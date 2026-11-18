// SPDX-License-Identifier: Apache-2.0
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {buildSitePlan, mirrorExcludedDocSetFromManifest, outlineSetting} from './prepare.mjs';

// Build a buildSitePlan input from a compact fixture, supplying empty defaults for the
// slug-lock axis so individual tests only set what they assert on.
function plan(docInputs, extra = {})
{
	return buildSitePlan({
		docInputs, readme: null, agents: null, mirrorExcluded: new Set(), locked: [], redirects: {}, searchCases: [], ...extra
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

test('an HTML anchor line that repeats the next heading\'s id is dropped, so the page has no duplicate id', () =>
{
	const raw = [
		'# Selectors',
		'',
		'See [it](#try-qry-builder-in-anonymous-apex).',
		'',
		'<a id="try-qry-builder-in-anonymous-apex"></a>',
		'### Try QRY_Builder in Anonymous Apex',
		'',
		'<a id="selectors"></a>You can mix them.',
		'',
		'    <a id="selectors"></a>',
		'',
		'<a id="not-a-heading"></a>',
		'',
		'```html',
		'<a id="selectors"></a>',
		'```',
		''
	].join('\n');
	const r = plan([{relPath: 'Guide.md', raw}]);
	const w = findWrite(r, 'guide.md');
	assert.ok(!w.content.includes('<a id="try-qry-builder-in-anonymous-apex"></a>'), 'the repeated id is dropped');
	assert.ok(w.content.includes('### Try QRY_Builder in Anonymous Apex'), 'the heading stays');
	assert.ok(w.content.includes('](#try-qry-builder-in-anonymous-apex)'), 'the link still points at the heading id');
	assert.ok(w.content.includes('<a id="selectors"></a>You can mix them.'), 'an anchor inside a paragraph stays, even with a heading id');
	assert.ok(w.content.includes('<a id="not-a-heading"></a>'), 'an anchor no heading repeats stays');
	assert.ok(w.content.includes('```html\n<a id="selectors"></a>\n```'), 'a line inside a fenced code block stays');
	assert.ok(w.content.includes('\n    <a id="selectors"></a>\n'), 'a line inside an indented code block stays');
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

// Ten guides with 10 to 19 entries in "On this page" (one main heading, the rest sub-headings).
// The smallest also has a fenced block of "## " lines: they are code, not headings, so counting
// them would wrongly make it the largest guide.
function guideFixtures()
{
	const guides = [];
	for(let i = 0; i < 10; i++)
	{
		const subHeadings = Array.from({length: 9 + i}, (_, n) => `### Part ${n}\n\nText.\n`).join('\n');
		const code = i === 0 ? '```bash\n' + '## not a heading\n'.repeat(50) + '```\n' : '';
		guides.push({relPath: `Topic ${i} - Guide.md`, raw: `# Topic ${i}\n\n## Main\n\n${subHeadings}\n${code}`});
	}
	return guides;
}

function frontmatterOf(result, outRel)
{
	const content = findWrite(result, outRel).content;
	return content.startsWith('---\n') ? content.slice(4, content.indexOf('\n---\n') + 1) : '';
}

test('outlineSetting opens by section for the eight largest guides and keeps one level for the rest', () =>
{
	assert.deepEqual(outlineSetting(40, 1), {outlineOpens: true});
	assert.deepEqual(outlineSetting(12, 8), {outlineOpens: true});
	assert.deepEqual(outlineSetting(12, 9), {outline: 2});
	assert.deepEqual(outlineSetting(0, 1), {outline: 2}, 'a guide with no headings has nothing to open');
});

test('the eight largest guides get outlineOpens', () =>
{
	const r = plan(guideFixtures());
	for(let i = 2; i < 10; i++)
	{
		const fm = frontmatterOf(r, `topic-${i}-guide.md`);
		assert.match(fm, /^outlineOpens: true$/m, `topic ${i} is one of the eight largest guides`);
		assert.doesNotMatch(fm, /^outline:/m);
	}
});

test('other guides get outline 2', () =>
{
	const r = plan(guideFixtures());
	for(const i of [0, 1])
	{
		const fm = frontmatterOf(r, `topic-${i}-guide.md`);
		assert.match(fm, /^outline: 2$/m, `topic ${i} is not one of the eight largest guides`);
		assert.doesNotMatch(fm, /outlineOpens/);
	}
});

test('a guide that sets its own outline keeps it', () =>
{
	const guides = guideFixtures();
	guides[0].raw = `---\noutline: deep\n---\n${guides[0].raw}`;
	const fm = frontmatterOf(plan(guides), 'topic-0-guide.md');
	assert.match(fm, /^outline: "?deep"?$/m);
	assert.doesNotMatch(fm, /^outline: 2$/m);
});

test('reference pages keep two levels', () =>
{
	const sections = Array.from({length: 60}, (_, n) => `## Method ${n}\n\n### Example ${n}\n`).join('\n');
	const r = plan([...guideFixtures(), {relPath: 'reference/apex/UTIL_SObject.md', raw: `# UTIL_SObject\n\n${sections}`}]);
	const fm = frontmatterOf(r, 'reference/apex/util-sobject.md');
	assert.doesNotMatch(fm, /outline/, 'a reference page gets no outline setting, so it shows main and sub-headings');
});

test('frozen trees are unchanged', () =>
{
	const r = plan(guideFixtures(), {frozen: true});
	for(let i = 0; i < 10; i++)
	{
		assert.doesNotMatch(frontmatterOf(r, `topic-${i}-guide.md`), /outline/, `frozen topic ${i} has no outline setting`);
	}
});

function findCopy(result, copyPath)
{
	return result.copies.find(c => c.copyPath === copyPath);
}

test('each latest page has a .md copy', () =>
{
	const r = plan([
		{
			relPath: 'Selectors - Guide.md',
			raw: '---\nnavOrder: 3\n---\n# Selectors\n\nA List<Id> and [DML](DML%20-%20Guide.md#save).\n\n<!-- internal -->\n<details><summary>More</summary>\n\nText.\n\n</details>\n'
		},
		{relPath: 'DML - Guide.md', raw: '# DML\n\n## Save\n\nBody.\n'},
		{relPath: 'reference/index.md', raw: '# API Reference\n'},
		{relPath: 'reference/apex/UTIL_SObject.md', raw: '---\ntitle: "UTIL_SObject"\n---\n\nNo heading here.\n'}
	], {agents: '# Agents\n\nOnboarding.\n', releaseNotes: [{relPath: 'Release Notes - Kern 1.1.md', raw: '# Kern 1.1 Release Notes\n\nNew.\n'}]});
	const selectors = findCopy(r, 'selectors-guide.md');
	assert.ok(selectors, 'a guide has a copy');
	assert.ok(!selectors.content.startsWith('---'), 'frontmatter is removed');
	assert.ok(selectors.content.includes('List<Id>'), 'angle brackets are as written');
	assert.ok(selectors.content.includes('](/dml-guide#save)'), 'links point at site pages');
	assert.ok(!selectors.content.includes('internal'), 'HTML comments are removed');
	assert.ok(!selectors.content.includes(':::'), 'no VitePress container blocks');
	assert.ok(findCopy(r, 'dml-guide.md'));
	assert.ok(findCopy(r, 'reference.md'), 'a directory index has its copy beside its folder');
	assert.ok(findCopy(r, 'reference/apex/util-sobject.md').content.startsWith('# UTIL_SObject\n'), 'a page with no heading gets its title');
	assert.ok(findCopy(r, 'agents.md'), 'the AGENTS page has a copy');
	assert.ok(findCopy(r, 'release-notes-kern-1-1.md'), 'a release note has a copy');
	assert.equal(r.copies.length, 6);
});

test('a copy shows the Learn it line that the page shows', () =>
{
	const r = plan([
		{relPath: 'Fast Start - Selectors.md', raw: '# Fast Start - Selectors\n\nBody.\n'},
		{relPath: 'Selectors - Guide.md', raw: '# Selectors\n\nBody.\n'},
		{relPath: 'reference/apex/QRY_Builder.md', raw: '# QRY_Builder\n\n**Class**\n\nBody.\n'}
	]);
	const page = findWrite(r, 'reference/apex/qry-builder.md').content;
	const copy = findCopy(r, 'reference/apex/qry-builder.md').content;
	assert.match(page, /Learn it:/);
	assert.match(copy, /Learn it:/);
});

test('frozen trees have none', () =>
{
	const r = plan([{relPath: 'DML - Guide.md', raw: '# DML\n'}], {frozen: true, agents: '# Agents\n'});
	assert.deepEqual(r.copies, []);
	assert.doesNotMatch(frontmatterOf(r, 'dml-guide.md'), /alternate/);
});

test('each page\'s head links its copy with rel alternate', () =>
{
	const r = plan([
		{relPath: 'DML - Guide.md', raw: '# DML\n'},
		{relPath: 'reference/apex/UTIL_SObject.md', raw: '# UTIL_SObject\n'}
	], {agents: '# Agents\n'});
	for(const [outRel, href] of [
		[
			'dml-guide.md',
			'/dml-guide.md'
		],
		[
			'reference/apex/util-sobject.md',
			'/reference/apex/util-sobject.md'
		],
		[
			'agents.md',
			'/agents.md'
		]
	])
	{
		const head = frontmatterOf(r, outRel).match(/^head: (.*)$/m);
		assert.ok(head, `${outRel} has a head setting`);
		assert.deepEqual(JSON.parse(head[1]), [['link', {rel: 'alternate', type: 'text/markdown', href}]]);
	}
});

test('the head link follows the deploy base', () =>
{
	const r = plan([{relPath: 'DML - Guide.md', raw: '# DML\n'}], {base: '/kern/'});
	assert.equal(JSON.parse(frontmatterOf(r, 'dml-guide.md').match(/^head: (.*)$/m)[1])[0][1].href, '/kern/dml-guide.md');
});

// A guide whose "Limits" and "Sizes" sub-headings moved to another page. The guide keeps the
// section's own heading as a stub that links to each moved heading, and lists the old ids.
function movedFixtures()
{
	const guide = [
		'---',
		'movedAnchors: {"limits": "/strategic-guide-overview#logging-limits", "sizes": "/strategic-guide-overview#logging-sizes"}',
		'---',
		'# Logging',
		'',
		'## Why choose this?',
		'',
		'Moved: [Limits](Strategic%20Guide%20-%20Overview.md#logging-limits) and',
		'[Sizes](Strategic%20Guide%20-%20Overview.md#logging-sizes).',
		'',
		'## Next section',
		''
	].join('\n');
	const comparisons = '# Overview\n\n## Logging {#logging}\n\n### Limits {#logging-limits}\n\n### Sizes {#logging-sizes}\n';
	const other = '# Other\n\nOld link: [limits](Logging%20-%20Guide.md#limits).\n';
	return [
		{relPath: 'Logging - Guide.md', raw: guide},
		{relPath: 'Strategic Guide - Overview.md', raw: comparisons},
		{relPath: 'Other - Guide.md', raw: other}
	];
}

test('movedAnchors adds each slug to the page\'s ids', () =>
{
	const r = plan(movedFixtures());
	const ids = r.idsBySlug.get('logging-guide');
	assert.ok(ids.has('limits') && ids.has('sizes'), `expected both moved ids, got ${[...ids].join(', ')}`);
	assert.deepEqual(JSON.parse(frontmatterOf(r, 'logging-guide.md').match(/^movedAnchors: (.*)$/m)[1]), {
		limits: '/strategic-guide-overview#logging-limits',
		sizes: '/strategic-guide-overview#logging-sizes'
	}, 'the page frontmatter carries the moved anchors as an object, for the theme script');
});

test('movedAnchors writes one id per slug inside the stub', () =>
{
	const content = findWrite(plan(movedFixtures()), 'logging-guide.md').content;
	const stub = content.slice(content.indexOf('## Why choose this?'), content.indexOf('## Next section'));
	for(const id of ['limits', 'sizes'])
	{
		assert.equal(content.split(`<span id="${id}"></span>`).length - 1, 1, `one element with id ${id} on the page`);
		assert.ok(stub.includes(`<span id="${id}"></span>`), `the element with id ${id} is inside the stub section`);
	}
});

test('a link to a moved slug passes the anchor pass', () =>
{
	const r = plan(movedFixtures());
	assert.deepEqual(r.unresolvedAnchors, []);
	assert.ok(findWrite(r, 'other-guide.md').content.includes('](/logging-guide#limits)'), 'the old link is kept as written');
});

test('moving the first of two same-text headings, with an explicit old id on the second, builds and both old ids resolve', () =>
{
	const guide = [
		'---',
		'movedAnchors: {"architecture": "/strategic-guide-overview#logging-architecture"}',
		'---',
		'# Logging',
		'',
		'## Why choose this?',
		'',
		'Moved: [Architecture](Strategic%20Guide%20-%20Overview.md#logging-architecture).',
		'',
		'## Design',
		'',
		'### Architecture {#architecture-1}',
		''
	].join('\n');
	const comparisons = '# Overview\n\n## Logging {#logging}\n\n### Architecture {#logging-architecture}\n';
	const other = '# Other\n\nFirst: [a](Logging%20-%20Guide.md#architecture). Second: [b](Logging%20-%20Guide.md#architecture-1).\n';
	const r = plan([
		{relPath: 'Logging - Guide.md', raw: guide},
		{relPath: 'Strategic Guide - Overview.md', raw: comparisons},
		{relPath: 'Other - Guide.md', raw: other}
	]);
	assert.deepEqual(r.unresolvedAnchors, []);
	const ids = r.idsBySlug.get('logging-guide');
	assert.ok(ids.has('architecture') && ids.has('architecture-1'), `expected both ids, got ${[...ids].join(', ')}`);
	assert.equal(findWrite(r, 'logging-guide.md').content.split('<span id="architecture"></span>').length - 1, 1, 'one stub element for the moved id');
});

// A guide whose "Limits" and "Sizes" sections were removed, with their old links sent to the front page.
function frontPageFixtures(target = '/')
{
	const guide = [
		'---',
		`movedAnchors: {"limits": "${target}", "sizes": "${target}"}`,
		'---',
		'# Logging',
		'',
		'## Who reads this',
		'',
		`Why use it: [Why KernDX](${target}).`,
		'',
		'## Next section',
		''
	].join('\n');
	return [{relPath: 'Logging - Guide.md', raw: guide}];
}

test('a removed section can send its old link to a whole page, with no heading id', () =>
{
	const r = plan(frontPageFixtures(), {readme: '---\nlayout: page\n---\n<KernLanding/>\n'});
	assert.deepEqual(r.unresolvedAnchors, [], 'Expected the front page to be accepted as the new place');
	const content = findWrite(r, 'logging-guide.md').content;
	for(const id of ['limits', 'sizes'])
	{
		assert.equal(content.split(`<span id="${id}"></span>`).length - 1, 1, `Expected one element with id ${id} on the page`);
	}
	assert.ok(content.includes('<span id="limits"></span><span id="sizes"></span>[Why KernDX](/)'), 'Expected both old ids in front of the one link to the front page');
});

test('a whole-page target that is no page on the site is reported', () =>
{
	const r = plan(frontPageFixtures('/no-such-page'), {readme: '---\nlayout: page\n---\n<KernLanding/>\n'});
	assert.ok(r.unresolvedAnchors.some(anchor => anchor.includes('/no-such-page is no heading on the site')), `Expected the missing page to be reported, got ${r.unresolvedAnchors.join('; ')}`);
});

test('a target heading id that the page does not have is reported', () =>
{
	const pages = [
		...frontPageFixtures('/strategic-guide-overview#no-such-id'),
		{relPath: 'Strategic Guide - Overview.md', raw: '# Overview\n\n## Logging\n'}
	];
	const r = plan(pages, {readme: '---\nlayout: page\n---\n<KernLanding/>\n'});
	assert.ok(r.unresolvedAnchors.some(anchor => anchor.includes('/strategic-guide-overview#no-such-id is no heading on the site')), `Expected the missing heading id to be reported, got ${r.unresolvedAnchors.join('; ')}`);
});

// A front page whose example blocks carry ids, as home.md's <CodeCompare id="..."> blocks do.
const LANDING_WITH_BLOCKS = '---\nlayout: page\n---\n<KernLanding>\n<FeatureGroup id="group-build-test-and-run" title="Build, test and run">\n<CodeCompare id="consoles" title="Consoles">\n</CodeCompare>\n</FeatureGroup>\n</KernLanding>\n';

test('a moved heading can be sent to an example block on the front page, through the guide\'s link to that page', () =>
{
	const [fixture] = frontPageFixtures('/');
	const guide = {...fixture, raw: fixture.raw.replace('movedAnchors: {"limits": "/", "sizes": "/"}', 'movedAnchors: {"limits": "/#consoles", "sizes": "/#consoles"}')};
	const r = plan([guide], {readme: LANDING_WITH_BLOCKS});
	assert.deepEqual(r.unresolvedAnchors, [], 'Expected the front page block id to be accepted as the new place');
	assert.ok(r.idsBySlug.get('').has('consoles') && r.idsBySlug.get('').has('group-build-test-and-run'), `Expected the front page ids, got ${[...r.idsBySlug.get('')].join(', ')}`);
	const content = findWrite(r, 'logging-guide.md').content;
	assert.ok(content.includes('<span id="limits"></span><span id="sizes"></span>[Why KernDX](/)'), 'Expected both old ids in front of the guide\'s one link to the front page');
});

test('a stub that links only to the page of a heading on another guide, not to the heading, is reported', () =>
{
	const guide = [
		'---',
		'movedAnchors: {"limits": "/strategic-guide-overview#logging-limits"}',
		'---',
		'# Logging',
		'',
		'## Why choose this?',
		'',
		'Moved: [Overview](Strategic%20Guide%20-%20Overview.md).',
		''
	].join('\n');
	const overview = '# Overview\n\n## Logging {#logging}\n\n### Limits {#logging-limits}\n';
	const r = plan([{relPath: 'Logging - Guide.md', raw: guide}, {relPath: 'Strategic Guide - Overview.md', raw: overview}]);
	assert.ok(r.unresolvedAnchors.some(anchor => anchor.includes('the stub has no link to /strategic-guide-overview#logging-limits')),
		`Expected the stub with no exact link to be reported, got ${r.unresolvedAnchors.join('; ')}`);
});

test('a front page block id that the front page does not have is reported', () =>
{
	const r = plan(frontPageFixtures('/#no-such-block'), {readme: LANDING_WITH_BLOCKS});
	assert.ok(r.unresolvedAnchors.some(anchor => anchor.includes('/#no-such-block is no heading on the site')), `Expected the missing block id to be reported, got ${r.unresolvedAnchors.join('; ')}`);
});

test('a link on the front page to one of its own block ids is kept', () =>
{
	const readme = LANDING_WITH_BLOCKS.replace('<CodeCompare id="consoles" title="Consoles">', '<CodeCompare id="consoles" title="Consoles" link="/#consoles">');
	const r = plan([], {readme});
	assert.ok(findWrite(r, 'index.md').content.includes('link="/#consoles"'), 'Expected the link to the block to stay as written');
});

// The front page's own sections (KernLanding.vue), such as the list of features a group's back link opens.
const LANDING_COMPONENT = '<script setup>\nconst label = \'id="not-in-the-template"\';\n</script>\n<template>\n<section id="jump-to-a-feature" :id="dynamic">\n<h2 class="kl-eyebrow" id="whats-in-the-box">What you get</h2>\n<span data-spec-id="hero"></span>\n</section>\n</template>\n';

test('a moved heading can be sent to a section of the front page component', () =>
{
	const [fixture] = frontPageFixtures('/');
	const guide = {...fixture, raw: fixture.raw.replace('movedAnchors: {"limits": "/", "sizes": "/"}', 'movedAnchors: {"limits": "/#jump-to-a-feature", "sizes": "/#whats-in-the-box"}')};
	const r = plan([guide], {readme: LANDING_WITH_BLOCKS, landingComponent: LANDING_COMPONENT});
	assert.deepEqual(r.unresolvedAnchors, [], 'Expected the front page component\'s section ids to be accepted as new places');
	const ids = r.idsBySlug.get('');
	assert.ok(ids.has('jump-to-a-feature') && ids.has('whats-in-the-box') && ids.has('consoles'), `Expected the component and home.md ids, got ${[...ids].join(', ')}`);
	assert.ok(!ids.has('not-in-the-template') && !ids.has('hero') && !ids.has('dynamic'), `Expected only plain id attributes in the template, got ${[...ids].join(', ')}`);
});

test('a link from a guide to a section of the front page component is not reported', () =>
{
	const guide = {relPath: 'Logging - Guide.md', raw: '# Logging\n\nSee [every feature](/#jump-to-a-feature).\n'};
	const without = plan([guide], {readme: LANDING_WITH_BLOCKS});
	assert.ok(without.unresolvedAnchors.some(anchor => anchor.includes('jump-to-a-feature')), `Expected the link to be reported without the component, got ${without.unresolvedAnchors.join('; ')}`);
	const r = plan([guide], {readme: LANDING_WITH_BLOCKS, landingComponent: LANDING_COMPONENT});
	assert.deepEqual(r.unresolvedAnchors, [], 'Expected the link to the component section to resolve');
});

test('a frozen tree does not take section ids from the front page component', () =>
{
	const r = plan([], {readme: LANDING_WITH_BLOCKS, landingComponent: LANDING_COMPONENT, frozen: true});
	assert.ok(!r.idsBySlug.get('').has('jump-to-a-feature'), 'Expected an older version\'s front page to keep only its own ids');
});

// A search word given to a heading must not already be a heading word anywhere on the site, the
// AGENTS page and the release notes included.
test('a search word already in a heading of the AGENTS page or a release note is reported', () =>
{
	const guide = '---\nsearchTerms: {"limits": ["onboarding"], "sizes": ["hotfix"]}\n---\n# Logging\n\n## Limits\n\n## Sizes\n';
	const cases = [
		{query: 'onboarding', expected: ['Logging > Limits']},
		{query: 'hotfix', expected: ['Logging > Sizes']}
	];
	const r = plan([{relPath: 'Logging - Guide.md', raw: guide}], {
		agents: '# Agents\n\n## Onboarding\n',
		releaseNotes: [{relPath: 'Release Notes - Kern 1.1.md', raw: '# Kern 1.1 Release Notes\n\n## Hotfix\n'}],
		searchCases: cases
	});
	assert.ok(r.searchTermProblems.some(problem => problem.includes('"onboarding" is already in the heading Agents > Onboarding')), r.searchTermProblems.join('; '));
	assert.ok(r.searchTermProblems.some(problem => problem.includes('"hotfix" is already in the heading Kern 1.1 Release Notes > Hotfix')), r.searchTermProblems.join('; '));
});

test('a frozen page ignores movedAnchors', () =>
{
	const r = plan(movedFixtures(), {frozen: true});
	const write = findWrite(r, 'logging-guide.md');
	assert.ok(!r.idsBySlug.get('logging-guide').has('limits'), 'no moved id on a frozen page');
	assert.doesNotMatch(write.content, /<span id=|movedAnchors/, 'no element and no frontmatter for moved anchors');
	assert.ok(r.unresolvedAnchors.some(anchor => anchor.includes('#limits')), 'an old link into a frozen page is checked against its headings only');
});

test('the landing page has no head link and no copy', () =>
{
	const r = plan([], {readme: '---\nlayout: page\n---\n<KernLanding/>\n'});
	assert.doesNotMatch(findWrite(r, 'index.md').content, /alternate/);
	assert.deepEqual(r.copies, []);
});

// One page with extra search words for its "Query Records" section, and the search case that
// searches for them and names that section.
const SEARCH_TERMS_PAGE = '---\nsearchTerms: {"query-records": ["SOQL query"]}\n---\n# Fast Start - Selectors\n\n## Query Records\n\nText.\n';
const SEARCH_TERMS_CASES = [{group: 'selectors', query: 'soql query', kind: 'vocabulary', expected: ['Fast Start - Selectors > Query Records'], accepted: []}];

test('a bad searchTerms key gives a searchTermProblems entry', () =>
{
	const good = plan([{relPath: 'Fast Start - Selectors.md', raw: SEARCH_TERMS_PAGE}], {searchCases: SEARCH_TERMS_CASES});
	assert.deepEqual(good.searchTermProblems, [], 'Expected no problem when the key names a heading on the page');
	const raw = SEARCH_TERMS_PAGE.replace('"query-records"', '"no-such-heading"');
	const bad = plan([{relPath: 'Fast Start - Selectors.md', raw}], {searchCases: SEARCH_TERMS_CASES});
	assert.equal(bad.searchTermProblems.length, 1, 'Expected one problem for the key that names no heading');
	assert.match(bad.searchTermProblems[0], /no-such-heading/);
});

test('the prepared frontmatter keeps the searchTerms line', () =>
{
	const r = plan([{relPath: 'Fast Start - Selectors.md', raw: SEARCH_TERMS_PAGE}], {searchCases: SEARCH_TERMS_CASES});
	assert.match(frontmatterOf(r, 'fast-start-selectors.md'), /^searchTerms: \{"query-records":\["SOQL query"\]\}$/m);
});

test('a frozen build drops searchTerms', () =>
{
	const r = plan([{relPath: 'Fast Start - Selectors.md', raw: SEARCH_TERMS_PAGE}], {frozen: true, searchCases: null});
	assert.doesNotMatch(findWrite(r, 'fast-start-selectors.md').content, /searchTerms/);
	assert.deepEqual(r.searchTermProblems, [], 'Expected a frozen build to skip the search words check');
});

test('a normal build without a case list fails', () =>
{
	assert.throws(() => plan([{relPath: 'Fast Start - Selectors.md', raw: SEARCH_TERMS_PAGE}], {searchCases: null}), /search-cases\.json/);
	assert.throws(() => plan([{relPath: 'Fast Start - Selectors.md', raw: SEARCH_TERMS_PAGE}], {searchCases: undefined}), /search-cases\.json/);
});
