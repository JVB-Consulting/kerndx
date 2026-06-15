// SPDX-License-Identifier: MIT
'use strict';
const fs = require('node:fs');
const path = require('node:path');

/**
 * Extract the text content of a named XML element (first occurrence).
 * Returns '' for self-closing tags, null when the element is absent.
 *
 * @param {string} xml - Raw XML string.
 * @param {string} name - Element name to search for.
 * @returns {string|null} Trimmed inner text, '' for self-closing, null if absent.
 */
function getElementText(xml, name)
{
	const selfClose = new RegExp(`<${name}\\b\\s*/>`);
	if(selfClose.test(xml))
	{
		return '';
	}
	const pair = new RegExp(`<${name}\\b[^>]*>([\\s\\S]*?)</${name}>`);
	const m = xml.match(pair);
	if(!m)
	{
		return null;
	}
	return m[1].trim();
}

/**
 * Validate a single Flow metadata file against the compiled naming patterns.
 *
 * When `skipReadFile` is false (default), the file is read from disk and its
 * internal `<label>` element is cross-checked against the filename stem.  Set
 * `skipReadFile: true` and supply `label` to validate a synthetic name without
 * touching the filesystem (useful in tests and for streaming pipelines).
 *
 * @param {string} filePath - Absolute or repo-relative path to the .flow-meta.xml file.
 * @param {object} patterns - Compiled patterns returned by buildPatterns().
 * @param {object} [options] - Optional overrides.
 * @param {boolean} [options.skipReadFile=false] - Skip filesystem read.
 * @param {string|null} [options.label=null] - Override label used when skipReadFile is true.
 * @returns {{ violations: Array<{file: string, rule: string, message: string}> }}
 */
function validateFlow(filePath, patterns, {skipReadFile = false, label = null} = {})
{
	const violations = [];
	let flowLabel = label;

	if(!skipReadFile)
	{
		const basename = path.basename(filePath, '.flow-meta.xml');
		flowLabel = basename;

		const xml = fs.readFileSync(filePath, 'utf-8');
		const innerLabel = getElementText(xml, 'label');
		if(innerLabel && innerLabel !== basename)
		{
			violations.push({
				file: filePath, rule: 'flow-label-mismatch', message: `<label>${innerLabel}</label> does not match filename ${basename}`
			});
		}
	}

	if(!patterns.flow.test(flowLabel))
	{
		violations.push({
			file: filePath, rule: 'flow-naming', message: `Flow name "${flowLabel}" does not match Domain_[Brand_]Object_Type_Action`
		});
	}

	if(flowLabel.length > patterns.lengthLimits.flow)
	{
		violations.push({
			file: filePath, rule: 'flow-length', message: `Flow name "${flowLabel}" exceeds ${patterns.lengthLimits.flow}-char limit (${flowLabel.length} chars)`
		});
	}

	return {violations};
}

module.exports = {validateFlow, getElementText};
