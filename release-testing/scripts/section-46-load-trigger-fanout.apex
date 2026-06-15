/**
 * Section 46 (extended-load Phase 2): Load Test — TRG_Dispatcher fan-out + per-action filter
 *
 * Stresses kern.TRG_Dispatcher.run() with 200 Account records flowing through 8 chained
 * TriggerActions (4 BeforeInsert + 1 AfterInsert + 2 BeforeUpdate + 1 AfterUpdate). Verifies
 * the dispatcher's per-action UTIL_FormulaFilter constructor path, the recursion-shield
 * stack push/pop, and the canExecuteAction gate run on every dispatch.
 *
 * SPEC vs ACTUAL — trigger object choice (Foobar__c → Account):
 *   Spec assumed Foobar__c with 8 stub TriggerAction__mdt rows injected via
 *   `kern.TST_Factory.newTriggerAction(...)`. Pre-flight survey found:
 *   1) `TST_Factory.newTriggerAction*` overloads are all `@TestVisible private` —
 *      anonymous Apex is NOT a test context, so they cannot be called from a script.
 *   2) CMDT DML is platform-blocked from anonymous Apex (per Task 1.6 + 2.2 findings),
 *      so `insert new TriggerAction__mdt(...)` also fails.
 *   3) `TRG_Dispatcher.actionMetadataOverride` is `@TestVisible private` — same problem.
 *   4) Foobar__c has zero deployed TriggerSetting/TriggerAction rows (verified empty),
 *      so the dispatcher fires but does no per-handler work.
 *   Adopted: Account as the trigger target. The subscriber org has 11 deployed
 *   TriggerActions on Account across all 4 measured operations; bypassing the flow
 *   actions yields exactly the spec-prescribed 8 chained handlers per record per
 *   insert+update cycle.
 *
 * SPEC vs ACTUAL — per-action EntryCriteriaFormula:
 *   Spec called for `Name != null && LEN(Name) > 3` formulas on each action to drive
 *   ~1,600 formula contexts. None of the 8 deployed actions populate
 *   `EntryCriteriaFormula__c` — adding formulas requires CMDT DML which is blocked.
 *   The dispatcher still constructs a `UTIL_FormulaFilter` per dispatch (its constructor
 *   stores the blank formula string), but `UTIL_FormulaFilter.filter()` short-circuits
 *   at line 125 (`String.isBlank(formula)`) and returns input lists unmodified — zero
 *   per-record formula evaluations. Reported `formulaEvalsApprox` reflects this: 0.
 *
 * SPEC vs ACTUAL — handler selection:
 *   The 8 dispatched actions (with kern.TRG_InvokeFlow bypassed):
 *     BeforeInsert: TRG_ExecuteValidationRules (50), TRG_SetAccountDefaults (100),
 *                   TRG_ValidateAccountName (200), TRG_StampAccountSource (300)
 *     AfterInsert:  TRG_CreateAccountTask (100)
 *     BeforeUpdate: TRG_ExecuteValidationRules (50), TRG_StampAccountSource (300)
 *     AfterUpdate:  TRG_DetectNameChange (100)
 *   Validation rules are bypassed at the kern.UTIL_ValidationRule layer, so
 *   TRG_ExecuteValidationRules still dispatches but short-circuits internally. The
 *   `BlockDml` flow action (TST_FlowAction_BlockDml_BeforeInsert) is BypassExecution=true
 *   in metadata and is skipped at the SEL_TriggerAction level, not via dispatch suppression.
 *
 * SPEC vs ACTUAL — scaling (200 records preserved):
 *   Section 1f scaled to 100 and Section 12g to 50 because they accumulate stack depth
 *   from prior scenarios. This script is run in isolation (single scenario, no prior
 *   DML), so 200 stays comfortably under the 1001-frame stack limit even with 8 chained
 *   actions and after-trigger DML cascades (200 Account inserts + 200 Task inserts +
 *   200 Account updates + 200 Task inserts ≈ 800 DML rows in the measurement window,
 *   well under the 10K row governor).
 *
 * BEHAVIOUR ASSERTIONS (hard gate):
 *   - All 200 Accounts inserted and persisted (no rollback)
 *   - All 200 have Description='Default' (TRG_SetAccountDefaults fired in BeforeInsert)
 *   - All 200 have AccountSource='Subscriber Trigger' after insert (TRG_StampAccountSource fired)
 *   - Exactly 200 Tasks created from AfterInsert (TRG_CreateAccountTask fired on every record)
 *   - After Name update: exactly 200 additional Tasks (TRG_DetectNameChange detected change)
 *   - After update: AccountSource re-stamped on all 200 (TRG_StampAccountSource BeforeUpdate fired)
 *   - No action skipped due to recursion shield false-positive (verified by exact Task counts —
 *     a false-positive on TRG_CreateAccountTask or TRG_DetectNameChange would yield <200 Tasks)
 *
 * PERF METRICS (soft gate, harvested by Phase 2.6):
 *   wallMs, cpuMs, soqlCount, dmlCount, formulaEvalsApprox, recursionCheckOps
 *   — emitted as PERF_ROW: lines (one System.debug per metric)
 *
 *   formulaEvalsApprox derivation: 8 actions × 200 records × 0 evaluations (formula blank,
 *   filter() short-circuits before per-record evaluate() loop). With non-blank formulas
 *   this would be 8 × 200 = 1,600.
 *
 *   recursionCheckOps derivation: per dispatch, TRG_Dispatcher.canExecuteAction calls
 *   inRecursion which walks ACTION_STACK (size = 1 at check time, just-pushed frame).
 *   8 actions × 200 records × 1 frame walk = 1,600 ops.
 *
 * Run-isolation: self-contained. All 200 Accounts and their child Tasks are deleted in
 * cleanup (bounded LIMIT 9000).
 *
 * Prerequisites:
 *   - subscriber scratch org with kern managed package + subscriber test fixtures
 *   - TRG_Account trigger deployed (before/after insert/update/delete/undelete)
 *   - 11 TriggerAction__mdt rows on Account (ExecuteValidationRules, SetAccountDefaults,
 *     ValidateAccountName, StampAccountSource, CreateAccountTask, DetectNameChange,
 *     plus 3 TST_FlowAction rows that this script bypasses via TRG_InvokeFlow action bypass)
 *
 * Run (in isolation):
 *   sf apex run --file release-testing/scripts/section-46-load-trigger-fanout.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock: <10 seconds (200 inserts + 200 updates with after-trigger Task DML).
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 46 (extended-load Phase 2): Load Test — TRG_Dispatcher fan-out + per-action filter ===');

kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow');
kern.UTIL_ValidationRule.bypassObject('Account');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String RUN_STAMP = String.valueOf(Datetime.now().getTime());
final String NAME_TAG_INITIAL = 'LoadFanout46-' + RUN_STAMP;
final String NAME_TAG_UPDATED = 'LoadFanout46Upd-' + RUN_STAMP;
final Integer BATCH_SIZE = 200;
final String EXPECTED_DEFAULT_DESCRIPTION = 'Default';
final String EXPECTED_ACCOUNT_SOURCE = 'Subscriber Trigger';
final Integer ACTIONS_BEFORE_INSERT = 4;
final Integer ACTIONS_AFTER_INSERT = 1;
final Integer ACTIONS_BEFORE_UPDATE = 2;
final Integer ACTIONS_AFTER_UPDATE = 1;
final Integer ACTIONS_PER_RECORD_PER_CYCLE = ACTIONS_BEFORE_INSERT + ACTIONS_AFTER_INSERT + ACTIONS_BEFORE_UPDATE + ACTIONS_AFTER_UPDATE;

// Pre-flight: confirm the 11 deployed TriggerActions are intact and the 8 we expect to dispatch
// are not BypassExecution. A drift here would skew assertions and metrics.
Integer activeActionCount =
[
		SELECT COUNT()
		FROM kern__TriggerAction__mdt
		WHERE kern__TriggerSetting__r.kern__SObjectType__c = 'Account'
		AND kern__BypassExecution__c = FALSE
];
System.debug(LoggingLevel.INFO,
		'Pre-flight: ' + activeActionCount + ' active TriggerAction__mdt rows on Account (BypassExecution=false). '
		+ 'Expected dispatch fan-out per record per insert+update cycle = '
		+ ACTIONS_PER_RECORD_PER_CYCLE + ' (4 BI + 1 AI + 2 BU + 1 AU, with kern.TRG_InvokeFlow bypassed). '
		+ 'Total dispatches: ' + (BATCH_SIZE * ACTIONS_PER_RECORD_PER_CYCLE));

// Capture pre-run governor baselines (measurement window covers insert + post-insert query +
// update + post-update query, matching the spec's "200 records × 8 actions × insert+update"
// fan-out scope).
Long startWallMs = System.currentTimeMillis();
Long startCpuMs = Limits.getCpuTime();
Integer startSoqlCount = Limits.getQueries();
Integer startDmlCount = Limits.getDmlStatements();

try
{
	List<Account> bulkAccounts = new List<Account>();
	for(Integer index = 0; index < BATCH_SIZE; index++)
	{
		bulkAccounts.add(new Account
				(
						Name = NAME_TAG_INITIAL + '-' + index,
						Industry = 'Technology',
						Phone = '555-0046'
				));
	}

	insert bulkAccounts;

	// Behaviour assertion 1: every Account persisted with the trigger-defaulted Description
	// and trigger-stamped AccountSource. Sums on the loop avoid loading 200 records twice.
	List<Account> insertedReadback =
	[
			SELECT Id,
					Description,
					AccountSource
			FROM Account
			WHERE Name LIKE :(NAME_TAG_INITIAL + '%')
	];
	Assert.areEqual(BATCH_SIZE, insertedReadback.size(),
			'46: all ' + BATCH_SIZE + ' Accounts must be persisted after bulk insert. Got: ' + insertedReadback.size());

	Integer defaultedDescriptionCount = 0;
	Integer stampedSourceCount = 0;
	for(Account inserted : insertedReadback)
	{
		if(inserted.Description == EXPECTED_DEFAULT_DESCRIPTION)
		{
			defaultedDescriptionCount++;
		}
		if(inserted.AccountSource == EXPECTED_ACCOUNT_SOURCE)
		{
			stampedSourceCount++;
		}
	}
	Assert.areEqual(BATCH_SIZE, defaultedDescriptionCount,
			'46: TRG_SetAccountDefaults BeforeInsert must default Description on every record. '
			+ 'Defaulted: ' + defaultedDescriptionCount + '/' + BATCH_SIZE);
	Assert.areEqual(BATCH_SIZE, stampedSourceCount,
			'46: TRG_StampAccountSource BeforeInsert must stamp AccountSource on every record. '
			+ 'Stamped: ' + stampedSourceCount + '/' + BATCH_SIZE);

	// Behaviour assertion 2: AfterInsert handler created exactly one Task per Account.
	Integer insertTaskCount =
	[
			SELECT COUNT()
			FROM Task
			WHERE WhatId IN :bulkAccounts
	];
	Assert.areEqual(BATCH_SIZE, insertTaskCount,
			'46: TRG_CreateAccountTask AfterInsert must create exactly 1 Task per Account. '
			+ 'A recursion-shield false-positive would yield fewer. Got: ' + insertTaskCount + '/' + BATCH_SIZE);

	// Now update all 200 with a Name change to fire BeforeUpdate (2 actions) + AfterUpdate (1 action).
	// First clear AccountSource so the BeforeUpdate stamper has something to set, then mutate Name
	// so AfterUpdate's TRG_DetectNameChange sees a name change and writes a Task.
	for(Account inserted : insertedReadback)
	{
		inserted.AccountSource = null;
		inserted.Name = NAME_TAG_UPDATED + '-' + inserted.Id;
	}
	update insertedReadback;

	// Behaviour assertion 3: BeforeUpdate's TRG_StampAccountSource re-stamped AccountSource on
	// every record (it only re-stamps when Name changes — which it did for all 200).
	List<Account> updatedReadback =
	[
			SELECT Id,
					AccountSource
			FROM Account
			WHERE Name LIKE :(NAME_TAG_UPDATED + '%')
	];
	Assert.areEqual(BATCH_SIZE, updatedReadback.size(),
			'46: all ' + BATCH_SIZE + ' Accounts must show the updated Name tag. Got: ' + updatedReadback.size());

	Integer reStampedCount = 0;
	for(Account updated : updatedReadback)
	{
		if(updated.AccountSource == EXPECTED_ACCOUNT_SOURCE)
		{
			reStampedCount++;
		}
	}
	Assert.areEqual(BATCH_SIZE, reStampedCount,
			'46: TRG_StampAccountSource BeforeUpdate must re-stamp AccountSource on every Name-changed record. '
			+ 'Re-stamped: ' + reStampedCount + '/' + BATCH_SIZE);

	// Behaviour assertion 4: AfterUpdate handler created another Task per Account (Name change detected).
	// Total Task count should now be exactly 2 × BATCH_SIZE (1 from AfterInsert + 1 from AfterUpdate).
	Integer totalTaskCount =
	[
			SELECT COUNT()
			FROM Task
			WHERE WhatId IN :insertedReadback
	];
	Assert.areEqual(BATCH_SIZE * 2, totalTaskCount,
			'46: After insert+update cycle, total Tasks must be 2 × ' + BATCH_SIZE + ' = ' + (BATCH_SIZE * 2)
			+ ' (1 from TRG_CreateAccountTask AfterInsert + 1 from TRG_DetectNameChange AfterUpdate). '
			+ 'A recursion-shield false-positive would yield fewer. Got: ' + totalTaskCount);

	// Capture post-run governor metrics
	Long wallMs = System.currentTimeMillis() - startWallMs;
	Long cpuMs = Limits.getCpuTime() - startCpuMs;
	Integer soqlCount = Limits.getQueries() - startSoqlCount;
	Integer dmlCount = Limits.getDmlStatements() - startDmlCount;

	// formulaEvalsApprox: per-record formula evaluations performed by UTIL_FormulaFilter.filter().
	// With no EntryCriteriaFormula on any of the 8 deployed actions, filter() short-circuits at
	// the blank-formula guard and performs zero evaluations. Reported value reflects deployed
	// reality, not spec assumption. With formulas configured this would be ACTIONS_PER_RECORD_PER_CYCLE
	// × BATCH_SIZE = 1,600.
	Integer formulaEvalsApprox = 0;

	// recursionCheckOps: per dispatch, canExecuteAction calls inRecursion which walks ACTION_STACK.
	// Stack depth = 1 at check time (frame just pushed for the action under check), so each
	// dispatch performs 1 stack-walk comparison. Total = 8 actions × 200 records × 1 op.
	Integer recursionCheckOps = ACTIONS_PER_RECORD_PER_CYCLE * BATCH_SIZE;

	// PERF_ROW emission (one System.debug per metric — harvested by Task 2.6 perf-history harvester).
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 46, 'metric' => 'wallMs', 'value' => wallMs}));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 46, 'metric' => 'cpuMs', 'value' => cpuMs}));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 46, 'metric' => 'soqlCount', 'value' => soqlCount}));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 46, 'metric' => 'dmlCount', 'value' => dmlCount}));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 46, 'metric' => 'formulaEvalsApprox', 'value' => formulaEvalsApprox}));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 46, 'metric' => 'recursionCheckOps', 'value' => recursionCheckOps}));

	System.debug(LoggingLevel.INFO,
			'46 PASS: ' + BATCH_SIZE + ' Accounts × ' + ACTIONS_PER_RECORD_PER_CYCLE + ' chained TriggerActions = '
			+ (BATCH_SIZE * ACTIONS_PER_RECORD_PER_CYCLE) + ' dispatches. '
			+ 'Defaulted=' + defaultedDescriptionCount + ' StampedInsert=' + stampedSourceCount
			+ ' StampedUpdate=' + reStampedCount + ' Tasks=' + totalTaskCount + ' (expect ' + (BATCH_SIZE * 2) + '). '
			+ 'wall=' + wallMs + 'ms cpu=' + cpuMs + 'ms soql=' + soqlCount + ' dml=' + dmlCount
			+ ' formulaEvals=' + formulaEvalsApprox + ' recursionOps=' + recursionCheckOps);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '46 FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('46: ' + scenarioError.getMessage());
	fail++;
}

// Cleanup — delete all Accounts and their child Tasks created by this run.
// Account name range: NAME_TAG_INITIAL + '-N' on insert, then NAME_TAG_UPDATED + '-Id' after update.
// We delete by both tags (the second tag wins after a successful update, but if the test failed
// before the update step the first tag is still present).
kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();
try
{
	List<Account> residualAccounts =
	[
			SELECT Id
			FROM Account
			WHERE Name LIKE :(NAME_TAG_INITIAL + '%')
			OR Name LIKE :(NAME_TAG_UPDATED + '%')
			LIMIT 9000
	];
	if(!residualAccounts.isEmpty())
	{
		List<Task> residualTasks =
		[
				SELECT Id
				FROM Task
				WHERE WhatId IN :residualAccounts
				LIMIT 9000
		];
		if(!residualTasks.isEmpty())
		{
			delete residualTasks;
			System.debug(LoggingLevel.INFO, 'Cleanup: deleted ' + residualTasks.size() + ' Task row(s)');
		}
		delete residualAccounts;
		System.debug(LoggingLevel.INFO, 'Cleanup: deleted ' + residualAccounts.size() + ' Account row(s)');
	}
}
catch(Exception cleanupError)
{
	System.debug(LoggingLevel.WARN, '46 cleanup warning (Account/Task delete failed): ' + cleanupError.getMessage());
}

// Summary
System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 46: ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 46 FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 46 failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 46 COMPLETE: All scenarios passed ===');
}
