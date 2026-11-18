// SPDX-License-Identifier: Apache-2.0
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, readdirSync} from 'node:fs';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {areaForPage} from './generate-nav.mjs';

// Enforces the documentation IA convention (docs/Code Conventions - Guide.md): every
// Fast Start declares a banded `navOrder` ("soonest × oftenest"), so the sidebar order
// is deterministic and self-describing rather than alphabetical. Fast Starts are gated
// (fail); Guides are advisory (warn), since they may legitimately fall back to alpha.
const DOCS = fileURLToPath(new URL('../../docs', import.meta.url));
const BANDS = [[10, 29], [30, 59], [60, 89], [90, 999]];

function navOrderOf(file)
{
	const txt = readFileSync(join(DOCS, file), 'utf8');
	const fm = txt.match(/^---\n([\s\S]*?)\n---/);
	if(!fm)
	{
		return null;
	}
	const n = fm[1].match(/^navOrder:\s*(\d+)\s*$/m);
	return n ? Number(n[1]) : null;
}

function inBand(n)
{
	return BANDS.some(([lo, hi]) => n >= lo && n <= hi);
}

test('every Fast Start declares a banded navOrder (IA convention)', () =>
{
	const files = readdirSync(DOCS).filter(f => /^Fast Start - .*\.md$/.test(f));
	assert.ok(files.length > 0, 'expected to find Fast Start source files');
	const missing = [];
	const outOfBand = [];
	for(const f of files)
	{
		const n = navOrderOf(f);
		if(n == null)
		{
			missing.push(f);
		}
		else if(!inBand(n))
		{
			outOfBand.push(`${f} (${n})`);
		}
	}
	assert.deepEqual(missing, [], `Fast Starts missing navOrder — add a banded value (see the IA convention): ${missing.join(', ')}`);
	assert.deepEqual(outOfBand, [], `Fast Starts with out-of-band navOrder: ${outOfBand.join(', ')}`);
});

test('every developer guide has a plain-word menu label', () =>
{
	// The Guides menu shows `navLabel`, for example "DML (saving records)", so a reader who does
	// not know the KernDX name of a feature can still find its guide. The page title stays as it is.
	const guides = readdirSync(DOCS).filter(f => f.endsWith('.md') && areaForPage({relPath: f, frontmatter: {}}) === 'guides');
	assert.ok(guides.length > 0, 'expected to find guide source files');
	const unlabelled = guides.filter(f => !/^navLabel:\s*"[^"]+\([^"]+\)"\s*$/m.test(frontmatterOf(f)));
	assert.deepEqual(unlabelled, [], `Guides without a navLabel of the form "Name (plain words)": ${unlabelled.join(', ')}`);
});

function frontmatterOf(file)
{
	const fm = readFileSync(join(DOCS, file), 'utf8').match(/^---\n([\s\S]*?)\n---/);
	return fm ? fm[1] : '';
}

test('Guides without navOrder are reported (advisory — they fall back to alpha)', () =>
{
	const guides = readdirSync(DOCS).filter(f => / - Guide\.md$/.test(f) && !/^Strategic Guide - /.test(f));
	const without = guides.filter(f => navOrderOf(f) == null);
	if(without.length)
	{
		console.warn(`[nav-order] ${without.length} Guide(s) have no navOrder (alpha-ordered): ${without.join(', ')}`);
	}
	assert.ok(true);
});
