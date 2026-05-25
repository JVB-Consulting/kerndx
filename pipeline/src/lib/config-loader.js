// SPDX-License-Identifier: MIT
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const yaml = require('js-yaml');
const Ajv = require('ajv');
const safeRegex = require('safe-regex');

class ConfigError extends Error {
	constructor(message) {
		super(message);
		this.name = 'ConfigError';
	}
}

const SCHEMA_PATH = path.join(__dirname, '..', 'templates', 'config-schema.json');
const schema = JSON.parse(fs.readFileSync(SCHEMA_PATH, 'utf-8'));

const ajv = new Ajv({ allErrors: true, strict: false });
const validate = ajv.compile(schema);

function loadConfig(configPath) {
	if (!fs.existsSync(configPath)) {
		throw new ConfigError(`Config file not found: ${configPath}`);
	}
	let parsed;
	try {
		parsed = yaml.load(fs.readFileSync(configPath, 'utf-8'));
	} catch (e) {
		throw new ConfigError(`YAML parse error in ${configPath}: ${e.message}`);
	}
	if (!validate(parsed)) {
		const messages = validate.errors.map(e => `${e.instancePath || '/'}: ${e.message}`).join('; ');
		throw new ConfigError(`Schema violation in ${configPath}: ${messages}`);
	}
	if (parsed.ci_adapter && parsed.ci_adapter.name === 'custom') {
		for (const p of parsed.ci_adapter.patterns) {
			if (!safeRegex(p.match)) {
				throw new ConfigError(
					`unsafe regex (catastrophic backtracking risk) in ci_adapter.patterns: "${p.match}". ` +
					`Simplify the pattern; see https://github.com/davisjam/safe-regex.`
				);
			}
		}
	}
	return parsed;
}

module.exports = { loadConfig, ConfigError };
