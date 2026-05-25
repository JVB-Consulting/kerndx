// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Validates instantiation and message propagation for each UTIL_Exceptions exception type.
 *
 * @see UTIL_Exceptions
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
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
}