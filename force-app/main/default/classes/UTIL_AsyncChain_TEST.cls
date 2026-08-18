// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Comprehensive tests for UTIL_AsyncChain — the async chain orchestration framework.
 * Covers the asynchronous execution path via Queueable, ChainBuilder fluent API,
 * ChainContext state management, StepResult factory methods, error/completion handlers,
 * kill switch, and edge cases. Recovery-path coverage (run-key fencing, stall
 * handling, watchdog sweep, re-drive, liveness, resume markers) lives in
 * UTIL_AsyncChainRecovery_TEST. ApiStep and per-step-retry coverage lives in
 * UTIL_AsyncChainApi_TEST.
 *
 * @see UTIL_AsyncChain
 * @see UTIL_AsyncChainRecovery_TEST
 * @see UTIL_AsyncChainApi_TEST
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date April 2026, August 2026
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
	 * @description Step count for the deep-chain completion pin: long enough that completing it
	 * proves the framework's default AsyncOptions depth (step count + 1) covers every chained
	 * re-enqueue, not just the shallow two- and three-step chains the other tests drive.
	 */
	private static final Integer DEEP_CHAIN_STEP_COUNT = 7;

	/**
	 * @description Caller-supplied queueable stack depth for the first-enqueue clone witnesses:
	 * deliberately unlike any framework-computed default (step count + 1) in these tests, so a
	 * depth observed on the built options can only have been copied from the caller's object.
	 */
	private static final Integer CUSTOM_STACK_DEPTH = 5;

	/**
	 * @description In-range first-step delay (platform range 0-10) handed to the first-enqueue
	 * clone helper, expected back verbatim on the built options and never on the caller's object.
	 */
	private static final Integer DELAY_MINUTES = 5;

	/**
	 * @description Stand-in for the framework-default stack depth (step count + 1) as execute()
	 * computes it for a chain started without custom options — the value that must now reach the
	 * first enqueue instead of being dropped by the old bare-enqueue branch.
	 */
	private static final Integer DEFAULT_DEPTH_FIXTURE = 3;

	/**
	 * @description Length of the deliberately oversized step failure message. Individually it stays
	 * under the default 32,768-character context soft cap (only the latest result is carried in the
	 * context), but five of them accumulated in the step list exceed the 131,072-character
	 * StepLog__c field, so an unbounded copy can never survive repeated continueOnError failures.
	 */
	private static final Integer OVERSIZED_MESSAGE_LENGTH = 30000;

	/**
	 * @description Expected upper bound for the failure-message copy persisted inside StepLog__c.
	 * Independent oracle for the production bound; the canonical full message lives in
	 * ErrorMessage__c and the step-failure log entry.
	 */
	private static final Integer EXPECTED_STEP_MESSAGE_BOUND = 255;

	/**
	 * @description Combined fixed JSON overhead, in characters, of the three-step valve-test chain
	 * outside the two padded step names: the OversizedFailureMessageStep entry (87), the two
	 * PaddedNameStep entries' fixed fields (65 each), the array brackets/commas (4), and ~265 of
	 * deliberate headroom. Sizing each padded name as (capacity - this) / 2 lands the build-time
	 * step list roughly 265 characters under the StepLog__c capacity: past the runtime reserve the
	 * build-time guard withholds (3 steps x 80), but too small to also absorb the failing step's
	 * bounded runtime message (~300 characters), which forces the mid-chain rewrite over capacity
	 * and exercises the message-dropping safety valve.
	 */
	private static final Integer PADDED_CHAIN_JSON_OVERHEAD = 486;

	/**
	 * @description Fixed JSON overhead of a two-PaddedNameStep chain (2 x 65 entry fields + 3 array
	 * characters) plus a 120-character headroom target. Sizing each padded name as
	 * (capacity - this) / 2 lands the build-time step list ~120 characters under the raw field
	 * capacity: inside the per-step runtime reserve execute() withholds (2 steps x 80) while clear
	 * of the pre-retry 2 x 50 reserve, so the guard must reject it even though the raw field could
	 * hold it — and only the bumped reserve makes it do so.
	 */
	private static final Integer PADDED_PAIR_JSON_OVERHEAD = 253;

	/**
	 * @description Explicit context cap for the oversized-message chains, giving the 30,000-character
	 * failure message comfortable room in the persisted previous-step result so ambient LOG-context
	 * growth can never tip these tests over the default 32,768 soft cap with a misleading
	 * context-overflow failure.
	 */
	private static final Integer OVERSIZED_MESSAGE_CONTEXT_CAP = 60000;

	/**
	 * @description Initial-context key seeded by the restart-declaration tests, expected verbatim in
	 * the as-built snapshot captured on the run record.
	 */
	private static final String RESTART_SEED_KEY = 'restartSeedKey';

	/**
	 * @description Initial-context value seeded by the restart-declaration tests, expected verbatim in
	 * the as-built snapshot captured on the run record.
	 */
	private static final String RESTART_SEED_VALUE = 'restart-seed-value';

	/**
	 * @description Context key SuccessStep writes while the chain runs — present in the evolved
	 * context but never in the as-built snapshot, so the restart tests can tell the two apart.
	 */
	private static final String EVOLVED_CONTEXT_KEY = 'stepCount';

	/**
	 * @description Deduplication key handed to withDeduplicationKey by the declared-key round-trip
	 * test, expected back verbatim on the terminal record after the active key is released.
	 */
	private static final String DECLARED_DEDUPLICATION_KEY = 'declared-deduplication-key-witness';

	/**
	 * @description Failure message carried by the declared-permanent failure fixture.
	 */
	private static final String PERMANENT_FAILURE_MESSAGE = 'Declared permanent failure';

	/**
	 * @description Fixed JSON characters around each undeclared step's class name in the insert-time
	 * StepLog__c document: the entry braces plus the className key and its quoting — the pre-change
	 * byte shape of a healthy step entry, which the null-suppressed declaration markers must not grow.
	 */
	private static final Integer HEALTHY_STEP_ENTRY_JSON_OVERHEAD = 16;

	/**
	 * @description Fixed JSON characters of the two-entry step-list document outside its entries: the
	 * array brackets plus the single separating comma.
	 */
	private static final Integer HEALTHY_STEP_LIST_JSON_OVERHEAD = 3;

	/**
	 * @description Deduplication key shared by the two launches in the deduplication-landing test, so
	 * the second launch lands on the first chain instead of starting a run of its own.
	 */
	private static final String SHARED_DEDUPLICATION_KEY = 'shared-deduplication-key-witness';

	/**
	 * @description Emitting-site suffix of the announcement a launch writes when it had to record its
	 * chain under a freshly minted correlation. Its own site, not the launch site, so the announcement
	 * never counts as the empty-chain completion signal that shares ChainBuilder.execute.
	 */
	private static final String MINTED_CORRELATION_SITE = 'announceMintedCorrelation';

	/**
	 * @description Independent oracle for the holder wording the correlation refusal falls back to when
	 * the run holding the correlation started outside this transaction — the shape a subscriber reads.
	 */
	private static final String UNNAMED_HOLDER_FRAGMENT = 'another chain execution';

	/**
	 * @description Independent oracle for the remedy the correlation refusal must spell out, so the
	 * caller is told how to launch several chains under one log correlation.
	 */
	private static final String CORRELATION_REMEDY_FRAGMENT = 'execute(correlationId)';

	/**
	 * @description Step name the next PaddedNameStep construction reports, seeded by each test before
	 * building its chain (same static-seam pattern as the production simulateCrash flag).
	 */
	private static String paddedStepName;

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
	 * @description Verifies a seven-step chain completes end-to-end through the real async path
	 * under the framework's default AsyncOptions — no builder override, so the depth in force is
	 * the one execute() derives (step count + 1). Pins the deep-chain envelope: a regression in
	 * that derivation, or a platform change to chained-queueable depth, fails here before any
	 * production chain does.
	 */
	@IsTest
	private static void shouldCompleteSevenStepChain()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = executeSevenStepDefaultOptionsChain();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'A seven-step chain under default options must complete');
			Assert.areEqual(DEEP_CHAIN_STEP_COUNT, execution.TotalSteps__c, 'The record must carry the full chain length');
			Assert.areEqual(DEEP_CHAIN_STEP_COUNT, execution.CompletedSteps__c, 'Every step of the deep chain must be counted complete');
			Assert.areEqual(DEEP_CHAIN_STEP_COUNT, parseContextData(execution).get('stepCount'), 'Each step must actually run: SuccessStep increments the counter once per step');
			Assert.isNotNull(execution.CompletedAt__c, 'Completed is terminal: CompletedAt must be stamped');
			Assert.isNull(execution.ErrorMessage__c, 'A clean completion must carry no error message');
			Assert.isNull(execution.FailureCategory__c, 'A clean completion must carry no failure category');
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
			AsyncChainExecution__c dummy = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'Dummy', new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 0
			});
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

			AsyncChainExecution__c record = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.CurrentStepName__c => 'FinalStep',
					AsyncChainExecution__c.CorrelationId__c => correlationId,
					AsyncChainExecution__c.TotalSteps__c => 3,
					AsyncChainExecution__c.CompletedSteps__c => 3,
					AsyncChainExecution__c.ErrorMessage__c => null,
					AsyncChainExecution__c.StartedAt__c => startedAt,
					AsyncChainExecution__c.CompletedAt__c => completedAt,
					AsyncChainExecution__c.DurationMs__c => 4200
			});

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
			AsyncChainExecution__c record = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 3,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.StartedAt__c => Datetime.now().addMinutes(-2),
					AsyncChainExecution__c.DurationMs__c => null
			});

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
			AsyncChainExecution__c record = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 3,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.ErrorMessage__c => 'Step 2 blew up',
					AsyncChainExecution__c.StartedAt__c => Datetime.now().addMinutes(-1),
					AsyncChainExecution__c.DurationMs__c => 60000
			});

			UTIL_AsyncChain.ChainStatus status = UTIL_AsyncChain.getChainStatus(record.Id);

			Assert.isNotNull(status, 'ChainStatus should not be null for a Failed execution');
			Assert.areEqual('Step 2 blew up', status.errorMessage, 'errorMessage should map');
			Assert.isTrue(status.isFailed(), 'A Failed chain reports failed');
			Assert.isTrue(status.isTerminal(), 'A Failed chain is terminal');
			Assert.isFalse(status.isRunning(), 'A Failed chain is not running');
		}
	}

	/**
	 * @description A Stalled row carrying a completion timestamp is a clobbered terminal row (the
	 * accepted lost-abort residual). isTerminal() must report it terminal so subscriber polling
	 * exits; a genuinely stalled row (null timestamp) stays non-terminal and recoverable.
	 */
	@IsTest
	private static void shouldReportContradictoryStalledRowTerminal()
	{
		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c contradictory = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME,
					new Map<SObjectField, Object> {AsyncChainExecution__c.CompletedAt__c => Datetime.now()});
			AsyncChainExecution__c genuine = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME + '-genuine');

			UTIL_AsyncChain.ChainStatus contradictoryStatus = UTIL_AsyncChain.getChainStatus(contradictory.Id);
			UTIL_AsyncChain.ChainStatus genuineStatus = UTIL_AsyncChain.getChainStatus(genuine.Id);

			Assert.isTrue(contradictoryStatus.isTerminal(), 'A completion timestamp proves the chain ended, whatever Status__c says');
			Assert.isFalse(contradictoryStatus.isRunning(), 'A contradictory row is not running');
			Assert.isFalse(genuineStatus.isTerminal(), 'A genuine stall (null timestamp) stays non-terminal');
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
			AsyncChainExecution__c dummy = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'Dummy', new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 0
			});
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
			AsyncChainExecution__c record = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 2,
					AsyncChainExecution__c.CompletedSteps__c => 2,
					AsyncChainExecution__c.ErrorMessage__c => null
			});

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
			record = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now()
			});
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
			AsyncChainExecution__c first = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.CompletedSteps__c => 1
			});
			AsyncChainExecution__c second = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 2,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.ErrorMessage__c => 'boom'
			});
			AsyncChainExecution__c removed = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'Removed', new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 0
			});
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
	 * @description Verifies the first-enqueue options builder carries custom AsyncOptions through a
	 * DELAYED first enqueue — the branch that historically dropped them — and that it returns a
	 * clone: the delay rides the built options only, and the caller's object (which becomes the
	 * executor baton every later hop re-uses) stays byte-unchanged, asserted property-by-property.
	 */
	@IsTest
	private static void shouldCarryCustomOptionsThroughDelayedFirstEnqueue()
	{
		System.runAs(getTestAdmin())
		{
			AsyncOptions custom = new AsyncOptions();
			custom.maximumQueueableStackDepth = CUSTOM_STACK_DEPTH;
			AsyncOptions built = UTIL_AsyncChain.buildFirstEnqueueOptions(custom, DELAY_MINUTES);
			Assert.areEqual(CUSTOM_STACK_DEPTH, built.maximumQueueableStackDepth, 'Custom depth must survive a delayed first enqueue');
			Assert.areEqual(DELAY_MINUTES, built.minimumQueueableDelayInMinutes, 'Delay must ride the options object');
			Assert.isNull(custom.minimumQueueableDelayInMinutes, 'Caller options must stay delay-free (delay repeats every hop otherwise)');
			Assert.areEqual(CUSTOM_STACK_DEPTH, custom.maximumQueueableStackDepth, 'Caller options must be byte-unchanged by the clone');
		}
	}

	/**
	 * @description Verifies the first-enqueue options builder forwards the framework-default stack
	 * depth to an undelayed first enqueue with no custom options — the branch that historically
	 * enqueued bare, so the depth default only took effect from the second hop — and sets no delay
	 * when none is configured.
	 */
	@IsTest
	private static void shouldApplyDefaultDepthOnUndelayedFirstEnqueueWithoutCustomOptions()
	{
		System.runAs(getTestAdmin())
		{
			AsyncOptions defaults = new AsyncOptions();
			defaults.maximumQueueableStackDepth = DEFAULT_DEPTH_FIXTURE;
			AsyncOptions built = UTIL_AsyncChain.buildFirstEnqueueOptions(defaults, null);
			Assert.areEqual(DEFAULT_DEPTH_FIXTURE, built.maximumQueueableStackDepth, 'Depth default must now reach the first hop');
			Assert.isNull(built.minimumQueueableDelayInMinutes, 'No delay configured means no delay set');
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
	 * @description Verifies that a step returning a failed StepResult stamps the StepException
	 * failure category alongside the terminal Failed status.
	 */
	@IsTest
	private static void shouldCategoriseStepFailureAsStepException()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.FailingStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should be Failed');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, execution.FailureCategory__c, 'A step failure must be categorised StepException');
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
	 * @description Verifies that repeated continueOnError failures whose messages are each under the
	 * context soft cap, but together larger than the StepLog__c field, still let the chain complete
	 * with valid step-log JSON: every persisted failure-message copy is bounded rather than the JSON
	 * document being truncated, so a later step's deserialize cannot throw and override the caller's
	 * explicit continueOnError intent.
	 *
	 * @date July 2026
	 */
	@IsTest
	private static void shouldCompleteWithValidStepLogWhenAccumulatedFailureMessagesExceedFieldCapacity()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.OversizedFailureMessageStep())
					.then(new UTIL_AsyncChain_TEST.OversizedFailureMessageStep())
					.then(new UTIL_AsyncChain_TEST.OversizedFailureMessageStep())
					.then(new UTIL_AsyncChain_TEST.OversizedFailureMessageStep())
					.then(new UTIL_AsyncChain_TEST.OversizedFailureMessageStep())
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withMaxContextSize(OVERSIZED_MESSAGE_CONTEXT_CAP)
					.withAsyncOptions(createAsyncOptions(7))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c,
					'Chain should complete despite the accumulated oversized failure messages — continueOnError intent must survive');
			Assert.areEqual(1, execution.CompletedSteps__c, 'Only the successful step should be counted');
			List<UTIL_AsyncChain.DTO_StepDefinition> persistedSteps = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.areEqual(6, persistedSteps.size(), 'Step log should remain a valid six-entry JSON document');
			for(Integer index = 0; index < 5; index++)
			{
				Assert.isNotNull(persistedSteps[index].message,
						'Bounded failure message ' + index + ' should be persisted, not dropped');
				Assert.isTrue(persistedSteps[index].message.length() <= EXPECTED_STEP_MESSAGE_BOUND,
						'Persisted failure message ' + index + ' should be bounded; was ' + persistedSteps[index].message.length() + ' characters');
			}
		}
	}

	/**
	 * @description Verifies that execute() reserves runtime headroom: a step list that fits the raw
	 * StepLog__c field but leaves no room for the per-step success/duration fields added as steps
	 * execute must be rejected at definition time — otherwise the chain would pass the guard and
	 * still die on a mid-flight persist even after the safety valve drops every message.
	 *
	 * @date July 2026
	 */
	@IsTest
	private static void shouldFailFastWhenStepListLeavesNoRuntimeHeadroom()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Integer fieldCapacity = AsyncChainExecution__c.StepLog__c.getDescribe().getLength();
			paddedStepName = 'N'.repeat((fieldCapacity - PADDED_PAIR_JSON_OVERHEAD) / 2);

			try
			{
				UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
						.then(new UTIL_AsyncChain_TEST.PaddedNameStep())
						.then(new UTIL_AsyncChain_TEST.PaddedNameStep())
						.execute();
				Assert.fail('execute() should throw when the step list leaves no runtime headroom in StepLog__c');
			}
			catch(UTIL_Exceptions.IllegalStateException expected)
			{
				Assert.isTrue(expected.getMessage().contains(String.valueOf(fieldCapacity)),
						'Overflow error should state the field capacity. Got: ' + expected.getMessage().left(300));
			}

			Assert.isTrue(new SEL_AsyncChainExecution().findByChainName(TEST_CHAIN_NAME).isEmpty(),
					'Runtime-headroom guard must throw before any execution row is inserted');
		}
	}

	/**
	 * @description Verifies the safety valve on the terminal-failure persist: when a halting
	 * (non-continueOnError) step fails with a near-capacity step list, the Failed record still
	 * carries valid step-log JSON with messages dropped, step names intact, and the canonical
	 * failure message in ErrorMessage__c.
	 *
	 * @date July 2026
	 */
	@IsTest
	private static void shouldDropStepMessagesOnTerminalFailureWhenStepLogWouldOverflow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Integer fieldCapacity = AsyncChainExecution__c.StepLog__c.getDescribe().getLength();
			paddedStepName = 'N'.repeat((fieldCapacity - PADDED_CHAIN_JSON_OVERHEAD) / 2);

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.HaltingOversizedFailureMessageStep())
					.then(new UTIL_AsyncChain_TEST.PaddedNameStep())
					.then(new UTIL_AsyncChain_TEST.PaddedNameStep())
					.withMaxContextSize(OVERSIZED_MESSAGE_CONTEXT_CAP)
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should halt on the non-continueOnError failure');
			Assert.isTrue(execution.ErrorMessage__c.startsWith('FFF'), 'Canonical failure message should reach ErrorMessage__c');
			List<UTIL_AsyncChain.DTO_StepDefinition> persistedSteps = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.areEqual(3, persistedSteps.size(), 'Step log on the Failed record should remain a valid three-entry JSON document');
			Assert.isNull(persistedSteps[0].message,
					'Per-step failure messages should be dropped from the terminal persist when the step log would otherwise overflow');
			Assert.areEqual(false, persistedSteps[0].success, 'Runtime success state should survive the message drop');
			Assert.areEqual(paddedStepName.length(), persistedSteps[1].stepName.length(),
					'Step names should survive the message drop un-truncated');
		}
	}

	/**
	 * @description Verifies that execute() rejects a chain whose serialized step list cannot fit the
	 * StepLog__c field, instead of silently truncating the JSON document at insert time.
	 *
	 * @date July 2026
	 */
	@IsTest
	private static void shouldFailFastAtExecuteWhenStepListExceedsFieldCapacity()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Integer fieldCapacity = AsyncChainExecution__c.StepLog__c.getDescribe().getLength();
			paddedStepName = 'N'.repeat(fieldCapacity / 2);

			try
			{
				UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
						.then(new UTIL_AsyncChain_TEST.PaddedNameStep())
						.then(new UTIL_AsyncChain_TEST.PaddedNameStep())
						.execute();
				Assert.fail('execute() should throw when the serialized step list exceeds the StepLog__c capacity');
			}
			catch(UTIL_Exceptions.IllegalStateException expected)
			{
				Assert.isTrue(expected.getMessage().contains(String.valueOf(fieldCapacity)),
						'Overflow error should state the field capacity. Got: ' + expected.getMessage().left(300));
			}

			Assert.isTrue(new SEL_AsyncChainExecution().findByChainName(TEST_CHAIN_NAME).isEmpty(),
					'Fail-fast guard must throw before any execution row is inserted');
		}
	}

	/**
	 * @description Verifies the mid-chain safety valve: when a progress rewrite of the step list
	 * would overflow StepLog__c even with bounded messages, the per-step message values are dropped
	 * from the persisted copy rather than the JSON document ever being truncated. The canonical
	 * failure records live in ErrorMessage__c and the step-failure log entries.
	 *
	 * @date July 2026
	 */
	@IsTest
	private static void shouldDropStepMessagesWhenMidChainStepLogWouldOverflow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Integer fieldCapacity = AsyncChainExecution__c.StepLog__c.getDescribe().getLength();
			paddedStepName = 'N'.repeat((fieldCapacity - PADDED_CHAIN_JSON_OVERHEAD) / 2);

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.OversizedFailureMessageStep())
					.then(new UTIL_AsyncChain_TEST.PaddedNameStep())
					.then(new UTIL_AsyncChain_TEST.PaddedNameStep())
					.withMaxContextSize(OVERSIZED_MESSAGE_CONTEXT_CAP)
					.withAsyncOptions(createAsyncOptions(4))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c,
					'Chain should complete despite the step log approaching capacity');
			Assert.areEqual(2, execution.CompletedSteps__c, 'Both padded success steps should be counted');
			List<UTIL_AsyncChain.DTO_StepDefinition> persistedSteps = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.areEqual(3, persistedSteps.size(), 'Step log should remain a valid three-entry JSON document');
			Assert.isNull(persistedSteps[0].message,
					'Per-step failure messages should be dropped when the step log would otherwise overflow');
			Assert.areEqual(false, persistedSteps[0].success, 'Runtime success state should survive the message drop');
			Assert.areEqual(paddedStepName.length(), persistedSteps[1].stepName.length(),
					'Step names should survive the message drop un-truncated');
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
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.TrackingStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, execution.Status__c, 'Chain should be Aborted');
			Assert.isTrue(execution.ErrorMessage__c.contains('Kill switch'), 'Error message should mention kill switch');
			Map<String, Object> contextData = parseContextData(execution);
			Assert.isNull(contextData.get('trackingStepExecuted'), 'Step should not have executed');
			Assert.areEqual(1, countTerminalLogs(executionId, 'markAborted', 'WARN'), 'The kill-switch abort emits exactly one WARN signal at its own site');
		}
	}

	/**
	 * @description Verifies that a kill-switch abort stamps the KillSwitch failure category
	 * alongside the terminal Aborted status.
	 */
	@IsTest
	private static void shouldCategoriseKillSwitchAbort()
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
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_KILL_SWITCH, execution.FailureCategory__c, 'A kill-switch abort must be categorised KillSwitch');
		}
	}

	/**
	 * @description The shipped AsyncChain flag must resolve ENABLED through the REAL metadata —
	 * the flag record, its hierarchy-setting strategy record, and no runtime-switch row — exactly
	 * as an untouched org resolves it after upgrade: the strategy finds no
	 * AsyncChainRuntimeSwitch__c row, reports no match, and the flag's ResultOnNoMatch keeps
	 * chains enabled. Deliberately seeds NO flag mock: the shipped records are the subject under
	 * test (the upgrade-neutrality witness). The precondition pin distinguishes the no-match
	 * fallback from the strategy-less IsEnabledByDefault branch — both resolve true on the
	 * shipped record, so without the pin a deleted strategy record would leave this green.
	 */
	@IsTest
	private static void shouldResolveChainFlagEnabledWithStrategyRecordAndNoSettingRow()
	{
		System.runAs(getTestAdmin())
		{
			FeatureFlag__mdt chainFlag = SEL_FeatureFlag.activeFlags.get(UTIL_AsyncChain.FEATURE_FLAG_NAME);
			Assert.areEqual(1, chainFlag.FeatureFlagStrategies__r?.size(),
					'Precondition: the shipped AsyncChain flag must carry exactly its hierarchy-setting strategy; without one, '
					+ 'resolution falls to IsEnabledByDefault and this witness could not regression-guard the strategy record');
			Assert.areEqual(SEL_FeatureFlagStrategy.TYPE_HIERARCHICAL_CUSTOM_SETTING, chainFlag.FeatureFlagStrategies__r[0].Type__c,
					'Precondition: the shipped strategy must resolve through the hierarchy-setting type');

			Assert.isTrue(UTIL_AsyncChain.isChainProcessingEnabled(),
					'An org that never wrote the runtime switch must resolve chains enabled: strategy no-match falls back to the shipped ResultOnNoMatch');
		}
	}

	/**
	 * @description suspendChainProcessing writes the ORG-default switch row, so the suspension is
	 * org-wide: both the suspending user and an unrelated second user resolve chains disabled
	 * through the hierarchy strategy. The second-user assert is the org-wide witness — a
	 * user-level write would suspend only its author and must fail here.
	 */
	@IsTest
	private static void shouldSuspendChainProcessingViaOrgDefaultSetting()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.suspendChainProcessing();
			Assert.isFalse(UTIL_AsyncChain.isChainProcessingEnabled(), 'The suspending user must resolve chains disabled');
		}
		System.runAs(getLowPrivilegeUser())
		{
			Assert.isFalse(UTIL_AsyncChain.isChainProcessingEnabled(),
					'A second user must resolve chains disabled: the suspension rides the org default, never a per-user row');
		}
	}

	/**
	 * @description resumeChainProcessing rewrites the same org-default row back to enabled, so a
	 * suspend-then-resume round trip ends with chains enabled again for every user.
	 */
	@IsTest
	private static void shouldResumeChainProcessingViaOrgDefaultSetting()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.suspendChainProcessing();
			UTIL_AsyncChain.resumeChainProcessing();
			Assert.isTrue(UTIL_AsyncChain.isChainProcessingEnabled(), 'Resume must re-enable chains through the same org-default row');
		}
		System.runAs(getLowPrivilegeUser())
		{
			Assert.isTrue(UTIL_AsyncChain.isChainProcessingEnabled(), 'Resume must reach every user, exactly as the suspension did');
		}
	}

	/**
	 * @description End-to-end: a chain started while chains are enabled is aborted at its next
	 * executor entry once processing is suspended mid-flight — the executor consult re-reads the
	 * runtime switch fresh in its own evaluation, so a suspension lands without waiting for new
	 * chains. Runs against the REAL flag and strategy records (no flag mock). The chain-record
	 * DML and the hierarchy-setting DML coexist in this one test transaction ONLY because
	 * System.runAs waives the mixed-DML restriction in tests — the exempt place, not a safe
	 * pattern: no production path may combine the two kinds (the setting-DML isolation
	 * precedent), which is why suspendChainProcessing performs the setting write and no other
	 * DML.
	 */
	@IsTest
	private static void shouldAbortRunningChainAtBoundaryWhenSuspended()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.TrackingStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			UTIL_AsyncChain.suspendChainProcessing();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, execution.Status__c, 'The executor entry consult must abort the chain under suspension');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_KILL_SWITCH, execution.FailureCategory__c, 'A suspension abort is a kill-switch abort');
			Map<String, Object> contextData = parseContextData(execution);
			Assert.isNull(contextData.get('trackingStepExecuted'), 'The step must not run under suspension');
		}
	}

	/**
	 * @description The operator abort writer stamps the full terminal bookkeeping — Aborted status,
	 * OperatorAbort category, abbreviated reason, completion timestamp, duration, and the
	 * deduplication-key release (I2) — and emits exactly one WARN signal at its own site (I1, D12).
	 */
	@IsTest
	private static void shouldAbortRunningChainWithFullBookkeeping()
	{
		System.runAs(getTestAdmin())
		{
			LOG_Builder.ignoreTestMode = true;
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME,
					new Map<SObjectField, Object>
					{
							AsyncChainExecution__c.StartedAt__c => Datetime.now().addMinutes(-5),
							AsyncChainExecution__c.ActiveDeduplicationKey__c => 'abort-writer-key'
					});

			Test.startTest();
			Boolean aborted = UTIL_AsyncChain.abortExecution(execution.Id, 'Stuck on external system');
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.isTrue(aborted, 'A Running chain is abortable');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, result.Status__c, 'Status must be Aborted');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_OPERATOR_ABORT, result.FailureCategory__c, 'An operator abort is not the kill switch');
			Assert.isTrue(result.ErrorMessage__c.contains('Stuck on external system'), 'The reason must be recorded');
			Assert.isNotNull(result.CompletedAt__c, 'An abort is terminal: the completion timestamp must be set');
			Assert.isNotNull(result.DurationMs__c, 'Duration must be computed from StartedAt');
			Assert.isNull(result.ActiveDeduplicationKey__c, 'I2: the deduplication key is released in the same update');
			Assert.areEqual(1, countTerminalLogs(execution.Id, 'abortExecution', 'WARN'), 'Exactly one WARN signal at the abort writer\'s own site');
		}
	}

	/**
	 * @description The writer refuses anything not in {Running, Stalled}: a Completed row is left
	 * byte-untouched and nothing is emitted (a refusal is not a terminal fact).
	 */
	@IsTest
	private static void shouldRefuseAbortOfTerminalChain()
	{
		System.runAs(getTestAdmin())
		{
			LOG_Builder.ignoreTestMode = true;
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN_NAME);

			Test.startTest();
			Boolean aborted = UTIL_AsyncChain.abortExecution(execution.Id, 'Too late');
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.isFalse(aborted, 'A Completed chain is not abortable');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'A refused abort must not touch the row');
			Assert.areEqual(0, countTerminalLogs(execution.Id, 'abortExecution', null), 'A refused abort emits nothing');
		}
	}

	/**
	 * @description An operator abort acts on a Stalled chain exactly as on a Running one: a chain
	 * parked awaiting recovery is precisely the kind an operator may need to put down (D11).
	 */
	@IsTest
	private static void shouldAbortStalledChain()
	{
		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME);

			Test.startTest();
			Boolean aborted = UTIL_AsyncChain.abortExecution(execution.Id, 'Stalled beyond recovery');
			Test.stopTest();

			Assert.isTrue(aborted, 'A Stalled chain is abortable');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, queryExecution(execution.Id).Status__c, 'Status must be Aborted');
		}
	}

	/**
	 * @description The writer reports a missing row to the caller as a refusal instead of throwing.
	 */
	@IsTest
	private static void shouldRefuseAbortOfMissingRow()
	{
		System.runAs(getTestAdmin())
		{
			Assert.isFalse(UTIL_AsyncChain.abortExecution(UTIL_Random.randomId(AsyncChainExecution__c.SObjectType), 'gone'), 'A missing row is not abortable');
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
	 * @description withDeduplicationKey stamps the key on the run record at start.
	 */
	@IsTest
	private static void shouldStampDeduplicationKeyAtStart()
	{
		setupEnabledFeatureFlag();
		System.runAs(getTestAdmin())
		{
			String deduplicationKey = UTIL_Random.randomUUID();
			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			AsyncChainExecution__c runningExecution = queryExecution(executionId);
			Test.stopTest();

			Assert.areEqual(deduplicationKey, runningExecution.ActiveDeduplicationKey__c,
					'The deduplication key should be stamped on the run record at start');
		}
	}

	/**
	 * @description A deduplication key at exactly the 255-character field limit is accepted at
	 * build time and stamped intact on the run record.
	 */
	@IsTest
	private static void shouldAcceptDeduplicationKeyAtMaximumLength()
	{
		setupEnabledFeatureFlag();
		System.runAs(getTestAdmin())
		{
			String boundaryKey = 'k'.repeat(255);
			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(boundaryKey)
					.execute();
			AsyncChainExecution__c runningExecution = queryExecution(executionId);
			Test.stopTest();

			Assert.areEqual(boundaryKey, runningExecution.ActiveDeduplicationKey__c, 'A boundary-length deduplication key should be stamped intact on the run record');
		}
	}

	/**
	 * @description A blank deduplication key is rejected at build time.
	 */
	@IsTest
	private static void shouldRejectBlankDeduplicationKey()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).withDeduplicationKey(' ');
				Assert.fail('A blank deduplication key should be rejected');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class,
						'A blank deduplication key should be rejected at build time: ' + error.getMessage());
				Assert.isTrue(error.getMessage().contains('must not be blank'),
						'The blank-key rejection should carry its build-time message: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description A deduplication key longer than the field is rejected at build time; the validation
	 * ceiling matches the deployed field length (raw describe as the independent oracle).
	 */
	@IsTest
	private static void shouldRejectOversizedDeduplicationKey()
	{
		System.runAs(getTestAdmin())
		{
			Assert.areEqual(255, AsyncChainExecution__c.ActiveDeduplicationKey__c.getDescribe().getLength(),
					'Validation ceiling must match the deployed field length');
			try
			{
				UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).withDeduplicationKey('k'.repeat(256));
				Assert.fail('An oversized deduplication key should be rejected');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class,
						'An oversized deduplication key should be rejected at build time: ' + error.getMessage());
				Assert.isTrue(error.getMessage().contains('exceeds 255 characters'),
						'The oversized-key rejection should carry the limit in its message: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Zero-step chains complete immediately and never stamp the key (D2).
	 */
	@IsTest
	private static void shouldSkipDeduplicationKeyOnZeroStepChain()
	{
		setupEnabledFeatureFlag();
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withDeduplicationKey(UTIL_Random.randomUUID())
					.execute();
			Test.stopTest();

			AsyncChainExecution__c completedExecution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, completedExecution.Status__c,
					'A zero-step chain should complete immediately');
			Assert.isNull(completedExecution.ActiveDeduplicationKey__c,
					'A zero-step chain should never hold a deduplication key');
		}
	}

	/**
	 * @description A second concurrent start with the same key lands on the active run.
	 */
	@IsTest
	private static void shouldLandSecondStartOnActiveRun()
	{
		setupEnabledFeatureFlag();
		System.runAs(getTestAdmin())
		{
			String deduplicationKey = UTIL_Random.randomUUID();
			Test.startTest();
			String firstRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			String secondRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			Test.stopTest();

			Assert.areEqual(firstRunId, secondRunId,
					'A second start with the same key should land on the active run');
		}
	}

	/**
	 * @description The unique text index is case-insensitive — a case-variant key collides and
	 * lands on the active run.
	 */
	@IsTest
	private static void shouldCollideCaseInsensitively()
	{
		setupEnabledFeatureFlag();
		System.runAs(getTestAdmin())
		{
			String deduplicationKey = 'dedup-' + UTIL_Random.randomUUID();
			Test.startTest();
			String firstRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(deduplicationKey.toLowerCase())
					.execute();
			String secondRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(deduplicationKey.toUpperCase())
					.execute();
			Test.stopTest();

			Assert.areEqual(firstRunId, secondRunId,
					'Keys differing only in case should collide on the case-insensitive index');
		}
	}

	/**
	 * @description A launch that declares a deduplication key AND reuses an attached correlation is
	 * refused with the correlation rule, whichever message form the platform gives it. Where the
	 * colliding field is named, the first failure is attributed straight away; where it is redacted,
	 * the launch presumes the deduplication index, finds no run holding its own free key, retries
	 * once, and the second failure clears the deduplication index a second time, leaving the
	 * correlation as the only index left to have collided. One outcome either way, so a keyed launch
	 * never hands a subscriber a raw duplicate-value error to decode.
	 */
	@IsTest
	private static void shouldRefuseAKeyedLaunchWhoseCorrelationIsAlreadyAttached()
	{
		setupEnabledFeatureFlag();
		System.runAs(getTestAdmin())
		{
			String correlationId = UTIL_Random.randomUUID();
			Test.startTest();
			UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.execute(correlationId);
			try
			{
				UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
						.then(new SuccessStep())
						.withDeduplicationKey(UTIL_Random.randomUUID())
						.execute(correlationId);
				Assert.fail('A keyed launch reusing an attached correlation must be refused, never landed on an unrelated run');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, UTIL_Exceptions.IllegalStateException.class,
						'A keyed launch must be refused with the correlation rule, not a raw platform error: ' + error.getMessage());
				Assert.isTrue(error.getMessage().contains(correlationId),
						'The refusal must name the correlation that is already attached: ' + error.getMessage());
				Assert.isTrue(error.getMessage().contains(CORRELATION_REMEDY_FRAGMENT),
						'The refusal must spell out the remedy: ' + error.getMessage());
			}
			Test.stopTest();
		}
	}

	/**
	 * @description A cross-user collision returns the active run's Id without widening visibility —
	 * status reads stay sharing-enforced (the shouldNotLeakOtherUsersChainViaGetChainStatus model,
	 * composed with the deduplication path).
	 */
	@IsTest
	private static void shouldNotWidenVisibilityOnCrossUserCollision()
	{
		setupEnabledFeatureFlag();
		String deduplicationKey = UTIL_Random.randomUUID();
		String firstRunId;
		Test.startTest();
		System.runAs(getTestAdmin())
		{
			firstRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
		}
		System.runAs(getLowPrivilegeUser())
		{
			String secondRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();

			Assert.areEqual(firstRunId, secondRunId,
					'The collision should land on the active run regardless of the caller');
			Assert.isNull(UTIL_AsyncChain.getChainStatus(secondRunId),
					'The returned Id must not widen visibility — status reads stay sharing-enforced');
		}
		Test.stopTest();
	}

	/**
	 * @description Completion releases the key in the terminal write; a sequential re-run is allowed.
	 */
	@IsTest
	private static void shouldReleaseDeduplicationKeyOnCompletion()
	{
		setupEnabledFeatureFlag();
		System.runAs(getTestAdmin())
		{
			String deduplicationKey = UTIL_Random.randomUUID();
			Test.startTest();
			String firstRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			Test.stopTest();

			AsyncChainExecution__c completedRun = queryExecution(firstRunId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, completedRun.Status__c,
					'The chain should have completed');
			Assert.isNull(completedRun.ActiveDeduplicationKey__c,
					'The terminal write should release the deduplication key');

			String secondRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			Assert.areNotEqual(firstRunId, secondRunId,
					'A finished run should free its key for a sequential re-run');
		}
	}

	/**
	 * @description A step failure releases the key in the terminal write; a sequential re-run is allowed.
	 */
	@IsTest
	private static void shouldReleaseDeduplicationKeyOnStepFailure()
	{
		setupEnabledFeatureFlag();
		System.runAs(getTestAdmin())
		{
			String deduplicationKey = UTIL_Random.randomUUID();
			Test.startTest();
			String firstRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new FailingStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			Test.stopTest();

			AsyncChainExecution__c failedRun = queryExecution(firstRunId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, failedRun.Status__c,
					'The chain should have failed');
			Assert.isNull(failedRun.ActiveDeduplicationKey__c,
					'The terminal failure write should release the deduplication key');

			String secondRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			Assert.areNotEqual(firstRunId, secondRunId,
					'A failed run should free its key for a sequential re-run');
		}
	}

	/**
	 * @description An asynchronous context overflow releases the key in its terminal failure write;
	 * a sequential re-run is allowed.
	 */
	@IsTest
	private static void shouldReleaseDeduplicationKeyOnContextOverflow()
	{
		setupEnabledFeatureFlag();
		System.runAs(getTestAdmin())
		{
			String deduplicationKey = UTIL_Random.randomUUID();
			Test.startTest();
			String firstRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withMaxContextSize(1)
					.withInitialContext('key', 'value')
					.then(new SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c failedRun = queryExecution(firstRunId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, failedRun.Status__c,
					'The chain should have failed on context overflow');
			Assert.isNull(failedRun.ActiveDeduplicationKey__c,
					'The overflow failure write should release the deduplication key');

			String secondRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			Assert.areNotEqual(firstRunId, secondRunId,
					'An overflow-failed run should free its key for a sequential re-run');
		}
	}

	/**
	 * @description A kill-switch abort releases the key in its terminal write; a sequential re-run
	 * is allowed.
	 */
	@IsTest
	private static void shouldReleaseDeduplicationKeyOnKillSwitchAbort()
	{
		setupDisabledFeatureFlag();
		System.runAs(getTestAdmin())
		{
			String deduplicationKey = UTIL_Random.randomUUID();
			Test.startTest();
			String firstRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new TrackingStep())
					.withDeduplicationKey(deduplicationKey)
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c abortedRun = queryExecution(firstRunId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, abortedRun.Status__c,
					'The chain should have aborted under the kill switch');
			Assert.isNull(abortedRun.ActiveDeduplicationKey__c,
					'The terminal abort write should release the deduplication key');

			String secondRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new TrackingStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			Assert.areNotEqual(firstRunId, secondRunId,
					'An aborted run should free its key for a sequential re-run');
		}
	}

	/**
	 * @description A completed chain with a completion handler releases the key through the
	 * handler write-back path; a sequential re-run is allowed.
	 */
	@IsTest
	private static void shouldReleaseDeduplicationKeyOnCompletionHandlerWriteBack()
	{
		setupEnabledFeatureFlag();
		System.runAs(getTestAdmin())
		{
			String deduplicationKey = UTIL_Random.randomUUID();
			Test.startTest();
			String firstRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.onComplete(new CompletionHandlerStep())
					.withDeduplicationKey(deduplicationKey)
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c completedRun = queryExecution(firstRunId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, completedRun.Status__c,
					'The chain should have completed through the handler write-back');
			Assert.isNull(completedRun.ActiveDeduplicationKey__c,
					'The handler write-back should leave the deduplication key released');

			String secondRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			Assert.areNotEqual(firstRunId, secondRunId,
					'A completed run should free its key for a sequential re-run');
		}
	}

	/**
	 * @description A failing completion handler escalates the chain to Failed through the handler
	 * write-back; the escalation leaves the key released and a sequential re-run is allowed.
	 */
	@IsTest
	private static void shouldReleaseDeduplicationKeyOnCompletionHandlerFailureEscalation()
	{
		setupEnabledFeatureFlag();
		System.runAs(getTestAdmin())
		{
			String deduplicationKey = UTIL_Random.randomUUID();
			Test.startTest();
			String firstRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.onComplete(new FailingCompletionHandlerStep())
					.withDeduplicationKey(deduplicationKey)
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c escalatedRun = queryExecution(firstRunId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, escalatedRun.Status__c,
					'A failing completion handler should escalate the chain to Failed');
			Assert.isNull(escalatedRun.ActiveDeduplicationKey__c,
					'The escalation write-back should leave the deduplication key released');

			String secondRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			Assert.areNotEqual(firstRunId, secondRunId,
					'An escalated-failed run should free its key for a sequential re-run');
		}
	}

	/**
	 * @description An executor crash releases the key in the Finalizer's terminal failure write;
	 * a sequential re-run is allowed.
	 */
	@IsTest
	private static void shouldReleaseDeduplicationKeyOnExecutorCrash()
	{
		setupEnabledFeatureFlag();
		System.runAs(getTestAdmin())
		{
			String deduplicationKey = UTIL_Random.randomUUID();
			UTIL_AsyncChain.simulateCrash = true;

			Test.startTest();
			String firstRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(deduplicationKey)
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

			AsyncChainExecution__c failedRun = queryExecution(firstRunId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, failedRun.Status__c,
					'The Finalizer should mark the crashed chain Failed');
			Assert.isNull(failedRun.ActiveDeduplicationKey__c,
					'The Finalizer failure write should release the deduplication key');

			String secondRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			Assert.areNotEqual(firstRunId, secondRunId,
					'A crashed run should free its key for a sequential re-run');
		}
	}

	/**
	 * @description Two key-less starts in the same window run concurrently — null keys never
	 * collide on the deduplication index (the legacy/straddle pin).
	 */
	@IsTest
	private static void shouldRunConcurrentChainsWithoutDeduplicationKeys()
	{
		setupEnabledFeatureFlag();
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			String firstRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.execute();
			String secondRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.execute();
			Test.stopTest();

			Assert.areNotEqual(firstRunId, secondRunId,
					'Key-less chains must never collide — a null key is exempt from deduplication');
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

			AsyncChainExecution__c abortRecord = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.Id, (Id)executionId)
					.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_ABORTED)
					.withOptionalField(AsyncChainExecution__c.ChainName__c)
					.withoutInsertion()
					.build();
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
	 * @description Verifies that an asynchronous context overflow stamps the StepException
	 * failure category alongside the terminal Failed status.
	 */
	@IsTest
	private static void shouldCategoriseContextOverflowAsStepException()
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
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, execution.FailureCategory__c, 'A context overflow must be categorised StepException');
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
	 * @description A service that starts a log correlation and then launches TWO chains keeps both:
	 * the first launch adopts the transaction's correlation, the second records its own rather than
	 * colliding on the unique CorrelationId__c index.
	 */
	@IsTest
	private static void shouldMintItsOwnCorrelationForASecondChainInOneCorrelatedTransaction()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			String transactionCorrelationId = LOG_Builder.startCorrelation();

			Test.startTest();
			String firstExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute();
			String secondExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute();
			Test.stopTest();

			Assert.areEqual(transactionCorrelationId, queryExecution(firstExecutionId).CorrelationId__c,
					'The first chain in a correlated transaction must adopt the active correlation');
			String secondCorrelationId = queryExecution(secondExecutionId).CorrelationId__c;
			Assert.isTrue(String.isNotBlank(secondCorrelationId), 'The second chain must still carry a correlation of its own');
			Assert.areNotEqual(transactionCorrelationId, secondCorrelationId,
					'The second chain must mint its own correlation instead of colliding on the unique index');
		}
	}

	/**
	 * @description The minted correlation is announced exactly once, filed under the TRANSACTION
	 * correlation and pointing at the chain it started — so a reader who only knows the correlation
	 * their service started can still find the second chain.
	 */
	@IsTest
	private static void shouldAnnounceTheMintedCorrelationUnderTheTransactionCorrelation()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			String transactionCorrelationId = LOG_Builder.startCorrelation();

			Test.startTest();
			UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute();
			String secondExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			String secondCorrelationId = queryExecution(secondExecutionId).CorrelationId__c;
			List<LogEntry__c> announcements = findLogEntriesAt(secondExecutionId, MINTED_CORRELATION_SITE);
			Assert.areEqual(1, announcements.size(), 'A minted correlation must be announced exactly once');
			Assert.areEqual('INFO', announcements[0].LogLevel__c, 'The announcement reports a routine launch, not a problem');
			Assert.areEqual(transactionCorrelationId, announcements[0].CorrelationId__c,
					'The announcement must be filed under the transaction correlation the caller knows about');
			Assert.isTrue(announcements[0].ShortMessage__c.contains(secondCorrelationId),
					'The announcement must name the correlation the second chain is recorded under');
			Assert.isTrue(announcements[0].ShortMessage__c.contains(transactionCorrelationId),
					'The announcement must name the transaction correlation it stepped aside from');

			List<LogEntry__c> secondChainCompletion = findLogEntriesAt(secondExecutionId, 'handleChainCompletion');
			Assert.areEqual(1, secondChainCompletion.size(), 'The second chain should complete and log it');
			Assert.areEqual(transactionCorrelationId, secondChainCompletion[0].CorrelationId__c,
					'The second chain\'s own entries stay under the transaction correlation, so one search still returns the whole action');
		}
	}

	/**
	 * @description Control for the first-adopter rule: a transaction that launches ONE chain still
	 * adopts the active correlation silently, with nothing announced.
	 */
	@IsTest
	private static void shouldAdoptTheActiveCorrelationSilentlyForTheOnlyChainInATransaction()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			String transactionCorrelationId = LOG_Builder.startCorrelation();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.areEqual(transactionCorrelationId, queryExecution(executionId).CorrelationId__c,
					'A lone chain must keep inheriting the active correlation');
			Assert.areEqual(0, findLogEntriesAt(executionId, MINTED_CORRELATION_SITE).size(),
					'A chain that adopted the active correlation has nothing to announce');
		}
	}

	/**
	 * @description A second launch that carries the same deduplication key lands on the running chain
	 * instead of starting one, so there is no new correlation and nothing to announce — the
	 * announcement must never claim a chain that was never started.
	 */
	@IsTest
	private static void shouldAnnounceNothingWhenTheSecondLaunchLandsOnTheRunningChain()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			LOG_Builder.startCorrelation();

			Test.startTest();
			String firstExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(SHARED_DEDUPLICATION_KEY)
					.execute();
			String secondExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.withDeduplicationKey(SHARED_DEDUPLICATION_KEY)
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.areEqual(firstExecutionId, secondExecutionId, 'The second launch must land on the chain already holding the key');
			Assert.areEqual(0, findLogEntriesAt(firstExecutionId, MINTED_CORRELATION_SITE).size(),
					'A launch that started no chain must announce no correlation');
		}
	}

	/**
	 * @description Reusing one correlation for two chains in the same transaction is refused with a
	 * message naming the correlation, the run already holding it, and the remedy — not a raw
	 * duplicate-value database error. Also pins that a correlation collision is never mistaken for
	 * deduplication: the second launch is refused, never quietly landed on the first run.
	 */
	@IsTest
	private static void shouldNameTheHolderWhenACorrelationIsReusedInTheSameTransaction()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			String sharedCorrelationId = UTIL_Random.randomUUID();

			Test.startTest();
			String firstExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute(sharedCorrelationId);
			try
			{
				UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute(sharedCorrelationId);
				Assert.fail('A second chain on an already-attached correlation must be refused');
			}
			catch(UTIL_Exceptions.IllegalStateException refusal)
			{
				Assert.isTrue(refusal.getMessage().contains(sharedCorrelationId), 'The refusal must name the correlation: ' + refusal.getMessage());
				Assert.isTrue(refusal.getMessage().contains(firstExecutionId),
						'The refusal must name the run already holding it: ' + refusal.getMessage());
				Assert.isTrue(refusal.getMessage().contains(CORRELATION_REMEDY_FRAGMENT),
						'The refusal must spell out the remedy: ' + refusal.getMessage());
			}
			Test.stopTest();
		}
	}

	/**
	 * @description A correlation propagated from an EARLIER transaction is held by a run this
	 * transaction never launched, so the refusal cannot name it — it still states the rule and the
	 * remedy rather than surfacing a database error.
	 */
	@IsTest
	private static void shouldStateTheRuleWhenACorrelationIsHeldByAnEarlierTransaction()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			String propagatedCorrelationId = UTIL_Random.randomUUID();
			TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.CorrelationId__c => propagatedCorrelationId
			});

			Test.startTest();
			try
			{
				UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute(propagatedCorrelationId);
				Assert.fail('A chain reusing a correlation attached elsewhere must be refused');
			}
			catch(UTIL_Exceptions.IllegalStateException refusal)
			{
				Assert.isTrue(refusal.getMessage().contains(propagatedCorrelationId), 'The refusal must name the correlation: ' + refusal.getMessage());
				Assert.isTrue(refusal.getMessage().contains(UNNAMED_HOLDER_FRAGMENT),
						'The refusal must say another run holds it, without a query to name which: ' + refusal.getMessage());
				Assert.isTrue(refusal.getMessage().contains(CORRELATION_REMEDY_FRAGMENT),
						'The refusal must spell out the remedy: ' + refusal.getMessage());
			}
			Test.stopTest();
		}
	}

	/**
	 * @description A stepless chain launches through its own insert, so it gets the same refusal as a
	 * chain with steps when its correlation is already attached.
	 */
	@IsTest
	private static void shouldRefuseASteplessChainOnAnAlreadyAttachedCorrelation()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			String propagatedCorrelationId = UTIL_Random.randomUUID();
			TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.CorrelationId__c => propagatedCorrelationId
			});

			Test.startTest();
			try
			{
				UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).execute(propagatedCorrelationId);
				Assert.fail('A stepless chain on an already-attached correlation must be refused');
			}
			catch(UTIL_Exceptions.IllegalStateException refusal)
			{
				Assert.isTrue(refusal.getMessage().contains(propagatedCorrelationId), 'The refusal must name the correlation: ' + refusal.getMessage());
				Assert.isTrue(refusal.getMessage().contains(CORRELATION_REMEDY_FRAGMENT),
						'The refusal must spell out the remedy: ' + refusal.getMessage());
			}
			Test.stopTest();
		}
	}

	/**
	 * @description A launch that fails for any reason OTHER than a duplicate correlation must reach
	 * the caller as the platform reported it: mislabelling an unrelated write failure as a
	 * correlation collision would send a subscriber hunting the wrong problem. Oversizing the
	 * correlation is the cheapest real path to a non-duplicate insert failure.
	 */
	@IsTest
	private static void shouldSurfaceANonDuplicateLaunchFailureAsThePlatformReportedIt()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Integer correlationCapacity = AsyncChainExecution__c.CorrelationId__c.getDescribe().getLength();
			String oversizedCorrelationId = 'x'.repeat(correlationCapacity + 1);

			Test.startTest();
			try
			{
				UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute(oversizedCorrelationId);
				Assert.fail('A correlation the field cannot hold must fail the launch');
			}
			catch(UTIL_Exceptions.IllegalStateException misattributed)
			{
				Assert.fail('A non-duplicate write failure must not be reported as a correlation collision: ' + misattributed.getMessage());
			}
			catch(DmlException platformFailure)
			{
				Assert.areNotEqual(StatusCode.DUPLICATE_VALUE, platformFailure.getDmlType(0),
						'The platform failure must reach the caller unchanged: ' + platformFailure.getMessage());
			}
			Test.stopTest();
		}
	}

	/**
	 * @description A completed chain emits exactly one guarded INFO terminal signal naming
	 * handleChainCompletion.
	 */
	@IsTest
	private static void shouldEmitTerminalLogOnCompletion()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, queryExecution(executionId).Status__c,
					'The chain should complete');
			Assert.areEqual(1, countTerminalLogs(executionId, 'handleChainCompletion', 'INFO'),
					'Completion should emit exactly one INFO terminal signal naming its site');
		}
	}

	/**
	 * @description A chain failed by a step's failed StepResult emits exactly one guarded ERROR
	 * terminal signal naming handleStepFailure.
	 */
	@IsTest
	private static void shouldEmitTerminalLogOnStepFailure()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.FailingStep())
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(executionId).Status__c,
					'The chain should fail');
			Assert.areEqual(1, countTerminalLogs(executionId, 'handleStepFailure', 'ERROR'),
					'Step failure should emit exactly one ERROR terminal signal naming its site');
		}
	}

	/**
	 * @description A chain failed by context overflow emits exactly one guarded ERROR terminal
	 * signal naming markFailed.
	 */
	@IsTest
	private static void shouldEmitTerminalLogOnContextOverflow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withMaxContextSize(1)
					.withInitialContext('key', 'value')
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(executionId).Status__c,
					'The chain should fail on context overflow');
			Assert.areEqual(1, countTerminalLogs(executionId, 'markFailed', 'ERROR'),
					'Context overflow should emit exactly one ERROR terminal signal naming its site');
		}
	}

	/**
	 * @description A zero-step chain, which completes synchronously inside ChainBuilder.execute,
	 * emits exactly one guarded INFO terminal signal naming that site.
	 */
	@IsTest
	private static void shouldEmitTerminalLogOnZeroStepCompletion()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).execute();
			Test.getEventBus().deliver();

			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, queryExecution(executionId).Status__c,
					'The zero-step chain should complete immediately');
			Assert.areEqual(1, countTerminalLogs(executionId, 'ChainBuilder.execute', 'INFO'),
					'Zero-step completion should emit exactly one INFO terminal signal naming its site');
		}
	}

	/**
	 * @description With the log threshold configured above INFO, a completed chain emits no
	 * completion signal of any level while the chain itself completes untouched — the INFO
	 * signal honours the configured threshold.
	 */
	@IsTest
	private static void shouldSuppressCompletionSignalBelowThreshold()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Engine.logSettingOverride = new LogSetting__c(
					IsEnabled__c = true,
					LogLevelThreshold__c = 'WARN',
					EnablePerformanceLogging__c = false);
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, queryExecution(executionId).Status__c,
					'The chain should complete regardless of the log threshold');
			Assert.areEqual(0, countTerminalLogs(executionId, 'handleChainCompletion', null),
					'No completion signal of any level should be persisted below the configured threshold');
		}
	}

	/**
	 * @description With the log threshold configured at ERROR, a failed chain still emits its
	 * ERROR terminal signal — the failure half of the level contract passes the threshold.
	 */
	@IsTest
	private static void shouldEmitFailureSignalAboveThreshold()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Engine.logSettingOverride = new LogSetting__c(
					IsEnabled__c = true,
					LogLevelThreshold__c = 'ERROR',
					EnablePerformanceLogging__c = false);
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.FailingStep())
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(executionId).Status__c,
					'The chain should fail');
			Assert.areEqual(1, countTerminalLogs(executionId, 'handleStepFailure', 'ERROR'),
					'The ERROR failure signal should pass an ERROR-level threshold');
		}
	}

	/**
	 * @description A chain that completes through a successful completion handler emits exactly one
	 * guarded INFO terminal signal at handleChainCompletion and nothing from the handler write-back:
	 * the successful write-back is silent by design, keeping the completion signal single.
	 */
	@IsTest
	private static void shouldEmitSingleTerminalLogWithCompletionHandler()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = executeWithCompletionHandler();
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, queryExecution(executionId).Status__c,
					'The chain should complete through its completion handler');
			Assert.areEqual(1, countTerminalLogs(executionId, 'handleChainCompletion', 'INFO'),
					'Completion with a handler should emit exactly one INFO terminal signal at handleChainCompletion');
			Assert.areEqual(0, countTerminalLogs(executionId, 'HandlerExecutor.execute', null),
					'The successful handler write-back should emit no terminal signal of any level');
		}
	}

	/**
	 * @description A chain whose completion handler returns a failed StepResult is escalated to
	 * Failed and emits exactly one guarded ERROR terminal signal at HandlerExecutor.execute,
	 * strictly after the escalation write-back.
	 */
	@IsTest
	private static void shouldEmitTerminalLogOnCompletionHandlerFailure()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.onComplete(new UTIL_AsyncChain_TEST.FailingCompletionHandlerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(executionId).Status__c,
					'The chain should be Failed by the handler escalation');
			Assert.areEqual(1, countTerminalLogs(executionId, 'HandlerExecutor.execute', 'ERROR'),
					'The handler escalation should emit exactly one ERROR terminal signal naming its site');
		}
	}

	/**
	 * @description A crashed completion handler is escalated to Failed by the Finalizer, which
	 * emits exactly one guarded ERROR terminal signal at HandlerExecutor.Finalizer strictly after
	 * its recovery write-back.
	 */
	@IsTest
	private static void shouldEmitTerminalLogOnHandlerCrash()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

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
			Test.getEventBus().deliver();

			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(executionId).Status__c,
					'The handler crash should mark the chain as Failed');
			Assert.areEqual(1, countTerminalLogs(executionId, 'HandlerExecutor.Finalizer', 'ERROR'),
					'The handler-crash escalation should emit exactly one ERROR terminal signal naming its site');
		}
	}

	/**
	 * @description When the chain's own work exhausts the DML budget, the terminal write still
	 * commits — the signal's fate under exhaustion is the logging engine's concern (see
	 * LOG_Engine.canPublishImmediately).
	 */
	@IsTest
	private static void shouldCompleteChainWhenDmlBudgetExhausted()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Engine.logSettingOverride = new LogSetting__c(
					IsEnabled__c = true,
					LogLevelThreshold__c = 'DEBUG',
					EnablePerformanceLogging__c = false);
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new DmlBudgetBurnerStep())
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, queryExecution(executionId).Status__c,
					'The terminal write must commit even with the signal budget exhausted');
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
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, execution.FailureCategory__c,
					'A completion-handler crash escalation must be categorised StepException');
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
	 * @description Verifies that a Queueable crash handled by the Finalizer stamps the
	 * StepException failure category alongside the terminal Failed status.
	 */
	@IsTest
	private static void shouldCategoriseCrashAsStepException()
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
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, execution.FailureCategory__c, 'A Queueable crash must be categorised StepException');
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
			System.enqueueJob(new UTIL_AsyncChain.ChainExecutor(execution.Id, 0, 50, 32768, null, null, options, null), options);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'Chain should fail for missing class');
			String resolverCause = String.format(UTIL_System.ERROR_TYPE_NOT_FOUND, new List<String> {'NonExistentClass'});
			String expectedMessage = String.format(UTIL_AsyncChain.STEP_NOT_CREATABLE_MESSAGE, new List<String> {'NonExistentClass', resolverCause});
			Assert.areEqual(expectedMessage, result.ErrorMessage__c, 'Error should name the step, state the constructor rule, and carry the resolver cause');
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
			System.enqueueJob(new UTIL_AsyncChain.ChainExecutor(executionId, 0, 50, 32768, null, null, options, null), options);
			Test.stopTest();

			Boolean existsAfter = QRY_Builder.selectFrom(AsyncChainExecution__c.SObjectType)
					.condition(AsyncChainExecution__c.Id).equals(executionId)
					.exists();
			Assert.isFalse(existsAfter, 'Executor should exit without recreating the deleted execution record');
		}
	}

	/**
	 * @description The builder must persist each step's idempotency declaration into the step log at
	 * build time: true for a step whose author declared isIdempotent, and null for an undeclared step
	 * — absent from the JSON with false semantics, so healthy step logs stay byte-identical.
	 */
	@IsTest
	private static void shouldPersistIdempotentDeclarationIntoStepLog()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.IdempotentSuccessStep())
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			List<UTIL_AsyncChain.DTO_StepDefinition> entries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.areEqual(true, entries[0].isIdempotent, 'Declared step must persist the marker');
			Assert.isNull(entries[1].isIdempotent, 'Undeclared step must stay null-suppressed (absent in JSON, false semantics)');
		}
	}

	/**
	 * @description An isIdempotent() override that answers null must read as undeclared: the builder
	 * persists no marker, so the retry gate keeps the step closed exactly as for a step that never
	 * overrode the declaration.
	 */
	@IsTest
	private static void shouldTreatNullIdempotencyDeclarationAsUndeclared()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.NullDeclaringStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'A null declaration must not disturb the run');
			List<UTIL_AsyncChain.DTO_StepDefinition> entries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.isNull(entries[0].isIdempotent, 'A null declaration must persist no marker');
		}
	}

	/**
	 * @description A chain built with allowRestart() must stamp the declaration on the run record at
	 * insert and capture the as-built initial context beside it — the snapshot a restart replays,
	 * never the evolved context the running steps write afterwards.
	 */
	@IsTest
	private static void shouldStampRestartDeclarationAndInitialContextAtInsert()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withInitialContext(RESTART_SEED_KEY, RESTART_SEED_VALUE)
					.allowRestart()
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c row = queryRestartProjection(executionId);
			Assert.areEqual(true, row.AllowRestart__c, 'allowRestart must stamp the record');
			Assert.isTrue(String.isNotBlank(row.InitialContextData__c), 'Initial context snapshot must persist for restart-declared chains');
			Assert.isTrue(row.InitialContextData__c.contains(RESTART_SEED_VALUE), 'Snapshot must be the as-built context');
			Assert.isFalse(row.InitialContextData__c.contains(EVOLVED_CONTEXT_KEY), 'Snapshot must never absorb keys the running steps wrote after the build');
			Assert.isTrue(row.ContextData__c.contains(EVOLVED_CONTEXT_KEY), 'Control: the evolved context does carry the step-written key the snapshot must lack');
		}
	}

	/**
	 * @description A chain built without allowRestart() must keep the default false declaration and
	 * store no initial-context snapshot — the second long-text copy is opt-in storage.
	 */
	@IsTest
	private static void shouldNotCaptureInitialContextWithoutRestartDeclaration()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withInitialContext(RESTART_SEED_KEY, RESTART_SEED_VALUE)
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c row = queryRestartProjection(executionId);
			Assert.areEqual(false, row.AllowRestart__c, 'Default stays false');
			Assert.isNull(row.InitialContextData__c, 'No snapshot for undeclared chains - storage is opt-in');
			Assert.isNull(row.DeclaredDeduplicationKey__c, 'An unkeyed chain must stamp no declared key');
		}
	}

	/**
	 * @description A step that returns failedPermanently must persist its declared-permanent marker
	 * into the failed entry of the terminal step log, so a later re-drive gate can read the finality
	 * verdict off the record instead of re-deriving it.
	 */
	@IsTest
	private static void shouldMarkTerminalPermanentFailureInStepLog()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.PermanentlyFailingStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'A declared-permanent failure must fail the chain');
			List<UTIL_AsyncChain.DTO_StepDefinition> entries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.areEqual(true, entries[0].permanentFailure, 'Declared-permanent terminal failure must persist its marker');
		}
	}

	/**
	 * @description A permanent failure on a continueOnError step must NOT persist the
	 * declared-permanent marker: the chain continues, so the failure is not terminal, and the marker
	 * rides only the terminal failure persist. Pins the stamp's position inside the terminal branch —
	 * hoisting it above the continueOnError check would silently mark continued failures.
	 */
	@IsTest
	private static void shouldNotMarkContinuedPermanentFailureInStepLog()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.PermanentlyFailingStep(), true)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'A continued permanent failure must not fail the chain');
			List<UTIL_AsyncChain.DTO_StepDefinition> entries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.areEqual(false, entries[0].success, 'Control: the continued step genuinely failed');
			Assert.isNull(entries[0].permanentFailure, 'A continued permanent failure must not carry the terminal marker');
		}
	}

	/**
	 * @description A chain built with withDeduplicationKey must keep the declared key on the record
	 * after the run ends — the active key releases at the terminal transition, the declared key stays
	 * so a re-drive can re-claim it.
	 */
	@IsTest
	private static void shouldPersistDeclaredDeduplicationKeyAtInsert()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.SuccessStep())
					.withDeduplicationKey(DECLARED_DEDUPLICATION_KEY)
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c row = queryRestartProjection(executionId);
			Assert.areEqual(DECLARED_DEDUPLICATION_KEY, row.DeclaredDeduplicationKey__c, 'The declared key must persist past the terminal transition');
			Assert.isNull(row.ActiveDeduplicationKey__c, 'Control: the active key must release at completion while the declared key stays');
		}
	}

	/**
	 * @description Round-trip size witness: a healthy chain of undeclared steps must persist an
	 * insert-time StepLog__c that is byte-identical to the pre-change shape — each entry carries
	 * exactly its className and nothing else, because the new declaration markers are null-suppressed
	 * and absent markers add zero bytes. Guards the upgrade-safety contract: step logs persisted
	 * before the markers existed and step logs written today serialize to the same document.
	 */
	@IsTest
	private static void shouldKeepHealthyStepLogInsertSizeUnchanged()
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
			AsyncChainExecution__c inserted = queryExecution(executionId);
			Test.stopTest();

			List<UTIL_AsyncChain.DTO_StepDefinition> entries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(inserted.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Integer expectedLength = 2 * (entries[0].className.length() + HEALTHY_STEP_ENTRY_JSON_OVERHEAD) + HEALTHY_STEP_LIST_JSON_OVERHEAD;
			Assert.areEqual(expectedLength, inserted.StepLog__c.length(), 'A healthy step log must stay byte-identical: null-suppressed markers add zero bytes per entry');
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
	 * @description Reads an AsyncChainExecution__c row through the production restart projection —
	 * the same selector method restartChainFromStart uses, so these witnesses prove the builder's
	 * persisted fields are reachable by the reader that will consume them, not merely present in
	 * the database.
	 *
	 * @param executionId The execution record ID.
	 *
	 * @return The execution record with the re-drive gating fields and the snapshot.
	 */
	private static AsyncChainExecution__c queryRestartProjection(String executionId)
	{
		return new SEL_AsyncChainExecution().findByIdForRestart(executionId);
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
	 * @description Builds and executes a seven-step success chain under the framework's default
	 * AsyncOptions: deliberately no withAsyncOptions call, so the depth in force is the one
	 * execute() derives (step count + 1) rather than a test-supplied override.
	 *
	 * @return The execution record ID.
	 */
	private static String executeSevenStepDefaultOptionsChain()
	{
		UTIL_AsyncChain.ChainBuilder builder = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME);
		for(Integer stepNumber = 0; stepNumber < DEEP_CHAIN_STEP_COUNT; stepNumber++)
		{
			builder.then(new UTIL_AsyncChain_TEST.SuccessStep());
		}
		return builder.execute();
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
	 * @description Counts persisted LogEntry__c rows whose RecordId__c names the given execution,
	 * whose ClassMethod__c ends with the given emitting-site suffix, and (when a level is given)
	 * whose LogLevel__c matches — so every terminal-signal test pins the D2 level contract, not
	 * just the site. The site suffix is deliberately part of the assertion: ClassMethod__c is the
	 * signal's subscriber-observable payload (Log Console column, runbook forensic grep), so a
	 * rename that changes it SHOULD fail these tests. Counting per site over the file's
	 * established getAll() idiom keeps unrelated framework entries from breaking the tests;
	 * in-test log volume is bounded (clean org, ignoreTestMode-gated publishes).
	 *
	 * @param executionId The chain execution record the signal must name.
	 * @param siteMethodSuffix The emitting site's method-name suffix (e.g. 'handleChainCompletion').
	 * @param expectedLogLevel The required LogLevel__c value, or null to count any level.
	 *
	 * @return The number of matching log entries.
	 */
	private static Integer countTerminalLogs(Id executionId, String siteMethodSuffix, String expectedLogLevel)
	{
		Integer matches = 0;
		for(LogEntry__c logEntry : findLogEntriesAt(executionId, siteMethodSuffix))
		{
			if(expectedLogLevel == null || logEntry.LogLevel__c == expectedLogLevel)
			{
				matches++;
			}
		}
		return matches;
	}

	/**
	 * @description Collects the persisted LogEntry__c rows that name the given execution and were
	 * emitted at the given site, for the tests that assert on an entry's payload — its level, its
	 * correlation, the text a reader sees — rather than only on how many there are.
	 *
	 * @param executionId The chain execution record the entry must name.
	 * @param siteMethodSuffix The emitting site's method-name suffix (e.g. 'announceMintedCorrelation').
	 *
	 * @return The matching log entries, in the selector's order.
	 */
	private static List<LogEntry__c> findLogEntriesAt(String executionId, String siteMethodSuffix)
	{
		List<LogEntry__c> matches = new List<LogEntry__c>();
		for(LogEntry__c logEntry : new SEL_LogEntry().getAll())
		{
			if(logEntry.RecordId__c == executionId && logEntry.ClassMethod__c != null && logEntry.ClassMethod__c.endsWith(siteMethodSuffix))
			{
				matches.add(logEntry);
			}
		}
		return matches;
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
	 * @description Step that succeeds and declares itself safe to execute more than once, so tests
	 * can prove the builder persists the declaration into the step log.
	 */
	public class IdempotentSuccessStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Declares the step safe to re-run — the constructor-free shape a subscriber uses.
		 *
		 * @return True.
		 */
		public override Boolean isIdempotent()
		{
			return true;
		}

		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.succeeded();
		}
	}

	/**
	 * @description Step whose idempotency override answers null, so tests can prove a null answer
	 * reads as undeclared rather than as a declaration.
	 */
	public class NullDeclaringStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Answers null instead of a Boolean.
		 *
		 * @return Null.
		 */
		public override Boolean isIdempotent()
		{
			return null;
		}

		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.succeeded();
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
	 * @description Step that declares its failure permanent, halting the chain so the terminal
	 * declared-permanent marker persist is exercised. Declared idempotent so re-drive fixtures can
	 * reuse it.
	 */
	public class PermanentlyFailingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Declares the step safe to re-run so the permanent-failure refusal is proven to
		 * outrank the idempotency declaration.
		 *
		 * @return True.
		 */
		public override Boolean isIdempotent()
		{
			return true;
		}

		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failedPermanently(PERMANENT_FAILURE_MESSAGE);
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
	 * @description Step with continueOnError that fails with a large message: individually under the
	 * default context soft cap, but too large for the StepLog__c field once repeated failures
	 * accumulate in the step list.
	 *
	 * @date July 2026
	 */
	public class OversizedFailureMessageStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Constructs an OversizedFailureMessageStep with continueOnError enabled.
		 */
		public OversizedFailureMessageStep()
		{
			this.continueOnError = true;
		}

		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed('F'.repeat(OVERSIZED_MESSAGE_LENGTH));
		}
	}

	/**
	 * @description Step without continueOnError that fails with the same oversized message, halting
	 * the chain so the terminal-failure persist path is exercised.
	 *
	 * @date July 2026
	 */
	public class HaltingOversizedFailureMessageStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed('F'.repeat(OVERSIZED_MESSAGE_LENGTH));
		}
	}

	/**
	 * @description Success step whose stepName is supplied by the test, used to pad the serialized
	 * step list towards the StepLog__c field capacity.
	 *
	 * @date July 2026
	 */
	public class PaddedNameStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Constructs the step with the test-seeded padded name. Each test seeds
		 * paddedStepName before building its chain so the step definition carries it; when the
		 * framework type resolver re-instantiates the step from its class name at runtime, the
		 * display name comes from the persisted definition, not this instance.
		 */
		public PaddedNameStep()
		{
			this.stepName = paddedStepName;
		}

		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.succeeded();
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
		/**
		 * @description Records execution in context to prove a pure interface step runs.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A successful StepResult.
		 */
		public UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put('pureInterfaceExecuted', true);
			return UTIL_AsyncChain.succeeded('Pure interface step completed');
		}
	}

	/**
	 * @description Test step that self-calibrates one DML_Builder execute's statement cost, then
	 * burns the transaction's DML statement budget down to exactly that cost — so the terminal
	 * write consumes the last statements, letting the test verify that the write still commits
	 * when the chain's own work has exhausted the DML budget (I2).
	 */
	public class DmlBudgetBurnerStep implements IF_Chain.Step
	{
		/**
		 * @description Burns the transaction's DML statement budget down to near-exhaustion, then
		 * returns successfully so the chain reaches its terminal write with almost no budget left.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A successful StepResult.
		 */
		public UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			Foobar__c burner = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
			Integer statementsBefore = Limits.getDmlStatements();
			DML_Builder.newTransaction().doInsert(burner).execute();
			Integer statementsPerExecute = Limits.getDmlStatements() - statementsBefore;

			while(Limits.getLimitDmlStatements() - Limits.getDmlStatements() > statementsPerExecute)
			{
				DML_Builder.newTransaction().doUpdate(burner).execute();
			}
			return UTIL_AsyncChain.succeeded('Step completed');
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