// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Recovery-path tests for UTIL_AsyncChain — run-key fencing, stall handling, the
 * watchdog sweep, re-drive, executor liveness, and resume markers. Separated from
 * UTIL_AsyncChain_TEST because the combined class sat at the cognitive-complexity ceiling and the
 * recovery machinery is an independently reviewable facet.
 *
 * @see UTIL_AsyncChain
 * @see UTIL_AsyncChain_TEST
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date July 2026
 */
@IsTest(SeeAllData=false IsParallel=false)
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.NcssTypeCount')
private class UTIL_AsyncChainRecovery_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'UTIL_AsyncChainRecovery_TEST-admin';
	private static final String LOW_PRIVILEGE_COMPANY = 'UTIL_AsyncChainRecovery_TEST-low-privilege';

	/**
	 * @description Name used for test chains.
	 */
	private static final String TEST_CHAIN_NAME = 'TestChain';

	/**
	 * @description Marker a HandlerSideEffectStep stamps onto its execution record through its own
	 * DML. The handler entry-fence test asserts on this marker because it commits with the
	 * handler's work, outside the framework status persist: its absence proves the work never ran,
	 * not merely that a later persist was fenced.
	 */
	private static final String HANDLER_SIDE_EFFECT_MARKER = 'HandlerSideEffectCommitted';

	/**
	 * @description Number of times a CountingErrorHandlerStep has run in this test transaction.
	 * The stall-notification tests assert on it to prove the onError handler fires exactly once
	 * per transition into Stalled (same static-seam pattern as the production simulateCrash flag).
	 */
	private static Integer errorHandlerRunCount = 0;

	/**
	 * @description Number of times a CountingFailingStep has run in this test transaction. The
	 * upgrade-straddle test asserts on it to prove a pre-upgrade step log yields exactly one
	 * attempt, with no retry consulted.
	 */
	private static Integer failingStepRunCount = 0;

	/**
	 * @description Number of times RotateAndFailWithRetryStep's retry strategy has been consulted
	 * in this test transaction. The fenced-retry test asserts on it to prove the failure dispatch
	 * entered the retry branch — the untouched record then proves scheduleRetry's fence fired,
	 * not the terminal write's (both fenced writes leave an identical record).
	 */
	private static Integer retryStrategyConsultCount = 0;

	/**
	 * @description Stale threshold that treats a just-created chain as fresh, for the watchdog
	 * sweep's leave-untouched polarity. Paired with SWEEP_EVERYTHING_THRESHOLD_MINUTES this forms
	 * the threshold-window technique: both polarities are exercised against live rows without
	 * back-dating any audit field.
	 */
	private static final Integer FRESH_THRESHOLD_MINUTES = 30;

	/**
	 * @description Negative stale threshold that places the cutoff in the future, so every seeded
	 * chain counts as stale (the other half of the threshold-window technique).
	 */
	private static final Integer SWEEP_EVERYTHING_THRESHOLD_MINUTES = -1;

	/**
	 * @description Batch size used by the watchdog sweep tests. Equals the sweep's batch ceiling, so
	 * the clamp test can assert the marked count against it directly.
	 */
	private static final Integer WATCHDOG_BATCH_SIZE = 50;

	/**
	 * @description Seed count deliberately above the sweep's 50-chain batch ceiling, proving the
	 * clamp: a sweep asked for this many chains must still mark only WATCHDOG_BATCH_SIZE of them.
	 */
	private static final Integer OVERSIZED_SWEEP_SEED_COUNT = 60;

	/**
	 * @description Independent oracle for the reason the sweep's budget gate records when it parks a
	 * candidate instead of processing it, because the transaction has no queueable budget left.
	 */
	private static final String PARKED_NO_BUDGET_REASON = 'Parked: no async budget';

	/**
	 * @description Independent oracle for the reason the sweep's query-budget gate records when it
	 * parks the remaining tail because the transaction is nearly out of database queries.
	 */
	private static final String PARKED_NO_QUERY_BUDGET_REASON = 'Parked: no query budget';

	/**
	 * @description Query budget the sweep is left to start with so exactly one candidate can be
	 * processed: the selector's own read spends one (leaving the per-candidate reserve of three, so
	 * the first candidate's decision legs run and its mark re-read spends another), the gate then
	 * refuses the second candidate at two remaining, and the tail parks one candidate per remaining
	 * query until the budget reaches zero.
	 */
	private static final Integer QUERY_BUDGET_FOR_ONE_SWEPT_CANDIDATE = 4;

	/**
	 * @description Seed count for the query-budget parking test: one candidate processed normally,
	 * two parked (one per remaining query), and one left untouched when the budget reaches zero
	 * mid-park.
	 */
	private static final Integer QUERY_PARK_SEED_COUNT = 4;

	/**
	 * @description Minutes the newer-activity test back-dates its hand-built sweep view by, so the
	 * real row's LastModifiedDate is provably newer than the view the re-drive receives.
	 */
	private static final Integer BACKDATED_SWEEP_VIEW_AGE_MINUTES = 5;

	/**
	 * @description Independent oracle fragment of the actionable reason the re-drive degrade path
	 * records when a candidate's persisted step log cannot be rehydrated into a runnable chain.
	 */
	private static final String REDRIVE_UNRECOVERABLE_FRAGMENT = 'step log is missing, unreadable, or inconsistent';

	/**
	 * @description The attempt number a retry-pending step-log entry carries after its first failed
	 * attempt scheduled a retry: scheduleRetry bumps the 1-based attempt to 2 and clears the
	 * entry's success marker.
	 */
	private static final Integer RETRY_PENDING_ATTEMPT = 2;

	/**
	 * @description Percentage of a valid pre-upgrade step-log document the truncation fixture
	 * keeps: cutting at this fraction lands mid-array, inside the second entry, so the document
	 * reads as JSON that started well and stopped abruptly — the shape a partially-written row
	 * leaves behind.
	 */
	private static final Integer TRUNCATED_STEP_LOG_PERCENT = 60;

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
	 * @description Verifies the Finalizer routes a transient next-step enqueue failure to Stalled:
	 * the chain awaits recovery instead of terminally failing, so CompletedAt stays unset.
	 */
	@IsTest
	private static void shouldRouteFinalizerEnqueueFailureToStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();

			UTIL_AsyncChain.simulateEnqueueFailure = true;
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, execution.Status__c, 'A transient enqueue failure must route the chain to Stalled, not Failed');
			Assert.isTrue(execution.ErrorMessage__c.contains('Finalizer failed to enqueue next step'), 'The stall reason must name the failed enqueue');
			Assert.isNull(execution.CompletedAt__c, 'Stalled is non-terminal: CompletedAt must stay unset');
		}
	}

	/**
	 * @description Verifies the Finalizer routes a transient handler enqueue failure to Stalled:
	 * the handler enqueue site is classified transient by call site, exactly like the next-step
	 * site. The chain's own work had already completed, so the completion stamp survives the
	 * sparse stall write untouched.
	 */
	@IsTest
	private static void shouldRouteHandlerEnqueueFailureToStalled()
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
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, execution.Status__c, 'A transient handler enqueue failure must route the chain to Stalled, not Failed');
			Assert.isTrue(execution.ErrorMessage__c.contains('Finalizer failed to enqueue handler'), 'The stall reason must name the failed handler enqueue');
			Assert.isNotNull(execution.CompletedAt__c, 'The stall write touches only Status and ErrorMessage: the earlier completion stamp must survive');
		}
	}

	/**
	 * @description Verifies that a transition into Stalled fires the chain's onError handler exactly
	 * once through the real Finalizer path: the notification rides the same HandlerExecutor as
	 * terminal failures and carries the stall reason through to the record.
	 */
	@IsTest
	private static void shouldFireOnErrorOnceWhenChainStalls()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.onError(new UTIL_AsyncChainRecovery_TEST.CountingErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();

			UTIL_AsyncChain.simulateEnqueueFailure = true;
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;

			Assert.areEqual(1, errorHandlerRunCount, 'The stall transition must fire the onError handler exactly once');
			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, execution.Status__c, 'The chain must land Stalled after the transient enqueue failure');
			Assert.isTrue(execution.ErrorMessage__c.contains('Finalizer failed to enqueue next step'), 'The notification must carry the stall reason through to the record');
			Assert.isNull(execution.CompletedAt__c, 'Stalled is non-terminal: CompletedAt must stay unset');
		}
	}

	/**
	 * @description Verifies the single-fire guard: marking a chain Stalled twice enqueues the
	 * onError notification only for the first mark, because the second mark reads a prior status
	 * that is already Stalled and skips the fire. The repeat mark refreshes the stall reason on
	 * the record; the one notification then re-records the first reason it carried when its
	 * write-back lands at stopTest.
	 */
	@IsTest
	private static void shouldFireOnErrorOnceWhenMarkedStalledTwice()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithStallHandler(execution.Id, runKey);

			Test.startTest();
			executor.markChainStalledFromFinalizer(execution.Id, 'First stall mark');
			executor.markChainStalledFromFinalizer(execution.Id, 'Second stall mark');

			AsyncChainExecution__c beforeNotification = queryExecution(execution.Id);
			Assert.isTrue(beforeNotification.ErrorMessage__c.contains('Second stall mark'), 'The repeat mark must refresh the stall reason on the record');
			Test.stopTest();

			Assert.areEqual(1, errorHandlerRunCount, 'The onError notification must fire exactly once per transition into Stalled');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The chain must remain Stalled after the repeat mark');
			Assert.isTrue(result.ErrorMessage__c.contains('First stall mark'), 'The notification write-back must re-record the first stall reason it carried');
			Assert.isNull(result.CompletedAt__c, 'Stalled is non-terminal: CompletedAt must stay unset');
		}
	}

	/**
	 * @description Verifies the degrade branch: when the onError enqueue itself fails in the same
	 * resource-exhausted transaction that caused the stall, the stall write still lands, the
	 * failure is logged, and nothing throws.
	 */
	@IsTest
	private static void shouldDegradeGracefullyWhenStalledOnErrorEnqueueFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithStallHandler(execution.Id, runKey);

			Test.startTest();
			UTIL_AsyncChain.simulateEnqueueFailure = true;
			executor.markChainStalledFromFinalizer(execution.Id, 'Stall with exhausted async budget');
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;
			Test.getEventBus().deliver();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The stall write must land even when the onError enqueue fails');
			Assert.areEqual(0, errorHandlerRunCount, 'The degraded onError enqueue must not run the handler');
			Assert.isTrue(anyLogMessageContains('Stalled onError enqueue failed'), 'The degraded enqueue must log its failure with the stall reason');
		}
	}

	/**
	 * @description Verifies a broken onError handler cannot escalate a Stalled chain to Failed:
	 * when the stalled notification's handler fails, the framework logs the failure and leaves
	 * the record untouched, so the chain stays Stalled and visible to recovery.
	 */
	@IsTest
	private static void shouldKeepChainStalledWhenStalledOnErrorHandlerFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.onError(new UTIL_AsyncChainRecovery_TEST.FailingErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();

			UTIL_AsyncChain.simulateEnqueueFailure = true;
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, execution.Status__c, 'A failing stalled notification handler must not escalate the chain to Failed');
			Assert.isTrue(execution.ErrorMessage__c.contains('Finalizer failed to enqueue next step'), 'The stall reason must survive the failed notification untouched');
			Assert.isNull(execution.CompletedAt__c, 'Stalled is non-terminal: CompletedAt must stay unset');
			Assert.isTrue(anyLogMessageContains('Stalled onError handler failed'), 'The handler failure must be logged, not written to the record');
		}
	}

	/**
	 * @description Verifies a crashing onError handler cannot escalate a Stalled chain to Failed:
	 * the HandlerExecutor Finalizer logs the crash instead of stamping Failed plus a completion
	 * time, so the chain stays Stalled and visible to recovery.
	 */
	@IsTest
	private static void shouldKeepChainStalledWhenStalledOnErrorHandlerCrashes()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.onError(new UTIL_AsyncChainRecovery_TEST.CountingErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();

			UTIL_AsyncChain.simulateEnqueueFailure = true;
			UTIL_AsyncChain.simulateHandlerCrash = true;
			try
			{
				Test.stopTest();
			}
			catch(Exception surfacedCrash)
			{
				Assert.isNotNull(surfacedCrash, 'Simulated handler crash should surface an exception');
			}
			UTIL_AsyncChain.simulateEnqueueFailure = false;
			UTIL_AsyncChain.simulateHandlerCrash = false;
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, execution.Status__c, 'A crashing stalled notification handler must not escalate the chain to Failed');
			Assert.isTrue(execution.ErrorMessage__c.contains('Finalizer failed to enqueue next step'), 'The stall reason must survive the handler crash untouched');
			Assert.isNull(execution.CompletedAt__c, 'Stalled is non-terminal: no completion stamp may land on a chain whose work never completed');
			Assert.isTrue(anyLogMessageContains('Chain left Stalled awaiting recovery'), 'The handler crash must be logged, not written to the record');
		}
	}

	/**
	 * @description Verifies the watchdog sweep marks a stale Running chain Stalled with the sweep
	 * reason, and leaves a chain younger than the threshold untouched. Uses the threshold-window
	 * technique: a 30-minute threshold treats the just-created chain as fresh, then a negative
	 * threshold places the cutoff in the future so the same live row counts as stale — both
	 * polarities without back-dating any audit field.
	 */
	@IsTest
	private static void shouldMarkStuckRunningChainStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(FRESH_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			AsyncChainExecution__c fresh = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, fresh.Status__c, 'A chain younger than the stale threshold must stay Running');
			Assert.isNull(fresh.ErrorMessage__c, 'A fresh chain must carry no stall reason');

			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The sweep must mark a stale Running chain Stalled');
			Assert.isTrue(result.ErrorMessage__c.contains('No live executor detected by watchdog sweep'), 'The stall reason must name the watchdog sweep');
			Assert.isNull(result.CompletedAt__c, 'Stalled is non-terminal: CompletedAt must stay unset');
			Assert.areEqual(0, errorHandlerRunCount, 'A step log without an error-handler entry must not produce a notification');
		}
	}

	/**
	 * @description Verifies that the watchdog stall mark stamps the Stalled failure category
	 * alongside the Stalled status.
	 */
	@IsTest
	private static void shouldCategoriseStallAsStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The sweep must mark a stale Running chain Stalled');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED, result.FailureCategory__c, 'A watchdog stall must be categorised Stalled');
		}
	}

	/**
	 * @description Verifies the sweep fires the onError notification exactly once for a chain whose
	 * persisted step log carries an error-handler definition: the first sweep marks the chain
	 * Stalled and enqueues the notification, and a repeat sweep of the now-already-Stalled chain
	 * must not enqueue a second one (the shared sequence's per-transition single-fire guard).
	 */
	@IsTest
	private static void shouldNotifyPersistedOnErrorHandlerOnceAcrossRepeatSweeps()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJsonWithErrorHandler()
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			AsyncChainExecution__c betweenSweeps = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, betweenSweeps.Status__c, 'The repeat sweep must keep the already-Stalled chain Stalled');
			Test.stopTest();

			Assert.areEqual(1, errorHandlerRunCount, 'The sweep must fire the onError notification exactly once across repeat sweeps');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The chain must remain Stalled after the notification lands');
			Assert.isTrue(result.ErrorMessage__c.contains('No live executor detected by watchdog sweep'), 'The notification write-back must carry the sweep reason');
			Assert.isNull(result.CompletedAt__c, 'Stalled is non-terminal: CompletedAt must stay unset');
		}
	}

	/**
	 * @description Verifies a malformed step log cannot break recovery: the sweep still marks the
	 * chain Stalled and simply skips the notification it cannot resolve a handler from.
	 */
	@IsTest
	private static void shouldSweepChainWithMalformedStepLog()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => 'not step-log json'
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'A malformed step log must not stop the sweep from marking the chain Stalled');
			Assert.areEqual(0, errorHandlerRunCount, 'No notification can fire when the step log cannot be parsed');
		}
	}

	/**
	 * @description The zombie-resurrection half of the accepted lost-abort residual: a Stalled row
	 * carrying a completion timestamp must be invisible to the whole sweep — neither re-marked nor
	 * re-driven — so the contradictory row stops instead of running again with a released key.
	 */
	@IsTest
	private static void shouldNotResurrectAbortedRowOverwrittenToStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME,
					new Map<SObjectField, Object>
					{
							AsyncChainExecution__c.CompletedAt__c => Datetime.now(),
							AsyncChainExecution__c.FailureCategory__c => SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED,
							AsyncChainExecution__c.StepLog__c => buildStepLogJson()
					});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The contradictory row must be left exactly as found');
			Assert.isNull(result.ErrorMessage__c, 'The contradictory row must carry no watchdog mark: an excluded candidate is never re-marked');
			Assert.areEqual(0, errorHandlerRunCount, 'No notification may fire for an excluded candidate');
		}
	}

	/**
	 * @description Verifies the sweep's per-chain failure isolation: when the stall write fails, the
	 * failure is logged with the sweep reason, no notification fires, and nothing throws. Uses the
	 * authorized-mock technique so the sweep and the fresh re-read both see a row whose real record
	 * is gone, forcing the stall DML to fail.
	 */
	@IsTest
	private static void shouldLogAndContinueWhenWatchdogStallWriteFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			Id executionId = execution.Id;
			DML_Builder.newTransaction().doDelete(execution).execute();
			registerAuthorizedExecutionMock(executionId, null);

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.isTrue(anyLogMessageContains('Watchdog stall DML failed'), 'A failed stall write must log the DML failure with the sweep reason');
			Assert.areEqual(0, errorHandlerRunCount, 'A failed stall write must not fire the onError notification');
		}
	}

	/**
	 * @description Verifies the sweep clamps an oversized batch size to its 50-chain ceiling: each
	 * stale row costs the sweep a query and an update, so an unclamped batch would hit a governor
	 * limit mid-sweep, roll back the whole run, and crash-loop on every fire during a mass-stall
	 * incident. Seeds 60 stale Running chains, requests all 60 in one sweep, and expects exactly 50
	 * marked Stalled with the remaining 10 left Running for the next sweep.
	 */
	@IsTest
	private static void shouldClampWatchdogSweepBatchToCeiling()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			TST_Factory.newChainExecutions(OVERSIZED_SWEEP_SEED_COUNT, SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, OVERSIZED_SWEEP_SEED_COUNT);
			Test.stopTest();

			Integer stalledCount = new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_STALLED).size();
			Integer runningCount = new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_RUNNING).size();

			Assert.areEqual(WATCHDOG_BATCH_SIZE, stalledCount, 'The sweep must mark exactly the batch ceiling of chains Stalled');
			Assert.areEqual(OVERSIZED_SWEEP_SEED_COUNT - WATCHDOG_BATCH_SIZE, runningCount, 'Chains beyond the ceiling must stay Running for the next sweep');
		}
	}

	/**
	 * @description Verifies the sweep's async-budget gate: with the transaction's queueable budget
	 * fully consumed, a stale Running chain is parked — marked Stalled with the distinct parked
	 * reason — and its persisted onError notification is NOT enqueued, even though the step log
	 * carries a handler. The no-enqueue polarity is self-enforcing: with zero budget, any enqueue
	 * attempt would raise an uncatchable LimitException and fail this test outright. Runs without
	 * Test.startTest on purpose — startTest opens a fresh governor-limit segment, which would hand
	 * the sweep a full queueable budget again.
	 */
	@IsTest
	private static void shouldParkStaleChainWhenAsyncBudgetExhausted()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJsonWithErrorHandler()
			});

			consumeAllQueueableBudget();
			Integer enqueuedJobsBeforeSweep = UTIL_Limits.queueableJobs().used();

			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual
					(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'With no queueable budget the sweep must park the stale chain Stalled instead of processing it');
			Assert.areEqual(PARKED_NO_BUDGET_REASON, result.ErrorMessage__c, 'A parked chain must carry the distinct no-async-budget reason, not the generic sweep stall reason');
			Assert.areEqual
					(enqueuedJobsBeforeSweep, UTIL_Limits.queueableJobs().used(), 'Parking must not enqueue the onError notification: it costs the slot the gate proved absent');
			Assert.isNull(result.CompletedAt__c, 'Stalled is non-terminal: a parked chain awaits recovery, so CompletedAt must stay unset');
		}
	}

	/**
	 * @description Verifies a parked chain stays re-processable: parking an already-Stalled chain
	 * keeps it Stalled, replaces its stall reason with the parked reason, and fires nothing — the
	 * shared sequence's single-fire guard sees no transition into Stalled, so no notification is
	 * attempted even on a later budget-rich sweep of the same row. Runs without Test.startTest for
	 * the same limit-segment reason as the exhausted-budget parking test.
	 */
	@IsTest
	private static void shouldReparkAlreadyStalledChainWithoutNotifying()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJsonWithErrorHandler(),
					AsyncChainExecution__c.ErrorMessage__c => 'No live executor detected by watchdog sweep'
			});

			consumeAllQueueableBudget();
			Integer enqueuedJobsBeforeSweep = UTIL_Limits.queueableJobs().used();

			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'Parking an already-Stalled chain must keep it Stalled and re-processable by the next sweep');
			Assert.areEqual(PARKED_NO_BUDGET_REASON, result.ErrorMessage__c, 'Re-parking must update the stall reason so the record shows why the sweep set the chain aside');
			Assert.areEqual(enqueuedJobsBeforeSweep, UTIL_Limits.queueableJobs().used(), 'Re-parking must fire nothing: the single-fire guard sees no stall transition');
		}
	}

	/**
	 * @description Verifies the sweep's query-budget gate end-to-end on a near-exhausted budget:
	 * the first candidate is still processed normally (the reserve holds), the gate then refuses
	 * the next candidate, the remaining tail is parked with the distinct no-query-budget reason
	 * for as long as the budget lasts, and the candidate beyond that is left completely untouched
	 * — with nothing thrown even at zero remaining queries. Runs without Test.startTest around the
	 * sweep on purpose — startTest opens a fresh governor-limit segment, which would hand the
	 * sweep a full query budget again; the assertions run inside that fresh segment instead,
	 * because the sweep deliberately ends with no query budget left to read with.
	 */
	@IsTest
	private static void shouldParkSweepTailWhenQueryBudgetRunsShort()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			TST_Factory.newChainExecutions(QUERY_PARK_SEED_COUNT, SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			consumeSoqlBudgetDownTo(QUERY_BUDGET_FOR_ONE_SWEPT_CANDIDATE);

			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			Test.startTest();
			List<String> stalledReasons = new List<String>();
			for(AsyncChainExecution__c chain : new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_STALLED))
			{
				stalledReasons.add(chain.ErrorMessage__c);
			}
			stalledReasons.sort();

			List<String> expectedReasons = new List<String> {'No live executor detected by watchdog sweep', PARKED_NO_QUERY_BUDGET_REASON, PARKED_NO_QUERY_BUDGET_REASON};
			Assert.areEqual(expectedReasons, stalledReasons, 'One candidate must be swept normally, two parked with the query-budget reason, in any order');
			Integer untouchedCount = new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_RUNNING).size();
			Assert.areEqual(1, untouchedCount, 'The candidate beyond the last affordable park must stay Running, untouched, for a later sweep');
			Assert.areEqual(0, errorHandlerRunCount, 'Parking must fire no notification');
			Test.stopTest();
		}
	}

	/**
	 * @description Verifies the re-drive leg's per-chain failure isolation at its rotation write:
	 * a provably-dead candidate whose record vanished between the sweep's read and the rotation
	 * persist (the authorized re-read mock keeps the fresh re-read qualifying while the real row
	 * is gone, so the rotation DML fails on the deleted row) is logged with the re-drive leg's own
	 * message and swallowed — sweepCandidate returns instead of letting the exception abort the
	 * surrounding sweep.
	 */
	@IsTest
	private static void shouldLogAndContinueWhenRedriveRotationWriteFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncApexJob deadJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Aborted')
					.build();
			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.RunKey__c => runKey,
					AsyncChainExecution__c.CurrentJobId__c => String.valueOf(deadJob.Id),
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});
			AsyncChainExecution__c sweepView = queryExecution(execution.Id);
			DML_Builder.newTransaction().doDelete(execution).execute();
			TST_Mock.register(AsyncChainExecution__c.SObjectType, TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.Id, sweepView.Id)
					.withOverride(AsyncChainExecution__c.RunKey__c, runKey)
					.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_RUNNING)
					.withOverride(AsyncChainExecution__c.StepLog__c, buildStepLogJson())
					.withoutInsertion()
					.build());

			Test.startTest();
			UTIL_AsyncChain.sweepCandidate(sweepView);
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.isTrue
					(
							anyLogMessageContains('Watchdog re-drive failed'),
							'A failed rotation write must be logged with the re-drive leg\'s own message instead of aborting the sweep'
					);
			Assert.areEqual(0, errorHandlerRunCount, 'A failed re-drive must not fire the onError notification');
		}
	}

	/**
	 * @description Verifies the sweep survives one candidate's re-drive leg failing and keeps
	 * processing, end-to-end through runWatchdogSweep: a stamped candidate whose liveness probe
	 * raises a real catchable QueryException is logged and left untouched — no mark, no rotation —
	 * while the other candidate is still genuinely marked Stalled with the ordinary sweep reason.
	 * Whichever order the selector returns them in, an escaping exception would fail this test at
	 * the sweep call, and an aborted sweep would leave the healthy candidate Running.
	 */
	@IsTest
	private static void shouldContinueSweepPastFailingRedriveLeg()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncApexJob probedJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Processing')
					.build();
			TST_Mock.throwsException(AsyncApexJob.SObjectType, new QueryException('Simulated liveness probe failure'));
			String probedRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c brokenCandidate = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.RunKey__c => probedRunKey,
					AsyncChainExecution__c.CurrentJobId__c => String.valueOf(probedJob.Id),
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});
			AsyncChainExecution__c healthyCandidate = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c broken = queryExecution(brokenCandidate.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, broken.Status__c, 'A candidate whose re-drive leg failed stays in place, still stale, for a later sweep');
			Assert.areEqual(probedRunKey, broken.RunKey__c, 'No rotation may land when the re-drive leg fails before its decision');
			AsyncChainExecution__c healthy = queryExecution(healthyCandidate.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, healthy.Status__c, 'The sweep must keep processing candidates after one re-drive leg fails');
			Assert.isTrue(healthy.ErrorMessage__c.contains('No live executor detected by watchdog sweep'), 'The surviving candidate must carry the ordinary sweep stall reason');
			Assert.isTrue(anyLogMessageContains('Watchdog re-drive failed'), 'The failed re-drive leg must be logged with its own message');
		}
	}

	/**
	 * @description Verifies the re-drive qualification's newer-activity rejection, both polarities:
	 * a fresh re-read whose LastModifiedDate is newer than the sweep's candidate view means
	 * something wrote the record after the sweep saw it — a live executor may be mid-flight — so
	 * the re-drive skips the candidate (no rotation, no enqueue) and logs the skip; a sweep view
	 * no newer than the fresh read still re-drives the same chain to completion.
	 */
	@IsTest
	private static void shouldSkipRedriveWhenFreshReadShowsNewerActivity()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => runKey,
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});
			AsyncChainExecution__c backdatedSweepView = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.Id, execution.Id)
					.withOverride(AsyncChainExecution__c.RunKey__c, runKey)
					.withOverride(AsyncChainExecution__c.LastModifiedDate, Datetime.now().addMinutes(-BACKDATED_SWEEP_VIEW_AGE_MINUTES))
					.withoutInsertion()
					.build();

			Integer enqueuedJobsBeforeRedrive = UTIL_Limits.queueableJobs().used();
			UTIL_AsyncChain.redriveStalledChain(backdatedSweepView);
			Test.getEventBus().deliver();

			AsyncChainExecution__c skipped = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, skipped.Status__c, 'A candidate with activity newer than the sweep view must stay untouched');
			Assert.areEqual(runKey, skipped.RunKey__c, 'No rotation may land when the fresh read shows newer activity: a live executor may be mid-flight');
			Assert.areEqual(enqueuedJobsBeforeRedrive, UTIL_Limits.queueableJobs().used(), 'A newer-activity skip must cost no executor enqueue');
			Assert.isTrue(anyLogMessageContains('Watchdog re-drive skipped'), 'The newer-activity skip must be logged');

			Test.startTest();
			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));
			Test.stopTest();

			AsyncChainExecution__c recovered = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, recovered.Status__c, 'A sweep view no newer than the fresh read must still re-drive the chain to completion');
			Assert.areNotEqual(runKey, recovered.RunKey__c, 'The equal-timestamp polarity must rotate the run key and recover the chain');
		}
	}

	/**
	 * @description Verifies handler persistence: executing a chain built with onError and onComplete
	 * appends both handler definitions to the persisted StepLog__c after the step entries, flagged
	 * via isErrorHandler / isCompletionHandler, while the executor's step arithmetic ignores them —
	 * the chain completes with the true step total and the handler entries gain no runtime fields.
	 */
	@IsTest
	private static void shouldPersistHandlerEntriesAfterStepsInStepLog()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.onError(new UTIL_AsyncChainRecovery_TEST.ErrorHandlerStep())
					.onComplete(new UTIL_AsyncChainRecovery_TEST.CompletionHandlerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'The executor must not run handler entries as steps: one real step completes the chain');
			Assert.areEqual(1, execution.TotalSteps__c, 'Handler entries are not steps: the persisted step total must not count them');
			Assert.areEqual(1, execution.CompletedSteps__c, 'Only the real step may count as completed');
			Assert.areEqual(true, parseContextData(execution).get('completionHandlerExecuted'), 'The completion handler must still fire through its own executor');

			List<UTIL_AsyncChain.DTO_StepDefinition> persisted = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.areEqual(3, persisted.size(), 'The persisted step log must carry the step plus both handler definitions');
			Assert.areEqual(true, persisted[0].success, 'The first entry is the executed step, carrying its runtime result');
			Assert.isNull(persisted[0].isErrorHandler, 'Step entries carry no handler flag');
			Assert.areEqual(true, persisted[1].isErrorHandler, 'The onError definition must follow the step entries with its flag set');
			Assert.isNull(persisted[1].success, 'Handler entries never gain runtime step fields');
			Assert.areEqual(true, persisted[2].isCompletionHandler, 'The onComplete definition must follow the step entries with its flag set');
		}
	}

	/**
	 * @description Closes the notification gap end-to-end: a chain the builder persisted with an
	 * onError registration stalls with no executor state anywhere, and the watchdog sweep resolves
	 * the notification handler purely from the persisted step log. Executes the builder outside
	 * startTest so the enqueued executor is never delivered — the row stays Running exactly like a
	 * production chain whose executor died.
	 */
	@IsTest
	private static void shouldNotifyBuilderPersistedOnErrorHandlerViaSweep()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.onError(new UTIL_AsyncChainRecovery_TEST.CountingErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			Assert.areEqual(1, errorHandlerRunCount, 'The sweep must resolve the builder-persisted onError handler and notify exactly once');
			AsyncChainExecution__c result = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The sweep marks the stale chain Stalled');
			Assert.isTrue(result.ErrorMessage__c.contains('No live executor detected by watchdog sweep'), 'The notification write-back must carry the sweep reason');
		}
	}

	/**
	 * @description Verifies the watchdog re-drive end-to-end: a stale mid-chain Running row whose
	 * stamped executor job is dead gets its run key rotated (fencing the zombie), a rehydrated
	 * executor enqueued at the persisted completed-step count finishes the remaining step with the
	 * restored context, the completion handler rehydrated from the persisted step log fires, and an
	 * executor still carrying the pre-rotation key is fenced out without double-finalising the
	 * chain. Drives redriveStalledChain directly through its @TestVisible seam because the sweep's
	 * liveness decision that routes dead-plus-budget candidates here is the next task's wiring; the
	 * end-to-end sweep-path variant lands with that wiring.
	 */
	@IsTest
	private static void shouldRedriveStaleChainAndFenceOldExecutor()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String staleRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = seedMidChainDeadRedriveCandidate(staleRunKey);

			AsyncOptions zombieOptions = createAsyncOptions(2);

			Test.startTest();
			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));
			String rotatedRunKey = queryExecution(execution.Id).RunKey__c;
			System.enqueueJob(new UTIL_AsyncChain.ChainExecutor(execution.Id, 1, 50, 32768, null, null, zombieOptions, staleRunKey), zombieOptions);
			Test.stopTest();

			Assert.isNotNull(rotatedRunKey, 'The re-drive must stamp a run key');
			Assert.areNotEqual(staleRunKey, rotatedRunKey, 'The re-drive must rotate the run key so any zombie executor is fenced');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The rehydrated executor must complete the remaining steps');
			Assert.areEqual(2, result.CompletedSteps__c, 'Exactly the one remaining step may run: the zombie is fenced and handler entries are not steps');
			Assert.areEqual(2, result.TotalSteps__c, 'Handler entries persisted in the step log must not change the step total');
			Assert.areEqual(rotatedRunKey, result.RunKey__c, 'The chain must finish under the rotated key: the fenced zombie may not reclaim it');
			Assert.isNotNull(result.CompletedAt__c, 'The rehydrated executor finalises the chain');
			Assert.areEqual(2, parseContextData(result).get('stepCount'), 'The remaining step must run with the restored context, not a fresh one');
			Assert.areEqual(true, parseContextData(result).get('completionHandlerExecuted'), 'The completion handler rehydrated from the persisted step log must fire');
			Assert.areEqual(0, errorHandlerRunCount, 'The rehydrated error handler must not fire on a successful recovery');
		}
	}

	/**
	 * @description Verifies the upgrade path: re-driving a legacy row persisted before the run-key
	 * upgrade (null RunKey__c) stamps a real key — the null key compares equal to the sweep's null
	 * read so the candidate qualifies, and the rotation gives the recovered run a genuine fence.
	 * Uses a Stalled candidate, the other qualifying status polarity next to the main test's
	 * Running row.
	 */
	@IsTest
	private static void shouldStampRealRunKeyWhenRedrivingLegacyChain()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => null,
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});

			Test.startTest();
			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.isNotNull(result.RunKey__c, 'Re-driving a legacy null-key row must stamp a real run key');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The re-driven legacy chain must complete under the current executor');
			Assert.areEqual(1, result.CompletedSteps__c, 'The single rehydrated step must run');
		}
	}

	/**
	 * @description Verifies a chain that reached a terminal status between the sweep's read and the
	 * re-drive is left untouched: the defensive fresh re-read sees Completed, so no key rotation,
	 * no status change and no executor enqueue may happen — a finished chain must never be re-run.
	 */
	@IsTest
	private static void shouldNotRedriveChainCompletedSinceSweepRead()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c sweepView = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.RunKey__c => runKey,
					AsyncChainExecution__c.StepLog__c => buildStepLogJson(),
					AsyncChainExecution__c.CompletedAt__c => Datetime.now()
			});
			sweepView.Status__c = SEL_AsyncChainExecution.STATUS_RUNNING;

			Integer enqueuedJobsBeforeRedrive = UTIL_Limits.queueableJobs().used();
			UTIL_AsyncChain.redriveStalledChain(sweepView);

			AsyncChainExecution__c result = queryExecution(sweepView.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'A concurrently-completed chain must stay Completed');
			Assert.areEqual(runKey, result.RunKey__c, 'No rotation may land on a concurrently-completed chain');
			Assert.areEqual(enqueuedJobsBeforeRedrive, UTIL_Limits.queueableJobs().used(), 'No executor may be enqueued for a concurrently-completed chain');
		}
	}

	/**
	 * @description Verifies a chain claimed by another actor between the sweep's read and the
	 * re-drive is left untouched: the fresh re-read sees a different run key, so the candidate no
	 * longer belongs to this sweep. A record deleted since the sweep's read degrades the same way —
	 * no write, no enqueue, nothing thrown.
	 */
	@IsTest
	private static void shouldNotRedriveChainClaimedSinceSweepRead()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String currentRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.RunKey__c => currentRunKey,
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});
			AsyncChainExecution__c sweepView = queryExecution(execution.Id);
			sweepView.RunKey__c = UTIL_Random.randomUUID();

			Integer enqueuedJobsBeforeRedrive = UTIL_Limits.queueableJobs().used();
			UTIL_AsyncChain.redriveStalledChain(sweepView);

			AsyncChainExecution__c claimedResult = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, claimedResult.Status__c, 'A claimed chain must keep its current status');
			Assert.areEqual(currentRunKey, claimedResult.RunKey__c, 'A claimed chain must keep its claimant key: the sweep may not rotate over it');

			AsyncChainExecution__c deletedView = queryExecution(execution.Id);
			DML_Builder.newTransaction().doDelete(execution).execute();
			UTIL_AsyncChain.redriveStalledChain(deletedView);

			Assert.areEqual(enqueuedJobsBeforeRedrive, UTIL_Limits.queueableJobs().used(), 'Neither a claimed nor a vanished candidate may cost an executor enqueue');
		}
	}

	/**
	 * @description Verifies the unrecoverable degrade: a re-drive candidate whose persisted step log
	 * is unreadable, blank, or inconsistent with the recorded progress is marked terminally Failed
	 * with the actionable reason instead of Stalled — an unreadable step log never repairs itself,
	 * so leaving the row Stalled would only re-park it silently on every future sweep forever.
	 */
	@IsTest
	private static void shouldFailRedriveCandidateWithUnrecoverableStepLog()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c corruptLog = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.StepLog__c => 'not step-log json'
			});
			AsyncChainExecution__c blankLog = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME);
			AsyncChainExecution__c inconsistentProgress = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.CompletedSteps__c => 5,
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});

			UTIL_AsyncChain.redriveStalledChain(queryExecution(corruptLog.Id));
			UTIL_AsyncChain.redriveStalledChain(queryExecution(blankLog.Id));
			UTIL_AsyncChain.redriveStalledChain(queryExecution(inconsistentProgress.Id));

			AsyncChainExecution__c corruptResult = queryExecution(corruptLog.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, corruptResult.Status__c, 'An unparseable step log must fail the candidate terminally');
			Assert.isTrue(corruptResult.ErrorMessage__c.contains(REDRIVE_UNRECOVERABLE_FRAGMENT), 'The failure must carry the actionable re-drive reason');
			Assert.isNotNull(corruptResult.CompletedAt__c, 'Failed is terminal: the degrade must stamp CompletedAt');
			Assert.isNotNull(corruptResult.DurationMs__c, 'A candidate with a start time must receive its duration at terminal failure');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(blankLog.Id).Status__c, 'A blank step log must fail the candidate terminally');
			Assert.areEqual
					(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(inconsistentProgress.Id).Status__c, 'Progress past the persisted step count must fail the candidate');
		}
	}

	/**
	 * @description Verifies that the unrecoverable re-drive degrade stamps the Stalled failure
	 * category (a stall-origin failure) alongside the terminal Failed status.
	 */
	@IsTest
	private static void shouldCategoriseUnrecoverableRedriveAsStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c corruptLog = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.StepLog__c => 'not step-log json'
			});

			UTIL_AsyncChain.redriveStalledChain(queryExecution(corruptLog.Id));

			AsyncChainExecution__c result = queryExecution(corruptLog.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'An unparseable step log must fail the candidate terminally');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED, result.FailureCategory__c, 'An unrecoverable re-drive must be categorised Stalled');
		}
	}

	/**
	 * @description Verifies the sweep degrades a dead-job re-drive candidate whose persisted step
	 * log is a pre-1.4 document truncated mid-array — deserialisation throws, yet no exception
	 * escapes the sweep: the candidate lands terminally Failed with the Stalled category and the
	 * same actionable reason as every other unrecoverable log, its run key rotated by the
	 * terminal-authoritative degrade, its truncated document left in place for inspection, and
	 * the notification skipped without an enqueue because no handler can be resolved from a
	 * document that cannot be read.
	 */
	@IsTest
	private static void shouldFailTruncatedPre14StepLogActionablyOnRedrive()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncApexJob deadJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Aborted')
					.build();
			String staleRunKey = UTIL_Random.randomUUID();
			String truncatedStepLog = buildTruncatedLegacyStepLog();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 2,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => staleRunKey,
					AsyncChainExecution__c.CurrentJobId__c => String.valueOf(deadJob.Id),
					AsyncChainExecution__c.StepLog__c => truncatedStepLog
			});

			Test.startTest();
			Integer enqueuedJobsBeforeSweep = UTIL_Limits.queueableJobs().used();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Assert.areEqual(enqueuedJobsBeforeSweep, UTIL_Limits.queueableJobs().used(), 'The degrade must enqueue neither an executor nor a notification');
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'A truncated step log must fail the candidate terminally');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED, result.FailureCategory__c, 'The stall-origin degrade must be categorised Stalled');
			Assert.isTrue(result.ErrorMessage__c.contains(REDRIVE_UNRECOVERABLE_FRAGMENT), 'The failure must carry the actionable re-drive reason');
			Assert.isNotNull(result.CompletedAt__c, 'Failed is terminal: the degrade must stamp CompletedAt');
			Assert.isNotNull(result.DurationMs__c, 'A candidate with a start time must receive its duration at terminal failure');
			Assert.areNotEqual(staleRunKey, result.RunKey__c, 'The terminal-authoritative degrade must rotate the run key to fence any zombie executor');
			Assert.areEqual(truncatedStepLog, result.StepLog__c, 'The degrade must leave the truncated document in place for inspection');
			Assert.areEqual(0, errorHandlerRunCount, 'No notification can fire when the step log cannot be parsed');
		}
	}

	/**
	 * @description Verifies the sweep's terminal-status gate: a candidate that reached a terminal
	 * status between the selector's read and the per-candidate decision is skipped entirely — no
	 * stall mark, no notification, no reason overwrite — because the shared mark sequence's fresh
	 * re-read refuses terminal rows on the watchdog's unfenced path. Drives sweepCandidate directly
	 * with a stale in-memory view (the direct-invocation precedent), since the live selector can
	 * never return the already-terminal row this race produces.
	 */
	@IsTest
	private static void shouldSkipCandidateThatReachedTerminalStatusSinceSweepRead()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJsonWithErrorHandler(),
					AsyncChainExecution__c.CompletedAt__c => Datetime.now()
			});
			AsyncChainExecution__c sweepView = queryExecution(execution.Id);
			sweepView.Status__c = SEL_AsyncChainExecution.STATUS_RUNNING;

			Integer enqueuedJobsBeforeSweep = UTIL_Limits.queueableJobs().used();
			UTIL_AsyncChain.sweepCandidate(sweepView);

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'A concurrently-completed candidate must keep its terminal status');
			Assert.isNull(result.ErrorMessage__c, 'The sweep must not write a stall reason onto a terminal row');
			Assert.isNotNull(result.CompletedAt__c, 'The completion stamp must survive the sweep untouched');
			Assert.areEqual(0, errorHandlerRunCount, 'No notification may fire for a terminal row');
			Assert.areEqual(enqueuedJobsBeforeSweep, UTIL_Limits.queueableJobs().used(), 'A skipped terminal row must cost no enqueue');
		}
	}

	/**
	 * @description Verifies the slow-but-alive branch: a stale candidate whose stamped executor job
	 * still holds a live platform status is left completely untouched — no stall mark, no
	 * notification, no rotation, no re-drive — because duplicate execution of a live chain is a
	 * worse defect than the stall it would fix. Runs through the real sweep path with the liveness
	 * probe answered by a registered live AsyncApexJob.
	 */
	@IsTest
	private static void shouldSkipSlowButAliveCandidateEntirely()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncApexJob liveJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Processing')
					.build();
			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.RunKey__c => runKey,
					AsyncChainExecution__c.CurrentJobId__c => String.valueOf(liveJob.Id),
					AsyncChainExecution__c.StepLog__c => buildStepLogJsonWithErrorHandler()
			});

			Integer enqueuedJobsBeforeSweep = UTIL_Limits.queueableJobs().used();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'A slow-but-alive chain must stay Running: the sweep may not mark it');
			Assert.isNull(result.ErrorMessage__c, 'The sweep must not write a stall reason under a live executor');
			Assert.areEqual(runKey, result.RunKey__c, 'The sweep must not rotate a live chain: rotation would fence its live executor');
			Assert.areEqual(0, errorHandlerRunCount, 'No notification may fire for a live chain');
			Assert.areEqual(enqueuedJobsBeforeSweep, UTIL_Limits.queueableJobs().used(), 'A live candidate must cost no enqueue');
		}
	}

	/**
	 * @description The end-to-end fence-proof through the real sweep path: a stale mid-chain
	 * Running row whose stamped executor job is provably dead is auto-re-driven by
	 * runWatchdogSweep itself — key rotated, rehydrated executor enqueued at the persisted resume
	 * point, chain finished under the rotated key with the persisted completion handler — while an
	 * executor still carrying the pre-rotation key is fenced out without double-finalising. The
	 * sweep-path companion to shouldRedriveStaleChainAndFenceOldExecutor's direct invocation.
	 */
	@IsTest
	private static void shouldRedriveDeadCandidateThroughSweepPath()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String staleRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = seedMidChainDeadRedriveCandidate(staleRunKey);

			AsyncOptions zombieOptions = createAsyncOptions(2);

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			String rotatedRunKey = queryExecution(execution.Id).RunKey__c;
			System.enqueueJob(new UTIL_AsyncChain.ChainExecutor(execution.Id, 1, 50, 32768, null, null, zombieOptions, staleRunKey), zombieOptions);
			Test.stopTest();

			Assert.areNotEqual(staleRunKey, rotatedRunKey, 'The sweep itself must rotate the run key when it re-drives a dead candidate');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The sweep-enqueued executor must complete the remaining step');
			Assert.areEqual(2, result.CompletedSteps__c, 'Exactly the one remaining step may run: the zombie is fenced');
			Assert.areEqual(rotatedRunKey, result.RunKey__c, 'The chain must finish under the sweep-rotated key');
			Assert.areEqual(2, parseContextData(result).get('stepCount'), 'The remaining step must run with the restored context');
			Assert.areEqual(true, parseContextData(result).get('completionHandlerExecuted'), 'The persisted completion handler must fire on the sweep-driven recovery');
			Assert.areEqual(0, errorHandlerRunCount, 'The persisted error handler must not fire on a successful sweep-driven recovery');
		}
	}

	/**
	 * @description Verifies the CANNOT-CHECK degrade survives a corrupted job-id stamp: a candidate
	 * whose CurrentJobId__c holds text that is not a valid AsyncApexJob id offers no correlation to
	 * probe, so the sweep degrades to detect-mark-notify — exactly like a null stamp — instead of
	 * throwing out of the whole sweep or re-driving what it cannot prove dead.
	 */
	@IsTest
	private static void shouldDegradeToMarkAndNotifyWhenJobIdMalformed()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.RunKey__c => runKey,
					AsyncChainExecution__c.CurrentJobId__c => 'not-a-valid-job-id',
					AsyncChainExecution__c.StepLog__c => buildStepLogJsonWithErrorHandler()
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'An unusable job-id stamp must degrade the candidate to the stall mark');
			Assert.areEqual(runKey, result.RunKey__c, 'A CANNOT-CHECK candidate must never be re-driven: the run key must not rotate');
			Assert.areEqual(1, errorHandlerRunCount, 'The degrade must still notify the persisted onError handler once');
		}
	}

	/**
	 * @description Verifies the unrecoverable degrade notifies before it fails: a re-drive
	 * candidate whose persisted log resolves an onError handler but offers no unattempted step to
	 * resume (every entry already carries a success marker) is marked terminally Failed with the
	 * actionable reason AND its persisted onError handler is notified exactly once through the
	 * shared notification machinery. Also pins the degrade's terminal-authoritative rotation: the
	 * run key changes with the terminal write.
	 */
	@IsTest
	private static void shouldNotifyPersistedHandlerOnUnrecoverableDegrade()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String preDegradeRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => preDegradeRunKey,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.StepLog__c => buildAllAttemptedStepLogWithErrorHandler()
			});

			Test.startTest();
			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'A candidate with no unattempted step to resume must fail terminally');
			Assert.isTrue(result.ErrorMessage__c.contains(REDRIVE_UNRECOVERABLE_FRAGMENT), 'The failure must carry the actionable re-drive reason');
			Assert.areEqual(1, errorHandlerRunCount, 'The degrade must notify the persisted onError handler exactly once before failing');
			Assert.areNotEqual(preDegradeRunKey, result.RunKey__c, 'The degrade must rotate the run key so its Failed verdict is terminal-authoritative');
			Assert.isNotNull(result.CompletedAt__c, 'Failed is terminal: the degrade must stamp CompletedAt');
		}
	}

	/**
	 * @description Verifies the degrade is terminal-authoritative against zombies: after the
	 * unrecoverable degrade rotates the key and fails the chain, a zombie executor still carrying
	 * the pre-degrade key cannot overwrite the actionable Failed verdict — its Finalizer recovery
	 * write is fenced by the rotated key and the record keeps the actionable reason.
	 */
	@IsTest
	private static void shouldFenceZombieBehindTerminalAuthoritativeDegrade()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String zombieRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.RunKey__c => zombieRunKey,
					AsyncChainExecution__c.StepLog__c => 'not step-log json'
			});
			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));

			UTIL_AsyncChain.ChainExecutor zombie = new UTIL_AsyncChain.ChainExecutor(execution.Id, 0, 50, 32768, null, null, createAsyncOptions(2), zombieRunKey);
			zombie.markChainFailedFromFinalizer(execution.Id, 'Zombie crash after degrade');

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'The degraded chain must stay Failed');
			Assert.isTrue(result.ErrorMessage__c.contains(REDRIVE_UNRECOVERABLE_FRAGMENT), 'The zombie write must be fenced: the actionable degrade reason must survive');
			Assert.isFalse(result.ErrorMessage__c.contains('Zombie crash after degrade'), 'The stale-key zombie may not overwrite the terminal-authoritative verdict');
		}
	}

	/**
	 * @description Verifies the resume-point derivation: a re-driven chain resumes at the first
	 * UNATTEMPTED step (success marker null), not at the CompletedSteps__c index. CompletedSteps__c
	 * counts successes only, so after a continueOnError failure the count lags the true position
	 * and indexing by it would replay the already-attempted failed-and-continued step. The fixture
	 * pins both halves: the chain completes cleanly (a replay would append a non-fatal failure
	 * entry to ErrorMessage__c) and only the one genuinely unattempted step runs.
	 */
	@IsTest
	private static void shouldResumeAtFirstUnattemptedStepAfterContinueOnErrorHistory()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 3,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.StepLog__c => buildContinueOnErrorHistoryStepLog(),
					AsyncChainExecution__c.ContextData__c => JSON.serialize(new Map<String, Object> {'stepCount' => 1})
			});

			Test.startTest();
			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The re-driven chain must complete from the first unattempted step');
			Assert.areEqual(2, parseContextData(result).get('stepCount'), 'Exactly one step may run on resume: the unattempted third step');
			Assert.areEqual(2, result.CompletedSteps__c, 'The resumed success joins the one persisted success');
			Assert.isNull(result.ErrorMessage__c, 'No replay may occur: re-running the failed-and-continued step would append a non-fatal failure entry');
		}
	}

	/**
	 * @description Verifies the legacy fallback: a persisted step log with no runtime markers on
	 * any step entry (the shape persisted before runtime markers existed) carries nothing for the
	 * derivation to read, so the re-drive falls back to CompletedSteps__c and resumes past the
	 * recorded successes. The null run key doubles as straddle coverage: a pre-upgrade row
	 * qualifies and recovers.
	 */
	@IsTest
	private static void shouldFallBackToCompletedStepsForLegacyLogWithoutMarkers()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 2,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.StepLog__c => buildLegacyMarkerlessStepLog(),
					AsyncChainExecution__c.ContextData__c => JSON.serialize(new Map<String, Object> {'stepCount' => 1})
			});

			Test.startTest();
			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The legacy chain must complete from the CompletedSteps fallback index');
			Assert.areEqual(2, parseContextData(result).get('stepCount'), 'Only the one step past the recorded successes may run');
			Assert.areEqual(2, result.CompletedSteps__c, 'The resumed success joins the recorded one');
		}
	}

	/**
	 * @description Verifies the retry persist joins the fence uniformly: when the failing step
	 * itself rotated the run key, scheduleRetry's re-attempt write is skipped and no retry link is
	 * enqueued — the persisted step log keeps its original shape with no attempt marker, no failure
	 * lands, and no retry executor ever wakes (a woken one would emit the entry-fence telemetry).
	 */
	@IsTest
	private static void shouldFenceRetryPersistOnStaleKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.RotateAndFailWithRetryStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, execution.Status__c, 'A fenced retry must leave the record on its current run: not Failed, not Stalled');
			Assert.isFalse(execution.StepLog__c.contains('"attempt"'), 'The fenced retry persist must not land its attempt marker');
			Assert.isFalse(execution.StepLog__c.contains('"success"'), 'The fenced retry persist must not rewrite the step log at all');
			Assert.isNull(execution.ErrorMessage__c, 'A fenced executor must not record the failure message');
			Assert.isNull(execution.FailureCategory__c, 'A fenced executor must not categorise anything');
			Assert.areEqual(0, execution.CompletedSteps__c, 'No progress may land behind the fence');
			Assert.isTrue(retryStrategyConsultCount > 0, 'The failing step\'s strategy must have been consulted: the untouched record then proves the fenced retry persist');
			Assert.isFalse(anyLogMessageContains('Chain step retry scheduled'), 'A fenced retry must never report itself as scheduled');
			Assert.isFalse(anyLogMessageContains('stale run key'), 'No retry executor may wake at all: the fence stops the enqueue, not merely a woken retry');
		}
	}

	/**
	 * @description Verifies the entry fence catches a delayed retry executor that outlived a
	 * watchdog re-drive: by the time the delayed executor wakes at the retrying step's index, the
	 * record's key has rotated, so the entry fence exits before any work — nothing persists, the
	 * retry-pending attempt marker survives byte-identical, and the fence telemetry is emitted.
	 * Mirrors shouldFenceExecutorAtEntryOnStaleKey with the retry-pending state seeded.
	 */
	@IsTest
	private static void shouldFenceDelayedRetryExecutorAfterRedrive()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String staleRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 2,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.StepLog__c => buildRetryPendingStepLog(),
					AsyncChainExecution__c.ContextData__c => JSON.serialize(new Map<String, Object> {'stepCount' => 1})
			});
			AsyncChainExecution__c beforeFence = queryExecution(execution.Id);
			AsyncOptions options = createAsyncOptions(2);

			Test.startTest();
			System.enqueueJob(new UTIL_AsyncChain.ChainExecutor(execution.Id, 1, 50, 32768, null, null, options, staleRunKey), options);
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'The entry fence must exit the delayed retry executor without touching the record');
			Assert.areEqual(1, result.CompletedSteps__c, 'No step may run behind the entry fence');
			Assert.areEqual(beforeFence.RunKey__c, result.RunKey__c, 'The re-driven run must keep its rotated key');
			Assert.areEqual(beforeFence.StepLog__c, result.StepLog__c, 'The retry-pending step log must survive byte-identical: the fenced executor persists nothing');
			Assert.areEqual(beforeFence.ContextData__c, result.ContextData__c, 'The persisted context must survive untouched behind the entry fence');
			Assert.isTrue(anyLogMessageContains('stale run key'), 'The entry fence must emit its warn telemetry for the fenced delayed retry');
		}
	}

	/**
	 * @description Verifies the Finalizer routes a transient retry enqueue failure to Stalled,
	 * exactly like the next-step enqueue site: the chain awaits recovery instead of terminally
	 * failing, and the retry-pending markers scheduleRetry persisted survive the sparse stall
	 * write — so a later re-drive resumes AT the retrying step.
	 */
	@IsTest
	private static void shouldRouteRetryEnqueueFailureToStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.FailingWithRetryStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();

			UTIL_AsyncChain.simulateEnqueueFailure = true;
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, execution.Status__c, 'A transient retry enqueue failure must route the chain to Stalled, not Failed');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED, execution.FailureCategory__c, 'A retry enqueue failure is a stall, categorised Stalled');
			Assert.isTrue(execution.ErrorMessage__c.contains('Finalizer failed to enqueue next step'), 'The stall reason must name the failed enqueue');
			Assert.isNull(execution.CompletedAt__c, 'Stalled is non-terminal: CompletedAt must stay unset');
			List<UTIL_AsyncChain.DTO_StepDefinition> persisted = parseStepLog(execution);
			Assert.areEqual(RETRY_PENDING_ATTEMPT, persisted[0].attempt, 'The retry-pending attempt marker must survive the sparse stall write');
			Assert.isNull(persisted[0].success, 'The cleared success marker must survive the stall, so a later re-drive resumes AT the retrying step');
		}
	}

	/**
	 * @description Verifies retry state cannot corrupt recovery: a chain that died mid-retry — its
	 * step log carrying the retry-pending attempt marker with the success marker cleared — is
	 * re-driven by the watchdog sweep AT the retrying step's index, because a cleared success
	 * marker reads as unattempted. The attempt marker survives the recovery, and the resumed
	 * attempt completes the chain without replaying the earlier success.
	 */
	@IsTest
	private static void shouldResumeRetryingStepOnWatchdogRedrive()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncApexJob deadJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Aborted')
					.build();
			String staleRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 2,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => staleRunKey,
					AsyncChainExecution__c.CurrentJobId__c => String.valueOf(deadJob.Id),
					AsyncChainExecution__c.StepLog__c => buildRetryPendingStepLog(),
					AsyncChainExecution__c.ContextData__c => JSON.serialize(new Map<String, Object> {'stepCount' => 1})
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The re-driven retrying chain must complete from the retry-pending step');
			Assert.areEqual(2, result.CompletedSteps__c, 'The resumed attempt joins the one persisted success');
			Assert.areEqual(2, parseContextData(result).get('stepCount'), 'Exactly one step may run on resume: the retrying step, never a replay of the completed one');
			Assert.areNotEqual(staleRunKey, result.RunKey__c, 'The sweep must rotate the run key when it re-drives the dead retrying candidate');
			List<UTIL_AsyncChain.DTO_StepDefinition> persisted = parseStepLog(result);
			Assert.areEqual(RETRY_PENDING_ATTEMPT, persisted[1].attempt, 'The attempt marker must survive the re-drive: the record shows which attempt completed');
			Assert.areEqual(true, persisted[1].success, 'The resumed attempt must record its success on the retrying entry');
			Assert.areEqual(true, persisted[0].success, 'The earlier success marker must survive the recovery untouched');
		}
	}

	/**
	 * @description Verifies the upgrade straddle: a Running row persisted before retries existed —
	 * its step log carrying only the pre-upgrade keys, no attempt or budget fields — re-drives
	 * onto the current executor and takes today's no-retry path verbatim when its step fails:
	 * exactly one attempt runs, the chain fails terminally with the StepException category, and
	 * no attempt key ever reaches the persisted step log.
	 */
	@IsTest
	private static void shouldTakeNoRetryPathForPreUpgradeStepLog()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncApexJob deadJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Aborted')
					.build();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 1,
					AsyncChainExecution__c.CompletedSteps__c => 0,
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.CurrentJobId__c => String.valueOf(deadJob.Id),
					AsyncChainExecution__c.StepLog__c => buildLegacyFailingStepLog()
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			Assert.areEqual(1, failingStepRunCount, 'A pre-upgrade step log must yield exactly one attempt: null attempt and budget fields consult no retry');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'The pre-upgrade chain must fail terminally on its single attempt');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, result.FailureCategory__c, 'A no-retry first-attempt failure stays categorised StepException');
			Assert.isFalse(result.StepLog__c.contains('"attempt"'), 'The no-retry path must never stamp an attempt key onto a pre-upgrade step log');
			Assert.isTrue(result.ErrorMessage__c.contains('Deliberate pre-upgrade failure'), 'The single attempt\'s failure message must land on the record');
			Assert.isNotNull(result.CompletedAt__c, 'Failed is terminal: the single-attempt failure must stamp CompletedAt');
			Assert.areEqual(0, result.CompletedSteps__c, 'The failed step may not count as completed');
		}
	}

	/**
	 * @description Verifies markAborted joins the fence uniformly: an executor whose captured run
	 * key no longer matches the record (a re-driven chain's superseded predecessor) must not land
	 * its kill-switch abort — the record keeps its current status and no terminal stamp appears.
	 * Kill-switch behaviour for the authorized executor is unchanged and covered by
	 * shouldAbortChainWhenKillSwitchActive.
	 */
	@IsTest
	private static void shouldFenceKillSwitchAbortOnStaleKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(UTIL_Random.randomUUID());
			UTIL_AsyncChain.ChainExecutor zombie = new UTIL_AsyncChain.ChainExecutor(execution.Id, 0, 50, 32768, null, null, createAsyncOptions(2), UTIL_Random.randomUUID());
			zombie.markAborted(queryExecution(execution.Id), 'Kill switch active');

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'A stale-key executor must not abort the current run');
			Assert.isNull(result.CompletedAt__c, 'No terminal stamp may land from a fenced abort');
			Assert.isNull(result.ErrorMessage__c, 'No abort reason may land from a fenced abort');
		}
	}

	/**
	 * @description Verifies a recovered chain cannot deterministically overflow on its own context:
	 * a candidate whose persisted context is already larger than the framework-default cap (built
	 * under a larger builder-time cap that is not persisted) re-drives with an effective cap of at
	 * least its existing size, so the resumed step — which here shrinks the context by replacing a
	 * bulky persisted previous-step result — completes instead of overflowing deterministically.
	 */
	@IsTest
	private static void shouldRedriveOversizedContextCandidateWithinExpandedCap()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Map<String, Object> bulkyPreviousResult = new Map<String, Object>
			{
					'success' => true,
					'message' => 'm'.repeat(2000),
					'data' => null
			};
			Map<String, Object> oversizedContext = new Map<String, Object>
			{
					'pad' => 'x'.repeat(33000),
					'stepCount' => 0,
					'__previousStepResult' => bulkyPreviousResult
			};
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.StepLog__c => buildStepLogJson(),
					AsyncChainExecution__c.ContextData__c => JSON.serialize(oversizedContext)
			});

			Test.startTest();
			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The oversized-context candidate must complete under the expanded effective cap');
			Assert.areEqual(1, result.CompletedSteps__c, 'The single rehydrated step must run');
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
			registerAuthorizedExecutionMock(executionId, null);

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							executionId, new UTIL_AsyncChain.ChainContext('test', 'test'), null, 'Failed', null, null
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
			registerAuthorizedExecutionMock(executionId, null);

			AsyncOptions options = createAsyncOptions(2);
			UTIL_AsyncChain.ChainExecutor executor = new UTIL_AsyncChain.ChainExecutor
					(
							executionId, 0, 50, 32768, null, null, options, null
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
	 * @description Verifies that a legacy execution row persisted without a run key (pre-upgrade
	 * data) still completes when driven by an executor whose captured run key is null, mirroring a
	 * deserialized pre-upgrade executor resuming an in-flight chain after the upgrade.
	 */
	@IsTest
	private static void shouldFinaliseLegacyChainWithNullRunKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => null,
					AsyncChainExecution__c.StepLog__c => JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition>
					{
							buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep')
					})
			});

			AsyncOptions options = createAsyncOptions(2);

			Test.startTest();
			System.enqueueJob(new UTIL_AsyncChain.ChainExecutor(execution.Id, 0, 50, 32768, null, null, options, null), options);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'A legacy chain with a null run key should still complete');
			Assert.isNull(result.RunKey__c, 'Driving a legacy chain must not stamp a run key onto its execution record');
		}
	}

	/**
	 * @description Verifies the full upgrade straddle: a multi-step chain that started before the
	 * run-key upgrade, seeded as a null-RunKey__c row mid-flight (one step already completed, its
	 * step-log entry carrying only the pre-upgrade key set, the persisted context holding the
	 * pre-upgrade log context and previous-step result), finishes cleanly when the remaining steps
	 * are driven by the current executor with a null captured run key. Both the mid-chain progress
	 * persist and the terminal completion persist must pass the null == null fence, and the
	 * executor must never retro-stamp a run key onto the legacy row.
	 */
	@IsTest
	private static void shouldFinaliseChainStartedBeforeUpgrade()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			UTIL_AsyncChain.DTO_StepDefinition completedLegacyStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep');
			completedLegacyStep.success = true;
			completedLegacyStep.durationMs = 5;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 3,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => null,
					AsyncChainExecution__c.StepLog__c => JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition>
					{
							completedLegacyStep,
							buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep'),
							buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep')
					}, true),
					AsyncChainExecution__c.ContextData__c => JSON.serialize(new Map<String, Object>
					{
							'__logContext' => LOG_Builder.serializeContext(),
							'stepCount' => 1,
							'__previousStepResult' => new Map<String, Object>
							{
									'success' => true,
									'message' => 'Step completed',
									'data' => null
							}
					})
			});

			AsyncOptions options = createAsyncOptions(3);

			Test.startTest();
			System.enqueueJob(new UTIL_AsyncChain.ChainExecutor(execution.Id, 1, 50, 32768, null, null, options, null), options);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'A chain started before the upgrade should finish cleanly under the current executor');
			Assert.areEqual(3, result.CompletedSteps__c, 'The mid-chain progress persist must pass the null == null fence so the final step can run');
			Assert.isNotNull(result.CompletedAt__c, 'The terminal completion persist must pass the null == null fence');
			Assert.isNull(result.RunKey__c, 'Finishing a pre-upgrade chain must not retro-stamp a run key onto its execution record');
			Assert.areEqual(3, parseContextData(result).get('stepCount'), 'Both remaining steps should have run and incremented the shared context');

			List<UTIL_AsyncChain.DTO_StepDefinition> finalSteps = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(result.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.areEqual(true, finalSteps[1].success, 'The first post-upgrade step should record its success in the step log');
			Assert.areEqual(true, finalSteps[2].success, 'The final post-upgrade step should record its success in the step log');
		}
	}

	/**
	 * @description Verifies the run-key fence silences a zombie executor after a mid-chain key
	 * rotation: once another actor claims the execution record by rotating RunKey__c, the in-flight
	 * executor still carries the old key, so its next persist is skipped, no further step is
	 * enqueued, and the chain is never finalised by the stale run.
	 */
	@IsTest
	private static void shouldFenceOutZombieAfterKeyRotation()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.RotateRunKeyStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(4))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, execution.Status__c, 'A stale run key must fence the executor out: the zombie may not finalise the chain');
			Assert.areEqual(1, execution.CompletedSteps__c, 'The fenced step must not persist its progress write');
		}
	}

	/**
	 * @description Verifies the completion write is fenced when the run key rotates during the
	 * final step: the zombie may not mark the chain Completed.
	 */
	@IsTest
	private static void shouldFenceCompletionWriteAfterKeyRotation()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.RotateRunKeyStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, execution.Status__c, 'The completion write must be fenced out after a mid-run key rotation');
			Assert.isNull(execution.CompletedAt__c, 'A fenced executor must not stamp CompletedAt');
		}
	}

	/**
	 * @description Verifies the step-failure write is fenced when the failing step itself rotated
	 * the run key: the zombie may not mark the chain Failed or record its error message.
	 */
	@IsTest
	private static void shouldFenceStepFailureWriteAfterKeyRotation()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.RotateAndFailStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, execution.Status__c, 'The step-failure write must be fenced out after a mid-run key rotation');
			Assert.isNull(execution.ErrorMessage__c, 'A fenced executor must not record the failure message');
		}
	}

	/**
	 * @description Verifies the context-overflow failure write is fenced when the overflowing step
	 * rotated the run key: the zombie may not mark the chain Failed over the re-driven run.
	 */
	@IsTest
	private static void shouldFenceOverflowFailureWriteAfterKeyRotation()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withMaxContextSize(1)
					.then(new UTIL_AsyncChainRecovery_TEST.RotateRunKeyStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, execution.Status__c, 'The overflow failure write must be fenced out after a mid-run key rotation');
			Assert.isNull(execution.ErrorMessage__c, 'A fenced executor must not record the overflow message');
		}
	}

	/**
	 * @description Verifies an external abort committed mid-step survives the step boundary: the
	 * post-step progress persist carries only the progress fields, so it must not write the loaded
	 * Running status back over the externally-committed Aborted, and the next executor's entry
	 * check must stop the chain without running further steps.
	 */
	@IsTest
	private static void shouldPreserveExternalAbortDuringStep()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.ExternalAbortStep())
					.then(new UTIL_AsyncChainRecovery_TEST.TrackingStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, execution.Status__c, 'An external abort committed mid-step must survive the progress persist');
			Assert.areEqual(1, execution.CompletedSteps__c, 'The step that ran to completion still persists its progress');
			Assert.isNull(execution.CompletedAt__c, 'An externally aborted chain must not be finalised by the in-flight executor');
			Assert.isNull(parseContextData(execution).get('trackingStepExecuted'), 'No further step may run once the external abort is on the record');
		}
	}

	/**
	 * @description An external abort committed during the FINAL step must survive the executor's
	 * terminal completion persist: the refusal reads the fresh row, sees Aborted, and skips the
	 * write, the terminal signal, and the completion bookkeeping.
	 */
	@IsTest
	private static void shouldRefuseCompletionOverExternalAbort()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.ExternalAbortStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, execution.Status__c, 'The committed abort must survive the terminal completion persist');
			Assert.isNull(execution.CompletedAt__c, 'A refused completion must not finalise the aborted row');
			Assert.areEqual(0, countLogsAtSite(executionId, 'handleChainCompletion'), 'A refused completion must emit no terminal signal');
		}
	}

	/**
	 * @description An external abort committed before a failing step's terminal persist must
	 * survive it: handleStepFailure's refusal reads the fresh row and skips write and signal.
	 */
	@IsTest
	private static void shouldRefuseFailureOverExternalAbort()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.AbortThenThrowStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, execution.Status__c, 'The committed abort must survive the terminal failure persist');
			Assert.isNull(execution.CompletedAt__c, 'A refused failure persist must not finalise the aborted row');
			Assert.areEqual(0, countLogsAtSite(executionId, 'handleStepFailure'), 'A refused failure persist must emit no terminal signal');
		}
	}

	/**
	 * @description An external abort committed by a succeeding step whose success then overflows the
	 * context-size limit must survive the overflow failure persist: markFailed's refusal reads the
	 * fresh row, sees Aborted, and skips both the terminal Failed write and its signal. The abort is
	 * committed mid-step (the step passes the executor's entry guard as Running), so this exercises
	 * the ABORTED half of the disjunct, distinct from the stale-key null half.
	 */
	@IsTest
	private static void shouldRefuseOverflowFailureOverExternalAbort()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withMaxContextSize(1)
					.then(new UTIL_AsyncChainRecovery_TEST.ExternalAbortStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, execution.Status__c, 'The committed abort must survive the overflow failure persist');
			Assert.isNull(execution.CompletedAt__c, 'A refused overflow failure must not finalise the aborted row');
			Assert.areEqual(0, countLogsAtSite(executionId, 'markFailed'), 'A refused overflow failure must emit no terminal signal at markFailed');
		}
	}

	/**
	 * @description Positive control for countLogsAtSite: a healthy single-step chain emits exactly
	 * one terminal completion signal, and the counter must see it at the completion site while
	 * returning zero for a non-emitting site suffix and for an unrelated execution record over the
	 * same log set. Without this the refusal tests' countLogsAtSite(...) == 0 assertions could pass
	 * vacuously on a counter silently broken to never match.
	 */
	@IsTest
	private static void shouldCountTerminalSignalAtEmittingSite()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c unrelated = persistRunningExecutionWithKey(UTIL_Random.randomUUID());

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'A healthy single-step chain must complete and signal its completion');
			Assert.areEqual(1, countLogsAtSite(executionId, 'handleChainCompletion'), 'The completion site must emit exactly one terminal signal the counter can see');
			Assert.areEqual(0, countLogsAtSite(executionId, 'handleStepFailure'), 'A non-emitting site suffix must count zero over the same log set');
			Assert.areEqual(0, countLogsAtSite(unrelated.Id, 'handleChainCompletion'), 'An unrelated execution record names no completion signal');
		}
	}

	/**
	 * @description Verifies a healthy chain keeps the run key stamped at enqueue time all the way
	 * through completion, and the terminal persist still delivers every completion field: the
	 * sparse persists drop the fence token from their write sets, never the stamp itself.
	 */
	@IsTest
	private static void shouldPreserveRunKeyThroughHealthyCompletion()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			String stampedRunKey = queryExecution(executionId).RunKey__c;
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.isNotNull(stampedRunKey, 'Starting a chain must stamp a run key onto the execution record');
			Assert.areEqual(stampedRunKey, execution.RunKey__c, 'A healthy run must finish with the run key stamped at enqueue time');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'The chain should complete');
			Assert.areEqual(2, execution.CompletedSteps__c, 'Both steps should persist their progress');
			Assert.isNotNull(execution.CompletedAt__c, 'The terminal persist must stamp CompletedAt');
			Assert.isNotNull(execution.DurationMs__c, 'The terminal persist must record the chain duration');
			Assert.areEqual(2, parseContextData(execution).get('stepCount'), 'The completion persist must carry the final context');
		}
	}

	/**
	 * @description Verifies the executor stamps its own queueable job id onto the execution record
	 * at the progress write, and that the stamp survives to the terminal state: no terminal write
	 * set intends CurrentJobId__c, so completion leaves the last known executor's job id in place
	 * for the watchdog's liveness check.
	 */
	@IsTest
	private static void shouldStampCurrentJobIdAtProgressWrite()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'The chain should complete');
			Assert.isNotNull(execution.CurrentJobId__c, 'The progress write must stamp the executing job id, and no terminal write may clear it');
			Assert.areEqual
					(
							AsyncApexJob.SObjectType,
							Id.valueOf(execution.CurrentJobId__c).getSobjectType(),
							'The stamped value must be the executor AsyncApexJob id the watchdog probes for liveness'
					);
		}
	}

	/**
	 * @description Verifies CurrentJobId__c belongs to the progress write's intended list only: a
	 * single-step chain performs no progress write (its only persist is the terminal completion
	 * write), so the field must stay null — proof that no terminal write set intends the stamp.
	 */
	@IsTest
	private static void shouldNotStampCurrentJobIdViaTerminalWrite()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'The chain should complete');
			Assert.isNull(execution.CurrentJobId__c, 'A single-step chain performs no progress write, so no terminal write may stamp CurrentJobId__c');
		}
	}

	/**
	 * @description Verifies isExecutorLive proves liveness for each of the platform's
	 * pre-execution/executing job statuses. TST_Mock returns the registered rows regardless of the
	 * WHERE Id, so each iteration clears the registry and registers exactly the one job whose
	 * status it asserts.
	 */
	@IsTest
	private static void shouldReportExecutorLiveForEachLiveJobStatus()
	{
		System.runAs(getTestAdmin())
		{
			for(String liveStatus : new List<String> {'Queued', 'Processing', 'Preparing', 'Holding'})
			{
				TST_Mock.clear(AsyncApexJob.SObjectType);
				AsyncApexJob liveJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
						.withOverride(AsyncApexJob.Status, liveStatus)
						.build();

				Assert.isTrue(UTIL_AsyncChain.isExecutorLive(liveJob.Id), 'A job in status ' + liveStatus + ' must prove a live executor');
			}
		}
	}

	/**
	 * @description Verifies a terminal job status yields no liveness proof: the stamped executor
	 * finished or was torn down, so the watchdog may treat this job id as carrying no live executor.
	 */
	@IsTest
	private static void shouldReportExecutorNotLiveForDeadJobStatus()
	{
		System.runAs(getTestAdmin())
		{
			AsyncApexJob deadJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Aborted')
					.build();

			Assert.isFalse(UTIL_AsyncChain.isExecutorLive(deadJob.Id), 'A job in a terminal status must yield no liveness proof');
		}
	}

	/**
	 * @description Verifies an absent AsyncApexJob row yields no liveness proof: with nothing
	 * registered in the mock layer the selector's query path runs for real and finds no row for
	 * the fabricated id.
	 */
	@IsTest
	private static void shouldReportExecutorNotLiveWhenJobRowAbsent()
	{
		System.runAs(getTestAdmin())
		{
			Id absentJobId = UTIL_Random.randomId(AsyncApexJob.SObjectType);

			Assert.isFalse(UTIL_AsyncChain.isExecutorLive(absentJobId), 'An id with no matching AsyncApexJob row must yield no liveness proof');
		}
	}

	/**
	 * @description Verifies a null job id short-circuits to false before any query: a chain whose
	 * record carries no stamped job id offers no correlation to probe, and no correlation can
	 * never prove a live executor.
	 */
	@IsTest
	private static void shouldReportExecutorNotLiveForNullJobId()
	{
		System.runAs(getTestAdmin())
		{
			Integer queriesBeforeProbe = Limits.getQueries();

			Assert.isFalse(UTIL_AsyncChain.isExecutorLive(null), 'A null job id means no correlation to probe, so liveness cannot be proven');
			Assert.areEqual(queriesBeforeProbe, Limits.getQueries(), 'The null-id branch must return before the selector issues its query');
		}
	}

	/**
	 * @description Verifies the in-memory entry gate: an executor waking up with a stale run key
	 * exits before running its step, leaves the record untouched, and emits its warn telemetry.
	 */
	@IsTest
	private static void shouldFenceExecutorAtEntryOnStaleKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(UTIL_Random.randomUUID());
			AsyncOptions options = createAsyncOptions(2);

			Test.startTest();
			System.enqueueJob(new UTIL_AsyncChain.ChainExecutor(execution.Id, 0, 50, 32768, null, null, options, UTIL_Random.randomUUID()), options);
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'An executor with a stale run key must exit at entry without touching the record');
			Assert.areEqual(0, result.CompletedSteps__c, 'No step may run behind the entry fence');

			Boolean foundFenceWarning = anyLogMessageContains('stale run key');
			Assert.isTrue(foundFenceWarning, 'The entry fence should emit its warn telemetry');
		}
	}

	/**
	 * @description Verifies that a stale run key fences the Finalizer failure write: the record
	 * keeps its current run untouched instead of being failed by the zombie.
	 */
	@IsTest
	private static void shouldFenceFinalizerFailureWriteOnStaleKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(UTIL_Random.randomUUID());

			UTIL_AsyncChain.ChainExecutor executor = new UTIL_AsyncChain.ChainExecutor
					(
							execution.Id, 0, 50, 32768, null, null, createAsyncOptions(2), UTIL_Random.randomUUID()
					);

			executor.markChainFailedFromFinalizer(execution.Id, 'Stale zombie failure write');

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'A stale run key must fence the Finalizer failure write');
			Assert.isNull(result.ErrorMessage__c, 'The fenced Finalizer write must not record an error message');
		}
	}

	/**
	 * @description Verifies that a matching real (non-null) run key still allows the Finalizer
	 * failure write: healthy recovery is not blocked by the fence.
	 */
	@IsTest
	private static void shouldAllowFinalizerFailureWriteWithMatchingKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);

			UTIL_AsyncChain.ChainExecutor executor = new UTIL_AsyncChain.ChainExecutor
					(
							execution.Id, 0, 50, 32768, null, null, createAsyncOptions(2), runKey
					);

			executor.markChainFailedFromFinalizer(execution.Id, 'Authorized Finalizer failure write');

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'A matching run key must allow the Finalizer failure write');
			Assert.isTrue(result.ErrorMessage__c.contains('Authorized Finalizer failure write'), 'The authorized write should record the failure message');
			Assert.isNotNull(result.CompletedAt__c, 'The authorized write should stamp CompletedAt');
		}
	}

	/**
	 * @description Verifies that a hard-deleted execution row silences the Finalizer failure write
	 * entirely: no DML is attempted, no recovery log is emitted, and nothing throws.
	 */
	@IsTest
	private static void shouldSilenceFinalizerFailureWriteWhenRecordMissing()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			Id executionId = execution.Id;
			DML_Builder.newTransaction().doDelete(execution).execute();

			UTIL_AsyncChain.ChainExecutor executor = new UTIL_AsyncChain.ChainExecutor
					(
							executionId, 0, 50, 32768, null, null, createAsyncOptions(2), null
					);

			executor.markChainFailedFromFinalizer(executionId, 'Zombie failure write after hard delete');
			Test.getEventBus().deliver();

			Boolean foundFinalizerLog = anyLogMessageContains('Finalizer DML failed') || anyLogMessageContains('Zombie failure write after hard delete');
			Assert.isFalse(foundFinalizerLog, 'A missing execution row must silence the Finalizer failure write entirely');
		}
	}

	/**
	 * @description Verifies that a stale run key fences the Finalizer stall write: the record keeps
	 * its current run untouched and no onError notification fires.
	 */
	@IsTest
	private static void shouldFenceStallWriteOnStaleKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(UTIL_Random.randomUUID());
			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithStallHandler(execution.Id, UTIL_Random.randomUUID());

			Test.startTest();
			executor.markChainStalledFromFinalizer(execution.Id, 'Stale zombie stall write');
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'A stale run key must fence the Finalizer stall write');
			Assert.isNull(result.ErrorMessage__c, 'The fenced stall write must not record a stall reason');
			Assert.areEqual(0, errorHandlerRunCount, 'The fenced stall must not fire the onError notification');
		}
	}

	/**
	 * @description Verifies that a hard-deleted execution row silences the Finalizer stall write
	 * entirely: no DML is attempted, no stall log is emitted, no notification fires, nothing throws.
	 */
	@IsTest
	private static void shouldSilenceStallWriteWhenRecordMissing()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			Id executionId = execution.Id;
			DML_Builder.newTransaction().doDelete(execution).execute();

			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithStallHandler(executionId, null);

			Test.startTest();
			executor.markChainStalledFromFinalizer(executionId, 'Zombie stall write after hard delete');
			Test.stopTest();
			Test.getEventBus().deliver();

			Boolean foundStallLog = anyLogMessageContains('Chain stalled') || anyLogMessageContains('stall DML failed');
			Assert.isFalse(foundStallLog, 'A missing execution row must silence the Finalizer stall write entirely');
			Assert.areEqual(0, errorHandlerRunCount, 'A missing execution row must not fire the onError notification');
		}
	}

	/**
	 * @description Verifies that ChainExecutor.markChainStalledFromFinalizer handles DML failure
	 * gracefully: the failure is logged with the original stall reason, the onError notification
	 * is skipped, and nothing throws.
	 */
	@IsTest
	private static void shouldHandleDmlFailureInStallRecovery()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			Id executionId = execution.Id;
			DML_Builder.newTransaction().doDelete(execution).execute();
			registerAuthorizedExecutionMock(executionId, null);

			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithStallHandler(executionId, null);

			Test.startTest();
			executor.markChainStalledFromFinalizer(executionId, 'Stall write against a deleted row');
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.isTrue(anyLogMessageContains('Finalizer stall DML failed'), 'A failed stall write must log the DML failure');
			Assert.areEqual(0, errorHandlerRunCount, 'A failed stall write must not fire the onError notification');
		}
	}

	/**
	 * @description An operator abort does not rotate the run key, so the Finalizer's fence alone
	 * would authorise marking the aborted row Stalled. The narrow refusal ahead of the fence-split
	 * must stop it on BOTH paths, without notifying.
	 */
	@IsTest
	private static void shouldRefuseStallOverAbortOnFinalizerPath()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipToAborted(execution.Id);
			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithStallHandler(execution.Id, runKey);

			Test.startTest();
			executor.markChainStalledFromFinalizer(execution.Id, 'Transient enqueue failure');
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, result.Status__c, 'An aborted row must never be marked back to Stalled by the Finalizer');
			Assert.areEqual(0, errorHandlerRunCount, 'A refused stall mark must not notify');
		}
	}

	/**
	 * @description The narrow refusal must not acquire the broad terminal semantics: a Finalizer
	 * marking an already-Failed row Stalled is legal today and stays legal.
	 */
	@IsTest
	private static void shouldKeepFinalizerStallOverFailedLegal()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipToFailed(execution.Id);
			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithStallHandler(execution.Id, runKey);

			Test.startTest();
			executor.markChainStalledFromFinalizer(execution.Id, 'Transient enqueue failure');
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'Finalizer stall over a Failed row is deliberately legal (fence-only semantics)');
			Assert.isNotNull(result.CompletedAt__c, 'markStalled must not clear the completion timestamp — D16 and D22 lean on exactly this');
		}
	}

	/**
	 * @description Verifies the handler entry gate: a handler executor waking up with a stale run
	 * key exits before running the subscriber's handler work, so none of the handler's own side
	 * effects are committed, and it emits its warn telemetry. The handler stamps its marker through
	 * its own DML, so the marker's absence proves the work never ran, independently of the fenced
	 * framework status persist.
	 */
	@IsTest
	private static void shouldFenceHandlerWorkAtEntryOnStaleKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(UTIL_Random.randomUUID());

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id,
							new UTIL_AsyncChain.ChainContext(execution.Id, 'test'),
							buildDtoStepDefinition(HandlerSideEffectStep.class.getName(), 'HandlerSideEffect'),
							SEL_AsyncChainExecution.STATUS_COMPLETED,
							null,
							UTIL_Random.randomUUID()
					);

			Test.startTest();
			System.enqueueJob(handlerExecutor);
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.isNull(result.CurrentStepName__c, 'A stale run key must fence the handler out at entry: the handler work must never run, so its own DML marker may not commit');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'The fenced handler must leave the record untouched');

			Boolean foundFenceWarning = anyLogMessageContains('Chain handler skipped');
			Assert.isTrue(foundFenceWarning, 'The handler entry fence should emit its warn telemetry');
		}
	}

	/**
	 * @description Verifies that a stale run key leaves the execution record terminally untouched
	 * by the handler executor: neither a status write nor a context persist reaches the re-driven
	 * run.
	 */
	@IsTest
	private static void shouldFenceHandlerStatusWriteOnStaleKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(UTIL_Random.randomUUID());

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id,
							new UTIL_AsyncChain.ChainContext('test', 'test'),
							buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.CompletionHandlerStep', 'CompletionHandler'),
							SEL_AsyncChainExecution.STATUS_COMPLETED,
							null,
							UTIL_Random.randomUUID()
					);

			Test.startTest();
			System.enqueueJob(handlerExecutor);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'A stale run key must fence the handler status write');
			Assert.isNull(result.ContextData__c, 'The fenced handler must not persist context data');
		}
	}

	/**
	 * @description Verifies the handler persist fence in isolation from the entry gate: a handler
	 * that is still authorized at entry, but whose run key rotates while its work is in flight,
	 * may not persist a terminal status over the run that claimed the record mid-work.
	 */
	@IsTest
	private static void shouldFenceHandlerStatusWriteWhenKeyRotatesDuringWork()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id,
							new UTIL_AsyncChain.ChainContext(execution.Id, 'test'),
							buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.RotateRunKeyStep', 'RotateRunKey'),
							SEL_AsyncChainExecution.STATUS_COMPLETED,
							null,
							runKey
					);

			Test.startTest();
			System.enqueueJob(handlerExecutor);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'The handler status write must be fenced out after a mid-work key rotation');
			Assert.isNull(result.ContextData__c, 'The fenced handler must not persist context data over the claiming run');
		}
	}

	/**
	 * @description An abort committed while a completion handler ran must survive the handler's
	 * expectedStatus write-back: the refusal reads the fresh row and leaves Aborted in place.
	 */
	@IsTest
	private static void shouldRefuseHandlerWriteBackOverExternalAbort()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipToAborted(execution.Id);

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id,
							new UTIL_AsyncChain.ChainContext(execution.Id, 'test'),
							buildDtoStepDefinition(CountingErrorHandlerStep.class.getName(), 'CountingErrorHandler'),
							SEL_AsyncChainExecution.STATUS_COMPLETED,
							null,
							runKey
					);

			Test.startTest();
			System.enqueueJob(handlerExecutor);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, result.Status__c, 'The handler write-back must refuse an aborted row');
		}
	}

	/**
	 * @description An abort committed before a completion handler crashes must survive the handler's
	 * own crash-recovery Finalizer write: markHandlerFailed reads the fresh row, sees Aborted, and
	 * skips the terminal Failed escalation and its signal. The crash is driven through the real
	 * HandlerExecutor dispatch and its attached Finalizer via the production simulateHandlerCrash
	 * seam — the handler entry guard fences only on the run key, so the aborted row still reaches the
	 * crash — rather than by invoking the recovery method directly.
	 */
	@IsTest
	private static void shouldRefuseHandlerCrashRecoveryOverExternalAbort()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipToAborted(execution.Id);

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id,
							new UTIL_AsyncChain.ChainContext(execution.Id, 'test'),
							buildDtoStepDefinition(CompletionHandlerStep.class.getName(), 'CompletionHandler'),
							SEL_AsyncChainExecution.STATUS_COMPLETED,
							null,
							runKey
					);

			UTIL_AsyncChain.simulateHandlerCrash = true;
			Test.startTest();
			System.enqueueJob(handlerExecutor);
			try
			{
				Test.stopTest();
			}
			catch(Exception surfacedCrash)
			{
				Assert.isNotNull(surfacedCrash, 'The simulated handler crash should surface an exception');
			}
			UTIL_AsyncChain.simulateHandlerCrash = false;
			Test.getEventBus().deliver();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, result.Status__c, 'The handler-crash Finalizer recovery write must refuse an aborted row');
			Assert.areEqual(0, countLogsAtSite(execution.Id, 'HandlerExecutor.Finalizer'), 'A refused handler-crash recovery write must emit no terminal signal');
		}
	}

	/**
	 * @description Verifies the upgrade path through the handler entry gate: a pre-upgrade handler
	 * executor deserialized with a null captured run key still runs its work against a legacy
	 * null-key row and persists its terminal status (null == null authorizes, the same contract as
	 * the step executor fence).
	 */
	@IsTest
	private static void shouldRunLegacyHandlerWithNullRunKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(null);

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id,
							new UTIL_AsyncChain.ChainContext(execution.Id, 'test'),
							buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.CompletionHandlerStep', 'CompletionHandler'),
							SEL_AsyncChainExecution.STATUS_COMPLETED,
							null,
							null
					);

			Test.startTest();
			System.enqueueJob(handlerExecutor);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'A pre-upgrade handler with a null captured key must still finalise a legacy null-key row');
			Assert.isTrue((Boolean)parseContextData(result).get('completionHandlerExecuted'), 'The legacy handler work should have run');
			Assert.isNull(result.RunKey__c, 'Finalising a legacy row must not stamp a run key onto it');
		}
	}

	/**
	 * @description Verifies that a stale run key fences the handler recovery write: the zombie's
	 * Finalizer may not mark the chain Failed over the re-driven run.
	 */
	@IsTest
	private static void shouldFenceHandlerRecoveryWriteOnStaleKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(UTIL_Random.randomUUID());

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id, new UTIL_AsyncChain.ChainContext('test', 'test'), null, 'Failed', null, UTIL_Random.randomUUID()
					);

			handlerExecutor.markHandlerFailed(execution.Id, 'Stale zombie handler recovery write');

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'A stale run key must fence the handler recovery write');
			Assert.isNull(result.ErrorMessage__c, 'The fenced handler recovery write must not record an error message');
		}
	}

	/**
	 * @description Verifies that a matching real (non-null) run key still allows the handler
	 * recovery write: healthy handler-crash recovery is not blocked by the fence.
	 */
	@IsTest
	private static void shouldAllowHandlerRecoveryWriteWithMatchingKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id, new UTIL_AsyncChain.ChainContext('test', 'test'), null, 'Failed', null, runKey
					);

			handlerExecutor.markHandlerFailed(execution.Id, 'Authorized handler recovery write');

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'A matching run key must allow the handler recovery write');
			Assert.isTrue(result.ErrorMessage__c.contains('Authorized handler recovery write'), 'The authorized write should record the failure message');
		}
	}

	/**
	 * @description Verifies that a hard-deleted execution row silences the handler recovery write
	 * entirely: no DML is attempted, no recovery log is emitted, and nothing throws.
	 */
	@IsTest
	private static void shouldSilenceHandlerRecoveryWriteWhenRecordMissing()
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
							executionId, new UTIL_AsyncChain.ChainContext('test', 'test'), null, 'Failed', null, null
					);

			handlerExecutor.markHandlerFailed(executionId, 'Zombie handler recovery write after hard delete');
			Test.getEventBus().deliver();

			Boolean foundHandlerLog = anyLogMessageContains('Handler Finalizer DML failed') || anyLogMessageContains('Zombie handler recovery write after hard delete');
			Assert.isFalse(foundHandlerLog, 'A missing execution row must silence the handler recovery write entirely');
		}
	}

	/**
	 * @description Winner-vanished race: the insert retries once against the freed key; when the
	 * retry also collides (the seeded row still holds it), the platform error surfaces verbatim.
	 */
	@IsTest
	private static void shouldRetryInsertOnceWhenWinnerLookupComesUpEmpty()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String deduplicationKey = UTIL_Random.randomUUID();
			TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.ActiveDeduplicationKey__c => deduplicationKey
			});
			TST_Mock.register(AsyncChainExecution__c.SObjectType, new List<AsyncChainExecution__c>());

			DmlException caught;
			try
			{
				UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
						.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
						.withDeduplicationKey(deduplicationKey)
						.execute();
			}
			catch(DmlException secondCollision)
			{
				caught = secondCollision;
			}
			Assert.isNotNull(caught, 'A retry that collides again should surface the platform error');
			Assert.areEqual(StatusCode.DUPLICATE_VALUE, caught.getDmlType(0),
					'The surfaced error should be the duplicate-value collision');
		}
	}

	/**
	 * @description Stalled is not terminal: the stall mark and the successful onError notification
	 * write-back both leave the deduplication key in place, and a same-key start lands on the
	 * stalled run instead of opening a duplicate.
	 */
	@IsTest
	private static void shouldHoldDeduplicationKeyWhileStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String deduplicationKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJsonWithErrorHandler(),
					AsyncChainExecution__c.ActiveDeduplicationKey__c => deduplicationKey
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			AsyncChainExecution__c stalledRun = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, stalledRun.Status__c, 'The sweep must mark the stale chain Stalled');
			Assert.areEqual(1, errorHandlerRunCount, 'The stall transition must have fired the onError notification whose write-back this test pins');
			Assert.areEqual(deduplicationKey, stalledRun.ActiveDeduplicationKey__c,
					'A stalled chain must hold its deduplication key through the stall mark and the notification write-back');

			String landedRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			Assert.areEqual(execution.Id, (Id)landedRunId, 'A same-key start must land on the stalled run — stalled is still active');
		}
	}

	/**
	 * @description The unrecoverable re-drive degrade is terminal: the Failed write releases the
	 * deduplication key and a sequential same-key start opens a fresh run.
	 */
	@IsTest
	private static void shouldReleaseDeduplicationKeyOnRedriveDegrade()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String deduplicationKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c candidate = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.StepLog__c => 'not step-log json',
					AsyncChainExecution__c.ActiveDeduplicationKey__c => deduplicationKey
			});

			UTIL_AsyncChain.redriveStalledChain(queryExecution(candidate.Id));

			AsyncChainExecution__c degradedRun = queryExecution(candidate.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, degradedRun.Status__c, 'An unrecoverable re-drive candidate must fail terminally');
			Assert.isNull(degradedRun.ActiveDeduplicationKey__c,
					'The terminal degrade write must release the deduplication key');

			String secondRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			Assert.areNotEqual(candidate.Id, (Id)secondRunId,
					'A degraded run must free its key for a sequential re-run');
		}
	}

	/**
	 * @description A handler crash's Finalizer failure write is terminal: it releases the
	 * deduplication key and a sequential same-key start opens a fresh run.
	 */
	@IsTest
	private static void shouldReleaseDeduplicationKeyOnHandlerCrash()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			String deduplicationKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => runKey,
					AsyncChainExecution__c.ActiveDeduplicationKey__c => deduplicationKey
			});

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id, new UTIL_AsyncChain.ChainContext('test', 'test'), null, SEL_AsyncChainExecution.STATUS_FAILED, null, runKey
					);

			handlerExecutor.markHandlerFailed(execution.Id, 'Authorized handler recovery write');

			AsyncChainExecution__c failedRun = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, failedRun.Status__c, 'The authorized handler recovery write must fail the chain terminally');
			Assert.isNull(failedRun.ActiveDeduplicationKey__c,
					'The handler recovery failure write must release the deduplication key');

			String secondRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			Assert.areNotEqual(execution.Id, (Id)secondRunId,
					'A terminally failed run must free its key for a sequential re-run');
		}
	}

	/**
	 * @description Release rides only authorized writes: a fenced-out zombie's terminal write may
	 * not clear the deduplication key the current run still holds.
	 */
	@IsTest
	private static void shouldNotClearDeduplicationKeyFromFencedOutZombie()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String deduplicationKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.ActiveDeduplicationKey__c => deduplicationKey
			});

			UTIL_AsyncChain.ChainExecutor zombie = new UTIL_AsyncChain.ChainExecutor
					(
							execution.Id, 0, 50, 32768, null, null, createAsyncOptions(2), UTIL_Random.randomUUID()
					);

			zombie.markChainFailedFromFinalizer(execution.Id, 'Stale zombie failure write');

			AsyncChainExecution__c survivingRun = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, survivingRun.Status__c, 'The stale run key must fence the zombie terminal write');
			Assert.areEqual(deduplicationKey, survivingRun.ActiveDeduplicationKey__c,
					'The deduplication key must survive an unauthorized terminal write — release rides only authorized writes');
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
	 * @description Inserts a Running execution row carrying the given run key, for direct-invocation
	 * fence tests that need full control over the persisted key.
	 *
	 * @param runKey The run key to stamp on the record, or null for a legacy row.
	 *
	 * @return The persisted record with its Id populated.
	 */
	private static AsyncChainExecution__c persistRunningExecutionWithKey(String runKey)
	{
		return TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.StartedAt__c => Datetime.now(),
				AsyncChainExecution__c.RunKey__c => runKey
		});
	}

	/**
	 * @description Flips the given execution record to Aborted through a sparse update, simulating an
	 * external abort committed while an executor or handler is in flight. The run key is untouched,
	 * so the in-flight actor stays authorized: only the refusal keeps the abort alive.
	 *
	 * @param executionId The execution record ID to flip.
	 */
	private static void flipToAborted(Id executionId)
	{
		AsyncChainExecution__c row = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.Id, executionId)
				.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_ABORTED)
				.withOptionalField(AsyncChainExecution__c.ChainName__c)
				.withoutInsertion()
				.build();
		DML_Builder.newTransaction().systemModeInternal().doUpdate(row).execute();
	}

	/**
	 * @description Flips the given execution record to Failed with its completion timestamp stamped,
	 * through the same sparse-update shape as flipToAborted, simulating a terminal failure committed
	 * while a Finalizer is in flight. The run key is untouched, so the fence alone still authorizes
	 * the in-flight actor.
	 *
	 * @param executionId The execution record ID to flip.
	 */
	private static void flipToFailed(Id executionId)
	{
		AsyncChainExecution__c row = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.Id, executionId)
				.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_FAILED)
				.withOverride(AsyncChainExecution__c.CompletedAt__c, Datetime.now())
				.withOptionalField(AsyncChainExecution__c.ChainName__c)
				.withoutInsertion()
				.build();
		DML_Builder.newTransaction().systemModeInternal().doUpdate(row).execute();
	}

	/**
	 * @description Registers a TST_Mock AsyncChainExecution__c row carrying the given run key so a
	 * persist guard's re-read stays authorized even though the real row is gone. Lets the
	 * DML-failure recovery tests reach the DML on a deleted row without the run-key fence
	 * short-circuiting first.
	 *
	 * @param executionId The execution record ID the mock must answer for.
	 * @param runKey The run key the mock reports, matching the executor under test.
	 */
	private static void registerAuthorizedExecutionMock(Id executionId, String runKey)
	{
		TST_Mock.register(AsyncChainExecution__c.SObjectType, TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.Id, executionId)
				.withOverride(AsyncChainExecution__c.RunKey__c, runKey)
				.withoutInsertion()
				.build());
	}

	/**
	 * @description Returns whether any persisted log entry carries a message containing the given
	 * fragment. Shared by the run-key fence tests that assert on emitted (or silenced) telemetry.
	 *
	 * @param fragment The message fragment to search for.
	 *
	 * @return True when at least one log entry message contains the fragment.
	 */
	private static Boolean anyLogMessageContains(String fragment)
	{
		for(LogEntry__c log : new SEL_LogEntry().getAll())
		{
			if(log.Message__c != null && log.Message__c.contains(fragment))
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * @description Counts persisted LogEntry__c rows whose RecordId__c names the given execution and
	 * whose ClassMethod__c ends with the given emitting-site suffix, so the refusal tests can prove
	 * a refused terminal persist emitted no signal at its site.
	 *
	 * @param executionId The chain execution record the signal must name.
	 * @param siteMethodSuffix The emitting site's method-name suffix (e.g. 'handleChainCompletion').
	 *
	 * @return The number of matching log entries.
	 */
	private static Integer countLogsAtSite(Id executionId, String siteMethodSuffix)
	{
		Integer matches = 0;
		for(LogEntry__c logEntry : new SEL_LogEntry().getAll())
		{
			if(logEntry.RecordId__c == String.valueOf(executionId) && logEntry.ClassMethod__c != null && logEntry.ClassMethod__c.endsWith(siteMethodSuffix))
			{
				matches++;
			}
		}
		return matches;
	}

	/**
	 * @description Executes a single-step chain with a CompletionHandler.
	 *
	 * @return The execution record ID.
	 */
	private static String executeWithCompletionHandler()
	{
		return UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
				.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
				.onComplete(new UTIL_AsyncChainRecovery_TEST.CompletionHandlerStep())
				.withAsyncOptions(createAsyncOptions(2))
				.execute();
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
	 * @description Builds a persisted step-log JSON body containing one regular step and no
	 * error-handler entry, for the watchdog tests that assert no notification resolves.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildStepLogJson()
	{
		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep')}, true);
	}

	/**
	 * @description Builds a persisted step-log JSON body containing one regular step plus a
	 * counting error-handler entry, for the watchdog tests that assert how often the persisted
	 * onError notification fires.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildStepLogJsonWithErrorHandler()
	{
		UTIL_AsyncChain.DTO_StepDefinition handlerDefinition = buildDtoStepDefinition(CountingErrorHandlerStep.class.getName(), 'CountingErrorHandler');
		handlerDefinition.isErrorHandler = true;
		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition>
		{
				buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep'),
				handlerDefinition
		}, true);
	}

	/**
	 * @description Builds a persisted step-log JSON document shaped like a mid-chain re-drive
	 * candidate: one completed step, one pending step, then the error- and completion-handler
	 * entries appended after the steps per the serialisation ordering contract.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildMidChainStepLogWithHandlers()
	{
		UTIL_AsyncChain.DTO_StepDefinition completedStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep');
		completedStep.success = true;
		completedStep.durationMs = 5;

		UTIL_AsyncChain.DTO_StepDefinition errorHandlerEntry = buildDtoStepDefinition(CountingErrorHandlerStep.class.getName(), 'CountingErrorHandler');
		errorHandlerEntry.isErrorHandler = true;

		UTIL_AsyncChain.DTO_StepDefinition completionHandlerEntry = buildDtoStepDefinition(CompletionHandlerStep.class.getName(), 'CompletionHandler');
		completionHandlerEntry.isCompletionHandler = true;

		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition>
		{
				completedStep,
				buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep'),
				errorHandlerEntry,
				completionHandlerEntry
		}, true);
	}

	/**
	 * @description Seeds the shared re-drive candidate the fence-proof tests start from: a stale
	 * mid-chain Running row (two steps, one completed) stamped with the caller's pre-rotation run
	 * key, a mocked Aborted AsyncApexJob as the provably-dead current job, the mid-chain step log
	 * with handlers, and the persisted mid-chain context.
	 *
	 * @param staleRunKey The pre-rotation run key to stamp, kept by the caller to prove the fence.
	 *
	 * @return The seeded AsyncChainExecution__c record.
	 */
	private static AsyncChainExecution__c seedMidChainDeadRedriveCandidate(String staleRunKey)
	{
		AsyncApexJob deadJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
				.withOverride(AsyncApexJob.Status, 'Aborted')
				.build();

		return TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.TotalSteps__c => 2,
				AsyncChainExecution__c.CompletedSteps__c => 1,
				AsyncChainExecution__c.StartedAt__c => Datetime.now(),
				AsyncChainExecution__c.RunKey__c => staleRunKey,
				AsyncChainExecution__c.CurrentJobId__c => String.valueOf(deadJob.Id),
				AsyncChainExecution__c.StepLog__c => buildMidChainStepLogWithHandlers(),
				AsyncChainExecution__c.ContextData__c => JSON.serialize(new Map<String, Object> {'stepCount' => 1})
		});
	}

	/**
	 * @description Builds a persisted step-log JSON document whose every step entry carries a
	 * success marker — a chain that attempted all its work but never finalised — plus a counting
	 * error-handler entry, for the unrecoverable-degrade notification tests: with no unattempted
	 * step to resume, the derivation lands past the last entry and the degrade must notify.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildAllAttemptedStepLogWithErrorHandler()
	{
		UTIL_AsyncChain.DTO_StepDefinition attemptedStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep');
		attemptedStep.success = true;
		attemptedStep.durationMs = 5;

		UTIL_AsyncChain.DTO_StepDefinition handlerEntry = buildDtoStepDefinition(CountingErrorHandlerStep.class.getName(), 'CountingErrorHandler');
		handlerEntry.isErrorHandler = true;

		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {attemptedStep, handlerEntry}, true);
	}

	/**
	 * @description Builds a persisted step-log JSON document with a continueOnError history: an
	 * attempted success, an attempted failed-and-continued step, then an unattempted step. The
	 * resume-derivation tests pin that only the third entry — the first with no success marker —
	 * is re-attempted on re-drive.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildContinueOnErrorHistoryStepLog()
	{
		UTIL_AsyncChain.DTO_StepDefinition attemptedSuccess = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep');
		attemptedSuccess.success = true;
		attemptedSuccess.durationMs = 5;

		UTIL_AsyncChain.DTO_StepDefinition attemptedContinuedFailure = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.FailingStep', 'FailingStep');
		attemptedContinuedFailure.continueOnError = true;
		attemptedContinuedFailure.success = false;
		attemptedContinuedFailure.durationMs = 3;
		attemptedContinuedFailure.message = 'Deliberate failure';

		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition>
		{
				attemptedSuccess,
				attemptedContinuedFailure,
				buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep')
		}, true);
	}

	/**
	 * @description Builds a two-step persisted step-log JSON document carrying no runtime markers
	 * on either entry — the legacy shape whose resume point only CompletedSteps__c can supply.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildLegacyMarkerlessStepLog()
	{
		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition>
		{
				buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep'),
				buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep')
		}, true);
	}

	/**
	 * @description Builds a mid-array-truncated pre-1.4 step-log document: the valid serialised
	 * two-entry marker-less list cut at TRUNCATED_STEP_LOG_PERCENT of its length, landing inside
	 * the second entry so deserialisation throws — the shape a partially-written legacy row
	 * leaves behind.
	 *
	 * @return The truncated step-log document.
	 */
	private static String buildTruncatedLegacyStepLog()
	{
		String legacyDocument = buildLegacyMarkerlessStepLog();
		return legacyDocument.substring(0, legacyDocument.length() * TRUNCATED_STEP_LOG_PERCENT / 100);
	}

	/**
	 * @description Builds a persisted step-log JSON document shaped like a chain that died
	 * mid-retry: a completed first step, then a retry-pending second entry carrying the bumped
	 * attempt marker with its success marker cleared — exactly the state scheduleRetry persists
	 * before the delayed re-enqueue.
	 *
	 * @return The serialised step-log JSON.
	 */
	private static String buildRetryPendingStepLog()
	{
		UTIL_AsyncChain.DTO_StepDefinition completedStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep');
		completedStep.success = true;
		completedStep.durationMs = 5;

		UTIL_AsyncChain.DTO_StepDefinition retryPendingStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep');
		retryPendingStep.attempt = RETRY_PENDING_ATTEMPT;

		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {completedStep, retryPendingStep}, true);
	}

	/**
	 * @description Builds a one-entry step-log JSON document in the pre-upgrade shape — only the
	 * className and stepName keys, no attempt or budget fields — whose step always fails, for the
	 * upgrade-straddle test.
	 *
	 * @return The serialised step-log JSON.
	 */
	private static String buildLegacyFailingStepLog()
	{
		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {buildDtoStepDefinition(CountingFailingStep.class.getName(), 'CountingFailingStep')}, true);
	}

	/**
	 * @description Deserialises an execution record's persisted step log into its step
	 * definitions, steps first and handler entries last per the serialisation ordering contract.
	 *
	 * @param execution The execution record carrying StepLog__c.
	 *
	 * @return The deserialised step definitions.
	 */
	private static List<UTIL_AsyncChain.DTO_StepDefinition> parseStepLog(AsyncChainExecution__c execution)
	{
		return (List<UTIL_AsyncChain.DTO_StepDefinition>)JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
	}

	/**
	 * @description Enqueues no-operation queueable jobs until the transaction's queueable budget is
	 * fully consumed, so the budget-gate tests can run the watchdog sweep with
	 * UTIL_Limits.queueableJobs().remaining() at zero. Must run outside Test.startTest — startTest
	 * opens a fresh governor-limit segment, which would hand the sweep a full budget again. The
	 * filler jobs never execute: nothing delivers them and the test transaction rolls back. The
	 * enqueue-in-loop is deliberate and self-bounding — hitting the limit is the loop's exit
	 * condition — hence the targeted suppression.
	 */
	@SuppressWarnings('PMD.OperationWithLimitsInLoop')
	private static void consumeAllQueueableBudget()
	{
		while(!UTIL_Limits.queueableJobs().isExhausted())
		{
			System.enqueueJob(new BudgetConsumingQueueable());
		}
	}

	/**
	 * @description Issues selector reads until the transaction's remaining synchronous query
	 * budget drops to the given target, so the query-budget gate test can run the watchdog sweep
	 * against a deterministic near-exhausted budget. Must run outside Test.startTest — startTest
	 * opens a fresh governor-limit segment, which would hand the sweep a full query budget again.
	 * The query-in-loop is deliberate and self-bounding — reaching the target is the loop's exit
	 * condition — hence the targeted suppression.
	 *
	 * @param targetRemaining The remaining query budget to leave for the code under test.
	 */
	@SuppressWarnings('PMD.OperationWithLimitsInLoop')
	private static void consumeSoqlBudgetDownTo(Integer targetRemaining)
	{
		while(UTIL_Limits.soqlQueries().remaining() > targetRemaining)
		{
			new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_RUNNING);
		}
	}

	/**
	 * @description Builds a direct-invocation ChainExecutor carrying the counting onError handler,
	 * for the stall tests that assert how often the notification fires.
	 *
	 * @param executionId The execution record ID.
	 * @param runKey The run key the executor captured at enqueue time, or null for a legacy row.
	 *
	 * @return The configured executor.
	 */
	private static UTIL_AsyncChain.ChainExecutor buildExecutorWithStallHandler(Id executionId, String runKey)
	{
		return new UTIL_AsyncChain.ChainExecutor
				(
						executionId, 0, 50, 32768,
						buildDtoStepDefinition(CountingErrorHandlerStep.class.getName(), 'CountingErrorHandler'),
						null, createAsyncOptions(2), runKey
				);
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
	 * @description Step that counts its attempts and always fails, with no retry strategy — the
	 * upgrade-straddle oracle proving a pre-upgrade step log takes today's single-attempt path.
	 */
	public class CountingFailingStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			failingStepRunCount++;
			return UTIL_AsyncChain.failed('Deliberate pre-upgrade failure');
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
	 * @description Error handler step that counts its executions, proving the stall notification
	 * fires exactly once per transition into Stalled.
	 */
	public class CountingErrorHandlerStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			errorHandlerRunCount++;
			context.put('errorHandlerExecuted', true);
			return UTIL_AsyncChain.succeeded('Stall handled');
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
	 * @description Step that rotates the execution record's run key mid-chain and succeeds,
	 * simulating another actor (a watchdog re-drive) claiming ownership while this executor
	 * is still in flight.
	 */
	public class RotateRunKeyStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			rotateRunKey(context);
			return UTIL_AsyncChain.succeeded();
		}
	}

	/**
	 * @description Step that rotates the execution record's run key and then fails, driving the
	 * step-failure persist while the executor's captured key is already stale.
	 */
	public class RotateAndFailStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			rotateRunKey(context);
			return UTIL_AsyncChain.failed('Deliberate failure after key rotation');
		}
	}

	/**
	 * @description Step that rotates the execution record's run key and then fails under a
	 * single-retry zero-backoff strategy, driving the retry persist while the executor's captured
	 * key is already stale.
	 */
	public class RotateAndFailWithRetryStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			rotateRunKey(context);
			return UTIL_AsyncChain.failed('Deliberate failure after key rotation');
		}

		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			retryStrategyConsultCount++;
			return UTIL_Retry.exponential().withMaxRetries(1).withBaseBackoff(0);
		}
	}

	/**
	 * @description Step that fails on every attempt under a single-retry zero-backoff strategy,
	 * for the retry-enqueue stall test: the first failure schedules a retry, and the simulated
	 * enqueue failure then stalls the chain with the retry-pending markers already persisted.
	 */
	public class FailingWithRetryStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed('Deliberate retryable failure');
		}

		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return UTIL_Retry.exponential().withMaxRetries(1).withBaseBackoff(0);
		}
	}

	/**
	 * @description Rotates the run key on the execution record backing the given context,
	 * simulating another actor claiming the chain while the current executor is still in flight.
	 *
	 * @param context The chain context carrying the execution record ID.
	 */
	private static void rotateRunKey(UTIL_AsyncChain.ChainContext context)
	{
		AsyncChainExecution__c row = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.Id, (Id)context.getChainExecutionId())
				.withOverride(AsyncChainExecution__c.RunKey__c, UTIL_Random.randomUUID())
				.withOptionalField(AsyncChainExecution__c.ChainName__c)
				.withoutInsertion()
				.build();
		DML_Builder.newTransaction().systemModeInternal().doUpdate(row).execute();
	}

	/**
	 * @description Step that flips its own execution record to Aborted via direct DML and succeeds,
	 * simulating an external abort committed mid-step while the executor is still in flight. The
	 * run key is untouched, so the executor stays authorized: only a sparse write set keeps the
	 * abort alive across the step boundary.
	 */
	public class ExternalAbortStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			AsyncChainExecution__c row = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.Id, (Id)context.getChainExecutionId())
					.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_ABORTED)
					.withOptionalField(AsyncChainExecution__c.ChainName__c)
					.withoutInsertion()
					.build();
			DML_Builder.newTransaction().systemModeInternal().doUpdate(row).execute();
			return UTIL_AsyncChain.succeeded();
		}
	}

	/**
	 * @description Step that flips its own execution record to Aborted via direct DML and then
	 * throws, driving the terminal failure persist while the committed abort already sits on the
	 * row. The run key is untouched, so the executor stays authorized: only the refusal keeps the
	 * abort alive across the failure persist.
	 */
	public class AbortThenThrowStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			AsyncChainExecution__c row = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.Id, (Id)context.getChainExecutionId())
					.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_ABORTED)
					.withOptionalField(AsyncChainExecution__c.ChainName__c)
					.withoutInsertion()
					.build();
			DML_Builder.newTransaction().systemModeInternal().doUpdate(row).execute();
			throw new IllegalArgumentException('Post-abort step failure');
		}
	}

	/**
	 * @description Handler step that stamps an observable marker onto its execution record through
	 * its own DML. The marker is the handler entry-fence test's independent observable: it commits
	 * with the handler's work, outside the framework status persist, so its absence proves the work
	 * never ran rather than that a later persist was fenced.
	 */
	public class HandlerSideEffectStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			AsyncChainExecution__c row = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.Id, (Id)context.getChainExecutionId())
					.withOverride(AsyncChainExecution__c.CurrentStepName__c, HANDLER_SIDE_EFFECT_MARKER)
					.withOptionalField(AsyncChainExecution__c.ChainName__c)
					.withoutInsertion()
					.build();
			DML_Builder.newTransaction().systemModeInternal().doUpdate(row).execute();
			return UTIL_AsyncChain.succeeded();
		}
	}

	/**
	 * @description Minimal queueable whose only purpose is consuming one queueable slot, so the
	 * budget-gate tests can drive the transaction's queueable budget to zero through the real
	 * platform counters. A test fixture this small needs no Finalizer.
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock,PMD.QueueableWithoutFinalizer')
	private class BudgetConsumingQueueable implements Queueable
	{
		/**
		 * @description Performs no work — the enqueue itself consumes the queueable slot under test.
		 *
		 * @param context The queueable context supplied by the platform.
		 */
		public void execute(QueueableContext context)
		{
			// The enqueue itself is the fixture: the budget-gate tests only need the slot consumed.
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
}