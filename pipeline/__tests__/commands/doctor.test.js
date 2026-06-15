// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {runInit} = require('../../src/commands/init.js');
const {runDoctor} = require('../../src/commands/doctor.js');

const ANSWERS_NONE = {
	package_dirs: ['force-app/main/default'],
	ci_adapter: {name: 'none'},
	branches: {main: 'main', ingress: ['main'], protected: ['main']},
	naming: {enabled: false},
	workflows: {runs_on: 'ubuntu-latest'}
};

test('doctor passes immediately after init', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'doc-clean-'));
	try
	{
		process.chdir(dir);
		await runInit({answers: ANSWERS_NONE, interactive: false});
		const code = await runDoctor({verbose: false, skipEnvironmentChecks: true});
		assert.equal(code, 0);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('doctor detects manually-edited workflow', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'doc-drift-'));
	try
	{
		process.chdir(dir);
		await runInit({answers: ANSWERS_NONE, interactive: false});
		fs.appendFileSync('.github/workflows/sfca-quality-gate.yml', '\n# tampered\n');
		const code = await runDoctor({verbose: false, skipEnvironmentChecks: true});
		assert.equal(code, 1);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('doctor tolerates CRLF line endings (LF-normalized hash)', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'doc-crlf-'));
	try
	{
		process.chdir(dir);
		await runInit({answers: ANSWERS_NONE, interactive: false});
		const file = '.github/workflows/sfca-quality-gate.yml';
		const lf = fs.readFileSync(file, 'utf-8');
		fs.writeFileSync(file, lf.replace(/\n/g, '\r\n'));
		const code = await runDoctor({verbose: false, skipEnvironmentChecks: true});
		assert.equal(code, 0, 'CRLF should not trip drift');
	}
	finally
	{
		process.chdir(originalCwd);
	}
});
