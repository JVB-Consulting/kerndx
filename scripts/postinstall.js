// SPDX-License-Identifier: BUSL-1.1
'use strict';

// Conditional husky install — runs only inside a git working tree.
//
// Path 3 subscribers (the pipeline-flavored zip) unpack KernDX into a
// non-git directory and run `npm ci --omit=dev`. Husky's default
// `postinstall: "husky install"` fails with "no .git directory" in that
// scenario, breaking the install. This wrapper detects the missing .git
// and skips husky cleanly instead.

const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');

const repoRoot = path.resolve(__dirname, '..');
const gitDir = path.join(repoRoot, '.git');

if(!fs.existsSync(gitDir))
{
	console.log('[postinstall] .git not present — skipping husky install (zip distribution scenario)');
	process.exit(0);
}

const result = spawnSync('npx', [
	'husky',
	'install'
], {stdio: 'inherit', cwd: repoRoot});
process.exit(result.status === null ? 1 : result.status);
