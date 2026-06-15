// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Drift-guard demo class for the Fast Start - Feature Flags guide. Demonstrates
 * the core flag-check pattern: branching on a feature flag to switch between legacy and new
 * pricing calculation logic.
 *
 * @see FastStart_FeatureFlag_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
public with sharing class FastStart_FeatureFlag_DEMO
{
	/**
	 * @description Feature flag name controlling the new pricing calculation.
	 */
	@TestVisible private static final String FLAG_NEW_PRICING = 'FastStart_NewPricing';

	/**
	 * @description Legacy surcharge rate applied when the flag is off (5%).
	 */
	@TestVisible private static final Decimal LEGACY_SURCHARGE = 0.05;

	/**
	 * @description New surcharge rate applied when the flag is on (3%).
	 */
	@TestVisible private static final Decimal NEW_SURCHARGE = 0.03;

	/**
	 * @description Calculates the final amount after applying the appropriate surcharge.
	 * Branches on {@link kern.UTIL_FeatureFlag#isEnabled} to select the legacy (5%) or
	 * new (3%) surcharge rate.
	 *
	 * @param baseAmount The base amount before surcharge.
	 *
	 * @return The total amount after surcharge.
	 */
	public Decimal processWithNewPricing(Decimal baseAmount)
	{
		if(kern.UTIL_FeatureFlag.isEnabled(FLAG_NEW_PRICING))
		{
			return baseAmount + (baseAmount * NEW_SURCHARGE);
		}

		return baseAmount + (baseAmount * LEGACY_SURCHARGE);
	}
}
