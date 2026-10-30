// SPDX-License-Identifier: Apache-2.0
// Waits for the org's queueable backlog to drain between batches and measures how fast the engine's jobs complete.
// The thresholds are the seed wrapper's (seed-chain-scenarios.sh): delayed chains sit in Holding for their whole
// delay, so Holding is counted against its own ceiling and never blocks the gate on its own.
const {KINDS, recordStage} = require('./manifest');

const DRAIN_THRESHOLDS = {maximumActiveJobs: 10, maximumHeldJobs: 60, pollSeconds: 15, timeoutSeconds: 600};
const QUEUE_DEPTH_QUERY = 'SELECT Status, COUNT(Id) jobCount FROM AsyncApexJob WHERE JobType = \'Queueable\' '
		+ 'AND Status IN (\'Queued\', \'Preparing\', \'Processing\', \'Holding\') GROUP BY Status';
const MINUTE_MILLISECONDS = 60_000;
// The drain stage's box: a full load's last batches settle within two hours, a staged load's within fifteen minutes.
const FULL_DRAIN_TIMEOUT_SECONDS = 7200;
const STAGED_DRAIN_TIMEOUT_SECONDS = 900;
// A rate needs two samples; a wait that ends on its first sample measured nothing.
const MINIMUM_RATE_SAMPLES = 2;
// A poll query that fails (a transient network failure reads "fetch failed") is attempted this many times in all before the drain gives up.
const POLL_RETRY_ATTEMPTS = 4;
// The statuses of a job that can still run its chain hop; a Running row whose job is in any other status sits on a dead job.
const LIVE_JOB_STATUSES = ['Queued', 'Preparing', 'Processing', 'Holding'];
// At most this many Running rows are checked for a dead job; more than that is a run still in flight and needs no check.
const DEAD_JOB_CHECK_LIMIT = 200;

/**
 * @description The count of engine jobs completed since an instant.
 *
 * @param {string} sinceIso An ISO-8601 instant, as SOQL takes it (no quotes).
 *
 * @returns {string}
 */
function completedJobsQuery(sinceIso)
{
	return `SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable' AND ApexClass.Name = 'UTIL_AsyncChain' AND Status = 'Completed' AND CompletedDate >= ${sinceIso}`;
}

/**
 * @description Splits the grouped queue query into the jobs that are live and the jobs that are held.
 *
 * @param {object[]} records The grouped rows, each `{Status, jobCount}`.
 *
 * @returns {{active: number, holding: number}}
 */
function readQueueDepth(records)
{
	let active = 0;
	let holding = 0;
	for(const record of records)
	{
		const count = Number(record.jobCount ?? 0);
		if(record.Status === 'Holding')
		{
			holding += count;
		}
		else
		{
			active += count;
		}
	}
	return {active, holding};
}

/**
 * @description Whether the queue is quiet enough for the next batch.
 *
 * @param {{active: number, holding: number}} depth The queue depth.
 * @param {object} [thresholds] The ceilings, default DRAIN_THRESHOLDS.
 *
 * @returns {boolean}
 */
function isDrained(depth, thresholds = DRAIN_THRESHOLDS)
{
	return depth.active < thresholds.maximumActiveJobs && depth.holding < thresholds.maximumHeldJobs;
}

/**
 * @description Completed engine jobs per minute over the samples, or null with fewer than two samples.
 *
 * @param {object[]} samples The drain samples, each `{at, completed}`.
 *
 * @returns {number|null}
 */
function jobsPerMinute(samples)
{
	// The busy window: up to the last sample with a live job, so a deferred chain waiting out its delay does not dilute the rate.
	const lastBusy = samples.map((sample) => sample.active > 0).lastIndexOf(true);
	const busy = samples.slice(0, lastBusy + 1);
	if(busy.length < 2)
	{
		return null;
	}
	const first = busy[0];
	const last = busy[busy.length - 1];
	const minutes = (last.at - first.at) / MINUTE_MILLISECONDS;
	return minutes <= 0 ? null : Number(((last.completed - first.completed) / minutes).toFixed(1));
}

/**
 * @description The highest active and held counts seen.
 *
 * @param {object[]} samples The drain samples, each `{active, holding}`.
 *
 * @returns {{active: number, holding: number}}
 */
function peakDepth(samples)
{
	return samples.reduce((peak, sample) => ({active: Math.max(peak.active, sample.active), holding: Math.max(peak.holding, sample.holding)}), {active: 0, holding: 0});
}

/**
 * @description Waits for a number of milliseconds.
 *
 * @param {number} milliseconds How long.
 *
 * @returns {Promise<void>}
 */
function defaultSleep(milliseconds)
{
	return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

/**
 * @description Polls the queue until it is drained or the timeout passes, keeping every sample. A quiet queue is
 * not enough when the caller's run has not started queueing yet, so `until` can hold the drain until the run is
 * settled by the caller's own measure (say, no run under an action still Running).
 *
 * @param {object} options `salesforce` (the org door), `sinceIso` (when the run started), `thresholds`, `sleep`, `now`, `onSample`,
 * `until` (a predicate the drain also waits for; default always true).
 *
 * @returns {Promise<{drained: boolean, timedOut: boolean, samples: object[]}>}
 */
async function drainQueue({
	salesforce, sinceIso, thresholds = DRAIN_THRESHOLDS, sleep = defaultSleep, now = Date.now, onSample = () =>
	{
	}, until = () => true, log = () =>
	{
	}
})
{
	const samples = [];
	const deadline = now() + thresholds.timeoutSeconds * 1000;
	const retry = {sleep, waitMilliseconds: thresholds.pollSeconds * 1000, log};
	// eslint-disable-next-line no-constant-condition
	while(true)
	{
		const {depth, completed} = await readWithRetry(() => ({
			depth: readQueueDepth(salesforce.query(QUEUE_DEPTH_QUERY).records),
			completed: salesforce.query(completedJobsQuery(sinceIso)).totalSize
		}), retry);
		const sample = {at: now(), active: depth.active, holding: depth.holding, completed};
		samples.push(sample);
		onSample(sample);
		if(isDrained(depth, thresholds) && await readWithRetry(() => until(depth), retry))
		{
			return {drained: true, timedOut: false, samples};
		}
		if(now() >= deadline)
		{
			return {drained: false, timedOut: true, samples};
		}
		await sleep(thresholds.pollSeconds * 1000);
	}
}

/**
 * @description Makes a poll read, retrying a failure a bounded number of times with a growing wait between attempts:
 * one transient network failure must not end a run with hours of work behind it. The last failure is thrown.
 *
 * @param {Function} read The read to make; its value is returned.
 * @param {object} options `sleep`, `waitMilliseconds` (the first wait; each later one is a multiple of it), `log`, and
 *                         `what` (how the warning names the read; the drain's poll query unless a caller says otherwise).
 *
 * @returns {Promise<*>} What the read returned.
 */
async function readWithRetry(read, {sleep, waitMilliseconds, log, what = 'drain: WARNING poll query failed'})
{
	for(let attempt = 1; ; attempt++)
	{
		try
		{
			return await read();
		}
		catch(failure)
		{
			if(attempt >= POLL_RETRY_ATTEMPTS)
			{
				throw failure;
			}
			const reason = String(failure.message).split('\n')[0];
			log(`${what} (${reason}); retry ${attempt} of ${POLL_RETRY_ATTEMPTS - 1} after ${(waitMilliseconds * attempt) / 1000} s`);
			await sleep(waitMilliseconds * attempt);
		}
	}
}

/**
 * @description The count of runs under the run's token still Running: every action of a run is keyed
 * `<token>-aaaa-...`, so one LIKE finds them all. A quiet queue alone is not a settled run: retry leaves wait out
 * their backoffs and a deferred chain sits in Holding for ten minutes, and a clone or a verify taken then would read
 * in-flight rows.
 *
 * @param {object} manifest The manifest.
 *
 * @returns {string}
 */
function runningRunsQuery(manifest)
{
	const prefix = manifest.org.namespacePrefix;
	return `SELECT COUNT() FROM ${prefix}AsyncChainExecution__c WHERE ${prefix}RootCorrelationId__c LIKE '${manifest.runToken}-${KINDS.action}-%' `
			+ `AND ${prefix}Status__c = 'Running'`;
}

/**
 * @description The box the whole run drains inside, by mode.
 *
 * @param {object} manifest The manifest.
 *
 * @returns {object} Thresholds for drainQueue.
 */
function runThresholds(manifest)
{
	return {...DRAIN_THRESHOLDS, timeoutSeconds: manifest.mode === 'full' ? FULL_DRAIN_TIMEOUT_SECONDS : STAGED_DRAIN_TIMEOUT_SECONDS};
}

/**
 * @description Waits until the queue is quiet and no run under the token is still Running.
 *
 * @param {object} context `{manifest, salesforce, log, sleep, now, drain}`.
 *
 * @returns {Promise<{drained: boolean, timedOut: boolean, samples: object[]}>}
 */
function waitForRunToSettle(context)
{
	const {manifest, salesforce, log} = context;
	const drain = context.drain || drainQueue;
	const onSample = (sample) => log(`drain: active=${sample.active} holding=${sample.holding} completed=${sample.completed}`);
	const until = (depth) => runningRunsSettled(salesforce, manifest, log, depth);
	return drain({salesforce, sinceIso: manifest.startedAt, thresholds: runThresholds(manifest), sleep: context.sleep, now: context.now, onSample, until, log});
}

/**
 * @description SOQL's quoted list of values.
 *
 * @param {string[]} values The values.
 *
 * @returns {string}
 */
function quoted(values)
{
	return values.map((value) => `'${value}'`).join(', ');
}

/**
 * @description Whether the run has settled: no run under the token is still Running, or every one still Running sits
 * on a dead job (its executor ended without writing the row: the watchdog's case, and the operate stage schedules the
 * watchdog only after this wait, so the wait must not hold for it). The dead verdict is trusted only while the queue
 * is empty: the engine stamps a run's job id at the progress write, so from the second step on the stamp trails the
 * live executor by one step and a run mid-flight reads as sitting on an ended job. A Running row with no job stamped
 * yet, or more Running rows than the check reads, keeps the wait.
 *
 * @param {object} salesforce The org door.
 * @param {object} manifest The manifest.
 * @param {Function} log Where a dead-job settle is printed.
 * @param {object} [depth] The queue depth of the same sample (`active`, `holding`); unknown means no dead verdict.
 *
 * @returns {boolean}
 */
function runningRunsSettled(salesforce, manifest, log, depth)
{
	const running = salesforce.query(runningRunsQuery(manifest)).totalSize;
	if(running === 0)
	{
		return true;
	}
	if(running > DEAD_JOB_CHECK_LIMIT || !depth || depth.active > 0 || depth.holding > 0)
	{
		return false;
	}
	const prefix = manifest.org.namespacePrefix;
	const rows = salesforce.query(`SELECT ${prefix}CurrentJobId__c FROM ${prefix}AsyncChainExecution__c `
			+ `WHERE ${prefix}RootCorrelationId__c LIKE '${manifest.runToken}-${KINDS.action}-%' AND ${prefix}Status__c = 'Running' LIMIT ${DEAD_JOB_CHECK_LIMIT}`).records;
	const jobIds = rows.map((row) => row[`${prefix}CurrentJobId__c`]).filter((jobId) => jobId);
	if(rows.length !== running || jobIds.length !== rows.length)
	{
		return false;
	}
	const live = salesforce.query(`SELECT COUNT() FROM AsyncApexJob WHERE Id IN (${quoted(jobIds)}) AND Status IN (${quoted(LIVE_JOB_STATUSES)})`).totalSize;
	if(live > 0)
	{
		return false;
	}
	log(`drain: ${running} run(s) still Running on a dead job (no live executor); settled, the operate stage's watchdog re-drives them`);
	return true;
}

/**
 * @description The drain rate a settle wait measured, as the manifest records it.
 *
 * @param {{samples: object[], timedOut: boolean}} result The wait's result.
 * @param {string} measuredBy The stage that measured it.
 *
 * @returns {object}
 */
function drainRateRecord(result, measuredBy)
{
	return {jobsPerMinute: jobsPerMinute(result.samples), peak: peakDepth(result.samples), samples: result.samples.length, timedOut: result.timedOut, measuredBy};
}

/**
 * @description The drain stage: waits for the whole run to settle and records the run's drain rate. When the launch
 * stage already waited the run out (staged mode settles before its fill), this wait sees one quiet sample and the
 * earlier measurement stands.
 *
 * @param {object} context `{manifest, salesforce, log, sleep, now}`.
 *
 * @returns {Promise<object>} The manifest with the stage recorded.
 */
async function run(context)
{
	const {manifest} = context;
	if(manifest.stages.preflight && manifest.stages.preflight.reused)
	{
		return recordStage(manifest, 'drain', {ok: true, reused: true});
	}
	const result = await waitForRunToSettle({...context, drain: drainQueue});
	if(result.timedOut)
	{
		// The run goes on with the warning on record, never as a silent success; a rate over a truncated window is no rate.
		const warning = `the run did not settle inside ${runThresholds(manifest).timeoutSeconds} seconds; runs are still Running and the rate is not recorded`;
		context.log(`drain: WARNING ${warning}`);
		manifest.drainRate = {...drainRateRecord(result, 'drain'), jobsPerMinute: null};
		return recordStage(manifest, 'drain', {ok: true, drained: false, timedOut: true, warning});
	}
	if(result.samples.length >= MINIMUM_RATE_SAMPLES || !manifest.drainRate)
	{
		manifest.drainRate = drainRateRecord(result, 'drain');
	}
	return recordStage(manifest, 'drain', {ok: true, drained: result.drained, timedOut: false});
}

module.exports = {
	DRAIN_THRESHOLDS, POLL_RETRY_ATTEMPTS, QUEUE_DEPTH_QUERY, completedJobsQuery, readQueueDepth, isDrained, jobsPerMinute, peakDepth, drainQueue, runningRunsQuery,
	runningRunsSettled, waitForRunToSettle, drainRateRecord, readWithRetry, defaultSleep, run
};
