// SPDX-License-Identifier: Apache-2.0
// The pass and fail rules of section 89, one function per step. Each takes what the org printed (already parsed) and
// returns `{pass, reasons, values}`: the reasons say what did not match, the values are what the results file records.
'use strict';
const {findUtcTimes, isSameInstant, isSameId, findAccountIds} = require('./probe-lines');

// The lowered allowance leaves this many executions above what the org has used: enough for the run's own jobs.
const ALLOWANCE_HEADROOM = 10;
// The chainable launch needs one place: its first job takes the last place, so that job's own next job finds none.
const LEAVE_BEFORE_LAUNCH = 1;
const LAUNCH_ITEMS = 3;
const LAUNCH_JOB_SIZE = 1;
const PROCESSOR_CLASS = 'UTIL_AdaptiveAsynchronousProcessor';
const WATCHDOG_CLASS = 'SCHED_OutboundRetryWatchdog';
const NEXT_HOP_LOCATION = /(^|\.)UTIL_AdaptiveAsynchronousProcessor\/enqueueNextHop$/;
const FLOW_ACTION_LOCATION = /(^|\.)FLOW_CallApiAsync\/invokeApiCallAsynchronously$/;
const WATCHDOG_LOCATION = /(^|\.)SCHED_OutboundRetryWatchdog\/execute$/;
const PENDING_STATUSES = ['Queued', 'Retry', 'Retrying'];
const ENDED_JOB_STATUSES = ['Completed', 'Failed', 'Aborted'];
// A background job at one of these has not ended: it waits to run, or it runs.
const LIVE_JOB_STATUSES = ['Queued', 'Holding', 'Preparing', 'Processing'];
// A background job at one of these has not started to run yet.
const WAITING_JOB_STATUSES = ['Queued', 'Holding', 'Preparing'];
// The words Salesforce's error names when it refuses a job at the 24-hour limit, as the async processing guide quotes
// it: `Rate Limiting Exception : AsyncApexExecutions Limit exceeded.`
const LIMIT_REFUSAL_TEXT = /AsyncApexExecutions Limit exceeded/i;
// The probe's own classes, such as the filler job class, all start with this.
const PROBE_CLASS_PREFIX = 'ElasticProbe';
// The two ways Salesforce can count a Queueable against the 24-hour allowance: as soon as it is queued, or only once it runs.
const COUNTED_WHEN_QUEUED = 'queued';
const COUNTED_WHEN_RUN = 'run';
// The read came after the chain's first job had started, so it cannot tell when Salesforce counts a job.
const COUNTED_WHEN_NOT_MEASURED = 'not-measured';
// FLOW_CallApiAsync waits this long before the first retry of a call Salesforce refused to start.
const FIRST_RETRY_WAIT_MINUTES = 15;
// The retry time is worked out a moment after the insert's time line, and the probe prints whole seconds.
const RETRY_TIME_TOLERANCE_MILLISECONDS = 120_000;
const MILLISECONDS_PER_MINUTE = 60_000;
const MILLISECONDS_PER_SECOND = 1_000;
// The call's text names its stored retry time. Stored times are whole seconds, so the time ends in `.000Z` or in `Z`.
const LAUNCH_REFUSED_TEXT = new RegExp('^Salesforce refused to start the background send, so the request was not sent: (.+)\\. It will be tried again at '
	+ '(\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.000)?Z)\\. The Next Retry field shows this time in your own time zone\\.$', 's');
const LOST_JOB_TEXT_START = 'No background job finished sending this request again.';
const RETRY_TIME_MOVED_TEXT_START = 'The retry of this call was due at';

/**
 * @description A step's outcome.
 *
 * @param {string[]} reasons What did not match; none means the step passed.
 * @param {object} [values] What the results file records.
 *
 * @returns {{pass: boolean, reasons: string[], values: object}}
 */
function outcome(reasons, values = {})
{
	return {pass: reasons.length === 0, reasons, values};
}

/**
 * @description One outbound call of a read, by its id.
 *
 * @param {object} read A read-budget read.
 * @param {string} callId The call.
 *
 * @returns {object|undefined} Undefined when the read does not list the call.
 */
function findCall(read, callId)
{
	return (read?.calls ?? []).find((candidate) => isSameId(candidate.id, callId));
}

/**
 * @description Whether a call or a saved row has a status and a retry count. A missing record has neither.
 *
 * @param {object|undefined} record The call or the row.
 * @param {string} status The status it must have.
 * @param {number} retries The retry count it must have.
 *
 * @returns {boolean}
 */
function hasStatusAndRetries(record, status, retries)
{
	return record?.status === status && record.retries === retries;
}

/**
 * @description Whether a call still waits as it was saved: at Retry, with the same retry time and no retry counted.
 *
 * @param {object|undefined} call The call.
 * @param {Date} nextRetry The retry time it was saved with.
 *
 * @returns {boolean}
 */
function isWaitingAsSaved(call, nextRetry)
{
	return hasStatusAndRetries(call, 'Retry', 0) && isSameInstant(call.nextRetry, nextRetry);
}

/**
 * @description Whether a call ended Failed after one retry, with no retry time left.
 *
 * @param {object|undefined} call The call.
 *
 * @returns {boolean}
 */
function isFailedWithOneRetry(call)
{
	return hasStatusAndRetries(call, 'Failed', 1) && call.nextRetry === null;
}

/**
 * @description Whether a text starts with the lost-job text: the words the watchdog writes when no background job
 * finished a call's retry.
 *
 * @param {string|null|undefined} text The text.
 *
 * @returns {boolean}
 */
function startsWithLostJobText(text)
{
	return String(text ?? '').startsWith(LOST_JOB_TEXT_START);
}

/**
 * @description Whether a job is there and has ended.
 *
 * @param {object|undefined} job The job.
 *
 * @returns {boolean}
 */
function hasEnded(job)
{
	return Boolean(job) && ENDED_JOB_STATUSES.includes(job.status);
}

/**
 * @description Whether a job is there and ended Completed.
 *
 * @param {object|undefined} job The job.
 *
 * @returns {boolean}
 */
function isCompleted(job)
{
	return job?.status === 'Completed';
}

/**
 * @description Whether a log entry has a time and was written at or after a moment.
 *
 * @param {object} entry The log entry.
 * @param {Date} since The moment.
 *
 * @returns {boolean}
 */
function isWrittenSince(entry, since)
{
	return Boolean(entry.created) && entry.created >= since;
}

/**
 * @description Whether an insert saved its call: it printed a saved id and no refusal.
 *
 * @param {object} insert The parsed insert.
 *
 * @returns {boolean}
 */
function isSaved(insert)
{
	return Boolean(insert.savedId) && !insert.refused;
}

/**
 * @description Whether both reads of the state gate printed their PROBE BUDGET line, and the second its PROBE GATE line.
 *
 * @param {object} first The first read.
 * @param {object} second The second read.
 *
 * @returns {boolean}
 */
function hasBudgetAndGate(first, second)
{
	return Boolean(first?.budget && second?.budget && second.gate);
}

/**
 * @description The allowance arithmetic of the run, from the used count U the state gate read. The allowance is set to
 * U + 10; the spend leaves 1 (9 filler jobs); the chainable launch's first job takes that last place, and no filler job
 * is queued after it. The first job's own next job is then the eleventh and is refused, and so is the outbound send.
 *
 * @param {number} used The used count U.
 *
 * @returns {{allowance: number, firstSpend: number, launchJobs: number}}
 */
function planAllowance(used)
{
	return {
		allowance: used + ALLOWANCE_HEADROOM,
		firstSpend: ALLOWANCE_HEADROOM - LEAVE_BEFORE_LAUNCH,
		launchJobs: 1
	};
}

/**
 * @description The state gate: both reads printed, the same remaining count, and nothing of the probe's running.
 *
 * @param {object} first The first read-budget read.
 * @param {object} second The read two minutes later.
 *
 * @returns {object} The outcome; values `used`, `maximum`, `remaining`.
 */
// noinspection FunctionWithMultipleReturnPointsJS
function checkGate(first, second)
{
	const reasons = [];
	if(!hasBudgetAndGate(first, second))
	{
		return outcome(['a read printed no PROBE BUDGET or PROBE GATE line']);
	}
	if(first.budget.remaining !== second.budget.remaining)
	{
		reasons.push(`the remaining count moved from ${first.budget.remaining} to ${second.budget.remaining} between the two reads`);
	}
	for(const counter of ['probeSchedules', 'pendingCalls', 'runningChains', 'liveJobs'])
	{
		if(second.gate[counter] !== 0)
		{
			reasons.push(`${counter}=${second.gate[counter]}, not 0`);
		}
	}
	return outcome(reasons, {used: second.budget.used, maximum: second.budget.maximum, remaining: second.budget.remaining});
}

/**
 * @description The outbound calls of the org, other than the run's own, that are waiting to be sent or retried.
 *
 * @param {object[]} records The rows of the guard's query, with the status field named `status`.
 * @param {string[]} ownIds The run's own call ids.
 *
 * @returns {object[]} `{id, status}` per foreign call.
 */
function findForeignCalls(records, ownIds)
{
	return records.filter((record) => PENDING_STATUSES.includes(record.status) && !ownIds.some((id) => isSameId(id, record.id)))
		.map((record) => ({id: record.id, status: record.status}));
}

/**
 * @description The lowered allowance: the read after the deploy shows the new maximum.
 *
 * @param {boolean} deployed Whether the deploy succeeded.
 * @param {object} read The read-budget read after it.
 * @param {number} allowance The allowance the run set.
 *
 * @returns {object} The outcome; values `maximum`, `remaining`.
 */
function checkLowered(deployed, read, allowance)
{
	const reasons = [];
	if(!deployed)
	{
		reasons.push('the settings deploy failed');
	}
	if(read?.budget?.maximum !== allowance)
	{
		reasons.push(`maximum=${read?.budget?.maximum}, not ${allowance}`);
	}
	return outcome(reasons, {maximum: read?.budget?.maximum, remaining: read?.budget?.remaining});
}

/**
 * @description The spend to the line before the launch: exactly one place is left and every filler job has ended.
 *
 * @param {object} read The read-budget read after the spend.
 *
 * @returns {object} The outcome; values `remaining`.
 */
function checkSpentToLaunchLine(read)
{
	const reasons = [];
	if(read?.budget?.remaining !== LEAVE_BEFORE_LAUNCH)
	{
		reasons.push(`remaining=${read?.budget?.remaining}, not ${LEAVE_BEFORE_LAUNCH}`);
	}
	if(read?.gate?.liveJobs !== 0)
	{
		reasons.push(`liveJobs=${read?.gate?.liveJobs}, not 0`);
	}
	return outcome(reasons, {remaining: read?.budget?.remaining});
}

/**
 * @description The read straight after the chainable launch, which also measures when Salesforce counts a Queueable
 * against the allowance. Step 89c left one place, and the chain's first job waits a minute before it runs. If that job
 * has its place already, the read shows 0 left: Salesforce counts a job as soon as it is queued. If the place is still
 * free, the read shows 1 left: Salesforce counts a job only once it runs. Either way the first job takes the last
 * place, so its own next job is refused. Any other count means the rolling 24 hours freed a place, or another job took
 * one, so the refusal cannot be proved. The count tells when Salesforce counts a job only while the first job still
 * waits in the same read: once it has run, it has been counted either way, so the read records `not-measured`.
 *
 * @param {object} read The read-budget read taken straight after the launch.
 * @param {string} jobId The id of the chain's first job.
 *
 * @returns {object} The outcome; values `remainingAfterLaunch`, `firstJobStatusAfterLaunch`, and `countsWhen`
 *          (`queued`, `run` or `not-measured`) when it passed.
 */
function checkPlacesLeftAfterLaunch(read, jobId)
{
	const remaining = read?.budget?.remaining;
	const job = (read?.jobs ?? []).find((candidate) => isSameId(candidate.id, jobId));
	let countsWhen = null;
	if(remaining === 0 || remaining === LEAVE_BEFORE_LAUNCH)
	{
		if(!job || !WAITING_JOB_STATUSES.includes(job.status))
		{
			countsWhen = COUNTED_WHEN_NOT_MEASURED;
		}
		else
		{
			countsWhen = remaining === 0 ? COUNTED_WHEN_QUEUED : COUNTED_WHEN_RUN;
		}
	}
	const reasons = [];
	if(read?.budget)
	{
		if(countsWhen === null)
		{
			reasons.push(`remaining=${remaining} straight after the launch, not 0 or ${LEAVE_BEFORE_LAUNCH}: the rolling 24 hours freed a place, or another job `
				+ 'took one, so the refused next job cannot be proved');
		}
	}
	else
	{
		reasons.push('the read after the launch printed no PROBE BUDGET line');
	}
	return outcome(reasons, {remainingAfterLaunch: remaining, firstJobStatusAfterLaunch: job?.status ?? 'not read', countsWhen});
}

/**
 * @description The ERROR entries written when the first job of the chainable launch could not start its next job.
 *
 * @param {object} read A read-budget read.
 * @param {string} jobId The first job's id.
 * @param {Date} runStart The org's time when the run started.
 *
 * @returns {object[]}
 */
function findNextHopEntries(read, jobId, runStart)
{
	return (read?.logs ?? []).filter((entry) => entry.level === 'ERROR' && NEXT_HOP_LOCATION.test(entry.at) && isSameId(entry.record, jobId)
		&& isWrittenSince(entry, runStart));
}

/**
 * @description Whether the wait for the refused next job can stop: the first job has ended and its entry is there.
 *
 * @param {object} read A read-budget read.
 * @param {string} jobId The first job's id.
 * @param {Date} runStart The org's time when the run started.
 *
 * @returns {boolean}
 */
function isNextHopSettled(read, jobId, runStart)
{
	const job = (read?.jobs ?? []).find((candidate) => isSameId(candidate.id, jobId));
	return hasEnded(job) && findNextHopEntries(read, jobId, runStart).length > 0;
}

/**
 * @description Whether the chainable launch was accepted as a Queueable of Kern's adaptive processor.
 *
 * @param {object} launch The parsed launch.
 *
 * @returns {boolean}
 */
function isProcessorQueueable(launch)
{
	return launch.accepted && launch.className === PROCESSOR_CLASS && launch.type === 'Queueable';
}

/**
 * @description Whether two lists of record ids name the same records in the same order.
 *
 * @param {string[]} first One list.
 * @param {string[]} second The other.
 *
 * @returns {boolean}
 */
function isSameIdList(first, second)
{
	return first.length === second.length && first.every((id, index) => isSameId(id, second[index]));
}

/**
 * @description What did not match about the chainable launch itself: the launch, its Account ids, its first job, and
 * any job of the processor that started after the first.
 *
 * @param {object} launch The parsed launch.
 * @param {object} read The last read-budget read.
 * @param {object|undefined} job The launch's first job in the read.
 *
 * @returns {string[]}
 */
function findLaunchProblems(launch, read, job)
{
	const reasons = [];
	if(!isProcessorQueueable(launch))
	{
		reasons.push(`the launch was not accepted as a ${PROCESSOR_CLASS} Queueable (${launch.refused ?? `class=${launch.className} type=${launch.type}`})`);
	}
	if(launch.accountIds.length !== LAUNCH_ITEMS)
	{
		reasons.push(`the launch printed ${launch.accountIds.length} Account ids, not ${LAUNCH_ITEMS}`);
	}
	if(!isCompleted(job))
	{
		reasons.push(`the first job ${launch.jobId} is ${job ? job.status : 'not in the last 20 jobs'}, not Completed`);
	}
	const laterJobs = job ? read.jobs.filter((candidate) => candidate.className === PROCESSOR_CLASS && !isSameId(candidate.id, job.id)
		&& candidate.created >= job.created) : [];
	if(laterJobs.length > 0)
	{
		reasons.push(`another ${PROCESSOR_CLASS} job started after the first: ${laterJobs.map((candidate) => candidate.id).join(', ')}`);
	}
	return reasons;
}

/**
 * @description What did not match about the ERROR entry of the refused next job: there must be exactly one, it must
 * name the second and third Accounts, and its message must name the 24-hour limit.
 *
 * @param {object[]} entries The entries for the first job.
 * @param {string[]} scope The Account ids the one entry names (empty when there is not exactly one entry).
 * @param {string[]} expectedScope The second and third Accounts of the launch.
 * @param {string|null} refusal The one entry's message (null when there is not exactly one entry).
 *
 * @returns {string[]}
 */
function findNextHopEntryProblems(entries, scope, expectedScope, refusal)
{
	const reasons = [];
	if(entries.length === 1)
	{
		if(!isSameIdList(scope, expectedScope))
		{
			reasons.push(`the entry lists ${scope.join(',') || 'no Account'}, not the second and third Accounts ${expectedScope.join(',')}`);
		}
		if(!LIMIT_REFUSAL_TEXT.test(refusal))
		{
			reasons.push(`the entry's message does not name the 24-hour limit (AsyncApexExecutions Limit exceeded): ${refusal}`);
		}
	}
	else
	{
		reasons.push(`${entries.length} ERROR entries at ${PROCESSOR_CLASS}/enqueueNextHop for the first job, not 1`);
	}
	return reasons;
}

/**
 * @description The refused next job of a chainable launch at the limit: the first job started and ended Completed, no
 * second job started, no place is left after it, and one ERROR entry names the two Accounts the chain did not reach.
 * Kern writes that entry for any error that stops the next job, so its message must also name the 24-hour limit.
 *
 * @param {object} launch The parsed launch.
 * @param {object} read The last read-budget read.
 * @param {Date} runStart The org's time when the run started.
 *
 * @returns {object} The outcome; values `firstJobId`, `jobStatus`, `entries`, `scope`, `remainingAfterHop`, `refusal`.
 */
function checkNextHop(launch, read, runStart)
{
	const job = (read?.jobs ?? []).find((candidate) => isSameId(candidate.id, launch.jobId));
	const entries = findNextHopEntries(read, launch.jobId, runStart);
	const scope = entries.length === 1 ? findAccountIds(entries[0].context) : [];
	const refusal = entries.length === 1 ? String(entries[0].message ?? '') : null;
	const reasons = [...findLaunchProblems(launch, read, job), ...findNextHopEntryProblems(entries, scope, launch.accountIds.slice(1), refusal)];
	const remainingAfterHop = read?.budget?.remaining;
	if(remainingAfterHop !== 0)
	{
		reasons.push(`remaining=${remainingAfterHop} after the first job, not 0`);
	}
	return outcome(reasons, {firstJobId: launch.jobId, jobStatus: job?.status, entries: entries.length, scope: scope.join(','), remainingAfterHop, refusal});
}

/**
 * @description The extra spend of 89d, when a place was left before the save: no filler job waits or runs any more,
 * and no place is left (0 or less, as the save itself asks).
 *
 * @param {object} read The read-budget read after the spend.
 *
 * @returns {object} The outcome; values `remainingBeforeSave`.
 */
function checkSpentToLimit(read)
{
	const reasons = [];
	if(read?.budget?.remaining === undefined || read.budget.remaining > 0)
	{
		reasons.push(`remaining=${read?.budget?.remaining}, not 0`);
	}
	if(read?.gate?.liveJobs !== 0)
	{
		reasons.push(`liveJobs=${read?.gate?.liveJobs}, not 0`);
	}
	return outcome(reasons, {remainingBeforeSave: read?.budget?.remaining});
}

/**
 * @description The error text a call is given when Salesforce refused to start its send, read for its reason and time.
 *
 * @param {string|null} errors The call's error text.
 *
 * @returns {{reason: string, retryTime: Date}|null} Null when the text is not that message.
 */
function readLaunchRefusedText(errors)
{
	const match = String(errors ?? '').trim().match(LAUNCH_REFUSED_TEXT);
	return match ? {reason: match[1], retryTime: new Date(match[2])} : null;
}

/**
 * @description Whether the insert ran at the limit: it printed its start line, with no place left (0 or less).
 *
 * @param {object} insert The parsed insert.
 *
 * @returns {boolean}
 */
function hasRunAtLimit(insert)
{
	return Boolean(insert.start) && !(insert.start.remaining > 0);
}

/**
 * @description Whether the saved row waits at Retry with a retry time and no retry counted.
 *
 * @param {object|null} row The row the insert read back.
 *
 * @returns {boolean}
 */
function isRowAtRetry(row)
{
	return Boolean(row?.exists && row.nextRetry) && hasStatusAndRetries(row, 'Retry', 0);
}

/**
 * @description What did not match about the error text of a call Salesforce refused to start: it must be the
 * refused-start message, and the time it names must be the call's Next Retry.
 *
 * @param {object|null} row The row the insert read back.
 * @param {{reason: string, retryTime: Date}|null} text The error text, read; null when it is not that message.
 *
 * @returns {string[]}
 */
function findRefusedTextProblems(row, text)
{
	const reasons = [];
	if(text === null)
	{
		reasons.push(`the error text is not the refused-start message: ${row?.errors}`);
	}
	else if(!isSameInstant(text.retryTime, row.nextRetry))
	{
		reasons.push(`the message names ${text.retryTime.toISOString()}, but Next Retry is ${row.nextRetry?.toISOString()}`);
	}
	return reasons;
}

/**
 * @description The save of one call at Queued at the limit: it succeeds, and the call waits at Retry with a retry time
 * 15 minutes out, its retry count 0 and the refused-start text, and no send job started.
 *
 * @param {object} insert The parsed insert.
 *
 * @returns {object} The outcome; values `callId`, `insertedAt`, `nextRetry`, `reason`.
 */
function checkQueuedInsert(insert)
{
	const reasons = [];
	if(!hasRunAtLimit(insert))
	{
		reasons.push(`the save ran with remaining=${insert.start?.remaining}, not 0 or less`);
	}
	if(!isSaved(insert))
	{
		reasons.push(`the save did not succeed (${insert.refused ?? 'no saved line'})`);
	}
	const row = insert.row;
	if(!isRowAtRetry(row))
	{
		reasons.push(`the call reads status=${row?.status} nextRetry=${row?.nextRetry?.toISOString() ?? null} retries=${row?.retries}, not Retry, a time, 0`);
	}
	const text = readLaunchRefusedText(row?.errors);
	reasons.push(...findRefusedTextProblems(row, text));
	if(row?.nextRetry && insert.start?.time)
	{
		const expected = insert.start.time.getTime() + FIRST_RETRY_WAIT_MINUTES * MILLISECONDS_PER_MINUTE;
		if(Math.abs(row.nextRetry.getTime() - expected) > RETRY_TIME_TOLERANCE_MILLISECONDS)
		{
			reasons.push(`Next Retry ${row.nextRetry.toISOString()} is not ${FIRST_RETRY_WAIT_MINUTES} minutes after the save`);
		}
	}
	const sendJobs = insert.jobs.filter((job) => job.className === PROCESSOR_CLASS);
	if(sendJobs.length > 0)
	{
		reasons.push(`a send job started: ${sendJobs.map((job) => job.id).join(', ')}`);
	}
	return outcome(reasons, {callId: row?.id ?? insert.savedId, insertedAt: insert.start?.time, nextRetry: row?.nextRetry, reason: text?.reason});
}

/**
 * @description The Flow action's warning about the call: written after the run started, and naming the retry time.
 *
 * @param {object} read A read-budget read.
 * @param {Date} since The org's time of the save.
 *
 * @returns {object[]}
 */
function findFlowActionWarnings(read, since)
{
	const start = new Date(Math.floor(since.getTime() / MILLISECONDS_PER_SECOND) * MILLISECONDS_PER_SECOND);
	return (read?.logs ?? []).filter((entry) => entry.level === 'WARN' && FLOW_ACTION_LOCATION.test(entry.at) && entry.created && entry.created >= start);
}

/**
 * @description The call a minute after its save: still at Retry with the same time and count, no issue, and one
 * warning from the Flow action that names the retry time as an ISO 8601 time.
 *
 * @param {object} read A read-budget read.
 * @param {string} callId The call.
 * @param {Date} nextRetry Its retry time.
 * @param {Date} insertedAt The org's time of the save.
 *
 * @returns {object} The outcome; values `warnings`.
 */
function checkQueuedWaiting(read, callId, nextRetry, insertedAt)
{
	const reasons = [];
	const call = findCall(read, callId);
	if(!isWaitingAsSaved(call, nextRetry))
	{
		reasons.push(`the call reads status=${call?.status} nextRetry=${call?.nextRetryText} retries=${call?.retries}, not as saved`);
	}
	const issues = (read?.issues ?? []).filter((issue) => isSameId(issue.call, callId));
	if(issues.length > 0)
	{
		reasons.push(`${issues.length} issue(s) for a call that was never sent`);
	}
	const warnings = findFlowActionWarnings(read, insertedAt);
	if(warnings.length !== 1)
	{
		reasons.push(`${warnings.length} WARN entries from the Flow action, not 1`);
	}
	else if(!findUtcTimes(warnings[0].message).some((time) => isSameInstant(time, nextRetry)))
	{
		reasons.push(`the warning does not name the retry time as an ISO 8601 time: ${warnings[0].message}`);
	}
	return outcome(reasons, {warnings: warnings.length});
}

/**
 * @description The allowance put back: the licensed maximum reads again, and the call has not been sent early.
 *
 * @param {boolean} deployed Whether the deploy succeeded.
 * @param {object} read The read-budget read after it.
 * @param {number} maximum The licensed maximum the state gate read.
 * @param {string|null} callId The waiting call, or null when there is none to check.
 * @param {Date|null} nextRetry Its retry time.
 *
 * @returns {object} The outcome; values `maximum`, `restoredAt`.
 */
function checkRestored(deployed, read, maximum, callId, nextRetry)
{
	const reasons = [];
	if(!deployed)
	{
		reasons.push('the settings deploy failed');
	}
	if(read?.budget?.maximum !== maximum)
	{
		reasons.push(`maximum=${read?.budget?.maximum}, not the licensed ${maximum}`);
	}
	if(callId)
	{
		const call = findCall(read, callId);
		if(!isWaitingAsSaved(call, nextRetry))
		{
			reasons.push(`the call reads status=${call?.status} nextRetry=${call?.nextRetryText} retries=${call?.retries}: it moved before its retry time`);
		}
	}
	return outcome(reasons, {maximum: read?.budget?.maximum, restoredAt: read?.budget?.time});
}

/**
 * @description The send jobs started since a moment.
 *
 * @param {object} read A read-budget read.
 * @param {Date} since The moment.
 *
 * @returns {object[]} Oldest first.
 */
function findSendJobsSince(read, since)
{
	return (read?.jobs ?? []).filter((job) => job.className === PROCESSOR_CLASS && job.created && job.created >= since)
		.sort((first, second) => first.created - second.created);
}

/**
 * @description Whether the wait for the retry can stop: the call has ended and every job is done.
 *
 * @param {object} read A read-budget read.
 * @param {string} callId The call.
 *
 * @returns {boolean}
 */
function isRetrySettled(read, callId)
{
	const call = (read?.calls ?? []).find((candidate) => isSameId(candidate.id, callId));
	return Boolean(call && !PENDING_STATUSES.includes(call.status) && read.gate?.liveJobs === 0);
}

/**
 * @description Whether exactly two send jobs ran, and both ended Completed: one per due time of the call.
 *
 * @param {object[]} jobs The send jobs since the restore.
 *
 * @returns {boolean}
 */
function hasTwoCompletedJobs(jobs)
{
	return jobs.length === 2 && jobs.every(isCompleted);
}

/**
 * @description Whether the org has an outbound call waiting, or a background job waiting or running. A read with no
 * PROBE GATE line counts as having one, because it cannot show that none is left.
 *
 * @param {object} read A read-budget read.
 *
 * @returns {boolean}
 */
function hasCallOrJobWaiting(read)
{
	return read?.gate?.pendingCalls !== 0 || read?.gate?.liveJobs !== 0;
}

/**
 * @description The retry at its time: the RetryLiveGet handler's one retry means two send jobs, one per due time,
 * both Completed, and the call ends Failed with no retry time and one retry counted; every issue for it is Open and not
 * marked External System May Have Acted (the request never left the org).
 *
 * @param {object} read The last read-budget read.
 * @param {string} callId The call.
 * @param {Date} restoredAt The org's time the allowance was put back.
 * @param {Date} firstDue The call's first retry time.
 *
 * @returns {object} The outcome; values `sendJobs`, `issues`, `firstSendAt`.
 */
function checkRetrySent(read, callId, restoredAt, firstDue)
{
	const reasons = [];
	const call = findCall(read, callId);
	if(!isFailedWithOneRetry(call))
	{
		reasons.push(`the call reads status=${call?.status} nextRetry=${call?.nextRetryText} retries=${call?.retries}, not Failed, null, 1`);
	}
	const jobs = findSendJobsSince(read, restoredAt);
	if(!hasTwoCompletedJobs(jobs))
	{
		reasons.push(`${jobs.length} send jobs since the restore (${jobs.map((job) => job.status).join(', ') || 'none'}), not 2 Completed`);
	}
	if(jobs.length > 0 && jobs[0].created.getTime() < firstDue.getTime() - MILLISECONDS_PER_SECOND)
	{
		reasons.push(`the first send job started at ${jobs[0].created.toISOString()}, before the retry time ${firstDue.toISOString()}`);
	}
	const issues = (read?.issues ?? []).filter((issue) => isSameId(issue.call, callId));
	if(issues.length === 0)
	{
		reasons.push('no issue for the failed call');
	}
	const wrongIssues = issues.filter((issue) => issue.status !== 'Open' || issue.mayHaveActed);
	if(wrongIssues.length > 0)
	{
		reasons.push(`${wrongIssues.length} issue(s) not Open or marked External System May Have Acted`);
	}
	if(hasCallOrJobWaiting(read))
	{
		reasons.push(`pendingCalls=${read?.gate?.pendingCalls} liveJobs=${read?.gate?.liveJobs}, not 0 and 0`);
	}
	return outcome(reasons, {sendJobs: jobs.length, issues: issues.length, firstSendAt: jobs[0]?.created});
}

/**
 * @description The save of one call left at Retrying: it succeeds, with a retry time and one retry counted.
 *
 * @param {object} insert The parsed insert.
 *
 * @returns {object} The outcome; values `callId`.
 */
function checkRetryingInsert(insert)
{
	const reasons = [];
	const row = insert.row;
	if(!isSaved(insert) || !isRowAtRetrying(row))
	{
		reasons.push(`the call reads saved=${insert.savedId} status=${row?.status} retries=${row?.retries} errors=${row?.errors}, not Retrying, 1, null`);
	}
	return outcome(reasons, {callId: row?.id ?? insert.savedId});
}

/**
 * @description Whether the saved row is left at Retrying with a retry time, one retry counted and no error text.
 *
 * @param {object|null} row The row the insert read back.
 *
 * @returns {boolean}
 */
function isRowAtRetrying(row)
{
	return Boolean(row?.exists && row.nextRetry) && hasStatusAndRetries(row, 'Retrying', 1) && row.errors === null;
}

/**
 * @description The watchdog's entries about one call, written after the run started.
 *
 * @param {object} read A read-budget read.
 * @param {string} callId The call.
 * @param {Date} runStart The org's time when the run started.
 *
 * @returns {object[]}
 */
function findWatchdogEntries(read, callId, runStart)
{
	return (read?.logs ?? []).filter((entry) => WATCHDOG_LOCATION.test(entry.at) && isSameId(entry.record, callId) && entry.created && entry.created >= runStart);
}

/**
 * @description The watchdog job made since the schedule: a Completed one when there is one, else the newest.
 *
 * @param {object} read A read-budget read.
 * @param {Date} scheduledAt The org's time of the schedule.
 *
 * @returns {object|undefined}
 */
function findWatchdogJob(read, scheduledAt)
{
	const jobs = (read?.jobs ?? []).filter((candidate) => candidate.className === WATCHDOG_CLASS && candidate.created >= scheduledAt);
	return jobs.find((candidate) => candidate.status === 'Completed') ?? jobs[0];
}

/**
 * @description Whether the wait for the watchdog pass can stop: the call has ended, its issue and warning are there,
 * and the watchdog job has ended.
 *
 * @param {object} read A read-budget read.
 * @param {string} callId The call left at Retrying.
 * @param {Date} scheduledAt The org's time of the schedule.
 * @param {Date} runStart The org's time when the run started.
 *
 * @returns {boolean}
 */
function isWatchdogSettled(read, callId, scheduledAt, runStart)
{
	const call = findCall(read, callId);
	const job = findWatchdogJob(read, scheduledAt);
	return call?.status === 'Failed' && hasEnded(job) && (read.issues ?? []).some((issue) => isSameId(issue.call, callId))
		&& findWatchdogEntries(read, callId, runStart).length > 0;
}

/**
 * @description Whether a call ended Failed after one retry, with no retry time left and the lost-job text.
 *
 * @param {object|undefined} call The call.
 *
 * @returns {boolean}
 */
function isFailedWithLostJobText(call)
{
	return isFailedWithOneRetry(call) && startsWithLostJobText(call.errors);
}

/**
 * @description Whether a call has exactly one issue, Open, marked External System May Have Acted, with the lost-job text.
 *
 * @param {object[]} issues The call's issues.
 *
 * @returns {boolean}
 */
function isSingleLostJobIssue(issues)
{
	return issues.length === 1 && issues[0].status === 'Open' && issues[0].mayHaveActed && startsWithLostJobText(issues[0].errors);
}

/**
 * @description What did not match about the call the watchdog passed over: the call, its issue and its one warning.
 *
 * @param {object|undefined} call The call left at Retrying.
 * @param {object[]} issues The call's issues.
 * @param {object[]} warnings The watchdog's WARN entries for the call.
 *
 * @returns {string[]}
 */
function findWatchdogCallProblems(call, issues, warnings)
{
	const reasons = [];
	if(!isFailedWithLostJobText(call))
	{
		reasons.push(`the call reads status=${call?.status} nextRetry=${call?.nextRetryText} retries=${call?.retries} errors=${call?.errors}, not Failed with the lost-job text`);
	}
	if(!isSingleLostJobIssue(issues))
	{
		reasons.push(`${issues.length} issue(s) for the call, not 1 Open issue marked External System May Have Acted with the lost-job text`);
	}
	if(warnings.length !== 1)
	{
		reasons.push(`${warnings.length} WARN entries from the watchdog for the call, not 1`);
	}
	return reasons;
}

/**
 * @description What did not match about the watchdog pass itself: every "retry time moved" warning names both times,
 * the watchdog job Completed, and the call that had already ended is untouched.
 *
 * @param {object} read The last read-budget read.
 * @param {object|undefined} job The watchdog job.
 * @param {string|null} firstCallId The call that ended before the pass, or null.
 * @param {Date} runStart The org's time when the run started.
 *
 * @returns {string[]}
 */
function findWatchdogPassProblems(read, job, firstCallId, runStart)
{
	const reasons = [];
	const movedWarnings = (read?.logs ?? []).filter((entry) => WATCHDOG_LOCATION.test(entry.at) && entry.created >= runStart
		&& entry.message.startsWith(RETRY_TIME_MOVED_TEXT_START));
	if(movedWarnings.some((entry) => findUtcTimes(entry.message).length !== 2))
	{
		reasons.push('a "retry time moved" warning does not name both times as ISO 8601 times');
	}
	if(!isCompleted(job))
	{
		reasons.push(`the watchdog job is ${job ? job.status : 'missing'}, not Completed`);
	}
	if(firstCallId)
	{
		const first = findCall(read, firstCallId);
		if(!isFailedWithOneRetry(first))
		{
			reasons.push(`the call that had ended reads status=${first?.status} retries=${first?.retries}: the watchdog touched it`);
		}
	}
	return reasons;
}

/**
 * @description One watchdog pass over a call left at Retrying: the call ends Failed with the lost-job text, one Open
 * issue is marked External System May Have Acted, one WARN entry names the call, the watchdog job Completed, and the
 * call that had already ended is untouched. A "retry time moved" warning, written only when the pass finds a call at
 * Retry, must name both times as ISO 8601 times.
 *
 * @param {object} read The last read-budget read.
 * @param {string} callId The call left at Retrying.
 * @param {string|null} firstCallId The call that ended before the pass, or null.
 * @param {Date} scheduledAt The org's time of the schedule.
 * @param {Date} runStart The org's time when the run started.
 *
 * @returns {object} The outcome; values `issues`, `warnings`, `watchdogJob`.
 */
function checkWatchdog(read, callId, firstCallId, scheduledAt, runStart)
{
	const issues = (read?.issues ?? []).filter((issue) => isSameId(issue.call, callId));
	const warnings = findWatchdogEntries(read, callId, runStart).filter((entry) => entry.level === 'WARN');
	const job = findWatchdogJob(read, scheduledAt);
	const reasons = [...findWatchdogCallProblems(findCall(read, callId), issues, warnings), ...findWatchdogPassProblems(read, job, firstCallId, runStart)];
	return outcome(reasons, {issues: issues.length, warnings: warnings.length, watchdogJob: job?.id});
}

/**
 * @description The clean-up's read-back: no probe call, issue, schedule or Account is left.
 *
 * @param {object} left The parsed PROBE LEFT counts.
 *
 * @returns {string[]} What is left, empty when nothing is.
 */
function findLeftovers(left)
{
	return ['calls', 'issues', 'probe schedules', 'launcher accounts', 'chain runs', 'runner rows'].filter((category) => left[category] !== '0')
		.map((category) => `${category}=${left[category] ?? 'not printed'}`);
}

/**
 * @description The clean-up's last read: every job of the probe that has not ended. A job of the probe is a job the run
 * started (such as the chain's first job) or a job of a probe class (such as a filler job).
 *
 * @param {object} read A parsed read-budget run.
 * @param {string[]} probeJobIds The ids of the jobs the run started, or that the clean-up found.
 *
 * @returns {object[]} `{id, className, status}` per job not ended, empty when every one ended.
 */
function findLiveProbeJobs(read, probeJobIds = [])
{
	return (read?.jobs ?? []).filter((job) => LIVE_JOB_STATUSES.includes(job.status)
		&& (probeJobIds.some((id) => isSameId(id, job.id)) || String(job.className).startsWith(PROBE_CLASS_PREFIX)));
}

/**
 * @description The result of the whole run from its steps: BLOCKED when a step was blocked by another call on the org,
 * FAIL when any step failed or was stopped by Ctrl-C, PASS only when every step passed. A blocked run never counts as a pass.
 *
 * @param {object[]} steps `{status}` per step: PASS, FAIL, BLOCKED or INTERRUPTED.
 *
 * @returns {string}
 */
// noinspection FunctionWithMultipleReturnPointsJS
function decideResult(steps)
{
	if(steps.length === 0 || steps.some((step) => step.status !== 'PASS' && step.status !== 'BLOCKED'))
	{
		return 'FAIL';
	}
	return steps.some((step) => step.status === 'BLOCKED') ? 'BLOCKED' : 'PASS';
}

module.exports = {
	ALLOWANCE_HEADROOM, LEAVE_BEFORE_LAUNCH, LAUNCH_ITEMS, LAUNCH_JOB_SIZE, PROCESSOR_CLASS, PENDING_STATUSES, COUNTED_WHEN_QUEUED, COUNTED_WHEN_RUN, planAllowance,
	COUNTED_WHEN_NOT_MEASURED, checkGate, findForeignCalls, checkLowered, checkSpentToLaunchLine, checkPlacesLeftAfterLaunch, isNextHopSettled, checkNextHop, checkSpentToLimit,
	readLaunchRefusedText, checkQueuedInsert, checkQueuedWaiting, findFlowActionWarnings, checkRestored, isRetrySettled, checkRetrySent, checkRetryingInsert, isWatchdogSettled,
	checkWatchdog, findLeftovers, decideResult, LIVE_JOB_STATUSES, WAITING_JOB_STATUSES, findLiveProbeJobs, isProcessorQueueable
};
