// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A stopwatch for timing data-masking runs with automatic threshold-gated
 * performance logging. Mirrors `UTIL_TriggerPerformanceTimer` / `UTIL_QueryPerformanceTimer`
 * / `UTIL_PerformanceTimer` — extends `UTIL_StopWatch`, captures governor-limit deltas at
 * start, and on `stop()` emits a single aggregate log entry when every gate passes.
 *
 * **Gate chain (in order of execution in `emitIfApplicable`):**
 * 1. Recursion guard — internal `isLogging` flag prevents synchronous re-entry into the
 *    logging pipeline within the same call stack (belt-and-braces mirror of
 *    `UTIL_TriggerPerformanceTimer.isLogging`).
 * 2. Per-transaction cap — once `MAX_LOGS_PER_TRANSACTION` entries have been emitted this
 *    transaction, subsequent invocations skip emission. Caps volume on runaway trigger
 *    handler loops even if aggregation-per-invocation is somehow bypassed.
 * 3. Re-entrance — emission is skipped when the object being masked is `LogEntryEvent__e`,
 *    otherwise emitting a log would publish a new event that re-enters the masker and loops.
 * 4. Settings enable flag — `LogSetting__c.EnableMaskerPerformanceLogging__c` must be true
 *    (hierarchical Org / Profile / User setting).
 * 5. Threshold — elapsed must meet or exceed `LogSetting__c.MaskerPerformanceThresholdMs__c`.
 *
 * The aggregate emission carries structured context (sObjectName, recordCount, totalMs,
 * avgMsPerRecord, thresholdMs) so investigators can correlate a slow commit to the masker
 * without per-object fields on every masked SObject. Any exception raised while publishing
 * the log is swallowed — telemetry must never break the masking pipeline the timer wraps.
 *
 * @see UTIL_StopWatch
 * @see UTIL_TriggerPerformanceTimer
 * @see UTIL_QueryPerformanceTimer
 * @see UTIL_PerformanceTimer
 * @see UTIL_MaskerPerformanceTimer_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date April 2026, May 2026
 *
 * @example
 * ```apex
 * UTIL_MaskerPerformanceTimer timer = new UTIL_MaskerPerformanceTimer('Foobar__c', records.size());
 * timer.start();
 * UTIL_FrameworkMasker.forRecords(records).apply();
 * timer.stop(); // auto-emits if configured + threshold met
 * ```
 */
public inherited sharing class UTIL_MaskerPerformanceTimer extends UTIL_StopWatch
{
	/**
	 * @description Ceiling on the number of masker performance log entries emitted per
	 * transaction. Caps runaway emission from a trigger-handler loop — once hit, subsequent
	 * `stop()` calls skip emission regardless of threshold.
	 */
	@TestVisible
	private static final Integer MAX_LOGS_PER_TRANSACTION = 10;

	/**
	 * @description Per-transaction counter tracking how many log entries this timer class
	 * has emitted. Paired with `MAX_LOGS_PER_TRANSACTION` to cap volume. Resets between
	 * transactions per Apex static semantics.
	 */
	@TestVisible
	private static Integer logCountThisTransaction = 0;

	/**
	 * @description Belt-and-braces mirror of `UTIL_TriggerPerformanceTimer.isLogging`. Defends
	 * against synchronous re-entry of the logging pipeline within the same call stack — not a
	 * cross-transaction guard (statics reset between transactions) and not a defence against
	 * async re-entry from the `LogEntryEvent__e` platform event trigger (the re-entrance gate
	 * on `sObjectName` covers that).
	 */
	@TestVisible
	private static Boolean isLogging = false;

	/**
	 * @description Test seam to force an exception during emission for exercising the defensive
	 * catch block. The emit pipeline (`LOG_Engine.logPerformance`) has its own internal error
	 * handling and does not surface exceptions on the hot path, so no realistic production
	 * scenario reaches the telemetry-swallow catch. The catch exists as a guard against
	 * unexpected platform-level failures (governor limits, event bus saturation) and must be
	 * tested via this seam.
	 */
	@TestVisible
	private static Boolean forceEmitFailureForTest = false;

	/**
	 * @description The SObject API name the masker operated on. Used for the re-entrance
	 * guard (skip emission when masking `LogEntryEvent__e`) and included in the emitted log
	 * context so investigators can group slow masks by target SObject.
	 */
	public final String sObjectName
	{
		get;
		private set;
	}

	/**
	 * @description Number of records in the trigger batch being masked. Included in the
	 * emitted log context and used to compute `avgMsPerRecord`.
	 */
	public final Integer recordCount
	{
		get;
		private set;
	}

	/**
	 * @description Starting CPU time for delta calculation in the emitted log detail line.
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
	 * @description Creates a masker performance timer bound to the current trigger context.
	 *
	 * @param sObjectName The SObject API name being masked (e.g., 'Foobar__c')
	 * @param recordCount Number of records in the trigger batch
	 */
	public UTIL_MaskerPerformanceTimer(String sObjectName, Integer recordCount)
	{
		super();
		this.sObjectName = sObjectName;
		this.recordCount = recordCount;
	}

	/**
	 * @description Starts the timer and captures initial governor-limit values.
	 *
	 * @throws UTIL_Exceptions.IllegalStateException if the stopwatch is already started
	 */
	public override void start()
	{
		super.start();
		captureStartMetrics();
	}

	/**
	 * @description Stops the timer and automatically emits a performance log entry if every
	 * gate passes: emission cap not reached, not re-entering on `LogEntryEvent__e`, settings
	 * enable masker logging, elapsed meets or exceeds the configured threshold.
	 *
	 * @throws UTIL_Exceptions.IllegalStateException if the stopwatch is not running
	 */
	public override void stop()
	{
		super.stop();
		emitIfApplicable();
	}

	/**
	 * @description Captures governor-limit baseline values so `stop()` can emit deltas.
	 */
	private void captureStartMetrics()
	{
		startCpuTime = UTIL_Limits.cpuTime().used();
		startHeapSize = UTIL_Limits.heapSize().used();
		startSoqlQueries = UTIL_Limits.soqlQueries().used();
		startDmlStatements = UTIL_Limits.dmlStatements().used();
	}

	/**
	 * @description Runs the full gate chain and emits a single aggregate log entry when all
	 * gates pass. Called from `stop()`.
	 */
	@SuppressWarnings('PMD.EmptyCatchBlock')
	private void emitIfApplicable()
	{
		if(isLogging)
		{
			return;
		}
		if(logCountThisTransaction >= MAX_LOGS_PER_TRANSACTION)
		{
			return;
		}

		String logEntryEventName = UTIL_SObjectDescribe.getObjectNameFromType(LogEntryEvent__e.SObjectType);
		if(sObjectName == logEntryEventName)
		{
			return;
		}

		LogSetting__c setting = LOG_Engine.getLogSetting();
		if(setting == null || setting.EnableMaskerPerformanceLogging__c != true)
		{
			return;
		}

		Long elapsedMs = getTime();
		Decimal thresholdMs = setting.MaskerPerformanceThresholdMs__c;
		if(thresholdMs == null || elapsedMs < thresholdMs)
		{
			return;
		}

		try
		{
			isLogging = true;
			logCountThisTransaction++;
			emitPerformanceLog(elapsedMs, (Long)thresholdMs);
		}
		catch(Exception telemetryError)
		{
			// Telemetry must never break the masking pipeline — swallow any emit failure.
		}
		finally
		{
			isLogging = false;
		}
	}

	/**
	 * @description Builds and emits the aggregate performance log entry. Structured context
	 * plus governor-limit deltas, so investigators can correlate a slow commit to both the
	 * target SObject and the resource envelope the masker consumed.
	 *
	 * @param elapsedMs Wall-clock milliseconds the masker spent on this trigger invocation
	 * @param thresholdMs The threshold the elapsed duration exceeded
	 */
	private void emitPerformanceLog(Long elapsedMs, Long thresholdMs)
	{
		if(forceEmitFailureForTest)
		{
			throw new UTIL_Exceptions.IllegalStateException('Forced test exception');
		}

		Long avgMsPerRecord = recordCount > 0 ? elapsedMs / recordCount : elapsedMs;
		String message = 'Masking on ' + sObjectName + ' (' + recordCount + ' records) exceeded threshold of ' + thresholdMs + 'ms — elapsed ' + elapsedMs + 'ms';
		String details = buildPerformanceDetails(elapsedMs, avgMsPerRecord, thresholdMs);

		String classMethod = UTIL_MaskerPerformanceTimer.class.getName() + '/' + sObjectName;
		LOG_Engine.logPerformance(message, details, classMethod, elapsedMs);
	}

	/**
	 * @description Formats the governor-limit deltas + aggregate stats into the log detail
	 * line. Uses `Math.max(0, ...)` to gracefully handle `Test.startTest()` limit resets.
	 *
	 * @param elapsedMs Wall-clock milliseconds the masker spent
	 * @param avgMsPerRecord Average wall-clock ms per record in the batch
	 * @param thresholdMs The threshold the elapsed exceeded
	 *
	 * @return Formatted detail string with CPU, heap, SOQL, DML deltas + aggregate ms values
	 */
	private String buildPerformanceDetails(Long elapsedMs, Long avgMsPerRecord, Long thresholdMs)
	{
		Integer cpuUsed = Math.max(0, UTIL_Limits.cpuTime().used() - startCpuTime);
		Integer heapUsed = Math.max(0, UTIL_Limits.heapSize().used() - startHeapSize);
		Integer soqlUsed = Math.max(0, UTIL_Limits.soqlQueries().used() - startSoqlQueries);
		Integer dmlUsed = Math.max(0, UTIL_Limits.dmlStatements().used() - startDmlStatements);

		return 'sObject: ' + sObjectName + ', Records: ' + recordCount
				+ ', TotalMs: ' + elapsedMs + ', AvgMsPerRecord: ' + avgMsPerRecord + ', ThresholdMs: ' + thresholdMs
				+ ', CPU: ' + cpuUsed + 'ms, Heap: ' + heapUsed + ' bytes, SOQL: ' + soqlUsed + ', DML: ' + dmlUsed;
	}
}