// SPDX-License-Identifier: MIT
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const pc = require('picocolors');
const {resolveDiffBase} = require('../lib/diff-base.js');
const {loadConfig} = require('../lib/config-loader.js');
const {runSfca, checkSfPresent, checkSfcaPluginPresent, pmdApexVersionWarning} = require('../lib/sfca-runner.js');

// shell: false (default). See sfca-runner.js — pathspecs must reach
// git verbatim and shell: true triggers Node's DEP0190 warning.
const SPAWN_OPTS = {encoding: 'utf-8'};

const SCAN_EXTENSIONS = [
	'cls',
	'trigger',
	'js',
	'html',
	'flow-meta.xml'
];

function scanPatternsFor(packageDirs)
{
	const patterns = [];
	for(const dir of packageDirs)
	{
		for(const ext of SCAN_EXTENSIONS)
		{
			patterns.push(`${dir}/**/*.${ext}`);
		}
	}
	return patterns;
}

function resolveChangedFiles(base, patterns)
{
	const diff = spawnSync('git', [
		'diff',
		'--name-only',
		`${base}...HEAD`,
		'--',
		...patterns
	], SPAWN_OPTS);
	if(diff.status !== 0)
	{
		return null;
	}
	return diff.stdout.split('\n').map(s => s.trim()).filter(Boolean).filter(f => fs.existsSync(f));
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

// The sfca-quality-gate workflow blocks a PR on any severity 1 OR 2 violation,
// and KernDX priority-1 PMD rules surface as SFCA severity 2 ("High") — so the
// CI threshold must be 2 for `kerndx scan --ci` to block what the gate blocks.
const CI_SEVERITY_THRESHOLD = 2;

function resolveSeverityThreshold(isCi, config)
{
	return isCi ? CI_SEVERITY_THRESHOLD : (config.scanner && config.scanner.severity_threshold) || 1;
}

// The runSfcaFn/checkSfFn/checkPluginFn options exist for the same reason
// sfca-runner's verdict helpers take injectable probes: the CI-blocking
// branches below must be testable without a live sf install. Production
// callers pass none of them.
async function scanCommand({ci = false, configPath = '.kerndx/config.yml', stdinText, runSfcaFn = runSfca, checkSfFn = checkSfPresent, checkPluginFn = checkSfcaPluginPresent} = {})
{
	const isCi = !!ci;
	const config = loadConfig(configPath);

	// Locally a missing sf/plugin downgrades to a skip (CI catches it); in CI
	// mode the scan IS the gate, so a missing tool is a loud failure — not a
	// misleading "violations found" and not a silent pass.
	if(!checkSfFn())
	{
		if(isCi)
		{
			console.error(pc.red('Salesforce CLI (`sf`) not found on PATH — the CI scan gate cannot run.'));
			return 1;
		}
		console.log(pc.yellow('Salesforce CLI (`sf`) not found on PATH — skipping local scan. CI will catch.'));
		return 0;
	}
	if(!checkPluginFn())
	{
		if(isCi)
		{
			console.error(pc.red('SFCA plugin not installed — run `sf plugins install code-analyzer`. The CI scan gate cannot run.'));
			return 1;
		}
		console.log(pc.yellow('SFCA plugin not installed — run `sf plugins install code-analyzer`. Skipping.'));
		return 0;
	}
	if(!isCi)
	{
		const pmdWarning = pmdApexVersionWarning();
		if(pmdWarning)
		{
			console.log(pc.yellow(pmdWarning));
		}
	}

	// stdinText is injectable because readStdinSync blocks forever on an open,
	// empty pipe — which is exactly what node:test gives its worker processes.
	const effectiveStdin = stdinText !== undefined ? stdinText : readStdinSync();
	const base = resolveDiffBase(effectiveStdin, config.branches && config.branches.main);
	process.stderr.write(`[scan] diff base: ${base}\n`);

	const patterns = scanPatternsFor(config.package_dirs);

	// resolveDiffBase's contract: the literal 'HEAD' is the degraded sentinel —
	// no real base exists, and a HEAD...HEAD diff is empty. Diffing would
	// silently pass on any change, so scan the full workspace instead
	// (an empty files list means no --target filters reach sf).
	const degraded = base === 'HEAD';
	let files;
	if(degraded)
	{
		process.stderr.write('[scan] no diff base could be resolved — scanning the full workspace\n');
		files = [];
	}
	else
	{
		files = resolveChangedFiles(base, patterns);
	}
	if(files === null)
	{
		if(isCi)
		{
			console.error(pc.red('Could not resolve changed files — the CI scan gate cannot run.'));
			return 1;
		}
		console.log(pc.yellow('Could not resolve changed files. Skipping scan.'));
		return 0;
	}
	if(!degraded && files.length === 0)
	{
		console.log(pc.green('No Apex/Trigger/LWC/Flow changes to scan.'));
		return 0;
	}
	process.stderr.write(`[scan] ${degraded ? 'full workspace' : `${files.length} file(s)`} to scan\n`);

	const result = runSfcaFn({
		workspace: config.package_dirs[0],
		configFile: 'code-analyzer.yml',
		ruleSelector: (config.scanner && config.scanner.rule_selector) || 'pmd,flow,eslint',
		files,
		severityThreshold: resolveSeverityThreshold(isCi, config)
	});

	if(result.status !== 0)
	{
		if(isCi)
		{
			console.error(pc.red('SFCA reported Critical/High (severity 1-2) violations. CI must block.'));
			return 1;
		}
		console.log(pc.yellow('SFCA reported violations above. Advisory — your push proceeds.'));
		console.log('   CI will block this PR if any Critical/High (severity 1-2) finding is unfixed.');
	}
	return 0;
}

module.exports = {scanCommand, scanPatternsFor, resolveChangedFiles, resolveSeverityThreshold, CI_SEVERITY_THRESHOLD};
