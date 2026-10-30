// SPDX-License-Identifier: Apache-2.0
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

	@IsTest
	private static void shouldNotThrowByCallingBare()
	{
		quietMethod();
		Assert.isTrue(true, 'A method that must not throw is simply called; a throw fails the test with the real error');
	}

	@IsTest
	private static void shouldAllowLocalsReassignedInsideTheCatch()
	{
		try
		{
			throwingMethod();
			Assert.fail('Expected IllegalArgumentException');
		}
		catch(Exception error)
		{
			String message = error.getMessage();
			message = message.toUpperCase();
			Assert.isTrue(message.contains('BOOM'), 'A local declared and reassigned inside the catch is not a sentinel');
		}
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
