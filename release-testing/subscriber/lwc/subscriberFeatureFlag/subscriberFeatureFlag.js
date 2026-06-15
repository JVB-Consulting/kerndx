// SPDX-License-Identifier: BUSL-1.1
import {ComponentBuilder} from 'kern/componentBuilder';
import {isFlagEnabled} from 'kern/featureFlag';

export default class SubscriberFeatureFlag extends ComponentBuilder()
{
	results = [];

	get hasResults()
	{
		return this.results.length > 0;
	}

	async runTests()
	{
		const checks = [];

		try
		{
			const bypassAuditEnabled = await isFlagEnabled('BypassAudit_Enabled');
			checks.push({
				name: 'BypassAudit_Enabled', pass: bypassAuditEnabled === true, detail: `bridge resolved to ${bypassAuditEnabled} (expected true — default-on framework flag)`
			});
		}
		catch(error)
		{
			checks.push({name: 'BypassAudit_Enabled', pass: false, detail: `bridge threw: ${error.message ?? error}`});
		}

		try
		{
			const missingFlag = await isFlagEnabled('NonexistentFlag_NeverConfigured_SubscriberE2E');
			checks.push({
				name: 'NonexistentFlag_NeverConfigured', pass: missingFlag === false, detail: `bridge resolved to ${missingFlag} (expected false — flag does not exist)`
			});
		}
		catch(error)
		{
			checks.push({name: 'NonexistentFlag_NeverConfigured', pass: false, detail: `bridge threw: ${error.message ?? error}`});
		}

		try
		{
			const userModeQueries = await isFlagEnabled('UserModeQueries_Enabled');
			checks.push({
				name: 'UserModeQueries_Enabled', pass: typeof userModeQueries === 'boolean', detail: `bridge resolved to ${userModeQueries} (any boolean accepted — flag exists)`
			});
		}
		catch(error)
		{
			checks.push({name: 'UserModeQueries_Enabled', pass: false, detail: `bridge threw: ${error.message ?? error}`});
		}

		this.results = checks.map(check => ({
			...check, label: `${check.name}: ${check.pass ? 'PASS' : 'FAIL'} — ${check.detail}`
		}));
	}
}
