// SPDX-License-Identifier: BUSL-1.1
@IsTest(SeeAllData=false IsParallel=true)
private class KernUseTestBuilder_Negative_TEST
{
	@IsTest
	private static void shouldBuildRecordsThroughTheBuilder()
	{
		Account account = (Account)TST_Builder.of(Account.SObjectType).build();
		Account unsaved = new Account();
		Assert.areEqual('Acme', account.Name, 'Default name should be applied');
	}
}
