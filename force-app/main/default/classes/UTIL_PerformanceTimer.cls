// SPDX-License-Identifier: Apache-2.0
/**
 * @description Timer that extends UTIL_StopWatch with automatic governor-limit tracking and
 * threshold-based performance logging. When `stop()` is called, the timer reads the user's
 * LogSetting__c. If EnablePerformanceLogging__c is on and the elapsed duration is
 * PerformanceThresholdMs__c or longer, it writes a log entry with the CPU, heap, SOQL and DML
 * used while it ran.
 *
 * Code that measured a duration some other way uses the static `logIfThresholdReached` method,
 * which applies the same check.
 *
 * For context-specific variants see {@link UTIL_QueryPerformanceTimer} (database queries) and
 * {@link UTIL_TriggerPerformanceTimer} (trigger actions).
 *
 * @see UTIL_StopWatch
 * @see UTIL_QueryPerformanceTimer
 * @see UTIL_TriggerPerformanceTimer
 * @see UTIL_PerformanceTimer_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, November 2026
 */
public inherited sharing class UTIL_PerformanceTimer extends UTIL_StopWatch
{
	/**
	 * @description The human-readable label for the timed operation, used in log messages.
	 */
	public final String operationName
	{
		get;
		private set;
	}

	/**
	 * @description The dot-separated class and method identifier written to the log entry.
	 */
	public final String classMethod
	{
		get;
		private set;
	}

	/**
	 * @description The CPU time, in milliseconds, the transaction had used when the timer started. The log entry reports the CPU
	 * time used since then.
	 */
	private Integer cpuTimeAtStart;
	/**
	 * @description The heap size, in bytes, the transaction was using when the timer started. The log entry reports how much it
	 * has grown since then.
	 */
	private Integer heapSizeAtStart;
	/**
	 * @description The number of SOQL queries the transaction had run when the timer started. The log entry reports the queries
	 * run since then.
	 */
	private Integer soqlCountAtStart;
	/**
	 * @description The number of DML statements the transaction had run when the timer started. The log entry reports the
	 * statements run since then.
	 */
	private Integer dmlCountAtStart;
	/**
	 * @description The number of rows the transaction had written with DML when the timer started. The log entry reports the rows
	 * written since then.
	 */
	private Integer dmlRowCountAtStart;

	/**
	 * @description Constructs a new timer bound to a specific operation and source location.
	 *
	 * @param operationName Label for the operation (appears in the log message).
	 * @param classMethod Dot-separated class and method (e.g., 'BATCH_Process/execute').
	 */
	public UTIL_PerformanceTimer(String operationName, String classMethod)
	{
		super();
		this.operationName = operationName;
		this.classMethod = classMethod;
	}

	/**
	 * @description Starts the timer and snapshots current governor-limit counters.
	 *
	 * @throws UTIL_Exceptions.IllegalStateException if the timer is already running.
	 */
	public override void start()
	{
		super.start();
		snapshotLimits();
	}

	/**
	 * @description Stops the timer and emits a performance log entry when the configured
	 * threshold is met or exceeded.
	 *
	 * @throws UTIL_Exceptions.IllegalStateException if the timer is not running.
	 */
	public override void stop()
	{
		super.stop();
		emitIfThresholdReached();
	}

	/**
	 * @description Stops the timer without emitting any log. Returns the elapsed duration so
	 * the caller can decide independently whether to log.
	 *
	 * @return Elapsed milliseconds.
	 *
	 * @throws UTIL_Exceptions.IllegalStateException if the timer is not running.
	 */
	public Long stopSilent()
	{
		super.stop();
		return getTime();
	}

	/**
	 * @description Records the current governor-limit values as the baseline for delta calculation.
	 */
	private void snapshotLimits()
	{
		cpuTimeAtStart = UTIL_Limits.cpuTime().used();
		heapSizeAtStart = UTIL_Limits.heapSize().used();
		soqlCountAtStart = UTIL_Limits.soqlQueries().used();
		dmlCountAtStart = UTIL_Limits.dmlStatements().used();
		dmlRowCountAtStart = UTIL_Limits.dmlRows().used();
	}

	/**
	 * @description Writes a performance entry for a duration that was measured somewhere else, when the general performance
	 * settings ask for it. It reads LogSetting__c through LOG_Engine.getLogSetting(). It writes nothing when
	 * EnablePerformanceLogging__c is off. Otherwise it writes the entry when the duration is PerformanceThresholdMs__c or
	 * longer. A blank PerformanceThresholdMs__c writes nothing. stop() uses this same check.
	 *
	 * @param message The headline of the entry.
	 * @param details More detail for the entry, or null.
	 * @param classMethod The dot-separated class and method written to the entry.
	 * @param elapsedMs The measured duration in milliseconds.
	 */
	public static void logIfThresholdReached(String message, String details, String classMethod, Long elapsedMs)
	{
		if(isThresholdReached(elapsedMs))
		{
			LOG_Engine.logPerformance(message, details, classMethod, elapsedMs);
		}
	}

	/**
	 * @description Checks the general performance settings for a duration. It reads LogSetting__c through
	 * LOG_Engine.getLogSetting(). The answer is false when EnablePerformanceLogging__c is off or PerformanceThresholdMs__c
	 * is blank. Otherwise it is true when the duration is PerformanceThresholdMs__c or longer.
	 *
	 * @param elapsedMs The measured duration in milliseconds.
	 *
	 * @return True when a performance entry should be written for this duration.
	 */
	private static Boolean isThresholdReached(Long elapsedMs)
	{
		LogSetting__c setting = LOG_Engine.getLogSetting();

		if(setting.EnablePerformanceLogging__c != true)
		{
			return false;
		}

		Long threshold = (Long)setting.PerformanceThresholdMs__c;

		return elapsedMs >= threshold;
	}

	/**
	 * @description Writes the performance entry for this timer when the general performance settings ask for it. It builds
	 * the headline and the governor-limit details only when the check passes, so a timer that logs nothing does not pay
	 * for them.
	 */
	private void emitIfThresholdReached()
	{
		Long elapsed = getTime();

		if(isThresholdReached(elapsed))
		{
			LOG_Engine.logPerformance(formatSummary(elapsed), formatLimitDeltas(), classMethod, elapsed);
		}
	}

	/**
	 * @description Formats the headline performance message.
	 *
	 * @param elapsed The elapsed time in milliseconds.
	 *
	 * @return Formatted string such as "ProcessRecords completed in 42ms".
	 */
	private String formatSummary(Long elapsed)
	{
		return operationName + ' completed in ' + elapsed + 'ms';
	}

	/**
	 * @description Computes governor-limit deltas and formats them into a single detail line.
	 * Uses Math.max to gracefully handle negative deltas caused by Test.startTest() limit resets.
	 *
	 * @return Formatted string with CPU, heap, SOQL and DML metrics.
	 */
	private String formatLimitDeltas()
	{
		Integer cpu = Math.max(0, UTIL_Limits.cpuTime().used() - cpuTimeAtStart);
		Integer heap = Math.max(0, UTIL_Limits.heapSize().used() - heapSizeAtStart);
		Integer soql = Math.max(0, UTIL_Limits.soqlQueries().used() - soqlCountAtStart);
		Integer dml = Math.max(0, UTIL_Limits.dmlStatements().used() - dmlCountAtStart);
		Integer rows = Math.max(0, UTIL_Limits.dmlRows().used() - dmlRowCountAtStart);

		return 'CPU: ' + cpu + 'ms, Heap: ' + heap + ' bytes, SOQL: ' + soql + ', DML: ' + dml + ' (' + rows + ' rows)';
	}
}