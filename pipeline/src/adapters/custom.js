// SPDX-License-Identifier: MIT
'use strict';

function build(adapterConfig, _branches)
{
	const compiled = adapterConfig.patterns.map(p => ({
		re: new RegExp(p.match), action: p.action, label: p.label
	}));
	return {
		name: 'custom', classifyHeadRef(headRef)
		{
			for(const c of compiled)
			{
				if(c.re.test(headRef))
				{
					return {action: c.action, label: c.label};
				}
			}
			return {action: 'full-scan', label: 'normal'};
		}
	};
}

module.exports = {build};
