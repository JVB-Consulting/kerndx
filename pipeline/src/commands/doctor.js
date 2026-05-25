// SPDX-License-Identifier: MIT
'use strict';
const fs = require('node:fs');
const pc = require('picocolors');
const { hashFile } = require('../lib/hash.js');
const { loadConfig } = require('../lib/config-loader.js');
const { checkSfPresent, checkSfcaPluginPresent } = require('../lib/sfca-runner.js');

/**
 * Validate the kerndx-pipeline installation in the current working directory.
 *
 * Checks performed (in order):
 *  1. Environment — sf CLI on PATH, SFCA plugin installed (skipped when skipEnvironmentChecks=true)
 *  2. Config — .kerndx/config.yml exists and passes schema validation
 *  3. Manifest drift — each file listed in .kerndx/manifest.json is present on disk and
 *     its LF-normalized SHA-256 matches the hash recorded at init time
 *
 * @param {object}  [opts]
 * @param {boolean} [opts.verbose=false]              - Print upgrade hint on drift.
 * @param {boolean} [opts.skipEnvironmentChecks=false] - Skip sf CLI / SFCA plugin checks (for tests).
 * @returns {Promise<number>} 0 if all checks pass, 1 if any issues found.
 */
async function runDoctor({ verbose = false, skipEnvironmentChecks = false } = {})
{
	const issues = [];

	if (!skipEnvironmentChecks)
	{
		if (!checkSfPresent()) issues.push('sf CLI not on PATH');
		if (!checkSfcaPluginPresent()) issues.push('SFCA plugin not installed (sf plugins install code-analyzer)');
	}

	try
	{
		loadConfig('.kerndx/config.yml');
	}
	catch (e)
	{
		issues.push(`config: ${e.message}`);
	}

	if (fs.existsSync('.kerndx/manifest.json'))
	{
		const manifest = JSON.parse(fs.readFileSync('.kerndx/manifest.json', 'utf-8'));
		for (const [file, expectedHash] of Object.entries(manifest.files))
		{
			if (!fs.existsSync(file))
			{
				issues.push(`missing scaffolded file: ${file}`);
				continue;
			}
			const actualHash = hashFile(file);
			if (actualHash !== expectedHash)
			{
				issues.push(`drift: ${file}`);
			}
		}
	}
	else
	{
		issues.push('.kerndx/manifest.json missing — run `./.kerndx-pipeline/bin/kerndx init`');
	}

	if (issues.length === 0)
	{
		console.log(pc.green('All checks pass.'));
		return 0;
	}

	console.log(pc.red(`Found ${issues.length} issue(s):`));
	for (const i of issues) console.log('  -', i);
	if (verbose) console.log('\nRun `upgrade` to refresh scaffolded files (preserves your edits as .bak).');
	return 1;
}

module.exports = { runDoctor };
