// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for QRY_Generator.
 * Tests SOQL string generation including fields, conditions, ordering, aggregates, and locking.
 *
 * @see QRY_Generator
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date February 2026, June 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
@IsTest(SeeAllData=false IsParallel=true)
private class QRY_Generator_TEST
{
	/**
	 * @description Test object name.
	 */
	private static final String TEST_OBJECT = 'Account';
	private static final String FIELD_NAME = 'Name';

	/**
	 * @description Tests basic query generation with fields.
	 */
	@IsTest
	private static void shouldGenerateBasicQuery()
	{
		QRY_Generator generator = new QRY_Generator()
				.addField(FIELD_NAME)
				.addField('Industry')
				.fromObject(TEST_OBJECT);

		String soql = generator.toSoql();

		Assert.isTrue(soql.startsWith('SELECT '), 'Should start with SELECT');
		Assert.isTrue(soql.contains(FIELD_NAME), 'Should contain Name field');
		Assert.isTrue(soql.contains('Industry'), 'Should contain Industry field');
		Assert.isTrue(soql.contains('FROM Account'), 'Should contain FROM Account');
	}

	/**
	 * @description Tests query with SObjectType constructor.
	 */
	@IsTest
	private static void shouldGenerateQueryWithSObjectTypeConstructor()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('FROM Account'), 'Should contain FROM Account');
	}

	/**
	 * @description Tests query with SObjectField.
	 */
	@IsTest
	private static void shouldGenerateQueryWithSObjectField()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(Account.Name)
				.addField(Account.Industry);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains(FIELD_NAME), 'Should contain Name field');
		Assert.isTrue(soql.contains('Industry'), 'Should contain Industry field');
	}

	/**
	 * @description Tests query with field list.
	 */
	@IsTest
	private static void shouldGenerateQueryWithFieldList()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addFields(new List<String> {FIELD_NAME, 'Industry', 'Type'});

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains(FIELD_NAME), 'Should contain Name');
		Assert.isTrue(soql.contains('Industry'), 'Should contain Industry');
		Assert.isTrue(soql.contains('Type'), 'Should contain Type');
	}

	/**
	 * @description Tests query with field set.
	 */
	@IsTest
	private static void shouldGenerateQueryWithFieldSet()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addFields(new Set<String> {FIELD_NAME, 'Industry'});

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains(FIELD_NAME), 'Should contain Name');
		Assert.isTrue(soql.contains('Industry'), 'Should contain Industry');
	}

	/**
	 * @description Tests default Id field when no fields specified.
	 */
	@IsTest
	private static void shouldAddIdFieldWhenNoFieldsSpecified()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('SELECT Id'), 'Should select Id by default');
	}

	/**
	 * @description Tests WHERE condition.
	 */
	@IsTest
	private static void shouldGenerateWhereClause()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition('Industry', 'Technology');

		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.whereCondition(condition);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('WHERE'), 'Should contain WHERE');
		Assert.isTrue(soql.contains('Industry'), 'Should contain Industry condition');
	}

	/**
	 * @description Tests ORDER BY clause.
	 */
	@IsTest
	private static void shouldGenerateOrderByClause()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.orderBy(new QRY_Generator.OrderBy(FIELD_NAME).ascending());

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('ORDER BY Name ASC'), 'Should contain ORDER BY Name ASC');
	}

	/**
	 * @description Tests ORDER BY descending.
	 */
	@IsTest
	private static void shouldGenerateOrderByDescending()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.orderBy(new QRY_Generator.OrderBy('CreatedDate').descending());

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('ORDER BY CreatedDate DESC'), 'Should contain ORDER BY DESC');
	}

	/**
	 * @description Tests ORDER BY with nulls first.
	 */
	@IsTest
	private static void shouldGenerateOrderByNullsFirst()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.orderBy(new QRY_Generator.OrderBy(FIELD_NAME).ascending().nullsFirst());

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('NULLS FIRST'), 'Should contain NULLS FIRST');
	}

	/**
	 * @description Tests ORDER BY with nulls last.
	 */
	@IsTest
	private static void shouldGenerateOrderByNullsLast()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.orderBy(new QRY_Generator.OrderBy(FIELD_NAME).ascending().nullsLast());

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('NULLS LAST'), 'Should contain NULLS LAST');
	}

	/**
	 * @description Tests OrderBy getField returns the configured field name.
	 */
	@IsTest
	private static void shouldReturnOrderByField()
	{
		QRY_Generator.OrderBy orderBy = new QRY_Generator.OrderBy(FIELD_NAME);

		Assert.areEqual(FIELD_NAME, orderBy.getField(), 'Should return field name');
	}

	/**
	 * @description Tests OrderBy isAscending returns true for ascending and false for descending.
	 */
	@IsTest
	private static void shouldReturnOrderByAscending()
	{
		QRY_Generator.OrderBy ascending = new QRY_Generator.OrderBy(FIELD_NAME).ascending();
		QRY_Generator.OrderBy descending = new QRY_Generator.OrderBy(FIELD_NAME).descending();

		Assert.isTrue(ascending.isAscending(), 'Should return true for ascending');
		Assert.isFalse(descending.isAscending(), 'Should return false for descending');
	}

	/**
	 * @description Tests ORDER BY with SObjectField.
	 */
	@IsTest
	private static void shouldGenerateOrderByWithSObjectField()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.orderBy(new QRY_Generator.OrderBy(Account.Name).ascending());

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('ORDER BY'), 'Should contain ORDER BY');
		Assert.isTrue(soql.contains(FIELD_NAME), 'Should contain Name');
	}

	/**
	 * @description Tests LIMIT clause.
	 */
	@IsTest
	private static void shouldGenerateLimitClause()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.limitTo(100);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('LIMIT 100'), 'Should contain LIMIT 100');
	}

	/**
	 * @description Tests OFFSET clause.
	 */
	@IsTest
	private static void shouldGenerateOffsetClause()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.offset(50);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('OFFSET 50'), 'Should contain OFFSET 50');
	}

	/**
	 * @description Tests GROUP BY clause.
	 */
	@IsTest
	private static void shouldGenerateGroupByClause()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectCount('Id')
				.groupBy('Industry');

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('GROUP BY Industry'), 'Should contain GROUP BY');
	}

	/**
	 * @description Tests GROUP BY with multiple fields.
	 */
	@IsTest
	private static void shouldGenerateMultipleGroupByFields()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectCount('Id')
				.groupBy('Industry')
				.groupBy('Rating');

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('GROUP BY Industry, Rating'), 'Should contain multi-field GROUP BY');
	}

	/**
	 * @description Tests GROUP BY ROLLUP.
	 */
	@IsTest
	private static void shouldGenerateGroupByRollup()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectCount('Id')
				.groupBy('Industry')
				.groupBy('Rating')
				.rollup();

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('GROUP BY ROLLUP(Industry, Rating)'), 'Should contain GROUP BY ROLLUP');
	}

	/**
	 * @description Tests GROUP BY CUBE.
	 */
	@IsTest
	private static void shouldGenerateGroupByCube()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectCount('Id')
				.groupBy('Industry')
				.groupBy('Rating')
				.cube();

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('GROUP BY CUBE(Industry, Rating)'), 'Should contain GROUP BY CUBE');
	}

	/**
	 * @description Tests GROUPING() function in SELECT.
	 */
	@IsTest
	private static void shouldGenerateGroupingFunction()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectCount('Id')
				.groupBy('Industry')
				.grouping('Industry')
				.rollup();

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('GROUPING(Industry)'), 'Should contain GROUPING function');
		Assert.isTrue(soql.contains('GROUP BY ROLLUP(Industry)'), 'Should contain ROLLUP');
	}

	/**
	 * @description Tests combined ROLLUP with GROUPING and aggregate.
	 */
	@IsTest
	private static void shouldGenerateGroupByRollupWithGrouping()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectSum('AnnualRevenue')
				.groupBy('Industry')
				.groupBy('Rating')
				.grouping('Industry')
				.grouping('Rating')
				.rollup();

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('GROUPING(Industry)'), 'Should contain GROUPING for Industry');
		Assert.isTrue(soql.contains('GROUPING(Rating)'), 'Should contain GROUPING for Rating');
		Assert.isTrue(soql.contains('GROUP BY ROLLUP(Industry, Rating)'), 'Should contain ROLLUP with both fields');
		Assert.isTrue(soql.contains('SUM(AnnualRevenue)'), 'Should contain SUM aggregate');
	}

	/**
	 * @description Tests HAVING clause.
	 */
	@IsTest
	private static void shouldGenerateHavingClause()
	{
		QRY_Condition.FieldCondition havingCond = new QRY_Condition.FieldCondition('COUNT(Id)');
		havingCond.greaterThan(5);

		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectCount('Id')
				.groupBy('Industry')
				.havingCondition(havingCond);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('HAVING'), 'Should contain HAVING');
	}

	/**
	 * @description Tests COUNT aggregate.
	 */
	@IsTest
	private static void shouldGenerateCountAggregate()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectCount();

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('SELECT COUNT()'), 'Should contain COUNT()');
	}

	/**
	 * @description Tests COUNT with field.
	 */
	@IsTest
	private static void shouldGenerateCountWithField()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectCount('Industry');

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('COUNT(Industry)'), 'Should contain COUNT(Industry)');
		Assert.isTrue(soql.contains('count_Industry'), 'Should contain alias');
	}

	/**
	 * @description Tests AVG aggregate.
	 */
	@IsTest
	private static void shouldGenerateAvgAggregate()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectAvg('AnnualRevenue');

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('AVG(AnnualRevenue)'), 'Should contain AVG');
	}

	/**
	 * @description Tests SUM aggregate.
	 */
	@IsTest
	private static void shouldGenerateSumAggregate()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectSum('AnnualRevenue');

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('SUM(AnnualRevenue)'), 'Should contain SUM');
	}

	/**
	 * @description Tests MIN aggregate.
	 */
	@IsTest
	private static void shouldGenerateMinAggregate()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectMin('CreatedDate');

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('MIN(CreatedDate)'), 'Should contain MIN');
	}

	/**
	 * @description Tests MAX aggregate.
	 */
	@IsTest
	private static void shouldGenerateMaxAggregate()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectMax('CreatedDate');

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('MAX(CreatedDate)'), 'Should contain MAX');
	}

	/**
	 * @description Tests COUNT_DISTINCT aggregate.
	 */
	@IsTest
	private static void shouldGenerateCountDistinctAggregate()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectCountDistinct(FIELD_NAME);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('COUNT_DISTINCT(Name)'), 'Should contain COUNT_DISTINCT');
		Assert.isTrue(soql.contains('count_distinct_Name'), 'Should contain alias');
	}

	/**
	 * @description Tests formatAggregate with COUNT_DISTINCT.
	 */
	@IsTest
	private static void shouldFormatCountDistinctAggregate()
	{
		String result = QRY_Generator.formatAggregate(QRY_Generator.Aggregate.COUNT_DISTINCT, FIELD_NAME);

		Assert.areEqual('COUNT_DISTINCT(Name)', result, 'Should format COUNT_DISTINCT correctly');
	}

	/**
	 * @description Tests FOR UPDATE clause.
	 */
	@IsTest
	private static void shouldGenerateForUpdate()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.forUpdate();

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('FOR UPDATE'), 'Should contain FOR UPDATE');
	}

	/**
	 * @description Tests FOR REFERENCE clause.
	 */
	@IsTest
	private static void shouldGenerateForReference()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.forReference();

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('FOR REFERENCE'), 'Should contain FOR REFERENCE');
	}

	/**
	 * @description Tests FOR VIEW clause.
	 */
	@IsTest
	private static void shouldGenerateForView()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.forView();

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('FOR VIEW'), 'Should contain FOR VIEW');
	}

	/**
	 * @description Tests ALL ROWS clause.
	 */
	@IsTest
	private static void shouldGenerateAllRows()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.allRows();

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('ALL ROWS'), 'Should contain ALL ROWS');
	}

	/**
	 * @description Tests WITH USER_MODE clause.
	 */
	@IsTest
	private static void shouldGenerateSecurityEnforced()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.withSecurityEnforced();

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('WITH USER_MODE'), 'Should contain WITH USER_MODE');
	}

	/**
	 * @description Tests WITH DATA CATEGORY clause with a single filter.
	 */
	@IsTest
	private static void shouldGenerateDataCategorySingleFilter()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.withDataCategory(new QRY_Generator.DataCategoryFilter(
						'Geography__c', QRY_Generator.DataCategoryOperator.AT, new List<String> {'USA__c'}
				));

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('WITH DATA CATEGORY Geography__c AT USA__c'), 'Should contain single data category filter');
		Assert.isFalse(soql.contains('('), 'Single category should not use parentheses');
	}

	/**
	 * @description Tests WITH DATA CATEGORY clause with multiple categories in one group.
	 */
	@IsTest
	private static void shouldGenerateDataCategoryMultipleCategories()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.withDataCategory(new QRY_Generator.DataCategoryFilter(
						'Geography__c', QRY_Generator.DataCategoryOperator.AT, new List<String> {'USA__c', 'Canada__c'}
				));

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('WITH DATA CATEGORY Geography__c AT (USA__c, Canada__c)'), 'Should contain parenthesized categories');
	}

	/**
	 * @description Tests WITH DATA CATEGORY clause with multiple groups.
	 */
	@IsTest
	private static void shouldGenerateDataCategoryMultipleGroups()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.withDataCategory(new QRY_Generator.DataCategoryFilter(
						'Geography__c', QRY_Generator.DataCategoryOperator.AT, new List<String> {'USA__c'}
				))
				.withDataCategory(new QRY_Generator.DataCategoryFilter(
						'Product__c', QRY_Generator.DataCategoryOperator.BELOW, new List<String> {'Electronics__c'}
				));

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('WITH DATA CATEGORY Geography__c AT USA__c AND Product__c BELOW Electronics__c'),
				'Should contain multiple groups joined with AND');
	}

	/**
	 * @description Tests WITH DATA CATEGORY ABOVE operator.
	 */
	@IsTest
	private static void shouldGenerateDataCategoryAboveOperator()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.withDataCategory(new QRY_Generator.DataCategoryFilter(
						'Geography__c', QRY_Generator.DataCategoryOperator.ABOVE, new List<String> {'USA__c'}
				));

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('Geography__c ABOVE USA__c'), 'Should contain ABOVE operator');
	}

	/**
	 * @description Tests WITH DATA CATEGORY BELOW operator.
	 */
	@IsTest
	private static void shouldGenerateDataCategoryBelowOperator()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.withDataCategory(new QRY_Generator.DataCategoryFilter(
						'Geography__c', QRY_Generator.DataCategoryOperator.BELOW, new List<String> {'USA__c'}
				));

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('Geography__c BELOW USA__c'), 'Should contain BELOW operator');
	}

	/**
	 * @description Tests WITH DATA CATEGORY ABOVE_OR_BELOW operator.
	 */
	@IsTest
	private static void shouldGenerateDataCategoryAboveOrBelowOperator()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.withDataCategory(new QRY_Generator.DataCategoryFilter(
						'Geography__c', QRY_Generator.DataCategoryOperator.ABOVE_BELOW, new List<String> {'USA__c'}
				));

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('Geography__c ABOVE_OR_BELOW USA__c'), 'Should contain ABOVE_OR_BELOW operator');
	}

	/**
	 * @description Tests that WITH DATA CATEGORY and WITH SECURITY_ENFORCED cannot coexist.
	 */
	@IsTest
	private static void shouldThrowWhenDataCategoryWithSecurityEnforced()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.withSecurityEnforced()
				.withDataCategory(new QRY_Generator.DataCategoryFilter(
						'Geography__c', QRY_Generator.DataCategoryOperator.AT, new List<String> {'USA__c'}
				));

		try
		{
			generator.toSoql();
			Assert.fail('Should throw ConfigurationException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.ConfigurationException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests that no data category clause is added when no filters exist.
	 */
	@IsTest
	private static void shouldOmitDataCategoryClauseWhenNoFilters()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME);

		String soql = generator.toSoql();

		Assert.isFalse(soql.contains('WITH DATA CATEGORY'), 'Should not contain WITH DATA CATEGORY');
	}

	/**
	 * @description Tests DataCategoryFilter getGroupName accessor.
	 */
	@IsTest
	private static void shouldReturnDataCategoryFilterGroupName()
	{
		QRY_Generator.DataCategoryFilter filter = new QRY_Generator.DataCategoryFilter(
				'Geography__c', QRY_Generator.DataCategoryOperator.AT, new List<String> {'USA__c'}
		);

		Assert.areEqual('Geography__c', filter.getGroupName(), 'Should return the group name');
	}

	/**
	 * @description Tests that null DataCategoryFilter is ignored gracefully.
	 */
	@IsTest
	private static void shouldIgnoreNullDataCategoryFilter()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.withDataCategory(null);

		String soql = generator.toSoql();

		Assert.isFalse(soql.contains('WITH DATA CATEGORY'), 'Should not contain WITH DATA CATEGORY when null filter passed');
	}

	/**
	 * @description Tests USING SCOPE clause.
	 */
	@IsTest
	private static void shouldGenerateUsingScope()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.usingScope(QRY_Generator.Scope.MINE);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('USING SCOPE Mine'), 'Should contain USING SCOPE Mine');
	}

	/**
	 * @description Tests all scope values.
	 */
	@IsTest
	private static void shouldGenerateAllScopeValues()
	{
		Map<QRY_Generator.Scope, String> scopeMap = new Map<QRY_Generator.Scope, String>
		{
				QRY_Generator.Scope.MINE => 'Mine',
				QRY_Generator.Scope.MY_TERRITORY => 'My_Territory',
				QRY_Generator.Scope.MY_TEAM_TERRITORY => 'My_Team_Territory',
				QRY_Generator.Scope.TEAM => 'Team',
				QRY_Generator.Scope.DELEGATED => 'Delegated',
				QRY_Generator.Scope.EVERYTHING => 'Everything'
		};

		for(QRY_Generator.Scope scope : scopeMap.keySet())
		{
			QRY_Generator generator = new QRY_Generator(Account.SObjectType)
					.addField(FIELD_NAME)
					.usingScope(scope);

			String soql = generator.toSoql();
			String expectedValue = scopeMap.get(scope);

			Assert.isTrue(soql.contains(expectedValue), 'Should contain scope ' + expectedValue);
		}
	}

	/**
	 * @description Tests query with bind registry.
	 */
	@IsTest
	private static void shouldGenerateQueryWithBinds()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition('Industry', 'Technology');

		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.whereCondition(condition);

		String soql = generator.toSoql(registry);

		Assert.isTrue(soql.contains(':b'), 'Should contain bind reference');
		Assert.isTrue(registry.size() > 0, 'Registry should have entries');
	}

	/**
	 * @description Tests exception when no object specified.
	 */
	@IsTest
	private static void shouldThrowExceptionWhenNoObject()
	{
		try
		{
			new QRY_Generator().addField(FIELD_NAME).toSoql();
			Assert.fail('Should throw exception when no object');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.ConfigurationException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests subquery in SELECT.
	 */
	@IsTest
	private static void shouldGenerateSubquery()
	{
		QRY_Generator subquery = new QRY_Generator()
				.addField('Id')
				.addField(FIELD_NAME)
				.fromObject('Contacts');

		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.addSubquery(subquery);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('(SELECT'), 'Should contain subquery SELECT');
		Assert.isTrue(soql.contains('FROM Contacts'), 'Should contain subquery FROM');
	}

	/**
	 * @description Tests getBindRegistry method.
	 */
	@IsTest
	private static void shouldReturnBindRegistry()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME);

		generator.toSoql(registry);

		Assert.isNotNull(generator.getBindRegistry(), 'Should return bind registry');
	}

	/**
	 * @description Tests null handling in addField.
	 */
	@IsTest
	private static void shouldHandleNullFieldName()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField((String)null)
				.addField(FIELD_NAME);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains(FIELD_NAME), 'Should contain Name');
	}

	/**
	 * @description Tests null handling in addField with SObjectField.
	 */
	@IsTest
	private static void shouldHandleNullSObjectField()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField((SObjectField)null)
				.addField(FIELD_NAME);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains(FIELD_NAME), 'Should contain Name');
	}

	/**
	 * @description Tests selectAllFields.
	 */
	@IsTest
	private static void shouldSelectAllFields()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectAllFields();

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('SELECT'), 'Should contain SELECT');
		Assert.isTrue(soql.contains('FROM Account'), 'Should contain FROM');
	}

	/**
	 * @description Tests fromObject with SObjectType.
	 */
	@IsTest
	private static void shouldSetObjectFromSObjectType()
	{
		QRY_Generator generator = new QRY_Generator()
				.addField(FIELD_NAME)
				.fromObject(Account.SObjectType);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('FROM Account'), 'Should contain FROM Account');
	}

	/**
	 * @description Tests null handling in addFields with null list.
	 */
	@IsTest
	private static void shouldHandleNullFieldList()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addFields((List<String>)null)
				.addField(FIELD_NAME);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains(FIELD_NAME), 'Should contain Name');
	}

	/**
	 * @description Tests null handling in addFields with null set.
	 */
	@IsTest
	private static void shouldHandleNullFieldSet()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addFields((Set<String>)null)
				.addField(FIELD_NAME);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains(FIELD_NAME), 'Should contain Name');
	}

	/**
	 * @description Tests null handling in orderBy.
	 */
	@IsTest
	private static void shouldHandleNullOrderBy()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.orderBy(null);

		String soql = generator.toSoql();

		Assert.isFalse(soql.contains('ORDER BY'), 'Should not contain ORDER BY');
	}

	/**
	 * @description Tests null handling in addSubquery.
	 */
	@IsTest
	private static void shouldHandleNullSubquery()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.addSubquery(null);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains(FIELD_NAME), 'Should contain Name');
		Assert.isFalse(soql.contains('(SELECT'), 'Should not contain subquery');
	}

	/**
	 * @description Tests locking exclusivity - FOR UPDATE disables ALL ROWS.
	 */
	@IsTest
	private static void shouldDisableAllRowsWhenForUpdate()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.allRows()
				.forUpdate();

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('FOR UPDATE'), 'Should contain FOR UPDATE');
		Assert.isFalse(soql.contains('ALL ROWS'), 'Should not contain ALL ROWS');
	}

	/**
	 * @description Tests locking exclusivity - ALL ROWS disables FOR UPDATE.
	 */
	@IsTest
	private static void shouldDisableForUpdateWhenAllRows()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.forUpdate()
				.allRows();

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('ALL ROWS'), 'Should contain ALL ROWS');
		Assert.isFalse(soql.contains('FOR UPDATE'), 'Should not contain FOR UPDATE');
	}

	/**
	 * @description Tests whereCondition that produces empty SOQL.
	 */
	@IsTest
	private static void shouldHandleEmptyWhereCondition()
	{
		QRY_Condition.AndCondition emptyCondition = new QRY_Condition.AndCondition();

		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.whereCondition(emptyCondition);

		String soql = generator.toSoql();

		Assert.isFalse(soql.contains('WHERE'), 'Should not contain WHERE for empty condition');
	}

	/**
	 * @description Tests havingCondition that produces empty SOQL.
	 */
	@IsTest
	private static void shouldHandleEmptyHavingCondition()
	{
		QRY_Condition.AndCondition emptyCondition = new QRY_Condition.AndCondition();

		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectCount()
				.groupBy('Industry')
				.havingCondition(emptyCondition);

		String soql = generator.toSoql();

		Assert.isFalse(soql.contains('HAVING'), 'Should not contain HAVING for empty condition');
	}

	/**
	 * @description Tests ORDER BY with all null orderBy entries.
	 */
	@IsTest
	private static void shouldHandleAllNullOrderByEntries()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.orderBy((QRY_Generator.OrderBy)null)
				.orderBy((QRY_Generator.OrderBy)null);

		String soql = generator.toSoql();

		Assert.isFalse(soql.contains('ORDER BY'), 'Should not contain ORDER BY when all entries null');
	}

	/**
	 * @description Tests subquery in field selection with bind registry.
	 */
	@IsTest
	private static void shouldGenerateSubqueryFieldWithBinds()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();

		QRY_Generator subquery = new QRY_Generator(Foobar__c.SObjectType)
				.addField('Id')
				.whereCondition(new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_TEXT, 'Test'));

		QRY_Generator generator = new QRY_Generator(Foobar__c.SObjectType)
				.addField(SEL_Foobar.FIELD_TEXT)
				.addSubquery(subquery);

		String soql = generator.toSoql(registry);

		Assert.isTrue(soql.contains('SELECT'), 'Should contain SELECT');
	}

	/**
	 * @description Tests subquery in field without bind registry.
	 */
	@IsTest
	private static void shouldGenerateSubqueryFieldWithoutBinds()
	{
		QRY_Generator subquery = new QRY_Generator(Foobar__c.SObjectType)
				.addField('Id');

		QRY_Generator generator = new QRY_Generator(Foobar__c.SObjectType)
				.addField(SEL_Foobar.FIELD_TEXT)
				.addSubquery(subquery);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('SELECT'), 'Should contain SELECT');
	}

	/**
	 * @description Tests toSoql with bind registry when no binds needed.
	 */
	@IsTest
	private static void shouldReturnBindRegistryWhenEmpty()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();
		QRY_Generator generator = new QRY_Generator(Foobar__c.SObjectType)
				.addField(SEL_Foobar.FIELD_TEXT);

		generator.toSoql(registry);
		QRY_BindRegistry returnedRegistry = generator.getBindRegistry();

		Assert.isNotNull(returnedRegistry, 'Should return bind registry');
		Assert.areEqual(0, returnedRegistry.size(), 'Should have no binds');
	}

	/**
	 * @description Tests scope conversion for null scope.
	 */
	@IsTest
	private static void shouldHandleNullScope()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.usingScope(null);

		String soql = generator.toSoql();

		Assert.isFalse(soql.contains('USING SCOPE'), 'Should not contain USING SCOPE for null');
	}

	/**
	 * @description Tests condition handling when condition implements BindAware.
	 */
	@IsTest
	private static void shouldHandleBindAwareConditionWithRegistry()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(FIELD_NAME, 'Test');

		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(FIELD_NAME)
				.whereCondition(condition);

		String soql = generator.toSoql(registry);

		Assert.isTrue(soql.contains(':b'), 'Should contain bind reference');
	}

	/**
	 * @description Tests condition handling when condition doesn't implement BindAware.
	 */
	@IsTest
	private static void shouldHandleNonBindAwareCondition()
	{
		QRY_Generator generator = new QRY_Generator(Foobar__c.SObjectType)
				.addField(SEL_Foobar.FIELD_TEXT)
				.whereCondition(new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_TEXT, 'Test'));

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('WHERE'), 'Should contain WHERE clause');
	}

	/**
	 * @description Tests empty WHERE condition produces no WHERE clause.
	 */
	@IsTest
	private static void shouldOmitWhereClauseForEmptyCondition()
	{
		QRY_Condition.AndCondition emptyCondition = new QRY_Condition.AndCondition();
		QRY_Generator generator = new QRY_Generator(Foobar__c.SObjectType)
				.addField(SEL_Foobar.FIELD_TEXT)
				.whereCondition(emptyCondition);

		String soql = generator.toSoql();

		Assert.isFalse(soql.contains('WHERE'), 'Should not contain WHERE for empty condition');
	}

	/**
	 * @description Tests empty HAVING condition produces no HAVING clause.
	 */
	@IsTest
	private static void shouldOmitHavingClauseForEmptyCondition()
	{
		QRY_Condition.AndCondition emptyCondition = new QRY_Condition.AndCondition();
		QRY_Generator generator = new QRY_Generator(Foobar__c.SObjectType)
				.selectCount()
				.groupBy(SEL_Foobar.FIELD_TEXT)
				.havingCondition(emptyCondition);

		String soql = generator.toSoql();

		Assert.isFalse(soql.contains('HAVING'), 'Should not contain HAVING for empty condition');
	}

	/**
	 * @description Tests orderBy list with all null entries produces no ORDER BY clause.
	 */
	@IsTest
	private static void shouldOmitOrderByClauseForAllNullEntries()
	{
		QRY_Generator generator = new QRY_Generator(Foobar__c.SObjectType)
				.addField(SEL_Foobar.FIELD_TEXT)
				.orderBy(null)
				.orderBy(null);

		String soql = generator.toSoql();

		Assert.isFalse(soql.contains('ORDER BY'), 'Should not contain ORDER BY for all null entries');
	}

	/**
	 * @description Tests empty WHERE condition with bind registry produces no WHERE clause.
	 */
	@IsTest
	private static void shouldOmitWhereClauseForEmptyConditionWithRegistry()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();
		QRY_Condition.AndCondition emptyCondition = new QRY_Condition.AndCondition();
		QRY_Generator generator = new QRY_Generator(Foobar__c.SObjectType)
				.addField(SEL_Foobar.FIELD_TEXT)
				.whereCondition(emptyCondition);

		String soql = generator.toSoql(registry);

		Assert.isFalse(soql.contains('WHERE'), 'Should not contain WHERE for empty condition with registry');
	}

	/**
	 * @description Tests empty HAVING condition with bind registry produces no HAVING clause.
	 */
	@IsTest
	private static void shouldOmitHavingClauseForEmptyConditionWithRegistry()
	{
		QRY_BindRegistry registry = new QRY_BindRegistry();
		QRY_Condition.AndCondition emptyCondition = new QRY_Condition.AndCondition();
		QRY_Generator generator = new QRY_Generator(Foobar__c.SObjectType)
				.selectCount()
				.groupBy(SEL_Foobar.FIELD_TEXT)
				.havingCondition(emptyCondition);

		String soql = generator.toSoql(registry);

		Assert.isFalse(soql.contains('HAVING'), 'Should not contain HAVING for empty condition with registry');
	}

	/**
	 * @description Tests that SoqlOptions.wildcardStringsInLikeOperators is threaded through to conditions.
	 */
	@IsTest
	private static void shouldApplyWildcardOptionToLikeCondition()
	{
		QRY_Condition.SoqlOptions options = new QRY_Condition.SoqlOptions();
		options.wildcardStringsInLikeOperators = true;

		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition
				(
						FIELD_NAME,
						QRY_Condition.Operator.LIKE_X,
						'Test'
				);

		QRY_Generator generator = new QRY_Generator()
				.addField(FIELD_NAME)
				.fromObject(TEST_OBJECT)
				.whereCondition(condition);

		String soql = generator.toSoql(options);

		Assert.isTrue(soql.contains('%Test%'), 'Should wrap LIKE value with wildcards when option is enabled');
	}

	/**
	 * @description Tests that SoqlOptions.wildcardStringsInLikeOperators is threaded through with bind registry.
	 */
	@IsTest
	private static void shouldApplyWildcardOptionToLikeConditionWithRegistry()
	{
		QRY_Condition.SoqlOptions options = new QRY_Condition.SoqlOptions();
		options.wildcardStringsInLikeOperators = true;

		QRY_BindRegistry registry = new QRY_BindRegistry();
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition
				(
						FIELD_NAME,
						QRY_Condition.Operator.LIKE_X,
						'Test'
				);

		QRY_Generator generator = new QRY_Generator()
				.addField(FIELD_NAME)
				.fromObject(TEST_OBJECT)
				.whereCondition(condition);

		generator.toSoql(registry, options);

		Map<String, Object> bindMap = registry.getMap();
		Assert.isFalse(bindMap.isEmpty(), 'Should have bind variables');

		Object boundValue = bindMap.values()[0];
		Assert.areEqual('%Test%', boundValue, 'Bound value should have wildcards when option is enabled');
	}

	/**
	 * @description Tests that default options do not add wildcards to LIKE conditions.
	 */
	@IsTest
	private static void shouldNotApplyWildcardsByDefault()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition
				(
						FIELD_NAME,
						QRY_Condition.Operator.LIKE_X,
						'Test'
				);

		QRY_Generator generator = new QRY_Generator()
				.addField(FIELD_NAME)
				.fromObject(TEST_OBJECT)
				.whereCondition(condition);

		String soql = generator.toSoql();

		Assert.isFalse(soql.contains('%Test%'), 'Should not wrap LIKE value with wildcards by default');
		Assert.isTrue(soql.contains('\'Test\''), 'Should contain unwrapped literal');
	}

	/**
	 * @description Tests that SoqlOptions.escapeSingleQuotes is threaded through to literal rendering.
	 */
	@IsTest
	private static void shouldEscapeSingleQuotesByDefault()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition
				(
						FIELD_NAME,
						QRY_Condition.Operator.EQUALS,
						'O\'Brien'
				);

		QRY_Generator generator = new QRY_Generator()
				.addField(FIELD_NAME)
				.fromObject(TEST_OBJECT)
				.whereCondition(condition);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('O\\\'Brien'), 'Should escape single quotes by default');
	}

	/**
	 * @description Tests that SoqlOptions.escapeSingleQuotes=false is respected when passed through options.
	 */
	@IsTest
	private static void shouldRespectDisabledEscapeSingleQuotes()
	{
		QRY_Condition.SoqlOptions options = new QRY_Condition.SoqlOptions();
		options.escapeSingleQuotes = false;

		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition
				(
						FIELD_NAME,
						QRY_Condition.Operator.EQUALS,
						'O\'Brien'
				);

		QRY_Generator generator = new QRY_Generator()
				.addField(FIELD_NAME)
				.fromObject(TEST_OBJECT)
				.whereCondition(condition);

		String soql = generator.toSoql(options);

		Assert.isTrue(soql.contains('O\'Brien'), 'Should not escape single quotes when option is disabled');
	}

	/**
	 * @description Tests selectX alias delegates to addField.
	 */
	@IsTest
	private static void shouldGenerateQueryWithSelectXAlias()
	{
		QRY_Generator generator = new QRY_Generator()
				.selectX(FIELD_NAME)
				.fromObject(TEST_OBJECT);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains(FIELD_NAME), 'selectX should add field to SELECT clause');
	}

	/**
	 * @description Tests fromX alias delegates to fromObject.
	 */
	@IsTest
	private static void shouldGenerateQueryWithFromXAlias()
	{
		QRY_Generator generator = new QRY_Generator()
				.addField(FIELD_NAME)
				.fromX(TEST_OBJECT);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('FROM ' + TEST_OBJECT), 'fromX should set FROM clause');
	}

	/**
	 * @description Tests whereX alias delegates to whereCondition.
	 */
	@IsTest
	private static void shouldGenerateQueryWithWhereXAlias()
	{
		QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition
				(
						FIELD_NAME,
						QRY_Condition.Operator.EQUALS,
						'Test'
				);

		QRY_Generator generator = new QRY_Generator()
				.addField(FIELD_NAME)
				.fromObject(TEST_OBJECT)
				.whereX(condition);

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('WHERE'), 'whereX should set WHERE clause');
	}

	/**
	 * @description Verifies the aggregate clause emits a grouped-and-aliased-projected expression once:
	 * the GROUP BY echo is suppressed because the aliased projection already covers it.
	 */
	@IsTest
	private static void aggregateGroupedAndAliasProjectedExpressionEmittedOnce()
	{
		String monthExpression = 'CALENDAR_MONTH(CreatedDate)';

		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(monthExpression + ' createdMonth')
				.selectCount('Id')
				.groupBy(monthExpression);

		String selectClause = generator.toSoql().substringBetween('SELECT ', ' FROM');

		Assert.areEqual('COUNT(Id) count_Id, ' + monthExpression + ' createdMonth', selectClause, 'Grouped-and-aliased-projected expression must appear once in SELECT');
	}

	/**
	 * @description Regression guard: a plain grouped field with no aliased projection is still echoed
	 * into the aggregate SELECT clause.
	 */
	@IsTest
	private static void aggregatePlainGroupedFieldStillEchoedIntoSelect()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectCount('Id')
				.groupBy('Industry');

		String selectClause = generator.toSoql().substringBetween('SELECT ', ' FROM');

		Assert.areEqual('COUNT(Id) count_Id, Industry', selectClause, 'Plain grouped field must still be echoed into SELECT');
	}

	/**
	 * @description Regression guard: a GROUPING() projection and its grouped field are both preserved
	 * in the aggregate SELECT clause after the de-dup change.
	 */
	@IsTest
	private static void aggregateGroupingExpressionPreservedWithDedup()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectCount('Id')
				.groupBy('Industry')
				.grouping('Industry')
				.rollup();

		String selectClause = generator.toSoql().substringBetween('SELECT ', ' FROM');

		Assert.areEqual('COUNT(Id) count_Id, Industry, GROUPING(Industry)', selectClause, 'GROUPING() and its grouped field must both be emitted');
	}
}