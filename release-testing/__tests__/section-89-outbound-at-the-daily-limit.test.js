// SPDX-License-Identifier: Apache-2.0
const fs = require('fs');
const os = require('os');
const path = require('path');
const lines = require('../scripts/section-89/probe-lines');
const scripts = require('../scripts/section-89/probe-scripts');
const checks = require('../scripts/section-89/checks');
const {pollUntil, createClock, InterruptedError} = require('../scripts/section-89/poll');
const childProcess = require('child_process');
const {runSection, runRestoreOnly, findCtrlCStop, WINDOWS_CTRL_C_EXIT_CODE} = require('../scripts/section-89/run');
const {parseCommandLine, exitCodeFor, runStamp, createInterruptHandler, USAGE} = require('../scripts/section-89-outbound-at-the-daily-limit');
const {createOrg, readAnswer, commandOptions, runSalesforceCommand, checkShellSafe} = require('../scripts/section-89/org');

const SECOND = 1_000;
const MINUTE = 60 * SECOND;
const START = Date.parse('2026-11-08T15:00:00.000Z');
const USED = 100;
const LICENSED = 250000;
const LOWERED = 110;
// A filler job runs, and so counts against the allowance, this long after it was queued.
const FILLER_RUN_DELAY = 50 * SECOND;
const FILLER_CLASS = 'ElasticProbeFiller';
// The class of the handler job that the launcher's delayed dispatch queues in place of the work.
const LAUNCHER_CLASS = 'UTIL_AsynchronousJobLauncher';
const LOST_JOB_TEXT = 'No background job finished sending this request again. Its retry was due 0 hour(s) ago.';
const ACCOUNT_IDS = ['001Ru00000AAAAAAAA', '001Ru00000BBBBBBBB', '001Ru00000CCCCCCCC'];
// Salesforce's error when it refuses a job at the 24-hour limit, as the async processing guide quotes it.
const LIMIT_REFUSAL_MESSAGE = 'Rate Limiting Exception : AsyncApexExecutions Limit exceeded.';

/**
 * @description A time as the probe prints it: Eastern time, to the second.
 *
 * @param {Date|number|null} value The time.
 *
 * @returns {string}
 */
// noinspection FunctionWithMultipleReturnPointsJS
function probeTime(value)
{
	if(value === null || value === undefined)
	{
		return 'null';
	}
	const parts = new Intl.DateTimeFormat('en-US', {
		timeZone: 'America/New_York', hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit'
	}).formatToParts(new Date(value));
	const part = (type) => parts.find((candidate) => candidate.type === type).value;
	return `${part('year')}-${part('month')}-${part('day')} ${part('hour')}:${part('minute')}:${part('second')}`;
}

/**
 * @description The refused-start text Kern writes on a call, naming its retry time.
 *
 * @param {number} retryTime The retry time.
 *
 * @returns {string}
 */
function launchRefusedText(retryTime)
{
	return 'Salesforce refused to start the background send, so the request was not sent: Too many async Apex executions. '
		+ `It will be tried again at ${new Date(retryTime).toISOString()}. The Next Retry field shows this time in your own time zone.`;
}

/**
 * @description An org that behaves as section 89 expects of an installed package, on a fake clock: the allowance,
 * the jobs, the calls, the issues, the log entries, the schedules, the probe classes and the Apex settings, moved on by
 * time as each command runs. Every Queueable counts against the allowance in the same way: when it runs (`countsWhen:
 * 'run'`, the default) or as soon as it is queued (`countsWhen: 'queued'`). A filler job runs a little after it was
 * queued (`fillerRunDelay`), the chain's first job a minute after the launch, and each reads as live until then.
 *
 * @param {object} [options] `countsWhen` and `fillerRunDelay` as above; `foreign`: guard query label to the foreign
 *        calls it finds; `stuckSpendLabels`: spends whose filler jobs never run; `foreignLiveJob`: a job of someone else that
 *        never ends; `launchNeverRuns`, `noFlowWarning`, `retryNeverSent`, `watchdogNeverFires`: evidence that never
 *        comes; `scheduleIdUnread`: the schedule line is not printed; `scheduleStuck`: a schedule no abort removes;
 *        `lowered`: the org starts with the allowance lowered, a probe schedule and the filler class left behind;
 *        `placesFreedAtLaunch`: places the rolling 24 hours frees just as the chainable launch is accepted;
 *        `placesFreedBeforeSave`: places it frees just before the read that starts 89d;
 *        `waitingProcessorJob`: the org starts with a job of the adaptive processor that waits at Queued;
 *        `processorAbortIgnored`: the stop of a processor job leaves it at Queued; `fillerAbortIgnored`: the stop of a
 *        filler job leaves it at Queued.
 * @param {string} [options.failDeploy] The label of a deploy that fails.
 *
 * @returns {object} `{org, clock, model, commands}`.
 */
function createFakeOrg(options = {})
{
	const clock = {time: START, now: () => clock.time, sleep: async(milliseconds) =>
	{
		clock.time += milliseconds;
	}};
	const model = {used: USED, maximum: LICENSED, override: null, jobs: [], calls: [], issues: [], logs: [], schedule: null, launch: null, counter: 0,
		classes: new Set(), spends: []};
	const commands = [];
	const countedWhenQueued = options.countsWhen === 'queued';
	const fillerRunDelay = options.fillerRunDelay ?? FILLER_RUN_DELAY;
	const newId = (prefix) =>
	{
		model.counter += 1;
		return `${prefix}Ru${String(model.counter).padStart(10, '0')}AAA`;
	};
	const remaining = () => model.maximum - model.used;
	const addJob = (className, created, status, type = 'Queueable') =>
	{
		const job = {id: newId('707'), className, type, status, created};
		model.jobs.push(job);
		if(type === 'Queueable' && (status !== 'Queued' || countedWhenQueued))
		{
			model.used += 1;
		}
		return job;
	};
	const runQueuedJob = (job) =>
	{
		job.status = 'Completed';
		if(!countedWhenQueued)
		{
			model.used += 1;
		}
	};
	const liveFillers = () => model.jobs.filter((job) => job.className === FILLER_CLASS && job.status === 'Queued').length;
	const newSchedule = () => ({cronId: newId('08e'), created: clock.time, fireAt: clock.time + 75 * SECOND, fired: false, aborted: false});
	const isScheduleLive = (schedule) => Boolean(schedule && !schedule.aborted);
	if(options.lowered)
	{
		Object.assign(model, {maximum: LOWERED, override: LOWERED, schedule: newSchedule()});
		model.classes.add(FILLER_CLASS);
	}
	if(options.waitingProcessorJob)
	{
		addJob(checks.PROCESSOR_CLASS, clock.time - 5 * MINUTE, 'Queued');
	}

	/**
	 * @description Moves the org on to the clock's time.
	 */
	// noinspection NestedFunctionJS
	function advance()
	{
		runDueFillers();
		runDueLaunch();
		for(const call of model.calls.filter(() => !options.retryNeverSent))
		{
			sendDueRetries(call);
		}
		fireDueSchedule();
	}

	/**
	 * @description Runs every filler job whose run delay has passed, unless the job is stuck.
	 */
	// noinspection NestedFunctionJS
	function runDueFillers()
	{
		for(const job of model.jobs.filter((candidate) => candidate.className === FILLER_CLASS && candidate.status === 'Queued' && !candidate.stuck))
		{
			if(clock.time >= job.created + fillerRunDelay)
			{
				runQueuedJob(job);
			}
		}
	}

	/**
	 * @description Runs the job the launch queued a minute after the launch. The chain's first job, with no place left,
	 * logs the refused next job; with a place left the next job runs. The launcher's handler starts the chain's first
	 * job only when a place is left, and writes nothing at the processor's next-job step.
	 */
	// noinspection NestedFunctionJS
	function runDueLaunch()
	{
		const launch = model.launch;
		if(launch && !launch.done && !options.launchNeverRuns && clock.time >= launch.job.created + MINUTE)
		{
			launch.done = true;
			runQueuedJob(launch.job);
			if(launch.isHandler)
			{
				if(remaining() > 0)
				{
					addJob(checks.PROCESSOR_CLASS, clock.time, 'Completed');
				}
			}
			else if(remaining() <= 0)
			{
				model.logs.push({level: 'ERROR', at: `kern.${checks.PROCESSOR_CLASS}/enqueueNextHop`, record: launch.job.id, created: launch.job.created + MINUTE + SECOND,
					message: LIMIT_REFUSAL_MESSAGE, context: `{"jobScope":"${ACCOUNT_IDS[1]},${ACCOUNT_IDS[2]}"}`});
			}
			else
			{
				addJob(checks.PROCESSOR_CLASS, clock.time, 'Completed');
			}
		}
	}

	/**
	 * @description Sends a call at Retry once the allowance is back and each of its due times has passed: the first send
	 * fails and counts a retry a minute later, the second ends the call Failed.
	 *
	 * @param {object} call The call.
	 */
	// noinspection NestedFunctionJS
	function sendDueRetries(call)
	{
		while(call.status === 'Retry' && model.maximum === LICENSED && call.nextRetry <= clock.time)
		{
			addJob(checks.PROCESSOR_CLASS, call.nextRetry, 'Completed');
			if(call.retries === 0)
			{
				call.retries = 1;
				call.nextRetry += MINUTE;
				model.issues.push({id: newId('a01'), status: 'Open', call: call.id, created: clock.time, mayHaveActed: false, errors: 'Unable to reach the Named Credential'});
			}
			else
			{
				call.status = 'Failed';
				call.nextRetry = null;
			}
		}
	}

	/**
	 * @description Whether the watchdog's schedule is there, not stopped, not fired yet and due.
	 *
	 * @param {object|null} schedule The schedule.
	 *
	 * @returns {boolean}
	 */
	// noinspection NestedFunctionJS
	function isScheduleDue(schedule)
	{
		return isScheduleLive(schedule) && !schedule.fired && !options.watchdogNeverFires && clock.time >= schedule.fireAt;
	}

	/**
	 * @description Fires the watchdog's schedule once it is due: every call at Retrying ends Failed with the lost-job
	 * text, a marked issue and a warning.
	 */
	// noinspection NestedFunctionJS
	function fireDueSchedule()
	{
		const schedule = model.schedule;
		if(isScheduleDue(schedule))
		{
			schedule.fired = true;
			addJob('SCHED_OutboundRetryWatchdog', schedule.created, 'Completed', 'ScheduledApex');
			for(const call of model.calls.filter((candidate) => candidate.status === 'Retrying'))
			{
				Object.assign(call, {status: 'Failed', nextRetry: null, errors: LOST_JOB_TEXT});
				model.issues.push({id: newId('a01'), status: 'Open', call: call.id, created: clock.time, mayHaveActed: true, errors: LOST_JOB_TEXT});
				model.logs.push({level: 'WARN', at: 'kern.SCHED_OutboundRetryWatchdog/execute', record: call.id, created: clock.time, message: LOST_JOB_TEXT, context: null});
			}
		}
	}

	/**
	 * @description What read-budget.apex prints.
	 *
	 * @returns {string[]}
	 */
	// noinspection NestedFunctionJS
	function readBudgetLines()
	{
		const pending = model.calls.filter((call) => checks.PENDING_STATUSES.includes(call.status)).length;
		const liveByClass = countLiveJobsByClass();
		const live = Object.values(liveByClass).reduce((total, count) => total + count, 0);
		const newestFirst = (first, second) => second.created - first.created;
		return [
			`PROBE BUDGET time=${probeTime(clock.time)} used=${model.used} maximum=${model.maximum} remaining=${remaining()}`,
			...model.calls.map((call) => `PROBE CALL ${checks.PENDING_STATUSES.includes(call.status) ? 'pending' : 'settled'} id=${call.id} status=${call.status} `
				+ `nextRetry=${probeTime(call.nextRetry)} retries=${call.retries} created=${probeTime(call.created)} modified=${probeTime(clock.time)} `
				+ `errors=${call.errors ?? 'null'}`),
			...model.issues.map((issue) => `PROBE ISSUE id=${issue.id} name=I-${issue.id.slice(-3)} status=${issue.status} call=${issue.call} `
				+ `created=${probeTime(issue.created)} mayHaveActed=${issue.mayHaveActed} errors=${issue.errors}`),
			...[...model.logs].sort(newestFirst).map((entry) => `PROBE LOG level=${entry.level} at=${entry.at} record=${entry.record} `
				+ `created=${probeTime(entry.created)} message=${entry.message}${entry.context === null ? '' : ` context=${entry.context}`}`),
			...[...model.jobs].sort(newestFirst).slice(0, 20).map((job) => `PROBE JOB id=${job.id} class=${job.className} type=${job.type} status=${job.status} `
				+ `created=${probeTime(job.created)} completed=null errors=0 extended=null`),
			...Object.entries(liveByClass).map(([className, count]) => `PROBE LIVE class=${className} status=Queued count=${count}`),
			`PROBE GATE remaining=${remaining()} probeSchedules=${isScheduleLive(model.schedule) ? 1 : 0} pendingCalls=${pending} outboundInterviews=0 `
				+ `runningChains=0 liveJobs=${live}`
		];
	}

	/**
	 * @description How many jobs wait at Queued, per class, with someone else's job that never ends when the test asks
	 * for one.
	 *
	 * @returns {object} Class name to count.
	 */
	// noinspection NestedFunctionJS
	function countLiveJobsByClass()
	{
		const liveByClass = {};
		for(const job of model.jobs.filter((candidate) => candidate.status === 'Queued'))
		{
			liveByClass[job.className] = (liveByClass[job.className] ?? 0) + 1;
		}
		if(options.foreignLiveJob)
		{
			liveByClass.SomeoneElsesJob = 1;
		}
		return liveByClass;
	}

	/**
	 * @description What abort-schedules-by-name.apex prints.
	 *
	 * @param {string} action abort or read.
	 *
	 * @returns {string[]}
	 */
	// noinspection NestedFunctionJS
	function sweepSchedules(action)
	{
		let aborted = 0;
		if(action === 'abort' && isScheduleLive(model.schedule) && !options.scheduleStuck)
		{
			model.schedule.aborted = true;
			aborted = 1;
		}
		const left = isScheduleLive(model.schedule) ? [model.schedule] : [];
		return [...left.map((schedule) => `SECTION89 SCHEDULE LEFT id=${schedule.cronId} name=Elastic Probe Outbound Retry Watchdog 1`),
			`SECTION89 SCHEDULES action=${action} aborted=${aborted} left=${left.length}`];
	}

	/**
	 * @description What abort-probe-jobs.apex prints: one job by its id, every processor job not ended (`all`) or
	 * none (`none`), and always every filler job not ended.
	 *
	 * @param {string} jobId The job's id, `all` or `none`.
	 * @param {string} action abort or read.
	 *
	 * @returns {string[]}
	 */
	// noinspection NestedFunctionJS
	function stopProbeJobs(jobId, action)
	{
		const isLive = (job) => checks.LIVE_JOB_STATUSES.includes(job.status);
		let found = [];
		if(jobId === 'all')
		{
			found = model.jobs.filter((job) => job.className === checks.PROCESSOR_CLASS && isLive(job));
		}
		else if(jobId !== 'none')
		{
			found = model.jobs.filter((job) => job.id === jobId);
		}
		found = [...found, ...model.jobs.filter((job) => job.className === FILLER_CLASS && isLive(job))];
		let aborted = 0;
		const output = found.map((job) =>
		{
			const waiting = checks.WAITING_JOB_STATUSES.includes(job.status);
			const status = job.status;
			const ignored = job.className === FILLER_CLASS ? options.fillerAbortIgnored : options.processorAbortIgnored;
			if(action === 'abort' && waiting && !ignored)
			{
				job.status = 'Aborted';
				aborted += 1;
				if(model.launch?.job === job)
				{
					model.launch.done = true;
				}
			}
			return `PROBE STOP JOB id=${job.id} status=${status} aborted=${action === 'abort' && waiting} class=${job.className}`;
		});
		const left = found.filter((job) => checks.LIVE_JOB_STATUSES.includes(job.status)).length;
		return [...output, `PROBE STOP JOBS action=${action} found=${found.length} aborted=${aborted} left=${left}`];
	}

	// Each script the fake org knows, by a text only that script holds, with what it prints. The first match answers.
	const responders = [
		['PROBE GATE remaining=', (apex, label) => respondToReadBudget(label)],
		['PROBE SPEND time=', respondToSpend],
		['PROBE LAUNCHER time=', respondToLaunch],
		['PROBE CALL INSERT time=', respondToInsert],
		['PROBE SCHEDULE ONCE', respondToScheduleOnce],
		['PROBE LEFT chain runs', respondToCleanUp],
		['SECTION89 BREAKER', () => ['SECTION89 BREAKER circuit=API_RetryLiveGet state=CLOSED']],
		['PROBE STOP JOBS action=', (apex) => stopProbeJobs(apex.match(/final String JOB_ID = '(\w+)';/)[1], apex.match(/final String ACTION = '(\w+)';/)[1])],
		['SECTION89 SCHEDULES action=', (apex) => sweepSchedules(apex.match(/final String ACTION = '(\w+)';/)[1])],
		['SECTION89 SCHEDULE id=', respondToAbortSchedule],
		['SECTION84 PASS 84-log-cleanup', () => ['SECTION84 PASS 84-log-cleanup: deleted 3 RetryLive log entries; none is left']]
	];

	/**
	 * @description What one script prints, by what the script is.
	 *
	 * @param {string} apex The script.
	 * @param {string} label The script's label.
	 *
	 * @returns {string[]}
	 */
	// noinspection NestedFunctionJS
	function respond(apex, label)
	{
		const responder = responders.find(([marker]) => apex.includes(marker));
		if(!responder)
		{
			throw new Error('the fake org does not know this script');
		}
		return responder[1](apex, label);
	}

	/**
	 * @description What read-budget.apex prints. Before the read that starts 89d, the rolling 24 hours may first free
	 * places, once.
	 *
	 * @param {string} label The script's label.
	 *
	 * @returns {string[]}
	 */
	// noinspection NestedFunctionJS
	function respondToReadBudget(label)
	{
		if(label.startsWith('89d-before') && options.placesFreedBeforeSave && !model.placesFreedBeforeSave)
		{
			model.placesFreedBeforeSave = true;
			model.used -= options.placesFreedBeforeSave;
		}
		return readBudgetLines();
	}

	/**
	 * @description What spend-budget.apex prints: it queues filler jobs until the places it must leave.
	 *
	 * @param {string} apex The script.
	 * @param {string} label The script's label.
	 *
	 * @returns {string[]}
	 */
	// noinspection NestedFunctionJS
	function respondToSpend(apex, label)
	{
		const leave = Number(apex.match(/final Integer LEAVE = (-?\d+);/)[1]);
		const toQueue = Math.max(0, Math.min(remaining() - leave, 50));
		const before = remaining();
		model.spends.push({label, queued: toQueue, liveFillers: liveFillers()});
		for(let index = 0; index < toQueue; index++)
		{
			addJob(FILLER_CLASS, clock.time, 'Queued').stuck = (options.stuckSpendLabels ?? []).includes(label);
		}
		return [`PROBE SPEND time=${probeTime(clock.time)} maximum=${model.maximum} remainingBefore=${before} leave=${leave} toQueue=${toQueue}`,
			`PROBE SPEND queued=${toQueue} remainingAfterEnqueueSameTransaction=${remaining()} firstJob=null lastJob=null`];
	}

	/**
	 * @description What launch-adaptive-processor.apex prints, by how the script sets its delay. A delay set through
	 * the async options (`withAsyncOptions`) of a chainable launch is on the chain's own jobs, so the job queued is the
	 * chain's first job. Any other delay goes through the launcher's delayed dispatch (`withDelayMinutes`), so the job
	 * queued is a UTIL_AsynchronousJobLauncher handler. The rolling 24 hours may free places at the same moment.
	 *
	 * @param {string} apex The script.
	 *
	 * @returns {string[]}
	 */
	// noinspection NestedFunctionJS
	function respondToLaunch(apex)
	{
		const delayMinutes = Number(apex.match(/final Integer DELAY_MINUTES = (\d+);/)[1]);
		const isChainable = apex.includes("final String STRATEGY = 'chainable';");
		const isDelayedThroughHandler = delayMinutes > 0 && !(isChainable && apex.includes('request.withAsyncOptions('));
		const className = isDelayedThroughHandler ? LAUNCHER_CLASS : checks.PROCESSOR_CLASS;
		const job = addJob(className, clock.time, 'Queued');
		model.launch = {job, done: false, isHandler: isDelayedThroughHandler};
		model.used -= options.placesFreedAtLaunch ?? 0;
		return [`PROBE LAUNCHER items=${ACCOUNT_IDS.join(',')} run=0`,
			`PROBE LAUNCHER run=0 accepted job=${job.id} class=${className} type=Queueable status=Queued`];
	}

	/**
	 * @description What insert-outbound-call.apex prints: a call left at Retrying, or a call Salesforce refused to start,
	 * which waits at Retry with the Flow action's warning.
	 *
	 * @param {string} apex The script.
	 *
	 * @returns {string[]}
	 */
	// noinspection NestedFunctionJS
	function respondToInsert(apex)
	{
		const mode = apex.match(/final String MODE = '(\w+)';/)[1];
		const call = {id: newId('a00'), created: clock.time, retries: 0, errors: null};
		if(mode === 'retrying')
		{
			Object.assign(call, {status: 'Retrying', nextRetry: clock.time - 5 * MINUTE, retries: 1});
		}
		else
		{
			const nextRetry = clock.time + 15 * MINUTE;
			Object.assign(call, {status: 'Retry', nextRetry, errors: launchRefusedText(nextRetry)});
			if(!options.noFlowWarning)
			{
				model.logs.push({level: 'WARN', at: 'kern.FLOW_CallApiAsync/invokeApiCallAsynchronously', record: 'null', created: clock.time + 5 * SECOND, context: null,
					message: 'Salesforce refused to start the background send. 1 calls were not sent and wait at Retry; '
						+ `the first is tried again at ${new Date(nextRetry).toISOString()}`});
			}
		}
		model.calls.push(call);
		return [`PROBE CALL INSERT time=${probeTime(clock.time)} mode=${mode} remaining=${remaining()} rowsBefore=0`, `PROBE CALL INSERT saved id=${call.id}`,
			`PROBE CALL INSERT rowExists=true id=${call.id} status=${call.status} nextRetry=${probeTime(call.nextRetry)} retries=${call.retries} `
			+ `errors=${call.errors ?? 'null'}`];
	}

	/**
	 * @description What schedule-once.apex prints: the watchdog's schedule is made, and its line is left out when the
	 * test asks for an unread id.
	 *
	 * @returns {string[]}
	 */
	// noinspection NestedFunctionJS
	function respondToScheduleOnce()
	{
		model.schedule = newSchedule();
		return options.scheduleIdUnread ? [] : [`PROBE SCHEDULE ONCE name=Elastic Probe Outbound Retry Watchdog 1 cronId=${model.schedule.cronId} `
			+ `fireAt=${probeTime(model.schedule.fireAt)} cron=x threshold=1`];
	}

	/**
	 * @description What clean-up.apex prints: the probe's rows go, and its schedule unless no abort removes it.
	 *
	 * @returns {string[]}
	 */
	// noinspection NestedFunctionJS
	function respondToCleanUp()
	{
		model.calls = [];
		model.issues = [];
		if(model.schedule && !options.scheduleStuck)
		{
			model.schedule.aborted = true;
		}
		const schedulesLeft = isScheduleLive(model.schedule) ? 1 : 0;
		return ['PROBE LEFT chain runs=0', 'PROBE LEFT calls=0 kept=none', 'PROBE LEFT issues=0', 'PROBE LEFT runner rows=0', 'PROBE LEFT launcher accounts=0',
			`PROBE LEFT probe schedules=${schedulesLeft}`, 'PROBE LEFT probe flow interviews=0'];
	}

	/**
	 * @description What abort-schedule.apex prints: the schedule stops by its id, unless no abort removes it.
	 *
	 * @returns {string[]}
	 */
	// noinspection NestedFunctionJS
	function respondToAbortSchedule()
	{
		const wasLive = isScheduleLive(model.schedule);
		if(model.schedule && !options.scheduleStuck)
		{
			model.schedule.aborted = true;
		}
		return [`SECTION89 SCHEDULE id=x aborted=${wasLive && !options.scheduleStuck} left=${isScheduleLive(model.schedule) ? 1 : 0}`];
	}

	// noinspection FunctionWithMultipleReturnPointsJS
	const org = {
		runApex: jest.fn((apex, label) =>
		{
			commands.push(`apex ${label}`);
			advance();
			const dryRun = apex.startsWith('if(Datetime.now() != null)');
			if(dryRun)
			{
				const exceptionMessage = `System.IllegalArgumentException: ${scripts.DRY_RUN_MARKER}`;
				return {exitCode: 1, success: false, compiled: true, compileProblem: '', exceptionMessage, debugLines: []};
			}
			return {exitCode: 0, success: true, compiled: true, compileProblem: '', exceptionMessage: '', debugLines: respond(apex, label)};
		}),
		query: jest.fn((soql, label) =>
		{
			commands.push(`query ${label}`);
			if(label === 'namespace')
			{
				return [{NamespacePrefix: 'kern'}];
			}
			if(label === 'subscriber-classes')
			{
				return [{Name: 'API_RetryLiveGet'}, {Name: 'AccountArchiveProcessor'}, ...[...model.classes].map((name) => ({Name: name}))];
			}
			if(label.startsWith('89h-classes'))
			{
				return [...model.classes].map((name) => ({Id: '01pX', Name: name}));
			}
			if(label.includes('guard'))
			{
				return (options.foreign?.[label] ?? []).map((call) => ({Id: call.id, kern__Status__c: call.status}));
			}
			return [];
		}),
		deploy: jest.fn((projectDirectory, metadata, label) =>
		{
			commands.push(`deploy ${metadata} ${label}`);
			if(options.failDeploy === label)
			{
				return {success: false, message: 'refused', file: 'x'};
			}
			if(metadata === 'Settings:Apex')
			{
				const text = fs.readFileSync(path.join(projectDirectory, 'force-app', 'main', 'default', 'settings', 'Apex.settings-meta.xml'), 'utf8');
				const override = text.match(/<asyncApexExecutionsOverride>(\d+)</);
				model.override = override ? Number(override[1]) : null;
				model.maximum = model.override ?? LICENSED;
			}
			else
			{
				model.classes.add(metadata.replace('ApexClass:', ''));
			}
			return {success: true, message: '', file: 'x'};
		}),
		deleteSource: jest.fn((projectDirectory, metadata, label) =>
		{
			commands.push(`delete ${metadata} ${label}`);
			model.classes.delete(metadata.replace('ApexClass:', ''));
			return {success: true, message: '', file: 'x'};
		}),
		retrieve: jest.fn((projectDirectory, metadata, label) =>
		{
			commands.push(`retrieve ${metadata} ${label}`);
			const override = model.override === null ? '<asyncApexExecutionsOverride xsi:nil="true"/>'
				: `<asyncApexExecutionsOverride>${model.override}</asyncApexExecutionsOverride>`;
			fs.writeFileSync(path.join(projectDirectory, 'force-app', 'main', 'default', 'settings', 'Apex.settings-meta.xml'),
				`<ApexSettings>${override}<enableAsyncApexElasticExecutions>false</enableAsyncApexElasticExecutions></ApexSettings>`);
			return {success: true, message: '', file: 'x'};
		})
	};
	return {org, clock, model, commands};
}

/**
 * @description A run context on a fake org.
 *
 * @param {object} fake The fake org.
 * @param {object} [overrides] Context fields to replace.
 *
 * @returns {object}
 */
function contextFor(fake, overrides = {})
{
	const output = [];
	return {org: fake.org, clock: fake.clock, log: (line) => output.push(line), output, dryRun: false, signal: {interrupted: false, cleaningUp: false},
		temporaryDirectory: fs.mkdtempSync(path.join(os.tmpdir(), 'section-89-test-')), ...overrides};
}

/**
 * @description The step lines of a run, as `<step> <status>`.
 *
 * @param {object} context The run.
 *
 * @returns {string[]}
 */
function stepLines(context)
{
	return context.steps.map((step) => `${step.step} ${step.status}`);
}

/**
 * @description Checks that the clean-up stopped the 9 filler jobs that a Ctrl-C during the spend left waiting, before
 * it deleted their class, and that every clean-up action then passed.
 *
 * @param {object} context The run.
 * @param {object} fake The fake org.
 */
function expectFillerJobsStopped(context, fake)
{
	const fillers = fake.model.jobs.filter((job) => job.className === FILLER_CLASS);
	expect(fillers).toHaveLength(9);
	expect(fillers.every((job) => job.status === 'Aborted')).toBe(true);
	const stop = fake.commands.indexOf('apex 89h-stop-probe-jobs-abort');
	expect(stop).toBeGreaterThan(-1);
	expect(stop).toBeLessThan(fake.commands.indexOf('delete ApexClass:ElasticProbeFiller 89h-delete-ElasticProbeFiller'));
	expect(context.steps.at(-1)).toMatchObject({step: '89h', status: 'PASS', values: {stoppedJobs: 9}});
}

/**
 * @description Checks that a run a Ctrl-C stopped reported no error of its own, and that the clean-up then passed and
 * put the licensed allowance back.
 *
 * @param {object} context The run.
 * @param {object} fake The fake org.
 */
function expectInterruptedRunPutBack(context, fake)
{
	expect(context.output.some((line) => line.startsWith('SECTION89 ERROR FAIL'))).toBe(false);
	expect(context.steps.at(-1)).toMatchObject({step: '89h', status: 'PASS'});
	expect(fake.model.maximum).toBe(LICENSED);
}

/**
 * @description Makes the first run of clean-up.apex end with the outcome given, as a command a Ctrl-C stopped would;
 * every later run of it, and every other script, behaves as before.
 *
 * @param {object} fake The fake org.
 * @param {object} outcome What the stopped command returns.
 */
function stopFirstCleanUpCommand(fake, outcome)
{
	const original = fake.org.runApex.getMockImplementation();
	const stoppedLabels = new Set();
	// noinspection FunctionWithMultipleReturnPointsJS
	fake.org.runApex.mockImplementation((apex, label) =>
	{
		if(label === '89h-clean-up' && !stoppedLabels.has(label))
		{
			stoppedLabels.add(label);
			fake.commands.push(`apex ${label}`);
			return outcome;
		}
		return original(apex, label);
	});
}

/**
 * @description A chainable launch at the limit whose next job was refused: the run's start, the accepted launch, its
 * first job that Completed, and the one ERROR entry that names the second and third Accounts and the 24-hour limit.
 *
 * @returns {{runStart: Date, launch: object, job: object, entry: object}}
 */
function createRefusedNextHop()
{
	return {
		runStart: new Date(START),
		launch: {accepted: true, jobId: '707A', className: 'UTIL_AdaptiveAsynchronousProcessor', type: 'Queueable', accountIds: ACCOUNT_IDS, refused: null},
		job: {id: '707A', className: 'UTIL_AdaptiveAsynchronousProcessor', status: 'Completed', created: new Date(START + MINUTE)},
		entry: {level: 'ERROR', at: 'UTIL_AdaptiveAsynchronousProcessor/enqueueNextHop', record: '707A', created: new Date(START + 2 * MINUTE),
			message: LIMIT_REFUSAL_MESSAGE, context: `${ACCOUNT_IDS[1]},${ACCOUNT_IDS[2]}`}
	};
}

describe('the scripts the driver sends', () =>
{
	it('fills every token and refuses a script that still carries one', () =>
	{
		expect(scripts.fillTokens('A __MODE__ B __MODE__', {__MODE__: 'queued'}, 'insert')).toBe('A queued B queued');
		expect(() => scripts.fillTokens('A __MODE__ __LEAVE__', {__MODE__: 'queued'}, 'insert')).toThrow('insert still carries __LEAVE__');
	});

	it('keeps, renames or removes the package namespace from what the org reads', () =>
	{
		const apex = 'kern.TST_Factory.x(); kern__ApiCall__c row; // Kern.Thing';
		expect(scripts.applyNamespace(apex, 'kern')).toBe(apex);
		expect(scripts.applyNamespace(apex, '')).toBe('TST_Factory.x(); ApiCall__c row; // Kern.Thing');
		expect(scripts.applyNamespace(apex, 'acme')).toBe('acme.TST_Factory.x(); acme__ApiCall__c row; // Kern.Thing');
	});

	it('renders the chainable launch with its strategy and job size, for a copy with no namespace', () =>
	{
		const apex = scripts.renderScript('launchAdaptiveProcessor', {namespace: '',
			values: {__ITEMS__: 3, __DELAY__: 1, __RUNS__: 1, __STRATEGY__: 'chainable', __JOB_SIZE__: 1}});
		expect(apex).toContain("final String STRATEGY = 'chainable';");
		expect(apex).toContain('final Integer JOB_SIZE = 1;');
		expect(apex).toContain('request.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.CHAINABLE).withQueueableJobSize(JOB_SIZE);');
		expect(apex).not.toMatch(/\bkern(\.|__)/);
		const chainableBranch = apex.slice(apex.indexOf("if(STRATEGY == 'chainable')"), apex.indexOf('else if(DELAY_MINUTES > 0)'));
		expect(chainableBranch).toContain('options.minimumQueueableDelayInMinutes = DELAY_MINUTES;');
		expect(chainableBranch).toContain('request.withAsyncOptions(options);');
		expect(chainableBranch).not.toContain('withDelayMinutes');
	});

	it('keeps the launcher\'s delayed dispatch for a launch the launcher chooses the job type for', () =>
	{
		const apex = scripts.renderScript('launchAdaptiveProcessor', {values: {__ITEMS__: 49, __DELAY__: 1, __RUNS__: 1, __STRATEGY__: 'auto', __JOB_SIZE__: 0}});
		const otherBranch = apex.slice(apex.indexOf('else if(DELAY_MINUTES > 0)'));
		expect(otherBranch).toContain('request.withDelayMinutes(DELAY_MINUTES);');
		expect(otherBranch).not.toContain('minimumQueueableDelayInMinutes');
	});

	it('sends the same Apex, with plain line breaks, when a Windows checkout saved the script with Windows line breaks', () =>
	{
		const values = {__ITEMS__: 49, __DELAY__: 1, __RUNS__: 1, __STRATEGY__: 'auto', __JOB_SIZE__: 0};
		const plain = scripts.renderScript('launchAdaptiveProcessor', {values});
		const readFileSync = fs.readFileSync;
		const spy = jest.spyOn(fs, 'readFileSync').mockImplementation((file, encoding) => readFileSync(file, encoding).replace(/\r?\n/g, '\r\n'));
		try
		{
			const fromWindowsCheckout = scripts.renderScript('launchAdaptiveProcessor', {values});
			expect(fromWindowsCheckout).not.toContain('\r');
			expect(fromWindowsCheckout).toBe(plain);
		}
		finally
		{
			spy.mockRestore();
		}
	});

	it('renders the stop by name of the watchdog schedules for both of its actions', () =>
	{
		expect(scripts.renderScript('abortSchedulesByName', {values: {__ACTION__: 'abort'}})).toContain("final String ACTION = 'abort';");
		expect(scripts.renderScript('abortSchedulesByName', {values: {__ACTION__: 'read'}})).toContain("'Elastic Probe Outbound Retry Watchdog%'");
	});

	it('renders the stop of the processor jobs with its id, and finds Kern\'s namespace from a Kern class name on any install', () =>
	{
		const namespaced = scripts.renderScript('abortProbeJobs', {values: {__JOB_ID__: '707Ru0000000001AAA', __ACTION__: 'abort'}});
		expect(namespaced).toContain("final String JOB_ID = '707Ru0000000001AAA';");
		expect(namespaced).toContain('kern.UTIL_AsynchronousJobLauncher.class.getName()');
		const plain = scripts.renderScript('abortProbeJobs', {namespace: '', values: {__JOB_ID__: 'all', __ACTION__: 'read'}});
		expect(plain).toContain('String launcherName = UTIL_AsynchronousJobLauncher.class.getName();');
		expect(plain).not.toMatch(/\bkern(\.|__)/);
		expect(plain).toContain('WHERE ApexClass.Name LIKE :PROBE_CLASS_PATTERN AND Status IN :LIVE_STATUSES');
		expect(plain).not.toContain('NamespacePrefix = null');
		expect(scripts.renderScript('abortProbeJobs', {values: {__JOB_ID__: 'none', __ACTION__: 'abort'}})).toContain("final String JOB_ID = 'none';");
		const stop = lines.parseStoppedJobs(['PROBE STOP JOB id=707A status=Queued aborted=true',
			'PROBE STOP JOB id=707B status=Queued aborted=true class=ElasticProbeFiller', 'PROBE STOP JOBS action=abort found=2 aborted=2 left=2']);
		expect(stop).toEqual({printed: true, found: 2, aborted: 2, left: 2, jobs: [{id: '707A', status: 'Queued', aborted: true, className: null},
			{id: '707B', status: 'Queued', aborted: true, className: 'ElasticProbeFiller'}]});
		expect(lines.parseStoppedJobs([])).toMatchObject({printed: false, jobs: []});
	});

	it('names as not ended a job the run started or a job of a probe class, and passes over every other job', () =>
	{
		const job = (id, className, status) => ({id, className, status});
		const read = {jobs: [job('707Ru0000000001AAA', 'UTIL_AdaptiveAsynchronousProcessor', 'Queued'), job('707Ru0000000002AAA', 'ElasticProbeFiller', 'Processing'),
			job('707Ru0000000003AAA', 'ElasticProbeFiller', 'Completed'), job('707Ru0000000004AAA', 'SomeoneElsesJob', 'Queued'),
			job('707Ru0000000005AAA', 'UTIL_AdaptiveAsynchronousProcessor', 'Aborted')]};
		expect(checks.findLiveProbeJobs(read, ['707Ru0000000001', '707Ru0000000005AAA']).map((live) => live.id)).toEqual(['707Ru0000000001AAA', '707Ru0000000002AAA']);
		expect(checks.findLiveProbeJobs(null)).toEqual([]);
	});

	it('makes a dry-run script stop first and adds a stand-in only for a class it names that the org lacks', () =>
	{
		const apex = scripts.renderScript('spendBudget', {values: {__LEAVE__: 0, __BATCH__: 50}, dryRun: true, missingClasses: ['ElasticProbeFiller', 'API_RetryLiveGet']});
		expect(apex.startsWith('if(Datetime.now() != null)')).toBe(true);
		expect(apex).toContain('public class ElasticProbeFiller implements Queueable');
		expect(apex).not.toContain('public class API_RetryLiveGet');
		const launch = scripts.renderScript('launchAdaptiveProcessor', {namespace: '', dryRun: true, missingClasses: ['AccountArchiveProcessor'],
			values: {__ITEMS__: 3, __DELAY__: 1, __RUNS__: 1, __STRATEGY__: 'chainable', __JOB_SIZE__: 1}});
		expect(launch).toContain('public class AccountArchiveProcessor implements IF_Async.Processable');
		expect(scripts.isDryRunStop({compiled: true, compileProblem: '', exceptionMessage: `System.IllegalArgumentException: ${scripts.DRY_RUN_MARKER}`})).toBe(true);
		expect(scripts.isDryRunStop({compiled: false, compileProblem: 'Variable does not exist', exceptionMessage: ''})).toBe(false);
	});

	it('sets the lowered allowance in the settings file and refuses an allowance below 1', () =>
	{
		expect(scripts.renderLoweredSettings(110)).toContain('<asyncApexExecutionsOverride>110</asyncApexExecutionsOverride>');
		expect(scripts.renderRestoreSettings()).toContain('xsi:nil="true"');
		expect(() => scripts.renderLoweredSettings(0)).toThrow('at least 1');
		expect(() => scripts.renderScript('noSuchScript')).toThrow('No script named noSuchScript');
	});

	it('reads the override and elastic limits from a retrieved settings file, and finds the probe classes by name', () =>
	{
		expect(scripts.readApexSettings(scripts.renderLoweredSettings(110))).toMatchObject({override: 110});
		expect(scripts.readApexSettings(scripts.renderRestoreSettings())).toEqual({override: null, elastic: false});
		expect(scripts.readApexSettings('<ApexSettings/>')).toEqual({override: null, elastic: null});
		expect(scripts.readProbeClass('ElasticProbeSlowBatch').source).toContain('ElasticProbeSlowBatch');
		expect(scripts.readProbeClass('ElasticProbeUnknown')).toBeNull();
		expect(scripts.readProbeClass('../ElasticProbeFiller')).toBeNull();
	});
});

describe('the PROBE lines', () =>
{
	it('reads an Eastern time in winter and in summer as the right instant', () =>
	{
		expect(lines.parseProbeTime('2026-11-08 10:15:42').toISOString()).toBe('2026-11-08T15:15:42.000Z');
		expect(lines.parseProbeTime('2026-07-01 10:15:42').toISOString()).toBe('2026-07-01T14:15:42.000Z');
		expect(lines.parseProbeTime('null')).toBeNull();
		expect(() => lines.parseProbeTime('10:15')).toThrow('Not a probe time');
	});

	it('compares an ISO time in a message with the printed time as times, not as text', () =>
	{
		const [retryTime] = lines.findUtcTimes('tried again at 2026-11-08T15:15:42.000Z. The Next Retry field');
		expect(lines.isSameInstant(retryTime, lines.parseProbeTime('2026-11-08 10:15:42'))).toBe(true);
		expect(lines.isSameInstant(retryTime, lines.parseProbeTime('2026-11-08 10:15:44'))).toBe(false);
		expect(lines.isSameInstant(null, retryTime)).toBe(false);
	});

	it('reads a time in a log message only in whole seconds, with .000Z or Z, as Kern stores retry times', () =>
	{
		expect(lines.findUtcTimes('at 2026-11-08T15:15:42.000Z and 2026-11-08T15:16:42Z').map((time) => time.toISOString()))
			.toEqual(['2026-11-08T15:15:42.000Z', '2026-11-08T15:16:42.000Z']);
		expect(lines.findUtcTimes('the first is tried again at 2026-11-08T15:15:42.371Z')).toEqual([]);
		const nextRetry = new Date(START + 15 * MINUTE);
		const warning = (time) => ({calls: [{id: 'a00A', status: 'Retry', nextRetry, retries: 0}], issues: [], logs: [{level: 'WARN',
			at: 'kern.FLOW_CallApiAsync/invokeApiCallAsynchronously', created: new Date(START + 5 * SECOND), message: `the first is tried again at ${time}`}]});
		expect(checks.checkQueuedWaiting(warning(nextRetry.toISOString()), 'a00A', nextRetry, new Date(START)).pass).toBe(true);
		const withMilliseconds = checks.checkQueuedWaiting(warning(new Date(nextRetry.getTime() + 371).toISOString()), 'a00A', nextRetry, new Date(START));
		expect(withMilliseconds.reasons).toEqual(['the warning does not name the retry time as an ISO 8601 time: the first is tried again at 2026-11-08T15:15:00.371Z']);
	});

	it('reads a read-budget run and a log entry context, and passes over the lines it has no use for', () =>
	{
		const read = lines.parseReadBudget([
			'PROBE BUDGET time=2026-11-08 10:00:00 used=100 maximum=110 remaining=10',
			'PROBE CALL pending id=a00X status=Retry nextRetry=2026-11-08 10:15:00 retries=0 created=2026-11-08 10:00:00 modified=2026-11-08 10:00:00 errors=null',
			'PROBE ISSUE id=a01X name=I-1 status=Open call=a00X created=2026-11-08 10:00:00 mayHaveActed=true errors=No background job',
			'PROBE LOG level=ERROR at=kern.UTIL_AdaptiveAsynchronousProcessor/enqueueNextHop record=707X created=2026-11-08 10:02:00 message=refused context={"jobScope":"a,b"}',
			'PROBE JOB id=707X class=UTIL_AdaptiveAsynchronousProcessor type=Queueable status=Completed created=2026-11-08 10:01:00 completed=null errors=0 extended=null',
			'PROBE LIVE class=ElasticProbeFiller status=Queued count=3',
			'PROBE LIVE class=ElasticProbeFiller status=Processing count=1',
			'PROBE LIVE class=UTIL_AdaptiveAsynchronousProcessor status=Holding count=1',
			'PROBE GATE remaining=10 probeSchedules=0 pendingCalls=1 outboundInterviews=0 runningChains=0 liveJobs=5',
			'PROBE SOMETHING else'
		]);
		expect(read.budget).toMatchObject({used: 100, maximum: 110, remaining: 10});
		expect(read.calls[0]).toMatchObject({id: 'a00X', status: 'Retry', retries: 0, errors: null});
		expect(read.issues[0]).toMatchObject({mayHaveActed: true, status: 'Open'});
		expect(read.logs[0]).toMatchObject({message: 'refused', context: '{"jobScope":"a,b"}'});
		expect(read.jobs[0]).toMatchObject({status: 'Completed', className: 'UTIL_AdaptiveAsynchronousProcessor'});
		expect(read.gate).toMatchObject({pendingCalls: 1, liveJobs: 5});
		expect(lines.splitLogMessage('x/execute', 'a context=b')).toEqual({message: 'a context=b', context: null});
	});

	it('reads the insert, spend, launch, schedule, schedule sweep and clean-up lines', () =>
	{
		const insert = lines.parseInsert(['PROBE CALL INSERT time=2026-11-08 10:00:00 mode=queued remaining=0 rowsBefore=0', 'PROBE CALL INSERT saved id=a00X',
			'PROBE CALL INSERT rowExists=true id=a00X status=Retry nextRetry=2026-11-08 10:15:00 retries=0 errors=text',
			'PROBE CALL INSERT job id=707X class=Filler status=Queued']);
		expect(insert).toMatchObject({savedId: 'a00X', refused: null, row: {exists: true, status: 'Retry', errors: 'text'}, jobs: [{className: 'Filler'}]});
		expect(lines.parseInsert(['PROBE CALL INSERT refused DmlException: no', 'PROBE CALL INSERT rowExists=false']))
			.toMatchObject({refused: 'DmlException: no', row: {exists: false}});
		expect(lines.parseSpend(['PROBE SPEND time=x maximum=110 remainingBefore=10 leave=2 toQueue=8', 'PROBE SPEND queued=8 remainingAfterEnqueueSameTransaction=2 firstJob=a',
			'PROBE SPEND refused at job 3: LimitException: no'])).toMatchObject({toQueue: 8, queued: 8, remainingAfter: 2, refused: 'at job 3: LimitException: no'});
		expect(lines.parseLauncher(['PROBE LAUNCHER items=a,b,c run=0', 'PROBE LAUNCHER run=0 accepted job=707X class=C type=Queueable status=Queued']))
			.toMatchObject({accountIds: ['a', 'b', 'c'], accepted: true, jobId: '707X', type: 'Queueable'});
		expect(lines.parseLauncher(['PROBE LAUNCHER items= run=0', 'PROBE LAUNCHER run=0 refused LaunchRefusedException: no']))
			.toMatchObject({accountIds: [], refused: 'LaunchRefusedException: no'});
		const scheduleLine = 'PROBE SCHEDULE ONCE name=Elastic Probe Outbound Retry Watchdog 1 cronId=08eX fireAt=2026-11-08 10:01:00 cron=0 1 10 8 11 ? 2026 threshold=1';
		expect(lines.parseScheduleOnce([scheduleLine]))
			.toMatchObject({cronId: '08eX', threshold: '1'});
		expect(lines.parseScheduleOnce([])).toBeNull();
		expect(lines.parseScheduleSweep(['SECTION89 SCHEDULE LEFT id=08eY name=Elastic Probe Outbound Retry Watchdog 2', 'SECTION89 SCHEDULES action=abort aborted=1 left=1']))
			.toEqual({printed: true, aborted: 1, left: [{id: '08eY', name: 'Elastic Probe Outbound Retry Watchdog 2'}]});
		expect(lines.parseScheduleSweep([])).toEqual({printed: false, aborted: null, left: []});
		expect(lines.parseLeft(['PROBE LEFT calls=0 kept=none', 'PROBE LEFT probe flow interviews=unknown'])).toEqual({calls: '0', 'probe flow interviews': 'unknown'});
		expect(lines.readDebugLines('x|USER_DEBUG|[1]|DEBUG|PROBE A\nother')).toEqual(['PROBE A']);
	});
});

describe('the pass and fail rules', () =>
{
	it('leaves the eleventh job of the run without a place: the chainable launch next job and the outbound send are refused', () =>
	{
		const plan = checks.planAllowance(USED);
		let remaining = plan.allowance - USED;
		expect(remaining).toBe(checks.ALLOWANCE_HEADROOM);
		remaining -= plan.firstSpend;
		expect(remaining).toBe(checks.LEAVE_BEFORE_LAUNCH);
		remaining -= plan.launchJobs;
		expect(plan).toEqual({allowance: LOWERED, firstSpend: 9, launchJobs: 1});
		expect(remaining).toBe(0);
	});

	it('passes the gate only on two agreeing reads with nothing running', () =>
	{
		const read = (remaining, liveJobs) => ({budget: {used: 1, maximum: 9, remaining}, gate: {probeSchedules: 0, pendingCalls: 0, runningChains: 0, liveJobs}});
		expect(checks.checkGate(read(8, 0), read(8, 0)).pass).toBe(true);
		expect(checks.checkGate(read(8, 0), read(7, 2)).reasons).toEqual(['the remaining count moved from 8 to 7 between the two reads', 'liveJobs=2, not 0']);
		expect(checks.checkGate(null, read(8, 0)).pass).toBe(false);
	});

	it('names every foreign call waiting to be sent and leaves the run own calls out', () =>
	{
		const records = [{id: 'a00Ru0000000001AAA', status: 'Retry'}, {id: 'a00Ru0000000002AAA', status: 'Queued'}, {id: 'a00Ru0000000003AAA', status: 'Failed'}];
		expect(checks.findForeignCalls(records, ['a00Ru0000000001'])).toEqual([{id: 'a00Ru0000000002AAA', status: 'Queued'}]);
	});

	it('reads when a queued job is counted from the places left straight after the launch, and fails any other count', () =>
	{
		const jobId = '707Ru0000000001AAA';
		const read = (remaining, status = 'Queued') => ({budget: {remaining}, jobs: [{id: jobId, status}]});
		expect(checks.checkPlacesLeftAfterLaunch(read(0), jobId)).toEqual({pass: true, reasons: [],
			values: {remainingAfterLaunch: 0, firstJobStatusAfterLaunch: 'Queued', countsWhen: 'queued'}});
		expect(checks.checkPlacesLeftAfterLaunch(read(1, 'Holding'), jobId)).toEqual({pass: true, reasons: [],
			values: {remainingAfterLaunch: 1, firstJobStatusAfterLaunch: 'Holding', countsWhen: 'run'}});
		const freed = checks.checkPlacesLeftAfterLaunch(read(2), jobId);
		expect(freed).toMatchObject({pass: false, values: {remainingAfterLaunch: 2, countsWhen: null}});
		expect(freed.reasons).toEqual(['remaining=2 straight after the launch, not 0 or 1: the rolling 24 hours freed a place, or another job took one, '
			+ 'so the refused next job cannot be proved']);
		expect(checks.checkPlacesLeftAfterLaunch(read(-1), jobId).reasons[0]).toContain('remaining=-1 straight after the launch, not 0 or 1');
		expect(checks.checkPlacesLeftAfterLaunch({}, jobId).reasons).toEqual(['the read after the launch printed no PROBE BUDGET line']);
	});

	it('records when a job is counted as not measured when the first job no longer waits in the read after the launch, and still passes', () =>
	{
		const jobId = '707Ru0000000001AAA';
		for(const status of ['Processing', 'Completed'])
		{
			expect(checks.checkPlacesLeftAfterLaunch({budget: {remaining: 0}, jobs: [{id: jobId, status}]}, jobId)).toEqual({pass: true, reasons: [],
				values: {remainingAfterLaunch: 0, firstJobStatusAfterLaunch: status, countsWhen: 'not-measured'}});
		}
		expect(checks.checkPlacesLeftAfterLaunch({budget: {remaining: 1}, jobs: []}, jobId)).toMatchObject({pass: true,
			values: {firstJobStatusAfterLaunch: 'not read', countsWhen: 'not-measured'}});
	});

	it('fails the refused next job when a second job started or the entry lists other Accounts', () =>
	{
		const {runStart, launch, job, entry} = createRefusedNextHop();
		const atLimit = {remaining: 0};
		const passed = checks.checkNextHop(launch, {budget: atLimit, jobs: [job], logs: [entry]}, runStart);
		expect(passed).toMatchObject({pass: true, values: {remainingAfterHop: 0, refusal: LIMIT_REFUSAL_MESSAGE}});
		const second = {...job, id: '707B', created: new Date(START + 2 * MINUTE)};
		expect(checks.checkNextHop(launch, {budget: atLimit, jobs: [second, job], logs: [entry]}, runStart).reasons[0])
			.toContain('another UTIL_AdaptiveAsynchronousProcessor job started');
		const wrongScope = {...entry, context: ACCOUNT_IDS[2]};
		expect(checks.checkNextHop(launch, {budget: atLimit, jobs: [job], logs: [wrongScope]}, runStart).reasons[0]).toContain('not the second and third Accounts');
		const refused = {...launch, accepted: false, refused: 'LaunchRefusedException: no', accountIds: []};
		expect(checks.checkNextHop(refused, {jobs: [], logs: []}, runStart).reasons).toHaveLength(5);
		expect(checks.isNextHopSettled({jobs: [job], logs: []}, '707A', runStart)).toBe(false);
	});

	it('fails the refused next job when its entry gives another error than the 24-hour limit, or a place is left after the first job', () =>
	{
		const {runStart, launch, job, entry} = createRefusedNextHop();
		const otherError = 'System.AsyncException: Maximum stack depth has been reached.';
		const other = checks.checkNextHop(launch, {budget: {remaining: 0}, jobs: [job], logs: [{...entry, message: otherError}]}, runStart);
		expect(other).toMatchObject({pass: false, values: {refusal: otherError}});
		expect(other.reasons).toEqual([`the entry's message does not name the 24-hour limit (AsyncApexExecutions Limit exceeded): ${otherError}`]);
		const placeLeft = checks.checkNextHop(launch, {budget: {remaining: 1}, jobs: [job], logs: [entry]}, runStart);
		expect(placeLeft).toMatchObject({pass: false, values: {remainingAfterHop: 1}});
		expect(placeLeft.reasons).toEqual(['remaining=1 after the first job, not 0']);
	});

	it('passes the save at the limit only when the message names the Next Retry time in whole seconds', () =>
	{
		const nextRetry = START + 15 * MINUTE;
		const insert = {start: {time: new Date(START), remaining: 0}, savedId: 'a00A', refused: null, jobs: [],
			row: {exists: true, id: 'a00A', status: 'Retry', nextRetry: new Date(nextRetry), retries: 0, errors: launchRefusedText(nextRetry)}};
		expect(checks.checkQueuedInsert(insert).pass).toBe(true);
		const noFraction = {...insert, row: {...insert.row, errors: insert.row.errors.replace('.000Z', 'Z')}};
		expect(checks.checkQueuedInsert(noFraction).pass).toBe(true);
		const withMilliseconds = {...insert, row: {...insert.row, errors: launchRefusedText(nextRetry + 371)}};
		expect(withMilliseconds.row.errors).toContain('.371Z');
		expect(checks.checkQueuedInsert(withMilliseconds).reasons[0]).toContain('the error text is not the refused-start message');
		const wrongTime = {...insert, row: {...insert.row, errors: launchRefusedText(nextRetry + 5 * SECOND)}};
		expect(checks.checkQueuedInsert(wrongTime).reasons[0]).toContain('but Next Retry is');
		const oldWording = {...insert, row: {...insert.row, errors: insert.row.errors.replace('Z. The Next', 'Z (UTC). The Next')}};
		expect(checks.checkQueuedInsert(oldWording).reasons[0]).toContain('the error text is not the refused-start message');
		const sent = {...insert, start: {time: new Date(START), remaining: 3}, jobs: [{id: '707A', className: 'UTIL_AdaptiveAsynchronousProcessor'}],
			row: {...insert.row, errors: 'other'}};
		expect(checks.checkQueuedInsert(sent).reasons).toEqual(expect.arrayContaining(['the save ran with remaining=3, not 0 or less', 'a send job started: 707A']));
		expect(checks.readLaunchRefusedText(null)).toBeNull();
	});

	it('names what is wrong when the allowance, the retry or the watchdog pass did not go as expected', () =>
	{
		const budget = {budget: {maximum: 250000, remaining: 5, time: new Date(START)}, gate: {liveJobs: 1, pendingCalls: 1}, calls: [], issues: [], logs: [], jobs: []};
		expect(checks.checkLowered(false, budget, 110).reasons).toEqual(['the settings deploy failed', 'maximum=250000, not 110']);
		expect(checks.checkSpentToLaunchLine(budget).reasons).toEqual(['remaining=5, not 1', 'liveJobs=1, not 0']);
		expect(checks.checkRestored(true, budget, 250000, 'a00A', new Date(START)).reasons[0]).toContain('it moved before its retry time');
		const call = {id: 'a00A', status: 'Retry', nextRetry: new Date(START), nextRetryText: 'x', retries: 1};
		const retry = checks.checkRetrySent({...budget, calls: [call], issues: [{call: 'a00A', status: 'Open', mayHaveActed: true}],
			jobs: [{className: 'UTIL_AdaptiveAsynchronousProcessor', status: 'Completed', created: new Date(START - MINUTE)}]},
		'a00A', new Date(START - 2 * MINUTE), new Date(START));
		expect(retry.reasons).toHaveLength(5);
		expect(checks.isRetrySettled({...budget, calls: [call]}, 'a00A')).toBe(false);
		const watchdog = checks.checkWatchdog({...budget, calls: [call], logs: [{level: 'WARN', at: 'SCHED_OutboundRetryWatchdog/execute', record: 'a00B', created: new Date(START),
			message: 'The retry of this call was due at 2026-11-08T15:00:00.000Z, but it did not start.'}]}, 'a00B', 'a00A', new Date(START), new Date(START));
		expect(watchdog.reasons).toEqual(expect.arrayContaining(['a "retry time moved" warning does not name both times as ISO 8601 times',
			'the watchdog job is missing, not Completed']));
		expect(checks.checkRetryingInsert({savedId: null, refused: 'no', row: {exists: false}}).pass).toBe(false);
		expect(checks.findLeftovers({calls: '0'})).toContain('issues=not printed');
	});

	it('gives BLOCKED only when nothing failed, and never PASS for a blocked or interrupted run', () =>
	{
		expect(checks.decideResult([{status: 'PASS'}, {status: 'PASS'}])).toBe('PASS');
		expect(checks.decideResult([{status: 'PASS'}, {status: 'BLOCKED'}])).toBe('BLOCKED');
		expect(checks.decideResult([{status: 'BLOCKED'}, {status: 'FAIL'}])).toBe('FAIL');
		expect(checks.decideResult([{status: 'INTERRUPTED'}, {status: 'PASS'}])).toBe('FAIL');
		expect(checks.decideResult([])).toBe('FAIL');
	});
});

describe('the waits', () =>
{
	it('reads until the condition holds, on a fake clock', async() =>
	{
		const clock = {time: 0, now: () => clock.time, sleep: async(milliseconds) =>
		{
			clock.time += milliseconds;
		}};
		let value = 0;
		const readNext = () =>
		{
			value += 1;
			return value;
		};
		const done = await pollUntil({read: readNext, isDone: (current) => current === 3, intervalMilliseconds: 30 * SECOND, timeLimitMilliseconds: 5 * MINUTE, clock});
		expect(done).toEqual({done: true, value: 3, reads: 3});
		expect(clock.time).toBe(MINUTE);
		const late = await pollUntil({read: () => 0, isDone: () => false, intervalMilliseconds: MINUTE, timeLimitMilliseconds: 3 * MINUTE, clock});
		expect(late).toEqual({done: false, value: 0, reads: 4});
	});

	it('ends a wait at once when the run is interrupted', async() =>
	{
		const signal = {interrupted: false};
		const clock = createClock(signal);
		await clock.sleep(5);
		signal.interrupted = true;
		await expect(clock.sleep(60 * SECOND)).rejects.toBeInstanceOf(InterruptedError);
		expect(clock.now()).toBeGreaterThan(0);
	});
});

describe('the whole run on an org that behaves as expected', () =>
{
	it('passes every step in order and puts the org back', async() =>
	{
		const fake = createFakeOrg();
		const context = contextFor(fake);
		const result = await runSection(context);
		expect(context.steps.filter((step) => step.status !== 'PASS')).toEqual([]);
		expect(stepLines(context)).toEqual(['GUARD PASS', '89a PASS', 'SETUP PASS', '89b PASS', '89c PASS', '89c-hop PASS', '89d PASS', '89e PASS', '89f PASS', '89g PASS',
			'89h PASS']);
		expect(result).toBe('PASS');
		expect(fake.model.maximum).toBe(LICENSED);
		expect(fake.model.classes.size).toBe(0);
		expect(fake.commands).toContain('delete ApexClass:ElasticProbeFiller 89h-delete-ElasticProbeFiller');
		expect(context.output.some((line) => line.startsWith('SECTION89 VALUES 89f sendJobs=2 issues=1 firstSendAt='))).toBe(true);
		expect(() => checkShellSafe(fake.commands.flatMap((command) => command.split(' ').slice(1)))).not.toThrow();
	});

	const countingModels = [
		['run', 'filler jobs run 50 seconds after they are queued', FILLER_RUN_DELAY, 1],
		['run', 'filler jobs run at once', 0, 1],
		['run', 'filler jobs run 4 minutes after they are queued', 4 * MINUTE, 1],
		['queued', 'filler jobs run 50 seconds after they are queued', FILLER_RUN_DELAY, 0]
	];

	it.each(countingModels)('spends to 1 place left, queues no filler job after the launch and has the next hop refused when a job is counted when it is %s (%s)',
		async(countsWhen, situation, fillerRunDelay, remainingAfterLaunch) =>
		{
			const fake = createFakeOrg({countsWhen, fillerRunDelay});
			const context = contextFor(fake);
			const result = await runSection(context);
			const plan = checks.planAllowance(USED);
			expect(fake.model.spends.map((spend) => spend.label)).toEqual(['89c-spend']);
			expect(fake.model.spends[0]).toMatchObject({queued: plan.firstSpend, liveFillers: 0});
			const jobsAfterLaunch = fake.model.jobs.slice(fake.model.jobs.indexOf(fake.model.launch.job) + 1);
			expect(jobsAfterLaunch.filter((job) => job.className === FILLER_CLASS)).toEqual([]);
			expect(context.steps.find((step) => step.step === '89c')).toMatchObject({status: 'PASS', values: {remaining: 1, queued: plan.firstSpend}});
			expect(context.output).toContain('SECTION89 VALUES 89c remaining=1 queued=9 planned=9');
			const hop = context.steps.find((step) => step.step === '89c-hop');
			expect(hop).toMatchObject({status: 'PASS', values: {remainingAfterLaunch, countsWhen, remainingAfterHop: 0, entries: 1, jobStatus: 'Completed',
				refusal: LIMIT_REFUSAL_MESSAGE}});
			const measured = ` remainingAfterLaunch=${remainingAfterLaunch} firstJobStatusAfterLaunch=Queued countsWhen=${countsWhen}`;
			expect(context.output.some((line) => line.startsWith('SECTION89 VALUES 89c-hop ') && line.endsWith(measured))).toBe(true);
			const savedAt = context.steps.find((step) => step.step === '89d').values.insertedAt.getTime();
			expect(fake.model.jobs.filter((job) => job.className === checks.PROCESSOR_CLASS && job.created < savedAt)).toHaveLength(1);
			expect(result).toBe('PASS');
		});

	it.each(['run', 'queued'])('fails the next hop step, naming the count, when a place was freed just as the launch was accepted (a job is counted when it is %s)',
		async(countsWhen) =>
		{
			const fake = createFakeOrg({countsWhen, placesFreedAtLaunch: countsWhen === 'run' ? 1 : 2});
			const context = contextFor(fake);
			const result = await runSection(context);
			expect(result).toBe('FAIL');
			const hop = context.steps.find((step) => step.step === '89c-hop');
			expect(hop).toMatchObject({status: 'FAIL', values: {remainingAfterLaunch: 2, countsWhen: null}});
			expect(hop.reason).toBe('remaining=2 straight after the launch, not 0 or 1: the rolling 24 hours freed a place, or another job took one, so the refused next '
				+ 'job cannot be proved; nothing was spent after the launch, and the run goes to the clean-up');
			expect(stepLines(context)).toEqual(['GUARD PASS', '89a PASS', 'SETUP PASS', '89b PASS', '89c PASS', '89c-hop FAIL', 'STOP FAIL', '89h PASS']);
			expect(fake.model.spends.map((spend) => spend.label)).toEqual(['89c-spend']);
			const afterLaunch = fake.commands.indexOf('apex 89c-hop-launch');
			expect(fake.commands.slice(afterLaunch + 1, afterLaunch + 5)).toEqual([expect.stringMatching(/^apex 89c-hop-after-launch-\d+$/),
				'apex 89h-stop-probe-jobs-abort', 'apex 89h-stop-probe-jobs-read', 'deploy Settings:Apex 89h-settings']);
			expect(fake.model.launch.job.status).toBe('Aborted');
			expect(fake.model.jobs.filter((job) => job.className === checks.PROCESSOR_CLASS)).toHaveLength(1);
			expect(context.steps.at(-1)).toMatchObject({step: '89h', status: 'PASS', values: {stoppedJobs: 1}});
			expect(fake.model.maximum).toBe(LICENSED);
		});

		it('fails the clean-up, naming the job, when the stop leaves the chain job waiting', async() =>
		{
			const fake = createFakeOrg({placesFreedAtLaunch: 1, processorAbortIgnored: true});
			const context = contextFor(fake);
			expect(await runSection(context)).toBe('FAIL');
			const jobId = fake.model.launch.job.id;
			expect(fake.model.launch.job.status).toBe('Queued');
			const cleanUp = context.steps.at(-1);
			expect(cleanUp).toMatchObject({step: '89h', status: 'FAIL'});
			expect(cleanUp.reason).toContain(`stop the probe jobs: not ended: ${jobId} (UTIL_AdaptiveAsynchronousProcessor Queued)`);
			expect(cleanUp.reason).toContain(`final read: probe jobs not ended: ${jobId} (UTIL_AdaptiveAsynchronousProcessor Queued)`);
		});

	it('records when a job is counted as not measured when the read after the launch comes after the first job ran, and the next hop still passes', async() =>
	{
		const fake = createFakeOrg({countsWhen: 'run'});
		const context = contextFor(fake);
		const original = fake.org.runApex.getMockImplementation();
		fake.org.runApex.mockImplementation((apex, label) =>
		{
			if(label.startsWith('89c-hop-after-launch'))
			{
				fake.clock.time += 2 * MINUTE;
			}
			return original(apex, label);
		});
		expect(await runSection(context)).toBe('PASS');
		const hop = context.steps.find((step) => step.step === '89c-hop');
		expect(hop).toMatchObject({status: 'PASS', values: {remainingAfterLaunch: 0, firstJobStatusAfterLaunch: 'Completed', countsWhen: 'not-measured', remainingAfterHop: 0}});
		expect(context.output.some((line) => line.startsWith('SECTION89 89c-hop The chain\'s first job had already left the queue (Completed)'))).toBe(true);
		expect(context.output.some((line) => line.startsWith('SECTION89 VALUES 89c-hop ') && line.endsWith(' countsWhen=not-measured'))).toBe(true);
	});

	it('fails the next hop step with no countsWhen on its line when a place freed just before the launch let the next job start', async() =>
	{
		const fake = createFakeOrg({countsWhen: 'queued', placesFreedAtLaunch: 1});
		const context = contextFor(fake);
		expect(await runSection(context)).toBe('FAIL');
		const hop = context.steps.find((step) => step.step === '89c-hop');
		expect(hop).toMatchObject({status: 'FAIL', values: {remainingAfterLaunch: 1, firstJobStatusAfterLaunch: 'Queued', entries: 0}});
		expect(hop.values).not.toHaveProperty('countsWhen');
		expect(hop.reason).toContain('another UTIL_AdaptiveAsynchronousProcessor job started after the first');
		const valuesLine = context.output.find((line) => line.startsWith('SECTION89 VALUES 89c-hop '));
		expect(valuesLine).toContain('remainingAfterLaunch=1');
		expect(valuesLine).not.toContain('countsWhen=');
		expect(context.steps.at(-1)).toMatchObject({step: '89h', status: 'PASS'});
	});

	it('fails the next hop step on the job class when the chainable launch sets its delay through the launcher\'s delayed dispatch', async() =>
	{
		const fake = createFakeOrg();
		const context = contextFor(fake);
		const original = fake.org.runApex.getMockImplementation();
		const delayedDispatchScripts = [];
		fake.org.runApex.mockImplementation((apex, label) =>
		{
			let sent = apex;
			if(label === '89c-hop-launch')
			{
				sent = apex.replace(/\t\tif\(DELAY_MINUTES > 0\)\n\t\t\{\n[\s\S]*?request\.withAsyncOptions\(options\);\n\t\t}\n/, '')
					.replace('else if(DELAY_MINUTES > 0)', 'if(DELAY_MINUTES > 0)');
				delayedDispatchScripts.push(sent);
			}
			return original(sent, label);
		});
		expect(await runSection(context)).toBe('FAIL');
		expect(delayedDispatchScripts).toHaveLength(1);
		expect(delayedDispatchScripts[0]).not.toContain('request.withAsyncOptions(');
		expect(delayedDispatchScripts[0]).toContain('request.withDelayMinutes(DELAY_MINUTES);');
		const hop = context.steps.find((step) => step.step === '89c-hop');
		expect(hop).toMatchObject({status: 'FAIL', values: {entries: 0}});
		expect(hop.reason).toContain(`the launch was not accepted as a ${checks.PROCESSOR_CLASS} Queueable (class=${LAUNCHER_CLASS} type=Queueable)`);
		expect(fake.model.launch.job.className).toBe(LAUNCHER_CLASS);
		expect(fake.org.runApex.mock.calls.some(([, label]) => label.startsWith('89c-hop-wait-'))).toBe(false);
		expect(context.steps.at(-1)).toMatchObject({step: '89h', status: 'PASS'});
	});

	it('spends the place freed before the save and waits until the filler job has run and none is left, then saves at the limit', async() =>
	{
		const fake = createFakeOrg({countsWhen: 'run', placesFreedBeforeSave: 1});
		const context = contextFor(fake);
		expect(await runSection(context)).toBe('PASS');
		expect(fake.model.spends.map((spend) => spend.label)).toEqual(['89c-spend', '89d-spend']);
		const filler = fake.model.jobs.filter((job) => job.className === FILLER_CLASS).at(-1);
		const saved = context.steps.find((step) => step.step === '89d');
		expect(saved.status).toBe('PASS');
		expect(saved.values.insertedAt.getTime()).toBeGreaterThanOrEqual(filler.created + FILLER_RUN_DELAY);
		expect(fake.commands.filter((command) => command.startsWith('apex 89d-spent-')).length).toBeGreaterThan(1);
	});

	it('stops with BLOCKED and changes nothing when another outbound call waits before the start', async() =>

	{
		const fake = createFakeOrg({foreign: {guard: [{id: 'a00Ru0000000999AAA', status: 'Retry'}]}});
		const context = contextFor(fake);
		const result = await runSection(context);
		expect(result).toBe('BLOCKED');
		expect(exitCodeFor(result)).toBe(3);
		expect(context.output).toContain('SECTION89 GUARD BLOCKED a00Ru0000000999AAA:Retry');
		expect(context.output.some((line) => line.includes('Nothing on the org was changed'))).toBe(true);
		expect(fake.org.runApex).not.toHaveBeenCalled();
		expect(fake.org.deploy).not.toHaveBeenCalled();
	});

	it('skips only the watchdog pass when a foreign call appears mid-run, keeps the earlier steps and still cleans up', async() =>
	{
		const fake = createFakeOrg({foreign: {'89g-guard': [{id: 'a00Ru0000000999AAA', status: 'Queued'}]}});
		const context = contextFor(fake);
		const result = await runSection(context);
		expect(result).toBe('BLOCKED');
		expect(stepLines(context)).toEqual(['GUARD PASS', '89a PASS', 'SETUP PASS', '89b PASS', '89c PASS', '89c-hop PASS', '89d PASS', '89e PASS', '89f PASS', '89g BLOCKED',
			'89h PASS']);
		expect(context.output).toContain('SECTION89 89g BLOCKED a00Ru0000000999AAA:Queued');
		expect(fake.commands.some((command) => command.startsWith('apex 89g-insert'))).toBe(false);
		expect(fake.commands).toContain('apex 89h-clean-up');
	});

	it('runs the clean-up after a FAIL, putting the lowered allowance back', async() =>
	{
		const fake = createFakeOrg();
		const context = contextFor(fake);
		const original = fake.org.runApex.getMockImplementation();
		fake.org.runApex.mockImplementation((apex, label) => (label.startsWith('89c-spend') ? {exitCode: 1, success: false, compileProblem: '', exceptionMessage: 'LimitException',
			debugLines: [], file: 'f'} : original(apex, label)));
		const result = await runSection(context);
		expect(result).toBe('FAIL');
		expect(context.output.some((line) => line.startsWith('SECTION89 ERROR FAIL 89c-spend failed: LimitException'))).toBe(true);
		expect(fake.commands).toContain('deploy Settings:Apex 89h-settings');
		expect(fake.model.maximum).toBe(LICENSED);
		expect(context.steps.at(-1)).toMatchObject({step: '89h', status: 'PASS'});
	});

	it('runs the clean-up after an interrupt during a wait, names the step, and the clean-up is not interrupted', async() =>
	{
		const fake = createFakeOrg();
		const context = contextFor(fake);
		const sleep = fake.clock.sleep;
		fake.clock.sleep = async(milliseconds) =>
		{
			if(context.state.lowered && !context.signal.cleaningUp)
			{
				throw new InterruptedError();
			}
			await sleep(milliseconds);
		};
		const result = await runSection(context);
		expect(result).toBe('FAIL');
		expect(context.output.some((line) => line.startsWith('SECTION89 89c INTERRUPTED stopped by Ctrl-C'))).toBe(true);
		expectFillerJobsStopped(context, fake);
		expect(fake.model.maximum).toBe(LICENSED);
	});

	it('fails the clean-up, naming each filler job, when a filler job stays Queued after the stop', async() =>
	{
		const fake = createFakeOrg({stuckSpendLabels: ['89c-spend'], fillerAbortIgnored: true});
		const context = contextFor(fake);
		const sleep = fake.clock.sleep;
		fake.clock.sleep = async(milliseconds) =>
		{
			if(context.state.lowered && !context.signal.cleaningUp)
			{
				throw new InterruptedError();
			}
			await sleep(milliseconds);
		};
		expect(await runSection(context)).toBe('FAIL');
		const fillers = fake.model.jobs.filter((job) => job.className === FILLER_CLASS);
		expect(fillers.every((job) => job.status === 'Queued')).toBe(true);
		const named = fillers.map((job) => `${job.id} (${FILLER_CLASS} Queued)`).join(', ');
		const cleanUp = context.steps.at(-1);
		expect(cleanUp).toMatchObject({step: '89h', status: 'FAIL'});
		expect(cleanUp.reason).toContain(`stop the probe jobs: not ended: ${named}`);
		expect(cleanUp.reason).toContain(`final read: probe jobs not ended: ${named}`);
	});

	it('fails the clean-up when a probe row is left, and says which', async() =>
	{
		const fake = createFakeOrg();
		const context = contextFor(fake);
		const original = fake.org.runApex.getMockImplementation();
		fake.org.runApex.mockImplementation((apex, label) =>
		{
			const answer = original(apex, label);
			return label === '89h-clean-up' ? {...answer, debugLines: answer.debugLines.map((line) => line.replace('issues=0', 'issues=2'))} : answer;
		});
		await runSection(context);
		expect(context.steps.at(-1)).toMatchObject({step: '89h', status: 'FAIL', reason: 'probe clean-up: left issues=2'});
	});

	it('runs the dry run: compiles every script, renders the settings, makes and stops the schedule, and deploys nothing', async() =>
	{
		const fake = createFakeOrg();
		const context = contextFor(fake, {dryRun: true});
		const result = await runSection(context);
		expect(stepLines(context)).toEqual(['GUARD PASS', '89a PASS', 'DRY-COMPILE PASS', 'DRY-SETTINGS PASS', 'DRY-WATCHDOG PASS']);
		expect(context.output).toContain('SECTION89 DRY-COMPILE PASS 14 scripts compiled with their tokens filled and stopped before their first statement');
		expect(fake.commands).toContain('apex dry-compile-12-abortProbeJobs');
		expect(result).toBe('PASS');
		expect(fake.org.deploy).not.toHaveBeenCalled();
		expect(fake.model.schedule.aborted).toBe(true);
		expect(fake.commands.some((command) => command.startsWith('apex dry-schedules'))).toBe(false);
	});

	it('stops the dry run schedule by name when its id cannot be read, and reads again', async() =>
	{
		const fake = createFakeOrg({scheduleIdUnread: true});
		const context = contextFor(fake, {dryRun: true});
		const result = await runSection(context);
		expect(stepLines(context)).toEqual(['GUARD PASS', '89a PASS', 'DRY-COMPILE PASS', 'DRY-SETTINGS PASS', 'DRY-WATCHDOG FAIL', 'SCHEDULE-STOP PASS']);
		expect(fake.commands).toEqual(expect.arrayContaining(['apex dry-schedules-abort', 'apex dry-schedules-read']));
		expect(fake.model.schedule.aborted).toBe(true);
		expect(result).toBe('FAIL');
	});

	it('fails the dry run and names the schedule with its id when the stop by name leaves it', async() =>
	{
		const fake = createFakeOrg({scheduleIdUnread: true, scheduleStuck: true});
		const context = contextFor(fake, {dryRun: true});
		expect(await runSection(context)).toBe('FAIL');
		const stop = context.steps.find((step) => step.step === 'SCHEDULE-STOP');
		expect(stop).toMatchObject({status: 'FAIL'});
		expect(stop.reason).toContain(`still scheduled: ${fake.model.schedule.cronId} (Elastic Probe Outbound Retry Watchdog 1)`);
	});

	it('stops the watchdog schedule by name in the clean-up when the run could not read its id', async() =>
	{
		const fake = createFakeOrg({scheduleIdUnread: true});
		const context = contextFor(fake);
		await runSection(context);
		expect(fake.commands).toEqual(expect.arrayContaining(['apex 89h-schedules-abort', 'apex 89h-schedules-read']));
		expect(fake.commands).not.toContain('apex 89h-abort-schedule');
		expect(context.steps.at(-1)).toMatchObject({step: '89h', status: 'PASS'});
	});

	it('stops before any change when Kern or the subscriber classes are missing', async() =>
	{
		const fake = createFakeOrg();
		fake.org.query.mockImplementation((soql, label) => (label === 'namespace' ? [{NamespacePrefix: null}] : []));
		const context = contextFor(fake);
		expect(await runSection(context)).toBe('FAIL');
		expect(context.namespace).toBe('');
		expect(context.output[0]).toBe('SECTION89 SETUP FAIL the org lacks API_RetryLiveGet, AccountArchiveProcessor (Phase 1.4)');
		fake.org.query.mockImplementation(() => []);
		expect(await runSection(contextFor(fake))).toBe('FAIL');
		expect(fake.org.deploy).not.toHaveBeenCalled();
	});
});

describe('a Ctrl-C that stops an sf command', () =>
{
	it('reports the step as INTERRUPTED, not FAIL, when its command ended by a signal after Ctrl-C, and still cleans up', async() =>
	{
		const fake = createFakeOrg();
		const context = contextFor(fake);
		const original = fake.org.runApex.getMockImplementation();
		// noinspection FunctionWithMultipleReturnPointsJS
		fake.org.runApex.mockImplementation((apex, label) =>
		{
			if(label === '89c-spend')
			{
				context.signal.interrupted = true;
				return {exitCode: 1, signal: 'SIGTERM', success: false, compileProblem: '', exceptionMessage: '', debugLines: [], file: 'f'};
			}
			return original(apex, label);
		});
		const result = await runSection(context);
		expect(result).toBe('FAIL');
		expect(context.output).toContain('SECTION89 89c INTERRUPTED stopped by Ctrl-C (the sf command was stopped by SIGTERM); the org is put back next if anything on it changed');
		expectInterruptedRunPutBack(context, fake);
	});

	it('reports a command ended by SIGINT as interrupted, and one ended by its time limit without Ctrl-C as a failure', async() =>
	{
		const interrupted = createFakeOrg();
		const first = contextFor(interrupted);
		const original = interrupted.org.runApex.getMockImplementation();
		interrupted.org.runApex.mockImplementation((apex, label) => (label === '89b-lowered-3'
			? {exitCode: 1, signal: 'SIGINT', success: false, debugLines: [], file: 'f'} : original(apex, label)));
		await runSection(first);
		expect(first.steps.map((step) => step.status)).toContain('INTERRUPTED');
		const timedOut = createFakeOrg();
		const second = contextFor(timedOut);
		const timedOutOriginal = timedOut.org.runApex.getMockImplementation();
		timedOut.org.runApex.mockImplementation((apex, label) => (label === '89b-lowered-3'
			? {exitCode: 1, signal: 'SIGTERM', success: false, compileProblem: '', exceptionMessage: '', debugLines: [], file: 'f'} : timedOutOriginal(apex, label)));
		await runSection(second);
		expect(second.output.some((line) => line.startsWith('SECTION89 ERROR FAIL 89b-lowered-3 failed'))).toBe(true);
		expect(second.steps.map((step) => step.status)).not.toContain('INTERRUPTED');
	});

	it('runs a clean-up action again when its command was stopped, and goes on with the rest of the clean-up', async() =>
	{
		const fake = createFakeOrg();
		const context = contextFor(fake);
		stopFirstCleanUpCommand(fake, {exitCode: 1, signal: 'SIGINT', success: false, debugLines: [], file: 'f'});
		await runSection(context);
		expect(fake.commands.filter((command) => command === 'apex 89h-clean-up')).toHaveLength(2);
		expect(fake.commands).toEqual(expect.arrayContaining(['apex 89h-breaker-reset', 'apex 89h-log-cleanup']));
		expect(context.steps.at(-1)).toMatchObject({step: '89h', status: 'PASS'});
	});

	it('reports the step as INTERRUPTED when a Windows Ctrl-C ended its command with exit code 3221225786 and no signal', async() =>
	{
		const fake = createFakeOrg();
		const context = contextFor(fake);
		const original = fake.org.runApex.getMockImplementation();
		fake.org.runApex.mockImplementation((apex, label) => (label === '89c-spend'
			? {exitCode: WINDOWS_CTRL_C_EXIT_CODE, signal: null, success: false, compileProblem: '', exceptionMessage: '', debugLines: [], file: 'f'} : original(apex, label)));
		const result = await runSection(context);
		expect(result).toBe('FAIL');
		expect(context.output).toContain('SECTION89 89c INTERRUPTED stopped by Ctrl-C (the sf command was stopped by Ctrl-C (exit code 3221225786)); '
			+ 'the org is put back next if anything on it changed');
		expectInterruptedRunPutBack(context, fake);
	});

	it('runs a clean-up action once more when a Windows Ctrl-C ended its command, and goes on with the rest of the clean-up', async() =>
	{
		const fake = createFakeOrg();
		const context = contextFor(fake);
		stopFirstCleanUpCommand(fake, {exitCode: WINDOWS_CTRL_C_EXIT_CODE, signal: null, success: false, debugLines: [], file: 'f'});
		await runSection(context);
		expect(fake.commands.filter((command) => command === 'apex 89h-clean-up')).toHaveLength(2);
		expect(fake.commands).toEqual(expect.arrayContaining(['apex 89h-breaker-reset', 'apex 89h-log-cleanup',
			'delete ApexClass:ElasticProbeFiller 89h-delete-ElasticProbeFiller']));
		expect(context.steps.at(-1)).toMatchObject({step: '89h', status: 'PASS'});
	});

	it('runs a clean-up action once more when its command failed after a Ctrl-C was seen, and the start of the clean-up keeps that Ctrl-C', async() =>
	{
		const fake = createFakeOrg();
		const context = contextFor(fake);
		const original = fake.org.runApex.getMockImplementation();
		const failedOnce = new Set();
		// noinspection FunctionWithMultipleReturnPointsJS
		fake.org.runApex.mockImplementation((apex, label) =>
		{
			if(label === '89c-spend')
			{
				createInterruptHandler(context.signal, () => undefined)();
			}
			if(label === '89h-breaker-read' && !failedOnce.has(label))
			{
				failedOnce.add(label);
				fake.commands.push(`apex ${label}`);
				return {exitCode: 1, signal: null, success: false, compileProblem: '', exceptionMessage: 'Unable to reach the org', debugLines: [], file: 'f'};
			}
			return original(apex, label);
		});
		await runSection(context);
		expect(context.signal).toMatchObject({ctrlCSeen: true, cleaningUp: true, interrupted: false});
		expect(context.steps.find((step) => step.step === '89c')).toMatchObject({status: 'INTERRUPTED'});
		expect(fake.commands.filter((command) => command === 'apex 89h-breaker-read')).toHaveLength(2);
		expectFillerJobsStopped(context, fake);
	});

	it('gives the clean-up action\'s own reason, with "after a Ctrl-C", when its command fails again in its last round', async() =>
	{
		const fake = createFakeOrg();
		const context = contextFor(fake);
		const original = fake.org.runApex.getMockImplementation();
		// noinspection FunctionWithMultipleReturnPointsJS
		fake.org.runApex.mockImplementation((apex, label) =>
		{
			if(label === '89c-spend')
			{
				createInterruptHandler(context.signal, () => undefined)();
			}
			if(label === '89h-breaker-read')
			{
				fake.commands.push(`apex ${label}`);
				return {exitCode: 1, signal: null, success: false, compileProblem: '', exceptionMessage: 'Unable to reach the org', debugLines: [], file: 'f'};
			}
			return original(apex, label);
		});
		fake.org.deleteSource.mockImplementation((projectDirectory, metadata, label) =>
		{
			fake.commands.push(`delete ${metadata} ${label}`);
			return {exitCode: 1, signal: null, success: false, message: 'refused', file: 'f'};
		});
		expect(await runSection(context)).toBe('FAIL');
		expect(fake.commands.filter((command) => command === 'apex 89h-breaker-read')).toHaveLength(2);
		expect(fake.commands.filter((command) => command === 'delete ApexClass:ElasticProbeFiller 89h-delete-ElasticProbeFiller')).toHaveLength(2);
		const cleanUp = context.steps.at(-1);
		expect(cleanUp).toMatchObject({step: '89h', status: 'FAIL'});
		expect(cleanUp.reason).toBe('reset the circuit breaker: 89h-breaker-read failed: Unable to reach the org (see f), after a Ctrl-C; '
			+ 'remove the probe classes: 1 probe class(es) left: ElasticProbeFiller (the delete failed for ElasticProbeFiller), after a Ctrl-C');
		expect(cleanUp.reason).not.toContain('failed after Ctrl-C');
	});

	it('records every Ctrl-C, also during the clean-up, and stops the run only before the clean-up', () =>
	{
		const printed = [];
		const signal = {interrupted: false, cleaningUp: false, ctrlCSeen: false};
		const handle = createInterruptHandler(signal, (line) => printed.push(line));
		handle();
		expect(signal).toEqual({interrupted: true, cleaningUp: false, ctrlCSeen: true});
		const cleaning = {interrupted: false, cleaningUp: true, ctrlCSeen: false};
		createInterruptHandler(cleaning, (line) => printed.push(line))();
		expect(cleaning).toEqual({interrupted: false, cleaningUp: true, ctrlCSeen: true});
		expect(printed).toEqual(['SECTION89 interrupted: the current step stops and the clean-up runs next',
			'SECTION89 the clean-up is running and will finish; wait for the RESULT line']);
		expect(findCtrlCStop({exitCode: 1, signal: 'SIGTERM', success: false}, {})).toBeNull();
		expect(findCtrlCStop({exitCode: 0, signal: null, success: true}, {ctrlCSeen: true}, false)).toBeNull();
		expect(findCtrlCStop({exitCode: 1, signal: null, file: 'f'}, {ctrlCSeen: true}, true)).toBe('the sf command failed after Ctrl-C (exit code 1; see f)');
	});
});

describe('a step whose evidence never comes', () =>
{
	const cases = [
		['89c', {stuckSpendLabels: ['89c-spend']}, ['still not there after 10 minutes', 'remaining=10, not 1', 'liveJobs=9, not 0']],
		['89c-hop', {launchNeverRuns: true}, ['still not there after 10 minutes', 'is Queued, not Completed', '0 ERROR entries']],
		['89d', {noFlowWarning: true}, ['still not there after 3 minutes', '0 WARN entries from the Flow action, not 1']],
		['89d', {placesFreedBeforeSave: 1, stuckSpendLabels: ['89d-spend']}, ['still not there after 10 minutes', 'remaining=1, not 0', 'liveJobs=1, not 0',
			'no call was saved']],
		['89f', {retryNeverSent: true}, ['still not there after 15 minutes', 'the call reads status=Retry', '0 send jobs since the restore']],
		['89g', {watchdogNeverFires: true}, ['still not there after 10 minutes', 'the call reads status=Retrying', 'the watchdog job is missing']]
	];

	it.each(cases)('fails %s with the missing evidence named once its time limit passes, and still cleans up', async(step, options, expected) =>
	{
		const fake = createFakeOrg(options);
		const context = contextFor(fake);
		const result = await runSection(context);
		const line = context.steps.find((candidate) => candidate.step === step);
		expect(line.status).toBe('FAIL');
		for(const text of expected)
		{
			expect(line.reason).toContain(text);
		}
		expect(result).toBe('FAIL');
		expect(context.steps.some((candidate) => candidate.step === 'ERROR')).toBe(false);
		expect(context.steps.at(-1).step).toBe('89h');
		expect(fake.model.maximum).toBe(LICENSED);
	});

	it('stops the chain job that never ran in the clean-up, so 89h passes with no job of the probe left waiting', async() =>
	{
		const fake = createFakeOrg({launchNeverRuns: true});
		const context = contextFor(fake);
		expect(await runSection(context)).toBe('FAIL');
		expect(context.steps.find((step) => step.step === '89c-hop')).toMatchObject({status: 'FAIL'});
		expect(fake.model.launch.job.status).toBe('Aborted');
		expect(fake.commands).toEqual(expect.arrayContaining(['apex 89h-stop-probe-jobs-abort', 'apex 89h-stop-probe-jobs-read']));
		expect(context.steps.at(-1)).toMatchObject({step: '89h', status: 'PASS', values: {stoppedJobs: 1}});
	});

	it('stops every waiting processor job in the clean-up when the launch queued its job but its answer was lost', async() =>
	{
		const fake = createFakeOrg({placesFreedAtLaunch: 1});
		const context = contextFor(fake);
		const original = fake.org.runApex.getMockImplementation();
		fake.org.runApex.mockImplementation((apex, label) =>
		{
			const answer = original(apex, label);
			return label === '89c-hop-launch' ? {...answer, exitCode: 1, success: false, exceptionMessage: 'Read timed out', debugLines: [], file: 'f'} : answer;
		});
		expect(await runSection(context)).toBe('FAIL');
		expect(context.output.some((line) => line.startsWith('SECTION89 ERROR FAIL 89c-hop-launch failed: Read timed out'))).toBe(true);
		expect(fake.model.launch.job.status).toBe('Aborted');
		const sent = fake.org.runApex.mock.calls.find(([, label]) => label === '89h-stop-probe-jobs-abort')[0];
		expect(sent).toContain("final String JOB_ID = 'all';");
		expect(context.steps.at(-1)).toMatchObject({step: '89h', status: 'PASS', values: {stoppedJobs: 1}});
	});

	it('stops the filler jobs that never ran in the clean-up, with no chain launched, so 89h passes', async() =>
	{
		const fake = createFakeOrg({stuckSpendLabels: ['89c-spend']});
		const context = contextFor(fake);
		expect(await runSection(context)).toBe('FAIL');
		expect(context.steps.find((step) => step.step === '89c')).toMatchObject({status: 'FAIL'});
		expect(fake.model.launch).toBeNull();
		const sent = fake.org.runApex.mock.calls.find(([, label]) => label === '89h-stop-probe-jobs-abort')[0];
		expect(sent).toContain("final String JOB_ID = 'none';");
		expectFillerJobsStopped(context, fake);
	});

	it('fails the state gate after 20 minutes of a job that never ends, and changes nothing, so there is nothing to clean up', async() =>
	{
		const fake = createFakeOrg({foreignLiveJob: true});
		const context = contextFor(fake);
		expect(await runSection(context)).toBe('FAIL');
		expect(stepLines(context)).toEqual(['GUARD PASS', '89a FAIL', 'STOP FAIL']);
		expect(context.steps[1].reason).toBe('still not there after 20 minutes; liveJobs=1, not 0');
		expect(fake.clock.time - START).toBeGreaterThanOrEqual(20 * MINUTE);
		expect(fake.org.deploy).not.toHaveBeenCalled();
	});
});

describe('--restore-only', () =>
{
	it('runs every clean-up action and no step before 89h, on an org an earlier run left lowered', async() =>
	{
		const fake = createFakeOrg({lowered: true});
		const context = contextFor(fake);
		const result = await runRestoreOnly(context);
		expect(result).toBe('PASS');
		expect(stepLines(context)).toEqual(['89h PASS']);
		expect(fake.commands).toEqual(expect.arrayContaining(['retrieve Settings:Apex 89h-settings-before', 'deploy Settings:Apex 89h-settings',
			'retrieve Settings:Apex 89h-settings-after', 'apex 89h-clean-up', 'apex 89h-schedules-abort', 'apex 89h-schedules-read', 'apex 89h-breaker-reset',
			'apex 89h-breaker-read', 'apex 89h-log-cleanup', 'delete ApexClass:ElasticProbeFiller 89h-delete-ElasticProbeFiller', 'query 89h-classes-left']));
		expect(fake.commands.some((command) => /guard|89a|89b|89c|89d|89e|89f|89g/.test(command))).toBe(false);
		expect(fake.model).toMatchObject({maximum: LICENSED, override: null});
		expect(fake.model.schedule.aborted).toBe(true);
		expect(fake.model.classes.size).toBe(0);
	});

	it('stops every waiting job of the adaptive processor first, with no job id from the earlier run', async() =>
	{
		const fake = createFakeOrg({lowered: true, waitingProcessorJob: true});
		const context = contextFor(fake);
		expect(await runRestoreOnly(context)).toBe('PASS');
		expect(fake.model.jobs.map((job) => job.status)).toEqual(['Aborted']);
		expect(fake.commands.slice(2, 5)).toEqual(['apex 89h-stop-probe-jobs-abort', 'apex 89h-stop-probe-jobs-read', 'retrieve Settings:Apex 89h-settings-before']);
		const sent = fake.org.runApex.mock.calls.find(([, label]) => label === '89h-stop-probe-jobs-abort')[0];
		expect(sent).toContain("final String JOB_ID = 'all';");
		expect(context.steps[0]).toMatchObject({step: '89h', status: 'PASS', values: {stoppedJobs: 1}});
	});

	it('leaves the settings alone when the override is already blank, and fails when a schedule stays', async() =>
	{
		const fake = createFakeOrg({scheduleStuck: true});
		fake.model.schedule = {cronId: '08eRu0000000777AAA', aborted: false, fired: true};
		const context = contextFor(fake);
		expect(await runRestoreOnly(context)).toBe('FAIL');
		expect(fake.org.deploy).not.toHaveBeenCalled();
		expect(context.steps[0].reason).toContain('still scheduled: 08eRu0000000777AAA (Elastic Probe Outbound Retry Watchdog 1)');
		expect(context.output.some((line) => line.startsWith('SECTION89 89h FAIL') && line.includes('stop the watchdog schedule: still scheduled: 08eRu0000000777AAA'))).toBe(true);
		expect(context.steps[0].values.notes).toBe('the allowance override was already blank');
	});

	it('fails at once when Kern is not on the org', async() =>
	{
		const fake = createFakeOrg();
		fake.org.query.mockImplementation(() => []);
		const context = contextFor(fake);
		expect(await runRestoreOnly(context)).toBe('FAIL');
		expect(context.output[0]).toBe('SECTION89 89h FAIL the clean-up could not start: Kern is not on the org: no class UTIL_AdaptiveAsynchronousProcessor');
	});
});

describe('the command line and the org door', () =>
{
	it('reads --dry-run and --restore-only, refuses both together and anything else, and maps each result to its exit code', () =>
	{
		expect(parseCommandLine(['--dry-run'])).toEqual({dryRun: true, restoreOnly: false, help: false});
		expect(parseCommandLine(['--restore-only'])).toEqual({dryRun: false, restoreOnly: true, help: false});
		expect(parseCommandLine(['-h'])).toEqual({dryRun: false, restoreOnly: false, help: true});
		expect(() => parseCommandLine(['--dry-run', '--restore-only'])).toThrow('--dry-run and --restore-only cannot run together');
		expect(() => parseCommandLine(['--org'])).toThrow('Unknown argument --org');
		expect(USAGE).toContain('--restore-only');
		expect([exitCodeFor('PASS'), exitCodeFor('FAIL'), exitCodeFor('BLOCKED'), exitCodeFor('other')]).toEqual([0, 1, 3, 1]);
		expect(runStamp(new Date(START))).toBe('2026-11-08T15-00-00-000Z');
	});

	it('writes every answer to a file before reading it, and keeps the exit code and the signal', () =>
	{
		const runDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'section-89-org-'));
		const execute = jest.fn((commandArguments) => (commandArguments[0] === 'apex'
			? {exitCode: 1, output: '{"status":1,"result":{"success":false,"compiled":true,"compileProblem":"","exceptionMessage":"boom","logs":"a|USER_DEBUG|[1]|DEBUG|PROBE X"}}'}
			: {exitCode: 1, output: 'no json here'}));
		const org = createOrg({alias: 'Test', runDirectory, execute});
		const result = org.runApex('System.debug(1);', 'probe');
		expect(result).toMatchObject({exitCode: 1, signal: null, success: false, exceptionMessage: 'boom', debugLines: ['PROBE X']});
		expect(fs.readFileSync(path.join(runDirectory, '001-probe.json'), 'utf8')).toContain('"boom"');
		execute.mockReturnValueOnce({exitCode: 1, output: '{"status":1,"message":"Execution failed","data":{"success":false,"compiled":true,"exceptionMessage":"stopped"}}'});
		expect(org.runApex('x', 'failed')).toMatchObject({compiled: true, exceptionMessage: 'stopped'});
		execute.mockReturnValueOnce({exitCode: 1, signal: 'SIGINT', output: ''});
		expect(org.runApex('x', 'stopped')).toMatchObject({signal: 'SIGINT', success: false});
		// noinspection SqlNoDataSourceInspection
		expect(() => org.query('SELECT Id FROM Account', 'accounts')).toThrow('The query failed (the command printed no JSON: no json here)');
		execute.mockReturnValueOnce({exitCode: 1, signal: 'SIGINT', output: ''});
		// noinspection SqlNoDataSourceInspection
		expect(() => org.query('SELECT Id FROM Account', 'stopped-query')).toThrow(expect.objectContaining({signal: 'SIGINT'}));
		expect(org.deploy('/p', 'Settings:Apex', 'settings')).toMatchObject({success: false, signal: null});
		expect(org.deleteSource('/p', 'ApexClass:X', 'delete')).toMatchObject({success: false});
		expect(org.retrieve('/p', 'Settings:Apex', 'retrieve')).toMatchObject({success: false});
		expect(execute).toHaveBeenCalledWith(expect.arrayContaining(['project', 'deploy', 'start', '-m', 'Settings:Apex']), {cwd: '/p'});
		expect(execute).toHaveBeenCalledWith(expect.arrayContaining(['project', 'retrieve', 'start', '-m', 'Settings:Apex']), {cwd: '/p'});
		expect(readAnswer('{bad')).toMatchObject({status: 1});
		expect(() => createOrg({alias: '', runDirectory})).toThrow('SF_SUBSCRIBER_ORG_ALIAS');
	});

	it('passes a script and a query as files relative to the run folder, so no argument holds a space, a quote or a %', () =>
	{
		const runDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'section 89 with spaces '));
		const execute = jest.fn(() => ({exitCode: 0, output: '{"status":0,"result":{"records":[{"Name":"ElasticProbeFiller"}],"success":true,"logs":""}}'}));
		const org = createOrg({alias: 'kern-subscriber', runDirectory, execute});
		// noinspection SqlNoDataSourceInspection
		const soql = "SELECT Id, Name FROM ApexClass WHERE Name LIKE 'ElasticProbe%'";
		expect(org.query(soql, '89h-classes-present')).toEqual([{Name: 'ElasticProbeFiller'}]);
		org.runApex("System.debug('PROBE A');", '89a-gate-1');
		const queryPath = path.join('queries', '89h-classes-present.soql');
		const scriptPath = path.join('scripts', '89a-gate-1.apex');
		expect(execute).toHaveBeenNthCalledWith(1, ['data', 'query', '-o', 'kern-subscriber', '--file', queryPath, '--json'], {cwd: runDirectory});
		expect(execute).toHaveBeenNthCalledWith(2, ['apex', 'run', '-o', 'kern-subscriber', '-f', scriptPath, '--json'], {cwd: runDirectory});
		expect(fs.readFileSync(path.join(runDirectory, queryPath), 'utf8')).toBe(soql);
		expect(fs.readFileSync(path.join(runDirectory, scriptPath), 'utf8')).toBe("System.debug('PROBE A');");
		for(const call of execute.mock.calls)
		{
			expect(() => checkShellSafe(call[0])).not.toThrow();
		}
		expect(() => checkShellSafe(['-q', soql])).toThrow('Section 89 cannot pass');
		expect(() => checkShellSafe([path.join(runDirectory, scriptPath)])).toThrow('Section 89 cannot pass');
		expect(() => checkShellSafe(['a&b', 'a|b', 'a^b', 'a%b', 'a"b'])).toThrow('"a&b", "a|b", "a^b", "a%b", "a"b"');
		expect(() => createOrg({alias: 'my org', runDirectory, execute})).toThrow('an alias such as kern-subscriber');
	});

	it('starts each sf command in its own process group on macOS and Linux, and through the shell on Windows, where sf is a .cmd file', () =>
	{
		expect(commandOptions('/p', 'darwin')).toMatchObject({cwd: '/p', detached: true, shell: false});
		expect(commandOptions('/p', 'linux')).toMatchObject({detached: true, shell: false});
		expect(commandOptions('/p', 'win32')).toMatchObject({detached: false, shell: true});
	});

	it('runs sf through the shell on a Windows machine and keeps the exit code a console Ctrl-C gives', () =>
	{
		const platform = Object.getOwnPropertyDescriptor(process, 'platform');
		const spawn = jest.spyOn(childProcess, 'spawnSync').mockReturnValue({status: WINDOWS_CTRL_C_EXIT_CODE, signal: null, stdout: '', stderr: '^C'});
		try
		{
			Object.defineProperty(process, 'platform', {value: 'win32'});
			expect(runSalesforceCommand(['apex', 'run', '-o', 'kern-subscriber', '-f', path.join('scripts', 'x.apex'), '--json'], {cwd: 'C:\\Users\\A B\\run'}))
				.toEqual({exitCode: WINDOWS_CTRL_C_EXIT_CODE, signal: null, output: '^C'});
			expect(spawn).toHaveBeenCalledWith('sf', expect.any(Array), expect.objectContaining({shell: true, detached: false, cwd: 'C:\\Users\\A B\\run'}));
			// noinspection SqlNoDataSourceInspection
			expect(() => runSalesforceCommand(['data', 'query', '-q', 'SELECT Id FROM Account'])).toThrow('Section 89 cannot pass "SELECT Id FROM Account"');
			expect(spawn).toHaveBeenCalledTimes(1);
		}
		finally
		{
			Object.defineProperty(process, 'platform', platform);
			spawn.mockRestore();
		}
	});
});
