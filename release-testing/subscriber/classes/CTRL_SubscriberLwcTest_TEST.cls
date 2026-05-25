// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for CTRL_SubscriberLwcTest.
 *
 * @see CTRL_SubscriberLwcTest
 *
 * @author developer@kerndx.com
 *
 * @group Subscriber Integration Tests
 *
 * @date March 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
private class CTRL_SubscriberLwcTest_TEST
{
	/**
	 * @description Test input for the echo method.
	 */
	private static final String TEST_INPUT = 'subscriber test';

	@IsTest
	private static void shouldEchoInput()
	{
		String result = CTRL_SubscriberLwcTest.echo(TEST_INPUT);
		Assert.areEqual('Echo: ' + TEST_INPUT, result, 'Echo should prefix the input');
	}

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

	@IsTest
	private static void shouldReturnRecentAccounts()
	{
		List<Account> result = CTRL_SubscriberLwcTest.getRecentAccounts();
		Assert.isNotNull(result, 'Result should not be null');
		Assert.isTrue(result instanceof List<Account>, 'Result should be a List of Accounts');
	}
}
