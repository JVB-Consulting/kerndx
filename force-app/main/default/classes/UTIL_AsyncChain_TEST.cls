// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Comprehensive tests for UTIL_AsyncChain — the async chain orchestration framework.
 * Covers the asynchronous execution path via Queueable, ChainBuilder fluent API,
 * ChainContext state management, StepResult factory methods, error/completion handlers,
 * kill switch, mock integration, and edge cases.
 *
 * @see UTIL_AsyncChain
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date April 2026, June 2026
 */
@IsTest(SeeAllData=false IsParallel=false)
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.NcssTypeCount')
private class UTIL_AsyncChain_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'UTIL_AsyncChain_TEST-admin';
	private static final String LOW_PRIVILEGE_COMPANY = 'UTIL_AsyncChain_TEST-low-privilege';

	/**
	 * @description Name used for test chains.
	 */
	private static final String TEST_CHAIN_NAME = 'TestChain';

	/**
	 * @description The API handler class name used by ApiStep tests.
	 */
	private static final String API_STEP_SERVICE_NAME = API_PostExample.class.getName();

	/**
	 * @description Creates a dedicated test admin user so System.runAs in each test starts a fresh
	 * permission-evaluation context, bypassing the synthetic-org permission-cache staleness issue
	 * that affected mutating the running user's permissionSet mid-transaction. Also commits a
	 * low-privilege user (Minimum Access - Salesforce profile) so the tier-A regression test
	 * (shouldCompleteChainForLowPrivilegeUser) can use System.runAs without triggering
	 * MIXED_DML_OPERATION — User is a Setup object, User DML cannot mix with standard/custom-object
	 * DML in the same transaction; pre-provisioning here satisfies that boundary.
	 */
	@TestSetup
	private static void setupTestUsers()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);

		User lowPrivilegeUser = TST_Factory.newMinimumAccessUser(LOW_PRIVILEGE_COMPANY);
		insert lowPrivilegeUser;
	}

	/**
	 * @description Verifies that a simple linear chain of three success steps completes
	 * with correct status, completedSteps, and totalSteps.
	 */
	@IsTest
	private static void shouldCompleteSimpleLinearChain()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = executeThreeStepSuccessChain();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should be Completed');
			Assert.areEqual(3, execution.TotalSteps__c, 'Total steps should be 3');
			Assert.areEqual(3, execution.CompletedSteps__c, 'Completed steps should be 3');
			Assert.isNotNull(execution.CompletedAt__c, 'CompletedAt should be set');
		}
	}

	/**
	 * @description Verifies that context values written by one step are readable by the next step.
	 */
	@IsTest
	private static void shouldPassContextBetweenSteps()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withInitialContext('testKey', 'hello')
					.then(new UTIL_AsyncChain_TEST.ContextReaderStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Map<String, Object> contextData = (Map<String, Object>)JSON.deserializeUntyped(execution.ContextData__c);
			Assert.areEqual('hello', contextData.get('readValue'), 'ContextReaderStep should read seeded value');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete');
		}
	}

	/**
	 * @description Verifies that getStatus returns a properly structured map with all expected keys.
	 */
	@IsTest
	private static void shouldReturnStatusAsMap()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			Map<String, Object> status = UTIL_AsyncChain.getStatus(executionId);
			Assert.isNotNull(status, 'Status map should not be null');
			Assert.areEqual(executionId, status.get('executionId'), 'executionId should match');
			Assert.areEqual(TEST_CHAIN_NAME, status.get('chainName'), 'chainName should match');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, status.get('status'), 'status should be Completed');
			Assert.isTrue(status.containsKey('totalSteps'), 'Should contain totalSteps key');
			Assert.isTrue(status.containsKey('completedSteps'), 'Should contain completedSteps key');
			Assert.isTrue(status.containsKey('errorMessage'), 'Should contain errorMessage key');
		}
	}

	/**
	 * @description Verifies that getStatus returns null for a nonexistent execution ID.
	 */
	@IsTest
	private static void shouldReturnNullStatusForInvalidId()
	{
		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c dummy = new AsyncChainExecution__c(
					ChainName__c = 'Dummy',
					Status__c = SEL_AsyncChainExecution.STATUS_RUNNING,
					TotalSteps__c = 0,
					CompletedSteps__c = 0,
					CorrelationId__c = UTIL_Random.randomUUID()
			);
			DML_Builder.newTransaction().doInsert(dummy).execute();
			DML_Builder.newTransaction().doDelete(dummy).execute();

			Map<String, Object> status = UTIL_AsyncChain.getStatus(dummy.Id);
			Assert.isNull(status, 'Status should be null for deleted record');
		}
	}

	/**
	 * @description Verifies that getChainStatus maps every scalar of a persisted execution onto the
	 * typed ChainStatus value object, and that a Completed chain reports terminal (not running, not failed).
	 */
	@IsTest
	private static void shouldReturnTypedChainStatusForExistingExecution()
	{
		System.runAs(getTestAdmin())
		{
			String correlationId = UTIL_Random.randomUUID();
			Datetime startedAt = Datetime.newInstanceGmt(2026, 6, 26, 10, 0, 0);
			Datetime completedAt = Datetime.newInstanceGmt(2026, 6, 26, 10, 0, 5);

			AsyncChainExecution__c record = persistExecution(new AsyncChainExecution__c(
					ChainName__c = TEST_CHAIN_NAME,
					Status__c = SEL_AsyncChainExecution.STATUS_COMPLETED,
					CurrentStepName__c = 'FinalStep',
					CorrelationId__c = correlationId,
					TotalSteps__c = 3,
					CompletedSteps__c = 3,
					ErrorMessage__c = null,
					StartedAt__c = startedAt,
					CompletedAt__c = completedAt,
					DurationMs__c = 4200
			));

			UTIL_AsyncChain.ChainStatus status = UTIL_AsyncChain.getChainStatus(record.Id);

			Assert.isNotNull(status, 'ChainStatus should not be null for an existing execution');
			Assert.areEqual(record.Id, status.executionId, 'executionId should map');
			Assert.areEqual(TEST_CHAIN_NAME, status.chainName, 'chainName should map');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, status.status, 'status should map');
			Assert.areEqual('FinalStep', status.currentStepName, 'currentStepName should map');
			Assert.areEqual(correlationId, status.correlationId, 'correlationId should map');
			Assert.areEqual(3, status.totalSteps, 'totalSteps should map');
			Assert.areEqual(3, status.completedSteps, 'completedSteps should map');
			Assert.isNull(status.errorMessage, 'errorMessage should be null for a Completed chain');
			Assert.areEqual(startedAt, status.startedAt, 'startedAt should map');
			Assert.areEqual(completedAt, status.completedAt, 'completedAt should map');
			Assert.areEqual(4200L, status.durationMs, 'durationMs should map the stored value');
			Assert.areEqual(UTIL_Date.formatDuration(4200L), status.durationLabel, 'durationLabel should derive from durationMs');
			Assert.isTrue(status.isTerminal(), 'A Completed chain is terminal');
			Assert.isFalse(status.isRunning(), 'A Completed chain is not running');
			Assert.isFalse(status.isFailed(), 'A Completed chain is not failed');
		}
	}

	/**
	 * @description Verifies that getChainStatus computes a live duration for a Running chain whose
	 * DurationMs__c is not yet persisted, mirroring the Chain Monitor's live-duration rule.
	 */
	@IsTest
	private static void shouldComputeLiveDurationForRunningChainStatus()
	{
		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c record = persistExecution(new AsyncChainExecution__c(
					ChainName__c = TEST_CHAIN_NAME,
					Status__c = SEL_AsyncChainExecution.STATUS_RUNNING,
					CorrelationId__c = UTIL_Random.randomUUID(),
					TotalSteps__c = 3,
					CompletedSteps__c = 1,
					StartedAt__c = Datetime.now().addMinutes(-2),
					DurationMs__c = null
			));

			UTIL_AsyncChain.ChainStatus status = UTIL_AsyncChain.getChainStatus(record.Id);

			Assert.isNotNull(status, 'ChainStatus should not be null for a Running execution');
			Assert.isNotNull(status.durationMs, 'A Running chain with no stored duration should report a live duration');
			Assert.isTrue(status.durationMs >= 0, 'Live duration should be non-negative');
			Assert.isNotNull(status.durationLabel, 'durationLabel should be derived from the live duration');
			Assert.isTrue(status.isRunning(), 'A Running chain reports running');
			Assert.isFalse(status.isTerminal(), 'A Running chain is not terminal');
			Assert.isFalse(status.isFailed(), 'A Running chain is not failed');
		}
	}

	/**
	 * @description Verifies that getChainStatus reflects a Failed chain through the helper predicates
	 * and maps the error message.
	 */
	@IsTest
	private static void shouldReflectFailedStatusInChainStatusHelpers()
	{
		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c record = persistExecution(new AsyncChainExecution__c(
					ChainName__c = TEST_CHAIN_NAME,
					Status__c = SEL_AsyncChainExecution.STATUS_FAILED,
					CorrelationId__c = UTIL_Random.randomUUID(),
					TotalSteps__c = 3,
					CompletedSteps__c = 1,
					ErrorMessage__c = 'Step 2 blew up',
					StartedAt__c = Datetime.now().addMinutes(-1),
					DurationMs__c = 60000
			));

			UTIL_AsyncChain.ChainStatus status = UTIL_AsyncChain.getChainStatus(record.Id);

			Assert.isNotNull(status, 'ChainStatus should not be null for a Failed execution');
			Assert.areEqual('Step 2 blew up', status.errorMessage, 'errorMessage should map');
			Assert.isTrue(status.isFailed(), 'A Failed chain reports failed');
			Assert.isTrue(status.isTerminal(), 'A Failed chain is terminal');
			Assert.isFalse(status.isRunning(), 'A Failed chain is not running');
		}
	}

	/**
	 * @description Verifies that getChainStatus returns null for a nonexistent execution ID.
	 */
	@IsTest
	private static void shouldReturnNullChainStatusForMissingId()
	{
		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c dummy = new AsyncChainExecution__c(
					ChainName__c = 'Dummy',
					Status__c = SEL_AsyncChainExecution.STATUS_RUNNING,
					TotalSteps__c = 0,
					CompletedSteps__c = 0,
					CorrelationId__c = UTIL_Random.randomUUID()
			);
			DML_Builder.newTransaction().doInsert(dummy).execute();
			DML_Builder.newTransaction().doDelete(dummy).execute();

			UTIL_AsyncChain.ChainStatus status = UTIL_AsyncChain.getChainStatus(dummy.Id);
			Assert.isNull(status, 'ChainStatus should be null for a deleted record');
		}
	}

	/**
	 * @description Regression lock: getChainStatus must not change the frozen getStatus(Id) map — it
	 * still returns exactly the six documented keys with matching values.
	 */
	@IsTest
	private static void shouldLeaveGetStatusMapUnchanged()
	{
		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c record = persistExecution(new AsyncChainExecution__c(
					ChainName__c = TEST_CHAIN_NAME,
					Status__c = SEL_AsyncChainExecution.STATUS_COMPLETED,
					CorrelationId__c = UTIL_Random.randomUUID(),
					TotalSteps__c = 2,
					CompletedSteps__c = 2,
					ErrorMessage__c = null
			));

			Map<String, Object> status = UTIL_AsyncChain.getStatus(record.Id);

			Assert.areEqual(6, status.size(), 'getStatus must still return exactly six keys');
			Assert.areEqual(record.Id, status.get('executionId'), 'executionId key unchanged');
			Assert.areEqual(TEST_CHAIN_NAME, status.get('chainName'), 'chainName key unchanged');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, status.get('status'), 'status key unchanged');
			Assert.areEqual(2, status.get('totalSteps'), 'totalSteps key unchanged');
			Assert.areEqual(2, status.get('completedSteps'), 'completedSteps key unchanged');
			Assert.isTrue(status.containsKey('errorMessage'), 'errorMessage key unchanged');
		}
	}

	/**
	 * @description Sharing parity with getStatus: a non-owner must not read another user's Private-OWD
	 * chain via getChainStatus. The admin owns the row; a low-privilege non-owner reads null.
	 */
	@IsTest
	private static void shouldNotLeakOtherUsersChainViaGetChainStatus()
	{
		AsyncChainExecution__c record;

		System.runAs(getTestAdmin())
		{
			record = persistExecution(new AsyncChainExecution__c(
					ChainName__c = TEST_CHAIN_NAME,
					Status__c = SEL_AsyncChainExecution.STATUS_RUNNING,
					CorrelationId__c = UTIL_Random.randomUUID(),
					TotalSteps__c = 1,
					CompletedSteps__c = 0,
					StartedAt__c = Datetime.now()
			));
		}

		System.runAs(getLowPrivilegeUser())
		{
			UTIL_AsyncChain.ChainStatus status = UTIL_AsyncChain.getChainStatus(record.Id);
			Assert.isNull(status, 'A non-owner must not read another user\'s Private-OWD chain via getChainStatus');
		}
	}

	/**
	 * @description Verifies that the bulk getChainStatuses accessor maps a set of IDs to ChainStatus
	 * objects in a single query, omitting IDs that do not resolve to a record.
	 */
	@IsTest
	private static void shouldReturnChainStatusesForBulkIds()
	{
		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c first = persistExecution(new AsyncChainExecution__c(
					ChainName__c = TEST_CHAIN_NAME,
					Status__c = SEL_AsyncChainExecution.STATUS_COMPLETED,
					CorrelationId__c = UTIL_Random.randomUUID(),
					TotalSteps__c = 1,
					CompletedSteps__c = 1
			));
			AsyncChainExecution__c second = persistExecution(new AsyncChainExecution__c(
					ChainName__c = TEST_CHAIN_NAME,
					Status__c = SEL_AsyncChainExecution.STATUS_FAILED,
					CorrelationId__c = UTIL_Random.randomUUID(),
					TotalSteps__c = 2,
					CompletedSteps__c = 1,
					ErrorMessage__c = 'boom'
			));
			AsyncChainExecution__c removed = new AsyncChainExecution__c(
					ChainName__c = 'Removed',
					Status__c = SEL_AsyncChainExecution.STATUS_RUNNING,
					TotalSteps__c = 0,
					CompletedSteps__c = 0,
					CorrelationId__c = UTIL_Random.randomUUID()
			);
			DML_Builder.newTransaction().doInsert(removed).execute();
			Id missingId = removed.Id;
			DML_Builder.newTransaction().doDelete(removed).execute();

			Map<Id, UTIL_AsyncChain.ChainStatus> statuses =
					UTIL_AsyncChain.getChainStatuses(new Set<Id> {first.Id, second.Id, missingId});

			Assert.areEqual(2, statuses.size(), 'Only the two existing executions should resolve');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, statuses.get(first.Id).status, 'first status should map');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, statuses.get(second.Id).status, 'second status should map');
			Assert.isFalse(statuses.containsKey(missingId), 'A missing ID should be absent from the result map');
		}
	}

	/**
	 * @description Verifies that withDelayMinutes clamps to the platform Queueable-delay range (0-10):
	 * a negative value clamps to 0, an above-ceiling value clamps to 10, an in-range value is stored
	 * verbatim, and null is a no-op.
	 */
	@IsTest
	private static void shouldClampWithDelayMinutesToPlatformRange()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainBuilder builder = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME);

			builder.withDelayMinutes(-5);
			Assert.areEqual(0, builder.firstStepDelayMinutes, 'A negative delay clamps to 0');

			builder.withDelayMinutes(20);
			Assert.areEqual(10, builder.firstStepDelayMinutes, 'A delay above the platform ceiling clamps to 10');

			builder.withDelayMinutes(7);
			Assert.areEqual(7, builder.firstStepDelayMinutes, 'An in-range delay is stored verbatim');

			builder.withDelayMinutes(null);
			Assert.isNull(builder.firstStepDelayMinutes, 'A null delay is a no-op');
		}
	}

	/**
	 * @description Verifies that withDelayMinutes(0) runs and completes through the existing
	 * immediate-enqueue path, exactly as a chain with no delay (0 and unset take the same code branch).
	 */
	@IsTest
	private static void shouldExecuteImmediatelyWhenDelayZero()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withDelayMinutes(0)
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'A zero delay behaves exactly as today');
			Assert.areEqual(1, execution.CompletedSteps__c, 'The step still completes');
		}
	}

	/**
	 * @description Verifies that a chain with a first-step delay still completes Running to Completed
	 * within a test, where the platform runs the delayed Queueable at Test.stopTest().
	 */
	@IsTest
	private static void shouldCompleteDelayedChainWithinTestContext()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withDelayMinutes(5)
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'A delayed chain still completes under Test.stopTest()');
			Assert.areEqual(1, execution.CompletedSteps__c, 'The delayed first step completes');
		}
	}

	/**
	 * @description Verifies the delay applies only to the first enqueue and never contaminates the
	 * shared AsyncOptions the Finalizer reuses to re-enqueue later steps. Asserts directly that the
	 * AsyncOptions instance is left unmutated after execute() (no delay stamped on it, stack depth
	 * unchanged), so a regression that wrote the delay onto the shared options would be caught at source
	 * rather than relying on chain completion (the platform ignores enqueue delays under Test.stopTest).
	 */
	@IsTest
	private static void shouldDelayOnlyTheFirstEnqueue()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncOptions sharedOptions = createAsyncOptions(4);

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withDelayMinutes(5)
					.withAsyncOptions(sharedOptions)
					.execute();
			Test.stopTest();

			Assert.isNull(sharedOptions.minimumQueueableDelayInMinutes,
					'The first-step delay must never be stamped on the shared AsyncOptions the Finalizer reuses for later steps');
			Assert.areEqual(4, sharedOptions.maximumQueueableStackDepth, 'execute() must not mutate the shared AsyncOptions');

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Later steps run normally after a delayed first step');
			Assert.areEqual(3, execution.TotalSteps__c, 'All three steps are present');
			Assert.areEqual(3, execution.CompletedSteps__c, 'All three steps complete');
		}
	}

	/**
	 * @description Verifies that a chain with no steps completes immediately with zero completed steps.
	 */
	@IsTest
	private static void shouldExecuteEmptyChain()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Empty chain should be Completed');
			Assert.areEqual(0, execution.TotalSteps__c, 'Total steps should be 0');
			Assert.areEqual(0, execution.CompletedSteps__c, 'Completed steps should be 0');
		}
	}

	/**
	 * @description Verifies that a chain fails when a step returns a failed StepResult.
	 */
	@IsTest
	private static void shouldFailChainWhenStepFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.then(new UTIL_AsyncChain_TEST.FailingStep())
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(4))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should be Failed');
			Assert.isTrue(execution.ErrorMessage__c.contains('Deliberate failure'), 'Error message should contain failure reason');
			Assert.areEqual(1, execution.CompletedSteps__c, 'Only the first successful step should be counted');
		}
	}

	/**
	 * @description Verifies that a chain fails when a step throws an unhandled exception.
	 */
	@IsTest
	private static void shouldFailChainWhenStepThrowsException()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.ExceptionStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should be Failed');
			Assert.isTrue(execution.ErrorMessage__c.contains('Deliberate exception'), 'Error message should contain exception message');
		}
	}

	/**
	 * @description Verifies that the error handler step executes when a step fails.
	 */
	@IsTest
	private static void shouldInvokeErrorHandlerOnFailure()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.FailingStep())
					.onError(new UTIL_AsyncChain_TEST.ErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Map<String, Object> contextData = (Map<String, Object>)JSON.deserializeUntyped(execution.ContextData__c);
			Assert.isTrue((Boolean)contextData.get('errorHandlerExecuted'), 'Error handler should have been executed');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should still be Failed');
		}
	}

	/**
	 * @description Verifies that when the error handler itself throws, both error messages are recorded.
	 */
	@IsTest
	private static void shouldRecordBothErrorsWhenErrorHandlerFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.FailingStep())
					.onError(new UTIL_AsyncChain_TEST.FailingErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should be Failed');
			Assert.isTrue(execution.ErrorMessage__c.contains('Handler failed'), 'Error message should mention handler failure');
			Assert.isTrue(execution.ErrorMessage__c.contains('Deliberate failure'), 'Error message should contain original failure');
		}
	}

	/**
	 * @description Verifies that a step with continueOnError=true does not halt the chain on failure.
	 */
	@IsTest
	private static void shouldContinueOnErrorWhenFlagSet()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.ContinueOnErrorStep())
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should be Completed despite step failure');
			Assert.areEqual(1, execution.CompletedSteps__c, 'Only the successful step should be counted');
		}
	}

	/**
	 * @description Verifies that the completion handler executes after all steps succeed.
	 */
	@IsTest
	private static void shouldInvokeCompletionHandlerOnSuccess()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = executeWithCompletionHandler();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Map<String, Object> contextData = (Map<String, Object>)JSON.deserializeUntyped(execution.ContextData__c);
			Assert.isTrue((Boolean)contextData.get('completionHandlerExecuted'), 'Completion handler should have been executed');
		}
	}

	/**
	 * @description Verifies that a chain is marked as failed when the completion handler throws.
	 */
	@IsTest
	private static void shouldFailChainWhenCompletionHandlerFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.onComplete(new UTIL_AsyncChain_TEST.FailingCompletionHandlerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should be Failed');
			Assert.isTrue(execution.ErrorMessage__c.contains('Handler failed'), 'Error message should mention handler failure');
		}
	}

	/**
	 * @description Verifies that the completion handler does NOT execute when a step fails.
	 */
	@IsTest
	private static void shouldNotInvokeCompletionHandlerOnFailure()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.FailingStep())
					.onComplete(new UTIL_AsyncChain_TEST.CompletionHandlerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Map<String, Object> contextData = (Map<String, Object>)JSON.deserializeUntyped(execution.ContextData__c);
			Assert.isNull(contextData.get('completionHandlerExecuted'), 'Completion handler should not execute on failure');
		}
	}

	/**
	 * @description Verifies that multiple initial context values seeded via withInitialContext are readable in steps.
	 */
	@IsTest
	private static void shouldSeedContextFromBuilder()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withInitialContext('key1', 'val1')
					.withInitialContext('key2', 42)
					.then(new UTIL_AsyncChain_TEST.ContextSeedVerifierStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Map<String, Object> contextData = (Map<String, Object>)JSON.deserializeUntyped(execution.ContextData__c);
			Assert.areEqual('val1', contextData.get('foundKey1'), 'key1 should be val1');
			Assert.areEqual(42, contextData.get('foundKey2'), 'key2 should be 42');
		}
	}

	/**
	 * @description Verifies that context serialize and deserialize round-trips correctly.
	 */
	@IsTest
	private static void shouldSerializeAndDeserializeContext()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('test-exec-id', 'test-corr-id');
			context.put('stringKey', 'hello');
			context.put('numberKey', 99);

			String serialized = context.serialize();
			UTIL_AsyncChain.ChainContext restored = UTIL_AsyncChain.deserializeContext(serialized, 'test-exec-id', 'test-corr-id');

			Assert.areEqual('hello', restored.get('stringKey'), 'String value should survive round-trip');
			Assert.areEqual(99, restored.get('numberKey'), 'Number value should survive round-trip');
			Assert.areEqual('test-exec-id', restored.getChainExecutionId(), 'Execution ID should be set');
			Assert.areEqual('test-corr-id', restored.getCorrelationId(), 'Correlation ID should be set');
		}
	}

	/**
	 * @description Verifies that getAs deserializes a stored value to the requested type.
	 */
	@IsTest
	private static void shouldReturnTypedValueFromGetAs()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('test-exec-id', 'test-corr-id');
			context.put('names', new List<String> {'Alice', 'Bob'});

			List<String> result = (List<String>)context.getAs('names', List<String>.class);
			Assert.areEqual(2, result.size(), 'List should have 2 elements');
			Assert.areEqual('Alice', result[0], 'First element should be Alice');
		}
	}

	/**
	 * @description Verifies that getAs deserializes correctly after JSON round-trip (cross-transaction scenario).
	 */
	@IsTest
	private static void shouldDeserializeViaGetAsAfterJsonRoundTrip()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('test-exec-id', 'test-corr-id');
			context.put('names', new List<String> {'Alice', 'Bob'});

			String serialized = context.serialize();
			UTIL_AsyncChain.ChainContext restored = UTIL_AsyncChain.deserializeContext(serialized, 'test-exec-id', 'test-corr-id');

			List<String> result = (List<String>)restored.getAs('names', List<String>.class);
			Assert.areEqual(2, result.size(), 'List should survive JSON round-trip');
			Assert.areEqual('Alice', result[0], 'First element should be Alice after round-trip');
		}
	}

	/**
	 * @description Verifies that getAs returns null for a missing key without throwing.
	 */
	@IsTest
	private static void shouldReturnNullFromGetAsForMissingKey()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('test-exec-id', 'test-corr-id');

			Object result = context.getAs('nonexistent', List<String>.class);
			Assert.isNull(result, 'getAs should return null for missing key');
		}
	}

	/**
	 * @description Verifies that the has method correctly identifies present and absent keys.
	 */
	@IsTest
	private static void shouldPutAndGetContextValues()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('test-exec-id', 'test-corr-id');
			context.put('existing', 'value');

			Assert.isTrue(context.has('existing'), 'Should have the existing key');
			Assert.isFalse(context.has('missing'), 'Should not have a missing key');
			Assert.areEqual('value', context.get('existing'), 'Should return the stored value');
			Assert.isNull(context.get('missing'), 'Should return null for missing key');
		}
	}

	/**
	 * @description Verifies that getCurrentStepIndex returns null before assignment and the set value after.
	 */
	@IsTest
	private static void shouldReturnCurrentStepIndex()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('test-exec-id', 'test-corr-id');
			Assert.isNull(context.getCurrentStepIndex(), 'Should be null before assignment');

			context.currentStepIndex = 2;
			Assert.areEqual(2, context.getCurrentStepIndex(), 'Should return assigned index');
		}
	}

	/**
	 * @description Verifies that idempotencyKey() derives the step-level key as executionId + "-" +
	 * stepIndex, and that the same context derives the same key on repeated calls (stability).
	 */
	@IsTest
	private static void shouldDeriveStepLevelIdempotencyKey()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('test-exec-id', 'test-corr-id');
			context.currentStepIndex = 2;

			String key = context.idempotencyKey();

			Assert.areEqual('test-exec-id-2', key, 'Step-level key should be executionId + "-" + stepIndex');
			Assert.areEqual(key, context.idempotencyKey(), 'The same context must derive the same step-level key on every call');
		}
	}

	/**
	 * @description Verifies that idempotencyKey(Id) composes the step key + "-" + recordId, that the
	 * same record Id reproduces the same key (the replay-safety property), and that different record
	 * Ids produce different keys.
	 */
	@IsTest
	private static void shouldDeriveRecordGrainIdempotencyKey()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('test-exec-id', 'test-corr-id');
			context.currentStepIndex = 2;
			Set<Id> distinctIds = new Set<Id>();
			while(distinctIds.size() < 2)
			{
				distinctIds.add(UTIL_Random.randomId(Foobar__c.SObjectType));
			}
			List<Id> recordIds = new List<Id>(distinctIds);
			Id firstRecordId = recordIds[0];
			Id secondRecordId = recordIds[1];

			String firstKey = context.idempotencyKey(firstRecordId);

			Assert.areEqual('test-exec-id-2-' + firstRecordId, firstKey, 'Record-grain key should be the step key + "-" + recordId');
			Assert.areEqual(firstKey, context.idempotencyKey(firstRecordId), 'The same record Id must reproduce the same key (replay-safety)');
			Assert.areNotEqual(firstKey, context.idempotencyKey(secondRecordId), 'Different record Ids must produce different keys');
		}
	}

	/**
	 * @description Verifies that idempotencyKey(String) composes the step key + "-" + grain, and that
	 * a long grain passes through verbatim with no hashing or truncation (the opaque-token contract).
	 */
	@IsTest
	private static void shouldDeriveStringGrainIdempotencyKey()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('test-exec-id', 'test-corr-id');
			context.currentStepIndex = 2;

			Assert.areEqual('test-exec-id-2-orderLine-7', context.idempotencyKey('orderLine-7'),
					'String-grain key should compose the step key + "-" + grain');

			String longGrain = 'x'.repeat(500);
			Assert.areEqual('test-exec-id-2-' + longGrain, context.idempotencyKey(longGrain),
					'A long grain must pass through verbatim — the helper never hashes or truncates');
		}
	}

	/**
	 * @description Verifies the null-handling contract: a null record Id, a null String grain, and a
	 * blank/whitespace String grain all fall back to the bare step-level key (no trailing delimiter,
	 * no "null" literal). Typed locals disambiguate the overloads (a bare null literal is a compile
	 * error — Ambiguous method signature).
	 */
	@IsTest
	private static void shouldFallBackToStepKeyForNullOrBlankGrain()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('test-exec-id', 'test-corr-id');
			context.currentStepIndex = 2;
			Id nullRecordId = null;
			String nullGrain = null;

			Assert.areEqual('test-exec-id-2', context.idempotencyKey(nullRecordId),
					'A null record Id must fall back to the bare step-level key');
			Assert.areEqual('test-exec-id-2', context.idempotencyKey(nullGrain),
					'A null String grain must fall back to the bare step-level key');
			Assert.areEqual('test-exec-id-2', context.idempotencyKey('   '),
					'A blank/whitespace String grain must fall back to the bare step-level key');
		}
	}

	/**
	 * @description Proves the record-grain helper is safe to call once per record in a fan-out loop:
	 * deriving keys for several records issues no SOQL and no DML (a zero-delta snapshot of getQueries
	 * and getDmlStatements), and distinct records yield distinct, exactly-composed keys. The derivation
	 * is pure string composition with no hashing or truncation, so a handful of records is sufficient —
	 * no large volume is needed to demonstrate the no-collision and zero-cost properties. (Single-record
	 * composition, reproducibility, and the null/blank fallbacks are covered by the focused tests above.)
	 */
	@IsTest
	private static void shouldDeriveRecordGrainKeysInALoopWithoutGovernorCost()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('test-exec-id', 'test-corr-id');
			context.currentStepIndex = 2;

			Set<Id> recordIds = new Set<Id>();
			while(recordIds.size() < 5)
			{
				recordIds.add(UTIL_Random.randomId(Foobar__c.SObjectType));
			}

			Integer queriesBefore = Limits.getQueries();
			Integer dmlBefore = Limits.getDmlStatements();

			Set<String> keys = new Set<String>();
			for(Id recordId : recordIds)
			{
				String key = context.idempotencyKey(recordId);
				Assert.areEqual('test-exec-id-2-' + recordId, key, 'Each record-grain key must be the step key + "-" + recordId');
				keys.add(key);
			}

			Assert.areEqual(recordIds.size(), keys.size(), 'Distinct record Ids must yield the same number of distinct keys (no collision)');
			Assert.areEqual(queriesBefore, Limits.getQueries(), 'Deriving keys must issue no SOQL (zero query cost)');
			Assert.areEqual(dmlBefore, Limits.getDmlStatements(), 'Deriving keys must issue no DML (zero DML cost)');
		}
	}

	/**
	 * @description Verifies that deserialize handles blank serialized data gracefully.
	 */
	@IsTest
	private static void shouldHandleBlankSerializedData()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = UTIL_AsyncChain.deserializeContext('', 'test-exec-id', 'test-corr-id');
			Assert.isFalse(context.has('anything'), 'Blank data should produce empty context');

			UTIL_AsyncChain.ChainContext nullContext = UTIL_AsyncChain.deserializeContext(null, 'test-exec-id', 'test-corr-id');
			Assert.isFalse(nullContext.has('anything'), 'Null data should produce empty context');
		}
	}

	/**
	 * @description Verifies that StepResult.succeeded() creates a successful result with no message.
	 */
	@IsTest
	private static void shouldCreateSucceededResult()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.StepResult result = UTIL_AsyncChain.succeeded();
			Assert.isTrue(result.success, 'Result should be successful');
			Assert.isNull(result.message, 'Message should be null');
			Assert.isNull(result.data, 'Data should be null');
		}
	}

	/**
	 * @description Verifies that StepResult.succeeded(message) creates a successful result with a message.
	 */
	@IsTest
	private static void shouldCreateSucceededResultWithMessage()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.StepResult result = UTIL_AsyncChain.succeeded('Done processing');
			Assert.isTrue(result.success, 'Result should be successful');
			Assert.areEqual('Done processing', result.message, 'Message should match');
		}
	}

	/**
	 * @description Verifies that StepResult.succeeded(message, data) creates a result with data payload.
	 */
	@IsTest
	private static void shouldCreateSucceededResultWithData()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.StepResult result = UTIL_AsyncChain.succeeded('Data step', 42);
			Assert.isTrue(result.success, 'Result should be successful');
			Assert.areEqual('Data step', result.message, 'Message should match');
			Assert.areEqual(42, result.data, 'Data should be 42');
		}
	}

	/**
	 * @description Verifies that StepResult.failed(message) creates a failed result.
	 */
	@IsTest
	private static void shouldCreateFailedResult()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.StepResult result = UTIL_AsyncChain.failed('Something broke');
			Assert.isFalse(result.success, 'Result should not be successful');
			Assert.areEqual('Something broke', result.message, 'Message should match');
		}
	}

	/**
	 * @description Verifies that StepResult.failed(exception) captures the exception reference and message.
	 */
	@IsTest
	private static void shouldCreateFailedResultFromException()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_Exceptions.IllegalStateException testException = new UTIL_Exceptions.IllegalStateException('Test error');
			UTIL_AsyncChain.StepResult result = UTIL_AsyncChain.failed(testException);
			Assert.isFalse(result.success, 'Result should not be successful');
			Assert.areEqual('Test error', result.message, 'Message should come from exception');
			Assert.isNotNull(result.error, 'Error reference should be set');
		}
	}

	/**
	 * @description Verifies that a step can access the result of the previous step via context.
	 */
	@IsTest
	private static void shouldAccessPreviousStepResult()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.DataStep())
					.then(new UTIL_AsyncChain_TEST.PreviousResultReaderStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Map<String, Object> contextData = (Map<String, Object>)JSON.deserializeUntyped(execution.ContextData__c);
			Assert.areEqual(42, contextData.get('previousData'), 'Previous step data should be 42');
		}
	}

	/**
	 * @description Verifies that setPreviousStepResult correctly stores and returns the result.
	 */
	@IsTest
	private static void shouldSetAndGetPreviousStepResult()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('test-exec-id', 'test-corr-id');
			Assert.isNull(context.getPreviousStepResult(), 'Should be null initially');

			UTIL_AsyncChain.StepResult result = UTIL_AsyncChain.succeeded('test');
			context.setPreviousStepResult(result);
			Assert.areEqual(result, context.getPreviousStepResult(), 'Should return set result');
		}
	}

	/**
	 * @description Verifies that the chain is aborted when the AsyncChain feature flag is disabled.
	 */
	@IsTest
	private static void shouldAbortChainWhenKillSwitchActive()
	{
		System.runAs(getTestAdmin())
		{
			setupDisabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.TrackingStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, execution.Status__c, 'Chain should be Aborted');
			Assert.isTrue(execution.ErrorMessage__c.contains('Kill switch'), 'Error message should mention kill switch');
			Map<String, Object> contextData = parseContextData(execution);
			Assert.isNull(contextData.get('trackingStepExecuted'), 'Step should not have executed');
		}
	}

	/**
	 * @description Verifies the build-time `then()` guard fires when the next step would
	 * push the chain past `maxSteps`, BEFORE any execution begins. Replaces an older runtime
	 * "Max steps exceeded" assertion path: that path was reachable only via
	 * `ChainExecutor.execute` after enqueue, by which point partial work may already have
	 * committed. The build-time guard fails the subscriber at definition time, before any
	 * AsyncChainExecution__c row is inserted.
	 */
	@IsTest
	private static void shouldFailAtBuildTimeWhenMaxStepsExceeded()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			try
			{
				UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
						.withMaxSteps(1)
						.then(new UTIL_AsyncChain_TEST.SuccessStep())
						.then(new UTIL_AsyncChain_TEST.SuccessStep());
				Assert.fail('Build-time guard should have rejected the second .then() call');
			}
			catch(UTIL_Exceptions.IllegalStateException expected)
			{
				Assert.isTrue(expected.getMessage().contains('maxSteps=1'),
						'Exception message should report the configured maxSteps. Got: ' + expected.getMessage());
				Assert.isTrue(expected.getMessage().contains('.withMaxSteps'),
						'Exception message should suggest .withMaxSteps as the remediation. Got: ' + expected.getMessage());
			}

			Assert.isTrue(new SEL_AsyncChainExecution().findByChainName(TEST_CHAIN_NAME).isEmpty(),
					'Build-time guard must throw before any execution row is inserted');
		}
	}

	/**
	 * @description Verifies that a caller-supplied correlation ID is persisted on the execution record.
	 */
	@IsTest
	private static void shouldUseProvidedCorrelationId()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String correlationId = 'my-custom-correlation-id';
			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute(correlationId);
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(correlationId, execution.CorrelationId__c, 'Correlation ID should match');
		}
	}

	/**
	 * @description Verifies that execute() without a correlation ID auto-generates one.
	 */
	@IsTest
	private static void shouldAutoGenerateCorrelationId()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.isNotNull(execution.CorrelationId__c, 'Auto-generated correlation ID should not be null');
		}
	}

	/**
	 * @description Verifies that execute returns a non-null execution record ID.
	 */
	@IsTest
	private static void shouldReturnExecutionIdFromExecute()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			Assert.isNotNull(executionId, 'Execution ID should not be null');
		}
	}

	/**
	 * @description Verifies that withMaxContextSize accepts a custom value and the chain executes without error.
	 */
	@IsTest
	private static void shouldAcceptCustomMaxContextSize()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withMaxContextSize(65536)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete with custom max context size');
		}
	}

	/**
	 * @description Verifies that a custom stepName is stored on the execution record.
	 */
	@IsTest
	private static void shouldUseCustomStepName()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.NamedStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual('CustomNamedStep', execution.CurrentStepName__c, 'Custom step name should be used');
		}
	}

	/**
	 * @description Verifies that the class name is used as step name when stepName is blank.
	 */
	@IsTest
	private static void shouldUseClassNameWhenStepNameBlank()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.isTrue(String.isNotBlank(execution.CurrentStepName__c), 'Class name should be used as step name');
		}
	}

	/**
	 * @description Verifies that steps can increment a shared counter across the chain.
	 */
	@IsTest
	private static void shouldTrackStepCountInContext()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = executeThreeStepSuccessChain();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Map<String, Object> contextData = parseContextData(execution);
			Assert.areEqual(3, contextData.get('stepCount'), 'Step count should be 3 after three steps');
		}
	}

	/**
	 * @description Verifies that the error handler is NOT invoked when all steps succeed.
	 */
	@IsTest
	private static void shouldNotInvokeErrorHandlerOnSuccess()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.onError(new UTIL_AsyncChain_TEST.ErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Map<String, Object> contextData = (Map<String, Object>)JSON.deserializeUntyped(execution.ContextData__c);
			Assert.isNull(contextData.get('errorHandlerExecuted'), 'Error handler should not execute on success');
		}
	}

	/**
	 * @description Verifies that both error and completion handlers can be configured
	 * and only the completion handler runs on success.
	 */
	@IsTest
	private static void shouldRunOnlyCompletionHandlerOnSuccess()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.onError(new UTIL_AsyncChain_TEST.ErrorHandlerStep())
					.onComplete(new UTIL_AsyncChain_TEST.CompletionHandlerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Map<String, Object> contextData = (Map<String, Object>)JSON.deserializeUntyped(execution.ContextData__c);
			Assert.isTrue((Boolean)contextData.get('completionHandlerExecuted'), 'Completion handler should run on success');
			Assert.isNull(contextData.get('errorHandlerExecuted'), 'Error handler should not run on success');
		}
	}

	/**
	 * @description Verifies that both error and completion handlers can be configured
	 * and only the error handler runs on failure.
	 */
	@IsTest
	private static void shouldRunOnlyErrorHandlerOnFailure()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.FailingStep())
					.onError(new UTIL_AsyncChain_TEST.ErrorHandlerStep())
					.onComplete(new UTIL_AsyncChain_TEST.CompletionHandlerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Map<String, Object> contextData = (Map<String, Object>)JSON.deserializeUntyped(execution.ContextData__c);
			Assert.isTrue((Boolean)contextData.get('errorHandlerExecuted'), 'Error handler should run on failure');
			Assert.isNull(contextData.get('completionHandlerExecuted'), 'Completion handler should not run on failure');
		}
	}

	/**
	 * @description Verifies that execute() throws on double-execution of the same builder.
	 */
	@IsTest
	private static void shouldThrowOnDoubleExecution()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			UTIL_AsyncChain.ChainBuilder builder = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep());

			Test.startTest();
			builder.execute();
			Test.stopTest();

			try
			{
				builder.execute();
				Assert.fail('Should throw on double execution');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Should be IllegalStateException');
			}
		}
	}

	/**
	 * @description Verifies that DTO_StepDefinition fields are accessible and default values are correct.
	 */
	@IsTest
	private static void shouldInitializeDtoStepDefinitionDefaults()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.DTO_StepDefinition definition = new UTIL_AsyncChain.DTO_StepDefinition();
			definition.className = 'TestClassName';
			definition.stepName = 'TestStepName';

			Assert.areEqual('TestClassName', definition.className, 'className should match');
			Assert.areEqual('TestStepName', definition.stepName, 'stepName should match');
			Assert.isNull(definition.continueOnError, 'continueOnError should default to null (suppressed from JSON)');
			Assert.isNull(definition.isErrorHandler, 'isErrorHandler should default to null (suppressed from JSON)');
			Assert.isNull(definition.isCompletionHandler, 'isCompletionHandler should default to null (suppressed from JSON)');
		}
	}

	/**
	 * @description Verifies that ChainStep properties have correct defaults and can be set.
	 */
	@IsTest
	private static void shouldExposeChainStepProperties()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain_TEST.SuccessStep step = new UTIL_AsyncChain_TEST.SuccessStep();
			Assert.isFalse(step.continueOnError, 'continueOnError should default to false');
			Assert.isNull(step.stepName, 'stepName should default to null');

			step.continueOnError = true;
			step.stepName = 'CustomName';

			Assert.isTrue(step.continueOnError, 'continueOnError should be settable');
			Assert.areEqual('CustomName', step.stepName, 'stepName should be settable');
		}
	}

	/**
	 * @description Verifies that the final context state is persisted to the execution record.
	 */
	@IsTest
	private static void shouldPersistContextAfterExecution()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withInitialContext('initial', 'value')
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.isNotNull(execution.ContextData__c, 'Context data should be persisted');
			Map<String, Object> contextData = (Map<String, Object>)JSON.deserializeUntyped(execution.ContextData__c);
			Assert.areEqual('value', contextData.get('initial'), 'Initial context value should be preserved');
			Assert.isTrue(contextData.containsKey('stepCount'), 'Step modifications should be persisted');
		}
	}

	/**
	 * @description Verifies that StartedAt is set when the chain is created.
	 */
	@IsTest
	private static void shouldSetStartedAtTimestamp()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Datetime beforeExecution = Datetime.now().addSeconds(-2);
			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.isNotNull(execution.StartedAt__c, 'StartedAt should be set');
			Assert.isTrue(execution.StartedAt__c >= beforeExecution, 'StartedAt should be within tolerance of test start');
		}
	}

	/**
	 * @description Verifies that the error handler has access to context values set by earlier steps.
	 */
	@IsTest
	private static void shouldPassContextToErrorHandler()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withInitialContext('testKey', 'available')
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.then(new UTIL_AsyncChain_TEST.FailingStep())
					.onError(new UTIL_AsyncChain_TEST.ContextCheckingErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Map<String, Object> contextData = (Map<String, Object>)JSON.deserializeUntyped(execution.ContextData__c);
			Assert.isTrue((Boolean)contextData.get('errorHandlerHadContext'), 'Error handler should have access to context');
		}
	}

	/**
	 * @description Verifies that newChain creates a builder that persists the chain name.
	 */
	@IsTest
	private static void shouldPersistChainNameFromNewChain()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain('MySpecialChain')
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual('MySpecialChain', execution.ChainName__c, 'Chain name should be persisted');
		}
	}

	/**
	 * @description Verifies that the single-arg then(ChainStep) overload resolves the class name
	 * via UTIL_System.getRuntimeTypeName and the chain completes successfully.
	 */
	@IsTest
	private static void shouldResolveClassNameFromInstance()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Single-arg then() should resolve class name and complete');
		}
	}

	/**
	 * @description Verifies that the asynchronous ChainExecutor exits early without executing
	 * the step when the execution record has been externally set to Aborted before the
	 * queueable runs.
	 */
	@IsTest
	private static void shouldAbortWhenExternallyAborted()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.TrackingStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();

			AsyncChainExecution__c abortRecord = new AsyncChainExecution__c(Id = executionId);
			abortRecord.Status__c = SEL_AsyncChainExecution.STATUS_ABORTED;
			DML_Builder.newTransaction().doUpdate(abortRecord).execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, execution.Status__c, 'Chain should remain aborted');
			Map<String, Object> contextData = parseContextData(execution);
			Assert.isNull(contextData.get('trackingStepExecuted'), 'Step should not have executed after external abort');
		}
	}

	/**
	 * @description Verifies that the asynchronous ChainExecutor detects context overflow after
	 * step execution and marks the chain as Failed with a descriptive error message.
	 */
	@IsTest
	private static void shouldHandleContextOverflowAsynchronously()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withMaxContextSize(1)
					.withInitialContext('key', 'value')
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Should fail on context overflow');
			Assert.isTrue(execution.ErrorMessage__c.contains('overflow'), 'Error should mention overflow');
		}
	}

	/**
	 * @description Verifies that when a step throws an unhandled exception, the asynchronous
	 * ChainExecutor catches it and marks the chain as Failed via the catch block in
	 * the execute(QueueableContext) method.
	 */
	@IsTest
	private static void shouldCatchExceptionAsynchronously()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.ExceptionStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should be Failed after async exception');
			Assert.isTrue(execution.ErrorMessage__c.contains('Deliberate exception'), 'Error message should contain exception details');
		}
	}

	/**
	 * @description Verifies enqueueNext is called for multi-step async chains. Step 2 fails to terminate.
	 */
	@IsTest
	private static void shouldEnqueueNextStepAsynchronously()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.then(new UTIL_AsyncChain_TEST.FailingStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c,
					'Chain should fail on second step after enqueueNext chains to it');
			Assert.areEqual(1, execution.CompletedSteps__c, 'Only the first successful step should be counted');
		}
	}

	/**
	 * @description Verifies that an existing LOG_Builder correlation is inherited by the chain
	 * and that warn-level logs from continueOnError steps share the same correlation ID.
	 */
	@IsTest
	private static void shouldInheritAndPropagateLoggingCorrelation()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String correlationId = LOG_Builder.startCorrelation();

			Test.startTest();
			String executionId = executeContinueOnErrorChain();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(correlationId, execution.CorrelationId__c, 'Chain should inherit the existing correlation ID');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete');

			List<LogEntry__c> allLogs = new SEL_LogEntry().getAll();
			Integer correlatedCount = 0;
			for(LogEntry__c log : allLogs)
			{
				if(log.CorrelationId__c == correlationId)
				{
					correlatedCount++;
				}
			}
			Assert.isTrue(correlatedCount >= 1, 'At least 1 log entry should share the correlation ID (continueOnError warn)');
		}
	}

	/**
	 * @description Verifies that the full LOG_Builder context is serialized into the chain context
	 * and that the chain execution record preserves the log context for hydration.
	 */
	@IsTest
	private static void shouldPersistLoggingContextInChainData()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String correlationId = LOG_Builder.startCorrelation();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(correlationId, execution.CorrelationId__c, 'Correlation should be inherited');

			Map<String, Object> contextData = parseContextData(execution);
			Assert.isNotNull(contextData.get('__logContext'), 'Serialized log context should be persisted in chain context');
		}
	}

	/**
	 * @description Verifies that then(step, true) allows a pure IF_Chain.Step to continue on error.
	 */
	@IsTest
	private static void shouldContinueOnErrorViaThenOverload()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = executeContinueOnErrorChain();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete despite failing step');
			Assert.areEqual(1, execution.CompletedSteps__c, 'Only the successful step should be counted');
			Assert.isTrue(execution.ErrorMessage__c.contains('Non-fatal'), 'Should contain non-fatal failure summary');
		}
	}

	/**
	 * @description Verifies that a warning is logged when context size exceeds 80% of the limit.
	 */
	@IsTest
	private static void shouldWarnWhenContextApproaches80Percent()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withInitialContext('padding', 'x'.repeat(500))
					.withMaxContextSize(800)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete');

			List<LogEntry__c> warnLogs = new SEL_LogEntry().getAll();
			Boolean foundContextWarning = false;
			for(LogEntry__c log : warnLogs)
			{
				if(log.Message__c != null && log.Message__c.contains('context approaching limit'))
				{
					foundContextWarning = true;
				}
			}
			Assert.isTrue(foundContextWarning, 'Should emit 80% context size warning as LogEntry__c');
		}
	}

	/**
	 * @description Verifies that the Finalizer gracefully fails the chain when enqueue throws.
	 */
	@IsTest
	private static void shouldFailChainWhenFinalizerEnqueueFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();

			UTIL_AsyncChain.simulateEnqueueFailure = true;
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should fail when enqueue fails');
			Assert.isTrue(execution.ErrorMessage__c.contains('Finalizer failed to enqueue'), 'Error should mention enqueue failure');
		}
	}

	/**
	 * @description Verifies that the Finalizer fails the chain when handler enqueue throws.
	 */
	@IsTest
	private static void shouldFailChainWhenHandlerEnqueueFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = executeWithCompletionHandler();

			UTIL_AsyncChain.simulateEnqueueFailure = true;
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should fail when handler enqueue fails');
			Assert.isTrue(execution.ErrorMessage__c.contains('enqueue handler'), 'Error should mention handler enqueue failure');
		}
	}

	/**
	 * @description Verifies that the HandlerExecutor Finalizer marks the chain as Failed when the handler crashes.
	 */
	@IsTest
	private static void shouldMarkChainFailedWhenHandlerCrashes()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = executeWithCompletionHandler();

			UTIL_AsyncChain.simulateHandlerCrash = true;
			try
			{
				Test.stopTest();
			}
			catch(Exception ignored)
			{
				Assert.isNotNull(ignored, 'Simulated handler crash should surface an exception');
			}
			UTIL_AsyncChain.simulateHandlerCrash = false;

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Handler crash should mark chain as Failed');
			Assert.isTrue(execution.ErrorMessage__c.contains('Handler crashed'), 'Should mention handler crash');
		}
	}

	/**
	 * @description Verifies that HandlerExecutor.markHandlerFailed handles DML failure gracefully.
	 */
	@IsTest
	private static void shouldHandleDmlFailureInHandlerRecovery()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			Id executionId = execution.Id;
			DML_Builder.newTransaction().doDelete(execution).execute();

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							executionId, new UTIL_AsyncChain.ChainContext('test', 'test'), null, 'Failed', null
					);

			handlerExecutor.markHandlerFailed(executionId, 'Test handler DML failure');
			Test.getEventBus().deliver();

			List<LogEntry__c> errorLogs = new SEL_LogEntry().getAll();
			Boolean foundDmlFailureLog = false;
			for(LogEntry__c log : errorLogs)
			{
				if(log.Message__c != null && log.Message__c.contains('Handler Finalizer DML failed'))
				{
					foundDmlFailureLog = true;
				}
			}
			Assert.isTrue(foundDmlFailureLog, 'Should emit handler DML failure error log');
		}
	}

	/**
	 * @description Verifies that ChainExecutor.markChainFailedFromFinalizer handles DML failure gracefully.
	 */
	@IsTest
	private static void shouldHandleDmlFailureInFinalizerRecovery()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			Id executionId = execution.Id;
			DML_Builder.newTransaction().doDelete(execution).execute();

			AsyncOptions options = createAsyncOptions(2);
			UTIL_AsyncChain.ChainExecutor executor = new UTIL_AsyncChain.ChainExecutor
					(
							executionId, 0, 50, 32768, null, null, options
					);

			executor.markChainFailedFromFinalizer(executionId, 'Test DML failure');
			Test.getEventBus().deliver();

			List<LogEntry__c> errorLogs = new SEL_LogEntry().getAll();
			Boolean foundDmlFailureLog = false;
			for(LogEntry__c log : errorLogs)
			{
				if(log.Message__c != null && log.Message__c.contains('Finalizer DML failed'))
				{
					foundDmlFailureLog = true;
				}
			}
			Assert.isTrue(foundDmlFailureLog, 'Should emit DML failure error log with original error context');
		}
	}

	/**
	 * @description Verifies that multiple continueOnError failures are accumulated in ErrorMessage.
	 */
	@IsTest
	private static void shouldAccumulateMultipleContinuedFailures()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.FailingStep(), true)
					.then(new UTIL_AsyncChain_TEST.FailingStep(), true)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(4))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete');
			Assert.areEqual(1, execution.CompletedSteps__c, 'Only the successful step should be counted');
			Assert.isTrue(execution.ErrorMessage__c.contains('; '), 'Should concatenate multiple failures with semicolon');
		}
	}

	/**
	 * @description Verifies that DurationMs__c is populated when a chain completes.
	 */
	@IsTest
	private static void shouldSetDurationOnCompletion()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.isNotNull(execution.DurationMs__c, 'DurationMs should be set on completion');
			Assert.isTrue(execution.DurationMs__c >= 0, 'DurationMs should be non-negative');
		}
	}

	/**
	 * @description Verifies that a pure IF_Chain.Step implementation (not extending ChainStep)
	 * works with the chain builder, supporting the open-closed principle for subscribers.
	 */
	@IsTest
	private static void shouldExecutePureInterfaceStep()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.PureInterfaceStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Pure interface step should complete');
			Map<String, Object> contextData = parseContextData(execution);
			Assert.isTrue((Boolean)contextData.get('pureInterfaceExecuted'), 'Pure interface step should have executed');
		}
	}

	/**
	 * @description Verifies that the Finalizer marks the chain as Failed when the Queueable crashes
	 * with an unhandled exception. Simulates a governor limit crash using the simulateCrash flag.
	 */
	@IsTest
	private static void shouldMarkChainFailedOnUnhandledException()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			UTIL_AsyncChain.simulateCrash = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.execute();
			try
			{
				Test.stopTest();
				Assert.fail('Simulated crash should have thrown');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class, 'Should be the simulated crash exception');
			}
			UTIL_AsyncChain.simulateCrash = false;

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Finalizer should mark chain as Failed');
			Assert.isTrue(execution.ErrorMessage__c.contains('Queueable crashed'), 'Error should indicate crash origin');
			Assert.isTrue(execution.ErrorMessage__c.contains('Simulated'), 'Error should contain exception message');
			Assert.isNotNull(execution.CompletedAt__c, 'CompletedAt should be set by Finalizer');
		}
	}

	/**
	 * @description Verifies that a chain executes with default AsyncOptions when none are provided.
	 */
	@IsTest
	private static void shouldUseDefaultAsyncOptionsWhenNotProvided()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete with default options');
		}
	}

	/**
	 * @description Verifies that the chain fails with an error when the step class cannot be found.
	 */
	@IsTest
	private static void shouldFailWhenStepClassNotFound()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			execution.StepLog__c = JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition>
			{
					buildDtoStepDefinition('NonExistentClass', 'MissingStep')
			});
			DML_Builder.newTransaction().doUpdate(execution).execute();

			AsyncOptions options = createAsyncOptions(2);

			Test.startTest();
			System.enqueueJob(new UTIL_AsyncChain.ChainExecutor(execution.Id, 0, 50, 32768, null, null, options), options);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'Chain should fail for missing class');
			Assert.isTrue(result.ErrorMessage__c.contains('Class Not Found'), 'Error should mention class not found');
		}
	}

	/**
	 * @description Verifies that the executor exits gracefully when the execution record is deleted externally.
	 */
	@IsTest
	private static void shouldHandleDeletedExecutionRecord()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			execution.StepLog__c = JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition>
			{
					buildDtoStepDefinition('UTIL_AsyncChain_TEST.SuccessStep', 'SuccessStep')
			});
			DML_Builder.newTransaction().doUpdate(execution).execute();
			Id executionId = execution.Id;
			DML_Builder.newTransaction().doDelete(execution).execute();

			AsyncOptions options = createAsyncOptions(2);

			Test.startTest();
			System.enqueueJob(new UTIL_AsyncChain.ChainExecutor(executionId, 0, 50, 32768, null, null, options), options);
			Test.stopTest();

			Boolean existsAfter = QRY_Builder.selectFrom(AsyncChainExecution__c.SObjectType)
					.condition(AsyncChainExecution__c.Id).equals(executionId)
					.exists();
			Assert.isFalse(existsAfter, 'Executor should exit without recreating the deleted execution record');
		}
	}

	/**
	 * @description Verifies that an ApiStep wrapping API_PostExample completes successfully
	 * within a single-step chain, producing a succeeded StepResult.
	 */
	@IsTest
	private static void shouldCompleteApiStepSuccessfully()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
							.triggeringRecord(record.Id)
							.withParameter(API_PostExample.PARAMETER_NAME, 'testValue'))
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete');
			Assert.areEqual(1, execution.CompletedSteps__c, 'One step should have completed');
		}
	}

	/**
	 * @description Verifies that static parameters set via withParameter() reach the handler.
	 */
	@IsTest
	private static void shouldPassStaticParametersToApiStepHandler()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
							.triggeringRecord(record.Id)
							.withParameter(API_PostExample.PARAMETER_NAME, 'staticValue'))
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete with static params');
			SEL_ApiCall.assertServiceCompleted(API_STEP_SERVICE_NAME);
		}
	}

	/**
	 * @description Verifies that withParameterFrom() resolves parameter values from prior step output.
	 */
	@IsTest
	private static void shouldResolveApiStepParametersFromContext()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withInitialContext('recordId', String.valueOf(record.Id))
					.withInitialContext('dynamicParam', 'contextValue')
					.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
							.triggeringRecordFrom('recordId')
							.withParameterFrom(API_PostExample.PARAMETER_NAME, 'dynamicParam'))
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete with context params');
		}
	}

	/**
	 * @description Verifies that triggeringRecordFrom() reads the record ID from ChainContext.
	 */
	@IsTest
	private static void shouldResolveApiStepTriggeringRecordFromContext()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withInitialContext('recordId', String.valueOf(record.Id))
					.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
							.triggeringRecordFrom('recordId')
							.withParameter(API_PostExample.PARAMETER_NAME, 'test'))
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete with context record ID');
		}
	}

	/**
	 * @description Verifies that triggeringRecord() passes a literal record ID to the handler.
	 */
	@IsTest
	private static void shouldPassStaticTriggeringRecordToApiStep()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();
			String executionId = executeSingleApiStepChain(record);
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete with static record ID');
		}
	}

	/**
	 * @description Verifies that credential() overrides the Named Credential for the handler.
	 */
	@IsTest
	private static void shouldApplyApiStepCredentialOverride()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
							.credential('AlternateCredential')
							.triggeringRecord(record.Id)
							.withParameter(API_PostExample.PARAMETER_NAME, 'test'))
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete with credential override');
		}
	}

	/**
	 * @description Verifies that API call results are stored in ChainContext under __apiResult_{index}.
	 */
	@IsTest
	private static void shouldWriteApiStepResultsToContext()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();
			String executionId = executeSingleApiStepChain(record);
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Map<String, Object> contextData = parseContextData(execution);
			Map<String, Object> apiResult = (Map<String, Object>)contextData.get(UTIL_AsyncChain.API_STEP_RESULT_KEY_PREFIX + '0');
			Assert.isNotNull(apiResult, 'API result should be stored in context');
			Assert.areEqual(true, apiResult.get('success'), 'Success should be true');
			Assert.isNotNull(apiResult.get('statusCode'), 'Status code should be stored');
			Assert.isNotNull(apiResult.get('apiCallId'), 'ApiCall ID should be stored');
		}
	}

	/**
	 * @description Verifies that API errors are persisted in the context result for downstream inspection.
	 */
	@IsTest
	private static void shouldPersistApiStepErrorsInContext()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			API_PostExample.simulatedValidationError = 'Simulated validation error for chain testing';
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
							.triggeringRecord(record.Id)
							.withParameter(API_PostExample.PARAMETER_NAME, 'test'), true)
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Map<String, Object> contextData = parseContextData(execution);
			Map<String, Object> apiResult = (Map<String, Object>)contextData.get(UTIL_AsyncChain.API_STEP_RESULT_KEY_PREFIX + '0');
			Assert.isNotNull(apiResult, 'API result should be stored in context');
			Assert.areEqual(false, apiResult.get('success'), 'Success should be false');
			Assert.isNotNull(apiResult.get('apiCallId'), 'ApiCall ID should be stored even on failure');
			Assert.isNotNull(apiResult.get('errors'), 'Validation errors should be stored in context');
		}
	}

	/**
	 * @description Verifies that a failed web service call produces a failed StepResult with error details.
	 */
	@IsTest
	private static void shouldFailApiStepOnHandlerFailure()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			API_MockFactory.registerErrorMock(API_STEP_SERVICE_NAME);

			Test.startTest();
			String executionId = executeSingleApiStepChain(record);
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should fail when API call fails');
			Assert.isTrue(execution.ErrorMessage__c.contains(API_STEP_SERVICE_NAME), 'Error should reference the handler class');
		}
	}

	/**
	 * @description Verifies that a validation abort (e.g., missing triggering record) produces a failed StepResult.
	 */
	@IsTest
	private static void shouldFailApiStepOnHandlerAbort()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
							.withParameter(API_PostExample.PARAMETER_NAME, 'test'))
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should fail when API call is aborted');
		}
	}

	/**
	 * @description Verifies that the chain's correlation ID flows through to the ApiCall__c.
	 */
	@IsTest
	private static void shouldPropagateApiStepCorrelationId()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			String correlationId = 'test-correlation-id';

			Test.startTest();
			String executionId = executeSingleApiStepChain(record, correlationId);
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(correlationId, execution.CorrelationId__c, 'Chain correlation ID should be set');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete');
		}
	}

	/**
	 * @description Verifies that an ApiCall__c record is persisted during ApiStep execution.
	 */
	@IsTest
	private static void shouldPersistApiStepApiCallRecord()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();
			executeSingleApiStepChain(record);
			Test.stopTest();

			SEL_ApiCall.assertServiceCompleted(API_STEP_SERVICE_NAME);
		}
	}

	/**
	 * @description Verifies that a regular step followed by an ApiStep followed by a regular step
	 * that reads the API result works correctly in a multi-step chain.
	 */
	@IsTest
	private static void shouldWorkInMultiStepApiStepChain()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withInitialContext('recordId', String.valueOf(record.Id))
					.then(new ApiStepContextWriterStep())
					.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
							.triggeringRecordFrom('recordId')
							.withParameterFrom(API_PostExample.PARAMETER_NAME, 'testParam'))
					.then(new ApiStepResultReaderStep())
					.withAsyncOptions(createAsyncOptions(4))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Multi-step chain should complete');
			Assert.areEqual(3, execution.CompletedSteps__c, 'All three steps should complete');

			Map<String, Object> contextData = parseContextData(execution);
			Assert.areEqual(true, contextData.get('apiResultRead'), 'Downstream step should read API result');
		}
	}

	/**
	 * @description Verifies that two ApiStep instances at different indices don't collide.
	 */
	@IsTest
	private static void shouldSupportMultipleApiStepsInChain()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
							.triggeringRecord(record.Id)
							.withParameter(API_PostExample.PARAMETER_NAME, 'first'))
					.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
							.triggeringRecord(record.Id)
							.withParameter(API_PostExample.PARAMETER_NAME, 'second'))
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain with multiple ApiSteps should complete');
			Assert.areEqual(2, execution.CompletedSteps__c, 'Both ApiSteps should complete');

			Map<String, Object> contextData = parseContextData(execution);
			Assert.isNotNull(contextData.get(UTIL_AsyncChain.API_STEP_RESULT_KEY_PREFIX + '0'), 'First ApiStep result should be stored');
			Assert.isNotNull(contextData.get(UTIL_AsyncChain.API_STEP_RESULT_KEY_PREFIX + '1'), 'Second ApiStep result should be stored');
		}
	}

	/**
	 * @description Verifies that a failed API call triggers the chain's onError handler.
	 */
	@IsTest
	private static void shouldInvokeErrorHandlerOnApiStepFailure()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			API_MockFactory.registerErrorMock(API_STEP_SERVICE_NAME);

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
							.triggeringRecord(record.Id)
							.withParameter(API_PostExample.PARAMETER_NAME, 'test'))
					.onError(new ApiStepErrorMarkerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should fail');
			Map<String, Object> contextData = parseContextData(execution);
			Assert.areEqual(true, contextData.get('errorHandlerRan'), 'Error handler should have executed');
		}
	}

	/**
	 * @description Verifies that work() returns a clear error when configuration is missing from context.
	 */
	@IsTest
	private static void shouldFailApiStepWhenConfigMissing()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ApiStep step = new UTIL_AsyncChain.ApiStep(API_PostExample.class);
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('testExecId', 'testCorrelation');
			context.currentStepIndex = 0;

			UTIL_AsyncChain.StepResult result = step.work(context);

			Assert.isFalse(result.success, 'Should fail when config is missing');
			Assert.isTrue(result.message.contains('configuration not found'), 'Error should mention missing config');
		}
	}

	/**
	 * @description Verifies that work() returns a clear error when the handler class name in config
	 * cannot be resolved by Type.forName() (e.g., subscriber uninstalled or class renamed).
	 */
	@IsTest
	private static void shouldFailApiStepWhenHandlerClassNotFound()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('testExecId', 'testCorrelation');
			context.currentStepIndex = 0;

			Map<String, Object> config = new Map<String, Object>
			{
					'handlerClassName' => 'NonExistentApiHandler'
			};
			context.put(UTIL_AsyncChain.API_STEP_CONFIG_KEY_PREFIX + '0', config);

			UTIL_AsyncChain.ApiStep step = new UTIL_AsyncChain.ApiStep();
			UTIL_AsyncChain.StepResult result = step.work(context);

			Assert.isFalse(result.success, 'Should fail when handler class not found');
			Assert.isTrue(result.message.contains('Handler class not found'), 'Error should mention handler class not found');
			Assert.isTrue(result.message.contains('NonExistentApiHandler'), 'Error should include the class name');
		}
	}

	/**
	 * @description Verifies that the no-arg constructor exists and produces a valid instance for reflection.
	 */
	@IsTest
	private static void shouldInstantiateApiStepViaReflection()
	{
		System.runAs(getTestAdmin())
		{
			Type apiStepType = Type.forName('UTIL_AsyncChain.ApiStep');
			Assert.isNotNull(apiStepType, 'ApiStep type should be resolvable');

			Object instance = apiStepType.newInstance();
			Assert.isNotNull(instance, 'No-arg constructor should produce a valid instance');
			Assert.isInstanceOfType(instance, IF_Chain.Step.class, 'Instance should implement IF_Chain.Step');
		}
	}

	/**
	 * @description Verifies that the ApiStep constructor rejects non-API_Outbound types.
	 */
	@IsTest
	private static void shouldThrowWhenApiStepReceivesInvalidType()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				new UTIL_AsyncChain.ApiStep(Account.class);
				Assert.fail('Should throw TypeException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, TypeException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Verifies that writeConfig() persists all configuration fields to the initial context map.
	 */
	@IsTest
	private static void shouldWriteAllApiStepConfigFieldsToContext()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			UTIL_AsyncChain.ApiStep step = new UTIL_AsyncChain.ApiStep(API_PostExample.class)
					.credential('TestCredential')
					.withParameter('param1', 'value1')
					.withParameterFrom('param2', 'contextKey')
					.triggeringRecord(record.Id);

			Map<String, Object> initialContext = new Map<String, Object>();
			step.writeConfig(initialContext, 3);

			Map<String, Object> config = (Map<String, Object>)initialContext.get(UTIL_AsyncChain.API_STEP_CONFIG_KEY_PREFIX + '3');
			Assert.isNotNull(config, 'Config should be written to context');
			Assert.areEqual(API_STEP_SERVICE_NAME, config.get('handlerClassName'), 'Handler class name should match');
			Assert.areEqual('TestCredential', config.get('credential'), 'Credential should be stored');
			Assert.isNotNull(config.get('staticParams'), 'Static params should be stored');
			Assert.isNotNull(config.get('contextMappings'), 'Context mappings should be stored');
			Assert.areEqual(String.valueOf(record.Id), config.get('triggeringRecordId'), 'Triggering record ID should be stored');
		}
	}

	/**
	 * @description Verifies that the ApiStep uses continueOnError when configured via builder overload.
	 */
	@IsTest
	private static void shouldContinueOnApiStepErrorWhenConfigured()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			API_MockFactory.registerErrorMock(API_STEP_SERVICE_NAME);

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
							.withParameter(API_PostExample.PARAMETER_NAME, 'test'), true)
					.then(new ApiStepSuccessMarkerStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete despite API failure');
			Map<String, Object> contextData = parseContextData(execution);
			Assert.areEqual(true, contextData.get('successMarkerRan'), 'Second step should execute after non-fatal API failure');
		}
	}

	/**
	 * @description Verifies that a chain of two different API_Outbound handlers (POST + GET) executes
	 * end-to-end, producing independent results at separate context keys. Validates the "entire chain
	 * is web services" scenario where each step is a callout in its own Queueable transaction.
	 */
	@IsTest
	private static void shouldChainMultipleDifferentApiHandlers()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
							.triggeringRecord(record.Id)
							.withParameter(API_PostExample.PARAMETER_NAME, 'chainFirst'))
					.then(new UTIL_AsyncChain.ApiStep(API_GetPwndPasswords.class)
							.withParameter(API_GetPwndPasswords.PARAMETER_PASSWORD, 'testpassword'))
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'All-API chain should complete');
			Assert.areEqual(2, execution.CompletedSteps__c, 'Both API steps should complete');

			Map<String, Object> contextData = parseContextData(execution);
			Map<String, Object> postResult = (Map<String, Object>)contextData.get(UTIL_AsyncChain.API_STEP_RESULT_KEY_PREFIX + '0');
			Map<String, Object> getResult = (Map<String, Object>)contextData.get(UTIL_AsyncChain.API_STEP_RESULT_KEY_PREFIX + '1');

			Assert.isNotNull(postResult, 'POST step result should be stored');
			Assert.areEqual(true, postResult.get('success'), 'POST step should succeed');
			Assert.isNotNull(postResult.get('apiCallId'), 'POST ApiCall ID should be stored');

			Assert.isNotNull(getResult, 'GET step result should be stored');
			Assert.areEqual(true, getResult.get('success'), 'GET step should succeed');
			Assert.isNotNull(getResult.get('apiCallId'), 'GET ApiCall ID should be stored');

			Assert.areNotEqual(postResult.get('apiCallId'), getResult.get('apiCallId'), 'Each step should produce a distinct ApiCall record');
		}
	}

	/**
	 * @description Queries an AsyncChainExecution__c record by ID.
	 *
	 * @param executionId The execution record ID.
	 *
	 * @return The queried execution record.
	 */
	private static AsyncChainExecution__c queryExecution(String executionId)
	{
		return (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(executionId);
	}

	/**
	 * @description Inserts a pre-populated AsyncChainExecution__c row (owned by the running user) so
	 * the typed getChainStatus tests can assert deterministic field mappings without running a chain.
	 *
	 * @param record The execution record to persist.
	 *
	 * @return The same record with its Id populated.
	 */
	private static AsyncChainExecution__c persistExecution(AsyncChainExecution__c record)
	{
		DML_Builder.newTransaction().doInsert(record).execute();
		return record;
	}

	/**
	 * @description Executes a chain with a FailingStep (continueOnError) then SuccessStep.
	 *
	 * @return The execution record ID.
	 */
	private static String executeContinueOnErrorChain()
	{
		return UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
				.then(new UTIL_AsyncChain_TEST.FailingStep(), true)
				.then(new UTIL_AsyncChain_TEST.SuccessStep())
				.withAsyncOptions(createAsyncOptions(3))
				.execute();
	}

	/**
	 * @description Executes a single-step chain with a CompletionHandler.
	 *
	 * @return The execution record ID.
	 */
	private static String executeWithCompletionHandler()
	{
		return UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
				.then(new UTIL_AsyncChain_TEST.SuccessStep())
				.onComplete(new UTIL_AsyncChain_TEST.CompletionHandlerStep())
				.withAsyncOptions(createAsyncOptions(2))
				.execute();
	}

	/**
	 * @description Builds and executes a three-step success chain for reuse across tests.
	 *
	 * @return The execution record ID.
	 */
	private static String executeThreeStepSuccessChain()
	{
		return UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
				.then(new UTIL_AsyncChain_TEST.SuccessStep())
				.then(new UTIL_AsyncChain_TEST.SuccessStep())
				.then(new UTIL_AsyncChain_TEST.SuccessStep())
				.withAsyncOptions(createAsyncOptions(4))
				.execute();
	}

	/**
	 * @description Executes a single ApiStep chain wrapping API_PostExample with the given Foobar record.
	 *
	 * @param record The Foobar__c record to use as the triggering record.
	 *
	 * @return The execution record ID.
	 */
	private static String executeSingleApiStepChain(Foobar__c record)
	{
		return executeSingleApiStepChain(record, null);
	}

	/**
	 * @description Executes a single ApiStep chain wrapping API_PostExample with an optional correlation ID.
	 *
	 * @param record The Foobar__c record to use as the triggering record.
	 * @param correlationId The correlation ID for log tracing, or null for auto-generated.
	 *
	 * @return The execution record ID.
	 */
	private static String executeSingleApiStepChain(Foobar__c record, String correlationId)
	{
		UTIL_AsyncChain.ChainBuilder builder = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
				.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
						.triggeringRecord(record.Id)
						.withParameter(API_PostExample.PARAMETER_NAME, 'test'))
				.withAsyncOptions(createAsyncOptions(2));
		return String.isNotBlank(correlationId) ? builder.execute(correlationId) : builder.execute();
	}

	/**
	 * @description Parses context data JSON from an execution record into a map, returning an empty map if blank.
	 *
	 * @param execution The execution record containing ContextData__c.
	 *
	 * @return Deserialized context data map.
	 */
	private static Map<String, Object> parseContextData(AsyncChainExecution__c execution)
	{
		return String.isNotBlank(execution.ContextData__c) ? (Map<String, Object>)JSON.deserializeUntyped(execution.ContextData__c) : new Map<String, Object>();
	}

	/**
	 * @description Creates an AsyncOptions instance with the specified queueable stack depth.
	 *
	 * @param stackDepth The maximum queueable stack depth.
	 *
	 * @return The configured AsyncOptions.
	 */
	private static AsyncOptions createAsyncOptions(Integer stackDepth)
	{
		AsyncOptions options = new AsyncOptions();
		options.maximumQueueableStackDepth = stackDepth;
		return options;
	}

	/**
	 * @description Sets up the feature flag cache to indicate the AsyncChain feature is enabled.
	 */
	private static void setupEnabledFeatureFlag()
	{
		FeatureFlag__mdt flag = (FeatureFlag__mdt)TST_Builder.of(FeatureFlag__mdt.SObjectType)
				.withOverride(FeatureFlag__mdt.DeveloperName, UTIL_AsyncChain.FEATURE_FLAG_NAME)
				.withOverride(FeatureFlag__mdt.IsActive__c, true)
				.withOverride(FeatureFlag__mdt.IsEnabledByDefault__c, true)
				.withOverride(FeatureFlag__mdt.ResultOnNoMatch__c, true)
				.withoutInsertion()
				.build();

		SEL_FeatureFlag.allDeveloperNames = new Set<String> {UTIL_AsyncChain.FEATURE_FLAG_NAME};
		SEL_FeatureFlag.activeFlags = new Map<String, FeatureFlag__mdt>
		{
				UTIL_AsyncChain.FEATURE_FLAG_NAME => flag
		};
	}

	/**
	 * @description Sets up the feature flag cache to indicate the AsyncChain feature is disabled.
	 */
	private static void setupDisabledFeatureFlag()
	{
		SEL_FeatureFlag.allDeveloperNames = new Set<String> {UTIL_AsyncChain.FEATURE_FLAG_NAME};
		SEL_FeatureFlag.activeFlags = new Map<String, FeatureFlag__mdt>();
	}

	/**
	 * @description Builds a DTO_StepDefinition with the given class name and step name.
	 *
	 * @param className The fully-qualified step class name.
	 * @param stepName The display name for the step.
	 *
	 * @return The configured DTO_StepDefinition.
	 */
	private static UTIL_AsyncChain.DTO_StepDefinition buildDtoStepDefinition(String className, String stepName)
	{
		UTIL_AsyncChain.DTO_StepDefinition definition = new UTIL_AsyncChain.DTO_StepDefinition();
		definition.className = className;
		definition.stepName = stepName;
		return definition;
	}

	/**
	 * @description Step that succeeds and increments a stepCount in context.
	 */
	public class SuccessStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			Integer count = context.has('stepCount') ? (Integer)context.get('stepCount') : 0;
			context.put('stepCount', count + 1);
			return UTIL_AsyncChain.succeeded('Step completed');
		}
	}

	/**
	 * @description Step that succeeds with data payload.
	 */
	public class DataStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.succeeded('Data step', 42);
		}
	}

	/**
	 * @description Step that reads a testKey from context and stores it as readValue.
	 */
	public class ContextReaderStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			Object value = context.get('testKey');
			context.put('readValue', value);
			return UTIL_AsyncChain.succeeded('Read: ' + String.valueOf(value));
		}
	}

	/**
	 * @description Step that always returns a failed result.
	 */
	public class FailingStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed('Deliberate failure');
		}
	}

	/**
	 * @description Step that throws an exception.
	 */
	public class ExceptionStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			throw new UTIL_Exceptions.IllegalStateException('Deliberate exception');
		}
	}

	/**
	 * @description Step that sets a tracking flag in context.
	 */
	public class TrackingStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put('trackingStepExecuted', true);
			return UTIL_AsyncChain.succeeded('Tracked');
		}
	}

	/**
	 * @description Error handler step that sets a tracking flag in context.
	 */
	public class ErrorHandlerStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put('errorHandlerExecuted', true);
			return UTIL_AsyncChain.succeeded('Error handled');
		}
	}

	/**
	 * @description Completion handler step that sets a tracking flag in context.
	 */
	public class CompletionHandlerStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put('completionHandlerExecuted', true);
			return UTIL_AsyncChain.succeeded('Completion handled');
		}
	}

	/**
	 * @description Error handler that itself throws.
	 */
	public class FailingErrorHandlerStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			throw new UTIL_Exceptions.IllegalStateException('Error handler failed');
		}
	}

	/**
	 * @description Completion handler that itself throws.
	 */
	public class FailingCompletionHandlerStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			throw new UTIL_Exceptions.IllegalStateException('Completion handler failed');
		}
	}

	/**
	 * @description Step with continueOnError that always fails.
	 */
	public class ContinueOnErrorStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Constructs a ContinueOnErrorStep with continueOnError enabled.
		 */
		public ContinueOnErrorStep()
		{
			this.continueOnError = true;
			this.stepName = 'ContinueOnErrorStep';
		}

		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed('Expected failure, continuing');
		}
	}

	/**
	 * @description Step with a custom name.
	 */
	public class NamedStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Constructs a NamedStep with a custom step name.
		 */
		public NamedStep()
		{
			this.stepName = 'CustomNamedStep';
		}

		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.succeeded('Named step completed');
		}
	}

	/**
	 * @description Step that reads the previous step result from context.
	 */
	public class PreviousResultReaderStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			UTIL_AsyncChain.StepResult previous = context.getPreviousStepResult();
			if(previous != null)
			{
				context.put('previousData', previous.data);
			}
			return UTIL_AsyncChain.succeeded('Read previous result');
		}
	}

	/**
	 * @description Step that verifies initial context was seeded from the builder.
	 */
	public class ContextSeedVerifierStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put('foundKey1', context.get('key1'));
			context.put('foundKey2', context.get('key2'));
			return UTIL_AsyncChain.succeeded('Context verified');
		}
	}

	/**
	 * @description Error handler that verifies context is passed to the handler.
	 */
	public class ContextCheckingErrorHandlerStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put('errorHandlerHadContext', context.has('testKey'));
			return UTIL_AsyncChain.succeeded('Error handled with context');
		}
	}

	/**
	 * @description Pure IF_Chain.Step implementation without extending ChainStep.
	 * Verifies the interface-based open-closed principle works for subscribers
	 * who can't extend ChainStep due to single inheritance constraints.
	 */
	public class PureInterfaceStep implements IF_Chain.Step
	{
		public UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put('pureInterfaceExecuted', true);
			return UTIL_AsyncChain.succeeded('Pure interface step completed');
		}
	}

	/**
	 * @description Step that writes a test parameter into the chain context for use by downstream ApiSteps.
	 */
	public class ApiStepContextWriterStep implements IF_Chain.Step
	{
		/**
		 * @description Writes a test parameter to context.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A successful StepResult.
		 */
		public UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put('testParam', 'fromPriorStep');
			return UTIL_AsyncChain.succeeded('Context written');
		}
	}

	/**
	 * @description Step that reads the API result from context to verify downstream access.
	 */
	public class ApiStepResultReaderStep implements IF_Chain.Step
	{
		/**
		 * @description Reads API result from context and marks that it was accessible.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A successful StepResult.
		 */
		public UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			Map<String, Object> apiResult = (Map<String, Object>)context.get(UTIL_AsyncChain.API_STEP_RESULT_KEY_PREFIX + '1');
			if(apiResult != null && (Boolean)apiResult.get('success') == true && apiResult.get('apiCallId') != null)
			{
				context.put('apiResultRead', true);
			}
			return UTIL_AsyncChain.succeeded('Result read');
		}
	}

	/**
	 * @description Error handler step that marks its execution in context for ApiStep tests.
	 */
	public class ApiStepErrorMarkerStep implements IF_Chain.Step
	{
		/**
		 * @description Marks that the error handler ran.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A successful StepResult.
		 */
		public UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put('errorHandlerRan', true);
			return UTIL_AsyncChain.succeeded('Error handled');
		}
	}

	/**
	 * @description Simple success step that marks its execution in context for ApiStep tests.
	 */
	public class ApiStepSuccessMarkerStep implements IF_Chain.Step
	{
		/**
		 * @description Marks that this step ran.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A successful StepResult.
		 */
		public UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put('successMarkerRan', true);
			return UTIL_AsyncChain.succeeded('Marker set');
		}
	}

	/**
	 * @description Tier-A — proves UTIL_AsyncChain.newChain(...).then(step).execute()
	 * reaches framework-owned AsyncChainExecution__c persistence from a subscriber user on the
	 * Minimum Access - Salesforce profile who has no FLS on kern__AsyncChainExecution__c. The chain
	 * must create its execution record, complete the single success step, and transition the record
	 * to COMPLETED regardless of the running user's FLS. Framework-internal DML on the execution
	 * record must elevate to SYSTEM_MODE.
	 *
	 * Catches: a future refactor that demotes UTIL_AsyncChain's insert of AsyncChainExecution__c
	 * to USER_MODE, or drops the `.withSystemMode()` on the Queueable's status update, fails this
	 * test at 2GP validated-build time rather than at subscriber scratch-org time.
	 *
	 * @see UTIL_AsyncChain
	 * @see UTIL_AsyncChain.ChainBuilder.execute
	 */
	@IsTest
	private static void shouldCompleteChainForLowPrivilegeUser()
	{
		String executionId;

		System.runAs(getLowPrivilegeUser())
		{
			setupEnabledFeatureFlag();

			Test.startTest();

			executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();

			Test.stopTest();
		}

		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c execution = queryExecution(executionId);

			Assert.isNotNull(execution, 'AsyncChainExecution__c should be persisted for low-privilege caller');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should transition to COMPLETED for low-privilege caller');
			Assert.areEqual(1, execution.TotalSteps__c, 'Total steps should be 1');
			Assert.areEqual(1, execution.CompletedSteps__c, 'Completed steps should be 1');
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup for use with
	 * System.runAs, so each test body runs with a fresh permission-evaluation context.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the tier-A test to exercise UTIL_AsyncChain and prove the
	 * subscribers-without-internal-FLS contract holds for the chain orchestration primitive.
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}
}