// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for UTIL_FrameworkMasker.
 *
 * @see UTIL_FrameworkMasker
 *
 * @author Jason van Beukering
 *
 * @group Data Masking
 *
 * @date April 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ExcessiveParameterList,PMD.CyclomaticComplexity,PMD.NcssTypeCount')
private class UTIL_FrameworkMasker_TEST
{
	/**
	 * @description The company name that marks the administrator user these tests run as.
	 */
	private static final String TEST_ADMIN_COMPANY = 'UTIL_FrameworkMasker_TEST-admin';

	/**
	 * @description The company name that marks the low-privilege user the sharing and permission tests run as.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'UTIL_FrameworkMasker_TEST-low-privilege';

	/**
	 * @description Sample value used across tests.
	 */
	private static final String SAMPLE_VALUE = 'alice@example.com';

	/**
	 * @description The message of the error a test raises when it makes field details (FieldDefinition) unreadable.
	 */
	private static final String FIELD_DETAILS_DENIAL = 'Simulated FieldDefinition denial';

	/**
	 * @description Sample caller class name used across tests.
	 */
	private static final String SAMPLE_CALLER = 'API_SendEmail';

	/**
	 * @description DeveloperName of the superseded predecessor rule in the supersession matrix.
	 */
	private static final String PREDECESSOR_RULE_NAME = 'OldCardRule';

	/**
	 * @description DeveloperName of the successor rule in the supersession matrix.
	 */
	private static final String SUCCESSOR_RULE_NAME = 'NewCardRule';

	/**
	 * @description A run key in the shape the chain engine creates (a version-4 UUID) whose last two groups look like a
	 * sixteen-digit payment card number to a card rule. A test run at high volume met this case once in several
	 * thousand chain starts.
	 */
	private static final String CARD_SHAPED_RUN_KEY = 'fb1f69f6-6768-4768-8833-380884223126';

	/**
	 * @description The shipped card rule's pattern: thirteen to nineteen digits, spaces or hyphens between them.
	 */
	private static final String CARD_PATTERN = '\\b\\d(?:[ -]?\\d){12,18}\\b';

	/**
	 * @description The token the shipped card rule writes in place of a matched card number.
	 */
	private static final String CARD_REPLACEMENT = '[CARD_REDACTED]';

	/**
	 * @description Token that only the predecessor rule matches. If it is still in an output value,
	 * the predecessor's target was dropped; if it was replaced, the predecessor ran.
	 */
	private static final String PREDECESSOR_TOKEN = 'PRED-TOKEN';

	/**
	 * @description Token only the successor rule matches, making the successor's application
	 * observable independently of the predecessor's.
	 */
	private static final String SUCCESSOR_TOKEN = 'SUCC-TOKEN';

	/**
	 * @description Replacement the predecessor rule writes. If it appears, the predecessor ran.
	 */
	private static final String PREDECESSOR_REPLACEMENT = '[P]';

	/**
	 * @description Replacement the successor rule writes. If it appears, the successor ran.
	 */
	private static final String SUCCESSOR_REPLACEMENT = '[S]';

	/**
	 * @description Replacement a tuned predecessor writes. If it appears, the tuned rule kept running.
	 */
	private static final String TUNED_REPLACEMENT = '[P-TUNED]';

	/**
	 * @description The fingerprint the entry masked by a misconfigured log rule is written with.
	 */
	private static final String MASKED_ENTRY_FINGERPRINT = 'masked-entry-fingerprint';

	/**
	 * @description The class and method that entry is written at.
	 */
	private static final String MASKED_ENTRY_CLASS_METHOD = 'OrderService.submitOrder';

	/**
	 * @description DeveloperName of the rule whose applicable field types name a type that does not exist.
	 */
	private static final String UNKNOWN_TYPE_RULE_NAME = 'LogEventUnknownFieldTypeRule';

	/**
	 * @description DeveloperName of the rule wired to a field whose type it excludes.
	 */
	private static final String MISMATCHED_TYPE_RULE_NAME = 'LogEventMismatchedFieldTypeRule';

	/**
	 * @description A field type no Apex type name matches, as an admin's typo leaves it.
	 */
	private static final String UNKNOWN_FIELD_TYPE = 'TEXTFIELD';

	/**
	 * @description A value no message of the test entry holds, so the misconfigured rules change nothing.
	 */
	private static final String UNMATCHED_TOKEN = 'never-in-a-message';

	/**
	 * @description Where the masker would say that a rule names a field type that does not exist.
	 */
	private static final String UNKNOWN_TYPE_WARNING_LOCATION = UTIL_FrameworkMasker.class.getName() + UTIL_String.DOT + 'parseApplicableFieldTypes';

	/**
	 * @description Where the masker would say that a target is wired to a field type its rule excludes.
	 */
	private static final String MISMATCHED_TYPE_WARNING_LOCATION = UTIL_FrameworkMasker.class.getName() + UTIL_String.DOT + 'filterTargetsByFieldType';

	/**
	 * @description Where the masker writes its warning when a masking rule fails.
	 */
	private static final String RULE_FAILURE_WARNING_LOCATION = UTIL_FrameworkMasker.class.getName() + UTIL_String.DOT + 'handleRuleFailure';

	/**
	 * @description The flood-control key the masker puts on its warning that a rule failed, for the rule the
	 * failure-action fixtures register.
	 */
	private static final String RULE_FAILURE_FINGERPRINT = 'masking:rule-failure:TestRule';

	/**
	 * @description The flood-control key the masker puts on its warning that a rule names a field type that does not
	 * exist, for the rule the unknown-type fixture registers.
	 */
	private static final String UNKNOWN_TYPE_FINGERPRINT = 'masking:unknown-field-type:FoobarUnknownTypeRule';

	/**
	 * @description The flood-control key the masker puts on its warning that a target wires a rule to a field whose
	 * type the rule excludes, for the rule and field the mismatch fixture registers.
	 */
	private static final String EXCLUDED_TYPE_FINGERPRINT = 'masking:excluded-field-type:FoobarExcludedTypeRule:'
			+ UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType) + UTIL_String.DOT + UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.URL__c);

	/**
	 * @description Developer name of the rule the unknown-type fingerprint test registers on Foobar__c.
	 */
	private static final String FOOBAR_UNKNOWN_TYPE_RULE_NAME = 'FoobarUnknownTypeRule';

	/**
	 * @description Developer name of the rule the excluded-type fingerprint test registers on Foobar__c.
	 */
	private static final String FOOBAR_EXCLUDED_TYPE_RULE_NAME = 'FoobarExcludedTypeRule';

	/**
	 * @description The DeveloperName the single-rule helpers give their rule.
	 */
	private static final String TEST_RULE_NAME = 'TestRule';

	/**
	 * @description The DeveloperName of the broken rule that the log event test links to a deployed log event target.
	 */
	private static final String LOG_EVENT_BROKEN_RULE_NAME = 'LogEventBrokenRule';

	/**
	 * @description A pattern that can never compile, because its group and its character set are never closed.
	 */
	private static final String BROKEN_PATTERN = '([bad';

	/**
	 * @description A pattern that compiles and has only one group, so a replacement that names a second group fails.
	 */
	private static final String ONE_GROUP_PATTERN = '(a+)b';

	/**
	 * @description A replacement that names a second group. It fails only on a value the pattern matches.
	 */
	private static final String SECOND_GROUP_REPLACEMENT = '$2';

	/**
	 * @description The replacement the tests with a broken pattern give their rule. It is never used.
	 */
	private static final String UNUSED_REPLACEMENT = 'X';

	/**
	 * @description A whole value that an exact-match rule replaces with nothing, so the value is blank afterwards.
	 */
	private static final String ERASED_VALUE = 'erase me';

	/**
	 * @description The name of a rule that runs first, fails, and puts the failure marker in place of the value.
	 */
	private static final String MARKER_RULE_NAME = 'BrokenMarkerRule';

	/**
	 * @description The name of a rule that runs after the marker rule on the same value.
	 */
	private static final String LATER_RULE_NAME = 'LaterRule';

	/**
	 * @description The order of the rule that runs first in the tests with two rules on one field.
	 */
	private static final Integer FIRST_RULE_ORDER = 10;

	/**
	 * @description The order of the rule that runs second in the tests with two rules on one field.
	 */
	private static final Integer SECOND_RULE_ORDER = 20;

	/**
	 * @description A small JSON value with a password key, for the tests on the JSON key path.
	 */
	private static final String PASSWORD_JSON = '{"password":"hunter2"}';

	/**
	 * @description A plain text value that a pattern matching any text would replace in full.
	 */
	private static final String PLAIN_VALUE = 'some value';

	/**
	 * @description A JSON key pattern that matches only the key named password.
	 */
	private static final String PASSWORD_KEY_PATTERN = '^password$';

	/**
	 * @description What the password key rule puts in place of the password.
	 */
	private static final String PASSWORD_REPLACEMENT = '***';

	/**
	 * @description A pattern that matches any text, so a rule with it replaces the whole value.
	 */
	private static final String WHOLE_VALUE_PATTERN = '(?s).+';

	/**
	 * @description What the rule with the whole value pattern puts in place of the value.
	 */
	private static final String WHOLE_VALUE_REPLACEMENT = '[TEXT_REDACTED]';

	/**
	 * @description The name of the target that names one field and is built the way a deployed target is read.
	 */
	private static final String DEPLOYED_FIELD_TARGET_NAME = 'FoobarTextTarget';

	/**
	 * @description A stored field value in the shape a deployed target keeps (the object's durable Id and the
	 * field's Id, joined by a dot) that matches no field in the org, as it reads after the field was deleted.
	 */
	private static final String DELETED_FIELD_DURABLE_ID = '01I000000000000.00N000000000000';

	/**
	 * @description How many numbers the card pattern finds in a full-length text of a digit and a separator repeated:
	 * 65,536 digits make 3,449 numbers of 19 digits. With a card number in the middle the count is the same: the card
	 * number is one of them.
	 */
	private static final Integer NUMBERS_IN_A_FULL_SEPARATED_DIGIT_WALL = 3449;

	/**
	 * @description How many 19-digit numbers that pass the Luhn check a full-length text of them holds.
	 */
	private static final Integer NUMBERS_IN_FULL_NINETEEN_DIGIT_GROUPS = 6553;

	/**
	 * @description How many different card numbers a full-length list of card numbers holds.
	 */
	private static final Integer NUMBERS_IN_A_FULL_CARD_DUMP = 7710;

	/**
	 * @description How many digits end the full-length text of 19-digit numbers: the text is cut after 12 digits of a last
	 * number, which is too short for a card number and stays.
	 */
	private static final Integer DIGITS_LEFT_AFTER_THE_LAST_GROUP = 12;

	/**
	 * @description Every digit, to check that no digit is left in a masked text.
	 */
	private static final String DIGITS = '0123456789';

	/**
	 * @description A 16-digit Visa test number that passes the Luhn check, placed in the middle of the long digit texts.
	 */
	private static final String VISA_TEST_CARD = '4111111111111111';

	/**
	 * @description A 19-digit number that passes the Luhn check, followed by a space: the unit the long text of 19-digit
	 * numbers repeats.
	 */
	private static final String NINETEEN_DIGIT_GROUP = '4111111111111111110 ';

	/**
	 * @description The digit the long digit texts are made of.
	 */
	private static final String DIGIT_ONE = '1';

	/**
	 * @description The digit used to pad a card number body on the left.
	 */
	private static final String DIGIT_ZERO = '0';

	/**
	 * @description A hyphen, the second separator the card pattern allows between two digits.
	 */
	private static final String HYPHEN = '-';

	/**
	 * @description Character code of the digit 0. A digit is its character code minus this value.
	 */
	private static final Integer ZERO_CHARACTER_CODE = 48;

	/**
	 * @description The first digit of every number in the long list of card numbers, as a Visa number has.
	 */
	private static final String VISA_FIRST_DIGIT = '4';

	/**
	 * @description How many digits follow the first digit and come before the check digit in a 16-digit card number.
	 */
	private static final Integer CARD_BODY_DIGITS = 14;

	/**
	 * @description The first number body used to make the long list of card numbers.
	 */
	private static final Long FIRST_CARD_BODY = 10000000000000L;

	/**
	 * @description How far apart two number bodies are in the long list of card numbers, so that every number is different.
	 */
	private static final Long CARD_BODY_STEP = 7919L;

	/**
	 * @description How many empty objects `buildAboveTheStructureLine` puts in front of a JSON value: one more than the
	 * most opening brackets a value can hold and still be read as a whole tree. So the value is read one token at a time.
	 */
	private static final Integer EMPTY_OBJECTS_ABOVE_THE_STRUCTURE_LINE = UTIL_String.JSON_STRUCTURE_LINE + 1;

	/**
	 * @description One empty JSON object followed by a comma, the unit `buildAboveTheStructureLine` repeats.
	 */
	private static final String EMPTY_OBJECT_IN_A_LIST = '{},';

	/**
	 * @description One level of the deep nests: an object whose only key holds the next level.
	 */
	private static final String NEST_LEVEL_OPENING = '{"a":';

	/**
	 * @description The closing brace of one level of the deep nests.
	 */
	private static final String NEST_LEVEL_CLOSING = '}';

	/**
	 * @description The object with a secret key at the bottom of the deep nests that hold one.
	 */
	private static final String DEEP_TOKEN_OBJECT = '{"token":"deep"}';

	/**
	 * @description One object of the full-length token list, followed by a comma.
	 */
	private static final String TOKEN_OBJECT_IN_A_LIST = '{"token":"x"},';

	/**
	 * @description The start of a token key and its value as the token list writes it, before any masking.
	 */
	private static final String TOKEN_VALUE_IN_CLEAR = '"token":"x';

	/**
	 * @description How many objects with a token the full-length token list holds before its last, padded object.
	 */
	private static final Integer FULL_OBJECTS_IN_THE_TOKEN_LIST = 9000;

	/**
	 * @description How many token values the full-length token list holds: the full objects and the padded last one.
	 */
	private static final Integer TOKENS_IN_THE_FULL_TOKEN_LIST = FULL_OBJECTS_IN_THE_TOKEN_LIST + 1;

	/**
	 * @description The length at which the token list is cut to make text that is not JSON: inside the value of its last
	 * token, so the text ends in an open string.
	 */
	private static final Integer TOKEN_LIST_CUT_LENGTH = 131000;

	/**
	 * @description The depth of the smaller deep nest. A whole-tree JSON reader ends the transaction at this depth.
	 */
	private static final Integer TWO_THOUSAND_LEVELS = 2000;

	/**
	 * @description The depth of the larger deep nest, which nearly fills a field of full length.
	 */
	private static final Integer TWENTY_ONE_THOUSAND_LEVELS = 21000;

	/**
	 * @description A depth past the 50 levels at which the tree walk stops looking for keys.
	 */
	private static final Integer SIXTY_LEVELS = 60;

	/**
	 * @description The word the tests on the masker's memory treat as a secret.
	 */
	private static final String SECRET_WORD = 'secret';

	/**
	 * @description What the rule in the tests on the masker's memory writes in place of the secret word.
	 */
	private static final String SECRET_WORD_REPLACEMENT = 'X';

	/**
	 * @description A short text that holds the secret word once.
	 */
	private static final String TEXT_WITH_A_SECRET = 'the secret is here';

	/**
	 * @description The same short text after the rule replaced the secret word.
	 */
	private static final String MASKED_TEXT_WITH_A_SECRET = 'the X is here';

	/**
	 * @description What the email rule in the tests on fields no one can write puts in place of the address.
	 */
	private static final String EMAIL_REPLACEMENT = '[EMAIL_HIDDEN]';

	/**
	 * @description Where the masker writes its warning when the platform refuses the masked value for a field.
	 */
	private static final String WRITE_REFUSED_WARNING_LOCATION = UTIL_FrameworkMasker.class.getName() + UTIL_String.DOT + 'applyFieldPlanToRecord';

	/**
	 * @description The flood-control key on the warning that the platform refused the masked value for `Case.ContactEmail`.
	 */
	private static final String WRITE_REFUSED_FINGERPRINT = 'masking:write-refused:'
			+ UTIL_SObjectDescribe.getObjectNameFromType(Case.SObjectType) + UTIL_String.DOT + UTIL_SObjectDescribe.getCachedFieldName(Case.ContactEmail);

	/**
	 * @description The short text with the secret word, changed after it was registered as masked.
	 */
	private static final String CHANGED_TEXT_WITH_A_SECRET = 'the secret is there';

	/**
	 * @description The changed short text after the rule replaced the secret word.
	 */
	private static final String MASKED_CHANGED_TEXT_WITH_A_SECRET = 'the X is there';

	/**
	 * @description A short text without the secret word, so the rule changes nothing in it.
	 */
	private static final String TEXT_WITHOUT_A_SECRET = 'nothing to hide';

	/**
	 * @description How many times the text without a secret is repeated to make a text longer than `Foobar__c.Text__c`.
	 */
	private static final Integer REPEATS_PAST_THE_TEXT_FIELD = 20;

	/**
	 * @description A second caller class name, so a test can show that what the masker knows under one caller is not
	 * used for another caller.
	 */
	private static final String OTHER_CALLER = 'API_Other';

	/**
	 * @description The letter the growing rule replaces. A text made only of this letter grows three times longer when
	 * it is masked, so its masked text is too long for its field and must be cut.
	 */
	private static final String GROWING_LETTER = 'a';

	/**
	 * @description What the growing rule writes in place of each letter: three characters for one.
	 */
	private static final String GROWING_LETTER_REPLACEMENT = '[A]';

	/**
	 * @description How many letters the growing texts hold: 200 letters become 600 characters when masked, more than
	 * the 255 characters `Foobar__c.Text__c` can hold.
	 */
	private static final Integer GROWING_LETTER_COUNT = 200;

	/**
	 * @description A letter the growing rule leaves as it is. It pads a growing text so that its masked text has an exact
	 * length.
	 */
	private static final String LETTER_NO_RULE_CHANGES = 'b';

	/**
	 * @description A value the one-group pattern matches, so the rule with a replacement that names a second group fails
	 * on it.
	 */
	private static final String VALUE_THE_ONE_GROUP_PATTERN_MATCHES = 'aab';

	/**
	 * @description A text made only of spaces. Its SHA-256 hash is not computed, so the masker never remembers it.
	 */
	private static final String SPACES_ONLY_TEXT = '   ';

	/**
	 * @description A JSON Web Token in the shape the shipped token rule finds: a header, a payload and a signature, joined
	 * by dots.
	 */
	private static final String WEB_TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4ifQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

	/**
	 * @description The length of the longest value the masking reads: 2,000,000 characters.
	 */
	private static final Integer LONGEST_VALUE_LENGTH = 2000000;

	/**
	 * @description Ordinary text without a token: a digit and a space.
	 */
	private static final String DIGIT_AND_SPACE = '1 ';

	/**
	 * @description The key of the padding text in the value that `OBJECT_UNDER_A_SECRET_KEY_HEAD` starts.
	 */
	private static final String PADDING_KEY = 'pad';

	/**
	 * @description The character the padding text is made of.
	 */
	private static final String PADDING_CHARACTER = 'v';

	/**
	 * @description The start of a JSON object whose secret key holds an object, followed by the start of a padding text.
	 * The text search cannot hide an object safely, so it puts the failure marker in place of the whole value. Reading
	 * the value as JSON replaces the object.
	 */
	private static final String OBJECT_UNDER_A_SECRET_KEY_HEAD = '{"token":{"k":"v"},"' + PADDING_KEY + '":"';

	/**
	 * @description The end of the padding text and of the object that `OBJECT_UNDER_A_SECRET_KEY_HEAD` starts.
	 */
	private static final String PADDED_OBJECT_TAIL = '"}';

	/**
	 * @description The key that holds an object in the value that `OBJECT_UNDER_A_SECRET_KEY_HEAD` starts.
	 */
	private static final String SECRET_KEY_HOLDING_AN_OBJECT = 'token';

	/**
	 * @description A key pattern with two key names: `password`, and `pass"word`, a name with a quote inside it. In JSON
	 * text the quote inside a key is written with a backslash before it.
	 */
	private static final String ESCAPED_KEY_NAMES_PATTERN = '^(password|pass"word)$';

	/**
	 * @description The start of a JSON object whose secret keys are written with JSON escapes, followed by the start of a
	 * padding text. The first key reads `password`: its letter a is written as a backslash, the letter u and the
	 * hexadecimal digits 0061. The second key reads `pass"word`: a backslash before a quote stands for the quote.
	 */
	private static final String KEYS_WRITTEN_WITH_ESCAPES_HEAD = '{"p\\u0061ssword":"hunter2","pass\\"word":"hunter3","' + PADDING_KEY + '":"';

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
	 * @description How many spaces sit between a secret key and its colon, or between the colon and the secret, in the
	 * test of a long run of spaces that the text search can still read. The text search reads at most 262,144 characters
	 * from the start of a key in one try, so the whole pair fits in what it reads. The value is still longer than
	 * `UTIL_FrameworkMasker.SYNCHRONOUS_JSON_TEXT_PASS_LINE`, so it takes the text search.
	 */
	private static final Integer SPACES_BELOW_THE_PAIR_READ_LENGTH = 200000;

	/**
	 * @description The secret text in the tests of a long run of spaces around a colon.
	 */
	private static final String PASSWORD_VALUE = 'hunter2';

	/**
	 * @description A rule pattern with two alternatives that can overlap: a `secret=` pair up to its `&`, or any six
	 * digits in a row. The digits inside the pair are part of the longer first match.
	 */
	private static final String OVERLAPPING_ALTERNATIVES_PATTERN = 'secret=[^&]*&|[0-9]{6}';

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
	 * @description The text written in place of each match of `OVERLAPPING_ALTERNATIVES_PATTERN`.
	 */
	private static final String PAIR_REPLACEMENT = '[X]';

	/**
	 * @description How many characters before the end of the first piece of the pattern search `SECRET_PAIR` starts. The
	 * piece end then cuts the pair after `secret=abc123456789x`, so a whole run of six digits lies inside the piece.
	 */
	private static final Integer PAIR_START_BEFORE_THE_PIECE_END = 20;

	/**
	 * @description The length of the value in the test of a pair cut by the end of a piece of the pattern search. The
	 * value takes three pieces.
	 */
	private static final Integer THREE_PIECE_VALUE_LENGTH = 300000;

	/**
	 * @description How many characters of a masked text an assertion message shows, so a failed test says what was left
	 * in clear.
	 */
	private static final Integer MESSAGE_WINDOW_LENGTH = 40;

	/**
	 * @description The masking result the Queueable of the running test produced.
	 */
	private static UTIL_FrameworkMasker.MaskingResult resultMaskedInQueueable;

	/**
	 * @description Creates a separate test admin user, so System.runAs in each test starts with fresh
	 * permission checks. This avoids a problem in test orgs where cached permissions went stale when
	 * the running user's permission sets changed during a transaction. Also commits a low-privilege
	 * user (Minimum Access - Salesforce profile), so the low-privilege test
	 * (shouldMaskRecordForLowPrivilegeUser) can use System.runAs without causing
	 * MIXED_DML_OPERATION. User is a Setup object, and DML on users cannot be mixed with DML on
	 * standard or custom objects in the same transaction; creating the user here avoids that.
	 */
	@TestSetup
	private static void setupTestUsers()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);

		User lowPrivilegeUser = TST_Factory.newMinimumAccessUser(LOW_PRIVILEGE_COMPANY);
		insert lowPrivilegeUser;
	}

	/**
	 * @description Tests that isMaskingEnabled returns true when the flag is active.
	 */
	@IsTest
	private static void isMaskingEnabledShouldReturnTrueWhenFlagIsActive()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);

			Assert.isTrue(UTIL_FrameworkMasker.isMaskingEnabled, 'isMaskingEnabled should return true when the flag is on');
		}
	}

	/**
	 * @description Tests that isMaskingEnabled returns false when an admin overrides the
	 * shipped default to disable the framework (simulated by removing it from the active
	 * flag cache).
	 */
	@IsTest
	private static void isMaskingEnabledShouldReturnFalseWhenFlagOverriddenOff()
	{
		System.runAs(getTestAdmin())
		{
			SEL_FeatureFlag.activeFlags.remove(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);

			Assert.isFalse(UTIL_FrameworkMasker.isMaskingEnabled, 'isMaskingEnabled should return false when the flag is disabled');
		}
	}

	/**
	 * @description Tests that isMaskingEnabled caches the result per transaction.
	 */
	@IsTest
	private static void isMaskingEnabledShouldCachePerTransaction()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);

			Boolean firstCall = UTIL_FrameworkMasker.isMaskingEnabled;
			Boolean secondCall = UTIL_FrameworkMasker.isMaskingEnabled;

			Assert.areEqual(firstCall, secondCall, 'Repeated reads should return the same cached value');
		}
	}

	/**
	 * @description Tests that mask returns the input unchanged in the skeleton.
	 */
	@IsTest
	private static void shouldPassInputThroughInSkeleton()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Email__c).mask(SAMPLE_VALUE);

			Assert.areEqual(SAMPLE_VALUE, result.maskedValue, 'maskedValue should equal input in the skeleton');
			Assert.areEqual(SAMPLE_VALUE.length(), result.originalLength, 'originalLength should reflect the input');
			Assert.areEqual(SAMPLE_VALUE.length(), result.maskedLength, 'maskedLength should equal originalLength when no changes');
		}
	}

	/**
	 * @description Tests that mask handles null input.
	 */
	@IsTest
	private static void shouldHandleNullValue()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Email__c).mask(null);

			Assert.isNull(result.maskedValue, 'maskedValue should be null for null input');
			Assert.areEqual(0, result.originalLength, 'originalLength should be 0 for null input');
			Assert.areEqual(0, result.maskedLength, 'maskedLength should be 0 for null input');
		}
	}

	/**
	 * @description Tests that calledFrom is persisted on the FieldMasker builder.
	 */
	@IsTest
	private static void shouldRecordCalledFromOnFieldMasker()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.FieldMasker masker = UTIL_FrameworkMasker.forField(Foobar__c.Email__c).calledFrom(SAMPLE_CALLER);

			Assert.areEqual(SAMPLE_CALLER, masker.callerClassName, 'calledFrom should be stored on the builder');
		}
	}

	/**
	 * @description Tests that RecordMasker.apply returns a non-null, error-free result for a
	 * record with no masking targets configured for its SObjectType.
	 */
	@IsTest
	private static void shouldApplyToSingleRecord()
	{
		System.runAs(getTestAdmin())
		{
			SObject record = TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.isNotNull(result, 'apply should return a result');
			Assert.isFalse(result.hadErrors, 'hadErrors should be false when no rules fire');
			Assert.areEqual(0, result.rulesMatched, 'No rules should have matched');
		}
	}

	/**
	 * @description Tests that calledFrom is persisted on the RecordMasker builder.
	 */
	@IsTest
	private static void shouldRecordCalledFromOnRecordMasker()
	{
		System.runAs(getTestAdmin())
		{
			SObject record = TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

			UTIL_FrameworkMasker.RecordMasker masker = UTIL_FrameworkMasker.forRecord(record).calledFrom(SAMPLE_CALLER);

			Assert.areEqual(SAMPLE_CALLER, masker.callerClassName, 'calledFrom should be stored on the builder');
		}
	}

	/**
	 * @description Tests that BulkRecordMasker returns one result per input record.
	 */
	@IsTest
	private static void shouldReturnResultsForEveryRecord()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().withCount(2).buildList();

			List<UTIL_FrameworkMasker.MaskingResult> results = UTIL_FrameworkMasker.forRecords(records).apply();

			Assert.areEqual(2, results.size(), 'Should return one result per input record');
			Assert.isFalse(results.get(0).hadErrors, 'First result should be clean when no rules fire');
			Assert.isFalse(results.get(1).hadErrors, 'Second result should be clean when no rules fire');
		}
	}

	/**
	 * @description Tests that BulkRecordMasker handles null gracefully.
	 */
	@IsTest
	private static void shouldHandleNullRecordsList()
	{
		System.runAs(getTestAdmin())
		{
			List<UTIL_FrameworkMasker.MaskingResult> results = UTIL_FrameworkMasker.forRecords(null).apply();

			Assert.isNotNull(results, 'Should return an empty list, not null, for null input');
			Assert.isTrue(results.isEmpty(), 'Should return empty list for null input');
		}
	}

	/**
	 * @description Tests that calledFrom is persisted on the BulkRecordMasker builder.
	 */
	@IsTest
	private static void shouldRecordCalledFromOnBulkRecordMasker()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.BulkRecordMasker masker = UTIL_FrameworkMasker.forRecords(new List<SObject>()).calledFrom(SAMPLE_CALLER);

			Assert.areEqual(SAMPLE_CALLER, masker.callerClassName, 'calledFrom should be stored on the builder');
		}
	}

	/**
	 * @description Tests that RecordMasker.apply masks a configured field in place and
	 * aggregates the match count on the returned result.
	 */
	@IsTest
	private static void shouldMaskConfiguredFieldOnRecord()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'the secret is here')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual('the X is here', record.Text__c, 'Field value should be masked in place on the record');
			Assert.areEqual(1, result.rulesMatched, 'Aggregate rulesMatched should reflect the single match');
		}
	}

	/**
	 * @description Tests that RecordMasker aggregates matches across multiple fields on a
	 * single record when several targets are configured.
	 */
	@IsTest
	private static void shouldAggregateMatchesAcrossFields()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'one', 'X', null, 'RuleOne', 10);
			mockTargetForFoobarTextArea(SEL_MaskingRule.MODE_EXACT_MATCH, 'two', 'Y', null, 'RuleTwo', 20);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'value one')
					.withOverride(Foobar__c.TextArea__c, 'value two')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual('value X', record.Text__c, 'Text__c should be masked');
			Assert.areEqual('value Y', record.TextArea__c, 'TextArea__c should be masked');
			Assert.areEqual(2, result.rulesMatched, 'Aggregate should count both field-level matches');
		}
	}

	/**
	 * @description Tests that RecordMasker skips fields that are null/unpopulated on the
	 * record: no attempt to mask, no error.
	 */
	@IsTest
	private static void shouldSkipUnpopulatedFieldsOnRecord()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();
			record.Text__c = null;

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(0, result.rulesMatched, 'No rules should fire when the field is null');
			Assert.isFalse(result.hadErrors, 'Null-field skip is not a failure');
		}
	}

	/**
	 * @description Tests that BulkRecordMasker masks every record in place with a shared rule.
	 */
	@IsTest
	private static void shouldMaskRecordsInBulk()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);

			Foobar__c firstRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'first secret')
					.withoutInsertion()
					.build();
			Foobar__c secondRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'second secret')
					.withoutInsertion()
					.build();

			List<UTIL_FrameworkMasker.MaskingResult> results = UTIL_FrameworkMasker.forRecords(new List<SObject> {firstRecord, secondRecord}).apply();

			Assert.areEqual('first X', firstRecord.Text__c, 'First record should be masked');
			Assert.areEqual('second X', secondRecord.Text__c, 'Second record should be masked');
			Assert.areEqual(2, results.size(), 'One result per input record');
		}
	}

	/**
	 * @description Tests that a BlockDml rule failure during RecordMasker.apply propagates
	 * `MaskingBlockedException` out of the terminal, halting processing.
	 */
	@IsTest
	private static void shouldPropagateBlockDmlExceptionFromRecordMasker()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithFailureAction(SEL_MaskingRule.MODE_REGEX, '([bad', 'X', null, SEL_MaskingRule.FAILURE_BLOCK_DML);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'some value')
					.withoutInsertion()
					.build();

			try
			{
				UTIL_FrameworkMasker.forRecord(record).apply();
				Assert.fail('RecordMasker should propagate MaskingBlockedException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.MaskingBlockedException.class, 'Should throw MaskingBlockedException');
			}
		}
	}

	/**
	 * @description Tests that a BlockDml failure on the first record halts the bulk masker
	 * at once: later records should not be touched.
	 */
	@IsTest
	private static void shouldFastExitBulkMaskerOnBlockDmlFailure()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithFailureAction(SEL_MaskingRule.MODE_REGEX, '([bad', 'X', null, SEL_MaskingRule.FAILURE_BLOCK_DML);

			Foobar__c firstRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'first')
					.withoutInsertion()
					.build();
			Foobar__c secondRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'second')
					.withoutInsertion()
					.build();

			try
			{
				UTIL_FrameworkMasker.forRecords(new List<SObject> {firstRecord, secondRecord}).apply();
				Assert.fail('BulkRecordMasker should propagate MaskingBlockedException');
			}
			catch(UTIL_Exceptions.MaskingBlockedException error)
			{
				Assert.areEqual('first', firstRecord.Text__c, 'First record must not have been partially mutated');
				Assert.areEqual('second', secondRecord.Text__c, 'Second record must not have been processed');
			}
		}
	}

	/**
	 * @description Tests that forRecord(null).apply does not throw and returns an empty result.
	 */
	@IsTest
	private static void shouldHandleNullRecordArgument()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(null).apply();

			Assert.isNotNull(result, 'apply should return a result even for null input');
			Assert.areEqual(0, result.rulesMatched, 'No rules should match when there is no record');
			Assert.isFalse(result.hadErrors, 'Null record is not a failure');
		}
	}

	/**
	 * @description Tests that RecordMasker.apply aggregates rule-failure metadata (hadErrors
	 * and failedRuleDeveloperNames) from a LogAndContinue rule failure up to the record-level
	 * result.
	 */
	@IsTest
	private static void shouldAggregateRuleFailureOnRecord()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_REGEX, '([bad', 'X', null);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'some value')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.isTrue(result.hadErrors, 'Record-level result should surface field-level failures');
			Assert.areEqual(1, result.failedRuleDeveloperNames.size(), 'Failed rule name should bubble up');
			Assert.areEqual('TestRule', result.failedRuleDeveloperNames.get(0), 'Failed rule name should match');
		}
	}

	/**
	 * @description Tests that a MaskingTarget pointing at a field that does not exist on the
	 * SObjectType is skipped without notice. This protects against admin setup that is out of date.
	 */
	@IsTest
	private static void shouldSkipTargetReferencingMissingField()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('TestRule', SEL_MaskingRule.MODE_EXACT_MATCH, 'x', 'y', 10)
					.withoutInsertion(true)
					.build();
			registerMockTarget(rule, 'NonExistentField__c', null);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'x here')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(0, result.rulesMatched, 'Target pointing at non-existent field should be a no-op');
			Assert.areEqual('x here', record.Text__c, 'Record should be untouched');
		}
	}

	/**
	 * @description Tests that a MaskingTarget whose Field__c is malformed (no object prefix /
	 * dot separator) is silently skipped rather than crashing.
	 */
	@IsTest
	private static void shouldSkipTargetWithMalformedFieldPath()
	{
		System.runAs(getTestAdmin())
		{
			String foobarName = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);

			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('TestRule', SEL_MaskingRule.MODE_EXACT_MATCH, 'x', 'y', 10)
					.withoutInsertion(true)
					.build();

			TST_Mock.of(MaskingTarget__mdt.SObjectType)
					.withOverride(MaskingTarget__mdt.IsActive__c, true)
					.withOverride(MaskingTarget__mdt.SObjectType__c, foobarName)
					.withOverride(MaskingTarget__mdt.Field__c, 'NoDotHere')
					.withOverride(MaskingTarget__mdt.Rule__c, rule)
					.build();

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'x here')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(0, result.rulesMatched, 'Malformed target Field__c should be a no-op');
			Assert.areEqual('x here', record.Text__c, 'Record should be untouched');
		}
	}

	/**
	 * @description Tests that RecordMasker respects the calledFrom caller when it goes through fields:
	 * rules limited to a caller only run when the caller matches.
	 */
	@IsTest
	private static void shouldHonourCallerScopeOnRecord()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', 'API_SendEmail');

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'the secret here')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.MaskingResult wrongCaller = UTIL_FrameworkMasker.forRecord(record).calledFrom('API_Other').apply();

			Assert.areEqual('the secret here', record.Text__c, 'Scoped rule should not fire for non-matching caller');
			Assert.areEqual(0, wrongCaller.rulesMatched, 'No rules should have matched');

			UTIL_FrameworkMasker.MaskingResult rightCaller = UTIL_FrameworkMasker.forRecord(record).calledFrom('API_SendEmail').apply();

			Assert.areEqual('the X here', record.Text__c, 'Scoped rule should fire when caller matches');
			Assert.areEqual(1, rightCaller.rulesMatched, 'Caller-matching call should record the match');
		}
	}

	/**
	 * @description Proves that the masker answers FITTED for a value whose masked text fits in its field: both a value a
	 * rule changed and a value no rule changed. On this answer a caller knows the field holds the whole masked value, so
	 * it does not mask the raw value again. A call with no caller and a call with an empty caller name ask the same thing.
	 */
	@IsTest
	private static void shouldAnswerFittedForAValueThatWasMaskedAndFits()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, SECRET_WORD, SECRET_WORD_REPLACEMENT, null);
			Foobar__c maskedRecord = buildFoobarWithText(TEXT_WITH_A_SECRET);
			Foobar__c unchangedRecord = buildFoobarWithText(TEXT_WITHOUT_A_SECRET);

			UTIL_FrameworkMasker.forRecords(new List<SObject> {maskedRecord, unchangedRecord}).apply();

			UTIL_FrameworkMasker.MaskedValueAnswer maskedAnswer = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, UTIL_String.EMPTY, TEXT_WITH_A_SECRET);
			UTIL_FrameworkMasker.MaskedValueAnswer unchangedAnswer = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, null, TEXT_WITHOUT_A_SECRET);

			Assert.areEqual(MASKED_TEXT_WITH_A_SECRET, maskedRecord.Text__c, 'Expected the rule to mask the secret word on the record');
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.FITTED, maskedAnswer.state, 'Expected a masked value that fits its field to be answered as fitted');
			Assert.isNull(maskedAnswer.uncutMaskedValue, 'Expected no remembered text for a value that was not cut');
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.FITTED, unchangedAnswer.state, 'Expected a value no rule changed to be answered as fitted');
		}
	}

	/**
	 * @description Proves that the masker answers NOT_SEEN for a value no masking pass masked in this transaction, and
	 * for a value longer than its field that no rule changed: the masker cannot say that such a value fits. On this
	 * answer a caller masks the raw value again.
	 */
	@IsTest
	private static void shouldAnswerNotSeenForAValueNoPassMasked()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, SECRET_WORD, SECRET_WORD_REPLACEMENT, null);
			String longTextWithoutASecret = TEXT_WITHOUT_A_SECRET.repeat(REPEATS_PAST_THE_TEXT_FIELD);

			UTIL_FrameworkMasker.forRecords(new List<SObject> {buildFoobarWithText(TEXT_WITH_A_SECRET)}).apply();
			UTIL_FrameworkMasker.MaskingResult longResult = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask(longTextWithoutASecret);

			UTIL_FrameworkMasker.MaskedValueAnswer otherAnswer = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, null, CHANGED_TEXT_WITH_A_SECRET);
			UTIL_FrameworkMasker.MaskedValueAnswer longAnswer = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, null, longTextWithoutASecret);

			Assert.areEqual(longTextWithoutASecret, longResult.maskedValue, 'Expected a long value no rule changed to come back whole');
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.NOT_SEEN, otherAnswer.state, 'Expected a value no pass masked to be answered as not seen');
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.NOT_SEEN, longAnswer.state, 'Expected a long value no rule changed to be answered as not seen');
			Assert.isNull(otherAnswer.uncutMaskedValue, 'Expected no remembered text for a value no pass masked');
		}
	}

	/**
	 * @description Proves that the masker keeps the whole masked text of a value it had to cut to fit its field, and
	 * hands it over once. The second question about the same value answers NOT_SEEN: the text is gone, so the caller
	 * masks the raw value again instead of saving a cut value as if it were whole.
	 */
	@IsTest
	private static void shouldRememberTheUncutTextWhenTheMaskedValueWasCut()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, GROWING_LETTER, GROWING_LETTER_REPLACEMENT, null);
			String rawValue = GROWING_LETTER.repeat(GROWING_LETTER_COUNT);
			Foobar__c record = buildFoobarWithText(rawValue);

			UTIL_FrameworkMasker.forRecords(new List<SObject> {record}).apply();

			UTIL_FrameworkMasker.MaskedValueAnswer firstAnswer = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, null, rawValue);
			UTIL_FrameworkMasker.MaskedValueAnswer secondAnswer = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, null, rawValue);

			Assert.isTrue(record.Text__c.length() <= getTextFieldLength(), 'Expected the masked value on the record to be cut to fit the field');
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.REMEMBERED, firstAnswer.state, 'Expected a cut value to be answered as remembered');
			Assert.areEqual(GROWING_LETTER_REPLACEMENT.repeat(GROWING_LETTER_COUNT), firstAnswer.uncutMaskedValue, 'Expected the whole masked text to be handed over');
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.NOT_SEEN, secondAnswer.state, 'Expected a remembered text to be handed over only once');
			Assert.isNull(secondAnswer.uncutMaskedValue, 'Expected no text the second time');
		}
	}

	/**
	 * @description Proves that the masker stops keeping whole masked texts once the next one would pass the cap, and
	 * answers DROPPED for that value. The first value's masked text is exactly as long as the cap, so it is kept and
	 * leaves no room. The value on the record is still masked and cut to fit: only the copy of the whole masked text is
	 * not kept, and the caller masks the raw value again when it needs the whole text.
	 */
	@IsTest
	private static void shouldAnswerDroppedPastTheCap()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, GROWING_LETTER, GROWING_LETTER_REPLACEMENT, null);
			String firstRawValue = buildRawValueMaskedToLength(UTIL_FrameworkMasker.REMEMBERED_TEXT_CAP);
			String secondRawValue = GROWING_LETTER.repeat(GROWING_LETTER_COUNT);
			Foobar__c secondRecord = buildFoobarWithText(secondRawValue);

			UTIL_FrameworkMasker.forRecords(new List<SObject> {buildFoobarWithText(firstRawValue), secondRecord}).apply();

			UTIL_FrameworkMasker.MaskedValueAnswer firstAnswer = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, null, firstRawValue);
			UTIL_FrameworkMasker.MaskedValueAnswer secondAnswer = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, null, secondRawValue);

			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.REMEMBERED, firstAnswer.state, 'Expected the value that fills the cap exactly to be remembered');
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.DROPPED, secondAnswer.state, 'Expected the value past the cap to be answered as dropped');
			Assert.isNull(secondAnswer.uncutMaskedValue, 'Expected no text for a dropped value');
			Assert.isTrue(secondRecord.Text__c.startsWith(GROWING_LETTER_REPLACEMENT), 'Expected the dropped value to be masked on the record all the same');
			Assert.isTrue(secondRecord.Text__c.length() <= getTextFieldLength(), 'Expected the dropped value to be cut to fit the field all the same');
		}
	}

	/**
	 * @description Proves that maskAndReturnWholeText hands the whole masked text straight to the caller, even when the
	 * cap would stop the masker from keeping any of it: the text that fits the field is cut, the whole text is returned
	 * beside it, and the masker keeps nothing, so a later answer for the value is NOT_SEEN. A value whose masked text
	 * fits is answered FITTED and comes with no whole text, and an empty value comes back as it is. A first record pass
	 * fills the cap exactly, so no room is left when the whole text is handed over.
	 */
	@IsTest
	private static void shouldReturnTheWholeMaskedTextWhateverTheCap()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, GROWING_LETTER, GROWING_LETTER_REPLACEMENT, SAMPLE_CALLER);
			String capFillingRawValue = buildRawValueMaskedToLength(UTIL_FrameworkMasker.REMEMBERED_TEXT_CAP);
			UTIL_FrameworkMasker.forRecords(new List<SObject> {buildFoobarWithText(capFillingRawValue)}).calledFrom(SAMPLE_CALLER).apply();
			String rawValue = GROWING_LETTER.repeat(GROWING_LETTER_COUNT);
			UTIL_FrameworkMasker.FieldMasker masker = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).calledFrom(SAMPLE_CALLER);

			UTIL_FrameworkMasker.MaskingResult cutResult = masker.maskAndReturnWholeText(rawValue);
			UTIL_FrameworkMasker.MaskingResult fittingResult = masker.maskAndReturnWholeText(GROWING_LETTER);
			UTIL_FrameworkMasker.MaskingResult emptyResult = masker.maskAndReturnWholeText(UTIL_String.EMPTY);

			Assert.areEqual(GROWING_LETTER_REPLACEMENT.repeat(GROWING_LETTER_COUNT), cutResult.uncutMaskedValue, 'Expected the whole masked text beside the cut one');
			Assert.areEqual(getTextFieldLength(), cutResult.maskedValue.length(), 'Expected the masked text cut to the field length');
			UTIL_FrameworkMasker.MaskedValueState cutState = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, SAMPLE_CALLER, rawValue).state;
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.NOT_SEEN, cutState, 'Expected the masker to keep nothing for a text it handed over, got ' + cutState);
			Assert.isNull(fittingResult.uncutMaskedValue, 'Expected no whole text for a masked text that fits');
			UTIL_FrameworkMasker.MaskedValueState fittingState = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, SAMPLE_CALLER, GROWING_LETTER).state;
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.FITTED, fittingState, 'Expected a masked text that fits to be answered as fitted, got ' + fittingState);
			Assert.areEqual(UTIL_String.EMPTY, emptyResult.maskedValue, 'Expected an empty value to come back as it is');
			Assert.isNull(emptyResult.uncutMaskedValue, 'Expected no whole text for an empty value');
			UTIL_FrameworkMasker.MaskedValueState capFillingState = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, SAMPLE_CALLER, capFillingRawValue).state;
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.REMEMBERED, capFillingState, 'Expected the text that fills the cap to be kept, got ' + capFillingState);
		}
	}

	/**
	 * @description Proves that a field whose text was registered as already masked, for the same field and caller, is
	 * left as it is and no rule runs on it. The text registered here still holds the secret word, so a rule that ran
	 * would change it. Also proves that the masker registers the text it writes: a second pass over a record it already
	 * masked skips the field.
	 */
	@IsTest
	private static void shouldSkipAFieldWhoseTextIsRegisteredUnderTheSameCaller()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, SECRET_WORD, SECRET_WORD_REPLACEMENT, null);
			Foobar__c registeredRecord = buildFoobarWithText(TEXT_WITH_A_SECRET);
			Foobar__c storedRecord = buildFoobarWithText(CHANGED_TEXT_WITH_A_SECRET);

			UTIL_FrameworkMasker.registerMaskedFieldText(Foobar__c.Text__c, SAMPLE_CALLER, TEXT_WITH_A_SECRET);
			UTIL_FrameworkMasker.MaskingResult registeredResult = UTIL_FrameworkMasker.forRecords(new List<SObject> {registeredRecord}).calledFrom(SAMPLE_CALLER).apply().get(0);
			UTIL_FrameworkMasker.MaskingResult firstPass = UTIL_FrameworkMasker.forRecords(new List<SObject> {storedRecord}).calledFrom(SAMPLE_CALLER).apply().get(0);
			UTIL_FrameworkMasker.MaskingResult secondPass = UTIL_FrameworkMasker.forRecords(new List<SObject> {storedRecord}).calledFrom(SAMPLE_CALLER).apply().get(0);

			Assert.areEqual(TEXT_WITH_A_SECRET, registeredRecord.Text__c, 'Expected the registered text to be left as it is');
			Assert.areEqual(0, registeredResult.rulesMatched, 'Expected no rule to run on the registered text');
			Assert.areEqual(1, registeredResult.fieldsSkippedAsAlreadyMasked, 'Expected the skip to be counted');
			Assert.areEqual(MASKED_CHANGED_TEXT_WITH_A_SECRET, storedRecord.Text__c, 'Expected the first pass to mask the text');
			Assert.areEqual(0, firstPass.fieldsSkippedAsAlreadyMasked, 'Expected the first pass not to skip a text nobody registered');
			Assert.areEqual(1, secondPass.fieldsSkippedAsAlreadyMasked, 'Expected the second pass to skip the text the first pass wrote');
			Assert.areEqual(0, secondPass.rulesMatched, 'Expected no rule to run on the text the first pass wrote');
		}
	}

	/**
	 * @description Proves that a text registered as masked for one caller is masked as usual for another caller,
	 * in both directions: a named caller does not use a registration made for another named caller, and a call with no
	 * caller does not use a registration made for a named caller. Two callers can have different rules, so a text masked
	 * with one caller's rules is not masked enough for the other's.
	 */
	@IsTest
	private static void shouldNotSkipAFieldRegisteredUnderAnotherCaller()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, SECRET_WORD, SECRET_WORD_REPLACEMENT, null);
			Foobar__c namedCallerRecord = buildFoobarWithText(TEXT_WITH_A_SECRET);
			Foobar__c noCallerRecord = buildFoobarWithText(TEXT_WITH_A_SECRET);

			UTIL_FrameworkMasker.registerMaskedFieldText(Foobar__c.Text__c, OTHER_CALLER, TEXT_WITH_A_SECRET);
			UTIL_FrameworkMasker.MaskingResult namedCallerResult = UTIL_FrameworkMasker.forRecords(new List<SObject> {namedCallerRecord}).calledFrom(SAMPLE_CALLER).apply().get(0);
			UTIL_FrameworkMasker.registerMaskedFieldText(Foobar__c.Text__c, SAMPLE_CALLER, TEXT_WITH_A_SECRET);
			UTIL_FrameworkMasker.MaskingResult noCallerResult = UTIL_FrameworkMasker.forRecords(new List<SObject> {noCallerRecord}).apply().get(0);

			Assert.areEqual(MASKED_TEXT_WITH_A_SECRET, namedCallerRecord.Text__c, 'Expected a text registered for another caller to be masked');
			Assert.areEqual(0, namedCallerResult.fieldsSkippedAsAlreadyMasked, 'Expected no skip for a text registered for another caller');
			Assert.areEqual(MASKED_TEXT_WITH_A_SECRET, noCallerRecord.Text__c, 'Expected a call with no caller to mask a text registered for a named caller');
			Assert.areEqual(0, noCallerResult.fieldsSkippedAsAlreadyMasked, 'Expected no skip for a call with no caller');
		}
	}

	/**
	 * @description Proves that a field whose text changed after a text was registered for it is masked as usual. The
	 * registration is for one exact text, so another step that writes a new value to the field before the save cannot
	 * get that new value past the rules.
	 */
	@IsTest
	private static void shouldNotSkipAFieldWhoseTextChangedAfterRegistration()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, SECRET_WORD, SECRET_WORD_REPLACEMENT, null);
			Foobar__c record = buildFoobarWithText(CHANGED_TEXT_WITH_A_SECRET);

			UTIL_FrameworkMasker.registerMaskedFieldText(Foobar__c.Text__c, SAMPLE_CALLER, TEXT_WITH_A_SECRET);
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecords(new List<SObject> {record}).calledFrom(SAMPLE_CALLER).apply().get(0);

			Assert.areEqual(MASKED_CHANGED_TEXT_WITH_A_SECRET, record.Text__c, 'Expected the changed text to be masked');
			Assert.areEqual(1, result.rulesMatched, 'Expected the rule to run on the changed text');
			Assert.areEqual(0, result.fieldsSkippedAsAlreadyMasked, 'Expected no skip for a text that changed after registration');
		}
	}

	/**
	 * @description Proves that masking the same raw value again, as a retry does, replaces what the masker kept for it
	 * and counts its length against the cap once. The two whole masked texts together are exactly as long as the cap, so
	 * a value counted twice would push the next value past the cap. The text the retry wrote is still registered: one
	 * more record pass over it leaves it as it is.
	 */
	@IsTest
	private static void shouldCountARetriedWriteOnceAgainstTheCap()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, GROWING_LETTER, GROWING_LETTER_REPLACEMENT, null);
			Integer firstMaskedLength = UTIL_FrameworkMasker.REMEMBERED_TEXT_CAP / GROWING_LETTER_REPLACEMENT.length();
			String firstRawValue = buildRawValueMaskedToLength(firstMaskedLength);
			String secondRawValue = buildRawValueMaskedToLength(UTIL_FrameworkMasker.REMEMBERED_TEXT_CAP - firstMaskedLength);
			Foobar__c retriedRecord = buildFoobarWithText(firstRawValue);

			UTIL_FrameworkMasker.forRecords(new List<SObject> {buildFoobarWithText(firstRawValue)}).apply();
			UTIL_FrameworkMasker.MaskingResult retriedResult = UTIL_FrameworkMasker.forRecords(new List<SObject> {retriedRecord}).apply().get(0);
			UTIL_FrameworkMasker.forRecords(new List<SObject> {buildFoobarWithText(secondRawValue)}).apply();
			UTIL_FrameworkMasker.MaskingResult passAfterRetry = UTIL_FrameworkMasker.forRecords(new List<SObject> {retriedRecord}).apply().get(0);

			UTIL_FrameworkMasker.MaskedValueAnswer firstAnswer = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, null, firstRawValue);
			UTIL_FrameworkMasker.MaskedValueAnswer secondAnswer = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, null, secondRawValue);

			Assert.areEqual(1, retriedResult.rulesMatched, 'Expected the retry to mask the raw value again');
			Assert.areEqual(1, passAfterRetry.fieldsSkippedAsAlreadyMasked, 'Expected a pass over the text the retry wrote to find it registered and skip it');
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.REMEMBERED, firstAnswer.state, 'Expected the retried value to be remembered');
			Assert.areEqual(firstRawValue.replace(GROWING_LETTER, GROWING_LETTER_REPLACEMENT), firstAnswer.uncutMaskedValue, 'Expected the whole text of the retried value');
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.REMEMBERED, secondAnswer.state, 'Expected the next value to fit under the cap, so the retry was counted once');
		}
	}

	/**
	 * @description Proves that a whole masked text the masker kept for one field and caller is never handed over for
	 * another field or another caller, even for the same raw value. Only the field and caller it was masked for get it.
	 */
	@IsTest
	private static void shouldNeverHandBackARememberedTextForAnotherField()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, GROWING_LETTER, GROWING_LETTER_REPLACEMENT, null);
			String rawValue = GROWING_LETTER.repeat(GROWING_LETTER_COUNT);

			UTIL_FrameworkMasker.forRecords(new List<SObject> {buildFoobarWithText(rawValue)}).calledFrom(SAMPLE_CALLER).apply();

			UTIL_FrameworkMasker.MaskedValueAnswer otherFieldAnswer = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.TextArea__c, SAMPLE_CALLER, rawValue);
			UTIL_FrameworkMasker.MaskedValueAnswer otherCallerAnswer = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, OTHER_CALLER, rawValue);
			UTIL_FrameworkMasker.MaskedValueAnswer sameFieldAnswer = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, SAMPLE_CALLER, rawValue);

			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.NOT_SEEN, otherFieldAnswer.state, 'Expected another field to get no answer for the value');
			Assert.isNull(otherFieldAnswer.uncutMaskedValue, 'Expected another field to get no remembered text');
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.NOT_SEEN, otherCallerAnswer.state, 'Expected another caller to get no answer for the value');
			Assert.isNull(otherCallerAnswer.uncutMaskedValue, 'Expected another caller to get no remembered text');
			Assert.areEqual(GROWING_LETTER_REPLACEMENT.repeat(GROWING_LETTER_COUNT), sameFieldAnswer.uncutMaskedValue, 'Expected the field it was masked for to get it');
		}
	}

	/**
	 * @description Proves that when a Write Failure Marker rule fails on a value, the marker that `forField` returns is
	 * answered as FITTED and registered, so a later record pass that finds the marker in the field leaves it as it is.
	 */
	@IsTest
	private static void shouldSkipTheFailureMarkerWrittenInPlaceOfAValue()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithFailureAction(SEL_MaskingRule.MODE_REGEX, ONE_GROUP_PATTERN, SECOND_GROUP_REPLACEMENT, null, SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER);

			UTIL_FrameworkMasker.MaskingResult fieldResult = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).calledFrom(SAMPLE_CALLER).mask(VALUE_THE_ONE_GROUP_PATTERN_MATCHES);
			UTIL_FrameworkMasker.MaskedValueAnswer answer = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, SAMPLE_CALLER, VALUE_THE_ONE_GROUP_PATTERN_MATCHES);
			Foobar__c record = buildFoobarWithText(fieldResult.maskedValue);
			UTIL_FrameworkMasker.MaskingResult recordResult = UTIL_FrameworkMasker.forRecords(new List<SObject> {record}).calledFrom(SAMPLE_CALLER).apply().get(0);

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, fieldResult.maskedValue, 'Expected the failed rule to write the failure marker');
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.FITTED, answer.state, 'Expected the marker to be answered as fitted');
			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, record.Text__c, 'Expected the marker to stay in the field');
			Assert.areEqual(1, recordResult.fieldsSkippedAsAlreadyMasked, 'Expected the record pass to skip the registered marker');
		}
	}

	/**
	 * @description Proves that a text made only of spaces is never registered and never remembered. Its hash is not
	 * computed, so all such texts would share one key; the masker masks each of them as usual instead.
	 */
	@IsTest
	private static void shouldNeverSkipOrRememberABlankText()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_REGEX, WHOLE_VALUE_PATTERN, WHOLE_VALUE_REPLACEMENT, null);
			Foobar__c record = buildFoobarWithText(TEXT_WITHOUT_A_SECRET);
			record.Text__c = SPACES_ONLY_TEXT;

			UTIL_FrameworkMasker.registerMaskedFieldText(Foobar__c.Text__c, SAMPLE_CALLER, SPACES_ONLY_TEXT);
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecords(new List<SObject> {record}).calledFrom(SAMPLE_CALLER).apply().get(0);
			UTIL_FrameworkMasker.MaskedValueAnswer blankAnswer = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, SAMPLE_CALLER, SPACES_ONLY_TEXT);
			UTIL_FrameworkMasker.MaskedValueAnswer nullAnswer = UTIL_FrameworkMasker.takeMaskedValueAnswer(Foobar__c.Text__c, SAMPLE_CALLER, null);

			Assert.areEqual(WHOLE_VALUE_REPLACEMENT, record.Text__c, 'Expected a text of spaces to be masked as usual');
			Assert.areEqual(0, result.fieldsSkippedAsAlreadyMasked, 'Expected no skip for a text of spaces');
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.NOT_SEEN, blankAnswer.state, 'Expected no answer for a text of spaces');
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.NOT_SEEN, nullAnswer.state, 'Expected no answer for a missing value');
		}
	}

	/**
	 * @description Tests that a Regex-mode MaskingTarget fires when mask() is called for its field.
	 */
	@IsTest
	private static void shouldApplyRegexRuleToField()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_REGEX, '\\d+', 'XXX', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('Code: 12345');

			Assert.areEqual('Code: XXX', result.maskedValue, 'Regex rule should replace the digits');
			Assert.areEqual(1, result.rulesMatched, 'One rule should have matched');
			Assert.areEqual(1, result.valuesRedacted, 'One value should be redacted');
			Assert.areEqual('TestRule', result.matchedRuleDeveloperNames.get(0), 'Matched rule name should be recorded');
		}
	}

	/**
	 * @description Tests that an ExactMatch-mode MaskingTarget replaces the exact literal.
	 */
	@IsTest
	private static void shouldApplyExactMatchRuleToField()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', '[REDACTED]', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('this secret is hidden');

			Assert.areEqual('this [REDACTED] is hidden', result.maskedValue, 'ExactMatch rule should replace the literal');
			Assert.areEqual(1, result.rulesMatched, 'One rule should have matched');
		}
	}

	/**
	 * @description Tests that a CreditCard-mode MaskingTarget redacts a Luhn-valid 16-digit
	 * card number embedded in free text. Exercises the framework dispatch into
	 * `UTIL_String.maskWithLuhnValidatedRegex`, proving a Luhn-passing match is treated the
	 * same way a plain Regex rule would treat its match.
	 */
	@IsTest
	private static void shouldMaskLuhnValidCardInCreditCardMode()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_CREDIT_CARD, '\\b(?:\\d[ -]*?){15,19}\\b', '[CARD]', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('customer card 4111111111111111 charged');

			Assert.areEqual('customer card [CARD] charged', result.maskedValue, 'Luhn-valid 16-digit card must be redacted in CreditCard mode');
			Assert.areEqual(1, result.rulesMatched, 'One rule should have matched');
		}
	}

	/**
	 * @description Tests that a CreditCard-mode MaskingTarget does NOT redact a 16-digit run
	 * that matches the regex but fails the Luhn checksum (e.g. a transaction ID). Catches the
	 * false-positive regression where a plain Regex mode would incorrectly over-redact.
	 */
	@IsTest
	private static void shouldNotMaskLuhnInvalidDigitRunInCreditCardMode()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_CREDIT_CARD, '\\b(?:\\d[ -]*?){15,19}\\b', '[CARD]', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('TID:1234567890123456 recorded');

			Assert.areEqual('TID:1234567890123456 recorded', result.maskedValue, 'Luhn-invalid 16-digit transaction ID must pass through in CreditCard mode');
			Assert.areEqual(0, result.rulesMatched, 'No rules should have matched when the Luhn gate fails');
		}
	}

	/**
	 * @description The shipped rule that hides payment card numbers finds the real card number in a full-length text of
	 * digits and spaces and hides it. The masking finishes without an error, although the text holds thousands of
	 * card-shaped numbers.
	 */
	@IsTest
	private static void shouldMaskTheCardInsideAFullLengthSpacedDigitWall()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt cardRule = registerShippedCardRuleOnApiCallRequest();
			String value = buildSpacedDigitWallWithCard(SEL_ApiCall.REQUEST_LENGTH);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask(value);

			Assert.isFalse(result.hadErrors, 'Expected the card rule to finish without an error');
			Assert.isFalse(result.maskedValue.contains(VISA_TEST_CARD), 'Expected the card number to be hidden');
			Assert.isTrue(result.maskedValue.contains(cardRule.Replacement__c), 'Expected the card replacement in the masked text');
		}
	}

	/**
	 * @description The shipped card rule finishes on every long hostile text at the full length of the field, and hides
	 * the expected number of numbers. In the texts of a digit and a separator, the numbers past the checking limit are
	 * hidden without the Luhn check. In the text without separators the pattern finds nothing, and a card number placed in
	 * it is found alone. Every 19-digit number and every number in a list of card numbers is hidden whole: no digit of
	 * them is left in clear, also where a number crosses the end of a search piece.
	 */
	@IsTest
	private static void shouldCompleteOnEveryHostileCardShape()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt cardRule = registerShippedCardRuleOnApiCallRequest();
			Integer length = SEL_ApiCall.REQUEST_LENGTH;
			Integer hiddenInASeparatedWall = NUMBERS_IN_A_FULL_SEPARATED_DIGIT_WALL - UTIL_String.LUHN_CANDIDATE_BUDGET;

			assertCardRuleHides('a text of digits only', buildDigitWall(length), 0, cardRule);
			assertCardRuleHides('digits and spaces', buildSpacedDigitWall(length), hiddenInASeparatedWall, cardRule);
			assertCardRuleHides('digits and hyphens', buildHyphenatedDigitWall(length), hiddenInASeparatedWall, cardRule);
			assertCardRuleHides('digits only with a card', buildDigitWallWithCard(length), 1, cardRule);
			assertCardRuleHides('digits and spaces with a card', buildSpacedDigitWallWithCard(length), hiddenInASeparatedWall, cardRule);
			assertCardRuleHides('digits and hyphens with a card', buildHyphenatedDigitWallWithCard(length), hiddenInASeparatedWall, cardRule);
			String maskedGroups = assertCardRuleHides('19-digit numbers', buildNineteenDigitGroups(length), NUMBERS_IN_FULL_NINETEEN_DIGIT_GROUPS, cardRule);
			String maskedCards = assertCardRuleHides('a list of card numbers', buildCardDump(length), NUMBERS_IN_A_FULL_CARD_DUMP, cardRule);

			Assert.isFalse(maskedGroups.left(maskedGroups.length() - DIGITS_LEFT_AFTER_THE_LAST_GROUP).containsAny(DIGITS),
					'Expected no digit of a 19-digit number to be left in clear');
			String groupsTail = maskedGroups.right(DIGITS_LEFT_AFTER_THE_LAST_GROUP);
			Assert.areEqual(NINETEEN_DIGIT_GROUP.left(DIGITS_LEFT_AFTER_THE_LAST_GROUP), groupsTail,
					'Expected the text to end with the digits of the cut last number, got ' + groupsTail);
			Assert.isFalse(maskedCards.containsAny(DIGITS), 'Expected no digit of a card number to be left in clear');
		}
	}

	/**
	 * @description The shipped secret-keys rule replaces the value of every one of the 9,001 keys named `token` in a
	 * full-length list of objects, and finishes. The list has far more opening brackets than the line, so it is read one token at a time.
	 * The masked text is longer than the field and is cut to its length afterwards.
	 */
	@IsTest
	private static void shouldMaskEveryTokenInAFullLengthArray()
	{
		System.runAs(getTestAdmin())
		{
			registerShippedSecretKeysRuleOnApiCallRequest();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask(buildTokenArray(SEL_ApiCall.REQUEST_LENGTH));

			Assert.isFalse(result.hadErrors, 'Expected the secret-keys rule to finish without an error');
			Assert.areEqual(TOKENS_IN_THE_FULL_TOKEN_LIST, result.valuesRedacted, 'Expected all 9,001 token values to be replaced');
			Assert.isFalse(result.maskedValue.contains(TOKEN_VALUE_IN_CLEAR), 'Expected no token value to be left in clear');
		}
	}

	/**
	 * @description A JSON value nested 2,000 levels deep is masked, and the masking finishes. A whole-tree JSON reader
	 * ends the transaction at this depth with an error no code can catch. The nest with a token at the bottom has the
	 * token replaced. The nest without a key is stored unchanged. The texts are compared as text, because a test cannot
	 * read them back as a tree either.
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldCompleteOnADeepNestOfTwoThousandLevels()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();
			assertDeepNestsAreMasked(TWO_THOUSAND_LEVELS, 0, secretRule);
		}
	}

	/**
	 * @description A JSON value nested 21,000 levels deep, nearly the full length of the field, is masked, and the
	 * masking finishes. The nest with a token at the bottom has the token replaced. The nest without a key, padded to
	 * the full length, is stored unchanged.
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldCompleteOnADeepNestOfTwentyOneThousandLevels()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();
			assertDeepNestsAreMasked(TWENTY_ONE_THOUSAND_LEVELS, SEL_ApiCall.REQUEST_LENGTH, secretRule);
		}
	}

	/**
	 * @description A secret key that holds a number has the number replaced, in a value read one token at a time.
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldMaskASecretStoredAsANumber()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();
			String expected = '{"token":"' + secretRule.Replacement__c + '","keep":1}';

			assertSecretKeysRuleMasksAboveTheLine('{"token":12345,"keep":1}', expected, 1);
		}
	}

	/**
	 * @description A secret key that holds a whole object has the whole object replaced, with every key inside it, in a
	 * value read one token at a time. The key named `token` inside the object is not counted: it is gone with the
	 * object.
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldMaskASecretStoredAsANestedObject()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();
			String expected = '{"apikey":"' + secretRule.Replacement__c + '","keep":1}';

			assertSecretKeysRuleMasksAboveTheLine('{"apikey":{"nested":{"x":[3]},"token":"inner"},"keep":1}', expected, 1);
		}
	}

	/**
	 * @description A secret key 61 levels deep is masked. The tree walk stops looking 50 levels deep, so the value is
	 * built with more opening brackets than the line, which makes it read one token at a time, at any depth.
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldMaskASecretAtDepthSixty()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();
			String deepSecret = NEST_LEVEL_OPENING.repeat(SIXTY_LEVELS) + DEEP_TOKEN_OBJECT + NEST_LEVEL_CLOSING.repeat(SIXTY_LEVELS);
			String expected = NEST_LEVEL_OPENING.repeat(SIXTY_LEVELS) + '{"token":"' + secretRule.Replacement__c + '"}' + NEST_LEVEL_CLOSING.repeat(SIXTY_LEVELS);

			assertSecretKeysRuleMasksAboveTheLine(deepSecret, expected, 1);
		}
	}

	/**
	 * @description A value that is text with JSON-like pairs in it takes the text search of the shipped secret-keys rule.
	 * Every plain value under a secret key is replaced: a text, a text with spaces around its colon, a number, true and
	 * null. The ordinary pair and the text around the pairs are kept.
	 */
	@IsTest
	private static void shouldMaskEveryScalarSecretWhenAValueTakesTheTextPass()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();
			String masked = '"' + secretRule.Replacement__c + '"';
			String value = 'login failed for {"password":"x", "secret" : "y", "token":12345, "bearer":true, "apikey":null, "user":"alice"} at step 2';
			String expected = 'login failed for {"password":' + masked + ', "secret" : ' + masked + ', "token":' + masked + ', "bearer":' + masked + ', "apikey":' + masked
					+ ', "user":"alice"} at step 2';

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask(value);

			Assert.isFalse(result.hadErrors, 'Expected the secret-keys rule to finish without an error');
			Assert.areEqual(expected, result.maskedValue, 'Expected every plain secret value replaced');
		}
	}

	/**
	 * @description When the text search of the secret-keys rule puts the failure marker in place of a value, the marker is
	 * final. A later Regex rule would replace the whole original value, but it does not run on the marker.
	 */
	@IsTest
	private static void shouldKeepTheTextPassMarkerFinalWhenALaterRuleWouldMatch()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();
			MaskingRule__mdt laterRule = (MaskingRule__mdt)mockRuleBuilder(LATER_RULE_NAME, SEL_MaskingRule.MODE_REGEX, WHOLE_VALUE_PATTERN, WHOLE_VALUE_REPLACEMENT,
					secretRule.Order__c + 1)
					.withoutInsertion(true)
					.build();
			registerMockTargetOn(ApiCall__c.SObjectType, laterRule, UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.Request__c), null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask('{"token":{"k":"v"}} sent');

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result.maskedValue, 'Expected the marker to stay in place of the value');
		}
	}

	/**
	 * @description A value that starts like JSON but has text after its end takes the text search. An object under a
	 * secret key cannot be hidden safely there, so the value gets the failure marker.
	 */
	@IsTest
	private static void shouldMarkAValueThatStartsLikeJsonButHoldsAnObjectUnderASecretKeyAndTrailingText()
	{
		System.runAs(getTestAdmin())
		{
			registerShippedSecretKeysRuleOnApiCallRequest();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask('{"token":{"k":"v"}}x');

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result.maskedValue, 'Expected the failure marker');
		}
	}

	/**
	 * @description A value that starts like JSON but has text after its end takes the text search, which replaces a
	 * number under a secret key and keeps the text after the JSON.
	 */
	@IsTest
	private static void shouldMaskANumberUnderASecretKeyInAValueThatStartsLikeJsonWithTrailingText()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask('{"token":12345} x');

			Assert.isFalse(result.hadErrors, 'Expected the secret-keys rule to finish without an error');
			Assert.areEqual('{"token":"' + secretRule.Replacement__c + '"} x', result.maskedValue, 'Expected the number replaced');
		}
	}

	/**
	 * @description When the text search puts the failure marker in place of a value, the masking counts that as a value
	 * the rule handled: the rule is counted as matched, one value is counted as replaced, and no error is recorded. The
	 * marker hides the whole value, so nothing secret is saved, and the rule did not fail.
	 */
	@IsTest
	private static void shouldCountTheTextPassMarkerAsAHandledValue()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask('{"token":{"k":"v"}}x');

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result.maskedValue, 'Expected the failure marker');
			Assert.areEqual(1, result.rulesMatched, 'Expected the rule counted as matched, got ' + result.rulesMatched);
			Assert.areEqual(1, result.valuesRedacted, 'Expected one value counted as replaced, got ' + result.valuesRedacted);
			Assert.isFalse(result.hadErrors, 'Expected no error recorded for the marker');
			Assert.isTrue(result.matchedRuleDeveloperNames.contains(secretRule.DeveloperName), 'Expected the secret-keys rule named as matched');
		}
	}

	/**
	 * @description A full stop right after the closing quote of a secret text is not a character that may end a JSON
	 * value, so the text search cannot tell where the secret ends, and the whole value gets the failure marker. A full
	 * stop after the closing brace is outside the pair, so there the secret text is replaced in place.
	 */
	@IsTest
	private static void shouldMarkTheWholeValueWhenAFullStopFollowsTheSecretText()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();
			UTIL_FrameworkMasker.FieldMasker masker = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c);

			UTIL_FrameworkMasker.MaskingResult stopAfterTheQuote = masker.mask('{"password":"x".}');
			UTIL_FrameworkMasker.MaskingResult stopAfterTheBrace = masker.mask('{"password":"x"}.');

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, stopAfterTheQuote.maskedValue, 'Expected the failure marker for a full stop after the quote');
			Assert.areEqual('{"password":"' + secretRule.Replacement__c + '"}.', stopAfterTheBrace.maskedValue, 'Expected the secret replaced for a full stop after the brace');
		}
	}

	/**
	 * @description A value read one token at a time in which no key matches is stored exactly as it came: the very same
	 * text, with its spaces, line break, number written as `1.00`, key written twice and escapes. The text holds a key
	 * that only starts with a secret key name, so the rule does read the whole value.
	 */
	@IsTest
	private static void shouldStoreAValueWithNoMatchingKeyByteForByte()
	{
		System.runAs(getTestAdmin())
		{
			registerShippedSecretKeysRuleOnApiCallRequest();
			String value = buildAboveTheStructureLine('{ "user" : "alice",\n  "amount": 1.00, "dup":1, "dup":2, "esc":"caf\\u00e9 \\/", "token_hint":"x" }');

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask(value);

			Object storedValue = result.maskedValue;
			Object originalValue = value;
			Assert.isTrue(storedValue === originalValue, 'Expected the very same text to be stored, byte for byte');
			Assert.areEqual(0, result.rulesMatched, 'Expected no rule to match');
			Assert.isFalse(result.hadErrors, 'Expected no error');
		}
	}

	/**
	 * @description The shipped token rule replaces every token in a plain text of 2,000,000 characters, and the masking
	 * finishes. One search over a text this long stops at the platform limit and ends the transaction, so the rule
	 * searches it in pieces.
	 */
	@IsTest
	private static void shouldMaskEveryTokenInALongestPlainTextValue()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt tokenRule = shippedRule(SEL_MaskingRule.RULE_MASK_JWT);
			registerMockTargetOn(ApiCall__c.SObjectType, tokenRule, UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.Request__c), null);
			Integer fillerLength = (LONGEST_VALUE_LENGTH - 3 * WEB_TOKEN.length()) / 2;
			String filler = DIGIT_AND_SPACE.repeat(fillerLength / DIGIT_AND_SPACE.length());
			String value = WEB_TOKEN + filler + WEB_TOKEN + filler + WEB_TOKEN;
			value += UTIL_String.SPACE.repeat(LONGEST_VALUE_LENGTH - value.length());
			filler = null;

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).maskAndReturnWholeText(value);

			value = null;
			Assert.isFalse(result.hadErrors, 'Expected the token rule to finish without an error');
			Assert.areEqual(3, result.uncutMaskedValue.countMatches(tokenRule.Replacement__c), 'Expected the three tokens replaced');
			Assert.isFalse(result.uncutMaskedValue.contains(WEB_TOKEN.left(10)), 'Expected no token left in clear');
		}
	}

	/**
	 * @description In a synchronous transaction, a JSON value just longer than
	 * `UTIL_FrameworkMasker.SYNCHRONOUS_JSON_TEXT_PASS_LINE` takes the quick text search of the secret-keys rule instead
	 * of being read as JSON. The text search cannot hide the object under the secret key safely, so the whole value gets
	 * the failure marker. Nothing secret is saved.
	 */
	@IsTest
	private static void shouldMarkJsonJustOverTheLineInASynchronousTransaction()
	{
		System.runAs(getTestAdmin())
		{
			registerShippedSecretKeysRuleOnApiCallRequest();
			String value = buildObjectUnderASecretKey(UTIL_FrameworkMasker.SYNCHRONOUS_JSON_TEXT_PASS_LINE + 1);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).maskAndReturnWholeText(value);

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result.maskedValue, 'Expected the failure marker in place of the value');
		}
	}

	/**
	 * @description In a synchronous transaction, a JSON value exactly as long as
	 * `UTIL_FrameworkMasker.SYNCHRONOUS_JSON_TEXT_PASS_LINE` is still read as JSON: the object under the secret key is
	 * replaced, and the rest of the value is kept.
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldMaskJsonAtTheLinePreciselyInASynchronousTransaction()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();
			String value = buildObjectUnderASecretKey(UTIL_FrameworkMasker.SYNCHRONOUS_JSON_TEXT_PASS_LINE);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).maskAndReturnWholeText(value);

			assertObjectUnderTheSecretKeyReplaced(result, secretRule);
		}
	}

	/**
	 * @description In a Queueable, an asynchronous transaction, a JSON value longer than
	 * `UTIL_FrameworkMasker.SYNCHRONOUS_JSON_TEXT_PASS_LINE` is still read as JSON: the object under the secret key is
	 * replaced, and the rest of the value is kept.
	 */
	@IsTest
	@SuppressWarnings('PMD.KernNoRawEnqueueJob,PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldMaskJsonOverTheLinePreciselyInAQueueable()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();

			Test.startTest();

			System.enqueueJob(new MaskInQueueable(buildObjectUnderASecretKey(UTIL_FrameworkMasker.SYNCHRONOUS_JSON_TEXT_PASS_LINE + 1)));

			Test.stopTest();

			assertObjectUnderTheSecretKeyReplaced(resultMaskedInQueueable, secretRule);
		}
	}

	/**
	 * @description In a synchronous transaction, a JSON value longer than
	 * `UTIL_FrameworkMasker.SYNCHRONOUS_JSON_TEXT_PASS_LINE` takes the quick text search, which reads a key written with
	 * JSON escapes by the name it stands for. A key spelled with a backslash, the letter u and four hexadecimal digits, and a key
	 * with an escaped quote inside it, both have their values replaced. The keys are kept as they were written, which
	 * shows that the text search, and not the JSON reader, masked the value.
	 */
	@IsTest
	private static void shouldMaskSecretKeysWrittenWithEscapesOverTheLineInASynchronousTransaction()
	{
		System.runAs(getTestAdmin())
		{
			registerMockJsonKeyRuleOnApiCallRequest(TEST_RULE_NAME, ESCAPED_KEY_NAMES_PATTERN, PASSWORD_REPLACEMENT, FIRST_RULE_ORDER, null);
			Integer paddingLength = UTIL_FrameworkMasker.SYNCHRONOUS_JSON_TEXT_PASS_LINE + 1 - KEYS_WRITTEN_WITH_ESCAPES_HEAD.length() - PADDED_OBJECT_TAIL.length();
			String value = KEYS_WRITTEN_WITH_ESCAPES_HEAD + PADDING_CHARACTER.repeat(paddingLength) + PADDED_OBJECT_TAIL;

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).maskAndReturnWholeText(value);

			String maskedText = result.uncutMaskedValue ?? result.maskedValue;
			Assert.isFalse(result.hadErrors, 'Expected the rule to finish without an error');
			Assert.isFalse(maskedText.contains('hunter'), 'Expected no secret left in clear');
			Assert.isTrue
					(
							maskedText.startsWith('{"p\\u0061ssword":"' + PASSWORD_REPLACEMENT + '","pass\\"word":"' + PASSWORD_REPLACEMENT + '","' + PADDING_KEY + '":"'),
							'Expected both values replaced and both keys kept as written, got ' + maskedText.left(80)
					);
		}
	}

	/**
	 * @description In a synchronous transaction, a JSON value longer than
	 * `UTIL_FrameworkMasker.SYNCHRONOUS_JSON_TEXT_PASS_LINE` takes the quick text search, which reads the value in pieces.
	 * A secret key with every letter written as a JSON escape is 74 characters long in quotes. When it crosses the end of
	 * the first piece, its value is still replaced: the next piece starts `UTIL_String.JSON_TEXT_SEARCH_PIECE_OVERLAP`
	 * characters before that end, so it holds the whole key.
	 */
	@IsTest
	private static void shouldMaskALongEscapedKeyAcrossAPieceEndOverTheLineInASynchronousTransaction()
	{
		System.runAs(getTestAdmin())
		{
			registerMockJsonKeyRuleOnApiCallRequest(TEST_RULE_NAME, LONG_KEY_NAME_PATTERN, PASSWORD_REPLACEMENT, FIRST_RULE_ORDER, null);
			String quotedKey = '"' + CLIENT_SECRET_WRITTEN_WITH_ESCAPES + '"';
			String head = '{"' + PADDING_KEY + '":"';
			String paddingEnd = '",';
			Integer keyStart = UTIL_String.JSON_TEXT_SEARCH_PIECE_LENGTH - quotedKey.length() + KEY_CHARACTERS_AFTER_THE_PIECE_END;
			String beforeKey = head + PADDING_CHARACTER.repeat(keyStart - head.length() - paddingEnd.length()) + paddingEnd;
			String pair = quotedKey + ':"hunter2","' + PADDING_KEY + '":"';
			Integer tailLength = UTIL_FrameworkMasker.SYNCHRONOUS_JSON_TEXT_PASS_LINE + 1 - beforeKey.length() - pair.length() - PADDED_OBJECT_TAIL.length();
			String value = beforeKey + pair + PADDING_CHARACTER.repeat(tailLength) + PADDED_OBJECT_TAIL;
			Assert.areEqual(keyStart, value.indexOf(quotedKey), 'Expected the key to start where it crosses the end of the first piece');

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).maskAndReturnWholeText(value);

			String maskedText = result.uncutMaskedValue ?? result.maskedValue;
			Assert.isFalse(result.hadErrors, 'Expected the rule to finish without an error');
			Assert.isFalse(maskedText.contains('hunter'), 'Expected no secret left in clear');
			Assert.isTrue(maskedText.contains(quotedKey + ':"' + PASSWORD_REPLACEMENT + '"'), 'Expected the value replaced and the key kept as written');
		}
	}

	/**
	 * @description In a synchronous transaction, a JSON value with 270,000 spaces between a secret key and its colon takes
	 * the quick text search. The text search reads at most 262,144 characters from the start of a key in one try, so it
	 * cannot see where the pair ends. It cannot tell what the pair holds, so the whole value gets the failure marker.
	 * Nothing of the secret is returned.
	 */
	@IsTest
	private static void shouldNotReturnASecretWhenSpacesBeforeItsColonRunPastTheReadLength()
	{
		System.runAs(getTestAdmin())
		{
			registerShippedSecretKeysRuleOnApiCallRequest();
			String value = '{"password"' + UTIL_String.SPACE.repeat(SPACES_PAST_THE_PAIR_READ_LENGTH) + ':"' + PASSWORD_VALUE + '"}';

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).maskAndReturnWholeText(value);

			assertSecretMarked(result);
		}
	}

	/**
	 * @description In a synchronous transaction, a JSON value with 270,000 spaces between the colon of a secret key and
	 * its secret takes the quick text search. The text search reads at most 262,144 characters from the start of a key in
	 * one try, so it cannot see where the pair ends. It cannot tell what the pair holds, so the whole value gets the
	 * failure marker. Nothing of the secret is returned.
	 */
	@IsTest
	private static void shouldNotReturnASecretWhenSpacesAfterItsColonRunPastTheReadLength()
	{
		System.runAs(getTestAdmin())
		{
			registerShippedSecretKeysRuleOnApiCallRequest();
			String value = '{"password":' + UTIL_String.SPACE.repeat(SPACES_PAST_THE_PAIR_READ_LENGTH) + '"' + PASSWORD_VALUE + '"}';

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).maskAndReturnWholeText(value);

			assertSecretMarked(result);
		}
	}

	/**
	 * @description In a synchronous transaction, a JSON value with 200,000 spaces before or after the colon of a secret key
	 * takes the quick text search. The whole pair fits in what the search reads from the key in one try, so the secret is
	 * replaced and the spaces are kept. The result holds the same JSON value as `UTIL_String.maskJsonKeys` gives when it
	 * reads the value as JSON.
	 */
	@IsTest
	private static void shouldMaskASecretWhenSpacesAroundItsColonStayBelowTheReadLength()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();
			String spaces = UTIL_String.SPACE.repeat(SPACES_BELOW_THE_PAIR_READ_LENGTH);
			String secret = '"' + PASSWORD_VALUE + '"';
			String maskedSecret = '"' + secretRule.Replacement__c + '"';

			for(String value : new List<String> {'{"password"' + spaces + ':' + secret + '}', '{"password":' + spaces + secret + '}'})
			{
				UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).maskAndReturnWholeText(value);

				String maskedText = result.uncutMaskedValue ?? result.maskedValue;
				String readAsJson = UTIL_String.maskJsonKeys(value, secretRule.Pattern__c, secretRule.Replacement__c, secretRule.CaseSensitive__c == true);
				Assert.isFalse(result.hadErrors, 'Expected the rule to finish without an error');
				Assert.areEqual(value.replace(secret, maskedSecret), maskedText, 'Expected the secret replaced and the spaces kept');
				Assert.areEqual(JSON.deserializeUntyped(readAsJson), JSON.deserializeUntyped(maskedText), 'Expected the same JSON value as maskJsonKeys gives');
			}
		}
	}

	/**
	 * @description A subscriber Regex rule has two alternatives that can overlap: a `secret=` pair up to its `&`, or six
	 * digits in a row. In a value of 300,000 characters, a pair starts 20 characters before the end of the first piece of
	 * the pattern search, so the piece end cuts the pair, but six of its digits lie inside the piece. The whole pair is
	 * still replaced, as one `replaceAll` over the whole value gives. Replacing only the digits would leave the start and
	 * the end of the pair in clear. One `replaceAll` over 300,000 characters stops at the platform limit for one search,
	 * so the test runs it over the pair alone: the spaces around the pair never match, so the result is the same.
	 */
	@IsTest
	private static void shouldMaskAMatchThatStartsJustBeforeAPieceEnd()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_REGEX, OVERLAPPING_ALTERNATIVES_PATTERN, PAIR_REPLACEMENT, null);
			Integer pairStart = UTIL_String.PATTERN_SEARCH_PIECE_LENGTH - PAIR_START_BEFORE_THE_PIECE_END;
			String value = UTIL_String.SPACE.repeat(pairStart) + SECRET_PAIR + UTIL_String.SPACE.repeat(THREE_PIECE_VALUE_LENGTH - pairStart - SECRET_PAIR.length());

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).maskAndReturnWholeText(value);

			String maskedText = result.uncutMaskedValue ?? result.maskedValue;
			String expected = value.replace(SECRET_PAIR, Pattern.compile(OVERLAPPING_ALTERNATIVES_PATTERN).matcher(SECRET_PAIR).replaceAll(PAIR_REPLACEMENT));
			Assert.isFalse(maskedText.contains(SECRET_PAIR_START), 'Expected the whole pair hidden, found ' + maskedText.mid(pairStart, MESSAGE_WINDOW_LENGTH));
			Assert.areEqual(expected, maskedText, 'Expected the same text as one replaceAll over the whole value');
		}
	}

	/**
	 * @description Text that does not start and end like a JSON object or list goes to the text search for
	 * `"key":"value"` pairs, and the masking finishes. The full-length token list cut inside its last value is such a
	 * text: every complete token value in it is replaced, and the masked text is cut to the field length. A short cut list
	 * shows the whole result: the last value has no closing quote and stays as it is.
	 */
	@IsTest
	private static void shouldSendTextThatIsNotJsonToTheTextPass()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();
			UTIL_FrameworkMasker.FieldMasker masker = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c);

			UTIL_FrameworkMasker.MaskingResult cutList = masker.mask(buildTokenArrayCut(SEL_ApiCall.REQUEST_LENGTH));
			UTIL_FrameworkMasker.MaskingResult shortCutList = masker.mask('[{"token":"abc"},{"user":"x","note":"hel');

			Assert.isFalse(cutList.hadErrors, 'Expected the text search to finish without an error');
			Assert.areEqual(1, cutList.rulesMatched, 'Expected the secret-keys rule to match the cut list');
			Assert.isFalse(cutList.maskedValue.contains(TOKEN_VALUE_IN_CLEAR), 'Expected no complete token value to be left in clear');
			Assert.areEqual('[{"token":"' + secretRule.Replacement__c + '"},{"user":"x","note":"hel', shortCutList.maskedValue,
					'Expected the complete token value replaced and the rest of the cut text left as it is');
		}
	}

	/**
	 * @description A full-length JSON object in which no secret key name appears anywhere is stored unchanged, as the
	 * very same text, and no rule is counted as matched. The key name search finds no secret key name in the text.
	 */
	@IsTest
	private static void shouldSkipTheRuleWhenNoKeyNameAppearsInTheText()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();
			String value = buildManyKeys(SEL_ApiCall.REQUEST_LENGTH);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask(value);

			Object storedValue = result.maskedValue;
			Object originalValue = value;
			Assert.isFalse(UTIL_String.canHoldMatchingJsonKey(value, secretRule.Pattern__c), 'Expected the key name search to find no secret key name');
			Assert.isTrue(storedValue === originalValue, 'Expected the very same text to be stored');
			Assert.areEqual(0, result.rulesMatched, 'Expected no rule to match');
		}
	}

	/**
	 * @description A secret key name written with a Unicode escape does not appear as it reads in the raw text: here
	 * `password` has its letter a written as a backslash, the letter u and the hexadecimal digits 0061. The rule must still read
	 * the value, and masks the key, in a value read as a tree and in a value read one token at a time.
	 */
	@IsTest
	private static void shouldNotSkipTheRuleWhenTheTextHoldsAUnicodeEscape()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();
			String escapedSecret = '{"p\\u0061ssword":"hunter2"}';
			String expected = '{"password":"' + secretRule.Replacement__c + '"}';

			UTIL_FrameworkMasker.MaskingResult treeResult = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask(escapedSecret);

			Assert.areEqual(JSON.deserializeUntyped(expected), JSON.deserializeUntyped(treeResult.maskedValue), 'Expected the escaped key masked in the tree');
			assertSecretKeysRuleMasksAboveTheLine(escapedSecret, expected, 1);
		}
	}

	/**
	 * @description Full-length texts of a digit and a space, or a digit and a hyphen, are stored unchanged by the
	 * secret-keys rule. They do not start like a JSON object or list, so they go to the text search, which finds no
	 * key in them, and the masking finishes.
	 */
	@IsTest
	private static void shouldLeaveTheSpacedDigitShapesUnchangedThroughTheTextPass()
	{
		System.runAs(getTestAdmin())
		{
			registerShippedSecretKeysRuleOnApiCallRequest();
			UTIL_FrameworkMasker.FieldMasker masker = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c);
			String spacedDigits = buildSpacedDigitWall(SEL_ApiCall.REQUEST_LENGTH);
			String hyphenatedDigits = buildHyphenatedDigitWall(SEL_ApiCall.REQUEST_LENGTH);

			Assert.areEqual(spacedDigits, masker.mask(spacedDigits).maskedValue, 'Expected digits and spaces to be stored unchanged');
			Assert.areEqual(hyphenatedDigits, masker.mask(hyphenatedDigits).maskedValue, 'Expected digits and hyphens to be stored unchanged');
		}
	}

	/**
	 * @description A value that is one JSON text or one JSON number, not an object or list, goes to the text search and
	 * is stored unchanged: it holds no key.
	 */
	@IsTest
	private static void shouldSendATopLevelScalarToTheTextPass()
	{
		System.runAs(getTestAdmin())
		{
			registerShippedSecretKeysRuleOnApiCallRequest();
			UTIL_FrameworkMasker.FieldMasker masker = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c);
			String scalarText = '"secret"';
			String scalarNumber = '42';

			UTIL_FrameworkMasker.MaskingResult textResult = masker.mask(scalarText);
			UTIL_FrameworkMasker.MaskingResult numberResult = masker.mask(scalarNumber);

			Assert.areEqual(scalarText, textResult.maskedValue, 'Expected a JSON text alone to be stored unchanged');
			Assert.areEqual(scalarNumber, numberResult.maskedValue, 'Expected a JSON number alone to be stored unchanged');
			Assert.areEqual(0, textResult.rulesMatched + numberResult.rulesMatched, 'Expected no rule to match');
		}
	}

	/**
	 * @description A value that starts and ends like a JSON object but is broken inside goes to the text search, which
	 * masks the complete `"key":"value"` pairs, both in a value read as a tree and in a value read one token at a time.
	 */
	@IsTest
	private static void shouldSendBrokenJsonToTheTextPass()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt secretRule = registerShippedSecretKeysRuleOnApiCallRequest();
			UTIL_FrameworkMasker.FieldMasker masker = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c);
			String broken = '{"token":"abc",,"user":"x"}';
			String expected = '{"token":"' + secretRule.Replacement__c + '",,"user":"x"}';

			UTIL_FrameworkMasker.MaskingResult treeResult = masker.mask(broken);
			UTIL_FrameworkMasker.MaskingResult streamResult = masker.mask(buildAboveTheStructureLine(broken));

			Assert.areEqual(expected, treeResult.maskedValue, 'Expected the text search to mask the broken value');
			Assert.areEqual(buildAboveTheStructureLine(expected), streamResult.maskedValue, 'Expected the text search to mask the broken long value');
			Assert.areEqual(1, streamResult.rulesMatched, 'Expected the secret-keys rule to match the broken long value');
		}
	}

	/**
	 * @description Two JsonKey rules on a value read one token at a time run in rule order, each on the output of the
	 * rule before. The later rule wins where both patterns match a key, and each rule's own replacements are counted.
	 */
	@IsTest
	private static void shouldApplyJsonKeyRulesInOrderOnAValueReadAsAStream()
	{
		System.runAs(getTestAdmin())
		{
			registerMockJsonKeyRuleOnApiCallRequest('FirstJsonKeyRule', '^(access_token|token)$', 'A', 10, null);
			registerMockJsonKeyRuleOnApiCallRequest('SecondJsonKeyRule', '^(access_token|session)$', 'B', 20, null);
			String value = buildAboveTheStructureLine('{"access_token":"a","session":"c","token":"d","user":"u"}');
			String expected = buildAboveTheStructureLine('{"access_token":"B","session":"B","token":"A","user":"u"}');

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask(value);

			Assert.areEqual(expected, result.maskedValue, 'Expected both rules applied in order');
			Assert.areEqual(2, result.rulesMatched, 'Expected both rules to match');
			Assert.areEqual(4, result.valuesRedacted, 'Expected two replacements from each rule');
		}
	}

	/**
	 * @description On a value read as a tree, a JsonKey rule whose key name is not in the text is skipped, and the next
	 * rule still reads the value and masks it.
	 */
	@IsTest
	private static void shouldRunTheNextJsonKeyRuleAfterASkippedOneOnATree()
	{
		System.runAs(getTestAdmin())
		{
			registerMockJsonKeyRuleOnApiCallRequest('SkippedJsonKeyRule', '^session$', 'S', 10, null);
			registerMockJsonKeyRuleOnApiCallRequest('MatchingJsonKeyRule', '^token$', 'T', 20, null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask('{"token":"d","user":"u"}');

			Assert.areEqual(JSON.deserializeUntyped('{"token":"T","user":"u"}'), JSON.deserializeUntyped(result.maskedValue), 'Expected the second rule to mask');
			Assert.areEqual(1, result.rulesMatched, 'Expected only the second rule to match');
		}
	}

	/**
	 * @description A JsonKey rule with a blank pattern does not stop the masking of a value read as a tree with an error.
	 * The rule runs, fails, and its failure is recorded for the rule.
	 */
	@IsTest
	private static void shouldRecordAFailureForAJsonKeyRuleWithABlankPatternOnATree()
	{
		System.runAs(getTestAdmin())
		{
			registerBlankPatternJsonKeyRuleOnApiCallRequest();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask('{"password":"x"}');

			Assert.areEqual(new List<String> {TEST_RULE_NAME}, result.failedRuleDeveloperNames, 'Expected the rule failure recorded');
		}
	}

	/**
	 * @description A JsonKey rule with a blank pattern does not stop the masking of a value read one token at a time with
	 * an error. The rule runs, fails, and its failure is recorded for the rule.
	 */
	@IsTest
	private static void shouldRecordAFailureForAJsonKeyRuleWithABlankPatternOnAStream()
	{
		System.runAs(getTestAdmin())
		{
			registerBlankPatternJsonKeyRuleOnApiCallRequest();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask(buildAboveTheStructureLine('{"password":"x"}'));

			Assert.areEqual(new List<String> {TEST_RULE_NAME}, result.failedRuleDeveloperNames, 'Expected the rule failure recorded');
		}
	}

	/**
	 * @description A JsonKey rule whose pattern cannot compile fails on a value read one token at a time, and the
	 * failure is recorded for the rule, as on a value read as a tree.
	 */
	@IsTest
	private static void shouldCaptureAJsonKeyRuleFailureOnAValueReadAsAStream()
	{
		System.runAs(getTestAdmin())
		{
			registerMockJsonKeyRuleOnApiCallRequest(TEST_RULE_NAME, BROKEN_PATTERN, UNUSED_REPLACEMENT, 10, null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask(buildAboveTheStructureLine('{"password":"x"}'));

			Assert.isTrue(result.hadErrors, 'Expected the rule failure to be recorded');
			Assert.areEqual(new List<String> {TEST_RULE_NAME}, result.failedRuleDeveloperNames, 'Expected the failing rule to be named');
			Assert.areEqual(0, result.rulesMatched, 'Expected no rule to count as matched');
		}
	}

	/**
	 * @description Tests that a Regex-mode rule with `MinInputLength__c` set is skipped when the
	 * field value is shorter than the configured threshold. Proves the short-circuit avoids
	 * compiling/executing the regex on values that cannot possibly match. Catches the regression
	 * where the length gate is ignored and the expensive regex fires on short framework fields.
	 */
	@IsTest
	private static void shouldSkipRegexRuleWhenValueShorterThanMinInputLength()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithMinInputLength(SEL_MaskingRule.MODE_REGEX, '\\d{15,19}', 'X', null, 15);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'short14chars12')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual('short14chars12', record.Text__c, 'Value shorter than MinInputLength must bypass the rule without regex evaluation');
		}
	}

	/**
	 * @description Tests that a Regex-mode rule with `MinInputLength__c` set still applies when
	 * the field value meets or exceeds the threshold. Proves the short-circuit does not suppress
	 * rules whose regex might legitimately match.
	 */
	@IsTest
	private static void shouldApplyRegexRuleWhenValueAtLeastMinInputLength()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithMinInputLength(SEL_MaskingRule.MODE_REGEX, '\\d{15,19}', 'X', null, 15);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'long123456789012345string')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.isTrue(record.Text__c.contains('X'), 'Value at or above MinInputLength must have the rule applied');
		}
	}

	/**
	 * @description Tests that a rule scoped to a CallerClass fires only when calledFrom matches.
	 */
	@IsTest
	private static void shouldHonourCallerClassScope()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', 'API_SendEmail');

			UTIL_FrameworkMasker.MaskingResult wrongCaller = UTIL_FrameworkMasker.forField(Foobar__c.Text__c)
					.calledFrom('API_Other')
					.mask('secret value');

			Assert.areEqual('secret value', wrongCaller.maskedValue, 'Rule should NOT fire for a different caller');
			Assert.areEqual(0, wrongCaller.rulesMatched, 'No rules should match when caller scope mismatches');

			UTIL_FrameworkMasker.MaskingResult rightCaller = UTIL_FrameworkMasker.forField(Foobar__c.Text__c)
					.calledFrom('API_SendEmail')
					.mask('secret value');

			Assert.areEqual('X value', rightCaller.maskedValue, 'Rule should fire when caller scope matches');
		}
	}

	/**
	 * @description Tests that a rule with blank CallerClass fires regardless of the caller.
	 */
	@IsTest
	private static void shouldFireUnscopedRuleForAnyCaller()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c)
					.calledFrom('AnyCaller')
					.mask('secret value');

			Assert.areEqual('X value', result.maskedValue, 'Unscoped rule should fire regardless of caller');
		}
	}

	/**
	 * @description Tests that rules targeting a different field do not fire.
	 */
	@IsTest
	private static void shouldSkipRulesForOtherFields()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextArea(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('secret value');

			Assert.areEqual('secret value', result.maskedValue, 'Rule targeting TextArea__c should NOT fire on Text__c');
		}
	}

	/**
	 * @description Tests that a rule with an invalid regex is caught, flagged, and that
	 * LogAndContinue (the default FailureAction when unset) leaves the value unchanged and
	 * adds the rule to the per-transaction invalidation set.
	 */
	@IsTest
	private static void shouldCaptureRegexFailure()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_REGEX, '([bad', 'X', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('some value');

			Assert.isTrue(result.hadErrors, 'hadErrors should be true when a rule throws');
			Assert.areEqual(1, result.failedRuleDeveloperNames.size(), 'One failed rule should be recorded');
			Assert.areEqual('some value', result.maskedValue, 'LogAndContinue default keeps the value unchanged');
			Assert.isTrue(UTIL_FrameworkMasker.invalidatedRuleDeveloperNames.contains('TestRule'), 'Failed rule should be added to the invalidation set');
		}
	}

	/**
	 * @description Tests that a rule configured with `FailureAction__c = WriteFailureMarker`
	 * substitutes the FAILURE_MARKER sentinel instead of leaving the raw value in place.
	 */
	@IsTest
	private static void shouldWriteFailureMarkerWhenConfigured()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithFailureAction(SEL_MaskingRule.MODE_REGEX, '([bad', 'X', null, SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('some value');

			Assert.isTrue(result.hadErrors, 'hadErrors should be true when a rule throws');
			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result.maskedValue, 'WriteFailureMarker should substitute the sentinel value');
		}
	}

	/**
	 * @description Tests that a rule configured with `FailureAction__c = BlockDml` throws
	 * `MaskingBlockedException` on first failure so the surrounding adapter aborts the DML.
	 */
	@IsTest
	private static void shouldBlockDmlWhenConfigured()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithFailureAction(SEL_MaskingRule.MODE_REGEX, '([bad', 'X', null, SEL_MaskingRule.FAILURE_BLOCK_DML);

			try
			{
				UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('some value');
				Assert.fail('BlockDml rule failure should have thrown MaskingBlockedException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.MaskingBlockedException.class, 'Should throw MaskingBlockedException');
			}
		}
	}

	/**
	 * @description Tests that a rule that has already failed is skipped on subsequent calls
	 * in the same transaction. This avoids wasted work for each record in bulk triggers, and stops
	 * each record from entering the logging loop again.
	 */
	@IsTest
	private static void shouldSkipInvalidatedRuleOnSubsequentCalls()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_REGEX, '([bad', 'X', null);

			UTIL_FrameworkMasker.MaskingResult firstCall = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('first');
			UTIL_FrameworkMasker.MaskingResult secondCall = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('second');

			Assert.isTrue(firstCall.hadErrors, 'First call should record the failure');
			Assert.isFalse(secondCall.hadErrors, 'Second call should skip the invalidated rule entirely');
			Assert.areEqual(0, secondCall.failedRuleDeveloperNames.size(), 'Second call should not re-record the failed rule');
			Assert.areEqual('second', secondCall.maskedValue, 'Second call should pass through unchanged');
		}
	}

	/**
	 * @description Tests that a masking rule failing on a LogEntry__c target does not emit a
	 * warning log, which closes the logging loop across transactions from end to end.
	 */
	@IsTest
	private static void shouldSkipWarnLoggingWhenLogEntryTargetRuleFails()
	{
		System.runAs(getTestAdmin())
		{
			String logEntryObjectName = UTIL_SObjectDescribe.getObjectNameFromType(LogEntry__c.SObjectType);
			String fieldApiName = UTIL_SObjectDescribe.getCachedFieldName(LogEntry__c.Message__c);

			MaskingRule__mdt rule = (MaskingRule__mdt)TST_Builder.of(MaskingRule__mdt.SObjectType)
					.withOverride(MaskingRule__mdt.DeveloperName, 'LogEntryRule')
					.withOverride(MaskingRule__mdt.Mode__c, SEL_MaskingRule.MODE_REGEX)
					.withOverride(MaskingRule__mdt.Pattern__c, '([bad')
					.withOverride(MaskingRule__mdt.Replacement__c, 'X')
					.withOverride(MaskingRule__mdt.IsActive__c, true)
					.withOverride(MaskingRule__mdt.Order__c, 10)
					.withoutInsertion(true)
					.build();

			TST_Mock.of(MaskingTarget__mdt.SObjectType)
					.withOverride(MaskingTarget__mdt.IsActive__c, true)
					.withOverride(MaskingTarget__mdt.SObjectType__c, logEntryObjectName)
					.withOverride(MaskingTarget__mdt.Field__c, logEntryObjectName + UTIL_String.DOT + fieldApiName)
					.withOverride(MaskingTarget__mdt.Rule__c, rule)
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(LogEntry__c.Message__c).mask('some value');

			Assert.isTrue(result.hadErrors, 'hadErrors should still be set for LogEntry target failures');
			Assert.isTrue(UTIL_FrameworkMasker.invalidatedRuleDeveloperNames.contains('LogEntryRule'), 'Rule invalidation still fires for LogEntry targets');
		}
	}

	/**
	 * @description A Write Failure Marker rule whose pattern cannot compile can never mask anything. The value it fails
	 * on gets the marker, and so does every later value it covers in the same transaction. Each of those results
	 * records the error, so a caller that reads the results sees every marked value.
	 */
	@IsTest
	private static void shouldMarkEveryValueWhenAWriteFailureMarkerRuleCannotCompile()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithFailureAction(SEL_MaskingRule.MODE_REGEX, BROKEN_PATTERN, UNUSED_REPLACEMENT, null, SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER);

			UTIL_FrameworkMasker.MaskingResult first = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('first');
			UTIL_FrameworkMasker.MaskingResult second = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('second');

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, first.maskedValue, 'Expected the value that failed to carry the marker');
			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, second.maskedValue, 'Expected a later value of a rule that cannot compile to carry the marker');
			Assert.isTrue(second.hadErrors, 'Expected the later marked value to report an error');
			Assert.isTrue(second.failedRuleDeveloperNames.contains(TEST_RULE_NAME), 'Expected the later marked value to name the rule that failed');
		}
	}

	/**
	 * @description On the record path, a Write Failure Marker regex rule that cannot compile marks the second record of
	 * the batch too. It is not skipped after it failed on the first record.
	 */
	@IsTest
	private static void shouldMarkBothRecordsWhenAWriteFailureMarkerRegexRuleCannotCompile()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithFailureAction(SEL_MaskingRule.MODE_REGEX, BROKEN_PATTERN, UNUSED_REPLACEMENT, null, SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER);

			Foobar__c firstRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'first')
					.withoutInsertion()
					.build();
			Foobar__c secondRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'second')
					.withoutInsertion()
					.build();

			List<UTIL_FrameworkMasker.MaskingResult> results = UTIL_FrameworkMasker.forRecords(new List<SObject> {firstRecord, secondRecord}).apply();

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, firstRecord.Text__c, 'Expected the first record to carry the marker');
			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, secondRecord.Text__c, 'Expected the second record to carry the marker');
			Assert.isTrue(results.get(1).hadErrors, 'Expected the second record to report an error');
		}
	}

	/**
	 * @description On the JSON path, a Write Failure Marker JsonKey rule that cannot compile marks the second record of
	 * the batch too. It is not skipped after it failed on the first record.
	 */
	@IsTest
	private static void shouldMarkBothRecordsWhenAWriteFailureMarkerJsonKeyRuleCannotCompile()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextAreaWithFailureAction(SEL_MaskingRule.MODE_JSON_KEY, BROKEN_PATTERN, UNUSED_REPLACEMENT, null, SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER);

			Foobar__c firstRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.TextArea__c, '{"password":"hunter2"}')
					.withoutInsertion()
					.build();
			Foobar__c secondRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.TextArea__c, '{"password":"other"}')
					.withoutInsertion()
					.build();

			List<UTIL_FrameworkMasker.MaskingResult> results = UTIL_FrameworkMasker.forRecords(new List<SObject> {firstRecord, secondRecord}).apply();

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, firstRecord.TextArea__c, 'Expected the first record to carry the marker');
			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, secondRecord.TextArea__c, 'Expected the second record to carry the marker');
			Assert.isTrue(results.get(1).hadErrors, 'Expected the second record to report an error');
		}
	}

	/**
	 * @description On the JSON path, the failure marker is final. The first JSON key rule cannot compile and puts the
	 * marker in place of the value. The second rule would match the password key. Its masked JSON must not be written
	 * over the marker.
	 */
	@IsTest
	private static void shouldKeepTheMarkerWhenALaterJsonKeyRuleMatchesInTheSameBatch()
	{
		System.runAs(getTestAdmin())
		{
			String textAreaField = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.TextArea__c);
			mockTarget
					(
							textAreaField,
							SEL_MaskingRule.MODE_JSON_KEY,
							BROKEN_PATTERN,
							UNUSED_REPLACEMENT,
							null,
							MARKER_RULE_NAME,
							FIRST_RULE_ORDER,
							SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER
					);
			mockTarget(textAreaField, SEL_MaskingRule.MODE_JSON_KEY, PASSWORD_KEY_PATTERN, PASSWORD_REPLACEMENT, null, LATER_RULE_NAME, SECOND_RULE_ORDER, null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.TextArea__c).mask(PASSWORD_JSON);

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result.maskedValue, 'Expected the marker to survive a later rule that matched');
			Assert.isFalse(result.matchedRuleDeveloperNames.contains(LATER_RULE_NAME), 'Expected the later rule not to run on the marked value');
			Assert.areEqual(0, result.rulesMatched, 'Expected no rule to count a match on a marked value');
		}
	}

	/**
	 * @description On the JSON path, the failure marker is final even when an earlier rule has already changed the
	 * JSON. The first JSON key rule works and masks the password. The second rule cannot compile and puts the marker
	 * in place of the value. The value must stay the marker: the masked JSON from the first rule must not be written
	 * over it at the end. This order needs its own test, because the stop at the start of each rule cannot help here:
	 * the marker is written by the last rule, after the stop was checked. Only the check before the JSON is written
	 * back keeps the marker.
	 */
	@IsTest
	private static void shouldKeepTheMarkerWhenAnEarlierJsonKeyRuleMatchedBeforeALaterRuleFailed()
	{
		System.runAs(getTestAdmin())
		{
			String textAreaField = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.TextArea__c);
			mockTarget(textAreaField, SEL_MaskingRule.MODE_JSON_KEY, PASSWORD_KEY_PATTERN, PASSWORD_REPLACEMENT, null, TEST_RULE_NAME, FIRST_RULE_ORDER, null);
			mockTarget
					(
							textAreaField,
							SEL_MaskingRule.MODE_JSON_KEY,
							BROKEN_PATTERN,
							UNUSED_REPLACEMENT,
							null,
							LATER_RULE_NAME,
							SECOND_RULE_ORDER,
							SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER
					);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.TextArea__c).mask(PASSWORD_JSON);

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result.maskedValue, 'Expected the marker, not the JSON the earlier rule masked');
			Assert.isTrue(result.hadErrors, 'Expected the result to report an error');
			Assert.isTrue(result.failedRuleDeveloperNames.contains(LATER_RULE_NAME), 'Expected the result to name the later rule as failed');
			Assert.isTrue(result.matchedRuleDeveloperNames.contains(TEST_RULE_NAME), 'Expected the earlier rule to have run and matched');
		}
	}

	/**
	 * @description On the JSON path, a Block DML JSON key rule that comes after the marker rule is not run on the
	 * marked value, because the marker holds no secret. The same rule still refuses the next JSON value that is not
	 * marked. The Block DML rule has two targets: one on TextArea__c, after the marker rule, and one on Text__c, where
	 * it is the only rule. This shape keeps both checks in one transaction, so the test proves the skip on the marked
	 * value did not turn the rule off.
	 */
	@IsTest
	private static void shouldNotRunALaterBlockDmlJsonKeyRuleOnAMarkedValueButRefuseTheNextUnmarkedOne()
	{
		System.runAs(getTestAdmin())
		{
			String textAreaField = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.TextArea__c);
			mockTarget
					(
							textAreaField,
							SEL_MaskingRule.MODE_JSON_KEY,
							BROKEN_PATTERN,
							UNUSED_REPLACEMENT,
							null,
							MARKER_RULE_NAME,
							FIRST_RULE_ORDER,
							SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER
					);

			MaskingRule__mdt blockRule = (MaskingRule__mdt)mockRuleBuilder(LATER_RULE_NAME, SEL_MaskingRule.MODE_JSON_KEY, BROKEN_PATTERN, UNUSED_REPLACEMENT, SECOND_RULE_ORDER)
					.withOverride(MaskingRule__mdt.FailureAction__c, SEL_MaskingRule.FAILURE_BLOCK_DML)
					.withoutInsertion(true)
					.build();
			registerMockTarget(blockRule, textAreaField, null);
			registerMockTarget(blockRule, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c), null);

			UTIL_FrameworkMasker.MaskingResult marked = UTIL_FrameworkMasker.forField(Foobar__c.TextArea__c).mask(PASSWORD_JSON);

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, marked.maskedValue, 'Expected the marked JSON value to keep the marker');

			try
			{
				UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask(PASSWORD_JSON);
				Assert.fail('Expected the Block DML rule to refuse the next JSON value that is not marked');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.MaskingBlockedException.class, 'Expected a MaskingBlockedException for the unmarked JSON value');
			}
		}
	}

	/**
	 * @description A JSON key rule also runs on a value that is not JSON, and there too the failure marker is final.
	 * Both rules are Write Failure Marker JSON key rules whose pattern cannot compile. Masking a JSON value first, on
	 * each field, makes the framework learn that each pattern is broken. The later rule has its own target on Text__c
	 * for this reason, because on TextArea__c it never runs after the marker. Then a plain value on TextArea__c gets
	 * the marker from the first rule. The later rule must not run on the marker, so the result names only the first
	 * rule as failed.
	 */
	@IsTest
	private static void shouldKeepTheMarkerWhenALaterJsonKeyRuleMeetsAValueThatIsNotJson()
	{
		System.runAs(getTestAdmin())
		{
			String textAreaField = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.TextArea__c);
			mockTarget
					(
							textAreaField,
							SEL_MaskingRule.MODE_JSON_KEY,
							BROKEN_PATTERN,
							UNUSED_REPLACEMENT,
							null,
							MARKER_RULE_NAME,
							FIRST_RULE_ORDER,
							SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER
					);

			MaskingRule__mdt laterRule = (MaskingRule__mdt)mockRuleBuilder(LATER_RULE_NAME, SEL_MaskingRule.MODE_JSON_KEY, BROKEN_PATTERN, UNUSED_REPLACEMENT, SECOND_RULE_ORDER)
					.withOverride(MaskingRule__mdt.FailureAction__c, SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER)
					.withoutInsertion(true)
					.build();
			registerMockTarget(laterRule, textAreaField, null);
			registerMockTarget(laterRule, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c), null);

			UTIL_FrameworkMasker.forField(Foobar__c.TextArea__c).mask(PASSWORD_JSON);
			UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask(PASSWORD_JSON);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.TextArea__c).mask(PLAIN_VALUE);

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result.maskedValue, 'Expected the plain value to carry the marker');
			Assert.isTrue(result.failedRuleDeveloperNames.contains(MARKER_RULE_NAME), 'Expected the result to name the rule that put the marker');
			Assert.isFalse(result.failedRuleDeveloperNames.contains(LATER_RULE_NAME), 'Expected the later rule not to run on the marker');
		}
	}

	/**
	 * @description On the text path, the failure marker is final. The first rule cannot compile and puts the marker in
	 * place of the value. The second rule matches any text and would replace the marker. It must not run on the marker.
	 */
	@IsTest
	private static void shouldKeepTheMarkerWhenALaterRegexRuleWouldReplaceTheWholeField()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText
					(
							SEL_MaskingRule.MODE_REGEX,
							BROKEN_PATTERN,
							UNUSED_REPLACEMENT,
							null,
							MARKER_RULE_NAME,
							FIRST_RULE_ORDER,
							SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER
					);
			mockTargetForFoobarText(SEL_MaskingRule.MODE_REGEX, WHOLE_VALUE_PATTERN, WHOLE_VALUE_REPLACEMENT, null, LATER_RULE_NAME, SECOND_RULE_ORDER);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask(PLAIN_VALUE);

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result.maskedValue, 'Expected the marker to end the pass for that value');
		}
	}

	/**
	 * @description A Block DML rule that comes after the marker rule is not run on the marked value, because the marker
	 * holds no secret. The same rule still refuses the next value that is not marked. The Block DML rule has two
	 * targets: one on Text__c, after the marker rule, and one on TextArea__c, where it is the only rule. This shape
	 * keeps both checks in one transaction, so the test proves the skip on the marked value did not turn the rule off.
	 */
	@IsTest
	private static void shouldNotRunALaterBlockDmlRuleOnAMarkedValueButRefuseTheNextUnmarkedOne()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText
					(
							SEL_MaskingRule.MODE_REGEX,
							BROKEN_PATTERN,
							UNUSED_REPLACEMENT,
							null,
							MARKER_RULE_NAME,
							FIRST_RULE_ORDER,
							SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER
					);

			MaskingRule__mdt blockRule = (MaskingRule__mdt)mockRuleBuilder(LATER_RULE_NAME, SEL_MaskingRule.MODE_REGEX, BROKEN_PATTERN, UNUSED_REPLACEMENT, SECOND_RULE_ORDER)
					.withOverride(MaskingRule__mdt.FailureAction__c, SEL_MaskingRule.FAILURE_BLOCK_DML)
					.withoutInsertion(true)
					.build();
			registerMockTarget(blockRule, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c), null);
			registerMockTarget(blockRule, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.TextArea__c), null);

			UTIL_FrameworkMasker.MaskingResult marked = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask(PLAIN_VALUE);

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, marked.maskedValue, 'Expected the marked value to keep the marker');

			try
			{
				UTIL_FrameworkMasker.forField(Foobar__c.TextArea__c).mask(SAMPLE_VALUE);
				Assert.fail('Expected the Block DML rule to refuse the next value that is not marked');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.MaskingBlockedException.class, 'Expected a MaskingBlockedException for the unmarked value');
			}
		}
	}

	/**
	 * @description A Write Failure Marker rule whose pattern compiles, but which fails on one value, marks only that
	 * value. The rule keeps running: it leaves a value it does not match, and it marks the next value it fails on.
	 * The replacement names a second group the pattern does not have, which fails only on a value the pattern matches.
	 */
	@IsTest
	private static void shouldMarkOnlyTheValueAWriteFailureMarkerRuleFailsOn()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithFailureAction(SEL_MaskingRule.MODE_REGEX, ONE_GROUP_PATTERN, SECOND_GROUP_REPLACEMENT, null, SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER);

			UTIL_FrameworkMasker.MaskingResult first = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('xxaab');
			UTIL_FrameworkMasker.MaskingResult second = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('nothing here');
			UTIL_FrameworkMasker.MaskingResult third = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('aab again');

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, first.maskedValue, 'Expected the value the rule failed on to carry the marker');
			Assert.areEqual('nothing here', second.maskedValue, 'Expected the rule to keep running and leave a value it does not match');
			Assert.isFalse(second.hadErrors, 'Expected no error on a value the rule handled');
			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, third.maskedValue, 'Expected a second matching value to be marked, not skipped');
			Assert.isTrue(third.hadErrors, 'Expected the second matching value to report an error');
		}
	}

	/**
	 * @description After a Write Failure Marker rule is known to be broken, a blank or null value stays as it is. There
	 * is nothing in it to hide, so it does not get the marker. That holds for a value that was blank from the start,
	 * and for a value an earlier rule left blank.
	 */
	@IsTest
	private static void shouldLeaveABlankValueBlankAfterAWriteFailureMarkerRuleBroke()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, ERASED_VALUE, UTIL_String.EMPTY, null, 'ErasingRule', 10);
			mockTarget
					(
							UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c),
							SEL_MaskingRule.MODE_REGEX,
							BROKEN_PATTERN,
							UNUSED_REPLACEMENT,
							null,
							TEST_RULE_NAME,
							20,
							SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER
					);

			UTIL_FrameworkMasker.MaskingResult first = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('first');
			UTIL_FrameworkMasker.MaskingResult erased = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask(ERASED_VALUE);
			UTIL_FrameworkMasker.MaskingResult blank = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask(UTIL_String.EMPTY);
			UTIL_FrameworkMasker.MaskingResult missing = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask(null);

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, first.maskedValue, 'Expected the value that failed to carry the marker');
			Assert.areEqual(UTIL_String.EMPTY, erased.maskedValue, 'Expected a value an earlier rule left blank to stay blank');
			Assert.isFalse(erased.hadErrors, 'Expected no error on a value the broken rule left alone');
			Assert.areEqual(UTIL_String.EMPTY, blank.maskedValue, 'Expected a blank value to stay blank');
			Assert.isNull(missing.maskedValue, 'Expected a null value to stay null');
		}
	}

	/**
	 * @description After a Write Failure Marker rule is known to be broken, a value shorter than the rule's minimum
	 * input length stays as it is. The rule's author has said such a short value cannot hold the secret.
	 */
	@IsTest
	private static void shouldLeaveAShortValueAloneAfterAWriteFailureMarkerRuleBroke()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextWithMinInputLength(SEL_MaskingRule.MODE_REGEX, BROKEN_PATTERN, UNUSED_REPLACEMENT, null, 10, SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER);

			UTIL_FrameworkMasker.MaskingResult first = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('long enough value');
			UTIL_FrameworkMasker.MaskingResult second = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('short');

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, first.maskedValue, 'Expected the long value the rule failed on to carry the marker');
			Assert.areEqual('short', second.maskedValue, 'Expected a value shorter than the minimum input length to stay as it is');
			Assert.isFalse(second.hadErrors, 'Expected no error on a value the rule does not look at');
		}
	}

	/**
	 * @description A broken Write Failure Marker rule on a log entry writes no warning, neither on the value it fails on
	 * nor on the next one, because a warning written while a log entry is masked starts a logging loop. The next value
	 * still gets the marker.
	 */
	@IsTest
	private static void shouldMarkWithoutWarningOnALogEntryTargetAfterAWriteFailureMarkerRuleBroke()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.setupLoggerForTest();
			LOG_Engine.ignoreTestMode = true;

			String logEntryObjectName = UTIL_SObjectDescribe.getObjectNameFromType(LogEntry__c.SObjectType);
			String fieldApiName = UTIL_SObjectDescribe.getCachedFieldName(LogEntry__c.Message__c);

			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('LogEntryRule', SEL_MaskingRule.MODE_REGEX, BROKEN_PATTERN, UNUSED_REPLACEMENT, 10)
					.withOverride(MaskingRule__mdt.FailureAction__c, SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER)
					.withoutInsertion(true)
					.build();

			TST_Mock.of(MaskingTarget__mdt.SObjectType)
					.withOverride(MaskingTarget__mdt.IsActive__c, true)
					.withOverride(MaskingTarget__mdt.SObjectType__c, logEntryObjectName)
					.withOverride(MaskingTarget__mdt.Field__c, logEntryObjectName + UTIL_String.DOT + fieldApiName)
					.withOverride(MaskingTarget__mdt.Rule__c, rule)
					.build();

			Test.startTest();
			UTIL_FrameworkMasker.MaskingResult first = UTIL_FrameworkMasker.forField(LogEntry__c.Message__c).mask('first');
			UTIL_FrameworkMasker.MaskingResult second = UTIL_FrameworkMasker.forField(LogEntry__c.Message__c).mask('second');
			Test.stopTest();

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, first.maskedValue, 'Expected the value that failed to carry the marker');
			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, second.maskedValue, 'Expected the next log entry value to carry the marker');
			Assert.isTrue(new SEL_LogEntry().findAllByMethod(RULE_FAILURE_WARNING_LOCATION).isEmpty(), 'Expected no warning from a rule on a log entry');
		}
	}

	/**
	 * @description A rule that fails on many values in one transaction writes its warning once, not once for each
	 * value it marks. The rule's pattern compiles, so it runs and fails again on every value. A pattern that cannot
	 * compile would be no good here: after the first value it marks later values without running, so it never
	 * reaches the warning again, and the count would be one even without the once-per-rule check. The warning
	 * carries a flood-control key named after the rule, so the count is read from the stored counter row.
	 */
	@IsTest
	private static void shouldWarnOnceForARuleThatFailsOnManyValues()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.setupLoggerForTest();
			LOG_Engine.ignoreTestMode = true;
			mockTargetForFoobarTextWithFailureAction(SEL_MaskingRule.MODE_REGEX, ONE_GROUP_PATTERN, SECOND_GROUP_REPLACEMENT, null, SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER);

			Test.startTest();
			UTIL_FrameworkMasker.MaskingResult first = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('aab');
			UTIL_FrameworkMasker.MaskingResult second = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('aaab');
			UTIL_FrameworkMasker.MaskingResult third = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('ab');
			Test.stopTest();

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, first.maskedValue, 'Expected the first value the rule failed on to carry the marker');
			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, second.maskedValue, 'Expected the second value the rule failed on to carry the marker');
			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, third.maskedValue, 'Expected the third value the rule failed on to carry the marker');
			assertStoredUnderFloodControl(new SEL_LogEntry().findAllByMethod(RULE_FAILURE_WARNING_LOCATION), RULE_FAILURE_FINGERPRINT, 1);
		}
	}

	/**
	 * @description A Block DML rule that fails on many values in one transaction writes its warning once, not once
	 * for each value it refuses. The rule's pattern compiles, so it runs and fails again on every value, and each
	 * value is refused with the exception that stops the save.
	 */
	@IsTest
	private static void shouldWarnOnceForABlockDmlRuleThatFailsOnManyValues()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.setupLoggerForTest();
			LOG_Engine.ignoreTestMode = true;
			mockTargetForFoobarTextWithFailureAction(SEL_MaskingRule.MODE_REGEX, ONE_GROUP_PATTERN, SECOND_GROUP_REPLACEMENT, null, SEL_MaskingRule.FAILURE_BLOCK_DML);

			Test.startTest();
			assertMaskingIsBlocked('aab');
			assertMaskingIsBlocked('aaab');
			assertMaskingIsBlocked('ab');
			Test.stopTest();

			assertStoredUnderFloodControl(new SEL_LogEntry().findAllByMethod(RULE_FAILURE_WARNING_LOCATION), RULE_FAILURE_FINGERPRINT, 1);
		}
	}

	/**
	 * @description Masks one value on `Foobar__c.Text__c` and checks that the Block DML rule refuses it.
	 *
	 * @param value The value to mask.
	 */
	private static void assertMaskingIsBlocked(String value)
	{
		try
		{
			UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask(value);
			Assert.fail('Expected the Block DML rule to refuse the value');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.MaskingBlockedException.class, 'Expected the Block DML rule to refuse the value');
		}
	}

	/**
	 * @description The warning that a rule names a field type that does not exist carries a flood-control key named
	 * after the rule, so a misconfigured rule that is met on every save fills one detail row and a daily counter.
	 */
	@IsTest
	private static void shouldFingerprintTheWarningAboutAnUnknownFieldTypeWithTheRuleName()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.setupLoggerForTest();
			LOG_Engine.ignoreTestMode = true;
			mockTargetForFoobarWildcardWithApplicableFieldTypes
					(SEL_MaskingRule.MODE_EXACT_MATCH, UNMATCHED_TOKEN, UNUSED_REPLACEMENT, FOOBAR_UNKNOWN_TYPE_RULE_NAME, UNKNOWN_FIELD_TYPE);
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Text__c, UTIL_Random.randomName()).withoutInsertion().build();

			Test.startTest();
			UTIL_FrameworkMasker.forRecord(record).apply();
			Test.stopTest();

			assertStoredUnderFloodControl(new SEL_LogEntry().findAllByMethod(UNKNOWN_TYPE_WARNING_LOCATION), UNKNOWN_TYPE_FINGERPRINT, 1);
		}
	}

	/**
	 * @description The warning that a target wires a rule to a field whose type the rule excludes carries a
	 * flood-control key named after the rule and the field, so each misconfigured target fills one detail row and a
	 * daily counter.
	 */
	@IsTest
	private static void shouldFingerprintTheWarningAboutAnExcludedFieldTypeWithTheRuleAndFieldNames()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.setupLoggerForTest();
			LOG_Engine.ignoreTestMode = true;
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder(FOOBAR_EXCLUDED_TYPE_RULE_NAME, SEL_MaskingRule.MODE_EXACT_MATCH, UNMATCHED_TOKEN, UNUSED_REPLACEMENT, 10)
					.withOverride(MaskingRule__mdt.ApplicableFieldTypes__c, String.valueOf(DisplayType.EMAIL))
					.withoutInsertion(true)
					.build();
			registerMockTarget(rule, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.URL__c), null);
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.URL__c, UTIL_Random.randomName()).withoutInsertion().build();

			Test.startTest();
			UTIL_FrameworkMasker.forRecord(record).apply();
			Test.stopTest();

			assertStoredUnderFloodControl(new SEL_LogEntry().findAllByMethod(MISMATCHED_TYPE_WARNING_LOCATION), EXCLUDED_TYPE_FINGERPRINT, 1);
		}
	}

	/**
	 * @description Tests that isLogEntryTarget returns true for the LogEntry__c object and
	 * false for other objects. This is the check that stops warning logs on masking failures against
	 * LogEntry targets, which breaks the logging loop across transactions.
	 */
	@IsTest
	private static void shouldIdentifyLogEntryTargetByObjectName()
	{
		System.runAs(getTestAdmin())
		{
			MaskingTarget__mdt logEntryTarget = (MaskingTarget__mdt)TST_Builder.of(MaskingTarget__mdt.SObjectType)
					.withOverride(MaskingTarget__mdt.SObjectType__c, UTIL_SObjectDescribe.getObjectNameFromType(LogEntry__c.SObjectType))
					.withoutInsertion(true)
					.build();

			MaskingTarget__mdt logEntryEventTarget = (MaskingTarget__mdt)TST_Builder.of(MaskingTarget__mdt.SObjectType)
					.withOverride(MaskingTarget__mdt.SObjectType__c, UTIL_SObjectDescribe.getObjectNameFromType(LogEntryEvent__e.SObjectType))
					.withoutInsertion(true)
					.build();

			MaskingTarget__mdt foobarTarget = (MaskingTarget__mdt)TST_Builder.of(MaskingTarget__mdt.SObjectType)
					.withOverride(MaskingTarget__mdt.SObjectType__c, UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType))
					.withoutInsertion(true)
					.build();

			Assert.isTrue(UTIL_FrameworkMasker.isLogEntryTarget(logEntryTarget), 'LogEntry__c target should be identified');
			Assert.isTrue(UTIL_FrameworkMasker.isLogEntryTarget(logEntryEventTarget), 'LogEntryEvent__e target should be identified');
			Assert.isFalse(UTIL_FrameworkMasker.isLogEntryTarget(foobarTarget), 'Non-log target should not be identified');
		}
	}

	/**
	 * @description Every masking target the package ships on the log event is seen as a log target when it is read
	 * the way the masker reads it. A deployed target does not store the object's API name. It stores the object's
	 * durable Id (the fixed key the platform gives each object; for a custom object, an Id such as `01I...`), and the
	 * API name on its related object is empty. So a check that compares the stored value with the API name misses
	 * every deployed target.
	 */
	@IsTest
	private static void shouldIdentifyEveryShippedLogEventTargetAsALogEntryTarget()
	{
		System.runAs(getTestAdmin())
		{
			List<MaskingTarget__mdt> logEventTargets = new SEL_MaskingTarget().findAllForSObjectType(LogEntryEvent__e.SObjectType);

			Assert.isFalse(logEventTargets.isEmpty(), 'Expected the package to ship masking targets on the log event');
			for(MaskingTarget__mdt target : logEventTargets)
			{
				Assert.areNotEqual(UTIL_FrameworkMasker.LOG_ENTRY_EVENT_OBJECT_NAME, target.SObjectType__c, 'Expected a deployed target to store the object Id');
				Assert.isTrue(UTIL_FrameworkMasker.isLogEntryTarget(target), 'Expected ' + target.DeveloperName + ' to be seen as a log target');
			}
		}
	}

	/**
	 * @description The log event targets are still seen as log targets when the selector cannot use its normal read.
	 * That happens when two masking targets share a DeveloperName: the selector then reads the targets with a plain
	 * query, and the copies it makes keep the stored object Id but have no related object at all.
	 */
	@IsTest
	private static void shouldIdentifyTheShippedLogEventTargetsWhenTheSelectorFallsBackToAQuery()
	{
		System.runAs(getTestAdmin())
		{
			SEL_MaskingTarget.simulateGetAllCollisionForTest = true;

			List<MaskingTarget__mdt> logEventTargets = new SEL_MaskingTarget().findAllForSObjectType(LogEntryEvent__e.SObjectType);

			Assert.isFalse(logEventTargets.isEmpty(), 'Expected the fallback read to find the log event targets');
			for(MaskingTarget__mdt target : logEventTargets)
			{
				Assert.isNull(target.SObjectType__r, 'Expected the fallback copy to have no related object');
				Assert.isTrue(UTIL_FrameworkMasker.isLogEntryTarget(target), 'Expected ' + target.DeveloperName + ' to be seen as a log target');
			}
		}
	}

	/**
	 * @description A broken rule on a deployed log event target writes no warning. The target is a copy of a target
	 * the package ships, read the way the masker reads it, so it stores the object's durable Id and not its API name.
	 * Its rule is replaced by one whose pattern cannot compile, and it is limited to one caller class, so the broken
	 * rule does not also change the warning, if one is written, before it is saved. A warning written while a log
	 * event is masked would publish another log event, which is masked again, so the warning is skipped. The value
	 * still gets the failure marker.
	 */
	@IsTest
	private static void shouldWriteNoWarningWhenARuleFailsOnADeployedLogEventTarget()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.setupLoggerForTest();
			LOG_Engine.ignoreTestMode = true;

			MaskingRule__mdt brokenRule = (MaskingRule__mdt)mockRuleBuilder(LOG_EVENT_BROKEN_RULE_NAME, SEL_MaskingRule.MODE_REGEX, BROKEN_PATTERN, UNUSED_REPLACEMENT, 10)
					.withOverride(MaskingRule__mdt.FailureAction__c, SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER)
					.withoutInsertion(true)
					.build();
			List<MaskingTarget__mdt> shippedLogEventTargets = new SEL_MaskingTarget().findAllForSObjectType(LogEntryEvent__e.SObjectType);
			Assert.isFalse(shippedLogEventTargets.isEmpty(), 'Expected the package to ship masking targets on the log event');
			MaskingTarget__mdt deployedTarget = shippedLogEventTargets[0].clone(true);
			deployedTarget.Rule__c = brokenRule.Id;
			deployedTarget.IsActive__c = true;
			deployedTarget.CallerClass__c = SAMPLE_CALLER;

			SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt> {deployedTarget.DeveloperName => deployedTarget};
			SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {LOG_EVENT_BROKEN_RULE_NAME => brokenRule};
			SEL_MaskingTarget.cachedTargetsByType = null;
			SEL_MaskingTarget.cachedRulesById = null;

			Test.startTest();
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(LogEntryEvent__e.Message__c).calledFrom(SAMPLE_CALLER).mask(UTIL_Random.randomName());
			Test.stopTest();

			Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result.maskedValue, 'Expected the value the broken rule failed on to carry the marker');
			Assert.areEqual(0, new SEL_LogEntry().getRecordCount(), 'Expected no warning from a broken rule on a log event target');
		}
	}

	/**
	 * @description A target that names one field masks that field when the target is read the way a deployed
	 * target is read. A deployed target does not store `Object.Field`. It stores two durable Ids joined by a dot,
	 * the object's and the field's (a durable Id is the fixed key the platform gives each object and each field),
	 * and its related field record has no API name. The masker must still find the field the target names.
	 */
	@IsTest
	private static void shouldMaskTheFieldADeployedTargetNames()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = buildWholeValueRule();
			MaskingTarget__mdt deployedTarget = buildDeployedTextFieldTarget(rule);
			SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt> {DEPLOYED_FIELD_TARGET_NAME => deployedTarget};
			SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {TEST_RULE_NAME => rule};
			SEL_MaskingTarget.cachedTargetsByType = null;
			SEL_MaskingTarget.cachedRulesById = null;

			Test.startTest();
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask(UTIL_Random.randomName());
			Test.stopTest();

			Assert.areEqual(WHOLE_VALUE_REPLACEMENT, result.maskedValue, 'Expected the field the deployed target names to be masked');
		}
	}

	/**
	 * @description A deployed target that names one field still masks that field when the selector cannot use its
	 * normal read. That happens when two masking targets share a DeveloperName: the selector then reads the targets
	 * with a plain query, and the copies it makes keep the two stored durable Ids but have no related records at all.
	 */
	@IsTest
	private static void shouldMaskTheFieldADeployedTargetNamesWhenTheSelectorFallsBackToAQuery()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = buildWholeValueRule();
			TST_Mock.registerNext(MaskingTarget__mdt.SObjectType, buildDeployedTextFieldTarget(rule));
			SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {TEST_RULE_NAME => rule};
			SEL_MaskingTarget.simulateGetAllCollisionForTest = true;
			SEL_MaskingTarget.cachedTargetsByType = null;
			SEL_MaskingTarget.cachedRulesById = null;

			Test.startTest();
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask(UTIL_Random.randomName());
			Test.stopTest();

			Assert.areEqual(WHOLE_VALUE_REPLACEMENT, result.maskedValue, 'Expected the field the deployed target names to be masked on the fallback read');
		}
	}

	/**
	 * @description Masking fails when a target names a field and the field details (FieldDefinition) cannot be read.
	 * A deployed target stores the field's durable Id, so the masker needs the field details to know which field the
	 * target masks. Without them it must not guess: the error reaches the caller, so a save fails and the value is
	 * never saved without masking.
	 */
	@IsTest
	private static void shouldFailMaskingWhenTheFieldATargetNamesCannotBeFound()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = buildWholeValueRule();
			MaskingTarget__mdt deployedTarget = buildDeployedTextFieldTarget(rule);
			SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt> {DEPLOYED_FIELD_TARGET_NAME => deployedTarget};
			SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {TEST_RULE_NAME => rule};
			SEL_MaskingTarget.cachedTargetsByType = null;
			SEL_MaskingTarget.cachedRulesById = null;
			TST_Mock.throwsException(FieldDefinition.SObjectType, FIELD_DETAILS_DENIAL);

			Test.startTest();
			try
			{
				UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask(UTIL_Random.randomName());
				Assert.fail('Expected masking to fail when the field the target names cannot be found');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, QueryException.class, 'Expected the error from reading field details to reach the caller');
			}
			Test.stopTest();
		}
	}

	/**
	 * @description Builds an active rule that replaces the whole value, for the deployed target tests.
	 *
	 * @return An uninserted MaskingRule__mdt.
	 */
	private static MaskingRule__mdt buildWholeValueRule()
	{
		return (MaskingRule__mdt)mockRuleBuilder(TEST_RULE_NAME, SEL_MaskingRule.MODE_REGEX, WHOLE_VALUE_PATTERN, WHOLE_VALUE_REPLACEMENT, FIRST_RULE_ORDER)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Builds an active target on `Foobar__c.Text__c` in the shape a deployed target has. Its object
	 * and field hold the durable Ids the platform gives them, read from the org, and only its related object
	 * record carries an API name.
	 *
	 * @param rule The rule the target points at.
	 *
	 * @return An uninserted MaskingTarget__mdt that names the field by its durable Ids.
	 */
	private static MaskingTarget__mdt buildDeployedTextFieldTarget(MaskingRule__mdt rule)
	{
		String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c);
		String fieldDurableId;
		for(FieldDefinition field : new SEL_FieldDefinition().findByEntity(UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType)))
		{
			if(field.QualifiedApiName == fieldName)
			{
				fieldDurableId = field.DurableId;
			}
		}
		String objectDurableId = fieldDurableId.substringBefore(UTIL_String.DOT);
		EntityDefinition foobarObject = new SEL_EntityDefinition().findByDurableIds(new Set<String> {objectDurableId})[0];

		MaskingTarget__mdt target = (MaskingTarget__mdt)TST_Builder.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.DeveloperName, DEPLOYED_FIELD_TARGET_NAME)
				.withOverride(MaskingTarget__mdt.SObjectType__c, foobarObject)
				.withoutInsertion(true)
				.build();
		target.SObjectType__c = objectDurableId;
		target.Field__c = fieldDurableId;
		target.Rule__c = rule.Id;
		target.IsActive__c = true;
		target.CallerClass__c = null;
		return target;
	}

	/**
	 * @description A masking rule misconfigured on the log event must not cost the entry being masked its
	 * fingerprint. The masker's warnings run inside the loop that builds an entry's events, while that entry's
	 * fingerprint is still open on the engine, and the warning's own emit closes it, so every message after the
	 * first would lose the fingerprint it was written with. The warnings are skipped on the log objects instead.
	 */
	@IsTest
	private static void shouldKeepTheFingerprintOfAnEntryAMisconfiguredLogRuleIsMasking()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);
			TST_Factory.setupLoggerForTest();
			LOG_Engine.ignoreTestMode = true;
			registerMisconfiguredRulesOnLogEntryEvents();

			Test.startTest();
			LOG_Builder.build()
					.warn(new List<String> {UTIL_Random.randomName(), UTIL_Random.randomName()})
					.withFingerprint(MASKED_ENTRY_FINGERPRINT)
					.emitAt(MASKED_ENTRY_CLASS_METHOD);
			Test.stopTest();

			List<LogEntry__c> rows = new SEL_LogEntry().findAllByMethod(MASKED_ENTRY_CLASS_METHOD);
			Assert.isFalse(rows.isEmpty(), 'The entry should be on file');
			for(LogEntry__c row : rows)
			{
				Assert.isTrue(row.Fingerprint__c?.contains(MASKED_ENTRY_FINGERPRINT) == true,
						'Every message of the entry keeps the fingerprint it was written with, and this one carries ' + row.Fingerprint__c);
			}
			Assert.isTrue(new SEL_LogEntry().findAllByMethod(UNKNOWN_TYPE_WARNING_LOCATION).isEmpty(), 'The masker says nothing about an unknown field type on a log entry');
			Assert.isTrue(new SEL_LogEntry().findAllByMethod(MISMATCHED_TYPE_WARNING_LOCATION).isEmpty(), 'The masker says nothing about a field-type mismatch on a log entry');
		}
	}

	/**
	 * @description Registers two misconfigured masking targets on the log event: one wildcard target whose rule
	 * names a field type that does not exist, and one wired to a field whose type its rule excludes. Each is a
	 * warning site the masker would otherwise reach from inside the event loop.
	 */
	private static void registerMisconfiguredRulesOnLogEntryEvents()
	{
		String logEntryEventName = UTIL_SObjectDescribe.getObjectNameFromType(LogEntryEvent__e.SObjectType);

		MaskingRule__mdt unknownTypeRule = (MaskingRule__mdt)mockRuleBuilder(UNKNOWN_TYPE_RULE_NAME, SEL_MaskingRule.MODE_EXACT_MATCH, UNMATCHED_TOKEN, 'X', 10)
				.withOverride(MaskingRule__mdt.ApplicableFieldTypes__c, UNKNOWN_FIELD_TYPE)
				.withoutInsertion(true)
				.build();
		TST_Mock.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.IsActive__c, true)
				.withOverride(MaskingTarget__mdt.SObjectType__c, logEntryEventName)
				.withOverride(MaskingTarget__mdt.Field__c, null)
				.withOverride(MaskingTarget__mdt.Rule__c, unknownTypeRule)
				.build();

		MaskingRule__mdt mismatchedTypeRule = (MaskingRule__mdt)mockRuleBuilder(MISMATCHED_TYPE_RULE_NAME, SEL_MaskingRule.MODE_EXACT_MATCH, UNMATCHED_TOKEN, 'X', 20)
				.withOverride(MaskingRule__mdt.ApplicableFieldTypes__c, String.valueOf(DisplayType.EMAIL))
				.withoutInsertion(true)
				.build();
		TST_Mock.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.IsActive__c, true)
				.withOverride(MaskingTarget__mdt.SObjectType__c, logEntryEventName)
				.withOverride(MaskingTarget__mdt.Field__c, logEntryEventName + UTIL_String.DOT + UTIL_SObjectDescribe.getCachedFieldName(LogEntryEvent__e.Message__c))
				.withOverride(MaskingTarget__mdt.Rule__c, mismatchedTypeRule)
				.build();
	}

	/**
	 * @description Tests that a rule with a mode value not recognised by the dispatcher (e.g. a
	 * future picklist value that ships before the Apex update catches up) is a safe no-op.
	 */
	@IsTest
	private static void shouldSkipUnrecognisedModeGracefully()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText('SomeFutureMode', 'foo', 'bar', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('unchanged');

			Assert.areEqual('unchanged', result.maskedValue, 'Unrecognised mode should leave the value alone');
			Assert.areEqual(0, result.rulesMatched, 'Unrecognised mode should not count as a match');
		}
	}

	/**
	 * @description Tests that a JsonKey-mode MaskingTarget fires through UTIL_FrameworkMasker.
	 */
	@IsTest
	private static void shouldApplyJsonKeyRuleToField()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextArea(SEL_MaskingRule.MODE_JSON_KEY, '^(password|token)$', '***', null);

			String input = '{"user":"alice","password":"hunter2","token":"abc"}';
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.TextArea__c).mask(input);

			Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(result.maskedValue);
			Assert.areEqual('***', parsed.get('password'), 'JsonKey rule should redact password');
			Assert.areEqual('***', parsed.get('token'), 'JsonKey rule should redact token');
			Assert.areEqual('alice', parsed.get('user'), 'Non-matching key should remain');
			Assert.areEqual(1, result.rulesMatched, 'One rule should have matched');
		}
	}

	/**
	 * @description Tests that a masked value which grows past the field's length limit is
	 * truncated so the subsequent DML does not throw STRING_TOO_LONG.
	 */
	@IsTest
	private static void shouldTruncateMaskedValueToFieldLength()
	{
		System.runAs(getTestAdmin())
		{
			String longReplacement = 'X'.repeat(300);
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'a', longReplacement, null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('a');

			Assert.areEqual(255, result.maskedValue.length(), 'Masked value should be truncated to field length (Text__c = 255)');
			Assert.areEqual(255, result.maskedLength, 'maskedLength metadata should reflect the truncated length');
		}
	}

	/**
	 * @description Tests that mask returns unchanged when no targets are configured for the field.
	 */
	@IsTest
	private static void shouldReturnUnchangedWhenNoTargets()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('unchanged');

			Assert.areEqual('unchanged', result.maskedValue, 'Value should pass through when no targets configured');
			Assert.areEqual(0, result.rulesMatched, 'No rules should match');
		}
	}

	/**
	 * @description Tests that two JsonKey rules on the same field apply in a single batched
	 * parse+serialize pass and both record a match.
	 */
	@IsTest
	private static void shouldBatchMultipleJsonKeyRules()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextArea(SEL_MaskingRule.MODE_JSON_KEY, '^password$', 'P', null, 'PasswordRule', 10);
			mockTargetForFoobarTextArea(SEL_MaskingRule.MODE_JSON_KEY, '^token$', 'T', null, 'TokenRule', 20);

			String input = '{"password":"hunter2","token":"abc","user":"alice"}';
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.TextArea__c).mask(input);

			Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(result.maskedValue);
			Assert.areEqual('P', parsed.get('password'), 'Password rule should fire');
			Assert.areEqual('T', parsed.get('token'), 'Token rule should fire');
			Assert.areEqual(2, result.rulesMatched, 'Both JsonKey rules should be recorded as matched');
		}
	}

	/**
	 * @description Tests that a JsonKey-mode rule applied to a record whose payload matches no
	 * keys completes without re-serializing the deserialized tree. A subsequent change removes
	 * the per-rule `JSON.serialize` before/after comparison; the CPU-budget assertion guards
	 * against a future regression reintroducing that double-serialize.
	 */
	@IsTest
	private static void shouldNotReserializeJsonTreeWhenNoJsonKeyRuleMatches()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_JSON_KEY, '^password$', '***', null);

			String payload = '{"user":"alice","role":"admin"}';
			Foobar__c record = new Foobar__c(Text__c = payload);

			Test.startTest();
			Integer cpuBefore = UTIL_Limits.cpuTime().used();
			UTIL_FrameworkMasker.forRecord(record).apply();
			Integer cpuAfter = UTIL_Limits.cpuTime().used();
			Test.stopTest();

			Assert.areEqual(payload, record.Text__c, 'Non-matching tree must pass through unchanged');
			Assert.isTrue(cpuAfter - cpuBefore < 200, 'Non-matching JsonKey mask must not serialize the tree (CPU budget < 200ms, observed=' + (cpuAfter - cpuBefore) + ')');
		}
	}

	/**
	 * @description Tests that a malformed JSON payload falls back to per-rule processing when
	 * the batched parse fails.
	 */
	@IsTest
	private static void shouldFallBackWhenJsonKeyBatchParseFails()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextArea(SEL_MaskingRule.MODE_JSON_KEY, '^password$', '***', null);

			String malformedJson = '{"password": "hunter2", broken';
			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.TextArea__c).mask(malformedJson);

			Assert.isTrue(result.maskedValue.contains('"password": "***"'), 'Fallback should still redact the password');
			Assert.isFalse(result.maskedValue.contains('hunter2'), 'Original secret must not remain');
		}
	}

	/**
	 * @description Tests that duplicate target configurations are deduped so the same rule only
	 * fires (and appears in the audit list) once.
	 */
	@IsTest
	private static void shouldDeduplicateIdenticalTargets()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('secret value');

			Assert.areEqual('X value', result.maskedValue, 'Rule should still fire');
			Assert.areEqual(1, result.rulesMatched, 'Duplicate target should be removed: only one match recorded');
		}
	}

	/**
	 * @description Tests that targets are applied in parent-rule Order__c ascending sequence.
	 * The earlier rule (Order__c = 10) runs first and replaces 'foo' with 'FIRST'; the later
	 * rule (Order__c = 20) then has nothing to match, proving execution order.
	 */
	@IsTest
	private static void shouldApplyTargetsInRuleOrderSequence()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'foo', 'SECOND', null, 'LaterRule', 20);
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'foo', 'FIRST', null, 'EarlierRule', 10);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('foo here');

			Assert.areEqual('EarlierRule', result.matchedRuleDeveloperNames.get(0), 'Rule with Order__c = 10 should execute first');
			Assert.areEqual(1, result.rulesMatched, 'Only the earlier rule should have matched: the later rule saw text that was already replaced');
			Assert.areEqual('FIRST here', result.maskedValue, 'Earlier rule wins; later rule cannot match because foo is already gone');
		}
	}

	/**
	 * @description Tests that a JsonKey rule with an invalid regex throws and is captured as a
	 * rule failure inside the batched JsonKey path. Works with the Regex-mode failure test.
	 */
	@IsTest
	private static void shouldCaptureJsonKeyRuleFailure()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextArea(SEL_MaskingRule.MODE_JSON_KEY, '([bad', '***', null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.TextArea__c).mask('{"password":"hunter2"}');

			Assert.isTrue(result.hadErrors, 'hadErrors should be true when a JsonKey rule throws');
			Assert.areEqual(1, result.failedRuleDeveloperNames.size(), 'One failed JsonKey rule should be recorded');
			Assert.areEqual('TestRule', result.failedRuleDeveloperNames.get(0), 'The failing rule name should be recorded');
			Assert.areEqual(0, result.rulesMatched, 'No rules should count as matched when the rule threw');
		}
	}

	/**
	 * @description Tests UTIL_String.applyJsonKeyRuleToTree with a null input. Covers the null check
	 * that UTIL_FrameworkMasker relies on.
	 */
	@IsTest
	private static void applyJsonKeyRuleToTreeShouldHandleNull()
	{
		System.runAs(getTestAdmin())
		{
			Object result = UTIL_String.applyJsonKeyRuleToTree(null, '^password$', '***', false);

			Assert.isNull(result, 'Null tree should return null');
		}
	}

	/**
	 * @description Tests that `resolveQualifiedFieldName` assembles the qualified field path from
	 * the `SObjectType__r.QualifiedApiName` + `Field__r.QualifiedApiName` relationship fields
	 * when both are populated. This is the shape real deployed CMDT records expose via the
	 * selector. Mocks normally put the already-qualified string in `Field__c`, so this test
	 * covers the metadata-relationship branch explicitly.
	 */
	@IsTest
	private static void shouldResolveQualifiedFieldNameFromRelationshipFields()
	{
		System.runAs(getTestAdmin())
		{
			EntityDefinition entityDefinition = (EntityDefinition)TST_Builder.of(EntityDefinition.SObjectType)
					.withOverride(EntityDefinition.QualifiedApiName, 'Foobar__c')
					.withoutInsertion()
					.build();

			FieldDefinition fieldDefinition = (FieldDefinition)TST_Builder.of(FieldDefinition.SObjectType)
					.withOverride(FieldDefinition.QualifiedApiName, 'Text__c')
					.withoutInsertion()
					.build();

			MaskingTarget__mdt target = (MaskingTarget__mdt)TST_Builder.of(MaskingTarget__mdt.SObjectType)
					.withOverride(MaskingTarget__mdt.SObjectType__c, entityDefinition)
					.withOverride(MaskingTarget__mdt.Field__c, fieldDefinition)
					.withoutInsertion(true)
					.build();

			String resolved = UTIL_FrameworkMasker.resolveQualifiedFieldName(target);

			Assert.areEqual('Foobar__c.Text__c', resolved, 'Resolved name should be assembled from relationship fields');
		}
	}

	/**
	 * @description A deployed target whose field was deleted still has its related object and field records, but
	 * neither carries an API name, and the selector has no name for the stored value. The resolver then returns the
	 * stored `Field__c` value, so the key and the warning text carry the stored durable Ids, not `null.null`.
	 */
	@IsTest
	private static void shouldResolveTheStoredValueForATargetWhoseFieldWasDeleted()
	{
		System.runAs(getTestAdmin())
		{
			EntityDefinition entityDefinition = (EntityDefinition)TST_Builder.of(EntityDefinition.SObjectType).withoutInsertion().build();
			FieldDefinition fieldDefinition = (FieldDefinition)TST_Builder.of(FieldDefinition.SObjectType).withoutInsertion().build();
			MaskingTarget__mdt target = (MaskingTarget__mdt)TST_Builder.of(MaskingTarget__mdt.SObjectType)
					.withOverride(MaskingTarget__mdt.SObjectType__c, entityDefinition)
					.withOverride(MaskingTarget__mdt.Field__c, fieldDefinition)
					.withoutInsertion(true)
					.build();
			target.SObjectType__c = DELETED_FIELD_DURABLE_ID.substringBefore(UTIL_String.DOT);
			target.Field__c = DELETED_FIELD_DURABLE_ID;

			Assert.isNotNull(target.SObjectType__r, 'Expected the target to carry a related object record');
			Assert.isNotNull(target.Field__r, 'Expected the target to carry a related field record');
			Assert.isNull(target.Field__r.QualifiedApiName, 'Expected the related field record to carry no API name');

			String resolved = UTIL_FrameworkMasker.resolveQualifiedFieldName(target);

			Assert.areEqual(DELETED_FIELD_DURABLE_ID, resolved, 'Expected the stored field value when no API name is known');
		}
	}

	/**
	 * @description Tests that a target naming a field wins over a wildcard (blank Field__c) target
	 * with the same rule and caller. This is the rule in `selectApplicableTargets` that a named field
	 * beats a wildcard. The wildcard target should be left out of the applicable targets, so only the
	 * target naming the field runs.
	 */
	@IsTest
	private static void shouldShadowWildcardTargetWithSpecificTarget()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('SharedRule', SEL_MaskingRule.MODE_EXACT_MATCH, 'foo', 'BAR', 10)
					.withoutInsertion(true)
					.build();
			registerMockTarget(rule, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c), null);
			registerMockTarget(rule, null, null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('foo here');

			Assert.areEqual('BAR here', result.maskedValue, 'Specific-field target should apply');
			Assert.areEqual(1, result.rulesMatched, 'The target naming the field should win over the wildcard, so the rule runs only once');
		}
	}

	/**
	 * @description Tests that a JsonKey rule invalidated by a failure on an earlier record is
	 * skipped for later records in the same bulk operation. Exercises the invalidation filter
	 * inside `applyJsonKeyBatchStatic`. The filter skips the rule's work on records
	 * processed against a cached BatchPlan that still references the now-invalid target.
	 */
	@IsTest
	private static void shouldSkipInvalidatedJsonKeyRuleOnLaterRecord()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarTextArea(SEL_MaskingRule.MODE_JSON_KEY, '([bad', '***', null);

			Foobar__c firstRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.TextArea__c, '{"password":"hunter2"}')
					.withoutInsertion()
					.build();
			Foobar__c secondRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.TextArea__c, '{"password":"other"}')
					.withoutInsertion()
					.build();

			List<UTIL_FrameworkMasker.MaskingResult> results = UTIL_FrameworkMasker.forRecords(new List<SObject> {firstRecord, secondRecord}).apply();

			Assert.isTrue(results.get(0).hadErrors, 'First record should record the JsonKey failure');
			Assert.isFalse(results.get(1).hadErrors, 'Second record should skip the already-invalidated JsonKey rule');
			Assert.isTrue(UTIL_FrameworkMasker.invalidatedRuleDeveloperNames.contains('TestRule'), 'Rule should be in the invalidation set');
		}
	}

	/**
	 * @description Tests that a Regex/ExactMatch rule invalidated by a failure on an earlier
	 * record is skipped for later records in the same bulk operation. Exercises the
	 * invalidation filter inside `applySingleTargetStatic`. The filter skips the rule's
	 * work on records processed against a cached BatchPlan that still references the now-invalid
	 * target.
	 */
	@IsTest
	private static void shouldSkipInvalidatedSingleTargetRuleOnLaterRecord()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_REGEX, '([bad', 'X', null);

			Foobar__c firstRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'first')
					.withoutInsertion()
					.build();
			Foobar__c secondRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'second')
					.withoutInsertion()
					.build();

			List<UTIL_FrameworkMasker.MaskingResult> results = UTIL_FrameworkMasker.forRecords(new List<SObject> {firstRecord, secondRecord}).apply();

			Assert.isTrue(results.get(0).hadErrors, 'First record should record the Regex failure');
			Assert.isFalse(results.get(1).hadErrors, 'Second record should skip the already-invalidated Regex rule');
			Assert.isTrue(UTIL_FrameworkMasker.invalidatedRuleDeveloperNames.contains('TestRule'), 'Rule should be in the invalidation set');
		}
	}

	/**
	 * @description Tests that a wildcard MaskingTarget (blank `Field__c`) applied through
	 * `RecordMasker.apply` expands to every text field it covers on the SObjectType, through
	 * `buildBatchPlan` and `getTextFieldsCoveredByWildcard`. The same rule fires on `Text__c`,
	 * `TextArea__c`, `Email__c`, and every other text field that holds matching input.
	 */
	@IsTest
	private static void shouldApplyWildcardTargetViaRecordMasker()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('WildcardRule', SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', 10)
					.withoutInsertion(true)
					.build();
			registerMockTarget(rule, null, null);

			Foobar__c record = buildFoobarWithTextAndTextArea('the secret one', 'another secret');

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual('the X one', record.Text__c, 'Wildcard rule should fire on Text__c');
			Assert.areEqual('another X', record.TextArea__c, 'Wildcard rule should fire on TextArea__c');
			Assert.areEqual(2, result.rulesMatched, 'Wildcard rule should match on every populated text field');
		}
	}

	/**
	 * @description Tests that `getTextFieldsCoveredByWildcard` returns a non-empty list for Foobar__c. Runs
	 * the code that finds and filters the text fields directly, so the cache and the field-type
	 * filter are both covered on their own, apart from the RecordMasker path.
	 */
	@IsTest
	private static void shouldEnumerateTextFieldsCoveredByWildcard()
	{
		System.runAs(getTestAdmin())
		{
			List<SObjectField> first = UTIL_FrameworkMasker.getTextFieldsCoveredByWildcard(Foobar__c.SObjectType);
			List<SObjectField> second = UTIL_FrameworkMasker.getTextFieldsCoveredByWildcard(Foobar__c.SObjectType);

			Assert.isFalse(first.isEmpty(), 'Foobar__c should have at least one text field a wildcard covers');
			Assert.areEqual(first.size(), second.size(), 'Cached lookup should return the same list on repeated calls');
		}
	}

	/**
	 * @description Tests the check for one field that the wildcard list is built from. An ordinary text field is
	 * covered, an identifier is not, and a field that cannot be found is not covered either.
	 */
	@IsTest
	private static void shouldReportWhetherAWildcardCoversOneField()
	{
		System.runAs(getTestAdmin())
		{
			Assert.isTrue(UTIL_FrameworkMasker.isCoveredByWildcard(Foobar__c.Text__c), 'Expected an ordinary text field to be covered');
			Assert.isFalse(UTIL_FrameworkMasker.isCoveredByWildcard(Foobar__c.ExternalId__c), 'Expected an external id not to be covered');
			Assert.isFalse(UTIL_FrameworkMasker.isCoveredByWildcard(null), 'Expected a field that cannot be found not to be covered');
		}
	}

	/**
	 * @description Tests that a wildcard target never expands to a field that identifies the record:
	 * a unique key or an external id. Masking rewrites the value it matches; on a key that means the
	 * key is destroyed and, on a unique index, the NEXT record whose key masks to the same constant
	 * fails to insert. A chain correlation id built from a long numeric order number is exactly the
	 * shape a payment-card rule matches, and `AsyncChainExecution__c.CorrelationId__c` is unique.
	 */
	@IsTest
	private static void shouldNotExpandWildcardToUniqueOrExternalIdFields()
	{
		System.runAs(getTestAdmin())
		{
			Set<SObjectField> chainFields = new Set<SObjectField>(UTIL_FrameworkMasker.getTextFieldsCoveredByWildcard(AsyncChainExecution__c.SObjectType));
			Set<SObjectField> foobarFields = new Set<SObjectField>(UTIL_FrameworkMasker.getTextFieldsCoveredByWildcard(Foobar__c.SObjectType));

			Assert.isFalse(chainFields.contains(AsyncChainExecution__c.CorrelationId__c), 'A unique external-id key must never be a wildcard masking target');
			Assert.isFalse(chainFields.contains(AsyncChainExecution__c.ActiveDeduplicationKey__c), 'The unique deduplication key must never be a wildcard masking target');
			Assert.isTrue(chainFields.contains(AsyncChainExecution__c.ErrorMessage__c), 'Ordinary text fields on the same object still expand');
			Assert.isFalse(foobarFields.contains(Foobar__c.ExternalId__c), 'An external id that is not unique is still an identifier and must not be masked by a wildcard');
			Assert.isTrue(foobarFields.contains(Foobar__c.Text__c), 'Ordinary text fields on Foobar__c still expand');
		}
	}

	/**
	 * @description Tests the check for identifier fields, which every wildcard decision uses. It
	 * reads the field's describe settings and handles a field that cannot be found.
	 */
	@IsTest
	private static void shouldReportIdentifierFieldsFromTheirDescribeFacets()
	{
		System.runAs(getTestAdmin())
		{
			Assert.isTrue(UTIL_FrameworkMasker.isIdentifierField(Foobar__c.ExternalId__c), 'An external id identifies its record');
			Assert.isFalse(UTIL_FrameworkMasker.isIdentifierField(Foobar__c.Text__c), 'An ordinary text field does not');
			Assert.isFalse(UTIL_FrameworkMasker.isIdentifierField((SObjectField)null), 'An unresolved field is not an identifier');
		}
	}

	/**
	 * @description Tests that a wildcard target never fires on an identifier field through `forField`
	 * either, which is the preview and sample path the advisor uses. Without this the preview would show a masking
	 * the record path (whose wildcard expansion skips identifier fields) never performs.
	 */
	@IsTest
	private static void shouldNotFireWildcardTargetOnIdentifierFieldThroughForField()
	{
		System.runAs(getTestAdmin())
		{
			mockTarget(null, SEL_MaskingRule.MODE_REGEX, '\\d+', 'XXX', null, 'TestRule', 10, null);

			UTIL_FrameworkMasker.MaskingResult identifierResult = UTIL_FrameworkMasker.forField(Foobar__c.ExternalId__c).mask('order 4111111111111111');
			UTIL_FrameworkMasker.MaskingResult textResult = UTIL_FrameworkMasker.forField(Foobar__c.Text__c).mask('order 4111111111111111');

			Assert.areEqual('order 4111111111111111', identifierResult.maskedValue, 'A wildcard must not rewrite an identifier field, even in preview');
			Assert.areEqual(0, identifierResult.rulesMatched, 'No rule should report a match on the identifier field');
			Assert.areEqual('order XXX', textResult.maskedValue, 'The same wildcard still fires on an ordinary text field');
		}
	}

	/**
	 * @description Tests that a target naming an identifier field explicitly is still applied: it is
	 * the administrator's deliberate choice. Only the wildcard skips identifier fields.
	 */
	@IsTest
	private static void shouldHonourExplicitTargetOnIdentifierField()
	{
		System.runAs(getTestAdmin())
		{
			mockTarget(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.ExternalId__c), SEL_MaskingRule.MODE_REGEX, '\\d+', 'XXX', null, 'TestRule', 10, null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(Foobar__c.ExternalId__c).mask('order 12345');

			Assert.areEqual('order XXX', result.maskedValue, 'An explicit target on an identifier field is the administrator\'s deliberate choice and fires');
			Assert.areEqual(1, result.rulesMatched, 'The explicit rule should report its match');
		}
	}

	/**
	 * @description Tests that a wildcard target never covers the chain engine's run key. Every process running a
	 * chain run holds a copy of the key and compares it with the stored one. The key is random, and about once in
	 * several thousand keys its digit groups look like a payment card. Masking would then rewrite only the stored
	 * copy, and every process of that run would stop as out of date, leaving the run Running with no error
	 * anywhere.
	 */
	@IsTest
	private static void shouldNotExpandWildcardToTheChainRunKey()
	{
		System.runAs(getTestAdmin())
		{
			Set<SObjectField> chainFields = new Set<SObjectField>(UTIL_FrameworkMasker.getTextFieldsCoveredByWildcard(AsyncChainExecution__c.SObjectType));

			Assert.isFalse(chainFields.contains(AsyncChainExecution__c.RunKey__c), 'The run key is a fence token the engine compares for equality; no wildcard may rewrite it');
			Assert.isFalse(chainFields.contains(AsyncChainExecution__c.CurrentJobId__c), 'The job id is what the watchdog reads for liveness; no wildcard may rewrite it');
			Assert.isTrue(chainFields.contains(AsyncChainExecution__c.ErrorMessage__c), 'Ordinary text fields on the chain object still expand');
		}
	}

	/**
	 * @description Tests the record path end to end: a wildcard card rule applied to a chain run whose run key reads
	 * as a card number leaves the key exactly as minted while redacting the same digits in an ordinary text field of
	 * the same record.
	 */
	@IsTest
	private static void shouldLeaveTheChainRunKeyAsMintedUnderAWildcardCardRule()
	{
		System.runAs(getTestAdmin())
		{
			registerMockTargetOn(AsyncChainExecution__c.SObjectType, mockCardRule(), null, null);
			AsyncChainExecution__c run = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.RunKey__c, CARD_SHAPED_RUN_KEY)
					.withOverride(AsyncChainExecution__c.ErrorMessage__c, 'card ' + CARD_SHAPED_RUN_KEY.substringAfterLast('4768-'))
					.withoutInsertion(true)
					.build();

			UTIL_FrameworkMasker.forRecord(run).apply();

			Assert.areEqual(CARD_SHAPED_RUN_KEY, run.RunKey__c, 'The run key must leave the masker exactly as minted');
			Assert.areEqual('card ' + CARD_REPLACEMENT, run.ErrorMessage__c, 'The same digits in an ordinary text field are redacted');
		}
	}

	/**
	 * @description Tests the preview path: a wildcard never fires on the run key through `forField` either, so the
	 * advisor's preview never claims a masking the record path refuses.
	 */
	@IsTest
	private static void shouldNotFireWildcardTargetOnTheChainRunKeyThroughForField()
	{
		System.runAs(getTestAdmin())
		{
			registerMockTargetOn(AsyncChainExecution__c.SObjectType, mockCardRule(), null, null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(AsyncChainExecution__c.RunKey__c).mask(CARD_SHAPED_RUN_KEY);

			Assert.areEqual(CARD_SHAPED_RUN_KEY, result.maskedValue, 'A wildcard must not rewrite the run key, even in preview');
			Assert.areEqual(0, result.rulesMatched, 'No rule should report a match on the run key');
		}
	}

	/**
	 * @description Tests that a target naming the run key explicitly is still honoured, as for an identifier field:
	 * the administrator's deliberate choice; only the wildcard steps around the fence token.
	 */
	@IsTest
	private static void shouldHonourExplicitTargetOnTheChainRunKey()
	{
		System.runAs(getTestAdmin())
		{
			registerMockTargetOn(AsyncChainExecution__c.SObjectType, mockCardRule(), UTIL_SObjectDescribe.getCachedFieldName(AsyncChainExecution__c.RunKey__c), null);

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(AsyncChainExecution__c.RunKey__c).mask(CARD_SHAPED_RUN_KEY);

			Assert.areEqual('fb1f69f6-6768-4768-' + CARD_REPLACEMENT, result.maskedValue, 'An explicit target on the run key is the administrator\'s deliberate choice and fires');
			Assert.areEqual(1, result.rulesMatched, 'The explicit rule should report its match');
		}
	}

	/**
	 * @description Tests that on a platform event a wildcard covers the custom text fields only. The platform sets
	 * the standard event fields `ReplayId` and `EventUuid` itself, so a wildcard must never cover them, while a custom
	 * field such as the log event's `Message__c` is covered.
	 */
	@IsTest
	private static void shouldExpandWildcardOnlyToCustomTextFieldsOfAPlatformEvent()
	{
		System.runAs(getTestAdmin())
		{
			Set<SObjectField> eventFields = new Set<SObjectField>(UTIL_FrameworkMasker.getTextFieldsCoveredByWildcard(LogEntryEvent__e.SObjectType));

			Assert.isFalse(eventFields.contains(LogEntryEvent__e.ReplayId), 'Expected the standard field ReplayId to stay out of the wildcard list');
			Assert.isFalse(eventFields.contains(LogEntryEvent__e.EventUuid), 'Expected the standard field EventUuid to stay out of the wildcard list');
			Assert.isTrue(eventFields.contains(LogEntryEvent__e.Message__c), 'Expected the custom text field Message__c in the wildcard list');
		}
	}

	/**
	 * @description Tests that `RecordMasker.apply` skips fields whose value is an empty string
	 * (not null): the check for a filled but empty value inside `applyFieldPlanToRecord`.
	 */
	@IsTest
	private static void shouldSkipEmptyStringFieldValueOnRecord()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, UTIL_String.EMPTY)
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(0, result.rulesMatched, 'No rules should fire when the field is an empty string');
			Assert.isFalse(result.hadErrors, 'Empty-string field skip is not a failure');
			Assert.areEqual(UTIL_String.EMPTY, record.Text__c, 'Record value should remain empty');
		}
	}

	/**
	 * @description Tests that a rule with `ApplicableFieldTypes__c` populated is filtered out
	 * of the batch plan for fields whose Apex `DisplayType` is excluded: no cost for each record,
	 * no regex run, no changed value. Card-masking rules can then limit themselves to
	 * `STRING;TEXTAREA;ENCRYPTEDSTRING`, which removes URL, Email and Phone fields from the loop over
	 * records entirely.
	 */
	@IsTest
	private static void shouldSkipRuleOnUrlFieldWhenExcludedByApplicableFieldTypes()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarWildcardWithApplicableFieldTypes
					(
							SEL_MaskingRule.MODE_REGEX,
							'\\d{16}',
							'X',
							'TestCardExcludeUrl',
							'STRING;TEXTAREA'
					);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.URL__c, 'https://example.com?acct=4111111111111111')
					.withOverride(Foobar__c.Text__c, 'customer charged 4111111111111111 today')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.isTrue(record.URL__c.contains('4111111111111111'), 'Url-typed field must be skipped when rule excludes URL via ApplicableFieldTypes__c');
			Assert.isTrue(record.Text__c.contains('X'), 'Text-typed field must still be scanned when rule includes STRING/TEXTAREA');
		}
	}

	/**
	 * @description Tests that when a `MaskingTarget__mdt` explicitly wires a rule to a specific
	 * `Field__c` whose DisplayType is excluded by the rule's `ApplicableFieldTypes__c`, the
	 * framework emits a one-time warning log to surface the misconfiguration. Without this
	 * signal, the admin's explicit wiring would be silently overridden by the rule-level
	 * filter: the rule would not run, but nothing in the log stream would explain why.
	 */
	@IsTest
	private static void shouldWarnOnceWhenSpecificFieldTargetDroppedByTypeFilter()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('TestSpecificFieldMismatch', SEL_MaskingRule.MODE_REGEX, '\\d{16}', 'X', 10)
					.withOverride(MaskingRule__mdt.ApplicableFieldTypes__c, 'STRING;TEXTAREA')
					.withoutInsertion(true)
					.build();
			registerMockTarget(rule, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.URL__c), null);

			UTIL_FrameworkMasker.warnedSpecificFieldTypeMismatches.clear();

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.URL__c, 'https://example.com?acct=4111111111111111')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.isTrue(record.URL__c.contains('4111111111111111'), 'A target naming the field must not override the rule-level type filter: the rule should not run');
			Assert.areEqual(1, UTIL_FrameworkMasker.warnedSpecificFieldTypeMismatches.size(), 'Framework must warn once when explicit wiring is dropped by the type filter');
			String expectedWarnKey = 'masking:excluded-field-type:TestSpecificFieldMismatch:'
					+ UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType) + UTIL_String.DOT + UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.URL__c);
			Assert.isTrue
					(
							UTIL_FrameworkMasker.warnedSpecificFieldTypeMismatches.contains(expectedWarnKey),
							'Warning key must identify rule, object and field so admins can locate the misconfigured target (expected ' + expectedWarnKey + ')'
					);

			UTIL_FrameworkMasker.cachedBatchPlans.clear();
			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(1, UTIL_FrameworkMasker.warnedSpecificFieldTypeMismatches.size(),
					'Warning must be written exactly once per rule and field pair per transaction: '
					+ 'clearing cachedBatchPlans forces the second apply to rebuild and re-enter '
					+ 'filterTargetsByFieldType, the contains-guard must suppress the duplicate warning');
		}
	}

	/**
	 * @description Tests that a rule with a blank `ApplicableFieldTypes__c` CSV applies to every
	 * text field, which is the original behaviour before field-type filters existed. Guards against a regression where
	 * an overly aggressive filter treats an unpopulated CSV as "no field types" instead of "all".
	 */
	@IsTest
	private static void shouldApplyRuleToAllTextFieldsWhenApplicableFieldTypesBlank()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarWildcardWithApplicableFieldTypes
					(
							SEL_MaskingRule.MODE_EXACT_MATCH,
							'secret',
							'X',
							'TestBlankFilter',
							null
					);

			Foobar__c record = buildFoobarWithTextAndTextArea('the secret one', 'another secret');

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual('the X one', record.Text__c, 'Blank ApplicableFieldTypes__c should still match STRING fields');
			Assert.areEqual('another X', record.TextArea__c, 'Blank ApplicableFieldTypes__c should still match TEXTAREA fields');
		}
	}

	/**
	 * @description Tests that the `ApplicableFieldTypes__c` CSV matches case-insensitively and
	 * trims spaces around entries: admins who set up CMDT through the UI may type
	 * ` string ; textarea ` and expect it to work the same as `STRING;TEXTAREA`.
	 */
	@IsTest
	private static void shouldMatchApplicableFieldTypesCaseInsensitivelyAndTrimmed()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarWildcardWithApplicableFieldTypes
					(
							SEL_MaskingRule.MODE_EXACT_MATCH,
							'secret',
							'X',
							'TestMixedCase',
							' string ; textarea '
					);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'the secret one')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual('the X one', record.Text__c, 'Lower-case CSV with whitespace should still admit STRING-typed fields');
		}
	}

	/**
	 * @description Tests the defensive fallback when every `ApplicableFieldTypes__c` token
	 * is unknown. If no token resolves the filter treats the rule as blank (apply to every
	 * text-shaped field) so misspelled configuration cannot silently disable a rule that is
	 * protecting sensitive data.
	 */
	@IsTest
	private static void shouldFallBackToApplyAllWhenApplicableFieldTypesAreAllUnknown()
	{
		System.runAs(getTestAdmin())
		{
			mockTargetForFoobarWildcardWithApplicableFieldTypes
					(
							SEL_MaskingRule.MODE_EXACT_MATCH,
							'secret',
							'X',
							'TestAllTypos',
							'STRNIG;TEXARE;ENCYRPTED'
					);

			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Text__c, 'the secret one')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual('the X one', record.Text__c,
					'Fully-typoed ApplicableFieldTypes must fall back to apply-to-all (secure default) so protection is not silently disabled');
		}
	}

	/**
	 * @description Tests that `parseApplicableFieldTypes` tolerates blank tokens produced by
	 * consecutive semicolons or whitespace-only entries in the CSV. Admins typing
	 * `STRING;;TEXTAREA` or `STRING; ;TEXTAREA` must get the same behaviour as `STRING;TEXTAREA`:
	 * the blank slot is skipped, not treated as an unknown token (which would trigger the
	 * "all unknown → apply everywhere" fallback).
	 */
	@IsTest
	private static void shouldSkipBlankTokensInApplicableFieldTypes()
	{
		MaskingRule__mdt rule = TST_Factory.newMaskingRule(new Map<SObjectField, Object>
		{
				MaskingRule__mdt.DeveloperName => 'TestBlankTokens',
				MaskingRule__mdt.ApplicableFieldTypes__c => 'STRING;; ;TEXTAREA'
		});
		MaskingTarget__mdt target = TST_Factory.newMaskingTarget(new Map<SObjectField, Object>(), rule);

		Set<DisplayType> allowedTypes = UTIL_FrameworkMasker.parseApplicableFieldTypes(target);

		Assert.areEqual(2, allowedTypes.size(), 'Blank tokens must be skipped, not counted as unknown');
		Assert.isTrue(allowedTypes.contains(DisplayType.STRING), 'STRING token must resolve');
		Assert.isTrue(allowedTypes.contains(DisplayType.TEXTAREA), 'TEXTAREA token must resolve');
	}

	/**
	 * @description Tests that `parseApplicableFieldTypes` caches by the raw list text: later calls
	 * with the same list must return the same Set without splitting it again. Bulk triggers check the
	 * same rule for hundreds of field and record pairs; this cache keeps that cost constant instead of
	 * growing with the number of pairs.
	 */
	@IsTest
	private static void shouldCacheParsedApplicableFieldTypesByCsv()
	{
		MaskingRule__mdt rule = TST_Factory.newMaskingRule(new Map<SObjectField, Object>
		{
				MaskingRule__mdt.DeveloperName => 'TestCacheByCsv',
				MaskingRule__mdt.ApplicableFieldTypes__c => 'STRING;TEXTAREA'
		});
		MaskingTarget__mdt target = TST_Factory.newMaskingTarget(new Map<SObjectField, Object>(), rule);

		Set<DisplayType> first = UTIL_FrameworkMasker.parseApplicableFieldTypes(target);
		UTIL_FrameworkMasker.parseApplicableFieldTypes(target);

		Assert.isTrue(UTIL_FrameworkMasker.cachedAllowedTypesByCsv.containsKey('STRING;TEXTAREA'), 'CSV key must be stored in the transaction cache after first parse');
		Assert.areEqual(2, first.size(), 'Two known tokens must resolve to two DisplayType enum values');
		Assert.isTrue(first.contains(DisplayType.STRING), 'STRING token must resolve to DisplayType.STRING');
		Assert.isTrue(first.contains(DisplayType.TEXTAREA), 'TEXTAREA token must resolve to DisplayType.TEXTAREA');
	}

	/**
	 * @description Registers a single active MaskingTarget pointing at Foobar__c.Text__c with an inline rule.
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 */
	private static void mockTargetForFoobarText(String mode, String rulePattern, String replacement, String callerClassScope)
	{
		mockTarget(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c), mode, rulePattern, replacement, callerClassScope, 'TestRule', 10, null);
	}

	/**
	 * @description Registers a MaskingTarget pointing at Foobar__c.Text__c with an explicit
	 * `FailureAction__c` value, for failure-handling tests (LogAndContinue / WriteFailureMarker / BlockDml).
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern (typically malformed so the rule throws)
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 * @param failureAction The MaskingRule__mdt.FailureAction__c picklist value to assign
	 */
	private static void mockTargetForFoobarTextWithFailureAction(String mode, String rulePattern, String replacement, String callerClassScope, String failureAction)
	{
		mockTarget(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c), mode, rulePattern, replacement, callerClassScope, 'TestRule', 10, failureAction);
	}

	/**
	 * @description Registers a wildcard MaskingTarget (blank `Field__c`) on Foobar__c with an
	 * explicit `ApplicableFieldTypes__c` semicolon-delimited CSV so field-type-filter tests can
	 * verify that fields whose `DisplayType` is excluded from the rule are dropped at
	 * the time the batch plan is built, at no cost for each record.
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern
	 * @param replacement Rule replacement
	 * @param ruleDeveloperName The MaskingRule__mdt DeveloperName to assign
	 * @param applicableFieldTypes The semicolon-delimited list of Apex DisplayType names (e.g. `STRING;TEXTAREA`)
	 */
	private static void mockTargetForFoobarWildcardWithApplicableFieldTypes
			(
					String mode,
					String rulePattern,
					String replacement,
					String ruleDeveloperName,
					String applicableFieldTypes
			)
	{
		MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder(ruleDeveloperName, mode, rulePattern, replacement, 10)
				.withOverride(MaskingRule__mdt.ApplicableFieldTypes__c, applicableFieldTypes)
				.withoutInsertion(true)
				.build();
		registerMockTarget(rule, null, null);
	}

	/**
	 * @description Registers a MaskingTarget pointing at Foobar__c.Text__c with an explicit
	 * `MinInputLength__c`, for tests that prove rules are skipped when the value
	 * is shorter than the configured threshold.
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 * @param minInputLength The MaskingRule__mdt.MinInputLength__c value; rule is skipped when the value is shorter
	 */
	private static void mockTargetForFoobarTextWithMinInputLength
			(
					String mode,
					String rulePattern,
					String replacement,
					String callerClassScope,
					Integer minInputLength
			)
	{
		mockTargetForFoobarTextWithMinInputLength(mode, rulePattern, replacement, callerClassScope, minInputLength, null);
	}

	/**
	 * @description Registers a MaskingTarget pointing at Foobar__c.Text__c with both a minimum input length and a
	 * failure action, for tests that prove a short value stays as it is after the rule failed.
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 * @param minInputLength The MaskingRule__mdt.MinInputLength__c value; rule is skipped when the value is shorter
	 * @param failureAction The MaskingRule__mdt.FailureAction__c value; null leaves it unset
	 */
	private static void mockTargetForFoobarTextWithMinInputLength
			(
					String mode,
					String rulePattern,
					String replacement,
					String callerClassScope,
					Integer minInputLength,
					String failureAction
			)
	{
		MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder(TEST_RULE_NAME, mode, rulePattern, replacement, 10)
				.withOverride(MaskingRule__mdt.MinInputLength__c, minInputLength)
				.withOverride(MaskingRule__mdt.FailureAction__c, failureAction)
				.withoutInsertion(true)
				.build();
		registerMockTarget(rule, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c), callerClassScope);
	}

	/**
	 * @description Registers a MaskingTarget pointing at Foobar__c.Text__c with a custom rule
	 * developer name and Order__c, for duplicate and ordering tests.
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 * @param ruleDeveloperName The MaskingRule__mdt DeveloperName to assign
	 * @param ruleOrder The MaskingRule__mdt.Order__c value controlling execution sequence
	 */
	private static void mockTargetForFoobarText(String mode, String rulePattern, String replacement, String callerClassScope, String ruleDeveloperName, Integer ruleOrder)
	{
		mockTarget(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c), mode, rulePattern, replacement, callerClassScope, ruleDeveloperName, ruleOrder, null);
	}

	/**
	 * @description Registers a MaskingTarget pointing at Foobar__c.Text__c with a custom rule developer name, Order__c
	 * and `FailureAction__c`, for tests where a rule that fails runs before or after another rule on the same field.
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 * @param ruleDeveloperName The MaskingRule__mdt DeveloperName to assign
	 * @param ruleOrder The MaskingRule__mdt.Order__c value controlling execution sequence
	 * @param failureAction The MaskingRule__mdt.FailureAction__c value; null leaves it unset
	 */
	private static void mockTargetForFoobarText
			(
					String mode,
					String rulePattern,
					String replacement,
					String callerClassScope,
					String ruleDeveloperName,
					Integer ruleOrder,
					String failureAction
			)
	{
		mockTarget(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c), mode, rulePattern, replacement, callerClassScope, ruleDeveloperName, ruleOrder, failureAction);
	}

	/**
	 * @description Registers a single active MaskingTarget pointing at Foobar__c.TextArea__c with an inline rule.
	 * Used by shouldSkipRulesForOtherFields to prove targets for a different field don't fire.
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope
	 */
	private static void mockTargetForFoobarTextArea(String mode, String rulePattern, String replacement, String callerClassScope)
	{
		mockTarget(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.TextArea__c), mode, rulePattern, replacement, callerClassScope, 'TestRule', 10, null);
	}

	/**
	 * @description Registers a MaskingTarget pointing at Foobar__c.TextArea__c with an explicit `FailureAction__c`
	 * value, for failure-handling tests on the JSON path.
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern (typically malformed so the rule throws)
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 * @param failureAction The MaskingRule__mdt.FailureAction__c picklist value to assign
	 */
	private static void mockTargetForFoobarTextAreaWithFailureAction(String mode, String rulePattern, String replacement, String callerClassScope, String failureAction)
	{
		mockTarget(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.TextArea__c), mode, rulePattern, replacement, callerClassScope, TEST_RULE_NAME, 10, failureAction);
	}

	/**
	 * @description Registers a MaskingTarget pointing at Foobar__c.TextArea__c with a custom rule
	 * developer name and Order__c, for batching and ordering tests.
	 *
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 * @param ruleDeveloperName The MaskingRule__mdt DeveloperName to assign
	 * @param ruleOrder The MaskingRule__mdt.Order__c value controlling execution sequence
	 */
	private static void mockTargetForFoobarTextArea(String mode, String rulePattern, String replacement, String callerClassScope, String ruleDeveloperName, Integer ruleOrder)
	{
		mockTarget(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.TextArea__c), mode, rulePattern, replacement, callerClassScope, ruleDeveloperName, ruleOrder, null);
	}

	/**
	 * @description Registers a MaskingTarget for a specific field on Foobar__c.
	 *
	 * @param fieldApiName The field API name (without the Foobar__c. prefix)
	 * @param mode Rule mode
	 * @param rulePattern Rule pattern
	 * @param replacement Rule replacement
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 * @param ruleDeveloperName The MaskingRule__mdt DeveloperName to assign
	 * @param ruleOrder The MaskingRule__mdt.Order__c value controlling execution sequence
	 * @param failureAction The MaskingRule__mdt.FailureAction__c value; null leaves it unset
	 */
	private static void mockTarget
			(
					String fieldApiName,
					String mode,
					String rulePattern,
					String replacement,
					String callerClassScope,
					String ruleDeveloperName,
					Integer ruleOrder,
					String failureAction
			)
	{
		MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder(ruleDeveloperName, mode, rulePattern, replacement, ruleOrder)
				.withOverride(MaskingRule__mdt.FailureAction__c, failureAction)
				.withoutInsertion(true)
				.build();
		registerMockTarget(rule, fieldApiName, callerClassScope);
	}

	/**
	 * @description Shared rule builder for the `mockTarget*` helper family. Returns a
	 * partially-configured `TST_Builder.Builder` with the six overrides every test-mock
	 * rule needs (DeveloperName, Mode, Pattern, Replacement, IsActive=true, Order). Callers
	 * chain their specialization overrides (FailureAction, MinInputLength,
	 * ApplicableFieldTypes, etc.) and terminate with `.withoutInsertion(true).build()`.
	 *
	 * @param developerName Rule DeveloperName
	 * @param mode Rule Mode__c
	 * @param pattern Rule Pattern__c
	 * @param replacement Rule Replacement__c
	 * @param order Rule Order__c
	 *
	 * @return A TST_Builder.Builder with the common rule overrides already applied
	 */
	private static TST_Builder.Builder mockRuleBuilder(String developerName, String mode, String pattern, String replacement, Decimal order)
	{
		return TST_Builder.of(MaskingRule__mdt.SObjectType)
				.withOverride(MaskingRule__mdt.DeveloperName, developerName)
				.withOverride(MaskingRule__mdt.Mode__c, mode)
				.withOverride(MaskingRule__mdt.Pattern__c, pattern)
				.withOverride(MaskingRule__mdt.Replacement__c, replacement)
				.withOverride(MaskingRule__mdt.IsActive__c, true)
				.withOverride(MaskingRule__mdt.Order__c, order);
	}

	/**
	 * @description Registers a single active `MaskingTarget__mdt` record for the given rule.
	 * Pass a blank `fieldApiName` to register a wildcard target (`Field__c = null`).
	 *
	 * @param rule The pre-built rule the target should point at
	 * @param fieldApiName The Foobar__c field API name (without object prefix); blank for a wildcard target
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 */
	private static void registerMockTarget(MaskingRule__mdt rule, String fieldApiName, String callerClassScope)
	{
		registerMockTargetOn(Foobar__c.SObjectType, rule, fieldApiName, callerClassScope);
	}

	/**
	 * @description Registers a single active `MaskingTarget__mdt` record for the given rule on any SObjectType.
	 * Pass a blank `fieldApiName` to register a wildcard target (`Field__c = null`).
	 *
	 * @param sObjectType The SObjectType the target names
	 * @param rule The pre-built rule the target should point at
	 * @param fieldApiName The field API name (without object prefix); blank for a wildcard target
	 * @param callerClassScope Optional CallerClass__c scope; null means unscoped
	 */
	private static void registerMockTargetOn(SObjectType sObjectType, MaskingRule__mdt rule, String fieldApiName, String callerClassScope)
	{
		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(sObjectType);
		String fieldValue = String.isBlank(fieldApiName) ? null : objectName + UTIL_String.DOT + fieldApiName;

		TST_Mock.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.IsActive__c, true)
				.withOverride(MaskingTarget__mdt.SObjectType__c, objectName)
				.withOverride(MaskingTarget__mdt.Field__c, fieldValue)
				.withOverride(MaskingTarget__mdt.CallerClass__c, callerClassScope)
				.withOverride(MaskingTarget__mdt.Rule__c, rule)
				.build();
	}

	/**
	 * @description A mock with the shipped card rule's pattern and redaction token in regex mode (the shipped rules run
	 *              in credit-card mode with a Luhn check; the card-shaped run key these tests use passes it either way).
	 *
	 * @return An uninserted MaskingRule__mdt.
	 */
	private static MaskingRule__mdt mockCardRule()
	{
		return (MaskingRule__mdt)mockRuleBuilder('CardRule', SEL_MaskingRule.MODE_REGEX, CARD_PATTERN, CARD_REPLACEMENT, 10).withoutInsertion(true).build();
	}

	/**
	 * @description A rule that replaces the secret word wherever it appears in a value.
	 *
	 * @return An uninserted MaskingRule__mdt.
	 */
	private static MaskingRule__mdt mockSecretWordRule()
	{
		return (MaskingRule__mdt)mockRuleBuilder('SecretWordRule', SEL_MaskingRule.MODE_EXACT_MATCH, SECRET_WORD, SECRET_WORD_REPLACEMENT, 10).withoutInsertion(true).build();
	}

	/**
	 * @description A rule that replaces the sample email address wherever it appears in a value.
	 *
	 * @return An uninserted MaskingRule__mdt.
	 */
	private static MaskingRule__mdt mockEmailRule()
	{
		return (MaskingRule__mdt)mockRuleBuilder('EmailRule', SEL_MaskingRule.MODE_EXACT_MATCH, SAMPLE_VALUE, EMAIL_REPLACEMENT, 10).withoutInsertion(true).build();
	}

	/**
	 * @description Builds a Case, not saved, whose `ContactEmail` and `Description` both hold the given address. Apex
	 * cannot set `ContactEmail` directly, because the platform fills it from the case's contact, so the Case is read
	 * from JSON, which is how a record with that field set reaches the masker.
	 *
	 * @param emailAddress The address both fields hold
	 *
	 * @return A Case that is not saved
	 */
	private static Case buildCaseWithContactEmailAndDescription(String emailAddress)
	{
		Map<String, Object> values = new Map<String, Object>
		{
				UTIL_SObjectDescribe.getCachedFieldName(Case.ContactEmail) => emailAddress,
				UTIL_SObjectDescribe.getCachedFieldName(Case.Description) => emailAddress
		};
		return (Case)JSON.deserialize(JSON.serialize(values), Case.class);
	}

	/**
	 * @description Builds an uninserted Foobar__c with Text__c and TextArea__c pre-populated.
	 * Several wildcard-target tests exercise the framework against a record carrying values on
	 * both field types; this helper builds that common record.
	 *
	 * @param textValue Value for `Foobar__c.Text__c`
	 * @param textAreaValue Value for `Foobar__c.TextArea__c`
	 *
	 * @return An uninserted Foobar__c with both fields set, ready to pass to the framework masker
	 */
	private static Foobar__c buildFoobarWithTextAndTextArea(String textValue, String textAreaValue)
	{
		return (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Text__c, textValue)
				.withOverride(Foobar__c.TextArea__c, textAreaValue)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Builds a Foobar__c that is not saved, with `Text__c` set, for the tests on the masker's memory.
	 *
	 * @param textValue Value for `Foobar__c.Text__c`
	 *
	 * @return A Foobar__c with a test Id that is not saved
	 */
	private static Foobar__c buildFoobarWithText(String textValue)
	{
		return (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Text__c, textValue)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Builds a raw value whose masked text, after the growing rule, has exactly the given length: growing
	 * letters for most of it, then up to two letters the rule leaves as they are.
	 *
	 * @param maskedLength The number of characters the masked text must have
	 *
	 * @return The raw value
	 */
	private static String buildRawValueMaskedToLength(Integer maskedLength)
	{
		Integer growingLetterCount = maskedLength / GROWING_LETTER_REPLACEMENT.length();
		Integer unchangedLetterCount = maskedLength - growingLetterCount * GROWING_LETTER_REPLACEMENT.length();
		return GROWING_LETTER.repeat(growingLetterCount) + LETTER_NO_RULE_CHANGES.repeat(unchangedLetterCount);
	}

	/**
	 * @description Reads how many characters `Foobar__c.Text__c` can hold.
	 *
	 * @return The field's length
	 */
	private static Integer getTextFieldLength()
	{
		return UTIL_SObjectDescribe.getCachedFieldDescribe(Foobar__c.Text__c).getLength();
	}

	/**
	 * @description Proves that UTIL_FrameworkMasker applies configured masking rules to a record in
	 * place when a subscriber user on the Minimum Access - Salesforce profile calls it. The running
	 * user has no FLS on the kern__ MaskingTarget CMDT objects or on kern__Foobar__c, yet masking must
	 * still read the applicable targets (framework-internal selectors run in system mode through
	 * systemModeRequired), match the configured rule, and change the record's field value whatever
	 * the caller's FLS.
	 *
	 * Catches: if a later change moved SEL_MaskingTarget (or any other selector used by masking) to
	 * USER_MODE, the low-privilege user's apply call would quietly do nothing. This test then fails
	 * when the 2GP build is validated, not later in a subscriber scratch org.
	 *
	 * @see UTIL_FrameworkMasker.forRecord
	 */
	@IsTest
	private static void shouldMaskRecordForLowPrivilegeUser()
	{
		mockTargetForFoobarText(SEL_MaskingRule.MODE_EXACT_MATCH, 'secret', 'X', null);

		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Text__c, 'the secret is here')
				.withoutInsertion()
				.build();

		UTIL_FrameworkMasker.MaskingResult result;

		System.runAs(getLowPrivilegeUser())
		{
			result = UTIL_FrameworkMasker.forRecord(record).apply();
		}

		Assert.areEqual('the X is here', record.Text__c, 'Field value should be masked in place for low-privilege caller');
		Assert.areEqual(1, result.rulesMatched, 'Aggregate rulesMatched should reflect the single match');
		Assert.isFalse(result.hadErrors, 'Masking should complete without errors for low-privilege caller');
	}

	/**
	 * @description A wildcard target (one with a blank `Field__c`) masks a record that a user without field access
	 * saves. The user has the Minimum Access profile and no permission on any field of `Foobar__c`. Which fields a
	 * wildcard covers must not depend on who saves the record. If it did, this user's secret would be stored as it
	 * was received. The record is built inside `System.runAs`. The field details the framework reads are kept for the
	 * rest of the transaction, so details read first as the administrator would hide what this user is allowed to do.
	 */
	@IsTest
	private static void shouldMaskRecordThroughAWildcardTargetForAUserWithoutFieldAccess()
	{
		registerMockTarget(mockSecretWordRule(), null, null);
		Foobar__c record;
		UTIL_FrameworkMasker.MaskingResult result;

		System.runAs(getLowPrivilegeUser())
		{
			record = buildFoobarWithText(TEXT_WITH_A_SECRET);
			result = UTIL_FrameworkMasker.forRecord(record).apply();
		}

		Assert.areEqual(MASKED_TEXT_WITH_A_SECRET, record.Text__c, 'Expected the wildcard target to mask the field for a user without field access');
		Assert.areEqual(1, result.rulesMatched, 'Expected the rule to match once');
		Assert.isFalse(result.hadErrors, 'Expected masking to finish without errors');
	}

	/**
	 * @description A wildcard target masks a log event that a user without field access builds. The log engine
	 * masks every event this way before it publishes it. The user has the Minimum Access profile and no permission
	 * to create log events, so the event's fields must still be covered whoever builds it. The event is built inside
	 * `System.runAs` for the reason the record test above gives.
	 */
	@IsTest
	private static void shouldMaskLogEventThroughAWildcardTargetForAUserWithoutFieldAccess()
	{
		registerMockTargetOn(LogEntryEvent__e.SObjectType, mockSecretWordRule(), null, null);
		LogEntryEvent__e logEvent;

		System.runAs(getLowPrivilegeUser())
		{
			logEvent = (LogEntryEvent__e)TST_Builder.of(LogEntryEvent__e.SObjectType)
					.withOverride(LogEntryEvent__e.Message__c, TEXT_WITH_A_SECRET)
					.withoutInsertion()
					.build();
			UTIL_FrameworkMasker.forRecord(logEvent).apply();
		}

		Assert.areEqual(MASKED_TEXT_WITH_A_SECRET, logEvent.Message__c, 'Expected the wildcard target to mask the event message for a user without field access');
	}

	/**
	 * @description The fields a wildcard covers are the same for a user without field access as for an
	 * administrator. The list is kept for the rest of the transaction, keyed by object only, so the test builds the
	 * list for the user without access first. Built the other way round, that user would read the administrator's
	 * list from the cache, and the test could not fail. The check that the first list holds an ordinary text field is
	 * what proves the rule; the comparison then shows that both users work with that same list.
	 */
	@IsTest
	private static void shouldListTheSameWildcardFieldsForAUserWithoutFieldAccessAsForAnAdministrator()
	{
		List<SObjectField> lowPrivilegeFields;
		List<SObjectField> administratorFields;

		System.runAs(getLowPrivilegeUser())
		{
			lowPrivilegeFields = UTIL_FrameworkMasker.getTextFieldsCoveredByWildcard(Foobar__c.SObjectType);
		}

		System.runAs(getTestAdmin())
		{
			administratorFields = UTIL_FrameworkMasker.getTextFieldsCoveredByWildcard(Foobar__c.SObjectType);
		}

		Assert.isTrue(lowPrivilegeFields.contains(Foobar__c.Text__c), 'Expected the list for a user without field access to hold an ordinary text field');
		Assert.areEqual(new Set<SObjectField>(administratorFields), new Set<SObjectField>(lowPrivilegeFields), 'Expected the same list for both users');
	}

	/**
	 * @description A wildcard never covers a field that no one writes: a formula or an auto-number. The platform
	 * works out their values. On `ApiCall__c`, `TriggeringRecordUrl__c` is a text formula and `Name` is an auto-number.
	 */
	@IsTest
	private static void shouldNotExpandWildcardToFormulaOrAutoNumberFields()
	{
		System.runAs(getTestAdmin())
		{
			Set<SObjectField> apiCallFields = new Set<SObjectField>(UTIL_FrameworkMasker.getTextFieldsCoveredByWildcard(ApiCall__c.SObjectType));

			Assert.isFalse(apiCallFields.contains(ApiCall__c.TriggeringRecordUrl__c), 'Expected a formula field to stay out of the wildcard list');
			Assert.isFalse(apiCallFields.contains(ApiCall__c.Name), 'Expected an auto-number field to stay out of the wildcard list');
			Assert.isTrue(apiCallFields.contains(ApiCall__c.Request__c), 'Expected an ordinary text field to be in the wildcard list');
		}
	}

	/**
	 * @description A wildcard covers the standard text fields of a record, not only the custom ones, for a user
	 * without field access too. On `Lead`, `Company` is required, so no permission controls it, and `Description` and
	 * `Email` are ordinary standard fields.
	 */
	@IsTest
	private static void shouldExpandWildcardToStandardTextFieldsOfARecord()
	{
		List<SObjectField> leadFields;

		System.runAs(getLowPrivilegeUser())
		{
			leadFields = UTIL_FrameworkMasker.getTextFieldsCoveredByWildcard(Lead.SObjectType);
		}

		Assert.isTrue(leadFields.contains(Lead.Company), 'Expected the required standard field Company in the wildcard list');
		Assert.isTrue(leadFields.contains(Lead.Description), 'Expected the standard field Description in the wildcard list');
		Assert.isTrue(leadFields.contains(Lead.Email), 'Expected the standard field Email in the wildcard list');
	}

	/**
	 * @description Some standard text fields are in the wildcard list, but the platform lets no one write them.
	 * `Case.ContactEmail` is one: the platform copies it from the case's contact. The masker must leave such a field
	 * as it is, mask the other fields of the record, and report no error. The save cannot change that field either,
	 * so nothing new is stored without masking. The user has the Minimum Access profile, and the record is built
	 * inside `System.runAs`, so the test also proves that `Description` is masked for a user without field access.
	 */
	@IsTest
	private static void shouldLeaveAFieldNoOneCanWriteAndMaskTheOtherFields()
	{
		registerMockTargetOn(Case.SObjectType, mockEmailRule(), null, null);
		Case record;
		UTIL_FrameworkMasker.MaskingResult result;

		System.runAs(getLowPrivilegeUser())
		{
			record = buildCaseWithContactEmailAndDescription(SAMPLE_VALUE);
			result = UTIL_FrameworkMasker.forRecord(record).apply();
		}

		Assert.areEqual(EMAIL_REPLACEMENT, record.Description, 'Expected the field that can be written to be masked');
		Assert.areEqual(SAMPLE_VALUE, record.ContactEmail, 'Expected the field no one can write to keep its value');
		Assert.isFalse(result.hadErrors, 'Expected no error for a field no one can write');
	}

	/**
	 * @description The masker warns once per transaction about a field the platform refuses to write, however many
	 * records carry it, and keeps masking the other fields of every record. After the first refusal the field is
	 * skipped, so no rule runs on it again in the transaction.
	 */
	@IsTest
	private static void shouldWarnOnceAboutAFieldNoOneCanWrite()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.setupLoggerForTest();
			LOG_Engine.ignoreTestMode = true;
			registerMockTargetOn(Case.SObjectType, mockEmailRule(), null, null);
			Case firstRecord = buildCaseWithContactEmailAndDescription(SAMPLE_VALUE);
			Case secondRecord = buildCaseWithContactEmailAndDescription(SAMPLE_VALUE);

			Test.startTest();
			UTIL_FrameworkMasker.forRecords(new List<SObject> {firstRecord, secondRecord}).apply();
			Test.stopTest();

			Assert.areEqual(EMAIL_REPLACEMENT, secondRecord.Description, 'Expected the later record to be masked too');
			Assert.areEqual(SAMPLE_VALUE, secondRecord.ContactEmail, 'Expected the field no one can write to keep its value on the later record');
			assertStoredUnderFloodControl(new SEL_LogEntry().findAllByMethod(WRITE_REFUSED_WARNING_LOCATION), WRITE_REFUSED_FINGERPRINT, 1);
		}
	}

	/**
	 * @description Verifies the preview method masks a value with a single rule even when no active
	 * MaskingTarget exists for the field, which is the core of previewing an unused rule. An unused
	 * Regex phone rule (no target configured) redacts a phone-shaped value, proving the active-target
	 * cache is not used.
	 */
	@IsTest
	private static void maskValueAgainstRuleRedactsDormantRegexRuleWithNoActiveTarget()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('PreviewPhone', SEL_MaskingRule.MODE_REGEX, '\\d{3}-\\d{3}-\\d{4}', '[PHONE_REDACTED]', 10)
					.withOverride(MaskingRule__mdt.IsActive__c, false)
					.withoutInsertion(true)
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.maskValueAgainstRule(Foobar__c.Text__c, rule, '415-555-1234');

			Assert.areEqual('[PHONE_REDACTED]', result.maskedValue, 'a dormant Regex rule redacts the value with no active target configured');
			Assert.areEqual(1, result.rulesMatched, 'the single preview rule matched once');
		}
	}

	/**
	 * @description Verifies the preview method applies a JsonKey rule to a JSON payload, redacting the
	 * value of the matched key while leaving the rest of the document intact.
	 */
	@IsTest
	private static void maskValueAgainstRuleMasksJsonKeyRuleOnJsonPayload()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('PreviewJsonKey', SEL_MaskingRule.MODE_JSON_KEY, 'password', '[REDACTED]', 10)
					.withOverride(MaskingRule__mdt.IsActive__c, false)
					.withoutInsertion(true)
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.maskValueAgainstRule(Foobar__c.TextArea__c, rule, '{"password":"secret","name":"bob"}');

			Assert.areEqual(1, result.rulesMatched, 'the JsonKey rule matched the password key');
			Assert.isTrue(result.maskedValue.contains('[REDACTED]'), 'the matched key value is redacted');
			Assert.isFalse(result.maskedValue.contains('secret'), 'the original secret value is gone');
		}
	}

	/**
	 * @description Verifies the preview method leaves a plain value that is not JSON unchanged when
	 * handed a JsonKey rule. That is correct, not a failure. The console must not read this as a broken
	 * rule, so the method records zero matches and does not change the value.
	 */
	@IsTest
	private static void maskValueAgainstRuleNoOpsJsonKeyRuleOnNonJsonScalar()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('PreviewJsonKey', SEL_MaskingRule.MODE_JSON_KEY, 'password', '[REDACTED]', 10)
					.withOverride(MaskingRule__mdt.IsActive__c, false)
					.withoutInsertion(true)
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.maskValueAgainstRule(Foobar__c.Text__c, rule, 'just a plain string');

			Assert.areEqual('just a plain string', result.maskedValue, 'a JsonKey rule leaves a non-JSON scalar unchanged');
			Assert.areEqual(0, result.rulesMatched, 'no JsonKey match is recorded for a non-JSON scalar');
		}
	}

	/**
	 * @description Verifies the preview method returns the value unchanged when handed a blank value,
	 * stopping before any rule runs.
	 */
	@IsTest
	private static void maskValueAgainstRuleReturnsUnmaskedForBlankValue()
	{
		System.runAs(getTestAdmin())
		{
			MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder('PreviewPhone', SEL_MaskingRule.MODE_REGEX, '\\d{3}-\\d{3}-\\d{4}', '[PHONE_REDACTED]', 10)
					.withoutInsertion(true)
					.build();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.maskValueAgainstRule(Foobar__c.Text__c, rule, '');

			Assert.areEqual('', result.maskedValue, 'an empty value is returned unchanged');
			Assert.areEqual(0, result.rulesMatched, 'no rule fires on an empty value');
		}
	}

	/**
	 * @description Runs the shipped `MaskAddress` rule exactly as it deploys (a Regex rule that
	 * matches anything and replaces the whole value with a fixed token), proving the new unused rule
	 * masks a postal address through the framework masker, without the advisor pages.
	 */
	@IsTest
	private static void shippedMaskAddressRuleRedactsAddressValue()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.MaskingResult result =
					UTIL_FrameworkMasker.maskValueAgainstRule(Foobar__c.Text__c, shippedRule(SEL_MaskingRule.RULE_MASK_ADDRESS), '742 Evergreen Terrace, Springfield');

			Assert.areEqual('[ADDRESS_REDACTED]', result.maskedValue, 'the shipped MaskAddress rule replaces the whole address with its token');
			Assert.areEqual(1, result.rulesMatched, 'the MaskAddress rule matched once');
		}
	}

	/**
	 * @description Runs the shipped `MaskFreeText` rule, proving the unused rule that matches anything
	 * masks a free-text value to its fixed token through the framework masker.
	 */
	@IsTest
	private static void shippedMaskFreeTextRuleRedactsTextValue()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.MaskingResult result =
					UTIL_FrameworkMasker.maskValueAgainstRule
							(
									Foobar__c.TextArea__c,
									shippedRule(SEL_MaskingRule.RULE_MASK_FREE_TEXT),
									'Private note: customer prefers email contact only.'
							);

			Assert.areEqual('[TEXT_REDACTED]', result.maskedValue, 'the shipped MaskFreeText rule replaces the whole free-text value with its token');
			Assert.areEqual(1, result.rulesMatched, 'the MaskFreeText rule matched once');
		}
	}

	/**
	 * @description Runs the shipped `MaskPhoneInternational` rule, proving the unused rule that matches
	 * anything masks an international-format phone value (with a leading country code) to its fixed token.
	 */
	@IsTest
	private static void shippedMaskPhoneInternationalRuleRedactsValue()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_FrameworkMasker.MaskingResult result =
					UTIL_FrameworkMasker.maskValueAgainstRule(Foobar__c.Text__c, shippedRule(SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL), '+44 20 7946 0958');

			Assert.areEqual('[PHONE_REDACTED]', result.maskedValue, 'the shipped MaskPhoneInternational rule replaces the whole phone number with its token');
			Assert.areEqual(1, result.rulesMatched, 'the MaskPhoneInternational rule matched once');
		}
	}

	/**
	 * @description Returns the shipped `MaskingRule__mdt` record with the given developer name, read
	 * through the framework's `SEL_MaskingTarget` selector (not a raw `getAll()`), so a round-trip test
	 * exercises the rule exactly as it ships (pattern, replacement, mode) through the same selector production
	 * uses, rather than a hand-built mock. Fails the test with a clear message when the rule is not
	 * deployed, so an un-deployed or renamed record surfaces as "rule not deployed" rather than an opaque
	 * downstream token-mismatch assertion.
	 *
	 * @param developerName The rule developer name to find (for example `MaskAddress`).
	 *
	 * @return The deployed rule (never `null`: a missing rule fails the test).
	 */
	private static MaskingRule__mdt shippedRule(String developerName)
	{
		MaskingRule__mdt found = null;
		for(MaskingRule__mdt rule : new SEL_MaskingTarget().getAllRulesById().values())
		{
			if(rule.DeveloperName == developerName)
			{
				found = rule;
				break;
			}
		}
		Assert.isNotNull(found, 'the shipped rule ' + developerName + ' must be deployed to the org for the round-trip test to run');
		return found;
	}

	/**
	 * @description Makes the shipped rule that hides payment card numbers the only rule for `ApiCall__c.Request__c`. The
	 * rule is the deployed record; only the target that links it to the field is a test record.
	 *
	 * @return The shipped card rule
	 */
	private static MaskingRule__mdt registerShippedCardRuleOnApiCallRequest()
	{
		MaskingRule__mdt cardRule = shippedRule(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD);
		registerMockTargetOn(ApiCall__c.SObjectType, cardRule, UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.Request__c), null);
		return cardRule;
	}

	/**
	 * @description Masks one value of `ApiCall__c.Request__c` and checks that the card rule finished without an error and
	 * put its replacement in the expected number of places.
	 *
	 * @param shapeName A short name of the text, used in the failure messages
	 * @param value The text to mask
	 * @param expectedReplacements How many replacements the masked text must hold
	 * @param cardRule The shipped card rule, whose replacement is counted
	 *
	 * @return The masked text, for checks that only some shapes need
	 */
	private static String assertCardRuleHides(String shapeName, String value, Integer expectedReplacements, MaskingRule__mdt cardRule)
	{
		UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask(value);

		Assert.isFalse(result.hadErrors, 'Expected the card rule to finish without an error on ' + shapeName);
		Assert.areEqual(expectedReplacements, result.maskedValue.countMatches(cardRule.Replacement__c), 'Expected the number of hidden numbers on ' + shapeName);
		return result.maskedValue;
	}

	/**
	 * @description Builds a text made only of the digit 1. It has no space or hyphen, so the card pattern finds nothing in
	 * it.
	 *
	 * @param length The length of the text
	 *
	 * @return The digit text
	 */
	private static String buildDigitWall(Integer length)
	{
		return DIGIT_ONE.repeat(length);
	}

	/**
	 * @description Builds a text of the digit 1 and a space, repeated. The card pattern finds a 19-digit number in every
	 * 37 characters, and none of them passes the Luhn check.
	 *
	 * @param length The length of the text
	 *
	 * @return The digit text
	 */
	private static String buildSpacedDigitWall(Integer length)
	{
		return (DIGIT_ONE + UTIL_String.SPACE).repeat(length / 2);
	}

	/**
	 * @description Builds a text of the digit 1 and a hyphen, repeated. It is the spaced digit text with hyphens.
	 *
	 * @param length The length of the text
	 *
	 * @return The digit text
	 */
	private static String buildHyphenatedDigitWall(Integer length)
	{
		return (DIGIT_ONE + HYPHEN).repeat(length / 2);
	}

	/**
	 * @description Builds the text of `buildDigitWall` with a real card number in the middle.
	 *
	 * @param length The length of the text
	 *
	 * @return The digit text with the card number
	 */
	private static String buildDigitWallWithCard(Integer length)
	{
		return placeCardInTheMiddle(buildDigitWall(length), UTIL_String.SPACE, length);
	}

	/**
	 * @description Builds the text of `buildSpacedDigitWall` with a real card number in the middle.
	 *
	 * @param length The length of the text
	 *
	 * @return The digit text with the card number
	 */
	private static String buildSpacedDigitWallWithCard(Integer length)
	{
		return placeCardInTheMiddle(buildSpacedDigitWall(length), UTIL_String.SPACE, length);
	}

	/**
	 * @description Builds the text of `buildHyphenatedDigitWall` with a real card number in the middle.
	 *
	 * @param length The length of the text
	 *
	 * @return The digit text with the card number
	 */
	private static String buildHyphenatedDigitWallWithCard(Integer length)
	{
		return placeCardInTheMiddle(buildHyphenatedDigitWall(length), HYPHEN, length);
	}

	/**
	 * @description Builds a text of 19-digit numbers that pass the Luhn check, one space apart, cut to the length.
	 *
	 * @param length The length of the text
	 *
	 * @return The text of numbers
	 */
	private static String buildNineteenDigitGroups(Integer length)
	{
		return NINETEEN_DIGIT_GROUP.repeat(length / NINETEEN_DIGIT_GROUP.length() + 1).left(length);
	}

	/**
	 * @description Builds a text of different 16-digit card numbers that all pass the Luhn check, one space apart, with
	 * spaces at the end to reach the length. A text of this length holds `(length + 1) / 17` numbers.
	 *
	 * @param length The length of the text
	 *
	 * @return The text of card numbers
	 */
	private static String buildCardDump(Integer length)
	{
		final Integer cardWithSeparatorLength = 17;
		List<String> cards = new List<String>();
		Long body = FIRST_CARD_BODY;

		for(Integer count = 0; count < (length + 1) / cardWithSeparatorLength; count++)
		{
			cards.add(buildLuhnValidCard(body));
			body += CARD_BODY_STEP;
		}

		String joined = String.join(cards, UTIL_String.SPACE);
		return joined + UTIL_String.SPACE.repeat(length - joined.length());
	}

	/**
	 * @description Puts `VISA_TEST_CARD`, with two separators on each side, in the middle of a text. The card number starts
	 * at an even place, so in a text of a digit and a separator repeated it follows a separator.
	 *
	 * @param base The text to put the card number in
	 * @param separator The separator to put on each side of the card number
	 * @param length The length of the result
	 *
	 * @return The text with the card number in the middle
	 */
	private static String placeCardInTheMiddle(String base, String separator, Integer length)
	{
		String inserted = separator + separator + VISA_TEST_CARD + separator + separator;
		Integer half = (length - inserted.length()) / 2;
		half += Math.mod(half, 2);
		return base.left(half) + inserted + base.substring(0, length - half - inserted.length());
	}

	/**
	 * @description Builds a 16-digit card number that starts with 4, holds the given body and ends with the check digit
	 * that makes it pass the Luhn check.
	 *
	 * @param body The 14 digits between the first digit and the check digit, padded with zeros on the left
	 *
	 * @return The card number
	 */
	private static String buildLuhnValidCard(Long body)
	{
		String digits = VISA_FIRST_DIGIT + String.valueOf(body).leftPad(CARD_BODY_DIGITS, DIGIT_ZERO);
		List<Integer> characterCodes = digits.getChars();
		Integer sum = 0;

		for(Integer index = characterCodes.size() - 1; index >= 0; index--)
		{
			Integer digit = characterCodes[index] - ZERO_CHARACTER_CODE;

			if(Math.mod(characterCodes.size() - index, 2) == 1)
			{
				digit = digit * 2 > 9 ? digit * 2 - 9 : digit * 2;
			}

			sum += digit;
		}

		return digits + String.valueOf(Math.mod(10 - Math.mod(sum, 10), 10));
	}

	/**
	 * @description Makes the shipped secret-keys rule the only rule for `ApiCall__c.Request__c`. The rule is the deployed
	 * record; only the target that links it to the field is a test record.
	 *
	 * @return The shipped secret-keys rule
	 */
	private static MaskingRule__mdt registerShippedSecretKeysRuleOnApiCallRequest()
	{
		MaskingRule__mdt secretRule = shippedRule(SEL_MaskingRule.RULE_MASK_SECRET_KEYS);
		registerMockTargetOn(ApiCall__c.SObjectType, secretRule, UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.Request__c), null);
		return secretRule;
	}

	/**
	 * @description Registers a test JsonKey rule and its target on `ApiCall__c.Request__c`, a field long enough for the
	 * values that are read one token at a time.
	 *
	 * @param developerName The rule DeveloperName
	 * @param keyPattern The key pattern of the rule
	 * @param replacement The text the rule writes in place of a matched value
	 * @param ruleOrder The rule Order__c, which sets when the rule runs
	 * @param failureAction The rule FailureAction__c; null leaves it unset
	 */
	private static void registerMockJsonKeyRuleOnApiCallRequest(String developerName, String keyPattern, String replacement, Integer ruleOrder, String failureAction)
	{
		MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder(developerName, SEL_MaskingRule.MODE_JSON_KEY, keyPattern, replacement, ruleOrder)
				.withOverride(MaskingRule__mdt.FailureAction__c, failureAction)
				.withoutInsertion(true)
				.build();
		registerMockTargetOn(ApiCall__c.SObjectType, rule, UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.Request__c), null);
	}

	/**
	 * @description Registers a test JsonKey rule with no pattern on `ApiCall__c.Request__c`. The rule cares about case,
	 * so the missing pattern cannot compile and the rule fails when it runs.
	 */
	private static void registerBlankPatternJsonKeyRuleOnApiCallRequest()
	{
		MaskingRule__mdt rule = (MaskingRule__mdt)mockRuleBuilder(TEST_RULE_NAME, SEL_MaskingRule.MODE_JSON_KEY, null, UNUSED_REPLACEMENT, 10)
				.withOverride(MaskingRule__mdt.CaseSensitive__c, true)
				.withoutInsertion(true)
				.build();
		Assert.isNull(rule.Pattern__c, 'Expected the test rule to have no pattern');
		registerMockTargetOn(ApiCall__c.SObjectType, rule, UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.Request__c), null);
	}

	/**
	 * @description Masks two deep nests on `ApiCall__c.Request__c` and checks the results: the nest with a token at the
	 * bottom has the token replaced, and the nest without a key is stored unchanged.
	 *
	 * @param levels How deep the nests are
	 * @param length The length to pad the nest without a key to; 0 leaves it unpadded
	 * @param secretRule The shipped secret-keys rule, whose replacement is expected
	 */
	private static void assertDeepNestsAreMasked(Integer levels, Integer length, MaskingRule__mdt secretRule)
	{
		UTIL_FrameworkMasker.FieldMasker masker = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c);
		String expected = NEST_LEVEL_OPENING.repeat(levels) + '{"token":"' + secretRule.Replacement__c + '"}' + NEST_LEVEL_CLOSING.repeat(levels);
		String nestWithoutKey = buildDeepNest(levels, length);

		UTIL_FrameworkMasker.MaskingResult tokenResult = masker.mask(buildDeepNestWithToken(levels));
		UTIL_FrameworkMasker.MaskingResult plainResult = masker.mask(nestWithoutKey);

		Assert.isFalse(tokenResult.hadErrors, 'Expected the deep nest with a token to be masked without an error');
		Assert.areEqual(expected, tokenResult.maskedValue, 'Expected the token at the bottom of the nest to be replaced');
		Assert.areEqual(1, tokenResult.valuesRedacted, 'Expected one value to be replaced');
		Assert.areEqual(nestWithoutKey, plainResult.maskedValue, 'Expected the nest without a key to be stored unchanged');
	}

	/**
	 * @description Masks a JSON value with the shipped secret-keys rule on `ApiCall__c.Request__c` after putting it behind
	 * more opening brackets than the line (see `buildAboveTheStructureLine`), so it is read one token at a time. Checks
	 * the result as a value: both texts are read as JSON and compared.
	 *
	 * @param jsonValue The JSON value to mask
	 * @param expectedJson The JSON value expected after masking
	 * @param expectedReplacements How many values the rule must replace
	 */
	private static void assertSecretKeysRuleMasksAboveTheLine(String jsonValue, String expectedJson, Integer expectedReplacements)
	{
		UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).mask(buildAboveTheStructureLine(jsonValue));

		Assert.isFalse(result.hadErrors, 'Expected the secret-keys rule to finish without an error');
		Assert.areEqual(JSON.deserializeUntyped(buildAboveTheStructureLine(expectedJson)), JSON.deserializeUntyped(result.maskedValue), 'Expected the secret value replaced');
		Assert.areEqual(expectedReplacements, result.valuesRedacted, 'Expected the number of replaced values');
	}

	/**
	 * @description Puts a JSON value at the end of a list that starts with `EMPTY_OBJECTS_ABOVE_THE_STRUCTURE_LINE` empty
	 * objects. The list holds more opening brackets than the line, so the masking reads it one token at a time.
	 *
	 * @param jsonValue The JSON value to put in the list
	 *
	 * @return The list as JSON text
	 */
	private static String buildAboveTheStructureLine(String jsonValue)
	{
		return '[' + EMPTY_OBJECT_IN_A_LIST.repeat(EMPTY_OBJECTS_ABOVE_THE_STRUCTURE_LINE) + jsonValue + ']';
	}

	/**
	 * @description Builds a JSON list of `FULL_OBJECTS_IN_THE_TOKEN_LIST` objects with a token key, then one last object
	 * whose token value is padded so the text has the given length.
	 *
	 * @param length The length of the text
	 *
	 * @return The token list as JSON text
	 */
	private static String buildTokenArray(Integer length)
	{
		String head = '[' + TOKEN_OBJECT_IN_A_LIST.repeat(FULL_OBJECTS_IN_THE_TOKEN_LIST) + '{"token":"';
		String tail = '"}]';
		return head + 'x'.repeat(length - head.length() - tail.length()) + tail;
	}

	/**
	 * @description Builds the token list of `buildTokenArray` cut at `TOKEN_LIST_CUT_LENGTH` characters, inside the value
	 * of its last token. The text is not JSON: it ends in an open string.
	 *
	 * @param length The length of the token list before the cut
	 *
	 * @return The cut token list
	 */
	private static String buildTokenArrayCut(Integer length)
	{
		return buildTokenArray(length).left(TOKEN_LIST_CUT_LENGTH);
	}

	/**
	 * @description Builds one JSON object with thousands of short keys (`k0`, `k1`, and so on) and a last key whose
	 * value is padded so the text has the given length. No key is a secret key name, and no secret key name appears
	 * anywhere in the text.
	 *
	 * @param length The length of the text
	 *
	 * @return The object as JSON text
	 */
	private static String buildManyKeys(Integer length)
	{
		final Integer roomForTheLastKey = 400;
		List<String> entries = new List<String>();
		Integer used = 2;

		for(Integer index = 0; used < length - roomForTheLastKey; index++)
		{
			String entry = '"k' + index + '":"v"';
			entries.add(entry);
			used += entry.length() + 1;
		}

		String head = '{' + String.join(entries, UTIL_String.COMMA) + ',"pad":"';
		String tail = '"}';
		return head + 'v'.repeat(length - head.length() - tail.length()) + tail;
	}

	/**
	 * @description Builds a JSON value nested the given number of levels deep, with one text at the bottom. The text is
	 * padded so the value has the given length, and holds at least one character.
	 *
	 * @param levels How deep the value is nested
	 * @param length The length of the text; 0 gives the shortest nest
	 *
	 * @return The deep nest as JSON text
	 */
	private static String buildDeepNest(Integer levels, Integer length)
	{
		Integer padding = Math.max(1, length - levels * (NEST_LEVEL_OPENING.length() + NEST_LEVEL_CLOSING.length()) - 2);
		String bottom = UTIL_String.DOUBLE_QUOTE + 'v'.repeat(padding) + UTIL_String.DOUBLE_QUOTE;
		return NEST_LEVEL_OPENING.repeat(levels) + bottom + NEST_LEVEL_CLOSING.repeat(levels);
	}

	/**
	 * @description Builds a JSON value nested the given number of levels deep, with `DEEP_TOKEN_OBJECT`, an object
	 * holding a token key, at the bottom.
	 *
	 * @param levels How deep the token object is nested
	 *
	 * @return The deep nest as JSON text
	 */
	private static String buildDeepNestWithToken(Integer levels)
	{
		return NEST_LEVEL_OPENING.repeat(levels) + DEEP_TOKEN_OBJECT + NEST_LEVEL_CLOSING.repeat(levels);
	}

	/**
	 * @description Asserts that a warning was stored under flood control: one detail row and one counter row for
	 * today, both keyed from the given fingerprint, nothing else at that location, and the counter holding the number
	 * of times the warning was written.
	 *
	 * @param warnings The rows found at the warning's location
	 * @param fingerprint The flood-control key the warning is expected to carry
	 * @param occurrences How many times the warning is expected to have been written
	 */
	private static void assertStoredUnderFloodControl(List<LogEntry__c> warnings, String fingerprint, Decimal occurrences)
	{
		String counterKeyStart = TRG_PersistLogEntry.PREFIX_ROLLUP + fingerprint + UTIL_String.COLON;
		Set<String> storedKeys = new Set<String>();
		Decimal counted;
		for(LogEntry__c warning : warnings)
		{
			storedKeys.add(warning.Fingerprint__c);
			if(warning.Fingerprint__c?.startsWith(counterKeyStart) == true)
			{
				counted = warning.OccurrenceCount__c;
			}
		}
		Assert.areEqual(2, warnings.size(), 'Expected the warning stored as one detail row and one counter row, found keys ' + storedKeys);
		Assert.isTrue(storedKeys.contains(TRG_PersistLogEntry.buildDetailKey(fingerprint)), 'Expected a detail row under the key ' + fingerprint + ', found keys ' + storedKeys);
		Assert.areEqual(occurrences, counted, 'Expected the counter row to hold the number of times the warning was written, found keys ' + storedKeys);
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup for use with
	 * System.runAs, so each test body runs with a fresh permission-evaluation context.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the low-privilege test to run UTIL_FrameworkMasker and prove that
	 * masking still works for subscriber users who have no FLS on the framework's own objects.
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}

	/**
	 * @description Tests that an untuned predecessor's target is dropped on a surface its untuned
	 * active successor mirrors: the predecessor token survives untouched (its rule never ran), the
	 * successor token is masked, and the result reports the successor as the only matched rule.
	 */
	@IsTest
	private static void shouldSuppressUntunedPredecessorTargetOnMirroredSurface()
	{
		System.runAs(getTestAdmin())
		{
			mockSupersessionPair(false, false, true);
			Foobar__c record = buildSupersessionRecord();

			UTIL_FrameworkMasker.MaskingResult result = UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual
					(
							PREDECESSOR_TOKEN + ' ' + SUCCESSOR_REPLACEMENT,
							record.Name,
							'The successor must mask its surface while the suppressed predecessor leaves its token untouched'
					);
			Assert.isTrue(result.matchedRuleDeveloperNames.contains(SUCCESSOR_RULE_NAME), 'The successor rule must run on the mirrored surface');
			Assert.isFalse(result.matchedRuleDeveloperNames.contains(PREDECESSOR_RULE_NAME), 'The suppressed predecessor rule must never run on the mirrored surface');
		}
	}

	/**
	 * @description Tests that a predecessor target keeps masking a field the successor does not also
	 * cover (the shape of a subscriber's custom object). The rule-level supersession check does pass,
	 * so only the missing successor target keeps the predecessor target running, and the test cannot
	 * pass for the wrong reason.
	 */
	@IsTest
	private static void shouldNotSuppressWhenSuccessorTargetMissingOnSurface()
	{
		System.runAs(getTestAdmin())
		{
			mockSupersessionPair(false, false, false);
			Foobar__c record = buildSupersessionRecord();

			Assert.isTrue(SEL_MaskingRule.findSupersededRuleNames(new SEL_MaskingTarget().getAllRulesById().values()).contains(PREDECESSOR_RULE_NAME),
					'Control check: the rule-level supersession must pass, so only the missing successor target keeps the predecessor running');

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(PREDECESSOR_REPLACEMENT + ' ' + SUCCESSOR_TOKEN, record.Name, 'The predecessor must keep masking surfaces the successor does not cover');
		}
	}

	/**
	 * @description Tests that a tuned predecessor (its current fingerprint no longer matches the
	 * successor's ReplacesFingerprint__c) is never dropped: both rules run and the tuned replacement
	 * is written, proving the subscriber's change stayed in force.
	 */
	@IsTest
	private static void shouldNotSuppressTunedPredecessor()
	{
		System.runAs(getTestAdmin())
		{
			mockSupersessionPair(true, false, true);
			Foobar__c record = buildSupersessionRecord();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(TUNED_REPLACEMENT + ' ' + SUCCESSOR_REPLACEMENT, record.Name, 'A tuned predecessor must keep running alongside the successor');
		}
	}

	/**
	 * @description Tests that a tuned successor (its current fingerprint no longer matches its own
	 * ShippedFingerprint__c) drops nothing: the predecessor keeps masking. The successor's change here
	 * (MinInputLength above the input length) also leaves its own token alone. This is the gap in
	 * coverage that made supersession check both the predecessor and the successor.
	 */
	@IsTest
	private static void shouldNotSuppressWhenSuccessorTuned()
	{
		System.runAs(getTestAdmin())
		{
			mockSupersessionPair(false, true, true);
			Foobar__c record = buildSupersessionRecord();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual
					(
							PREDECESSOR_REPLACEMENT + ' ' + SUCCESSOR_TOKEN,
							record.Name,
							'A tuned successor must not replace its predecessor: the predecessor still masks the field'
					);
		}
	}

	/**
	 * @description Tests that suppression requires an exact field|caller surface match: a
	 * wildcard predecessor target and a successor target bound to one specific field carry
	 * different composite keys, so both rules run.
	 */
	@IsTest
	private static void shouldNotSuppressAcrossDifferentSurfaceKeys()
	{
		System.runAs(getTestAdmin())
		{
			List<MaskingRule__mdt> pair = buildSupersessionRulePair(false, false);
			registerMockTarget(pair[0], null, null);
			registerMockTarget(pair[1], UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name), null);
			Foobar__c record = buildSupersessionRecord();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(PREDECESSOR_REPLACEMENT + ' ' + SUCCESSOR_REPLACEMENT, record.Name,
					'A wildcard predecessor target and a field-specific successor target have different field keys: neither may be dropped');
		}
	}

	/**
	 * @description Tests that supersession pairs that exist side by side stay independent: pair one's
	 * successor covers the field and pair two's successor has no target there. Pair one's predecessor
	 * is dropped, while pair two's predecessor keeps masking. Pair one's coverage must never count
	 * for pair two.
	 */
	@IsTest
	private static void shouldSuppressEachSupersessionLinkIndependently()
	{
		System.runAs(getTestAdmin())
		{
			List<MaskingRule__mdt> firstPair = buildSupersessionRulePairNamed(PREDECESSOR_RULE_NAME, PREDECESSOR_TOKEN, PREDECESSOR_REPLACEMENT,
					SUCCESSOR_RULE_NAME, SUCCESSOR_TOKEN, SUCCESSOR_REPLACEMENT);
			List<MaskingRule__mdt> secondPair = buildSupersessionRulePairNamed('OldTextRule', 'PRED2-TOKEN', '[P2]', 'NewTextRule', 'SUCC2-TOKEN', '[S2]');
			overrideAllRules(new List<MaskingRule__mdt> {firstPair[0], firstPair[1], secondPair[0], secondPair[1]});
			registerMockTarget(firstPair[0], null, null);
			registerMockTarget(firstPair[1], null, null);
			registerMockTarget(secondPair[0], null, null);
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, PREDECESSOR_TOKEN + ' ' + SUCCESSOR_TOKEN + ' PRED2-TOKEN')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(PREDECESSOR_TOKEN + ' ' + SUCCESSOR_REPLACEMENT + ' [P2]', record.Name,
					'Dropping pair one\'s predecessor must not drop pair two\'s predecessor: its own successor has no target on this field');
		}
	}

	/**
	 * @description Tests that a TUNED successor cannot use another successor's result for the same
	 * predecessor. The real successor covers only one named field, so the predecessor keeps its
	 * wildcard target even though the tuned successor's wildcard target is on the same field. The
	 * targets of a tuned successor must never decide which predecessor targets are dropped.
	 */
	@IsTest
	private static void shouldNotLetTunedSiblingSuccessorPiggybackOnAnotherLinksVerdict()
	{
		System.runAs(getTestAdmin())
		{
			List<MaskingRule__mdt> pair = buildSupersessionRulePairNamed(PREDECESSOR_RULE_NAME, PREDECESSOR_TOKEN, PREDECESSOR_REPLACEMENT,
					SUCCESSOR_RULE_NAME, SUCCESSOR_TOKEN, SUCCESSOR_REPLACEMENT);
			MaskingRule__mdt tunedSibling = (MaskingRule__mdt)mockRuleBuilder('TunedSiblingRule', SEL_MaskingRule.MODE_EXACT_MATCH, 'SIBLING-TOKEN', '[T]', 200)
					.withOverride(MaskingRule__mdt.Replaces__c, PREDECESSOR_RULE_NAME)
					.withoutInsertion(true)
					.build();
			tunedSibling.ReplacesFingerprint__c = SEL_MaskingRule.computeFingerprint(pair[0]);
			tunedSibling.ShippedFingerprint__c = SEL_MaskingRule.computeFingerprint(tunedSibling);
			tunedSibling.MinInputLength__c = 99;
			overrideAllRules(new List<MaskingRule__mdt> {pair[0], pair[1], tunedSibling});
			registerMockTarget(pair[0], null, null);
			registerMockTarget(pair[1], UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name), null);
			registerMockTarget(tunedSibling, null, null);
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, PREDECESSOR_TOKEN + ' ' + SUCCESSOR_TOKEN + ' SIBLING-TOKEN')
					.withoutInsertion()
					.build();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(PREDECESSOR_REPLACEMENT + ' ' + SUCCESSOR_REPLACEMENT + ' SIBLING-TOKEN', record.Name,
					'A tuned successor must not use another successor\'s result: the predecessor keeps the fields its real successor does not cover');
		}
	}

	/**
	 * @description Tests that the caller dimension participates in surface matching: a
	 * caller-scoped predecessor target and an unscoped successor target bind different surfaces,
	 * so both rules run for that caller.
	 */
	@IsTest
	private static void shouldNotSuppressCallerScopedPredecessorSurface()
	{
		System.runAs(getTestAdmin())
		{
			List<MaskingRule__mdt> pair = buildSupersessionRulePairNamed(PREDECESSOR_RULE_NAME, PREDECESSOR_TOKEN, PREDECESSOR_REPLACEMENT,
					SUCCESSOR_RULE_NAME, SUCCESSOR_TOKEN, SUCCESSOR_REPLACEMENT);
			overrideAllRules(pair);
			registerMockTarget(pair[0], null, SAMPLE_CALLER);
			registerMockTarget(pair[1], null, null);
			Foobar__c record = buildSupersessionRecord();

			UTIL_FrameworkMasker.forRecord(record).calledFrom(SAMPLE_CALLER).apply();

			Assert.areEqual(PREDECESSOR_REPLACEMENT + ' ' + SUCCESSOR_REPLACEMENT, record.Name,
					'A predecessor target limited to one caller does not match the successor target for every caller: nothing is dropped, both rules run');
		}
	}

	/**
	 * @description Tests that an org-local copy that shares the packaged predecessor's DeveloperName
	 * AND its values keeps masking when the packaged predecessor is dropped. A rule is identified by
	 * its namespace-qualified name everywhere (removing duplicates, checking supersession, dropping
	 * targets), so the packaged rule's result can never drop the copy's target. The namespaces are
	 * worked out at run time, so the test holds in an unmanaged org, in a managed package, and when
	 * rebuilt under any namespace.
	 */
	@IsTest
	private static void shouldNotSuppressIdenticalCloneFromAnotherNamespace()
	{
		System.runAs(getTestAdmin())
		{
			String runningNamespace = UTIL_System.getManagedPackageNamespace();
			String foreignNamespace = (runningNamespace ?? UTIL_String.EMPTY) + 'subscriber';
			MaskingRule__mdt predecessor = (MaskingRule__mdt)mockRuleBuilder(PREDECESSOR_RULE_NAME, SEL_MaskingRule.MODE_EXACT_MATCH, PREDECESSOR_TOKEN,
					PREDECESSOR_REPLACEMENT, 200)
					.withOverride(MaskingRule__mdt.NamespacePrefix, runningNamespace)
					.withoutInsertion(true)
					.build();
			MaskingRule__mdt successor = (MaskingRule__mdt)mockRuleBuilder(SUCCESSOR_RULE_NAME, SEL_MaskingRule.MODE_EXACT_MATCH, SUCCESSOR_TOKEN, SUCCESSOR_REPLACEMENT, 200)
					.withOverride(MaskingRule__mdt.Replaces__c, PREDECESSOR_RULE_NAME)
					.withOverride(MaskingRule__mdt.NamespacePrefix, runningNamespace)
					.withoutInsertion(true)
					.build();
			successor.ReplacesFingerprint__c = SEL_MaskingRule.computeFingerprint(predecessor);
			successor.ShippedFingerprint__c = SEL_MaskingRule.computeFingerprint(successor);
			MaskingRule__mdt clone = (MaskingRule__mdt)mockRuleBuilder(PREDECESSOR_RULE_NAME, SEL_MaskingRule.MODE_EXACT_MATCH, PREDECESSOR_TOKEN, PREDECESSOR_REPLACEMENT, 200)
					.withOverride(MaskingRule__mdt.NamespacePrefix, foreignNamespace)
					.withoutInsertion(true)
					.build();
			overrideAllRules(new List<MaskingRule__mdt> {predecessor, successor, clone});
			registerMockTarget(predecessor, null, null);
			registerMockTarget(successor, null, null);
			registerMockTarget(clone, null, null);
			Foobar__c record = buildSupersessionRecord();

			UTIL_FrameworkMasker.forRecord(record).apply();

			Assert.areEqual(PREDECESSOR_REPLACEMENT + ' ' + SUCCESSOR_REPLACEMENT, record.Name,
					'The packaged predecessor is suppressed, but the identically-configured clone from another namespace must keep masking');
		}
	}

	/**
	 * @description Builds the standard supersession rule pair (a predecessor, and a successor naming
	 * it in Replaces__c, with both fingerprints set exactly as the shipped metadata would carry them).
	 * Applies the requested tuning AFTER the fingerprints are taken, and sets the selector's list of
	 * all rules, so supersession sees the successor rule even when no target refers to it.
	 *
	 * @param predecessorTuned Tune the predecessor's Replacement__c (fingerprint drifts; rule still matches its token)
	 * @param successorTuned Tune the successor's MinInputLength__c (fingerprint drifts; rule stops matching the short input)
	 *
	 * @return The pair: index 0 is the predecessor, index 1 the successor
	 */
	private static List<MaskingRule__mdt> buildSupersessionRulePair(Boolean predecessorTuned, Boolean successorTuned)
	{
		List<MaskingRule__mdt> pair = buildSupersessionRulePairNamed(PREDECESSOR_RULE_NAME, PREDECESSOR_TOKEN, PREDECESSOR_REPLACEMENT,
				SUCCESSOR_RULE_NAME, SUCCESSOR_TOKEN, SUCCESSOR_REPLACEMENT);

		if(predecessorTuned)
		{
			pair[0].Replacement__c = TUNED_REPLACEMENT;
		}

		if(successorTuned)
		{
			pair[1].MinInputLength__c = 99;
		}

		overrideAllRules(pair);

		return pair;
	}

	/**
	 * @description Builds a supersession rule pair with explicit names, tokens, and replacements,
	 * so a test can hold several separate pairs. Both fingerprints are taken exactly as the shipped
	 * metadata would carry them. Does NOT set the selector's list of all rules: callers that build
	 * several pairs set it once with overrideAllRules.
	 *
	 * @param predecessorName The predecessor rule DeveloperName
	 * @param predecessorToken The token only the predecessor matches
	 * @param predecessorReplacement The replacement the predecessor writes
	 * @param successorName The successor rule DeveloperName
	 * @param successorToken The token only the successor matches
	 * @param successorReplacement The replacement the successor writes
	 *
	 * @return The pair: index 0 is the predecessor, index 1 the successor
	 */
	private static List<MaskingRule__mdt> buildSupersessionRulePairNamed
			(
					String predecessorName,
					String predecessorToken,
					String predecessorReplacement,
					String successorName,
					String successorToken,
					String successorReplacement
			)
	{
		MaskingRule__mdt predecessor = (MaskingRule__mdt)mockRuleBuilder(predecessorName, SEL_MaskingRule.MODE_EXACT_MATCH, predecessorToken, predecessorReplacement, 200)
				.withoutInsertion(true)
				.build();
		MaskingRule__mdt successor = (MaskingRule__mdt)mockRuleBuilder(successorName, SEL_MaskingRule.MODE_EXACT_MATCH, successorToken, successorReplacement, 200)
				.withOverride(MaskingRule__mdt.Replaces__c, predecessorName)
				.withoutInsertion(true)
				.build();
		successor.ReplacesFingerprint__c = SEL_MaskingRule.computeFingerprint(predecessor);
		successor.ShippedFingerprint__c = SEL_MaskingRule.computeFingerprint(successor);

		return new List<MaskingRule__mdt> {predecessor, successor};
	}

	/**
	 * @description Replaces every masking rule the selector sees with the given rules, so the
	 * supersession checks see exactly these rules. The map keys are positions in the list, because
	 * copies may share a DeveloperName, and the code that reads the map reads only its values.
	 *
	 * @param rules Every masking rule the test needs
	 */
	private static void overrideAllRules(List<MaskingRule__mdt> rules)
	{
		Map<String, MaskingRule__mdt> rulesByKey = new Map<String, MaskingRule__mdt>();

		for(Integer index = 0; index < rules.size(); index++)
		{
			rulesByKey.put(String.valueOf(index), rules[index]);
		}

		SEL_MaskingTarget.allRulesOverrideForTest = rulesByKey;
	}

	/**
	 * @description Builds and registers the standard supersession matrix fixture: wildcard
	 * predecessor target, and (optionally) a wildcard successor target mirroring the same
	 * surface.
	 *
	 * @param predecessorTuned Tune the predecessor after fingerprint capture
	 * @param successorTuned Tune the successor after fingerprint capture
	 * @param successorTargetPresent Register the mirroring successor target (false = subscriber-custom-object shape)
	 */
	private static void mockSupersessionPair(Boolean predecessorTuned, Boolean successorTuned, Boolean successorTargetPresent)
	{
		List<MaskingRule__mdt> pair = buildSupersessionRulePair(predecessorTuned, successorTuned);

		registerMockTarget(pair[0], null, null);

		if(successorTargetPresent)
		{
			registerMockTarget(pair[1], null, null);
		}
	}

	/**
	 * @description Builds an uninserted Foobar__c whose Name carries both supersession tokens, so
	 * each rule's application is independently observable in the output value regardless of rule
	 * execution order.
	 *
	 * @return An uninserted Foobar__c ready for the framework masker
	 */
	private static Foobar__c buildSupersessionRecord()
	{
		return (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, PREDECESSOR_TOKEN + ' ' + SUCCESSOR_TOKEN)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Builds a JSON object of the given length whose secret key holds an object, followed by a padding text
	 * (see `OBJECT_UNDER_A_SECRET_KEY_HEAD`).
	 *
	 * @param length The length of the JSON text
	 *
	 * @return The JSON text
	 */
	private static String buildObjectUnderASecretKey(Integer length)
	{
		return OBJECT_UNDER_A_SECRET_KEY_HEAD + PADDING_CHARACTER.repeat(length - OBJECT_UNDER_A_SECRET_KEY_HEAD.length() - PADDED_OBJECT_TAIL.length()) + PADDED_OBJECT_TAIL;
	}

	/**
	 * @description Checks that a value with a long run of spaces around the colon of a secret key got the failure marker,
	 * and that nothing of the secret is in the masked text. A masked text longer than the field is read from
	 * `uncutMaskedValue`, and the end of it is shown in the message when the secret is found.
	 *
	 * @param result The masking result to check
	 */
	private static void assertSecretMarked(UTIL_FrameworkMasker.MaskingResult result)
	{
		String maskedText = result.uncutMaskedValue ?? result.maskedValue;
		Assert.isFalse(maskedText.contains(PASSWORD_VALUE), 'Expected no secret left in clear, found ' + maskedText.right(MESSAGE_WINDOW_LENGTH));
		Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, result.maskedValue, 'Expected the failure marker in place of the whole value');
	}

	/**
	 * @description Checks that the value built by `buildObjectUnderASecretKey` was read as JSON: the object under the
	 * secret key is replaced by the replacement of the secret-keys rule, and the padding text is kept. The masked text is
	 * longer than the field, so the whole text is read from `uncutMaskedValue`.
	 *
	 * @param result The masking result to check
	 * @param secretRule The shipped secret-keys rule, whose replacement is expected
	 */
	private static void assertObjectUnderTheSecretKeyReplaced(UTIL_FrameworkMasker.MaskingResult result, MaskingRule__mdt secretRule)
	{
		Assert.isFalse(result.hadErrors, 'Expected the secret-keys rule to finish without an error');
		Assert.isNotNull(result.uncutMaskedValue, 'Expected the masked text to be longer than the field, got ' + result.maskedValue?.left(40));
		Map<String, Object> masked = (Map<String, Object>)JSON.deserializeUntyped(result.uncutMaskedValue);
		Assert.areEqual(secretRule.Replacement__c, masked.get(SECRET_KEY_HOLDING_AN_OBJECT), 'Expected the object under the secret key replaced');
		Assert.isTrue(((String)masked.get(PADDING_KEY)).startsWith(PADDING_CHARACTER), 'Expected the padding text kept');
	}

	/**
	 * @description A Queueable that masks one value of `ApiCall__c.Request__c` and keeps the result in
	 * `resultMaskedInQueueable`, so a test can check how the masking reads a value in an asynchronous transaction.
	 */
	@SuppressWarnings('PMD.QueueableWithoutFinalizer')
	private inherited sharing class MaskInQueueable implements Queueable
	{
		/**
		 * @description The value to mask.
		 */
		private final String value;

		/**
		 * @description Prepares the job.
		 *
		 * @param value The value to mask
		 */
		private MaskInQueueable(String value)
		{
			this.value = value;
		}

		/**
		 * @description Masks the value and keeps the result.
		 *
		 * @param context The context of the Queueable job
		 */
		public void execute(QueueableContext context)
		{
			resultMaskedInQueueable = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).maskAndReturnWholeText(value);
		}
	}
}