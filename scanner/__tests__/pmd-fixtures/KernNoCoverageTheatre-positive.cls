// SPDX-License-Identifier: BUSL-1.1
@IsTest(SeeAllData=false IsParallel=true)
private class KernNoCoverageTheatre_Positive_TEST
{
	@IsTest
	private static void shouldSwallowException()
	{
		try
		{
			throwingMethod();
		}
		catch(Exception error)
		{
		}
	}

	@IsTest
	private static void shouldUseBooleanExceptionFlag()
	{
		Boolean exceptionThrown = false;
		try
		{
			throwingMethod();
		}
		catch(Exception error)
		{
			exceptionThrown = true;
		}
		Assert.isTrue(exceptionThrown, 'should throw');
	}

	@IsTest
	private static void shouldHaveNoAssertions()
	{
		String value = 'untested';
		value += value;
	}

	@IsTest
	private static void shouldAssertIsNotNullRightAfterBuild()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		Assert.isNotNull(record, 'record should not be null');
	}

	private static void throwingMethod()
	{
		throw new IllegalArgumentException('boom');
	}
}
