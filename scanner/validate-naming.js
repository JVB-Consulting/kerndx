#!/usr/bin/env node
// SPDX-License-Identifier: BUSL-1.1

/**
 * Subscriber Naming Standards Validator (Declarative Metadata)
 *
 * Scans a Salesforce DX project's force-app/ directory and flags Flows and
 * Custom Objects that violate the configured subscriber naming conventions.
 *
 * Apex classes, triggers, and LWC are validated by PMD and ESLint rules in
 * scanner/ — this script only covers artefact types that those tools cannot
 * parse (Flow XML and object metadata folders).
 *
 * Usage:
 *   node validate-naming.js [path-to-force-app]
 *
 * Defaults to ./force-app if no path is provided.
 *
 * Configuration:
 *   The validator reads `.kerndx/config.yml` (if present) from the current
 *   working directory or the path passed as the second positional argument.
 *   The `naming` block of that file overrides the hardcoded defaults — see
 *   `scanner/README.md` → "Customizing naming rules" for the schema.
 *
 *   When no `.kerndx/config.yml` is present, the hardcoded defaults at
 *   `scanner/lib/naming-config-loader.js#HARDCODED_DEFAULTS` apply (the
 *   same `(ACM|BTA)` brand placeholders shipped in the PMD ruleset).
 *
 *   The loader fails LOUD on a malformed config file (invalid YAML,
 *   wrong types, etc.) — it never silently falls back to hardcoded
 *   defaults when a file is present. Defaults apply only when the file
 *   does not exist.
 *
 * @see subscriber-naming-pmd-ruleset.xml  — Apex class and trigger naming (PMD)
 * @see eslint-plugin-kerndx/rules/enforce-component-naming.js — LWC naming (ESLint)
 * @see lib/naming-config-loader.js — shared loader (will also be consumed by
 *      the KernDX pipeline naming-engine in a follow-up).
 */

const fs = require('fs');
const path = require('path');
const { loadConfig, ConfigError } = require('./lib/naming-config-loader.js');

// ─── Configuration ──────────────────────────────────────────────────────────

const LENGTH_WARNING_THRESHOLD = 5;

function buildScannerPatterns(config)
{
	const domainGroup = config.domains.join('|');
	const brandGroup = (config.brands && config.brands.length > 0) ? config.brands.join('|') : null;
	const flowTypeGroup = config.flow_types.join('|');

	const brandSegment = brandGroup ? `(?:(${brandGroup})_)?` : '';

	const flowPattern = new RegExp(
		`^(${domainGroup})_${brandSegment}[A-Z][a-zA-Z0-9]+_(${flowTypeGroup})_[A-Z][a-zA-Z0-9]+$`
	);

	const objectPattern = new RegExp(
		`^(${domainGroup})_${brandSegment}[A-Z][a-zA-Z0-9]+__c$`
	);

	return { flow: flowPattern, object: objectPattern };
}

// ─── Scanner ────────────────────────────────────────────────────────────────

function scanDirectory(dirPath)
{
	if (!fs.existsSync(dirPath))
	{
		return [];
	}
	return fs.readdirSync(dirPath);
}

function check(state, category, name, pattern, expectedHint)
{
	state.checked++;
	if (!pattern.test(name))
	{
		state.violations.push({ category, name, expected: expectedHint });
	}
	const limit = state.lengthLimits[category];
	if (limit)
	{
		const bare = name.replace(/__c$|__e$|__mdt$/, '');
		if (bare.length > limit)
		{
			state.violations.push({ category, name, expected: `${limit} character limit exceeded (${bare.length} chars)` });
		}
		else if (bare.length > limit - LENGTH_WARNING_THRESHOLD)
		{
			state.warnings.push({ category, name, length: bare.length, limit });
		}
	}
}

function scanFlows(state, basePath, patterns)
{
	const flowDir = path.join(basePath, 'flows');
	const files = scanDirectory(flowDir);

	for (const file of files)
	{
		if (!file.endsWith('.flow-meta.xml') || file.startsWith('.'))
		{
			continue;
		}
		const name = file.replace('.flow-meta.xml', '');
		check(state, 'Flow', name, patterns.flow, 'Domain_[Brand_]Object_Type_Action');
	}
}

function scanCustomObjects(state, basePath, patterns)
{
	const objectDir = path.join(basePath, 'objects');
	const entries = scanDirectory(objectDir);

	for (const entry of entries)
	{
		if (entry.startsWith('.') || !entry.endsWith('__c'))
		{
			continue;
		}
		check(state, 'Custom Object', entry, patterns.object, 'Domain_[Brand_]ObjectName__c');
	}
}

// ─── Main ───────────────────────────────────────────────────────────────────

function main(argv)
{
	const inputPath = argv[2] || './force-app';

	if (!fs.existsSync(inputPath))
	{
		console.error(`Error: ${inputPath} does not exist.`);
		process.exit(2);
	}

	const standardPath = path.join(inputPath, 'main', 'default');
	const isStandardLayout = fs.existsSync(standardPath);
	const basePath = isStandardLayout ? standardPath : inputPath;

	let configResult;
	try
	{
		configResult = loadConfig({ repoRoot: process.cwd() });
	}
	catch (e)
	{
		if (e instanceof ConfigError)
		{
			console.error(`Configuration error: ${e.message}`);
			process.exit(2);
		}
		throw e;
	}

	const patterns = buildScannerPatterns(configResult.config);

	console.log('Subscriber Naming Standards Validator (Flows & Custom Objects)');
	console.log(`Source: ${inputPath}${isStandardLayout ? ' (SFDX standard layout)' : ' (flat layout)'}`);
	if (configResult.source === 'config')
	{
		console.log(`Config: ${configResult.configPath} (overrides applied)`);
	}
	else if (configResult.source === 'config-no-naming-block')
	{
		console.log(`Config: ${configResult.configPath} (no 'naming' block — defaults applied)`);
	}
	else
	{
		console.log('Config: no .kerndx/config.yml found — hardcoded defaults applied');
	}
	console.log('');
	console.log('Note: Apex class, trigger, and LWC naming is enforced by PMD and ESLint.');
	console.log('      See scanner/subscriber-naming-pmd-ruleset.xml and scanner/eslint-plugin-kerndx/.\n');

	const state = {
		checked: 0,
		violations: [],
		warnings: [],
		lengthLimits: {
			'Flow': configResult.config.length_limits.flow,
			'Custom Object': configResult.config.length_limits.custom_object
		}
	};

	scanFlows(state, basePath, patterns);
	scanCustomObjects(state, basePath, patterns);

	console.log(`Checked: ${state.checked} artefacts\n`);

	if (state.warnings.length > 0)
	{
		console.log(`Near-limit warnings (within ${LENGTH_WARNING_THRESHOLD} chars):`);
		for (const w of state.warnings)
		{
			console.log(`  ${w.name} (${w.category}: ${w.length}/${w.limit} chars)`);
		}
		console.log('');
	}

	if (state.violations.length === 0)
	{
		console.log('No naming violations found.');
		process.exit(0);
	}

	const grouped = {};
	for (const v of state.violations)
	{
		if (!grouped[v.category])
		{
			grouped[v.category] = [];
		}
		grouped[v.category].push(v);
	}

	for (const [category, items] of Object.entries(grouped))
	{
		console.log(`${category} (${items.length} violation${items.length === 1 ? '' : 's'}):`);
		for (const item of items)
		{
			console.log(`  ${item.name}`);
			console.log(`    Expected: ${item.expected}`);
		}
		console.log('');
	}

	console.log(`Total: ${state.violations.length} violation${state.violations.length === 1 ? '' : 's'} across ${state.checked} artefacts.`);
	process.exit(1);
}

if (require.main === module)
{
	main(process.argv);
}

module.exports = { buildScannerPatterns };
