// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const CLI = path.join(__dirname, '..', 'bin', 'cli.js');

test('cli --help prints all 8 subcommands', () =>
{
	const result = spawnSync('node', [
		CLI,
		'--help'
	], {encoding: 'utf-8'});
	assert.equal(result.status, 0);
	for(const cmd of [
		'init',
		'scan',
		'naming',
		'preflight',
		'doctor',
		'upgrade',
		'classify-ref',
		'slack-payload'
	])
	{
		assert.match(result.stdout, new RegExp(`\\b${cmd}\\b`), `expected help to mention ${cmd}`);
	}
});

test('cli with no args prints help and exits 1', () =>
{
	const result = spawnSync('node', [CLI], {encoding: 'utf-8'});
	assert.equal(result.error, undefined, 'spawn should not error — CLI binary must exist and be reachable');
	assert.equal(result.status, 1);
	assert.match(result.stdout, /Available Commands/, 'help text should be printed before exit 1');
});

test('cli upgrade --help documents --force flag', () =>
{
	const result = spawnSync('node', [
		CLI,
		'upgrade',
		'--help'
	], {encoding: 'utf-8'});
	assert.equal(result.status, 0);
	assert.match(result.stdout, /--force/, 'upgrade help should mention --force');
});

test('cli init --check answers the prompts but writes no file in the current folder', () =>
{
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cli-init-check-'));
	try
	{
		// An empty standard input takes the default answer to every prompt.
		const result = spawnSync('node', [
			CLI,
			'init',
			'--check'
		], {cwd: dir, input: '', encoding: 'utf-8', timeout: 30000});
		assert.equal(result.status, 0, result.stderr);
		assert.deepEqual(fs.readdirSync(dir), []);
		assert.match(result.stdout, /would write \.kerndx\/config\.yml/);
		assert.match(result.stdout, /would write \.kerndx\/manifest\.json/);
	}
	finally
	{
		fs.rmSync(dir, {recursive: true, force: true});
	}
});

test('cli init --answers-file --check asks no question and writes no file in the current folder', () =>
{
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cli-init-answers-'));
	const answersDir = fs.mkdtempSync(path.join(os.tmpdir(), 'cli-init-answers-file-'));
	const answersFile = path.join(answersDir, 'kerndx-answers.json');
	fs.writeFileSync(answersFile, JSON.stringify({
		package_dirs: ['force-app/main/default'],
		framework_package: true,
		ci_adapter: {name: 'none'},
		branches: {main: 'main', ingress: ['main'], protected: ['main'], release: []},
		slack: {enabled: false}
	}));
	try
	{
		const result = spawnSync('node', [
			CLI,
			'init',
			'--answers-file',
			answersFile,
			'--check'
		], {cwd: dir, input: '', encoding: 'utf-8', timeout: 30000});
		assert.equal(result.status, 0, result.stderr);
		assert.deepEqual(fs.readdirSync(dir), []);
		assert.doesNotMatch(result.stdout, /Package directories/, 'Expected no question when the answers come from a file');
		assert.match(result.stdout, /would write \.kerndx\/config\.yml/);
		assert.match(result.stdout, /would write \.kerndx\/manifest\.json/);
	}
	finally
	{
		fs.rmSync(dir, {recursive: true, force: true});
		fs.rmSync(answersDir, {recursive: true, force: true});
	}
});

test('cli init --answers-file without a path fails with the reason and writes nothing', () =>
{
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cli-init-no-answers-path-'));
	try
	{
		for(const args of [['--answers-file'], ['--answers-file', '--check']])
		{
			const result = spawnSync('node', [CLI, 'init', ...args], {cwd: dir, input: '', encoding: 'utf-8', timeout: 30000});

			assert.equal(result.status, 1, `Expected init ${args.join(' ')} to fail`);
			assert.match(result.stderr, /init failed: --answers-file needs the path of a JSON file/);
			assert.doesNotMatch(result.stdout, /Package directories/, 'Expected no question when --answers-file is given');
			assert.deepEqual(fs.readdirSync(dir), []);
		}
	}
	finally
	{
		fs.rmSync(dir, {recursive: true, force: true});
	}
});

test('cli init --answers-file with a file that is not JSON fails with the reason and writes nothing', () =>
{
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cli-init-bad-answers-'));
	const answersDir = fs.mkdtempSync(path.join(os.tmpdir(), 'cli-init-bad-answers-file-'));
	const answersFile = path.join(answersDir, 'kerndx-answers.json');
	fs.writeFileSync(answersFile, 'package_dirs: force-app');
	try
	{
		const result = spawnSync('node', [
			CLI,
			'init',
			'--answers-file',
			answersFile,
			'--check'
		], {cwd: dir, input: '', encoding: 'utf-8', timeout: 30000});
		assert.equal(result.status, 1);
		assert.match(result.stderr, /init failed:/);
		assert.ok(result.stderr.includes(answersFile), `Expected the error to name the answers file, got: ${result.stderr}`);
		assert.match(result.stderr, /not valid JSON/);
		assert.doesNotMatch(result.stdout, /Package directories/, 'Expected no question when the answers come from a file');
		assert.deepEqual(fs.readdirSync(dir), []);
	}
	finally
	{
		fs.rmSync(dir, {recursive: true, force: true});
		fs.rmSync(answersDir, {recursive: true, force: true});
	}
});
