// SPDX-License-Identifier: MIT
'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {checkSfPresent, runSfca, quoteForCommandPrompt} = require('../../src/lib/sfca-runner.js');

/**
 * @description Installs a stand-in sf that only records what it was given. On Windows it is sf.cmd, exactly as the real
 *              CLI is, so the start travels the same road a reader's does. The pipeline may require nothing outside
 *              itself, so this is not scripts/lib/stand-in-tools.js.
 * @param {string} directory The folder the stand-in is written to.
 */
function installStandInSf(directory)
{
	const recorder = path.join(directory, 'stand-in.js');
	fs.writeFileSync(recorder, 'const fs=require(\'fs\');fs.appendFileSync(process.env.STAND_IN_LOG,JSON.stringify(process.argv.slice(2))+\'\\n\');\n');
	if(process.platform === 'win32')
	{
		fs.writeFileSync(path.join(directory, 'sf.cmd'), '@echo off\r\nnode "%~dp0stand-in.js" %*\r\n');
		return;
	}
	const shim = path.join(directory, 'sf');
	fs.writeFileSync(shim, `#!/bin/sh\nexec node "${recorder}" "$@"\n`);
	fs.chmodSync(shim, 0o755);
}

/**
 * @description Runs a callback with a folder first on the PATH and the stand-in's log pointed inside it, then puts
 *              both variables back as they were.
 * @param {string} directory The folder that holds the stand-in sf.
 * @param {Function} run Receives a function that returns the calls the stand-in recorded so far.
 * @returns {*} Whatever the callback returns.
 */
function withPath(directory, run)
{
	const key = Object.keys(process.env).find(name => name.toUpperCase() === 'PATH') || 'PATH';
	const saved = {path: process.env[key], log: process.env.STAND_IN_LOG};
	const logFile = path.join(directory, 'calls.log');
	process.env[key] = directory + path.delimiter + (saved.path || '');
	process.env.STAND_IN_LOG = logFile;
	try
	{
		return run(() => (fs.existsSync(logFile) ? fs.readFileSync(logFile, 'utf8').trim().split('\n').map(line => JSON.parse(line)) : []));
	}
	finally
	{
		process.env[key] = saved.path;
		if(saved.log === undefined)
		{
			delete process.env.STAND_IN_LOG;
		}
		else
		{
			process.env.STAND_IN_LOG = saved.log;
		}
	}
}

test('checkSfPresent finds a stand-in sf first on the PATH, on this system', () =>
{
	const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'sf-stand-in-'));
	installStandInSf(directory);
	try
	{
		withPath(directory, () => assert.equal(checkSfPresent(), true));
	}
	finally
	{
		fs.rmSync(directory, {recursive: true, force: true});
	}
});

test('runSfca hands sf exactly the arguments it built, a space and a quote included', () =>
{
	const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'sf-stand-in-'));
	installStandInSf(directory);
	try
	{
		withPath(directory, (calls) =>
		{
			const result = runSfca({
				workspace: 'my workspace', configFile: 'code-analyzer.yml', ruleSelector: 'Recommended', severityThreshold: 3,
				files: ['force-app/main/default/classes/A B.cls', 'force-app/**/*.cls', 'a"quoted".cls'], stdio: 'pipe'
			});
			assert.equal(result.status, 0);
			assert.deepEqual(calls(), [[
				'code-analyzer', 'run', '--workspace', 'my workspace', '--config-file', 'code-analyzer.yml', '--rule-selector', 'Recommended',
				'--severity-threshold', '3', '--target', 'force-app/main/default/classes/A B.cls', '--target', 'force-app/**/*.cls', '--target', 'a"quoted".cls'
			]]);
		});
	}
	finally
	{
		fs.rmSync(directory, {recursive: true, force: true});
	}
});

test('checkSfPresent is false when no sf is on the PATH', () =>
{
	const empty = fs.mkdtempSync(path.join(os.tmpdir(), 'no-sf-'));
	const key = Object.keys(process.env).find(name => name.toUpperCase() === 'PATH') || 'PATH';
	const saved = process.env[key];
	process.env[key] = empty;
	try
	{
		assert.equal(checkSfPresent(), false);
	}
	finally
	{
		process.env[key] = saved;
		fs.rmSync(empty, {recursive: true, force: true});
	}
});

test('quoteForCommandPrompt quotes only what Command Prompt would otherwise split or interpret', () =>
{
	assert.equal(quoteForCommandPrompt('plain'), 'plain');
	assert.equal(quoteForCommandPrompt('with space'), '"with space"');
	assert.equal(quoteForCommandPrompt('a&b'), '"a&b"');
	assert.equal(quoteForCommandPrompt('say "hi"'), '"say \\"hi\\""');
	assert.equal(quoteForCommandPrompt('force-app/**/*.cls'), 'force-app/**/*.cls');
});
