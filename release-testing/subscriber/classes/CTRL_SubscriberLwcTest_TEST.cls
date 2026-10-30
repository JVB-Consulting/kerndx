// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests for CTRL_SubscriberLwcTest.
 *
 * @see CTRL_SubscriberLwcTest
 *
 * @author developer@kerndx.com
 *
 * @group Subscriber Integration Tests
 *
 * @date March 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=true)
private class CTRL_SubscriberLwcTest_TEST
{
	/**
	 * @description Test input for the echo method.
	 */
	private static final String TEST_INPUT = 'subscriber test';

	/**
	 * @description The echo method returns the text it was given behind the "Echo: " prefix, so a caller can tell that
	 * its text reached the controller and the answer came back from it.
	 */
	@IsTest
	private static void shouldEchoInput()
	{
		String result = CTRL_SubscriberLwcTest.echo(TEST_INPUT);
		Assert.areEqual('Echo: ' + TEST_INPUT, result, 'Echo should prefix the input');
	}

	/**
	 * @description The failOnPurpose method always throws an AuraHandledException, the exception a Lightning component
	 * receives as an error it can show, so a component's error handling can be exercised on demand.
	 */
	@IsTest
	private static void shouldThrowOnFailOnPurpose()
	{
		try
		{
			CTRL_SubscriberLwcTest.failOnPurpose();
			Assert.fail('Should throw AuraHandledException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, AuraHandledException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description With one more Account than the limit, each created a day before the last, getRecentAccounts returns
	 * exactly the limit's worth, newest first, leaves out the oldest, and each carries its Name.
	 */
	@IsTest
	private static void shouldReturnRecentAccounts()
	{
		kern.TRG_Base.bypass(Account.SObjectType);
		List<SObject> accounts = kern.TST_Builder.of(Account.SObjectType).withCount(CTRL_SubscriberLwcTest.RECENT_ACCOUNT_LIMIT + 1).buildList();
		Datetime now = Datetime.now();
		List<Id> expectedIds = new List<Id>();
		Map<Id, String> namesById = new Map<Id, String>();
		for(Integer position = 0; position < accounts.size(); position++)
		{
			Account createdAccount = (Account)accounts[position];
			Test.setCreatedDate(createdAccount.Id, now.addDays(-position));
			namesById.put(createdAccount.Id, createdAccount.Name);
			if(position < CTRL_SubscriberLwcTest.RECENT_ACCOUNT_LIMIT)
			{
				expectedIds.add(createdAccount.Id);
			}
		}

		List<Account> result = CTRL_SubscriberLwcTest.getRecentAccounts();

		List<Id> resultIds = new List<Id>();
		for(Account recentAccount : result)
		{
			resultIds.add(recentAccount.Id);
			Assert.areEqual(namesById.get(recentAccount.Id), recentAccount.Name, 'Expected the Account\'s Name, got ' + recentAccount.Name);
		}
		Assert.areEqual(expectedIds, resultIds, 'Expected the newest Accounts up to the limit, newest first, got ' + resultIds);
	}

	/**
	 * @description With no Accounts in the org's test data, getRecentAccounts answers with an empty list rather than
	 * null, so a component can read the answer without a null check.
	 */
	@IsTest
	private static void shouldReturnAnEmptyListWhenThereAreNoAccounts()
	{
		List<Account> result = CTRL_SubscriberLwcTest.getRecentAccounts();

		Assert.areEqual(0, result.size(), 'Expected no Accounts, got ' + result);
	}
}
