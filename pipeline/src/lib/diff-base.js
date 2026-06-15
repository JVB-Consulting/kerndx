// SPDX-License-Identifier: MIT
// pipeline/src/lib/diff-base.js
//
// Resolve a git diff base for "what did this push change?" queries.
// Three inputs considered, in order:
//   1. Pre-push hook stdin: "<local_ref> <local_sha> <remote_ref> <remote_sha>"
//      (passed by git to pre-push hooks — see `man githooks`)
//   2. Merge-base with origin/<default-branch>
//   3. HEAD~20 (last-resort fallback)
//
// Always returns a resolvable git ref. Callers use it as `<base>...HEAD` for
// git diff invocations.
//
// Security: every git invocation uses execFileSync('git', [args]) — NO shell.
// The default-branch name is interpolated into a ref argument, and that name is
// subscriber-controlled (it comes from `config.branches.main`, which a PR can
// edit). With a shell (the old execSync(`git merge-base HEAD origin/${branch}`))
// a branch value like `main; rm -rf /` would execute. Passing args as an array
// to execFileSync removes the shell entirely; a hostile branch value becomes an
// inert, unresolvable ref string that merely fails the merge-base probe.

const {execFileSync} = require('node:child_process');

const ZERO_SHA = '0000000000000000000000000000000000000000';

/**
 * Run git with an argv array (never a shell string). Throws on non-zero exit.
 * stderr is suppressed: every caller goes through tryGit, and the fallback chain
 * deliberately probes refs that may not exist (origin/<branch>, HEAD~20) — git's
 * raw `fatal:` lines on those expected misses are just noise in CI logs.
 * @param {string[]} args
 * @returns {string}
 */
function runGit(args)
{
	return execFileSync('git', args, {
		encoding: 'utf-8',
		stdio: [
			'ignore',
			'pipe',
			'ignore'
		]
	}).trim();
}

/**
 * Run git, returning null instead of throwing on failure.
 * @param {string[]} args
 * @returns {string|null}
 */
function tryGit(args)
{
	try
	{
		return runGit(args);
	}
	catch
	{
		return null;
	}
}

/**
 * Whether a string is a plausible git object name (hex, 7–64 chars). Guards
 * against an argv-injection style value (e.g. a leading `-`) reaching `git
 * cat-file`/`rev-parse` as if it were an option.
 * @param {string} sha
 * @returns {boolean}
 */
function isHexSha(sha)
{
	return typeof sha === 'string' && /^[0-9a-f]{7,64}$/i.test(sha);
}

/**
 * Parse the pre-push hook stdin format.
 * Returns { remoteSha } on success, null if not in pre-push format.
 */
function parsePrePushStdin(stdinText)
{
	if(!stdinText)
	{
		return null;
	}
	// Format: "<local_ref> <local_sha> <remote_ref> <remote_sha>\n" (possibly multiple lines if batched push)
	// We only need the first line's remote_sha.
	const first = stdinText.split('\n')[0].trim();
	const parts = first.split(/\s+/);
	if(parts.length !== 4)
	{
		return null;
	}
	return {remoteSha: parts[3]};
}

/**
 * Resolve the diff base. Returns a git-resolvable ref string.
 * Options:
 *   stdinText — raw pre-push stdin (or null/undefined when called from CLI).
 *   defaultBranch — the repo's default branch name (from config.branches.main);
 *     defaults to 'main' so existing callers are unaffected. Lets the merge-base
 *     fallback work on repos whose default branch is `master`/`develop`/etc.
 *
 * The literal string 'HEAD' is the unique "degraded" sentinel: it is returned
 * only when no real base could be resolved. Callers MUST treat a 'HEAD' result
 * as "no diff base" (a `git diff HEAD...HEAD` is empty) and react accordingly —
 * e.g. scan the full tree rather than silently reporting nothing changed.
 */
function resolveDiffBase(stdinText, defaultBranch)
{
	const branch = defaultBranch || 'main';
	const prePush = parsePrePushStdin(stdinText);

	// Case 1: real pre-push invocation with a non-zero, plausibly-shaped remote sha.
	if(prePush && prePush.remoteSha !== ZERO_SHA && isHexSha(prePush.remoteSha))
	{
		// Sanity-check the sha resolves (local clone may be behind remote).
		if(tryGit([
			'cat-file',
			'-e',
			prePush.remoteSha
		]) !== null || tryGit([
			'rev-parse',
			'--verify',
			prePush.remoteSha
		]) !== null)
		{
			return prePush.remoteSha;
		}
	}

	// Case 2: new branch being pushed (remote sha = zeros) OR no stdin — use merge-base with the default branch.
	const mb = tryGit([
		'merge-base',
		'HEAD',
		`origin/${branch}`
	]);
	if(mb)
	{
		return mb;
	}

	// Case 3: origin/<branch> not reachable — last-ditch fallback.
	const fallback = tryGit([
		'rev-parse',
		'HEAD~20'
	]);
	if(fallback)
	{
		return fallback;
	}

	// Fully detached, no history — return HEAD (the degraded sentinel; see above).
	return 'HEAD';
}

module.exports = {resolveDiffBase, parsePrePushStdin, isHexSha};
