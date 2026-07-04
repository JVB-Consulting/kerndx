// SPDX-License-Identifier: MIT
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const {
	buildSfcaArgs,
	pluginsJsonHasCodeAnalyzer,
	classifyPmdApexVersion,
	parsePluginRoot,
	parsePmdApexVersion,
	getBundledPmdApexVersion,
	pmdApexVersionVerdict,
	pmdApexVersionWarning,
	PMD_APEX_MODULE_MINIMUM_VERSION,
	PMD_APEX_MODULE_VALIDATED_VERSION,
	PMD_APEX_MODULE_CEILING_VERSION
} = require('../../src/lib/sfca-runner.js');

// Realistic dist/java-lib listing as bundled by code-analyzer-pmd-engine.
// JAR_LIST_7_19 predates the 7.26.0 minimum — used only for the version
// extraction tests (which never classify). JAR_LIST_7_26 sits inside the
// supported [minimum, ceiling) window for the classification tests.
const JAR_LIST_7_19 = [
	'antlr4-runtime-4.9.3.jar',
	'apex-ls_2.13-6.0.1.jar',
	'apex-parser-4.4.1.jar',
	'apex-types_2.13-1.3.0.jar',
	'pmd-apex-7.19.0.jar',
	'pmd-core-7.19.0.jar',
	'summit-ast-2.4.0.jar'
];
const JAR_LIST_7_26 = [
	'antlr4-runtime-4.9.3.jar',
	'apex-ls_2.13-6.0.1.jar',
	'apex-parser-5.0.0.jar',
	'apex-types_2.13-1.3.0.jar',
	'pmd-apex-7.26.0.jar',
	'pmd-core-7.26.0.jar',
	'summit-ast-2.4.0.jar'
];

function pluginsJson(entries)
{
	return JSON.stringify(entries);
}

const PLUGINS_JSON_TYPICAL = pluginsJson([
	{name: '@salesforce/plugin-packaging', version: '2.28.2', root: '/plugins/packaging'},
	{name: '@salesforce/plugin-code-analyzer', version: '5.8.0', root: '/plugins/code-analyzer'}
]);

test('buildSfcaArgs assembles --target flags per file', () =>
{
	const args = buildSfcaArgs({
		workspace: 'force-app',
		configFile: 'code-analyzer.yml',
		ruleSelector: 'pmd,flow,eslint',
		files: [
			'a.cls',
			'b.cls'
		],
		severityThreshold: 1
	});
	assert.deepEqual(args, [
		'code-analyzer',
		'run',
		'--workspace',
		'force-app',
		'--config-file',
		'code-analyzer.yml',
		'--rule-selector',
		'pmd,flow,eslint',
		'--severity-threshold',
		'1',
		'--target',
		'a.cls',
		'--target',
		'b.cls'
	]);
});

test('buildSfcaArgs omits --severity-threshold when null (CI mode handles it via output check)', () =>
{
	const args = buildSfcaArgs({
		workspace: 'force-app', configFile: 'code-analyzer.yml', ruleSelector: 'pmd', files: ['x.cls'], severityThreshold: null
	});
	assert.ok(!args.includes('--severity-threshold'));
});

test('pluginsJsonHasCodeAnalyzer: true when the code-analyzer plugin is listed', () =>
{
	assert.equal(pluginsJsonHasCodeAnalyzer(PLUGINS_JSON_TYPICAL), true);
});

test('pluginsJsonHasCodeAnalyzer: false for absent plugin, malformed JSON, null, or non-array', () =>
{
	assert.equal(pluginsJsonHasCodeAnalyzer(pluginsJson([{name: '@salesforce/plugin-packaging'}])), false);
	assert.equal(pluginsJsonHasCodeAnalyzer('{not json'), false);
	assert.equal(pluginsJsonHasCodeAnalyzer(null), false);
	assert.equal(pluginsJsonHasCodeAnalyzer(pluginsJson({name: 'x'})), false);
});

// --- PMD apex-module version guard -----------------------------------------

test('PMD version constants are the hard minimum, validated baseline, and ceiling', () =>
{
	assert.equal(PMD_APEX_MODULE_MINIMUM_VERSION, '7.26.0');
	assert.equal(PMD_APEX_MODULE_VALIDATED_VERSION, '7.26.0');
	assert.equal(PMD_APEX_MODULE_CEILING_VERSION, '7.27.0');
});

test('classifyPmdApexVersion: validated baseline is ok with no message', () =>
{
	const v = classifyPmdApexVersion('7.26.0');
	assert.equal(v.status, 'ok');
	assert.equal(v.message, null);
	assert.equal(v.version, '7.26.0');
	assert.equal(v.minimum, PMD_APEX_MODULE_MINIMUM_VERSION);
	assert.equal(v.validated, PMD_APEX_MODULE_VALIDATED_VERSION);
	assert.equal(v.ceiling, PMD_APEX_MODULE_CEILING_VERSION);
});

test('classifyPmdApexVersion: one patch below the ceiling is still ok', () =>
{
	assert.equal(classifyPmdApexVersion('7.26.9').status, 'ok');
});

test('classifyPmdApexVersion: below the 7.26.0 minimum is a hard-floor warning', () =>
{
	const v = classifyPmdApexVersion('7.25.0');
	assert.equal(v.status, 'below');
	assert.match(v.message, /7\.25\.0/);
	assert.match(v.message, /7\.26\.0/);
	assert.match(v.message, /InvocableClassNoArgConstructor/);
});

test('classifyPmdApexVersion: the legacy 7.19.0 baseline is now below the minimum', () =>
{
	assert.equal(classifyPmdApexVersion('7.19.0').status, 'below');
	assert.equal(classifyPmdApexVersion('7.25.9').status, 'below');
});

test('classifyPmdApexVersion: exactly the ceiling is ahead and warns', () =>
{
	const v = classifyPmdApexVersion('7.27.0');
	assert.equal(v.status, 'ahead');
	assert.match(v.message, /7\.27\.0/);
	assert.match(v.message, /7\.26\.0/);
});

test('classifyPmdApexVersion: above the ceiling is ahead', () =>
{
	assert.equal(classifyPmdApexVersion('7.27.1').status, 'ahead');
	assert.equal(classifyPmdApexVersion('8.0.0').status, 'ahead');
});

test('classifyPmdApexVersion: null/garbage is unknown (never nags)', () =>
{
	assert.equal(classifyPmdApexVersion(null).status, 'unknown');
	assert.equal(classifyPmdApexVersion('garbage').status, 'unknown');
	assert.equal(classifyPmdApexVersion('not.a.version').status, 'unknown');
	assert.equal(classifyPmdApexVersion(null).message, null);
});

test('classifyPmdApexVersion: tolerates short and long version tuples', () =>
{
	assert.equal(classifyPmdApexVersion('7.25').status, 'below');
	assert.equal(classifyPmdApexVersion('7.26').status, 'ok');
	assert.equal(classifyPmdApexVersion('7.27').status, 'ahead');
	assert.equal(classifyPmdApexVersion('7.27.0.1').status, 'ahead');
});

test('parsePluginRoot: returns the code-analyzer plugin root', () =>
{
	assert.equal(parsePluginRoot(PLUGINS_JSON_TYPICAL), '/plugins/code-analyzer');
});

test('parsePluginRoot: null when plugin absent, JSON malformed, root missing, or not an array', () =>
{
	assert.equal(parsePluginRoot(pluginsJson([{name: '@salesforce/plugin-packaging', root: '/x'}])), null);
	assert.equal(parsePluginRoot('{not json'), null);
	assert.equal(parsePluginRoot(pluginsJson([{name: '@salesforce/plugin-code-analyzer'}])), null);
	assert.equal(parsePluginRoot(pluginsJson({name: 'x'})), null);
	assert.equal(parsePluginRoot(null), null);
});

test('parsePmdApexVersion: extracts the version from the pmd-apex jar', () =>
{
	assert.equal(parsePmdApexVersion(JAR_LIST_7_19), '7.19.0');
	assert.equal(parsePmdApexVersion(['pmd-apex-7.25.0.jar']), '7.25.0');
});

test('parsePmdApexVersion: null when no pmd-apex jar, empty list, or non-array', () =>
{
	assert.equal(parsePmdApexVersion([
		'pmd-core-7.19.0.jar',
		'antlr4-runtime-4.9.3.jar'
	]), null);
	assert.equal(parsePmdApexVersion([]), null);
	assert.equal(parsePmdApexVersion(null), null);
});

test('parsePmdApexVersion: deterministic first match when multiple pmd-apex jars present', () =>
{
	assert.equal(parsePmdApexVersion([
		'pmd-apex-7.19.0.jar',
		'pmd-apex-7.25.0.jar'
	]), '7.19.0');
});

test('getBundledPmdApexVersion: composes plugin root + jar listing via injected seams', () =>
{
	const version = getBundledPmdApexVersion({
		runPluginsJson: () => PLUGINS_JSON_TYPICAL, listJarDir: () => JAR_LIST_7_19
	});
	assert.equal(version, '7.19.0');
});

test('getBundledPmdApexVersion: passes the resolved engine lib dir to the jar lister', () =>
{
	let seen = null;
	getBundledPmdApexVersion({
		runPluginsJson: () => PLUGINS_JSON_TYPICAL, listJarDir: (dir) =>
		{
			seen = dir;
			return JAR_LIST_7_19;
		}
	});
	assert.match(seen, /plugins[/\\]code-analyzer[/\\]node_modules[/\\]@salesforce[/\\]code-analyzer-pmd-engine[/\\]dist[/\\]java-lib$/);
});

// Pins the exact SFCA on-disk layout the guard depends on. The other tests mock
// the directory away; this one resolves it from a realistic plugin root through
// parsePluginRoot, so a future SFCA layout change (which would silently degrade
// the guard to a permanent no-warn) trips this instead of passing unnoticed.
test('getBundledPmdApexVersion: resolves the engine lib dir from a realistic plugin root', () =>
{
	const root = '/home/u/.local/share/sf/node_modules/@salesforce/plugin-code-analyzer';
	let seen = null;
	const version = getBundledPmdApexVersion({
		runPluginsJson: () => pluginsJson([{name: '@salesforce/plugin-code-analyzer', version: '5.8.0', root}]), listJarDir: (dir) =>
		{
			seen = dir;
			return JAR_LIST_7_19;
		}
	});
	assert.equal(version, '7.19.0');
	assert.equal(seen, path.join(root, 'node_modules', '@salesforce', 'code-analyzer-pmd-engine', 'dist', 'java-lib'));
});

test('getBundledPmdApexVersion: null when sf/plugin unavailable or lib dir unreadable', () =>
{
	assert.equal(getBundledPmdApexVersion({runPluginsJson: () => null, listJarDir: () => JAR_LIST_7_19}), null);
	assert.equal(getBundledPmdApexVersion({runPluginsJson: () => PLUGINS_JSON_TYPICAL, listJarDir: () => null}), null);
});

test('pmdApexVersionVerdict: returns the full classified verdict for the bundled version', () =>
{
	const ahead = pmdApexVersionVerdict({
		runPluginsJson: () => PLUGINS_JSON_TYPICAL, listJarDir: () => ['pmd-apex-7.27.0.jar']
	});
	assert.equal(ahead.status, 'ahead');
	assert.match(ahead.message, /7\.27\.0/);

	const below = pmdApexVersionVerdict({
		runPluginsJson: () => PLUGINS_JSON_TYPICAL, listJarDir: () => JAR_LIST_7_19
	});
	assert.equal(below.status, 'below');
	assert.equal(below.version, '7.19.0');

	const ok = pmdApexVersionVerdict({
		runPluginsJson: () => PLUGINS_JSON_TYPICAL, listJarDir: () => JAR_LIST_7_26
	});
	assert.equal(ok.status, 'ok');
	assert.equal(ok.version, '7.26.0');

	const unknown = pmdApexVersionVerdict({runPluginsJson: () => null, listJarDir: () => null});
	assert.equal(unknown.status, 'unknown');
	assert.equal(unknown.version, null);
});

test('pmdApexVersionWarning: returns the warning string when below the minimum or ahead', () =>
{
	const ahead = pmdApexVersionWarning({
		runPluginsJson: () => PLUGINS_JSON_TYPICAL, listJarDir: () => ['pmd-apex-7.27.0.jar']
	});
	assert.match(ahead, /7\.27\.0/);

	const below = pmdApexVersionWarning({
		runPluginsJson: () => PLUGINS_JSON_TYPICAL, listJarDir: () => JAR_LIST_7_19
	});
	assert.match(below, /7\.26\.0/);

	const ok = pmdApexVersionWarning({
		runPluginsJson: () => PLUGINS_JSON_TYPICAL, listJarDir: () => JAR_LIST_7_26
	});
	assert.equal(ok, null);

	const unknown = pmdApexVersionWarning({runPluginsJson: () => null, listJarDir: () => null});
	assert.equal(unknown, null);
});
