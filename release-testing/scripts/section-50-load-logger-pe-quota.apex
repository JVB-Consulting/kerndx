/**
 * Section 50 (extended-load Phase 3, Tier 2): Load Test — Logger Platform Event quota (Launch)
 *
 * Stresses kern.LOG_Builder.emit() flooding LogEntryEvent__e Platform Event +
 * verifies (in section-50b) that subscriber TRG_PersistLogEntry processes all entries into
 * kern__LogEntry__c without quota exhaustion or drops. Captures the synchronous emitWallMs
 * for the 100 emit() calls (the work the launch tx does to publish 100 PEs to the bus) and
 * persists the run-stamp + CorrelationId + emitWallMs into a tagged kern__Foobar__c handoff
 * row keyed by run-stamp. Section 50b reads the handoff, polls kern__LogEntry__c for the
 * 100 persisted rows, asserts no drops + TransactionId consistency + correlation propagation
 * + zero quota errors, and emits the four PERF_ROW lines (emitWallMs, peDeliveryWallMs,
 * persistedCount, droppedCount).
 *
 * SPEC vs ACTUAL — single-script vs launch+verify split (FRAMEWORK FINDING A36):
 *   the extended-load spec §7.7 specifies polling kern__LogEntry__c for the 100 persisted rows after
 *   emit(). Empirical pre-flight survey + Task 3.3 closure (FRAMEWORK FOLLOW-UP A36)
 *   demonstrate this is structurally impossible: Platform Events do NOT deliver to
 *   subscribers until the publishing transaction COMMITS. EventBus.publish() (PublishImmediate
 *   semantics — see LOG_Engine.cls line 1108) places the event on the bus immediately, but
 *   the bus does not invoke subscribers (TRG_PersistLogEntry) until the enqueueing tx
 *   commits. A busy-wait probe inside the same anon Apex tx polling kern__LogEntry__c
 *   would observe zero rows for the entire window because the publishing tx (the
 *   executeAnonymous) has not yet committed; subscriber dispatch + LogEntry__c persistence
 *   only fires AFTER `sf apex run` exits. Adopted: launch+verify split (mirrors section-49
 *   / section-49b precedent). Launch script captures emitWallMs + persists run context;
 *   verify script (section-50b) polls kern__LogEntry__c for terminal count + asserts the
 *   subscriber-side contract + emits the PERF_ROW lines for Phase 2.5's harvester. Same
 *   constraint applies to Tasks 3.3 (Queueable/Batch) and 3.2 (async chain Queueables) —
 *   any subscriber-side observable that depends on the launch tx committing first must
 *   be deferred to a verify script. Section-50b's polling budget is 60s with 2s interval
 *   per spec § "PE delivery latency".
 *
 * SPEC vs ACTUAL — entry count reduced from 200 to 100 (finding A18):
 *   the extended-load spec §7.7 specifies 200 entries. Task 1.7 finding A18 (section-58 #4) empirically
 *   established that LOG_Builder.emit() OUTSIDE an active scope publishes immediately
 *   (one PublishImmediate DML per emit, no batching — LOG_Engine.cls BATCH_SIZE=50 only
 *   applies inside scopes). The per-transaction PublishImmediate DML governor caps at 150;
 *   200 emits hit the limit at the 151st and aborts the script with System.LimitException.
 *   Reduced to 100 to stay well under the 150 cap with margin. The 100 emits exercise the
 *   raw flood code path (the most common subscriber pattern — emit on every record without
 *   wrapping in a scope), validating that the framework + subscriber chain handles 100
 *   discrete PEs cleanly. The subscriber's TRG_PersistLogEntry is the assertion target,
 *   not the buffering / batching paths (those have their own coverage in section-58 #3).
 *
 * SPEC vs ACTUAL — pattern selection (raw flood vs scoped flush):
 *   Per task spec "Pick pattern 1 (matches the spec intent of 'raw flood') to test the
 *   high-emission-rate code path that subscribers most commonly hit." This script does
 *   NOT wrap the 100 emits in kern.LOG_Builder.scope() — each .info(...).emitAt(...) is a
 *   discrete PublishImmediate DML. This is the path subscribers most commonly hit when
 *   they sprinkle .emit() through their own service / handler classes without thinking
 *   about scope batching. The scope+auto-flush path is covered by section-58 #3 (501-entry
 *   scope flood) so this load test deliberately exercises the un-scoped path.
 *
 * SPEC vs ACTUAL — correlation contract:
 *   The test EXPLICITLY calls kern.LOG_Builder.startCorrelation() so all 100 emits share
 *   a single correlationId. This tests the meaningful subscriber path where a service
 *   correlates a burst of work via a single id. Without startCorrelation(), the framework
 *   leaves currentCorrelationId at null (LOG_Engine.cls line 263) and CorrelationId__c
 *   would persist as null — that path is covered by section-16h. By forcing a correlation
 *   here we get a concrete subscriber contract to assert in section-50b: "all 100 share
 *   THIS specific correlationId" — a stronger property than "non-null".
 *
 * SPEC vs ACTUAL — TransactionId__c contract:
 *   Per LOG_Engine.cls line 1412: event.TransactionId__c = Request.getCurrent().getRequestId().
 *   All 100 emits within this single anon Apex tx share the same RequestId so all 100
 *   persisted LogEntry__c rows MUST share the same TransactionId__c. Section 50b asserts
 *   this contract via DISTINCT-style aggregation (one bucket per TransactionId, expect 1).
 *   The launch script captures the launch-tx RequestId into the handoff row so 50b can
 *   assert the persisted TransactionId equals the LAUNCH RequestId (not the verify-tx
 *   RequestId, which is irrelevant).
 *
 * SPEC vs ACTUAL — handoff persistence mechanism:
 *   The run-stamp + correlationId + transactionId + emitWallMs need to survive the
 *   launch→verify gap. We store them on a single tagged kern__Foobar__c row by serializing
 *   JSON into the kern__TextAreaLong__c field (LongTextArea, 32K capacity — same field
 *   used by section-49 launch). The row is keyed by Name='Section50Load_<runStamp>' so
 *   the verify script ORDER BY CreatedDate DESC LIMIT 1 finds THIS run's handoff. Cleanup
 *   in section-50b deletes the handoff row AND all the LogEntry__c rows scoped by the
 *   run-stamped ClassMethod__c marker.
 *
 * SPEC vs ACTUAL — run-isolation marker:
 *   The spec's example marker `OriginLocation__c='Section50Load_<runStamp>'` references a
 *   field that DOES NOT EXIST on kern__LogEntry__c. The actual fields are listed at
 *   force-app/main/default/objects/LogEntry__c/fields/ — there is no OriginLocation__c.
 *   Substituted: ClassMethod__c (length=100, populated from emitAt's classMethod arg) as
 *   the run-isolation marker. Each emit uses
 *   classMethod = 'LOG_TestSection50_<runStamp>.peQuotaFlood' so the run-stamp is folded
 *   into the ClassMethod__c column. Verify queries scope by
 *   ClassMethod__c LIKE 'LOG_TestSection50_<runStamp>%' AND CreatedDate = TODAY AND
 *   CreatedById = current user, which uniquely picks THIS run's 100 rows even with
 *   concurrent runs from other users or other days.
 *
 * BEHAVIOUR ASSERTIONS (HARD GATE — split across launch + verify):
 *   In section-50 (this launch script):
 *     - kern.LOG_Builder.startCorrelation() returns a non-blank correlationId
 *     - 100 emit() calls complete without exception (no PublishImmediate governor breach)
 *     - emitWallMs measured for the 100 emits
 *     - Handoff row persists with runStamp + correlationId + transactionId + emitWallMs
 *   In section-50b (verify script):
 *     - persistedCount == 100 (all entries written to kern__LogEntry__c by subscriber)
 *     - droppedCount == 0 (100 - persistedCount)
 *     - All 100 share the SAME TransactionId__c, equal to the LAUNCH tx RequestId
 *     - All 100 share the SAME CorrelationId__c, equal to the launch's startCorrelation()
 *     - Zero quota-exhausted ERROR-level LogEntry__c rows from TRG_PersistLogEntry scoped
 *       to TODAY + current user
 *     - Zero ApiIssue__c rows from TODAY + current user (subscriber didn't surface any
 *       integration-side errors as a side-effect of the PE flood)
 *
 * PERF METRICS (soft gate — emitted by section-50b after polling):
 *   emitWallMs       — wall clock for the 100 emit() calls (synchronous; this launch
 *                      script measures it and writes into the handoff row; section-50b
 *                      reads + emits PERF_ROW)
 *   peDeliveryWallMs — wall clock from emit completion to all 100 LogEntry__c rows
 *                      persisted (async PE delivery; measured by section-50b as
 *                      time-to-100-rows minus a known floor — the verify script's
 *                      pollStartMs - launchCompleteEpoch — see section-50b header)
 *   persistedCount   — actual count after polling (target = 100)
 *   droppedCount     — 100 - persistedCount (target = 0)
 *
 * Run-isolation: handoff row + persisted LogEntry__c rows are deleted by section-50b
 *   cleanup (filter: Foobar Name LIKE 'Section50Load_%'; LogEntry ClassMethod__c LIKE
 *   'LOG_TestSection50_%' from TODAY by current user). Re-running section-50 before
 *   section-50b leaves orphan handoff rows; verify script ORDER BY CreatedDate DESC
 *   LIMIT 1 always picks the latest. LogEntry rows from earlier runs persist until the
 *   matching verify script's cleanup, but the run-stamped ClassMethod__c marker keeps
 *   each run's verify query scoped to its own 100 rows.
 *
 * Prerequisites:
 *   - subscriber scratch org with kern managed package installed
 *   - kern__LogSetting__c.IsEnabled__c = true with no ClassFilter__c (verified on org —
 *     ClassFilter__c is null in org-defaults so all classes pass isLoggable allowlist)
 *   - kern__LogSetting__c.LogLevelThreshold__c = DEBUG or INFO (we emit INFO; verified
 *     on org — threshold is DEBUG so INFO passes)
 *   - PE daily quota headroom ≥ 100 (verified on org — 0/40000 used)
 *   - kern__Foobar__c trigger has no configured TriggerAction__mdt (verified — empty)
 *
 * Run (in two stages — separated by ~10-60 s of wall-clock PE delivery time):
 *   sf apex run --file release-testing/scripts/section-50-load-logger-pe-quota.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *   (wait ~10-60 s for the 100 PEs to deliver and TRG_PersistLogEntry to persist 100 LogEntry__c rows)
 *   sf apex run --file release-testing/scripts/section-50b-load-logger-pe-quota-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock for the LAUNCH script: ~1-3 seconds (100 PE publishes + one Foobar
 * insert). Verify script wall-clock budget: up to 60 s polling.
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 50 (extended-load Phase 3): Load Test — Logger PE Quota (Launch) ===');

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String RUN_STAMP_50 = String.valueOf(System.currentTimeMillis());
final String HANDOFF_NAME = 'Section50Load_' + RUN_STAMP_50;
final String CLASS_METHOD_MARKER = 'LOG_TestSection50_' + RUN_STAMP_50 + '.peQuotaFlood';
final Integer EMIT_COUNT = 100;

try
{
	String correlationId = kern.LOG_Builder.startCorrelation();

	Assert.isNotNull(correlationId,
		'50-launch: startCorrelation() must return a non-null correlationId for downstream verify');
	Assert.isTrue(String.isNotBlank(correlationId),
		'50-launch: startCorrelation() correlationId must be non-blank; got: "' + correlationId + '"');

	String launchTransactionId = Request.getCurrent().getRequestId();

	Long startWallMs = System.currentTimeMillis();
	for(Integer index = 0; index < EMIT_COUNT; index++)
	{
		kern.LOG_Builder.build()
			.info('Section50 PE flood entry ' + index)
			.emitAt(CLASS_METHOD_MARKER);
	}
	Long emitWallMs = System.currentTimeMillis() - startWallMs;

	System.debug(LoggingLevel.INFO,
		'50-launch (emit) PASS: ' + EMIT_COUNT + ' kern.LOG_Builder emit() calls completed in '
			+ emitWallMs + 'ms (no PublishImmediate governor breach; cap=150/tx). '
			+ 'CorrelationId=' + correlationId + ', TransactionId=' + launchTransactionId);

	Map<String, Object> handoff = new Map<String, Object>
	{
		'runStamp' => RUN_STAMP_50,
		'correlationId' => correlationId,
		'transactionId' => launchTransactionId,
		'classMethodMarker' => CLASS_METHOD_MARKER,
		'emitCount' => EMIT_COUNT,
		'emitWallMs' => emitWallMs,
		'launchCompletedAtMs' => System.currentTimeMillis()
	};

	kern__Foobar__c handoffRow = new kern__Foobar__c
	(
		Name = HANDOFF_NAME,
		kern__TextAreaLong__c = JSON.serialize(handoff)
	);
	insert handoffRow;

	System.debug(LoggingLevel.INFO,
		'50-launch (handoff) PASS: persisted handoff row ' + handoffRow.Id + ' Name=' + HANDOFF_NAME
			+ ' with runStamp + correlationId + transactionId + emitWallMs. '
			+ 'Run section-50b after ~10-60 s for persistence verification + PERF_ROW emission.');

	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
		'50-launch FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('50-launch: ' + scenarioError.getMessage());
	fail++;
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 50 (Launch): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 50 (Launch) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 50 (Launch) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 50 (Launch) COMPLETE: 100 PEs published. Run section-50b after PE delivery (~10-60 s) to verify persistence + emit PERF_ROW. ===');
}
