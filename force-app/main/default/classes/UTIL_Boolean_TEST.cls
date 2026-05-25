// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Tests the utility methods for Boolean evaluation and conversion.
 *
 * @see UTIL_Boolean
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_Boolean_TEST
{
	/**
	 * @description Assertion message template for unexpected return values.
	 */
	private static final String MSG_WRONG_RESULT = 'UTIL_Boolean.{0}({1}) returned {2}, expected {3}';

	/**
	 * @description Tests the isTrue method for checking if a Boolean is true.
	 *
	 * @see UTIL_Boolean.isTrue
	 */
	@IsTest
	private static void shouldReturnTrueForTrueInput()
	{
		assertIsTrue(true, true);
		assertIsTrue(false, false);
		assertIsTrue(null, false);
	}

	/**
	 * @description Tests the toBoolean method for converting strings to Booleans.
	 *
	 * @see UTIL_Boolean.toBoolean
	 */
	@IsTest
	private static void shouldConvertStringToBoolean()
	{
		assertToBoolean('true', true);
		assertToBoolean('yes', true);
		assertToBoolean('y', true);
		assertToBoolean('1', true);
		assertToBoolean('false', false);
		assertToBoolean('no', false);
		assertToBoolean((String)null, false);
	}

	/**
	 * @description Asserts the result of the isTrue method.
	 *
	 * @param input The Boolean input to test.
	 * @param expected The expected result.
	 */
	private static void assertIsTrue(Boolean input, Boolean expected)
	{
		Boolean actual = UTIL_Boolean.isTrue(input);
		Assert.areEqual(expected, actual, String.format(MSG_WRONG_RESULT, new List<Object> {'isTrue', input, actual, expected}));
	}

	/**
	 * @description Asserts the result of the toBoolean method for String input.
	 *
	 * @param input The String input to test.
	 * @param expected The expected result.
	 */
	private static void assertToBoolean(String input, Boolean expected)
	{
		Boolean actual = UTIL_Boolean.toBoolean(input);
		Assert.areEqual(expected, actual, String.format(MSG_WRONG_RESULT, new List<Object> {'toBoolean', input, actual, expected}));
	}
}