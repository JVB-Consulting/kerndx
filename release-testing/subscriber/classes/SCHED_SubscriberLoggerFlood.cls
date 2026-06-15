// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Subscriber-side fixture Schedulable that drives the sustained-logger-pe-flood
 * extended load test. Each cron fire is a fresh transaction so heap, CPU, DML, and SOQL
 * governors reset between iterations — including the per-tx 150 PublishImmediate cap.
 * Emits EMIT_BATCH_SIZE (100) kern.LOG_Builder.info() calls per fire, each producing one
 * LogEntryEvent__e. This deliberately exercises the un-scoped emit path (each emit is one
 * PublishImmediate DML — the framework's BATCH_SIZE=50 chunking only applies inside scopes
 * per Task 1.7 finding A18). 100 stays well under the 150 cap with margin.
 *
 * On each fire:
 * 1. Computes iteration index by counting prior SOAK_ITERATION rows persisted in
 *    kern__LogEntry__c (scoped to this run-stamp via ClassMethod__c marker).
 * 2. Captures pre-state: wallMs, cpuMs, soql count, dml count, heap bytes.
 * 3. Calls kern.LOG_Builder.startCorrelation() so all 100 emits this iteration share a
 *    single correlationId. The launch tx's RequestId is captured as the expected
 *    TransactionId for this iteration.
 * 4. Emits EMIT_BATCH_SIZE LogEntryEvent__e via kern.LOG_Builder.build().info(...).emitAt(...).
 *    Each emit is one PublishImmediate DML; framework BATCH_SIZE=50 does not apply outside
 *    scopes (Task 1.7 finding A18, LOG_Engine.cls line 44).
 * 5. Captures post-state and emits one SOAK_ITERATION JSON line via kern.LOG_Builder so
 *    the operational verify script can compute drift across iterations.
 * 6. Per-iteration cleanup: deletes prior iteration's persisted FLOOD entries (current
 *    iteration's PEs cannot be deleted in-tx — they have not delivered yet). Bounded
 *    LIMIT 9000 for safety.
 * 7. At iteration MAX_ITERATIONS (30), aborts the binding CronTrigger so the soak stops
 *    cleanly without operator intervention.
 *
 * The class is implemented as a plain Schedulable (not kern.IF_Schedulable) because it
 * takes no parameters — the run-stamp + class-method marker are encoded into the cron job
 * name at scheduling time. Matches the SCHED_SubscriberMaskerSoak fixture pattern.
 *
 * Smoke-test mode: callers can direct-fire `new SCHED_SubscriberLoggerFlood().execute(null)`
 * inside an anon Apex script. With null SchedulableContext the CronTrigger lookup + abort
 * path is short-circuited; the iteration-counter falls back to 0 (no prior LogEntry__c
 * rows). One iteration runs end-to-end, but the 100 emits cannot be observed in the same
 * transaction — Platform Events do not deliver to subscribers until the publishing tx
 * COMMITS. The launch script polls AFTER execute(null) returns + the anon Apex tx commits.
 *
 * Operational mode: deploy this class, then schedule with
 * `System.schedule('LoggerFlood_<runStamp>', '0 * * * * ? *', new SCHED_SubscriberLoggerFlood());`
 * The cron fires once per minute. After ~30 fires the class self-aborts. If the operator
 * needs to abort early they can call `System.abortJob` on the CronTrigger ID directly.
 *
 * Daily PE quota: 30 iterations × 100 emits = 3,000 PE publishes per operational run. The
 * scratch-org daily PE quota typically far exceeds this (50K+), so quota exhaustion is not
 * a realistic risk. The smoke test publishes 100 PEs.
 *
 * @see release-testing/scripts/load-extended/sustained-logger-pe-flood.apex
 * @see LOG_Builder
 * @see LOG_Engine
 *
 * @group Async
 *
 * @date May 2026
 */
public with sharing class SCHED_SubscriberLoggerFlood implements Schedulable
{
	/**
	 * @description Entries emitted per cron fire. Sized to stay well under the 150
	 * PublishImmediate per-tx governor (Task 1.7 finding A18 — non-scoped emits each cost
	 * one PublishImmediate DML; framework BATCH_SIZE=50 only applies inside scopes). 100
	 * matches section-50 baseline; 50 of headroom under the cap.
	 */
	public static final Integer EMIT_BATCH_SIZE = 100;
	/**
	 * @description Operational cap on iterations. After this iteration index, the cron
	 * is aborted by the running fire. Matches the extended-load spec §9.3 (30 min × 1 fire/min).
	 */
	public static final Integer MAX_ITERATIONS = 30;
	/**
	 * @description Heap headroom gate — Limits.getHeapSize() must stay below this fraction
	 * of Limits.getLimitHeapSize() at end-of-iteration. Per the extended-load spec §9.3 drift signal.
	 */
	public static final Decimal HEAP_GATE_FRACTION = 0.80;
	/**
	 * @description Prefix used for the kern__LogEntry__c.kern__ClassMethod__c marker on
	 * the FLOOD entries (the 100 per-iteration emits). Each emit's classMethod is built as
	 * FLOOD_CLASS_METHOD_PREFIX + runStamp + '/iter' + iterationIndex so cumulative + per-iteration
	 * verify queries can scope to this run.
	 */
	public static final String FLOOD_CLASS_METHOD_PREFIX = 'SCHED_SubscriberLoggerFlood.flood_';
	/**
	 * @description LogEntry ClassMethod marker prefix for the SOAK_ITERATION row. The verify
	 * script can ORDER BY CreatedDate ASC and parse the SOAK_ITERATION JSON message body to
	 * compute per-iteration drift (wallMs, cpuMs, heap, persisted count) across the run.
	 */
	public static final String CLASS_METHOD_PREFIX = 'SCHED_SubscriberLoggerFlood.executeIteration_';

	/**
	 * @description Per-instance run-stamp. Set by the constructor; encoded into both the
	 * FLOOD ClassMethod__c marker and the SOAK_ITERATION ClassMethod__c marker so per-iteration
	 * cleanup + verify queries are exactly scoped to this run. Initialized via the no-arg
	 * constructor (used by `System.schedule`) so each scheduled run gets its OWN stamp at
	 * construction time; subsequent fires share it because the platform serializes the instance.
	 */
	private final String runStamp;

	/**
	 * @description No-arg constructor used by `System.schedule(...)` and by anon-Apex
	 * smoke tests via `new SCHED_SubscriberLoggerFlood()`. Sets the run-stamp once at
	 * construction so all subsequent fires of the same scheduled instance share the same
	 * marker — required so the iteration counter can find prior rows.
	 */
	public SCHED_SubscriberLoggerFlood()
	{
		this.runStamp = String.valueOf(System.currentTimeMillis());
	}

	/**
	 * @description Test-visible constructor that injects an explicit run-stamp. Used by
	 * the smoke-test launcher script when it wants the launch script's run-stamp folded
	 * into the persisted markers (so launch + verify share one stamp).
	 *
	 * @param injectedRunStamp The run-stamp to encode into the ClassMethod markers.
	 */
	public SCHED_SubscriberLoggerFlood(String injectedRunStamp)
	{
		this.runStamp = injectedRunStamp;
	}

	/**
	 * @description Returns the run-stamp used by this instance. Allows the launch script
	 * to capture the stamp for later verify-side filtering when it constructed the
	 * Schedulable via the no-arg constructor.
	 *
	 * @return The run-stamp encoded into the ClassMethod markers for this run.
	 */
	public String getRunStamp()
	{
		return this.runStamp;
	}

	/**
	 * @description Returns the LogEntry__c.ClassMethod__c marker used by the FLOOD entries
	 * for the given iteration index. Allows the launch script to construct the polling
	 * predicate without duplicating the marker convention.
	 *
	 * @param iterationIndex The zero-based iteration index.
	 *
	 * @return The fully-formed ClassMethod__c marker for FLOOD entries from that iteration.
	 */
	public String buildFloodClassMethodMarker(Integer iterationIndex)
	{
		return FLOOD_CLASS_METHOD_PREFIX + this.runStamp + '/iter' + iterationIndex;
	}

	/**
	 * @description Returns the LogEntry__c.ClassMethod__c marker for the SOAK_ITERATION
	 * summary row. Allows the launch script to scope its SOAK_ITERATION poll to this run.
	 *
	 * @return The ClassMethod__c marker for SOAK_ITERATION rows from this run.
	 */
	public String buildSoakIterationClassMethodMarker()
	{
		return CLASS_METHOD_PREFIX + this.runStamp;
	}

	/**
	 * @description Schedulable entry point. Computes iteration index, starts a correlation,
	 * captures pre-state, emits EMIT_BATCH_SIZE LogEntryEvent__e via kern.LOG_Builder, captures
	 * post-state, emits one SOAK_ITERATION row via kern.LOG_Builder, deletes prior iteration's
	 * persisted FLOOD entries, and self-aborts the CronTrigger at MAX_ITERATIONS.
	 *
	 * @param context The SchedulableContext from the platform. May be null in smoke-test
	 *   mode where the launcher script direct-fires execute(null) — in that case the
	 *   CronTrigger abort path short-circuits gracefully.
	 */
	public void execute(SchedulableContext context)
	{
		kern.TRG_Base.clearAllBypasses();
		kern.UTIL_ValidationRule.clearAllBypasses();

		final String soakIterationMarker = CLASS_METHOD_PREFIX + this.runStamp;

		Integer iterationIndex = countPriorIterations(soakIterationMarker);

		final String floodClassMethodMarker = FLOOD_CLASS_METHOD_PREFIX + this.runStamp + '/iter' + iterationIndex;
		final String correlationId = kern.LOG_Builder.startCorrelation();
		final String transactionId = Request.getCurrent().getRequestId();

		Long startWallMs = System.currentTimeMillis();
		Long startCpuMs = Limits.getCpuTime();
		Integer startSoqlCount = Limits.getQueries();
		Integer startDmlCount = Limits.getDmlStatements();
		Integer startPublishImmediateCount = Limits.getPublishImmediateDML();
		Long startHeapBytes = Limits.getHeapSize();

		for(Integer index = 0; Index < EMIT_BATCH_SIZE; Index++)
		{
			kern.LOG_Builder.build()
					.info('FLOOD_ENTRY iteration=' + iterationIndex + ' index=' + Index + ' runStamp=' + this.runStamp)
					.emitAt(floodClassMethodMarker);
		}

		Long wallMs = System.currentTimeMillis() - startWallMs;
		Long cpuMs = Limits.getCpuTime() - startCpuMs;
		Integer soqlCount = Limits.getQueries() - startSoqlCount;
		Integer dmlCount = Limits.getDmlStatements() - startDmlCount;
		Integer publishImmediateCount = Limits.getPublishImmediateDML() - startPublishImmediateCount;
		Long endHeapBytes = Limits.getHeapSize();
		Long heapDeltaBytes = endHeapBytes - startHeapBytes;
		Long heapLimitBytes = Limits.getLimitHeapSize();
		Decimal heapFraction = heapLimitBytes == 0 ? 0 : ((Decimal)endHeapBytes / heapLimitBytes);

		Map<String, Object> iterationStats = new Map<String, Object>
		{
				'runStamp' => this.runStamp,
				'iteration' => iterationIndex,
				'maxIterations' => MAX_ITERATIONS,
				'emitCount' => EMIT_BATCH_SIZE,
				'correlationId' => correlationId,
				'transactionId' => transactionId,
				'floodClassMethodMarker' => floodClassMethodMarker,
				'wallMs' => wallMs,
				'cpuMs' => cpuMs,
				'soqlCount' => soqlCount,
				'dmlCount' => dmlCount,
				'publishImmediateCount' => publishImmediateCount,
				'heapStartBytes' => startHeapBytes,
				'heapEndBytes' => endHeapBytes,
				'heapDeltaBytes' => heapDeltaBytes,
				'heapLimitBytes' => heapLimitBytes,
				'heapFraction' => heapFraction
		};

		kern.LOG_Builder.build()
				.info('SOAK_ITERATION: ' + JSON.serialize(iterationStats))
				.emitAt(soakIterationMarker);

		try
		{
			deletePriorIterationFloodEntries(iterationIndex, soakIterationMarker);
		}
		catch(Exception cleanupError)
		{
			kern.LOG_Builder.build()
					.warn('SOAK_CLEANUP_WARN: ' + cleanupError.getMessage())
					.emitAt(soakIterationMarker);
		}

		Boolean atTerminalIteration = iterationIndex >= (MAX_ITERATIONS - 1);
		if(atTerminalIteration && context != null)
		{
			try
			{
				System.abortJob(context.getTriggerId());
			}
			catch(Exception abortError)
			{
				kern.LOG_Builder.build()
						.warn('SOAK_ABORT_WARN: ' + abortError.getMessage())
						.emitAt(soakIterationMarker);
			}
		}
	}

	/**
	 * @description Deletes the PRIOR iteration's FLOOD entries from kern__LogEntry__c. The
	 * current iteration's FLOOD entries cannot be deleted in-tx because PE delivery is
	 * async — they have not been persisted yet at this point in execution. By the time this
	 * fire runs (cron fires once per minute), the PRIOR iteration's PEs have had ~60 s to
	 * deliver and persist, so they ARE in kern__LogEntry__c and can be deleted.
	 *
	 * Iteration 0 has no prior iteration to clean — no-op. Iteration N>0 deletes entries
	 * scoped by the prior iteration's flood marker. This keeps the steady-state row count
	 * bounded at ~200 (one iteration's entries pending delivery + one fully-persisted
	 * iteration awaiting its successor's cleanup) instead of growing linearly to 3,000+
	 * over a 30-min run.
	 *
	 * The SOAK_ITERATION rows are NOT cleaned per-iteration — they're the drift signal the
	 * verify script reads, so they must accumulate for the duration of the run. Final
	 * cleanup of SOAK_ITERATION rows + the very last iteration's FLOOD rows is the
	 * operator's responsibility (documented in the launch-script header).
	 *
	 * @param currentIterationIndex The zero-based iteration index of THIS fire.
	 * @param soakIterationMarker The SOAK_ITERATION ClassMethod marker for warn-log emission.
	 */
	private void deletePriorIterationFloodEntries(Integer currentIterationIndex, String soakIterationMarker)
	{
		if(currentIterationIndex <= 0)
		{
			return;
		}
		String priorFloodMarker = FLOOD_CLASS_METHOD_PREFIX + this.runStamp + '/iter' + (currentIterationIndex - 1);
		List<kern__LogEntry__c> priorFloodEntries =
		[
				SELECT Id
				FROM kern__LogEntry__c
				WHERE kern__ClassMethod__c = :priorFloodMarker
				LIMIT 9000
		];
		if(!priorFloodEntries.isEmpty())
		{
			delete priorFloodEntries;
		}
	}

	/**
	 * @description Counts persisted SOAK_ITERATION rows in kern__LogEntry__c scoped to this
	 * run-stamp's ClassMethod marker. Used as the iteration index for THIS fire (zero-based).
	 *
	 * Note: the platform-event-based logger means prior fires' rows MUST have already been
	 * delivered + persisted before this fire runs. Each cron fire is its own transaction
	 * separated by ~60 s — far longer than typical PE delivery latency (~1-5 s). If the
	 * platform-event delivery lags more than 60 s the iteration counter would undercount,
	 * but this is a known scratch-org constraint documented in the launch-script header.
	 *
	 * @param soakIterationMarker The exact ClassMethod marker for this run (CLASS_METHOD_PREFIX + runStamp).
	 *
	 * @return Zero-based iteration index — count of prior SOAK_ITERATION rows persisted to LogEntry__c.
	 */
	private Integer countPriorIterations(String soakIterationMarker)
	{
		try
		{
			Integer priorCount =
			[
					SELECT COUNT()
					FROM kern__LogEntry__c
					WHERE kern__ClassMethod__c = :soakIterationMarker
					AND kern__ShortMessage__c LIKE 'SOAK_ITERATION:%'
			];
			return priorCount;
		}
		catch(Exception queryError)
		{
			return 0;
		}
	}
}
