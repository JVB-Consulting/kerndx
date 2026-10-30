// SPDX-License-Identifier: Apache-2.0
/**
 * @description Re-drive and kill-switch gate tests for CTRL_ChainMonitor (the permission,
 * capability-flag, suspension, and missing-row gates on the operator action endpoints), separated
 * from CTRL_ChainMonitor_TEST because these need @TestSetup users and IsParallel=false (User DML is
 * not permitted in parallel tests), while the read-path suite stays parallel. Refusals assert the
 * exception type and the untouched row, never the label text: AuraHandledException messages are
 * opaque in test context, so the way each scenario is built is what ties each refusal to its gate.
 *
 * @see CTRL_ChainMonitor
 * @see CTRL_ChainMonitorAbort_TEST
 * @see UTIL_AsyncChain
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date August 2026, October 2026
 */
@SuppressWarnings('PMD.CyclomaticComplexity')
@IsTest(seeAllData=false isParallel=false)
private class CTRL_ChainMonitorRedrive_TEST
{
	/**
	 * @description Company name of the test user who holds the redrive permission set and not the kill-switch one. The tests
	 * run as this user to retry a chain, to restart one and to clear stalled chains, and to prove that the same user is
	 * refused the suspend and resume actions. The tests look the user up by this name.
	 */
	private static final String REDRIVE_GRANTEE_COMPANY = 'CTRL_ChainMonitorRedrive_TEST-redrive-grantee';

	/**
	 * @description Company name of the test user who holds the permission to suspend and resume chain processing for the
	 * whole org. The tests look the user up by this name.
	 */
	private static final String KILL_SWITCH_GRANTEE_COMPANY = 'CTRL_ChainMonitorRedrive_TEST-kill-switch-grantee';

	/**
	 * @description Company name of the test user who was given neither of those two permissions, used to prove that an
	 * action is refused. The tests look the user up by this name.
	 */
	private static final String BYSTANDER_COMPANY = 'CTRL_ChainMonitorRedrive_TEST-bystander';

	/**
	 * @description Chain name given to every run these tests create through TST_Factory.newChainExecution.
	 */
	private static final String TEST_CHAIN = 'RedriveControllerChain';

	/**
	 * @description Number of steps a seeded failed run records: one that completed and one that failed.
	 */
	private static final Integer TOTAL_STEPS = 2;

	/**
	 * @description Number of steps a seeded failed run records as completed: the first of its two.
	 */
	private static final Integer COMPLETED_STEPS = 1;

	/**
	 * @description Duration in milliseconds written on the completed step of every seeded step log, so the entry looks like
	 * one a real run wrote.
	 */
	private static final Integer COMPLETED_STEP_DURATION_MS = 5;

	/**
	 * @description Duration in milliseconds written on the failed step of every seeded step log, so the entry looks like one
	 * a real run wrote.
	 */
	private static final Integer FAILED_STEP_DURATION_MS = 3;

	/**
	 * @description Duration in milliseconds stored on a seeded failed run, one of the end-of-run values a real failure
	 * leaves on the record.
	 */
	private static final Integer SEEDED_DURATION_MS = 1000;

	/**
	 * @description Error text on the seeded failed step and on the seeded failed run. It is also the message of the log
	 * entry created in the test setup.
	 */
	private static final String SEEDED_FAILURE_MESSAGE = 'Deliberate seeded failure for the gate matrix';

	/**
	 * @description Message RecoveringStep returns when it succeeds.
	 */
	private static final String STEP_SUCCESS_MESSAGE = 'Recovered';

	/**
	 * @description Key of the single entry in the seeded chain context. Two tests also put it alone in a JSON list, to build
	 * a context that is valid JSON but not an object.
	 */
	private static final String CONTEXT_SEED_KEY = 'seedCount';

	/**
	 * @description A small, valid chain context as JSON: one key with the value 1. It is stored on seeded runs so the retry
	 * and restart checks find a context they can read.
	 */
	private static final String CONTEXT_JSON = JSON.serialize(new Map<String, Object> {CONTEXT_SEED_KEY => 1});

	/**
	 * @description Deduplication key (the key that stops two live runs of the same work) given to the failed run and to a
	 * second run that is still running, so the retry meets a key that is already in use.
	 */
	private static final String DECLARED_DEDUPLICATION_KEY = 'RedriveControllerChain-deduplication-key';

	/**
	 * @description Key of the logging-context entry in the snapshot that buildCapacityFillingSnapshotJson builds.
	 */
	private static final String LOG_CONTEXT_KEY = '__logContext';

	/**
	 * @description A one-character stand-in for the logging context. It is deliberately tiny, so the full entry that replaces
	 * it on a restart is certain to be longer and to overflow the field.
	 */
	private static final String TINY_LOG_CONTEXT_VALUE = 'x';

	/**
	 * @description Key of the filler entry that pads the snapshot to the exact length of its field.
	 */
	private static final String SNAPSHOT_PADDING_KEY = 'padding';

	/**
	 * @description Maximum length of the InitialContextData__c field, read from the field itself, so the snapshot can be
	 * built to fill it exactly.
	 */
	private static final Integer CONTEXT_DATA_FIELD_CAPACITY = AsyncChainExecution__c.InitialContextData__c.getDescribe().getLength();

	/**
	 * @description Tells invokeAction to call the retry endpoint, which runs a failed chain again from its failed step.
	 */
	private static final String ACTION_RETRY = 'retry';

	/**
	 * @description Tells invokeAction to call the restart endpoint, which runs a chain again from its first step.
	 */
	private static final String ACTION_RESTART = 'restart';

	/**
	 * @description Tells invokeAction to call the endpoint that clears stalled chains.
	 */
	private static final String ACTION_CLEAR_STALLED = 'clearStalled';

	/**
	 * @description Tells invokeAction to call the endpoint that suspends chain processing.
	 */
	private static final String ACTION_SUSPEND = 'suspend';

	/**
	 * @description Tells invokeAction to call the endpoint that resumes chain processing.
	 */
	private static final String ACTION_RESUME = 'resume';

	/**
	 * @description Company name of the test user with minimum access, who cannot read LogEntry__c. The tests look the user
	 * up by this name.
	 */
	private static final String MINIMUM_ACCESS_COMPANY = 'CTRL_ChainMonitorRedrive_TEST-minimum-access';

	/**
	 * @description Correlation id (the tracking id that links log entries to a run) shared by the log entry created in the
	 * test setup and the run that shouldSeedNoLogEntriesForCallerWithoutLogAccess creates, so a stored entry exists for
	 * that run.
	 */
	private static final String SEED_GATE_CORRELATION_ID = 'redrive-gate-seed-correlation-0001';

	/**
	 * @description Creates the users the tests run as: one who may retry, restart and clear stalled chains, one who may suspend and resume
	 * chain processing, one bystander who was given neither permission, and one with minimum access. It also creates the
	 * log entry that shouldSeedNoLogEntriesForCallerWithoutLogAccess relies on.
	 */
	@TestSetup
	private static void setupTestUsers()
	{
		// Package installs write the packaged custom permissions INTO profiles: the System
		// Administrator profile on an admins-only install (the default), every profile on an all-users
		// install. Every test user therefore lives on the Standard User profile, which the default
		// install leaves grant-free, so the three users differ only by their permission-set assignments
		// (the redrive grantee is also the kill-switch bystander of the two-permission split test), and
		// nothing here touches an org-level setup row: the profile grants are shared state that every
		// parallel test class can see, and deleting them collides on the row lock. The Kern
		// Administrator permission set on all three is for the post-refusal row re-reads: view-all-
		// records visibility over the privately-owned execution rows through the sharing-enforced
		// selector, not for the refusal paths themselves.
		User redriveGrantee = newStandardUserWithAdministratorPermissionSet(REDRIVE_GRANTEE_COMPANY);
		TST_Factory.createPermissionSetAssignments(new List<User> {redriveGrantee}, UTIL_AsyncChain.REDRIVE_PERMISSION_SET_NAME);
		User killSwitchGrantee = newStandardUserWithAdministratorPermissionSet(KILL_SWITCH_GRANTEE_COMPANY);
		TST_Factory.createPermissionSetAssignments(new List<User> {killSwitchGrantee}, UTIL_AsyncChain.KILL_SWITCH_TOGGLE_PERMISSION_SET_NAME);
		newStandardUserWithAdministratorPermissionSet(BYSTANDER_COMPANY);
		DML_Builder.newTransaction().withSystemMode().doInsert(TST_Factory.newMinimumAccessUser(MINIMUM_ACCESS_COMPANY)).execute();
		// The log entry for shouldSeedNoLogEntriesForCallerWithoutLogAccess is seeded here rather than in that test method:
		// this non-setup insert must be segregated from the User and PermissionSetAssignment DML
		// above (the runAs wrapper does that), and committed setup data is visible to the runAs
		// caller without granting that caller any create access of its own.
		System.runAs(new User(Id = UserInfo.getUserId()))
		{
			TST_Builder.of(LogEntry__c.SObjectType)
					.withOverride(LogEntry__c.CorrelationId__c, SEED_GATE_CORRELATION_ID)
					.withOverride(LogEntry__c.ShortMessage__c, SEEDED_FAILURE_MESSAGE)
					.build();
		}
	}

	/**
	 * @description Finds the user created in the test setup who holds the redrive permission set, which the retry, restart
	 * and clear-stalled tests run as.
	 *
	 * @return The user who holds the redrive permission set.
	 */
	private static User getRedriveGrantee()
	{
		return new SEL_User().findByCompanyName(REDRIVE_GRANTEE_COMPANY);
	}

	/**
	 * @description Finds the user created in the test setup who holds the permission to suspend and resume chain processing.
	 *
	 * @return The user who may suspend and resume chain processing.
	 */
	private static User getKillSwitchGrantee()
	{
		return new SEL_User().findByCompanyName(KILL_SWITCH_GRANTEE_COMPANY);
	}

	/**
	 * @description Creates and inserts a test user on the Standard User profile holding the Kern Administrator
	 * permission set. Every test user in this suite has this shape: the profile the default install leaves grant-free,
	 * plus the view-all-records visibility the post-refusal row re-reads need.
	 *
	 * @param company The company name the user is looked up by.
	 *
	 * @return The inserted user.
	 */
	private static User newStandardUserWithAdministratorPermissionSet(String company)
	{
		return TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, company, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);
	}

	/**
	 * @description Asserts that a user lacks a packaged custom permission, so the refusal under test has a user without
	 * the permission at all. On an all-users install the profile grant reaches every user. The suite then fails with
	 * this message instead of editing the org's setup rows to create such a user.
	 *
	 * @param user The user expected to lack the permission.
	 * @param customPermissionName The API name of the packaged custom permission.
	 * @param userRole What the user stands for in the test, named in the failure message.
	 * @param proof What the user is there to prove, named in the failure message.
	 */
	private static void assertUserLacksPermission(User user, String customPermissionName, String userRole, String proof)
	{
		Assert.isFalse(SEL_CustomPermission.hasPackagePermission(user.Id, customPermissionName),
				'Expected the Standard User profile not to hold ' + customPermissionName + ', but this org grants it (an all-users package '
				+ 'install), so no ' + userRole + ' exists to prove the ' + proof + ' against; run this suite in an org installed for admins only');
	}

	/**
	 * @description The bystander, asserted to be one: on an all-users install the profile grant makes
	 * every user a permission holder, and a refusal test run there is not testing a bystander; it says
	 * so instead of editing the org's setup rows to manufacture one.
	 *
	 * @return The bystander user, guaranteed to lack the redrive custom permission.
	 */
	private static User getBystander()
	{
		User bystander = new SEL_User().findByCompanyName(BYSTANDER_COMPANY);
		assertUserLacksPermission(bystander, UTIL_AsyncChain.REDRIVE_CUSTOM_PERMISSION_NAME, 'bystander', 'refusal of the redrive actions');
		return bystander;
	}

	/**
	 * @description Finds the minimum-access user created in the test setup, the caller who cannot read LogEntry__c.
	 *
	 * @return The minimum-access user.
	 */
	private static User getMinimumAccessUser()
	{
		return new SEL_User().findByCompanyName(MINIMUM_ACCESS_COMPANY);
	}

	/**
	 * @description Re-reads an execution row through the sharing-enforced selector to verify
	 * committed state.
	 *
	 * @param executionId The AsyncChainExecution__c record ID.
	 *
	 * @return The re-read AsyncChainExecution__c record, or null when no row exists.
	 */
	private static AsyncChainExecution__c queryExecution(Id executionId)
	{
		return (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(executionId);
	}

	/**
	 * @description Invokes the named operator action endpoint, so the shared refusal helper can
	 * cover the whole matrix without repeating the house expect-throw shape per action.
	 *
	 * @param action One of the ACTION_* discriminators.
	 * @param executionId The chain record the action targets; ignored by the record-less actions.
	 */
	private static void invokeAction(String action, Id executionId)
	{
		if(action == ACTION_RETRY)
		{
			CTRL_ChainMonitor.retryChainFromFailedStep(executionId);
		}
		else if(action == ACTION_RESTART)
		{
			CTRL_ChainMonitor.restartChainFromStart(executionId);
		}
		else if(action == ACTION_CLEAR_STALLED)
		{
			CTRL_ChainMonitor.clearStalledChains();
		}
		else if(action == ACTION_SUSPEND)
		{
			CTRL_ChainMonitor.suspendChainProcessing();
		}
		else if(action == ACTION_RESUME)
		{
			CTRL_ChainMonitor.resumeChainProcessing();
		}
	}

	/**
	 * @description Calls the named action and asserts it refuses with an AuraHandledException. The
	 * house expect-throw shape (Assert.fail then a typed catch), shared so the refusal tests do not
	 * each inline it.
	 *
	 * @param action One of the ACTION_* discriminators.
	 * @param executionId The chain record the action is attempted on; ignored by the record-less actions.
	 */
	private static void assertActionRefused(String action, Id executionId)
	{
		try
		{
			invokeAction(action, executionId);
			Assert.fail('Should throw AuraHandledException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, AuraHandledException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Builds a step definition with the given class name and display name.
	 *
	 * @param className The fully-qualified step class name.
	 * @param stepName The display name for the step.
	 *
	 * @return The configured DTO_StepDefinition.
	 */
	private static UTIL_AsyncChain.DTO_StepDefinition buildStepDefinition(String className, String stepName)
	{
		UTIL_AsyncChain.DTO_StepDefinition definition = new UTIL_AsyncChain.DTO_StepDefinition();
		definition.className = className;
		definition.stepName = stepName;
		return definition;
	}

	/**
	 * @description Builds the eligible retry candidate's step log: a completed first step and a
	 * failed second step whose entry declares isIdempotent, the shape the retry gate admits.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildEligibleFailedStepLog()
	{
		UTIL_AsyncChain.DTO_StepDefinition completedStep = buildStepDefinition(RecoveringStep.class.getName(), 'CompletedStep');
		completedStep.success = true;
		completedStep.durationMs = COMPLETED_STEP_DURATION_MS;

		UTIL_AsyncChain.DTO_StepDefinition failedStep = buildStepDefinition(RecoveringStep.class.getName(), 'FailedStep');
		failedStep.isIdempotent = true;
		failedStep.success = false;
		failedStep.message = SEEDED_FAILURE_MESSAGE;
		failedStep.durationMs = FAILED_STEP_DURATION_MS;

		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {completedStep, failedStep}, true);
	}

	/**
	 * @description Builds the ineligible retry variant whose failed entry never declared
	 * isIdempotent: the pre-upgrade and undeclared shape the gate must refuse.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildNonIdempotentFailedStepLog()
	{
		UTIL_AsyncChain.DTO_StepDefinition completedStep = buildStepDefinition(RecoveringStep.class.getName(), 'CompletedStep');
		completedStep.success = true;
		completedStep.durationMs = COMPLETED_STEP_DURATION_MS;

		UTIL_AsyncChain.DTO_StepDefinition failedStep = buildStepDefinition(RecoveringStep.class.getName(), 'FailedStep');
		failedStep.success = false;
		failedStep.message = SEEDED_FAILURE_MESSAGE;
		failedStep.durationMs = FAILED_STEP_DURATION_MS;

		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {completedStep, failedStep}, true);
	}

	/**
	 * @description Builds the declared-permanent retry variant: the failed entry declares BOTH
	 * isIdempotent and permanentFailure, so a passing refusal proves permanence outranks the
	 * idempotency declaration through the controller gate.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildPermanentFailureStepLog()
	{
		UTIL_AsyncChain.DTO_StepDefinition completedStep = buildStepDefinition(RecoveringStep.class.getName(), 'CompletedStep');
		completedStep.success = true;
		completedStep.durationMs = COMPLETED_STEP_DURATION_MS;

		UTIL_AsyncChain.DTO_StepDefinition failedStep = buildStepDefinition(RecoveringStep.class.getName(), 'FailedStep');
		failedStep.isIdempotent = true;
		failedStep.permanentFailure = true;
		failedStep.success = false;
		failedStep.message = SEEDED_FAILURE_MESSAGE;
		failedStep.durationMs = FAILED_STEP_DURATION_MS;

		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {completedStep, failedStep}, true);
	}

	/**
	 * @description Builds an as-built snapshot that fills InitialContextData__c to its exact field
	 * capacity, carrying a deliberately tiny logging-context entry. Restarting from it must
	 * overflow: the clone rebuild swaps that entry for a full correlation document, so the clone's
	 * ContextData__c cannot fit the same field.
	 *
	 * @return The serialized capacity-filling snapshot JSON.
	 */
	private static String buildCapacityFillingSnapshotJson()
	{
		Map<String, Object> snapshot = new Map<String, Object>
		{
				LOG_CONTEXT_KEY => TINY_LOG_CONTEXT_VALUE,
				SNAPSHOT_PADDING_KEY => UTIL_String.EMPTY
		};
		Integer fillerLength = CONTEXT_DATA_FIELD_CAPACITY - JSON.serialize(snapshot).length();
		snapshot.put(SNAPSHOT_PADDING_KEY, 'p'.repeat(fillerLength));
		return JSON.serialize(snapshot);
	}

	/**
	 * @description Seeds a Failed chain row from the given step log, carrying the full terminal
	 * bookkeeping of a real failure (parseable context, run key, completion timestamp, duration,
	 * failure category and error message), the exact shape the operator gates read. The completion timestamp is the
	 * one the factory gives a Failed row at birth, because a finished run's end time never changes once written.
	 *
	 * @param stepLogJson The hand-built persisted step log.
	 * @param restartDeclared When true, the row also carries the restart declaration and snapshot.
	 *
	 * @return The seeded AsyncChainExecution__c record.
	 */
	private static AsyncChainExecution__c seedFailedChain(String stepLogJson, Boolean restartDeclared)
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_FAILED, TEST_CHAIN, stepLogJson, TOTAL_STEPS, COMPLETED_STEPS);
		execution.ContextData__c = CONTEXT_JSON;
		execution.RunKey__c = UTIL_Random.randomUUID();
		execution.DurationMs__c = SEEDED_DURATION_MS;
		execution.FailureCategory__c = SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION;
		execution.ErrorMessage__c = SEEDED_FAILURE_MESSAGE;
		if(restartDeclared)
		{
			execution.AllowRestart__c = true;
			execution.InitialContextData__c = CONTEXT_JSON;
		}
		DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();
		return execution;
	}

	/**
	 * @description Seeds a failed run that the retry check accepts: its failed step declares that it is safe to run again.
	 * The run does not declare that it may be restarted.
	 *
	 * @return The seeded record's ID.
	 */
	private static Id seedEligibleFailedChain()
	{
		return seedFailedChain(buildEligibleFailedStepLog(), false).Id;
	}

	/**
	 * @description Seeds a Stalled chain row with no executor job stamp: the sweep's liveness probe
	 * treats the missing stamp as CANNOT-CHECK and degrades to detect-mark, so the row
	 * deterministically stays Stalled and lands in the remainingStalled tally bucket.
	 *
	 * @return The seeded record's ID.
	 */
	private static Id seedStalledChain()
	{
		return TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN).Id;
	}

	/**
	 * @description A redrive permission holder retries an eligible Failed chain through the
	 * controller: the row commits back to Running before the re-driven executor runs, and the
	 * returned detail reflects the re-driven run without a second round trip.
	 */
	@IsTest
	private static void shouldRetryFailedChainAsGrantee()
	{
		Id executionId = seedEligibleFailedChain();

		System.runAs(getRedriveGrantee())
		{
			Test.startTest();
			CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.retryChainFromFailedStep(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, queryExecution(executionId).Status__c,
					'The retry must commit the row back to Running before the executor runs');
			Test.stopTest();

			Assert.areEqual(executionId, detail.executionId, 'Retry re-enters the same record, never a clone');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, detail.status, 'The returned detail reflects the re-driven run');

			Integer retriedStepCount = 0;
			for(CTRL_ChainMonitorTypes.DTO_StepDetail step : detail.steps)
			{
				retriedStepCount += step.manuallyRetried == true ? 1 : 0;
			}
			Assert.areEqual(1, retriedStepCount, 'The returned detail marks exactly the step the operator retried');
			Assert.isNotNull(queryExecution(executionId).LastManualRetryAt__c, 'The retry stamps the record through the controller path too');
		}
	}

	/**
	 * @description A user without the redrive custom permission is refused with a throw and the row
	 * stays untouched: Apex is the enforcement point, the button state is only a hint.
	 */
	@IsTest
	private static void shouldRefuseRetryForBystander()
	{
		Id executionId = seedEligibleFailedChain();

		System.runAs(getBystander())
		{
			Test.startTest();
			assertActionRefused(ACTION_RETRY, executionId);
			Test.stopTest();
		}

		Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(executionId).Status__c, 'A refused action must not mutate the row');
	}

	/**
	 * @description With the redrive feature flag out of the active set a permission holder is
	 * refused on the mutating path: the org-wide off state blocks the action exactly as it blocks
	 * availability. Removing the cache entry models an admin deactivating the flag record.
	 */
	@IsTest
	private static void shouldRefuseRetryWhenCapabilityFlagInactive()
	{
		Id executionId = seedEligibleFailedChain();

		System.runAs(getRedriveGrantee())
		{
			SEL_FeatureFlag.activeFlags.remove(UTIL_AsyncChain.REDRIVE_FEATURE_FLAG_NAME);

			Test.startTest();
			assertActionRefused(ACTION_RETRY, executionId);
			Test.stopTest();
		}

		Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(executionId).Status__c, 'A capability-disabled refusal must not mutate the row');
	}

	/**
	 * @description A permission holder is refused on a chain whose failed step never declared
	 * isIdempotent: the engine's state gate holds through the controller, and the refused row stays
	 * untouched under the sharing-enforced re-read.
	 */
	@IsTest
	private static void shouldRefuseRetryForIneligibleChain()
	{
		Id executionId = seedFailedChain(buildNonIdempotentFailedStepLog(), false).Id;

		System.runAs(getRedriveGrantee())
		{
			Test.startTest();
			assertActionRefused(ACTION_RETRY, executionId);
			Test.stopTest();
		}

		Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(executionId).Status__c, 'A state-refused action must not mutate the row');
	}

	/**
	 * @description A redrive permission holder restarts a declared chain: the returned detail is
	 * the CLONE (fresh record, Running, carrying the lineage lookup), and the source row keeps its
	 * terminal status untouched.
	 */
	@IsTest
	private static void shouldRestartDeclaredChainAsGrantee()
	{
		AsyncChainExecution__c source = seedFailedChain(buildEligibleFailedStepLog(), true);

		System.runAs(getRedriveGrantee())
		{
			Test.startTest();
			CTRL_ChainMonitorTypes.DTO_ChainDetail cloneDetail = CTRL_ChainMonitor.restartChainFromStart(source.Id);
			Test.stopTest();

			Assert.areNotEqual(source.Id, cloneDetail.executionId, 'Restart clones to a fresh record');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, cloneDetail.status, 'The clone starts Running');
			Assert.areEqual(source.Id, cloneDetail.sourceExecutionId, 'The clone carries the restart lineage lookup');
		}

		Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(source.Id).Status__c, 'The source row keeps its terminal status');
	}

	/**
	 * @description A user without the redrive custom permission is refused a restart with a throw
	 * and the declared source row stays untouched.
	 */
	@IsTest
	private static void shouldRefuseRestartForBystander()
	{
		AsyncChainExecution__c source = seedFailedChain(buildEligibleFailedStepLog(), true);

		System.runAs(getBystander())
		{
			Test.startTest();
			assertActionRefused(ACTION_RESTART, source.Id);
			Test.stopTest();
		}

		Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(source.Id).Status__c, 'A refused restart must not mutate the source row');
	}

	/**
	 * @description A redrive permission holder runs the clear-stalled sweep and receives the real
	 * per-bucket counts: the seeded stamp-less candidate is CANNOT-CHECK, so it stays Stalled and
	 * lands in the remainingStalled bucket, proving the endpoint returns the engine tally, not a
	 * fabricated shape.
	 */
	@IsTest
	private static void shouldClearStalledAsGranteeWithCounts()
	{
		Id executionId = seedStalledChain();

		System.runAs(getRedriveGrantee())
		{
			Test.startTest();
			CTRL_ChainMonitorTypes.DTO_ClearStalledResult result = CTRL_ChainMonitor.clearStalledChains();
			Test.stopTest();

			Assert.areEqual(1, result.candidates, 'The sweep must inspect the one stalled candidate');
			Assert.areEqual(0, result.redriven, 'A CANNOT-CHECK candidate is never re-driven');
			Assert.areEqual(0, result.markedFailed, 'A CANNOT-CHECK candidate is never degraded to Failed');
			Assert.areEqual(1, result.remainingStalled, 'The detect-marked candidate still awaits recovery');
		}

		Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, queryExecution(executionId).Status__c, 'The detect-marked row stays Stalled');
	}

	/**
	 * @description A user without the redrive custom permission is refused the sweep with a throw
	 * and the stalled row stays untouched.
	 */
	@IsTest
	private static void shouldRefuseClearStalledForBystander()
	{
		Id executionId = seedStalledChain();

		System.runAs(getBystander())
		{
			Test.startTest();
			assertActionRefused(ACTION_CLEAR_STALLED, null);
			Test.stopTest();
		}

		Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, queryExecution(executionId).Status__c, 'A refused sweep must not touch the stalled row');
	}

	/**
	 * @description While chain processing is suspended, a redrive permission holder is refused the
	 * sweep and the operations state reports the suspension. This gate exists ONLY in the
	 * controller. The engine's clearStalledChains carries no suspension conjunct, because an
	 * all-zeros engine refusal would be indistinguishable from "nothing stalled". So this test is
	 * the only one that checks the controller enforces this gate.
	 */
	@IsTest
	private static void shouldRefuseClearStalledWhileSuspendedForGrantee()
	{
		Id executionId = seedStalledChain();
		UTIL_AsyncChain.suspendChainProcessing();

		System.runAs(getRedriveGrantee())
		{
			Test.startTest();
			Assert.areEqual
					(
							UTIL_AsyncChain.REDRIVE_PROCESSING_SUSPENDED, CTRL_ChainMonitor.getChainOperationsState().clearStalledAvailability,
							'The operations state must report the suspension as the clear-stalled availability'
					);
			assertActionRefused(ACTION_CLEAR_STALLED, null);
			Test.stopTest();
		}

		Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, queryExecution(executionId).Status__c, 'A suspension-refused sweep must not touch the stalled row');
	}

	/**
	 * @description A kill-switch permission holder suspends and resumes chain processing through
	 * the controller: each verb returns the fresh operations state, and the round trip leaves the
	 * org-default runtime switch enabled.
	 */
	@IsTest
	private static void shouldSuspendAndResumeAsKillSwitchGrantee()
	{
		System.runAs(getKillSwitchGrantee())
		{
			Test.startTest();
			CTRL_ChainMonitorTypes.DTO_OperationsState suspended = CTRL_ChainMonitor.suspendChainProcessing();
			CTRL_ChainMonitorTypes.DTO_OperationsState resumed = CTRL_ChainMonitor.resumeChainProcessing();
			Test.stopTest();

			Assert.isFalse(suspended.chainProcessingEnabled, 'Suspend must report chain processing disabled');
			Assert.isTrue(resumed.chainProcessingEnabled, 'Resume must report chain processing enabled');
			Assert.areEqual(CTRL_ChainMonitor.OPERATOR_AVAILABLE, resumed.killSwitchAvailability, 'A kill-switch grantee with the live flag sees the toggle as available');
		}

		Assert.isTrue(AsyncChainRuntimeSwitch__c.getOrgDefaults().ChainsEnabled__c, 'The round trip must leave the org-default runtime switch enabled');
	}

	/**
	 * @description A redrive permission holder WITHOUT the kill-switch permission is refused BOTH
	 * toggle verbs and no runtime-switch row is written. This proves the two permissions are separate. Being
	 * trusted to re-drive one chain never implies being trusted to stop, or restart, every chain
	 * in the org.
	 */
	@IsTest
	private static void shouldRefuseKillSwitchToggleForRedriveOnlyGrantee()
	{
		User redriveOnlyGrantee = getRedriveGrantee();
		assertUserLacksPermission(redriveOnlyGrantee, UTIL_AsyncChain.KILL_SWITCH_TOGGLE_CUSTOM_PERMISSION_NAME, 'redrive-only user',
				'separation of the redrive and kill-switch permissions');
		System.runAs(redriveOnlyGrantee)
		{
			Test.startTest();
			assertActionRefused(ACTION_SUSPEND, null);
			assertActionRefused(ACTION_RESUME, null);
			Test.stopTest();
		}

		Assert.isNull(AsyncChainRuntimeSwitch__c.getOrgDefaults().Id, 'A refused toggle must not write the runtime-switch row');
	}

	/**
	 * @description With the kill-switch feature flag out of the active set even a kill-switch
	 * permission holder is refused the toggle: the org-wide off state blocks the verb, and no
	 * runtime-switch row is written.
	 */
	@IsTest
	private static void shouldRefuseSuspendWhenCapabilityFlagInactive()
	{
		System.runAs(getKillSwitchGrantee())
		{
			SEL_FeatureFlag.activeFlags.remove(UTIL_AsyncChain.KILL_SWITCH_TOGGLE_FEATURE_FLAG_NAME);

			Test.startTest();
			assertActionRefused(ACTION_SUSPEND, null);
			Test.stopTest();
		}

		Assert.isNull(AsyncChainRuntimeSwitch__c.getOrgDefaults().Id, 'A capability-disabled toggle must not write the runtime-switch row');
	}

	/**
	 * @description A caller whose context cannot read LogEntry__c at all seeds an EMPTY live-stream
	 * history (never a throw, and never the framework-owned log rows their permissions deny), even
	 * though a persisted entry exists for the chain's correlation (seeded in @TestSetup; the setup
	 * comment records why it cannot be seeded here): the stream degrades to live-only, exactly the
	 * monitor read posture the permission sets promise. The test fails if the access check is
	 * removed: the code then checks no describe at all, and its trace read, which ignores sharing,
	 * hands this caller the row seeded in setup.
	 */
	@IsTest
	private static void shouldSeedNoLogEntriesForCallerWithoutLogAccess()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, TEST_CHAIN, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.CorrelationId__c => SEED_GATE_CORRELATION_ID
		});

		System.runAs(getMinimumAccessUser())
		{
			Test.startTest();
			Assert.isTrue(CTRL_ChainMonitor.getChainLogEntries(execution.Id).isEmpty(), 'A caller without LogEntry__c access must seed an empty list, never framework log rows');
			Test.stopTest();
		}
	}

	/**
	 * @description A permission holder acting on a non-existent chain is refused on both re-drive
	 * actions with a throw: the monitoring read returns null, so each mutating path stops before
	 * any write. Proves the missing-row guard on the action paths, not just the read path.
	 */
	@IsTest
	private static void shouldRefuseAllActionsAgainstMissingRow()
	{
		Id missingId = UTIL_Random.randomId(AsyncChainExecution__c.SObjectType);

		System.runAs(getRedriveGrantee())
		{
			Test.startTest();
			assertActionRefused(ACTION_RETRY, missingId);
			assertActionRefused(ACTION_RESTART, missingId);
			Test.stopTest();
		}

		Assert.isNull(queryExecution(missingId), 'No row is written for a missing chain');
	}

	/**
	 * @description A permission holder is refused both re-drive actions on a Completed chain: the
	 * chain-state refusal wins over the held permission on the mutating path, and the terminal row
	 * stays untouched.
	 */
	@IsTest
	private static void shouldRefuseBothActionsOnCompletedChainForGrantee()
	{
		Id executionId = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN).Id;

		System.runAs(getRedriveGrantee())
		{
			Test.startTest();
			assertActionRefused(ACTION_RETRY, executionId);
			assertActionRefused(ACTION_RESTART, executionId);
			Test.stopTest();
		}

		Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, queryExecution(executionId).Status__c, 'A state-refused action must not mutate the terminal row');
	}

	/**
	 * @description While chain processing is suspended a permission holder is refused the retry:
	 * the engine's suspension conjunct maps through the controller to a labeled refusal, and the
	 * row stays untouched.
	 */
	@IsTest
	private static void shouldRefuseRetryWhileSuspendedForGrantee()
	{
		Id executionId = seedEligibleFailedChain();
		UTIL_AsyncChain.suspendChainProcessing();

		System.runAs(getRedriveGrantee())
		{
			Test.startTest();
			assertActionRefused(ACTION_RETRY, executionId);
			Test.stopTest();
		}

		Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(executionId).Status__c, 'A suspension-refused retry must not mutate the row');
	}

	/**
	 * @description A permission holder is refused the retry of a chain whose persisted context is
	 * valid JSON but not an object (the shape the executor could not rehydrate), and the row
	 * stays untouched.
	 */
	@IsTest
	private static void shouldRefuseRetryWhenContextUnparseableForGrantee()
	{
		AsyncChainExecution__c execution = seedFailedChain(buildEligibleFailedStepLog(), false);
		execution.ContextData__c = JSON.serialize(new List<String> {CONTEXT_SEED_KEY});
		DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();

		System.runAs(getRedriveGrantee())
		{
			Test.startTest();
			assertActionRefused(ACTION_RETRY, execution.Id);
			Test.stopTest();
		}

		Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(execution.Id).Status__c, 'A context-refused retry must not mutate the row');
	}

	/**
	 * @description A permission holder is refused the retry of a step-declared permanent failure
	 * even though the failed entry also declares isIdempotent: permanence outranks the idempotency
	 * declaration through the controller gate, and the row stays untouched.
	 */
	@IsTest
	private static void shouldRefuseRetryOfPermanentFailureForGrantee()
	{
		Id executionId = seedFailedChain(buildPermanentFailureStepLog(), false).Id;

		System.runAs(getRedriveGrantee())
		{
			Test.startTest();
			assertActionRefused(ACTION_RETRY, executionId);
			Test.stopTest();
		}

		Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(executionId).Status__c, 'A permanence-refused retry must not mutate the row');
	}

	/**
	 * @description When another live run holds the chain's declared deduplication key, a permission
	 * holder's retry is refused through the engine's own fresh-read refusal (the collision
	 * surfaces at the sparse update, rolls back, and maps to the duplicate-run label), and the row
	 * keeps its terminal state.
	 */
	@IsTest
	private static void shouldRefuseRetryWhenDuplicateRunForGrantee()
	{
		AsyncChainExecution__c execution = seedFailedChain(buildEligibleFailedStepLog(), false);
		execution.DeclaredDeduplicationKey__c = DECLARED_DEDUPLICATION_KEY;
		DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.ActiveDeduplicationKey__c => DECLARED_DEDUPLICATION_KEY
		});

		System.runAs(getRedriveGrantee())
		{
			Test.startTest();
			assertActionRefused(ACTION_RETRY, execution.Id);
			Test.stopTest();
		}

		Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(execution.Id).Status__c, 'A key-collision refusal must roll the sparse update back');
	}

	/**
	 * @description An engine failure that is neither a refusal nor a key collision surfaces to the
	 * operator as the generic retry-failed label. Forced with the engine suite's authorized-mock
	 * technique: both reads serve a mock whose real record was deleted, so the sparse update cannot
	 * land and its DmlException crosses the controller's catch.
	 */
	@IsTest
	private static void shouldMapEngineFailureToRetryFailedLabel()
	{
		AsyncChainExecution__c execution = seedFailedChain(buildEligibleFailedStepLog(), false);
		Id executionId = execution.Id;
		DML_Builder.newTransaction().doDelete(execution).execute();
		TST_Mock.register(AsyncChainExecution__c.SObjectType, TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.Id, executionId)
				.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_FAILED)
				.withOverride(AsyncChainExecution__c.ContextData__c, CONTEXT_JSON)
				.withOverride(AsyncChainExecution__c.StepLog__c, buildEligibleFailedStepLog())
				.withoutInsertion()
				.build());

		System.runAs(getRedriveGrantee())
		{
			Test.startTest();
			assertActionRefused(ACTION_RETRY, executionId);
			Test.stopTest();
		}
	}

	/**
	 * @description A restart whose clone context outgrows its field surfaces to the operator as the
	 * generic restart-failed label. That is on purpose: the snapshot was captured and is
	 * intact, so no specific refusal code applies. Forced by a capacity-filling snapshot whose
	 * rebuilt logging-context entry pushes the clone past the field, and the source row survives
	 * the rolled-back insert untouched.
	 */
	@IsTest
	private static void shouldMapSnapshotOverflowToRestartFailedLabel()
	{
		AsyncChainExecution__c source = seedFailedChain(buildEligibleFailedStepLog(), true);
		source.InitialContextData__c = buildCapacityFillingSnapshotJson();
		DML_Builder.newTransaction().withSystemMode().doUpdate(source).execute();

		System.runAs(getRedriveGrantee())
		{
			Test.startTest();
			assertActionRefused(ACTION_RESTART, source.Id);
			Test.stopTest();
		}

		Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(source.Id).Status__c, 'The source survives a failed restart untouched');
	}

	/**
	 * @description A permission holder is refused the restart of a Failed chain that never declared
	 * allowRestart: the declaration gate holds through the controller, and the row stays untouched.
	 */
	@IsTest
	private static void shouldRefuseRestartNotDeclaredForGrantee()
	{
		Id executionId = seedEligibleFailedChain();

		System.runAs(getRedriveGrantee())
		{
			Test.startTest();
			assertActionRefused(ACTION_RESTART, executionId);
			Test.stopTest();
		}

		Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(executionId).Status__c, 'A declaration-refused restart must not mutate the row');
	}

	/**
	 * @description A declared chain whose snapshot is valid JSON but not an object is refused
	 * through the engine's own dedicated-read refusal (the shape only the action can see, mapped
	 * to the restart context label), and no clone is inserted.
	 */
	@IsTest
	private static void shouldRefuseRestartWhenSnapshotIsNotAnObjectForGrantee()
	{
		AsyncChainExecution__c source = seedFailedChain(buildEligibleFailedStepLog(), true);
		source.InitialContextData__c = JSON.serialize(new List<String> {CONTEXT_SEED_KEY});
		DML_Builder.newTransaction().withSystemMode().doUpdate(source).execute();

		System.runAs(getRedriveGrantee())
		{
			Test.startTest();
			assertActionRefused(ACTION_RESTART, source.Id);
			Test.stopTest();
		}

		Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(source.Id).Status__c, 'A snapshot-refused restart must not mutate the source row');
	}

	/**
	 * @description Step that succeeds, so re-driven and restarted fixture chains complete cleanly
	 * when their executor runs at Test.stopTest. Persisted step-log entries name this class, and the
	 * rehydrated executor instantiates it by name.
	 */
	public class RecoveringStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Succeeds on every call so the re-driven or restarted chain completes.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A succeeded result carrying STEP_SUCCESS_MESSAGE.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.succeeded(STEP_SUCCESS_MESSAGE);
		}
	}
}