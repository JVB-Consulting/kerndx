// SPDX-License-Identifier: MIT
'use strict';

/**
 * `kerndx secret-scan` — Salesforce-aware secret scan over changed files.
 *
 * Runs the shared pattern set (src/lib/secret-patterns.js) across the set of
 * files changed since the diff base, mirroring `scan`'s changed-files plumbing
 * but over a BROADER file set: secrets leak in .env / .yml / .json / .sh /
 * config files, not just Apex/LWC, so this command does not restrict to the
 * SFCA extension list.
 *
 * Behaviour matches the rest of the pipeline:
 *   - CI mode (`--ci`): exit non-zero when any BLOCKING finding is present.
 *   - Local mode: advisory — report and exit 0 so the push proceeds (CI is the
 *     hard gate), giving the developer a chance to catch a secret first.
 *
 * Suppression (none of which disables the gate):
 *   - inline `// kerndx-secret-allow: <reason>` comment + DEFAULT_STOPWORDS
 *     (handled inside scanText)
 *   - `secret_scanning.ignore_globs` config (path allowlist)
 *   - `.kerndxsecretsignore` fingerprints (`path:ruleId:sha8`) for a confirmed
 *     -safe one-off finding the rules cannot otherwise distinguish.
 */

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
const pc = require('picocolors');
const {resolveDiffBase} = require('../lib/diff-base.js');
const {loadConfig} = require('../lib/config-loader.js');
const {scanText, summarizeFindings} = require('../lib/secret-patterns.js');

const SPAWN_OPTS = {encoding: 'utf-8'};
const MAX_TEXT_FILE_BYTES = 5 * 1024 * 1024;
const IGNORE_FILE = '.kerndxsecretsignore';

const BINARY_EXTENSIONS = new Set([
	'.png',
	'.jpg',
	'.jpeg',
	'.gif',
	'.svg',
	'.ico',
	'.zip',
	'.pdf',
	'.woff',
	'.woff2',
	'.ttf',
	'.otf',
	'.eot',
	'.asset',
	'.resource',
	'.staticresource',
	'.gz',
	'.tgz',
	'.jar',
	'.class',
	'.exe',
	'.dll',
	'.so',
	'.dylib'
]);

/**
 * Stable, commit-independent fingerprint for a finding so a confirmed-safe hit
 * can be suppressed via .kerndxsecretsignore without breaking on rebase or line
 * shifts. Shape: `path:ruleId:<12-char SHA-256 prefix of the matched secret>`.
 *
 * @param {string} file
 * @param {{ruleId:string, match:string}} finding
 * @returns {string}
 */
function fingerprintFinding(file, finding)
{
	const hash = crypto.createHash('sha256').update(String(finding.match), 'utf8').digest('hex').slice(0, 12);
	return `${file}:${finding.ruleId}:${hash}`;
}

/**
 * Parse a .kerndxsecretsignore file's contents into a Set of fingerprints.
 *
 * @param {string|null} content
 * @returns {Set<string>}
 */
function parseIgnoreFile(content)
{
	const set = new Set();
	if(!content)
	{
		return set;
	}
	for(const raw of String(content).split('\n'))
	{
		const line = raw.trim();
		if(!line || line.startsWith('#'))
		{
			continue;
		}
		set.add(line);
	}
	return set;
}

/**
 * Convert a single glob to a RegExp source fragment. Supports a globstar (spans
 * directories), a single star (within a path segment), and `?`.
 *
 * ReDoS-safe by construction. Compiling a "globstar-slash" segment to a nullable
 * cross-slash group is catastrophic when several appear in one glob: they become
 * stacked nullable groups whose any-run can each match across a slash, so a deep
 * non-matching path forces the engine to try every way of partitioning the
 * slashes among the groups (polynomial / exponential backtracking). With both
 * inputs attacker-controlled (ignore_globs from config, paths from PR files)
 * that wedges the scan. Two changes make it linear: (1) collapse consecutive
 * globstar runs so they cannot stack, and (2) compile a globstar-slash to the
 * segment-bounded group "(?:[^slash]+slash)*" (each iteration consumes exactly
 * one segment, so it cannot backtrack ambiguously against a neighbour). BOTH are
 * required.
 *
 * @param {string} glob
 * @returns {string}
 */
function globToRegExpSource(glob)
{
	// Normalize pathological globstar runs BEFORE compiling: collapse runs of 3+
	// stars to a globstar, then collapse consecutive globstar-slash segments to one.
	const g = String(glob).replace(/\*{3,}/g, '**').replace(/(?:\*\*\/)+/g, '**/');
	let out = '';
	for(let i = 0; i < g.length; i++)
	{
		const c = g[i];
		if(c === '*')
		{
			if(g[i + 1] === '*')
			{
				if(g[i + 2] === '/')
				{
					// `**/` → zero or more whole path segments (segment-bounded).
					out += '(?:[^/]+/)*';
					i += 2;
				}
				else
				{
					// trailing / standalone `**` → any remaining characters. Safe as a
					// single run: normalization guarantees it is not adjacent to another
					// globstar, so it cannot stack into ambiguous backtracking.
					out += '[^\\0]*';
					i += 1;
				}
			}
			else
			{
				out += '[^/]*';
			}
		}
		else if(c === '?')
		{
			out += '[^/]';
		}
		else
		{
			out += c.replace(/[.+^${}()|[\]\\]/g, '\\$&');
		}
	}
	return out;
}

/**
 * Build a path matcher from a list of globs. With no globs, matches nothing.
 *
 * @param {string[]} globs
 * @returns {(p:string)=>boolean}
 */
function globsToMatcher(globs)
{
	if(!Array.isArray(globs) || globs.length === 0)
	{
		return () => false;
	}
	const regexes = globs.map(g => new RegExp(`^${globToRegExpSource(g)}$`));
	return (p) => regexes.some(re => re.test(p));
}

function defaultReadFile(file)
{
	try
	{
		if(BINARY_EXTENSIONS.has(path.extname(file).toLowerCase()))
		{
			return null;
		}
		const stat = fs.statSync(file);
		if(stat.size > MAX_TEXT_FILE_BYTES)
		{
			return null;
		}
		const buf = fs.readFileSync(file);
		if(buf.includes(0))
		{
			return null;
		}
		return buf.toString('utf8');
	}
	catch
	{
		return null;
	}
}

/**
 * Scan a list of files. Pure aside from the injectable `readFile`.
 *
 * @param {string[]} files
 * @param {object} [opts]
 * @param {(file:string)=>(string|null)} [opts.readFile] - content reader (null = skip)
 * @param {Array} [opts.customPatterns]
 * @param {string[]} [opts.ignoreGlobs]
 * @param {Set<string>} [opts.ignoreFingerprints]
 * @param {boolean} [opts.includeAdvisory=true]
 * @returns {{findings:Array, blocking:number, advisory:number, ignored:number}}
 */
function scanFiles(files, opts)
{
	const o = opts || {};
	const readFile = o.readFile || defaultReadFile;
	const customPatterns = o.customPatterns || [];
	const includeAdvisory = o.includeAdvisory !== false;
	const isIgnoredPath = globsToMatcher(o.ignoreGlobs || []);
	const ignoreFingerprints = o.ignoreFingerprints || new Set();

	const findings = [];
	let ignored = 0;
	for(const file of (files || []))
	{
		if(isIgnoredPath(file))
		{
			ignored++;
			continue;
		}
		const content = readFile(file);
		if(content === null || content === undefined)
		{
			continue;
		}
		const fileFindings = scanText(content, {customPatterns, includeAdvisory});
		for(const f of fileFindings)
		{
			const fingerprint = fingerprintFinding(file, f);
			if(ignoreFingerprints.has(fingerprint))
			{
				continue;
			}
			findings.push({file, ...f, fingerprint});
		}
	}

	const summary = summarizeFindings(findings);
	return {findings, blocking: summary.blocking, advisory: summary.advisory, ignored};
}

/**
 * Exit-code policy: CI blocks on any blocking finding; local is always advisory.
 *
 * @param {{blocking:number}} summary
 * @param {boolean} isCi
 * @returns {number}
 */
function decideExit(summary, isCi)
{
	return (isCi && summary.blocking > 0) ? 1 : 0;
}

function resolveChangedFiles(base)
{
	const diff = spawnSync('git', [
		'diff',
		'--name-only',
		`${base}...HEAD`
	], SPAWN_OPTS);
	if(diff.status !== 0)
	{
		return null;
	}
	return diff.stdout.split('\n').map(s => s.trim()).filter(Boolean).filter(f => fs.existsSync(f));
}

/**
 * Enumerate the full tracked tree. Used as the fallback when no reliable diff
 * base could be resolved (a degraded base): over-scanning the whole repo is
 * safe, whereas diffing HEAD against HEAD would scan nothing and pass green.
 *
 * @returns {string[]|null} tracked file paths, or null if git is unavailable.
 */
function resolveTrackedFiles()
{
	const ls = spawnSync('git', ['ls-files'], SPAWN_OPTS);
	if(ls.status !== 0)
	{
		return null;
	}
	return ls.stdout.split('\n').map(s => s.trim()).filter(Boolean).filter(f => fs.existsSync(f));
}

function readStdinSync()
{
	try
	{
		return fs.readFileSync(0, 'utf-8');
	}
	catch
	{
		return '';
	}
}

function loadIgnoreFingerprints()
{
	try
	{
		return parseIgnoreFile(fs.readFileSync(IGNORE_FILE, 'utf-8'));
	}
	catch
	{
		return new Set();
	}
}

function reportFinding(f)
{
	const tag = f.tier === 'block' ? pc.red('  SECRET ') : pc.yellow('advisory ');
	console.log(`${tag} ${f.file}:${f.lineNumber}:${f.column}  ${f.ruleId} — ${f.label}  [${f.redacted}]`);
}

/**
 * @param {object} [args]
 * @param {boolean} [args.ci=false]
 * @param {string} [args.configPath='.kerndx/config.yml']
 * @param {string} [args.stdinText] - injected pre-push stdin (test seam; reads fd 0 when omitted).
 * @returns {Promise<number>} exit code
 */
async function secretScanCommand({ci = false, configPath = '.kerndx/config.yml', stdinText} = {})
{
	const isCi = !!ci;
	const config = loadConfig(configPath);
	const sconf = (config && config.secret_scanning) || {};
	// Warnings go to stderr in CI (keeps stdout clean for logs), stdout locally.
	const warn = (msg) => (isCi ? console.error : console.log)(pc.yellow(msg));

	if(sconf.enabled === false)
	{
		if(!isCi)
		{
			console.log(pc.dim('[secret-scan] disabled in config — skipping.'));
		}
		return 0;
	}

	// Establish the diff base.
	//
	// In CI, config.branches.main is NOT trusted: it lives in the PR-authored
	// .kerndx/config.yml, so an attacker could point it at a ref whose diff
	// excludes their secret (an empty diff, or one based on a poisoned ancestor).
	// The only base we trust in CI is GITHUB_BASE_REF — the real PR target branch,
	// injected by the CI platform and not attacker-controllable. So: in CI with NO
	// GITHUB_BASE_REF (a non-GitHub-Actions / non-pull-request runner), scan the
	// FULL tracked tree rather than any config-derived diff base. With
	// GITHUB_BASE_REF present (the shipped GitHub Actions path), use it as the
	// base; the empty-diff fallback below is a second layer of defence.
	const trustedBranch = (process.env.GITHUB_BASE_REF || '').trim();
	const stdin = stdinText === undefined ? readStdinSync() : stdinText;

	let files;
	let degraded = false;
	if(isCi && !trustedBranch)
	{
		degraded = true;
		warn('[secret-scan] No trusted CI base ref (GITHUB_BASE_REF is unset) — scanning the FULL tracked tree rather than a config-derived diff base, which a PR could poison.');
		files = resolveTrackedFiles();
	}
	else
	{
		const defaultBranch = trustedBranch || (config && config.branches && config.branches.main);
		const base = resolveDiffBase(stdin, defaultBranch);
		// 'HEAD' is diff-base's unique "no base resolved" sentinel; diffing
		// HEAD...HEAD scans NOTHING. Scan the full tracked tree instead so a secret
		// cannot slip through on a degraded base (shallow clone, unfetched branch).
		degraded = base === 'HEAD';
		process.stderr.write(`[secret-scan] diff base: ${base}${degraded ? ' (degraded — scanning full tree)' : ''}\n`);
		if(degraded)
		{
			warn('[secret-scan] No reliable diff base (default branch not fetched, shallow clone, or branch mismatch). Scanning the FULL tracked tree instead of a diff so nothing slips through.');
			files = resolveTrackedFiles();
		}
		else
		{
			files = resolveChangedFiles(base);
			// An EMPTY changed-file set in CI is never a clean PR (a PR always
			// changes at least one file) — it means the base was wrong or an
			// already-merged ref. Never report green; over-scan the full tree.
			// Locally an empty diff is a genuine no-op and stays green.
			if(isCi && files !== null && files.length === 0)
			{
				degraded = true;
				warn('[secret-scan] Empty diff in CI (base resolved to HEAD or an already-merged ref) — scanning the FULL tracked tree rather than trusting an empty diff.');
				files = resolveTrackedFiles();
			}
		}
	}

	if(files === null)
	{
		// Surface this loudly — a required check that silently passes because it
		// could not determine what to scan is worse than a noisy warning. Exit 0
		// (consistent with scan/naming) so a transient git state never wedges a PR,
		// but make it visible that NO scan ran.
		warn('[secret-scan] Could not enumerate files to scan (git unavailable). Secret scan did NOT run — verify the repository state.');
		return 0;
	}
	if(files.length === 0)
	{
		// Only reachable on a genuinely empty change set (local) / empty tree.
		console.log(pc.green(`[secret-scan] No ${degraded ? 'tracked' : 'changed'} files to scan.`));
		return 0;
	}

	const ignoreGlobs = Array.isArray(sconf.ignore_globs) ? sconf.ignore_globs : [];
	if(ignoreGlobs.some(g => g === '**' || g === '*'))
	{
		warn('[secret-scan] secret_scanning.ignore_globs contains a catch-all glob ("**" / "*") — this disables the entire scan. Narrow it or remove it.');
	}

	const {findings, blocking, advisory, ignored} = scanFiles(files, {
		ignoreGlobs, ignoreFingerprints: loadIgnoreFingerprints()
	});

	if(files.length > 0 && ignored === files.length)
	{
		warn(`[secret-scan] All ${files.length} candidate file(s) were excluded by secret_scanning.ignore_globs — nothing was scanned. Verify the ignore globs are intentional.`);
	}

	if(findings.length === 0)
	{
		console.log(pc.green(`[secret-scan] No secrets detected in ${files.length} changed file(s).`));
		return 0;
	}

	for(const f of findings)
	{
		reportFinding(f);
	}

	if(blocking > 0)
	{
		if(isCi)
		{
			console.error(pc.red(`[secret-scan] ${blocking} blocking secret finding(s). CI must block.`));
			return 1;
		}
		console.log(pc.yellow(`[secret-scan] ${blocking} blocking + ${advisory} advisory finding(s). Advisory locally — your push proceeds, but CI will block.`));
	}
	else
	{
		console.log(pc.yellow(`[secret-scan] ${advisory} advisory finding(s). Review before pushing.`));
	}
	console.log(
			pc.dim('   Remove + ROTATE any real secret (committed secrets persist in git history). Suppress a confirmed-safe finding with an inline `kerndx-secret-allow: <reason>` comment, a `secret_scanning.ignore_globs` entry, or a `.kerndxsecretsignore` fingerprint line.'));

	return decideExit({blocking, advisory}, isCi);
}

module.exports = {
	secretScanCommand, scanFiles, defaultReadFile, fingerprintFinding, parseIgnoreFile, globToRegExpSource, globsToMatcher, decideExit, resolveChangedFiles, resolveTrackedFiles
};
