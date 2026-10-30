// SPDX-License-Identifier: Apache-2.0
'use strict';

// Conditional husky install — runs only inside a git working tree.
//
// Path 3 subscribers (the pipeline-flavored zip) unpack KernDX into a
// non-git directory and run `npm ci --omit=dev`. There is nothing for
// husky to do in that folder: it prints that .git cannot be found and
// exits 0. This wrapper detects the missing .git first and skips husky
// with a message of its own, so npx is never started in a folder that
// has no git tree.
//
// The command is `husky` alone: husky 9 deprecated `husky install` and prints a notice for it on every install.
// npx is started through startTool, because on Windows npx is a .cmd file, which Node will not start without a shell.

const fs = require('node:fs');
const path = require('node:path');
const {startTool} = require('./lib/start-tool');

const repoRoot = path.resolve(__dirname, '..');
const gitDir = path.join(repoRoot, '.git');

if(!fs.existsSync(gitDir))
{
	console.log('[postinstall] .git not present — skipping husky install (zip distribution scenario)');
	process.exit(0);
}

const result = startTool('npx', ['husky'], {stdio: 'inherit', cwd: repoRoot});
if(result.error)
{
	console.error(`[postinstall] could not start "npx husky": ${result.error.message}`);
}
process.exit(result.status === null ? 1 : result.status);
