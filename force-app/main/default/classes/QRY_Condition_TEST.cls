// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for QRY_Condition.
 * Tests all condition classes: FieldCondition, SetCondition, AndCondition, OrCondition, NotCondition, DateLiteral, UnitOfTime.
 *
 * @see QRY_Condition
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity,PMD.NcssTypeCount')
@IsTest(seeAllData=false isParallel=false)
private class QRY_Condition_TEST
{
	/**
	 * @description Company name given to the admin user created in test setup. It is unique to this class, so getTestAdmin
	 * can find that one user again by company name.
	 */
	private static final String TEST_ADMIN_COMPANY = 'QRY_Condition_TEST-admin';

	/**
	 * @description Test value for field name.
	 */
	private static final String TEST_FIELD = 'Name';

	/**
	 * @description Test value for string comparison.
	 */
	private static final String TEST_VALUE = 'Test';

	/**
	 * @description The name the bind registry gives the first value it holds.
	 */
	private static final String FIRST_BIND_NAME = 'bv0';

	/**
	 * @description The largest number an Apex Integer can hold.
	 */
	private static final Integer LARGEST_INTEGER = 2147483647;

	/**
	 * @description The smallest whole number too large for an Apex Integer.
	 */
	private static final Long FIRST_NUMBER_ABOVE_INTEGER_RANGE = 2147483648L;

	/**
	 * @description The smallest number an Apex Integer can hold: -2147483648.
	 */
	private static final Integer SMALLEST_INTEGER = -LARGEST_INTEGER - 1;

	/**
	 * @description The largest whole number too small for an Apex Integer: -2147483649.
	 */
	private static final Long FIRST_NUMBER_BELOW_INTEGER_RANGE = -2147483649L;

	/**
	 * @description A time of day. A query condition cannot use a Time value, so a list that holds one can be neither
	 * bound nor written into the query text.
	 */
	private static final Time NINE_IN_THE_MORNING = Time.newInstance(9, 0, 0, 0);

	/**
	 * @description The start of the error message given for a value that a query condition cannot use.
	 */
	private static final String UNSUPPORTED_LITERAL_MESSAGE_START = 'Unsupported literal type: ';

	/**
	 * @description The number of characters in a short record Id. A record Id can be written with 15 or with 18 characters.
	 */
	private static final Integer SHORT_ID_LENGTH = 15;

	/**
	 * @description A very small fractional value that Apex writes with an exponent (1E-9) when it turns the number into text.
	 */
	private static final String TINY_DECIMAL_TEXT = '0.000000001';

	/**
	 * @description The letter that starts the exponent part of a number written in scientific notation.
	 */
	private static final String EXPONENT_MARKER = 'E';

	/**
	 * @description Search term holding a trailing LIKE multiple-character wildcard.
	 */
	private static final String WILDCARD_SEARCH_TERM = '100%';

	/**
	 * @description The pattern containsLiteral must compose for WILDCARD_SEARCH_TERM: %100\%%
	 */
	private static final String ESCAPED_WILDCARD_PATTERN = '%100\\%%';

	/**
	 * @description Search term holding the LIKE escape character and a wildcard.
	 */
	private static final String BACKSLASH_SEARCH_TERM = 'a\\b%';

	/**
	 * @description The pattern containsLiteral must compose for BACKSLASH_SEARCH_TERM: %a\\b\%%
	 */
	private static final String ESCAPED_BACKSLASH_PATTERN = '%a\\\\b\\%%';

	/**
	 * @description Search term holding a LIKE single-character wildcard, as someone searching for a
	 * class name would type it.
	 */
	private static final String UNDERSCORE_SEARCH_TERM = 'UTIL_HttpClient';

	/**
	 * @description Seeded value holding UNDERSCORE_SEARCH_TERM literally.
	 */
	private static final String UNDERSCORE_MATCH_VALUE = 'UTIL_HttpClient timeout';

	/**
	 * @description Seeded decoy differing from UNDERSCORE_MATCH_VALUE only at the underscore.
	 */
	private static final String UNDERSCORE_DECOY_VALUE = 'UTILxHttpClient timeout';

	/**
	 * @description Seeded value holding WILDCARD_SEARCH_TERM literally.
	 */
	private static final String WILDCARD_MATCH_VALUE = 'Load 100% complete';

	/**
	 * @description Seeded decoy differing from WILDCARD_MATCH_VALUE only at the percent sign.
	 */
	private static final String WILDCARD_DECOY_VALUE = 'Load 100X complete';

	/**
	 * @description Expected SOQL output for YESTERDAY.
	 */
	private static final String EXPECTED_YESTERDAY = 'YESTERDAY';

	/**
	 * @description Expected SOQL output for TODAY.
	 */
	private static final String EXPECTED_TODAY = 'TODAY';

	/**
	 * @description Expected SOQL output for TOMORROW.
	 */
	private static final String EXPECTED_TOMORROW = 'TOMORROW';

	/**
	 * @description Name of the Custom Label that holds the message for a text the conditions refuse where they expect a
	 * field name. The message names the class that refused the text.
	 */
	private static final String FIELD_NAME_REFUSED_LABEL = 'QueryBuilder_FieldName_NotAllowed';

	/**
	 * @description Name of the Custom Label that holds the message for a word, other than AND or OR, given to join the
	 * conditions of a group.
	 */
	private static final String CONDITION_SEPARATOR_REFUSED_LABEL = 'QueryBuilder_ConditionSeparator_NotAllowed';

	/**
	 * @description Number of Foobar__c rows the tests about crafted field names save. A text that is let through and
	 * matches every row returns this many.
	 */
	private static final Integer CRAFTED_TEXT_PROBE_ROWS = 3;

	/**
	 * @description A time far in the future. Every saved record was created before it.
	 */
	private static final Datetime FAR_FUTURE = Datetime.newInstanceGmt(2100, 1, 1, 0, 0, 0);

	/**
	 * @description FAR_FUTURE as the query text writes it.
	 */
	private static final String FAR_FUTURE_TEXT = '2100-01-01T00:00:00.000Z';

	/**
	 * @description The phone number given to each Account a test saves. Some orgs that install the package have their
	 * own rule that an Account needs a phone number or a website, so a saved Account carries one.
	 */
	private static final String ACCOUNT_PHONE = '555-0100';

	/**
	 * @description The industry given to each Account a test saves. Some orgs that install the package have their own
	 * rule that an Account needs an industry, so a saved Account carries one.
	 */
	private static final String ACCOUNT_INDUSTRY = 'Technology';

	/**
	 * @description Creates a dedicated test admin user so System.runAs in each test starts a fresh
	 * permission-evaluation context, bypassing the synthetic-org permission-cache staleness issue
	 * that affected mutating the running user's permissionSet mid-transaction.
	 */
	@TestSetup
	private static void setupTestAdmin()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);
	}

	/**
	 * @description Tests that FieldCondition equals generates correct SOQL.
	 */
	@IsTest
	private static void shouldGenerateEqualsCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD, TEST_VALUE);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('Name = '), 'Should contain equals operator');
			Assert.isTrue(soql.contains('\'Test\''), 'Should contain quoted value');
		}
	}

	/**
	 * @description Tests that FieldCondition notEquals generates correct SOQL.
	 */
	@IsTest
	private static void shouldGenerateNotEqualsCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD);
			condition.notEquals(TEST_VALUE);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('Name != '), 'Should contain not equals operator');
		}
	}

	/**
	 * @description Tests that FieldCondition lessThan generates correct SOQL.
	 */
	@IsTest
	private static void shouldGenerateLessThanCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition('Amount');
			condition.lessThan(1000);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('Amount < 1000'), 'Should contain less than operator');
		}
	}

	/**
	 * @description Tests that FieldCondition lessThanOrEqualTo generates correct SOQL.
	 */
	@IsTest
	private static void shouldGenerateLessThanOrEqualToCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition('Amount');
			condition.lessThanOrEqualTo(1000);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('Amount <= 1000'), 'Should contain less than or equal operator');
		}
	}

	/**
	 * @description Tests that FieldCondition greaterThan generates correct SOQL.
	 */
	@IsTest
	private static void shouldGenerateGreaterThanCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition('Amount');
			condition.greaterThan(1000);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('Amount > 1000'), 'Should contain greater than operator');
		}
	}

	/**
	 * @description Tests that FieldCondition greaterThanOrEqualTo generates correct SOQL.
	 */
	@IsTest
	private static void shouldGenerateGreaterThanOrEqualToCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition('Amount');
			condition.greaterThanOrEqualTo(1000);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('Amount >= 1000'), 'Should contain greater than or equal operator');
		}
	}

	/**
	 * @description Tests that FieldCondition likeX generates correct SOQL.
	 */
	@IsTest
	private static void shouldGenerateLikeCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD);
			condition.likeX('%Test%');

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('LIKE'), 'Should contain LIKE operator');
			Assert.isTrue(soql.contains('%Test%'), 'Should contain pattern');
		}
	}

	/**
	 * @description Tests that FieldCondition contains wraps the value in wildcards itself, so callers
	 * never assemble LIKE patterns by hand.
	 */
	@IsTest
	private static void shouldGenerateContainsCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD);
			condition.contains('Test');

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('LIKE'), 'Should contain LIKE operator');
			Assert.isTrue(soql.contains('%Test%'), 'Should wrap the value in wildcards');
		}
	}

	/**
	 * @description Tests that containsLiteral escapes the LIKE wildcards inside the value, so a term a
	 * user typed matches the characters they typed. The assertion reads the bound value, which is what
	 * the database evaluates.
	 */
	@IsTest
	private static void shouldBindEscapedWildcardPatternForContainsLiteral()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD);
			condition.containsLiteral(WILDCARD_SEARCH_TERM);

			String soql = condition.toSoql(registry);

			Assert.isTrue(soql.contains('LIKE'), 'Should contain LIKE operator');
			Assert.isTrue(soql.contains(':b'), 'Should bind the pattern rather than inline it');
			Assert.areEqual(ESCAPED_WILDCARD_PATTERN, registry.getMap().values()[0], 'Should escape the percent sign inside the bound pattern');
		}
	}

	/**
	 * @description Tests that containsLiteral escapes the LIKE escape character itself before the
	 * wildcards, so its own escapes are never escaped a second time.
	 */
	@IsTest
	private static void shouldEscapeBackslashBeforeWildcardsInContainsLiteral()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD);
			condition.containsLiteral(BACKSLASH_SEARCH_TERM);

			condition.toSoql(registry);

			Assert.areEqual(ESCAPED_BACKSLASH_PATTERN, registry.getMap().values()[0], 'Should escape the backslash before the wildcard');
		}
	}

	/**
	 * @description Tests that containsLiteral composes the same pattern contains does for a null
	 * value, so the escape never turns a null term into a runtime failure.
	 */
	@IsTest
	private static void shouldComposeTheSamePatternAsContainsForNullValue()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.FieldCondition literalCondition = new QRY_Condition.FieldCondition(TEST_FIELD);
			literalCondition.containsLiteral(null);
			QRY_Condition.FieldCondition wildcardCondition = new QRY_Condition.FieldCondition(TEST_FIELD);
			wildcardCondition.contains(null);

			Assert.areEqual(wildcardCondition.toSoql(), literalCondition.toSoql(), 'Should match contains for a null value');
		}
	}

	/**
	 * @description Tests against real rows that containsLiteral matches an underscore literally where
	 * contains keeps it as the single-character wildcard.
	 */
	@IsTest
	private static void containsLiteralShouldMatchUnderscoreLiterally()
	{
		System.runAs(getTestAdmin())
		{
			seedFoobarNamed(UNDERSCORE_MATCH_VALUE);
			seedFoobarNamed(UNDERSCORE_DECOY_VALUE);

			List<SObject> literalMatches = findFoobarByName(new QRY_Condition.FieldCondition(Foobar__c.Name).containsLiteral(UNDERSCORE_SEARCH_TERM));
			List<SObject> wildcardMatches = findFoobarByName(new QRY_Condition.FieldCondition(Foobar__c.Name).contains(UNDERSCORE_SEARCH_TERM));

			Assert.areEqual(2, wildcardMatches.size(), 'contains should keep the underscore as a wildcard and match both rows');
			Assert.areEqual(1, literalMatches.size(), 'containsLiteral should match only the row holding a literal underscore');
			Assert.areEqual(UNDERSCORE_MATCH_VALUE, ((Foobar__c)literalMatches[0]).Name, 'containsLiteral should match the literal row, not the decoy');
		}
	}

	/**
	 * @description Tests against real rows that containsLiteral matches a percent sign literally where
	 * contains keeps it as the multiple-character wildcard.
	 */
	@IsTest
	private static void containsLiteralShouldMatchPercentSignLiterally()
	{
		System.runAs(getTestAdmin())
		{
			seedFoobarNamed(WILDCARD_MATCH_VALUE);
			seedFoobarNamed(WILDCARD_DECOY_VALUE);

			List<SObject> literalMatches = findFoobarByName(new QRY_Condition.FieldCondition(Foobar__c.Name).containsLiteral(WILDCARD_SEARCH_TERM));
			List<SObject> wildcardMatches = findFoobarByName(new QRY_Condition.FieldCondition(Foobar__c.Name).contains(WILDCARD_SEARCH_TERM));

			Assert.areEqual(2, wildcardMatches.size(), 'contains should keep the percent sign as a wildcard and match both rows');
			Assert.areEqual(1, literalMatches.size(), 'containsLiteral should match only the row holding a literal percent sign');
			Assert.areEqual(WILDCARD_MATCH_VALUE, ((Foobar__c)literalMatches[0]).Name, 'containsLiteral should match the literal row, not the decoy');
		}
	}

	/**
	 * @description Inserts one Foobar__c record carrying the supplied name, so the literal-match tests
	 * run against real rows rather than a generated SOQL string. The searched field is Name rather
	 * than Text__c because the Foobar__c before-insert trigger action overwrites Text__c with a fixed
	 * value whenever a test is running, which would leave every seeded row identical.
	 *
	 * @param nameValue The value to store in Name.
	 */
	private static void seedFoobarNamed(String nameValue)
	{
		TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, nameValue).build();
	}

	/**
	 * @description Runs a condition through the full query pipeline, selecting Name so the caller can
	 * assert which row matched.
	 *
	 * @param condition The condition to apply.
	 *
	 * @return The matching records.
	 */
	private static List<SObject> findFoobarByName(QRY_Condition.Evaluable condition)
	{
		return QRY_Builder.selectFrom(Foobar__c.SObjectType).addField(Foobar__c.Name).addCondition(condition).toList();
	}

	/**
	 * @description Tests that FieldCondition with SObjectField generates correct SOQL.
	 */
	@IsTest
	private static void shouldGenerateConditionWithSObjectField()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(Account.Name);
			condition.equals(TEST_VALUE);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('Name = '), 'Should contain field name');
		}
	}

	/**
	 * @description Tests that FieldCondition constructor with SObjectField and value works.
	 */
	@IsTest
	private static void shouldCreateConditionWithSObjectFieldAndValue()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(Account.Name, TEST_VALUE);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('Name = '), 'Should contain field and equals operator');
		}
	}

	/**
	 * @description Tests that FieldCondition constructor with SObjectField, operator, and value works.
	 */
	@IsTest
	private static void shouldCreateConditionWithSObjectFieldOperatorAndValue()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition
					(
							Account.Name,
							QRY_Condition.Operator.NOT_EQUALS,
							TEST_VALUE
					);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('Name != '), 'Should contain not equals operator');
		}
	}

	/**
	 * @description Tests that FieldCondition with null value generates correct SOQL.
	 */
	@IsTest
	private static void shouldGenerateConditionWithNullValue()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD, null);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('NULL'), 'Should contain NULL literal');
		}
	}

	/**
	 * @description Tests that FieldCondition throws exception for empty field.
	 */
	@IsTest
	private static void shouldThrowExceptionForEmptyField()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				new QRY_Condition.FieldCondition('');
				Assert.fail('Should throw exception for empty field');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that FieldCondition throws exception for invalid operator.
	 */
	@IsTest
	private static void shouldThrowExceptionForInvalidOperator()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				new QRY_Condition.FieldCondition(TEST_FIELD, QRY_Condition.Operator.IN_X, TEST_VALUE);
				Assert.fail('Should throw exception for set operator used in field condition');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that SetCondition IN generates correct SOQL.
	 */
	@IsTest
	private static void shouldGenerateInCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Status');
			condition.inX(new List<Object> {'Open', 'Pending'});

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('Status IN'), 'Should contain IN operator');
			Assert.isTrue(soql.contains('Open'), 'Should contain value');
		}
	}

	/**
	 * @description Tests that SetCondition NOT IN generates correct SOQL.
	 */
	@IsTest
	private static void shouldGenerateNotInCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Status');
			condition.notIn(new List<Object> {'Closed', 'Cancelled'});

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('Status NOT IN'), 'Should contain NOT IN operator');
		}
	}

	/**
	 * @description Tests that SetCondition INCLUDES generates correct SOQL.
	 */
	@IsTest
	private static void shouldGenerateIncludesCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Topics');
			condition.includes(new List<Object> {'Security', 'Privacy'});

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('INCLUDES'), 'Should contain INCLUDES operator');
		}
	}

	/**
	 * @description Tests that SetCondition EXCLUDES generates correct SOQL.
	 */
	@IsTest
	private static void shouldGenerateExcludesCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Topics');
			condition.excludes(new List<Object> {'Marketing'});

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('EXCLUDES'), 'Should contain EXCLUDES operator');
		}
	}

	/**
	 * @description Tests that SetCondition constructor with operator and list works.
	 */
	@IsTest
	private static void shouldCreateSetConditionWithOperatorAndList()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition
					(
							'Status',
							QRY_Condition.Operator.IN_X,
							new List<Object> {'Active'}
					);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('Status IN'), 'Should contain IN operator');
		}
	}

	/**
	 * @description Tests that SetCondition constructor with operator and set works.
	 */
	@IsTest
	private static void shouldCreateSetConditionWithOperatorAndSet()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition
					(
							'Status',
							QRY_Condition.Operator.IN_X,
							new Set<Object> {'Active', 'Pending'}
					);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('Status IN'), 'Should contain IN operator');
		}
	}

	/**
	 * @description Tests that SetCondition throws exception for empty field.
	 */
	@IsTest
	private static void shouldThrowExceptionForEmptySetConditionField()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				new QRY_Condition.SetCondition('');
				Assert.fail('Should throw exception for empty field');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that SetCondition throws exception for empty values.
	 */
	@IsTest
	private static void shouldThrowExceptionForEmptyValues()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Status');
				condition.inX(new List<Object>());
				Assert.fail('Should throw exception for empty values');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that SetCondition throws exception for invalid operator.
	 */
	@IsTest
	private static void shouldThrowExceptionForInvalidSetOperator()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				new QRY_Condition.SetCondition('Status', QRY_Condition.Operator.EQUALS, new List<Object> {'Active'});
				Assert.fail('Should throw exception for simple operator used in set condition');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that SetCondition throws exception when no operator is set.
	 */
	@IsTest
	private static void shouldThrowExceptionWhenNoOperatorSet()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Status');
				condition.toSoql();
				Assert.fail('Should throw exception when no operator set');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that SetCondition throws exception for non-collection value.
	 */
	@IsTest
	private static void shouldThrowExceptionForNonCollectionValue()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				new QRY_Condition.SetCondition('Status', QRY_Condition.Operator.IN_X, (Object)'NotACollection');
				Assert.fail('Should throw exception for non-collection value');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that AndCondition generates correct SOQL.
	 */
	@IsTest
	private static void shouldGenerateAndCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.AndCondition condition = new QRY_Condition.AndCondition();
			condition.add(new QRY_Condition.FieldCondition('Status', 'Active'));
			condition.add(new QRY_Condition.FieldCondition('Type', 'Customer'));

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('AND'), 'Should contain AND separator');
			Assert.isTrue(soql.startsWith('('), 'Should be wrapped in parentheses');
			Assert.isTrue(soql.endsWith(')'), 'Should be wrapped in parentheses');
		}
	}

	/**
	 * @description Tests that OrCondition generates correct SOQL.
	 */
	@IsTest
	private static void shouldGenerateOrCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.OrCondition condition = new QRY_Condition.OrCondition();
			condition.add(new QRY_Condition.FieldCondition('Status', 'Active'));
			condition.add(new QRY_Condition.FieldCondition('Status', 'Pending'));

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('OR'), 'Should contain OR separator');
		}
	}

	/**
	 * @description Tests that NotCondition generates correct SOQL.
	 */
	@IsTest
	private static void shouldGenerateNotCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.NotCondition condition = new QRY_Condition.NotCondition
					(
							new QRY_Condition.FieldCondition('Status', 'Closed')
					);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('NOT'), 'Should contain NOT operator');
			Assert.isTrue(soql.contains('Status'), 'Should contain field');
		}
	}

	/**
	 * @description Tests that NotCondition with null returns empty string.
	 */
	@IsTest
	private static void shouldReturnEmptyForNullNotCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.NotCondition condition = new QRY_Condition.NotCondition();

			String soql = condition.toSoql();

			Assert.areEqual('', soql, 'Should return empty string for null condition');
		}
	}

	/**
	 * @description Tests that NotCondition add method works.
	 */
	@IsTest
	private static void shouldAddConditionToNotCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.NotCondition condition = new QRY_Condition.NotCondition();
			condition.add(new QRY_Condition.FieldCondition('Status', 'Closed'));

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('NOT'), 'Should contain NOT operator after add');
		}
	}

	/**
	 * @description Tests nested condition groups.
	 */
	@IsTest
	private static void shouldGenerateNestedConditions()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.OrCondition statusCondition = new QRY_Condition.OrCondition();
			statusCondition.add(new QRY_Condition.FieldCondition('Status', 'Active'));
			statusCondition.add(new QRY_Condition.FieldCondition('Status', 'Pending'));

			QRY_Condition.AndCondition mainCondition = new QRY_Condition.AndCondition();
			mainCondition.add(new QRY_Condition.FieldCondition('Type', 'Customer'));
			mainCondition.add(statusCondition);

			String soql = mainCondition.toSoql();

			Assert.isTrue(soql.contains('AND'), 'Should contain AND');
			Assert.isTrue(soql.contains('OR'), 'Should contain nested OR');
		}
	}

	/**
	 * @description Tests empty condition group returns empty string.
	 */
	@IsTest
	private static void shouldReturnEmptyForEmptyConditionGroup()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.AndCondition condition = new QRY_Condition.AndCondition();

			String soql = condition.toSoql();

			Assert.areEqual('', soql, 'Should return empty string for empty group');
		}
	}

	/**
	 * @description Tests that condition group ignores null conditions.
	 */
	@IsTest
	private static void shouldIgnoreNullInConditionGroup()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.AndCondition condition = new QRY_Condition.AndCondition();
			condition.add(null);
			condition.add(new QRY_Condition.FieldCondition('Status', 'Active'));

			String soql = condition.toSoql();

			Assert.isFalse(soql.contains('AND'), 'Should not contain AND with single condition');
			Assert.isTrue(soql.contains('Status'), 'Should contain the non-null condition');
		}
	}

	/**
	 * @description Tests FieldCondition with bind registry.
	 */
	@IsTest
	private static void shouldGenerateFieldConditionWithBinds()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD, TEST_VALUE);

			String soql = condition.toSoql(registry);

			Assert.isTrue(soql.contains(':b'), 'Should contain bind reference');
			Assert.areEqual(1, registry.size(), 'Should have one bind variable');
		}
	}

	/**
	 * @description Tests SetCondition with bind registry.
	 */
	@IsTest
	private static void shouldGenerateSetConditionWithBinds()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Status');
			condition.inX(new List<Object> {'Active', 'Pending'});

			String soql = condition.toSoql(registry);

			Assert.isTrue(soql.contains(':b'), 'Should contain bind reference');
		}
	}

	/**
	 * @description Tests that a list of dates reaches the query as one bound list of dates, so the query text holds only a
	 * bind reference and both dates travel in the bind map.
	 */
	@IsTest
	private static void shouldBindADateListAsListOfDate()
	{
		System.runAs(getTestAdmin())
		{
			String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Date__c);
			List<Date> dates = new List<Date> {Date.newInstance(2026, 3, 1), Date.newInstance(2026, 3, 2)};
			QRY_BindRegistry registry = new QRY_BindRegistry();

			String soql = new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, new List<Object> {dates[0], dates[1]}).toSoql(registry);

			Object bound = registry.getMap().get(FIRST_BIND_NAME);
			Assert.areEqual(fieldName + ' IN :' + FIRST_BIND_NAME, soql, 'Expected a bind reference in the query text');
			Assert.areEqual('List<Date>', UTIL_System.getRuntimeTypeName(bound), 'Expected the dates bound as a list of dates');
			Assert.areEqual(dates, bound, 'Expected both dates in the bound list');
		}
	}

	/**
	 * @description Tests that a list of date and time values reaches the query as one bound list of Datetime values.
	 */
	@IsTest
	private static void shouldBindADatetimeListAsListOfDatetime()
	{
		System.runAs(getTestAdmin())
		{
			String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Datetime__c);
			List<Datetime> moments = new List<Datetime> {Datetime.newInstanceGmt(2026, 3, 1, 9, 30, 0), Datetime.newInstanceGmt(2026, 3, 1, 10, 30, 0)};
			QRY_BindRegistry registry = new QRY_BindRegistry();

			String soql = new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, new List<Object> {moments[0], moments[1]}).toSoql(registry);

			Object bound = registry.getMap().get(FIRST_BIND_NAME);
			Assert.areEqual(fieldName + ' IN :' + FIRST_BIND_NAME, soql, 'Expected a bind reference in the query text');
			Assert.areEqual('List<Datetime>', UTIL_System.getRuntimeTypeName(bound), 'Expected the values bound as a list of Datetime values');
			Assert.areEqual(moments, bound, 'Expected both values in the bound list');
		}
	}

	/**
	 * @description Tests that a list of true or false values reaches the query as one bound list of Boolean values.
	 */
	@IsTest
	private static void shouldBindABooleanListAsListOfBoolean()
	{
		System.runAs(getTestAdmin())
		{
			String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Checkbox__c);
			QRY_BindRegistry registry = new QRY_BindRegistry();

			String soql = new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, new List<Object> {true}).toSoql(registry);

			Object bound = registry.getMap().get(FIRST_BIND_NAME);
			Assert.areEqual(fieldName + ' IN :' + FIRST_BIND_NAME, soql, 'Expected a bind reference in the query text');
			Assert.areEqual('List<Boolean>', UTIL_System.getRuntimeTypeName(bound), 'Expected the value bound as a list of Boolean values');
			Assert.areEqual(new List<Boolean> {true}, bound, 'Expected the value in the bound list');
		}
	}

	/**
	 * @description Tests that whole numbers given as an Integer, a Long and a Decimal with a zero fraction are bound as one
	 * list of Integer values. Some query columns, such as COUNT() and CALENDAR_YEAR(), accept only a list of Integer values.
	 */
	@IsTest
	private static void shouldBindWholeNumbersInIntegerRangeAsListOfInteger()
	{
		System.runAs(getTestAdmin())
		{
			String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.NumberInteger__c);
			QRY_BindRegistry registry = new QRY_BindRegistry();

			String soql = new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, new List<Object> {1, 2L, 3.0}).toSoql(registry);

			Object bound = registry.getMap().get(FIRST_BIND_NAME);
			Assert.areEqual(fieldName + ' IN :' + FIRST_BIND_NAME, soql, 'Expected a bind reference in the query text');
			Assert.areEqual('List<Integer>', UTIL_System.getRuntimeTypeName(bound), 'Expected the whole numbers bound as a list of Integer values');
			Assert.areEqual(new List<Integer> {1, 2, 3}, bound, 'Expected the three numbers in the bound list');
		}
	}

	/**
	 * @description Tests that a list holding a number with a fraction, or a whole number too large for an Integer, is bound as
	 * one list of Decimal values.
	 */
	@IsTest
	private static void shouldBindOtherNumbersAsListOfDecimal()
	{
		System.runAs(getTestAdmin())
		{
			String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.NumberDecimal__c);
			Decimal largeValue = Decimal.valueOf('123456789012');
			QRY_BindRegistry registry = new QRY_BindRegistry();

			String soql = new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, new List<Object> {largeValue, 2.5}).toSoql(registry);

			Object bound = registry.getMap().get(FIRST_BIND_NAME);
			Assert.areEqual(fieldName + ' IN :' + FIRST_BIND_NAME, soql, 'Expected a bind reference in the query text');
			Assert.areEqual('List<Decimal>', UTIL_System.getRuntimeTypeName(bound), 'Expected the numbers bound as a list of Decimal values');
			Assert.areEqual(new List<Decimal> {largeValue, 2.5}, bound, 'Expected both numbers in the bound list');
		}
	}

	/**
	 * @description Tests the edge of the Integer range: the largest Integer is bound as a list of Integer values, and the next
	 * whole number up is bound as a list of Decimal values.
	 */
	@IsTest
	private static void shouldBindALargeWholeNumberAsListOfDecimal()
	{
		System.runAs(getTestAdmin())
		{
			String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.NumberDecimal__c);
			QRY_BindRegistry aboveRangeRegistry = new QRY_BindRegistry();
			QRY_BindRegistry inRangeRegistry = new QRY_BindRegistry();

			new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, new List<Object> {FIRST_NUMBER_ABOVE_INTEGER_RANGE}).toSoql(aboveRangeRegistry);
			new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, new List<Object> {LARGEST_INTEGER}).toSoql(inRangeRegistry);

			Object aboveRange = aboveRangeRegistry.getMap().get(FIRST_BIND_NAME);
			Object inRange = inRangeRegistry.getMap().get(FIRST_BIND_NAME);
			Assert.areEqual('List<Decimal>', UTIL_System.getRuntimeTypeName(aboveRange), 'Expected a number above the Integer range bound as a list of Decimal values');
			Assert.areEqual(new List<Decimal> {FIRST_NUMBER_ABOVE_INTEGER_RANGE}, aboveRange, 'Expected the large number in the bound list');
			Assert.areEqual('List<Integer>', UTIL_System.getRuntimeTypeName(inRange), 'Expected the largest Integer bound as a list of Integer values');
			Assert.areEqual(new List<Integer> {LARGEST_INTEGER}, inRange, 'Expected the largest Integer in the bound list');
		}
	}

	/**
	 * @description Tests the lower edge of the Integer range: the smallest Integer is bound as a list of Integer values, and
	 * the next whole number down is bound as a list of Decimal values.
	 */
	@IsTest
	private static void shouldBindASmallWholeNumberAsListOfDecimal()
	{
		System.runAs(getTestAdmin())
		{
			String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.NumberDecimal__c);
			QRY_BindRegistry belowRangeRegistry = new QRY_BindRegistry();
			QRY_BindRegistry inRangeRegistry = new QRY_BindRegistry();

			new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, new List<Object> {FIRST_NUMBER_BELOW_INTEGER_RANGE}).toSoql(belowRangeRegistry);
			new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, new List<Object> {SMALLEST_INTEGER}).toSoql(inRangeRegistry);

			Object belowRange = belowRangeRegistry.getMap().get(FIRST_BIND_NAME);
			Object inRange = inRangeRegistry.getMap().get(FIRST_BIND_NAME);
			Assert.areEqual('List<Decimal>', UTIL_System.getRuntimeTypeName(belowRange), 'Expected a number below the Integer range bound as a list of Decimal values');
			Assert.areEqual(new List<Decimal> {FIRST_NUMBER_BELOW_INTEGER_RANGE}, belowRange, 'Expected the small number in the bound list');
			Assert.areEqual('List<Integer>', UTIL_System.getRuntimeTypeName(inRange), 'Expected the smallest Integer bound as a list of Integer values');
			Assert.areEqual(new List<Integer> {SMALLEST_INTEGER}, inRange, 'Expected the smallest Integer in the bound list');
		}
	}

	/**
	 * @description Tests that record Ids given as text inside a List<Object> are bound as one list of Id values, and that
	 * the query finds the records. One Id is written with 18 characters and one with 15. The bound list holds each one
	 * as an Id value, so the 15-character Id becomes the full 18-character Id, and the query finds both records.
	 */
	@IsTest
	private static void shouldBindIdTextInAnObjectListAsListOfId()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c firstRecord = TST_Factory.insertFoobar();
			Foobar__c secondRecord = TST_Factory.insertFoobar();
			TST_Factory.insertFoobar();
			List<Object> idTexts = new List<Object> {String.valueOf(firstRecord.Id), String.valueOf(secondRecord.Id).left(SHORT_ID_LENGTH)};
			String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Id);
			QRY_BindRegistry registry = new QRY_BindRegistry();

			String soql = new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, idTexts).toSoql(registry);
			List<Foobar__c> matched = QRY_Builder.selectFrom(Foobar__c.SObjectType).condition(Foobar__c.Id).isIn(idTexts).toList();

			Object bound = registry.getMap().get(FIRST_BIND_NAME);
			Assert.areEqual(fieldName + ' IN :' + FIRST_BIND_NAME, soql, 'Expected a bind reference in the query text');
			Assert.areEqual('List<Id>', UTIL_System.getRuntimeTypeName(bound), 'Expected the Id text bound as a list of Id values');
			Assert.areEqual(idTexts.size(), ((List<Id>)bound).size(), 'Expected both Ids in the bound list');
			Assert.areEqual(firstRecord.Id, ((List<Id>)bound)[0], 'Expected the 18-character Id first in the bound list');
			Assert.areEqual(String.valueOf(secondRecord.Id), String.valueOf(((List<Id>)bound)[1]), 'Expected the 15-character Id held as the full 18-character Id');
			Assert.areEqual(new Set<Id> {firstRecord.Id, secondRecord.Id}, new Map<Id, Foobar__c>(matched).keySet(), 'Expected the query to find the two records');
		}
	}

	/**
	 * @description Tests that a list holding a value a query condition cannot use, such as a Time, is refused with an
	 * IllegalArgumentException that names the type. The Time comes after a text value the condition can use, so the
	 * whole list is checked, not only its first value. Such a list cannot be bound, and it cannot be written into the query
	 * text either, so it must not reach the database.
	 */
	@IsTest
	private static void shouldRefuseAListHoldingAValueAQueryCannotUse()
	{
		System.runAs(getTestAdmin())
		{
			String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name);
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, new List<Object> {'a', NINE_IN_THE_MORNING});

			try
			{
				condition.toSoql(new QRY_BindRegistry());
				Assert.fail('Expected a list holding a Time to be refused');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException, got: ' + error);
				String expectedStart = UNSUPPORTED_LITERAL_MESSAGE_START + Time.class.getName();
				Assert.isTrue(error.getMessage().startsWith(expectedStart), 'Expected the error to name the Time type: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Tests that a list mixing a number and a date is written into the query as literals, and nothing is bound.
	 */
	@IsTest
	private static void shouldKeepLiteralsForAMixedKindList()
	{
		System.runAs(getTestAdmin())
		{
			String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Date__c);
			QRY_BindRegistry registry = new QRY_BindRegistry();

			String soql = new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, new List<Object> {1, Date.newInstance(2026, 3, 1)}).toSoql(registry);

			Assert.areEqual(fieldName + ' IN (1' + UTIL_String.COMMA + '2026-03-01)', soql, 'Expected the mixed list written as literals');
			Assert.isTrue(registry.isEmpty(), 'Expected nothing in the bind map');
		}
	}

	/**
	 * @description Tests that a list holding only a blank value is written into the query as the NULL literal, and nothing is
	 * bound.
	 */
	@IsTest
	private static void shouldKeepLiteralsForAnAllNullList()
	{
		System.runAs(getTestAdmin())
		{
			String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Date__c);
			QRY_BindRegistry registry = new QRY_BindRegistry();

			String soql = new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, new List<Object> {null}).toSoql(registry);

			Assert.areEqual(fieldName + ' IN (NULL)', soql, 'Expected the blank value written as the NULL literal');
			Assert.isTrue(registry.isEmpty(), 'Expected nothing in the bind map');
		}
	}

	/**
	 * @description Tests that a very small fractional value is written as plain digits, never with an exponent such as 1E-9,
	 * which the query parser rejects. It checks a Decimal through the query text and a Double through the literal method.
	 */
	@IsTest
	private static void shouldRenderATinyDecimalLiteralWithoutAnExponent()
	{
		System.runAs(getTestAdmin())
		{
			String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Percent__c);
			Double tiny = 0.000000001;

			String soql = new QRY_Condition.SetCondition(fieldName, QRY_Condition.Operator.IN_X, new List<Object> {Decimal.valueOf(TINY_DECIMAL_TEXT)}).toSoql();
			String doubleLiteral = QRY_Condition.toLiteral(tiny, QRY_Condition.DEFAULT_OPTIONS);

			String insideParentheses = soql.substringBetween('(', ')');
			Assert.isTrue(insideParentheses.contains(TINY_DECIMAL_TEXT), 'Expected the Decimal written as plain digits: ' + soql);
			Assert.isFalse(insideParentheses.contains(EXPONENT_MARKER), 'Expected no exponent in the Decimal literal: ' + soql);
			Assert.isTrue(doubleLiteral.contains(TINY_DECIMAL_TEXT), 'Expected the Double written as plain digits: ' + doubleLiteral);
			Assert.isFalse(doubleLiteral.contains(EXPONENT_MARKER), 'Expected no exponent in the Double literal: ' + doubleLiteral);
		}
	}

	/**
	 * @description Tests AndCondition with bind registry.
	 */
	@IsTest
	private static void shouldGenerateAndConditionWithBinds()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.AndCondition condition = new QRY_Condition.AndCondition();
			condition.add(new QRY_Condition.FieldCondition('Status', 'Active'));
			condition.add(new QRY_Condition.FieldCondition('Type', 'Customer'));

			String soql = condition.toSoql(registry);

			Assert.isTrue(soql.contains(':b'), 'Should contain bind references');
			Assert.areEqual(2, registry.size(), 'Should have two bind variables');
		}
	}

	/**
	 * @description Tests NotCondition with bind registry.
	 */
	@IsTest
	private static void shouldGenerateNotConditionWithBinds()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.NotCondition condition = new QRY_Condition.NotCondition
					(
							new QRY_Condition.FieldCondition('Status', 'Closed')
					);

			String soql = condition.toSoql(registry);

			Assert.isTrue(soql.contains('NOT'), 'Should contain NOT');
			Assert.isTrue(soql.contains(':b'), 'Should contain bind reference');
		}
	}

	/**
	 * @description Tests operator to string conversion.
	 */
	@IsTest
	private static void shouldConvertOperatorToString()
	{
		System.runAs(getTestAdmin())
		{
			Assert.areEqual('=', QRY_Condition.operatorToString(QRY_Condition.Operator.EQUALS), 'EQUALS should be =');
			Assert.areEqual('!=', QRY_Condition.operatorToString(QRY_Condition.Operator.NOT_EQUALS), 'NOT_EQUALS should be !=');
			Assert.areEqual('<', QRY_Condition.operatorToString(QRY_Condition.Operator.LESS_THAN), 'LESS_THAN should be <');
			Assert.areEqual('<=', QRY_Condition.operatorToString(QRY_Condition.Operator.LESS_THAN_OR_EQUAL_TO), 'LESS_THAN_OR_EQUAL_TO should be <=');
			Assert.areEqual('>', QRY_Condition.operatorToString(QRY_Condition.Operator.GREATER_THAN), 'GREATER_THAN should be >');
			Assert.areEqual('>=', QRY_Condition.operatorToString(QRY_Condition.Operator.GREATER_THAN_OR_EQUAL_TO), 'GREATER_THAN_OR_EQUAL_TO should be >=');
			Assert.areEqual('LIKE', QRY_Condition.operatorToString(QRY_Condition.Operator.LIKE_X), 'LIKE_X should be LIKE');
			Assert.areEqual('IN', QRY_Condition.operatorToString(QRY_Condition.Operator.IN_X), 'IN_X should be IN');
			Assert.areEqual('NOT IN', QRY_Condition.operatorToString(QRY_Condition.Operator.NOT_IN), 'NOT_IN should be NOT IN');
			Assert.areEqual('INCLUDES', QRY_Condition.operatorToString(QRY_Condition.Operator.INCLUDES), 'INCLUDES should be INCLUDES');
			Assert.areEqual('EXCLUDES', QRY_Condition.operatorToString(QRY_Condition.Operator.EXCLUDES), 'EXCLUDES should be EXCLUDES');
		}
	}

	/**
	 * @description Tests SoqlOptions defaults.
	 */
	@IsTest
	private static void shouldHaveCorrectDefaultOptions()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.SoqlOptions options = new QRY_Condition.SoqlOptions();

			Assert.isTrue(options.escapeSingleQuotes, 'Should escape single quotes by default');
			Assert.isFalse(options.wildcardStringsInLikeOperators, 'Should not add wildcards by default');
		}
	}

	/**
	 * @description Tests default constructor for FieldCondition.
	 */
	@IsTest
	private static void shouldCreateEmptyFieldCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition();
			condition.field(TEST_FIELD);
			condition.equals(TEST_VALUE);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('Name = '), 'Should contain field and operator');
		}
	}

	/**
	 * @description Tests default constructor for SetCondition.
	 */
	@IsTest
	private static void shouldCreateEmptySetCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition();
			condition.field('Status');
			condition.inX(new List<Object> {'Active'});

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('Status IN'), 'Should contain field and operator');
		}
	}

	/**
	 * @description Tests SetCondition with QRY_Generator for subquery.
	 */
	@IsTest
	private static void shouldGenerateSetConditionWithSubquery()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Generator subquery = new QRY_Generator()
					.selectX('AccountId')
					.fromX('Contact');

			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition
					(
							'Id',
							QRY_Condition.Operator.IN_X,
							subquery
					);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('Id IN'), 'Should contain IN operator');
			Assert.isTrue(soql.contains('SELECT'), 'Should contain subquery');
		}
	}

	/**
	 * @description Tests SetCondition throws for null builder.
	 */
	@IsTest
	private static void shouldThrowExceptionForNullBuilder()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Id');
				condition.inX((QRY_Generator)null);
				Assert.fail('Should throw exception for null builder');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests SetCondition includes with builder.
	 */
	@IsTest
	private static void shouldGenerateIncludesWithSubquery()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Generator subquery = new QRY_Generator()
					.selectX('AccountId')
					.fromX('Contact');

			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Id');
			condition.includes(subquery);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('INCLUDES'), 'Should contain INCLUDES operator');
		}
	}

	/**
	 * @description Tests SetCondition excludes with builder.
	 */
	@IsTest
	private static void shouldGenerateExcludesWithSubquery()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Generator subquery = new QRY_Generator()
					.selectX('AccountId')
					.fromX('Contact');

			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Id');
			condition.excludes(subquery);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('EXCLUDES'), 'Should contain EXCLUDES operator');
		}
	}

	/**
	 * @description Tests SetCondition notIn with builder.
	 */
	@IsTest
	private static void shouldGenerateNotInWithSubquery()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Generator subquery = new QRY_Generator()
					.selectX('AccountId')
					.fromX('Contact');

			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Id');
			condition.notIn(subquery);

			String soql = condition.toSoql();

			Assert.isTrue(soql.contains('NOT IN'), 'Should contain NOT IN operator');
		}
	}

	/**
	 * @description Tests FieldCondition with wildcardStringsInLikeOperators option enabled.
	 */
	@IsTest
	private static void shouldAddWildcardsInLikeCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.SoqlOptions options = new QRY_Condition.SoqlOptions();
			options.wildcardStringsInLikeOperators = true;

			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD);
			condition.likeX('Test');

			String soql = condition.toSoql(options);

			Assert.isTrue(soql.contains('%Test%'), 'Should add wildcards to LIKE value');
		}
	}

	/**
	 * @description Tests FieldCondition with wildcardStringsInLikeOperators using bind registry.
	 */
	@IsTest
	private static void shouldAddWildcardsInLikeConditionWithBinds()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.SoqlOptions options = new QRY_Condition.SoqlOptions();
			options.wildcardStringsInLikeOperators = true;

			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD);
			condition.likeX('Test');

			String soql = condition.toSoql(registry, options);

			Assert.isTrue(soql.contains('LIKE'), 'Should contain LIKE operator');
			Assert.isTrue(soql.contains(':b'), 'Should contain bind reference');
		}
	}

	/**
	 * @description Tests FieldCondition with null value using bind registry.
	 */
	@IsTest
	private static void shouldGenerateNullLiteralWithBinds()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(TEST_FIELD, null);

			String soql = condition.toSoql(registry);

			Assert.isTrue(soql.contains('null'), 'Should contain null literal');
			Assert.areEqual(0, registry.size(), 'Should not register null as bind variable');
		}
	}

	/**
	 * @description Tests SetCondition with subquery using bind registry.
	 */
	@IsTest
	private static void shouldGenerateSetConditionWithSubqueryAndBinds()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Generator subquery = new QRY_Generator()
					.selectX('AccountId')
					.fromX('Contact')
					.whereX(new QRY_Condition.FieldCondition('LastName', 'Test'));

			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition
					(
							'Id',
							QRY_Condition.Operator.IN_X,
							subquery
					);

			String soql = condition.toSoql(registry);

			Assert.isTrue(soql.contains('Id IN'), 'Should contain IN operator');
			Assert.isTrue(soql.contains('SELECT'), 'Should contain subquery');
		}
	}

	/**
	 * @description Tests SetCondition with INCLUDES operator and bind registry (should use literals).
	 */
	@IsTest
	private static void shouldNotBindIncludesValues()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Topics');
			condition.includes(new List<Object> {'Security', 'Privacy'});

			String soql = condition.toSoql(registry);

			Assert.isTrue(soql.contains('INCLUDES'), 'Should contain INCLUDES operator');
			Assert.isFalse(soql.contains(':b'), 'Should not use bind for INCLUDES');
		}
	}

	/**
	 * @description Tests SetCondition with EXCLUDES operator and bind registry (should use literals).
	 */
	@IsTest
	private static void shouldNotBindExcludesValues()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Topics');
			condition.excludes(new List<Object> {'Marketing'});

			String soql = condition.toSoql(registry);

			Assert.isTrue(soql.contains('EXCLUDES'), 'Should contain EXCLUDES operator');
			Assert.isFalse(soql.contains(':b'), 'Should not use bind for EXCLUDES');
		}
	}

	/**
	 * @description Tests SetCondition with Id values and bind registry.
	 */
	@IsTest
	private static void shouldBindIdValuesInSetCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('AccountId');
			condition.inX(new List<Object> {UserInfo.getUserId()});

			String soql = condition.toSoql(registry);

			Assert.isTrue(soql.contains('AccountId IN'), 'Should contain IN operator');
			Assert.isTrue(soql.contains(':b'), 'Should use bind for Id values');
		}
	}

	/**
	 * @description Tests SetCondition throws when no operator set with bind registry.
	 */
	@IsTest
	private static void shouldThrowExceptionWhenNoOperatorSetWithBinds()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();

			try
			{
				QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Status');
				condition.toSoql(registry);
				Assert.fail('Should throw exception when no operator set');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests NotCondition with null inner condition using bind registry.
	 */
	@IsTest
	private static void shouldReturnEmptyForNullNotConditionWithBinds()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.NotCondition condition = new QRY_Condition.NotCondition();

			String soql = condition.toSoql(registry);

			Assert.areEqual('', soql, 'Should return empty string for null condition');
		}
	}

	/**
	 * @description Tests NotCondition with non-BindAware inner condition.
	 */
	@IsTest
	private static void shouldHandleNonBindAwareInNotCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.NotCondition notCond = new QRY_Condition.NotCondition
					(
							new QRY_Condition.FieldCondition('Status', 'Active')
					);

			String soql = notCond.toSoql(registry);

			Assert.isTrue(soql.contains('NOT'), 'Should contain NOT');
			Assert.isTrue(soql.contains('Status'), 'Should contain field');
		}
	}

	/**
	 * @description Tests ConditionGroup with non-BindAware condition using bind registry.
	 */
	@IsTest
	private static void shouldHandleNonBindAwareInConditionGroup()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.AndCondition andCondition = new QRY_Condition.AndCondition();
			andCondition.add(new QRY_Condition.FieldCondition('Status', 'Active'));

			String soql = andCondition.toSoql(registry);

			Assert.isTrue(soql.contains('Status'), 'Should contain field');
		}
	}

	/**
	 * @description Tests SetCondition with SObject values.
	 */
	@IsTest
	private static void shouldBindSObjectValuesInSetCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			Foobar__c mockRecord = TST_Factory.newFoobarWithName('Test');
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Lookup__c');
			condition.inX(new List<Object> {mockRecord});

			String soql = condition.toSoql(registry);

			Assert.isTrue(soql.contains('Lookup__c IN'), 'Should contain IN operator');
		}
	}

	/**
	 * @description Tests SetCondition with mixed null values in collection.
	 */
	@IsTest
	private static void shouldHandleMixedNullValuesInSetCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Status');
			condition.inX(new List<Object> {'Active', null, 'Pending'});

			String soql = condition.toSoql(registry);

			Assert.isTrue(soql.contains('Status IN'), 'Should contain IN operator');
		}
	}

	/**
	 * @description Tests that SetCondition binds a list of numbers with a fraction, rather than writing them into the query
	 * text as literals.
	 */
	@IsTest
	private static void shouldBindDecimalValues()
	{
		System.runAs(getTestAdmin())
		{
			String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.NumberDecimal__c);
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(fieldName);
			condition.inX(new List<Object> {100.5, 200.75});

			String soql = condition.toSoql(registry);

			Object bound = registry.getMap().get(FIRST_BIND_NAME);
			Assert.areEqual(fieldName + ' IN :' + FIRST_BIND_NAME, soql, 'Expected the Decimal values bound, not written as literals');
			Assert.areEqual('List<Decimal>', UTIL_System.getRuntimeTypeName(bound), 'Expected the values bound as a list of Decimal values');
			Assert.areEqual(new List<Decimal> {100.5, 200.75}, bound, 'Expected both values in the bound list');
		}
	}

	/**
	 * @description Tests toLiteral with null value.
	 */
	@IsTest
	private static void shouldConvertNullToLiteral()
	{
		System.runAs(getTestAdmin())
		{
			String literal = QRY_Condition.toLiteral(null, QRY_Condition.DEFAULT_OPTIONS);

			Assert.areEqual('NULL', literal, 'Should return NULL for null value');
		}
	}

	/**
	 * @description Tests toLiteral with String value.
	 */
	@IsTest
	private static void shouldConvertStringToLiteral()
	{
		System.runAs(getTestAdmin())
		{
			String literal = QRY_Condition.toLiteral('acme', QRY_Condition.DEFAULT_OPTIONS);

			Assert.areEqual('\'acme\'', literal, 'Should wrap string in single quotes');
		}
	}

	/**
	 * @description Tests toLiteral escapes single quotes in strings.
	 */
	@IsTest
	private static void shouldEscapeSingleQuotesInStringLiteral()
	{
		System.runAs(getTestAdmin())
		{
			String literal = QRY_Condition.toLiteral('O\'Brien', QRY_Condition.DEFAULT_OPTIONS);

			Assert.isTrue(literal.contains('O\\\'Brien'), 'Should escape single quotes');
		}
	}

	/**
	 * @description Tests toLiteral with escapeSingleQuotes disabled.
	 */
	@IsTest
	private static void shouldNotEscapeWhenOptionDisabled()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.SoqlOptions options = new QRY_Condition.SoqlOptions();
			options.escapeSingleQuotes = false;

			String literal = QRY_Condition.toLiteral('O\'Brien', options);

			Assert.isTrue(literal.contains('O\'Brien'), 'Should not escape when option disabled');
		}
	}

	/**
	 * @description Tests toLiteral with Boolean true value.
	 */
	@IsTest
	private static void shouldConvertBooleanTrueToLiteral()
	{
		System.runAs(getTestAdmin())
		{
			String literal = QRY_Condition.toLiteral(true, QRY_Condition.DEFAULT_OPTIONS);

			Assert.areEqual('TRUE', literal, 'Should return uppercase TRUE');
		}
	}

	/**
	 * @description Tests toLiteral with Boolean false value.
	 */
	@IsTest
	private static void shouldConvertBooleanFalseToLiteral()
	{
		System.runAs(getTestAdmin())
		{
			String literal = QRY_Condition.toLiteral(false, QRY_Condition.DEFAULT_OPTIONS);

			Assert.areEqual('FALSE', literal, 'Should return uppercase FALSE');
		}
	}

	/**
	 * @description Tests toLiteral with Integer value.
	 */
	@IsTest
	private static void shouldConvertIntegerToLiteral()
	{
		System.runAs(getTestAdmin())
		{
			String literal = QRY_Condition.toLiteral(42, QRY_Condition.DEFAULT_OPTIONS);

			Assert.areEqual('42', literal, 'Should convert Integer to string');
		}
	}

	/**
	 * @description Tests toLiteral with Long value.
	 */
	@IsTest
	private static void shouldConvertLongToLiteral()
	{
		System.runAs(getTestAdmin())
		{
			Long longValue = 9999999999L;
			String literal = QRY_Condition.toLiteral(longValue, QRY_Condition.DEFAULT_OPTIONS);

			Assert.areEqual('9999999999', literal, 'Should convert Long to string');
		}
	}

	/**
	 * @description Tests toLiteral with Decimal value.
	 */
	@IsTest
	private static void shouldConvertDecimalToLiteral()
	{
		System.runAs(getTestAdmin())
		{
			Decimal decimalValue = 1.1;
			String literal = QRY_Condition.toLiteral(decimalValue, QRY_Condition.DEFAULT_OPTIONS);

			Assert.areEqual('1.1', literal, 'Should convert Decimal to string');
		}
	}

	/**
	 * @description Tests toLiteral with Double value.
	 */
	@IsTest
	private static void shouldConvertDoubleToLiteral()
	{
		System.runAs(getTestAdmin())
		{
			Double doubleValue = 1.1;
			String literal = QRY_Condition.toLiteral(doubleValue, QRY_Condition.DEFAULT_OPTIONS);

			Assert.areEqual('1.1', literal, 'Should convert Double to string');
		}
	}

	/**
	 * @description Tests toLiteral with SObject value extracts Id.
	 */
	@IsTest
	private static void shouldConvertSObjectToLiteral()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			String literal = QRY_Condition.toLiteral(record, QRY_Condition.DEFAULT_OPTIONS);

			Assert.areEqual('\'' + record.Id + '\'', literal, 'Should extract and quote SObject Id');
		}
	}

	/**
	 * @description Tests toLiteral with SObject with null Id returns NULL.
	 */
	@IsTest
	private static void shouldConvertSObjectWithNullIdToNull()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.newFoobar();

			String literal = QRY_Condition.toLiteral(record, QRY_Condition.DEFAULT_OPTIONS);

			Assert.areEqual('NULL', literal, 'Should return NULL for SObject with no Id');
		}
	}

	/**
	 * @description Tests toLiteralList with mixed primitive values.
	 */
	@IsTest
	private static void shouldConvertMixedPrimitivesToLiteralList()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> values = new List<Object> {1, 'test123', 1.1, true, null};
			List<String> literals = QRY_Condition.toLiteralList(values);

			Assert.areEqual(5, literals.size(), 'Should return five literals');
			Assert.areEqual('1', literals[0], 'Should convert Integer');
			Assert.areEqual('\'test123\'', literals[1], 'Should quote String');
			Assert.areEqual('1.1', literals[2], 'Should convert Decimal');
			Assert.areEqual('TRUE', literals[3], 'Should uppercase Boolean');
			Assert.areEqual('NULL', literals[4], 'Should convert null');
		}
	}

	/**
	 * @description Tests literal String condition executes through full query pipeline.
	 */
	@IsTest
	private static void literalStringConditionExecutes()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();
			record = (Foobar__c)new SEL_Foobar().findById(record.Id);

			List<SObject> results = buildLiteralQuery(Foobar__c.Text__c, record.Text__c);

			Assert.isFalse(results.isEmpty(), 'Literal String query should return results');
		}
	}

	/**
	 * @description Tests literal Boolean condition executes through full query pipeline.
	 */
	@IsTest
	private static void literalBooleanConditionExecutes()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();
			record = (Foobar__c)new SEL_Foobar().findById(record.Id);

			List<SObject> results = buildLiteralQuery(Foobar__c.Checkbox__c, record.Checkbox__c);

			Assert.isFalse(results.isEmpty(), 'Literal Boolean query should return results');
		}
	}

	/**
	 * @description Tests literal Integer condition executes through full query pipeline.
	 */
	@IsTest
	private static void literalIntegerConditionExecutes()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();
			record = (Foobar__c)new SEL_Foobar().findById(record.Id);

			List<SObject> results = buildLiteralQuery(Foobar__c.NumberInteger__c, record.NumberInteger__c);

			Assert.isFalse(results.isEmpty(), 'Literal Integer query should return results');
		}
	}

	/**
	 * @description Tests literal Decimal condition executes through full query pipeline.
	 */
	@IsTest
	private static void literalDecimalConditionExecutes()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();
			record = (Foobar__c)new SEL_Foobar().findById(record.Id);

			List<SObject> results = buildLiteralQuery(Foobar__c.NumberDecimal__c, record.NumberDecimal__c);

			Assert.isFalse(results.isEmpty(), 'Literal Decimal query should return results');
		}
	}

	/**
	 * @description Tests literal Date condition executes through full query pipeline.
	 */
	@IsTest
	private static void literalDateConditionExecutes()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Date__c, Date.today())
					.build();
			record = (Foobar__c)new SEL_Foobar().findById(record.Id);

			List<SObject> results = buildLiteralQuery(Foobar__c.Date__c, record.Date__c);

			Assert.isFalse(results.isEmpty(), 'Literal Date query should return results');
		}
	}

	/**
	 * @description Tests literal Datetime condition executes through full query pipeline.
	 */
	@IsTest
	private static void literalDatetimeConditionExecutes()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.CreatedDate).greaterThan(Datetime.newInstanceGmt(2020, 1, 1, 0, 0, 0));
			builder.useLiterals = true;

			List<SObject> results = builder.toList();

			Assert.isFalse(results.isEmpty(), 'Literal Datetime query should return results');
		}
	}

	/**
	 * @description Tests literal Id condition executes through full query pipeline.
	 */
	@IsTest
	private static void literalIdConditionExecutes()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id);
			builder.useLiterals = true;

			List<SObject> results = builder.toList();

			Assert.areEqual(1, results.size(), 'Literal Id query should return exactly one record');
		}
	}

	/**
	 * @description Executes a literal query through the full QRY_Builder pipeline using
	 * useLiterals mode. Conditions are inlined as SOQL literals instead of bind parameters.
	 *
	 * @param field The SObjectField to filter on.
	 * @param value The value to match.
	 *
	 * @return List of matching SObjects.
	 */
	private static List<SObject> buildLiteralQuery(SObjectField field, Object value)
	{
		QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType)
				.condition(field).equals(value);
		builder.useLiterals = true;
		return builder.toList();
	}

	/**
	 * @description Tests LIKE condition with wildcardStringsInLikeOperators without bind registry.
	 */
	@IsTest
	private static void shouldAddWildcardsToLikeWithoutBindRegistry()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.SoqlOptions options = new QRY_Condition.SoqlOptions();
			options.wildcardStringsInLikeOperators = true;

			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(
					SEL_Foobar.FIELD_TEXT,
					QRY_Condition.Operator.LIKE_X,
					'Test'
			);

			String soql = condition.toSoql(options);

			Assert.isTrue(soql.contains('%Test%'), 'Should add wildcards for LIKE with option enabled');
		}
	}

	/**
	 * @description Tests LIKE condition with wildcardStringsInLikeOperators with bind registry.
	 */
	@IsTest
	private static void shouldAddWildcardsToLikeWithBindRegistry()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.SoqlOptions options = new QRY_Condition.SoqlOptions();
			options.wildcardStringsInLikeOperators = true;
			QRY_BindRegistry registry = new QRY_BindRegistry();

			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(
					SEL_Foobar.FIELD_TEXT,
					QRY_Condition.Operator.LIKE_X,
					'Test'
			);

			String soql = condition.toSoql(registry, options);
			Map<String, Object> binds = registry.getMap();

			Assert.isTrue(soql.contains(':b'), 'Should use bind reference');
			Boolean foundWildcard = false;
			for(Object bindValue : binds.values())
			{
				if(bindValue instanceof String && ((String)bindValue).contains('%Test%'))
				{
					foundWildcard = true;
					break;
				}
			}
			Assert.isTrue(foundWildcard, 'Should add wildcards to bound value');
		}
	}

	/**
	 * @description Tests FieldCondition with null value using bind registry returns null literal.
	 */
	@IsTest
	private static void shouldReturnNullLiteralForNullValueWithBindRegistry()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(
					SEL_Foobar.FIELD_TEXT,
					QRY_Condition.Operator.EQUALS,
					null
			);

			String soql = condition.toSoql(registry);

			Assert.isTrue(soql.contains('= null'), 'Should use null literal for null value with bind registry');
		}
	}

	/**
	 * @description Tests FieldCondition with Soqlable value uses toSoql method.
	 */
	@IsTest
	private static void shouldUseSoqlableToSoqlForSoqlableValue()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			MockSoqlable mockValue = new MockSoqlable('MOCK_VALUE');
			QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition
					(
							SEL_Foobar.FIELD_TEXT,
							QRY_Condition.Operator.EQUALS,
							mockValue
					);

			String soql = condition.toSoql(registry);

			Assert.isTrue(soql.contains('MOCK_VALUE'), 'Should use Soqlable toSoql method');
		}
	}

	/**
	 * @description Mock implementation of Evaluable for testing.
	 */
	private class MockSoqlable implements QRY_Condition.Evaluable
	{
		/**
		 * @description The value to return in toSoql.
		 */
		private final String returnValue;

		/**
		 * @description Constructor with return value.
		 *
		 * @param returnValue The value to return.
		 */
		public MockSoqlable(String returnValue)
		{
			this.returnValue = returnValue;
		}

		/**
		 * @description Returns the configured value.
		 *
		 * @return The SOQL string.
		 */
		public String toSoql()
		{
			return returnValue;
		}

		/**
		 * @description Returns the configured value.
		 *
		 * @param options Ignored.
		 *
		 * @return The SOQL string.
		 */
		public String toSoql(QRY_Condition.SoqlOptions options)
		{
			return returnValue;
		}
	}

	/**
	 * @description Tests SetCondition with Set of values via constructor.
	 */
	@IsTest
	private static void shouldGenerateSetConditionWithSetValues()
	{
		System.runAs(getTestAdmin())
		{
			Set<Object> values = new Set<Object> {'Value1', 'Value2'};
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD, QRY_Condition.Operator.IN_X, values);

			String soql = condition.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('IN'), 'Should contain IN operator');
		}
	}

	/**
	 * @description Tests SetCondition with List of values via constructor.
	 */
	@IsTest
	private static void shouldGenerateSetConditionWithListValues()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> values = new List<Object> {'Value1', 'Value2'};
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD, QRY_Condition.Operator.IN_X, values);

			String soql = condition.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('IN'), 'Should contain IN operator');
		}
	}

	/**
	 * @description Tests that mixed SObject and Id types fall back to untyped binding.
	 */
	@IsTest
	private static void shouldHandleMixedSObjectAndIdTypes()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> mixedValues = new List<Object>
			{
					TST_Factory.newFoobarWithMockId(),
					UTIL_Random.randomId(Foobar__c.SObjectType)
			};

			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD, QRY_Condition.Operator.IN_X, mixedValues);
			QRY_BindRegistry registry = new QRY_BindRegistry();

			String soql = condition.toSoql(registry);

			Assert.isNotNull(soql, 'Should generate SOQL even with mixed types');
		}
	}

	/**
	 * @description Tests that mixed Id and String types fall back to untyped binding.
	 */
	@IsTest
	private static void shouldHandleMixedIdAndStringTypes()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> mixedValues = new List<Object>
			{
					UTIL_Random.randomId(Foobar__c.SObjectType),
					'StringValue'
			};

			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD, QRY_Condition.Operator.IN_X, mixedValues);
			QRY_BindRegistry registry = new QRY_BindRegistry();

			String soql = condition.toSoql(registry);

			Assert.isNotNull(soql, 'Should generate SOQL even with mixed types');
		}
	}

	/**
	 * @description Tests condition group with conditions that produce blank SOQL.
	 */
	@IsTest
	private static void shouldHandleConditionGroupWithBlankSoql()
	{
		System.runAs(getTestAdmin())
		{
			MockSoqlable blankCondition = new MockSoqlable('');
			MockSoqlable validCondition = new MockSoqlable('Name = \'Test\'');

			QRY_Condition.AndCondition condition = new QRY_Condition.AndCondition();
			condition.add(blankCondition);
			condition.add(validCondition);

			String soql = condition.toSoql();

			Assert.areEqual('(Name = \'Test\')', soql, 'Should skip blank conditions');
		}
	}

	/**
	 * @description Tests SetCondition constructor with Set passed as Object.
	 */
	@IsTest
	private static void shouldHandleSetConditionWithSetAsObject()
	{
		System.runAs(getTestAdmin())
		{
			Object setAsObject = new Set<Object> {'Value1', 'Value2'};
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD, QRY_Condition.Operator.IN_X, setAsObject);

			String soql = condition.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('IN'), 'Should contain IN operator');
		}
	}

	/**
	 * @description Tests SetCondition constructor with List passed as Object.
	 */
	@IsTest
	private static void shouldHandleSetConditionWithListAsObject()
	{
		System.runAs(getTestAdmin())
		{
			Object listAsObject = new List<Object> {'Value1', 'Value2'};
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(TEST_FIELD, QRY_Condition.Operator.IN_X, listAsObject);

			String soql = condition.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('IN'), 'Should contain IN operator');
		}
	}

	/**
	 * @description Tests toLiteral with Date value.
	 */
	@IsTest
	private static void shouldConvertDateToLiteral()
	{
		System.runAs(getTestAdmin())
		{
			Date testDate = Date.newInstance(2026, 2, 1);
			String literal = QRY_Condition.toLiteral(testDate, QRY_Condition.DEFAULT_OPTIONS);

			Assert.areEqual('2026-02-01', literal, 'Should format Date correctly');
		}
	}

	/**
	 * @description Tests non-BindAware condition in AndCondition with bind registry.
	 */
	@IsTest
	private static void shouldHandleNonBindAwareInAndConditionWithRegistry()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			MockSoqlable mockCondition = new MockSoqlable('Status = \'Active\'');

			QRY_Condition.AndCondition andCondition = new QRY_Condition.AndCondition();
			andCondition.add(mockCondition);

			String soql = andCondition.toSoql(registry, QRY_Condition.DEFAULT_OPTIONS);

			Assert.isTrue(soql.contains('Status'), 'Should use toSoql(options) for non-BindAware');
		}
	}

	/**
	 * @description Tests non-BindAware condition in NotCondition with bind registry.
	 */
	@IsTest
	private static void shouldHandleNonBindAwareInNotConditionWithRegistry()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			MockSoqlable mockCondition = new MockSoqlable('Status = \'Active\'');

			QRY_Condition.NotCondition notCondition = new QRY_Condition.NotCondition(mockCondition);

			String soql = notCondition.toSoql(registry, QRY_Condition.DEFAULT_OPTIONS);

			Assert.isTrue(soql.contains('NOT'), 'Should contain NOT');
			Assert.isTrue(soql.contains('Status'), 'Should use toSoql(options) for non-BindAware');
		}
	}

	/**
	 * @description Tests toLiteral with Datetime value.
	 */
	@IsTest
	private static void shouldConvertDatetimeToLiteral()
	{
		System.runAs(getTestAdmin())
		{
			Datetime testDatetime = Datetime.newInstanceGmt(2026, 2, 1, 12, 30, 45);
			String literal = QRY_Condition.toLiteral(testDatetime, QRY_Condition.DEFAULT_OPTIONS);

			Assert.isTrue(literal.contains('2026-02-01'), 'Should format Datetime correctly');
			Assert.isTrue(literal.contains('T'), 'Should contain ISO 8601 separator');
			Assert.isTrue(literal.endsWith('Z'), 'Should end with Z for GMT');
		}
	}

	/**
	 * @description Tests toLiteral with Id value.
	 */
	@IsTest
	private static void shouldConvertIdToLiteral()
	{
		System.runAs(getTestAdmin())
		{
			Id testId = UTIL_Random.randomId(Account.SObjectType);
			String literal = QRY_Condition.toLiteral(testId, QRY_Condition.DEFAULT_OPTIONS);

			Assert.isTrue(literal.startsWith('\''), 'Should start with quote');
			Assert.isTrue(literal.endsWith('\''), 'Should end with quote');
			Assert.isTrue(literal.contains(String.valueOf(testId)), 'Should contain Id value');
		}
	}

	/**
	 * @description Tests that convertToLiteral throws for unsupported types.
	 */
	@IsTest
	private static void shouldThrowForUnsupportedLiteralType()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Condition.toLiteral(Blob.valueOf('test'), QRY_Condition.DEFAULT_OPTIONS);
				Assert.fail('Should throw IllegalArgumentException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that yesterday produces YESTERDAY literal.
	 */
	@IsTest
	private static void shouldReturnYesterday()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().yesterday();

			Assert.areEqual(EXPECTED_YESTERDAY, result.toSoql(), 'Should produce YESTERDAY');
		}
	}

	/**
	 * @description Tests that today produces TODAY literal.
	 */
	@IsTest
	private static void shouldReturnToday()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().today();

			Assert.areEqual(EXPECTED_TODAY, result.toSoql(), 'Should produce TODAY');
		}
	}

	/**
	 * @description Tests that tomorrow produces TOMORROW literal.
	 */
	@IsTest
	private static void shouldReturnTomorrow()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().tomorrow();

			Assert.areEqual(EXPECTED_TOMORROW, result.toSoql(), 'Should produce TOMORROW');
		}
	}

	/**
	 * @description Tests that toSoql with options returns the same literal.
	 */
	@IsTest
	private static void shouldReturnLiteralWithOptions()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().today();

			Assert.areEqual(EXPECTED_TODAY, result.toSoql(new QRY_Condition.SoqlOptions()), 'Should produce TODAY with options');
		}
	}

	/**
	 * @description Tests thisX with DAY returns TODAY.
	 */
	@IsTest
	private static void shouldReturnTodayForThisDay()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().thisUnit(QRY_Condition.UnitOfTime.DAY);

			Assert.areEqual(EXPECTED_TODAY, result.toSoql(), 'THIS_DAY should produce TODAY');
		}
	}

	/**
	 * @description Tests thisX with MONTH returns THIS_MONTH.
	 */
	@IsTest
	private static void shouldReturnThisMonth()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().thisUnit(QRY_Condition.UnitOfTime.MONTH);

			Assert.areEqual('THIS_MONTH', result.toSoql(), 'Should produce THIS_MONTH');
		}
	}

	/**
	 * @description Tests thisX with QUARTER returns THIS_QUARTER.
	 */
	@IsTest
	private static void shouldReturnThisQuarter()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().thisUnit(QRY_Condition.UnitOfTime.QUARTER);

			Assert.areEqual('THIS_QUARTER', result.toSoql(), 'Should produce THIS_QUARTER');
		}
	}

	/**
	 * @description Tests thisX with YEAR returns THIS_YEAR.
	 */
	@IsTest
	private static void shouldReturnThisYear()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().thisUnit(QRY_Condition.UnitOfTime.YEAR);

			Assert.areEqual('THIS_YEAR', result.toSoql(), 'Should produce THIS_YEAR');
		}
	}

	/**
	 * @description Tests thisX with FISCAL_QUARTER returns THIS_FISCAL_QUARTER.
	 */
	@IsTest
	private static void shouldReturnThisFiscalQuarter()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().thisUnit(QRY_Condition.UnitOfTime.FISCAL_QUARTER);

			Assert.areEqual('THIS_FISCAL_QUARTER', result.toSoql(), 'Should produce THIS_FISCAL_QUARTER');
		}
	}

	/**
	 * @description Tests last90Days produces LAST_90_DAYS.
	 */
	@IsTest
	private static void shouldReturnLast90Days()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().last90Days();

			Assert.areEqual('LAST_90_DAYS', result.toSoql(), 'Should produce LAST_90_DAYS');
		}
	}

	/**
	 * @description Tests next90Days produces NEXT_90_DAYS.
	 */
	@IsTest
	private static void shouldReturnNext90Days()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().next90Days();

			Assert.areEqual('NEXT_90_DAYS', result.toSoql(), 'Should produce NEXT_90_DAYS');
		}
	}

	/**
	 * @description Tests lastNDays produces LAST_N_DAYS:n.
	 */
	@IsTest
	private static void shouldReturnLastNDays()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().lastNDays(30);

			Assert.areEqual('LAST_N_DAYS:30', result.toSoql(), 'Should produce LAST_N_DAYS:30');
		}
	}

	/**
	 * @description Tests nextNDays produces NEXT_N_DAYS:n.
	 */
	@IsTest
	private static void shouldReturnNextNDays()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().nextNDays(60);

			Assert.areEqual('NEXT_N_DAYS:60', result.toSoql(), 'Should produce NEXT_N_DAYS:60');
		}
	}

	/**
	 * @description Tests last(unit) with QUARTER produces LAST_QUARTER.
	 */
	@IsTest
	private static void shouldReturnLastQuarter()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().last(QRY_Condition.UnitOfTime.QUARTER);

			Assert.areEqual('LAST_QUARTER', result.toSoql(), 'Should produce LAST_QUARTER');
		}
	}

	/**
	 * @description Tests next(unit) with YEAR produces NEXT_YEAR.
	 */
	@IsTest
	private static void shouldReturnNextYear()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().next(QRY_Condition.UnitOfTime.YEAR);

			Assert.areEqual('NEXT_YEAR', result.toSoql(), 'Should produce NEXT_YEAR');
		}
	}

	/**
	 * @description Tests last(n, unit) with QUARTER produces LAST_N_QUARTERS:n.
	 */
	@IsTest
	private static void shouldReturnLastNQuarters()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().last(4, QRY_Condition.UnitOfTime.QUARTER);

			Assert.areEqual('LAST_N_QUARTERS:4', result.toSoql(), 'Should produce LAST_N_QUARTERS:4');
		}
	}

	/**
	 * @description Tests next(n, unit) with FISCAL_YEAR produces NEXT_N_FISCAL_YEARS:n.
	 */
	@IsTest
	private static void shouldReturnNextNFiscalYears()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.DateLiteral result = new QRY_Condition.DateLiteral().next(2, QRY_Condition.UnitOfTime.FISCAL_YEAR);

			Assert.areEqual('NEXT_N_FISCAL_YEARS:2', result.toSoql(), 'Should produce NEXT_N_FISCAL_YEARS:2');
		}
	}

	/**
	 * @description Tests that negative units throw IllegalArgumentException.
	 */
	@IsTest
	private static void shouldThrowForNegativeUnits()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				new QRY_Condition.DateLiteral().lastNDays(-1);
				Assert.fail('Should throw IllegalArgumentException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that N_WEEKS throws IllegalArgumentException.
	 */
	@IsTest
	private static void shouldThrowForNWeeks()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				new QRY_Condition.DateLiteral().last(2, QRY_Condition.UnitOfTime.WEEK);
				Assert.fail('Should throw IllegalArgumentException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that N_MONTHS throws IllegalArgumentException.
	 */
	@IsTest
	private static void shouldThrowForNMonths()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				new QRY_Condition.DateLiteral().last(2, QRY_Condition.UnitOfTime.MONTH);
				Assert.fail('Should throw IllegalArgumentException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that date literal integrates with QRY_Builder condition as value.
	 */
	@IsTest
	private static void shouldIntegrateWithQryBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition('CreatedDate').lessThan(new QRY_Condition.DateLiteral().lastNDays(30))
					.toSoql();

			Assert.isTrue(soql.contains('LAST_N_DAYS:30'), 'SOQL should contain date literal: ' + soql);
		}
	}

	/**
	 * @description Tests that FalseCondition generates SOQL that matches no records.
	 */
	@IsTest
	private static void falseConditionShouldGenerateImpossibleCondition()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Condition.FalseCondition condition = new QRY_Condition.FalseCondition();

			Assert.areEqual('Id = null', condition.toSoql(), 'FalseCondition should generate Id = null');
			Assert.areEqual('Id = null', condition.toSoql(QRY_Condition.DEFAULT_OPTIONS), 'FalseCondition should generate Id = null with options');
		}
	}

	/**
	 * @description Proves that every FieldCondition and SetCondition constructor, and their field methods, refuse a text
	 * that is not a field name. Each text adds an OR that matches every row. One case is the text the Scheduled Jobs
	 * purge job passes on from its date field setting: it would turn "rows older than one day" into "every row". The
	 * query runs against real rows, so a text that is let through shows how many rows it returned. A refused text must
	 * raise an IllegalArgumentException that names the class, and must leave the query text as it was. First, the test
	 * proves that a parent field path to a date field, as the purge job may pass, is still accepted, keeps its query
	 * text and runs.
	 */
	@IsTest
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static void shouldRefuseCraftedTextInTheConditionConstructors()
	{
		System.runAs(getTestAdmin())
		{
			Account parentAccount = (Account)TST_Builder.of(Account.SObjectType)
					.withOverride(Account.Phone, ACCOUNT_PHONE)
					.withOverride(Account.Industry, ACCOUNT_INDUSTRY)
					.build();
			TST_Builder.of(Contact.SObjectType).withOverride(Contact.AccountId, parentAccount.Id).build();
			String accountCreatedDate = UTIL_SObjectDescribe.getCachedFieldDescribe(Contact.AccountId).getRelationshipName() + '.'
					+ UTIL_SObjectDescribe.getCachedFieldName(Account.CreatedDate);
			QRY_Builder.Builder contactQuery = QRY_Builder.selectFrom(Contact.SObjectType)
					.addField(Contact.LastName)
					.addCondition(new QRY_Condition.FieldCondition(accountCreatedDate, QRY_Condition.Operator.LESS_THAN, FAR_FUTURE));
			Assert.areEqual
					(
							'SELECT Id, ' + UTIL_SObjectDescribe.getCachedFieldName(Contact.LastName) + ' FROM ' + String.valueOf(Contact.SObjectType) + ' WHERE '
							+ accountCreatedDate + ' < ' + FAR_FUTURE_TEXT,
							contactQuery.toSoql(),
							'Expected a parent field path to a date field to keep its query text'
					);
			Assert.areEqual(1, contactQuery.toList().size(), 'Expected the query on a parent field path to run and return the saved Contact');

			for(Integer index = 0; index < CRAFTED_TEXT_PROBE_ROWS; index++)
			{
				seedFoobarNamed(UTIL_Random.randomUUID());
			}
			String createdDate = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.CreatedDate);
			String widening = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Id) + ' != null OR ' + UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name);
			String noMatch = UTIL_Random.randomUUID();

			for(ConstructorCase craftedCall : ConstructorCase.values())
			{
				String craftedText = craftedCall == ConstructorCase.PURGE_JOB_DATE_FIELD ? createdDate + ' != null OR ' + createdDate : widening;
				String className = craftedCall.name().startsWith('SET_') ? 'SetCondition' : 'FieldCondition';
				QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType).addField(Foobar__c.Name);
				String soqlBefore = query.toSoql();
				try
				{
					query.addCondition(buildCraftedCondition(craftedCall, craftedText, noMatch));
					List<SObject> rows = query.toList();
					Assert.fail
							(
									'Expected ' + className + ' to refuse the text given to ' + craftedCall.name() + '; the query ran and returned '
									+ rows.size() + ' rows: ' + query.toSoql()
							);
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException for ' + craftedCall.name() + ', got: ' + error);
					Assert.areEqual(buildMessage(FIELD_NAME_REFUSED_LABEL, className), error.getMessage(), 'Expected the message to name ' + className);
					Assert.areEqual(soqlBefore, query.toSoql(), 'Expected the refused text to leave the query unchanged for ' + craftedCall.name());
				}
			}
		}
	}

	/**
	 * @description Proves that a select text added to an inner query after a SetCondition stored it is refused when
	 * the query text is built. The inner query is stored with no selected field, so there is nothing to check when it
	 * is stored. Its select list is written inside the outer WHERE clause, so the text added later could swap the
	 * filter the code meant for another one. Account A has a Contact; Account B has an Opportunity and no Contact.
	 */
	@IsTest
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static void shouldRefuseSemiJoinSelectTextAddedAfterTheSubqueryIsStored()
	{
		System.runAs(getTestAdmin())
		{
			Account accountWithContact = (Account)TST_Builder.of(Account.SObjectType)
					.withOverride(Account.Name, 'A ' + UTIL_Random.randomUUID())
					.withOverride(Account.Phone, ACCOUNT_PHONE)
					.withOverride(Account.Industry, ACCOUNT_INDUSTRY)
					.build();
			Account accountWithOpportunity = (Account)TST_Builder.of(Account.SObjectType)
					.withOverride(Account.Name, 'B ' + UTIL_Random.randomUUID())
					.withOverride(Account.Phone, ACCOUNT_PHONE)
					.withOverride(Account.Industry, ACCOUNT_INDUSTRY)
					.build();
			TST_Builder.of(Contact.SObjectType).withOverride(Contact.AccountId, accountWithContact.Id).build();
			TST_Builder.of(Opportunity.SObjectType).withOverride(Opportunity.AccountId, accountWithOpportunity.Id).build();
			String ownerField = UTIL_SObjectDescribe.getCachedFieldName(Account.OwnerId);
			String craftedSelect = UTIL_SObjectDescribe.getCachedFieldName(Contact.AccountId) + ' FROM ' + String.valueOf(Opportunity.SObjectType)
					+ ') AND ' + ownerField + ' IN (SELECT ' + ownerField;

			QRY_Generator innerQuery = new QRY_Generator().fromObject(String.valueOf(Contact.SObjectType));
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition(UTIL_SObjectDescribe.getCachedFieldName(Account.Id)).notIn(innerQuery);
			innerQuery.addField(craftedSelect);
			QRY_Builder.Builder query = QRY_Builder.selectFrom(Account.SObjectType)
					.addField(Account.Name)
					.condition(Account.Name).isIn(new List<Object> {accountWithContact.Name, accountWithOpportunity.Name});

			try
			{
				query.addCondition(condition);
				List<SObject> rows = query.toList();
				List<String> rowNames = new List<String>();
				for(SObject row : rows)
				{
					rowNames.add((String)row.get(Account.Name));
				}
				Assert.fail
						(
								'Expected SetCondition to refuse a select text added after the inner query was stored; the query ran and returned '
								+ rows.size() + ' rows ' + rowNames + ': ' + query.toSoql()
						);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException, got: ' + error);
				Assert.areEqual(buildMessage(FIELD_NAME_REFUSED_LABEL, 'SetCondition'), error.getMessage(), 'Expected the message to name SetCondition');
			}
		}
	}

	/**
	 * @description Proves that a group of conditions refuses a joining word other than AND or OR. A class that extends
	 * ConditionGroup can pass any word; here it passes a word that adds "OR Id != null OR" between two conditions that
	 * match no row, so the group would match every row. The refusal must come when the group is created, with an
	 * IllegalArgumentException that names ConditionGroup, and the query text must stay as it was.
	 */
	@IsTest
	private static void shouldRefuseAConditionGroupJoiningWordOtherThanAndOrOr()
	{
		System.runAs(getTestAdmin())
		{
			for(Integer index = 0; index < CRAFTED_TEXT_PROBE_ROWS; index++)
			{
				seedFoobarNamed(UTIL_Random.randomUUID());
			}
			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType).addField(Foobar__c.Name);
			String soqlBefore = query.toSoql();

			try
			{
				JoinedConditionGroup conditionGroup = new JoinedConditionGroup('OR ' + UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Id) + ' != null OR');
				conditionGroup.add(new QRY_Condition.FieldCondition(Foobar__c.Name, UTIL_Random.randomUUID()));
				conditionGroup.add(new QRY_Condition.FieldCondition(Foobar__c.Name, UTIL_Random.randomUUID()));
				query.addCondition(conditionGroup);
				List<SObject> rows = query.toList();
				Assert.fail('Expected ConditionGroup to refuse the joining word; the query ran and returned ' + rows.size() + ' rows: ' + query.toSoql());
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException, got: ' + error);
				Assert.areEqual(buildMessage(CONDITION_SEPARATOR_REFUSED_LABEL, 'ConditionGroup'), error.getMessage(), 'Expected the message to name ConditionGroup');
				Assert.areEqual(soqlBefore, query.toSoql(), 'Expected the refused group to leave the query unchanged');
			}
		}
	}

	/**
	 * @description Records that a group of conditions joined by "and" in lower case is accepted, and that the query
	 * text keeps the word exactly as given. The query runs and returns the one row that matches both conditions.
	 */
	@IsTest
	private static void shouldKeepTheQueryTextForAConditionGroupJoinedByLowerCaseAnd()
	{
		System.runAs(getTestAdmin())
		{
			String matchingName = UTIL_Random.randomUUID();
			String otherName = UTIL_Random.randomUUID();
			seedFoobarNamed(matchingName);
			seedFoobarNamed(otherName);
			String nameField = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name);

			JoinedConditionGroup conditionGroup = new JoinedConditionGroup('and');
			conditionGroup.add(new QRY_Condition.FieldCondition(Foobar__c.Name, matchingName));
			conditionGroup.add(new QRY_Condition.FieldCondition(Foobar__c.Name, QRY_Condition.Operator.NOT_EQUALS, otherName));
			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType).addField(Foobar__c.Name).addCondition(conditionGroup);

			Assert.areEqual
					(
							'SELECT Id, ' + nameField + ' FROM ' + SEL_Foobar.OBJECT_NAME + ' WHERE (' + nameField + ' = \'' + matchingName + '\' and '
							+ nameField + ' != \'' + otherName + '\')',
							query.toSoql(),
							'Expected the joining word to stay as given'
					);
			Assert.areEqual(1, query.toList().size(), 'Expected the query to run and return the one matching row');
		}
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
	 * @description Builds the message a condition gives when it refuses a text. The label is read by its name, with the
	 * package namespace, and the class name is put into it.
	 *
	 * @param labelName The name of the Custom Label that holds the message
	 * @param className The class the message must name
	 *
	 * @return The expected message
	 */
	private static String buildMessage(String labelName, String className)
	{
		return String.format(System.Label.get(UTIL_System.getManagedPackageNamespace(), labelName), new List<Object> {className});
	}

	/**
	 * @description Builds the condition a case names, with the crafted text where the field name goes.
	 *
	 * @param craftedCall The constructor or field method to call
	 * @param craftedText The text that is not a field name
	 * @param noMatch A value that matches no row
	 *
	 * @return The condition
	 */
	private static QRY_Condition.Evaluable buildCraftedCondition(ConstructorCase craftedCall, String craftedText, String noMatch)
	{
		List<Object> values = new List<Object> {noMatch};
		switch on craftedCall
		{
			when FIELD_CONDITION_FIELD_ONLY
			{
				return new QRY_Condition.FieldCondition(craftedText).equals(noMatch);
			}
			when FIELD_CONDITION_WITH_OPERATOR
			{
				return new QRY_Condition.FieldCondition(craftedText, QRY_Condition.Operator.EQUALS, noMatch);
			}
			when FIELD_CONDITION_WITH_VALUE
			{
				return new QRY_Condition.FieldCondition(craftedText, (Object)noMatch);
			}
			when FIELD_CONDITION_FIELD_METHOD
			{
				return new QRY_Condition.FieldCondition().field(craftedText).equals(noMatch);
			}
			when SET_CONDITION_FIELD_ONLY
			{
				return new QRY_Condition.SetCondition(craftedText).inX(values);
			}
			when SET_CONDITION_WITH_COLLECTION
			{
				return new QRY_Condition.SetCondition(craftedText, QRY_Condition.Operator.IN_X, (Object)values);
			}
			when SET_CONDITION_WITH_LIST
			{
				return new QRY_Condition.SetCondition(craftedText, QRY_Condition.Operator.IN_X, values);
			}
			when SET_CONDITION_WITH_SET
			{
				return new QRY_Condition.SetCondition(craftedText, QRY_Condition.Operator.IN_X, new Set<Object>(values));
			}
			when SET_CONDITION_WITH_INNER_QUERY
			{
				return new QRY_Condition.SetCondition(craftedText, QRY_Condition.Operator.IN_X, new QRY_Generator(Foobar__c.SObjectType));
			}
			when SET_CONDITION_FIELD_METHOD
			{
				return new QRY_Condition.SetCondition().field(craftedText).inX(values);
			}
			when else
			{
				return new QRY_Condition.FieldCondition(craftedText, QRY_Condition.Operator.LESS_THAN, new QRY_Condition.DateLiteral().lastNDays(1));
			}
		}
	}

	/**
	 * @description The condition constructor or field method that receives a crafted text in a test. The values that
	 * start with SET_ are SetCondition calls; the others are FieldCondition calls.
	 */
	private enum ConstructorCase
	{
		/**
		 * @description new FieldCondition(text), followed by equals.
		 */
		FIELD_CONDITION_FIELD_ONLY,
		/**
		 * @description new FieldCondition(text, Operator.EQUALS, value).
		 */
		FIELD_CONDITION_WITH_OPERATOR,
		/**
		 * @description new FieldCondition(text, value), which compares with equals.
		 */
		FIELD_CONDITION_WITH_VALUE,
		/**
		 * @description new FieldCondition().field(text), followed by equals.
		 */
		FIELD_CONDITION_FIELD_METHOD,
		/**
		 * @description new SetCondition(text), followed by inX with a list.
		 */
		SET_CONDITION_FIELD_ONLY,
		/**
		 * @description new SetCondition(text, Operator.IN_X, value), where the value is a list passed as an Object.
		 */
		SET_CONDITION_WITH_COLLECTION,
		/**
		 * @description new SetCondition(text, Operator.IN_X, list).
		 */
		SET_CONDITION_WITH_LIST,
		/**
		 * @description new SetCondition(text, Operator.IN_X, set).
		 */
		SET_CONDITION_WITH_SET,
		/**
		 * @description new SetCondition(text, Operator.IN_X, inner query).
		 */
		SET_CONDITION_WITH_INNER_QUERY,
		/**
		 * @description new SetCondition().field(text), followed by inX with a list.
		 */
		SET_CONDITION_FIELD_METHOD,
		/**
		 * @description new FieldCondition(text, Operator.LESS_THAN, LAST_N_DAYS:1), as the Scheduled Jobs purge job builds
		 * it from its date field setting.
		 */
		PURGE_JOB_DATE_FIELD
	}

	/**
	 * @description A group of conditions joined by any word the test gives. It stands for a class that a developer
	 * writes by extending ConditionGroup.
	 */
	private inherited sharing class JoinedConditionGroup extends QRY_Condition.ConditionGroup
	{
		/**
		 * @description Creates the group with the given joining word.
		 *
		 * @param joiningWord The word written between the conditions of the group
		 */
		public JoinedConditionGroup(String joiningWord)
		{
			super(joiningWord);
		}
	}
}