// SPDX-License-Identifier: BUSL-1.1
@IsTest(SeeAllData=false IsParallel=true)
private class KernUseTestBuilder_Positive_TEST
{
	@IsTest
	private static void shouldBuildRecordsByHand()
	{
		Account account = new Account(Name = 'Acme');
		Contact contact = new Contact(LastName = 'Smith', AccountId = account.Id);
		Assert.isNotNull(contact.LastName, 'Contact should carry a last name');
	}

	private class Helper
	{
		private Foobar__c make()
		{
			return new Foobar__c(Name = 'inner');
		}
	}
}
