// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests for CTRL_ScheduledJob controller methods.
 *
 * @see CTRL_ScheduledJob
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date March 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class CTRL_ScheduledJob_TEST
{
	/**
	 * @description Company name identifying the administrator who holds the Kern Job Runner Management permission set.
	 */
	private static final String MANAGING_ADMIN_COMPANY = 'CTRL_ScheduledJob_TEST-managing';

	/**
	 * @description Company name identifying the user who holds no access to the log entry object.
	 */
	private static final String RESTRICTED_USER_COMPANY = 'CTRL_ScheduledJob_TEST-restricted';

	/**
	 * @description Company name identifying the user who holds no job runner permission. A package install writes the
	 * Manage Job Runner permission into the System Administrator profile. So this user is on the Standard User profile,
	 * which the default install leaves without that permission.
	 */
	private static final String UNPERMITTED_USER_COMPANY = 'CTRL_ScheduledJob_TEST-unpermitted';

	/**
	 * @description The schedule of the jobs the job runner setting tests save: every day at noon.
	 */
	private static final String NOON_EVERY_DAY = '0 0 12 * * ?';

	/**
	 * @description The name of the run priority value in the JSON request the editors send.
	 */
	private static final String RUN_PRIORITY_KEY = 'runPriority';

	/**
	 * @description The run priority stored on the job runner record before the tests save it.
	 */
	private static final Decimal STORED_RUN_PRIORITY = 5;

	/**
	 * @description The name of the run priority value written with a capital first letter, as a caller may send it.
	 */
	private static final String RUN_PRIORITY_KEY_WITH_CAPITAL_LETTER = 'RunPriority';

	/**
	 * @description The run priority the tests save over the stored one.
	 */
	private static final Decimal CHANGED_RUN_PRIORITY = 7;

	/**
	 * @description Inserts the administrator who holds the Kern Job Runner Management permission set, read back by
	 * getManagingAdmin, the user without access to the log entry object, read back by getRestrictedUser, and the
	 * standard user without the job runner permission, read back by getUnpermittedUser.
	 */
	@TestSetup
	private static void setupUsers()
	{
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_SYSTEM_ADMIN, MANAGING_ADMIN_COMPANY, UTIL_ScheduledJobRunner.JOB_RUNNER_MANAGEMENT_PERMISSION_SET_NAME);
		TST_Factory.insertUser(SEL_Profile.PROFILE_MINIMUM_ACCESS, RESTRICTED_USER_COMPANY);
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, UNPERMITTED_USER_COMPANY, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);
	}

	/**
	 * @description Reads back the administrator who holds the Kern Job Runner Management permission set.
	 *
	 * @return The managing administrator.
	 */
	private static User getManagingAdmin()
	{
		return new SEL_User().findByCompanyName(MANAGING_ADMIN_COMPANY);
	}

	/**
	 * @description Reads back the user who may not read log entries.
	 *
	 * @return The restricted user.
	 */
	private static User getRestrictedUser()
	{
		return new SEL_User().findByCompanyName(RESTRICTED_USER_COMPANY);
	}

	/**
	 * @description Reads back the standard user who holds no job runner permission.
	 *
	 * @return The user without the job runner permission.
	 */
	private static User getUnpermittedUser()
	{
		return new SEL_User().findByCompanyName(UNPERMITTED_USER_COMPANY);
	}

	/**
	 * @description Plain Schedulable class without IF_Schedulable for testing.
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
	public class PlainSchedulable implements Schedulable
	{
		/**
		 * @description No-op execute.
		 *
		 * @param context The SchedulableContext.
		 */
		public void execute(SchedulableContext context)
		{
		}
	}

	/**
	 * @description Tests that getSchedulableClasses returns known Schedulable class names.
	 */
	@IsTest
	private static void shouldReturnSchedulableClasses()
	{
		List<String> classNames = CTRL_ScheduledJob.getSchedulableClasses();

		Assert.isFalse(classNames.isEmpty(), 'Should return at least one Schedulable class');
		Assert.isTrue(classNames.contains(SCHED_DeactivateUsers.class.getName()), 'Should contain SCHED_DeactivateUsers');
	}

	/**
	 * @description Tests that getSchedulableClasses returns cached values from the platform cache.
	 * Requires Platform Cache capacity — without it the seeded entry cannot persist and the
	 * controller recomputes the real class list.
	 */
	@IsTest
	private static void shouldReturnSchedulableClassesFromCache()
	{
		if(!UTIL_Cache.isOrgAllocated())
		{
			return;
		}

		List<String> cached = new List<String> {'CachedSchedulable'};
		UTIL_Cache.org().put(CTRL_ScheduledJob.CACHE_KEY_SCHEDULABLE_CLASSES, cached);

		List<String> classNames = CTRL_ScheduledJob.getSchedulableClasses();

		Assert.areEqual(cached, classNames, 'Should return cached class names');
	}

	/**
	 * @description Tests that a list scanned afresh is stored in org Platform Cache under the class list key, so the next
	 * request is served from there. Requires Platform Cache capacity, as the test above does.
	 */
	@IsTest
	private static void shouldStoreTheScannedListInOrgCache()
	{
		if(!UTIL_Cache.isOrgAllocated())
		{
			return;
		}

		UTIL_Cache.org().remove(CTRL_ScheduledJob.CACHE_KEY_SCHEDULABLE_CLASSES);

		List<String> classNames = CTRL_ScheduledJob.getSchedulableClasses();

		Assert.areEqual(classNames, UTIL_Cache.org().get(CTRL_ScheduledJob.CACHE_KEY_SCHEDULABLE_CLASSES), 'The scanned list is stored under the class list key');
	}

	/**
	 * @description Tests that a class name typed in another letter case still finds the class and its parameters, which
	 * is how the editors check a name the list does not show.
	 */
	@IsTest
	private static void shouldAcceptATypedClassNameInAnyLetterCase()
	{
		List<DTO_ScheduledParameterDefinition> parameters = CTRL_ScheduledJob.getParameterDefinitions(SCHED_DeactivateUsers.class.getName().toLowerCase());

		Assert.isFalse(parameters.isEmpty(), 'A class name typed in lower case finds the class and its parameters');
	}

	/**
	 * @description Tests that a typed name of a class that is not Schedulable is refused, which is what the editors show
	 * under the class field.
	 */
	@IsTest
	private static void shouldRefuseATypedClassThatIsNotSchedulable()
	{
		try
		{
			CTRL_ScheduledJob.getParameterDefinitions(CTRL_ScheduledJob.class.getName());
			Assert.fail('A class that is not Schedulable must be refused');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, AuraHandledException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests that getParameterDefinitions returns parameters for an IF_Schedulable/SCHED_Base class.
	 */
	@IsTest
	private static void shouldReturnParameterDefinitionsForSchedulableConfig()
	{
		List<DTO_ScheduledParameterDefinition> parameters = CTRL_ScheduledJob.getParameterDefinitions(SCHED_DeactivateUsers.class.getName());

		Assert.isNotNull(parameters, 'Parameters should not be null for IF_Schedulable/SCHED_Base class');
		Assert.isFalse(parameters.isEmpty(), 'Parameters should not be empty');
	}

	/**
	 * @description Tests that getParameterDefinitions returns null for a plain Schedulable class.
	 */
	@IsTest
	private static void shouldReturnNullForPlainSchedulable()
	{
		List<DTO_ScheduledParameterDefinition> parameters = CTRL_ScheduledJob.getParameterDefinitions(PlainSchedulable.class.getName());

		Assert.isNull(parameters, 'Parameters should be null for plain Schedulable class');
	}

	/**
	 * @description Tests that getParameterDefinitions throws for an invalid class name.
	 */
	@IsTest
	private static void shouldThrowForInvalidClassName()
	{
		try
		{
			CTRL_ScheduledJob.getParameterDefinitions(UTIL_Random.randomName());
			Assert.fail('Should throw AuraHandledException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, AuraHandledException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests that getParameterDefinitions returns null for a blank class name.
	 */
	@IsTest
	private static void shouldReturnNullForBlankClassName()
	{
		List<DTO_ScheduledParameterDefinition> parameters = CTRL_ScheduledJob.getParameterDefinitions('');

		Assert.isNull(parameters, 'Parameters should be null for blank class name');
	}

	/**
	 * @description Tests that saveRecord inserts a new ScheduledJob__c record.
	 */
	@IsTest
	private static void shouldInsertNewRecord()
	{
		CTRL_ScheduledJob.SaveRequest request = new CTRL_ScheduledJob.SaveRequest();
		request.schedulerName = 'Test Scheduler';
		request.className = PlainSchedulable.class.getName();
		request.cronExpression = '0 0 12 * * ?';
		request.isActive = false;
		request.description = 'Test description';
		request.parameters = new Map<String, String> {'param1' => 'value1'};

		Test.startTest();
		Id recordId = CTRL_ScheduledJob.saveRecord(JSON.serialize(request));
		Test.stopTest();

		Assert.isNotNull(recordId, 'Record ID should not be null after insert');
		ScheduledJob__c record = (ScheduledJob__c)new SEL_ScheduledJob().findById(recordId);
		Assert.areEqual('Test Scheduler', record.SchedulerName__c, 'Scheduler name should match');
		Assert.areEqual
				(
						new DTO_NameValues(new Map<String, String> {'param1' => 'value1'}).serialize(),
						record.Parameters__c,
						'Parameters should be stored as serialized DTO_NameValues'
				);
	}

	/**
	 * @description Tests that saveRecord updates an existing ScheduledJob__c record.
	 */
	@IsTest
	private static void shouldUpdateExistingRecord()
	{
		ScheduledJob__c existingRecord = TST_Factory.insertInactiveScheduledJob(PlainSchedulable.class.getName());

		CTRL_ScheduledJob.SaveRequest request = new CTRL_ScheduledJob.SaveRequest();
		request.recordId = existingRecord.Id;
		request.schedulerName = 'Updated Name';
		request.className = PlainSchedulable.class.getName();
		request.cronExpression = '0 0 6 * * ?';
		request.isActive = false;
		request.description = 'Updated description';
		request.parameters = new Map<String, String> {'param1' => 'updated'};

		Test.startTest();
		Id recordId = CTRL_ScheduledJob.saveRecord(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(existingRecord.Id, recordId, 'Record ID should match existing record');
		ScheduledJob__c record = (ScheduledJob__c)new SEL_ScheduledJob().findById(recordId);
		Assert.areEqual('Updated Name', record.SchedulerName__c, 'Scheduler name should be updated');
		Assert.areEqual
				(
						new DTO_NameValues(new Map<String, String> {'param1' => 'updated'}).serialize(),
						record.Parameters__c,
						'Parameters should be stored as serialized DTO_NameValues'
				);
	}

	/**
	 * @description Tests that saveRecord activates an inactive record and schedules the job.
	 */
	@IsTest
	private static void shouldActivateInactiveRecord()
	{
		ScheduledJob__c existingRecord = TST_Factory.insertInactiveScheduledJob(PlainSchedulable.class.getName());

		CTRL_ScheduledJob.SaveRequest request = new CTRL_ScheduledJob.SaveRequest();
		request.recordId = existingRecord.Id;
		request.schedulerName = 'Activated Job';
		request.className = PlainSchedulable.class.getName();
		request.cronExpression = '0 0 3 * * ?';
		request.isActive = true;
		request.description = 'Activation test';
		request.parameters = new Map<String, String>();

		Test.startTest();
		Id recordId = CTRL_ScheduledJob.saveRecord(JSON.serialize(request));
		Test.stopTest();

		ScheduledJob__c record = (ScheduledJob__c)new SEL_ScheduledJob().findById(recordId);
		Assert.isTrue(record.IsActive__c, 'Record should be active');
		Assert.isNotNull(record.ScheduledJobId__c, 'Active record should have a ScheduledJobId');
	}

	/**
	 * @description Tests that saveRecord stores null Parameters__c when parameters map is empty.
	 */
	@IsTest
	private static void shouldStoreNullParametersWhenEmpty()
	{
		CTRL_ScheduledJob.SaveRequest request = new CTRL_ScheduledJob.SaveRequest();
		request.schedulerName = 'Empty Params';
		request.className = PlainSchedulable.class.getName();
		request.cronExpression = '0 0 12 * * ?';
		request.isActive = false;
		request.parameters = new Map<String, String>();

		Test.startTest();
		Id recordId = CTRL_ScheduledJob.saveRecord(JSON.serialize(request));
		Test.stopTest();

		ScheduledJob__c record = (ScheduledJob__c)new SEL_ScheduledJob().findById(recordId);
		Assert.isNull(record.Parameters__c, 'Empty parameters should store null');
	}

	/**
	 * @description Tests that saveRecord stores null Parameters__c when parameters is null.
	 */
	@IsTest
	private static void shouldStoreNullParametersWhenNull()
	{
		CTRL_ScheduledJob.SaveRequest request = new CTRL_ScheduledJob.SaveRequest();
		request.schedulerName = 'Null Params';
		request.className = PlainSchedulable.class.getName();
		request.cronExpression = '0 0 12 * * ?';
		request.isActive = false;
		request.parameters = null;

		Test.startTest();
		Id recordId = CTRL_ScheduledJob.saveRecord(JSON.serialize(request));
		Test.stopTest();

		ScheduledJob__c record = (ScheduledJob__c)new SEL_ScheduledJob().findById(recordId);
		Assert.isNull(record.Parameters__c, 'Null parameters should store null');
	}

	/**
	 * @description Tests that saveRecord populates Timezone__c with the running user's timezone when no explicit timezone is provided.
	 */
	@IsTest
	private static void shouldPopulateTimezoneOnInsert()
	{
		CTRL_ScheduledJob.SaveRequest request = new CTRL_ScheduledJob.SaveRequest();
		request.schedulerName = 'Timezone Test';
		request.className = PlainSchedulable.class.getName();
		request.cronExpression = '0 0 12 * * ?';
		request.isActive = false;

		Test.startTest();
		Id recordId = CTRL_ScheduledJob.saveRecord(JSON.serialize(request));
		Test.stopTest();

		ScheduledJob__c record = (ScheduledJob__c)new SEL_ScheduledJob().findById(recordId);
		Assert.areEqual(UserInfo.getTimeZone().getID(), record.Timezone__c, 'Timezone should default to running user timezone');
	}

	/**
	 * @description Tests that saveRecord stores the explicit timezone when provided in the request.
	 */
	@IsTest
	private static void shouldUseExplicitTimezoneWhenProvided()
	{
		CTRL_ScheduledJob.SaveRequest request = new CTRL_ScheduledJob.SaveRequest();
		request.schedulerName = 'Explicit TZ';
		request.className = PlainSchedulable.class.getName();
		request.cronExpression = '0 0 12 * * ?';
		request.isActive = false;
		request.timezone = 'America/New_York';

		Test.startTest();
		Id recordId = CTRL_ScheduledJob.saveRecord(JSON.serialize(request));
		Test.stopTest();

		ScheduledJob__c record = (ScheduledJob__c)new SEL_ScheduledJob().findById(recordId);
		Assert.areEqual('America/New_York', record.Timezone__c, 'Timezone should match the explicitly provided value');
	}

	/**
	 * @description Tests that getUserTimezone returns the running user's timezone ID.
	 */
	@IsTest
	private static void shouldReturnUserTimezone()
	{
		String result = CTRL_ScheduledJob.getUserTimezone();

		Assert.areEqual(UserInfo.getTimeZone().getID(), result, 'Should return running user timezone ID');
	}

	/**
	 * @description Tests that saveRecord persists the execution mode, the run priority and the overlap policy, and
	 * that a blank mode and a blank policy save with their defaults.
	 */
	@IsTest
	private static void saveRecordPersistsTheModeThePriorityAndThePolicyAndDefaultsThemForOwnMode()
	{
		System.runAs(getManagingAdmin())
		{
			CTRL_ScheduledJob.SaveRequest request = new CTRL_ScheduledJob.SaveRequest();
			request.schedulerName = 'On the runner';
			request.className = SCHED_PurgeRecords.class.getName();
			request.cronExpression = '0 */5 * * * ?';
			request.isActive = true;
			request.timezone = 'UTC';
			request.parameters = new Map<String, String> {SCHED_PurgeRecords.REQUIRED_PARAMETER_OBJECT_NAME => UTIL_SObjectDescribe.getObjectNameFromType(LogEntry__c.SObjectType)};
			request.executionMode = UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER;
			request.runPriority = 3;
			request.overlapPolicy = UTIL_ScheduledJobRunner.OVERLAP_POLICY_ALLOW;

			Id savedId = CTRL_ScheduledJob.saveRecord(JSON.serialize(request));

			ScheduledJob__c saved = (ScheduledJob__c)new SEL_ScheduledJob().findById(savedId);
			Assert.areEqual(UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER, saved.ExecutionMode__c, 'the mode is saved');
			Assert.areEqual(3, saved.RunPriority__c, 'the priority is saved');
			Assert.areEqual(UTIL_ScheduledJobRunner.OVERLAP_POLICY_ALLOW, saved.OverlapPolicy__c, 'the policy is saved');
			Assert.isNotNull(saved.NextRunAt__c, 'the trigger seeded the cursor through the real save path');

			CTRL_ScheduledJob.SaveRequest ownMode = new CTRL_ScheduledJob.SaveRequest();
			ownMode.schedulerName = 'Own slot';
			ownMode.className = SCHED_PurgeRecords.class.getName();
			ownMode.cronExpression = '0 0 2 * * ?';
			ownMode.isActive = false;
			ownMode.parameters = request.parameters;
			ScheduledJob__c savedOwn = (ScheduledJob__c)new SEL_ScheduledJob().findById(CTRL_ScheduledJob.saveRecord(JSON.serialize(ownMode)));
			Assert.areEqual(UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB, savedOwn.ExecutionMode__c, 'a blank mode saves as own mode');
			Assert.areEqual(UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, savedOwn.OverlapPolicy__c, 'a blank policy saves as Skip');
		}
	}

	/**
	 * @description Tests that saving an existing job with a request that names none of the job runner settings leaves
	 * all three as they are, so a user who cannot read them does not move the job off the job runner.
	 */
	@IsTest
	private static void saveRecordKeepsTheJobRunnerSettingsAnUpdateDoesNotName()
	{
		System.runAs(getManagingAdmin())
		{
			ScheduledJob__c existingRecord = insertJobRunnerRecord();

			Id savedId = CTRL_ScheduledJob.saveRecord(JSON.serialize(newRequestWithoutJobRunnerSettings(existingRecord.Id)));

			ScheduledJob__c saved = (ScheduledJob__c)new SEL_ScheduledJob().findById(savedId);
			Assert.areEqual(UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER, saved.ExecutionMode__c, 'Expected the job to stay on the job runner');
			Assert.areEqual(STORED_RUN_PRIORITY, saved.RunPriority__c, 'Expected the run priority to stay as it was');
			Assert.areEqual(UTIL_ScheduledJobRunner.OVERLAP_POLICY_ALLOW, saved.OverlapPolicy__c, 'Expected the overlap policy to stay as it was');
		}
	}

	/**
	 * @description Tests that saving an existing job with a request that names the run priority in another letter case
	 * (a capital R) still writes it, as a new job's save does.
	 */
	@IsTest
	private static void saveRecordWritesTheRunPriorityAnUpdateNamesInAnotherLetterCase()
	{
		System.runAs(getManagingAdmin())
		{
			ScheduledJob__c existingRecord = insertJobRunnerRecord();
			Map<String, Object> request = newRequestWithoutJobRunnerSettings(existingRecord.Id);
			request.put(RUN_PRIORITY_KEY_WITH_CAPITAL_LETTER, CHANGED_RUN_PRIORITY);

			Id savedId = CTRL_ScheduledJob.saveRecord(JSON.serialize(request));

			ScheduledJob__c saved = (ScheduledJob__c)new SEL_ScheduledJob().findById(savedId);
			Assert.areEqual(CHANGED_RUN_PRIORITY, saved.RunPriority__c, 'Expected the run priority to be written');
		}
	}

	/**
	 * @description Tests that a user without the job runner permission can save an existing job runner job with a request
	 * that names none of the job runner settings, and that the job stays on the job runner with its settings.
	 */
	@IsTest
	private static void saveRecordKeepsTheJobRunnerSettingsForAUserWithoutTheJobRunnerPermission()
	{
		ScheduledJob__c existingRecord;
		Id savedId;

		System.runAs(getManagingAdmin())
		{
			existingRecord = insertJobRunnerRecord();
		}

		User unpermittedUser = getUnpermittedUser();
		Assert.isFalse
				(
						SEL_CustomPermission.hasPackagePermission(unpermittedUser.Id, UTIL_ScheduledJobRunner.MANAGE_JOB_RUNNER_CUSTOM_PERMISSION_NAME),
						'This org grants ' +
						UTIL_ScheduledJobRunner.MANAGE_JOB_RUNNER_CUSTOM_PERMISSION_NAME +
						' to the Standard User profile (an all-users package install), so no user without it exists to save as; ' +
						'run this suite in an org installed for admins only'
				);

		System.runAs(unpermittedUser)
		{
			Assert.isFalse(UTIL_ScheduledJobRunner.hasManagePermission(), 'Expected the Standard User to hold no job runner manage permission');
			savedId = CTRL_ScheduledJob.saveRecord(JSON.serialize(newRequestWithoutJobRunnerSettings(existingRecord.Id)));
		}

		ScheduledJob__c saved = (ScheduledJob__c)new SEL_ScheduledJob().findById(savedId);
		Assert.areEqual(UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER, saved.ExecutionMode__c, 'Expected the job to stay on the job runner');
		Assert.areEqual(STORED_RUN_PRIORITY, saved.RunPriority__c, 'Expected the run priority to stay as it was');
		Assert.areEqual(UTIL_ScheduledJobRunner.OVERLAP_POLICY_ALLOW, saved.OverlapPolicy__c, 'Expected the overlap policy to stay as it was');
	}

	/**
	 * @description Tests that saving an existing job with a request that names the run priority with no value clears
	 * the run priority, and leaves the two job runner settings the request does not name as they are.
	 */
	@IsTest
	private static void saveRecordClearsTheRunPriorityAnUpdateSendsWithNoValue()
	{
		System.runAs(getManagingAdmin())
		{
			ScheduledJob__c existingRecord = insertJobRunnerRecord();
			Map<String, Object> request = newRequestWithoutJobRunnerSettings(existingRecord.Id);
			request.put(RUN_PRIORITY_KEY, null);

			Id savedId = CTRL_ScheduledJob.saveRecord(JSON.serialize(request));

			ScheduledJob__c saved = (ScheduledJob__c)new SEL_ScheduledJob().findById(savedId);
			Assert.isNull(saved.RunPriority__c, 'Expected a run priority sent with no value to be cleared');
			Assert.areEqual(UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER, saved.ExecutionMode__c, 'Expected the job to stay on the job runner');
			Assert.areEqual(UTIL_ScheduledJobRunner.OVERLAP_POLICY_ALLOW, saved.OverlapPolicy__c, 'Expected the overlap policy to stay as it was');
		}
	}

	/**
	 * @description Tests that a new job saved with a request that names none of the job runner settings gets the
	 * defaults: it runs as its own scheduled job, with overlap policy Skip and no run priority.
	 */
	@IsTest
	private static void saveRecordGivesANewJobTheDefaultJobRunnerSettings()
	{
		Id savedId = CTRL_ScheduledJob.saveRecord(JSON.serialize(newRequestWithoutJobRunnerSettings(null)));

		ScheduledJob__c saved = (ScheduledJob__c)new SEL_ScheduledJob().findById(savedId);
		Assert.areEqual(UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB, saved.ExecutionMode__c, 'Expected a new job to run as its own scheduled job');
		Assert.areEqual(UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP, saved.OverlapPolicy__c, 'Expected a new job to have overlap policy Skip');
		Assert.isNull(saved.RunPriority__c, 'Expected a new job to have no run priority');
	}

	/**
	 * @description Tests that previewNextRun uses the same evaluator as the job runner's check and returns null for
	 * an invalid or a never-firing expression.
	 */
	@IsTest
	private static void previewNextRunUsesTheSameEvaluatorAsTheJobRunnersCheckAndReturnsNullForAnInvalidExpression()
	{
		Datetime preview = CTRL_ScheduledJob.previewNextRun('0 */15 * * * ?', 'UTC');

		Assert.isNotNull(preview, 'a valid expression previews');
		Assert.isTrue(preview > Datetime.now() && preview <= Datetime.now().addMinutes(15), 'within the next quarter hour');
		Assert.areEqual(0, Math.mod(preview.minuteGmt(), 15), 'on a quarter-hour mark, the same evaluator as the job runner\'s check');
		Assert.isNull(CTRL_ScheduledJob.previewNextRun('0 61 * * * ?', 'UTC'), 'an invalid expression previews nothing');
		Assert.isNull(CTRL_ScheduledJob.previewNextRun('0 0 12 * * ? 2020', 'UTC'), 'an expression that never fires previews nothing');
	}

	/**
	 * @description Tests that runNow wraps a refusal in an AuraHandledException that keeps its message.
	 */
	@IsTest
	private static void runNowWrapsARefusalInAnAuraHandledExceptionThatKeepsItsMessage()
	{
		System.runAs(getManagingAdmin())
		{
			TRG_Base.bypass(ScheduledJob__c.SObjectType);
			String logEntryObjectName = UTIL_SObjectDescribe.getObjectNameFromType(LogEntry__c.SObjectType);
			Map<String, String> ownModeParameters = new Map<String, String> {SCHED_PurgeRecords.REQUIRED_PARAMETER_OBJECT_NAME => logEntryObjectName};
			ScheduledJob__c ownMode = TST_Factory.insertScheduledJob(SCHED_PurgeRecords.class.getName(), ownModeParameters);
			TRG_Base.clearBypass(ScheduledJob__c.SObjectType);
			try
			{
				CTRL_ScheduledJob.runNow(ownMode.Id);
				Assert.fail('an own-mode record has no Run now');
			}
			catch(AuraHandledException refusal)
			{
				Assert.areEqual(System.Label.ScheduledJob_RunNowOnlyForJobRunnerRecords, refusal.getMessage(), 'the label text reaches the client');
			}
		}
	}

	/**
	 * @description Tests that getJobRunnerState reports an active runner and the running user's permission.
	 */
	@IsTest
	private static void getJobRunnerStateReportsAnActiveRunnerAndThePermission()
	{
		System.runAs(getManagingAdmin())
		{
			CTRL_ScheduledJob.DTO_JobRunnerState before = CTRL_ScheduledJob.getJobRunnerState();
			Assert.isFalse(before.isActive, 'no runner yet');
			Assert.isTrue(before.canManage, 'the managing admin may manage');

			Test.startTest();
			CTRL_HealthCheck.activateJobRunner(15);
			Test.stopTest();

			CTRL_ScheduledJob.DTO_JobRunnerState after = CTRL_ScheduledJob.getJobRunnerState();
			Assert.isTrue(after.isActive, 'the runner is active');
			Assert.areEqual(15, after.checkIntervalMinutes, 'at fifteen minutes');
		}
	}

	/**
	 * @description Tests that findLastRunLogEntryId answers with the newest log entry written against the record,
	 * and with nothing for a record that has none.
	 */
	@IsTest
	private static void findLastRunLogEntryIdAnswersWithTheNewestEntryWrittenAgainstTheRecord()
	{
		Id recordId = UTIL_Random.randomId(ScheduledJob__c.SObjectType);
		TST_Builder.of(LogEntry__c.SObjectType).withOverride(LogEntry__c.RecordId__c, recordId).build();
		LogEntry__c newest = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType).withOverride(LogEntry__c.RecordId__c, recordId).build();

		Id foundId = CTRL_ScheduledJob.findLastRunLogEntryId(recordId);

		Assert.areEqual(newest.Id, foundId, 'the newest entry written against the record is the one the link opens');
		Assert.isNull(CTRL_ScheduledJob.findLastRunLogEntryId(UTIL_Random.randomId(ScheduledJob__c.SObjectType)), 'a record with no entry has nothing to open');
	}

	/**
	 * @description Tests that findLastRunLogEntryId answers with nothing for a user who may not read log entries,
	 * even though an entry exists for the record.
	 */
	@IsTest
	private static void findLastRunLogEntryIdAnswersWithNothingForAUserWhoMayNotReadLogEntries()
	{
		Id recordId = UTIL_Random.randomId(ScheduledJob__c.SObjectType);
		TST_Builder.of(LogEntry__c.SObjectType).withOverride(LogEntry__c.RecordId__c, recordId).build();

		System.runAs(getRestrictedUser())
		{
			Assert.isNull(CTRL_ScheduledJob.findLastRunLogEntryId(recordId), 'a user who cannot read log entries is offered nothing to open');
		}
	}

	/**
	 * @description Inserts an inactive job that runs on the job runner, with run priority 5 and overlap policy Allow.
	 *
	 * @return The inserted job.
	 */
	private static ScheduledJob__c insertJobRunnerRecord()
	{
		return (ScheduledJob__c)TST_Builder.of(ScheduledJob__c.SObjectType)
				.withOverride(ScheduledJob__c.SchedulerName__c, UTIL_Random.randomName())
				.withOverride(ScheduledJob__c.ClassName__c, PlainSchedulable.class.getName())
				.withOverride(ScheduledJob__c.CronExpression__c, NOON_EVERY_DAY)
				.withOverride(ScheduledJob__c.IsActive__c, false)
				.withOverride(ScheduledJob__c.ExecutionMode__c, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER)
				.withOverride(ScheduledJob__c.RunPriority__c, STORED_RUN_PRIORITY)
				.withOverride(ScheduledJob__c.OverlapPolicy__c, UTIL_ScheduledJobRunner.OVERLAP_POLICY_ALLOW)
				.build();
	}

	/**
	 * @description Builds the request a save sends when it names only the job's name, class and schedule (and the
	 * record id, for an existing job), and none of the three job runner settings.
	 *
	 * @param recordId The job to update, or null to insert a new one.
	 *
	 * @return The request as a map of names to values.
	 */
	private static Map<String, Object> newRequestWithoutJobRunnerSettings(Id recordId)
	{
		CTRL_ScheduledJob.SaveRequest request = new CTRL_ScheduledJob.SaveRequest();
		request.recordId = recordId;
		request.schedulerName = UTIL_Random.randomName();
		request.className = PlainSchedulable.class.getName();
		request.cronExpression = NOON_EVERY_DAY;

		return (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(request, true));
	}
}