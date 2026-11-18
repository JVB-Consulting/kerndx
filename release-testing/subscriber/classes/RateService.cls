// SPDX-License-Identifier: Apache-2.0
/**
 * @description Stands in for the reader's own slow service that the Platform Cache sample of the Why KernDX page calls.
 * It returns a fixed exchange rate and counts how often it was asked, so a test can see whether the cache answered.
 *
 * @see DocumentationSamplesFrontPage_TEST
 *
 * @author your.name@company.com
 *
 * @group Documentation Samples
 *
 * @date November 2026
 */
public with sharing class RateService
{
	/**
	 * @description The exchange rate from US dollars to euros that this stand-in always returns.
	 */
	public static final Decimal USD_TO_EUR = 0.92;

	/**
	 * @description How many times fetch() ran in this transaction.
	 */
	public static Integer fetchCount = 0;

	/**
	 * @description Returns the exchange rate, as a slow service would.
	 *
	 * @return The exchange rate from US dollars to euros.
	 */
	public static Object fetch()
	{
		fetchCount++;
		return USD_TO_EUR;
	}
}
