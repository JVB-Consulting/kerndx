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
 * @description Test the behaviour of the base object
 * adapted from:[apex-trigger-actions-framework](https://github.com/mitchspano/apex-trigger-actions-framework/blob/master/README.md#metadata-driven-trigger-actions)
 *
 * @see TRG_Base
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
@IsTest(SeeAllData=false IsParallel=true)
private class TRG_Base_TEST
{
	private static final String OBJECT_NAME = SEL_Foobar.OBJECT_NAME;

	/**
	 * @description Tests that before execution of trigger works as expected
	 *
	 * @see IF_Trigger.BeforeInsert
	 */
	@IsTest
	private static void beforeInsert()
	{
		assertTriggerExecuted(TriggerOperation.BEFORE_INSERT);
	}

	/**
	 * @description Checks that the trigger execute for the given operation
	 *
	 * @param operation The operation to simulate
	 */
	private static void assertTriggerExecuted(TriggerOperation operation)
	{
		TestTriggerAction testAction = setupTestConditions(operation);

		Test.startTest();

		testAction.run();

		Test.stopTest();

		Assert.isTrue(testAction.hasBeenExecuted, 'Trigger Action was not executed');
	}

	/**
	 * @description Will setup the relevant test data and object for executing trigger action
	 *
	 * @param operation The trigger operation to configure for
	 *
	 * @return Initialized Test Trigger Action
	 */
	private static TestTriggerAction setupTestConditions(TriggerOperation operation)
	{
		Foobar__c newFoobar = TST_Factory.newFoobar();
		newFoobar.Id = operation == TriggerOperation.BEFORE_INSERT ? null : UTIL_Random.randomId(Foobar__c.SObjectType);

		List<SObject> newFoobars = new List<SObject> {newFoobar};

		TestTriggerAction testAction = new TestTriggerAction();

		testAction.context = operation;

		switch on operation
		{
			when BEFORE_INSERT, AFTER_INSERT, AFTER_DELETE, BEFORE_DELETE
			{
				testAction.triggerNew = newFoobars;
			}
			when else
			{
				testAction.triggerNew = newFoobars;
				testAction.triggerOld = newFoobars;
			}
		}

		return testAction;
	}

	/**
	 * @description Tests that before execution of trigger works as expected
	 *
	 * @see IF_Trigger.AfterInsert
	 */
	@IsTest
	private static void afterInsert()
	{
		assertTriggerExecuted(TriggerOperation.AFTER_INSERT);
	}

	/**
	 * @description Tests that before execution of trigger works as expected
	 *
	 * @see IF_Trigger.BeforeUpdate
	 */
	@IsTest
	private static void beforeUpdate()
	{
		assertTriggerExecuted(TriggerOperation.BEFORE_UPDATE);
	}

	/**
	 * @description Tests that before execution of trigger works as expected
	 *
	 * @see IF_Trigger.AfterUpdate
	 */
	@IsTest
	private static void afterUpdate()
	{
		assertTriggerExecuted(TriggerOperation.AFTER_UPDATE);
	}

	/**
	 * @description Tests that before execution of trigger works as expected
	 *
	 * @see IF_Trigger.BeforeDelete
	 */
	@IsTest
	private static void beforeDelete()
	{
		assertTriggerExecuted(TriggerOperation.BEFORE_DELETE);
	}

	/**
	 * @description Tests that before execution of trigger works as expected
	 *
	 * @see IF_Trigger.AfterDelete
	 */
	@IsTest
	private static void afterDelete()
	{
		assertTriggerExecuted(TriggerOperation.AFTER_DELETE);
	}

	/**
	 * @description Tests that before execution of trigger works as expected
	 *
	 * @see IF_Trigger.AfterUndelete
	 */
	@IsTest
	private static void afterUndelete()
	{
		assertTriggerExecuted(TriggerOperation.AFTER_UNDELETE);
	}

	/**
	 * @description Will check if the class that's being executed is not support relevant interface
	 */
	@IsTest
	private static void invalidType()
	{
		TRG_Base baseObject = new TRG_Base();

		baseObject.context = TriggerOperation.BEFORE_INSERT;
		baseObject.triggerNew = TST_Factory.newFoobars(1);
		try
		{
			Test.startTest();

			baseObject.run();

			Test.stopTest();

			Assert.fail('Expected an exception to be thrown');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, TypeException.class, 'Invalid Exception Type thrown');
		}
	}

	/**
	 * @description Tests that an exception is thrown when run() is called outside of a trigger context
	 */
	@IsTest
	private static void runFail()
	{
		try
		{
			Test.startTest();

			new TestTriggerAction().run();

			Test.stopTest();

			Assert.fail('Expected an Exception to be thrown');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Incorrect exception type');
			Assert.areEqual(TRG_Base.HANDLER_OUTSIDE_TRIGGER_MESSAGE, error.getMessage(), 'Incorrect exception message');
		}
	}

	/**
	 * @description Checks to see if a trigger is bypassed whether it will run
	 *
	 * @see TRG_Base.bypass
	 * @see TRG_Base.run
	 */
	@IsTest
	private static void bypassed()
	{
		TestTriggerAction testAction = setupTestConditions(TriggerOperation.BEFORE_INSERT);
		TRG_Base.bypass(OBJECT_NAME);

		Test.startTest();

		testAction.run();

		Test.stopTest();

		Assert.isFalse(testAction.hasBeenExecuted, 'Action should not have run');
	}

	/**
	 * @description Checks that an action can be bypassed and bypasses can be cleared based on object
	 *
	 * @see TRG_Base.bypass
	 * @see TRG_Base.clearBypass
	 */
	@IsTest
	private static void bypassOnObject()
	{
		Test.startTest();

		TRG_Base.bypass(OBJECT_NAME);

		Assert.isTrue(TRG_Base.BYPASSED_OBJECTS.contains(OBJECT_NAME), 'Action was not bypassed');

		TRG_Base.clearBypass(OBJECT_NAME);

		Assert.isTrue(TRG_Base.BYPASSED_OBJECTS.isEmpty(), 'Bypass was not cleared');

		Test.stopTest();
	}

	/**
	 * @description Checks to see if an is bypassed
	 *
	 * @see TRG_Base.isBypassed
	 */
	@IsTest
	private static void isBypassed()
	{
		TRG_Base.bypass(OBJECT_NAME);

		Test.startTest();

		Boolean isBypassed = TRG_Base.isBypassed(OBJECT_NAME);

		Test.stopTest();

		Assert.isTrue(isBypassed, 'Action not reported as bypassed');
	}

	/**
	 * @description Checks to see if all bypasses set are cleared
	 *
	 * @see TRG_Base.clearAllBypasses
	 */
	@IsTest
	private static void clearAllBypasses()
	{
		TRG_Base.bypass(OBJECT_NAME);
		Test.startTest();

		TRG_Base.clearAllBypasses();

		Test.stopTest();

		Assert.isTrue(TRG_Base.BYPASSED_OBJECTS.isEmpty(), 'Bypasses not cleared');
	}

	/**
	 * @description Tests that the type-safe bypass overload correctly bypasses trigger actions.
	 *
	 * @see TRG_Base.bypass(SObjectType)
	 */
	@IsTest
	private static void shouldBypassUsingSObjectType()
	{
		TestTriggerAction testAction = setupTestConditions(TriggerOperation.BEFORE_INSERT);

		TRG_Base.bypass(Foobar__c.SObjectType);

		Test.startTest();

		testAction.run();

		Test.stopTest();

		Assert.isFalse(testAction.hasBeenExecuted, 'Action should not have run');
	}

	/**
	 * @description Tests that the type-safe isBypassed overload returns correct status.
	 *
	 * @see TRG_Base.isBypassed(SObjectType)
	 */
	@IsTest
	private static void shouldReportBypassedUsingSObjectType()
	{
		TRG_Base.bypass(Foobar__c.SObjectType);

		Test.startTest();

		Boolean isBypassed = TRG_Base.isBypassed(Foobar__c.SObjectType);

		Test.stopTest();

		Assert.isTrue(isBypassed, 'Action not reported as bypassed');
	}

	/**
	 * @description Tests that the type-safe clearBypass overload clears a bypass set via SObjectType.
	 *
	 * @see TRG_Base.bypass(SObjectType)
	 * @see TRG_Base.clearBypass(SObjectType)
	 */
	@IsTest
	private static void shouldClearBypassUsingSObjectType()
	{
		TRG_Base.bypass(Foobar__c.SObjectType);

		Test.startTest();

		TRG_Base.clearBypass(Foobar__c.SObjectType);

		Test.stopTest();

		Assert.isFalse(TRG_Base.isBypassed(Foobar__c.SObjectType), 'Bypass was not cleared');
	}

	/**
	 * @description Tests that string-based and SObjectType-based bypass APIs are interoperable.
	 *
	 * @see TRG_Base.bypass(SObjectType)
	 * @see TRG_Base.isBypassed(String)
	 */
	@IsTest
	private static void shouldInteroperateBetweenStringAndSObjectType()
	{
		TRG_Base.bypass(Foobar__c.SObjectType);

		Test.startTest();

		Boolean bypassedViaString = TRG_Base.isBypassed(OBJECT_NAME);
		Boolean bypassedViaType = TRG_Base.isBypassed(Foobar__c.SObjectType);

		Test.stopTest();

		Assert.isTrue(bypassedViaString, 'String-based check should detect SObjectType-based bypass');
		Assert.isTrue(bypassedViaType, 'SObjectType-based check should detect SObjectType-based bypass');
	}

	/**
	 * @description Tests that an action can be bypassed and the bypass status is reported correctly
	 *
	 * @see TRG_Base.bypassAction
	 * @see TRG_Base.isActionBypassed
	 */
	@IsTest
	private static void bypassAction()
	{
		Test.startTest();

		TRG_Base.bypassAction(OBJECT_NAME);

		Test.stopTest();

		Assert.isTrue(TRG_Base.isActionBypassed(OBJECT_NAME), 'Action should be bypassed');
	}

	/**
	 * @description Tests that a specific action bypass can be cleared
	 *
	 * @see TRG_Base.bypassAction
	 * @see TRG_Base.clearActionBypass
	 */
	@IsTest
	private static void clearActionBypass()
	{
		TRG_Base.bypassAction(OBJECT_NAME);

		Test.startTest();

		TRG_Base.clearActionBypass(OBJECT_NAME);

		Test.stopTest();

		Assert.isFalse(TRG_Base.isActionBypassed(OBJECT_NAME), 'Action bypass should be cleared');
	}

	/**
	 * @description Tests that all action bypasses can be cleared at once
	 *
	 * @see TRG_Base.bypassAction
	 * @see TRG_Base.clearAllActionBypasses
	 */
	@IsTest
	private static void clearAllActionBypasses()
	{
		TRG_Base.bypassAction(OBJECT_NAME);

		Test.startTest();

		TRG_Base.clearAllActionBypasses();

		Test.stopTest();

		Assert.isFalse(TRG_Base.isActionBypassed(OBJECT_NAME), 'Action bypass should be cleared');
	}

	/**
	 * @description Tests that the triggerOldMap lazy property is accessible
	 *
	 * @see TRG_Base.triggerOldMap
	 */
	@IsTest
	private static void triggerOldMap()
	{
		TestTriggerAction testAction = new TestTriggerAction();

		Foobar__c record = TST_Factory.newFoobar();
		record.Id = UTIL_Random.randomId(Foobar__c.SObjectType);

		testAction.triggerOldMap = new Map<Id, SObject> {record.Id => record};

		Test.startTest();

		Map<Id, SObject> oldMap = testAction.triggerOldMap;

		Test.stopTest();

		Assert.isNotNull(oldMap, 'triggerOldMap should not be null');
		Assert.areEqual(1, oldMap.size(), 'triggerOldMap should contain the record');
	}

	/**
	 * @description Tests that validateSingleRequest passes for exactly one request
	 *
	 * @see TRG_Base.validateSingleRequest
	 */
	@IsTest
	private static void validateSingleRequestPasses()
	{
		try
		{
			Test.startTest();

			TRG_Base.validateSingleRequest(1, 'TestClass');

			Test.stopTest();
		}
		catch(Exception error)
		{
			Assert.fail('validateSingleRequest should not throw for valid size of 1: ' + error.getMessage());
		}
	}

	/**
	 * @description Tests that validateSingleRequest throws for zero requests
	 *
	 * @see TRG_Base.validateSingleRequest
	 */
	@IsTest
	private static void validateSingleRequestFailsForZero()
	{
		try
		{
			Test.startTest();

			TRG_Base.validateSingleRequest(0, 'TestClass');

			Test.stopTest();

			Assert.fail('Expected IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect exception type');
			Assert.isTrue(error.getMessage().contains('TestClass'), 'Error should reference the class name');
		}
	}

	/**
	 * @description Tests that the BypassType-dispatching bypass overload works for OBJECT_NAME.
	 *
	 * @see TRG_Base.bypass
	 */
	@IsTest
	private static void shouldBypassUsingBypassTypeObjectName()
	{
		Test.startTest();

		TRG_Base.bypass(OBJECT_NAME, TRG_Base.BypassType.OBJECT_NAME);

		Test.stopTest();

		Assert.isTrue(TRG_Base.isBypassed(OBJECT_NAME), 'Object should be bypassed');
	}

	/**
	 * @description Tests that the BypassType-dispatching bypass overload works for CLASS_NAME.
	 *
	 * @see TRG_Base.bypass
	 */
	@IsTest
	private static void shouldBypassUsingBypassTypeClassName()
	{
		Test.startTest();

		TRG_Base.bypass('TRG_SetFoobarDefaults', TRG_Base.BypassType.CLASS_NAME);

		Test.stopTest();

		Assert.isTrue(TRG_Base.isActionBypassed('TRG_SetFoobarDefaults'), 'Action should be bypassed');
	}

	/**
	 * @description Tests that the BypassType-dispatching isBypassed overload works for both types.
	 *
	 * @see TRG_Base.isBypassed
	 */
	@IsTest
	private static void shouldCheckBypassedUsingBypassType()
	{
		TRG_Base.bypass(OBJECT_NAME);
		TRG_Base.bypassAction('TRG_SetFoobarDefaults');

		Test.startTest();

		Boolean objectBypassed = TRG_Base.isBypassed(OBJECT_NAME, TRG_Base.BypassType.OBJECT_NAME);
		Boolean actionBypassed = TRG_Base.isBypassed('TRG_SetFoobarDefaults', TRG_Base.BypassType.CLASS_NAME);

		Test.stopTest();

		Assert.isTrue(objectBypassed, 'Object should be bypassed');
		Assert.isTrue(actionBypassed, 'Action should be bypassed');
	}

	/**
	 * @description Tests that the BypassType-dispatching clearBypass overload works for both types.
	 *
	 * @see TRG_Base.clearBypass
	 */
	@IsTest
	private static void shouldClearBypassUsingBypassType()
	{
		TRG_Base.bypass(OBJECT_NAME);
		TRG_Base.bypassAction('TRG_SetFoobarDefaults');

		Test.startTest();

		TRG_Base.clearBypass(OBJECT_NAME, TRG_Base.BypassType.OBJECT_NAME);
		TRG_Base.clearBypass('TRG_SetFoobarDefaults', TRG_Base.BypassType.CLASS_NAME);

		Test.stopTest();

		Assert.isFalse(TRG_Base.isBypassed(OBJECT_NAME), 'Object bypass should be cleared');
		Assert.isFalse(TRG_Base.isActionBypassed('TRG_SetFoobarDefaults'), 'Action bypass should be cleared');
	}

	/**
	 * @description Tests that the BypassType-dispatching clearAllBypasses overload works for both types.
	 *
	 * @see TRG_Base.clearAllBypasses
	 */
	@IsTest
	private static void shouldClearAllBypassesUsingBypassType()
	{
		TRG_Base.bypass(OBJECT_NAME);
		TRG_Base.bypassAction('TRG_SetFoobarDefaults');

		Test.startTest();

		TRG_Base.clearAllBypasses(TRG_Base.BypassType.OBJECT_NAME);
		TRG_Base.clearAllBypasses(TRG_Base.BypassType.CLASS_NAME);

		Test.stopTest();

		Assert.isFalse(TRG_Base.isBypassed(OBJECT_NAME), 'Object bypasses should be cleared');
		Assert.isFalse(TRG_Base.isActionBypassed('TRG_SetFoobarDefaults'), 'Action bypasses should be cleared');
	}

	/**
	 * @description Tests that resolveBypassType returns OBJECT_NAME for valid input
	 *
	 * @see TRG_Base.resolveBypassType
	 */
	@IsTest
	private static void resolveBypassTypeReturnsObjectName()
	{
		Test.startTest();

		TRG_Base.BypassType result = TRG_Base.resolveBypassType('OBJECT_NAME');

		Test.stopTest();

		Assert.areEqual(TRG_Base.BypassType.OBJECT_NAME, result, 'Should return OBJECT_NAME');
	}

	/**
	 * @description Tests that resolveBypassType throws for invalid input
	 *
	 * @see TRG_Base.resolveBypassType
	 */
	@IsTest
	private static void resolveBypassTypeThrowsForInvalid()
	{
		try
		{
			Test.startTest();

			TRG_Base.resolveBypassType('INVALID');

			Test.stopTest();

			Assert.fail('Expected exception for invalid bypass type');
		}
		catch(Exception error)
		{
			Assert.areEqual(TRG_Base.ERROR_INVALID_BYPASS_TYPE, error.getMessage(), 'Should have user-friendly error message');
		}
	}

	/**
	 * @description Class to check the behaviour of a trigger action
	 */
	private class TestTriggerAction extends TRG_Base implements IF_Trigger.BeforeInsert, IF_Trigger.AfterInsert,
			IF_Trigger.BeforeUpdate, IF_Trigger.AfterUpdate, IF_Trigger.BeforeDelete,
			IF_Trigger.AfterDelete, IF_Trigger.AfterUndelete
	{
		/**
		 * @description Indicates if the relevant interface method was called
		 */
		public Boolean hasBeenExecuted = false;

		public void beforeInsert(List<SObject> newList)
		{
			this.hasBeenExecuted = true;
		}

		public void afterInsert(List<SObject> newList)
		{
			this.hasBeenExecuted = true;
		}

		public void beforeUpdate(List<SObject> newList, List<SObject> oldList)
		{
			this.hasBeenExecuted = true;
		}

		public void afterUpdate(List<SObject> newList, List<SObject> oldList)
		{
			this.hasBeenExecuted = true;
		}

		public void beforeDelete(List<SObject> oldList)
		{
			this.hasBeenExecuted = true;
		}

		public void afterDelete(List<SObject> newList)
		{
			this.hasBeenExecuted = true;
		}

		public void afterUndelete(List<SObject> newList)
		{
			this.hasBeenExecuted = true;
		}
	}

	/**
	 * @description Tests that triggerNew and triggerOldMap return null when accessed outside trigger context.
	 */
	@IsTest
	private static void shouldReturnNullForTriggerContextOutsideTrigger()
	{
		TRG_Base handler = new TRG_Base();

		Assert.isNull(handler.triggerNew, 'triggerNew should be null outside trigger context');
		Assert.isNull(handler.triggerOldMap, 'triggerOldMap should be null outside trigger context');
	}

	/**
	 * @description Tests that `setBypassReason` latches a reason string that flows into every
	 * subsequent bypass audit log entry until explicitly cleared.
	 *
	 * @see TRG_Base.setBypassReason
	 */
	@IsTest
	private static void setBypassReasonShouldLatchReasonForAuditLogs()
	{
		LOG_Builder.ignoreTestMode = true;

		TRG_Base.setBypassReason('Customer data migration');
		TRG_Base.bypass(OBJECT_NAME);
		TRG_Base.bypassAction('SomeAction');

		Assert.areEqual('Customer data migration', UTIL_BypassAudit.bypassReason, 'Reason should persist across bypass calls');
		Assert.isTrue(TRG_Base.isBypassed(OBJECT_NAME), 'Object bypass should still take effect');
		Assert.isTrue(TRG_Base.isActionBypassed('SomeAction'), 'Action bypass should still take effect');
	}

	/**
	 * @description Tests that passing a blank reason to `setBypassReason` clears the latched
	 * reason so subsequent audit log entries omit the reason context.
	 *
	 * @see TRG_Base.setBypassReason
	 */
	@IsTest
	private static void setBypassReasonWithNullShouldClearLatchedReason()
	{
		TRG_Base.setBypassReason('Initial');
		TRG_Base.setBypassReason(null);

		Assert.isNull(UTIL_BypassAudit.bypassReason, 'Null reason should clear the latched value');
	}

	/**
	 * @description Tests that `TRG_Base.bypass(SObjectType)` emits a `trigger-object` audit entry
	 * recording the SObject API name as the target. Closes the CAP-055 documented edge case for
	 * the trigger object-bypass surface.
	 *
	 * @see TRG_Base.bypass
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitBypassAuditOnTriggerObjectBypass()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		TRG_Base.bypass(Foobar__c.SObjectType);
		Test.stopTest();

		Map<String, Object> context = findTriggerAuditContext(SEL_Foobar.OBJECT_NAME, UTIL_BypassAudit.SURFACE_TRIGGER_OBJECT);
		Assert.isNotNull(context, 'bypass(SObjectType) should emit a trigger-object audit entry');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
	}

	/**
	 * @description Tests that `TRG_Base.bypassAction(String)` emits a `trigger-action` audit
	 * entry recording the action class name as the target. Closes the CAP-055 documented edge
	 * case for the trigger action-class bypass surface.
	 *
	 * @see TRG_Base.bypassAction
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitBypassAuditOnTriggerActionBypass()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		TRG_Base.bypassAction('TRG_SetFoobarDefaults');
		Test.stopTest();

		Map<String, Object> context = findTriggerAuditContext('TRG_SetFoobarDefaults', UTIL_BypassAudit.SURFACE_TRIGGER_ACTION);
		Assert.isNotNull(context, 'bypassAction should emit a trigger-action audit entry');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
	}

	/**
	 * @description Tests that `TRG_Base.clearBypass(SObjectType)` emits a `trigger-object` audit
	 * entry with the `CLEAR` action. Closes the CAP-055 documented edge case for the per-object
	 * bypass-clear surface.
	 *
	 * @see TRG_Base.clearBypass
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitClearBypassAuditOnTriggerObjectClear()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TRG_Base.bypass(Foobar__c.SObjectType);

		Test.startTest();
		TRG_Base.clearBypass(Foobar__c.SObjectType);
		Test.stopTest();

		Map<String, Object> bypassContext = findTriggerAuditContextWithAction(SEL_Foobar.OBJECT_NAME, UTIL_BypassAudit.SURFACE_TRIGGER_OBJECT, UTIL_BypassAudit.ACTION_BYPASS);
		Assert.isNotNull(bypassContext, 'setup phase bypass should have emitted a trigger-object BYPASS audit entry');
		Map<String, Object> clearContext = findTriggerAuditContextWithAction(SEL_Foobar.OBJECT_NAME, UTIL_BypassAudit.SURFACE_TRIGGER_OBJECT, UTIL_BypassAudit.ACTION_CLEAR);
		Assert.isNotNull(clearContext, 'clearBypass should emit a trigger-object CLEAR audit entry');
	}

	/**
	 * @description Tests that `TRG_Base.clearAllBypasses()` emits a `trigger-object` audit
	 * entry with the `CLEAR_ALL` action and `ALL` target. Closes the CAP-055 documented edge
	 * case for the bulk-clear surface.
	 *
	 * @see TRG_Base.clearAllBypasses
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitClearAllBypassAudit()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TRG_Base.bypass(Foobar__c.SObjectType);

		Test.startTest();
		TRG_Base.clearAllBypasses();
		Test.stopTest();

		Map<String, Object> bypassContext = findTriggerAuditContextWithAction(SEL_Foobar.OBJECT_NAME, UTIL_BypassAudit.SURFACE_TRIGGER_OBJECT, UTIL_BypassAudit.ACTION_BYPASS);
		Assert.isNotNull(bypassContext, 'setup phase bypass should have emitted a trigger-object BYPASS audit entry');
		Map<String, Object> clearAllContext =
				findTriggerAuditContextWithAction(UTIL_BypassAudit.TARGET_ALL, UTIL_BypassAudit.SURFACE_TRIGGER_OBJECT, UTIL_BypassAudit.ACTION_CLEAR_ALL);
		Assert.isNotNull(clearAllContext, 'clearAllBypasses should emit a trigger-object CLEAR_ALL audit entry');
	}

	/**
	 * @description Locates the most-recent bypass audit entry whose `target` and `surface` match
	 * the supplied values. Filtering by both keeps assertions stable when other framework-internal
	 * audits also fire during the test setup phase.
	 *
	 * @param target The bypass audit `target` context value to find.
	 * @param surface The bypass audit `surface` context value to match.
	 *
	 * @return The inner context map for the matching audit entry, or `null` if none exists.
	 */
	private static Map<String, Object> findTriggerAuditContext(String target, String surface)
	{
		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			if(context != null && target.equals(context.get(UTIL_BypassAudit.CONTEXT_TARGET)) && surface.equals(context.get(UTIL_BypassAudit.CONTEXT_SURFACE)))
			{
				return context;
			}
		}
		return null;
	}

	/**
	 * @description Locates the most-recent bypass audit entry whose `target`, `surface`, and
	 * `action` all match the supplied values. Used for tests that need to disambiguate between
	 * setup-phase BYPASS calls and the assert-phase CLEAR / CLEAR_ALL emissions for the same target.
	 *
	 * @param target The bypass audit `target` context value to find.
	 * @param surface The bypass audit `surface` context value to match.
	 * @param action The bypass audit `action` context value to match.
	 *
	 * @return The inner context map for the matching audit entry, or `null` if none exists.
	 */
	private static Map<String, Object> findTriggerAuditContextWithAction(String target, String surface, String action)
	{
		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			if(context != null
					&& target.equals(context.get(UTIL_BypassAudit.CONTEXT_TARGET))
					&& surface.equals(context.get(UTIL_BypassAudit.CONTEXT_SURFACE))
					&& action.equals(context.get(UTIL_BypassAudit.CONTEXT_ACTION)))
			{
				return context;
			}
		}
		return null;
	}
}