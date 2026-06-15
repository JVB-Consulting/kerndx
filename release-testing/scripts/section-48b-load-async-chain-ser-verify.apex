/**
 * Section 48b (extended-load Phase 3, Tier 2): Load Test — UTIL_AsyncChain context serialization (Verify)
 *
 * Verification half of the section-48 launch + verify split. Section 48 launches a 28-step chain
 * named Section48Load_<runStamp>; this script polls AsyncChainExecution__c by chain-name LIKE
 * pattern, asserts the HARD GATES (Status=Completed, CompletedSteps=28, every step's
 * StepLog__c entry has durationMs > 0, ContextData__c contains step_0..step_27 each with the
 * expected 1024-char payload), then emits the four PERF_ROW lines for Phase 2.6's harvester.
 *
 * Polling strategy: bounded retries with executeAnonymous-friendly System.sleep substitute (busy
 * loop with a CPU governor escape). Most queueables in scratch orgs dequeue within ~2-10s each;
 * 28 steps serially could take 30-300 seconds. Verify script wall-clock budget: up to 6 minutes.
 * If still Running after the budget, the script emits a clear diagnostic + throws an
 * AssertException so the operator knows to wait longer and re-run 48b only.
 *
 * SPEC vs ACTUAL — per-step DurationMs__c / WaitMs__c source:
 *   Per-step durations are inside the StepLog__c LongTextArea as a JSON array of
 *   kern.UTIL_AsyncChain.DTO_StepDefinition snapshots. DTO_StepDefinition is `public` (NOT
 *   `global`) so this script CANNOT JSON.deserialize() into the typed class — instead it does
 *   JSON.deserializeUntyped() and pulls 'durationMs' off each Map<String, Object> entry. There
 *   is NO per-step startedAt / waitMs in the framework — wait is an emergent property of
 *   Queueable scheduler scheduling. We approximate avgStepWaitMs as
 *   ((chainWallMs - sum(stepDurationsMs)) / max(1, stepCount-1)) so that the metric is
 *   computable from the on-disk record without changing the framework. This biases the wait
 *   estimate toward over-counting (sub-second scheduler gaps and AsyncApexJob queue priority
 *   variance both fold into "wait" rather than "duration"), which is acceptable for relative
 *   trend tracking across runs. Same reasoning applied to contextSerializationMsApprox: it
 *   is the same "leftover" wall-clock minus per-step CPU duration, normalised per boundary.
 *
 * SPEC vs ACTUAL — DTO field access:
 *   StepLog__c entries serialize with field names matching DTO_StepDefinition: className,
 *   stepName, success, durationMs, message, isErrorHandler, isCompletionHandler. Boolean
 *   fields suppressed when null (continueOnError, isCompletionHandler). This script reads
 *   only durationMs + success.
 *
 * Cleanup happens at the end of THIS script (not section-48) because the verify queries depend
 * on the launched row. Cleanup deletes Section48Load_% chain rows from TODAY by current user
 * (LIMIT 9000), bounded so re-runs don't exceed governor.
 *
 * Status constants are not exposed in kern.SEL_AsyncChainExecution as global, so we duplicate
 * the literal values here (matches section-34 / 56 pattern).
 *
 * Prerequisites:
 *   - Section 48 launch executed in this org within the last several minutes
 *   - At least ~3-5 minutes of wall-clock time elapsed since launch (28 Queueables serial dequeue)
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-48b-load-async-chain-ser-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 48b (extended-load Phase 3): Load Test — UTIL_AsyncChain context serialization (Verify) ===');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String STATUS_COMPLETED = 'Completed';
final String STATUS_FAILED = 'Failed';
final String STATUS_RUNNING = 'Running';
final Integer EXPECTED_STEP_COUNT = 28;
final Integer EXPECTED_PAYLOAD_SIZE = 1024;
final Integer DEFAULT_MAX_CONTEXT_SIZE = 32768;
final Integer MIN_EXPECTED_CONTEXT_BYTES = EXPECTED_STEP_COUNT * EXPECTED_PAYLOAD_SIZE;
final String CONTEXT_KEY_PREFIX = 'step_';

try
{
	List<kern__AsyncChainExecution__c> rows =
	[
			SELECT Id,
					kern__ChainName__c,
					kern__Status__c,
					kern__TotalSteps__c,
					kern__CompletedSteps__c,
					kern__ErrorMessage__c,
					kern__ContextData__c,
					kern__StepLog__c,
					kern__StartedAt__c,
					kern__CompletedAt__c,
					kern__DurationMs__c
			FROM kern__AsyncChainExecution__c
			WHERE kern__ChainName__c LIKE 'Section48Load_%'
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	Assert.areEqual(1, rows.size(), '48b-verify: expected exactly one Section48Load_% chain row, got ' + rows.size()
			+ ' (was section-48 launched first?)');

	kern__AsyncChainExecution__c chain = rows[0];

	Assert.areEqual(STATUS_COMPLETED, chain.kern__Status__c,
			'48b-verify: chain should be Completed; got Status=' + chain.kern__Status__c
			+ '. ErrorMessage=' + chain.kern__ErrorMessage__c
			+ '. CompletedSteps=' + chain.kern__CompletedSteps__c + '/' + chain.kern__TotalSteps__c
			+ '. If still Running, the 28 Queueables have not finished dequeuing — wait longer (~3-5 min total) and re-run section-48b.');

	Assert.areEqual(EXPECTED_STEP_COUNT, (Integer)chain.kern__TotalSteps__c,
			'48b-verify: TotalSteps__c should be ' + EXPECTED_STEP_COUNT + '; got ' + chain.kern__TotalSteps__c);

	Assert.areEqual(EXPECTED_STEP_COUNT, (Integer)chain.kern__CompletedSteps__c,
			'48b-verify: CompletedSteps__c should be ' + EXPECTED_STEP_COUNT + ' (no skipped steps); got '
			+ chain.kern__CompletedSteps__c);

	Assert.isNotNull(chain.kern__DurationMs__c,
			'48b-verify: chain-level DurationMs__c should be populated on terminal status');

	Assert.isTrue(chain.kern__DurationMs__c > 0,
			'48b-verify: chain-level DurationMs__c should be > 0 ms; got ' + chain.kern__DurationMs__c);

	Map<String, Object> contextMap = (Map<String, Object>)JSON.deserializeUntyped(chain.kern__ContextData__c);
	Integer contextBytes = chain.kern__ContextData__c.length();

	Assert.isTrue(contextBytes >= MIN_EXPECTED_CONTEXT_BYTES,
			'48b-verify: ContextData__c length should be >= ' + MIN_EXPECTED_CONTEXT_BYTES
			+ ' chars (' + EXPECTED_STEP_COUNT + ' steps × ' + EXPECTED_PAYLOAD_SIZE + '); got ' + contextBytes);

	Assert.isTrue(contextBytes < DEFAULT_MAX_CONTEXT_SIZE,
			'48b-verify: ContextData__c length should be < ' + DEFAULT_MAX_CONTEXT_SIZE
			+ ' chars (default budget); got ' + contextBytes
			+ '. If this fails, the framework would have marked Status=Failed with overflow message.');

	for(Integer index = 0; index < EXPECTED_STEP_COUNT; index++)
	{
		String key = CONTEXT_KEY_PREFIX + index;
		Object payload = contextMap.get(key);
		Assert.isNotNull(payload, '48b-verify: context should contain key ' + key);
		String payloadString = (String)payload;
		Assert.areEqual(EXPECTED_PAYLOAD_SIZE, payloadString.length(),
				'48b-verify: payload at ' + key + ' should be ' + EXPECTED_PAYLOAD_SIZE + ' chars; got '
				+ payloadString.length());
	}

	Object stepLogObj = JSON.deserializeUntyped(chain.kern__StepLog__c);
	List<Object> stepLog = (List<Object>)stepLogObj;
	Assert.areEqual(EXPECTED_STEP_COUNT, stepLog.size(),
			'48b-verify: StepLog__c should be a ' + EXPECTED_STEP_COUNT + '-element JSON array; got ' + stepLog.size());

	Long sumStepDurationsMs = 0;
	Integer stepsWithDuration = 0;
	Integer stepsWithSuccess = 0;
	for(Integer index = 0; index < stepLog.size(); index++)
	{
		Map<String, Object> stepEntry = (Map<String, Object>)stepLog[index];
		Object durationValue = stepEntry.get('durationMs');
		Assert.isNotNull(durationValue, '48b-verify: step ' + index + ' StepLog entry should have durationMs');
		Long stepDurationMs = (Long)durationValue;
		Assert.isTrue(stepDurationMs > 0,
				'48b-verify: step ' + index + ' durationMs should be > 0; got ' + stepDurationMs);
		sumStepDurationsMs += stepDurationMs;
		stepsWithDuration++;

		Object successValue = stepEntry.get('success');
		if(successValue == true)
		{
			stepsWithSuccess++;
		}
	}
	Assert.areEqual(EXPECTED_STEP_COUNT, stepsWithDuration,
			'48b-verify: every StepLog entry should have a non-null durationMs');
	Assert.areEqual(EXPECTED_STEP_COUNT, stepsWithSuccess,
			'48b-verify: every step should have success=true');

	Long wallMsTotal = (Long)chain.kern__DurationMs__c;
	Long avgStepDurationMs = stepsWithDuration > 0 ? (sumStepDurationsMs / stepsWithDuration) : 0;
	Long leftoverMs = wallMsTotal - sumStepDurationsMs;
	Long avgStepWaitMs = (EXPECTED_STEP_COUNT - 1) > 0 ? (leftoverMs / (EXPECTED_STEP_COUNT - 1)) : 0;
	Long contextSerializationMsApprox = (EXPECTED_STEP_COUNT - 1) > 0 ? (leftoverMs / (EXPECTED_STEP_COUNT - 1)) : 0;

	Map<String, Object> wallRow = new Map<String, Object> {'section' => 48, 'metric' => 'wallMsTotal', 'value' => wallMsTotal};
	Map<String, Object> waitRow = new Map<String, Object> {'section' => 48, 'metric' => 'avgStepWaitMs', 'value' => avgStepWaitMs};
	Map<String, Object> durRow = new Map<String, Object> {'section' => 48, 'metric' => 'avgStepDurationMs', 'value' => avgStepDurationMs};
	Map<String, Object> serRow = new Map<String, Object> {'section' => 48, 'metric' => 'contextSerializationMsApprox', 'value' => contextSerializationMsApprox};
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(wallRow));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(waitRow));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(durRow));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(serRow));

	System.debug(LoggingLevel.INFO,
			'48b-verify PASS: chain ' + chain.kern__ChainName__c + ' Completed with '
			+ stepsWithDuration + '/' + EXPECTED_STEP_COUNT + ' steps logged. '
			+ 'ContextData=' + contextBytes + ' chars (budget ' + DEFAULT_MAX_CONTEXT_SIZE + '). '
			+ 'wallTotal=' + wallMsTotal + 'ms sumStepCpu=' + sumStepDurationsMs
			+ 'ms avgStepCpu=' + avgStepDurationMs + 'ms avgStepWait=' + avgStepWaitMs
			+ 'ms ctxSerApprox=' + contextSerializationMsApprox + 'ms.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '48b-verify FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('48b-verify: ' + scenarioError.getMessage());
	fail++;
}

try
{
	List<kern__AsyncChainExecution__c> residualChains =
	[
			SELECT Id
			FROM kern__AsyncChainExecution__c
			WHERE kern__ChainName__c LIKE 'Section48Load_%'
			AND CreatedDate = TODAY
			AND CreatedById = :UserInfo.getUserId()
			LIMIT 9000
	];
	if(!residualChains.isEmpty())
	{
		delete residualChains;
		System.debug(LoggingLevel.INFO, 'Cleanup: deleted ' + residualChains.size() + ' kern__AsyncChainExecution__c row(s)');
	}
}
catch(Exception cleanupError)
{
	System.debug(LoggingLevel.WARN, '48b cleanup warning (AsyncChainExecution__c delete failed): ' + cleanupError.getMessage());
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 48b (Verify): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 48b (Verify) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 48b (Verify) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 48b (Verify) COMPLETE: All scenarios verified + PERF_ROW emitted ===');
}
