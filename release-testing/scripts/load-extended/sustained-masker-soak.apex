/**
 * sustained-masker-soak.apex (extended-load Phase 4 / §9.3)
 *
 * EXTENDED LOAD TEST — pre-tag-only. NOT part of every release-test cycle. Run before
 * promoting beta → GA via `npm run test:load:extended` (the runner that wraps this script
 * + the other 3 extended-load scripts; see the extended-load spec §10.2). FIRST script in the new
 * release-testing/scripts/load-extended/ directory — establishes the pattern for the
 * other three (sustained-logger-pe-flood, parallel-callout-burst-100, parallel-cache-contention).
 *
 * PURPOSE
 *   Sustained masking under load. Detects:
 *     - Heap drift across iterations (memory leaks within transaction reset between fires)
 *     - Governor accumulation (DML/SOQL/CPU stats across re-launches)
 *     - Orphaned async jobs (Schedulable lifecycle correctness — self-abort at iteration 30)
 *     - Per-iteration timing drift (>20% from opening iteration = degradation signal)
 *
 * OPERATIONAL PATTERN (production / pre-tag verification — ~30 min wall clock)
 *   The Schedulable SCHED_SubscriberMaskerSoak lives in release-testing/subscriber/classes/
 *   and is deployed as part of the standard subscriber fixture deploy (Phase 1 of the
 *   release-testing runbook). To run the operational 30-minute soak:
 *
 *     1. Choose a unique scheduler name suffix:
 *          String runStamp = String.valueOf(System.currentTimeMillis());
 *
 *     2. Schedule the soak (cron `0 * * * * ? *` fires once per minute):
 *          System.schedule
 *          (
 *              'MaskerSoak_' + runStamp,
 *              '0 * * * * ? *',
 *              new SCHED_SubscriberMaskerSoak(runStamp)
 *          );
 *
 *     3. Wait ~30 min (the Schedulable self-aborts at iteration MAX_ITERATIONS=30).
 *
 *     4. Verify drift via SOQL on the persisted SOAK_ITERATION rows:
 *          SELECT kern__ShortMessage__c, kern__Message__c, CreatedDate
 *          FROM kern__LogEntry__c
 *          WHERE kern__ClassMethod__c = 'SCHED_SubscriberMaskerSoak.executeIteration_<runStamp>'
 *            AND kern__ShortMessage__c LIKE 'SOAK_ITERATION:%'
 *          ORDER BY CreatedDate ASC
 *
 *        For each row, parse the JSON payload from kern__Message__c (or
 *        kern__ShortMessage__c if it fits in 255 chars). Compute:
 *          opening = stats[0]
 *          For each later row N:
 *            Assert stats[N].wallMs <= opening.wallMs * 1.20  (per-iteration drift)
 *            Assert stats[N].heapFraction < 0.80               (no heap leak)
 *            Assert stats[N].rawCardRetained == 0              (masker still working)
 *            Assert stats[N].maskingFailures == 0              (no rule explosions)
 *            Assert stats[N].iteration == N                    (no skipped fires)
 *
 *     5. Verify no orphan CronTrigger:
 *          SELECT COUNT() FROM CronTrigger
 *          WHERE CronJobDetail.Name = 'MaskerSoak_<runStamp>'
 *            AND State NOT IN ('DELETED','COMPLETE')
 *        Expect 0. If non-zero, abort manually:
 *          System.abortJob([SELECT Id FROM CronTrigger
 *                           WHERE CronJobDetail.Name = 'MaskerSoak_<runStamp>'].Id);
 *
 *     6. (Optional) Cleanup the persisted SOAK_ITERATION rows + any residual ApiCall__c:
 *          delete [SELECT Id FROM kern__LogEntry__c
 *                  WHERE kern__ClassMethod__c =
 *                        'SCHED_SubscriberMaskerSoak.executeIteration_<runStamp>'
 *                  LIMIT 9000];
 *          delete [SELECT Id FROM kern__ApiCall__c
 *                  WHERE kern__ServiceName__c = 'MaskerSoak_<runStamp>'
 *                  LIMIT 9000];
 *
 * SMOKE-TEST PATTERN (this script — used by `sf apex run --file ...` during dev)
 *   The full 30-min run is the OPERATIONAL pattern; we don't burn 30 min of scratch-org
 *   wall clock during dev. This script:
 *     - Direct-fires `new SCHED_SubscriberMaskerSoak(runStamp).execute(null)` ONCE,
 *       which bypasses cron scheduling and runs synchronously inside the anon Apex tx.
 *     - Asserts the smoke-test invariants (50 records inserted + masked, governors well
 *       under threshold, SOAK_ITERATION row emitted, no exception).
 *     - Cleans up the persisted SOAK_ITERATION row + ApiCall__c rows.
 *     - Documents (above) the operational invocation pattern so the operator can run the
 *       full 30-min soak when promoting.
 *
 *   The `execute(null)` direct-fire short-circuits the CronTrigger.abortJob() path inside
 *   the Schedulable (since context.getTriggerId() can't be called on null) — that's
 *   handled gracefully by the `context != null` guard at the abort site. The iteration
 *   counter falls through to 0 because no prior SOAK_ITERATION rows exist for this
 *   freshly-stamped run.
 *
 * SMOKE-TEST BEHAVIOUR ASSERTIONS (HARD GATE — single iteration)
 *   - 50 kern__ApiCall__c records inserted in single iteration (persistedCount == 50)
 *   - All 50 sampled records: rawCardRetained == 0 (masker rewrote 4111... → CARD_REDACTED)
 *   - All 50 sampled records: maskingFailures == 0 (no [MASKING_FAILURE] sentinels)
 *   - heapFraction < 0.80 at end of iteration (heap headroom maintained)
 *   - cpuMs < 5000 ms (well under the 10s sync CPU governor)
 *   - wallMs < 10000 ms (sane per-iteration ceiling)
 *   - SOAK_ITERATION row persisted in kern__LogEntry__c with parseable JSON payload
 *     (note: PE delivery to LogEntry__c is async — verify polls with a 60 s budget)
 *   - No exception raised during iteration
 *
 * OPERATIONAL MODE INVARIANTS (documented for reference; NOT asserted in smoke test)
 *   - 30 iterations complete without governor exhaustion
 *   - Per-iteration wallMs stays within ±20% of iteration[0].wallMs (drift detection)
 *   - Per-iteration heapFraction stays < 0.80 across all 30 fires
 *   - Cumulative kern__LogEntry__c rows for this run grows linearly, exactly +1 per minute
 *     (no drops, no duplicates — proves PE delivery + scheduler correctness)
 *   - No orphaned AsyncApexJob row after 30 min — the Schedulable self-aborts the
 *     CronTrigger at iteration MAX_ITERATIONS-1
 *   - Cumulative kern__ApiCall__c rows for this ServiceName remain at 0 between fires
 *     (each iteration deletes its own 50-record batch before the next fire begins)
 *
 * SPEC vs ACTUAL — Schedulable type binding (the ephemeral-anon-class problem)
 *   The the extended-load spec §9.3 spec described the soak loosely as "Schedulable + Batchable hybrid"
 *   that "Loop[s]: insert 50 records, masker fires, capture cumulative LogEntry__c for
 *   any drift, repeat for 30 minutes via Database.executeBatch(... scope: 50) + scheduled
 *   re-launch." The implementer survey discovered an empirical constraint that drove a
 *   design pivot:
 *     - System.schedule(name, cron, instance) requires a STABLE Apex Type to bind to.
 *     - Anonymous-Apex classes are EPHEMERAL: they exist only inside the script's compile
 *       unit and are dropped when the executeAnonymous tx ends. Scheduling an anon-Apex
 *       class via System.schedule succeeds at scheduling time but the next cron fire
 *       FAILS because the platform can't instantiate the now-dropped type.
 *     - The Database.executeBatch(...) variant doesn't actually meet the spec intent
 *       either: a single Batchable's start→execute→finish all share one AsyncApexJob row
 *       so per-fire heap reset is not observable across iterations the way the spec
 *       called for ("heap stays <80% across iterations" — across iterations, not within
 *       a single batch).
 *   ADOPTED: deploy SCHED_SubscriberMaskerSoak as a permanent subscriber-side fixture
 *   class (release-testing/subscriber/classes/) so System.schedule has a stable type to
 *   bind to. Each cron fire is its own transaction with fresh governors — exactly the
 *   property that makes drift detection meaningful. Anon-Apex direct-fires the
 *   Schedulable's execute(null) for the smoke test, bypassing cron entirely.
 *
 * SPEC vs ACTUAL — iteration counter via SOAK_ITERATION row count
 *   The spec did not specify how the Schedulable should track its own iteration index
 *   across cron fires (each fire is a separate tx; static Apex state doesn't persist).
 *   ADOPTED: count prior SOAK_ITERATION rows persisted in kern__LogEntry__c scoped to
 *   the run-stamped ClassMethod__c marker. The iteration index for THIS fire equals the
 *   number of prior fires that already emitted their SOAK_ITERATION row. This requires
 *   that PE delivery + TRG_PersistLogEntry persistence completes within the 60 s gap
 *   between cron fires; observed delivery is typically 1-5 s in scratch orgs so the
 *   margin is wide. If PE delivery lags > 60 s the counter under-reports — documented
 *   here as a known scratch-org constraint that's negligible in practice.
 *
 * SPEC vs ACTUAL — masker target/rule density
 *   Same constraint as section-44 (Task 2.2): the deployed framework ships 3 wildcard
 *   targets for ApiCall__c (ApiCall_All_Card → MaskCreditCard, ApiCall_All_PaymentCard →
 *   MaskPaymentCard, ApiCall_All_Secret → MaskSecretKeys) × 3 active framework rules,
 *   but the Card target defers to the PaymentCard successor at shipped values, so 2
 *   targets evaluate per record + ~1 leftover subscriber test fixture
 *   (variable across runs). The spec assumed 5 × 10 = 50 target-rule pairs; effective is
 *   ~2 × 2 to 2 × 3 = 4-6 pairs. CMDT DML is platform-blocked from anon Apex so we
 *   cannot vary this within a single test run. The masker still meaningfully exercises
 *   the bulk path (50 records × 4-6 pairs = 200-300 evaluations per fire), and
 *   per-iteration timing drift is the load signal regardless of absolute eval count.
 *
 * SPEC vs ACTUAL — per-iteration cleanup of inserted records
 *   The spec implied accumulation is fine since the test runs for 30 min. ADOPTED:
 *   delete the 50 just-inserted ApiCall__c rows AT THE END OF EACH FIRE (inside the
 *   Schedulable). Without per-iteration cleanup the org accumulates ~1500 rows over
 *   the 30-min run, which (a) doesn't match the spec's "drift" signal of interest,
 *   (b) burns scratch-org row capacity unnecessarily, and (c) makes the verify SOQL
 *   slower as the table grows. Per-iteration delete keeps the steady-state row count
 *   at 0 between fires. Drift is captured in the persisted SOAK_ITERATION rows, not
 *   in the ApiCall__c rows themselves.
 *
 * SPEC vs ACTUAL — smoke test scope
 *   The spec describes the operational 30-min run. The implementer task spec called
 *   for a smoke test at single-iteration scope (not waiting 30 min during dev).
 *   ADOPTED: smoke test direct-fires execute(null) once, asserts the per-iteration
 *   invariants, and exits. Operational invariants (drift, no-orphan, linearity) are
 *   documented for the operator but NOT asserted by this smoke-test script.
 *
 * Run-isolation: self-contained. The smoke test inserts then deletes its 50
 *   ApiCall__c rows + cleans up the SOAK_ITERATION LogEntry__c row by run-stamp. The
 *   smoke test does NOT schedule a CronTrigger, so no cleanup of CronTrigger rows is
 *   needed. The operational soak's run-stamped CronTrigger self-aborts at iteration 30.
 *
 * Prerequisites:
 *   - subscriber scratch org with kern managed package installed
 *   - SCHED_SubscriberMaskerSoak class deployed (release-testing/subscriber/classes/)
 *   - kern.UTIL_FrameworkMasker.isMaskingEnabled (default true via FeatureFlag)
 *   - kern__MaskingTarget__mdt: ApiCall_All_PaymentCard + ApiCall_All_Secret active
 *     (ApiCall_All_Card also ships active but defers to the PaymentCard successor)
 *   - kern__MaskingRule__mdt: MaskPaymentCard + MaskSecretKeys (+ legacy MaskCreditCard) active
 *   - kern__LogSetting__c.IsEnabled__c = true and threshold ≤ INFO
 *   - PE quota headroom (smoke test publishes 1 PE; operational publishes ~30)
 *
 * Run (smoke test — single iteration):
 *   sf apex run --file release-testing/scripts/load-extended/sustained-masker-soak.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock for the smoke test: <8 seconds (one iteration ~500ms + 60s LogEntry
 * polling budget — typically resolves in <10s with PE delivery latency in scratch orgs).
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== sustained-masker-soak (extended-load Phase 4): Extended Load — Single-Iteration Smoke Test ===');

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String SMOKE_RUN_STAMP = String.valueOf(System.currentTimeMillis());
final String EXPECTED_SERVICE_NAME = SCHED_SubscriberMaskerSoak.SERVICE_NAME_PREFIX + SMOKE_RUN_STAMP;
final String EXPECTED_CLASS_METHOD_MARKER = SCHED_SubscriberMaskerSoak.CLASS_METHOD_PREFIX + SMOKE_RUN_STAMP;
final Integer EXPECTED_INSERT_BATCH_SIZE = SCHED_SubscriberMaskerSoak.INSERT_BATCH_SIZE;
final Decimal HEAP_GATE_FRACTION = SCHED_SubscriberMaskerSoak.HEAP_GATE_FRACTION;
final Long CPU_GATE_MS = 5000;
final Long WALL_GATE_MS = 10000;
final Integer LOG_POLL_BUDGET_MS = 60000;
final Integer LOG_POLL_INTERVAL_MS = 2000;

Integer activeMaskingTargets =
[
		SELECT COUNT()
		FROM kern__MaskingTarget__mdt
		WHERE kern__IsActive__c = TRUE
];
Integer activeMaskingRules =
[
		SELECT COUNT()
		FROM kern__MaskingRule__mdt
		WHERE kern__IsActive__c = TRUE
];
// Pre-flight: kern.UTIL_FrameworkMasker.isMaskingEnabled is `public inherited sharing` not
// `global`, so subscriber anon Apex cannot reference it directly (FRAMEWORK FOLLOW-UP A38).
// Masking enablement is observable via the smoke test's downstream assertion: if maskedCount
// equals sampledCount and rawCardRetained == 0, the masker fired correctly. We do not need
// a pre-flight isMaskingEnabled probe.
System.debug(LoggingLevel.INFO,
		'Pre-flight: activeTargets=' + activeMaskingTargets + ', activeRules=' + activeMaskingRules
		+ ' (Spec wanted 5×10 ApiCall pairs; deployed 3 wildcard ApiCall targets, 2 effective — the Card '
		+ 'target defers to the PaymentCard successor — × 3-4 active rules; '
		+ 'documented in section-44 / Task 2.2). Masker enablement is verified via the smoke '
		+ 'assertions on maskedCount / rawCardRetained.');

Long startWallMs = System.currentTimeMillis();
Long preExecuteHeapBytes = Limits.getHeapSize();

try
{
	SCHED_SubscriberMaskerSoak soak = new SCHED_SubscriberMaskerSoak(SMOKE_RUN_STAMP);

	Assert.areEqual(SMOKE_RUN_STAMP, soak.getRunStamp(),
			'smoke-test: SCHED_SubscriberMaskerSoak.getRunStamp() should reflect the injected run-stamp');

	soak.execute(null);

	Long iterationWallMs = System.currentTimeMillis() - startWallMs;
	Long postExecuteHeapBytes = Limits.getHeapSize();
	Long heapDeltaBytes = postExecuteHeapBytes - preExecuteHeapBytes;
	Decimal heapFraction = ((Decimal)postExecuteHeapBytes / Limits.getLimitHeapSize());

	System.debug(LoggingLevel.INFO,
			'Smoke iteration finished: wallMs=' + iterationWallMs + ', cpuMs=' + Limits.getCpuTime()
			+ ', heapStart=' + preExecuteHeapBytes + ', heapEnd=' + postExecuteHeapBytes
			+ ', heapDelta=' + heapDeltaBytes + ', heapFraction=' + heapFraction.setScale(4));

	Assert.isTrue(iterationWallMs < WALL_GATE_MS,
			'smoke-test: iteration wallMs (' + iterationWallMs + ') must be < ' + WALL_GATE_MS
			+ ' ms (sane per-iteration ceiling)');

	Assert.isTrue(Limits.getCpuTime() < CPU_GATE_MS,
			'smoke-test: cpuMs (' + Limits.getCpuTime() + ') must be < ' + CPU_GATE_MS
			+ ' ms (well under 10s sync governor)');

	Assert.isTrue(heapFraction < HEAP_GATE_FRACTION,
			'smoke-test: heap fraction (' + heapFraction.setScale(4) + ') must be < '
			+ HEAP_GATE_FRACTION + ' (post-iteration headroom maintained)');

	Integer residualApiCallCount =
	[
			SELECT COUNT()
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :EXPECTED_SERVICE_NAME
	];
	Assert.areEqual(0, residualApiCallCount,
			'smoke-test: per-iteration cleanup must drop the inserted ApiCall__c rows; '
			+ 'expected 0 residual, got ' + residualApiCallCount);

	System.debug(LoggingLevel.INFO,
			'smoke iteration PASS: wallMs=' + iterationWallMs + ', cpuMs=' + Limits.getCpuTime()
			+ ', heapFraction=' + heapFraction.setScale(4) + ', residualApiCalls=' + residualApiCallCount
			+ ' (the Schedulable inserted ' + EXPECTED_INSERT_BATCH_SIZE + ' records, asserted masking, '
			+ 'and deleted them; PE delivery to LogEntry__c is verified next via polling)');

	Long pollStartMs = System.currentTimeMillis();
	Long pollElapsedMs = 0;
	List<kern__LogEntry__c> soakRows = new List<kern__LogEntry__c>();
	while(pollElapsedMs < LOG_POLL_BUDGET_MS && soakRows.isEmpty())
	{
		soakRows =
		[
				SELECT Id,
						kern__ShortMessage__c,
						kern__Message__c,
						kern__ClassMethod__c,
						CreatedDate
				FROM kern__LogEntry__c
				WHERE kern__ClassMethod__c = :EXPECTED_CLASS_METHOD_MARKER
				AND kern__ShortMessage__c LIKE 'SOAK_ITERATION:%'
				ORDER BY CreatedDate ASC
				LIMIT 10
		];
		if(!soakRows.isEmpty())
		{
			break;
		}
		Long spinUntilMs = System.currentTimeMillis() + LOG_POLL_INTERVAL_MS;
		while(System.currentTimeMillis() < spinUntilMs && Limits.getCpuTime() < (CPU_GATE_MS + 3000))
		{
			Math.sqrt(2.0);
		}
		pollElapsedMs = System.currentTimeMillis() - pollStartMs;
	}

	Assert.isFalse(soakRows.isEmpty(),
			'smoke-test: SOAK_ITERATION row must persist to kern__LogEntry__c within '
			+ LOG_POLL_BUDGET_MS + ' ms (PE delivery latency); none seen after ' + pollElapsedMs
			+ ' ms for ClassMethod=' + EXPECTED_CLASS_METHOD_MARKER + '. If PE delivery is lagging '
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
	Integer persistedCount = (Integer)stats.get('persistedCount');
	Integer sampledCount = (Integer)stats.get('sampledCount');
	Integer maskedCount = (Integer)stats.get('maskedCount');
	Integer rawCardRetained = (Integer)stats.get('rawCardRetained');
	Integer maskingFailures = (Integer)stats.get('maskingFailures');
	Decimal innerHeapFraction = (Decimal)stats.get('heapFraction');
	Object innerWallMsObj = stats.get('wallMs');
	Long innerWallMs = innerWallMsObj instanceof Integer
			? (Long)((Integer)innerWallMsObj)
			: (Long)innerWallMsObj;

	Assert.areEqual(0, iterationIndex,
			'smoke-test: first direct-fire iteration index must be 0 (no prior SOAK_ITERATION rows); got '
			+ iterationIndex);

	Assert.areEqual(EXPECTED_INSERT_BATCH_SIZE, persistedCount,
			'smoke-test: persistedCount must equal INSERT_BATCH_SIZE (' + EXPECTED_INSERT_BATCH_SIZE
			+ '); got ' + persistedCount);

	Assert.areEqual(EXPECTED_INSERT_BATCH_SIZE, sampledCount,
			'smoke-test: sampledCount must equal INSERT_BATCH_SIZE for a 50-record fire; got '
			+ sampledCount);

	Assert.areEqual(0, rawCardRetained,
			'smoke-test: rawCardRetained must be 0 — the masker should have rewritten every Visa '
			+ '4111... → CARD_REDACTED; got ' + rawCardRetained + '/' + sampledCount);

	Assert.areEqual(0, maskingFailures,
			'smoke-test: maskingFailures must be 0 — no [MASKING_FAILURE] sentinels expected; got '
			+ maskingFailures + '/' + sampledCount);

	Assert.isTrue(maskedCount == sampledCount,
			'smoke-test: every sampled record should show CARD_REDACTED (and not raw Visa); got '
			+ maskedCount + '/' + sampledCount);

	Assert.isTrue(innerHeapFraction < HEAP_GATE_FRACTION,
			'smoke-test: persisted iteration heapFraction (' + innerHeapFraction
			+ ') must be < ' + HEAP_GATE_FRACTION + '; the Schedulable measured this at end-of-fire');

	Assert.isTrue(innerWallMs >= 0 && innerWallMs < WALL_GATE_MS,
			'smoke-test: persisted iteration wallMs (' + innerWallMs + ') must be >= 0 and < '
			+ WALL_GATE_MS + ' ms');

	System.debug(LoggingLevel.INFO,
			'smoke verify PASS: SOAK_ITERATION row found in ' + pollElapsedMs + ' ms — iteration='
			+ iterationIndex + ', persisted=' + persistedCount + '/' + sampledCount
			+ ', masked=' + maskedCount + ', rawCardRetained=' + rawCardRetained
			+ ', maskingFailures=' + maskingFailures + ', innerHeap=' + innerHeapFraction.setScale(4)
			+ ', innerWallMs=' + innerWallMs);

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
	List<kern__ApiCall__c> residualApiCalls =
	[
			SELECT Id
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :EXPECTED_SERVICE_NAME
			LIMIT 9000
	];
	if(!residualApiCalls.isEmpty())
	{
		delete residualApiCalls;
		System.debug(LoggingLevel.INFO,
				'Cleanup: deleted ' + residualApiCalls.size() + ' residual kern__ApiCall__c row(s)');
	}

	List<kern__LogEntry__c> residualLogEntries =
	[
			SELECT Id
			FROM kern__LogEntry__c
			WHERE kern__ClassMethod__c = :EXPECTED_CLASS_METHOD_MARKER
			LIMIT 9000
	];
	if(!residualLogEntries.isEmpty())
	{
		delete residualLogEntries;
		System.debug(LoggingLevel.INFO,
				'Cleanup: deleted ' + residualLogEntries.size() + ' SOAK_ITERATION kern__LogEntry__c row(s)');
	}
}
catch(Exception cleanupError)
{
	System.debug(LoggingLevel.WARN, 'smoke-test cleanup warning: ' + cleanupError.getMessage());
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'sustained-masker-soak smoke test: ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== sustained-masker-soak smoke test FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('sustained-masker-soak smoke test failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO,
			'=== sustained-masker-soak smoke test COMPLETE: 1 iteration verified end-to-end. '
			+ 'Operational 30-min mode: see header for System.schedule invocation pattern. ===');
}
