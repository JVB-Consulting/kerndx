// SPDX-License-Identifier: BUSL-1.1
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
	 * @description Inserts the administrator who holds the Kern Job Runner Management permission set, read back by
	 * getManagingAdmin, and the user without access to the log entry object, read back by getRestrictedUser.
	 */
	@TestSetup
	private static void setupUsers()
	{
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_SYSTEM_ADMIN, MANAGING_ADMIN_COMPANY, UTIL_ScheduledJobRunner.JOB_RUNNER_MANAGEMENT_PERMISSION_SET_NAME);
		TST_Factory.insertUser(SEL_Profile.PROFILE_MINIMUM_ACCESS, RESTRICTED_USER_COMPANY);
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
}