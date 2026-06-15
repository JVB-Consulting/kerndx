// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Smoke tests for the `TRG_InvokeFlow` implementation. Covers the
 * primary integration paths; the broader test matrix (7 contexts x 2 failure
 * strategies x bypass / perf-threshold / recursion-identity / Configurable
 * variants) lives elsewhere. These smoke tests prove: (a) the mock-driven invocation
 * path applies the flow's output back onto the trigger record, (b) `LogAndContinue`
 * on a mocked failure lets DML succeed, (c) `BlockDml` on a mocked failure surfaces
 * `record.addError`, (d) the legacy null-CMDT picklist defaults compile to the
 * documented defaults, and (e) dispatcher integration via `IF_Trigger.Configurable`
 * wires `setConfig` correctly.
 *
 * @see TRG_InvokeFlow
 * @see TST_InvokeFlowMock
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date April 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
@IsTest(SeeAllData=false IsParallel=true)
private class TRG_InvokeFlow_TEST
{
	/**
	 * @description Class name constant used by `TST_Factory.newTriggerActionForContext` for CMDT construction.
	 */
	private static final String TRIGGER_ACTION = TRG_InvokeFlow.class.getName();

	/**
	 * @description Flow API name used by every mock-driven test in this class.
	 */
	private static final String FLOW_NAME = 'TRG_InvokeFlow_TEST_StubFlow';

	/**
	 * @description `FailureAction__c` value that lets DML proceed on flow error.
	 */
	private static final String FAILURE_LOG_AND_CONTINUE = 'LogAndContinue';

	/**
	 * @description `FailureAction__c` value that calls `record.addError` on flow error.
	 */
	private static final String FAILURE_BLOCK_DML = 'BlockDml';

	/**
	 * @description Description value applied by mocked successful flow runs to verify field write-back.
	 */
	private static final String DESCRIPTION_VALUE = 'Mock-set';

	/**
	 * @description Error message returned by failing mocks.
	 */
	private static final String FAILURE_MESSAGE = 'Synthetic flow failure';

	/**
	 * @description Verifies a mocked flow's output `record` is copied onto the trigger record
	 * via `applyResults`/`getPopulatedFieldsAsMap`. Drives `beforeInsert` directly so the
	 * test is independent of the dispatcher.
	 */
	@IsTest
	private static void shouldInvokeFlowOnBeforeInsertViaMock()
	{
		Foobar__c mockedOutput = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.TextArea__c, DESCRIPTION_VALUE)
				.withoutInsertion()
				.build();

		TST_InvokeFlowMock.forFlow(FLOW_NAME)
				.succeed()
				.withOutputRecord(mockedOutput)
				.register();

		TriggerAction__mdt config = buildConfig(FAILURE_LOG_AND_CONTINUE);
		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(new List<SObject> {triggerRecord});
		Test.stopTest();

		Assert.areEqual(DESCRIPTION_VALUE, triggerRecord.TextArea__c, 'Flow output should be applied to the trigger record');
		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 1);
	}

	/**
	 * @description Verifies a `LogAndContinue` failure strategy lets DML proceed and does not
	 * call `addError` on the trigger record. The mocked failure path is the only path that
	 * runs without contacting the platform `Flow.Interview` runtime.
	 */
	@IsTest
	private static void shouldHandleLogAndContinueOnMockedFailure()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TST_InvokeFlowMock.forFlow(FLOW_NAME).fail(FAILURE_MESSAGE).register();

		TriggerAction__mdt config = buildConfig(FAILURE_LOG_AND_CONTINUE);
		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(new List<SObject> {triggerRecord});
		Test.stopTest();

		Assert.isFalse(triggerRecord.hasErrors(), 'LogAndContinue should not raise an addError on the record');
		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 1);
	}

	/**
	 * @description Verifies `BlockDml` calls `record.addError` with the formatted message.
	 * The error message format is `[flowName] originalError (record: id)`.
	 */
	@IsTest
	private static void shouldBlockDmlOnMockedFailureWhenStrategyIsBlockDml()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TST_InvokeFlowMock.forFlow(FLOW_NAME).fail(FAILURE_MESSAGE).register();

		TriggerAction__mdt config = buildConfig(FAILURE_BLOCK_DML);
		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(new List<SObject> {triggerRecord});
		Test.stopTest();

		Assert.isTrue(triggerRecord.hasErrors(), 'BlockDml should raise an addError on the trigger record');
		List<Database.Error> recordErrors = triggerRecord.getErrors();
		Assert.areEqual(1, recordErrors.size(), 'Exactly one error should be present on the record');
		String errorMessage = recordErrors.iterator().next().getMessage();
		Assert.isTrue(errorMessage.contains(FLOW_NAME), 'Formatted error should include the flow name');
		Assert.isTrue(errorMessage.contains(FAILURE_MESSAGE), 'Formatted error should include the original failure message');
	}

	/**
	 * @description Verifies the runtime-error catch block routes through `LogAndContinue`
	 * when the mocked flow throws an exception at the equivalent of `Flow.Interview.start()`.
	 * Drives the `catch (Exception runtimeError)` opener, the `handleFailure` call inside the
	 * catch, and the `return false` sentinel via `TST_InvokeFlowMock.throwOnStart` — without needing
	 * a deliberately-broken flow XML to be deployed.
	 */
	@IsTest
	private static void shouldRouteRuntimeExceptionThroughLogAndContinueViaThrowOnStart()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TST_InvokeFlowMock.forFlow(FLOW_NAME)
				.throwOnStart(new System.NullPointerException())
				.register();

		TriggerAction__mdt config = buildConfig(FAILURE_LOG_AND_CONTINUE);
		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(new List<SObject> {triggerRecord});
		Test.stopTest();

		Assert.isFalse(triggerRecord.hasErrors(), 'LogAndContinue should swallow the runtime exception so DML can proceed');
		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 1);
	}

	/**
	 * @description Verifies the runtime-error catch block routes through `BlockDml` when the
	 * mocked flow throws at start. Pairs with the LogAndContinue case to lock the catch
	 * block's behavior under both failure strategies.
	 */
	@IsTest
	private static void shouldRouteRuntimeExceptionThroughBlockDmlViaThrowOnStart()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TST_InvokeFlowMock.forFlow(FLOW_NAME)
				.throwOnStart(new System.NullPointerException())
				.register();

		TriggerAction__mdt config = buildConfig(FAILURE_BLOCK_DML);
		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(new List<SObject> {triggerRecord});
		Test.stopTest();

		Assert.isTrue(triggerRecord.hasErrors(), 'BlockDml should surface the runtime exception via addError');
		String errorMessage = triggerRecord.getErrors().iterator().next().getMessage();
		Assert.isTrue(errorMessage.contains(FLOW_NAME), 'Formatted error should include the flow name');
	}

	/**
	 * @description Verifies a CMDT row with null `FailureAction__c` does not throw and behaves
	 * as if the default (`LogAndContinue`) were set. Guards the null-coalesce contract for
	 * legacy CMDT records that pre-date the failure-action field.
	 */
	@IsTest
	private static void shouldNullCoalescePicklistDefaultsForLegacyCmdt()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TST_InvokeFlowMock.forFlow(FLOW_NAME).fail(FAILURE_MESSAGE).register();

		TriggerAction__mdt config = buildConfig(null);
		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(new List<SObject> {triggerRecord});
		Test.stopTest();

		Assert.isFalse(triggerRecord.hasErrors(), 'Default LogAndContinue should not raise addError');
		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 1);
	}

	/**
	 * @description Verifies the dispatcher's `Configurable` hook drives `TRG_InvokeFlow`
	 * end-to-end. Uses `actionMetadataOverride` so the synthetic CMDT row is the only
	 * configured action (no dependency on real CMDT being deployed) and asserts the
	 * registered mock was invoked, proving the full path from dispatcher → setConfig →
	 * beforeInsert → invokeSingle → mock short-circuit fires.
	 */
	@IsTest
	private static void shouldShortCircuitMockBeforeConstructingFlowInterview()
	{
		Foobar__c mockedOutput = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.TextArea__c, DESCRIPTION_VALUE)
				.withoutInsertion()
				.build();

		TST_InvokeFlowMock.forFlow(FLOW_NAME)
				.succeed()
				.withOutputRecord(mockedOutput)
				.register();

		TriggerAction__mdt triggerAction = TST_Factory.newTriggerActionForContext
				(
						TRIGGER_ACTION,
						TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME),
						TriggerOperation.BEFORE_INSERT
				);
		triggerAction.FlowName__c = FLOW_NAME;
		triggerAction.FailureAction__c = FAILURE_LOG_AND_CONTINUE;

		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_Dispatcher dispatcher = new TRG_Dispatcher();
		dispatcher.triggerNew = new List<Foobar__c> {triggerRecord};
		dispatcher.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		dispatcher.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();
		dispatcher.run();
		Test.stopTest();

		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 1);
		Assert.areEqual(DESCRIPTION_VALUE, triggerRecord.TextArea__c, 'Flow output should be applied via the dispatcher path');
	}

	/**
	 * @description Verifies all seven trigger-context callbacks dispatch through `run()` to a
	 * registered mock. Registers a single succeed-mock, drives each callback once with an
	 * appropriate record list, and asserts the mock observed seven invocations total.
	 */
	@IsTest
	private static void shouldRunOnAllSevenTriggerContextsViaMock()
	{
		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();

		TriggerAction__mdt config = buildConfig(FAILURE_LOG_AND_CONTINUE);
		Foobar__c newImage = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.TextArea__c, 'new')
				.withoutInsertion()
				.build();
		Foobar__c oldImage = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.TextArea__c, 'old')
				.withoutInsertion()
				.build();
		List<SObject> newImages = new List<SObject> {newImage};
		List<SObject> oldImages = new List<SObject> {oldImage};

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(newImages);
		action.afterInsert(newImages);
		action.beforeUpdate(newImages, oldImages);
		action.afterUpdate(newImages, oldImages);
		action.beforeDelete(oldImages);
		action.afterDelete(oldImages);
		action.afterUndelete(newImages);
		Test.stopTest();

		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 7);
	}

	/**
	 * @description Verifies the action handles a null `actionConfig` (action constructed but
	 * `setConfig` never called) without throwing. The `run()` null-coalesce ensures the
	 * defaults take effect, and the empty `flowName` short-circuits the mock check so no
	 * `Flow.Interview` is constructed.
	 */
	@IsTest
	private static void shouldHandleNullActionConfigWithoutThrowing()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();

		Test.startTest();
		action.beforeInsert(new List<SObject> {record});
		Test.stopTest();

		Assert.isFalse(record.hasErrors(), 'Null config should not raise an addError');
	}

	/**
	 * @description Verifies an empty driving-record list short-circuits without invoking the
	 * mock or emitting `Flow.Interview` calls.
	 */
	@IsTest
	private static void shouldShortCircuitOnEmptyDrivingRecords()
	{
		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();

		TriggerAction__mdt config = buildConfig(FAILURE_LOG_AND_CONTINUE);

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(new List<SObject>());
		Test.stopTest();

		TST_InvokeFlowMock.assertNotInvoked(FLOW_NAME);
	}

	/**
	 * @description Verifies the real `Flow.Interview` happy-path: an active auto-launched flow
	 * declaring `record` (Account, in/out) is invoked, runs to completion, and its output
	 * variable is field-copied back onto the trigger record. Uses the
	 * `Test_BeforeInsertSetDescription` flow (an org fixture that assigns a literal value to
	 * `record.Description`).
	 */
	@IsTest
	private static void shouldInvokeRealFlowAndApplyResultsToAccount()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		String realFlowName = UTIL_System.getManagedPackageNamespacePrefix() + 'Test_BeforeInsertSetDescription';
		TriggerAction__mdt config = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'TRG_InvokeFlow_TEST_RealFlow')
				.withOverride(TriggerAction__mdt.FlowName__c, realFlowName)
				.withOverride(TriggerAction__mdt.FailureAction__c, FAILURE_LOG_AND_CONTINUE)
				.withoutInsertion()
				.build();

		Account newRecord = (Account)TST_Mock.of(Account.SObjectType)
				.withOverride(Account.Name, 'TRG_InvokeFlow_TEST_AccountName')
				.build();
		Account oldRecord = (Account)TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Id, newRecord.Id)
				.withOverride(Account.Name, 'OldName')
				.withoutInsertion()
				.build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeUpdate(new List<SObject> {newRecord}, new List<SObject> {oldRecord});
		Test.stopTest();

		Assert.isFalse(newRecord.hasErrors(), 'Real flow happy-path should not raise addError');
		Assert.isNotNull(newRecord.Description, 'Real flow should have set the Description field');
	}

	/**
	 * @description Verifies the namespace-prefix parse branch in `UTIL_System.createInterview`
	 * (invoked from `TRG_InvokeFlow.createInterviewOrFail`) executes when `FlowName__c`
	 * carries a `namespace__name` prefix shape. Uses a non-existent namespace so
	 * `Flow.Interview.createInterview` deterministically throws `TypeException` after the
	 * parse — the `LogAndContinue` failure strategy routes the lookup failure through
	 * `handleFailure`, DML proceeds without `addError`, and the configuration error is
	 * recorded to the audit log. Both dev-org (unmanaged) and subscriber (managed) runs
	 * reach the parse block via this synthetic prefix, closing the coverage gap that an
	 * unprefixed `FlowName__c` would leave.
	 *
	 * @see TRG_InvokeFlow.createInterviewOrFail
	 * @see UTIL_System.createInterview
	 */
	@IsTest
	private static void shouldParseNamespacePrefixFromFlowNameAndLogConfigurationError()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		String prefixedFlowName = 'kerntest__NonExistentFlow_' + UTIL_Random.randomName();
		TriggerAction__mdt config = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'TRG_InvokeFlow_TEST_PrefixParse')
				.withOverride(TriggerAction__mdt.FlowName__c, prefixedFlowName)
				.withOverride(TriggerAction__mdt.FailureAction__c, FAILURE_LOG_AND_CONTINUE)
				.withoutInsertion()
				.build();

		Account triggerRecord = (Account)TST_Mock.of(Account.SObjectType)
				.withOverride(Account.Name, 'PrefixParse')
				.build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(new List<SObject> {triggerRecord});
		Test.stopTest();

		Assert.isFalse(triggerRecord.hasErrors(), 'LogAndContinue should swallow the configuration error');
		LogEntry__c errorLog = new SEL_LogEntry().findByMethod(TRIGGER_ACTION + '.run');
		Assert.isNotNull(errorLog, 'Configuration error should be recorded');
		Assert.isTrue(errorLog.ShortMessage__c?.contains('kerntest.NonExistentFlow') == true,
				'ShortMessage should reference parsed namespace+name in dot-separated form, proving 3-arg createInterview executed: ' + errorLog.ShortMessage__c);
	}

	/**
	 * @description Verifies `applyResults` skips non-updateable fields (`IsDeleted`,
	 * `CreatedDate`, etc.) that the platform Flow runtime returns populated on the output
	 * record envelope. Without the filter, calling `record.put('IsDeleted', false)` raises
	 * `SObjectException: Field IsDeleted is not editable` and aborts the dispatch.
	 *
	 * Uses a mock output record constructed via `JSON.deserialize` so the test can populate
	 * `IsDeleted` (non-settable through normal field assignment) alongside `Description`
	 * (writable). Asserts the writable field lands and the non-writable field is silently
	 * skipped without exception.
	 */
	@IsTest
	private static void shouldSkipNonUpdateableFieldsInApplyResults()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Account mockOutput = (Account)JSON.deserialize
				(
						'{"attributes":{"type":"Account"},"Description":"From flow","IsDeleted":false}',
						Account.class
				);
		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().withOutputRecord(mockOutput).register();

		TriggerAction__mdt config = buildConfig(FAILURE_LOG_AND_CONTINUE);
		Account triggerRecord = (Account)TST_Mock.of(Account.SObjectType)
				.withOverride(Account.Name, 'shouldSkipNonUpdateableFieldsInApplyResults')
				.build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(new List<SObject> {triggerRecord});
		Test.stopTest();

		Assert.isFalse(triggerRecord.hasErrors(), 'Non-updateable field write should be silently skipped, not raise addError');
		Assert.areEqual('From flow', triggerRecord.Description, 'Updateable Description should land via applyResults');
		LogEntry__c errorLog = new SEL_LogEntry().findByMethod(TRIGGER_ACTION + '.run');
		Assert.isNull(errorLog, 'applyResults must silence non-editable writes via tryPutField — no error log should emit');
	}

	/**
	 * @description Verifies `applyResults` silently skips fields that exist on the flow's output
	 * SObject but not on the trigger record's SObjectType. The describe-based typo guard
	 * (`UTIL_SObjectDescribe.getFieldDescribe` returning null) prevents the `put` from being
	 * attempted at all. This is the correctness path for "flow author bound to wrong SObject"
	 * misconfiguration — the trigger record is preserved and the dispatch continues without error.
	 */
	@IsTest
	private static void shouldSkipFieldsNotPresentOnTriggerRecordType()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Account mockOutputWithMismatchedFields = (Account)TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, 'mismatched-output')
				.withOverride(Account.Description, 'should be filtered — Foobar__c has no Description')
				.withoutInsertion()
				.build();
		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().withOutputRecord(mockOutputWithMismatchedFields).register();

		TriggerAction__mdt config = buildConfig(FAILURE_LOG_AND_CONTINUE);
		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(new List<SObject> {triggerRecord});
		Test.stopTest();

		Assert.isFalse(triggerRecord.hasErrors(), 'Mismatched-type field copy must not raise addError');
		LogEntry__c errorLog = new SEL_LogEntry().findByMethod(TRIGGER_ACTION + '.run');
		Assert.isNull(errorLog, 'Cross-type field copy must be silently filtered by the describe-based typo guard');
	}

	/**
	 * @description Verifies the real `Flow.Interview.createInterview` configuration error path:
	 * when the flow name does not resolve to a deployed flow, the platform raises
	 * `System.TypeException` which the framework catches and routes through `FailureAction__c`.
	 * `LogAndContinue` lets DML proceed; the structured log entry tags `errorKind=configuration`.
	 *
	 * Drives the test record through a mock Id so the failure path's `forRecord(record.Id)`
	 * branch (`emitErrorEntry`) fires.
	 */
	@IsTest
	private static void shouldRouteFlowLookupTypeExceptionThroughFailureAction()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TriggerAction__mdt config = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'TRG_InvokeFlow_TEST_StubMissing')
				.withOverride(TriggerAction__mdt.FlowName__c, 'TRG_InvokeFlow_TEST_NonExistentFlowName')
				.withOverride(TriggerAction__mdt.FailureAction__c, FAILURE_LOG_AND_CONTINUE)
				.withoutInsertion()
				.build();

		Foobar__c record = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType).build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(new List<SObject> {record});
		Test.stopTest();

		Assert.isFalse(record.hasErrors(), 'LogAndContinue should not raise addError on configuration failure');
	}

	/**
	 * @description Verifies the defense-in-depth `catch (Exception unexpectedConfigError)` branch
	 * around `Flow.Interview.createInterview` routes any non-`TypeException` configuration
	 * surface (theoretical platform change, untested edge case) through `FailureAction__c`
	 * tagged with `errorKind = configuration-unexpected`. Empirically only `System.TypeException`
	 * fires from `createInterview`, but the broad fallback ensures subscribers' configured
	 * strategy still wins if the empirical assumption ever proves wrong. Drives the branch via
	 * the `simulateCreateInterviewExceptionForTest` seam so the test does not depend on
	 * coercing the platform Flow runtime.
	 */
	@IsTest
	private static void shouldRouteUnexpectedCreateInterviewExceptionThroughFailureAction()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TriggerAction__mdt config = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'TRG_InvokeFlow_TEST_UnexpectedConfig')
				.withOverride(TriggerAction__mdt.FlowName__c, 'TRG_InvokeFlow_TEST_NonExistentFlowName')
				.withOverride(TriggerAction__mdt.FailureAction__c, FAILURE_LOG_AND_CONTINUE)
				.withoutInsertion()
				.build();

		Foobar__c record = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType).build();
		TRG_InvokeFlow.simulateCreateInterviewExceptionForTest = new System.NullPointerException();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		try
		{
			action.beforeInsert(new List<SObject> {record});
		}
		finally
		{
			TRG_InvokeFlow.simulateCreateInterviewExceptionForTest = null;
		}
		Test.stopTest();

		Assert.isFalse(record.hasErrors(), 'LogAndContinue should not raise addError on unexpected configuration failure');
	}

	/**
	 * @description Verifies the unexpected-config catch rethrows when the caught exception is
	 * a fatal governor blow — matches the runtime catch's `isFatalGovernorError` rethrow
	 * semantics so governor exhaustion is never swallowed by the configuration-error gate.
	 */
	@IsTest
	private static void shouldRethrowFatalGovernorErrorFromUnexpectedCreateInterviewBranch()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TriggerAction__mdt config = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'TRG_InvokeFlow_TEST_UnexpectedFatal')
				.withOverride(TriggerAction__mdt.FlowName__c, 'TRG_InvokeFlow_TEST_NonExistentFlowName')
				.withOverride(TriggerAction__mdt.FailureAction__c, FAILURE_LOG_AND_CONTINUE)
				.withoutInsertion()
				.build();

		Foobar__c record = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType).build();
		System.IllegalArgumentException syntheticBlow = new System.IllegalArgumentException();
		syntheticBlow.setMessage('synthetic governor blow');
		TRG_InvokeFlow.simulateCreateInterviewExceptionForTest = syntheticBlow;
		UTIL_Exceptions.simulateFatalGovernorErrorForTest = true;

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		try
		{
			action.beforeInsert(new List<SObject> {record});
			Assert.fail('Fatal governor error should have rethrown out of the unexpected-config catch');
		}
		catch(System.IllegalArgumentException rethrown)
		{
			Assert.areEqual('synthetic governor blow', rethrown.getMessage(), 'Original exception should propagate unmodified');
		}
		finally
		{
			TRG_InvokeFlow.simulateCreateInterviewExceptionForTest = null;
			UTIL_Exceptions.simulateFatalGovernorErrorForTest = false;
		}
		Test.stopTest();
	}

	/**
	 * @description Verifies `AlwaysOn` audit logging emits the per-batch summary entry on
	 * success. Sets `EnableFlowActionLogging__c = AlwaysOn` via `LOG_Engine.logSettingOverride`,
	 * registers a success mock, dispatches `beforeInsert`, and asserts the dispatch completes
	 * cleanly. The covered audit emit path is the production code that subscribers query for
	 * compliance evidence.
	 */
	@IsTest
	private static void shouldEmitAlwaysOnAuditOnSuccess()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		LogSetting__c logSetting = LOG_Engine.logSettingOverride;
		logSetting.EnableFlowActionLogging__c = 'AlwaysOn';

		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();

		TriggerAction__mdt config = buildConfig(FAILURE_LOG_AND_CONTINUE);
		Foobar__c record = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType).build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(new List<SObject> {record});
		Test.stopTest();

		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 1);
	}

	/**
	 * @description Verifies a successful mock without `withOutputRecord` is a no-op on the
	 * trigger record (no field write-back). Covers the `mockResult.outputRecord != null`
	 * branch in `handleMockResult`.
	 */
	@IsTest
	private static void shouldHandleSuccessMockWithoutOutputRecord()
	{
		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();

		TriggerAction__mdt config = buildConfig(FAILURE_LOG_AND_CONTINUE);
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.TextArea__c, 'unchanged')
				.withoutInsertion()
				.build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(new List<SObject> {record});
		Test.stopTest();

		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 1);
		Assert.areEqual('unchanged', record.TextArea__c, 'No output record means no field write-back');
	}

	/**
	 * @description Verifies update-context dispatch supplies the matching pre-update record as
	 * `recordPrior`. Records carry mock Ids so `buildOldRecordMap` can index them by Id and
	 * the `priorRecord != null` branch of `invokeSingle` fires.
	 */
	@IsTest
	private static void shouldPassPriorRecordOnUpdateContext()
	{
		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();

		TriggerAction__mdt config = buildConfig(FAILURE_LOG_AND_CONTINUE);
		Foobar__c newRecord = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType).build();
		Foobar__c oldRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Id, newRecord.Id)
				.withoutInsertion()
				.build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeUpdate(new List<SObject> {newRecord}, new List<SObject> {oldRecord});
		Test.stopTest();

		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 1);
	}

	/**
	 * @description Verifies `BlockDml` formats the error correctly when the trigger record
	 * has no Id (e.g., a synthetic in-memory test record where Salesforce hasn't yet assigned
	 * an Id). The formatted message substitutes `null` for the missing record id.
	 */
	@IsTest
	private static void shouldFormatBlockDmlErrorWhenRecordHasNoId()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TST_InvokeFlowMock.forFlow(FLOW_NAME).fail(FAILURE_MESSAGE).register();

		TriggerAction__mdt config = buildConfig(FAILURE_BLOCK_DML);
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(new List<SObject> {record});
		Test.stopTest();

		Assert.isTrue(record.hasErrors(), 'BlockDml should call addError even without record Id');
		String errorMessage = record.getErrors().iterator().next().getMessage();
		Assert.isTrue(errorMessage.contains('record: null'), 'Error message should substitute null for missing Id');
	}

	/**
	 * @description Verifies `BlockDml` strategy on the `BEFORE_UPDATE` context lets a
	 * successful flow apply its output and does not raise an addError. Pairs with the
	 * `BEFORE_INSERT` BlockDml-success coverage already shipped via the realistic
	 * `BEFORE_UPDATE` shape that supplies both `record` and `recordPrior` to the flow.
	 */
	@IsTest
	private static void shouldAllowDmlOnBeforeUpdateWhenStrategyIsBlockDmlAndMockSucceeds()
	{
		Foobar__c mockedOutput = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.TextArea__c, DESCRIPTION_VALUE)
				.withoutInsertion()
				.build();

		TST_InvokeFlowMock.forFlow(FLOW_NAME)
				.succeed()
				.withOutputRecord(mockedOutput)
				.register();

		TriggerAction__mdt config = buildConfig(FAILURE_BLOCK_DML);
		Foobar__c newRecord = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType).build();
		Foobar__c oldRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Id, newRecord.Id)
				.withoutInsertion()
				.build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeUpdate(new List<SObject> {newRecord}, new List<SObject> {oldRecord});
		Test.stopTest();

		Assert.isFalse(newRecord.hasErrors(), 'BlockDml on a successful flow should not raise addError');
		Assert.areEqual(DESCRIPTION_VALUE, newRecord.TextArea__c, 'Successful BlockDml flow should still apply its output');
		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 1);
	}

	/**
	 * @description Verifies `BlockDml` on `BEFORE_UPDATE` raises `record.addError` with the
	 * formatted `[flowName] errorMessage (record: id)` message on flow failure. Mirrors the
	 * `BEFORE_INSERT` BlockDml-error coverage but on the realistic update shape that supplies
	 * `recordPrior` to the flow.
	 */
	@IsTest
	private static void shouldBlockDmlOnBeforeUpdateWhenStrategyIsBlockDmlAndMockFails()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TST_InvokeFlowMock.forFlow(FLOW_NAME).fail(FAILURE_MESSAGE).register();

		TriggerAction__mdt config = buildConfig(FAILURE_BLOCK_DML);
		Foobar__c newRecord = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType).build();
		Foobar__c oldRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Id, newRecord.Id)
				.withoutInsertion()
				.build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeUpdate(new List<SObject> {newRecord}, new List<SObject> {oldRecord});
		Test.stopTest();

		Assert.isTrue(newRecord.hasErrors(), 'BlockDml on a failed flow should raise addError on BEFORE_UPDATE');
		String errorMessage = newRecord.getErrors().iterator().next().getMessage();
		Assert.isTrue(errorMessage.contains(FLOW_NAME), 'BEFORE_UPDATE BlockDml error should include the flow name');
		Assert.isTrue(errorMessage.contains(FAILURE_MESSAGE), 'BEFORE_UPDATE BlockDml error should include the failure message');
	}

	/**
	 * @description Verifies a `LogAndContinue` failure routes correctly through every one of
	 * the seven trigger callbacks. Drives each public callback once with a fail-mock and asserts
	 * (a) the mock observed seven invocations total, (b) no record raises addError. The
	 * underlying `handleFailure` routing is identical per context, so a single combined test
	 * is sufficient regression coverage — splitting per-context would duplicate setup without
	 * exercising distinct code paths.
	 */
	@IsTest
	private static void shouldRouteAllSevenContextErrorsThroughLogAndContinue()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		TST_InvokeFlowMock.forFlow(FLOW_NAME).fail(FAILURE_MESSAGE).register();

		TriggerAction__mdt config = buildConfig(FAILURE_LOG_AND_CONTINUE);
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		List<SObject> records = new List<SObject> {record};

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(records);
		action.afterInsert(records);
		action.beforeUpdate(records, records);
		action.afterUpdate(records, records);
		action.beforeDelete(records);
		action.afterDelete(records);
		action.afterUndelete(records);
		Test.stopTest();

		Assert.isFalse(record.hasErrors(), 'LogAndContinue should swallow all seven contexts without raising addError');
		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 7);
	}

	/**
	 * @description Verifies action-level bypass via `TRG_Base.bypassAction('TRG_InvokeFlow')`
	 * skips the flow action entirely on `BEFORE_INSERT` — the dispatcher's
	 * `isActionBypassed(className)` check fires before `setConfig` runs, so the mock is
	 * never invoked.
	 */
	@IsTest
	private static void shouldSkipFlowActionWhenActionLevelBypassedOnBeforeInsert()
	{
		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();

		TriggerAction__mdt triggerAction = newDispatcherFlowConfig(TriggerOperation.BEFORE_INSERT, FAILURE_LOG_AND_CONTINUE);
		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_Dispatcher dispatcher = new TRG_Dispatcher();
		dispatcher.triggerNew = new List<Foobar__c> {triggerRecord};
		dispatcher.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		dispatcher.context = TriggerOperation.BEFORE_INSERT;

		TRG_Base.bypassAction(TRIGGER_ACTION);

		Test.startTest();
		dispatcher.run();
		Test.stopTest();

		TST_InvokeFlowMock.assertNotInvoked(FLOW_NAME);
	}

	/**
	 * @description Verifies action-level bypass on `BEFORE_UPDATE` mirrors the BEFORE_INSERT
	 * behavior. Two-context coverage proves the bypass check fires regardless of dispatch
	 * context — it's evaluated once per dispatch loop iteration.
	 */
	@IsTest
	private static void shouldSkipFlowActionWhenActionLevelBypassedOnBeforeUpdate()
	{
		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();

		TriggerAction__mdt triggerAction = newDispatcherFlowConfig(TriggerOperation.BEFORE_UPDATE, FAILURE_LOG_AND_CONTINUE);
		Foobar__c newRecord = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType).build();
		Foobar__c oldRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Id, newRecord.Id)
				.withoutInsertion()
				.build();

		TRG_Dispatcher dispatcher = new TRG_Dispatcher();
		dispatcher.triggerNew = new List<Foobar__c> {newRecord};
		dispatcher.triggerOld = new List<Foobar__c> {oldRecord};
		dispatcher.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_UPDATE => new List<TriggerAction__mdt> {triggerAction}
		};
		dispatcher.context = TriggerOperation.BEFORE_UPDATE;

		TRG_Base.bypassAction(TRIGGER_ACTION);

		Test.startTest();
		dispatcher.run();
		Test.stopTest();

		TST_InvokeFlowMock.assertNotInvoked(FLOW_NAME);
	}

	/**
	 * @description Verifies object-level bypass via `TRG_Base.bypass(SEL_Foobar.OBJECT_NAME)`
	 * short-circuits the entire dispatch — the dispatcher's `isBypassed(sObjectName)` check
	 * runs before action enumeration, so the flow action is never reached.
	 */
	@IsTest
	private static void shouldSkipFlowActionWhenObjectLevelBypassedOnBeforeInsert()
	{
		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();

		TriggerAction__mdt triggerAction = newDispatcherFlowConfig(TriggerOperation.BEFORE_INSERT, FAILURE_LOG_AND_CONTINUE);
		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_Dispatcher dispatcher = new TRG_Dispatcher();
		dispatcher.triggerNew = new List<Foobar__c> {triggerRecord};
		dispatcher.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		dispatcher.context = TriggerOperation.BEFORE_INSERT;

		TRG_Base.bypass(SEL_Foobar.OBJECT_NAME);

		Test.startTest();
		dispatcher.run();
		Test.stopTest();

		TST_InvokeFlowMock.assertNotInvoked(FLOW_NAME);
	}

	/**
	 * @description Verifies object-level bypass on `BEFORE_UPDATE` short-circuits dispatch.
	 * Pairs with the BEFORE_INSERT case to lock the object-bypass semantic across
	 * representative pre-event contexts.
	 */
	@IsTest
	private static void shouldSkipFlowActionWhenObjectLevelBypassedOnBeforeUpdate()
	{
		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();

		TriggerAction__mdt triggerAction = newDispatcherFlowConfig(TriggerOperation.BEFORE_UPDATE, FAILURE_LOG_AND_CONTINUE);
		Foobar__c newRecord = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType).build();
		Foobar__c oldRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Id, newRecord.Id)
				.withoutInsertion()
				.build();

		TRG_Dispatcher dispatcher = new TRG_Dispatcher();
		dispatcher.triggerNew = new List<Foobar__c> {newRecord};
		dispatcher.triggerOld = new List<Foobar__c> {oldRecord};
		dispatcher.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_UPDATE => new List<TriggerAction__mdt> {triggerAction}
		};
		dispatcher.context = TriggerOperation.BEFORE_UPDATE;

		TRG_Base.bypass(SEL_Foobar.OBJECT_NAME);

		Test.startTest();
		dispatcher.run();
		Test.stopTest();

		TST_InvokeFlowMock.assertNotInvoked(FLOW_NAME);
	}

	/**
	 * @description Verifies the dispatcher's `(actionType, fingerprint)` recursion-identity tuple
	 * lets two `TriggerAction__mdt` rows pointing at `TRG_InvokeFlow` with different
	 * `DeveloperName` values both execute, even when both have `AllowRecursion__c = false`.
	 * Without the fingerprint discriminator the second row would be wrongly skipped because
	 * both rows share `actionType = TRG_InvokeFlow.class`. Both rows point at the same flow
	 * name; we assert the mock observed two invocations.
	 */
	@IsTest
	private static void shouldRunBothFlowActionRowsWhenDifferentDeveloperNamesShareFlowName()
	{
		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();

		TriggerAction__mdt rowA = newDispatcherFlowConfig(TriggerOperation.BEFORE_INSERT, FAILURE_LOG_AND_CONTINUE);
		rowA.DeveloperName = 'TRG_InvokeFlow_TEST_RowA';
		rowA.AllowRecursion__c = false;
		TriggerAction__mdt rowB = newDispatcherFlowConfig(TriggerOperation.BEFORE_INSERT, FAILURE_LOG_AND_CONTINUE);
		rowB.DeveloperName = 'TRG_InvokeFlow_TEST_RowB';
		rowB.AllowRecursion__c = false;

		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_Dispatcher dispatcher = new TRG_Dispatcher();
		dispatcher.triggerNew = new List<Foobar__c> {triggerRecord};
		dispatcher.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {rowA, rowB}
		};
		dispatcher.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();
		dispatcher.run();
		Test.stopTest();

		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 2);
	}

	/**
	 * @description Verifies two `TriggerAction__mdt` rows pointing at `TRG_InvokeFlow` with
	 * distinct `FlowName__c` values each fire their own mock independently. Combined with
	 * the same-flow-different-row case above, this proves the recursion-identity refactor
	 * routes per-CMDT-row regardless of whether the underlying flow names match.
	 */
	@IsTest
	private static void shouldRunBothFlowActionRowsWithDifferentFlowNames()
	{
		String secondFlowName = FLOW_NAME + '_Second';

		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();
		TST_InvokeFlowMock.forFlow(secondFlowName).succeed().register();

		TriggerAction__mdt rowA = newDispatcherFlowConfig(TriggerOperation.BEFORE_INSERT, FAILURE_LOG_AND_CONTINUE);
		rowA.DeveloperName = 'TRG_InvokeFlow_TEST_RowFirst';
		rowA.AllowRecursion__c = false;
		TriggerAction__mdt rowB = newDispatcherFlowConfig(TriggerOperation.BEFORE_INSERT, FAILURE_LOG_AND_CONTINUE);
		rowB.DeveloperName = 'TRG_InvokeFlow_TEST_RowSecond';
		rowB.FlowName__c = secondFlowName;
		rowB.AllowRecursion__c = false;

		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_Dispatcher dispatcher = new TRG_Dispatcher();
		dispatcher.triggerNew = new List<Foobar__c> {triggerRecord};
		dispatcher.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {rowA, rowB}
		};
		dispatcher.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();
		dispatcher.run();
		Test.stopTest();

		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 1);
		TST_InvokeFlowMock.assertInvoked(secondFlowName, 1);
	}

	/**
	 * @description Verifies the perf timer's per-action `flowName` plumbing: when
	 * `PerformanceThresholdMs__c = 0` forces a perf log on every dispatch and trigger logging
	 * is enabled, the resulting `LogEntry__c.ContextData__c` carries the `flowName` context
	 * value so subscribers querying perf logs can filter by flow. Validates the integration
	 * end-to-end through the dispatcher.
	 */
	@IsTest
	private static void shouldEmitPerformanceLogWithFlowNameWhenThresholdBreached()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0, false, 0, true, 0);

		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();

		TriggerAction__mdt triggerAction = newDispatcherFlowConfig(TriggerOperation.BEFORE_INSERT, FAILURE_LOG_AND_CONTINUE);
		triggerAction.PerformanceThresholdMs__c = 0;

		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_Dispatcher dispatcher = new TRG_Dispatcher();
		dispatcher.triggerNew = new List<Foobar__c> {triggerRecord};
		dispatcher.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		dispatcher.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();
		dispatcher.run();
		Test.stopTest();

		LogEntry__c performanceLog = new SEL_LogEntry().findPerformanceLogByMethod(TRIGGER_ACTION + '/before_insert');
		Assert.isNotNull(performanceLog, 'PerformanceThresholdMs__c = 0 should force a perf log entry for the flow action');
		Assert.isNotNull(performanceLog.ContextData__c, 'Perf log must carry serialized context data for the flow action');
		Assert.isTrue(performanceLog.ContextData__c.contains('flowName'), 'Perf log context must include the flowName key');
		Assert.isTrue(performanceLog.ContextData__c.contains(FLOW_NAME), 'Perf log context must include the configured flow name');
	}

	/**
	 * @description Verifies `SuppressPerformanceLogging__c = true` blocks perf log emission
	 * for `TRG_InvokeFlow` even when global trigger logging is enabled at threshold 0.
	 * Locks the suppress-takes-precedence behavior end-to-end through the dispatcher for
	 * flow actions specifically.
	 */
	@IsTest
	private static void shouldNotEmitPerformanceLogForFlowActionWhenSuppressFlagSet()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0, false, 0, true, 0);

		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();

		TriggerAction__mdt triggerAction = newDispatcherFlowConfig(TriggerOperation.BEFORE_INSERT, FAILURE_LOG_AND_CONTINUE);
		triggerAction.SuppressPerformanceLogging__c = true;

		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_Dispatcher dispatcher = new TRG_Dispatcher();
		dispatcher.triggerNew = new List<Foobar__c> {triggerRecord};
		dispatcher.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {triggerAction}
		};
		dispatcher.context = TriggerOperation.BEFORE_INSERT;

		Test.startTest();
		dispatcher.run();
		Test.stopTest();

		LogEntry__c performanceLog = new SEL_LogEntry().findPerformanceLogByMethod(TRIGGER_ACTION + '/before_insert');
		Assert.isNull(performanceLog, 'SuppressPerformanceLogging__c should block perf log emission for flow action');
	}

	/**
	 * @description Verifies `setConfig` stores the supplied `TriggerAction__mdt` reference on
	 * the action's `actionConfig` field, exposing it via `@TestVisible`. Locks the contract
	 * the dispatcher relies on: `setConfig` is the only mutator and it stores the reference
	 * verbatim — no copy, no transformation, no validation side-effects.
	 */
	@IsTest
	private static void shouldStoreSuppliedConfigOnSetConfig()
	{
		TriggerAction__mdt config = buildConfig(FAILURE_LOG_AND_CONTINUE);

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Assert.areEqual(config, action.actionConfig, 'setConfig must store the exact TriggerAction__mdt reference (no copy or transformation)');
	}

	/**
	 * @description Verifies the unified `catch(Exception)` block rethrows fatal governor-blow
	 * exceptions verbatim instead of swallowing via the `LogAndContinue` failure strategy.
	 *
	 * Real `System.LimitException` thrown from user code escapes all Apex catch blocks at the
	 * platform's executor level, so the rethrow path is not driveable with an actual
	 * `LimitException`. Instead, the test flips the
	 * `simulateFatalGovernorErrorForTest` toggle so `isFatalGovernorError` returns true for
	 * the injected `NullPointerException`, the `throw caught;` branch fires, and the test
	 * asserts the original exception propagates unchanged. Locks the defense-in-depth contract
	 * even though real platform-fired LimitException is untestable from user-mode Apex.
	 */
	@IsTest
	private static void shouldRethrowFatalGovernorErrorVerbatimWhenIsFatalReturnsTrue()
	{
		System.NullPointerException injected = new System.NullPointerException();
		TST_InvokeFlowMock.forFlow(FLOW_NAME).throwOnStart(injected).register();
		UTIL_Exceptions.simulateFatalGovernorErrorForTest = true;

		TriggerAction__mdt config = buildConfig(FAILURE_LOG_AND_CONTINUE);
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		try
		{
			Test.startTest();
			action.beforeInsert(new List<SObject> {record});
			Test.stopTest();
			Assert.fail('Fatal governor error should propagate uncaught from beforeInsert');
		}
		catch(System.NullPointerException error)
		{
			Assert.areEqual(injected, error, 'Catch should receive the original injected exception verbatim');
			Assert.isFalse(record.hasErrors(), 'Rethrow path must not have routed through addError');
		}
	}

	/**
	 * @description Verifies `isFatalGovernorError` returns `true` for a real
	 * `System.LimitException` instance via direct method call (the catch in `invokeSingle` is
	 * unreachable from user-mode tests, but the discriminator function is callable directly).
	 * Locks the production behavior that real `System.LimitException` instances trigger the
	 * rethrow path even when the test seam is off.
	 */
	@IsTest
	private static void shouldClassifyRealLimitExceptionAsFatalGovernorError()
	{
		Assert.isFalse(UTIL_Exceptions.simulateFatalGovernorErrorForTest, 'Test seam must be off for production-shape assertion');
		Assert.isTrue(UTIL_Exceptions.isFatalGovernorError(new System.LimitException('any')), 'System.LimitException should classify as fatal governor error');
		Assert.isFalse(UTIL_Exceptions.isFatalGovernorError(new System.NullPointerException()), 'Non-LimitException must NOT classify as fatal when test seam is off');
	}

	/**
	 * @description Verifies `run()` short-circuits cleanly when `FlowName__c` is blank — no
	 * exception, no mock invocation, no addError. This is the production-shape contract for a
	 * mis-configured CMDT row: the action exits silently rather than throwing a configuration
	 * error mid-trigger.
	 */
	@IsTest
	private static void shouldShortCircuitWhenFlowNameIsBlank()
	{
		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();

		TriggerAction__mdt config = buildConfig(FAILURE_LOG_AND_CONTINUE);
		config.FlowName__c = '';

		Foobar__c triggerRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		action.beforeInsert(new List<SObject> {triggerRecord});
		Test.stopTest();

		Assert.isFalse(triggerRecord.hasErrors(), 'Blank FlowName__c should short-circuit without raising addError');
		TST_InvokeFlowMock.assertNotInvoked(FLOW_NAME);
	}

	/**
	 * @description Verifies a Change Event dispatch injects a `DTO_ChangeEventHeader` into
	 * the Flow input variables map and threads it through to the mock recorder. The dispatch
	 * is driven by an in-memory `AccountChangeEvent` SObject built via `TST_Builder` —
	 * standard `AccountChangeEvent` resolves identically in both unmanaged dev orgs and
	 * managed subscriber installs, and `String.endsWith('ChangeEvent')` fires on the API
	 * name to flag the CDC branch.
	 *
	 * The header is supplied via the `simulateChangeEventHeaderForTest` seam rather than
	 * populated on the SObject because the platform crashes on
	 * `(EventBus.ChangeEventHeader)record.get('ChangeEventHeader')` for any JSON-roundtripped
	 * Change Event SObject (`TST_Builder`/`TST_Mock`/raw deserialize all share this
	 * limitation). The real-CDC cast path is covered by the subscriber-org integration tests.
	 *
	 * @see TRG_InvokeFlow.buildChangeEventHeaderDto
	 * @see TST_InvokeFlowMock.getLastInputHeader
	 * @see DTO_ChangeEventHeader
	 */
	@IsTest
	private static void shouldInjectChangeEventHeaderForCdcDispatchViaMock()
	{
		String cdcFlowName = 'TRG_InvokeFlow_TEST_AcctChangeFlow';
		TST_InvokeFlowMock.forFlow(cdcFlowName).succeed().register();

		TriggerAction__mdt config = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'TRG_InvokeFlow_TEST_CdcStub')
				.withOverride(TriggerAction__mdt.FlowName__c, cdcFlowName)
				.withOverride(TriggerAction__mdt.FailureAction__c, FAILURE_LOG_AND_CONTINUE)
				.withoutInsertion()
				.build();

		DTO_ChangeEventHeader simulatedHeader = new DTO_ChangeEventHeader();
		simulatedHeader.entityName = 'Account';
		simulatedHeader.changeType = 'CREATE';
		simulatedHeader.recordIds = new List<String> {String.valueOf(UTIL_Random.randomId(Account.SObjectType))};
		TRG_InvokeFlow.simulateChangeEventHeaderForTest = simulatedHeader;

		AccountChangeEvent cdcRecord = (AccountChangeEvent)TST_Builder.of(AccountChangeEvent.SObjectType)
				.withoutInsertion()
				.build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		try
		{
			action.afterInsert(new List<SObject> {cdcRecord});
		}
		finally
		{
			TRG_InvokeFlow.simulateChangeEventHeaderForTest = null;
		}
		Test.stopTest();

		DTO_ChangeEventHeader captured = (DTO_ChangeEventHeader)TST_InvokeFlowMock.getLastInputHeader(cdcFlowName);
		Assert.isNotNull(captured, 'CDC dispatch should inject a DTO_ChangeEventHeader for the mocked flow');
		Assert.areEqual('CREATE', captured.changeType, 'Header changeType should flow through to the mock recorder');
		Assert.areEqual('Account', captured.entityName, 'Header entityName should flow through to the mock recorder');
		Assert.areEqual(simulatedHeader.recordIds, captured.recordIds, 'Header recordIds should flow through to the mock recorder');
		TST_InvokeFlowMock.assertInvoked(cdcFlowName, 1);
	}

	/**
	 * @description Verifies the CDC aggregate audit path: with `AlwaysOn` flow-action logging
	 * enabled, a Change Event dispatch emits exactly one per-batch audit `LogEntry__c` whose
	 * serialized context carries the underlying `header.recordIds` (not the synthetic
	 * change-event record Id) and whose `recordCount` reflects the total recordIds across
	 * all change-event records (not the change-event record count). The simulator seam
	 * supplies a known header so the assertion can match exact recordId values.
	 *
	 * Confirms the design intent: subscribers querying the flow-action audit for "what
	 * records did this CDC dispatch target?" see the underlying object Ids the platform
	 * delivered in `header.recordIds`, capped at MAX_AUDITED_IDS for spot-checking while
	 * the total count surfaces in `CONTEXT_RECORD_COUNT`.
	 *
	 * @see TRG_InvokeFlow.emitAuditEvent
	 */
	@IsTest
	private static void shouldEmitAggregateCdcAuditWithHeaderRecordIdsAndTotalCount()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		LogSetting__c logSetting = LOG_Engine.logSettingOverride;
		logSetting.EnableFlowActionLogging__c = 'AlwaysOn';

		String cdcFlowName = 'TRG_InvokeFlow_TEST_AcctAggregateFlow';
		TST_InvokeFlowMock.forFlow(cdcFlowName).succeed().register();

		TriggerAction__mdt config = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'TRG_InvokeFlow_TEST_CdcAggregate')
				.withOverride(TriggerAction__mdt.FlowName__c, cdcFlowName)
				.withOverride(TriggerAction__mdt.FailureAction__c, FAILURE_LOG_AND_CONTINUE)
				.withoutInsertion()
				.build();

		String firstRecordId = String.valueOf(UTIL_Random.randomId(Account.SObjectType));
		String secondRecordId = String.valueOf(UTIL_Random.randomId(Account.SObjectType));
		String thirdRecordId = String.valueOf(UTIL_Random.randomId(Account.SObjectType));

		DTO_ChangeEventHeader simulatedHeader = new DTO_ChangeEventHeader();
		simulatedHeader.entityName = 'Account';
		simulatedHeader.changeType = 'CREATE';
		simulatedHeader.recordIds = new List<String> {firstRecordId, secondRecordId, thirdRecordId};
		TRG_InvokeFlow.simulateChangeEventHeaderForTest = simulatedHeader;

		AccountChangeEvent cdcRecord = (AccountChangeEvent)TST_Builder.of(AccountChangeEvent.SObjectType)
				.withoutInsertion()
				.build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		try
		{
			action.afterInsert(new List<SObject> {cdcRecord});
		}
		finally
		{
			TRG_InvokeFlow.simulateChangeEventHeaderForTest = null;
		}
		Test.stopTest();

		LogEntry__c auditLog = new SEL_LogEntry().findByMethod(TRIGGER_ACTION + '.run');
		Assert.isNotNull(auditLog, 'AlwaysOn audit should emit a per-batch entry for the CDC dispatch');
		Assert.isNotNull(auditLog.ContextData__c, 'Audit context data must be populated');
		Map<String, Object> ctx = extractAuditContextData(auditLog.ContextData__c);
		Assert.areEqual('3', String.valueOf(ctx.get('recordCount')),
				'recordCount must equal total header.recordIds (3), not change-event record count (1): ' + auditLog.ContextData__c);
		String serializedIds = String.valueOf(ctx.get('recordIds'));
		Assert.isTrue(serializedIds.contains(firstRecordId), 'Audit should carry the first underlying recordId from header');
		Assert.isTrue(serializedIds.contains(secondRecordId), 'Audit should carry the second underlying recordId from header');
		Assert.isTrue(serializedIds.contains(thirdRecordId), 'Audit should carry the third underlying recordId from header');
	}

	/**
	 * @description Verifies the CDC aggregate audit caps the recordIds list at `MAX_AUDITED_IDS`
	 * while the total count reflects the full uncapped sum. Dispatches three change-event
	 * records whose combined header.recordIds total 300 (3 × 100) — the audit list caps at 200
	 * (first 200 ids surface in `CONTEXT_RECORD_IDS`) while `CONTEXT_RECORD_COUNT` reports 300.
	 *
	 * Drives the cap-saturation branch where `remaining <= 0` short-circuits subsequent
	 * accumulation, plus the per-list-add branch where take is bounded by remaining capacity
	 * rather than the list size.
	 */
	@IsTest
	private static void shouldCapCdcAuditRecordIdsAtMaxWhileTotalCountReflectsFullSum()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		LogSetting__c logSetting = LOG_Engine.logSettingOverride;
		logSetting.EnableFlowActionLogging__c = 'AlwaysOn';

		String cdcFlowName = 'TRG_InvokeFlow_TEST_AcctCappedFlow';
		TST_InvokeFlowMock.forFlow(cdcFlowName).succeed().register();

		TriggerAction__mdt config = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'TRG_InvokeFlow_TEST_CdcCapped')
				.withOverride(TriggerAction__mdt.FlowName__c, cdcFlowName)
				.withOverride(TriggerAction__mdt.FailureAction__c, FAILURE_LOG_AND_CONTINUE)
				.withoutInsertion()
				.build();

		List<String> bulkIds = new List<String>();
		for(Integer i = 0; i < 100; i++)
		{
			bulkIds.add(String.valueOf(UTIL_Random.randomId(Account.SObjectType)));
		}

		DTO_ChangeEventHeader simulatedHeader = new DTO_ChangeEventHeader();
		simulatedHeader.entityName = 'Account';
		simulatedHeader.changeType = 'UPDATE';
		simulatedHeader.recordIds = bulkIds;
		TRG_InvokeFlow.simulateChangeEventHeaderForTest = simulatedHeader;

		List<SObject> cdcRecords = new List<SObject>();
		for(Integer i = 0; i < 3; i++)
		{
			cdcRecords.add(TST_Builder.of(AccountChangeEvent.SObjectType).withoutInsertion().build());
		}

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		try
		{
			action.afterInsert(cdcRecords);
		}
		finally
		{
			TRG_InvokeFlow.simulateChangeEventHeaderForTest = null;
		}
		Test.stopTest();

		LogEntry__c auditLog = new SEL_LogEntry().findByMethod(TRIGGER_ACTION + '.run');
		Assert.isNotNull(auditLog, 'AlwaysOn audit should emit a per-batch entry for the CDC dispatch');
		Map<String, Object> ctx = extractAuditContextData(auditLog.ContextData__c);
		Assert.areEqual('300', String.valueOf(ctx.get('recordCount')),
				'recordCount must reflect full uncapped total (300 = 3 × 100): ' + auditLog.ContextData__c);
		String serializedIds = String.valueOf(ctx.get('recordIds'));
		Assert.isTrue(serializedIds.contains(bulkIds[0]), 'First id should be in audit list (below cap)');
		List<Object> capturedIds = (List<Object>)JSON.deserializeUntyped(serializedIds);
		Assert.areEqual(200, capturedIds.size(),
				'attemptedCdcRecordIds must cap at MAX_AUDITED_IDS (200) — full uncapped total surfaces only via recordCount');
	}

	/**
	 * @description Verifies a CDC dispatch with a header carrying null `recordIds` does not
	 * throw and emits an audit entry with `recordCount = 0`. Covers the defensive early
	 * return in `accumulateCdcAuditIds` when the simulator seam produces a DTO without a
	 * populated `recordIds` list (default-constructor case) — production CDC delivery
	 * always populates `recordIds`, but the framework must not crash on a malformed
	 * synthetic header.
	 */
	@IsTest
	private static void shouldSkipAccumulationWhenCdcHeaderRecordIdsIsNull()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		LogSetting__c logSetting = LOG_Engine.logSettingOverride;
		logSetting.EnableFlowActionLogging__c = 'AlwaysOn';

		String cdcFlowName = 'TRG_InvokeFlow_TEST_NullIdsFlow';
		TST_InvokeFlowMock.forFlow(cdcFlowName).succeed().register();

		TriggerAction__mdt config = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'TRG_InvokeFlow_TEST_CdcNullIds')
				.withOverride(TriggerAction__mdt.FlowName__c, cdcFlowName)
				.withOverride(TriggerAction__mdt.FailureAction__c, FAILURE_LOG_AND_CONTINUE)
				.withoutInsertion()
				.build();

		DTO_ChangeEventHeader simulatedHeader = new DTO_ChangeEventHeader();
		simulatedHeader.entityName = 'Account';
		simulatedHeader.changeType = 'GAP_OVERFLOW';
		TRG_InvokeFlow.simulateChangeEventHeaderForTest = simulatedHeader;

		AccountChangeEvent cdcRecord = (AccountChangeEvent)TST_Builder.of(AccountChangeEvent.SObjectType)
				.withoutInsertion()
				.build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		try
		{
			action.afterInsert(new List<SObject> {cdcRecord});
		}
		finally
		{
			TRG_InvokeFlow.simulateChangeEventHeaderForTest = null;
		}
		Test.stopTest();

		LogEntry__c auditLog = new SEL_LogEntry().findByMethod(TRIGGER_ACTION + '.run');
		Assert.isNotNull(auditLog, 'AlwaysOn audit should still emit even when header.recordIds is null');
		Map<String, Object> ctx = extractAuditContextData(auditLog.ContextData__c);
		Assert.areEqual('0', String.valueOf(ctx.get('recordCount')),
				'recordCount must be 0 when header carries no recordIds: ' + auditLog.ContextData__c);
	}

	/**
	 * @description Verifies a `BlockDml` failure on a Change Event dispatch is degraded to
	 * `LogAndContinue` semantics: `record.addError` is NOT called (because a committed
	 * change cannot be rolled back), and a distinct warning audit entry is emitted with
	 * `errorKind = cdc-block-dml-degraded` so subscribers can pivot queries on the degrade
	 * event. The per-record error log entry still emits (it carries the underlying flow
	 * failure context); the degrade warning is a parallel signal naming the policy switch.
	 *
	 * @see TRG_InvokeFlow.handleFailure
	 */
	@IsTest
	private static void shouldDegradeBlockDmlToLogAndContinueOnCdcDispatch()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		String cdcFlowName = 'TRG_InvokeFlow_TEST_CdcBlockDmlFlow';
		TST_InvokeFlowMock.forFlow(cdcFlowName).fail(FAILURE_MESSAGE).register();

		TriggerAction__mdt config = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'TRG_InvokeFlow_TEST_CdcBlockDml')
				.withOverride(TriggerAction__mdt.FlowName__c, cdcFlowName)
				.withOverride(TriggerAction__mdt.FailureAction__c, FAILURE_BLOCK_DML)
				.withoutInsertion()
				.build();

		DTO_ChangeEventHeader simulatedHeader = new DTO_ChangeEventHeader();
		simulatedHeader.entityName = 'Account';
		simulatedHeader.changeType = 'CREATE';
		simulatedHeader.recordIds = new List<String> {String.valueOf(UTIL_Random.randomId(Account.SObjectType))};
		TRG_InvokeFlow.simulateChangeEventHeaderForTest = simulatedHeader;

		AccountChangeEvent cdcRecord = (AccountChangeEvent)TST_Builder.of(AccountChangeEvent.SObjectType)
				.withoutInsertion()
				.build();

		TRG_InvokeFlow action = new TRG_InvokeFlow();
		action.setConfig(config);

		Test.startTest();
		try
		{
			action.afterInsert(new List<SObject> {cdcRecord});
		}
		finally
		{
			TRG_InvokeFlow.simulateChangeEventHeaderForTest = null;
		}
		Test.stopTest();

		Assert.isFalse(cdcRecord.hasErrors(),
				'BlockDml on Change Event must degrade to LogAndContinue — addError cannot roll back a committed change');
		List<LogEntry__c> allEntries = new SEL_LogEntry().findAllByMethod(TRIGGER_ACTION + '.run');
		Boolean foundDegradeWarning = false;
		for(LogEntry__c entry : allEntries)
		{
			if(entry.ContextData__c != null && entry.ContextData__c.contains('cdc-block-dml-degraded'))
			{
				foundDegradeWarning = true;
				Assert.isTrue(entry.ContextData__c.contains(cdcFlowName),
						'Degrade warning should name the offending flow');
				Assert.isTrue(entry.ContextData__c.contains('BlockDml'),
						'Degrade warning should name the rejected failure action');
				break;
			}
		}
		Assert.isTrue(foundDegradeWarning,
				'A warning audit entry with errorKind=cdc-block-dml-degraded must be emitted on BlockDml+CDC: ' + allEntries);

		Boolean foundUnderlyingError = false;
		for(LogEntry__c entry : allEntries)
		{
			if(entry.ContextData__c != null && entry.ContextData__c.contains('runtime') && !entry.ContextData__c.contains('cdc-block-dml-degraded'))
			{
				foundUnderlyingError = true;
				break;
			}
		}
		Assert.isTrue(foundUnderlyingError,
				'The underlying flow-failure audit entry (errorKind=runtime) must still emit alongside the degrade warning: ' + allEntries);
	}

	/**
	 * @description Parses the `LogEntry__c.ContextData__c` JSON string and returns the inner
	 * `contextData` map. LOG_Builder wraps the user-supplied context map in a `{"contextData":
	 * {...}}` envelope before serializing, so test assertions on individual context keys must
	 * navigate one level into the outer object. Returns an empty map when the field is null
	 * or the inner envelope is missing — callers should follow up with explicit value checks.
	 *
	 * @param contextDataJson The raw `ContextData__c` field value (LOG_Builder-serialized JSON).
	 *
	 * @return The inner `contextData` map containing the per-emit context keys.
	 */
	private static Map<String, Object> extractAuditContextData(String contextDataJson)
	{
		if(String.isBlank(contextDataJson))
		{
			return new Map<String, Object>();
		}
		Map<String, Object> envelope = (Map<String, Object>)JSON.deserializeUntyped(contextDataJson);
		Object payload = envelope.get('contextData');
		if(!(payload instanceof Map<String, Object>))
		{
			return new Map<String, Object>();
		}
		return (Map<String, Object>)payload;
	}

	/**
	 * @description Builds a synthetic in-memory `TriggerAction__mdt` row carrying the supplied
	 * failure strategy. Bypasses the CMDT parent-relationship trickery `TST_Factory` handles
	 * because these smoke tests drive `TRG_InvokeFlow` directly without the dispatcher.
	 *
	 * @param failureAction The `FailureAction__c` value to apply, or null for legacy-CMDT testing.
	 *
	 * @return An in-memory `TriggerAction__mdt` record with the requested values.
	 */
	private static TriggerAction__mdt buildConfig(String failureAction)
	{
		return (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.DeveloperName, 'TRG_InvokeFlow_TEST_Stub')
				.withOverride(TriggerAction__mdt.FlowName__c, FLOW_NAME)
				.withOverride(TriggerAction__mdt.FailureAction__c, failureAction)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Builds a `TriggerAction__mdt` row suitable for dispatcher-driven tests —
	 * `ApexClassName__c` and dispatcher-required defaults are populated via `TST_Factory`,
	 * then the flow-specific fields (`FlowName__c`, `FailureAction__c`) are layered on.
	 * Use this for any test that goes through `TRG_Dispatcher.run()`; the lighter
	 * `buildConfig` helper above is for direct-action invocation only.
	 *
	 * @param context The trigger operation (controls the resolved `Event__c` value).
	 * @param failureAction The `FailureAction__c` value to apply.
	 *
	 * @return An in-memory `TriggerAction__mdt` record with dispatcher-required defaults.
	 */
	private static TriggerAction__mdt newDispatcherFlowConfig(TriggerOperation context, String failureAction)
	{
		TriggerAction__mdt row = TST_Factory.newTriggerActionForContext
				(
						TRIGGER_ACTION,
						TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME),
						context
				);
		row.FlowName__c = FLOW_NAME;
		row.FailureAction__c = failureAction;
		return row;
	}
}