// SPDX-License-Identifier: MIT
'use strict';

/**
 * Tests for pipeline/scripts/run-tests.js — the wrapper that filters
 * subscriber-naming-fixture-dependent tests when the fixtures dir is absent
 * (mirror-clone case).
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');

const RUNNER = path.resolve(__dirname, '..', 'scripts', 'run-tests.js');
const {enumerateTestFiles, requiresSubscriberFixtures} = require('../scripts/run-tests.js');

function mkTmpRoot()
{
	return fs.mkdtempSync(path.join(os.tmpdir(), 'kern-pipeline-runner-'));
}

function mkTestFile(dir, name, content)
{
	fs.mkdirSync(dir, {recursive: true});
	const p = path.join(dir, name);
	fs.writeFileSync(p, content);
	return p;
}

test('enumerateTestFiles walks recursively + finds *.test.js', () =>
{
	const root = mkTmpRoot();
	try
	{
		mkTestFile(root, 'a.test.js', 'test();');
		mkTestFile(path.join(root, 'sub'), 'b.test.js', 'test();');
		mkTestFile(path.join(root, 'sub', 'deeper'), 'c.test.js', 'test();');
		mkTestFile(root, 'not-a-test.js', 'noop');
		const found = enumerateTestFiles(root);
		assert.equal(found.length, 3);
		assert.ok(found.some(p => p.endsWith('a.test.js')));
		assert.ok(found.some(p => p.endsWith('b.test.js')));
		assert.ok(found.some(p => p.endsWith('c.test.js')));
		assert.ok(!found.some(p => p.endsWith('not-a-test.js')));
	}
	finally
	{
		fs.rmSync(root, {recursive: true, force: true});
	}
});

test('enumerateTestFiles skips fixtures/ and node_modules/', () =>
{
	const root = mkTmpRoot();
	try
	{
		mkTestFile(root, 'a.test.js', 'test();');
		mkTestFile(path.join(root, 'fixtures'), 'b.test.js', 'test();');
		mkTestFile(path.join(root, 'node_modules', 'dep'), 'c.test.js', 'test();');
		const found = enumerateTestFiles(root);
		assert.equal(found.length, 1);
		assert.ok(found[0].endsWith('a.test.js'));
	}
	finally
	{
		fs.rmSync(root, {recursive: true, force: true});
	}
});

test('enumerateTestFiles returns empty when dir is absent', () =>
{
	const found = enumerateTestFiles('/nonexistent/path-12345');
	assert.deepEqual(found, []);
});

test('requiresSubscriberFixtures detects literal path strings', () =>
{
	const root = mkTmpRoot();
	try
	{
		const file = mkTestFile(root, 't.test.js', 'const p = \'fixtures/subscriber-naming/config.yml\';');
		assert.equal(requiresSubscriberFixtures(file), true);
	}
	finally
	{
		fs.rmSync(root, {recursive: true, force: true});
	}
});

test('requiresSubscriberFixtures detects path.join arg sequences', () =>
{
	const root = mkTmpRoot();
	try
	{
		const file = mkTestFile(root, 't.test.js', 'path.join(__dirname, \'..\', \'fixtures\', \'subscriber-naming\', \'flows\');');
		assert.equal(requiresSubscriberFixtures(file), true);
	}
	finally
	{
		fs.rmSync(root, {recursive: true, force: true});
	}
});

test('requiresSubscriberFixtures returns false for unrelated tests', () =>
{
	const root = mkTmpRoot();
	try
	{
		const file = mkTestFile(root, 't.test.js', 'assert.equal(1+1, 2);');
		assert.equal(requiresSubscriberFixtures(file), false);
	}
	finally
	{
		fs.rmSync(root, {recursive: true, force: true});
	}
});

test('integration: runner exits 0 when fixtures present (upstream case)', () =>
{
	// This test exercises the real upstream tree because that's where the
	// fixtures live. Run with --test-name-pattern=__nothing__ to avoid
	// re-running every pipeline test in this assertion (we only care that
	// the runner orchestrates successfully).
	const result = spawnSync('node', [
		RUNNER,
		'--test-name-pattern',
		'__match-nothing-12345__'
	], {
		encoding: 'utf-8', cwd: path.resolve(__dirname, '..', '..')
	});
	assert.equal(result.status, 0, `runner exit nonzero: ${result.stderr}`);
});

test('integration: runner skips fixture-dependent tests when fixtures absent', () =>
{
	// Mock a "mirror clone" by copying the runner + a minimal __tests__/ tree
	// (no fixtures dir) into a tmp pipeline-root.
	const tmpRoot = mkTmpRoot();
	try
	{
		fs.mkdirSync(path.join(tmpRoot, 'scripts'));
		fs.mkdirSync(path.join(tmpRoot, '__tests__', 'naming-engine'), {recursive: true});

		fs.copyFileSync(RUNNER, path.join(tmpRoot, 'scripts', 'run-tests.js'));

		// One test that does NOT reference subscriber-naming.
		mkTestFile(path.join(tmpRoot, '__tests__'), 'always.test.js', 'const t = require(\'node:test\'); const a = require(\'node:assert/strict\'); t(\'ok\', () => a.equal(1,1));');

		// One test that DOES reference subscriber-naming — should be skipped.
		mkTestFile(path.join(tmpRoot, '__tests__', 'naming-engine'), 'flow.test.js',
				'const path = require(\'node:path\'); const dir = path.join(__dirname, \'..\', \'fixtures\', \'subscriber-naming\', \'flows\');');

		const result = spawnSync('node', [path.join(tmpRoot, 'scripts', 'run-tests.js')], {
			encoding: 'utf-8', cwd: tmpRoot
		});
		assert.equal(result.status, 0, `runner exit nonzero: ${result.stderr}`);
		assert.match(result.stdout, /subscriber-naming fixtures not shipped/);
		assert.match(result.stdout, /skipping 1 test file/);
		assert.match(result.stdout, /flow\.test\.js/);
		assert.match(result.stdout, /running 1 remaining test file/);
	}
	finally
	{
		fs.rmSync(tmpRoot, {recursive: true, force: true});
	}
});
