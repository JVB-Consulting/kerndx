// SPDX-License-Identifier: Apache-2.0
// Namespace resolution for specs that run against both the managed subscriber org
// ('kern__' / 'kern.') and the no-namespace unmanaged org ('' / ''). Mirrors the
// masking-advisor page object's Tooling-API probe, shared so page objects and
// anonymous-Apex seed builders resolve the prefix the same way. Cached for the
// process so the lookup runs at most once per test run.
const {soqlQuery} = require('./sf-cli');

let cachedNamespacePrefix;

function namespacePrefix()
{
	if(cachedNamespacePrefix === undefined)
	{
		const rows = soqlQuery('SELECT NamespacePrefix FROM ApexClass WHERE Name = \'UTIL_AsyncChain\' LIMIT 1', {tooling: true});
		const namespace = rows[0] && rows[0].NamespacePrefix;
		cachedNamespacePrefix = namespace ? `${namespace}__` : '';
	}
	return cachedNamespacePrefix;
}

// The Apex type-reference form of the same answer: 'kern.' on a subscriber org, '' unmanaged.
function apexNamespacePrefix()
{
	const prefix = namespacePrefix();
	return prefix ? `${prefix.slice(0, -2)}.` : '';
}

const APEX_NAMESPACE_TOKEN = '__APEX_NAMESPACE__';
const FIELD_NAMESPACE_TOKEN = '__FIELD_NAMESPACE__';

/**
 * @description Fills the two neutral namespace tokens a template carries, so one template serves an org with the
 * package installed under any namespace and an org that holds the framework with none.
 *
 * @param {string} source The template text.
 * @param {string} fieldPrefix The org's field prefix (`kern__` on a subscriber org, empty on the development org).
 *
 * @returns {string}
 */
function fillNamespaceTokens(source, fieldPrefix)
{
	const apexPrefix = fieldPrefix ? `${fieldPrefix.slice(0, -2)}.` : '';
	return source.split(FIELD_NAMESPACE_TOKEN).join(fieldPrefix).split(APEX_NAMESPACE_TOKEN).join(apexPrefix);
}

/**
 * @description Rewrites the namespace literals a release-testing script was written with (`kern__` and `kern.`, the
 * forms bin/swap-namespace.js also rewrites) to the org's own: stripped on the development org, moved on an org
 * under another namespace, untouched on an org under the same one.
 *
 * @param {string} source The script text.
 * @param {string} fieldPrefix The org's field prefix, empty for none.
 *
 * @returns {string}
 */
function rewriteNamespaceLiterals(source, fieldPrefix)
{
	const apexPrefix = fieldPrefix ? `${fieldPrefix.slice(0, -2)}.` : '';
	return source.split('kern__').join(fieldPrefix).split('kern.').join(apexPrefix);
}

/**
 * @description A script as the harness org needs it: tokens filled, literals rewritten, both from the org's probe.
 *
 * @param {string} source The script text.
 *
 * @returns {string}
 */
function prepareApexForOrg(source)
{
	const fieldPrefix = namespacePrefix();
	return rewriteNamespaceLiterals(fillNamespaceTokens(source, fieldPrefix), fieldPrefix);
}

module.exports = {namespacePrefix, apexNamespacePrefix, fillNamespaceTokens, rewriteNamespaceLiterals, prepareApexForOrg, APEX_NAMESPACE_TOKEN, FIELD_NAMESPACE_TOKEN};
