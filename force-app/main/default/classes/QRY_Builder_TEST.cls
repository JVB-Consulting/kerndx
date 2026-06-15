// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for QRY_Builder adapter class.
 * Verifies the QRY_Builder API correctly delegates to the underlying UTIL_Query infrastructure.
 *
 * @see QRY_Builder
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date February 2026, June 2026
 */
@IsTest(SeeAllData=false IsParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity,PMD.NcssTypeCount')
private class QRY_Builder_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'QRY_Builder_TEST-admin';
	private static final String FIELD_DATE = SEL_Foobar.FIELD_DATE;
	private static final String FIELD_EMAIL = SEL_Foobar.FIELD_EMAIL;
	private static final String FIELD_ID = 'Id';
	private static final String FIELD_LOOKUP = SEL_Foobar.FIELD_LOOKUP;
	private static final String FIELD_NAME = SEL_Foobar.FIELD_NAME;
	private static final String FIELD_NUMBER_DECIMAL = SEL_Foobar.FIELD_DECIMAL;
	private static final String FIELD_NUMBER_INTEGER = SEL_Foobar.FIELD_INTEGER;
	private static final String FIELD_PICKLIST = SEL_Foobar.FIELD_PICKLIST;
	private static final String FIELD_TEXT = SEL_Foobar.FIELD_TEXT;
	private static final String FIELD_TEXTAREA = SEL_Foobar.FIELD_TEXT_AREA;
	private static final String OBJECT_NAME = SEL_Foobar.OBJECT_NAME;

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
	 * @description Tests that the query builder constructs a basic SOQL query with SELECT, FROM, and WHERE clauses.
	 */
	@IsTest
	private static void buildsBasicQueryWithSelectFromAndWhere()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<SObjectField> {Foobar__c.Name})
					.condition(Foobar__c.Name).equals('Test Foobar')
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('FROM ' + OBJECT_NAME), 'Should contain FROM clause');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_NAME + ' = \'Test Foobar\''), 'Should contain WHERE clause');
		}
	}

	/**
	 * @description Tests that the query builder handles complex conditions with AND and OR logic.
	 */
	@IsTest
	private static void buildsComplexConditionsWithAndOrLogic()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Text__c).equals('TestValue')
					.andCondition(Foobar__c.TextArea__c).notEquals('Other')
					.orCondition(Foobar__c.Email__c).isNotNull()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase(FIELD_TEXT + ' = \'TestValue\''), 'Should have equals');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_TEXTAREA + ' != \'Other\''), 'Should have not equals');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_EMAIL + ' != NULL'), 'Should have email not null condition');
			Assert.isTrue(soql.containsIgnoreCase(' OR '), 'Should have OR operator');
		}
	}

	/**
	 * @description Tests that the query builder adds ORDER BY and LIMIT clauses correctly.
	 */
	@IsTest
	private static void buildsQueryWithOrderByAndLimit()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.NumberDecimal__c).descending()
					.withLimit(10)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NUMBER_DECIMAL + ' DESC'), 'Should sort descending');
			Assert.isTrue(soql.containsIgnoreCase('LIMIT 10'), 'Should limit');
		}
	}

	/**
	 * @description Tests that the condition builder supports all comparison operators.
	 */
	@IsTest
	private static void conditionBuilderSupportsAllOperators()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType);

			query.condition(Foobar__c.Name).contains('Test')
					.andCondition(Foobar__c.Picklist__c).isIn(new Set<Object> {'Option1', 'Option2'})
					.andCondition(Foobar__c.Text__c).isIn(new List<Object> {'Value1'})
					.andCondition(Foobar__c.NumberInteger__c).greaterThan(100)
					.andCondition(Foobar__c.NumberInteger__c).lessThan(1000)
					.andCondition(Foobar__c.NumberInteger__c).greaterThanOrEquals(101)
					.andCondition(Foobar__c.NumberInteger__c).lessThanOrEquals(999)
					.andCondition(Foobar__c.TextArea__c).isNull()
					.andCondition(Foobar__c.Email__c).isNotNull()
					.andCondition(Foobar__c.Text__c).startsWith('Start')
					.andCondition(Foobar__c.Text__c).endsWith('End')
					.andCondition(Foobar__c.Lookup__c).notInSet(new Set<Object> {UserInfo.getUserId()});

			String soql = query.toSoql();
			Assert.isTrue(soql.containsIgnoreCase(FIELD_NAME + ' LIKE \'%Test%\''), 'Contains mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_PICKLIST + ' IN (\'Option1\',\'Option2\')'), 'IN set mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_TEXT + ' IN (\'Value1\')'), 'IN list mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_NUMBER_INTEGER + ' > 100'), 'Greater than mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_NUMBER_INTEGER + ' < 1000'), 'Less than mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_NUMBER_INTEGER + ' >= 101'), 'Greater equals mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_NUMBER_INTEGER + ' <= 999'), 'Less equals mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_TEXTAREA + ' = NULL'), 'Is null mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_EMAIL + ' != NULL'), 'Is not null mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_TEXT + ' LIKE \'Start%\''), 'Starts with mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_TEXT + ' LIKE \'%End\''), 'Ends with mismatch');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_LOOKUP + ' NOT IN'), 'Not in mismatch');
		}
	}

	/**
	 * @description Tests that toList() executes the query and returns results.
	 */
	@IsTest
	private static void toListExecutesQuery()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.toList();

			Assert.areEqual(1, results.size(), 'Should return inserted record');
		}
	}

	/**
	 * @description Tests that getFirst() returns a single record.
	 */
	@IsTest
	private static void getFirstReturnsSingleRecord()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			SObject result = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.getFirst();

			Assert.isNotNull(result, 'Should return record');
			Assert.areEqual(record.Id, result.Id, 'Should return correct record');
		}
	}

	/**
	 * @description Tests that getFirst() returns null when no records match.
	 */
	@IsTest
	private static void getFirstReturnsNullWhenNoMatch()
	{
		System.runAs(getTestAdmin())
		{
			SObject result = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).equals('NonExistent_' + System.currentTimeMillis())
					.getFirst();

			Assert.isNull(result, 'Should return null when no match');
		}
	}

	/**
	 * @description Tests that count() returns the correct record count.
	 */
	@IsTest
	private static void countReturnsRecordCount()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(3);

			Integer count = QRY_Builder.selectFrom(Foobar__c.SObjectType).count();

			Assert.isTrue(count >= 3, 'Should count at least inserted records');
		}
	}

	/**
	 * @description Tests that exists() returns true when records exist.
	 */
	@IsTest
	private static void existsReturnsTrueWhenRecordsExist()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Boolean exists = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.exists();

			Assert.isTrue(exists, 'Should return true when record exists');
		}
	}

	/**
	 * @description Tests that exists() returns false when no records exist.
	 */
	@IsTest
	private static void existsReturnsFalseWhenNoRecords()
	{
		System.runAs(getTestAdmin())
		{
			Boolean exists = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).equals('NonExistent_' + System.currentTimeMillis())
					.exists();

			Assert.isFalse(exists, 'Should return false when no match');
		}
	}

	/**
	 * @description Tests that asMap() returns results as Map<Id, SObject>.
	 */
	@IsTest
	private static void asMapReturnsIdMap()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Map<Id, SObject> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.asMap();

			Assert.isTrue(resultMap.containsKey(record.Id), 'Map should contain record Id');
		}
	}

	/**
	 * @description Tests that asIdSet() returns a Set of record Ids.
	 */
	@IsTest
	private static void asIdSetReturnsIdSet()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Set<Id> idSet = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.asIdSet();

			Assert.isTrue(idSet.contains(record.Id), 'Set should contain record Id');
		}
	}

	/**
	 * @description Tests that asIdList() returns a List of record Ids.
	 */
	@IsTest
	private static void asIdListReturnsIdList()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<Id> idList = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.asIdList();

			Assert.isTrue(idList.contains(record.Id), 'List should contain record Id');
		}
	}

	/**
	 * @description Tests that asMapById(SObjectField) returns a Map keyed by the specified Id field.
	 */
	@IsTest
	private static void asMapByIdReturnsMapKeyedByField()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();

			Test.startTest();
			Map<Id, SObject> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Lookup__c)
					.condition(Foobar__c.Id).equals(child.Id)
					.asMapById(Foobar__c.Lookup__c);
			Test.stopTest();

			Assert.areEqual(1, resultMap.size(), 'Map should contain one entry keyed by parent Id');
			Assert.isTrue(resultMap.containsKey(parent.Id), 'Map should contain parent Id as key');
			Assert.areEqual(child.Id, resultMap.get(parent.Id).Id, 'Value should be the child record');
		}
	}

	/**
	 * @description Tests that asMapById(String) returns a Map keyed by the specified Id field name.
	 */
	@IsTest
	private static void asMapByIdStringReturnsMapKeyedByFieldName()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();

			Test.startTest();
			Map<Id, SObject> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Lookup__c)
					.condition(Foobar__c.Id).equals(child.Id)
					.asMapById(FIELD_LOOKUP);
			Test.stopTest();

			Assert.areEqual(1, resultMap.size(), 'Map should contain one entry keyed by parent Id');
			Assert.isTrue(resultMap.containsKey(parent.Id), 'Map should contain parent Id as key from string overload');
		}
	}

	/**
	 * @description Tests that asMapById returns an empty map when the query yields no results.
	 */
	@IsTest
	private static void asMapByIdReturnsEmptyMapWhenNoResults()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Map<Id, SObject> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Lookup__c)
					.condition(Foobar__c.Name).equals('NonExistent_XYZ_12345')
					.asMapById(Foobar__c.Lookup__c);
			Test.stopTest();

			Assert.isTrue(resultMap.isEmpty(), 'Map should be empty when no results match');
		}
	}

	/**
	 * @description Tests that asMapByString(SObjectField) returns a Map keyed by the specified String field.
	 * Uses Name field because Foobar__c.Text__c is overwritten by TRG_SetFoobarDefaults during inserts in test context.
	 */
	@IsTest
	private static void asMapByStringReturnsMapKeyedByField()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Name, 'UniqueName-AAA')
					.build();

			Test.startTest();
			Map<String, SObject> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Name)
					.condition(Foobar__c.Id).equals(record.Id)
					.asMapByString(Foobar__c.Name);
			Test.stopTest();

			Assert.areEqual(1, resultMap.size(), 'Map should contain one entry');
			Assert.isTrue(resultMap.containsKey('UniqueName-AAA'), 'Map should contain string key with preserved casing');
			Assert.areEqual(record.Id, resultMap.get('UniqueName-AAA').Id, 'Value should be the inserted record');
		}
	}

	/**
	 * @description Tests that asMapByString(String) returns a Map keyed by the specified field name.
	 */
	@IsTest
	private static void asMapByStringStringReturnsMapKeyedByFieldName()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Name, 'UniqueName-BBB')
					.build();

			Test.startTest();
			Map<String, SObject> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Name)
					.condition(Foobar__c.Id).equals(record.Id)
					.asMapByString(FIELD_NAME);
			Test.stopTest();

			Assert.areEqual(1, resultMap.size(), 'Map should contain one entry from string overload');
			Assert.isTrue(resultMap.containsKey('UniqueName-BBB'), 'Map should contain string key from string overload');
		}
	}

	/**
	 * @description Tests that asMapByString returns an empty map when the query yields no results.
	 */
	@IsTest
	private static void asMapByStringReturnsEmptyMapWhenNoResults()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Map<String, SObject> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Name)
					.condition(Foobar__c.Name).equals('NonExistent_XYZ_12345')
					.asMapByString(Foobar__c.Name);
			Test.stopTest();

			Assert.isTrue(resultMap.isEmpty(), 'Map should be empty when no results match');
		}
	}

	/**
	 * @description Tests that asGroupedMapById(SObjectField) groups records by an Id field, preserving duplicates.
	 */
	@IsTest
	private static void asGroupedMapByIdReturnsGroupedMap()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c childOne = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();
			Foobar__c childTwo = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();

			Test.startTest();
			Map<Id, List<SObject>> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Lookup__c)
					.condition(Foobar__c.Id).isIn(new List<Object> {childOne.Id, childTwo.Id})
					.asGroupedMapById(Foobar__c.Lookup__c);
			Test.stopTest();

			Assert.areEqual(1, resultMap.size(), 'Map should contain one group for parent Id');
			Assert.areEqual(2, resultMap.get(parent.Id).size(), 'Group should contain both child records');
		}
	}

	/**
	 * @description Tests that asGroupedMapById(String) groups records by an Id field name.
	 */
	@IsTest
	private static void asGroupedMapByIdStringReturnsGroupedMap()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c childOne = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();
			Foobar__c childTwo = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();

			Test.startTest();
			Map<Id, List<SObject>> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Lookup__c)
					.condition(Foobar__c.Id).isIn(new List<Object> {childOne.Id, childTwo.Id})
					.asGroupedMapById(FIELD_LOOKUP);
			Test.stopTest();

			Assert.areEqual(1, resultMap.size(), 'Map should contain one group from string overload');
			Assert.areEqual(2, resultMap.get(parent.Id).size(), 'Group should contain both child records');
		}
	}

	/**
	 * @description Tests that asGroupedMapById returns an empty map when the query yields no results.
	 */
	@IsTest
	private static void asGroupedMapByIdReturnsEmptyMapWhenNoResults()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Map<Id, List<SObject>> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Lookup__c)
					.condition(Foobar__c.Name).equals('NonExistent_XYZ_12345')
					.asGroupedMapById(Foobar__c.Lookup__c);
			Test.stopTest();

			Assert.isTrue(resultMap.isEmpty(), 'Map should be empty when no results match');
		}
	}

	/**
	 * @description Tests that asGroupedMapByString(SObjectField) groups records by a String field, preserving duplicates.
	 * Uses Name field because Foobar__c.Text__c is overwritten by TRG_SetFoobarDefaults during inserts in test context.
	 */
	@IsTest
	private static void asGroupedMapByStringReturnsGroupedMap()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, 'GroupKeyA').build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, 'GroupKeyA').build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, 'GroupKeyB').build();

			Test.startTest();
			Map<String, List<SObject>> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Name)
					.condition(Foobar__c.Name).isIn(new List<Object> {'GroupKeyA', 'GroupKeyB'})
					.asGroupedMapByString(Foobar__c.Name);
			Test.stopTest();

			Assert.areEqual(2, resultMap.size(), 'Map should contain two groups');
			Assert.areEqual(2, resultMap.get('GroupKeyA').size(), 'GroupKeyA should contain two records');
			Assert.areEqual(1, resultMap.get('GroupKeyB').size(), 'GroupKeyB should contain one record');
		}
	}

	/**
	 * @description Tests that asGroupedMapByString(String) groups records by a String field name.
	 */
	@IsTest
	private static void asGroupedMapByStringStringReturnsGroupedMap()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, 'GroupKeyC').build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Name, 'GroupKeyC').build();

			Test.startTest();
			Map<String, List<SObject>> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Name)
					.condition(Foobar__c.Name).equals('GroupKeyC')
					.asGroupedMapByString(FIELD_NAME);
			Test.stopTest();

			Assert.areEqual(1, resultMap.size(), 'Map should contain one group from string overload');
			Assert.areEqual(2, resultMap.get('GroupKeyC').size(), 'GroupKeyC should contain two records');
		}
	}

	/**
	 * @description Tests that asGroupedMapByString returns an empty map when the query yields no results.
	 */
	@IsTest
	private static void asGroupedMapByStringReturnsEmptyMapWhenNoResults()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Map<String, List<SObject>> resultMap = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Name)
					.condition(Foobar__c.Name).equals('NonExistent_XYZ_12345')
					.asGroupedMapByString(Foobar__c.Name);
			Test.stopTest();

			Assert.isTrue(resultMap.isEmpty(), 'Map should be empty when no results match');
		}
	}

	/**
	 * @description Tests that getPage() returns paginated results.
	 */
	@IsTest
	private static void getPageReturnsPaginatedResults()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(5);

			QRY_Builder.QueryPage result = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.CreatedDate).ascending()
					.getPage(1, 2);

			Assert.areEqual(2, result.records.size(), 'Should return 2 records per page');
			Assert.isTrue(result.totalRecords >= 5, 'Should have at least 5 total records');
			Assert.areEqual(1, result.pageNumber, 'Should be page 1');
			Assert.areEqual(2, result.pageSize, 'Page size should be 2');
			Assert.isTrue(result.hasMorePages, 'Should have more pages');
			Assert.isFalse(result.hasPriorPages, 'First page should not have prior pages');
			Assert.isNotNull(result.cursor, 'PaginationCursor should be populated');
			Assert.isNotNull(result.deletedRecords, 'deletedRecords should be populated');
		}
	}

	/**
	 * @description Tests that Page.totalPages is calculated correctly.
	 */
	@IsTest
	private static void pageContainsTotalPages()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(10);

			QRY_Builder.QueryPage result = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.CreatedDate).ascending()
					.getPage(1, 3);

			Assert.isTrue(result.totalPages >= 4, 'Should calculate total pages (10/3 = 4)');
		}
	}

	/**
	 * @description Tests that setMock() and clearMocks() work correctly.
	 */
	@IsTest
	private static void mockingWorksCorrectly()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> mockRecords = TST_Factory.newFoobars(3);
			for(Foobar__c mockRecord : mockRecords)
			{
				mockRecord.Name = 'Mock Record';
			}

			QRY_Builder.setMock(Foobar__c.SObjectType, mockRecords);

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();

			Assert.areEqual(3, results.size(), 'Should return mock records');
			Assert.areEqual('Mock Record', ((Foobar__c)results[0]).Name, 'Should have mock name');

			QRY_Builder.clearMocks();

			List<SObject> afterClear = QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();

			Assert.areEqual(0, afterClear.size(), 'Should return no records after clearing mocks');
		}
	}

	/**
	 * @description Tests that QRY_Builder.setMockException delegates to QRY_Engine.setMockException
	 * and that the registered exception fires on a query against that SObjectType.
	 */
	@IsTest
	private static void shouldDelegateSetMockExceptionToQryEngine()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.setMockException(Foobar__c.SObjectType, new QueryException('Pass-through failure'));

			Assert.isNotNull
					(
							QRY_Engine.getMockException(Foobar__c.SObjectType),
							'QRY_Builder.setMockException should register the exception on QRY_Engine'
					);

			Test.startTest();
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();
				Assert.fail('Should throw the registered QueryException via pass-through');
			}
			catch(QueryException error)
			{
				Assert.areEqual
						(
								'Pass-through failure',
								error.getMessage(),
								'Pass-through should preserve the exception instance'
						);
			}
			Test.stopTest();

			QRY_Engine.clearMocks();
		}
	}

	/**
	 * @description Tests that addCondition with QRY_Condition works.
	 */
	@IsTest
	private static void addConditionWithQryConditionWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			QRY_Condition.OrCondition orCondition = new QRY_Condition.OrCondition();
			orCondition.add(new QRY_Condition.FieldCondition('Name', QRY_Condition.Operator.EQUALS, record.Name));
			orCondition.add(new QRY_Condition.FieldCondition('Name', QRY_Condition.Operator.EQUALS, 'Other Record'));

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addCondition(orCondition)
					.toList();

			Assert.isFalse(results.isEmpty(), 'Should find records with OR condition');
		}
	}

	/**
	 * @description Tests that isIn() with SObject records works correctly.
	 */
	@IsTest
	private static void isInWithSObjectRecordsWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).isIn(new List<SObject> {parent})
					.toList();

			Set<Id> resultIds = new Map<Id, SObject>(results).keySet();
			Assert.isTrue(resultIds.contains(child.Id), 'Should find child record');
		}
	}

	/**
	 * @description Tests that isIn() with field extraction works correctly.
	 */
	@IsTest
	private static void isInWithFieldExtractionWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(new List<SObject> {record}, Foobar__c.Id)
					.toList();

			Assert.areEqual(1, results.size(), 'Should find record by extracted field');
		}
	}

	/**
	 * @description Tests that notInSet() with SObject records works correctly.
	 */
	@IsTest
	private static void notInSetWithSObjectRecordsWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c excluded = TST_Factory.insertFoobar();
			Foobar__c included = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).notInSet(new List<SObject> {excluded})
					.toList();

			Set<Id> resultIds = new Map<Id, SObject>(results).keySet();
			Assert.isFalse(resultIds.contains(excluded.Id), 'Should not contain excluded record');
			Assert.isTrue(resultIds.contains(included.Id), 'Should contain included record');
		}
	}

	/**
	 * @description Tests that notInSet() with field extraction works correctly.
	 */
	@IsTest
	private static void notInSetWithFieldExtractionWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c excluded = TST_Factory.insertFoobar();
			Foobar__c included = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).notInSet(new List<SObject> {excluded}, Foobar__c.Id)
					.toList();

			Set<Id> resultIds = new Map<Id, SObject>(results).keySet();
			Assert.isFalse(resultIds.contains(excluded.Id), 'Should not contain excluded record');
			Assert.isTrue(resultIds.contains(included.Id), 'Should contain included record');
		}
	}

	/**
	 * @description Tests that isInStrict() throws exception for empty list.
	 */
	@IsTest
	private static void isInStrictThrowsForEmptyList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Name).isInStrict(new List<Object>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty list');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that isInStrict() throws exception for empty set.
	 */
	@IsTest
	private static void isInStrictThrowsForEmptySet()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Name).isInStrict(new Set<Object>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty set');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that isInStrict() with SObjects throws exception for empty list.
	 */
	@IsTest
	private static void isInStrictSObjectsThrowsForEmptyList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Lookup__c).isInStrict(new List<SObject>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty SObject list');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that isInStrict() with field extraction throws exception for empty list.
	 */
	@IsTest
	private static void isInStrictFieldExtractionThrowsForEmptyList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Id).isInStrict(new List<SObject>(), Foobar__c.Id)
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty list with field extraction');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that isInStrict(List<Object>) works with valid data.
	 */
	@IsTest
	private static void isInStrictListObjectSucceeds()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isInStrict(new List<Object> {record.Id})
					.toList();

			Assert.areEqual(1, results.size(), 'Should find record');
		}
	}

	/**
	 * @description Tests that isInStrict(Set<Object>) works with valid data.
	 */
	@IsTest
	private static void isInStrictSetObjectSucceeds()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isInStrict(new Set<Object> {record.Id})
					.toList();

			Assert.areEqual(1, results.size(), 'Should find record');
		}
	}

	/**
	 * @description Tests that isInStrict(List<SObject>) works with valid data.
	 */
	@IsTest
	private static void isInStrictListSObjectSucceeds()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).isInStrict(new List<SObject> {parent})
					.toList();

			Set<Id> resultIds = new Map<Id, SObject>(results).keySet();
			Assert.isTrue(resultIds.contains(child.Id), 'Should find child record');
		}
	}

	/**
	 * @description Tests that isInStrict(List<SObject>, SObjectField) works with valid data.
	 */
	@IsTest
	private static void isInStrictListSObjectFieldSucceeds()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isInStrict(new List<SObject> {record}, Foobar__c.Id)
					.toList();

			Assert.areEqual(1, results.size(), 'Should find record');
		}
	}

	/**
	 * @description Tests that notInSet(Set<Object>) works correctly.
	 */
	@IsTest
	private static void notInSetWithSetObjectWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c excluded = TST_Factory.insertFoobar();
			Foobar__c included = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).notInSet(new Set<Object> {excluded.Id})
					.toList();

			Set<Id> resultIds = new Map<Id, SObject>(results).keySet();
			Assert.isFalse(resultIds.contains(excluded.Id), 'Should exclude record');
			Assert.isTrue(resultIds.contains(included.Id), 'Should include other record');
		}
	}

	/**
	 * @description Tests that notInSet(List<Object>) works correctly.
	 */
	@IsTest
	private static void notInSetWithListObjectWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c excluded = TST_Factory.insertFoobar();
			Foobar__c included = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).notInSet(new List<Object> {excluded.Id})
					.toList();

			Set<Id> resultIds = new Map<Id, SObject>(results).keySet();
			Assert.isFalse(resultIds.contains(excluded.Id), 'Should exclude record');
			Assert.isTrue(resultIds.contains(included.Id), 'Should include other record');
		}
	}

	/**
	 * @description Tests that notInSetStrict() throws exception for empty list.
	 */
	@IsTest
	private static void notInSetStrictThrowsForEmptyList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Name).notInSetStrict(new List<Object>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty list');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that notInSetStrict() throws exception for empty set.
	 */
	@IsTest
	private static void notInSetStrictThrowsForEmptySet()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Name).notInSetStrict(new Set<Object>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty set');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that notInSetStrict() with SObjects throws exception for empty list.
	 */
	@IsTest
	private static void notInSetStrictSObjectsThrowsForEmptyList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Lookup__c).notInSetStrict(new List<SObject>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty SObject list');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that notInSetStrict() with field extraction throws exception for empty list.
	 */
	@IsTest
	private static void notInSetStrictFieldExtractionThrowsForEmptyList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Id).notInSetStrict(new List<SObject>(), Foobar__c.Id)
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty list with field extraction');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that includes() works for multi-picklist fields.
	 */
	@IsTest
	private static void includesWorksForMultiPicklist()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).includes(new List<Object> {'Option1', 'Option2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('INCLUDES'), 'Should contain INCLUDES');
		}
	}

	/**
	 * @description Tests that includes() with Set works for multi-picklist fields.
	 */
	@IsTest
	private static void includesWithSetWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).includes(new Set<Object> {'Option1', 'Option2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('INCLUDES'), 'Should contain INCLUDES');
		}
	}

	/**
	 * @description Tests that includesStrict() throws exception for empty list.
	 */
	@IsTest
	private static void includesStrictThrowsForEmptyList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Picklist__c).includesStrict(new List<Object>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty list');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that includesStrict() throws exception for empty set.
	 */
	@IsTest
	private static void includesStrictThrowsForEmptySet()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Picklist__c).includesStrict(new Set<Object>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty set');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that includesStrict() with List succeeds for valid values.
	 */
	@IsTest
	private static void includesStrictListSucceeds()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).includesStrict(new List<Object> {'Option1', 'Option2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('INCLUDES'), 'Should contain INCLUDES');
		}
	}

	/**
	 * @description Tests that includesStrict() with Set succeeds for valid values.
	 */
	@IsTest
	private static void includesStrictSetSucceeds()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).includesStrict(new Set<Object> {'Option1', 'Option2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('INCLUDES'), 'Should contain INCLUDES');
		}
	}

	/**
	 * @description Tests that excludes() works for multi-picklist fields.
	 */
	@IsTest
	private static void excludesWorksForMultiPicklist()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).excludes(new List<Object> {'Option1', 'Option2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('EXCLUDES'), 'Should contain EXCLUDES');
		}
	}

	/**
	 * @description Tests that excludes() with Set works for multi-picklist fields.
	 */
	@IsTest
	private static void excludesWithSetWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).excludes(new Set<Object> {'Option1', 'Option2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('EXCLUDES'), 'Should contain EXCLUDES');
		}
	}

	/**
	 * @description Tests that excludesStrict() throws exception for empty list.
	 */
	@IsTest
	private static void excludesStrictThrowsForEmptyList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Picklist__c).excludesStrict(new List<Object>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty list');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that excludesStrict() throws exception for empty set.
	 */
	@IsTest
	private static void excludesStrictThrowsForEmptySet()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Picklist__c).excludesStrict(new Set<Object>())
						.toList();
				Assert.fail('Should throw IllegalArgumentException for empty set');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that excludesStrict() with List succeeds for valid values.
	 */
	@IsTest
	private static void excludesStrictListSucceeds()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).excludesStrict(new List<Object> {'Option1', 'Option2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('EXCLUDES'), 'Should contain EXCLUDES');
		}
	}

	/**
	 * @description Tests that excludesStrict() with Set succeeds for valid values.
	 */
	@IsTest
	private static void excludesStrictSetSucceeds()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).excludesStrict(new Set<Object> {'Option1', 'Option2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('EXCLUDES'), 'Should contain EXCLUDES');
		}
	}

	/**
	 * @description Tests that equals() with SObject record works correctly.
	 */
	@IsTest
	private static void equalsWithSObjectRecordWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).equals(parent)
					.toList();

			Set<Id> resultIds = new Map<Id, SObject>(results).keySet();
			Assert.isTrue(resultIds.contains(child.Id), 'Should find child record');
		}
	}

	/**
	 * @description Tests that notEquals() with SObject record works correctly.
	 */
	@IsTest
	private static void notEqualsWithSObjectRecordWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c childWithParent = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id)
					.build();
			Foobar__c childWithoutParent = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).notEquals(parent)
					.toList();

			Set<Id> resultIds = new Map<Id, SObject>(results).keySet();
			Assert.isFalse(resultIds.contains(childWithParent.Id), 'Should not contain child with parent');
			Assert.isTrue(resultIds.contains(childWithoutParent.Id), 'Should contain child without parent');
		}
	}

	/**
	 * @description Tests that withCache() enables caching.
	 */
	@IsTest
	private static void withCacheEnablesCaching()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.withCache(300);

			List<SObject> results = query.toList();

			Assert.areEqual(1, results.size(), 'Should return record');
		}
	}

	/**
	 * @description Tests that HAVING conditions work with aggregates.
	 */
	@IsTest
	private static void havingConditionsWorkWithAggregates()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			List<AggregateResult> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Name)
					.havingCount().greaterThan(0)
					.toList();

			Assert.isTrue(results.size() >= 1, 'Should return grouped results');
		}
	}

	/**
	 * @description Tests havingSumOf() method.
	 */
	@IsTest
	private static void havingSumOfWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.sum(Foobar__c.NumberInteger__c)
					.groupBy(Foobar__c.Picklist__c)
					.havingSumOf(Foobar__c.NumberInteger__c).greaterThan(0)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('HAVING'), 'Should contain HAVING clause');
		}
	}

	/**
	 * @description Tests havingAvgOf() method.
	 */
	@IsTest
	private static void havingAvgOfWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.avg(Foobar__c.NumberInteger__c)
					.groupBy(Foobar__c.Picklist__c)
					.havingAvgOf(Foobar__c.NumberInteger__c).greaterThan(0)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('HAVING'), 'Should contain HAVING clause');
		}
	}

	/**
	 * @description Tests havingMinOf() method.
	 */
	@IsTest
	private static void havingMinOfWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.min(Foobar__c.NumberInteger__c)
					.groupBy(Foobar__c.Picklist__c)
					.havingMinOf(Foobar__c.NumberInteger__c).greaterThan(0)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('HAVING'), 'Should contain HAVING clause');
		}
	}

	/**
	 * @description Tests havingMaxOf() method.
	 */
	@IsTest
	private static void havingMaxOfWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.max(Foobar__c.NumberInteger__c)
					.groupBy(Foobar__c.Picklist__c)
					.havingMaxOf(Foobar__c.NumberInteger__c).greaterThan(0)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('HAVING'), 'Should contain HAVING clause');
		}
	}

	/**
	 * @description Tests havingCountOf() method.
	 */
	@IsTest
	private static void havingCountOfWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Picklist__c)
					.havingCountOf(Foobar__c.Id).greaterThan(0)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('HAVING'), 'Should contain HAVING clause');
		}
	}

	/**
	 * @description Tests countDistinct() aggregate method.
	 */
	@IsTest
	private static void countDistinctWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			List<AggregateResult> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.countDistinct(Foobar__c.Picklist__c)
					.toList();

			Assert.isFalse(results.isEmpty(), 'COUNT_DISTINCT query should return results');
		}
	}

	/**
	 * @description Tests countDistinct() aggregate method with String field name.
	 */
	@IsTest
	private static void countDistinctWithStringFieldWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			List<AggregateResult> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.countDistinct(FIELD_PICKLIST)
					.toList();

			Assert.isFalse(results.isEmpty(), 'COUNT_DISTINCT with String field should return results');
		}
	}

	/**
	 * @description Tests that semi-join subquery works with isIn().
	 * Uses Foobar__c/User to avoid same-object subquery limitation.
	 */
	@IsTest
	private static void semiJoinSubqueryWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {'OwnerId'});

			List<SObject> results = QRY_Builder.selectFrom(User.SObjectType)
					.fields(new List<String> {'Name'})
					.condition(FIELD_ID).isIn(subquery)
					.toList();

			Assert.isTrue(results.size() >= 1, 'Running user should own Foobar__c');
		}
	}

	/**
	 * @description Tests that anti-join subquery works with notIn().
	 * Uses Foobar__c/User to avoid same-object subquery limitation.
	 */
	@IsTest
	private static void antiJoinSubqueryWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {'OwnerId'});

			Integer totalActiveUsers = QRY_Builder.selectFrom(User.SObjectType)
					.fields(new List<String> {'Name'})
					.condition(User.IsActive).equals(true)
					.toList()
					.size();

			List<SObject> results = QRY_Builder.selectFrom(User.SObjectType)
					.fields(new List<String> {'Name'})
					.condition(FIELD_ID).notIn(subquery)
					.condition(User.IsActive).equals(true)
					.toList();

			Assert.isTrue(results.size() < totalActiveUsers, 'Anti-join should exclude Foobar__c owners');
		}
	}

	/**
	 * @description Tests that relatedFields() adds parent field paths.
	 */
	@IsTest
	private static void relatedFieldsAddsParentPaths()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.relatedFields(new List<String> {'Lookup__r.Name'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Lookup__r.Name'), 'Should contain related field path');
		}
	}

	/**
	 * @description Tests that toCursor() returns a database cursor.
	 */
	@IsTest
	private static void toCursorReturnsDatabaseCursor()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Database.Cursor cursor = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).equals(record.Name)
					.toCursor();

			Assert.isNotNull(cursor, 'Should return database cursor');
		}
	}

	/**
	 * @description Tests that custom selector with getDefaultOrderBy works.
	 */
	@IsTest
	private static void customSelectorWithDefaultOrderByWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			List<QRY_Generator.OrderBy> orderBy = new OrderedSelector().getDefaultOrderBy();

			Assert.isNotNull(orderBy, 'Should return default order by');
		}
	}

	/**
	 * @description Tests that custom selector extending Builder works.
	 */
	@IsTest
	private static void customSelectorExtendsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<Foobar__c> results = new FoobarSelector().findByName(record.Name);

			Assert.isTrue(results.size() >= 1, 'Custom selector should work');
		}
	}

	/**
	 * @description Example custom selector extending QRY_Builder.Builder.
	 */
	private class FoobarSelector extends QRY_Builder.Builder
	{
		/**
		 * @description Constructs the selector for Foobar__c.
		 */
		public FoobarSelector()
		{
			super(Foobar__c.SObjectType);
		}

		/**
		 * @description Returns default fields for this selector.
		 *
		 * @return Set of field API names
		 */
		public override Set<String> getDefaultFields()
		{
			return new Set<String> {FIELD_ID, 'Name'};
		}

		/**
		 * @description Finds records by name.
		 *
		 * @param recordName The record name to filter by
		 *
		 * @return List of matching Foobar__c records
		 */
		@SuppressWarnings('PMD.UnnecessaryCast')
		public List<Foobar__c> findByName(String recordName)
		{
			return condition(Foobar__c.Name).equals(recordName).toList();
		}
	}

	/**
	 * @description Selector with default ordering.
	 */
	private class OrderedSelector extends QRY_Builder.Builder
	{
		/**
		 * @description Constructs the selector.
		 */
		public OrderedSelector()
		{
			super(Foobar__c.SObjectType);
		}

		/**
		 * @description Returns default order by for this selector.
		 *
		 * @return List of OrderBy clauses
		 */
		public override List<QRY_Generator.OrderBy> getDefaultOrderBy()
		{
			return new List<QRY_Generator.OrderBy> {new QRY_Generator.OrderBy('Name')};
		}
	}

	/**
	 * @description Selector with base condition.
	 */
	private class FilteredSelector extends QRY_Builder.Builder
	{
		/**
		 * @description Constructs the selector.
		 */
		public FilteredSelector()
		{
			super(Foobar__c.SObjectType);
		}

		/**
		 * @description Returns base condition applied to all queries.
		 *
		 * @return Condition filtering by name
		 */
		public override QRY_Condition.Evaluable getBaseCondition()
		{
			return new QRY_Condition.FieldCondition(Foobar__c.Name, QRY_Condition.Operator.NOT_EQUALS, null);
		}
	}

	/**
	 * @description Tests that custom selector with getBaseCondition works.
	 */
	@IsTest
	private static void customSelectorWithBaseConditionWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = new FilteredSelector()
					.condition(Foobar__c.Name).equals(record.Name)
					.toList();

			Assert.isFalse(results.isEmpty(), 'Should return filtered results');
		}
	}

	/**
	 * @description Tests that base getDefaultOrderBy returns null.
	 */
	@IsTest
	private static void baseGetDefaultOrderByReturnsNull()
	{
		System.runAs(getTestAdmin())
		{
			List<QRY_Generator.OrderBy> orderBy = new FoobarSelector().getDefaultOrderBy();

			Assert.isNull(orderBy, 'Base implementation should return null');
		}
	}

	/**
	 * @description Tests that custom selector with limit and offset works.
	 */
	@IsTest
	private static void customSelectorWithLimitAndOffsetWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(5);

			List<SObject> results = new FoobarSelector()
					.withLimit(2)
					.withOffset(1)
					.toList();

			Assert.areEqual(2, results.size(), 'Should return 2 records with offset');
		}
	}

	/**
	 * @description Tests that isIn() with null set adds a false condition.
	 */
	@IsTest
	private static void isInWithNullSetAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).isIn((Set<Object>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when null set');
		}
	}

	/**
	 * @description Tests that isIn() with empty set adds a false condition.
	 */
	@IsTest
	private static void isInWithEmptySetAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).isIn(new Set<Object>())
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when empty set');
		}
	}

	/**
	 * @description Tests that isIn() with null list adds a false condition.
	 */
	@IsTest
	private static void isInWithNullListAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).isIn((List<Object>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when null list');
		}
	}

	/**
	 * @description Tests that isIn() with empty list adds a false condition.
	 */
	@IsTest
	private static void isInWithEmptyListAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).isIn(new List<Object>())
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when empty list');
		}
	}

	/**
	 * @description Tests that isIn() with null SObject list adds a false condition.
	 */
	@IsTest
	private static void isInWithNullSObjectListAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).isIn((List<SObject>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when null SObject list');
		}
	}

	/**
	 * @description Tests that isIn() with empty SObject list adds a false condition.
	 */
	@IsTest
	private static void isInWithEmptySObjectListAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).isIn(new List<SObject>())
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when empty SObject list');
		}
	}

	/**
	 * @description Tests that isIn() with SObject list containing only nulls adds a false condition.
	 */
	@IsTest
	private static void isInWithAllNullSObjectsAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = new List<SObject> {null, null};

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).isIn(records)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when only null records');
		}
	}

	/**
	 * @description Tests that isIn() with field extraction on null list adds a false condition.
	 */
	@IsTest
	private static void isInWithFieldExtractionNullListAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn((List<SObject>)null, Foobar__c.Id)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when null list');
		}
	}

	/**
	 * @description Tests that isIn() with field extraction on empty list adds a false condition.
	 */
	@IsTest
	private static void isInWithFieldExtractionEmptyListAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(new List<SObject>(), Foobar__c.Id)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when empty list');
		}
	}

	/**
	 * @description Tests that isIn() with field extraction on all-null list adds a false condition.
	 */
	@IsTest
	private static void isInWithFieldExtractionAllNullAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = new List<SObject> {null, null};

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).isIn(records, Foobar__c.Id)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when only null records');
		}
	}

	/**
	 * @description Tests that isIn() with empty set combined with another condition
	 * includes the false condition in SOQL, preventing silent query expansion.
	 */
	@IsTest
	private static void isInWithEmptySetAndOtherConditionAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Text__c).equals('Test')
					.andCondition(Foobar__c.Picklist__c).isIn(new Set<Object>())
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition for empty isIn');
			Assert.isTrue(soql.containsIgnoreCase('= \'Test\''), 'Should still contain the other condition');
		}
	}

	/**
	 * @description Tests that notInSet() with null set returns builder without error.
	 */
	@IsTest
	private static void notInSetWithNullSetReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).notInSet((Set<Object>)null)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when null set');
		}
	}

	/**
	 * @description Tests that notInSet() with empty set returns builder without error.
	 */
	@IsTest
	private static void notInSetWithEmptySetReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).notInSet(new Set<Object>())
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when empty set');
		}
	}

	/**
	 * @description Tests that notInSet() with null list returns builder without error.
	 */
	@IsTest
	private static void notInSetWithNullListReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).notInSet((List<Object>)null)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when null list');
		}
	}

	/**
	 * @description Tests that notInSet() with empty list returns builder without error.
	 */
	@IsTest
	private static void notInSetWithEmptyListReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).notInSet(new List<Object>())
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when empty list');
		}
	}

	/**
	 * @description Tests that notInSet() with null SObject list returns builder without error.
	 */
	@IsTest
	private static void notInSetWithNullSObjectListReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).notInSet((List<SObject>)null)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when null SObject list');
		}
	}

	/**
	 * @description Tests that notInSet() with empty SObject list returns builder without error.
	 */
	@IsTest
	private static void notInSetWithEmptySObjectListReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).notInSet(new List<SObject>())
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when empty SObject list');
		}
	}

	/**
	 * @description Tests that notInSet() with SObject list containing only nulls returns builder.
	 */
	@IsTest
	private static void notInSetWithAllNullSObjectsReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = new List<SObject> {null, null};

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).notInSet(records)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when only null records');
		}
	}

	/**
	 * @description Tests that notInSet() with field extraction on null list returns builder.
	 */
	@IsTest
	private static void notInSetWithFieldExtractionNullListReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).notInSet((List<SObject>)null, Foobar__c.Id)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when null list');
		}
	}

	/**
	 * @description Tests that notInSet() with field extraction on empty list returns builder.
	 */
	@IsTest
	private static void notInSetWithFieldExtractionEmptyListReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).notInSet(new List<SObject>(), Foobar__c.Id)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when empty list');
		}
	}

	/**
	 * @description Tests that notInSet() with field extraction on all-null list returns builder.
	 */
	@IsTest
	private static void notInSetWithFieldExtractionAllNullReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = new List<SObject> {null, null};

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).notInSet(records, Foobar__c.Id)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('NOT IN'), 'Should not contain NOT IN when only null records');
		}
	}

	/**
	 * @description Tests that includes() with null list adds a false condition.
	 */
	@IsTest
	private static void includesWithNullListAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).includes((List<Object>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when null list');
		}
	}

	/**
	 * @description Tests that includes() with empty list adds a false condition.
	 */
	@IsTest
	private static void includesWithEmptyListAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).includes(new List<Object>())
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when empty list');
		}
	}

	/**
	 * @description Tests that includes() with null set adds a false condition.
	 */
	@IsTest
	private static void includesWithNullSetAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).includes((Set<Object>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when null set');
		}
	}

	/**
	 * @description Tests that includes() with empty set adds a false condition.
	 */
	@IsTest
	private static void includesWithEmptySetAddsFalseCondition()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).includes(new Set<Object>())
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Id = null'), 'Should contain false condition when empty set');
		}
	}

	/**
	 * @description Tests that excludes() with null list returns builder without error.
	 */
	@IsTest
	private static void excludesWithNullListReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).excludes((List<Object>)null)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('EXCLUDES'), 'Should not contain EXCLUDES when null list');
		}
	}

	/**
	 * @description Tests that excludes() with empty list returns builder without error.
	 */
	@IsTest
	private static void excludesWithEmptyListReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).excludes(new List<Object>())
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('EXCLUDES'), 'Should not contain EXCLUDES when empty list');
		}
	}

	/**
	 * @description Tests that excludes() with null set returns builder without error.
	 */
	@IsTest
	private static void excludesWithNullSetReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).excludes((Set<Object>)null)
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('EXCLUDES'), 'Should not contain EXCLUDES when null set');
		}
	}

	/**
	 * @description Tests that excludes() with empty set returns builder without error.
	 */
	@IsTest
	private static void excludesWithEmptySetReturnsBuilder()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Picklist__c).excludes(new Set<Object>())
					.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('EXCLUDES'), 'Should not contain EXCLUDES when empty set');
		}
	}

	/**
	 * @description Tests that QueryPage.totalPages returns 1 when pageSize is null.
	 */
	@IsTest
	private static void queryPageTotalPagesReturnsOneWhenPageSizeNull()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.QueryPage page = new QRY_Builder.QueryPage();
			page.totalRecords = 10;
			page.pageSize = null;

			Assert.areEqual(1, page.totalPages, 'Should return 1 when pageSize is null');
		}
	}

	/**
	 * @description Tests that QueryPage.totalPages returns 1 when pageSize is 0.
	 */
	@IsTest
	private static void queryPageTotalPagesReturnsOneWhenPageSizeZero()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.QueryPage page = new QRY_Builder.QueryPage();
			page.totalRecords = 10;
			page.pageSize = 0;

			Assert.areEqual(1, page.totalPages, 'Should return 1 when pageSize is 0');
		}
	}

	/**
	 * @description Tests that isInStrict with SObjects containing only nulls throws exception.
	 */
	@IsTest
	private static void isInStrictWithAllNullSObjectsThrows()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = new List<SObject> {null, null};

			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Lookup__c).isInStrict(records)
						.toList();
				Assert.fail('Should throw for list with only null records');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that isInStrict with field extraction containing only nulls throws exception.
	 */
	@IsTest
	private static void isInStrictFieldExtractionAllNullsThrows()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = new List<SObject> {null, null};

			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Id).isInStrict(records, Foobar__c.Id)
						.toList();
				Assert.fail('Should throw for list with only null records');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that notInSetStrict with SObjects containing only nulls throws exception.
	 */
	@IsTest
	private static void notInSetStrictWithAllNullSObjectsThrows()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = new List<SObject> {null, null};

			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Lookup__c).notInSetStrict(records)
						.toList();
				Assert.fail('Should throw for list with only null records');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests that notInSetStrict with field extraction containing only nulls throws exception.
	 */
	@IsTest
	private static void notInSetStrictFieldExtractionAllNullsThrows()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = new List<SObject> {null, null};

			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.condition(Foobar__c.Id).notInSetStrict(records, Foobar__c.Id)
						.toList();
				Assert.fail('Should throw for list with only null records');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests addFields with SObjectField list.
	 */
	@IsTest
	private static void addFieldsWithSObjectFieldListWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addFields(new List<SObjectField> {Foobar__c.Name, Foobar__c.Text__c})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase(FIELD_NAME), 'Should contain Name field');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_TEXT), 'Should contain Text field');
		}
	}

	/**
	 * @description Tests addFields with String list.
	 */
	@IsTest
	private static void addFieldsWithStringListWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addFields(new List<String> {'Name', SEL_Foobar.FIELD_TEXT})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase(FIELD_NAME), 'Should contain Name field');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_TEXT), 'Should contain Text field');
		}
	}

	/**
	 * @description Tests addField with SObjectField.
	 */
	@IsTest
	private static void addFieldWithSObjectFieldWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Email__c)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase(FIELD_EMAIL), 'Should contain Email field');
		}
	}

	/**
	 * @description Tests addField with String.
	 */
	@IsTest
	private static void addFieldWithStringWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(SEL_Foobar.FIELD_EMAIL)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase(FIELD_EMAIL), 'Should contain Email field');
		}
	}

	/**
	 * @description Tests selectAllFields method.
	 */
	@IsTest
	private static void selectAllFieldsWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.selectAllFields()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase(FIELD_NAME), 'Should contain Name field');
			Assert.isTrue(soql.containsIgnoreCase('CreatedDate'), 'Should contain CreatedDate field');
			Assert.isTrue(soql.containsIgnoreCase('LastModifiedDate'), 'Should contain LastModifiedDate field');
		}
	}

	/**
	 * @description Tests relatedField with single string.
	 */
	@IsTest
	private static void relatedFieldWithStringSingle()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.relatedField('Owner.Name')
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('Owner.Name'), 'Should contain related field');
		}
	}

	/**
	 * @description Tests withOffset method.
	 */
	@IsTest
	private static void withOffsetWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withOffset(10)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('OFFSET 10'), 'Should contain OFFSET clause');
		}
	}

	/**
	 * @description Tests withUserMode method.
	 */
	@IsTest
	private static void withUserModeWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.withUserMode()
					.toList();

			Assert.areEqual(1, results.size(), 'Should return record with user mode');
		}
	}

	/**
	 * @description Flag disabled: new Builder defaults to SYSTEM_MODE.
	 */
	@IsTest
	private static void shouldDefaultToSystemModeWhenFlagDisabled()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true, false);

			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType);

			Assert.isFalse(builder.userModeEnabled, 'Builder must default to SYSTEM_MODE when UserModeQueries_Enabled is disabled');
		}
	}

	/**
	 * @description Flag enabled: new Builder defaults to USER_MODE.
	 */
	@IsTest
	private static void shouldDefaultToUserModeWhenFlagEnabled()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType);

			Assert.isTrue(builder.userModeEnabled, 'Builder must default to USER_MODE when UserModeQueries_Enabled is enabled');
		}
	}

	/**
	 * @description .withSystemMode() overrides a flag-driven USER_MODE default.
	 */
	@IsTest
	private static void shouldLetWithSystemModeOverrideFlag()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode();

			Assert.isFalse(builder.userModeEnabled, '.withSystemMode() must force SYSTEM_MODE regardless of flag');
		}
	}

	/**
	 * @description .withUserMode() overrides a flag-driven SYSTEM_MODE default.
	 */
	@IsTest
	private static void shouldLetWithUserModeOverrideFlag()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true, false);

			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType).withUserMode();

			Assert.isTrue(builder.userModeEnabled, '.withUserMode() must force USER_MODE regardless of flag');
		}
	}

	/**
	 * @description Last explicit access-mode call wins (chained overrides).
	 */
	@IsTest
	private static void shouldRespectLastAccessModeCall()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true, false);

			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType).withUserMode().withSystemMode();

			Assert.isFalse(builder.userModeEnabled, 'Last access-mode call (.withSystemMode) must win');
		}
	}

	/**
	 * @description Tests stripInaccessible method.
	 */
	@IsTest
	private static void stripInaccessibleWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.stripInaccessible()
					.toList();

			Assert.areEqual(1, results.size(), 'Should return record with strip inaccessible');
		}
	}

	/**
	 * @description Tests withSharing method.
	 */
	@IsTest
	private static void withSharingWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.withSharing()
					.toList();

			Assert.areEqual(1, results.size(), 'Should return record with sharing');
		}
	}

	/**
	 * @description Tests bypassSharing method.
	 */
	@IsTest
	private static void bypassSharingWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.bypassSharing()
					.toList();

			Assert.areEqual(1, results.size(), 'Should return record with bypass sharing');
		}
	}

	/**
	 * @description Tests withoutSecurity method.
	 */
	@IsTest
	private static void withoutSecurityWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id)
					.withUserMode()
					.withoutSecurity()
					.toList();

			Assert.areEqual(1, results.size(), 'Should return record after reset security');
		}
	}

	/**
	 * @description Tests forUpdate method.
	 */
	@IsTest
	private static void forUpdateWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.forUpdate()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('FOR UPDATE'), 'Should contain FOR UPDATE');
		}
	}

	/**
	 * @description Tests forReference method.
	 */
	@IsTest
	private static void forReferenceWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.forReference()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('FOR REFERENCE'), 'Should contain FOR REFERENCE');
		}
	}

	/**
	 * @description Tests forView method.
	 */
	@IsTest
	private static void forViewWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.forView()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('FOR VIEW'), 'Should contain FOR VIEW');
		}
	}

	/**
	 * @description Tests allRows method.
	 */
	@IsTest
	private static void allRowsWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.allRows()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ALL ROWS'), 'Should contain ALL ROWS');
		}
	}

	/**
	 * @description Tests ascending method for ORDER BY.
	 */
	@IsTest
	private static void ascendingWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.Name).ascending()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' ASC'), 'Should sort ascending');
		}
	}

	/**
	 * @description Tests nullsFirst method for ORDER BY.
	 */
	@IsTest
	private static void nullsFirstWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.Name).nullsFirst()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('NULLS FIRST'), 'Should have NULLS FIRST');
		}
	}

	/**
	 * @description Tests nullsLast method for ORDER BY.
	 */
	@IsTest
	private static void nullsLastWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.Name).nullsLast()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('NULLS LAST'), 'Should have NULLS LAST');
		}
	}

	/**
	 * @description Tests orderBy with SObjectField and sortDescending flag ascending.
	 */
	@IsTest
	private static void orderByFieldWithDescendingFalseWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.Name, false)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' ASC'), 'Should sort ascending');
			Assert.isTrue(soql.containsIgnoreCase('NULLS FIRST'), 'Should default to NULLS FIRST');
		}
	}

	/**
	 * @description Tests orderBy with SObjectField and sortDescending flag descending.
	 */
	@IsTest
	private static void orderByFieldWithDescendingTrueWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.Name, true)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' DESC'), 'Should sort descending');
			Assert.isTrue(soql.containsIgnoreCase('NULLS LAST'), 'Should default to NULLS LAST for DESC');
		}
	}

	/**
	 * @description Tests orderBy with SObjectField, sortDescending, and nullsLast flags.
	 */
	@IsTest
	private static void orderByFieldWithDescendingAndNullsLastWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.Name, true, true)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' DESC'), 'Should sort descending');
			Assert.isTrue(soql.containsIgnoreCase('NULLS LAST'), 'Should have NULLS LAST');
		}
	}

	/**
	 * @description Tests orderBy with SObjectField, ascending direction, and nullsFirst.
	 */
	@IsTest
	private static void orderByFieldWithAscendingAndNullsFirstWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(Foobar__c.Name, false, false)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' ASC'), 'Should sort ascending');
			Assert.isTrue(soql.containsIgnoreCase('NULLS FIRST'), 'Should have NULLS FIRST');
		}
	}

	/**
	 * @description Tests orderBy with String field name and sortDescending flag ascending.
	 */
	@IsTest
	private static void orderByStringWithDescendingFalseWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(FIELD_NAME, false)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' ASC'), 'Should sort ascending');
			Assert.isTrue(soql.containsIgnoreCase('NULLS FIRST'), 'Should default to NULLS FIRST');
		}
	}

	/**
	 * @description Tests orderBy with String field name and sortDescending flag descending.
	 */
	@IsTest
	private static void orderByStringWithDescendingTrueWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(FIELD_NAME, true)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' DESC'), 'Should sort descending');
			Assert.isTrue(soql.containsIgnoreCase('NULLS LAST'), 'Should default to NULLS LAST for DESC');
		}
	}

	/**
	 * @description Tests orderBy with String field name, sortDescending, and nullsLast flags.
	 */
	@IsTest
	private static void orderByStringWithDescendingAndNullsLastWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(FIELD_NAME, true, true)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' DESC'), 'Should sort descending');
			Assert.isTrue(soql.containsIgnoreCase('NULLS LAST'), 'Should have NULLS LAST');
		}
	}

	/**
	 * @description Tests orderBy with String field name, ascending direction, and nullsFirst.
	 */
	@IsTest
	private static void orderByStringWithAscendingAndNullsFirstWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(FIELD_NAME, false, false)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' ASC'), 'Should sort ascending');
			Assert.isTrue(soql.containsIgnoreCase('NULLS FIRST'), 'Should have NULLS FIRST');
		}
	}

	/**
	 * @description Tests asValueSet with SObjectField.
	 */
	@IsTest
	private static void asValueSetWithSObjectFieldWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Set<Object> values = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Text__c)
					.condition(Foobar__c.Id).equals(record.Id)
					.asValueSet(Foobar__c.Text__c);

			Assert.isFalse(values.isEmpty(), 'Should return values');
		}
	}

	/**
	 * @description Tests asValueSet with String field name.
	 */
	@IsTest
	private static void asValueSetWithStringWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Set<Object> values = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(FIELD_TEXT)
					.condition(Foobar__c.Id).equals(record.Id)
					.asValueSet(FIELD_TEXT);

			Assert.isFalse(values.isEmpty(), 'Should return values');
		}
	}

	/**
	 * @description Tests asStringSet with SObjectField.
	 */
	@IsTest
	private static void asStringSetWithSObjectFieldWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Set<String> values = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.Text__c)
					.condition(Foobar__c.Id).equals(record.Id)
					.asStringSet(Foobar__c.Text__c);

			Assert.isFalse(values.isEmpty(), 'Should return values');
		}
	}

	/**
	 * @description Tests asStringSet with String field name.
	 */
	@IsTest
	private static void asStringSetWithStringWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Set<String> values = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(FIELD_TEXT)
					.condition(Foobar__c.Id).equals(record.Id)
					.asStringSet(FIELD_TEXT);

			Assert.isFalse(values.isEmpty(), 'Should return values');
		}
	}

	/**
	 * @description Tests isCached method.
	 */
	@IsTest
	private static void isCachedWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(record.Id);

			query.toList();

			Assert.isFalse(query.isCached(), 'Should not be cached on first execution');
		}
	}

	/**
	 * @description Tests toQueryLocator method.
	 */
	@IsTest
	private static void toQueryLocatorWorks()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();

			Database.QueryLocator locator = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).equals(record.Name)
					.toQueryLocator();

			Assert.isNotNull(locator, 'Should return query locator');
		}
	}

	/**
	 * @description Tests getRandomItem method with mock.
	 */
	@IsTest
	private static void getRandomItemWorks()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> mockRecords = new List<Foobar__c>
			{
					TST_Factory.newFoobarWithName('Random Test')
			};
			QRY_Builder.setMock(Foobar__c.SObjectType, mockRecords);

			SObject random = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).equals('Random Test')
					.getRandomItem();

			Assert.isNotNull(random, 'Should return random item');

			QRY_Builder.clearMocks();
		}
	}

	/**
	 * @description Tests getRandomItems method with mock.
	 */
	@IsTest
	private static void getRandomItemsWorks()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> mockRecords = new List<Foobar__c>();
			for(Integer i = 0; i < 3; i++)
			{
				mockRecords.add(TST_Factory.newFoobarWithName('Random Items Test ' + i));
			}
			QRY_Builder.setMock(Foobar__c.SObjectType, mockRecords);

			List<SObject> randoms = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).contains('Random Items Test')
					.getRandomItems(3);

			Assert.isFalse(randoms.isEmpty(), 'Should return random items');

			QRY_Builder.clearMocks();
		}
	}

	/**
	 * @description Tests getRandomItems with null count returns empty list.
	 */
	@IsTest
	private static void getRandomItemsWithNullCountReturnsEmpty()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> result = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.getRandomItems(null);

			Assert.isTrue(result.isEmpty(), 'Should return empty list for null count');
		}
	}

	/**
	 * @description Tests getRandomItems with zero count returns empty list.
	 */
	@IsTest
	private static void getRandomItemsWithZeroCountReturnsEmpty()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> result = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.getRandomItems(0);

			Assert.isTrue(result.isEmpty(), 'Should return empty list for zero count');
		}
	}

	/**
	 * @description Tests getRandomItem returns null when no records.
	 */
	@IsTest
	private static void getRandomItemReturnsNullWhenNoRecords()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.setMock(Foobar__c.SObjectType, new List<Foobar__c>());

			SObject random = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).equals('NonExistent')
					.getRandomItem();

			Assert.isNull(random, 'Should return null when no records');

			QRY_Builder.clearMocks();
		}
	}

	/**
	 * @description Tests getRandomItems with real data exercises cursor-based fetch.
	 */
	@IsTest
	private static void getRandomItemsWorksWithCursorFetch()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(3);

			List<SObject> result = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.getRandomItems(2);

			Assert.isFalse(result.isEmpty(), 'Should return random items via cursor');
			Assert.isTrue(result.size() <= 2, 'Should not exceed requested count');
		}
	}

	/**
	 * @description Tests subselect method.
	 */
	@IsTest
	private static void subselectWorks()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder childQuery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {'Name'});

			String soql = QRY_Builder.selectFrom(Account.SObjectType)
					.fields(new List<String> {'Name'})
					.subselect(childQuery, 'Contacts')
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT') && soql.containsIgnoreCase('FROM Account'), 'Should contain main query');
		}
	}

	/**
	 * @description Tests groupBy with SObjectField.
	 */
	@IsTest
	private static void groupByWithSObjectFieldWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Picklist__c)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('GROUP BY'), 'Should contain GROUP BY clause');
		}
	}

	/**
	 * @description Tests groupBy with String field name.
	 */
	@IsTest
	private static void groupByWithStringFieldWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(FIELD_PICKLIST)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('GROUP BY'), 'Should contain GROUP BY clause');
			Assert.isTrue(soql.containsIgnoreCase(FIELD_PICKLIST), 'Should contain field name');
		}
	}

	/**
	 * @description Tests multi-field GROUP BY.
	 */
	@IsTest
	private static void groupByMultipleFieldsWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.groupBy(FIELD_PICKLIST)
					.groupBy(FIELD_TEXT)
					.count(FIELD_ID)
					.toSoql();

			Assert.isTrue(soql.contains('GROUP BY ' + FIELD_PICKLIST + ', ' + FIELD_TEXT), 'Should contain multi-field GROUP BY');
		}
	}

	/**
	 * @description Tests GROUP BY ROLLUP.
	 */
	@IsTest
	private static void groupByRollupWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.groupBy(FIELD_PICKLIST)
					.groupBy(FIELD_TEXT)
					.count(FIELD_ID)
					.rollup()
					.toSoql();

			Assert.isTrue(soql.contains('GROUP BY ROLLUP(' + FIELD_PICKLIST + ', ' + FIELD_TEXT + ')'), 'Should contain GROUP BY ROLLUP');
		}
	}

	/**
	 * @description Tests GROUP BY CUBE.
	 */
	@IsTest
	private static void groupByCubeWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.groupBy(FIELD_PICKLIST)
					.groupBy(FIELD_TEXT)
					.count(FIELD_ID)
					.cube()
					.toSoql();

			Assert.isTrue(soql.contains('GROUP BY CUBE(' + FIELD_PICKLIST + ', ' + FIELD_TEXT + ')'), 'Should contain GROUP BY CUBE');
		}
	}

	/**
	 * @description Tests GROUPING() function in SELECT with String field name.
	 */
	@IsTest
	private static void groupingFunctionWithStringWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.groupBy(FIELD_PICKLIST)
					.grouping(FIELD_PICKLIST)
					.count(FIELD_ID)
					.rollup()
					.toSoql();

			Assert.isTrue(soql.contains('GROUPING(' + FIELD_PICKLIST + ')'), 'Should contain GROUPING function');
		}
	}

	/**
	 * @description Tests GROUPING() function in SELECT with SObjectField token.
	 */
	@IsTest
	private static void groupingFunctionWithSObjectFieldWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.groupBy(Foobar__c.Picklist__c)
					.grouping(Foobar__c.Picklist__c)
					.count(FIELD_ID)
					.rollup()
					.toSoql();

			Assert.isTrue(soql.contains('GROUPING('), 'Should contain GROUPING function with SObjectField');
		}
	}

	/**
	 * @description Tests combined ROLLUP with GROUPING and aggregate.
	 */
	@IsTest
	private static void groupByRollupWithGroupingAndAggregateWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.groupBy(FIELD_PICKLIST)
					.groupBy(FIELD_TEXT)
					.grouping(FIELD_PICKLIST)
					.grouping(FIELD_TEXT)
					.sum(Foobar__c.NumberDecimal__c)
					.rollup()
					.toSoql();

			Assert.isTrue(soql.contains('GROUP BY ROLLUP('), 'Should contain ROLLUP');
			Assert.isTrue(soql.contains('GROUPING(' + FIELD_PICKLIST + ')'), 'Should contain GROUPING for picklist');
			Assert.isTrue(soql.contains('GROUPING(' + FIELD_TEXT + ')'), 'Should contain GROUPING for text');
			Assert.isTrue(soql.containsIgnoreCase('SUM('), 'Should contain SUM aggregate');
		}
	}

	/**
	 * @description Tests orderBy with String field name.
	 */
	@IsTest
	private static void orderByWithStringFieldWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.orderBy(FIELD_NAME).ascending()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('ORDER BY ' + FIELD_NAME + ' ASC'), 'Should sort by string field ascending');
		}
	}

	/**
	 * @description Tests ascending/descending/nullsFirst/nullsLast with empty orderByFields.
	 */
	@IsTest
	private static void orderByModifiersIgnoredWhenEmpty()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.ascending()
					.descending()
					.nullsFirst()
					.nullsLast();

			String soql = query.toSoql();

			Assert.isFalse(soql.containsIgnoreCase('ORDER BY'), 'Should not contain ORDER BY when no fields');
		}
	}

	/**
	 * @description Tests fields with null SObjectField list.
	 */
	@IsTest
	private static void fieldsWithNullSObjectFieldListHandled()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields((List<SObjectField>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT Id'), 'Should default to Id field');
		}
	}

	/**
	 * @description Tests fields with null String list.
	 */
	@IsTest
	private static void fieldsWithNullStringListHandled()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields((List<String>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT Id'), 'Should default to Id field');
		}
	}

	/**
	 * @description Tests addFields with null SObjectField list.
	 */
	@IsTest
	private static void addFieldsWithNullSObjectFieldListHandled()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addFields((List<SObjectField>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT'), 'Should generate valid query');
		}
	}

	/**
	 * @description Tests addFields with null String list.
	 */
	@IsTest
	private static void addFieldsWithNullStringListHandled()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addFields((List<String>)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT'), 'Should generate valid query');
		}
	}

	/**
	 * @description Tests addField with null SObjectField.
	 */
	@IsTest
	private static void addFieldWithNullSObjectFieldHandled()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField((SObjectField)null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT'), 'Should generate valid query');
		}
	}

	/**
	 * @description Tests addField with blank String.
	 */
	@IsTest
	private static void addFieldWithBlankStringHandled()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField('')
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT'), 'Should generate valid query');
		}
	}

	/**
	 * @description Tests relatedField with blank String.
	 */
	@IsTest
	private static void relatedFieldWithBlankStringHandled()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.relatedField('')
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT'), 'Should generate valid query');
		}
	}

	/**
	 * @description Tests relatedFields with null list.
	 */
	@IsTest
	private static void relatedFieldsWithNullListHandled()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.relatedFields(null)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT'), 'Should generate valid query');
		}
	}

	/**
	 * @description Tests usingScope method.
	 */
	@IsTest
	private static void usingScopeWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.usingScope(QRY_Builder.Scope.EVERYTHING)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('USING SCOPE everything'), 'Should contain USING SCOPE clause');
		}
	}

	/**
	 * @description Tests usingScope with all scope values.
	 */
	@IsTest
	private static void usingScopeAllValuesWork()
	{
		System.runAs(getTestAdmin())
		{
			Assert.isTrue(QRY_Builder.selectFrom(Foobar__c.SObjectType).usingScope(QRY_Builder.Scope.MINE).toSoql().containsIgnoreCase('SCOPE mine'), 'MINE scope');
			Assert.isTrue
					(
							QRY_Builder.selectFrom(Foobar__c.SObjectType).usingScope(QRY_Builder.Scope.MY_TERRITORY).toSoql().containsIgnoreCase('SCOPE my_territory'),
							'MY_TERRITORY scope'
					);
			Assert.isTrue
					(
							QRY_Builder.selectFrom(Foobar__c.SObjectType).usingScope(QRY_Builder.Scope.MY_TEAM_TERRITORY).toSoql().containsIgnoreCase('SCOPE my_team_territory'),
							'MY_TEAM_TERRITORY scope'
					);
			Assert.isTrue(QRY_Builder.selectFrom(Foobar__c.SObjectType).usingScope(QRY_Builder.Scope.TEAM).toSoql().containsIgnoreCase('SCOPE team'), 'TEAM scope');
			Assert.isTrue(QRY_Builder.selectFrom(Foobar__c.SObjectType).usingScope(QRY_Builder.Scope.DELEGATED).toSoql().containsIgnoreCase('SCOPE delegated'), 'DELEGATED scope');
		}
	}

	/**
	 * @description Tests withDataCategory().at() with a single category.
	 */
	@IsTest
	private static void withDataCategoryAtSingleFilter()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Geography__c').at('USA__c')
					.toSoql();

			Assert.isTrue(soql.contains('WITH DATA CATEGORY Geography__c AT USA__c'), 'Should contain single data category filter');
		}
	}

	/**
	 * @description Tests withDataCategory().at() with multiple categories.
	 */
	@IsTest
	private static void withDataCategoryAtMultipleCategories()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Geography__c').at(new List<String> {'USA__c', 'Canada__c'})
					.toSoql();

			Assert.isTrue(soql.contains('WITH DATA CATEGORY Geography__c AT (USA__c, Canada__c)'), 'Should contain parenthesized categories');
		}
	}

	/**
	 * @description Tests withDataCategory().above() operator.
	 */
	@IsTest
	private static void withDataCategoryAboveSingleFilter()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Geography__c').above('USA__c')
					.toSoql();

			Assert.isTrue(soql.contains('Geography__c ABOVE USA__c'), 'Should contain ABOVE operator');
		}
	}

	/**
	 * @description Tests withDataCategory().below() operator.
	 */
	@IsTest
	private static void withDataCategoryBelowSingleFilter()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Product__c').below('Electronics__c')
					.toSoql();

			Assert.isTrue(soql.contains('Product__c BELOW Electronics__c'), 'Should contain BELOW operator');
		}
	}

	/**
	 * @description Tests withDataCategory().above() with multiple categories.
	 */
	@IsTest
	private static void withDataCategoryAboveMultipleCategories()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Geography__c').above(new List<String> {'USA__c', 'Canada__c'})
					.toSoql();

			Assert.isTrue(soql.contains('Geography__c ABOVE (USA__c, Canada__c)'), 'Should contain ABOVE with parenthesized categories');
		}
	}

	/**
	 * @description Tests withDataCategory().aboveOrBelow() operator.
	 */
	@IsTest
	private static void withDataCategoryAboveOrBelowSingleFilter()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Audience__c').aboveOrBelow('External')
					.toSoql();

			Assert.isTrue(soql.contains('Audience__c ABOVE_OR_BELOW External'), 'Should contain ABOVE_OR_BELOW operator');
		}
	}

	/**
	 * @description Tests withDataCategory().below() with multiple categories.
	 */
	@IsTest
	private static void withDataCategoryBelowMultipleCategories()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Product__c').below(new List<String> {'Electronics__c', 'Clothing__c'})
					.toSoql();

			Assert.isTrue(soql.contains('Product__c BELOW (Electronics__c, Clothing__c)'), 'Should contain BELOW with parenthesized categories');
		}
	}

	/**
	 * @description Tests withDataCategory().aboveOrBelow() with multiple categories.
	 */
	@IsTest
	private static void withDataCategoryAboveOrBelowMultipleCategories()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Audience__c').aboveOrBelow(new List<String> {'External', 'Internal'})
					.toSoql();

			Assert.isTrue(soql.contains('Audience__c ABOVE_OR_BELOW (External, Internal)'), 'Should contain ABOVE_OR_BELOW with parenthesized categories');
		}
	}

	/**
	 * @description Tests multiple data category groups joined with AND.
	 */
	@IsTest
	private static void withDataCategoryMultipleGroups()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.withDataCategory('Geography__c').at('USA__c')
					.withDataCategory('Product__c').below('Electronics__c')
					.toSoql();

			Assert.isTrue(soql.contains('WITH DATA CATEGORY Geography__c AT USA__c AND Product__c BELOW Electronics__c'),
					'Should contain multiple groups joined with AND');
		}
	}

	/**
	 * @description Tests withDataCategory throws on blank group name.
	 */
	@IsTest
	private static void withDataCategoryThrowsOnBlankGroupName()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).withDataCategory('');
				Assert.fail('Should throw IllegalArgumentException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests withDataCategory().at() throws on blank category name.
	 */
	@IsTest
	private static void withDataCategoryThrowsOnBlankCategoryName()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).withDataCategory('Geography__c').at('');
				Assert.fail('Should throw IllegalArgumentException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests withDataCategory().at() throws on empty category list.
	 */
	@IsTest
	private static void withDataCategoryThrowsOnEmptyCategoryList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).withDataCategory('Geography__c').at(new List<String>());
				Assert.fail('Should throw IllegalArgumentException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests withDataCategory().at() throws on null category list.
	 */
	@IsTest
	private static void withDataCategoryThrowsOnNullCategoryList()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType).withDataCategory('Geography__c').at((List<String>)null);
				Assert.fail('Should throw IllegalArgumentException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests withDataCategory throws on duplicate group.
	 */
	@IsTest
	private static void withDataCategoryThrowsOnDuplicateGroup()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.withDataCategory('Geography__c').at('USA__c')
						.withDataCategory('Geography__c').below('Canada__c');
				Assert.fail('Should throw IllegalArgumentException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
				Assert.isTrue(error.getMessage().contains('already been added'), 'Should mention duplicate group');
			}
		}
	}

	/**
	 * @description Tests duplicate group detection is case-insensitive.
	 */
	@IsTest
	private static void withDataCategoryDuplicateGroupIsCaseInsensitive()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				QRY_Builder.selectFrom(Foobar__c.SObjectType)
						.withDataCategory('Geography__c').at('USA__c')
						.withDataCategory('geography__c').below('Canada__c');
				Assert.fail('Should throw IllegalArgumentException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests data category filters chain with conditions and ordering.
	 */
	@IsTest
	private static void withDataCategoryChainsWithConditions()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField('Title')
					.condition('PublishStatus').equals('Online')
					.withDataCategory('Geography__c').at('USA__c')
					.orderBy('Title').ascending()
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('WHERE'), 'Should contain WHERE clause');
			Assert.isTrue(soql.contains('WITH DATA CATEGORY'), 'Should contain WITH DATA CATEGORY clause');
			Assert.isTrue(soql.containsIgnoreCase('ORDER BY'), 'Should contain ORDER BY clause');

			Integer whereIndex = soql.indexOf('WHERE');
			Integer dataCategoryIndex = soql.indexOf('WITH DATA CATEGORY');
			Integer orderByIndex = soql.toUpperCase().indexOf('ORDER BY');

			Assert.isTrue(whereIndex < dataCategoryIndex, 'WHERE should come before WITH DATA CATEGORY');
			Assert.isTrue(dataCategoryIndex < orderByIndex, 'WITH DATA CATEGORY should come before ORDER BY');
		}
	}

	/**
	 * @description Tests stripInaccessible with getPage.
	 */
	@IsTest
	private static void stripInaccessibleWithGetPageWorks()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(5);

			QRY_Builder.QueryPage result = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.stripInaccessible()
					.getPage(1, 3);

			Assert.areEqual(3, result.records.size(), 'Should return records with strip inaccessible');
		}
	}

	/**
	 * @description Tests QueryPage totalPages returns 1 when pageSize is null.
	 */
	@IsTest
	private static void queryPageTotalPagesReturnsOneForNullPageSize()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.QueryPage page = new QRY_Builder.QueryPage();
			page.totalRecords = 100;
			page.pageSize = null;

			Assert.areEqual(1, page.totalPages, 'Should return 1 when pageSize is null');
		}
	}

	/**
	 * @description Tests QueryPage totalPages returns 1 when pageSize is zero.
	 */
	@IsTest
	private static void queryPageTotalPagesReturnsOneForZeroPageSize()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.QueryPage page = new QRY_Builder.QueryPage();
			page.totalRecords = 100;
			page.pageSize = 0;

			Assert.areEqual(1, page.totalPages, 'Should return 1 when pageSize is zero');
		}
	}

	/**
	 * @description Tests QueryPage totalPages returns 1 when pageSize is negative.
	 */
	@IsTest
	private static void queryPageTotalPagesReturnsOneForNegativePageSize()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.QueryPage page = new QRY_Builder.QueryPage();
			page.totalRecords = 100;
			page.pageSize = -5;

			Assert.areEqual(1, page.totalPages, 'Should return 1 when pageSize is negative');
		}
	}

	/**
	 * @description Tests notInSetStrict with List of Objects succeeds for valid values.
	 */
	@IsTest
	private static void notInSetStrictListObjectsWorksForValidValues()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).notInSetStrict(new List<Object> {'Test1', 'Test2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('NOT IN'), 'Should contain NOT IN clause');
		}
	}

	/**
	 * @description Tests notInSetStrict with Set of Objects succeeds for valid values.
	 */
	@IsTest
	private static void notInSetStrictSetObjectsWorksForValidValues()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Name).notInSetStrict(new Set<Object> {'Test1', 'Test2'})
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('NOT IN'), 'Should contain NOT IN clause');
		}
	}

	/**
	 * @description Tests notInSetStrict with List of SObjects with mixed null and valid records.
	 */
	@IsTest
	private static void notInSetStrictSObjectsWithMixedNullsWorks()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = new List<Foobar__c>
			{
					null,
					TST_Factory.newFoobarWithMockId(),
					null,
					TST_Factory.newFoobarWithMockId()
			};

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).notInSetStrict(records)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('NOT IN'), 'Should contain NOT IN clause');
		}
	}

	/**
	 * @description Tests notInSetStrict with List of SObjects and explicit field extraction.
	 */
	@IsTest
	private static void notInSetStrictSObjectsWithFieldExtractionWorks()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = new List<Foobar__c>
			{
					TST_Factory.newFoobarWithMockId(),
					TST_Factory.newFoobarWithMockId()
			};

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Lookup__c).notInSetStrict(records, Foobar__c.Id)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('NOT IN'), 'Should contain NOT IN clause');
		}
	}

	/**
	 * @description Tests subquery with limit in semi-join.
	 */
	@IsTest
	private static void semiJoinSubqueryWithLimitWorks()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {SEL_Foobar.FIELD_LOOKUP})
					.withLimit(10);

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(FIELD_ID).isIn(subquery)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('LIMIT 10'), 'Should contain LIMIT in subquery');
		}
	}

	/**
	 * @description Tests subquery with offset in semi-join.
	 */
	@IsTest
	private static void semiJoinSubqueryWithOffsetWorks()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {SEL_Foobar.FIELD_LOOKUP})
					.withOffset(5);

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(FIELD_ID).isIn(subquery)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('OFFSET 5'), 'Should contain OFFSET in subquery');
		}
	}

	/**
	 * @description Tests subquery with selectAllFields in semi-join.
	 */
	@IsTest
	private static void semiJoinSubqueryWithSelectAllFieldsWorks()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.selectAllFields();

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(FIELD_ID).isIn(subquery)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('SELECT'), 'Should contain subquery');
			Assert.isTrue(soql.containsIgnoreCase('Id IN'), 'Should contain IN clause');
		}
	}

	/**
	 * @description Tests OR condition with trailing AND conditions adds final andGroup to orGroup.
	 */
	@IsTest
	private static void orConditionWithTrailingAndConditionsWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(SEL_Foobar.FIELD_TEXT).equals('Value1')
					.orCondition(SEL_Foobar.FIELD_EMAIL).equals('test@test.com')
					.andCondition(SEL_Foobar.FIELD_PHONE).equals('12345')
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('OR'), 'Should contain OR');
			Assert.isTrue(soql.containsIgnoreCase(SEL_Foobar.FIELD_PHONE), 'Should contain trailing condition');
		}
	}

	/**
	 * @description Tests subquery with Foobar__c self-lookup and limit.
	 */
	@IsTest
	private static void semiJoinSubqueryWithFoobarLookupWorks()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {SEL_Foobar.FIELD_LOOKUP})
					.withLimit(10)
					.withOffset(5);

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {'Name'})
					.condition(FIELD_ID).isIn(subquery)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('LIMIT 10'), 'Should contain LIMIT');
			Assert.isTrue(soql.containsIgnoreCase('OFFSET 5'), 'Should contain OFFSET');
		}
	}

	/**
	 * @description Tests fieldSet method with string name.
	 */
	@IsTest
	private static void fieldSetWithStringNameWorks()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fieldSet(SEL_Foobar.FIELDSET_AUDIT)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('CreatedDate'), 'Should contain CreatedDate from fieldset');
		}
	}

	/**
	 * @description Tests fieldSet method with Schema.FieldSet.
	 */
	@IsTest
	private static void fieldSetWithSchemaFieldSetWorks()
	{
		System.runAs(getTestAdmin())
		{
			FieldSet aFieldSet = SObjectType.Foobar__c.fieldSets.getMap().get(SEL_Foobar.FIELDSET_AUDIT);

			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fieldSet(aFieldSet)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('CreatedDate'), 'Should contain CreatedDate from fieldset');
		}
	}

	/**
	 * @description Tests that suppressPerformanceLogging sets the flag on the builder.
	 */
	@IsTest
	private static void suppressPerformanceLoggingSetsFlag()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.suppressPerformanceLogging();

			Assert.isTrue(builder.suppressPerformanceLog, 'suppressPerformanceLog should be true');
			Assert.isFalse(builder.forcePerformanceLog, 'forcePerformanceLog should be false');
		}
	}

	/**
	 * @description Tests that forcePerformanceLogging sets the flag on the builder.
	 */
	@IsTest
	private static void forcePerformanceLoggingSetsFlag()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.forcePerformanceLogging();

			Assert.isTrue(builder.forcePerformanceLog, 'forcePerformanceLog should be true');
			Assert.isFalse(builder.suppressPerformanceLog, 'suppressPerformanceLog should be false');
		}
	}

	/**
	 * @description Tests that logPerformanceIfSlowerThan sets the threshold.
	 */
	@IsTest
	private static void logPerformanceIfSlowerThanSetsThreshold()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.logPerformanceIfSlowerThan(500);

			Assert.areEqual(500, builder.performanceThresholdMs, 'performanceThresholdMs should be 500');
			Assert.isFalse(builder.suppressPerformanceLog, 'suppressPerformanceLog should be false');
			Assert.isFalse(builder.forcePerformanceLog, 'forcePerformanceLog should be false');
		}
	}

	/**
	 * @description Tests that performance settings are passed through to QueryParameters.
	 */
	@IsTest
	private static void passesPerformanceSettingsToParameters()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.suppressPerformanceLogging();

			QRY_BindRegistry registry = new QRY_BindRegistry();
			QRY_Engine.QueryParameters params = builder.buildParameters(registry);

			Assert.isTrue(params.suppressPerformanceLogging, 'suppressPerformanceLogging should be passed through');
			Assert.isFalse(params.forcePerformanceLogging, 'forcePerformanceLogging should be passed through');
			Assert.isNull(params.customPerformanceThresholdMs, 'customPerformanceThresholdMs should be null');
		}
	}

	/**
	 * @description Tests end-to-end query execution with performance logging integration.
	 */
	@IsTest
	private static void executesQueryWithPerformanceLogging()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c testRecord = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.Id).equals(testRecord.Id)
					.suppressPerformanceLogging()
					.toList();

			Assert.areEqual(1, results.size(), 'Should return record with performance logging configured');
		}
	}

	/**
	 * @description Tests that getSObjectType returns the SObjectType set on the builder.
	 */
	@IsTest
	private static void getSObjectTypeReturnsConfiguredType()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType);

			Assert.areEqual(Foobar__c.SObjectType, builder.objectType, 'Should return Foobar__c SObjectType');
		}
	}

	/**
	 * @description Tests full QRY_Builder path with mixed bind condition and DateLiteral condition.
	 */
	@IsTest
	private static void shouldExecuteQueryWithBindAndDateLiteral()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c testRecord = TST_Factory.insertFoobar();

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<String> {FIELD_NAME})
					.condition(Foobar__c.Id).equals(testRecord.Id)
					.condition('CreatedDate').equals(new QRY_Condition.DateLiteral().today())
					.toList();

			Assert.areEqual(1, results.size(), 'Should return record matching both bind and date literal');
			Assert.areEqual(testRecord.Id, results[0].Id, 'Should return correct record');
		}
	}

	/**
	 * @description Tests that the builder can be used as an IF_Queryable reference.
	 */
	@IsTest
	private static void builderImplementsQueryableInterface()
	{
		System.runAs(getTestAdmin())
		{
			IF_Queryable queryable = QRY_Builder.selectFrom(Foobar__c.SObjectType);

			Assert.isNotNull(queryable.toList(), 'Should return list via interface');
			Assert.areEqual(0, queryable.count(), 'Should return count via interface');
			Assert.isFalse(queryable.exists(), 'Should return exists via interface');
		}
	}

	/**
	 * @description Tests that toAggregateList returns AggregateRow wrappers with typed accessors.
	 */
	@IsTest
	private static void toAggregateListReturnsWrappedResults()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Name)
					.toAggregateList();

			Assert.isFalse(rows.isEmpty(), 'Should return aggregate rows');
			Assert.isNotNull(rows[0].getInteger('count_Id'), 'Should return count as Integer');
			Assert.isNotNull(rows[0].getString(FIELD_NAME), 'Should return grouped field as String');
			Assert.isNotNull(rows[0].get('count_Id'), 'Should return raw Object value');
		}
	}

	/**
	 * @description Tests that getFirstAggregate returns a single AggregateRow for scalar aggregates.
	 */
	@IsTest
	private static void getFirstAggregateReturnsSingleRow()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.NumberInteger__c, 10)
					.build();

			QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.sum(Foobar__c.NumberInteger__c)
					.getFirstAggregate();

			Assert.isNotNull(row, 'Should return aggregate row');
			Assert.isNotNull(row.getDecimal('sum_' + SEL_Foobar.FIELD_INTEGER), 'Should return SUM as Decimal');
		}
	}

	/**
	 * @description Tests that getFirstAggregate returns null when GROUP BY yields no results.
	 */
	@IsTest
	private static void getFirstAggregateReturnsNullForEmptyResults()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(Foobar__c.Name)
					.condition(Foobar__c.Name).equals('NonExistent_XYZ_12345')
					.getFirstAggregate();

			Assert.isNull(row, 'Should return null when no results');
		}
	}

	/**
	 * @description Tests that AggregateRow getDate returns a Date value from MIN aggregate.
	 */
	@IsTest
	private static void aggregateRowGetDateReturnsDateValue()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Date__c, Date.today())
					.build();

			QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.min(Foobar__c.Date__c)
					.getFirstAggregate();

			Assert.isNotNull(row, 'Should return aggregate row');
			Assert.areEqual(Date.today(), row.getDate('min_' + Foobar__c.Date__c.getDescribe().getName()), 'Should return Date value');
		}
	}

	/**
	 * @description Tests that AggregateRow getId returns an Id value from a grouped field.
	 */
	@IsTest
	private static void aggregateRowGetIdReturnsIdValue()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy('CreatedById')
					.toAggregateList();

			Assert.isFalse(rows.isEmpty(), 'Should return aggregate rows');
			Assert.isNotNull(rows[0].getId('CreatedById'), 'Should return Id value');
		}
	}

	/**
	 * @description Tests that AggregateRow getLong returns a Long value from a COUNT aggregate.
	 */
	@IsTest
	private static void aggregateRowGetLongReturnsLongValue()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobar();

			QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.getFirstAggregate();

			Assert.isNotNull(row, 'Should return aggregate row');
			Assert.isNotNull(row.getLong('count_Id'), 'Should return count as Long');
		}
	}

	/**
	 * @description Tests that getLong returns null for a null aggregate value.
	 */
	@IsTest
	private static void aggregateRowGetLongReturnsNullForNullValue()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.sum(Foobar__c.NumberInteger__c)
					.condition(Foobar__c.Name).equals('NonExistent_XYZ_12345')
					.getFirstAggregate();

			Assert.isNotNull(row, 'Should return aggregate row even with no matches');
			Assert.isNull(row.getLong('sum_' + Foobar__c.NumberInteger__c.getDescribe().getName()), 'Should return null for null aggregate');
		}
	}

	/**
	 * @description Tests that registerMockContextClass via QRY_Builder delegates to QRY_Engine.
	 */
	@IsTest
	private static void registerMockContextClassViaBuilderEnablesFiltering()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c matchingMock = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.NumberInteger__c, 10)
					.withoutInsertion(true).build();
			Foobar__c nonMatchingMock = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.NumberInteger__c, 20)
					.withoutInsertion(true).build();

			QRY_Builder.registerMockContextClass(Foobar__c.SObjectType, UTIL_FormulaContext.FoobarContext.class.getName());
			QRY_Builder.setMock(Foobar__c.SObjectType, new List<Foobar__c> {matchingMock, nonMatchingMock});

			List<SObject> results = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.condition(Foobar__c.NumberInteger__c).equals(10)
					.toList();

			Assert.areEqual(1, results.size(), 'Should filter mocks using registered context class');
		}
	}

	/**
	 * @description Tests that a subquery with a WHERE condition generates correct SOQL.
	 */
	@IsTest
	private static void semiJoinSubqueryWithConditionWorks()
	{
		System.runAs(getTestAdmin())
		{
			QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(Foobar__c.OwnerId)
					.condition(Foobar__c.Name).equals('Test');

			String soql = QRY_Builder.selectFrom(User.SObjectType)
					.condition(FIELD_ID).isIn(subquery)
					.toSoql();

			Assert.isTrue(soql.containsIgnoreCase('WHERE'), 'Should contain WHERE in subquery');
			Assert.isTrue(soql.containsIgnoreCase('Id IN'), 'Should contain IN clause');
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
	 * @description Tests that `withSystemMode` emits a `query` bypass audit entry recording
	 * the system-mode target. Validates the framework-wide bypass audit floor — query reads
	 * that opt out of USER_MODE-by-default leave a forensic trail.
	 *
	 * @see QRY_Builder.Builder.withSystemMode
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitBypassAuditOnWithSystemMode()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().toList();
		Test.stopTest();

		Map<String, Object> context = findBypassAuditContext('system-mode:' + String.valueOf(Foobar__c.SObjectType));
		Assert.isNotNull(context, 'withSystemMode should emit an object-qualified bypass audit entry');
		Assert.areEqual(UTIL_BypassAudit.SURFACE_QUERY, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Surface should be query');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
	}

	/**
	 * @description Tests that `systemModeInternal` flips USER_MODE off WITHOUT enqueuing a
	 * bypass audit entry. The framework-internal channel is the path used by `SEL_Base.query`
	 * for `systemModeRequired() == true` selectors and by `UTIL_FeatureFlag` CMDT/setting
	 * lookups — none of which are subscriber-facing bypasses, so they must not pollute the
	 * `BypassEvent` forensic trail. Without this contract, every framework-internal config
	 * read would emit a noise audit entry on every operation.
	 *
	 * @see QRY_Builder.Builder.systemModeInternal
	 * @see SEL_Base.query
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldNotEmitBypassAuditOnSystemModeInternal()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType).systemModeInternal();
		builder.toList();
		Test.stopTest();

		Assert.isFalse(builder.userModeEnabled, 'systemModeInternal should flip userModeEnabled to false');
		Assert.isNull(findBypassAuditContext('system-mode:' + String.valueOf(Foobar__c.SObjectType)),
				'systemModeInternal must not emit a bypass audit entry');
	}

	/**
	 * @description Tests that `bypassSharing` emits a `query` bypass audit entry recording
	 * the sharing target.
	 *
	 * @see QRY_Builder.Builder.bypassSharing
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitBypassAuditOnBypassSharing()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		QRY_Builder.selectFrom(Foobar__c.SObjectType).bypassSharing().toList();
		Test.stopTest();

		Map<String, Object> context = findBypassAuditContext('sharing:' + String.valueOf(Foobar__c.SObjectType));
		Assert.isNotNull(context, 'bypassSharing should emit an object-qualified bypass audit entry');
		Assert.areEqual(UTIL_BypassAudit.SURFACE_QUERY, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Surface should be query');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
	}

	/**
	 * @description Tests that `bypassSharingInternal` disables the sharing proxy WITHOUT enqueuing
	 * a bypass audit entry. The framework-internal channel is the path used by framework reads
	 * that structurally require org-wide visibility (the health check's trusted-site probe, the
	 * community-nickname uniqueness scan) — none of which are subscriber-facing bypasses, so they
	 * must not pollute the `BypassEvent` forensic trail.
	 *
	 * @see QRY_Builder.Builder.bypassSharingInternal
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldNotEmitBypassAuditOnBypassSharingInternal()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		QRY_Builder.Builder builder = QRY_Builder.selectFrom(Foobar__c.SObjectType).bypassSharingInternal();
		builder.toList();
		Test.stopTest();

		Assert.isFalse(builder.sharingEnforced, 'bypassSharingInternal should flip sharingEnforced to false');
		Assert.isNull(findBypassAuditContext('sharing:' + String.valueOf(Foobar__c.SObjectType)),
				'bypassSharingInternal must not emit a bypass audit entry');
	}

	/**
	 * @description Tests that `withoutSecurity` emits a `query` bypass audit entry recording
	 * the security-mode target.
	 *
	 * @see QRY_Builder.Builder.withoutSecurity
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitBypassAuditOnWithoutSecurity()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		QRY_Builder.selectFrom(Foobar__c.SObjectType).withoutSecurity().toList();
		Test.stopTest();

		Map<String, Object> context = findBypassAuditContext('security-mode:' + String.valueOf(Foobar__c.SObjectType));
		Assert.isNotNull(context, 'withoutSecurity should emit an object-qualified bypass audit entry');
		Assert.areEqual(UTIL_BypassAudit.SURFACE_QUERY, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Surface should be query');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
	}

	/**
	 * @description Tests that the latched `setBypassReason` flows into a query-side bypass audit
	 * entry, proving the cross-surface reason latch works through the query emission path.
	 *
	 * @see QRY_Builder.Builder.withSystemMode
	 * @see UTIL_BypassAudit.setBypassReason
	 */
	@IsTest
	private static void shouldRespectBypassReasonLatchOnQuerySystemMode()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		UTIL_BypassAudit.setBypassReason('Customer data migration');

		Test.startTest();
		QRY_Builder.selectFrom(Foobar__c.SObjectType).withSystemMode().toList();
		Test.stopTest();

		Map<String, Object> context = findBypassAuditContext('system-mode:' + String.valueOf(Foobar__c.SObjectType));
		Assert.isNotNull(context, 'withSystemMode should emit an object-qualified bypass audit entry');
		Assert.areEqual('Customer data migration', context.get(UTIL_BypassAudit.CONTEXT_REASON), 'Latched reason should appear in query bypass audit context');
	}

	/**
	 * @description Locates the most-recent bypass audit entry whose `target` context value matches
	 * the supplied target and returns its parsed inner context map. Returns `null` when no audit
	 * entry exists for the target. Helper used by the bypass-audit tests so each assertion focuses
	 * on the audit shape, not the JSON envelope or filter logic.
	 *
	 * @param target The bypass audit `target` context value to find.
	 *
	 * @return The inner context map for the matching audit entry, or `null` if none exists.
	 */
	private static Map<String, Object> findBypassAuditContext(String target)
	{
		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			if(context != null
					&& target.equals(context.get(UTIL_BypassAudit.CONTEXT_TARGET))
					&& UTIL_BypassAudit.SURFACE_QUERY.equals(context.get(UTIL_BypassAudit.CONTEXT_SURFACE)))
			{
				return context;
			}
		}
		return null;
	}

	/**
	 * @description Verifies groupBy(QRY_Function) renders the date-function expression into GROUP BY,
	 * and that a grouped-but-not-aliased-projected function is still echoed into SELECT (the de-dup
	 * leaves the plain echo untouched).
	 */
	@IsTest
	private static void groupByFunctionRendersIntoGroupByClause()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.toSoql();

			Assert.isTrue(soql.contains('GROUP BY CALENDAR_MONTH(' + FIELD_DATE + ')'), 'groupBy(QRY_Function) should render the expression into GROUP BY');
			Assert.isTrue(soql.contains('count_Id, CALENDAR_MONTH(' + FIELD_DATE + ')'), 'An unprojected grouped function should still be echoed into SELECT');
		}
	}

	/**
	 * @description Verifies the canonical bucket-and-aggregate query renders the function exactly once
	 * in SELECT — under its explicit alias — proving addField(QRY_Function, alias) projects the
	 * expression and the aggregate de-dup suppresses the redundant GROUP BY echo.
	 */
	@IsTest
	private static void addFieldAndGroupByFunctionEmitItOnce()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(QRY_Function.calendarMonth(Foobar__c.Date__c), 'dateBucket')
					.count(FIELD_ID)
					.groupBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.toSoql();

			String selectClause = soql.substringBetween('SELECT ', ' FROM');
			String expectedSelect = 'COUNT(Id) count_Id, CALENDAR_MONTH(' + FIELD_DATE + ') dateBucket';
			Assert.areEqual(expectedSelect, selectClause, 'Grouped-and-projected function must appear once in SELECT, under its alias');
			Assert.isTrue(soql.contains('GROUP BY CALENDAR_MONTH(' + FIELD_DATE + ')'), 'GROUP BY should retain the bare function expression');
		}
	}

	/**
	 * @description Regression guard: a plain grouped field with no separate aliased projection is still
	 * echoed into SELECT after the date-function de-dup change.
	 */
	@IsTest
	private static void plainFieldGroupingStillEchoesIntoSelect()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(FIELD_PICKLIST)
					.toSoql();

			Assert.isTrue(soql.contains('count_Id, ' + FIELD_PICKLIST), 'Plain grouped field must still echo into SELECT');
			Assert.isTrue(soql.contains('GROUP BY ' + FIELD_PICKLIST), 'GROUP BY should contain the plain field');
		}
	}

	/**
	 * @description Regression guard: a GROUPING() expression is still emitted alongside the echoed
	 * grouped field after the date-function de-dup change.
	 */
	@IsTest
	private static void groupingExpressionStillEmittedAlongsideFunctionDedup()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(FIELD_PICKLIST)
					.grouping(FIELD_PICKLIST)
					.rollup()
					.toSoql();

			Assert.isTrue(soql.contains('GROUPING(' + FIELD_PICKLIST + ')'), 'GROUPING() expression must still be emitted');
			Assert.isTrue(soql.contains('count_Id, ' + FIELD_PICKLIST), 'Grouped field must still echo alongside GROUPING()');
		}
	}

	/**
	 * @description Verifies orderBy(QRY_Function) renders the date-function expression into ORDER BY,
	 * ascending (no direction keyword emitted by default).
	 */
	@IsTest
	private static void orderByFunctionAscendingRendersExpression()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.orderBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.toSoql();

			Assert.isTrue(soql.contains('ORDER BY CALENDAR_MONTH(' + FIELD_DATE + ')'), 'orderBy(QRY_Function) should render the expression into ORDER BY');
			Assert.isFalse(soql.contains('CALENDAR_MONTH(' + FIELD_DATE + ') DESC'), 'Ascending order should not emit DESC');
		}
	}

	/**
	 * @description Verifies orderBy(QRY_Function, true) renders the date-function expression into ORDER
	 * BY with a DESC direction.
	 */
	@IsTest
	private static void orderByFunctionDescendingRendersDescending()
	{
		System.runAs(getTestAdmin())
		{
			String soql = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.count(FIELD_ID)
					.groupBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.orderBy(QRY_Function.calendarMonth(Foobar__c.Date__c), true)
					.toSoql();

			Assert.isTrue(soql.contains('ORDER BY CALENDAR_MONTH(' + FIELD_DATE + ') DESC'), 'orderBy(QRY_Function, true) should render DESC');
		}
	}

	/**
	 * @description End-to-end: buckets seeded records by calendar month, ascending, and reads back the
	 * bucket and the per-bucket count through the typed AggregateRow getters.
	 */
	@IsTest
	private static void dateBucketReportReturnsCountsPerCalendarMonth()
	{
		System.runAs(getTestAdmin())
		{
			for(Integer i = 0; i < 3; i++)
			{
				TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, Date.newInstance(2026, 3, 10 + i)).build();
			}
			for(Integer i = 0; i < 2; i++)
			{
				TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, Date.newInstance(2026, 6, 10 + i)).build();
			}

			List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(QRY_Function.calendarMonth(Foobar__c.Date__c), 'closeMonth')
					.count(FIELD_ID)
					.groupBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.orderBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.toAggregateList();

			Assert.areEqual(2, rows.size(), 'Should return one bucket per calendar month');
			Assert.areEqual(3, rows[0].getInteger('closeMonth'), 'First bucket (ascending) should be March');
			Assert.areEqual(3, rows[0].getInteger('count_Id'), 'March bucket should count three records');
			Assert.areEqual(6, rows[1].getInteger('closeMonth'), 'Second bucket should be June');
			Assert.areEqual(2, rows[1].getInteger('count_Id'), 'June bucket should count two records');
		}
	}

	/**
	 * @description End-to-end: dayOnly truncates a datetime to a Date bucket, read back via getDate
	 * (the read-back outlier). Two identical instants bucket together regardless of time zone.
	 */
	@IsTest
	private static void dayOnlyBucketReadsBackAsDate()
	{
		System.runAs(getTestAdmin())
		{
			// Seed two identical instants and one distinct instant: identical instants resolve to the
			// same DAY_ONLY date in any time zone, so the bucket counts are independent of the org/user TZ.
			Datetime marchInstant = Datetime.newInstanceGmt(2026, 3, 15, 12, 0, 0);
			Datetime juneInstant = Datetime.newInstanceGmt(2026, 6, 20, 12, 0, 0);
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Datetime__c, marchInstant).build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Datetime__c, marchInstant).build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Datetime__c, juneInstant).build();

			List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(QRY_Function.dayOnly(Foobar__c.Datetime__c), 'theDay')
					.count(FIELD_ID)
					.groupBy(QRY_Function.dayOnly(Foobar__c.Datetime__c))
					.toAggregateList();

			Assert.areEqual(2, rows.size(), 'dayOnly should produce two day buckets');
			Map<Date, Integer> dayToCount = new Map<Date, Integer>();
			for(QRY_Builder.AggregateRow row : rows)
			{
				Date bucketDay = row.getDate('theDay');
				Assert.isNotNull(bucketDay, 'dayOnly bucket should read back as a Date');
				dayToCount.put(bucketDay, row.getInteger('count_Id'));
			}
			Assert.areEqual(2, dayToCount.size(), 'Should be two distinct day buckets');
			Assert.isTrue(dayToCount.values().contains(2), 'The two identical instants should bucket together with count two');
		}
	}

	/**
	 * @description End-to-end: the date-bucket report runs under USER_MODE and still returns buckets,
	 * confirming the function wrapper is transparent to field-level-security enforcement.
	 */
	@IsTest
	private static void calendarMonthBucketsUnderUserModeReturnBuckets()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, Date.newInstance(2026, 3, 10)).build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, Date.newInstance(2026, 3, 11)).build();

			List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.addField(QRY_Function.calendarMonth(Foobar__c.Date__c), 'closeMonth')
					.count(FIELD_ID)
					.groupBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.withUserMode()
					.toAggregateList();

			Assert.areEqual(1, rows.size(), 'Should return one calendar-month bucket under USER_MODE');
			Assert.areEqual(3, rows[0].getInteger('closeMonth'), 'Bucket should be March');
			Assert.areEqual(2, rows[0].getInteger('count_Id'), 'Both records should be counted under USER_MODE');
		}
	}

	/**
	 * @description End-to-end: a SELECT + GROUP BY date-bucket query with no aggregate returns the
	 * distinct date buckets and reads back via the explicit alias.
	 */
	@IsTest
	private static void distinctCalendarMonthsReadBackWithoutAggregate()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, Date.newInstance(2026, 3, 10)).build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, Date.newInstance(2026, 3, 11)).build();
			TST_Factory.getFoobarBuilder().withOverride(Foobar__c.Date__c, Date.newInstance(2026, 6, 5)).build();

			List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					// empty fields() disables the default Id projection so a GROUP BY with no aggregate is valid SOQL
					.fields(new List<SObjectField>())
					.addField(QRY_Function.calendarMonth(Foobar__c.Date__c), 'bucket')
					.groupBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.orderBy(QRY_Function.calendarMonth(Foobar__c.Date__c))
					.toAggregateList();

			Assert.areEqual(2, rows.size(), 'Should return distinct calendar-month buckets without an aggregate');
			Assert.areEqual(3, rows[0].getInteger('bucket'), 'First bucket should be March');
			Assert.areEqual(6, rows[1].getInteger('bucket'), 'Second bucket should be June');
		}
	}
}