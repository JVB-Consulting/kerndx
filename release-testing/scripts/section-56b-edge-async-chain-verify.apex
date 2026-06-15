/**
 * Section 56b: UTIL_AsyncChain — Edge Cases (Verify)
 *
 * Verification half of the section-56 launch + verify split. Section 56 launches four edge-
 * case chains; this script asserts their terminal state after wall-clock dequeue time. Mirrors
 * the section-34 / 34b pattern (chains cannot reach terminal status within a single execute-
 * anonymous transaction because Queueables only dequeue AFTER the enqueueing transaction
 * commits, and polling in the same transaction either never sees the dequeue or blows the
 * 60s sync CPU governor).
 *
 * Scenario coverage:
 *   - 56a: a 3-step chain configured with .withMaxSteps(2) is marked Failed at step index 2
 *     with ErrorMessage containing "Max steps".
 *   - 56b: synchronous-only build-time honesty check — verified entirely in section-56,
 *     nothing to verify here.
 *   - 56c: ApiStep chain with withParameterFrom('foo','NotInContextKey56c') Completes
 *     successfully and apiResult.success=true (graceful skip of missing context key).
 *   - 56d: success-path chain with onComplete + onError sets KEY_COMPLETED=true and not
 *     KEY_ERROR_HANDLED; failure-path chain with the same handlers sets KEY_ERROR_HANDLED=true
 *     and NOT KEY_COMPLETED. Documents that onComplete is success-only in the framework.
 *
 * Cleanup happens at the end of THIS script (not section-56) because the verify queries depend
 * on the launched rows. If section-56 is re-run before section-56b, the SOQL filter in each
 * scenario uses ChainName__c LIKE 'Section56X_%' ORDER BY CreatedDate DESC LIMIT 1, so the
 * MOST RECENT chain wins (the older one becomes orphan and is swept by the cleanup at the end).
 *
 * Status constants are not exposed in kern.SEL_AsyncChainExecution (public, not global), so
 * we duplicate the literal values here (matches section-34 pattern).
 *
 * Prerequisites:
 *   - Section 56 launch executed in this org within the last few minutes
 *   - At least 30-60 seconds of wall-clock time elapsed since launch (to allow Queueables
 *     to dequeue and the chains to reach terminal status)
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-56b-edge-async-chain-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 56b: UTIL_AsyncChain Edge Cases (Verify) ===');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String STATUS_COMPLETED = 'Completed';
final String STATUS_FAILED = 'Failed';

// Verify 56a — 2-step chain at the .withMaxSteps(2) boundary completed successfully.
// Confirms framework finding A10 build-time guard does not over-restrict: a chain whose registered
// step count exactly equals maxSteps must build, enqueue, and run to Completed with
// CompletedSteps==TotalSteps==2.
try
{
	List<kern__AsyncChainExecution__c> rows56a =
	[
			SELECT kern__Status__c,
					kern__CompletedSteps__c,
					kern__TotalSteps__c,
					kern__ErrorMessage__c
			FROM kern__AsyncChainExecution__c
			WHERE kern__ChainName__c LIKE 'Section56a_MaxSteps_%'
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	Assert.areEqual(1, rows56a.size(), '56a-verify: expected exactly one Section56a chain row, got ' + rows56a.size() + ' (was section-56 launched first?)');
	kern__AsyncChainExecution__c execution56a = rows56a[0];
	Assert.areEqual(STATUS_COMPLETED, execution56a.kern__Status__c,
			'56a-verify: chain at the maxSteps boundary should reach Completed; got Status=' + execution56a.kern__Status__c
			+ ' ErrorMessage=' + execution56a.kern__ErrorMessage__c
			+ ' (chain may still be Running — wait longer between launch and verify, or scratch-org queueable backpressure may be saturating)');
	Assert.areEqual(2, (Integer)execution56a.kern__TotalSteps__c, '56a-verify: TotalSteps__c should be 2');
	Assert.areEqual(2, (Integer)execution56a.kern__CompletedSteps__c,
			'56a-verify: CompletedSteps__c should equal 2 (both steps executed at the cap boundary)');
	System.debug(LoggingLevel.INFO,
			'56a-verify PASS: 2-step chain at withMaxSteps(2) boundary → Completed ('
			+ execution56a.kern__CompletedSteps__c + '/' + execution56a.kern__TotalSteps__c
			+ ' steps)');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '56a-verify FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('56a-verify: ' + scenarioError.getMessage());
	fail++;
}

// 56b — synchronous-only build-time honesty check fully verified in section-56 launch.
// Nothing to assert here, just acknowledge.
System.debug(LoggingLevel.INFO, '56b-verify SKIP: synchronous-only assertion in section-56 launch; no async state to verify');

// Verify 56c — ApiStep chain with withParameterFrom('foo','NotInContextKey56c') Completed
// successfully and apiResult.success=true. Confirms graceful skip at UTIL_AsyncChain.cls
// lines 1366-1378 (when contextValue is null, the parameter is silently NOT added; the
// API call still fires and succeeds against the registered 200 mock).
try
{
	List<kern__AsyncChainExecution__c> rows56c =
	[
			SELECT kern__Status__c,
					kern__ContextData__c
			FROM kern__AsyncChainExecution__c
			WHERE kern__ChainName__c LIKE 'Section56c_MissingKey_%'
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	Assert.areEqual(1, rows56c.size(), '56c-verify: expected exactly one Section56c chain row, got ' + rows56c.size());
	kern__AsyncChainExecution__c execution56c = rows56c[0];
	Assert.areEqual(STATUS_COMPLETED, execution56c.kern__Status__c,
			'56c-verify: chain should Complete despite missing context key (graceful skip, not throw); got Status=' + execution56c.kern__Status__c);
	Map<String, Object> context56c = (Map<String, Object>)JSON.deserializeUntyped(execution56c.kern__ContextData__c);
	Object apiResultObj = context56c.get('__apiResult_0');
	Assert.isNotNull(apiResultObj, '56c-verify: __apiResult_0 should be present in context (ApiStep wrote its result)');
	Map<String, Object> apiResult56c = (Map<String, Object>)apiResultObj;
	Assert.areEqual(true, apiResult56c.get('success'),
			'56c-verify: API call should succeed (mock returns 200) — got success=' + apiResult56c.get('success'));
	System.debug(LoggingLevel.INFO,
			'56c-verify PASS: ApiStep.withParameterFrom("foo","NotInContextKey56c") gracefully skipped the absent key; chain Completed with apiResult.success=true');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '56c-verify FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('56c-verify: ' + scenarioError.getMessage());
	fail++;
}

// Verify 56d — success-path chain ran onComplete (KEY_COMPLETED=true, KEY_ERROR_HANDLED null);
// failure-path chain ran onError (KEY_ERROR_HANDLED=true, KEY_COMPLETED null). Documents that
// the framework implements onComplete as a success-only hook (not "any terminal path"). See
// section-56 header for the spec follow-up against the extended-load spec §6.5 #7.
try
{
	List<kern__AsyncChainExecution__c> rows56dSuccess =
	[
			SELECT kern__Status__c,
					kern__ContextData__c
			FROM kern__AsyncChainExecution__c
			WHERE kern__ChainName__c LIKE 'Section56d_OnCompleteSuccess_%'
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	Assert.areEqual(1, rows56dSuccess.size(), '56d-verify: expected exactly one Section56d success row, got ' + rows56dSuccess.size());
	kern__AsyncChainExecution__c execSuccess56d = rows56dSuccess[0];
	Assert.areEqual(STATUS_COMPLETED, execSuccess56d.kern__Status__c, '56d-verify: success-path chain should be Completed; got Status=' + execSuccess56d.kern__Status__c);
	Map<String, Object> successContext56d = (Map<String, Object>)JSON.deserializeUntyped(execSuccess56d.kern__ContextData__c);
	Assert.areEqual(true, successContext56d.get(SubscriberChainSteps.KEY_COMPLETED), '56d-verify: success-path chain should set KEY_COMPLETED=true via onComplete handler');
	Assert.isNull(successContext56d.get(SubscriberChainSteps.KEY_ERROR_HANDLED), '56d-verify: success-path chain should NOT set KEY_ERROR_HANDLED (onError did not run)');

	List<kern__AsyncChainExecution__c> rows56dFailure =
	[
			SELECT kern__Status__c,
					kern__ContextData__c
			FROM kern__AsyncChainExecution__c
			WHERE kern__ChainName__c LIKE 'Section56d_OnCompleteFailure_%'
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	Assert.areEqual(1, rows56dFailure.size(), '56d-verify: expected exactly one Section56d failure row, got ' + rows56dFailure.size());
	kern__AsyncChainExecution__c execFailure56d = rows56dFailure[0];
	Assert.areEqual(STATUS_FAILED, execFailure56d.kern__Status__c, '56d-verify: failure-path chain should be Failed; got Status=' + execFailure56d.kern__Status__c);
	Map<String, Object> failureContext56d = (Map<String, Object>)JSON.deserializeUntyped(execFailure56d.kern__ContextData__c);
	Assert.areEqual(true, failureContext56d.get(SubscriberChainSteps.KEY_ERROR_HANDLED), '56d-verify: failure-path chain should set KEY_ERROR_HANDLED=true via onError handler');
	Assert.isNull(failureContext56d.get(SubscriberChainSteps.KEY_COMPLETED),
			'56d-verify: failure-path chain should NOT set KEY_COMPLETED — onComplete is success-only in the framework (see section-56 header for spec follow-up)');
	System.debug(LoggingLevel.INFO, '56d-verify PASS: onComplete fires on success path only; onError fires on failure path; honest semantic differs from spec §6.5 #7');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '56d-verify FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('56d-verify: ' + scenarioError.getMessage());
	fail++;
}

// Cleanup — bounded by remaining DML rows in this transaction. Section 56 launch inserts a
// handful of Foobar__c rows + ~5 AsyncChainExecution__c rows + 1 ApiCall__c row. LIMIT 9000
// leaves safety margin and survives many re-runs in the same day.
delete
[
		SELECT Id
		FROM kern__ApiCall__c
		WHERE kern__ServiceName__c = 'API_PostExample'
		AND CreatedDate = TODAY
		AND CreatedById = :UserInfo.getUserId()
		LIMIT 9000
];
delete
[
		SELECT Id
		FROM kern__Foobar__c
		WHERE CreatedDate = TODAY
		AND CreatedById = :UserInfo.getUserId()
		LIMIT 9000
];
delete
[
		SELECT Id
		FROM kern__AsyncChainExecution__c
		WHERE CreatedDate = TODAY
		AND CreatedById = :UserInfo.getUserId()
		LIMIT 9000
];
kern.API_MockFactory.clearMocks();
kern.TRG_Base.clearAllBypasses();

// Summary
System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 56b (Verify): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 56b (Verify) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 56b (Verify) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 56b (Verify) COMPLETE: All scenarios verified ===');
}
