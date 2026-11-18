// SPDX-License-Identifier: Apache-2.0
// Accessibility gate. Builds nothing; serves `vitepress preview` over the existing dist and runs
// axe-core against a representative page set in BOTH colour schemes. Exits non-zero on any
// violation that is not a recorded, dated exception. Run after `npm run build`.
//
// Why this exists alongside the Lighthouse score: Lighthouse's accessibility category is 73 audits
// and is NOT a superset of axe. It omits `nested-interactive` (WCAG 2.0 Level A) entirely, so a
// green Lighthouse score is not evidence of an accessible page. Conversely axe skips rules tagged
// `experimental` by default — which is why a stock axe run does not report
// `label-content-name-mismatch` while Lighthouse does. This harness enables them explicitly so both
// sets are visible from one place.
import {chromium} from '@playwright/test';
import {spawn} from 'node:child_process';
import {createRequire} from 'node:module';
import {readFileSync} from 'node:fs';
import {setTimeout as sleep} from 'node:timers/promises';

const DOCS_BASE = (process.env.DOCS_BASE ?? '/').replace(/\/$/, '');
const BASE = `http://localhost:4173${DOCS_BASE}`;
const axeSource = readFileSync(createRequire(import.meta.url).resolve('axe-core/axe.min.js'), 'utf8');

// One page per structural archetype. Sweeping the whole corpus is a pre-release activity; this set
// is what every CI run can afford, chosen so each distinct page shape is represented: landing,
// hand-written guide, generated API reference, fast start, the install page (which has its own
// touch-target constraint), the media-heavy tour page, and From Plain Apex to KernDX (side-by-side
// code samples).
const PAGES = [
	'/',
	'/selectors-guide',
	'/reference/apex/qry-builder-builder',
	'/fast-start-selectors',
	'/installation',
	'/strategic-guide-overview',
	'/administration-tools-guide',
	'/from-plain-apex-to-kerndx'
];

// Pages also scanned whole at desktop width, where the top bar shows more than on a phone (the
// search button with its keyboard keys, the version badge): the landing page with its job table,
// From Plain Apex to KernDX, a guide, and a reference page with its links to a Fast Start and a guide.
const DESKTOP_PAGES = [
	'/',
	'/from-plain-apex-to-kerndx',
	'/selectors-guide',
	'/reference/apex/qry-builder'
];

// A guide large enough that "On this page" shows main headings with one button to show them all.
const OUTLINE_PAGE = '/selectors-guide';

// Lighthouse's axe tag set plus WCAG 2.2 AA (target-size) and best-practice. `experimental` rules
// are enabled below via `runOnly` not covering them — see ENABLE_EXPERIMENTAL.
const TAGS = [
	'wcag2a',
	'wcag2aa',
	'wcag21a',
	'wcag21aa',
	'wcag22aa',
	'best-practice'
];

// Rules axe classes as `experimental` and therefore skips unless asked for by id. Lighthouse runs
// label-content-name-mismatch, so omitting it here would let a defect pass this gate and fail there.
const ENABLE_EXPERIMENTAL = ['label-content-name-mismatch'];

// Known, tracked exceptions. A violation of a listed rule is REPORTED but does not fail the gate.
// Every entry must name the reason and where it is tracked, so an exception cannot quietly become
// permanent. Removing the last blocker for an entry should mean deleting the entry.
const KNOWN = {};

function collect(results, page, theme, out)
{
	for(const v of results.violations)
	{
		const rec = out.get(v.id) ?? {id: v.id, impact: v.impact, help: v.help, nodes: 0, where: new Set()};
		rec.nodes += v.nodes.length;
		rec.where.add(`${theme} ${page}`);
		rec.sample ??= (v.nodes[0]?.failureSummary ?? '').replace(/\s+/g, ' ').slice(0, 180);
		rec.target ??= v.nodes[0]?.target?.join(' ');
		out.set(v.id, rec);
	}
}

async function waitForServer(timeoutMs = 60000)
{
	const start = Date.now();
	while(Date.now() - start < timeoutMs)
	{
		try
		{
			if((await fetch(BASE)).ok)
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

// `detached` + killing the process GROUP, not the child. Spawning through `npx` puts a wrapper
// process in between, so a plain server.kill() reaps the wrapper and leaves vitepress bound to the
// port. That orphan then serves a STALE file map (sirv indexes the directory once at startup), so
// the next run's freshly built, content-hashed assets 404 and the page never hydrates — which
// reads as a pile of phantom accessibility failures on VitePress's own components. Diagnosed the
// hard way; do not simplify this back to a bare kill().
const server = spawn('npx', [
	'vitepress',
	'preview',
	'--port',
	'4173'
], {stdio: 'ignore', detached: true});
// Detaching puts the child in its own process group (so teardown can kill the group), but the
// handle would otherwise keep this process's event loop alive and the script would hang after
// printing its result instead of exiting. unref() lets Node exit once the work is done.
server.unref();

function stopServer()
{
	try
	{
		process.kill(-server.pid, 'SIGTERM');
	}
	catch
	{
		server.kill();
	}
}
const found = new Map();
let browser;
try
{
	await waitForServer();
	browser = await chromium.launch();
	for(const theme of [
		'light',
		'dark'
	])
	{
		const ctx = await browser.newContext({
			colorScheme: theme,
			viewport: {width: 412, height: 823},
			isMobile: true,
			hasTouch: true,
			deviceScaleFactor: 1.75
		});
		const page = await ctx.newPage();
		// A page that fails to hydrate reports a pile of phantom violations against VitePress's own
		// components (the appearance switch has no aria-label until Vue runs, the skip link is still
		// laid out, and so on) — findings that look real and are entirely an artefact of broken JS.
		// Fail loudly on the cause instead of reporting the symptoms. Any same-origin 4xx/5xx means
		// this run's numbers are worthless.
		const brokenAssets = [];
		page.on('response', (response) =>
		{
			if(response.status() >= 400 && response.url().startsWith(BASE))
			{
				brokenAssets.push(`${response.status()} ${response.url().replace(BASE, '')}`);
			}
		});
		for(const path of PAGES)
		{
			// networkidle, not domcontentloaded: axe must see the hydrated page, not the SSR shell.
			await page.goto(`${BASE}${path}`, {waitUntil: 'networkidle'});
			if(brokenAssets.length)
			{
				throw new Error(`asset(s) failed to load, so the page never hydrated and any result would be phantom — is a stale \`vitepress preview\` still bound to the port?\n  ${brokenAssets.join('\n  ')}`);
			}
			await page.evaluate(axeSource);
			const results = await page.evaluate(
				async ({tags, experimental}) =>
				{
					const base = await window.axe.run(document, {runOnly: {type: 'tag', values: tags}});
					const extra = await window.axe.run(document, {runOnly: {type: 'rule', values: experimental}});
					return {violations: [...base.violations, ...extra.violations]};
				},
				{tags: TAGS, experimental: ENABLE_EXPERIMENTAL}
			);
			collect(results, path, theme, found);
			console.log(`scanned [${theme}] ${path}`);
		}
		await ctx.close();

		// "On this page" sits in the right-hand column, which VitePress shows only from 1280px, so
		// the phone scans above never see it. Scan it on a large guide at desktop width twice: with
		// the section being read open, and with every heading shown (theme/overrides/VPDocOutlineItem.vue).
		// Only the list is scanned here: the rest of the page is scanned at phone width above.
		const desktop = await browser.newContext({colorScheme: theme, viewport: {width: 1440, height: 900}});
		const desktopPage = await desktop.newPage();
		const brokenDesktopAssets = [];
		desktopPage.on('response', (response) =>
		{
			if(response.status() >= 400 && response.url().startsWith(BASE))
			{
				brokenDesktopAssets.push(`${response.status()} ${response.url().replace(BASE, '')}`);
			}
		});
		for(const path of DESKTOP_PAGES)
		{
			await desktopPage.goto(`${BASE}${path}`, {waitUntil: 'networkidle'});
			if(brokenDesktopAssets.length)
			{
				throw new Error(`asset(s) failed to load at desktop width, so any result would be phantom:\n  ${brokenDesktopAssets.join('\n  ')}`);
			}
			await desktopPage.evaluate(axeSource);
			const results = await desktopPage.evaluate(
				async ({tags, experimental}) =>
				{
					const base = await window.axe.run(document, {runOnly: {type: 'tag', values: tags}});
					const extra = await window.axe.run(document, {runOnly: {type: 'rule', values: experimental}});
					return {violations: [...base.violations, ...extra.violations]};
				},
				{tags: TAGS, experimental: ENABLE_EXPERIMENTAL}
			);
			collect(results, `${path} (desktop)`, theme, found);
			console.log(`scanned [${theme}] ${path} at desktop width`);
		}
		await desktopPage.goto(`${BASE}${OUTLINE_PAGE}`, {waitUntil: 'networkidle'});
		await desktopPage.locator('.VPDocAsideOutline li:has(> .section-headings) > a.outline-link').nth(1).click();
		await desktopPage.waitForTimeout(300);
		for(const view of ['section open', 'all headings'])
		{
			if(view === 'all headings')
			{
				await desktopPage.locator('.VPDocAsideOutline button.outline-toggle').click();
			}
			await desktopPage.evaluate(axeSource);
			const results = await desktopPage.evaluate(
				async ({tags, experimental}) =>
				{
					const context = {include: ['.VPDocAsideOutline']};
					const base = await window.axe.run(context, {runOnly: {type: 'tag', values: tags}});
					const extra = await window.axe.run(context, {runOnly: {type: 'rule', values: experimental}});
					return {violations: [...base.violations, ...extra.violations]};
				},
				{tags: TAGS, experimental: ENABLE_EXPERIMENTAL}
			);
			collect(results, `${OUTLINE_PAGE} (desktop, ${view})`, theme, found);
			console.log(`scanned [${theme}] ${OUTLINE_PAGE} at desktop width, "On this page" with ${view}`);
		}
		await desktop.close();
	}
}
finally
{
	stopServer();
}

const blocking = [...found.values()].filter(v => !KNOWN[v.id]);
const known = [...found.values()].filter(v => KNOWN[v.id]);

console.log(`\nscanned ${PAGES.length * 2} page-scans across ${PAGES.length} pages in light + dark, plus ${DESKTOP_PAGES.length} pages`
	+ ` and ${OUTLINE_PAGE}'s "On this page" (twice) at desktop width in each`);

for(const v of known)
{
	console.log(`\nKNOWN [${v.impact}] ${v.id} — ${v.nodes} nodes on ${v.where.size} page-scans`);
	console.log(`  tracked: ${KNOWN[v.id]}`);
}
// A recorded exception that no longer fires is an exception that should be deleted. Say so loudly
// rather than letting the allowlist rot into a list of rules nobody re-checks.
for(const id of Object.keys(KNOWN))
{
	if(!found.has(id))
	{
		console.log(`\nSTALE EXCEPTION: '${id}' is in KNOWN but no longer violates — delete the entry.`);
	}
}
for(const v of blocking)
{
	console.error(`\nFAIL [${v.impact}] ${v.id} — ${v.help}`);
	console.error(`  ${v.nodes} nodes across ${v.where.size} page-scans, e.g. ${[...v.where][0]} :: ${v.target}`);
	console.error(`  ${v.sample}`);
}

if(blocking.length)
{
	console.error(`\n${blocking.length} blocking accessibility violation(s)`);
	process.exit(1);
}
console.log(`\naccessibility gate passed${known.length ? ` (${known.length} tracked exception(s))` : ''}`);
process.exit(0);
