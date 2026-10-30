// SPDX-License-Identifier: Apache-2.0
/**
 * @description Validates instantiation and message propagation for each UTIL_Exceptions exception type.
 *
 * @see UTIL_Exceptions
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class UTIL_Exceptions_TEST
{
	/**
	 * @description Shared error text for all throw-and-catch assertions.
	 */
	private static final String ERROR_MESSAGE = 'Simulated failure for unit test';

	/**
	 * @description Verifies ConfigurationException carries the supplied message.
	 */
	@IsTest
	private static void shouldThrowConfigurationException()
	{
		try
		{
			throw new UTIL_Exceptions.ConfigurationException(ERROR_MESSAGE);
		}
		catch(Exception caught)
		{
			Assert.isInstanceOfType(caught, UTIL_Exceptions.ConfigurationException.class, 'Expected ConfigurationException');
			Assert.areEqual(ERROR_MESSAGE, caught.getMessage(), 'Message should match');
		}
	}

	/**
	 * @description Verifies NotFoundException carries the supplied message.
	 */
	@IsTest
	private static void shouldThrowNotFoundException()
	{
		try
		{
			throw new UTIL_Exceptions.NotFoundException(ERROR_MESSAGE);
		}
		catch(Exception caught)
		{
			Assert.isInstanceOfType(caught, UTIL_Exceptions.NotFoundException.class, 'Expected NotFoundException');
			Assert.areEqual(ERROR_MESSAGE, caught.getMessage(), 'Message should match');
		}
	}

	/**
	 * @description Verifies IllegalStateException carries the supplied message.
	 */
	@IsTest
	private static void shouldThrowIllegalStateException()
	{
		try
		{
			throw new UTIL_Exceptions.IllegalStateException(ERROR_MESSAGE);
		}
		catch(Exception caught)
		{
			Assert.isInstanceOfType(caught, UTIL_Exceptions.IllegalStateException.class, 'Expected IllegalStateException');
			Assert.areEqual(ERROR_MESSAGE, caught.getMessage(), 'Message should match');
		}
	}

	/**
	 * @description Verifies MaskingBlockedException carries the supplied message and is
	 * catchable by its global type from the kern namespace.
	 */
	@IsTest
	private static void shouldThrowMaskingBlockedException()
	{
		try
		{
			throw new UTIL_Exceptions.MaskingBlockedException(ERROR_MESSAGE);
		}
		catch(Exception caught)
		{
			Assert.isInstanceOfType(caught, UTIL_Exceptions.MaskingBlockedException.class, 'Expected MaskingBlockedException');
			Assert.areEqual(ERROR_MESSAGE, caught.getMessage(), 'Message should match');
		}
	}

	/**
	 * @description Verifies that an ordinary runtime exception is not read as a fatal governor error, so a caller's
	 * catch block handles it through its own failure policy instead of rethrowing it.
	 */
	@IsTest
	private static void shouldNotReadAnOrdinaryExceptionAsAFatalGovernorError()
	{
		Boolean isFatal = UTIL_Exceptions.isFatalGovernorError(new UTIL_Exceptions.IllegalStateException(ERROR_MESSAGE));

		Assert.isFalse(isFatal, 'Expected an IllegalStateException not to be read as a fatal governor error, got a fatal reading');
	}

	/**
	 * @description Verifies PermanentFailureException carries the supplied message and is catchable by its own type, which
	 * is how the outbound retry decision recognises a handler's refusal of a retry.
	 */
	@IsTest
	private static void shouldThrowPermanentFailureException()
	{
		try
		{
			throw new UTIL_Exceptions.PermanentFailureException(ERROR_MESSAGE);
		}
		catch(Exception caught)
		{
			Assert.isInstanceOfType(caught, UTIL_Exceptions.PermanentFailureException.class, 'Expected PermanentFailureException, got ' + caught.getTypeName());
			Assert.areEqual(ERROR_MESSAGE, caught.getMessage(), 'Expected the supplied message, got ' + caught.getMessage());
		}
	}

	/**
	 * @description Verifies RequestRefusedException is a PermanentFailureException that carries the supplied message, so the
	 * outbound retry decision refuses it as it refuses its parent.
	 */
	@IsTest
	private static void shouldThrowRequestRefusedExceptionAsAPermanentFailure()
	{
		try
		{
			refuseTheRequest();
			Assert.fail('Expected RequestRefusedException to be thrown');
		}
		catch(UTIL_Exceptions.PermanentFailureException caught)
		{
			Assert.isInstanceOfType(caught, UTIL_Exceptions.RequestRefusedException.class, 'Expected RequestRefusedException, got ' + caught.getTypeName());
			Assert.areEqual(ERROR_MESSAGE, caught.getMessage(), 'Expected the supplied message, got ' + caught.getMessage());
		}
	}

	/**
	 * @description Throws a RequestRefusedException with the shared test message.
	 */
	private static void refuseTheRequest()
	{
		throw new UTIL_Exceptions.RequestRefusedException(ERROR_MESSAGE);
	}
}