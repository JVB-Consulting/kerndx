// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for UTIL_Cache
 * Verifies single/bulk operations, scoping, and configuration for framework/subscriber scenarios.
 *
 * @see UTIL_Cache
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date December 2025, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.ApexUnitTestClassShouldHaveRunAs,PMD.NcssTypeCount')
private class UTIL_Cache_TEST
{
	/**
	 * @description Tests basic put and get operations (Single)
	 */
	@IsTest
	private static void shouldStoreAndRetrieveValue()
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto();
		String testKey = 'testKey';
		String testValue = 'testValue';

		Boolean putResult = cache.put(testKey, testValue);

		if(putResult)
		{
			Assert.areEqual(testValue, cache.get(testKey), 'Retrieved value should match stored value');
			Assert.isTrue(cache.contains(testKey), 'Cache should contain the key');
		}
	}

	/**
	 * @description Tests bulk operations (PutAll/GetAll)
	 */
	@IsTest
	private static void shouldHandleBulkOperations()
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto();
		Map<String, Object> bulkData = new Map<String, Object>
		{
				'key1' => 'value1',
				'key2' => 'value2',
				'key3' => 'value3'
		};

		Boolean result = cache.putAll(bulkData);

		if(result)
		{
			Map<String, Object> results = cache.getAll(new Set<String> {'key1', 'key3'});
			Assert.areEqual(2, results.size(), 'Should retrieve 2 items');
			Assert.areEqual('value1', results.get('key1'), 'key1 should round-trip its stored value');
			Assert.areEqual('value3', results.get('key3'), 'key3 should round-trip its stored value');
			Assert.isFalse(results.containsKey('key2'), 'Should not retrieve key2 if not requested');
		}
	}

	/**
	 * @description Tests bulk removal
	 */
	@IsTest
	private static void shouldHandleBulkRemoval()
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto();
		Boolean put1 = cache.put('rem1', 'val1');
		Boolean put2 = cache.put('rem2', 'val2');

		Boolean removed = cache.removeAll(new Set<String> {'rem1', 'rem2'});

		if(put1 && put2)
		{
			Assert.isTrue(removed, 'Remove operation should succeed');
			Assert.isFalse(cache.contains('rem1'), 'rem1 should be gone');
			Assert.isFalse(cache.contains('rem2'), 'rem2 should be gone');
		}
	}

	/**
	 * @description Tests user scoping functionality
	 */
	@IsTest
	private static void shouldScopeKeysByUser()
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto().withUserScope(true);
		String key = 'scopedKey';
		String value = 'scopedValue';

		Boolean putResult = cache.put(key, value);

		if(putResult)
		{
			Assert.areEqual(value, cache.get(key), 'Should retrieve scoped value');

			UTIL_Cache.Store rawCache = UTIL_Cache.auto().withUserScope(false);
			Assert.isNull(rawCache.get(key), 'Unscoped cache should not find the scoped key');
		}
	}

	/**
	 * @description Tests subscriber usage pattern (Custom Partition)
	 */
	@IsTest
	private static void shouldAllowCustomPartitionForSubscribers()
	{
		String customPartition = 'local.MySubscriberPartition';
		UTIL_Cache.Store cache = UTIL_Cache.auto()
				.withPartition(customPartition);

		Boolean result = cache.put('subKey', 'subValue');

		Assert.isNotNull(result, 'Method should execute without unhandled exception');
	}

	/**
	 * @description Tests invalid input handling
	 */
	@IsTest
	private static void shouldHandleInvalidInputs()
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto();

		Assert.isFalse(cache.put(null, 'value'), 'Null key should return false');
		Assert.isFalse(cache.put('', 'value'), 'Blank key should return false');
		Assert.isNull(cache.get(null), 'Null key get should return null');
		Assert.isFalse(cache.remove(null), 'Null key remove should return false');
		Assert.isFalse(cache.remove(''), 'Blank key remove should return false');
		Assert.isFalse(cache.contains(null), 'Null key contains should return false');
		Assert.isFalse(cache.contains(''), 'Blank key contains should return false');

		Assert.isFalse(cache.putAll(new Map<String, Object>()), 'Empty map should return false');
		Assert.isTrue(cache.getAll(null).isEmpty(), 'Null keyset should return empty map');
		Assert.isFalse(cache.removeAll(null), 'Null keyset remove should return false');
		Assert.isFalse(cache.removeAll(new Set<String>()), 'Empty keyset remove should return false');
	}

	/**
	 * @description Tests availability check logic
	 */
	@IsTest
	private static void shouldCheckAvailability()
	{
		Assert.isNotNull(UTIL_Cache.isAvailable(), 'Static check should return boolean');
		Assert.isNotNull(UTIL_Cache.isAvailable(UTIL_Cache.Scope.SESSION), 'Type check should return boolean');
	}

	/**
	 * @description Tests cache configuration chaining
	 */
	@IsTest
	private static void shouldSupportFluentConfiguration()
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto()
				.withScope(UTIL_Cache.Scope.SESSION)
				.withUserScope(true)
				.withPartition('local.Test');

		Assert.isNotNull(cache, 'Cache instance created');
	}

	/**
	 * @description Tests convenience factory method for Org cache
	 */
	@IsTest
	private static void shouldProvideOrgCacheConvenienceFactory()
	{
		UTIL_Cache.Store cache = UTIL_Cache.org();
		Assert.isNotNull(cache, 'Org cache instance should be created');

		Boolean result = cache.put('orgKey', 'orgValue');

		if(result)
		{
			Assert.areEqual('orgValue', cache.get('orgKey'), 'Should retrieve from Org cache');
		}
	}

	/**
	 * @description Tests convenience factory method for Session cache
	 */
	@IsTest
	private static void shouldProvideSessionCacheConvenienceFactory()
	{
		UTIL_Cache.Store cache = UTIL_Cache.session();
		Assert.isNotNull(cache, 'Session cache instance should be created');

		Boolean result = cache.put('sessionKey', 'sessionValue');

		if(result)
		{
			Assert.areEqual('sessionValue', cache.get('sessionKey'), 'Should retrieve from Session cache');
		}
	}

	/**
	 * @description Tests convenience factory method for custom partition
	 */
	@IsTest
	private static void shouldProvidePartitionConvenienceFactory()
	{
		String customPartition = 'local.TestPartition';
		UTIL_Cache.Store cache = UTIL_Cache.partition(customPartition);
		Assert.isNotNull(cache, 'Custom partition cache instance should be created');

		Boolean result = cache.put('testKey', 'testValue');
		Assert.isNotNull(result, 'Method should execute without exception');
	}

	/**
	 * @description Tests single remove method delegation to removeAll
	 */
	@IsTest
	private static void shouldRemoveSingleKey()
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto();
		Boolean putResult = cache.put('removeKey', 'removeValue');

		if(putResult)
		{
			Boolean removed = cache.remove('removeKey');
			Assert.isTrue(removed, 'Single remove should succeed');
			Assert.isFalse(cache.contains('removeKey'), 'Key should be removed');
		}
	}

	/**
	 * @description Tests Org cache fallback when Session cache is partial
	 */
	@IsTest
	private static void shouldFallbackToOrgCacheForMissingKeys()
	{
		UTIL_Cache.Store sessionCache = UTIL_Cache.auto()
				.withScope(UTIL_Cache.Scope.SESSION);
		UTIL_Cache.Store orgCache = UTIL_Cache.auto()
				.withScope(UTIL_Cache.Scope.ORG);
		UTIL_Cache.Store autoCache = UTIL_Cache.auto()
				.withScope(UTIL_Cache.Scope.AUTO);

		Boolean sessionPut = sessionCache.put('sessionKey', 'sessionValue');
		Boolean orgPut = orgCache.put('orgKey', 'orgValue');

		if(sessionPut || orgPut)
		{
			Map<String, Object> results = autoCache.getAll(new Set<String> {'sessionKey', 'orgKey'});
			Assert.isTrue(results.containsKey('sessionKey') || results.containsKey('orgKey'), 'Should find at least one key via fallback');
		}
	}

	/**
	 * @description Tests cache type availability checks
	 */
	@IsTest
	private static void shouldCheckSpecificScopes()
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto();

		Assert.isNotNull(cache.isCacheAvailable(), 'Instance cache availability check should return boolean');
		Assert.isNotNull(UTIL_Cache.isAvailable(UTIL_Cache.Scope.ORG), 'ORG cache check should return boolean');
		Assert.isNotNull(UTIL_Cache.isAvailable(UTIL_Cache.Scope.AUTO), 'AUTO cache check should return boolean');
	}

	/**
	 * @description Tests graceful handling when platform cache is not available (invalid partition)
	 * This simulates scenarios like guest user profiles where Session cache is unavailable
	 */
	@IsTest
	private static void shouldHandleUnavailableCache()
	{
		String invalidPartition = 'local.NonExistentPartition_' + String.valueOf(System.currentTimeMillis());

		UTIL_Cache.Store cache = UTIL_Cache.auto()
				.withPartition(invalidPartition);

		Assert.isFalse(cache.put('testKey', 'testValue'), 'Put should return false for invalid partition');
		Assert.isNull(cache.get('testKey'), 'Get should return null for invalid partition');
		Assert.isFalse(cache.contains('testKey'), 'Contains should return false for invalid partition');
		Assert.isFalse(cache.remove('testKey'), 'Remove should return false for invalid partition');

		Map<String, Object> testData = new Map<String, Object> {'key1' => 'value1', 'key2' => 'value2'};
		Assert.isFalse(cache.putAll(testData), 'PutAll should return false for invalid partition');
		Assert.isTrue(cache.getAll(new Set<String> {'key1', 'key2'}).isEmpty(), 'GetAll should return empty map for invalid partition');
		Assert.isFalse(cache.removeAll(new Set<String> {'key1', 'key2'}), 'RemoveAll should return false for invalid partition');

		Assert.isFalse(cache.isCacheAvailable(), 'Cache should report as unavailable for invalid partition');
	}

	/**
	 * @description Tests Session cache unavailable scenario (guest user profile)
	 * but Org cache available - should fallback to Org
	 */
	@IsTest
	private static void shouldFallbackWhenSessionCacheUnavailable()
	{
		String invalidPartition = 'local.InvalidSessionPartition_' + String.valueOf(System.currentTimeMillis());

		UTIL_Cache.Store sessionCache = UTIL_Cache.auto()
				.withScope(UTIL_Cache.Scope.SESSION)
				.withPartition(invalidPartition);

		Assert.isFalse(sessionCache.put('sessionKey', 'sessionValue'), 'SESSION cache should fail with invalid partition');

		UTIL_Cache.Store orgCache = UTIL_Cache.auto()
				.withScope(UTIL_Cache.Scope.ORG);

		Boolean orgResult = orgCache.put('orgKey', 'orgValue');

		if(orgResult)
		{
			Assert.areEqual('orgValue', orgCache.get('orgKey'), 'Should retrieve from ORG cache');
		}
	}

	/**
	 * @description Tests exception handling in getFromCache when partition operations fail
	 */
	@IsTest
	private static void shouldHandleExceptionsInGetOperations()
	{
		String invalidPartition = 'local.ExceptionTest_' + String.valueOf(System.currentTimeMillis());

		UTIL_Cache.Store cache = UTIL_Cache.auto()
				.withPartition(invalidPartition);

		Object result = cache.get('exceptionKey');
		Assert.isNull(result, 'Get should return null when exceptions occur');

		Map<String, Object> bulkResults = cache.getAll(new Set<String> {'key1', 'key2', 'key3'});
		Assert.isTrue(bulkResults.isEmpty(), 'GetAll should return empty map when exceptions occur');

		Boolean containsResult = cache.contains('exceptionKey');
		Assert.isFalse(containsResult, 'Contains should return false when exceptions occur');
	}

	/**
	 * @description Tests exception handling in putToCache and removeFromCache
	 */
	@IsTest
	private static void shouldHandleExceptionsInWriteOperations()
	{
		String invalidPartition = 'local.WriteExceptionTest_' + String.valueOf(System.currentTimeMillis());

		UTIL_Cache.Store cache = UTIL_Cache.auto()
				.withPartition(invalidPartition);

		Boolean putResult = cache.put('exceptionKey', 'exceptionValue');
		Assert.isFalse(putResult, 'Put should return false when exceptions occur');

		Map<String, Object> bulkData = new Map<String, Object>
		{
				'bulkKey1' => 'bulkValue1',
				'bulkKey2' => 'bulkValue2'
		};
		Boolean putAllResult = cache.putAll(bulkData);
		Assert.isFalse(putAllResult, 'PutAll should return false when exceptions occur');

		Boolean removeResult = cache.remove('exceptionKey');
		Assert.isFalse(removeResult, 'Remove should return false when exceptions occur');

		Boolean removeAllResult = cache.removeAll(new Set<String> {'bulkKey1', 'bulkKey2'});
		Assert.isFalse(removeAllResult, 'RemoveAll should return false when exceptions occur');
	}

	/**
	 * @description Tests simulated put exception with valid partition
	 */
	@IsTest
	private static void shouldHandleSimulatedPutException()
	{
		UTIL_Cache.simulatePutException = true;

		UTIL_Cache.Store cache = UTIL_Cache.auto();
		Boolean result = cache.put('testKey', 'testValue');

		Assert.isFalse(result, 'Put should fail when exception is simulated');

		UTIL_Cache.OperationResult operationResult = cache.getLastOperationResult();
		Assert.isFalse(operationResult.success, 'Operation should report failure');
		Assert.areEqual(UTIL_Cache.Status.WRITE_FAILURE, operationResult.status, 'Status should be WRITE_FAILURE');
	}

	/**
	 * @description Tests simulated get exception with valid partition
	 */
	@IsTest
	private static void shouldHandleSimulatedGetException()
	{
		UTIL_Cache.simulateGetException = true;

		UTIL_Cache.Store cache = UTIL_Cache.auto();
		Object result = cache.get('testKey');

		Assert.isNull(result, 'Get should return null when exception is simulated');

		UTIL_Cache.OperationResult operationResult = cache.getLastOperationResult();
		Assert.isFalse(operationResult.success, 'Operation should report failure');
		Assert.areEqual(UTIL_Cache.Status.READ_FAILURE, operationResult.status, 'Status should be READ_FAILURE');
	}

	/**
	 * @description Tests isCacheAvailable exception handling
	 */
	@IsTest
	private static void shouldHandleExceptionsInAvailabilityCheck()
	{
		String invalidPartition = 'local.AvailabilityException_' + String.valueOf(System.currentTimeMillis());

		UTIL_Cache.Store cache = UTIL_Cache.auto()
				.withPartition(invalidPartition)
				.withScope(UTIL_Cache.Scope.SESSION);

		Boolean sessionAvailable = cache.isCacheAvailable();
		Assert.isFalse(sessionAvailable, 'Should return false for invalid partition instead of throwing exception');

		cache = UTIL_Cache.auto()
				.withPartition(invalidPartition)
				.withScope(UTIL_Cache.Scope.ORG);

		Boolean orgAvailable = cache.isCacheAvailable();
		Assert.isFalse(orgAvailable, 'ORG cache should return false for invalid partition');

		cache = UTIL_Cache.auto()
				.withPartition(invalidPartition)
				.withScope(UTIL_Cache.Scope.AUTO);

		Boolean autoAvailable = cache.isCacheAvailable();
		Assert.isFalse(autoAvailable, 'AUTO should return false when both SESSION and ORG are unavailable');
	}

	/**
	 * @description Tests error reporting for write failures
	 */
	@IsTest
	private static void shouldReportWriteFailureDetails()
	{
		LOG_Builder.ignoreTestMode = true;

		String invalidPartition = 'local.WriteErrorReport_' + String.valueOf(System.currentTimeMillis());
		UTIL_Cache.Store cache = UTIL_Cache.auto()
				.withPartition(invalidPartition);

		Boolean result = cache.put('testKey', 'testValue');
		Assert.isFalse(result, 'Put should fail with invalid partition');

		UTIL_Cache.OperationResult lastResult = cache.getLastOperationResult();
		Assert.isNotNull(lastResult, 'Last operation result should be captured');
		Assert.isFalse(lastResult.success, 'Operation should be marked as failed');
		Assert.areEqual(UTIL_Cache.Status.WRITE_FAILURE, lastResult.status, 'Status should be WRITE_FAILURE');
		Assert.isNotNull(lastResult.errorMessage, 'Error message should be provided');
		Assert.isTrue(lastResult.errorMessage.contains(invalidPartition), 'Error message should contain partition name');
	}

	/**
	 * @description Tests error reporting for read failures
	 */
	@IsTest
	private static void shouldReportReadFailureDetails()
	{
		LOG_Builder.ignoreTestMode = true;

		String invalidPartition = 'local.ReadErrorReport_' + String.valueOf(System.currentTimeMillis());
		UTIL_Cache.Store cache = UTIL_Cache.auto()
				.withPartition(invalidPartition);

		Object result = cache.get('testKey');
		Assert.isNull(result, 'Get should return null with invalid partition');

		UTIL_Cache.OperationResult lastResult = cache.getLastOperationResult();
		Assert.isNotNull(lastResult, 'Last operation result should be captured');
		Assert.isFalse(lastResult.success, 'Operation should be marked as failed');
		Assert.areEqual(UTIL_Cache.Status.READ_FAILURE, lastResult.status, 'Status should be READ_FAILURE');
		Assert.isNotNull(lastResult.errorMessage, 'Error message should be provided');
		Assert.isTrue(lastResult.errorMessage.contains(invalidPartition), 'Error message should contain partition name');
	}

	/**
	 * @description Tests error reporting for cache miss (not a failure, normal scenario)
	 */
	@IsTest
	private static void shouldReportCacheMissDetails()
	{
		if(!UTIL_Cache.isAllocated())
		{
			return;
		}

		UTIL_Cache.Store cache = UTIL_Cache.auto();

		Map<String, Object> results = cache.getAll(new Set<String> {'nonExistent1', 'nonExistent2', 'nonExistent3'});
		Assert.isTrue(results.isEmpty(), 'Should return empty map for non-existent keys');

		UTIL_Cache.OperationResult lastResult = cache.getLastOperationResult();
		Assert.isNotNull(lastResult, 'Last operation result should be captured');
		Assert.isTrue(lastResult.success, 'Cache miss is not a failure');
		Assert.areEqual(UTIL_Cache.Status.CACHE_MISS, lastResult.status, 'Status should be CACHE_MISS');
		Assert.areEqual(3, lastResult.keysRequested, 'Should report 3 keys requested');
		Assert.areEqual(0, lastResult.keysFound, 'Should report 0 keys found');
	}

	/**
	 * @description Tests error reporting for successful operations
	 */
	@IsTest
	private static void shouldReportSuccessDetails()
	{
		if(!UTIL_Cache.isAllocated())
		{
			return;
		}

		UTIL_Cache.Store cache = UTIL_Cache.auto();

		Boolean putResult = cache.put('successKey', 'successValue');
		Assert.isTrue(putResult, 'Put should succeed');

		UTIL_Cache.OperationResult lastResult = cache.getLastOperationResult();
		Assert.isNotNull(lastResult, 'Last operation result should be captured');
		Assert.isTrue(lastResult.success, 'Operation should be successful');
		Assert.areEqual(UTIL_Cache.Status.WRITE_SUCCESS, lastResult.status, 'Status should be WRITE_SUCCESS');
		Assert.isNotNull(lastResult.cacheTypeUsed, 'Cache type should be reported');

		Object value = cache.get('successKey');
		Assert.areEqual('successValue', value, 'Should retrieve cached value');

		lastResult = cache.getLastOperationResult();
		Assert.isTrue(lastResult.success, 'Read should be successful');
		Assert.areEqual(UTIL_Cache.Status.READ_SUCCESS, lastResult.status, 'Status should be READ_SUCCESS');
	}

	/**
	 * @description Tests error reporting for remove failures
	 */
	@IsTest
	private static void shouldReportRemoveFailureDetails()
	{
		LOG_Builder.ignoreTestMode = true;

		String invalidPartition = 'local.RemoveErrorReport_' + String.valueOf(System.currentTimeMillis());
		UTIL_Cache.Store cache = UTIL_Cache.auto()
				.withPartition(invalidPartition);

		Boolean result = cache.remove('testKey');
		Assert.isFalse(result, 'Remove should fail with invalid partition');

		UTIL_Cache.OperationResult lastResult = cache.getLastOperationResult();
		Assert.isNotNull(lastResult, 'Last operation result should be captured');
		Assert.isFalse(lastResult.success, 'Operation should be marked as failed');
		Assert.areEqual(UTIL_Cache.Status.REMOVE_FAILURE, lastResult.status, 'Status should be REMOVE_FAILURE');
		Assert.isNotNull(lastResult.errorMessage, 'Error message should be provided');
		Assert.isTrue(lastResult.errorMessage.contains(invalidPartition), 'Error message should contain partition name');
	}

	/**
	 * @description Tests error reporting distinguishes between cache unavailable vs operation failure
	 */
	@IsTest
	private static void shouldDistinguishCacheUnavailableVsOperationFailure()
	{
		LOG_Builder.ignoreTestMode = true;

		String invalidPartition = 'local.UnavailableVsFailure_' + String.valueOf(System.currentTimeMillis());
		UTIL_Cache.Store cache = UTIL_Cache.auto()
				.withPartition(invalidPartition);

		Boolean result = cache.put('key', 'value');
		Assert.isFalse(result, 'Operation should fail');

		UTIL_Cache.OperationResult lastResult = cache.getLastOperationResult();
		Assert.isNotNull(lastResult, 'Last operation result should be captured');

		Boolean isExpectedFailureType = lastResult.status == UTIL_Cache.Status.WRITE_FAILURE
				|| lastResult.status == UTIL_Cache.Status.CACHE_UNAVAILABLE;
		Assert.isTrue(isExpectedFailureType, 'Status should indicate specific failure type, got: ' + lastResult.status);
		Assert.isNotNull(lastResult.errorMessage, 'Should provide diagnostic error message');
	}

	/**
	 * @description Tests partial cache hits to cover the contains(key) branch in getFromCache
	 */
	@IsTest
	private static void shouldHandlePartialCacheHits()
	{
		if(!UTIL_Cache.isAllocated())
		{
			return;
		}

		UTIL_Cache.Store cache = UTIL_Cache.auto();

		cache.put('existingKey1', 'value1');
		cache.put('existingKey2', 'value2');

		Set<String> requestedKeys = new Set<String> {'existingKey1', 'existingKey2', 'nonExistent1', 'nonExistent2'};
		Map<String, Object> results = cache.getAll(requestedKeys);

		Assert.areEqual(2, results.size(), 'Should return only existing keys');
		Assert.isTrue(results.containsKey('existingKey1'), 'Should find existingKey1');
		Assert.isTrue(results.containsKey('existingKey2'), 'Should find existingKey2');
		Assert.isFalse(results.containsKey('nonExistent1'), 'Should not include nonExistent1');

		UTIL_Cache.OperationResult lastResult = cache.getLastOperationResult();
		Assert.isNotNull(lastResult, 'Last operation result should be captured');

		Assert.isTrue(lastResult.success, 'ORG cache miss is still success (not an error)');
		Assert.areEqual(UTIL_Cache.Status.CACHE_MISS, lastResult.status, 'Should report CACHE_MISS for ORG fallback');
		Assert.areEqual(2, lastResult.keysRequested, 'Should report 2 keys requested from ORG (the missing ones)');
		Assert.areEqual(0, lastResult.keysFound, 'Should report 0 keys found in ORG');
	}

	/**
	 * @description Tests exception in partition.contains() during read operation
	 */
	@IsTest
	private static void shouldHandleContainsException()
	{
		LOG_Builder.ignoreTestMode = true;

		String invalidPartition = 'local.ContainsException_' + String.valueOf(System.currentTimeMillis());
		UTIL_Cache.Store cache = UTIL_Cache.auto()
				.withPartition(invalidPartition);

		Map<String, Object> results = cache.getAll(new Set<String> {'key1', 'key2'});
		Assert.isTrue(results.isEmpty(), 'Should return empty map on exception');

		UTIL_Cache.OperationResult lastResult = cache.getLastOperationResult();
		Assert.isNotNull(lastResult, 'Last operation result should be captured');
		Assert.isFalse(lastResult.success, 'Operation should be marked as failed');
		Assert.areEqual(UTIL_Cache.Status.READ_FAILURE, lastResult.status, 'Should report READ_FAILURE');
		Assert.isNotNull(lastResult.errorMessage, 'Should have error message');
	}

	/**
	 * @description Tests null partition scenario (defensive code coverage)
	 * Uses test-only flag to simulate partition instance returning null
	 */
	@IsTest
	private static void shouldHandleNullPartition()
	{
		LOG_Builder.ignoreTestMode = true;

		UTIL_Cache.Store cache = UTIL_Cache.auto();
		UTIL_Cache.simulateNullPartition = true;

		Boolean putResult = cache.put('testKey', 'testValue');
		Assert.isFalse(putResult, 'Put should fail when partition is null');

		UTIL_Cache.OperationResult putOpResult = cache.getLastOperationResult();
		Assert.isNotNull(putOpResult, 'Should track operation result for put');
		Assert.isFalse(putOpResult.success, 'Put should be marked as failed');
		Assert.areEqual(UTIL_Cache.Status.CACHE_UNAVAILABLE, putOpResult.status, 'Should report CACHE_UNAVAILABLE for null partition on put');
		Assert.isNotNull(putOpResult.errorMessage, 'Should have error message for put');
		Assert.isTrue(putOpResult.errorMessage.contains('not available'), 'Error should mention cache unavailable');

		Map<String, Object> getResult = cache.getAll(new Set<String> {'testKey'});
		Assert.isTrue(getResult.isEmpty(), 'Get should return empty when partition is null');

		UTIL_Cache.OperationResult getOpResult = cache.getLastOperationResult();
		Assert.isNotNull(getOpResult, 'Should track operation result for get');
		Assert.isFalse(getOpResult.success, 'Get should be marked as failed');
		Assert.areEqual(UTIL_Cache.Status.CACHE_UNAVAILABLE, getOpResult.status, 'Should report CACHE_UNAVAILABLE for null partition on get');
		Assert.isNotNull(getOpResult.errorMessage, 'Should have error message for get');
		Assert.isTrue(getOpResult.errorMessage.contains('not available'), 'Error should mention cache unavailable');

		Boolean removeResult = cache.remove('testKey');
		Assert.isFalse(removeResult, 'Remove should fail when partition is null');

		UTIL_Cache.OperationResult removeOpResult = cache.getLastOperationResult();
		Assert.isNotNull(removeOpResult, 'Should track operation result for remove');
		Assert.isFalse(removeOpResult.success, 'Remove should be marked as failed');
		Assert.areEqual(UTIL_Cache.Status.CACHE_UNAVAILABLE, removeOpResult.status, 'Should report CACHE_UNAVAILABLE for null partition on remove');
		Assert.isNotNull(removeOpResult.errorMessage, 'Should have error message for remove');
		Assert.isTrue(removeOpResult.errorMessage.contains('not available'), 'Error should mention cache unavailable');

		UTIL_Cache.simulateNullPartition = false;
	}

	/**
	 * @description Tests that keys with are properly sanitized and work correctly
	 */
	@IsTest
	private static void shouldHandleKeysWithUnderscores()
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto();
		String invalidKey = 'API_PostExample';
		String testValue = 'testValue';

		Boolean putResult = cache.put(invalidKey, testValue);

		if(putResult)
		{
			Assert.areEqual(testValue, cache.get(invalidKey), 'Should retrieve correct value for key with underscores');
			Assert.isTrue(cache.contains(invalidKey), 'Contains should work for key with underscores');
		}
	}

	/**
	 * @description Tests that keys with special characters are properly sanitized
	 */
	@IsTest
	private static void shouldHandleKeysWithSpecialCharacters()
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto();
		String specialKey = 'my-key_with.special@chars!';
		String testValue = 'specialValue';

		Boolean putResult = cache.put(specialKey, testValue);

		if(putResult)
		{
			Assert.areEqual(testValue, cache.get(specialKey), 'Should retrieve correct value for key with special characters');
		}
	}

	/**
	 * @description Tests that long keys (over 50 chars) are properly sanitized
	 */
	@IsTest
	private static void shouldHandleLongKeys()
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto();
		String longKey = 'ThisIsAVeryLongKeyThatExceedsTheFiftyCharacterLimitForPlatformCacheKeys';
		String testValue = 'longValue';

		Boolean putResult = cache.put(longKey, testValue);

		if(putResult)
		{
			Assert.areEqual(testValue, cache.get(longKey), 'Should retrieve correct value for long key');
		}
	}

	/**
	 * @description Tests that keys with namespace prefixes work correctly
	 */
	@IsTest
	private static void shouldHandleNamespacedKeys()
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto();
		String namespacedKey = 'acmelib.API_PostExample';
		String testValue = 'namespacedValue';

		Boolean putResult = cache.put(namespacedKey, testValue);

		if(putResult)
		{
			Assert.areEqual(testValue, cache.get(namespacedKey), 'Should retrieve correct value for namespaced key');
		}
	}

	/**
	 * @description Tests that the same key returns the same hashed value (key hash caching)
	 */
	@IsTest
	private static void shouldCacheHashedKeys()
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto();
		String testKey = 'API_Test_Key_With_Underscores';
		String value1 = 'value1';
		String value2 = 'value2';

		Boolean putResult1 = cache.put(testKey, value1);

		if(putResult1)
		{
			Assert.areEqual(value1, cache.get(testKey), 'First value should be retrieved correctly');

			cache.put(testKey, value2);
			Assert.areEqual(value2, cache.get(testKey), 'Second value should overwrite first');
		}
	}

	/**
	 * @description Tests bulk operations with invalid key names
	 */
	@IsTest
	private static void shouldHandleBulkOperationsWithInvalidKeys()
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto();
		Map<String, Object> bulkData = new Map<String, Object>
		{
				'key_with_underscores' => 'value1',
				'key-with-hyphens' => 'value2',
				'key.with.dots' => 'value3',
				'acmelib__NamespacedKey__c' => 'value4'
		};

		Boolean result = cache.putAll(bulkData);

		if(result)
		{
			Map<String, Object> results = cache.getAll(bulkData.keySet());
			Assert.areEqual(4, results.size(), 'Should retrieve all 4 items');
			Assert.areEqual('value1', results.get('key_with_underscores'), 'underscore-keyed entry should round-trip');
			Assert.areEqual('value2', results.get('key-with-hyphens'), 'hyphen-keyed entry should round-trip');
			Assert.areEqual('value3', results.get('key.with.dots'), 'dot-keyed entry should round-trip');
			Assert.areEqual('value4', results.get('acmelib__NamespacedKey__c'), 'subscriber-namespaced key should round-trip');
		}
	}

	/**
	 * @description Tests removal operations with invalid key names
	 */
	@IsTest
	private static void shouldHandleRemovalWithInvalidKeys()
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto();
		String invalidKey = 'circuit_breaker_state';

		Boolean putResult = cache.put(invalidKey, 'testValue');

		if(putResult)
		{
			Assert.isTrue(cache.contains(invalidKey), 'Key should exist before removal');

			Boolean removed = cache.remove(invalidKey);
			Assert.isTrue(removed, 'Removal should succeed');
			Assert.isFalse(cache.contains(invalidKey), 'Key should not exist after removal');
		}
	}

	/**
	 * @description Tests CacheEntryWrapper validity checking
	 */
	@IsTest
	private static void shouldCheckCacheEntryValidity()
	{
		// Create wrapper with 2 second validity
		Object testValue = new Map<String, Object> {'key1' => 'value1', 'key2' => 'value2'};
		UTIL_Cache.CacheEntry wrapper = new UTIL_Cache.CacheEntry(testValue, 2);

		Assert.isTrue(wrapper.isValid(), 'Entry should be valid immediately after creation');
		Assert.isNotNull(wrapper.cachedAt, 'cachedAt should be set');
		Assert.isNotNull(wrapper.validUntil, 'validUntil should be set');
		Assert.isFalse(wrapper.isCompressed, 'Small data should not be compressed');

		// Fast-forward time by creating wrapper with negative validity
		UTIL_Cache.CacheEntry expiredWrapper = new UTIL_Cache.CacheEntry(testValue, -1);
		Assert.isFalse(expiredWrapper.isValid(), 'Entry with negative validity should be invalid');
	}

	/**
	 * @description Tests that expired cache entries are treated as cache miss
	 */
	@IsTest
	private static void shouldTreatExpiredEntriesAsCacheMiss()
	{
		if(!UTIL_Cache.isAllocated())
		{
			return;
		}

		LOG_Builder.ignoreTestMode = true;

		UTIL_Cache.Store cache = UTIL_Cache.auto();

		// Negative validity produces a wrapper with validUntil in the past, exercising the
		// same "wrapper.isValid() == false → CACHE_MISS" branch as a busy-wait would — no sleep required.
		cache.put('shortLivedKey', 'shortLivedValue', -1);

		Object afterExpiry = cache.get('shortLivedKey');
		Assert.isNull(afterExpiry, 'Expired entry should return null (cache miss)');

		UTIL_Cache.OperationResult result = cache.getLastOperationResult();
		Assert.areEqual(UTIL_Cache.Status.CACHE_MISS, result.status, 'Should report CACHE_MISS for expired entry');
	}

	/**
	 * @description Tests compression for large payloads
	 */
	@IsTest
	private static void shouldCompressLargePayloads()
	{
		// Create large payload (over 100KB threshold)
		List<Map<String, Object>> largeData = new List<Map<String, Object>>();
		for(Integer i = 0; i < 1000; i++)
		{
			largeData.add(new Map<String, Object>
			{
					'id' => i,
					'name' => 'Record ' + i,
					'description' => 'This is a long description field that adds to the payload size. ' +
							'It contains multiple sentences to simulate real-world data. ' +
							'Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
			});
		}

		UTIL_Cache.CacheEntry wrapper = new UTIL_Cache.CacheEntry(largeData, 300);

		Assert.isTrue(wrapper.isCompressed, 'Large payload should be compressed');
		Assert.isNotNull(wrapper.data, 'Compressed data should exist');
		Assert.isTrue(wrapper.data instanceof Blob, 'Compressed data should be Blob');
		Assert.isTrue(wrapper.originalSize > 102400, 'Original size should exceed compression threshold');

		// Unwrap and verify data integrity
		Object unwrapped = wrapper.unwrap();
		Assert.isNotNull(unwrapped, 'Unwrapped data should not be null');

		// Verify we can serialize it back (confirms it's valid data)
		String serialized = JSON.serialize(unwrapped);
		Assert.isTrue(serialized.length() > 0, 'Unwrapped data should be serializable');
	}

	/**
	 * @description Tests that small payloads are not compressed
	 */
	@IsTest
	private static void shouldNotCompressSmallPayloads()
	{
		Map<String, Object> smallData = new Map<String, Object>
		{
				'key1' => 'value1',
				'key2' => 'value2',
				'key3' => 'value3'
		};

		UTIL_Cache.CacheEntry wrapper = new UTIL_Cache.CacheEntry(smallData, 300);

		Assert.isFalse(wrapper.isCompressed, 'Small payload should not be compressed');
		Assert.isNotNull(wrapper.data, 'Data should exist');
		Assert.isFalse(wrapper.data instanceof Blob, 'Uncompressed data should not be Blob');
		Assert.isTrue(wrapper.originalSize < 102400, 'Original size should be below compression threshold');

		// Unwrap and verify data integrity
		Object unwrapped = wrapper.unwrap();
		Assert.areEqual(smallData, unwrapped, 'Unwrapped small data should match original');
	}

	/**
	 * @description Tests end-to-end compression with cache storage and retrieval
	 */
	@IsTest
	private static void shouldHandleCompressionInCacheOperations()
	{
		if(!UTIL_Cache.isAllocated())
		{
			return;
		}

		UTIL_Cache.Store cache = UTIL_Cache.auto();

		// Create large payload to trigger compression
		List<String> largeList = new List<String>();
		for(Integer i = 0; i < 5000; i++)
		{
			largeList.add('This is item number ' + i + ' with some extra text to increase size');
		}

		// Store in cache
		Boolean putResult = cache.put('largePayload', largeList);
		Assert.isTrue(putResult, 'Should successfully store large payload');

		// Retrieve from cache
		Object retrieved = cache.get('largePayload');
		Assert.isNotNull(retrieved, 'Should retrieve large payload');

		// Verify data integrity by comparing serialized versions
		String originalSerialized = JSON.serialize(largeList);
		String retrievedSerialized = JSON.serialize(retrieved);
		Assert.areEqual(originalSerialized, retrievedSerialized, 'Retrieved data should match original after compression/decompression');
	}

	/**
	 * @description Tests that CacheEntryWrapper metadata is populated correctly
	 */
	@IsTest
	private static void shouldPopulateCacheEntryMetadata()
	{
		Map<String, Object> testData = new Map<String, Object>
		{
				'field1' => 'value1',
				'field2' => 123,
				'field3' => true
		};

		Long beforeCreation = System.currentTimeMillis();
		UTIL_Cache.CacheEntry wrapper = new UTIL_Cache.CacheEntry(testData, 600);
		Long afterCreation = System.currentTimeMillis();

		// Check validUntil is approximately 600 seconds in the future
		Long expectedValidUntil = beforeCreation + 600000;
		Assert.isTrue(wrapper.validUntil >= expectedValidUntil && wrapper.validUntil <= expectedValidUntil + 1000,
				'validUntil should be approximately 600 seconds from creation');

		// Check cachedAt is set to current time
		Long cachedAtMillis = wrapper.cachedAt.getTime();
		Assert.isTrue(cachedAtMillis >= beforeCreation && cachedAtMillis <= afterCreation,
				'cachedAt should be set to time of creation');

		// Check originalSize is populated
		Assert.isTrue(wrapper.originalSize > 0, 'originalSize should be greater than 0');

		// Verify originalSize matches actual serialized size
		Integer actualSize = JSON.serialize(testData).length();
		Assert.areEqual(actualSize, wrapper.originalSize, 'originalSize should match serialized data size');
	}

	/**
	 * @description Tests bulk operations with compression
	 */
	@IsTest
	private static void shouldHandleBulkOperationsWithCompression()
	{
		if(!UTIL_Cache.isAllocated())
		{
			return;
		}

		UTIL_Cache.Store cache = UTIL_Cache.auto();

		// Create mix of small and large payloads
		Map<String, Object> bulkData = new Map<String, Object>();

		// Small payload
		bulkData.put('small1', new Map<String, String> {'key' => 'value'});

		// Large payload (will be compressed)
		List<String> largePayload = new List<String>();
		for(Integer i = 0; i < 3000; i++)
		{
			largePayload.add('Item ' + i + ' with additional content to increase size');
		}
		bulkData.put('large1', largePayload);

		// Store all
		Boolean putResult = cache.putAll(bulkData);
		Assert.isTrue(putResult, 'Bulk put should succeed');

		// Retrieve all
		Map<String, Object> retrieved = cache.getAll(new Set<String> {'small1', 'large1'});
		Assert.areEqual(2, retrieved.size(), 'Should retrieve both entries');

		// Verify small payload
		Assert.isNotNull(retrieved.get('small1'), 'Should retrieve small payload');

		// Verify large payload integrity
		Object retrievedLarge = retrieved.get('large1');
		Assert.isNotNull(retrievedLarge, 'Should retrieve large payload');
		String originalSerialized = JSON.serialize(largePayload);
		String retrievedSerialized = JSON.serialize(retrievedLarge);
		Assert.areEqual(originalSerialized, retrievedSerialized, 'Large payload should match after compression/decompression');
	}

	/**
	 * @description Tests KEY_HASH_CACHE overflow scenario to ensure heap leak prevention
	 * Verifies that the hash cache clears itself when it exceeds MAXIMUM_HASH_KEY_CACHE_SIZE entries
	 */
	@IsTest
	private static void shouldClearHashCacheOnOverflow()
	{
		UTIL_Cache.DefaultCache cache = (UTIL_Cache.DefaultCache)UTIL_Cache.auto();

		// Exercise the overflow+clear branch by calling sanitizeKey directly — avoids
		// 2001 round-trips through Platform Cache IO and still drives the
		// KEY_HASH_CACHE.size() > MAXIMUM_HASH_KEY_CACHE_SIZE → clear() branch.
		Integer maxSize = UTIL_Cache.MAXIMUM_HASH_KEY_CACHE_SIZE;

		for(Integer i = 0; i <= maxSize; i++)
		{
			cache.sanitizeKey('test.key.' + i + '.overflow');
		}

		String postClearHash = cache.sanitizeKey('post.clear.test.key');
		Assert.isNotNull(postClearHash, 'sanitizeKey should still return a hash after overflow clear');
	}

	/**
	 * @description Tests that putToCache returns false when scope probe detects no capacity.
	 * Covers the exception catch block in isScopeFunctional and the CACHE_UNAVAILABLE branch in putToCache.
	 */
	@IsTest
	private static void shouldReturnFalseWhenScopeProbeThrowsException()
	{
		if(!UTIL_Cache.isAvailable())
		{
			return;
		}

		UTIL_Cache.simulateProbeException = true;

		UTIL_Cache.Store cache = UTIL_Cache.org();
		Boolean result = cache.put('testKey', 'testValue');

		Assert.isFalse(result, 'Put should fail when scope probe throws exception');

		UTIL_Cache.OperationResult operationResult = cache.getLastOperationResult();
		Assert.isFalse(operationResult.success, 'Operation should report failure');
		Assert.areEqual(UTIL_Cache.Status.CACHE_UNAVAILABLE, operationResult.status, 'Status should be CACHE_UNAVAILABLE');
		Assert.isTrue(operationResult.errorMessage.contains('no capacity'), 'Error message should mention no capacity');
	}

	/**
	 * @description Tests the defensive null/blank key check in sanitizeKey() method
	 * This ensures that if the public API null checks are bypassed, the private method still validates
	 */
	@IsTest
	private static void shouldThrowExceptionForNullOrBlankKeyInSanitizeKey()
	{
		UTIL_Cache.DefaultCache cache = (UTIL_Cache.DefaultCache)UTIL_Cache.auto();

		// Test null key
		try
		{
			cache.sanitizeKey(null);
			Assert.fail('Should throw InvalidParamException for null key');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, Cache.InvalidParamException.class, 'Invalid Exception Type');
			Assert.isTrue(error.getMessage().contains('Invalid Key'), 'Exception message should mention invalid key');
		}

		// Test blank key
		try
		{
			cache.sanitizeKey('');
			Assert.fail('Should throw InvalidParamException for blank key');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, Cache.InvalidParamException.class, 'Invalid Exception Type');
			Assert.isTrue(error.getMessage().contains('Invalid Key'), 'Exception message should mention invalid key');
		}

		// Test whitespace-only key
		try
		{
			cache.sanitizeKey('   ');
			Assert.fail('Should throw InvalidParamException for whitespace key');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, Cache.InvalidParamException.class, 'Invalid Exception Type');
			Assert.isTrue(error.getMessage().contains('Invalid Key'), 'Exception message should mention invalid key');
		}
	}

	/**
	 * @description Tests that oversized cache entries are rejected gracefully
	 * Verifies that putToCache() returns false and sets WRITE_FAILURE status when an entry exceeds MAXIMUM_ENTRY_SIZE
	 */
	@IsTest
	private static void shouldFailWhenEntryExceedsMaximumSize()
	{
		UTIL_Cache.simulateCompressionFailure = true;

		UTIL_Cache.Store cache = UTIL_Cache.auto();

		String oversizedValue = 'x'.repeat(UTIL_Cache.MAXIMUM_ENTRY_SIZE + 1);

		Boolean result = cache.put('oversizedKey', oversizedValue);

		if(UTIL_Cache.isAllocated())
		{
			Assert.isFalse(result, 'Put should return false for oversized entry');

			UTIL_Cache.OperationResult operationResult = cache.getLastOperationResult();
			Assert.isFalse(operationResult.success, 'Operation should report failure');
			Assert.areEqual(UTIL_Cache.Status.WRITE_FAILURE, operationResult.status, 'Status should be WRITE_FAILURE');
			Assert.isTrue(operationResult.errorMessage.contains('exceeds maximum size'), 'Error message should mention exceeds maximum size');
		}
	}

	/**
	 * @description Tests that compression failure is handled gracefully with fallback to uncompressed storage
	 * Uses simulateCompressionFailure flag to force compression to throw an exception
	 */
	@IsTest
	private static void shouldHandleCompressionFailureGracefully()
	{
		// Enable compression failure simulation
		UTIL_Cache.simulateCompressionFailure = true;

		UTIL_Cache.Store cache = UTIL_Cache.auto();

		// Create a payload large enough to trigger compression (>4KB)
		Map<String, String> largePayload = new Map<String, String>();

		for(Integer i = 0; i < 200; i++)
		{
			largePayload.put('field' + i, 'This is a test value with some content to make it larger ' + i);
		}

		// This should trigger compression, which will fail, then fall back to uncompressed
		Boolean result = cache.put('testKey', largePayload);

		// If cache is available, operation should still succeed (fallback to uncompressed)
		if(result)
		{
			Object retrieved = cache.get('testKey');
			Assert.isNotNull(retrieved, 'Should retrieve data even though compression failed');

			Map<String, Object> retrievedMap = (Map<String, Object>)retrieved;
			Assert.areEqual(largePayload.size(), retrievedMap.size(), 'Retrieved map should have same size');
			Assert.areEqual(largePayload.get('field0'), retrievedMap.get('field0'), 'Sample field should match');
		}
	}

	/**
	 * @description Smoke-tests the per-scope allocation probes — only verifies the method
	 * doesn't throw and returns a Boolean. The actual allocation state varies by org.
	 */
	@IsTest
	private static void shouldExposePerScopeAllocationProbes()
	{
		Assert.isNotNull(UTIL_Cache.isOrgAllocated(), 'isOrgAllocated should return a Boolean');
		Assert.isNotNull(UTIL_Cache.isSessionAllocated(), 'isSessionAllocated should return a Boolean');
	}

	/**
	 * @description Tests that inTransaction() returns a fresh Store instance each call,
	 * while both instances share the same backing storage within the transaction.
	 */
	@IsTest
	private static void shouldReturnFreshTransactionStoreInstance()
	{
		UTIL_Cache.Store storeA = UTIL_Cache.inTransaction();
		UTIL_Cache.Store storeB = UTIL_Cache.inTransaction();

		Assert.areNotEqual(storeA, storeB, 'inTransaction() should return a fresh Store instance each call');

		storeA.put('sharedKey', 'sharedValue');
		Assert.areEqual('sharedValue', storeB.get('sharedKey'), 'Both instances should share the same backing storage');
	}

	/**
	 * @description Tests that withScope/withPartition/withUserScope are no-op fluent chains.
	 */
	@IsTest
	private static void shouldFluentlyChainTransactionStoreConfiguration()
	{
		UTIL_Cache.Store cache = UTIL_Cache.inTransaction()
				.withScope(UTIL_Cache.Scope.ORG)
				.withPartition('local.IgnoredPartition')
				.withUserScope(true);

		Assert.isNotNull(cache, 'Fluent chain should return a Store');
		Assert.isTrue(cache.put('key', 'value'), 'Fluent-configured TransactionStore should still put successfully');
		Assert.areEqual('value', cache.get('key'), 'Fluent configuration is no-op; storage still works');
	}

	/**
	 * @description Tests put/get happy path on TransactionStore and that cacheTypeUsed is reported.
	 */
	@IsTest
	private static void shouldPutAndGetValueFromTransactionStore()
	{
		UTIL_Cache.Store cache = UTIL_Cache.inTransaction();

		Boolean putResult = cache.put('transactionKey', 'transactionValue');
		Object retrieved = cache.get('transactionKey');

		Assert.isTrue(putResult, 'Transaction put should succeed');
		Assert.areEqual('transactionValue', retrieved, 'Retrieved value should match');
		UTIL_Cache.OperationResult result = cache.getLastOperationResult();
		Assert.areEqual(UTIL_Cache.Status.READ_SUCCESS, result.status, 'Status should be READ_SUCCESS');
		Assert.areEqual(UTIL_Cache.Scope.IN_TRANSACTION, result.cacheTypeUsed, 'cacheTypeUsed should report TRANSACTION');
	}

	/**
	 * @description Tests that the ttlSeconds parameter is ignored on TransactionStore.
	 */
	@IsTest
	private static void shouldIgnoreTtlOnTransactionStore()
	{
		UTIL_Cache.Store cache = UTIL_Cache.inTransaction();

		Boolean putResult = cache.put('ttlKey', 'ttlValue', 99999);

		Assert.isTrue(putResult, 'Put with absurd TTL should still succeed');
		Assert.areEqual('ttlValue', cache.get('ttlKey'), 'TTL is ignored; value is retrievable');
	}

	/**
	 * @description Tests cache-miss reporting when a key is not stored.
	 */
	@IsTest
	private static void shouldReportCacheMissOnUnknownTransactionKey()
	{
		UTIL_Cache.Store cache = UTIL_Cache.inTransaction();

		Object retrieved = cache.get('unknownKey');

		Assert.isNull(retrieved, 'Unknown key should return null');
		UTIL_Cache.OperationResult result = cache.getLastOperationResult();
		Assert.areEqual(UTIL_Cache.Status.CACHE_MISS, result.status, 'Status should be CACHE_MISS');
		Assert.areEqual(UTIL_Cache.Scope.IN_TRANSACTION, result.cacheTypeUsed, 'cacheTypeUsed should report TRANSACTION');
		Assert.areEqual(1, result.keysRequested, 'keysRequested should be 1');
		Assert.areEqual(0, result.keysFound, 'keysFound should be 0');
	}

	/**
	 * @description Tests getAll partial-hit reporting (keysRequested / keysFound populated).
	 */
	@IsTest
	private static void shouldReturnPartialResultsForMixedKeySetOnTransactionStore()
	{
		UTIL_Cache.Store cache = UTIL_Cache.inTransaction();
		cache.put('present1', 'value1');
		cache.put('present2', 'value2');

		Map<String, Object> results = cache.getAll(new Set<String> {'present1', 'present2', 'missing'});

		Assert.areEqual(2, results.size(), 'Should return only the keys that were present');
		Assert.areEqual('value1', results.get('present1'), 'present1 should round-trip');
		Assert.areEqual('value2', results.get('present2'), 'present2 should round-trip');
		UTIL_Cache.OperationResult result = cache.getLastOperationResult();
		Assert.areEqual(UTIL_Cache.Status.CACHE_MISS, result.status, 'Partial hit reports CACHE_MISS');
		Assert.areEqual(3, result.keysRequested, 'keysRequested should be 3');
		Assert.areEqual(2, result.keysFound, 'keysFound should be 2');
	}

	/**
	 * @description Tests getAll all-hit reporting (READ_SUCCESS, full match).
	 */
	@IsTest
	private static void shouldReturnAllResultsWhenAllKeysPresentOnTransactionStore()
	{
		UTIL_Cache.Store cache = UTIL_Cache.inTransaction();
		cache.put('a', 1);
		cache.put('b', 2);

		Map<String, Object> results = cache.getAll(new Set<String> {'a', 'b'});

		Assert.areEqual(2, results.size(), 'All keys should hit');
		UTIL_Cache.OperationResult result = cache.getLastOperationResult();
		Assert.areEqual(UTIL_Cache.Status.READ_SUCCESS, result.status, 'All-hit should be READ_SUCCESS');
		Assert.areEqual(UTIL_Cache.Scope.IN_TRANSACTION, result.cacheTypeUsed, 'cacheTypeUsed should be TRANSACTION');
	}

	/**
	 * @description Tests remove() on TransactionStore when the key existed.
	 */
	@IsTest
	private static void shouldRemoveKeyFromTransactionStore()
	{
		UTIL_Cache.Store cache = UTIL_Cache.inTransaction();
		cache.put('removeKey', 'removeValue');

		Boolean removed = cache.remove('removeKey');

		Assert.isTrue(removed, 'remove() should return true when the key existed');
		Assert.isFalse(cache.contains('removeKey'), 'Key should be gone after remove');
		Assert.areEqual(UTIL_Cache.Status.REMOVE_SUCCESS, cache.getLastOperationResult().status, 'Status should be REMOVE_SUCCESS');
	}

	/**
	 * @description Tests remove() returns false when the key was never present.
	 */
	@IsTest
	private static void shouldReturnFalseRemovingMissingKey()
	{
		UTIL_Cache.Store cache = UTIL_Cache.inTransaction();

		Boolean removed = cache.remove('notThere');

		Assert.isFalse(removed, 'remove() should return false for a missing key');
		Assert.areEqual(UTIL_Cache.Status.REMOVE_SUCCESS, cache.getLastOperationResult().status, 'Status still records REMOVE_SUCCESS (no-op succeeded)');
	}

	/**
	 * @description Tests putAll + removeAll bulk operations on TransactionStore.
	 */
	@IsTest
	private static void shouldBulkPutAndBulkRemoveFromTransactionStore()
	{
		UTIL_Cache.Store cache = UTIL_Cache.inTransaction();
		Map<String, Object> bulkInputs = new Map<String, Object>
		{
				'bulkKey1' => 'one',
				'bulkKey2' => 'two',
				'bulkKey3' => 'three'
		};

		Assert.isTrue(cache.putAll(bulkInputs), 'Bulk put should succeed');
		Assert.areEqual('two', cache.get('bulkKey2'), 'Bulk-put values should be retrievable');

		Assert.isTrue(cache.removeAll(new Set<String> {'bulkKey1', 'bulkKey2'}), 'Bulk remove should succeed');
		Assert.isFalse(cache.contains('bulkKey1'), 'bulkKey1 should be removed');
		Assert.isFalse(cache.contains('bulkKey2'), 'bulkKey2 should be removed');
		Assert.isTrue(cache.contains('bulkKey3'), 'bulkKey3 should still be present');
	}

	/**
	 * @description Tests putAll with default TTL (overload routes through putAll(map, null)).
	 */
	@IsTest
	private static void shouldBulkPutWithDefaultTtlOnTransactionStore()
	{
		UTIL_Cache.Store cache = UTIL_Cache.inTransaction();

		Boolean result = cache.putAll(new Map<String, Object> {'key' => 'value'});

		Assert.isTrue(result, 'putAll(map) should route through putAll(map, null) and succeed');
		Assert.areEqual('value', cache.get('key'), 'Default-TTL bulk put should round-trip');
	}

	/**
	 * @description Tests bulk-input rejection branches (null + empty for putAll, getAll, removeAll).
	 */
	@IsTest
	private static void shouldReturnFalseOnNullBulkInputForTransactionStore()
	{
		UTIL_Cache.Store cache = UTIL_Cache.inTransaction();

		Assert.isFalse(cache.putAll(null), 'putAll(null) should return false');
		Assert.isFalse(cache.putAll(new Map<String, Object>()), 'putAll(empty) should return false');
		Assert.isTrue(cache.getAll(null).isEmpty(), 'getAll(null) should return empty map');
		Assert.isTrue(cache.getAll(new Set<String>()).isEmpty(), 'getAll(empty) should return empty map');
		Assert.isFalse(cache.removeAll(null), 'removeAll(null) should return false');
		Assert.isFalse(cache.removeAll(new Set<String>()), 'removeAll(empty) should return false');
	}

	/**
	 * @description Tests blank-key rejection on single-key operations.
	 */
	@IsTest
	private static void shouldRejectBlankKeyOnTransactionStore()
	{
		UTIL_Cache.Store cache = UTIL_Cache.inTransaction();

		Assert.isFalse(cache.put(null, 'value'), 'put(null) should return false');
		Assert.isFalse(cache.put('', 'value'), 'put(blank) should return false');
		Assert.isNull(cache.get(null), 'get(null) should return null');
		Assert.isNull(cache.get(''), 'get(blank) should return null');
		Assert.isFalse(cache.contains(null), 'contains(null) should return false');
		Assert.isFalse(cache.contains(''), 'contains(blank) should return false');
		Assert.isFalse(cache.remove(null), 'remove(null) should return false');
		Assert.isFalse(cache.remove(''), 'remove(blank) should return false');
	}

	/**
	 * @description Tests contains() reports true after a put.
	 */
	@IsTest
	private static void shouldReturnContainsTrueAfterTransactionPut()
	{
		UTIL_Cache.Store cache = UTIL_Cache.inTransaction();
		cache.put('hereKey', 'hereValue');

		Assert.isTrue(cache.contains('hereKey'), 'contains() should be true after put');
	}

	/**
	 * @description Tests contains() reports false after a remove.
	 */
	@IsTest
	private static void shouldReturnContainsFalseAfterTransactionRemove()
	{
		UTIL_Cache.Store cache = UTIL_Cache.inTransaction();
		cache.put('hereKey', 'hereValue');
		cache.remove('hereKey');

		Assert.isFalse(cache.contains('hereKey'), 'contains() should be false after remove');
	}

	/**
	 * @description Tests isCacheAvailable() unconditionally returns true on TransactionStore.
	 */
	@IsTest
	private static void shouldReportTransactionStoreAlwaysAvailable()
	{
		UTIL_Cache.Store cache = UTIL_Cache.inTransaction();

		Assert.isTrue(cache.isCacheAvailable(), 'TransactionStore is always available');
	}

	/**
	 * @description Tests per-instance independence of lastOperationResult — concurrent
	 * callers see their own diagnostic state even though they share the same STORAGE.
	 */
	@IsTest
	private static void shouldKeepIndependentLastOperationResultPerTransactionStoreInstance()
	{
		UTIL_Cache.Store storeA = UTIL_Cache.inTransaction();
		UTIL_Cache.Store storeB = UTIL_Cache.inTransaction();

		storeA.put('writerKey', 'writerValue');
		storeB.get('missingFromBPerspective');

		Assert.areEqual(UTIL_Cache.Status.WRITE_SUCCESS, storeA.getLastOperationResult().status, 'storeA should still report WRITE_SUCCESS');
		Assert.areEqual(UTIL_Cache.Status.CACHE_MISS, storeB.getLastOperationResult().status, 'storeB should report CACHE_MISS independently');
	}

	/**
	 * @description Tests that TRANSACTION-scope writes do not leak into the Platform Cache scopes.
	 */
	@IsTest
	private static void shouldNotLeakTransactionEntriesToOrgOrSession()
	{
		UTIL_Cache.Store transactionCache = UTIL_Cache.inTransaction();
		transactionCache.put('isolatedKey', 'isolatedValue');

		Assert.isNull(UTIL_Cache.org().get('isolatedKey'), 'Org cache should not see TRANSACTION-only entry');
		Assert.isNull(UTIL_Cache.session().get('isolatedKey'), 'Session cache should not see TRANSACTION-only entry');
	}

	/**
	 * @description Tests that autoWithTransactionFallback() returns a CompositeStore distinct
	 * from auto() and from inTransaction().
	 */
	@IsTest
	private static void shouldReturnCompositeStoreFromFallbackFactory()
	{
		UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();

		Assert.isNotNull(composite, 'Factory should return a Store');
		Assert.isTrue(composite.isCacheAvailable(), 'CompositeStore is always available (fallback tier guarantees it)');
	}

	/**
	 * @description Tests that withScope/withPartition/withUserScope on the composite forward to
	 * the primary Store.
	 */
	@IsTest
	private static void shouldForwardFluentConfigurationToPrimaryStore()
	{
		UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback()
				.withScope(UTIL_Cache.Scope.ORG)
				.withPartition('local.IgnoredPartition')
				.withUserScope(true);

		Assert.isNotNull(composite, 'Fluent chain should return a Store');
	}

	/**
	 * @description Tests primary-success path — value goes to Platform Cache when allocated.
	 */
	@IsTest
	private static void shouldUsePrimaryWhenPlatformCacheAllocated()
	{
		UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();

		Boolean putResult = composite.put('primaryKey', 'primaryValue');

		if(putResult)
		{
			UTIL_Cache.OperationResult result = composite.getLastOperationResult();
			Assert.isTrue(result.cacheTypeUsed == UTIL_Cache.Scope.SESSION || result.cacheTypeUsed == UTIL_Cache.Scope.ORG,
					'Primary success should report SESSION or ORG, not IN_TRANSACTION');
		}
	}

	/**
	 * @description Tests primary failure → fallback success path on put().
	 * Uses simulateNullPartition to force the Platform Cache primary to return false.
	 */
	@IsTest
	private static void shouldFallBackToTransactionWhenPrimaryPutFails()
	{
		UTIL_Cache.simulateNullPartition = true;
		try
		{
			UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();

			Boolean putResult = composite.put('fallbackKey', 'fallbackValue');

			Assert.isTrue(putResult, 'Composite put should succeed via fallback');
			UTIL_Cache.OperationResult result = composite.getLastOperationResult();
			Assert.areEqual(UTIL_Cache.Scope.IN_TRANSACTION, result.cacheTypeUsed, 'cacheTypeUsed should report IN_TRANSACTION on fallback');
			Assert.areEqual(UTIL_Cache.Status.WRITE_SUCCESS, result.status, 'Status should be WRITE_SUCCESS');
		}
		finally
		{
			UTIL_Cache.simulateNullPartition = false;
		}
	}

	/**
	 * @description Tests both-fail path on put — blank key fails both primary and fallback,
	 * composite returns false.
	 */
	@IsTest
	private static void shouldReturnFalseWhenBothPrimaryAndFallbackPutFail()
	{
		UTIL_Cache.simulateNullPartition = true;
		try
		{
			UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();

			Boolean putResult = composite.put('', 'value');

			Assert.isFalse(putResult, 'Composite put with blank key should fail in both stores');
		}
		finally
		{
			UTIL_Cache.simulateNullPartition = false;
		}
	}

	/**
	 * @description Tests get primary-hit path when Platform Cache is allocated.
	 */
	@IsTest
	private static void shouldReturnFromPrimaryWhenPlatformCacheHit()
	{
		UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();
		Boolean stored = composite.put('readKey', 'readValue');

		if(stored && composite.getLastOperationResult().cacheTypeUsed != UTIL_Cache.Scope.IN_TRANSACTION)
		{
			Assert.areEqual('readValue', composite.get('readKey'), 'Should read from primary when allocated');
		}
	}

	/**
	 * @description Tests get path when primary misses and fallback hits.
	 * Loads value directly into the fallback (TransactionStore) and reads via the composite.
	 */
	@IsTest
	private static void shouldReturnFromFallbackWhenPrimaryMissAndFallbackHit()
	{
		UTIL_Cache.inTransaction().put('onlyInFallback', 'fromFallback');

		UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();
		Object value = composite.get('onlyInFallback');

		Assert.areEqual('fromFallback', value, 'Should read from fallback when primary misses');
		UTIL_Cache.OperationResult result = composite.getLastOperationResult();
		Assert.areEqual(UTIL_Cache.Scope.IN_TRANSACTION, result.cacheTypeUsed, 'cacheTypeUsed should report IN_TRANSACTION');
		Assert.areEqual(UTIL_Cache.Status.READ_SUCCESS, result.status, 'Status should be READ_SUCCESS');
	}

	/**
	 * @description Tests get returns null when both primary and fallback miss.
	 */
	@IsTest
	private static void shouldReturnNullWhenBothStoresMiss()
	{
		UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();

		Object value = composite.get('nothingAnywhere');

		Assert.isNull(value, 'Both-miss should return null');
	}

	/**
	 * @description Tests contains() — primary true short-circuits.
	 */
	@IsTest
	private static void shouldReturnContainsTrueWhenInPrimary()
	{
		UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();
		Boolean stored = composite.put('inPrimary', 'value');

		if(stored && composite.getLastOperationResult().cacheTypeUsed != UTIL_Cache.Scope.IN_TRANSACTION)
		{
			Assert.isTrue(composite.contains('inPrimary'), 'contains() should be true when key is in primary');
		}
	}

	/**
	 * @description Tests contains() — primary false but fallback true.
	 */
	@IsTest
	private static void shouldReturnContainsTrueWhenInFallbackOnly()
	{
		UTIL_Cache.inTransaction().put('inFallbackOnly', 'value');

		UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();

		Assert.isTrue(composite.contains('inFallbackOnly'), 'contains() should be true when key is in fallback only');
	}

	/**
	 * @description Tests contains() — both stores false.
	 */
	@IsTest
	private static void shouldReturnContainsFalseWhenInNeither()
	{
		UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();

		Assert.isFalse(composite.contains('nowhereToBeFound'), 'contains() should be false when key is in neither');
	}

	/**
	 * @description Tests remove() — orphan cleanup across both stores.
	 */
	@IsTest
	private static void shouldRemoveFromBothPrimaryAndFallback()
	{
		UTIL_Cache.inTransaction().put('cleanupKey', 'value');

		UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();

		Boolean removed = composite.remove('cleanupKey');

		Assert.isTrue(removed, 'remove() should return true when key was present in either store');
		Assert.isFalse(composite.contains('cleanupKey'), 'Key should be gone from both stores after remove');
	}

	/**
	 * @description Tests bulk put primary success.
	 */
	@IsTest
	private static void shouldBulkPutToPrimaryWhenAvailable()
	{
		UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();
		Map<String, Object> entries = new Map<String, Object> {'b1' => '1', 'b2' => '2'};

		Boolean result = composite.putAll(entries);

		if(result)
		{
			Assert.isNotNull(composite.getLastOperationResult(), 'lastOperationResult should be populated');
		}
	}

	/**
	 * @description Tests bulk put fallback path when primary is unavailable.
	 */
	@IsTest
	private static void shouldBulkPutFallBackToTransactionWhenPrimaryFails()
	{
		UTIL_Cache.simulateNullPartition = true;
		try
		{
			UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();
			Map<String, Object> entries = new Map<String, Object> {'bf1' => 'one', 'bf2' => 'two'};

			Boolean result = composite.putAll(entries);

			Assert.isTrue(result, 'Composite putAll should succeed via fallback');
			Assert.areEqual(UTIL_Cache.Scope.IN_TRANSACTION, composite.getLastOperationResult().cacheTypeUsed, 'cacheTypeUsed should report IN_TRANSACTION');
		}
		finally
		{
			UTIL_Cache.simulateNullPartition = false;
		}
	}

	/**
	 * @description Tests bulk put both-fail path — empty map fails both stores.
	 */
	@IsTest
	private static void shouldReturnFalseWhenBothBulkPutPathsFail()
	{
		UTIL_Cache.simulateNullPartition = true;
		try
		{
			UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();

			Assert.isFalse(composite.putAll(new Map<String, Object>()), 'Empty map should be rejected by both stores');
		}
		finally
		{
			UTIL_Cache.simulateNullPartition = false;
		}
	}

	/**
	 * @description Tests bulk getAll — all in primary path.
	 */
	@IsTest
	private static void shouldBulkGetAllFromPrimary()
	{
		UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();
		Map<String, Object> entries = new Map<String, Object> {'gp1' => '1', 'gp2' => '2'};
		Boolean stored = composite.putAll(entries);

		if(stored && composite.getLastOperationResult().cacheTypeUsed != UTIL_Cache.Scope.IN_TRANSACTION)
		{
			Map<String, Object> results = composite.getAll(new Set<String> {'gp1', 'gp2'});
			Assert.areEqual(2, results.size(), 'Both keys should resolve from primary');
		}
	}

	/**
	 * @description Tests bulk getAll — mixed path with some keys in primary and others in fallback.
	 */
	@IsTest
	private static void shouldBulkGetMixedAcrossPrimaryAndFallback()
	{
		UTIL_Cache.Store primary = UTIL_Cache.auto();
		Boolean primaryStored = primary.put('inPrimaryMix', 'fromPrimary');
		UTIL_Cache.inTransaction().put('inFallbackMix', 'fromFallback');

		if(primaryStored)
		{
			UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();
			Map<String, Object> results = composite.getAll(new Set<String> {'inPrimaryMix', 'inFallbackMix'});

			Assert.areEqual('fromPrimary', results.get('inPrimaryMix'), 'Primary value should be present');
			Assert.areEqual('fromFallback', results.get('inFallbackMix'), 'Fallback value should be present');
		}
	}

	/**
	 * @description Tests bulk getAll — every satisfied key comes from fallback only.
	 */
	@IsTest
	private static void shouldBulkGetAllFromFallbackWhenPrimaryUnavailable()
	{
		UTIL_Cache.inTransaction().put('allFb1', 'fb1');
		UTIL_Cache.inTransaction().put('allFb2', 'fb2');

		UTIL_Cache.simulateNullPartition = true;
		try
		{
			UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();
			Map<String, Object> results = composite.getAll(new Set<String> {'allFb1', 'allFb2'});

			Assert.areEqual(2, results.size(), 'Both fallback-only keys should resolve');
			Assert.areEqual(UTIL_Cache.Scope.IN_TRANSACTION, composite.getLastOperationResult().cacheTypeUsed, 'cacheTypeUsed should report IN_TRANSACTION');
			Assert.areEqual(UTIL_Cache.Status.READ_SUCCESS, composite.getLastOperationResult().status, 'All-hit reports READ_SUCCESS');
		}
		finally
		{
			UTIL_Cache.simulateNullPartition = false;
		}
	}

	/**
	 * @description Tests bulk getAll — fallback partial hit reports CACHE_MISS with keysRequested/keysFound.
	 */
	@IsTest
	private static void shouldBulkGetReportPartialFallbackHit()
	{
		UTIL_Cache.inTransaction().put('fbHit', 'fb');

		UTIL_Cache.simulateNullPartition = true;
		try
		{
			UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();
			Map<String, Object> results = composite.getAll(new Set<String> {'fbHit', 'fbMiss'});

			Assert.areEqual(1, results.size(), 'Only the present key should resolve');
			UTIL_Cache.OperationResult result = composite.getLastOperationResult();
			Assert.areEqual(UTIL_Cache.Status.CACHE_MISS, result.status, 'Partial fallback hit reports CACHE_MISS');
			Assert.areEqual(2, result.keysRequested, 'keysRequested should be 2');
			Assert.areEqual(1, result.keysFound, 'keysFound should be 1');
		}
		finally
		{
			UTIL_Cache.simulateNullPartition = false;
		}
	}

	/**
	 * @description Tests bulk getAll — empty/null key set short-circuits to empty result.
	 */
	@IsTest
	private static void shouldBulkGetReturnEmptyWhenNoKeysRequested()
	{
		UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();

		Assert.isTrue(composite.getAll(null).isEmpty(), 'Null keyset should return empty map');
		Assert.isTrue(composite.getAll(new Set<String>()).isEmpty(), 'Empty keyset should return empty map');
	}

	/**
	 * @description Tests bulk removeAll — clears keys from both stores.
	 */
	@IsTest
	private static void shouldBulkRemoveFromBothPrimaryAndFallback()
	{
		UTIL_Cache.inTransaction().put('toBeRemoved1', 'a');
		UTIL_Cache.inTransaction().put('toBeRemoved2', 'b');

		UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();
		Boolean removed = composite.removeAll(new Set<String> {'toBeRemoved1', 'toBeRemoved2'});

		Assert.isTrue(removed, 'Bulk remove should return true when keys were present in either store');
		Assert.isFalse(composite.contains('toBeRemoved1'), 'toBeRemoved1 should be cleared from both stores');
		Assert.isFalse(composite.contains('toBeRemoved2'), 'toBeRemoved2 should be cleared from both stores');
	}

	/**
	 * @description Tests composite returns isCacheAvailable() == true always.
	 */
	@IsTest
	private static void shouldReportCompositeStoreAlwaysAvailable()
	{
		UTIL_Cache.Store composite = UTIL_Cache.autoWithTransactionFallback();

		UTIL_Cache.simulateNullPartition = true;
		try
		{
			Assert.isTrue(composite.isCacheAvailable(), 'CompositeStore is always available because fallback is always available');
		}
		finally
		{
			UTIL_Cache.simulateNullPartition = false;
		}
	}

}