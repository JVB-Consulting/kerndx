// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Apex controller for subscriber LWC integration tests.
 *              Provides AuraEnabled methods to verify cross-namespace controller calls.
 *
 * @author developer@kerndx.com
 *
 * @group Subscriber Integration Tests
 *
 * @date March 2026, May 2026
 */
public with sharing class CTRL_SubscriberLwcTest
{
	/**
	 * @description Error message thrown on purpose for error handling tests.
	 */
	@TestVisible
	private static final String ERROR_ON_PURPOSE = 'Intentional error for testing';

	/**
	 * @description Echoes back the provided input with a prefix.
	 *
	 * @param input The string to echo
	 *
	 * @return The echoed string prefixed with 'Echo: '
	 */
	@AuraEnabled
	public static String echo(String input)
	{
		return 'Echo: ' + input;
	}

	/**
	 * @description Throws an exception on purpose for error handling verification.
	 *
	 * @throws AuraHandledException Always thrown with a test error message
	 */
	@AuraEnabled
	public static void failOnPurpose()
	{
		throw new AuraHandledException(ERROR_ON_PURPOSE);
	}

	/**
	 * @description Returns recently created Accounts.
	 *
	 * @return List of up to 5 recent Accounts ordered by CreatedDate descending
	 */
	@AuraEnabled
	public static List<Account> getRecentAccounts()
	{
		return
		[
				SELECT Id,
						Name,
						CreatedDate
				FROM Account
				ORDER BY CreatedDate DESC
				LIMIT 5
		];
	}
}
