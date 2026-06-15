// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
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
