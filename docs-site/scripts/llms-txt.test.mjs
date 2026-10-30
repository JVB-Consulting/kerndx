// SPDX-License-Identifier: Apache-2.0
// Hard gates for the hand-authored llms.txt (docs-site/assets/llms.txt):
//   resolve gate      — every absolute docs-site link resolves to a real page slug
//   completeness gate — every Fast Start / module Guide page is linked or exempted
// Exemption policy: exemptions are for navigational or duplicative pages ONLY,
// never content guides — a content guide belongs in llms.txt or should not exist.
// Every exemption carries a non-empty reason; a stale exemption (matching no
// built page) fails, symmetrically with a dead link.
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {existsSync, readFileSync, readdirSync} from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {slugForPath} from './slug.mjs';
import {mirrorExcludedDocSetFromManifest} from './prepare.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, '..', '..');
const LLMS = readFileSync(path.join(HERE, '..', 'assets', 'llms.txt'), 'utf8');
const MANIFEST_PATH = path.join(REPO, 'distribution', 'public-mirror-manifest.json');

// {page: '<slug>', reason: '<why this page is navigational/duplicative>'}
const EXEMPTIONS = [];

function walkMarkdown(dir, rel = '')
{
	const out = [];
	for(const entry of readdirSync(dir, {withFileTypes: true}))
	{
		const childRel = rel ? `${rel}/${entry.name}` : entry.name;
		if(entry.isDirectory())
		{
			out.push(...walkMarkdown(path.join(dir, entry.name), childRel));
		}
		else if(entry.name.toLowerCase().endsWith('.md'))
		{
			out.push(childRel);
		}
	}
	return out;
}

// The manifest is internal-only (it never ships with the published repository),
// but this test DOES ship and the published repo's docs CI runs it. Guard the
// read: there the excluded docs are already stripped from docs/, so an empty
// exclusion set yields identical gate results.
const excluded = existsSync(MANIFEST_PATH) ? mirrorExcludedDocSetFromManifest(JSON.parse(readFileSync(MANIFEST_PATH, 'utf8'))) : new Set();
const docPages = walkMarkdown(path.join(REPO, 'docs')).filter(rel => !excluded.has(rel));
const validSlugs = new Set(docPages.map(slugForPath).concat([
	'',
	'agents',
	'readme'
]));
const linkedSlugs = [...LLMS.matchAll(/https:\/\/docs\.jvb-consulting\.io\/([^)\s]*)/g)]
.map(match => match[1].replace(/\/+$/, ''));

test('resolve gate: every llms.txt link resolves to a live page slug', () =>
{
	for(const slug of linkedSlugs)
	{
		assert.ok(validSlugs.has(slug), `llms.txt links /${slug} but no such page exists (or it is mirror-excluded)`);
	}
});

test('completeness gate: every Fast Start and module Guide page is linked or exempted', () =>
{
	const linked = new Set(linkedSlugs);
	const exempt = new Set(EXEMPTIONS.map(e => e.page));
	const families = [...validSlugs].filter(slug => /^fast-start-/.test(slug) || /-guide$/.test(slug));
	for(const slug of families)
	{
		assert.ok(linked.has(slug) || exempt.has(slug), `page /${slug} is neither linked in llms.txt nor exempted`);
	}
});

test('exemption governance: non-empty reasons, no stale entries', () =>
{
	for(const entry of EXEMPTIONS)
	{
		assert.ok(entry.reason && entry.reason.trim().length > 0, `exemption for /${entry.page} has no reason`);
		assert.ok(validSlugs.has(entry.page), `exemption for /${entry.page} is stale — no such page exists`);
	}
});

test('llms.txt has the required shape: H1, summary blockquote, sections', () =>
{
	assert.match(LLMS, /^# KernDX\n/);
	assert.match(LLMS, /\n> /);
	for(const heading of [
		'## Start here',
		'## Core capabilities',
		'## Conventions & reference',
		'## Optional'
	])
	{
		assert.ok(LLMS.includes(`\n${heading}\n`), `missing section: ${heading}`);
	}
});
