// SPDX-License-Identifier: Apache-2.0
/**
 * @description Shows that a subscriber test can turn off a feature flag the org ships on. EnableSubscriberFlowAction is deployed
 * active and enabled by default, so without the call a test reads it as on. kern.TST_Factory.newDisabledFeatureFlag turns it
 * off for the rest of the test.
 *
 * @author Jason van Beukering
 *
 * @group Feature Flags
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class SubscriberDisabledFeatureFlag_TEST
{
	/**
	 * @description A feature flag this org deploys active and enabled by default, with no strategy.
	 */
	private static final String FLAG_SHIPPED_ON = 'EnableSubscriberFlowAction';

	/**
	 * @description The deployed flag reads as on until the test turns it off, and as off afterwards.
	 */
	@IsTest
	private static void shouldTurnOffAFlagTheOrgShipsOn()
	{
		Assert.isTrue(kern.UTIL_FeatureFlag.isEnabled(FLAG_SHIPPED_ON), 'Expected the deployed flag to be on before the test turns it off');

		kern.TST_Factory.newDisabledFeatureFlag(FLAG_SHIPPED_ON);

		Assert.isFalse(kern.UTIL_FeatureFlag.isEnabled(FLAG_SHIPPED_ON), 'Expected the flag to be off after newDisabledFeatureFlag');
	}
}
