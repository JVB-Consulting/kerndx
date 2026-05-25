// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Subscriber-namespace test class proving cross-namespace dispatch
 * of `kern.TRG_InvokeFlow` and the `kern.TST_InvokeFlowMock` harness.
 *
 * Phase 5B Layer 3 of the flow-as-trigger-action work. Validates the feature as subscribers experience
 * it after installing the managed package: the trigger framework's `TRG_InvokeFlow`
 * Apex class must resolve subscriber-namespace flows, mutate trigger records
 * with the flow's outputs, and short-circuit cleanly when subscriber tests
 * register a `kern.TST_InvokeFlowMock`. The CMDT rows shipped under
 * `release-testing/subscriber/customMetadata/` provide the binding from Account
 * before-insert to `TST_SubscriberFlow_SetDefaults` and
 * `TST_SubscriberFlow_AdditionalDefaults`.
 *
 * @see kern.TRG_InvokeFlow
 * @see kern.TST_InvokeFlowMock
 *
 * @author Jason van Beukering
 *
 * @group Trigger Actions
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class TRG_InvokeFlow_SUBTEST
{
	/**
	 * @description Flow API name bound to the primary `TRG_InvokeFlow` CMDT row.
	 */
	private static final String PRIMARY_FLOW = 'TST_SubscriberFlow_SetDefaults';

	/**
	 * @description Flow API name bound to the second `TRG_InvokeFlow` CMDT row used
	 * by the recursion-identity assertion.
	 */
	private static final String ADDITIONAL_FLOW = 'TST_SubscriberFlow_AdditionalDefaults';

	/**
	 * @description Tests that registering a `kern.TST_InvokeFlowMock` on the primary
	 * flow short-circuits the platform Flow runtime — the real flow is not invoked
	 * and the mock's `withOutputRecord` write-back is applied to the trigger record.
	 */
	@IsTest
	private static void shouldShortCircuitFlowWhenMockRegistered()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');

		Account expectedOutput = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withoutInsertion()
				.withOverride(Account.Description, 'From Mock')
				.withOverride(Account.AccountSource, 'Mock Source')
				.build();
		kern.TST_InvokeFlowMock.forFlow(PRIMARY_FLOW)
				.succeed()
				.withOutputRecord(expectedOutput)
				.register();

		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, 'Technology')
				.withOverride(Account.Phone, '555-0100')
				.build();

		Account result =
		[
				SELECT Description,
						AccountSource
				FROM Account
				WHERE Id = :record.Id
		];
		Assert.areEqual('From Mock', result.Description, 'Mock should write Description back onto trigger record');
		Assert.areEqual('Mock Source', result.AccountSource, 'Mock should write AccountSource back onto trigger record');
		kern.TST_InvokeFlowMock.assertInvoked(PRIMARY_FLOW, 1);
	}

	/**
	 * @description Tests that mock-registered failures route through the CMDT row's
	 * `FailureAction__c = LogAndContinue` strategy — DML succeeds and the error
	 * surfaces only via audit log.
	 */
	@IsTest
	private static void shouldAllowDmlWhenMockFailsUnderLogAndContinue()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');

		kern.TST_InvokeFlowMock.forFlow(PRIMARY_FLOW)
				.fail('Subscriber test deliberate failure')
				.register();

		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, 'Technology')
				.withOverride(Account.Phone, '555-0100')
				.build();

		Account result =
		[
				SELECT Description,
						AccountSource,
						NumberOfEmployees
				FROM Account
				WHERE Id = :record.Id
		];
		Assert.areEqual('Default', result.Description, 'Description should reflect TRG_SetAccountDefaults default — primary flow mocked-fail does not override');
		Assert.areEqual(42, result.NumberOfEmployees, 'Additional flow should still run on the same insert (recursion-identity)');
		kern.TST_InvokeFlowMock.assertInvoked(PRIMARY_FLOW, 1);
		kern.TST_InvokeFlowMock.assertInvoked(ADDITIONAL_FLOW, 0);
	}

	/**
	 * @description Tests that two `TRG_InvokeFlow` CMDT rows bound to distinct flows
	 * both fire on the same trigger event. Confirms the dispatcher's
	 * `(actionType, fingerprint)` recursion-identity tuple distinguishes flow rows
	 * sharing the same `TRG_InvokeFlow` Apex class.
	 */
	@IsTest
	private static void shouldFireBothFlowActionsOnSameTriggerEvent()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');

		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, 'Technology')
				.withOverride(Account.Phone, '555-0100')
				.build();

		Account result =
		[
				SELECT Description,
						AccountSource,
						NumberOfEmployees
				FROM Account
				WHERE Id = :record.Id
		];
		Assert.areEqual('Default From Flow', result.Description, 'Primary flow should set Description');
		Assert.areEqual('Subscriber Flow', result.AccountSource, 'Primary flow should set AccountSource');
		Assert.areEqual(42, result.NumberOfEmployees, 'Additional flow should set NumberOfEmployees');
	}

	/**
	 * @description Tests that `kern.TST_InvokeFlowMock.getLastInputRecord` captures
	 * the trigger record passed into the mocked flow, exposing it for subscriber
	 * test assertions.
	 */
	@IsTest
	private static void shouldCaptureLastInputRecordForMockedFlow()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');

		kern.TST_InvokeFlowMock.forFlow(PRIMARY_FLOW)
				.succeed()
				.register();

		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, 'Technology')
				.withOverride(Account.Phone, '555-0100')
				.build();

		Account captured = (Account)kern.TST_InvokeFlowMock.getLastInputRecord(PRIMARY_FLOW);
		Assert.isNotNull(captured, 'Mock should capture the trigger record');
		Assert.areEqual(record.Id, captured.Id, 'Captured record should match inserted Account Id');
		Assert.areEqual('Technology', captured.Industry, 'Captured record should preserve trigger field values');
	}

	/**
	 * @description Tests that `kern.TST_InvokeFlowMock.assertNotInvoked` correctly
	 * reports that a flow was never invoked when no insert touches its CMDT row.
	 */
	@IsTest
	private static void shouldReportFlowNotInvokedWhenNoMatchingDml()
	{
		kern.TST_InvokeFlowMock.forFlow(PRIMARY_FLOW)
				.succeed()
				.register();

		kern.TST_InvokeFlowMock.assertNotInvoked(PRIMARY_FLOW);
	}
}
