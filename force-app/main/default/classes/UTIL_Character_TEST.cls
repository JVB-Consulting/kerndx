// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Tests the utility methods for character manipulation and classification.
 *
 * @see UTIL_Character
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class UTIL_Character_TEST
{
	/**
	 * @description ASCII control characters for test assertions.
	 */
	private static final String CHARS_ASCII_CONTROL = '\n\t\r\f';

	/**
	 * @description ASCII digit characters for test assertions.
	 */
	private static final String CHARS_ASCII_DIGITS = '0123456789';

	/**
	 * @description ASCII lowercase characters for test assertions.
	 */
	private static final String CHARS_ASCII_LOWER = 'abcdefghijklmnopqrstuvwxyz';

	/**
	 * @description ASCII uppercase characters for test assertions.
	 */
	private static final String CHARS_ASCII_UPPER = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

	/**
	 * @description ASCII printable characters for test assertions.
	 */
	private static final String CHARS_ASCII_PRINTABLE = ' !"#$%&\'()*+,-./' + CHARS_ASCII_DIGITS + ':;<=>?@' +
			CHARS_ASCII_UPPER + '[\\]^_`' + CHARS_ASCII_LOWER + '{|}~';

	/**
	 * @description Non-ASCII characters for test assertions.
	 */
	private static final String CHARS_NON_ASCII = '€‚ƒ„…†‡ˆ‰Š‹ŒŽ‘’“”•–—˜™š›œžŸ ¡¢£¤¥¦§¨©ª«¬­®¯' +
			'°±²³´µ¶·¸¹º»¼½¾¿ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþ';

	/**
	 * @description Error message template for invalid character assertions.
	 */
	private static final String MSG_INVALID_CHAR = 'Expected exception for invalid char: {0}';

	/**
	 * @description Error message template for wrong result assertions.
	 */
	private static final String MSG_WRONG_RESULT = 'UTIL_Character.{0}(\'{1}\') returned {2}, expected {3}';

	/**
	 * @description Tests the isWhitespace method for whitespace character detection.
	 *
	 * @see UTIL_Character.isWhitespace
	 */
	@IsTest
	private static void isWhitespace()
	{
		for(Integer i = 0; i < CHARS_ASCII_UPPER.length(); i++)
		{
			assertIsWhitespace(UTIL_String.charAt(CHARS_ASCII_UPPER, i), false);
		}
		for(Integer i = 0; i < CHARS_ASCII_LOWER.length(); i++)
		{
			assertIsWhitespace(UTIL_String.charAt(CHARS_ASCII_LOWER, i), false);
		}
		for(Integer i = 0; i < CHARS_ASCII_DIGITS.length(); i++)
		{
			assertIsWhitespace(UTIL_String.charAt(CHARS_ASCII_DIGITS, i), false);
		}
		for(Integer i = 0; i < CHARS_NON_ASCII.length(); i++)
		{
			assertIsWhitespace(UTIL_String.charAt(CHARS_NON_ASCII, i), false);
		}
		for(Integer i = 0; i < CHARS_ASCII_CONTROL.length(); i++)
		{
			assertIsWhitespace(UTIL_String.charAt(CHARS_ASCII_CONTROL, i), true);
		}
	}

	/**
	 * @description Tests the toChar method for converting ASCII values to characters.
	 *
	 * @see UTIL_Character.toChar
	 */
	@IsTest
	private static void toChar()
	{
		assertToChar(-1, null);
		assertToChar(0, null);
		assertToChar(128, null);
		assertToChar(9, '\t');
		assertToChar(10, '\n');
		assertToChar(12, '\f');
		assertToChar(13, '\r');
		for(Integer i = 32; i < 128; i++)
		{
			assertToChar(i, UTIL_String.charAt(CHARS_ASCII_PRINTABLE, i - 32));
		}
	}

	/**
	 * @description Tests the validateChar method for character validation.
	 *
	 * @see UTIL_Character.validateChar
	 */
	@IsTest
	private static void validateChar()
	{
		for(String badChar : new List<String> {'', 'AB'})
		{
			try
			{
				UTIL_Character.validateChar(badChar);
				Assert.fail(String.format(MSG_INVALID_CHAR, new List<Object> {badChar}));
			}
			catch(Exception caughtException)
			{
				Assert.isInstanceOfType(caughtException, IllegalArgumentException.class, 'Expected IllegalArgumentException for invalid char: ' + badChar);
			}
		}

		Exception errorThrown;
		try
		{
			UTIL_Character.validateChar('B');
		}
		catch(Exception error)
		{
			errorThrown = error;
		}

		Assert.isNull(errorThrown, 'No error should be thrown for a valid char');
	}

	/**
	 * @description Asserts the result of isWhitespace method.
	 *
	 * @param character The character to test.
	 * @param expected The expected result.
	 */
	private static void assertIsWhitespace(String character, Boolean expected)
	{
		Boolean actual = UTIL_Character.isWhitespace(character);
		Assert.areEqual(expected, actual, String.format(MSG_WRONG_RESULT, new List<Object> {'isWhitespace', character, actual, expected}));
	}

	/**
	 * @description Asserts the result of toChar method.
	 *
	 * @param ascii The ASCII value to test.
	 * @param expected The expected character.
	 */
	private static void assertToChar(Integer ascii, String expected)
	{
		String actual = UTIL_Character.toChar(ascii);
		Assert.areEqual(expected, actual, String.format(MSG_WRONG_RESULT, new List<Object> {'toChar', ascii, actual, expected}));
	}
}