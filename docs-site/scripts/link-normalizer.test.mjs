// SPDX-License-Identifier: BUSL-1.1
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {normalizeLink, rewriteLinks} from './link-normalizer.mjs';

const slugMap = new Map([
	[
		'Fast Start - Feature Flags.md',
		'fast-start-feature-flags'
	],
	[
		'Utilities - Guide.md',
		'utilities-guide'
	],
	[
		'reference/objects/ScheduledJob__c.md',
		'reference/objects/scheduledjob-c'
	],
	[
		'reference/apex/index.md',
		'reference/apex'
	],
	[
		'reference/index.md',
		'reference'
	],
	[
		'Feature Flags - Guide.md',
		'feature-flags-guide'
	]
]);

test('decodes %20 and resolves a root-relative .md link to a slug', () =>
{
	const r = normalizeLink('Fast%20Start%20-%20Feature%20Flags.md', '', slugMap);
	assert.deepEqual(r, {href: '/fast-start-feature-flags', resolved: true});
});

test('preserves an anchor', () =>
{
	const r = normalizeLink('Fast%20Start%20-%20Feature%20Flags.md#create-the-flag-and-try-again', '', slugMap);
	assert.equal(r.href, '/fast-start-feature-flags#create-the-flag-and-try-again');
});

test('resolves a link into the reference subtree', () =>
{
	const r = normalizeLink('reference/objects/ScheduledJob__c.md', '', slugMap);
	assert.equal(r.href, '/reference/objects/scheduledjob-c');
});

test('resolves a link relative to the current file directory', () =>
{
	// a page inside reference/apex/ linking up to a top-level guide
	const r = normalizeLink('../../Utilities%20-%20Guide.md#type-resolution-util_typeresolver', 'reference/apex', slugMap);
	assert.equal(r.href, '/utilities-guide#type-resolution-util_typeresolver');
});

test('leaves external, anchor-only, and non-.md links unchanged', () =>
{
	assert.equal(normalizeLink('https://developer.salesforce.com/x', '', slugMap).href, 'https://developer.salesforce.com/x');
	assert.equal(normalizeLink('#section', '', slugMap).href, '#section');
	assert.equal(normalizeLink('image.png', '', slugMap).href, 'image.png');
});

test('reports an unresolved .md target instead of throwing', () =>
{
	const r = normalizeLink('Does%20Not%20Exist.md', '', slugMap);
	assert.equal(r.resolved, false);
});

test('rewriteLinks rewrites every markdown link in a body and collects unresolved', () =>
{
	const body = 'See [FF](Fast%20Start%20-%20Feature%20Flags.md) and [missing](Gone.md).';
	const {content, unresolved} = rewriteLinks(body, 'Feature Flags - Guide.md', slugMap);
	assert.ok(content.includes('](/fast-start-feature-flags)'));
	assert.deepEqual(unresolved, ['Gone.md']);
});

test('a directory-index target keeps a trailing slash so the dead-link checker matches', () =>
{
	// VitePress builds the page id for reference/apex/index.md as "reference/apex/index";
	// a link to /reference/apex (no slash) is flagged dead. The trailing slash lets the
	// checker append "index" and resolve.
	const r = normalizeLink('apex/index.md', 'reference', slugMap);
	assert.equal(r.href, '/reference/apex/');
	const top = normalizeLink('reference/index.md', '', slugMap);
	assert.equal(top.href, '/reference/');
});

test('a directory-index target preserves an anchor after the trailing slash', () =>
{
	const r = normalizeLink('apex/index.md#classes', 'reference', slugMap);
	assert.equal(r.href, '/reference/apex/#classes');
});

test('rewriteLinks rewrites reference-style link definitions ([id]: path)', () =>
{
	const body = 'Use [the launcher][ujl].\n\n[ujl]: reference/objects/ScheduledJob__c.md\n[gone]: Missing.md';
	const {content, unresolved} = rewriteLinks(body, 'Feature Flags - Guide.md', slugMap);
	assert.ok(content.includes('[ujl]: /reference/objects/scheduledjob-c'));
	assert.deepEqual(unresolved, ['Missing.md']);
});
