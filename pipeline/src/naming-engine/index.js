// SPDX-License-Identifier: MIT
'use strict';
const { buildPatterns } = require('./config.js');
const { validateFlow } = require('./flow.js');
const { validateObject } = require('./object.js');
const { loadSuppressions } = require('./suppressions.js');

/**
 * Validate a list of files against the project naming configuration.
 *
 * Flows are validated directly by path. Object-directory files are deduplicated
 * to a single validation per object directory before being dispatched to the
 * object validator. Suppressions are honoured per-file for checks that include
 * 'naming' or the special value 'all'.
 *
 * @param {object} options - Validation options.
 * @param {string[]} options.files - Repo-relative or absolute file paths to check.
 * @param {object} options.config - Naming configuration block from .kerndx/config.yml.
 * @returns {Promise<{violations: Array<{file: string, rule: string, message: string}>}>}
 */
async function validate({ files, config }) {
	const patterns = buildPatterns(config);
	const suppMap = config.suppressions_file
		? loadSuppressions(config.suppressions_file).suppressions
		: new Map();

	const violations = [];

	for (const file of files) {
		if (suppMap.has(file)) {
			const entry = suppMap.get(file);
			if (entry.checks === 'all' || (entry.checks.has && entry.checks.has('naming'))) {
				continue;
			}
		}

		if (file.endsWith('.flow-meta.xml')) {
			const r = validateFlow(file, patterns);
			violations.push(...r.violations);
			continue;
		}

		const objDirMatch = file.match(/\/objects\/([^/]+)\//);
		if (objDirMatch) {
			const objectDir = file.slice(0, file.indexOf(`/objects/${objDirMatch[1]}/`) + `/objects/${objDirMatch[1]}`.length);
			if (!violations.some(v => v.file === objectDir)) {
				const r = validateObject(objectDir, patterns);
				violations.push(...r.violations);
			}
		}
	}

	return { violations };
}

module.exports = { validate };
