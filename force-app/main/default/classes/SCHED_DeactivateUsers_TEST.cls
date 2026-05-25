// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the behavior of the SCHED_DeactivateUsers schedulable class, which deactivates users based on specified profile names and inactivity duration.
 *
 * @see SCHED_DeactivateUsers
 *
 * @author Jason van Beukering
 *
 * @group Bulk DML
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class SCHED_DeactivateUsers_TEST
{
	private static final String CHATTER_FREE_PROFILE = SEL_Profile.PROFILE_CHATTER_FREE_USER;
	private static final String DAYS_PARAM = SCHED_DeactivateUsers.REQUIRED_PARAMETER_MINIMUM_NUMBER_OF_DAYS;
	private static final String ERROR_NO_JOB_STARTED = SCHED_DeactivateUsers.class.getName() + ' was not started';
	private static final String MINIMUM_DAYS = '10';
	private static final String PROFILE_PARAM = SCHED_DeactivateUsers.REQUIRED_PARAMETER_PROFILE_NAMES;
	private static final String SCHEDULER_CLASS_NAME = SCHED_DeactivateUsers.class.getName();
	private static final String SYSTEM_ADMIN_PROFILE = SEL_Profile.PROFILE_SYSTEM_ADMIN;

	/**
	 * @description Tests that getParameterDefinitions returns the expected parameter definitions.
	 *
	 * @see SCHED_DeactivateUsers.getParameterDefinitions
	 */
	@IsTest
	private static void shouldReturnParameterDefinitions()
	{
		SCHED_DeactivateUsers scheduler = new SCHED_DeactivateUsers();
		List<DTO_ScheduledParameterDefinition> parameters = scheduler.getParameterDefinitions();

		Assert.areEqual(4, parameters.size(), 'Should return 4 parameter definitions');
		Assert.areEqual(SCHED_DeactivateUsers.REQUIRED_PARAMETER_PROFILE_NAMES, parameters[0].name, 'First parameter should be profileNames');
		Assert.isTrue(parameters[0].isRequired, 'profileNames should be required');
		Assert.areEqual(SCHED_DeactivateUsers.REQUIRED_PARAMETER_MINIMUM_NUMBER_OF_DAYS, parameters[1].name, 'Second parameter should be minimumNumberOfDays');
		Assert.isTrue(parameters[1].isRequired, 'minimumNumberOfDays should be required');
		Assert.isFalse(parameters[2].isRequired, 'batchSize should be optional');
		Assert.isFalse(parameters[3].isRequired, 'allOrNothing should be optional');
	}

	/**
	 * @description Tests that the scheduler fails when required parameters are not provided.
	 *
	 * @see SCHED_DeactivateUsers
	 */
	@IsTest
	private static void invalidParameters()
	{
		Test.startTest();

		try
		{
			TST_Factory.insertScheduledJob(SCHEDULER_CLASS_NAME);

			Assert.fail('Expected DmlException to be thrown');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Incorrect Exception Thrown');
		}

		Test.stopTest();
	}

	/**
	 * @description Tests that the scheduler runs successfully with valid parameters.
	 *
	 * @see SCHED_DeactivateUsers
	 */
	@IsTest
	private static void runSchedule()
	{
		Test.startTest();

		Map<String, String> parameters = new Map<String, String>
		{
				PROFILE_PARAM => CHATTER_FREE_PROFILE + '|' + SYSTEM_ADMIN_PROFILE,
				DAYS_PARAM => MINIMUM_DAYS
		};
		ScheduledJob__c scheduler = TST_Factory.insertScheduledJob(SCHEDULER_CLASS_NAME, parameters);
		scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);

		Test.stopTest();

		Assert.isNotNull(scheduler.ScheduledJobId__c, ERROR_NO_JOB_STARTED);
	}
}