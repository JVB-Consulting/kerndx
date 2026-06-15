// SPDX-License-Identifier: MIT
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const {
	scanFiles, defaultReadFile, fingerprintFinding, parseIgnoreFile, globsToMatcher, decideExit, secretScanCommand, resolveTrackedFiles
} = require('../src/commands/secret-scan.js');

const AUTH_URL = 'force://3MVG9ClientIdABCdefGHIjkl:1955279925675241719:5Aep861FakeRefreshTokenBodyABCDEFGH@acme-dev-ed.my.salesforce.com'; // kerndx-secret-allow — synthetic fixture

function readerFor(map)
{
	return (file) => (Object.prototype.hasOwnProperty.call(map, file) ? map[file] : null);
}

// ---- scanFiles core -----------------------------------------------------

test('scanFiles flags a planted secret with its file path', () =>
{
	const files = [
		'force-app/secret.cls',
		'docs/readme.md'
	];
	const res = scanFiles(files, {
		readFile: readerFor({
			'force-app/secret.cls': `String s = '${AUTH_URL}';`, 'docs/readme.md': '# clean docs'
		})
	});
	assert.equal(res.blocking, 1, 'one blocking finding');
	assert.equal(res.findings[0].file, 'force-app/secret.cls');
	assert.equal(res.findings[0].ruleId, 'sfdx-auth-url');
	assert.ok(res.findings[0].fingerprint, 'finding carries a fingerprint');
});

test('scanFiles returns nothing for clean files', () =>
{
	const res = scanFiles([
		'a.js',
		'b.yml'
	], {
		readFile: readerFor({'a.js': 'const x = 1;', 'b.yml': 'key: value'})
	});
	assert.equal(res.findings.length, 0);
	assert.equal(res.blocking, 0);
	assert.equal(res.advisory, 0);
});

test('scanFiles skips files the reader returns null for (binary/large/unreadable)', () =>
{
	const res = scanFiles(['bin.png'], {readFile: () => null});
	assert.equal(res.findings.length, 0);
});

test('scanFiles honors ignoreGlobs', () =>
{
	const files = [
		'fixtures/leak.txt',
		'src/leak.txt'
	];
	const map = {'fixtures/leak.txt': AUTH_URL, 'src/leak.txt': AUTH_URL};
	const res = scanFiles(files, {readFile: readerFor(map), ignoreGlobs: ['fixtures/**']});
	assert.equal(res.findings.length, 1, 'only the non-ignored path is reported');
	assert.equal(res.findings[0].file, 'src/leak.txt');
});

test('scanFiles honors ignoreFingerprints (per-finding suppression)', () =>
{
	const file = 'src/leak.txt';
	const map = {[file]: AUTH_URL};
	const first = scanFiles([file], {readFile: readerFor(map)});
	const fp = first.findings[0].fingerprint;
	const suppressed = scanFiles([file], {readFile: readerFor(map), ignoreFingerprints: new Set([fp])});
	assert.equal(suppressed.findings.length, 0, 'fingerprinted finding is suppressed');
});

test('scanFiles applies caller-supplied custom patterns (internal seam)', () =>
{
	// customPatterns is a pure internal seam on scanFiles/scanText; there are no
	// subscriber-configured custom patterns any more, but a caller can still pass
	// pattern objects directly.
	const res = scanFiles(['a.txt'], {
		readFile: readerFor({'a.txt': 'value=WIDGETSECRETXYZ'}), customPatterns: [{id: 'widget', label: 'Widget key', tier: 'block', regex: /WIDGETSECRET[A-Z]+/g}]
	});
	assert.ok(res.findings.some(f => f.ruleId === 'widget'));
});

// ---- helpers ------------------------------------------------------------

test('fingerprintFinding is stable and derived from path + rule + secret', () =>
{
	const finding = {ruleId: 'sfdx-auth-url', match: AUTH_URL};
	const a = fingerprintFinding('src/x.cls', finding);
	const b = fingerprintFinding('src/x.cls', finding);
	assert.equal(a, b, 'stable for identical inputs');
	assert.notEqual(a, fingerprintFinding('src/y.cls', finding), 'path changes fingerprint');
	assert.notEqual(a, fingerprintFinding('src/x.cls', {ruleId: 'jwt', match: AUTH_URL}), 'rule changes fingerprint');
	assert.match(a, /^src\/x\.cls:sfdx-auth-url:[0-9a-f]{8,}$/, 'path:rule:hash shape');
});

test('parseIgnoreFile drops comments and blanks', () =>
{
	const set = parseIgnoreFile('# header\n\nsrc/x.cls:jwt:abcd1234\n   \n# trailing\nsrc/y.cls:jwt:beef5678\n');
	assert.equal(set.size, 2);
	assert.ok(set.has('src/x.cls:jwt:abcd1234'));
	assert.ok(set.has('src/y.cls:jwt:beef5678'));
});

test('parseIgnoreFile tolerates empty/missing content', () =>
{
	assert.equal(parseIgnoreFile('').size, 0);
	assert.equal(parseIgnoreFile(null).size, 0);
});

test('globsToMatcher matches ** and * correctly', () =>
{
	const m = globsToMatcher([
		'fixtures/**',
		'*.min.js',
		'docs/*.md'
	]);
	assert.ok(m('fixtures/a/b/c.txt'), '** spans directories');
	assert.ok(m('app.min.js'), '* within a segment');
	assert.ok(m('docs/guide.md'), 'docs/*.md');
	assert.ok(!m('docs/sub/guide.md'), '* does not span /');
	assert.ok(!m('src/app.js'), 'non-match');
});

test('globsToMatcher with no globs matches nothing', () =>
{
	const m = globsToMatcher([]);
	assert.ok(!m('anything'));
});

test('globsToMatcher is ReDoS-safe against adjacent ** + deep non-matching paths', () =>
{
	// Adjacent globstars used to compile to stacked nullable cross-slash groups
	// (catastrophic backtracking). The collapse + segment-bounded body keep this
	// linear. A deep path that does NOT match the trailing literal is the worst
	// case (forces full backtracking on the old compiler).
	const evil = globsToMatcher([
		'**/**/**/**/**/**/*.cls',
		'***/***/x'
	]);
	const deepNonMatch = `${'a/'.repeat(2000)}b.NOPE`;
	const start = process.hrtime.bigint();
	const result = evil(deepNonMatch);
	const ms = Number(process.hrtime.bigint() - start) / 1e6;
	assert.equal(result, false, 'deep path does not match the .cls glob');
	assert.ok(ms < 250, `matcher stays linear on a pathological input (took ${ms.toFixed(1)}ms)`);
	// Correctness preserved through the collapse: a real nested path still matches.
	assert.ok(globsToMatcher(['**/**/*.cls'])('src/a/b/c/Foo.cls'), 'collapsed globstars still match a nested path');
	assert.ok(globsToMatcher(['**/*.cls'])('Foo.cls'), 'globstar matches zero intermediate segments');
});

// ---- exit-code policy ---------------------------------------------------

test('decideExit blocks in CI when there are blocking findings', () =>
{
	assert.equal(decideExit({blocking: 2, advisory: 0}, true), 1);
});

test('decideExit is advisory locally even with blocking findings', () =>
{
	assert.equal(decideExit({blocking: 2, advisory: 0}, false), 0);
});

test('decideExit passes when only advisory findings exist, even in CI', () =>
{
	assert.equal(decideExit({blocking: 0, advisory: 3}, true), 0);
});

test('decideExit passes a clean result', () =>
{
	assert.equal(decideExit({blocking: 0, advisory: 0}, true), 0);
	assert.equal(decideExit({blocking: 0, advisory: 0}, false), 0);
});

// ---- defaultReadFile (binary / size / utf-8 gate) -----------------------

test('defaultReadFile reads a normal text file', () =>
{
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rf-'));
	const f = path.join(dir, 'a.txt');
	fs.writeFileSync(f, 'hello\nworld\n');
	try
	{
		assert.equal(defaultReadFile(f), 'hello\nworld\n');
	}
	finally
	{
		fs.rmSync(dir, {recursive: true, force: true});
	}
});

test('defaultReadFile skips known binary extensions', () =>
{
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rf-'));
	const f = path.join(dir, 'logo.png');
	fs.writeFileSync(f, Buffer.from([
		0x89,
		0x50,
		0x4e,
		0x47
	]));
	try
	{
		assert.equal(defaultReadFile(f), null);
	}
	finally
	{
		fs.rmSync(dir, {recursive: true, force: true});
	}
});

test('defaultReadFile skips a file containing NUL bytes (binary content)', () =>
{
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rf-'));
	const f = path.join(dir, 'blob.dat');
	fs.writeFileSync(f, Buffer.from([
		0x41,
		0x00,
		0x42
	]));
	try
	{
		assert.equal(defaultReadFile(f), null);
	}
	finally
	{
		fs.rmSync(dir, {recursive: true, force: true});
	}
});

test('defaultReadFile returns null for a missing file', () =>
{
	assert.equal(defaultReadFile('/no/such/file/anywhere.txt'), null);
});

// ---- command surface ----------------------------------------------------
// secretScanCommand reads stdin (fd 0) to detect a pre-push invocation, which
// would block under a test runner whose stdin never reaches EOF — so the command
// accepts an injected `stdinText` seam. With it, the degraded-base (B3) and
// empty-diff-in-CI (branch-poisoning) fallbacks are exercised in-process against
// throwaway git repos, not just the gitignored tmp/ shell smoke.

test('secretScanCommand is an async function', () =>
{
	assert.equal(typeof secretScanCommand, 'function');
});

const SSC_CONFIG = 'package_dirs: [force-app]\nbranches: { main: main, ingress: [main], protected: [main] }\nci_adapter: { name: none }\n';

function makeTempRepo(files)
{
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ssc-'));
	const git = (args) => execFileSync('git', args, {
		cwd: dir,
		encoding: 'utf-8',
		stdio: [
			'ignore',
			'pipe',
			'ignore'
		]
	});
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
	for(const [rel, content] of Object.entries(files))
	{
		const full = path.join(dir, rel);
		fs.mkdirSync(path.dirname(full), {recursive: true});
		fs.writeFileSync(full, content);
	}
	git([
		'add',
		'-A'
	]);
	git([
		'commit',
		'-qm',
		'init'
	]);
	return {dir, git};
}

// Run fn() with cwd set to dir and GITHUB_BASE_REF cleared (so the config branch
// path is what drives resolution), restoring both afterwards.
async function inRepo(dir, fn)
{
	const cwd = process.cwd();
	const savedRef = process.env.GITHUB_BASE_REF;
	delete process.env.GITHUB_BASE_REF;
	try
	{
		process.chdir(dir);
		return await fn();
	}
	finally
	{
		process.chdir(cwd);
		if(savedRef === undefined)
		{
			delete process.env.GITHUB_BASE_REF;
		}
		else
		{
			process.env.GITHUB_BASE_REF = savedRef;
		}
		fs.rmSync(dir, {recursive: true, force: true});
	}
}

// Like inRepo, but SETS GITHUB_BASE_REF to a trusted PR-target ref (the shipped
// GitHub Actions path) and optionally removes extra temp dirs (e.g. a bare
// origin) on teardown.
async function inRepoWithRef(dir, ref, fn, cleanupDirs)
{
	const cwd = process.cwd();
	const savedRef = process.env.GITHUB_BASE_REF;
	process.env.GITHUB_BASE_REF = ref;
	try
	{
		process.chdir(dir);
		return await fn();
	}
	finally
	{
		process.chdir(cwd);
		if(savedRef === undefined)
		{
			delete process.env.GITHUB_BASE_REF;
		}
		else
		{
			process.env.GITHUB_BASE_REF = savedRef;
		}
		fs.rmSync(dir, {recursive: true, force: true});
		for(const d of (cleanupDirs || []))
		{
			fs.rmSync(d, {recursive: true, force: true});
		}
	}
}

// A working repo wired to a throwaway bare "origin" so merge-base against
// origin/<branch> resolves — the precondition for exercising GITHUB_BASE_REF
// (PR-target) diff-base resolution. Returns {dir, remote, git}.
function makeRepoWithOrigin()
{
	const remote = fs.mkdtempSync(path.join(os.tmpdir(), 'ssc-rem-'));
	execFileSync('git', [
		'init',
		'--bare',
		'-q',
		'-b',
		'main',
		remote
	], {
		stdio: [
			'ignore',
			'pipe',
			'ignore'
		]
	});
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ssc-'));
	const git = (args) => execFileSync('git', args, {
		cwd: dir,
		encoding: 'utf-8',
		stdio: [
			'ignore',
			'pipe',
			'ignore'
		]
	});
	git([
		'init',
		'-q',
		'-b',
		'main'
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
	git([
		'remote',
		'add',
		'origin',
		remote
	]);
	return {dir, remote, git};
}

function writeRepoFile(dir, rel, content)
{
	const full = path.join(dir, rel);
	fs.mkdirSync(path.dirname(full), {recursive: true});
	fs.writeFileSync(full, content);
}

test('resolveTrackedFiles enumerates the tracked tree', async() =>
{
	const {dir} = makeTempRepo({'.kerndx/config.yml': SSC_CONFIG, 'force-app/a.cls': 'public class A {}'});
	await inRepo(dir, () =>
	{
		const files = resolveTrackedFiles();
		assert.ok(Array.isArray(files), 'returns an array');
		assert.ok(files.includes('force-app/a.cls'), 'lists a tracked source file');
		assert.ok(files.includes('.kerndx/config.yml'), 'lists the config file');
	});
});

test('secretScanCommand: a DEGRADED base (no origin, young repo) scans the full tree and BLOCKS in CI (B3)', async() =>
{
	const {dir} = makeTempRepo({'.kerndx/config.yml': SSC_CONFIG, 'force-app/leak.cls': `String s = '${AUTH_URL}';`});
	await inRepo(dir, async() =>
	{
		// No origin/main and <20 commits → resolveDiffBase degrades to 'HEAD'.
		const code = await secretScanCommand({ci: true, stdinText: ''});
		assert.equal(code, 1, 'degraded base must trigger a full-tree scan that blocks on the planted secret');
	});
});

test('secretScanCommand: an EMPTY CI diff (poisoned / HEAD base) falls back to full-tree and BLOCKS; local stays green (T1)', async() =>
{
	const {dir} = makeTempRepo({'.kerndx/config.yml': SSC_CONFIG, 'force-app/leak.cls': `String s = '${AUTH_URL}';`});
	const headSha = execFileSync('git', [
		'rev-parse',
		'HEAD'
	], {cwd: dir, encoding: 'utf-8'}).trim();
	// A pre-push stdin whose remote sha == HEAD makes the base resolve to HEAD's
	// own commit → `git diff HEAD...HEAD` is empty: the branch-poisoning shape.
	const stdin = `refs/heads/x ${headSha} refs/heads/main ${headSha}\n`;
	await inRepo(dir, async() =>
	{
		const ciCode = await secretScanCommand({ci: true, stdinText: stdin});
		assert.equal(ciCode, 1, 'an empty CI diff must fall back to a full-tree scan and block');
		const localCode = await secretScanCommand({ci: false, stdinText: stdin});
		assert.equal(localCode, 0, 'an empty diff locally is a genuine no-op (advisory, stays green)');
	});
});

test('secretScanCommand: GITHUB_BASE_REF is the trusted diff base and WINS over config.branches.main (T1)', async() =>
{
	// config.branches.main points at `oldbase` (a base BEFORE the pre-existing
	// secret); the trusted GITHUB_BASE_REF points at `postleak` (a base AFTER it).
	// If the config branch were used the diff would include old-leak.cls and
	// BLOCK; using the trusted ref, the secret is in the base and the diff is just
	// the clean new file → green. A green result proves GITHUB_BASE_REF won.
	const cfg = 'package_dirs: [force-app]\nbranches: { main: oldbase, ingress: [oldbase], protected: [oldbase] }\nci_adapter: { name: none }\n';
	const {dir, remote, git} = makeRepoWithOrigin();
	writeRepoFile(dir, '.kerndx/config.yml', cfg);
	writeRepoFile(dir, 'force-app/clean0.cls', 'public class Clean0 {}');
	git([
		'add',
		'-A'
	]);
	git([
		'commit',
		'-qm',
		'c0 clean baseline'
	]);
	git([
		'push',
		'-q',
		'origin',
		'HEAD:refs/heads/oldbase'
	]);
	writeRepoFile(dir, 'force-app/old-leak.cls', `String s = '${AUTH_URL}';`);
	git([
		'add',
		'-A'
	]);
	git([
		'commit',
		'-qm',
		'c1 pre-existing secret'
	]);
	git([
		'push',
		'-q',
		'origin',
		'HEAD:refs/heads/postleak'
	]);
	writeRepoFile(dir, 'force-app/clean-new.cls', 'public class CleanNew {}');
	git([
		'add',
		'-A'
	]);
	git([
		'commit',
		'-qm',
		'c2 clean change'
	]);
	git([
		'fetch',
		'-q',
		'origin'
	]);
	await inRepoWithRef(dir, 'postleak', async() =>
	{
		const code = await secretScanCommand({ci: true, stdinText: ''});
		assert.equal(code, 0, 'trusted GITHUB_BASE_REF base excludes the pre-existing secret → green (config.branches.main=oldbase would have blocked)');
	}, [remote]);
});

test('secretScanCommand: an empty diff on the trusted GITHUB_BASE_REF base falls back to full-tree and BLOCKS in CI (T1 fallback)', async() =>
{
	// origin/main == HEAD, so merge-base resolves to HEAD and the diff is empty.
	// The empty-diff-in-CI fallback must over-scan the full tree and catch the
	// committed secret rather than trusting the empty diff.
	const cfg = 'package_dirs: [force-app]\nbranches: { main: main, ingress: [main], protected: [main] }\nci_adapter: { name: none }\n';
	const {dir, remote, git} = makeRepoWithOrigin();
	writeRepoFile(dir, '.kerndx/config.yml', cfg);
	writeRepoFile(dir, 'force-app/leak.cls', `String s = '${AUTH_URL}';`);
	git([
		'add',
		'-A'
	]);
	git([
		'commit',
		'-qm',
		'c0 with secret'
	]);
	git([
		'push',
		'-q',
		'origin',
		'HEAD:refs/heads/main'
	]);
	git([
		'fetch',
		'-q',
		'origin'
	]);
	await inRepoWithRef(dir, 'main', async() =>
	{
		const code = await secretScanCommand({ci: true, stdinText: ''});
		assert.equal(code, 1, 'empty diff against the trusted base falls back to a full-tree scan and blocks');
	}, [remote]);
});
