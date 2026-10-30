// SPDX-License-Identifier: Apache-2.0
/**
 * @description This class is used in Flows to check whether a specific feature flag is enabled.
 * It provides a method that can be invoked from a flow to determine if a feature is active
 * for the current user based on the UTIL_FeatureFlag utility.
 *
 * @see FLOW_CheckFeatureFlag_TEST
 * @see UTIL_FeatureFlag
 *
 * @author Jason van Beukering
 *
 * @group Feature Flags
 *
 * @date November 2025, October 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * List<Boolean> results = FLOW_CheckFeatureFlag.isEnabled(new List<String> {'NewDashboard'});
 * Boolean isEnabled = results[0];
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_CheckFeatureFlag
{
	/**
	 * @description Returns if the specified feature flag is enabled for the current user.
	 *
	 * @param flagNames The API names of the feature flags to check, one per Flow interview.
	 *
	 * @return One Boolean for each name, in the same order: true when that flag is enabled for the current user.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Boolean> results = FLOW_CheckFeatureFlag.isEnabled(new List<String>{'NewDashboard', 'BetaFeature'});
	 * if(results[0])
	 * {
	 * 	LOG_Builder.build().info('NewDashboard feature is enabled').emitAt('MyFlow.checkFlag');
	 * }
	 * ```
	 */
	@InvocableMethod(category='Utilities' label='Is Feature Flag Enabled' description='Returns true if the specified Feature Flag is enabled for the current user.')
	global static List<Boolean> isEnabled(List<String> flagNames)
	{
		List<Boolean> flagStatuses = new List<Boolean>();

		for(String flagName : flagNames)
		{
			flagStatuses.add(UTIL_FeatureFlag.isEnabled(flagName));
		}

		return flagStatuses;
	}
}