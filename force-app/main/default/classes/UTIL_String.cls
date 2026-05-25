// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Various string manipulation utilities
 *
 * @see UTIL_String_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * String shortened = UTIL_String.abbreviate('Now is the time for all good men', 10);
 * String joined = UTIL_String.join(new List<Object>{'a', 'b', 'c'}, ',');
 * List<String> parts = UTIL_String.split('one,two,three', ',');
 * String replaced = UTIL_String.replace('Hello World', 'World', 'Apex');
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength,PMD.NcssTypeCount,PMD.AvoidGlobalModifier')
global inherited sharing class UTIL_String
{
	/**
	 * @description Ampersand character constant '&'
	 */
	public static final String AMPERSAND = '&';

	/**
	 * @description Colon character constant ':'
	 */
	public static final String COLON = ':';

	/**
	 * @description Comma character constant ','
	 */
	public static final String COMMA = ',';

	/**
	 * @description Period/dot character constant '.'
	 */
	public static final String DOT = '.';

	/**
	 * @description Empty string constant ''
	 */
	public static final String EMPTY = '';

	/**
	 * @description Empty JSON response constant '{ }'
	 */
	public static final String EMPTY_JSON_RESPONSE = '{ }';

	/**
	 * @description Equals sign character constant '='
	 */
	public static final String EQUALS = '=';

	/**
	 * @description Line feed character constant '\n'
	 */
	public static final String LF = '\n';

	/**
	 * @description Question mark character constant '?'
	 */
	public static final String QUESTION_MARK = '?';

	/**
	 * @description Semicolon character constant ';'
	 */
	public static final String SEMI_COLON = ';';

	/**
	 * @description Space character constant ' '
	 */
	public static final String SPACE = ' ';

	/**
	 * @description Underscore character constant '_'
	 */
	public static final String UNDERSCORE = '_';

	/**
	 * @description Double underscore character constant '__'
	 */
	public static final String DOUBLE_UNDERSCORE = UNDERSCORE + UNDERSCORE;
	/**
	 * @description Carriage return String followed by a line feed String.
	 */
	public static final String CRLF = '\r' + LF;

	/**
	 * @description Ellipsis string used for abbreviation ('...').
	 */
	private static final String ELLIPSIS = '...';

	/**
	 * @description Length of the ellipsis string.
	 */
	private static final Integer ELLIPSIS_LENGTH = ELLIPSIS.length();

	/**
	 * @description Minimum abbreviation width (ellipsis length + 1).
	 */
	private static final Integer MIN_ABBREVIATION_WIDTH = ELLIPSIS_LENGTH + 1;

	/**
	 * @description Default percentage of a string to mask.
	 */
	private static final Double DEFAULT_MASK_PERCENTAGE = 66.66;

	/**
	 * @description Default character used for masking.
	 */
	private static final String DEFAULT_MASK_CHARACTER = 'x';

	/**
	 * @description Minimum string length required for masking.
	 */
	private static final Integer MIN_MASK_LENGTH = 3;

	/**
	 * @description Maximum input size (characters) before JSON deserialization is skipped in
	 * favour of the regex fallback. Prevents the untyped walk from exhausting Apex heap on
	 * very large payloads. @TestVisible so tests can exercise the branch without generating
	 * multi-megabyte inputs.
	 */
	@TestVisible
	private static Integer jsonWalkSizeThreshold = 2000000;

	/**
	 * @description Maximum recursion depth while walking a deserialized JSON tree.
	 */
	private static final Integer JSON_WALK_MAX_DEPTH = 50;

	/**
	 * @description <p>Abbreviates a String using ellipses. This will turn
	 * "Now is the time for all good men" into "Now is the time for..."</p>
	 * <p/>
	 * <p>Specifically:</p>
	 * <ul>
	 *   <li>If the number of characters in {@code input} is less than or equal to
	 *       {@code maxWidth}, return {@code input}.</li>
	 *   <li>Else abbreviate it to {@code (substring(input, 0, max-3) + "...")}.</li>
	 *   <li>If {@code maxWidth} is less than {@code 4}, throw an
	 *       {@code IllegalArgumentException}.</li>
	 *   <li>In no case will it return a String of length greater than
	 *       {@code maxWidth}.</li>
	 * </ul>
	 * <p/>
	 *
	 * @param input the String to check, may be null
	 * @param maxWidth maximum length of result String, must be at least 4
	 *
	 * @return abbreviated String, {@code null} if null String input
	 *
	 * @throws IllegalArgumentException if the width is too small
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_String.abbreviate(null, 4);        // returns null
	 * UTIL_String.abbreviate('', 4);          // returns ''
	 * UTIL_String.abbreviate('abcdefg', 6);   // returns 'abc...'
	 * UTIL_String.abbreviate('abcdefg', 7);   // returns 'abcdefg'
	 * UTIL_String.abbreviate('abcdefg', 8);   // returns 'abcdefg'
	 * UTIL_String.abbreviate('abcdefg', 4);   // returns 'a...'
	 * UTIL_String.abbreviate('abcdefg', 3);   // throws IllegalArgumentException
	 * ```
	 */
	global static String abbreviate(String input, Integer maxWidth)
	{
		return abbreviate(input, 0, maxWidth);
	}

	/**
	 * @description <p>Abbreviates a String using ellipses. This will turn
	 * "Now is the time for all good men" into "...is the time for..."</p>
	 *
	 * Works like String.abbreviate, but allows you to specify
	 * a "left edge" offset.  Note that this left edge is not necessarily going to
	 * be the leftmost character in the result, or the first character following the
	 * ellipses, but it will appear somewhere in the result.
	 *
	 * In no case will it return a String of length greater than maxWidth
	 *
	 * @param input the String to check, may be null
	 * @param offset left edge of source String
	 * @param maxWidth maximum length of result String, must be at least 4
	 *
	 * @return abbreviated String, {@code null} if null String input
	 *
	 * @throws IllegalArgumentException if the width is too small
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_String.abbreviate(null, 0, 4);                 // returns null
	 * UTIL_String.abbreviate('', 0, 4);                   // returns ''
	 * UTIL_String.abbreviate('abcdefghijklmno', -1, 10);  // returns 'abcdefg...'
	 * UTIL_String.abbreviate('abcdefghijklmno', 0, 10);   // returns 'abcdefg...'
	 * UTIL_String.abbreviate('abcdefghijklmno', 1, 10);   // returns 'abcdefg...'
	 * UTIL_String.abbreviate('abcdefghijklmno', 4, 10);   // returns 'abcdefg...'
	 * UTIL_String.abbreviate('abcdefghijklmno', 5, 10);   // returns '...fghi...'
	 * UTIL_String.abbreviate('abcdefghijklmno', 6, 10);   // returns '...ghij...'
	 * UTIL_String.abbreviate('abcdefghijklmno', 8, 10);   // returns '...ijklmno'
	 * UTIL_String.abbreviate('abcdefghijklmno', 10, 10);  // returns '...ijklmno'
	 * UTIL_String.abbreviate('abcdefghijklmno', 12, 10);  // returns '...ijklmno'
	 * UTIL_String.abbreviate('abcdefghij', 0, 3);         // throws IllegalArgumentException
	 * UTIL_String.abbreviate('abcdefghij', 5, 6);         // throws IllegalArgumentException
	 * ```
	 */
	global static String abbreviate(String input, Integer offset, Integer maxWidth)
	{
		if(input == null)
		{
			return input;
		}
		if(maxWidth == null || maxWidth < MIN_ABBREVIATION_WIDTH)
		{
			throw new IllegalArgumentException('Minimum abbreviation width is 4');
		}
		if(input.length() <= maxWidth)
		{
			return input;
		}
		if(offset > input.length())
		{
			offset = input.length();
		}
		if((input.length() - offset) < (maxWidth - ELLIPSIS_LENGTH))
		{
			offset = input.length() - (maxWidth - ELLIPSIS_LENGTH);
		}
		if(offset <= MIN_ABBREVIATION_WIDTH)
		{
			return input.substring(0, maxWidth - ELLIPSIS_LENGTH) + ELLIPSIS;
		}
		if(maxWidth < (MIN_ABBREVIATION_WIDTH + ELLIPSIS_LENGTH))
		{
			throw new IllegalArgumentException('Minimum abbreviation width with offset is 7');
		}
		if((offset + (maxWidth - ELLIPSIS_LENGTH)) < input.length())
		{
			return ELLIPSIS + abbreviate(input.substring(offset), maxWidth - ELLIPSIS_LENGTH);
		}
		return ELLIPSIS + input.substring(input.length() - (maxWidth - ELLIPSIS_LENGTH));
	}

	/**
	 * @description Abbreviates a String to fit within the maximum length of the specified SObjectField.
	 * Automatically derives the field length from the field's describe metadata.
	 *
	 * @param input the String to abbreviate, may be null
	 * @param field the SObjectField whose length determines the maximum width
	 *
	 * @return abbreviated String fitting within the field length, {@code null} if null String input
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String shortened = UTIL_String.abbreviateToField(longMessage, LogEntry__c.Message__c);
	 * ```
	 */
	global static String abbreviate(String input, SObjectField field)
	{
		return abbreviate(input, UTIL_SObjectDescribe.getCachedFieldDescribe(field)?.length);
	}

	/**
	 * @description Capitalizes each word in a string by splitting on the given delimiter.
	 *
	 * @param input the input string to capitalize
	 * @param delimiter The delimiter to use that separates words
	 *
	 * @return String with each word capitalized
	 *
	 * @example
	 * ```apex
	 * String result = UTIL_String.capitalizeWords('value', ',');
	 * ```
	 */
	public static String capitalizeWords(String input, String delimiter)
	{
		if(String.isBlank(input))
		{
			return input;
		}

		List<String> words = split(input, delimiter);
		List<String> capitalizedWords = new List<String>();

		for(String word : words)
		{
			capitalizedWords.add(word?.toLowerCase()?.capitalize());
		}

		return String.join(capitalizedWords, delimiter);
	}

	/**
	 * @description retrieve character at index of string starts at 0
	 *
	 * @param input the String to retrieve a character from
	 * @param index the zero-based position
	 *
	 * @return string character
	 *
	 * @example
	 * ```apex
	 * String result = UTIL_String.charAt('value', 10);
	 * ```
	 */
	public static String charAt(String input, Integer index)
	{
		if(String.isEmpty(input))
		{
			return input;
		}

		if(index < 0 || index >= input.length())
		{
			return null;
		}

		return input.substring(index, index + 1);
	}

	/**
	 * @description Null-safe indexOf. Returns -1 if either argument is null.
	 *
	 * @param input the String to search within
	 * @param searchString the String to find
	 *
	 * @return the first index, or -1 if not found or null input
	 */
	private static Integer indexOf(String input, String searchString)
	{
		return input == null || searchString == null ? -1 : input.indexOf(searchString);
	}

	/**
	 * @description Null-safe indexOf with start position. Returns -1 if either argument is null.
	 *
	 * @param input the String to search within
	 * @param searchString the String to find
	 * @param startPosition the position to start searching from
	 *
	 * @return the first index at or after startPosition, or -1 if not found or null input
	 */
	private static Integer indexOf(String input, String searchString, Integer startPosition)
	{
		return input == null || searchString == null ? -1 : input.indexOf(searchString, startPosition);
	}

	/**
	 * @description <p>Joins the elements of the provided array into a single String
	 * containing the provided list of elements.</p>
	 * <p/>
	 * <p>No delimiter is added before or after the list.
	 * Null objects or empty strings within the array are represented by
	 * empty strings.</p>
	 * <p/>
	 *
	 * @param objectArray the array of values to join together, may be null
	 * @param separator the separator character to use
	 *
	 * @return the joined String, {@code null} if null array input
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_String.join(null, ';');                              // returns null
	 * UTIL_String.join(new List<Object>(), ';');                // returns ''
	 * UTIL_String.join(new List<Object>{null}, ';');            // returns ''
	 * UTIL_String.join(new List<Object>{'a', 'b', 'c'}, ';');   // returns 'a;b;c'
	 * UTIL_String.join(new List<Object>{'a', 'b', 'c'}, null);  // returns 'abc'
	 * UTIL_String.join(new List<Object>{null, '', 'a'}, ';');   // returns ';a'
	 * ```
	 */
	global static String join(List<Object> objectArray, String separator)
	{
		if(objectArray == null)
		{
			return null;
		}
		if(separator == null)
		{
			separator = EMPTY;
		}

		String result = EMPTY;
		Boolean isFirst = true;
		for(Integer i = 0; i < objectArray.size(); i++)
		{
			if(objectArray[i] != null)
			{
				if(isFirst)
				{
					isFirst = false;
				}
				else
				{
					result += separator;
				}
				result += objectArray[i];
			}
		}
		return result;
	}

	/**
	 * @description <p>Joins the elements of the provided {@code Iterator} into
	 * a single String containing the provided elements.</p>
	 * <p/>
	 * <p>No delimiter is added before or after the list.
	 * A {@code null} separator is the same as an empty String ("").</p>
	 * <p/>
	 *
	 * @param stringSet the {@code Iterator} of values to join together, may be null
	 * @param separator the separator character to use, null treated as ""
	 *
	 * @return the joined String, {@code null} if null iterator input
	 *
	 * @see String.join
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = UTIL_String.join(new Set<String>{'a', 'b'}, ',');
	 * ```
	 */
	global static String join(Set<String> stringSet, String separator)
	{
		return stringSet == null ? null : join(new List<String>(stringSet), separator);
	}

	/**
	 * @description <p>Gets the leftmost {@code length} characters of a String.</p>
	 * <p/>
	 * <p>If {@code length} characters are not available, or the
	 * String is {@code null}, the String will be returned without
	 * an exception. An empty String is returned if length is negative.</p>
	 * <p/>
	 *
	 * @param input the String to get the leftmost characters from, may be null
	 * @param length the length of the required String
	 *
	 * @return the leftmost characters, {@code null} if null String input
	 *
	 * @example
	 * ```apex
	 * UTIL_String.left(null, 2);    // returns null
	 * UTIL_String.left('abc', -1);  // returns ''
	 * UTIL_String.left('', 2);      // returns ''
	 * UTIL_String.left('abc', 0);   // returns ''
	 * UTIL_String.left('abc', 2);   // returns 'ab'
	 * UTIL_String.left('abc', 4);   // returns 'abc'
	 * ```
	 */
	public static String left(String input, Integer length)
	{
		if(input == null)
		{
			return null;
		}
		if(length < 0)
		{
			return EMPTY;
		}
		if(input.length() <= length)
		{
			return input;
		}
		return input.substring(0, length);
	}

	/**
	 * @description Removes all occurrences of a substring from within the source string.
	 *
	 * @param input the source String to search, may be null
	 * @param remove the String to search for and remove, may be null
	 *
	 * @return the substring with the string removed if found, null if null String input
	 *
	 * @see String.remove
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_String.remove(null, 'ue');       // returns null
	 * UTIL_String.remove('', 'ue');         // returns ''
	 * UTIL_String.remove('queued', null);   // returns 'queued'
	 * UTIL_String.remove('queued', '');     // returns 'queued'
	 * UTIL_String.remove('queued', 'ue');   // returns 'qd'
	 * UTIL_String.remove('queued', 'zz');   // returns 'queued'
	 * ```
	 */
	global static String remove(String input, String remove)
	{
		return input == null || remove == null ? input : input.remove(remove);
	}

	/**
	 * @description <p>Removes a substring only if it is at the beginning of a source string,
	 * otherwise returns the source string.</p>
	 * <p/>
	 * <p>A {@code null} source string will return {@code null}.
	 * An empty ("") source string will return the empty string.
	 * A {@code null} search string will return the source string.</p>
	 * <p/>
	 *
	 * @param input the source String to search, may be null
	 * @param remove the String to search for and remove, may be null
	 *
	 * @return the substring with the string removed if found,
	 *  {@code null} if null String input
	 *
	 * @example
	 * ```apex
	 * UTIL_String.removeStart(null, 'www.');              // returns null
	 * UTIL_String.removeStart('', 'www.');                // returns ''
	 * UTIL_String.removeStart('www.domain.com', null);    // returns 'www.domain.com'
	 * UTIL_String.removeStart('www.domain.com', 'www.');  // returns 'domain.com'
	 * UTIL_String.removeStart('domain.com', 'www.');      // returns 'domain.com'
	 * UTIL_String.removeStart('www.domain.com', 'domain');// returns 'www.domain.com'
	 * UTIL_String.removeStart('abc', '');                 // returns 'abc'
	 * ```
	 */
	public static String removeStart(String input, String remove)
	{
		if(String.isEmpty(input) || String.isEmpty(remove))
		{
			return input;
		}
		if(input.startsWith(remove))
		{
			if(remove.length() >= input.length())
			{
				return EMPTY;
			}
			else
			{
				return input.substring(remove.length());
			}
		}
		return input;
	}

	/**
	 * @description <p>Replaces all occurrences of a String within another String.</p>
	 * <p/>
	 * <p>A {@code null} reference passed to this method is a no-op.</p>
	 * <p/>
	 *
	 * @param text text to search and replace in, may be null
	 * @param searchString the String to search for, may be null
	 * @param replacement the String to replace it with, may be null
	 *
	 * @return the text with any replacements processed,
	 *  {@code null} if null String input
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_String.replace(null, 'a', 'z');    // returns null
	 * UTIL_String.replace('', 'a', 'z');      // returns ''
	 * UTIL_String.replace('any', null, 'z');  // returns 'any'
	 * UTIL_String.replace('any', 'a', null);  // returns 'any'
	 * UTIL_String.replace('any', '', 'z');    // returns 'any'
	 * UTIL_String.replace('aba', 'a', null);  // returns 'aba'
	 * UTIL_String.replace('aba', 'a', '');    // returns 'b'
	 * UTIL_String.replace('aba', 'a', 'z');   // returns 'zbz'
	 * ```
	 */
	global static String replace(String text, String searchString, String replacement)
	{
		if(String.isEmpty(text) || String.isEmpty(searchString) || replacement == null)
		{
			return text;
		}
		Integer startIndex = 0;
		Integer endIndex = indexOf(text, searchString, startIndex);
		if(endIndex == -1)
		{
			return text;
		}
		Integer replacementLength = searchString.length();
		String result = EMPTY;
		while(endIndex != -1)
		{
			result += substring(text, startIndex, endIndex) + replacement;
			startIndex = endIndex + replacementLength;
			endIndex = indexOf(text, searchString, startIndex);
		}
		result += substring(text, startIndex);
		return result;
	}

	/**
	 * @description Replaces each search token in the text with the corresponding replacement token,
	 * repeating the process until no further replacements occur.
	 *
	 * @param text The text to perform replacements on.
	 * @param searchTokens The tokens to search for.
	 * @param replaceTokens The replacement values corresponding to each search token.
	 * @param repeat If true, repeats the replacement pass until the text stabilises.
	 *
	 * @return The text with all replacements applied, or the original text if inputs are null/empty.
	 *
	 * @example
	 * ```apex
	 * List<String> search = new List<String>{'{{name}}', '{{org}}'};
	 * List<String> replace = new List<String>{'Acme', 'Corp'};
	 * String result = UTIL_String.replaceEachRepeatedly('Hello {{name}} at {{org}}', search, replace, false);
	 * // returns 'Hello Acme at Corp'
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	public static String replaceEachRepeatedly(String text, List<String> searchTokens, List<String> replaceTokens, Boolean repeat)
	{
		if(text == null || searchTokens == null || replaceTokens == null || searchTokens.isEmpty())
		{
			return text;
		}

		Integer tokenCount = Math.min(searchTokens.size(), replaceTokens.size());
		Boolean changed = true;

		while(changed)
		{
			changed = false;

			for(Integer i = 0; i < tokenCount; i++)
			{
				String before = text;
				text = text.replace(searchTokens[i], replaceTokens[i]);

				if(text != before)
				{
					changed = true;
				}
			}

			if(!repeat)
			{
				break;
			}
		}

		return text;
	}

	/**
	 * @description <p>Splits the provided text into an array, using whitespace as the
	 * separator.
	 * Whitespace is defined by {@link UTIL_Character.isWhitespace}.</p>
	 * <p/>
	 * <p>The separator is not included in the returned String array.
	 * Adjacent separators are treated as one separator.
	 * For more control over the split use the StrTokenizer class.</p>
	 * <p/>
	 * <p>A {@code null} input String returns {@code null}.</p>
	 * <p/>
	 *
	 * @param input the String to parse, may be null
	 *
	 * @return an array of parsed Strings, {@code null} if null String input
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_String.split(null);          // returns null
	 * UTIL_String.split('');            // returns new List<String>()
	 * UTIL_String.split('abc def');     // returns new List<String>{'abc', 'def'}
	 * UTIL_String.split('abc  def');    // returns new List<String>{'abc', 'def'}
	 * UTIL_String.split(' abc ');       // returns new List<String>{'abc'}
	 * ```
	 */
	global static List<String> split(String input)
	{
		return split(input, null, -1);
	}

	/**
	 * @description <p>Splits the provided text into an array, separators specified.
	 * This is an alternative to using StringTokenizer.</p>
	 * <p/>
	 * <p>The separator is not included in the returned String array.
	 * Adjacent separators are treated as one separator.
	 * For more control over the split use the StrTokenizer class.</p>
	 * <p/>
	 * <p>A {@code null} input String returns {@code null}.
	 * A {@code null} separatorChars splits on whitespace.</p>
	 * <p/>
	 *
	 * @param input the String to parse, may be null
	 * @param separatorChars the characters used as the delimiters,
	 *  {@code null} splits on whitespace
	 *
	 * @return an array of parsed Strings, {@code null} if null String input
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_String.split(null, ' ');           // returns null
	 * UTIL_String.split('', ' ');             // returns new List<String>()
	 * UTIL_String.split('abc def', null);     // returns new List<String>{'abc', 'def'}
	 * UTIL_String.split('abc def', ' ');      // returns new List<String>{'abc', 'def'}
	 * UTIL_String.split('abc  def', ' ');     // returns new List<String>{'abc', 'def'}
	 * UTIL_String.split('ab:cd:ef', ':');     // returns new List<String>{'ab', 'cd', 'ef'}
	 * ```
	 */
	global static List<String> split(String input, String separatorChars)
	{
		return split(input, separatorChars, -1);
	}

	/**
	 * @description <p>Splits the provided text into an array with a maximum length,
	 * separators specified.</p>
	 * <p/>
	 * <p>The separator is not included in the returned String array.
	 * Adjacent separators are treated as one separator.</p>
	 * <p/>
	 * <p>A {@code null} input String returns {@code null}.
	 * A {@code null} separatorChars splits on whitespace.</p>
	 * <p/>
	 * <p>If more than {@code max} delimited substrings are found, the last
	 * returned string includes all characters after the first {@code max - 1}
	 * returned strings (including separator characters).</p>
	 * <p/>
	 *
	 * @param input the String to parse, may be null
	 * @param separatorChars the characters used as the delimiters,
	 *  {@code null} splits on whitespace
	 * @param max the maximum number of elements to include in the
	 *  array. A zero or negative value implies no limit
	 *
	 * @return an array of parsed Strings, {@code null} if null String input
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_String.split(null, ':', 0);           // returns null
	 * UTIL_String.split('', ':', 0);             // returns new List<String>()
	 * UTIL_String.split('ab cd ef', null, 0);    // returns new List<String>{'ab', 'cd', 'ef'}
	 * UTIL_String.split('ab   cd ef', null, 0);  // returns new List<String>{'ab', 'cd', 'ef'}
	 * UTIL_String.split('ab:cd:ef', ':', 0);     // returns new List<String>{'ab', 'cd', 'ef'}
	 * UTIL_String.split('ab:cd:ef', ':', 2);     // returns new List<String>{'ab', 'cd:ef'}
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidDeeplyNestedIfStmts')
	global static List<String> split(String input, String separatorChars, Integer max)
	{
		if(input == null)
		{
			return null;
		}
		Integer length = input.length();
		if(length == 0)
		{
			return new List<String> {};
		}

		List<String> parts = new List<String>();
		Integer sizePlus1 = 1;
		Integer i = 0;
		Integer start = 0;
		Boolean match = false;
		String singleSeparator = separatorChars?.length() == 1 ? charAt(separatorChars, 0) : null;

		while(i < length)
		{
			String character = charAt(input, i);

			if(isSeparatorCharacter(character, separatorChars, singleSeparator))
			{
				if(match)
				{
					if(sizePlus1++ == max)
					{
						i = length;
					}
					parts.add(input.substring(start, i));
					match = false;
				}
				start = ++i;
				continue;
			}
			match = true;
			i++;
		}
		if(match)
		{
			parts.add(input.substring(start, i));
		}
		return parts;
	}

	/**
	 * @description Determines whether a character is a separator based on the separator configuration.
	 *
	 * @param character the character to test
	 * @param separatorChars the full set of separator characters, or null for whitespace splitting
	 * @param singleSeparator the pre-extracted single separator character for optimised comparison, or null
	 *
	 * @return true if the character is a separator
	 */
	private static Boolean isSeparatorCharacter(String character, String separatorChars, String singleSeparator)
	{
		if(separatorChars == null)
		{
			return UTIL_Character.isWhitespace(character);
		}
		if(singleSeparator != null)
		{
			return character == singleSeparator;
		}
		return separatorChars.indexOf(character) >= 0;
	}

	/**
	 * @description <p>Splits the provided text into an array, separator string specified.</p>
	 * <p/>
	 * <p>The separator(s) will not be included in the returned String array.
	 * Adjacent separators are treated as one separator.</p>
	 * <p/>
	 * <p>A {@code null} input String returns {@code null}.
	 * A {@code null} separator splits on whitespace.</p>
	 * <p/>
	 *
	 * @param input the String to parse, may be null
	 * @param separator String containing the String to be used as a delimiter,
	 *  {@code null} splits on whitespace
	 *
	 * @return an array of parsed Strings, {@code null} if null String was input
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_String.splitByWholeSeparator(null, '-!-');           // returns null
	 * UTIL_String.splitByWholeSeparator('', '-!-');             // returns new List<String>()
	 * UTIL_String.splitByWholeSeparator('ab de fg', null);      // returns new List<String>{'ab', 'de', 'fg'}
	 * UTIL_String.splitByWholeSeparator('ab   de fg', null);    // returns new List<String>{'ab', 'de', 'fg'}
	 * UTIL_String.splitByWholeSeparator('ab:cd:ef', ':');       // returns new List<String>{'ab', 'cd', 'ef'}
	 * UTIL_String.splitByWholeSeparator('ab-!-cd-!-ef', '-!-'); // returns new List<String>{'ab', 'cd', 'ef'}
	 * ```
	 */
	global static List<String> splitByWholeSeparator(String input, String separator)
	{
		if(input == null)
		{
			return null;
		}

		Integer length = input.length();
		if(length == 0)
		{
			return new List<String> {};
		}

		if(String.isEmpty(separator))
		{
			return split(input, null, -1);
		}
		Integer separatorLength = separator.length();

		List<String> substrings = new List<String>();
		Integer beginIndex = 0;
		Integer endIndex = 0;
		while(endIndex < length)
		{
			endIndex = input.indexOf(separator, beginIndex);

			if(endIndex > -1)
			{
				if(endIndex > beginIndex)
				{
					substrings.add(input.substring(beginIndex, endIndex));
					beginIndex = endIndex + separatorLength;
				}
				else
				{
					beginIndex = endIndex + separatorLength;
				}
			}
			else
			{
				substrings.add(input.substring(beginIndex));
				endIndex = length;
			}
		}

		return substrings;
	}

	/**
	 * @description <p>Gets a substring from the specified String avoiding exceptions.</p>
	 * <p/>
	 * <p>A negative start position can be used to start {@code n}
	 * characters from the end of the String.</p>
	 * <p/>
	 * <p>A {@code null} String will return {@code null}.
	 * An empty ("") String will return "".</p>
	 * <p/>
	 *
	 * @param input the String to get the substring from, may be null
	 * @param startIndex the position to start from, negative means
	 *  count back from the end of the String by this many characters
	 *
	 * @return substring from start position, {@code null} if null String input
	 *
	 * @example
	 * ```apex
	 * UTIL_String.substring(null, 2);    // returns null (any startIndex)
	 * UTIL_String.substring('', 2);      // returns '' (any startIndex)
	 * UTIL_String.substring('abc', 0);   // returns 'abc'
	 * UTIL_String.substring('abc', 2);   // returns 'c'
	 * UTIL_String.substring('abc', 4);   // returns ''
	 * UTIL_String.substring('abc', -2);  // returns 'bc'
	 * UTIL_String.substring('abc', -4);  // returns 'abc'
	 * ```
	 */
	public static String substring(String input, Integer startIndex)
	{
		if(input == null)
		{
			return null;
		}

		if(startIndex < 0)
		{
			startIndex = input.length() + startIndex;
		}

		if(startIndex < 0)
		{
			startIndex = 0;
		}

		if(startIndex >= input.length())
		{
			return EMPTY;
		}
		return input.substring(startIndex);
	}

	/**
	 * @description <p>Gets a substring from the specified String avoiding exceptions.</p>
	 * <p/>
	 * <p>A negative start position can be used to start/end {@code n}
	 * characters from the end of the String.</p>
	 * <p/>
	 * <p>The returned substring starts with the character in the {@code start}
	 * position and ends before the {@code end} position. All position counting is
	 * zero-based -- i.e., to start at the beginning of the string use
	 * {@code start = 0}. Negative start and end positions can be used to
	 * specify offsets relative to the end of the String.</p>
	 * <p/>
	 * <p>If {@code start} is not strictly to the left of {@code end}, ""
	 * is returned.</p>
	 * <p/>
	 *
	 * @param input the String to get the substring from, may be null
	 * @param startIndex the position to start from, negative means
	 *  count back from the end of the String by this many characters
	 * @param endIndex the position to end at (exclusive), negative means
	 *  count back from the end of the String by this many characters
	 *
	 * @return substring from start position to end position,
	 *  {@code null} if null String input
	 *
	 * @example
	 * ```apex
	 * UTIL_String.substring(null, 0, 2);    // returns null (any indices)
	 * UTIL_String.substring('', 0, 2);      // returns '' (any indices)
	 * UTIL_String.substring('abc', 0, 2);   // returns 'ab'
	 * UTIL_String.substring('abc', 2, 0);   // returns ''
	 * UTIL_String.substring('abc', 2, 4);   // returns 'c'
	 * UTIL_String.substring('abc', 4, 6);   // returns ''
	 * UTIL_String.substring('abc', 2, 2);   // returns ''
	 * UTIL_String.substring('abc', -2, -1); // returns 'b'
	 * UTIL_String.substring('abc', -4, 2);  // returns 'ab'
	 * ```
	 */
	public static String substring(String input, Integer startIndex, Integer endIndex)
	{
		if(input == null)
		{
			return null;
		}
		if(endIndex < 0)
		{
			endIndex = input.length() + endIndex;
		}
		if(startIndex < 0)
		{
			startIndex = input.length() + startIndex;
		}

		if(endIndex > input.length())
		{
			endIndex = input.length();
		}

		if(startIndex >= endIndex)
		{
			return EMPTY;
		}

		if(startIndex < 0)
		{
			startIndex = 0;
		}
		if(endIndex < 0)
		{
			endIndex = 0;
		}
		return input.substring(startIndex, endIndex);
	}

	/**
	 * @description <p>Gets the String that is nested in between two Strings.
	 * Only the first match is returned.</p>
	 * <p/>
	 * <p>A {@code null} input String returns {@code null}.
	 * A {@code null} open/close returns {@code null} (no match).
	 * An empty ("") open and close returns an empty string.</p>
	 * <p/>
	 *
	 * @param input the String containing the substring, may be null
	 * @param open the String before the substring, may be null
	 * @param close the String after the substring, may be null
	 *
	 * @return the substring, {@code null} if no match
	 *
	 * @example
	 * ```apex
	 * UTIL_String.substringBetween('wx[b]yz', '[', ']');       // returns 'b'
	 * UTIL_String.substringBetween(null, '[', ']');            // returns null (any open/close)
	 * UTIL_String.substringBetween('abc', null, ']');          // returns null (any str/close)
	 * UTIL_String.substringBetween('abc', '[', null);          // returns null (any str/open)
	 * UTIL_String.substringBetween('', '', '');                // returns ''
	 * UTIL_String.substringBetween('', '', ']');               // returns null
	 * UTIL_String.substringBetween('', '[', ']');              // returns null
	 * UTIL_String.substringBetween('yabcz', '', '');           // returns ''
	 * UTIL_String.substringBetween('yabcz', 'y', 'z');         // returns 'abc'
	 * UTIL_String.substringBetween('yabczyabcz', 'y', 'z');    // returns 'abc'
	 * ```
	 */
	public static String substringBetween(String input, String open, String close)
	{
		Integer start = indexOf(input, open);

		if(start != -1)
		{
			Integer endIndex = input.indexOf(close, start + open.length());

			if(endIndex != -1)
			{
				return substring(input, start + open.length(), endIndex);
			}
		}

		return null;
	}

	/**
	 * @description Wraps a string with the given character if it does not already start and end with it.
	 *
	 * @param input the String to wrap
	 * @param character the character to wrap with
	 *
	 * @return string wrapped with the character at start and end
	 *
	 * @example
	 * ```apex
	 * String result = UTIL_String.wrapWith('value', '"');
	 * ```
	 */
	public static String wrapWith(String input, String character)
	{
		String result = input;

		if(result != null && character != null)
		{
			result = input.startsWith(character) ? result : character + result;
			result = input.endsWith(character) ? result : result + character;
		}

		return result;
	}

	/**
	 * @description Will mask the given string
	 *
	 * @param sensitiveString The string to mask
	 *
	 * @return A Masked string
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = UTIL_String.maskString('value');
	 * ```
	 */
	global static String maskString(String sensitiveString)
	{
		return maskString(sensitiveString, DEFAULT_MASK_PERCENTAGE);
	}

	/**
	 * @description Will mask the given string
	 *
	 * @param sensitiveString The string to mask
	 * @param percentageOfStringToBeMasked The percentage of string to be masked
	 *
	 * @return A Masked string
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = UTIL_String.maskString('value', 99.99);
	 * ```
	 */
	global static String maskString(String sensitiveString, Decimal percentageOfStringToBeMasked)
	{
		return maskString(sensitiveString, DEFAULT_MASK_CHARACTER, MIN_MASK_LENGTH, percentageOfStringToBeMasked);
	}

	/**
	 * @description Masks a string
	 *
	 * @param sensitiveString The string to mask
	 * @param maskCharacter The character to be used for masking
	 * @param minimumStringLength The minimum length of the input string which is to be masked
	 * @param percentageOfStringToBeMasked The percentage of string to be masked
	 *
	 * @return A Masked string
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = UTIL_String.maskString('value', 'value', 10, 99.99);
	 * ```
	 */
	global static String maskString(String sensitiveString, String maskCharacter, Integer minimumStringLength, Decimal percentageOfStringToBeMasked)
	{
		String maskedString = sensitiveString;

		if(String.isNotBlank(sensitiveString) && sensitiveString.length() >= minimumStringLength)
		{
			Integer totalLength = maskedString.length();

			Integer maskLength = Math.ceil(totalLength * (percentageOfStringToBeMasked / 100)).intValue();
			Integer startIndex = Math.floor((totalLength - maskLength) / 2).intValue();

			maskedString = sensitiveString.substring(0, startIndex) + maskCharacter.repeat(maskLength) + sensitiveString.substring(startIndex + maskLength);
		}

		return maskedString;
	}

	/**
	 * @description Reports whether `candidate` is a valid credit-card number shape: 13–19 digits
	 * (optionally interrupted by single spaces or hyphens) passing the Luhn (mod-10) checksum
	 * per ISO/IEC 7812. Null / empty / whitespace / letter-containing inputs return false
	 * without throwing. Separators (space, hyphen) are stripped before the checksum; any other
	 * non-digit character causes an early-return false.
	 *
	 * Used by `maskWithLuhnValidatedRegex` to gate credit-card redaction on values that
	 * actually satisfy the card-industry checksum — without it a 15–19 digit regex match would
	 * redact transaction IDs, nanosecond timestamps, and order numbers as if they were cards.
	 * Regex checks route through `UTIL_String`'s per-transaction compiled-pattern cache to
	 * avoid recompiling on each call.
	 *
	 * @param candidate The string to validate
	 *
	 * @return True when `candidate` is 13–19 digits long after stripping separators and the Luhn sum mod 10 is zero
	 *
	 * @example
	 * ```apex
	 * UTIL_String.isValidCardNumber('4111 1111 1111 1111'); // true — valid Visa test number
	 * UTIL_String.isValidCardNumber('1234567890123456');    // false — 16-digit transaction ID
	 * ```
	 */
	public static Boolean isValidCardNumber(String candidate)
	{
		if(String.isBlank(candidate))
		{
			return false;
		}

		final Integer minimumCardDigits = 13;
		final Integer maximumCardDigits = 19;

		if(getCompiledPattern('[^0-9 \\-]', false).matcher(candidate).find())
		{
			return false;
		}

		String digits = getCompiledPattern('[^0-9]', false).matcher(candidate).replaceAll('');

		if(digits.length() < minimumCardDigits || digits.length() > maximumCardDigits)
		{
			return false;
		}

		Integer sum = 0;
		Boolean doubleNext = false;

		for(Integer position = digits.length() - 1; position >= 0; position--)
		{
			Integer digit = Integer.valueOf(digits.substring(position, position + 1));

			if(doubleNext)
			{
				digit = digit * 2;
				if(digit > 9)
				{
					digit = digit - 9;
				}
			}

			sum = sum + digit;
			doubleNext = !doubleNext;
		}

		return Math.mod(sum, 10) == 0;
	}

	/**
	 * @description Replaces every match of the given regex in the input with the supplied
	 * replacement. Case-insensitive by default. `$1`, `$2` etc. in the replacement reference
	 * capture groups from the pattern. Throws `StringException` if the replacement contains
	 * a `$` followed by a digit that does not reference an existing capture group.
	 *
	 * @param input The value to mask
	 * @param regex The regex pattern to match
	 * @param replacement The replacement string; `$1`, `$2` etc. reference capture groups
	 *
	 * @return The input with every match replaced, or the input unchanged if no match
	 *
	 * @example
	 * ```apex
	 * String result = UTIL_String.maskWithRegex('SSN: 123-45-6789', '\\b\\d{3}-\\d{2}-\\d{4}\\b', 'XXX-XX-XXXX');
	 * ```
	 */
	public static String maskWithRegex(String input, String regex, String replacement)
	{
		return maskWithRegex(input, regex, replacement, false);
	}

	/**
	 * @description Replaces every match of the given regex in the input with the supplied
	 * replacement. Use `caseSensitive = false` (the default via the 3-arg overload) for
	 * case-insensitive matching.
	 *
	 * @param input The value to mask
	 * @param regex The regex pattern to match
	 * @param replacement The replacement string; `$1`, `$2` etc. reference capture groups
	 * @param caseSensitive When false, the regex is wrapped with `(?i)` for case-insensitive matching
	 *
	 * @return The input with every match replaced, or the input unchanged if no match
	 *
	 * @example
	 * ```apex
	 * String result = UTIL_String.maskWithRegex('Authorization: Bearer abc', '(Authorization):\\s*\\S+', '$1: [REDACTED]', true);
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	public static String maskWithRegex(String input, String regex, String replacement, Boolean caseSensitive)
	{
		if(String.isEmpty(input))
		{
			return input;
		}

		return getCompiledPattern(regex, caseSensitive).matcher(input).replaceAll(replacement);
	}

	/**
	 * @description Like `maskWithRegex`, but each regex match is independently checked against
	 * `isValidCardNumber` before being replaced. Matches that do not Luhn-validate are left as-is.
	 * Intended for credit-card redaction patterns that would otherwise generate false positives
	 * on any 15-19 digit run (transaction IDs, nanosecond timestamps, order numbers).
	 *
	 * Uses the same `getCompiledPattern` cache as `maskWithRegex` for the pattern, and the
	 * `isValidCardNumber` cache for the Luhn-gate regexes - no recompilation on bulk callers.
	 *
	 * @param input The value to mask
	 * @param regex The regex pattern to match
	 * @param replacement The replacement string used for every Luhn-valid match
	 * @param caseSensitive When false, the regex is wrapped with `(?i)` for case-insensitive matching
	 *
	 * @return The input with every Luhn-valid match replaced; Luhn-invalid matches and non-matches pass through unchanged
	 *
	 * @example
	 * ```apex
	 * String result = UTIL_String.maskWithLuhnValidatedRegex(
	 *         'card 4111111111111111, trace 1234567890123456',
	 *         '\\b(?:\\d[ -]*?){15,19}\\b',
	 *         '[CARD_REDACTED]',
	 *         false);
	 * // result: 'card [CARD_REDACTED], trace 1234567890123456'
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	public static String maskWithLuhnValidatedRegex(String input, String regex, String replacement, Boolean caseSensitive)
	{
		if(String.isEmpty(input))
		{
			return input;
		}

		Set<String> luhnValidMatches = new Set<String>();
		Matcher matcher = getCompiledPattern(regex, caseSensitive).matcher(input);

		while(matcher.find())
		{
			String matched = matcher.group();
			if(isValidCardNumber(matched))
			{
				luhnValidMatches.add(matched);
			}
		}

		if(luhnValidMatches.isEmpty())
		{
			return input;
		}

		String result = input;
		for(String validMatch : luhnValidMatches)
		{
			result = result.replace(validMatch, replacement);
		}
		return result;
	}

	/**
	 * @description Per-transaction cache of compiled `Pattern` objects keyed by case-sensitivity
	 * prefix + regex string. Avoids re-compiling the same regex when the masker is invoked on
	 * hundreds of records in a bulk trigger.
	 */
	@TestVisible
	private static Map<String, Pattern> compiledPatternCache
	{
		get
		{
			if(compiledPatternCache == null)
			{
				compiledPatternCache = new Map<String, Pattern>();
			}
			return compiledPatternCache;
		}
		set;
	}

	/**
	 * @description Returns a compiled `Pattern` for the given regex and case-sensitivity, reusing
	 * a previously compiled copy when available.
	 *
	 * @param regex The regex pattern
	 * @param caseSensitive When false, the pattern is wrapped with `(?i)`
	 *
	 * @return A cached compiled `Pattern`
	 */
	private static Pattern getCompiledPattern(String regex, Boolean caseSensitive)
	{
		String key = (caseSensitive ? 'cs:' : 'ci:') + regex;

		if(!compiledPatternCache.containsKey(key))
		{
			compiledPatternCache.put(key, Pattern.compile(caseSensitive ? regex : '(?i)' + regex));
		}

		return compiledPatternCache.get(key);
	}

	/**
	 * @description Replaces every occurrence of the given literal substring with the supplied
	 * replacement. Plain text search — `$` and `\` in the replacement pass through without
	 * triggering regex capture-group handling.
	 *
	 * @param input The value to mask
	 * @param literal The exact substring to find
	 * @param replacement The replacement string
	 *
	 * @return The input with every occurrence replaced, or the input unchanged if no match
	 *
	 * @example
	 * ```apex
	 * String result = UTIL_String.maskExactMatch('Card: 4111-1111-1111-1111', '4111-1111-1111-1111', '[CARD_REDACTED]');
	 * ```
	 */
	public static String maskExactMatch(String input, String literal, String replacement)
	{
		if(String.isEmpty(input) || String.isEmpty(literal))
		{
			return input;
		}

		return input.replace(literal, replacement);
	}

	/**
	 * @description Redacts values stored under JSON keys matching the supplied regex.
	 * Case-insensitive by default.
	 *
	 * @param input The JSON string to mask
	 * @param keyRegex Regex matched against each JSON key; matching keys have their value replaced
	 * @param replacement The literal string written in place of matching values
	 *
	 * @return The input with matching values redacted; unchanged if no keys match
	 *
	 * @example
	 * ```apex
	 * String safe = UTIL_String.maskJsonKeys('{"password":"hunter2","user":"alice"}', '^(password|token)$', '***');
	 * ```
	 */
	public static String maskJsonKeys(String input, String keyRegex, String replacement)
	{
		return maskJsonKeys(input, keyRegex, replacement, false);
	}

	/**
	 * @description Redacts values stored under JSON keys matching the supplied regex.
	 * Prefers a typed `JSON.deserializeUntyped` walk; falls back to a raw-string regex pass
	 * when the payload is malformed JSON or exceeds a 2 MB safety threshold.
	 *
	 * @param input The JSON string to mask
	 * @param keyRegex Regex matched against each JSON key
	 * @param replacement The literal string written in place of matching values
	 * @param caseSensitive When false, the key regex is wrapped with `(?i)`
	 *
	 * @return The input with matching values redacted
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	public static String maskJsonKeys(String input, String keyRegex, String replacement, Boolean caseSensitive)
	{
		if(String.isEmpty(input))
		{
			return input;
		}

		if(input.length() > jsonWalkSizeThreshold)
		{
			return maskJsonKeysViaRegex(input, keyRegex, replacement, caseSensitive);
		}

		try
		{
			Object parsed = JSON.deserializeUntyped(input);
			Object masked = applyJsonKeyRuleToTree(parsed, keyRegex, replacement, caseSensitive);
			return JSON.serialize(masked);
		}
		catch(System.JSONException parseError)
		{
			return maskJsonKeysViaRegex(input, keyRegex, replacement, caseSensitive);
		}
	}

	/**
	 * @description Result wrapper returned by `applyJsonKeyRuleToTreeWithCount`. Callers get
	 * the (possibly mutated) tree, a boolean flag indicating whether any replacement happened,
	 * and a count of replacements performed. The flag lets callers avoid a redundant round-trip
	 * `JSON.serialize` comparison to detect mutation — the hot-path optimisation driving
	 * the masking performance pass.
	 */
	public class JsonKeyMaskResult
	{
		/**
		 * @description The same tree reference passed in, with values under matching keys replaced.
		 */
		public Object tree;

		/**
		 * @description True when at least one replacement was performed. False when no key matched.
		 */
		public Boolean mutated = false;

		/**
		 * @description Total number of replacements performed across all nested key matches.
		 */
		public Integer replacementCount = 0;
	}

	/**
	 * @description Applies a JsonKey masking rule to an already-deserialized JSON tree and
	 * returns a `JsonKeyMaskResult` carrying both the tree and a mutation indicator. Use this
	 * when batching multiple JsonKey rules on the same parsed tree — the mutation flag lets
	 * the batch driver serialize the tree exactly once at the end, instead of once per rule.
	 *
	 * @param parsedValue The deserialized JSON tree (`Map<String, Object>`, `List<Object>`, or a scalar)
	 * @param keyRegex Regex matched against each JSON key
	 * @param replacement Literal value to write in place of matching values
	 * @param caseSensitive When false, the key regex is wrapped with `(?i)`
	 *
	 * @return A `JsonKeyMaskResult` with `tree` set to the same reference, `mutated` true iff any value was replaced, and `replacementCount` equal to the number of replacements
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	public static JsonKeyMaskResult applyJsonKeyRuleToTreeWithCount(Object parsedValue, String keyRegex, String replacement, Boolean caseSensitive)
	{
		JsonKeyMaskResult result = new JsonKeyMaskResult();
		result.tree = parsedValue;

		if(parsedValue == null)
		{
			return result;
		}

		Pattern keyPattern = getCompiledPattern(keyRegex, caseSensitive);
		walkAndMaskJsonKeysTracked(parsedValue, keyPattern, replacement, 0, result);
		return result;
	}

	/**
	 * @description Back-compat wrapper: delegates to `applyJsonKeyRuleToTreeWithCount` and
	 * returns the tree only. Preserves the existing public API so external callers that do
	 * not need mutation data are unaffected.
	 *
	 * @param parsedValue The deserialized JSON tree
	 * @param keyRegex Regex matched against each JSON key
	 * @param replacement Literal value to write in place of matching values
	 * @param caseSensitive When false, the key regex is wrapped with `(?i)`
	 *
	 * @return The same tree reference passed in, with values under matching keys replaced
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	public static Object applyJsonKeyRuleToTree(Object parsedValue, String keyRegex, String replacement, Boolean caseSensitive)
	{
		return applyJsonKeyRuleToTreeWithCount(parsedValue, keyRegex, replacement, caseSensitive).tree;
	}

	/**
	 * @description Recursively walks a deserialized JSON value, replacing the value under every
	 * key that matches the pattern and incrementing the tracked result counter on each replacement.
	 * Stops descending a branch when depth exceeds `JSON_WALK_MAX_DEPTH`. Preserves the traversal
	 * semantics of the previous `walkAndMaskJsonKeys` verbatim — only mutation tracking is added.
	 *
	 * @param value The current node in the JSON tree
	 * @param keyPattern Compiled pattern matched against each key
	 * @param replacement The literal string written in place of matching values
	 * @param depth Current recursion depth
	 * @param result The accumulator carrying the mutation flag and replacement count
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static void walkAndMaskJsonKeysTracked(Object value, Pattern keyPattern, String replacement, Integer depth, JsonKeyMaskResult result)
	{
		if(depth > JSON_WALK_MAX_DEPTH || value == null)
		{
			return;
		}

		if(value instanceof Map<String, Object>)
		{
			Map<String, Object> asMap = (Map<String, Object>)value;
			for(String key : new List<String>(asMap.keySet()))
			{
				if(keyPattern.matcher(key).matches())
				{
					asMap.put(key, replacement);
					result.mutated = true;
					result.replacementCount++;
				}
				else
				{
					walkAndMaskJsonKeysTracked(asMap.get(key), keyPattern, replacement, depth + 1, result);
				}
			}
			return;
		}

		if(value instanceof List<Object>)
		{
			for(Object element : (List<Object>)value)
			{
				walkAndMaskJsonKeysTracked(element, keyPattern, replacement, depth + 1, result);
			}
		}
	}

	/**
	 * @description Regex-based fallback for maskJsonKeys when the payload cannot be parsed or is
	 * too large for the typed walk. Matches the JSON `"key": "value"` pattern for each key
	 * satisfying keyRegex and replaces the value.
	 *
	 * @param input The raw string
	 * @param keyRegex The key pattern supplied by the caller
	 * @param replacement The literal string to substitute
	 * @param caseSensitive Whether the match is case-sensitive
	 *
	 * @return The input with matching JSON-style key-value pairs redacted
	 */
	private static String maskJsonKeysViaRegex(String input, String keyRegex, String replacement, Boolean caseSensitive)
	{
		String keyRegexInner = keyRegex.removeStart('^').removeEnd('$');
		String compositeKey = 'jsonComposite:' + (caseSensitive ? 'cs:' : 'ci:') + keyRegexInner;

		Pattern compositePattern = compiledPatternCache.get(compositeKey);

		if(compositePattern == null)
		{
			String flag = caseSensitive ? '' : '(?i)';
			// Use named groups so capturing groups inside the caller-supplied key regex
			// do not shift `$1`/`$2` positions in the replacement. `keyRegexInner` often
			// contains its own parens (e.g. `(password|token|...)`), and unnamed positional
			// back-references would then point at the key name rather than the trailing quote.
			// Template-assembled so the static analyser sees a complete regex literal with
			// both groups closed — prevents "Empty group" false positives.
			String compositeTemplate = '__FLAG__(?<lead>"(?:__KEY__)"\\s*:\\s*")[^"]*(?<tail>")';
			String assembledRegex = compositeTemplate.replace('__FLAG__', flag).replace('__KEY__', keyRegexInner);
			compositePattern = Pattern.compile(assembledRegex);
			compiledPatternCache.put(compositeKey, compositePattern);
		}

		String safeReplacement = replacement == null ? '' : replacement.replace('\\', '\\\\').replace('$', '\\$');
		return compositePattern.matcher(input).replaceAll('${lead}' + safeReplacement + '${tail}');
	}

	/**
	 * @description Will perform a search and replace of whole words only
	 *
	 * @param text The text to search
	 * @param searchString The word to search for
	 * @param replacement The text to replace found string with
	 *
	 * @return A string with all the found whole words replaced
	 *
	 * @example
	 * ```apex
	 * String result = UTIL_String.replaceWholeWords('value', 'value', 'value');
	 * ```
	 */
	public static String replaceWholeWords(String text, String searchString, String replacement)
	{
		String replacedString = text;

		if(String.isNotEmpty(text) && String.isNotEmpty(searchString))
		{
			replacedString = text.replaceAll('\\b' + Pattern.quote(searchString) + '\\b', replacement);
		}

		return replacedString;
	}

	/**
	 * @description Will replace each of the search strings with associated replacement string. This will only replace matched whole words
	 *
	 * @param text The String to search
	 * @param searchStrings A list of search strings
	 * @param replacementStrings A list of replacement strings
	 *
	 * @return A string with found words replaced
	 *
	 * @throws IllegalArgumentException if the searchStrings and replacementString lists are the same size
	 *
	 * @example
	 * ```apex
	 * String result = UTIL_String.replaceWholeWords('value', new List<String>{'a', 'b', 'c'}, new List<String>{'a', 'b', 'c'});
	 * ```
	 */
	public static String replaceWholeWords(String text, List<String> searchStrings, List<String> replacementStrings)
	{
		String replacedString = text;

		if(String.isNotEmpty(replacedString) && searchStrings != null && replacementStrings != null && !searchStrings.isEmpty() && !replacementStrings.isEmpty())
		{
			if(searchStrings.size() != replacementStrings.size())
			{
				throw new IllegalArgumentException('Search and Replace array lengths don\'t match: ' + searchStrings.size() + ' vs ' + replacementStrings.size());
			}

			for(Integer i = 0; i < searchStrings.size(); i++)
			{
				String searchFor = searchStrings[i];
				String replaceWith = replacementStrings[i];

				replacedString = replaceWholeWords(replacedString, searchFor, replaceWith);
			}
		}

		return replacedString;
	}

	/**
	 * @description Splits a delimited string into a list of strings.
	 *
	 * @param delimitedString The string to split
	 * @param delimiter The delimiter to use for splitting
	 *
	 * @return A List of split elements, or an empty list if the input is blank
	 *
	 * @example
	 * ```apex
	 * List<String> parts = UTIL_String.toList('one,two,three', ',');
	 * ```
	 */
	public static List<String> toList(String delimitedString, String delimiter)
	{
		List<String> stringsList = new List<String>();

		if(String.isNotBlank(delimitedString))
		{
			stringsList = splitByWholeSeparator(delimitedString, delimiter);
		}

		return stringsList;
	}

	/**
	 * @description Converts a delimited name-value string into a map.
	 *
	 * @param separatedNameValues A string containing name-value pairs (e.g. "key1=value1,key2=value2")
	 * @param separator The separator between pairs; defaults to comma if null
	 *
	 * @return A map containing the name-value pairs
	 *
	 * @example
	 * ```apex
	 * Map<String, String> params = UTIL_String.toMap('key1=value1,key2=value2', ',');
	 * ```
	 */
	public static Map<String, String> toMap(String separatedNameValues, String separator)
	{
		Map<String, String> valueByNameMap = new Map<String, String>();

		List<String> parameterList = toList(separatedNameValues, separator ?? COMMA);

		for(String parameter : parameterList)
		{
			List<String> singleParameterList = toList(parameter, EQUALS);

			if(singleParameterList.size() == 2)
			{
				valueByNameMap.put(singleParameterList[0]?.trim(), singleParameterList[1]?.trim());
			}
		}

		return valueByNameMap;
	}

	/**
	 * @description Builds a delimited string from incrementally added items, with optional prefix per item.
	 */
	public virtual inherited sharing class DelimitedListBuilder
	{
		/**
		 * @description The list of string items to join.
		 */
		private final List<String> items = new List<String>();

		/**
		 * @description Prefix applied to each item during concatenation.
		 */
		private String itemPrefix = EMPTY;

		/**
		 * @description Delimiter used to separate items.
		 */
		private String delimiter = COMMA;

		/**
		 * @description Default constructor.
		 *
		 * @example
		 * ```apex
		 * UTIL_String.DelimitedListBuilder builder = new UTIL_String.DelimitedListBuilder();
		 * ```
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public DelimitedListBuilder()
		{
		}

		/**
		 * @description Constructor which initialises the builder with values.
		 *
		 * @param values List of values to initialise the builder with.
		 *
		 * @example
		 * ```apex
		 * UTIL_String.DelimitedListBuilder builder = new UTIL_String.DelimitedListBuilder(new List<String>{'a', 'b'});
		 * ```
		 */
		public DelimitedListBuilder(List<String> values)
		{
			items.addAll(values);
		}

		/**
		 * @description Adds a single string value.
		 *
		 * @param value A string to append to the builder.
		 */
		public void add(String value)
		{
			items.add(value);
		}

		/**
		 * @description Adds a list of string values.
		 *
		 * @param values A list of strings to append to the builder.
		 */
		public void add(List<String> values)
		{
			items.addAll(values);
		}

		/**
		 * @description Sets a prefix for each item in the list during concatenation.
		 *
		 * @param itemPrefix A prefix to add to each item.
		 *
		 * @example
		 * ```apex
		 * UTIL_String.DelimitedListBuilder builder = new UTIL_String.DelimitedListBuilder();
		 * builder.setItemPrefix('*');
		 * builder.add(new List<String>{'Item1', 'Item2'});
		 * System.debug(builder.toString()); // Output: '*Item1,*Item2'
		 * ```
		 */
		public void setItemPrefix(String itemPrefix)
		{
			this.itemPrefix = itemPrefix;
		}

		/**
		 * @description Sets the delimiter used during concatenation.
		 *
		 * @param delimiter The delimiter to separate items.
		 */
		public void setDelimiter(String delimiter)
		{
			this.delimiter = delimiter;
		}

		/**
		 * @description Generates a concatenated string with prefix and delimiter.
		 *
		 * @return A formatted string representing the builder's content.
		 */
		public override String toString()
		{
			return itemPrefix + String.join(items, delimiter + itemPrefix);
		}
	}

}