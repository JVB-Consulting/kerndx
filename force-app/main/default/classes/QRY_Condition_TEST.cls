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
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity,PMD.NcssTypeCount')
@IsTest(SeeAllData=false IsParallel=false)
private class QRY_Condition_TEST
{
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
	 * @description Tests SetCondition with Decimal values (should use literals).
	 */
	@IsTest
	private static void shouldUseLiteralsForDecimalValues()
	{
		System.runAs(getTestAdmin())
		{
			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Condition.SetCondition condition = new QRY_Condition.SetCondition('Amount');
			condition.inX(new List<Object> {100.5, 200.75});

			String soql = condition.toSoql(registry);

			Assert.isTrue(soql.contains('Amount IN'), 'Should contain IN operator');
			Assert.isFalse(soql.contains(':b'), 'Should use literals for Decimal values');
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
	 * @description Retrieves the committed test admin user set up in @TestSetup for use with
	 * System.runAs, so each test body runs with a fresh permission-evaluation context.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}
}