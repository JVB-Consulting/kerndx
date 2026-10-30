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
// touch-target constraint), and the media-heavy tour page.
const PAGES = [
	'/',
	'/selectors-guide',
	'/reference/apex/qry-builder-builder',
	'/fast-start-selectors',
	'/installation',
	'/strategic-guide-overview',
	'/administration-tools-guide'
];

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
	}
}
finally
{
	stopServer();
}

const blocking = [...found.values()].filter(v => !KNOWN[v.id]);
const known = [...found.values()].filter(v => KNOWN[v.id]);

console.log(`\nscanned ${PAGES.length * 2} page-scans across ${PAGES.length} pages in light + dark`);

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
