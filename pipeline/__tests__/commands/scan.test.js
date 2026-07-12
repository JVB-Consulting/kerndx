// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const {scanCommand, resolveChangedFiles, scanPatternsFor, resolveSeverityThreshold, CI_SEVERITY_THRESHOLD} = require('../../src/commands/scan.js');

test('scan --ci scans the full workspace when no diff base can be resolved', async() =>
{
	const originalCwd = process.cwd();
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'scan-degraded-'));
	try
	{
		process.chdir(dir);
		// A fresh repo with no commits and no origin: merge-base and HEAD~20 both
		// fail, so resolveDiffBase returns its degraded 'HEAD' sentinel.
		execFileSync('git', ['init', '-q']);
		fs.mkdirSync('.kerndx', {recursive: true});
		fs.writeFileSync('.kerndx/config.yml', [
			'package_dirs:',
			'  - force-app/main/default',
			'branches:',
			'  main: main',
			'  ingress:',
			'    - main',
			'  protected:',
			'    - main',
			'ci_adapter:',
			'  name: none',
			''
		].join('\n'));

		let captured = null;
		const rc = await scanCommand({
			ci: true,
			stdinText: '',
			runSfcaFn: (opts) =>
			{
				captured = opts;
				return {status: 0};
			},
			checkSfFn: () => true,
			checkPluginFn: () => true
		});

		assert.equal(rc, 0);
		assert.ok(captured, 'the scan must run, not silently skip');
		assert.deepEqual(captured.files, [], 'degraded base scans the whole workspace (no --target filters)');
		assert.equal(captured.severityThreshold, CI_SEVERITY_THRESHOLD);
	}
	finally
	{
		process.chdir(originalCwd);
		fs.rmSync(dir, {recursive: true, force: true});
	}
});

test('CI severity threshold matches the workflow gate (sev1 + sev2 block)', () =>
{
	// The sfca-quality-gate workflow blocks on severity 1 OR 2, and KernDX
	// priority-1 PMD rules surface as SFCA severity 2 — a threshold of 1
	// would never block a KernDX rule violation.
	assert.equal(CI_SEVERITY_THRESHOLD, 2);
});

test('resolveSeverityThreshold: CI mode always uses the gate-parity threshold', () =>
{
	assert.equal(resolveSeverityThreshold(true, {}), 2);
	assert.equal(resolveSeverityThreshold(true, {scanner: {severity_threshold: 5}}), 2);
});

test('resolveSeverityThreshold: local mode honours config with a default of 1', () =>
{
	assert.equal(resolveSeverityThreshold(false, {}), 1);
	assert.equal(resolveSeverityThreshold(false, {scanner: {severity_threshold: 3}}), 3);
});

test('scanPatternsFor returns the standard glob set for force-app default', () =>
{
	const patterns = scanPatternsFor(['force-app/main/default']);
	assert.deepEqual(patterns, [
		'force-app/main/default/**/*.cls',
		'force-app/main/default/**/*.trigger',
		'force-app/main/default/**/*.js',
		'force-app/main/default/**/*.html',
		'force-app/main/default/**/*.flow-meta.xml'
	]);
});

test('scanPatternsFor handles multiple package dirs', () =>
{
	const patterns = scanPatternsFor([
		'force-app/main/default',
		'unpackaged/main/default'
	]);
	assert.equal(patterns.length, 10);
	assert.ok(patterns.some(p => p.startsWith('unpackaged/')));
});
