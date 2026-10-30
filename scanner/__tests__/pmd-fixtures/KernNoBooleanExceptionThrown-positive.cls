// SPDX-License-Identifier: Apache-2.0
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

	@IsTest
	private static void shouldUseCapturedExceptionSentinel()
	{
		Exception caught;
		try
		{
			throwingMethod();
		}
		catch(IllegalArgumentException named)
		{
			caught = named;
		}
		catch(DmlException redacted)
		{
			caught = redacted;
		}
		Assert.isNotNull(caught, 'should throw');
	}

	@IsTest
	private static void shouldUseInverseSentinelToProveNoThrow()
	{
		Exception errorThrown;
		try
		{
			quietMethod();
		}
		catch(Exception error)
		{
			errorThrown = error;
		}
		Assert.isNull(errorThrown, 'should not throw');
	}

	private static void throwingMethod()
	{
		throw new IllegalArgumentException('boom');
	}

	private static void quietMethod()
	{
		Integer unused = 1;
	}
}
