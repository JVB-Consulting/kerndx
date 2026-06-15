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
	// on web-services-guide, and the 30 `__c` field anchors on a reference object page.
	await page.setViewportSize({width: 1280, height: 800});
	for(const route of ['/web-services-guide', '/reference/objects/apicall-c'])
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

	// 7. Home is the public README (subscriber-facing), not the internal maintainer one.
	await page.goto(`${BASE}/`, {waitUntil: 'networkidle'});
	const homeText = await page.locator('.vp-doc').innerText();
	assert(!homeText.includes('Private Development Repo'), 'home is the public README, not the internal dev one');

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
