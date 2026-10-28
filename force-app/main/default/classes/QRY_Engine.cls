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
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength,PMD.ExcessivePublicCount,PMD.NcssTypeCount')
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
	 * @description The most rows the in-memory query cache keeps for one read: the 200 records of one trigger batch.
	 * The framework chose this number; it does not come from the data. What limits memory is the memory cache's heap
	 * guard, the check that stops the cache from using too much heap.
	 */
	@TestVisible
	private static final Integer MEMORY_CACHE_ROW_LIMIT = 200;

	/**
	 * @description The transaction's in-memory query cache. Emptied at the start and the end of every DML_Transaction commit attempt.
	 */
	@TestVisible
	private static final UTIL_Cache.TransactionMemoryCache QUERY_RESULT_MEMORY_CACHE = new UTIL_Cache.TransactionMemoryCache();

	/**
	 * @description Cache-key segment for a result produced with sharing enforced through the with-sharing proxy.
	 */
	private static final String CACHE_KEY_SHARING_ENFORCED = 'ENFORCED';

	/**
	 * @description Cache-key segment for a result produced with sharing bypassed; org-wide, so shared by every caller.
	 */
	private static final String CACHE_KEY_SHARING_BYPASSED = 'BYPASSED';

	/**
	 * @description In-memory cache-key segment for a result read in user mode, with the running user's object, field
	 * and sharing access applied.
	 */
	private static final String CACHE_KEY_ACCESS_USER = 'USER';

	/**
	 * @description In-memory cache-key segment for a result read in system mode, with object and field access waived.
	 */
	private static final String CACHE_KEY_ACCESS_SYSTEM = 'SYSTEM';

	/**
	 * @description The Platform Cache stores this transaction has already built, one per scope, so the check for which
	 * partition is available runs once per scope per transaction.
	 */
	@TestVisible
	private static final Map<UTIL_Cache.Scope, UTIL_Cache.Store> DURABLE_STORE_BY_SCOPE = new Map<UTIL_Cache.Scope, UTIL_Cache.Store>();

	/**
	 * @description Functions whose values the platform renders for the running user: the translated label, the
	 * locale's formatting, the user's currency and the user's time zone. Matched on the upper-cased, space-normalised
	 * query, so a space before the parenthesis still counts.
	 */
	private static final Pattern USER_DEPENDENT_FUNCTION = Pattern.compile('\\b(TOLABEL|FORMAT|CONVERTCURRENCY|CONVERTTIMEZONE) ?\\(');

	/**
	 * @description A USING SCOPE other than EVERYTHING, which picks rows relative to the running user: theirs, their
	 * team's, their territory's or their delegated records.
	 */
	private static final Pattern USER_DEPENDENT_SCOPE = Pattern.compile(' USING SCOPE (?!EVERYTHING\\b)\\w+');

	/**
	 * @description Relative date literals, which the platform reads in the running user's time zone and week start.
	 * Fiscal literals are listed too: the fiscal calendar is the org's, but the current fiscal period still starts at
	 * midnight in the running user's time zone.
	 */
	private static final Pattern USER_DEPENDENT_DATE_LITERAL = Pattern.compile('\\b(TODAY|YESTERDAY|TOMORROW|(THIS|LAST|NEXT)_(WEEK|MONTH)|'
			+ '(THIS|LAST|NEXT)_(FISCAL_)?(QUARTER|YEAR)|(LAST|NEXT)_N_(DAYS|WEEKS|MONTHS)|(LAST|NEXT)_N_(FISCAL_)?(QUARTERS|YEARS)|'
			+ 'N_(DAYS|WEEKS|MONTHS)_AGO|N_(FISCAL_)?(QUARTERS|YEARS)_AGO|(LAST|NEXT)_90_DAYS)\\b');

	/**
	 * @description Finds a child subquery in an upper-cased, space-normalised query: an opening parenthesis followed by
	 * SELECT that is not a semi-join (IN or NOT IN followed by a subquery).
	 */
	private static final Pattern CHILD_SUBQUERY = Pattern.compile('(?<!\\bIN ?)\\( ?SELECT\\b');

	/**
	 * @description A single-quoted string literal, escaped quotes inside it included. Blanked out before looking for a
	 * child subquery, so text inside a literal is never taken for one.
	 */
	private static final Pattern QUOTED_LITERAL = Pattern.compile('\'(?:\\\\.|[^\'\\\\])*\'');

	/**
	 * @description Message for a page that cannot be read because the transaction has used up its cursors. A cursor
	 * is a platform handle that reads a large result in parts. The engine throws this on purpose, because otherwise
	 * the platform would fail the same call with a governor limit exception that no catch block can catch.
	 */
	private static final String CURSOR_CAPACITY_EXHAUSTED = 'This transaction has no cursor capacity left to read another page. '
			+ 'Spread the paged reads across transactions, or narrow the query so fewer rows are matched.';

	/**
	 * @description Message thrown when a null answer is queued; it points the caller at the empty list, which
	 * means the next query finds nothing.
	 */
	private static final String QUEUED_ANSWER_NULL_MESSAGE = 'A queued mock answer cannot be null; queue an empty list for a query that finds nothing';

	/**
	 * @description Message thrown when null is passed to addAggregateMock as the rows; it points the caller at the
	 * empty list, which adds no row.
	 */
	private static final String ADDED_AGGREGATE_ROWS_NULL_MESSAGE = 'The aggregate rows to add cannot be null; add an empty list to add no row';

	/**
	 * @description Message thrown when an aggregate query meets record mocks but no aggregate rows for its type.
	 * The placeholder is the SObjectType.
	 */
	private static final String AGGREGATE_QUERY_WITHOUT_AGGREGATE_MOCK_MESSAGE = 'An aggregate query on {0} found record mocks but no aggregate rows. '
			+ 'Record mocks never answer an aggregate query. Register the rows the query should return with TST_Mock.registerAggregateRows.';

	/**
	 * @description A value a test sets for the most rows pagination cursors may read. It is null in production, where
	 * the limit always comes from UTIL_Limits.apexPaginationCursorRows().maximum() (100,000 at the time of writing).
	 * That way the framework follows the governor limit instead of keeping its own copy, which could go out of date.
	 *
	 * A query that matches more rows than the transaction has left fails when the cursor is CREATED, with
	 * `System.LimitException: Too many apex pagination cursor rows`. That is a governor limit exception, so no
	 * catch block can catch it and nothing can recover from it; the whole transaction fails. The only protection is
	 * to count the matching rows BEFORE the cursor is opened, and to read the page from a standard cursor instead.
	 * A standard cursor counts against a separate, far larger allowance.
	 *
	 * A test lowers this value to reach the too-many-rows case through the real limited count and the real standard
	 * cursor, without creating a hundred thousand rows.
	 */
	@TestVisible
	private static Integer paginationCursorRowLimitOverride;

	/**
	 * @description A value a test sets for the most standard cursors one transaction may open. It is null in
	 * production, where it comes from UTIL_Limits.apexCursors().maximum() (50 at the time of writing). A test sets it
	 * to zero to act as if every cursor is used. That is the only way to reach the ways of reading a page that come
	 * after the standard cursor, without opening fifty cursors first.
	 */
	@TestVisible
	private static Integer standardCursorLimitOverride;

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
		BYPASS,

		/**
		 * @description Result was served from the transaction's in-memory query cache.
		 */
		MEMORY_HIT,

		/**
		 * @description Result was fetched from the database and stored in the transaction's in-memory query cache only,
		 * because the request asked for the transaction scope.
		 */
		MEMORY_STORED,

		/**
		 * @description Result of a user-mode read was fetched from the database and stored in the transaction's
		 * in-memory query cache only, because user-mode results never go to Platform Cache.
		 */
		MEMORY_STORED_USER_MODE,

		/**
		 * @description Result was fetched from the database and stored in the transaction's in-memory query cache only,
		 * because no Platform Cache partition kept it.
		 */
		MEMORY_STORED_NO_PARTITION,

		/**
		 * @description Result was fetched from the database and stored in no cache, because a system-mode read with
		 * inherited sharing depends on the caller's sharing context.
		 */
		DECLINED_INHERITED_SHARING,

		/**
		 * @description Not cached: the result has more rows than the in-memory query cache keeps for one read. Reported
		 * only for a read that memory alone could keep (a user-mode read, a transaction-scope read, or a read no Platform
		 * Cache partition kept), so neither store holds it.
		 */
		DECLINED_ROW_CAP,

		/**
		 * @description Not cached: heap use stayed at or over the in-memory cache's guard after evicting every older
		 * entry. Reported only for a read that memory alone could keep (a user-mode read, a transaction-scope read, or a
		 * read no Platform Cache partition kept), so neither store holds it.
		 */
		DECLINED_HEAP_GUARD,

		/**
		 * @description Not cached: an aggregate query is never kept in memory. Reported only for a read that memory alone
		 * could keep (a user-mode read, a transaction-scope read, or a read no Platform Cache partition kept), so neither
		 * store holds it. Platform Cache, where a partition keeps it, still keeps a system-mode aggregate read.
		 */
		DECLINED_AGGREGATE,

		/**
		 * @description Not cached: a query with a child subquery is never kept in memory, because copying its rows would share the child records between
		 * callers. Platform Cache, which serializes, still keeps it.
		 */
		DECLINED_CHILD_SUBQUERY
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
	 * @description The mock records a test registered, by SObjectType, so that tests do not depend on real data.
	 * It stays `null` until a test writes to it through `setMock`, so production code, where no mocks are
	 * registered, never creates it. The checks that only read it (`hasMock`, `getMock`, `clearMocks`) handle the
	 * null value instead of creating the map.
	 */
	@TestVisible
	private static Map<SObjectType, List<SObject>> mockRegistry;

	/**
	 * @description The FormulaEval context class name for each SObjectType, used to filter mock records by the
	 * query's conditions. The map is created only when a context class is registered.
	 */
	@TestVisible
	private static Map<SObjectType, String> mockContextRegistry;

	/**
	 * @description The exceptions to throw when a specific SObjectType is queried. Tests use it to reach the error
	 * paths, so subscribers can test their catch blocks without mocking anything else. Filled by setMockException;
	 * emptied by clearMockException, clearMockExceptions or clearMocks. It stays `null` in production, so each
	 * query through `validateAndApplyMockException` costs only one null check, and no map is created.
	 */
	@TestVisible
	private static Map<SObjectType, Exception> mockExceptionRegistry;

	/**
	 * @description The exceptions to throw only when an AGGREGATE query (one with aggregate functions or a GROUP BY)
	 * runs against a specific SObjectType. A test can then make an aggregate query fail while row queries against
	 * the same SObjectType still succeed. This is how a test proves that a caller handles a failed aggregate query
	 * on its own, without losing every read of the object. setMockException, which covers the whole SObjectType,
	 * cannot fail one kind of query and not the other. Filled by setMockAggregateException; emptied by
	 * clearMockException, clearMockExceptions or clearMocks. It stays `null` in production, so each query costs only
	 * one null check.
	 */
	@TestVisible
	private static Map<SObjectType, Exception> mockAggregateExceptionRegistry;

	/**
	 * @description A queue of answers for each SObjectType. Each answer is returned to exactly one row query or count
	 * against its type, in the order the answers were added, and is then removed. The queue is checked before
	 * `mockRegistry`. So inside one transaction a test can make the first read find nothing and the second read find
	 * the row. Once the queue is empty, the type behaves as if nothing had been queued. Filled by queueMock; emptied
	 * by clearMockQueue, clearMockQueues or clearMocks. It is never created in production and stays `null` there, so
	 * each query costs only one null check.
	 */
	private static Map<SObjectType, List<List<SObject>>> mockQueueRegistry;

	/**
	 * @description The rows a test set, by SObjectType, to answer every aggregate query (a query with aggregate
	 * functions or a GROUP BY) against that type. Each map is one row, keyed by the aliases the query selects. These
	 * rows never answer a row query, and record mocks never answer an aggregate query. Filled by setAggregateMock and
	 * addAggregateMock; emptied by clearAggregateMock, clearAggregateMocks or clearMocks. It stays `null` in
	 * production, so an aggregate query costs only one null check here.
	 */
	private static Map<SObjectType, List<Map<String, Object>>> aggregateMockRegistry;

	/**
	 * @description A queue of aggregate answers for each SObjectType. Each answer is returned to exactly one aggregate
	 * query against its type, in the order the answers were added, and is then removed. The queue is checked before
	 * `aggregateMockRegistry`. Filled by queueAggregateMock; emptied by clearAggregateMock, clearAggregateMocks or
	 * clearMocks. It stays `null` in production, so an aggregate query costs only one null check here.
	 */
	private static Map<SObjectType, List<List<Map<String, Object>>>> aggregateMockQueueRegistry;

	/**
	 * @description Returns how many pagination-cursor rows THIS transaction can still use. The governor limit
	 * applies to the whole transaction and is shared by every pagination cursor opened in it. So a second paged read
	 * has only what the first one left, not the full allowance.
	 *
	 * @return The remaining pagination-cursor row allowance; zero or less when it is spent.
	 */
	private static Integer getPaginationCursorRowHeadroom()
	{
		UTIL_Limits.LimitCheck paginationCursorRows = UTIL_Limits.apexPaginationCursorRows();
		Integer ceiling = paginationCursorRowLimitOverride ?? paginationCursorRows.maximum();
		return ceiling - paginationCursorRows.used();
	}

	/**
	 * @description Returns the LIMIT for a pagination guard query, the count that runs before a pagination cursor is
	 * opened. The LIMIT is one more than the rows this transaction has left. That is the smallest number that still
	 * tells "exactly at the limit" (a pagination cursor may be opened) apart from "over it" (opening one would fail
	 * the transaction). It also keeps the guard's cost the same every time: a COUNT() with a LIMIT stops counting at
	 * the LIMIT, so it uses one query row however many rows match.
	 *
	 * @return The LIMIT to place on a pagination guard query, never below 1.
	 */
	public static Integer getPaginationGuardRowLimit()
	{
		return Math.max(getPaginationCursorRowHeadroom(), 0) + 1;
	}

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
	 * @description Lazy-initializer for `mockAggregateExceptionRegistry`. Allocates the backing map on first write.
	 *
	 * @return The initialized registry instance.
	 */
	private static Map<SObjectType, Exception> ensureMockAggregateExceptionRegistry()
	{
		if(mockAggregateExceptionRegistry == null)
		{
			mockAggregateExceptionRegistry = new Map<SObjectType, Exception>();
		}
		return mockAggregateExceptionRegistry;
	}

	/**
	 * @description Lazy-initializer for `mockQueueRegistry`. Allocates the backing map on first write.
	 *
	 * @return The initialized registry instance.
	 */
	private static Map<SObjectType, List<List<SObject>>> ensureMockQueueRegistry()
	{
		if(mockQueueRegistry == null)
		{
			mockQueueRegistry = new Map<SObjectType, List<List<SObject>>>();
		}
		return mockQueueRegistry;
	}

	/**
	 * @description Lazy-initializer for `aggregateMockRegistry`. Allocates the backing map on first write.
	 *
	 * @return The initialized registry instance.
	 */
	private static Map<SObjectType, List<Map<String, Object>>> ensureAggregateMockRegistry()
	{
		if(aggregateMockRegistry == null)
		{
			aggregateMockRegistry = new Map<SObjectType, List<Map<String, Object>>>();
		}
		return aggregateMockRegistry;
	}

	/**
	 * @description Lazy-initializer for `aggregateMockQueueRegistry`. Allocates the backing map on first write.
	 *
	 * @return The initialized registry instance.
	 */
	private static Map<SObjectType, List<List<Map<String, Object>>>> ensureAggregateMockQueueRegistry()
	{
		if(aggregateMockQueueRegistry == null)
		{
			aggregateMockQueueRegistry = new Map<SObjectType, List<List<Map<String, Object>>>>();
		}
		return aggregateMockQueueRegistry;
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
	 * @description Clears all registered mocks, mock context classes, mock exceptions, queued answers and aggregate
	 * answers. It skips the maps that were never created, so production callers pay only seven null checks.
	 */
	public static void clearMocks()
	{
		mockRegistry?.clear();
		mockContextRegistry?.clear();
		mockExceptionRegistry?.clear();
		mockAggregateExceptionRegistry?.clear();
		mockQueueRegistry?.clear();
		clearAggregateMocks();
	}

	/**
	 * @description Registers an Exception to be thrown the next time a query is executed
	 * against the specified SObjectType. Tests use it to reach error paths, so subscribers can
	 * test their catch blocks around a SOQL call without mocking anything else.
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
	 * @description Registers an Exception to be thrown only when an AGGREGATE query (aggregate functions
	 * or a GROUP BY) runs against the specified SObjectType; row queries against the same SObjectType
	 * still run for real. Tests use it for callers that run an aggregate query next to row queries of the
	 * same object and handle a failure of each one on its own. setMockException, which covers the whole
	 * SObjectType, fails both kinds at once, so it cannot prove that one keeps working when the other fails.
	 *
	 * @param objectType The SObjectType whose aggregate queries should throw.
	 * @param exceptionToThrow The exception instance to throw. May not be null.
	 *
	 * @throws IllegalArgumentException When objectType or exceptionToThrow is null.
	 */
	public static void setMockAggregateException(SObjectType objectType, Exception exceptionToThrow)
	{
		if(objectType == null)
		{
			throw new IllegalArgumentException('SObjectType cannot be null');
		}
		if(exceptionToThrow == null)
		{
			throw new IllegalArgumentException('Exception cannot be null');
		}
		ensureMockAggregateExceptionRegistry().put(objectType, exceptionToThrow);
	}

	/**
	 * @description Removes any registered exception, for all queries and for aggregate queries only, for the
	 * specified SObjectType. Does nothing when a map was never created.
	 *
	 * @param objectType The SObjectType whose registered exceptions (if any) are cleared.
	 */
	public static void clearMockException(SObjectType objectType)
	{
		mockExceptionRegistry?.remove(objectType);
		mockAggregateExceptionRegistry?.remove(objectType);
	}

	/**
	 * @description Removes all registered mock exceptions, for all queries and for aggregate queries only,
	 * across every SObjectType. TST_Mock.clear() uses it to empty the exception maps.
	 * Does nothing when a map was never created.
	 */
	public static void clearMockExceptions()
	{
		mockExceptionRegistry?.clear();
		mockAggregateExceptionRegistry?.clear();
	}

	/**
	 * @description Adds one answer to the queue for the specified SObjectType: the next row query or count against
	 * the type returns exactly these records and removes the answer from the queue. Answers are used in the order
	 * they were added. They are checked after any registered exception and before the records registered with
	 * setMock, so once the queue is empty the type behaves as if nothing had been queued. An empty list means the
	 * next query finds nothing.
	 *
	 * @param objectType The SObjectType to set the next answer for.
	 * @param mocks The records the next query returns. May be empty; may not be null.
	 *
	 * @throws IllegalArgumentException When objectType is null, when mocks is null, or when a record is of another type.
	 */
	public static void queueMock(SObjectType objectType, List<SObject> mocks)
	{
		if(objectType == null)
		{
			throw new IllegalArgumentException('SObjectType cannot be null');
		}
		if(mocks == null)
		{
			throw new IllegalArgumentException(QUEUED_ANSWER_NULL_MESSAGE);
		}
		validateMockRecords(objectType, mocks);
		Map<SObjectType, List<List<SObject>>> registry = ensureMockQueueRegistry();
		if(!registry.containsKey(objectType))
		{
			registry.put(objectType, new List<List<SObject>>());
		}
		registry.get(objectType).add(mocks);
	}

	/**
	 * @description Removes and returns the next queued answer for the specified SObjectType, or null when nothing
	 * is queued. It never creates the map.
	 *
	 * @param objectType The SObjectType whose next answer is taken.
	 *
	 * @return The next queued answer, or null when the queue is empty.
	 */
	private static List<SObject> takeQueuedMock(SObjectType objectType)
	{
		List<List<SObject>> queue = mockQueueRegistry?.get(objectType);
		if(queue == null || queue.isEmpty())
		{
			return null;
		}
		return queue.remove(0);
	}

	/**
	 * @description Checks whether at least one record answer is queued for the specified SObjectType, without taking
	 * it. It never creates the map.
	 *
	 * @param objectType The SObjectType to check.
	 *
	 * @return True when a queued record answer is waiting for the type.
	 */
	private static Boolean hasQueuedMock(SObjectType objectType)
	{
		return mockQueueRegistry?.get(objectType)?.isEmpty() == false;
	}

	/**
	 * @description Drops every queued answer for the specified SObjectType. Does nothing when the
	 * map was never created.
	 *
	 * @param objectType The SObjectType whose queued answers (if any) are dropped.
	 */
	public static void clearMockQueue(SObjectType objectType)
	{
		mockQueueRegistry?.remove(objectType);
	}

	/**
	 * @description Drops every queued answer across every SObjectType. TST_Mock.clear() uses it, together with
	 * the methods that empty the exception maps. Does nothing when the map was never created.
	 */
	public static void clearMockQueues()
	{
		mockQueueRegistry?.clear();
	}

	/**
	 * @description Sets the rows that answer every aggregate query (a query with aggregate functions or a GROUP BY)
	 * against the specified SObjectType, until they are cleared. Each map is one row, keyed by the aliases the query
	 * selects. Rows set here replace any set or added earlier for the type; addAggregateMock adds to them instead.
	 * They never answer a row query.
	 *
	 * @param objectType The SObjectType whose aggregate queries the rows answer.
	 * @param rows The rows to return, in this order. Null removes the rows set for the type.
	 *
	 * @throws IllegalArgumentException When objectType is null.
	 */
	public static void setAggregateMock(SObjectType objectType, List<Map<String, Object>> rows)
	{
		if(objectType == null)
		{
			throw new IllegalArgumentException('SObjectType cannot be null');
		}
		if(rows == null)
		{
			aggregateMockRegistry?.remove(objectType);
		}
		else
		{
			ensureAggregateMockRegistry().put(objectType, rows);
		}
	}

	/**
	 * @description Adds rows after the rows that already answer every aggregate query against the specified
	 * SObjectType, the rows set with setAggregateMock or added here earlier. One aggregate query then returns all of
	 * them, the first added first. The rows are kept in a new list, so a later change to the caller's list, or to a
	 * list given to setAggregateMock before, does not change the rows that answer. An empty list adds nothing; when no
	 * rows were set for the type yet, it makes every aggregate query against the type find nothing.
	 *
	 * @param objectType The SObjectType whose aggregate queries the rows answer.
	 * @param rows The rows to add, in this order. May be empty; may not be null.
	 *
	 * @throws IllegalArgumentException When objectType or rows is null.
	 */
	public static void addAggregateMock(SObjectType objectType, List<Map<String, Object>> rows)
	{
		if(objectType == null)
		{
			throw new IllegalArgumentException('SObjectType cannot be null');
		}
		if(rows == null)
		{
			throw new IllegalArgumentException(ADDED_AGGREGATE_ROWS_NULL_MESSAGE);
		}
		Map<SObjectType, List<Map<String, Object>>> registry = ensureAggregateMockRegistry();
		List<Map<String, Object>> combinedRows = new List<Map<String, Object>>();
		if(registry.containsKey(objectType))
		{
			combinedRows.addAll(registry.get(objectType));
		}
		combinedRows.addAll(rows);
		registry.put(objectType, combinedRows);
	}

	/**
	 * @description Adds one answer to the queue of aggregate answers for the specified SObjectType: the next aggregate
	 * query against the type returns exactly these rows, and the answer is then removed from the queue. Answers are
	 * used in the order they were added, before the rows set with setAggregateMock. An empty list means the next
	 * aggregate query finds nothing.
	 *
	 * @param objectType The SObjectType to set the next aggregate answer for.
	 * @param rows The rows the next aggregate query returns. May be empty; may not be null.
	 *
	 * @throws IllegalArgumentException When objectType or rows is null.
	 */
	public static void queueAggregateMock(SObjectType objectType, List<Map<String, Object>> rows)
	{
		if(objectType == null)
		{
			throw new IllegalArgumentException('SObjectType cannot be null');
		}
		if(rows == null)
		{
			throw new IllegalArgumentException(QUEUED_ANSWER_NULL_MESSAGE);
		}
		Map<SObjectType, List<List<Map<String, Object>>>> registry = ensureAggregateMockQueueRegistry();
		if(!registry.containsKey(objectType))
		{
			registry.put(objectType, new List<List<Map<String, Object>>>());
		}
		registry.get(objectType).add(rows);
	}

	/**
	 * @description Removes and returns the next queued aggregate answer for the specified SObjectType, or null when
	 * nothing is queued. It never creates the map.
	 *
	 * @param objectType The SObjectType whose next aggregate answer is taken.
	 *
	 * @return The next queued aggregate rows, or null when the queue is empty.
	 */
	private static List<Map<String, Object>> takeQueuedAggregateMock(SObjectType objectType)
	{
		List<List<Map<String, Object>>> queue = aggregateMockQueueRegistry?.get(objectType);
		if(queue == null || queue.isEmpty())
		{
			return null;
		}
		return queue.remove(0);
	}

	/**
	 * @description Removes every aggregate answer, the rows set with setAggregateMock and the queued ones, across
	 * every SObjectType. clearMocks calls it. Does nothing when a map was never created.
	 */
	public static void clearAggregateMocks()
	{
		aggregateMockRegistry?.clear();
		aggregateMockQueueRegistry?.clear();
	}

	/**
	 * @description Removes the aggregate answers for the specified SObjectType: the rows set with setAggregateMock and
	 * the queued ones. Other types keep theirs. Does nothing when a map was never created.
	 *
	 * @param objectType The SObjectType whose aggregate answers are removed.
	 */
	public static void clearAggregateMock(SObjectType objectType)
	{
		aggregateMockRegistry?.remove(objectType);
		aggregateMockQueueRegistry?.remove(objectType);
	}

	/**
	 * @description Returns the registered mock exception for the specified SObjectType,
	 * or null when no exception is registered. It never creates the map.
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
	 * @description Returns the mock exception registered for aggregate queries only on the specified SObjectType,
	 * or null when no exception is registered. It never creates the map.
	 *
	 * @param objectType The SObjectType to look up.
	 *
	 * @return The registered Exception, or null when none is registered.
	 */
	public static Exception getMockAggregateException(SObjectType objectType)
	{
		return mockAggregateExceptionRegistry?.get(objectType);
	}

	/**
	 * @description Validates query parameters and rethrows any registered mock exception
	 * for the target SObjectType. execute(), executeCount() and getQueryLocator() all call it first, so the null
	 * check and the order of the exception checks are written in one place.
	 *
	 * In production the exception map is `null`, so on this path, which every query takes, the only cost is the
	 * null check of the parameters and one more null check: no map lookup and no new object.
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

		if(parameters.aggregateQuery == true)
		{
			Exception aggregateRegistered = mockAggregateExceptionRegistry?.get(parameters.objectType);
			if(aggregateRegistered != null)
			{
				throw aggregateRegistered;
			}
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
	 * @description Checks whether aggregate rows will answer the next aggregate query on a specific SObjectType: rows
	 * set with setAggregateMock or added with addAggregateMock, or at least one queued aggregate answer. It only looks: it never takes a queued answer
	 * and never creates a map.
	 *
	 * @param objectType The SObjectType to check.
	 *
	 * @return True when aggregate rows are registered for this type, standing or queued.
	 */
	public static Boolean hasAggregateMock(SObjectType objectType)
	{
		return aggregateMockRegistry?.containsKey(objectType) == true || aggregateMockQueueRegistry?.get(objectType)?.isEmpty() == false;
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
	 * @description Executes a query and returns results. A test can answer the query without the database. The answer
	 * is chosen in this order:
	 * 1. A registered exception is thrown.
	 * 2. For an aggregate query, a queued aggregate answer, then the aggregate rows set with setAggregateMock or added
	 *    with addAggregateMock. When
	 *    neither exists but a record mock or a queued record answer does, the query throws, because record mocks never
	 *    answer an aggregate query. The queued record answer is left for the next row query.
	 * 3. For a row query, a queued record answer, then the records set with setMock.
	 * 4. Otherwise the database answers.
	 *
	 * @param parameters The query parameters.
	 *
	 * @return Query result containing records and metadata.
	 *
	 * @throws UTIL_Exceptions.IllegalStateException When an aggregate query finds record mocks but no aggregate rows.
	 */
	public static QueryResult execute(QueryParameters parameters)
	{
		validateAndApplyMockException(parameters);

		if(parameters.aggregateQuery == true)
		{
			List<Map<String, Object>> aggregateRows = takeQueuedAggregateMock(parameters.objectType);
			if(aggregateRows == null)
			{
				aggregateRows = aggregateMockRegistry?.get(parameters.objectType);
			}
			if(aggregateRows != null)
			{
				return executeAggregateMock(parameters, aggregateRows);
			}
			if(hasMock(parameters.objectType) || hasQueuedMock(parameters.objectType))
			{
				String message = String.format(AGGREGATE_QUERY_WITHOUT_AGGREGATE_MOCK_MESSAGE, new List<String> {String.valueOf(parameters.objectType)});
				throw new UTIL_Exceptions.IllegalStateException(message);
			}
			return executeQuery(parameters);
		}

		List<SObject> queuedAnswer = takeQueuedMock(parameters.objectType);
		if(queuedAnswer != null)
		{
			return executeMock(parameters, queuedAnswer);
		}
		if(hasMock(parameters.objectType))
		{
			return executeMock(parameters, getMock(parameters.objectType));
		}

		return executeQuery(parameters);
	}

	/**
	 * @description Counts the matching records. In a test, a mock exception registered for the object is thrown first, and
	 * registered mock records answer with their number, so no query runs. Otherwise one COUNT() query runs. Null parameters throw IllegalArgumentException.
	 *
	 * @param parameters The query parameters.
	 *
	 * @return The count of matching records.
	 */
	public static Integer executeCount(QueryParameters parameters)
	{
		validateAndApplyMockException(parameters);

		List<SObject> queuedAnswer = takeQueuedMock(parameters.objectType);
		if(queuedAnswer != null)
		{
			return queuedAnswer.size();
		}
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
		Map<String, Object> bindMap = parameters.bindMap ?? new Map<String, Object>();

		// Sent through the same sharing executors as a row query and a count. A locator built directly here
		// would use whatever sharing the caller happens to have, and quietly ignore the builder's sharing setting
		// for a whole batch job, which is where a caller most needs both the sharing and the access setting.
		Database.QueryLocator locator;
		if(parameters.enforceSharing == true)
		{
			locator = new WithSharingExecutor().locator(parameters, accessLevel, bindMap);
		}
		else if(parameters.enforceSharing == false)
		{
			locator = new WithoutSharingExecutor().locator(parameters, accessLevel, bindMap);
		}
		else
		{
			locator = doLocator(parameters.queryString, accessLevel, bindMap);
		}

		stopTimer(timer, parameters, CacheStatus.BYPASS, null);

		return locator;
	}

	/**
	 * @description Opens a Database.Cursor for deferred traversal of a large result set.
	 *
	 * @param parameters The query parameters.
	 *
	 * @return A cursor whose later fetches read the rows that the sharing setting allows.
	 */
	public static Database.Cursor getCursor(QueryParameters parameters)
	{
		validateAndApplyMockException(parameters);

		UTIL_QueryPerformanceTimer timer = createPerformanceTimer(parameters, 'Cursor');

		AccessLevel accessLevel = parameters.userMode ? AccessLevel.USER_MODE : AccessLevel.SYSTEM_MODE;
		Map<String, Object> bindMap = parameters.bindMap ?? new Map<String, Object>();

		// Sent through the same sharing executors as a row query, a count and a locator. A cursor fixes its
		// set of rows when it is created, so building it directly here would lock the caller's own sharing
		// into every later fetch (in this transaction or a later one), while the bypass audit still
		// records the bypass the builder asked for.
		Database.Cursor cursor;
		if(parameters.enforceSharing == true)
		{
			cursor = new WithSharingExecutor().cursor(parameters, accessLevel, bindMap);
		}
		else if(parameters.enforceSharing == false)
		{
			cursor = new WithoutSharingExecutor().cursor(parameters, accessLevel, bindMap);
		}
		else
		{
			cursor = doCursor(parameters.queryString, accessLevel, bindMap);
		}

		stopTimer(timer, parameters, CacheStatus.BYPASS, null);

		return cursor;
	}

	/**
	 * @description Executes a query using mocks. When a FormulaEval context class is available
	 * and conditions are present, filters mock records in memory using UTIL_FormulaFilter.
	 *
	 * @param parameters The query parameters.
	 * @param mocks The records to return: the standing registration, or one queued answer.
	 *
	 * @return Query result with mock data.
	 */
	@SuppressWarnings('PMD.CognitiveComplexity')
	private static QueryResult executeMock(QueryParameters parameters, List<SObject> mocks)
	{
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
	 * @description Answers an aggregate query from registered aggregate rows. The rows come back in the order they were
	 * registered and are never filtered, sorted or paged. Only the query's LIMIT applies: it keeps the first rows. The
	 * result counts as mocked, holds no records, and its total is the number of rows returned. Each call returns a new
	 * list, so a test that adds or removes a row in one result does not change the registered rows or the next result.
	 *
	 * @param parameters The query parameters.
	 * @param rows The aggregate rows to return: the standing ones, or one queued answer.
	 *
	 * @return Query result with the aggregate rows in `aggregateRows`.
	 */
	private static QueryResult executeAggregateMock(QueryParameters parameters, List<Map<String, Object>> rows)
	{
		Integer rowsToReturn = parameters.limitCount != null && rows.size() > parameters.limitCount ? parameters.limitCount : rows.size();
		List<Map<String, Object>> returnedRows = new List<Map<String, Object>>();
		for(Integer index = 0; index < rowsToReturn; index++)
		{
			returnedRows.add(rows[index]);
		}

		QueryResult result = new QueryResult();
		result.aggregateRows = returnedRows;
		result.totalRecords = returnedRows.size();
		result.isMocked = true;
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
		 * @description Keeps the ORDER BY fields in the order given. The first field decides the order, and each later field
		 * only breaks ties.
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
	 * @description Executes the actual database query, reading from and storing in a cache when the request asks for
	 * one. The steps, in order:
	 * - Decide whether caching is declined (see resolveDeclinedStatus): a read shape that is never cached, or a system-mode
	 * read whose sharing is left to the calling class.
	 * - Pick the stores. A user-mode read and a transaction-scope read use memory only; any other read uses the
	 * Platform Cache store for its scope, with memory as the fall-back.
	 * - Unless the request skips cached reads, look in memory first, then in Platform Cache, and return a copy of
	 * what is found.
	 * - Otherwise run the query under the requested access mode and sharing.
	 * - Store the rows (see storeResult) and report where they went, or why they went nowhere.
	 *
	 * @param parameters The query parameters.
	 *
	 * @return Query result with database records.
	 */
	private static QueryResult executeQuery(QueryParameters parameters)
	{
		UTIL_QueryPerformanceTimer timer = createPerformanceTimer(parameters, 'Query');

		CacheStatus declined = resolveDeclinedStatus(parameters);
		Boolean useCache = parameters.cacheScope != null && declined == null;
		Boolean memoryOnly = useCache && (parameters.userMode || parameters.cacheScope == UTIL_Cache.Scope.IN_TRANSACTION);
		String durableKey = useCache && !memoryOnly ? generateCacheKey(parameters) : null;
		String memoryKey = useCache ? generateTransactionCacheKey(parameters) : null;

		if(useCache && !parameters.bypassCache)
		{
			QueryResult cachedResult = getCopyFromMemoryCache(memoryKey);
			CacheStatus hitStatus = CacheStatus.MEMORY_HIT;
			if(cachedResult == null && durableKey != null)
			{
				cachedResult = getFromCache(parameters.cacheScope, durableKey);
				hitStatus = CacheStatus.HIT;
			}
			if(cachedResult != null)
			{
				cachedResult.cacheStatus = hitStatus;
				cachedResult.queryDurationMs = stopTimer(timer, parameters, hitStatus, cachedResult.records.size());
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

		result.cacheStatus = useCache ? storeResult(parameters, durableKey, memoryKey, result) : (declined ?? CacheStatus.BYPASS);
		result.queryDurationMs = stopTimer(timer, parameters, result.cacheStatus, result.records.size());
		return result;
	}

	/**
	 * @description Says why a caching request is declined, or returns null when it is not declined or nothing was
	 * requested. A request is declined when:
	 * - the read shape is never cached: random results, a row lock (FOR UPDATE, REFERENCE or VIEW), ALL ROWS, which
	 * may include deleted rows, or a cursor-backed read (getPage or random sampling), because a hit restores only the
	 * record list, never the total or the cursor;
	 * - a system-mode read leaves its sharing to the calling class, which the engine cannot see when it builds the key:
	 * the same user's read from a without-sharing class and from a with-sharing class would share one key while
	 * returning different rows. A user-mode read is not declined, because the platform applies the user's sharing.
	 * An aggregate query or a query with a child subquery is not declined here: storeResult refuses to keep it in
	 * memory, whichever way the read reached memory.
	 *
	 * @param parameters The query parameters.
	 *
	 * @return BYPASS or DECLINED_INHERITED_SHARING, or null.
	 */
	private static CacheStatus resolveDeclinedStatus(QueryParameters parameters)
	{
		if(parameters.cacheScope == null)
		{
			return null;
		}
		if(parameters.randomResults || parameters.lockForUpdate || parameters.lockForReference || parameters.lockForView
				|| parameters.includeAllRows || parameters.cursorMode != null)
		{
			return CacheStatus.BYPASS;
		}
		if(parameters.enforceSharing == null && !parameters.userMode)
		{
			return CacheStatus.DECLINED_INHERITED_SHARING;
		}
		return null;
	}

	/**
	 * @description Stores the rows in Platform Cache where the scope keeps them, otherwise in memory. A read reaches
	 * memory either because memory is the only store it may use (a user-mode read or a transaction-scope read) or
	 * because no Platform Cache partition kept it. Either way, an aggregate query or a query with a child subquery is
	 * never kept in memory: it is reported as DECLINED_AGGREGATE or DECLINED_CHILD_SUBQUERY instead.
	 *
	 * @param parameters The query parameters.
	 * @param durableKey The Platform Cache key, or null when the read may use memory only.
	 * @param memoryKey The in-memory key.
	 * @param result The result the caller receives.
	 *
	 * @return STORED, MEMORY_STORED, MEMORY_STORED_USER_MODE or MEMORY_STORED_NO_PARTITION when the rows were kept,
	 * otherwise the reason they were not.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static CacheStatus storeResult(QueryParameters parameters, String durableKey, String memoryKey, QueryResult result)
	{
		if(durableKey != null && storeInCache(parameters.cacheScope, durableKey, result, parameters.cacheTTL))
		{
			return CacheStatus.STORED;
		}
		if(parameters.aggregateQuery)
		{
			return CacheStatus.DECLINED_AGGREGATE;
		}
		if(containsChildSubquery(normalizeQuery(parameters.queryString)))
		{
			return CacheStatus.DECLINED_CHILD_SUBQUERY;
		}
		CacheStatus storedStatus = parameters.userMode ? CacheStatus.MEMORY_STORED_USER_MODE
				: (durableKey != null ? CacheStatus.MEMORY_STORED_NO_PARTITION : CacheStatus.MEMORY_STORED);
		return storeCopyInMemoryCache(memoryKey, result.records, storedStatus);
	}

	/**
	 * @description Upper-cases and space-normalises a query, the form every cache key and every query-text check reads.
	 *
	 * @param queryString The query, as built.
	 *
	 * @return The normalised query, or null when there is no query.
	 */
	@TestVisible
	private static String normalizeQuery(String queryString)
	{
		return queryString?.toUpperCase()?.normalizeSpace();
	}

	/**
	 * @description Builds the part every cache key starts with: the normalised query and the bind map.
	 *
	 * @param parameters The query parameters.
	 *
	 * @return The shared start of a cache key.
	 */
	private static String buildBaseCacheKey(QueryParameters parameters)
	{
		String bindMapString = parameters.bindMap != null ? JSON.serialize(parameters.bindMap) : '';
		return 'QRY:' + normalizeQuery(parameters.queryString) + ':' + bindMapString;
	}

	/**
	 * @description Generates the Platform Cache key from the query string, the bind map, the sharing setting and,
	 * wherever the result depends on who ran it, the running user. The sharing setting is always explicit by the time
	 * this key is built, because resolveDeclinedStatus refuses a system-mode read with inherited sharing, and a
	 * user-mode read never reaches Platform Cache. A result read with sharing enforced depends on who ran it, so its
	 * key includes the user. A result read without sharing is shared by every caller in the org only when its rows
	 * and values are the same for everyone. A read without sharing that the platform works out for the running user
	 * also includes the user in its key. Without these parts of the key, one user's result could be shown to another
	 * user, who might not be allowed to see it.
	 *
	 * @param parameters The query parameters.
	 *
	 * @return A cache key string.
	 */
	@TestVisible
	private static String generateCacheKey(QueryParameters parameters)
	{
		String sharingSegment = parameters.enforceSharing ? CACHE_KEY_SHARING_ENFORCED : CACHE_KEY_SHARING_BYPASSED;
		Boolean sharedByEveryUser = parameters.enforceSharing == false && !containsUserDependentKeyword(normalizeQuery(parameters.queryString));
		String userSegment = sharedByEveryUser ? '' : ':USER=' + UserInfo.getUserId();
		return buildBaseCacheKey(parameters) + ':SHARING=' + sharingSegment + userSegment;
	}

	/**
	 * @description Generates the in-memory key: the Platform Cache key's parts plus the access mode and, always, the
	 * running user, so a result is never served to another user or to a read in another access mode. Inherited sharing
	 * reaches here only for user-mode reads, where the platform applies the user's sharing, so its key says enforced.
	 *
	 * @param parameters The query parameters.
	 *
	 * @return The in-memory cache key.
	 */
	private static String generateTransactionCacheKey(QueryParameters parameters)
	{
		Boolean sharingEnforced = parameters.enforceSharing ?? true;
		String sharingSegment = sharingEnforced ? CACHE_KEY_SHARING_ENFORCED : CACHE_KEY_SHARING_BYPASSED;
		String accessSegment = parameters.userMode ? CACHE_KEY_ACCESS_USER : CACHE_KEY_ACCESS_SYSTEM;
		return buildBaseCacheKey(parameters) + ':SHARING=' + sharingSegment + ':ACCESS=' + accessSegment + ':USER=' + UserInfo.getUserId();
	}

	/**
	 * @description Returns this transaction's Platform Cache store for a scope, building it on first use: the session
	 * store for SESSION, the org store for ORG, and the automatic store, session then org, for any other scope.
	 *
	 * @param scope The requested cache scope.
	 *
	 * @return The store for the scope.
	 */
	private static UTIL_Cache.Store getDurableStore(UTIL_Cache.Scope scope)
	{
		UTIL_Cache.Store store = DURABLE_STORE_BY_SCOPE.get(scope);
		if(store == null)
		{
			store = scope == UTIL_Cache.Scope.SESSION ? UTIL_Cache.session() : scope == UTIL_Cache.Scope.ORG ? UTIL_Cache.org() : UTIL_Cache.auto();
			DURABLE_STORE_BY_SCOPE.put(scope, store);
		}
		return store;
	}

	/**
	 * @description Tells whether a query contains a SOQL keyword the platform evaluates for the running user, so its
	 * rows or values can differ by user even with sharing bypassed: a scope relative to the user, a function that
	 * translates, formats or converts a value for the user, or a date literal read in the user's time zone. Read from
	 * the whole query, so subqueries, filters, grouping and ordering all count, as do
	 * raw strings added to any of them. A string literal that holds one of these keywords counts too; that costs a
	 * per-user entry, never a wrong hit.
	 *
	 * @param normalizedQuery The query, upper-cased and space-normalised.
	 *
	 * @return True when the query must be cached per user.
	 */
	private static Boolean containsUserDependentKeyword(String normalizedQuery)
	{
		return normalizedQuery != null
				&& (USER_DEPENDENT_FUNCTION.matcher(normalizedQuery).find()
				|| USER_DEPENDENT_SCOPE.matcher(normalizedQuery).find()
				|| USER_DEPENDENT_DATE_LITERAL.matcher(normalizedQuery).find());
	}

	/**
	 * @description Says whether the query has a child subquery, wherever it came from: a builder subselect or a raw string
	 * added as a field. A semi-join in a WHERE clause is not a child subquery, and neither is text inside a quoted literal.
	 *
	 * @param normalizedQuery The query, upper-cased and space-normalised.
	 *
	 * @return True when the query has a child subquery
	 */
	@TestVisible
	private static Boolean containsChildSubquery(String normalizedQuery)
	{
		return normalizedQuery != null && CHILD_SUBQUERY.matcher(QUOTED_LITERAL.matcher(normalizedQuery).replaceAll('\'\'')).find();
	}

	/**
	 * @description Attempts to retrieve a cached query result from the Platform Cache store for the scope.
	 *
	 * @param scope The requested cache scope.
	 * @param cacheKey The cache key.
	 *
	 * @return Cached QueryResult or null if not found/expired.
	 */
	private static QueryResult getFromCache(UTIL_Cache.Scope scope, String cacheKey)
	{
		Object cached = getDurableStore(scope).get(cacheKey);

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
	 * @description Stores query results in the Platform Cache store for the scope.
	 *
	 * @param scope The requested cache scope.
	 * @param cacheKey The cache key.
	 * @param result The query result to cache.
	 * @param ttlSeconds The time-to-live in seconds; null or zero uses DEFAULT_CACHE_TTL.
	 *
	 * @return True when a partition kept the rows, false when the scope keeps nothing.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static Boolean storeInCache(UTIL_Cache.Scope scope, String cacheKey, QueryResult result, Integer ttlSeconds)
	{
		Integer effectiveTimeToLive = (ttlSeconds == null || ttlSeconds == 0) ? DEFAULT_CACHE_TTL : ttlSeconds;
		return getDurableStore(scope).put(cacheKey, result.records, effectiveTimeToLive);
	}

	/**
	 * @description Empties the in-memory query cache, so no read after a write gets rows from before it. It is called at
	 * the start and at the end of every DML_Transaction commit attempt, after API_Base's safe-mode rollback, and before
	 * the raw inserts of FLOW_SendEmailInternal.handleActivityLogging and of the test data factory (TST_Factory).
	 *
	 * Any code path that writes to the database on the framework's behalf must either commit through DML_Transaction
	 * (every commit reaches the step that empties the cache) or call this method before its write and say why in its
	 * own ApexDoc. FLOW_SendEmailInternal and TST_Factory are the two direct callers outside the commit path. The one
	 * recorded exception is TRG_PersistLogEntry: its flood-control rows are written with raw Database DML and do not
	 * empty the cache, because a log can be saved in the middle of a transaction, so clearing there would empty every
	 * cache on each flush, and the framework caches no LogEntry__c read.
	 */
	public static void clearQueryResultMemoryCache()
	{
		QUERY_RESULT_MEMORY_CACHE.clear();
	}

	/**
	 * @description Returns a copy of the rows kept in memory under the key, marked cached, or null.
	 *
	 * @param key The in-memory cache key
	 *
	 * @return A result holding a fresh copy of the stored rows, or null
	 */
	@TestVisible
	private static QueryResult getCopyFromMemoryCache(String key)
	{
		List<SObject> stored = (List<SObject>)QUERY_RESULT_MEMORY_CACHE.get(key);
		if(stored == null)
		{
			return null;
		}
		QueryResult result = new QueryResult();
		result.records = stored.deepClone(true, true, true);
		result.totalRecords = result.records.size();
		result.isCached = true;
		return result;
	}

	/**
	 * @description Keeps a copy of the rows in memory, unless they are over the row cap or the memory cache's heap
	 * guard refuses them. Storing evicts the oldest values while heap use is at or over the guard, with the copy
	 * already counted, so under heap pressure the oldest values go first.
	 *
	 * @param key The in-memory cache key
	 * @param records The rows the caller received
	 * @param storedStatus The status to report when the rows are kept
	 *
	 * @return storedStatus, DECLINED_ROW_CAP or DECLINED_HEAP_GUARD
	 */
	@TestVisible
	private static CacheStatus storeCopyInMemoryCache(String key, List<SObject> records, CacheStatus storedStatus)
	{
		if(records.size() > MEMORY_CACHE_ROW_LIMIT)
		{
			return CacheStatus.DECLINED_ROW_CAP;
		}
		Boolean stored = QUERY_RESULT_MEMORY_CACHE.putIfHeapAllows(key, records.deepClone(true, true, true));
		return stored ? storedStatus : CacheStatus.DECLINED_HEAP_GUARD;
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
	 * @description Internal query execution logic. A PAGINATION read whose guard count comes back above the
	 * platform ceiling is served from a standard cursor instead, since a pagination cursor cannot be opened
	 * over a set that large.
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
			fetchPageFromStandardCursor(parameters, result, accessLevel, bindMap);
		}
		else if(parameters.cursorMode == CursorMode.PAGINATION)
		{
			if(!exceedsPaginationCursorRowLimit(parameters, accessLevel, bindMap))
			{
				fetchPageFromPaginationCursor(parameters, result, accessLevel, bindMap);
			}
			else if(hasStandardCursorHeadroom())
			{
				fetchPageFromStandardCursor(parameters, result, accessLevel, bindMap);
			}
			else if(canServePlainPage(parameters))
			{
				fetchPageFromPlainQuery(parameters, result, accessLevel, bindMap);
			}
			else
			{
				throw new UTIL_Exceptions.IllegalStateException(CURSOR_CAPACITY_EXHAUSTED);
			}
		}
		else
		{
			result.records = doQuery(parameters.queryString, accessLevel, bindMap);
			result.totalRecords = result.records.size();
		}
	}

	/**
	 * @description Answers whether this transaction can still open a standard cursor and make a fetch call on
	 * it. Both limits apply to the whole transaction: 50 cursors and 100 fetch calls at the time of writing.
	 *
	 * @return True when a standard cursor can still serve a page.
	 */
	private static Boolean hasStandardCursorHeadroom()
	{
		UTIL_Limits.LimitCheck standardCursors = UTIL_Limits.apexCursors();
		Integer ceiling = standardCursorLimitOverride ?? standardCursors.maximum();
		return standardCursors.used() < ceiling && !UTIL_Limits.fetchCallsOnApexCursor().isExhausted();
	}

	/**
	 * @description Answers whether the last way to read a page can be used: a plain LIMIT/OFFSET query. It needs no
	 * cursor at all, but it cannot read past SOQL's OFFSET limit of MAX_QUERY_OFFSET rows.
	 *
	 * @param parameters The query parameters, carrying the optional plain page and total-count queries.
	 *
	 * @return True when a plain query can serve this page.
	 */
	private static Boolean canServePlainPage(QueryParameters parameters)
	{
		// Aggregate pages are refused here even though a LIMIT/OFFSET aggregate is valid SOQL: this way's
		// totalRecords comes from a COUNT() of rows, not of groups, so it would return a wrong total where
		// every other way throws. A clear capacity error is better than a page that gives a wrong size.
		return parameters.plainPageQuery != null && parameters.totalRecordCountQuery != null && (parameters.offset ?? 0) <= MAX_QUERY_OFFSET && parameters.aggregateQuery != true;
	}

	/**
	 * @description Answers whether this transaction can NOT open a pagination cursor for the current page. Three
	 * things can prevent it: the transaction has no pagination cursor left to open, it has no rows left to read, or
	 * more rows match than the rows left. The third is checked by running the limited count the caller supplied. The
	 * first two are cheaper to read from the governor limits, so when either one applies the count is not run.
	 *
	 * The count runs here, not where the method is called, so it uses the sharing that the executor set up.
	 * WithSharingExecutor and WithoutSharingExecutor both reach this through doExecute, so the guard counts exactly
	 * the rows the page query will read.
	 *
	 * The guard is a check made before opening the cursor, not a fallback after it fails. Opening the cursor and
	 * catching the failure is impossible, because the platform throws a governor LimitException that no catch block
	 * can catch.
	 *
	 * @param parameters The query parameters, carrying the optional limited count query.
	 * @param accessLevel The access level.
	 * @param bindMap The bind variables, shared with the page query.
	 *
	 * @return True when the page must come another way: from a standard cursor, or from the plain query when no
	 * standard cursor is left.
	 */
	private static Boolean exceedsPaginationCursorRowLimit(QueryParameters parameters, AccessLevel accessLevel, Map<String, Object> bindMap)
	{
		if(parameters.paginationGuardQuery == null)
		{
			return false;
		}

		if(UTIL_Limits.apexPaginationCursors().isExhausted())
		{
			return true;
		}

		Integer headroom = getPaginationCursorRowHeadroom();

		if(headroom <= 0)
		{
			return true;
		}

		return doCount(parameters.paginationGuardQuery, accessLevel, bindMap) > headroom;
	}

	/**
	 * @description The second way to read a page: fetches one page through a standard cursor. A standard cursor may
	 * read far more rows than a pagination cursor (50,000,000 against 100,000 at the time of writing). The cost is
	 * that it gives no count of deleted records, and no cursor the caller could reuse for a later page. The STANDARD
	 * cursor mode uses this same method, so the two always behave the same.
	 *
	 * @param parameters The query parameters.
	 * @param result The result to populate.
	 * @param accessLevel The access level.
	 * @param bindMap The bind variables.
	 */
	private static void fetchPageFromStandardCursor(QueryParameters parameters, QueryResult result, AccessLevel accessLevel, Map<String, Object> bindMap)
	{
		Database.Cursor cursor = doCursor(parameters.queryString, accessLevel, bindMap);
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

	/**
	 * @description The first way to read a page: fetches one page through a pagination cursor. This cursor also
	 * reports how many records were deleted since it was created, and it can be returned to the caller for later
	 * pages. Each transaction may read 100,000 rows and open 50 cursors this way, at the time of writing.
	 *
	 * Cursor failures the platform throws here (`System.FatalCursorException` and
	 * `System.TransientCursorException`) are passed on to the caller, not caught. Only the caller knows enough to
	 * tell them apart: a temporary failure is worth retrying, a fatal one is not.
	 *
	 * @param parameters The query parameters.
	 * @param result The result to populate.
	 * @param accessLevel The access level.
	 * @param bindMap The bind variables.
	 */
	private static void fetchPageFromPaginationCursor(QueryParameters parameters, QueryResult result, AccessLevel accessLevel, Map<String, Object> bindMap)
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

	/**
	 * @description The third way to read a page: fetches one page with a plain LIMIT/OFFSET query, and a separate
	 * count for the total. It needs no cursor at all, so it still works in a transaction that has used up both kinds
	 * of cursor. But SOQL's OFFSET limit of MAX_QUERY_OFFSET rows means it cannot read a page far into the results.
	 *
	 * @param parameters The query parameters, carrying the plain page and total-count queries.
	 * @param result The result to populate.
	 * @param accessLevel The access level.
	 * @param bindMap The bind variables.
	 */
	private static void fetchPageFromPlainQuery(QueryParameters parameters, QueryResult result, AccessLevel accessLevel, Map<String, Object> bindMap)
	{
		result.records = doQuery(parameters.plainPageQuery, accessLevel, bindMap);
		result.totalRecords = doCount(parameters.totalRecordCountQuery, accessLevel, bindMap);
	}

	/**
	 * @description Internal row-query execution, and the single place a row query reaches the database. Runs
	 * in whichever sharing context its caller establishes.
	 *
	 * @param rowQuery The SOQL query to run.
	 * @param accessLevel The access level.
	 * @param bindMap The bind variables.
	 *
	 * @return The matching records.
	 */
	private static List<SObject> doQuery(String rowQuery, AccessLevel accessLevel, Map<String, Object> bindMap)
	{
		return Database.queryWithBinds(rowQuery, bindMap, accessLevel);
	}

	/**
	 * @description Runs the COUNT() query against the database and records its time for the performance log. The sharing
	 * setting picks who runs it: with sharing, without sharing, or the calling class when no setting is made. A count is
	 * never read from or stored in the cache.
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

		// Sent through the same sharing executors as a row query. Counting directly here would use
		// whatever sharing the caller happens to have, and quietly ignore the builder's sharing setting.
		// A count without sharing could then return fewer rows than the same row query without sharing,
		// which misleads any caller that counts the rows before it runs the query.
		Integer count;
		if(parameters.enforceSharing == true)
		{
			count = new WithSharingExecutor().count(parameters, accessLevel, bindMap);
		}
		else if(parameters.enforceSharing == false)
		{
			count = new WithoutSharingExecutor().count(parameters, accessLevel, bindMap);
		}
		else
		{
			count = doCount(parameters.queryString, accessLevel, bindMap);
		}

		stopTimer(timer, parameters, CacheStatus.BYPASS, count);

		return count;
	}

	/**
	 * @description Internal count execution logic, and the single place a count query reaches the database.
	 * It runs with whatever sharing its caller sets up, so the executor that calls it decides the sharing. It
	 * takes the query, not the parameters, because two different counts go through it: the caller's own count, and
	 * the limited guard count that checks the size of a page before a pagination cursor is opened.
	 *
	 * @param countQuery The COUNT() query to run.
	 * @param accessLevel The access level.
	 * @param bindMap The bind variables.
	 *
	 * @return The count of matching records.
	 */
	private static Integer doCount(String countQuery, AccessLevel accessLevel, Map<String, Object> bindMap)
	{
		return Database.countQueryWithBinds
				(
						countQuery,
						bindMap,
						accessLevel
				);
	}

	/**
	 * @description Builds a query locator, and is the single place a query locator is opened. It runs with
	 * whatever sharing its caller sets up, so the executor that calls it decides the sharing used to read the
	 * locator's rows.
	 *
	 * @param locatorQuery The SOQL the locator will run.
	 * @param accessLevel The access level.
	 * @param bindMap The bind variables.
	 *
	 * @return The locator.
	 */
	private static Database.QueryLocator doLocator(String locatorQuery, AccessLevel accessLevel, Map<String, Object> bindMap)
	{
		return Database.getQueryLocatorWithBinds(locatorQuery, bindMap, accessLevel);
	}

	/**
	 * @description Builds a standard cursor, and is the single place a standard cursor is opened. A cursor fixes
	 * its set of rows when it is created, so the executor that calls this decides the sharing of every later
	 * fetch, in this transaction or a later one.
	 *
	 * @param cursorQuery The SOQL the cursor will run.
	 * @param accessLevel The access level.
	 * @param bindMap The bind variables.
	 *
	 * @return The cursor.
	 */
	private static Database.Cursor doCursor(String cursorQuery, AccessLevel accessLevel, Map<String, Object> bindMap)
	{
		return Database.getCursorWithBinds(cursorQuery, bindMap, accessLevel);
	}

	/**
	 * @description Creates, configures, and starts a performance timer based on query parameters.
	 * Sets object name and logging behaviour (suppress/force/threshold) before starting.
	 *
	 * @param parameters The QueryParameters containing logging control settings.
	 * @param operationSuffix The suffix for the operation name (e.g., 'Query', 'Count', 'QueryLocator', 'Cursor').
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
	 * @param rowCount Number of rows returned (null for QueryLocator and Cursor).
	 *
	 * @return The elapsed time in milliseconds.
	 */
	private static Long stopTimer(UTIL_QueryPerformanceTimer timer, QueryParameters parameters, CacheStatus status, Integer rowCount)
	{
		timer.withQueryContext(parameters.queryString, parameters.bindMap, status == CacheStatus.HIT || status == CacheStatus.MEMORY_HIT, status.name());

		if(rowCount != null)
		{
			timer.setRowCount(rowCount);
		}

		timer.stop();
		return timer.getTime();
	}

	/**
	 * @description Parameters for query execution. This class holds one field for each setting the builder can
	 * make, and the engine reads each field once. So the many fields reflect the many query settings; they do not
	 * mean the class does too much.
	 */
	@SuppressWarnings('PMD.TooManyFields')
	public class QueryParameters
	{
		/**
		 * @description The object the query reads. The engine uses it to find the mocks and mock exceptions a test registered
		 * for that object, and to name the object in the performance log.
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
		 * @description True runs the query with AccessLevel.USER_MODE, so the running user's permissions apply; false runs it
		 * with AccessLevel.SYSTEM_MODE. A cached user-mode result is kept in memory for this transaction only.
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
		 * @description A copy of `queryString` as a limited `SELECT COUNT() ... LIMIT n` query, with the same WHERE,
		 * the same binds and so the same matching rows. It is used only in PAGINATION mode, to decide whether few
		 * enough rows match for a pagination cursor. Null means no guard: the pagination cursor is opened directly.
		 */
		public String paginationGuardQuery;

		/**
		 * @description A copy of `queryString` as a plain LIMIT/OFFSET query, with the same fields, WHERE, ORDER BY
		 * and binds. It is used only in PAGINATION mode, and only when neither kind of cursor can read the page.
		 * Null means this plain way of reading a page cannot be used, and a page that cannot be read throws instead.
		 */
		public String plainPageQuery;

		/**
		 * @description A copy of `queryString` as a `SELECT COUNT()` query with no LIMIT, counting the same rows.
		 * It gives the true total when a page is read with the plain query. There, no cursor reports a total,
		 * and the guard count stops too early to be used as one.
		 */
		public String totalRecordCountQuery;

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
		 * @description The most rows the query returns, or null for no limit. The engine uses it to cut registered mock rows to
		 * the same number a real query would return.
		 */
		public Integer limitCount;

		/**
		 * @description Cache TTL in seconds. Null = no caching.
		 */
		public Integer cacheTTL;

		/**
		 * @description Where cached results may be kept. Null = no caching requested.
		 */
		public UTIL_Cache.Scope cacheScope;

		/**
		 * @description True skips reading the cache, so the query always runs. When caching is on, the fresh rows are still
		 * stored for later reads.
		 */
		public Boolean bypassCache = false;

		/**
		 * @description Whether random results are requested.
		 */
		public Boolean randomResults = false;

		/**
		 * @description Whether the query has aggregate functions or a GROUP BY. The builder sets it, so that a
		 * mock exception registered with setMockAggregateException can fail aggregate queries without
		 * touching row queries against the same SObjectType.
		 */
		public Boolean aggregateQuery = false;

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
		 * @description True stops this query from writing a performance log entry, however long it takes. It wins over
		 * forcePerformanceLogging and customPerformanceThresholdMs.
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
		 * @description The rows the query returned, or the rows of the current page for a paged read. It is empty when nothing
		 * matched, and when registered aggregate rows answered the query.
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
		 * @description The rows a test registered to answer an aggregate query (a query with aggregate functions or a
		 * GROUP BY). Each map holds one row, keyed by the aliases the query selects. It is null unless such registered
		 * rows answered the query; `records` is then empty.
		 */
		public List<Map<String, Object>> aggregateRows;

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
	 * @description Runs the query with sharing rules enforced.
	 */
	@SuppressWarnings('DuplicatedCode')
	private with sharing class WithSharingExecutor
	{
		/**
		 * @description Runs the read inside this class, which is declared with sharing, so the running user's sharing rules
		 * decide which records come back. It fills the given result.
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

		/**
		 * @description Executes the count with sharing.
		 *
		 * @param parameters The query parameters.
		 * @param accessLevel The access level.
		 * @param bindMap The bind variables.
		 *
		 * @return The count of matching records.
		 */
		public Integer count(QueryParameters parameters, AccessLevel accessLevel, Map<String, Object> bindMap)
		{
			return doCount(parameters.queryString, accessLevel, bindMap);
		}

		/**
		 * @description Opens the locator with sharing.
		 *
		 * @param parameters The query parameters.
		 * @param accessLevel The access level.
		 * @param bindMap The bind variables.
		 *
		 * @return The locator.
		 */
		public Database.QueryLocator locator(QueryParameters parameters, AccessLevel accessLevel, Map<String, Object> bindMap)
		{
			return doLocator(parameters.queryString, accessLevel, bindMap);
		}

		/**
		 * @description Opens the cursor with sharing.
		 *
		 * @param parameters The query parameters.
		 * @param accessLevel The access level.
		 * @param bindMap The bind variables.
		 *
		 * @return The cursor.
		 */
		public Database.Cursor cursor(QueryParameters parameters, AccessLevel accessLevel, Map<String, Object> bindMap)
		{
			return doCursor(parameters.queryString, accessLevel, bindMap);
		}
	}

	/**
	 * @description Runs the query without sharing rules.
	 */
	@SuppressWarnings('DuplicatedCode')
	private without sharing class WithoutSharingExecutor
	{
		/**
		 * @description Runs the read inside this class, which is declared without sharing, so sharing rules do not limit which
		 * records come back. It fills the given result.
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

		/**
		 * @description Executes the count without sharing, so a count without sharing counts the same rows that
		 * a row query without sharing would return.
		 *
		 * @param parameters The query parameters.
		 * @param accessLevel The access level.
		 * @param bindMap The bind variables.
		 *
		 * @return The count of matching records.
		 */
		public Integer count(QueryParameters parameters, AccessLevel accessLevel, Map<String, Object> bindMap)
		{
			return doCount(parameters.queryString, accessLevel, bindMap);
		}

		/**
		 * @description Opens the locator without sharing, so a batch without sharing reads the same rows that
		 * a row query without sharing would return.
		 *
		 * @param parameters The query parameters.
		 * @param accessLevel The access level.
		 * @param bindMap The bind variables.
		 *
		 * @return The locator.
		 */
		public Database.QueryLocator locator(QueryParameters parameters, AccessLevel accessLevel, Map<String, Object> bindMap)
		{
			return doLocator(parameters.queryString, accessLevel, bindMap);
		}

		/**
		 * @description Opens the cursor without sharing, so a cursor without sharing fetches the same rows that
		 * a row query without sharing would return, in this transaction or a later one.
		 *
		 * @param parameters The query parameters.
		 * @param accessLevel The access level.
		 * @param bindMap The bind variables.
		 *
		 * @return The cursor.
		 */
		public Database.Cursor cursor(QueryParameters parameters, AccessLevel accessLevel, Map<String, Object> bindMap)
		{
			return doCursor(parameters.queryString, accessLevel, bindMap);
		}
	}
}