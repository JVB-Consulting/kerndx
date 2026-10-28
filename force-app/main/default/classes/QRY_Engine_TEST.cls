// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for QRY_Engine.
 * Tests query execution, mocking, sharing enforcement, and pagination.
 *
 * @see QRY_Engine
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity,PMD.NcssTypeCount,PMD.NcssCount,PMD.CognitiveComplexity')
@IsTest(seeAllData=false isParallel=true)
private class QRY_Engine_TEST
{
	/**
	 * @description Object API name for Foobar__c.
	 */
	private static final String OBJECT_NAME = SEL_Foobar.OBJECT_NAME;

	/**
	 * @description Field API name for Name.
	 */
	private static final String FIELD_NAME = SEL_Foobar.FIELD_NAME;

	/**
	 * @description Field API name for NumberInteger__c.
	 */
	private static final String FIELD_INTEGER = SEL_Foobar.FIELD_INTEGER;

	/**
	 * @description Name on the Foobar__c row stored for real by the queued-answer tests, so the read that reaches
	 * the database is told apart from the scripted answers by name as well as by Id.
	 */
	private static final String STORED_ROW_NAME = 'Stored for real';

	/**
	 * @description Name on the scripted Foobar__c record the queued-answer tests serve.
	 */
	private static final String SCRIPTED_ROW_NAME = 'Scripted answer';

	/**
	 * @description Text every refusal of a null queued answer must carry, pointing the caller at the empty list.
	 */
	private static final String EMPTY_LIST_HINT = 'empty list';

	/**
	 * @description Text the refusal of a null SObjectType must carry.
	 */
	private static final String NULL_TYPE_HINT = 'SObjectType';

	/**
	 * @description Text the refusal of a record of another type must carry.
	 */
	private static final String TYPE_MISMATCH_HINT = 'type mismatch';

	/**
	 * @description The relationship name of an account's contacts, used to subselect child rows.
	 */
	private static final String CONTACTS_RELATIONSHIP = 'Contacts';

	/**
	 * @description Time-to-live, in seconds, the cached-read tests ask for.
	 */
	private static final Integer CACHE_TIME_TO_LIVE_SECONDS = 300;

	/**
	 * @description Heap, in bytes, a memory hit may use beyond the same uncached read: the QueryResult wrapper a hit
	 * allocates.
	 */
	private static final Integer HIT_HEAP_MARGIN_BYTES = 2048;

	/**
	 * @description The length of the random key stored in the query result memory cache.
	 */
	private static final Integer MEMORY_CACHE_KEY_LENGTH = 20;

	/**
	 * @description The length of the random Name the memory cache tests give a row, or write over a stored row's Name.
	 */
	private static final Integer MEMORY_CACHE_VALUE_LENGTH = 10;

	/**
	 * @description The length of each string the heap guard test holds to reach the guard: large enough to get there in
	 * few steps.
	 */
	private static final Integer LARGE_VALUE_LENGTH = 100000;

	/**
	 * @description Alias of the count the aggregate cached-read test selects.
	 */
	private static final String TOTAL_ALIAS = 'total';

	/**
	 * @description The total held by the first registered aggregate row in the aggregate mock tests.
	 */
	private static final Integer FIRST_TOTAL = 3;

	/**
	 * @description The total held by the second registered aggregate row in the aggregate mock tests.
	 */
	private static final Integer SECOND_TOTAL = 5;

	/**
	 * @description The total held by the third registered aggregate row in the aggregate mock tests.
	 */
	private static final Integer THIRD_TOTAL = 8;

	/**
	 * @description The LIMIT the aggregate mock tests place on a query that has more registered rows than that.
	 */
	private static final Integer AGGREGATE_ROW_LIMIT = 2;

	/**
	 * @description The number of rows in an aggregate answer that holds one row.
	 */
	private static final Integer ONE_ROW = 1;

	/**
	 * @description The number of rows in an aggregate answer that holds two rows.
	 */
	private static final Integer TWO_ROWS = 2;

	/**
	 * @description The number of mock records the aggregate mock tests set with setMock, beside the aggregate rows.
	 */
	private static final Integer RECORD_MOCK_COUNT = 2;

	/**
	 * @description Text the refusal of an aggregate query that only record mocks could answer must carry: the name of
	 * the method that registers aggregate rows.
	 */
	private static final String REGISTER_AGGREGATE_ROWS_HINT = 'registerAggregateRows';

	/**
	 * @description Message of the aggregate-only exception the precedence test registers.
	 */
	private static final String AGGREGATE_FAILURE_MESSAGE = 'Aggregate-only failure';

	/**
	 * @description Tests basic query execution.
	 */
	@IsTest
	private static void shouldExecuteBasicQuery()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Test Account')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(1, result.records.size(), 'Should return one record');
		Assert.areEqual(testRecord.Id, result.records[0].Id, 'Should return correct record');
		Assert.isFalse(result.isMocked, 'Should not be mocked');
	}

	/**
	 * @description Tests query with USER_MODE.
	 */
	@IsTest
	private static void shouldExecuteWithUserMode()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Test Account')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.userMode = true;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(1, result.records.size(), 'Should return one record');
	}

	/**
	 * @description Tests mock registration and retrieval.
	 */
	@IsTest
	private static void shouldRegisterAndRetrieveMocks()
	{
		List<SObject> mockRecords = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(2)
				.withoutInsertion()
				.buildList();

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		Assert.isTrue(QRY_Engine.hasMock(Foobar__c.SObjectType), 'Should have mock registered');
		Assert.areEqual(2, QRY_Engine.getMock(Foobar__c.SObjectType).size(), 'Should return mock records');

		QRY_Engine.clearMocks();

		Assert.isFalse(QRY_Engine.hasMock(Foobar__c.SObjectType), 'Should not have mock after clear');
	}

	/**
	 * @description Tests query returns mocks when registered.
	 */
	@IsTest
	private static void shouldReturnMocksWhenRegistered()
	{
		List<SObject> mockRecords = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(3)
				.withoutInsertion()
				.buildList();

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(3, result.records.size(), 'Should return mock records');
		Assert.isTrue(result.isMocked, 'Should be mocked');
		Assert.areEqual(3, result.totalRecords, 'Should have correct total');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests mock pagination.
	 */
	@IsTest
	private static void shouldPaginateMocks()
	{
		List<SObject> mockRecords = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(5)
				.withoutInsertion()
				.buildList();

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME;
		parameters.pageSize = 2;
		parameters.pageNumber = 2;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(2, result.records.size(), 'Should return page size records');
		Assert.areEqual(5, result.totalRecords, 'Should have correct total');
		Assert.isTrue(result.hasMorePages, 'Should have more pages');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests mock with limit.
	 */
	@IsTest
	private static void shouldLimitMocks()
	{
		List<SObject> mockRecords = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(3)
				.withoutInsertion()
				.buildList();

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' LIMIT 2';
		parameters.limitCount = 2;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(2, result.records.size(), 'Should limit mock results');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests empty mock returns empty result.
	 */
	@IsTest
	private static void shouldReturnEmptyForEmptyMock()
	{
		QRY_Engine.setMock(Foobar__c.SObjectType, new List<Foobar__c>());

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.isTrue(result.records.isEmpty(), 'Should return empty list');
		Assert.areEqual(0, result.totalRecords, 'Should have zero total');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests mock pagination beyond available records.
	 */
	@IsTest
	private static void shouldReturnEmptyWhenPageBeyondMocks()
	{
		List<SObject> mockRecords = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(2)
				.withoutInsertion()
				.buildList();

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME;
		parameters.pageSize = 2;
		parameters.pageNumber = 5;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.isTrue(result.records.isEmpty(), 'Should return empty for page beyond data');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests clearing mocks with null.
	 */
	@IsTest
	private static void shouldClearMockWithNull()
	{
		List<SObject> mockRecords = TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.buildList();
		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);
		Assert.isTrue(QRY_Engine.hasMock(Foobar__c.SObjectType), 'Should have mock');

		QRY_Engine.setMock(Foobar__c.SObjectType, null);
		Assert.isFalse(QRY_Engine.hasMock(Foobar__c.SObjectType), 'Should not have mock after null');
	}

	/**
	 * @description Tests that a registered mock exception is thrown from execute.
	 */
	@IsTest
	private static void shouldThrowRegisteredExceptionFromExecute()
	{
		QueryException registered = new QueryException('Simulated SOQL failure');
		QRY_Engine.setMockException(Foobar__c.SObjectType, registered);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;

		Test.startTest();
		try
		{
			QRY_Engine.execute(parameters);
			Assert.fail('Should throw the registered exception');
		}
		catch(QueryException error)
		{
			Assert.areEqual('Simulated SOQL failure', error.getMessage(), 'Should rethrow the exact registered instance');
		}
		Test.stopTest();

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that a registered mock exception is thrown from executeCount.
	 */
	@IsTest
	private static void shouldThrowRegisteredExceptionFromExecuteCount()
	{
		QRY_Engine.setMockException(Foobar__c.SObjectType, new QueryException('Count failure'));

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT COUNT() FROM ' + OBJECT_NAME;

		try
		{
			QRY_Engine.executeCount(parameters);
			Assert.fail('Should throw the registered exception for executeCount');
		}
		catch(QueryException error)
		{
			Assert.areEqual('Count failure', error.getMessage(), 'Should rethrow the exact registered instance for count');
		}

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that a registered mock exception is thrown from getQueryLocator.
	 */
	@IsTest
	private static void shouldThrowRegisteredExceptionFromGetQueryLocator()
	{
		QRY_Engine.setMockException(Foobar__c.SObjectType, new QueryException('Locator failure'));

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;

		try
		{
			QRY_Engine.getQueryLocator(parameters);
			Assert.fail('Should throw the registered exception for getQueryLocator');
		}
		catch(QueryException error)
		{
			Assert.areEqual('Locator failure', error.getMessage(), 'Should rethrow the exact registered instance for locator');
		}

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that a registered mock exception is thrown from getCursor, exactly as it is from
	 * every other terminal, so a subscriber test can fail a cursor read without data tricks.
	 */
	@IsTest
	private static void shouldThrowRegisteredExceptionFromGetCursor()
	{
		QRY_Engine.setMockException(Foobar__c.SObjectType, new QueryException('Cursor failure'));

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;

		try
		{
			QRY_Engine.getCursor(parameters);
			Assert.fail('Should throw the registered exception for getCursor');
		}
		catch(QueryException error)
		{
			Assert.areEqual('Cursor failure', error.getMessage(), 'Should rethrow the exact registered instance for cursor');
		}

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that the registered exception fires even when mock records are also registered
	 * for the same SObjectType (throw-precedes-records semantics).
	 */
	@IsTest
	private static void shouldThrowExceptionEvenWhenRecordsAlsoMocked()
	{
		List<SObject> mockRecords = TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.buildList();
		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);
		QRY_Engine.setMockException(Foobar__c.SObjectType, new QueryException('Exception wins'));

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;

		try
		{
			QRY_Engine.execute(parameters);
			Assert.fail('Exception should fire before record path even when records are mocked');
		}
		catch(QueryException error)
		{
			Assert.areEqual('Exception wins', error.getMessage(), 'Exception should take precedence over mocked records');
		}

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that clearMockException removes the exception for a single SObjectType.
	 */
	@IsTest
	private static void shouldNotThrowAfterClearMockException()
	{
		QRY_Engine.setMockException(Foobar__c.SObjectType, new QueryException('Should be cleared'));
		Assert.isNotNull(QRY_Engine.getMockException(Foobar__c.SObjectType), 'Exception should be registered');

		QRY_Engine.clearMockException(Foobar__c.SObjectType);

		Assert.isNull(QRY_Engine.getMockException(Foobar__c.SObjectType), 'Exception should be cleared');

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME + ' WHERE Id = NULL';

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);
		Assert.areEqual(0, result.records.size(), 'Should proceed normally after clearing exception');
	}

	/**
	 * @description Tests that clearMockExceptions removes every registered exception across all types.
	 */
	@IsTest
	private static void shouldNotThrowAfterClearMockExceptions()
	{
		QRY_Engine.setMockException(Foobar__c.SObjectType, new QueryException('Wipe me'));
		QRY_Engine.setMockException(User.SObjectType, new QueryException('Wipe me too'));

		QRY_Engine.clearMockExceptions();

		Assert.isNull(QRY_Engine.getMockException(Foobar__c.SObjectType), 'Foobar exception should be cleared');
		Assert.isNull(QRY_Engine.getMockException(User.SObjectType), 'User exception should be cleared');
	}

	/**
	 * @description Tests that clearMocks also wipes registered exceptions.
	 */
	@IsTest
	private static void shouldClearExceptionsWhenClearMocksCalled()
	{
		QRY_Engine.setMockException(Foobar__c.SObjectType, new QueryException('Wipe via clearMocks'));
		Assert.isNotNull(QRY_Engine.getMockException(Foobar__c.SObjectType), 'Exception should be registered');

		QRY_Engine.clearMocks();

		Assert.isNull(QRY_Engine.getMockException(Foobar__c.SObjectType), 'Exception should be cleared by clearMocks');
	}

	/**
	 * @description Tests that setMockException registers the exception and getMockException returns it.
	 */
	@IsTest
	private static void shouldRegisterAndRetrieveMockException()
	{
		QueryException registered = new QueryException('Retrieve me');
		QRY_Engine.setMockException(Foobar__c.SObjectType, registered);

		Exception retrieved = QRY_Engine.getMockException(Foobar__c.SObjectType);

		Assert.areEqual(registered.getMessage(), retrieved.getMessage(), 'Should return the registered exception');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that getMockException returns null when no exception is registered for the type.
	 */
	@IsTest
	private static void shouldReturnNullWhenNoExceptionRegistered()
	{
		Assert.isNull(QRY_Engine.getMockException(Foobar__c.SObjectType), 'Should return null when no exception registered');
	}

	/**
	 * @description Tests that setMockException with a null SObjectType throws IllegalArgumentException.
	 */
	@IsTest
	private static void shouldThrowIllegalArgumentWhenNullObjectTypeOnSetMockException()
	{
		try
		{
			QRY_Engine.setMockException(null, new QueryException('Some failure'));
			Assert.fail('Should throw IllegalArgumentException for null SObjectType');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests that setMockException with a null exception throws IllegalArgumentException.
	 */
	@IsTest
	private static void shouldThrowIllegalArgumentWhenNullExceptionOnSetMockException()
	{
		try
		{
			QRY_Engine.setMockException(Foobar__c.SObjectType, null);
			Assert.fail('Should throw IllegalArgumentException for null exception');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests that an aggregate-scoped mock exception fires for a query whose parameters are
	 * stamped as an aggregate, and rethrows the exact registered instance.
	 */
	@IsTest
	private static void shouldThrowAggregateExceptionForAggregateQuery()
	{
		QRY_Engine.setMockAggregateException(Foobar__c.SObjectType, new QueryException('Aggregate-only failure'));

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT COUNT(Id) total FROM ' + OBJECT_NAME;
		parameters.aggregateQuery = true;

		try
		{
			QRY_Engine.execute(parameters);
			Assert.fail('Should throw the registered aggregate exception for an aggregate query');
		}
		catch(QueryException error)
		{
			Assert.areEqual('Aggregate-only failure', error.getMessage(), 'Should rethrow the exact registered instance');
		}

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests why the aggregate-only mock exists: with an aggregate-scoped exception registered, a ROW query
	 * against the same SObjectType still executes for real. A mock set with setMockException for the whole
	 * SObjectType cannot do that.
	 */
	@IsTest
	private static void shouldNotThrowAggregateExceptionForRowQuery()
	{
		QRY_Engine.setMockAggregateException(Foobar__c.SObjectType, new QueryException('Aggregate-only failure'));

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME + ' WHERE Id = NULL';

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(0, result.records.size(), 'A row query against the same SObjectType should execute for real');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that every clear path — per-type clearMockException, clearMockExceptions, and
	 * clearMocks — also removes an aggregate-scoped exception.
	 */
	@IsTest
	private static void shouldClearAggregateExceptionThroughEveryClearPath()
	{
		QRY_Engine.setMockAggregateException(Foobar__c.SObjectType, new QueryException('Wipe per type'));
		QRY_Engine.clearMockException(Foobar__c.SObjectType);
		Assert.isNull(QRY_Engine.getMockAggregateException(Foobar__c.SObjectType), 'clearMockException should remove the aggregate exception for the type');

		QRY_Engine.setMockAggregateException(Foobar__c.SObjectType, new QueryException('Wipe all'));
		QRY_Engine.clearMockExceptions();
		Assert.isNull(QRY_Engine.getMockAggregateException(Foobar__c.SObjectType), 'clearMockExceptions should remove every aggregate exception');

		QRY_Engine.setMockAggregateException(Foobar__c.SObjectType, new QueryException('Wipe via clearMocks'));
		QRY_Engine.clearMocks();
		Assert.isNull(QRY_Engine.getMockAggregateException(Foobar__c.SObjectType), 'clearMocks should remove every aggregate exception');
	}

	/**
	 * @description Tests that setMockAggregateException validates both arguments as non-null.
	 */
	@IsTest
	private static void shouldThrowIllegalArgumentForNullArgumentsOnSetMockAggregateException()
	{
		try
		{
			QRY_Engine.setMockAggregateException(null, new QueryException('Some failure'));
			Assert.fail('Should throw IllegalArgumentException for null SObjectType');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
		}
		try
		{
			QRY_Engine.setMockAggregateException(Foobar__c.SObjectType, null);
			Assert.fail('Should throw IllegalArgumentException for null exception');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests exception for null parameters.
	 */
	@IsTest
	private static void shouldThrowExceptionForNullParams()
	{
		try
		{
			QRY_Engine.execute(null);
			Assert.fail('Should throw exception for null parameters');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests exception for null SObjectType in setMock.
	 */
	@IsTest
	private static void shouldThrowExceptionForNullObjectType()
	{
		try
		{
			QRY_Engine.setMock(null, new List<Foobar__c>());
			Assert.fail('Should throw exception for null object type');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests exception for mismatched mock type.
	 */
	@IsTest
	private static void shouldThrowExceptionForMismatchedMockType()
	{
		try
		{
			QRY_Engine.setMock(Foobar__c.SObjectType, new List<SObject> {new User(LastName = 'Test')});
			Assert.fail('Should throw exception for mismatched type');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests count query execution.
	 */
	@IsTest
	private static void shouldExecuteCountQuery()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Test Account')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT COUNT() FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};

		Integer count = QRY_Engine.executeCount(parameters);

		Assert.areEqual(1, count, 'Should return correct count');
	}

	/**
	 * @description Tests count with mocks.
	 */
	@IsTest
	private static void shouldReturnMockCount()
	{
		List<SObject> mockRecords = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(3)
				.withoutInsertion()
				.buildList();

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT COUNT() FROM ' + OBJECT_NAME;

		Integer count = QRY_Engine.executeCount(parameters);

		Assert.areEqual(3, count, 'Should return mock count');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests exception for null parameters in count.
	 */
	@IsTest
	private static void shouldThrowExceptionForNullCountParams()
	{
		try
		{
			QRY_Engine.executeCount(null);
			Assert.fail('Should throw exception for null parameters');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests QueryLocator generation.
	 */
	@IsTest
	private static void shouldGetQueryLocator()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Test Account')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};

		Database.QueryLocator locator = QRY_Engine.getQueryLocator(parameters);

		Assert.isNotNull(locator, 'Should return query locator');
	}

	/**
	 * @description Tests exception for null parameters in getQueryLocator.
	 */
	@IsTest
	private static void shouldThrowExceptionForNullQueryLocatorParams()
	{
		try
		{
			QRY_Engine.getQueryLocator(null);
			Assert.fail('Should throw exception for null parameters');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests query with enforceSharing = true.
	 */
	@IsTest
	private static void shouldExecuteWithSharing()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Test Account')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.enforceSharing = true;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(1, result.records.size(), 'Should return record with sharing');
	}

	/**
	 * @description Tests query with enforceSharing = false.
	 */
	@IsTest
	private static void shouldExecuteWithoutSharing()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Test Account')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.enforceSharing = false;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(1, result.records.size(), 'Should return record without sharing');
	}

	/**
	 * @description Tests that a count honours the sharing dial on every setting, exactly as a row query
	 * does. A count that ignored enforceSharing would run under whatever sharing its caller happens to have,
	 * so a bypassed count could return a smaller number than the identical bypassed row query — the wrong
	 * direction for any caller that sizes a query before deciding whether to issue it.
	 */
	@IsTest
	private static void shouldExecuteCountUnderEachSharingSetting()
	{
		TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Test Account')
				.withCount(3)
				.buildList();

		Test.startTest();
		Integer enforcedCount = QRY_Engine.executeCount(countParametersFor(true));
		Integer bypassedCount = QRY_Engine.executeCount(countParametersFor(false));
		Integer inheritedCount = QRY_Engine.executeCount(countParametersFor(null));
		Test.stopTest();

		// This class is IsParallel=true, so it cannot create the second user a sharing DIVERGENCE needs.
		// It covers all three dispatch arms and checks that the owner's own rows are reachable through each;
		// the divergence itself is proven against a Private-OWD object in
		// QRY_Builder_TEST.countHonoursTheSharingBypassItAdvertises.
		Assert.areEqual(3, enforcedCount, 'The owner should reach every seeded row with sharing enforced');
		Assert.areEqual(3, bypassedCount, 'The owner should reach every seeded row with sharing bypassed');
		Assert.areEqual(3, inheritedCount, 'The owner should reach every seeded row under inherited sharing');
	}

	/**
	 * @description Builds count parameters for the Foobar fixture under one sharing setting.
	 *
	 * @param enforceSharing True to enforce, false to bypass, null to inherit.
	 *
	 * @return The count parameters.
	 */
	private static QRY_Engine.QueryParameters countParametersFor(Boolean enforceSharing)
	{
		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT COUNT() FROM ' + OBJECT_NAME;
		parameters.enforceSharing = enforceSharing;
		return parameters;
	}

	/**
	 * @description Tests that a locator is opened under every sharing setting and yields the owner's rows through
	 * each. This class is IsParallel=true, so it cannot create the second user a sharing divergence needs; the
	 * divergence itself is proven against a Private-OWD object in
	 * QRY_Builder_TEST.queryLocatorHonoursTheSharingBypassItAdvertises and queryLocatorBypassSurvivesBatchRetrieval.
	 */
	@IsTest
	private static void shouldOpenQueryLocatorUnderEachSharingSetting()
	{
		TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Test Account')
				.withCount(3)
				.buildList();

		Test.startTest();
		Integer enforcedRows = countLocatorRows(QRY_Engine.getQueryLocator(locatorParametersFor(true)));
		Integer bypassedRows = countLocatorRows(QRY_Engine.getQueryLocator(locatorParametersFor(false)));
		Integer inheritedRows = countLocatorRows(QRY_Engine.getQueryLocator(locatorParametersFor(null)));
		Test.stopTest();

		Assert.areEqual(3, enforcedRows, 'The owner should iterate every seeded row with sharing enforced');
		Assert.areEqual(3, bypassedRows, 'The owner should iterate every seeded row with sharing bypassed');
		Assert.areEqual(3, inheritedRows, 'The owner should iterate every seeded row under inherited sharing');
	}

	/**
	 * @description Builds locator parameters for the Foobar fixture under one sharing setting.
	 *
	 * @param enforceSharing True to enforce, false to bypass, null to inherit.
	 *
	 * @return The locator parameters.
	 */
	private static QRY_Engine.QueryParameters locatorParametersFor(Boolean enforceSharing)
	{
		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;
		parameters.enforceSharing = enforceSharing;
		return parameters;
	}

	/**
	 * @description Iterates a locator in the current transaction and counts the rows it yields.
	 *
	 * @param locator The locator under test.
	 *
	 * @return The number of rows iterated.
	 */
	private static Integer countLocatorRows(Database.QueryLocator locator)
	{
		Integer rows = 0;
		Database.QueryLocatorIterator locatorIterator = locator.iterator();
		while(locatorIterator.hasNext())
		{
			locatorIterator.next();
			rows++;
		}
		return rows;
	}

	/**
	 * @description Tests that a cursor is opened under every sharing setting and yields the owner's rows
	 * through each. This class is IsParallel=true, so it cannot create the second user a sharing divergence
	 * needs; the divergence itself is proven against a Private-OWD object in
	 * QRY_Builder_TEST.cursorHonoursTheSharingBypassItAdvertises and cursorBypassSurvivesCrossTransactionFetch.
	 */
	@IsTest
	private static void shouldOpenCursorUnderEachSharingSetting()
	{
		TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Test Account')
				.withCount(3)
				.buildList();

		Test.startTest();
		Integer enforcedRows = countCursorRows(QRY_Engine.getCursor(cursorParametersFor(true)));
		Integer bypassedRows = countCursorRows(QRY_Engine.getCursor(cursorParametersFor(false)));
		Integer inheritedRows = countCursorRows(QRY_Engine.getCursor(cursorParametersFor(null)));
		Test.stopTest();

		Assert.areEqual(3, enforcedRows, 'The owner should fetch every seeded row with sharing enforced');
		Assert.areEqual(3, bypassedRows, 'The owner should fetch every seeded row with sharing bypassed');
		Assert.areEqual(3, inheritedRows, 'The owner should fetch every seeded row under inherited sharing');
	}

	/**
	 * @description Builds cursor parameters for the Foobar fixture under one sharing setting.
	 *
	 * @param enforceSharing True to enforce, false to bypass, null to inherit.
	 *
	 * @return The cursor parameters.
	 */
	private static QRY_Engine.QueryParameters cursorParametersFor(Boolean enforceSharing)
	{
		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;
		parameters.enforceSharing = enforceSharing;
		return parameters;
	}

	/**
	 * @description Drains a cursor in the current transaction and counts the rows it yields.
	 *
	 * @param probeCursor The cursor under test.
	 *
	 * @return The fetched row count.
	 */
	private static Integer countCursorRows(Database.Cursor probeCursor)
	{
		Integer total = probeCursor.getNumRecords();
		return total == 0 ? 0 : probeCursor.fetch(0, total).size();
	}

	/**
	 * @description Tests cursor-based pagination.
	 */
	@IsTest
	private static void shouldExecuteWithCursor()
	{
		TST_Builder.of(Foobar__c.SObjectType)
				.withCount(10)
				.buildList();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' ORDER BY ' + FIELD_NAME;
		parameters.bindMap = new Map<String, Object>();
		parameters.cursorMode = QRY_Engine.CursorMode.PAGINATION;
		parameters.pageSize = 3;
		parameters.offset = 0;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(3, result.records.size(), 'Should return page size records');
		Assert.areEqual(10, result.totalRecords, 'Should have correct total');
		Assert.isTrue(result.hasMorePages, 'Should have more pages');
	}

	/**
	 * @description Tests that a pagination read whose guard count lands above the platform ceiling is served
	 * by a standard cursor instead. The platform throws an uncatchable governor exception when a pagination
	 * cursor is opened over too many rows, so the decision has to be made before the cursor exists.
	 */
	@IsTest
	private static void shouldServePageFromStandardCursorWhenGuardCountExceedsCeiling()
	{
		TST_Builder.of(Foobar__c.SObjectType)
				.withCount(5)
				.buildList();
		QRY_Engine.paginationCursorRowLimitOverride = 3;

		QRY_Engine.QueryResult result = QRY_Engine.execute(buildPageParameters(true, 2, 0));

		Assert.areEqual(2, result.records.size(), 'Should still return a full page');
		Assert.areEqual(5, result.totalRecords, 'Standard cursor should report the true total');
		Assert.isNull(result.cursor, 'No pagination cursor should be handed back once the read is diverted');
		Assert.areEqual(0, result.deletedRecords, 'A standard cursor cannot report deleted records');
	}

	/**
	 * @description Builds parameters for a paged read of every Foobar__c row.
	 *
	 * @param guarded Whether to attach the bounded guard count sized to the remaining allowance.
	 * @param pageSize The page size.
	 * @param offset The offset to read from.
	 *
	 * @return Parameters ready for QRY_Engine.execute.
	 *
	 * @date August 2026
	 */
	private static QRY_Engine.QueryParameters buildPageParameters(Boolean guarded, Integer pageSize, Integer offset)
	{
		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' ORDER BY ' + FIELD_NAME;
		parameters.bindMap = new Map<String, Object>();
		parameters.cursorMode = QRY_Engine.CursorMode.PAGINATION;
		parameters.pageSize = pageSize;
		parameters.offset = offset;

		if(guarded)
		{
			parameters.paginationGuardQuery = 'SELECT COUNT() FROM ' + OBJECT_NAME + ' LIMIT ' + QRY_Engine.getPaginationGuardRowLimit();
		}

		return parameters;
	}

	/**
	 * @description Tests that a guard count landing exactly ON the ceiling keeps the pagination cursor. The
	 * platform rejects the cursor only above the ceiling, so equality must not divert the read.
	 */
	@IsTest
	private static void shouldKeepPaginationCursorWhenGuardCountEqualsCeiling()
	{
		TST_Builder.of(Foobar__c.SObjectType)
				.withCount(3)
				.buildList();
		QRY_Engine.paginationCursorRowLimitOverride = 3;

		QRY_Engine.QueryResult result = QRY_Engine.execute(buildPageParameters(true, 2, 0));

		Assert.areEqual(2, result.records.size(), 'Should return a full page');
		Assert.areEqual(3, result.totalRecords, 'Should report the true total');
		Assert.isNotNull(result.cursor, 'A set exactly at the ceiling is still cursor-eligible');
	}

	/**
	 * @description Tests that a pagination read carrying no guard query behaves exactly as it did before the
	 * guard existed: the pagination cursor is opened directly, whatever the ceiling says.
	 */
	@IsTest
	private static void shouldOpenPaginationCursorWhenNoGuardQueryIsSet()
	{
		TST_Builder.of(Foobar__c.SObjectType)
				.withCount(5)
				.buildList();
		QRY_Engine.paginationCursorRowLimitOverride = 3;

		QRY_Engine.QueryResult result = QRY_Engine.execute(buildPageParameters(false, 2, 0));

		Assert.areEqual(2, result.records.size(), 'Should return a full page');
		Assert.areEqual(5, result.totalRecords, 'Should report the true total');
		Assert.isNotNull(result.cursor, 'Without a guard query the pagination cursor is opened as before');
	}

	/**
	 * @description Tests that a page is diverted once the transaction has no pagination cursor left to open.
	 * The instance allowance is per-transaction and separate from the row allowance, so a transaction can be
	 * well under the row ceiling and still be unable to open another cursor.
	 */
	@IsTest
	private static void shouldServePageFromStandardCursorWhenPaginationCursorPoolIsExhausted()
	{
		TST_Builder.of(Foobar__c.SObjectType)
				.withCount(5)
				.buildList();

		// Reading past the end of the result set claims a place in the pool without spending a fetch call.
		while(!UTIL_Limits.apexPaginationCursors().isExhausted())
		{
			QRY_Engine.execute(buildPageParameters(false, 2, 1000));
		}

		QRY_Engine.QueryResult result = QRY_Engine.execute(buildPageParameters(true, 2, 0));

		Assert.areEqual(2, result.records.size(), 'The page should still be served');
		Assert.areEqual(5, result.totalRecords, 'The standard cursor should report the true total');
		Assert.isNull(result.cursor, 'With no pagination cursor left to open, the page comes from a standard cursor');
	}

	/**
	 * @description Tests that a page fails with a clear, catchable error when no tier can serve it: no
	 * pagination cursor rows, no standard cursor, and no plain rendering to fall back on. Left to the
	 * platform, the same call would raise a governor exception no caller can catch, in a transaction that has
	 * already done work.
	 */
	@IsTest
	private static void shouldFailClearlyWhenNoTierCanServeThePage()
	{
		TST_Builder.of(Foobar__c.SObjectType)
				.withCount(5)
				.buildList();
		QRY_Engine.paginationCursorRowLimitOverride = 0;
		QRY_Engine.standardCursorLimitOverride = 0;

		try
		{
			QRY_Engine.execute(buildPageParameters(true, 2, 0));
			Assert.fail('A page with no tier left to serve it should be refused');
		}
		catch(UTIL_Exceptions.IllegalStateException expected)
		{
			Assert.isTrue(expected.getMessage().contains('no cursor capacity left'), 'The error should say the capacity is spent, got: ' + expected.getMessage());
		}
	}

	/**
	 * @description Tests QueryResult hasMorePages calculation.
	 */
	@IsTest
	private static void shouldCalculateHasMorePages()
	{
		Foobar__c mockRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();
		QRY_Engine.QueryResult result = new QRY_Engine.QueryResult();
		result.records = new List<SObject> {mockRecord};
		result.totalRecords = 5;

		Assert.isTrue(result.hasMorePages, 'Should have more pages when records < total');

		result.totalRecords = 1;
		Assert.isFalse(result.hasMorePages, 'Should not have more pages when records = total');
	}

	/**
	 * @description Tests QueryParameters defaults.
	 */
	@IsTest
	private static void shouldHaveCorrectDefaults()
	{
		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();

		Assert.isFalse(parameters.userMode, 'userMode should default to false');
		Assert.isNull(parameters.cursorMode, 'cursorMode should default to null');
		Assert.isFalse(parameters.bypassCache, 'bypassCache should default to false');
		Assert.areEqual(1, parameters.pageNumber, 'pageNumber should default to 1');
		Assert.isNull(parameters.enforceSharing, 'enforceSharing should default to null');
	}

	/**
	 * @description Tests that mock null records are handled.
	 */
	@IsTest
	private static void shouldHandleNullRecordsInMock()
	{
		Foobar__c mockRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();
		List<Foobar__c> mockRecords = new List<Foobar__c> {mockRecord, null};

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		Assert.isTrue(QRY_Engine.hasMock(Foobar__c.SObjectType), 'Should have mock after setting with null records');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests constants are defined correctly.
	 */
	@IsTest
	private static void shouldHaveCorrectConstants()
	{
		Assert.areEqual(900, QRY_Engine.DEFAULT_CACHE_TTL, 'DEFAULT_CACHE_TTL should be 900');
		Assert.areEqual(2000, QRY_Engine.MAX_QUERY_OFFSET, 'MAX_QUERY_OFFSET should be 2000');
	}

	/**
	 * @description Tests mock with limit when mock size equals limit count.
	 */
	@IsTest
	private static void shouldReturnAllMocksWhenSizeEqualsLimit()
	{
		List<SObject> mockRecords = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(2)
				.withoutInsertion()
				.buildList();

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' LIMIT 2';
		parameters.limitCount = 2;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(2, result.records.size(), 'Should return all mocks when size equals limit');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests mock with limit when mock size is less than limit count.
	 */
	@IsTest
	private static void shouldReturnAllMocksWhenSizeLessThanLimit()
	{
		List<SObject> mockRecords = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(2)
				.withoutInsertion()
				.buildList();

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' LIMIT 5';
		parameters.limitCount = 5;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(2, result.records.size(), 'Should return all mocks when size less than limit');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests cursor pagination when offset exceeds total records.
	 */
	@IsTest
	private static void shouldReturnEmptyWhenCursorOffsetExceedsTotal()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Test Account')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cursorMode = QRY_Engine.CursorMode.PAGINATION;
		parameters.pageSize = 10;
		parameters.offset = 1000;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.isTrue(result.records.isEmpty(), 'Should return empty when offset exceeds total');
	}

	/**
	 * @description Tests cursor pagination with null offset defaults to 0.
	 */
	@IsTest
	private static void shouldDefaultOffsetToZeroInCursor()
	{
		TST_Factory.insertFoobars(5);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' ORDER BY ' + FIELD_NAME;
		parameters.bindMap = new Map<String, Object>();
		parameters.cursorMode = QRY_Engine.CursorMode.PAGINATION;
		parameters.pageSize = 2;
		parameters.offset = null;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(2, result.records.size(), 'Should return first page when offset is null');
		Assert.areEqual(5, result.totalRecords, 'Should have correct total');
	}

	/**
	 * @description Tests cursor with null pageSize uses totalRecords.
	 */
	@IsTest
	private static void shouldUseDefaultPageSizeInCursor()
	{
		TST_Factory.insertFoobars(3);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME;
		parameters.bindMap = new Map<String, Object>();
		parameters.cursorMode = QRY_Engine.CursorMode.PAGINATION;
		parameters.pageSize = null;
		parameters.offset = 0;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(3, result.records.size(), 'Should return all records when pageSize is null');
	}

	/**
	 * @description Tests query locator with USER_MODE.
	 */
	@IsTest
	private static void shouldGetQueryLocatorWithUserMode()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Test Account')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.userMode = true;

		Database.QueryLocator locator = QRY_Engine.getQueryLocator(parameters);

		Assert.isNotNull(locator, 'Should return query locator in user mode');
	}

	/**
	 * @description Tests query locator with null bindMap.
	 */
	@IsTest
	private static void shouldGetQueryLocatorWithNullBindMap()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Test Null Binds')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = \'' + testRecord.Id + '\'';
		parameters.bindMap = null;

		Database.QueryLocator locator = QRY_Engine.getQueryLocator(parameters);

		Assert.isNotNull(locator, 'Should return query locator with null bindMap');
	}

	/**
	 * @description Tests cursor with recordsToRetrieve calculation edge case.
	 */
	@IsTest
	private static void shouldHandleCursorEdgeCaseWithSmallDataSet()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Single Cursor Test')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cursorMode = QRY_Engine.CursorMode.PAGINATION;
		parameters.pageSize = 100;
		parameters.offset = 0;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(1, result.records.size(), 'Should return single record');
		Assert.areEqual(1, result.totalRecords, 'Should have correct total');
		Assert.isFalse(result.hasMorePages, 'Should not have more pages');
	}

	/**
	 * @description Tests mock with limit greater than mock count returns all mocks.
	 */
	@IsTest
	private static void shouldReturnAllMocksWhenLimitExceedsMockCount()
	{
		List<SObject> mockRecords = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(2)
				.withoutInsertion()
				.buildList();

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' LIMIT 10';
		parameters.limitCount = 10;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(2, result.records.size(), 'Should return all mocks when limit exceeds count');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests mock with limit equal to mock count returns all mocks.
	 */
	@IsTest
	private static void shouldReturnAllMocksWhenLimitEqualsMockCount()
	{
		List<SObject> mockRecords = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(3)
				.withoutInsertion()
				.buildList();

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' LIMIT 3';
		parameters.limitCount = 3;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(3, result.records.size(), 'Should return all mocks when limit equals count');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests cursor pagination with offset exceeding total records returns empty.
	 */
	@IsTest
	private static void shouldReturnEmptyWhenCursorOffsetExceedsTotalRecords()
	{
		TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Cursor Offset Test')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE ' + FIELD_NAME + ' = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => 'Cursor Offset Test'};
		parameters.cursorMode = QRY_Engine.CursorMode.PAGINATION;
		parameters.pageSize = 10;
		parameters.offset = 100;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(0, result.records.size(), 'Should return empty when offset exceeds total');
		Assert.areEqual(1, result.totalRecords, 'Should still report correct total');
	}

	/**
	 * @description Tests that cache is NOT used when cacheTTL is null (default).
	 */
	@IsTest
	private static void shouldNotUseCacheWhenCacheTTLIsNull()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Cache Test Null')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cacheTTL = null;
		parameters.enforceSharing = false;

		QRY_Engine.QueryResult result1 = QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult result2 = QRY_Engine.execute(parameters);

		Assert.isFalse(result1.isCached, 'First call should NOT be cached');
		Assert.isFalse(result2.isCached, 'Second call should NOT be cached when TTL is null');
	}

	/**
	 * @description Tests that cache IS used when cacheTTL is set and bypassCache is false.
	 */
	@IsTest
	private static void shouldUseCacheWhenCacheTTLIsSet()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Cache Test TTL')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cacheTTL = 600;
		parameters.cacheScope = UTIL_Cache.Scope.AUTO;
		parameters.enforceSharing = false;
		parameters.bypassCache = false;

		QRY_Engine.QueryResult result1 = QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult result2 = QRY_Engine.execute(parameters);

		Assert.isFalse(result1.isCached, 'First call should be cache MISS');
		Assert.isTrue(result2.isCached, 'Second call should be cache HIT');
	}

	/**
	 * @description Tests that bypassCache flag overrides cacheTTL setting.
	 */
	@IsTest
	private static void shouldBypassCacheWhenFlagSet()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Cache Bypass Test')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cacheTTL = 600;
		parameters.cacheScope = UTIL_Cache.Scope.AUTO;
		parameters.enforceSharing = false;
		parameters.bypassCache = true;

		QRY_Engine.QueryResult result1 = QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult result2 = QRY_Engine.execute(parameters);

		Assert.isFalse(result1.isCached, 'First call should NOT be cached when bypassCache is true');
		Assert.isFalse(result2.isCached, 'Second call should NOT be cached when bypassCache is true');
	}

	/**
	 * @description Tests that a user-mode cached read is kept in memory for the transaction only: the repeat is a
	 * memory hit, because a user-mode result never goes to Platform Cache.
	 */
	@IsTest
	private static void shouldKeepUserModeReadInMemoryOnly()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'UserMode Cache Test')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cacheTTL = 600;
		parameters.cacheScope = UTIL_Cache.Scope.AUTO;
		parameters.enforceSharing = false;
		parameters.bypassCache = false;
		parameters.userMode = true;

		QRY_Engine.QueryResult result1 = QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult result2 = QRY_Engine.execute(parameters);

		Assert.isFalse(result1.isCached, 'The first user-mode read should be a miss');
		Assert.isTrue(result2.isCached, 'A repeat of a user-mode read should be served from memory');
		Assert.areEqual(QRY_Engine.CacheStatus.MEMORY_HIT, result2.cacheStatus, 'A user-mode result should be kept in memory, never in Platform Cache');
	}

	/**
	 * @description Tests that caching is disabled when lockForUpdate is true.
	 * Locking queries require fresh data for concurrency control.
	 */
	@IsTest
	private static void shouldNotCacheWhenLockForUpdateEnabled()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Lock Update Test')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1 FOR UPDATE';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cacheTTL = 600;
		parameters.cacheScope = UTIL_Cache.Scope.AUTO;
		parameters.enforceSharing = false;
		parameters.bypassCache = false;
		parameters.lockForUpdate = true;

		QRY_Engine.QueryResult result1 = QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult result2 = QRY_Engine.execute(parameters);

		Assert.isFalse(result1.isCached, 'FOR UPDATE queries should not be cached');
		Assert.isFalse(result2.isCached, 'FOR UPDATE queries should not be cached on repeat');
	}

	/**
	 * @description Tests that caching is disabled when lockForReference is true.
	 */
	@IsTest
	private static void shouldNotCacheWhenLockForReferenceEnabled()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Lock Reference Test')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1 FOR REFERENCE';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cacheTTL = 600;
		parameters.cacheScope = UTIL_Cache.Scope.AUTO;
		parameters.enforceSharing = false;
		parameters.bypassCache = false;
		parameters.lockForReference = true;

		QRY_Engine.QueryResult result1 = QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult result2 = QRY_Engine.execute(parameters);

		Assert.isFalse(result1.isCached, 'FOR REFERENCE queries should not be cached');
		Assert.isFalse(result2.isCached, 'FOR REFERENCE queries should not be cached on repeat');
	}

	/**
	 * @description Tests that caching is disabled when lockForView is true.
	 */
	@IsTest
	private static void shouldNotCacheWhenLockForViewEnabled()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Lock View Test')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1 FOR VIEW';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cacheTTL = 600;
		parameters.cacheScope = UTIL_Cache.Scope.AUTO;
		parameters.enforceSharing = false;
		parameters.bypassCache = false;
		parameters.lockForView = true;

		QRY_Engine.QueryResult result1 = QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult result2 = QRY_Engine.execute(parameters);

		Assert.isFalse(result1.isCached, 'FOR VIEW queries should not be cached');
		Assert.isFalse(result2.isCached, 'FOR VIEW queries should not be cached on repeat');
	}

	/**
	 * @description Tests that caching is disabled when includeAllRows is true.
	 * ALL ROWS queries may include deleted/archived records.
	 */
	@IsTest
	private static void shouldNotCacheWhenIncludeAllRowsEnabled()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'All Rows Test')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1 ALL ROWS';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cacheTTL = 600;
		parameters.cacheScope = UTIL_Cache.Scope.AUTO;
		parameters.enforceSharing = false;
		parameters.bypassCache = false;
		parameters.includeAllRows = true;

		QRY_Engine.QueryResult result1 = QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult result2 = QRY_Engine.execute(parameters);

		Assert.isFalse(result1.isCached, 'ALL ROWS queries should not be cached');
		Assert.isFalse(result2.isCached, 'ALL ROWS queries should not be cached on repeat');
	}

	/**
	 * @description Tests that caching is disabled when randomResults is true.
	 * Random queries should return different results each time.
	 */
	@IsTest
	private static void shouldNotCacheWhenRandomResultsEnabled()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Random Test')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cacheTTL = 600;
		parameters.cacheScope = UTIL_Cache.Scope.AUTO;
		parameters.enforceSharing = false;
		parameters.bypassCache = false;
		parameters.randomResults = true;

		QRY_Engine.QueryResult result1 = QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult result2 = QRY_Engine.execute(parameters);

		Assert.isFalse(result1.isCached, 'Random queries should not be cached');
		Assert.isFalse(result2.isCached, 'Random queries should not be cached on repeat');
	}

	/**
	 * @description Tests that cache hit returns correct isCached flag.
	 */
	@IsTest
	private static void shouldSetIsCachedFlagOnCacheHit()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Cached Flag Test')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cacheTTL = 600;
		parameters.cacheScope = UTIL_Cache.Scope.AUTO;
		parameters.enforceSharing = false;
		parameters.bypassCache = false;

		QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult cachedResult = QRY_Engine.execute(parameters);

		Assert.isTrue(cachedResult.isCached, 'isCached should be true on cache hit');
		Assert.areEqual(1, cachedResult.records.size(), 'Should return correct number of records');
	}

	/**
	 * @description Tests that a read whose sharing dial is left inherited is never cached: the engine cannot
	 * see the calling class's sharing at key time, so the identical inherited-dial read twice inside the TTL
	 * must miss both times rather than serve a hit it cannot key correctly.
	 */
	@IsTest
	private static void shouldNotCacheWhenSharingDialIsInherited()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Cache Test Inherited Dial')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cacheTTL = 600;
		parameters.cacheScope = UTIL_Cache.Scope.AUTO;
		parameters.bypassCache = false;

		QRY_Engine.QueryResult result1 = QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult result2 = QRY_Engine.execute(parameters);

		Assert.isFalse(result1.isCached, 'An inherited-dial read must not be cached');
		Assert.areEqual(QRY_Engine.CacheStatus.DECLINED_INHERITED_SHARING, result1.cacheStatus, 'An inherited-dial read must not be stored');
		Assert.isFalse(result2.isCached, 'An inherited-dial read must not be served from cache on repeat');
	}

	/**
	 * @description Tests that query execution populates queryDurationMs.
	 */
	@IsTest
	private static void shouldHaveQueryDurationAfterExecution()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Duration Test')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.isNotNull(result.queryDurationMs, 'queryDurationMs should be populated');
		Assert.isTrue(result.queryDurationMs >= 0, 'queryDurationMs should be non-negative');
	}

	/**
	 * @description Tests that mock queries do not populate queryDurationMs.
	 */
	@IsTest
	private static void shouldNotHaveQueryDurationForMocks()
	{
		List<SObject> mockRecords = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(2)
				.withoutInsertion()
				.buildList();

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.isNull(result.queryDurationMs, 'queryDurationMs should be null for mocks');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that cacheStatus is STORED on first execution with cache enabled. In an org with no Platform
	 * Cache space set aside, the rows are kept in memory for the transaction instead, and the status is
	 * MEMORY_STORED_NO_PARTITION.
	 */
	@IsTest
	private static void shouldTrackCacheStatusOnMiss()
	{
		QRY_Engine.CacheStatus expectedStatus = UTIL_Cache.isAllocated() ? QRY_Engine.CacheStatus.STORED : QRY_Engine.CacheStatus.MEMORY_STORED_NO_PARTITION;
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'CacheStatus STORED')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cacheTTL = 600;
		parameters.cacheScope = UTIL_Cache.Scope.AUTO;
		parameters.enforceSharing = false;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(expectedStatus, result.cacheStatus, 'Expected cacheStatus ' + expectedStatus + ' on the first call, got ' + result.cacheStatus);
	}

	/**
	 * @description Tests that cacheStatus is HIT on cache hit. In an org with no Platform Cache space set aside, the second
	 * call is served from the copy kept in memory for the transaction, and the status is MEMORY_HIT.
	 */
	@IsTest
	private static void shouldTrackCacheStatusOnHit()
	{
		QRY_Engine.CacheStatus expectedStatus = UTIL_Cache.isAllocated() ? QRY_Engine.CacheStatus.HIT : QRY_Engine.CacheStatus.MEMORY_HIT;
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'CacheStatus HIT')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cacheTTL = 600;
		parameters.cacheScope = UTIL_Cache.Scope.AUTO;
		parameters.enforceSharing = false;

		QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(expectedStatus, result.cacheStatus, 'Expected cacheStatus ' + expectedStatus + ' on the second call, got ' + result.cacheStatus);
	}

	/**
	 * @description Tests that a bypassed cached read whose rows or values depend on the running user is kept per
	 * user: a second user running the identical read is never served the first user's stored result. Each query
	 * carries one SOQL keyword the platform evaluates for the running user: a scope other than everything, a translated
	 * or formatted value, a time zone, or a date literal read in the user's time zone. The currency conversion is
	 * proved through a string literal, because it needs an org with several currencies to run as a function; a
	 * literal that holds such a keyword is the one false positive the key accepts, and it costs a per-user entry, never
	 * a wrong hit. In an org with no Platform Cache space set aside, the rows are kept in memory for the transaction, and
	 * the memory key always holds the user: the first user gets MEMORY_HIT and the second user still gets a fresh read,
	 * MEMORY_STORED_NO_PARTITION.
	 */
	@IsTest
	private static void shouldKeepABypassedCachedReadThatDependsOnTheUserPerUser()
	{
		Boolean hasCacheSpace = UTIL_Cache.isAllocated();
		QRY_Engine.CacheStatus expectedHit = hasCacheSpace ? QRY_Engine.CacheStatus.HIT : QRY_Engine.CacheStatus.MEMORY_HIT;
		QRY_Engine.CacheStatus expectedFreshRead = hasCacheSpace ? QRY_Engine.CacheStatus.STORED : QRY_Engine.CacheStatus.MEMORY_STORED_NO_PARTITION;
		String picklist = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Picklist__c);
		String currencyAmount = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Currency__c);
		String dateOnly = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Date__c);
		String dateTimeValue = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Datetime__c);
		List<String> userDependentQueries = new List<String>
		{
				'SELECT Id FROM ' + OBJECT_NAME + ' USING SCOPE MINE',
				'SELECT Id, toLabel(' + picklist + ') FROM ' + OBJECT_NAME,
				'SELECT Id, TOLABEL (' + picklist + ') FROM ' + OBJECT_NAME,
				'SELECT Id, FORMAT(' + currencyAmount + ') FROM ' + OBJECT_NAME,
				'SELECT Id FROM ' + OBJECT_NAME + ' WHERE Name = \'convertCurrency(\'',
				'SELECT Id FROM ' + OBJECT_NAME + ' WHERE HOUR_IN_DAY(convertTimezone(' + dateTimeValue + ')) > 0',
				'SELECT Id FROM ' + OBJECT_NAME + ' WHERE ' + dateOnly + ' = TODAY',
				'SELECT Id FROM ' + OBJECT_NAME + ' WHERE ' + dateOnly + ' = THIS_WEEK',
				'SELECT Id FROM ' + OBJECT_NAME + ' WHERE ' + dateTimeValue + ' = LAST_N_DAYS:7',
				'SELECT Id FROM ' + OBJECT_NAME + ' WHERE ' + dateOnly + ' = N_DAYS_AGO:3',
				'SELECT Id FROM ' + OBJECT_NAME + ' WHERE ' + dateOnly + ' = NEXT_90_DAYS',
				'SELECT Id FROM ' + OBJECT_NAME + ' WHERE ' + dateOnly + ' = THIS_FISCAL_QUARTER',
				'SELECT Id FROM ' + OBJECT_NAME + ' WHERE ' + dateOnly + ' = LAST_N_FISCAL_YEARS:2'
		};
		User firstUser = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		User secondUser = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);

		Test.startTest();
		System.runAs(firstUser)
		{
			for(String query : userDependentQueries)
			{
				QRY_Engine.execute(buildBypassedCachedRead(query));
				Assert.areEqual(expectedHit, QRY_Engine.execute(buildBypassedCachedRead(query)).cacheStatus,
						'Expected the first user to be served their own stored result, so the entry exists, for ' + query);
			}
		}
		System.runAs(secondUser)
		{
			for(String query : userDependentQueries)
			{
				Assert.areEqual(expectedFreshRead, QRY_Engine.execute(buildBypassedCachedRead(query)).cacheStatus,
						'Expected a second user never to be served the first user\'s result for ' + query);
			}
		}
		Test.stopTest();
	}

	/**
	 * @description Tests that a bypassed cached read whose rows are the same for everyone keeps its single org-wide
	 * entry: a second user running the identical read is served the first user's stored result. The everything scope and
	 * a fixed date are read the same for every user, so both stay shared too. In an org with no Platform Cache space set
	 * aside, there is no org-wide entry to share: the rows are kept in memory, the memory key always holds the user, and
	 * the second user gets a fresh read, MEMORY_STORED_NO_PARTITION.
	 */
	@IsTest
	private static void shouldShareABypassedCachedReadThatIsTheSameForEveryUser()
	{
		QRY_Engine.CacheStatus expectedStatus = UTIL_Cache.isAllocated() ? QRY_Engine.CacheStatus.HIT : QRY_Engine.CacheStatus.MEMORY_STORED_NO_PARTITION;
		String dateOnly = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Date__c);
		List<String> sharedQueries = new List<String>
		{
				'SELECT Id, Name FROM ' + OBJECT_NAME,
				'SELECT Id FROM ' + OBJECT_NAME + ' USING SCOPE EVERYTHING',
				'SELECT Id FROM ' + OBJECT_NAME + ' WHERE ' + dateOnly + ' = 2026-01-01'
		};
		User firstUser = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		User secondUser = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);

		Test.startTest();
		System.runAs(firstUser)
		{
			for(String query : sharedQueries)
			{
				QRY_Engine.execute(buildBypassedCachedRead(query));
			}
		}
		System.runAs(secondUser)
		{
			for(String query : sharedQueries)
			{
				Assert.areEqual(expectedStatus, QRY_Engine.execute(buildBypassedCachedRead(query)).cacheStatus,
						'Expected a read that is the same for every user to give ' + expectedStatus + ' for ' + query);
			}
		}
		Test.stopTest();
	}

	/**
	 * @description Tests that a cached read made with bypassSharing() alone is never served to another user's read that
	 * keeps record sharing. Both users may read Foobar__c records but cannot see the row the test administrator owns.
	 * The first user stores a bypassed read with the org-wide cache scope, and reads it again to show the stored result
	 * exists. The second user runs the same query with withSharing() and the same scope. That read must go to the
	 * database, not to the stored result, and must not see the administrator's row. This holds whether the org has
	 * Platform Cache space or keeps the rows in memory, so the test needs no branch for it.
	 */
	@IsTest
	private static void bypassedCachedReadIsNotServedToAnotherUsersEnforcedRead()
	{
		User firstUser = insertFoobarReader();
		User secondUser = insertFoobarReader();
		Foobar__c row;
		System.runAs(new User(Id = UserInfo.getUserId()))
		{
			row = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, UTIL_Random.randomName())
					.withOverride(Foobar__c.Email__c, UTIL_Random.randomEmail())
					.build();
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		Boolean firstUserRepeatCached;
		Boolean secondUserCached;
		List<SObject> secondUserRows;

		Test.startTest();
		System.runAs(firstUser)
		{
			newOrgCachedRowRead(row.Id).bypassSharing().toList();
			QRY_Builder.Builder repeat = newOrgCachedRowRead(row.Id).bypassSharing();
			repeat.toList();
			firstUserRepeatCached = repeat.isCached();
		}
		System.runAs(secondUser)
		{
			QRY_Builder.Builder enforced = newOrgCachedRowRead(row.Id).withSharing();
			secondUserRows = enforced.toList();
			secondUserCached = enforced.isCached();
		}
		Test.stopTest();

		Assert.isTrue(firstUserRepeatCached, 'Expected the first user to be served the stored result, which shows the entry exists');
		Assert.isFalse(secondUserCached, 'Expected the second user\'s read with withSharing() to go to the database, not to the bypassed result');
		Assert.areEqual(0, secondUserRows.size(), 'Expected record sharing to hide the row the test administrator owns from the second user');
	}

	/**
	 * @description Tests that a cached read made with bypassSharing() alone is shared between users, and that the
	 * fields each user cannot read are removed from the rows that user gets. Neither user can see the row the test
	 * administrator owns through record sharing. The first user may read Email__c and stores a bypassed read of the
	 * row, with its Email__c, at the org-wide cache scope. The second user cannot read Email__c and runs the same
	 * bypassed read at the same scope. The second read is served from the stored result, because a bypassed read is
	 * the same for every user, but its row has no Email__c. The first user's row keeps the email. In an org with no
	 * Platform Cache space set aside, the rows are kept in memory and the memory key holds the user, so the second
	 * user's first read is a fresh read. The second user then reads again, and that read is served from memory, still
	 * without Email__c.
	 */
	@IsTest
	private static void bypassedCachedReadRemovesHiddenFieldsForEachUser()
	{
		Boolean hasCacheSpace = UTIL_Cache.isAllocated();
		User emailReader = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_STANDARD_USER,
						new List<SObjectType> {Foobar__c.SObjectType},
						new List<SObjectField> {ObjectPermissions.PermissionsRead},
						Foobar__c.ExternalId__c
				);
		User restricted = insertFoobarReader();
		Foobar__c row;
		System.runAs(new User(Id = UserInfo.getUserId()))
		{
			row = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, UTIL_Random.randomName())
					.withOverride(Foobar__c.Email__c, UTIL_Random.randomEmail().toLowerCase())
					.build();
		}
		TST_Factory.newFeatureFlag(QRY_Builder.FLAG_USER_MODE_QUERIES, true);

		List<SObject> emailReaderRows;
		List<SObject> restrictedRows;
		Boolean restrictedCached;

		Test.startTest();
		System.runAs(emailReader)
		{
			emailReaderRows = newOrgCachedRowRead(row.Id).addField(Foobar__c.Email__c).bypassSharing().toList();
		}
		System.runAs(restricted)
		{
			if(!hasCacheSpace)
			{
				newOrgCachedRowRead(row.Id).addField(Foobar__c.Email__c).bypassSharing().toList();
			}
			QRY_Builder.Builder shared = newOrgCachedRowRead(row.Id).addField(Foobar__c.Email__c).bypassSharing();
			restrictedRows = shared.toList();
			restrictedCached = shared.isCached();
		}
		Test.stopTest();

		Assert.areEqual(1, emailReaderRows.size(), 'Expected the first user to read the row the test administrator owns');
		Assert.areEqual(row.Email__c, emailReaderRows[0].get(Foobar__c.Email__c), 'Expected the first user, who may read Email__c, to get the email');
		Assert.isTrue(restrictedCached, hasCacheSpace
				? 'Expected the second user to be served the result the first user stored'
				: 'Expected the second user\'s repeat read to be served from memory');
		Assert.areEqual(1, restrictedRows.size(), 'Expected the second user to get the row from the stored result');
		Assert.isFalse(restrictedRows[0].isSet(Foobar__c.Email__c), 'Expected the email, which the second user cannot read, to be removed');
	}

	/**
	 * @description Saves a Standard User who may read Foobar__c records and every Foobar__c field except Email__c. The user
	 * has no View All, so record sharing hides the rows another user owns.
	 *
	 * @return The saved user
	 */
	private static User insertFoobarReader()
	{
		return TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_STANDARD_USER,
						new List<SObjectType> {Foobar__c.SObjectType},
						new List<SObjectField> {ObjectPermissions.PermissionsRead},
						Foobar__c.Email__c
				);
	}

	/**
	 * @description Starts a Foobar__c query that reads the Name of one row and keeps its result in the org-wide cache.
	 *
	 * @param rowId The Id of the row to read
	 *
	 * @return The new query
	 */
	private static QRY_Builder.Builder newOrgCachedRowRead(Id rowId)
	{
		return QRY_Builder.selectFrom(Foobar__c.SObjectType)
				.fields(new List<SObjectField> {Foobar__c.Name})
				.condition(Foobar__c.Id).equals(rowId)
				.withCache(UTIL_Cache.Scope.ORG, CACHE_TIME_TO_LIVE_SECONDS);
	}

	/**
	 * @description Builds a cached, system-mode read with sharing bypassed: the only kind of read whose key leaves the
	 * running user out unless the query depends on that user.
	 *
	 * @param query The SOQL to run.
	 *
	 * @return The query parameters.
	 */
	private static QRY_Engine.QueryParameters buildBypassedCachedRead(String query)
	{
		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = query;
		parameters.cacheTTL = QRY_Engine.DEFAULT_CACHE_TTL;
		parameters.cacheScope = UTIL_Cache.Scope.AUTO;
		parameters.enforceSharing = false;
		return parameters;
	}

	/**
	 * @description Tests that cacheStatus is BYPASS when caching is not enabled.
	 */
	@IsTest
	private static void shouldTrackCacheStatusBypass()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'CacheStatus BYPASS')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(QRY_Engine.CacheStatus.BYPASS, result.cacheStatus, 'cacheStatus should be BYPASS when no cache');
	}

	/**
	 * @description Tests that performance parameters have correct defaults.
	 */
	@IsTest
	private static void shouldHaveCorrectPerformanceDefaults()
	{
		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();

		Assert.isFalse(parameters.suppressPerformanceLogging, 'suppressPerformanceLogging should default to false');
		Assert.isFalse(parameters.forcePerformanceLogging, 'forcePerformanceLogging should default to false');
		Assert.isNull(parameters.customPerformanceThresholdMs, 'customPerformanceThresholdMs should default to null');
	}

	/**
	 * @description Tests that suppress performance logging prevents LogEntry__c creation.
	 */
	@IsTest
	private static void shouldSuppressPerformanceLogging()
	{
		Foobar__c testRecord = TST_Factory.insertFoobar();
		TST_Factory.setupLoggerForTest(true, 0, true, 0);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.suppressPerformanceLogging = true;

		Test.startTest();

		LOG_Builder.ignoreTestMode = true;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Test.stopTest();

		Assert.areEqual(1, result.records.size(), 'Should still return records when logging suppressed');
		Assert.isNotNull(result.queryDurationMs, 'Duration should still be tracked');

		LOG_Builder.ignoreTestMode = false;

		LogEntry__c log = new SEL_LogEntry().findByMethod(QRY_Engine.class.getName() + '/executeQuery');
		Assert.isNull(log, 'Performance log should NOT be created when suppressPerformanceLogging is true');
	}

	/**
	 * @description Tests that force performance logging creates an LogEntry__c record.
	 */
	@IsTest
	private static void shouldForcePerformanceLogging()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 999999, true, 999999);

		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Force Perf')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.forcePerformanceLogging = true;

		Test.startTest();

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Test.stopTest();

		Assert.areEqual(1, result.records.size(), 'Should still return records when logging forced');
		Assert.isNotNull(result.queryDurationMs, 'Duration should be tracked');

		LogEntry__c log = new SEL_LogEntry().findByMethod(QRY_Engine.class.getName() + '/executeQuery');
		Assert.isNotNull(log, 'Performance log should be created when forcePerformanceLogging is true');
		Assert.isNotNull(log.DurationMs__c, 'Log should include duration');
	}

	/**
	 * @description Tests that custom performance threshold does not prevent query execution.
	 */
	@IsTest
	private static void shouldApplyCustomPerformanceThreshold()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(true, 999999, true, 999999);

		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Custom Threshold')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.customPerformanceThresholdMs = 0;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(1, result.records.size(), 'Should still return records with custom threshold');
		Assert.isNotNull(result.queryDurationMs, 'Duration should be tracked');
	}

	/**
	 * @description Tests that count query populates duration via timer.
	 */
	@IsTest
	private static void shouldHaveQueryDurationForCountQuery()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Count Duration')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT COUNT() FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};

		Integer count = QRY_Engine.executeCount(parameters);

		Assert.areEqual(1, count, 'Should return correct count');
	}

	/**
	 * @description Tests query execution with mixed bind variables and inline date literals.
	 */
	@IsTest
	private static void shouldExecuteQueryWithBindAndDateLiteral()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Mixed Literal Test')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1 AND CreatedDate = TODAY';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(1, result.records.size(), 'Should return record matching both bind and date literal conditions');
		Assert.areEqual(testRecord.Id, result.records[0].Id, 'Should return correct record');
	}

	/**
	 * @description Tests that getQueryLocator works with performance timer.
	 */
	@IsTest
	private static void shouldHaveQueryDurationForQueryLocator()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Locator Duration')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};

		Database.QueryLocator locator = QRY_Engine.getQueryLocator(parameters);

		Assert.isNotNull(locator, 'Should return query locator with performance timer');
	}

	/**
	 * @description Tests that mock filtering with EQUALS returns only matching records.
	 */
	@IsTest
	private static void shouldFilterMocksWithEquals()
	{
		List<Foobar__c> mocks = new List<Foobar__c>
		{
				(Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
						.withOverride(Foobar__c.NumberInteger__c, 10)
						.withoutInsertion(true).build(),
				(Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
						.withOverride(Foobar__c.NumberInteger__c, 20)
						.withoutInsertion(true).build(),
				(Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
						.withOverride(Foobar__c.NumberInteger__c, 10)
						.withoutInsertion(true).build()
		};

		QRY_Engine.setMock(Foobar__c.SObjectType, mocks);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;
		parameters.whereCondition = new QRY_Condition.FieldCondition(FIELD_INTEGER, QRY_Condition.Operator.EQUALS, 10);

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(2, result.records.size(), 'Should return only matching records');
		Assert.areEqual(2, result.totalRecords, 'Total records should reflect filtered count');
		Assert.isTrue(result.isMocked, 'Should be mocked');
	}

	/**
	 * @description Tests that mock filtering with GREATER_THAN returns only matching records.
	 */
	@IsTest
	private static void shouldFilterMocksWithGreaterThan()
	{
		List<Foobar__c> mocks = new List<Foobar__c>
		{
				(Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
						.withOverride(Foobar__c.NumberInteger__c, 5)
						.withoutInsertion(true).build(),
				(Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
						.withOverride(Foobar__c.NumberInteger__c, 15)
						.withoutInsertion(true).build(),
				(Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
						.withOverride(Foobar__c.NumberInteger__c, 25)
						.withoutInsertion(true).build()
		};

		QRY_Engine.setMock(Foobar__c.SObjectType, mocks);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;
		parameters.whereCondition = new QRY_Condition.FieldCondition(FIELD_INTEGER, QRY_Condition.Operator.GREATER_THAN, 10);

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(2, result.records.size(), 'Should return only records > 10');
	}

	/**
	 * @description Tests that mock filtering is applied before LIMIT.
	 */
	@IsTest
	private static void shouldFilterMocksBeforeLimit()
	{
		List<Foobar__c> mocks = newIntegerMocks(new List<Integer> {10, 20, 10, 10});

		QRY_Engine.setMock(Foobar__c.SObjectType, mocks);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;
		parameters.whereCondition = new QRY_Condition.FieldCondition(FIELD_INTEGER, QRY_Condition.Operator.EQUALS, 10);
		parameters.limitCount = 2;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(2, result.records.size(), 'Should limit after filtering');
		Assert.areEqual(3, result.totalRecords, 'Total should reflect filtered count before limit');
	}

	/**
	 * @description Tests that mock filtering with pagination reflects filtered totalRecords.
	 */
	@IsTest
	private static void shouldFilterMocksWithPagination()
	{
		List<Foobar__c> mocks = newIntegerMocks(new List<Integer> {10, 20, 10, 10});

		QRY_Engine.setMock(Foobar__c.SObjectType, mocks);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;
		parameters.whereCondition = new QRY_Condition.FieldCondition(FIELD_INTEGER, QRY_Condition.Operator.EQUALS, 10);
		parameters.pageSize = 2;
		parameters.pageNumber = 1;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(2, result.records.size(), 'Page 1 should have 2 records');
		Assert.areEqual(3, result.totalRecords, 'Total should reflect filtered count');
	}

	/**
	 * @description Tests that mocks are returned unfiltered when no conditions are provided.
	 */
	@IsTest
	private static void shouldReturnAllMocksWhenNoConditions()
	{
		List<Foobar__c> mocks = newIntegerMocks(new List<Integer> {10, 20});

		QRY_Engine.setMock(Foobar__c.SObjectType, mocks);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(2, result.records.size(), 'Should return all mocks when no conditions');
	}

	/**
	 * @description Tests that mocks are returned unfiltered for SObjectType without context class.
	 */
	@IsTest
	private static void shouldReturnAllMocksWhenNoContextClass()
	{
		List<Foobar__c> mocks = newIntegerMocks(new List<Integer> {10, 20});

		QRY_Engine.setMock(Foobar__c.SObjectType, mocks);
		QRY_Engine.registerMockContextClass(Foobar__c.SObjectType, null);

		UTIL_FormulaFilter.STANDARD_OBJECT_CONTEXT_TYPES.remove(Foobar__c.SObjectType);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;
		parameters.whereCondition = new QRY_Condition.FieldCondition(FIELD_INTEGER, QRY_Condition.Operator.EQUALS, 10);

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(2, result.records.size(), 'Should return all mocks when no context class');

		UTIL_FormulaFilter.STANDARD_OBJECT_CONTEXT_TYPES.put(Foobar__c.SObjectType, UTIL_FormulaContext.FoobarContext.class);
	}

	/**
	 * @description Tests that registerMockContextClass enables filtering for registered types.
	 */
	@IsTest
	private static void shouldFilterMocksWithRegisteredContextClass()
	{
		List<Foobar__c> mocks = newIntegerMocks(new List<Integer> {10, 20});

		QRY_Engine.registerMockContextClass(Foobar__c.SObjectType, UTIL_FormulaContext.FoobarContext.class.getName());
		QRY_Engine.setMock(Foobar__c.SObjectType, mocks);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;
		parameters.whereCondition = new QRY_Condition.FieldCondition(FIELD_INTEGER, QRY_Condition.Operator.EQUALS, 10);

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(1, result.records.size(), 'Should filter using registered context class');
	}

	/**
	 * @description Tests that clearMocks clears the context registry.
	 */
	@IsTest
	private static void shouldClearMockContextRegistry()
	{
		QRY_Engine.registerMockContextClass(Foobar__c.SObjectType, UTIL_FormulaContext.FoobarContext.class.getName());

		QRY_Engine.clearMocks();

		Assert.isTrue(QRY_Engine.mockContextRegistry.isEmpty(), 'Context registry should be cleared');
	}

	/**
	 * @description Tests that mocks are returned unfiltered when condition uses unsupported operator.
	 */
	@IsTest
	private static void shouldReturnAllMocksForUnsupportedCondition()
	{
		List<Foobar__c> mocks = newIntegerMocks(new List<Integer> {10, 20});

		QRY_Engine.setMock(Foobar__c.SObjectType, mocks);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;
		parameters.whereCondition = new QRY_Condition.FieldCondition('Lookup__r.Name', QRY_Condition.Operator.EQUALS, 'Test');

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(2, result.records.size(), 'Should return all mocks for unsupported condition');
	}

	/**
	 * @description Tests that registerMockContextClass throws for null SObjectType.
	 */
	@IsTest
	private static void shouldThrowWhenRegisteringNullObjectType()
	{
		try
		{
			QRY_Engine.registerMockContextClass(null, 'SomeContext');
			Assert.fail('Should throw IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests that mocks are sorted by a single field in ascending order.
	 */
	@IsTest
	private static void mocksSortedBySingleFieldAscending()
	{
		List<Foobar__c> mockRecords = newIntegerMocks(new List<Integer> {30, 10, 20});

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_INTEGER + ' FROM ' + OBJECT_NAME;
		parameters.orderByFields = new List<QRY_Generator.OrderBy>
		{
				new QRY_Generator.OrderBy(FIELD_INTEGER).ascending()
		};

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(3, result.records.size(), 'Should return all records');
		Assert.areEqual(10, result.records[0].get(FIELD_INTEGER), 'First should be lowest');
		Assert.areEqual(20, result.records[1].get(FIELD_INTEGER), 'Second should be middle');
		Assert.areEqual(30, result.records[2].get(FIELD_INTEGER), 'Third should be highest');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that mocks are sorted by a single field in descending order.
	 */
	@IsTest
	private static void mocksSortedBySingleFieldDescending()
	{
		List<Foobar__c> mockRecords = newIntegerMocks(new List<Integer> {10, 30, 20});

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_INTEGER + ' FROM ' + OBJECT_NAME;
		parameters.orderByFields = new List<QRY_Generator.OrderBy>
		{
				new QRY_Generator.OrderBy(FIELD_INTEGER).descending()
		};

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(3, result.records.size(), 'Should return all records');
		Assert.areEqual(30, result.records[0].get(FIELD_INTEGER), 'First should be highest');
		Assert.areEqual(20, result.records[1].get(FIELD_INTEGER), 'Second should be middle');
		Assert.areEqual(10, result.records[2].get(FIELD_INTEGER), 'Third should be lowest');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that mocks are sorted by multiple fields with mixed directions.
	 */
	@IsTest
	private static void mocksSortedByMultipleFields()
	{
		List<Foobar__c> mockRecords = newNamedIntegerMocks
				(
						new List<String> {'Alpha', 'Alpha', 'Beta'},
						new List<Integer> {20, 10, 5}
				);

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ', ' + FIELD_INTEGER + ' FROM ' + OBJECT_NAME;
		parameters.orderByFields = new List<QRY_Generator.OrderBy>
		{
				new QRY_Generator.OrderBy(FIELD_NAME).ascending(),
				new QRY_Generator.OrderBy(FIELD_INTEGER).descending()
		};

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(3, result.records.size(), 'Should return all records');
		Assert.areEqual('Alpha', result.records[0].get(FIELD_NAME), 'First should be Alpha');
		Assert.areEqual(20, result.records[0].get(FIELD_INTEGER), 'Alpha with higher integer first');
		Assert.areEqual('Alpha', result.records[1].get(FIELD_NAME), 'Second should be Alpha');
		Assert.areEqual(10, result.records[1].get(FIELD_INTEGER), 'Alpha with lower integer second');
		Assert.areEqual('Beta', result.records[2].get(FIELD_NAME), 'Third should be Beta');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that filterMocks returns all mocks when the formula filter throws an exception.
	 * Registers an invalid context class name to trigger the catch block.
	 *
	 * @see QRY_Engine.filterMocks
	 */
	@IsTest
	private static void shouldReturnAllMocksWhenFilterThrowsException()
	{
		List<Foobar__c> mocks = newIntegerMocks(new List<Integer> {10, 20});

		QRY_Engine.registerMockContextClass(Foobar__c.SObjectType, 'InvalidNonExistentContextClass');
		QRY_Engine.setMock(Foobar__c.SObjectType, mocks);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;
		parameters.whereCondition = new QRY_Condition.FieldCondition(FIELD_INTEGER, QRY_Condition.Operator.EQUALS, 10);

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(2, result.records.size(), 'Should return all mocks when filter throws exception');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that mocks remain in insertion order when no ORDER BY is specified.
	 */
	@IsTest
	private static void mocksUnsortedWhenNoOrderBy()
	{
		List<Foobar__c> mockRecords = newIntegerMocks(new List<Integer> {30, 10, 20});

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_INTEGER + ' FROM ' + OBJECT_NAME;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(3, result.records.size(), 'Should return all records');
		Assert.areEqual(30, result.records[0].get(FIELD_INTEGER), 'Should preserve insertion order');
		Assert.areEqual(10, result.records[1].get(FIELD_INTEGER), 'Should preserve insertion order');
		Assert.areEqual(20, result.records[2].get(FIELD_INTEGER), 'Should preserve insertion order');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that records equal on all sort fields preserve stable ordering.
	 */
	@IsTest
	private static void mocksSortedByMultipleFieldsWithEqualValues()
	{
		List<Foobar__c> mockRecords = newNamedIntegerMocks
				(
						new List<String> {'Alpha', 'Alpha'},
						new List<Integer> {10, 10}
				);

		QRY_Engine.setMock(Foobar__c.SObjectType, mockRecords);

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ', ' + FIELD_INTEGER + ' FROM ' + OBJECT_NAME;
		parameters.orderByFields = new List<QRY_Generator.OrderBy>
		{
				new QRY_Generator.OrderBy(FIELD_NAME).ascending(),
				new QRY_Generator.OrderBy(FIELD_INTEGER).ascending()
		};

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(2, result.records.size(), 'Should return both records');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests standard cursor pagination returns empty when offset exceeds total records.
	 */
	@IsTest
	private static void shouldReturnEmptyWhenStandardCursorOffsetExceedsTotal()
	{
		TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'Standard Cursor Test')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE ' + FIELD_NAME + ' = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => 'Standard Cursor Test'};
		parameters.cursorMode = QRY_Engine.CursorMode.STANDARD;
		parameters.pageSize = 10;
		parameters.offset = 100;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(0, result.records.size(), 'Should return empty when offset exceeds total');
		Assert.areEqual(1, result.totalRecords, 'Should still report correct total');
	}

	/**
	 * @description Creates mock Foobar__c records with specified NumberInteger__c values and mock IDs.
	 *
	 * @param integerValues The integer values to assign to each mock record
	 *
	 * @return List of mock Foobar__c records
	 */
	private static List<Foobar__c> newIntegerMocks(List<Integer> integerValues)
	{
		List<Foobar__c> mocks = new List<Foobar__c>();
		for(Integer integerValue : integerValues)
		{
			mocks.add((Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.NumberInteger__c, integerValue)
					.withoutInsertion(true).build());
		}
		return mocks;
	}

	/**
	 * @description Builds the parameters of an aggregate query that counts the rows of an object, with the count read
	 * through the alias `total`.
	 *
	 * @param objectType The object the query counts.
	 *
	 * @return Query parameters marked as an aggregate query.
	 */
	private static QRY_Engine.QueryParameters newAggregateParameters(SObjectType objectType)
	{
		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = objectType;
		parameters.queryString = 'SELECT COUNT(Id) ' + TOTAL_ALIAS + ' FROM ' + String.valueOf(objectType);
		parameters.aggregateQuery = true;
		return parameters;
	}

	/**
	 * @description Builds aggregate mock rows, one row for each total, each keyed by the alias `total`.
	 *
	 * @param totals The total of each row, in the order the rows are returned.
	 *
	 * @return One map for each total.
	 */
	private static List<Map<String, Object>> newAggregateRows(List<Integer> totals)
	{
		List<Map<String, Object>> rows = new List<Map<String, Object>>();
		for(Integer total : totals)
		{
			rows.add(new Map<String, Object> {TOTAL_ALIAS => total});
		}
		return rows;
	}

	/**
	 * @description Creates mock Foobar__c records with specified Name and NumberInteger__c values.
	 *
	 * @param names The name values to assign to each mock record
	 * @param integerValues The integer values to assign to each mock record
	 *
	 * @return List of mock Foobar__c records
	 */
	private static List<Foobar__c> newNamedIntegerMocks(List<String> names, List<Integer> integerValues)
	{
		List<Foobar__c> mocks = new List<Foobar__c>();
		for(Integer i = 0; i < names.size(); i++)
		{
			mocks.add((Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, names[i])
					.withOverride(Foobar__c.NumberInteger__c, integerValues[i])
					.withoutInsertion(true)
					.build());
		}
		return mocks;
	}

	/**
	 * @description Tests that a queued answer serves exactly one query, after which the standing registration
	 * answers again: the shape a test stages when one read must miss and the next must find the row.
	 */
	@IsTest
	private static void shouldServeAQueuedAnswerOnceThenTheStandingMocks()
	{
		List<SObject> standing = TST_Builder.of(Foobar__c.SObjectType).withCount(2).withoutInsertion(true).buildList();
		QRY_Engine.setMock(Foobar__c.SObjectType, standing);
		QRY_Engine.queueMock(Foobar__c.SObjectType, new List<SObject>());

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME;

		QRY_Engine.QueryResult first = QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult second = QRY_Engine.execute(parameters);

		Assert.isTrue(first.isMocked, 'A queued answer is served as a mock result');
		Assert.areEqual(0, first.records.size(), 'The queued empty answer serves the first query');
		Assert.areEqual(2, second.records.size(), 'The second query falls back to the standing registration');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that queued answers serve in registration order and that, with nothing registered
	 * behind them, the query after the last answer reads the database: a row stored for real is found.
	 */
	@IsTest
	private static void shouldServeQueuedAnswersInOrderThenReadTheDatabase()
	{
		Foobar__c stored = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, STORED_ROW_NAME).build();
		Foobar__c scripted = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, SCRIPTED_ROW_NAME).withoutInsertion(true).build();
		QRY_Engine.queueMock(Foobar__c.SObjectType, new List<SObject>());
		QRY_Engine.queueMock(Foobar__c.SObjectType, new List<SObject> {scripted});

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME;

		QRY_Engine.QueryResult first = QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult second = QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult third = QRY_Engine.execute(parameters);

		Assert.areEqual(0, first.records.size(), 'The first queued answer is the empty one');
		Assert.areEqual(scripted.Id, second.records[0].Id, 'The second queued answer is the scripted record');
		Assert.isFalse(third.isMocked, 'With the queue used up and nothing registered, the third query is real');
		Assert.areEqual(stored.Id, third.records[0].Id, 'The third query reads the row stored in the database');
	}

	/**
	 * @description Tests that a count query consumes a queued answer and returns its size, and that the next
	 * count reads the database.
	 */
	@IsTest
	private static void shouldServeAQueuedAnswerToACount()
	{
		QRY_Engine.queueMock(Foobar__c.SObjectType, TST_Builder.of(Foobar__c.SObjectType).withCount(3).withoutInsertion(true).buildList());

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT COUNT() FROM ' + OBJECT_NAME;

		Assert.areEqual(3, QRY_Engine.executeCount(parameters), 'A count consumes the queued answer and returns its size');
		Assert.areEqual(0, QRY_Engine.executeCount(parameters), 'The next count reads the database, which holds no rows');
	}

	/**
	 * @description Tests that a queued answer is limited like a standing registration.
	 */
	@IsTest
	private static void shouldLimitAQueuedAnswerLikeAStandingMock()
	{
		QRY_Engine.queueMock(Foobar__c.SObjectType, TST_Builder.of(Foobar__c.SObjectType).withCount(3).withoutInsertion(true).buildList());

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' LIMIT 2';
		parameters.limitCount = 2;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(2, result.records.size(), 'The limit applies to the queued answer');
		Assert.areEqual(3, result.totalRecords, 'The total reports the whole queued answer');
	}

	/**
	 * @description Tests that a queued answer is paged like a standing registration: a page beyond its size is empty.
	 */
	@IsTest
	private static void shouldPageAQueuedAnswerLikeAStandingMock()
	{
		QRY_Engine.queueMock(Foobar__c.SObjectType, TST_Builder.of(Foobar__c.SObjectType).withCount(3).withoutInsertion(true).buildList());

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME;
		parameters.pageSize = 2;
		parameters.pageNumber = 5;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.isTrue(result.isMocked, 'The page is served from the queued answer');
		Assert.isTrue(result.records.isEmpty(), 'A page beyond the queued answer is empty');
	}

	/**
	 * @description Tests that clearMocks drops queued answers beside the other registries, so the next query is real.
	 */
	@IsTest
	private static void shouldDropQueuedAnswersOnClearMocks()
	{
		QRY_Engine.queueMock(Foobar__c.SObjectType, TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).buildList());

		QRY_Engine.clearMocks();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;

		Assert.isFalse(QRY_Engine.execute(parameters).isMocked, 'clearMocks drops the queued answer, so the query is real');
	}

	/**
	 * @description Tests that clearMockQueue drops only the named type's queue.
	 */
	@IsTest
	private static void shouldDropOnlyThatTypesQueueOnClearMockQueue()
	{
		QRY_Engine.queueMock(Foobar__c.SObjectType, TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).buildList());
		QRY_Engine.queueMock(Account.SObjectType, TST_Builder.of(Account.SObjectType).withoutInsertion(true).buildList());

		QRY_Engine.clearMockQueue(Foobar__c.SObjectType);

		QRY_Engine.QueryParameters foobarParameters = new QRY_Engine.QueryParameters();
		foobarParameters.objectType = Foobar__c.SObjectType;
		foobarParameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;
		QRY_Engine.QueryParameters accountParameters = new QRY_Engine.QueryParameters();
		accountParameters.objectType = Account.SObjectType;
		accountParameters.queryString = 'SELECT Id FROM Account';

		Assert.isFalse(QRY_Engine.execute(foobarParameters).isMocked, 'The cleared type queries the database');
		Assert.isTrue(QRY_Engine.execute(accountParameters).isMocked, 'The other type keeps its queued answer');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that a null queued answer is refused with a message that points at the empty list.
	 */
	@IsTest
	private static void shouldRefuseANullQueuedAnswer()
	{
		try
		{
			QRY_Engine.queueMock(Foobar__c.SObjectType, null);
			Assert.fail('A null queued answer should be refused');
		}
		catch(IllegalArgumentException error)
		{
			Assert.isTrue(error.getMessage().contains(EMPTY_LIST_HINT), 'The refusal points at the empty list: ' + error.getMessage());
		}
	}

	/**
	 * @description Tests that a null SObjectType is refused when queueing an answer.
	 */
	@IsTest
	private static void shouldRefuseANullTypeForAQueuedAnswer()
	{
		try
		{
			QRY_Engine.queueMock(null, new List<SObject>());
			Assert.fail('A null SObjectType should be refused');
		}
		catch(IllegalArgumentException error)
		{
			Assert.isTrue(error.getMessage().contains(NULL_TYPE_HINT), 'The refusal names the SObjectType: ' + error.getMessage());
		}
	}

	/**
	 * @description Tests that a queued record of another type is refused by the existing mock validation.
	 */
	@IsTest
	private static void shouldRefuseAQueuedRecordOfAnotherType()
	{
		List<SObject> accounts = TST_Builder.of(Account.SObjectType).withoutInsertion(true).buildList();
		try
		{
			QRY_Engine.queueMock(Foobar__c.SObjectType, accounts);
			Assert.fail('A record of another type should be refused');
		}
		catch(IllegalArgumentException error)
		{
			Assert.isTrue(error.getMessage().contains(TYPE_MISMATCH_HINT), 'The refusal names the mismatch: ' + error.getMessage());
		}
	}

	/**
	 * @description Tests that an aggregate query is answered from the aggregate rows a test registered. The rows come
	 * back as they were registered, the result counts as mocked, and it holds no records.
	 */
	@IsTest
	private static void shouldAnswerAnAggregateQueryFromRegisteredAggregateRows()
	{
		QRY_Engine.setAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {FIRST_TOTAL, SECOND_TOTAL}));

		QRY_Engine.QueryResult result = QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));

		Assert.areEqual(TWO_ROWS, result.aggregateRows?.size(), 'Expected both registered aggregate rows to answer the query');
		Assert.isTrue(result.isMocked, 'Expected the result to count as mocked');
		Assert.isTrue(result.records.isEmpty(), 'Expected no records beside the aggregate rows');
		Assert.areEqual(TWO_ROWS, result.totalRecords, 'Expected the total to count the aggregate rows');
		Assert.areEqual(FIRST_TOTAL, result.aggregateRows?.get(0)?.get(TOTAL_ALIAS), 'Expected the first row to keep its value');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that queued aggregate rows answer exactly one aggregate query and are then used up, so the
	 * next queries get the standing aggregate rows, again and again.
	 */
	@IsTest
	private static void shouldServeTheNextAggregateAnswerOnceThenTheStandingRows()
	{
		QRY_Engine.queueAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {FIRST_TOTAL}));
		QRY_Engine.setAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {SECOND_TOTAL, THIRD_TOTAL}));

		QRY_Engine.QueryResult first = QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));
		QRY_Engine.QueryResult second = QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));
		QRY_Engine.QueryResult third = QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));

		Assert.areEqual(ONE_ROW, first.aggregateRows?.size(), 'Expected the queued answer to serve the first query');
		Assert.areEqual(FIRST_TOTAL, first.aggregateRows?.get(0)?.get(TOTAL_ALIAS), 'Expected the queued row in the first answer');
		Assert.areEqual(TWO_ROWS, second.aggregateRows?.size(), 'Expected the standing rows to serve the second query');
		Assert.areEqual(SECOND_TOTAL, second.aggregateRows?.get(0)?.get(TOTAL_ALIAS), 'Expected the standing rows in the second answer');
		Assert.areEqual(TWO_ROWS, third.aggregateRows?.size(), 'Expected the standing rows to serve the third query as well');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that the query's LIMIT cuts the registered aggregate rows down, keeping the first ones in the
	 * order they were registered, and that the total counts only the rows returned.
	 */
	@IsTest
	private static void shouldApplyTheLimitToAggregateRows()
	{
		QRY_Engine.setAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {FIRST_TOTAL, SECOND_TOTAL, THIRD_TOTAL}));
		QRY_Engine.QueryParameters parameters = newAggregateParameters(Foobar__c.SObjectType);
		parameters.limitCount = AGGREGATE_ROW_LIMIT;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(AGGREGATE_ROW_LIMIT, result.aggregateRows?.size(), 'Expected the limit to cut the aggregate rows');
		Assert.areEqual(AGGREGATE_ROW_LIMIT, result.totalRecords, 'Expected the total to count only the rows returned');
		Assert.areEqual(SECOND_TOTAL, result.aggregateRows?.get(1)?.get(TOTAL_ALIAS), 'Expected the rows kept in the order they were registered');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that record mocks never answer an aggregate query. With an empty record mock, a record mock
	 * with records, or only a queued record answer, the aggregate query throws an error that names
	 * TST_Mock.registerAggregateRows. The queued record answer is not used up: the next row query still gets it.
	 */
	@IsTest
	private static void shouldThrowWhenOnlyRecordMocksExistForAnAggregateQuery()
	{
		QRY_Engine.setMock(Foobar__c.SObjectType, new List<SObject>());
		assertAggregateQueryRefused('an empty record mock');
		QRY_Engine.clearMocks();

		QRY_Engine.setMock(Foobar__c.SObjectType, TST_Builder.of(Foobar__c.SObjectType).withCount(RECORD_MOCK_COUNT).withoutInsertion(true).buildList());
		assertAggregateQueryRefused('a record mock with records');
		QRY_Engine.clearMocks();

		List<SObject> queued = TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).buildList();
		QRY_Engine.queueMock(Foobar__c.SObjectType, queued);
		assertAggregateQueryRefused('a queued record answer');

		QRY_Engine.QueryParameters rowParameters = new QRY_Engine.QueryParameters();
		rowParameters.objectType = Foobar__c.SObjectType;
		rowParameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;
		QRY_Engine.QueryResult rowResult = QRY_Engine.execute(rowParameters);

		Assert.isTrue(rowResult.isMocked, 'Expected the row query to get the queued answer, which the aggregate query left in place');
		Assert.areEqual(queued[0].Id, rowResult.records[0].Id, 'Expected the queued record in the row query answer');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that an exception registered for aggregate queries wins over registered aggregate rows. Once
	 * the exception is cleared, the same rows answer, which proves they were registered all along.
	 */
	@IsTest
	private static void shouldThrowTheAggregateExceptionMockBeforeAggregateRows()
	{
		QRY_Engine.setMockAggregateException(Foobar__c.SObjectType, new QueryException(AGGREGATE_FAILURE_MESSAGE));
		QRY_Engine.setAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {FIRST_TOTAL}));

		try
		{
			QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));
			Assert.fail('Expected the registered aggregate exception to be thrown before the aggregate rows answer');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, QueryException.class, 'Expected the registered QueryException');
			Assert.areEqual(AGGREGATE_FAILURE_MESSAGE, error.getMessage(), 'Expected the exact registered exception');
		}

		QRY_Engine.clearMockException(Foobar__c.SObjectType);
		QRY_Engine.QueryResult result = QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));

		Assert.areEqual(ONE_ROW, result.aggregateRows?.size(), 'Expected the aggregate rows to answer once the exception is cleared');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that an aggregate query with no mock of any kind reads the database: the stored row is
	 * counted, and the result holds the real aggregate result row, not mocked rows.
	 */
	@IsTest
	private static void shouldReadTheDatabaseWhenNoMockOfAnyKindExistsForAnAggregateQuery()
	{
		TST_Factory.insertFoobar();

		QRY_Engine.QueryResult result = QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));

		Assert.isNull(result.aggregateRows, 'Expected no mocked aggregate rows');
		Assert.areEqual(ONE_ROW, result.records.size(), 'Expected the one real aggregate result row');
		Assert.isFalse(result.isMocked, 'Expected the database to answer');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that registered aggregate rows never answer a row query on the same object: the row query
	 * reads the stored row from the database. The row query also leaves queued aggregate rows in place, so the next
	 * aggregate query still gets them.
	 */
	@IsTest
	private static void shouldNotAnswerARowQueryFromAggregateRows()
	{
		Foobar__c stored = TST_Factory.insertFoobar();
		QRY_Engine.setAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {FIRST_TOTAL}));
		QRY_Engine.queueAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {SECOND_TOTAL}));

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;
		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.isNull(result.aggregateRows, 'Expected no aggregate rows on a row query');
		Assert.isFalse(result.isMocked, 'Expected the database to answer the row query');
		Assert.areEqual(stored.Id, result.records[0].Id, 'Expected the stored row');

		QRY_Engine.QueryResult aggregateResult = QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));

		Assert.areEqual(ONE_ROW, aggregateResult.aggregateRows?.size(), 'Expected the queued aggregate rows to answer the next aggregate query');
		Assert.areEqual(SECOND_TOTAL, aggregateResult.aggregateRows?.get(0)?.get(TOTAL_ALIAS), 'Expected the queued row, which the row query left in place');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that registered aggregate rows answer an aggregate query even when record mocks for the same
	 * object exist too: a list set with setMock and a queued record answer. The record mocks do not cause an error, and
	 * the queued record answer is not used up: the next row query still gets it.
	 */
	@IsTest
	private static void shouldAnswerAnAggregateQueryFromRowsWhenRecordMocksAlsoExist()
	{
		QRY_Engine.setMock(Foobar__c.SObjectType, TST_Builder.of(Foobar__c.SObjectType).withCount(RECORD_MOCK_COUNT).withoutInsertion(true).buildList());
		List<SObject> queued = TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).buildList();
		QRY_Engine.queueMock(Foobar__c.SObjectType, queued);
		QRY_Engine.setAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {FIRST_TOTAL}));

		QRY_Engine.QueryResult aggregateResult = QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));

		Assert.areEqual(ONE_ROW, aggregateResult.aggregateRows?.size(), 'Expected the aggregate rows to answer the aggregate query');
		Assert.areEqual(FIRST_TOTAL, aggregateResult.aggregateRows?.get(0)?.get(TOTAL_ALIAS), 'Expected the registered aggregate row');

		QRY_Engine.QueryParameters rowParameters = new QRY_Engine.QueryParameters();
		rowParameters.objectType = Foobar__c.SObjectType;
		rowParameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;
		QRY_Engine.QueryResult rowResult = QRY_Engine.execute(rowParameters);

		Assert.isTrue(rowResult.isMocked, 'Expected the row query to get a mocked answer');
		Assert.areEqual(queued[0].Id, rowResult.records[0].Id, 'Expected the queued record, which the aggregate query left in place');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that a queued aggregate answer wins over record mocks for the same object: a list set with
	 * setMock and a queued record answer. The aggregate query uses up the queued aggregate answer and leaves the record
	 * mocks as they were. The next row query gets the queued record answer, and the one after that gets the records set
	 * with setMock.
	 */
	@IsTest
	private static void shouldAnswerAnAggregateQueryFromAQueuedAnswerWhenRecordMocksAlsoExist()
	{
		List<SObject> standingRecords = TST_Builder.of(Foobar__c.SObjectType).withCount(RECORD_MOCK_COUNT).withoutInsertion(true).buildList();
		QRY_Engine.setMock(Foobar__c.SObjectType, standingRecords);
		List<SObject> queued = TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).buildList();
		QRY_Engine.queueMock(Foobar__c.SObjectType, queued);
		QRY_Engine.queueAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {FIRST_TOTAL}));

		QRY_Engine.QueryResult aggregateResult = QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));

		Assert.areEqual(ONE_ROW, aggregateResult.aggregateRows?.size(), 'Expected the queued aggregate answer to answer the aggregate query');
		Assert.areEqual(FIRST_TOTAL, aggregateResult.aggregateRows?.get(0)?.get(TOTAL_ALIAS), 'Expected the queued aggregate row');
		Assert.isFalse(QRY_Engine.hasAggregateMock(Foobar__c.SObjectType), 'Expected the queued aggregate answer to be used up');
		Assert.areEqual(standingRecords, QRY_Engine.getMock(Foobar__c.SObjectType), 'Expected the records set with setMock to be left as they were');

		QRY_Engine.QueryParameters rowParameters = new QRY_Engine.QueryParameters();
		rowParameters.objectType = Foobar__c.SObjectType;
		rowParameters.queryString = 'SELECT Id FROM ' + OBJECT_NAME;
		QRY_Engine.QueryResult firstRowResult = QRY_Engine.execute(rowParameters);
		QRY_Engine.QueryResult secondRowResult = QRY_Engine.execute(rowParameters);

		Set<Id> queuedIds = new Map<Id, SObject>(queued).keySet();
		Set<Id> standingIds = new Map<Id, SObject>(standingRecords).keySet();
		Assert.areEqual(queuedIds, new Map<Id, SObject>(firstRowResult.records).keySet(), 'Expected the queued record answer, which the aggregate query left in place');
		Assert.areEqual(standingIds, new Map<Id, SObject>(secondRowResult.records).keySet(), 'Expected the records set with setMock');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that each aggregate query answered from standing aggregate rows gets its own list. A test that
	 * adds a row to one result does not change the next result, or the rows that are registered.
	 */
	@IsTest
	private static void shouldReturnANewListOfAggregateRowsForEachQuery()
	{
		QRY_Engine.setAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {FIRST_TOTAL, SECOND_TOTAL}));

		QRY_Engine.QueryResult first = QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));
		first.aggregateRows.add(new Map<String, Object> {TOTAL_ALIAS => THIRD_TOTAL});
		QRY_Engine.QueryResult second = QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));

		Assert.areEqual(TWO_ROWS, second.aggregateRows?.size(), 'Expected the second result to hold only the two registered rows');
		Assert.areEqual(TWO_ROWS, second.totalRecords, 'Expected the second total to count only the two registered rows');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that addAggregateMock puts its rows after the rows set earlier for the object, so one aggregate
	 * query returns both sets, the first set first. The rows are kept in a new list: adding the rows leaves the list
	 * given to setAggregateMock as it was, and a row added later to either caller's list does not answer the query.
	 */
	@IsTest
	private static void shouldAddAggregateRowsAfterTheRowsSetEarlier()
	{
		List<Map<String, Object>> setRows = newAggregateRows(new List<Integer> {FIRST_TOTAL});
		List<Map<String, Object>> addedRows = newAggregateRows(new List<Integer> {SECOND_TOTAL});
		QRY_Engine.setAggregateMock(Foobar__c.SObjectType, setRows);

		QRY_Engine.addAggregateMock(Foobar__c.SObjectType, addedRows);

		Assert.areEqual(ONE_ROW, setRows.size(), 'Expected adding rows to leave the list given to setAggregateMock as it was');
		setRows.add(new Map<String, Object> {TOTAL_ALIAS => THIRD_TOTAL});
		addedRows.add(new Map<String, Object> {TOTAL_ALIAS => THIRD_TOTAL});
		QRY_Engine.QueryResult result = QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));
		Assert.areEqual(TWO_ROWS, result.aggregateRows?.size(), 'Expected the rows set first and the rows added, and no row added to a caller list later');
		Assert.areEqual(FIRST_TOTAL, result.aggregateRows?.get(0)?.get(TOTAL_ALIAS), 'Expected the rows set first to come first');
		Assert.areEqual(SECOND_TOTAL, result.aggregateRows?.get(1)?.get(TOTAL_ALIAS), 'Expected the added rows to come after them');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that addAggregateMock with an empty list, when no rows were set for the object, makes an
	 * aggregate query find nothing instead of reading the database, and that a later empty list adds no row.
	 */
	@IsTest
	private static void shouldAnswerWithNoRowsWhenAnEmptyListIsAddedFirst()
	{
		QRY_Engine.addAggregateMock(Foobar__c.SObjectType, new List<Map<String, Object>>());
		QRY_Engine.QueryResult emptyResult = QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));
		Assert.isNotNull(emptyResult.aggregateRows, 'Expected the empty list to answer the query instead of the database');
		Assert.isTrue(emptyResult.aggregateRows.isEmpty(), 'Expected the empty list to make the query find nothing');

		QRY_Engine.addAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {FIRST_TOTAL}));
		QRY_Engine.addAggregateMock(Foobar__c.SObjectType, new List<Map<String, Object>>());
		QRY_Engine.QueryResult result = QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));
		Assert.areEqual(ONE_ROW, result.aggregateRows?.size(), 'Expected a later empty list to add no row and remove none');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that addAggregateMock refuses a null object type, and refuses null rows with a message that
	 * points at the empty list.
	 */
	@IsTest
	private static void shouldRefuseNullArgumentsWhenAddingAggregateRows()
	{
		try
		{
			QRY_Engine.addAggregateMock(null, newAggregateRows(new List<Integer> {FIRST_TOTAL}));
			Assert.fail('Expected a null object type to be refused when adding aggregate rows');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException for a null object type');
			Assert.isTrue(error.getMessage().contains(NULL_TYPE_HINT), 'Expected the refusal to name the SObjectType: ' + error.getMessage());
		}
		try
		{
			QRY_Engine.addAggregateMock(Foobar__c.SObjectType, null);
			Assert.fail('Expected null rows to be refused when adding aggregate rows');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException for null rows');
			Assert.isTrue(error.getMessage().contains(EMPTY_LIST_HINT), 'Expected the refusal to point at the empty list: ' + error.getMessage());
		}
		Assert.isFalse(QRY_Engine.hasAggregateMock(Foobar__c.SObjectType), 'Expected a refused call to register no rows');
	}

	/**
	 * @description Tests every way of clearing aggregate rows: clearMocks, clearAggregateMocks, clearAggregateMock for
	 * one object and setAggregateMock with null rows. After each, an aggregate query reads the database. Rows
	 * registered for another object survive clearAggregateMock.
	 */
	@IsTest
	private static void shouldClearAggregateMocksThroughEveryClearPath()
	{
		QRY_Engine.setAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {FIRST_TOTAL}));
		QRY_Engine.queueAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {SECOND_TOTAL}));
		QRY_Engine.clearMocks();
		Assert.isNull(QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType)).aggregateRows, 'Expected clearMocks to clear the aggregate rows');

		QRY_Engine.setAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {FIRST_TOTAL}));
		QRY_Engine.queueAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {SECOND_TOTAL}));
		QRY_Engine.clearAggregateMocks();
		Assert.isNull(QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType)).aggregateRows, 'Expected clearAggregateMocks to clear the aggregate rows');

		QRY_Engine.setAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {FIRST_TOTAL}));
		QRY_Engine.queueAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {SECOND_TOTAL}));
		QRY_Engine.setAggregateMock(Account.SObjectType, newAggregateRows(new List<Integer> {THIRD_TOTAL}));
		QRY_Engine.clearAggregateMock(Foobar__c.SObjectType);
		Assert.isNull(QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType)).aggregateRows, 'Expected clearAggregateMock to clear that object');
		QRY_Engine.QueryResult otherObject = QRY_Engine.execute(newAggregateParameters(Account.SObjectType));
		Assert.areEqual(THIRD_TOTAL, otherObject.aggregateRows?.get(0)?.get(TOTAL_ALIAS), 'Expected the other object to keep its aggregate rows');

		QRY_Engine.setAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {FIRST_TOTAL}));
		QRY_Engine.setAggregateMock(Foobar__c.SObjectType, null);
		Assert.isNull(QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType)).aggregateRows, 'Expected null rows to clear the standing rows');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Tests that the aggregate mock setters refuse a null object type, and that queueing refuses null
	 * rows with a message that points at the empty list.
	 */
	@IsTest
	private static void shouldRefuseNullArgumentsOnTheAggregateMockSetters()
	{
		try
		{
			QRY_Engine.setAggregateMock(null, newAggregateRows(new List<Integer> {FIRST_TOTAL}));
			Assert.fail('Expected a null object type to be refused when setting aggregate rows');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException for a null object type');
			Assert.isTrue(error.getMessage().contains(NULL_TYPE_HINT), 'Expected the refusal to name the SObjectType: ' + error.getMessage());
		}

		assertQueueAggregateMockRefused(null, newAggregateRows(new List<Integer> {FIRST_TOTAL}), NULL_TYPE_HINT);
		assertQueueAggregateMockRefused(Foobar__c.SObjectType, null, EMPTY_LIST_HINT);
	}

	/**
	 * @description Tests that hasAggregateMock says whether aggregate rows will answer an aggregate query on an object:
	 * false with none, true with standing rows, true with only a queued answer, and false again once cleared. Looking
	 * does not use up the queued answer: the next aggregate query still gets it.
	 */
	@IsTest
	private static void shouldReportWhetherAnAggregateMockIsRegistered()
	{
		Assert.isFalse(QRY_Engine.hasAggregateMock(Foobar__c.SObjectType), 'Expected no aggregate mock before any is registered');

		QRY_Engine.setAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {FIRST_TOTAL}));
		Assert.isTrue(QRY_Engine.hasAggregateMock(Foobar__c.SObjectType), 'Expected standing aggregate rows to count as an aggregate mock');
		QRY_Engine.clearAggregateMocks();

		QRY_Engine.queueAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {SECOND_TOTAL}));
		Assert.isTrue(QRY_Engine.hasAggregateMock(Foobar__c.SObjectType), 'Expected a queued aggregate answer to count as an aggregate mock');
		QRY_Engine.QueryResult result = QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));
		Assert.areEqual(SECOND_TOTAL, result.aggregateRows?.get(0)?.get(TOTAL_ALIAS), 'Expected the queued answer to be left in place by the check');

		QRY_Engine.setAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {FIRST_TOTAL}));
		QRY_Engine.queueAggregateMock(Foobar__c.SObjectType, newAggregateRows(new List<Integer> {SECOND_TOTAL}));
		QRY_Engine.clearAggregateMock(Foobar__c.SObjectType);
		Assert.isFalse(QRY_Engine.hasAggregateMock(Foobar__c.SObjectType), 'Expected no aggregate mock once cleared');

		QRY_Engine.clearMocks();
	}

	/**
	 * @description Runs an aggregate query on Foobar__c and checks that it is refused because only record mocks exist.
	 * The error must be an IllegalStateException, and its message must name TST_Mock.registerAggregateRows, so the
	 * developer knows how to fix the test.
	 *
	 * @param scenario Words that say which record mock the test registered, used in the assert messages.
	 */
	private static void assertAggregateQueryRefused(String scenario)
	{
		try
		{
			QRY_Engine.execute(newAggregateParameters(Foobar__c.SObjectType));
			Assert.fail('Expected ' + scenario + ' to refuse the aggregate query');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Expected an IllegalStateException for ' + scenario);
			Assert.isTrue(error.getMessage().contains(REGISTER_AGGREGATE_ROWS_HINT), 'Expected the message to name the fix: ' + error.getMessage());
		}
	}

	/**
	 * @description Queues aggregate rows with a null argument and checks that the call is refused with an
	 * IllegalArgumentException whose message carries the given text.
	 *
	 * @param objectType The object to queue the rows for, or null to test a missing object type.
	 * @param rows The rows to queue, or null to test missing rows.
	 * @param expectedHint The text the refusal message must carry.
	 */
	private static void assertQueueAggregateMockRefused(SObjectType objectType, List<Map<String, Object>> rows, String expectedHint)
	{
		try
		{
			QRY_Engine.queueAggregateMock(objectType, rows);
			String nullArgument = objectType == null ? 'a null object type' : 'null rows';
			Assert.fail('Expected queueing aggregate rows with ' + nullArgument + ' to be refused');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException for a null argument in the queue');
			Assert.isTrue(error.getMessage().contains(expectedHint), 'Expected the refusal to carry the text ' + expectedHint + ': ' + error.getMessage());
		}
	}

	/**
	 * @description A miss stores a copy and a hit returns a fresh copy, so no caller's edits reach another.
	 */
	@IsTest
	private static void memoryCacheIsolatesEveryCaller()
	{
		List<Foobar__c> firstCallerRows = TST_Factory.insertFoobars(2);
		String key = UTIL_Random.randomAlphanumeric(MEMORY_CACHE_KEY_LENGTH);

		QRY_Engine.storeCopyInMemoryCache(key, firstCallerRows, QRY_Engine.CacheStatus.MEMORY_STORED);
		String original = firstCallerRows[0].Name;
		firstCallerRows[0].Name = UTIL_Random.randomAlphanumeric(MEMORY_CACHE_VALUE_LENGTH);
		List<SObject> firstHit = QRY_Engine.getCopyFromMemoryCache(key).records;
		firstHit[0].put(FIELD_NAME, UTIL_Random.randomAlphanumeric(MEMORY_CACHE_VALUE_LENGTH));
		List<SObject> secondHit = QRY_Engine.getCopyFromMemoryCache(key).records;

		Assert.areEqual(original, secondHit[0].get(FIELD_NAME), 'Neither the first caller nor the first hit may change what is stored');
		Assert.isTrue(firstHit !== secondHit, 'Each hit should be a distinct list object');
		Assert.isTrue(QRY_Engine.getCopyFromMemoryCache(key).isCached, 'A memory hit should be marked cached');
	}

	/**
	 * @description A child subquery is found wherever it came from: the text a builder subselect generates, a raw
	 * subquery string with or without inner spaces, a nested grandchild subquery, and a child subquery whose own
	 * filter holds a semi-join. Such a query is never kept in memory, because copying its rows shares the child records.
	 */
	@IsTest
	private static void containsChildSubqueryFindsChildSubqueries()
	{
		String builderSubselect = QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name})
				.subselect(QRY_Builder.selectFrom(Contact.SObjectType).fields(new List<SObjectField> {Contact.LastName}), CONTACTS_RELATIONSHIP)
				.toSoql();

		Assert.isTrue(QRY_Engine.containsChildSubquery(QRY_Engine.normalizeQuery(builderSubselect)), 'A builder subselect should be found');
		Assert.isTrue(QRY_Engine.containsChildSubquery(QRY_Engine.normalizeQuery('SELECT Id, (SELECT Id FROM Contacts) FROM Account')),
				'A raw child subquery should be found');
		Assert.isTrue(QRY_Engine.containsChildSubquery(QRY_Engine.normalizeQuery('SELECT Id, ( SELECT Id FROM Contacts ) FROM Account')),
				'A raw child subquery with inner spaces should be found');
		Assert.isTrue(QRY_Engine.containsChildSubquery(QRY_Engine.normalizeQuery('SELECT Id, (SELECT Id, (SELECT Id FROM Cases) FROM Contacts) FROM Account')),
				'A nested grandchild subquery should be found');
		Assert.isTrue(QRY_Engine.containsChildSubquery(
				QRY_Engine.normalizeQuery('SELECT Id, (SELECT Id FROM Contacts WHERE Id IN (SELECT ContactId FROM Cases)) FROM Account')),
				'A child subquery whose filter holds a semi-join should be found');
		Assert.isTrue(QRY_Engine.containsChildSubquery(
				QRY_Engine.normalizeQuery('SELECT Id, (SELECT Id FROM Contacts WHERE LastName = \'O\\\'Brien\') FROM Account')),
				'A child subquery whose filter holds a quoted literal should be found');
	}

	/**
	 * @description Parentheses that do not open a child subquery are not mistaken for one: semi-joins in a filter
	 * (with or without a space after IN), a TYPEOF field, function calls, a field whose name starts with SELECT, a
	 * quoted literal that holds one, with or without an escaped quote in it, and no query at all. Such reads stay eligible for the memory cache.
	 */
	@IsTest
	private static void containsChildSubqueryIgnoresOtherParentheses()
	{
		Assert.isFalse(QRY_Engine.containsChildSubquery(QRY_Engine.normalizeQuery('SELECT Id FROM Account WHERE Id IN (SELECT AccountId FROM Contact)')),
				'A semi-join should not count');
		Assert.isFalse(QRY_Engine.containsChildSubquery(QRY_Engine.normalizeQuery('SELECT Id FROM Account WHERE Id NOT IN (SELECT AccountId FROM Contact)')),
				'An anti-join should not count');
		Assert.isFalse(QRY_Engine.containsChildSubquery(QRY_Engine.normalizeQuery('SELECT Id FROM Account WHERE Id IN(SELECT AccountId FROM Contact)')),
				'A semi-join with no space after IN should not count');
		Assert.isFalse(QRY_Engine.containsChildSubquery(QRY_Engine.normalizeQuery('SELECT TYPEOF What WHEN Account THEN Name END FROM Event')),
				'A TYPEOF field should not count');
		Assert.isFalse(QRY_Engine.containsChildSubquery(QRY_Engine.normalizeQuery('SELECT TOLABEL(Picklist__c), FORMAT(Selected__c) FROM Foobar__c')),
				'Function calls, one on a field whose name starts with SELECT, should not count');
		Assert.isFalse(QRY_Engine.containsChildSubquery(QRY_Engine.normalizeQuery('SELECT Selected__c FROM Foobar__c')),
				'A field whose name starts with SELECT should not count');
		Assert.isFalse(QRY_Engine.containsChildSubquery(QRY_Engine.normalizeQuery('SELECT Id FROM Account WHERE Name = \'(SELECT X\'')),
				'A quoted literal holding (SELECT should not count');
		Assert.isFalse(QRY_Engine.containsChildSubquery(QRY_Engine.normalizeQuery('SELECT Id FROM Account WHERE Name = \'It\\\'s (SELECT X\'')),
				'A quoted literal with an escaped quote before (SELECT should not count');
		Assert.isFalse(QRY_Engine.containsChildSubquery(null), 'No query should not count');
	}

	/**
	 * @description A memory hit carries only the fields the query selected: reading a field the query did not select
	 * throws on the hit exactly as it does on the queried row, so a cached read never hides a missing field.
	 */
	@IsTest
	private static void memoryCacheHitKeepsTheQueriedFields()
	{
		Foobar__c inserted = TST_Factory.insertFoobars(1)[0];
		List<Foobar__c> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
				.fields(new List<SObjectField> {Foobar__c.Name})
				.condition(Foobar__c.Id).equals(inserted.Id)
				.withoutSecurity()
				.toList();
		String key = UTIL_Random.randomAlphanumeric(MEMORY_CACHE_KEY_LENGTH);

		QRY_Engine.storeCopyInMemoryCache(key, rows, QRY_Engine.CacheStatus.MEMORY_STORED);
		SObject hitRow = QRY_Engine.getCopyFromMemoryCache(key).records[0];

		Assert.areEqual(rows[0].Name, hitRow.get(FIELD_NAME), 'The hit should carry the selected field');
		try
		{
			rows[0].get(Foobar__c.NumberInteger__c);
			Assert.fail('Reading a field the query did not select should throw on the queried row');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, SObjectException.class, 'Incorrect Exception Type');
		}
		try
		{
			hitRow.get(Foobar__c.NumberInteger__c);
			Assert.fail('Reading a field the query did not select should throw on the memory hit');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, SObjectException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description A result over the row cap is declined and not stored.
	 */
	@IsTest
	private static void memoryCacheDeclinesOverRowCap()
	{
		List<SObject> rows = TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, UTIL_Random.randomAlphanumeric(MEMORY_CACHE_VALUE_LENGTH))
				.withCount(QRY_Engine.MEMORY_CACHE_ROW_LIMIT + 1)
				.withoutInsertion()
				.buildList();
		String key = UTIL_Random.randomAlphanumeric(MEMORY_CACHE_KEY_LENGTH);

		QRY_Engine.CacheStatus status = QRY_Engine.storeCopyInMemoryCache(key, rows, QRY_Engine.CacheStatus.MEMORY_STORED);

		Assert.areEqual(QRY_Engine.CacheStatus.DECLINED_ROW_CAP, status, 'A result over the cap should be declined');
		Assert.isNull(QRY_Engine.getCopyFromMemoryCache(key), 'A declined result should not be stored');
	}

	/**
	 * @description A store the heap guard refuses is reported as declined. The test fills the heap with
	 * 100,000-character strings until the guard is reached, so it calibrates itself against the live limit.
	 */
	@IsTest
	private static void memoryCacheReportsHeapGuardDecline()
	{
		SObject row = TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, UTIL_Random.randomAlphanumeric(MEMORY_CACHE_VALUE_LENGTH)).withoutInsertion().build();
		List<String> ballast = new List<String>();
		while(!UTIL_Limits.heapSize().isNearLimit(UTIL_Cache.MEMORY_CACHE_EVICTION_HEAP_SHARE))
		{
			ballast.add('x'.repeat(LARGE_VALUE_LENGTH));
		}
		String key = UTIL_Random.randomAlphanumeric(MEMORY_CACHE_KEY_LENGTH);

		QRY_Engine.CacheStatus status = QRY_Engine.storeCopyInMemoryCache(key, new List<SObject> {row}, QRY_Engine.CacheStatus.MEMORY_STORED);

		Assert.areEqual(QRY_Engine.CacheStatus.DECLINED_HEAP_GUARD, status, 'A refused store should report the heap guard');
		Assert.isNotNull(ballast, 'Keep the ballast alive until after the store');
	}

	/**
	 * @description clearQueryResultMemoryCache empties the engine's cache.
	 */
	@IsTest
	private static void clearQueryResultMemoryCacheEmptiesTheCache()
	{
		String key = UTIL_Random.randomAlphanumeric(MEMORY_CACHE_KEY_LENGTH);
		List<SObject> rows = TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, UTIL_Random.randomAlphanumeric(MEMORY_CACHE_VALUE_LENGTH))
				.withoutInsertion()
				.buildList();
		QRY_Engine.storeCopyInMemoryCache(key, rows, QRY_Engine.CacheStatus.MEMORY_STORED);

		QRY_Engine.clearQueryResultMemoryCache();

		Assert.isNull(QRY_Engine.getCopyFromMemoryCache(key), 'The cache should be empty after a clear');
	}

	/**
	 * @description A user-mode cached read is kept in memory for the transaction: the first read is stored as a
	 * user-mode result, and a repeat runs no query, reports itself cached and is served from memory.
	 */
	@IsTest
	private static void userModeReadIsCachedInMemory()
	{
		Foobar__c row = TST_Factory.insertFoobar();
		QRY_Builder.Builder query = buildFoobarRead(row.Name).withUserMode().withCache(CACHE_TIME_TO_LIVE_SECONDS);

		QRY_Engine.QueryResult miss = executeThroughEngine(query);
		Integer hitQueries = countQueriesOf(query);
		Boolean hitReportedCached = query.isCached();
		QRY_Engine.QueryResult hit = executeThroughEngine(query);

		Assert.areEqual(QRY_Engine.CacheStatus.MEMORY_STORED_USER_MODE, miss.cacheStatus, 'The first read should be stored in memory as a user-mode result');
		Assert.areEqual(0, hitQueries, 'A repeat of a user-mode cached read should run no query');
		Assert.isTrue(hitReportedCached, 'The builder should report the repeat as cached');
		Assert.areEqual(QRY_Engine.CacheStatus.MEMORY_HIT, hit.cacheStatus, 'A repeat should be served from memory');
		Assert.areEqual(row.Id, hit.records[0].Id, 'The hit should carry the stored row');
	}

	/**
	 * @description A user-mode read never reaches Platform Cache, even when it names the org scope: nothing is stored
	 * under the key a system-mode read of the same query would use, with sharing enforced or bypassed.
	 */
	@IsTest
	private static void userModeReadNeverReachesPlatformCache()
	{
		Foobar__c row = TST_Factory.insertFoobar();
		QRY_Builder.Builder query = buildFoobarRead(row.Name).withUserMode().withCache(UTIL_Cache.Scope.ORG, CACHE_TIME_TO_LIVE_SECONDS);

		QRY_Engine.QueryResult result = executeThroughEngine(query);
		QRY_Engine.QueryParameters parameters = query.buildParameters(new QRY_BindRegistry());
		parameters.enforceSharing = true;
		String enforcedKey = QRY_Engine.generateCacheKey(parameters);
		parameters.enforceSharing = false;
		String bypassedKey = QRY_Engine.generateCacheKey(parameters);

		Assert.areEqual(QRY_Engine.CacheStatus.MEMORY_STORED_USER_MODE, result.cacheStatus, 'A user-mode read should be kept in memory only');
		Assert.isNull(UTIL_Cache.org().get(enforcedKey), 'A user-mode result must never be stored in Platform Cache');
		Assert.isNull(UTIL_Cache.org().get(bypassedKey), 'A user-mode result must never be stored in Platform Cache under a bypassed key');
	}

	/**
	 * @description A system-mode read that leaves its sharing to the calling class is never cached, even in memory:
	 * the engine cannot see that sharing when it builds the key. Stating the sharing makes the same read cacheable.
	 */
	@IsTest
	private static void systemModeInheritedSharingIsDeclined()
	{
		Foobar__c row = TST_Factory.insertFoobar();
		QRY_Builder.Builder inherited = buildFoobarRead(row.Name).withSystemMode().withCache(UTIL_Cache.Scope.IN_TRANSACTION, null);
		QRY_Builder.Builder bypassed = buildFoobarRead(row.Name).withSystemMode().bypassSharing().withCache(UTIL_Cache.Scope.IN_TRANSACTION, null);

		QRY_Engine.QueryResult firstInherited = executeThroughEngine(inherited);
		Integer secondInheritedQueries = countQueriesOf(inherited);
		executeThroughEngine(bypassed);
		Integer secondBypassedQueries = countQueriesOf(bypassed);

		Assert.areEqual(QRY_Engine.CacheStatus.DECLINED_INHERITED_SHARING, firstInherited.cacheStatus, 'An inherited-sharing system-mode read should be declined');
		Assert.areEqual(1, secondInheritedQueries, 'A repeat of an inherited-sharing system-mode read should run its query again');
		Assert.areEqual(0, secondBypassedQueries, 'A repeat of the same read with sharing bypassed should be served from memory');
	}

	/**
	 * @description A result read in system mode is never served to a user-mode read of the same query by the same
	 * user. Both reads key as sharing enforced, so only the access mode in the in-memory key tells them apart.
	 */
	@IsTest
	private static void inMemoryKeySeparatesAccessModes()
	{
		Foobar__c row = TST_Factory.insertFoobar();
		QRY_Builder.Builder systemModeRead = buildFoobarRead(row.Name).withSystemMode().withSharing().withCache(UTIL_Cache.Scope.IN_TRANSACTION, null);
		QRY_Builder.Builder userModeRead = buildFoobarRead(row.Name).withUserMode().withCache(UTIL_Cache.Scope.IN_TRANSACTION, null);

		systemModeRead.toList();
		Integer userModeQueries = countQueriesOf(userModeRead);

		Assert.areEqual(1, userModeQueries, 'A user-mode read must run its own query, never take the system-mode result');
	}

	/**
	 * @description A system-mode read that asks for the session scope, in a transaction with no session partition,
	 * is kept in memory and reported as such, and nothing reaches the org partition. Where the precondition does not
	 * hold (a session partition exists, or no org partition exists to prove the negative against), the test returns.
	 */
	@IsTest
	private static void explicitSessionWithoutSessionPartitionGoesToMemory()
	{
		if(UTIL_Cache.isSessionAllocated() || !UTIL_Cache.isOrgAllocated())
		{
			return;
		}
		Foobar__c row = TST_Factory.insertFoobar();
		QRY_Builder.Builder query = buildFoobarRead(row.Name).withSystemMode().bypassSharing().withCache(UTIL_Cache.Scope.SESSION, CACHE_TIME_TO_LIVE_SECONDS);

		QRY_Engine.QueryResult result = executeThroughEngine(query);
		String durableKey = QRY_Engine.generateCacheKey(query.buildParameters(new QRY_BindRegistry()));

		Assert.areEqual(QRY_Engine.CacheStatus.MEMORY_STORED_NO_PARTITION, result.cacheStatus, 'With no session partition the read should be kept in memory');
		Assert.isNull(UTIL_Cache.org().get(durableKey), 'A session-scope read must not be stored in the org partition');
	}

	/**
	 * @description A system-mode read with sharing bypassed whose Platform Cache store is refused steps down to
	 * memory: it is reported as kept in memory for want of a partition, and the same read again runs no query and is
	 * served from memory.
	 */
	@IsTest
	private static void systemModeReadStepsDownToMemoryWhenPlatformCacheRefuses()
	{
		Foobar__c row = TST_Factory.insertFoobar();
		QRY_Builder.Builder query = buildFoobarRead(row.Name).withSystemMode().bypassSharing().withCache(CACHE_TIME_TO_LIVE_SECONDS);

		QRY_Engine.QueryResult miss;
		Integer hitQueries;
		QRY_Engine.QueryResult hit;
		UTIL_Cache.simulatePutException = true;
		try
		{
			miss = executeThroughEngine(query);
			hitQueries = countQueriesOf(query);
			hit = executeThroughEngine(query);
		}
		finally
		{
			UTIL_Cache.simulatePutException = false;
		}

		Assert.areEqual(QRY_Engine.CacheStatus.MEMORY_STORED_NO_PARTITION, miss.cacheStatus, 'A refused Platform Cache store should step down to memory');
		Assert.areEqual(0, hitQueries, 'The same read again should run no query');
		Assert.areEqual(QRY_Engine.CacheStatus.MEMORY_HIT, hit.cacheStatus, 'The same read again should be served from memory');
		Assert.areEqual(row.Id, hit.records[0].Id, 'The hit should carry the stored row');
	}

	/**
	 * @description An aggregate query is never kept in memory: a user-mode cached aggregate read runs its query every
	 * time and says why it was not cached.
	 */
	@IsTest
	private static void aggregateQueryIsNotStoredInMemory()
	{
		QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
				.count(Foobar__c.Id, TOTAL_ALIAS)
				.withUserMode()
				.withCache(CACHE_TIME_TO_LIVE_SECONDS);

		QRY_Engine.QueryResult first = executeThroughEngine(query);
		Integer queriesBefore = UTIL_Limits.soqlQueries().used();
		query.toAggregateList();
		Integer secondReadQueries = UTIL_Limits.soqlQueries().used() - queriesBefore;

		Assert.areEqual(QRY_Engine.CacheStatus.DECLINED_AGGREGATE, first.cacheStatus, 'An aggregate read should be declined in memory');
		Assert.areEqual(1, secondReadQueries, 'A repeat of an aggregate read should run its query again');
	}

	/**
	 * @description A query with a child subquery is never kept in memory, because copying its rows would share the
	 * child records between callers: a user-mode cached read with a builder subselect runs its query every time.
	 */
	@IsTest
	private static void childSubqueryIsNotStoredInMemory()
	{
		QRY_Builder.Builder query = buildAccountRead()
				.subselect(QRY_Builder.selectFrom(Contact.SObjectType).fields(new List<SObjectField> {Contact.LastName}), CONTACTS_RELATIONSHIP)
				.withUserMode()
				.withCache(CACHE_TIME_TO_LIVE_SECONDS);

		QRY_Engine.QueryResult first = executeThroughEngine(query);
		Integer secondReadQueries = countQueriesOf(query);

		Assert.areEqual(QRY_Engine.CacheStatus.DECLINED_CHILD_SUBQUERY, first.cacheStatus, 'A read with a child subquery should be declined in memory');
		Assert.areEqual(1, secondReadQueries, 'A repeat of a read with a child subquery should run its query again');
	}

	/**
	 * @description A child subquery added as a raw field string is found in the query text and declined like a
	 * builder subselect, so a check of the builder's own subselects alone would not be enough.
	 */
	@IsTest
	private static void rawStringChildSubqueryIsNotStoredInMemory()
	{
		QRY_Builder.Builder query = buildAccountRead()
				.addField('(SELECT LastName FROM ' + CONTACTS_RELATIONSHIP + ')')
				.withUserMode()
				.withCache(CACHE_TIME_TO_LIVE_SECONDS);

		QRY_Engine.QueryResult first = executeThroughEngine(query);
		Integer secondReadQueries = countQueriesOf(query);

		Assert.areEqual(QRY_Engine.CacheStatus.DECLINED_CHILD_SUBQUERY, first.cacheStatus, 'A raw-string child subquery should be declined in memory');
		Assert.areEqual(1, secondReadQueries, 'A repeat of a read with a raw-string child subquery should run its query again');
	}

	/**
	 * @description A semi-join is a filter, not a child subquery, so a user-mode cached read filtered by one is kept
	 * in memory: its repeat runs no query.
	 */
	@IsTest
	private static void semiJoinReadIsStoredInMemory()
	{
		QRY_Builder.Builder query = buildAccountRead()
				.condition(Account.Id).isIn(QRY_Builder.selectFrom(Contact.SObjectType).fields(new List<SObjectField> {Contact.AccountId}))
				.withUserMode()
				.withCache(CACHE_TIME_TO_LIVE_SECONDS);

		query.toList();
		Integer secondReadQueries = countQueriesOf(query);

		Assert.areEqual(0, secondReadQueries, 'A repeat of a semi-join read should be served from memory');
	}

	/**
	 * @description The memory-only decline of child subqueries leaves Platform Cache alone: a system-mode read with
	 * sharing bypassed and a subselect is still stored in the org partition. Where no org partition exists the test
	 * returns.
	 */
	@IsTest
	private static void durableChildSubqueryReadIsStillStored()
	{
		if(!UTIL_Cache.isOrgAllocated())
		{
			return;
		}
		QRY_Builder.Builder query = buildAccountRead()
				.subselect(QRY_Builder.selectFrom(Contact.SObjectType).fields(new List<SObjectField> {Contact.LastName}), CONTACTS_RELATIONSHIP)
				.withSystemMode()
				.bypassSharing()
				.withCache(UTIL_Cache.Scope.ORG, CACHE_TIME_TO_LIVE_SECONDS);

		QRY_Engine.QueryResult result = executeThroughEngine(query);

		Assert.areEqual(QRY_Engine.CacheStatus.STORED, result.cacheStatus, 'A system-mode read with a child subquery should still be kept in Platform Cache');
	}

	/**
	 * @description Checks that every Platform Cache hit is a fresh copy. The Platform Cache store serializes a value
	 * when it keeps it and rebuilds it on every read, so no caller sees another's unsaved edits, child records
	 * included: an edit to the rows a miss returned reaches no hit, two hits share no list, record or child record,
	 * and an edit to one hit's row or child leaves the other's alone. The test fails if a change to the store stops
	 * copying. The rows are Foobar__c records, a parent and a child linked by its lookup to another Foobar__c, because
	 * a package test never saves a standard object: an org's own rules on a standard object could refuse the save.
	 * Where no org partition exists the test returns.
	 */
	@IsTest
	private static void durableHitIsolatesEveryCaller()
	{
		if(!UTIL_Cache.isOrgAllocated())
		{
			return;
		}
		Foobar__c parent = TST_Factory.insertFoobar();
		Foobar__c child = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, UTIL_Random.randomName())
				.withOverride(Foobar__c.Lookup__c, parent.Id)
				.build();
		QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
				.fields(new List<SObjectField> {Foobar__c.Name})
				.subselect(QRY_Builder.selectFrom(Foobar__c.SObjectType).fields(new List<SObjectField> {Foobar__c.Name}), SEL_Foobar.RELATIONSHIP_FOOBARS)
				.condition(Foobar__c.Id).equals(parent.Id)
				.withSystemMode()
				.bypassSharing()
				.withCache(UTIL_Cache.Scope.ORG, CACHE_TIME_TO_LIVE_SECONDS);

		QRY_Engine.QueryResult miss = executeThroughEngine(query);
		miss.records[0].put(Foobar__c.Name, UTIL_Random.randomName());
		miss.records[0].getSObjects(SEL_Foobar.RELATIONSHIP_FOOBARS)[0].put(Foobar__c.Name, UTIL_Random.randomName());
		QRY_Engine.QueryResult firstHit = executeThroughEngine(query);
		QRY_Engine.QueryResult secondHit = executeThroughEngine(query);
		SObject firstHitChild = firstHit.records[0].getSObjects(SEL_Foobar.RELATIONSHIP_FOOBARS)[0];
		SObject secondHitChild = secondHit.records[0].getSObjects(SEL_Foobar.RELATIONSHIP_FOOBARS)[0];
		Object firstHitName = firstHit.records[0].get(Foobar__c.Name);
		Object firstHitChildName = firstHitChild.get(Foobar__c.Name);
		firstHit.records[0].put(Foobar__c.Name, UTIL_Random.randomName());
		firstHitChild.put(Foobar__c.Name, UTIL_Random.randomName());

		Assert.areEqual(QRY_Engine.CacheStatus.STORED, miss.cacheStatus, 'The first read should be kept in Platform Cache');
		Assert.areEqual(QRY_Engine.CacheStatus.HIT, firstHit.cacheStatus, 'The second read should be a Platform Cache hit');
		Assert.areEqual(QRY_Engine.CacheStatus.HIT, secondHit.cacheStatus, 'The third read should be a Platform Cache hit');
		Assert.areEqual(parent.Name, firstHitName, 'A hit should carry the stored name, not the unsaved edit made to the rows the miss returned');
		Assert.areEqual(child.Name, firstHitChildName, 'A hit\'s child should carry the stored name, not the unsaved edit made to the miss');
		Assert.areEqual(parent.Name, secondHit.records[0].get(Foobar__c.Name), 'A hit should carry the stored name, not another caller\'s unsaved edit');
		Assert.areEqual(child.Name, secondHitChild.get(Foobar__c.Name), 'A hit\'s child should carry the stored name, not another caller\'s edit');
		Assert.isTrue(firstHit.records !== secondHit.records, 'Two hits should not share a list');
		Assert.isTrue(firstHit.records[0] !== secondHit.records[0], 'Two hits should not share a record');
		Assert.isTrue(firstHitChild !== secondHitChild, 'Two hits should not share a child record');
	}

	/**
	 * @description The Platform Cache store for a scope is built once per transaction and reused: after two cached
	 * reads with different filters, the engine holds exactly one store, for the automatic scope.
	 */
	@IsTest
	private static void durableStoreProbesOncePerTransaction()
	{
		List<Foobar__c> rows = TST_Factory.insertFoobars(2);

		buildFoobarRead(rows[0].Name).withSystemMode().bypassSharing().withCache(CACHE_TIME_TO_LIVE_SECONDS).toList();
		buildFoobarRead(rows[1].Name).withSystemMode().bypassSharing().withCache(CACHE_TIME_TO_LIVE_SECONDS).toList();

		Assert.areEqual(1, QRY_Engine.DURABLE_STORE_BY_SCOPE.size(), 'One store should serve every read of a scope');
		Assert.isTrue(QRY_Engine.DURABLE_STORE_BY_SCOPE.containsKey(UTIL_Cache.Scope.AUTO), 'The store should be held for the automatic scope');
	}

	/**
	 * @description The Platform Cache key is byte-for-byte what it was before the in-memory cache existed, so entries
	 * already stored keep being found: a plain bypassed read is shared by every user, and a bypassed read with a
	 * date literal read in the user's time zone is kept per user.
	 */
	@IsTest
	private static void generateCacheKeyIsUnchanged()
	{
		QRY_Engine.QueryParameters plainRead = new QRY_Engine.QueryParameters();
		plainRead.queryString = 'SELECT Id FROM Account WHERE Name = :b1';
		plainRead.bindMap = new Map<String, Object> {'b1' => 'Cache key probe'};
		plainRead.enforceSharing = false;
		QRY_Engine.QueryParameters todayRead = new QRY_Engine.QueryParameters();
		todayRead.queryString = 'SELECT Id FROM Account WHERE LastActivityDate = TODAY';
		todayRead.enforceSharing = false;

		Assert.areEqual('QRY:SELECT ID FROM ACCOUNT WHERE NAME = :B1:{"b1":"Cache key probe"}:SHARING=BYPASSED', QRY_Engine.generateCacheKey(plainRead),
				'A plain bypassed read should keep its shared key');
		Assert.areEqual('QRY:SELECT ID FROM ACCOUNT WHERE LASTACTIVITYDATE = TODAY::SHARING=BYPASSED:USER=' + UserInfo.getUserId(),
				QRY_Engine.generateCacheKey(todayRead), 'A bypassed read that depends on the user should keep its per-user key');
	}

	/**
	 * @description A memory hit costs no more heap than running the query: serving 200 rows from memory grows the
	 * heap by no more than the same read without caching, plus a small margin for the result wrapper a hit allocates.
	 */
	@IsTest
	private static void hitUsesNoMoreHeapThanTheQuery()
	{
		String sharedName = UTIL_Random.randomAlphanumeric(MEMORY_CACHE_VALUE_LENGTH);
		TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, sharedName).withCount(QRY_Engine.MEMORY_CACHE_ROW_LIMIT).buildList();
		QRY_Builder.Builder uncachedRead = buildFoobarRead(sharedName).withUserMode().withoutCache();
		QRY_Builder.Builder cachedRead = buildFoobarRead(sharedName).withUserMode().withCache(CACHE_TIME_TO_LIVE_SECONDS);
		cachedRead.toList();

		Integer heapBefore = UTIL_Limits.heapSize().used();
		List<SObject> queriedRows = uncachedRead.toList();
		Integer queryGrowth = UTIL_Limits.heapSize().used() - heapBefore;
		heapBefore = UTIL_Limits.heapSize().used();
		List<SObject> hitRows = cachedRead.toList();
		Integer hitGrowth = UTIL_Limits.heapSize().used() - heapBefore;

		Assert.isTrue(cachedRead.isCached(), 'The measured cached read should be a memory hit');
		Assert.areEqual(queriedRows.size(), hitRows.size(), 'Both reads should return every row');
		Assert.isTrue(hitGrowth <= queryGrowth + HIT_HEAP_MARGIN_BYTES,
				'A memory hit grew the heap by ' + hitGrowth + ' bytes against ' + queryGrowth + ' for the query');
	}

	/**
	 * @description Read shapes that are never cached stay uncached when the transaction scope is requested: a row
	 * lock, ALL ROWS and random sampling each run their query again on a repeat.
	 */
	@IsTest
	private static void neverCachedShapesStayUncached()
	{
		Foobar__c row = TST_Factory.insertFoobar();
		QRY_Builder.Builder lockedRead = buildFoobarRead(row.Name).withUserMode().withCache(UTIL_Cache.Scope.IN_TRANSACTION, null).forUpdate();
		QRY_Builder.Builder allRowsRead = buildFoobarRead(row.Name).withUserMode().withCache(UTIL_Cache.Scope.IN_TRANSACTION, null).allRows();
		QRY_Builder.Builder randomRead = buildFoobarRead(row.Name).withUserMode().withCache(UTIL_Cache.Scope.IN_TRANSACTION, null);

		lockedRead.toList();
		Integer lockedRepeatQueries = countQueriesOf(lockedRead);
		allRowsRead.toList();
		Integer allRowsRepeatQueries = countQueriesOf(allRowsRead);
		Integer queriesBefore = UTIL_Limits.soqlQueries().used();
		randomRead.getRandomItem();
		Integer randomFirstQueries = UTIL_Limits.soqlQueries().used() - queriesBefore;
		queriesBefore = UTIL_Limits.soqlQueries().used();
		randomRead.getRandomItem();
		Integer randomRepeatQueries = UTIL_Limits.soqlQueries().used() - queriesBefore;

		Assert.areEqual(1, lockedRepeatQueries, 'A repeat of a FOR UPDATE read should run its query again');
		Assert.areEqual(1, allRowsRepeatQueries, 'A repeat of an ALL ROWS read should run its query again');
		Assert.isTrue(randomFirstQueries > 0, 'A random read should run a query');
		Assert.areEqual(randomFirstQueries, randomRepeatQueries, 'A repeat of a random read should run its queries again');
	}

	/**
	 * @description A write to any object empties the memory cache, because a write can change a cached read through
	 * roll-ups, formulas or triggers: after a builder inserts a log entry record, a repeat of a cached read of
	 * Foobar__c rows runs its query again. The written object is one the package owns, because a package test never
	 * saves a standard object: an org's own rules on a standard object could refuse the save.
	 */
	@IsTest
	private static void builderWriteToAnotherObjectEmptiesTheMemoryCache()
	{
		Foobar__c row = TST_Factory.insertFoobar();
		QRY_Builder.Builder query = buildFoobarRead(row.Name).withUserMode().withCache(CACHE_TIME_TO_LIVE_SECONDS);
		query.toList();
		Integer queriesBeforeTheWrite = countQueriesOf(query);

		DML_Builder.newTransaction().withSystemMode().doInsert(TST_Builder.of(LogEntry__c.SObjectType).withoutInsertion().build()).execute();
		Integer queriesAfterTheWrite = countQueriesOf(query);

		Assert.areEqual(0, queriesBeforeTheWrite, 'Before the write the repeat should be served from memory');
		Assert.areEqual(1, queriesAfterTheWrite, 'After a write to another object the repeat should run its query again');
	}

	/**
	 * @description A read after a builder update sees the new value: the cached read made before the update is not
	 * served after it.
	 */
	@IsTest
	private static void readAfterBuilderUpdateSeesNewValue()
	{
		Foobar__c row = TST_Factory.insertFoobar();
		QRY_Builder.Builder query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
				.fields(new List<SObjectField> {Foobar__c.Name})
				.condition(Foobar__c.Id).equals(row.Id)
				.withUserMode()
				.withCache(CACHE_TIME_TO_LIVE_SECONDS);
		query.toList();
		row.Name = UTIL_Random.randomName();

		DML_Builder.newTransaction().withSystemMode().doUpdate(row).execute();
		List<SObject> rowsAfterTheUpdate = query.toList();

		Assert.areEqual(1, rowsAfterTheUpdate.size(), 'The read after the update should return the one row');
		Assert.areEqual(row.Name, rowsAfterTheUpdate[0].get(FIELD_NAME), 'A read after the update should see the new value');
	}

	/**
	 * @description Builds a read of Foobar__c rows by name, selecting the name.
	 *
	 * @param name The name to filter on
	 *
	 * @return The builder
	 */
	private static QRY_Builder.Builder buildFoobarRead(String name)
	{
		return QRY_Builder.selectFrom(Foobar__c.SObjectType).fields(new List<SObjectField> {Foobar__c.Name}).condition(Foobar__c.Name).equals(name);
	}

	/**
	 * @description Builds a read of accounts selecting the name, for the child subquery and semi-join tests.
	 *
	 * @return The builder
	 */
	private static QRY_Builder.Builder buildAccountRead()
	{
		return QRY_Builder.selectFrom(Account.SObjectType).fields(new List<SObjectField> {Account.Name});
	}

	/**
	 * @description Runs a builder's query through the engine with the parameters the builder itself builds, so the
	 * caller can read the cache status the engine reports.
	 *
	 * @param query The builder
	 *
	 * @return The engine's result
	 */
	private static QRY_Engine.QueryResult executeThroughEngine(QRY_Builder.Builder query)
	{
		return QRY_Engine.execute(query.buildParameters(new QRY_BindRegistry()));
	}

	/**
	 * @description Runs a builder's query and counts the SOQL queries it used.
	 *
	 * @param query The builder
	 *
	 * @return The number of queries the read used
	 */
	private static Integer countQueriesOf(QRY_Builder.Builder query)
	{
		Integer queriesBefore = UTIL_Limits.soqlQueries().used();
		query.toList();
		return UTIL_Limits.soqlQueries().used() - queriesBefore;
	}
}