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
 * @date February 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=true)
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
	 * @description A nineteen digit number that passes the Luhn check.
	 */
	private static final String VALID_NINETEEN_DIGITS = '4111111111111111110';

	/**
	 * @description A sixteen digit number whose last digit is wrong, so it fails the Luhn check.
	 */
	private static final String INVALID_LUHN_16 = '4111111111111112';

	/**
	 * @description A Luhn-valid 16-digit Mastercard test number.
	 */
	private static final String VALID_MC_16 = '5555555555554444';

	/**
	 * @description A Luhn-valid 19-digit UnionPay test number.
	 */
	private static final String VALID_UNION_PAY_19 = '6221260000000000001';

	/**
	 * @description A 16-digit run that does not pass Luhn: a representative transaction ID.
	 */
	private static final String INVALID_TRANSACTION_ID_16 = '1234567890123456';

	/**
	 * @description A 19-digit nanosecond timestamp. Not a card.
	 */
	private static final String TIMESTAMP_NANO_19 = '1776297919466123000';

	/**
	 * @description The fewest digits a card number may have.
	 */
	private static final Integer SHORTEST_CARD_DIGITS = 13;

	/**
	 * @description The most digits a card number may have.
	 */
	private static final Integer LONGEST_CARD_DIGITS = 19;

	/**
	 * @description A zero placed in front of a run of digits: it adds one digit without changing the Luhn sum.
	 */
	private static final String LEADING_ZERO = '0';

	/**
	 * @description Separator character used to render a sorted list of fruit names.
	 */
	private static final String FRUIT_SEPARATOR = ', ';

	/**
	 * @description Fruit names joined with FRUIT_SEPARATOR in ascending order.
	 */
	private static final String SORTED_FRUIT = 'apple, fig, pear';

	/**
	 * @description Fruit names joined with no separator in ascending order.
	 */
	private static final String SORTED_FRUIT_UNSEPARATED = 'applefigpear';

	/**
	 * @description Text of a pattern that compiles: one or more digits.
	 */
	private static final String COMPILABLE_PATTERN = '\\d+';

	/**
	 * @description Text of a pattern that can never compile: a group that is opened and never closed.
	 */
	private static final String BROKEN_PATTERN = '([bad';

	/**
	 * @description The pattern of the shipped rule that hides payment card numbers: 13 to 19 digits, with at most one space
	 * or hyphen between two digits.
	 */
	private static final String PAYMENT_CARD_PATTERN = '\\b\\d(?:[ -]?\\d){12,18}\\b';

	/**
	 * @description The text that takes the place of a hidden card number in these tests.
	 */
	private static final String CARD_REPLACEMENT = '[CARD_REDACTED]';

	/**
	 * @description A replacement much longer than a card number, to check the rebuilt text when the value grows.
	 */
	private static final String LONG_CARD_REPLACEMENT = '[A CARD NUMBER WAS HIDDEN IN THIS PLACE]';

	/**
	 * @description A replacement much shorter than a card number, to check the rebuilt text when the value shrinks.
	 */
	private static final String SHORT_CARD_REPLACEMENT = '#';

	/**
	 * @description What goes between two numbers in a list of numbers: a comma and a space. The card pattern does not take
	 * a comma as part of a number, so each number is found on its own.
	 */
	private static final String NUMBER_SEPARATOR = ', ';

	/**
	 * @description How many numbers past the checking limit the budget test adds.
	 */
	private static final Integer NUMBERS_PAST_THE_BUDGET = 10;

	/**
	 * @description How many digits of the card number that crosses the end of the first search piece sit before that end.
	 */
	private static final Integer DIGITS_BEFORE_THE_PIECE_END = 8;

	/**
	 * @description How many spaces sit between the two card numbers near the end of the first search piece.
	 */
	private static final Integer SPACES_BETWEEN_THE_EDGE_CARDS = 4;

	/**
	 * @description How many spaces follow the card number that crosses the end of the first search piece.
	 */
	private static final Integer SPACES_AFTER_THE_EDGE_CARD = 5000;

	/**
	 * @description A card number with a line break after its first four digits. The card pattern allows only a space or a
	 * hyphen between digits, so neither part is long enough to be found.
	 */
	private static final String CARD_SPLIT_BY_A_LINE_BREAK = '4111' + UTIL_String.LF + '1111 1111 1111';

	/**
	 * @description Ten digits that follow a card number with no separator, so the whole run is 26 digits long. That is too
	 * long for a card number, so the pattern does not find it.
	 */
	private static final String TEN_TRAILING_DIGITS = '0000000000';

	/**
	 * @description Five digits that follow a 15-digit card number with no separator, so the whole run is 20 digits long,
	 * one more than a card number may have.
	 */
	private static final String FIVE_TRAILING_DIGITS = '00000';

	/**
	 * @description A letter written directly after a card number. A letter joined to the digits means they are not a
	 * separate number, so the card pattern does not find them.
	 */
	private static final String LETTER_AFTER_THE_CARD = 'z';

	/**
	 * @description The shipped secret-keys rule. The tests read its key pattern and replacement from the rule, so they
	 * always test the pattern that ships.
	 */
	private static final MaskingRule__mdt SECRET_KEYS_RULE = MaskingRule__mdt.getInstance(SEL_MaskingRule.RULE_MASK_SECRET_KEYS);

	/**
	 * @description The key pattern of the shipped secret-keys rule: the key names whose values it hides.
	 */
	private static final String SECRET_KEY_PATTERN = SECRET_KEYS_RULE.Pattern__c;

	/**
	 * @description The replacement of the shipped secret-keys rule.
	 */
	private static final String SECRET_REPLACEMENT = SECRET_KEYS_RULE.Replacement__c;

	/**
	 * @description The secret value expected in a masked JSON text: the replacement as a JSON text.
	 */
	private static final String MASKED = '"' + SECRET_REPLACEMENT + '"';

	/**
	 * @description One level of a deep JSON nest: an object whose only key holds the next level.
	 */
	private static final String NEST_LEVEL_OPENING = '{"a":';

	/**
	 * @description The closing brace of one level of a deep JSON nest.
	 */
	private static final String NEST_LEVEL_CLOSING = '}';

	/**
	 * @description A depth past the 50 levels at which the tree walk stops looking for keys.
	 */
	private static final Integer SIXTY_LEVELS = 60;

	/**
	 * @description A depth at which reading a whole JSON tree ends the transaction with an error no code can catch.
	 */
	private static final Integer TWO_THOUSAND_LEVELS = 2000;

	/**
	 * @description One empty JSON object followed by a comma, repeated to put a value above the structure line.
	 */
	private static final String EMPTY_OBJECT_IN_A_LIST = '{},';

	/**
	 * @description A short text written after a JSON-like value. With it, the value no longer ends like a JSON object or
	 * list, so `maskJsonKeys` sends it to the text search for `"key":"value"` pairs.
	 */
	private static final String TEXT_AFTER_THE_JSON = ' sent at step 2';

	/**
	 * @description The length of a very long secret text: far longer than one piece of the text search.
	 */
	private static final Integer LONG_SECRET_LENGTH = 120000;

	/**
	 * @description How many characters before the end of the first piece of the text search a secret key starts, in the
	 * tests where the key and its value cross the end of that piece. The key starts 100 characters before the stretch
	 * that the first piece shares with the next one, so the next piece does not hold the key.
	 */
	private static final Integer KEY_START_BEFORE_THE_PIECE_END = UTIL_String.JSON_TEXT_SEARCH_PIECE_OVERLAP + 100;

	/**
	 * @description How many spaces follow the secret key in the test where the spaces cross the end of the first piece of
	 * the text search.
	 */
	private static final Integer SPACES_ACROSS_THE_PIECE_END = KEY_START_BEFORE_THE_PIECE_END + 50;

	/**
	 * @description One ordinary `"key":"value"` pair followed by a comma, repeated to build a long text without a secret
	 * key.
	 */
	private static final String ORDINARY_PAIR = '"a":"b",';

	/**
	 * @description A key pattern with a repeat that has no upper limit on both sides of the key name.
	 */
	private static final String UNLIMITED_REPEAT_KEY_PATTERN = '.*secret.*';

	/**
	 * @description A JSON Web Token in the shape the shipped token rule finds: a header, a payload and a signature, joined
	 * by dots.
	 */
	private static final String WEB_TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4ifQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

	/**
	 * @description How many characters of the token lie before the end of the first search piece, in the test where the
	 * token crosses that end.
	 */
	private static final Integer TOKEN_CHARACTERS_BEFORE_THE_PIECE_END = 20;

	/**
	 * @description The length of a value that the pattern search of `maskWithRegex` reads in three pieces.
	 */
	private static final Integer THREE_PIECE_VALUE_LENGTH = 300000;

	/**
	 * @description The length of the longest value the masking reads: 2,000,000 characters.
	 */
	private static final Integer LONGEST_VALUE_LENGTH = 2000000;

	/**
	 * @description Ordinary text without a token: a digit and a space. It is the text that made one search over a long
	 * value stop at the platform limit.
	 */
	private static final String DIGIT_AND_SPACE = '1 ';

	/**
	 * @description A text with an email address and a web address that holds a user name and a password. The shipped
	 * email rule and the shipped web address rule both keep part of what they find, with the group reference `$1`.
	 */
	private static final String CONTACT_DETAILS = 'mail alice@example.com or open https://bob:hunter2@api.example.org/v1 now ';

	/**
	 * @description A character the shipped token rule counts as part of a token. A token right after it is not a token
	 * of its own.
	 */
	private static final String TOKEN_CHARACTER = 'x';

	/**
	 * @description A pattern with eleven groups, the last one named `tail`, after a few characters a group count must not
	 * count: an escaped bracket, a quoted bracket and a bracket inside a character class.
	 */
	private static final String ELEVEN_GROUP_PATTERN = '\\(\\Q(\\E[(](a)(b)(c)(d)(e)(f)(g)(h)(i)(j)(?<tail>k)';

	/**
	 * @description The text that `ELEVEN_GROUP_PATTERN` matches.
	 */
	private static final String ELEVEN_GROUP_TEXT = '(((abcdefghijk';

	/**
	 * @description A replacement that uses every kind of reference: a two-digit group number, a group number followed by
	 * a digit that is not part of it, an escaped dollar sign and a named group.
	 */
	private static final String EVERY_REFERENCE_REPLACEMENT = '<$10|$11|$12|\\$|${tail}>';

	/**
	 * @description A replacement that refers to a group the pattern does not have.
	 */
	private static final String MISSING_GROUP_REPLACEMENT = '[$9]';

	/**
	 * @description A pattern that finds a run of digits, as its group 1.
	 */
	private static final String DIGIT_RUN_PATTERN = '(\\d+)';

	/**
	 * @description A replacement that writes the run of digits `DIGIT_RUN_PATTERN` found, in angle brackets.
	 */
	private static final String DIGIT_RUN_REPLACEMENT = '<$1>';

	/**
	 * @description A pattern with one group, which finds the letter a.
	 */
	private static final String ONE_GROUP_PATTERN = '(a)';

	/**
	 * @description The length of a secret text longer than the text search for `"key":"value"` pairs can read in one
	 * try. A search over this many characters ends the transaction with a platform error that no code can catch.
	 */
	private static final Integer SECRET_PAST_THE_PAIR_READ_LENGTH = 1000010;

	/**
	 * @description A quote with a backslash before it. This is how a JSON text writes a quote inside itself, and the text
	 * search reads it as one escape.
	 */
	private static final String ESCAPED_QUOTE = '\\"';

	/**
	 * @description A letter followed by a quote with a backslash before it. A run of these costs the text search the most
	 * steps for each character: the letter and the escape are read one after the other.
	 */
	private static final String LETTER_AND_ESCAPED_QUOTE = 'a' + ESCAPED_QUOTE;

	/**
	 * @description How many escaped quotes a secret text holds in the test of a long run of them: 540,000 characters,
	 * longer than the text search reads in one try.
	 */
	private static final Integer ESCAPED_QUOTES_PAST_THE_PAIR_READ_LENGTH = 270000;

	/**
	 * @description How many letters a secret text holds in the test of a long run of plain letters: 540,000 characters,
	 * the same length as the run of escaped quotes.
	 */
	private static final Integer LETTERS_PAST_THE_PAIR_READ_LENGTH = 540000;

	/**
	 * @description How many times `LETTER_AND_ESCAPED_QUOTE` is repeated in a secret text of 300,000 characters. That is
	 * a little longer than the text search reads in one try, so the secret gets the failure marker.
	 */
	private static final Integer LETTER_AND_ESCAPED_QUOTE_REPEATS_PAST_THE_PAIR_READ_LENGTH = 100000;

	/**
	 * @description How many times `LETTER_AND_ESCAPED_QUOTE` is repeated in a secret text of 261,000 characters. The
	 * text, with its key and its closing quote, still fits in what the text search reads in one try, so the secret is
	 * replaced whole.
	 */
	private static final Integer LETTER_AND_ESCAPED_QUOTE_REPEATS_INSIDE_THE_PAIR_READ_LENGTH = 87000;

	/**
	 * @description A key pattern with two key names: `password`, and `pass"word`, a name with a quote inside it. In JSON
	 * text the quote inside a key is written with a backslash before it.
	 */
	private static final String ESCAPED_KEY_NAMES_PATTERN = '^(password|pass"word)$';

	/**
	 * @description JSON text whose keys are written with JSON escapes. A backslash, the letter u and four hexadecimal digits stand
	 * for one character: the hexadecimal digits 0061 for the letter a, 0041 for A and 0065 for e. So the keys read `password`,
	 * `PASSWORD` and `user`. A backslash before a quote stands for the quote: `pass\"word` reads `pass"word`.
	 */
	private static final String KEYS_WRITTEN_WITH_ESCAPES =
			'{"p\\u0061ssword":"hunter2","pass\\"word":"hunter3","us\\u0065r":"alice","P\\u0041SSWORD":"hunter4","p\\u0061ssword":"hunter5"}';

	/**
	 * @description The text of `KEYS_WRITTEN_WITH_ESCAPES` after the masking: each value under a key that reads as a
	 * secret key name is replaced, and every key is kept as it was written.
	 */
	private static final String KEYS_WRITTEN_WITH_ESCAPES_MASKED =
			'{"p\\u0061ssword":' + MASKED + ',"pass\\"word":' + MASKED + ',"us\\u0065r":"alice","P\\u0041SSWORD":' + MASKED + ',"p\\u0061ssword":' + MASKED + '}';

	/**
	 * @description A key pattern with one key name of twelve letters: `clientsecret`.
	 */
	private static final String LONG_KEY_NAME_PATTERN = '^clientsecret$';

	/**
	 * @description The key name `clientsecret` with every letter written as a JSON escape: a backslash, the letter u and
	 * four hexadecimal digits. Some programs write every letter outside plain English this way, so a key name in Japanese or
	 * Russian is written just as long. In quotes and with its colon, the key is 75 characters long.
	 */
	private static final String CLIENT_SECRET_WRITTEN_WITH_ESCAPES = '\\u0063\\u006c\\u0069\\u0065\\u006e\\u0074\\u0073\\u0065\\u0063\\u0072\\u0065\\u0074';

	/**
	 * @description How many characters of the key in quotes lie after the end of the first piece of the text search, in
	 * the test where a key written with escapes crosses that end. The key in quotes is 74 characters long, so it starts
	 * 70 characters before that end, inside the `UTIL_String.JSON_TEXT_SEARCH_PIECE_OVERLAP` characters that the next
	 * piece reads too.
	 */
	private static final Integer KEY_CHARACTERS_AFTER_THE_PIECE_END = 4;

	/**
	 * @description How many spaces sit between a secret key and its colon, or between the colon and the secret, in the
	 * tests of a very long run of spaces. The text search reads at most 262,144 characters from the start of a key in one
	 * try, so 270,000 spaces run past the end of what it reads.
	 */
	private static final Integer SPACES_PAST_THE_PAIR_READ_LENGTH = 270000;

	/**
	 * @description The secret text in the tests of a very long run of spaces around a colon.
	 */
	private static final String PASSWORD_VALUE = 'hunter2';

	/**
	 * @description The length of a value that ends in the spaces after a secret key, with no colon. It is a little longer
	 * than one piece of the text search, so the key and its spaces cross the end of the first piece, and the read of the
	 * pair reaches the real end of the value.
	 */
	private static final Integer VALUE_ENDING_IN_SPACES_LENGTH = 20000;

	/**
	 * @description A rule pattern with two alternatives that can overlap: a `secret=` pair up to its `&`, or any six
	 * digits in a row. The digits inside the pair are part of the longer first match.
	 */
	private static final String OVERLAPPING_ALTERNATIVES_PATTERN = 'secret=[^&]*&|[0-9]{6}';

	/**
	 * @description The first alternative of `OVERLAPPING_ALTERNATIVES_PATTERN` alone: a `secret=` pair up to its `&`.
	 */
	private static final String SINGLE_ALTERNATIVE_PATTERN = 'secret=[^&]*&';

	/**
	 * @description A pair that the first alternative of `OVERLAPPING_ALTERNATIVES_PATTERN` matches whole. It holds nine
	 * digits in a row, which the second alternative also matches.
	 */
	private static final String SECRET_PAIR = 'secret=abc123456789xyz&';

	/**
	 * @description The start of the secret in `SECRET_PAIR`. When it is left in the result, part of the pair was not hidden.
	 */
	private static final String SECRET_PAIR_START = 'abc';

	/**
	 * @description The text written in place of each match of the overlapping and single alternative patterns.
	 */
	private static final String PAIR_REPLACEMENT = '[X]';

	/**
	 * @description How many characters before the end of the first piece of the pattern search `SECRET_PAIR` starts. The
	 * piece end then cuts the pair after `secret=abc123456789x`, so a whole run of six digits lies inside the piece.
	 */
	private static final Integer PAIR_START_BEFORE_THE_PIECE_END = 20;

	/**
	 * @description How many characters follow the first piece of the pattern search in the test that moves `SECRET_PAIR`
	 * across the end of that piece. The value then takes two pieces and is short enough to search many times.
	 */
	private static final Integer CHARACTERS_AFTER_THE_FIRST_PIECE = 4000;

	/**
	 * @description The earliest place of `SECRET_PAIR`, counted in characters before the end of the first piece of the
	 * pattern search, in the test that moves the pair across that end.
	 */
	private static final Integer FIRST_PAIR_START_BEFORE_THE_PIECE_END = 40;

	/**
	 * @description The latest place of `SECRET_PAIR`, counted in characters after the end of the first piece of the
	 * pattern search, in the test that moves the pair across that end.
	 */
	private static final Integer LAST_PAIR_START_AFTER_THE_PIECE_END = 8;

	/**
	 * @description Six digits in a row, which the second alternative of `OVERLAPPING_ALTERNATIVES_PATTERN` matches whole.
	 * The test that moves `SECRET_PAIR` across the end of a piece writes them a little before the pair, so the search keeps
	 * a match in the shared part of two pieces before it reaches the pair.
	 */
	private static final String DIGIT_RUN = '000000';

	/**
	 * @description How many characters before the start of `SECRET_PAIR` the test writes `DIGIT_RUN`. The digits then lie
	 * in the shared part of the first two pieces at every place of the pair, with spaces between them and the pair.
	 */
	private static final Integer DIGIT_RUN_START_BEFORE_THE_PAIR = 100;

	/**
	 * @description How many characters of a result around `SECRET_PAIR` an assertion message shows, so a failed test
	 * says what was left in clear.
	 */
	private static final Integer MESSAGE_WINDOW_LENGTH = 40;

	/**
	 * @description A plain letter that fills the rest of a long value after a pair. It holds no quote, space or colon, so
	 * the text search finds nothing in it.
	 */
	private static final String FILLER_LETTER = 'n';

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
	 * @description Verifies that joinSorted renders a Set in ascending order whatever its insertion order,
	 * treats a null separator as empty, returns an empty string for an empty set and null for a null set.
	 */
	@IsTest
	private static void joinSortedRendersAscendingOrder()
	{
		Assert.isNull(UTIL_String.joinSorted(null, FRUIT_SEPARATOR), 'Null set should return null');
		Assert.areEqual(UTIL_String.EMPTY, UTIL_String.joinSorted(new Set<String>(), FRUIT_SEPARATOR), 'Empty set should return an empty string');
		Assert.areEqual(SORTED_FRUIT, UTIL_String.joinSorted(new Set<String> {'pear', 'apple', 'fig'}, FRUIT_SEPARATOR),
				'Members should render in ascending order whatever the insertion order');
		Assert.areEqual(SORTED_FRUIT_UNSEPARATED, UTIL_String.joinSorted(new Set<String> {'pear', 'apple', 'fig'}, null),
				'A null separator should join with nothing between members');
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
	 * @description A value of exactly `UTIL_String.PATTERN_SEARCH_PIECE_LENGTH` characters is searched in one go, and the
	 * result is the same text that one `replaceAll` over the whole value gives.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void shouldMaskAValueAtThePieceLengthAsOneSearchDoes()
	{
		String body = WEB_TOKEN + UTIL_String.SPACE + CONTACT_DETAILS;
		String value = body.repeat(UTIL_String.PATTERN_SEARCH_PIECE_LENGTH / body.length());
		value += UTIL_String.SPACE.repeat(UTIL_String.PATTERN_SEARCH_PIECE_LENGTH - value.length());

		String result = maskWithShippedRule(SEL_MaskingRule.RULE_MASK_JWT, value);

		Assert.areEqual(UTIL_String.PATTERN_SEARCH_PIECE_LENGTH, value.length(), 'Expected the value to be exactly one piece long');
		Assert.areEqual(replaceAllWithShippedRule(SEL_MaskingRule.RULE_MASK_JWT, value), result, 'Expected the same text as one search over the whole value');
	}

	/**
	 * @description A token that crosses the end of the first search piece of a long value is replaced once. Nothing of it
	 * is left in clear, and nothing around it is lost or written twice.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void shouldMaskATokenThatCrossesTheEndOfTheFirstPieceOnce()
	{
		MaskingRule__mdt tokenRule = MaskingRule__mdt.getInstance(SEL_MaskingRule.RULE_MASK_JWT);
		String before = UTIL_String.SPACE.repeat(UTIL_String.PATTERN_SEARCH_PIECE_LENGTH - TOKEN_CHARACTERS_BEFORE_THE_PIECE_END);
		String after = UTIL_String.SPACE.repeat(THREE_PIECE_VALUE_LENGTH - before.length() - WEB_TOKEN.length());

		String result = maskWithShippedRule(SEL_MaskingRule.RULE_MASK_JWT, before + WEB_TOKEN + after);

		Assert.areEqual(before + tokenRule.Replacement__c + after, result, 'Expected the token across the end of the piece replaced once');
	}

	/**
	 * @description A match that the end of the first search piece cuts short, and that starts in the part the next piece
	 * also holds, is left for the next piece, which sees the whole match. Its replacement then holds the whole number, as
	 * one search over the whole value gives.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void shouldFindAMatchCutByThePieceEndWholeInTheNextPiece()
	{
		String before = UTIL_String.SPACE.repeat(UTIL_String.PATTERN_SEARCH_PIECE_LENGTH - DIGITS_BEFORE_THE_PIECE_END);
		String after = UTIL_String.SPACE.repeat(THREE_PIECE_VALUE_LENGTH - before.length() - VALID_VISA_16.length());

		String result = UTIL_String.maskWithRegex(before + VALID_VISA_16 + after, DIGIT_RUN_PATTERN, DIGIT_RUN_REPLACEMENT, true);

		Assert.areEqual(before + '<' + VALID_VISA_16 + '>' + after, result, 'Expected the whole number in the replacement');
	}

	/**
	 * @description A rule has two alternatives that can overlap: a `secret=` pair up to its `&`, or six digits in a row.
	 * A pair starts 20 characters before the end of the first piece of a 300,000 character value, so the piece end cuts
	 * the pair, but six of its digits lie inside the piece. The whole pair is still replaced once, as one `replaceAll`
	 * over the whole value gives. Replacing only the digits would leave the start and the end of the pair in clear. One
	 * `replaceAll` over 300,000 characters stops at the platform limit for one search, so the test runs it over the pair
	 * alone: the spaces around the pair never match, so the result is the same.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void shouldMatchOneReplaceAllWhenACutMatchHidesAnEarlierStart()
	{
		Integer pairStart = UTIL_String.PATTERN_SEARCH_PIECE_LENGTH - PAIR_START_BEFORE_THE_PIECE_END;
		String value = buildValueWithSecretPairAt(pairStart, THREE_PIECE_VALUE_LENGTH);

		String result = UTIL_String.maskWithRegex(value, OVERLAPPING_ALTERNATIVES_PATTERN, PAIR_REPLACEMENT, true);

		Assert.isFalse(result.contains(SECRET_PAIR_START), 'Expected the whole pair hidden, found ' + result.mid(pairStart, MESSAGE_WINDOW_LENGTH));
		Assert.areEqual(value.replace(SECRET_PAIR, replaceAllWithOverlappingAlternatives(SECRET_PAIR)), result, 'Expected the same text as one replaceAll gives');
	}

	/**
	 * @description A pair that the overlapping alternatives rule matches is placed at every position from 40 characters
	 * before to 8 characters after the end of the first piece of the pattern search. The value is just long enough to take
	 * two pieces. At every position the result is the same text that one `replaceAll` over the whole value gives, so no
	 * part of the pair is left in clear wherever the piece end cuts it. Six digits 100 characters before the pair, in the
	 * part the two pieces share, are also replaced exactly once.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void shouldMatchOneReplaceAllAtEveryOffsetAroundAPieceEnd()
	{
		Integer valueLength = UTIL_String.PATTERN_SEARCH_PIECE_LENGTH + CHARACTERS_AFTER_THE_FIRST_PIECE;

		for(Integer offset = -FIRST_PAIR_START_BEFORE_THE_PIECE_END; offset <= LAST_PAIR_START_AFTER_THE_PIECE_END; offset++)
		{
			Integer pairStart = UTIL_String.PATTERN_SEARCH_PIECE_LENGTH + offset;
			Integer digitRunStart = pairStart - DIGIT_RUN_START_BEFORE_THE_PAIR;
			String pairValue = buildValueWithSecretPairAt(pairStart, valueLength);
			String value = pairValue.left(digitRunStart) + DIGIT_RUN + pairValue.substring(digitRunStart + DIGIT_RUN.length());

			String result = UTIL_String.maskWithRegex(value, OVERLAPPING_ALTERNATIVES_PATTERN, PAIR_REPLACEMENT, true);

			String position = ' with the pair ' + offset + ' characters from the piece end';
			Assert.isFalse(result.contains(SECRET_PAIR_START), 'Expected the whole pair hidden' + position + ', found ' + result.mid(pairStart, MESSAGE_WINDOW_LENGTH));
			Assert.areEqual(replaceAllWithOverlappingAlternatives(value), result, 'Expected the same text as one replaceAll' + position);
		}
	}

	/**
	 * @description A rule with one alternative, a `secret=` pair up to its `&`, is used on a pair that the end of the first
	 * piece of the pattern search cuts. The search of the first piece cannot finish the match, and the next piece finds it
	 * whole. The pair is replaced exactly once, as one `replaceAll` over the whole value gives.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void shouldMaskAMatchCutAtAPieceEndOnceWithASingleAlternative()
	{
		String value = buildValueWithSecretPairAt(UTIL_String.PATTERN_SEARCH_PIECE_LENGTH - PAIR_START_BEFORE_THE_PIECE_END, THREE_PIECE_VALUE_LENGTH);
		String expected = Pattern.compile(SINGLE_ALTERNATIVE_PATTERN).matcher(value).replaceAll(PAIR_REPLACEMENT);

		String result = UTIL_String.maskWithRegex(value, SINGLE_ALTERNATIVE_PATTERN, PAIR_REPLACEMENT, true);

		Assert.areEqual(1, result.countMatches(PAIR_REPLACEMENT), 'Expected the pair replaced exactly once');
		Assert.areEqual(expected, result, 'Expected the same text as one replaceAll over the whole value');
	}

	/**
	 * @description A text of 2,000,000 characters with a token at its start, in its middle and at its end has all three
	 * tokens replaced, and the masking finishes. One search over the whole text stops at the platform limit and ends the
	 * transaction.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void shouldMaskTokensAtTheStartMiddleAndEndOfALongestValue()
	{
		String replacement = MaskingRule__mdt.getInstance(SEL_MaskingRule.RULE_MASK_JWT).Replacement__c;
		Integer fillerLength = (LONGEST_VALUE_LENGTH - 3 * WEB_TOKEN.length() - 4) / 2;
		String filler = DIGIT_AND_SPACE.repeat(fillerLength / DIGIT_AND_SPACE.length());
		String value = WEB_TOKEN + UTIL_String.SPACE + filler + WEB_TOKEN + UTIL_String.SPACE + filler + WEB_TOKEN;
		value += UTIL_String.SPACE.repeat(LONGEST_VALUE_LENGTH - value.length());
		filler = null;

		String result = maskWithShippedRule(SEL_MaskingRule.RULE_MASK_JWT, value);

		Assert.areEqual(LONGEST_VALUE_LENGTH, value.length(), 'Expected the value to be 2,000,000 characters long');
		value = null;
		Assert.areEqual(3, result.countMatches(replacement), 'Expected the three tokens replaced');
		Assert.isFalse(result.contains(WEB_TOKEN.left(10)), 'Expected no token left in clear');
		Assert.areEqual(LONGEST_VALUE_LENGTH - 3 * (WEB_TOKEN.length() - replacement.length()), result.length(), 'Expected nothing else to change');
	}

	/**
	 * @description The shipped email rule and the shipped web address rule keep part of what they find with the group
	 * reference `$1`. On a long value, searched in pieces, the text they write is the same text `replaceAll` writes for
	 * the same details in a short value.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void shouldWriteGroupReferencesInALongValueAsOneSearchDoes()
	{
		String filler = UTIL_String.SPACE.repeat(UTIL_String.PATTERN_SEARCH_PIECE_LENGTH);

		for(String ruleName : new List<String> {SEL_MaskingRule.RULE_MASK_EMAIL, SEL_MaskingRule.RULE_MASK_URL_BASIC_AUTH})
		{
			String maskedDetails = replaceAllWithShippedRule(ruleName, CONTACT_DETAILS);

			String result = maskWithShippedRule(ruleName, CONTACT_DETAILS + filler + CONTACT_DETAILS + filler + CONTACT_DETAILS);

			Assert.areNotEqual(CONTACT_DETAILS, maskedDetails, 'Expected the rule ' + ruleName + ' to change the details');
			Assert.areEqual(maskedDetails + filler + maskedDetails + filler + maskedDetails, result, 'Expected the rule ' + ruleName + ' to write what one search writes');
		}
	}

	/**
	 * @description A long value, searched in pieces, gets the same text as `replaceAll` writes for every kind of reference
	 * in the replacement: a two-digit group number, a group number followed by a digit that is not part of it, an escaped
	 * dollar sign and a named group. The pattern also holds brackets that are not groups.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void shouldWriteEveryKindOfReferenceInALongValueAsOneSearchDoes()
	{
		String filler = UTIL_String.SPACE.repeat(UTIL_String.PATTERN_SEARCH_PIECE_LENGTH);
		String expected = Pattern.compile(ELEVEN_GROUP_PATTERN).matcher(ELEVEN_GROUP_TEXT).replaceAll(EVERY_REFERENCE_REPLACEMENT);

		String result = UTIL_String.maskWithRegex(ELEVEN_GROUP_TEXT + filler + ELEVEN_GROUP_TEXT, ELEVEN_GROUP_PATTERN, EVERY_REFERENCE_REPLACEMENT, true);

		Assert.areEqual('<j|k|a2|$|k>', expected, 'Expected replaceAll to write each reference');
		Assert.areEqual(expected + filler + expected, result, 'Expected the same text as replaceAll for each match');
	}

	/**
	 * @description A replacement that refers to a group the pattern does not have is refused on a long value in the same
	 * way `replaceAll` refuses it on a short one, with a `StringException`.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void shouldRefuseAMissingGroupInALongValueAsOneSearchDoes()
	{
		String longValue = 'a' + UTIL_String.SPACE.repeat(UTIL_String.PATTERN_SEARCH_PIECE_LENGTH);

		try
		{
			UTIL_String.maskWithRegex(longValue, ONE_GROUP_PATTERN, MISSING_GROUP_REPLACEMENT, true);
			Assert.fail('Expected a StringException for a group the pattern does not have');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, StringException.class, 'Expected the exception replaceAll throws');
		}
	}

	/**
	 * @description The shipped token rule does not take a token that follows a token character, such as `x`. When such a
	 * token starts exactly where a search piece of a long value starts, the search still sees the character before it,
	 * and leaves the token alone. A search that could not see that character would replace it.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void shouldNotTakeATokenAtThePieceStartAfterATokenCharacter()
	{
		Integer secondPieceStart = UTIL_String.PATTERN_SEARCH_PIECE_LENGTH - UTIL_String.PATTERN_SEARCH_PIECE_OVERLAP;
		String before = UTIL_String.SPACE.repeat(secondPieceStart - TOKEN_CHARACTER.length()) + TOKEN_CHARACTER;
		String value = before + WEB_TOKEN + UTIL_String.SPACE.repeat(THREE_PIECE_VALUE_LENGTH - before.length() - WEB_TOKEN.length());

		Assert.areEqual(value, maskWithShippedRule(SEL_MaskingRule.RULE_MASK_JWT, value), 'Expected the token joined to a token character to stay');
		Assert.areEqual(value, replaceAllWithShippedRule(SEL_MaskingRule.RULE_MASK_JWT, value), 'Expected one search over the whole value to leave it too');
	}

	/**
	 * @description The shipped free text rule replaces the whole value. On a long value, searched in pieces, the whole
	 * value is still replaced exactly once, not once for each piece.
	 *
	 * @see UTIL_String.maskWithRegex
	 */
	@IsTest
	private static void shouldReplaceALongValueOnceWithAWholeValueRule()
	{
		String replacement = MaskingRule__mdt.getInstance(SEL_MaskingRule.RULE_MASK_FREE_TEXT).Replacement__c;

		String result = maskWithShippedRule(SEL_MaskingRule.RULE_MASK_FREE_TEXT, DIGIT_AND_SPACE.repeat(THREE_PIECE_VALUE_LENGTH / DIGIT_AND_SPACE.length()));

		Assert.areEqual(replacement, result, 'Expected the whole value replaced once');
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

	/**
	 * @description A JSON payload that is only the literal null comes back unchanged from maskJsonKeys. It has no keys to
	 * mask, and the call must not fail on a payload that is neither an object nor a list.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
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
	 * its mutation flag clear and its replacement count at zero when no key matches: the
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
	 * levels, preventing a hidden undercount in batched rule telemetry.
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

	/**
	 * @description A secret key written twice in one object has both values replaced by the token reader. A whole-tree
	 * reader keeps only the last copy of a key, so the text is compared as text.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	private static void shouldMaskBothCopiesOfASecretKeyWrittenTwice()
	{
		UTIL_String.JsonKeyMaskResult result = streamWithSecretKeysRule('{"password":"first","user":"u","password":"second"}');

		Assert.areEqual('{"password":' + MASKED + ',"user":"u","password":' + MASKED + '}', result.maskedText, 'Expected both copies masked');
		Assert.areEqual(2, result.replacementCount, 'Expected two replacements');
	}

	/**
	 * @description Two secret keys that differ only in upper and lower case are both masked, and keep their own spelling.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	private static void shouldMaskSecretKeysWrittenTwiceInDifferentCase()
	{
		UTIL_String.JsonKeyMaskResult result = streamWithSecretKeysRule('{"Token":"first","user":"u","token":"second"}');

		Assert.areEqual('{"Token":' + MASKED + ',"user":"u","token":' + MASKED + '}', result.maskedText, 'Expected both keys masked');
	}

	/**
	 * @description A secret key name written with a Unicode escape is masked: here `password` has its letter a written
	 * as a backslash, the letter u and the hexadecimal digits 0061. The token reader decodes the key name before the pattern
	 * checks it.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldMaskASecretKeyWrittenWithAUnicodeEscape()
	{
		UTIL_String.JsonKeyMaskResult result = streamWithSecretKeysRule('{"p\\u0061ssword":"hunter2","name":"caf\\u00e9"}');

		assertSameJsonValue('{"password":' + MASKED + ',"name":"caf\\u00e9"}', result.maskedText);
	}

	/**
	 * @description A secret key name whose first letter is written as a Unicode escape is masked: here `token` has its
	 * letter t written as a backslash, the letter u and the hexadecimal digits 0074.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldMaskASecretKeyWrittenOnlyWithAnEscapedFirstLetter()
	{
		UTIL_String.JsonKeyMaskResult result = streamWithSecretKeysRule('{"\\u0074oken":"abc"}');

		assertSameJsonValue('{"token":' + MASKED + '}', result.maskedText);
	}

	/**
	 * @description Key names with other escapes (an escaped backslash, slash or quote) read as names that are not secret
	 * key names, and keep their values. Only the real secret key is masked.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	private static void shouldMaskOnlyTheSecretKeyAmongKeysWithOtherEscapes()
	{
		UTIL_String.JsonKeyMaskResult result = streamWithSecretKeysRule('{"to\\\\ken":"a","api\\/key":"b","pass\\"wd":"c","secret":"d"}');

		assertSameJsonValue('{"to\\\\ken":"a","api/key":"b","pass\\"wd":"c","secret":' + MASKED + '}', result.maskedText);
		Assert.areEqual(1, result.replacementCount, 'Expected only the secret key masked');
	}

	/**
	 * @description Quotes, brackets, braces and key-like text inside text values do not confuse the token reader: only
	 * the value under the real key named `token` is masked.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	private static void shouldIgnoreJsonSyntaxInsideTextValues()
	{
		String note = '"note":"say \\"hi\\" \\\\ [x] {y} \\"token\\":\\"z\\"","list":["]","{","\\"password\\":\\"p\\""]';

		UTIL_String.JsonKeyMaskResult result = streamWithSecretKeysRule('{' + note + ',"token":"t"}');

		assertSameJsonValue('{' + note + ',"token":' + MASKED + '}', result.maskedText);
		Assert.areEqual(1, result.replacementCount, 'Expected only the real token key masked');
	}

	/**
	 * @description A number under a secret key is replaced.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldReplaceANumberUnderASecretKey()
	{
		assertSameJsonValue('{"token":' + MASKED + ',"keep":1}', streamWithSecretKeysRule('{"token":12345,"keep":1}').maskedText);
	}

	/**
	 * @description The value true under a secret key is replaced.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldReplaceTrueUnderASecretKey()
	{
		assertSameJsonValue('{"secret":' + MASKED + ',"keep":1}', streamWithSecretKeysRule('{"secret":true,"keep":1}').maskedText);
	}

	/**
	 * @description The value false under a secret key is replaced.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldReplaceFalseUnderASecretKey()
	{
		assertSameJsonValue('{"password":' + MASKED + ',"keep":1}', streamWithSecretKeysRule('{"password":false,"keep":1}').maskedText);
	}

	/**
	 * @description The value null under a secret key is replaced.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldReplaceNullUnderASecretKey()
	{
		assertSameJsonValue('{"passwd":' + MASKED + ',"keep":1}', streamWithSecretKeysRule('{"passwd":null,"keep":1}').maskedText);
	}

	/**
	 * @description A whole list under a secret key, with the objects and lists inside it, is replaced.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldReplaceAListUnderASecretKey()
	{
		assertSameJsonValue('{"api_key":' + MASKED + ',"keep":1}', streamWithSecretKeysRule('{"api_key":[1,{"a":2},["x"]],"keep":1}').maskedText);
	}

	/**
	 * @description A whole object under a secret key, with every key inside it, is replaced. The key named `token` inside
	 * it is not counted, because it is gone with the object.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	private static void shouldReplaceAnObjectUnderASecretKey()
	{
		UTIL_String.JsonKeyMaskResult result = streamWithSecretKeysRule('{"apikey":{"nested":{"x":[3]},"token":"inner"},"keep":1}');

		assertSameJsonValue('{"apikey":' + MASKED + ',"keep":1}', result.maskedText);
		Assert.areEqual(1, result.replacementCount, 'Expected one replacement');
	}

	/**
	 * @description Secret keys at every level of an object, inside lists too, are all masked and all counted.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	private static void shouldMaskSecretKeysAtEveryLevel()
	{
		UTIL_String.JsonKeyMaskResult result = streamWithSecretKeysRule
				(
						'{"auth":{"token":"a","inner":{"password":"b","user":"u"}},"secret":{"token":"c"},"list":[{"bearer":"d"}]}'
				);

		assertSameJsonValue
				(
						'{"auth":{"token":' + MASKED + ',"inner":{"password":' + MASKED + ',"user":"u"}},"secret":' + MASKED + ',"list":[{"bearer":' + MASKED + '}]}',
						result.maskedText
				);
		Assert.areEqual(4, result.replacementCount, 'Expected four replacements');
	}

	/**
	 * @description A secret key 61 levels deep is masked by the token reader, which has no depth limit. The tree walk
	 * stops looking 50 levels deep.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	private static void shouldMaskASecretSixtyLevelsDeepInTheStream()
	{
		String opening = NEST_LEVEL_OPENING.repeat(SIXTY_LEVELS);
		String closing = NEST_LEVEL_CLOSING.repeat(SIXTY_LEVELS);

		UTIL_String.JsonKeyMaskResult result = streamWithSecretKeysRule(opening + '{"token":"deep"}' + closing);

		Assert.areEqual(opening + '{"token":' + MASKED + '}' + closing, result.maskedText, 'Expected the deep token masked');
	}

	/**
	 * @description When two rules run one after the other, the second reads the output of the first. Where both
	 * patterns match a key, the second rule's replacement is the one kept.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	private static void shouldLetALaterRuleSeeTheOutputOfAnEarlierRule()
	{
		String firstOutput = streamWithSecretKeysRule('{"access_token":"a","refresh_token":"b","session":"c","token":"d","user":"u"}').maskedText;

		UTIL_String.JsonKeyMaskResult second = UTIL_String.maskJsonKeysStreaming(firstOutput, '^(access_token|session|refresh_token)$', '[TOKEN]', false);

		assertSameJsonValue('{"access_token":"[TOKEN]","refresh_token":"[TOKEN]","session":"[TOKEN]","token":' + MASKED + ',"user":"u"}', second.maskedText);
		Assert.areEqual(3, second.replacementCount, 'Expected the second rule to count its own three replacements');
	}

	/**
	 * @description A long value that starts and ends like a JSON object or list but is broken inside goes to the text
	 * search when the token reader refuses it. The text search masks the complete `"key":"value"` pair.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldSendBrokenJsonAboveTheLineToTheTextSearch()
	{
		String result = UTIL_String.maskJsonKeys(buildAboveTheStructureLine('{"token":"abc",,"user":"x"}'), SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

		Assert.areEqual(buildAboveTheStructureLine('{"token":' + MASKED + ',,"user":"x"}'), result, 'Expected the text search to mask the broken value');
	}

	/**
	 * @description JSON cut inside a text value does not end like a JSON list, so it goes straight to the text search,
	 * which masks the complete pair and leaves the cut text as it is.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldSendJsonCutInsideATextValueToTheTextSearch()
	{
		String result = UTIL_String.maskJsonKeys('[{"token":"abc"},{"user":"x","note":"hel', SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

		Assert.areEqual('[{"token":' + MASKED + '},{"user":"x","note":"hel', result, 'Expected the complete pair masked and the cut text kept');
	}

	/**
	 * @description A long value whose last object is cut inside a list starts and ends like a JSON list, but the token
	 * reader refuses it, so it goes to the text search.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldSendJsonCutInsideAnObjectToTheTextSearch()
	{
		String result = UTIL_String.maskJsonKeys(buildAboveTheStructureLine('{"token":"abc","list":[1,2}'), SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

		Assert.areEqual(buildAboveTheStructureLine('{"token":' + MASKED + ',"list":[1,2}'), result, 'Expected the text search to mask the cut value');
	}

	/**
	 * @description When the token reader finds no secret key, it returns the very same string it was given: spaces, line
	 * breaks, the number `1.00`, the key written twice and the escapes all stay as they were.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	private static void shouldReturnTheSameStringWhenTheStreamMatchesNoKey()
	{
		String input = '{ "user" : "alice",\n  "amount": 1.00, "dup":1, "dup":2, "esc":"caf\\u00e9 \\/", "token_hint":"x" }';

		UTIL_String.JsonKeyMaskResult result = streamWithSecretKeysRule(input);

		Object output = result.maskedText;
		Object original = input;
		Assert.isTrue(output === original, 'Expected the very same string back');
		Assert.isFalse(result.mutated, 'Expected no change to be reported');
	}

	/**
	 * @description When no secret key name appears anywhere in the text, the key name search says so, and `maskJsonKeys`
	 * returns the very same string.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldReturnTheSameStringWhenNoKeyNameIsInTheText()
	{
		String input = '{"user":"alice","amount":1.00}';

		Object output = UTIL_String.maskJsonKeys(input, SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

		Object original = input;
		Assert.isFalse(UTIL_String.canHoldMatchingJsonKey(input, SECRET_KEY_PATTERN), 'Expected the key name search to find no secret key name');
		Assert.isTrue(output === original, 'Expected the very same string back');
	}

	/**
	 * @description The token reader writes every number again with the same value. `1.00`, `-0.50`, `0` and a 16-digit
	 * number keep their exact text; `1e5` is written as `1E+5`, the same number.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	private static void shouldKeepTheValueOfEveryNumber()
	{
		String numbers = '"amount":1.00,"exp":1e5,"negative":-0.50,"zero":0,"long":9007199254740993';

		String output = streamWithSecretKeysRule('{' + numbers + ',"token":"t"}').maskedText;

		assertSameJsonValue('{' + numbers + ',"token":' + MASKED + '}', output);
		Assert.isTrue(output.contains('"amount":1.00,"exp":1E+5,"negative":-0.50,"zero":0,"long":9007199254740993'), 'Expected the numbers as written, 1e5 as 1E+5');
	}

	/**
	 * @description The token reader copies true, false and null under keys that are not secret exactly as they were.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	private static void shouldCopyTrueFalseAndNullUnderOtherKeys()
	{
		String output = streamWithSecretKeysRule('{"active":true,"deleted":false,"note":null,"token":"t"}').maskedText;

		Assert.areEqual('{"active":true,"deleted":false,"note":null,"token":' + MASKED + '}', output, 'Expected true, false and null copied');
	}

	/**
	 * @description Spaces, a line break and a tab around the colon and the comma do not stop a secret key from being
	 * masked.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldMaskASecretKeyWithSpacesAroundTheColon()
	{
		assertSameJsonValue('{"token":' + MASKED + ',"user":"b"}', streamWithSecretKeysRule('{ "token" :\n "a" ,\t"user":"b" }').maskedText);
	}

	/**
	 * @description A value with more opening brackets than the structure line is read one token at a time by
	 * `maskJsonKeys`: a value nested 2,000 levels deep, which a whole-tree reader cannot read, is masked.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldReadAValueAboveTheStructureLineOneTokenAtATime()
	{
		String opening = NEST_LEVEL_OPENING.repeat(TWO_THOUSAND_LEVELS);
		String closing = NEST_LEVEL_CLOSING.repeat(TWO_THOUSAND_LEVELS);

		String result = UTIL_String.maskJsonKeys(opening + '{"token":"deep"}' + closing, SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

		Assert.areEqual(opening + '{"token":' + MASKED + '}' + closing, result, 'Expected the token at the bottom masked');
	}

	/**
	 * @description A value with exactly as many opening brackets as the structure line is still read as a whole tree,
	 * and the masked tree is written back to text. A key next to the deep branch is masked.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldReadAValueAtTheStructureLineAsATree()
	{
		Integer levels = UTIL_String.JSON_STRUCTURE_LINE - 1;
		String nest = NEST_LEVEL_OPENING.repeat(levels) + '"v"' + NEST_LEVEL_CLOSING.repeat(levels);
		String input = '{"password":"hunter2","deep":' + nest + '}';

		String result = UTIL_String.maskJsonKeys(input, SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

		Assert.isFalse(UTIL_String.exceedsJsonStructureLine(input), 'Expected the value to sit exactly at the line');
		assertSameJsonValue('{"password":' + MASKED + ',"deep":' + nest + '}', result);
	}

	/**
	 * @description The structure line counts opening braces and opening square brackets together.
	 *
	 * @see UTIL_String.exceedsJsonStructureLine
	 */
	@IsTest
	private static void shouldCountOpeningBracketsAgainstTheStructureLine()
	{
		Integer half = UTIL_String.JSON_STRUCTURE_LINE / 2;
		String atTheLine = '{'.repeat(half) + '['.repeat(UTIL_String.JSON_STRUCTURE_LINE - half);

		Assert.isFalse(UTIL_String.exceedsJsonStructureLine(atTheLine), 'Expected a value at the line not to exceed it');
		Assert.isTrue(UTIL_String.exceedsJsonStructureLine(atTheLine + '['), 'Expected one more opening bracket to exceed the line');
	}

	/**
	 * @description Only a value that starts and ends like a JSON object or a JSON list, after spaces at both ends, has
	 * the outline of one.
	 *
	 * @see UTIL_String.hasJsonObjectOrArrayShape
	 */
	@IsTest
	private static void shouldRecogniseTheOutlineOfAJsonObjectOrList()
	{
		Assert.isTrue(UTIL_String.hasJsonObjectOrArrayShape(' {"a":1} \n'), 'Expected an object with spaces around it');
		Assert.isTrue(UTIL_String.hasJsonObjectOrArrayShape('[1]'), 'Expected a list');
		Assert.isFalse(UTIL_String.hasJsonObjectOrArrayShape('{"a":1]'), 'Expected an object closed as a list to be refused');
		Assert.isFalse(UTIL_String.hasJsonObjectOrArrayShape('[1}'), 'Expected a list closed as an object to be refused');
		Assert.isFalse(UTIL_String.hasJsonObjectOrArrayShape('"x"'), 'Expected a JSON text alone to be refused');
		Assert.isFalse(UTIL_String.hasJsonObjectOrArrayShape('42'), 'Expected a JSON number alone to be refused');
		Assert.isFalse(UTIL_String.hasJsonObjectOrArrayShape(null), 'Expected null to be refused');
	}

	/**
	 * @description A secret key name that crosses the end of one search piece is found, because the next piece starts
	 * earlier and holds the whole name. The same text with a key name that is not secret is found to hold no secret key.
	 *
	 * @see UTIL_String.canHoldMatchingJsonKey
	 */
	@IsTest
	private static void shouldFindAKeyNameThatCrossesTheEndOfASearchPiece()
	{
		String keyName = 'password';
		String head = '{"pad":"';
		String beforeKey = '","';
		Integer padding = UTIL_String.KEY_SEARCH_PIECE_LENGTH - keyName.length() / 2 - head.length() - beforeKey.length();
		String withSecret = head + 'v'.repeat(padding) + beforeKey + keyName + '":"hunter2"}';
		String withoutSecret = withSecret.replace(keyName, 'username');

		String result = UTIL_String.maskJsonKeys(withSecret, SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

		Assert.areEqual(UTIL_String.KEY_SEARCH_PIECE_LENGTH, withSecret.indexOf(keyName) + keyName.length() / 2, 'Expected the key name to cross the end of a piece');
		Assert.isTrue(UTIL_String.canHoldMatchingJsonKey(withSecret, SECRET_KEY_PATTERN), 'Expected the key name across the piece end to be found');
		Assert.isFalse(result.contains('hunter2'), 'Expected the secret masked');
		Assert.isFalse(UTIL_String.canHoldMatchingJsonKey(withoutSecret, SECRET_KEY_PATTERN), 'Expected no secret key name to be found');
	}

	/**
	 * @description A pattern with an anchor in the middle (`^password$|^token$`) can match a key name alone but not the
	 * same name inside the text, so the key name search is not trusted and the rule reads the value.
	 *
	 * @see UTIL_String.canHoldMatchingJsonKey
	 */
	@IsTest
	private static void shouldNotSkipWhenThePatternHoldsAnotherAnchor()
	{
		String pattern = '^password$|^token$';

		Assert.isTrue(UTIL_String.canHoldMatchingJsonKey('{"user":"u"}', pattern), 'Expected the search not to be trusted');
		assertSameJsonValue('{"token":' + MASKED + '}', UTIL_String.maskJsonKeys('{"token":"t"}', pattern, SECRET_REPLACEMENT, false));
	}

	/**
	 * @description A key name written with any escape, here an escaped slash, does not appear as it reads in the raw
	 * text. The rule reads the value anyway, and a pattern that matches the decoded name masks it.
	 *
	 * @see UTIL_String.canHoldMatchingJsonKey
	 */
	@IsTest
	private static void shouldNotSkipWhenAKeyNameIsWrittenWithAnEscape()
	{
		String input = '{"api\\/key":"b"}';

		Assert.isTrue(UTIL_String.canHoldMatchingJsonKey(input, '^api.key$'), 'Expected a text with an escape not to be skipped');
		assertSameJsonValue('{"api/key":' + MASKED + '}', UTIL_String.maskJsonKeys(input, '^api.key$', SECRET_REPLACEMENT, false));
	}

	/**
	 * @description A pattern with a repeat that has no upper limit, such as `^.*secret.*$`, is not searched for over the
	 * raw text: over a long text that search takes so many steps that the transaction ends. The rule reads the value
	 * instead, and on a full-length value it finishes and masks the key that holds the word secret. That key comes last,
	 * so no piece of text before it holds a match.
	 *
	 * @see UTIL_String.canHoldMatchingJsonKey
	 */
	@IsTest
	private static void shouldNotSearchTheTextForAPatternWithARepeatThatHasNoUpperLimit()
	{
		String pattern = '^.*secret.*$';
		String head = '{"pad":"';
		String tail = '","mysecretvalue":"hunter2"}';
		String input = head + 'v'.repeat(SEL_ApiCall.REQUEST_LENGTH - head.length() - tail.length()) + tail;

		String result = UTIL_String.maskJsonKeys(input, pattern, SECRET_REPLACEMENT, false);

		Assert.areEqual(SEL_ApiCall.REQUEST_LENGTH, input.length(), 'Expected a value of full field length');
		Assert.isTrue(UTIL_String.canHoldMatchingJsonKey(input, pattern), 'Expected the key name search not to be used');
		Assert.isFalse(result.contains('hunter2'), 'Expected the key that holds the word secret to be masked');
		Assert.isTrue(UTIL_String.canHoldMatchingJsonKey('{"a":1}', '^\\w+token$'), 'Expected a repeat with + not to be searched for');
		Assert.isTrue(UTIL_String.canHoldMatchingJsonKey('{"a":1}', '^x{2,}$'), 'Expected a repeat with no upper count not to be searched for');
	}

	/**
	 * @description A blank or missing key pattern does not stop the key name search with an error: the search answers
	 * that the value can hold a key, so the rule itself runs and deals with the pattern. `maskJsonKeys` with a missing
	 * pattern returns the JSON value unchanged, as it did before the key name search existed.
	 *
	 * @see UTIL_String.canHoldMatchingJsonKey
	 */
	@IsTest
	private static void shouldNotFailOnABlankKeyPattern()
	{
		Assert.isTrue(UTIL_String.canHoldMatchingJsonKey('{"a":1}', null), 'Expected a missing pattern not to skip the rule');
		Assert.isTrue(UTIL_String.canHoldMatchingJsonKey('{"a":1}', UTIL_String.EMPTY), 'Expected an empty pattern not to skip the rule');
		Assert.areEqual('{"password":"x"}', UTIL_String.maskJsonKeys('{"password":"x"}', null, SECRET_REPLACEMENT), 'Expected the value unchanged');
	}

	/**
	 * @description When the pattern without its `^` and `$` does not compile, the key name search cannot run, and the
	 * rule reads the value.
	 *
	 * @see UTIL_String.canHoldMatchingJsonKey
	 */
	@IsTest
	private static void shouldNotSkipWhenTheShortenedPatternDoesNotCompile()
	{
		Assert.isTrue(UTIL_String.canHoldMatchingJsonKey('{"a":1}', '^abc\\$'), 'Expected a pattern that ends in an escaped dollar not to be trusted');
	}

	/**
	 * @description A null value has no opening brackets, so it does not go past the structure line. The check answers
	 * false without an error, as the outline check does for a null value.
	 *
	 * @see UTIL_String.exceedsJsonStructureLine
	 */
	@IsTest
	private static void shouldNotExceedTheStructureLineForANullValue()
	{
		Assert.isFalse(UTIL_String.exceedsJsonStructureLine(null), 'Expected a null value not to exceed the structure line');
	}

	/**
	 * @description A null value holds no key, so the key name search answers false without an error, whatever the key
	 * pattern is. It answers as the outline check does for a null value.
	 *
	 * @see UTIL_String.canHoldMatchingJsonKey
	 */
	@IsTest
	private static void shouldFindNoKeyNameInANullValue()
	{
		Assert.isFalse(UTIL_String.canHoldMatchingJsonKey(null, SECRET_KEY_PATTERN), 'Expected a null value to hold no secret key name');
		Assert.isFalse(UTIL_String.canHoldMatchingJsonKey(null, null), 'Expected a null value to hold no key name, even with a missing pattern');
	}

	/**
	 * @description A pattern with a repeat whose upper count is large, such as `^.{0,99999}secret$`, reads as far from
	 * every place as a repeat with no upper limit, so the key name search does not use it: the rule reads the value. The
	 * text search does not run with it either, and a value that holds a quote gets the failure marker. A small count,
	 * such as `{0,2}`, still lets the key name search answer that no key name can be in the value.
	 *
	 * @see UTIL_String.canHoldMatchingJsonKey
	 */
	@IsTest
	private static void shouldNotSearchTheTextForAPatternWithALargeUpperCount()
	{
		String largeCountPattern = '^.{0,99999}secret$';

		Assert.isTrue(UTIL_String.canHoldMatchingJsonKey('{"a":1}', largeCountPattern), 'Expected a large upper count not to be searched for');
		Assert.isTrue(UTIL_String.canHoldMatchingJsonKey('{"a":1}', '^x{100}$'), 'Expected a large exact count not to be searched for');
		Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, UTIL_String.maskJsonKeys('sent {"client_secret":"a"}', largeCountPattern, SECRET_REPLACEMENT),
				'Expected the failure marker from the text search');
		Assert.isFalse(UTIL_String.canHoldMatchingJsonKey('{"a":1}', '^api.{0,2}key$'), 'Expected a small upper count to be searched for');
	}

	/**
	 * @description The key pattern of the shipped secret-keys rule holds nothing that makes the key name search unsafe.
	 * So the search answers that a value without any of its key names cannot hold one, and the rule skips that value
	 * instead of reading it as JSON. If the shipped pattern lost this, every JSON value would be read in full.
	 *
	 * @see UTIL_String.canHoldMatchingJsonKey
	 */
	@IsTest
	private static void shouldLetTheShippedSecretKeysPatternUseTheKeyNameSearch()
	{
		Assert.isFalse(UTIL_String.canHoldMatchingJsonKey('{"user":"alice","amount":1.00,"items":[1,2]}', SECRET_KEY_PATTERN), 'Expected no secret key name to be found');
	}

	/**
	 * @description A null replacement is written as JSON null by the token reader, as the tree walk does.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	private static void shouldWriteJsonNullForANullReplacementInTheStream()
	{
		UTIL_String.JsonKeyMaskResult result = UTIL_String.maskJsonKeysStreaming('{"password":"x"}', '^password$', null, false);

		Assert.areEqual('{"password":null}', result.maskedText, 'Expected JSON null in place of the value');
	}

	/**
	 * @description The token reader returns an empty or null value as it is, with no change reported.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	private static void shouldReturnAnEmptyValueFromTheStreamUnchanged()
	{
		Assert.areEqual(UTIL_String.EMPTY, streamWithSecretKeysRule(UTIL_String.EMPTY).maskedText, 'Expected an empty value back');
		Assert.isNull(streamWithSecretKeysRule(null).maskedText, 'Expected null back');
		Assert.isFalse(streamWithSecretKeysRule(null).mutated, 'Expected no change to be reported');
	}

	/**
	 * @description The token reader refuses text that is not valid JSON with a JSON error, so the caller can send the
	 * value to the text search.
	 *
	 * @see UTIL_String.maskJsonKeysStreaming
	 */
	@IsTest
	private static void shouldThrowWhenTheStreamReadsTextThatIsNotJson()
	{
		try
		{
			streamWithSecretKeysRule('{"token":"abc",,"user":"x"}');
			Assert.fail('Expected a JSON error for broken JSON');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, System.JSONException.class, 'Expected a JSON error');
		}
	}

	/**
	 * @description A value that is one JSON text or one JSON number goes to the text search and comes back unchanged.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldSendATopLevelScalarToTheTextSearch()
	{
		Assert.areEqual('"secret"', UTIL_String.maskJsonKeys('"secret"', SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false), 'Expected a JSON text alone unchanged');
		Assert.areEqual('42', UTIL_String.maskJsonKeys('42', SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false), 'Expected a JSON number alone unchanged');
	}

	/**
	 * @description The text search replaces a secret text whole, even when the text holds an escaped quote. Nothing of the
	 * part after the escaped quote is left.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMaskAStringSecretWithAnEscapedQuoteWhole()
	{
		String result = maskAsTextWithSecretKeysRule('{"password":"ab\\"cd"}');

		Assert.areEqual('{"password":' + MASKED + '}' + TEXT_AFTER_THE_JSON, result, 'Expected the whole secret text replaced');
		Assert.isFalse(result.contains('cd'), 'Expected nothing of the secret left after the escaped quote');
	}

	/**
	 * @description The text search replaces a number under a secret key. The replacement is written in quotes, as for a
	 * secret text.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMaskANumberSecretInTheTextPass()
	{
		Assert.areEqual
				(
						'{"token":' + MASKED + ',"keep":1}' + TEXT_AFTER_THE_JSON,
						maskAsTextWithSecretKeysRule('{"token":12345,"keep":1}'),
						'Expected the secret number replaced and the other number kept'
				);
		Assert.areEqual
				(
						'{"token":' + MASKED + '}' + TEXT_AFTER_THE_JSON,
						maskAsTextWithSecretKeysRule('{"token":-1.5e+3}'),
						'Expected a negative number with a fraction and an exponent replaced whole'
				);
	}

	/**
	 * @description The text search replaces true, false and null under a secret key.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMaskBooleanAndNullSecretsInTheTextPass()
	{
		Assert.areEqual
				(
						'{"secret":' + MASKED + ',"bearer":' + MASKED + ',"passwd":' + MASKED + ',"keep":true}' + TEXT_AFTER_THE_JSON,
						maskAsTextWithSecretKeysRule('{"secret":true,"bearer":false,"passwd":null,"keep":true}'),
						'Expected true, false and null under secret keys replaced, and the other value kept'
				);
	}

	/**
	 * @description The text search cannot tell where an object under a secret key ends, so it cannot hide it safely. It
	 * returns the failure marker in place of the whole value.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMarkTheWholeValueWhenASecretKeyHoldsAnObject()
	{
		Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, maskAsTextWithSecretKeysRule('{"token":{"k":"v"}}'), 'Expected the failure marker');
	}

	/**
	 * @description The text search cannot tell where a list under a secret key ends, so it returns the failure marker in
	 * place of the whole value.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMarkTheWholeValueWhenASecretKeyHoldsAnArray()
	{
		Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, maskAsTextWithSecretKeysRule('{"token":["a","b"]}'), 'Expected the failure marker');
	}

	/**
	 * @description A secret text without its closing quote has no end the text search can find, so the search returns the
	 * failure marker in place of the whole value. A value cut inside a secret text is never saved with the secret.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMarkTheWholeValueWhenASecretStringIsUnterminated()
	{
		String result = UTIL_String.maskJsonKeys('[{"token":"abc"},{"password":"hunter', SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

		Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result, 'Expected the failure marker');
	}

	/**
	 * @description Key-like text inside an ordinary text, written with escaped quotes, is not read as a key: the value
	 * comes back unchanged. The search may hide too much, but never too little; for this text it hides nothing, because
	 * an escaped quote never starts or ends a key.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldLeaveKeyLikeTextInsideAnOrdinaryStringAlone()
	{
		String input = '{"description":"say \\"password\\": \\"x\\" here"}' + TEXT_AFTER_THE_JSON;

		Object result = UTIL_String.maskJsonKeys(input, SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

		Object original = input;
		Assert.isTrue(result === original, 'Expected the very same text back, with the key-like text left as it is');
	}

	/**
	 * @description The text search reads a key written with JSON escapes as JSON reads it, and judges the key by the name
	 * it reads. A key spelled with a backslash, the letter u and four hexadecimal digits, and a key with an escaped quote inside
	 * it, both have their values replaced when the name they read matches the pattern. A key whose name does not match
	 * keeps its value, and every key stays as it was written.
	 *
	 * @see UTIL_String.maskJsonKeysViaRegex
	 */
	@IsTest
	private static void shouldMaskASecretKeyWrittenWithEscapesInTheTextSearch()
	{
		String result = UTIL_String.maskJsonKeysViaRegex(KEYS_WRITTEN_WITH_ESCAPES, ESCAPED_KEY_NAMES_PATTERN, SECRET_REPLACEMENT, false);

		Assert.areEqual(KEYS_WRITTEN_WITH_ESCAPES_MASKED, result, 'Expected every value under a key that reads as a secret name replaced');
		Assert.isFalse(result.contains('hunter'), 'Expected no secret left in clear');
	}

	/**
	 * @description A key with a backslash that JSON cannot read, such as a backslash before the letter e, has no name the
	 * text search can check. The search cannot rule out that the key is secret, so it returns the failure marker in place
	 * of the whole value.
	 *
	 * @see UTIL_String.maskJsonKeysViaRegex
	 */
	@IsTest
	private static void shouldMarkTheWholeValueWhenAKeyCannotBeRead()
	{
		String result = UTIL_String.maskJsonKeysViaRegex('{"user":"alice","tok\\en":"hunter2"}', SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

		Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result, 'Expected the failure marker in place of the whole value');
	}

	/**
	 * @description A secret key with every letter written as a JSON escape is 74 characters long in quotes. When it
	 * crosses the end of the first piece of the text search, its value is still replaced: the next piece starts
	 * `UTIL_String.JSON_TEXT_SEARCH_PIECE_OVERLAP` characters before that end, so it holds the whole key.
	 *
	 * @see UTIL_String.maskJsonKeysViaRegex
	 */
	@IsTest
	private static void shouldMaskALongEscapedKeyThatCrossesTheEndOfAPiece()
	{
		String quotedKey = UTIL_String.DOUBLE_QUOTE + CLIENT_SECRET_WRITTEN_WITH_ESCAPES + UTIL_String.DOUBLE_QUOTE;
		String head = buildTextWithPairNearThePieceEnd(quotedKey + ':', quotedKey.length() - KEY_CHARACTERS_AFTER_THE_PIECE_END);
		Integer keyStart = UTIL_String.JSON_TEXT_SEARCH_PIECE_LENGTH - quotedKey.length() + KEY_CHARACTERS_AFTER_THE_PIECE_END;
		Assert.areEqual(keyStart, head.indexOf(quotedKey), 'Expected the key to start where it crosses the end of the first piece');

		String result = UTIL_String.maskJsonKeysViaRegex(head + '"hunter2"}', LONG_KEY_NAME_PATTERN, SECRET_REPLACEMENT, false);

		Assert.areEqual(head + MASKED + '}', result, 'Expected the value under the long key replaced and the key kept as written');
	}

	/**
	 * @description A quote that follows a backslash is part of a text and never starts a key. This holds also when the
	 * quote is the first character of a piece of the text search: the search still sees the backslash before the piece.
	 * Here the escaped quote starts the second piece, and the text after it reads like a secret key written with an
	 * escape. The value comes back unchanged. A search that could not see the backslash would replace `hunter2`.
	 *
	 * @see UTIL_String.maskJsonKeysViaRegex
	 */
	@IsTest
	private static void shouldNotReadAnEscapedQuoteAtThePieceStartAsAKey()
	{
		Integer secondPieceStart = UTIL_String.JSON_TEXT_SEARCH_PIECE_LENGTH - UTIL_String.JSON_TEXT_SEARCH_PIECE_OVERLAP;
		String head = '{"note":"';
		String beforeTheQuote = head + 'n'.repeat(secondPieceStart - 1 - head.length()) + '\\';
		String input = beforeTheQuote + '"p\\u0061ssword":"hunter2","pad":"' + 'v'.repeat(UTIL_String.JSON_TEXT_SEARCH_PIECE_LENGTH) + '"}';
		Assert.areEqual(secondPieceStart, input.indexOf('\\"') + 1, 'Expected the escaped quote to be the first character of the second piece');

		Object result = UTIL_String.maskJsonKeysViaRegex(input, SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

		Object original = input;
		Assert.isTrue(result === original, 'Expected the very same text back, with hunter2 kept inside the note');
	}

	/**
	 * @description The text search finds a secret key with spaces, tabs or line breaks on either side of its colon, and
	 * keeps those spaces.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldTolerateWhitespaceAroundTheColon()
	{
		Assert.areEqual
				(
						'{"password" :\n ' + MASKED + ' , "token"\t:\t' + MASKED + '}' + TEXT_AFTER_THE_JSON,
						maskAsTextWithSecretKeysRule('{"password" :\n "x" , "token"\t:\t42}'),
						'Expected both secrets replaced and the spaces kept'
				);
	}

	/**
	 * @description A secret key written more than once has every one of its values replaced.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMaskRepeatedKeysInTheTextPass()
	{
		Assert.areEqual
				(
						'{"token":' + MASKED + ',"token":' + MASKED + ',"TOKEN":' + MASKED + '}' + TEXT_AFTER_THE_JSON,
						maskAsTextWithSecretKeysRule('{"token":"a","token":"b","TOKEN":"c"}'),
						'Expected every copy of the key replaced, in any case'
				);
	}

	/**
	 * @description A word without quotes under a secret key is not JSON, and the text search cannot tell where it ends.
	 * It returns the failure marker in place of the whole value.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMarkTheWholeValueWhenASecretHoldsAnUnquotedToken()
	{
		Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, maskAsTextWithSecretKeysRule('{"password": hunter2}'), 'Expected the failure marker');
	}

	/**
	 * @description A secret text of 120,000 characters, far longer than one piece of the text search, is replaced whole,
	 * and the search finishes.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMaskALongStringSecretWithoutHittingTheRegexLimit()
	{
		String result = maskAsTextWithSecretKeysRule('{"password":"' + 'x'.repeat(LONG_SECRET_LENGTH) + '"}');

		Assert.areEqual('{"password":' + MASKED + '}' + TEXT_AFTER_THE_JSON, result, 'Expected the long secret replaced whole');
	}

	/**
	 * @description A secret text longer than the text search can read in one try gets the failure marker in place of the
	 * whole value, and the search finishes. Reading the whole secret in one try ends the transaction with a platform error
	 * that no code can catch.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMarkASecretTooLongToReadInOneTryInsteadOfEndingTheTransaction()
	{
		String result = maskAsTextWithSecretKeysRule('{"note":"a","token":"' + 'x'.repeat(SECRET_PAST_THE_PAIR_READ_LENGTH) + '"}');

		Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result, 'Expected the failure marker in place of the value');
	}

	/**
	 * @description A secret text of 540,000 characters made only of escaped quotes gets the failure marker in place of
	 * the whole value, and the search finishes. Each escaped quote costs the search more steps than a plain letter.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMarkALongSecretOfEscapedQuotesInsteadOfEndingTheTransaction()
	{
		String result = maskAsTextWithSecretKeysRule('{"password":"' + ESCAPED_QUOTE.repeat(ESCAPED_QUOTES_PAST_THE_PAIR_READ_LENGTH) + '"}');

		Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result, 'Expected the failure marker in place of the value');
	}

	/**
	 * @description A secret text of 540,000 plain letters gets the failure marker in place of the whole value, and the
	 * search finishes.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMarkALongSecretOfPlainLettersInsteadOfEndingTheTransaction()
	{
		String result = maskAsTextWithSecretKeysRule('{"password":"' + 'a'.repeat(LETTERS_PAST_THE_PAIR_READ_LENGTH) + '"}');

		Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result, 'Expected the failure marker in place of the value');
	}

	/**
	 * @description A secret text of 300,000 characters, where letters and escaped quotes take turns, gets the failure
	 * marker in place of the whole value. This text costs the search the most steps for each character, so the search
	 * reads a pair over a much shorter stretch than the length at which such a text ends the transaction.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMarkASecretOfLettersAndEscapedQuotesLongerThanOneRead()
	{
		String secret = LETTER_AND_ESCAPED_QUOTE.repeat(LETTER_AND_ESCAPED_QUOTE_REPEATS_PAST_THE_PAIR_READ_LENGTH);

		String result = maskAsTextWithSecretKeysRule('{"password":"' + secret + '"}');

		Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result, 'Expected the failure marker in place of the value');
	}

	/**
	 * @description A secret text of 261,000 characters, where letters and escaped quotes take turns, is replaced whole.
	 * The text fits in what the search reads in one try, and the search finishes.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMaskASecretOfLettersAndEscapedQuotesThatFitsInOneRead()
	{
		String secret = LETTER_AND_ESCAPED_QUOTE.repeat(LETTER_AND_ESCAPED_QUOTE_REPEATS_INSIDE_THE_PAIR_READ_LENGTH);

		String result = maskAsTextWithSecretKeysRule('{"password":"' + secret + '"}');

		Assert.areEqual('{"password":' + MASKED + '}' + TEXT_AFTER_THE_JSON, result, 'Expected the secret replaced whole');
	}

	/**
	 * @description A secret text that starts near the end of the first piece of the text search and ends in the next
	 * piece is replaced whole.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMaskASecretWhoseValueCrossesTheEndOfAPiece()
	{
		String secret = 's'.repeat(KEY_START_BEFORE_THE_PIECE_END * 2);
		String head = buildTextWithPairNearThePieceEnd('"token":"');

		String result = maskAsTextWithSecretKeysRule(head + secret + '"}');

		Assert.areEqual(head.removeEnd(UTIL_String.DOUBLE_QUOTE) + MASKED + '}' + TEXT_AFTER_THE_JSON, result, 'Expected the secret replaced whole');
	}

	/**
	 * @description A secret key followed by so many spaces that they cross the end of the first piece of the text search
	 * still has its value replaced. The key starts too early for the next piece to see it, so the search looks back
	 * from the spaces at the end of the piece for the key.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMaskASecretWhenSpacesAfterItsKeyCrossTheEndOfAPiece()
	{
		String head = buildTextWithPairNearThePieceEnd('"password"' + UTIL_String.SPACE.repeat(SPACES_ACROSS_THE_PIECE_END) + ': ');

		String result = maskAsTextWithSecretKeysRule(head + '"hunter2"}');

		Assert.areEqual(head + MASKED + '}' + TEXT_AFTER_THE_JSON, result, 'Expected the secret after the spaces replaced');
	}

	/**
	 * @description A secret key with 270,000 spaces before its colon, or 270,000 spaces between its colon and its secret,
	 * gets the failure marker in place of the whole value. The text search reads at most 262,144 characters from the start
	 * of a key in one try, so it cannot see where such a pair ends. It cannot tell what the pair holds, so it hides the
	 * whole value. Nothing of the secret is returned.
	 *
	 * @see UTIL_String.maskJsonKeysViaRegex
	 */
	@IsTest
	private static void shouldMarkAPairWhoseSpacesRunPastTheReadLength()
	{
		String spaces = UTIL_String.SPACE.repeat(SPACES_PAST_THE_PAIR_READ_LENGTH);
		String secret = '"' + PASSWORD_VALUE + '"}';

		for(String value : new List<String> {'{"password"' + spaces + ':' + secret, '{"password":' + spaces + secret})
		{
			String result = UTIL_String.maskJsonKeysViaRegex(value, SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

			Assert.isFalse(result.contains(PASSWORD_VALUE), 'Expected no secret left in clear, found ' + result.right(MESSAGE_WINDOW_LENGTH));
			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result, 'Expected the failure marker in place of the whole value');
		}
	}

	/**
	 * @description A secret key is followed by spaces that cross the end of the first piece of the text search and run to
	 * the end of the value. No colon follows the key, so there is no pair. The read of the key reaches the real end of the
	 * value, so the search knows that nothing more can follow. The value comes back unchanged, without the failure marker.
	 *
	 * @see UTIL_String.maskJsonKeysViaRegex
	 */
	@IsTest
	private static void shouldLeaveAKeyWithoutAColonAtTheEndOfTheValueAlone()
	{
		String head = buildTextWithPairNearThePieceEnd('"password"');
		String value = head + UTIL_String.SPACE.repeat(VALUE_ENDING_IN_SPACES_LENGTH - head.length());

		String result = UTIL_String.maskJsonKeysViaRegex(value, SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

		Assert.areEqual(value, result, 'Expected the value unchanged, with no failure marker');
	}

	/**
	 * @description An ordinary key, `name`, is followed by spaces that cross the end of the first piece of the text
	 * search, and then by a colon and a value. The value is 300,000 characters long, so more of it follows the longest
	 * stretch the search reads from the key. The secret-keys rule does not match `name`, so the read of the key fails at
	 * once, long before the end of what it may read. The value comes back unchanged, without the failure marker.
	 *
	 * @see UTIL_String.maskJsonKeysViaRegex
	 */
	@IsTest
	private static void shouldLeaveAnOrdinaryKeyBeforeLongSpacesAlone()
	{
		String head = buildTextWithPairNearThePieceEnd('"name"' + UTIL_String.SPACE.repeat(SPACES_ACROSS_THE_PIECE_END) + ': "x"');
		String value = head + FILLER_LETTER.repeat(THREE_PIECE_VALUE_LENGTH - head.length());

		String result = UTIL_String.maskJsonKeysViaRegex(value, SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

		Assert.areEqual(value, result, 'Expected the value unchanged, with no failure marker');
	}

	/**
	 * @description A full-length wall of quotes holds no key. The text search returns the very same text and finishes,
	 * and never an empty text.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldReturnAWallOfQuotesUnchanged()
	{
		String input = UTIL_String.DOUBLE_QUOTE.repeat(SEL_ApiCall.REQUEST_LENGTH);

		Object result = UTIL_String.maskJsonKeys(input, SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

		Object original = input;
		Assert.isTrue(result === original, 'Expected the very same text back');
		Assert.areEqual(SEL_ApiCall.REQUEST_LENGTH, ((String)result).length(), 'Expected the text not to be emptied');
	}

	/**
	 * @description A full-length text of ordinary `"key":"value"` pairs without a secret key comes back as the very same
	 * text, and the text search finishes.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldReturnAWallOfOrdinaryPairsUnchanged()
	{
		String input = ORDINARY_PAIR.repeat(SEL_ApiCall.REQUEST_LENGTH / ORDINARY_PAIR.length());

		Object result = UTIL_String.maskJsonKeys(input, SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

		Object original = input;
		Assert.isTrue(result === original, 'Expected the very same text back');
	}

	/**
	 * @description A text that holds two JSON objects, one after the other, is not one JSON value, so it goes to the text
	 * search. The search replaces every secret in both objects.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMaskTheSecretsOfTwoObjectsWrittenOneAfterTheOther()
	{
		String result = UTIL_String.maskJsonKeys('sent {"token":"a"} then {"password":"b"}', SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);

		Assert.areEqual('sent {"token":' + MASKED + '} then {"password":' + MASKED + '}', result, 'Expected the secrets of both objects replaced');
	}

	/**
	 * @description A key pattern with a repeat that has no upper limit, such as `.*secret.*`, would end the transaction
	 * on a long text full of quotes. The text search does not run with it: a full-length one-line value gets the failure
	 * marker, and the masking finishes.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMarkALongValueWhenTheKeyPatternHasAnUnlimitedRepeat()
	{
		String input = UTIL_String.DOUBLE_QUOTE.repeat(SEL_ApiCall.REQUEST_LENGTH);

		Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, UTIL_String.maskJsonKeys(input, UNLIMITED_REPEAT_KEY_PATTERN, SECRET_REPLACEMENT), 'Expected the failure marker');
	}

	/**
	 * @description A key pattern with a repeat that has no upper limit is not safe for the text search at any length:
	 * a text of quotes already ends the transaction at about 1,000 characters. So a short value that holds a quote gets
	 * the failure marker too, instead of having its secret replaced in place. A value without a quote cannot hold a key
	 * and comes back unchanged.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldMarkAShortValueWhenTheKeyPatternHasAnUnlimitedRepeat()
	{
		String withoutQuotes = 'no key in this text';

		Assert.areEqual
				(
						UTIL_FrameworkMasker.FAILURE_MARKER,
						UTIL_String.maskJsonKeys('sent {"client_secret":"a"}', UNLIMITED_REPEAT_KEY_PATTERN, SECRET_REPLACEMENT),
						'Expected the failure marker for a short value with a key'
				);
		Assert.areEqual(withoutQuotes, UTIL_String.maskJsonKeys(withoutQuotes, UNLIMITED_REPEAT_KEY_PATTERN, SECRET_REPLACEMENT), 'Expected a value without a quote unchanged');
	}

	/**
	 * @description A blank key pattern cannot find any key. The text search refuses it with a clear error instead of
	 * failing on the missing pattern, so the masking records the rule as failed.
	 *
	 * @see UTIL_String.maskJsonKeys
	 */
	@IsTest
	private static void shouldThrowWhenTheTextSearchGetsABlankKeyPattern()
	{
		try
		{
			UTIL_String.maskJsonKeys('password: hunter2', null, SECRET_REPLACEMENT);
			Assert.fail('Expected an error for a blank key pattern');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException');
			Assert.isTrue(error.getMessage().contains('key pattern'), 'Expected the message to name the key pattern, found: ' + error.getMessage());
		}
	}

	/**
	 * @description A real-format 15-digit American Express number is accepted as a card number, so a card shorter than 16
	 * digits is not mistaken for an ordinary number.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldAcceptValidAmex()
	{
		Assert.isTrue(UTIL_String.isValidCardNumber(VALID_AMEX_15), 'Valid 15-digit Amex must pass card-number validation');
	}

	/**
	 * @description A real-format 16-digit Visa number is accepted as a card number: it has a card's length and passes the
	 * Luhn check, the checksum built into card numbers.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldAcceptValidVisa()
	{
		Assert.isTrue(UTIL_String.isValidCardNumber(VALID_VISA_16), 'Valid 16-digit Visa must pass card-number validation');
	}

	/**
	 * @description A real-format 16-digit Mastercard number is accepted as a card number, so acceptance does not depend on
	 * one card brand's leading digits.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldAcceptValidMastercard()
	{
		Assert.isTrue(UTIL_String.isValidCardNumber(VALID_MC_16), 'Valid 16-digit Mastercard must pass card-number validation');
	}

	/**
	 * @description A real-format 19-digit UnionPay number is accepted as a card number, so the longest card length is
	 * covered as well as the common 16 digits.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldAcceptValidUnionPay()
	{
		Assert.isTrue(UTIL_String.isValidCardNumber(VALID_UNION_PAY_19), 'Valid 19-digit UnionPay must pass card-number validation');
	}

	/**
	 * @description A 16-digit transaction id has the length of a card number but fails the Luhn check (the checksum built
	 * into card numbers), so it is not accepted as a card number. Length alone never makes a number a card.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldRejectTransactionIdShapedAs16Digits()
	{
		Assert.isFalse(UTIL_String.isValidCardNumber(INVALID_TRANSACTION_ID_16), '16-digit transaction ID must not card-number-validate');
	}

	/**
	 * @description A 19-digit timestamp in nanoseconds is not accepted as a card number, although 19 digits is a valid card
	 * length. A number that is not a card is not read as one just because of its length.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldRejectNanosecondTimestamp()
	{
		Assert.isFalse(UTIL_String.isValidCardNumber(TIMESTAMP_NANO_19), '19-digit nanosecond timestamp must not card-number-validate');
	}

	/**
	 * @description A card number written in groups of four, with hyphens or with spaces between the groups, is accepted: the
	 * separators are ignored and only the digits are checked.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldStripSpacesAndHyphensBeforeValidating()
	{
		Assert.isTrue(UTIL_String.isValidCardNumber('4111-1111-1111-1111'), 'Hyphens must be stripped before card-number validation');
		Assert.isTrue(UTIL_String.isValidCardNumber('4111 1111 1111 1111'), 'Spaces must be stripped before card-number validation');
	}

	/**
	 * @description A 12-digit number that passes the Luhn check is not accepted as a card number: it is shorter than 13
	 * digits, the shortest length a card number may have. The same digits with a leading zero, which keeps the Luhn check
	 * passing, are accepted at 13 digits, so length is the only reason the shorter one is turned away.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldRejectTooShortInput()
	{
		String tooShort = generateLuhnValidDigits(SHORTEST_CARD_DIGITS - 1);

		Assert.isTrue(UTIL_String.isValidCardNumber(LEADING_ZERO + tooShort), 'Expected the 13-digit Luhn-valid number to be accepted, got rejected');
		Assert.isFalse(UTIL_String.isValidCardNumber(tooShort), 'Expected the 12-digit Luhn-valid number to be rejected for its length, got accepted');
	}

	/**
	 * @description A 20-digit number that passes the Luhn check is not accepted as a card number: it is longer than 19
	 * digits, the longest length a card number may have. The same digits without their leading zero are accepted at 19
	 * digits, so length is the only reason the longer one is turned away.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldRejectTooLongInput()
	{
		String longestAccepted = generateLuhnValidDigits(LONGEST_CARD_DIGITS);

		Assert.isTrue(UTIL_String.isValidCardNumber(longestAccepted), 'Expected the 19-digit Luhn-valid number to be accepted, got rejected');
		Assert.isFalse(UTIL_String.isValidCardNumber(LEADING_ZERO + longestAccepted), 'Expected the 20-digit Luhn-valid number to be rejected for its length, got accepted');
	}

	/**
	 * @description A null value, an empty text and a text of spaces only are each answered with false and no error, so a
	 * caller can pass any value without checking it first.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldRejectNullAndEmpty()
	{
		Assert.isFalse(UTIL_String.isValidCardNumber(null), 'Null input must return false');
		Assert.isFalse(UTIL_String.isValidCardNumber(''), 'Empty input must return false');
		Assert.isFalse(UTIL_String.isValidCardNumber('   '), 'Whitespace-only input must return false');
	}

	/**
	 * @description A text with letters between its digits is not accepted as a card number. Only spaces and hyphens are
	 * ignored; any other character makes the text something other than a card number.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldRejectLetterContaminatedInput()
	{
		Assert.isFalse(UTIL_String.isValidCardNumber('4111A1111B1111C1111'), 'Letters must cause rejection even if digits would otherwise Luhn-validate');
	}

	/**
	 * @description A card number may mix spaces and hyphens between its digits. Both kinds of separator are ignored and only
	 * the digits are checked.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldAcceptACardWithSpacesAndHyphensBetweenDigits()
	{
		Assert.isTrue(UTIL_String.isValidCardNumber('4111 1111-1111 1111'), 'Expected a card with a space and a hyphen between digits to be accepted, got rejected');
	}

	/**
	 * @description A text with any character other than a digit, a space or a hyphen is not a card number, even when the
	 * digits in it would pass the Luhn check. A letter and a dot are both turned away.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldRejectACandidateWithAnyOtherCharacter()
	{
		Assert.isFalse(UTIL_String.isValidCardNumber('4111 1111 1111 111a'), 'Expected a text that ends in a letter to be rejected, got accepted');
		Assert.isFalse(UTIL_String.isValidCardNumber('4111.1111.1111.1111'), 'Expected a text with dots between digits to be rejected, got accepted');
	}

	/**
	 * @description A run of twenty digits that passes the Luhn check is not a card number, because a card number has at
	 * most nineteen digits.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldRejectATwentyDigitRun()
	{
		Assert.isFalse(UTIL_String.isValidCardNumber(LEADING_ZERO + VALID_NINETEEN_DIGITS), 'Expected twenty digits to be rejected for their length, got accepted');
	}

	/**
	 * @description A run of twelve digits that passes the Luhn check is not a card number, because a card number has at
	 * least thirteen digits.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldRejectTwelveDigits()
	{
		Assert.isFalse(UTIL_String.isValidCardNumber(generateLuhnValidDigits(SHORTEST_CARD_DIGITS - 1)), 'Expected twelve digits to be rejected for their length, got accepted');
	}

	/**
	 * @description A nineteen digit number that passes the Luhn check is accepted. Nineteen is the longest length a card
	 * number may have.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldAcceptANineteenDigitLuhnValidNumber()
	{
		Assert.isTrue(UTIL_String.isValidCardNumber(VALID_NINETEEN_DIGITS), 'Expected nineteen digits that pass the Luhn check to be accepted, got rejected');
	}

	/**
	 * @description A sixteen digit number whose last digit is wrong fails the Luhn check and is not accepted.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldRejectALuhnInvalidNumber()
	{
		Assert.isFalse(UTIL_String.isValidCardNumber(INVALID_LUHN_16), 'Expected sixteen digits that fail the Luhn check to be rejected, got accepted');
	}

	/**
	 * @description An empty text and a null value are each answered with false and no error.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldRejectBlank()
	{
		Assert.isFalse(UTIL_String.isValidCardNumber(''), 'Expected an empty text to be rejected, got accepted');
		Assert.isFalse(UTIL_String.isValidCardNumber(null), 'Expected null to be rejected, got accepted');
	}

	/**
	 * @description Two separators in a row, or a separator before the first digit or after the last digit, are ignored
	 * like any other separator, so a card number written that way is still accepted.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldIgnoreRepeatedAndEdgeSeparators()
	{
		Assert.isTrue(UTIL_String.isValidCardNumber('4111  1111 1111 1111'), 'Expected two spaces in a row to be ignored, got rejected');
		Assert.isTrue(UTIL_String.isValidCardNumber(' 4111-1111-1111-1111-'), 'Expected a space before and a hyphen after the digits to be ignored, got rejected');
	}

	/**
	 * @description Digits from other writing systems (Arabic-Indic and fullwidth digits) are not part of a card number,
	 * although the platform counts a text made only of such digits as numeric. A tab, a line break and a non-breaking
	 * space are not separators a card number may have. Each of these texts is answered with false and no error.
	 *
	 * @see UTIL_String.isValidCardNumber
	 */
	@IsTest
	private static void shouldRejectDigitsThatAreNotAsciiAndOtherWhitespace()
	{
		final Integer arabicIndicOne = 1633;
		final Integer fullwidthOne = 65297;
		final Integer nonBreakingSpace = 160;
		final Integer sixteenDigits = 16;
		List<Integer> arabicIndicCodes = new List<Integer>();
		List<Integer> fullwidthCodes = new List<Integer>();

		for(Integer count = 0; count < sixteenDigits; count++)
		{
			arabicIndicCodes.add(arabicIndicOne);
			fullwidthCodes.add(fullwidthOne);
		}

		Assert.isFalse(UTIL_String.isValidCardNumber(String.fromCharArray(arabicIndicCodes)), 'Expected a run of Arabic-Indic digits to be rejected, got accepted');
		Assert.isFalse(UTIL_String.isValidCardNumber(String.fromCharArray(fullwidthCodes)), 'Expected a run of fullwidth digits to be rejected, got accepted');
		Assert.isFalse(UTIL_String.isValidCardNumber('4111\t1111 1111 1111'), 'Expected a tab between digits to be rejected, got accepted');
		Assert.isFalse(UTIL_String.isValidCardNumber('4111\n1111 1111 1111'), 'Expected a line break between digits to be rejected, got accepted');
		String withNonBreakingSpace = '4111' + String.fromCharArray(new List<Integer> {nonBreakingSpace}) + '1111 1111 1111';
		Assert.isFalse(UTIL_String.isValidCardNumber(withNonBreakingSpace), 'Expected a non-breaking space between digits to be rejected, got accepted');
	}

	/**
	 * @description A run of digits that the pattern finds and that passes the Luhn check (the checksum built into card
	 * numbers) is replaced with the mask text, and the words around it stay as they were. A real card number in a message
	 * is hidden.
	 *
	 * @see UTIL_String.maskWithLuhnValidatedRegex
	 */
	@IsTest
	private static void shouldMaskLuhnValidCardInRegexAndLuhnPipeline()
	{
		String input = 'Charge receipt: 4111 1111 1111 1111 accepted';
		String regex = '\\b(?:\\d[ -]*?){15,19}\\b';
		String output = UTIL_String.maskWithLuhnValidatedRegex(input, regex, '[CARD_REDACTED]', false);
		Assert.areEqual('Charge receipt: [CARD_REDACTED] accepted', output, 'Luhn-valid match must be redacted');
	}

	/**
	 * @description A run of digits that the pattern finds but that fails the Luhn check is left as it is: a 16-digit
	 * transaction id stays readable, so masking card numbers does not destroy ids that only look like cards.
	 *
	 * @see UTIL_String.maskWithLuhnValidatedRegex
	 */
	@IsTest
	private static void shouldLeaveLuhnInvalidDigitRunAloneInPipeline()
	{
		String input = 'parentTransactionId: TID:1234567890123456';
		String regex = '\\b(?:\\d[ -]*?){15,19}\\b';
		String output = UTIL_String.maskWithLuhnValidatedRegex(input, regex, '[CARD_REDACTED]', false);
		Assert.areEqual('parentTransactionId: TID:1234567890123456', output, 'Luhn-invalid 16-digit transaction ID must pass through unchanged');
	}

	/**
	 * @description When one text holds both a card number and a 16-digit id that fails the Luhn check, only the card number
	 * is replaced. Each match is checked on its own, so one real card does not cause every digit run to be masked.
	 *
	 * @see UTIL_String.maskWithLuhnValidatedRegex
	 */
	@IsTest
	private static void shouldRedactOnlyLuhnValidMatchesWhenBothPresent()
	{
		String input = 'card 4111111111111111, trace 1234567890123456, done';
		String regex = '\\b(?:\\d[ -]*?){15,19}\\b';
		String output = UTIL_String.maskWithLuhnValidatedRegex(input, regex, 'X', false);
		Assert.areEqual('card X, trace 1234567890123456, done', output, 'Only the Luhn-valid card must be redacted; the trace ID survives');
	}

	/**
	 * @description A null text comes back as null and an empty text comes back empty, with no error, so a caller can mask a
	 * value without checking first whether it has one.
	 *
	 * @see UTIL_String.maskWithLuhnValidatedRegex
	 */
	@IsTest
	private static void shouldReturnInputUnchangedWhenNullOrEmptyInLuhnPipeline()
	{
		String regex = '\\b(?:\\d[ -]*?){15,19}\\b';
		Assert.areEqual(null, UTIL_String.maskWithLuhnValidatedRegex(null, regex, 'X', false), 'Null passes through unchanged');
		Assert.areEqual('', UTIL_String.maskWithLuhnValidatedRegex('', regex, 'X', false), 'Empty passes through unchanged');
	}

	/**
	 * @description Only the first `UTIL_String.LUHN_CANDIDATE_BUDGET` numbers in a value get the Luhn check. Every number
	 * after them is hidden without the check. Here every number fails the check: the first ones stay, the last ten are
	 * hidden. This keeps a text full of card-shaped numbers from using too much processing time.
	 *
	 * @see UTIL_String.maskWithLuhnValidatedRegex
	 */
	@IsTest
	private static void shouldMaskEveryCandidatePastTheBudgetWithoutTheChecksum()
	{
		List<String> numbers = new List<String>();
		List<String> expected = new List<String>();

		for(Integer index = 0; index < UTIL_String.LUHN_CANDIDATE_BUDGET + NUMBERS_PAST_THE_BUDGET; index++)
		{
			numbers.add(INVALID_LUHN_16);
			expected.add(index < UTIL_String.LUHN_CANDIDATE_BUDGET ? INVALID_LUHN_16 : CARD_REPLACEMENT);
		}

		String output = UTIL_String.maskWithLuhnValidatedRegex(String.join(numbers, NUMBER_SEPARATOR), PAYMENT_CARD_PATTERN, CARD_REPLACEMENT, false);

		Assert.areEqual(String.join(expected, NUMBER_SEPARATOR), output, 'Expected the first numbers to stay and the ten past the limit to be hidden');
	}

	/**
	 * @description Under the limit, each number still gets the Luhn check: of five numbers, the two that pass are hidden
	 * and the three that fail stay as they are.
	 *
	 * @see UTIL_String.maskWithLuhnValidatedRegex
	 */
	@IsTest
	private static void shouldStillCheckTheChecksumUnderTheBudget()
	{
		String input = String.join(new List<String> {VALID_VISA_16, INVALID_LUHN_16, VALID_MC_16, INVALID_TRANSACTION_ID_16, INVALID_LUHN_16}, NUMBER_SEPARATOR);
		String expected = String.join(new List<String> {CARD_REPLACEMENT, INVALID_LUHN_16, CARD_REPLACEMENT, INVALID_TRANSACTION_ID_16, INVALID_LUHN_16}, NUMBER_SEPARATOR);

		String output = UTIL_String.maskWithLuhnValidatedRegex(input, PAYMENT_CARD_PATTERN, CARD_REPLACEMENT, false);

		Assert.areEqual(expected, output, 'Expected exactly the two numbers that pass the Luhn check to be hidden');
		Assert.areEqual(2, output.countMatches(CARD_REPLACEMENT), 'Expected two replacements');
	}

	/**
	 * @description Card numbers with only one character between them, and card numbers at the very start and the very end
	 * of the value, are each replaced, and the characters between them stay in place.
	 *
	 * @see UTIL_String.maskWithLuhnValidatedRegex
	 */
	@IsTest
	private static void shouldRebuildAdjacentMatches()
	{
		String input = VALID_VISA_16 + UTIL_String.COMMA + VALID_MC_16 + UTIL_String.SEMI_COLON + VALID_AMEX_15;
		String expected = CARD_REPLACEMENT + UTIL_String.COMMA + CARD_REPLACEMENT + UTIL_String.SEMI_COLON + CARD_REPLACEMENT;

		String output = UTIL_String.maskWithLuhnValidatedRegex(input, PAYMENT_CARD_PATTERN, CARD_REPLACEMENT, false);

		Assert.areEqual(expected, output, 'Expected each of the three card numbers to be replaced and the separators kept');
	}

	/**
	 * @description The value is rebuilt correctly when the replacement is longer than the card number and when it is
	 * shorter. The text before, between and after the numbers is kept exactly.
	 *
	 * @see UTIL_String.maskWithLuhnValidatedRegex
	 */
	@IsTest
	private static void shouldRebuildWhenTheReplacementIsLongerAndShorterThanTheMatch()
	{
		String input = 'pay ' + VALID_VISA_16 + ' and ' + VALID_AMEX_15 + ' now';

		Assert.areEqual('pay ' + LONG_CARD_REPLACEMENT + ' and ' + LONG_CARD_REPLACEMENT + ' now',
				UTIL_String.maskWithLuhnValidatedRegex(input, PAYMENT_CARD_PATTERN, LONG_CARD_REPLACEMENT, false), 'Expected the longer replacement in both places');
		Assert.areEqual('pay ' + SHORT_CARD_REPLACEMENT + ' and ' + SHORT_CARD_REPLACEMENT + ' now',
				UTIL_String.maskWithLuhnValidatedRegex(input, PAYMENT_CARD_PATTERN, SHORT_CARD_REPLACEMENT, false), 'Expected the shorter replacement in both places');
	}

	/**
	 * @description The last number under the limit still gets the Luhn check, and the first number past the limit does
	 * not. Here the last checked number passes the check and is hidden, and the next number fails the check but is hidden
	 * anyway. The numbers before them fail the check and stay.
	 *
	 * @see UTIL_String.maskWithLuhnValidatedRegex
	 */
	@IsTest
	private static void shouldHandleTheMatchThatCrossesTheBudgetBoundary()
	{
		List<String> numbers = new List<String>();
		List<String> expected = new List<String>();

		for(Integer index = 1; index < UTIL_String.LUHN_CANDIDATE_BUDGET; index++)
		{
			numbers.add(INVALID_LUHN_16);
			expected.add(INVALID_LUHN_16);
		}

		numbers.add(VALID_VISA_16);
		numbers.add(INVALID_LUHN_16);
		expected.add(CARD_REPLACEMENT);
		expected.add(CARD_REPLACEMENT);

		String output = UTIL_String.maskWithLuhnValidatedRegex(String.join(numbers, NUMBER_SEPARATOR), PAYMENT_CARD_PATTERN, CARD_REPLACEMENT, false);

		Assert.areEqual(String.join(expected, NUMBER_SEPARATOR), output, 'Expected the last checked number and the first unchecked number to be hidden');
	}

	/**
	 * @description A value whose numbers all fail the Luhn check, with fewer numbers than the limit, comes back exactly as
	 * it went in.
	 *
	 * @see UTIL_String.maskWithLuhnValidatedRegex
	 */
	@IsTest
	private static void shouldLeaveAValueWhoseOnlyMatchesFailTheChecksumUnderTheBudgetUnchanged()
	{
		String input = 'ids ' + String.join(new List<String> {INVALID_LUHN_16, INVALID_TRANSACTION_ID_16, INVALID_LUHN_16}, NUMBER_SEPARATOR) + ' end';

		Assert.areEqual(input, UTIL_String.maskWithLuhnValidatedRegex(input, PAYMENT_CARD_PATTERN, CARD_REPLACEMENT, false), 'Expected the value to come back unchanged');
	}

	/**
	 * @description A card number split by a line break is not found. The card pattern allows only a space or a hyphen
	 * between digits, and neither part has enough digits to be a card number on its own. The value comes back unchanged.
	 *
	 * @see UTIL_String.maskWithLuhnValidatedRegex
	 */
	@IsTest
	private static void shouldLeaveACardSplitAcrossALineBreakAlone()
	{
		Assert.areEqual(CARD_SPLIT_BY_A_LINE_BREAK, UTIL_String.maskWithLuhnValidatedRegex(CARD_SPLIT_BY_A_LINE_BREAK, PAYMENT_CARD_PATTERN, CARD_REPLACEMENT, false),
				'Expected a card number split by a line break to stay as it is');
	}

	/**
	 * @description Only the places where the pattern found a number are replaced. The same digits inside a longer run of
	 * digits, which the pattern does not find because the run is too long for a card number, stay as they are.
	 *
	 * @see UTIL_String.maskWithLuhnValidatedRegex
	 */
	@IsTest
	private static void shouldReplaceOnlyTheMatchedNumberAndNotTheSameDigitsInALongerRun()
	{
		String input = 'card ' + VALID_VISA_16 + ' order ' + VALID_VISA_16 + TEN_TRAILING_DIGITS;

		Assert.areEqual('card ' + CARD_REPLACEMENT + ' order ' + VALID_VISA_16 + TEN_TRAILING_DIGITS,
				UTIL_String.maskWithLuhnValidatedRegex(input, PAYMENT_CARD_PATTERN, CARD_REPLACEMENT, false), 'Expected the 26-digit order number to stay whole');
	}

	/**
	 * @description A value longer than `UTIL_String.CARD_SEARCH_PIECE_LENGTH` is searched in pieces that share a few
	 * characters. This value holds one card number inside the shared characters and one that crosses the end of the first
	 * piece. Each is replaced once: nothing is lost at the end of the piece and nothing is replaced twice.
	 *
	 * @see UTIL_String.maskWithLuhnValidatedRegex
	 */
	@IsTest
	private static void shouldMaskACardSpanningASliceBoundary()
	{
		Integer cardAcrossTheEndStart = UTIL_String.CARD_SEARCH_PIECE_LENGTH - DIGITS_BEFORE_THE_PIECE_END;
		String before = UTIL_String.SPACE.repeat(cardAcrossTheEndStart - SPACES_BETWEEN_THE_EDGE_CARDS - VALID_VISA_16.length());
		String between = UTIL_String.SPACE.repeat(SPACES_BETWEEN_THE_EDGE_CARDS);
		String after = UTIL_String.SPACE.repeat(SPACES_AFTER_THE_EDGE_CARD);
		String input = before + VALID_VISA_16 + between + VALID_MC_16 + after;

		String output = UTIL_String.maskWithLuhnValidatedRegex(input, PAYMENT_CARD_PATTERN, CARD_REPLACEMENT, false);

		Assert.areEqual(before + CARD_REPLACEMENT + between + CARD_REPLACEMENT + after, output, 'Expected each card number near the end of the piece to be replaced once');
	}

	/**
	 * @description A run of 20 digits that crosses the end of the first search piece is too long for a card number, so the
	 * value stays as it is. The first piece holds only the first 15 digits, and they pass the Luhn check on their own. A
	 * search that trusted the end of the piece would hide those 15 digits and leave the last 5 in clear.
	 *
	 * @see UTIL_String.maskWithLuhnValidatedRegex
	 */
	@IsTest
	private static void shouldLeaveALongDigitRunThatCrossesThePieceEndAlone()
	{
		String before = UTIL_String.SPACE.repeat(UTIL_String.CARD_SEARCH_PIECE_LENGTH - VALID_AMEX_15.length());
		String input = before + VALID_AMEX_15 + FIVE_TRAILING_DIGITS + UTIL_String.SPACE.repeat(SPACES_AFTER_THE_EDGE_CARD);

		Assert.areEqual(input, UTIL_String.maskWithLuhnValidatedRegex(input, PAYMENT_CARD_PATTERN, CARD_REPLACEMENT, false),
				'Expected the 20-digit run across the end of the piece to stay whole');
	}

	/**
	 * @description A card number that ends exactly at the end of the first search piece and is followed by a letter is not
	 * a separate number, so the value stays as it is. Inside the first piece the number looks complete, because the piece
	 * ends right after it. A search that trusted the end of the piece would hide it.
	 *
	 * @see UTIL_String.maskWithLuhnValidatedRegex
	 */
	@IsTest
	private static void shouldLeaveACardEndingAtThePieceEndAndFollowedByALetterAlone()
	{
		String before = UTIL_String.SPACE.repeat(UTIL_String.CARD_SEARCH_PIECE_LENGTH - VALID_VISA_16.length());
		String input = before + VALID_VISA_16 + LETTER_AFTER_THE_CARD + UTIL_String.SPACE.repeat(SPACES_AFTER_THE_EDGE_CARD);

		Assert.areEqual(input, UTIL_String.maskWithLuhnValidatedRegex(input, PAYMENT_CARD_PATTERN, CARD_REPLACEMENT, false),
				'Expected the card number joined to a letter to stay as it is');
	}

	/**
	 * @description Builds a random run of digits of the given length that passes the Luhn check: random digits followed by
	 * the check digit that makes the Luhn sum a multiple of ten. Prefixing the result with zeros keeps it Luhn-valid.
	 *
	 * @param length The number of digits to return, check digit included
	 *
	 * @return A Luhn-valid run of digits of the given length
	 */
	private static String generateLuhnValidDigits(Integer length)
	{
		String payload = UTIL_Random.randomNumeric(length - 1);
		Integer sum = 0;
		Boolean doubleDigit = true;

		for(Integer position = payload.length() - 1; position >= 0; position--)
		{
			Integer digit = Integer.valueOf(payload.substring(position, position + 1));

			if(doubleDigit)
			{
				digit = digit * 2;
				digit = digit > 9 ? digit - 9 : digit;
			}

			sum += digit;
			doubleDigit = !doubleDigit;
		}

		return payload + String.valueOf(Math.mod(10 - Math.mod(sum, 10), 10));
	}

	/**
	 * @description Verifies that `canCompilePattern` answers true for a pattern that compiles.
	 */
	@IsTest
	private static void shouldAnswerTrueForAPatternThatCompiles()
	{
		Assert.isTrue(UTIL_String.canCompilePattern(COMPILABLE_PATTERN, true), 'Expected a valid pattern to compile');
	}

	/**
	 * @description Verifies that `canCompilePattern` answers false, and does not throw, for a pattern that cannot compile.
	 */
	@IsTest
	private static void shouldAnswerFalseForAPatternThatCannotCompile()
	{
		Assert.isFalse(UTIL_String.canCompilePattern(BROKEN_PATTERN, true), 'Expected an unclosed group to fail to compile');
	}

	/**
	 * @description Verifies that `canCompilePattern` answers false in the same way when case does not matter.
	 */
	@IsTest
	private static void shouldAnswerFalseWithoutThrowingWhenCaseInsensitive()
	{
		Assert.isFalse(UTIL_String.canCompilePattern(BROKEN_PATTERN, false), 'Expected the case-insensitive wrapper to fail the same way');
	}

	/**
	 * @description Masks a value with `maskWithRegex` and the pattern, replacement and case setting of a shipped Regex
	 * rule.
	 *
	 * @param ruleName The DeveloperName of the shipped rule
	 * @param value The value to mask
	 *
	 * @return The masked value
	 */
	private static String maskWithShippedRule(String ruleName, String value)
	{
		MaskingRule__mdt rule = MaskingRule__mdt.getInstance(ruleName);
		return UTIL_String.maskWithRegex(value, rule.Pattern__c, rule.Replacement__c ?? UTIL_String.EMPTY, rule.CaseSensitive__c == true);
	}

	/**
	 * @description Masks a value with one `replaceAll` over the whole value, with the pattern, replacement and case
	 * setting of a shipped Regex rule. The tests compare `maskWithRegex` with this result.
	 *
	 * @param ruleName The DeveloperName of the shipped rule
	 * @param value The value to mask
	 *
	 * @return The masked value
	 */
	private static String replaceAllWithShippedRule(String ruleName, String value)
	{
		MaskingRule__mdt rule = MaskingRule__mdt.getInstance(ruleName);
		String caseFlag = rule.CaseSensitive__c == true ? UTIL_String.EMPTY : '(?i)';
		return Pattern.compile(caseFlag + rule.Pattern__c).matcher(value).replaceAll(rule.Replacement__c ?? UTIL_String.EMPTY);
	}

	/**
	 * @description Builds a value of spaces with `SECRET_PAIR` written at one place in it.
	 *
	 * @param pairStart Where the pair starts in the value
	 * @param valueLength How long the value is
	 *
	 * @return The value
	 */
	private static String buildValueWithSecretPairAt(Integer pairStart, Integer valueLength)
	{
		return UTIL_String.SPACE.repeat(pairStart) + SECRET_PAIR + UTIL_String.SPACE.repeat(valueLength - pairStart - SECRET_PAIR.length());
	}

	/**
	 * @description Masks a value with one `replaceAll` over the whole value, with `OVERLAPPING_ALTERNATIVES_PATTERN` and
	 * `PAIR_REPLACEMENT`. The tests compare `maskWithRegex` with this result.
	 *
	 * @param value The value to mask
	 *
	 * @return The masked value
	 */
	private static String replaceAllWithOverlappingAlternatives(String value)
	{
		return Pattern.compile(OVERLAPPING_ALTERNATIVES_PATTERN).matcher(value).replaceAll(PAIR_REPLACEMENT);
	}

	/**
	 * @description Masks a JSON text with the token reader and the key pattern and replacement of the shipped secret-keys
	 * rule.
	 *
	 * @param input The JSON text to mask
	 *
	 * @return The result of the token reader
	 */
	private static UTIL_String.JsonKeyMaskResult streamWithSecretKeysRule(String input)
	{
		return UTIL_String.maskJsonKeysStreaming(input, SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);
	}

	/**
	 * @description Masks a JSON-like value with the key pattern and replacement of the shipped secret-keys rule, after
	 * writing `TEXT_AFTER_THE_JSON` behind it. The value then does not end like JSON, so `maskJsonKeys` sends it to the
	 * text search for `"key":"value"` pairs.
	 *
	 * @param jsonLikeValue The value to write the text behind and mask
	 *
	 * @return The masked text
	 */
	private static String maskAsTextWithSecretKeysRule(String jsonLikeValue)
	{
		return UTIL_String.maskJsonKeys(jsonLikeValue + TEXT_AFTER_THE_JSON, SECRET_KEY_PATTERN, SECRET_REPLACEMENT, false);
	}

	/**
	 * @description Builds the start of a JSON-like text with an ordinary note, padded so that the pair written after it
	 * starts `KEY_START_BEFORE_THE_PIECE_END` characters before the end of the first piece of the text search.
	 *
	 * @param pair The pair to write after the note, starting with its key
	 *
	 * @return The text
	 */
	private static String buildTextWithPairNearThePieceEnd(String pair)
	{
		return buildTextWithPairNearThePieceEnd(pair, KEY_START_BEFORE_THE_PIECE_END);
	}

	/**
	 * @description Builds the start of a JSON-like text with an ordinary note, padded so that the pair written after it
	 * starts a given number of characters before the end of the first piece of the text search.
	 *
	 * @param pair The pair to write after the note, starting with its key
	 * @param keyStartBeforeThePieceEnd How many characters before the end of the first piece the pair starts
	 *
	 * @return The text
	 */
	private static String buildTextWithPairNearThePieceEnd(String pair, Integer keyStartBeforeThePieceEnd)
	{
		String head = '{"note":"';
		String noteEnd = '",';
		Integer padding = UTIL_String.JSON_TEXT_SEARCH_PIECE_LENGTH - keyStartBeforeThePieceEnd - head.length() - noteEnd.length();
		return head + 'n'.repeat(padding) + noteEnd + pair;
	}

	/**
	 * @description Checks that two JSON texts hold the same value: both are read as JSON and compared, so key order and
	 * spacing do not count.
	 *
	 * @param expected The expected JSON text
	 * @param actual The JSON text to check
	 */
	private static void assertSameJsonValue(String expected, String actual)
	{
		Assert.areEqual(JSON.deserializeUntyped(expected), JSON.deserializeUntyped(actual), 'Expected the JSON value ' + expected);
	}

	/**
	 * @description Puts a JSON value at the end of a list that starts with more empty objects than the structure line
	 * allows opening brackets, so `maskJsonKeys` reads it one token at a time.
	 *
	 * @param jsonValue The JSON value to put in the list
	 *
	 * @return The list as JSON text
	 */
	private static String buildAboveTheStructureLine(String jsonValue)
	{
		return '[' + EMPTY_OBJECT_IN_A_LIST.repeat(UTIL_String.JSON_STRUCTURE_LINE + 1) + jsonValue + ']';
	}
}
