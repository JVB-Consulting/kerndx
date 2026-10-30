// SPDX-License-Identifier: Apache-2.0
/**
 * @description A stopwatch for timing database queries with automatic performance logging.
 * Extends UTIL_StopWatch to add query-specific performance logging with fluent API control.
 * Respects LogSetting__c settings for EnableQueryPerformanceLogging__c and QueryPerformanceThresholdMs__c.
 *
 * Use this class when timing database queries. For other contexts, use:
 * - {@link UTIL_PerformanceTimer} for general API/operation logging (simpler, no fluent API)
 * - {@link UTIL_TriggerPerformanceTimer} for trigger actions (has action metadata support)
 *
 * **Shared Pattern:** This class shares common patterns with its sibling timer classes:
 * governor limit tracking, fluent API (log/suppressLogging/logIfSlowerThan), threshold-based
 * logging where the last of log(), suppressLogging() and logIfSlowerThan() wins, and recursion guards.
 * See {@link UTIL_StopWatch} class documentation for design rationale.
 *
 * @see UTIL_StopWatch
 * @see UTIL_PerformanceTimer
 * @see UTIL_TriggerPerformanceTimer
 * @see UTIL_QueryPerformanceTimer_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date December 2025, October 2026
 *
 * @example
 * ```apex
 * // Simple usage - logs automatically on stop() if threshold exceeded
 * UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer('AccountQuery', 'SEL_Account/findById');
 * timer.start();
 * List<Account> accounts = Database.query(soql);
 * timer.stop(); // Automatically logs if duration exceeds configured threshold
 * // Force logging regardless of threshold
 * timer.log().stop();
 * // Custom threshold override
 * timer.logIfSlowerThan(500).stop(); // Log only if > 500ms
 * // Suppress logging entirely
 * timer.suppressLogging().stop(); // Never logs
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.AvoidBooleanMethodParameters')
public inherited sharing class UTIL_QueryPerformanceTimer extends UTIL_StopWatch
{
	/**
	 * @description Static recursion guard to prevent infinite loops when logging triggers queries.
	 */
	private static Boolean isLogging = false;
	/**
	 * @description True when the caller asked for this query to be logged however fast it ran and whatever the log setting says.
	 * Asking for it clears suppressLog; the request made last is the one that counts.
	 */
	private Boolean forceLog = false;
	/**
	 * @description True when the caller asked for this query never to be logged. Asking for it clears forceLog; the request made
	 * last is the one that counts.
	 */
	private Boolean suppressLog = false;
	/**
	 * @description The duration in milliseconds from which this query is logged, used in place of the threshold in the log
	 * setting. Null when the caller set none. It applies only while query performance logging is switched on in the log setting.
	 */
	private Integer customThresholdMs;
	/**
	 * @description How many rows the query returned, as told by the caller. It is added to the log entry when set and left out
	 * when null.
	 */
	private Integer rowCount;
	/**
	 * @description The CPU time, in milliseconds, the transaction had used when the timer started. The log entry reports the CPU
	 * time used since then.
	 */
	private Integer startCpuTime;
	/**
	 * @description The heap size, in bytes, the transaction was using when the timer started. The log entry reports how much it
	 * has grown since then.
	 */
	private Integer startHeapSize;
	/**
	 * @description The number of SOQL queries the transaction had run when the timer started. The log entry reports the queries
	 * run since then.
	 */
	private Integer startSoqlQueries;

	/**
	 * @description The SOQL query string for context logging.
	 */
	private String queryString;

	/**
	 * @description JSON-serialized bind variables for context logging.
	 */
	private String bindVariablesJson;

	/**
	 * @description The SObject type name being queried.
	 */
	private String objectName;

	/**
	 * @description Whether the result came from cache.
	 */
	private Boolean isCached;

	/**
	 * @description Cache status (HIT, MISS, STORED, BYPASS, etc.).
	 */
	private String cacheStatus;

	/**
	 * @description The class and method context for log entries (e.g., 'MyClass/myMethod').
	 */
	public final String classMethod
	{
		get;
		private set;
	}

	/**
	 * @description The name of the operation being timed, used in the performance log message.
	 */
	public final String operationName
	{
		get;
		private set;
	}

	/**
	 * @description Creates a timer that is not running yet: call start() just before the query and stop() just after it.
	 * The two names are not checked; they only label the performance log entry.
	 *
	 * @param operationName Name of the query operation being timed (used in log message)
	 * @param classMethod The class.method context for the log entry (e.g., 'SEL_Account/findById')
	 *
	 * @example
	 * ```apex
	 * UTIL_QueryPerformanceTimer timer = new UTIL_QueryPerformanceTimer('AccountQuery', 'SEL_Account/findById');
	 * ```
	 */
	public UTIL_QueryPerformanceTimer(String operationName, String classMethod)
	{
		super();
		this.operationName = operationName;
		this.classMethod = classMethod;
	}

	/**
	 * @description Forces logging regardless of threshold settings, even when query performance logging is switched off.
	 * Clears an earlier suppressLogging(); a later suppressLogging() or logIfSlowerThan() clears this request in turn.
	 *
	 * @return This timer instance for method chaining
	 *
	 * @example
	 * ```apex
	 * timer.log().stop(); // Always logs
	 * ```
	 */
	public UTIL_QueryPerformanceTimer log()
	{
		forceLog = true;
		suppressLog = false;
		return this;
	}

	/**
	 * @description Sets a custom threshold that overrides the global setting.
	 * The query will be logged only if duration reaches this threshold and query performance logging is switched on.
	 * Clears an earlier log() or suppressLogging().
	 *
	 * @param thresholdMs Custom threshold in milliseconds
	 *
	 * @return This timer instance for method chaining
	 *
	 * @example
	 * ```apex
	 * timer.logIfSlowerThan(500).stop(); // Log only if the query took 500 ms or more
	 * ```
	 */
	public UTIL_QueryPerformanceTimer logIfSlowerThan(Integer thresholdMs)
	{
		customThresholdMs = thresholdMs;
		forceLog = false;
		suppressLog = false;
		return this;
	}

	/**
	 * @description Sets the number of rows returned by the query for inclusion in log details.
	 *
	 * @param count The number of rows returned
	 *
	 * @return This timer instance for method chaining
	 *
	 * @example
	 * ```apex
	 * List<Account> accounts = Database.query(soql);
	 * timer.setRowCount(accounts.size()).stop();
	 * ```
	 */
	public UTIL_QueryPerformanceTimer setRowCount(Integer count)
	{
		rowCount = count;
		return this;
	}

	/**
	 * @description Sets the query context from individual parameters for enriched logging.
	 * Captures SOQL text, bind variables, cache status for inclusion in ContextData__c.
	 *
	 * @param aQueryString The SOQL query string
	 * @param bindMap The bind variable map (can be null or empty)
	 * @param isQueryCached Whether the result came from cache
	 * @param queryCacheStatus Cache status string (e.g., 'HIT', 'STORED', 'BYPASS')
	 *
	 * @return This timer instance for method chaining
	 *
	 * @example
	 * ```apex
	 * timer.withQueryContext(soql, bindMap, false, 'STORED').setRowCount(results.size()).stop();
	 * ```
	 */
	public UTIL_QueryPerformanceTimer withQueryContext(String aQueryString, Map<String, Object> bindMap, Boolean isQueryCached, String queryCacheStatus)
	{
		queryString = aQueryString;
		isCached = isQueryCached;
		cacheStatus = queryCacheStatus;

		if(bindMap?.isEmpty() == false)
		{
			bindVariablesJson = JSON.serialize(bindMap);
		}

		return this;
	}

	/**
	 * @description Sets the object name for context logging.
	 *
	 * @param objectName The SObject type name being queried (e.g., 'Account', 'Custom__c')
	 *
	 * @return This timer instance for method chaining
	 *
	 * @example
	 * ```apex
	 * timer.withObjectName('Account').stop();
	 * ```
	 */
	public UTIL_QueryPerformanceTimer withObjectName(String objectName)
	{
		this.objectName = objectName;
		return this;
	}

	/**
	 * @description Starts the timer and captures initial governor limit values.
	 * Tracks CPU time, heap size, and SOQL queries.
	 *
	 * @throws UTIL_Exceptions.IllegalStateException if the stopwatch is already started
	 */
	public override void start()
	{
		super.start();
		captureStartMetrics();
	}

	/**
	 * @description Stops the timer and automatically logs performance if conditions are met.
	 * Of log(), suppressLogging() and logIfSlowerThan(), the one called last decides: a suppressed timer never logs, a forced
	 * timer always logs, and otherwise the query is logged only when query performance logging is switched on and the time
	 * reaches the custom threshold, or the log setting threshold when no custom threshold is set.
	 *
	 * @throws UTIL_Exceptions.IllegalStateException if the stopwatch is not running
	 */
	public override void stop()
	{
		super.stop();
		logPerformanceIfNeeded();
	}

	/**
	 * @description Stops the timer without logging. Use when you need the elapsed time
	 * but want to decide whether to log based on custom criteria.
	 *
	 * @return The elapsed time in milliseconds
	 *
	 * @throws UTIL_Exceptions.IllegalStateException if the stopwatch is not running
	 */
	public Long stopSilent()
	{
		super.stop();
		return getTime();
	}

	/**
	 * @description Suppresses all logging for this timer instance.
	 * Takes precedence over threshold settings. Clears an earlier log(); a later log() or logIfSlowerThan() clears this request
	 * in turn.
	 *
	 * @return This timer instance for method chaining
	 *
	 * @example
	 * ```apex
	 * timer.suppressLogging().stop(); // Never logs
	 * ```
	 */
	public UTIL_QueryPerformanceTimer suppressLogging()
	{
		suppressLog = true;
		forceLog = false;
		return this;
	}

	/**
	 * @description Builds the detailed performance metrics string.
	 * Uses Math.max(0, ...) to handle Test.startTest() limit resets gracefully.
	 *
	 * @return The formatted details string with CPU, heap, SOQL, and row count metrics
	 */
	private String buildPerformanceDetails()
	{
		Integer cpuUsed = Math.max(0, UTIL_Limits.cpuTime().used() - startCpuTime);
		Integer heapUsed = Math.max(0, UTIL_Limits.heapSize().used() - startHeapSize);
		Integer soqlUsed = Math.max(0, UTIL_Limits.soqlQueries().used() - startSoqlQueries);

		String details = 'CPU: ' + cpuUsed + 'ms, Heap: ' + heapUsed + ' bytes, SOQL: ' + soqlUsed;

		if(rowCount != null)
		{
			details += ', Rows: ' + rowCount;
		}

		return details;
	}

	/**
	 * @description Builds the main performance log message.
	 *
	 * @param elapsedMs The elapsed time in milliseconds
	 *
	 * @return The formatted performance message
	 */
	private String buildPerformanceMessage(Long elapsedMs)
	{
		return operationName + ' completed in ' + elapsedMs + 'ms';
	}

	/**
	 * @description Captures the starting values of governor limits for delta calculation.
	 */
	private void captureStartMetrics()
	{
		startCpuTime = UTIL_Limits.cpuTime().used();
		startHeapSize = UTIL_Limits.heapSize().used();
		startSoqlQueries = UTIL_Limits.soqlQueries().used();
	}

	/**
	 * @description Logs performance metrics based on the configured logging hierarchy.
	 * Of log(), suppressLogging() and logIfSlowerThan(), the one called last decides, because each clears the requests of the
	 * others: suppressed never logs, forced always logs, and otherwise the custom or log setting threshold applies while query
	 * performance logging is switched on.
	 */
	private void logPerformanceIfNeeded()
	{
		// Prevent infinite recursion when logging triggers queries
		if(isLogging)
		{
			return;
		}

		if(suppressLog)
		{
			return;
		}

		try
		{
			isLogging = true;

			LogSetting__c setting = LOG_Engine.getLogSetting();
			Long elapsedMs = getTime();

			if(forceLog)
			{
				logPerformance(elapsedMs);
				return;
			}

			if(setting.EnableQueryPerformanceLogging__c != true)
			{
				return;
			}

			Long threshold;
			if(customThresholdMs != null)
			{
				threshold = customThresholdMs;
			}
			else
			{
				threshold = (Long)setting.QueryPerformanceThresholdMs__c;
			}

			// Use >= so that a 0ms threshold means "log all queries"
			if(elapsedMs >= threshold)
			{
				logPerformance(elapsedMs);
			}
		}
		finally
		{
			isLogging = false;
		}
	}

	/**
	 * @description Writes the performance log entry with query context.
	 * Pushes operation context with SOQL, bind variables, and cache status before logging,
	 * then pops the context to prevent bleeding into subsequent logs.
	 *
	 * @param elapsedMs The elapsed time in milliseconds
	 */
	private void logPerformance(Long elapsedMs)
	{
		// Build query context for the context stack
		Map<String, String> queryContext = buildQueryContext();

		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.QUERY, queryContext);

		try
		{
			String message = buildPerformanceMessage(elapsedMs);
			String details = buildPerformanceDetails();
			LOG_Engine.logPerformance(message, details, classMethod, elapsedMs);
		}
		finally
		{
			LOG_Engine.popOperationContext();
		}
	}

	/**
	 * @description Builds the query context map for the context stack.
	 * Includes SOQL text, bind variables, cache status, and object name.
	 *
	 * @return Map<String, String> The query context data
	 */
	private Map<String, String> buildQueryContext()
	{
		Map<String, String> context = new Map<String, String>();
		context.put(LOG_Engine.CONTEXT_QUERY_TYPE, 'SOQL');

		if(String.isNotBlank(objectName))
		{
			context.put(LOG_Engine.CONTEXT_OBJECT_NAME, objectName);
		}

		if(String.isNotBlank(queryString))
		{
			context.put(LOG_Engine.CONTEXT_SOQL, queryString);
		}

		if(String.isNotBlank(bindVariablesJson))
		{
			context.put(LOG_Engine.CONTEXT_BIND_VARIABLES, bindVariablesJson);
		}

		if(rowCount != null)
		{
			context.put(LOG_Engine.CONTEXT_ROW_COUNT, String.valueOf(rowCount));
		}

		if(isCached != null)
		{
			context.put(LOG_Engine.CONTEXT_IS_CACHED, String.valueOf(isCached));
		}

		if(String.isNotBlank(cacheStatus))
		{
			context.put(LOG_Engine.CONTEXT_CACHE_STATUS, cacheStatus);
		}

		return context;
	}
}