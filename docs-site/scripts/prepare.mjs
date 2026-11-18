// SPDX-License-Identifier: Apache-2.0
import {readFile, writeFile, mkdir, rm, readdir, cp} from 'node:fs/promises';
import {existsSync} from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
import {buildSlugMap, slugForPath} from './slug.mjs';
import {generateSidebar, generateSidebarAreas, isGuidePage, referenceLinksFor} from './generate-nav.mjs';
import {linksForClass, renderLinkLine, insertLinkLine, isApexClassPage} from './reference-links.mjs';
import {groupMembers, insertGroupTable, methodNamesOf, renderGroupTable} from './method-groups.mjs';
import {markdownCopyHeadEntry, markdownCopyPath, renderMarkdownCopy} from './markdown-copy.mjs';
import {transformDetails} from './details-transform.mjs';
import {escapeAngles} from './markdown-safety.mjs';
import {rewriteLinks} from './link-normalizer.mjs';
import {extractHeadingIds, rewriteAnchors} from './anchor-normalizer.mjs';
import {rewriteHomeLinks} from './home.mjs';
import {resolveVersionList} from './package-version.mjs';
import {cleanMetaDescription} from './meta-description.mjs';
import {parseFrontmatter, stringifyFrontmatter} from './frontmatter.mjs';
import {diffSlugs, loadLock} from './slug-lock.mjs';
import {sourceRepoRelForPage} from './sitemap-lastmod.mjs';
import {checkSearchTerms, searchTermsOf} from './search-render.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');   // docs-site/
const REPO = path.resolve(ROOT, '..');                                          // repo root
// Source roots are env-overridable so a frozen version build reads from docs-versions/<X.Y>/
// instead of the live tree. Defaults reproduce the latest (current) build exactly.
const DOCS = process.env.DOCS_SRC ? path.resolve(REPO, process.env.DOCS_SRC) : path.join(REPO, 'docs');
const RELEASE_NOTES = process.env.RELEASE_NOTES_SRC ? path.resolve(REPO, process.env.RELEASE_NOTES_SRC) : path.join(REPO, 'release-notes');
const HOME = process.env.HOME_SRC ? path.resolve(REPO, process.env.HOME_SRC) : path.join(ROOT, 'home.md');
// A frozen snapshot is immutable, so the URL-stability (slug-lock) gate — which guards the
// LIVE tree against silently dropping a published slug — does not apply to it.
const FROZEN = process.env.DOCS_FROZEN === '1';
// The deploy base for this build ('/' for latest, '/X.Y/' for a frozen tree) — mirrors
// config.mjs. Used to base-prefix the landing's raw HTML links (see resolveLandingLinks).
const BASE = process.env.DOCS_BASE || '/';
const SRC = path.join(ROOT, 'src');
// Committed static assets (robots.txt, og-image, favicon) — src/ is gitignored +
// mirror-blacklisted, so these are sourced from docs-site/assets/ and copied into
// the (regenerated) src/public/ each build. VitePress serves src/public/* at the
// site root, so they land at dist root (e.g. /robots.txt, /og-image.png).
const ASSETS = path.join(ROOT, 'assets');
const MANIFEST = path.join(REPO, 'distribution', 'public-mirror-manifest.json');
const SFDX_PROJECT = path.join(REPO, 'sfdx-project.json');
const DOCS_VERSIONS = path.join(REPO, 'docs-versions');

// The landing credibility strip, version badge and API version are data-driven per build: their
// values come from THIS tree's Strategic Guide - Metrics.md, so a frozen line shows its own figures.
// One extraction path is shared with the docs:validate guard (canonicalFigures).
const nodeRequire = createRequire(import.meta.url);
const {canonicalFigures} = nodeRequire(path.join(REPO, 'scripts', 'validate-landing-metrics.js'));

/**
 * @description Base-prefixes and resolves the internal links in the landing home body — the
 * raw `<a href="/…">` ledger chips and `<CodeCompare link="/…">` props. The landing is emitted
 * verbatim (a `layout: page` component body), and VitePress base-rewrites neither raw HTML
 * hrefs nor component props, so on a frozen tree (DOCS_BASE=/X.Y/) these would otherwise leak
 * to the latest tree. Resolution matches the component's resolve(): a page this tree never had
 * → tree home; a missing anchor → page top; otherwise unchanged. The result is prefixed with
 * the tree base so 1.1's landing stays inside /1.1/.
 *
 * @param {string} body
 * @param {Map<string, Set<string>>} idsBySlug
 * @return {string}
 */
function resolveLandingLinks(body, idsBySlug)
{
	const prefix = BASE.replace(/\/$/, '');
	return body.replace(/\b(href|link)="(\/[^"]*)"/g, (whole, attr, href) =>
	{
		if(href.startsWith('//'))
		{
			return whole;                               // protocol-relative — leave alone
		}
		const [slug, anchor] = href.slice(1).split('#');
		let resolved;
		if(slug && !idsBySlug.has(slug))
		{
			resolved = '/';                             // page absent in this tree → home
		}
		else if(anchor && !idsBySlug.get(slug).has(anchor))
		{
			resolved = `/${slug}`;                      // anchor absent → page top
		}
		else
		{
			resolved = href;
		}
		return `${attr}="${prefix}${resolved}"`;
	});
}

// The frozen documentation lines that have a committed snapshot under docs-versions/<X.Y>/.
// Phase 1 has none (→ the switcher lists only "latest"); the freeze step adds 1.1 and 1.2.
// Directory presence is the deploy-truth: a line is only offered once a tree exists for it.
async function listFrozenDocLines()
{
	try
	{
		const entries = await readdir(DOCS_VERSIONS, {withFileTypes: true});
		return entries.filter(e => e.isDirectory() && /^\d+\.\d+$/.test(e.name)).map(e => e.name);
	}
	catch
	{
		return [];
	}
}

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

// How many guides get the "On this page" list that opens by section. They are the guides with the
// most entries in that list, where a full list of main and sub-headings is too long to scan.
const OUTLINE_OPENS_GUIDE_COUNT = 8;

// The number of entries a page shows in "On this page" by default: its main headings (##) and
// sub-headings (###). Lines inside fenced code blocks are code, not headings.
export function countOutlineEntries(markdown)
{
	let count = 0;
	let fence = null;
	for(const line of markdown.split('\n'))
	{
		const marker = line.match(/^\s{0,3}(`{3,}|~{3,})/);
		if(marker)
		{
			if(fence === null)
			{
				fence = marker[1];
			}
			else if(marker[1][0] === fence[0] && marker[1].length >= fence.length && /^\s{0,3}(`+|~+)\s*$/.test(line))
			{
				fence = null;
			}
			continue;
		}
		if(fence === null && /^\s{0,3}#{2,3}\s+\S/.test(line))
		{
			count++;
		}
	}
	return count;
}

// The "On this page" setting a guide gets, from its entry count and its place when guides are
// ordered from most entries to fewest (1 is the largest). The largest guides show main headings
// and open the section being read (outlineOpens, read by theme/overrides/VPDocOutlineItem.vue);
// every other guide shows main headings only.
export function outlineSetting(pageEntryCount, rank)
{
	return pageEntryCount > 0 && rank <= OUTLINE_OPENS_GUIDE_COUNT ? {outlineOpens: true} : {outline: 2};
}

// An old heading id in `movedAnchors` that can stand in an element's id: no space, quote, angle
// bracket, ampersand or "#".
const MOVED_ANCHOR_ID = /^[^\s"'<>&#]+$/;

// Reads a page's `movedAnchors` frontmatter: each old heading id on the page, and the place
// (`/<page-route>#<id>`) the heading moved to. The frontmatter holds it as one line of JSON, which
// parseFrontmatter returns as a string. Returns {} when the page has none, and throws when the value
// is not a JSON object.
export function movedAnchorsOf(data)
{
	const value = data.movedAnchors;
	if(value == null || value === '')
	{
		return {};
	}
	let parsed = value;
	if(typeof value === 'string')
	{
		try
		{
			parsed = JSON.parse(value);
		}
		catch
		{
			parsed = null;
		}
	}
	if(!parsed || typeof parsed !== 'object' || Array.isArray(parsed) || Object.values(parsed).some(target => typeof target !== 'string'))
	{
		throw new Error(`movedAnchors is not a JSON object of "old-id": "/route#id" pairs: ${value}`);
	}
	return parsed;
}

// The ids the landing page's own elements carry (`id="selectors"` on an example block, a group, a
// section), in the order they appear. A component prop written `:id="..."` is not one.
export function landingElementIds(body)
{
	return [...body.matchAll(/(?<![:\w-])id="([^"\s]+)"/g)].map(match => match[1]);
}

// Drops each line that holds only an HTML anchor (`<a id="x"></a>` or `<a name="x"></a>`) whose id a
// heading on the page already has here. A guide puts such a line before a heading so a GitHub link
// lands on it, because GitHub gives the heading another anchor (it keeps `_`, the site makes it
// `-`). On the site the heading carries that id itself, and a second element with it would make the
// id appear twice. Lines inside fenced or indented code blocks, and anchors inside a paragraph, are left as written.
export function dropHeadingAnchorLines(body)
{
	const headingIds = new Set(extractHeadingIds(body));
	let fence = null;
	return body.split('\n').filter(line =>
	{
		const fenceMark = line.match(/^ {0,3}([`~]{3,})/);
		if(fenceMark)
		{
			fence = fence === null ? fenceMark[1][0] : (fenceMark[1][0] === fence ? null : fence);
			return true;
		}
		const anchor = fence === null ? line.match(/^ {0,3}<a\s+(?:id|name)="([^"]+)"\s*><\/a>\s*$/i) : null;
		return !(anchor && headingIds.has(anchor[1]));
	}).join('\n');
}

// Puts an empty element with each moved heading's old id in front of the stub's link to the place
// the heading moved to, so an old link (`/page#old-id`) still scrolls to the stub when scripts are
// off. The theme script (theme/movedAnchors.mjs) sends a reader with scripts on to the new place.
// Returns the new body and a list of problems: an old id that is still a heading on the page, or a
// moved heading the stub does not link to.
function placeMovedAnchors(body, movedAnchors, headingIds)
{
	const problems = [];
	let content = body;
	for(const [oldId, target] of Object.entries(movedAnchors))
	{
		if(!MOVED_ANCHOR_ID.test(oldId))
		{
			problems.push(`movedAnchors "${oldId}" is not a heading id`);
			continue;
		}
		if(headingIds.has(oldId))
		{
			problems.push(`movedAnchors #${oldId} is still a heading on this page`);
			continue;
		}
		// The stub links to the exact new place. Only a block on the front page may be served by a link to the page alone: a guide's
		// "Why KernDX" link to the front page serves every old id sent to a block there. Any other page needs the exact link.
		const linkTo = (place) => new RegExp(`\\[[^\\]]*\\]\\(${place.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(\\s+"[^"]*")?\\)`);
		const page = target.includes('#') ? target.slice(0, target.indexOf('#')) : null;
		const match = content.match(linkTo(target)) ?? (page === '/' ? content.match(linkTo(page)) : null);
		if(!match)
		{
			problems.push(`movedAnchors #${oldId}: the stub has no link to ${target}`);
			continue;
		}
		content = `${content.slice(0, match.index)}<span id="${oldId}"></span>${content.slice(match.index)}`;
	}
	return {content, problems};
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
//   frozen:         boolean             a frozen version tree: no "Reference for this page" links, no "On this page" settings, no "Methods by task" table and no Markdown copies
//   base:           string              the deploy base ('/' for the latest tree), put in front of each page's Markdown copy link
//   searchCases:    object[]|null       the search cases in search-cases.json, which every page's searchTerms are checked against; required unless frozen
//   landingComponent: string|null       the front page component's source (KernLanding.vue), whose section ids a link or a moved heading may name; a frozen tree ignores it
//
// Returns { writes, copies, pages, sidebar, unresolved, slugDiff, currentSlugs }. `copies` holds the
// Markdown copy of each page ({copyPath, content}); the caller writes them under src/public/.
export function buildSitePlan({docInputs, readme, agents, releaseNotes, mirrorExcluded, locked, redirects, frozen = false, base = '/', searchCases = null,
	landingComponent = null})
{
	// Without the case list the search words check below cannot run, and a page's searchTerms would
	// reach the site unchecked. A frozen tree ignores searchTerms, so it needs no list.
	if(!frozen && !Array.isArray(searchCases))
	{
		throw new Error('buildSitePlan needs the search cases from scripts/search-cases.json to check the pages\' searchTerms');
	}
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

	// Slug → title of every Apex reference page, for the "Reference for this page" links of a guide.
	const apexTitles = new Map(docRel.filter(rel => rel.startsWith('reference/apex/')).map(rel => [
		slugMap.get(rel),
		parseFrontmatter(rawByRel.get(rel)).data.title || path.posix.basename(rel, '.md')
	]));

	// Each guide's place when guides are ordered by their "On this page" entry count, largest first
	// (ties by path, so the order is stable). A frozen tree gets no outline settings.
	const outlineRankByRel = new Map();
	if(!frozen)
	{
		docRel
		.map(rel => ({rel, ...parseFrontmatter(rawByRel.get(rel))}))
		.filter(({rel, data}) => isGuidePage({relPath: rel, frontmatter: data}))
		.map(({rel, content}) => ({rel, count: countOutlineEntries(content)}))
		.sort((a, b) => b.count - a.count || a.rel.localeCompare(b.rel))
		.forEach(({rel, count}, index) => outlineRankByRel.set(rel, {count, rank: index + 1}));
	}

	const pages = [];
	const unresolved = [];

	// Pass 1 — materialize every page's body (frontmatter, <details>, angle-escaping,
	// cross-file link resolution) and record the heading ids VitePress will mint for it, so
	// pass 2 can reconcile in-page anchors against the real id set of any page they target.
	const materialized = [];     // { outRel, slug, fm, body, plain, title }
	const idsBySlug = new Map();  // slug → Set<heading id>
	const movedProblems = [];     // a page's movedAnchors that cannot work, reported with the bad anchors
	const searchTermProblems = []; // a page's searchTerms that cannot be read
	const movedTargets = [];      // { outRel, oldId, target }: each target must be a real heading id
	// `plain` is the page's Markdown as written, for its Markdown copy: the same links and added
	// lines as `body`, but none of the changes that let VitePress render it. A page with no copy
	// (the landing page, a frozen tree) passes none.
	const register = (slug, outRel, fm, body, plain = null, title = '') =>
	{
		idsBySlug.set(slug, new Set(extractHeadingIds(body)));
		materialized.push({outRel, slug, fm, body, plain, title});
	};
	// Adds one `key: value` line to the end of a frontmatter block, or makes the block.
	const withFrontmatterLine = (fm, line) => (fm ? fm.replace(/---\n$/, `${line}\n---\n`) : `---\n${line}\n---\n`);
	// Tells browsers and crawlers where the page's Markdown copy is. A JSON list is also a YAML
	// list, which is how VitePress reads frontmatter.
	const withCopyLink = (fm, slug) => (frozen || slug === '' ? fm : withFrontmatterLine(fm, `head: ${JSON.stringify([markdownCopyHeadEntry(slug, base)])}`));

	// Regular docs pages.
	for(const rel of docRel)
	{
		const raw = rawByRel.get(rel);
		const {data, content} = parseFrontmatter(raw);
		const currentRelDir = path.posix.dirname(rel) === '.' ? '' : path.posix.dirname(rel);
		let body = escapeAngles(transformDetails(dropHeadingAnchorLines(unlinkPlaceholderRefs(content, currentRelDir))));
		const {content: linked, unresolved: unresolvedHere} = rewriteLinks(body, rel, slugMap);
		body = linked;
		for(const u of unresolvedHere)
		{
			unresolved.push(`${rel} → ${u}`);
		}
		// The Markdown copy starts from the page as written, and gets the same links and the same added
		// lines (below) as the page body. A link that does not resolve is reported above, from the body.
		let plain = frozen ? null : rewriteLinks(unlinkPlaceholderRefs(content, currentRelDir), rel, slugMap).content;

		// An Apex class page opens with a line that links it to its Fast Start and guide. A frozen
		// tree is left as it was published.
		if(!frozen && isApexClassPage(rel))
		{
			// A target that is not built (a trimmed set of pages) is left out, never linked dead.
			// reference-links.test.mjs checks that every target of the table is a real page.
			const links = linksForClass(path.posix.basename(rel, '.md'));
			for(const key of ['fastStart', 'guide'])
			{
				if(links[key] && !slugMap.has(`${links[key]}.md`))
				{
					delete links[key];
				}
			}
			const linkLine = renderLinkLine(links);
			body = insertLinkLine(body, linkLine);

			// A class listed in GROUPS_BY_CLASS in method-groups.mjs (nine classes) also gets a short table
			// that groups its methods by what you want to do, above the alphabetical list. A worked example
			// on a page that is not built is left out, and so is the link of a group that has none.
			const groups = groupMembers(path.posix.basename(rel, '.md'), methodNamesOf(body))
			.map(g => (slugMap.has(`${g.exampleLink.page}.md`) ? g : {...g, exampleLink: null}));
			const groupTable = renderGroupTable(groups);
			body = insertGroupTable(body, groupTable);
			plain = insertGroupTable(insertLinkLine(plain, linkLine), groupTable);
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

		// Headings that moved to another page keep their old ids on this one (see placeMovedAnchors).
		// A frozen tree is left as it was published, so it ignores movedAnchors.
		let movedAnchors = {};
		if(!frozen)
		{
			try
			{
				movedAnchors = movedAnchorsOf(data);
			}
			catch(error)
			{
				movedProblems.push(`${outRel} → ${error.message}`);
			}
		}
		delete data.movedAnchors;
		// A section's extra search words (search-render.mjs) stay in the page's frontmatter as one
		// line of JSON, where the search index reads them. A frozen tree is left as it was published.
		let searchTermsLine = null;
		if(!frozen && data.searchTerms != null)
		{
			try
			{
				searchTermsLine = `searchTerms: ${JSON.stringify(Object.fromEntries(searchTermsOf(raw)))}`;
			}
			catch(error)
			{
				searchTermProblems.push(`${rel}: ${error.message}`);
			}
		}
		delete data.searchTerms;
		if(Object.keys(movedAnchors).length)
		{
			const placed = placeMovedAnchors(body, movedAnchors, new Set(extractHeadingIds(body)));
			body = placed.content;
			placed.problems.forEach(problem => movedProblems.push(`${outRel} → ${problem}`));
			Object.entries(movedAnchors).forEach(([oldId, target]) => movedTargets.push({outRel, oldId, target}));
		}

		// Title: frontmatter title, else the first H1 (matches what VitePress shows in the
		// <title> tag), else the filename. The H1 fallback keeps index.md pages from being
		// labelled the literal "index" in the sidebar (their H1 is the real section name).
		const h1 = body.match(/^\s{0,3}#\s+(.+?)\s*$/m);
		const derivedTitle = data.title || (h1 ? h1[1].trim() : rel.replace(/\.md$/i, '').split('/').pop());
		const page = {relPath: rel, slug, frontmatter: data, title: derivedTitle};

		// A guide's most used classes go into its own frontmatter, where ReferenceForPage.vue reads
		// them. Inline site data ships on every page, so they never go into the shared sidebar.
		let fm = Object.keys(data).length ? stringifyFrontmatter(data) : '';
		const referenceLinks = !frozen && isGuidePage(page) ? referenceLinksFor({...page, body}, apexTitles) : [];
		if(referenceLinks.length)
		{
			// A JSON list is also a YAML list, which is how VitePress reads frontmatter.
			const line = `referenceForPage: ${JSON.stringify(referenceLinks)}\n`;
			fm = fm ? fm.replace(/---\n$/, `${line}---\n`) : `---\n${line}---\n`;
		}
		// How much of "On this page" a guide shows. A guide that sets its own `outline` keeps it.
		const outlineRank = outlineRankByRel.get(rel);
		if(outlineRank && data.outline == null)
		{
			const setting = outlineSetting(outlineRank.count, outlineRank.rank);
			const lines = Object.entries(setting).map(([key, value]) => `${key}: ${value}\n`).join('');
			fm = fm ? fm.replace(/---\n$/, `${lines}---\n`) : `---\n${lines}---\n`;
		}
		// The theme script reads the moved anchors from the page data. A JSON object is also a YAML map.
		if(Object.keys(movedAnchors).length)
		{
			fm = withFrontmatterLine(fm, `movedAnchors: ${JSON.stringify(movedAnchors)}`);
		}
		if(searchTermsLine)
		{
			fm = withFrontmatterLine(fm, searchTermsLine);
		}
		register(slug, outRel, withCopyLink(fm, slug), body, plain, derivedTitle);
		// Before the anchor pass, so a link to an old id counts as a link to a real place on this page.
		const pageIds = idsBySlug.get(slug);
		Object.keys(movedAnchors).filter(oldId => !pageIds.has(oldId) && MOVED_ANCHOR_ID.test(oldId)).forEach(oldId => pageIds.add(oldId));
		pages.push(page);
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
			// The landing page has no Markdown headings. Its places are the elements it gives an id,
			// such as an example block (<CodeCompare id="selectors">), so a link or a moved heading can
			// land on one. They are known before its own links are resolved, so a link to one is kept.
			// The front page component's own sections (KernLanding.vue, such as #jump-to-a-feature) are
			// places too. Only its template is read, so an id written inside its script is not one.
			// An older version's front page has its own layout, so a frozen tree takes none of them.
			const templateStart = frozen || landingComponent == null ? -1 : landingComponent.indexOf('<template>');
			const componentTemplate = templateStart < 0 ? '' : landingComponent.slice(templateStart, landingComponent.lastIndexOf('</template>'));
			const landingIds = [...landingElementIds(homeBody), ...landingElementIds(componentTemplate)];
			idsBySlug.set('', new Set(landingIds));
			register('', 'index.md', stringifyFrontmatter(homeData), resolveLandingLinks(homeBody, idsBySlug));
			landingIds.forEach(id => idsBySlug.get('').add(id));
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
		register('agents', 'agents.md', withCopyLink('', 'agents'), escapeAngles(transformDetails(rewriteHomeLinks(agentsBody, slugMap))),
				frozen ? null : rewriteHomeLinks(agentsBody, slugMap), 'AI Agent Onboarding');
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
		register(slug, `${slug}.md`, withCopyLink(stringifyFrontmatter(data), slug), body,
				frozen ? null : rewriteHomeLinks(content, slugMap, 'release-notes'), title);
		pages.push({relPath: `release-notes/${relPath}`, slug, frontmatter: data, title});
	}

	// Pass 2 — reconcile each in-page anchor (`#frag`, `/slug#frag`) to the heading id
	// VitePress actually emits. A fragment that resolves to no heading on its target page is
	// collected separately so the caller can gate on dead anchors that the route-only
	// dead-link check never sees.
	const writes = [];
	const copies = [];
	const unresolvedAnchors = [...movedProblems];
	// The place each moved heading went must be a real heading id, written exactly: the theme script
	// sends the reader there as written, with no fuzzy matching. A place with no `#id` is a whole page
	// (a removed section can send its old links to the front page, `/`); the page must exist.
	for(const {outRel, oldId, target} of movedTargets)
	{
		const [route, id] = target.split('#');
		const ids = idsBySlug.get(route.replace(/^\//, '').replace(/\/$/, ''));
		if(!route.startsWith('/') || !ids || (id !== undefined && !ids.has(id)))
		{
			unresolvedAnchors.push(`${outRel} → movedAnchors #${oldId}: ${target} is no heading on the site`);
		}
	}
	for(const {outRel, slug, fm, body, plain, title} of materialized)
	{
		const {content: anchored, unresolved: badAnchors} = rewriteAnchors(body, {currentSlug: slug, idsBySlug});
		for(const a of badAnchors)
		{
			unresolvedAnchors.push(`${outRel} → ${a}`);
		}
		writes.push({outRel, content: fm + anchored});
		// The copy gets the same anchor fixes as the page, so a link in it lands on the same heading.
		// A bad anchor was reported above from the page body.
		if(plain !== null && slug !== '')
		{
			const {content: plainAnchored} = rewriteAnchors(plain, {currentSlug: slug, idsBySlug});
			copies.push({copyPath: markdownCopyPath(slug), content: renderMarkdownCopy({markdown: plainAnchored, title})});
		}
	}

	const sidebar = generateSidebar(pages);

	// URL-stability gate input.
	const currentSlugs = [...new Set(pages.map(p => p.slug))];
	const slugDiff = diffSlugs(locked, currentSlugs, redirects);

	// Every section's extra search words, checked against the headings of every page and against the
	// search cases. A frozen tree ignores them.
	if(!frozen)
	{
		// The AGENTS page and the release notes are pages of the site too, so their headings count.
		const builtPages = [
			...docRel.map(rel => ({name: rel, source: rawByRel.get(rel)})),
			...(agents == null ? [] : [{name: 'AGENTS.md', source: agents}]),
			...releaseNoteList.map(({relPath, raw}) => ({name: `release-notes/${relPath}`, source: raw}))
		];
		searchTermProblems.push(...checkSearchTerms(builtPages, searchCases));
	}

	return {writes, copies, pages, sidebar, unresolved, unresolvedAnchors, slugDiff, currentSlugs, idsBySlug, searchTermProblems: [...new Set(searchTermProblems)]};
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
	return readFile(HOME, 'utf8');
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
		], {
			cwd: repoRoot,
			encoding: 'utf8',
			stdio: [
				'ignore',
				'pipe',
				'ignore'
			]
		}).trim();
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
	const entries = [
		[
			'',
			sourceRepoRelForPage('', '')
		]
	].concat(pages.map(p => [
		p.slug,
		sourceRepoRelForPage(p.slug, p.relPath)
	]));
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
		if(FROZEN)
		{
			// llms.txt is a latest-only routing file: a frozen /X.Y/ tree must not
			// re-serve it, and its links point at the live (latest) pages.
			await rm(path.join(SRC, 'public', 'llms.txt'), {force: true});
		}
		console.log('Copied static assets (robots.txt, llms.txt, og-image, favicon) into src/public/.');
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

	const searchCases = JSON.parse(await readFile(path.join(ROOT, 'scripts', 'search-cases.json'), 'utf8'));
	// The front page component, whose section ids are places a link may name.
	const landingComponent = await readFile(path.join(ROOT, '.vitepress', 'theme', 'components', 'KernLanding.vue'), 'utf8').catch(() => null);
	const {writes, copies, pages, sidebar, unresolved, unresolvedAnchors, slugDiff, idsBySlug, searchTermProblems} = buildSitePlan({
		docInputs, readme, agents, releaseNotes, mirrorExcluded, locked, redirects, frozen: FROZEN, base: BASE, searchCases, landingComponent
	});

	// Fail loudly on a section's search words that are misplaced (see checkSearchTerms in
	// search-render.mjs): a word on a heading the page does not have, a word already in a heading,
	// or a word with no search case in scripts/search-cases.json.
	if(searchTermProblems.length)
	{
		console.error('Search words (searchTerms) that cannot be used:');
		for(const problem of searchTermProblems)
		{
			console.error('  ' + problem);
		}
		process.exit(1);
	}

	// Materialize every planned write under src/.
	for(const {outRel, content} of writes)
	{
		const dest = path.join(SRC, outRel);
		await mkdir(path.dirname(dest), {recursive: true});
		await writeFile(dest, content);
	}

	// The Markdown copies go under src/public/, so they are served as they are at /<slug>.md and are
	// not built into pages (config.mjs leaves out markdown under public/), listed in the sitemap or
	// put in the search index. A frozen tree has none.
	let copyBytes = 0;
	for(const {copyPath, content} of copies)
	{
		const dest = path.join(SRC, 'public', copyPath);
		await mkdir(path.dirname(dest), {recursive: true});
		await writeFile(dest, content);
		copyBytes += Buffer.byteLength(content);
	}
	console.log(`Markdown copies: ${copies.length} written to src/public/ (${(copyBytes / 1024 / 1024).toFixed(1)} MB).`);

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

	// Emit the generated sidebar. A frozen tree keeps its single flat sidebar (an array). The latest
	// tree gets one menu per area, in the compact form of generateSidebarAreas (an object), which
	// throws for a page in no area and so fails the build. config.mjs tells the two apart.
	const sidebarOutput = FROZEN ? sidebar : generateSidebarAreas(pages);
	await writeFile(path.join(ROOT, '.vitepress', 'sidebar.generated.mjs'),
			`// AUTO-GENERATED by scripts/prepare.mjs — do not edit.\nexport default ${JSON.stringify(sidebarOutput, null, 2)}\n`);

	// Emit the per-page sitemap <lastmod> map (git last-commit date of each page's source).
	// config.mjs applies it to the sitemap via transformItems.
	const lastmodMap = buildLastmodMap(pages, REPO);
	await writeFile(path.join(ROOT, '.vitepress', 'lastmod.generated.json'), JSON.stringify(lastmodMap, null, 2) + '\n');
	console.log(`lastmod map: ${Object.keys(lastmodMap).length}/${pages.length + 1} pages dated.`);

	// Emit the version-switcher manifest (mirrors sidebar.generated.mjs): the latest line at
	// "/" plus any frozen docs-versions/<X.Y>/ trees. VersionSwitcher.vue imports this.
	const sfdx = JSON.parse(await readFile(SFDX_PROJECT, 'utf8'));
	const versionList = resolveVersionList(sfdx, await listFrozenDocLines());
	await writeFile(path.join(ROOT, '.vitepress', 'versions.generated.mjs'),
			`// AUTO-GENERATED by scripts/prepare.mjs — do not edit.\nexport default ${JSON.stringify(versionList, null, 2)};\n`);
	console.log(`versions: ${versionList.map(v => v.label + (v.latest ? ' (latest)' : '')).join(', ')}`);

	// Emit this build's landing facts (version label + the four credibility-strip figures).
	// KernLanding.vue imports this. Figures come from THIS tree's Metrics doc, so the latest
	// landing shows the live numbers and a frozen line shows the numbers it shipped with;
	// canonicalFigures throws if a required row is missing, failing the build loudly. The
	// version label is the line being built — DOCS_VERSION for a frozen tree, else the latest.
	const figures = canonicalFigures(await readFile(path.join(DOCS, 'Strategic Guide - Metrics.md'), 'utf8'));
	const currentLabel = FROZEN ? process.env.DOCS_VERSION : (versionList.find(v => v.latest)?.label ?? versionList[0]?.label);
	const thousands = n => String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ',');

	// Resolve the landing's internal links against THIS tree's pages + heading ids, so the
	// shared (latest) landing never deep-links a frozen version to a page or anchor it never
	// had. Absent page → tree home; absent anchor → page top; otherwise unchanged. withBase is
	// applied in the component. The component wraps each resolvable link as resolve('/path'),
	// so this scans for those — a new landing link needs no change here.
	const landingVue = await readFile(path.join(ROOT, '.vitepress', 'theme', 'components', 'KernLanding.vue'), 'utf8');
	const links = {};
	for(const [, href] of landingVue.matchAll(/resolve\('([^']+)'\)/g))
	{
		if(!href.startsWith('/') || links[href])
		{
			continue;
		}
		const [slug, anchor] = href.slice(1).split('#');
		if(slug && !idsBySlug.has(slug))
		{
			links[href] = '/';
		}
		else if(anchor && !idsBySlug.get(slug).has(anchor))
		{
			links[href] = `/${slug}`;
		}
		else
		{
			links[href] = href;
		}
	}
	const redirected = Object.entries(links).filter(([k, v]) => k !== v);

	const landing = {
		version: `v${currentLabel}`,
		globalApiClasses: figures.globalApiClasses,
		productionClasses: figures.productionClasses,
		lwcComponents: figures.lwcComponents,
		apexTests: figures.apexTests,
		apexTestsLabel: thousands(figures.apexTests),
		apiVersion: figures.apiVersion,
		links
	};
	await writeFile(path.join(ROOT, '.vitepress', 'landing.generated.mjs'),
			`// AUTO-GENERATED by scripts/prepare.mjs — do not edit.\nexport default ${JSON.stringify(landing, null, 2)};\n`);
	console.log(
			`landing: ${landing.version} — ${landing.globalApiClasses} global / ${landing.productionClasses} classes / ${landing.lwcComponents} LWC / ${landing.apexTestsLabel} tests / API ${landing.apiVersion}`);
	if(redirected.length)
	{
		console.log(`landing links: ${redirected.length} re-pointed for this tree → ${redirected.map(([k, v]) => `${k}→${v}`).join(', ')}`);
	}

	// Emit this tree's route list to dist root (served at ${base}routes.json). The switcher
	// fetches the TARGET version's routes.json to decide whether the current page exists there,
	// preserving the page on switch or falling back to that tree's home. Logical slugs only
	// (home '' is implicit and always exists).
	const routeSlugs = [...new Set(pages.map(p => p.slug))].filter(Boolean).sort();
	await mkdir(path.join(SRC, 'public'), {recursive: true});
	await writeFile(path.join(SRC, 'public', 'routes.json'), JSON.stringify(routeSlugs) + '\n');
	console.log(`routes.json: ${routeSlugs.length} routes for cross-version switching.`);

	// URL-stability gate — skipped for a frozen snapshot (it is immutable, and its slug set
	// legitimately differs from the live tree's lock; see blocker #2).
	const {added, removedWithoutRedirect} = slugDiff;
	const currentSlugs = [...new Set(pages.map(p => p.slug))];
	if(FROZEN)
	{
		console.log(`prepare:src complete — ${pages.length} frozen pages materialized into src/.`);
		return;
	}
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
