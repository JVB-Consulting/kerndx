// SPDX-License-Identifier: Apache-2.0
// Tier-1 render gate. Builds, serves `vitepress preview`, drives Chromium via
// @playwright/test's chromium (NOT the Playwright MCP). Exits non-zero on failure.
import {chromium} from '@playwright/test';
import {spawn} from 'node:child_process';
import {readdir, readFile} from 'node:fs/promises';
import {setTimeout as sleep} from 'node:timers/promises';
import {parseFrontmatter} from './frontmatter.mjs';
import {movedAnchorsOf} from './prepare.mjs';
import {slugForPath} from './slug.mjs';

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

// The first page in docs/ whose frontmatter lists movedAnchors, with its first moved heading, or null
// when no page lists any. `headingMove` is the first old id, on any page, whose new place is a heading
// (`/page#id`) and not a whole page, or null when there is none.
async function findMovedAnchor()
{
	const docs = new URL('../../docs/', import.meta.url);
	const files = (await readdir(docs, {recursive: true})).filter(file => file.endsWith('.md')).sort();
	let found = null;
	for(const file of files)
	{
		const anchors = movedAnchorsOf(parseFrontmatter(await readFile(new URL(file, docs), 'utf8')).data);
		const route = slugForPath(file.split('\\').join('/'));
		const entries = Object.entries(anchors);
		if(found === null && entries.length > 0)
		{
			found = {route, oldId: entries[0][0], target: entries[0][1], movedIds: Object.keys(anchors), headingMove: null};
		}
		const toHeading = entries.find(([, place]) => place.includes('#'));
		if(found !== null && toHeading)
		{
			found.headingMove = {route, oldId: toHeading[0], target: toHeading[1]};
			return found;
		}
	}
	return found;
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

// `detached` so teardown can kill the process GROUP. Spawning through `npx` puts a wrapper process
// in between, so a plain server.kill() reaps the wrapper and leaves vitepress bound to the port.
// That orphan then serves a STALE file map (sirv indexes the directory once at startup), so the
// next run's freshly built, content-hashed assets 404 and the page never hydrates.
const server = spawn('npx', [
	'vitepress',
	'preview',
	'--port',
	'4173'
], {stdio: 'inherit', detached: true});
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

	// 3b. …and the <Mermaid> component resolved during SSR, not only in the browser. The check above
	//     cannot see the difference: it drives a real browser, so a component registered only on the
	//     client still produces the SVG and still passes. But the server-rendered HTML would then
	//     carry no diagram container at all — invisible to the gate, visible to anyone reading
	//     source, and to a crawler. mermaid is registered lazily (theme/index.mjs) precisely so it
	//     stays out of the client entry, which makes it easy to "tidy" the registration into the
	//     browser-only block and silently lose SSR. This assertion is what makes that loud.
	const diagramHtml = await readFile(new URL('../.vitepress/dist/objects-metadata-guide.html', import.meta.url), 'utf8');
	assert(/class="mermaid[" ]/.test(diagramHtml), 'mermaid container is present in the SERVER-rendered HTML (component resolved during SSR, not client-only)');

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

	// 7b. Phone: the job table ("I need to" / "Try it in minutes" / "Learn it properly" / "Look up a method")
	//     fits its column on the landing page and on /fast-starts. A table wider than its column scrolls
	//     sideways, and nothing tells the reader to swipe, so "Look up a method" is never seen. Every row
	//     must show all four of its pieces inside the column, and each link must show its column name.
	await page.setViewportSize({width: 390, height: 844});
	for(const route of ['/', '/fast-starts'])
	{
		await page.goto(`${BASE}${route}`, {waitUntil: 'networkidle'});
		const jobs = await page.evaluate(() =>
		{
			const table = [...document.querySelectorAll('table')].find(candidate =>
				[...candidate.querySelectorAll('thead th')].map(header => header.textContent.trim()).join('|')
				=== 'I need to|Try it in minutes|Learn it properly|Look up a method');
			if(!table)
			{
				return {error: 'no job table'};
			}
			const column = table.closest('.kl-jobs, .vp-doc');
			const columnBox = column.getBoundingClientRect();
			const problems = [];
			if(table.scrollWidth > column.clientWidth + 1 || column.scrollWidth > column.clientWidth + 1)
			{
				problems.push(`table ${table.scrollWidth}px wide in a ${column.clientWidth}px column`);
			}
			const rows = [...table.querySelectorAll('tbody tr')];
			for(const row of rows)
			{
				const pieces = [...row.children];
				const job = pieces[0]?.textContent.trim().slice(0, 30);
				if(pieces.length !== 4)
				{
					problems.push(`"${job}" has ${pieces.length} pieces`);
					continue;
				}
				for(const piece of pieces)
				{
					const box = piece.getBoundingClientRect();
					if(box.width === 0 || box.height === 0 || box.left < columnBox.left - 1 || box.right > columnBox.right + 1)
					{
						problems.push(`"${job}": a piece sits outside the column (${Math.round(box.left)} to ${Math.round(box.right)})`);
					}
					// A column name that wraps past its own piece runs over the next one.
					if(piece.scrollHeight > piece.clientHeight + 1)
					{
						problems.push(`"${job}": text runs past its piece (${piece.scrollHeight}px in ${piece.clientHeight}px)`);
					}
				}
				for(const cell of pieces.slice(1))
				{
					const label = cell.getAttribute('data-label');
					const shown = getComputedStyle(cell, '::before').content;
					if(!label || !shown.includes(label))
					{
						problems.push(`"${job}": a link does not show its column name`);
					}
				}
			}
			return {rows: rows.length, problems};
		});
		assert(!jobs.error, `job table present on ${route} (${jobs.error || 'ok'})`);
		assert(jobs.rows === 10 && jobs.problems.length === 0,
			`job table on ${route} fits a 390px phone with all four pieces of its ${jobs.rows} rows visible (${jobs.problems.slice(0, 3).join('; ') || 'ok'})`);
	}
	await page.setViewportSize({width: 1280, height: 800});

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
	// 10b. No <video> anywhere in the corpus may carry `autoplay` in its SERVER-RENDERED HTML.
	//      `autoplay` overrides the `preload="none"` beside it, so the browser's preload scanner
	//      starts every loop downloading during first paint — before Vue hydrates, and therefore
	//      before the IntersectionObserver in HeroLoop can gate it (pausing a video does not abort
	//      a fetch already in flight). Eight loops cost the tour page an 8 MB first load that way.
	//      Two deliberate choices here. Read the built HTML rather than the hydrated DOM: the DOM
	//      is what the page holds after JS has run, the HTML is what the scanner actually acted on.
	//      And sweep the WHOLE corpus rather than the one page that has loops today, so a NEW page
	//      embedding one is covered the day it is written, with nobody having to extend this test.
	const distDir = new URL('../.vitepress/dist/', import.meta.url);
	const htmlFiles = (await readdir(distDir, {recursive: true})).filter(f => f.endsWith('.html'));
	let corpusVideos = 0;
	const autoplayPages = [];
	for(const file of htmlFiles)
	{
		const html = await readFile(new URL(file, distDir), 'utf8');
		corpusVideos += (html.match(/<video\b[^>]*>/gi) ?? []).length;
		const offenders = (html.match(/<video\b[^>]*\bautoplay\b[^>]*>/gi) ?? []).length;
		if(offenders)
		{
			autoplayPages.push(`${file} (${offenders})`);
		}
	}
	// The two guards below keep the assertion from passing vacuously: a build that emitted nothing,
	// or a corpus with no <video> left in it, would otherwise read as "no autoplay anywhere".
	assert(htmlFiles.length > 100, `corpus sweep found the built pages (${htmlFiles.length} html files)`);
	assert(corpusVideos > 0, `corpus contains <video> elements to check (${corpusVideos})`);
	assert(autoplayPages.length === 0, `no page ships autoplay in server-rendered HTML (offenders: ${autoplayPages.join(', ') || 'none'})`);

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

	// 12. The older-version banner on a frozen tree, at phone and desktop widths. Two defects this
	//     guards: on desktop the fixed nav covered the banner (the theme offsets the nav and content
	//     by --vp-layout-top-height, which nothing set), and on a phone its link opened a 404 (the
	//     router resolved '/' inside the frozen app). The link must land on the SAME page in the
	//     latest tree. The banner is pinned only from 960px, where the theme pins the nav; on a phone
	//     it scrolls away with the page. Frozen trees exist only after build:versions; the check is
	//     skipped, not passed, when the repository has none, and fails when it has some that the
	//     build did not assemble.
	const frozenSources = (await readdir(new URL('../../docs-versions/', import.meta.url)).catch(() => []))
	.filter(name => /^\d+\.\d+$/.test(name));
	const frozenBuilt = (await readdir(distDir).catch(() => [])).filter(name => /^\d+\.\d+$/.test(name));
	if(frozenSources.length === 0)
	{
		console.log('skip: no docs-versions/ lines, so no older-version banner to check');
	}
	else
	{
		assert(frozenBuilt.length === frozenSources.length, `every frozen line is assembled into dist (${frozenBuilt.join(', ')}); run build:versions first`);
		const frozenLine = frozenBuilt.sort((a, b) => a.localeCompare(b, undefined, {numeric: true})).at(-1);
		for(const width of [390, 1280])
		{
			await page.setViewportSize({width, height: 800});
			await page.goto(`${BASE}/${frozenLine}/selectors-guide`, {waitUntil: 'networkidle'});
			const banner = page.locator('.version-banner');
			assert(await banner.isVisible(), `older-version banner shows on /${frozenLine}/ at ${width}px`);
			const covered = await page.evaluate(() =>
			{
				const box = document.querySelector('.version-banner').getBoundingClientRect();
				const hit = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
				return !hit?.closest('.version-banner');
			});
			assert(!covered, `nothing covers the older-version banner at ${width}px`);
			// Pinned on desktop, where the nav is pinned too; on a phone it scrolls away with the page.
			const position = await banner.evaluate(el => getComputedStyle(el).position);
			assert((position === 'fixed') === (width >= 960), `older-version banner is ${width >= 960 ? 'pinned' : 'in the page flow'} at ${width}px (position ${position})`);
			// Not being covered is not enough on desktop: the banner sits above the nav, so the nav must also start below it.
			const layout = await page.evaluate(() => ({
				bannerBottom: document.querySelector('.version-banner').getBoundingClientRect().bottom,
				navTop: document.querySelector('.VPNav').getBoundingClientRect().top,
				published: document.documentElement.style.getPropertyValue('--vp-layout-top-height')
			}));
			assert(layout.navTop >= layout.bannerBottom - 1, `the nav starts below the banner at ${width}px (nav ${layout.navTop}px, banner ends ${layout.bannerBottom}px)`);
			assert((layout.published !== '') === (width >= 960), `the banner height is published to the theme only when pinned, at ${width}px ('${layout.published}')`);
			await Promise.all([page.waitForURL(`${BASE}/selectors-guide`), banner.locator('a').click()]);
			await page.waitForLoadState('networkidle');
			assert(await page.locator('.NotFound').count() === 0, `banner link opens a real page, not a 404, at ${width}px`);
			assert(await page.locator('.version-banner').count() === 0, `banner link lands on the latest tree at ${width}px`);
		}
	}

	// 12b. A link into an older version the site no longer publishes opens the same page in the
	//      current docs, and its home opens the current home. The preview server, like GitHub Pages,
	//      answers an address it has no file for with 404.html, whose script sends the reader on.
	//      A published older version is left alone. 0.1 and 0.2 were never published, so they
	//      stand for any removed version and stay valid whichever versions are kept.
	await page.setViewportSize({width: 1280, height: 800});
	await page.goto(`${BASE}/0.1/selectors-guide#joins`, {waitUntil: 'networkidle'});
	assert(page.url() === `${BASE}/selectors-guide#joins`, `a removed version's page opens the current page (${page.url()})`);
	assert(await page.locator('.NotFound').count() === 0, 'the current page it opens is a real page, not a 404');
	await page.goto(`${BASE}/0.2/`, {waitUntil: 'networkidle'});
	assert(page.url() === `${BASE}/`, `a removed version's home opens the current home (${page.url()})`);
	const newestPublished = frozenBuilt.sort((a, b) => a.localeCompare(b, undefined, {numeric: true})).at(-1);
	if(newestPublished)
	{
		await page.goto(`${BASE}/${newestPublished}/selectors-guide`, {waitUntil: 'networkidle'});
		assert(page.url() === `${BASE}/${newestPublished}/selectors-guide`, `a published older version stays where it is (${page.url()})`);
		assert(await page.locator('.version-banner').count() === 1, `/${newestPublished}/selectors-guide still shows its own older-version page`);
	}

	// 13. "On this page" on the largest guides (theme/overrides/VPDocOutlineItem.vue). It shows the
	//     main headings and opens the sub-headings of the section being read; one button shows every
	//     heading. The section being read comes from VitePress's own scroll tracking (the `active`
	//     class), so these checks also catch an upgrade that changes it. The list is in the right-hand
	//     column, which VitePress shows only from 1280px.
	// VitePress slides the marker to the active entry in 0.25 s; wait that out before measuring it.
	const MARKER_MOVE_MS = 400;
	await page.setViewportSize({width: 1440, height: 900});
	await page.goto(`${BASE}/selectors-guide`, {waitUntil: 'networkidle'});
	const outline = page.locator('.VPDocAsideOutline');
	const toggle = outline.locator('button.outline-toggle');
	const outlineState = () => page.evaluate(() =>
	{
		const aside = document.querySelector('.VPDocAsideOutline');
		const links = [...aside.querySelectorAll('a.outline-link')];
		const visible = links.filter(a => a.offsetParent !== null);
		const active = aside.querySelector('a.outline-link.active');
		const marker = aside.querySelector('.outline-marker');
		const activeBox = active?.getBoundingClientRect();
		const markerBox = marker.getBoundingClientRect();
		return {
			total: links.length,
			visible: visible.length,
			visibleNested: visible.filter(a => a.closest('.section-headings')).length,
			openSections: [...aside.querySelectorAll('.section-headings')].filter(d => d.offsetParent !== null).map(d => d.parentElement.querySelector(':scope > a').getAttribute('href')),
			active: active?.getAttribute('href') ?? null,
			activeVisible: active ? active.offsetParent !== null : false,
			markerOnActive: activeBox ? markerBox.top >= activeBox.top - 1 && markerBox.bottom <= activeBox.bottom + 1 && getComputedStyle(marker).opacity === '1' : false,
			markerTop: Math.round(markerBox.top),
			activeTop: activeBox ? Math.round(activeBox.top) : null,
			headingsInPage: document.querySelectorAll('.vp-doc :where(h2,h3)[id]').length
		};
	});
	assert(await toggle.count() === 1, 'On this page: the largest guides have one button to show all headings');
	assert((await toggle.innerText()).trim() === 'Show all headings' && await toggle.getAttribute('aria-expanded') === 'false', 'On this page: the button reads "Show all headings" and is not expanded');
	let state = await outlineState();
	assert(state.visibleNested === 0 && state.visible > 0 && state.visible < state.total, `On this page: at the top of the page only main headings show (${state.visible} of ${state.total})`);

	// opening a section shows its sub-headings
	const sectionLink = outline.locator('li:has(> .section-headings) > a.outline-link').nth(2);
	const sectionHref = await sectionLink.getAttribute('href');
	await sectionLink.click();
	await page.waitForFunction((href) => document.querySelector(`.VPDocAsideOutline li:has(> a[href="${href}"]) > .section-headings`)?.offsetParent !== null, sectionHref, {timeout: 5000});
	await sleep(MARKER_MOVE_MS);
	state = await outlineState();
	assert(state.openSections.length === 1 && state.openSections[0] === sectionHref && state.visibleNested > 0, `opening a section shows its sub-headings (${sectionHref}, ${state.visibleNested} shown, open: ${state.openSections.join(' ')})`);
	assert(state.active === sectionHref && state.markerOnActive, `On this page: the opened section is the active entry and the marker sits on it (${state.active}; marker ${state.markerTop}px, entry ${state.activeTop}px)`);

	// Show all headings lists every heading
	await toggle.click();
	await sleep(MARKER_MOVE_MS);
	state = await outlineState();
	assert(state.markerOnActive, `On this page: after "Show all headings" the marker still sits on the section being read (marker ${state.markerTop}px, entry ${state.activeTop}px)`);
	assert(state.visible === state.total && state.total === state.headingsInPage, `Show all headings lists every heading (${state.visible} of ${state.total}, ${state.headingsInPage} in the page)`);
	assert((await toggle.innerText()).trim() === 'Show main headings' && await toggle.getAttribute('aria-expanded') === 'true', 'On this page: the button then reads "Show main headings" and is expanded');
	await toggle.click();
	state = await outlineState();
	assert(state.openSections.length === 1 && state.openSections[0] === sectionHref, 'On this page: "Show main headings" closes every section but the one being read');

	// keyboard moves through the list and focus stays visible
	await toggle.focus();
	await page.keyboard.press('Enter');
	assert(await toggle.getAttribute('aria-expanded') === 'true', 'On this page: Enter on the button shows all headings');
	await page.keyboard.press('Space');
	assert(await toggle.getAttribute('aria-expanded') === 'false', 'On this page: Space on the button shows main headings again');
	// Tab from the button until focus leaves the list: every stop must be a shown entry with a focus
	// ring, and the stops must be exactly the entries on screen, in order.
	const visited = [];
	for(let step = 0; step < 200; step++)
	{
		await page.keyboard.press('Tab');
		const stop = await page.evaluate(() =>
		{
			const el = document.activeElement;
			const style = getComputedStyle(el);
			return {
				inOutline: !!el.closest('.VPDocAsideOutline'),
				shown: el.offsetParent !== null,
				focusDrawn: style.outlineStyle !== 'none' && parseFloat(style.outlineWidth) >= 2,
				href: el.getAttribute('href')
			};
		});
		if(!stop.inOutline)
		{
			break;
		}
		visited.push(stop);
	}
	const shownHrefs = await page.evaluate(() => [...document.querySelectorAll('.VPDocAsideOutline a.outline-link')].filter(a => a.offsetParent !== null).map(a => a.getAttribute('href')));
	const openChildHrefs = await outline.locator(`li:has(> a[href="${sectionHref}"]) > .section-headings a.outline-link`).evaluateAll(links => links.map(a => a.getAttribute('href')));
	assert(visited.length > 0 && visited.every(v => v.shown && v.focusDrawn) && visited.map(v => v.href).join(' ') === shownHrefs.join(' '),
			`keyboard moves through the list and focus stays visible (${visited.length} stops for ${shownHrefs.length} shown entries, every stop shown with a focus ring: ${visited.every(v => v.shown && v.focusDrawn)})`);
	assert(openChildHrefs.length > 0 && openChildHrefs.every(href => visited.some(v => v.href === href)), `On this page: Tab reaches the sub-headings of the open section (${openChildHrefs.length})`);

	// the active section opens on load from an anchor, and stays right when the reader opens the
	// list by keyboard. A section in the middle of the page, so the page bottom does not move the
	// active entry to the last heading.
	const sections = outline.locator('li:has(> .section-headings)');
	const middle = sections.nth(Math.floor(await sections.count() / 2));
	const deepHref = await middle.locator('.section-headings a.outline-link').first().getAttribute('href');
	const deepSection = await middle.locator(':scope > a.outline-link').getAttribute('href');
	await page.goto(`${BASE}/selectors-guide${deepHref}`, {waitUntil: 'networkidle'});
	await page.waitForFunction((href) => document.querySelector(`.VPDocAsideOutline a.outline-link.active[href="${href}"]`)?.offsetParent != null, deepHref, {timeout: 5000});
	await sleep(MARKER_MOVE_MS);
	state = await outlineState();
	assert(state.active === deepHref && state.activeVisible && state.openSections.join(' ') === deepSection && state.markerOnActive, `the active section opens on load from an anchor (${deepHref} in ${deepSection}; open: ${state.openSections.join(' ')}, marker on it: ${state.markerOnActive})`);
	await toggle.focus();
	await page.keyboard.press('Enter');
	await sleep(MARKER_MOVE_MS);
	state = await outlineState();
	assert(state.active === deepHref && state.activeVisible && state.markerOnActive && await page.evaluate(() => document.activeElement.classList.contains('outline-toggle')), 'On this page: showing all headings by keyboard keeps focus on the button and the marker on the section being read');
	await page.keyboard.press('Enter');
	await sleep(MARKER_MOVE_MS);
	state = await outlineState();
	assert(state.active === deepHref && state.activeVisible && state.markerOnActive && state.openSections.join(' ') === deepSection, 'On this page: showing main headings again keeps the section being read open and marked');

	// keyboard focus on a sub-heading keeps its section open while the page scrolls to another
	// section (Space scrolls the page one screen at a time), so focus is not lost; when focus
	// leaves, it closes.
	await outline.locator(`a.outline-link[href="${deepHref}"]`).focus();
	const isReadingAnotherSection = () => page.evaluate((section) =>
	{
		const active = document.querySelector('.VPDocAsideOutline a.outline-link.active');
		return active !== null && !active.closest('li:has(> .section-headings)')?.querySelector(':scope > a.outline-link')?.matches(`[href="${section}"]`);
	}, deepSection);
	for(let press = 0; press < 40 && !await isReadingAnotherSection(); press++)
	{
		await page.keyboard.press('Space');
		await sleep(250);
	}
	assert(await isReadingAnotherSection(), 'On this page: scrolling by keyboard reaches another section');
	await sleep(MARKER_MOVE_MS);
	const focusState = await page.evaluate(() => ({href: document.activeElement.getAttribute('href'), shown: document.activeElement.offsetParent !== null}));
	state = await outlineState();
	assert(focusState.href === deepHref && focusState.shown && state.markerOnActive, `On this page: a section with keyboard focus in it stays open while scrolling makes another section the one being read (focus on ${focusState.href}, shown: ${focusState.shown}; active ${state.active})`);
	await page.evaluate(() => document.activeElement.blur());
	state = await outlineState();
	assert(!state.openSections.includes(deepSection), `On this page: that section closes once focus leaves it (open: ${state.openSections.join(' ')})`);

	// moving to another large guide by its sidebar link (no full page load) leaves no section open
	// by mistake, even when both guides have a main heading with the same link (such as "How does
	// it work?") and the reader was in a sub-heading of it that the new page does not have.
	await page.goto(`${BASE}/web-services-guide`, {waitUntil: 'networkidle'});
	const targetOutline = await page.evaluate(() => ({
		links: [...document.querySelectorAll('.VPDocAsideOutline a.outline-link')].map(a => a.getAttribute('href')),
		sections: [...document.querySelectorAll('.VPDocAsideOutline li:has(> .section-headings) > a.outline-link')].map(a => a.getAttribute('href'))
	}));
	await page.goto(`${BASE}/selectors-guide`, {waitUntil: 'networkidle'});
	const shared = await page.evaluate((target) =>
	{
		for(const link of document.querySelectorAll('.VPDocAsideOutline li:has(> .section-headings) > a.outline-link'))
		{
			const subHeading = [...link.parentElement.querySelectorAll('.section-headings a.outline-link')].map(a => a.getAttribute('href')).find(href => !target.links.includes(href));
			if(target.sections.includes(link.getAttribute('href')) && subHeading)
			{
				return {section: link.getAttribute('href'), subHeading};
			}
		}
		return null;
	}, targetOutline);
	assert(shared !== null, 'On this page: the Selectors and Web Services guides share a main heading with sub-headings, for the page-change check');
	await page.evaluate((href) =>
	{
		const heading = document.getElementById(decodeURIComponent(href.slice(1)));
		window.scrollTo(0, heading.getBoundingClientRect().top + window.scrollY - 20);
	}, shared.subHeading);
	await page.waitForFunction((href) => document.querySelector(`.VPDocAsideOutline a.outline-link.active[href="${href}"]`) !== null, shared.subHeading, {timeout: 5000});
	state = await outlineState();
	assert(state.openSections.join(' ') === shared.section, `On this page: reading ${shared.subHeading} opens ${shared.section} before the page change (open: ${state.openSections.join(' ')})`);
	await Promise.all([page.waitForURL(`${BASE}/web-services-guide`), page.locator('.VPSidebar a[href$="/web-services-guide"], .VPSidebar a[href$="/web-services-guide.html"]').first().click()]);
	await page.waitForFunction((links) => [...document.querySelectorAll('.VPDocAsideOutline a.outline-link')].map(a => a.getAttribute('href')).join(' ') === links.join(' '), targetOutline.links, {timeout: 5000});
	await sleep(MARKER_MOVE_MS);
	state = await outlineState();
	assert(state.active === null && state.openSections.length === 0, `On this page: after moving to another guide by the sidebar, no section is open while none is being read (active ${state.active}; open: ${state.openSections.join(' ')})`);

	// Other guides show main headings only; reference pages keep main and sub-headings, both with
	// no button.
	await page.goto(`${BASE}/feature-flags-guide`, {waitUntil: 'networkidle'});
	state = await outlineState();
	assert(await toggle.count() === 0 && state.total > 0 && state.total === await page.locator('.vp-doc h2[id]').count(), `a smaller guide lists its main headings only, with no button (${state.total})`);
	await page.goto(`${BASE}/reference/apex/qry-builder-builder`, {waitUntil: 'networkidle'});
	state = await outlineState();
	assert(await toggle.count() === 0 && state.total === state.headingsInPage && state.visible === state.total, `a reference page keeps two levels, with no button (${state.total})`);

	// 14. Old links to a heading that moved to another page, or to a section sent to a whole page such as
	//     the front page (movedAnchors frontmatter). With scripts on, the old link opens the new place
	//     (the moved heading, or the top of the whole page), and the Back button does not return to the
	//     old link (which would send the reader forward again). With scripts off, the old link lands on
	//     the link to the new place left in the guide. The checks need a page that lists movedAnchors;
	//     until a rewrite moves a section, there is none, and the checks are skipped, not passed.
	const moved = await findMovedAnchor();
	if(moved === null)
	{
		console.log('skip: no page lists movedAnchors yet, so no moved-heading link to check');
	}
	else
	{
		const {route, oldId, target} = moved;
		const oldLink = `${BASE}/${route}#${oldId}`;
		const targetHash = target.split('#')[1];
		const targetId = targetHash === undefined ? null : decodeURIComponent(targetHash);
		const inView = (id) => page.evaluate((elementId) =>
		{
			const element = document.getElementById(elementId);
			const box = element?.getBoundingClientRect();
			return box ? box.top >= 0 && box.top < window.innerHeight : false;
		}, id);
		await page.setViewportSize({width: 1280, height: 800});
		await page.goto(oldLink, {waitUntil: 'networkidle'});
		await page.waitForURL(`${BASE}${target}`, {timeout: 10000});
		await sleep(MARKER_MOVE_MS);
		const opened = targetId === null ? await page.evaluate(() => window.scrollY === 0) : await inView(targetId);
		assert(opened, `an old sub-heading link opens its new place (${oldLink} opened ${page.url()})`);

		// VitePress plans a scroll to the old id for a frame. When the new page opens before that frame
		// runs (its code is already loaded, or the browser is busy), the late scroll must not move the new
		// page. Here each frame runs at least 300 ms late and at least 100 ms after the one asked for before
		// it, still in the order asked for, so other work can finish between two frames. That makes the
		// wrong order show every run, not by chance.
		const SLOW_FRAME_MS = 300;
		const FRAME_GAP_MS = 100;
		const slowContext = await browser.newContext({viewport: {width: 1280, height: 800}});
		await slowContext.addInitScript(({delay, gap}) =>
		{
			const nextFrame = window.requestAnimationFrame.bind(window);
			let lastDue = 0;
			window.requestAnimationFrame = (callback) =>
			{
				const due = Math.max(performance.now() + delay, lastDue + gap);
				lastDue = due;
				return nextFrame(() => setTimeout(() => callback(performance.now()), Math.max(0, due - performance.now())));
			};
		}, {delay: SLOW_FRAME_MS, gap: FRAME_GAP_MS});
		const slowPage = await slowContext.newPage();
		// True when the new place is shown: the top of a whole page, or the moved heading in view.
		const newPlaceShown = (id) => slowPage.evaluate((elementId) =>
		{
			if(elementId === null)
			{
				return window.scrollY === 0;
			}
			const box = document.getElementById(elementId)?.getBoundingClientRect();
			return box ? box.top >= 0 && box.top < window.innerHeight : false;
		}, id);
		// Clicks a link to the old address from inside the open page, the way a reader follows a link in
		// a guide, so the site opens it without loading the whole page again.
		const clickLinkTo = (href) => slowPage.evaluate((linkHref) =>
		{
			window.scrollTo(0, 600);
			const link = document.createElement('a');
			link.href = linkHref;
			link.textContent = 'old link';
			document.body.appendChild(link);
			link.click();
		}, href);
		// Opens one old link in one way on the slow page, and checks the reader sees its new place.
		const checkWhenBusy = async({move, startUrl, how}) =>
		{
			const moveLink = `${BASE}/${move.route}#${move.oldId}`;
			const moveHash = move.target.split('#')[1];
			const moveId = moveHash === undefined ? null : decodeURIComponent(moveHash);
			await slowPage.goto(startUrl, {waitUntil: 'networkidle'});
			if(how === 'address')
			{
				await slowPage.goto(moveLink, {waitUntil: 'networkidle'});
			}
			else
			{
				await clickLinkTo(how === 'same page' ? `#${move.oldId}` : `${DOCS_BASE}/${move.route}#${move.oldId}`);
			}
			await slowPage.waitForURL(`${BASE}${move.target}`, {timeout: 10000});
			await sleep(SLOW_FRAME_MS * 3 + FRAME_GAP_MS * 5 + MARKER_MOVE_MS);
			const shown = await newPlaceShown(moveId);
			const scrolled = await slowPage.evaluate(() => window.scrollY);
			assert(shown, `an old sub-heading link (${how}) opens its new place when frames are slow (${moveLink} from ${startUrl}, scrolled ${scrolled}px)`);
		};
		const otherPage = (move) => move.route === 'fast-starts' ? `${BASE}/` : `${BASE}/fast-starts`;
		const busyMoves = moved.headingMove === null ? [moved] : [moved, moved.headingMove];
		for(const move of busyMoves)
		{
			// A full page load of the old address, with the new page's code already loaded.
			await checkWhenBusy({move, startUrl: `${BASE}${move.target.split('#')[0]}`, how: 'address'});
			// A link on another page of the site.
			await checkWhenBusy({move, startUrl: otherPage(move), how: 'link from another page'});
			// A link on the guide itself, to its own old id.
			await checkWhenBusy({move, startUrl: `${BASE}/${move.route}`, how: 'same page'});
		}
		await slowContext.close();

		const plainContext = await browser.newContext({javaScriptEnabled: false});
		const plainPage = await plainContext.newPage();
		await plainPage.setViewportSize({width: 1280, height: 800});
		await plainPage.goto(oldLink, {waitUntil: 'load'});
		const stub = await plainPage.evaluate(({elementId, place, frontPage}) =>
		{
			const element = document.getElementById(elementId);
			const box = element?.getBoundingClientRect();
			// Several old ids sent to the same place stand side by side in front of its one link.
			let next = element?.nextElementSibling;
			while(next?.tagName === 'SPAN' && next.id && next.childNodes.length === 0)
			{
				next = next.nextElementSibling;
			}
			// The stub links to the exact new place. Only for a block on the front page may it link to the front page alone,
			// and then the link is to the front page itself, not to any address that ends in a slash.
			const href = next?.tagName === 'A' ? next.getAttribute('href') || '' : '';
			const page = place.includes('#') ? place.slice(0, place.indexOf('#')) : null;
			return {
				url: location.href,
				// An element inside a table cell can stop a fraction of a pixel above the top edge.
				shown: box ? box.top > -1 && box.top < window.innerHeight : false,
				linksOn: href !== '' && (href.endsWith(place) || (page === '/' && href.replace(/#.*$/, '') === frontPage))
			};
		}, {elementId: oldId, place: target, frontPage: `${DOCS_BASE}/`});
		await plainContext.close();
		assert(stub.url === oldLink && stub.shown && stub.linksOn,
			`with scripts off, an old sub-heading link lands on its stub (${stub.url}, in view: ${stub.shown}, next to its link: ${stub.linksOn})`);

		await page.goto(`${BASE}/${route}`, {waitUntil: 'networkidle'});
		const otherId = await page.evaluate((movedIds) => [...document.querySelectorAll('.vp-doc h2[id]')].map(heading => heading.id).find(id => !movedIds.includes(id)), moved.movedIds);
		await page.goto(`${BASE}/${route}#${otherId}`, {waitUntil: 'networkidle'});
		await sleep(MARKER_MOVE_MS);
		assert(page.url() === `${BASE}/${route}#${otherId}`, `a hash that is not in movedAnchors is left alone (${page.url()})`);

		// The page opens first on another site, so Back has somewhere outside this site to go.
		const historyPage = await browser.newPage();
		await historyPage.goto('data:text/html,<title>start</title>');
		await historyPage.goto(oldLink, {waitUntil: 'networkidle'});
		await historyPage.waitForURL(`${BASE}${target}`, {timeout: 10000});
		await historyPage.goBack({waitUntil: 'load'});
		await sleep(MARKER_MOVE_MS);
		const afterBack = historyPage.url();
		await historyPage.close();
		assert(afterBack.startsWith('data:'), `Back after a moved-anchor redirect leaves the site's history without returning to the redirect (${afterBack})`);
	}

	// 15. The front page's examples sit in four groups, and only the first starts open. An old guide link
	//     sent to an example opens that example: in the open group and in a closed one, by its address and
	//     by a link clicked on another page of the site. A closed group is opened first, then the page
	//     scrolls to the example, so its top is in view just under the top bar.
	await page.setViewportSize({width: 1280, height: 800});
	await page.goto(`${BASE}/`, {waitUntil: 'networkidle'});
	const groupsOnLoad = await page.evaluate(() => [...document.querySelectorAll('details.kl-group')].map(group => ({id: group.id, open: group.open})));
	assert(groupsOnLoad.length === 4 && groupsOnLoad[0].open && groupsOnLoad.slice(1).every(group => !group.open),
		`the front page has four example groups and only the first starts open (${JSON.stringify(groupsOnLoad)})`);
	const frontPageMoves = [
		{route: 'dml-guide', oldId: 'why-choose-this-over-the-built-in-option', id: 'saving-records', group: 'group-read-and-save-data'},
		{route: 'administration-tools-guide', oldId: 'when-the-native-salesforce-tool-is-enough', id: 'consoles', group: 'group-build-test-and-run'}
	];
	// The example's group is open, and the example's top is in view, under the top bar and not far below it.
	const exampleShown = (id, group) => page.evaluate(({elementId, groupId}) =>
	{
		const top = document.getElementById(elementId)?.getBoundingClientRect().top;
		const bar = document.querySelector('.VPNav')?.getBoundingClientRect().bottom ?? 0;
		return {open: document.getElementById(groupId)?.open === true, top: Math.round(top), bar: Math.round(bar), shown: top >= bar - 1 && top < 300};
	}, {elementId: id, groupId: group});
	for(const move of frontPageMoves)
	{
		const oldLink = `${BASE}/${move.route}#${move.oldId}`;
		await page.goto(oldLink, {waitUntil: 'networkidle'});
		await page.waitForURL(`${BASE}/#${move.id}`, {timeout: 10000});
		await sleep(MARKER_MOVE_MS);
		let state = await exampleShown(move.id, move.group);
		assert(state.open && state.shown, `an old guide address sent to the front page opens its example (${oldLink}: group open ${state.open}, top ${state.top}, bar ${state.bar})`);

		await page.goto(`${BASE}/fast-starts`, {waitUntil: 'networkidle'});
		await page.evaluate((linkHref) =>
		{
			const link = document.createElement('a');
			link.href = linkHref;
			link.textContent = 'old link';
			document.body.appendChild(link);
			link.click();
		}, `${DOCS_BASE}/${move.route}#${move.oldId}`);
		await page.waitForURL(`${BASE}/#${move.id}`, {timeout: 10000});
		await sleep(MARKER_MOVE_MS);
		state = await exampleShown(move.id, move.group);
		assert(state.open && state.shown, `an old guide link clicked on another page opens its front-page example (${move.route}#${move.oldId}: group open ${state.open}, top ${state.top}, bar ${state.bar})`);
	}

	// A link in the list of features opens its example's group, scrolls to the example and replaces the
	// address, so Back does not step through every jump.
	await page.goto(`${BASE}/`, {waitUntil: 'networkidle'});
	const historyBefore = await page.evaluate(() => window.history.length);
	await page.click('a.kl-index-link[href="#code-scanning"]');
	await sleep(MARKER_MOVE_MS);
	const jumped = await exampleShown('code-scanning', 'group-build-test-and-run');
	const afterJump = await page.evaluate(() => ({hash: window.location.hash, length: window.history.length}));
	assert(jumped.open && jumped.shown && afterJump.hash === '#code-scanning' && afterJump.length === historyBefore,
		`a link in the list of features opens its example in place (group open ${jumped.open}, top ${jumped.top}, ${JSON.stringify(afterJump)}, history before ${historyBefore})`);

	// A group's "Back to all features" link scrolls back to the list of features and replaces the
	// address. Its click must not reach the group's own toggle, so the group stays open.
	const backLink = page.locator('#group-build-test-and-run a.kl-back');
	await backLink.scrollIntoViewIfNeeded();
	await backLink.click();
	await sleep(MARKER_MOVE_MS);
	const back = await page.evaluate(() =>
	{
		const top = document.getElementById('jump-to-a-feature')?.getBoundingClientRect().top;
		const bar = document.querySelector('.VPNav')?.getBoundingClientRect().bottom ?? 0;
		return {
			hash: window.location.hash,
			length: window.history.length,
			top: Math.round(top),
			bar: Math.round(bar),
			groupOpen: document.getElementById('group-build-test-and-run')?.open === true
		};
	});
	assert(back.hash === '#jump-to-a-feature' && back.length === historyBefore && back.top >= back.bar - 1 && back.top < 300 && back.groupOpen,
		`a group's "Back to all features" link returns to the list of features in place and leaves the group open (${JSON.stringify(back)}, history before ${historyBefore})`);

	// 16. "Expand all" over the front page's example groups is a button, so the keyboard reaches it. While a
	//     group is closed it reads "Expand all" and is not expanded. Enter opens every group, and the button
	//     then reads "Collapse all" and is expanded. Space closes every group again and flips it back.
	await page.goto(`${BASE}/`, {waitUntil: 'networkidle'});
	const expandAll = page.locator('button#kl-expand-all');
	const groupsOpen = () => page.evaluate(() => [...document.querySelectorAll('details.kl-group')].map(group => group.open));
	const expandAllState = async() => ({text: (await expandAll.innerText()).trim(), expanded: await expandAll.getAttribute('aria-expanded'), open: await groupsOpen()});
	assert(await expandAll.count() === 1, 'the front page has one "Expand all" button over its example groups');
	let expandState = await expandAllState();
	assert(expandState.text === 'Expand all' && expandState.expanded === 'false' && expandState.open.some(open => !open),
		`"Expand all" starts not expanded while a group is closed (${JSON.stringify(expandState)})`);
	await expandAll.focus();
	await page.keyboard.press('Enter');
	await page.waitForFunction(() => document.getElementById('kl-expand-all')?.getAttribute('aria-expanded') === 'true', null, {timeout: 5000});
	expandState = await expandAllState();
	assert(expandState.text === 'Collapse all' && expandState.open.length > 0 && expandState.open.every(Boolean),
		`Enter on "Expand all" opens every group and the button reads "Collapse all" (${JSON.stringify(expandState)})`);
	await page.keyboard.press('Space');
	await page.waitForFunction(() => document.getElementById('kl-expand-all')?.getAttribute('aria-expanded') === 'false', null, {timeout: 5000});
	expandState = await expandAllState();
	assert(expandState.text === 'Expand all' && expandState.open.every(open => !open),
		`Space on "Collapse all" closes every group and the button reads "Expand all" again (${JSON.stringify(expandState)})`);

	console.log('render smoke-test PASSED');
}
finally
{
	if(browser)
	{
		await browser.close();
	}
	try
	{
		process.kill(-server.pid, 'SIGTERM');
	}
	catch
	{
		server.kill('SIGTERM');
	}
}
