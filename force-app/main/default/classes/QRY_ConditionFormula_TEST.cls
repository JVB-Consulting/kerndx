// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for QRY_ConditionFormula, covering all operator translations,
 * value formatting, compound conditions, and edge cases.
 *
 * @see QRY_ConditionFormula
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date February 2026, November 2026
 */
@IsTest(seeAllData=false isParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.CyclomaticComplexity')
private class QRY_ConditionFormula_TEST
{
	/**
	 * @description Test field name for simple conditions.
	 */
	private static final String TEST_FIELD = 'Name';

	/**
	 * @description Test field name for conditions on a date and time.
	 */
	private static final String DATETIME_FIELD = 'CreatedDate';

	/**
	 * @description Test field name for numeric conditions.
	 */
	private static final String TEST_NUMERIC_FIELD = 'Amount';

	/**
	 * @description Record prefix used in formula expressions.
	 */
	private static final String PREFIX = QRY_ConditionFormula.RECORD_PREFIX;

	/**
	 * @description The object most tests write formulas for. Its Name, Amount, AccountId, CloseDate and CreatedDate fields
	 * are not picklists, so they are written as they are. It has no IsActive field: a field the object does not know is
	 * also written as it is.
	 */
	private static final SObjectType TEST_OBJECT_TYPE = Opportunity.SObjectType;

	/**
	 * @description How a formula writes the date and time of the Datetime tests, 5 February 2026 at 10:00:00 GMT.
	 */
	private static final String DATETIME_FORMULA = 'DATETIMEVALUE("2026-02-05 10:00:00")';

	/**
	 * @description How a formula writes the start of the second after the date and time of the Datetime tests.
	 */
	private static final String NEXT_SECOND_FORMULA = 'DATETIMEVALUE("2026-02-05 10:00:01")';

	/**
	 * @description How many milliseconds past the whole second a Datetime test value lies.
	 */
	private static final Long MILLISECONDS_PAST_THE_SECOND = 250;

	/**
	 * @description How a formula reads the picklist field of Foobar__c: inside TEXT(), which gives its value as text.
	 */
	private static final String PICKLIST_FIELD_AS_TEXT = 'TEXT(' + PREFIX + SEL_Foobar.FIELD_PICKLIST + ')';

	/**
	 * @description The number of letters in a random picklist value.
	 */
	private static final Integer PICKLIST_VALUE_LENGTH = 8;

	/**
	 * @description The most characters the split tests let into one formula: room for two values of a list on the Name
	 * field, which take 46 characters, but not for three, which take 70.
	 */
	private static final Integer SMALL_FORMULA_LENGTH = 50;

	/**
	 * @description The most characters the comparison count tests let into one formula. It is far above what their formulas
	 * need, so only the number of comparisons decides whether a formula is split.
	 */
	private static final Integer LARGE_FORMULA_LENGTH = 100000;

	/**
	 * @description The most characters the tests with two lists let into one formula: room for the 10 characters of the
	 * AND around them and 50 for each list.
	 */
	private static final Integer TWO_LIST_FORMULA_LENGTH = 110;

	/**
	 * @description A list of five values, longer than the small limit, so it is split into three parts.
	 */
	private static final List<Object> LONG_LIST = new List<Object> {'A', 'B', 'C', 'D', 'E'};

	/**
	 * @description A second list of five values, for the tests with two long lists.
	 */
	private static final List<Object> SECOND_LONG_LIST = new List<Object> {'V', 'W', 'X', 'Y', 'Z'};

	/**
	 * @description A list of four values, exactly two groups of two values.
	 */
	private static final List<Object> FOUR_VALUE_LIST = new List<Object> {'A', 'B', 'C', 'D'};

	/**
	 * @description A list of two values that fits beside a part of a long list.
	 */
	private static final List<Object> SHORT_LIST = new List<Object> {'Y', 'Z'};

	/**
	 * @description A path with a backslash in it, searched for with containsLiteral.
	 */
	private static final String PATH_WITH_BACKSLASH = 'C:\\dir';

	/**
	 * @description A name with an underscore in it, searched for with containsLiteral.
	 */
	private static final String NAME_WITH_UNDERSCORE = 'ACME_West';

	/**
	 * @description A text with a percent sign in it, searched for with containsLiteral.
	 */
	private static final String TEXT_WITH_PERCENT_SIGN = '50%';

	/**
	 * @description A text with a percent sign between other characters, searched for with contains.
	 */
	private static final String TEXT_WITH_PERCENT_SIGN_INSIDE = '50%off';

	/**
	 * @description The number of one-letter values in the list that fits by characters but has too many comparisons: 100
	 * values take about 2,400 characters, far below the limit.
	 */
	private static final Integer MANY_SHORT_VALUES_COUNT = 100;

	/**
	 * @description The number of one-letter values in each of the two lists that share the comparisons of a formula.
	 */
	private static final Integer SHARED_LIST_COUNT = 60;

	/**
	 * @description A value that ends in a backslash.
	 */
	private static final String VALUE_ENDING_IN_BACKSLASH = 'Folder\\';

	/**
	 * @description A value that holds a backslash right before a double quote.
	 */
	private static final String VALUE_WITH_BACKSLASH_BEFORE_QUOTE = 'say\\"hi';

	/**
	 * @description Tests EQUALS with a String value.
	 */
	@IsTest
	private static void equalsWithString()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).equals('Active');

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'Name = "Active"', result, 'Should translate EQUALS String');
	}

	/**
	 * @description Tests EQUALS with an Integer value.
	 */
	@IsTest
	private static void equalsWithInteger()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).equals(100);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'Amount = 100', result, 'Should translate EQUALS Integer');
	}

	/**
	 * @description Tests EQUALS with a Decimal value.
	 */
	@IsTest
	private static void equalsWithDecimal()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).equals(99.5);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'Amount = 99.5', result, 'Should translate EQUALS Decimal');
	}

	/**
	 * @description Tests EQUALS with a Long value.
	 */
	@IsTest
	private static void equalsWithLong()
	{
		Long longValue = 1234567890L;
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).equals(longValue);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'Amount = 1234567890', result, 'Should translate EQUALS Long');
	}

	/**
	 * @description Tests EQUALS with a Boolean true value.
	 */
	@IsTest
	private static void equalsWithBooleanTrue()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition('IsActive').equals(true);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'IsActive = TRUE', result, 'Should translate EQUALS Boolean true');
	}

	/**
	 * @description Tests EQUALS with a Boolean false value.
	 */
	@IsTest
	private static void equalsWithBooleanFalse()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition('IsActive').equals(false);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'IsActive = FALSE', result, 'Should translate EQUALS Boolean false');
	}

	/**
	 * @description Tests EQUALS with a Date value.
	 */
	@IsTest
	private static void equalsWithDate()
	{
		Date testDate = Date.newInstance(2026, 2, 5);
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition('CloseDate').equals(testDate);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'CloseDate = DATE(2026, 2, 5)', result, 'Should translate EQUALS Date');
	}

	/**
	 * @description Tests EQUALS with a Datetime value: the record matches anywhere inside that whole second, as in the
	 * database, which keeps no milliseconds.
	 */
	@IsTest
	private static void equalsWithDatetime()
	{
		Datetime testDatetime = Datetime.newInstanceGmt(2026, 2, 5, 10, 0, 0);
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(DATETIME_FIELD).equals(testDatetime);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual('(' + PREFIX + DATETIME_FIELD + ' >= ' + DATETIME_FORMULA + ' && ' + PREFIX + DATETIME_FIELD + ' < ' + NEXT_SECOND_FORMULA + ')', result,
				'Expected the date and time in GMT, written with a space and no T or Z, and the record checked inside that whole second');
	}

	/**
	 * @description Tests each comparison other than equals with a Datetime value that has milliseconds. Not equals is
	 * written as outside the value's second. At or before the value is written as before the next second, and after the
	 * value as at or after the next second. Before the value, and at or after the value, are written against the start of
	 * the value's second.
	 */
	@IsTest
	private static void shouldCompareADatetimeValueAtWholeSeconds()
	{
		Datetime testDatetime = Datetime.newInstanceGmt(2026, 2, 5, 10, 0, 0);
		Datetime withMilliseconds = Datetime.newInstance(testDatetime.getTime() + MILLISECONDS_PAST_THE_SECOND);
		String field = PREFIX + DATETIME_FIELD;

		Assert.areEqual('NOT(' + field + ' >= ' + DATETIME_FORMULA + ' && ' + field + ' < ' + NEXT_SECOND_FORMULA + ')',
				QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(DATETIME_FIELD).notEquals(withMilliseconds), TEST_OBJECT_TYPE),
				'Expected not equals to match a record outside the whole second');
		Assert.areEqual(field + ' < ' + NEXT_SECOND_FORMULA,
				QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(DATETIME_FIELD).lessThanOrEqualTo(withMilliseconds), TEST_OBJECT_TYPE),
				'Expected at or before the value to mean before the next second');
		Assert.areEqual(field + ' >= ' + NEXT_SECOND_FORMULA,
				QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(DATETIME_FIELD).greaterThan(withMilliseconds), TEST_OBJECT_TYPE),
				'Expected after the value to mean at or after the next second');
		Assert.areEqual(field + ' < ' + DATETIME_FORMULA,
				QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(DATETIME_FIELD).lessThan(withMilliseconds), TEST_OBJECT_TYPE),
				'Expected before the value to mean before the start of its second');
		Assert.areEqual(field + ' >= ' + DATETIME_FORMULA,
				QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(DATETIME_FIELD).greaterThanOrEqualTo(withMilliseconds), TEST_OBJECT_TYPE),
				'Expected at or after the value to mean at or after the start of its second');
	}

	/**
	 * @description Tests that each value of an IN or NOT IN list of Datetime values is checked at whole seconds.
	 */
	@IsTest
	private static void shouldCompareEachDatetimeOfAListAtWholeSeconds()
	{
		Datetime testDatetime = Datetime.newInstanceGmt(2026, 2, 5, 10, 0, 0);
		String field = PREFIX + DATETIME_FIELD;
		String insideTheSecond = '(' + field + ' >= ' + DATETIME_FORMULA + ' && ' + field + ' < ' + NEXT_SECOND_FORMULA + ')';

		Assert.areEqual('(' + insideTheSecond + ')',
				QRY_ConditionFormula.toFormula(new QRY_Condition.SetCondition(DATETIME_FIELD).inX(new List<Object> {testDatetime}), TEST_OBJECT_TYPE),
				'Expected an IN value to match a record inside its whole second');
		Assert.areEqual('(NOT' + insideTheSecond + ')',
				QRY_ConditionFormula.toFormula(new QRY_Condition.SetCondition(DATETIME_FIELD).notIn(new List<Object> {testDatetime}), TEST_OBJECT_TYPE),
				'Expected a NOT IN value to match a record outside its whole second');
	}

	/**
	 * @description Tests EQUALS with an Id value.
	 */
	@IsTest
	private static void equalsWithId()
	{
		Id testId = UTIL_Random.randomId(Account.SObjectType);
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition('AccountId').equals(testId);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.isTrue(result.startsWith(PREFIX + 'AccountId = "'), 'Should translate EQUALS Id with quotes');
		Assert.isTrue(result.endsWith('"'), 'Should end with closing quote');
	}

	/**
	 * @description Tests EQUALS with null generates ISBLANK formula.
	 */
	@IsTest
	private static void equalsWithNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).equals(null);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual('ISBLANK(' + PREFIX + 'Name)', result, 'Should translate EQUALS null to ISBLANK');
	}

	/**
	 * @description Tests NOT_EQUALS with a String value.
	 */
	@IsTest
	private static void notEqualsWithString()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).notEquals('Inactive');

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'Name <> "Inactive"', result, 'Should translate NOT_EQUALS String');
	}

	/**
	 * @description Tests NOT_EQUALS with null generates NOT(ISBLANK) formula.
	 */
	@IsTest
	private static void notEqualsWithNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).notEquals(null);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual('NOT(ISBLANK(' + PREFIX + 'Name))', result, 'Should translate NOT_EQUALS null to NOT(ISBLANK)');
	}

	/**
	 * @description Tests GREATER_THAN operator.
	 */
	@IsTest
	private static void greaterThan()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).greaterThan(100);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'Amount > 100', result, 'Should translate GREATER_THAN');
	}

	/**
	 * @description Tests LESS_THAN operator.
	 */
	@IsTest
	private static void lessThan()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).lessThan(50);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'Amount < 50', result, 'Should translate LESS_THAN');
	}

	/**
	 * @description Tests GREATER_THAN_OR_EQUAL_TO operator.
	 */
	@IsTest
	private static void greaterThanOrEqualTo()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).greaterThanOrEqualTo(100);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'Amount >= 100', result, 'Should translate GREATER_THAN_OR_EQUAL_TO');
	}

	/**
	 * @description Tests LESS_THAN_OR_EQUAL_TO operator.
	 */
	@IsTest
	private static void lessThanOrEqualTo()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).lessThanOrEqualTo(50);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'Amount <= 50', result, 'Should translate LESS_THAN_OR_EQUAL_TO');
	}

	/**
	 * @description Tests LIKE_X with %value% pattern translates to CONTAINS.
	 */
	@IsTest
	private static void likeContainsPattern()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).likeX('%test%');

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual('CONTAINS(' + PREFIX + 'Name, "test")', result, 'Should translate LIKE %val% to CONTAINS');
	}

	/**
	 * @description Tests LIKE_X with starts-with pattern returns null (unsupported).
	 */
	@IsTest
	private static void likeStartsWithReturnsNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).likeX('test%');

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'Should return null for starts-with LIKE pattern');
	}

	/**
	 * @description Tests LIKE_X with ends-with pattern returns null (unsupported).
	 */
	@IsTest
	private static void likeEndsWithReturnsNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).likeX('%test');

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'Should return null for ends-with LIKE pattern');
	}

	/**
	 * @description Tests LIKE_X with non-String value returns null.
	 */
	@IsTest
	private static void likeWithNonStringReturnsNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).likeX(123);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'Should return null for non-string LIKE value');
	}

	/**
	 * @description Tests LIKE_X with single % character returns null.
	 */
	@IsTest
	private static void likeWithOnlyWildcardsReturnsNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).likeX('%%');

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'Should return null for empty contains pattern');
	}

	/**
	 * @description Tests IN_X with multiple String values.
	 */
	@IsTest
	private static void inWithStringValues()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD).inX(new List<Object> {'A', 'B', 'C'});

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual('(' + PREFIX + 'Name = "A" || ' + PREFIX + 'Name = "B" || ' + PREFIX + 'Name = "C")', result, 'Should translate IN with OR clauses');
	}

	/**
	 * @description Tests IN_X with a single value.
	 */
	@IsTest
	private static void inWithSingleValue()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD).inX(new List<Object> {'Active'});

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual('(' + PREFIX + 'Name = "Active")', result, 'Should translate IN with single value');
	}

	/**
	 * @description Tests NOT_IN with multiple String values.
	 */
	@IsTest
	private static void notInWithStringValues()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD).notIn(new List<Object> {'A', 'B'});

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual('(' + PREFIX + 'Name <> "A" && ' + PREFIX + 'Name <> "B")', result, 'Should translate NOT IN with AND clauses');
	}

	/**
	 * @description Tests IN_X with Integer values.
	 */
	@IsTest
	private static void inWithIntegerValues()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_NUMERIC_FIELD).inX(new List<Object> {1, 2, 3});

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual('(' + PREFIX + 'Amount = 1 || ' + PREFIX + 'Amount = 2 || ' + PREFIX + 'Amount = 3)', result, 'Should translate IN with Integer values');
	}

	/**
	 * @description Tests INCLUDES operator returns null (unsupported).
	 */
	@IsTest
	private static void includesReturnsNull()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD).includes(new List<Object> {'A', 'B'});

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'Should return null for INCLUDES operator');
	}

	/**
	 * @description Tests EXCLUDES operator returns null (unsupported).
	 */
	@IsTest
	private static void excludesReturnsNull()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD).excludes(new List<Object> {'A', 'B'});

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'Should return null for EXCLUDES operator');
	}

	/**
	 * @description Tests SetCondition with a subquery builder returns null (unsupported).
	 */
	@IsTest
	private static void setConditionWithBuilderReturnsNull()
	{
		QRY_Generator builder = new QRY_Generator(Account.SObjectType);
		builder.addFields(new Set<String> {'Id'});
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('AccountId').inX(builder);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'Should return null for subquery SetCondition');
	}

	/**
	 * @description Tests AND condition group with two conditions.
	 */
	@IsTest
	private static void andConditionGroup()
	{
		QRY_Condition.AndCondition andGroup = new QRY_Condition.AndCondition();
		andGroup.add(new QRY_Condition.FieldCondition(TEST_FIELD).equals('Active'));
		andGroup.add(new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).greaterThan(100));

		String result = QRY_ConditionFormula.toFormula(andGroup, TEST_OBJECT_TYPE);

		Assert.areEqual('((' + PREFIX + 'Name = "Active") && (' + PREFIX + 'Amount > 100))', result, 'Should translate AND group');
	}

	/**
	 * @description Tests OR condition group with two conditions.
	 */
	@IsTest
	private static void orConditionGroup()
	{
		QRY_Condition.OrCondition orGroup = new QRY_Condition.OrCondition();
		orGroup.add(new QRY_Condition.FieldCondition(TEST_FIELD).equals('Active'));
		orGroup.add(new QRY_Condition.FieldCondition(TEST_FIELD).equals('Pending'));

		String result = QRY_ConditionFormula.toFormula(orGroup, TEST_OBJECT_TYPE);

		Assert.areEqual('((' + PREFIX + 'Name = "Active") || (' + PREFIX + 'Name = "Pending"))', result, 'Should translate OR group');
	}

	/**
	 * @description Tests nested condition groups (AND containing OR).
	 */
	@IsTest
	private static void nestedConditionGroups()
	{
		QRY_Condition.OrCondition orGroup = new QRY_Condition.OrCondition();
		orGroup.add(new QRY_Condition.FieldCondition(TEST_FIELD).equals('A'));
		orGroup.add(new QRY_Condition.FieldCondition(TEST_FIELD).equals('B'));

		QRY_Condition.AndCondition andGroup = new QRY_Condition.AndCondition();
		andGroup.add(orGroup);
		andGroup.add(new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).greaterThan(0));

		String result = QRY_ConditionFormula.toFormula(andGroup, TEST_OBJECT_TYPE);

		Assert.isNotNull(result, 'Should translate nested groups');
		Assert.isTrue(result.contains('||'), 'Should contain OR operator from nested group');
		Assert.isTrue(result.contains('&&'), 'Should contain AND operator from outer group');
	}

	/**
	 * @description Tests AND group with single condition returns unwrapped formula.
	 */
	@IsTest
	private static void andGroupWithSingleCondition()
	{
		QRY_Condition.AndCondition andGroup = new QRY_Condition.AndCondition();
		andGroup.add(new QRY_Condition.FieldCondition(TEST_FIELD).equals('Active'));

		String result = QRY_ConditionFormula.toFormula(andGroup, TEST_OBJECT_TYPE);

		Assert.areEqual('(' + PREFIX + 'Name = "Active")', result, 'Single condition in group should be wrapped once');
	}

	/**
	 * @description Tests empty AND condition group returns null.
	 */
	@IsTest
	private static void emptyAndGroupReturnsNull()
	{
		QRY_Condition.AndCondition andGroup = new QRY_Condition.AndCondition();

		String result = QRY_ConditionFormula.toFormula(andGroup, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'Empty group should return null');
	}

	/**
	 * @description Tests empty OR condition group returns null.
	 */
	@IsTest
	private static void emptyOrGroupReturnsNull()
	{
		QRY_Condition.OrCondition orGroup = new QRY_Condition.OrCondition();

		String result = QRY_ConditionFormula.toFormula(orGroup, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'Empty group should return null');
	}

	/**
	 * @description Tests that a relationship field path (contains dot) returns null.
	 */
	@IsTest
	private static void relationshipFieldReturnsNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition('Account.Name').equals('Test');

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'Relationship field should return null');
	}

	/**
	 * @description Tests that a relationship field in SetCondition returns null.
	 */
	@IsTest
	private static void relationshipFieldInSetConditionReturnsNull()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Account.Type').inX(new List<Object> {'A', 'B'});

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'Relationship field in SetCondition should return null');
	}

	/**
	 * @description Tests null condition input returns null.
	 */
	@IsTest
	private static void nullConditionReturnsNull()
	{
		String result = QRY_ConditionFormula.toFormula(null, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'Null condition should return null');
	}

	/**
	 * @description Tests unknown Evaluable implementation returns null.
	 */
	@IsTest
	private static void unknownEvaluableReturnsNull()
	{
		QRY_Condition.DateLiteral dateLiteral = new QRY_Condition.DateLiteral().today();

		String result = QRY_ConditionFormula.toFormula(dateLiteral, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'Unknown Evaluable type should return null');
	}

	/**
	 * @description Tests AND group containing an unsupported child returns null.
	 */
	@IsTest
	private static void groupWithUnsupportedChildReturnsNull()
	{
		QRY_Condition.AndCondition andGroup = new QRY_Condition.AndCondition();
		andGroup.add(new QRY_Condition.FieldCondition(TEST_FIELD).equals('Active'));
		andGroup.add(new QRY_Condition.FieldCondition('Account.Name').equals('Test'));

		String result = QRY_ConditionFormula.toFormula(andGroup, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'Group with unsupported child should return null');
	}

	/**
	 * @description Tests String value with double quotes is escaped properly.
	 */
	@IsTest
	private static void stringValueWithDoubleQuotesEscaped()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).equals('He said "hello"');

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'Name = "He said \\"hello\\""', result, 'Double quotes should be escaped');
	}

	/**
	 * @description Tests that FieldCondition with null field returns null.
	 */
	@IsTest
	private static void fieldConditionWithNullFieldReturnsNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition();
		condition.equals('test');

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'FieldCondition with null field should return null');
	}

	/**
	 * @description Tests NOT_EQUALS with an Integer value.
	 */
	@IsTest
	private static void notEqualsWithInteger()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).notEquals(0);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'Amount <> 0', result, 'Should translate NOT_EQUALS Integer');
	}

	/**
	 * @description Tests GREATER_THAN with a Decimal value.
	 */
	@IsTest
	private static void greaterThanWithDecimal()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).greaterThan(99.99);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'Amount > 99.99', result, 'Should translate GREATER_THAN Decimal');
	}

	/**
	 * @description Tests IN with Boolean values.
	 */
	@IsTest
	private static void inWithBooleanValues()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('IsActive').inX(new List<Object> {true, false});

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual('(' + PREFIX + 'IsActive = TRUE || ' + PREFIX + 'IsActive = FALSE)', result, 'Should translate IN with Boolean values');
	}

	/**
	 * @description Tests NOT_IN with a single value.
	 */
	@IsTest
	private static void notInWithSingleValue()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD).notIn(new List<Object> {'Inactive'});

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual('(' + PREFIX + 'Name <> "Inactive")', result, 'Should translate NOT IN with single value');
	}

	/**
	 * @description Tests CONTAINS formula output escapes double quotes in search value.
	 */
	@IsTest
	private static void likeContainsWithSpecialCharacters()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).likeX('%say "hi"%');

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual('CONTAINS(' + PREFIX + 'Name, "say \\"hi\\"")', result, 'Should escape quotes in CONTAINS');
	}

	/**
	 * @description Tests Date formatting in IN condition.
	 */
	@IsTest
	private static void inWithDateValues()
	{
		Date date1 = Date.newInstance(2026, 1, 1);
		Date date2 = Date.newInstance(2026, 12, 31);
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('CloseDate').inX(new List<Object> {date1, date2});

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.isTrue(result.contains('DATE(2026, 1, 1)'), 'Should contain first date');
		Assert.isTrue(result.contains('DATE(2026, 12, 31)'), 'Should contain second date');
	}

	/**
	 * @description Tests that an unsupported value type in FieldCondition returns null.
	 */
	@IsTest
	private static void unsupportedValueTypeReturnsNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).equals(new QRY_Condition.DateLiteral().today());

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'Unsupported value type (Evaluable) should return null');
	}

	/**
	 * @description Tests Double value formatting.
	 */
	@IsTest
	private static void equalsWithDouble()
	{
		Double doubleValue = 3.14;
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).equals(doubleValue);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'Amount = 3.14', result, 'Should translate EQUALS Double');
	}

	/**
	 * @description Tests that a SetCondition with an unsupported value type in the list returns null.
	 */
	@IsTest
	private static void setConditionWithUnsupportedValueTypeReturnsNull()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD, QRY_Condition.Operator.IN_X, new List<Object> {new QRY_Condition.DateLiteral().today()});

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'SetCondition with unsupported value type should return null');
	}

	/**
	 * @description Tests that formatValue returns null when value is null for a non-null-handling operator.
	 */
	@IsTest
	private static void nonNullOperatorWithNullValueReturnsNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD, QRY_Condition.Operator.GREATER_THAN, null);

		String result = QRY_ConditionFormula.toFormula(condition, TEST_OBJECT_TYPE);

		Assert.isNull(result, 'Non-null operator with null value should return null');
	}

	/**
	 * @description A value that ends in a backslash, or holds a backslash before a quote, gets each backslash doubled
	 * before the quotes are escaped, so the value stays one string in the formula.
	 */
	@IsTest
	private static void shouldEscapeBackslashesBeforeQuotes()
	{
		String endsInBackslash = QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(TEST_FIELD).equals(VALUE_ENDING_IN_BACKSLASH), TEST_OBJECT_TYPE);
		String backslashBeforeQuote = QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(TEST_FIELD).equals(VALUE_WITH_BACKSLASH_BEFORE_QUOTE), TEST_OBJECT_TYPE);

		Assert.areEqual(PREFIX + 'Name = "Folder\\\\"', endsInBackslash, 'Expected the backslash at the end to be doubled');
		Assert.areEqual(PREFIX + 'Name = "say\\\\\\"hi"', backslashBeforeQuote, 'Expected the backslash doubled and the quote escaped');
	}

	/**
	 * @description containsLiteral escapes a backslash, an underscore and a percent sign for the LIKE pattern. The formula
	 * undoes those escapes and looks for the text itself, with the backslash escaped once for the formula.
	 */
	@IsTest
	private static void shouldSearchForTheLiteralTextOfAContainsLiteralCondition()
	{
		String backslashFormula = QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(TEST_FIELD).containsLiteral(PATH_WITH_BACKSLASH), TEST_OBJECT_TYPE);
		String underscoreFormula = QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(TEST_FIELD).containsLiteral(NAME_WITH_UNDERSCORE), TEST_OBJECT_TYPE);
		String percentFormula = QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(TEST_FIELD).containsLiteral(TEXT_WITH_PERCENT_SIGN), TEST_OBJECT_TYPE);

		Assert.areEqual('CONTAINS(' + PREFIX + 'Name, "C:\\\\dir")', backslashFormula, 'Expected one backslash, escaped once for the formula');
		Assert.areEqual('CONTAINS(' + PREFIX + 'Name, "ACME_West")', underscoreFormula, 'Expected the underscore as plain text');
		Assert.areEqual('CONTAINS(' + PREFIX + 'Name, "50%")', percentFormula, 'Expected the percent sign as plain text');
	}

	/**
	 * @description A LIKE pattern with a percent sign or an underscore in the middle, without a backslash in front, is
	 * searched for as plain text, because CONTAINS cannot stand for any characters.
	 */
	@IsTest
	private static void shouldSearchForAWildcardInTheMiddleAsPlainText()
	{
		String underscoreFormula = QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(TEST_FIELD).contains(NAME_WITH_UNDERSCORE), TEST_OBJECT_TYPE);
		String percentFormula = QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(TEST_FIELD).contains(TEXT_WITH_PERCENT_SIGN_INSIDE), TEST_OBJECT_TYPE);

		Assert.areEqual('CONTAINS(' + PREFIX + 'Name, "ACME_West")', underscoreFormula, 'Expected the underscore as plain text');
		Assert.areEqual('CONTAINS(' + PREFIX + 'Name, "50%off")', percentFormula, 'Expected the percent sign as plain text');
	}

	/**
	 * @description A LIKE pattern with a lone backslash before the last percent sign is not a search for text anywhere in
	 * the field, so no formula is made.
	 */
	@IsTest
	private static void shouldNotTranslateALikePatternThatEndsInALoneBackslash()
	{
		Assert.isNull(QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(TEST_FIELD, QRY_Condition.Operator.LIKE_X, '%end\\%'), TEST_OBJECT_TYPE),
				'Expected no formula when a backslash makes the last percent sign plain text');
	}

	/**
	 * @description A formula cannot compare a picklist field with text as it is, so the field is put inside TEXT(), which
	 * gives the value of the field as text. This holds for equals, not equals and a search for text in the field.
	 */
	@IsTest
	private static void shouldWrapAPicklistFieldInTextForAnEqualsCondition()
	{
		String value = UTIL_Random.randomAlphabetic(PICKLIST_VALUE_LENGTH);

		String equalsFormula = QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_PICKLIST).equals(value), Foobar__c.SObjectType);
		String notEqualsFormula = QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_PICKLIST).notEquals(value), Foobar__c.SObjectType);
		String containsFormula = QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_PICKLIST).contains(value), Foobar__c.SObjectType);

		Assert.areEqual(PICKLIST_FIELD_AS_TEXT + ' = "' + value + '"', equalsFormula, 'Expected the picklist field inside TEXT() for equals');
		Assert.areEqual(PICKLIST_FIELD_AS_TEXT + ' <> "' + value + '"', notEqualsFormula, 'Expected the picklist field inside TEXT() for not equals');
		Assert.areEqual('CONTAINS(' + PICKLIST_FIELD_AS_TEXT + ', "' + value + '")', containsFormula, 'Expected the picklist field inside TEXT() for contains');
	}

	/**
	 * @description Each value of an IN or NOT IN list on a picklist field is compared with the field inside TEXT().
	 */
	@IsTest
	private static void shouldWrapAPicklistFieldInTextForAnInList()
	{
		String firstValue = UTIL_Random.randomAlphabetic(PICKLIST_VALUE_LENGTH);
		String secondValue = UTIL_Random.randomAlphabetic(PICKLIST_VALUE_LENGTH);
		List<Object> values = new List<Object> {firstValue, secondValue};

		String inFormula = QRY_ConditionFormula.toFormula(new QRY_Condition.SetCondition(SEL_Foobar.FIELD_PICKLIST).inX(values), Foobar__c.SObjectType);
		String notInFormula = QRY_ConditionFormula.toFormula(new QRY_Condition.SetCondition(SEL_Foobar.FIELD_PICKLIST).notIn(values), Foobar__c.SObjectType);

		Assert.areEqual('(' + PICKLIST_FIELD_AS_TEXT + ' = "' + firstValue + '" || ' + PICKLIST_FIELD_AS_TEXT + ' = "' + secondValue + '")', inFormula,
				'Expected each value of the IN list compared with the picklist field inside TEXT()');
		Assert.areEqual('(' + PICKLIST_FIELD_AS_TEXT + ' <> "' + firstValue + '" && ' + PICKLIST_FIELD_AS_TEXT + ' <> "' + secondValue + '")', notInFormula,
				'Expected each value of the NOT IN list compared with the picklist field inside TEXT()');
	}

	/**
	 * @description A check that a picklist field is blank, or is not blank, looks at the field inside TEXT().
	 */
	@IsTest
	private static void shouldWrapAPicklistFieldInTextForABlankCheck()
	{
		String blankFormula = QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_PICKLIST).equals(null), Foobar__c.SObjectType);
		String notBlankFormula = QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_PICKLIST).notEquals(null), Foobar__c.SObjectType);

		Assert.areEqual('ISBLANK(' + PICKLIST_FIELD_AS_TEXT + ')', blankFormula, 'Expected the blank check to look at the picklist field inside TEXT()');
		Assert.areEqual('NOT(ISBLANK(' + PICKLIST_FIELD_AS_TEXT + '))', notBlankFormula, 'Expected the not-blank check to look at the picklist field inside TEXT()');
	}

	/**
	 * @description When no object is given, the translator cannot tell which fields are picklists, so the field is written
	 * as it is.
	 */
	@IsTest
	private static void shouldWriteTheFieldAsItIsWhenNoObjectIsGiven()
	{
		String value = UTIL_Random.randomAlphabetic(PICKLIST_VALUE_LENGTH);

		String formula = QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_PICKLIST).equals(value), null);

		Assert.areEqual(PREFIX + SEL_Foobar.FIELD_PICKLIST + ' = "' + value + '"', formula, 'Expected the field as it is when no object is given');
	}

	/**
	 * @description Greater than and less than on a picklist field are not checked in a test: the condition gets no
	 * formula, so a mocked read with it returns every mock.
	 */
	@IsTest
	private static void shouldReturnNoFormulaForAGreaterThanConditionOnAPicklist()
	{
		String value = UTIL_Random.randomAlphabetic(PICKLIST_VALUE_LENGTH);

		Assert.isNull(QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_PICKLIST).greaterThan(value), Foobar__c.SObjectType),
				'Expected no formula for greater than on a picklist field');
		Assert.isNull(QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_PICKLIST).lessThan(value), Foobar__c.SObjectType),
				'Expected no formula for less than on a picklist field');
		Assert.isNull(QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_PICKLIST).greaterThanOrEqualTo(value), Foobar__c.SObjectType),
				'Expected no formula for greater than or equal to on a picklist field');
		Assert.isNull(QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_PICKLIST).lessThanOrEqualTo(value), Foobar__c.SObjectType),
				'Expected no formula for less than or equal to on a picklist field');
	}

	/**
	 * @description A multi-select picklist field holds several values in one, which a formula cannot compare, so a
	 * condition that compares it with a value gets no formula, and the read then returns every mock. A check that the
	 * field is blank, or is not blank, is written with the field as it is.
	 */
	@IsTest
	private static void shouldWriteOnlyBlankChecksForAMultiSelectPicklist()
	{
		String value = UTIL_Random.randomAlphabetic(PICKLIST_VALUE_LENGTH);

		Assert.isNull(QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_PICKLIST_MULTI_SELECT).equals(value), Foobar__c.SObjectType),
				'Expected no formula for equals on a multi-select picklist field');
		Assert.isNull(QRY_ConditionFormula.toFormula(new QRY_Condition.SetCondition(SEL_Foobar.FIELD_PICKLIST_MULTI_SELECT).inX(new List<Object> {value}), Foobar__c.SObjectType),
				'Expected no formula for an IN list on a multi-select picklist field');
		Assert.areEqual('ISBLANK(' + PREFIX + SEL_Foobar.FIELD_PICKLIST_MULTI_SELECT + ')',
				QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_PICKLIST_MULTI_SELECT).equals(null), Foobar__c.SObjectType),
				'Expected the blank check on a multi-select picklist field to read the field as it is');
		Assert.areEqual('NOT(ISBLANK(' + PREFIX + SEL_Foobar.FIELD_PICKLIST_MULTI_SELECT + '))',
				QRY_ConditionFormula.toFormula(new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_PICKLIST_MULTI_SELECT).notEquals(null), Foobar__c.SObjectType),
				'Expected the not-blank check on a multi-select picklist field to read the field as it is');
	}

	/**
	 * @description Each value of an IN list on a picklist field costs six more characters, for TEXT(), so splitToFit
	 * counts the field inside TEXT() when it splits a long list. The parts still check every value, in order.
	 */
	@IsTest
	private static void shouldSplitALongInListOnAPicklistField()
	{
		String twoValueFormula = QRY_ConditionFormula.toFormula(new QRY_Condition.SetCondition(SEL_Foobar.FIELD_PICKLIST).inX(SHORT_LIST), Foobar__c.SObjectType);
		QRY_ConditionFormula.maximumFormulaLength = twoValueFormula.length();

		QRY_ConditionFormula.ConditionPart plan = QRY_ConditionFormula.splitToFit(new QRY_Condition.SetCondition(SEL_Foobar.FIELD_PICKLIST).inX(LONG_LIST), Foobar__c.SObjectType);

		Assert.areEqual
				(
						new List<String>
						{
								'(' + PICKLIST_FIELD_AS_TEXT + ' = "A" || ' + PICKLIST_FIELD_AS_TEXT + ' = "B")',
								'(' + PICKLIST_FIELD_AS_TEXT + ' = "C" || ' + PICKLIST_FIELD_AS_TEXT + ' = "D")',
								'(' + PICKLIST_FIELD_AS_TEXT + ' = "E")'
						},
						collectFormulas(plan),
						'Expected three parts of at most two values, each value compared with the picklist field inside TEXT()'
				);
		Assert.isTrue(plan.isMatchedByAnyPart, 'Expected an IN list to match when any part matches');
	}

	/**
	 * @description A condition whose formula fits is planned as that one formula, and a condition that cannot be written
	 * as a formula, such as a subquery list, or no condition at all, gets no plan.
	 */
	@IsTest
	private static void shouldPlanOneFormulaForAConditionThatFits()
	{
		QRY_ConditionFormula.maximumFormulaLength = SMALL_FORMULA_LENGTH;
		QRY_Generator subquery = new QRY_Generator(Account.SObjectType);
		subquery.addFields(new Set<String> {'Id'});
		QRY_Condition.SetCondition shortList = new QRY_Condition.SetCondition(TEST_FIELD).inX(new List<Object> {'A', 'B'});

		QRY_ConditionFormula.ConditionPart plan = QRY_ConditionFormula.splitToFit(shortList, TEST_OBJECT_TYPE);

		Assert.areEqual(QRY_ConditionFormula.toFormula(shortList, TEST_OBJECT_TYPE), plan.formula, 'Expected a list of two values to fit in one formula');
		Assert.isTrue(plan.parts.isEmpty(), 'Expected no smaller parts');
		Assert.areEqual(1, plan.formulaCount, 'Expected one formula');
		Assert.isNull(QRY_ConditionFormula.splitToFit(new QRY_Condition.SetCondition('AccountId').inX(subquery), TEST_OBJECT_TYPE), 'Expected no plan for a subquery list');
		Assert.isNull(QRY_ConditionFormula.splitToFit(null, TEST_OBJECT_TYPE), 'Expected no plan without a condition');
	}

	/**
	 * @description A condition that is too long for one formula, and has no list to split, gets no plan.
	 */
	@IsTest
	private static void shouldNotPlanALongConditionWithNoListToSplit()
	{
		QRY_ConditionFormula.maximumFormulaLength = SMALL_FORMULA_LENGTH;
		QRY_Condition.AndCondition condition = new QRY_Condition.AndCondition();
		condition.add(new QRY_Condition.FieldCondition(TEST_FIELD).equals('A'));
		condition.add(new QRY_Condition.FieldCondition(TEST_FIELD).equals('B'));
		condition.add(new QRY_Condition.FieldCondition(TEST_FIELD).equals('C'));

		Assert.isNull(QRY_ConditionFormula.splitToFit(condition, TEST_OBJECT_TYPE), 'Expected no plan, since there is no list to split');
	}

	/**
	 * @description A long INCLUDES list gets no plan, because a formula cannot check INCLUDES at all.
	 */
	@IsTest
	private static void shouldNotPlanALongIncludesList()
	{
		QRY_ConditionFormula.maximumFormulaLength = SMALL_FORMULA_LENGTH;

		QRY_ConditionFormula.ConditionPart plan = QRY_ConditionFormula.splitToFit(new QRY_Condition.SetCondition(TEST_FIELD).includes(LONG_LIST), TEST_OBJECT_TYPE);

		Assert.isNull(plan, 'Expected no plan for an INCLUDES list');
	}

	/**
	 * @description A long IN list is split into lists whose formulas fit, in the order of the values, and a record
	 * matches the whole condition when it matches any part.
	 */
	@IsTest
	private static void shouldSplitALongInListInOrder()
	{
		QRY_ConditionFormula.maximumFormulaLength = SMALL_FORMULA_LENGTH;

		QRY_ConditionFormula.ConditionPart plan = QRY_ConditionFormula.splitToFit(new QRY_Condition.SetCondition(TEST_FIELD).inX(LONG_LIST), TEST_OBJECT_TYPE);

		Assert.isNull(plan.formula, 'Expected the long list not to fit in one formula');
		Assert.isTrue(plan.isMatchedByAnyPart, 'Expected an IN list to match when any part matches');
		Assert.areEqual
				(
						new List<String>
						{
								'(' + PREFIX + 'Name = "A" || ' + PREFIX + 'Name = "B")',
								'(' + PREFIX + 'Name = "C" || ' + PREFIX + 'Name = "D")',
								'(' + PREFIX + 'Name = "E")'
						},
						collectFormulas(plan),
						'Expected three parts of at most two values, in the order of the values'
				);
		Assert.areEqual(3, plan.formulaCount, 'Expected three formulas');
	}

	/**
	 * @description A long NOT IN list is split the same way, and a record matches the whole condition only when it
	 * matches every part.
	 */
	@IsTest
	private static void shouldSplitALongNotInList()
	{
		QRY_ConditionFormula.maximumFormulaLength = SMALL_FORMULA_LENGTH;

		QRY_ConditionFormula.ConditionPart plan = QRY_ConditionFormula.splitToFit(new QRY_Condition.SetCondition(TEST_FIELD).notIn(LONG_LIST), TEST_OBJECT_TYPE);

		Assert.isFalse(plan.isMatchedByAnyPart, 'Expected a NOT IN list to match only when every part matches');
		Assert.areEqual(3, plan.parts.size(), 'Expected three parts of at most two values');
		Assert.areEqual('(' + PREFIX + 'Name <> "E")', plan.parts[2].formula, 'Expected the last value alone in the last part');
	}

	/**
	 * @description A list that splits into groups of exactly the same size gets no empty part at the end.
	 */
	@IsTest
	private static void shouldNotAddAnEmptyPartWhenAListSplitsEvenly()
	{
		QRY_ConditionFormula.maximumFormulaLength = SMALL_FORMULA_LENGTH;

		QRY_ConditionFormula.ConditionPart plan = QRY_ConditionFormula.splitToFit(new QRY_Condition.SetCondition(TEST_FIELD).inX(FOUR_VALUE_LIST), TEST_OBJECT_TYPE);

		Assert.areEqual
				(
						new List<String>
						{
								'(' + PREFIX + 'Name = "A" || ' + PREFIX + 'Name = "B")',
								'(' + PREFIX + 'Name = "C" || ' + PREFIX + 'Name = "D")'
						},
						collectFormulas(plan),
						'Expected two parts of two values and no empty part'
				);
	}

	/**
	 * @description Two long lists in one condition share the space equally, so each is split into groups of two values. A
	 * group with one value leaves more space for the other list. Every formula fits.
	 */
	@IsTest
	private static void shouldShareTheSpaceBetweenTwoLongLists()
	{
		QRY_Condition.AndCondition condition = new QRY_Condition.AndCondition();
		condition.add(new QRY_Condition.SetCondition(TEST_FIELD).inX(LONG_LIST));
		condition.add(new QRY_Condition.SetCondition(TEST_FIELD).inX(SECOND_LONG_LIST));
		QRY_ConditionFormula.maximumFormulaLength = TWO_LIST_FORMULA_LENGTH;

		QRY_ConditionFormula.ConditionPart plan = QRY_ConditionFormula.splitToFit(condition, TEST_OBJECT_TYPE);

		List<String> formulas = collectFormulas(plan);
		Assert.areEqual(8, formulas.size(), 'Expected three formulas for each of the first two groups and two for the last value alone');
		Assert.areEqual(formulas.size(), plan.formulaCount, 'Expected the plan to count every formula');
		for(String formula : formulas)
		{
			Assert.isTrue(formula.length() <= TWO_LIST_FORMULA_LENGTH, 'Expected every formula to fit, got ' + formula);
		}
		Assert.areEqual
				(
						'(((' + PREFIX + 'Name = "A" || ' + PREFIX + 'Name = "B")) && ((' + PREFIX + 'Name = "V" || ' + PREFIX + 'Name = "W")))',
						formulas[0],
						'Expected the first formula to hold the first two values of each list'
				);
	}

	/**
	 * @description A short list beside a long one keeps all its values, and the long list gets the rest of the space.
	 */
	@IsTest
	private static void shouldKeepAShortListWholeWhileSplittingALongOne()
	{
		QRY_Condition.AndCondition condition = new QRY_Condition.AndCondition();
		condition.add(new QRY_Condition.SetCondition(TEST_FIELD).inX(LONG_LIST));
		condition.add(new QRY_Condition.SetCondition(TEST_FIELD).inX(SHORT_LIST));
		QRY_ConditionFormula.maximumFormulaLength = TWO_LIST_FORMULA_LENGTH;

		QRY_ConditionFormula.ConditionPart plan = QRY_ConditionFormula.splitToFit(condition, TEST_OBJECT_TYPE);

		String shortListFormula = '(' + PREFIX + 'Name = "Y" || ' + PREFIX + 'Name = "Z")';
		Assert.areEqual
				(
						new List<String>
						{
								'(((' + PREFIX + 'Name = "A" || ' + PREFIX + 'Name = "B")) && (' + shortListFormula + '))',
								'(((' + PREFIX + 'Name = "C" || ' + PREFIX + 'Name = "D")) && (' + shortListFormula + '))',
								'(((' + PREFIX + 'Name = "E")) && (' + shortListFormula + '))'
						},
						collectFormulas(plan),
						'Expected the long list split in three and the short list whole in each formula'
				);
	}

	/**
	 * @description A long list inside nested groups is split into copies of the whole condition: each copy keeps the
	 * other conditions and the kind of each group, and the condition passed in is not changed.
	 */
	@IsTest
	private static void shouldKeepTheOtherConditionsWhenSplittingInsideGroups()
	{
		QRY_Condition.FieldCondition numberCondition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).greaterThan(0);
		QRY_Condition.OrCondition orGroup = new QRY_Condition.OrCondition();
		orGroup.add(numberCondition);
		orGroup.add(new QRY_Condition.SetCondition(TEST_FIELD).inX(new List<Object> {'A', 'B', 'C'}));
		QRY_Condition.AndCondition andGroup = new QRY_Condition.AndCondition();
		andGroup.add(new QRY_Condition.FieldCondition(TEST_FIELD).notEquals('Z'));
		andGroup.add(orGroup);
		String formulaBefore = QRY_ConditionFormula.toFormula(andGroup, TEST_OBJECT_TYPE);
		QRY_ConditionFormula.maximumFormulaLength = formulaBefore.length() - 1;

		QRY_ConditionFormula.ConditionPart plan = QRY_ConditionFormula.splitToFit(andGroup, TEST_OBJECT_TYPE);

		String otherConditions = '((' + PREFIX + 'Name <> "Z") && (((' + PREFIX + 'Amount > 0) || ';
		Assert.areEqual
				(
						new List<String>
						{
								otherConditions + '((' + PREFIX + 'Name = "A" || ' + PREFIX + 'Name = "B")))))',
								otherConditions + '((' + PREFIX + 'Name = "C")))))'
						},
						collectFormulas(plan),
						'Expected each part to keep the other conditions and the AND and OR groups'
				);
		Assert.isInstanceOfType(plan.parts[0].condition, QRY_Condition.AndCondition.class, 'Expected the outer group to stay an AND');
		Assert.areEqual(formulaBefore, QRY_ConditionFormula.toFormula(andGroup, TEST_OBJECT_TYPE), 'Expected the condition passed in to be unchanged');
	}

	/**
	 * @description A list of 100 short values fits in one formula by its characters, but it has more comparisons than one
	 * formula may hold, so it is split into a part with the most comparisons a formula may hold and a part with the rest.
	 */
	@IsTest
	private static void shouldSplitAListWithMoreComparisonsThanOneFormulaMayHold()
	{
		QRY_Condition.SetCondition manyValues = new QRY_Condition.SetCondition(TEST_FIELD).inX(newNumberNames(MANY_SHORT_VALUES_COUNT));
		Assert.isTrue(QRY_ConditionFormula.toFormula(manyValues, TEST_OBJECT_TYPE).length() <= QRY_ConditionFormula.maximumFormulaLength, 'Expected the list to fit by characters');

		QRY_ConditionFormula.ConditionPart plan = QRY_ConditionFormula.splitToFit(manyValues, TEST_OBJECT_TYPE);

		Assert.isNull(plan.formula, 'Expected the list not to fit in one formula');
		Assert.areEqual(2, plan.formulaCount, 'Expected two formulas');
		Integer firstPartSize = ((QRY_Condition.SetCondition)plan.parts[0].condition).values.size();
		Integer secondPartSize = ((QRY_Condition.SetCondition)plan.parts[1].condition).values.size();
		Assert.areEqual(QRY_ConditionFormula.MAXIMUM_COMPARISONS_PER_FORMULA, firstPartSize, 'Expected the first part to hold the most comparisons');
		Assert.areEqual(MANY_SHORT_VALUES_COUNT - firstPartSize, secondPartSize, 'Expected the second part to hold the rest');
	}

	/**
	 * @description Two lists whose comparisons together are more than one formula may hold share the comparisons, and no
	 * formula of the plan holds more than the most a formula may hold.
	 */
	@IsTest
	private static void shouldShareTheComparisonsBetweenTwoLists()
	{
		QRY_Condition.AndCondition condition = new QRY_Condition.AndCondition();
		condition.add(new QRY_Condition.SetCondition(TEST_FIELD).inX(newNumberNames(SHARED_LIST_COUNT)));
		condition.add(new QRY_Condition.SetCondition(TEST_FIELD).notIn(newNumberNames(SHARED_LIST_COUNT)));

		QRY_ConditionFormula.ConditionPart plan = QRY_ConditionFormula.splitToFit(condition, TEST_OBJECT_TYPE);

		List<String> formulas = collectFormulas(plan);
		Assert.areEqual(3, formulas.size(), 'Expected the first list split in two and the second split once beside the larger part');
		for(String formula : formulas)
		{
			Integer comparisonCount = formula.countMatches(PREFIX);
			Assert.isTrue(comparisonCount <= QRY_ConditionFormula.MAXIMUM_COMPARISONS_PER_FORMULA, 'Expected at most the most comparisons, got ' + comparisonCount);
		}
	}

	/**
	 * @description A list that needs exactly the most formulas one read may plan gets a plan, and a list that needs one
	 * more gets none.
	 */
	@IsTest
	private static void shouldPlanNoMoreThanTheMostFormulasForOneRead()
	{
		QRY_ConditionFormula.maximumFormulaLength = SMALL_FORMULA_LENGTH;
		List<Object> mostValues = new List<Object>();
		for(Integer index = 0; index < QRY_ConditionFormula.MAXIMUM_FORMULAS_PER_READ * 2; index++)
		{
			mostValues.add(LONG_LIST[0]);
		}
		List<Object> tooManyValues = mostValues.clone();
		tooManyValues.add(LONG_LIST[0]);

		QRY_ConditionFormula.ConditionPart plan = QRY_ConditionFormula.splitToFit(new QRY_Condition.SetCondition(TEST_FIELD).inX(mostValues), TEST_OBJECT_TYPE);

		Assert.areEqual(QRY_ConditionFormula.MAXIMUM_FORMULAS_PER_READ, plan.formulaCount, 'Expected the most formulas, two values each');
		Assert.isNull(QRY_ConditionFormula.splitToFit(new QRY_Condition.SetCondition(TEST_FIELD).inX(tooManyValues), TEST_OBJECT_TYPE), 'Expected no plan for one formula more');
	}

	/**
	 * @description A date and time in an IN or NOT IN list is written as two comparisons, so it counts two. The test has a
	 * list of text values that is two values short of the most comparisons one formula may hold, and a list of two date
	 * and time values. Together they count two comparisons more than one formula may hold, though the formula is short in
	 * characters. So the condition is split into two formulas.
	 */
	@IsTest
	private static void shouldCountTwoComparisonsForEachDatetimeOfAList()
	{
		QRY_ConditionFormula.maximumFormulaLength = LARGE_FORMULA_LENGTH;
		Datetime firstTime = Datetime.newInstanceGmt(2026, 2, 5, 10, 0, 0);
		QRY_Condition.AndCondition condition = new QRY_Condition.AndCondition();
		condition.add(new QRY_Condition.SetCondition(TEST_FIELD).inX(newNumberNames(QRY_ConditionFormula.MAXIMUM_COMPARISONS_PER_FORMULA - 2)));
		condition.add(new QRY_Condition.SetCondition(DATETIME_FIELD).notIn(new List<Object> {firstTime, firstTime.addSeconds(1)}));

		QRY_ConditionFormula.ConditionPart plan = QRY_ConditionFormula.splitToFit(condition, TEST_OBJECT_TYPE);

		Assert.areEqual(2, plan.formulaCount, 'Expected two formulas, since the two date and time values count four comparisons');
	}

	/**
	 * @description A date and time that is checked for equal or not equal is written as two comparisons, so it counts
	 * two. Each condition is tested beside a list of text values that is one value short of the most comparisons one
	 * formula may hold. With an equal or not equal condition the total is one comparison too many, so the list is split
	 * into two formulas. A date and time checked at or before the value is written as one comparison, so everything fits
	 * in one formula.
	 */
	@IsTest
	private static void shouldCountTwoComparisonsForEachDatetimeEqualityCondition()
	{
		QRY_ConditionFormula.maximumFormulaLength = LARGE_FORMULA_LENGTH;
		Datetime testDatetime = Datetime.newInstanceGmt(2026, 2, 5, 10, 0, 0);

		Assert.areEqual(2, planListWithOneMoreCondition(new QRY_Condition.FieldCondition(DATETIME_FIELD).equals(testDatetime)).formulaCount,
				'Expected an equal condition to count two comparisons');
		Assert.areEqual(2, planListWithOneMoreCondition(new QRY_Condition.FieldCondition(DATETIME_FIELD).notEquals(testDatetime)).formulaCount,
				'Expected a not equal condition to count two comparisons');
		Assert.areEqual(1, planListWithOneMoreCondition(new QRY_Condition.FieldCondition(DATETIME_FIELD).lessThanOrEqualTo(testDatetime)).formulaCount,
				'Expected an at or before condition to count one comparison');
	}

	/**
	 * @description The test has an IN list of date and time values. The list has one value more than half of the most
	 * comparisons one formula may hold. Each value counts two comparisons, so the list counts two comparisons more than
	 * one formula may hold. The list is split in two: the first formula holds as many values as fit, and the second
	 * formula holds the one value left.
	 */
	@IsTest
	private static void shouldSplitAListOfDatetimesByItsComparisons()
	{
		QRY_ConditionFormula.maximumFormulaLength = LARGE_FORMULA_LENGTH;
		Integer valueCount = QRY_ConditionFormula.MAXIMUM_COMPARISONS_PER_FORMULA / 2 + 1;

		QRY_ConditionFormula.ConditionPart plan = QRY_ConditionFormula.splitToFit(new QRY_Condition.SetCondition(DATETIME_FIELD).inX(newDatetimes(valueCount)), TEST_OBJECT_TYPE);

		List<String> formulas = collectFormulas(plan);
		Assert.areEqual(2, formulas.size(), 'Expected two formulas');
		Assert.areEqual(QRY_ConditionFormula.MAXIMUM_COMPARISONS_PER_FORMULA, formulas[0].countMatches(PREFIX), 'Expected the first formula to hold as many values as fit');
		Assert.areEqual(2, formulas[1].countMatches(PREFIX), 'Expected the second formula to hold the one value left, written as two comparisons');
	}

	/**
	 * @description The test has an IN list of date and time values, one value more than half of the most comparisons one
	 * formula may hold, joined with one equal condition on a text field. Each date and time value counts two comparisons
	 * and the equal condition counts one, so the list may use one comparison less than one formula holds: an odd number.
	 * The first formula holds as many whole values as fit beside the equal condition, and the second formula holds the two
	 * values left and the equal condition again.
	 */
	@IsTest
	private static void shouldSplitAListOfDatetimesWhenItsShareIsOdd()
	{
		QRY_ConditionFormula.maximumFormulaLength = LARGE_FORMULA_LENGTH;
		Integer valueCount = QRY_ConditionFormula.MAXIMUM_COMPARISONS_PER_FORMULA / 2 + 1;
		QRY_Condition.AndCondition condition = new QRY_Condition.AndCondition();
		condition.add(new QRY_Condition.SetCondition(DATETIME_FIELD).inX(newDatetimes(valueCount)));
		condition.add(new QRY_Condition.FieldCondition(TEST_FIELD).equals(UTIL_Random.random(10)));

		QRY_ConditionFormula.ConditionPart plan = QRY_ConditionFormula.splitToFit(condition, TEST_OBJECT_TYPE);

		List<String> formulas = collectFormulas(plan);
		Assert.areEqual(2, formulas.size(), 'Expected two formulas');
		Assert.areEqual(QRY_ConditionFormula.MAXIMUM_COMPARISONS_PER_FORMULA - 1, formulas[0].countMatches(PREFIX),
				'Expected the first formula to hold 39 values, written as two comparisons each, and the equal condition');
		Assert.areEqual(5, formulas[1].countMatches(PREFIX),
				'Expected the second formula to hold the two values left, written as two comparisons each, and the equal condition');
	}

	/**
	 * @description Plans a condition made of a list of text values that is one value short of the most comparisons one
	 * formula may hold, and one more condition.
	 *
	 * @param otherCondition The condition that comes after the list.
	 *
	 * @return The plan.
	 */
	private static QRY_ConditionFormula.ConditionPart planListWithOneMoreCondition(QRY_Condition.Evaluable otherCondition)
	{
		QRY_Condition.AndCondition condition = new QRY_Condition.AndCondition();
		condition.add(new QRY_Condition.SetCondition(TEST_FIELD).inX(newNumberNames(QRY_ConditionFormula.MAXIMUM_COMPARISONS_PER_FORMULA - 1)));
		condition.add(otherCondition);
		return QRY_ConditionFormula.splitToFit(condition, TEST_OBJECT_TYPE);
	}

	/**
	 * @description Builds a list that holds the same date and time value many times. It reads the list from JSON text
	 * made by repeating the value, so it needs no loop: a loop would push this test class over the code scanner's
	 * complexity limit for one class.
	 *
	 * @param count How many values.
	 *
	 * @return The values.
	 */
	private static List<Object> newDatetimes(Integer count)
	{
		String valueAsJson = JSON.serialize(Datetime.newInstanceGmt(2026, 2, 5, 10, 0, 0));
		return (List<Datetime>)JSON.deserialize('[' + valueAsJson.repeat(',', count) + ']', List<Datetime>.class);
	}

	/**
	 * @description Builds a list of the numbers from zero, written as text.
	 *
	 * @param count How many numbers.
	 *
	 * @return The numbers as text, in order.
	 */
	private static List<Object> newNumberNames(Integer count)
	{
		List<Object> names = new List<Object>();
		for(Integer index = 0; index < count; index++)
		{
			names.add(String.valueOf(index));
		}
		return names;
	}

	/**
	 * @description Collects the formulas of a plan, from left to right.
	 *
	 * @param plan The plan to read.
	 *
	 * @return The formulas, in the order the plan holds them.
	 */
	private static List<String> collectFormulas(QRY_ConditionFormula.ConditionPart plan)
	{
		List<String> formulas = new List<String>();
		if(plan.formula != null)
		{
			formulas.add(plan.formula);
		}
		for(QRY_ConditionFormula.ConditionPart part : plan.parts)
		{
			formulas.addAll(collectFormulas(part));
		}
		return formulas;
	}
}