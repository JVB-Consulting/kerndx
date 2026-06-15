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
 * @date February 2026, June 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class TRG_Dispatcher_TEST
{
	private static final String BOGUS_CLASS_NAME = 'Bogus';
	private static final String DEFAULT_RECORD_NAME = 'My Record';
	private static final String MSG_EXCEPTION_EXPECTED = 'Expected an exception to be thrown';
	private static final String TEST_AFTER_DELETE = TRG_Dispatcher_TEST.class.getName() + '.TestAfterDelete';
	private static final String TEST_AFTER_INSERT = TRG_Dispatcher_TEST.class.getName() + '.TestAfterInsert';
	private static final String TEST_AFTER_UNDELETE = TRG_Dispatcher_TEST.class.getName() + '.TestAfterUndelete';
	private static final String TEST_AFTER_UPDATE = TRG_Dispatcher_TEST.class.getName() + '.TestAfterUpdate';
	private static final String TEST_BEFORE_DELETE = TRG_Dispatcher_TEST.class.getName() + '.TestBeforeDelete';
	private static final String TEST_BEFORE_INSERT = TRG_Dispatcher_TEST.class.getName() + '.TestBeforeInsert';
	private static final String TEST_BEFORE_UPDATE = TRG_Dispatcher_TEST.class.getName() + '.TestBeforeUpdate';
	private static final String TEST_CONFIGURABLE = TRG_Dispatcher_TEST.class.getName() + '.TestConfigurable';
	private static final String TEST_LOGGING_AFTER_INSERT = TRG_Dispatcher_TEST.class.getName() + '.LoggingAfterInsert';
	private static final String LOGGING_ACTION_FINGERPRINT = 'trg-dispatcher-test-logging-action';
	private static final String MIXED_APEX_ACTION = TRG_Dispatcher_TEST.class.getName() + '.TestMixedApexBeforeInsert';
	private static final String MIXED_FLOW_ACTION = TRG_InvokeFlow.class.getName();
	private static final String MIXED_FLOW_NAME = 'TRG_Dispatcher_TEST_MixedStackFlow';
	private static final String MIXED_APEX_NAME_VALUE = 'mixed-apex-mutated';
	private static final String MIXED_FLOW_TEXTAREA_VALUE = 'mixed-flow-mutated';
	private static final String THROWING_ACTION = TRG_Dispatcher_TEST.class.getName() + '.TestThrowingBeforeInsert';
	private static final String THROWING_ACTION_MESSAGE = 'Test action threw on purpose';
	private static final String FAILURE_LOG_AND_CONTINUE = 'LogAndContinue';
	private static final String FAILURE_BLOCK_DML = 'BlockDml';

	private static final Foobar__c DEFAULT_RECORD = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
			.withOverride(Foobar__c.Name, DEFAULT_RECORD_NAME)
			.withOverride(Foobar__c.Id, UTIL_Random.randomId(Foobar__c.SObjectType))
			.withoutInsertion()
			.build();

	private static final TRG_Dispatcher FACTORY_TRIGGER_ACTION = new TRG_Dispatcher();

	private static final TriggerSetting__mdt TRIGGER_SETTING = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

	private static Boolean wasAfterDeleteCalled = false;
	private static Boolean wasAfterInsertCalled = false;
	private static Boolean wasAfterUndeleteCalled = false;
	private static Boolean wasAfterUpdateCalled = false;
	private static Boolean wasBeforeDeleteCalled = false;
	private static Boolean wasBeforeInsertCalled = false;
	private static Boolean wasBeforeUpdateCalled = false;
	private static Boolean wasThrowingActionCalled = false;
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
	 * @description Tally for mixed-action-stack tests — flipped to true by `TestMixedApexBeforeInsert`
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
	 * @description Count of `TestPostAction.execute` invocations in the current transaction.
	 * Reset by `registerSinglePostAction`. The outermost-unwind hook must drive this to exactly
	 * one per top-level dispatch that completes normally — and to zero when the dispatch aborts.
	 */
	private static Integer postActionInvocationCount = 0;
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
		TST_Factory.setupLoggerForTest(false, 0, false, 0, false, 500);

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
		TST_Factory.setupLoggerForTest(false, 0, false, 0, true, 0);

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
		TST_Factory.setupLoggerForTest(false, 0, false, 0, true, 999999);

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
		TST_Factory.setupLoggerForTest(false, 0, false, 0, true, 0);

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
	 * @description Mock implementation for before insert trigger action
	 */
	@SuppressWarnings('PMD.ApexDoc, ApexUnusedDeclaration')
	public class TestBeforeInsert implements IF_Trigger.BeforeInsert
	{
		public void beforeInsert(List<SObject> triggerNew)
		{
			TRG_Dispatcher_TEST.wasBeforeInsertCalled = true;
		}
	}

	/**
	 * @description Mock implementation for after insert trigger action
	 */
	@SuppressWarnings('PMD.ApexDoc, ApexUnusedDeclaration')
	public class TestAfterInsert implements IF_Trigger.AfterInsert
	{
		public void afterInsert(List<SObject> triggerNew)
		{
			TRG_Dispatcher_TEST.wasAfterInsertCalled = true;
		}
	}

	/**
	 * @description Mock after-insert action that emits a fingerprinted DEBUG log — the real
	 * skip-log shape that floods under change-event redelivery — simulating an action that logs
	 * while the dispatcher is processing a change-event / platform-event. DEBUG exercises the
	 * buffered branch end-to-end (begin suspends saving, the emit buffers, the dispatch-boundary
	 * flush persists via DML). Used by `changeEventDispatchPersistsActionLogsViaDmlWithoutPublishing`
	 * to prove the dispatcher enters event-trigger context so the log persists via DML rather than
	 * republishing and looping.
	 */
	@SuppressWarnings('PMD.ApexDoc, ApexUnusedDeclaration')
	public class LoggingAfterInsert implements IF_Trigger.AfterInsert
	{
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
	@SuppressWarnings('PMD.ApexDoc, ApexUnusedDeclaration')
	public class TestBeforeUpdate implements IF_Trigger.BeforeUpdate
	{
		public void beforeUpdate(List<SObject> triggerNew, List<SObject> triggerOld)
		{
			TRG_Dispatcher_TEST.wasBeforeUpdateCalled = true;
		}
	}

	/**
	 * @description Mock implementation for after update trigger action
	 */
	@SuppressWarnings('PMD.ApexDoc, ApexUnusedDeclaration')
	public class TestAfterUpdate implements IF_Trigger.AfterUpdate
	{
		public void afterUpdate(List<SObject> triggerNew, List<SObject> triggerOld)
		{
			TRG_Dispatcher_TEST.wasAfterUpdateCalled = true;
		}
	}

	/**
	 * @description Tests that `applyMaskingIfConfigured` invokes a `UTIL_MaskerPerformanceTimer`
	 * when all three gates pass: BEFORE_INSERT context, masking framework enabled, and the
	 * object's TriggerSetting permits masking. Asserts that the timer's per-transaction counter
	 * increments when logging is configured to emit — proving the timer is actually driven by
	 * the dispatcher, not just instantiated.
	 */
	@IsTest
	private static void shouldDriveMaskerPerformanceTimerWhenMaskingConfigured()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0, false, 0, false, 500);
		LOG_Engine.logSettingOverride.EnableMaskerPerformanceLogging__c = true;
		LOG_Engine.logSettingOverride.MaskerPerformanceThresholdMs__c = 0;

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
	 * off. Asserts the timer's per-transaction counter stays at zero — proving the dispatcher
	 * skips masking (and its timer) when subscribers have disabled the framework.
	 */
	@IsTest
	private static void shouldSkipMaskerTimerWhenMaskingFrameworkDisabled()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0, false, 0, false, 500);
		LOG_Engine.logSettingOverride.EnableMaskerPerformanceLogging__c = true;
		LOG_Engine.logSettingOverride.MaskerPerformanceThresholdMs__c = 0;

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
	 * via direct DML — NOT published as a `LogEntryEvent__e`. Publishing a platform event from inside
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
		Integer publishBefore = Limits.getPublishImmediateDML();
		FACTORY_TRIGGER_ACTION.run();
		Integer publishAfter = Limits.getPublishImmediateDML();
		Test.stopTest();

		Assert.isTrue(wasLoggingActionCalled, 'The logging action should have executed during the change-event dispatch');
		Assert.areEqual(publishBefore, publishAfter,
				'A log emitted during a change-event dispatch must persist via DML, never publish (no redelivery loop)');

		String detailKey = TRG_PersistLogEntry.PREFIX_DETAIL + LOGGING_ACTION_FINGERPRINT;
		Boolean detailFound = false;
		for(LogEntry__c row : new SEL_LogEntry().getAll())
		{
			if(detailKey.equals(row.Fingerprint__c))
			{
				detailFound = true;
			}
		}
		Assert.isTrue(detailFound, 'The action log must persist via direct DML during change-event dispatch');
	}

	/**
	 * @description Verifies the dispatcher invokes `IF_Trigger.Configurable.setConfig`
	 * before the trigger interface method (`beforeInsert`), passing the exact
	 * `TriggerAction__mdt` row injected via `actionMetadataOverride`. Guards the
	 * Configurable hook contract: ordering (`setConfig` before `beforeInsert`), one-shot
	 * semantics (one `setConfig` per CMDT row), and identity (the same record reference
	 * reaches the action — not a copy or transformation).
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
	 * `fingerprintsMatch` by exercising the legacy frame shape — non-Configurable
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
	 * @description Verifies a mixed Apex+Flow action stack — Apex action ordered first, Flow
	 * action ordered second — runs both, with the flow's output write-back applied to the
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
	 * dispatcher continues to subsequent actions in the same trigger context — the dispatch
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
	 * the outermost and must not fire. Only the outer unwind — when `ACTION_STACK` is empty —
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
	 * object type — proving the aborted dispatch cleared `touchedSObjectTypes` (no stale-state
	 * leak across top-level DML when an Apex caller catches the failure and continues).
	 *
	 * The abort is driven through the fatal-governor simulation seam so the rethrow happens before
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
				'The aborted dispatch must have cleared touched types — the clean dispatch delivers only its own object, not the prior Foobar');
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
				'An unresolvable object name must not break dispatch — the post-action still fires');
		Assert.isTrue(capturedTouchedTypes.isEmpty(),
				'An unresolvable object name must be dropped fail-soft, leaving the delivered touched-type set empty');
	}

	/**
	 * @description Verifies the post-trigger-action hook is suppressed when the dispatch is the
	 * framework's own `LogEntryEvent__e` delivery. Persisting a log entry is itself a dispatch, so
	 * firing the hook on each delivered log event would re-enter the dispatcher and — should the
	 * hook path emit any further log event — self-feed a logging cascade (one log write fanning out
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
	 * @description Registers a single post-trigger action row (pointing at `TestPostAction`) via
	 * the selector override seam and resets the invocation tally + captured-types capture. Lets the
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
	@SuppressWarnings('PMD.ApexDoc, ApexUnusedDeclaration')
	public class TestBeforeDelete implements IF_Trigger.BeforeDelete
	{
		public void beforeDelete(List<SObject> triggerOld)
		{
			TRG_Dispatcher_TEST.wasBeforeDeleteCalled = true;
		}
	}

	/**
	 * @description Mock implementation for after delete trigger action
	 */
	@SuppressWarnings('PMD.ApexDoc, ApexUnusedDeclaration')
	public class TestAfterDelete implements IF_Trigger.AfterDelete
	{
		public void afterDelete(List<SObject> triggerOld)
		{
			TRG_Dispatcher_TEST.wasAfterDeleteCalled = true;
		}
	}

	/**
	 * @description Mock implementation for after undelete trigger action
	 */
	@SuppressWarnings('PMD.ApexDoc, ApexUnusedDeclaration')
	public class TestAfterUndelete implements IF_Trigger.AfterUndelete
	{
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
	@SuppressWarnings('PMD.ApexDoc, ApexUnusedDeclaration')
	public class TestMixedApexBeforeInsert implements IF_Trigger.BeforeInsert
	{
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
	 * Subscribers configuring flow actions never see the implementation class name — the
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
	 * `FailureAction__c` — exhaustion is never swallowed. Drives the rethrow branch
	 * through the `simulateFatalGovernorErrorForTest` seam so the test does not
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
	 * known message. Drives the dispatcher's `handleActionFailure` policy branches —
	 * tests assert the captured exception class and message match the expected propagation
	 * shape (Block DML rethrows; Log and Continue swallows; governor blow always rethrows).
	 */
	@SuppressWarnings('PMD.ApexDoc, ApexUnusedDeclaration')
	public class TestThrowingBeforeInsert implements IF_Trigger.BeforeInsert
	{
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
	@SuppressWarnings('PMD.ApexDoc, ApexUnusedDeclaration')
	public class TestConfigurable implements IF_Trigger.Configurable, IF_Trigger.BeforeInsert
	{
		private TriggerAction__mdt receivedConfig;

		public void setConfig(TriggerAction__mdt config)
		{
			this.receivedConfig = config;
			TRG_Dispatcher_TEST.configurableLastConfig = config;
			Integer existingCalls = TRG_Dispatcher_TEST.CONFIGURABLE_SET_CONFIG_CALLS.get(config.DeveloperName) ?? 0;
			TRG_Dispatcher_TEST.CONFIGURABLE_SET_CONFIG_CALLS.put(config.DeveloperName, existingCalls + 1);
		}

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
	@SuppressWarnings('PMD.ApexDoc, ApexUnusedDeclaration')
	public class TestPostAction implements IF_Trigger.PostAction
	{
		public void execute(IF_Trigger.PostActionContext context)
		{
			TRG_Dispatcher_TEST.postActionInvocationCount++;
			TRG_Dispatcher_TEST.capturedTouchedTypes = context.touchedSObjectTypes;
		}
	}
}