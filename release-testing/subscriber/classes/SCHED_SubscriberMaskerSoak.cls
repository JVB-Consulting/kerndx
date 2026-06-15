// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Subscriber-side fixture Schedulable that drives the sustained-masker-soak
 * extended load test. Each cron fire is a fresh transaction so heap, CPU, DML, and SOQL
 * governors reset between iterations — exactly the property that lets the operational
 * 30-min run detect drift across boundaries.
 *
 * On each fire:
 * 1. Inserts INSERT_BATCH_SIZE (50) kern__ApiCall__c records carrying sensitive payload
 *    (Visa 4111... + secret keys) so the framework's BulkRecordMasker fires inline via
 *    TRG_ApiCall + the framework's masking pre-step.
 * 2. Captures iteration index from the persisted ScheduledJobName by counting prior
 *    SOAK_ITERATION rows persisted in kern__LogEntry__c (scoped to this run-stamp via
 *    ClassMethod__c marker), wallMs, cpuMs, soql, dml, heapBytes, and a sample-50 mask
 *    check.
 * 3. Emits one SOAK_ITERATION JSON line via kern.LOG_Builder so the operational verify
 *    script can compute drift across the persisted LogEntry__c rows.
 * 4. After assertions, deletes the 50 just-inserted records (so the org doesn't
 *    accumulate ~1500 rows over 30 min) — bounded LIMIT 9000 for safety.
 * 5. At iteration MAX_ITERATIONS (30), aborts the binding CronTrigger so the soak
 *    stops cleanly without operator intervention.
 *
 * The class is implemented as a plain Schedulable (not kern.IF_Schedulable) because it
 * takes no parameters — the run-stamp + class-method marker are encoded into the cron
 * job name at scheduling time and read back via querying CronTrigger by job name. This
 * matches the SCHED_SubscriberJob fixture pattern: implement the platform interface only.
 *
 * Smoke-test mode: callers can direct-fire `new SCHED_SubscriberMaskerSoak().execute(null)`
 * inside an anon Apex script. With null SchedulableContext the CronTrigger lookup +
 * abort path is short-circuited (gracefully); the iteration-counter falls back to 0
 * (no prior LogEntry__c rows). One iteration runs end-to-end with full assertions.
 *
 * Operational mode: deploy this class, then schedule with
 * `System.schedule('MaskerSoak_<runStamp>', '0 * * * * ? *', new SCHED_SubscriberMaskerSoak());`
 * The cron fires once per minute. After ~30 fires the class self-aborts. If the operator
 * needs to abort early they can call `System.abortJob` on the CronTrigger ID directly.
 *
 * @see release-testing/scripts/load-extended/sustained-masker-soak.apex
 * @see UTIL_FrameworkMasker
 *
 * @group Async
 *
 * @date May 2026
 */
public with sharing class SCHED_SubscriberMaskerSoak implements Schedulable
{
	/**
	 * @description Records inserted per cron fire. Sized to stay well under the 80% heap
	 * gate while still exercising the masker's bulk path (200 evals = 50 records × 2 wildcard
	 * targets × 2 active framework rules).
	 */
	public static final Integer INSERT_BATCH_SIZE = 50;
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
	 * @description Sentinel raw value embedded in the request body. The masker should
	 * replace this with CARD_REDACTED.
	 */
	public static final String VISA_CARD = '4111111111111111';
	/**
	 * @description Expected sentinel after the masker fires.
	 */
	public static final String CARD_REDACTED_SENTINEL = 'CARD_REDACTED';
	/**
	 * @description Failure sentinel the masker writes when a rule explodes. Should never appear.
	 */
	public static final String MASKING_FAILURE_SENTINEL = '[MASKING_FAILURE]';
	/**
	 * @description Prefix used both for the kern__ApiCall__c.kern__ServiceName__c column
	 * (so per-iteration delete is scoped to THIS run) and for the kern__LogEntry__c.kern__ClassMethod__c
	 * marker (so the verify script can find this run's SOAK_ITERATION rows).
	 */
	public static final String SERVICE_NAME_PREFIX = 'MaskerSoak_';
	/**
	 * @description LogEntry ClassMethod marker prefix — paired with run-stamp. The verify
	 * script can ORDER BY CreatedDate ASC and parse the SOAK_ITERATION JSON message body
	 * to compute per-iteration drift (wallMs, cpuMs, heap) across the run.
	 */
	public static final String CLASS_METHOD_PREFIX = 'SCHED_SubscriberMaskerSoak.executeIteration_';

	/**
	 * @description Per-instance run-stamp. Set by the constructor; encoded into both the
	 * ServiceName and the ClassMethod marker so per-iteration cleanup + verify queries are
	 * exactly scoped to this run. Initialized via the no-arg constructor (used by
	 * `System.schedule`) so each scheduled run gets its OWN stamp at construction time;
	 * subsequent fires share it because the platform serializes the instance.
	 */
	private final String runStamp;

	/**
	 * @description No-arg constructor used by `System.schedule(...)` and by anon-Apex
	 * smoke tests via `new SCHED_SubscriberMaskerSoak()`. Sets the run-stamp once at
	 * construction so all subsequent fires of the same scheduled instance share the same
	 * marker — required so the iteration counter can find prior rows.
	 */
	public SCHED_SubscriberMaskerSoak()
	{
		this.runStamp = String.valueOf(System.currentTimeMillis());
	}

	/**
	 * @description Test-visible constructor that injects an explicit run-stamp. Used by
	 * the smoke-test launcher script when it wants the launch script's run-stamp folded
	 * into the persisted markers (so launch + verify share one stamp).
	 *
	 * @param injectedRunStamp The run-stamp to encode into the ServiceName + ClassMethod marker.
	 */
	public SCHED_SubscriberMaskerSoak(String injectedRunStamp)
	{
		this.runStamp = injectedRunStamp;
	}

	/**
	 * @description Returns the run-stamp used by this instance. Allows the launch script
	 * to capture the stamp for later verify-side filtering when it constructed the
	 * Schedulable via the no-arg constructor.
	 *
	 * @return The run-stamp encoded into ServiceName/ClassMethod markers for this run.
	 */
	public String getRunStamp()
	{
		return this.runStamp;
	}

	/**
	 * @description Schedulable entry point. Inserts INSERT_BATCH_SIZE records, captures
	 * per-iteration governor + heap stats, asserts behavioural invariants for the smoke
	 * test, emits SOAK_ITERATION via kern.LOG_Builder, deletes the just-inserted rows,
	 * and self-aborts the CronTrigger at MAX_ITERATIONS.
	 *
	 * @param context The SchedulableContext from the platform. May be null in smoke-test
	 *   mode where the launcher script direct-fires execute(null) — in that case the
	 *   CronTrigger abort path short-circuits gracefully.
	 */
	public void execute(SchedulableContext context)
	{
		kern.TRG_Base.clearAllBypasses();
		kern.UTIL_ValidationRule.clearAllBypasses();

		final String serviceName = SERVICE_NAME_PREFIX + this.runStamp;
		final String classMethodMarker = CLASS_METHOD_PREFIX + this.runStamp;

		Integer iterationIndex = countPriorIterations(classMethodMarker);

		Long startWallMs = System.currentTimeMillis();
		Long startCpuMs = Limits.getCpuTime();
		Integer startSoqlCount = Limits.getQueries();
		Integer startDmlCount = Limits.getDmlStatements();
		Long startHeapBytes = Limits.getHeapSize();

		final String sensitiveRequest = '{"card":"' + VISA_CARD + '","apiKey":"AKIAIOSFODNN7EXAMPLE","password":"hunter2"}';
		final String sensitiveResponse = '{"status":"ok","token":"secret-abc123"}';
		final String sensitiveUrl = 'https://admin:hunter2@api.example.com/soak/' + iterationIndex;

		List<kern__ApiCall__c> bulkRecords = new List<kern__ApiCall__c>();
		for(Integer index = 0; Index < INSERT_BATCH_SIZE; Index++)
		{
			kern__ApiCall__c record = new kern__ApiCall__c();
			record.kern__ServiceName__c = serviceName;
			record.kern__Direction__c = 'Inbound';
			record.kern__Status__c = 'Completed';
			record.kern__Request__c = sensitiveRequest;
			record.kern__Response__c = sensitiveResponse;
			record.kern__URL__c = sensitiveUrl + '_' + Index;
			bulkRecords.add(record);
		}
		insert bulkRecords;

		Long wallMs = System.currentTimeMillis() - startWallMs;
		Long cpuMs = Limits.getCpuTime() - startCpuMs;
		Integer soqlCount = Limits.getQueries() - startSoqlCount;
		Integer dmlCount = Limits.getDmlStatements() - startDmlCount;
		Long endHeapBytes = Limits.getHeapSize();
		Long heapDeltaBytes = endHeapBytes - startHeapBytes;
		Long heapLimitBytes = Limits.getLimitHeapSize();
		Decimal heapFraction = heapLimitBytes == 0 ? 0 : ((Decimal)endHeapBytes / heapLimitBytes);

		Integer persistedCount =
		[
				SELECT COUNT()
				FROM kern__ApiCall__c
				WHERE kern__ServiceName__c = :serviceName
		];

		List<kern__ApiCall__c> sample =
		[
				SELECT Id,
						kern__Request__c,
						kern__Response__c
				FROM kern__ApiCall__c
				WHERE kern__ServiceName__c = :serviceName
				LIMIT 50
		];

		Integer rawCardRetained = 0;
		Integer maskingFailures = 0;
		Integer maskedCount = 0;
		for(kern__ApiCall__c row : sample)
		{
			String requestBody = row.kern__Request__c == null ? '' : row.kern__Request__c;
			String responseBody = row.kern__Response__c == null ? '' : row.kern__Response__c;
			if(requestBody.contains(VISA_CARD))
			{
				rawCardRetained++;
			}
			if(requestBody.contains(MASKING_FAILURE_SENTINEL) || responseBody.contains(MASKING_FAILURE_SENTINEL))
			{
				maskingFailures++;
			}
			if(!requestBody.contains(VISA_CARD) && requestBody.containsIgnoreCase(CARD_REDACTED_SENTINEL))
			{
				maskedCount++;
			}
		}

		Map<String, Object> iterationStats = new Map<String, Object>
		{
				'runStamp' => this.runStamp,
				'iteration' => iterationIndex,
				'maxIterations' => MAX_ITERATIONS,
				'persistedCount' => persistedCount,
				'sampledCount' => sample.size(),
				'maskedCount' => maskedCount,
				'rawCardRetained' => rawCardRetained,
				'maskingFailures' => maskingFailures,
				'wallMs' => wallMs,
				'cpuMs' => cpuMs,
				'soqlCount' => soqlCount,
				'dmlCount' => dmlCount,
				'heapStartBytes' => startHeapBytes,
				'heapEndBytes' => endHeapBytes,
				'heapDeltaBytes' => heapDeltaBytes,
				'heapLimitBytes' => heapLimitBytes,
				'heapFraction' => heapFraction
		};

		kern.LOG_Builder.build()
				.info('SOAK_ITERATION: ' + JSON.serialize(iterationStats))
				.emitAt(classMethodMarker);

		try
		{
			List<kern__ApiCall__c> insertedRows =
			[
					SELECT Id
					FROM kern__ApiCall__c
					WHERE kern__ServiceName__c = :serviceName
					LIMIT 9000
			];
			if(!insertedRows.isEmpty())
			{
				delete insertedRows;
			}
		}
		catch(Exception cleanupError)
		{
			kern.LOG_Builder.build()
					.warn('SOAK_CLEANUP_WARN: ' + cleanupError.getMessage())
					.emitAt(classMethodMarker);
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
						.emitAt(classMethodMarker);
			}
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
	 * @param classMethodMarker The exact ClassMethod marker for this run (CLASS_METHOD_PREFIX + runStamp).
	 *
	 * @return Zero-based iteration index — count of prior SOAK_ITERATION rows persisted to LogEntry__c.
	 */
	private Integer countPriorIterations(String classMethodMarker)
	{
		try
		{
			Integer priorCount =
			[
					SELECT COUNT()
					FROM kern__LogEntry__c
					WHERE kern__ClassMethod__c = :classMethodMarker
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
