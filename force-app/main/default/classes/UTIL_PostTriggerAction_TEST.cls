// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for `UTIL_PostTriggerAction`. Covers the three gating filters
 * (feature flags, optional `TriggerSetting__c` scope, Apex entry-criteria evaluator),
 * the no-DML contract guard and its framework-log-persistence discount, the
 * `FailureAction__c` policy branches, the fatal-governor rethrow, and the recursion guard.
 *
 * @see UTIL_PostTriggerAction
 * @see PostTriggerAction__mdt
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date May 2026, August 2026
 */
@IsTest(SeeAllData=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class UTIL_PostTriggerAction_TEST
{
	private static final String FLAG_BYPASS = 'TestPostActionBypassFlag';
	private static final String FLAG_REQUIRED = 'TestPostActionRequiredFlag';
	/**
	 * @description Shared execution log used by the success mocks to record invocation
	 * order in a single list. Resides on the top-level test class because Apex forbids
	 * `static` members on inner classes.
	 */
	private static List<String> executionLogClassNames;
	private static final String ACTION_NAME_SUCCESS = UTIL_PostTriggerAction_TEST.MockPostAction_Success.class.getName();
	private static final String ACTION_NAME_SUCCESS_SECONDARY = UTIL_PostTriggerAction_TEST.MockPostAction_SuccessSecondary.class.getName();
	private static final String ACTION_NAME_DML = UTIL_PostTriggerAction_TEST.MockPostAction_Dml.class.getName();
	private static final String ACTION_NAME_DML_AND_ERROR_LOG = UTIL_PostTriggerAction_TEST.MockPostAction_DmlAndErrorLog.class.getName();
	private static final String ACTION_NAME_EMITS_ERROR_LOG = UTIL_PostTriggerAction_TEST.MockPostAction_EmitsErrorLog.class.getName();
	private static final String ACTION_NAME_EMITS_INFO_LOG = UTIL_PostTriggerAction_TEST.MockPostAction_EmitsInfoLog.class.getName();
	private static final String ACTION_NAME_THROWS = UTIL_PostTriggerAction_TEST.MockPostAction_Throws.class.getName();
	/**
	 * @description One below `LOG_Engine`'s private buffer cap (`MAX_BUFFER_SIZE` = 500), so a
	 * single buffered INFO emit from the post-action under test crosses the cap and triggers the
	 * synchronous auto-flush.
	 */
	private static final Integer LOG_BUFFER_COUNT_ONE_BELOW_CAP = 499;
	private static final String EVALUATOR_TRUE = UTIL_PostTriggerAction_TEST.MockEntryCriteria_True.class.getName();
	private static final String EVALUATOR_FALSE = UTIL_PostTriggerAction_TEST.MockEntryCriteria_False.class.getName();

	/**
	 * @description Confirms `run` short-circuits when the selector returns no rows —
	 * neither the recursion guard nor the action loop should execute.
	 */
	@IsTest
	private static void runDoesNothingWhenNoRowsConfigured()
	{
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt>();
		resetExecutionLog();

		Test.startTest();
		UTIL_PostTriggerAction.run(emptyContext());
		Test.stopTest();

		Assert.areEqual(0, totalExecutionCount(), 'No actions configured → no execute');
		Assert.isFalse(UTIL_PostTriggerAction.isRunning, 'Recursion guard should remain false on early return');
	}

	/**
	 * @description Confirms actions execute in `Order__c` ascending. The selector's
	 * override seam returns rows pre-sorted, so this test verifies the loop walks them
	 * top-to-bottom and the perf-timer / no-DML path completes for a no-op action.
	 */
	@IsTest
	private static void runExecutesActionsInOrder()
	{
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt>
		{
				buildRow('First', 10, ACTION_NAME_SUCCESS, SEL_TriggerAction.FAILURE_ACTION_LOG_AND_CONTINUE),
				buildRow('Second', 20, ACTION_NAME_SUCCESS_SECONDARY, SEL_TriggerAction.FAILURE_ACTION_LOG_AND_CONTINUE)
		};
		resetExecutionLog();

		Test.startTest();
		UTIL_PostTriggerAction.run(emptyContext());
		Test.stopTest();

		Assert.areEqual(new List<String> {'Success', 'SuccessSecondary'}, executionLogClassNames,
				'Actions should fire in selector-returned list order');
	}

	/**
	 * @description Re-entry into `run` while a prior `run` is mid-flight short-circuits
	 * without re-invoking the action loop. Simulates the recursion guard by setting
	 * `isRunning = true` ahead of the call.
	 */
	@IsTest
	private static void runReturnsEarlyWhenAlreadyRunning()
	{
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {buildSuccessRow('First', 10)};
		resetExecutionLog();
		UTIL_PostTriggerAction.isRunning = true;

		Test.startTest();
		UTIL_PostTriggerAction.run(emptyContext());
		Test.stopTest();

		Assert.areEqual(0, totalExecutionCount(), 'Re-entry should skip the loop entirely');
		UTIL_PostTriggerAction.isRunning = false;
	}

	/**
	 * @description A row whose `BypassFeatureFlag__c` is an enabled flag is skipped.
	 */
	@IsTest
	private static void runSkipsRowWhenBypassFlagIsEnabled()
	{
		registerActiveFeatureFlag(FLAG_BYPASS);
		PostTriggerAction__mdt row = (PostTriggerAction__mdt)TST_Builder.of(PostTriggerAction__mdt.SObjectType)
				.withOverride(PostTriggerAction__mdt.DeveloperName, 'BypassFlagOn')
				.withOverride(PostTriggerAction__mdt.ApexClassName__c, ACTION_NAME_SUCCESS)
				.withOverride(PostTriggerAction__mdt.Order__c, 10)
				.withOverride(PostTriggerAction__mdt.BypassFeatureFlag__c, buildFlagRecord(FLAG_BYPASS))
				.withoutInsertion()
				.build();
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {row};
		resetExecutionLog();

		Test.startTest();
		UTIL_PostTriggerAction.run(emptyContext());
		Test.stopTest();

		Assert.areEqual(0, totalExecutionCount(), 'Bypass flag enabled → action skipped');
	}

	/**
	 * @description A row with `RequiredFeatureFlag__c` set to a flag that is NOT
	 * registered as active is skipped.
	 */
	@IsTest
	private static void runSkipsRowWhenRequiredFlagIsNotEnabled()
	{
		FeatureFlag__mdt requiredFlag = buildFlagRecord(FLAG_REQUIRED);
		PostTriggerAction__mdt row = (PostTriggerAction__mdt)TST_Builder.of(PostTriggerAction__mdt.SObjectType)
				.withOverride(PostTriggerAction__mdt.DeveloperName, 'RequiredFlagOff')
				.withOverride(PostTriggerAction__mdt.ApexClassName__c, ACTION_NAME_SUCCESS)
				.withOverride(PostTriggerAction__mdt.Order__c, 10)
				.withOverride(PostTriggerAction__mdt.RequiredFeatureFlag__c, requiredFlag)
				.withoutInsertion()
				.build();
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {row};
		resetExecutionLog();

		Test.startTest();
		UTIL_PostTriggerAction.run(emptyContext());
		Test.stopTest();

		Assert.areEqual(0, totalExecutionCount(), 'Required flag not enabled → action skipped');
	}

	/**
	 * @description A row with `RequiredFeatureFlag__c` set to an enabled flag executes.
	 */
	@IsTest
	private static void runExecutesRowWhenRequiredFlagIsEnabled()
	{
		FeatureFlag__mdt requiredFlag = registerActiveFeatureFlag(FLAG_REQUIRED);
		PostTriggerAction__mdt row = (PostTriggerAction__mdt)TST_Builder.of(PostTriggerAction__mdt.SObjectType)
				.withOverride(PostTriggerAction__mdt.DeveloperName, 'RequiredFlagOn')
				.withOverride(PostTriggerAction__mdt.ApexClassName__c, ACTION_NAME_SUCCESS)
				.withOverride(PostTriggerAction__mdt.Order__c, 10)
				.withOverride(PostTriggerAction__mdt.RequiredFeatureFlag__c, requiredFlag)
				.withoutInsertion()
				.build();
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {row};
		resetExecutionLog();

		Test.startTest();
		UTIL_PostTriggerAction.run(emptyContext());
		Test.stopTest();

		Assert.areEqual(1, totalExecutionCount(), 'Required flag enabled → action fires');
	}

	/**
	 * @description Optional-lookup smart-semantics: `TriggerSetting__c` set, parent
	 * `SObjectType__c` IS in `touchedSObjectTypes` → action fires.
	 */
	@IsTest
	private static void runFiresWhenSettingScopeSObjectIsTouched()
	{
		TriggerSetting__mdt setting = (TriggerSetting__mdt)TST_Builder.of(TriggerSetting__mdt.SObjectType)
				.withOverride(TriggerSetting__mdt.DeveloperName, 'AccountSetting')
				.withOverride(TriggerSetting__mdt.SObjectType__c, 'Account')
				.withoutInsertion(true)
				.build();
		PostTriggerAction__mdt row = (PostTriggerAction__mdt)TST_Builder.of(PostTriggerAction__mdt.SObjectType)
				.withOverride(PostTriggerAction__mdt.DeveloperName, 'AccountScoped')
				.withOverride(PostTriggerAction__mdt.ApexClassName__c, ACTION_NAME_SUCCESS)
				.withOverride(PostTriggerAction__mdt.Order__c, 10)
				.withOverride(PostTriggerAction__mdt.TriggerSetting__c, setting)
				.withoutInsertion()
				.build();
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {row};
		resetExecutionLog();

		Test.startTest();
		UTIL_PostTriggerAction.run(contextWith(new Set<SObjectType> {Account.SObjectType}));
		Test.stopTest();

		Assert.areEqual(1, totalExecutionCount(), 'Parent SObject touched → action fires');
	}

	/**
	 * @description Optional-lookup smart-semantics: `TriggerSetting__c` set, parent
	 * `SObjectType__c` is NOT in `touchedSObjectTypes` → action skipped.
	 */
	@IsTest
	private static void runSkipsWhenSettingScopeSObjectNotTouched()
	{
		TriggerSetting__mdt setting = (TriggerSetting__mdt)TST_Builder.of(TriggerSetting__mdt.SObjectType)
				.withOverride(TriggerSetting__mdt.DeveloperName, 'ContactSetting')
				.withOverride(TriggerSetting__mdt.SObjectType__c, 'Contact')
				.withoutInsertion(true)
				.build();
		PostTriggerAction__mdt row = (PostTriggerAction__mdt)TST_Builder.of(PostTriggerAction__mdt.SObjectType)
				.withOverride(PostTriggerAction__mdt.DeveloperName, 'ContactScoped')
				.withOverride(PostTriggerAction__mdt.ApexClassName__c, ACTION_NAME_SUCCESS)
				.withOverride(PostTriggerAction__mdt.Order__c, 10)
				.withOverride(PostTriggerAction__mdt.TriggerSetting__c, setting)
				.withoutInsertion()
				.build();
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {row};
		resetExecutionLog();

		Test.startTest();
		UTIL_PostTriggerAction.run(contextWith(new Set<SObjectType> {Account.SObjectType}));
		Test.stopTest();

		Assert.areEqual(0, totalExecutionCount(), 'Parent SObject not touched → action skipped');
	}

	/**
	 * @description Mis-configured lookup: `TriggerSetting__c` set but the parent
	 * setting's `SObjectType__c` is blank → action skipped fail-soft.
	 */
	@IsTest
	private static void runSkipsWhenSettingScopeSObjectIsBlank()
	{
		TriggerSetting__mdt setting = (TriggerSetting__mdt)TST_Builder.of(TriggerSetting__mdt.SObjectType)
				.withOverride(TriggerSetting__mdt.DeveloperName, 'BlankSetting')
				.withoutInsertion(true)
				.build();
		PostTriggerAction__mdt row = (PostTriggerAction__mdt)TST_Builder.of(PostTriggerAction__mdt.SObjectType)
				.withOverride(PostTriggerAction__mdt.DeveloperName, 'BlankParent')
				.withOverride(PostTriggerAction__mdt.ApexClassName__c, ACTION_NAME_SUCCESS)
				.withOverride(PostTriggerAction__mdt.Order__c, 10)
				.withOverride(PostTriggerAction__mdt.TriggerSetting__c, setting)
				.withoutInsertion()
				.build();
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {row};
		resetExecutionLog();

		Test.startTest();
		UTIL_PostTriggerAction.run(contextWith(new Set<SObjectType> {Account.SObjectType}));
		Test.stopTest();

		Assert.areEqual(0, totalExecutionCount(), 'Blank parent SObjectType → action skipped');
	}

	/**
	 * @description Mis-configured lookup: `TriggerSetting__c` set, parent
	 * `SObjectType__c` is a name that does not resolve via `UTIL_SObjectDescribe` →
	 * action skipped fail-soft.
	 */
	@IsTest
	private static void runSkipsWhenSettingScopeSObjectDoesNotResolve()
	{
		TriggerSetting__mdt setting = (TriggerSetting__mdt)TST_Builder.of(TriggerSetting__mdt.SObjectType)
				.withOverride(TriggerSetting__mdt.DeveloperName, 'PhantomSetting')
				.withOverride(TriggerSetting__mdt.SObjectType__c, 'NoSuchObject__c')
				.withoutInsertion(true)
				.build();
		PostTriggerAction__mdt row = (PostTriggerAction__mdt)TST_Builder.of(PostTriggerAction__mdt.SObjectType)
				.withOverride(PostTriggerAction__mdt.DeveloperName, 'PhantomParent')
				.withOverride(PostTriggerAction__mdt.ApexClassName__c, ACTION_NAME_SUCCESS)
				.withOverride(PostTriggerAction__mdt.Order__c, 10)
				.withOverride(PostTriggerAction__mdt.TriggerSetting__c, setting)
				.withoutInsertion()
				.build();
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {row};
		resetExecutionLog();

		Test.startTest();
		UTIL_PostTriggerAction.run(contextWith(new Set<SObjectType> {Account.SObjectType}));
		Test.stopTest();

		Assert.areEqual(0, totalExecutionCount(), 'Unresolvable parent SObjectType → action skipped');
	}

	/**
	 * @description Entry-criteria evaluator returns `false` → action skipped.
	 */
	@IsTest
	private static void runSkipsWhenEntryCriteriaReturnsFalse()
	{
		PostTriggerAction__mdt row = (PostTriggerAction__mdt)TST_Builder.of(PostTriggerAction__mdt.SObjectType)
				.withOverride(PostTriggerAction__mdt.DeveloperName, 'GatedFalse')
				.withOverride(PostTriggerAction__mdt.ApexClassName__c, ACTION_NAME_SUCCESS)
				.withOverride(PostTriggerAction__mdt.Order__c, 10)
				.withOverride(PostTriggerAction__mdt.EntryCriteriaContextClassName__c, EVALUATOR_FALSE)
				.withoutInsertion()
				.build();
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {row};
		resetExecutionLog();

		Test.startTest();
		UTIL_PostTriggerAction.run(emptyContext());
		Test.stopTest();

		Assert.areEqual(0, totalExecutionCount(), 'Evaluator false → action skipped');
	}

	/**
	 * @description Entry-criteria evaluator returns `true` → action fires.
	 */
	@IsTest
	private static void runFiresWhenEntryCriteriaReturnsTrue()
	{
		PostTriggerAction__mdt row = (PostTriggerAction__mdt)TST_Builder.of(PostTriggerAction__mdt.SObjectType)
				.withOverride(PostTriggerAction__mdt.DeveloperName, 'GatedTrue')
				.withOverride(PostTriggerAction__mdt.ApexClassName__c, ACTION_NAME_SUCCESS)
				.withOverride(PostTriggerAction__mdt.Order__c, 10)
				.withOverride(PostTriggerAction__mdt.EntryCriteriaContextClassName__c, EVALUATOR_TRUE)
				.withoutInsertion()
				.build();
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {row};
		resetExecutionLog();

		Test.startTest();
		UTIL_PostTriggerAction.run(emptyContext());
		Test.stopTest();

		Assert.areEqual(1, totalExecutionCount(), 'Evaluator true → action fires');
	}

	/**
	 * @description Entry-criteria misconfiguration where the named class exists but does NOT
	 * implement `IF_Trigger.PostActionEntryCriteria`: the wrong-interface cast raises
	 * `TypeException`, which must propagate out of `run` rather than route through the
	 * `FailureAction__c` policy. Locks the contract that a deploy-time misconfiguration surfaces
	 * instead of being silently swallowed as a `LogAndContinue`. Uses a `PostAction` mock as the
	 * (wrong) evaluator binding.
	 */
	@IsTest
	private static void runPropagatesWhenEntryCriteriaClassDoesNotImplementInterface()
	{
		PostTriggerAction__mdt row = (PostTriggerAction__mdt)TST_Builder.of(PostTriggerAction__mdt.SObjectType)
				.withOverride(PostTriggerAction__mdt.DeveloperName, 'WrongEvaluatorInterface')
				.withOverride(PostTriggerAction__mdt.ApexClassName__c, ACTION_NAME_SUCCESS)
				.withOverride(PostTriggerAction__mdt.Order__c, 10)
				.withOverride(PostTriggerAction__mdt.EntryCriteriaContextClassName__c, ACTION_NAME_SUCCESS)
				.withoutInsertion()
				.build();
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {row};
		resetExecutionLog();

		Exception caught = runCapturingException();

		Assert.isNotNull(caught, 'A wrong-interface entry-criteria binding must surface, not route through FailureAction');
		Assert.isInstanceOfType(caught, TypeException.class, 'Wrong-interface entry-criteria binding should propagate as TypeException');
		Assert.areEqual(0, totalExecutionCount(), 'The post-action must not run when its entry-criteria binding is invalid');
		Assert.isFalse(UTIL_PostTriggerAction.isRunning, 'Recursion guard must reset even when run throws');
	}

	/**
	 * @description Entry-criteria misconfiguration where the named class cannot be resolved at
	 * all: the unresolvable class name must surface out of `run` rather than route through the
	 * `FailureAction__c` policy. Locks the surfaced-not-swallowed contract for the unresolvable
	 * branch (the exact runtime type is left to the platform; the contract is that it propagates).
	 */
	@IsTest
	private static void runPropagatesWhenEntryCriteriaClassIsUnresolvable()
	{
		PostTriggerAction__mdt row = (PostTriggerAction__mdt)TST_Builder.of(PostTriggerAction__mdt.SObjectType)
				.withOverride(PostTriggerAction__mdt.DeveloperName, 'UnresolvableEvaluator')
				.withOverride(PostTriggerAction__mdt.ApexClassName__c, ACTION_NAME_SUCCESS)
				.withOverride(PostTriggerAction__mdt.Order__c, 10)
				.withOverride(PostTriggerAction__mdt.EntryCriteriaContextClassName__c, 'NoSuchEntryCriteriaClass')
				.withoutInsertion()
				.build();
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {row};
		resetExecutionLog();

		Exception caught = runCapturingException();

		Assert.isNotNull(caught, 'An unresolvable entry-criteria class name must surface, not route through FailureAction');
		Assert.areEqual(0, totalExecutionCount(), 'The post-action must not run when its entry-criteria class cannot be resolved');
		Assert.isFalse(UTIL_PostTriggerAction.isRunning, 'Recursion guard must reset even when run throws');
	}

	/**
	 * @description An action that performs synchronous DML inside `execute(context)`
	 * raises `PostActionDmlException` — the no-DML contract guard fires regardless of
	 * `FailureAction__c` policy.
	 */
	@IsTest
	private static void runRaisesDmlExceptionWhenActionPerformsDml()
	{
		PostTriggerAction__mdt row = buildRow('DmlRow', 10, ACTION_NAME_DML, SEL_TriggerAction.FAILURE_ACTION_LOG_AND_CONTINUE);
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {row};

		Exception caught = runCapturingException();

		Assert.isNotNull(caught, 'DML in post-action should throw');
		Assert.isInstanceOfType
				(
						caught, UTIL_Exceptions.PostActionDmlException.class,
						'Should throw the framework no-DML exception even when FailureAction is LogAndContinue'
				);
		Assert.isTrue(caught.getMessage().contains('synchronous DML'), 'Message should specify synchronous DML');
		Assert.isTrue(caught.getMessage().contains(ACTION_NAME_DML), 'Message should name the offending action');
	}

	/**
	 * @description A post-action that emits an ERROR-level log inside a platform-event /
	 * change-event trigger dispatch persists that log synchronously via the engine's
	 * direct-DML path (`TRG_PersistLogEntry.persist` — publishing would make the platform
	 * redeliver the source event). That framework-owned DML must NOT trip the no-DML
	 * contract guard: the guard discounts the engine's own log persistence and blames the
	 * post-action only for DML it performed itself. The delta assertion pins that the
	 * persistence still happened synchronously inside the dispatch window — the discount
	 * must not change log delivery timing.
	 */
	@IsTest
	private static void runDoesNotRaiseDmlExceptionWhenActionEmitsErrorLogInEventTriggerContext()
	{
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt>
		{
				buildRow('ErrorLogEmit', 10, ACTION_NAME_EMITS_ERROR_LOG, SEL_TriggerAction.FAILURE_ACTION_LOG_AND_CONTINUE)
		};
		LOG_Engine.beginEventTriggerContext(new List<SObject> {new LogEntryEvent__e()});
		Integer dmlStatementsBeforeRun = Limits.getDmlStatements();

		EventTriggerContextRunOutcome outcome = runInsideEventTriggerContextCapturingOutcome();

		Assert.isNull(outcome.caught, 'Framework log persistence must not trip the post-action no-DML guard; caught: ' + outcome.caught);
		Assert.isTrue(outcome.dmlStatementsAfterRun > dmlStatementsBeforeRun,
				'The ERROR log must still persist synchronously via direct DML inside the dispatch window, sampled before teardown so a deferred flush cannot satisfy it');
	}

	/**
	 * @description A post-action whose INFO-level emit crosses the engine's buffer cap inside an
	 * event-trigger dispatch triggers the synchronous auto-flush, which persists the whole buffer
	 * via direct DML (measured in-org 2026-08-10: 20 DML statements / 500 rows for a full buffer).
	 * That framework-owned DML must NOT trip the no-DML contract guard — this is the shipped
	 * `IF_Trigger.PostAction` `@example` shape, which would otherwise fail intermittently
	 * depending on how full the buffer happens to be. The buffer is pre-filled to one below the
	 * cap so the mock's single emit is the crossing one.
	 */
	@IsTest
	private static void runDoesNotRaiseDmlExceptionWhenActionInfoLogCrossesBufferCapInEventTriggerContext()
	{
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt>
		{
				buildRow('InfoLogBufferCrossing', 10, ACTION_NAME_EMITS_INFO_LOG, SEL_TriggerAction.FAILURE_ACTION_LOG_AND_CONTINUE)
		};
		LOG_Engine.beginEventTriggerContext(new List<SObject> {new LogEntryEvent__e()});
		for(Integer i = 0; i < LOG_BUFFER_COUNT_ONE_BELOW_CAP; i++)
		{
			LOG_Engine.logBuffer.add((LogEntryEvent__e)TST_Builder.of(LogEntryEvent__e.SObjectType)
					.withOverride(LogEntryEvent__e.Message__c, 'buffer filler ' + i)
					.withOverride(LogEntryEvent__e.LogLevel__c, LoggingLevel.INFO.name())
					.withoutInsertion()
					.build());
		}
		Integer dmlStatementsBeforeRun = Limits.getDmlStatements();

		EventTriggerContextRunOutcome outcome = runInsideEventTriggerContextCapturingOutcome();

		Assert.isNull(outcome.caught, 'A buffer-cap-crossing flush is framework-owned DML and must not trip the guard; caught: ' + outcome.caught);
		Assert.isTrue(outcome.dmlStatementsAfterRun > dmlStatementsBeforeRun,
				'Crossing the buffer cap must still flush synchronously via direct DML inside the dispatch window, sampled before teardown so a deferred flush cannot satisfy it');
	}

	/**
	 * @description A post-action that performs its OWN synchronous DML still trips the
	 * no-DML contract guard even when it also emits an ERROR-level log inside the same
	 * event-trigger dispatch. Pins the boundary of the framework-log discount: only the
	 * engine's own persistence DML is excluded from the measured delta, never the
	 * post-action's.
	 */
	@IsTest
	private static void runRaisesDmlExceptionWhenActionPerformsOwnDmlBesideErrorLogInEventTriggerContext()
	{
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt>
		{
				buildRow('OwnDmlBesideLog', 10, ACTION_NAME_DML_AND_ERROR_LOG, SEL_TriggerAction.FAILURE_ACTION_LOG_AND_CONTINUE)
		};
		LOG_Engine.beginEventTriggerContext(new List<SObject> {new LogEntryEvent__e()});

		EventTriggerContextRunOutcome outcome = runInsideEventTriggerContextCapturingOutcome();

		Assert.isNotNull(outcome.caught, 'A post-action performing its own DML must still trip the guard even when it also logs');
		Assert.isInstanceOfType(outcome.caught, UTIL_Exceptions.PostActionDmlException.class,
				'The framework-log discount must never absorb the post-action\'s own DML');
	}

	/**
	 * @description An action throwing a non-fatal, non-DML runtime exception with
	 * `FailureAction__c = LogAndContinue` is logged and swallowed — `run` returns
	 * normally without rethrowing.
	 */
	@IsTest
	private static void runSwallowsRuntimeExceptionUnderLogAndContinue()
	{
		PostTriggerAction__mdt row = buildRow('LogAndContinueRow', 10, ACTION_NAME_THROWS, SEL_TriggerAction.FAILURE_ACTION_LOG_AND_CONTINUE);
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {row};

		Exception caught = runCapturingException();

		Assert.isNull(caught, 'LogAndContinue should swallow the action exception');
	}

	/**
	 * @description An action throwing a non-fatal, non-DML runtime exception with
	 * `FailureAction__c = BlockDml` is logged and rethrown so the originating DML rolls back.
	 */
	@IsTest
	private static void runRethrowsRuntimeExceptionUnderBlockDml()
	{
		PostTriggerAction__mdt row = buildRow('BlockDmlRow', 10, ACTION_NAME_THROWS, SEL_TriggerAction.FAILURE_ACTION_BLOCK_DML);
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {row};

		Exception caught = runCapturingException();

		Assert.isNotNull(caught, 'BlockDml policy should rethrow the action exception');
		Assert.isInstanceOfType(caught, MockActionException.class, 'Rethrown exception should be the action exception type');
	}

	/**
	 * @description When a row's `FailureAction__c` is blank, the handler defaults to
	 * `LogAndContinue` semantics (swallow non-fatal exceptions). Exercises the
	 * default-branch in `handleFailure`.
	 */
	@IsTest
	private static void runDefaultsToLogAndContinueWhenFailureActionBlank()
	{
		PostTriggerAction__mdt row = buildRow('DefaultPolicy', 10, ACTION_NAME_THROWS, null);
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {row};

		Exception caught = runCapturingException();

		Assert.isNull(caught, 'Blank FailureAction should behave as LogAndContinue');
	}

	/**
	 * @description Fatal governor exceptions always rethrow regardless of
	 * `FailureAction__c` policy. Drives the rethrow branch via the
	 * `UTIL_Exceptions.simulateFatalGovernorErrorForTest` toggle.
	 */
	@IsTest
	private static void runAlwaysRethrowsFatalGovernorException()
	{
		PostTriggerAction__mdt row = buildRow('FatalRow', 10, ACTION_NAME_THROWS, SEL_TriggerAction.FAILURE_ACTION_LOG_AND_CONTINUE);
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt> {row};
		UTIL_Exceptions.simulateFatalGovernorErrorForTest = true;

		Exception caught;
		try
		{
			caught = runCapturingException();
		}
		finally
		{
			UTIL_Exceptions.simulateFatalGovernorErrorForTest = false;
		}

		Assert.isNotNull(caught, 'Fatal-governor should rethrow even when policy is LogAndContinue');
		Assert.isInstanceOfType(caught, MockActionException.class, 'Rethrown exception should be the original action exception');
	}

	/**
	 * @description Runs `UTIL_PostTriggerAction.run` against an empty context inside a
	 * `Test.startTest()`/`Test.stopTest()` window and returns any exception it raised, or
	 * null when `run` returned normally. Lets the failure-policy tests assert on the
	 * captured exception without each repeating the same start/stop/try/catch scaffold.
	 *
	 * @return The exception thrown by `run`, or null if none was thrown
	 */
	private static Exception runCapturingException()
	{
		try
		{
			Test.startTest();
			UTIL_PostTriggerAction.run(emptyContext());
			Test.stopTest();
			return null;
		}
		catch(Exception caughtException)
		{
			return caughtException;
		}
	}

	/**
	 * @description Carries what a post-action dispatch inside an owned event-trigger context
	 * produced: the exception `run` raised (null when it returned normally) and the
	 * DML-statement count sampled inside the dispatch window, before the context teardown
	 * (null when `run` threw before the sample).
	 */
	private class EventTriggerContextRunOutcome
	{
		private Exception caught;
		private Integer dmlStatementsAfterRun;
	}

	/**
	 * @description Runs `UTIL_PostTriggerAction.run` against an empty context inside an
	 * already-begun event-trigger context, samples `Limits.getDmlStatements()` BEFORE the
	 * `finally` tears the context down (so a flush deferred to teardown cannot satisfy a
	 * delivery-timing assertion), and always ends the context. Lets the framework-log-discount
	 * tests share one scaffold instead of repeating the try/catch/finally block.
	 *
	 * @return The outcome carrying the captured exception and the in-window DML sample
	 */
	private static EventTriggerContextRunOutcome runInsideEventTriggerContextCapturingOutcome()
	{
		EventTriggerContextRunOutcome outcome = new EventTriggerContextRunOutcome();
		try
		{
			UTIL_PostTriggerAction.run(emptyContext());
			outcome.dmlStatementsAfterRun = Limits.getDmlStatements();
		}
		catch(Exception caughtException)
		{
			outcome.caught = caughtException;
		}
		finally
		{
			LOG_Engine.endEventTriggerContext();
		}
		return outcome;
	}

	/**
	 * @description Builds a baseline PostTriggerAction__mdt row with the given identity,
	 * order, Apex binding, and failure-action policy.
	 *
	 * @param developerName The CMDT DeveloperName
	 * @param orderValue The Order__c value
	 * @param apexClassName The ApexClassName__c value
	 * @param failureAction The FailureAction__c value (nullable to exercise the blank-default branch)
	 *
	 * @return An uninserted PostTriggerAction__mdt
	 */
	private static PostTriggerAction__mdt buildRow(String developerName, Decimal orderValue, String apexClassName, String failureAction)
	{
		TST_Builder.Builder builder = TST_Builder.of(PostTriggerAction__mdt.SObjectType)
				.withOverride(PostTriggerAction__mdt.DeveloperName, developerName)
				.withOverride(PostTriggerAction__mdt.ApexClassName__c, apexClassName)
				.withOverride(PostTriggerAction__mdt.Order__c, orderValue);
		if(failureAction != null)
		{
			builder.withOverride(PostTriggerAction__mdt.FailureAction__c, failureAction);
		}
		return (PostTriggerAction__mdt)builder.withoutInsertion().build();
	}

	/**
	 * @description Shortcut for `buildRow` with the default `MockPostAction_Success`
	 * action class and `LogAndContinue` failure-action.
	 *
	 * @param developerName The CMDT DeveloperName
	 * @param orderValue The Order__c value
	 *
	 * @return An uninserted PostTriggerAction__mdt
	 */
	private static PostTriggerAction__mdt buildSuccessRow(String developerName, Decimal orderValue)
	{
		return buildRow(developerName, orderValue, ACTION_NAME_SUCCESS, SEL_TriggerAction.FAILURE_ACTION_LOG_AND_CONTINUE);
	}

	/**
	 * @description Builds an in-memory `FeatureFlag__mdt` for populating a relationship
	 * field without registering the flag as active. Mirrors
	 * `TST_Factory.newFeatureFlag(name, false)` but uses TST_Builder directly so the test
	 * stays self-contained.
	 *
	 * @param flagName The flag DeveloperName
	 *
	 * @return An uninserted FeatureFlag__mdt
	 */
	private static FeatureFlag__mdt buildFlagRecord(String flagName)
	{
		return (FeatureFlag__mdt)TST_Builder.of(FeatureFlag__mdt.SObjectType)
				.withOverride(FeatureFlag__mdt.DeveloperName, flagName)
				.withOverride(FeatureFlag__mdt.IsActive__c, true)
				.withOverride(FeatureFlag__mdt.IsEnabledByDefault__c, true)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Builds a flag record AND registers it in `SEL_FeatureFlag.activeFlags`
	 * so `UTIL_FeatureFlag.isEnabled(flagName)` returns true within the test.
	 *
	 * @param flagName The flag DeveloperName
	 *
	 * @return The registered FeatureFlag__mdt
	 */
	private static FeatureFlag__mdt registerActiveFeatureFlag(String flagName)
	{
		FeatureFlag__mdt flag = buildFlagRecord(flagName);
		SEL_FeatureFlag.allDeveloperNames = new Set<String> {flagName};
		SEL_FeatureFlag.activeFlags = new Map<String, FeatureFlag__mdt> {flagName => flag};
		return flag;
	}

	/**
	 * @description Resets the shared execution log between test methods.
	 */
	private static void resetExecutionLog()
	{
		executionLogClassNames = new List<String>();
	}

	/**
	 * @description Appends a class-name marker to the shared execution log. Called from
	 * each success mock's `execute(...)` so order and call counts can be asserted.
	 *
	 * @param className The marker to record (e.g. 'Success', 'SuccessSecondary')
	 */
	private static void recordExecution(String className)
	{
		if(executionLogClassNames == null)
		{
			resetExecutionLog();
		}
		executionLogClassNames.add(className);
	}

	/**
	 * @description Returns the total number of executions recorded in the shared log.
	 *
	 * @return The execution count, or 0 if the log has not been populated
	 */
	private static Integer totalExecutionCount()
	{
		return executionLogClassNames == null ? 0 : executionLogClassNames.size();
	}

	/**
	 * @description Constructs an empty post-action context — no SObject types touched.
	 *
	 * @return A PostActionContext with an empty touched-types set
	 */
	private static IF_Trigger.PostActionContext emptyContext()
	{
		return new IF_Trigger.PostActionContext(new Set<SObjectType>());
	}

	/**
	 * @description Constructs a post-action context with the supplied touched-types set.
	 *
	 * @param touched The set of SObject types to populate
	 *
	 * @return A PostActionContext with the given touched-types set
	 */
	private static IF_Trigger.PostActionContext contextWith(Set<SObjectType> touched)
	{
		return new IF_Trigger.PostActionContext(touched);
	}

	/**
	 * @description Mock `PostAction` that records its invocation in the shared
	 * execution log so ordering and call-count assertions can distinguish invocations
	 * across mocks.
	 */
	public class MockPostAction_Success implements IF_Trigger.PostAction
	{
		public void execute(IF_Trigger.PostActionContext context)
		{
			recordExecution('Success');
		}
	}

	/**
	 * @description Second mock `PostAction` — used in the ordering test alongside
	 * `MockPostAction_Success` so the assertion can distinguish two invocations by
	 * the class name recorded into the shared log.
	 */
	public class MockPostAction_SuccessSecondary implements IF_Trigger.PostAction
	{
		public void execute(IF_Trigger.PostActionContext context)
		{
			recordExecution('SuccessSecondary');
		}
	}

	/**
	 * @description Mock `PostAction` that performs synchronous DML — used to drive the
	 * no-DML contract guard and assert `PostActionDmlException` always throws.
	 */
	public class MockPostAction_Dml implements IF_Trigger.PostAction
	{
		public void execute(IF_Trigger.PostActionContext context)
		{
			// Issue a DML statement through the framework DML layer for the no-DML guard to detect.
			// allowPartial() makes the insert all-or-none = false, so a row-level failure — a subscriber
			// validation rule, FLS, org storage — returns a failed result instead of throwing out of
			// execute() before the guard's Limits.getDmlStatements() check runs. The statement still
			// counts, so the guard surfaces PostActionDmlException as designed. A managed-package test
			// cannot assume a subscriber org will accept a standard-object insert.
			DML_Builder.newTransaction()
					.doInsert
							(
									TST_Builder.of(Account.SObjectType)
											.withOverride(Account.Name, 'PostActionDmlAccount')
											.withoutInsertion()
											.build()
							)
					.allowPartial()
					.suppressLogging()
					.execute();
		}
	}

	/**
	 * @description Mock `PostAction` that emits an ERROR-level log through the real
	 * `LOG_Builder` path — inside an event-trigger context that emit persists via direct
	 * DML, which the no-DML guard must discount as framework-owned.
	 */
	public class MockPostAction_EmitsErrorLog implements IF_Trigger.PostAction
	{
		/**
		 * @description Emits the ERROR-level probe log when the dispatcher invokes this action.
		 *
		 * @param context The post-action context supplied by the dispatcher
		 */
		public void execute(IF_Trigger.PostActionContext context)
		{
			LOG_Builder.build().error('Post-action framework-log persistence probe').emitAt(ACTION_NAME_EMITS_ERROR_LOG);
		}
	}

	/**
	 * @description Mock `PostAction` that emits a single INFO-level log through the real
	 * `LOG_Builder` path — mirrors the shipped `IF_Trigger.PostAction` `@example`. Used with a
	 * pre-filled buffer so the emit crosses the engine's buffer cap and triggers the synchronous
	 * auto-flush inside the dispatch window.
	 */
	public class MockPostAction_EmitsInfoLog implements IF_Trigger.PostAction
	{
		/**
		 * @description Emits the single INFO-level log that crosses the pre-filled buffer cap.
		 *
		 * @param context The post-action context supplied by the dispatcher
		 */
		public void execute(IF_Trigger.PostActionContext context)
		{
			LOG_Builder.build().info('Transaction touched ' + context.touchedSObjectTypes.size() + ' SObject(s)').emitAt(ACTION_NAME_EMITS_INFO_LOG);
		}
	}

	/**
	 * @description Mock `PostAction` that performs its own synchronous DML AND emits an
	 * ERROR-level log — used to pin that the framework-log discount never absorbs the
	 * post-action's own DML. The DML shape mirrors `MockPostAction_Dml` (partial-allowed,
	 * logging-suppressed) so a subscriber-org row failure cannot escape before the guard runs.
	 */
	public class MockPostAction_DmlAndErrorLog implements IF_Trigger.PostAction
	{
		/**
		 * @description Performs the action's own insert, then emits the ERROR-level probe log.
		 *
		 * @param context The post-action context supplied by the dispatcher
		 */
		public void execute(IF_Trigger.PostActionContext context)
		{
			DML_Builder.newTransaction()
					.doInsert
							(
									TST_Builder.of(Account.SObjectType)
											.withOverride(Account.Name, 'PostActionDmlBesideLogAccount')
											.withoutInsertion()
											.build()
							)
					.allowPartial()
					.suppressLogging()
					.execute();
			LOG_Builder.build().error('Post-action own-DML-beside-log probe').emitAt(ACTION_NAME_DML_AND_ERROR_LOG);
		}
	}

	/**
	 * @description Mock `PostAction` that throws a non-DML, non-fatal runtime exception —
	 * used to drive the `FailureAction__c` policy branches.
	 */
	public class MockPostAction_Throws implements IF_Trigger.PostAction
	{
		public void execute(IF_Trigger.PostActionContext context)
		{
			throw new MockActionException('Mock action runtime failure');
		}
	}

	/**
	 * @description Mock `PostActionEntryCriteria` that returns `true`.
	 */
	public class MockEntryCriteria_True implements IF_Trigger.PostActionEntryCriteria
	{
		public Boolean shouldRun(IF_Trigger.PostActionContext context)
		{
			return true;
		}
	}

	/**
	 * @description Mock `PostActionEntryCriteria` that returns `false`.
	 */
	public class MockEntryCriteria_False implements IF_Trigger.PostActionEntryCriteria
	{
		public Boolean shouldRun(IF_Trigger.PostActionContext context)
		{
			return false;
		}
	}

	/**
	 * @description Custom exception thrown by `MockPostAction_Throws` so assertions can
	 * identify the rethrown type distinctly from framework exceptions.
	 */
	public class MockActionException extends Exception
	{
	}
}