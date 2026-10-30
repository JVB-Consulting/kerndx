// SPDX-License-Identifier: Apache-2.0
/**
 * @description A stopwatch that times data-masking runs and writes a performance log entry when a run is slow.
 * It works like `UTIL_TriggerPerformanceTimer`, `UTIL_QueryPerformanceTimer` and `UTIL_PerformanceTimer`: it
 * extends `UTIL_StopWatch`, records the governor-limit values at start, and on `stop()` writes one summary log
 * entry when every check below passes.
 *
 * **Checks, in the order `emitIfApplicable` runs them:**
 * 1. Recursion guard: an internal `isLogging` flag stops the logging code from being entered again in the same
 *    call stack (an extra safety check that copies `UTIL_TriggerPerformanceTimer.isLogging`).
 * 2. Limit per transaction: once `MAX_LOGS_PER_TRANSACTION` entries have been written in this transaction,
 *    later calls write nothing. This limits the volume when a trigger handler loops out of control, even if
 *    one summary per call is somehow not enforced.
 * 3. Masking a log event: nothing is written when the object being masked is `LogEntryEvent__e`. Otherwise
 *    writing a log would publish a new event, which would run the masker again, in an endless loop.
 * 4. Setting: `LogSetting__c.EnableMaskerPerformanceLogging__c` must be true (a hierarchy setting at the Org,
 *    Profile or User level).
 * 5. Threshold: the elapsed time must be at least `LogSetting__c.MaskerPerformanceThresholdMs__c`.
 *
 * The summary entry carries structured context (sObjectName, recordCount, totalMs, avgMsPerRecord,
 * thresholdMs), so someone looking into a slow save can link it to the masker without adding fields to every
 * masked SObject. Any exception thrown while publishing the log is caught and ignored: timing data must never
 * break the masking the timer measures.
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
 * @date April 2026, October 2026
 *
 * @example
 * ```apex
 * UTIL_MaskerPerformanceTimer timer = new UTIL_MaskerPerformanceTimer('Foobar__c', records.size());
 * timer.start();
 * UTIL_FrameworkMasker.forRecords(records).apply();
 * timer.stop(); // writes a log entry when it is switched on and the threshold is met
 * ```
 */
public inherited sharing class UTIL_MaskerPerformanceTimer extends UTIL_StopWatch
{
	/**
	 * @description The most masker performance log entries written in one transaction. This limits
	 * the volume when a trigger handler loops out of control: once it is reached, later `stop()` calls
	 * write nothing, whatever the threshold.
	 */
	@TestVisible
	private static final Integer MAX_LOGS_PER_TRANSACTION = 10;

	/**
	 * @description Counts how many log entries this timer class has written in the current
	 * transaction. Used with `MAX_LOGS_PER_TRANSACTION` to limit the volume. Like every Apex static,
	 * it starts again at zero in each transaction.
	 */
	@TestVisible
	private static Integer logCountThisTransaction = 0;

	/**
	 * @description An extra safety flag that copies `UTIL_TriggerPerformanceTimer.isLogging`. It stops
	 * the logging code from being entered again within the same call stack. It does not guard across
	 * transactions (statics reset between transactions), and it does not stop the `LogEntryEvent__e`
	 * platform event trigger from running the masker again later, in its own transaction (the check
	 * on `sObjectName` covers that).
	 */
	@TestVisible
	private static Boolean isLogging = false;

	/**
	 * @description Set by a test to force an exception while the log entry is written, so the test can
	 * reach the catch block that protects masking. The logging code (`LOG_Engine.logPerformance`)
	 * handles its own errors and does not throw on the normal path, so no realistic production case
	 * reaches that catch. The catch guards against unexpected platform failures (governor limits, a
	 * full event bus), and this flag is the only way to test it.
	 */
	@TestVisible
	private static Boolean forceEmitFailureForTest = false;

	/**
	 * @description The SObject API name the masker worked on. Used to skip logging when masking
	 * `LogEntryEvent__e`, and included in the log context so slow masking runs can be grouped by
	 * SObject.
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
	 * @description CPU time at start, used to work out how much CPU the run used, for the log detail line.
	 */
	private Integer startCpuTime;

	/**
	 * @description Heap size at start, used to work out how much heap the run used.
	 */
	private Integer startHeapSize;

	/**
	 * @description SOQL query count at start, used to work out how many queries the run made.
	 */
	private Integer startSoqlQueries;

	/**
	 * @description DML statement count at start, used to work out how many DML statements the run made.
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
	 * @description Stops the timer and writes a performance log entry when every check passes: the
	 * limit per transaction is not reached, the object being masked is not `LogEntryEvent__e`, the
	 * setting switches masker logging on, and the elapsed time is at least the configured threshold.
	 *
	 * @throws UTIL_Exceptions.IllegalStateException if the stopwatch is not running
	 */
	public override void stop()
	{
		super.stop();
		emitIfApplicable();
	}

	/**
	 * @description Records the governor-limit values at start, so `stop()` can log how much the run used.
	 */
	private void captureStartMetrics()
	{
		startCpuTime = UTIL_Limits.cpuTime().used();
		startHeapSize = UTIL_Limits.heapSize().used();
		startSoqlQueries = UTIL_Limits.soqlQueries().used();
		startDmlStatements = UTIL_Limits.dmlStatements().used();
	}

	/**
	 * @description Runs every check in order and writes one summary log entry when all of them
	 * pass. Called from `stop()`.
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
			// Timing data must never break masking: ignore any failure to write the log entry.
		}
		finally
		{
			isLogging = false;
		}
	}

	/**
	 * @description Builds and writes the summary performance log entry: structured context plus how
	 * much of each governor limit the run used. Someone looking into a slow save can then link it to
	 * both the SObject and the resources the masker used.
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
		String message = 'Masking on ' + sObjectName + ' (' + recordCount + ' records) exceeded threshold of ' + thresholdMs + 'ms; elapsed ' + elapsedMs + 'ms';
		String details = buildPerformanceDetails(elapsedMs, avgMsPerRecord, thresholdMs);

		String classMethod = UTIL_MaskerPerformanceTimer.class.getName() + '/' + sObjectName;
		LOG_Engine.logPerformance(message, details, classMethod, elapsedMs);
	}

	/**
	 * @description Formats the governor-limit usage and the summary timings into the log detail
	 * line. Uses `Math.max(0, ...)` so a limit reset by `Test.startTest()` never shows as a negative value.
	 *
	 * @param elapsedMs Wall-clock milliseconds the masker spent
	 * @param avgMsPerRecord Average wall-clock ms per record in the batch
	 * @param thresholdMs The threshold the elapsed exceeded
	 *
	 * @return Formatted detail text with the CPU, heap, SOQL and DML used, and the timings in milliseconds
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