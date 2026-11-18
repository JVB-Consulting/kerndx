// SPDX-License-Identifier: Apache-2.0
/**
 * @description A stopwatch for timing trigger actions with automatic performance logging.
 * Extends UTIL_StopWatch to add trigger-specific performance logging with fluent API control.
 * Reads the action row (TriggerAction__mdt or PostTriggerAction__mdt), the threshold of the trigger setting the action
 * belongs to (TriggerSetting__mdt), and the org settings (LogSetting__c).
 *
 * Use this class when timing trigger actions. For other contexts, use:
 * - {@link UTIL_PerformanceTimer} for general API/operation logging (simpler, no fluent API)
 * - {@link UTIL_QueryPerformanceTimer} for database queries (has query context support)
 *
 * **Shared Pattern:** This class shares common patterns with its sibling timer classes:
 * governor limit tracking, fluent API (log/suppressLogging/logIfSlowerThan), threshold-based
 * logging, and recursion guards.
 * See {@link UTIL_StopWatch} class documentation for design rationale.
 *
 * **When a run is logged**, strongest rule first:
 * 1. TriggerAction__mdt.SuppressPerformanceLogging__c: the action never logs, even when Force is also ticked.
 * 2. ForcePerformanceLogging__c on the action row: the action always logs.
 * 3. PerformanceThresholdMs__c on the action row: the action logs a run that takes this long or longer.
 * 4. TriggerSetting__mdt.PerformanceThresholdMs__c: the same, for every action registered under that trigger setting.
 * 5. LogSetting__c.EnableTriggerPerformanceLogging__c and TriggerPerformanceThresholdMs__c: used only when neither the
 *    action nor its trigger setting has a threshold.
 *
 * A threshold on the action or on its trigger setting logs even when the org switch
 * (EnableTriggerPerformanceLogging__c) is off. The most specific threshold that is set applies. A threshold of 0 logs
 * every run, and a very high threshold stops the entries for those actions.
 *
 * The order above is for the settings on the action row; of log(), suppressLogging() and logIfSlowerThan() called on the
 * timer, the last call decides.
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
 * @date December 2025, November 2026
 *
 * @example
 * ```apex
 * // Simple usage - logs on stop() when the run takes the threshold that applies or longer
 * UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer('TRG_Account_ValidateName', 'BEFORE_INSERT', 'Account', 100);
 * timer.start();
 * // ... execute trigger action ...
 * timer.stop(); // Logs when the run took the threshold that applies or longer
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity')
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
	 * @description The action's own threshold in milliseconds: PerformanceThresholdMs__c on the action row, or the value
	 * given to logIfSlowerThan. Null when the action has none. It wins over triggerSettingThresholdMs.
	 */
	private Integer customThresholdMs;

	/**
	 * @description The threshold in milliseconds of the trigger setting the action belongs to
	 * (TriggerSetting__mdt.PerformanceThresholdMs__c). Null when the setting has none, or the action has no setting.
	 */
	private Integer triggerSettingThresholdMs;

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
	 * @description Name of the trigger action being timed, set once by the constructor. It starts the performance log
	 * message and, with the trigger operation, forms the location of the log entry.
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
	 * Clears an earlier suppressLogging(). Of log(), suppressLogging() and logIfSlowerThan(), the one called last decides.
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
	 * @description Sets the action's own threshold. It replaces the trigger setting's threshold and the org's. A run that
	 * takes this long or longer is logged, even when the org switch for trigger performance logging is off. Clears an
	 * earlier log() or suppressLogging(). Of log(), suppressLogging() and logIfSlowerThan(), the one called last decides.
	 *
	 * @param thresholdMs Custom threshold in milliseconds
	 *
	 * @return This timer instance for method chaining
	 *
	 * @example
	 * ```apex
	 * timer.logIfSlowerThan(500).stop(); // Logs a run of 500 ms or more
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
	 * Clears an earlier log(). Of log(), suppressLogging() and logIfSlowerThan(), the one called last decides.
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
	 * Applies SuppressPerformanceLogging__c, ForcePerformanceLogging__c and PerformanceThresholdMs__c. When both
	 * Suppress and Force are ticked, Suppress wins and the action never logs.
	 *
	 * @param triggerActionMetadata The TriggerAction__mdt record
	 *
	 * @return This timer instance for method chaining
	 */
	public UTIL_TriggerPerformanceTimer withActionSettings(TriggerAction__mdt triggerActionMetadata)
	{
		if(triggerActionMetadata != null)
		{
			if(triggerActionMetadata.SuppressPerformanceLogging__c)
			{
				suppressLog = true;
				forceLog = false;
			}
			else if(triggerActionMetadata.ForcePerformanceLogging__c)
			{
				forceLog = true;
				suppressLog = false;
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
	 * @description Configures the timer from `PostTriggerAction__mdt` settings, as `withActionSettings(TriggerAction__mdt)`
	 * does for a trigger action. A post-trigger action row has two performance settings: `ForcePerformanceLogging__c`
	 * and `PerformanceThresholdMs__c`. It has no Suppress setting: to quiet a post-trigger action, give it a very high
	 * threshold.
	 *
	 * @param postTriggerActionMetadata The PostTriggerAction__mdt record
	 *
	 * @return This timer instance for method chaining
	 */
	public UTIL_TriggerPerformanceTimer withPostActionSettings(PostTriggerAction__mdt postTriggerActionMetadata)
	{
		if(postTriggerActionMetadata != null)
		{
			if(postTriggerActionMetadata.ForcePerformanceLogging__c)
			{
				forceLog = true;
				suppressLog = false;
			}

			if(postTriggerActionMetadata.PerformanceThresholdMs__c != null)
			{
				customThresholdMs = (Integer)postTriggerActionMetadata.PerformanceThresholdMs__c;
			}
		}
		return this;
	}

	/**
	 * @description Sets the threshold of the trigger setting the action belongs to
	 * (TriggerSetting__mdt.PerformanceThresholdMs__c). It applies when the action has no threshold of its own. A run that
	 * takes this long or longer is logged, even when the org switch for trigger performance logging is off. A null value
	 * changes nothing: the action follows its own threshold, or Log Setting when it has none.
	 *
	 * @param thresholdMs The trigger setting's threshold in milliseconds, or null when it has none.
	 *
	 * @return This timer instance for method chaining
	 *
	 * @example
	 * ```apex
	 * timer.withActionSettings(actionRow).withTriggerSettingThreshold(actionRow.TriggerSetting__r?.PerformanceThresholdMs__c);
	 * ```
	 */
	public UTIL_TriggerPerformanceTimer withTriggerSettingThreshold(Decimal thresholdMs)
	{
		if(thresholdMs != null)
		{
			triggerSettingThresholdMs = thresholdMs.intValue();
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
	 * Whether it logs follows the order in the class description: suppress, then force, then the action's threshold,
	 * then the trigger setting's threshold, then the org settings.
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
	 * @description Logs the run when the rules in the class description say so: never when suppressed, always when
	 * forced, otherwise when the run took as long as the threshold that applies (see resolveThresholdMs) or longer.
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

			Long elapsedMs = getTime();

			if(forceLog)
			{
				logPerformance(elapsedMs);
				return;
			}

			Long thresholdMs = resolveThresholdMs();

			// Use >= so that a 0ms threshold means "log all actions"
			if(thresholdMs != null && elapsedMs >= thresholdMs)
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
	 * @description Finds the threshold that applies to this run. The action's own threshold comes first, then the
	 * threshold of its trigger setting. Either one applies even when the org switch for trigger performance logging is
	 * off. When neither is set, the org threshold applies, but only while the org switch is on.
	 *
	 * @return The threshold in milliseconds, or null when the run must not be logged.
	 */
	private Long resolveThresholdMs()
	{
		Integer configuredThresholdMs = customThresholdMs ?? triggerSettingThresholdMs;
		if(configuredThresholdMs != null)
		{
			return configuredThresholdMs;
		}

		LogSetting__c setting = LOG_Engine.getLogSetting();
		return setting.EnableTriggerPerformanceLogging__c == true ? (Long)setting.TriggerPerformanceThresholdMs__c : null;
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