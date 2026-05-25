#!/usr/bin/env node
// SPDX-License-Identifier: MIT
'use strict';

/**
 * @description Pipeline test-runner wrapper that filters out fixture-
 *              dependent tests when the fixtures directory is not present.
 *              Some tests require fixture data that is not bundled with this
 *              distribution; the wrapper skips those tests with a clear log
 *              line and runs the remainder.
 *
 *              Branches:
 *                - Fixtures present: run the full suite via
 *                  `node --test pipeline/__tests__/`.
 *                - Fixtures absent: enumerate test files, drop any that
 *                  reference the fixtures path, log the skip, run
 *                  `node --test` on the filtered list.
 *
 * @author Kern Framework
 * @date May 2026
 */

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const pipelineRoot = path.resolve(__dirname, '..');
const testsRoot = path.join(pipelineRoot, '__tests__');
const fixturesDir = path.join(testsRoot, 'fixtures', 'subscriber-naming');

function enumerateTestFiles(dir, out)
{
	out = out || [];
	if(!fs.existsSync(dir)) return out;
	for(const entry of fs.readdirSync(dir, {withFileTypes: true}))
	{
		if(entry.name === 'fixtures' || entry.name === 'node_modules') continue;
		const full = path.join(dir, entry.name);
		if(entry.isDirectory()) enumerateTestFiles(full, out);
		else if(entry.isFile() && entry.name.endsWith('.test.js')) out.push(full);
	}
	return out;
}

function requiresSubscriberFixtures(file)
{
	// Matches both literal path strings ('fixtures/subscriber-naming/...') and
	// path.join arg sequences ("'fixtures', 'subscriber-naming'") that source
	// the subscriber-naming fixture set.
	const content = fs.readFileSync(file, 'utf-8');
	return content.includes('subscriber-naming');
}

function run(argv)
{
	const hasFixtures = fs.existsSync(fixturesDir);
	const allTests = enumerateTestFiles(testsRoot).sort();

	let runList;
	if(hasFixtures)
	{
		runList = allTests;
	}
	else
	{
		const skipped = [];
		runList = [];
		for(const test of allTests)
		{
			if(requiresSubscriberFixtures(test)) skipped.push(test);
			else runList.push(test);
		}
		if(skipped.length > 0)
		{
			console.log(`[test:pipeline] subscriber-naming fixtures not shipped in this checkout — skipping ${skipped.length} test file(s):`);
			for(const s of skipped) console.log(`  - ${path.relative(pipelineRoot, s)}`);
			console.log(`[test:pipeline] running ${runList.length} remaining test file(s).`);
		}
	}

	if(runList.length === 0)
	{
		console.log('[test:pipeline] no test files to run.');
		return 0;
	}

	const result = spawnSync('node', ['--test', ...runList, ...argv], {stdio: 'inherit', cwd: pipelineRoot});
	return result.status === null ? 1 : result.status;
}

if(require.main === module)
{
	process.exit(run(process.argv.slice(2)));
}

module.exports = {run, enumerateTestFiles, requiresSubscriberFixtures};
