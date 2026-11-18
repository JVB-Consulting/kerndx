// SPDX-License-Identifier: Apache-2.0
/**
 * @description Test class to check behavior of SCHED_PurgeRecords_TEST
 *
 * @see SCHED_PurgeRecords
 *
 * @author Jason van Beukering
 *
 * @group Bulk DML
 *
 * @date February 2026, November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class SCHED_PurgeRecords_TEST
{
	/**
	 * @description Number of Foobar__c records to create for test data.
	 */
	private static final Integer NUMBER_OF_RECORDS_TO_CREATE = 10;

	/**
	 * @description Object name parameter key for purge configuration.
	 */
	private static final String OBJECT_NAME_KEY = SCHED_PurgeRecords.REQUIRED_PARAMETER_OBJECT_NAME;

	/**
	 * @description Company name of the administrator, with the Kern Administrator permission set, who runs the scheduled
	 * purge of chain runs.
	 */
	private static final String TEST_ADMIN_COMPANY = 'SCHED_PurgeRecords_TEST-admin';

	/**
	 * @description Chain name carried by every chain run the tests save.
	 */
	private static final String TEST_CHAIN_NAME = 'ScheduledPurgeTestChain';

	/**
	 * @description The minimum age in days the scheduled purge of chain runs is given. A run that stalled this many days
	 * ago is old enough to be deleted.
	 */
	private static final Integer MINIMUM_AGE_DAYS = 10;

	/**
	 * @description Saves the administrator who runs the scheduled purge of chain runs, in its own setup transaction, so a
	 * test can use System.runAs with that user.
	 */
	@TestSetup
	private static void setupTestUsers()
	{
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_SYSTEM_ADMIN, TEST_ADMIN_COMPANY, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);
	}

	/**
	 * @description A scheduled purge goes through the same purge as a direct call, so it also deletes a chain run that
	 * stays Stalled. The job is given the chain run object, the CompletedAt__c date field and a minimum age, and runs as
	 * an administrator. It deletes the Stalled run that stalled long ago and keeps the one that stalled now.
	 *
	 * @see SCHED_PurgeRecords.execute
	 * @see UTIL_PurgeRecords.deleteOlderThanNDays
	 */
	@IsTest
	private static void shouldPurgeChainRunsThatStalledLongAgo()
	{
		System.runAs(new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY))
		{
			AsyncChainExecution__c oldStalled = insertStalledChainRun(Datetime.now().addDays(-MINIMUM_AGE_DAYS));
			AsyncChainExecution__c recentStalled = insertStalledChainRun(Datetime.now());
			DTO_NameValues parameters = new DTO_NameValues();
			parameters.add(OBJECT_NAME_KEY, UTIL_SObjectDescribe.getObjectNameFromType(AsyncChainExecution__c.SObjectType));
			parameters.add(SCHED_PurgeRecords.OPTIONAL_PARAMETER_DATE_FIELD_NAME, UTIL_SObjectDescribe.getCachedFieldName(AsyncChainExecution__c.CompletedAt__c));
			parameters.add(SCHED_PurgeRecords.OPTIONAL_PARAMETER_MINIMUM_NUMBER_OF_DAYS, String.valueOf(MINIMUM_AGE_DAYS));
			SCHED_PurgeRecords purgeJob = new SCHED_PurgeRecords();
			purgeJob.setParameterValues(parameters);

			Test.startTest();
			purgeJob.execute(null);
			Test.stopTest();

			Assert.isNull(new SEL_AsyncChainExecution().findByIdForMonitoring(oldStalled.Id), 'Expected the scheduled purge to delete the run that stalled long ago');
			Assert.isNotNull(new SEL_AsyncChainExecution().findByIdForMonitoring(recentStalled.Id), 'Expected the scheduled purge to keep the run that stalled now');
		}
	}

	/**
	 * @description Tests that getParameterDefinitions returns the expected parameter definitions.
	 *
	 * @see SCHED_PurgeRecords.getParameterDefinitions
	 */
	@IsTest
	private static void shouldReturnParameterDefinitions()
	{
		SCHED_PurgeRecords scheduler = new SCHED_PurgeRecords();
		List<DTO_ScheduledParameterDefinition> parameters = scheduler.getParameterDefinitions();

		Assert.areEqual(5, parameters.size(), 'Should return 5 parameter definitions');
		Assert.areEqual(SCHED_PurgeRecords.REQUIRED_PARAMETER_OBJECT_NAME, parameters[0].name, 'First parameter should be objectName');
		Assert.isTrue(parameters[0].isRequired, 'objectName should be required');
		Assert.isFalse(parameters[1].isRequired, 'minimumNumberOfDays should be optional');
		Assert.areEqual('CreatedDate', parameters[2].defaultValue, 'dateFieldName should default to CreatedDate');
	}

	/**
	 * @description Tests the behaviour of deleteOlderThanNDays
	 *
	 * @see SCHED_PurgeRecords.execute
	 * @see UTIL_PurgeRecords.deleteOlderThanNDays
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void deleteItemsOlderThanNDays()
	{
		TST_Factory.insertFoobars(NUMBER_OF_RECORDS_TO_CREATE);

		assertSchedulerStartsWithParameters(new Map<String, String>
		{
				OBJECT_NAME_KEY => SEL_Foobar.OBJECT_NAME,
				SCHED_PurgeRecords.OPTIONAL_PARAMETER_MINIMUM_NUMBER_OF_DAYS => String.valueOf(10)
		});
	}

	/**
	 * @description Tests the behaviour of deleteAllRecords
	 *
	 * @see SCHED_PurgeRecords.execute
	 * @see UTIL_PurgeRecords.deleteAllRecords
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void deleteAllRecords()
	{
		TST_Factory.insertFoobars(NUMBER_OF_RECORDS_TO_CREATE);

		assertSchedulerStartsWithParameters(new Map<String, String> {OBJECT_NAME_KEY => SEL_Foobar.OBJECT_NAME});
	}

	/**
	 * @description Tests the behaviour of deleteAllRecords
	 *
	 * @see SCHED_PurgeRecords.execute
	 */
	@IsTest
	private static void noObjectName()
	{
		try
		{
			Test.startTest();

			TST_Factory.insertScheduledJob(SCHED_PurgeRecords.class.getName());

			Assert.fail('Expected Exception to be thrown');

			Test.stopTest();
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Incorrect Exception Thrown');
		}
	}

	/**
	 * @description Inserts a SCHED_PurgeRecords scheduler with the given parameters and asserts it started.
	 *
	 * @param parameters The parameter name-value map for the scheduler.
	 */
	private static void assertSchedulerStartsWithParameters(Map<String, String> parameters)
	{
		Test.startTest();

		ScheduledJob__c scheduler = TST_Factory.insertScheduledJob(SCHED_PurgeRecords.class.getName(), parameters);
		scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);

		Test.stopTest();

		Assert.isNotNull(scheduler.ScheduledJobId__c, SCHED_PurgeRecords.class.getName() + ' was not started');
	}

	/**
	 * @description Saves one Stalled chain run with the Stalled category and the given stall time, in system mode, owned
	 * by the running user.
	 *
	 * @param stalledAt The stall time the run carries.
	 *
	 * @return The saved chain run.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static AsyncChainExecution__c insertStalledChainRun(Datetime stalledAt)
	{
		AsyncChainExecution__c chainRun = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.ChainName__c, TEST_CHAIN_NAME)
				.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_STALLED)
				.withOverride(AsyncChainExecution__c.CorrelationId__c, UTIL_Random.randomUUID())
				.withOverride(AsyncChainExecution__c.FailureCategory__c, SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED)
				.withOverride(AsyncChainExecution__c.StalledAt__c, stalledAt)
				.withoutInsertion()
				.build();
		DML_Builder.newTransaction().withSystemMode().doInsert(chainRun).execute();
		return chainRun;
	}
}