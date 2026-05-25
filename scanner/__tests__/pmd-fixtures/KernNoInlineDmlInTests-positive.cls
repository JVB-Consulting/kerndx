// SPDX-License-Identifier: BUSL-1.1
@IsTest(SeeAllData=false IsParallel=true)
private class KernNoInlineDmlInTests_Positive_TEST
{
	@IsTest
	private static void shouldUseInlineInsert()
	{
		Account account = new Account(Name = 'Test');
		insert account;
		Assert.isNotNull(account.Id, 'account inserted');
	}

	@IsTest
	private static void shouldUseDatabaseInsert()
	{
		Account account = new Account(Name = 'Test');
		Database.insert(account, false);
		Assert.isNotNull(account.Id, 'account inserted');
	}
}
