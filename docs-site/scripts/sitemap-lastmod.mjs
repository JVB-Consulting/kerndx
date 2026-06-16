// SPDX-License-Identifier: BUSL-1.1
// Sitemap <lastmod> helpers.
//
// Each page's <lastmod> is the git last-commit DATE (YYYY-MM-DD) of its SOURCE file.
// prepare.mjs computes the { slug: date } map (it has the page→source mapping and runs
// git) and writes it to `.vitepress/lastmod.generated.json`; config.mjs applies it to the
// VitePress sitemap via `transformItems`. Per-page dates are the signal search engines
// trust — a single build-time date stamped on every URL is treated as noise and ignored.
//
// These two helpers are pure (no I/O) so they can be unit-tested directly.

// Map one page's slug to its source file path, relative to the repo root. The slug is the
// VitePress route ('' = home, 'agents', 'fast-starts', 'reference/apex/sel-base', …); the
// source is the committed markdown the page is built from. Mirrors prepare.mjs's own
// source enumeration: AGENTS and release notes live at the repo root, the home page is the
// public README, everything else is under docs/.
export function sourceRepoRelForPage(slug, relPath)
{
	if(slug === '')
	{
		return 'README.md';
	}
	if(relPath === 'AGENTS.md')
	{
		return 'AGENTS.md';
	}
	if(relPath.startsWith('release-notes/'))
	{
		return relPath;
	}
	return `docs/${relPath}`;
}

// Normalize a VitePress sitemap item URL to the route slug used as the map key: drop a
// leading slash, a trailing slash, and any `.html`, so '/fast-starts', 'fast-starts/',
// and 'fast-starts.html' all key to 'fast-starts'; '/' and '' both key to '' (home).
export function urlToSlug(url)
{
	return String(url || '')
		.replace(/^\//, '')
		.replace(/\.html$/, '')
		.replace(/\/$/, '');
}

// Apply a { slug: 'YYYY-MM-DD' } map to VitePress sitemap items, setting `lastmod` where a
// date is known. Items with no known date are left untouched (no fabricated date). Pure:
// returns a new array, original items unmutated.
export function applyLastmod(items, lastmodBySlug)
{
	const map = lastmodBySlug || {};
	return items.map(item =>
	{
		const date = map[urlToSlug(item.url)];
		return date ? {...item, lastmod: date} : item;
	});
}
