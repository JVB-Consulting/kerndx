// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const {parsePrePushStdin, resolveDiffBase, isHexSha} = require('../../src/lib/diff-base.js');

test('parsePrePushStdin returns null for empty input', () =>
{
	assert.equal(parsePrePushStdin(''), null);
	assert.equal(parsePrePushStdin(null), null);
});

test('parsePrePushStdin returns remoteSha for well-formed line', () =>
{
	const stdin = 'refs/heads/feature/x abc123def456 refs/heads/feature/x 0123456789abcdef0123456789abcdef01234567\n';
	assert.deepEqual(parsePrePushStdin(stdin), {remoteSha: '0123456789abcdef0123456789abcdef01234567'});
});

test('parsePrePushStdin returns null for malformed line', () =>
{
	assert.equal(parsePrePushStdin('garbage'), null);
});

test('resolveDiffBase accepts a default-branch override and always returns a ref', () =>
{
	// Runs against this repo; the configured branch is interpolated into the
	// merge-base probe, with deterministic fallbacks, so the result is a
	// non-empty git ref string regardless of which branches exist.
	const base = resolveDiffBase('', 'master');
	assert.equal(typeof base, 'string');
	assert.ok(base.length > 0);
	// An unknown branch still resolves via the fallback chain (never throws).
	assert.ok(resolveDiffBase('', 'no-such-branch-xyz').length > 0);
});

test('resolveDiffBase defaults the branch to main when omitted', () =>
{
	assert.ok(resolveDiffBase('').length > 0);
});

test('isHexSha accepts plausible git object names and rejects everything else', () =>
{
	assert.ok(isHexSha('0123456789abcdef0123456789abcdef01234567'), '40-char sha');
	assert.ok(isHexSha('abc1234'), '7-char abbrev');
	assert.ok(!isHexSha('main; rm -rf /'), 'shell metacharacters rejected');
	assert.ok(!isHexSha('-Pfoo'), 'leading-dash (argv-injection) rejected');
	assert.ok(!isHexSha('abc'), 'too short');
	assert.ok(!isHexSha(''), 'empty');
	assert.ok(!isHexSha(null), 'null');
});

test('resolveDiffBase returns a verified pre-push remote sha (resolvable object)', () =>
{
	// This file runs inside the repo; HEAD is a real, resolvable object.
	let head;
	try
	{
		head = execFileSync('git', [
			'rev-parse',
			'HEAD'
		], {encoding: 'utf-8'}).trim();
	}
	catch
	{
		return;   // not in a git repo (CI edge) — skip
	}
	const stdin = `refs/heads/x ${head} refs/heads/main ${head}\n`;
	assert.equal(resolveDiffBase(stdin, 'main'), head, 'a resolvable remote sha is returned verbatim');
});

test('resolveDiffBase degrades to the literal HEAD sentinel when no base is resolvable', () =>
{
	// A throwaway repo with a single commit, no remote, no HEAD~20 history, and a
	// nonexistent default branch exercises the full fallback chain to 'HEAD' —
	// the sentinel BLOCKER-3 degraded-base handling keys on.
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'db-'));
	const cwd = process.cwd();
	const git = (args) => execFileSync('git', args, {cwd: dir, encoding: 'utf-8'});
	try
	{
		git([
			'init',
			'-q'
		]);
		git([
			'config',
			'user.email',
			't@t.t'
		]);
		git([
			'config',
			'user.name',
			't'
		]);
		git([
			'config',
			'commit.gpgsign',
			'false'
		]);
		fs.writeFileSync(path.join(dir, 'a.txt'), 'one\n');
		git([
			'add',
			'-A'
		]);
		git([
			'commit',
			'-qm',
			'one'
		]);
		process.chdir(dir);
		assert.equal(resolveDiffBase('', 'no-such-remote-branch'), 'HEAD', 'fully-degraded base returns the HEAD sentinel');
	}
	finally
	{
		process.chdir(cwd);
		fs.rmSync(dir, {recursive: true, force: true});
	}
});
