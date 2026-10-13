// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {runInit} = require('../../src/commands/init.js');
const {runUpgrade} = require('../../src/commands/upgrade.js');

const ANSWERS = {
	package_dirs: ['force-app/main/default'],
	ci_adapter: {name: 'none'},
	branches: {main: 'main', ingress: ['main'], protected: ['main']},
	naming: {enabled: false},
	slack: {enabled: false},
	workflows: {runs_on: 'ubuntu-latest'}
};

test('upgrade renames existing scaffolded files to .bak then rewrites', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'upg-'));
	try
	{
		process.chdir(dir);
		await runInit({answers: ANSWERS, interactive: false});
		fs.appendFileSync('.github/workflows/sfca-quality-gate.yml', '\n# my edits\n');

		const code = await runUpgrade();
		assert.equal(code, 0);
		assert.ok(fs.existsSync('.github/workflows/sfca-quality-gate.yml.bak'));
		const backup = fs.readFileSync('.github/workflows/sfca-quality-gate.yml.bak', 'utf-8');
		assert.match(backup, /# my edits/);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('upgrade re-renders the auto-assign reviewer workflow from the persisted opt-in', async() =>
{
	// The opt-in lives in config.yml as workflows.auto_assign_reviewer and
	// upgrade feeds it back through runInit, so the workflow must survive the
	// round trip and be refreshed from the shipped template.
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'upg-auto-assign-'));
	try
	{
		process.chdir(dir);
		await runInit({answers: {...ANSWERS, workflows: {runs_on: 'ubuntu-latest', auto_assign_reviewer: true}}, interactive: false});
		assert.ok(fs.existsSync('.github/workflows/auto-assign.yml'), 'init wrote auto-assign.yml');
		assert.match(fs.readFileSync('.kerndx/config.yml', 'utf-8'), /auto_assign_reviewer: true/);
		fs.appendFileSync('.github/workflows/auto-assign.yml', '\n# my edits\n');

		const code = await runUpgrade();
		assert.equal(code, 0);
		const refreshed = fs.readFileSync('.github/workflows/auto-assign.yml', 'utf-8');
		assert.match(refreshed, /^name: auto-assign\n/);
		assert.doesNotMatch(refreshed, /# my edits/, 'upgrade rewrites the workflow from the template');
		assert.match(fs.readFileSync('.github/workflows/auto-assign.yml.bak', 'utf-8'), /# my edits/);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('upgrade refuses if any .bak file already exists', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'upg-refuse-'));
	try
	{
		process.chdir(dir);
		await runInit({answers: ANSWERS, interactive: false});
		fs.writeFileSync('.github/workflows/sfca-quality-gate.yml.bak', 'old');
		const code = await runUpgrade();
		assert.equal(code, 1);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('upgrade --force auto-deletes stale .bak files and proceeds', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'upg-force-'));
	try
	{
		process.chdir(dir);
		await runInit({answers: ANSWERS, interactive: false});
		fs.writeFileSync('.github/workflows/sfca-quality-gate.yml.bak', 'stale-content-from-prior-upgrade');

		const code = await runUpgrade({force: true});
		assert.equal(code, 0);
		// The pre-existing .bak should have been deleted, then re-created by
		// the upgrade's normal backup pass (this time backing up the current
		// scaffolded content, NOT the stale "stale-content..." text).
		assert.ok(fs.existsSync('.github/workflows/sfca-quality-gate.yml.bak'));
		const backup = fs.readFileSync('.github/workflows/sfca-quality-gate.yml.bak', 'utf-8');
		assert.doesNotMatch(backup, /stale-content-from-prior-upgrade/);
		assert.match(backup, /name: sfca-quality-gate/);
	}
	finally
	{
		process.chdir(originalCwd);
	}
});

test('upgrade back-to-back with --force succeeds twice', async() =>
{
	// Regression: prior version refused any back-to-back upgrade because the
	// first one left .bak files behind.
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'upg-back-to-back-'));
	try
	{
		process.chdir(dir);
		await runInit({answers: ANSWERS, interactive: false});

		const first = await runUpgrade();
		assert.equal(first, 0, 'first upgrade should succeed');

		const second = await runUpgrade({force: true});
		assert.equal(second, 0, 'second upgrade with --force should succeed');
	}
	finally
	{
		process.chdir(originalCwd);
	}
});
