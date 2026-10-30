// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests for UTIL_AsyncChain, the framework that runs async chains (a list of steps, each run in
 * its own Queueable job). They cover the Queueable run path, the ChainBuilder methods, the values ChainContext
 * holds, the StepResult factory methods, the error and completion handlers, the kill switch and edge cases.
 * The recovery tests live in UTIL_AsyncChainRecovery_TEST: the run key that stops an old job from writing, stalled
 * chains, the watchdog sweep, starting a chain again, checking whether a job is still alive, and the markers a step
 * leaves when it resumes. The ApiStep and per-step retry tests live in UTIL_AsyncChainApi_TEST.
 *
 * @see UTIL_AsyncChain
 * @see UTIL_AsyncChainRecovery_TEST
 * @see UTIL_AsyncChainApi_TEST
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date April 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssTypeCount,PMD.NcssCount')
private class UTIL_AsyncChain_TEST
{
	/**
	 * @description Company name of the admin user created in the test setup. Tests find that user by this name and run as
	 * them.
	 */
	private static final String TEST_ADMIN_COMPANY = 'UTIL_AsyncChain_TEST-admin';

	/**
	 * @description Company name of the minimum-access user created in the test setup. Tests find that user by this name and
	 * run as them, either as a second user who must not see another user's run or be left out of an org-wide switch, or to
	 * prove a chain still completes for a user with very few permissions.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'UTIL_AsyncChain_TEST-low-privilege';

	/**
	 * @description Name used for test chains.
	 */
	private static final String TEST_CHAIN_NAME = 'TestChain';

	/**
	 * @description Step count for the deep-chain completion test: long enough that completing it
	 * proves the framework's default AsyncOptions depth (step count plus one plus the levels kept for nested chains) covers
	 * every time the chain queues its next job, not just the short two- and three-step chains the other tests run.
	 */
	private static final Integer DEEP_CHAIN_STEP_COUNT = 7;

	/**
	 * @description The step count that gives a chain launched from a plain job a second step, so the chain's second job is queued too.
	 */
	private static final Integer TWO_STEPS = 2;

	/**
	 * @description Queueable stack depth that the caller passes, for the tests that check the first queued job copies the
	 * caller's options. It is chosen to differ from any default the framework works out in these tests (step count plus
	 * one plus the levels kept for nested chains). So a depth seen on the built options can only have come from the
	 * caller's object.
	 */
	private static final Integer CUSTOM_STACK_DEPTH = 5;

	/**
	 * @description Queueable stack depth that a trigger passes to the chain it launches, in the test that checks the chain runs
	 * under the caller's maximum. It is not 5, the platform default, and not 7, the framework default for that chain. So the
	 * depth the chain saves can only have come from the caller's options.
	 */
	private static final Integer CALLER_MAXIMUM_STACK_DEPTH = 9;

	/**
	 * @description The framework default maximum for the one-step chain that a trigger launches with no options, when the
	 * launch starts a new line of jobs at depth 0. It is made up of 0 for the launch depth, 1 for the one step, 1 for the first
	 * hop, and 5 for the levels the framework keeps for nested chains.
	 */
	private static final Integer DEFAULT_TRIGGER_CHAIN_STACK_DEPTH = 7;

	/**
	 * @description A first-step delay inside the platform range of 0 to 10, passed to the helper that copies the options
	 * for the first queued job. The test expects it back unchanged on the built options, and never on the caller's object.
	 */
	private static final Integer DELAY_MINUTES = 5;

	/**
	 * @description Stand-in for the framework's default stack depth (step count plus one plus the levels kept for nested
	 * chains), as execute() works it out for a chain started without custom options. This value must reach the first
	 * queued job too, not only the later ones.
	 */
	private static final Integer DEFAULT_DEPTH_FIXTURE = 3;

	/**
	 * @description Length of the step failure message that is too long on purpose. One message alone stays under the
	 * default context limit of 32,768 characters (the context holds only the latest result). But five of them in the
	 * step list are more than the 131,072-character StepLog__c field holds. So a copy with no length limit could never
	 * survive several continueOnError failures in a row.
	 */
	private static final Integer OVERSIZED_MESSAGE_LENGTH = 30000;

	/**
	 * @description The longest the copy of a failure message saved inside StepLog__c may be. The test keeps its own copy
	 * of the limit, so it does not read the value from the code it checks. The full message is kept in ErrorMessage__c
	 * and in the log entry for the step failure.
	 */
	private static final Integer EXPECTED_STEP_MESSAGE_BOUND = 255;

	/**
	 * @description Combined fixed JSON overhead, in characters, of the two-step chain that tests the safety valve in the
	 * middle of a chain. The safety valve drops a step's failure message when the step log would grow past its field
	 * capacity. The overhead is everything outside the padded step name:
	 * the OversizedFailureMessageStep entry as the launch inserts it (102, its first-step start included),
	 * the PaddedNameStep entry's fixed fields (65), the array brackets and comma (3), and 252 of deliberate headroom.
	 * The padded name is sized as capacity minus this value, so the build-time step list lands 252 characters under the
	 * StepLog__c capacity. That is more than the runtime reserve the build-time guard holds back (2 steps x 100). But it
	 * is too small to also hold what the first job's progress save adds: the failing step's shortened message (about 270
	 * characters), its result markers and the next step's start, about 316 in all. So the rewrite in the middle of the
	 * chain goes over capacity, and the safety valve has to drop the message.
	 */
	private static final Integer CONTINUED_OVERSIZED_CHAIN_JSON_OVERHEAD = 422;

	/**
	 * @description Combined fixed JSON overhead of the two-step chain that tests the safety valve when the chain ends.
	 * The overhead is everything outside the padded step name: the HaltingOversizedFailureMessageStep entry as the launch
	 * inserts it (86), the PaddedNameStep entry's fixed fields (65), the array brackets and comma (3), and the same 252 of
	 * headroom. That headroom is more than the reserve the guard holds back (200). But it is too small to hold the final
	 * save's shortened message and result markers (about 302). So the final rewrite has to use the safety valve.
	 */
	private static final Integer HALTING_OVERSIZED_CHAIN_JSON_OVERHEAD = 406;

	/**
	 * @description Fixed JSON overhead of a two-PaddedNameStep chain (2 x 65 entry fields + 3 array
	 * characters) plus a 120-character headroom target. Each padded name is sized as (capacity minus this value) / 2, so
	 * the build-time step list lands about 120 characters under the raw field capacity (105 once the launch records the
	 * first step's start). That is inside the room execute() keeps free for each step while it runs (2 steps x 100), but
	 * outside a smaller room of 2 x 50. So the guard must reject the chain even though the raw field could hold it, and
	 * only the room of 100 per step makes it do so.
	 */
	private static final Integer PADDED_PAIR_JSON_OVERHEAD = 253;

	/**
	 * @description Context size limit set for the chains with the oversized message. It gives the 30,000-character
	 * failure message plenty of room in the saved result of the previous step. So the logging details the framework
	 * adds to the context can never push these tests over the default limit of 32,768 and fail them with a misleading
	 * context-too-large error.
	 */
	private static final Integer OVERSIZED_MESSAGE_CONTEXT_CAP = 60000;

	/**
	 * @description Initial-context key that the tests for chains that allow a restart seed. The test expects it unchanged
	 * in the copy of the starting data saved on the run record when the chain is built.
	 */
	private static final String RESTART_SEED_KEY = 'restartSeedKey';

	/**
	 * @description Initial-context value that the tests for chains that allow a restart seed. The test expects it
	 * unchanged in the copy of the starting data saved on the run record when the chain is built.
	 */
	private static final String RESTART_SEED_VALUE = 'restart-seed-value';

	/**
	 * @description Context key that SuccessStep writes while the chain runs. It is in the context as the steps change it,
	 * but never in the copy of the starting data, so the restart tests can tell the two apart.
	 */
	private static final String EVOLVED_CONTEXT_KEY = 'stepCount';

	/**
	 * @description Deduplication key that the declared-key test passes to withDeduplicationKey. The test expects it back
	 * unchanged on the finished record, after the active key is released.
	 */
	private static final String DECLARED_DEDUPLICATION_KEY = 'declared-deduplication-key-value';

	/**
	 * @description Failure message of the test step that fails and declares the failure permanent.
	 */
	private static final String PERMANENT_FAILURE_MESSAGE = 'Declared permanent failure';

	/**
	 * @description Fixed JSON characters around the class name of each step that declares nothing, in the StepLog__c
	 * document saved at insert: the entry braces, the className key and its quotes. This is the size of a plain step
	 * entry. The declaration markers are left out when they are null, so they must not make that entry any longer.
	 */
	private static final Integer HEALTHY_STEP_ENTRY_JSON_OVERHEAD = 16;

	/**
	 * @description Fixed JSON characters of the two-entry step-list document outside its entries: the
	 * array brackets plus the single separating comma.
	 */
	private static final Integer HEALTHY_STEP_LIST_JSON_OVERHEAD = 3;

	/**
	 * @description JSON characters of the one runtime member a launch records in the insert-time step log, the first
	 * step's start: the separating comma, the quoted started key, the colon and the value true.
	 */
	private static final Integer FIRST_STEP_START_JSON_LENGTH = ',"started":true'.length();

	/**
	 * @description Deduplication key shared by the two launches in the deduplication-landing test, so
	 * the second launch lands on the first chain instead of starting a run of its own.
	 */
	private static final String SHARED_DEDUPLICATION_KEY = 'shared-deduplication-key-value';

	/**
	 * @description The method suffix of the framework's launch log entry. It is written in the log entries of the action
	 * that launched the run, for every run launched under an active log correlation.
	 */
	private static final String LAUNCH_ANNOUNCEMENT_SITE = 'announceLaunch';

	/**
	 * @description The method suffix of the framework's completion entry, written once by every run that completes.
	 */
	private static final String COMPLETION_SITE = 'handleChainCompletion';

	/**
	 * @description The chain name of the one-step chain a launching step starts from inside its own run.
	 */
	private static final String CHILD_CHAIN_NAME = 'ChildChain';

	/**
	 * @description The chain name of the run a nested launching step starts, whose own step launches one more.
	 */
	private static final String GRANDCHILD_CHAIN_NAME = 'GrandchildChain';

	/**
	 * @description The context key under which a launching step stores the execution id of the chain it launched.
	 */
	private static final String CHILD_EXECUTION_KEY = 'childExecutionId';

	/**
	 * @description The framework's reserved context key for the serialized logging context, mirrored here because the
	 * production constant is private.
	 */
	private static final String LOG_CONTEXT_KEY_NAME = '__logContext';

	/**
	 * @description The JSON field name of a context document's correlation id.
	 */
	private static final String DOCUMENT_CORRELATION_FIELD = 'correlationId';

	/**
	 * @description The JSON field name of a context document's root correlation id.
	 */
	private static final String DOCUMENT_ROOT_FIELD = 'rootCorrelationId';

	/**
	 * @description The framework's reserved context key for a run's nesting depth, mirrored here because the production
	 * constant is private.
	 */
	private static final String NESTING_DEPTH_KEY_NAME = '__nestingDepth';

	/**
	 * @description The deepest nesting level the framework allows, mirrored here because the production constant is
	 * private: the sixth launch in a line of launches is refused.
	 */
	private static final Integer MAXIMUM_NESTING_DEPTH = 5;

	/**
	 * @description The test's own copy of the wording of the refusal for nesting too deep.
	 */
	private static final String NESTING_REFUSAL_FRAGMENT = 'chains may nest at most';

	/**
	 * @description The test's own copy of the wording of the refusal for no stack depth left.
	 */
	private static final String STACK_REFUSAL_FRAGMENT = 'leaving no level';

	/**
	 * @description The chain name of every run in a line of self-launching chains.
	 */
	private static final String NESTED_CHAIN_NAME = 'NestedChain';

	/**
	 * @description The delay, in minutes, a delayed launching step asks for its child.
	 */
	private static final Integer NESTED_LAUNCH_DELAY_MINUTES = 1;

	/**
	 * @description The suffix the framework appends to a launching run's id to key a launch from its first step.
	 */
	private static final String FIRST_STEP_LAUNCH_KEY_SUFFIX = ':0';

	/**
	 * @description The suffix the framework appends to a launching run's id to key a launch from its completion handler.
	 */
	private static final String COMPLETION_HANDLER_LAUNCH_KEY_SUFFIX = ':onComplete';

	/**
	 * @description The suffix the framework appends to a launching run's id to key a launch from its error handler.
	 */
	private static final String ERROR_HANDLER_LAUNCH_KEY_SUFFIX = ':onError';

	/**
	 * @description The padding the context-size warning test seeds: with the framework's reserved entries (the logging
	 * document with its correlation, root and parent transaction, the nesting depth, the previous step result) the
	 * serialized context lands near ninety percent of the limit below, above the warning line and under the ceiling
	 * with room either side.
	 */
	private static final Integer CONTEXT_WARNING_PADDING_LENGTH = 600;

	/**
	 * @description The context-size limit the context-size warning test sets.
	 */
	private static final Integer CONTEXT_WARNING_LIMIT = 1000;

	/**
	 * @description The test's own copy of the words a refusal uses for the run holding the correlation, when the caller
	 * cannot see that run.
	 */
	private static final String UNNAMED_HOLDER_FRAGMENT = 'another chain execution';

	/**
	 * @description The test's own copy of the refusal wording for a second chain launched from one step or handler.
	 */
	private static final String SECOND_LAUNCH_FRAGMENT = 'already launched chain';

	/**
	 * @description The test's own copy of the refusal wording for a launch from a step that already added its one job.
	 */
	private static final String ENQUEUE_USED_FRAGMENT = 'already added its one queueable job';

	/**
	 * @description The test's own copy of the fix that the correlation refusal must name, so the caller is told how to
	 * launch several chains under one log correlation.
	 */
	private static final String CORRELATION_REMEDY_FRAGMENT = 'execute(correlationId)';

	/**
	 * @description Step name the next PaddedNameStep construction reports, seeded by each test before
	 * building its chain. It is a test-only switch, set the same way as the production simulateCrash flag.
	 */
	private static String paddedStepName;

	/**
	 * @description Execution id of the chain ChainLaunchingQueueable launched, so the test that runs that job can read
	 * the run record the launch produced.
	 */
	private static String chainLaunchedFromQueueable;

	/**
	 * @description The two statuses a launch the platform accepted can be found in: the chain is still going, or the
	 * test already ran all its queued jobs and the chain finished. Anything else means the launch itself was refused.
	 */
	private static final Set<String> ACCEPTED_LAUNCH_STATUSES = new Set<String> {SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_COMPLETED};

	/**
	 * @description The exception a launch from inside RefusedLaunchQueueable raised, so the test that runs that job can
	 * check the refusal. Null when the launch was not refused.
	 */
	private static Exception launchRefusalFromQueueable;

	/**
	 * @description Correlation id a launch that is meant to be refused runs under. The tests look for a run record with
	 * this id to prove the refusal saved none.
	 */
	private static final String REFUSED_LAUNCH_CORRELATION_ID = UTIL_Random.randomUUID();

	/**
	 * @description Maximum stack depth for a Queueable whose line of jobs has no level left: the Queueable itself runs at
	 * depth 1, so a chain it launches has no room for its first job.
	 */
	private static final Integer FULL_LINE_STACK_DEPTH = 1;

	/**
	 * @description Part of the refusal for a launch whose line of jobs has no spare stack level.
	 */
	private static final String STACK_DEPTH_REFUSAL_FRAGMENT = 'queueable stack depth';

	/**
	 * @description Part of the refusal for a launch from a job that has already added its one queueable job.
	 */
	private static final String ENQUEUE_USED_REFUSAL_FRAGMENT = 'already added its one queueable job';

	/**
	 * @description Execution id of the chain ChainLaunchingTriggerAction launched from the Foobar__c trigger, so the test
	 * can read the run record that launch produced. Null when the launch did not happen or was refused.
	 */
	private static String chainLaunchedFromTrigger;

	/**
	 * @description The exception the launch from ChainLaunchingTriggerAction raised, so the test can show the launch was
	 * not refused. Null when the launch worked.
	 */
	private static Exception launchRefusalFromTrigger;

	/**
	 * @description The options ChainLaunchingTriggerAction gives the chain it launches. Null, the default, launches the
	 * chain with no options of its own.
	 */
	private static AsyncOptions triggerLaunchOptions;

	/**
	 * @description The context key under which MaximumStackDepthRecordingStep saves the maximum queueable stack depth
	 * of the job it runs in.
	 */
	private static final String MAXIMUM_STACK_DEPTH_KEY = 'maximumStackDepth';

	/**
	 * @description The full name of the test trigger action that launches a chain after a Foobar__c record is inserted.
	 * The trigger framework creates the action from this name.
	 */
	private static final String CHAIN_LAUNCHING_TRIGGER_ACTION_CLASS = ChainLaunchingTriggerAction.class.getName();

	/**
	 * @description Creates a test admin user of its own, so System.runAs in each test starts with fresh permission
	 * checks. This avoids a problem where the test org kept stale permissions after the running user's permission set
	 * changed in the middle of a transaction. It also saves a low-privilege user (Minimum Access - Salesforce profile),
	 * so the test that runs as that user (shouldCompleteChainForLowPrivilegeUser) can call System.runAs without a
	 * MIXED_DML_OPERATION error. User is a Setup object, so a User save cannot share a transaction with a save of a
	 * standard or custom object. Creating the users here keeps the two apart.
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

		TST_Factory.insertUsers(new List<User> {TST_Factory.newMinimumAccessUser(LOW_PRIVILEGE_COMPANY)});
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
	 * @description Verifies a seven-step chain completes from start to end through the real async path, under the
	 * framework's default AsyncOptions. The builder sets no depth, so the depth used is the one execute() works out
	 * (step count plus one plus the levels kept for nested chains). This test guards the limit for long chains. If that
	 * calculation breaks, or the platform changes how deep queued jobs may chain, this test fails before any real chain
	 * does.
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
			Assert.isNotNull(execution.CompletedAt__c, 'Completed is a final status: CompletedAt must be set');
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
	 * @description Verifies that getChainStatus maps every scalar of a saved execution onto the
	 * typed ChainStatus value object, and that a Completed chain reports a final status (not running, not failed).
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
	 * DurationMs__c is not yet saved, mirroring the Chain Monitor's live-duration rule.
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
	 * @description Verifies that getChainStatus keeps counting for a Stalled chain with no stored duration, as the
	 * Chain Monitor does: a run that went silent has still been going since its start.
	 */
	@IsTest
	private static void shouldComputeLiveDurationForStalledChainStatus()
	{
		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c record = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now().addMinutes(-3),
					AsyncChainExecution__c.DurationMs__c => null
			});

			UTIL_AsyncChain.ChainStatus status = UTIL_AsyncChain.getChainStatus(record.Id);

			Assert.isNotNull(status.durationMs, 'A Stalled chain with no stored duration should report how long it has been going');
			Assert.isTrue(status.durationMs >= 120000L, 'The live duration should cover at least two of the three minutes since the start');
			Assert.isNotNull(status.durationLabel, 'durationLabel should be derived from the live duration');
		}
	}

	/**
	 * @description Verifies that getChainStatus gives an ended chain that stored no duration (a crashed background
	 * job's run, a run with no steps) the time between its start and its end, for each of the three ways a run ends.
	 */
	@IsTest
	private static void shouldReportStartToEndForEndedChainStatusWithoutStoredDuration()
	{
		System.runAs(getTestAdmin())
		{
			Datetime startedAt = Datetime.newInstanceGmt(2026, 6, 26, 10, 0, 0);
			Map<Id, String> statusByExecutionId = new Map<Id, String>();

			for(String endedStatus : new List<String> {SEL_AsyncChainExecution.STATUS_COMPLETED, SEL_AsyncChainExecution.STATUS_FAILED, SEL_AsyncChainExecution.STATUS_ABORTED})
			{
				AsyncChainExecution__c record = TST_Factory.newChainExecution(endedStatus, TEST_CHAIN_NAME, new Map<SObjectField, Object>
				{
						AsyncChainExecution__c.StartedAt__c => startedAt,
						AsyncChainExecution__c.CompletedAt__c => startedAt.addSeconds(5),
						AsyncChainExecution__c.DurationMs__c => null
				});
				statusByExecutionId.put(record.Id, endedStatus);
			}

			Map<Id, UTIL_AsyncChain.ChainStatus> statuses = UTIL_AsyncChain.getChainStatuses(statusByExecutionId.keySet());

			Assert.areEqual(3, statuses.size(), 'Every ended chain should resolve');
			for(Id executionId : statuses.keySet())
			{
				UTIL_AsyncChain.ChainStatus status = statuses.get(executionId);
				Assert.areEqual(5000L, status.durationMs, 'A ' + statusByExecutionId.get(executionId) + ' chain with no stored duration should report its start to its end');
				Assert.areEqual(UTIL_Date.formatDuration(5000L), status.durationLabel, 'durationLabel should derive from the same duration');
			}
		}
	}

	/**
	 * @description Verifies that getChainStatus still reports the stored duration for a row that was never read from
	 * the database, which is what a test that registers its own chain row with TST_Mock hands the accessor. Such a
	 * row carries no formula value, so the stored duration is the only one there is.
	 */
	@IsTest
	private static void shouldReportStoredDurationForMockedChainStatusRow()
	{
		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c mockedRow = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.ChainName__c, TEST_CHAIN_NAME)
					.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_COMPLETED)
					.withOverride(AsyncChainExecution__c.DurationMs__c, 4200)
					.withoutInsertion(true)
					.build();
			TST_Mock.register(AsyncChainExecution__c.SObjectType, mockedRow);

			UTIL_AsyncChain.ChainStatus status = UTIL_AsyncChain.getChainStatus(mockedRow.Id);

			Assert.isNotNull(status, 'The registered row should be the one the accessor reads');
			Assert.areEqual(4200L, status.durationMs, 'A row with no formula value should still report the duration it stored');
			Assert.areEqual(UTIL_Date.formatDuration(4200L), status.durationLabel, 'durationLabel should derive from the stored duration');
		}
	}

	/**
	 * @description Verifies that getChainStatus reports no duration for a chain that never recorded a start, whatever
	 * its status: there is nothing to count from.
	 */
	@IsTest
	private static void shouldReportNoDurationForChainStatusWithoutStart()
	{
		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c record = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => null,
					AsyncChainExecution__c.DurationMs__c => null
			});

			UTIL_AsyncChain.ChainStatus status = UTIL_AsyncChain.getChainStatus(record.Id);

			Assert.isNull(status.durationMs, 'A chain with no recorded start has no duration to report');
			Assert.isNull(status.durationLabel, 'durationLabel follows durationMs');
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
	 * @description A Stalled row with an end time (CompletedAt__c) is a finished run whose status was overwritten by
	 * mistake. This can happen when an abort and another save race, and that rare case is accepted. isTerminal() must
	 * report the row as finished, so subscriber code that polls the status stops. A real stalled row (no end time)
	 * stays not finished and can be recovered. The package does not let anyone
	 * save a Stalled record with an end time. Older orgs still have such records. So the test does not save one. It gives
	 * the status read a stand-in (mocked) record instead.
	 */
	@IsTest
	private static void shouldReportContradictoryStalledRowTerminal()
	{
		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c contradictory = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.ChainName__c, TEST_CHAIN_NAME)
					.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_STALLED)
					.withOverride(AsyncChainExecution__c.CompletedAt__c, Datetime.now())
					.withoutInsertion(true)
					.build();
			AsyncChainExecution__c genuine = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME + '-genuine');
			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType, contradictory);

			UTIL_AsyncChain.ChainStatus contradictoryStatus = UTIL_AsyncChain.getChainStatus(contradictory.Id);
			UTIL_AsyncChain.ChainStatus genuineStatus = UTIL_AsyncChain.getChainStatus(genuine.Id);

			Assert.isTrue(contradictoryStatus.isTerminal(), 'A completion timestamp proves the chain ended, whatever Status__c says');
			Assert.isFalse(contradictoryStatus.isRunning(), 'A contradictory row is not running');
			Assert.isFalse(genuineStatus.isTerminal(), 'A real stall (no end time) is not finished');
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
	 * @description Guards against a later change: getChainStatus must not change the getStatus(Id) map, which may not
	 * change. It still returns exactly the six documented keys, with matching values.
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
	 * @description getChainStatus keeps sharing, like getStatus: a user who does not own a chain must not read another
	 * user's private chain (the org-wide default is Private) through getChainStatus. The admin owns the row; a
	 * low-privilege user who does not own it reads null.
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
			Assert.isNull(status, 'A user who does not own the chain must not read another user\'s private chain through getChainStatus');
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
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'A zero delay behaves exactly like no delay');
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
	 * @description Verifies the delay applies only to the first queued job, and never leaks into the shared AsyncOptions
	 * that the Finalizer reuses to queue the later steps. It checks directly that execute() leaves the AsyncOptions
	 * object unchanged (no delay set on it, stack depth the same). So a change that wrote the delay onto the shared
	 * options is caught at the place it happens. Chain completion alone would not show it, because the platform ignores
	 * queue delays under Test.stopTest.
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
	 * @description Verifies that the helper building the options for the first queued job keeps the custom AsyncOptions
	 * when the first job is DELAYED. It also checks that the helper returns a copy. The delay is set only on the built
	 * options. The caller's object is passed on to every later job of the chain, so it must stay exactly the same; the
	 * test checks it one property at a time.
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
			Assert.areEqual(DELAY_MINUTES, built.minimumQueueableDelayInMinutes, 'The delay must be set on the built options');
			Assert.isNull(custom.minimumQueueableDelayInMinutes, 'The caller\'s options must have no delay (otherwise every later job is delayed too)');
			Assert.areEqual(CUSTOM_STACK_DEPTH, custom.maximumQueueableStackDepth, 'The copy must leave the caller\'s options exactly the same');
		}
	}

	/**
	 * @description Verifies that the helper building the options for the first queued job passes the framework's
	 * default stack depth to a first job with no delay and no custom options. So the default depth applies from the
	 * first job, not only from the second. It also checks that the helper sets no delay when none is configured.
	 */
	@IsTest
	private static void shouldApplyDefaultDepthOnUndelayedFirstEnqueueWithoutCustomOptions()
	{
		System.runAs(getTestAdmin())
		{
			AsyncOptions defaults = new AsyncOptions();
			defaults.maximumQueueableStackDepth = DEFAULT_DEPTH_FIXTURE;
			AsyncOptions built = UTIL_AsyncChain.buildFirstEnqueueOptions(defaults, null);
			Assert.areEqual(DEFAULT_DEPTH_FIXTURE, built.maximumQueueableStackDepth, 'The default depth must reach the first job');
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
	 * @description A chain with no steps, launched under an active log correlation, gets a launch log entry among the
	 * action's log entries like any other launch, once its record exists.
	 */
	@IsTest
	private static void shouldAnnounceASteplessChainInTheActionsStory()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			String actionCorrelationId = LOG_Builder.startCorrelation();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			assertAnnouncedOnceInTheStory(executionId, actionCorrelationId);
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
	 * with valid step-log JSON: every saved failure-message copy is bounded rather than the JSON
	 * document being truncated, so a later step's deserialize cannot throw and override the caller's
	 * explicit continueOnError intent.
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
					'Chain should complete despite the many oversized failure messages: the continueOnError choice must hold');
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
	 * @description Verifies that execute() keeps room free for what the steps add while they run. A step list that fits
	 * the raw StepLog__c field, but leaves no room for the success and duration fields each step adds, must be rejected
	 * when the chain is built. Otherwise the chain would pass the check and still fail on a save in the middle of the
	 * run, even after the safety valve drops every message.
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
	 * @description Verifies the safety valve on the terminal-failure save: when a halting
	 * (non-continueOnError) step fails with a near-capacity step list, the Failed record still
	 * carries valid step-log JSON with the messages dropped and the step names kept, and the full
	 * failure message is in ErrorMessage__c.
	 */
	@IsTest
	private static void shouldDropStepMessagesOnTerminalFailureWhenStepLogWouldOverflow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Integer fieldCapacity = AsyncChainExecution__c.StepLog__c.getDescribe().getLength();
			paddedStepName = 'N'.repeat(fieldCapacity - HALTING_OVERSIZED_CHAIN_JSON_OVERHEAD);

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.HaltingOversizedFailureMessageStep())
					.then(new UTIL_AsyncChain_TEST.PaddedNameStep())
					.withMaxContextSize(OVERSIZED_MESSAGE_CONTEXT_CAP)
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should halt on the non-continueOnError failure');
			Assert.isTrue(execution.ErrorMessage__c.startsWith('FFF'), 'The full failure message should reach ErrorMessage__c');
			List<UTIL_AsyncChain.DTO_StepDefinition> persistedSteps = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.areEqual(2, persistedSteps.size(), 'Step log on the Failed record should remain a valid two-entry JSON document');
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
	 * @description Verifies the safety valve in the middle of a chain: when a progress rewrite of the step list
	 * would overflow StepLog__c even with bounded messages, the per-step message values are dropped
	 * from the saved copy, so the JSON document is never cut short. The full failure details are
	 * kept in ErrorMessage__c and in the log entries for the step failures.
	 */
	@IsTest
	private static void shouldDropStepMessagesWhenMidChainStepLogWouldOverflow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Integer fieldCapacity = AsyncChainExecution__c.StepLog__c.getDescribe().getLength();
			paddedStepName = 'N'.repeat(fieldCapacity - CONTINUED_OVERSIZED_CHAIN_JSON_OVERHEAD);

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain_TEST.OversizedFailureMessageStep())
					.then(new UTIL_AsyncChain_TEST.PaddedNameStep())
					.withMaxContextSize(OVERSIZED_MESSAGE_CONTEXT_CAP)
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c,
					'Chain should complete despite the step log approaching capacity');
			Assert.areEqual(1, execution.CompletedSteps__c, 'The padded success step should be counted');
			List<UTIL_AsyncChain.DTO_StepDefinition> persistedSteps = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.areEqual(2, persistedSteps.size(), 'Step log should remain a valid two-entry JSON document');
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
	 * same record Id gives the same key again (so running a step again is safe), and that different record
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

			Assert.areEqual('test-exec-id-2-' + firstRecordId, firstKey, 'The per-record key should be the step key + "-" + recordId');
			Assert.areEqual(firstKey, context.idempotencyKey(firstRecordId), 'The same record Id must give the same key again, so running a step again is safe');
			Assert.areNotEqual(firstKey, context.idempotencyKey(secondRecordId), 'Different record Ids must produce different keys');
		}
	}

	/**
	 * @description Verifies that idempotencyKey(String) builds the step key + "-" + the given text, and that a long text
	 * passes through unchanged, with no hashing or cutting. The method treats the text as a value it never reads.
	 */
	@IsTest
	private static void shouldDeriveStringGrainIdempotencyKey()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('test-exec-id', 'test-corr-id');
			context.currentStepIndex = 2;

			Assert.areEqual('test-exec-id-2-orderLine-7', context.idempotencyKey('orderLine-7'),
					'The key for a given text should be the step key + "-" + that text');

			String longGrain = 'x'.repeat(500);
			Assert.areEqual('test-exec-id-2-' + longGrain, context.idempotencyKey(longGrain),
					'A long text must pass through unchanged: the method never hashes or cuts it');
		}
	}

	/**
	 * @description Verifies how null is handled: a null record Id, a null String, and a blank or whitespace String all
	 * fall back to the plain step-level key (no trailing separator, no "null" text). The test passes typed variables to
	 * choose the right method, because a plain null literal does not compile (Ambiguous method signature).
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
					'Expected a null record Id to fall back to the plain step-level key');
			Assert.areEqual('test-exec-id-2', context.idempotencyKey(nullGrain),
					'Expected a null String to fall back to the plain step-level key');
			Assert.areEqual('test-exec-id-2', context.idempotencyKey('   '),
					'Expected a blank or whitespace String to fall back to the plain step-level key');
		}
	}

	/**
	 * @description Proves the per-record key method is safe to call once for each record in a loop. Building keys for
	 * several records runs no SOQL and no DML (the query and DML counts are the same before and after). Different
	 * records give different keys, each built exactly. The key is plain string joining, with no hashing or cutting, so
	 * a few records are enough. No large volume is needed to show that keys never clash and cost nothing. (The tests
	 * above cover one record, getting the same key again, and the null and blank cases.)
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

			Integer queriesBefore = UTIL_Limits.soqlQueries().used();
			Integer dmlBefore = UTIL_Limits.dmlStatements().used();

			Set<String> keys = new Set<String>();
			for(Id recordId : recordIds)
			{
				String key = context.idempotencyKey(recordId);
				Assert.areEqual('test-exec-id-2-' + recordId, key, 'Each per-record key must be the step key + "-" + recordId');
				keys.add(key);
			}

			Assert.areEqual(recordIds.size(), keys.size(), 'Distinct record Ids must yield the same number of distinct keys (no collision)');
			Assert.areEqual(queriesBefore, UTIL_Limits.soqlQueries().used(), 'Deriving keys must issue no SOQL (zero query cost)');
			Assert.areEqual(dmlBefore, UTIL_Limits.dmlStatements().used(), 'Deriving keys must issue no DML (zero DML cost)');
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
			Assert.areEqual(1, countTerminalLogs(executionId, 'markAborted', 'WARN'), 'The kill-switch abort logs exactly one WARN entry, from its own method');
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
	 * @description The AsyncChain flag that the package ships must answer ENABLED through the REAL metadata: the flag
	 * record, its strategy record that reads a hierarchy custom setting, and no runtime switch row. That is how an
	 * org that nobody changed answers after an upgrade. The strategy finds no AsyncChainRuntimeSwitch__c row and
	 * reports no match, and the flag's ResultOnNoMatch keeps chains enabled. The test sets up NO flag mock, on
	 * purpose: the shipped records are what it tests, so it proves an upgrade leaves chains enabled.
	 * A first check tells the no-match answer apart from IsEnabledByDefault, which is used when there is no strategy.
	 * Both answer true on the shipped record. Without that check, the test would still pass if the strategy record
	 * were deleted.
	 */
	@IsTest
	private static void shouldResolveChainFlagEnabledWithStrategyRecordAndNoSettingRow()
	{
		System.runAs(getTestAdmin())
		{
			FeatureFlag__mdt chainFlag = SEL_FeatureFlag.activeFlags.get(UTIL_AsyncChain.FEATURE_FLAG_NAME);
			Assert.areEqual(1, chainFlag.FeatureFlagStrategies__r?.size(),
					'Expected the shipped AsyncChain flag to carry exactly one strategy, its hierarchy-setting strategy; without it, '
					+ 'the flag falls back to IsEnabledByDefault and this test could no longer catch a deleted strategy record');
			Assert.areEqual(SEL_FeatureFlagStrategy.TYPE_HIERARCHICAL_CUSTOM_SETTING, chainFlag.FeatureFlagStrategies__r[0].Type__c,
					'Precondition: the shipped strategy must resolve through the hierarchy-setting type');

			Assert.isTrue(UTIL_AsyncChain.isChainProcessingEnabled(),
					'An org that never wrote the runtime switch must resolve chains enabled: strategy no-match falls back to the shipped ResultOnNoMatch');
		}
	}

	/**
	 * @description suspendChainProcessing writes the ORG-default switch row, so the suspension is
	 * org-wide: both the suspending user and an unrelated second user resolve chains disabled
	 * through the hierarchy strategy. The second-user assert is what proves the suspension is
	 * org-wide: a user-level write would suspend only its author and must fail here.
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
					'A second user must see chains disabled: the suspension is saved on the org default, never on a per-user row');
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
	 * @description From start to end: a chain started while chains are enabled is aborted when its next job starts, if
	 * processing was suspended while it ran. The job reads the runtime switch fresh each time it starts, so a
	 * suspension takes effect at once, not only for new chains. The test uses the REAL flag and strategy records (no
	 * flag mock).
	 * The chain record save and the custom setting save happen in this one test transaction ONLY because System.runAs
	 * lifts the mixed DML restriction in tests. That is allowed in a test, but it is not a safe pattern: no production
	 * code may combine the two kinds of save. That is why suspendChainProcessing saves the setting and nothing else.
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
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, execution.Status__c, 'The check when the job starts must abort the chain while processing is suspended');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_KILL_SWITCH, execution.FailureCategory__c, 'A suspension abort is a kill-switch abort');
			Map<String, Object> contextData = parseContextData(execution);
			Assert.isNull(contextData.get('trackingStepExecuted'), 'The step must not run under suspension');
		}
	}

	/**
	 * @description The operator abort writer stamps the full terminal bookkeeping: Aborted status,
	 * OperatorAbort category, shortened reason, end time, duration, and the release of the
	 * deduplication key. It also logs exactly one WARN entry, from its own method.
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
			Assert.isNull(result.ActiveDeduplicationKey__c, 'Expected the deduplication key to be released in the same update as the abort');
			Assert.areEqual(1, countTerminalLogs(execution.Id, 'abortExecution', 'WARN'), 'Exactly one WARN entry, logged from the abort method itself');
		}
	}

	/**
	 * @description The abort method refuses any status other than Running or Stalled. A Completed row is left exactly
	 * as it was, and nothing is logged, because a refusal does not end a chain.
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
	 * @description An operator abort acts on a Stalled chain exactly as on a Running one. A chain that is waiting for
	 * recovery is exactly the kind an operator may need to stop for good.
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
	 * @description The abort method reports a missing row to the caller as a refusal instead of throwing.
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
	 * push the chain past `maxSteps`, BEFORE anything runs. A check that ran inside
	 * `ChainExecutor.execute` would come only after the job was queued, when some work may already be
	 * saved. The check at build time stops the subscriber when the chain is defined, before any
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
	 * @description Verifies that a caller-supplied correlation ID is saved on the execution record.
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
	 * @description A deduplication key longer than the field is rejected at build time. The limit the check uses
	 * matches the field length in the org (the test reads it with a raw describe, so it does not rely on the code it
	 * checks).
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
	 * @description Zero-step chains complete immediately and never stamp the key.
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
	 * @description The unique text index ignores case. So a key that differs only in upper and lower case matches and
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
	 * @description A launch that declares a deduplication key AND reuses a correlation another run already holds is
	 * refused with the correlation rule, whichever form of message the platform gives. The platform's duplicate
	 * error may or may not name the field that clashed.
	 * 1. When it names the field, the framework knows the cause from the first failure.
	 * 2. When it hides the field, the framework first assumes the deduplication index. It finds no run holding its
	 *    own key, so it tries once more. The second failure rules out the deduplication index again, so the
	 *    correlation is the only index left that can have clashed.
	 * The outcome is the same either way. So a launch with a key never gives a subscriber a raw duplicate-value error
	 * to puzzle out.
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
	 * @description When another user's run holds the key, the launch returns that active run's Id but shows the caller
	 * nothing more. Status reads still keep sharing. This is the check in shouldNotLeakOtherUsersChainViaGetChainStatus,
	 * applied to the deduplication path.
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
					'The returned Id must not show the caller more: status reads still keep sharing');
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
	 * @description A completed chain with a completion handler releases the key when the handler's result is saved
	 * back to the run; a later run with the same key is allowed.
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
	 * @description A failing completion handler moves the chain to Failed when the handler's result is saved back to
	 * the run. The key is released, and a later run with the same key is allowed.
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
	 * @description An job crash releases the key in the Finalizer's terminal failure write;
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
	 * @description Two key-less starts in the same window run concurrently: null keys never
	 * collide on the deduplication index. This covers chains started without a key, as older
	 * callers start them.
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
					'Chains without a key must never clash: a null key is not checked for duplicates');
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
	 * @description Verifies that the final context state is saved to the execution record.
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
	 * @description Verifies that newChain creates a builder that saves the chain name.
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
					.withOverride(AsyncChainExecution__c.CompletedAt__c, Datetime.now())
					.withOverride(AsyncChainExecution__c.FailureCategory__c, SEL_AsyncChainExecution.FAILURE_CATEGORY_OPERATOR_ABORT)
					.withOptionalField(AsyncChainExecution__c.ChainName__c)
					.withoutInsertion()
					.build();
			abortRecord.ActiveDeduplicationKey__c = null;
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
	 * @description A chain launched inside a traced action runs under an id of its own, records the action as the id it
	 * was launched under and as its root, and every entry its steps write carries the run's id and the action's root.
	 */
	@IsTest
	private static void shouldRunUnderItsOwnIdAndKeepTheActionAsRoot()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			String actionCorrelationId = LOG_Builder.startCorrelation();

			Test.startTest();
			String executionId = executeContinueOnErrorChain();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areNotEqual(actionCorrelationId, execution.CorrelationId__c, 'The run carries an id of its own, never the action\'s');
			Assert.areEqual(actionCorrelationId, execution.LaunchCorrelationId__c, 'The run was launched under the action');
			Assert.areEqual(actionCorrelationId, execution.RootCorrelationId__c, 'The action is the run\'s root');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete');

			List<LogEntry__c> runEntries = findLogEntriesOfRun(execution.CorrelationId__c);
			Assert.isTrue(runEntries.size() >= 1, 'At least one entry carries the run\'s id (the continueOnError warn)');
			assertEntriesCarryRoot(runEntries, actionCorrelationId, 'Every entry of the run names the action as its root');
		}
	}

	/**
	 * @description Verifies that the full logging context is stored in the chain context under the run's own id, with
	 * the action as the root. So the chain execution record keeps the log context, and each later job can load it back.
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
			Assert.areEqual(correlationId, execution.RootCorrelationId__c, 'The action is the root');
			Map<String, Object> contextData = parseContextData(execution);
			Map<String, Object> logContext = (Map<String, Object>)JSON.deserializeUntyped((String)contextData.get(LOG_CONTEXT_KEY_NAME));
			Assert.areEqual(execution.CorrelationId__c, logContext.get(DOCUMENT_CORRELATION_FIELD), 'The stored context carries the run\'s own id');
			Assert.areEqual(correlationId, logContext.get(DOCUMENT_ROOT_FIELD), 'The stored context carries the action as the root');
		}
	}

	/**
	 * @description Two chains launched inside one traced action carry different ids of their own, both launched under
	 * the action with the action as their root.
	 */
	@IsTest
	private static void shouldGiveEachChainInOneActionAnIdOfItsOwn()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			String actionCorrelationId = LOG_Builder.startCorrelation();

			Test.startTest();
			String firstExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute();
			String secondExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute();
			Test.stopTest();

			AsyncChainExecution__c first = queryExecution(firstExecutionId);
			AsyncChainExecution__c second = queryExecution(secondExecutionId);
			Assert.areNotEqual(actionCorrelationId, first.CorrelationId__c, 'The first chain carries an id of its own');
			Assert.areNotEqual(first.CorrelationId__c, second.CorrelationId__c, 'The two chains carry different ids');
			Assert.areEqual(actionCorrelationId, first.LaunchCorrelationId__c, 'The first run was launched under the action');
			Assert.areEqual(actionCorrelationId, first.RootCorrelationId__c, 'The first run keeps the action as its root');
			Assert.areEqual(actionCorrelationId, second.LaunchCorrelationId__c, 'The second run was launched under the action');
			Assert.areEqual(actionCorrelationId, second.RootCorrelationId__c, 'The second run keeps the action as its root');
		}
	}

	/**
	 * @description Every launch inside a traced action is logged once in the action's story (the log entries filed under
	 * the action's correlation id): an INFO entry under
	 * the action's correlation and root, pointed at the run, naming the run's id and the action's; the runs' own
	 * entries carry their own id and the action's root, so one search by the action's id still returns everything.
	 */
	@IsTest
	private static void shouldAnnounceEachLaunchInTheActionsStory()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			String actionCorrelationId = LOG_Builder.startCorrelation();

			Test.startTest();
			String firstExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute();
			String secondExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			assertAnnouncedOnceInTheStory(firstExecutionId, actionCorrelationId);
			assertAnnouncedOnceInTheStory(secondExecutionId, actionCorrelationId);

			AsyncChainExecution__c second = queryExecution(secondExecutionId);
			List<LogEntry__c> secondChainCompletion = findLogEntriesAt(secondExecutionId, COMPLETION_SITE);
			Assert.areEqual(1, secondChainCompletion.size(), 'The second chain completes and logs it');
			Assert.areEqual(second.CorrelationId__c, secondChainCompletion[0].CorrelationId__c, 'The second chain\'s own entries carry its own id');
			Assert.areEqual(actionCorrelationId, secondChainCompletion[0].RootCorrelationId__c, 'and the action as their root');
		}
	}

	/**
	 * @description The only chain in a traced action still gets an id of its own and one launch log entry. No chain ever
	 * takes the action's id as its own.
	 */
	@IsTest
	private static void shouldAnnounceTheOnlyChainInAnActionOnce()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			String actionCorrelationId = LOG_Builder.startCorrelation();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.areNotEqual(actionCorrelationId, queryExecution(executionId).CorrelationId__c, 'A lone chain carries an id of its own');
			Assert.areEqual(1, findLogEntriesAt(executionId, LAUNCH_ANNOUNCEMENT_SITE).size(), 'The launch is announced once');
		}
	}

	/**
	 * @description A chain launched with no live correlation starts its own action: its run id is its root, it was
	 * launched under nothing, its entries carry the run id in both fields, and nothing is announced.
	 */
	@IsTest
	private static void shouldStartItsOwnActionWhenLaunchedWithNoLiveCorrelation()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.isTrue(String.isNotBlank(execution.CorrelationId__c), 'The run carries an id of its own');
			Assert.isNull(execution.LaunchCorrelationId__c, 'A launch with no live correlation was launched under nothing');
			Assert.areEqual(execution.CorrelationId__c, execution.RootCorrelationId__c, 'The run is its own root');
			List<LogEntry__c> completions = findLogEntriesAt(executionId, COMPLETION_SITE);
			Assert.areEqual(1, completions.size(), 'The chain completes and logs it');
			Assert.areEqual(execution.CorrelationId__c, completions[0].CorrelationId__c, 'The step entries carry the run\'s id');
			Assert.areEqual(execution.CorrelationId__c, completions[0].RootCorrelationId__c, 'The step entries carry the run as the root');
			Assert.areEqual(0, findLogEntriesAt(executionId, LAUNCH_ANNOUNCEMENT_SITE).size(), 'Nothing is announced when no correlation was live');
		}
	}

	/**
	 * @description A caller-supplied id is honoured as the run's id, and the run still records the action it was
	 * launched under and the action's root.
	 */
	@IsTest
	private static void shouldHonourACallerSuppliedIdAndStillRecordTheLaunch()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			String actionCorrelationId = LOG_Builder.startCorrelation();
			String suppliedCorrelationId = UTIL_Random.randomUUID();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute(suppliedCorrelationId);
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(suppliedCorrelationId, execution.CorrelationId__c, 'The run is recorded under the id the caller supplied');
			Assert.areEqual(actionCorrelationId, execution.LaunchCorrelationId__c, 'The run was launched under the action');
			Assert.areEqual(actionCorrelationId, execution.RootCorrelationId__c, 'The run keeps the action as its root');
		}
	}

	/**
	 * @description A chain a step launches gets an id of its own, records the parent run's id as the one it was launched
	 * under, keeps the action's root, and is logged in the parent run's own story (the log entries filed under the
	 * parent run's correlation id). This test also detects it if the platform ever refuses, in a test, a Queueable job
	 * queued from a running Queueable job.
	 */
	@IsTest
	private static void shouldRecordTheParentRunWhenAStepLaunchesAChain()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			String actionCorrelationId = LOG_Builder.startCorrelation();

			Test.startTest();
			String parentExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new LaunchingStep()).withAsyncOptions(createAsyncOptions(3)).execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c parent = queryExecution(parentExecutionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, parent.Status__c, 'The parent completes: ' + parent.ErrorMessage__c);
			String childExecutionId = (String)parseContextData(parent).get(CHILD_EXECUTION_KEY);
			Assert.isTrue(String.isNotBlank(childExecutionId), 'The step launched the child and stored its id');
			AsyncChainExecution__c child = queryExecution(childExecutionId);
			Assert.areNotEqual(parent.CorrelationId__c, child.CorrelationId__c, 'The child run carries an id of its own');
			Assert.areEqual(parent.CorrelationId__c, child.LaunchCorrelationId__c, 'The child was launched under the parent run');
			Assert.areEqual(actionCorrelationId, child.RootCorrelationId__c, 'The child keeps the action as its root');

			List<LogEntry__c> announcements = findLogEntriesAt(childExecutionId, LAUNCH_ANNOUNCEMENT_SITE);
			Assert.areEqual(1, announcements.size(), 'The launch is announced once');
			Assert.areEqual(parent.CorrelationId__c, announcements[0].CorrelationId__c, 'The launch entry is filed under the parent run\'s correlation id');
			Assert.areEqual(actionCorrelationId, announcements[0].RootCorrelationId__c, 'The announcement carries the action as its root');
		}
	}

	/**
	 * @description Three levels deep, the test that proves the whole design works: an action launches run A, whose step
	 * launches run B, whose step launches run C. Each run carries its own id, its launcher's id as the one it was
	 * launched under, and the action's root; every entry the action or any run wrote carries the action's root, a
	 * query by that root returns exactly those entries, and B's own entries are found by B's id.
	 */
	@IsTest
	private static void shouldKeepTheActionsRootThroughThreeLevelsOfLaunches()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			String actionCorrelationId = LOG_Builder.startCorrelation();

			Test.startTest();
			String executionIdA = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new NestedLaunchingStep()).withAsyncOptions(createAsyncOptions(3)).execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			List<AsyncChainExecution__c> line = followTheLineOfLaunches(executionIdA);
			Assert.areEqual(3, line.size(), 'A, B and C exist');
			AsyncChainExecution__c runA = line[0];
			AsyncChainExecution__c runB = line[1];
			AsyncChainExecution__c runC = line[2];
			Assert.areEqual(actionCorrelationId, runA.LaunchCorrelationId__c, 'A was launched under the action');
			Assert.areEqual(runA.CorrelationId__c, runB.LaunchCorrelationId__c, 'B was launched under A');
			Assert.areEqual(runB.CorrelationId__c, runC.LaunchCorrelationId__c, 'C was launched under B');
			Integer completions = 0;
			Integer entriesByRoot = 0;
			for(Integer depth = 0; depth < line.size(); depth++)
			{
				AsyncChainExecution__c run = line[depth];
				Assert.areEqual(actionCorrelationId, run.RootCorrelationId__c, 'Every run keeps the action as its root');
				Assert.areEqual(depth, parseContextData(run).get(NESTING_DEPTH_KEY_NAME), 'Each run carries its depth below the first');
				completions += findLogEntriesAt(run.Id, COMPLETION_SITE).size();
				List<LogEntry__c> runEntries = findLogEntriesOfRun(run.CorrelationId__c);
				assertEntriesCarryRoot(runEntries, actionCorrelationId, 'Every entry of every run carries the action as its root');
				entriesByRoot += runEntries.size();
			}
			Assert.areEqual(3, completions, 'All three runs complete and log it');
			Assert.isTrue(entriesByRoot >= 3, 'A, B and C each wrote entries carrying the action as their root');
			List<LogEntry__c> actionsOwnEntries = findLogEntriesOfRun(actionCorrelationId);
			assertEntriesCarryRoot(actionsOwnEntries, actionCorrelationId, 'The action\'s own entries carry the action as their root');
			Assert.areEqual(entriesByRoot + actionsOwnEntries.size(), findLogEntriesByRoot(actionCorrelationId).size(),
					'A query by the action\'s root returns exactly the entries of the action and of A, B and C');
			Assert.isTrue(findLogEntriesOfRun(runB.CorrelationId__c).size() >= 1, 'B\'s own entries are found by B\'s id');
		}
	}

	/**
	 * @description A step's launch is refused before anything is written when the chain of jobs the launching job
	 * belongs to has no spare Queueable stack level for the child's first job. The parent ends Failed with the
	 * stack-depth refusal naming it, and no child run exists.
	 */
	@IsTest
	private static void shouldRefuseAStepLaunchWhenTheLineageHasNoSpareLevel()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.startCorrelation();

			Test.startTest();
			String parentExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new LaunchingStep())
					.withAsyncOptions(createAsyncOptions(1))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c parent = queryExecution(parentExecutionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, parent.Status__c, 'The launching step fails on the refusal');
			Assert.isTrue(parent.ErrorMessage__c.contains(STACK_REFUSAL_FRAGMENT), 'The refusal says no level was left: ' + parent.ErrorMessage__c);
			Assert.isTrue(parent.ErrorMessage__c.contains(parentExecutionId), 'The refusal names the launching run: ' + parent.ErrorMessage__c);
			AsyncChainExecution__c childUnderTheLaunchKey = new SEL_AsyncChainExecution().findByDeclaredDeduplicationKey(parentExecutionId + FIRST_STEP_LAUNCH_KEY_SUFFIX);
			Assert.isNull(childUnderTheLaunchKey, 'No child run was written under the launch key');
			Assert.areEqual(0, new SEL_AsyncChainExecution().findByChainName(CHILD_CHAIN_NAME).size(), 'No child run exists');
		}
	}

	/**
	 * @description A line of chains each launching the next stops at the framework's nesting limit: five runs sit below
	 * the first, each carrying its depth in its context, and the sixth launch is refused with the nesting message before
	 * anything is written, so the deepest run ends Failed with no child.
	 */
	@IsTest
	private static void shouldRefuseAStepLaunchBeyondTheNestingLimit()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.startCorrelation();

			Test.startTest();
			String firstExecutionId = UTIL_AsyncChain.newChain(NESTED_CHAIN_NAME)
					.then(new SelfLaunchingStep())
					.withAsyncOptions(createAsyncOptions(MAXIMUM_NESTING_DEPTH + 2))
					.execute();
			Test.stopTest();

			List<AsyncChainExecution__c> line = followTheLineOfLaunches(firstExecutionId);
			Assert.areEqual(MAXIMUM_NESTING_DEPTH + 1, line.size(), 'The first chain and five below it exist, and no sixth');
			for(Integer depth = 0; depth <= MAXIMUM_NESTING_DEPTH; depth++)
			{
				Assert.areEqual(depth, parseContextData(line[depth]).get(NESTING_DEPTH_KEY_NAME), 'Each run carries its depth below the first');
			}
			AsyncChainExecution__c deepest = line[MAXIMUM_NESTING_DEPTH];
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, deepest.Status__c, 'The deepest run\'s launch is refused');
			Assert.isTrue(deepest.ErrorMessage__c.contains(NESTING_REFUSAL_FRAGMENT), 'The refusal names the limit: ' + deepest.ErrorMessage__c);
			Integer nestedRuns = new SEL_AsyncChainExecution().findByChainName(NESTED_CHAIN_NAME).size();
			Assert.areEqual(MAXIMUM_NESTING_DEPTH + 1, nestedRuns, 'Six runs in all, none written for the refused launch');
		}
	}

	/**
	 * @description A step may launch a child with a delay: the delay overload is accepted inside a running job, and the
	 * child's record carries the parent as its launch id and the action as its root.
	 */
	@IsTest
	private static void shouldLaunchAChildWithADelayFromAStep()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			String actionCorrelationId = LOG_Builder.startCorrelation();

			Test.startTest();
			String parentExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new DelayedLaunchingStep()).withAsyncOptions(createAsyncOptions(3)).execute();
			Test.stopTest();

			AsyncChainExecution__c parent = queryExecution(parentExecutionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, parent.Status__c, 'The parent completes: ' + parent.ErrorMessage__c);
			AsyncChainExecution__c child = queryExecution((String)parseContextData(parent).get(CHILD_EXECUTION_KEY));
			Assert.areEqual(parent.CorrelationId__c, child.LaunchCorrelationId__c, 'The child was launched under the parent run');
			Assert.areEqual(actionCorrelationId, child.RootCorrelationId__c, 'The child keeps the action as its root');
		}
	}

	/**
	 * @description A launch is a side effect that outlives the step: a step that launches a child and then fails leaves
	 * the child to run to completion while its own run ends Failed.
	 */
	@IsTest
	private static void shouldKeepTheChildWhenTheLaunchingStepFailsAfterwards()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.startCorrelation();

			Test.startTest();
			String parentExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new LaunchThenFailStep()).withAsyncOptions(createAsyncOptions(3)).execute();
			Test.stopTest();

			AsyncChainExecution__c parent = queryExecution(parentExecutionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, parent.Status__c, 'The launching step failed after the launch');
			List<AsyncChainExecution__c> children = new SEL_AsyncChainExecution().findByChainName(CHILD_CHAIN_NAME);
			Assert.areEqual(1, children.size(), 'The child exists');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, children[0].Status__c, 'The child ran to completion: ' + children[0].ErrorMessage__c);
			Assert.areEqual(parent.CorrelationId__c, children[0].LaunchCorrelationId__c, 'The child was launched under the parent run');
		}
	}

	/**
	 * @description A retried step gets the child it already launched, not a second one: one child exists, keyed by the
	 * parent run and the step's position, announced once, and the retry stores the same id.
	 */
	@IsTest
	private static void shouldLaunchTheChildOnceWhenTheLaunchingStepIsRetried()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			LOG_Builder.startCorrelation();

			Test.startTest();
			String parentExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new LaunchThenFailOnceStep()).withAsyncOptions(createAsyncOptions(3)).execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c parent = queryExecution(parentExecutionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, parent.Status__c, 'The retry succeeds: ' + parent.ErrorMessage__c);
			List<AsyncChainExecution__c> children = new SEL_AsyncChainExecution().findByChainName(CHILD_CHAIN_NAME);
			Assert.areEqual(1, children.size(), 'The retry launched no second child');
			Assert.areEqual(parentExecutionId + FIRST_STEP_LAUNCH_KEY_SUFFIX, children[0].DeclaredDeduplicationKey__c, 'The child is keyed by the parent run and the step');
			Assert.areEqual(children[0].Id, parseContextData(parent).get(CHILD_EXECUTION_KEY), 'The retry received the id of the child already launched');
			Assert.areEqual(1, findLogEntriesAt(children[0].Id, LAUNCH_ANNOUNCEMENT_SITE).size(), 'The launch is announced once');
		}
	}

	/**
	 * @description The framework default stack depth reserves room for nested launches: with no caller options at all,
	 * an action launches run A, whose step launches run B, whose step launches run C, and all three complete.
	 */
	@IsTest
	private static void shouldReserveRoomForNestedLaunchesInTheDefaultCap()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.startCorrelation();

			Test.startTest();
			String executionIdA = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new NestedLaunchingStep()).execute();
			Test.stopTest();

			List<AsyncChainExecution__c> line = followTheLineOfLaunches(executionIdA);
			Assert.areEqual(3, line.size(), 'A, B and C exist');
			for(AsyncChainExecution__c run : line)
			{
				Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, run.Status__c, 'Every run completes: ' + run.ErrorMessage__c);
			}
		}
	}

	/**
	 * @description A chain launched from inside a Queueable that is not a chain job (a job on the job runner) is
	 * accepted: it takes the top-level path, the platform lets it start, and the run carries the job id of its first
	 * job. That acceptance is what this test proves. The stack-depth cap such a chain sets for itself, worked out
	 * from the depth the launching job runs at so the chain keeps all its room, is not something a test can read
	 * back. So the arithmetic behind it rests on a measurement made in an org on 13 September 2026.
	 */
	@IsTest
	private static void shouldAcceptAChainLaunchedFromInsideAnyQueueable()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.startCorrelation();

			Test.startTest();
			System.enqueueJob(new ChainLaunchingQueueable());
			Test.stopTest();

			Assert.isNotNull(chainLaunchedFromQueueable, 'the chain was launched from inside the Queueable');
			AsyncChainExecution__c launched = queryExecution(chainLaunchedFromQueueable);
			Assert.isTrue(ACCEPTED_LAUNCH_STATUSES.contains(launched.Status__c), 'the launch was accepted: ' + launched.Status__c + ' ' + launched.ErrorMessage__c);
			Assert.isNotNull(launched.CurrentJobId__c, 'the first job was queued and its job id saved on the run');
		}
	}

	/**
	 * @description A chain launched from inside a Queueable that was queued with its own maximum stack depth is
	 * accepted. The platform does not let a job inside such a line of jobs set a new maximum. So the chain's first job
	 * is queued without options and runs under the maximum the line already has, and the run carries its job id. The chain
	 * has two steps, so this also proves the second job: it is queued with options that carry a maximum, while the line
	 * of jobs already has a different maximum, and the platform accepts it (a refused job would leave the run Stalled).
	 */
	@IsTest
	private static void shouldAcceptAChainLaunchedFromInsideAQueueableThatHasAMaximumDepth()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			System.enqueueJob(new ChainLaunchingQueueable(TWO_STEPS), createAsyncOptions(CUSTOM_STACK_DEPTH));
			Test.stopTest();

			Assert.isNotNull(chainLaunchedFromQueueable, 'Expected the chain to be launched from inside the Queueable');
			AsyncChainExecution__c launched = queryExecution(chainLaunchedFromQueueable);
			Assert.isTrue(ACCEPTED_LAUNCH_STATUSES.contains(launched.Status__c), 'Expected the launch to be accepted: ' + launched.Status__c + ' ' + launched.ErrorMessage__c);
			Assert.isNotNull(launched.CurrentJobId__c, 'Expected the first job to be queued and its job id saved on the run');
		}
	}

	/**
	 * @description A launch from inside a Queueable whose line of jobs is already at its maximum stack depth is refused
	 * before the run record is saved. The chain's first job could never be queued, so no Running run is left without a job.
	 */
	@IsTest
	private static void shouldRefuseALaunchFromAQueueableWithNoSpareStackLevel()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			System.enqueueJob(new RefusedLaunchQueueable(null), createAsyncOptions(FULL_LINE_STACK_DEPTH));
			Test.stopTest();

			Assert.isInstanceOfType(launchRefusalFromQueueable, UTIL_Exceptions.IllegalStateException.class, 'Expected the launch to be refused: ' + launchRefusalFromQueueable);
			Assert.isTrue(launchRefusalFromQueueable.getMessage().contains(STACK_DEPTH_REFUSAL_FRAGMENT), 'Expected the refusal to name the stack depth: '
					+ launchRefusalFromQueueable.getMessage());
			Assert.isNull(new SEL_AsyncChainExecution().findByCorrelationId(REFUSED_LAUNCH_CORRELATION_ID), 'Expected no run record for the refused launch');
		}
	}

	/**
	 * @description A launch from inside a Queueable that already added its one queueable job is refused before the run
	 * record is saved. The platform would refuse the chain's first job, so the refusal comes first and leaves no run behind.
	 */
	@IsTest
	private static void shouldRefuseALaunchFromAQueueableThatAlreadyAddedItsJob()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			System.enqueueJob(new RefusedLaunchQueueable(new IdleJob()));
			Test.stopTest();

			Assert.isInstanceOfType(launchRefusalFromQueueable, UTIL_Exceptions.IllegalStateException.class, 'Expected the launch to be refused: ' + launchRefusalFromQueueable);
			Assert.isTrue(launchRefusalFromQueueable.getMessage().contains(ENQUEUE_USED_REFUSAL_FRAGMENT), 'Expected the refusal to name the used job: '
					+ launchRefusalFromQueueable.getMessage());
			Assert.isNull(new SEL_AsyncChainExecution().findByCorrelationId(REFUSED_LAUNCH_CORRELATION_ID), 'Expected no run record for the refused launch');
		}
	}

	/**
	 * @description A chain step inserts a record, and the record's trigger launches a second chain with no options. Inside
	 * a trigger fired by a queueable job's own save, the platform refuses to tell the framework the job's queueable stack
	 * depth. A job queued from there starts a new line of jobs (the jobs started one from another) at depth 1. So the
	 * launch must not ask for the depth of the step's line: the child chain starts, is recorded as launched under the
	 * step's run, gets its first job, and runs to the end.
	 */
	@IsTest
	private static void shouldStartAChainLaunchedFromATriggerFiredByAChainStep()
	{
		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c child = runAChainWhoseStepTriggerLaunchesAChain();
			Assert.isNotNull(child.CurrentJobId__c, 'Expected the first job of the chain launched from the trigger to be queued');
			Assert.areEqual(DEFAULT_TRIGGER_CHAIN_STACK_DEPTH, parseContextData(child).get(MAXIMUM_STACK_DEPTH_KEY),
					'Expected the chain to run under the framework default maximum for a new line of jobs');
		}
	}

	/**
	 * @description A chain step inserts a record, and the record's trigger launches a second chain with options of its
	 * own. Inside that trigger the platform refuses to tell the framework the step job's queueable stack depth, and a
	 * job queued from there starts a new line of jobs. So the child chain does not run under the maximum of the step's
	 * line: its first job is queued with the caller's options and runs under the caller's maximum. The child still sits
	 * one level below the step's run and runs to the end.
	 */
	@IsTest
	private static void shouldUseTheCallersOptionsForAChainLaunchedFromATriggerFiredByAChainStep()
	{
		System.runAs(getTestAdmin())
		{
			triggerLaunchOptions = createAsyncOptions(CALLER_MAXIMUM_STACK_DEPTH);

			AsyncChainExecution__c child = runAChainWhoseStepTriggerLaunchesAChain();
			Assert.areEqual(CALLER_MAXIMUM_STACK_DEPTH, parseContextData(child).get(MAXIMUM_STACK_DEPTH_KEY), 'Expected the chain to run under the caller\'s maximum stack depth');
		}
	}

	/**
	 * @description A plain queueable job, not a chain job, inserts a record, and the record's trigger launches a chain
	 * with no options. Inside that trigger the platform refuses to tell the framework the job's queueable stack depth.
	 * The launch then counts from depth 0, as the platform does for a job queued from there, and the chain starts and
	 * runs to the end.
	 */
	@IsTest
	private static void shouldStartAChainLaunchedFromATriggerFiredByAQueueable()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerFoobarTriggerWithChainLaunchingAction();

			Test.startTest();
			System.enqueueJob(new RecordInsertingQueueable());
			Test.stopTest();

			Assert.isNull(launchRefusalFromTrigger, 'Expected the launch from the trigger to be accepted: ' + launchRefusalFromTrigger);
			Assert.isNotNull(chainLaunchedFromTrigger, 'Expected the trigger to launch the chain');
			AsyncChainExecution__c launched = queryExecution(chainLaunchedFromTrigger);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, launched.Status__c, 'Expected the chain launched from the trigger to complete: ' + launched.ErrorMessage__c);
			Assert.isNotNull(launched.CurrentJobId__c, 'Expected the first job of the chain launched from the trigger to be queued');
		}
	}

	/**
	 * @description When the platform refuses the chain's first job after the run record was saved, the record is removed
	 * and the platform's own exception reaches the caller. Here the platform refuses a second job with the same duplicate
	 * signature. A caller that catches the exception and goes on must not keep a Running run that has no job.
	 */
	@IsTest
	private static void shouldLeaveNoRunWhenThePlatformRefusesTheFirstJob()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncOptions options = createAsyncOptions(CUSTOM_STACK_DEPTH);
			options.duplicateSignature = QueueableDuplicateSignature.builder().addId(UserInfo.getUserId()).build();

			Test.startTest();
			String acceptedExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).withAsyncOptions(options).execute();
			try
			{
				UTIL_AsyncChain.newChain(CHILD_CHAIN_NAME).then(new SuccessStep()).withAsyncOptions(options).execute(REFUSED_LAUNCH_CORRELATION_ID);
				Assert.fail('Expected the platform to refuse a second job with the same duplicate signature');
			}
			catch(Exception refusal)
			{
				Assert.isInstanceOfType(refusal, DuplicateMessageException.class, 'Expected the platform exception itself to reach the caller: ' + refusal);
			}
			Test.stopTest();

			Assert.isNull(new SEL_AsyncChainExecution().findByCorrelationId(REFUSED_LAUNCH_CORRELATION_ID), 'Expected no run record for the refused launch');
			Assert.isNotNull(queryExecution(acceptedExecutionId).CurrentJobId__c, 'Expected the first launch to keep its run and its job');
		}
	}

	/**
	 * @description A completion handler runs inside the chain's jobs and may launch one chain the way a step does: the
	 * child is keyed by the run and the handler, launched under the run's id with the action as its root.
	 */
	@IsTest
	private static void shouldLaunchAChildFromACompletionHandler()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			String actionCorrelationId = LOG_Builder.startCorrelation();

			Test.startTest();
			String parentExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.onComplete(new LaunchingStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c parent = queryExecution(parentExecutionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, parent.Status__c, 'The chain and its handler complete: ' + parent.ErrorMessage__c);
			AsyncChainExecution__c child = new SEL_AsyncChainExecution().findByDeclaredDeduplicationKey(parentExecutionId + COMPLETION_HANDLER_LAUNCH_KEY_SUFFIX);
			Assert.isNotNull(child, 'The handler\'s launch is keyed by the run and the completion handler');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, child.Status__c, 'The child ran to completion under the handler\'s cap: ' + child.ErrorMessage__c);
			Assert.areEqual(parent.CorrelationId__c, child.LaunchCorrelationId__c, 'The child was launched under the run');
			Assert.areEqual(actionCorrelationId, child.RootCorrelationId__c, 'The child keeps the action as its root');
		}
	}

	/**
	 * @description A terminally failed run's error handler launches a chain of its own, keyed by the run and the error
	 * handler, and the completion handler's key stays free, so a completion handler that runs later gets a chain of its
	 * own rather than the error handler's.
	 */
	@IsTest
	private static void shouldLaunchAChildFromAnErrorHandler()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			String actionCorrelationId = LOG_Builder.startCorrelation();

			Test.startTest();
			String parentExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new FailingStep())
					.onError(new LaunchingStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c parent = queryExecution(parentExecutionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, parent.Status__c, 'The chain fails and its error handler runs: ' + parent.ErrorMessage__c);
			AsyncChainExecution__c child = new SEL_AsyncChainExecution().findByDeclaredDeduplicationKey(parentExecutionId + ERROR_HANDLER_LAUNCH_KEY_SUFFIX);
			Assert.isNotNull(child, 'The error handler\'s launch is keyed by the run and the error handler');
			Assert.isNull(new SEL_AsyncChainExecution().findByDeclaredDeduplicationKey(parentExecutionId + COMPLETION_HANDLER_LAUNCH_KEY_SUFFIX),
					'The completion handler\'s key stays free for a chain of its own');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, child.Status__c, 'The child ran to completion under the handler\'s cap: ' + child.ErrorMessage__c);
			Assert.areEqual(parent.CorrelationId__c, child.LaunchCorrelationId__c, 'The child was launched under the run');
			Assert.areEqual(actionCorrelationId, child.RootCorrelationId__c, 'The child keeps the action as its root');
		}
	}

	/**
	 * @description A step may launch one chain: a second launch of a different chain from the same step is refused
	 * with a message naming both chains, before anything is written, rather than answered with the first child's id.
	 */
	@IsTest
	private static void shouldRefuseASecondChainFromTheSameStep()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.startCorrelation();

			Test.startTest();
			String parentExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new TwiceLaunchingStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c parent = queryExecution(parentExecutionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, parent.Status__c, 'The second launch fails the step');
			Assert.isTrue(parent.ErrorMessage__c.contains(SECOND_LAUNCH_FRAGMENT), 'The refusal states the one-launch rule: ' + parent.ErrorMessage__c);
			Assert.isTrue(parent.ErrorMessage__c.contains(CHILD_CHAIN_NAME), 'The refusal names the chain already launched: ' + parent.ErrorMessage__c);
			Assert.areEqual(1, new SEL_AsyncChainExecution().findByChainName(CHILD_CHAIN_NAME).size(), 'The first child exists once');
			Assert.areEqual(0, new SEL_AsyncChainExecution().findByChainName(NESTED_CHAIN_NAME).size(), 'The second chain was never written');
		}
	}

	/**
	 * @description A step may launch one chain each time it runs: a second launch of the same chain from the same step
	 * in the same transaction is refused, naming the run already launched, rather than answered with that run's id
	 * while the second launch's work never runs.
	 */
	@IsTest
	private static void shouldRefuseASecondLaunchOfTheSameChainFromOneStep()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.startCorrelation();

			Test.startTest();
			String parentExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SameChainTwiceStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c parent = queryExecution(parentExecutionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, parent.Status__c, 'The second launch fails the step');
			Assert.isTrue(parent.ErrorMessage__c.contains(SECOND_LAUNCH_FRAGMENT), 'The refusal states the one-launch rule: ' + parent.ErrorMessage__c);
			List<AsyncChainExecution__c> children = new SEL_AsyncChainExecution().findByChainName(CHILD_CHAIN_NAME);
			Assert.areEqual(1, children.size(), 'The first child exists once and the second was never written');
			Assert.isTrue(parent.ErrorMessage__c.contains(children[0].Id), 'The refusal names the run already launched: ' + parent.ErrorMessage__c);
		}
	}

	/**
	 * @description A step that has already added its one queueable job cannot launch a chain: the launch is refused
	 * before anything is written, so no run record is left Running with no job behind it.
	 */
	@IsTest
	private static void shouldRefuseALaunchAfterTheStepAddedItsOwnJob()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.startCorrelation();

			Test.startTest();
			String parentExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new AddJobThenLaunchStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c parent = queryExecution(parentExecutionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, parent.Status__c, 'The launch fails the step');
			Assert.isTrue(parent.ErrorMessage__c.contains(ENQUEUE_USED_FRAGMENT), 'The refusal names the job already added: ' + parent.ErrorMessage__c);
			Assert.areEqual(0, new SEL_AsyncChainExecution().findByChainName(CHILD_CHAIN_NAME).size(), 'No run record was written for the refused chain');
		}
	}

	/**
	 * @description A second launch that carries the same deduplication key lands on the running chain instead of
	 * starting one, so the first launch's announcement stays the only one: an announcement must never claim a chain
	 * that was never started.
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
			Assert.areEqual(1, findLogEntriesAt(firstExecutionId, LAUNCH_ANNOUNCEMENT_SITE).size(),
					'The first launch is announced once; the launch that landed on the running chain adds nothing');
		}
	}

	/**
	 * @description Reusing one correlation for two chains in the same transaction is refused with a
	 * message naming the correlation, the run already holding it, and how to fix it, not with a raw
	 * duplicate-value database error. It also checks that a clash on the correlation is never taken for
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
	 * @description A correlation held by a run an earlier transaction launched is refused with a message naming that
	 * run, because the caller can see it, beside the correlation and how to fix it, rather than showing a database
	 * error.
	 */
	@IsTest
	private static void shouldNameTheHolderWhenACorrelationIsHeldByAnEarlierTransaction()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			String propagatedCorrelationId = UTIL_Random.randomUUID();
			AsyncChainExecution__c holder = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
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
				Assert.isTrue(refusal.getMessage().contains(holder.Id), 'The refusal names the run already holding it: ' + refusal.getMessage());
				Assert.isTrue(refusal.getMessage().contains(CORRELATION_REMEDY_FRAGMENT),
						'The refusal must spell out the remedy: ' + refusal.getMessage());
			}
			Test.stopTest();
		}
	}

	/**
	 * @description A caller who cannot see the run holding a correlation is refused without that run being named: the
	 * refusal states the correlation and how to fix it, and names no record the caller's sharing hides.
	 */
	@IsTest
	private static void shouldNotNameAHolderTheCallerCannotSee()
	{
		String heldCorrelationId = UTIL_Random.randomUUID();
		AsyncChainExecution__c holder;
		System.runAs(getTestAdmin())
		{
			holder = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.CorrelationId__c => heldCorrelationId
			});
		}

		System.runAs(getLowPrivilegeUser())
		{
			setupEnabledFeatureFlag();
			Test.startTest();
			try
			{
				UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute(heldCorrelationId);
				Assert.fail('A chain reusing a correlation attached elsewhere must be refused');
			}
			catch(UTIL_Exceptions.IllegalStateException refusal)
			{
				Assert.isTrue(refusal.getMessage().contains(heldCorrelationId), 'The refusal must name the correlation: ' + refusal.getMessage());
				Assert.isTrue(refusal.getMessage().contains(UNNAMED_HOLDER_FRAGMENT), 'The refusal names no run the caller cannot see: ' + refusal.getMessage());
				Assert.isFalse(refusal.getMessage().contains(holder.Id), 'The hidden run\'s id never leaks: ' + refusal.getMessage());
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
	 * the caller as the platform reported it. Calling an unrelated save failure a clash on the
	 * correlation would send a subscriber looking for the wrong problem. Oversizing the
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
	 * @description A completed chain emits exactly one guarded INFO end-of-chain log entry naming
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
					'Completion should emit exactly one INFO end-of-chain log entry naming its site');
		}
	}

	/**
	 * @description A chain failed by a step's failed StepResult emits exactly one guarded ERROR
	 * end-of-chain log entry naming handleStepFailure.
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
					'Step failure should emit exactly one ERROR end-of-chain log entry naming its site');
		}
	}

	/**
	 * @description A chain failed by context overflow emits exactly one guarded ERROR end-of-chain
	 * log entry naming markFailed.
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
					'Context overflow should emit exactly one ERROR end-of-chain log entry naming its site');
		}
	}

	/**
	 * @description A zero-step chain, which completes synchronously inside ChainBuilder.execute,
	 * emits exactly one guarded INFO end-of-chain log entry naming that site.
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
					'Zero-step completion should emit exactly one INFO end-of-chain log entry naming its site');
		}
	}

	/**
	 * @description With the log threshold configured above INFO, a completed chain emits no
	 * completion log entry of any level, while the chain itself completes normally. The INFO
	 * entry follows the configured threshold.
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
					'Expected no completion log entry of any level to be saved below the configured threshold');
		}
	}

	/**
	 * @description With the log threshold configured at ERROR, a failed chain still emits its
	 * ERROR log entry for its end. An ERROR entry always passes this threshold.
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
					'Expected the ERROR end-of-chain log entry to pass an ERROR-level threshold');
		}
	}

	/**
	 * @description A chain that completes through a successful completion handler emits exactly one
	 * guarded INFO log entry for its end, at handleChainCompletion, and nothing when the handler's result is saved
	 * back to the run. That save logs nothing on success, on purpose, so the completion is logged only once.
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
					'Completion with a handler should emit exactly one INFO end-of-chain log entry at handleChainCompletion');
			Assert.areEqual(0, countTerminalLogs(executionId, 'HandlerExecutor.execute', null),
					'Saving the successful handler\'s result should log no end-of-chain entry of any level');
		}
	}

	/**
	 * @description A chain whose completion handler returns a failed StepResult is escalated to
	 * Failed and emits exactly one guarded ERROR end-of-chain log entry at HandlerExecutor.execute,
	 * strictly after the save that moves the chain to Failed.
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
					'The handler escalation should emit exactly one ERROR end-of-chain log entry naming its site');
		}
	}

	/**
	 * @description A crashed completion handler is escalated to Failed by the Finalizer, which
	 * emits exactly one guarded ERROR log entry for the chain's end, at HandlerExecutor.Finalizer, strictly after
	 * its recovery save.
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
					'The handler-crash escalation should emit exactly one ERROR end-of-chain log entry naming its site');
		}
	}

	/**
	 * @description When the chain's own work uses up the DML limit, the final save of the run still
	 * commits. Whether the log entry is still sent in that case is up to the logging engine (see
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
					'Expected the final save to commit even with the DML limit used up');
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
					.withInitialContext('padding', 'x'.repeat(CONTEXT_WARNING_PADDING_LENGTH))
					.withMaxContextSize(CONTEXT_WARNING_LIMIT)
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
	 * @description Verifies that the job exits gracefully when the execution record is deleted externally.
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
	 * @description The builder must save each step's idempotency declaration (whether the step is safe to run twice)
	 * into the step log at build time. It is true for a step whose author declared isIdempotent, and null for a step
	 * that declares nothing. A null value is left out of the JSON and means false, so ordinary step logs stay exactly
	 * the same size.
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
			Assert.isNull(entries[1].isIdempotent, 'A step that declares nothing must stay null, so it is left out of the JSON and means false');
		}
	}

	/**
	 * @description An isIdempotent() override that answers null must read as undeclared: the builder
	 * saves no marker, so the retry check keeps the step closed exactly as for a step that never
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
	 * @description A chain built with allowRestart() must set AllowRestart__c on the run record at insert. Beside it,
	 * it must save a copy of the initial context as the chain was built. A restart starts again from that copy, never
	 * from the context the running steps change afterwards.
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
			Assert.isTrue(String.isNotBlank(row.InitialContextData__c), 'The copy of the initial context must be saved for chains that allow a restart');
			Assert.isTrue(row.InitialContextData__c.contains(RESTART_SEED_VALUE), 'The copy must be the context as the chain was built');
			Assert.isFalse(row.InitialContextData__c.contains(EVOLVED_CONTEXT_KEY), 'The copy must never take in keys the running steps wrote after the build');
			Assert.isTrue(row.ContextData__c.contains(EVOLVED_CONTEXT_KEY), 'Control: the running context does carry the key the step wrote, which the copy must not have');
		}
	}

	/**
	 * @description A chain built without allowRestart() must keep the default false declaration and
	 * store no copy of the initial context. That second long-text copy is stored only when a chain asks for it.
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
			Assert.isNull(row.InitialContextData__c, 'No copy for chains that do not allow a restart: it is stored only on request');
			Assert.isNull(row.DeclaredDeduplicationKey__c, 'A chain without a key must set no declared key');
		}
	}

	/**
	 * @description A step that returns failedPermanently must save its permanent-failure marker into the failed entry
	 * of the final step log. Then a later retry check can read from the record that the failure is final, instead of
	 * working it out again.
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
			Assert.areEqual(true, entries[0].permanentFailure, 'A final failure declared permanent must save its marker');
		}
	}

	/**
	 * @description A permanent failure on a continueOnError step must NOT save the permanent-failure marker. The chain
	 * goes on, so the failure does not end it, and the marker is saved only with a failure that ends the chain. The
	 * test checks that the marker is set only in that code path: moving it above the continueOnError check would mark
	 * failures the chain went past, with no warning.
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
			Assert.areEqual(false, entries[0].success, 'Control: the step the chain went past really failed');
			Assert.isNull(entries[0].permanentFailure, 'A permanent failure the chain went past must not carry the marker');
		}
	}

	/**
	 * @description A chain built with withDeduplicationKey must keep the declared key on the record
	 * after the run ends. The active key is released when the run ends. The declared key stays, so a retry or a restart
	 * can take it again.
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
			Assert.areEqual(DECLARED_DEDUPLICATION_KEY, row.DeclaredDeduplicationKey__c, 'The declared key must stay after the run ends');
			Assert.isNull(row.ActiveDeduplicationKey__c, 'Control: the active key must release at completion while the declared key stays');
		}
	}

	/**
	 * @description Checks the size of the saved step log. An ordinary chain of steps that declare nothing must save an
	 * insert-time StepLog__c in which each entry carries exactly its className. The first step also carries
	 * the start the launch records before its enqueue. The declaration markers are left out when null, so
	 * absent markers add zero bytes. This keeps upgrades safe: step logs saved before the declaration
	 * markers existed and step logs written now differ by that one recorded start and nothing else.
	 */
	@IsTest
	private static void shouldKeepHealthyStepLogInsertSizeToClassNamesAndTheFirstStepsStart()
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
			Integer expectedLength = 2 * (entries[0].className.length() + HEALTHY_STEP_ENTRY_JSON_OVERHEAD) + HEALTHY_STEP_LIST_JSON_OVERHEAD + FIRST_STEP_START_JSON_LENGTH;
			Assert.areEqual(expectedLength, inserted.StepLog__c.length(),
					'Expected a healthy step log to carry only its class names and the first step\'s recorded start, got ' + inserted.StepLog__c);
			Assert.areEqual(true, entries[0].started, 'Expected the launch to record the first step\'s start in the insert, got ' + entries[0].started);
			Assert.isNull(entries[1].started, 'Expected no start on a step whose job has not been queued, got ' + entries[1].started);
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
	 * @description Reads an AsyncChainExecution__c row through the restart read of the real code, the same selector
	 * method restartChainFromStart uses. So the tests that call it prove that the code that uses the builder's saved
	 * fields can reach them, not only that they are in the database.
	 *
	 * @param executionId The execution record ID.
	 *
	 * @return The execution record with the fields the retry and restart checks read, and the copy of the starting data.
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
	 * AsyncOptions. It calls no withAsyncOptions on purpose, so the depth used is the one execute() works out (step
	 * count plus one plus the levels kept for nested chains), not one the test supplies.
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
	 * @description Counts saved LogEntry__c rows whose RecordId__c names the given execution, whose ClassMethod__c ends
	 * with the suffix of the given method, and (when a level is given) whose LogLevel__c matches. So every test of an
	 * end-of-chain log entry checks the entry's log level, not only the method that logged it.
	 * The method suffix is part of the check on purpose. Subscribers see ClassMethod__c: it is a Log Console column, and
	 * the runbook searches for it when it looks into a problem. So a rename that changes it SHOULD fail these tests.
	 * Counting by method, over the getAll() read the file already uses, keeps unrelated framework entries from breaking
	 * the tests. The number of log entries in a test stays small (a clean org, and entries are sent only when
	 * ignoreTestMode is set).
	 *
	 * @param executionId The chain execution record the log entry must name.
	 * @param siteMethodSuffix The suffix of the name of the method that logged the entry (for example
	 * 'handleChainCompletion').
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
	 * @description Collects the saved LogEntry__c rows that name the given execution and were logged by the given
	 * method. It is for the tests that check what an entry holds (its level, its correlation, the text a reader sees),
	 * not only how many there are.
	 *
	 * @param executionId The chain execution record the entry must name.
	 * @param siteMethodSuffix The suffix of the name of the method that logged the entry (for example 'announceLaunch').
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
	 * @description Follows a line of launches from the first run down through the child id each launching step stored,
	 * returning the runs from the first to the deepest.
	 *
	 * @param firstExecutionId The first run's record id.
	 *
	 * @return The runs, first to deepest.
	 */
	private static List<AsyncChainExecution__c> followTheLineOfLaunches(String firstExecutionId)
	{
		List<AsyncChainExecution__c> line = new List<AsyncChainExecution__c>();
		String executionId = firstExecutionId;
		while(String.isNotBlank(executionId))
		{
			AsyncChainExecution__c run = queryExecution(executionId);
			line.add(run);
			executionId = (String)parseContextData(run).get(CHILD_EXECUTION_KEY);
		}
		return line;
	}

	/**
	 * @description Collects the saved LogEntry__c rows a run wrote, by the run's own correlation id, with every
	 * field the tests' checks read (the entry selector's read by exact correlation returns fewer fields).
	 *
	 * @param runCorrelationId The run's correlation id.
	 *
	 * @return The run's entries, in the selector's order.
	 */
	private static List<LogEntry__c> findLogEntriesOfRun(String runCorrelationId)
	{
		return findLogEntriesMatching(LogEntry__c.CorrelationId__c, runCorrelationId);
	}

	/**
	 * @description The saved entries carrying the given root correlation id, whichever correlation each was filed
	 * under: the whole action, read with the selector's full field list.
	 *
	 * @param rootCorrelationId The action's correlation id.
	 *
	 * @return The action's entries, in the selector's order.
	 */
	private static List<LogEntry__c> findLogEntriesByRoot(String rootCorrelationId)
	{
		return findLogEntriesMatching(LogEntry__c.RootCorrelationId__c, rootCorrelationId);
	}

	/**
	 * @description The saved entries whose given field holds the given value, read with the selector's full
	 * field list.
	 *
	 * @param field The field to match.
	 * @param value The value to match.
	 *
	 * @return The matching entries, in the selector's order.
	 */
	private static List<LogEntry__c> findLogEntriesMatching(SObjectField field, String value)
	{
		List<LogEntry__c> matches = new List<LogEntry__c>();
		for(LogEntry__c logEntry : new SEL_LogEntry().getAll())
		{
			if((String)logEntry.get(field) == value)
			{
				matches.add(logEntry);
			}
		}
		return matches;
	}

	/**
	 * @description Asserts every entry carries the given root correlation id.
	 *
	 * @param entries The entries to check.
	 * @param rootCorrelationId The expected root.
	 * @param message The assertion message.
	 */
	private static void assertEntriesCarryRoot(List<LogEntry__c> entries, String rootCorrelationId, String message)
	{
		for(LogEntry__c entry : entries)
		{
			Assert.areEqual(rootCorrelationId, entry.RootCorrelationId__c, message);
		}
	}

	/**
	 * @description Asserts a run's launch was logged exactly once in the story of the given correlation (the log
	 * entries filed under that correlation id): an INFO entry under that correlation and root, naming the run's id and
	 * the story's id.
	 *
	 * @param executionId The run whose launch is announced.
	 * @param storyCorrelationId The correlation the announcement is filed under, which is also its root here.
	 */
	private static void assertAnnouncedOnceInTheStory(String executionId, String storyCorrelationId)
	{
		AsyncChainExecution__c run = queryExecution(executionId);
		List<LogEntry__c> announcements = findLogEntriesAt(executionId, LAUNCH_ANNOUNCEMENT_SITE);
		Assert.areEqual(1, announcements.size(), 'Each launch is announced exactly once');
		Assert.areEqual('INFO', announcements[0].LogLevel__c, 'The announcement reports a routine launch, not a problem');
		Assert.areEqual(storyCorrelationId, announcements[0].CorrelationId__c, 'The announcement is filed in the action\'s story, never under the run');
		Assert.areEqual(storyCorrelationId, announcements[0].RootCorrelationId__c, 'The announcement carries the action as its root');
		Assert.isTrue(announcements[0].ShortMessage__c.contains(run.CorrelationId__c), 'The announcement names the id the run is recorded under');
		Assert.isTrue(announcements[0].ShortMessage__c.contains(storyCorrelationId), 'The announcement names the id the run was launched under');
		Assert.isTrue(announcements[0].ShortMessage__c.indexOf(storyCorrelationId) < announcements[0].ShortMessage__c.indexOf(run.CorrelationId__c),
				'The announcement names the id the run was launched under first, then the id it is recorded under: ' + announcements[0].ShortMessage__c);
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
	 * @description Mocks the Foobar__c trigger's setting with one after insert action, ChainLaunchingTriggerAction, so
	 * every Foobar__c record saved in the test launches a chain from the trigger. The action uses no feature flag.
	 */
	private static void registerFoobarTriggerWithChainLaunchingAction()
	{
		String objectName = TRG_Base.resolveSObjectName(new List<SObject> {new Foobar__c()}, null);
		TriggerSetting__mdt setting = TST_Factory.newTriggerSetting(objectName, new Map<SObjectField, Object> {TriggerSetting__mdt.ObjectApiNameOverride__c => objectName});
		TriggerAction__mdt launchingAction = TST_Factory.newTriggerActionForContext(CHAIN_LAUNCHING_TRIGGER_ACTION_CLASS, setting, TriggerOperation.AFTER_INSERT);
		TST_Mock.register(TriggerSetting__mdt.SObjectType, TST_Factory.newTriggerSettingWithActions(setting, new List<TriggerAction__mdt> {launchingAction}));
	}

	/**
	 * @description Runs a one-step chain whose step inserts a Foobar__c record, so the record's trigger launches a second
	 * chain with the options in triggerLaunchOptions. Checks that the launch was accepted and that both chains completed.
	 * Checks too that the second chain is recorded as launched under the first chain's run, sits one level below it, and
	 * is remembered by the step that launched it.
	 *
	 * @return The run record of the chain launched from the trigger.
	 */
	private static AsyncChainExecution__c runAChainWhoseStepTriggerLaunchesAChain()
	{
		setupEnabledFeatureFlag();
		registerFoobarTriggerWithChainLaunchingAction();
		LOG_Builder.startCorrelation();

		Test.startTest();
		String parentExecutionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new RecordInsertingStep()).execute();
		Test.stopTest();

		Assert.isNull(launchRefusalFromTrigger, 'Expected the launch from the trigger to be accepted: ' + launchRefusalFromTrigger);
		Assert.isNotNull(chainLaunchedFromTrigger, 'Expected the trigger to launch the chain');
		AsyncChainExecution__c parent = queryExecution(parentExecutionId);
		Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, parent.Status__c, 'Expected the inserting step to complete: ' + parent.ErrorMessage__c);
		AsyncChainExecution__c child = queryExecution(chainLaunchedFromTrigger);
		Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, child.Status__c, 'Expected the chain launched from the trigger to complete: ' + child.ErrorMessage__c);
		Assert.areEqual(parent.CorrelationId__c, child.LaunchCorrelationId__c, 'Expected the chain to be recorded as launched under the step\'s run');
		Assert.areEqual(1, parseContextData(child).get(NESTING_DEPTH_KEY_NAME), 'Expected the chain to sit one level below the step\'s run');
		Assert.areEqual(parentExecutionId + FIRST_STEP_LAUNCH_KEY_SUFFIX, child.DeclaredDeduplicationKey__c,
				'Expected the chain to be remembered by the step that launched it');
		return child;
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
		/**
		 * @description Increments the stepCount context entry, starting from zero when absent, and succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			Integer count = context.has('stepCount') ? (Integer)context.get('stepCount') : 0;
			context.put('stepCount', count + 1);
			return UTIL_AsyncChain.succeeded('Step completed');
		}
	}

	/**
	 * @description Step that launches a one-step child chain from inside its own run and records the child's execution
	 * id in the context, so a test can read the child's run record and the entries both runs wrote.
	 */
	public class LaunchingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Launches a one-step child chain and stores its execution id under childExecutionId.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result naming the child's execution id.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			String childExecutionId = UTIL_AsyncChain.newChain(CHILD_CHAIN_NAME).then(new SuccessStep()).execute();
			context.put(CHILD_EXECUTION_KEY, childExecutionId);
			return UTIL_AsyncChain.succeeded('Launched ' + childExecutionId);
		}
	}

	/**
	 * @description Step that launches a child chain whose own step launches a grandchild, so a test can follow three
	 * levels of launches from one action. The recovery suite names this class in a seeded step log
	 * (UTIL_AsyncChainRecovery_TEST.NESTED_LAUNCH_STEP_CLASS_NAME), so a rename must follow there.
	 */
	public class NestedLaunchingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Launches a child chain that runs a LaunchingStep and stores the child's execution id under
		 * childExecutionId.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result naming the child's execution id.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			String childExecutionId = UTIL_AsyncChain.newChain(GRANDCHILD_CHAIN_NAME).then(new LaunchingStep()).execute();
			context.put(CHILD_EXECUTION_KEY, childExecutionId);
			return UTIL_AsyncChain.succeeded('Launched ' + childExecutionId);
		}
	}

	/**
	 * @description Step that launches a chain running another step of this kind, so a test can follow a line of launches
	 * down to the framework's nesting limit; the launch that is refused fails the step.
	 */
	public class SelfLaunchingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Launches a one-step chain of the same shape and stores its execution id under childExecutionId.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result naming the child's execution id.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			String childExecutionId = UTIL_AsyncChain.newChain(NESTED_CHAIN_NAME).then(new SelfLaunchingStep()).execute();
			context.put(CHILD_EXECUTION_KEY, childExecutionId);
			return UTIL_AsyncChain.succeeded('Launched ' + childExecutionId);
		}
	}

	/**
	 * @description Step that launches a one-step child chain with a delay, so a test can prove the delay overload is
	 * accepted from inside a running job.
	 */
	public class DelayedLaunchingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Launches a one-step child chain with a one-minute delay and stores its execution id under
		 * childExecutionId.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result naming the child's execution id.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			String childExecutionId = UTIL_AsyncChain.newChain(CHILD_CHAIN_NAME).then(new SuccessStep()).withDelayMinutes(NESTED_LAUNCH_DELAY_MINUTES).execute();
			context.put(CHILD_EXECUTION_KEY, childExecutionId);
			return UTIL_AsyncChain.succeeded('Launched ' + childExecutionId);
		}
	}

	/**
	 * @description Step that launches a one-step child chain and then fails, so a test can prove the launch is a side
	 * effect that outlives the step.
	 */
	public class LaunchThenFailStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Launches a one-step child chain, stores its execution id under childExecutionId, and fails.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A failed result naming the child's execution id.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			String childExecutionId = UTIL_AsyncChain.newChain(CHILD_CHAIN_NAME).then(new SuccessStep()).execute();
			context.put(CHILD_EXECUTION_KEY, childExecutionId);
			return UTIL_AsyncChain.failed('Failed after launching ' + childExecutionId);
		}
	}

	/**
	 * @description Step that launches a one-step child chain, fails on its first attempt and succeeds on its retry, so a
	 * test can prove the retry gets the child already launched rather than a second one.
	 */
	public class LaunchThenFailOnceStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Launches a one-step child chain and stores its execution id under childExecutionId; fails on the
		 * first attempt, succeeds on the retry.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A failed result on the first attempt, a succeeded one afterwards, both naming the child's execution id.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			String childExecutionId = UTIL_AsyncChain.newChain(CHILD_CHAIN_NAME).then(new SuccessStep()).execute();
			context.put(CHILD_EXECUTION_KEY, childExecutionId);
			return context.getAttempt() == 1
					? UTIL_AsyncChain.failed('Failed after launching ' + childExecutionId)
					: UTIL_AsyncChain.succeeded('Launched ' + childExecutionId);
		}

		/**
		 * @description One retry with no backoff, so the retry runs inside the test.
		 *
		 * @return An exponential strategy capped at one retry with a zero base backoff.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return UTIL_Retry.exponential().withMaxRetries(1).withBaseBackoff(0);
		}
	}

	/**
	 * @description Step that launches two different chains from inside its own run, so a test can prove the second
	 * launch is refused rather than answered with the first child's id.
	 */
	public class TwiceLaunchingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Launches a one-step child chain, stores its execution id under childExecutionId, then launches a
		 * second chain of a different name, which the framework refuses.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result naming both children, never reached.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			String firstChildExecutionId = UTIL_AsyncChain.newChain(CHILD_CHAIN_NAME).then(new SuccessStep()).execute();
			context.put(CHILD_EXECUTION_KEY, firstChildExecutionId);
			String secondChildExecutionId = UTIL_AsyncChain.newChain(NESTED_CHAIN_NAME).then(new SuccessStep()).execute();
			return UTIL_AsyncChain.succeeded('Launched ' + firstChildExecutionId + ' and ' + secondChildExecutionId);
		}
	}

	/**
	 * @description Step that launches the same one-step child chain twice from inside its own run, so a test can prove
	 * the second launch is refused rather than answered with the first child's id.
	 */
	public class SameChainTwiceStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Launches the child chain, stores its execution id under childExecutionId, then launches the same
		 * chain again, which the framework refuses.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result naming both launches, never reached.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			String firstLaunchId = UTIL_AsyncChain.newChain(CHILD_CHAIN_NAME).then(new SuccessStep()).execute();
			context.put(CHILD_EXECUTION_KEY, firstLaunchId);
			String secondLaunchId = UTIL_AsyncChain.newChain(CHILD_CHAIN_NAME).then(new SuccessStep()).execute();
			return UTIL_AsyncChain.succeeded('Launched ' + firstLaunchId + ' and ' + secondLaunchId);
		}
	}

	/**
	 * @description Step that adds a queueable job of its own before launching a chain, so a test can prove the launch is
	 * refused before anything is written once the job's one enqueue is used.
	 */
	public class AddJobThenLaunchStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Adds an idle job, then launches a one-step child chain, which the framework refuses.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result naming the child, never reached.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			System.enqueueJob(new IdleJob());
			String childExecutionId = UTIL_AsyncChain.newChain(CHILD_CHAIN_NAME).then(new SuccessStep()).execute();
			return UTIL_AsyncChain.succeeded('Launched ' + childExecutionId);
		}
	}

	/**
	 * @description A queueable job that does nothing, so a step can use up its one enqueue. It attaches itself as its
	 * own Finalizer, the shape every queueable in the package takes.
	 */
	public class IdleJob implements Queueable, Finalizer
	{
		/**
		 * @description Does nothing: the job exists only to use up the running step's one enqueue.
		 *
		 * @param queueableContext The platform's job context.
		 */
		public void execute(QueueableContext queueableContext)
		{
			System.attachFinalizer(this);
		}

		/**
		 * @description Nothing to finish: the job did nothing, so the finalizer only checks in.
		 *
		 * @param finalizerContext The platform's finalizer context.
		 */
		public void execute(FinalizerContext finalizerContext)
		{
			Assert.isNotNull(finalizerContext, 'The platform hands every finalizer its context');
		}
	}

	/**
	 * @description A plain Queueable (not a chain step) whose work is to launch a chain, standing in for a job on the runner.
	 * It attaches no Finalizer: a fixture has nothing to record after it runs.
	 */
	@SuppressWarnings('PMD.QueueableWithoutFinalizer')
	public class ChainLaunchingQueueable implements Queueable
	{
		/**
		 * @description How many steps the launched chain gets: one or two.
		 */
		private final Integer stepCount;

		/**
		 * @description Creates the job so that it launches a one-step chain.
		 */
		public ChainLaunchingQueueable()
		{
			stepCount = 1;
		}

		/**
		 * @description Creates the job and says how many steps the launched chain gets.
		 *
		 * @param stepCount 1 to launch a one-step chain, 2 to launch a two-step chain.
		 */
		public ChainLaunchingQueueable(Integer stepCount)
		{
			this.stepCount = stepCount;
		}

		/**
		 * @description Launches the chain and records its execution id, so the test can read the run record. The chain has
		 * one step, or two when the job was created with the two-step choice.
		 *
		 * @param context The platform's job context.
		 */
		public void execute(QueueableContext context)
		{
			UTIL_AsyncChain.ChainBuilder builder = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep());
			if(stepCount == TWO_STEPS)
			{
				builder = builder.then(new SuccessStep());
			}
			chainLaunchedFromQueueable = builder.execute();
		}
	}

	/**
	 * @description A plain Queueable (not a chain step) that launches a chain the framework is expected to refuse, and
	 * keeps the refusal so the test can check it. It can first add a job of its own, which uses up its one queueable job.
	 * It attaches no Finalizer: a fixture has nothing to record after it runs.
	 */
	@SuppressWarnings('PMD.QueueableWithoutFinalizer')
	public class RefusedLaunchQueueable implements Queueable
	{
		/**
		 * @description The job this job adds before it launches the chain, or null to add none.
		 */
		private final Queueable jobToAddFirst;

		/**
		 * @description Creates the job.
		 *
		 * @param jobToAddFirst The job to add before the launch, or null to add none.
		 */
		public RefusedLaunchQueueable(Queueable jobToAddFirst)
		{
			this.jobToAddFirst = jobToAddFirst;
		}

		/**
		 * @description Adds its own job when it has one, then launches a one-step chain under REFUSED_LAUNCH_CORRELATION_ID
		 * and keeps the exception the launch raised.
		 *
		 * @param context The platform's job context.
		 */
		public void execute(QueueableContext context)
		{
			if(jobToAddFirst != null)
			{
				// In a test the platform refuses a job queued from inside a job unless it carries a maximum stack depth.
				System.enqueueJob(jobToAddFirst, createAsyncOptions(CUSTOM_STACK_DEPTH));
			}
			try
			{
				UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(new SuccessStep()).execute(REFUSED_LAUNCH_CORRELATION_ID);
			}
			catch(Exception refusal)
			{
				launchRefusalFromQueueable = refusal;
			}
		}
	}

	/**
	 * @description Step that inserts one Foobar__c record, so the record's trigger runs inside the chain job.
	 */
	public class RecordInsertingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Inserts one Foobar__c record and succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			TST_Builder.of(Foobar__c.SObjectType).build();
			return UTIL_AsyncChain.succeeded('Inserted a record');
		}
	}

	/**
	 * @description A plain Queueable (not a chain step) that inserts one Foobar__c record, so the record's trigger runs
	 * inside a queueable job that is not a chain job. It attaches no Finalizer: a fixture has nothing to record after it runs.
	 */
	@SuppressWarnings('PMD.QueueableWithoutFinalizer')
	public class RecordInsertingQueueable implements Queueable
	{
		/**
		 * @description Inserts one Foobar__c record.
		 *
		 * @param context The platform's job context.
		 */
		public void execute(QueueableContext context)
		{
			TST_Builder.of(Foobar__c.SObjectType).build();
		}
	}

	/**
	 * @description Step that saves the maximum queueable stack depth of the job it runs in to the chain context, under
	 * MAXIMUM_STACK_DEPTH_KEY, so a test can see which maximum the chain ran under. It saves null when the job has none.
	 */
	public class MaximumStackDepthRecordingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Saves the job's maximum queueable stack depth and succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put(MAXIMUM_STACK_DEPTH_KEY, System.AsyncInfo.hasMaxStackDepth() ? System.AsyncInfo.getMaximumQueueableStackDepth() : null);
			return UTIL_AsyncChain.succeeded('Saved the maximum stack depth');
		}
	}

	/**
	 * @description Test trigger action that launches a one-step chain after Foobar__c records are inserted, with the
	 * options in triggerLaunchOptions (none when it is null). The chain's step saves the maximum stack depth it runs
	 * under. The action keeps the launched run's id, or the exception the launch raised, so the test can check the launch.
	 */
	public class ChainLaunchingTriggerAction implements IF_Trigger.AfterInsert
	{
		/**
		 * @description Launches a one-step chain and keeps its execution id, or keeps the exception the launch raised.
		 *
		 * @param triggerNew The inserted records; unused.
		 */
		public void afterInsert(List<SObject> triggerNew)
		{
			try
			{
				chainLaunchedFromTrigger = UTIL_AsyncChain.newChain(CHILD_CHAIN_NAME)
						.then(new MaximumStackDepthRecordingStep())
						.withAsyncOptions(triggerLaunchOptions)
						.execute();
			}
			catch(Exception refusal)
			{
				launchRefusalFromTrigger = refusal;
			}
		}
	}

	/**
	 * @description Step that succeeds and declares itself safe to execute more than once, so tests
	 * can prove the builder saves the declaration into the step log.
	 */
	public class IdempotentSuccessStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Declares the step safe to run again. A subscriber declares it the same way, with no constructor.
		 *
		 * @return True.
		 */
		public override Boolean isIdempotent()
		{
			return true;
		}

		/**
		 * @description Succeeds without touching the context; the idempotency declaration is the fixture's whole purpose.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A succeeded result.
		 */
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

		/**
		 * @description Succeeds without touching the context; the null idempotency answer is the fixture's whole purpose.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A succeeded result.
		 */
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
		/**
		 * @description Succeeds with a message and the Integer payload 42, so tests can read a step result's data.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A succeeded result carrying the payload 42.
		 */
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
		/**
		 * @description Reads the testKey context entry, stores it under readValue and succeeds with a message naming the value.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result whose message names the value read.
		 */
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
		/**
		 * @description Fails on every call.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed('Deliberate failure');
		}
	}

	/**
	 * @description Step that declares its failure permanent and stops the chain, so the test runs the save of the
	 * permanent-failure marker at the chain's end. It is declared idempotent, so the retry tests can use it too.
	 */
	public class PermanentlyFailingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Declares the step safe to run again, to prove the refusal for a permanent failure wins over the
		 * idempotency declaration.
		 *
		 * @return True.
		 */
		public override Boolean isIdempotent()
		{
			return true;
		}

		/**
		 * @description Declares the failure permanent with PERMANENT_FAILURE_MESSAGE, halting the chain.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A permanently failed result.
		 */
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
		/**
		 * @description Throws an IllegalStateException on every call.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return Never; every call throws instead.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException On every call.
		 */
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
		/**
		 * @description Writes the trackingStepExecuted flag into the context and succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
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
		/**
		 * @description Writes the errorHandlerExecuted flag into the context and succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
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
		/**
		 * @description Writes the completionHandlerExecuted flag into the context and succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
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
		/**
		 * @description Throws an IllegalStateException so the chain's error handler itself fails.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return Never; every call throws instead.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException On every call.
		 */
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
		/**
		 * @description Throws an IllegalStateException so the chain's completion handler itself fails.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return Never; every call throws instead.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException On every call.
		 */
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

		/**
		 * @description Fails on every call; the continueOnError flag set in the constructor lets the chain carry on past the failure.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed('Expected failure, continuing');
		}
	}

	/**
	 * @description Step with continueOnError that fails with a large message: individually under the
	 * default context limit, but too large for the StepLog__c field once several failures
	 * pile up in the step list.
	 *
	 * @date July 2026, September 2026
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

		/**
		 * @description Fails with a message OVERSIZED_MESSAGE_LENGTH characters long; the chain carries on because continueOnError is set.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed('F'.repeat(OVERSIZED_MESSAGE_LENGTH));
		}
	}

	/**
	 * @description Step without continueOnError that fails with the same oversized message and stops the chain, so the
	 * test runs the code that saves a failure that ends the chain.
	 *
	 * @date July 2026, September 2026
	 */
	public class HaltingOversizedFailureMessageStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Fails with a message OVERSIZED_MESSAGE_LENGTH characters long, halting the chain because continueOnError is off.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed('F'.repeat(OVERSIZED_MESSAGE_LENGTH));
		}
	}

	/**
	 * @description Success step whose stepName is supplied by the test, used to pad the serialized
	 * step list towards the StepLog__c field capacity.
	 *
	 * @date July 2026, September 2026
	 */
	public class PaddedNameStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Constructs the step with the test-seeded padded name. Each test seeds
		 * paddedStepName before building its chain, so the step definition carries it. When the
		 * framework creates the step again from its class name at run time, the display name
		 * comes from the saved definition, not from this instance.
		 */
		public PaddedNameStep()
		{
			this.stepName = paddedStepName;
		}

		/**
		 * @description Succeeds without touching the context; the padded step name is the fixture's whole purpose.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A succeeded result.
		 */
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

		/**
		 * @description Succeeds with a message naming the step.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A succeeded result.
		 */
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
		/**
		 * @description Copies the previous step result's data into the previousData context entry when a previous result exists, then succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
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
		/**
		 * @description Copies the key1 and key2 context entries into foundKey1 and foundKey2, so the test can prove the builder seeded them, then succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
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
		/**
		 * @description Records under errorHandlerHadContext whether the testKey context entry reached the handler, then succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
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
	 * @description Test step that first measures how many DML statements one DML_Builder execute uses, then
	 * uses up the transaction's DML statement limit until exactly that many are left. So the final
	 * save uses the last statements, and the test can verify that the save still commits
	 * when the chain's own work has used up the DML budget.
	 */
	public class DmlBudgetBurnerStep implements IF_Chain.Step
	{
		/**
		 * @description Uses up the transaction's DML statement limit until almost none is left, then
		 * returns success, so the chain reaches its final save with almost no statements left.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A successful StepResult.
		 */
		public UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			Foobar__c burner = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
			Integer statementsBefore = UTIL_Limits.dmlStatements().used();
			DML_Builder.newTransaction().doInsert(burner).execute();
			Integer statementsPerExecute = UTIL_Limits.dmlStatements().used() - statementsBefore;

			while(UTIL_Limits.dmlStatements().remaining() > statementsPerExecute)
			{
				DML_Builder.newTransaction().doUpdate(burner).execute();
			}
			return UTIL_AsyncChain.succeeded('Step completed');
		}
	}

	/**
	 * @description Runs as a low-privilege user. Proves that UTIL_AsyncChain.newChain(...).then(step).execute() can
	 * save the framework-owned AsyncChainExecution__c record for a subscriber user on the Minimum Access - Salesforce
	 * profile, who has no field-level access (FLS) on kern__AsyncChainExecution__c. The chain must create its execution
	 * record, complete its one success step, and move the record to COMPLETED, whatever the running user's FLS. The
	 * framework's own DML on the execution record must switch to SYSTEM_MODE.
	 *
	 * Catches: a later change that moves UTIL_AsyncChain's insert of AsyncChainExecution__c to USER_MODE, or removes
	 * the `.withSystemMode()` on the Queueable's status update. This test then fails when the managed package version
	 * is built and validated, not later in a subscriber's scratch org.
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
	 * set up in @TestSetup. The test that runs as this user calls UTIL_AsyncChain to prove a chain still runs for a
	 * subscriber user who has no field-level access to the framework's own objects.
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}
}