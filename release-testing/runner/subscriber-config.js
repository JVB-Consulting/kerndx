// SPDX-License-Identifier: BUSL-1.1
// Subscriber org alias — single source of truth for the test subscriber org.
// Export SF_SUBSCRIBER_ORG_ALIAS before invoking any release-testing runner.
module.exports = {
	getSubscriberOrgAlias()
	{
		const alias = process.env.SF_SUBSCRIBER_ORG_ALIAS;
		if(!alias)
		{
			throw new Error('SF_SUBSCRIBER_ORG_ALIAS env var is required. Export your subscriber scratch-org alias before running.');
		}
		return alias;
	}
};
