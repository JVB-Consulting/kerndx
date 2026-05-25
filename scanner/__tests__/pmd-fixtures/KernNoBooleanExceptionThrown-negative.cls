// SPDX-License-Identifier: BUSL-1.1
@IsTest(SeeAllData=false IsParallel=true)
private class KernNoBooleanExceptionThrown_Negative_TEST
{
	@IsTest
	private static void shouldThrowWithAssertFail()
	{
		try
		{
			throwingMethod();
			Assert.fail('Expected IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect type');
		}
	}

	private static void throwingMethod()
	{
		throw new IllegalArgumentException('boom');
	}
}
