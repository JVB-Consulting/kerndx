// SPDX-License-Identifier: MIT
'use strict';
const fs = require('node:fs');
const yaml = require('js-yaml');

const KNOWN_CHECK_IDS = new Set(['naming', 'description', 'inlineHelpText']);

function loadSuppressions(manifestPath) {
	const result = { suppressions: new Map(), errors: [] };
	if (!fs.existsSync(manifestPath)) return result;

	let doc;
	try {
		doc = yaml.load(fs.readFileSync(manifestPath, 'utf-8'));
	} catch (e) {
		result.errors.push(`YAML parse error in ${manifestPath}: ${e.message}`);
		return result;
	}

	if (!doc || !Array.isArray(doc.suppressions)) return result;

	for (let i = 0; i < doc.suppressions.length; i++) {
		const entry = doc.suppressions[i];
		const ref = `entry #${i + 1} (path: ${entry?.path ?? '<missing>'})`;
		if (!entry || typeof entry !== 'object') {
			result.errors.push(`${ref}: not an object`);
			continue;
		}
		if (typeof entry.path !== 'string' || !entry.path) {
			result.errors.push(`${ref}: missing required field 'path'`);
			continue;
		}
		if (typeof entry.reason !== 'string' || !entry.reason) {
			result.errors.push(`${ref}: missing required field 'reason'`);
			continue;
		}
		if (entry.reason.length < 20) {
			result.errors.push(`${ref}: reason must be at least 20 characters (got ${entry.reason.length})`);
			continue;
		}
		let checks;
		if (entry.checks === 'all') {
			checks = 'all';
		} else if (Array.isArray(entry.checks)) {
			checks = new Set();
			let bad = false;
			for (const c of entry.checks) {
				if (!KNOWN_CHECK_IDS.has(c)) {
					result.errors.push(`${ref}: unknown check '${c}' (known: ${[...KNOWN_CHECK_IDS].join(', ')}, or "all")`);
					bad = true;
					break;
				}
				checks.add(c);
			}
			if (bad) continue;
		} else {
			result.errors.push(`${ref}: 'checks' must be an array or "all"`);
			continue;
		}
		result.suppressions.set(entry.path, {
			checks,
			reason: entry.reason,
			expires: entry.expires || null,
			owner: entry.owner || null,
		});
	}
	return result;
}

module.exports = { loadSuppressions, KNOWN_CHECK_IDS };
