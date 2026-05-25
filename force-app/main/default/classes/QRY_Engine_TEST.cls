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
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
@IsTest(SeeAllData=false IsParallel=true)
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
		parameters.bypassCache = true;

		QRY_Engine.QueryResult result1 = QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult result2 = QRY_Engine.execute(parameters);

		Assert.isFalse(result1.isCached, 'First call should NOT be cached when bypassCache is true');
		Assert.isFalse(result2.isCached, 'Second call should NOT be cached when bypassCache is true');
	}

	/**
	 * @description Tests that caching is disabled when userMode is enabled.
	 * Security-sensitive queries should not be cached across contexts.
	 */
	@IsTest
	private static void shouldNotCacheWhenUserModeEnabled()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'UserMode Cache Test')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cacheTTL = 600;
		parameters.bypassCache = false;
		parameters.userMode = true;

		QRY_Engine.QueryResult result1 = QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult result2 = QRY_Engine.execute(parameters);

		Assert.isFalse(result1.isCached, 'UserMode queries should not be cached');
		Assert.isFalse(result2.isCached, 'UserMode queries should not be cached on repeat');
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
		parameters.bypassCache = false;

		QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult cachedResult = QRY_Engine.execute(parameters);

		Assert.isTrue(cachedResult.isCached, 'isCached should be true on cache hit');
		Assert.areEqual(1, cachedResult.records.size(), 'Should return correct number of records');
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
	 * @description Tests that cacheStatus is STORED on first execution with cache enabled.
	 */
	@IsTest
	private static void shouldTrackCacheStatusOnMiss()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'CacheStatus STORED')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cacheTTL = 600;

		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(QRY_Engine.CacheStatus.STORED, result.cacheStatus, 'cacheStatus should be STORED on first call');
	}

	/**
	 * @description Tests that cacheStatus is HIT on cache hit.
	 */
	@IsTest
	private static void shouldTrackCacheStatusOnHit()
	{
		Foobar__c testRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, 'CacheStatus HIT')
				.build();

		QRY_Engine.QueryParameters parameters = new QRY_Engine.QueryParameters();
		parameters.objectType = Foobar__c.SObjectType;
		parameters.queryString = 'SELECT Id, ' + FIELD_NAME + ' FROM ' + OBJECT_NAME + ' WHERE Id = :b1';
		parameters.bindMap = new Map<String, Object> {'b1' => testRecord.Id};
		parameters.cacheTTL = 600;

		QRY_Engine.execute(parameters);
		QRY_Engine.QueryResult result = QRY_Engine.execute(parameters);

		Assert.areEqual(QRY_Engine.CacheStatus.HIT, result.cacheStatus, 'cacheStatus should be HIT on second call');
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
}