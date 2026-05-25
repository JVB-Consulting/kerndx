// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for `TST_InvokeFlowMock` mock harness.
 *
 * Covers the fluent registration chain, double-register protection, invocation
 * counting, assertion helpers, input-record capture (`getLastInputRecord` /
 * `getLastInputPriorRecord`), and the framework-internal `TRG_InvokeFlow` integration
 * surface (`isMocked` / `getMockResult` / `recordInvocation`).
 *
 * @see TST_InvokeFlowMock
 *
 * @author Jason van Beukering
 *
 * @group Trigger Framework
 *
 * @date April 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class TST_InvokeFlowMock_TEST
{
	/**
	 * @description Flow name used by happy-path tests.
	 */
	private static final String FLOW_NAME = 'Account_SetDefaults';

	/**
	 * @description Alternate flow name used to verify per-flow isolation.
	 */
	private static final String OTHER_FLOW_NAME = 'Account_PopulateNumber';

	/**
	 * @description Failure error message used when registering a failing mock.
	 */
	private static final String FAILURE_MESSAGE = 'Synthetic flow failure';

	/**
	 * @description Description value applied to mocked output records to verify pass-through.
	 */
	private static final String DESCRIPTION_VALUE = 'Mock-set';

	/**
	 * @description Industry value applied to captured input records to verify input-record capture.
	 */
	private static final String INDUSTRY_VALUE = 'Technology';

	/**
	 * @description Prior industry value applied to captured priorRecord inputs to verify update-context capture.
	 */
	private static final String PRIOR_INDUSTRY_VALUE = 'Manufacturing';

	/**
	 * @description Verifies a happy-path register-and-retrieve cycle.
	 */
	@IsTest
	private static void shouldRegisterAndRetrieveMock()
	{
		Account expectedOutput = (Account)TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Description, DESCRIPTION_VALUE)
				.withoutInsertion()
				.build();

		TST_InvokeFlowMock.forFlow(FLOW_NAME)
				.succeed()
				.withOutputRecord(expectedOutput)
				.register();

		Assert.isTrue(TST_InvokeFlowMock.isMocked(FLOW_NAME), 'Mock should be registered');

		TST_InvokeFlowMock.MockResult result = TST_InvokeFlowMock.getMockResult(FLOW_NAME);

		Assert.isNotNull(result, 'MockResult should be retrievable');
		Assert.isTrue(result.success, 'Default success flag should be true');
		Assert.isNull(result.errorMessage, 'Successful mock should have no error message');
		Assert.areEqual(expectedOutput, result.outputRecord, 'Output record should round-trip');
		Assert.isNull(result.outputRecords, 'Single-record mock should leave outputRecords null');
	}

	/**
	 * @description Verifies `fail()` records the failure flag and message.
	 */
	@IsTest
	private static void shouldRegisterFailingMock()
	{
		TST_InvokeFlowMock.forFlow(FLOW_NAME).fail(FAILURE_MESSAGE).register();

		TST_InvokeFlowMock.MockResult result = TST_InvokeFlowMock.getMockResult(FLOW_NAME);

		Assert.isFalse(result.success, 'Failing mock should report success=false');
		Assert.areEqual(FAILURE_MESSAGE, result.errorMessage, 'Error message should round-trip');
	}

	/**
	 * @description Verifies `withOutputRecords` populates the bulk-mode list.
	 */
	@IsTest
	private static void shouldRegisterMockWithOutputRecordList()
	{
		List<SObject> outputs = new List<SObject>
		{
				TST_Builder.of(Account.SObjectType)
						.withOverride(Account.Description, DESCRIPTION_VALUE)
						.withoutInsertion()
						.build()
		};

		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().withOutputRecords(outputs).register();

		TST_InvokeFlowMock.MockResult result = TST_InvokeFlowMock.getMockResult(FLOW_NAME);

		Assert.areEqual(1, result.outputRecords.size(), 'Output records should round-trip');
		Assert.areEqual(outputs[0], result.outputRecords[0], 'Output record should match input');
	}

	/**
	 * @description Verifies `clear()` empties both the registry and invocation history.
	 */
	@IsTest
	private static void shouldClearRegistryAndInvocations()
	{
		Account record = (Account)TST_Builder.of(Account.SObjectType).withoutInsertion().build();

		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();
		TST_InvokeFlowMock.recordInvocation(FLOW_NAME, record, null);

		TST_InvokeFlowMock.clear();

		Assert.isFalse(TST_InvokeFlowMock.isMocked(FLOW_NAME), 'Registry should be empty after clear');
		Assert.isNull(TST_InvokeFlowMock.getMockResult(FLOW_NAME), 'getMockResult should return null after clear');
		Assert.isFalse(TST_InvokeFlowMock.wasInvoked(FLOW_NAME), 'Invocation counts should reset on clear');
		Assert.isNull(TST_InvokeFlowMock.getLastInputRecord(FLOW_NAME), 'Captured input should reset on clear');
	}

	/**
	 * @description Verifies double-registration raises a clear error.
	 */
	@IsTest
	private static void shouldRejectDoubleRegistration()
	{
		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();

		try
		{
			TST_InvokeFlowMock.forFlow(FLOW_NAME).fail(FAILURE_MESSAGE).register();
			Assert.fail('Double-register should throw IllegalStateException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Incorrect Exception Type');
			Assert.isTrue(error.getMessage().contains(FLOW_NAME), 'Error message should reference the flow name');
		}
	}

	/**
	 * @description Verifies `forFlow` rejects blank input.
	 */
	@IsTest
	private static void shouldRejectBlankFlowName()
	{
		try
		{
			TST_InvokeFlowMock.forFlow('   ');
			Assert.fail('Blank flow name should throw ConfigurationException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.ConfigurationException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Verifies invocation tracking + assertion helpers across two flows.
	 */
	@IsTest
	private static void shouldTrackInvocationsPerFlow()
	{
		Account record = (Account)TST_Builder.of(Account.SObjectType).withoutInsertion().build();

		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();
		TST_InvokeFlowMock.forFlow(OTHER_FLOW_NAME).succeed().register();

		TST_InvokeFlowMock.recordInvocation(FLOW_NAME, record, null);
		TST_InvokeFlowMock.recordInvocation(FLOW_NAME, record, null);
		TST_InvokeFlowMock.recordInvocation(OTHER_FLOW_NAME, record, null);

		Assert.isTrue(TST_InvokeFlowMock.wasInvoked(FLOW_NAME), 'Primary flow should be flagged as invoked');
		Assert.isTrue(TST_InvokeFlowMock.wasInvoked(OTHER_FLOW_NAME), 'Other flow should be flagged as invoked');

		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 2);
		TST_InvokeFlowMock.assertInvoked(OTHER_FLOW_NAME, 1);
	}

	/**
	 * @description Verifies `wasInvoked` and `assertNotInvoked` for a never-called flow.
	 */
	@IsTest
	private static void shouldReportZeroInvocationsForUntouchedFlow()
	{
		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();

		Assert.isFalse(TST_InvokeFlowMock.wasInvoked(FLOW_NAME), 'Untouched flow should not be flagged as invoked');
		TST_InvokeFlowMock.assertNotInvoked(FLOW_NAME);
		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 0);
	}

	/**
	 * @description Verifies registry lookups are case-insensitive for flow name keys.
	 */
	@IsTest
	private static void shouldNormalizeFlowNameForLookup()
	{
		Account record = (Account)TST_Builder.of(Account.SObjectType).withoutInsertion().build();

		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();
		TST_InvokeFlowMock.recordInvocation(FLOW_NAME.toUpperCase(), record, null);

		Assert.isTrue(TST_InvokeFlowMock.isMocked(FLOW_NAME.toLowerCase()), 'Lookup should be case-insensitive');
		Assert.isNotNull(TST_InvokeFlowMock.getMockResult(FLOW_NAME.toUpperCase()), 'Result lookup should ignore case');
		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 1);
	}

	/**
	 * @description Verifies `throwOnStart` stores the supplied exception on the result and
	 * flips success to false. The trigger framework reads `exceptionToThrow` and raises it
	 * at the point a real `Flow.Interview.start()` would have run, so tests can drive the
	 * runtime-error catch path without deploying a deliberately-broken flow XML.
	 */
	@IsTest
	private static void shouldStoreExceptionToThrowAndMarkFailure()
	{
		System.NullPointerException simulatedRuntimeError = new System.NullPointerException();

		TST_InvokeFlowMock.forFlow(FLOW_NAME).throwOnStart(simulatedRuntimeError).register();
		TST_InvokeFlowMock.MockResult result = TST_InvokeFlowMock.getMockResult(FLOW_NAME);

		Assert.areEqual(simulatedRuntimeError, result.exceptionToThrow, 'throwOnStart should store the supplied exception');
		Assert.isFalse(result.success, 'throwOnStart should flip success=false to mark a failure');
	}

	/**
	 * @description Verifies `getLastInputRecord` returns the SObject the most recent invocation
	 * received. Lets subscriber tests assert "the flow saw the upstream Apex action's mutation"
	 * without inspecting the trigger record's final state.
	 */
	@IsTest
	private static void shouldCaptureLastInputRecord()
	{
		Account observed = (Account)TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, INDUSTRY_VALUE)
				.withoutInsertion()
				.build();

		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();
		TST_InvokeFlowMock.recordInvocation(FLOW_NAME, observed, null);

		SObject captured = TST_InvokeFlowMock.getLastInputRecord(FLOW_NAME);

		Assert.areEqual(observed, captured, 'Captured input should be the same SObject reference');
		Assert.areEqual(INDUSTRY_VALUE, ((Account)captured).Industry, 'Captured input should preserve Industry value');
		Assert.isNull(TST_InvokeFlowMock.getLastInputPriorRecord(FLOW_NAME), 'No priorRecord supplied → getLastInputPriorRecord returns null');
	}

	/**
	 * @description Verifies `getLastInputPriorRecord` returns the priorRecord supplied to update
	 * contexts (BEFORE_UPDATE, AFTER_UPDATE) so subscriber tests can assert the flow saw both
	 * sides of the field-change pair.
	 */
	@IsTest
	private static void shouldCaptureLastInputPriorRecord()
	{
		Account newRecord = (Account)TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, INDUSTRY_VALUE)
				.withoutInsertion()
				.build();
		Account priorRecord = (Account)TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, PRIOR_INDUSTRY_VALUE)
				.withoutInsertion()
				.build();

		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();
		TST_InvokeFlowMock.recordInvocation(FLOW_NAME, newRecord, priorRecord);

		SObject capturedNew = TST_InvokeFlowMock.getLastInputRecord(FLOW_NAME);
		SObject capturedPrior = TST_InvokeFlowMock.getLastInputPriorRecord(FLOW_NAME);

		Assert.areEqual(INDUSTRY_VALUE, ((Account)capturedNew).Industry, 'New record should expose post-update Industry');
		Assert.areEqual(PRIOR_INDUSTRY_VALUE, ((Account)capturedPrior).Industry, 'Prior record should expose pre-update Industry');
	}

	/**
	 * @description Verifies the input getters return the record from the MOST RECENT
	 * invocation when a single flow is invoked multiple times.
	 */
	@IsTest
	private static void shouldReturnLastInputAcrossMultipleInvocations()
	{
		Account firstRecord = (Account)TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, PRIOR_INDUSTRY_VALUE)
				.withoutInsertion()
				.build();
		Account secondRecord = (Account)TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, INDUSTRY_VALUE)
				.withoutInsertion()
				.build();

		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();
		TST_InvokeFlowMock.recordInvocation(FLOW_NAME, firstRecord, null);
		TST_InvokeFlowMock.recordInvocation(FLOW_NAME, secondRecord, null);

		SObject captured = TST_InvokeFlowMock.getLastInputRecord(FLOW_NAME);

		Assert.areEqual(secondRecord, captured, 'getLastInputRecord should return the most recent invocation, not the first');
		TST_InvokeFlowMock.assertInvoked(FLOW_NAME, 2);
	}

	/**
	 * @description Verifies the input getters return null for flows that have not been
	 * invoked, so test authors get a clean diagnostic instead of an out-of-bounds error.
	 */
	@IsTest
	private static void shouldReturnNullForUninvokedFlow()
	{
		TST_InvokeFlowMock.forFlow(FLOW_NAME).succeed().register();

		Assert.isNull(TST_InvokeFlowMock.getLastInputRecord(FLOW_NAME), 'Uninvoked flow returns null record');
		Assert.isNull(TST_InvokeFlowMock.getLastInputPriorRecord(FLOW_NAME), 'Uninvoked flow returns null priorRecord');
		Assert.isNull(TST_InvokeFlowMock.getLastInputRecord(OTHER_FLOW_NAME), 'Unregistered flow returns null record');
	}
}