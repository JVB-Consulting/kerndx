// SPDX-License-Identifier: MIT
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { Eta } = require('eta');

const DEFAULT_DOMAINS = ['SLS', 'ORD', 'PRD', 'SVC', 'SUB', 'MKT', 'CMN'];
const DEFAULT_BRANDS  = ['ACM', 'BTA'];
const DEFAULT_LAYERS  = ['SEL', 'TRG', 'FLOW', 'SVC', 'BATCH', 'SCHED', 'API', 'REST', 'DTO', 'CTRL', 'UTIL', 'LOG', 'IF', 'QRY', 'DML', 'MAP', 'TST'];
const DEFAULT_APEX_LENGTH = 40;

const TEMPLATE_PATH = path.resolve(__dirname, '..', '..', '..', 'scanner', 'subscriber-naming-pmd-ruleset.xml.eta');

class PmdRulesetError extends Error {
	constructor(message) {
		super(message);
		this.name = 'PmdRulesetError';
	}
}

function validateCodeList(codes, kind, { minLen = 2, maxLen = 5 } = {}) {
	if (!Array.isArray(codes)) {
		throw new PmdRulesetError(`naming.${kind} must be an array of codes, got ${typeof codes}`);
	}
	for (const code of codes) {
		if (typeof code !== 'string') {
			throw new PmdRulesetError(`naming.${kind} entry must be a string, got ${typeof code}: ${JSON.stringify(code)}`);
		}
		if (!/^[A-Z][A-Z0-9]*$/.test(code)) {
			throw new PmdRulesetError(`naming.${kind} entry "${code}" must be uppercase alphanumeric starting with a letter (e.g. SLS, ORD)`);
		}
		if (code.length < minLen || code.length > maxLen) {
			throw new PmdRulesetError(`naming.${kind} entry "${code}" must be ${minLen}-${maxLen} characters (got ${code.length})`);
		}
	}
	const seen = new Set();
	for (const code of codes) {
		if (seen.has(code)) {
			throw new PmdRulesetError(`naming.${kind} contains duplicate entry "${code}"`);
		}
		seen.add(code);
	}
}

function resolveCodeList(naming, key, defaults) {
	if (naming[key] === undefined) return defaults;
	if (!Array.isArray(naming[key])) {
		throw new PmdRulesetError(`naming.${key} must be an array of codes, got ${typeof naming[key]}`);
	}
	if (naming[key].length === 0 && key !== 'brands') {
		return defaults;
	}
	return naming[key];
}

function deriveTemplateData(config) {
	const naming = (config && config.naming) || {};
	const domains = resolveCodeList(naming, 'domains', DEFAULT_DOMAINS);
	const brands  = resolveCodeList(naming, 'brands', DEFAULT_BRANDS);
	const layers  = resolveCodeList(naming, 'apex_layers', DEFAULT_LAYERS);
	const lengthLimit = (naming.length_limits && naming.length_limits.apex !== undefined)
		? naming.length_limits.apex
		: DEFAULT_APEX_LENGTH;

	validateCodeList(domains, 'domains', { minLen: 2, maxLen: 5 });
	if (brands.length > 0) {
		validateCodeList(brands, 'brands', { minLen: 2, maxLen: 5 });
	}
	validateCodeList(layers, 'apex_layers', { minLen: 2, maxLen: 5 });
	if (!Number.isInteger(lengthLimit) || lengthLimit < 10 || lengthLimit > 80) {
		throw new PmdRulesetError(`naming.length_limits.apex must be an integer between 10 and 80 (got ${lengthLimit})`);
	}

	return {
		domainsCsv: domains.join(', '),
		domainsPipe: domains.join('|'),
		brandsCsv: brands.length > 0 ? brands.join(', ') : '(none)',
		brandsPipe: brands.length > 0 ? brands.join('|') : null,
		layersCsv: layers.join(', '),
		layersPipe: layers.join('|'),
		apexLengthLimit: lengthLimit,
	};
}

function renderPmdRuleset(config, { templatePath = TEMPLATE_PATH } = {}) {
	const data = deriveTemplateData(config);
	const eta = new Eta({
		views: path.dirname(templatePath),
		cache: false,
		autoEscape: false,
		useWith: true,
		tags: ['<%', '%>'],
		autoTrim: false,
	});
	const tmplContent = fs.readFileSync(templatePath, 'utf-8');
	return eta.renderString(tmplContent, data);
}

module.exports = {
	renderPmdRuleset,
	deriveTemplateData,
	PmdRulesetError,
	DEFAULT_DOMAINS,
	DEFAULT_BRANDS,
	DEFAULT_LAYERS,
	DEFAULT_APEX_LENGTH,
	TEMPLATE_PATH,
};
