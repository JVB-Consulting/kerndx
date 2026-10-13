// SPDX-License-Identifier: BUSL-1.1
// Adversarial exploration of the two consoles' pinned state and their narrow widths, and their walk at volume.
//
// This is not a fixed journey. It drives the Log Console and the Chain Monitor through sequences a
// written journey would never take — seeded-random orders, hostile orders, a reload between every
// pair of moves, every width the two consoles change their column sets at — and after every step it
// compares what the screen shows with a small model of the rules (the address is the record of the
// pins; an in-place pin pushes a history entry; a clear rewrites in place; a hand-off is applied
// once and then normalised out of the address).
// Nothing is asserted: a disagreement is recorded with its evidence and the session carries on, so
// one wrong screen never hides the next.
//
// Run (the org must be free; the shaped seed is laid down and torn down by this script):
//   SF_SUBSCRIBER_ORG_ALIAS=<your org alias> node explore-consoles.js
//   SF_SUBSCRIBER_ORG_ALIAS=<your org alias> node explore-consoles.js --seed 123456789
// The seed of the random generator is printed first and replayed with --seed, so a run repeats its
// moves exactly. Findings land in tmp/plan166/exploration-findings.md with screenshots beside them
// in tmp/plan166/exploration/; the process exits 1 when there is at least one finding, 0 otherwise.
// With --manifest <path> (the volume driver's manifest) the volume phase walks the load that manifest
// describes instead, with no seed of its own, and writes under tmp/consoles-at-volume/exploration/.
//
// The parts, each a module under explore/:
//   constants.js        the paths, the console's keys and defaults, the widths, the allowances
//   shaped-seed.js      the seed and its teardown, plus the row oracle read from the database
//   model.js            the state model: the history tape, the console's own session state, the expected counts
//   checks.js           the checks run after every step
//   moves.js            the sequences: the moves, the random sessions, the hostile orders, the three probes
//   widths.js           the widths, on both consoles
//   timing.js           every read and every open timed, judged at the 75th percentile
//   manifest-oracle.js  the volume walk's oracle: the manifest says what, the database says how many
//   coverage.js         the volume walk over both consoles
//   report.js           the output: the findings ledger and its table, the output paths
//   command-line.js     the options
// This file is the entry: it reads the options, lays the seed down, opens the browser, assembles the
// context every part reads, runs the phases, tears the seed down and exits with the findings count.
'use strict';

const fs = require('fs');
const path = require('path');
const {chromium} = require('@playwright/test');
const LogConsolePage = require('./pages/log-console.page');
const ChainMonitorPage = require('./pages/chain-monitor.page');
const {namespacePrefix} = require('./helpers/sf-namespace');
const {getInstanceUrl} = require('./helpers/sf-auth');
const {
	AUTH_STATE_PATH, OUTPUT_DIRECTORY, SCREENSHOT_DIRECTORY, FINDINGS_PATH, TIMINGS_PATH, VOLUME_PHASE, WIDTHS, SESSION_VIEWPORT, BROWSER_TIMEZONE,
	MAXIMUM_SCREENSHOTS, MESSAGE_EXCERPT_LENGTH, NOISE_LINES_PRINTED, USAGE_EXIT_CODE, COUNTED_CONTROLLER_METHODS, MONITOR_CONTROLLER_METHODS
} = require('./explore/constants');
const {FIXTURE_IDS, seedFixtures, tearDownFixtures, countSurvivingFixtureRows, readOracle} = require('./explore/shaped-seed');
const {consoleEntry, HistoryTape, freshSession} = require('./explore/model');
const {checkSeedTotals} = require('./explore/checks');
const {createRandom, runRandomSession, runHostileSequences, probeIdenticalRepin, probeBackOntoScopedMonitor, probePreMountReads} = require('./explore/moves');
const {sweepConsoleWidths, sweepMonitorWidths} = require('./explore/widths');
const {createFindingsLedger, outputPaths} = require('./explore/report');
const {parseArguments} = require('./explore/command-line');
const {attachTiming, reportTimingBreaches, writeTimings} = require('./explore/timing');
const {readManifestOracle} = require('./explore/manifest-oracle');
const {walkMonitor, walkConsole, walkDeepLinks, resolveOutputDirectory, readPackageVersion} = require('./explore/coverage');

// The controller methods each read travels under: counted for the probes, timed for the budgets.
const WATCHED_CONTROLLER_METHODS = [...COUNTED_CONTROLLER_METHODS, ...MONITOR_CONTROLLER_METHODS];

/**
 * @description Reads the command line, printing the refusal and the usage line and exiting with the
 *              usage code when it is wrong: told apart from 1 (there were findings) and 0 (there were
 *              none), neither of which is true of a run that never started.
 * @returns {Object} The parsed options.
 */
function readOptions()
{
	try
	{
		return parseArguments(process.argv.slice(2));
	}
	catch(failure)
	{
		console.error(`explore-consoles: ${failure.message}`);
		return process.exit(USAGE_EXIT_CODE);
	}
}

/**
 * @description Where this run writes: the folder the output resolver names (I3: the release results by
 *              version on a release org, the development folder otherwise), or the shaped run's fixed paths.
 * @param {Object} options The parsed options.
 * @returns {Object} The folder, the screenshot folder, the findings path and the timings path.
 */
function resolveOutputs(options)
{
	const directory = resolveOutputDirectory({
		manifest: options.manifest, namespacePrefix: namespacePrefix(), version: readPackageVersion(), outputDirectory: options.outputDirectory
	});
	if(directory === OUTPUT_DIRECTORY)
	{
		return {directory, screenshotDirectory: SCREENSHOT_DIRECTORY, findingsPath: FINDINGS_PATH, timingsPath: TIMINGS_PATH};
	}
	return outputPaths(directory);
}

/**
 * @description One line of an error, for a findings row or the log.
 * @param {Error|string} failure The error.
 * @returns {string} The excerpt.
 */
function excerpt(failure)
{
	return String(failure.message || failure).replace(/\s+/g, ' ').slice(0, MESSAGE_EXCERPT_LENGTH);
}

/**
 * @description Listens to the page: uncaught errors and console errors for the checks, and the controller
 *              methods each Aura request carries for the probes' read counts.
 * @param {Object} context The run context.
 */
function listenToPage(context)
{
	const {page} = context;
	// Both the message and the frames behind it: a platform message on its own ("Invalid or missing
	// callback") names no component, and the stack is what a later reader needs to find the call site.
	page.on('pageerror', (error) => context.pageErrors.push({message: String(error?.message || error), stack: String(error?.stack || '')}));
	page.on('console', (message) =>
	{
		if(message.type() === 'error')
		{
			context.consoleErrors.push(message.text());
		}
	});
	page.on('request', (request) =>
	{
		if(request.method() !== 'POST' || !request.url().includes('/aura'))
		{
			return;
		}
		let body = request.postData() || '';
		try
		{
			body = decodeURIComponent(body);
		}
		catch
		{
			// A body that will not decode is counted as it arrived.
		}
		for(const method of WATCHED_CONTROLLER_METHODS)
		{
			const occurrences = body.split(`"method":"${method}"`).length - 1;
			if(occurrences > 0)
			{
				context.apexCalls.set(method, (context.apexCalls.get(method) || 0) + occurrences);
			}
		}
	});
}

/**
 * @description Opens a page on the stored session and assembles the context every part reads.
 * @param {Object} browser The launched browser.
 * @param {Object} oracles The shaped `oracle` (null without the seed) and the manifest's `load` (null without one).
 * @param {Object} options The parsed options.
 * @param {Object} ledger The findings ledger.
 * @returns {Promise<Object>} The run context.
 */
async function openContext(browser, {oracle, load}, options, ledger)
{
	const contextOptions = {viewport: SESSION_VIEWPORT, timezoneId: BROWSER_TIMEZONE};
	if(fs.existsSync(AUTH_STATE_PATH))
	{
		contextOptions.storageState = AUTH_STATE_PATH;
	}
	const browserContext = await browser.newContext(contextOptions);
	const page = await browserContext.newPage();
	const context = {
		page,
		logConsole: new LogConsolePage(page),
		monitor: new ChainMonitorPage(page),
		oracle,
		load,
		random: createRandom(options.seed),
		tape: new HistoryTape(consoleEntry()),
		session: freshSession(),
		pageErrors: [],
		consoleErrors: [],
		consoleNoise: [],
		apexCalls: new Map(),
		skippedCountChecks: 0,
		ledger,
		options,
		timing: attachTiming(page, WATCHED_CONTROLLER_METHODS)
	};
	listenToPage(context);
	return context;
}

/**
 * @description The fixtures' own totals first: every row count the shaped walk checks reads these rows.
 * @param {Object} context The run context.
 */
async function reportSeedTotals(context)
{
	const seedFindings = checkSeedTotals(context.oracle);
	console.log(`the seed's documented totals: ${seedFindings.length === 0 ? 'all four as documented' : `${seedFindings.length} of four disagree`}`);
	for(const finding of seedFindings)
	{
		await context.ledger.report(context, finding);
	}
}

/**
 * @description Runs the phases the options name, in their fixed order.
 * @param {Object} context The run context.
 * @param {Object} options The parsed options.
 */
async function runPhases(context, options)
{
	if(options.phases.includes('sessions'))
	{
		for(let session = 1; session <= options.sessions; session++)
		{
			await runRandomSession(context, `S${session}`, options.steps);
		}
	}
	if(options.phases.includes('hostile'))
	{
		await runHostileSequences(context);
	}
	if(options.phases.includes('probes'))
	{
		await probeIdenticalRepin(context);
		await probeBackOntoScopedMonitor(context);
		await probePreMountReads(context);
	}
	if(options.phases.includes('widths'))
	{
		await sweepConsoleWidths(context);
		await sweepMonitorWidths(context);
	}
	if(options.phases.includes(VOLUME_PHASE))
	{
		await walkMonitor(context);
		await walkConsole(context);
		await walkDeepLinks(context);
	}
}

/**
 * @description The shaped seed's teardown and the proof that it worked: two separate things, because a
 *              teardown that throws must not take the verification with it, because that is the one reading that
 *              says whether the shared org is clean for the next run.
 * @param {Object} ledger The findings ledger.
 * @param {Object} reportingContext The run context, or a page-less stand-in when the browser never opened.
 */
async function tearDownShapedSeed(ledger, reportingContext)
{
	let teardownFailure = null;
	try
	{
		tearDownFixtures();
	}
	catch(failure)
	{
		teardownFailure = failure;
		console.error(`\nteardown: the teardown script itself failed: ${excerpt(failure)}`);
		await ledger.report(reportingContext, {
			session: 'TEARDOWN', step: 1, move: 'the teardown script', check: 'teardown-failed', expected: 'the teardown script runs', observed: excerpt(failure),
			pins: consoleEntry()
		});
	}
	let surviving = null;
	try
	{
		surviving = countSurvivingFixtureRows();
	}
	catch(failure)
	{
		console.error(`\nteardown: the verification query failed: ${excerpt(failure)}`);
	}
	console.log(`\nteardown: rows still carrying any of the seed's ${FIXTURE_IDS.length} ids = ${surviving === null ? 'unknown' : surviving}`
			+ `${teardownFailure ? ' (after a failed teardown)' : ''}`);
	if(surviving !== 0)
	{
		await ledger.report(reportingContext, {
			session: 'TEARDOWN', step: 2, move: 'the teardown', check: 'seed-left-behind',
			expected: `no row under any of the seed's ${FIXTURE_IDS.length} ids`,
			observed: surviving === null ? 'the verification query could not answer, so the org is unproved' : `${surviving} rows survived`,
			pins: consoleEntry()
		});
	}
}

/**
 * @description The one-line summary of what the run walked and what the checks could not say.
 * @param {Object} options The parsed options.
 * @param {Object|null} context The run context, or null when the browser never opened.
 * @param {Array<Object>} judgements The timing judgements.
 * @returns {string} The summary.
 */
function describeRun(options, context, judgements)
{
	const ran = [
		options.phases.includes('sessions') ? `${options.sessions} random sessions of ${options.steps} steps at ${SESSION_VIEWPORT.width}px` : null,
		options.phases.includes('hostile') ? 'the four hostile orders' : null,
		options.phases.includes('probes') ? 'the three probes' : null,
		options.phases.includes('widths') ? `the widths ${WIDTHS.join(', ')} on both consoles` : null,
		options.phases.includes(VOLUME_PHASE) ? 'both consoles at volume and their deep links' : null
	].filter((phase) => phase !== null);
	const breaches = judgements.filter((judgement) => judgement.breach);
	const informationalBreaches = breaches.filter((judgement) => judgement.informational).length;
	return `Run: seed ${options.seed}, ${ran.join(', ')}. Count checks stood down on ${context ? context.skippedCountChecks : 0} steps `
			+ `(the model could not name the expected rows there). Console-error noise lines: ${context ? context.consoleNoise.length : 0}; timings: ${judgements.length} kinds, `
			+ `${breaches.length} breaches (${informationalBreaches} informational).`;
}

/**
 * @description Prints the summary, every finding, the timings and the console noise.
 * @param {string} summary The run's summary line.
 * @param {Object} ledger The findings ledger.
 * @param {Object|null} context The run context, or null.
 * @param {Object} outputs The output paths.
 * @param {Array<Object>} judgements The timing judgements.
 */
function printResults(summary, ledger, context, outputs, judgements)
{
	const reportable = ledger.reportableCount();
	console.log(`\n${summary}`);
	console.log(`findings: ${reportable} reportable, ${ledger.findings.length - reportable} observations only -> ${outputs.findingsPath}`);
	const judged = judgements.map((judgement) => `${judgement.kind} ${judgement.name} P75 ${judgement.p75} ms over ${judgement.samples}`).join('; ');
	console.log(`timings: ${judged || 'none'} -> ${outputs.timingsPath}`);
	for(const finding of ledger.findings)
	{
		console.log(`  [${finding.index}] ${finding.session}/${finding.step} ${finding.check} (${finding.move}): expected ${finding.expected}; on screen ${finding.observed}`
				+ `${finding.repeats ? ` (+${finding.repeats} more)` : ''}`);
	}
	if(context && context.consoleNoise.length > 0)
	{
		console.log('\nconsole noise (not findings):');
		for(const noise of [...new Set(context.consoleNoise)].slice(0, NOISE_LINES_PRINTED))
		{
			console.log(`  ${noise}`);
		}
	}
}

/**
 * @description Prints what this run is: its seed, its phases, its org and, for a volume run, its manifest.
 * @param {Object} options The parsed options.
 */
function printBanner(options)
{
	console.log(options.manifest
			? 'Console exploration at volume: both consoles over the driver\'s load'
			: 'Adversarial console exploration: the pinned state and the narrow widths');
	console.log('======================================================================');
	console.log(`seed=${options.seed} sessions=${options.sessions} steps=${options.steps} phases=[${options.phases.join(', ')}]`
			+ ` instance=${getInstanceUrl()} namespace=[${namespacePrefix()}]${options.manifest ? ` manifest=${options.manifest}` : ''}`);
	console.log('Replay this run\'s moves with: node explore-consoles.js --seed ' + options.seed);
}

/**
 * @description The two oracles a run may need: the shaped seed's rows when a shaped phase runs, the load's
 *              manifest when one is given.
 * @param {Object} options The parsed options.
 * @param {boolean} seedNeeded Whether a shaped phase runs.
 * @returns {Object} `oracle` and `load`, either null when not needed.
 */
function readOracles(options, seedNeeded)
{
	const oracle = seedNeeded ? readOracle() : null;
	const load = options.manifest ? readManifestOracle(options.manifest) : null;
	if(oracle)
	{
		console.log(`seeded rows under the fixtures' ids: ${oracle.rows.length}`);
	}
	if(load)
	{
		console.log(`manifest: run ${load.runToken}, ${load.actions.length} actions, reconciliation ${load.reconciliation.id}`);
	}
	return {oracle, load};
}

/**
 * @description Makes the output folder, and for a manifest run copies the manifest beside the findings it was
 *              checked against.
 * @param {Object} options The parsed options.
 * @param {Object} outputs The output paths.
 */
function prepareOutputs(options, outputs)
{
	fs.mkdirSync(outputs.screenshotDirectory, {recursive: true});
	if(options.manifest)
	{
		fs.copyFileSync(options.manifest, path.join(outputs.directory, 'manifest.json'));
	}
}

async function main()
{
	const options = readOptions();
	const outputs = resolveOutputs(options);
	// The shaped phases need the shaped seed; the volume phase walks the load the manifest describes.
	const seedNeeded = options.phases.some((phase) => phase !== VOLUME_PHASE);
	const ledger = createFindingsLedger({
		seed: options.seed, screenshotDirectory: outputs.screenshotDirectory, findingsPath: outputs.findingsPath, maximumScreenshots: MAXIMUM_SCREENSHOTS
	});
	prepareOutputs(options, outputs);
	printBanner(options);

	// Everything from here is inside the try: from the moment the seed is in the org, the only way out
	// is through the teardown, whether the org, the browser or the walk is what failed.
	if(seedNeeded)
	{
		seedFixtures();
	}
	let aborted = null;
	let browser = null;
	let context = null;
	let judgements;
	try
	{
		const oracles = readOracles(options, seedNeeded);
		browser = await chromium.launch({headless: true});
		context = await openContext(browser, oracles, options, ledger);
		if(seedNeeded)
		{
			await reportSeedTotals(context);
		}
		await runPhases(context, options);
	}
	catch(failure)
	{
		aborted = failure;
	}
	finally
	{
		// The timings are judged while the page is still open, so a breach's row carries a screenshot like any
		// other finding; a walk that never opened the browser has no sample to judge.
		judgements = context ? await reportTimingBreaches(context, options.timingBudgets) : [];
		if(browser)
		{
			await browser.close().catch(() =>
			{
			});
		}
		if(seedNeeded)
		{
			await tearDownShapedSeed(ledger, context || {page: null});
		}
	}

	const summary = describeRun(options, context, judgements);
	ledger.write(summary);
	writeTimings(outputs.timingsPath, judgements);
	printResults(summary, ledger, context, outputs, judgements);
	if(aborted)
	{
		console.error('\nThe walk stopped early:', aborted);
	}
	process.exit(ledger.reportableCount() > 0 || aborted ? 1 : 0);
}

main().catch((failure) =>
{
	console.error('Exploration aborted before it could clean up:', failure);
	process.exit(1);
});
