// SPDX-License-Identifier: BUSL-1.1
@IsTest(SeeAllData=false IsParallel=true)
private class KernNoInlineDmlInTests_Negative_TEST
{
	@IsTest
	private static void shouldUseBuilderInsteadOfDml()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		Foobar__c result = [SELECT Id, Name FROM Foobar__c WHERE Id = :record.Id LIMIT 1];
		Assert.isNotNull(result.Name, 'default name should be set');
	}

	@IsTest
	private static void shouldUseDmlBuilder()
	{
		Account account = (Account)TST_Builder.of(Account.SObjectType).build();
		DML_Builder.newTransaction().doUpdate(account).execute();
		Assert.isNotNull(account.Id, 'account updated');
	}
}
