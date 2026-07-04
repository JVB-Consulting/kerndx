// SPDX-License-Identifier: MIT
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');

// shell: false (default). Passing pathspec args like 'force-app/**/*.cls'
// with shell: true triggers Node's DEP0190 deprecation warning AND risks
// the shell expanding the glob before git/sf sees it. Both tools accept
// argv directly, so no shell is needed.
const SPAWN_OPTS = {encoding: 'utf-8'};

function buildSfcaArgs({workspace, configFile, ruleSelector, files, severityThreshold})
{
	const args = [
		'code-analyzer',
		'run',
		'--workspace',
		workspace,
		'--config-file',
		configFile,
		'--rule-selector',
		ruleSelector
	];
	if(severityThreshold !== null && severityThreshold !== undefined)
	{
		args.push('--severity-threshold', String(severityThreshold));
	}
	for(const f of files)
	{
		args.push('--target', f);
	}
	return args;
}

function runSfca({workspace, configFile, ruleSelector, files, severityThreshold, stdio = 'inherit'})
{
	const args = buildSfcaArgs({workspace, configFile, ruleSelector, files, severityThreshold});
	return spawnSync('sf', args, {...SPAWN_OPTS, stdio});
}

function checkSfPresent()
{
	const result = spawnSync('sf', ['--version'], SPAWN_OPTS);
	return result.status === 0;
}

// `sf plugins --json` dumps every plugin's full command manifest — several MB
// on a machine with many plugins — which overflows spawnSync's default 1 MB
// maxBuffer and surfaces as ENOBUFS (status null, truncated stdout). Give it
// room so the JSON parses. Single runner shared by every `sf plugins` consumer.
const SF_PLUGINS_MAX_BUFFER = 64 * 1024 * 1024;

function runPluginsJson()
{
	const result = spawnSync('sf', [
		'plugins',
		'--json'
	], {...SPAWN_OPTS, maxBuffer: SF_PLUGINS_MAX_BUFFER});
	return result.status === 0 ? result.stdout : null;
}

// Pure: does the `sf plugins --json` payload list the code-analyzer plugin?
function pluginsJsonHasCodeAnalyzer(pluginsJson)
{
	try
	{
		const plugins = JSON.parse(pluginsJson);
		return Array.isArray(plugins) && plugins.some(p => (p.name || '').includes('plugin-code-analyzer'));
	}
	catch
	{
		return false;
	}
}

function checkSfcaPluginPresent()
{
	return pluginsJsonHasCodeAnalyzer(runPluginsJson());
}

// --- PMD apex-module version guard -----------------------------------------
//
// The custom rulesets under scanner/ are mostly XPath rules evaluated against
// the Apex AST, plus one standard PMD rule bundled by reference
// (InvocableClassNoArgConstructor, category/apex/errorprone.xml). KernDX does
// not pin PMD directly — it arrives transitively through whatever PMD jars the
// Salesforce Code Analyzer plugin bundles. Three thresholds bracket the safe
// range:
//
//   * minimum  — the rulesets reference a rule that only exists at or above
//     this version (InvocableClassNoArgConstructor landed in PMD 7.26.0). Below
//     it the Code Analyzer cannot resolve the reference and the WHOLE ruleset
//     fails to load, so this is a hard floor surfaced loudly (status 'below').
//   * validated — the version the rules were last verified against.
//   * ceiling  — the next version we have not yet re-validated against; crossing
//     it warns a human to re-run the deliberate-violation fixtures in case the
//     Apex AST shifted under the XPath rules. Advisory only — it never blocks.

const PMD_APEX_MODULE_MINIMUM_VERSION = '7.26.0';
const PMD_APEX_MODULE_VALIDATED_VERSION = '7.26.0';
const PMD_APEX_MODULE_CEILING_VERSION = '7.27.0';

const PMD_APEX_JAR_PATTERN = /^pmd-apex-(\d+(?:\.\d+)*)\.jar$/;
const PMD_ENGINE_LIB_SEGMENTS = [
	'node_modules',
	'@salesforce',
	'code-analyzer-pmd-engine',
	'dist',
	'java-lib'
];

function parseVersionTuple(version)
{
	if(typeof version !== 'string')
	{
		return null;
	}
	const trimmed = version.trim();
	if(!/^\d+(\.\d+)*$/.test(trimmed))
	{
		return null;
	}
	return trimmed.split('.').map(Number);
}

function compareVersionTuples(a, b)
{
	const len = Math.max(a.length, b.length);
	for(let i = 0; i < len; i++)
	{
		const x = a[i] ?? 0;
		const y = b[i] ?? 0;
		if(x !== y)
		{
			return x < y ? -1 : 1;
		}
	}
	return 0;
}

// Classify a bundled pmd-apex version against the minimum / validated / ceiling.
// Returns { status: 'below' | 'ok' | 'ahead' | 'unknown', version, minimum,
// validated, ceiling, message }.
function classifyPmdApexVersion(version)
{
	const verdict = {
		version: version == null ? null : version, minimum: PMD_APEX_MODULE_MINIMUM_VERSION, validated: PMD_APEX_MODULE_VALIDATED_VERSION, ceiling: PMD_APEX_MODULE_CEILING_VERSION, message: null
	};
	const tuple = parseVersionTuple(version);
	if(!tuple)
	{
		return {...verdict, status: 'unknown'};
	}
	const minimum = parseVersionTuple(PMD_APEX_MODULE_MINIMUM_VERSION);
	if(compareVersionTuples(tuple, minimum) < 0)
	{
		return {
			...verdict,
			status: 'below',
			message: `PMD apex module ${version} bundled by Salesforce Code Analyzer is older than the `
					+ `${PMD_APEX_MODULE_MINIMUM_VERSION} minimum the KernDX scanner/ rulesets require `
					+ `(InvocableClassNoArgConstructor was added in PMD 7.26.0; below it the ruleset cannot load). `
					+ `Upgrade the plugin: sf plugins update.`
		};
	}
	const ceiling = parseVersionTuple(PMD_APEX_MODULE_CEILING_VERSION);
	if(compareVersionTuples(tuple, ceiling) >= 0)
	{
		return {
			...verdict,
			status: 'ahead',
			message: `PMD apex module ${version} bundled by Salesforce Code Analyzer is newer than the validated `
					+ `${PMD_APEX_MODULE_VALIDATED_VERSION} baseline. Re-validate the scanner/ rulesets `
					+ `against the deliberate-violation fixtures before trusting scan results.`
		};
	}
	return {...verdict, status: 'ok'};
}

// Pull the code-analyzer plugin's install root out of `sf plugins --json` text.
function parsePluginRoot(pluginsJson)
{
	try
	{
		const plugins = JSON.parse(pluginsJson);
		if(!Array.isArray(plugins))
		{
			return null;
		}
		const entry = plugins.find(p => (p.name || '').includes('plugin-code-analyzer'));
		return (entry && entry.root) || null;
	}
	catch
	{
		return null;
	}
}

// Pull the version out of the pmd-apex-<ver>.jar in a dist/java-lib listing.
function parsePmdApexVersion(jarFilenames)
{
	if(!Array.isArray(jarFilenames))
	{
		return null;
	}
	for(const name of jarFilenames)
	{
		const match = PMD_APEX_JAR_PATTERN.exec(name);
		if(match)
		{
			return match[1];
		}
	}
	return null;
}

function defaultListJarDir(dir)
{
	try
	{
		return fs.readdirSync(dir);
	}
	catch
	{
		return null;
	}
}

// Resolve the pmd-apex module version SFCA actually bundles on this machine.
// Returns a version string, or null if it cannot be determined for any reason
// (no sf CLI, plugin absent, layout changed). Never throws on the default path;
// the shipped call sites pass no deps, so the status-guarded runner and the
// try/catch jar lister are always used.
function getBundledPmdApexVersion(deps = {})
{
	const readPluginsJson = deps.runPluginsJson || runPluginsJson;
	const listJarDir = deps.listJarDir || defaultListJarDir;

	const root = parsePluginRoot(readPluginsJson());
	if(!root)
	{
		return null;
	}
	const libDir = path.join(root, ...PMD_ENGINE_LIB_SEGMENTS);
	const files = listJarDir(libDir);
	if(!files)
	{
		return null;
	}
	return parsePmdApexVersion(files);
}

// Detect + classify the SFCA-bundled pmd-apex version in one call. Returns the
// full verdict ({ status, version, message, ... }) so callers can branch on
// 'ahead' vs 'unknown' (e.g. doctor --verbose surfaces 'unknown').
function pmdApexVersionVerdict(deps = {})
{
	return classifyPmdApexVersion(getBundledPmdApexVersion(deps));
}

// Convenience for the scan preflight, which only cares about the loud cases.
// Returns the warning text when the bundled version is below the hard minimum
// or ahead of the validated baseline, else null.
function pmdApexVersionWarning(deps = {})
{
	const verdict = pmdApexVersionVerdict(deps);
	return (verdict.status === 'below' || verdict.status === 'ahead') ? verdict.message : null;
}

module.exports = {
	buildSfcaArgs,
	runSfca,
	checkSfPresent,
	checkSfcaPluginPresent,
	pluginsJsonHasCodeAnalyzer,
	classifyPmdApexVersion,
	parsePluginRoot,
	parsePmdApexVersion,
	getBundledPmdApexVersion,
	pmdApexVersionVerdict,
	pmdApexVersionWarning,
	PMD_APEX_MODULE_MINIMUM_VERSION,
	PMD_APEX_MODULE_VALIDATED_VERSION,
	PMD_APEX_MODULE_CEILING_VERSION,
};
