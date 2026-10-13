#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1
// Runs the journeys a change needs: the map names the source each spec part proves; the changed files come from git.
//   npm run test:e2e:changed -- --since origin/HEAD [--dry-run]
// origin/HEAD, the default, is the remote's default branch, which git sets on every clone.
'use strict';
const {execFileSync, spawnSync} = require('child_process');
const fs = require('fs');
const path = require('path');
const {namespacePrefix} = require('./helpers/sf-namespace');

const MAP_PATH = path.join(__dirname, 'journey-map.json');
const CONFIG = path.join('release-testing', 'e2e', 'playwright.config.js');
const DEFAULT_SINCE = 'origin/HEAD';
const USAGE_EXIT_CODE = 2;
const FAILURE_EXIT_CODE = 1;
const PAGES_DIRECTORY = 'release-testing/e2e/pages/';
const SPEC_SUFFIX = '.spec.js';

/**
 * @description Runs a git command and returns its raw text output.
 *
 * @param {string[]} args The git subcommand and its arguments.
 *
 * @returns {string} The command's standard output.
 */
function runGit(args)
{
	return execFileSync('git', args, {encoding: 'utf8'});
}

/**
 * @description The repository-relative paths that changed since a ref, joining what was committed with what the
 * working tree still carries (staged, unstaged or untracked), so a change is caught whether or not it is committed.
 *
 * @param {object} options The read options.
 * @param {string} options.since The ref to diff against.
 * @param {Function} [options.git] The git runner, overridable so a test can script the answers.
 *
 * @returns {string[]} The de-duplicated list of changed paths.
 *
 * @throws {Error} When git cannot diff against the ref, naming `--since` as the way to pass one that exists.
 */
function readChangedPaths({since, git = runGit})
{
	let diff;
	try
	{
		diff = git(['diff', '--name-only', since]);
	}
	catch(failure)
	{
		throw new Error(`git cannot diff against ${since} (${failure.message.trim()}); pass a ref that exists with --since <ref>`);
	}
	const committed = diff.split('\n').map((line) => line.trim()).filter(Boolean);
	const working = git(['status', '--porcelain']).split('\n').map((line) => line.slice(3).trim()).filter(Boolean);
	return [...new Set([...committed, ...working])];
}

/**
 * @description Which spec parts a set of changed paths touches, and why: a part is selected when a changed path
 * is its spec file, starts with one of its mapped prefixes, or is one of its page objects; a change under a core
 * path selects everything, since core files back every journey.
 *
 * @param {object} map The journey map (`core` prefixes and named `parts`).
 * @param {string[]} changedPaths The repository-relative paths that changed.
 *
 * @returns {object} `{parts, reasons, core, everything}`: the selected part names, the matched paths per part, the
 * changed paths that fall under a core path, and whether a core change means the whole battery.
 */
function selectParts(map, changedPaths)
{
	const core = changedPaths.filter((changed) => map.core.some((corePath) => changed.startsWith(corePath)));
	const reasons = {};
	for(const [name, part] of Object.entries(map.parts))
	{
		const matched = changedPaths.filter((changed) => changed === part.spec
				|| part.paths.some((mapped) => changed.startsWith(mapped))
				|| part.pages.some((page) => changed === `${PAGES_DIRECTORY}${page}`));
		if(matched.length > 0)
		{
			reasons[name] = matched;
		}
	}
	return {parts: Object.keys(reasons), reasons, core, everything: core.length > 0};
}

/**
 * @description The selection to run, guarded against narrowing on an org that already has the package installed:
 * a packaged org proves the release the same way every time, so a change-based narrowing there would silently
 * skip journeys a subscriber upgrade still needs proved.
 *
 * @param {object} map The journey map.
 * @param {string[]} changedPaths The repository-relative paths that changed.
 *
 * @returns {object} The selection from {@link selectParts}, plus `reason` (a one-line explanation, or `null` when
 * the selection came from the changed paths alone).
 */
function decide(map, changedPaths)
{
	if(namespacePrefix())
	{
		return {everything: true, parts: [], reasons: {}, core: [], reason: 'the org has the package installed, so a release run is always the whole battery'};
	}
	return {...selectParts(map, changedPaths), reason: null};
}

/**
 * @description The command-line entry point: reads the changed paths, decides the selection, prints its reasoning,
 * and either stops short (nothing to run), reports the dry run, or hands the selected specs to Playwright.
 *
 * @param {string[]} argv The arguments after the script name (`process.argv.slice(2)`).
 *
 * @returns {number} The process exit code.
 */
function main(argv)
{
	const sinceIndex = argv.indexOf('--since');
	const since = sinceIndex >= 0 ? argv[sinceIndex + 1] : DEFAULT_SINCE;
	const dryRun = argv.includes('--dry-run');
	const map = JSON.parse(fs.readFileSync(MAP_PATH, 'utf8'));
	const changed = readChangedPaths({since});
	const decision = decide(map, changed);
	if(decision.reason)
	{
		console.log(`select-journeys: ${decision.reason}`);
	}
	const specs = decision.everything ? [] : decision.parts.map((name) => path.basename(map.parts[name].spec, SPEC_SUFFIX));
	console.log(`select-journeys: ${changed.length} changed paths since ${since}`);
	for(const [name, matched] of Object.entries(decision.reasons))
	{
		console.log(`  ${name} because ${matched.join(', ')}`);
	}
	if(decision.core.length > 0)
	{
		console.log(`  the whole battery because ${decision.core.join(', ')}`);
	}
	if(!decision.everything && specs.length === 0)
	{
		console.log('select-journeys: no journey maps to the change; nothing to run');
		return 0;
	}
	console.log(decision.everything
			? 'select-journeys: the whole battery'
			: `select-journeys: these parts (Playwright still runs the parts they depend on first): ${specs.join(', ')}`);
	if(dryRun)
	{
		return 0;
	}
	const result = spawnSync('npx', ['playwright', 'test', '--config', CONFIG, ...specs], {stdio: 'inherit', shell: process.platform === 'win32'});
	if(result.error)
	{
		console.error(`select-journeys: playwright did not start: ${result.error.message}`);
		return FAILURE_EXIT_CODE;
	}
	return result.status ?? FAILURE_EXIT_CODE;
}

if(require.main === module)
{
	try
	{
		process.exit(main(process.argv.slice(2)));
	}
	catch(failure)
	{
		console.error(`select-journeys: ${failure.message}`);
		process.exit(USAGE_EXIT_CODE);
	}
}

module.exports = {readChangedPaths, selectParts, decide, main, DEFAULT_SINCE, PAGES_DIRECTORY};
