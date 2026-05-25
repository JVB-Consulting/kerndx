// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Timer that extends UTIL_StopWatch with automatic governor-limit tracking and
 * threshold-based performance logging. When `stop()` is called the elapsed duration is
 * compared against the user's LogSetting__c threshold; if the threshold is met or
 * exceeded a structured log entry is emitted containing CPU, heap, SOQL and DML deltas.
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
 * @date February 2026, May 2026
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

	private Integer cpuTimeAtStart;
	private Integer heapSizeAtStart;
	private Integer soqlCountAtStart;
	private Integer dmlCountAtStart;
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
		this.cpuTimeAtStart = UTIL_Limits.cpuTime().used();
		this.heapSizeAtStart = UTIL_Limits.heapSize().used();
		this.soqlCountAtStart = UTIL_Limits.soqlQueries().used();
		this.dmlCountAtStart = UTIL_Limits.dmlStatements().used();
		this.dmlRowCountAtStart = UTIL_Limits.dmlRows().used();
	}

	/**
	 * @description Checks the user's performance-logging filter and emits a log entry when
	 * the elapsed time meets or exceeds the threshold.
	 */
	private void emitIfThresholdReached()
	{
		LogSetting__c setting = LOG_Engine.getLogSetting();

		if(setting.EnablePerformanceLogging__c != true)
		{
			return;
		}

		Long elapsed = getTime();
		Long threshold = (Long)setting.PerformanceThresholdMs__c;

		if(elapsed >= threshold)
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