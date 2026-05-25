// SPDX-License-Identifier: BUSL-1.1
// Dev org alias — single source of truth for the KernDX dev org.
// Export KERN_DEV_ORG before invoking any script that resolves a dev org alias.
module.exports = {
	getDevOrgAlias()
	{
		const alias = process.env.KERN_DEV_ORG;
		if(!alias)
		{
			throw new Error('KERN_DEV_ORG env var is required. Export your dev scratch-org alias before running.');
		}
		return alias;
	}
};
