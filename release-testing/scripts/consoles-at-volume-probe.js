#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
// The consoles-at-volume probe (PLAN-175 Task 1): one root fanned out three deep on the harness org, sampled every
// fifteen seconds; a one-off watchdog sweep with a two-minute threshold at the widest point; a chain whose first
// step spends the transaction's enqueue. Prints and writes tmp/consoles-at-volume/probe-report.md, and the record
// the shape table reads, release-testing/scripts/consoles-at-volume/probe-report.json.
//
//   SF_SUBSCRIBER_ORG_ALIAS=<your org alias> node release-testing/scripts/consoles-at-volume-probe.js [--target-depth 3] [--busy-milliseconds 1500] [--minutes 30]
//   SF_SUBSCRIBER_ORG_ALIAS=<your org alias> node release-testing/scripts/consoles-at-volume-probe.js --cleanup   (removes the probe's rows and jobs)
'use strict';
const fs = require('fs');
const path = require('path');
const {getSubscriberOrgAlias} = require('../runner/subscriber-config');
const {namespacePrefix, fillNamespaceTokens} = require('../e2e/helpers/sf-namespace');
const {deployStrippedSubscriberClasses} = require('../e2e/helpers/subscriber-deploy');
const {createOrgDoor} = require('./consoles-at-volume/org-door');
const {drainQueue, jobsPerMinute, peakDepth, DRAIN_THRESHOLDS} = require('./consoles-at-volume/drain');
const {renderTemplate} = require('./consoles-at-volume/apex-templates');

const OUTPUT_DIRECTORY = path.join(__dirname, '..', '..', 'tmp', 'consoles-at-volume');
const REPORT_PATH = path.join(OUTPUT_DIRECTORY, 'probe-report.md');
const JSON_REPORT_PATH = path.join(__dirname, 'consoles-at-volume', 'probe-report.json');
// The id alphabet: hexadecimal letters only (SubscriberChainSteps.VOLUME_ID_ALPHABET), eight of them per token.
const RUN_TOKEN_ALPHABET = 'abcdef';
const RUN_TOKEN_LENGTH = 8;
const STALL_SETTLE_MILLISECONDS = 180_000;
const SWEEP_SETTLE_MILLISECONDS = 120_000;
const WATCHDOG_JOB_NAME = 'Consoles At Volume Probe Watchdog';
const WATCHDOG_THRESHOLD_MINUTES = 2;
// The fan-out's pending hops wait as Queued (Holding is where delayed jobs wait), so the widest point is read from the active count.
const SWEEP_AT_ACTIVE = 40;
const EXPECTED_RUNS = 156;
const EXPECTED_LEAVES = 125;
const ONE_TRANSACTION_HOLDING_CEILING = 100;
const REDRIVE_MESSAGE_PREFIX = 'Chain re-driven by watchdog';
const ERROR_TEXT_PREVIEW_LENGTH = 160;
const MINUTE_MILLISECONDS = 60_000;
const DEPTH_TWO_CHAIN_NAME = 'Volume_LedgerReconcile';
const LEAF_CHAIN_NAME = 'Volume_AccountReconcile';

/**
 * @description Reads a numeric command-line option.
 *
 * @param {string} name The option name without its dashes.
 * @param {number} fallback The value when the option is absent.
 *
 * @returns {number}
 */
function readNumber(name, fallback)
{
	const index = process.argv.indexOf(`--${name}`);
	return index < 0 ? fallback : Number(process.argv[index + 1]);
}

/**
 * @description A random token spelled in the id alphabet.
 *
 * @param {number} length How many letters.
 *
 * @returns {string}
 */
function lettersOnlyToken(length)
{
	let token = '';
	for(let index = 0; index < length; index++)
	{
		token += RUN_TOKEN_ALPHABET[Math.floor(Math.random() * RUN_TOKEN_ALPHABET.length)];
	}
	return token;
}

/**
 * @description A template with its values filled and its namespace tokens filled for the org.
 *
 * @param {string} name The template file name.
 * @param {object} values Token to value.
 *
 * @returns {string}
 */
function template(name, values)
{
	return fillNamespaceTokens(renderTemplate(name, values), namespacePrefix());
}

/**
 * @description Removes the probe's rows, jobs and log entries from the org, through the same template door.
 *
 * @param {object} org The org door.
 */
function cleanUp(org)
{
	const result = org.salesforce.runApex(template('probe-cleanup.apex', {}), 'probe-cleanup');
	console.log(`cleanup: ${result.debugLines.join(' ')}`);
}

/**
 * @description The value after `key=` in the first debug line that carries it.
 *
 * @param {string[]} debugLines The script's debug lines.
 * @param {string} key The key.
 *
 * @returns {string|null}
 */
function debugValue(debugLines, key)
{
	const line = debugLines.find((candidate) => candidate.includes(`${key}=`)) || '';
	const match = line.match(new RegExp(`${key}=([^ ]+)`));
	return match ? match[1] : null;
}

/**
 * @description Waits for a number of milliseconds.
 *
 * @param {number} milliseconds How long.
 *
 * @returns {Promise<void>}
 */
function sleep(milliseconds)
{
	return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

/**
 * @description The org door plus the namespace-aware names the probe queries with.
 *
 * @returns {object} `{alias, salesforce, prefix, field, chainObject, logObject}`.
 */
function openOrg()
{
	const alias = getSubscriberOrgAlias();
	const prefix = namespacePrefix();
	const field = (name) => `${prefix}${name}`;
	return {alias, salesforce: createOrgDoor({alias}), prefix, field, chainObject: field('AsyncChainExecution__c'), logObject: field('LogEntry__c')};
}

/**
 * @description Launches one root fanned out to the target depth under a fresh token-keyed action.
 *
 * @param {object} org The org door.
 * @param {object} options The probe's options.
 * @param {Function} say The report line writer.
 *
 * @returns {object} `{runToken, actionId, rootId, startedAt, sinceIso}`.
 */
function launchRoot(org, options, say)
{
	const runToken = lettersOnlyToken(RUN_TOKEN_LENGTH);
	const startedAt = new Date();
	const values = {__RUN_TOKEN__: runToken, __TARGET_DEPTH__: options.targetDepth, __BUSY_MILLISECONDS__: options.busyMilliseconds};
	const launch = org.salesforce.runApex(template('probe-fan-out.apex', values), 'probe-fan-out');
	const actionId = debugValue(launch.debugLines, 'action');
	const rootId = debugValue(launch.debugLines, 'root');
	say(`- launched one root: action ${actionId}, root ${rootId}, ${launch.debugLines.find((line) => line.startsWith('VOLUME_PROBE'))}`);
	return {runToken, actionId, rootId, startedAt, sinceIso: startedAt.toISOString()};
}

/**
 * @description Drains the root's run, scheduling one watchdog sweep at the fan-out's widest point (or after the
 * drain when the queue never gets that wide). A quiet queue alone is not a settled run: right after the launch the
 * root's first hop is the only job, so the drain is also held until no run under the action is still Running.
 *
 * @param {object} org The org door.
 * @param {object} run The launched root.
 * @param {object} options The probe's options.
 * @param {Function} say The report line writer.
 *
 * @returns {Promise<{drained: boolean, timedOut: boolean, samples: object[]}>}
 */
async function drainAndSweep(org, run, options, say)
{
	let sweepScheduled = false;
	const scheduleSweep = (why) =>
	{
		sweepScheduled = true;
		const values = {__THRESHOLD_MINUTES__: WATCHDOG_THRESHOLD_MINUTES, __JOB_NAME__: WATCHDOG_JOB_NAME};
		const sweep = org.salesforce.runApex(template('schedule-watchdog-once.apex', values), 'probe-watchdog');
		say(`  ${why}: ${sweep.debugLines.join(' ')}`);
	};
	const runningQuery = `SELECT COUNT() FROM ${org.chainObject} WHERE ${org.field('RootCorrelationId__c')} = '${run.actionId}' AND ${org.field('Status__c')} = 'Running'`;
	const runningUnderAction = () => org.salesforce.query(runningQuery).totalSize;
	const onSample = (sample) =>
	{
		say(`  ${new Date(sample.at).toISOString()} active=${sample.active} holding=${sample.holding} completed=${sample.completed}`);
		if(!sweepScheduled && sample.active >= SWEEP_AT_ACTIVE)
		{
			scheduleSweep('scheduled the watchdog sweep at the widest point');
		}
	};
	const thresholds = {...DRAIN_THRESHOLDS, timeoutSeconds: options.minutes * 60};
	const drain = await drainQueue({salesforce: org.salesforce, sinceIso: run.sinceIso, thresholds, until: () => runningUnderAction() === 0, onSample});
	if(!sweepScheduled)
	{
		scheduleSweep(`the queue never reached ${SWEEP_AT_ACTIVE} active jobs; scheduled the sweep after the drain instead`);
		await sleep(SWEEP_SETTLE_MILLISECONDS);
	}
	return drain;
}

/**
 * @description Reads what the engine wrote under the action once the run has drained.
 *
 * @param {object} org The org door.
 * @param {object} run The launched root.
 * @param {Function} say The report line writer.
 *
 * @returns {object} The counts the verdict is judged on.
 */
function measureTree(org, run, say)
{
	const {salesforce, chainObject, field} = org;
	const underAction = `FROM ${chainObject} WHERE ${field('RootCorrelationId__c')} = '${run.actionId}'`;
	const byStatus = salesforce.query(`SELECT ${field('Status__c')} status, COUNT(Id) runs ${underAction} GROUP BY ${field('Status__c')}`).records;
	const byName = salesforce.query(`SELECT ${field('ChainName__c')} name, COUNT(Id) runs ${underAction} GROUP BY ${field('ChainName__c')}`).records;
	const total = byStatus.reduce((sum, row) => sum + Number(row.runs), 0);
	const depthTwoIds = salesforce.query(`SELECT ${field('CorrelationId__c')} ${underAction} AND ${field('ChainName__c')} = '${DEPTH_TWO_CHAIN_NAME}'`).records
	.map((row) => `'${row[field('CorrelationId__c')]}'`);
	const leavesQuery = `SELECT COUNT() FROM ${chainObject} WHERE ${field('ChainName__c')} = '${LEAF_CHAIN_NAME}' `
			+ `AND ${field('LaunchCorrelationId__c')} IN (${depthTwoIds.join(',')})`;
	const leavesUnderDepthTwo = depthTwoIds.length === 0 ? 0 : salesforce.query(leavesQuery).totalSize;
	// A Finalizer whose enqueue failed marks the row Stalled (the error text is on a long text area, which SOQL cannot filter).
	const finalizerFailures = salesforce.query(`SELECT COUNT() ${underAction} AND ${field('Status__c')} = 'Stalled'`).totalSize;
	const platformFailures = salesforce.query('SELECT COUNT() FROM AsyncApexJob WHERE JobType = \'Queueable\' AND ApexClass.Name = \'UTIL_AsyncChain\' '
			+ `AND Status IN ('Failed', 'Aborted') AND CreatedDate >= ${run.sinceIso}`).totalSize;
	const redrivesQuery = `SELECT COUNT() FROM ${org.logObject} WHERE ${field('ShortMessage__c')} LIKE '${REDRIVE_MESSAGE_PREFIX}%' AND CreatedDate >= ${run.sinceIso}`;
	const watchdogRedrives = salesforce.query(redrivesQuery).totalSize;
	const statuses = byStatus.map((row) => `${row.status}=${row.runs}`).join(', ');
	const names = byName.map((row) => `${row.name}=${row.runs}`).join(', ');
	say(`- runs under the action: ${total} (expected ${EXPECTED_RUNS}); by status ${statuses}; by name ${names}`);
	say(`- leaves launched under a depth-2 run: ${leavesUnderDepthTwo} (expected ${EXPECTED_LEAVES}); Finalizer enqueue failures (rows Stalled): ${finalizerFailures}; `
			+ `failed or aborted engine jobs: ${platformFailures}`);
	say(`- watchdog re-drives logged after the ${WATCHDOG_THRESHOLD_MINUTES}-minute sweep: ${watchdogRedrives} (a healthy chain re-driven is a finding for Task 13)`);
	return {total, byStatus, leavesUnderDepthTwo, finalizerFailures, platformFailures, watchdogRedrives};
}

/**
 * @description Launches the chain whose first step spends the transaction's enqueue and reads how the engine left it.
 *
 * @param {object} org The org door.
 * @param {Function} say The report line writer.
 *
 * @returns {Promise<{status: string, strategy: string}>}
 */
async function probeStall(org, say)
{
	const {salesforce, chainObject, field} = org;
	const stallId = debugValue(salesforce.runApex(template('probe-stalled.apex', {}), 'probe-stalled').debugLines, 'stall');
	await sleep(STALL_SETTLE_MILLISECONDS);
	const fields = [
		'Status__c',
		'FailureCategory__c',
		'ErrorMessage__c',
		'CurrentJobId__c'
	].map(field).join(', ');
	const row = salesforce.query(`SELECT ${fields} FROM ${chainObject} WHERE Id = '${stallId}'`).records[0];
	const jobId = row[field('CurrentJobId__c')];
	const job = jobId ? salesforce.query(`SELECT Status, ExtendedStatus FROM AsyncApexJob WHERE Id = '${jobId}'`).records[0] : null;
	const status = row[field('Status__c')];
	const strategy = status === 'Stalled' ? 'engine' : 'synthesized';
	const error = String(row[field('ErrorMessage__c')] || '').slice(0, ERROR_TEXT_PREVIEW_LENGTH);
	const jobText = job ? `${job.Status} ${job.ExtendedStatus || ''}` : 'none';
	say(`- stall probe ${stallId}: status ${status}, category ${row[field('FailureCategory__c')]}, error "${error}", job ${jobText}`);
	say(`- stall strategy for shapes.js: ${strategy}`);
	return {status, strategy};
}

/**
 * @description D1's criteria, each named, so the report says which one a run missed.
 *
 * @param {object} tree The measured counts.
 * @param {object} drain The drain's result.
 * @param {{active: number, holding: number}} peak The peak queue depths.
 *
 * @returns {Array<{name: string, pass: boolean}>}
 */
function judge(tree, drain, peak)
{
	return [
		{name: `${EXPECTED_RUNS} runs under the action`, pass: tree.total === EXPECTED_RUNS},
		{name: `${EXPECTED_LEAVES} leaves under a depth-2 run`, pass: tree.leavesUnderDepthTwo === EXPECTED_LEAVES},
		{name: 'no Finalizer enqueue failure', pass: tree.finalizerFailures === 0},
		{name: 'drained inside the box', pass: drain.drained},
		{name: `peak Holding under ${ONE_TRANSACTION_HOLDING_CEILING}`, pass: peak.holding < ONE_TRANSACTION_HOLDING_CEILING},
		{
			name: 'every run Completed or Failed',
			pass: tree.byStatus.every((row) => [
				'Completed',
				'Failed'
			].includes(row.status))
		}
	];
}

/**
 * @description Writes the markdown report and the JSON record the shape table reads.
 *
 * @param {object} record What the JSON record carries.
 * @param {string[]} lines The report lines.
 */
function writeReports(record, lines)
{
	fs.writeFileSync(REPORT_PATH, `${lines.join('\n')}\n`, 'utf8');
	// The record the shape table reads (shapes.js readProbeReport): committed with Task 1, never guessed.
	fs.writeFileSync(JSON_REPORT_PATH, `${JSON.stringify(record, null, '\t')}\n`, 'utf8');
	console.log(`report: ${REPORT_PATH} and ${JSON_REPORT_PATH}`);
}

/**
 * @description Runs the probe and writes its two reports.
 */
async function main()
{
	const options = {targetDepth: readNumber('target-depth', 3), busyMilliseconds: readNumber('busy-milliseconds', 1500), minutes: readNumber('minutes', 30)};
	const org = openOrg();
	if(process.argv.includes('--cleanup'))
	{
		cleanUp(org);
		return;
	}
	fs.mkdirSync(OUTPUT_DIRECTORY, {recursive: true});
	const lines = [];
	const say = (line) =>
	{
		console.log(line);
		lines.push(line);
	};
	say(`# Consoles-at-volume probe, ${new Date().toISOString()}, org ${org.alias}, namespace [${org.prefix}]`);
	say(`- options: target depth ${options.targetDepth}, busy milliseconds ${options.busyMilliseconds}, drain box ${options.minutes} minutes`);
	if(!org.prefix)
	{
		deployStrippedSubscriberClasses([
			'SubscriberChainSteps',
			'SubscriberChainSteps_TEST'
		]);
		say('- deployed the stripped step classes');
	}

	const run = launchRoot(org, options, say);
	const drain = await drainAndSweep(org, run, options, say);
	const peak = peakDepth(drain.samples);
	const rate = jobsPerMinute(drain.samples);
	say(`- drain: ${drain.drained ? 'drained' : 'TIMED OUT'} after ${drain.samples.length} samples; peak active ${peak.active}, peak holding ${peak.holding}; `
			+ `jobs per minute ${rate}`);
	const tree = measureTree(org, run, say);
	const stall = await probeStall(org, say);

	const checks = judge(tree, drain, peak);
	const verdict = checks.every((check) => check.pass) ? 'FITS' : 'DOES NOT FIT';
	const missed = checks.filter((check) => !check.pass).map((check) => check.name);
	say(`- verdict: ${verdict} (D1 criteria; 140 Completed and 16 Failed expected)${missed.length ? `; missed: ${missed.join('; ')}` : ''}`);
	const rootWallClockMinutes = Number(((drain.samples[drain.samples.length - 1].at - drain.samples[0].at) / MINUTE_MILLISECONDS).toFixed(1));
	writeReports({
		measuredAt: run.sinceIso,
		org: org.alias,
		verdict,
		jobsPerMinute: rate,
		peakActive: peak.active,
		peakHolding: peak.holding,
		rootWallClockMinutes,
		watchdogRedrives: tree.watchdogRedrives,
		stallStrategy: stall.strategy,
		fitsInOneTransaction: peak.holding < ONE_TRANSACTION_HOLDING_CEILING,
		reportPath: path.relative(process.cwd(), REPORT_PATH)
	}, lines);
	process.exit(verdict === 'FITS' ? 0 : 1);
}

main().catch((failure) =>
{
	console.error('The probe stopped:', failure);
	process.exit(2);
});
