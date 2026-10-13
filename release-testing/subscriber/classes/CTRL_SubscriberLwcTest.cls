// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Apex controller for subscriber LWC integration tests.
 *              Provides AuraEnabled methods to verify cross-namespace controller calls.
 *
 * @author developer@kerndx.com
 *
 * @group Subscriber Integration Tests
 *
 * @date March 2026, October 2026
 */
public with sharing class CTRL_SubscriberLwcTest
{
	/**
	 * @description Error message thrown on purpose for error handling tests.
	 */
	@TestVisible
	private static final String ERROR_ON_PURPOSE = 'Intentional error for testing';
	/**
	 * @description The most Accounts getRecentAccounts returns.
	 */
	@TestVisible
	private static final Integer RECENT_ACCOUNT_LIMIT = 5;

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
	 * @description Returns the most recently created Accounts the running user can see, newest first, with their Id, Name
	 * and CreatedDate.
	 *
	 * @return Up to RECENT_ACCOUNT_LIMIT Accounts ordered by CreatedDate, newest first; an empty list when there are none.
	 */
	@AuraEnabled
	public static List<Account> getRecentAccounts()
	{
		return kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Id, Account.Name, Account.CreatedDate})
				.orderBy(Account.CreatedDate).descending()
				.withLimit(RECENT_ACCOUNT_LIMIT)
				.toList();
	}
}
