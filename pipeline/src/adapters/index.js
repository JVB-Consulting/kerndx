// SPDX-License-Identifier: MIT
'use strict';

const ADAPTERS = {
	gearset: {module: require('./gearset.js'), experimental: false},
	copado: {module: require('./copado.js'), experimental: true},
	autorabit: {module: require('./autorabit.js'), experimental: true},
	'devops-center': {module: require('./devops-center.js'), experimental: false},
	none: {module: require('./none.js'), experimental: false},
	custom: {module: require('./custom.js'), experimental: false}
};

function resolve(adapterConfig, branches)
{
	if(!adapterConfig || !adapterConfig.name)
	{
		throw new Error('ci_adapter.name is required');
	}
	const entry = ADAPTERS[adapterConfig.name];
	if(!entry)
	{
		throw new Error(`unknown adapter: ${adapterConfig.name} (known: ${Object.keys(ADAPTERS).join(', ')})`);
	}
	if(entry.experimental && adapterConfig.experimental !== true)
	{
		throw new Error(`adapter "${adapterConfig.name}" is experimental and requires \`experimental: true\` `
				+ `in .kerndx/config.yml ci_adapter block. See the spec § "Experimental adapter acknowledgment".`);
	}
	const branchesContext = {
		protected_branches: Array.isArray(branches) ? branches : (branches.protected || branches.protected_branches || [])
	};
	return entry.module.build(adapterConfig, branchesContext);
}

module.exports = {resolve, ADAPTERS};
