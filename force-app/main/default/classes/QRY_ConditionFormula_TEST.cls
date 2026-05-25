// SPDX-License-Identifier: BUSL-1.1
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
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.CyclomaticComplexity')
private class QRY_ConditionFormula_TEST
{
	/**
	 * @description Test field name for simple conditions.
	 */
	private static final String TEST_FIELD = 'Name';

	/**
	 * @description Test field name for numeric conditions.
	 */
	private static final String TEST_NUMERIC_FIELD = 'Amount';

	/**
	 * @description Record prefix used in formula expressions.
	 */
	private static final String PREFIX = QRY_ConditionFormula.RECORD_PREFIX;

	/**
	 * @description Tests EQUALS with a String value.
	 */
	@IsTest
	private static void equalsWithString()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).equals('Active');

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual(PREFIX + 'Name = "Active"', result, 'Should translate EQUALS String');
	}

	/**
	 * @description Tests EQUALS with an Integer value.
	 */
	@IsTest
	private static void equalsWithInteger()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).equals(100);

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual(PREFIX + 'Amount = 100', result, 'Should translate EQUALS Integer');
	}

	/**
	 * @description Tests EQUALS with a Decimal value.
	 */
	@IsTest
	private static void equalsWithDecimal()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).equals(99.5);

		String result = QRY_ConditionFormula.toFormula(condition);

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

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual(PREFIX + 'Amount = 1234567890', result, 'Should translate EQUALS Long');
	}

	/**
	 * @description Tests EQUALS with a Boolean true value.
	 */
	@IsTest
	private static void equalsWithBooleanTrue()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition('IsActive').equals(true);

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual(PREFIX + 'IsActive = TRUE', result, 'Should translate EQUALS Boolean true');
	}

	/**
	 * @description Tests EQUALS with a Boolean false value.
	 */
	@IsTest
	private static void equalsWithBooleanFalse()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition('IsActive').equals(false);

		String result = QRY_ConditionFormula.toFormula(condition);

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

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual(PREFIX + 'CloseDate = DATE(2026, 2, 5)', result, 'Should translate EQUALS Date');
	}

	/**
	 * @description Tests EQUALS with a Datetime value.
	 */
	@IsTest
	private static void equalsWithDatetime()
	{
		Datetime testDatetime = Datetime.newInstanceGmt(2026, 2, 5, 10, 0, 0);
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition('CreatedDate').equals(testDatetime);

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual(PREFIX + 'CreatedDate = DATETIMEVALUE("' + UTIL_Date.toIso8601(testDatetime) + '")', result, 'Should translate EQUALS Datetime');
	}

	/**
	 * @description Tests EQUALS with an Id value.
	 */
	@IsTest
	private static void equalsWithId()
	{
		Id testId = UTIL_Random.randomId(Account.SObjectType);
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition('AccountId').equals(testId);

		String result = QRY_ConditionFormula.toFormula(condition);

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

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual('ISBLANK(' + PREFIX + 'Name)', result, 'Should translate EQUALS null to ISBLANK');
	}

	/**
	 * @description Tests NOT_EQUALS with a String value.
	 */
	@IsTest
	private static void notEqualsWithString()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).notEquals('Inactive');

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual(PREFIX + 'Name <> "Inactive"', result, 'Should translate NOT_EQUALS String');
	}

	/**
	 * @description Tests NOT_EQUALS with null generates NOT(ISBLANK) formula.
	 */
	@IsTest
	private static void notEqualsWithNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).notEquals(null);

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual('NOT(ISBLANK(' + PREFIX + 'Name))', result, 'Should translate NOT_EQUALS null to NOT(ISBLANK)');
	}

	/**
	 * @description Tests GREATER_THAN operator.
	 */
	@IsTest
	private static void greaterThan()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).greaterThan(100);

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual(PREFIX + 'Amount > 100', result, 'Should translate GREATER_THAN');
	}

	/**
	 * @description Tests LESS_THAN operator.
	 */
	@IsTest
	private static void lessThan()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).lessThan(50);

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual(PREFIX + 'Amount < 50', result, 'Should translate LESS_THAN');
	}

	/**
	 * @description Tests GREATER_THAN_OR_EQUAL_TO operator.
	 */
	@IsTest
	private static void greaterThanOrEqualTo()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).greaterThanOrEqualTo(100);

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual(PREFIX + 'Amount >= 100', result, 'Should translate GREATER_THAN_OR_EQUAL_TO');
	}

	/**
	 * @description Tests LESS_THAN_OR_EQUAL_TO operator.
	 */
	@IsTest
	private static void lessThanOrEqualTo()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).lessThanOrEqualTo(50);

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual(PREFIX + 'Amount <= 50', result, 'Should translate LESS_THAN_OR_EQUAL_TO');
	}

	/**
	 * @description Tests LIKE_X with %value% pattern translates to CONTAINS.
	 */
	@IsTest
	private static void likeContainsPattern()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).likeX('%test%');

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual('CONTAINS(' + PREFIX + 'Name, "test")', result, 'Should translate LIKE %val% to CONTAINS');
	}

	/**
	 * @description Tests LIKE_X with starts-with pattern returns null (unsupported).
	 */
	@IsTest
	private static void likeStartsWithReturnsNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).likeX('test%');

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.isNull(result, 'Should return null for starts-with LIKE pattern');
	}

	/**
	 * @description Tests LIKE_X with ends-with pattern returns null (unsupported).
	 */
	@IsTest
	private static void likeEndsWithReturnsNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).likeX('%test');

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.isNull(result, 'Should return null for ends-with LIKE pattern');
	}

	/**
	 * @description Tests LIKE_X with non-String value returns null.
	 */
	@IsTest
	private static void likeWithNonStringReturnsNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).likeX(123);

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.isNull(result, 'Should return null for non-string LIKE value');
	}

	/**
	 * @description Tests LIKE_X with single % character returns null.
	 */
	@IsTest
	private static void likeWithOnlyWildcardsReturnsNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).likeX('%%');

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.isNull(result, 'Should return null for empty contains pattern');
	}

	/**
	 * @description Tests IN_X with multiple String values.
	 */
	@IsTest
	private static void inWithStringValues()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD).inX(new List<Object> {'A', 'B', 'C'});

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual('(' + PREFIX + 'Name = "A" || ' + PREFIX + 'Name = "B" || ' + PREFIX + 'Name = "C")', result, 'Should translate IN with OR clauses');
	}

	/**
	 * @description Tests IN_X with a single value.
	 */
	@IsTest
	private static void inWithSingleValue()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD).inX(new List<Object> {'Active'});

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual('(' + PREFIX + 'Name = "Active")', result, 'Should translate IN with single value');
	}

	/**
	 * @description Tests NOT_IN with multiple String values.
	 */
	@IsTest
	private static void notInWithStringValues()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD).notIn(new List<Object> {'A', 'B'});

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual('(' + PREFIX + 'Name <> "A" && ' + PREFIX + 'Name <> "B")', result, 'Should translate NOT IN with AND clauses');
	}

	/**
	 * @description Tests IN_X with Integer values.
	 */
	@IsTest
	private static void inWithIntegerValues()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_NUMERIC_FIELD).inX(new List<Object> {1, 2, 3});

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual('(' + PREFIX + 'Amount = 1 || ' + PREFIX + 'Amount = 2 || ' + PREFIX + 'Amount = 3)', result, 'Should translate IN with Integer values');
	}

	/**
	 * @description Tests INCLUDES operator returns null (unsupported).
	 */
	@IsTest
	private static void includesReturnsNull()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD).includes(new List<Object> {'A', 'B'});

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.isNull(result, 'Should return null for INCLUDES operator');
	}

	/**
	 * @description Tests EXCLUDES operator returns null (unsupported).
	 */
	@IsTest
	private static void excludesReturnsNull()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD).excludes(new List<Object> {'A', 'B'});

		String result = QRY_ConditionFormula.toFormula(condition);

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

		String result = QRY_ConditionFormula.toFormula(condition);

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

		String result = QRY_ConditionFormula.toFormula(andGroup);

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

		String result = QRY_ConditionFormula.toFormula(orGroup);

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

		String result = QRY_ConditionFormula.toFormula(andGroup);

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

		String result = QRY_ConditionFormula.toFormula(andGroup);

		Assert.areEqual('(' + PREFIX + 'Name = "Active")', result, 'Single condition in group should be wrapped once');
	}

	/**
	 * @description Tests empty AND condition group returns null.
	 */
	@IsTest
	private static void emptyAndGroupReturnsNull()
	{
		QRY_Condition.AndCondition andGroup = new QRY_Condition.AndCondition();

		String result = QRY_ConditionFormula.toFormula(andGroup);

		Assert.isNull(result, 'Empty group should return null');
	}

	/**
	 * @description Tests empty OR condition group returns null.
	 */
	@IsTest
	private static void emptyOrGroupReturnsNull()
	{
		QRY_Condition.OrCondition orGroup = new QRY_Condition.OrCondition();

		String result = QRY_ConditionFormula.toFormula(orGroup);

		Assert.isNull(result, 'Empty group should return null');
	}

	/**
	 * @description Tests that a relationship field path (contains dot) returns null.
	 */
	@IsTest
	private static void relationshipFieldReturnsNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition('Account.Name').equals('Test');

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.isNull(result, 'Relationship field should return null');
	}

	/**
	 * @description Tests that a relationship field in SetCondition returns null.
	 */
	@IsTest
	private static void relationshipFieldInSetConditionReturnsNull()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Account.Type').inX(new List<Object> {'A', 'B'});

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.isNull(result, 'Relationship field in SetCondition should return null');
	}

	/**
	 * @description Tests null condition input returns null.
	 */
	@IsTest
	private static void nullConditionReturnsNull()
	{
		String result = QRY_ConditionFormula.toFormula(null);

		Assert.isNull(result, 'Null condition should return null');
	}

	/**
	 * @description Tests unknown Evaluable implementation returns null.
	 */
	@IsTest
	private static void unknownEvaluableReturnsNull()
	{
		QRY_Condition.DateLiteral dateLiteral = new QRY_Condition.DateLiteral().today();

		String result = QRY_ConditionFormula.toFormula(dateLiteral);

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

		String result = QRY_ConditionFormula.toFormula(andGroup);

		Assert.isNull(result, 'Group with unsupported child should return null');
	}

	/**
	 * @description Tests String value with double quotes is escaped properly.
	 */
	@IsTest
	private static void stringValueWithDoubleQuotesEscaped()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).equals('He said "hello"');

		String result = QRY_ConditionFormula.toFormula(condition);

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

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.isNull(result, 'FieldCondition with null field should return null');
	}

	/**
	 * @description Tests NOT_EQUALS with an Integer value.
	 */
	@IsTest
	private static void notEqualsWithInteger()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).notEquals(0);

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual(PREFIX + 'Amount <> 0', result, 'Should translate NOT_EQUALS Integer');
	}

	/**
	 * @description Tests GREATER_THAN with a Decimal value.
	 */
	@IsTest
	private static void greaterThanWithDecimal()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD).greaterThan(99.99);

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual(PREFIX + 'Amount > 99.99', result, 'Should translate GREATER_THAN Decimal');
	}

	/**
	 * @description Tests IN with Boolean values.
	 */
	@IsTest
	private static void inWithBooleanValues()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('IsActive').inX(new List<Object> {true, false});

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual('(' + PREFIX + 'IsActive = TRUE || ' + PREFIX + 'IsActive = FALSE)', result, 'Should translate IN with Boolean values');
	}

	/**
	 * @description Tests NOT_IN with a single value.
	 */
	@IsTest
	private static void notInWithSingleValue()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD).notIn(new List<Object> {'Inactive'});

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual('(' + PREFIX + 'Name <> "Inactive")', result, 'Should translate NOT IN with single value');
	}

	/**
	 * @description Tests CONTAINS formula output escapes double quotes in search value.
	 */
	@IsTest
	private static void likeContainsWithSpecialCharacters()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD).likeX('%say "hi"%');

		String result = QRY_ConditionFormula.toFormula(condition);

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

		String result = QRY_ConditionFormula.toFormula(condition);

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

		String result = QRY_ConditionFormula.toFormula(condition);

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

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.areEqual(PREFIX + 'Amount = 3.14', result, 'Should translate EQUALS Double');
	}

	/**
	 * @description Tests that a SetCondition with an unsupported value type in the list returns null.
	 */
	@IsTest
	private static void setConditionWithUnsupportedValueTypeReturnsNull()
	{
		QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD, QRY_Condition.Operator.IN_X, new List<Object> {new QRY_Condition.DateLiteral().today()});

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.isNull(result, 'SetCondition with unsupported value type should return null');
	}

	/**
	 * @description Tests that formatValue returns null when value is null for a non-null-handling operator.
	 */
	@IsTest
	private static void nonNullOperatorWithNullValueReturnsNull()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_NUMERIC_FIELD, QRY_Condition.Operator.GREATER_THAN, null);

		String result = QRY_ConditionFormula.toFormula(condition);

		Assert.isNull(result, 'Non-null operator with null value should return null');
	}
}