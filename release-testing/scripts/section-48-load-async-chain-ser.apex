/**
 * Section 48 (extended-load Phase 3, Tier 2): Load Test — UTIL_AsyncChain context serialization (Launch)
 *
 * Stresses kern.UTIL_AsyncChain serialization across N chained Queueable boundaries by building
 * a chain whose every step writes a 1KB random alphanumeric payload to ChainContext under a
 * unique key (step_<currentStepIndex>) AND reads back the previous step's payload to prove the
 * cross-transaction JSON round-trip survives. Each step adds a fresh ~1KB serialized payload to
 * AsyncChainExecution__c.ContextData__c so the ContextData__c grows linearly to the chain's
 * total step count × 1024 chars (plus framework reserved keys).
 *
 * Launch + verify split (mirrors section-34 / 56 precedent — commit 6a34a90): chains cannot
 * reach terminal status within a single execute-anonymous transaction because Queueables only
 * dequeue AFTER the enqueueing transaction commits. Polling for terminal status in the same
 * script either never sees the dequeue or blows the 10s sync CPU governor on busy-wait. This
 * script LAUNCHES the chain, captures the run-stamped chain name + execution ID, and exits.
 * Section 48b polls for terminal status, asserts the behaviour gates, and emits PERF_ROW lines.
 *
 * SPEC vs ACTUAL — step count (50 → 28):
 *   Spec called for "50 chained Queueable steps × 1KB context per step (final ~50KB)".
 *   Pre-flight survey found:
 *   1) Framework default kern.UTIL_AsyncChain.DEFAULT_MAX_CONTEXT_SIZE = 32768 chars (32K).
 *      A 50-step chain with 1KB payload each would serialize to ~52K and trip the
 *      "Chain context overflow" guard at UTIL_AsyncChain.cls line 1685, marking the chain
 *      Failed BEFORE the spec's behaviour assertions could run.
 *   2) The .withMaxContextSize(Integer) builder method is declared `public ChainBuilder ...`
 *      at UTIL_AsyncChain.cls line 885 — NOT `global`. Subscribers (and anonymous Apex from
 *      a subscriber org) cannot call it: deploy probe of test code calling
 *      .withMaxContextSize(8192) failed with "Method is not visible:
 *      kern.UTIL_AsyncChain.ChainBuilder kern.UTIL_AsyncChain.ChainBuilder.withMaxContextSize"
 *      (deploy ID 0AfRu00000ci9RVKAY). New framework follow-up A35 captures this.
 *   Adopted: 28-step chain × 1024-char payload = ~28,672 chars of WriteContextStep payload +
 *   ~500-1000 chars of framework reserved keys (__logContext, transient __previousStepResult)
 *   ≈ ~29.7KB serialized, comfortably under the 32K default. The cross-boundary serialization
 *   stress is preserved (28 round-trips through JSON.serialize → DML → query → JSON.deserialize
 *   exercises the same code path as 50). When A35 ships (.withMaxContextSize promoted to
 *   global), this script can be retuned to the spec's full 50 steps × 1KB.
 *
 * SPEC vs ACTUAL — fixture step approach:
 *   Pre-flight survey of release-testing/subscriber/classes/SubscriberChainSteps.cls confirmed
 *   no existing step writes a sized payload to context AND reads back a prior step's payload
 *   for serialization-round-trip verification. The closest existing step (CreateFoobarStep)
 *   writes a single Id under foobarId; it doesn't grow context per-step. Three new fixture
 *   steps were added to SubscriberChainSteps:
 *     - WriteContextStep — writes 1024-char payload at step_<index>, reads step_<index-1>
 *     - WriteUndersizedContextStep + NoWriteStep — drive the WriteContextStep failure paths
 *       (covered by SubscriberChainSteps_TEST.shouldFailWhenPriorPayload* methods)
 *
 * SPEC vs ACTUAL — per-step DurationMs__c / WaitMs__c:
 *   Spec called for per-step DurationMs__c + WaitMs__c on AsyncChainStepExecution__c child rows.
 *   No AsyncChainStepExecution__c table exists — per-step data is stored as a JSON array on
 *   AsyncChainExecution__c.StepLog__c (LongTextArea, 128K). Each entry deserializes to
 *   kern.UTIL_AsyncChain.DTO_StepDefinition with className/stepName/success/durationMs/message
 *   fields. There is NO startedAt or waitMs per step; only chain-level StartedAt__c +
 *   CompletedAt__c + DurationMs__c (wall clock). Section 48b parses StepLog__c, extracts
 *   per-step durationMs, and computes wait approximation as
 *   (chainWallMs - sum(step.durationMs)) / max(1, stepCount-1) — see verify script for the
 *   derivation. Note: DTO_StepDefinition is `public` not `global` so 48b cannot
 *   JSON.deserialize() into the typed class — it deserializes untyped and pulls 'durationMs'
 *   off each Map<String, Object>.
 *
 * SPEC vs ACTUAL — initial baseline + threshold:
 *   First run captures the actual wallMsTotal / avgStepWaitMs / avgStepDurationMs /
 *   contextSerializationMsApprox values; threshold is 50% (Queueable wait jitter is high in
 *   scratch orgs). Captured values land in the commit message and feed Phase 2.6's
 *   perf-history harvester via the PERF_ROW lines emitted by section-48b.
 *
 * BEHAVIOUR ASSERTIONS (HARD GATE — verified in section-48b):
 *   - Final Status__c = 'Completed' (no step skipped, no overflow)
 *   - CompletedSteps__c = 28 (every WriteContextStep persisted success)
 *   - StepLog__c parses as a 28-element array, every element has durationMs > 0
 *   - ContextData__c contains step_0 .. step_27 keys, each with a 1024-char payload
 *   - ContextData__c serialized length > 28KB and < 32KB (within default budget)
 *   - DurationMs__c (chain-level wall clock) populated and > 0
 *
 * PERF METRICS (soft gate — emitted by section-48b after polling):
 *   wallMsTotal              — total wall clock from execute() to terminal status
 *   avgStepWaitMs            — average per-step wait time (estimated: see derivation above)
 *   avgStepDurationMs        — average per-step CPU duration (from StepLog__c.durationMs)
 *   contextSerializationMsApprox — approximate per-boundary serialization cost
 *                                  (chainWallMs - sum(stepDurations)) / max(1, stepCount-1)
 *
 * Run-isolation: chain is named with a per-run stamp (Section48Load_<epoch>) so
 * section-48b's verify query LIKE 'Section48Load_%' ORDER BY CreatedDate DESC LIMIT 1
 * always finds THIS run's chain (older runs become orphans, swept by the cleanup at the
 * end of section-48b).
 *
 * Prerequisites:
 *   - subscriber scratch org with kern managed package installed
 *   - SubscriberChainSteps fixture deployed (with WriteContextStep + WriteUndersizedContextStep
 *     + NoWriteStep added in this commit)
 *   - kern__FeatureFlag.AsyncChain__mdt record exists and is Active=true (default ON)
 *
 * Run (in two stages — separated by ~3-5 minutes of wall-clock dequeue time):
 *   sf apex run --file release-testing/scripts/section-48-load-async-chain-ser.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *   (wait 3-5 minutes for all 28 Queueables to dequeue serially)
 *   sf apex run --file release-testing/scripts/section-48b-load-async-chain-ser-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock for the LAUNCH script: <2 seconds (build builder, 1 DML insert,
 * enqueue first Queueable). Verify script wall-clock budget: up to 6 minutes.
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 48 (extended-load Phase 3): Load Test — UTIL_AsyncChain context serialization (Launch) ===');

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String RUN_STAMP_48 = String.valueOf(Datetime.now().getTime());
final String CHAIN_NAME_48 = 'Section48Load_' + RUN_STAMP_48;
final Integer STEP_COUNT = 28;
final Integer STEPS_PER_QUEUEABLE_DEPTH = STEP_COUNT + 1;

try
{
	kern.UTIL_AsyncChain.ChainBuilder builder = kern.UTIL_AsyncChain.newChain(CHAIN_NAME_48);
	for(Integer index = 0; index < STEP_COUNT; index++)
	{
		builder.then(new SubscriberChainSteps.WriteContextStep());
	}

	String executionId = builder.execute();
	Assert.isNotNull(executionId, '48-launch: execute() should return a non-null execution ID');

	kern__AsyncChainExecution__c readback =
	[
		SELECT kern__Status__c, kern__TotalSteps__c, kern__ChainName__c
		FROM kern__AsyncChainExecution__c
		WHERE Id = :executionId
	];
	Assert.areEqual(CHAIN_NAME_48, readback.kern__ChainName__c,
		'48-launch: persisted chain name should match the run-stamped name');
	Assert.areEqual(STEP_COUNT, (Integer)readback.kern__TotalSteps__c,
		'48-launch: TotalSteps__c should equal ' + STEP_COUNT + ' at execute() time');

	System.debug(LoggingLevel.INFO,
		'48-launch PASS: ' + STEP_COUNT + '-step WriteContextStep chain launched as ' + CHAIN_NAME_48
			+ ' (' + executionId + '). TotalSteps=' + readback.kern__TotalSteps__c
			+ ' Status=' + readback.kern__Status__c
			+ '. Run section-48b after ~3-5 minutes for dequeue + verification.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '48-launch FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('48-launch: ' + scenarioError.getMessage());
	fail++;
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 48 (Launch): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 48 (Launch) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 48 (Launch) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 48 (Launch) COMPLETE: chain launched. Run section-48b after dequeue (~3-5 min) to verify + emit PERF_ROW. ===');
}
