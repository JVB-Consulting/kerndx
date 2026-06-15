// SPDX-License-Identifier: BUSL-1.1
'use strict';

/**
 * Naming Config Loader (Shared by scanner/validate-naming.js + pipeline)
 *
 * Loads the subscriber's `.kerndx/config.yml` `naming` block and merges it
 * against hardcoded defaults. Returns a config object compatible with
 * `pipeline/src/naming-engine/config.js#buildPatterns()` so both validators
 * compile the same regex shapes from the same source of truth.
 *
 * Behaviour contract:
 *
 *   - If `.kerndx/config.yml` does NOT exist  → return HARDCODED_DEFAULTS.
 *   - If file EXISTS but YAML parsing fails    → throw a ConfigError naming
 *     the file + parser error (fail-loud).
 *   - If a present key has the wrong type      → throw a ConfigError naming
 *     the file + offending key.
 *   - js-yaml is required only when a config file is present. Standalone
 *     scanner installs without js-yaml continue to work as long as the
 *     subscriber has not added a .kerndx/config.yml file. When a config
 *     file is present but js-yaml is not installed, throw a clear error
 *     instructing the user to install it.
 */

const fs = require('node:fs');
const path = require('node:path');

class ConfigError extends Error
{
	constructor(message)
	{
		super(message);
		this.name = 'ConfigError';
	}
}

const HARDCODED_DEFAULTS = Object.freeze({
	domains: Object.freeze([
		'SLS',
		'ORD',
		'PRD',
		'SVC',
		'SUB',
		'MKT',
		'CMN'
	]), brands: Object.freeze([
		'ACM',
		'BTA'
	]), flow_types: Object.freeze([
		'BS',
		'AS',
		'BD',
		'SCR',
		'AL',
		'SCH',
		'PE',
		'SF'
	]), apex_layers: Object.freeze([
		'SEL',
		'TRG',
		'FLOW',
		'SVC',
		'BATCH',
		'SCHED',
		'API',
		'REST',
		'DTO',
		'CTRL',
		'UTIL',
		'LOG',
		'IF',
		'QRY',
		'DML',
		'MAP',
		'TST'
	]), length_limits: Object.freeze({
		flow: 80, custom_object: 40, apex: 40
	})
});

function unfreeze(value)
{
	if(Array.isArray(value))
	{
		return value.slice();
	}
	if(value && typeof value === 'object')
	{
		const out = {};
		for(const k of Object.keys(value))
		{
			out[k] = unfreeze(value[k]);
		}
		return out;
	}
	return value;
}

function ensureArrayOfStrings(configPath, key, value)
{
	if(!Array.isArray(value))
	{
		throw new ConfigError(`${configPath}: 'naming.${key}' must be an array of strings (got ${typeof value})`);
	}
	for(const item of value)
	{
		if(typeof item !== 'string' || item.length === 0)
		{
			throw new ConfigError(`${configPath}: 'naming.${key}' must contain non-empty strings (got ${JSON.stringify(item)})`);
		}
	}
}

function loadConfig({repoRoot, configPath} = {})
{
	const resolvedConfigPath = configPath || path.join(repoRoot || process.cwd(), '.kerndx', 'config.yml');

	if(!fs.existsSync(resolvedConfigPath))
	{
		return {
			config: unfreeze(HARDCODED_DEFAULTS), source: 'defaults', configPath: null
		};
	}

	let yaml;
	try
	{
		yaml = require('js-yaml');
	}
	catch(_)
	{
		throw new ConfigError(`${resolvedConfigPath} exists but the 'js-yaml' package is not installed. `
				+ `Install it (npm install --no-save js-yaml) or remove the config file to use hardcoded defaults.`);
	}

	let raw;
	try
	{
		raw = fs.readFileSync(resolvedConfigPath, 'utf-8');
	}
	catch(e)
	{
		throw new ConfigError(`Failed to read ${resolvedConfigPath}: ${e.message}`);
	}

	let parsed;
	try
	{
		parsed = yaml.load(raw);
	}
	catch(e)
	{
		throw new ConfigError(`YAML parse error in ${resolvedConfigPath}: ${e.message}`);
	}

	if(parsed === null || typeof parsed !== 'object')
	{
		throw new ConfigError(`${resolvedConfigPath} did not produce a YAML object (got ${typeof parsed})`);
	}

	const namingBlock = parsed.naming;
	if(namingBlock === undefined)
	{
		// No naming block; defaults apply
		return {
			config: unfreeze(HARDCODED_DEFAULTS), source: 'config-no-naming-block', configPath: resolvedConfigPath
		};
	}
	if(namingBlock === null || typeof namingBlock !== 'object' || Array.isArray(namingBlock))
	{
		throw new ConfigError(`${resolvedConfigPath}: 'naming' must be a YAML object (got ${Array.isArray(namingBlock) ? 'array' : typeof namingBlock})`);
	}

	if(namingBlock.domains !== undefined)
	{
		ensureArrayOfStrings(resolvedConfigPath, 'domains', namingBlock.domains);
	}
	if(namingBlock.brands !== undefined)
	{
		ensureArrayOfStrings(resolvedConfigPath, 'brands', namingBlock.brands);
	}
	if(namingBlock.flow_types !== undefined)
	{
		ensureArrayOfStrings(resolvedConfigPath, 'flow_types', namingBlock.flow_types);
	}
	if(namingBlock.apex_layers !== undefined)
	{
		ensureArrayOfStrings(resolvedConfigPath, 'apex_layers', namingBlock.apex_layers);
	}
	if(namingBlock.length_limits !== undefined && (namingBlock.length_limits === null || typeof namingBlock.length_limits !== 'object' || Array.isArray(namingBlock.length_limits)))
	{
		throw new ConfigError(`${resolvedConfigPath}: 'naming.length_limits' must be a YAML object (got ${Array.isArray(namingBlock.length_limits) ? 'array'
				: typeof namingBlock.length_limits})`);
	}

	const merged = {
		domains: namingBlock.domains !== undefined ? namingBlock.domains.slice() : HARDCODED_DEFAULTS.domains.slice(),
		brands: namingBlock.brands !== undefined ? namingBlock.brands.slice() : HARDCODED_DEFAULTS.brands.slice(),
		flow_types: namingBlock.flow_types !== undefined ? namingBlock.flow_types.slice() : HARDCODED_DEFAULTS.flow_types.slice(),
		apex_layers: namingBlock.apex_layers !== undefined ? namingBlock.apex_layers.slice() : HARDCODED_DEFAULTS.apex_layers.slice(),
		length_limits: Object.assign({}, HARDCODED_DEFAULTS.length_limits, namingBlock.length_limits || {})
	};

	return {config: merged, source: 'config', configPath: resolvedConfigPath};
}

module.exports = {loadConfig, HARDCODED_DEFAULTS, ConfigError};
