// SPDX-License-Identifier: BUSL-1.1
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {sourceRepoRelForPage, urlToSlug, applyLastmod} from './sitemap-lastmod.mjs';

test('sourceRepoRelForPage maps each page kind to its repo-root source path', () =>
{
	assert.equal(sourceRepoRelForPage('', ''), 'README.md');                                  // home = public README
	assert.equal(sourceRepoRelForPage('agents', 'AGENTS.md'), 'AGENTS.md');                    // on-site /agents
	assert.equal(sourceRepoRelForPage('release-notes-kern-1-1', 'release-notes/Kern-1.1.md'), 'release-notes/Kern-1.1.md');
	assert.equal(sourceRepoRelForPage('fast-starts', 'Fast Starts.md'), 'docs/Fast Starts.md');
	assert.equal(sourceRepoRelForPage('reference/apex/sel-base', 'reference/apex/SEL_Base.md'), 'docs/reference/apex/SEL_Base.md');
});

test('urlToSlug normalizes leading/trailing slash and .html', () =>
{
	assert.equal(urlToSlug('/fast-starts'), 'fast-starts');
	assert.equal(urlToSlug('fast-starts/'), 'fast-starts');
	assert.equal(urlToSlug('fast-starts.html'), 'fast-starts');
	assert.equal(urlToSlug('/reference/apex/sel-base'), 'reference/apex/sel-base');
	assert.equal(urlToSlug('/'), '');
	assert.equal(urlToSlug(''), '');
});

test('applyLastmod sets lastmod only where a date is known, without mutating inputs', () =>
{
	const items = [
		{url: '/fast-starts'},
		{url: '/reference/apex/sel-base'},
		{url: '/uncharted'}
	];
	const map = {'fast-starts': '2026-06-16', 'reference/apex/sel-base': '2026-06-10'};
	const out = applyLastmod(items, map);

	assert.equal(out[0].lastmod, '2026-06-16');
	assert.equal(out[1].lastmod, '2026-06-10');
	assert.equal(out[2].lastmod, undefined, 'unknown page gets no fabricated date');
	assert.equal(items[0].lastmod, undefined, 'original items are not mutated');
});

test('applyLastmod tolerates a missing/empty map', () =>
{
	const items = [{url: '/x'}];
	assert.deepEqual(applyLastmod(items, null), [{url: '/x'}]);
	assert.deepEqual(applyLastmod(items, {}), [{url: '/x'}]);
});
