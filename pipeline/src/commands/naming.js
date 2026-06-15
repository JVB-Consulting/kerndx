// SPDX-License-Identifier: MIT
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const pc = require('picocolors');
const {resolveDiffBase} = require('../lib/diff-base.js');
const {loadConfig} = require('../lib/config-loader.js');

// shell: false (default). Pathspecs like 'force-app/**/*.flow-meta.xml'
// must reach git verbatim so git applies its own pathspec matching.
// Passing args via shell: true triggered Node's DEP0190 deprecation
// warning AND risked the shell pre-expanding the glob.
const SPAWN_OPTS = {encoding: 'utf-8'};

/**
 * Build the glob patterns used to detect changed Flow + Object artefacts.
 *
 * @param {string[]} packageDirs - SFDX package directory paths.
 * @returns {string[]} Glob patterns for git diff --name-only.
 */
function namingPatternsFor(packageDirs)
{
	const patterns = [];
	for(const dir of packageDirs)
	{
		patterns.push(`${dir}/**/*.flow-meta.xml`);
		patterns.push(`${dir}/**/objects/**/*`);
	}
	return patterns;
}

/**
 * Read stdin synchronously without blocking when there is no piped input.
 *
 * @returns {string} Raw stdin text or empty string.
 */
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

/**
 * Execute the naming validation command.
 *
 * @param {object} [opts]
 * @param {boolean} [opts.ci=false] - Exit non-zero on violation when true.
 * @param {string}  [opts.configPath='.kerndx/config.yml'] - Config file path.
 * @returns {Promise<number>} Exit code (0 = pass/advisory, 1 = CI failure).
 */
async function namingCommand({ci = false, configPath = '.kerndx/config.yml'} = {})
{
	const config = loadConfig(configPath);
	if(!config.naming || !config.naming.enabled)
	{
		console.log(pc.dim('Naming validation not enabled in config — skipping.'));
		return 0;
	}

	const stdinText = readStdinSync();
	const base = resolveDiffBase(stdinText);
	process.stderr.write(`[naming] diff base: ${base}\n`);

	const patterns = namingPatternsFor(config.package_dirs);
	const diff = spawnSync('git', [
		'diff',
		'--name-only',
		`${base}...HEAD`,
		'--',
		...patterns
	], SPAWN_OPTS);
	if(diff.status !== 0)
	{
		console.log(pc.yellow('Could not resolve changed naming files. Skipping.'));
		return 0;
	}
	const files = diff.stdout.split('\n').map(s => s.trim()).filter(Boolean);
	if(files.length === 0)
	{
		console.log(pc.green('No Flow or Object changes to validate.'));
		return 0;
	}

	// Phase C.7 wires naming-engine here. For now: NO-OP placeholder.
	const engine = require('../naming-engine/index.js');
	const result = await engine.validate({files, config: config.naming});

	if(result.violations.length > 0)
	{
		console.log('');
		for(const v of result.violations)
		{
			console.log(pc.red(`✘ ${v.file}: ${v.rule} — ${v.message}`));
		}
		console.log('');
		console.log(`Total: ${result.violations.length} violation(s) across ${new Set(result.violations.map(v => v.file)).size} artefacts.`);
		if(ci)
		{
			return 1;
		}
		console.log(pc.yellow('Advisory — your push proceeds. CI will block this PR.'));
	}
	else
	{
		console.log(pc.green(`All ${files.length} file(s) pass naming validation.`));
	}
	return 0;
}

module.exports = {namingCommand, namingPatternsFor};
