// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A stopwatch for timing trigger actions with automatic performance logging.
 * Extends UTIL_StopWatch to add trigger-specific performance logging with fluent API control.
 * Respects LogSetting__c settings for EnableTriggerPerformanceLogging__c and TriggerPerformanceThresholdMs__c,
 * as well as TriggerSetting__mdt and TriggerAction__mdt level overrides.
 *
 * Use this class when timing trigger actions. For other contexts, use:
 * - {@link UTIL_PerformanceTimer} for general API/operation logging (simpler, no fluent API)
 * - {@link UTIL_QueryPerformanceTimer} for database queries (has query context support)
 *
 * **Shared Pattern:** This class shares common patterns with its sibling timer classes:
 * governor limit tracking, fluent API (log/suppressLogging/logIfSlowerThan), threshold-based
 * logging with hierarchy (suppress > force > custom > global), and recursion guards.
 * See {@link UTIL_StopWatch} class documentation for design rationale.
 *
 * **Configuration Hierarchy** (highest to lowest priority):
 * 1. TriggerAction__mdt.ForcePerformanceLogging__c / SuppressPerformanceLogging__c / PerformanceThresholdMs__c
 * 2. TriggerSetting__mdt.EnablePerformanceLogging__c / PerformanceThresholdMs__c
 * 3. LogSetting__c.EnableTriggerPerformanceLogging__c / TriggerPerformanceThresholdMs__c
 *
 * @see UTIL_StopWatch
 * @see UTIL_PerformanceTimer
 * @see UTIL_QueryPerformanceTimer
 * @see UTIL_TriggerPerformanceTimer_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date December 2025, May 2026
 *
 * @example
 * ```apex
 * // Simple usage - logs automatically on stop() if threshold exceeded
 * UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer('TRG_Account_ValidateName', 'BEFORE_INSERT', 'Account', 100);
 * timer.start();
 * // ... execute trigger action ...
 * timer.stop(); // Automatically logs if duration exceeds configured threshold
 * ```
 */
public inherited sharing class UTIL_TriggerPerformanceTimer extends UTIL_StopWatch
{
	/**
	 * @description Static recursion guard to prevent infinite loops when logging triggers queries.
	 */
	@TestVisible
	private static Boolean isLogging = false;

	/**
	 * @description Force logging regardless of threshold settings.
	 */
	private Boolean forceLog = false;

	/**
	 * @description Suppress logging entirely.
	 */
	private Boolean suppressLog = false;

	/**
	 * @description Custom threshold from TriggerAction__mdt or TriggerSetting__mdt.
	 */
	private Integer customThresholdMs;

	/**
	 * @description Flow API name captured from `TriggerAction__mdt.FlowName__c` when the
	 * action is a Flow-as-Trigger-Action dispatch. Surfaced in the perf log entry's
	 * trigger-context map so subscriber log queries can filter by flow.
	 */
	@TestVisible
	private String flowName;

	/**
	 * @description Number of records in the trigger batch.
	 */
	private final Integer recordCount;

	/**
	 * @description Starting CPU time for delta calculation.
	 */
	private Integer startCpuTime;

	/**
	 * @description Starting heap size for delta calculation.
	 */
	private Integer startHeapSize;

	/**
	 * @description Starting SOQL query count for delta calculation.
	 */
	private Integer startSoqlQueries;

	/**
	 * @description Starting DML statement count for delta calculation.
	 */
	private Integer startDmlStatements;

	/**
	 * @description The trigger action class name.
	 */
	public final String actionClassName
	{
		get;
		private set;
	}

	/**
	 * @description The trigger operation context (e.g., BEFORE_INSERT, AFTER_UPDATE).
	 */
	public final String triggerOperation
	{
		get;
		private set;
	}

	/**
	 * @description The SObject type name being processed.
	 */
	public final String objectName
	{
		get;
		private set;
	}

	/**
	 * @description Creates a trigger performance timer with the specified parameters.
	 *
	 * @param actionClassName Name of the trigger action class (e.g., 'TRG_Account_ValidateName')
	 * @param triggerOperation The trigger context (e.g., 'BEFORE_INSERT')
	 * @param objectName The SObject type name (e.g., 'Account')
	 * @param recordCount Number of records in the trigger batch
	 *
	 * @example
	 * ```apex
	 * UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer('TRG_Account_ValidateName', 'BEFORE_INSERT', 'Account', 100);
	 * ```
	 */
	public UTIL_TriggerPerformanceTimer(String actionClassName, String triggerOperation, String objectName, Integer recordCount)
	{
		super();
		this.actionClassName = actionClassName;
		this.triggerOperation = triggerOperation;
		this.objectName = objectName;
		this.recordCount = recordCount;
	}

	/**
	 * @description Forces logging regardless of threshold settings.
	 * Takes precedence over suppressLogging() if both are called.
	 *
	 * @return This timer instance for method chaining
	 *
	 * @example
	 * ```apex
	 * timer.log().stop(); // Always logs
	 * ```
	 */
	public UTIL_TriggerPerformanceTimer log()
	{
		forceLog = true;
		suppressLog = false;
		return this;
	}

	/**
	 * @description Sets a custom threshold that overrides the global setting.
	 * The action will be logged only if duration exceeds this threshold.
	 *
	 * @param thresholdMs Custom threshold in milliseconds
	 *
	 * @return This timer instance for method chaining
	 *
	 * @example
	 * ```apex
	 * timer.logIfSlowerThan(500).stop(); // Log only if > 500ms
	 * ```
	 */
	public UTIL_TriggerPerformanceTimer logIfSlowerThan(Integer thresholdMs)
	{
		customThresholdMs = thresholdMs;
		forceLog = false;
		suppressLog = false;
		return this;
	}

	/**
	 * @description Suppresses all logging for this timer instance.
	 * Takes precedence over threshold settings but not over forceLog().
	 *
	 * @return This timer instance for method chaining
	 *
	 * @example
	 * ```apex
	 * timer.suppressLogging().stop(); // Never logs
	 * ```
	 */
	public UTIL_TriggerPerformanceTimer suppressLogging()
	{
		suppressLog = true;
		forceLog = false;
		return this;
	}

	/**
	 * @description Configures the timer from TriggerAction__mdt settings.
	 * Applies ForcePerformanceLogging__c, SuppressPerformanceLogging__c, and PerformanceThresholdMs__c.
	 *
	 * @param triggerActionMetadata The TriggerAction__mdt record
	 *
	 * @return This timer instance for method chaining
	 */
	public UTIL_TriggerPerformanceTimer withActionSettings(TriggerAction__mdt triggerActionMetadata)
	{
		if(triggerActionMetadata != null)
		{
			if(triggerActionMetadata.ForcePerformanceLogging__c)
			{
				forceLog = true;
				suppressLog = false;
			}
			else if(triggerActionMetadata.SuppressPerformanceLogging__c)
			{
				suppressLog = true;
				forceLog = false;
			}

			if(triggerActionMetadata.PerformanceThresholdMs__c != null)
			{
				customThresholdMs = (Integer)triggerActionMetadata.PerformanceThresholdMs__c;
			}

			if(String.isNotBlank(triggerActionMetadata.FlowName__c))
			{
				flowName = triggerActionMetadata.FlowName__c;
			}
		}
		return this;
	}

	/**
	 * @description Starts the timer and captures initial governor limit values.
	 * Tracks CPU time, heap size, SOQL queries, and DML statements.
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
	 * Logging respects the hierarchy: suppressLogging > forceLog > customThreshold > globalThreshold.
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
	 * @description Builds the detailed performance metrics string.
	 * Uses Math.max(0, ...) to handle Test.startTest() limit resets gracefully.
	 *
	 * @return The formatted details string with CPU, heap, SOQL, DML, and record count metrics
	 */
	private String buildPerformanceDetails()
	{
		Integer cpuUsed = Math.max(0, UTIL_Limits.cpuTime().used() - startCpuTime);
		Integer heapUsed = Math.max(0, UTIL_Limits.heapSize().used() - startHeapSize);
		Integer soqlUsed = Math.max(0, UTIL_Limits.soqlQueries().used() - startSoqlQueries);
		Integer dmlUsed = Math.max(0, UTIL_Limits.dmlStatements().used() - startDmlStatements);

		String details = 'CPU: ' + cpuUsed + 'ms, Heap: ' + heapUsed + ' bytes, SOQL: ' + soqlUsed + ', DML: ' + dmlUsed;

		if(recordCount != null)
		{
			details += ', Records: ' + recordCount;
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
		return actionClassName + ' (' + triggerOperation + ') completed in ' + elapsedMs + 'ms';
	}

	/**
	 * @description Captures the starting values of governor limits for delta calculation.
	 */
	private void captureStartMetrics()
	{
		startCpuTime = UTIL_Limits.cpuTime().used();
		startHeapSize = UTIL_Limits.heapSize().used();
		startSoqlQueries = UTIL_Limits.soqlQueries().used();
		startDmlStatements = UTIL_Limits.dmlStatements().used();
	}

	/**
	 * @description Logs performance metrics based on the configured logging hierarchy.
	 * Hierarchy: suppressLogging > forceLog > customThreshold > globalThreshold
	 */
	private void logPerformanceIfNeeded()
	{
		// Prevent infinite recursion when logging triggers queries
		if(isLogging)
		{
			return;
		}

		// Suppress takes highest precedence (unless force was called after)
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

			if(setting.EnableTriggerPerformanceLogging__c != true)
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
				threshold = (Long)setting.TriggerPerformanceThresholdMs__c;
			}

			// Use >= so that a 0ms threshold means "log all actions"
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
	 * @description Writes the performance log entry with trigger context.
	 * Pushes operation context with trigger details before logging,
	 * then pops the context to prevent bleeding into subsequent logs.
	 *
	 * @param elapsedMs The elapsed time in milliseconds
	 */
	private void logPerformance(Long elapsedMs)
	{
		// Build trigger context for the context stack
		Map<String, String> triggerContext = buildTriggerContext();

		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.TRIGGER_ACTION, triggerContext);

		try
		{
			String message = buildPerformanceMessage(elapsedMs);
			String details = buildPerformanceDetails();
			LOG_Engine.logPerformance(message, details, actionClassName + '/' + triggerOperation.toLowerCase(), elapsedMs);
		}
		finally
		{
			LOG_Engine.popOperationContext();
		}
	}

	/**
	 * @description Builds the trigger context map for the context stack.
	 * Includes action class name, trigger operation, object name, and record count.
	 *
	 * @return Map<String, String> The trigger context data
	 */
	private Map<String, String> buildTriggerContext()
	{
		Map<String, String> context = new Map<String, String>();
		context.put(LOG_Engine.CONTEXT_ACTION_CLASS_NAME, actionClassName);
		context.put(LOG_Engine.CONTEXT_TRIGGER_OPERATION, triggerOperation);

		if(String.isNotBlank(objectName))
		{
			context.put(LOG_Engine.CONTEXT_OBJECT_NAME, objectName);
		}

		if(recordCount != null)
		{
			context.put(LOG_Engine.CONTEXT_RECORD_COUNT, String.valueOf(recordCount));
		}

		if(String.isNotBlank(flowName))
		{
			context.put(LOG_Engine.CONTEXT_FLOW_NAME, flowName);
		}

		return context;
	}
}