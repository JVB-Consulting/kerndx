// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Classifies Accounts based on industry and revenue.
 *
 * @see UTIL_AccountClassifier_TEST
 *
 * @author your.name@company.com
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
public with sharing class UTIL_AccountClassifier
{
	/**
	 * @description Classification for high-revenue accounts.
	 */
	@TestVisible
	private static final String ENTERPRISE = 'Enterprise';

	/**
	 * @description Classification for standard accounts with an industry.
	 */
	@TestVisible
	private static final String STANDARD = 'Standard';

	/**
	 * @description Classification for accounts with no industry.
	 */
	@TestVisible
	private static final String UNCLASSIFIED = 'Unclassified';

	/**
	 * @description Revenue threshold for enterprise classification.
	 */
	@TestVisible
	private static final Decimal ENTERPRISE_THRESHOLD = 1000000;

	/**
	 * @description Classifies an Account based on its Industry and AnnualRevenue.
	 *
	 * @param record The Account to classify.
	 *
	 * @return The classification string.
	 */
	public static String classify(Account record)
	{
		if(String.isBlank(record.Industry))
		{
			return UNCLASSIFIED;
		}
		if(record.AnnualRevenue != null && record.AnnualRevenue > ENTERPRISE_THRESHOLD)
		{
			return ENTERPRISE;
		}
		return STANDARD;
	}
}
