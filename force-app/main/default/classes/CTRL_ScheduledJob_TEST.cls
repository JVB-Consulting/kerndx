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
 * @date March 2026, June 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class CTRL_ScheduledJob_TEST
{
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
}