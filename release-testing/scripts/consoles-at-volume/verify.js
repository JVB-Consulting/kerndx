// SPDX-License-Identifier: Apache-2.0
// Reconciles the manifest against the database: one claim per count the load promised, one PASS or FAIL line each.
const {recordStage, KINDS} = require('./manifest');

// Three sweep cadences: the platform scheduler is not real time, and a sweep that runs late is not a failed re-drive.
const REDRIVE_WAIT_MILLISECONDS = 20 * 60_000;
const REDRIVE_POLL_MILLISECONDS = 60_000;
const REDRIVE_MESSAGE = 'Chain re-driven by watchdog after a stall';
// Wave kinds whose rows the engine writes without a launch entry under the action (the wave launches carry no live correlation).
const WAVE_KINDS = [
	'slowExport',
	'switchedOff',
	'stallProbe',
	'deferredDispatch',
	'idempotentDeferredDispatch'
];
const LEAF_CHAIN_INDEX = 3;
const RUNBOOK_SECTION = 83;
// This section's measures, one PERF_ROW line each, in the order they are printed.
const PERFORMANCE_MEASURES = ['runs', 'jobsPerMinute', 'peakActive', 'peakHolding', 'samplesAboveFifty', 'watchdogRowsPerSweep', 'backstopRefusals', 'lockRefusals'];
// The fixed words the engine's log line starts with when the status backstop refuses one of its chain run writes.
const BACKSTOP_REFUSAL_PHRASE = 'Chain run transition refused by the backstop';
// The platform's status code for a save refused because another transaction held the row's lock. In the LIKE filter
// each underscore matches any one character; the class-method and exception-type filters keep that from counting other rows.
const LOCK_REFUSAL_TOKEN = 'UNABLE_TO_LOCK_ROW';
// Where the framework's save logs a failure that stopped it, without a namespace.
const COMMIT_CLASS_METHOD = 'DML_Transaction.commitWork';
// The name of the claim that counts the backstop's refusals; the output line and the manifest's counts read it back.
const BACKSTOP_CLAIM = 'backstop refusals counted';
// The name of the claim that counts the lock refusals; the output line and the manifest's counts read it back.
const LOCK_CLAIM = 'lock refusals counted';
// Shown when a synthesized Stalled row no longer reads Stalled: the watchdog can only mark such a row again, so a row
// that moved was given a job id, or something other than the watchdog changed it. An end time cannot move it: the
// watchdog skips a row that has one, and a Stalled row may not have one.
const STALLED_FIXTURE_NOTE = 'a synthesized row has no job id, so the watchdog can only mark it Stalled again; a row that moved was given a job id, '
	+ 'or was changed by something other than the watchdog';
// How the watchdog's reason for ending a started-step row begins (the AsyncChain_RecoveryStoppedAtStartedStep label,
// with the step name the rows carry). The short message of its ERROR entry begins the same way.
const STARTED_STEP_REASON_START = 'Recovery stopped at step Create Foobar.';
const STARTED_STEP_ENTRY_START = 'Recovery stopped at step';
// Both backstop refusal entries, the engine's and the trigger's, match this pattern.
const ANY_BACKSTOP_REFUSAL = 'Chain run % refused by the backstop';
// How the watchdog's ERROR entries begin when a re-drive or a stall write fails for one row (UTIL_AsyncChain
// redriveWhenProvablyDead and markStalledFromWatchdog). A sweep that dies on a limit it cannot catch logs nothing; its rows
// stay Stalled, which the started-step and dead-job claims catch.
const WATCHDOG_FAILURE_STARTS = ['Watchdog re-drive failed', 'Watchdog stall DML failed'];
// One sweep looks at fifty rows at most and every started-step row costs it three queries, so a sweep ends about thirty
// of them. Verify waits one sweep interval for every twenty-five rows on top of the dead-job wait.
const STARTED_ROWS_PER_SWEEP_FLOOR = 25;
const SWEEP_INTERVAL_MILLISECONDS = 5 * 60_000;
// The three budgets the verify line reports for the busiest sweep, as UTIL_Limits names them in a log entry's limits.
const SWEEP_BUDGETS = ['Queries', 'DML Statements', 'Cpu Time'];
const BUDGET_LINE = /^(.+): (\d+) of (\d+)$/;

/**
 * @description Ids as the body of a SOQL IN list.
 *
 * @param {string[]} ids The ids.
 *
 * @returns {string}
 */
function quoted(ids)
{
	return ids.map((id) => `'${id}'`).join(', ');
}

/**
 * @description What an action should hold once the operator wave has acted on it: a retry turns a Failed run
 * Completed, a restart adds a clone that fails again (the restartable shape fails on every run).
 *
 * @param {object} action The action's manifest record.
 * @param {object} wave The manifest's operator wave.
 *
 * @returns {{runs: number, byStatus: object}}
 */
function adjustedExpectation(action, wave)
{
	const retries = (wave.retries || []).filter((press) => press.actionId === action.id).length;
	const restarts = (wave.restarts || []).filter((press) => press.actionId === action.id).length;
	const byStatus = {...action.expected.byStatus};
	if(retries + restarts > 0)
	{
		byStatus.Completed = (byStatus.Completed || 0) + retries;
		byStatus.Failed = (byStatus.Failed || 0) - retries + restarts;
	}
	return {runs: action.expected.runs + restarts, byStatus};
}

/**
 * @description The claims one action makes: its run count, its counts by status, and for the reconciliation its
 * leaves and its absence of runs left Running or Stalled; every engine action also promises a launch entry.
 *
 * @param {object} action The action's manifest record.
 * @param {object} wave The manifest's operator wave.
 * @param {Function} field The org's field namer.
 * @param {Function} count Adds a chain-row count claim.
 * @param {string} entries The log entry object's name.
 *
 * @returns {object[]} The entry claims (the count claims go through `count`).
 */
function actionClaims(action, wave, field, count, entries)
{
	const under = `${field('RootCorrelationId__c')} = '${action.id}'`;
	const tooMany = 'more rows than launched means an unexpected re-drive or a duplicate launch';
	const expected = adjustedExpectation(action, wave);
	count(`action ${action.id} holds ${expected.runs} runs`, under, expected.runs, 'equals', tooMany, {kind: 'runs', action: action.id});
	for(const [status, runs] of Object.entries(expected.byStatus))
	{
		const oneStatus = {kind: 'statuses', action: action.id, statuses: [status]};
		count(`action ${action.id} holds ${runs} ${status}`, `${under} AND ${field('Status__c')} = '${status}'`, runs, 'equals', undefined, oneStatus);
	}
	if(action.kind === 'reconciliation')
	{
		const leaves = `${under} AND ${field('ChainName__c')} = '${action.chainNames[LEAF_CHAIN_INDEX]}'`;
		count(`action ${action.id} has ${action.expected.leaves} leaves`, leaves, action.expected.leaves, 'equals', undefined, {kind: 'leaves', action: action.id});
		const unfinished = {kind: 'statuses', action: action.id, statuses: ['Running', 'Stalled']};
		count(`action ${action.id} has no run left Running or Stalled`, `${under} AND ${field('Status__c')} IN ('Running', 'Stalled')`, 0, 'equals', undefined, unfinished);
	}
	if(action.synthesized || WAVE_KINDS.includes(action.kind))
	{
		return [];
	}
	const launchEntries = `SELECT COUNT() FROM ${entries} WHERE ${field('RootCorrelationId__c')} = '${action.id}' AND ${field('LogLevel__c')} = 'INFO'`;
	return [{name: `engine action ${action.id} has a launch entry`, soql: launchEntries, expected: 1, compare: 'atLeast', aggregate: {kind: 'launchEntries', action: action.id}}];
}

/**
 * @description The per-action counts of the whole run in three grouped reads, so a verify at volume asks the org a
 * handful of questions rather than one per claim: chain rows by action, status and failure category; the
 * reconciliation's leaves by action; INFO entries by action.
 *
 * @param {object} salesforce The org door.
 * @param {string} fieldPrefix The org's field prefix.
 * @param {object} manifest The manifest.
 *
 * @returns {{runs: Map, byStatus: Map, byStatusAndCategory: Map, leaves: Map, launchEntries: Map}}
 */
function readAggregates(salesforce, fieldPrefix, manifest)
{
	const field = (name) => `${fieldPrefix}${name}`;
	const chains = field('AsyncChainExecution__c');
	const root = field('RootCorrelationId__c');
	const underToken = `${root} LIKE '${manifest.runToken}-${KINDS.action}-%'`;
	const reconciliation = manifest.actions.find((action) => action.kind === 'reconciliation');
	const leafChain = reconciliation ? reconciliation.chainNames[LEAF_CHAIN_INDEX] : 'Volume_AccountReconcile';
	const rows = salesforce.query(`SELECT ${root} root, ${field('Status__c')} status, ${field('FailureCategory__c')} category, COUNT(Id) n FROM ${chains} `
			+ `WHERE ${underToken} GROUP BY ${root}, ${field('Status__c')}, ${field('FailureCategory__c')}`).records;
	const leafRows = salesforce.query(`SELECT ${root} root, COUNT(Id) n FROM ${chains} WHERE ${field('ChainName__c')} = '${leafChain}' AND ${underToken} GROUP BY ${root}`).records;
	const entriesQuery = `SELECT ${root} root, COUNT(Id) n FROM ${field('LogEntry__c')} WHERE ${field('LogLevel__c')} = 'INFO' AND ${underToken} GROUP BY ${root}`;
	const entryRows = salesforce.query(entriesQuery).records;
	const add = (map, key, n) => map.set(key, (map.get(key) || 0) + Number(n));
	const aggregates = {runs: new Map(), byStatus: new Map(), byStatusAndCategory: new Map(), leaves: new Map(), launchEntries: new Map()};
	for(const row of rows)
	{
		add(aggregates.runs, row.root, row.n);
		add(aggregates.byStatus.get(row.root) || aggregates.byStatus.set(row.root, new Map()).get(row.root), row.status, row.n);
		add(aggregates.byStatusAndCategory, `${row.root}|${row.status}|${row.category || ''}`, row.n);
	}
	leafRows.forEach((row) => add(aggregates.leaves, row.root, row.n));
	entryRows.forEach((row) => add(aggregates.launchEntries, row.root, row.n));
	return aggregates;
}

/**
 * @description A claim's observed count from the grouped reads, or null when the claim is not one of them.
 *
 * @param {object} claim The claim.
 * @param {object} aggregates The grouped reads.
 *
 * @returns {number|null}
 */
function observeFromAggregates(claim, aggregates)
{
	const {kind, action, statuses, status, category} = claim.aggregate || {};
	if(kind === 'runs')
	{
		return aggregates.runs.get(action) || 0;
	}
	if(kind === 'statuses')
	{
		const byStatus = aggregates.byStatus.get(action) || new Map();
		return statuses.reduce((sum, name) => sum + (byStatus.get(name) || 0), 0);
	}
	if(kind === 'statusAndCategory')
	{
		return aggregates.byStatusAndCategory.get(`${action}|${status}|${category}`) || 0;
	}
	if(kind === 'leaves' || kind === 'launchEntries')
	{
		return aggregates[kind].get(action) || 0;
	}
	return null;
}

/**
 * @description The claims the operator wave makes: every retry, restart, abort, the kill switch, every dead-job stall.
 *
 * @param {object} manifest The manifest.
 * @param {Function} field The org's field namer.
 * @param {Function} count Adds a chain-row count claim.
 * @param {string} entries The log entry object's name.
 * @param {string} chains The chain object's name.
 *
 * @returns {object[]} The claims that read other objects.
 */
function waveClaims(manifest, field, count, entries, chains)
{
	const wave = manifest.operatorWave;
	const claims = [];
	for(const retry of wave.retries)
	{
		const stamped = `Id = '${retry.executionId}' AND ${field('Status__c')} = 'Completed' AND ${field('LastManualRetryAt__c')} != null`;
		count(`retried run ${retry.executionId} is Completed with its retry stamped`, stamped, 1);
	}
	for(const restart of wave.restarts)
	{
		count(`restarted run ${restart.executionId} has a clone`, `${field('SourceExecution__c')} = '${restart.executionId}'`, 1, 'atLeast');
	}
	for(const abort of wave.aborts)
	{
		const byOperator = `Id = '${abort.executionId}' AND ${field('Status__c')} = 'Aborted' AND ${field('FailureCategory__c')} = 'OperatorAbort'`;
		count(`aborted run ${abort.executionId} is Aborted by the operator`, byOperator, 1);
	}
	if(wave.killSwitch)
	{
		const {actionId, launched} = wave.killSwitch;
		const underKillSwitch = `${field('RootCorrelationId__c')} = '${actionId}' AND ${field('Status__c')} = 'Aborted' AND ${field('FailureCategory__c')} = 'KillSwitch'`;
		const aggregate = {kind: 'statusAndCategory', action: actionId, status: 'Aborted', category: 'KillSwitch'};
		count(`kill switch action ${actionId} holds ${launched} Aborted under KillSwitch`, underKillSwitch, launched, 'equals', undefined, aggregate);
	}
	// A dead-job run is re-driven only when its step declares itself safe to repeat. The step was marked started before
	// its job was queued, and an aborted job reads the same whether it died in the queue or mid-work, so the watchdog
	// ends every other dead-job run Failed at the started step.
	const redrivable = wave.deadJobStalls.filter((stall) => stall.idempotent === true);
	const refused = wave.deadJobStalls.filter((stall) => stall.idempotent !== true);
	for(const stall of wave.deadJobStalls)
	{
		if(stall.idempotent === true)
		{
			const redriven = `Id = '${stall.executionId}' AND ${field('Status__c')} = 'Completed' AND ${field('CurrentJobId__c')} != '${stall.jobId}' `
					+ `AND ${field('RunKey__c')} != '${stall.runKey}'`;
			count(`dead-job run ${stall.executionId} was re-driven`, redriven, 1);
		}
		const jobDead = `SELECT COUNT() FROM AsyncApexJob WHERE Id = '${stall.jobId}' AND Status = 'Aborted'`;
		claims.push({name: `dead-job run ${stall.executionId}'s killed job ${stall.jobId} is dead`, soql: jobDead, expected: 1, compare: 'equals'});
	}
	claims.push(...startedStepEndClaims(refused.map((stall) => stall.executionId), {
		ended: `dead-job runs number ${refused.length} on a step not safe to repeat ended Failed at the started step`,
		entries: `dead-job runs on a step not safe to repeat have one ERROR entry each (${refused.length})`,
		reasonStart: STARTED_STEP_ENTRY_START
	}, field, entries, chains));
	if(redrivable.length > 0)
	{
		// The engine's own record of every re-drive it made, written for the run's record (no correlation): exactly one
		// per re-drivable dead-job run under this load, and none for any other run since the load started.
		const slice = quoted(redrivable.map((stall) => stall.executionId));
		const redriveEntries = `SELECT COUNT() FROM ${entries} WHERE ${field('ShortMessage__c')} LIKE '${REDRIVE_MESSAGE}%'`;
		claims.push({
			name: `watchdog re-drives number ${redrivable.length}`, soql: `${redriveEntries} AND ${field('RecordId__c')} IN (${slice})`,
			expected: redrivable.length, compare: 'equals'
		});
		// Read in two steps so that a re-drive of another load's stale row on a shared org never counts: first the
		// entries since the run started for records outside the slice, then how many of those records are this run's.
		const outside = `SELECT ${field('RecordId__c')} FROM ${entries} WHERE ${field('ShortMessage__c')} LIKE '${REDRIVE_MESSAGE}%' AND CreatedDate >= ${manifest.startedAt} `
				+ `AND ${field('RecordId__c')} NOT IN (${slice})`;
		const observe = (salesforce) =>
		{
			const records = salesforce.query(outside).records.map((row) => row[field('RecordId__c')]);
			if(records.length === 0)
			{
				return 0;
			}
			const mine = `SELECT COUNT() FROM ${chains} WHERE Id IN (${quoted(records)}) AND ${field('RootCorrelationId__c')} LIKE '${manifest.runToken}-${KINDS.action}-%'`;
			return salesforce.query(mine).totalSize;
		};
		claims.push({
			name: 'no re-drive outside the dead-job slice', observe, expected: 0, compare: 'equals',
			note: 'a re-drive outside the dead-job slice means the sweep read a healthy chain as dead (the one-step job-id lag), or ran again a step '
					+ 'not safe to repeat; a finding for the engine, not for the driver'
		});
	}
	for(const probe of wave.stallProbes || [])
	{
		count(`stall probe ${probe} is Stalled`, `Id = '${probe}' AND ${field('Status__c')} = 'Stalled'`, 1);
	}
	return claims;
}

/**
 * @description Two counts kept for the next release's decision on locking chain runs, not checks: they always pass.
 * The first counts chain run writes the status backstop refused because the row changed between the engine's read and
 * its write. The second counts the framework's saves that failed because another transaction held a row lock; read it
 * as "at least this many", because the per-row failures of a partial save are logged in another form and are not
 * counted. Both read the log's short message, because the long message cannot be filtered, and only entries made since
 * the load started.
 *
 * @param {object} manifest The manifest.
 * @param {Function} field The org's field namer.
 * @param {string} entries The log entry object's name.
 * @param {string} fieldPrefix The org's field prefix, empty when the org has no namespace.
 *
 * @returns {object[]} The two claims.
 */
function refusalClaims(manifest, field, entries, fieldPrefix)
{
	const since = `SELECT COUNT() FROM ${entries} WHERE CreatedDate >= ${manifest.startedAt}`;
	const backstop = `${since} AND ${field('ShortMessage__c')} LIKE '${BACKSTOP_REFUSAL_PHRASE}%'`;
	// On a namespaced org the class name the log records may carry the namespace; both spellings are read so either way counts.
	const namespace = fieldPrefix.replace(/__$/, '');
	const commitPlaces = [COMMIT_CLASS_METHOD, ...(namespace ? [`${namespace}.${COMMIT_CLASS_METHOD}`] : [])].map((place) => `'${place}'`).join(', ');
	const lock = `${since} AND ${field('ClassMethod__c')} IN (${commitPlaces}) AND ${field('ExceptionType__c')} = 'System.DmlException' `
			+ `AND ${field('ShortMessage__c')} LIKE '%${LOCK_REFUSAL_TOKEN}%'`;
	return [
		{name: BACKSTOP_CLAIM, soql: backstop, expected: 0, compare: 'atLeast'},
		{name: LOCK_CLAIM, soql: lock, expected: 0, compare: 'atLeast'}
	];
}

/**
 * @description The claims the started-step Stalled rows make. Each row carries the id of a job that does not exist and
 * a current step that started and saved no result, without saying it is safe to run twice. So the watchdog must end
 * every row Failed, with the started-step reason and an end time, and write one ERROR entry for it. It must never run
 * the step again, and no write of its own on these rows may be refused by the status backstop. The never-started case
 * (a dead job whose step never ran, re-driven) is the dead-job stalls' claim, and the screen-fixture rows keep theirs.
 *
 * @param {object} manifest The manifest.
 * @param {Function} field The org's field namer.
 * @param {string} entries The log entry object's name.
 * @param {string} chains The chain object's name.
 *
 * @returns {object[]} The claims; none when no started-step rows were laid.
 */
function startedStepClaims(manifest, field, entries, chains)
{
	const startedRows = manifest.synthesized.startedStepRows || [];
	if(startedRows.length === 0)
	{
		return [];
	}
	const refusals = `SELECT COUNT() FROM ${entries} WHERE ${field('ShortMessage__c')} LIKE '${ANY_BACKSTOP_REFUSAL}%' AND ${field('RecordId__c')} IN (${quoted(startedRows)})`;
	return [
		...startedStepEndClaims(startedRows, {
			ended: `started-step rows number ${startedRows.length} ended Failed at the started step`,
			entries: `started-step rows have one ERROR entry each (${startedRows.length})`,
			reasonStart: STARTED_STEP_REASON_START
		}, field, entries, chains),
		{name: 'no backstop refusal on a started-step row', soql: refusals, expected: 0, compare: 'equals'}
	];
}

/**
 * @description The two claims for rows the watchdog must end Failed at a started step: every row reads Failed with an
 * end time, the Stalled category and the started-step reason, and every row has one ERROR entry.
 *
 * @param {string[]} rowIds The rows.
 * @param {{ended: string, entries: string, reasonStart: string}} names The two claims' names and how the reason begins.
 * @param {Function} field The org's field namer.
 * @param {string} entries The log entry object's name.
 * @param {string} chains The chain object's name.
 *
 * @returns {object[]} The claims; none when there are no rows.
 */
function startedStepEndClaims(rowIds, names, field, entries, chains)
{
	if(rowIds.length === 0)
	{
		return [];
	}
	const slice = quoted(rowIds);
	const ended = `SELECT Id, ${field('ErrorMessage__c')} FROM ${chains} WHERE Id IN (${slice}) AND ${field('Status__c')} = 'Failed' AND ${field('CompletedAt__c')} != null `
			+ `AND ${field('FailureCategory__c')} = 'Stalled'`;
	// The reason is long text, which a query cannot filter, so the rows are read and the reason checked here.
	const observeEnded = (salesforce) => salesforce.query(ended).records.filter((row) => String(row[field('ErrorMessage__c')] || '').startsWith(names.reasonStart)).length;
	const errorEntries = `SELECT COUNT() FROM ${entries} WHERE ${field('LogLevel__c')} = 'ERROR' AND ${field('RecordId__c')} IN (${slice}) `
			+ `AND ${field('ShortMessage__c')} LIKE '${STARTED_STEP_ENTRY_START}%'`;
	return [
		{
			name: names.ended, observe: observeEnded, expected: rowIds.length, compare: 'equals',
			note: 'a row still Stalled was not reached in time or was refused; a row re-driven means the watchdog ran a started step again, a finding for the engine'
		},
		{name: names.entries, soql: errorEntries, expected: rowIds.length, compare: 'equals'}
	];
}

/**
 * @description The claim that the watchdog logged no failure while the load ran: no re-drive and no stall write that
 * failed for a row. The schedule's own job row cannot answer this: a recurring schedule keeps one row that stays Queued.
 *
 * @param {object} manifest The manifest.
 * @param {Function} field The org's field namer.
 * @param {string} entries The log entry object's name.
 *
 * @returns {object[]} The claim; none when the run scheduled no watchdog.
 */
function watchdogFailureClaims(manifest, field, entries)
{
	if(!manifest.watchdog?.scheduled)
	{
		return [];
	}
	const starts = WATCHDOG_FAILURE_STARTS.map((start) => `${field('ShortMessage__c')} LIKE '${start}%'`).join(' OR ');
	const failures = `SELECT COUNT() FROM ${entries} WHERE CreatedDate >= ${manifest.startedAt} AND ${field('LogLevel__c')} = 'ERROR' AND (${starts})`;
	return [{name: 'no watchdog failure logged since the load started', soql: failures, expected: 0, compare: 'equals'}];
}

/**
 * @description The claims a manifest makes, each with the query that answers it.
 *
 * @param {object} manifest The manifest.
 * @param {string} fieldPrefix The org's field prefix.
 *
 * @returns {object[]} `[{name, soql, expected, compare, note}]`, or `observed` in place of `soql` for a claim the manifest itself answers.
 */
function buildClaims(manifest, fieldPrefix)
{
	const field = (name) => `${fieldPrefix}${name}`;
	const chains = field('AsyncChainExecution__c');
	const entries = field('LogEntry__c');
	const claims = [];
	const count = (name, where, expected, compare = 'equals', note, aggregate) => claims.push({
		name, soql: `SELECT COUNT() FROM ${chains} WHERE ${where}`, expected, compare, note, aggregate
	});
	for(const action of manifest.actions)
	{
		claims.push(...actionClaims(action, manifest.operatorWave, field, count, entries));
	}
	claims.push(...waveClaims(manifest, field, count, entries, chains));
	// The synthesized rows are Stalled, have no end time and no recorded job id (synthesize-stalled.apex sets neither),
	// and are dated well past the watchdog's threshold. So the watchdog reads each one as a candidate, but with no job id
	// it cannot tell whether the run is dead: it can only mark the row Stalled again and log a WARN. It never runs a row
	// again and never ends one Failed, because both of those need a job id it can prove dead. The rows stay Stalled.
	const stalledRows = manifest.synthesized.stalledRows;
	if(stalledRows.length > 0)
	{
		count(`synthesized Stalled rows number ${stalledRows.length}`, `Id IN (${quoted(stalledRows)}) AND ${field('Status__c')} = 'Stalled'`, stalledRows.length,
			'equals', STALLED_FIXTURE_NOTE);
	}
	claims.push(...startedStepClaims(manifest, field, entries, chains));
	claims.push(...watchdogFailureClaims(manifest, field, entries));
	claims.push({name: 'drain rate is known', expected: 1, compare: 'atLeast', observed: manifest.drainRate && manifest.drainRate.jobsPerMinute > 0 ? 1 : 0});
	claims.push(...refusalClaims(manifest, field, entries, fieldPrefix));
	return claims;
}

/**
 * @description A claim judged against what was observed.
 *
 * @param {object} claim The claim.
 * @param {number} observed The count read.
 *
 * @returns {{name: string, pass: boolean, expected: number, observed: number, note: (string|undefined)}}
 */
function evaluateClaim(claim, observed)
{
	const comparisons = {atLeast: observed >= claim.expected, atMost: observed <= claim.expected, equals: observed === claim.expected};
	const pass = comparisons[claim.compare] ?? comparisons.equals;
	return {name: claim.name, pass, expected: claim.expected, observed, note: !pass && claim.note ? claim.note : undefined};
}

/**
 * @description What each class of evidence in the load consists of (I11), for the verify output and the result file.
 *
 * @param {object} manifest The manifest.
 *
 * @returns {{engine: string, operator: string, clone: string, fixture: string}}
 */
function evidenceClasses(manifest)
{
	// The reconciliation action holds every root under one id; only the roots the engine ran are engine evidence.
	const engineShare = (action) => (action.engineRoots && action.roots ? Math.round(action.expected.runs * action.engineRoots / action.roots) : action.expected.runs);
	const engineRuns = manifest.actions.filter((action) => !action.synthesized).reduce((sum, action) => sum + engineShare(action), 0);
	const wave = manifest.operatorWave;
	const stalls = wave.stallProbes.length > 0 ? `, ${wave.stallProbes.length} genuine Stalled rows` : ', no genuine Stalled row (the probe found no in-engine cause)';
	const killSwitchAborts = wave.killSwitch ? wave.killSwitch.launched : 0;
	const redrivable = wave.deadJobStalls.filter((stall) => stall.idempotent === true).length;
	const startedRows = (manifest.synthesized.startedStepRows || []).length;
	// The driver lays the started-step rows; what the watchdog does to them is what the claims check.
	const startedStep = startedRows > 0 ? `; ${startedRows} synthesized started-step Stalled rows, which the watchdog must end Failed` : '';
	return {
		engine: `${engineRuns} runs the engine wrote${stalls}`,
		operator: `${wave.retries.length} retries, ${wave.restarts.length} restarts, ${wave.aborts.length} aborts, ${killSwitchAborts} kill-switch aborts, `
				+ `${redrivable} dead-job re-drives by the watchdog, ${wave.deadJobStalls.length - redrivable} dead-job runs the watchdog ended Failed at the started step`,
		clone: `${manifest.synthesized.chainRows} rows re-keyed from engine-written rows (staged mode only)`,
		fixture: `${manifest.synthesized.stalledRows.length} synthesized Stalled rows, a screen fixture${startedStep}`
	};
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
 * @description How long verify waits for the watchdog: three sweep cadences for the dead-job re-drives, and one more
 * sweep interval for every twenty-five started-step rows, because a sweep looks at fifty rows at most.
 *
 * @param {object} manifest The manifest.
 *
 * @returns {number} Milliseconds.
 */
function watchdogWaitMilliseconds(manifest)
{
	const startedRows = (manifest.synthesized.startedStepRows || []).length;
	return REDRIVE_WAIT_MILLISECONDS + Math.ceil(startedRows / STARTED_ROWS_PER_SWEEP_FLOOR) * SWEEP_INTERVAL_MILLISECONDS;
}

/**
 * @description Holds until every claim on the watchdog's work passes, or the wait is over.
 *
 * @param {object[]} claims The dead-job and started-step claims.
 * @param {Function} readClaim Reads a claim's observed count.
 * @param {object} context The stage context.
 */
async function waitForRedrives(claims, readClaim, context)
{
	const sleep = context.sleep || defaultSleep;
	const now = context.now || Date.now;
	const deadline = now() + watchdogWaitMilliseconds(context.manifest);
	while(claims.length > 0 && now() < deadline && !claims.every((claim) => evaluateClaim(claim, readClaim(claim)).pass))
	{
		context.log('verify: waiting for the watchdog to re-drive the dead-job stalls and end the started-step rows');
		await sleep(REDRIVE_POLL_MILLISECONDS);
	}
}

/**
 * @description The budgets one log entry's limits text records, by the name UTIL_Limits gives each.
 *
 * @param {string} limitsText The entry's limits, one `<name>: <used> of <maximum>` line each.
 *
 * @returns {Map<string, {used: number, maximum: number}>}
 */
function parseBudgets(limitsText)
{
	const budgets = new Map();
	for(const line of String(limitsText || '').split('\n'))
	{
		const match = line.trim().match(BUDGET_LINE);
		if(match)
		{
			budgets.set(match[1], {used: Number(match[2]), maximum: Number(match[3])});
		}
	}
	return budgets;
}

/**
 * @description What the watchdog's sweeps cost while they ended the started-step rows. Every row ended gets one ERROR
 * entry, written in the sweep's own transaction, so the entries grouped by transaction give the rows each sweep ended,
 * and the busiest sweep's entries record how much of its query, DML and CPU budgets it had used. No wall time is read:
 * the sweep logs no timing of its own, and a recurring schedule keeps one job row that never completes.
 *
 * @param {object} salesforce The org door.
 * @param {object} manifest The manifest.
 *
 * @returns {{sweeps: number, rowsPerSweep: number, budgets: Map}|null} Null when no
 * started-step rows were laid or none has an entry yet.
 */
function readSweepMeasures(salesforce, manifest)
{
	const startedRows = manifest.synthesized.startedStepRows || [];
	if(startedRows.length === 0)
	{
		return null;
	}
	const field = (name) => `${manifest.org.namespacePrefix}${name}`;
	const entries = salesforce.query(`SELECT ${field('TransactionId__c')}, ${field('Limits__c')} FROM ${field('LogEntry__c')} WHERE ${field('LogLevel__c')} = 'ERROR' `
			+ `AND ${field('RecordId__c')} IN (${quoted(startedRows)}) AND ${field('ShortMessage__c')} LIKE '${STARTED_STEP_ENTRY_START}%'`).records;
	if(entries.length === 0)
	{
		return null;
	}
	const bySweep = new Map();
	for(const entry of entries)
	{
		const transaction = entry[field('TransactionId__c')];
		bySweep.set(transaction, [...(bySweep.get(transaction) || []), entry]);
	}
	const busiest = [...bySweep.values()].reduce((largest, sweep) => (sweep.length > largest.length ? sweep : largest));
	const budgets = new Map();
	for(const entry of busiest)
	{
		for(const [name, budget] of parseBudgets(entry[field('Limits__c')]))
		{
			if(SWEEP_BUDGETS.includes(name) && (!budgets.has(name) || budget.used > budgets.get(name).used))
			{
				budgets.set(name, budget);
			}
		}
	}
	return {sweeps: bySweep.size, rowsPerSweep: busiest.length, budgets};
}

/**
 * @description The verify line for the sweeps that ended the started-step rows.
 *
 * @param {object} sweeps What readSweepMeasures read.
 *
 * @returns {string}
 */
function describeSweeps(sweeps)
{
	const budgets = SWEEP_BUDGETS.filter((name) => sweeps.budgets.has(name)).map((name) => `${name} ${sweeps.budgets.get(name).used} of ${sweeps.budgets.get(name).maximum}`);
	return `verify: the watchdog ended the started-step rows in ${sweeps.sweeps} sweeps, at most ${sweeps.rowsPerSweep} in one; that sweep used at most ${budgets.join(', ')}`;
}

/**
 * @description The verify stage: every claim read and judged, one line each, the evidence classes and the PERF_ROW.
 *
 * @param {object} context `{manifest, salesforce, log, sleep, now}`.
 *
 * @returns {Promise<object>} The manifest with the stage recorded.
 */
async function run(context)
{
	const {manifest, salesforce, log} = context;
	const claims = buildClaims(manifest, manifest.org.namespacePrefix);
	const readClaim = (claim, aggregates) =>
	{
		const fromAggregates = aggregates ? observeFromAggregates(claim, aggregates) : null;
		if(fromAggregates !== null)
		{
			return fromAggregates;
		}
		if(claim.observe)
		{
			return claim.observe(salesforce);
		}
		return claim.observed === undefined ? salesforce.query(claim.soql).totalSize : claim.observed;
	};
	const watchdogClaims = claims.filter((claim) => claim.name.startsWith('dead-job run') || claim.name.startsWith('started-step rows'));
	await waitForRedrives(watchdogClaims, readClaim, context);
	// The per-action counts come from three grouped reads taken once the re-drives are in, so verify at volume stays quick.
	const aggregates = readAggregates(salesforce, manifest.org.namespacePrefix, manifest);
	const results = claims.map((claim) => evaluateClaim(claim, readClaim(claim, aggregates)));
	for(const result of results)
	{
		const note = result.note ? ` (${result.note})` : '';
		log(result.pass ? `PASS: ${result.name} (${result.observed})` : `FAIL: ${result.name} expected ${result.expected}, observed ${result.observed}${note}`);
	}
	const failed = results.filter((result) => !result.pass).length;
	const runs = manifest.actions.reduce((sum, action) => sum + action.expected.runs, 0);
	const evidence = evidenceClasses(manifest);
	for(const [evidenceClass, description] of Object.entries(evidence))
	{
		log(`EVIDENCE: ${evidenceClass}: ${description}`);
	}
	const observedFor = (name) => results.find((result) => result.name === name).observed;
	const counts = {backstopRefusals: observedFor(BACKSTOP_CLAIM), lockRefusals: observedFor(LOCK_CLAIM)};
	const sweeps = readSweepMeasures(salesforce, manifest);
	if(sweeps)
	{
		log(describeSweeps(sweeps));
	}
	const pressure = manifest.pressure || {peakActive: null, peakHolding: null, samplesAboveFifty: null};
	const measures = {
		runs,
		jobsPerMinute: manifest.drainRate ? manifest.drainRate.jobsPerMinute : null,
		peakActive: pressure.peakActive,
		peakHolding: pressure.peakHolding,
		samplesAboveFifty: pressure.samplesAboveFifty,
		watchdogRowsPerSweep: sweeps ? sweeps.rowsPerSweep : null,
		backstopRefusals: counts.backstopRefusals,
		lockRefusals: counts.lockRefusals
	};
	for(const metric of PERFORMANCE_MEASURES)
	{
		const value = measures[metric];
		if(value == null)
		{
			continue;
		}
		log(`PERF_ROW: ${JSON.stringify({section: RUNBOOK_SECTION, metric, value, mode: manifest.mode, name: 'consoles-at-volume'})}`);
	}
	log(`verify: ${counts.backstopRefusals} backstop refusals, ${counts.lockRefusals} lock refusals`);
	log(`verify: ${results.length - failed} passed, ${failed} failed`);
	const sweepRecord = sweeps && {...sweeps, budgets: Object.fromEntries(sweeps.budgets)};
	return recordStage(manifest, 'verify', {ok: true, passed: results.length - failed, failed, claims: results, evidence, counts, sweeps: sweepRecord});
}

module.exports = {buildClaims, evaluateClaim, evidenceClasses, readAggregates, observeFromAggregates, run};
