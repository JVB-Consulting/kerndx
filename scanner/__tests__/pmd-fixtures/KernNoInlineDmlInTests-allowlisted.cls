// SPDX-License-Identifier: Apache-2.0
@IsTest(SeeAllData=false IsParallel=true)
private class TST_Builder_TEST
{
	@IsTest
	private static void shouldPerformDirectDmlForBuilderSelfTest()
	{
		Account account = new Account(Name = 'Test');
		insert account;
		Assert.isNotNull(account.Id, 'account inserted');
	}
}
