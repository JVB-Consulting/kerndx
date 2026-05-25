// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Calculates pricing using either legacy or new engine based on feature flag.
 *
 * @see SVC_PricingCalculator_TEST
 *
 * @author your.name@company.com
 *
 * @group Pricing
 *
 * @date February 2026, May 2026
 */
public with sharing class SVC_PricingCalculator
{
	/**
	 * @description Feature flag name controlling the pricing engine.
	 */
	@TestVisible private static final String FLAG_NEW_PRICING = 'NewPricingEngine';

	/**
	 * @description Legacy discount rate (10%).
	 */
	@TestVisible private static final Decimal LEGACY_DISCOUNT = 0.10;

	/**
	 * @description New discount rate (15%).
	 */
	@TestVisible private static final Decimal NEW_DISCOUNT = 0.15;

	/**
	 * @description Calculates the final price after applying the appropriate discount.
	 *
	 * @param basePrice The base price before discount.
	 *
	 * @return The discounted price.
	 */
	public Decimal calculatePrice(Decimal basePrice)
	{
		Decimal discount;

		if(kern.UTIL_FeatureFlag.isEnabled(FLAG_NEW_PRICING))
		{
			discount = NEW_DISCOUNT;
			kern.LOG_Builder.build().info('Using new pricing engine')
					.at('SVC_PricingCalculator.calculatePrice')
					.withContext('discount', NEW_DISCOUNT)
					.emit();
		}
		else
		{
			discount = LEGACY_DISCOUNT;
			kern.LOG_Builder.build().info('Using legacy pricing engine')
					.at('SVC_PricingCalculator.calculatePrice')
					.withContext('discount', LEGACY_DISCOUNT)
					.emit();
		}

		return basePrice - (basePrice * discount);
	}
}
