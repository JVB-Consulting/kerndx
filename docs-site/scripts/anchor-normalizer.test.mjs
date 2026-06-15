// SPDX-License-Identifier: BUSL-1.1
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {slugifyHeading, extractHeadingIds, rewriteAnchors} from './anchor-normalizer.mjs';

// slugifyHeading must be byte-for-byte identical to VitePress' own slugify (the
// algorithm baked into @mdit-vue/shared and shipped inside vitepress' bundle).
// These expectations were captured from a real `vitepress build` of this corpus.
test('slugifyHeading reproduces VitePress heading ids exactly', () =>
{
	assert.equal(slugifyHeading('Url__c'), 'url-c');
	assert.equal(slugifyHeading('CalloutDurationMs__c'), 'calloutdurationms-c');
	assert.equal(slugifyHeading('1. ApiCall__c (Custom Object)'), '_1-apicall-c-custom-object');
	assert.equal(slugifyHeading('Type Resolution: UTIL_TypeResolver'), 'type-resolution-util-typeresolver');
	assert.equal(slugifyHeading('Quick Navigation'), 'quick-navigation');
	// leading digit gets the `_` prefix; runs of specials collapse to one dash
	assert.equal(slugifyHeading('5. Named Credentials'), '_5-named-credentials');
	// an em-dash is NOT in VitePress' special set, so it survives in the id (verified
	// against a real build: `## CRITICAL — Namespace Prefix Rule`)
	assert.equal(slugifyHeading('CRITICAL — Namespace Prefix Rule'), 'critical-—-namespace-prefix-rule');
});

test('extractHeadingIds returns ids in document order, all levels', () =>
{
	const md = '# Title\n\nintro\n\n## Section One\n\n### Url__c\n\n#### Deep\n';
	assert.deepEqual(extractHeadingIds(md), [
		'title',
		'section-one',
		'url-c',
		'deep'
	]);
});

test('extractHeadingIds strips inline markup like markdown-it-anchor', () =>
{
	// link in heading -> link text only; inline code -> its content; bold markers dropped
	const md = '### 1. [ApiCall__c](/reference/objects/apicall-c) (Custom Object)\n\n## `UTIL_HttpClient`\n\n## **Bold** Heading\n';
	assert.deepEqual(extractHeadingIds(md), [
		'_1-apicall-c-custom-object',
		'util-httpclient',
		'bold-heading'
	]);
});

test('extractHeadingIds dedups repeated slugs the way markdown-it-anchor does', () =>
{
	const md = '## Overview\n\n## Overview\n\n## Overview\n';
	assert.deepEqual(extractHeadingIds(md), [
		'overview',
		'overview-1',
		'overview-2'
	]);
});

test('extractHeadingIds re-checks suffixed collisions like markdown-it-anchor', () =>
{
	// A naive per-slug occurrence counter diverges from markdown-it-anchor when an authored
	// `-1` slug collides with a generated one. markdown-it-anchor keeps a used-id set and
	// increments the suffix until the candidate is free, so it never emits a duplicate id.
	// `## Overview` / `## Overview` / `## Overview 1` →
	//   overview, overview-1 (generated), overview-1 collides → overview-1-1.
	const md = '## Overview\n\n## Overview\n\n## Overview 1\n';
	assert.deepEqual(extractHeadingIds(md), [
		'overview',
		'overview-1',
		'overview-1-1'
	]);

	// An authored `## X 1` heading taken BEFORE the generated suffix would land there pushes
	// the generated suffix past it: x, x-1 (authored, taken), x → x-2 not x-1.
	const md2 = '## X\n\n## X 1\n\n## X\n\n## X\n';
	assert.deepEqual(extractHeadingIds(md2), [
		'x',
		'x-1',
		'x-2',
		'x-3'
	]);
});

test('extractHeadingIds captures setext (underline-style) headings', () =>
{
	// `===` underlines an H1, `---` underlines an H2; both contribute ids the same way ATX
	// headings do, including dedup and inline-markup stripping.
	const md = 'Title One\n=========\n\nintro\n\nSection Two\n-----------\n\n## ATX Three\n\nUrl__c\n======\n';
	assert.deepEqual(extractHeadingIds(md), [
		'title-one',
		'section-two',
		'atx-three',
		'url-c'
	]);
});

test('extractHeadingIds does not treat a thematic break (HR) as a setext heading', () =>
{
	// A `---`/`===` line is only a setext underline when a non-blank paragraph line precedes
	// it with no blank line between. A `---` after a blank line is a horizontal rule, not a
	// heading — it must contribute no id.
	const md = '## Real\n\nsome paragraph text\n\n---\n\n## Also Real\n';
	assert.deepEqual(extractHeadingIds(md), [
		'real',
		'also-real'
	]);
});

test('extractHeadingIds skips setext underlines inside fenced code blocks', () =>
{
	const md = '## Real\n\n```\nNot A Heading\n=============\n```\n\n## Also Real\n';
	assert.deepEqual(extractHeadingIds(md), [
		'real',
		'also-real'
	]);
});

test('extractHeadingIds ignores # lines inside fenced code blocks', () =>
{
	const md = '## Real\n\n```bash\n# Install\nnpm ci\n```\n\n~~~\n### not a heading\n~~~\n\n## Also Real\n';
	assert.deepEqual(extractHeadingIds(md), [
		'real',
		'also-real'
	]);
});

test('rewriteAnchors fixes a same-page GitHub-style fragment to the VitePress id', () =>
{
	const ids = new Map([
		[
			'',
			new Set([
				'url-c',
				'calloutdurationms-c'
			])
		]
	]);
	const body = 'See [Url__c](#url__c) and [dur](#calloutdurationms__c).';
	const {content, unresolved} = rewriteAnchors(body, {currentSlug: '', idsBySlug: ids});
	assert.ok(content.includes('](#url-c)'));
	assert.ok(content.includes('](#calloutdurationms-c)'));
	assert.deepEqual(unresolved, []);
});

test('rewriteAnchors leaves an already-correct fragment untouched', () =>
{
	const ids = new Map([
		[
			'',
			new Set(['overview'])
		]
	]);
	const {content, unresolved} = rewriteAnchors('[x](#overview)', {currentSlug: '', idsBySlug: ids});
	assert.equal(content, '[x](#overview)');
	assert.deepEqual(unresolved, []);
});

test('rewriteAnchors fixes a cross-page fragment against the target page ids', () =>
{
	const ids = new Map([
		[
			'web-services-guide',
			new Set()
		],
		[
			'reference/objects/apicall-c',
			new Set(['url-c'])
		]
	]);
	const body = 'see [u](/reference/objects/apicall-c#url__c)';
	const {content} = rewriteAnchors(body, {currentSlug: 'web-services-guide', idsBySlug: ids});
	assert.ok(content.includes('](/reference/objects/apicall-c#url-c)'));
});

test('rewriteAnchors resolves a trailing-slash index target and the home root', () =>
{
	const ids = new Map([
		[
			'reference/apex',
			new Set(['classes'])
		],
		[
			'',
			new Set(['kerndx'])
		]
	]);
	const a = rewriteAnchors('[x](/reference/apex/#classes)', {currentSlug: 'x', idsBySlug: ids});
	assert.ok(a.content.includes('](/reference/apex/#classes)'));
	const b = rewriteAnchors('[home](/#kerndx)', {currentSlug: 'x', idsBySlug: ids});
	assert.ok(b.content.includes('](/#kerndx)'));
});

test('rewriteAnchors loose-matches when a kept char (em-dash) defeats slugify', () =>
{
	// real heading "CRITICAL — Namespace Prefix Rule" → id keeps the em-dash; the authored
	// GitHub-style anchor stripped it to a double dash. Neither equality nor re-slugify
	// matches, but the punctuation-agnostic loose key does.
	const ids = new Map([
		[
			'',
			new Set(['critical-—-namespace-prefix-rule'])
		]
	]);
	const {content, unresolved} = rewriteAnchors('[x](#critical--namespace-prefix-rule)', {currentSlug: '', idsBySlug: ids});
	assert.ok(content.includes('](#critical-—-namespace-prefix-rule)'));
	assert.deepEqual(unresolved, []);
});

test('rewriteAnchors tight-matches an apostrophe, a dotted number, and a dotted member', () =>
{
	// VitePress turns the dropped char into a separator where GitHub elided it entirely.
	const ids = new Map([
		[
			'',
			new Set([
				'what-you-ll-do',
				'_2-1-register-namespace',
				'if-trigger-beforeinsert'
			])
		]
	]);
	const a = rewriteAnchors('[x](#what-youll-do)', {currentSlug: '', idsBySlug: ids});
	assert.ok(a.content.includes('](#what-you-ll-do)'));
	const b = rewriteAnchors('[x](#21-register-namespace)', {currentSlug: '', idsBySlug: ids});
	assert.ok(b.content.includes('](#_2-1-register-namespace)'));
	const c = rewriteAnchors('[x](#if_triggerbeforeinsert)', {currentSlug: '', idsBySlug: ids});
	assert.ok(c.content.includes('](#if-trigger-beforeinsert)'));
});

test('rewriteAnchors will not guess when a loose key is ambiguous', () =>
{
	// "Foo — Bar" (em-dash) and "Foo – Bar" (en-dash) both keep their dash in the real id,
	// so neither equals slugify(#foo--bar); both reduce to loose key `foo-bar`. Ambiguous —
	// we report rather than guess which heading was meant.
	const ids = new Map([
		[
			'',
			new Set([
				'foo-—-bar',
				'foo-–-bar'
			])
		]
	]);
	const {content, unresolved} = rewriteAnchors('[x](#foo--bar)', {currentSlug: '', idsBySlug: ids});
	assert.equal(content, '[x](#foo--bar)');
	assert.equal(unresolved.length, 1);
});

test('rewriteAnchors reports a fragment that matches no heading on the target', () =>
{
	const ids = new Map([
		[
			'',
			new Set(['real-heading'])
		]
	]);
	const {content, unresolved} = rewriteAnchors('[x](#does-not-exist)', {currentSlug: '', idsBySlug: ids});
	assert.equal(content, '[x](#does-not-exist)');
	assert.equal(unresolved.length, 1);
	assert.match(unresolved[0], /does-not-exist/);
});

test('rewriteAnchors ignores empty and bare-hash fragments', () =>
{
	const ids = new Map([
		[
			'',
			new Set(['x'])
		]
	]);
	const {content, unresolved} = rewriteAnchors('[a](#) text', {currentSlug: '', idsBySlug: ids});
	assert.equal(content, '[a](#) text');
	assert.deepEqual(unresolved, []);
});

test('rewriteAnchors rewrites reference-style link definitions', () =>
{
	const ids = new Map([
		[
			'',
			new Set(['url-c'])
		]
	]);
	const body = 'Use [the field][f].\n\n[f]: #url__c';
	const {content} = rewriteAnchors(body, {currentSlug: '', idsBySlug: ids});
	assert.ok(content.includes('[f]: #url-c'));
});
