// SPDX-License-Identifier: Apache-2.0
/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @description Test class for Trigger actions
 * adapted from: [apex-trigger-actions-framework](https://github.com/mitchspano/apex-trigger-actions-framework/blob/master/README.md#metadata-driven-trigger-actions)
 *
 * @see TRG_Dispatcher
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class TRG_Dispatcher_TEST
{
	/**
	 * @description A class name that does not exist. The tests configure it as a trigger action to prove the
	 * dispatcher refuses an action whose class it cannot find.
	 */
	private static final String BOGUS_CLASS_NAME = 'Bogus';
	/**
	 * @description The Name given to DEFAULT_RECORD, the record most tests hand to the dispatcher.
	 */
	private static final String DEFAULT_RECORD_NAME = 'My Record';
	/**
	 * @description Failure message shown when a dispatcher run that must throw finishes without an exception.
	 */
	private static final String MSG_EXCEPTION_EXPECTED = 'Expected an exception to be thrown';
	/**
	 * @description Full name of the inner class TestAfterDelete, set as the action class when a test needs an
	 * action that answers the after delete step.
	 */
	private static final String TEST_AFTER_DELETE = TRG_Dispatcher_TEST.class.getName() + '.TestAfterDelete';
	/**
	 * @description Full name of the inner class TestAfterInsert, set as the action class when a test needs an
	 * action that answers the after insert step. It is also configured for the before insert step, which it does not
	 * answer, to prove the dispatcher refuses an action set up for the wrong step.
	 */
	private static final String TEST_AFTER_INSERT = TRG_Dispatcher_TEST.class.getName() + '.TestAfterInsert';
	/**
	 * @description Full name of the inner class TestAfterUndelete, set as the action class when a test needs an
	 * action that answers the after undelete step.
	 */
	private static final String TEST_AFTER_UNDELETE = TRG_Dispatcher_TEST.class.getName() + '.TestAfterUndelete';
	/**
	 * @description Full name of the inner class TestAfterUpdate, set as the action class when a test needs an
	 * action that answers the after update step.
	 */
	private static final String TEST_AFTER_UPDATE = TRG_Dispatcher_TEST.class.getName() + '.TestAfterUpdate';
	/**
	 * @description Full name of the inner class TestBeforeDelete, set as the action class when a test needs an
	 * action that answers the before delete step.
	 */
	private static final String TEST_BEFORE_DELETE = TRG_Dispatcher_TEST.class.getName() + '.TestBeforeDelete';
	/**
	 * @description Full name of the inner class TestBeforeInsert, set as the action class when a test needs an
	 * action that answers the before insert step. Most tests in the class use this one. It is also configured for
	 * the other steps, which it does not answer, to prove the dispatcher refuses an action set up for the wrong step.
	 */
	private static final String TEST_BEFORE_INSERT = TRG_Dispatcher_TEST.class.getName() + '.TestBeforeInsert';
	/**
	 * @description Full name of the inner class TestBeforeUpdate, set as the action class when a test needs an
	 * action that answers the before update step.
	 */
	private static final String TEST_BEFORE_UPDATE = TRG_Dispatcher_TEST.class.getName() + '.TestBeforeUpdate';
	/**
	 * @description Full name of the inner class TestConfigurable, the action that also receives its own
	 * configuration row. Tests set it as the action class to check which row the dispatcher hands over.
	 */
	private static final String TEST_CONFIGURABLE = TRG_Dispatcher_TEST.class.getName() + '.TestConfigurable';
	/**
	 * @description Full name of the inner class LoggingAfterInsert, the action that writes a log entry while it
	 * runs. Tests set it as the action class to check what happens to a log written during an event dispatch.
	 */
	private static final String TEST_LOGGING_AFTER_INSERT = TRG_Dispatcher_TEST.class.getName() + '.LoggingAfterInsert';
	/**
	 * @description The fingerprint (a fixed label that identifies one log entry) that LoggingAfterInsert puts on
	 * its log. isLoggingActionEntryPersisted looks for it to tell whether that entry was saved.
	 */
	private static final String LOGGING_ACTION_FINGERPRINT = 'trg-dispatcher-test-logging-action';
	/**
	 * @description Full name of the inner class TestMixedApexBeforeInsert, the Apex half of the tests that run an
	 * Apex action and a flow action for the same trigger step.
	 */
	private static final String MIXED_APEX_ACTION = TRG_Dispatcher_TEST.class.getName() + '.TestMixedApexBeforeInsert';
	/**
	 * @description Name of TRG_InvokeFlow, the framework action that runs a flow. It is the flow half of the tests
	 * that run an Apex action and a flow action for the same trigger step.
	 */
	private static final String MIXED_FLOW_ACTION = TRG_InvokeFlow.class.getName();
	/**
	 * @description The flow name written on the flow action's configuration row and registered with
	 * TST_InvokeFlowMock, so the tests can script the flow's result and count its runs without a real flow.
	 */
	private static final String MIXED_FLOW_NAME = 'TRG_Dispatcher_TEST_MixedStackFlow';
	/**
	 * @description The value TestMixedApexBeforeInsert writes into each record's Name. Finding it after the run
	 * proves the Apex action's change to the record was kept.
	 */
	private static final String MIXED_APEX_NAME_VALUE = 'mixed-apex-mutated';
	/**
	 * @description The value the mocked flow returns for the record's TextArea__c field. Finding it on the record
	 * after the run proves the flow's output was written back.
	 */
	private static final String MIXED_FLOW_TEXTAREA_VALUE = 'mixed-flow-mutated';
	/**
	 * @description Full name of the inner class TestThrowingBeforeInsert, the action that always throws. Tests set
	 * it as the action class to check what the dispatcher does when an action fails.
	 */
	private static final String THROWING_ACTION = TRG_Dispatcher_TEST.class.getName() + '.TestThrowingBeforeInsert';
	/**
	 * @description The message on the exception TestThrowingBeforeInsert throws. Tests compare it with the message
	 * they catch, to prove the original exception reaches them unchanged.
	 */
	private static final String THROWING_ACTION_MESSAGE = 'Test action threw on purpose';
	/**
	 * @description The failure action value that tells the dispatcher to log an action's failure and let the
	 * save carry on.
	 */
	private static final String FAILURE_LOG_AND_CONTINUE = 'LogAndContinue';
	/**
	 * @description The failure action value that tells the dispatcher to log an action's failure and then throw
	 * the original exception again, so the save is stopped.
	 */
	private static final String FAILURE_BLOCK_DML = 'BlockDml';

	/**
	 * @description The one Foobar__c record most tests give the dispatcher as the trigger's new or old records.
	 * It is built in memory with a random Id and is never saved, so the tests run without touching the database.
	 */
	private static final Foobar__c DEFAULT_RECORD = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
			.withOverride(Foobar__c.Name, DEFAULT_RECORD_NAME)
			.withOverride(Foobar__c.Id, UTIL_Random.randomId(Foobar__c.SObjectType))
			.withoutInsertion()
			.build();

	/**
	 * @description The dispatcher under test. Each test sets its records, its trigger step and its list of
	 * actions directly and then calls run, which stands in for a real trigger firing.
	 */
	private static final TRG_Dispatcher FACTORY_TRIGGER_ACTION = new TRG_Dispatcher();

	/**
	 * @description An in-memory trigger setting row for the Foobar object. Every action row the tests build is
	 * attached to it, so the tests do not depend on the trigger settings that exist in the org.
	 */
	private static final TriggerSetting__mdt TRIGGER_SETTING = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

	/**
	 * @description Set to true by TestAfterDelete when the dispatcher calls it; a test reads it to prove the after
	 * delete action ran.
	 */
	private static Boolean wasAfterDeleteCalled = false;
	/**
	 * @description Set to true by TestAfterInsert when the dispatcher calls it; a test reads it to prove the after
	 * insert action ran.
	 */
	private static Boolean wasAfterInsertCalled = false;
	/**
	 * @description Set to true by TestAfterUndelete when the dispatcher calls it; a test reads it to prove the
	 * after undelete action ran.
	 */
	private static Boolean wasAfterUndeleteCalled = false;
	/**
	 * @description Set to true by TestAfterUpdate when the dispatcher calls it; a test reads it to prove the after
	 * update action ran.
	 */
	private static Boolean wasAfterUpdateCalled = false;
	/**
	 * @description Set to true by TestBeforeDelete when the dispatcher calls it; a test reads it to prove the
	 * before delete action ran.
	 */
	private static Boolean wasBeforeDeleteCalled = false;
	/**
	 * @description Set to true by TestBeforeInsert when the dispatcher calls it. Tests read it to prove the before
	 * insert action ran, or that it did not run when it was bypassed or filtered out.
	 */
	private static Boolean wasBeforeInsertCalled = false;
	/**
	 * @description Set to true by TestBeforeUpdate when the dispatcher calls it; a test reads it to prove the
	 * before update action ran.
	 */
	private static Boolean wasBeforeUpdateCalled = false;
	/**
	 * @description Set to true by TestThrowingBeforeInsert just before it throws. Tests read it to prove the
	 * failing action was really called, so the failure they check came from the action.
	 */
	private static Boolean wasThrowingActionCalled = false;
	/**
	 * @description Set to true by LoggingAfterInsert just before it writes its log. Tests read it to prove the
	 * action ran, and so a log entry was produced for the dispatcher to handle.
	 */
	private static Boolean wasLoggingActionCalled = false;

	/**
	 * @description Per-DeveloperName tally of `setConfig` invocations on `TestConfigurable`,
	 * letting tests assert which CMDT row(s) the dispatcher passed in.
	 */
	private static final Map<String, Integer> CONFIGURABLE_SET_CONFIG_CALLS = new Map<String, Integer>();
	/**
	 * @description Per-DeveloperName tally of `beforeInsert` invocations on `TestConfigurable`,
	 * letting tests assert that each row's interface method ran independently of the others.
	 */
	private static final Map<String, Integer> CONFIGURABLE_BEFORE_INSERT_CALLS = new Map<String, Integer>();
	/**
	 * @description Captures the most recent `TriggerAction__mdt` reference handed to
	 * `TestConfigurable.setConfig` so tests can assert identity (not just developer name).
	 */
	private static TriggerAction__mdt configurableLastConfig;
	/**
	 * @description When set, `TestConfigurable.beforeInsert` re-enters the dispatcher with the
	 * same `actionMetadataOverride` already in effect, simulating a self-initiated DML that
	 * pushes a second frame onto the action stack with the same `(actionType, fingerprint)`
	 * pair. The outer frame is still on the stack at that moment because the dispatcher pops
	 * only inside its `finally` block.
	 */
	private static Boolean configurableShouldReenter = false;

	/**
	 * @description Tally for mixed-action-stack tests, flipped to true by `TestMixedApexBeforeInsert`
	 * so tests can assert the Apex side of a mixed Apex+Flow stack actually executed.
	 */
	private static Boolean wasMixedApexBeforeInsertCalled = false;

	/**
	 * @description Apex class name of the post-trigger action mock injected via
	 * `SEL_PostTriggerAction.overrideRows`, used to assert the dispatcher's outermost-unwind
	 * hook fires `UTIL_PostTriggerAction.run` the expected number of times.
	 */
	private static final String POST_ACTION = TRG_Dispatcher_TEST.class.getName() + '.TestPostAction';
	/**
	 * @description Apex class name of the post-trigger action mock that performs synchronous DML on
	 * its first execution only, injected via `SEL_PostTriggerAction.overrideRows` to make the hook
	 * throw `PostActionDmlException` at the outermost unwind of an event dispatch.
	 */
	private static final String TEST_DML_ONCE_POST_ACTION = TRG_Dispatcher_TEST.class.getName() + '.TestDmlOncePostAction';
	/**
	 * @description Count of `TestPostAction.execute` invocations in the current transaction.
	 * Reset by `registerSinglePostAction`. The outermost-unwind hook must drive this to exactly
	 * one per top-level dispatch that completes normally, and to zero when the dispatch aborts.
	 */
	private static Integer postActionInvocationCount = 0;
	/**
	 * @description Whether `TestDmlOncePostAction.execute` has already run in the current
	 * transaction. The mock performs its guard-tripping DML only on the first execution, so the
	 * nested `LogEntry__c` dispatch fired by the protected teardown's buffered-log persist runs the
	 * hook clean instead of tripping the no-DML guard a second time (which would roll back the
	 * persisted rows the teardown-protection test asserts on).
	 */
	private static Boolean dmlOncePostActionHasExecuted = false;
	/**
	 * @description The `touchedSObjectTypes` set most recently delivered to `TestPostAction.execute`,
	 * captured so tests can assert which object types the dispatcher accumulated and that the set is
	 * cleared between top-level dispatches.
	 */
	private static Set<SObjectType> capturedTouchedTypes;

	/**
	 * @description Tests the after delete trigger action
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void afterDelete()
	{
		runTriggerAction(TEST_AFTER_DELETE, TriggerOperation.AFTER_DELETE);
		Assert.isTrue(wasAfterDeleteCalled, 'After delete action should have been called');
	}

	/**
	 * @description Tests that an exception is thrown for an incorrect class in after delete
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void afterDeleteIncorrectClass()
	{
		assertRunThrows(BOGUS_CLASS_NAME, TriggerOperation.AFTER_DELETE, IllegalArgumentException.class, 'Expected IllegalArgumentException to be thrown');
	}

	/**
	 * @description Tests that an exception is thrown for an incorrect type in after delete
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void afterDeleteIncorrectType()
	{
		assertRunThrows(TEST_BEFORE_INSERT, TriggerOperation.AFTER_DELETE, TypeException.class, 'Expected TypeException to be thrown');
	}

	/**
	 * @description Tests the after insert trigger action
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void afterInsert()
	{
		runTriggerAction(TEST_AFTER_INSERT, TriggerOperation.AFTER_INSERT);
		Assert.isTrue(wasAfterInsertCalled, 'After insert action should have been called');
	}

	/**
	 * @description Tests that an exception is thrown for an incorrect class in after insert
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void afterInsertIncorrectClass()
	{
		assertRunThrows(BOGUS_CLASS_NAME, TriggerOperation.AFTER_INSERT, IllegalArgumentException.class, 'Expected IllegalArgumentException to be thrown');
	}

	/**
	 * @description Tests that an exception is thrown for an incorrect type in after insert
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void afterInsertIncorrectType()
	{
		assertRunThrows(TEST_BEFORE_INSERT, TriggerOperation.AFTER_INSERT, TypeException.class, 'Expected TypeException to be thrown');
	}

	/**
	 * @description Tests the after undelete trigger action
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void afterUndelete()
	{
		runTriggerAction(TEST_AFTER_UNDELETE, TriggerOperation.AFTER_UNDELETE);
		Assert.isTrue(wasAfterUndeleteCalled, 'After undelete action should have been called');
	}

	/**
	 * @description Tests that an exception is thrown for an incorrect class in after undelete
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void afterUndeleteIncorrectClass()
	{
		assertRunThrows(BOGUS_CLASS_NAME, TriggerOperation.AFTER_UNDELETE, IllegalArgumentException.class, 'Expected IllegalArgumentException to be thrown');
	}

	/**
	 * @description Tests that an exception is thrown for an incorrect type in after undelete
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void afterUndeleteIncorrectType()
	{
		assertRunThrows(TEST_BEFORE_INSERT, TriggerOperation.AFTER_UNDELETE, TypeException.class, 'Expected TypeException to be thrown');
	}

	/**
	 * @description Tests the after update trigger action
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void afterUpdate()
	{
		runTriggerAction(TEST_AFTER_UPDATE, TriggerOperation.AFTER_UPDATE);
		Assert.isTrue(wasAfterUpdateCalled, 'After update action should have been called');
	}

	/**
	 * @description Tests that an exception is thrown for an incorrect class in after update
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void afterUpdateIncorrectClass()
	{
		assertRunThrows(BOGUS_CLASS_NAME, TriggerOperation.AFTER_UPDATE, IllegalArgumentException.class, 'Expected IllegalArgumentException to be thrown');
	}

	/**
	 * @description Tests that an exception is thrown for an incorrect type in after update
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void afterUpdateIncorrectType()
	{
		assertRunThrows(TEST_BEFORE_INSERT, TriggerOperation.AFTER_UPDATE, TypeException.class, 'Expected TypeException to be thrown');
	}

	/**
	 * @description Tests the before delete trigger action
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void beforeDelete()
	{
		runTriggerAction(TEST_BEFORE_DELETE, TriggerOperation.BEFORE_DELETE);
		Assert.isTrue(wasBeforeDeleteCalled, 'Before delete action should have been called');
	}

	/**
	 * @description Tests that an exception is thrown for an incorrect class in before delete
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void beforeDeleteIncorrectClass()
	{
		assertRunThrows(BOGUS_CLASS_NAME, TriggerOperation.BEFORE_DELETE, IllegalArgumentException.class, 'Expected IllegalArgumentException to be thrown');
	}

	/**
	 * @description Tests that an exception is thrown for an incorrect type in before delete
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void beforeDeleteIncorrectType()
	{
		assertRunThrows(TEST_BEFORE_INSERT, TriggerOperation.BEFORE_DELETE, TypeException.class, 'Expected TypeException to be thrown');
	}

	/**
	 * @description Tests the before insert trigger action
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void beforeInsert()
	{
		runTriggerAction(TEST_BEFORE_INSERT, TriggerOperation.BEFORE_INSERT);
		Assert.isTrue(wasBeforeInsertCalled, 'Before insert action should have been called');
	}

	/**
	 * @description Tests that an exception is thrown for an incorrect class in before insert
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void beforeInsertIncorrectClass()
	{
		assertRunThrows(BOGUS_CLASS_NAME, TriggerOperation.BEFORE_INSERT, IllegalArgumentException.class, 'Expected IllegalArgumentException to be thrown');
	}

	/**
	 * @description Tests that an exception is thrown for an incorrect type in before insert
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void beforeInsertIncorrectType()
	{
		assertRunThrows(TEST_AFTER_INSERT, TriggerOperation.BEFORE_INSERT, TypeException.class, 'Expected TypeException to be thrown');
	}

	/**
	 * @description Tests the before update trigger action
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void beforeUpdate()
	{
		runTriggerAction(TEST_BEFORE_UPDATE, TriggerOperation.BEFORE_UPDATE);
		Assert.isTrue(wasBeforeUpdateCalled, 'Before update action should have been called');
	}

	/**
	 * @description Tests that an exception is thrown for an incorrect class in before update
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void beforeUpdateIncorrectClass()
	{
		assertRunThrows(BOGUS_CLASS_NAME, TriggerOperation.BEFORE_UPDATE, IllegalArgumentException.class, 'Expected IllegalArgumentException to be thrown');
	}

	/**
	 * @description Tests that an exception is thrown for an incorrect type in before update
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void beforeUpdateIncorrectType()
	{
		assertRunThrows(TEST_BEFORE_INSERT, TriggerOperation.BEFORE_UPDATE, TypeException.class, 'Expected TypeException to be thrown');
	}

	/**
	 * @description Tests that an action-level bypass prevents the dispatcher from executing the action
	 *
	 * @see TRG_Base.bypassAction
	 * @see TRG_Base.isActionBypassed
	 */
	@IsTest
	private static void actionBypassPreventsExecution()
	{
		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext(
				TEST_BEFORE_INSERT, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		TRG_Base.bypassAction(TEST_BEFORE_INSERT);

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();

		Assert.isFalse(wasBeforeInsertCalled, 'Action should not be called when bypassed via TRG_Base.bypassAction');
	}

	/**
	 * @description Tests that an object-level bypass prevents the dispatcher from executing any actions
	 *
	 * @see TRG_Base.bypass
	 * @see TRG_Base.isBypassed
	 */
	@IsTest
	private static void objectBypassPreventsDispatch()
	{
		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext(
				TEST_BEFORE_INSERT, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		TRG_Base.bypass(SEL_Foobar.OBJECT_NAME);

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();

		Assert.isFalse(wasBeforeInsertCalled, 'Action should not be called when object is bypassed via TRG_Base.bypass');
	}

	/**
	 * @description Verifies that feature flag integration works end-to-end through the real DAL query path.
	 * Uses Foobar__c which has real TriggerAction__mdt configured without permission restrictions,
	 * so the action should execute normally.
	 *
	 * NOTE: Feature flag filtering logic is tested in SEL_TriggerAction_TEST where the actual
	 * shouldExecute() method resides. This test verifies the integration
	 * between TRG_Dispatcher and SEL_TriggerAction.
	 *
	 * @see SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation
	 * @see SEL_TriggerAction_TEST
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void featureFlagIntegrationViaRealMetadataQuery()
	{
		SEL_FeatureFlag.allDeveloperNames = null;

		TRG_Dispatcher factory = new TRG_Dispatcher();
		Foobar__c foobarRecord = TST_Factory.newFoobar();
		factory.triggerNew = new List<Foobar__c> {foobarRecord};
		factory.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();

		factory.run();

		Test.stopTest();

		List<TriggerAction__mdt> actions = SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation(SEL_Foobar.OBJECT_NAME, TriggerOperation.BEFORE_INSERT);
		Assert.isFalse(actions.isEmpty(), 'Foobar should have configured trigger actions that pass feature flag filtering');
		Assert.isTrue(actions[0].ApexClassName__c.contains('TRG_SetFoobarDefaults'), 'TRG_SetFoobarDefaults action should be included');
	}

	/**
	 * @description Verifies that when DAL filters out an action (due to bypass flag being enabled),
	 * the factory does NOT execute that action.
	 * Tests the integration contract: Factory trusts DAL's filtering.
	 *
	 * Scenario: Action has BypassFeatureFlag__c = 'TestBypassFlag', flag is enabled
	 * Expected: DAL excludes action → Factory receives empty list → Action NOT executed
	 *
	 * @see SEL_TriggerAction.shouldExecute
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void factoryDoesNotExecuteWhenDALFiltersOutBypassedAction()
	{
		SEL_FeatureFlag.allDeveloperNames = new Set<String> {'TestBypassFlag'};

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>> {TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt>()};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();

		Assert.isFalse(wasBeforeInsertCalled, 'Action should NOT be called when DAL filters it out due to bypass flag');
	}

	/**
	 * @description Verifies that when DAL filters out an action (due to required flag being disabled),
	 * the factory does NOT execute that action.
	 * Tests the integration contract: Factory trusts DAL's filtering.
	 *
	 * Scenario: Action has RequiredFeatureFlag__c = 'TestRequiredFlag', flag is disabled
	 * Expected: DAL excludes action → Factory receives empty list → Action NOT executed
	 *
	 * @see SEL_TriggerAction.shouldExecute
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void factoryDoesNotExecuteWhenDALFiltersOutRequiredNotMet()
	{
		SEL_FeatureFlag.allDeveloperNames = new Set<String> {'TestRequiredFlag'};

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>> {TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt>()};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();

		Assert.isFalse(wasBeforeInsertCalled, 'Action should NOT be called when DAL filters it out due to required flag not met');
	}

	/**
	 * @description Verifies that when a feature flag is defined but disabled, the factory receives
	 * an empty action list from DAL filtering and does not execute the action.
	 *
	 * Scenario: Value 'MyFeatureOrPermission' exists as Feature Flag definition (disabled)
	 * Expected: DAL excludes action → Factory receives empty list → Action NOT executed
	 *
	 * @see SEL_TriggerAction.shouldExecute
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void factoryRespectsFeatureFlagFilteringFromDAL()
	{
		SEL_FeatureFlag.allDeveloperNames = new Set<String> {'MyFeatureOrPermission'};

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>> {TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt>()};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();

		Assert.isFalse(wasBeforeInsertCalled, 'Strict Definition Priority: Factory should respect DAL feature flag filtering');
	}

	/**
	 * @description Verifies that when an action PASSES feature flag filtering (no bypass, required met),
	 * the factory correctly EXECUTES it. Tests the positive path of the integration.
	 *
	 * Simulates DAL returning an action (i.e., all feature flag conditions were met).
	 *
	 * @see SEL_TriggerAction.shouldExecute
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void factoryExecutesActionWhenFeatureFlagConditionsMet()
	{
		SEL_FeatureFlag.allDeveloperNames = new Set<String> {'TestRequiredFlag'};

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerAction(TEST_BEFORE_INSERT, TRIGGER_SETTING, null, 'TestRequiredFlag');

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();

		Assert.isTrue(wasBeforeInsertCalled, 'Action SHOULD be called when DAL includes it (feature flag conditions met)');
	}

	/**
	 * @description Tests that ForcePerformanceLogging creates a log entry even when global trigger logging is disabled.
	 * Verifies ForcePerformanceLogging__c bypasses the LogSetting__c EnableTriggerPerformanceLogging__c check.
	 *
	 * @see TRG_Dispatcher
	 * @see UTIL_TriggerPerformanceTimer
	 */
	@IsTest
	private static void shouldLogWhenForcePerformanceLoggingEnabled()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext(TEST_BEFORE_INSERT, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		triggerAction.ForcePerformanceLogging__c = true;

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();

		Assert.isTrue(wasBeforeInsertCalled, 'Before insert action should have been called');

		LogEntry__c performanceLog = new SEL_LogEntry().findPerformanceLogByMethod(TEST_BEFORE_INSERT + '/before_insert');
		Assert.isNotNull(performanceLog, 'ForcePerformanceLogging should create log even when global trigger logging is disabled');
	}

	/**
	 * @description Tests that SuppressPerformanceLogging prevents log creation even when global trigger logging is enabled.
	 * Verifies SuppressPerformanceLogging__c takes precedence over threshold settings.
	 *
	 * @see TRG_Dispatcher
	 * @see UTIL_TriggerPerformanceTimer
	 */
	@IsTest
	private static void shouldNotLogWhenSuppressPerformanceLoggingEnabled()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.newLoggerSettings().withTriggerLogging(0).apply();

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext(TEST_BEFORE_INSERT, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		triggerAction.SuppressPerformanceLogging__c = true;

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();

		Assert.isTrue(wasBeforeInsertCalled, 'Before insert action should have been called');

		LogEntry__c performanceLog = new SEL_LogEntry().findPerformanceLogByMethod(TEST_BEFORE_INSERT + '/before_insert');
		Assert.isNull(performanceLog, 'SuppressPerformanceLogging should prevent log creation even when global trigger logging is enabled');
	}

	/**
	 * @description Tests that PerformanceThresholdMs__c at action level overrides global threshold.
	 * Setting threshold to 0 means "log all actions" - verifies log is created.
	 *
	 * @see TRG_Dispatcher
	 * @see UTIL_TriggerPerformanceTimer
	 */
	@IsTest
	private static void shouldLogWhenCustomThresholdExceeded()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.newLoggerSettings().withTriggerLogging(999999).apply();

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext(TEST_BEFORE_INSERT, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		triggerAction.PerformanceThresholdMs__c = 0;

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();

		Assert.isTrue(wasBeforeInsertCalled, 'Before insert action should have been called');

		LogEntry__c performanceLog = new SEL_LogEntry().findPerformanceLogByMethod(TEST_BEFORE_INSERT + '/before_insert');
		Assert.isNotNull(performanceLog, 'Action-level PerformanceThresholdMs__c should override global threshold');
	}

	/**
	 * @description Tests that performance log includes record count in the message.
	 * Verifies the performance timer correctly captures the batch size.
	 *
	 * @see TRG_Dispatcher
	 * @see UTIL_TriggerPerformanceTimer
	 */
	@IsTest
	private static void shouldIncludeRecordCountInPerformanceLog()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.newLoggerSettings().withTriggerLogging(0).apply();

		FACTORY_TRIGGER_ACTION.triggerNew = TST_Builder.of(Foobar__c.SObjectType).withCount(5).withoutInsertion(true).buildList();

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext(
				TEST_BEFORE_INSERT, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();

		Assert.isTrue(wasBeforeInsertCalled, 'Before insert action should have been called');

		LogEntry__c performanceLog = new SEL_LogEntry().findPerformanceLogByMethod(TEST_BEFORE_INSERT + '/before_insert');
		Assert.isNotNull(performanceLog, 'Performance log should be created');
		Assert.isTrue(performanceLog.Message__c.contains('Records: 5'), 'Performance log should include record count');
	}

	/**
	 * @description Tests that calling run() outside a trigger context throws IllegalStateException.
	 *
	 * @see TRG_Dispatcher.run
	 */
	@IsTest
	private static void shouldThrowWhenCalledOutsideTriggerContext()
	{
		TRG_Dispatcher dispatcher = new TRG_Dispatcher();

		try
		{
			Test.startTest();

			dispatcher.run();

			Test.stopTest();

			Assert.fail(MSG_EXCEPTION_EXPECTED);
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Should throw IllegalStateException');
		}
	}

	/**
	 * @description Tests that selfInitiated check is evaluated when AllowNonSelfInitiated is disabled.
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void shouldEvaluateSelfInitiatedWhenNotAllowNonSelfInitiated()
	{
		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext(
				TEST_BEFORE_INSERT, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		triggerAction.AllowNonSelfInitiated__c = false;

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();

		Assert.isTrue(wasBeforeInsertCalled, 'Self-initiated action should still execute');
	}

	/**
	 * @description Configures and runs a trigger action, asserting that it throws the expected exception type.
	 *
	 * @param actionClassName The Apex class name for the trigger action
	 * @param operation The trigger operation context
	 * @param expectedExceptionType The expected exception type
	 * @param assertionMessage The assertion failure message
	 */
	private static void assertRunThrows(String actionClassName, TriggerOperation operation, Type expectedExceptionType, String assertionMessage)
	{
		configureDispatcherForOperation(actionClassName, operation);

		try
		{
			Test.startTest();
			FACTORY_TRIGGER_ACTION.run();
			Test.stopTest();
			Assert.fail(MSG_EXCEPTION_EXPECTED);
		}
		catch(Exception caughtException)
		{
			Assert.isInstanceOfType(caughtException, expectedExceptionType, assertionMessage);
		}
	}

	/**
	 * @description Configures and runs a trigger action for the given operation.
	 * Sets triggerNew/triggerOld based on operation type, creates the action metadata, and executes the dispatcher.
	 *
	 * @param actionClassName The Apex class name for the trigger action
	 * @param operation The trigger operation context
	 */
	private static void runTriggerAction(String actionClassName, TriggerOperation operation)
	{
		configureDispatcherForOperation(actionClassName, operation);

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();
	}

	/**
	 * @description Populates the dispatcher's trigger collections and action metadata for a given
	 * operation context. Extracted to remove the duplicate setup block that existed in
	 * `runTriggerAction` and `assertRunThrows`.
	 *
	 * @param actionClassName The Apex class name for the trigger action
	 * @param operation The trigger operation context
	 */
	private static void configureDispatcherForOperation(String actionClassName, TriggerOperation operation)
	{
		switch on operation
		{
			when BEFORE_INSERT, AFTER_INSERT, AFTER_UNDELETE
			{
				FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};
			}
			when BEFORE_DELETE, AFTER_DELETE
			{
				FACTORY_TRIGGER_ACTION.triggerOld = new List<Foobar__c> {DEFAULT_RECORD};
			}
			when BEFORE_UPDATE, AFTER_UPDATE
			{
				FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};
				FACTORY_TRIGGER_ACTION.triggerOld = new List<Foobar__c> {DEFAULT_RECORD};
			}
		}

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext(actionClassName, TRIGGER_SETTING, operation);

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				operation => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = operation;
	}

	/**
	 * @description Whether the logging action's fingerprinted entry reached LogEntry__c, read through the selector so
	 * the check sees exactly what direct DML persisted.
	 *
	 * @return True when at least one persisted row carries the action's fingerprint detail key.
	 */
	private static Boolean isLoggingActionEntryPersisted()
	{
		String detailKey = TRG_PersistLogEntry.PREFIX_DETAIL + LOGGING_ACTION_FINGERPRINT;
		for(LogEntry__c row : new SEL_LogEntry().getAll())
		{
			if(detailKey.equals(row.Fingerprint__c))
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * @description Mock implementation for before insert trigger action
	 */
	public class TestBeforeInsert implements IF_Trigger.BeforeInsert
	{
		/**
		 * @description Sets wasBeforeInsertCalled so the test can prove the dispatcher reached the before-insert callback.
		 *
		 * @param triggerNew The records about to be inserted; unused.
		 */
		public void beforeInsert(List<SObject> triggerNew)
		{
			TRG_Dispatcher_TEST.wasBeforeInsertCalled = true;
		}
	}

	/**
	 * @description Mock implementation for after insert trigger action
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	public class TestAfterInsert implements IF_Trigger.AfterInsert
	{
		/**
		 * @description Sets wasAfterInsertCalled so the test can prove the dispatcher reached the after-insert callback.
		 *
		 * @param triggerNew The inserted records; unused.
		 */
		public void afterInsert(List<SObject> triggerNew)
		{
			TRG_Dispatcher_TEST.wasAfterInsertCalled = true;
		}
	}

	/**
	 * @description Mock after-insert action that emits a fingerprinted DEBUG log (the real
	 * skip-log shape that floods under change-event redelivery), simulating an action that logs
	 * while the dispatcher is processing a change-event / platform-event. DEBUG exercises the
	 * buffered branch end-to-end (begin suspends saving, the emit buffers, the dispatch-boundary
	 * flush persists via DML). Used by `changeEventDispatchPersistsActionLogsViaDmlWithoutPublishing`
	 * to prove the dispatcher enters event-trigger context so the log persists via DML rather than
	 * republishing and looping.
	 */
	public class LoggingAfterInsert implements IF_Trigger.AfterInsert
	{
		/**
		 * @description Sets wasLoggingActionCalled, then emits a fingerprinted DEBUG log so the test can observe how the dispatcher
		 * persists an action's log during change-event dispatch.
		 *
		 * @param triggerNew The inserted records; unused.
		 */
		public void afterInsert(List<SObject> triggerNew)
		{
			TRG_Dispatcher_TEST.wasLoggingActionCalled = true;
			LOG_Builder.build()
					.debug('logging action fired during change-event dispatch')
					.withFingerprintInternal(LOGGING_ACTION_FINGERPRINT)
					.at(TRG_Dispatcher_TEST.class.getName() + '.LoggingAfterInsert.afterInsert')
					.emit();
		}
	}

	/**
	 * @description Mock implementation for before update trigger action
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	public class TestBeforeUpdate implements IF_Trigger.BeforeUpdate
	{
		/**
		 * @description Sets wasBeforeUpdateCalled so the test can prove the dispatcher reached the before-update callback.
		 *
		 * @param triggerNew The records about to be updated; unused.
		 * @param triggerOld Their prior versions; unused.
		 */
		public void beforeUpdate(List<SObject> triggerNew, List<SObject> triggerOld)
		{
			TRG_Dispatcher_TEST.wasBeforeUpdateCalled = true;
		}
	}

	/**
	 * @description Mock implementation for after update trigger action
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	public class TestAfterUpdate implements IF_Trigger.AfterUpdate
	{
		/**
		 * @description Sets wasAfterUpdateCalled so the test can prove the dispatcher reached the after-update callback.
		 *
		 * @param triggerNew The updated records; unused.
		 * @param triggerOld Their prior versions; unused.
		 */
		public void afterUpdate(List<SObject> triggerNew, List<SObject> triggerOld)
		{
			TRG_Dispatcher_TEST.wasAfterUpdateCalled = true;
		}
	}

	/**
	 * @description Tests that `applyMaskingIfConfigured` invokes a `UTIL_MaskerPerformanceTimer`
	 * when all three gates pass: BEFORE_INSERT context, masking framework enabled, and the
	 * object's TriggerSetting permits masking. Asserts that the timer's per-transaction counter
	 * increments when logging is configured to emit, proving the timer is actually driven by
	 * the dispatcher, not just instantiated.
	 */
	@IsTest
	private static void shouldDriveMaskerPerformanceTimerWhenMaskingConfigured()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.newLoggerSettings().withMaskerLogging(0).apply();

		SEL_TriggerAction.applyMaskingByObjectNameMap = new Map<String, Boolean> {SEL_Foobar.OBJECT_NAME => true};
		UTIL_MaskerPerformanceTimer.logCountThisTransaction = 0;

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt>()
		};

		FACTORY_TRIGGER_ACTION.run();

		Assert.areEqual(1, UTIL_MaskerPerformanceTimer.logCountThisTransaction, 'Masker timer should emit once when all gates pass and logging threshold is met');
	}

	/**
	 * @description Tests that `applyMaskingIfConfigured` short-circuits before constructing a
	 * `UTIL_MaskerPerformanceTimer` when the masking framework kill-switch feature flag is
	 * off. Asserts the timer's per-transaction counter stays at zero, proving the dispatcher
	 * skips masking (and its timer) when subscribers have disabled the framework.
	 */
	@IsTest
	private static void shouldSkipMaskerTimerWhenMaskingFrameworkDisabled()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.newLoggerSettings().withMaskerLogging(0).apply();

		SEL_FeatureFlag.activeFlags.remove(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);
		SEL_TriggerAction.applyMaskingByObjectNameMap = new Map<String, Boolean> {SEL_Foobar.OBJECT_NAME => true};
		UTIL_MaskerPerformanceTimer.logCountThisTransaction = 0;

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt>()
		};

		FACTORY_TRIGGER_ACTION.run();

		Assert.areEqual(0, UTIL_MaskerPerformanceTimer.logCountThisTransaction, 'Masker timer must not run when masking framework flag is off');
	}

	/**
	 * @description Loop-fix integration guard: when the dispatcher runs on a change-event (here
	 * `AccountChangeEvent`), a log emitted by one of its actions must be persisted to `LogEntry__c`
	 * via direct DML, NOT published as a `LogEntryEvent__e`. Publishing a platform event from inside
	 * a change-event/platform-event trigger makes the platform redeliver the source event, re-running
	 * the dispatcher unbounded. `getPublishImmediateDML` staying flat across `run()` proves no publish
	 * occurred; the persisted flood-control detail row proves the action's log was not lost. This
	 * verifies the dispatcher actually enters `LOG_Engine` event-trigger context for event dispatches.
	 *
	 * @see LOG_Engine.beginEventTriggerContext
	 * @see TRG_Dispatcher.run
	 */
	@IsTest
	private static void changeEventDispatchPersistsActionLogsViaDmlWithoutPublishing()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		wasLoggingActionCalled = false;

		TriggerAction__mdt loggingAction = TST_Factory.newTriggerActionForContext(
				TEST_LOGGING_AFTER_INSERT, TRIGGER_SETTING, TriggerOperation.AFTER_INSERT);

		FACTORY_TRIGGER_ACTION.triggerNew = new List<SObject> {new AccountChangeEvent()};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.AFTER_INSERT;
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.AFTER_INSERT => new List<TriggerAction__mdt> {loggingAction}
		};

		Test.startTest();
		Integer publishBefore = UTIL_Limits.publishImmediateDml().used();
		FACTORY_TRIGGER_ACTION.run();
		Integer publishAfter = UTIL_Limits.publishImmediateDml().used();
		Test.stopTest();

		Assert.isTrue(wasLoggingActionCalled, 'The logging action should have executed during the change-event dispatch');
		Assert.areEqual(publishBefore, publishAfter,
				'A log emitted during a change-event dispatch must persist via DML, never publish (no redelivery loop)');

		Assert.isTrue(isLoggingActionEntryPersisted(), 'The action log must persist via direct DML during change-event dispatch');
	}

	/**
	 * @description Verifies the dispatcher invokes `IF_Trigger.Configurable.setConfig`
	 * before the trigger interface method (`beforeInsert`), passing the exact
	 * `TriggerAction__mdt` row injected via `actionMetadataOverride`. Guards the
	 * Configurable hook contract: ordering (`setConfig` before `beforeInsert`), one-shot
	 * semantics (one `setConfig` per CMDT row), and identity (the same record reference
	 * reaches the action, not a copy or transformation).
	 *
	 * @see IF_Trigger.Configurable
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void shouldInvokeSetConfigBeforeBeforeInsertWhenActionImplementsConfigurable()
	{
		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext(
				TEST_CONFIGURABLE, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();

		Assert.areEqual(1, CONFIGURABLE_SET_CONFIG_CALLS.get(triggerAction.DeveloperName), 'setConfig should run exactly once for the injected CMDT row');
		Assert.areEqual(1, CONFIGURABLE_BEFORE_INSERT_CALLS.get(triggerAction.DeveloperName), 'beforeInsert should run exactly once for the injected CMDT row');
		Assert.areEqual(triggerAction, configurableLastConfig, 'setConfig should receive the exact TriggerAction__mdt row passed via actionMetadataOverride');
	}

	/**
	 * @description Verifies the dispatcher does NOT invoke `setConfig` on actions that
	 * do not implement `IF_Trigger.Configurable`. Negative test guarding against a
	 * future regression where the dispatcher accidentally invokes `setConfig`
	 * reflectively on every action. Uses the existing `TestBeforeInsert` mock which
	 * implements `BeforeInsert` only.
	 *
	 * @see IF_Trigger.Configurable
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void shouldNotInvokeSetConfigWhenActionIsNotConfigurable()
	{
		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext(
				TEST_BEFORE_INSERT, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();

		Assert.isTrue(wasBeforeInsertCalled, 'BeforeInsert action should still execute');
		Assert.isTrue(CONFIGURABLE_SET_CONFIG_CALLS.isEmpty(), 'setConfig must not be invoked on a non-Configurable action');
		Assert.isNull(configurableLastConfig, 'No TriggerAction__mdt should have been handed to setConfig');
	}

	/**
	 * @description Verifies the recursion-identity behavior for `Configurable` actions:
	 * two `TriggerAction__mdt` rows pointing at the same `Configurable` action class
	 * with different `DeveloperName` values both execute, even when both have
	 * `AllowRecursion__c = false`. The `(actionType, fingerprint)` recursion-identity
	 * tuple distinguishes the rows so neither is skipped as a recursion of the other.
	 * Without this distinction the second row would be wrongly skipped because both
	 * rows share `actionType = TestConfigurable.class`.
	 *
	 * @see IF_Trigger.Configurable
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void shouldExecuteBothCmdtRowsWhenSameActionClassDifferentFingerprints()
	{
		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};

		TriggerAction__mdt rowA = TST_Factory.newTriggerActionForContext(
				TEST_CONFIGURABLE, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		rowA.DeveloperName = 'TestConfigurable_RowA';
		rowA.AllowRecursion__c = false;
		TriggerAction__mdt rowB = TST_Factory.newTriggerActionForContext(
				TEST_CONFIGURABLE, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		rowB.DeveloperName = 'TestConfigurable_RowB';
		rowB.AllowRecursion__c = false;

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {rowA, rowB}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();

		Assert.areEqual(1, CONFIGURABLE_SET_CONFIG_CALLS.get('TestConfigurable_RowA'), 'setConfig should run once for row A');
		Assert.areEqual(1, CONFIGURABLE_SET_CONFIG_CALLS.get('TestConfigurable_RowB'), 'setConfig should run once for row B');
		Assert.areEqual(1, CONFIGURABLE_BEFORE_INSERT_CALLS.get('TestConfigurable_RowA'), 'beforeInsert should run once for row A');
		Assert.areEqual(
				1,
				CONFIGURABLE_BEFORE_INSERT_CALLS.get('TestConfigurable_RowB'),
				'beforeInsert should run once for row B (would be skipped without the fingerprint refactor)'
		);
	}

	/**
	 * @description Verifies the recursion shield still fires when the same
	 * `(actionType, fingerprint)` pair recurs via self-initiated re-entry into the
	 * dispatcher. Configures a `Configurable` action with `AllowRecursion__c = false`
	 * and toggles `configurableShouldReenter` so `TestConfigurable.beforeInsert` calls
	 * the dispatcher again with the same metadata override; the outer frame is still
	 * on the action stack at that moment, so the second push gives `inRecursion` two
	 * matching frames and the inner `beforeInsert` is shielded.
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void shouldShieldRecursionWhenSameFingerprintRepeatsViaSelfInitiatedDml()
	{
		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext(
				TEST_CONFIGURABLE, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		triggerAction.DeveloperName = 'TestConfigurable_Recursive';
		triggerAction.AllowRecursion__c = false;

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		configurableShouldReenter = true;

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();

		Assert.areEqual(2, CONFIGURABLE_SET_CONFIG_CALLS.get('TestConfigurable_Recursive'), 'setConfig runs once on each dispatcher entry, including the recursive one');
		Assert.areEqual(1, CONFIGURABLE_BEFORE_INSERT_CALLS.get('TestConfigurable_Recursive'),
				'beforeInsert should run only once: the recursive call must be shielded by the recursion identity tuple');
	}

	/**
	 * @description Verifies that non-`Configurable` actions traverse the
	 * `inRecursion(actionType, null)` code path. Closes the `(null, null)` branch in
	 * `fingerprintsMatch` by exercising the legacy frame shape: non-Configurable
	 * actions push frames with a null fingerprint, and recurring frames must still match
	 * by `actionType` alone.
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void shouldRunNonConfigurableActionWithNullFingerprintPath()
	{
		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext(
				TEST_BEFORE_INSERT, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		triggerAction.AllowRecursion__c = false;

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();

		FACTORY_TRIGGER_ACTION.run();

		Test.stopTest();

		Assert.isTrue(wasBeforeInsertCalled, 'Non-Configurable action should execute through the (actionType, null) path');
		Assert.isTrue(CONFIGURABLE_SET_CONFIG_CALLS.isEmpty(), 'setConfig must not be invoked on a non-Configurable action');
	}

	/**
	 * @description Verifies the truth table for `fingerprintsMatch`: matching null pair returns
	 * true (legacy non-Configurable frame shape), matching non-null returns true (same CMDT row),
	 * non-matching non-null returns false (different rows), and mixed-null returns false. The
	 * mixed-null branch is unreachable from production dispatch (frames sharing actionType share
	 * fingerprint nullity by class invariant) but the discriminator is exposed `@TestVisible` so
	 * the contract can be locked directly without synthesising frames.
	 */
	@IsTest
	private static void shouldReturnExpectedFingerprintMatchForAllInputs()
	{
		Assert.isTrue(TRG_Dispatcher.fingerprintsMatch(null, null), 'Both null should match (legacy non-Configurable frame shape)');
		Assert.isTrue(TRG_Dispatcher.fingerprintsMatch('TestRow', 'TestRow'), 'Equal non-null fingerprints should match (same CMDT row)');
		Assert.isFalse(TRG_Dispatcher.fingerprintsMatch('TestRowA', 'TestRowB'), 'Different non-null fingerprints should not match');
		Assert.isFalse(TRG_Dispatcher.fingerprintsMatch(null, 'TestRow'), 'Null left + non-null right must not match');
		Assert.isFalse(TRG_Dispatcher.fingerprintsMatch('TestRow', null), 'Non-null left + null right must not match');
	}

	/**
	 * @description Verifies a mixed Apex+Flow action stack (Apex action ordered first, Flow
	 * action ordered second) runs both, with the flow's output write-back applied to the
	 * trigger record alongside the Apex action's mutation. The dispatch order is determined
	 * by the `List<TriggerAction__mdt>` order in `actionMetadataOverride`.
	 *
	 * @see TRG_InvokeFlow
	 */
	@IsTest
	private static void shouldRunBothApexAndFlowActionsWhenApexOrderedFirst()
	{
		Foobar__c flowOutput = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.TextArea__c, MIXED_FLOW_TEXTAREA_VALUE)
				.withoutInsertion()
				.build();
		TST_InvokeFlowMock.forFlow(MIXED_FLOW_NAME)
				.succeed()
				.withOutputRecord(flowOutput)
				.register();

		TriggerAction__mdt apexRow = TST_Factory.newTriggerActionForContext(MIXED_APEX_ACTION, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		apexRow.DeveloperName = 'TRG_Dispatcher_TEST_MixedApex';
		TriggerAction__mdt flowRow = TST_Factory.newTriggerActionForContext(MIXED_FLOW_ACTION, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		flowRow.DeveloperName = 'TRG_Dispatcher_TEST_MixedFlow';
		flowRow.FlowName__c = MIXED_FLOW_NAME;
		flowRow.FailureAction__c = 'LogAndContinue';

		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {triggerRecord};
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {apexRow, flowRow}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();
		FACTORY_TRIGGER_ACTION.run();
		Test.stopTest();

		Assert.isTrue(wasMixedApexBeforeInsertCalled, 'Apex action ordered first must execute');
		TST_InvokeFlowMock.assertInvoked(MIXED_FLOW_NAME, 1);
		Assert.areEqual(MIXED_APEX_NAME_VALUE, triggerRecord.Name, 'Apex mutation should be present after dispatch');
		Assert.areEqual(MIXED_FLOW_TEXTAREA_VALUE, triggerRecord.TextArea__c, 'Flow output write-back should be present after dispatch');
	}

	/**
	 * @description Verifies the symmetric ordering: Flow action ordered first, Apex action
	 * second. Both run; both mutations end up on the trigger record. Confirms the dispatcher
	 * applies the flow's output write-back synchronously inside `dispatchAction` so a subsequent
	 * Apex action observes the post-flow record state.
	 *
	 * @see TRG_InvokeFlow
	 */
	@IsTest
	private static void shouldRunBothFlowAndApexActionsWhenFlowOrderedFirst()
	{
		Foobar__c flowOutput = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.TextArea__c, MIXED_FLOW_TEXTAREA_VALUE)
				.withoutInsertion()
				.build();
		TST_InvokeFlowMock.forFlow(MIXED_FLOW_NAME)
				.succeed()
				.withOutputRecord(flowOutput)
				.register();

		TriggerAction__mdt apexRow = TST_Factory.newTriggerActionForContext(MIXED_APEX_ACTION, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		apexRow.DeveloperName = 'TRG_Dispatcher_TEST_MixedApex';
		TriggerAction__mdt flowRow = TST_Factory.newTriggerActionForContext(MIXED_FLOW_ACTION, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		flowRow.DeveloperName = 'TRG_Dispatcher_TEST_MixedFlow';
		flowRow.FlowName__c = MIXED_FLOW_NAME;
		flowRow.FailureAction__c = 'LogAndContinue';

		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {triggerRecord};
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {flowRow, apexRow}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();
		FACTORY_TRIGGER_ACTION.run();
		Test.stopTest();

		Assert.isTrue(wasMixedApexBeforeInsertCalled, 'Apex action ordered second must still execute');
		TST_InvokeFlowMock.assertInvoked(MIXED_FLOW_NAME, 1);
		Assert.areEqual(MIXED_FLOW_TEXTAREA_VALUE, triggerRecord.TextArea__c, 'Flow output should write back before subsequent Apex runs');
		Assert.areEqual(MIXED_APEX_NAME_VALUE, triggerRecord.Name, 'Apex mutation applied after the flow should be present');
	}

	/**
	 * @description Verifies a `BlockDml` flow failure raises `record.addError` and that the
	 * dispatcher continues to subsequent actions in the same trigger context: the dispatch
	 * loop does not short-circuit on `addError`. The eventual DML aborts because of the
	 * marker, but in-memory dispatch completes both actions.
	 *
	 * @see TRG_InvokeFlow
	 */
	@IsTest
	private static void shouldContinueApexActionAfterFlowBlocksDmlButRecordCarriesError()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TST_InvokeFlowMock.forFlow(MIXED_FLOW_NAME).fail('Synthetic flow failure').register();

		TriggerAction__mdt flowRow = TST_Factory.newTriggerActionForContext(MIXED_FLOW_ACTION, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		flowRow.DeveloperName = 'TRG_Dispatcher_TEST_MixedFlowBlock';
		flowRow.FlowName__c = MIXED_FLOW_NAME;
		flowRow.FailureAction__c = 'BlockDml';
		TriggerAction__mdt apexRow = TST_Factory.newTriggerActionForContext(MIXED_APEX_ACTION, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		apexRow.DeveloperName = 'TRG_Dispatcher_TEST_MixedApexAfterBlock';

		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {triggerRecord};
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {flowRow, apexRow}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();
		FACTORY_TRIGGER_ACTION.run();
		Test.stopTest();

		Assert.isTrue(triggerRecord.hasErrors(), 'BlockDml flow failure should mark the record with addError');
		Assert.isTrue(wasMixedApexBeforeInsertCalled, 'Subsequent Apex action still executes in dispatch loop (DML aborts later)');
		TST_InvokeFlowMock.assertInvoked(MIXED_FLOW_NAME, 1);
	}

	/**
	 * @description Verifies action-level bypass via `TRG_Base.bypassAction('TRG_InvokeFlow')`
	 * skips ALL `TRG_InvokeFlow` rows in the dispatch chain while the adjacent Apex action
	 * still runs. Confirms the per-class bypass semantic is the documented escape hatch:
	 * one bypass call disables every flow-action row regardless of `FlowName__c` or
	 * `DeveloperName`.
	 *
	 * @see TRG_InvokeFlow
	 * @see TRG_Base.bypassAction
	 */
	@IsTest
	private static void shouldBypassFlowActionWhileApexActionStillRuns()
	{
		TST_InvokeFlowMock.forFlow(MIXED_FLOW_NAME).succeed().register();

		TriggerAction__mdt flowRow = TST_Factory.newTriggerActionForContext(MIXED_FLOW_ACTION, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		flowRow.DeveloperName = 'TRG_Dispatcher_TEST_MixedFlowBypassed';
		flowRow.FlowName__c = MIXED_FLOW_NAME;
		flowRow.FailureAction__c = 'LogAndContinue';
		TriggerAction__mdt apexRow = TST_Factory.newTriggerActionForContext(MIXED_APEX_ACTION, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		apexRow.DeveloperName = 'TRG_Dispatcher_TEST_MixedApexAfterFlowBypass';

		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {triggerRecord};
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {flowRow, apexRow}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		TRG_Base.bypassAction(MIXED_FLOW_ACTION);

		Test.startTest();
		FACTORY_TRIGGER_ACTION.run();
		Test.stopTest();

		TST_InvokeFlowMock.assertNotInvoked(MIXED_FLOW_NAME);
		Assert.isTrue(wasMixedApexBeforeInsertCalled, 'Adjacent Apex action must still run when only the flow class is bypassed');
	}

	/**
	 * @description Verifies the outermost-unwind hook fires post-trigger actions exactly once
	 * when a self-initiated DML stacks a second dispatch frame. A `Configurable` action with
	 * `AllowRecursion__c = true` re-enters the dispatcher from `beforeInsert`; the inner dispatch
	 * unwinds while the outer action frame is still on `ACTION_STACK`, so the inner unwind is NOT
	 * the outermost and must not fire. Only the outer unwind, when `ACTION_STACK` is empty,
	 * fires. Guards the "use the stack, not a depth counter" outermost-detection contract.
	 *
	 * @see TRG_Dispatcher
	 * @see UTIL_PostTriggerAction
	 */
	@IsTest
	private static void shouldFirePostActionsOnceAtOutermostUnwindWhenDispatchesStacked()
	{
		registerSinglePostAction();

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext(
				TEST_CONFIGURABLE, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		triggerAction.DeveloperName = 'TestConfigurable_StackedDispatch';
		triggerAction.AllowRecursion__c = true;

		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		configurableShouldReenter = true;

		Test.startTest();
		FACTORY_TRIGGER_ACTION.run();
		Test.stopTest();

		Assert.areEqual(1, postActionInvocationCount,
				'Post-actions must fire exactly once at the outermost unwind even when a self-initiated dispatch stacks a second frame');
	}

	/**
	 * @description Verifies clean-completion-only firing and exception-safe state cleanup. A
	 * trigger action rethrows out of `run()`; the aborted dispatch must NOT fire post-actions.
	 * A subsequent clean dispatch on a different object then fires once and delivers ONLY its own
	 * object type, proving the aborted dispatch cleared `touchedSObjectTypes` (no stale-state
	 * leak across top-level DML when an Apex caller catches the failure and continues).
	 *
	 * The abort is driven through the test override that simulates a fatal governor error, so the rethrow happens before
	 * any failure-action logging: a logging failure path persists a log entry, which itself fires a
	 * trigger dispatch that would drive the globally-registered post-action mock and confound the
	 * count. The governor path keeps this test scoped to exactly the dispatch under test.
	 *
	 * @see TRG_Dispatcher
	 */
	@IsTest
	private static void shouldNotFirePostActionsAndShouldClearStateWhenActionThrows()
	{
		registerSinglePostAction();

		TriggerAction__mdt throwingAction = TST_Factory.newTriggerActionForContext(
				THROWING_ACTION, TRIGGER_SETTING, TriggerOperation.BEFORE_INSERT);
		throwingAction.FailureAction__c = FAILURE_LOG_AND_CONTINUE;

		TRG_Dispatcher throwingDispatcher = new TRG_Dispatcher();
		throwingDispatcher.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};
		throwingDispatcher.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {throwingAction}
		};
		throwingDispatcher.context = TriggerOperation.BEFORE_INSERT;
		UTIL_Exceptions.simulateFatalGovernorErrorForTest = true;

		Test.startTest();
		try
		{
			throwingDispatcher.run();
			Assert.fail('A fatal action exception should rethrow out of run()');
		}
		catch(IllegalArgumentException expected)
		{
			Assert.areEqual(THROWING_ACTION_MESSAGE, expected.getMessage(), 'Original action exception should propagate unmodified');
		}
		finally
		{
			UTIL_Exceptions.simulateFatalGovernorErrorForTest = false;
		}

		Assert.areEqual(0, postActionInvocationCount,
				'A dispatch aborted by a throwing action must NOT fire post-actions (clean-completion-only semantics)');

		TRG_Dispatcher cleanDispatcher = new TRG_Dispatcher();
		cleanDispatcher.triggerNew = new List<Account> {(Account)TST_Builder.of(Account.SObjectType).withoutInsertion().build()};
		cleanDispatcher.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt>()
		};
		cleanDispatcher.context = TriggerOperation.BEFORE_INSERT;

		cleanDispatcher.run();
		Test.stopTest();

		Assert.areEqual(1, postActionInvocationCount, 'The subsequent clean dispatch must fire post-actions exactly once');
		Assert.areEqual(new Set<SObjectType> {Account.SObjectType}, capturedTouchedTypes,
				'The aborted dispatch must have cleared touched types; the clean dispatch delivers only its own object, not the prior Foobar');
	}

	/**
	 * @description Verifies the dispatcher accumulates the dispatched object's `SObjectType` and
	 * delivers it to the post-action via `IF_Trigger.PostActionContext.touchedSObjectTypes`.
	 *
	 * @see TRG_Dispatcher
	 * @see IF_Trigger.PostActionContext
	 */
	@IsTest
	private static void shouldDeliverTouchedSObjectTypesToPostActionContext()
	{
		registerSinglePostAction();

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt>()
		};

		Test.startTest();
		FACTORY_TRIGGER_ACTION.run();
		Test.stopTest();

		Assert.areEqual(1, postActionInvocationCount, 'Post-action should fire once on a clean dispatch');
		Assert.areEqual(new Set<SObjectType> {Foobar__c.SObjectType}, capturedTouchedTypes,
				'The dispatched object type should be delivered to the post-action context');
	}

	/**
	 * @description Verifies the hook consults the selector but fires nothing when no post-actions
	 * are configured (empty selector result). The dispatch completes without error.
	 *
	 * @see TRG_Dispatcher
	 * @see SEL_PostTriggerAction.findActiveOrdered
	 */
	@IsTest
	private static void shouldConsultSelectorButFireNothingWhenNoPostActionsConfigured()
	{
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt>();
		postActionInvocationCount = 0;
		capturedTouchedTypes = null;

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt>()
		};

		Test.startTest();
		FACTORY_TRIGGER_ACTION.run();
		Test.stopTest();

		Assert.areEqual(0, postActionInvocationCount,
				'No configured post-actions → nothing executes, and the dispatch completes without error');
	}

	/**
	 * @description Verifies an unresolvable object name is dropped fail-soft from the touched-type
	 * set rather than breaking dispatch. The post-action still fires; the delivered touched-type
	 * set is empty because the bogus name does not resolve via `UTIL_SObjectDescribe`.
	 *
	 * @see TRG_Dispatcher
	 * @see UTIL_SObjectDescribe.getSObjectTypeByName
	 */
	@IsTest
	private static void shouldDropUnresolvableSObjectNameFromTouchedTypesFailSoft()
	{
		registerSinglePostAction();

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};
		FACTORY_TRIGGER_ACTION.sObjectName = 'NoSuchObject__x';
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.AFTER_INSERT;
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.AFTER_INSERT => new List<TriggerAction__mdt>()
		};

		Test.startTest();
		FACTORY_TRIGGER_ACTION.run();
		Test.stopTest();

		Assert.areEqual(1, postActionInvocationCount,
				'An unresolvable object name must not break dispatch; the post-action still fires');
		Assert.isTrue(capturedTouchedTypes.isEmpty(),
				'An unresolvable object name must be dropped fail-soft, leaving the delivered touched-type set empty');
	}

	/**
	 * @description Verifies the post-trigger-action hook is suppressed when the dispatch is the
	 * framework's own `LogEntryEvent__e` delivery. Persisting a log entry is itself a dispatch, so
	 * firing the hook on each delivered log event would re-enter the dispatcher and, should the
	 * hook path emit any further log event, self-feed a logging cascade (one log write fanning out
	 * into ~120). The companion `shouldDeliverTouchedSObjectTypesToPostActionContext` proves the
	 * hook DOES fire for a normal object, so this isolates the `LogEntryEvent__e` suppression.
	 *
	 * @see TRG_Dispatcher.run
	 */
	@IsTest
	private static void shouldSuppressPostActionsForFrameworkLogEntryEventDispatch()
	{
		registerSinglePostAction();

		LogEntryEvent__e logEvent = (LogEntryEvent__e)TST_Builder.of(LogEntryEvent__e.SObjectType)
				.withoutInsertion()
				.build();
		FACTORY_TRIGGER_ACTION.triggerNew = new List<LogEntryEvent__e> {logEvent};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.AFTER_INSERT;
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.AFTER_INSERT => new List<TriggerAction__mdt>()
		};

		Test.startTest();
		FACTORY_TRIGGER_ACTION.run();
		Test.stopTest();

		Assert.areEqual(0, postActionInvocationCount,
				'The post-trigger-action hook must be suppressed for the framework LogEntryEvent__e dispatch to prevent a logging re-entrancy cascade');
	}

	/**
	 * @description Teardown-protection guard: an exception escaping the post-trigger-action hook
	 * (here the no-DML contract guard's `PostActionDmlException`) must NOT skip
	 * `LOG_Engine.endEventTriggerContext()` in `run()`'s `finally`. Without the protection the
	 * event-trigger context and suspended saving stay set for the rest of the transaction and the
	 * buffered in-context logs never flush; on a platform-event subscriber trigger the escaping
	 * exception also fails delivery, which the platform retries and can ultimately suspend.
	 *
	 * All post-conditions are observed through public logging behaviour: the hook's exception still
	 * surfaces out of `run()` (never swallowed: platform-event retry semantics depend on it), the
	 * buffer drains into a persisted `LogEntry__c` row, and once the context is torn down a
	 * follow-up ERROR emit no longer persists via direct DML while a follow-up DEBUG emit is no
	 * longer buffered.
	 *
	 * @see TRG_Dispatcher.run
	 * @see LOG_Engine.endEventTriggerContext
	 * @see UTIL_PostTriggerAction
	 */
	@IsTest
	private static void shouldTearDownEventTriggerContextAndFlushBufferWhenPostActionThrows()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		wasLoggingActionCalled = false;
		dmlOncePostActionHasExecuted = false;
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt>
		{
				(PostTriggerAction__mdt)TST_Builder.of(PostTriggerAction__mdt.SObjectType)
						.withOverride(PostTriggerAction__mdt.DeveloperName, 'TestDispatcherDmlOncePostAction')
						.withOverride(PostTriggerAction__mdt.ApexClassName__c, TEST_DML_ONCE_POST_ACTION)
						.withOverride(PostTriggerAction__mdt.Order__c, 10)
						.withOverride(PostTriggerAction__mdt.FailureAction__c, FAILURE_LOG_AND_CONTINUE)
						.withoutInsertion()
						.build()
		};

		TriggerAction__mdt loggingAction = TST_Factory.newTriggerActionForContext(
				TEST_LOGGING_AFTER_INSERT, TRIGGER_SETTING, TriggerOperation.AFTER_INSERT);

		FACTORY_TRIGGER_ACTION.triggerNew = new List<SObject> {new AccountChangeEvent()};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.AFTER_INSERT;
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.AFTER_INSERT => new List<TriggerAction__mdt> {loggingAction}
		};

		Test.startTest();
		try
		{
			FACTORY_TRIGGER_ACTION.run();
			Assert.fail('The post-action DML-guard exception must surface out of run(); the teardown protection must never swallow it');
		}
		catch(UTIL_Exceptions.PostActionDmlException expected)
		{
			Assert.isTrue(wasLoggingActionCalled, 'Precondition: the in-context log must have been emitted (and buffered) before the hook threw');
		}
		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getBufferSize(),
				'Buffered in-context logs must flush when the post-action hook throws; the protected teardown owns the flush');

		Assert.isTrue(isLoggingActionEntryPersisted(), 'The buffered action log must persist via direct DML when the throwing hook unwinds: flushed, not dropped');

		LOG_Builder.ignoreTestMode = false;
		Integer rowCountBeforeErrorEmit = new SEL_LogEntry().getAll().size();
		LOG_Builder.build().error('post-run emit probing event-trigger context teardown').emit();
		Assert.areEqual(rowCountBeforeErrorEmit, new SEL_LogEntry().getAll().size(),
				'Event-trigger context must be torn down after run(); an ERROR emitted afterwards must not persist via direct DML');

		LOG_Builder.build().debug('post-run emit probing suspended-saving restore').emit();
		Assert.areEqual(0, LOG_Engine.getBufferSize(),
				'Suspended saving must be restored after run(); an emit after the dispatch must not be buffered');
	}

	/**
	 * @description Registers a single post-trigger action row (pointing at `TestPostAction`) via
	 * the selector's test override and resets the invocation tally + captured-types capture. Lets the
	 * outermost-unwind tests assert firing behaviour without deploying real `PostTriggerAction__mdt`.
	 */
	private static void registerSinglePostAction()
	{
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt>
		{
				(PostTriggerAction__mdt)TST_Builder.of(PostTriggerAction__mdt.SObjectType)
						.withOverride(PostTriggerAction__mdt.DeveloperName, 'TestDispatcherPostAction')
						.withOverride(PostTriggerAction__mdt.ApexClassName__c, POST_ACTION)
						.withOverride(PostTriggerAction__mdt.Order__c, 10)
						.withOverride(PostTriggerAction__mdt.FailureAction__c, FAILURE_LOG_AND_CONTINUE)
						.withoutInsertion()
						.build()
		};
		postActionInvocationCount = 0;
		capturedTouchedTypes = null;
	}

	/**
	 * @description Mock implementation for before delete trigger action
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	public class TestBeforeDelete implements IF_Trigger.BeforeDelete
	{
		/**
		 * @description Sets wasBeforeDeleteCalled so the test can prove the dispatcher reached the before-delete callback.
		 *
		 * @param triggerOld The records about to be deleted; unused.
		 */
		public void beforeDelete(List<SObject> triggerOld)
		{
			TRG_Dispatcher_TEST.wasBeforeDeleteCalled = true;
		}
	}

	/**
	 * @description Mock implementation for after delete trigger action
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	public class TestAfterDelete implements IF_Trigger.AfterDelete
	{
		/**
		 * @description Sets wasAfterDeleteCalled so the test can prove the dispatcher reached the after-delete callback.
		 *
		 * @param triggerOld The deleted records; unused.
		 */
		public void afterDelete(List<SObject> triggerOld)
		{
			TRG_Dispatcher_TEST.wasAfterDeleteCalled = true;
		}
	}

	/**
	 * @description Mock implementation for after undelete trigger action
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	public class TestAfterUndelete implements IF_Trigger.AfterUndelete
	{
		/**
		 * @description Sets wasAfterUndeleteCalled so the test can prove the dispatcher reached the after-undelete callback.
		 *
		 * @param triggerNew The restored records; unused.
		 */
		public void afterUndelete(List<SObject> triggerNew)
		{
			TRG_Dispatcher_TEST.wasAfterUndeleteCalled = true;
		}
	}

	/**
	 * @description Mock Apex action for mixed-stack tests. Sets `Foobar__c.Name` to a known
	 * literal so tests can prove (a) the Apex side of a mixed dispatch ran, and (b) Apex
	 * mutations and flow output write-back co-exist on the same trigger record after dispatch.
	 */
	public class TestMixedApexBeforeInsert implements IF_Trigger.BeforeInsert
	{
		/**
		 * @description Sets wasMixedApexBeforeInsertCalled and writes MIXED_APEX_NAME_VALUE into every record's Name, leaving a
		 * visible Apex mutation beside the flow's write-back.
		 *
		 * @param triggerNew The records about to be inserted.
		 */
		public void beforeInsert(List<SObject> triggerNew)
		{
			TRG_Dispatcher_TEST.wasMixedApexBeforeInsertCalled = true;
			for(SObject record : triggerNew)
			{
				record.put(Foobar__c.Name, TRG_Dispatcher_TEST.MIXED_APEX_NAME_VALUE);
			}
		}
	}

	/**
	 * @description Verifies the dispatcher resolves a flow action to the framework's built-in
	 * flow runner when a TriggerAction row leaves Apex Class Name blank and populates Flow Name.
	 * Subscribers configuring flow actions never see the implementation class name; the
	 * dispatcher routes through it transparently.
	 */
	@IsTest
	private static void shouldResolveToFlowRunnerWhenApexClassBlankAndFlowNameSet()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TST_InvokeFlowMock.forFlow('TRG_Dispatcher_TEST_FlowResolveCheck').succeed().register();

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext
				(
						TRG_InvokeFlow.class.getName(),
						TRIGGER_SETTING,
						TriggerOperation.BEFORE_INSERT
				);
		triggerAction.ApexClassName__c = null;
		triggerAction.FlowName__c = 'TRG_Dispatcher_TEST_FlowResolveCheck';
		triggerAction.FailureAction__c = FAILURE_LOG_AND_CONTINUE;

		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {record};
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();
		FACTORY_TRIGGER_ACTION.run();
		Test.stopTest();

		TST_InvokeFlowMock.assertInvoked('TRG_Dispatcher_TEST_FlowResolveCheck', 1);
	}

	/**
	 * @description Verifies an Apex action that throws an unhandled exception under the
	 * `LogAndContinue` policy: the dispatcher emits a structured `LogEntryEvent__e` and
	 * lets the trigger transaction proceed without rethrowing. Confirms the generalised
	 * failure-action pipeline applies to Apex actions, not just flow actions.
	 */
	@IsTest
	private static void shouldLogAndContinueWhenApexActionThrowsUnderLogAndContinuePolicy()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext
				(
						THROWING_ACTION,
						TRIGGER_SETTING,
						TriggerOperation.BEFORE_INSERT
				);
		triggerAction.FailureAction__c = FAILURE_LOG_AND_CONTINUE;

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();
		FACTORY_TRIGGER_ACTION.run();
		Test.stopTest();

		Assert.isTrue(wasThrowingActionCalled, 'Throwing action should have been invoked');
	}

	/**
	 * @description Verifies an Apex action that throws an unhandled exception under the
	 * `BlockDml` policy: the dispatcher emits a structured `LogEntryEvent__e` and rethrows
	 * the original exception so the trigger transaction rolls back.
	 */
	@IsTest
	private static void shouldRethrowWhenApexActionThrowsUnderBlockDmlPolicy()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext
				(
						THROWING_ACTION,
						TRIGGER_SETTING,
						TriggerOperation.BEFORE_INSERT
				);
		triggerAction.FailureAction__c = FAILURE_BLOCK_DML;

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();
		try
		{
			FACTORY_TRIGGER_ACTION.run();
			Assert.fail('BlockDml policy should rethrow the action exception');
		}
		catch(IllegalArgumentException rethrown)
		{
			Assert.areEqual(THROWING_ACTION_MESSAGE, rethrown.getMessage(), 'Original exception should propagate unmodified');
		}
		Test.stopTest();
	}

	/**
	 * @description Verifies governor-class exceptions always rethrow regardless of
	 * `FailureAction__c`: exhaustion is never swallowed. Drives the rethrow branch
	 * through the `simulateFatalGovernorErrorForTest` test override so the test does not
	 * depend on consuming a real governor limit.
	 */
	@IsTest
	private static void shouldRethrowGovernorErrorRegardlessOfFailureActionPolicy()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext
				(
						THROWING_ACTION,
						TRIGGER_SETTING,
						TriggerOperation.BEFORE_INSERT
				);
		triggerAction.FailureAction__c = FAILURE_LOG_AND_CONTINUE;

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;
		UTIL_Exceptions.simulateFatalGovernorErrorForTest = true;

		Test.startTest();
		try
		{
			FACTORY_TRIGGER_ACTION.run();
			Assert.fail('Fatal governor error should always rethrow even under LogAndContinue');
		}
		catch(IllegalArgumentException rethrown)
		{
			Assert.areEqual(THROWING_ACTION_MESSAGE, rethrown.getMessage(), 'Original exception should propagate unmodified');
		}
		finally
		{
			UTIL_Exceptions.simulateFatalGovernorErrorForTest = false;
		}
		Test.stopTest();
	}

	/**
	 * @description Verifies the dispatcher defaults a blank `FailureAction__c` to
	 * `LogAndContinue`, matching the picklist default. Existing CMDT rows that pre-date
	 * the failure-action field continue to dispatch without throwing on action failure.
	 */
	@IsTest
	private static void shouldDefaultFailureActionToLogAndContinueWhenBlank()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext
				(
						THROWING_ACTION,
						TRIGGER_SETTING,
						TriggerOperation.BEFORE_INSERT
				);
		triggerAction.FailureAction__c = null;

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();
		FACTORY_TRIGGER_ACTION.run();
		Test.stopTest();

		Assert.isTrue(wasThrowingActionCalled, 'Throwing action should have been invoked under default policy');
	}

	/**
	 * @description Verifies the dispatcher surfaces a clear `ConfigurationException` when a
	 * TriggerAction row reaches `resolveClassName` with both ApexClassName and FlowName blank.
	 * The MutuallyExclusiveTarget validation rule normally blocks this configuration at deploy
	 * time, but defensive coding surfaces a configuration-error message rather than letting
	 * the dispatcher NPE downstream when subscribers bypass the VR via Tooling-API insertion.
	 */
	@IsTest
	private static void shouldThrowWhenBothApexClassNameAndFlowNameAreBlank()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext
				(
						THROWING_ACTION,
						TRIGGER_SETTING,
						TriggerOperation.BEFORE_INSERT
				);
		triggerAction.ApexClassName__c = null;
		triggerAction.FlowName__c = null;
		triggerAction.DeveloperName = 'TRG_Dispatcher_TEST_OrphanRow';

		FACTORY_TRIGGER_ACTION.triggerNew = new List<Foobar__c> {DEFAULT_RECORD};
		FACTORY_TRIGGER_ACTION.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		FACTORY_TRIGGER_ACTION.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();
		try
		{
			FACTORY_TRIGGER_ACTION.run();
			Assert.fail('Dispatcher should throw ConfigurationException when both ApexClassName and FlowName are blank');
		}
		catch(UTIL_Exceptions.ConfigurationException error)
		{
			Assert.isTrue(error.getMessage().contains('TRG_Dispatcher_TEST_OrphanRow'),
					'Error should name the offending TriggerAction row. Got: ' + error.getMessage());
			Assert.isTrue(error.getMessage().contains('ApexClassName__c') && error.getMessage().contains('FlowName__c'),
					'Error should reference both fields. Got: ' + error.getMessage());
		}
		Test.stopTest();
	}

	/**
	 * @description Mock implementation that always throws an `IllegalArgumentException` with a
	 * known message. Drives the dispatcher's `handleActionFailure` policy branches:
	 * tests assert the captured exception class and message match the expected propagation
	 * shape (Block DML rethrows; Log and Continue swallows; governor blow always rethrows).
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	public class TestThrowingBeforeInsert implements IF_Trigger.BeforeInsert
	{
		/**
		 * @description Sets wasThrowingActionCalled, then throws an IllegalArgumentException carrying THROWING_ACTION_MESSAGE.
		 *
		 * @param triggerNew The records about to be inserted; unused.
		 *
		 * @throws IllegalArgumentException On every call.
		 */
		public void beforeInsert(List<SObject> triggerNew)
		{
			TRG_Dispatcher_TEST.wasThrowingActionCalled = true;
			throw new IllegalArgumentException(TRG_Dispatcher_TEST.THROWING_ACTION_MESSAGE);
		}
	}

	/**
	 * @description Mock implementation that exercises both `IF_Trigger.Configurable`
	 * and `IF_Trigger.BeforeInsert`. Tallies `setConfig` and `beforeInsert` invocations
	 * keyed by `TriggerAction__mdt.DeveloperName` so tests can assert per-CMDT-row
	 * behaviour, and optionally re-enters the dispatcher from `beforeInsert` to drive
	 * the recursion-shield path.
	 */
	public class TestConfigurable implements IF_Trigger.Configurable, IF_Trigger.BeforeInsert
	{
		/**
		 * @description The configuration row the dispatcher passed to setConfig. beforeInsert reads its
		 * DeveloperName so each call is counted under the row it ran for.
		 */
		private TriggerAction__mdt receivedConfig;

		/**
		 * @description Stores the configuration row, publishes it through configurableLastConfig and tallies the call under its
		 * DeveloperName in CONFIGURABLE_SET_CONFIG_CALLS.
		 *
		 * @param config The TriggerAction__mdt row the dispatcher resolved for this action.
		 */
		public void setConfig(TriggerAction__mdt config)
		{
			this.receivedConfig = config;
			TRG_Dispatcher_TEST.configurableLastConfig = config;
			Integer existingCalls = TRG_Dispatcher_TEST.CONFIGURABLE_SET_CONFIG_CALLS.get(config.DeveloperName) ?? 0;
			TRG_Dispatcher_TEST.CONFIGURABLE_SET_CONFIG_CALLS.put(config.DeveloperName, existingCalls + 1);
		}

		/**
		 * @description Tallies the call under the stored configuration's DeveloperName in CONFIGURABLE_BEFORE_INSERT_CALLS, then
		 * re-enters the dispatcher once when configurableShouldReenter is set, so the recursion shield has a nested
		 * dispatch to refuse.
		 *
		 * @param triggerNew The records about to be inserted; unused.
		 */
		public void beforeInsert(List<SObject> triggerNew)
		{
			String developerName = (this.receivedConfig != null) ? this.receivedConfig.DeveloperName : null;
			Integer existingCalls = TRG_Dispatcher_TEST.CONFIGURABLE_BEFORE_INSERT_CALLS.get(developerName) ?? 0;
			TRG_Dispatcher_TEST.CONFIGURABLE_BEFORE_INSERT_CALLS.put(developerName, existingCalls + 1);

			if(TRG_Dispatcher_TEST.configurableShouldReenter)
			{
				TRG_Dispatcher_TEST.configurableShouldReenter = false;
				TRG_Dispatcher_TEST.FACTORY_TRIGGER_ACTION.run();
			}
		}
	}

	/**
	 * @description Mock `IF_Trigger.PostAction` injected via `SEL_PostTriggerAction.overrideRows`
	 * so the dispatcher's outermost-unwind hook drives it. Records each invocation and captures the
	 * delivered `touchedSObjectTypes` so tests can assert firing count and accumulated object types.
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	public class TestPostAction implements IF_Trigger.PostAction
	{
		/**
		 * @description Counts the invocation in postActionInvocationCount and captures the delivered touched SObject types in
		 * capturedTouchedTypes.
		 *
		 * @param context The post-action context carrying the touched SObject types.
		 */
		public void execute(IF_Trigger.PostActionContext context)
		{
			TRG_Dispatcher_TEST.postActionInvocationCount++;
			TRG_Dispatcher_TEST.capturedTouchedTypes = context.touchedSObjectTypes;
		}
	}

	/**
	 * @description Mock `IF_Trigger.PostAction` that performs synchronous DML on its FIRST
	 * execution only, tripping the hook's no-DML contract guard exactly once. The teardown-protection
	 * test needs the hook to throw at the outermost unwind of the change-event dispatch, yet run
	 * clean during the nested `LogEntry__c` dispatch fired by the protected teardown's buffered-log
	 * persist: a second guard trip there would roll back the persisted rows the test asserts on.
	 */
	public class TestDmlOncePostAction implements IF_Trigger.PostAction
	{
		/**
		 * @description Issues one insert through the framework DML layer on the first invocation and returns without acting on every
		 * later one, so the no-DML guard trips exactly once.
		 *
		 * @param context The post-action context; unused.
		 */
		public void execute(IF_Trigger.PostActionContext context)
		{
			if(TRG_Dispatcher_TEST.dmlOncePostActionHasExecuted)
			{
				return;
			}
			TRG_Dispatcher_TEST.dmlOncePostActionHasExecuted = true;
			// Issue a DML statement through the framework DML layer for the no-DML guard to detect.
			// allowPartial() makes the insert all-or-none = false, so a row-level failure (a subscriber
			// validation rule, FLS, org storage) returns a failed result instead of throwing out of
			// execute() before the guard's Limits.getDmlStatements() check runs. The statement still
			// counts, so the guard surfaces PostActionDmlException as designed. The record is the package's
			// own Foobar__c, because a subscriber org's rules can refuse a standard object such as Account.
			DML_Builder.newTransaction()
					.doInsert(TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build())
					.allowPartial()
					.suppressLogging()
					.execute();
		}
	}
}