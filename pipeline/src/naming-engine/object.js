// SPDX-License-Identifier: MIT
'use strict';
const path = require('node:path');

/**
 * Validate a Salesforce custom object directory against the compiled naming patterns.
 *
 * The object name is taken from the final path segment (the directory name), which
 * matches how sfdx source format stores objects: `objects/Domain_Name__c/`.
 *
 * @param {string} objectDir - Absolute or repo-relative path to the object directory.
 * @param {object} patterns - Compiled patterns returned by buildPatterns().
 * @returns {{ violations: Array<{file: string, rule: string, message: string}> }}
 */
function validateObject(objectDir, patterns)
{
	const violations = [];
	const name = path.basename(objectDir);

	if(!patterns.object.test(name))
	{
		violations.push({
			file: objectDir, rule: 'object-naming', message: `Object "${name}" does not match Domain_[Brand_]Name__c`
		});
	}

	if(name.length > patterns.lengthLimits.apex)
	{
		violations.push({
			file: objectDir, rule: 'object-length', message: `Object name "${name}" exceeds ${patterns.lengthLimits.apex}-char limit (${name.length} chars)`
		});
	}

	return {violations};
}

module.exports = {validateObject};
