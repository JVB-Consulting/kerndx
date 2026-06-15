// SPDX-License-Identifier: BUSL-1.1
@IsTest(SeeAllData=false IsParallel=true)
private class KernNoCoverageTheatre_Negative_TEST
{
	@IsTest
	private static void shouldAssertOnDerivedField()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		Foobar__c result =
		[
				SELECT Id,
						Name
				FROM Foobar__c
				WHERE Id = :record.Id
				LIMIT 1
		];
		Assert.isNotNull(result.Name, 'Name default should be set');
	}

	@IsTest
	private static void shouldThrowCleanly()
	{
		try
		{
			throwingMethod();
			Assert.fail('Expected IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect exception type');
		}
	}

	@IsTest
	private static void shouldAssertPositiveCase()
	{
		Integer sum = 1 + 1;
		Assert.areEqual(2, sum, 'arithmetic still works');
	}

	private static void throwingMethod()
	{
		throw new IllegalArgumentException('boom');
	}
}
