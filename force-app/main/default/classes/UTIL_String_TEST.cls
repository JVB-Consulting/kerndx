// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Tests the behaviour of string utilities
 *
 * @see UTIL_String
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssTypeCount,PMD.ApexUnitTestClassShouldHaveRunAs')
private class UTIL_String_TEST
{
	/**
	 * @description Test string constant representing 'abc'.
	 */
	private static final String A_TO_C = 'abc';

	/**
	 * @description Ellipsis string used in abbreviation test expectations.
	 */
	private static final String ELLIPSES = '...';

	/**
	 * @description Test string constant for abbreviation assertions.
	 */
	private static final String A_TO_C_WITH_ELLIPSES = A_TO_C + ELLIPSES;

	/**
	 * @description Test string constant representing 'abcd'.
	 */
	private static final String A_TO_D = A_TO_C + 'd';

	/**
	 * @description Test string constant representing 'abcde'.
	 */
	private static final String A_TO_E = A_TO_D + 'e';

	/**
	 * @description Test string constant representing 'abcdef'.
	 */
	private static final String A_TO_F = A_TO_E + 'f';

	/**
	 * @description Test string constant representing 'abcdefg'.
	 */
	private static final String A_TO_G = A_TO_F + 'g';

	/**
	 * @description Test string constant for abbreviation assertions.
	 */
	private static final String A_TO_G_WITH_ELLIPSES = A_TO_G + ELLIPSES;

	/**
	 * @description Test string constant representing 'abcdefgij'.
	 */
	private static final String A_TO_J = A_TO_G + 'ij';

	/**
	 * @description Test string constant representing 'ijklmno'.
	 */
	private static final String I_TO_O = 'ijklmno';

	/**
	 * @description Test string constant representing 'abcdefghijklmno'.
	 */
	private static final String A_TO_O = A_TO_G + 'h' + I_TO_O;

	/**
	 * @description Test string constant with ellipsis prefix for abbreviation tests.
	 */
	private static final String I_TO_O_PREFIX_ELLIPSES = ELLIPSES + I_TO_O;

	/**
	 * @description Test string constant representing 'xyz'.
	 */
	private static final String XYZ = 'xyz';

	/**
	 * @description A Luhn-valid 15-digit American Express test number.
	 */
	private static final String VALID_AMEX_15 = '378282246310005';

	/**
	 * @description A Luhn-valid 16-digit Visa test number.
	 */
	private static final String VALID_VISA_16 = '4111111111111111';

	/**
	 * @description A Luhn-valid 16-digit Mastercard test number.
	 */
	private static final String VALID_MC_16 = '5555555555554444';

	/**
	 * @description A Luhn-valid 19-digit UnionPay test number.
	 */
	private static final String VALID_UNION_PAY_19 = '6221260000000000001';

	/**
	 * @description A 16-digit run that does not pass Luhn — representative transaction ID.
	 */
	private static final String INVALID_TRANSACTION_ID_16 = '1234567890123456';

	/**
	 * @description A 19-digit nanosecond timestamp. Not a card.
	 */
	private static final String TIMESTAMP_NANO_19 = '1776297919466123000';

	/**
	 * @description Verifies that abbreviate with two arguments truncates strings correctly.
	 */
	@IsTest
	private static void abbreviateTwoArgs()
	{
		assertAbbreviateTwoArgs(null, -1, null, false);
		assertAbbreviateTwoArgs(null, null, null, false);
		assertAbbreviateTwoArgs(A_TO_G, null, null, true);
		assertAbbreviateTwoArgs('', 4, '', false);
		assertAbbreviateTwoArgs(A_TO_G, 6, A_TO_C_WITH_ELLIPSES, false);
		assertAbbreviateTwoArgs(A_TO_G, 7, A_TO_G, false);
		assertAbbreviateTwoArgs(A_TO_G, 8, A_TO_G, false);
		assertAbbreviateTwoArgs(A_TO_G, 4, 'a...', false);
		assertAbbreviateTwoArgs(A_TO_G, 3, null, true);
	}

	/**
	 * @description Asserts that abbreviate with two arguments returns the expected result or throws as expected.
	 *
	 * @param str The input string to abbreviate.
	 * @param maxWidth The maximum width of the result.
	 * @param expected The expected abbreviated result.
	 * @param exceptionExpected Whether an exception is expected.
	 */
	private static void assertAbbreviateTwoArgs(String str, Integer maxWidth, String expected, Boolean exceptionExpected)
	{
		String actual = null;
		Boolean exceptionActual = false;
		try
		{
			actual = UTIL_String.abbreviate(str, maxWidth);
		}
		catch(IllegalArgumentException e)
		{
			exceptionActual = true;
		}
		if(exceptionExpected && exceptionActual)
		{
			return;
		}
		Assert.areEqual(exceptionExpected, exceptionActual, 'UTIL_String.abbreviate(\''
				+ str + '\',' + maxWidth + ') '
				+ (exceptionExpected ? 'did not throw' : 'unexpectedly threw')
				+ ' IllegalArgumentException');
		if(!exceptionExpected && !exceptionActual)
		{
			Assert.areEqual(expected, actual, 'UTIL_String.abbreviate(\'' + str + '\','
					+ maxWidth + ') returned ' + actual + '; expected ' + expected);
		}
	}

	/**
	 * @description Verifies that abbreviate with three arguments handles offset-based truncation correctly.
	 */
	@IsTest
	private static void abbreviateThreeArgs()
	{
		assertAbbreviateThreeArgs(null, -1, -1, null, false);
		assertAbbreviateThreeArgs('', 0, 4, '', false);
		assertAbbreviateThreeArgs(A_TO_O, -1, 10, A_TO_G_WITH_ELLIPSES, false);
		assertAbbreviateThreeArgs(A_TO_O, 0, 10, A_TO_G_WITH_ELLIPSES, false);
		assertAbbreviateThreeArgs(A_TO_O, 1, 10, A_TO_G_WITH_ELLIPSES, false);
		assertAbbreviateThreeArgs(A_TO_O, 4, 10, A_TO_G_WITH_ELLIPSES, false);
		assertAbbreviateThreeArgs(A_TO_O, 5, 10, '...fghi...', false);
		assertAbbreviateThreeArgs(A_TO_O, 6, 10, '...ghij...', false);
		assertAbbreviateThreeArgs(A_TO_O, 8, 10, I_TO_O_PREFIX_ELLIPSES, false);
		assertAbbreviateThreeArgs(A_TO_O, 10, 10, I_TO_O_PREFIX_ELLIPSES, false);
		assertAbbreviateThreeArgs(A_TO_O, 12, 10, I_TO_O_PREFIX_ELLIPSES, false);
		assertAbbreviateThreeArgs(A_TO_O, 20, 10, I_TO_O_PREFIX_ELLIPSES, false);
		assertAbbreviateThreeArgs(A_TO_J, 0, 3, null, true);
		assertAbbreviateThreeArgs(A_TO_J, 5, 6, null, true);
	}

	/**
	 * @description Asserts that abbreviate with three arguments returns the expected result or throws as expected.
	 *
	 * @param str The input string to abbreviate.
	 * @param offset The left edge offset into the string.
	 * @param maxWidth The maximum width of the result.
	 * @param expected The expected abbreviated result.
	 * @param exceptionExpected Whether an exception is expected.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static void assertAbbreviateThreeArgs(String str, Integer offset, Integer maxWidth, String expected, Boolean exceptionExpected)
	{

		String actual = null;
		Boolean exceptionActual = false;
		try
		{
			actual = UTIL_String.abbreviate(str, offset, maxWidth);
		}
		catch(IllegalArgumentException e)
		{
			exceptionActual = true;
		}
		if(exceptionExpected && exceptionActual)
		{
			return;
		}
		Assert.areEqual(exceptionExpected, exceptionActual, 'UTIL_String.abbreviate(\''
				+ str + '\',' + offset + UTIL_String.COMMA + maxWidth + ') '
				+ (exceptionExpected ? 'did not throw' : 'unexpectedly threw')
				+ ' IllegalArgumentException');
		if(!exceptionExpected && !exceptionActual)
		{
			Assert.areEqual(expected, actual, 'UTIL_String.abbreviate(\'' + str + '\','
					+ offset + UTIL_String.COMMA + maxWidth + ') returned ' + actual + '; expected ' + expected);
		}
	}

	/**
	 * @description Verifies that abbreviate with an SObjectField truncates to the field length.
	 */
	@IsTest
	private static void abbreviateWithSObjectField()
	{
		// Null string returns null
		Assert.isNull(UTIL_String.abbreviate(null, Account.Name), 'Null string should return null');

		// Null field throws IllegalArgumentException
		try
		{
			UTIL_String.abbreviate(A_TO_G, (SObjectField)null);
			Assert.fail('Expected IllegalArgumentException for null field');
		}
		catch(Exception caughtException)
		{
			Assert.isInstanceOfType(caughtException, IllegalArgumentException.class, 'Expected IllegalArgumentException');
		}

		// String shorter than field length returns unchanged
		Assert.areEqual(A_TO_G, UTIL_String.abbreviate(A_TO_G, Account.Name), 'Short string should return unchanged');

		// String longer than field length gets abbreviated
		Integer fieldLength = Account.Name.getDescribe().getLength();
		String longString = A_TO_G.repeat(100);
		String abbreviated = UTIL_String.abbreviate(longString, Account.Name);
		Assert.areEqual(fieldLength, abbreviated.length(), 'Abbreviated string should match field length');
		Assert.isTrue(abbreviated.endsWith(ELLIPSES), 'Abbreviated string should end with ellipses');
	}

	/**
	 * @description Verifies that split with one argument splits on whitespace.
	 */
	@IsTest
	private static void splitOneArg()
	{
		assertSplitOneArg(null, null);
		assertSplitOneArg('', new List<String> {''});
		assertSplitOneArg('abc def', new List<String> {A_TO_C, 'def'});
		assertSplitOneArg('abc  def', new List<String> {A_TO_C, 'def'});
		assertSplitOneArg(' abc ', new List<String> {A_TO_C});
	}

	/**
	 * @description Asserts that split with one argument returns the expected list of substrings.
	 *
	 * @param str The input string to split.
	 * @param expected The expected list of substrings.
	 */
	private static void assertSplitOneArg(String str, List<String> expected)
	{
		List<String> actual = UTIL_String.split(str);
		if(actual == null)
		{
			Assert.isNull(expected, 'UTIL_String.split(\'' + str + '\') returned ' + String.valueOf(actual));
			return;
		}
		for(Integer i = 0; i < actual.size(); i++)
		{
			Assert.areEqual(expected[i], actual[i], 'UTIL_String.split(\'' + str + '\') returned ' + String.valueOf(actual));
		}
	}

	/**
	 * @description Verifies that capitalizeWords capitalizes each word split by the given delimiter.
	 *
	 * @see UTIL_String.capitalizeWords
	 */
	@IsTest
	private static void capitalizeWords()
	{
		Assert.areEqual(null, UTIL_String.capitalizeWords(null, ' '), 'null input should return null');
		Assert.areEqual('', UTIL_String.capitalizeWords('', ' '), 'empty input should return empty');
		Assert.areEqual('Joe Soap', UTIL_String.capitalizeWords('joe soap', ' '), 'Should capitalize each word');
		Assert.areEqual('Peter Piper', UTIL_String.capitalizeWords('pEtEr pIpEr', ' '), 'Should lowercase then capitalize');
		Assert.areEqual('One,Two', UTIL_String.capitalizeWords('one,two', ','), 'Should use custom delimiter');
	}

	/**
	 * @description Verifies that charAt returns the character at the specified index.
	 */
	@IsTest
	private static void charAt()
	{
		assertCharAt(null, -1, null);
		assertCharAt(null, 0, null);
		assertCharAt(A_TO_C, -1, null);
		assertCharAt(A_TO_C, 3, null);
		assertCharAt(A_TO_C, 0, 'a');
		assertCharAt(A_TO_C, 2, 'c');
		assertCharAt(A_TO_E, -2, null);
		assertCharAt(A_TO_E, 0, 'a');
		assertCharAt(A_TO_E, 1, 'b');
		assertCharAt(A_TO_E, 4, 'e');
		assertCharAt(A_TO_E, 5, null);
		assertCharAt('', 0, '');
		assertCharAt(' ', 0, ' ');
	}

	/**
	 * @description Asserts that charAt returns the expected character.
	 *
	 * @param str The input string to index into.
	 * @param index The character index to retrieve.
	 * @param expected The expected character at the index.
	 */
	private static void assertCharAt(String str, Integer index, String expected)
	{
		String actual = UTIL_String.charAt(str, index);
		Assert.areEqual(expected, actual, 'UTIL_String.charAt(\'' + str + '\',' + index + ') returned ' + actual);
	}

	/**
	 * @description Verifies that split with two arguments splits on the specified separator.
	 */
	@IsTest
	private static void splitTwoArgs()
	{
		assertSplitTwoArgs(null, null, null);
		assertSplitTwoArgs('', null, new List<String> {''});
		assertSplitTwoArgs('', A_TO_C, new List<String> {''});
		assertSplitTwoArgs('a.b.c', '.', new List<String> {'a', 'b', 'c'});
		assertSplitTwoArgs('a..b.c', '.', new List<String> {'a', 'b', 'c'});
		assertSplitTwoArgs('a..b..c', '..', new List<String> {'a', 'b', 'c'});
		assertSplitTwoArgs('a:b:c', '.', new List<String> {'a:b:c'});
		assertSplitTwoArgs('a b c', ' ', new List<String> {'a', 'b', 'c'});
	}

	/**
	 * @description Asserts that split with two arguments returns the expected list of substrings.
	 *
	 * @param str The input string to split.
	 * @param separator The separator to split on.
	 * @param expected The expected list of substrings.
	 */
	private static void assertSplitTwoArgs(String str, String separator, List<String> expected)
	{
		List<String> actual = UTIL_String.split(str, separator);
		if(actual == null)
		{
			Assert.isNull(expected, 'UTIL_String.split(\'' + str + '\',\'' + separator + '\') returned ' + String.valueOf(actual));
			return;
		}
		for(Integer i = 0; i < actual.size(); i++)
		{
			Assert.areEqual(expected[i], actual[i], 'UTIL_String.split(\'' + str + '\',\'' + separator + '\') returned ' + String.valueOf(actual));
		}
	}

	/**
	 * @description Verifies that split with three arguments limits the number of resulting parts.
	 */
	@IsTest
	private static void splitThreeArgs()
	{
		assertSplitThreeArgs(null, '', 1, null);
		assertSplitThreeArgs('', '', 1, new List<String> {''});
		assertSplitThreeArgs('ab cd ef', null, 0, new List<String> {'ab', 'cd', 'ef'});
		assertSplitThreeArgs('ab   cd ef', null, 0, new List<String> {'ab', 'cd', 'ef'});
		assertSplitThreeArgs('ab:cd:ef', ':', 0, new List<String> {'ab', 'cd', 'ef'});
		assertSplitThreeArgs('ab:cd:ef', ':', 2, new List<String> {'ab', 'cd:ef'});
		assertSplitThreeArgs('ab cd ef', null, 2, new List<String> {'ab', 'cd ef'});
		assertSplitThreeArgs('ab:cd:ef', ':;', 2, new List<String> {'ab', 'cd:ef'});
	}

	/**
	 * @description Asserts that split with three arguments returns the expected list of substrings.
	 *
	 * @param str The input string to split.
	 * @param separator The separator to split on.
	 * @param max The maximum number of resulting parts.
	 * @param expected The expected list of substrings.
	 */
	private static void assertSplitThreeArgs(String str, String separator, Integer max, List<String> expected)
	{
		List<String> actual = UTIL_String.split(str, separator, max);
		if(actual == null)
		{
			Assert.isNull(expected, 'UTIL_String.split(\'' + str + '\',\'' + separator + '\',' + max + ') returned ' + String.valueOf(actual));
			return;
		}
		for(Integer i = 0; i < actual.size(); i++)
		{
			Assert.areEqual
					(
							expected[i],
							actual[i],
							'UTIL_String.split(\'' + str + '\',\'' + separator + '\',' + max + ') returned ' + String.valueOf(actual)
					);
		}
	}

	/**
	 * @description Verifies that splitByWholeSeparator with two arguments splits on the full separator string.
	 */
	@IsTest
	private static void splitByWholeSeparatorTwoArg()
	{
		assertSplitByWholeSeparatorTwoArg(null, null, null);
		assertSplitByWholeSeparatorTwoArg('', null, new List<String> {''});
		assertSplitByWholeSeparatorTwoArg('ab cd ef', null, new List<String> {'ab', 'cd', 'ef'});
		assertSplitByWholeSeparatorTwoArg('ab cd ef', ' ', new List<String> {'ab', 'cd', 'ef'});
		assertSplitByWholeSeparatorTwoArg('ab     cd ef', null, new List<String> {'ab', 'cd', 'ef'});
		assertSplitByWholeSeparatorTwoArg('ab:cd:ef', ':', new List<String> {'ab', 'cd', 'ef'});
		assertSplitByWholeSeparatorTwoArg('ab-!-cd-!-ef', '-!-', new List<String> {'ab', 'cd', 'ef'});
		assertSplitByWholeSeparatorTwoArg('ab::cd', ':', new List<String> {'ab', 'cd'});
	}

	/**
	 * @description Asserts that splitByWholeSeparator with two arguments returns the expected list.
	 *
	 * @param str The input string to split.
	 * @param separator The whole separator string to split on.
	 * @param expected The expected list of substrings.
	 */
	private static void assertSplitByWholeSeparatorTwoArg(String str, String separator, List<String> expected)
	{
		List<String> actual = UTIL_String.splitByWholeSeparator(str, separator);
		if(actual == null)
		{
			Assert.isNull
					(
							expected,
							'UTIL_String.splitByWholeSeparator(\'' + str + '\',\'' + separator + '\') returned ' + String.valueOf(actual)
					);
			return;
		}
		for(Integer i = 0; i < actual.size(); i++)
		{
			Assert.areEqual
					(
							expected[i],
							actual[i],
							'UTIL_String.splitByWholeSeparator(\'' + str + '\',\'' + separator + '\') returned ' + String.valueOf(actual)
					);
		}
	}

	/**
	 * @description Verifies that validateChar throws an exception for multi-character strings.
	 */
	@IsTest
	private static void validateChar()
	{
		try
		{
			UTIL_Character.validateChar('ab'); //should throw exception since string has > 1 chars
			Assert.fail('UTIL_Character.validateChar(\'ab\') did not throw IllegalArgumentException');
		}
		catch(Exception caughtException)
		{
			Assert.isInstanceOfType(caughtException, IllegalArgumentException.class, 'Expected IllegalArgumentException');
		}
	}

	/**
	 * @description Verifies that join with two arguments joins elements with the specified separator.
	 */
	@IsTest
	private static void joinTwoArgs()
	{
		assertJoinArrayTwoArgs(null, null, null);
		assertJoinArrayTwoArgs(new List<String> {}, null, '');
		assertJoinArrayTwoArgs(new List<String> {null}, null, '');
		assertJoinArrayTwoArgs(new List<String> {'a', 'b', 'c'}, ';', 'a;b;c');
		assertJoinArrayTwoArgs(new List<String> {'a', 'b', 'c'}, null, A_TO_C);
		assertJoinArrayTwoArgs(new List<String> {null, '', 'a'}, ';', ';a');
	}

	/**
	 * @description Asserts that join with two arguments returns the expected joined string.
	 *
	 * @param objectArray The array of objects to join.
	 * @param separator The separator to place between elements.
	 * @param expected The expected joined result.
	 */
	private static void assertJoinArrayTwoArgs(List<Object> objectArray, String separator, String expected)
	{
		String actual = UTIL_String.join(objectArray, separator);
		Assert.areEqual(expected, actual, 'UTIL_String.join(\'' + String.valueOf(objectArray) + '\',\''
				+ separator + '\') returned \'' + actual + '\'; expected \'' + expected + '\'');
	}

	/**
	 * @description Verifies that join with Set<String> delegates correctly.
	 */
	@IsTest
	private static void joinStrings()
	{
		Assert.isNull(UTIL_String.join((Set<String>)null, ','), 'Null set should return null');

		String result = UTIL_String.join(new Set<String> {'alpha', 'beta'}, ',');
		Assert.isTrue(result.contains('alpha'), 'Should contain alpha');
		Assert.isTrue(result.contains('beta'), 'Should contain beta');
	}

	/**
	 * @description Verifies that substring with two arguments extracts from the specified start index.
	 */
	@IsTest
	private static void substringTwoArgs()
	{
		assertSubstringTwoArgs(null, -1, null);
		assertSubstringTwoArgs('', -2, '');
		assertSubstringTwoArgs('', -1, '');
		assertSubstringTwoArgs('', 0, '');
		assertSubstringTwoArgs('', 1, '');
		assertSubstringTwoArgs(A_TO_C, 0, A_TO_C);
		assertSubstringTwoArgs(A_TO_C, 2, 'c');
		assertSubstringTwoArgs(A_TO_C, 4, '');
		assertSubstringTwoArgs(A_TO_C, -2, 'bc');
		assertSubstringTwoArgs(A_TO_C, -4, A_TO_C);
	}

	/**
	 * @description Asserts that substring with two arguments returns the expected substring.
	 *
	 * @param str The input string to extract from.
	 * @param startIndex The starting index of the substring.
	 * @param expected The expected substring result.
	 */
	private static void assertSubstringTwoArgs(String str, Integer startIndex, String expected)
	{
		String actual = UTIL_String.substring(str, startIndex);
		Assert.areEqual(expected, actual, 'UTIL_String.substring(\'' + str + '\','
				+ startIndex + ') returned \'' + actual + '\'; expected \'' + expected + '\'');
	}

	/**
	 * @description Verifies that substring with three arguments extracts between the specified indices.
	 */
	@IsTest
	private static void substringThreeArgs()
	{
		assertSubstringThreeArgs(null, -1, -1, null);
		assertSubstringThreeArgs('', -1, -1, '');
		assertSubstringThreeArgs(A_TO_C, 0, 2, 'ab');
		assertSubstringThreeArgs(A_TO_C, 2, 0, '');
		assertSubstringThreeArgs(A_TO_C, 2, 4, 'c');
		assertSubstringThreeArgs(A_TO_C, 4, 6, '');
		assertSubstringThreeArgs(A_TO_C, 2, 2, '');
		assertSubstringThreeArgs(A_TO_C, -2, -1, 'b');
		assertSubstringThreeArgs(A_TO_C, -4, 2, 'ab');
		assertSubstringThreeArgs(A_TO_C, -5, -4, '');

	}

	/**
	 * @description Asserts that substring with three arguments returns the expected substring.
	 *
	 * @param str The input string to extract from.
	 * @param startIndex The starting index of the substring.
	 * @param endIndex The ending index of the substring.
	 * @param expected The expected substring result.
	 */
	private static void assertSubstringThreeArgs(String str, Integer startIndex, Integer endIndex, String expected)
	{
		String actual = UTIL_String.substring(str, startIndex, endIndex);
		Assert.areEqual(expected, actual, 'UTIL_String.substring(\'' + str + '\','
				+ startIndex + ',' + endIndex + ') returned \'' + actual + '\'; expected \'' + expected + '\'');
	}

	/**
	 * @description Verifies that left returns the leftmost characters up to the specified length.
	 */
	@IsTest
	private static void left()
	{
		assertLeft(null, -1, null);
		assertLeft(null, 0, null);
		assertLeft(XYZ, -1, '');
		assertLeft('', -1, '');
		assertLeft('', 0, '');
		assertLeft(A_TO_C, 0, '');
		assertLeft(A_TO_C, 2, 'ab');
		assertLeft(A_TO_C, 4, A_TO_C);
	}

	/**
	 * @description Asserts that left returns the expected leftmost substring.
	 *
	 * @param str The input string to extract from.
	 * @param len The number of leftmost characters to return.
	 * @param expected The expected leftmost substring.
	 */
	private static void assertLeft(String str, Integer len, String expected)
	{
		String actual = UTIL_String.left(str, len);
		Assert.areEqual(expected, actual, 'UTIL_String.left(\'' + str + '\','
				+ len + ') returned \'' + actual + '\'; expected \'' + expected + '\'');
	}

	/**
	 * @description Verifies that remove strips all occurrences of the search string.
	 */
	@IsTest
	private static void remove()
	{
		assertRemove(null, null, null);
		assertRemove('', null, '');
		assertRemove(XYZ, null, XYZ);
		assertRemove(XYZ, '', XYZ);
		assertRemove('queued', 'ue', 'qd');
		assertRemove('queued', 'zz', 'queued');
	}

	/**
	 * @description Asserts that remove returns the expected result.
	 *
	 * @param str The input string to modify.
	 * @param remove The string to remove from the input.
	 * @param expected The expected result value.
	 */
	private static void assertRemove(String str, String remove, String expected)
	{
		String actual = UTIL_String.remove(str, remove);
		Assert.areEqual(expected, actual, 'UTIL_String.remove(\'' + str + '\',\'' + remove
				+ '\') returned \'' + actual + '\'; expected \'' + expected + '\'');
	}

	/**
	 * @description Verifies that removeStart strips the prefix if the string starts with it.
	 */
	@IsTest
	private static void removeStart()
	{
		assertRemoveStart(null, null, null);
		assertRemoveStart('', null, '');
		assertRemoveStart(XYZ, null, XYZ);
		assertRemoveStart('/', '/', '');
		assertRemoveStart('www.domain.com', 'www.', 'domain.com');
		assertRemoveStart('domain.com', 'www.', 'domain.com');
		assertRemoveStart('www.domain.com', 'domain', 'www.domain.com');
		assertRemoveStart(A_TO_C, '', A_TO_C);
	}

	/**
	 * @description Asserts that removeStart returns the expected result.
	 *
	 * @param str The input string to modify.
	 * @param remove The prefix string to remove.
	 * @param expected The expected result value.
	 */
	private static void assertRemoveStart(String str, String remove, String expected)
	{
		String actual = UTIL_String.removeStart(str, remove);
		Assert.areEqual(expected, actual, 'UTIL_String.removeStart(\'' + str + '\',\'' + remove
				+ '\') returned \'' + actual + '\'; expected \'' + expected + '\'');
	}

	/**
	 * @description Verifies that replace with three arguments substitutes all occurrences of the search string.
	 */
	@IsTest
	private static void replaceThreeArgs()
	{
		assertReplaceThreeArgs(null, null, null, null);
		assertReplaceThreeArgs('', null, null, '');
		assertReplaceThreeArgs('any', null, null, 'any');
		assertReplaceThreeArgs('any', null, null, 'any');
		assertReplaceThreeArgs('any', '', null, 'any');
		assertReplaceThreeArgs('aba', 'a', null, 'aba');
		assertReplaceThreeArgs('aba', 'a', '', 'b');
		assertReplaceThreeArgs('aba', 'a', 'z', 'zbz');
		assertReplaceThreeArgs('xyz', 'a', 'b', 'xyz');
	}

	/**
	 * @description Asserts that replace with three arguments returns the expected result.
	 *
	 * @param text The input text to modify.
	 * @param searchString The string to search for.
	 * @param replacement The string to replace with.
	 * @param expected The expected result value.
	 */
	private static void assertReplaceThreeArgs(String text, String searchString, String replacement, String expected)
	{
		String actual = UTIL_String.replace(text, searchString, replacement);
		Assert.areEqual(expected, actual, 'UTIL_String.replace(\'' + text + '\',\''
				+ searchString + '\',\'' + replacement + '\') returned \'' + actual + '\'; expected \'' + expected + '\'');
	}

	/**
	 * @description Verifies that substringBetween with three arguments extracts the string between open and close tags.
	 */
	@IsTest
	private static void substringBetweenThreeArgs()
	{
		assertSubstringBetweenThreeArgs('wx[b]yz', '[', ']', 'b');
		assertSubstringBetweenThreeArgs(null, null, null, null);
		assertSubstringBetweenThreeArgs(null, null, null, null);
		assertSubstringBetweenThreeArgs(null, null, null, null);
		assertSubstringBetweenThreeArgs('', '', '', '');
		assertSubstringBetweenThreeArgs('', '', ']', null);
		assertSubstringBetweenThreeArgs('', '[', ']', null);
		assertSubstringBetweenThreeArgs('yabcz', '', '', '');
		assertSubstringBetweenThreeArgs('yabcz', 'y', 'z', A_TO_C);
		assertSubstringBetweenThreeArgs('yabczyabcz', 'y', 'z', A_TO_C);
	}

	/**
	 * @description Asserts that substringBetween with three arguments returns the expected result.
	 *
	 * @param str The input string to extract from.
	 * @param open The opening delimiter.
	 * @param close The closing delimiter.
	 * @param expected The expected substring result.
	 */
	private static void assertSubstringBetweenThreeArgs(String str, String open, String close, String expected)
	{
		String actual = UTIL_String.substringBetween(str, open, close);
		Assert.areEqual(expected, actual, 'UTIL_String.substringBetween(\'' + str + '\',\'' + open + '\', \'' + close
				+ '\') returned \'' + actual + '\'; expected \'' + expected + '\'');
	}

	/**
	 * @description Verifies that wrapWith surrounds the string with the specified wrapper.
	 */
	@IsTest
	private static void wrapWith()
	{
		assertWrapWith(null, null, null);
		assertWrapWith(null, A_TO_C, null);
		assertWrapWith('', A_TO_C, 'abcabc');
		assertWrapWith('test123', null, 'test123');
		assertWrapWith('test123', A_TO_C, 'abctest123abc');
	}

	/**
	 * @description Asserts that wrapWith returns the expected wrapped string.
	 *
	 * @param str The input string to wrap.
	 * @param character The character to wrap with.
	 * @param expected The expected wrapped result.
	 */
	private static void assertWrapWith(String str, String character, String expected)
	{
		String actual = UTIL_String.wrapWith(str, character);
		Assert.areEqual(expected, actual, 'UTIL_String.wrapWith(\'' + str + '\', \'' + character
				+ '\') returned \'' + actual + '\'; expected \'' + expected + '\'');
	}

	/**
	 * @description To test the string which length is 10
	 */
	@IsTest
	private static void checkInvalidId()
	{
		String invalidID = UTIL_Random.randomAlphabetic(10);

		Test.startTest();

		Id validatedID = UTIL_SObject.validateId(invalidID);

		Test.stopTest();

		Assert.isNull(validatedID, 'A null Id should be returned.');
	}

	/**
	 * @description To test the Id generated
	 */
	@IsTest
	private static void checkValidId()
	{
		Foobar__c obj = TST_Factory.newFoobar();

		Test.startTest();

		Id validatedID = UTIL_SObject.validateId(obj.Id);

		Test.stopTest();

		Assert.areEqual(obj.Id, validatedID, 'Ids do not match.');
	}

	/**
	 * @description To check if string is masked correctly
	 *
	 * @see UTIL_String.maskString
	 */
	@IsTest
	private static void maskString()
	{
		final Integer minimumStringToMaskLength = 3;

		Test.startTest();

		String validStringForMasking = UTIL_String.maskString(UTIL_Random.randomAlphabetic(minimumStringToMaskLength));
		String invalidStringForMasking = UTIL_String.maskString(UTIL_Random.randomAlphabetic(minimumStringToMaskLength - 1));

		Test.stopTest();

		Assert.isTrue(String.isNotEmpty(validStringForMasking) && validStringForMasking.length() >= 3, 'Masked succesfully');
		Assert.isTrue(String.isNotEmpty(invalidStringForMasking) && invalidStringForMasking.length() < 3, 'String did not get masked');
	}

	/**
	 * @description To check if replacement of whole words is done correctly
	 *
	 * @see UTIL_String.replaceWholeWords
	 */
	@IsTest
	private static void searchAndReplaceWholeWords()
	{
		final String originalText = 'This has some words in it, butter "is" unhealthy.';
		final String expectedText = 'This has some words in it, butter "is not" unhealthy.';

		Test.startTest();

		String replacedText = UTIL_String.replaceWholeWords(originalText, 'is', 'is not');

		Test.stopTest();

		Assert.areEqual(expectedText, replacedText, 'Words were not replaced correctly');
	}

	/**
	 * @description To check if replacement of whole words is done correctly
	 *
	 * @see UTIL_String.replaceWholeWords
	 */
	@IsTest
	private static void searchAndReplaceWholeWordsWithList()
	{
		final String originalText = 'This has Thishas words in it, butter "is" unhealthy.';
		final String expectedText = 'THIS HAS Thishas words in it, butter "is not" unhealthy.';
		final List<String> searchStrings = new List<String> {'This', 'has', 'is'};
		final List<String> replacementStrings = new List<String> {'THIS', 'HAS', 'is not'};

		Test.startTest();

		String replacedText = UTIL_String.replaceWholeWords(originalText, searchStrings, replacementStrings);

		Test.stopTest();

		Assert.areEqual(expectedText, replacedText, 'Words were not replaced correctly');
	}

	/**
	 * @description To check if replacement of whole words is done correctly
	 *
	 * @see UTIL_String.replaceWholeWords
	 */
	@IsTest
	private static void searchAndReplaceWithIllegalArguments()
	{
		final String originalText = 'This has Thishas words in it, butter "is" unhealthy.';
		final List<String> searchStrings = new List<String> {'This', 'has', 'is'};
		final List<String> replacementStrings = new List<String> {'THIS', 'HAS'};

		Test.startTest();

		try
		{
			UTIL_String.replaceWholeWords(originalText, searchStrings, replacementStrings);
			Assert.fail('The method should have failed');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect exception thrown');
		}

		Test.stopTest();
	}

	/**
	 * @description Tests the DelimitedListBuilder comma-delimited output.
	 */
	@IsTest
	private static void shouldBuildDelimitedList()
	{
		UTIL_String.DelimitedListBuilder builder = new UTIL_String.DelimitedListBuilder(new List<String> {'x', 'y'});
		builder.add('a');
		builder.add(new List<String> {'b', 'c', 'd'});

		Assert.areEqual('x,y,a,b,c,d', builder.toString(), 'DelimitedListBuilder should create a comma-separated string');
	}

	/**
	 * @description Tests the DelimitedListBuilder with a custom item prefix.
	 */
	@IsTest
	private static void shouldBuildDelimitedListWithPrefix()
	{
		UTIL_String.DelimitedListBuilder builder = new UTIL_String.DelimitedListBuilder(new List<String> {'x', 'y'});
		builder.add('a');
		builder.add(new List<String> {'b', 'c', 'd'});
		builder.setItemPrefix('$');

		Assert.areEqual('$x,$y,$a,$b,$c,$d', builder.toString(), 'DelimitedListBuilder should apply prefix to each item');
	}

	/**
	 * @description Tests the DelimitedListBuilder with a custom delimiter.
	 */
	@IsTest
	private static void shouldBuildDelimitedListWithCustomDelimiter()
	{
		UTIL_String.DelimitedListBuilder builder = new UTIL_String.DelimitedListBuilder(new List<String> {'x', 'y'});
		builder.setDelimiter(';');
		builder.add('a');
		builder.add(new List<String> {'b', 'c', 'd'});

		Assert.areEqual('x;y;a;b;c;d', builder.toString(), 'DelimitedListBuilder should use custom delimiter');
	}

	/**
	 * @description Tests the DelimitedListBuilder with both a custom delimiter and prefix.
	 */
	@IsTest
	private static void shouldBuildDelimitedListWithDelimiterAndPrefix()
	{
		UTIL_String.DelimitedListBuilder builder = new UTIL_String.DelimitedListBuilder(new List<String> {'x', 'y'});
		builder.setItemPrefix('#');
		builder.setDelimiter(':');
		builder.add('a');
		builder.add(new List<String> {'b', 'c', 'd'});

		Assert.areEqual('#x:#y:#a:#b:#c:#d', builder.toString(), 'DelimitedListBuilder should apply both custom delimiter and prefix');
	}

	/**
	 * @description Tests the FieldListBuilder with a list of SObject fields.
	 */
	@IsTest
	private static void shouldBuildFieldList()
	{
		List<SObjectField> fields = new List<SObjectField>
		{
				Foobar__c.Email__c,
				Foobar__c.Lookup__c,
				Foobar__c.NumberDecimal__c
		};

		UTIL_SObjectDescribe.FieldListBuilder fieldListBuilder = new UTIL_SObjectDescribe.FieldListBuilder(fields);
		List<String> fieldList = fieldListBuilder.toString().split(UTIL_String.COMMA);
		Set<String> fieldSet = new Set<String>(fieldList);

		Assert.areEqual(3, fieldSet.size(), 'FieldListBuilder should return 3 unique fields');
		Assert.isTrue(fieldSet.contains(SEL_Foobar.FIELD_DECIMAL), 'Field set should contain NumberDecimal__c');
		Assert.isTrue(fieldSet.contains(SEL_Foobar.FIELD_EMAIL), 'Field set should contain Email__c');
		Assert.isTrue(fieldSet.contains(SEL_Foobar.FIELD_LOOKUP), 'Field set should contain Lookup__c');
	}

	/**
	 * @description Tests the FieldListBuilder with a field set and additional fields.
	 */
	@IsTest
	private static void shouldBuildFieldListWithFieldSet()
	{
		List<SObjectField> fields = new List<SObjectField> {Foobar__c.Id};
		List<FieldSet> fieldSets = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType).getFieldSetsMap().values();

		UTIL_SObjectDescribe.FieldListBuilder fieldListBuilder = new UTIL_SObjectDescribe.FieldListBuilder(fields, fieldSets);
		List<String> fieldList = fieldListBuilder.toString().split(UTIL_String.COMMA);
		Set<String> fieldSet = new Set<String>(fieldList);

		Assert.isTrue(fieldSet.contains(SEL_Foobar.FIELD_EMAIL), 'Field set should contain Email__c');
		Assert.isTrue(fieldSet.contains(SEL_Foobar.FIELD_NAME), 'Field set should contain Name');
		Assert.isTrue(fieldSet.contains(SEL_Foobar.FIELD_PHONE), 'Field set should contain Phone__c');
	}

	/**
	 * @description Tests conversion of a delimited string to a list.
	 *
	 * @see UTIL_String.toList
	 */
	@IsTest
	private static void shouldConvertToList()
	{
		List<String> resultList = UTIL_String.toList('abc; 555; a b; 555;,', UTIL_String.SEMI_COLON);

		Assert.areEqual(5, resultList.size(), 'Wrong list size');
	}

	/**
	 * @description Tests conversion of a name-value string to a map.
	 *
	 * @see UTIL_String.toMap
	 */
	@IsTest
	private static void shouldConvertToMap()
	{
		Map<String, String> resultMap = UTIL_String.toMap('paramName1=paramValue1,paramName2=paramValue2', null);

		Assert.areEqual(2, resultMap.size(), 'Map returned of wrong size');
		Assert.areEqual('paramValue1', resultMap.get('paramName1'), 'Values should match');
	}

	/**
	 * @description Tests conversion of an invalid name-value pair string to a map returns an empty map.
	 *
	 * @see UTIL_String.toMap
	 */
	@IsTest
	private static void shouldReturnEmptyMapForInvalidNameValueString()
	{
		Map<String, String> resultMap = UTIL_String.toMap(UTIL_Random.randomUUID(), null);

		Assert.isTrue(resultMap.isEmpty(), 'Map returned of wrong size');
	}

	/**
	 * @description Tests that replaceEachRepeatedly replaces all search tokens with corresponding replacements.
	 *
	 * @see UTIL_String.replaceEachRepeatedly
	 */
	@IsTest
	private static void shouldReplaceEachTokenInText()
	{
		List<String> searchTokens = new List<String> {'{{name}}', '{{org}}'};
		List<String> replaceTokens = new List<String> {'Acme', 'Corp'};

		String result = UTIL_String.replaceEachRepeatedly('Hello {{name}} at {{org}}', searchTokens, replaceTokens, false);

		Assert.areEqual('Hello Acme at Corp', result, 'Tokens should be replaced');
	}

	/**
	 * @description Tests that replaceEachRepeatedly returns the original text when inputs are null.
	 *
	 * @see UTIL_String.replaceEachRepeatedly
	 */
	@IsTest
	private static void shouldReturnOriginalTextWhenTokensAreNull()
	{
		String result = UTIL_String.replaceEachRepeatedly('Hello', null, null, false);

		Assert.areEqual('Hello', result, 'Original text should be returned');
	}

	/**
	 * @description Tests that replaceEachRepeatedly repeats replacements until text stabilises.
	 *
	 * @see UTIL_String.replaceEachRepeatedly
	 */
	@IsTest
	private static void shouldRepeatReplacementsUntilStable()
	{
		List<String> searchTokens = new List<String> {'{{a}}', '{{b}}'};
		List<String> replaceTokens = new List<String> {'{{b}}', 'final'};

		String result = UTIL_String.replaceEachRepeatedly('Start {{a}}', searchTokens, replaceTokens, true);

		Assert.areEqual('Start final', result, 'Chained tokens should resolve through repeated passes');
	}

	/**
	 * @description Tests that maskWithRegex replaces matches.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void maskWithRegexShouldReplaceMatches()
	{
		String result = UTIL_String.maskWithRegex('SSN: 123-45-6789', '\\b\\d{3}-\\d{2}-\\d{4}\\b', 'XXX-XX-XXXX');

		Assert.areEqual('SSN: XXX-XX-XXXX', result, 'Regex match should be replaced');
	}

	/**
	 * @description Tests that maskWithRegex is case-insensitive by default.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void maskWithRegexShouldBeCaseInsensitiveByDefault()
	{
		String result = UTIL_String.maskWithRegex('authorization: secret', 'AUTHORIZATION', '***');

		Assert.areEqual('***: secret', result, 'Default should match regardless of case');
	}

	/**
	 * @description Tests that maskWithRegex honours caseSensitive = true.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void maskWithRegexShouldHonourCaseSensitiveFlag()
	{
		String result = UTIL_String.maskWithRegex('authorization: secret', 'AUTHORIZATION', '***', true);

		Assert.areEqual('authorization: secret', result, 'Case-sensitive match should NOT fire on lowercase input');
	}

	/**
	 * @description Tests that maskWithRegex preserves capture groups via $1/$2.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void maskWithRegexShouldPreserveCaptureGroups()
	{
		String result = UTIL_String.maskWithRegex
				(
						'alice@example.com',
						'\\b([A-Z0-9._%+-]+)@([A-Z0-9.-]+\\.[A-Z]{2,})\\b',
						'REDACTED@$2'
				);

		Assert.areEqual('REDACTED@example.com', result, 'Capture group $2 (domain) should be preserved');
	}

	/**
	 * @description Tests that maskWithRegex returns unchanged when no match.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void maskWithRegexShouldReturnInputWhenNoMatch()
	{
		String result = UTIL_String.maskWithRegex('no digits here', '\\d+', 'X');

		Assert.areEqual('no digits here', result, 'Non-matching input should pass through unchanged');
	}

	/**
	 * @description Tests that maskWithRegex handles empty input.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void maskWithRegexShouldHandleEmptyInput()
	{
		Assert.isNull(UTIL_String.maskWithRegex(null, '\\d+', 'X'), 'Null input should return null');
		Assert.areEqual('', UTIL_String.maskWithRegex('', '\\d+', 'X'), 'Empty input should return empty');
	}

	/**
	 * @description Tests that maskExactMatch replaces occurrences literally.
	 *
	 * @see UTIL_String.maskExactMatch
	 */
	@IsTest
	private static void maskExactMatchShouldReplaceOccurrences()
	{
		String result = UTIL_String.maskExactMatch('Card: 4111-1111-1111-1111', '4111-1111-1111-1111', '[CARD_REDACTED]');

		Assert.areEqual('Card: [CARD_REDACTED]', result, 'Literal substring should be replaced');
	}

	/**
	 * @description Tests that maskExactMatch treats replacement as literal (no regex syntax).
	 *
	 * @see UTIL_String.maskExactMatch
	 */
	@IsTest
	private static void maskExactMatchShouldTreatReplacementAsLiteral()
	{
		String result = UTIL_String.maskExactMatch('find me', 'find me', '$1 \\backslash');

		Assert.areEqual('$1 \\backslash', result, 'Dollar and backslash in replacement should pass through unchanged');
	}

	/**
	 * @description Tests that maskExactMatch handles empty input and empty literal.
	 *
	 * @see UTIL_String.maskExactMatch
	 */
	@IsTest
	private static void maskExactMatchShouldHandleEmptyInputs()
	{
		Assert.isNull(UTIL_String.maskExactMatch(null, 'literal', 'X'), 'Null input should return null');
		Assert.areEqual('', UTIL_String.maskExactMatch('', 'literal', 'X'), 'Empty input should return empty');
		Assert.areEqual('text', UTIL_String.maskExactMatch('text', '', 'X'), 'Empty literal should return input unchanged');
	}

	/**
	 * @description Tests that maskJsonKeys redacts values under matching top-level keys.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void maskJsonKeysShouldRedactMatchingTopLevelValues()
	{
		String input = '{"user":"alice","password":"hunter2","token":"abc123"}';

		String result = UTIL_String.maskJsonKeys(input, '^(password|token)$', '***');

		Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(result);
		Assert.areEqual('alice', parsed.get('user'), 'Non-matching key should remain');
		Assert.areEqual('***', parsed.get('password'), 'password value should be redacted');
		Assert.areEqual('***', parsed.get('token'), 'token value should be redacted');
	}

	/**
	 * @description Tests that maskJsonKeys is case-insensitive by default.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void maskJsonKeysShouldBeCaseInsensitiveByDefault()
	{
		String result = UTIL_String.maskJsonKeys('{"Password":"hunter2"}', '^password$', '***');

		Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(result);
		Assert.areEqual('***', parsed.get('Password'), 'Default should match case-insensitively');
	}

	/**
	 * @description Tests that maskJsonKeys honours caseSensitive = true.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void maskJsonKeysShouldHonourCaseSensitiveFlag()
	{
		String result = UTIL_String.maskJsonKeys('{"Password":"hunter2"}', '^password$', '***', true);

		Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(result);
		Assert.areEqual('hunter2', parsed.get('Password'), 'Case-sensitive match should NOT fire on differing-case key');
	}

	/**
	 * @description Tests that maskJsonKeys walks nested objects.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void maskJsonKeysShouldWalkNestedObjects()
	{
		String input = '{"user":{"name":"alice","secret":"x"},"outer":"y"}';

		String result = UTIL_String.maskJsonKeys(input, '^secret$', '***');

		Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(result);
		Map<String, Object> user = (Map<String, Object>)parsed.get('user');
		Assert.areEqual('***', user.get('secret'), 'Nested secret should be redacted');
		Assert.areEqual('alice', user.get('name'), 'Nested name should remain');
		Assert.areEqual('y', parsed.get('outer'), 'Top-level outer should remain');
	}

	/**
	 * @description Tests that maskJsonKeys walks into arrays of objects.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void maskJsonKeysShouldWalkArrays()
	{
		String input = '{"items":[{"password":"a"},{"password":"b"}]}';

		String result = UTIL_String.maskJsonKeys(input, '^password$', '***');

		Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(result);
		List<Object> items = (List<Object>)parsed.get('items');
		Assert.areEqual(2, items.size(), 'Array size should be preserved');
		Assert.areEqual('***', ((Map<String, Object>)items.get(0)).get('password'), 'First array element should be redacted');
		Assert.areEqual('***', ((Map<String, Object>)items.get(1)).get('password'), 'Second array element should be redacted');
	}

	/**
	 * @description Tests that maskJsonKeys falls back to regex replacement when JSON parse fails.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void maskJsonKeysShouldFallBackToRegexOnParseFailure()
	{
		String malformedJson = '{"password": "hunter2", bad json';

		String result = UTIL_String.maskJsonKeys(malformedJson, '^password$', '***');

		Assert.isTrue(result.contains('"password": "***"'), 'Fallback regex should redact the password value even in malformed JSON');
		Assert.isFalse(result.contains('hunter2'), 'Original secret should not remain in the output');
	}

	/**
	 * @description Tests that maskJsonKeys handles empty input.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void maskJsonKeysShouldHandleEmptyInput()
	{
		Assert.isNull(UTIL_String.maskJsonKeys(null, '^password$', '***'), 'Null input should return null');
		Assert.areEqual('', UTIL_String.maskJsonKeys('', '^password$', '***'), 'Empty input should return empty');
	}

	/**
	 * @description Tests that maskJsonKeys preserves non-matching values unchanged.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void maskJsonKeysShouldLeaveNonMatchingKeysUntouched()
	{
		String input = '{"id":123,"name":"alice","active":true}';

		String result = UTIL_String.maskJsonKeys(input, '^password$', '***');

		Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(result);
		Assert.areEqual(123, parsed.get('id'), 'Numeric value should be preserved');
		Assert.areEqual('alice', parsed.get('name'), 'Name should be preserved');
		Assert.areEqual(true, parsed.get('active'), 'Boolean value should be preserved');
	}

	/**
	 * @description Tests that the regex fallback escapes `$` in the replacement so literal
	 * dollar signs do not trigger capture-group handling.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void maskJsonKeysShouldEscapeDollarSignInReplacementFallback()
	{
		String malformedJson = '{"password": "hunter2", broken';

		String result = UTIL_String.maskJsonKeys(malformedJson, '^password$', '$100');

		Assert.isTrue(result.contains('"password": "$100"'), 'Literal $100 should appear in the output');
	}

	/**
	 * @description Tests that maskJsonKeys handles a null replacement via the fallback path.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void maskJsonKeysShouldHandleNullReplacementInFallback()
	{
		String malformedJson = '{"password": "hunter2", broken';

		String result = UTIL_String.maskJsonKeys(malformedJson, '^password$', null);

		Assert.isTrue(result.contains('"password": ""'), 'Null replacement should substitute empty string');
	}

	/**
	 * @description Tests that maskJsonKeys falls back to regex when the input exceeds the
	 * 2 MB size threshold (guarding heap on very large payloads).
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void maskJsonKeysShouldFallBackToRegexWhenInputExceedsSizeThreshold()
	{
		UTIL_String.jsonWalkSizeThreshold = 1;

		String result = UTIL_String.maskJsonKeys('{"password":"hunter2"}', '^password$', '***');

		Assert.isTrue(result.contains('"password":"***"'), 'Oversized payload should still redact via regex fallback');
		Assert.isFalse(result.contains('hunter2'), 'Original secret must not remain');
	}

	/**
	 * @description Tests that the walk stops descending once it exceeds JSON_WALK_MAX_DEPTH so
	 * pathological payloads cannot exhaust stack space.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void maskJsonKeysShouldStopDescendingAtRecursionCap()
	{
		String nested = '"leaf"';

		for(Integer depth = 0; depth < 55; depth++)
		{
			nested = '{"n":' + nested + '}';
		}

		String wrapped = '{"password":"hunter2","deep":' + nested + '}';

		String result = UTIL_String.maskJsonKeys(wrapped, '^password$', '***');

		Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(result);
		Assert.areEqual('***', parsed.get('password'), 'Top-level password should still be redacted even when a neighbouring branch exceeds depth');
	}

	@IsTest
	private static void shouldReturnInputUnchangedWhenJsonPayloadIsLiteralNull()
	{
		String result = UTIL_String.maskJsonKeys('null', '^password$', '***');
		Assert.areEqual('null', result, 'A JSON payload of literal null should round-trip unchanged through the tree walker');
	}

	/**
	 * @description Tests that the counter-returning variant of the JsonKey tree walker raises
	 * its mutation flag and increments its replacement count when a top-level key matches.
	 *
	 * @see UTIL_String.applyJsonKeyRuleToTreeWithCount
	 */
	@IsTest
	private static void shouldReportMutationOnJsonKeyWalkerWhenRuleMatches()
	{
		Object tree = JSON.deserializeUntyped('{"user":"alice","password":"hunter2"}');

		UTIL_String.JsonKeyMaskResult result = UTIL_String.applyJsonKeyRuleToTreeWithCount(tree, '^password$', '***', false);

		Assert.isTrue(result.mutated, 'Mutation flag must fire when a key matches');
		Assert.areEqual(1, result.replacementCount, 'One replacement must be counted');
		Map<String, Object> asMap = (Map<String, Object>)result.tree;
		Assert.areEqual('***', asMap.get('password'), 'Password value must be replaced in the returned tree');
	}

	/**
	 * @description Tests that the counter-returning variant of the JsonKey tree walker keeps
	 * its mutation flag clear and its replacement count at zero when no key matches — the
	 * cheap-path signal that lets the batching caller skip a redundant re-serialize.
	 *
	 * @see UTIL_String.applyJsonKeyRuleToTreeWithCount
	 */
	@IsTest
	private static void shouldReportZeroMutationsWhenNoKeyMatches()
	{
		Object tree = JSON.deserializeUntyped('{"user":"alice","role":"admin"}');

		UTIL_String.JsonKeyMaskResult result = UTIL_String.applyJsonKeyRuleToTreeWithCount(tree, '^password$', '***', false);

		Assert.isFalse(result.mutated, 'Mutation flag must stay false when no key matches');
		Assert.areEqual(0, result.replacementCount, 'Replacement count must be zero when nothing matches');
	}

	/**
	 * @description Tests that the counter-returning variant of the JsonKey tree walker counts
	 * every replacement, not just the first, when the same key appears at several nesting
	 * levels — preventing a hidden undercount in batched rule telemetry.
	 *
	 * @see UTIL_String.applyJsonKeyRuleToTreeWithCount
	 */
	@IsTest
	private static void shouldCountEachReplacementAcrossNestedKeys()
	{
		Object tree = JSON.deserializeUntyped('{"outer":{"secret":"a","inner":{"secret":"b"}}}');

		UTIL_String.JsonKeyMaskResult result = UTIL_String.applyJsonKeyRuleToTreeWithCount(tree, '^secret$', '***', false);

		Assert.isTrue(result.mutated, 'Mutation flag must fire');
		Assert.areEqual(2, result.replacementCount, 'Both nested secret keys must be counted');
	}

	@IsTest
	private static void shouldAcceptValidAmex()
	{
		Assert.isTrue(UTIL_String.isValidCardNumber(VALID_AMEX_15), 'Valid 15-digit Amex must pass card-number validation');
	}

	@IsTest
	private static void shouldAcceptValidVisa()
	{
		Assert.isTrue(UTIL_String.isValidCardNumber(VALID_VISA_16), 'Valid 16-digit Visa must pass card-number validation');
	}

	@IsTest
	private static void shouldAcceptValidMastercard()
	{
		Assert.isTrue(UTIL_String.isValidCardNumber(VALID_MC_16), 'Valid 16-digit Mastercard must pass card-number validation');
	}

	@IsTest
	private static void shouldAcceptValidUnionPay()
	{
		Assert.isTrue(UTIL_String.isValidCardNumber(VALID_UNION_PAY_19), 'Valid 19-digit UnionPay must pass card-number validation');
	}

	@IsTest
	private static void shouldRejectTransactionIdShapedAs16Digits()
	{
		Assert.isFalse(UTIL_String.isValidCardNumber(INVALID_TRANSACTION_ID_16), '16-digit transaction ID must not card-number-validate');
	}

	@IsTest
	private static void shouldRejectNanosecondTimestamp()
	{
		Assert.isFalse(UTIL_String.isValidCardNumber(TIMESTAMP_NANO_19), '19-digit nanosecond timestamp must not card-number-validate');
	}

	@IsTest
	private static void shouldStripSpacesAndHyphensBeforeValidating()
	{
		Assert.isTrue(UTIL_String.isValidCardNumber('4111-1111-1111-1111'), 'Hyphens must be stripped before card-number validation');
		Assert.isTrue(UTIL_String.isValidCardNumber('4111 1111 1111 1111'), 'Spaces must be stripped before card-number validation');
	}

	@IsTest
	private static void shouldRejectTooShortInput()
	{
		Assert.isFalse(UTIL_String.isValidCardNumber('1234567890'), '10-digit input must be rejected (below 13-digit card floor)');
	}

	@IsTest
	private static void shouldRejectTooLongInput()
	{
		Assert.isFalse(UTIL_String.isValidCardNumber('12345678901234567890'), '20-digit input must be rejected (above 19-digit card ceiling)');
	}

	@IsTest
	private static void shouldRejectNullAndEmpty()
	{
		Assert.isFalse(UTIL_String.isValidCardNumber(null), 'Null input must return false');
		Assert.isFalse(UTIL_String.isValidCardNumber(''), 'Empty input must return false');
		Assert.isFalse(UTIL_String.isValidCardNumber('   '), 'Whitespace-only input must return false');
	}

	@IsTest
	private static void shouldRejectLetterContaminatedInput()
	{
		Assert.isFalse(UTIL_String.isValidCardNumber('4111A1111B1111C1111'), 'Letters must cause rejection even if digits would otherwise Luhn-validate');
	}

	@IsTest
	private static void shouldMaskLuhnValidCardInRegexAndLuhnPipeline()
	{
		String input = 'Charge receipt: 4111 1111 1111 1111 accepted';
		String regex = '\\b(?:\\d[ -]*?){15,19}\\b';
		String output = UTIL_String.maskWithLuhnValidatedRegex(input, regex, '[CARD_REDACTED]', false);
		Assert.areEqual('Charge receipt: [CARD_REDACTED] accepted', output, 'Luhn-valid match must be redacted');
	}

	@IsTest
	private static void shouldLeaveLuhnInvalidDigitRunAloneInPipeline()
	{
		String input = 'parentTransactionId: TID:1234567890123456';
		String regex = '\\b(?:\\d[ -]*?){15,19}\\b';
		String output = UTIL_String.maskWithLuhnValidatedRegex(input, regex, '[CARD_REDACTED]', false);
		Assert.areEqual('parentTransactionId: TID:1234567890123456', output, 'Luhn-invalid 16-digit transaction ID must pass through unchanged');
	}

	@IsTest
	private static void shouldRedactOnlyLuhnValidMatchesWhenBothPresent()
	{
		String input = 'card 4111111111111111, trace 1234567890123456, done';
		String regex = '\\b(?:\\d[ -]*?){15,19}\\b';
		String output = UTIL_String.maskWithLuhnValidatedRegex(input, regex, 'X', false);
		Assert.areEqual('card X, trace 1234567890123456, done', output, 'Only the Luhn-valid card must be redacted; the trace ID survives');
	}

	@IsTest
	private static void shouldReturnInputUnchangedWhenNullOrEmptyInLuhnPipeline()
	{
		String regex = '\\b(?:\\d[ -]*?){15,19}\\b';
		Assert.areEqual(null, UTIL_String.maskWithLuhnValidatedRegex(null, regex, 'X', false), 'Null passes through unchanged');
		Assert.areEqual('', UTIL_String.maskWithLuhnValidatedRegex('', regex, 'X', false), 'Empty passes through unchanged');
	}
}