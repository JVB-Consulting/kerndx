// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Answers one question for the ci job: between two commits, did a terminal block in a shipped guide,
 *              or a tool a reader runs, change? Only then is the Windows workflow worth its minutes.
 *              Usage: node scripts/terminal-blocks-changed.js <beforeSha> <afterSha>
 */
'use strict';

const fs = require('fs');
const path = require('path');
const {execFileSync} = require('child_process');
const {extractTerminalBlocks, fingerprint} = require('./lib/terminal-blocks');

const REPOSITORY_ROOT = path.resolve(__dirname, '..');

const WATCHED_PATHS = [
	'bin/', 'pipeline/', 'package.json', '.gitattributes', '.github/workflows/windows.yml',
	'scripts/build-package.js', 'scripts/prepare-package-build.js', 'scripts/postinstall.js', 'scripts/run-docs-commands.js',
	'scripts/terminal-blocks-changed.js', 'scripts/hold-file-watcher.js', 'scripts/docs-commands-register.json',
	'scripts/lib/terminal-blocks.js', 'scripts/lib/stand-in-tools.js', 'scripts/run-shipped-npm-scripts.js',
	'scripts/shipped-npm-scripts-register.json', 'scripts/report-command-shapes.js', 'scripts/lib/start-tool.js', 'eslint.config.mjs'
];
const GUIDE = /^(docs\/[^/]+\.md|bin\/README\.md)$/;
const NO_COMMIT = /^0*$/;

/**
 * @description The guides a register names, wherever they live in the tree.
 * @param {Object} register - The docs command register.
 * @returns {string[]} Repository-relative guide paths, each named once.
 */
function watchedGuides(register)
{
	return [...new Set((register.scopes || []).map(scope => scope.guide))];
}

/**
 * @description Decides from the changed paths and the two versions of each changed guide.
 * @param {{changedPaths: string[], readAt: function(string, string): string, guides?: string[]}} input -
 *        `readAt('before'|'after', path)` returns the file's content at that commit, or an empty string when it
 *        does not exist there. `guides` names extra guide paths a register watches, outside `docs/` and `bin/`.
 * @returns {{changed: boolean, reason: string}} The decision and one plain reason.
 */
function decide({changedPaths, readAt, guides = []})
{
	for(const changedPath of changedPaths)
	{
		if(WATCHED_PATHS.some(watched => changedPath === watched || (watched.endsWith('/') && changedPath.startsWith(watched))))
		{
			return {changed: true, reason: `${changedPath} is a watched path`};
		}
	}
	for(const changedPath of changedPaths.filter(candidate => GUIDE.test(candidate) || guides.includes(candidate)))
	{
		const before = fingerprint(extractTerminalBlocks(readAt('before', changedPath), changedPath));
		const after = fingerprint(extractTerminalBlocks(readAt('after', changedPath), changedPath));
		if(before !== after)
		{
			return {changed: true, reason: `a terminal block changed in ${changedPath}`};
		}
	}
	return {changed: false, reason: 'no terminal block or watched path changed'};
}

module.exports = {WATCHED_PATHS, decide, watchedGuides};

if(require.main === module)
{
	const [beforeSha, afterSha] = process.argv.slice(2);
	if(!beforeSha || !afterSha || NO_COMMIT.test(beforeSha))
	{
		console.log('changed=true there is no earlier commit to compare with');
		process.exit(0);
	}
	const git = args => execFileSync('git', args, {encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore']});
	const shas = {before: beforeSha, after: afterSha};
	const readAt = (which, filePath) =>
	{
		try { return git(['show', `${shas[which]}:${filePath}`]); }
		catch(error) { return ''; }
	};
	const registerPaths = ['scripts/docs-commands-register.json', 'release-testing/windows/real-org-journey-register.json']
		.filter(registerPath => fs.existsSync(path.join(REPOSITORY_ROOT, registerPath)));
	const guides = registerPaths.flatMap(registerPath => watchedGuides(JSON.parse(fs.readFileSync(path.join(REPOSITORY_ROOT, registerPath), 'utf8'))));
	let decision;
	try
	{
		decision = decide({changedPaths: git(['diff', '--name-only', beforeSha, afterSha]).split('\n').filter(Boolean), readAt, guides});
	}
	catch(error)
	{
		decision = {changed: true, reason: 'the two commits could not be compared, so the proof runs to be safe'};
	}
	console.log(`changed=${decision.changed} ${decision.reason}`);
}
