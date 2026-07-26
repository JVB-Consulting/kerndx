// SPDX-License-Identifier: BUSL-1.1
/**
 * @description ApiStep and per-step-retry tests for UTIL_AsyncChain — ApiStep configuration and
 * context threading, outbound-engine interplay (retry freeze, self-retry suppression),
 * createRetryStrategy attempt/backoff behaviour, and the attempt-state accessors. Separated from
 * UTIL_AsyncChain_TEST because the combined class exceeded the cognitive-complexity ceiling and
 * the ApiStep/retry machinery is an independently reviewable facet.
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
private class UTIL_AsyncChainApi_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'UTIL_AsyncChainApi_TEST-admin';
	private static final String LOW_PRIVILEGE_COMPANY = 'UTIL_AsyncChainApi_TEST-lowpriv';

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
	 * @description Backoff seconds for the delay-inheritance pin: 120 seconds clamps to a two-minute
	 * enqueue delay on the retry link.
	 */
	private static final Integer RETRY_PIN_BACKOFF_SECONDS = 120;

	/**
	 * @description The API handler class name used by ApiStep tests.
	 */
	private static final String API_STEP_SERVICE_NAME = API_PostExample.class.getName();

	/**
	 * @description Outbound-engine retry allowance for the retry-interplay freeze pin: the
	 * ApiSetting__mdt fixture grants the outbound engine two retries of its own, so a single failed
	 * callout leaves headroom for the engine to self-schedule.
	 */
	private static final Integer OUTBOUND_ENGINE_MAX_RETRY_COUNT = 2;

	/**
	 * @description Outbound-engine backoff seconds for the retry-interplay freeze pin: non-zero so
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
	 * disables chain-level retry — the whole-pair-or-null boundary.
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
	 * @description Service name of the fails-once-then-succeeds outbound fixture handler.
	 */
	private static final String FLAKY_SERVICE_NAME = FlakyOutboundHandler.class.getName();

	/**
	 * @description Success body the flaky fixture flips its registered mock to after the first
	 * recorded callout.
	 */
	private static final String FLAKY_SUCCESS_BODY = '{"success":true}';

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
	 * attempt 1 and final attempt true — the contract for every step without a retry strategy.
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
	 * @description Freeze pin for the pre-withRetry interplay: an ApiStep with no chain-level retry
	 * strategy leaves the outbound engine as the sole retry authority. A failing callout fails the
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
			TST_Factory.newOutboundApiSetting(API_STEP_SERVICE_NAME, new Map<SObjectField, Object>
			{
					ApiSetting__mdt.MaxRetryCount__c => OUTBOUND_ENGINE_MAX_RETRY_COUNT,
					ApiSetting__mdt.RetryBackoffSeconds__c => OUTBOUND_ENGINE_RETRY_BACKOFF_SECONDS
			});
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
	 */
	@IsTest
	private static void shouldRetryApiStepWithChainStrategy()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
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
	 * fixture would normally let the engine claim it (the freeze pin proves exactly that claim on
	 * the unconfigured path).
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
	 * and a disabled opt-in (maxAttempts <= 1) stores neither key — the pair is whole or absent.
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
	 * outbound factory path in the same test transaction still self-schedules its own retry. Pins
	 * the per-instance property against any future refactor of handler-instance lifetime.
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
	 * retry budget (withRetry) — the shared shape of the suppression tests.
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
	 * unsuppressed failure self-schedules (Status Retry, NextRetry__c stamped).
	 */
	private static void mockOutboundEngineRetrySetting()
	{
		TST_Factory.newOutboundApiSetting(API_STEP_SERVICE_NAME, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MaxRetryCount__c => OUTBOUND_ENGINE_MAX_RETRY_COUNT,
				ApiSetting__mdt.RetryBackoffSeconds__c => OUTBOUND_ENGINE_RETRY_BACKOFF_SECONDS
		});
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
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put(ATTEMPT_STAMP_KEY_PREFIX + context.getAttempt(), context.getAttempt() + ':' + context.isFinalAttempt());
			if(context.getAttempt() < 3)
			{
				return UTIL_AsyncChain.failed('Transient failure on attempt ' + context.getAttempt());
			}
			return UTIL_AsyncChain.succeeded();
		}

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
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed('Permanent failure, attempt ' + context.getAttempt());
		}

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
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			throw new UTIL_Exceptions.IllegalStateException('Deterministic failure');
		}

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
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put(OBSERVED_DELAY_KEY_PREFIX + 'Step0Attempt' + context.getAttempt(), observedEnqueueDelay());
			if(context.getAttempt() < 2)
			{
				return UTIL_AsyncChain.failed('Transient failure for the delay pin');
			}
			return UTIL_AsyncChain.succeeded();
		}

		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return UTIL_Retry.exponential().withMaxRetries(1).withBaseBackoff(RETRY_PIN_BACKOFF_SECONDS);
		}
	}

	/**
	 * @description Step that records the enqueue delay its transaction observes via System.AsyncInfo.
	 * Placed after a retrying step to observe what a post-recovery hop inherits.
	 */
	public class DelayRecordingStep extends UTIL_AsyncChain.ChainStep
	{
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