// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Internal query execution engine for the QRY_Builder framework.
 * Handles query execution, caching, sharing enforcement, and pagination.
 *
 * **VISIBILITY**: Intentionally `public` (package-internal), NOT `global`.
 * This is a deliberate architectural decision:
 * - Internal implementation details should not be part of the managed package API
 * - Subscribers use QRY_Builder's fluent API which wraps this engine
 * - Keeping this internal allows future refactoring without breaking subscriber code
 *
 * @see QRY_Builder
 * @see QRY_Generator
 * @see QRY_Engine_TEST
 *
 * @author Jason van Beukering
 *
 * @group Query Infrastructure
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength')
public inherited sharing class QRY_Engine
{
	/**
	 * @description Default cache TTL in seconds (15 minutes).
	 */
	public static final Integer DEFAULT_CACHE_TTL = 900;

	/**
	 * @description Maximum query offset allowed by Salesforce for standard SOQL queries.
	 * Used as a fallback cap when cursor-based pagination is not available (e.g., mock queries).
	 */
	public static final Integer MAX_QUERY_OFFSET = 2000;

	/**
	 * @description Cache status indicating how the query result was resolved.
	 */
	public enum CacheStatus
	{
		/**
		 * @description Result was served from cache.
		 */
		HIT,

		/**
		 * @description Result was fetched from database and stored in cache.
		 */
		STORED,

		/**
		 * @description Cache was not used for this query.
		 */
		BYPASS
	}

	/**
	 * @description Cursor mode for query execution. Determines whether and how cursor-based
	 * pagination is used.
	 */
	public enum CursorMode
	{
		/**
		 * @description PaginationCursor for getPage() pagination with deleted record tracking.
		 */
		PAGINATION,

		/**
		 * @description Standard Database.Cursor for random item selection (supports 50M record limit).
		 */
		STANDARD
	}

	/**
	 * @description Mock registry for test isolation. Maps SObjectType to mock records.
	 * Honestly-lazy: stays `null` until a test writes to it via `setMock`. Production code paths
	 * (where mocks are never registered) never allocate. Read-only checks (`hasMock`, `getMock`,
	 * `clearMocks`) guard against the null-state instead of triggering initialization.
	 */
	@TestVisible
	private static Map<SObjectType, List<SObject>> mockRegistry;

	/**
	 * @description Registry for mock context class names. Maps SObjectType to FormulaEval context class names
	 * for use in smart mock filtering. Honestly-lazy: only allocated when a context is registered.
	 */
	@TestVisible
	private static Map<SObjectType, String> mockContextRegistry;

	/**
	 * @description Registry of exceptions to throw when querying a specific SObjectType. Used for
	 * negative-path test coverage so subscribers can exercise their catch blocks without needing
	 * to mock at a different layer. Populated via setMockException; cleared via clearMockException,
	 * clearMockExceptions, or clearMocks. Honestly-lazy: stays `null` in production so every query
	 * through `validateAndApplyMockException` pays only a single null-check, not a Map allocation.
	 */
	@TestVisible
	private static Map<SObjectType, Exception> mockExceptionRegistry;

	/**
	 * @description Lazy-initializer for `mockRegistry`. Allocates the backing map on first write.
	 *
	 * @return The initialized registry instance.
	 */
	private static Map<SObjectType, List<SObject>> ensureMockRegistry()
	{
		if(mockRegistry == null)
		{
			mockRegistry = new Map<SObjectType, List<SObject>>();
		}
		return mockRegistry;
	}

	/**
	 * @description Lazy-initializer for `mockContextRegistry`. Allocates the backing map on first write.
	 *
	 * @return The initialized registry instance.
	 */
	private static Map<SObjectType, String> ensureMockContextRegistry()
	{
		if(mockContextRegistry == null)
		{
			mockContextRegistry = new Map<SObjectType, String>();
		}
		return mockContextRegistry;
	}

	/**
	 * @description Lazy-initializer for `mockExceptionRegistry`. Allocates the backing map on first write.
	 *
	 * @return The initialized registry instance.
	 */
	private static Map<SObjectType, Exception> ensureMockExceptionRegistry()
	{
		if(mockExceptionRegistry == null)
		{
			mockExceptionRegistry = new Map<SObjectType, Exception>();
		}
		return mockExceptionRegistry;
	}

	/**
	 * @description Sets mock records for a specific SObjectType.
	 *
	 * @param objectType The SObjectType to mock.
	 * @param mocks The mock records to return.
	 */
	public static void setMock(SObjectType objectType, List<SObject> mocks)
	{
		if(objectType == null)
		{
			throw new IllegalArgumentException('SObjectType cannot be null');
		}
		if(mocks == null)
		{
			mockRegistry?.remove(objectType);
		}
		else
		{
			validateMockRecords(objectType, mocks);
			ensureMockRegistry().put(objectType, mocks);
		}
	}

	/**
	 * @description Registers a FormulaEval context class for an SObjectType, enabling smart mock filtering.
	 *
	 * @param objectType The SObjectType to register the context for.
	 * @param contextClassName The fully qualified class name of the FormulaEval context.
	 */
	public static void registerMockContextClass(SObjectType objectType, String contextClassName)
	{
		if(objectType == null)
		{
			throw new IllegalArgumentException('SObjectType cannot be null');
		}
		ensureMockContextRegistry().put(objectType, contextClassName);
	}

	/**
	 * @description Clears all registered mocks, mock context classes, and mock exceptions.
	 * Honestly-lazy: skips registries that were never allocated so production callers pay only
	 * three null-checks, not three map-clears.
	 */
	public static void clearMocks()
	{
		mockRegistry?.clear();
		mockContextRegistry?.clear();
		mockExceptionRegistry?.clear();
	}

	/**
	 * @description Registers an Exception to be thrown the next time a query is executed
	 * against the specified SObjectType. Used for negative-path testing so subscribers can
	 * exercise their catch blocks around a SOQL call without mocking at a different layer.
	 *
	 * @param objectType The SObjectType for which queries should throw.
	 * @param exceptionToThrow The exception instance to throw. May not be null.
	 *
	 * @throws IllegalArgumentException When objectType or exceptionToThrow is null.
	 */
	public static void setMockException(SObjectType objectType, Exception exceptionToThrow)
	{
		if(objectType == null)
		{
			throw new IllegalArgumentException('SObjectType cannot be null');
		}
		if(exceptionToThrow == null)
		{
			throw new IllegalArgumentException('Exception cannot be null');
		}
		ensureMockExceptionRegistry().put(objectType, exceptionToThrow);
	}

	/**
	 * @description Removes any registered exception for the specified SObjectType. Honestly-lazy:
	 * no-op when the registry has never been allocated.
	 *
	 * @param objectType The SObjectType whose registered exception (if any) is cleared.
	 */
	public static void clearMockException(SObjectType objectType)
	{
		mockExceptionRegistry?.remove(objectType);
	}

	/**
	 * @description Removes all registered mock exceptions across every SObjectType.
	 * Used by TST_Mock.clear() to wipe the entire exception registry. Honestly-lazy: no-op when
	 * the registry has never been allocated.
	 */
	public static void clearMockExceptions()
	{
		mockExceptionRegistry?.clear();
	}

	/**
	 * @description Returns the registered mock exception for the specified SObjectType,
	 * or null when no exception is registered. Honestly-lazy: never triggers allocation.
	 *
	 * @param objectType The SObjectType to look up.
	 *
	 * @return The registered Exception, or null when none is registered.
	 */
	public static Exception getMockException(SObjectType objectType)
	{
		return mockExceptionRegistry?.get(objectType);
	}

	/**
	 * @description Validates query parameters and rethrows any registered mock exception
	 * for the target SObjectType. Shared early-guard for execute(), executeCount(), and
	 * getQueryLocator() so the null check and the exception-check ordering live in one place.
	 *
	 * Honestly-lazy: in production the exception registry is `null`, so the only cost on the
	 * hot path is the parameters null-check and a single reference null-check — no map lookup,
	 * no allocation.
	 *
	 * @param parameters The query parameters to validate.
	 *
	 * @throws IllegalArgumentException When parameters is null.
	 */
	private static void validateAndApplyMockException(QueryParameters parameters)
	{
		if(parameters == null)
		{
			throw new IllegalArgumentException('QueryParameters cannot be null');
		}

		Exception registered = mockExceptionRegistry?.get(parameters.objectType);
		if(registered != null)
		{
			throw registered;
		}
	}

	/**
	 * @description Checks if mocks are registered for a specific SObjectType.
	 *
	 * @param objectType The SObjectType to check.
	 *
	 * @return True if mocks are registered.
	 */
	public static Boolean hasMock(SObjectType objectType)
	{
		return mockRegistry?.containsKey(objectType) == true;
	}

	/**
	 * @description Gets mock records for a specific SObjectType.
	 *
	 * @param objectType The SObjectType.
	 *
	 * @return The mock records or null if not registered.
	 */
	public static List<SObject> getMock(SObjectType objectType)
	{
		return mockRegistry?.get(objectType);
	}

	/**
	 * @description Validates that mock records match the expected SObjectType.
	 *
	 * @param objectType The expected type.
	 * @param mocks The mock records.
	 */
	private static void validateMockRecords(SObjectType objectType, List<SObject> mocks)
	{
		for(SObject record : mocks)
		{
			if(record != null && record.getSObjectType() != objectType)
			{
				throw new IllegalArgumentException
						(
								'Mock record type mismatch: expected ' + objectType + ' but got ' + record.getSObjectType()
						);
			}
		}
	}

	/**
	 * @description Executes a query and returns results.
	 *
	 * @param parameters The query parameters.
	 *
	 * @return Query result containing records and metadata.
	 */
	public static QueryResult execute(QueryParameters parameters)
	{
		validateAndApplyMockException(parameters);

		if(hasMock(parameters.objectType))
		{
			return executeMock(parameters);
		}

		return executeQuery(parameters);
	}

	/**
	 * @description Executes a count query.
	 *
	 * @param parameters The query parameters.
	 *
	 * @return The count of matching records.
	 */
	public static Integer executeCount(QueryParameters parameters)
	{
		validateAndApplyMockException(parameters);

		if(hasMock(parameters.objectType))
		{
			List<SObject> mocks = getMock(parameters.objectType);
			return mocks != null ? mocks.size() : 0;
		}

		return executeCountQuery(parameters);
	}

	/**
	 * @description Gets a QueryLocator for batch processing.
	 *
	 * @param parameters The query parameters.
	 *
	 * @return Database.QueryLocator for use in batch jobs.
	 */
	public static Database.QueryLocator getQueryLocator(QueryParameters parameters)
	{
		validateAndApplyMockException(parameters);

		UTIL_QueryPerformanceTimer timer = createPerformanceTimer(parameters, 'QueryLocator');

		AccessLevel accessLevel = parameters.userMode ? AccessLevel.USER_MODE : AccessLevel.SYSTEM_MODE;
		Database.QueryLocator locator = Database.getQueryLocatorWithBinds
				(
						parameters.queryString,
						parameters.bindMap ?? new Map<String, Object>(),
						accessLevel
				);

		stopTimer(timer, parameters, CacheStatus.BYPASS, null);

		return locator;
	}

	/**
	 * @description Executes a query using mocks. When a FormulaEval context class is available
	 * and conditions are present, filters mock records in memory using UTIL_FormulaFilter.
	 *
	 * @param parameters The query parameters.
	 *
	 * @return Query result with mock data.
	 */
	@SuppressWarnings('PMD.CognitiveComplexity')
	private static QueryResult executeMock(QueryParameters parameters)
	{
		List<SObject> mocks = getMock(parameters.objectType);
		QueryResult result = new QueryResult();

		if(mocks == null || mocks.isEmpty())
		{
			result.records = new List<SObject>();
			result.totalRecords = 0;
			result.isMocked = true;
			return result;
		}

		mocks = filterMocks(mocks, parameters);
		mocks = sortMocks(mocks, parameters);

		result.totalRecords = mocks.size();
		result.isMocked = true;

		if(parameters.pageSize != null && parameters.pageSize > 0)
		{
			Integer startIndex = Math.max((parameters.pageNumber - 1) * parameters.pageSize, 0);
			if(startIndex >= mocks.size())
			{
				result.records = new List<SObject>();
				return result;
			}

			Integer endIndex = Math.min(startIndex + parameters.pageSize, mocks.size());
			List<SObject> paginatedMocks = new List<SObject>();
			for(Integer i = startIndex; i < endIndex; i++)
			{
				paginatedMocks.add(mocks[i]);
			}
			result.records = paginatedMocks;
		}
		else if(parameters.limitCount != null)
		{
			if(mocks.size() > parameters.limitCount)
			{
				List<SObject> limitedMocks = new List<SObject>();
				for(Integer i = 0; i < parameters.limitCount; i++)
				{
					limitedMocks.add(mocks[i]);
				}
				result.records = limitedMocks;
			}
			else
			{
				result.records = mocks;
			}
		}
		else
		{
			result.records = mocks;
		}

		return result;
	}

	/**
	 * @description Filters mock records in memory using FormulaEval when conditions and a
	 * context class are available. Falls back to returning all mocks when filtering cannot
	 * be applied.
	 *
	 * @param mocks The mock records to filter.
	 * @param parameters The query parameters containing conditions.
	 *
	 * @return The filtered mock records, or the original list if filtering is not possible.
	 */
	private static List<SObject> filterMocks(List<SObject> mocks, QueryParameters parameters)
	{
		if(parameters.whereCondition == null)
		{
			return mocks;
		}

		String contextClassName = resolveMockContextClass(parameters.objectType);
		if(contextClassName == null)
		{
			return mocks;
		}

		String formula = QRY_ConditionFormula.toFormula(parameters.whereCondition);
		if(formula == null)
		{
			return mocks;
		}

		try
		{
			UTIL_FormulaFilter filter = new UTIL_FormulaFilter('QRY_Engine.filterMocks', contextClassName, formula);
			UTIL_FormulaFilter.DTO_FilterResults filterResults = filter.filter(null, mocks);
			return filterResults.newRecords;
		}
		catch(Exception error)
		{
			return mocks;
		}
	}

	/**
	 * @description Resolves the FormulaEval context class name for the given SObjectType.
	 * Checks the explicit mock context registry first, then falls back to auto-detection
	 * via UTIL_FormulaFilter.resolveContextClass.
	 *
	 * @param objectType The SObjectType to resolve.
	 *
	 * @return The context class name, or null if none available.
	 */
	private static String resolveMockContextClass(SObjectType objectType)
	{
		String contextClassName = mockContextRegistry?.get(objectType);
		if(String.isNotBlank(contextClassName))
		{
			return contextClassName;
		}

		return UTIL_FormulaFilter.resolveContextClass(objectType, null);
	}

	/**
	 * @description Sorts mock records in memory using ORDER BY configuration from the query.
	 * Returns mocks unchanged when no ORDER BY fields are specified.
	 *
	 * @param mocks The mock records to sort.
	 * @param parameters The query parameters containing ORDER BY configuration.
	 *
	 * @return The sorted mock records, or the original list if no ordering is specified.
	 */
	private static List<SObject> sortMocks(List<SObject> mocks, QueryParameters parameters)
	{
		if(parameters.orderByFields == null || parameters.orderByFields.isEmpty())
		{
			return mocks;
		}

		return UTIL_List.sort(mocks, new MockOrderByComparator(parameters.orderByFields));
	}

	/**
	 * @description Comparator for sorting mock SObjects by multiple ORDER BY fields.
	 * Iterates fields in order; the first non-zero comparison result determines ordering.
	 */
	private class MockOrderByComparator extends UTIL_Comparators.SObjectComparator
	{
		/**
		 * @description The ORDER BY fields to sort by.
		 */
		private final List<QRY_Generator.OrderBy> orderByFields;

		/**
		 * @description Constructs a comparator for the given ORDER BY fields.
		 *
		 * @param orderByFields The ORDER BY fields to sort by.
		 */
		public MockOrderByComparator(List<QRY_Generator.OrderBy> orderByFields)
		{
			this.orderByFields = orderByFields;
		}

		/**
		 * @description Compares two SObjects by evaluating each ORDER BY field in sequence.
		 *
		 * @param firstRecord The first SObject to compare.
		 * @param secondRecord The second SObject to compare.
		 *
		 * @return Negative if first is less, positive if greater, zero if equal across all fields.
		 */
		public override Integer compare(SObject firstRecord, SObject secondRecord)
		{
			for(QRY_Generator.OrderBy orderBy : orderByFields)
			{
				UTIL_Comparators.SObjectFieldComparator fieldComparator = new UTIL_Comparators.SObjectFieldComparator
						(
								orderBy.getField(),
								orderBy.isAscending()
						);

				Integer result = fieldComparator.compare(firstRecord, secondRecord);

				if(result != 0)
				{
					return result;
				}
			}

			return 0;
		}
	}

	/**
	 * @description Executes the actual database query with optional caching.
	 *
	 * @param parameters The query parameters.
	 *
	 * @return Query result with database records.
	 */
	private static QueryResult executeQuery(QueryParameters parameters)
	{
		UTIL_QueryPerformanceTimer timer = createPerformanceTimer(parameters, 'Query');

		Boolean useCache = shouldUseCache(parameters);
		String cacheKey = useCache ? generateCacheKey(parameters) : null;
		Boolean userScoped = parameters.userScopedCache == true;

		if(useCache && !parameters.bypassCache)
		{
			QueryResult cachedResult = getFromCache(cacheKey, userScoped);
			if(cachedResult != null)
			{
				cachedResult.cacheStatus = CacheStatus.HIT;
				cachedResult.queryDurationMs = stopTimer(timer, parameters, CacheStatus.HIT, cachedResult.records.size());
				return cachedResult;
			}
		}

		QueryResult result = new QueryResult();
		AccessLevel accessLevel = parameters.userMode ? AccessLevel.USER_MODE : AccessLevel.SYSTEM_MODE;
		Map<String, Object> bindMap = parameters.bindMap ?? new Map<String, Object>();

		if(parameters.enforceSharing == true)
		{
			executeWithSharing(parameters, result, accessLevel, bindMap);
		}
		else if(parameters.enforceSharing == false)
		{
			executeWithoutSharing(parameters, result, accessLevel, bindMap);
		}
		else
		{
			executeInherited(parameters, result, accessLevel, bindMap);
		}

		if(useCache)
		{
			storeInCache(cacheKey, result, parameters.cacheTTL, userScoped);
			result.cacheStatus = CacheStatus.STORED;
		}
		else
		{
			result.cacheStatus = CacheStatus.BYPASS;
		}

		result.queryDurationMs = stopTimer(timer, parameters, result.cacheStatus, result.records.size());

		return result;
	}

	/**
	 * @description Determines whether caching should be used for the query.
	 * Caching is disabled when:
	 * - cacheTTL is null (caching not requested)
	 * - userMode is enabled (security-sensitive data shouldn't be cached)
	 * - Random results are requested (would cache non-random results)
	 * - Row locking is enabled (FOR UPDATE/REFERENCE/VIEW)
	 * - ALL ROWS is enabled (may include deleted records)
	 *
	 * @param parameters The query parameters.
	 *
	 * @return True if caching should be used.
	 */
	private static Boolean shouldUseCache(QueryParameters parameters)
	{
		if(parameters.cacheTTL == null)
		{
			return false;
		}
		if(parameters.userMode)
		{
			return false;
		}
		if(parameters.randomResults)
		{
			return false;
		}
		if(parameters.lockForUpdate || parameters.lockForReference || parameters.lockForView)
		{
			return false;
		}
		if(parameters.includeAllRows)
		{
			return false;
		}
		return true;
	}

	/**
	 * @description Generates a cache key from the query string and bind map.
	 *
	 * @param parameters The query parameters.
	 *
	 * @return A cache key string.
	 */
	private static String generateCacheKey(QueryParameters parameters)
	{
		String normalizedQuery = parameters.queryString?.toUpperCase()?.normalizeSpace();
		String bindMapString = parameters.bindMap != null ? JSON.serialize(parameters.bindMap) : '';
		return 'QRY:' + normalizedQuery + ':' + bindMapString;
	}

	/**
	 * @description Attempts to retrieve a cached query result.
	 *
	 * @param cacheKey The cache key.
	 * @param userScoped Whether to use user-scoped cache.
	 *
	 * @return Cached QueryResult or null if not found/expired.
	 */
	private static QueryResult getFromCache(String cacheKey, Boolean userScoped)
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto().withUserScope(userScoped);
		Object cached = cache.get(cacheKey);

		if(cached instanceof List<SObject>)
		{
			QueryResult result = new QueryResult();
			result.records = (List<SObject>)cached;
			result.totalRecords = result.records.size();
			result.isCached = true;
			return result;
		}

		return null;
	}

	/**
	 * @description Stores query results in the cache.
	 *
	 * @param cacheKey The cache key.
	 * @param result The query result to cache.
	 * @param ttlSeconds The time-to-live in seconds.
	 * @param userScoped Whether to use user-scoped cache.
	 */
	private static void storeInCache(String cacheKey, QueryResult result, Integer ttlSeconds, Boolean userScoped)
	{
		UTIL_Cache.Store cache = UTIL_Cache.auto().withUserScope(userScoped);
		Integer effectiveTTL = ttlSeconds == 0 ? DEFAULT_CACHE_TTL : ttlSeconds;
		cache.put(cacheKey, result.records, effectiveTTL);
	}

	/**
	 * @description Executes query with sharing rules enforced.
	 *
	 * @param parameters The query parameters.
	 * @param result The result to populate.
	 * @param accessLevel The access level.
	 * @param bindMap The bind variables.
	 */
	private static void executeWithSharing(QueryParameters parameters, QueryResult result, AccessLevel accessLevel, Map<String, Object> bindMap)
	{
		WithSharingExecutor executor = new WithSharingExecutor();
		executor.execute(parameters, result, accessLevel, bindMap);
	}

	/**
	 * @description Executes query without sharing rules.
	 *
	 * @param parameters The query parameters.
	 * @param result The result to populate.
	 * @param accessLevel The access level.
	 * @param bindMap The bind variables.
	 */
	private static void executeWithoutSharing(QueryParameters parameters, QueryResult result, AccessLevel accessLevel, Map<String, Object> bindMap)
	{
		WithoutSharingExecutor executor = new WithoutSharingExecutor();
		executor.execute(parameters, result, accessLevel, bindMap);
	}

	/**
	 * @description Executes query with inherited sharing.
	 *
	 * @param parameters The query parameters.
	 * @param result The result to populate.
	 * @param accessLevel The access level.
	 * @param bindMap The bind variables.
	 */
	private static void executeInherited(QueryParameters parameters, QueryResult result, AccessLevel accessLevel, Map<String, Object> bindMap)
	{
		doExecute(parameters, result, accessLevel, bindMap);
	}

	/**
	 * @description Internal query execution logic.
	 *
	 * @param parameters The query parameters.
	 * @param result The result to populate.
	 * @param accessLevel The access level.
	 * @param bindMap The bind variables.
	 */
	private static void doExecute(QueryParameters parameters, QueryResult result, AccessLevel accessLevel, Map<String, Object> bindMap)
	{
		if(parameters.cursorMode == CursorMode.STANDARD)
		{
			Database.Cursor cursor = Database.getCursorWithBinds(parameters.queryString, bindMap, accessLevel);
			result.totalRecords = cursor.getNumRecords();

			Integer offset = parameters.offset ?? 0;
			Integer recordsToRetrieve = Math.min(result.totalRecords - offset, Math.max(parameters.pageSize ?? result.totalRecords, 1));

			if(recordsToRetrieve > 0 && offset < result.totalRecords)
			{
				result.records = cursor.fetch(offset, recordsToRetrieve);
			}
			else
			{
				result.records = new List<SObject>();
			}
		}
		else if(parameters.cursorMode == CursorMode.PAGINATION)
		{
			Database.PaginationCursor cursor = Database.getPaginationCursorWithBinds(parameters.queryString, bindMap, accessLevel);
			result.totalRecords = cursor.getNumRecords();

			Integer offset = parameters.offset ?? 0;
			Integer recordsToRetrieve = Math.min(result.totalRecords - offset, Math.max(parameters.pageSize ?? result.totalRecords, 1));

			if(recordsToRetrieve > 0 && offset < result.totalRecords)
			{
				Database.CursorFetchResult fetchResult = cursor.fetchPage(offset, recordsToRetrieve);
				result.records = fetchResult.getRecords();
				result.deletedRecords = fetchResult.getNumDeletedRecords();
			}
			else
			{
				result.records = new List<SObject>();
			}

			result.cursor = cursor;
		}
		else
		{
			result.records = Database.queryWithBinds(parameters.queryString, bindMap, accessLevel);
			result.totalRecords = result.records.size();
		}
	}

	/**
	 * @description Executes a count query.
	 *
	 * @param parameters The query parameters.
	 *
	 * @return The count of matching records.
	 */
	private static Integer executeCountQuery(QueryParameters parameters)
	{
		UTIL_QueryPerformanceTimer timer = createPerformanceTimer(parameters, 'Count');

		AccessLevel accessLevel = parameters.userMode ? AccessLevel.USER_MODE : AccessLevel.SYSTEM_MODE;
		Map<String, Object> bindMap = parameters.bindMap ?? new Map<String, Object>();

		Integer count = Database.countQueryWithBinds
				(
						parameters.queryString,
						bindMap,
						accessLevel
				);

		stopTimer(timer, parameters, CacheStatus.BYPASS, count);

		return count;
	}

	/**
	 * @description Creates, configures, and starts a performance timer based on query parameters.
	 * Sets object name and logging behaviour (suppress/force/threshold) before starting.
	 *
	 * @param parameters The QueryParameters containing logging control settings.
	 * @param operationSuffix The suffix for the operation name (e.g., 'Query', 'Count', 'QueryLocator').
	 *
	 * @return A started UTIL_QueryPerformanceTimer instance.
	 */
	private static UTIL_QueryPerformanceTimer createPerformanceTimer(QueryParameters parameters, String operationSuffix)
	{
		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(parameters.objectType);
		UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer
				(
						objectName + ' ' + operationSuffix,
						QRY_Engine.class.getName() + '/execute' + operationSuffix
				);

		timer.withObjectName(objectName);

		if(parameters.suppressPerformanceLogging == true)
		{
			timer.suppressLogging();
		}
		else if(parameters.forcePerformanceLogging == true)
		{
			timer.log();
		}
		else if(parameters.customPerformanceThresholdMs != null)
		{
			timer.logIfSlowerThan(parameters.customPerformanceThresholdMs);
		}

		timer.start();
		return timer;
	}

	/**
	 * @description Stops the performance timer with query context and returns elapsed time.
	 *
	 * @param timer The running timer to stop.
	 * @param parameters The query parameters (provides queryString and bindMap).
	 * @param status Cache status indicating how the result was resolved.
	 * @param rowCount Number of rows returned (null for QueryLocator).
	 *
	 * @return The elapsed time in milliseconds.
	 */
	private static Long stopTimer(UTIL_QueryPerformanceTimer timer, QueryParameters parameters, CacheStatus status, Integer rowCount)
	{
		timer.withQueryContext(parameters.queryString, parameters.bindMap, status == CacheStatus.HIT, status.name());

		if(rowCount != null)
		{
			timer.setRowCount(rowCount);
		}

		timer.stop();
		return timer.getTime();
	}

	/**
	 * @description Parameters for query execution.
	 */
	public class QueryParameters
	{
		/**
		 * @description The SObjectType being queried.
		 */
		public SObjectType objectType;

		/**
		 * @description The SOQL query string.
		 */
		public String queryString;

		/**
		 * @description The bind variable map.
		 */
		public Map<String, Object> bindMap;

		/**
		 * @description Whether to use USER_MODE.
		 */
		public Boolean userMode = false;

		/**
		 * @description Whether to enforce sharing rules. Null = inherited.
		 */
		public Boolean enforceSharing;

		/**
		 * @description The cursor mode for query execution. Null = no cursor (standard query).
		 */
		public CursorMode cursorMode;

		/**
		 * @description The page size for pagination.
		 */
		public Integer pageSize;

		/**
		 * @description The page number (1-based).
		 */
		public Integer pageNumber = 1;

		/**
		 * @description The offset for pagination.
		 */
		public Integer offset;

		/**
		 * @description The limit count.
		 */
		public Integer limitCount;

		/**
		 * @description Cache TTL in seconds. Null = no caching.
		 */
		public Integer cacheTTL;

		/**
		 * @description Whether to bypass cache.
		 */
		public Boolean bypassCache = false;

		/**
		 * @description Whether random results are requested.
		 */
		public Boolean randomResults = false;

		/**
		 * @description Whether to lock records FOR UPDATE.
		 */
		public Boolean lockForUpdate = false;

		/**
		 * @description Whether to lock records FOR REFERENCE.
		 */
		public Boolean lockForReference = false;

		/**
		 * @description Whether to lock records FOR VIEW.
		 */
		public Boolean lockForView = false;

		/**
		 * @description Whether to include ALL ROWS (deleted/archived).
		 */
		public Boolean includeAllRows = false;

		/**
		 * @description Whether to use user-scoped caching.
		 */
		public Boolean userScopedCache = false;

		/**
		 * @description Whether to suppress performance logging for this query.
		 */
		public Boolean suppressPerformanceLogging = false;

		/**
		 * @description Whether to force performance logging regardless of threshold.
		 */
		public Boolean forcePerformanceLogging = false;

		/**
		 * @description Custom performance threshold in milliseconds. Overrides global setting.
		 */
		public Integer customPerformanceThresholdMs;

		/**
		 * @description The structured WHERE condition for smart mock filtering.
		 */
		public QRY_Condition.Evaluable whereCondition;

		/**
		 * @description The ORDER BY fields for mock sorting.
		 */
		public List<QRY_Generator.OrderBy> orderByFields;
	}

	/**
	 * @description Result of a query execution.
	 */
	public class QueryResult
	{
		/**
		 * @description The records returned.
		 */
		public List<SObject> records = new List<SObject>();

		/**
		 * @description The total number of records (for pagination).
		 */
		public Integer totalRecords = 0;

		/**
		 * @description Number of records deleted since the cursor was created.
		 */
		public Integer deletedRecords = 0;

		/**
		 * @description The PaginationCursor for cursor state pass-through.
		 */
		public Database.PaginationCursor cursor;

		/**
		 * @description Whether results came from mocks.
		 */
		public Boolean isMocked = false;

		/**
		 * @description Whether results came from cache.
		 */
		public Boolean isCached = false;

		/**
		 * @description The query execution duration in milliseconds.
		 */
		public Long queryDurationMs;

		/**
		 * @description Cache status indicating how the result was resolved.
		 */
		public CacheStatus cacheStatus;

		/**
		 * @description Whether there are more pages.
		 */
		public Boolean hasMorePages
		{
			get
			{
				return records.size() < totalRecords;
			}
		}
	}

	/**
	 * @description Executor with sharing rules enforced.
	 */
	private with sharing class WithSharingExecutor
	{
		/**
		 * @description Executes the query with sharing.
		 *
		 * @param parameters The query parameters.
		 * @param result The result to populate.
		 * @param accessLevel The access level.
		 * @param bindMap The bind variables.
		 */
		public void execute(QueryParameters parameters, QueryResult result, AccessLevel accessLevel, Map<String, Object> bindMap)
		{
			doExecute(parameters, result, accessLevel, bindMap);
		}
	}

	/**
	 * @description Executor without sharing rules.
	 */
	private without sharing class WithoutSharingExecutor
	{
		/**
		 * @description Executes the query without sharing.
		 *
		 * @param parameters The query parameters.
		 * @param result The result to populate.
		 * @param accessLevel The access level.
		 * @param bindMap The bind variables.
		 */
		public void execute(QueryParameters parameters, QueryResult result, AccessLevel accessLevel, Map<String, Object> bindMap)
		{
			doExecute(parameters, result, accessLevel, bindMap);
		}
	}
}