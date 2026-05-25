// SPDX-License-Identifier: BUSL-1.1
@IsTest(SeeAllData=false IsParallel=true)
private class KernNoBooleanExceptionThrown_Positive_TEST
{
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

	private static void throwingMethod()
	{
		throw new IllegalArgumentException('boom');
	}
}
