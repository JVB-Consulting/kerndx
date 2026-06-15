// SPDX-License-Identifier: MIT
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const pc = require('picocolors');
const {runInit} = require('./init.js');
const {loadConfig} = require('../lib/config-loader.js');

async function runUpgrade({force = false} = {})
{
	if(!fs.existsSync('.kerndx/manifest.json'))
	{
		console.error(pc.red('No .kerndx/manifest.json — has `init` been run?'));
		return 1;
	}
	const manifest = JSON.parse(fs.readFileSync('.kerndx/manifest.json', 'utf-8'));

	const blocking = Object.keys(manifest.files).filter(f => fs.existsSync(f + '.bak'));
	if(blocking.length > 0)
	{
		if(force)
		{
			console.warn(pc.yellow(`Deleting ${blocking.length} stale .bak file(s) (--force):`));
			for(const b of blocking)
			{
				const bakPath = b + '.bak';
				console.warn('  -', bakPath);
				fs.unlinkSync(bakPath);
			}
		}
		else
		{
			console.error(pc.red('Existing .bak files block this upgrade:'));
			for(const b of blocking)
			{
				console.error('  -', b + '.bak');
			}
			console.error('\nReview + delete the .bak files, then re-run upgrade.');
			console.error('Or skip the review with: kerndx upgrade --force');
			console.error('Or run: rm ' + blocking.map(b => `'${b}.bak'`).join(' '));
			return 1;
		}
	}

	for(const file of Object.keys(manifest.files))
	{
		if(fs.existsSync(file))
		{
			fs.copyFileSync(file, file + '.bak');
		}
	}

	const config = loadConfig('.kerndx/config.yml');
	const answers = {
		package_dirs: config.package_dirs,
		ci_adapter: config.ci_adapter,
		branches: config.branches,
		naming: config.naming || {enabled: false},
		slack: (config.notifications && config.notifications.slack) || {enabled: false},
		workflows: config.workflows || {runs_on: 'ubuntu-latest'}
	};
	await runInit({answers, interactive: false});

	console.log(pc.green('Upgrade complete.'));
	console.log(`Backups: ${Object.keys(manifest.files).length} file(s) saved as .bak`);
	console.log('Compare your edits using `git diff` or your IDE\'s diff tool.');
	return 0;
}

module.exports = {runUpgrade};
