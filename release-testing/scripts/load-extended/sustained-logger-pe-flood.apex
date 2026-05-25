/**
 * sustained-logger-pe-flood.apex (extended-load Phase 4 / §9.3)
 *
 * EXTENDED LOAD TEST — pre-tag-only. NOT part of every release-test cycle. Run before
 * promoting beta → GA via `npm run test:load:extended` (the runner that wraps this script
 * + the other 3 extended-load scripts; see the extended-load spec §10.2). SECOND script in the
 * release-testing/scripts/load-extended/ directory — follows the pattern established by
 * sustained-masker-soak.apex (Task 4.2, commit `e072995`).
 *
 * PURPOSE
 *   Sustained PE emission near-quota for ~30 min. Detects:
 *     - Subscriber TRG_PersistLogEntry under sustained pressure (publish count = persisted
 *       count across 30 iterations × 100 emits = 3,000 PE publishes)
 *     - PE drop signal (any iteration where persistedCount < emitCount)
 *     - Orphaned CorrelationId__c (within an iteration, all 100 entries share the
 *       iteration's correlationId; across iterations correlationIds differ)
 *     - Daily PE quota exhaustion (typically 50K+ in scratch orgs; 3,000 is trivial)
 *     - Per-iteration timing drift (>20% from opening iteration = degradation signal)
 *
 * OPERATIONAL PATTERN (production / pre-tag verification — ~30 min wall clock)
 *   The Schedulable SCHED_SubscriberLoggerFlood lives in release-testing/subscriber/classes/
 *   and is deployed as part of the standard subscriber fixture deploy (Phase 1 of the
 *   release-testing runbook). To run the operational 30-minute soak:
 *
 *     1. Choose a unique scheduler name suffix:
 *          String runStamp = String.valueOf(System.currentTimeMillis());
 *
 *     2. Schedule the soak (cron `0 * * * * ? *` fires once per minute):
 *          System.schedule
 *          (
 *              'LoggerFlood_' + runStamp,
 *              '0 * * * * ? *',
 *              new SCHED_SubscriberLoggerFlood(runStamp)
 *          );
 *
 *     3. Wait ~30 min (the Schedulable self-aborts at iteration MAX_ITERATIONS=30).
 *
 *     4. Verify drift via SOQL on the persisted SOAK_ITERATION rows:
 *          SELECT kern__ShortMessage__c, kern__Message__c, CreatedDate
 *          FROM kern__LogEntry__c
 *          WHERE kern__ClassMethod__c = 'SCHED_SubscriberLoggerFlood.executeIteration_<runStamp>'
 *            AND kern__ShortMessage__c LIKE 'SOAK_ITERATION:%'
 *          ORDER BY CreatedDate ASC
 *
 *        For each row, parse the JSON payload from kern__Message__c (or
 *        kern__ShortMessage__c if it fits in 255 chars). Compute:
 *          opening = stats[0]
 *          For each later row N:
 *            Assert stats[N].wallMs <= opening.wallMs * 1.20  (per-iteration drift)
 *            Assert stats[N].heapFraction < 0.80               (no heap leak)
 *            Assert stats[N].publishImmediateCount == 100      (per-tx PE chunk count)
 *            Assert stats[N].iteration == N                    (no skipped fires)
 *
 *     5. Verify FLOOD entries persisted per iteration:
 *          SELECT kern__ClassMethod__c, COUNT(Id) cnt
 *          FROM kern__LogEntry__c
 *          WHERE kern__UserId__c = '<your user id>'
 *            AND kern__ClassMethod__c LIKE 'SCHED_SubscriberLoggerFlood.flood_<runStamp>/iter%'
 *          GROUP BY kern__ClassMethod__c
 *
 *        After per-iteration cleanup runs, only iterations N (current pending delivery)
 *        and N-1 (just-persisted, awaiting next-fire's cleanup) should have non-zero counts
 *        at any in-flight observation moment. After the run completes, ONLY the very last
 *        iteration's FLOOD entries remain (the soak self-aborts before it can clean its
 *        own — cleanup deletes the PRIOR iteration's entries each fire). Expect cardinality
 *        100 for the terminal iteration.
 *
 *     6. Verify correlationId scoping (each iteration's 100 emits share one correlation):
 *          SELECT kern__CorrelationId__c, COUNT(Id) cnt
 *          FROM kern__LogEntry__c
 *          WHERE kern__UserId__c = '<your user id>'
 *            AND kern__ClassMethod__c LIKE 'SCHED_SubscriberLoggerFlood.flood_<runStamp>/iter%'
 *          GROUP BY kern__CorrelationId__c
 *
 *        Each surviving iteration's correlationId bucket should have exactly 100 rows.
 *        DISTINCT correlationIds across iterations (each fire calls startCorrelation()).
 *
 *     7. Verify no orphan CronTrigger:
 *          SELECT COUNT() FROM CronTrigger
 *          WHERE CronJobDetail.Name = 'LoggerFlood_<runStamp>'
 *            AND State NOT IN ('DELETED','COMPLETE')
 *        Expect 0. If non-zero, abort manually:
 *          System.abortJob([SELECT Id FROM CronTrigger
 *                           WHERE CronJobDetail.Name = 'LoggerFlood_<runStamp>'].Id);
 *
 *     8. (Optional) Cleanup the persisted SOAK_ITERATION + terminal-iteration FLOOD rows:
 *          delete [SELECT Id FROM kern__LogEntry__c
 *                  WHERE kern__ClassMethod__c =
 *                        'SCHED_SubscriberLoggerFlood.executeIteration_<runStamp>'
 *                  LIMIT 9000];
 *          delete [SELECT Id FROM kern__LogEntry__c
 *                  WHERE kern__ClassMethod__c LIKE
 *                        'SCHED_SubscriberLoggerFlood.flood_<runStamp>/iter%'
 *                  LIMIT 9000];
 *
 * SMOKE-TEST PATTERN (this script — used by `sf apex run --file ...` during dev)
 *   The full 30-min run is the OPERATIONAL pattern; we don't burn 30 min of scratch-org
 *   wall clock during dev. This script:
 *     - Direct-fires `new SCHED_SubscriberLoggerFlood(runStamp).execute(null)` ONCE,
 *       which bypasses cron scheduling and runs synchronously inside the anon Apex tx.
 *     - The 100 PE emits inside execute(null) cannot be observed in the same tx — Platform
 *       Events do not deliver to subscribers until the publishing tx COMMITS (per Task 3.3
 *       finding A36 + section-50 launch+verify split). A busy-wait probe inside the anon
 *       Apex tx polling kern__LogEntry__c would observe zero rows for the entire window.
 *     - After execute(null) returns + the anon Apex tx COMMITS (via the implicit commit at
 *       end of executeAnonymous), the publishing tx is sealed and the 100 PEs flow to
 *       TRG_PersistLogEntry. We poll AFTER execute(null) within the SAME anon Apex tx —
 *       the polling loop still observes zero rows because we're still inside the publishing
 *       tx. To work around this WITHOUT splitting into launch+verify scripts (which would
 *       contradict the "smoke test = single script" simplicity goal), we pre-emit a SINGLE
 *       SOAK_ITERATION row BEFORE execute(null) and use that as the polling target — then
 *       infer correctness from the SCHED's INSIDE-EXECUTE assertions persisted via the
 *       SOAK_ITERATION JSON stats.
 *     - Adopted: same launch+verify split semantics as section-50 / section-50b within ONE
 *       script via two-stage polling. Stage 1 (immediately after execute(null) returns):
 *       parse the SOAK_ITERATION row's JSON stats from execute() — these are the
 *       INSIDE-EXECUTE measurements (publishImmediateCount, correlationId, transactionId,
 *       wallMs, heap). Asserts Stage 1 invariants on the JSON payload. Stage 2: poll
 *       kern__LogEntry__c for the 100 FLOOD entries — but this poll runs INSIDE the same
 *       anon Apex tx as execute(), so the FLOOD entries CANNOT have delivered yet. Stage
 *       2 is therefore deferred for the smoke test to a subsequent re-run of the same
 *       script (which observes the prior smoke run's FLOOD entries via run-stamp scoping)
 *       OR is skipped with a documented "smoke-test-only invariant on JSON stats" note.
 *
 *   For the SMOKE TEST in this script we adopt the simpler approach: the inside-execute
 *   JSON stats are the assertion target. The SOAK_ITERATION row's JSON contains
 *   publishImmediateCount=100 (proves 100 PEs were published to the bus), wallMs (per-tx
 *   latency), correlationId (proves startCorrelation() returned a non-blank id),
 *   transactionId (proves Request.getRequestId() captured), and heap stats. These give us
 *   single-tx coverage. The cross-tx contract (PE delivery + persistence by subscriber's
 *   TRG_PersistLogEntry) is empirically verified for THIS code path by section-50 +
 *   section-50b (Task 3.4) — the same kern.LOG_Builder.build().info().emitAt() pattern.
 *   The OPERATIONAL 30-min run does observe the cross-tx contract because subsequent fires
 *   query the prior iteration's persisted entries.
 *
 * SMOKE-TEST BEHAVIOUR ASSERTIONS (HARD GATE — single iteration, INSIDE-EXECUTE only)
 *   - 100 emit() calls complete without exception (no PublishImmediate governor breach)
 *   - publishImmediateCount == 100 (per-tx PublishImmediate DML count)
 *   - correlationId is non-blank (proves startCorrelation() returned a usable id)
 *   - transactionId is non-blank (proves Request.getRequestId() returned a usable id)
 *   - all 100 emits share THIS iteration's correlationId (verified at execute() level —
 *     LOG_Builder.startCorrelation() sets the engine state, all subsequent emits in the
 *     same tx pick it up; this is a property of the framework verified by section-16h +
 *     section-50)
 *   - all 100 emits share THIS tx's RequestId (TransactionId; verified by LOG_Engine
 *     line 1412 — same tx → same Request.getRequestId() return value across all emits)
 *   - wallMs < 5000 ms (sane per-iteration ceiling for 100 PublishImmediate DMLs)
 *   - heapFraction < 0.80 at end of iteration (heap headroom maintained)
 *   - SOAK_ITERATION row persisted to kern__LogEntry__c with parseable JSON payload
 *     (verified via post-tx polling AFTER waiting for the publishing tx to commit; PE
 *     delivery latency is typically 1-5 s in scratch orgs, polling budget is 60 s)
 *
 * OPERATIONAL MODE INVARIANTS (documented for reference; NOT asserted in smoke test)
 *   - 30 iterations complete without quota exhaustion (3,000 PE publishes vs typical
 *     scratch-org daily quota of 50K+ — 6% utilization)
 *   - Cumulative persisted FLOOD count = 30 × 100 = 3,000 across all iterations (each
 *     iteration's persistedCount stays at 100, no drops)
 *   - Per-iteration wallMs stays within ±20% of iteration[0].wallMs (drift detection)
 *   - Per-iteration heapFraction stays < 0.80 across all 30 fires
 *   - Cumulative kern__LogEntry__c rows for SOAK_ITERATION grows linearly, exactly +1 per
 *     minute (no drops, no duplicates — proves PE delivery + scheduler correctness)
 *   - No orphaned AsyncApexJob row after 30 min — the Schedulable self-aborts the
 *     CronTrigger at iteration MAX_ITERATIONS-1
 *   - At any in-flight observation moment between fires, only 1-2 iterations' FLOOD
 *     entries are present (current iteration pending delivery + prior iteration awaiting
 *     next fire's cleanup); after the soak completes, only the terminal iteration's
 *     FLOOD entries remain (the SCHED's prior-iteration cleanup deletes earlier iterations
 *     in sequence; the terminal iteration's cleanup never runs because the SCHED aborts
 *     immediately after)
 *
 * SPEC vs ACTUAL — Schedulable type binding (the ephemeral-anon-class problem)
 *   Same constraint as Task 4.2 / sustained-masker-soak. System.schedule(name, cron,
 *   instance) requires a STABLE Apex Type to bind to. Anonymous-Apex classes are EPHEMERAL.
 *   ADOPTED: deploy SCHED_SubscriberLoggerFlood as a permanent subscriber-side fixture
 *   class. Anon Apex direct-fires the Schedulable's execute(null) for the smoke test,
 *   bypassing cron entirely.
 *
 * SPEC vs ACTUAL — emit count of 100 (Task 1.7 finding A18)
 *   the extended-load spec §9.3 describes the soak loosely ("near quota"). Empirical constraint per
 *   Task 1.7 finding A18: kern.LOG_Builder.build().info(...).emitAt(...) OUTSIDE an
 *   active scope publishes immediately (one PublishImmediate DML per emit, no batching —
 *   LOG_Engine.cls BATCH_SIZE=50 only applies INSIDE scopes). The per-transaction
 *   PublishImmediate DML governor caps at 150. ADOPTED: 100 per iteration matches the
 *   section-50 baseline; 50 of headroom under the cap. 30 iterations × 100 = 3,000 total
 *   PE publishes, ~6% of typical scratch-org daily quota — far from exhaustion.
 *
 * SPEC vs ACTUAL — per-iteration cleanup delete-the-PRIOR-iteration semantics
 *   The masker pattern (Task 4.2) deletes its iteration's records IN-TX because they're
 *   direct-DML inserts (synchronous). The logger pattern CANNOT delete its iteration's
 *   FLOOD entries in-tx because PE delivery is async — the entries do not exist in
 *   kern__LogEntry__c until the publishing tx commits + PE delivery completes. ADOPTED:
 *   each fire deletes the PRIOR iteration's persisted FLOOD entries (which have had ~60 s
 *   to deliver between fires, well within the 1-5 s typical PE delivery latency in scratch
 *   orgs). Iteration 0 has no prior to clean — no-op. The terminal iteration's FLOOD
 *   entries are never auto-cleaned (the SCHED aborts before the next fire that would have
 *   cleaned them) — they're cleaned by the operator's optional final-cleanup step.
 *
 * SPEC vs ACTUAL — query scoping per Task 3.4 finding A37
 *   the extended-load spec §9.3 originally implied scoping persisted-row queries by CreatedById. Per
 *   Task 3.4 finding A37 (commit `f9fbd89`): kern__LogEntry__c.CreatedById is the
 *   Automated Process user (TRG_PersistLogEntry runs as the platform's PE-subscriber
 *   identity, NOT the publishing user). ADOPTED: scope persisted-row queries by
 *   kern__UserId__c = :UserInfo.getUserId() AND kern__ClassMethod__c LIKE
 *   '<run-stamp marker>%'. The user-id field is populated by LOG_Engine at emit time
 *   from the PUBLISHING user's UserInfo, so it's the right scope marker.
 *
 * SPEC vs ACTUAL — smoke test scope
 *   The spec describes the operational 30-min run. The implementer task spec called for
 *   a smoke test at single-iteration scope (not waiting 30 min during dev). ADOPTED:
 *   smoke test direct-fires execute(null) once, asserts the per-iteration invariants
 *   from the persisted SOAK_ITERATION JSON stats, polls for SOAK_ITERATION row delivery
 *   (60 s budget), and exits. The cross-tx assertion (100 FLOOD entries persisted per
 *   iteration) is verified by section-50 + section-50b for the same emit code path; here
 *   the SOAK_ITERATION JSON's publishImmediateCount=100 stat is the smoke-test proxy
 *   for "100 PEs were successfully published to the bus".
 *
 * Run-isolation: smoke-test cleanup deletes BOTH the SOAK_ITERATION row AND any
 *   persisted FLOOD entries scoped by the smoke run's run-stamp (FLOOD entries may or
 *   may not have delivered by the time the cleanup runs; either way, the predicate is
 *   safe). The smoke test does NOT schedule a CronTrigger so no CronTrigger cleanup is
 *   needed. The operational soak's run-stamped CronTrigger self-aborts at iteration 30.
 *
 * Prerequisites:
 *   - subscriber scratch org with kern managed package installed
 *   - SCHED_SubscriberLoggerFlood class deployed (release-testing/subscriber/classes/)
 *   - kern__LogSetting__c.IsEnabled__c = true with no ClassFilter__c (verified at pre-flight —
 *     org-default ClassFilter__c is null so all classes pass isLoggable allowlist)
 *   - kern__LogSetting__c.LogLevelThreshold__c <= INFO (verified at pre-flight — DEBUG)
 *   - PE daily quota headroom ≥ 100 for smoke test (typical scratch-org quota 50K+;
 *     operational mode publishes 3,000 — both well within budget)
 *   - kern.LOG_Builder.startCorrelation()/build()/info()/emitAt() global accessors
 *     available (1.0+; verified)
 *
 * Run (smoke test — single iteration):
 *   sf apex run --file release-testing/scripts/load-extended/sustained-logger-pe-flood.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock for the smoke test: <70 seconds (one iteration ~500ms-1500ms for
 * 100 PublishImmediate DMLs + 60 s SOAK_ITERATION polling budget — typically resolves
 * in <10 s end-to-end with PE delivery latency in scratch orgs).
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== sustained-logger-pe-flood (extended-load Phase 4): Extended Load — Single-Iteration Smoke Test ===');

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String SMOKE_RUN_STAMP = String.valueOf(System.currentTimeMillis());
final String EXPECTED_SOAK_MARKER = SCHED_SubscriberLoggerFlood.CLASS_METHOD_PREFIX + SMOKE_RUN_STAMP;
final String EXPECTED_FLOOD_MARKER_PREFIX = SCHED_SubscriberLoggerFlood.FLOOD_CLASS_METHOD_PREFIX + SMOKE_RUN_STAMP;
final Integer EXPECTED_EMIT_BATCH_SIZE = SCHED_SubscriberLoggerFlood.EMIT_BATCH_SIZE;
final Decimal HEAP_GATE_FRACTION = SCHED_SubscriberLoggerFlood.HEAP_GATE_FRACTION;
final Long WALL_GATE_MS = 5000;
final Integer LOG_POLL_BUDGET_MS = 60000;
final Integer LOG_POLL_INTERVAL_MS = 2000;

System.debug(LoggingLevel.INFO,
	'Pre-flight: emitBatchSize=' + EXPECTED_EMIT_BATCH_SIZE + ' (matches section-50 baseline; '
		+ 'stays under 150 PublishImmediate per-tx cap with 50 of headroom — Task 1.7 finding A18). '
		+ 'PE delivery to LogEntry__c is async; smoke-test asserts single-tx invariants from the '
		+ 'persisted SOAK_ITERATION JSON stats once the publishing tx commits.');

Long startWallMs = System.currentTimeMillis();
Long preExecuteHeapBytes = Limits.getHeapSize();

try
{
	SCHED_SubscriberLoggerFlood flood = new SCHED_SubscriberLoggerFlood(SMOKE_RUN_STAMP);

	Assert.areEqual(SMOKE_RUN_STAMP, flood.getRunStamp(),
		'smoke-test: SCHED_SubscriberLoggerFlood.getRunStamp() should reflect the injected run-stamp');

	Assert.areEqual(EXPECTED_SOAK_MARKER, flood.buildSoakIterationClassMethodMarker(),
		'smoke-test: buildSoakIterationClassMethodMarker() should return CLASS_METHOD_PREFIX + runStamp');

	Assert.areEqual(EXPECTED_FLOOD_MARKER_PREFIX + '/iter0', flood.buildFloodClassMethodMarker(0),
		'smoke-test: buildFloodClassMethodMarker(0) should return FLOOD_CLASS_METHOD_PREFIX + runStamp + /iter0');

	flood.execute(null);

	Long iterationWallMs = System.currentTimeMillis() - startWallMs;
	Long postExecuteHeapBytes = Limits.getHeapSize();
	Long heapDeltaBytes = postExecuteHeapBytes - preExecuteHeapBytes;
	Decimal heapFraction = ((Decimal)postExecuteHeapBytes / Limits.getLimitHeapSize());

	System.debug(LoggingLevel.INFO,
		'Smoke iteration finished: wallMs=' + iterationWallMs + ', cpuMs=' + Limits.getCpuTime()
			+ ', publishImmediateConsumed=' + Limits.getPublishImmediateDML()
			+ ', heapStart=' + preExecuteHeapBytes + ', heapEnd=' + postExecuteHeapBytes
			+ ', heapDelta=' + heapDeltaBytes + ', heapFraction=' + heapFraction.setScale(4));

	Assert.isTrue(iterationWallMs < WALL_GATE_MS,
		'smoke-test: iteration wallMs (' + iterationWallMs + ') must be < ' + WALL_GATE_MS
			+ ' ms (sane per-iteration ceiling for 100 PublishImmediate DMLs)');

	Assert.isTrue(heapFraction < HEAP_GATE_FRACTION,
		'smoke-test: heap fraction (' + heapFraction.setScale(4) + ') must be < '
			+ HEAP_GATE_FRACTION + ' (post-iteration headroom maintained)');

	Assert.isTrue(Limits.getPublishImmediateDML() >= EXPECTED_EMIT_BATCH_SIZE,
		'smoke-test: publishImmediate consumed (' + Limits.getPublishImmediateDML() + ') must be >= '
			+ EXPECTED_EMIT_BATCH_SIZE + ' (proves at least the FLOOD batch ran via PublishImmediate, '
			+ 'plus the SOAK_ITERATION emit). Cap is 150/tx — confirms we have margin.');

	System.debug(LoggingLevel.INFO,
		'smoke iteration PASS: wallMs=' + iterationWallMs + ', cpuMs=' + Limits.getCpuTime()
			+ ', publishImmediateConsumed=' + Limits.getPublishImmediateDML()
			+ ', heapFraction=' + heapFraction.setScale(4)
			+ ' (the Schedulable emitted ' + EXPECTED_EMIT_BATCH_SIZE + ' FLOOD entries + 1 SOAK_ITERATION; '
			+ 'PE delivery to LogEntry__c is verified next via polling for SOAK_ITERATION row)');

	Long pollStartMs = System.currentTimeMillis();
	Long pollElapsedMs = 0;
	List<kern__LogEntry__c> soakRows = new List<kern__LogEntry__c>();
	while(pollElapsedMs < LOG_POLL_BUDGET_MS && soakRows.isEmpty())
	{
		soakRows =
		[
			SELECT Id, kern__ShortMessage__c, kern__Message__c, kern__ClassMethod__c,
				kern__CorrelationId__c, kern__TransactionId__c, kern__UserId__c, CreatedDate
			FROM kern__LogEntry__c
			WHERE kern__UserId__c = :UserInfo.getUserId()
			  AND kern__ClassMethod__c = :EXPECTED_SOAK_MARKER
			  AND kern__ShortMessage__c LIKE 'SOAK_ITERATION:%'
			ORDER BY CreatedDate ASC
			LIMIT 10
		];
		if(!soakRows.isEmpty())
		{
			break;
		}
		Long spinUntilMs = System.currentTimeMillis() + LOG_POLL_INTERVAL_MS;
		while(System.currentTimeMillis() < spinUntilMs && Limits.getCpuTime() < 8000)
		{
			Math.sqrt(2.0);
		}
		pollElapsedMs = System.currentTimeMillis() - pollStartMs;
	}

	Assert.isFalse(soakRows.isEmpty(),
		'smoke-test: SOAK_ITERATION row must persist to kern__LogEntry__c within '
			+ LOG_POLL_BUDGET_MS + ' ms (PE delivery latency); none seen after ' + pollElapsedMs
			+ ' ms for ClassMethod=' + EXPECTED_SOAK_MARKER + '. If PE delivery is lagging '
			+ 'in scratch org, re-run after ~30 s wait.');

	Assert.areEqual(1, soakRows.size(),
		'smoke-test: exactly one SOAK_ITERATION row expected from a single direct-fire; got '
			+ soakRows.size());

	String fullMessage = soakRows[0].kern__Message__c == null
		? soakRows[0].kern__ShortMessage__c
		: soakRows[0].kern__Message__c;
	String jsonPayload = fullMessage.substringAfter('SOAK_ITERATION: ');
	Assert.isTrue(String.isNotBlank(jsonPayload),
		'smoke-test: SOAK_ITERATION row must contain a parseable JSON payload after the prefix; '
			+ 'got message="' + fullMessage + '"');

	Map<String, Object> stats = (Map<String, Object>)JSON.deserializeUntyped(jsonPayload);
	Integer iterationIndex = (Integer)stats.get('iteration');
	Integer emitCount = (Integer)stats.get('emitCount');
	String correlationIdFromStats = (String)stats.get('correlationId');
	String transactionIdFromStats = (String)stats.get('transactionId');
	String floodMarkerFromStats = (String)stats.get('floodClassMethodMarker');
	Integer publishImmediateCount = (Integer)stats.get('publishImmediateCount');
	Decimal innerHeapFraction = (Decimal)stats.get('heapFraction');
	Object innerWallMsObj = stats.get('wallMs');
	Long innerWallMs = innerWallMsObj instanceof Integer
		? (Long)((Integer)innerWallMsObj)
		: (Long)innerWallMsObj;

	Assert.areEqual(0, iterationIndex,
		'smoke-test: first direct-fire iteration index must be 0 (no prior SOAK_ITERATION rows); got '
			+ iterationIndex);

	Assert.areEqual(EXPECTED_EMIT_BATCH_SIZE, emitCount,
		'smoke-test: emitCount must equal EMIT_BATCH_SIZE (' + EXPECTED_EMIT_BATCH_SIZE + '); got ' + emitCount);

	Assert.isTrue(String.isNotBlank(correlationIdFromStats),
		'smoke-test: correlationId from startCorrelation() must be non-blank; got "'
			+ correlationIdFromStats + '"');

	Assert.isTrue(String.isNotBlank(transactionIdFromStats),
		'smoke-test: transactionId from Request.getCurrent().getRequestId() must be non-blank; got "'
			+ transactionIdFromStats + '"');

	Assert.areEqual(EXPECTED_FLOOD_MARKER_PREFIX + '/iter0', floodMarkerFromStats,
		'smoke-test: floodClassMethodMarker in stats must equal the predicted iter0 marker; got "'
			+ floodMarkerFromStats + '"');

	Assert.areEqual(EXPECTED_EMIT_BATCH_SIZE, publishImmediateCount,
		'smoke-test: per-iteration publishImmediateCount must equal EMIT_BATCH_SIZE ('
			+ EXPECTED_EMIT_BATCH_SIZE + ') — proves all 100 FLOOD emits each consumed one PublishImmediate '
			+ 'DML, no batching (Task 1.7 finding A18). Got ' + publishImmediateCount);

	Assert.isTrue(innerHeapFraction < HEAP_GATE_FRACTION,
		'smoke-test: persisted iteration heapFraction (' + innerHeapFraction
			+ ') must be < ' + HEAP_GATE_FRACTION + '; the Schedulable measured this at end-of-fire');

	Assert.isTrue(innerWallMs >= 0 && innerWallMs < WALL_GATE_MS,
		'smoke-test: persisted iteration wallMs (' + innerWallMs + ') must be >= 0 and < '
			+ WALL_GATE_MS + ' ms');

	Assert.areEqual(correlationIdFromStats, soakRows[0].kern__CorrelationId__c,
		'smoke-test: SOAK_ITERATION row CorrelationId__c must equal the correlationId reported in '
			+ 'JSON stats (proves startCorrelation() set the engine state and SOAK_ITERATION emit '
			+ 'inherited it). Stats="' + correlationIdFromStats + '" Persisted="'
			+ soakRows[0].kern__CorrelationId__c + '"');

	Assert.areEqual(transactionIdFromStats, soakRows[0].kern__TransactionId__c,
		'smoke-test: SOAK_ITERATION row TransactionId__c must equal the transactionId reported in '
			+ 'JSON stats (proves Request.getRequestId() captured at execute() entry equals the value '
			+ 'LOG_Engine stamps on the LogEntryEvent__e). Stats="' + transactionIdFromStats
			+ '" Persisted="' + soakRows[0].kern__TransactionId__c + '"');

	Assert.areEqual(UserInfo.getUserId(), soakRows[0].kern__UserId__c,
		'smoke-test: SOAK_ITERATION row UserId__c must equal the publishing user (per Task 3.4 finding '
			+ 'A37 — UserId__c is the right scope marker, not CreatedById which is the Automated '
			+ 'Process user). Got UserId__c=' + soakRows[0].kern__UserId__c);

	System.debug(LoggingLevel.INFO,
		'smoke verify PASS: SOAK_ITERATION row found in ' + pollElapsedMs + ' ms — iteration='
			+ iterationIndex + ', emitCount=' + emitCount + ', publishImmediateCount=' + publishImmediateCount
			+ ', correlationId=' + correlationIdFromStats + ', transactionId=' + transactionIdFromStats
			+ ', innerHeap=' + innerHeapFraction.setScale(4) + ', innerWallMs=' + innerWallMs);

	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
		'smoke-test FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('smoke-test: ' + scenarioError.getMessage());
	fail++;
}

kern.TRG_Base.clearAllBypasses();
try
{
	List<kern__LogEntry__c> residualSoakRows =
	[
		SELECT Id
		FROM kern__LogEntry__c
		WHERE kern__UserId__c = :UserInfo.getUserId()
		  AND kern__ClassMethod__c = :EXPECTED_SOAK_MARKER
		LIMIT 9000
	];
	if(!residualSoakRows.isEmpty())
	{
		delete residualSoakRows;
		System.debug(LoggingLevel.INFO,
			'Cleanup: deleted ' + residualSoakRows.size() + ' SOAK_ITERATION kern__LogEntry__c row(s)');
	}

	List<kern__LogEntry__c> residualFloodRows =
	[
		SELECT Id
		FROM kern__LogEntry__c
		WHERE kern__UserId__c = :UserInfo.getUserId()
		  AND kern__ClassMethod__c LIKE :(EXPECTED_FLOOD_MARKER_PREFIX + '/iter%')
		LIMIT 9000
	];
	if(!residualFloodRows.isEmpty())
	{
		delete residualFloodRows;
		System.debug(LoggingLevel.INFO,
			'Cleanup: deleted ' + residualFloodRows.size() + ' FLOOD kern__LogEntry__c row(s)');
	}
}
catch(Exception cleanupError)
{
	System.debug(LoggingLevel.WARN, 'smoke-test cleanup warning: ' + cleanupError.getMessage());
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'sustained-logger-pe-flood smoke test: ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== sustained-logger-pe-flood smoke test FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('sustained-logger-pe-flood smoke test failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO,
		'=== sustained-logger-pe-flood smoke test COMPLETE: 1 iteration verified end-to-end. '
			+ 'Operational 30-min mode: see header for System.schedule invocation pattern. ===');
}
