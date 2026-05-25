// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class to check behavior of SCHED_PurgeRecords_TEST
 *
 * @see SCHED_PurgeRecords
 *
 * @author Jason van Beukering
 *
 * @group Bulk DML
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
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
}