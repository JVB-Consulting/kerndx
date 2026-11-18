// SPDX-License-Identifier: Apache-2.0
// Reads the PROBE lines the elastic limits probe's scripts print, and the times in them. The probe prints its times in
// Eastern time (America/New_York) as `yyyy-MM-dd HH:mm:ss`; Kern's own messages carry ISO 8601 times in UTC.
'use strict';

const PROBE_TIME_ZONE = 'America/New_York';
const TIME = '(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}|null)';
const DEBUG_MARKER = '|DEBUG|';
const MILLISECONDS_PER_MINUTE = 60_000;
// The probe prints whole seconds and Kern's ISO times carry milliseconds, so two readings of one time differ by less than this.
const SAME_INSTANT_TOLERANCE_MILLISECONDS = 1_000;
// An ISO 8601 time in UTC: its trailing Z marks UTC. Kern stores retry times in whole seconds, so the time ends in
// `.000Z` or in `Z`.
const ISO_UTC_TIME = /\b(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.000)?Z)/g;
const ACCOUNT_ID = /\b001[0-9A-Za-z]{12}(?:[0-9A-Za-z]{3})?\b/g;
const ID_PREFIX_LENGTH = 15;

const PATTERNS = {
	budget: new RegExp(`^PROBE BUDGET time=${TIME} used=(-?\\d+) maximum=(-?\\d+) remaining=(-?\\d+)`),
	gate: /^PROBE GATE remaining=(-?\d+) probeSchedules=(\d+) pendingCalls=(\d+) outboundInterviews=(\d+) runningChains=(\d+) liveJobs=(\d+)/,
	call: new RegExp(`^PROBE CALL (pending|settled) id=(\\S+) status=(\\S+) nextRetry=${TIME} retries=(\\S+) created=${TIME} modified=${TIME} errors=(.*)$`),
	issue: new RegExp(`^PROBE ISSUE id=(\\S+) name=(\\S+) status=(\\S+) call=(\\S+) created=${TIME} mayHaveActed=(\\S+) errors=(.*)$`),
	log: new RegExp(`^PROBE LOG level=(\\S+) at=(\\S+) record=(\\S+) created=${TIME} message=(.*)$`),
	job: new RegExp(`^PROBE JOB id=(\\S+) class=(\\S+) type=(\\S+) status=(\\S+) created=${TIME} completed=${TIME} errors=(\\S+) extended=(.*)$`),
	insertStart: new RegExp(`^PROBE CALL INSERT time=${TIME} mode=(\\S+) remaining=(-?\\d+) rowsBefore=(\\d+)`),
	insertSaved: /^PROBE CALL INSERT saved id=(\S+)/,
	insertRefused: /^PROBE CALL INSERT refused (.*)$/,
	insertRow: new RegExp(`^PROBE CALL INSERT rowExists=(true|false)(?: id=(\\S+) status=(\\S+) nextRetry=${TIME} retries=(\\S+) errors=(.*))?$`),
	insertJob: /^PROBE CALL INSERT job id=(\S+) class=(\S+) status=(\S+)/,
	spendStart: /^PROBE SPEND time=.* maximum=(-?\d+) remainingBefore=(-?\d+) leave=(-?\d+) toQueue=(\d+)/,
	spendQueued: /^PROBE SPEND queued=(\d+) remainingAfterEnqueueSameTransaction=(-?\d+)/,
	spendRefused: /^PROBE SPEND refused (.*)$/,
	launcherItems: /^PROBE LAUNCHER items=(\S*) run=(\d+)/,
	launcherAccepted: /^PROBE LAUNCHER run=(\d+) accepted job=(\S+)(?: \(no job row\)| class=(\S+) type=(\S+) status=(\S+))/,
	launcherRefused: /^PROBE LAUNCHER run=(\d+) refused (.*)$/,
	scheduleOnce: new RegExp(`^PROBE SCHEDULE ONCE name=(.+) cronId=(\\S+) fireAt=${TIME} cron=.* threshold=(\\S+)`),
	left: /^PROBE LEFT (.+?)=(\S+)/,
	scheduleLeft: /^SECTION89 SCHEDULE LEFT id=(\S+) name=(.*)$/,
	schedulesSwept: /^SECTION89 SCHEDULES action=(\S+) aborted=(\d+) left=(\d+)/,
	stopJob: /^PROBE STOP JOB id=(\S+) status=(\S+) aborted=(true|false)(?: class=(\S+))?/,
	stopJobs: /^PROBE STOP JOBS action=(\S+) found=(\d+) aborted=(\d+) left=(\d+)/
};

/**
 * @description The USER_DEBUG messages of an anonymous Apex log, in order.
 *
 * @param {string} logs The log text `sf apex run --json` returned.
 *
 * @returns {string[]}
 */
function readDebugLines(logs)
{
	return String(logs ?? '').split('\n').filter((line) => line.includes('|USER_DEBUG|'))
		.map((line) => line.slice(line.lastIndexOf(DEBUG_MARKER) + DEBUG_MARKER.length).trim());
}

/**
 * @description How many minutes Eastern time is ahead of UTC at one instant (a negative number: -300 or -240).
 *
 * @param {Date} instant The instant.
 *
 * @returns {number}
 */
function easternOffsetMinutes(instant)
{
	// noinspection JSCheckFunctionSignatures
	const parts = new Intl.DateTimeFormat('en-US', {
		timeZone: PROBE_TIME_ZONE, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit'
	}).formatToParts(instant);
	const value = (type) => Number(parts.find((part) => part.type === type).value);
	const asUtc = Date.UTC(value('year'), value('month') - 1, value('day'), value('hour'), value('minute'), value('second'));
	return Math.round((asUtc - Math.floor(instant.getTime() / 1000) * 1000) / MILLISECONDS_PER_MINUTE);
}

/**
 * @description A time the probe printed, as a date. The probe prints Eastern time to the second.
 *
 * @param {string|null} text The printed time, or `null` or nothing.
 *
 * @returns {Date|null} The instant, or null when the probe printed none.
 */
// noinspection FunctionWithMultipleReturnPointsJS
function parseProbeTime(text)
{
	if(!text || text === 'null')
	{
		return null;
	}
	const match = String(text).match(/^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/);
	if(!match)
	{
		throw new Error(`Not a probe time: ${text}`);
	}
	const asUtc = Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]), Number(match[4]), Number(match[5]), Number(match[6]));
	let guess = asUtc;
	// Two rounds settle the offset, also on the day the clocks change.
	for(let round = 0; round < 2; round++)
	{
		guess = asUtc - easternOffsetMinutes(new Date(guess)) * MILLISECONDS_PER_MINUTE;
	}
	return new Date(guess);
}

/**
 * @description The ISO 8601 UTC times a text carries (such as `2026-11-08T12:15:42.000Z`), in order.
 *
 * @param {string} text The text.
 *
 * @returns {Date[]}
 */
function findUtcTimes(text)
{
	return [...String(text ?? '').matchAll(ISO_UTC_TIME)].map((match) => new Date(match[1]));
}

/**
 * @description Whether two readings name the same instant: Kern's ISO time and the probe's printed time.
 *
 * @param {Date|null} first One reading.
 * @param {Date|null} second The other.
 *
 * @returns {boolean}
 */
function isSameInstant(first, second)
{
	return Boolean(first && second) && Math.abs(first.getTime() - second.getTime()) < SAME_INSTANT_TOLERANCE_MILLISECONDS;
}

/**
 * @description Whether two record ids name the same record: a 15-character id and its 18-character form match.
 *
 * @param {string} first One id.
 * @param {string} second The other.
 *
 * @returns {boolean}
 */
function isSameId(first, second)
{
	return Boolean(first && second) && String(first).slice(0, ID_PREFIX_LENGTH) === String(second).slice(0, ID_PREFIX_LENGTH);
}

/**
 * @description The Account ids a text names, in order.
 *
 * @param {string} text The text, such as a log entry's context.
 *
 * @returns {string[]}
 */
function findAccountIds(text)
{
	return String(text ?? '').match(ACCOUNT_ID) ?? [];
}

/**
 * @description A log entry's message and, for an entry at a refused next job, its context, which follows the message.
 *
 * @param {string} at Where the entry was written.
 * @param {string} rest The text after `message=`.
 *
 * @returns {{message: string, context: string|null}}
 */
// noinspection FunctionWithMultipleReturnPointsJS
function splitLogMessage(at, rest)
{
	const marker = ' context=';
	const position = rest.lastIndexOf(marker);
	if(!at.endsWith('/enqueueNextHop') || position < 0)
	{
		return {message: rest, context: null};
	}
	return {message: rest.slice(0, position), context: rest.slice(position + marker.length)};
}

/**
 * @description Everything a read-budget.apex run printed, parsed.
 *
 * @param {string[]} lines The script's debug lines.
 *
 * @returns {object} `{budget, gate, calls, issues, logs, jobs}`; budget and gate are null when the line is missing.
 */
function parseReadBudget(lines)
{
	const read = {budget: null, gate: null, calls: [], issues: [], logs: [], jobs: []};
	const handlers = [
		[PATTERNS.budget, (match) =>
		{
			read.budget = {time: parseProbeTime(match[1]), used: Number(match[2]), maximum: Number(match[3]), remaining: Number(match[4])};
		}],
		[PATTERNS.gate, (match) =>
		{
			read.gate = {
				remaining: Number(match[1]), probeSchedules: Number(match[2]), pendingCalls: Number(match[3]), outboundInterviews: Number(match[4]),
				runningChains: Number(match[5]), liveJobs: Number(match[6])
			};
		}],
		[PATTERNS.call, (match) => read.calls.push({
			id: match[2], status: match[3], nextRetry: parseProbeTime(match[4]), nextRetryText: match[4], retries: Number(match[5]),
			created: parseProbeTime(match[6]), errors: readErrors(match[8])
		})],
		[PATTERNS.issue, (match) => read.issues.push({
			id: match[1], status: match[3], call: match[4], created: parseProbeTime(match[5]), mayHaveActed: match[6] === 'true',
			errors: readErrors(match[7])
		})],
		[PATTERNS.log, (match) => read.logs.push({
			level: match[1], at: match[2], record: match[3], created: parseProbeTime(match[4]), ...splitLogMessage(match[2], match[5])
		})],
		[PATTERNS.job, (match) => read.jobs.push({
			id: match[1], className: match[2], type: match[3], status: match[4], created: parseProbeTime(match[5]), completed: parseProbeTime(match[6]),
			errors: match[7], extended: match[8]
		})]
	];
	for(const line of lines)
	{
		applyFirstMatch(line, handlers);
	}
	return read;
}

/**
 * @description Runs the handler of the first pattern a line matches, and no other. A line that matches no pattern is
 * left alone.
 *
 * @param {string} line One debug line.
 * @param {Array[]} handlers Each pattern with the handler that takes its match, as a pair, in the order to try.
 */
function applyFirstMatch(line, handlers)
{
	const handler = handlers.find((candidate) => candidate[0].test(line));
	if(handler)
	{
		handler[1](line.match(handler[0]));
	}
}

/**
 * @description The errors text the probe printed, or null when it printed `null`.
 *
 * @param {string} text The printed text.
 *
 * @returns {string|null}
 */
function readErrors(text)
{
	return text === 'null' ? null : text;
}

/**
 * @description What an insert-outbound-call.apex run printed, parsed.
 *
 * @param {string[]} lines The script's debug lines.
 *
 * @returns {object} `{start, savedId, refused, row, jobs}`.
 */
function parseInsert(lines)
{
	const insert = {start: null, savedId: null, refused: null, row: null, jobs: []};
	const handlers = [
		[PATTERNS.insertStart, (match) =>
		{
			insert.start = {time: parseProbeTime(match[1]), mode: match[2], remaining: Number(match[3]), rowsBefore: Number(match[4])};
		}],
		[PATTERNS.insertSaved, (match) =>
		{
			insert.savedId = match[1];
		}],
		[PATTERNS.insertRefused, (match) =>
		{
			insert.refused = match[1];
		}],
		[PATTERNS.insertRow, (match) =>
		{
			insert.row = match[1] === 'true'
				? {exists: true, id: match[2], status: match[3], nextRetry: parseProbeTime(match[4]), retries: Number(match[5]), errors: readErrors(match[6])}
				: {exists: false};
		}],
		[PATTERNS.insertJob, (match) => insert.jobs.push({id: match[1], className: match[2], status: match[3]})]
	];
	for(const line of lines)
	{
		applyFirstMatch(line, handlers);
	}
	return insert;
}

/**
 * @description What a spend-budget.apex run printed, parsed.
 *
 * @param {string[]} lines The script's debug lines.
 *
 * @returns {object} `{maximum, remainingBefore, leave, toQueue, queued, remainingAfter, refused}`; numbers are null when missing.
 */
function parseSpend(lines)
{
	const spend = {maximum: null, remainingBefore: null, leave: null, toQueue: null, queued: null, remainingAfter: null, refused: null};
	for(const line of lines)
	{
		let match;
		if((match = line.match(PATTERNS.spendStart)))
		{
			Object.assign(spend, {maximum: Number(match[1]), remainingBefore: Number(match[2]), leave: Number(match[3]), toQueue: Number(match[4])});
		}
		else if((match = line.match(PATTERNS.spendQueued)))
		{
			Object.assign(spend, {queued: Number(match[1]), remainingAfter: Number(match[2])});
		}
		else if((match = line.match(PATTERNS.spendRefused)))
		{
			spend.refused = match[1];
		}
	}
	return spend;
}

/**
 * @description What a launch-adaptive-processor.apex run printed for its first launch, parsed.
 *
 * @param {string[]} lines The script's debug lines.
 *
 * @returns {object} `{accountIds, accepted, jobId, className, type, status, refused}`.
 */
function parseLauncher(lines)
{
	const launch = {accountIds: [], accepted: false, jobId: null, className: null, type: null, status: null, refused: null};
	for(const line of lines)
	{
		let match;
		if((match = line.match(PATTERNS.launcherItems)) && match[2] === '0')
		{
			launch.accountIds = match[1] ? match[1].split(',') : [];
		}
		else if((match = line.match(PATTERNS.launcherAccepted)) && match[1] === '0')
		{
			Object.assign(launch, {accepted: true, jobId: match[2], className: match[3] ?? null, type: match[4] ?? null, status: match[5] ?? null});
		}
		else if((match = line.match(PATTERNS.launcherRefused)) && match[1] === '0')
		{
			launch.refused = match[2];
		}
	}
	return launch;
}

/**
 * @description What a schedule-once.apex run printed, parsed.
 *
 * @param {string[]} lines The script's debug lines.
 *
 * @returns {object|null} `{name, cronId, fireAt, threshold}`, or null when the line is missing.
 */
// noinspection FunctionWithMultipleReturnPointsJS
function parseScheduleOnce(lines)
{
	for(const line of lines)
	{
		const match = line.match(PATTERNS.scheduleOnce);
		if(match)
		{
			return {name: match[1], cronId: match[2], fireAt: parseProbeTime(match[3]), threshold: match[4]};
		}
	}
	return null;
}

/**
 * @description The counts a clean-up.apex run printed, one per category.
 *
 * @param {string[]} lines The script's debug lines.
 *
 * @returns {object} Category name to the printed count (text: it can read `unknown`).
 */
function parseLeft(lines)
{
	const left = {};
	for(const line of lines)
	{
		const match = line.match(PATTERNS.left);
		if(match)
		{
			left[match[1]] = match[2];
		}
	}
	return left;
}

/**
 * @description What abort-schedules-by-name.apex printed: how many schedules it stopped, and each one still left.
 *
 * @param {string[]} lines The script's debug lines.
 *
 * @returns {{printed: boolean, aborted: number|null, left: object[]}} `printed` is false when the summary line is missing;
 *          `left` holds `{id, name}` per schedule still there.
 */
function parseScheduleSweep(lines)
{
	const sweep = {printed: false, aborted: null, left: []};
	for(const line of lines)
	{
		let match;
		if((match = line.match(PATTERNS.scheduleLeft)))
		{
			sweep.left.push({id: match[1], name: match[2]});
		}
		else if((match = line.match(PATTERNS.schedulesSwept)))
		{
			Object.assign(sweep, {printed: true, aborted: Number(match[2])});
		}
	}
	return sweep;
}

/**
 * @description What abort-probe-jobs.apex printed: each job it found (of the adaptive processor or of a probe
 * class, such as a filler job), and the counts.
 *
 * @param {string[]} lines The script's debug lines.
 *
 * @returns {{printed: boolean, found: number|null, aborted: number|null, left: number|null, jobs: object[]}} `printed`
 *          is false when the summary line is missing; `jobs` holds `{id, status, aborted, className}` per job found
 *          (`className` is null when the line names no class).
 */
function parseStoppedJobs(lines)
{
	const stop = {printed: false, found: null, aborted: null, left: null, jobs: []};
	for(const line of lines)
	{
		let match;
		if((match = line.match(PATTERNS.stopJob)))
		{
			stop.jobs.push({id: match[1], status: match[2], aborted: match[3] === 'true', className: match[4] ?? null});
		}
		else if((match = line.match(PATTERNS.stopJobs)))
		{
			Object.assign(stop, {printed: true, found: Number(match[2]), aborted: Number(match[3]), left: Number(match[4])});
		}
	}
	return stop;
}

module.exports = {
	PROBE_TIME_ZONE, readDebugLines, parseProbeTime, easternOffsetMinutes, findUtcTimes, isSameInstant, isSameId, findAccountIds, splitLogMessage,
	parseReadBudget, parseInsert, parseSpend, parseLauncher, parseScheduleOnce, parseLeft,
	parseScheduleSweep, parseStoppedJobs
};
