// SPDX-License-Identifier: MIT
'use strict';

/**
 * Extract the domain prefix from a field or object API name.
 *
 * Returns the uppercase segment before the first underscore, or null if the
 * name has no prefix or the prefix contains lowercase letters (i.e. not a
 * domain token).
 *
 * @param {string} fieldName - The field or object API name (e.g. 'ORD_TrackingNumber__c')
 * @returns {string|null} The prefix (e.g. 'ORD') or null when absent
 */
function getFieldPrefix(fieldName)
{
	const bare = fieldName.replace(/__c$/, '');
	const idx = bare.indexOf('_');
	if(idx === -1)
	{
		return null;
	}
	const prefix = bare.slice(0, idx);
	return /^[A-Z]+$/.test(prefix) ? prefix : null;
}

/**
 * Derive the domain of a parent object from its API name.
 *
 * Returns the domain prefix when it appears in the allowlisted domains set,
 * otherwise null (standard objects and unrecognised prefixes both return null).
 *
 * @param {string} parentName - The parent object API name (e.g. 'ORD_Sale__c')
 * @param {object} patterns - Compiled patterns from buildPatterns()
 * @param {Set<string>} patterns.domains - Allowlisted domain prefixes
 * @returns {string|null} Domain string or null
 */
function getParentDomain(parentName, patterns)
{
	const prefix = getFieldPrefix(parentName);
	if(prefix && patterns.domains.has(prefix))
	{
		return prefix;
	}
	return null;
}

/**
 * Validate whether a custom field API name satisfies the configured prefix rule.
 *
 * Three modes are driven by patterns.fieldPrefixRule:
 *
 *   'never'             - No prefix required; all fields pass.
 *   'always'            - Every field must carry an allowlisted domain prefix.
 *   'cross-domain-only' - Fields on standard objects must have a domain prefix;
 *                         fields on custom objects only need a prefix when their
 *                         prefix differs from the parent object's domain.
 *
 * @param {string} fieldName - Custom field API name (e.g. 'ORD_TrackingNumber__c')
 * @param {string} parentName - Parent object API name (e.g. 'ORD_Sale__c' or 'Account')
 * @param {object} patterns - Compiled patterns from buildPatterns()
 * @param {Set<string>} patterns.domains - Allowlisted domain prefixes
 * @param {string} patterns.fieldPrefixRule - One of 'never' | 'always' | 'cross-domain-only'
 * @returns {{ violations: Array<{ file: string, rule: string, message: string }> }}
 */
function validateField(fieldName, parentName, patterns)
{
	const violations = [];

	if(patterns.fieldPrefixRule === 'never')
	{
		return {violations};
	}

	const isStandardObject = !parentName.endsWith('__c');
	const fieldDomain = getFieldPrefix(fieldName);
	const parentDomain = isStandardObject ? null : getParentDomain(parentName, patterns);

	if(patterns.fieldPrefixRule === 'always')
	{
		if(!fieldDomain || !patterns.domains.has(fieldDomain))
		{
			violations.push({
				file: `${parentName}.${fieldName}`, rule: 'field-prefix', message: `Field "${fieldName}" on "${parentName}" requires a domain prefix.`
			});
		}
		return {violations};
	}

	// cross-domain-only (default)
	if(isStandardObject)
	{
		if(!fieldDomain || !patterns.domains.has(fieldDomain))
		{
			violations.push({
				file: `${parentName}.${fieldName}`, rule: 'field-prefix-standard', message: `Field "${fieldName}" on standard object "${parentName}" must have a domain prefix.`
			});
		}
	}
	else if(parentDomain && fieldDomain && fieldDomain !== parentDomain)
	{
		if(!patterns.domains.has(fieldDomain))
		{
			violations.push({
				file: `${parentName}.${fieldName}`, rule: 'field-prefix-domain', message: `Field prefix "${fieldDomain}" not in allowed domains list.`
			});
		}
	}

	return {violations};
}

module.exports = {validateField, getFieldPrefix, getParentDomain};
