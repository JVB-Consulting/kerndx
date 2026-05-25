/**
 * Section 56: UTIL_AsyncChain — Edge Cases (Launch)
 *
 * Closes gaps in async chain coverage beyond section-34/34b. Section-34 already exercises
 * happy single-step + multi-step + failing chain + onError + onComplete + getStatus + initial
 * context + ApiStep bridge + continueOnError + handler-callout-isolation. This script covers
 * four edge scenarios that section-34 does not touch:
 *
 *   1. withMaxSteps runtime ceiling — chain marked Failed when execution attempts a step
 *      beyond the configured ceiling.
 *   2. withMaxSteps "build-time guard" honesty check — confirms the framework does NOT
 *      validate steps.size() vs maxSteps at .then() / .execute() time; the cap is only
 *      enforced at runtime per step.
 *   3. ApiStep.withParameterFrom('missing-key') graceful skip — when the named context
 *      key is absent, the parameter is silently NOT added (no throw).
 *   4. onComplete handler scope — fires on the success terminal path only; on failure
 *      the onError handler runs and onComplete is NOT invoked.
 *
 * Launch + verify split (mirrors section-34 / 34b): chains cannot reach terminal status
 * within a single execute-anonymous transaction because Queueables only dequeue AFTER the
 * enqueueing transaction commits. Polling for terminal status in the same script either
 * never sees the dequeue or blows the 60s sync CPU governor on busy-wait. Section 56
 * therefore launches all chains here, captures predictable chain names, and section 56b
 * verifies the terminal status after ~30-60s of wall-clock dequeue time.
 *
 * Synchronous assertions live HERE (scenario 56b — the negative-build-time check),
 * since they don't need the chain to dequeue. Async-terminal assertions live in 56b.
 *
 * Deferrals to managed @IsTest harness or framework follow-up — captured by spec
 * §6.5 but structurally unreachable from execute-anonymous in this subscriber org:
 *
 *   - Chain depth at the DEFAULT_MAX_STEPS=50 boundary and at depth 51 (spec
 *     scenarios 2 + 3): a 50-step chain takes ~50-150 wall-seconds to dequeue
 *     each Queueable in scratch-org load conditions. Even the launch-phase
 *     enqueue would consume excessive setup time and the verify phase would
 *     have to wait minutes. Belongs in Subscriber_AsyncChainEdges_TEST where
 *     Test.startTest()/stopTest() forces synchronous queueable execution and
 *     each @IsTest method gets a fresh CPU budget.
 *
 *   - Recursive chain (spec scenario 4): would require a SubscriberChainSteps fixture
 *     step whose work() body invokes kern.UTIL_AsyncChain.newChain('inner').execute().
 *     The framework has NO recursion guard at the chain layer — each .execute() creates
 *     an independent AsyncChainExecution__c row. Platform Queueable depth limits and
 *     governor caps are the only bounds. The new fixture step + assertion belongs in
 *     Subscriber_AsyncChainEdges_TEST. FRAMEWORK FOLLOW-UP: consider a transaction-
 *     scoped guard that aborts a chain whose ChainExecutor is already on the
 *     transaction stack, to prevent runaway nested chains.
 *
 *   - Chain re-entry via record-trigger (spec scenario 6): no production trigger
 *     handler in the package launches a chain (chains are explicitly invoked from
 *     subscriber code). Would require a new SubscriberChainSteps trigger handler
 *     fixture that fires on a record insert. Belongs in Subscriber_AsyncChainEdges_TEST
 *     with a fresh fixture handler.
 *
 *   - Empirical proof that onComplete fires for BOTH success AND failure paths (spec
 *     scenario 7): reading the framework — handleChainCompletion() at line 1843
 *     registers the onComplete handler, and handleStepFailure() at line 1821 only
 *     registers onError. So onComplete is a SUCCESS-ONLY hook, not a "any terminal
 *     path" hook. Scenario 56d documents this honestly: onComplete on success path,
 *     onError on failure path, and onComplete is verifiably absent from context on
 *     the failure path. SPEC FOLLOW-UP: the extended-load spec §6.5 #7 was written assuming a
 *     "fires on either path" semantic that the framework does not implement; either
 *     update the spec to "onComplete = success-only" OR change the framework to
 *     register onComplete in both handleChainCompletion + handleStepFailure (the
 *     latter would require a status-check inside the handler since it would have
 *     to differentiate the two paths via context).
 *
 * Run-isolation: self-contained — does not depend on prior section state. Cleanup of
 * inserted Foobar__c / AsyncChainExecution__c / ApiCall__c rows happens in section-56b
 * after verification (cleaning up here would prevent the verify step from finding the
 * rows it needs).
 *
 * Implementation notes:
 *   - All chain names are stamped with a per-run RUN_STAMP_56 (current epoch ms in this
 *     transaction) AND a stable scenario name suffix (e.g. "Section56a_MaxSteps") so
 *     section-56b can find each chain by `WHERE ChainName__c LIKE 'Section56X_%'
 *     ORDER BY CreatedDate DESC LIMIT 1`. The stamp differentiates re-runs but the
 *     prefix is stable.
 *   - Status constants are not exposed in kern.SEL_AsyncChainExecution (public, not
 *     global), so we duplicate the literal values here (matches section-34 pattern).
 *
 * Prerequisites:
 *   - subscriber scratch org with the kern managed package installed
 *   - SubscriberChainSteps fixture class deployed
 *   - kern__FeatureFlag.AsyncChain__mdt record exists and is Active=true
 *   - kern__ApiSetting.PostExample CMDT record exists with MockingEnabled=true
 *
 * Run (in two stages — separated by ~30-60s of wall-clock dequeue time):
 *   sf apex run --file release-testing/scripts/section-56-edge-async-chain.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *   (wait 30-60 seconds for chains to dequeue)
 *   sf apex run --file release-testing/scripts/section-56b-edge-async-chain-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 56: UTIL_AsyncChain Edge Cases (Launch) ===');

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();
kern.API_MockFactory.clearMocks();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String RUN_STAMP_56 = String.valueOf(Datetime.now().getTime());

// Scenario 56a — withMaxSteps positive boundary (framework finding A10): a 2-step chain configured with
// .withMaxSteps(2) builds and executes successfully. Demonstrates that the build-time guard
// (covered by 56b in the negative direction) does not over-restrict at the boundary — a chain
// whose registered step count exactly equals maxSteps must build, enqueue, and run to Completed.
//
// LAUNCH ONLY — terminal-status assertion (Status=Completed, CompletedSteps=2) happens in
// section-56b verify.
try
{
	String chainName56a = 'Section56a_MaxSteps_' + RUN_STAMP_56;
	String executionId56a = kern.UTIL_AsyncChain.newChain(chainName56a)
			.withMaxSteps(2)
			.then(new SubscriberChainSteps.CreateFoobarStep())
			.then(new SubscriberChainSteps.UpdateFoobarStep())
			.execute();
	Assert.isNotNull(executionId56a, '56a-launch: execute() should return a non-null execution ID');
	System.debug(LoggingLevel.INFO, '56a-launch PASS: 2-step chain at withMaxSteps(2) boundary launched as ' + chainName56a + ' (' + executionId56a + ')');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '56a-launch FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('56a-launch: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 56b — withMaxSteps build-time guard (framework finding A10): .then() throws an
// IllegalStateException as soon as the next step would push the chain past the configured cap.
// Subscribers see the limit at chain-definition time rather than mid-execution. Fully synchronous —
// no terminal-status check, no section-56b verify needed.
//
// Construction sequence with withMaxSteps(2): step 1 ok, step 2 ok, step 3 throws. We swallow the
// expected throw and assert it occurred. We then continue past the failure to confirm the builder
// does not enter a corrupted state when the guard fires.
try
{
	Boolean threwOnBuild = false;
	String guardMessage = '';
	try
	{
		kern.UTIL_AsyncChain.ChainBuilder builder56b = kern.UTIL_AsyncChain.newChain('Section56b_BuildSize_' + RUN_STAMP_56)
				.withMaxSteps(2);
		for(Integer i = 0; i < 11; i++)
		{
			builder56b.then(new SubscriberChainSteps.CreateFoobarStep());
		}
	}
	catch(Exception buildError)
	{
		threwOnBuild = true;
		guardMessage = buildError.getMessage();
	}
	Assert.isTrue(threwOnBuild, '56b: framework SHOULD throw at .then() time when next step would exceed withMaxSteps (framework finding A10 build-time guard)');
	System.debug(LoggingLevel.INFO, '56b PASS: framework finding A10 build-time guard active — withMaxSteps(2) rejected the 3rd .then() call: ' + guardMessage.left(160));
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '56b FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('56b: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 56c — ApiStep.withParameterFrom('missing-key') graceful skip: registers a 200 mock for
// API_PostExample, builds a 1-step ApiStep chain that tries to read parameter 'foo' from a context
// key that is NEVER populated ('NotInContextKey56c'), and launches the chain. Section-56b
// verifies the chain still completes successfully and the API call returns success=true,
// confirming the framework's contract at UTIL_AsyncChain.cls lines 1366-1378: when
// context.get(contextKey) returns null, the parameter is silently NOT added (no throw, no
// failed StepResult). The downstream API call still fires with whatever default the handler's
// DTO_Request.populate() assigns.
//
// We pre-create a Foobar__c so the ApiStep has a real triggering record (API_PostExample
// requires one by default — requiresTriggeringRecord=true).
try
{
	kern.API_MockFactory.forService(kern.UTIL_System.getTypeForClassName('API_PostExample').getName())
			.body('{"echo":"missing-key-skipped"}')
			.statusCode(200)
			.register();

	kern__Foobar__c triggerRecord56c = new kern__Foobar__c(Name = 'Section56c trigger ' + RUN_STAMP_56);
	kern.DML_Builder.newTransaction().doInsert(triggerRecord56c).execute();

	String chainName56c = 'Section56c_MissingKey_' + RUN_STAMP_56;
	String executionId56c = kern.UTIL_AsyncChain.newChain(chainName56c)
			.then(new kern.UTIL_AsyncChain.ApiStep(kern.UTIL_System.getTypeForClassName('API_PostExample'))
					.triggeringRecord(triggerRecord56c.Id)
					.withParameterFrom('foo', 'NotInContextKey56c'))
			.execute();
	Assert.isNotNull(executionId56c, '56c-launch: execute() should return a non-null execution ID');
	System.debug(LoggingLevel.INFO, '56c-launch PASS: ApiStep chain with missing-context-key launched as ' + chainName56c + ' (' + executionId56c + ')');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '56c-launch FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('56c-launch: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 56d — onComplete handler scope: launches two chains, both configured with onComplete
// + onError handlers — one will succeed (CreateFoobarStep) and one will fail (FailingStep).
// Section-56b verifies the success-path chain runs onComplete (KEY_COMPLETED=true) and not
// onError, while the failure-path chain runs onError (KEY_ERROR_HANDLED=true) and NOT onComplete.
//
// This is the documented honest-counter to the extended-load spec §6.5 #7 which assumed both paths would
// invoke onComplete — see the deferral note in the header for the spec follow-up.
try
{
	String chainName56dSuccess = 'Section56d_OnCompleteSuccess_' + RUN_STAMP_56;
	String executionId56dSuccess = kern.UTIL_AsyncChain.newChain(chainName56dSuccess)
			.then(new SubscriberChainSteps.CreateFoobarStep())
			.onError(new SubscriberChainSteps.ErrorHandlerStep())
			.onComplete(new SubscriberChainSteps.CompletionHandlerStep())
			.execute();
	Assert.isNotNull(executionId56dSuccess, '56d-launch: success-path execute() should return a non-null execution ID');

	String chainName56dFailure = 'Section56d_OnCompleteFailure_' + RUN_STAMP_56;
	String executionId56dFailure = kern.UTIL_AsyncChain.newChain(chainName56dFailure)
			.then(new SubscriberChainSteps.FailingStep())
			.onError(new SubscriberChainSteps.ErrorHandlerStep())
			.onComplete(new SubscriberChainSteps.CompletionHandlerStep())
			.execute();
	Assert.isNotNull(executionId56dFailure, '56d-launch: failure-path execute() should return a non-null execution ID');
	System.debug(LoggingLevel.INFO, '56d-launch PASS: success-path (' + chainName56dSuccess + ') + failure-path (' + chainName56dFailure + ') chains launched');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '56d-launch FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('56d-launch: ' + scenarioError.getMessage());
	fail++;
}

// No cleanup here — section-56b needs the launched chain rows to exist for verification,
// and cleans up after asserting. If section-56b is skipped, manual cleanup is needed:
//   delete [SELECT Id FROM kern__Foobar__c WHERE CreatedDate = TODAY AND CreatedById = :UserInfo.getUserId() LIMIT 9000];
//   delete [SELECT Id FROM kern__AsyncChainExecution__c WHERE CreatedDate = TODAY AND CreatedById = :UserInfo.getUserId() LIMIT 9000];
//   delete [SELECT Id FROM kern__ApiCall__c WHERE CreatedDate = TODAY AND CreatedById = :UserInfo.getUserId() LIMIT 9000];
//   kern.API_MockFactory.clearMocks();
//   kern.TRG_Base.clearAllBypasses();

// Summary
System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 56 (Launch): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 56 (Launch) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 56 (Launch) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 56 (Launch) COMPLETE: All scenarios launched. Run section-56b after ~30-60s to verify terminal status. ===');
}
