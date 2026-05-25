// SPDX-License-Identifier: MIT
'use strict';
const { spawnSync } = require('node:child_process');

// shell: false (default). Passing pathspec args like 'force-app/**/*.cls'
// with shell: true triggers Node's DEP0190 deprecation warning AND risks
// the shell expanding the glob before git/sf sees it. Both tools accept
// argv directly, so no shell is needed.
const SPAWN_OPTS = { encoding: 'utf-8' };

function buildSfcaArgs({ workspace, configFile, ruleSelector, files, severityThreshold })
{
	const args = [
		'code-analyzer', 'run',
		'--workspace', workspace,
		'--config-file', configFile,
		'--rule-selector', ruleSelector,
	];
	if (severityThreshold !== null && severityThreshold !== undefined)
	{
		args.push('--severity-threshold', String(severityThreshold));
	}
	for (const f of files)
	{
		args.push('--target', f);
	}
	return args;
}

function runSfca({ workspace, configFile, ruleSelector, files, severityThreshold, stdio = 'inherit' })
{
	const args = buildSfcaArgs({ workspace, configFile, ruleSelector, files, severityThreshold });
	return spawnSync('sf', args, { ...SPAWN_OPTS, stdio });
}

function checkSfPresent()
{
	const result = spawnSync('sf', ['--version'], SPAWN_OPTS);
	return result.status === 0;
}

function checkSfcaPluginPresent()
{
	const result = spawnSync('sf', ['plugins', '--json'], SPAWN_OPTS);
	if (result.status !== 0) return false;
	try
	{
		const plugins = JSON.parse(result.stdout);
		return plugins.some(p => (p.name || '').includes('plugin-code-analyzer'));
	}
	catch
	{
		return false;
	}
}

module.exports = { buildSfcaArgs, runSfca, checkSfPresent, checkSfcaPluginPresent };
