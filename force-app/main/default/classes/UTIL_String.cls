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
 * @date February 2026, October 2026
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
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength,PMD.NcssTypeCount,PMD.NcssCount,PMD.AvoidGlobalModifier')
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
	 * @description Double-quote character constant '"'
	 */
	public static final String DOUBLE_QUOTE = '"';

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
	 * @description Pipe/vertical-bar character constant '|'
	 */
	public static final String PIPE = '|';

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
	 * @description Number of characters the ellipsis takes (3). The abbreviate methods take it off the maximum width to
	 * find how much of the text still fits beside the ellipsis.
	 */
	private static final Integer ELLIPSIS_LENGTH = ELLIPSIS.length();

	/**
	 * @description Minimum abbreviation width (ellipsis length + 1).
	 */
	private static final Integer MIN_ABBREVIATION_WIDTH = ELLIPSIS_LENGTH + 1;

	/**
	 * @description Share of the text that maskString hides when the caller gives no percentage: about two thirds (66.66
	 * percent).
	 */
	private static final Double DEFAULT_MASK_PERCENTAGE = 66.66;

	/**
	 * @description Character that maskString writes in place of each hidden character when the caller gives no mask
	 * character.
	 */
	private static final String DEFAULT_MASK_CHARACTER = 'x';

	/**
	 * @description Minimum string length required for masking.
	 */
	private static final Integer MIN_MASK_LENGTH = 3;

	/**
	 * @description What the Luhn check adds for a digit it doubles. The list is read by digit: place 0 holds the value for 0,
	 * place 7 holds the value for 7. A doubled digit above 9 counts as its two digits added together, so 7 doubled is 14 and
	 * counts as 5.
	 */
	private static final List<Integer> DOUBLED_DIGIT_VALUES = new List<Integer> {0, 2, 4, 6, 8, 1, 3, 5, 7, 9};

	/**
	 * @description How many numbers `maskWithLuhnValidatedRegex` checks with the Luhn check in one value. The pattern finds
	 * the numbers one by one. The first 50 numbers are checked, and only the ones that pass are hidden. Every number the
	 * pattern finds after the first 50 is hidden without the check. A text with that many card-shaped numbers is not an
	 * ordinary message, and checking thousands of them one by one would use too much processing time.
	 */
	public static final Integer LUHN_CANDIDATE_BUDGET = 50;

	/**
	 * @description The longest piece of a value that `maskWithLuhnValidatedRegex` searches with one pattern search. The
	 * platform stops a pattern search that takes too many steps, and a long digit text can reach that limit. So a value
	 * longer than this is searched in pieces of at most this many characters. A shorter value is searched in one go.
	 */
	public static final Integer CARD_SEARCH_PIECE_LENGTH = 32768;

	/**
	 * @description How many characters two pieces of a long value have in common when `maskWithLuhnValidatedRegex`
	 * searches it in pieces. Each piece starts this many characters before the end of the piece before it, so a number
	 * that crosses the end of one piece is found whole in the next one. This works for every number up to this length. A
	 * number longer than this, which only a pattern that allows long runs of separators can find, can be cut at the end of a
	 * piece. No card number written with single spaces or hyphens comes near this length: the longest is 37 characters,
	 * 19 digits and 18 separators.
	 */
	public static final Integer CARD_SEARCH_PIECE_OVERLAP = 2048;

	/**
	 * @description The longest piece of a value that `maskWithRegex` searches with one pattern search. The platform stops
	 * a pattern search that takes too many steps, and ends the transaction with an error that no code can catch. The
	 * shipped rule that hides JSON Web Tokens reaches that limit in one search over 400,000 to 490,000 characters of
	 * ordinary text. The limit counts each search on its own, so fifteen searches of this length in one transaction
	 * finish in about 60 milliseconds. A value at or under this length is searched in one go.
	 */
	public static final Integer PATTERN_SEARCH_PIECE_LENGTH = 131072;

	/**
	 * @description How many characters two pieces of a long value have in common when `maskWithRegex` searches it in
	 * pieces. Each piece starts this many characters before the end of the piece before it, so a match of up to this
	 * length that crosses the end of one piece is found whole in the next one. A JSON Web Token is at most about 22,000
	 * characters long, so it always fits. A match of a pattern that can match more than this many characters can be cut
	 * at the end of a piece.
	 */
	public static final Integer PATTERN_SEARCH_PIECE_OVERLAP = 32768;

	/**
	 * @description The backslash that, in a replacement, writes the character after it as it is. `\$` writes a dollar
	 * sign instead of starting a group reference.
	 */
	private static final String REPLACEMENT_ESCAPE_START = '\\';

	/**
	 * @description The dollar sign that starts a group reference in a replacement, such as `$1` or `${name}`.
	 */
	private static final String REPLACEMENT_GROUP_START = '$';

	/**
	 * @description The ten digits. A character is a digit when this text holds it.
	 */
	private static final String DIGITS = '0123456789';

	/**
	 * @description Finds, in the text of a pattern, the parts that matter for numbering its groups: a quoted part
	 * (`\Q...\E`), an escaped character, a character class, a bracket that opens a group without a name, and a bracket
	 * that opens a named group (its name is group 1). See `findGroupNumbersByName`.
	 */
	private static final Pattern GROUP_OPENING_SEARCH =
			Pattern.compile('\\\\Q[\\s\\S]*?(?:\\\\E|$)|\\\\[\\s\\S]|\\[(?:\\\\[\\s\\S]|[^\\]\\\\])*+\\]|\\((?!\\?)|\\(\\?<([a-zA-Z][a-zA-Z0-9]*)>');

	/**
	 * @description Maximum recursion depth while walking a deserialized JSON tree.
	 */
	private static final Integer JSON_WALK_MAX_DEPTH = 50;

	/**
	 * @description The most opening brackets (`{` and `[` added together) a JSON value can hold and still be read as a
	 * whole tree by `maskJsonKeys`. A value with more is read one token at a time by `maskJsonKeysStreaming`. The
	 * platform reads a whole tree by going one level deeper for each nested object or list. A value nested 1,000 levels
	 * deep is read without a problem, but one nested 2,000 levels deep ends the transaction with an error that no code can
	 * catch. A value is never nested deeper than its count of opening brackets, so a value at or under this count is far
	 * from that limit. The count also sends long lists of small objects to the token reader. The tree takes more than
	 * a second on a full-length list of 9,000 objects, and the token reader takes about a third of a second.
	 */
	public static final Integer JSON_STRUCTURE_LINE = 500;

	/**
	 * @description The longest piece of a value that `canHoldMatchingJsonKey` searches for a key name with one pattern
	 * search. The platform stops a pattern search that takes too many steps: one search for the key names over a whole
	 * full-length value ends the transaction from about 96,000 characters. A search over pieces of this length stays far
	 * below that limit. Each piece gets its own matcher, because the platform adds up the steps of every search made with
	 * one matcher.
	 */
	public static final Integer KEY_SEARCH_PIECE_LENGTH = 16384;

	/**
	 * @description How many characters two pieces of a value have in common when `canHoldMatchingJsonKey` searches it in
	 * pieces. Each piece starts this many characters before the end of the piece before it. So a key name of up to this
	 * length that crosses the end of one piece lies whole inside the next piece, and the search finds it there. The longest
	 * key name the shipped secret-keys rule matches has 13 characters.
	 *
	 * What this does not cover: a key name longer than this that crosses the end of a piece can be missed. The search
	 * then finds no key name, and the rule skips the value, so the value under that key is not replaced.
	 */
	public static final Integer KEY_SEARCH_PIECE_OVERLAP = 64;

	/**
	 * @description Finds the parts of a key pattern that make the key name search of `canHoldMatchingJsonKey` unsafe.
	 * The text search for `"key":"value"` pairs does not run with such a pattern either (see `maskJsonKeysViaRegex`).
	 * - A `^` or `$` left inside the pattern, a backslash anchor or word boundary (`\b`, `\B`, `\A`, `\z`, `\Z`,
	 *   `\G`), and a look-ahead or look-behind group. Each of them can match a key name on its own but fail on the
	 *   same name inside the whole text, because they look at what comes before or after the name.
	 * - A repeat with no upper limit: `*`, `+` or `{n,}`. Searched over a long piece of text, such a pattern (for
	 *   example `.*secret.*`) tries a match from every place to every later place. The number of steps grows with the
	 *   square of the piece length and ends the transaction.
	 * - A repeat whose upper count has three digits or more, such as `{0,99999}`, `{100}` or the `{1,100}` in
	 *   `^x_[a-z0-9]{1,100}$`. The check does not work out how many steps such a repeat can take (a repeat inside
	 *   another repeat multiplies them), so it treats every large count as unsafe. This applies to the text search
	 *   too: a value that holds a quote then gets `UTIL_FrameworkMasker.FAILURE_MARKER` in place of the whole value.
	 *   No key name needs a count that large.
	 * The check does not look at a backslash before a character. So an escaped `\*` or `\+`, which matches only that
	 * character, counts as a repeat too. That is on the safe side: such a pattern only loses the quick key name search,
	 * and the text search does not run with it.
	 */
	private static final Pattern KEY_SEARCH_UNSAFE_PARTS = Pattern.compile('\\^|\\$|\\\\[bBAzZG]|\\(\\?[=!<]|\\*|\\+|\\{\\d+,\\}|\\{(?:\\d+,)?\\d{3,}\\}');

	/**
	 * @description The backslash that starts every escape in JSON text. For example, the letter a can be written as a
	 * backslash, the letter u and the four hexadecimal digits 0061.
	 */
	private static final String JSON_ESCAPE_START = '\\';

	/**
	 * @description The longest piece of a value that the text search for `"key":"value"` pairs (see
	 * `maskJsonKeysViaRegex`) searches with one pattern search. The platform adds up the steps of every search made with
	 * one matcher, and one search over a whole full-length value, such as a wall of quotes, ends the transaction with an
	 * error that no code can catch. Each piece gets its own matcher, and a search over a piece of this length stays far
	 * below that limit.
	 */
	public static final Integer JSON_TEXT_SEARCH_PIECE_LENGTH = 16384;

	/**
	 * @description How many characters two pieces of a value have in common when the text search for `"key":"value"`
	 * pairs searches it in pieces. Each piece starts this many characters before the end of the piece before it. So a
	 * key in quotes, with its colon, of up to this length that crosses the end of one piece lies whole inside the next
	 * piece, and the search finds it there.
	 *
	 * A key can be written with JSON escapes, where six characters stand for one letter: a backslash, the letter u
	 * and four hexadecimal digits. Some programs write every letter outside plain English this way. So a key name of up to about
	 * 84 letters still fits, even with every letter written as an escape. Each piece reads about 3% of its text twice.
	 *
	 * What this does not cover: a key written longer than this length can be missed where one piece ends and the next
	 * begins, and then its value is not replaced.
	 */
	public static final Integer JSON_TEXT_SEARCH_PIECE_OVERLAP = 512;

	/**
	 * @description The most characters the text search for `"key":"value"` pairs reads, from the start of a key, when it
	 * reads a pair again over the rest of the value (see `JsonTextSearch.readPairAt`). One match over a long text ends the
	 * transaction with a platform error that no code can catch. Escapes cost more than plain text: a run of plain
	 * letters is read in one go, but each escape (a backslash and the character after it) is read on its own.
	 *
	 * Measured with one match in a synchronous transaction: it finished over 900,000 plain letters and ended the
	 * transaction at 1,000,000. Over escaped quotes (a backslash and a quote, again and again) it finished at 650,000
	 * characters and ended the transaction at 675,000. Over a letter and an escaped quote taking turns, the text that
	 * costs the most for each character, it finished at 585,000 characters and ended the transaction at 600,000. This
	 * length is less than half of the lowest of these, to leave a wide margin.
	 *
	 * A secret text longer than this has no closing quote inside what is read, so the search cannot hide it safely,
	 * and the whole value gets the failure marker instead. The same happens whenever a read reaches this length and more
	 * of the value follows, such as spaces around the colon of a key that are longer than this, or a lone quote with no
	 * closing quote within this length; a value that holds no secret can then get the marker too.
	 */
	private static final Integer JSON_TEXT_PAIR_READ_LENGTH = 262144;

	/**
	 * @description The start of the pattern of the text search for `"key":"value"` pairs: the case flag (`__FLAG__`), the
	 * key in quotes, and the colon with any spaces around it. The key is read in one of two ways:
	 * - As it is written: the key pattern of the rule (`__KEY__`) matches the text between the quotes.
	 * - As a key written with JSON escapes, in the named group `escapedKey`: any text between the quotes that holds
	 *   at least one backslash, read as JSON reads a text. For example, the letter a of `password` can be written
	 *   as a backslash, the letter u and the hexadecimal digits 0061. The search then checks the name the key stands for
	 *   (see `JsonTextSearch.isEscapedKeyMatching`). The opening quote of such a key must not follow a backslash,
	 *   because a quote after a backslash is part of a text and never starts a key. This also keeps the search
	 *   quick on a text full of escaped quotes: each try reads only to the next quote that ends a text.
	 * Spaces are read possessively: once read, they are never given back, so a long run of spaces costs one step.
	 */
	private static final String JSON_TEXT_KEY_TEMPLATE = '__FLAG__(?:"(?:__KEY__)|(?<!\\\\)"(?<escapedKey>[^"\\\\]*+(?:\\\\[\\s\\S][^"\\\\]*+)++))"\\s*+:\\s*+';

	/**
	 * @description The end of the pattern of the text search for `"key":"value"` pairs: the value after the colon, in one
	 * of two named groups.
	 * - `scalar`: one whole JSON text, number, `true`, `false` or `null`, followed by a space, a comma, a closing
	 *   brace or bracket, or the end of the text. A text is read as JSON reads it: ordinary characters, or a
	 *   backslash and the character after it, up to the closing quote. A run of ordinary characters is read in one
	 *   go, but each escape is read on its own, so a long text full of escapes costs more (see
	 *   `JSON_TEXT_PAIR_READ_LENGTH`).
	 * - `other`: any other character after the colon, or the end of the text. This is an object, a list, a text
	 *   without its closing quote, or a word without quotes.
	 */
	private static final String JSON_TEXT_VALUE_PATTERN =
			'(?:(?<scalar>"(?:[^"\\\\]++|\\\\[\\s\\S])*+"|-?\\d++(?:\\.\\d++)?+(?:[eE][+-]?+\\d++)?+|true|false|null)(?=[\\s,}\\]]|$)|(?<other>[\\s\\S]|$))';

	/**
	 * @description Finds a run of spaces, line breaks and colons at the start of a text. The text search reads the end of a
	 * piece backwards with it, to find where the spaces at the end of the piece begin.
	 */
	private static final Pattern SPACES_AND_COLONS = Pattern.compile('[\\s:]*+');

	/**
	 * @description Abbreviates a String using ellipses. This will turn
	 * "Now is the time for all good men" into "Now is the time for..."
	 *
	 * Specifically:
	 * - If the number of characters in {@code input} is less than or equal to
	 *   {@code maxWidth}, return {@code input}.
	 * - Else abbreviate it to {@code (substring(input, 0, max-3) + "...")}.
	 * - If {@code maxWidth} is less than {@code 4}, throw an
	 *   {@code IllegalArgumentException}.
	 * - In no case will it return a String of length greater than
	 *   {@code maxWidth}.
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
	 * @description Abbreviates a String using ellipses. This will turn
	 * "Now is the time for all good men" into "...is the time for..."
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
	 * String shortened = UTIL_String.abbreviate(longMessage, LogEntry__c.Message__c);
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
	 * @description Joins the elements of the provided array into a single String
	 * containing the provided list of elements.
	 *
	 * No delimiter is added before or after the list.
	 * Null objects or empty strings within the array are represented by
	 * empty strings.
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
	 * @description Joins the elements of the provided {@code Iterator} into
	 * a single String containing the provided elements.
	 *
	 * No delimiter is added before or after the list.
	 * A {@code null} separator is the same as an empty String ("").
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
	 * @description Joins the elements of the provided {@code Set} into a single String in
	 * ascending order, so a message or log line that lists the members of a set reads the same
	 * on every run.
	 *
	 * A Set has no documented iteration order, so {@code join(Set<String>, String)} renders
	 * whatever order the platform hands back; use this method wherever the rendering must be
	 * stable, for example a validation message that names every offending value. A {@code null}
	 * separator is the same as an empty String ("").
	 *
	 * @param values the {@code Set} of values to join together, may be null
	 * @param separator the separator character to use, null treated as ""
	 *
	 * @return the joined String in ascending order, {@code null} if null set input
	 *
	 * @see UTIL_String.join
	 *
	 * @since 1.8
	 *
	 * @example
	 * ```apex
	 * UTIL_String.joinSorted(new Set<String> {'pear', 'apple', 'fig'}, ', ');   // returns 'apple, fig, pear'
	 * UTIL_String.joinSorted(null, ', ');                                       // returns null
	 * ```
	 */
	global static String joinSorted(Set<String> values, String separator)
	{
		if(values == null)
		{
			return null;
		}
		List<String> sortedValues = new List<String>(values);
		sortedValues.sort();
		return join(sortedValues, separator);
	}

	/**
	 * @description Gets the leftmost {@code length} characters of a String.
	 *
	 * If {@code length} characters are not available, or the
	 * String is {@code null}, the String will be returned without
	 * an exception. An empty String is returned if length is negative.
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
	 * @description Removes a substring only if it is at the beginning of a source string,
	 * otherwise returns the source string.
	 *
	 * A {@code null} source string will return {@code null}.
	 * An empty ("") source string will return the empty string.
	 * A {@code null} search string will return the source string.
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
	 * @description Replaces all occurrences of a String within another String.
	 *
	 * A {@code null} reference passed to this method is a no-op.
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
	 * @description Splits the provided text into an array, using whitespace as the
	 * separator.
	 * Whitespace means a space, a tab, a new line (\n), a carriage return (\r) or a form feed (\f).
	 *
	 * The separator is not included in the returned String array.
	 * Adjacent separators are treated as one separator.
	 * For more control over the split use the StrTokenizer class.
	 *
	 * A {@code null} input String returns {@code null}.
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
	 * @description Splits the provided text into an array, separators specified.
	 * This is an alternative to using StringTokenizer.
	 *
	 * The separator is not included in the returned String array.
	 * Adjacent separators are treated as one separator.
	 * For more control over the split use the StrTokenizer class.
	 *
	 * A {@code null} input String returns {@code null}.
	 * A {@code null} separatorChars splits on whitespace.
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
	 * @description Splits the provided text into an array with a maximum length,
	 * separators specified.
	 *
	 * The separator is not included in the returned String array.
	 * Adjacent separators are treated as one separator.
	 *
	 * A {@code null} input String returns {@code null}.
	 * A {@code null} separatorChars splits on whitespace.
	 *
	 * If more than {@code max} delimited substrings are found, the last
	 * returned string includes all characters after the first {@code max - 1}
	 * returned strings (including separator characters).
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
	 * @description Splits the provided text into an array, separator string specified.
	 *
	 * The separator(s) will not be included in the returned String array.
	 * Adjacent separators are treated as one separator.
	 *
	 * A {@code null} input String returns {@code null}.
	 * A {@code null} separator splits on whitespace.
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
	 * @description Gets a substring from the specified String avoiding exceptions.
	 *
	 * A negative start position can be used to start {@code n}
	 * characters from the end of the String.
	 *
	 * A {@code null} String will return {@code null}.
	 * An empty ("") String will return "".
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
	 * @description Gets a substring from the specified String avoiding exceptions.
	 *
	 * A negative start position can be used to start/end {@code n}
	 * characters from the end of the String.
	 *
	 * The returned substring starts with the character in the {@code start}
	 * position and ends before the {@code end} position. All position counting is
	 * zero-based -- i.e., to start at the beginning of the string use
	 * {@code start = 0}. Negative start and end positions can be used to
	 * specify offsets relative to the end of the String.
	 *
	 * If {@code start} is not strictly to the left of {@code end}, ""
	 * is returned.
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
	 * @description Gets the String that is nested in between two Strings.
	 * Only the first match is returned.
	 *
	 * A {@code null} input String returns {@code null}.
	 * A {@code null} open/close returns {@code null} (no match).
	 * An empty ("") open and close returns an empty string.
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
	 * @description Hides the middle of the text and keeps its start and end. The number of hidden characters is the given
	 * percentage of the length, rounded up. Each one is replaced by maskCharacter. The characters that stay visible are
	 * split evenly between the start and the end, and when the split is uneven the end keeps one more. A blank text, or a
	 * text shorter than minimumStringLength, is returned unchanged.
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
	 * @description Reports whether `candidate` looks like a real card number: 13 to 19 digits that pass the Luhn check
	 * (the checksum built into card numbers, defined in ISO/IEC 7812). Every space and hyphen is ignored: one between two
	 * digits, several in a row, and any before the first digit or after the last one. Any other character, a null value,
	 * an empty text and a text of spaces only all return false. The method never throws.
	 *
	 * This method is hot: `maskWithLuhnValidatedRegex` calls it once for every digit group the pattern finds, and a long
	 * field can hold thousands of groups. So it uses no pattern matching, no substrings and no text-to-number conversion.
	 * It removes the spaces and hyphens with two plain text replacements, checks that only the digits 0 to 9 remain, and
	 * then adds up the digits by their character codes. A digit is its character code minus 48.
	 *
	 * The Luhn check doubles every second digit, counting from the last one. The last digit is added as it is, the one before
	 * it is doubled, and so on.
	 *
	 * @param candidate The text to check
	 *
	 * @return True when `candidate` holds 13 to 19 digits, ignoring spaces and hyphens, and the Luhn sum divided by 10 leaves no remainder
	 *
	 * @example
	 * ```apex
	 * UTIL_String.isValidCardNumber('4111 1111 1111 1111'); // true: a valid Visa test number
	 * UTIL_String.isValidCardNumber('1234567890123456');    // false: a 16-digit transaction ID
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
		final Integer zeroCharacterCode = 48;

		String digits = candidate.remove(' ').remove('-');
		Integer digitCount = digits.length();

		if(digitCount < minimumCardDigits || digitCount > maximumCardDigits || !digits.isNumeric() || !digits.isAsciiPrintable())
		{
			return false;
		}

		List<Integer> characterCodes = digits.getChars();
		Integer sum = 0;

		for(Integer index = digitCount - 1; index >= 0; index -= 2)
		{
			sum += characterCodes[index] - zeroCharacterCode;
		}

		for(Integer index = digitCount - 2; index >= 0; index -= 2)
		{
			sum += DOUBLED_DIGIT_VALUES[characterCodes[index] - zeroCharacterCode];
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
	 * A value of at most `PATTERN_SEARCH_PIECE_LENGTH` characters is searched with one `replaceAll`. A longer value is
	 * searched in pieces (see `PatternSearch`), because one search over a long value can take too many steps, and the
	 * platform then ends the transaction with an error that no code can catch. The pieces give the same text as one
	 * `replaceAll` would, with two limits: a match longer than `PATTERN_SEARCH_PIECE_OVERLAP` can be cut at the end of a
	 * piece, and a match that runs to the end of a piece is joined with a match that starts right where it ends, so a
	 * pattern such as `(?s).+` replaces the whole value once.
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

		Pattern compiledPattern = getCompiledPattern(regex, caseSensitive);

		if(input.length() <= PATTERN_SEARCH_PIECE_LENGTH)
		{
			return compiledPattern.matcher(input).replaceAll(replacement);
		}

		PatternSearch search = new PatternSearch(input, compiledPattern, replacement);
		search.searchWholeValue();
		return search.buildMaskedValue();
	}

	/**
	 * @description Finds every match of a pattern in a value longer than `PATTERN_SEARCH_PIECE_LENGTH`, for
	 * `maskWithRegex`. It keeps where each match starts and ends in the value, and the text that replaces it. The value is
	 * built again once, at the end.
	 *
	 * The value is searched in pieces of `PATTERN_SEARCH_PIECE_LENGTH` characters. Each piece starts
	 * `PATTERN_SEARCH_PIECE_OVERLAP` characters before the end of the piece before it, and the last piece ends at the end
	 * of the value. Each piece gets a matcher of its own, because the platform adds up the steps of every search made with
	 * one matcher. The matcher reads the whole value but looks for matches only inside its piece (a region). A look-behind
	 * or a look-ahead in the pattern still sees the characters just outside the piece, and `^` and `$` match only at the
	 * real start and end of the value, not at the ends of a piece.
	 */
	private inherited sharing class PatternSearch
	{
		/**
		 * @description The whole value, as the caller gave it. It is never changed: every piece is searched inside it, and
		 * the masked value is built from it at the end, or it is returned as it is when nothing matched.
		 */
		private final String input;

		/**
		 * @description The compiled pattern.
		 */
		private final Pattern searchPattern;

		/**
		 * @description The replacement as the caller gave it, with any group references still in it.
		 */
		private final String replacement;

		/**
		 * @description The replacement read into its parts, built when the first match is found (see `ReplacementText`).
		 */
		private ReplacementText replacementText;

		/**
		 * @description Where each match starts in the value, in the order the matches appear.
		 */
		private final List<Integer> matchStarts = new List<Integer>();

		/**
		 * @description Where each match ends in the value (the place just after its last character), in the same order as
		 * `matchStarts`.
		 */
		private final List<Integer> matchEnds = new List<Integer>();

		/**
		 * @description The text that replaces each match, in the same order as `matchStarts`.
		 */
		private final List<String> matchReplacements = new List<String>();

		/**
		 * @description The place in the value where the next search starts. Every place before it is decided: either it
		 * belongs to a match already kept, or no match starts there.
		 */
		private Integer resumeAt = 0;

		/**
		 * @description True when the last match kept runs to the end of its piece, and the search looked at that end. The
		 * match may go on in the next piece, so a match that starts exactly where it ends is joined to it.
		 */
		private Boolean isLastMatchOpenAtPieceEnd = false;

		/**
		 * @description Prepares a search of one value.
		 *
		 * @param input The value to search
		 * @param searchPattern The compiled pattern
		 * @param replacement The replacement, with any group references still in it
		 */
		private PatternSearch(String input, Pattern searchPattern, String replacement)
		{
			this.input = input;
			this.searchPattern = searchPattern;
			this.replacement = replacement;
		}

		/**
		 * @description Searches the whole value in pieces of `PATTERN_SEARCH_PIECE_LENGTH` characters. Each piece starts
		 * `PATTERN_SEARCH_PIECE_OVERLAP` characters before the end of the piece before it, and the last piece ends at the
		 * end of the value.
		 */
		private void searchWholeValue()
		{
			Integer inputLength = input.length();
			Integer pieceStart = 0;
			Integer pieceEnd = 0;

			while(pieceEnd < inputLength)
			{
				pieceEnd = Math.min(pieceStart + PATTERN_SEARCH_PIECE_LENGTH, inputLength);
				searchPiece(pieceStart, pieceEnd);
				pieceStart = pieceEnd - PATTERN_SEARCH_PIECE_OVERLAP;
			}
		}

		/**
		 * @description Searches one piece of the value, from `resumeAt` on, and keeps the matches it finds.
		 *
		 * The end of a piece is not the end of the value. The matcher says when a match may depend on the text after the
		 * piece: `hitEnd()` is true when the search looked at the end of the piece. Such a match, when it starts in the
		 * part the next piece also holds, is left for the next piece, which sees the text after it. The search of this
		 * piece then stops, and the next piece starts where that shared part starts, or after the last match kept, when
		 * that is later. It does not start at the match itself: the search may have passed over an earlier start only
		 * because the piece ended there, and the next piece must try that start again with the text after it in view.
		 * A match cut by the end of the piece that starts earlier is kept, and when it runs to the end of the piece, the
		 * next piece joins a match that starts right where it ends (see `keepMatch`).
		 *
		 * @param pieceStart Where the piece starts in the value
		 * @param pieceEnd Where the piece ends in the value (the place just after its last character)
		 */
		private void searchPiece(Integer pieceStart, Integer pieceEnd)
		{
			Boolean isLastPiece = pieceEnd == input.length();
			Integer nextPieceStart = pieceEnd - PATTERN_SEARCH_PIECE_OVERLAP;
			Matcher matcher = searchPattern.matcher(input).useTransparentBounds(true).useAnchoringBounds(false).region(Math.max(pieceStart, resumeAt), pieceEnd);

			while(matcher.find())
			{
				Integer matchStart = matcher.start();
				Integer matchEnd = matcher.end();
				Boolean isCutByPieceEnd = !isLastPiece && matcher.hitEnd();

				if(isCutByPieceEnd && matchStart >= nextPieceStart)
				{
					break;
				}

				keepMatch(matcher, matchStart, matchEnd);
				isLastMatchOpenAtPieceEnd = isCutByPieceEnd && matchEnd == pieceEnd;
				resumeAt = matchEnd == matchStart ? matchEnd + 1 : matchEnd;
			}

			resumeAt = Math.max(resumeAt, nextPieceStart);
		}

		/**
		 * @description Keeps one match. A match that starts exactly where the last kept match ends, when that match runs
		 * to the end of its piece, is the rest of the same match: the last kept match is made longer, and keeps its
		 * replacement. Any other match is kept with its own replacement.
		 *
		 * @param matcher The matcher positioned on the match
		 * @param matchStart Where the match starts in the value
		 * @param matchEnd Where the match ends in the value
		 */
		private void keepMatch(Matcher matcher, Integer matchStart, Integer matchEnd)
		{
			Integer lastIndex = matchEnds.size() - 1;

			if(isLastMatchOpenAtPieceEnd && matchEnds[lastIndex] == matchStart)
			{
				matchEnds[lastIndex] = matchEnd;
				return;
			}

			replacementText = replacementText ?? new ReplacementText(replacement, matcher);
			matchStarts.add(matchStart);
			matchEnds.add(matchEnd);
			matchReplacements.add(replacementText.writeFor(matcher));
		}

		/**
		 * @description Builds the value again with the kept matches replaced: the text between them is copied, and the
		 * replacement of each match is written in its place.
		 *
		 * @return The masked value, or the value itself when no match was kept
		 */
		private String buildMaskedValue()
		{
			if(matchStarts.isEmpty())
			{
				return input;
			}

			List<String> parts = new List<String>();
			Integer copiedUpTo = 0;

			for(Integer index = 0; index < matchStarts.size(); index++)
			{
				parts.add(input.substring(copiedUpTo, matchStarts[index]));
				parts.add(matchReplacements[index]);
				copiedUpTo = matchEnds[index];
			}

			parts.add(input.substring(copiedUpTo));
			return String.join(parts, EMPTY);
		}
	}

	/**
	 * @description A replacement read into its parts, so that the text for each match is the text `replaceAll` writes
	 * for it. The platform matcher has no method that writes the replacement for one match, so the replacement is read
	 * here, with the same rules `replaceAll` uses:
	 * - A backslash writes the character after it as it is. `\$` writes a dollar sign.
	 * - A dollar sign and a group number write the text of that group. The number takes as many digits as still make
	 *   a group the pattern has: with eleven groups, `$11` is group 11 and `$12` is group 1 followed by the digit
	 *   2.
	 * - A dollar sign and a name in braces, such as `${name}`, write the text of the group with that name.
	 * - A group that took no part in the match writes nothing.
	 * A replacement that `replaceAll` refuses, such as one that names a group the pattern does not have, is refused
	 * here with the same `StringException`.
	 */
	private inherited sharing class ReplacementText
	{
		/**
		 * @description The parts of the replacement, in order. A part is either a text written as it is, or null where a
		 * group is written.
		 */
		private final List<String> textParts = new List<String>();

		/**
		 * @description For each part, the number of the group written there, or null where `textParts` holds a text.
		 */
		private final List<Integer> groupParts = new List<Integer>();

		/**
		 * @description How many groups the pattern has.
		 */
		private final Integer groupCount;

		/**
		 * @description Reads the replacement into its parts. It first lets the platform check the replacement, so a
		 * replacement `replaceAll` refuses is refused here with the same exception.
		 *
		 * @param replacement The replacement, with any group references still in it
		 * @param matcher A matcher of the pattern, positioned on a match
		 *
		 * @throws StringException When `replaceAll` refuses the replacement
		 */
		private ReplacementText(String replacement, Matcher matcher)
		{
			groupCount = matcher.groupCount();
			Map<String, Integer> groupNumbersByName = replacement.contains('${') ? findGroupNumbersByName(matcher.pattern().pattern()) : new Map<String, Integer>();
			checkReplacement(replacement, groupNumbersByName);
			readParts(replacement, groupNumbersByName);
		}

		/**
		 * @description Lets the platform check the replacement. A pattern of empty groups, as many as the pattern has and
		 * with the same names in the same places, matches an empty text once, and `replaceAll` then reads the replacement
		 * and throws for a replacement it refuses.
		 *
		 * @param replacement The replacement to check
		 * @param groupNumbersByName The number of each named group of the pattern
		 *
		 * @throws StringException When `replaceAll` refuses the replacement
		 */
		private void checkReplacement(String replacement, Map<String, Integer> groupNumbersByName)
		{
			List<String> emptyGroups = new List<String>();

			for(Integer groupNumber = 1; groupNumber <= groupCount; groupNumber++)
			{
				emptyGroups.add('()');
			}

			for(String groupName : groupNumbersByName.keySet())
			{
				Integer groupNumber = groupNumbersByName.get(groupName);

				if(groupNumber <= groupCount)
				{
					emptyGroups[groupNumber - 1] = '(?<' + groupName + '>)';
				}
			}

			Pattern.compile(String.join(emptyGroups, EMPTY)).matcher(EMPTY).replaceAll(replacement);
		}

		/**
		 * @description Reads the replacement, which the platform has checked, into texts and group references (see
		 * `ReplacementText`).
		 *
		 * @param replacement The checked replacement
		 * @param groupNumbersByName The number of each named group of the pattern
		 */
		private void readParts(String replacement, Map<String, Integer> groupNumbersByName)
		{
			List<String> text = new List<String>();
			Integer index = 0;

			while(index < replacement.length())
			{
				String character = replacement.substring(index, index + 1);
				index++;

				if(character == REPLACEMENT_ESCAPE_START)
				{
					text.add(replacement.substring(index, index + 1));
					index++;
				}
				else if(character == REPLACEMENT_GROUP_START)
				{
					addPart(String.join(text, EMPTY), null);
					text.clear();
					index = readGroupReferenceAt(replacement, index, groupNumbersByName);
				}
				else
				{
					text.add(character);
				}
			}

			addPart(String.join(text, EMPTY), null);
		}

		/**
		 * @description Reads the group reference that follows a dollar sign, and adds it as a part: a name in braces, or
		 * a group number of as many digits as still make a group the pattern has.
		 *
		 * @param replacement The checked replacement
		 * @param index Where the reference starts: the place just after the dollar sign
		 * @param groupNumbersByName The number of each named group of the pattern
		 *
		 * @return The place just after the reference
		 */
		private Integer readGroupReferenceAt(String replacement, Integer index, Map<String, Integer> groupNumbersByName)
		{
			if(replacement.substring(index, index + 1) == '{')
			{
				Integer nameEnd = replacement.indexOf('}', index);
				addPart(null, groupNumbersByName.get(replacement.substring(index + 1, nameEnd)));
				return nameEnd + 1;
			}

			Integer groupNumber = Integer.valueOf(replacement.substring(index, index + 1));
			Integer next = index + 1;

			while(next < replacement.length())
			{
				String digit = replacement.substring(next, next + 1);
				Integer longerNumber = DIGITS.contains(digit) ? groupNumber * 10 + Integer.valueOf(digit) : null;

				if(longerNumber == null || longerNumber > groupCount)
				{
					break;
				}

				groupNumber = longerNumber;
				next++;
			}

			addPart(null, groupNumber);
			return next;
		}

		/**
		 * @description Adds one part: a text, or the number of a group. An empty text adds nothing.
		 *
		 * @param text The text to write as it is, or null for a group
		 * @param groupNumber The number of the group to write, or null for a text
		 */
		private void addPart(String text, Integer groupNumber)
		{
			if(String.isEmpty(text) && groupNumber == null)
			{
				return;
			}

			textParts.add(text);
			groupParts.add(groupNumber);
		}

		/**
		 * @description Writes the replacement for the match the matcher is on.
		 *
		 * @param matcher The matcher positioned on the match
		 *
		 * @return The replacement text for this match
		 */
		private String writeFor(Matcher matcher)
		{
			List<String> written = new List<String>();

			for(Integer index = 0; index < textParts.size(); index++)
			{
				written.add(textParts[index] ?? matcher.group(groupParts[index]) ?? EMPTY);
			}

			return String.join(written, EMPTY);
		}
	}

	/**
	 * @description Finds the number of each named group in a pattern, such as `(?<name>...)`. Groups are numbered by
	 * where they open, from 1, the same way the platform numbers them. Brackets that open no group are not counted: an
	 * escaped bracket, a bracket in a quoted part (`\Q...\E`) or in a character class, and a bracket followed by `?`
	 * (such as `(?:`, `(?=` and `(?i)`), except a named group. A character class inside another character class is not
	 * read; a bracket in it can make the numbers wrong.
	 *
	 * @param regex The pattern
	 *
	 * @return The number of each named group, by name
	 */
	private static Map<String, Integer> findGroupNumbersByName(String regex)
	{
		Map<String, Integer> groupNumbersByName = new Map<String, Integer>();
		Matcher token = GROUP_OPENING_SEARCH.matcher(regex);
		Integer groupNumber = 0;

		while(token.find())
		{
			if(token.group().startsWith('('))
			{
				groupNumber++;
			}

			if(token.group(1) != null)
			{
				groupNumbersByName.put(token.group(1), groupNumber);
			}
		}

		return groupNumbersByName;
	}

	/**
	 * @description Like `maskWithRegex`, but a number the pattern finds is replaced only when it looks like a real card
	 * number. It is meant for card patterns, which would otherwise also hide transaction ids, timestamps and order numbers
	 * of 13 to 19 digits.
	 *
	 * How it works:
	 * 1. The pattern finds the numbers one by one, from the start of the value to its end.
	 * 2. Each of the first `LUHN_CANDIDATE_BUDGET` numbers is checked with `isValidCardNumber`, which applies the Luhn check
	 *    (the checksum built into card numbers). A number that passes is replaced. A number that fails stays.
	 * 3. Every number after the first `LUHN_CANDIDATE_BUDGET` is replaced without the check. A text with that many
	 *    card-shaped numbers is not an ordinary message, and checking each one would use too much processing time.
	 * 4. The value is built again once. The text between the replaced numbers is copied, and the replacement is written
	 *    where each replaced number was. Only the places the pattern found are replaced: the same digits elsewhere in the
	 *    value, for example inside a longer run of digits, stay.
	 *
	 * A value longer than `CARD_SEARCH_PIECE_LENGTH` is searched in pieces of that length, because the platform stops a
	 * pattern search that takes too many steps. Each piece starts `CARD_SEARCH_PIECE_OVERLAP` characters before the end of
	 * the piece before it. So a card number that crosses the end of one piece is found whole in the next one, and no
	 * number is found twice. A number longer than `CARD_SEARCH_PIECE_OVERLAP` can be cut at the end of a piece. Only a
	 * pattern that allows long runs of separators finds such a number.
	 *
	 * The pattern comes from the same `getCompiledPattern` cache as `maskWithRegex`, so it is compiled once per transaction.
	 * The replacement is written exactly as given: a group reference such as `$1` is not expanded.
	 *
	 * @param input The value to mask
	 * @param regex The pattern that finds the numbers
	 * @param replacement The text written in place of every replaced number
	 * @param caseSensitive When false, the pattern is wrapped with `(?i)` so that case does not matter
	 *
	 * @return The input with the replaced numbers, or the input unchanged when no number is replaced
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

		CardNumberSearch search = new CardNumberSearch(input, getCompiledPattern(regex, caseSensitive));
		search.searchWholeValue();
		return search.buildMaskedValue(replacement);
	}

	/**
	 * @description Finds the numbers that `maskWithLuhnValidatedRegex` replaces in one value, and keeps where each one
	 * starts and ends in the value. The steps and the search in pieces are described on `maskWithLuhnValidatedRegex`.
	 */
	private inherited sharing class CardNumberSearch
	{
		/**
		 * @description The whole value, as the caller gave it. It is never changed: it is searched for card numbers, and
		 * the masked value is built from it at the end, or it is returned as it is when no number is replaced.
		 */
		private final String input;

		/**
		 * @description The compiled card pattern.
		 */
		private final Pattern cardPattern;

		/**
		 * @description Where each number to replace starts in the value, in the order the numbers appear.
		 */
		private final List<Integer> numberStarts = new List<Integer>();

		/**
		 * @description Where each number to replace ends in the value (the place just after its last character), in the
		 * same order as `numberStarts`.
		 */
		private final List<Integer> numberEnds = new List<Integer>();

		/**
		 * @description How many numbers the pattern has found so far in the value, checked or not. Compared with
		 * `LUHN_CANDIDATE_BUDGET`.
		 */
		private Integer candidateCount = 0;

		/**
		 * @description The place in the value where the next search starts. Every place before it is decided: either it
		 * belongs to a number already found, or no number starts there.
		 */
		private Integer resumeAt = 0;

		/**
		 * @description Prepares a search of one value.
		 *
		 * @param input The value to search
		 * @param cardPattern The compiled card pattern
		 */
		private CardNumberSearch(String input, Pattern cardPattern)
		{
			this.input = input;
			this.cardPattern = cardPattern;
		}

		/**
		 * @description Searches the whole value. A value of at most `CARD_SEARCH_PIECE_LENGTH` characters is searched in
		 * one go. A longer value is searched in pieces of that length. Each piece starts `CARD_SEARCH_PIECE_OVERLAP`
		 * characters before the end of the piece before it, and the last piece ends at the end of the value.
		 */
		private void searchWholeValue()
		{
			Integer inputLength = input.length();

			if(inputLength <= CARD_SEARCH_PIECE_LENGTH)
			{
				searchPiece(cardPattern.matcher(input), 0, inputLength);
				return;
			}

			Integer pieceStart = 0;
			Integer pieceEnd = 0;

			while(pieceEnd < inputLength)
			{
				pieceEnd = Math.min(pieceStart + CARD_SEARCH_PIECE_LENGTH, inputLength);
				searchPiece(cardPattern.matcher(input.substring(pieceStart, pieceEnd)), pieceStart, pieceEnd);
				pieceStart = pieceEnd - CARD_SEARCH_PIECE_OVERLAP;
			}
		}

		/**
		 * @description Searches one piece of the value, from `resumeAt` on, and keeps the numbers it finds.
		 *
		 * The end of a piece is not the end of the value. A number found near the end of a piece can be cut short, or can
		 * be found only because the text after it is missing. The matcher says so: `hitEnd()` is true when the search
		 * looked at the end of the piece. Such a number, when it starts in the part the next piece also holds, is left
		 * for the next piece, which holds the text after it.
		 *
		 * A piece searched as text of its own cannot see the character just before it. So the next piece starts its
		 * search one character into its first part, except when this piece already found a number that starts exactly
		 * where the next piece starts. In that case the start of that number is known to be right.
		 *
		 * @param matcher A matcher over the piece only
		 * @param pieceStart Where the piece starts in the value
		 * @param pieceEnd Where the piece ends in the value (the place just after its last character)
		 */
		private void searchPiece(Matcher matcher, Integer pieceStart, Integer pieceEnd)
		{
			Boolean isLastPiece = pieceEnd == input.length();
			Integer nextPieceStart = pieceEnd - CARD_SEARCH_PIECE_OVERLAP;
			Boolean isFound = matcher.find(resumeAt - pieceStart);

			while(isFound)
			{
				Integer numberStart = pieceStart + matcher.start();

				if(!isLastPiece && numberStart >= nextPieceStart && matcher.hitEnd())
				{
					resumeAt = numberStart == nextPieceStart ? nextPieceStart : Math.max(resumeAt, nextPieceStart + 1);
					return;
				}

				Integer numberEnd = pieceStart + matcher.end();
				addCandidate(matcher, numberStart, numberEnd);
				resumeAt = numberEnd;
				isFound = matcher.find();
			}

			if(!isLastPiece)
			{
				resumeAt = Math.max(resumeAt, nextPieceStart + 1);
			}
		}

		/**
		 * @description Counts one number the pattern found and keeps it for replacement when it is past the checking limit
		 * or passes the Luhn check. The text of the number is read only when it is checked.
		 *
		 * @param matcher The matcher positioned on the number
		 * @param numberStart Where the number starts in the value
		 * @param numberEnd Where the number ends in the value
		 */
		private void addCandidate(Matcher matcher, Integer numberStart, Integer numberEnd)
		{
			candidateCount++;

			if(candidateCount > LUHN_CANDIDATE_BUDGET || isValidCardNumber(matcher.group()))
			{
				numberStarts.add(numberStart);
				numberEnds.add(numberEnd);
			}
		}

		/**
		 * @description Builds the value again with the kept numbers replaced: the text between them is copied and the
		 * replacement is written in place of each one.
		 *
		 * @param replacement The text written in place of each kept number
		 *
		 * @return The masked value, or the value itself when no number was kept
		 */
		private String buildMaskedValue(String replacement)
		{
			if(numberStarts.isEmpty())
			{
				return input;
			}

			List<String> parts = new List<String>();
			Integer copiedUpTo = 0;

			for(Integer index = 0; index < numberStarts.size(); index++)
			{
				parts.add(input.substring(copiedUpTo, numberStarts[index]));
				parts.add(replacement);
				copiedUpTo = numberEnds[index];
			}

			parts.add(input.substring(copiedUpTo));
			return String.join(parts, EMPTY);
		}
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
	 * @description Answers whether the given regex can be compiled. A pattern that compiles is kept
	 * for the rest of the transaction, so later use is fast. A pattern that fails is not kept.
	 * This method never throws.
	 *
	 * @param regex The regex pattern
	 * @param caseSensitive When false, the pattern is wrapped with `(?i)`
	 *
	 * @return True when the pattern compiles, false when it does not
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	public static Boolean canCompilePattern(String regex, Boolean caseSensitive)
	{
		try
		{
			return getCompiledPattern(regex, caseSensitive) != null;
		}
		catch(Exception compileError)
		{
			return false;
		}
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
	 * @return The input with matching values redacted; unchanged if no keys match. See the four-argument
	 * `maskJsonKeys` for a value that is not JSON.
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
	 * @description Redacts values stored under JSON keys matching the supplied regex. The masking engine takes the same
	 * steps for a JsonKey rule, with one exception: in a synchronous transaction, the engine sends a value longer than
	 * `UTIL_FrameworkMasker.SYNCHRONOUS_JSON_TEXT_PASS_LINE` straight to the text search (see `maskJsonKeysViaRegex`),
	 * and this method does not. For every other value, this method and the engine give the same result. The steps:
	 * - A value that does not start with `{` and end with `}`, or start with `[` and end with `]`, is not a JSON
	 *   object or list. It goes to a text search for `"key":"value"` pairs (see `hasJsonObjectOrArrayShape`).
	 * - A value in which no key name of the pattern can appear is returned as it is, without reading it as JSON
	 *   (see `canHoldMatchingJsonKey`).
	 * - A value with at most `JSON_STRUCTURE_LINE` opening brackets is read as a whole tree and walked. The walk
	 *   stops 50 levels deep.
	 * - A value with more opening brackets is read one token at a time (see `maskJsonKeysStreaming`), at any
	 *   depth.
	 * - A value that the JSON reader refuses goes to the text search.
	 * When no key matched, the method returns the input string itself, byte for byte. The text search replaces every
	 * plain value under a matching key: a text, a number, `true`, `false` or `null`. When a matching key holds a value
	 * it cannot hide safely, such as an object or a text with no closing quote, the method returns
	 * `UTIL_FrameworkMasker.FAILURE_MARKER` in place of the whole value (see `maskJsonKeysViaRegex`).
	 *
	 * @param input The JSON string to mask
	 * @param keyRegex Regex matched against each JSON key
	 * @param replacement The literal string written in place of matching values
	 * @param caseSensitive When false, the key regex is wrapped with `(?i)`
	 *
	 * @return The input with matching values redacted, `UTIL_FrameworkMasker.FAILURE_MARKER` when the text search meets a
	 * value it cannot hide safely, or the input itself when no key matched; the marker is also written when the search reads a
	 * pair again from a quote (see `JsonTextSearch.readPairAt`), reaches `JSON_TEXT_PAIR_READ_LENGTH` characters before the pair
	 * ends, and more of the value follows; such a quote need not start a secret
	 *
	 * @throws IllegalArgumentException When the value goes to the text search and the key pattern is blank
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	public static String maskJsonKeys(String input, String keyRegex, String replacement, Boolean caseSensitive)
	{
		if(String.isEmpty(input))
		{
			return input;
		}

		if(!hasJsonObjectOrArrayShape(input))
		{
			return maskJsonKeysViaRegex(input, keyRegex, replacement, caseSensitive);
		}

		if(!canHoldMatchingJsonKey(input, keyRegex))
		{
			return input;
		}

		try
		{
			if(exceedsJsonStructureLine(input))
			{
				return maskJsonKeysStreaming(input, keyRegex, replacement, caseSensitive).maskedText;
			}

			JsonKeyMaskResult masked = applyJsonKeyRuleToTreeWithCount(JSON.deserializeUntyped(input), keyRegex, replacement, caseSensitive);
			return masked.mutated ? JSON.serialize(masked.tree) : input;
		}
		catch(System.JSONException parseError)
		{
			return maskJsonKeysViaRegex(input, keyRegex, replacement, caseSensitive);
		}
	}

	/**
	 * @description Checks whether a value has the outline of a JSON object or list: after spaces and line breaks at both
	 * ends are removed, it starts with `{` and ends with `}`, or starts with `[` and ends with `]`. A value without this
	 * outline cannot be a JSON object or list, so the JsonKey masking does not try to read it as JSON. A value with the
	 * outline can still be broken inside; the JSON reader finds that. A value that starts like JSON but has more text after
	 * its last brace, such as `{"token":"a"} and more`, has no outline either and goes to the text search. The text
	 * search keeps it safe: it masks every plain value under a secret key, and puts the failure marker in place of the
	 * whole value when an object or list follows a secret key.
	 *
	 * @param input The value to check
	 *
	 * @return True when the value starts and ends like a JSON object or a JSON list
	 */
	public static Boolean hasJsonObjectOrArrayShape(String input)
	{
		String trimmed = input?.trim() ?? EMPTY;
		return (trimmed.startsWith('{') && trimmed.endsWith('}')) || (trimmed.startsWith('[') && trimmed.endsWith(']'));
	}

	/**
	 * @description Checks whether a JSON value holds more opening brackets (`{` and `[` added together) than
	 * `JSON_STRUCTURE_LINE`. Such a value is read one token at a time by `maskJsonKeysStreaming` instead of as a
	 * whole tree. Brackets inside strings are counted too: that can only send a value to the token reader, which reads
	 * every valid JSON value correctly.
	 *
	 * @param input The JSON value to check
	 *
	 * @return True when the value holds more opening brackets than `JSON_STRUCTURE_LINE`; false for a null value
	 */
	public static Boolean exceedsJsonStructureLine(String input)
	{
		return input != null && input.countMatches('{') + input.countMatches('[') > JSON_STRUCTURE_LINE;
	}

	/**
	 * @description Checks, without reading the value as JSON, whether a JSON value can hold a key name that the key
	 * pattern matches. It returns false only when that is certain, and then the JsonKey rule can skip the value.
	 *
	 * Why the answer false is safe: in a JSON text without a backslash, every key name is written exactly as it
	 * reads, between quotes. So when the pattern matches a key name, the same pattern without its `^` at the start and `$`
	 * at the end finds that name in the raw text. The search ignores upper and lower case, so it finds every name a
	 * rule that cares about case would match too.
	 *
	 * It returns true, so the rule runs, in these cases:
	 * - The text holds a backslash. A key name can then be written with an escape, for example `password` with
	 *   its letter a written as a backslash, the letter u and the hexadecimal digits 0061. The raw text then does not show
	 *   the name as it reads.
	 * - The pattern holds another `^` or `$`, a backslash anchor or word boundary, or a look-ahead or look-behind
	 *   group (see `KEY_SEARCH_UNSAFE_PARTS`). Such a pattern can match a key name alone and fail on it inside the
	 *   text.
	 * - The pattern holds a repeat with no upper limit (`*`, `+` or `{n,}`). Searching for it over a long text can
	 *   take so many steps that the transaction ends.
	 * - The pattern holds a repeat with an upper count of three digits or more. The check does not work out how many
	 *   steps such a repeat can take, so it treats it as unsafe too.
	 * - The pattern is blank, or without its `^` and `$` does not compile. The rule then runs and reports its own
	 *   failure.
	 * - The search finds a match.
	 *
	 * The search runs over pieces of `KEY_SEARCH_PIECE_LENGTH` characters, because one search over a whole long value
	 * can end the transaction. Two pieces in a row share `KEY_SEARCH_PIECE_OVERLAP` characters, so a key name that crosses
	 * the end of one piece lies whole inside the next one. This holds for every key name up to that length.
	 *
	 * @param input The JSON value to search
	 * @param keyRegex The key pattern of the rule, usually anchored with `^` and `$`
	 *
	 * @return False when no key name the pattern matches can be in the value, and for a null value; true otherwise
	 */
	public static Boolean canHoldMatchingJsonKey(String input, String keyRegex)
	{
		if(input == null)
		{
			return false;
		}

		if(String.isBlank(keyRegex))
		{
			return true;
		}

		String keyNamePattern = keyRegex.removeStart('^').removeEnd('$');

		if(input.contains(JSON_ESCAPE_START) || KEY_SEARCH_UNSAFE_PARTS.matcher(keyNamePattern).find())
		{
			return true;
		}

		Pattern keyNameSearch;

		try
		{
			keyNameSearch = getCompiledPattern(keyNamePattern, false);
		}
		catch(Exception compileError)
		{
			return true;
		}

		Integer start = 0;
		Integer finish = 0;

		while(finish < input.length())
		{
			finish = Math.min(start + KEY_SEARCH_PIECE_LENGTH, input.length());

			if(keyNameSearch.matcher(input).region(start, finish).find())
			{
				return true;
			}

			start = finish - KEY_SEARCH_PIECE_OVERLAP;
		}

		return false;
	}

	/**
	 * @description Redacts values stored under JSON keys matching the pattern, reading the JSON text one token at a time
	 * instead of as a whole tree. The reader and the writer keep no nesting of their own, so a value nested thousands of
	 * levels deep is read to the end, and a key is found at any depth.
	 * - Every token is copied to the output as it comes, except the value of a key the pattern matches.
	 * - That value is replaced by the replacement, whatever it is: a text, a number, true, false, null, or a whole
	 *   object or list with everything in it. A null replacement is written as JSON null.
	 * - Keys keep their order, and a key written twice stays twice; each copy is checked.
	 * - Numbers are written again from their value: `1.00` stays `1.00`, but `1e5` is written as `1E+5`, the same
	 *   number.
	 * When no key matched, `maskedText` is the input string itself, byte for byte. To apply several rules to one value,
	 * call this once per rule, in rule order, each time on the output of the call before.
	 *
	 * @param input The JSON text to mask
	 * @param keyRegex Regex matched against each JSON key
	 * @param replacement The literal string written in place of matching values
	 * @param caseSensitive When false, the key regex is wrapped with `(?i)`
	 *
	 * @return A `JsonKeyMaskResult` with `maskedText`, `mutated` and `replacementCount` set; `tree` stays null
	 *
	 * @throws System.JSONException When the text is not valid JSON. Nothing is returned then, so the caller decides what
	 * to do with the value.
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters,PMD.ExcessiveParameterList')
	public static JsonKeyMaskResult maskJsonKeysStreaming(String input, String keyRegex, String replacement, Boolean caseSensitive)
	{
		JsonKeyMaskResult result = new JsonKeyMaskResult();
		result.maskedText = input;

		if(String.isEmpty(input))
		{
			return result;
		}

		Pattern keyPattern = getCompiledPattern(keyRegex, caseSensitive);
		JSONParser parser = JSON.createParser(input);
		JSONGenerator generator = JSON.createGenerator(false);

		for(JSONToken token = parser.nextToken(); token != null; token = parser.nextToken())
		{
			copyJsonToken(token, parser, generator);

			if(token == JSONToken.FIELD_NAME && keyPattern.matcher(parser.getText()).matches())
			{
				writeReplacementForFieldValue(parser, generator, replacement);
				result.replacementCount++;
			}
		}

		if(result.replacementCount > 0)
		{
			result.mutated = true;
			result.maskedText = generator.getAsString();
		}

		return result;
	}

	/**
	 * @description Copies the token the reader is on to the writer. The reader gives no other kinds of token for JSON
	 * text than the ones copied here. A number is written again through a Decimal. A number too large for a Decimal, such
	 * as `1e9999999999`, makes the copy throw a TypeException, which is not a JSON error, so the masking records the rule
	 * as failed on that value.
	 *
	 * @param token The token the reader is on
	 * @param parser The JSON reader, used for the text of names, strings and numbers
	 * @param generator The JSON writer
	 */
	private static void copyJsonToken(JSONToken token, JSONParser parser, JSONGenerator generator)
	{
		switch on token
		{
			when START_OBJECT
			{
				generator.writeStartObject();
			}
			when END_OBJECT
			{
				generator.writeEndObject();
			}
			when START_ARRAY
			{
				generator.writeStartArray();
			}
			when END_ARRAY
			{
				generator.writeEndArray();
			}
			when FIELD_NAME
			{
				generator.writeFieldName(parser.getText());
			}
			when VALUE_STRING
			{
				generator.writeString(parser.getText());
			}
			when VALUE_NUMBER_INT, VALUE_NUMBER_FLOAT
			{
				generator.writeNumber(Decimal.valueOf(parser.getText()));
			}
			when VALUE_TRUE, VALUE_FALSE
			{
				generator.writeBoolean(token == JSONToken.VALUE_TRUE);
			}
			when VALUE_NULL
			{
				generator.writeNull();
			}
		}
	}

	/**
	 * @description Moves the reader past the value of the key it has just read, and writes the replacement in its place.
	 * When the value is an object or a list, the reader skips everything inside it, so nothing of the value is copied.
	 *
	 * @param parser The JSON reader, on the name of a key the pattern matched
	 * @param generator The JSON writer, which has just written that key name
	 * @param replacement The text written in place of the value; null writes JSON null
	 */
	private static void writeReplacementForFieldValue(JSONParser parser, JSONGenerator generator, String replacement)
	{
		JSONToken valueToken = parser.nextToken();

		if(valueToken == JSONToken.START_OBJECT || valueToken == JSONToken.START_ARRAY)
		{
			parser.skipChildren();
		}

		if(replacement == null)
		{
			generator.writeNull();
			return;
		}

		generator.writeString(replacement);
	}

	/**
	 * @description Result wrapper returned by `applyJsonKeyRuleToTreeWithCount` and `maskJsonKeysStreaming`. Callers get
	 * the (possibly mutated) tree or masked text, a boolean flag indicating whether any replacement happened,
	 * and a count of replacements performed. The flag lets callers see a change without writing the
	 * tree out with `JSON.serialize` and comparing the text, which costs time on every record.
	 */
	public class JsonKeyMaskResult
	{
		/**
		 * @description The same tree reference passed in, with values under matching keys replaced. Set by
		 * `applyJsonKeyRuleToTreeWithCount`; `maskJsonKeysStreaming` leaves it null.
		 */
		public Object tree;

		/**
		 * @description The masked JSON text. Set by `maskJsonKeysStreaming`: the input string itself when no key matched.
		 * `applyJsonKeyRuleToTreeWithCount` leaves it null.
		 */
		public String maskedText;

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
	 * when batching multiple JsonKey rules on the same parsed tree: the mutation flag lets
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
	 * Stops descending a branch when depth exceeds `JSON_WALK_MAX_DEPTH`, so a key deeper than that
	 * is not masked by the walk.
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
	 * @description The text search that `maskJsonKeys` uses for a value that does not have the outline of a JSON object
	 * or list, or that the JSON reader refuses. It looks for a key in quotes that the key pattern matches, then a colon,
	 * then the value. Spaces and line breaks are allowed on both sides of the colon. For each matching key, one of two
	 * things happens:
	 * - The value is one whole JSON text, number, `true`, `false` or `null`, followed by a comma, a closing brace or
	 *   bracket, a space or the end of the value. The value is replaced by the replacement, written in quotes. A
	 *   text can hold escaped quotes, such as `"ab\"cd"`, and is replaced whole.
	 * - The value is anything else: an object, a list, a text with no closing quote, or a word without quotes such
	 *   as `hunter2`. The search cannot tell where such a value ends, so it cannot hide it safely. The method then
	 *   returns `UTIL_FrameworkMasker.FAILURE_MARKER` in place of the whole input, and the masking saves the marker
	 *   instead of the value.
	 * A key written with JSON escapes, such as `pass\"word` for `pass"word`, or `password` with its letter a written as
	 * a backslash, the letter u and the hexadecimal digits 0061, is read as JSON reads it, and the key pattern is checked
	 * against the name it stands for. A key with a backslash that JSON cannot read has no name to check, so the method
	 * returns `UTIL_FrameworkMasker.FAILURE_MARKER` in place of the whole input. When no key matches, the method returns
	 * the input itself. Text that only looks like a key, written with escaped quotes inside an ordinary text, is not read
	 * as a key. The search reads the value in pieces, so a long value cannot end the transaction (see `JsonTextSearch`).
	 * The masking engine also calls this method directly for a JSON value longer than
	 * `UTIL_FrameworkMasker.SYNCHRONOUS_JSON_TEXT_PASS_LINE` in a synchronous transaction, because this search is much
	 * quicker than reading the value as JSON.
	 *
	 * Some key patterns are not safe for this search (see `KEY_SEARCH_UNSAFE_PARTS`). The main case is a repeat with
	 * no upper limit, such as `.*secret.*`. The search tries the pattern at every quote in the text, and such a pattern
	 * then reads to the end of the line each time. On a text full of quotes this ends the transaction with an error that
	 * no code can catch, already at about 1,000 characters. So the method does not search with such a pattern. A repeat
	 * with an upper count of three digits or more, such as `^x_[a-z0-9]{1,100}$`, is treated the same way, because the
	 * check does not work out how many steps it can take. A value that holds a quote, and so could hold a key, gets
	 * `UTIL_FrameworkMasker.FAILURE_MARKER` in place of the whole value. Nothing secret is saved, and the marker shows the admin that the rule needs a narrower pattern, such as
	 * `^(secret|client_secret)$`. A value without a quote is returned as it is.
	 *
	 * @param input The value to search
	 * @param keyRegex The key pattern of the rule, usually anchored with `^` and `$`
	 * @param replacement The text written in place of each matched value; null is written as an empty text
	 * @param caseSensitive When false, the key pattern is wrapped with `(?i)` so that case does not matter
	 *
	 * @return The input with every matched value replaced, `UTIL_FrameworkMasker.FAILURE_MARKER` when a matching key holds
	 * a value that cannot be replaced safely or the key pattern is not safe for the search, or the input itself when no
	 * key matched; the marker is also written when the search reads a pair again from a quote (see
	 * `JsonTextSearch.readPairAt`), reaches `JSON_TEXT_PAIR_READ_LENGTH` characters before the pair ends, and more of the value
	 * follows; such a quote need not start a secret
	 *
	 * @throws IllegalArgumentException When the key pattern is blank. The masking records the rule as failed.
	 *
	 * @example
	 * ```apex
	 * String masked = UTIL_String.maskJsonKeysViaRegex('{"token":"abc","items":[1,2]}', '^(token)$', '***', false);
	 * // masked: '{"token":"***","items":[1,2]}'
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	public static String maskJsonKeysViaRegex(String input, String keyRegex, String replacement, Boolean caseSensitive)
	{
		if(String.isBlank(keyRegex))
		{
			throw new IllegalArgumentException('The key pattern of the JSON key masking rule is blank, so the rule cannot find any key.');
		}

		if(KEY_SEARCH_UNSAFE_PARTS.matcher(keyRegex.removeStart('^').removeEnd('$')).find())
		{
			return input.contains(DOUBLE_QUOTE) ? UTIL_FrameworkMasker.FAILURE_MARKER : input;
		}

		JsonTextSearch search = new JsonTextSearch(input, keyRegex, caseSensitive);
		search.searchWholeValue();
		return search.buildMaskedValue(replacement);
	}

	/**
	 * @description Builds the pattern of the text search for `"key":"value"` pairs, or takes it from
	 * `compiledPatternCache`. The pattern reads, in order: the key in quotes, matched by the key pattern without its `^`
	 * and `$`, or a key written with JSON escapes in the named group `escapedKey` (see `JSON_TEXT_KEY_TEMPLATE`); spaces,
	 * the colon and more spaces; and then one of two named groups, `scalar` and `other` (see `JSON_TEXT_VALUE_PATTERN`). A
	 * group the key pattern has of its own comes before them, so `escapedKey` is always the third group from the end,
	 * `scalar` the one before the last group and `other` the last group.
	 *
	 * @param keyRegex The key pattern of the rule
	 * @param caseSensitive When false, the pattern is wrapped with `(?i)` so that case does not matter
	 *
	 * @return The compiled pattern
	 */
	private static Pattern getJsonTextSearchPattern(String keyRegex, Boolean caseSensitive)
	{
		String keyNamePattern = keyRegex.removeStart('^').removeEnd('$');
		String cacheKey = 'jsonTextSearch:' + (caseSensitive ? 'cs:' : 'ci:') + keyNamePattern;
		Pattern searchPattern = compiledPatternCache.get(cacheKey);

		if(searchPattern == null)
		{
			String flag = caseSensitive ? EMPTY : '(?i)';
			searchPattern = Pattern.compile(JSON_TEXT_KEY_TEMPLATE.replace('__FLAG__', flag).replace('__KEY__', keyNamePattern) + JSON_TEXT_VALUE_PATTERN);
			compiledPatternCache.put(cacheKey, searchPattern);
		}

		return searchPattern;
	}

	/**
	 * @description Finds the values that `maskJsonKeysViaRegex` replaces in one value, and keeps where each one starts and
	 * ends in the value. The value is rebuilt once, at the end.
	 *
	 * A value longer than `JSON_TEXT_SEARCH_PIECE_LENGTH` is searched in pieces. Each piece gets its own matcher, and
	 * each piece starts `JSON_TEXT_SEARCH_PIECE_OVERLAP` characters before the end of the piece before it. The end of a
	 * piece is not the end of the value, so a pair found at the end of a piece can be cut short. For such a pair, the
	 * search reads the key once more with a new matcher over the rest of the value, up to `JSON_TEXT_PAIR_READ_LENGTH`
	 * characters. That one try stays far below the length at which one match ends the transaction. When that read
	 * reaches its limit before the pair ends, and more of the value follows, the search cannot tell what the pair holds,
	 * so the whole value gets the failure marker.
	 */
	private inherited sharing class JsonTextSearch
	{
		/**
		 * @description The whole JSON text, as the caller gave it. It is never changed: it is searched for matching keys,
		 * and the masked text is built from it at the end, or it is returned as it is when no value is replaced.
		 */
		private final String input;

		/**
		 * @description The compiled pattern of the text search (see `getJsonTextSearchPattern`).
		 */
		private final Pattern searchPattern;

		/**
		 * @description The key pattern of the rule, as the rule holds it. A key written with JSON escapes is checked
		 * against it after the key is read (see `isEscapedKeyMatching`).
		 */
		private final String keyRegex;

		/**
		 * @description False when case does not matter to the key pattern.
		 */
		private final Boolean caseSensitive;

		/**
		 * @description For each key written with JSON escapes that the search has met, as written, whether the name it
		 * stands for matches the key pattern. A key repeated many times, as in a long list of objects, is read once.
		 */
		private final Map<String, Boolean> escapedKeyMatches = new Map<String, Boolean>();

		/**
		 * @description Where each value to replace starts in the whole value, in the order the values appear.
		 */
		private final List<Integer> valueStarts = new List<Integer>();

		/**
		 * @description Where each value to replace ends in the whole value (the place just after its last character), in
		 * the same order as `valueStarts`.
		 */
		private final List<Integer> valueEnds = new List<Integer>();

		/**
		 * @description The place in the value where the next search starts. Every place before it is decided: either it
		 * belongs to a pair already found, or no pair starts there.
		 */
		private Integer resumeAt = 0;

		/**
		 * @description True once a matching key holds a value that cannot be replaced safely. The search then stops, and
		 * the whole value gets the failure marker.
		 */
		private Boolean hasUnboundedValue = false;

		/**
		 * @description Prepares a search of one value.
		 *
		 * @param input The value to search
		 * @param keyRegex The key pattern of the rule
		 * @param caseSensitive When false, case does not matter to the key pattern
		 */
		private JsonTextSearch(String input, String keyRegex, Boolean caseSensitive)
		{
			this.input = input;
			this.keyRegex = keyRegex;
			this.caseSensitive = caseSensitive;
			searchPattern = getJsonTextSearchPattern(keyRegex, caseSensitive);
		}

		/**
		 * @description Searches the whole value. A value of at most `JSON_TEXT_SEARCH_PIECE_LENGTH` characters is searched
		 * in one go. A longer value is searched in pieces of that length. Each piece starts `JSON_TEXT_SEARCH_PIECE_OVERLAP`
		 * characters before the end of the piece before it, or after the last replaced value when that is later.
		 */
		private void searchWholeValue()
		{
			Integer inputLength = input.length();

			if(inputLength <= JSON_TEXT_SEARCH_PIECE_LENGTH)
			{
				searchPiece(input, 0);
				return;
			}

			Integer pieceStart = 0;
			Integer pieceEnd = 0;

			while(pieceEnd < inputLength && !hasUnboundedValue)
			{
				pieceEnd = Math.min(pieceStart + JSON_TEXT_SEARCH_PIECE_LENGTH, inputLength);
				searchPiece(input.substring(pieceStart, pieceEnd), pieceStart);
				pieceStart = Math.min(Math.max(pieceEnd - JSON_TEXT_SEARCH_PIECE_OVERLAP, resumeAt), inputLength);
			}
		}

		/**
		 * @description Searches one piece of the value, from `resumeAt` on, and keeps the pairs it finds.
		 *
		 * The matcher says when a pair it found may be cut short: `hitEnd()` is true when the search looked at the end
		 * of the piece. In a piece that is not the last one, such a pair is read again over the whole rest of the value
		 * (see `readPairAt`). After the search, a piece that is not the last one is also checked for a key whose spaces
		 * run past its end (see `readKeyBeforeSpacesAtPieceEnd`).
		 *
		 * The matcher reads the whole value, limited to the piece. A look-behind or look-ahead in the pattern still sees
		 * the text outside the piece. So it sees the character before the piece: a quote at the start of the piece that
		 * follows a backslash is not read as the start of a key. And the check after a value sees the real next character,
		 * even when it lies after the end of the piece. A match itself never runs past the end of the piece, and a `$` in
		 * the pattern matches there, so a pair cut at the end of the piece is read again as said above.
		 *
		 * @param piece The text of the piece
		 * @param pieceStart Where the piece starts in the value
		 */
		private void searchPiece(String piece, Integer pieceStart)
		{
			Integer pieceEnd = pieceStart + piece.length();
			Boolean isLastPiece = pieceEnd == input.length();
			Matcher matcher = searchPattern.matcher(input).useTransparentBounds(true).useAnchoringBounds(true);

			while(!hasUnboundedValue && resumeAt < pieceEnd && matcher.region(Math.max(resumeAt, pieceStart), pieceEnd).find())
			{
				if(isLastPiece || !matcher.hitEnd())
				{
					keepPair(matcher, 0);
				}
				else
				{
					Integer keyStart = matcher.start();
					resumeAt = keyStart + 1;
					readPairAt(keyStart);
				}
			}

			if(!hasUnboundedValue && !isLastPiece)
			{
				readKeyBeforeSpacesAtPieceEnd(piece, pieceStart);
			}
		}

		/**
		 * @description Reads the pair that starts at one place, with a new matcher over the rest of the value, and keeps
		 * or marks it (see `keepPair`). The matcher tries this one place only. It reads at most
		 * `JSON_TEXT_PAIR_READ_LENGTH` characters, so one match cannot end the transaction, and a text value with no
		 * closing quote inside them is read as a value that cannot be hidden safely. The matcher still sees the character
		 * after what it reads, and treats only the real end of the value as its end.
		 *
		 * Nothing changes when the read fails before the end of what it may read, or when it reaches the real end of the
		 * value. The whole value gets the failure marker when the read reaches the end of what it may read and more of the
		 * value follows, for example when the spaces around the colon of a key are longer than the read: the search cannot
		 * tell what the text holds, as for a text value with no closing quote.
		 *
		 * @param keyStart Where the key starts in the value: the place of its opening quote
		 */
		private void readPairAt(Integer keyStart)
		{
			Integer readEnd = Math.min(keyStart + JSON_TEXT_PAIR_READ_LENGTH, input.length());
			Matcher pairMatcher = searchPattern.matcher(input).useTransparentBounds(true).useAnchoringBounds(false).region(keyStart, readEnd);

			if(pairMatcher.lookingAt())
			{
				keepPair(pairMatcher, 0);
			}
			else if(pairMatcher.hitEnd() && readEnd < input.length())
			{
				hasUnboundedValue = true;
			}
		}

		/**
		 * @description Keeps the value of a pair the matcher found, or marks the whole value when the pair holds a value
		 * that cannot be replaced safely (the `other` group, the last group of the pattern). A pair whose key is written
		 * with JSON escapes (the `escapedKey` group, the third group from the end) is kept only when the name the key
		 * stands for matches the key pattern. Otherwise it is passed over, and the search goes on from the place just
		 * after the opening quote of the key.
		 *
		 * @param matcher The matcher positioned on the pair
		 * @param offset Where the text the matcher reads starts in the value
		 */
		private void keepPair(Matcher matcher, Integer offset)
		{
			Integer scalarGroup = matcher.groupCount() - 1;
			Integer escapedKeyGroup = scalarGroup - 1;

			if(matcher.start(escapedKeyGroup) != -1 && !isEscapedKeyMatching(matcher.group(escapedKeyGroup)))
			{
				resumeAt = Math.max(resumeAt, offset + matcher.start() + 1);
				return;
			}

			if(hasUnboundedValue || matcher.start(scalarGroup) == -1)
			{
				hasUnboundedValue = true;
				return;
			}

			valueStarts.add(offset + matcher.start(scalarGroup));
			valueEnds.add(offset + matcher.end(scalarGroup));
			resumeAt = offset + matcher.end();
		}

		/**
		 * @description Checks whether a key written with JSON escapes stands for a name that the key pattern matches. The
		 * key is read as JSON reads a text: for example a backslash, the letter u and the hexadecimal digits 0061 read as the
		 * letter a, and `pass\"word` reads `pass"word`. The key pattern is then checked against the whole name, as when
		 * the value is read as JSON. A key that JSON cannot read, such as one with a backslash before the letter e, has
		 * no name to check. The search cannot rule out that it is secret, so the whole value gets the failure marker,
		 * and the method returns true.
		 *
		 * @param escapedKey The key as it is written, without its quotes
		 *
		 * @return True when the name the key stands for matches the key pattern, or when the key cannot be read
		 */
		private Boolean isEscapedKeyMatching(String escapedKey)
		{
			if(!escapedKeyMatches.containsKey(escapedKey))
			{
				Boolean isMatching = true;

				try
				{
					String keyName = (String)JSON.deserialize(DOUBLE_QUOTE + escapedKey + DOUBLE_QUOTE, String.class);
					isMatching = getCompiledPattern(keyRegex, caseSensitive).matcher(keyName).matches();
				}
				catch(System.JSONException unreadableKey)
				{
					hasUnboundedValue = true;
				}

				escapedKeyMatches.put(escapedKey, isMatching);
			}

			return escapedKeyMatches.get(escapedKey);
		}

		/**
		 * @description Finds a pair that the search of a piece cannot see because the spaces after its key run past the end
		 * of the piece. The next piece starts `JSON_TEXT_SEARCH_PIECE_OVERLAP` characters before the end of this one, so
		 * it does not see a key that starts before that.
		 *
		 * Such a key ends just before a run of spaces, line breaks and colons that reaches the end of the piece. So the
		 * run is found first, reading the piece backwards. Then each quote just before the run, in a stretch of
		 * `JSON_TEXT_SEARCH_PIECE_OVERLAP` characters, is tried as the start of a pair (see `readPairAt`).
		 *
		 * @param piece The text of the piece
		 * @param pieceStart Where the piece starts in the value
		 */
		private void readKeyBeforeSpacesAtPieceEnd(String piece, Integer pieceStart)
		{
			Matcher spaces = SPACES_AND_COLONS.matcher(piece.reverse());
			spaces.lookingAt();

			if(spaces.end() == 0)
			{
				return;
			}

			Integer pieceEnd = pieceStart + piece.length();
			Integer keyEnd = pieceEnd - spaces.end() - 1;
			Integer lastCandidate = Math.min(keyEnd, pieceEnd - JSON_TEXT_SEARCH_PIECE_OVERLAP);
			Integer candidate = input.indexOf(DOUBLE_QUOTE, Math.max(resumeAt, keyEnd - JSON_TEXT_SEARCH_PIECE_OVERLAP));

			while(candidate != -1 && candidate < lastCandidate)
			{
				Integer keptBefore = valueStarts.size();
				readPairAt(candidate);

				if(hasUnboundedValue || valueStarts.size() > keptBefore)
				{
					return;
				}

				candidate = input.indexOf(DOUBLE_QUOTE, candidate + 1);
			}
		}

		/**
		 * @description Builds the value again with the kept values replaced: the text between them is copied, and the
		 * replacement, in quotes, is written in place of each one.
		 *
		 * @param replacement The text written in place of each kept value; null is written as an empty text
		 *
		 * @return `UTIL_FrameworkMasker.FAILURE_MARKER` when a value cannot be replaced safely, the value itself when no
		 * value was kept, or the masked value
		 */
		private String buildMaskedValue(String replacement)
		{
			if(hasUnboundedValue)
			{
				return UTIL_FrameworkMasker.FAILURE_MARKER;
			}

			if(valueStarts.isEmpty())
			{
				return input;
			}

			String quotedReplacement = DOUBLE_QUOTE + (replacement ?? EMPTY) + DOUBLE_QUOTE;
			List<String> parts = new List<String>();
			Integer copiedUpTo = 0;

			for(Integer index = 0; index < valueStarts.size(); index++)
			{
				parts.add(input.substring(copiedUpTo, valueStarts[index]));
				parts.add(quotedReplacement);
				copiedUpTo = valueEnds[index];
			}

			parts.add(input.substring(copiedUpTo));
			return String.join(parts, EMPTY);
		}
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
		 * @description Starts an empty builder. Items are joined with a comma and no prefix until setDelimiter or
		 * setItemPrefix changes that.
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
		 * @description Appends every value of the list, in list order, after the items already in the builder.
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
		 * // builder.toString() is '*Item1,*Item2'
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