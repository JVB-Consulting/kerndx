// SPDX-License-Identifier: BUSL-1.1
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

module.exports = {namespacePrefix, apexNamespacePrefix};
