// SPDX-License-Identifier: MIT
'use strict';

function escapeForRegex(s)
{
	return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function build(_adapterConfig, branchesConfig)
{
	const protectedBranches = branchesConfig.protected_branches || [];
	const altGroup = protectedBranches.map(escapeForRegex).join('|');
	const backPromRe = new RegExp(`^gs-pipeline/(${altGroup})_-_(${altGroup})$`);
	const featureRe = new RegExp(`^gs-pipeline/feature/.+_-_(${altGroup})$`);

	return {
		name: 'gearset', classifyHeadRef(headRef)
		{
			if(backPromRe.test(headRef))
			{
				return {action: 'skip-scan', label: 'back-promotion'};
			}
			if(featureRe.test(headRef))
			{
				return {action: 'full-scan', label: 'intercepted-feature'};
			}
			if(headRef.startsWith('gs-pipeline/'))
			{
				return {action: 'full-scan', label: 'suspicious-prefix'};
			}
			return {action: 'full-scan', label: 'normal'};
		},
	};
}

module.exports = {build};
