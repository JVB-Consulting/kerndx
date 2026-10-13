// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for FastStart_ScheduledJob_DEMO: a record schedules it and its run does not fail, the switch makes
 * a run fail with the message its log entry shows, and the editor gets one switch, off by default.
 *
 * @see FastStart_ScheduledJob_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class FastStart_ScheduledJob_DEMO_TEST
{
	/**
	 * @description Name of the record the test saves, apart from the one you made in the guide.
	 */
	private static final String TEST_JOB_NAME = 'Fast Start Scheduled Job Test';

	/**
	 * @description Every hour, on the hour.
	 */
	private static final String EVERY_HOUR = '0 0 * * * ?';

	/**
	 * @description How many parameters the job declares.
	 */
	private static final Integer DECLARED_PARAMETER_COUNT = 1;

	/**
	 * @description Verifies that an active record schedules the class, and that the run Test.stopTest() makes does not
	 * fail with the switch off.
	 */
	@IsTest
	private static void shouldScheduleFromARecordAndRunWithoutFailing()
	{
		Test.startTest();
		kern__ScheduledJob__c job = (kern__ScheduledJob__c)kern.TST_Builder.of(kern__ScheduledJob__c.SObjectType)
				.withOverride(kern__ScheduledJob__c.kern__SchedulerName__c, TEST_JOB_NAME)
				.withOverride(kern__ScheduledJob__c.kern__ClassName__c, FastStart_ScheduledJob_DEMO.class.getName())
				.withOverride(kern__ScheduledJob__c.kern__CronExpression__c, EVERY_HOUR)
				.withOverride(kern__ScheduledJob__c.kern__IsActive__c, true)
				.build();
		Test.stopTest();

		kern__ScheduledJob__c saved = (kern__ScheduledJob__c)kern.QRY_Builder.selectFrom(kern__ScheduledJob__c.SObjectType)
				.fields(new List<SObjectField> {kern__ScheduledJob__c.kern__ScheduledJobId__c})
				.condition(kern__ScheduledJob__c.Id).equals(job.Id)
				.getFirst();

		Assert.isNotNull(saved.kern__ScheduledJobId__c, 'The record scheduled the class: the platform job id is stored');
	}

	/**
	 * @description Verifies that a run with Fail on purpose switched on throws, with the message its log entry shows.
	 */
	@IsTest
	private static void shouldFailWhenAskedToFailOnPurpose()
	{
		FastStart_ScheduledJob_DEMO job = new FastStart_ScheduledJob_DEMO();
		job.setParameterValues(new kern.DTO_NameValues(new Map<String, String> {FastStart_ScheduledJob_DEMO.PARAMETER_FAIL_ON_PURPOSE => String.valueOf(true)}));

		try
		{
			job.execute(null);
			Assert.fail('A run asked to fail on purpose must throw');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, FastStart_ScheduledJob_DEMO.FailedOnPurposeException.class, 'Incorrect exception type');
			Assert.areEqual(FastStart_ScheduledJob_DEMO.FAILED_ON_PURPOSE_MESSAGE, error.getMessage(), 'The message is the one View log shows');
		}
	}

	/**
	 * @description Verifies that the job declares one switch, off by default, which the editor draws as a toggle.
	 */
	@IsTest
	private static void shouldDeclareOneSwitchThatIsOffByDefault()
	{
		List<kern.DTO_ScheduledParameterDefinition> definitions = new FastStart_ScheduledJob_DEMO().getParameterDefinitions();

		Assert.areEqual(DECLARED_PARAMETER_COUNT, definitions.size(), 'The job declares one parameter');
		Assert.areEqual(FastStart_ScheduledJob_DEMO.PARAMETER_FAIL_ON_PURPOSE, definitions[0].name, 'The parameter is the switch');
		Assert.areEqual(kern.DTO_ScheduledParameterDefinition.DataType.FLAG.name(), definitions[0].dataType, 'The editor draws a FLAG parameter as a toggle');
		Assert.areEqual(String.valueOf(false), definitions[0].defaultValue, 'The switch is off unless you switch it on');
	}
}
