// SPDX-License-Identifier: BUSL-1.1
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {buildSitePlan, mirrorExcludedDocSetFromManifest} from './prepare.mjs';

// Build a buildSitePlan input from a compact fixture, supplying empty defaults for the
// slug-lock axis so individual tests only set what they assert on.
function plan(docInputs, extra = {})
{
	return buildSitePlan({
		docInputs, readme: null, agents: null, mirrorExcluded: new Set(), locked: [], redirects: {}, ...extra
	});
}

function findWrite(result, outRel)
{
	return result.writes.find(w => w.outRel === outRel);
}

test('a top-level guide materializes to <slug>.md', () =>
{
	const r = plan([{relPath: 'Fast Start - DML.md', raw: '# DML\n\nBody.\n'}]);
	const w = findWrite(r, 'fast-start-dml.md');
	assert.ok(w, 'expected a writes entry at fast-start-dml.md');
	assert.ok(w.content.includes('# DML'));
	const page = r.pages.find(p => p.relPath === 'Fast Start - DML.md');
	assert.equal(page.slug, 'fast-start-dml');
});

test('a directory index writes to <slug>/index.md and a nested ref doc to <slug>.md', () =>
{
	const r = plan([
		{relPath: 'reference/index.md', raw: '# API Reference\n'},
		{relPath: 'reference/apex/UTIL_SObject.md', raw: '# UTIL_SObject\n'}
	]);
	assert.ok(findWrite(r, 'reference/index.md'), 'index.md becomes a directory index');
	assert.ok(findWrite(r, 'reference/apex/util-sobject.md'), 'nested ref doc keeps its slug path');
});

test('a mirror-excluded doc is dropped from writes and pages', () =>
{
	const r = plan([
		{relPath: 'Fast Start - DML.md', raw: '# DML\n'},
		{relPath: 'Strategic Guide - Internal.md', raw: '# Secret\n'}
	], {mirrorExcluded: new Set(['Strategic Guide - Internal.md'])});
	assert.ok(findWrite(r, 'fast-start-dml.md'), 'the included doc is still written');
	assert.equal(findWrite(r, 'strategic-guide-internal.md'), undefined, 'excluded doc not written');
	assert.equal(r.pages.find(p => p.relPath === 'Strategic Guide - Internal.md'), undefined, 'excluded doc not a page');
});

test('a link to a non-existent .md target is collected as unresolved', () =>
{
	const r = plan([{relPath: 'Guide.md', raw: 'See [gone](Does%20Not%20Exist.md).\n'}]);
	assert.equal(r.unresolved.length, 1);
	assert.ok(r.unresolved[0].includes('Does%20Not%20Exist.md'));
	assert.ok(r.unresolved[0].startsWith('Guide.md → '));
});

test('details transform and angle escaping are applied to the written body', () =>
{
	const raw = '# T\n\n<details>\n<summary>More</summary>\n\nInner text.\n\n</details>\n\nReturns a List<SObject> of records.\n';
	const r = plan([{relPath: 'Guide.md', raw}]);
	const w = findWrite(r, 'guide.md');
	assert.ok(w.content.includes('::: details More'), 'transformDetails applied');
	assert.ok(w.content.includes('&lt;SObject&gt;'), 'escapeAngles applied to Apex generic in prose');
});

test('README becomes the home index and AGENTS becomes /agents with a page record', () =>
{
	const r = plan([], {readme: '# KernDX\n\nHome body.\n', agents: '# Agents\n\nAgent onboarding.\n'});
	const home = findWrite(r, 'index.md');
	assert.ok(home, 'README writes src/index.md');
	assert.ok(home.content.includes('Home body.'));
	const agentsWrite = findWrite(r, 'agents.md');
	assert.ok(agentsWrite, 'AGENTS writes src/agents.md');
	const agentsPage = r.pages.find(p => p.relPath === 'AGENTS.md');
	assert.ok(agentsPage, 'an AGENTS page record exists');
	assert.equal(agentsPage.slug, 'agents');
});

test('slug-lock: a locked slug absent from current with no redirect is removedWithoutRedirect', () =>
{
	const r = plan([{relPath: 'Kept.md', raw: '# Kept\n'}], {
		locked: [
			'kept',
			'dropped'
		]
	});
	assert.deepEqual(r.slugDiff.removedWithoutRedirect, ['dropped']);
});

test('slug-lock: a redirect for the removed slug clears removedWithoutRedirect', () =>
{
	const r = plan([{relPath: 'Kept.md', raw: '# Kept\n'}], {
		locked: [
			'kept',
			'dropped'
		], redirects: {dropped: 'kept'}
	});
	assert.deepEqual(r.slugDiff.removedWithoutRedirect, []);
});

test('sidebar is a non-empty array grouping the fixture pages', () =>
{
	const r = plan([
		{relPath: 'Fast Start - DML.md', raw: '# DML\n'},
		{relPath: 'reference/apex/UTIL_SObject.md', raw: '# UTIL_SObject\n'}
	]);
	assert.ok(Array.isArray(r.sidebar));
	assert.ok(r.sidebar.length > 0);
	const flat = JSON.stringify(r.sidebar);
	assert.ok(flat.includes('Fast Starts'), 'Fast Start page is grouped under Fast Starts');
	assert.ok(flat.includes('API Reference'), 'reference page is grouped under API Reference');
});

test('in-page anchors are reconciled to the VitePress heading id (same page)', () =>
{
	// authored GitHub-style `#url__c`; the real heading id is `url-c`
	const raw = '# Obj\n\nSee [Url](#url__c).\n\n### Url__c\n\nfield.\n';
	const r = plan([{relPath: 'reference/objects/ApiCall__c.md', raw}]);
	const w = findWrite(r, 'reference/objects/apicall-c.md');
	assert.ok(w.content.includes('](#url-c)'), 'fragment rewritten to the real id');
	assert.ok(!w.content.includes('#url__c'), 'no broken __c fragment remains');
	assert.deepEqual(r.unresolvedAnchors, []);
});

test('an in-page anchor with no matching heading is reported in unresolvedAnchors', () =>
{
	const r = plan([{relPath: 'Guide.md', raw: '# T\n\n[x](#does-not-exist).\n\n## Real\n'}]);
	assert.equal(r.unresolvedAnchors.length, 1);
	assert.ok(r.unresolvedAnchors[0].startsWith('guide.md → '));
	assert.ok(r.unresolvedAnchors[0].includes('does-not-exist'));
});

test('release notes materialize under a "Release Notes" group, newest first, and the home links to them', () =>
{
	const r = plan([], {
		readme: '# KernDX\n\nSee the [latest notes](./release-notes/Release%20Notes%20-%20Kern%201.1.md).\n', releaseNotes: [
			{relPath: 'Release Notes - Kern 1.0.md', raw: '# Kern 1.0 — Feature Reference\n\nOld.\n'},
			{relPath: 'Release Notes - Kern 1.1.md', raw: '# Kern 1.1 Release Notes\n\nNew.\n'}
		]
	});
	assert.ok(findWrite(r, 'release-notes-kern-1-1.md'), '1.1 note materialized');
	assert.ok(findWrite(r, 'release-notes-kern-1-0.md'), '1.0 note materialized');
	// home link resolves to the site slug, not a GitHub blob
	assert.ok(findWrite(r, 'index.md').content.includes('](/release-notes-kern-1-1)'));
	// the section exists and orders 1.1 before 1.0
	const rn = r.sidebar.find(g => g.text === 'Release Notes');
	assert.ok(rn, 'a Release Notes sidebar group exists');
	assert.deepEqual(rn.items.map(i => i.link), [
		'/release-notes-kern-1-1',
		'/release-notes-kern-1-0'
	]);
});

test('mirrorExcludedDocSetFromManifest keeps only concrete docs/*.md entries', () =>
{
	const set = mirrorExcludedDocSetFromManifest({
		blacklist_assertions: [
			'docs/Strategic Guide - Internal.md',
			'docs/*.draft.md',
			'release-testing/x.cls',
			'docs/sub/Thing.md'
		]
	});
	assert.ok(set.has('Strategic Guide - Internal.md'));
	assert.ok(set.has('sub/Thing.md'));
	assert.ok(!set.has('*.draft.md'), 'wildcard entries are ignored');
	assert.equal(set.size, 2);
});

test('mirrorExcludedDocSetFromManifest degrades gracefully on a malformed manifest', () =>
{
	// A non-array blacklist_assertions must not throw (TypeError: not iterable).
	assert.deepEqual(mirrorExcludedDocSetFromManifest({blacklist_assertions: {}}), new Set());
	assert.deepEqual(mirrorExcludedDocSetFromManifest({blacklist_assertions: 42}), new Set());
	// A non-string entry must not throw (TypeError: entry.startsWith is not a function).
	const set = mirrorExcludedDocSetFromManifest({
		blacklist_assertions: [
			null,
			42,
			{},
			'docs/Real.md'
		]
	});
	assert.ok(set.has('Real.md'));
	assert.equal(set.size, 1);
	// A missing/empty manifest still yields an empty set.
	assert.deepEqual(mirrorExcludedDocSetFromManifest(null), new Set());
	assert.deepEqual(mirrorExcludedDocSetFromManifest({}), new Set());
});

test('a draft:true page is excluded from the sidebar AND not materialized into src/', () =>
{
	const r = plan([
		{relPath: 'Fast Start - DML.md', raw: '# DML\n\nBody.\n'},
		{relPath: 'Work In Progress.md', raw: '---\ndraft: true\n---\n# WIP\n\nNot ready.\n'}
	]);
	assert.ok(findWrite(r, 'fast-start-dml.md'), 'the published doc is still written');
	assert.equal(findWrite(r, 'work-in-progress.md'), undefined, 'draft doc is not materialized into src/');
	assert.equal(r.pages.find(p => p.relPath === 'Work In Progress.md'), undefined, 'draft doc is not a page');
	const flat = JSON.stringify(r.sidebar);
	assert.ok(!flat.includes('WIP'), 'draft doc is absent from the sidebar');
});

test('placeholder Foobar reference docs are not materialized as public pages', () =>
{
	const r = plan([
		{relPath: 'reference/apex/UTIL_SObject.md', raw: '# UTIL_SObject\n'},
		{relPath: 'reference/apex/SEL_Foobar.md', raw: '# SEL_Foobar\n'},
		{relPath: 'reference/apex/TRG_Foobar.md', raw: '# TRG_Foobar\n'},
		{relPath: 'reference/apex/UTIL_FormulaContext.FoobarContext.md', raw: '# FoobarContext\n'}
	]);
	assert.ok(findWrite(r, 'reference/apex/util-sobject.md'), 'a real reference doc still ships');
	assert.equal(findWrite(r, 'reference/apex/sel-foobar.md'), undefined, 'SEL_Foobar placeholder dropped');
	assert.equal(findWrite(r, 'reference/apex/trg-foobar.md'), undefined, 'TRG_Foobar placeholder dropped');
	assert.equal(r.pages.find(p => /Foobar/i.test(p.relPath)), undefined, 'no Foobar placeholder is a page');
});

test('a Foobar name outside reference/ is NOT skipped (only reference docs are placeholders)', () =>
{
	const r = plan([{relPath: 'Foobar Guide.md', raw: '# Foobar Guide\n'}]);
	assert.ok(findWrite(r, 'foobar-guide.md'), 'a non-reference Foobar doc still ships');
});

test('a cross-link to a skipped Foobar page is neutralized to plain text, not a hard-fail', () =>
{
	// A real reference page links to the placeholder; dropping the placeholder must NOT
	// strand the link as unresolved (it is an intentional skip, not a typo).
	const r = plan([
		{relPath: 'reference/apex/SEL_Base.md', raw: '# SEL_Base\n\nTypes: [SEL_ApiCall](SEL_ApiCall.md), [SEL_Foobar](SEL_Foobar.md).\n'},
		{relPath: 'reference/apex/SEL_ApiCall.md', raw: '# SEL_ApiCall\n'},
		{relPath: 'reference/apex/SEL_Foobar.md', raw: '# SEL_Foobar\n'}
	]);
	assert.deepEqual(r.unresolved, [], 'the dropped-placeholder link does not fail the build');
	const w = findWrite(r, 'reference/apex/sel-base.md');
	assert.ok(w.content.includes('](/reference/apex/sel-apicall)'), 'the real sibling link survives');
	assert.ok(!/\]\(\S*Foobar/i.test(w.content) && !w.content.includes('/sel-foobar'), 'no Foobar link remains');
	assert.ok(/Types: \[SEL_ApiCall\]\(\/reference\/apex\/sel-apicall\), SEL_Foobar\./.test(w.content), 'Foobar reduced to plain text in place');
});

test('a real doc that slugs to the home slug ("") collides instead of clobbering the home page', () =>
{
	// index.md at the docs root slugs to '' — same as the injected README home slug.
	assert.throws(
		() => plan([{relPath: 'index.md', raw: '# Root\n'}], {readme: '# Home\n'}),
		/collision/i,
		'a docs page slugging to the home slug must be rejected, not silently clobber the home'
	);
});

test('a real doc that slugs to "agents" collides instead of clobbering the /agents page', () =>
{
	assert.throws(
		() => plan([{relPath: 'agents.md', raw: '# Agents Doc\n'}], {agents: '# AGENTS\n'}),
		/collision/i,
		'a docs page slugging to "agents" must be rejected, not silently clobber the /agents page'
	);
});

test('a broken docs link in the README home body fails the build via unresolved', () =>
{
	const r = plan([], {readme: '# Home\n\nSee [the guide](./docs/Nonexistent%20Guide.md).\n'});
	assert.ok(r.unresolved.length >= 1, 'a broken home->docs link is collected as unresolved');
	assert.ok(r.unresolved.some(u => /Nonexistent/.test(u)), 'the broken target is named');
});

test('a broken docs link in AGENTS and a release note also fail via unresolved', () =>
{
	const r = plan([], {
		agents: '# AGENTS\n\nSee [x](./docs/Missing%20Agents%20Doc.md).\n',
		releaseNotes: [
			{relPath: 'Release Notes - Kern 1.1.md', raw: '# Kern 1.1\n\nSee [y](../docs/Missing%20Release%20Doc.md).\n'}
		]
	});
	assert.ok(r.unresolved.some(u => /Missing Agents Doc|Missing%20Agents%20Doc/.test(u)), 'broken AGENTS link reported');
	assert.ok(r.unresolved.some(u => /Missing Release Doc|Missing%20Release%20Doc/.test(u)), 'broken release-note link reported');
});

test('a resolvable docs link in the README home body does NOT produce an unresolved entry', () =>
{
	const r = plan([{relPath: 'Fast Start - DML.md', raw: '# DML\n'}], {
		readme: '# Home\n\nSee [the guide](./docs/Fast%20Start%20-%20DML.md).\n'
	});
	assert.equal(r.unresolved.length, 0, 'a valid home->docs link is not flagged');
	assert.ok(findWrite(r, 'index.md').content.includes('](/fast-start-dml)'), 'the link is rewritten to the site slug');
});
