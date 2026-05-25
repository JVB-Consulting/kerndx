// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SVC_PricingCalculator.
 *
 * @see SVC_PricingCalculator
 *
 * @author your.name@company.com
 *
 * @group Pricing
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(IsParallel=true)
private class SVC_PricingCalculator_TEST
{
	/**
	 * @description Base price used across all tests.
	 */
	private static final Decimal BASE_PRICE = 100.00;

	/**
	 * @description Tests legacy pricing when flag is disabled.
	 */
	@IsTest
	private static void shouldUseLegacyPricingWhenFlagDisabled()
	{
		Decimal result = new SVC_PricingCalculator().calculatePrice(BASE_PRICE);

		Decimal expectedPrice = BASE_PRICE - (BASE_PRICE * SVC_PricingCalculator.LEGACY_DISCOUNT);
		Assert.areEqual(expectedPrice, result, 'Should apply legacy 10% discount');
	}

	/**
	 * @description Tests new pricing when flag is enabled.
	 */
	@IsTest
	private static void shouldUseNewPricingWhenFlagEnabled()
	{
		kern.TST_Factory.newFeatureFlag(SVC_PricingCalculator.FLAG_NEW_PRICING);

		Decimal result = new SVC_PricingCalculator().calculatePrice(BASE_PRICE);

		Decimal expectedPrice = BASE_PRICE - (BASE_PRICE * SVC_PricingCalculator.NEW_DISCOUNT);
		Assert.areEqual(expectedPrice, result, 'Should apply new 15% discount');
	}
}
