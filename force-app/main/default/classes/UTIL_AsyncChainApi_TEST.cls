// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for the ApiStep and the per-step retry of UTIL_AsyncChain: how an ApiStep is set up and how
 * it reads and writes the chain context, how it works with the outbound engine (the engine's own retry is held while
 * the chain retries the step), the attempts and waits of createRetryStrategy, and the methods that report the current
 * attempt. They live apart from UTIL_AsyncChain_TEST because one class holding both grew past the complexity limit,
 * and the ApiStep and its retries can be reviewed on their own.
 *
 * @see UTIL_AsyncChain
 * @see UTIL_AsyncChain_TEST
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date July 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssTypeCount')
private class UTIL_AsyncChainApi_TEST
{
	/**
	 * @description Company name given to the admin user created in the test setup. It is unique to this class, so
	 * getTestAdmin can find that one user again by company name.
	 */
	private static final String TEST_ADMIN_COMPANY = 'UTIL_AsyncChainApi_TEST-admin';

	/**
	 * @description Name used for test chains.
	 */
	private static final String TEST_CHAIN_NAME = 'TestChain';

	/**
	 * @description Attempt number stamped on the context by the stamped-attempt-state test.
	 */
	private static final Integer STAMPED_ATTEMPT_NUMBER = 3;

	/**
	 * @description Context key prefix under which EventuallySucceedsStep records the attempt stamp it
	 * observes on each attempt: key = prefix + attempt number, value = attempt + ':' + isFinalAttempt.
	 */
	private static final String ATTEMPT_STAMP_KEY_PREFIX = 'attemptStamp';

	/**
	 * @description Context key prefix under which the delay-recording fixtures store the enqueue
	 * delay their transaction observes via System.AsyncInfo: the delay in minutes as a string, or
	 * 'none' when no minimum delay was requested for the enqueue.
	 */
	private static final String OBSERVED_DELAY_KEY_PREFIX = 'observedDelay';

	/**
	 * @description Backoff seconds for shouldNotInheritRetryDelayAfterRecovery: 120 seconds clamps to a two-minute
	 * enqueue delay on the retry link.
	 */
	private static final Integer DELAY_INHERITANCE_BACKOFF_SECONDS = 120;

	/**
	 * @description The API handler class name used by ApiStep tests.
	 */
	private static final String API_STEP_SERVICE_NAME = API_PostExample.class.getName();

	/**
	 * @description Outbound-engine retry allowance for shouldFreezeOutboundRetryForApiStepWithoutStrategy: the
	 * ApiSetting__mdt fixture grants the outbound engine two retries of its own, so a single failed
	 * callout leaves headroom for the engine to self-schedule.
	 */
	private static final Integer OUTBOUND_ENGINE_MAX_RETRY_COUNT = 2;

	/**
	 * @description Outbound-engine backoff seconds for shouldFreezeOutboundRetryForApiStepWithoutStrategy: non-zero so
	 * the engine's self-schedule actually stamps NextRetry__c (a zero backoff skips rescheduling).
	 */
	private static final Integer OUTBOUND_ENGINE_RETRY_BACKOFF_SECONDS = 10;

	/**
	 * @description Chain-level retry attempts for the withRetry opt-in tests: two total attempts,
	 * so one chain-owned retry.
	 */
	private static final Integer CHAIN_RETRY_MAX_ATTEMPTS = 2;

	/**
	 * @description Chain-level base backoff for the withRetry opt-in tests: zero keeps the retry
	 * re-enqueue delay-free inside the test transaction.
	 */
	private static final Integer CHAIN_RETRY_BACKOFF_SECONDS = 0;

	/**
	 * @description Disabling maxAttempts for the withRetry opt-in: at or below one total attempt
	 * disables chain-level retry. Both retry values are then left out together, never one alone.
	 */
	private static final Integer DISABLED_RETRY_MAX_ATTEMPTS = 1;

	/**
	 * @description Backoff passed alongside a disabling maxAttempts (<= 1) to prove the pair is
	 * stored whole or not at all: this value must never reach the persisted config.
	 */
	private static final Integer DISABLED_RETRY_BACKOFF_SECONDS = 7;

	/**
	 * @description ApiStep config key carrying the chain-level retry attempts, as written by
	 * writeConfig and read back by a fresh work() instance.
	 */
	private static final String CONFIG_KEY_RETRY_MAX_ATTEMPTS = 'retryMaxAttempts';

	/**
	 * @description ApiStep config key carrying the chain-level retry base backoff seconds.
	 */
	private static final String CONFIG_KEY_RETRY_BACKOFF_SECONDS = 'retryBackoffSeconds';

	/**
	 * @description ApiStep config key carrying the JSON-serialized retryOn status-code filter, as
	 * written by writeConfig and restored by work()'s re-stash.
	 */
	private static final String CONFIG_KEY_RETRYABLE_STATUS_CODES = 'retryableStatusCodes';

	/**
	 * @description Service name of the fails-once-then-succeeds outbound fixture handler.
	 */
	private static final String FLAKY_SERVICE_NAME = FlakyOutboundHandler.class.getName();

	/**
	 * @description Success body the flaky fixture flips its registered mock to after the first
	 * recorded callout.
	 */
	private static final String FLAKY_SUCCESS_BODY = '{"success":true}';

	/**
	 * @description The message the test steps give to a failure that retrying cannot fix. Tests look for it on the
	 * step result and on the saved chain record, to prove the message is carried through unchanged.
	 */
	private static final String PERMANENT_FAILURE_MESSAGE = 'Business rule rejected the record';
	/**
	 * @description The message the test steps give to a failure that may be retried. It differs from
	 * PERMANENT_FAILURE_MESSAGE so the two kinds of failure cannot be mixed up in a test.
	 */
	private static final String TRANSIENT_FAILURE_MESSAGE = 'Transient failure before the permanent verdict';
	/**
	 * @description Key in the chain's shared data under which PermanentFlagReaderStep stores the permanent failure
	 * flag it saw on the previous step's result. The test reads it to prove the flag reaches the next step.
	 */
	private static final String PERMANENT_FLAG_SEEN_KEY = 'permanentFlagSeenByNextStep';

	/**
	 * @description Key in the chain's shared data for the answer a step got when it asked whether this is the last
	 * attempt, given an exception the retry filter refuses to retry. The test expects true.
	 */
	private static final String PROBE_DENIED_KEY = 'probeDeniedExceptionAnswer';
	/**
	 * @description Key in the chain's shared data for the answer a step got when it asked whether this is the last
	 * attempt, given an exception the retry filter allows to be retried. The test expects false while retries
	 * are left.
	 */
	private static final String PROBE_ALLOWED_KEY = 'probeAllowedExceptionAnswer';
	/**
	 * @description Key in the chain's shared data for the answer a step got when it asked whether this is the last
	 * attempt without naming an exception, so only the number of retries left is counted. The test expects false.
	 */
	private static final String PROBE_BUDGET_KEY = 'probeBudgetOnlyAnswer';
	/**
	 * @description Key in the chain's shared data under which the error handler step stores whether it was told
	 * this is the last attempt. The tests read it to prove the handler sees the right answer.
	 */
	private static final String HANDLER_FINALITY_KEY = 'handlerObservedFinality';

	/**
	 * @description HTTP status 503 (service unavailable). It stands in for a failure of the external system that
	 * is worth retrying.
	 */
	private static final Integer HTTP_STATUS_SERVICE_UNAVAILABLE = 503;
	/**
	 * @description The HTTP statuses the tests allow a step to retry on: 500 and 503. A failure with any other
	 * status must then be treated as one that retrying cannot fix.
	 */
	private static final Set<Integer> SERVER_ERROR_RETRY_STATUS_CODES = new Set<Integer> {API_Base.HTTP_INTERNAL_SERVER_ERROR, HTTP_STATUS_SERVICE_UNAVAILABLE};
	/**
	 * @description Service name of FlakyServerErrorOutboundHandler, the test handler whose first call fails and
	 * whose later calls succeed. Tests register mock responses under this name.
	 */
	private static final String SERVER_ERROR_SERVICE_NAME = FlakyServerErrorOutboundHandler.class.getName();
	/**
	 * @description The response body the mocked external system returns together with an error status.
	 */
	private static final String SERVER_ERROR_BODY = '{"error":"service unavailable"}';
	/**
	 * @description A status value that is text, not a number. It proves that a status the retry filter cannot read
	 * leaves the failure open to retry.
	 */
	private static final String NON_NUMERIC_STATUS_CODE = 'gateway timeout';
	/**
	 * @description A status made of digits but too large to fit in an Integer. It proves that such a value leaves
	 * the failure open to retry and does not cause an exception.
	 */
	private static final String OVERSIZED_STATUS_CODE = '99999999999';
	/**
	 * @description Chain-level retry attempts for the tests of a request that is not safe to repeat: three in all, so a
	 * step that stops after its first attempt leaves retry budget unspent and the stop cannot come from an empty budget.
	 */
	private static final Integer CHAIN_RETRY_ATTEMPTS_WITH_BUDGET_LEFT = 3;
	/**
	 * @description The attempt on which a re-run step succeeds in the tests where the chain runs it again: the second.
	 */
	private static final Integer SECOND_ATTEMPT = 2;
	/**
	 * @description The callouts a re-run step makes when both its attempts reach the external system: one each.
	 */
	private static final Integer CALLOUTS_WHEN_BOTH_ATTEMPTS_ARE_SENT = 2;
	/**
	 * @description The callouts a re-run step makes when its first attempt never left the org: only the second is sent.
	 */
	private static final Integer CALLOUTS_WHEN_ONLY_THE_SECOND_ATTEMPT_IS_SENT = 1;
	/**
	 * @description Queueable stack depth for the chains that may run three attempts: one link per attempt and one spare.
	 */
	private static final Integer CHAIN_RETRY_STACK_DEPTH = 4;
	/**
	 * @description Service name of AcceptedThenFailingOutboundHandler, whose external system accepts the request and
	 * whose own handling of the response then fails.
	 */
	private static final String ACCEPTED_THEN_FAILING_SERVICE_NAME = AcceptedThenFailingOutboundHandler.class.getName();
	/**
	 * @description The message AcceptedThenFailingOutboundHandler fails with after the external system accepted the
	 * request.
	 */
	private static final String ACCEPTED_THEN_FAILING_MESSAGE = 'The order was accepted but its confirmation could not be read';
	/**
	 * @description Service name of FlakyReadOutboundHandler, a GET whose first call fails and whose later calls succeed.
	 */
	private static final String FLAKY_READ_SERVICE_NAME = FlakyReadOutboundHandler.class.getName();
	/**
	 * @description Service name of RefusedOnceOutboundHandler, whose first callout the platform refuses before it leaves
	 * the org and whose later callouts are sent.
	 */
	private static final String REFUSED_ONCE_SERVICE_NAME = RefusedOnceOutboundHandler.class.getName();
	/**
	 * @description Service name of NarrowRetryableSetOutboundHandler, a POST whose handler retries only 503, whose first
	 * call fails and whose later calls succeed.
	 */
	private static final String NARROW_RETRYABLE_SET_SERVICE_NAME = NarrowRetryableSetOutboundHandler.class.getName();
	/**
	 * @description Service name of AcceptedThenFailingOnceReadOutboundHandler, a GET whose handling of the response fails
	 * after the first call only.
	 */
	private static final String ACCEPTED_THEN_FAILING_ONCE_READ_SERVICE_NAME = AcceptedThenFailingOnceReadOutboundHandler.class.getName();
	/**
	 * @description Service name of PermanentlyRefusingReadOutboundHandler, a GET whose handling of the response throws
	 * UTIL_Exceptions.PermanentFailureException.
	 */
	private static final String PERMANENTLY_REFUSING_READ_SERVICE_NAME = PermanentlyRefusingReadOutboundHandler.class.getName();
	/**
	 * @description The message PermanentlyRefusingReadOutboundHandler's permanent failure carries.
	 */
	private static final String PERMANENT_REFUSAL_MESSAGE = 'The order no longer exists, so reading it again cannot succeed';
	/**
	 * @description Service name of HookRefusingPostOutboundHandler, a POST with no key whose retryable status set throws
	 * UTIL_Exceptions.PermanentFailureException.
	 */
	private static final String HOOK_REFUSING_POST_SERVICE_NAME = HookRefusingPostOutboundHandler.class.getName();
	/**
	 * @description Service name of CommitRefusingPostOutboundHandler, a POST with no key whose commit throws
	 * UTIL_Exceptions.PermanentFailureException.
	 */
	private static final String COMMIT_REFUSING_POST_SERVICE_NAME = CommitRefusingPostOutboundHandler.class.getName();
	/**
	 * @description How many characters of the line that says why a step stopped the tests expect at the start of the step's
	 * message, right after the handler's name: the step log keeps only the first 255 characters of a message, and the
	 * handler's name with this much of the line always fits.
	 */
	private static final Integer LINE_CHARACTERS_KEPT_IN_STEP_LOG = 100;
	/**
	 * @description Set once RefusedOnceOutboundHandler has saved a record before its first callout, so the platform
	 * refuses that callout for unsaved work and lets every later one through.
	 */
	private static Boolean hasProvokedTheRefusedCallout = false;
	/**
	 * @description Service name of KeyRotatingAfterCalloutOutboundHandler, a POST with no key whose handler rotates the
	 * chain's run key once the external system has responded, so the step's hop loses its progress write.
	 */
	private static final String KEY_ROTATING_SERVICE_NAME = KeyRotatingAfterCalloutOutboundHandler.class.getName();
	/**
	 * @description The run the started-step sweep test launches; KeyRotatingAfterCalloutOutboundHandler rotates its run key
	 * after the callout. Set by the test once the launch has returned the id, before the queued hop runs.
	 */
	private static String executionIdWhoseKeyRotatesAfterTheCallout;
	/**
	 * @description Negative stale threshold that places the watchdog's cutoff in the future, so a chain the test has just
	 * run counts as stale and the sweep decides its fate.
	 */
	private static final Integer SWEEP_EVERYTHING_THRESHOLD_MINUTES = -1;
	/**
	 * @description Batch size for the watchdog sweep: the sweep's own ceiling.
	 */
	private static final Integer WATCHDOG_BATCH_SIZE = 50;
	/**
	 * @description Independent oracle for the longest message a step entry keeps in the persisted step log: the engine
	 * abbreviates a longer one to this many characters.
	 */
	private static final Integer STEP_MESSAGE_CAPACITY = 255;
	/**
	 * @description Service name of KeyRotatingOnceReadOutboundHandler, a GET whose first call loses its hop's progress write.
	 */
	private static final String KEY_ROTATING_ONCE_READ_SERVICE_NAME = KeyRotatingOnceReadOutboundHandler.class.getName();
	/**
	 * @description Service name of KeyRotatingOnceOutboundHandler, a POST whose first call loses its hop's progress write.
	 */
	private static final String KEY_ROTATING_ONCE_SERVICE_NAME = KeyRotatingOnceOutboundHandler.class.getName();
	/**
	 * @description Message ConfigureFailingOutboundHandler throws from configure().
	 */
	private static final String CONFIGURE_FAILURE_MESSAGE = 'The handler cannot be configured';
	/**
	 * @description Message of the query failure the setting-read test registers for ApiSetting__mdt.
	 */
	private static final String SETTING_READ_FAILURE_MESSAGE = 'The API setting cannot be read';

	/**
	 * @description Creates a dedicated test admin user so System.runAs in each test starts a fresh
	 * permission-evaluation context, bypassing the synthetic-org permission-cache staleness issue
	 * that affected mutating the running user's permissionSet mid-transaction. Every test in this
	 * class runs as that admin; the low-privilege chain test lives in UTIL_AsyncChain_TEST, which
	 * provisions its own minimum-access user.
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
	}

	/**
	 * @description Verifies that a step whose retry strategy allows retries is re-attempted until it
	 * succeeds: the chain completes, the retried step is counted once, and the step-log entry records
	 * the successful final attempt.
	 */
	@IsTest
	private static void shouldRetryFailingStepUntilSuccess()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainApi_TEST.EventuallySucceedsStep())
					.withAsyncOptions(createAsyncOptions(4))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete once the retried step succeeds');
			Assert.areEqual(1, execution.CompletedSteps__c, 'The retried step should be counted once');
			List<UTIL_AsyncChain.DTO_StepDefinition> persistedSteps = parseStepLog(execution);
			Assert.areEqual(3, persistedSteps[0].attempt, 'Step log should record the successful third attempt');
			Assert.areEqual(true, persistedSteps[0].success, 'Step log should record the final attempt as successful');
		}
	}

	/**
	 * @description Verifies that a step that fails on every attempt exhausts its retry budget: the
	 * chain fails with the RetriesExhausted category and the step log records the exhausted final
	 * attempt.
	 */
	@IsTest
	private static void shouldExhaustRetriesAndCategorise()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainApi_TEST.AlwaysFailsWithRetryStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should fail once the retry budget is exhausted');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_RETRIES_EXHAUSTED, execution.FailureCategory__c,
					'An exhausted retry budget must be categorised RetriesExhausted');
			List<UTIL_AsyncChain.DTO_StepDefinition> persistedSteps = parseStepLog(execution);
			Assert.areEqual(2, persistedSteps[0].attempt, 'Step log should record the exhausted second attempt');
		}
	}

	/**
	 * @description Verifies that a step without a retry strategy fails terminally on its first
	 * attempt, exactly as before retries existed: no attempt key ever reaches the step log and the
	 * failure stays categorised StepException.
	 */
	@IsTest
	private static void shouldNotRetryWithoutStrategy()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainApi_TEST.FailingStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should fail on the first attempt');
			Assert.isFalse(execution.StepLog__c.contains('"attempt"'), 'A step without a retry strategy should never gain an attempt key');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, execution.FailureCategory__c,
					'A first-attempt failure without retries must stay categorised StepException');
		}
	}

	/**
	 * @description Verifies that an exception-allowlist retry strategy suppresses the retry when the
	 * thrown type is not allowlisted: the chain fails after one attempt with the StepException
	 * category, because no retry budget was ever consumed.
	 */
	@IsTest
	private static void shouldSuppressRetryWhenExceptionNotAllowlisted()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainApi_TEST.ThrowingRetryAllowlistStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should fail without retrying');
			Assert.isFalse(execution.StepLog__c.contains('"attempt"'), 'A filter-denied first-attempt failure should never gain an attempt key');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, execution.FailureCategory__c,
					'A filter-denied first-attempt failure is a StepException, not an exhausted budget');
		}
	}

	/**
	 * @description Verifies that retry composes with continueOnError: the step retries first, and only
	 * its final failed attempt continues the chain, which then completes with the failure accumulated
	 * in the error message.
	 */
	@IsTest
	private static void shouldRetryThenContinueOnError()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainApi_TEST.AlwaysFailsWithRetryStep(), true)
					.then(new UTIL_AsyncChainApi_TEST.TrackingStep())
					.withAsyncOptions(createAsyncOptions(4))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete after the exhausted step continues');
			List<UTIL_AsyncChain.DTO_StepDefinition> persistedSteps = parseStepLog(execution);
			Assert.areEqual(2, persistedSteps[0].attempt, 'Both attempts should be recorded before the step continued');
			Assert.isTrue(execution.ErrorMessage__c.contains('Permanent failure'), 'The continued failure should be accumulated in the error message');
			Assert.areEqual(true, parseContextData(execution).get('trackingStepExecuted'), 'The step after the continued failure should have executed');
		}
	}

	/**
	 * @description Verifies the attempt stamps a retrying step observes from inside work(): the
	 * attempt number increments per retry and isFinalAttempt turns true only on the attempt with no
	 * retry remaining.
	 */
	@IsTest
	private static void shouldStampFinalAttemptFlags()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainApi_TEST.EventuallySucceedsStep())
					.withAsyncOptions(createAsyncOptions(4))
					.execute();
			Test.stopTest();

			Map<String, Object> contextData = parseContextData(queryExecution(executionId));
			Assert.areEqual('1:false', contextData.get(ATTEMPT_STAMP_KEY_PREFIX + 1), 'The first attempt should observe attempt 1 with a retry remaining');
			Assert.areEqual('2:false', contextData.get(ATTEMPT_STAMP_KEY_PREFIX + 2), 'The second attempt should observe attempt 2 with a retry remaining');
			Assert.areEqual('3:true', contextData.get(ATTEMPT_STAMP_KEY_PREFIX + 3), 'The third attempt should observe the final attempt');
		}
	}

	/**
	 * @description Verifies that the retry backoff delay fires exactly once, on the retry link
	 * itself: the retried attempt's transaction observes the backoff enqueue delay, and the step
	 * AFTER the recovered retry runs without any inherited delay.
	 */
	@IsTest
	private static void shouldNotInheritRetryDelayAfterRecovery()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainApi_TEST.DelayRecordingRetryStep())
					.then(new UTIL_AsyncChainApi_TEST.DelayRecordingStep())
					.withAsyncOptions(createAsyncOptions(5))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete after the retried step recovers');
			Map<String, Object> contextData = parseContextData(execution);
			Assert.areEqual('2', contextData.get(OBSERVED_DELAY_KEY_PREFIX + 'Step0Attempt2'), 'The retried attempt should observe the two-minute backoff delay');
			Assert.areEqual('none', contextData.get(OBSERVED_DELAY_KEY_PREFIX + 'Step1'), 'The step after a recovered retry should run without an inherited delay');
		}
	}

	/**
	 * @description Verifies that a fresh context, before the executor stamps anything, defaults to
	 * attempt 1 and final attempt true. Every step without a retry strategy can rely on that.
	 */
	@IsTest
	private static void shouldDefaultAttemptStateForFreshContext()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('test-exec-id', 'test-corr-id');

			Assert.areEqual(1, context.getAttempt(), 'A fresh context should default to attempt 1');
			Assert.isTrue(context.isFinalAttempt(), 'A fresh context should default to the final attempt');
		}
	}

	/**
	 * @description Verifies that stamped attempt state is exposed through the accessors and that the
	 * transient per-step stamps stay out of the serialized context data, exactly like currentStepIndex.
	 */
	@IsTest
	private static void shouldExposeStampedAttemptState()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('test-exec-id', 'test-corr-id');
			context.currentAttempt = STAMPED_ATTEMPT_NUMBER;
			context.finalAttempt = false;

			Assert.areEqual(STAMPED_ATTEMPT_NUMBER, context.getAttempt(), 'getAttempt should expose the stamped attempt number');
			Assert.isFalse(context.isFinalAttempt(), 'isFinalAttempt should expose the stamped value');

			AsyncChainExecution__c serializedShell = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.ContextData__c, context.serialize())
					.withoutInsertion()
					.build();
			Map<String, Object> contextData = parseContextData(serializedShell);
			Assert.isFalse(contextData.containsKey('currentAttempt'), 'Serialized context data should not carry the attempt stamp');
			Assert.isFalse(contextData.containsKey('finalAttempt'), 'Serialized context data should not carry the finalAttempt stamp');
		}
	}

	/**
	 * @description Verifies an onError handler reads isFinalAttempt() true after a filter-denied
	 * retry. The failing step's allowlist refuses the thrown exception while budget remains, so
	 * the pre-work stamp said false; the dispatch must correct it before the handler runs. The
	 * handler having run at all also proves that the transient strategy stash never rides the
	 * handler enqueue's platform serialization (the fixture's filter holds a Set<Type>).
	 */
	@IsTest
	private static void shouldRestampFinalityBeforeErrorHandlerAfterFilterDenial()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainApi_TEST.ThrowingRetryAllowlistStep())
					.onError(new UTIL_AsyncChainApi_TEST.FinalityRecordingErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(4))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'The filter-denied failure must fail the chain');
			Map<String, Object> contextData = parseContextData(execution);
			Assert.areEqual(true, contextData.get(HANDLER_FINALITY_KEY),
					'The handler must read the corrected finality: the denied retry made this failure final');
		}
	}

	/**
	 * @description Verifies an onError handler reads isFinalAttempt() true after a permanent
	 * failure refused the remaining budget: the pre-work stamp said false (budget remained), and
	 * the dispatch must correct it on the permanent short-circuit path too.
	 */
	@IsTest
	private static void shouldRestampFinalityBeforeErrorHandlerAfterPermanentFailure()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainApi_TEST.PermanentlyFailingStep())
					.onError(new UTIL_AsyncChainApi_TEST.FinalityRecordingErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(4))
					.execute();
			Test.stopTest();

			Map<String, Object> contextData = parseContextData(queryExecution(executionId));
			Assert.areEqual(true, contextData.get(HANDLER_FINALITY_KEY),
					'The handler must read final after a permanent declaration refused the budget');
		}
	}

	/**
	 * @description Verifies the exception-aware probe from inside work() on attempt one of three:
	 * a filter-denied exception reads final (the retry would be refused), a filter-allowed one
	 * reads not final (a retry remains), and the budget-only overload still reads not final.
	 * The overload cannot see the filter, which is why the exception-aware check exists.
	 */
	@IsTest
	private static void shouldAnswerExceptionAwareFinalityProbeInsideWork()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainApi_TEST.FinalityProbeRecordingStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			Map<String, Object> contextData = parseContextData(queryExecution(executionId));
			Assert.areEqual(true, contextData.get(PROBE_DENIED_KEY), 'A filter-denied exception must read final');
			Assert.areEqual(false, contextData.get(PROBE_ALLOWED_KEY), 'A filter-allowed exception must read not final while budget remains');
			Assert.areEqual(false, contextData.get(PROBE_BUDGET_KEY), 'The budget-only reading stays not final: the blindness the probe sees past');
		}
	}

	/**
	 * @description Verifies the probe's default answer: a context with no stashed strategy (a
	 * fresh context, or any handler transaction after the stash was excluded from serialization)
	 * reads final for any exception. That is correct, because a failure outside a live retry consult is
	 * always final.
	 */
	@IsTest
	private static void shouldDefaultExceptionAwareFinalityProbeForFreshContext()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext('test-exec-id', 'test-corr-id');
			Assert.isTrue(context.isFinalAttempt(new UTIL_Exceptions.IllegalStateException(PERMANENT_FAILURE_MESSAGE)),
					'With no strategy in scope every failure is final');
		}
	}

	/**
	 * @description Verifies a step that declares its failure permanent is never retried even though
	 * its strategy has budget left: one attempt runs, the chain fails, and the audit category reads
	 * StepException because the budget was refused, not exhausted.
	 */
	@IsTest
	private static void shouldNotRetryPermanentlyFailedStepDespiteBudget()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainApi_TEST.PermanentlyFailingStep())
					.withAsyncOptions(createAsyncOptions(4))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'A permanent failure must fail the chain');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, execution.FailureCategory__c,
					'A refused budget is not an exhausted one: the category must read StepException');
			Assert.isTrue(execution.ErrorMessage__c.contains(PERMANENT_FAILURE_MESSAGE), 'The declared message must reach the audit record');
			Assert.isFalse(execution.StepLog__c.contains('"attempt"'),
					'No retry may be scheduled for a permanent failure, so the attempt marker never lands');
		}
	}

	/**
	 * @description Verifies the permanent-failure flag across every factory: both failedPermanently
	 * overloads set it, every other factory leaves it false, and it is never null.
	 */
	@IsTest
	private static void shouldExposePermanentFailureFlagOnStepResultFactories()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.StepResult permanentFromMessage = UTIL_AsyncChain.failedPermanently(PERMANENT_FAILURE_MESSAGE);
			Assert.isFalse(permanentFromMessage.success, 'failedPermanently must produce a failed result');
			Assert.isTrue(permanentFromMessage.permanentFailure, 'The message overload must set the permanent flag');
			Assert.areEqual(PERMANENT_FAILURE_MESSAGE, permanentFromMessage.message, 'The message must pass through unchanged');

			UTIL_Exceptions.IllegalStateException cause = new UTIL_Exceptions.IllegalStateException(PERMANENT_FAILURE_MESSAGE);
			UTIL_AsyncChain.StepResult permanentFromException = UTIL_AsyncChain.failedPermanently(cause);
			Assert.isTrue(permanentFromException.permanentFailure, 'The exception overload must set the permanent flag');
			Assert.areEqual(cause, permanentFromException.error, 'The exception must ride the result like failed(exception)');

			Assert.isFalse(UTIL_AsyncChain.failed(PERMANENT_FAILURE_MESSAGE).permanentFailure, 'failed() must never read as permanent');
			Assert.isFalse(UTIL_AsyncChain.failed(cause).permanentFailure, 'failed(exception) must never read as permanent');
			Assert.isFalse(UTIL_AsyncChain.succeeded().permanentFailure, 'succeeded() must never read as permanent');
		}
	}

	/**
	 * @description Tests the isIdempotent declaration on ChainStep as a subscriber writes it: a step
	 * subclass overrides isIdempotent(), with no constructor, and the chain still completes through
	 * the real execution path. The declaration is inert to the run
	 * itself; it gates the Chain Monitor's re-drive actions.
	 */
	@IsTest
	private static void shouldExposeIdempotentDeclarationOnChainStep()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainApi_TEST.IdempotentDeclaringStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'A chain whose step declares isIdempotent must still complete');
			Assert.areEqual(1, execution.CompletedSteps__c, 'The declaring step must run and count complete');
		}
	}

	/**
	 * @description Verifies a step that genuinely retried once and then declared its failure
	 * permanent records StepException: the second attempt refused the remaining budget, and
	 * recording RetriesExhausted would corrupt the audit distinction the guide promises.
	 */
	@IsTest
	private static void shouldCategorisePermanentFailureAsStepExceptionAfterRetry()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainApi_TEST.TransientThenPermanentStep())
					.withAsyncOptions(createAsyncOptions(4))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'The permanent verdict on attempt two must fail the chain');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, execution.FailureCategory__c,
					'A permanent verdict after a real retry still reads StepException, never RetriesExhausted');
			List<UTIL_AsyncChain.DTO_StepDefinition> persistedSteps = parseStepLog(execution);
			Assert.areEqual(2, persistedSteps[0].attempt, 'The step log must record that a real second attempt ran');
		}
	}

	/**
	 * @description Checks the dispatch behaviour the ApexDoc states: a step that RETURNS
	 * failed(exception) without throwing is filtered exactly like a throwing step, so an
	 * allowlist that does not match the returned exception denies the retry on attempt one.
	 */
	@IsTest
	private static void shouldApplyExceptionFilterToReturnedFailedResult()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainApi_TEST.ReturnsFilterDeniedExceptionStep())
					.withAsyncOptions(createAsyncOptions(4))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'The filter-denied returned failure must fail the chain');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, execution.FailureCategory__c,
					'A first-attempt filter denial reads StepException');
			Assert.isFalse(execution.StepLog__c.contains('"attempt"'),
					'The allowlist must deny the retry of a returned failed(exception): no attempt marker may land');
		}
	}

	/**
	 * @description Verifies the permanent-failure flag survives the previous-step-result
	 * persistence round trip: a continueOnError successor running in a later transaction still
	 * reads permanentFailure true from getPreviousStepResult().
	 */
	@IsTest
	private static void shouldRoundTripPermanentFailureFlagToNextStep()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainApi_TEST.PermanentlyFailingStep(), true)
					.then(new UTIL_AsyncChainApi_TEST.PermanentFlagReaderStep())
					.withAsyncOptions(createAsyncOptions(4))
					.execute();
			Test.stopTest();

			Map<String, Object> contextData = parseContextData(queryExecution(executionId));
			Assert.areEqual(true, contextData.get(PERMANENT_FLAG_SEEN_KEY),
					'The successor transaction must still see the permanent flag on the previous result');
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
	 * @description Keeps the behaviour of an ApiStep without withRetry from changing: an ApiStep with no
	 * chain-level retry strategy leaves the outbound engine as the sole retry authority. A failing callout fails the
	 * chain after a single attempt, while the outbound engine independently self-schedules its own
	 * retry on the ApiCall__c row: Status Retry, NextRetry__c stamped, first retry recorded.
	 */
	@IsTest
	private static void shouldFreezeOutboundRetryForApiStepWithoutStrategy()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			mockOutboundEngineRetrySetting();
			API_MockFactory.registerErrorMock(API_STEP_SERVICE_NAME);

			Test.startTest();
			String executionId = executeSingleApiStepChain(record);
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain without a retry strategy should fail after a single attempt');

			List<ApiCall__c> apiCalls = new SEL_ApiCall().findByServiceName(API_STEP_SERVICE_NAME);
			Assert.areEqual(1, apiCalls.size(), 'The unconfigured path should make exactly one callout');

			ApiCall__c apiCall = apiCalls.iterator().next();
			Assert.areEqual(SEL_ApiCall.STATUS_RETRY, apiCall.Status__c, 'The outbound engine should keep sole retry ownership of the ApiCall record');
			Assert.isNotNull(apiCall.NextRetry__c, 'The outbound engine should stamp its own next-retry schedule');
			Assert.areEqual(1, apiCall.Retries__c, 'The outbound engine should record its first self-scheduled retry');
		}
	}

	/**
	 * @description Verifies the ApiStep chain-level retry opt-in: with withRetry configured, a
	 * callout that fails once and then succeeds is re-run by the chain (a fresh handler instance and
	 * a fresh callout), the chain completes, and the step log records the successful second attempt.
	 * Idempotency Enabled makes the step's POST safe to repeat, so the 500 is a failure the chain may
	 * re-run: a 500 to a POST with no key is never re-run.
	 */
	@IsTest
	private static void shouldRetryApiStepWithChainStrategy()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(FLAKY_SERVICE_NAME, true);
			API_MockFactory.registerErrorMock(FLAKY_SERVICE_NAME);

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(FlakyOutboundHandler.class)
							.withRetry(CHAIN_RETRY_MAX_ATTEMPTS, CHAIN_RETRY_BACKOFF_SECONDS))
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Chain should complete once the retried callout succeeds');
			List<UTIL_AsyncChain.DTO_StepDefinition> persistedSteps = parseStepLog(execution);
			Assert.areEqual(CHAIN_RETRY_MAX_ATTEMPTS, persistedSteps[0].attempt, 'Step log should record the successful second attempt');
			Assert.areEqual(true, persistedSteps[0].success, 'Step log should record the final attempt as successful');
		}
	}

	/**
	 * @description Verifies there is one retry authority, never two: when the chain owns retries via
	 * withRetry, the outbound engine's own NextRetry__c rescheduling is suppressed for calls made by
	 * this step. An always-failing callout exhausts the chain budget (two attempts, two ApiCall__c
	 * rows) and neither row carries the engine's self-schedule, even though the ApiSetting__mdt
	 * fixture would normally let the engine claim it (shouldFreezeOutboundRetryForApiStepWithoutStrategy
	 * proves exactly that claim when the chain has no retry of its own).
	 */
	@IsTest
	private static void shouldSuppressOutboundSelfRetryWhenChainOwnsRetry()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			mockOutboundEngineRetrySetting();
			API_MockFactory.registerErrorMock(API_STEP_SERVICE_NAME);

			Test.startTest();
			String executionId = executeSingleApiStepChainWithRetry(record);
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Chain should fail once its retry budget is exhausted');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_RETRIES_EXHAUSTED, execution.FailureCategory__c,
					'An exhausted chain retry budget must be categorised RetriesExhausted');

			List<ApiCall__c> apiCalls = new SEL_ApiCall().findByServiceName(API_STEP_SERVICE_NAME);
			Assert.areEqual(CHAIN_RETRY_MAX_ATTEMPTS, apiCalls.size(), 'Each chain attempt should have made its own callout');
			for(ApiCall__c apiCall : apiCalls)
			{
				Assert.areNotEqual(SEL_ApiCall.STATUS_RETRY, apiCall.Status__c, 'A suppressed outbound engine must not claim the row for its own retry: ' + apiCall.Id);
				Assert.isNull(apiCall.NextRetry__c, 'A suppressed outbound engine must not stamp its own next-retry time: ' + apiCall.Id);
			}
		}
	}

	/**
	 * @description Verifies the retry pair round-trips writeConfig into the persisted context a
	 * fresh work() instance reads: a configured step carries both keys with the as-provided values,
	 * and a disabled opt-in (maxAttempts <= 1) stores neither key. The two keys are saved together or not at all.
	 */
	@IsTest
	private static void shouldRoundTripRetryConfigThroughContext()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
							.triggeringRecord(record.Id)
							.withParameter(API_PostExample.PARAMETER_NAME, 'first')
							.withRetry(CHAIN_RETRY_MAX_ATTEMPTS, CHAIN_RETRY_BACKOFF_SECONDS))
					.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
							.triggeringRecord(record.Id)
							.withParameter(API_PostExample.PARAMETER_NAME, 'second')
							.withRetry(DISABLED_RETRY_MAX_ATTEMPTS, DISABLED_RETRY_BACKOFF_SECONDS))
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Both steps should complete on the auto-mocked success path');

			Map<String, Object> contextData = parseContextData(execution);
			Map<String, Object> configuredStep = (Map<String, Object>)contextData.get(UTIL_AsyncChain.API_STEP_CONFIG_KEY_PREFIX + '0');
			Assert.areEqual
					(
							CHAIN_RETRY_MAX_ATTEMPTS,
							configuredStep.get(CONFIG_KEY_RETRY_MAX_ATTEMPTS),
							'The configured pair should carry max attempts unchanged to the fresh work() instance'
					);
			Assert.areEqual(CHAIN_RETRY_BACKOFF_SECONDS, configuredStep.get(CONFIG_KEY_RETRY_BACKOFF_SECONDS), 'The configured pair should carry the base backoff unchanged');

			Map<String, Object> disabledStep = (Map<String, Object>)contextData.get(UTIL_AsyncChain.API_STEP_CONFIG_KEY_PREFIX + '1');
			Assert.isFalse(disabledStep.containsKey(CONFIG_KEY_RETRY_MAX_ATTEMPTS), 'A disabled opt-in must store no attempts key');
			Assert.isFalse(disabledStep.containsKey(CONFIG_KEY_RETRY_BACKOFF_SECONDS), 'A disabled opt-in must store no backoff key');
		}
	}

	/**
	 * @description Verifies suppression is per-handler-instance, never transaction- or type-global:
	 * after the suppressed withRetry ApiStep has run, invoking the same service through the normal
	 * outbound factory path in the same test transaction still self-schedules its own retry. Guards
	 * the per-instance behaviour against any future refactor of handler-instance lifetime.
	 */
	@IsTest
	private static void shouldNotBleedSuppressionAcrossHandlerInstances()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			mockOutboundEngineRetrySetting();
			API_MockFactory.registerErrorMock(API_STEP_SERVICE_NAME);

			Test.startTest();
			executeSingleApiStepChainWithRetry(record);
			Test.stopTest();

			List<ApiCall__c> suppressedCalls = new SEL_ApiCall().findByServiceName(API_STEP_SERVICE_NAME);
			Assert.areEqual(CHAIN_RETRY_MAX_ATTEMPTS, suppressedCalls.size(), 'The suppressed chain attempts should have made two callouts');
			for(ApiCall__c apiCall : suppressedCalls)
			{
				Assert.areNotEqual(SEL_ApiCall.STATUS_RETRY, apiCall.Status__c, 'No chain-made call may carry the engine self-schedule: ' + apiCall.Id);
			}

			UTIL_HttpClient.useHandler(API_PostExample.class)
					.withTriggeringRecord(record.Id)
					.withParameter(API_PostExample.PARAMETER_NAME, 'test')
					.invoke();

			List<ApiCall__c> selfScheduledCalls = new List<ApiCall__c>();
			for(ApiCall__c apiCall : new SEL_ApiCall().findByServiceName(API_STEP_SERVICE_NAME))
			{
				if(apiCall.Status__c == SEL_ApiCall.STATUS_RETRY)
				{
					selfScheduledCalls.add(apiCall);
				}
			}
			Assert.areEqual(1, selfScheduledCalls.size(), 'The unsuppressed factory-path call must still self-schedule its own retry');
			Assert.isNotNull(selfScheduledCalls[0].NextRetry__c, 'The unsuppressed factory-path call must stamp its own next-retry time');
		}
	}

	/**
	 * @description Verifies a failed status outside the retryOn filter is never retried even with
	 * retry budget configured: exactly one call runs, the chain fails, and the category reads
	 * StepException because the status proved the failure deterministic.
	 */
	@IsTest
	private static void shouldNotRetryApiStepWhenStatusExcludedByRetryOn()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			API_MockFactory.forService(API_STEP_SERVICE_NAME)
					.body(SERVER_ERROR_BODY)
					.statusCode(API_Base.HTTP_BAD_REQUEST)
					.register();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
							.triggeringRecord(record.Id)
							.withParameter(API_PostExample.PARAMETER_NAME, 'test')
							.withRetry(CHAIN_RETRY_MAX_ATTEMPTS, CHAIN_RETRY_BACKOFF_SECONDS)
							.retryOn(SERVER_ERROR_RETRY_STATUS_CODES))
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'The excluded status must fail the chain');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, execution.FailureCategory__c,
					'A status the filter excludes is a deterministic failure: StepException, never RetriesExhausted');
			Assert.areEqual(1, new SEL_ApiCall().findByServiceName(API_STEP_SERVICE_NAME).size(),
					'The excluded status must consume exactly one call: no retry may fire');
		}
	}

	/**
	 * @description Verifies a failed status inside the retryOn filter still retries: the flaky
	 * fixture fails with 503 once, the filter admits it, and the chain completes on attempt two.
	 */
	@IsTest
	private static void shouldRetryApiStepWhenStatusIncludedInRetryOn()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			API_MockFactory.forService(SERVER_ERROR_SERVICE_NAME)
					.body(SERVER_ERROR_BODY)
					.statusCode(HTTP_STATUS_SERVICE_UNAVAILABLE)
					.register();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(FlakyServerErrorOutboundHandler.class)
							.withRetry(CHAIN_RETRY_MAX_ATTEMPTS, CHAIN_RETRY_BACKOFF_SECONDS)
							.retryOn(SERVER_ERROR_RETRY_STATUS_CODES))
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'The in-filter status must retry to success');
			List<UTIL_AsyncChain.DTO_StepDefinition> persistedSteps = parseStepLog(execution);
			Assert.areEqual(CHAIN_RETRY_MAX_ATTEMPTS, persistedSteps[0].attempt, 'The step log must record the successful second attempt');
		}
	}

	/**
	 * @description Checks the released default: without retryOn, EVERY failed status retries, a 400
	 * included. Guards against the HttpClient-style default set {500, 502, 503, 504} ever leaking
	 * into the chain path, which would silently stop shipped chains retrying client errors.
	 */
	@IsTest
	private static void shouldRetryAnyFailedStatusWithoutRetryOnFilter()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			API_MockFactory.forService(SERVER_ERROR_SERVICE_NAME)
					.body(SERVER_ERROR_BODY)
					.statusCode(API_Base.HTTP_BAD_REQUEST)
					.register();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(FlakyServerErrorOutboundHandler.class)
							.withRetry(CHAIN_RETRY_MAX_ATTEMPTS, CHAIN_RETRY_BACKOFF_SECONDS))
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c,
					'Without retryOn the released retry-any default stands: even a 400 retries to success');
			Assert.areEqual(CHAIN_RETRY_MAX_ATTEMPTS, parseStepLog(execution)[0].attempt, 'The 400 must have been retried');
		}
	}

	/**
	 * @description End-to-end test that a transport failure with no status, on a request that is safe
	 * to repeat, stays retryable under the strictest possible filter. The first call throws before any
	 * status exists. The empty retryOn set would refuse every failure that has a status. Yet the chain
	 * retries and completes, because without a status nothing proves the failure will happen again.
	 * Idempotency Enabled makes the POST safe to repeat; the same failure of a POST with no key is
	 * never re-run (shouldStopTheStepWhenAnUnkeyedPostGetsNoResponse).
	 */
	@IsTest
	private static void shouldKeepStatuslessTransportFailureRetryableWhenSafeToRepeat()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(SERVER_ERROR_SERVICE_NAME, true);
			API_MockFactory.forService(SERVER_ERROR_SERVICE_NAME).withTransportFailure().register();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(FlakyServerErrorOutboundHandler.class)
							.withRetry(CHAIN_RETRY_MAX_ATTEMPTS, CHAIN_RETRY_BACKOFF_SECONDS)
							.retryOn(new Set<Integer>()))
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c,
					'A statusless transport failure must stay retryable even under an empty retryOn filter');
			Assert.areEqual(CHAIN_RETRY_MAX_ATTEMPTS, parseStepLog(execution)[0].attempt,
					'The step log must record the successful second attempt after the transport failure');
		}
	}

	/**
	 * @description Verifies retryOn round-trips the step config as a JSON string: present with the
	 * exact codes when configured, absent when never called, and restored by work()'s re-stash so
	 * the post-work permanence decision sees it on the reflected instance.
	 */
	@IsTest
	private static void shouldRoundTripRetryOnConfigurationThroughContext()
	{
		System.runAs(getTestAdmin())
		{
			Map<String, Object> initialContext = new Map<String, Object>();
			new UTIL_AsyncChain.ApiStep(API_PostExample.class)
					.withRetry(CHAIN_RETRY_MAX_ATTEMPTS, CHAIN_RETRY_BACKOFF_SECONDS)
					.retryOn(SERVER_ERROR_RETRY_STATUS_CODES)
					.writeConfig(initialContext, 0);

			Map<String, Object> config = (Map<String, Object>)initialContext.get(UTIL_AsyncChain.API_STEP_CONFIG_KEY_PREFIX + '0');
			Set<Integer> persisted = (Set<Integer>)JSON.deserialize((String)config.get(CONFIG_KEY_RETRYABLE_STATUS_CODES), Set<Integer>.class);
			Assert.areEqual(SERVER_ERROR_RETRY_STATUS_CODES, persisted, 'The configured codes must round-trip the JSON string');

			Map<String, Object> unfilteredContext = new Map<String, Object>();
			new UTIL_AsyncChain.ApiStep(API_PostExample.class)
					.withRetry(CHAIN_RETRY_MAX_ATTEMPTS, CHAIN_RETRY_BACKOFF_SECONDS)
					.writeConfig(unfilteredContext, 0);
			Map<String, Object> unfilteredConfig = (Map<String, Object>)unfilteredContext.get(UTIL_AsyncChain.API_STEP_CONFIG_KEY_PREFIX + '0');
			Assert.isFalse(unfilteredConfig.containsKey(CONFIG_KEY_RETRYABLE_STATUS_CODES),
					'An unset filter must write no key, so the retry-any default is structurally preserved');
		}
	}

	/**
	 * @description Direct test of every branch where the status filter allows a retry because it cannot
	 * decide, including the cases no mock can produce: unset filter, absent retry budget, blank status, non-numeric
	 * status, and a numeric status too large for an Integer all stay retryable; only a parseable
	 * status outside the filter reads permanent.
	 */
	@IsTest
	private static void shouldFailOpenToRetryableForUnfilterableStatusCodes()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsyncChain.ApiStep filtered = new UTIL_AsyncChain.ApiStep(API_PostExample.class)
					.withRetry(CHAIN_RETRY_MAX_ATTEMPTS, CHAIN_RETRY_BACKOFF_SECONDS)
					.retryOn(SERVER_ERROR_RETRY_STATUS_CODES);
			Assert.isTrue(filtered.isPermanentByStatusFilter(String.valueOf(API_Base.HTTP_BAD_REQUEST)), 'A parseable status outside the filter reads permanent');
			Assert.isFalse(filtered.isPermanentByStatusFilter(String.valueOf(HTTP_STATUS_SERVICE_UNAVAILABLE)), 'A status inside the filter stays retryable');
			Assert.isFalse(filtered.isPermanentByStatusFilter(null), 'A missing status fails open to retryable');
			Assert.isFalse(filtered.isPermanentByStatusFilter(''), 'A blank status fails open to retryable');
			Assert.isFalse(filtered.isPermanentByStatusFilter(NON_NUMERIC_STATUS_CODE), 'A non-numeric status fails open to retryable');
			Assert.isFalse(filtered.isPermanentByStatusFilter(OVERSIZED_STATUS_CODE), 'A status too large for an Integer fails open to retryable, never throws');

			UTIL_AsyncChain.ApiStep unfiltered = new UTIL_AsyncChain.ApiStep(API_PostExample.class)
					.withRetry(CHAIN_RETRY_MAX_ATTEMPTS, CHAIN_RETRY_BACKOFF_SECONDS);
			Assert.isFalse(unfiltered.isPermanentByStatusFilter(String.valueOf(API_Base.HTTP_BAD_REQUEST)),
					'Without retryOn no status reads permanent: the released retry-any default');

			UTIL_AsyncChain.ApiStep withoutRetryBudget = new UTIL_AsyncChain.ApiStep(API_PostExample.class)
					.retryOn(SERVER_ERROR_RETRY_STATUS_CODES);
			Assert.isFalse(withoutRetryBudget.isPermanentByStatusFilter(String.valueOf(API_Base.HTTP_BAD_REQUEST)), 'retryOn is inert without withRetry');

			UTIL_AsyncChain.ApiStep emptyFiltered = new UTIL_AsyncChain.ApiStep(API_PostExample.class)
					.withRetry(CHAIN_RETRY_MAX_ATTEMPTS, CHAIN_RETRY_BACKOFF_SECONDS)
					.retryOn(new Set<Integer>());
			Assert.isTrue(emptyFiltered.isPermanentByStatusFilter(String.valueOf(HTTP_STATUS_SERVICE_UNAVAILABLE)),
					'An empty filter stops every status-bearing failure from retrying');
		}
	}

	/**
	 * @description A POST with no key that got no response may have reached the external system, so the chain does not
	 * re-run the step although retry budget is left: one callout, the step fails for good with the line that says why,
	 * the chain fails, and the one issue says the external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldStopTheStepWhenAnUnkeyedPostGetsNoResponse()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(SERVER_ERROR_SERVICE_NAME, false);
			API_MockFactory.forService(SERVER_ERROR_SERVICE_NAME).withTransportFailure().register();

			Test.startTest();
			String executionId = executeChainWithBudgetLeft(new UTIL_AsyncChain.ApiStep(FlakyServerErrorOutboundHandler.class));
			Test.stopTest();

			String expectedLine = String.format(System.Label.OutboundCall_NoResponseNotRepeated, new List<Object> {SERVER_ERROR_SERVICE_NAME});
			assertStepStoppedAfterOneCallout(executionId, SERVER_ERROR_SERVICE_NAME, expectedLine);
		}
	}

	/**
	 * @description An API step sends a POST with no key, and its hop then loses its progress write. (The handler rotates
	 * the run key once the external system has responded. A hop leaves the same shape when the platform ends it between
	 * the callout and the write.) The watchdog does not send the request again: the step's start was recorded at launch
	 * and the step never declared itself idempotent. So the sweep ends the chain Failed with the labelled reason, the
	 * callout count stays at one, and the one call row stays as the first hop left it.
	 */
	@IsTest
	private static void shouldNotSendTheCalloutAgainWhenAnApiStepStartedAndLeftNoResult()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(KEY_ROTATING_SERVICE_NAME, false);

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(KeyRotatingAfterCalloutOutboundHandler.class))
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			executionIdWhoseKeyRotatesAfterTheCallout = executionId;
			Test.stopTest();

			AsyncChainExecution__c stranded = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, stranded.Status__c,
					'Fixture guard: expected the fenced hop to leave the chain Running, got ' + stranded.Status__c);
			Assert.areEqual(1, API_MockFactory.getInvocationCount(KEY_ROTATING_SERVICE_NAME),
					'Fixture guard: expected one callout, got ' + API_MockFactory.getInvocationCount(KEY_ROTATING_SERVICE_NAME));
			UTIL_AsyncChain.DTO_StepDefinition strandedStep = parseStepLog(stranded)[0];
			Assert.areEqual(true, strandedStep.started, 'Fixture guard: expected the launch to record the step\'s start, got ' + strandedStep.started);
			Assert.isNull(strandedStep.success, 'Fixture guard: expected no saved result on the step, got ' + strandedStep.success);

			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			AsyncChainExecution__c result = queryExecution(executionId);
			String expectedReason = String.format(System.Label.AsyncChain_RecoveryStoppedAtStartedStep, new List<String> {KEY_ROTATING_SERVICE_NAME});
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c,
					'Expected the sweep to stop the chain instead of sending the request again, got ' + result.Status__c);
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED, result.FailureCategory__c, 'Expected the Stalled category, got ' + result.FailureCategory__c);
			Assert.areEqual(expectedReason, result.ErrorMessage__c, 'Expected the labelled reason naming the step, got ' + result.ErrorMessage__c);
			Assert.areNotEqual(stranded.RunKey__c, result.RunKey__c, 'Expected the refusal to rotate the run key, got the same key');
			Integer callouts = API_MockFactory.getInvocationCount(KEY_ROTATING_SERVICE_NAME);
			Assert.areEqual(1, callouts, 'Expected the request not to be sent again, got ' + callouts + ' callouts');
			List<ApiCall__c> calls = new SEL_ApiCall().findByServiceName(KEY_ROTATING_SERVICE_NAME);
			Assert.areEqual(1, calls.size(), 'Expected one call row, got ' + calls.size());
			Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, calls[0].Status__c, 'Expected the one call to rest Completed as the first hop left it, got ' + calls[0].Status__c);
			UTIL_AsyncChain.DTO_StepDefinition refusedStep = parseStepLog(result)[0];
			Assert.areEqual(false, refusedStep.success, 'Expected the started step marked as the failed step, got ' + refusedStep.success);
			Assert.areEqual(UTIL_String.abbreviate(expectedReason, STEP_MESSAGE_CAPACITY), refusedStep.message,
					'Expected the step message to carry the reason, got ' + refusedStep.message);
		}
	}

	/**
	 * @description An API step whose handler sends a GET declares itself safe to repeat when the chain is built. When its
	 * hop sends the request and then loses its progress write (the stall shape the watchdog sees after the platform ends a
	 * hop between the callout and the write), the watchdog runs the step again and the chain completes: two callouts, two
	 * call rows, and the step's entry records the declaration, the start and the success.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRunAStalledReadStepAgainAndComplete()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(KEY_ROTATING_ONCE_READ_SERVICE_NAME, false);

			String executionId = runChainThatStallsOnceThenSweep(new UTIL_AsyncChain.ApiStep(KeyRotatingOnceReadOutboundHandler.class));

			assertStalledStepRanAgainAndCompleted(executionId, KEY_ROTATING_ONCE_READ_SERVICE_NAME);
		}
	}

	/**
	 * @description An API step whose handler sends a POST under an API setting with Idempotency Enabled declares itself safe
	 * to repeat when the chain is built, because the engine sends an Idempotency-Key with every attempt. After the same
	 * stall the watchdog runs the step again and the chain completes with two callouts. Both call rows record the same key,
	 * so the external system can tell the second request is the first one sent again.
	 */
	@IsTest
	private static void shouldRunAStalledKeyedPostStepAgainAndComplete()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(KEY_ROTATING_ONCE_SERVICE_NAME, true);

			String executionId = runChainThatStallsOnceThenSweep(new UTIL_AsyncChain.ApiStep(KeyRotatingOnceOutboundHandler.class));

			assertStalledStepRanAgainAndCompleted(executionId, KEY_ROTATING_ONCE_SERVICE_NAME);
			List<ApiCall__c> calls = new SEL_ApiCall().findByServiceName(KEY_ROTATING_ONCE_SERVICE_NAME);
			Assert.isTrue(String.isNotBlank(calls[0].IdempotencyKey__c), 'Expected the first call to record its Idempotency-Key, got ' + calls[0].IdempotencyKey__c);
			Assert.areEqual(calls[0].IdempotencyKey__c, calls[1].IdempotencyKey__c,
					'Expected the run again to send the same Idempotency-Key, got ' + calls[0].IdempotencyKey__c + ' and ' + calls[1].IdempotencyKey__c);
		}
	}

	/**
	 * @description An API step whose handler sends a POST with no key does not declare itself safe to repeat. After the same
	 * stall, with the sweep running while a re-run could still execute, the watchdog does not send the request again: the
	 * chain ends Failed with the labelled reason, one callout, one call row, and the step's entry carries no declaration.
	 */
	@IsTest
	private static void shouldEndTheChainWhenAStalledUnkeyedPostStepCannotRunAgain()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(KEY_ROTATING_ONCE_SERVICE_NAME, false);

			String executionId = runChainThatStallsOnceThenSweep(new UTIL_AsyncChain.ApiStep(KeyRotatingOnceOutboundHandler.class));

			AsyncChainExecution__c result = queryExecution(executionId);
			String expectedReason = String.format(System.Label.AsyncChain_RecoveryStoppedAtStartedStep, new List<String> {KEY_ROTATING_ONCE_SERVICE_NAME});
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'Expected the sweep to stop the chain, got ' + result.Status__c);
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED, result.FailureCategory__c, 'Expected the Stalled category, got ' + result.FailureCategory__c);
			Assert.areEqual(expectedReason, result.ErrorMessage__c, 'Expected the labelled reason naming the step, got ' + result.ErrorMessage__c);
			Assert.areEqual(0, result.CompletedSteps__c, 'Expected no completed step, got ' + result.CompletedSteps__c);
			Integer callouts = API_MockFactory.getInvocationCount(KEY_ROTATING_ONCE_SERVICE_NAME);
			Assert.areEqual(1, callouts, 'Expected the request not to be sent again, got ' + callouts + ' callouts');
			List<ApiCall__c> calls = new SEL_ApiCall().findByServiceName(KEY_ROTATING_ONCE_SERVICE_NAME);
			Assert.areEqual(1, calls.size(), 'Expected one call row, got ' + calls.size());
			Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, calls[0].Status__c, 'Expected the one call to rest Completed, got ' + calls[0].Status__c);
			UTIL_AsyncChain.DTO_StepDefinition refusedStep = parseStepLog(result)[0];
			Assert.isNull(refusedStep.isIdempotent, 'Expected the build to store no idempotency declaration, got ' + refusedStep.isIdempotent);
			Assert.areEqual(true, refusedStep.started, 'Expected the step\'s start to stand, got ' + refusedStep.started);
			Assert.areEqual(false, refusedStep.success, 'Expected the started step marked as the failed step, got ' + refusedStep.success);
			Assert.areEqual(UTIL_String.abbreviate(expectedReason, STEP_MESSAGE_CAPACITY), refusedStep.message,
					'Expected the step message to carry the reason, got ' + refusedStep.message);
		}
	}

	/**
	 * @description An API step with no handler type, the shape the chain recreates by class name in each hop, cannot judge
	 * its request, so it gives the safe answer: not safe to repeat.
	 */
	@IsTest
	private static void shouldNotDeclareAnApiStepWithoutAHandlerIdempotent()
	{
		System.runAs(getTestAdmin())
		{
			Boolean isIdempotent = new UTIL_AsyncChain.ApiStep().isIdempotent();

			Assert.isFalse(isIdempotent, 'Expected an API step with no handler to answer false, got ' + isIdempotent);
		}
	}

	/**
	 * @description Judging an API step's request creates its handler, whose configure() opens a logging context for the
	 * call. The judgement clears it, so building a chain leaves no logging context behind for a call that was never made.
	 */
	@IsTest
	private static void shouldLeaveNoLoggingContextBehindWhenJudgingAnApiStep()
	{
		System.runAs(getTestAdmin())
		{
			Boolean isIdempotent = new UTIL_AsyncChain.ApiStep(KeyRotatingOnceReadOutboundHandler.class).isIdempotent();

			Assert.isTrue(isIdempotent, 'Expected a GET handler to be judged safe to repeat, got ' + isIdempotent);
			Assert.isTrue(LOG_Engine.webserviceContextsByCorrelation.isEmpty(), 'Expected no logging context left, got ' + LOG_Engine.webserviceContextsByCorrelation);
		}
	}

	/**
	 * @description A handler whose configure() throws cannot be asked about its request when the chain is built. Building the
	 * chain still succeeds, and the step stores no idempotency declaration, the safe answer.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldBuildTheChainWhenTheHandlerCannotBeConfigured()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(ConfigureFailingOutboundHandler.class))
					.execute();

			assertLaunchStoredNoDeclaration(executionId);
		}
	}

	/**
	 * @description A POST handler whose API setting cannot be read when the chain is built (the setting query throws) cannot
	 * prove its request is keyed. Building the chain still succeeds, and the step stores no idempotency declaration.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldBuildTheChainWhenTheHandlerSettingCannotBeRead()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			TST_Mock.throwsException(ApiSetting__mdt.SObjectType, new QueryException(SETTING_READ_FAILURE_MESSAGE));

			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChain.ApiStep(KeyRotatingOnceOutboundHandler.class))
					.execute();

			assertLaunchStoredNoDeclaration(executionId);
		}
	}

	/**
	 * @description A 504 to a POST with no key may follow a request the external system processed, so the chain does not
	 * re-run the step although retry budget is left: one callout, the step fails for good with the line that says why,
	 * the chain fails, and the one issue says the external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldStopTheStepWhenAnUnkeyedPostGetsAGatewayTimeout()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(SERVER_ERROR_SERVICE_NAME, false);
			registerServerErrorMock(API_Base.HTTP_GATEWAY_TIMEOUT);

			Test.startTest();
			String executionId = executeChainWithBudgetLeft(new UTIL_AsyncChain.ApiStep(FlakyServerErrorOutboundHandler.class));
			Test.stopTest();

			String expectedLine = String.format(System.Label.OutboundCall_ServerErrorNotRepeated, new List<Object> {SERVER_ERROR_SERVICE_NAME, API_Base.HTTP_GATEWAY_TIMEOUT});
			assertStepStoppedAfterOneCallout(executionId, SERVER_ERROR_SERVICE_NAME, expectedLine);
		}
	}

	/**
	 * @description A POST with no key that the external system accepted (201) before the handler's own handling of the
	 * response failed has already been acted on, so the chain does not re-run the step although retry budget is left:
	 * one callout, the step fails for good with the line that says why, the chain fails, and the one issue says the
	 * external system may have acted.
	 */
	@IsTest
	private static void shouldStopTheStepWhenAnUnkeyedPostFailsAfterTheExternalSystemAcceptedIt()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(ACCEPTED_THEN_FAILING_SERVICE_NAME, false);
			API_MockFactory.forService(ACCEPTED_THEN_FAILING_SERVICE_NAME).body(FLAKY_SUCCESS_BODY).statusCode(API_Base.HTTP_CREATED).register();

			Test.startTest();
			String executionId = executeChainWithBudgetLeft(new UTIL_AsyncChain.ApiStep(AcceptedThenFailingOutboundHandler.class));
			Test.stopTest();

			String expectedLine = String.format
					(
							System.Label.OutboundCall_ExternalSystemAcceptedBeforeFailure,
							new List<Object> {ACCEPTED_THEN_FAILING_SERVICE_NAME, String.valueOf(API_Base.HTTP_CREATED)}
					);
			ApiIssue__c issue = assertStepStoppedAfterOneCallout(executionId, ACCEPTED_THEN_FAILING_SERVICE_NAME, expectedLine);
			Assert.isTrue(issue.ErrorMessages__c.contains(ACCEPTED_THEN_FAILING_MESSAGE),
					'Expected the issue to carry the handler\'s own failure, got ' + issue.ErrorMessages__c);
		}
	}

	/**
	 * @description retryOn(...) names refusal statuses only: a step that names 201 still stops after the external system
	 * accepted a POST with no key (201) and the handler's own handling then failed. One callout, the step fails for good
	 * with the line that says why, and the one issue says the external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldStopTheStepAfterTheExternalSystemAcceptedItEvenWhenRetryOnNamesTheStatus()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(ACCEPTED_THEN_FAILING_SERVICE_NAME, false);
			API_MockFactory.forService(ACCEPTED_THEN_FAILING_SERVICE_NAME).body(FLAKY_SUCCESS_BODY).statusCode(API_Base.HTTP_CREATED).register();

			Test.startTest();
			String executionId = executeChainWithBudgetLeft(new UTIL_AsyncChain.ApiStep(AcceptedThenFailingOutboundHandler.class)
					.retryOn(new Set<Integer> {API_Base.HTTP_CREATED}));
			Test.stopTest();

			String expectedLine = String.format
					(
							System.Label.OutboundCall_ExternalSystemAcceptedBeforeFailure,
							new List<Object> {ACCEPTED_THEN_FAILING_SERVICE_NAME, String.valueOf(API_Base.HTTP_CREATED)}
					);
			assertStepStoppedAfterOneCallout(executionId, ACCEPTED_THEN_FAILING_SERVICE_NAME, expectedLine);
		}
	}

	/**
	 * @description A handler that leaves 500 out of its own retryable set has said less about retrying, never that a
	 * request that is not safe to repeat may be sent again: a 500 to a POST with no key whose handler retries only 503
	 * stops the step although retry budget is left. One callout, the step fails for good with the line that says why, the
	 * chain fails, and the one issue says the external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldStopTheStepWhenAnUnkeyedPostGetsAServerErrorItsHandlerLeavesOutOfItsRetryableSet()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(NARROW_RETRYABLE_SET_SERVICE_NAME, false);
			API_MockFactory.registerErrorMock(NARROW_RETRYABLE_SET_SERVICE_NAME);

			Test.startTest();
			String executionId = executeChainWithBudgetLeft(new UTIL_AsyncChain.ApiStep(NarrowRetryableSetOutboundHandler.class));
			Test.stopTest();

			String expectedLine = String.format
					(
							System.Label.OutboundCall_ServerErrorNotRepeated,
							new List<Object> {NARROW_RETRYABLE_SET_SERVICE_NAME, API_Base.HTTP_INTERNAL_SERVER_ERROR}
					);
			assertStepStoppedAfterOneCallout(executionId, NARROW_RETRYABLE_SET_SERVICE_NAME, expectedLine);
		}
	}

	/**
	 * @description A UTIL_Exceptions.PermanentFailureException is the handler's own word that the call must not be
	 * retried, so it stops the step whatever the method: a GET, which is safe to repeat, whose handling of a 200 throws
	 * one runs once, the step fails for good with the exception's message first, the chain fails, and the one issue says
	 * the external system may have acted (it accepted the request).
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldStopTheStepWhenTheHandlerThrowsAPermanentFailureOnARequestThatIsSafeToRepeat()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(PERMANENTLY_REFUSING_READ_SERVICE_NAME, false);
			API_MockFactory.forService(PERMANENTLY_REFUSING_READ_SERVICE_NAME).body(FLAKY_SUCCESS_BODY).statusCode(API_Base.HTTP_OK).register();

			Test.startTest();
			String executionId = executeChainWithBudgetLeft(new UTIL_AsyncChain.ApiStep(PermanentlyRefusingReadOutboundHandler.class));
			Test.stopTest();

			assertStepStoppedAfterOneCallout(executionId, PERMANENTLY_REFUSING_READ_SERVICE_NAME, PERMANENT_REFUSAL_MESSAGE);
		}
	}

	/**
	 * @description A UTIL_Exceptions.PermanentFailureException thrown by a hook the refusal read calls is the refusal it
	 * means: a 500 to a POST with no key makes the read ask the handler's retryable status set, which throws one, and the
	 * step stops after one callout although a second callout would succeed.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldStopTheStepWhenAHookOfTheRefusalReadThrowsAPermanentFailure()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(HOOK_REFUSING_POST_SERVICE_NAME, false);
			API_MockFactory.forService(HOOK_REFUSING_POST_SERVICE_NAME).body(SERVER_ERROR_BODY).statusCode(API_Base.HTTP_INTERNAL_SERVER_ERROR).register();

			Test.startTest();
			String executionId = executeChainWithBudgetLeft(new UTIL_AsyncChain.ApiStep(HookRefusingPostOutboundHandler.class));
			Test.stopTest();

			assertStepStoppedForGoodByAPermanentFailure(executionId, HOOK_REFUSING_POST_SERVICE_NAME);
		}
	}

	/**
	 * @description A permanent failure outranks a status the step names in retryOn(...): the hook that throws it is read
	 * after a 500 the step named, and the step still stops after one callout.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldLetAPermanentFailureFromAHookOutrankAStatusTheStepNamesInRetryOn()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(HOOK_REFUSING_POST_SERVICE_NAME, false);
			API_MockFactory.forService(HOOK_REFUSING_POST_SERVICE_NAME).body(SERVER_ERROR_BODY).statusCode(API_Base.HTTP_INTERNAL_SERVER_ERROR).register();

			Test.startTest();
			String executionId = executeChainWithBudgetLeft(new UTIL_AsyncChain.ApiStep(HookRefusingPostOutboundHandler.class)
					.retryOn(new Set<Integer> {API_Base.HTTP_INTERNAL_SERVER_ERROR}));
			Test.stopTest();

			assertStepStoppedForGoodByAPermanentFailure(executionId, HOOK_REFUSING_POST_SERVICE_NAME);
		}
	}

	/**
	 * @description The other order: the call first gets a 500 the step names in retryOn(...), then the handler's commit
	 * throws a permanent failure. The permanent failure still outranks the named status and the step stops after one
	 * callout.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldLetAPermanentFailureFromTheCommitOutrankAStatusTheStepNamesInRetryOn()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(COMMIT_REFUSING_POST_SERVICE_NAME, false);
			API_MockFactory.forService(COMMIT_REFUSING_POST_SERVICE_NAME).body(SERVER_ERROR_BODY).statusCode(API_Base.HTTP_INTERNAL_SERVER_ERROR).register();

			Test.startTest();
			String executionId = executeChainWithBudgetLeft(new UTIL_AsyncChain.ApiStep(CommitRefusingPostOutboundHandler.class)
					.retryOn(new Set<Integer> {API_Base.HTTP_INTERNAL_SERVER_ERROR}));
			Test.stopTest();

			assertStepStoppedForGoodByAPermanentFailure(executionId, COMMIT_REFUSING_POST_SERVICE_NAME);
		}
	}

	/**
	 * @description A status the step names in retryOn(...) is the author's own choice and is re-run whatever the method:
	 * a 504 to a POST with no key, then a 200, completes on the second attempt. The first attempt's issue still says the
	 * external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRerunAnUnkeyedPostAfterAGatewayTimeoutTheStepNamesInRetryOn()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(SERVER_ERROR_SERVICE_NAME, false);
			registerServerErrorMock(API_Base.HTTP_GATEWAY_TIMEOUT);

			Test.startTest();
			String executionId = executeChainWithBudgetLeft(new UTIL_AsyncChain.ApiStep(FlakyServerErrorOutboundHandler.class)
					.retryOn(new Set<Integer> {API_Base.HTTP_GATEWAY_TIMEOUT}));
			Test.stopTest();

			assertStepCompletedOnTheSecondAttempt(executionId, SERVER_ERROR_SERVICE_NAME, CALLOUTS_WHEN_BOTH_ATTEMPTS_ARE_SENT, true);
		}
	}

	/**
	 * @description A POST sent with a key (Idempotency Enabled) is safe to repeat, so a 504 and then a 200 completes on
	 * the second attempt, and the first attempt's issue does not say the external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRerunAKeyedPostAfterAGatewayTimeout()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(SERVER_ERROR_SERVICE_NAME, true);
			registerServerErrorMock(API_Base.HTTP_GATEWAY_TIMEOUT);

			Test.startTest();
			String executionId = executeChainWithBudgetLeft(new UTIL_AsyncChain.ApiStep(FlakyServerErrorOutboundHandler.class));
			Test.stopTest();

			assertStepCompletedOnTheSecondAttempt(executionId, SERVER_ERROR_SERVICE_NAME, CALLOUTS_WHEN_BOTH_ATTEMPTS_ARE_SENT, false);
		}
	}

	/**
	 * @description A GET is safe to repeat, so a call that got no response and then a 200 completes on the second
	 * attempt, and the first attempt's issue does not say the external system may have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRerunAGetThatGotNoResponse()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(FLAKY_READ_SERVICE_NAME, false);
			API_MockFactory.forService(FLAKY_READ_SERVICE_NAME).withTransportFailure().register();

			Test.startTest();
			String executionId = executeChainWithBudgetLeft(new UTIL_AsyncChain.ApiStep(FlakyReadOutboundHandler.class));
			Test.stopTest();

			assertStepCompletedOnTheSecondAttempt(executionId, FLAKY_READ_SERVICE_NAME, CALLOUTS_WHEN_BOTH_ATTEMPTS_ARE_SENT, false);
		}
	}

	/**
	 * @description A GET is safe to repeat, so a call the external system accepted (200) whose handling then failed, and
	 * then a call that succeeds, completes on the second attempt. The first attempt's issue still says the external
	 * system may have acted, because it did.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRerunAGetWhoseHandlingFailedAfterTheExternalSystemAcceptedIt()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(ACCEPTED_THEN_FAILING_ONCE_READ_SERVICE_NAME, false);
			API_MockFactory.forService(ACCEPTED_THEN_FAILING_ONCE_READ_SERVICE_NAME).body(FLAKY_SUCCESS_BODY).statusCode(API_Base.HTTP_OK).register();

			Test.startTest();
			String executionId = executeChainWithBudgetLeft(new UTIL_AsyncChain.ApiStep(AcceptedThenFailingOnceReadOutboundHandler.class));
			Test.stopTest();

			assertStepCompletedOnTheSecondAttempt(executionId, ACCEPTED_THEN_FAILING_ONCE_READ_SERVICE_NAME, CALLOUTS_WHEN_BOTH_ATTEMPTS_ARE_SENT, true);
		}
	}

	/**
	 * @description A 503 says the external system did not process the request, so a POST with no key that got a 503 and
	 * then a 200 completes on the second attempt, and the first attempt's issue does not say the external system may
	 * have acted.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRerunAnUnkeyedPostAfterServiceUnavailable()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(SERVER_ERROR_SERVICE_NAME, false);
			registerServerErrorMock(HTTP_STATUS_SERVICE_UNAVAILABLE);

			Test.startTest();
			String executionId = executeChainWithBudgetLeft(new UTIL_AsyncChain.ApiStep(FlakyServerErrorOutboundHandler.class));
			Test.stopTest();

			assertStepCompletedOnTheSecondAttempt(executionId, SERVER_ERROR_SERVICE_NAME, CALLOUTS_WHEN_BOTH_ATTEMPTS_ARE_SENT, false);
		}
	}

	/**
	 * @description A callout the platform refused before it left the org (the step had saved a record first) reached
	 * nothing, so a POST with no key is re-run and completes on the second attempt. The platform never ran the mock for
	 * the refused callout, so the mock counts one callout for two attempts, and the first attempt's issue does not say
	 * the external system may have acted.
	 */
	@IsTest
	private static void shouldRerunAnUnkeyedPostThePlatformRefusedBeforeItLeftTheOrg()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			registerStepServiceSetting(REFUSED_ONCE_SERVICE_NAME, false);
			API_MockFactory.forService(REFUSED_ONCE_SERVICE_NAME).body(FLAKY_SUCCESS_BODY).statusCode(API_Base.HTTP_OK).register();

			Test.startTest();
			String executionId = executeChainWithBudgetLeft(new UTIL_AsyncChain.ApiStep(RefusedOnceOutboundHandler.class));
			Test.stopTest();

			Assert.isTrue(hasProvokedTheRefusedCallout, 'Expected the first attempt to save a record before its callout, got no save');
			assertStepCompletedOnTheSecondAttempt(executionId, REFUSED_ONCE_SERVICE_NAME, CALLOUTS_WHEN_ONLY_THE_SECOND_ATTEMPT_IS_SENT, false);
		}
	}

	/**
	 * @description A call made through UTIL_HttpClient.useHandler(...) that got no response records its issue, as the
	 * same call dispatched directly does: the call ends Failed with no retry time and the line that says why, and one
	 * issue says the external system may have acted and carries that line.
	 */
	@IsTest
	private static void shouldLogTheIssueWhenADelegatedCallGetsNoResponse()
	{
		System.runAs(getTestAdmin())
		{
			registerStepServiceSetting(SERVER_ERROR_SERVICE_NAME, false);
			API_MockFactory.forService(SERVER_ERROR_SERVICE_NAME).withTransportFailure().register();

			Test.startTest();
			UTIL_HttpClient.useHandler(FlakyServerErrorOutboundHandler.class).invoke();
			Test.stopTest();

			String expectedLine = String.format(System.Label.OutboundCall_NoResponseNotRepeated, new List<Object> {SERVER_ERROR_SERVICE_NAME});
			ApiCall__c failedCall = SEL_ApiCall.assertServiceFailed(SERVER_ERROR_SERVICE_NAME, expectedLine)[0];
			Assert.isNull(failedCall.NextRetry__c, 'Expected no next retry time, got ' + failedCall.NextRetry__c);
			Assert.areEqual(0, (failedCall.Retries__c ?? 0).intValue(), 'Expected no attempt spent on the call, got ' + failedCall.Retries__c);
			Integer callouts = API_MockFactory.getInvocationCount(SERVER_ERROR_SERVICE_NAME);
			Assert.areEqual(1, callouts, 'Expected one callout, got ' + callouts);

			List<ApiIssue__c> issues = new SEL_ApiIssue().getAll();
			Assert.areEqual(1, issues.size(), 'Expected one issue, got ' + issues.size());
			Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue to say the external system may have acted, got false');
			Assert.isTrue(issues[0].ErrorMessages__c.contains(expectedLine), 'Expected the issue to carry the line that says why, got ' + issues[0].ErrorMessages__c);
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
	 * @description Executes a single ApiStep chain wrapping API_PostExample where the chain owns the
	 * retry budget (withRetry). The suppression tests all use this shape.
	 *
	 * @param record The Foobar__c record to use as the triggering record.
	 *
	 * @return The execution record ID.
	 */
	private static String executeSingleApiStepChainWithRetry(Foobar__c record)
	{
		return UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
				.then(new UTIL_AsyncChain.ApiStep(API_PostExample.class)
						.triggeringRecord(record.Id)
						.withParameter(API_PostExample.PARAMETER_NAME, 'test')
						.withRetry(CHAIN_RETRY_MAX_ATTEMPTS, CHAIN_RETRY_BACKOFF_SECONDS))
				.withAsyncOptions(createAsyncOptions(3))
				.execute();
	}

	/**
	 * @description Registers the ApiSetting__mdt fixture that lets the outbound engine schedule its
	 * own retries for the ApiStep service: a positive retry budget with a non-zero backoff, so any
	 * unsuppressed failure self-schedules (Status Retry, NextRetry__c stamped). Idempotency Enabled
	 * makes the step's POST safe to repeat, so the mocked 500 is a failure the engine may retry: a
	 * POST without an Idempotency-Key that gets a 500 is never retried, which would leave nothing to suppress.
	 */
	private static void mockOutboundEngineRetrySetting()
	{
		TST_Factory.newOutboundApiSetting(API_STEP_SERVICE_NAME, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MaxRetryCount__c => OUTBOUND_ENGINE_MAX_RETRY_COUNT,
				ApiSetting__mdt.RetryBackoffSeconds__c => OUTBOUND_ENGINE_RETRY_BACKOFF_SECONDS,
				ApiSetting__mdt.IdempotencyEnabled__c => true
		});
	}

	/**
	 * @description Registers the one ApiSetting__mdt a test's step service runs with: retry budget left for the outbound
	 * engine, issues logged, and Idempotency Enabled as given, which decides whether a POST is sent with a key.
	 *
	 * @param serviceName The step's service name.
	 * @param isIdempotencyEnabled True to send the POST with a key, so a repeat is safe.
	 */
	private static void registerStepServiceSetting(String serviceName, Boolean isIdempotencyEnabled)
	{
		TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MaxRetryCount__c => OUTBOUND_ENGINE_MAX_RETRY_COUNT,
				ApiSetting__mdt.RetryBackoffSeconds__c => OUTBOUND_ENGINE_RETRY_BACKOFF_SECONDS,
				ApiSetting__mdt.LogIssues__c => true,
				ApiSetting__mdt.IdempotencyEnabled__c => isIdempotencyEnabled
		});
	}

	/**
	 * @description Registers the mock the first call of FlakyServerErrorOutboundHandler gets: the given error status.
	 *
	 * @param statusCode The error status the external system responds with.
	 */
	private static void registerServerErrorMock(Integer statusCode)
	{
		API_MockFactory.forService(SERVER_ERROR_SERVICE_NAME).body(SERVER_ERROR_BODY).statusCode(statusCode).register();
	}

	/**
	 * @description Runs a one-step chain whose step has chain retry on with budget left (three attempts, no wait).
	 *
	 * @param step The API step, without its retry setting.
	 *
	 * @return The execution record ID.
	 */
	private static String executeChainWithBudgetLeft(UTIL_AsyncChain.ApiStep step)
	{
		return UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
				.then(step.withRetry(CHAIN_RETRY_ATTEMPTS_WITH_BUDGET_LEFT, CHAIN_RETRY_BACKOFF_SECONDS))
				.withAsyncOptions(createAsyncOptions(CHAIN_RETRY_STACK_DEPTH))
				.execute();
	}

	/**
	 * @description Asserts what is left after the chain did not re-run a step because the external system may have
	 * acted on a request that is not safe to repeat: the chain failed with a step error (not an exhausted budget) and
	 * carries the line that says why; the step's one attempt failed for good; one callout and one call row, Failed with
	 * no retry time; one issue, which says the external system may have acted and carries the line.
	 *
	 * @param executionId The execution record ID.
	 * @param serviceName The step's service name.
	 * @param expectedLine The labelled line that says why the request was not sent again.
	 *
	 * @return The one issue.
	 */
	private static ApiIssue__c assertStepStoppedAfterOneCallout(String executionId, String serviceName, String expectedLine)
	{
		UTIL_AsyncChain.DTO_StepDefinition step = assertStepFailedForGoodAfterOneCallout(executionId, serviceName, expectedLine);
		String expectedMessageStart = serviceName + ' failed: ' + expectedLine.left(LINE_CHARACTERS_KEPT_IN_STEP_LOG);
		Assert.isTrue(step.message.startsWith(expectedMessageStart), 'Expected the step message to start with "' + expectedMessageStart + '", got ' + step.message);

		ApiCall__c call = new SEL_ApiCall().findByServiceName(serviceName)[0];
		Assert.areEqual(0, (call.Retries__c ?? 0).intValue(), 'Expected no attempt spent on the call, got ' + call.Retries__c);

		List<ApiIssue__c> issues = new SEL_ApiIssue().getAll();
		Assert.areEqual(1, issues.size(), 'Expected one issue, got ' + issues.size());
		Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue to say the external system may have acted, got false');
		return issues[0];
	}

	/**
	 * @description Asserts what is left after a UTIL_Exceptions.PermanentFailureException stopped a step: the chain failed
	 * with a step error (not an exhausted budget, as budget was left) and its message carries the permanent failure; the
	 * step ran once and failed for good; the external system was called once and the call row is Failed with no retry
	 * time.
	 *
	 * @param executionId The execution record ID.
	 * @param serviceName The step's service name.
	 */
	private static void assertStepStoppedForGoodByAPermanentFailure(String executionId, String serviceName)
	{
		assertStepFailedForGoodAfterOneCallout(executionId, serviceName, PERMANENT_REFUSAL_MESSAGE);
	}

	/**
	 * @description Asserts what every step that failed for good on its one attempt leaves behind: the chain failed with a
	 * step error (not an exhausted budget) and its message carries the given text; the step ran once and failed for good;
	 * the external system was called once, and the one call row is Failed with no retry time.
	 *
	 * @param executionId The execution record ID.
	 * @param serviceName The step's service name.
	 * @param expectedChainMessageText Text the chain's error message must carry.
	 *
	 * @return The step's entry from the step log, for the caller's own checks.
	 */
	private static UTIL_AsyncChain.DTO_StepDefinition assertStepFailedForGoodAfterOneCallout(String executionId, String serviceName, String expectedChainMessageText)
	{
		AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Expected the chain to fail, got ' + execution.Status__c);
		Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, execution.FailureCategory__c,
				'Expected a step error, not an exhausted budget, got ' + execution.FailureCategory__c);
		Assert.isTrue(execution.ErrorMessage__c.contains(expectedChainMessageText), 'Expected the chain error to carry "' + expectedChainMessageText + '", got '
				+ execution.ErrorMessage__c);

		UTIL_AsyncChain.DTO_StepDefinition step = parseStepLog(execution)[0];
		Assert.isNull(step.attempt, 'Expected the step to run once, with no second attempt recorded, got attempt ' + step.attempt);
		Assert.areEqual(false, step.success, 'Expected the step to fail, got ' + step.success);
		Assert.areEqual(true, step.permanentFailure, 'Expected the step to fail for good, got ' + step.permanentFailure);

		Integer callouts = API_MockFactory.getInvocationCount(serviceName);
		Assert.areEqual(1, callouts, 'Expected one callout, got ' + callouts);
		List<ApiCall__c> calls = new SEL_ApiCall().findByServiceName(serviceName);
		Assert.areEqual(1, calls.size(), 'Expected one call row, got ' + calls.size());
		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, calls[0].Status__c, 'Expected the call to rest at Failed, got ' + calls[0].Status__c);
		Assert.isNull(calls[0].NextRetry__c, 'Expected no next retry time, got ' + calls[0].NextRetry__c);
		return step;
	}

	/**
	 * @description Asserts what is left after the chain re-ran a step to success: the chain completed; the step's
	 * second attempt succeeded; the mock ran the given number of times; two call rows, the first Failed with no retry
	 * time and the second Completed; one issue, from the first attempt, whose flag is as given.
	 *
	 * @param executionId The execution record ID.
	 * @param serviceName The step's service name.
	 * @param expectedCallouts The number of times the mock responded.
	 * @param isExternalSystemExpectedToHaveActed The flag the first attempt's issue must carry.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static void assertStepCompletedOnTheSecondAttempt(String executionId, String serviceName, Integer expectedCallouts, Boolean isExternalSystemExpectedToHaveActed)
	{
		AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c,
				'Expected the chain to complete, got ' + execution.Status__c + ': ' + execution.ErrorMessage__c);
		UTIL_AsyncChain.DTO_StepDefinition step = parseStepLog(execution)[0];
		Assert.areEqual(SECOND_ATTEMPT, step.attempt, 'Expected the step to succeed on its second attempt, got attempt ' + step.attempt);
		Assert.areEqual(true, step.success, 'Expected the step to succeed, got ' + step.success);

		Integer callouts = API_MockFactory.getInvocationCount(serviceName);
		Assert.areEqual(expectedCallouts, callouts, 'Expected ' + expectedCallouts + ' callouts, got ' + callouts);
		List<ApiCall__c> calls = new SEL_ApiCall().findByServiceName(serviceName);
		Assert.areEqual(SECOND_ATTEMPT, calls.size(), 'Expected one call row per attempt, got ' + calls.size());
		List<String> statuses = new List<String>();
		for(ApiCall__c call : calls)
		{
			Assert.isNull(call.NextRetry__c, 'Expected no next retry time on a call the chain owns, got ' + call.NextRetry__c);
			statuses.add(call.Status__c);
		}
		statuses.sort();
		Assert.areEqual(new List<String> {SEL_ApiCall.STATUS_COMPLETED, SEL_ApiCall.STATUS_FAILED}, statuses, 'Expected one Completed and one Failed call row, got ' + statuses);

		List<ApiIssue__c> issues = new SEL_ApiIssue().getAll();
		Assert.areEqual(1, issues.size(), 'Expected one issue, from the first attempt, got ' + issues.size());
		Assert.areEqual(isExternalSystemExpectedToHaveActed, issues[0].ExternalSystemMayHaveActed__c,
				'Expected the issue flag ' + isExternalSystemExpectedToHaveActed + ', got ' + issues[0].ExternalSystemMayHaveActed__c);
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
	 * @description Parses the StepLog__c JSON from an execution record into the definition list.
	 *
	 * @param execution The execution record containing StepLog__c.
	 *
	 * @return The deserialized step definition list.
	 */
	private static List<UTIL_AsyncChain.DTO_StepDefinition> parseStepLog(AsyncChainExecution__c execution)
	{
		return (List<UTIL_AsyncChain.DTO_StepDefinition>)JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
	}

	/**
	 * @description Reads the minimum enqueue delay the currently executing queueable was scheduled
	 * with, via System.AsyncInfo.
	 *
	 * @return The delay in minutes as a string, or 'none' when no minimum delay was requested.
	 */
	private static String observedEnqueueDelay()
	{
		Integer minimumDelay = System.AsyncInfo.getMinimumQueueableDelayInMinutes();
		return minimumDelay == null ? 'none' : String.valueOf(minimumDelay);
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
	 * @description Step that fails transiently until its third attempt, under a two-retry zero-backoff
	 * strategy. Records the attempt stamp it observes from inside work() on every attempt.
	 */
	public class EventuallySucceedsStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Records the attempt number and finality reading it observes under an ATTEMPT_STAMP_KEY_PREFIX key, fails on attempts one
		 * and two, and succeeds from attempt three.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A failed result before the third attempt, a succeeded result from the third attempt on.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put(ATTEMPT_STAMP_KEY_PREFIX + context.getAttempt(), context.getAttempt() + ':' + context.isFinalAttempt());
			if(context.getAttempt() < 3)
			{
				return UTIL_AsyncChain.failed('Transient failure on attempt ' + context.getAttempt());
			}
			return UTIL_AsyncChain.succeeded();
		}

		/**
		 * @description Allows two retries with no backoff, so the third attempt runs inside the test window.
		 *
		 * @return An exponential strategy capped at two retries with a zero base backoff.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return UTIL_Retry.exponential().withMaxRetries(2).withBaseBackoff(0);
		}
	}

	/**
	 * @description Step that fails on every attempt, under a single-retry zero-backoff strategy.
	 */
	public class AlwaysFailsWithRetryStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Fails on every attempt, naming the attempt in the message.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed('Permanent failure, attempt ' + context.getAttempt());
		}

		/**
		 * @description Allows a single retry with no backoff.
		 *
		 * @return An exponential strategy capped at one retry with a zero base backoff.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return UTIL_Retry.exponential().withMaxRetries(1).withBaseBackoff(0);
		}
	}

	/**
	 * @description Step that throws a deterministic exception under an allowlist retry strategy
	 * permitting only CalloutException retries, so the thrown type is filter-denied.
	 */
	public class ThrowingRetryAllowlistStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Throws an IllegalStateException on every attempt.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return Never; every call throws instead.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException On every call.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			throw new UTIL_Exceptions.IllegalStateException('Deterministic failure');
		}

		/**
		 * @description Allows three retries with no backoff, but only for CalloutException, so the IllegalStateException this step throws
		 * is filter-denied.
		 *
		 * @return An allowlist strategy that retries CalloutException only, capped at three retries.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return UTIL_Retry.retryOnlyOnException(
					UTIL_Retry.exponential().withMaxRetries(3).withBaseBackoff(0),
					new Set<Type> {System.CalloutException.class});
		}
	}

	/**
	 * @description Step that fails its first attempt under a single-retry strategy with a two-minute
	 * backoff, recording the enqueue delay each attempt's transaction observes via System.AsyncInfo.
	 */
	public class DelayRecordingRetryStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Records the enqueue delay this attempt's transaction observes under an OBSERVED_DELAY_KEY_PREFIX key, fails on
		 * attempt one and succeeds from attempt two.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A failed result on the first attempt, a succeeded result afterwards.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put(OBSERVED_DELAY_KEY_PREFIX + 'Step0Attempt' + context.getAttempt(), observedEnqueueDelay());
			if(context.getAttempt() < 2)
			{
				return UTIL_AsyncChain.failed('Transient failure for the delay inheritance test');
			}
			return UTIL_AsyncChain.succeeded();
		}

		/**
		 * @description Allows a single retry after DELAY_INHERITANCE_BACKOFF_SECONDS of backoff, so the retried attempt is enqueued with an observable delay.
		 *
		 * @return An exponential strategy capped at one retry with DELAY_INHERITANCE_BACKOFF_SECONDS as its base backoff.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return UTIL_Retry.exponential().withMaxRetries(1).withBaseBackoff(DELAY_INHERITANCE_BACKOFF_SECONDS);
		}
	}

	/**
	 * @description Step that records the enqueue delay its transaction observes via System.AsyncInfo.
	 * Placed after a retrying step to observe what a post-recovery hop inherits.
	 */
	public class DelayRecordingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Records the enqueue delay this transaction observes under the Step1 OBSERVED_DELAY_KEY_PREFIX key, then succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put(OBSERVED_DELAY_KEY_PREFIX + 'Step1', observedEnqueueDelay());
			return UTIL_AsyncChain.succeeded();
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
	 * @description Outbound handler fixture whose mock fails once and then succeeds. Each chain
	 * attempt constructs a fresh handler instance (configure() runs from the API_Base constructor),
	 * so the sequential response is driven by the API_MockFactory invocation count: the error mock
	 * the test registers stays in place for the first callout, and flips to a success mock once
	 * that first callout has been recorded.
	 */
	public class FlakyOutboundHandler extends API_Outbound
	{
		/**
		 * @description Configures the fixture: no triggering record required, and flips the
		 * registered mock to a success response once the first callout has been recorded.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = FLAKY_SUCCESS_BODY;

			if(API_MockFactory.getInvocationCount(FLAKY_SERVICE_NAME) >= 1)
			{
				API_MockFactory.forService(FLAKY_SERVICE_NAME)
						.body(FLAKY_SUCCESS_BODY)
						.statusCode(API_Base.HTTP_OK)
						.register();
			}
		}
	}

	/**
	 * @description Outbound fixture whose first call fails with a retryable server error and whose
	 * later calls succeed, so retryOn tests can prove an in-filter status is retried to success.
	 * The test registers the failing mock; configure() flips it to success once a call has run.
	 */
	public class FlakyServerErrorOutboundHandler extends API_Outbound
	{
		/**
		 * @description Configures the fixture: no triggering record required, and flips the
		 * registered mock to a success response once the first callout has been recorded.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = FLAKY_SUCCESS_BODY;

			if(API_MockFactory.getInvocationCount(SERVER_ERROR_SERVICE_NAME) >= 1)
			{
				API_MockFactory.forService(SERVER_ERROR_SERVICE_NAME)
						.body(FLAKY_SUCCESS_BODY)
						.statusCode(API_Base.HTTP_OK)
						.register();
			}
		}
	}

	/**
	 * @description A GET whose first call fails and whose later calls succeed. The test registers the failing mock;
	 * configure() flips it to success once a call has run.
	 */
	public class FlakyReadOutboundHandler extends API_Outbound
	{
		/**
		 * @description Configures the fixture: no triggering record required, and flips the registered mock to a success
		 * response once the first callout has been recorded.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = FLAKY_SUCCESS_BODY;

			if(API_MockFactory.getInvocationCount(FLAKY_READ_SERVICE_NAME) >= 1)
			{
				API_MockFactory.forService(FLAKY_READ_SERVICE_NAME).body(FLAKY_SUCCESS_BODY).statusCode(API_Base.HTTP_OK).register();
			}
		}

		/**
		 * @description A GET, so a repeat is safe.
		 *
		 * @return GET.
		 */
		public override HttpMethod getHttpMethod()
		{
			return HttpMethod.GET;
		}
	}

	/**
	 * @description A POST whose handler retries only 503, whose first call fails and whose later calls succeed. The test
	 * registers the failing mock; configure() flips it to success once a call has run.
	 */
	public class NarrowRetryableSetOutboundHandler extends API_Outbound
	{
		/**
		 * @description Configures the fixture: no triggering record required, and flips the registered mock to a success
		 * response once the first callout has been recorded.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = FLAKY_SUCCESS_BODY;

			if(API_MockFactory.getInvocationCount(NARROW_RETRYABLE_SET_SERVICE_NAME) >= 1)
			{
				API_MockFactory.forService(NARROW_RETRYABLE_SET_SERVICE_NAME).body(FLAKY_SUCCESS_BODY).statusCode(API_Base.HTTP_OK).register();
			}
		}

		/**
		 * @description Retries only 503, so every other status ends the call by the handler's own choice.
		 *
		 * @return The one retryable status, 503.
		 */
		public override Set<Integer> getRetryableStatusCodes()
		{
			return new Set<Integer> {HTTP_STATUS_SERVICE_UNAVAILABLE};
		}
	}

	/**
	 * @description A POST whose external system accepts the request and whose own handling of the response then fails,
	 * on every call.
	 */
	public class AcceptedThenFailingOutboundHandler extends API_Outbound
	{
		/**
		 * @description Configures the fixture: no triggering record required.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = FLAKY_SUCCESS_BODY;
		}

		/**
		 * @description Fails after the external system accepted the request.
		 */
		public override void onSuccess()
		{
			throw new UTIL_Exceptions.IllegalStateException(ACCEPTED_THEN_FAILING_MESSAGE);
		}
	}

	/**
	 * @description A POST with no key whose external system accepts the request, and whose handler then rotates the chain's
	 * run key. Because the run key changed, the engine refuses the progress write of the hop that ran it. So the record
	 * keeps the step's start and never receives its result. A hop leaves the same shape when the platform ends it between
	 * the callout and the write.
	 */
	public class KeyRotatingAfterCalloutOutboundHandler extends API_Outbound
	{
		/**
		 * @description Configures the fixture: no triggering record required, a success body by default.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = FLAKY_SUCCESS_BODY;
		}

		/**
		 * @description Rotates the run key of the run named by executionIdWhoseKeyRotatesAfterTheCallout, once the external
		 * system has responded.
		 */
		public override void onSuccess()
		{
			rotateRunKey(executionIdWhoseKeyRotatesAfterTheCallout);
		}
	}

	/**
	 * @description A GET whose external system accepts every request, and whose handler rotates the chain's run key after
	 * its first call only: the first hop loses its progress write, a later run of the step completes.
	 */
	public class KeyRotatingOnceReadOutboundHandler extends API_Outbound
	{
		/**
		 * @description Configures the fixture: no triggering record required, a success body by default.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = FLAKY_SUCCESS_BODY;
		}

		/**
		 * @description A GET, so a repeat is safe.
		 *
		 * @return GET.
		 */
		public override HttpMethod getHttpMethod()
		{
			return HttpMethod.GET;
		}

		/**
		 * @description Rotates the run key after the first call only.
		 */
		public override void onSuccess()
		{
			rotateRunKeyAfterTheFirstCallout(KEY_ROTATING_ONCE_READ_SERVICE_NAME);
		}
	}

	/**
	 * @description A POST whose external system accepts every request, and whose handler rotates the chain's run key after
	 * its first call only. Whether it is sent with a key is decided by the API setting the test registers.
	 */
	public class KeyRotatingOnceOutboundHandler extends API_Outbound
	{
		/**
		 * @description Configures the fixture: no triggering record required, a success body by default.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = FLAKY_SUCCESS_BODY;
		}

		/**
		 * @description Rotates the run key after the first call only.
		 */
		public override void onSuccess()
		{
			rotateRunKeyAfterTheFirstCallout(KEY_ROTATING_ONCE_SERVICE_NAME);
		}
	}

	/**
	 * @description A handler whose configure() always throws, so it cannot be created.
	 */
	public class ConfigureFailingOutboundHandler extends API_Outbound
	{
		/**
		 * @description Throws before the handler is configured.
		 */
		public override void configure()
		{
			throw new UTIL_Exceptions.IllegalStateException(CONFIGURE_FAILURE_MESSAGE);
		}
	}

	/**
	 * @description Runs the chain watchdog's sweep as a queued job, so a sweep can follow a chain's hop inside one test
	 * window and whatever it queues still runs before the window closes.
	 */
	@SuppressWarnings('PMD.QueueableWithoutFinalizer')
	public class WatchdogSweepJob implements Queueable
	{
		/**
		 * @description Sweeps every Running or Stalled chain, whatever its age.
		 *
		 * @param context The queueable context; unused.
		 */
		public void execute(QueueableContext context)
		{
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
		}
	}

	/**
	 * @description A GET whose external system accepts every request and whose own handling of the response fails after
	 * the first call only.
	 */
	public class AcceptedThenFailingOnceReadOutboundHandler extends API_Outbound
	{
		/**
		 * @description Configures the fixture: no triggering record required.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = FLAKY_SUCCESS_BODY;
		}

		/**
		 * @description A GET, so a repeat is safe.
		 *
		 * @return GET.
		 */
		public override HttpMethod getHttpMethod()
		{
			return HttpMethod.GET;
		}

		/**
		 * @description Fails after the first call the external system accepted, and succeeds after every later one.
		 */
		public override void onSuccess()
		{
			if(API_MockFactory.getInvocationCount(ACCEPTED_THEN_FAILING_ONCE_READ_SERVICE_NAME) == 1)
			{
				throw new UTIL_Exceptions.IllegalStateException(ACCEPTED_THEN_FAILING_MESSAGE);
			}
		}
	}

	/**
	 * @description A POST with no key whose first call gets the error the test registers and whose later calls succeed. Its
	 * retryable status set throws UTIL_Exceptions.PermanentFailureException; the refusal read asks for that set only after a
	 * 500, 502 or 504 to a request that is not safe to repeat.
	 */
	public class HookRefusingPostOutboundHandler extends API_Outbound
	{
		/**
		 * @description Configures the fixture: no triggering record required, and flips the registered mock to a success
		 * response once the first callout has been recorded.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = FLAKY_SUCCESS_BODY;

			if(API_MockFactory.getInvocationCount(HOOK_REFUSING_POST_SERVICE_NAME) >= 1)
			{
				API_MockFactory.forService(HOOK_REFUSING_POST_SERVICE_NAME).body(FLAKY_SUCCESS_BODY).statusCode(API_Base.HTTP_OK).register();
			}
		}

		/**
		 * @description Says the call must not be retried.
		 *
		 * @return Never returns.
		 */
		public override Set<Integer> getRetryableStatusCodes()
		{
			throw new UTIL_Exceptions.PermanentFailureException(PERMANENT_REFUSAL_MESSAGE);
		}
	}

	/**
	 * @description A POST with no key whose first call gets the error the test registers and whose later calls succeed. The
	 * start of its commit throws UTIL_Exceptions.PermanentFailureException, after the call got its response.
	 */
	public class CommitRefusingPostOutboundHandler extends API_Outbound
	{
		/**
		 * @description Configures the fixture: no triggering record required, and flips the registered mock to a success
		 * response once the first callout has been recorded.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = FLAKY_SUCCESS_BODY;

			if(API_MockFactory.getInvocationCount(COMMIT_REFUSING_POST_SERVICE_NAME) >= 1)
			{
				API_MockFactory.forService(COMMIT_REFUSING_POST_SERVICE_NAME).body(FLAKY_SUCCESS_BODY).statusCode(API_Base.HTTP_OK).register();
			}
		}

		/**
		 * @description Says the call must not be retried, as the commit starts.
		 */
		public override void onCommitWorkStarting()
		{
			throw new UTIL_Exceptions.PermanentFailureException(PERMANENT_REFUSAL_MESSAGE);
		}
	}

	/**
	 * @description A GET whose handling of every response throws UTIL_Exceptions.PermanentFailureException.
	 */
	public class PermanentlyRefusingReadOutboundHandler extends API_Outbound
	{
		/**
		 * @description Configures the fixture: no triggering record required.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = FLAKY_SUCCESS_BODY;
		}

		/**
		 * @description A GET, so a repeat is safe.
		 *
		 * @return GET.
		 */
		public override HttpMethod getHttpMethod()
		{
			return HttpMethod.GET;
		}

		/**
		 * @description Says the call must not be retried.
		 */
		public override void onSuccess()
		{
			throw new UTIL_Exceptions.PermanentFailureException(PERMANENT_REFUSAL_MESSAGE);
		}
	}

	/**
	 * @description A POST whose first callout the platform refuses before it leaves the org: before that callout it saves
	 * a record, which leaves unsaved work in the transaction. Later callouts save nothing first and are sent. It declares
	 * no default mock body, so the callout goes through the platform (the registered mock responds to it) rather than
	 * being handled in memory.
	 */
	public class RefusedOnceOutboundHandler extends API_Outbound
	{
		/**
		 * @description Configures the fixture: no triggering record required.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
		}

		/**
		 * @description Saves a record before the first callout only, then builds the body as usual.
		 *
		 * @return The request body.
		 */
		public override String getBody()
		{
			if(!hasProvokedTheRefusedCallout)
			{
				hasProvokedTheRefusedCallout = true;
				TST_Builder.of(Foobar__c.SObjectType).build();
			}
			return super.getBody();
		}
	}

	/**
	 * @description Step that declares its failure permanent on the first attempt while carrying a
	 * retry strategy with remaining budget, so tests can prove the declaration outranks the budget.
	 */
	public class PermanentlyFailingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Declares the failure permanent on the first attempt.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A permanently failed result carrying PERMANENT_FAILURE_MESSAGE.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failedPermanently(PERMANENT_FAILURE_MESSAGE);
		}

		/**
		 * @description Allows two retries with no backoff, giving the permanent declaration a retry budget to outrank.
		 *
		 * @return An exponential strategy capped at two retries with a zero base backoff.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return UTIL_Retry.exponential().withMaxRetries(2).withBaseBackoff(0);
		}
	}

	/**
	 * @description Step that fails plainly on attempt one and permanently on attempt two, so tests
	 * can prove a genuine retry followed by a permanent verdict records StepException, never
	 * RetriesExhausted: the second attempt refused the remaining budget rather than consuming it.
	 */
	public class TransientThenPermanentStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Fails plainly on attempt one and permanently on attempt two.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A failed result on the first attempt, a permanently failed result on the second.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			if(context.getAttempt() < 2)
			{
				return UTIL_AsyncChain.failed(TRANSIENT_FAILURE_MESSAGE);
			}
			return UTIL_AsyncChain.failedPermanently(PERMANENT_FAILURE_MESSAGE);
		}

		/**
		 * @description Allows two retries with no backoff, so the second attempt still has budget left to refuse.
		 *
		 * @return An exponential strategy capped at two retries with a zero base backoff.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return UTIL_Retry.exponential().withMaxRetries(2).withBaseBackoff(0);
		}
	}

	/**
	 * @description Step that RETURNS (never throws) a failed result carrying an exception the
	 * allowlist does not match. It checks the dispatch behaviour the ApexDoc states:
	 * exception filters apply to a returned failed(exception) exactly as to a thrown one.
	 */
	public class ReturnsFilterDeniedExceptionStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Returns, rather than throws, a failed result carrying an IllegalStateException the allowlist does not match.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A failed result carrying the exception.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed(new UTIL_Exceptions.IllegalStateException(PERMANENT_FAILURE_MESSAGE));
		}

		/**
		 * @description Allows three retries with no backoff, but only for CalloutException, so the returned IllegalStateException is filter-denied.
		 *
		 * @return An allowlist strategy that retries CalloutException only, capped at three retries.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return UTIL_Retry.retryOnlyOnException(
					UTIL_Retry.exponential().withMaxRetries(3).withBaseBackoff(0),
					new Set<Type> {System.CalloutException.class});
		}
	}

	/**
	 * @description Successor step that records whether the previous step's persisted result still
	 * carries its permanent-failure flag after the cross-transaction round trip.
	 */
	public class PermanentFlagReaderStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Copies the previous step result's permanent-failure flag into the context under PERMANENT_FLAG_SEEN_KEY, then succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put(PERMANENT_FLAG_SEEN_KEY, context.getPreviousStepResult()?.permanentFailure);
			return UTIL_AsyncChain.succeeded();
		}
	}

	/**
	 * @description Step that records, from inside work() on attempt one of an allowlisted
	 * three-attempt budget, what the exception-aware probe answers for a filter-denied exception
	 * (final), a filter-allowed exception (not final), and the budget-only reading (not final).
	 */
	public class FinalityProbeRecordingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Records three finality readings into the context: the probe answer for a filter-denied exception (PROBE_DENIED_KEY), for a
		 * filter-allowed exception (PROBE_ALLOWED_KEY) and for the retry budget alone (PROBE_BUDGET_KEY); then succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put(PROBE_DENIED_KEY, context.isFinalAttempt(new UTIL_Exceptions.IllegalStateException(PERMANENT_FAILURE_MESSAGE)));
			context.put(PROBE_ALLOWED_KEY, context.isFinalAttempt(new System.CalloutException(TRANSIENT_FAILURE_MESSAGE)));
			context.put(PROBE_BUDGET_KEY, context.isFinalAttempt());
			return UTIL_AsyncChain.succeeded();
		}

		/**
		 * @description Allows two retries with no backoff, but only for CalloutException, so the probe has both a denied and an allowed exception type to read.
		 *
		 * @return An allowlist strategy that retries CalloutException only, capped at two retries.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return UTIL_Retry.retryOnlyOnException(
					UTIL_Retry.exponential().withMaxRetries(2).withBaseBackoff(0),
					new Set<Type> {System.CalloutException.class});
		}
	}

	/**
	 * @description onError handler that records what isFinalAttempt() reads inside the handler
	 * transaction, so tests can prove the post-denial re-stamp reaches the handler: before the
	 * fix a filter-denied retry left the pre-work false in place, and the handler was lied to.
	 */
	public class FinalityRecordingErrorHandlerStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Records what isFinalAttempt() answers inside the handler transaction under HANDLER_FINALITY_KEY, then succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put(HANDLER_FINALITY_KEY, context.isFinalAttempt());
			return UTIL_AsyncChain.succeeded();
		}
	}

	/**
	 * @description Step that declares idempotency by overriding isIdempotent(), with no constructor, as a
	 * subscriber writes it, and succeeds. shouldExposeIdempotentDeclarationOnChainStep uses it to drive
	 * the declaration through the real execution path.
	 */
	public class IdempotentDeclaringStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Declares the step safe to re-run, with no constructor, the way a subscriber's step does it.
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
	 * @description Rotates the run key on the given execution record, simulating another actor claiming the chain while the
	 * current executor is still in flight. The run key no longer matches, so the engine refuses that executor's progress
	 * write.
	 *
	 * @param executionId The execution record whose run key to rotate.
	 */
	private static void rotateRunKey(String executionId)
	{
		AsyncChainExecution__c row = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.Id, (Id)executionId)
				.withOverride(AsyncChainExecution__c.RunKey__c, UTIL_Random.randomUUID())
				.withOptionalField(AsyncChainExecution__c.ChainName__c)
				.withoutInsertion()
				.build();
		DML_Builder.newTransaction().systemModeInternal().doUpdate(row).execute();
	}

	/**
	 * @description Rotates the run key of the run named by executionIdWhoseKeyRotatesAfterTheCallout on the first call of
	 * the given service only, so the first hop loses its progress write and a later run of the same step completes.
	 *
	 * @param serviceName The service whose callout count decides whether this is its first call.
	 */
	private static void rotateRunKeyAfterTheFirstCallout(String serviceName)
	{
		if(API_MockFactory.getInvocationCount(serviceName) == 1)
		{
			rotateRunKey(executionIdWhoseKeyRotatesAfterTheCallout);
		}
	}

	/**
	 * @description Launches a one-step chain around the given API step and queues a watchdog sweep behind it, both inside
	 * one test window: the step's first hop sends its request and loses its progress write, the sweep then finds the run
	 * stale with its job finished, and whatever the sweep queues still runs before the window closes.
	 *
	 * @param step The API step whose handler loses its first hop's progress write.
	 *
	 * @return The execution record ID.
	 */
	@SuppressWarnings('PMD.KernNoRawEnqueueJob')
	private static String runChainThatStallsOnceThenSweep(UTIL_AsyncChain.ApiStep step)
	{
		Test.startTest();
		String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME).then(step).withAsyncOptions(createAsyncOptions(2)).execute();
		executionIdWhoseKeyRotatesAfterTheCallout = executionId;
		System.enqueueJob(new WatchdogSweepJob());
		Test.stopTest();
		return executionId;
	}

	/**
	 * @description Asserts the final state of a one-step chain whose API step stalled after its first call and was run
	 * again by the watchdog: Completed with no failure, the step counted once, two callouts and two Completed call rows,
	 * and the step's entry carrying the idempotency declaration, its start and its success.
	 *
	 * @param executionId The execution record ID.
	 * @param serviceName The step's service name.
	 */
	private static void assertStalledStepRanAgainAndCompleted(String executionId, String serviceName)
	{
		AsyncChainExecution__c result = queryExecution(executionId);
		Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c,
				'Expected the watchdog to run the stalled step again to completion, got ' + result.Status__c + ': ' + result.ErrorMessage__c);
		Assert.isNull(result.FailureCategory__c, 'Expected no failure category, got ' + result.FailureCategory__c);
		Assert.isNull(result.ErrorMessage__c, 'Expected no error message, got ' + result.ErrorMessage__c);
		Assert.areEqual(1, result.CompletedSteps__c, 'Expected the one step counted once, got ' + result.CompletedSteps__c);
		Integer callouts = API_MockFactory.getInvocationCount(serviceName);
		Assert.areEqual(2, callouts, 'Expected the stalled call and the watchdog\'s run of it, got ' + callouts + ' callouts');
		List<ApiCall__c> calls = new SEL_ApiCall().findByServiceName(serviceName);
		Assert.areEqual(2, calls.size(), 'Expected one call row per callout, got ' + calls.size());
		for(ApiCall__c call : calls)
		{
			Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, call.Status__c, 'Expected every call to rest Completed, got ' + call.Status__c);
		}
		List<UTIL_AsyncChain.DTO_StepDefinition> entries = parseStepLog(result);
		Assert.areEqual(1, entries.size(), 'Expected one step entry, got ' + entries.size());
		Assert.areEqual(true, entries[0].isIdempotent, 'Expected the build to store the step\'s idempotency declaration, got ' + entries[0].isIdempotent);
		Assert.areEqual(true, entries[0].started, 'Expected the step\'s start recorded, got ' + entries[0].started);
		Assert.areEqual(true, entries[0].success, 'Expected the step\'s success recorded, got ' + entries[0].success);
	}

	/**
	 * @description Asserts that a chain was built and launched around one API step whose handler could not answer, and
	 * that the step's entry stores no idempotency declaration: the run is Running with one step to go and the launch's
	 * start recorded.
	 *
	 * @param executionId The execution record ID the launch returned.
	 */
	private static void assertLaunchStoredNoDeclaration(String executionId)
	{
		AsyncChainExecution__c launched = queryExecution(executionId);
		Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, launched.Status__c, 'Expected the chain launched, got ' + launched.Status__c);
		Assert.areEqual(1, launched.TotalSteps__c, 'Expected one step, got ' + launched.TotalSteps__c);
		Assert.areEqual(0, launched.CompletedSteps__c, 'Expected no completed step, got ' + launched.CompletedSteps__c);
		List<UTIL_AsyncChain.DTO_StepDefinition> entries = parseStepLog(launched);
		Assert.areEqual(1, entries.size(), 'Expected one step entry, got ' + entries.size());
		Assert.isNull(entries[0].isIdempotent, 'Expected no idempotency declaration stored, got ' + entries[0].isIdempotent);
		Assert.areEqual(true, entries[0].started, 'Expected the launch to record the step\'s start, got ' + entries[0].started);
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