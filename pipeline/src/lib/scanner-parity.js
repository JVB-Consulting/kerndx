// SPDX-License-Identifier: MIT
'use strict';
const fs = require('node:fs');

const RE_SELECTOR = /--rule-selector\s+([a-z,]+)/gi;

function normaliseList(str) {
	return str.split(',').map(s => s.trim()).filter(Boolean).sort().join(',');
}

function extractSelectorsFromText(text) {
	return [...text.matchAll(RE_SELECTOR)].map(m => normaliseList(m[1]));
}

function extractSelectorsFromFile(filePath) {
	if (!fs.existsSync(filePath)) return { filePath, found: [], error: `not found: ${filePath}` };
	return { filePath, found: extractSelectorsFromText(fs.readFileSync(filePath, 'utf-8')), error: null };
}

function checkParity(sources) {
	const results = Object.entries(sources).map(([label, p]) => ({ label, ...extractSelectorsFromFile(p) }));
	const issues = [];
	for (const r of results) {
		if (r.error) issues.push(`${r.label} (${r.filePath}): ${r.error}`);
		else if (r.found.length === 0) issues.push(`${r.label} (${r.filePath}): no --rule-selector found`);
	}
	if (issues.length) return { ok: false, issues, results };
	const canonical = results[0].found[0];
	for (const r of results) {
		for (const sel of r.found) {
			if (sel !== canonical) {
				issues.push(`drift — ${r.label} has "${sel}" but other sources have "${canonical}"`);
			}
		}
	}
	return { ok: issues.length === 0, issues, results };
}

module.exports = { checkParity, extractSelectorsFromFile, extractSelectorsFromText, normaliseList };
