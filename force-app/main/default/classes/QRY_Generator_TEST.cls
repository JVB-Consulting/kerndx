// SPDX-License-Identifier: Apache-2.0
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
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
@IsTest(seeAllData=false isParallel=true)
private class QRY_Generator_TEST
{
	/**
	 * @description Test object name.
	 */
	private static final String TEST_OBJECT = 'Account';

	/**
	 * @description The field most tests select, sort by or count. The tests check the generated query text for it.
	 */
	private static final String FIELD_NAME = 'Name';

	/**
	 * @description Name of the Custom Label that holds the message for a text the generator refuses where it expects a
	 * field name or an object name. The message names the method that refused the text.
	 */
	private static final String FIELD_NAME_REFUSED_LABEL = 'QueryBuilder_FieldName_NotAllowed';

	/**
	 * @description Alias given to the sum that the aggregate selection test builds.
	 */
	private static final String SUM_ALIAS = 'total';

	/**
	 * @description The longest field text, and the longest item of a list, that the field name checks read.
	 */
	private static final Integer LONGEST_FIELD_TEXT_LENGTH = 500;

	/**
	 * @description The longest sort list or group list that the field name checks read.
	 */
	private static final Integer LONGEST_FIELD_LIST_LENGTH = 16000;

	/**
	 * @description The most fields an ORDER BY clause takes.
	 */
	private static final Integer MOST_SORT_ITEMS = 32;

	/**
	 * @description The length of a very long crafted text. Without a length limit, a pattern that reads a text this long
	 * stops the transaction with an error no code can catch.
	 */
	private static final Integer VERY_LONG_TEXT_LENGTH = 300000;

	/**
	 * @description The number of items in a long crafted list. Without a check of one item at a time, a pattern that reads
	 * a list this long fails with a stack overflow.
	 */
	private static final Integer MANY_LIST_ITEMS = 300;

	/**
	 * @description The number of dotted names in a long crafted field path. Without a length limit, a pattern that reads a
	 * path this long fails with a stack overflow.
	 */
	private static final Integer MANY_DOTTED_NAMES = 1000;

	/**
	 * @description A data category group name that the generator accepts.
	 */
	private static final String CATEGORY_GROUP = 'Geography__c';

	/**
	 * @description A data category name that the generator accepts.
	 */
	private static final String CATEGORY_NAME = 'USA__c';

	/**
	 * @description The generator method that receives each crafted text, so the test can say which method had to refuse it.
	 */
	private static final Map<GeneratorEntry, String> ENTRY_METHOD_NAMES = new Map<GeneratorEntry, String>
	{
			GeneratorEntry.FROM_OBJECT => 'fromObject',
			GeneratorEntry.FROM_X => 'fromX',
			GeneratorEntry.SELECT_COUNT => 'selectCount',
			GeneratorEntry.SELECT_AVG => 'selectAvg',
			GeneratorEntry.SELECT_SUM => 'selectSum',
			GeneratorEntry.SELECT_MIN => 'selectMin',
			GeneratorEntry.SELECT_MAX => 'selectMax',
			GeneratorEntry.SELECT_COUNT_DISTINCT => 'selectCountDistinct',
			GeneratorEntry.GROUPING => 'grouping',
			GeneratorEntry.SELECT_AGGREGATE => 'selectAggregate',
			GeneratorEntry.ORDER_BY => 'OrderBy',
			GeneratorEntry.GROUP_BY => 'groupBy',
			GeneratorEntry.DATA_CATEGORY_FILTER => 'DataCategoryFilter'
	};

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
	 * @description Tests that explicitly aliased aggregate selections accumulate: one query renders COUNT,
	 * MIN and MAX together, each under its caller-supplied alias and in call order, with the GROUP BY
	 * expression echoed into SELECT as usual.
	 */
	@IsTest
	private static void shouldGenerateMultipleAliasedAggregates()
	{
		QRY_Generator generator = new QRY_Generator(Opportunity.SObjectType)
				.selectAggregate(QRY_Generator.Aggregate.COUNT, 'Id', 'rowTotal')
				.selectAggregate(QRY_Generator.Aggregate.MIN, 'CreatedDate', 'firstSeen')
				.selectAggregate(QRY_Generator.Aggregate.MAX, 'CreatedDate', 'lastSeen')
				.groupBy('StageName');

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('COUNT(Id) rowTotal'), 'Should render the aliased COUNT selection');
		Assert.isTrue(soql.contains('MIN(CreatedDate) firstSeen'), 'Should render the aliased MIN selection');
		Assert.isTrue(soql.contains('MAX(CreatedDate) lastSeen'), 'Should render the aliased MAX selection');
		Assert.isTrue(soql.contains('GROUP BY StageName'), 'Should keep the GROUP BY clause');
		Assert.isTrue(soql.indexOf('rowTotal') < soql.indexOf('firstSeen') && soql.indexOf('firstSeen') < soql.indexOf('lastSeen'), 'Selections should render in call order');
	}

	/**
	 * @description Tests that the legacy single aggregate and the aliased selections combine in one
	 * SELECT: the legacy auto-aliased function renders first, then the explicit selections.
	 */
	@IsTest
	private static void shouldCombineLegacyAggregateWithAliasedSelections()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectCount('Id')
				.selectAggregate(QRY_Generator.Aggregate.MAX, 'CreatedDate', 'lastSeen')
				.groupBy('Industry');

		String soql = generator.toSoql();

		Assert.isTrue(soql.contains('COUNT(Id) count_Id'), 'Should keep the legacy auto-aliased aggregate');
		Assert.isTrue(soql.contains('MAX(CreatedDate) lastSeen'), 'Should render the aliased selection alongside it');
		Assert.isTrue(soql.indexOf('count_Id') < soql.indexOf('lastSeen'), 'The legacy aggregate should render before the selections');
	}

	/**
	 * @description Tests that a malformed aggregate alias is rejected: anything other than a bare
	 * identifier (a letter followed by letters, digits or underscores) throws, so a caller-supplied alias
	 * can never smuggle SOQL syntax into the SELECT clause.
	 */
	@IsTest
	private static void shouldRejectMalformedAggregateAlias()
	{
		List<String> malformedAliases = new List<String> {null, '', ' ', 'bad alias', '1leading', 'alias, Name', 'alias FROM Account'};

		for(String malformed : malformedAliases)
		{
			try
			{
				new QRY_Generator(Account.SObjectType).selectAggregate(QRY_Generator.Aggregate.COUNT, 'Id', malformed);
				Assert.fail('A malformed alias should throw: ' + malformed);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
				Assert.isTrue(error.getMessage().contains('alias'), 'The error should name the alias rule');
			}
		}
	}

	/**
	 * @description Tests that an aliased aggregate selection without a field is rejected — every
	 * selection aggregates a concrete field.
	 */
	@IsTest
	private static void shouldRejectBlankFieldForAggregateSelection()
	{
		try
		{
			new QRY_Generator(Account.SObjectType).selectAggregate(QRY_Generator.Aggregate.COUNT, ' ', 'rowTotal');
			Assert.fail('A blank aggregate field should throw');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			Assert.isTrue(error.getMessage().contains('field'), 'The error should name the missing field');
		}
	}

	/**
	 * @description Tests that a padded alias is trimmed rather than rejected — SOQL ignores whitespace
	 * around an alias, so padding must not break callers that predate the validation.
	 */
	@IsTest
	private static void shouldTrimAliasPadding()
	{
		String soql = new QRY_Generator(Account.SObjectType)
				.selectAggregate(QRY_Generator.Aggregate.COUNT, 'Id', ' rowTotal ')
				.groupBy('Industry')
				.toSoql();

		Assert.areEqual('rowTotal', QRY_Generator.validateSelectAlias(' rowTotal '), 'Validation should return the trimmed alias');
		Assert.isTrue(soql.contains('COUNT(Id) rowTotal'), 'The rendered selection should carry the trimmed alias');
	}

	/**
	 * @description Tests that a duplicate aggregate alias is rejected when registered — SOQL treats
	 * aliases case-insensitively, so a case-variant duplicate counts as a collision.
	 */
	@IsTest
	private static void shouldRejectDuplicateAggregateAlias()
	{
		try
		{
			new QRY_Generator(Account.SObjectType)
					.selectAggregate(QRY_Generator.Aggregate.COUNT, 'Id', 'rowTotal')
					.selectAggregate(QRY_Generator.Aggregate.MAX, 'CreatedDate', 'ROWTOTAL');
			Assert.fail('A duplicate alias should throw');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			Assert.isTrue(error.getMessage().contains('alias'), 'The error should name the alias rule');
		}
	}

	/**
	 * @description Tests that a field-less COUNT() combined with aliased selections fails fast at
	 * build — SOQL allows COUNT() only as the sole SELECT entry, and the raw parser error names
	 * neither culprit.
	 */
	@IsTest
	private static void shouldRejectFieldlessCountWithAliasedSelections()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectCount()
				.selectAggregate(QRY_Generator.Aggregate.MAX, 'CreatedDate', 'lastSeen');

		try
		{
			generator.toSoql();
			Assert.fail('A field-less COUNT() combined with aliased selections should throw at build time');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			Assert.isTrue(error.getMessage().contains('COUNT()'), 'The error should name the field-less COUNT()');
		}
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
	 * @description Verifies that an expression that is both grouped and selected under an alias appears only once
	 * in the aggregate clause: the GROUP BY echo is skipped because the aliased entry in the field list already covers it.
	 */
	@IsTest
	private static void aggregateGroupedAndAliasSelectedExpressionAppearsOnce()
	{
		String monthExpression = 'CALENDAR_MONTH(CreatedDate)';

		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.addField(monthExpression + ' createdMonth')
				.selectCount('Id')
				.groupBy(monthExpression);

		String selectClause = generator.toSoql().substringBetween('SELECT ', ' FROM');

		Assert.areEqual('COUNT(Id) count_Id, ' + monthExpression + ' createdMonth', selectClause, 'Expected a grouped expression with its own alias to appear once in SELECT');
	}

	/**
	 * @description Regression guard: a plain grouped field with no aliased entry in the field list is still echoed
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
	 * @description Regression guard: a selected GROUPING() function and its grouped field are both preserved
	 * in the aggregate SELECT clause: neither is treated as a duplicate.
	 */
	@IsTest
	private static void shouldKeepGroupingExpressionAndItsGroupedFieldInAggregateSelect()
	{
		QRY_Generator generator = new QRY_Generator(Account.SObjectType)
				.selectCount('Id')
				.groupBy('Industry')
				.grouping('Industry')
				.rollup();

		String selectClause = generator.toSoql().substringBetween('SELECT ', ' FROM');

		Assert.areEqual('COUNT(Id) count_Id, Industry, GROUPING(Industry)', selectClause, 'GROUPING() and its grouped field must both be emitted');
	}

	/**
	 * @description Proves that every generator method that stores an object name, a field name or a data category name
	 * as text refuses a text that adds more than a name: fromObject and fromX with a WHERE clause or ALL ROWS after the
	 * object name; selectCount, selectAvg, selectSum, selectMin, selectMax, selectCountDistinct, grouping, selectAggregate,
	 * the OrderBy constructor and groupBy with a text that closes the function and adds a FROM clause, or with ALL ROWS;
	 * and the DataCategoryFilter constructor with a group name followed by more of the query, or a category name followed
	 * by a LIMIT. The generator is called directly, not through QRY_Builder, so its own checks must refuse the text. Each
	 * method is tried on its own, so a method that lets a text through fails the test under its own name. A refused text
	 * must raise an IllegalArgumentException that names the method, and must leave the query text as it was. First, the
	 * test proves that a blank name still gives COUNT(), because a blank name is how a caller counts every row.
	 */
	@IsTest
	private static void shouldRefuseCraftedTextInTheGeneratorStoragePoints()
	{
		for(String blankName : new List<String> {null, UTIL_String.EMPTY})
		{
			Assert.areEqual
					(
							'SELECT COUNT() FROM ' + TEST_OBJECT,
							new QRY_Generator().fromObject(TEST_OBJECT).selectCount(blankName).toSoql(),
							'Expected a blank name to count every row'
					);
		}

		Map<String, String> objectTexts = new Map<String, String>
		{
				'an object name followed by a WHERE clause' => TEST_OBJECT + ' WHERE ' + FIELD_NAME + ' != null',
				'an object name followed by ALL ROWS' => TEST_OBJECT + ' ALL ROWS'
		};
		Map<String, String> fieldTexts = new Map<String, String>
		{
				'a text that closes the function and adds a FROM clause' => FIELD_NAME + ') FROM ' + TEST_OBJECT + ' WHERE (' + FIELD_NAME,
				'ALL ROWS' => FIELD_NAME + ' ALL ROWS'
		};
		Map<String, String> dataCategoryTexts = new Map<String, String>
		{
				'a group name followed by a category and an ORDER BY' => CATEGORY_GROUP + ' AT ' + CATEGORY_NAME + ' ORDER BY ' + FIELD_NAME + ' LIMIT 1 X',
				'a category name followed by a LIMIT' => CATEGORY_NAME + ' LIMIT 1'
		};

		for(GeneratorEntry entry : GeneratorEntry.values())
		{
			Map<String, String> craftedTexts = fieldTexts;
			if(entry == GeneratorEntry.FROM_OBJECT || entry == GeneratorEntry.FROM_X)
			{
				craftedTexts = objectTexts;
			}
			else if(entry == GeneratorEntry.DATA_CATEGORY_FILTER)
			{
				craftedTexts = dataCategoryTexts;
			}
			String methodName = ENTRY_METHOD_NAMES.get(entry);
			for(String caseName : craftedTexts.keySet())
			{
				QRY_Generator generator = new QRY_Generator().fromObject(TEST_OBJECT);
				String textBefore = generator.toSoql();
				try
				{
					applyCraftedText(generator, entry, craftedTexts.get(caseName));
					Assert.fail('Expected ' + methodName + ' to refuse ' + caseName + '; the generator wrote: ' + describeRenderedText(generator));
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException for ' + caseName + ', got: ' + error);
					Assert.areEqual(buildRefusalMessage(methodName), error.getMessage(), 'Expected the message to name ' + methodName + ' for ' + caseName);
					Assert.areEqual(textBefore, generator.toSoql(), 'Expected the refused text to leave the query unchanged for ' + caseName);
				}
			}
		}
	}

	/**
	 * @description Proves that each of the six field name checks accepts every text of the shape it allows, and gives the
	 * text back trimmed. A field path is allowed by all six. A date or distance function is allowed by all but the field
	 * path check, including each way Apex writes a number. An aggregate and toLabel are allowed on the field side of a
	 * condition and in a sort list. Directions and nulls orders are allowed in a sort list, and the check used before a
	 * direction is added allows them on every item but the last. Spaces just inside the round brackets of a function are
	 * allowed, and so is a date function around convertTimezone. A field path of 500 characters, the longest the checks
	 * read, is allowed by all six, and a list of 31 such paths and a sort list of 32 items by the list checks. A blank
	 * text is given back for the caller to judge.
	 */
	@IsTest
	private static void shouldAcceptEveryTextEachFieldNameCheckAllows()
	{
		String longestFieldPath = 'a.'.repeat((LONGEST_FIELD_TEXT_LENGTH - 2) / 2) + 'aa';
		List<String> longestPaths = new List<String>();
		while((longestPaths.size() + 1) * (LONGEST_FIELD_TEXT_LENGTH + 2) <= LONGEST_FIELD_LIST_LENGTH)
		{
			longestPaths.add(longestFieldPath);
		}
		List<String> fieldPaths = new List<String> {FIELD_NAME, 'abc__Field__c', 'abc__Parent__r.abc__Field__c', 'A1_b', 'What.Name', ' Name ', longestFieldPath};
		List<String> fieldExpressions = new List<String>
		{
				'calendar_year(CreatedDate)',
				'CALENDAR_YEAR( CreatedDate )',
				'HOUR_IN_DAY(convertTimezone(CreatedDate))',
				'day_only( CONVERTTIMEZONE( Owner.CreatedDate ) )',
				'DISTANCE(abc__Loc__c, GEOLOCATION(37.7749,-122.4194), \'mi\')',
				'DISTANCE(Loc__c, GEOLOCATION(1E-7,1E+12), \'km\')',
				'DISTANCE(Loc__c, GEOLOCATION(45.000000000000,-122.418), \'mi\')',
				'DISTANCE(Loc__c, GEOLOCATION(null,10), \'mi\')',
				'DISTANCE( Loc__c, GEOLOCATION( 1, 1 ), \'mi\' )'
		};
		List<String> conditionFields = new List<String> {'SUM(Amount)', 'count(Id)', 'COUNT_DISTINCT(abc__Field__c)', 'toLabel(Status)', 'SUM( Amount )', 'toLabel( Status )'};
		List<String> fieldLists = new List<String>
		{
				'HOUR_IN_DAY(convertTimezone(CreatedDate)), DISTANCE(Loc__c, GEOLOCATION(1,2), \'km\'), Name',
				String.join(longestPaths, ', ')
		};
		List<String> sortLists = new List<String> {'Name desc nulls last, Id', (FIELD_NAME + ' DESC, ').repeat(MOST_SORT_ITEMS - 1) + FIELD_NAME};

		Map<FieldNameCheck, List<String>> acceptedTexts = new Map<FieldNameCheck, List<String>>();
		acceptedTexts.put(FieldNameCheck.FIELD_PATH, fieldPaths);
		acceptedTexts.put(FieldNameCheck.FIELD_EXPRESSION, joinLists(new List<List<String>> {fieldPaths, fieldExpressions}));
		acceptedTexts.put(FieldNameCheck.CONDITION_FIELD, joinLists(new List<List<String>> {fieldPaths, fieldExpressions, conditionFields}));
		acceptedTexts.put
				(
						FieldNameCheck.SORT_LIST,
						joinLists(new List<List<String>> {fieldPaths, fieldExpressions, conditionFields, fieldLists, sortLists, new List<String> {'COUNT(Id) DESC'}})
				);
		acceptedTexts.put
				(
						FieldNameCheck.SORT_LIST_BEFORE_DIRECTION,
						joinLists
								(
										new List<List<String>>
										{
												fieldPaths, fieldExpressions, conditionFields, fieldLists, sortLists, new List<String> {'Name, Industry', 'Name DESC, Industry'}
										}
								)
				);
		acceptedTexts.put(FieldNameCheck.GROUP_LIST, joinLists(new List<List<String>> {fieldPaths, fieldExpressions, fieldLists, new List<String> {'Name, Industry'}}));

		for(FieldNameCheck check : FieldNameCheck.values())
		{
			for(String acceptedText : acceptedTexts.get(check))
			{
				Assert.areEqual(acceptedText.trim(), runFieldNameCheck(check, acceptedText), 'Expected ' + check.name() + ' to accept and trim: ' + acceptedText);
			}
			Assert.isNull(runFieldNameCheck(check, null), 'Expected ' + check.name() + ' to give back a null text for the caller to judge');
			Assert.areEqual(UTIL_String.EMPTY, runFieldNameCheck(check, '  '), 'Expected ' + check.name() + ' to give back a blank text trimmed, for the caller to judge');
		}
	}

	/**
	 * @description Proves that each of the six field name checks refuses every text that could add to the query or that
	 * is not the shape it allows. The refused texts add a LIMIT, ALL ROWS or an OR, open or close a bracket or a quote,
	 * start or end with a dot or a comma, start with a digit or an underscore, hide a LIMIT after a line break, carry a
	 * wrong distance unit or a broken number, wrap more than a name in a function, or repeat a direction. They also put a
	 * LIMIT or an OR around convertTimezone, use convertTimezone outside a date function, leave a list item empty, or are
	 * longer than the checks read: one name of 501 characters, a very long path or text, a long list whose last item
	 * ends with ALL ROWS, and a list of valid names that is longer than 16,000 characters. The field path
	 * check also refuses a function, the group check refuses an aggregate and toLabel, and the check used before a
	 * direction is added refuses a direction or nulls order on the last item. Each refusal must be an
	 * IllegalArgumentException with the message that names the method.
	 */
	@IsTest
	private static void shouldRefuseEveryTextEachFieldNameCheckDoesNotAllow()
	{
		List<String> craftedTexts = new List<String>
		{
				'Name LIMIT 1',
				'Name ALL ROWS',
				'Id != null OR Name',
				'Name)',
				'(Name',
				'Name\'',
				'Name,',
				'.Name',
				'Name.',
				'A..B',
				'1Name',
				'_Name',
				'Name\nLIMIT 1',
				'DISTANCE(Loc__c, GEOLOCATION(1,1), \'mx\')',
				'DISTANCE(Loc__c, GEOLOCATION(1E,1), \'mi\')',
				'DISTANCE(Loc__c, GEOLOCATION(1e-7 OR 1,1), \'mi\')',
				'DISTANCE(Loc__c, GEOLOCATION(nullx,1), \'mi\')',
				'CALENDAR_YEAR(Name LIMIT 1)',
				'SUM(Amount) FROM Account',
				'SUM(Amount LIMIT 1)',
				'COUNT()',
				'Name DESC DESC',
				'Name NULLS',
				'HOUR_IN_DAY(convertTimezone(CreatedDate) LIMIT 1)',
				'HOUR_IN_DAY(convertTimezone(CreatedDate)) OR Id != null',
				'HOUR_IN_DAY(convertTimezone(convertTimezone(CreatedDate)))',
				'convertTimezone(CreatedDate)',
				'SUM( Amount LIMIT 1 )',
				'Name,,Id',
				'Name, , Id',
				'a'.repeat(LONGEST_FIELD_TEXT_LENGTH + 1),
				'a.'.repeat(MANY_DOTTED_NAMES) + 'a ALL ROWS',
				'a'.repeat(VERY_LONG_TEXT_LENGTH) + ' ALL ROWS',
				(FIELD_NAME + ', ').repeat(MANY_LIST_ITEMS) + FIELD_NAME + ' ALL ROWS',
				(FIELD_NAME + ', ').repeat(LONGEST_FIELD_LIST_LENGTH / (FIELD_NAME.length() + 2) + 1) + FIELD_NAME
		};
		List<String> aggregateAndLabelTexts = new List<String> {'SUM(Amount)', 'toLabel(Status)'};

		Map<FieldNameCheck, List<String>> refusedTexts = new Map<FieldNameCheck, List<String>>();
		refusedTexts.put(FieldNameCheck.FIELD_PATH, joinLists(new List<List<String>> {craftedTexts, aggregateAndLabelTexts, new List<String> {'CALENDAR_YEAR(CreatedDate)'}}));
		refusedTexts.put(FieldNameCheck.FIELD_EXPRESSION, joinLists(new List<List<String>> {craftedTexts, aggregateAndLabelTexts}));
		refusedTexts.put(FieldNameCheck.CONDITION_FIELD, craftedTexts);
		refusedTexts.put(FieldNameCheck.SORT_LIST, craftedTexts);
		refusedTexts.put(FieldNameCheck.SORT_LIST_BEFORE_DIRECTION, joinLists(new List<List<String>> {craftedTexts, new List<String> {'Name DESC', 'Name, Industry NULLS LAST'}}));
		refusedTexts.put(FieldNameCheck.GROUP_LIST, joinLists(new List<List<String>> {craftedTexts, aggregateAndLabelTexts}));

		for(FieldNameCheck check : FieldNameCheck.values())
		{
			String methodName = check.name().toLowerCase();
			for(String refusedText : refusedTexts.get(check))
			{
				try
				{
					String acceptedText = runFieldNameCheck(check, refusedText);
					Assert.fail('Expected ' + check.name() + ' to refuse: ' + refusedText + '; it gave back: ' + acceptedText);
				}
				catch(Exception error)
				{
					Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException from ' + check.name() + ' for: ' + refusedText);
					Assert.areEqual(buildRefusalMessage(methodName), error.getMessage(), 'Expected the message to name the method for ' + check.name() + ': ' + refusedText);
				}
			}
		}
	}

	/**
	 * @description Builds the message the generator gives when it refuses a text. The label is read by its name, with the
	 * package namespace, and the method name is put into it.
	 *
	 * @param methodName The method the message must name
	 *
	 * @return The expected message
	 */
	private static String buildRefusalMessage(String methodName)
	{
		return String.format(System.Label.get(UTIL_System.getManagedPackageNamespace(), FIELD_NAME_REFUSED_LABEL), new List<Object> {methodName});
	}

	/**
	 * @description Puts several lists of texts into one new list, in order.
	 *
	 * @param lists The lists to put together
	 *
	 * @return One list that holds every text of every list
	 */
	private static List<String> joinLists(List<List<String>> lists)
	{
		List<String> joined = new List<String>();
		for(List<String> texts : lists)
		{
			joined.addAll(texts);
		}
		return joined;
	}

	/**
	 * @description Runs the field name check the value names on a text. The method name given to the check is the value's
	 * name in lower case, so a test can find it in the message.
	 *
	 * @param check The field name check to run
	 * @param text The text to check
	 *
	 * @return What the check gives back
	 */
	private static String runFieldNameCheck(FieldNameCheck check, String text)
	{
		String methodName = check.name().toLowerCase();
		switch on check
		{
			when FIELD_PATH
			{
				return QRY_Generator.validateFieldPath(text, methodName);
			}
			when FIELD_EXPRESSION
			{
				return QRY_Generator.validateFieldExpression(text, methodName);
			}
			when CONDITION_FIELD
			{
				return QRY_Generator.validateConditionField(text, methodName);
			}
			when SORT_LIST
			{
				return QRY_Generator.validateSortList(text, methodName);
			}
			when SORT_LIST_BEFORE_DIRECTION
			{
				return QRY_Generator.validateSortListBeforeDirection(text, methodName);
			}
			when else
			{
				return QRY_Generator.validateGroupList(text, methodName);
			}
		}
	}

	/**
	 * @description Passes a crafted text to the generator method the entry names. For DataCategoryFilter the text is tried
	 * first as the group name, then as the only category name, each beside a valid name. It raises the refusal only when
	 * both places refuse the text, so a check missing from either place fails the test.
	 *
	 * @param generator The generator to give the text to
	 * @param entry The method that receives the text
	 * @param craftedText The text that is not a name
	 */
	private static void applyCraftedText(QRY_Generator generator, GeneratorEntry entry, String craftedText)
	{
		switch on entry
		{
			when FROM_OBJECT
			{
				generator.fromObject(craftedText);
			}
			when FROM_X
			{
				generator.fromX(craftedText);
			}
			when SELECT_COUNT
			{
				generator.selectCount(craftedText);
			}
			when SELECT_AVG
			{
				generator.selectAvg(craftedText);
			}
			when SELECT_SUM
			{
				generator.selectSum(craftedText);
			}
			when SELECT_MIN
			{
				generator.selectMin(craftedText);
			}
			when SELECT_MAX
			{
				generator.selectMax(craftedText);
			}
			when SELECT_COUNT_DISTINCT
			{
				generator.selectCountDistinct(craftedText);
			}
			when GROUPING
			{
				generator.grouping(craftedText);
			}
			when SELECT_AGGREGATE
			{
				generator.selectAggregate(QRY_Generator.Aggregate.SUM, craftedText, SUM_ALIAS);
			}
			when ORDER_BY
			{
				new QRY_Generator.OrderBy(craftedText);
			}
			when GROUP_BY
			{
				generator.groupBy(craftedText);
			}
			when DATA_CATEGORY_FILTER
			{
				try
				{
					new QRY_Generator.DataCategoryFilter(craftedText, QRY_Generator.DataCategoryOperator.AT, new List<String> {CATEGORY_NAME});
				}
				catch(IllegalArgumentException groupNameRefused)
				{
					new QRY_Generator.DataCategoryFilter(CATEGORY_GROUP, QRY_Generator.DataCategoryOperator.AT, new List<String> {craftedText});
				}
			}
		}
	}

	/**
	 * @description Gives the query text a generator writes, or the error it raises while writing it. It never raises an
	 * error itself, so that a test can put its answer in a failure message.
	 *
	 * @param generator The generator whose query text to write
	 *
	 * @return The query text, or a sentence that names the error
	 */
	private static String describeRenderedText(QRY_Generator generator)
	{
		try
		{
			return generator.toSoql();
		}
		catch(Exception error)
		{
			return 'no text, it failed with ' + error.getTypeName() + ': ' + error.getMessage();
		}
	}

	/**
	 * @description The generator method that receives a crafted text in the test. Each value names one method;
	 * applyCraftedText calls it.
	 */
	private enum GeneratorEntry
	{
		/**
		 * @description fromObject(text), which sets the object of the FROM clause.
		 */
		FROM_OBJECT,
		/**
		 * @description fromX(text), which also sets the object of the FROM clause.
		 */
		FROM_X,
		/**
		 * @description selectCount(text).
		 */
		SELECT_COUNT,
		/**
		 * @description selectAvg(text).
		 */
		SELECT_AVG,
		/**
		 * @description selectSum(text).
		 */
		SELECT_SUM,
		/**
		 * @description selectMin(text).
		 */
		SELECT_MIN,
		/**
		 * @description selectMax(text).
		 */
		SELECT_MAX,
		/**
		 * @description selectCountDistinct(text).
		 */
		SELECT_COUNT_DISTINCT,
		/**
		 * @description grouping(text), which adds GROUPING(text) to the SELECT clause.
		 */
		GROUPING,
		/**
		 * @description selectAggregate with SUM, the text as the field and a valid alias.
		 */
		SELECT_AGGREGATE,
		/**
		 * @description The OrderBy constructor that takes the text as a sort list.
		 */
		ORDER_BY,
		/**
		 * @description groupBy(text), which adds the text to the GROUP BY clause.
		 */
		GROUP_BY,
		/**
		 * @description The DataCategoryFilter constructor, with the text as the group name and then as a category name.
		 */
		DATA_CATEGORY_FILTER
	}
	/**
	 * @description One of the six field name checks in QRY_Generator. Each value names the shape of text its check
	 * allows; runFieldNameCheck calls it.
	 */
	private enum FieldNameCheck
	{
		/**
		 * @description validateFieldPath: one name, or names joined by dots.
		 */
		FIELD_PATH,
		/**
		 * @description validateFieldExpression: a field path, or a date or distance function around one.
		 */
		FIELD_EXPRESSION,
		/**
		 * @description validateConditionField: a field expression, an aggregate or toLabel.
		 */
		CONDITION_FIELD,
		/**
		 * @description validateSortList: sort items joined by commas, each with a direction and a nulls order if wanted.
		 */
		SORT_LIST,
		/**
		 * @description validateSortListBeforeDirection: the same, but the last item has no direction and no nulls order.
		 */
		SORT_LIST_BEFORE_DIRECTION,
		/**
		 * @description validateGroupList: field expressions joined by commas.
		 */
		GROUP_LIST
	}
}