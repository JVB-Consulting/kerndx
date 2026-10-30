// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for SCHED_SubscriberJob.
 *
 * @see SCHED_SubscriberJob
 *
 * @author your.name@company.com
 *
 * @group Scheduler
 *
 * @date March 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class SCHED_SubscriberJob_TEST
{
	/**
	 * @description The object name the tests hand to the job.
	 */
	private static final String OBJECT_NAME = String.valueOf(Account.SObjectType);
	/**
	 * @description A batch size other than the job's default, so a test can tell a value it gave from the default.
	 */
	private static final Integer GIVEN_BATCH_SIZE = 500;

	/**
	 * @description The job declares its three parameters in order: objectName required with no default, batchSize a
	 * number defaulting to DEFAULT_BATCH_SIZE, and dryRun true or false defaulting to DEFAULT_DRY_RUN.
	 */
	@IsTest
	private static void shouldDeclareThreeParametersWithTheirDefaults()
	{
		List<kern.DTO_ScheduledParameterDefinition> definitions = new SCHED_SubscriberJob().getParameterDefinitions();

		Assert.areEqual(3, definitions.size(), 'Expected 3 parameter definitions, got ' + definitions.size());
		Assert.areEqual(SCHED_SubscriberJob.PARAMETER_OBJECT_NAME, definitions[0].name, 'Expected objectName first');
		Assert.isTrue(definitions[0].isRequired, 'Expected objectName to be required');
		Assert.isNull(definitions[0].defaultValue, 'Expected objectName to have no default');
		Assert.areEqual(SCHED_SubscriberJob.PARAMETER_BATCH_SIZE, definitions[1].name, 'Expected batchSize second');
		Assert.areEqual(String.valueOf(SCHED_SubscriberJob.DEFAULT_BATCH_SIZE), definitions[1].defaultValue, 'Expected the declared batch size default');
		Assert.areEqual(SCHED_SubscriberJob.PARAMETER_DRY_RUN, definitions[2].name, 'Expected dryRun third');
		Assert.areEqual(String.valueOf(SCHED_SubscriberJob.DEFAULT_DRY_RUN), definitions[2].defaultValue, 'Expected the declared dry-run default');
	}

	/**
	 * @description Values that were given reach the job as given, converted to a number and to true or false, and the
	 * defaults do not replace them.
	 */
	@IsTest
	private static void shouldExecuteWithParameters()
	{
		SCHED_SubscriberJob job = new SCHED_SubscriberJob();
		kern.DTO_NameValues parameters = new kern.DTO_NameValues();
		parameters.add(SCHED_SubscriberJob.PARAMETER_OBJECT_NAME, OBJECT_NAME);
		parameters.add(SCHED_SubscriberJob.PARAMETER_BATCH_SIZE, String.valueOf(GIVEN_BATCH_SIZE));
		parameters.add(SCHED_SubscriberJob.PARAMETER_DRY_RUN, String.valueOf(!SCHED_SubscriberJob.DEFAULT_DRY_RUN));
		job.setParameterValues(parameters);

		Test.startTest();
		job.execute(null);
		Test.stopTest();

		Assert.isTrue(SCHED_SubscriberJob.executed, 'Expected the job to have run');
		Assert.areEqual(OBJECT_NAME, SCHED_SubscriberJob.resolvedObjectName, 'Expected the given object name');
		Assert.areEqual(GIVEN_BATCH_SIZE, SCHED_SubscriberJob.resolvedBatchSize, 'Expected the given batch size');
		Assert.areEqual(!SCHED_SubscriberJob.DEFAULT_DRY_RUN, SCHED_SubscriberJob.resolvedDryRun, 'Expected the given dry-run setting');
	}

	/**
	 * @description A job run with no values handed over at all still applies the defaults it declares; objectName, which
	 * has no default, stays null.
	 */
	@IsTest
	private static void shouldApplyTheDeclaredDefaultsWhenNoValuesWereGiven()
	{
		SCHED_SubscriberJob job = new SCHED_SubscriberJob();

		Test.startTest();
		job.execute(null);
		Test.stopTest();

		Assert.isTrue(SCHED_SubscriberJob.executed, 'Expected the job to have run');
		Assert.isNull(SCHED_SubscriberJob.resolvedObjectName, 'Expected no object name, got ' + SCHED_SubscriberJob.resolvedObjectName);
		Assert.areEqual(SCHED_SubscriberJob.DEFAULT_BATCH_SIZE, SCHED_SubscriberJob.resolvedBatchSize, 'Expected the declared batch size default');
		Assert.areEqual(SCHED_SubscriberJob.DEFAULT_DRY_RUN, SCHED_SubscriberJob.resolvedDryRun, 'Expected the declared dry-run default');
	}

	/**
	 * @description A batchSize and a dryRun left blank take the defaults the job declares in getParameterDefinitions,
	 * read here from the declarations themselves, while the objectName that was given is kept.
	 */
	@IsTest
	private static void shouldApplyTheDeclaredDefaultsToBlankValues()
	{
		SCHED_SubscriberJob job = new SCHED_SubscriberJob();
		Map<String, String> declaredDefaults = new Map<String, String>();
		for(kern.DTO_ScheduledParameterDefinition definition : job.getParameterDefinitions())
		{
			declaredDefaults.put(definition.name, definition.defaultValue);
		}
		kern.DTO_NameValues parameters = new kern.DTO_NameValues();
		parameters.add(SCHED_SubscriberJob.PARAMETER_OBJECT_NAME, OBJECT_NAME);
		parameters.add(SCHED_SubscriberJob.PARAMETER_BATCH_SIZE, '');
		parameters.add(SCHED_SubscriberJob.PARAMETER_DRY_RUN, '');
		job.setParameterValues(parameters);

		Test.startTest();
		job.execute(null);
		Test.stopTest();

		Integer expectedBatchSize = Integer.valueOf(declaredDefaults.get(SCHED_SubscriberJob.PARAMETER_BATCH_SIZE));
		Boolean expectedDryRun = Boolean.valueOf(declaredDefaults.get(SCHED_SubscriberJob.PARAMETER_DRY_RUN));
		Assert.isTrue(SCHED_SubscriberJob.executed, 'Expected the job to have run');
		Assert.areEqual(OBJECT_NAME, SCHED_SubscriberJob.resolvedObjectName, 'Expected the given object name');
		Assert.areEqual(expectedBatchSize, SCHED_SubscriberJob.resolvedBatchSize, 'Expected the declared batch size default for a blank value');
		Assert.areEqual(expectedDryRun, SCHED_SubscriberJob.resolvedDryRun, 'Expected the declared dry-run default for a blank value');
	}
}
