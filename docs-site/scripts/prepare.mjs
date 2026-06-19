// SPDX-License-Identifier: BUSL-1.1
import {readFile, writeFile, mkdir, rm, readdir, cp} from 'node:fs/promises';
import {existsSync} from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
import {buildSlugMap, slugForPath} from './slug.mjs';
import {generateSidebar} from './generate-nav.mjs';
import {transformDetails} from './details-transform.mjs';
import {escapeAngles} from './markdown-safety.mjs';
import {rewriteLinks} from './link-normalizer.mjs';
import {extractHeadingIds, rewriteAnchors} from './anchor-normalizer.mjs';
import {rewriteHomeLinks} from './home.mjs';
import {resolvePackageVersion} from './package-version.mjs';
import {cleanMetaDescription} from './meta-description.mjs';
import {parseFrontmatter, stringifyFrontmatter} from './frontmatter.mjs';
import {diffSlugs, loadLock} from './slug-lock.mjs';
import {sourceRepoRelForPage} from './sitemap-lastmod.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');   // docs-site/
const REPO = path.resolve(ROOT, '..');                                          // repo root
const DOCS = path.join(REPO, 'docs');
const RELEASE_NOTES = path.join(REPO, 'release-notes');
const SRC = path.join(ROOT, 'src');
// Committed static assets (robots.txt, og-image, favicon) — src/ is gitignored +
// mirror-blacklisted, so these are sourced from docs-site/assets/ and copied into
// the (regenerated) src/public/ each build. VitePress serves src/public/* at the
// site root, so they land at dist root (e.g. /robots.txt, /og-image.png).
const ASSETS = path.join(ROOT, 'assets');
const MANIFEST = path.join(REPO, 'distribution', 'public-mirror-manifest.json');

async function walk(dir, base = dir)
{
	const out = [];
	for(const entry of await readdir(dir, {withFileTypes: true}))
	{
		const full = path.join(dir, entry.name);
		if(entry.isDirectory())
		{
			out.push(...await walk(full, base));
		}
		else if(entry.name.endsWith('.md'))
		{
			out.push(path.posix.relative(base, full).split(path.sep).join('/'));
		}
	}
	return out;
}

// The site materializes exactly what ships to the published repo. Some docs (e.g.
// internal Strategic Guides) are excluded from the mirror artifact, so they must not
// become site pages upstream either — otherwise the local build would carry pages the
// production (mirror) build never sees, with links to never-shipped internal files. The
// mirror's exclusion set lives in the manifest's `blacklist_assertions`. Read it when
// present (upstream); on the mirror the manifest itself is excluded, but the stripped
// docs are already absent from docs/, so this is a no-op there.
async function loadMirrorExcludedDocSet()
{
	let manifest;
	try
	{
		manifest = JSON.parse(await readFile(MANIFEST, 'utf8'));
	}
	catch
	{
		return new Set();
	}
	return mirrorExcludedDocSetFromManifest(manifest);
}

// Pure: turn a parsed manifest into the docs-relative exclusion set. Degrades gracefully on a
// malformed manifest — a missing, non-array, or non-string-bearing blacklist_assertions yields
// an empty set rather than a TypeError that would crash the whole prepare run.
export function mirrorExcludedDocSetFromManifest(manifest)
{
	const set = new Set();
	const list = manifest && manifest.blacklist_assertions;
	if(!Array.isArray(list))
	{
		return set;
	}
	for(const entry of list)
	{
		if(typeof entry === 'string' && entry.startsWith('docs/') && entry.endsWith('.md') && !entry.includes('*'))
		{
			set.add(entry.slice('docs/'.length));
		}
	}
	return set;
}

// Placeholder/example reference docs (SEL_Foobar, TRG_Foobar, UTIL_FormulaContext.FoobarContext,
// Foobar__c) are scaffolding, not real public API — never materialize them as live site pages.
function isPlaceholderRef(rel)
{
	return rel.startsWith('reference/') && /Foobar/i.test(path.posix.basename(rel));
}

// Skipping the placeholder pages leaves real reference pages with `[SEL_Foobar](SEL_Foobar.md)`
// cross-links that now target nothing. They're intentional skips, not typos, so neutralize each
// such link to its plain link text (mirrors how home.mjs strips unbundleable local images) rather
// than letting rewriteLinks flag it unresolved and hard-fail the build. `currentRelDir` is the
// POSIX dir of the source file relative to docs/ ('' for top-level).
function unlinkPlaceholderRefs(body, currentRelDir)
{
	return body.replace(/\[([^\]]+)\]\(([^)\s]+)(\s+"[^"]*")?\)/g, (whole, text, href) =>
	{
		const [pathPart] = href.split('#');
		if(!/\.md$/i.test(pathPart))
		{
			return whole;
		}
		let decoded;
		try
		{
			decoded = decodeURIComponent(pathPart);
		}
		catch
		{
			decoded = pathPart;
		}
		const targetRel = path.posix.normalize(path.posix.join(currentRelDir, decoded)).replace(/^(\.\/)+/, '');
		return isPlaceholderRef(targetRel) ? text : whole;
	});
}

// Collect docs/ and release-notes/ link targets in a repo-root-relative body (the README home,
// AGENTS, or a release note) that DON'T resolve to a site slug. rewriteHomeLinks silently
// degrades these to a GitHub blob URL, so without this check a broken home→docs link ships
// unnoticed — unlike a regular docs page, where rewriteLinks already feeds the hard-fail gate.
// `currentDir` is the body's own directory relative to the repo root ('' for README/AGENTS,
// 'release-notes' for a release note). Returns the unresolved raw hrefs.
function unresolvedHomeLinks(body, slugMap, currentDir = '')
{
	const out = [];
	const re = /\]\(([^)\s]+)(\s+"[^"]*")?\)/g;
	let m;
	while((m = re.exec(body)) !== null)
	{
		const href = m[1];
		if(/^(https?:|mailto:|tel:|#)/i.test(href))
		{
			continue;
		}
		let decoded;
		try
		{
			decoded = decodeURIComponent(href);
		}
		catch
		{
			decoded = href;
		}
		const rawFile = decoded.includes('#') ? decoded.slice(0, decoded.indexOf('#')) : decoded;
		// Only .md targets map to a site slug — bare directory links (./docs/, ./docs/reference/)
		// and other repo files (LICENSE) are intentional GitHub-blob fallbacks, not broken pages.
		if(!/\.md$/i.test(rawFile))
		{
			continue;
		}
		const repoRel = path.posix.normalize(path.posix.join(currentDir, rawFile)).replace(/^(\.\/)+/, '');
		if(repoRel.startsWith('docs/'))
		{
			if(slugMap.get(repoRel.slice('docs/'.length)) === undefined)
			{
				out.push(href);
			}
		}
		else if(repoRel.startsWith('release-notes/'))
		{
			if(slugMap.get(repoRel) === undefined)
			{
				out.push(href);
			}
		}
	}
	return out;
}

// PURE core. No filesystem, no process.exit, no console. Fully deterministic — every
// input is supplied; every output is returned. main() is the I/O shell around this.
//
//   docInputs:      [{ relPath, raw }]  relPath relative to docs/, raw = file text
//   readme:         string|null         repo-root README.md body source (home page)
//   agents:         string|null         repo-root AGENTS.md body source (/agents page)
//   mirrorExcluded: Set<string>         docs-relative paths to skip
//   locked:         string[]            slugs.lock.json slugs
//   redirects:      object              redirects.json map
//
// Returns { writes, pages, sidebar, unresolved, slugDiff, currentSlugs }.
export function buildSitePlan({docInputs, readme, agents, releaseNotes, mirrorExcluded, locked, redirects})
{
	const excluded = mirrorExcluded || new Set();
	const rawByRel = new Map(docInputs.map(d => [
		d.relPath,
		d.raw
	]));
	// A draft:true page is excluded from the sidebar AND must not be materialized into src/ at
	// all — a routable draft page is an orphan/leak. Skip drafts (and mirror-excluded docs, and
	// placeholder Foobar reference scaffolding) up front so they never enter the slug map, the
	// writes, or the page list.
	const isDraft = (rel) => parseFrontmatter(rawByRel.get(rel)).data.draft === true;
	const docRel = docInputs
	.map(d => d.relPath)
	.filter(rel => !excluded.has(rel))
	.filter(rel => !isPlaceholderRef(rel))
	.filter(rel => !isDraft(rel));
	const releaseNoteList = releaseNotes || [];

	// Slug map keyed by path relative to docs/. README and AGENTS handled specially.
	const slugMap = buildSlugMap(docRel);
	// The injected home ('') and /agents ('agents') slugs bypass buildSlugMap's collision guard.
	// A real doc that slugs to either would silently clobber the home/agents page, so guard the
	// injected slugs here the same way buildSlugMap guards doc-vs-doc collisions.
	const occupant = (target) => docRel.find(rel => slugMap.get(rel) === target);
	if(readme != null && occupant('') !== undefined)
	{
		throw new Error(`Slug collision: "${occupant('')}" maps to "/" but the home page (README) already owns it`);
	}
	if(agents != null && occupant('agents') !== undefined)
	{
		throw new Error(`Slug collision: "${occupant('agents')}" maps to "/agents" but the AGENTS page already owns it`);
	}
	slugMap.set('__README__', '');         // home
	slugMap.set('__AGENTS__', 'agents');   // on-site page
	// Release notes live at repo-root release-notes/; key them with that prefix so the home
	// page and any cross-reference resolve to their site slug (registered before the home is
	// rewritten below).
	for(const {relPath} of releaseNoteList)
	{
		slugMap.set(`release-notes/${relPath}`, slugForPath(relPath));
	}

	const pages = [];
	const unresolved = [];

	// Pass 1 — materialize every page's body (frontmatter, <details>, angle-escaping,
	// cross-file link resolution) and record the heading ids VitePress will mint for it, so
	// pass 2 can reconcile in-page anchors against the real id set of any page they target.
	const materialized = [];     // { outRel, slug, fm, body }
	const idsBySlug = new Map();  // slug → Set<heading id>
	const register = (slug, outRel, fm, body) =>
	{
		idsBySlug.set(slug, new Set(extractHeadingIds(body)));
		materialized.push({outRel, slug, fm, body});
	};

	// Regular docs pages.
	for(const rel of docRel)
	{
		const raw = rawByRel.get(rel);
		const {data, content} = parseFrontmatter(raw);
		const currentRelDir = path.posix.dirname(rel) === '.' ? '' : path.posix.dirname(rel);
		let body = escapeAngles(transformDetails(unlinkPlaceholderRefs(content, currentRelDir)));
		const {content: linked, unresolved: unresolvedHere} = rewriteLinks(body, rel, slugMap);
		body = linked;
		for(const u of unresolvedHere)
		{
			unresolved.push(`${rel} → ${u}`);
		}

		// Clean the meta description in-place (omit the key when unusable).
		if(data.description)
		{
			const clean = cleanMetaDescription(data.description);
			if(clean)
			{
				data.description = clean;
			}
			else
			{
				delete data.description;
			}
		}

		const slug = slugMap.get(rel);
		const isIndex = path.posix.basename(rel).toLowerCase() === 'index.md';
		const outRel = slug === '' ? 'index.md' : isIndex ? `${slug}/index.md` : `${slug}.md`;
		const fm = Object.keys(data).length ? stringifyFrontmatter(data) : '';
		register(slug, outRel, fm, body);

		// Title: frontmatter title, else the first H1 (matches what VitePress shows in the
		// <title> tag), else the filename. The H1 fallback keeps index.md pages from being
		// labelled the literal "index" in the sidebar (their H1 is the real section name).
		const h1 = body.match(/^\s{0,3}#\s+(.+?)\s*$/m);
		const derivedTitle = data.title || (h1 ? h1[1].trim() : rel.replace(/\.md$/i, '').split('/').pop());
		pages.push({relPath: rel, slug, frontmatter: data, title: derivedTitle});
	}

	// Home (src/index.md). When the home declares a layout (the landing page uses
	// `layout: page` with a <KernLanding/> component body), preserve its frontmatter and emit
	// the body VERBATIM — escapeAngles / transformDetails / rewriteHomeLinks are markdown-prose
	// transforms that would mangle component tags and intentional HTML. Otherwise (a plain
	// README home) keep the legacy prose pipeline.
	if(readme != null)
	{
		const {data: homeData, content: homeBody} = parseFrontmatter(readme);
		if(homeData.layout)
		{
			register('', 'index.md', stringifyFrontmatter(homeData), homeBody);
		}
		else
		{
			for(const u of unresolvedHomeLinks(homeBody, slugMap))
			{
				unresolved.push(`README.md → ${u}`);
			}
			register('', 'index.md', '', escapeAngles(transformDetails(rewriteHomeLinks(homeBody, slugMap))));
		}
	}

	// AGENTS.md → on-site /agents page.
	if(agents != null)
	{
		const {content: agentsBody} = parseFrontmatter(agents);
		for(const u of unresolvedHomeLinks(agentsBody, slugMap))
		{
			unresolved.push(`AGENTS.md → ${u}`);
		}
		register('agents', 'agents.md', '', escapeAngles(transformDetails(rewriteHomeLinks(agentsBody, slugMap))));
		pages.push({relPath: 'AGENTS.md', slug: 'agents', frontmatter: {title: 'AI Agent Onboarding'}, title: 'AI Agent Onboarding'});
	}

	// Release notes → their own "Release Notes" sidebar section, newest first. They carry no
	// frontmatter, so derive the title from the H1 and order by version descending. Their
	// bodies are repo-root-relative (../docs/…, sibling release notes), so use the home-link
	// rewriter with a release-notes/ current directory.
	for(const {relPath, raw} of releaseNoteList)
	{
		const slug = slugMap.get(`release-notes/${relPath}`);
		const {content} = parseFrontmatter(raw);
		for(const u of unresolvedHomeLinks(content, slugMap, 'release-notes'))
		{
			unresolved.push(`release-notes/${relPath} → ${u}`);
		}
		const body = escapeAngles(transformDetails(rewriteHomeLinks(content, slugMap, 'release-notes')));
		const h1 = body.match(/^#\s+(.+?)\s*$/m);
		const title = h1 ? h1[1].trim() : relPath.replace(/\.md$/i, '');
		const v = relPath.match(/(\d+)\.(\d+)/);
		const order = v ? -(Number(v[1]) * 1000 + Number(v[2])) : 0;
		const data = {title, group: 'Release Notes', order};
		register(slug, `${slug}.md`, stringifyFrontmatter(data), body);
		pages.push({relPath: `release-notes/${relPath}`, slug, frontmatter: data, title});
	}

	// Pass 2 — reconcile each in-page anchor (`#frag`, `/slug#frag`) to the heading id
	// VitePress actually emits. A fragment that resolves to no heading on its target page is
	// collected separately so the caller can gate on dead anchors that the route-only
	// dead-link check never sees.
	const writes = [];
	const unresolvedAnchors = [];
	for(const {outRel, slug, fm, body} of materialized)
	{
		const {content: anchored, unresolved: badAnchors} = rewriteAnchors(body, {currentSlug: slug, idsBySlug});
		for(const a of badAnchors)
		{
			unresolvedAnchors.push(`${outRel} → ${a}`);
		}
		writes.push({outRel, content: fm + anchored});
	}

	const sidebar = generateSidebar(pages);

	// URL-stability gate input.
	const currentSlugs = [...new Set(pages.map(p => p.slug))];
	const slugDiff = diffSlugs(locked, currentSlugs, redirects);

	return {writes, pages, sidebar, unresolved, unresolvedAnchors, slugDiff, currentSlugs};
}

// The docs-site home is the landing tour, authored as a real markdown file at
// docs-site/home.md: a `layout: page` page whose body is the <KernLanding/> component
// (registered in the theme) plus an #examples slot of <CodeCompare> blocks. The code
// snippets are authored as ```apex fences inside that slot so VitePress renders them
// through the site's own shiki Apex theme with a Copy button — the same machinery as
// every other code block. Keeping `layout: page` (and NOT `sidebar: false`) restores the
// left doc sidebar + the mobile hamburger so the tour is navigable. The page body is
// emitted VERBATIM (see buildSitePlan's home branch) so the component tags survive. The
// GitHub README is synthesized separately by the mirror synthesizer.
async function buildDocsHome()
{
	return readFile(path.join(ROOT, 'home.md'), 'utf8');
}

async function loadReleaseNotes()
{
	let names;
	try
	{
		names = (await readdir(RELEASE_NOTES)).filter(n => n.endsWith('.md'));
	}
	catch
	{
		return [];
	}
	const out = [];
	for(const name of names)
	{
		out.push({relPath: name, raw: await readFile(path.join(RELEASE_NOTES, name), 'utf8')});
	}
	return out;
}

// Git last-commit date (YYYY-MM-DD) of one repo-root-relative file, or null when it can't be
// resolved (untracked, or a shallow clone with no history). execFileSync → no shell, so paths
// with spaces ("docs/Fast Starts.md") need no quoting.
function gitDateFor(repoRel, repoRoot)
{
	try
	{
		const out = execFileSync('git', [
			'log',
			'-1',
			'--format=%cs',
			'--',
			repoRel
		], {cwd: repoRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore']}).trim();
		return /^\d{4}-\d{2}-\d{2}$/.test(out) ? out : null;
	}
	catch
	{
		return null;
	}
}

// Build the { slug: 'YYYY-MM-DD' } sitemap-lastmod map from each page's source file. The home
// page (slug '') is materialized but not in `pages`, so it's added explicitly. Pages whose date
// can't be resolved are omitted (a missing <lastmod> is valid; a fabricated uniform date is not).
function buildLastmodMap(pages, repoRoot)
{
	const map = {};
	const entries = [['', sourceRepoRelForPage('', '')]].concat(pages.map(p => [p.slug, sourceRepoRelForPage(p.slug, p.relPath)]));
	for(const [slug, repoRel] of entries)
	{
		if(slug === undefined || map[slug])
		{
			continue;
		}
		const date = gitDateFor(repoRel, repoRoot);
		if(date)
		{
			map[slug] = date;
		}
	}
	return map;
}

async function main()
{
	await rm(SRC, {recursive: true, force: true});
	await mkdir(SRC, {recursive: true});

	// Static SEO/site assets → src/public/ (served at site root by VitePress).
	if(existsSync(ASSETS))
	{
		await cp(ASSETS, path.join(SRC, 'public'), {recursive: true});
		console.log('Copied static assets (robots.txt, og-image, favicon) into src/public/.');
	}

	// Enumerate sources. docs/** plus two repo-root on-site pages, minus the docs the
	// published repo excludes (so the local corpus matches what production builds).
	const mirrorExcluded = await loadMirrorExcludedDocSet();
	const docRel = await walk(DOCS);
	const docInputs = [];
	for(const rel of docRel)
	{
		docInputs.push({relPath: rel, raw: await readFile(path.join(DOCS, rel), 'utf8')});
	}
	const readme = await buildDocsHome();
	const agents = await readFile(path.join(REPO, 'AGENTS.md'), 'utf8').catch(() => null);
	const releaseNotes = await loadReleaseNotes();
	const {locked, redirects} = await loadLock(path.join(ROOT, 'slugs.lock.json'), path.join(ROOT, 'redirects.json'));

	const {writes, pages, sidebar, unresolved, unresolvedAnchors, slugDiff} = buildSitePlan({
		docInputs, readme, agents, releaseNotes, mirrorExcluded, locked, redirects
	});

	// Materialize every planned write under src/.
	for(const {outRel, content} of writes)
	{
		const dest = path.join(SRC, outRel);
		await mkdir(path.dirname(dest), {recursive: true});
		await writeFile(dest, content);
	}

	// Fail loudly on unresolved internal links (better error than VitePress' own).
	if(unresolved.length)
	{
		console.error('Unresolved internal links (fix at source, add a redirect, or include the target):');
		for(const u of unresolved)
		{
			console.error('  ' + u);
		}
		process.exit(1);
	}

	// Fail loudly on in-page anchors that resolve to no heading on their target page —
	// a class of dead link VitePress' route-only dead-link gate never catches.
	if(unresolvedAnchors.length)
	{
		console.error('Unresolved in-page anchors (no heading with that id on the target page):');
		for(const a of unresolvedAnchors)
		{
			console.error('  ' + a);
		}
		process.exit(1);
	}

	// Emit the generated sidebar.
	await writeFile(path.join(ROOT, '.vitepress', 'sidebar.generated.mjs'),
			`// AUTO-GENERATED by scripts/prepare.mjs — do not edit.\nexport default ${JSON.stringify(sidebar, null, 2)}\n`);

	// Emit the per-page sitemap <lastmod> map (git last-commit date of each page's source).
	// config.mjs applies it to the sitemap via transformItems.
	const lastmodMap = buildLastmodMap(pages, REPO);
	await writeFile(path.join(ROOT, '.vitepress', 'lastmod.generated.json'), JSON.stringify(lastmodMap, null, 2) + '\n');
	console.log(`lastmod map: ${Object.keys(lastmodMap).length}/${pages.length + 1} pages dated.`);

	// URL-stability gate.
	const {added, removedWithoutRedirect} = slugDiff;
	const currentSlugs = [...new Set(pages.map(p => p.slug))];
	if(removedWithoutRedirect.length)
	{
		console.error('URL-stability gate FAILED — these published slugs disappeared without a redirects.json entry:');
		for(const s of removedWithoutRedirect)
		{
			console.error('  /' + s);
		}
		console.error('Fix: restore the file, or add "<old-slug>": "<new-slug>" to docs-site/redirects.json.');
		process.exit(1);
	}
	if(added.length && process.env.UPDATE_SLUG_LOCK === '1')
	{
		await writeFile(path.join(ROOT, 'slugs.lock.json'), JSON.stringify({slugs: currentSlugs.sort()}, null, 2) + '\n');
		console.log(`slugs.lock.json updated (+${added.length} new slugs).`);
	}
	else if(added.length)
	{
		console.log(`Note: ${added.length} new slug(s). Run with UPDATE_SLUG_LOCK=1 to record them in slugs.lock.json.`);
	}

	console.log(`prepare:src complete — ${pages.length} pages materialized into src/.`);
}

// Run only as a script, not when imported by tests.
if(process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url))
{
	main().catch(err =>
	{
		console.error(err);
		process.exit(1);
	});
}
