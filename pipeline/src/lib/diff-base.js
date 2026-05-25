// SPDX-License-Identifier: MIT
// pipeline/src/lib/diff-base.js
//
// Resolve a git diff base for "what did this push change?" queries.
// Three inputs considered, in order:
//   1. Pre-push hook stdin: "<local_ref> <local_sha> <remote_ref> <remote_sha>"
//      (passed by git to pre-push hooks — see `man githooks`)
//   2. Merge-base with origin/main
//   3. HEAD~20 (last-resort fallback)
//
// Always returns a resolvable git ref. Callers use it as `<base>...HEAD` for
// git diff invocations.

const { execSync } = require('node:child_process');

const ZERO_SHA = '0000000000000000000000000000000000000000';

function run(cmd)
{
	return execSync(cmd, { encoding: 'utf-8' }).trim();
}

function tryRun(cmd)
{
	try { return run(cmd); } catch { return null; }
}

/**
 * Parse the pre-push hook stdin format.
 * Returns { remoteSha } on success, null if not in pre-push format.
 */
function parsePrePushStdin(stdinText)
{
	if (!stdinText) return null;
	// Format: "<local_ref> <local_sha> <remote_ref> <remote_sha>\n" (possibly multiple lines if batched push)
	// We only need the first line's remote_sha.
	const first = stdinText.split('\n')[0].trim();
	const parts = first.split(/\s+/);
	if (parts.length !== 4) return null;
	return { remoteSha: parts[3] };
}

/**
 * Resolve the diff base. Returns a git-resolvable ref string.
 * Options:
 *   stdinText — raw pre-push stdin (or null/undefined when called from CLI).
 */
function resolveDiffBase(stdinText)
{
	const prePush = parsePrePushStdin(stdinText);

	// Case 1: real pre-push invocation with a non-zero remote sha.
	if (prePush && prePush.remoteSha !== ZERO_SHA)
	{
		// Sanity-check the sha resolves (local clone may be behind remote).
		if (tryRun(`git cat-file -e ${prePush.remoteSha}`) !== null || tryRun(`git rev-parse --verify ${prePush.remoteSha}`) !== null)
		{
			return prePush.remoteSha;
		}
	}

	// Case 2: new branch being pushed (remote sha = zeros) OR no stdin — use merge-base with origin/main.
	const mb = tryRun('git merge-base HEAD origin/main');
	if (mb) return mb;

	// Case 3: origin/main not reachable — last-ditch fallback.
	const fallback = tryRun('git rev-parse HEAD~20');
	if (fallback) return fallback;

	// Fully detached, no history — return HEAD so diff-to-HEAD returns empty.
	return 'HEAD';
}

module.exports = { resolveDiffBase, parsePrePushStdin };
