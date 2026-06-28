// SPDX-License-Identifier: BUSL-1.1
// Tier-1 render gate. Builds, serves `vitepress preview`, drives Chromium via
// @playwright/test's chromium (NOT the Playwright MCP). Exits non-zero on failure.
import {chromium} from '@playwright/test';
import {spawn} from 'node:child_process';
import {setTimeout as sleep} from 'node:timers/promises';

// DOCS_BASE is e.g. '/kerndx-docs-pages-check/' for a project-page deploy,
// or '/' (the default) for the production custom-domain deploy.
const DOCS_BASE = (process.env.DOCS_BASE ?? '/').replace(/\/$/, '');
const BASE = `http://localhost:4173${DOCS_BASE}`;

async function waitForServer(timeoutMs = 30000)
{
	const start = Date.now();
	while(Date.now() - start < timeoutMs)
	{
		try
		{
			const r = await fetch(BASE);
			if(r.ok)
			{
				return;
			}
		}
		catch
		{
		}
		await sleep(500);
	}
	throw new Error('preview server did not start');
}

function assert(cond, msg)
{
	if(!cond)
	{
		console.error('FAIL:', msg);
		process.exitCode = 1;
		throw new Error(msg);
	}
	else
	{
		console.log('ok:', msg);
	}
}

const server = spawn('npx', [
	'vitepress',
	'preview',
	'--port',
	'4173'
], {stdio: 'inherit'});
let browser;
try
{
	await waitForServer();
	browser = await chromium.launch();
	const page = await browser.newPage();

	// 1. Ordinary GFM table renders (Selectors guide has tables).
	await page.goto(`${BASE}/selectors-guide`, {waitUntil: 'networkidle'});
	assert(await page.locator('.vp-doc table').count() > 0, 'GFM table renders on selectors-guide');

	// 2. Code block has a copy button.
	assert(await page.locator('.vp-doc div[class*="language-"] button.copy').count() > 0, 'code block has a copy button');

	// 3. Mermaid → SVG (await client-side hydration).
	await page.goto(`${BASE}/objects-metadata-guide`, {waitUntil: 'networkidle'});
	await page.waitForSelector('.vp-doc svg[id^="mermaid"], .mermaid svg', {timeout: 15000});
	assert(await page.locator('.vp-doc svg').count() > 0, 'mermaid diagram renders as <svg>');

	// 4. Collapsible compiled to native details.custom-block with no raw ::: leak + inner content.
	await page.goto(`${BASE}/dtos-guide`, {waitUntil: 'networkidle'});
	const details = page.locator('details.custom-block').first();
	assert(await details.count() > 0, 'details compiled to details.custom-block');
	const bodyText = await page.locator('.vp-doc').innerText();
	assert(!bodyText.includes(':::'), 'no raw ::: container token leaks into rendered body');

	// 5. Mobile: page body has no horizontal overflow at 390px.
	await page.setViewportSize({width: 390, height: 800});
	await page.goto(`${BASE}/objects-metadata-guide`, {waitUntil: 'networkidle'});
	const overflow = await page.evaluate(() => document.body.scrollWidth - document.body.clientWidth);
	assert(overflow <= 1, `page body has no horizontal overflow at 390px (got ${overflow}px)`);

	// 6. In-page anchors resolve: every same-page #fragment link in the doc body points at a
	// real element id. Covers the trickiest pages — a numbered TOC + a generic method anchor
	// on web-services-guide, the 30 `__c` field anchors on a reference object page, and the
	// admin-tools tour's raw-`<a href="#…">` jump-list chips (authored as HTML, so they bypass
	// the build's markdown anchor-rewrite and are only caught by a runtime DOM check like this).
	await page.setViewportSize({width: 1280, height: 800});
	for(const route of ['/web-services-guide', '/reference/objects/apicall-c', '/administration-tools-guide'])
	{
		await page.goto(`${BASE}${route}`, {waitUntil: 'networkidle'});
		const dead = await page.evaluate(() =>
		{
			const bad = [];
			for(const a of document.querySelectorAll('.vp-doc a[href^="#"]'))
			{
				const id = decodeURIComponent(a.getAttribute('href').slice(1));
				if(id && !document.getElementById(id))
				{
					bad.push(id);
				}
			}
			return bad;
		});
		assert(dead.length === 0, `all in-page anchors resolve on ${route} (dead: ${dead.join(', ')})`);
	}

	// 7. Home is the subscriber-facing KernDX landing tour (layout:page + the KernLanding
	//    component), not the internal maintainer README. The component renders as
	//    .kern-landing — outside the .vp-doc content wrapper a markdown page would use.
	await page.goto(`${BASE}/`, {waitUntil: 'networkidle'});
	// innerText reflects CSS text-transform (the section eyebrows are uppercased), so
	// lowercase both sides before matching the landing's merged "Ideas worth taking" grid.
	const homeText = (await page.locator('.kern-landing').innerText()).toLowerCase();
	assert(homeText.includes('ideas worth taking'), 'home renders the KernDX landing tour');
	assert(!homeText.includes('private development repo'), 'home is the public landing, not the internal dev README');

	// 8. Mobile: a method-summary signature stays readable. The stacked-card layout must
	//    NOT blockify each inline type-link into its own ~1-char-wide column (a flex
	//    container turns every <a>/text node of a multi-element cell into a shrunk flex
	//    item). Regression guard for the Methods-overview table at ≤640px.
	await page.setViewportSize({width: 390, height: 1200});
	await page.goto(`${BASE}/reference/apex/util-sobjectdescribe`, {waitUntil: 'networkidle'});
	const sig = await page.evaluate(() =>
	{
		const tables = [...document.querySelectorAll('.vp-doc table')];
		const methodTable = tables.find(t => (t.querySelector('thead th')?.textContent || '').trim() === 'Method');
		if(!methodTable)
		{
			return {error: 'no Method summary table on reference page'};
		}
		const cell = methodTable.querySelector('tbody tr td');
		const links = [...cell.querySelectorAll('a')];
		const maxW = links.reduce((m, a) => Math.max(m, Math.round(a.getBoundingClientRect().width)), 0);
		return {linkCount: links.length, maxW};
	});
	assert(!sig.error, `Methods summary table present on reference page (${sig.error || 'ok'})`);
	assert(sig.maxW >= 40, `method signature wraps as text, not per-character columns at 390px (widest type-link ${sig.maxW}px across ${sig.linkCount} links)`);

	// 9. Reference property/field details must not render orphan metadata labels. A class
	//    property carries a `Since:` (single doc version → intentionally dropped) and may carry
	//    an empty `Example:`; if the extractor fails to strip them they leak into the description
	//    as bare "Since:" / "Example:" lines. SEL_Base has several documented properties, so it
	//    exercises the property-detail path. (A real example renders as bold "Example", no colon.)
	//    The per-property detail cards now render inline under the merged `## Properties` section
	//    (each with a `Type:` line); the separate `## Property Details` heading was folded in.
	await page.setViewportSize({width: 1280, height: 800});
	await page.goto(`${BASE}/reference/apex/sel-base`, {waitUntil: 'networkidle'});
	const refText = await page.locator('.vp-doc').innerText();
	assert(refText.includes('Properties') && refText.includes('Type:'), 'SEL_Base reference page renders property details under the merged Properties section');
	const orphanLabels = refText.split('\n').map(l => l.trim()).filter(l => l === 'Since:' || l === 'Example:');
	assert(orphanLabels.length === 0, `reference property details have no orphan Since:/Example: labels (found ${orphanLabels.length})`);

	// 10. Administration Tools tour page renders hero-loop videos: each <video> is muted +
	//     looped, carries a poster + aria-label, offers a webm AND an mp4 <source>; each loop
	//     has a "Read the full guide" deep-link; every source, poster, AND guide target resolves
	//     (HTTP 200). Reduced-motion safety is handled in the component.
	await page.goto(`${BASE}/administration-tools-guide`, {waitUntil: 'networkidle'});
	const loops = await page.evaluate(() =>
	{
		const out = [];
		for(const fig of document.querySelectorAll('figure.hero-loop'))
		{
			const v = fig.querySelector('video.hero-loop__video');
			if(!v)
			{
				continue;
			}
			const g = fig.querySelector('a.hero-loop__guide');
			out.push({
				poster: v.getAttribute('poster'),
				ariaLabel: v.getAttribute('aria-label'),
				muted: v.muted,
				loop: v.loop,
				sources: Array.from(v.querySelectorAll('source')).map(s => ({src: s.getAttribute('src'), type: s.getAttribute('type')})),
				guide: g ? g.getAttribute('href') : null
			});
		}
		return out;
	});
	assert(loops.length >= 4, `tour page renders >=4 hero loops (got ${loops.length})`);
	for(const l of loops)
	{
		assert(l.muted && l.loop, `hero loop is muted + looped (${l.poster})`);
		assert(!!l.poster, `hero loop has a poster (${l.poster})`);
		assert(!!l.ariaLabel, `hero loop has an aria-label (${l.poster})`);
		const types = l.sources.map(s => s.type);
		assert(types.includes('video/webm') && types.includes('video/mp4'), `hero loop offers webm + mp4 (${l.poster})`);
		for(const s of l.sources)
		{
			const sres = await page.request.get(new URL(s.src, page.url()).href);
			assert(sres.status() === 200, `hero loop source resolves 200: ${s.src}`);
		}
		const pres = await page.request.get(new URL(l.poster, page.url()).href);
		assert(pres.status() === 200, `hero loop poster resolves 200: ${l.poster}`);
		assert(!!l.guide, `hero loop has a guide deep-link (${l.poster})`);
		// vite preview serves built files; request the .html artifact so a typo'd slug 404s here.
		const gres = await page.request.get(new URL(l.guide.replace(/\/$/, '') + '.html', page.url()).href);
		assert(gres.status() === 200, `hero loop guide link resolves 200: ${l.guide}`);
		console.log(`ok: hero loop ${l.poster} (webm+mp4, poster, guide ${l.guide})`);
	}

	// 11. Admin-tools tour stills: every embedded /stills/ screenshot resolves (HTTP 200). These are
	//     plain markdown images served from /public — nothing in the build gates a missing one, so
	//     verify them at render time the way the hero-loop sources are verified above.
	const stills = await page.evaluate(() =>
		Array.from(document.querySelectorAll('.vp-doc img'))
		.map(img => img.getAttribute('src'))
		.filter(src => src && src.includes('/stills/')));
	assert(stills.length >= 7, `tour page embeds >=7 stills (got ${stills.length})`);
	for(const src of stills)
	{
		const sres = await page.request.get(new URL(src, page.url()).href);
		assert(sres.status() === 200, `tour still resolves 200: ${src}`);
	}

	console.log('render smoke-test PASSED');
}
finally
{
	if(browser)
	{
		await browser.close();
	}
	server.kill('SIGTERM')
}
