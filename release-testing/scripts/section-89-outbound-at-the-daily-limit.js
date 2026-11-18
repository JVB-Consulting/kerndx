#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
// Runbook section 89: Kern's outbound send at Salesforce's daily limit of background Apex jobs, and the outbound retry
// watchdog, proved on an installed package. One command, about 35 minutes, up to about 100 minutes if every wait runs
// to its limit. It lowers an org-wide limit, so it is never part of the release runner. The org comes from
// SF_SUBSCRIBER_ORG_ALIAS; the namespace is read from the org. It prints a line for each step as it goes, so a long
// quiet stretch is a wait, not a hang.
//   SF_SUBSCRIBER_ORG_ALIAS=<your org alias> node release-testing/scripts/section-89-outbound-at-the-daily-limit.js
//   SF_SUBSCRIBER_ORG_ALIAS=<your org alias> node release-testing/scripts/section-89-outbound-at-the-daily-limit.js --dry-run
//   SF_SUBSCRIBER_ORG_ALIAS=<your org alias> node release-testing/scripts/section-89-outbound-at-the-daily-limit.js --restore-only
'use strict';
const fs = require('fs');
const path = require('path');
const {getSubscriberOrgAlias} = require('../runner/subscriber-config');
const {createOrg} = require('./section-89/org');
const {createClock} = require('./section-89/poll');
const {runSection, runRestoreOnly} = require('./section-89/run');

const RUN_FOLDER = path.resolve(__dirname, '..', '..', 'tmp', 'section-89');
const EXIT_CODES = {PASS: 0, FAIL: 1, BLOCKED: 3};
const USAGE_EXIT_CODE = 2;
const USAGE = [
	'Usage: node release-testing/scripts/section-89-outbound-at-the-daily-limit.js [--dry-run | --restore-only]',
	'  The org is SF_SUBSCRIBER_ORG_ALIAS. Exit code 0 is PASS, 1 is FAIL, 3 is BLOCKED (another outbound call was waiting).',
	'  --dry-run       For an org whose limit cannot be lowered: the guard, the state gate, every script compiled and stopped',
	'                  before it runs, and the watchdog schedule made and stopped at once. Nothing else on the org changes.',
	'  --restore-only  Only puts the org back (step 89h), after a run that was stopped or killed: every waiting job of',
	'                  Kern\'s UTIL_AdaptiveAsynchronousProcessor (so nothing else of that class may run), the allowance (a',
	'                  blank override, read back), the probe schedules, rows and classes, the circuit breaker and the',
	'                  section 84 log entries. It needs nothing from the earlier run. Exit code 0 only on PASS.'
].join('\n');

/**
 * @description Reads the command line.
 *
 * @param {string[]} commandArguments The arguments after the script.
 *
 * @returns {{dryRun: boolean, restoreOnly: boolean, help: boolean}}
 */
function parseCommandLine(commandArguments)
{
	const options = {dryRun: false, restoreOnly: false, help: false};
	for(const argument of commandArguments)
	{
		if(argument === '--dry-run')
		{
			options.dryRun = true;
		}
		else if(argument === '--restore-only')
		{
			options.restoreOnly = true;
		}
		else if(argument === '--help' || argument === '-h')
		{
			options.help = true;
		}
		else
		{
			throw new Error(`Unknown argument ${argument}\n${USAGE}`);
		}
	}
	if(options.dryRun && options.restoreOnly)
	{
		throw new Error(`--dry-run and --restore-only cannot run together\n${USAGE}`);
	}
	return options;
}

/**
 * @description The run's folder name: the time it started, safe as a file name.
 *
 * @param {Date} now The time.
 *
 * @returns {string}
 */
function runStamp(now)
{
	return now.toISOString().replace(/[:.]/g, '-');
}

/**
 * @description The exit code a result earns.
 *
 * @param {string} result PASS, FAIL or BLOCKED.
 *
 * @returns {number}
 */
function exitCodeFor(result)
{
	return EXIT_CODES[result] ?? EXIT_CODES.FAIL;
}

/**
 * @description The Ctrl-C handler. It always records that a Ctrl-C was seen (`ctrlCSeen`, never cleared), so a command
 * that a Ctrl-C stopped on Windows counts as interrupted, also during the clean-up. Before the clean-up it stops the
 * run; during the clean-up it only says the clean-up will finish.
 *
 * @param {object} signal The run's `{interrupted, cleaningUp, ctrlCSeen}`.
 * @param {Function} print Prints one line.
 *
 * @returns {Function}
 */
function createInterruptHandler(signal, print)
{
	return () =>
	{
		signal.ctrlCSeen = true;
		if(signal.cleaningUp)
		{
			print('SECTION89 the clean-up is running and will finish; wait for the RESULT line');
		}
		else
		{
			signal.interrupted = true;
			print('SECTION89 interrupted: the current step stops and the clean-up runs next');
		}
	};
}

/**
 * @description The name of the mode the command line asked for.
 *
 * @param {{dryRun: boolean, restoreOnly: boolean}} options The command line, as parseCommandLine read it.
 *
 * @returns {string} restore-only, dry-run or full.
 */
function describeMode(options)
{
	let mode = 'full';
	if(options.restoreOnly)
	{
		mode = 'restore-only';
	}
	else if(options.dryRun)
	{
		mode = 'dry-run';
	}
	return mode;
}

/**
 * @description Runs the section against the org and exits with its result's code.
 */
async function main()
{
	let options;
	try
	{
		options = parseCommandLine(process.argv.slice(2));
	}
	catch(failure)
	{
		console.error(failure.message);
		process.exit(USAGE_EXIT_CODE);
	}
	if(options.help)
	{
		console.log(USAGE);
		process.exit(0);
	}
	const runDirectory = path.join(RUN_FOLDER, runStamp(new Date()));
	fs.mkdirSync(runDirectory, {recursive: true});
	const signal = {interrupted: false, cleaningUp: false, ctrlCSeen: false};
	process.on('SIGINT', createInterruptHandler(signal, (line) => console.log(line)));
	const transcript = [];
	const log = (line) =>
	{
		transcript.push(line);
		console.log(line);
	};
	const alias = getSubscriberOrgAlias();
	const mode = describeMode(options);
	log(`SECTION89 START org=${alias} mode=${mode} answers=${runDirectory}`);
	const context = {org: createOrg({alias, runDirectory}), clock: createClock(signal), log, dryRun: options.dryRun, signal};
	const result = options.restoreOnly ? await runRestoreOnly(context) : await runSection(context);
	log(`SECTION89 RESULT ${result}`);
	fs.writeFileSync(path.join(runDirectory, 'summary.json'), JSON.stringify({alias, mode, result, steps: context.steps}, null, '\t'));
	fs.writeFileSync(path.join(runDirectory, 'transcript.txt'), `${transcript.join('\n')}\n`);
	process.exit(exitCodeFor(result));
}

if(require.main === module)
{
	main().catch((failure) =>
	{
		console.error('SECTION89 RESULT FAIL the driver stopped:', failure);
		process.exit(EXIT_CODES.FAIL);
	});
}

module.exports = {parseCommandLine, runStamp, exitCodeFor, createInterruptHandler, EXIT_CODES, USAGE};
