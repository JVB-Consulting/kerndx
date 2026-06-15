// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for FastStart_FeatureFlag_DEMO. Validates both the legacy and new
 * pricing branches at 100% coverage using the in-memory flag seeding API.
 *
 * @see FastStart_FeatureFlag_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FastStart_FeatureFlag_DEMO_TEST
{
	/**
	 * @description Base amount used across all pricing tests.
	 */
	private static final Decimal BASE_AMOUNT = 100.00;

	/**
	 * @description Verifies the legacy surcharge (5%) is applied when the flag is not active.
	 * No flag is seeded — the missing flag returns false by default.
	 */
	@IsTest
	private static void shouldApplyLegacySurchargeWhenFlagDisabled()
	{
		Decimal result = new FastStart_FeatureFlag_DEMO().processWithNewPricing(BASE_AMOUNT);

		Decimal expected = BASE_AMOUNT + (BASE_AMOUNT * FastStart_FeatureFlag_DEMO.LEGACY_SURCHARGE);
		Assert.areEqual(expected, result, 'Should apply the legacy 5% surcharge when flag is off');
	}

	/**
	 * @description Verifies the new surcharge (3%) is applied when the flag is active.
	 * Uses kern.TST_Factory.newFeatureFlag to seed an in-memory active flag — no CMDT record
	 * is created in the org and no cleanup is needed between tests.
	 */
	@IsTest
	private static void shouldApplyNewSurchargeWhenFlagEnabled()
	{
		kern.TST_Factory.newFeatureFlag(FastStart_FeatureFlag_DEMO.FLAG_NEW_PRICING);

		Decimal result = new FastStart_FeatureFlag_DEMO().processWithNewPricing(BASE_AMOUNT);

		Decimal expected = BASE_AMOUNT + (BASE_AMOUNT * FastStart_FeatureFlag_DEMO.NEW_SURCHARGE);
		Assert.areEqual(expected, result, 'Should apply the new 3% surcharge when flag is on');
	}
}
