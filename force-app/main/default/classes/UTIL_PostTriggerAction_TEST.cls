// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for `UTIL_PostTriggerAction`. Covers the three gating filters
 * (feature flags, optional `TriggerSetting__c` scope, Apex entry-criteria evaluator),
 * the no-DML contract guard, the `FailureAction__c` policy branches, the fatal-governor
 * rethrow, and the recursion guard.
 *
 * @see UTIL_PostTriggerAction
 * @see PostTriggerAction__mdt
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date May 2026, June 2026
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
	private static final String ACTION_NAME_THROWS = UTIL_PostTriggerAction_TEST.MockPostAction_Throws.class.getName();
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