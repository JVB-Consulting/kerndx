// SPDX-License-Identifier: BUSL-1.1
'use strict';

// scripts/lib/doc-claim-extractor.js
//
// Pure extractor for "prose file claims" in Markdown docs. Given Markdown
// content, returns the list of file/script references that the prose claims
// exist — backtick-quoted filenames, backtick-quoted paths, and `npm run X`
// invocations.
//
// Used by scripts/validate-docs.js for both source-tree (edit-time) and
// release-artifact (build-time) validation.
//
// No I/O — callers provide the resolver/index. This keeps the extractor
// trivially unit-testable.

const FILE_EXTENSIONS = [
	'md',
	'js',
	'json',
	'yml',
	'yaml',
	'cls',
	'trigger',
	'xml',
	'sh',
	'css',
	'html',
	'mjs',
	'cjs',
	'txt',
	'eta'
];

const EXT_GROUP = FILE_EXTENSIONS.join('|');

// Path/filename char class includes space (file names like
// `docs/Code Conventions - Guide.md` are common in this repo).
const INLINE_PATH_RE = new RegExp('`((?:[A-Za-z0-9_.\\- ]+\\/)+[A-Za-z0-9_.\\- ]+(?:\\.(?:' + EXT_GROUP + '))?)`', 'g');

const INLINE_FILE_RE = new RegExp('`([A-Za-z0-9_.\\- ]+\\.(?:' + EXT_GROUP + '))`', 'g');

const NPM_RUN_RE = /\bnpm run ([a-z0-9:_-]+)/g;

// Subscriber Domain_[Brand_]Layer_Name pattern — tutorial-example Apex class
// references (subscriber creates these), not files that should ship in the
// release artifact. Same shape used in scanner/subscriber-naming-pmd-ruleset.xml.
const SUBSCRIBER_APEX_RE = /^(SLS|ORD|PRD|SVC|SUB|MKT|CMN)_([A-Z]{2,5}_)?(SEL|TRG|FLOW|SVC|BATCH|SCHED|API|REST|DTO|CTRL|UTIL|LOG|IF|QRY|DML|MAP|TST)_[A-Z][A-Za-z0-9]*(_TEST)?\.(cls|trigger)$/;
// FastStart_*_DEMO.cls — Fast Start example class refs (subscriber-side).
const FAST_START_RE = /^FastStart_[A-Z][A-Za-z0-9]+_(DEMO|TEST|DEMO_TEST)\.(cls|trigger)$/;
// Generic Apex class refs ending in .cls/.trigger without prefix — usually
// tutorial examples (subscribers create them).
const TUTORIAL_APEX_RE = /^[A-Z][A-Za-z0-9]+(_TEST)?\.(cls|trigger)$/;
// Version filename like `1.0.0-37.md` — release-testing results convention example.
const VERSION_FILE_RE = /^\d+\.\d+\.\d+(-\d+)?\.md$/;
// `_TEST.cls` and similar — convention/suffix references.
const SUFFIX_CONVENTION_RE = /^_[A-Z][A-Za-z]*\.(cls|trigger|js|md|json|xml|yml|yaml)$/;

// Top-level allowed directories. Path refs not starting with one of these
// are skipped (they're LWC imports `c/foo`, ESLint rule paths `kerndx/foo`,
// platform APIs `lightning/foo`, subscriber-side tutorial paths
// `force-app/...`, IDE config paths `.vscode/...`, etc.).
const DEFAULT_TOP_DIRS = new Set([
	'docs',
	'release-notes',
	'release-testing',
	'bin',
	'scripts',
	'scanner',
	'pipeline',
	'distribution',
]);

function shouldSkipPathRef(ref, topDirs)
{
	if(ref.startsWith('http://') || ref.startsWith('https://'))
	{
		return true;
	}
	if(ref.startsWith('/'))
	{
		return true;
	}
	if(ref.startsWith('~'))
	{
		return true;
	}
	if(ref.startsWith('#'))
	{
		return true;
	}
	if(ref.includes('..'))
	{
		return true;
	}
	if(ref.includes('${') || ref.includes('{{'))
	{
		return true;
	}
	if(ref.includes('<') || ref.includes('>'))
	{
		return true;
	}
	const firstSeg = ref.split('/')[0];
	if(!topDirs.has(firstSeg))
	{
		return true;
	}
	return false;
}

function shouldSkipFilenameRef(ref)
{
	if(ref.startsWith('.'))
	{
		return true;
	}
	if(/^[A-Z_][A-Z0-9_]+$/.test(ref))
	{
		return true;
	}
	if(ref.includes('${') || ref.includes('{{'))
	{
		return true;
	}
	if(ref.includes('<') || ref.includes('>'))
	{
		return true;
	}
	if(SUBSCRIBER_APEX_RE.test(ref))
	{
		return true;
	}
	if(FAST_START_RE.test(ref))
	{
		return true;
	}
	if(TUTORIAL_APEX_RE.test(ref))
	{
		return true;
	}
	if(VERSION_FILE_RE.test(ref))
	{
		return true;
	}
	if(SUFFIX_CONVENTION_RE.test(ref))
	{
		return true;
	}
	return false;
}

// Extract candidate refs from one line. Does NOT apply skip rules — the
// caller decides what's a violation based on its own resolver.
function extractRefsFromLine(line)
{
	const refs = [];
	const seen = new Set();
	let m;
	const pathRe = new RegExp(INLINE_PATH_RE.source, 'g');
	while((m = pathRe.exec(line)) !== null)
	{
		if(!seen.has(m[1]))
		{
			seen.add(m[1]);
			refs.push({type: 'path', ref: m[1]});
		}
	}
	const fileRe = new RegExp(INLINE_FILE_RE.source, 'g');
	while((m = fileRe.exec(line)) !== null)
	{
		if(!seen.has(m[1]))
		{
			seen.add(m[1]);
			refs.push({type: 'filename', ref: m[1]});
		}
	}
	return refs;
}

function extractNpmScriptsFromLine(line)
{
	const scripts = [];
	let m;
	const re = new RegExp(NPM_RUN_RE.source, 'g');
	while((m = re.exec(line)) !== null)
	{
		scripts.push(m[1]);
	}
	return scripts;
}

/**
 * Walk markdown content line-by-line and emit candidate claims.
 *
 * @param {string} content - Markdown content.
 * @param {object} [options]
 * @param {Set<string>} [options.topDirs] - Allowed top-level dirs (defaults to DEFAULT_TOP_DIRS).
 * @param {boolean} [options.skipNpmScriptsInFences=false] - If true, only emit `npm run X` from inside ```bash code blocks (set false to also catch inline prose).
 * @returns {Array<{type: 'path'|'filename'|'npm-script', ref: string, line: number}>}
 *   Candidate claims with apply-skip-rules NOT yet applied.
 *   Caller must filter using applySkipRules() (or its own logic).
 */
function extractClaims(content, options)
{
	options = options || {};
	const topDirs = options.topDirs || DEFAULT_TOP_DIRS;
	const claims = [];
	const lines = content.split('\n');
	let inFence = false;
	let fenceLang = '';

	for(let i = 0; i < lines.length; i++)
	{
		const line = lines[i];
		const lineNum = i + 1;
		const fenceMatch = line.match(/^```(\w*)/);
		if(fenceMatch)
		{
			if(!inFence)
			{
				inFence = true;
				fenceLang = fenceMatch[1].toLowerCase();
			}
			else
			{
				inFence = false;
				fenceLang = '';
			}
			continue;
		}

		// `npm run X` inside bash code blocks AND inline prose
		const npmScripts = extractNpmScriptsFromLine(line);
		for(const script of npmScripts)
		{
			claims.push({type: 'npm-script', ref: script, line: lineNum});
		}

		if(inFence)
		{
			continue;
		}

		const refs = extractRefsFromLine(line);
		for(const {type, ref} of refs)
		{
			if(type === 'path' && shouldSkipPathRef(ref, topDirs))
			{
				continue;
			}
			if(type === 'filename' && shouldSkipFilenameRef(ref))
			{
				continue;
			}
			claims.push({type, ref, line: lineNum});
		}
	}

	return claims;
}

// Glob-style pattern: * matches any non-slash chars; ** matches any chars.
function matchesGlobPattern(ref, pattern)
{
	// Escape regex metacharacters including * (we re-introduce * meaning below)
	const escaped = pattern.replace(/[.+*^${}()|[\]\\]/g, '\\$&');
	const regex = escaped.replace(/\\\*\\\*/g, '.*').replace(/\\\*/g, '[^/]*');
	return new RegExp('^' + regex + '$').test(ref);
}

function isAllowlisted(claim, allowSet)
{
	if(allowSet.has(claim.ref))
	{
		return true;
	}
	// Type-prefixed entry: "npm:scriptname" allowlists an npm-script claim.
	if(claim.type === 'npm-script' && allowSet.has('npm:' + claim.ref))
	{
		return true;
	}
	for(const entry of allowSet)
	{
		if(entry.startsWith('pattern:') && matchesGlobPattern(claim.ref, entry.substring(8)))
		{
			return true;
		}
	}
	return false;
}

module.exports = {
	extractClaims, extractRefsFromLine, extractNpmScriptsFromLine, shouldSkipPathRef, shouldSkipFilenameRef, matchesGlobPattern, isAllowlisted, DEFAULT_TOP_DIRS, FILE_EXTENSIONS
};
