// SPDX-License-Identifier: MIT
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const pc = require('picocolors');
const { resolveDiffBase } = require('../lib/diff-base.js');
const { loadConfig } = require('../lib/config-loader.js');
const { runSfca, checkSfPresent, checkSfcaPluginPresent } = require('../lib/sfca-runner.js');

// shell: false (default). See sfca-runner.js — pathspecs must reach
// git verbatim and shell: true triggers Node's DEP0190 warning.
const SPAWN_OPTS = { encoding: 'utf-8' };

const SCAN_EXTENSIONS = ['cls', 'trigger', 'js', 'html', 'flow-meta.xml'];

function scanPatternsFor(packageDirs) {
	const patterns = [];
	for (const dir of packageDirs) {
		for (const ext of SCAN_EXTENSIONS) {
			patterns.push(`${dir}/**/*.${ext}`);
		}
	}
	return patterns;
}

function resolveChangedFiles(base, patterns) {
	const diff = spawnSync('git', ['diff', '--name-only', `${base}...HEAD`, '--', ...patterns], SPAWN_OPTS);
	if (diff.status !== 0) return null;
	return diff.stdout.split('\n').map(s => s.trim()).filter(Boolean).filter(f => fs.existsSync(f));
}

function readStdinSync() {
	try { return fs.readFileSync(0, 'utf-8'); } catch { return ''; }
}

async function scanCommand({ ci = false, configPath = '.kerndx/config.yml' } = {}) {
	const isCi = !!ci;
	const config = loadConfig(configPath);

	if (!isCi) {
		if (!checkSfPresent()) {
			console.log(pc.yellow('Salesforce CLI (`sf`) not found on PATH — skipping local scan. CI will catch.'));
			return 0;
		}
		if (!checkSfcaPluginPresent()) {
			console.log(pc.yellow('SFCA plugin not installed — run `sf plugins install code-analyzer`. Skipping.'));
			return 0;
		}
	}

	const stdinText = readStdinSync();
	const base = resolveDiffBase(stdinText);
	process.stderr.write(`[scan] diff base: ${base}\n`);

	const patterns = scanPatternsFor(config.package_dirs);
	const files = resolveChangedFiles(base, patterns);
	if (files === null) {
		console.log(pc.yellow('Could not resolve changed files. Skipping scan.'));
		return 0;
	}
	if (files.length === 0) {
		console.log(pc.green('No Apex/Trigger/LWC/Flow changes to scan.'));
		return 0;
	}
	process.stderr.write(`[scan] ${files.length} file(s) to scan\n`);

	const result = runSfca({
		workspace: config.package_dirs[0],
		configFile: 'code-analyzer.yml',
		ruleSelector: (config.scanner && config.scanner.rule_selector) || 'pmd,flow,eslint',
		files,
		severityThreshold: isCi ? null : (config.scanner && config.scanner.severity_threshold) || 1,
	});

	if (result.status !== 0) {
		if (isCi) {
			console.error(pc.red('SFCA reported Sev-1 violations. CI must block.'));
			return 1;
		}
		console.log(pc.yellow('SFCA reported violations above. Advisory — your push proceeds.'));
		console.log('   CI will block this PR if any Sev-1 is unfixed.');
	}
	return 0;
}

module.exports = { scanCommand, scanPatternsFor, resolveChangedFiles };
