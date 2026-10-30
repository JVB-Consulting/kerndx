// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for SCHED_JobRunner: the runner's schedulable declares no parameters and hands its execute to
 * one check for due jobs.
 *
 * @see SCHED_JobRunner
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date September 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SCHED_JobRunner_TEST
{
	/**
	 * @description Company name that identifies the test user who holds no job runner permission. A package install writes
	 * the Manage Job Runner permission into the System Administrator profile. So this user is on the Standard User profile,
	 * which the default install leaves without that permission.
	 */
	private static final String NO_JOB_RUNNER_PERMISSION_COMPANY = 'SCHED_JobRunner_TEST-plain';

	/**
	 * @description The log method the runner writes its entries under. The class half comes from the class itself, so it
	 * carries the package namespace exactly as the runner writes it.
	 */
	private static final String CHECK_METHOD = UTIL_ScheduledJobRunner.class.getName() + '.checkForDueJobs';

	/**
	 * @description Tests that the runner asks an administrator for nothing, and that the class name every runner record
	 * carries resolves back to a job the framework can run.
	 */
	@IsTest
	private static void declaresNoParametersAndIsASchedulable()
	{
		SCHED_JobRunner runner = new SCHED_JobRunner();

		Assert.isTrue(runner.getParameterDefinitions().isEmpty(), 'the runner takes no parameters');
		Type resolved = UTIL_System.findTypeForClassName(UTIL_ScheduledJobRunner.RUNNER_CLASS_NAME, Schedulable.class);
		Assert.areEqual(SCHED_JobRunner.class, resolved, 'the name a runner record carries resolves back to this class as a Schedulable');
	}

	/**
	 * @description Tests that the platform entry point itself refuses a user who does not hold the Manage Job Runner
	 * permission, and says so once at WARN, so a runner left on a user who lost the permission is visible in the log.
	 */
	@IsTest
	private static void executeWithoutThePermissionRefusesAtTheEntryGuard()
	{
		TST_Factory.newFeatureFlag(UTIL_ScheduledJobRunner.FEATURE_FLAG_NAME);
		LogSetting__c setting = new LogSetting__c();
		setting.IsEnabled__c = true;
		setting.LogLevelThreshold__c = LOG_Engine.LEVEL_DEBUG;
		LOG_Engine.logSettingOverride = setting;
		LOG_Builder.ignoreTestMode = true;
		User userWithoutPermission = TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_STANDARD_USER, NO_JOB_RUNNER_PERMISSION_COMPANY, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);
		Assert.isFalse
				(
						SEL_CustomPermission.hasPackagePermission(userWithoutPermission.Id, UTIL_ScheduledJobRunner.MANAGE_JOB_RUNNER_CUSTOM_PERMISSION_NAME),
						'This org grants ' +
						UTIL_ScheduledJobRunner.MANAGE_JOB_RUNNER_CUSTOM_PERMISSION_NAME +
						' to the Standard User profile (an all-users package install), so no non-holder exists to prove the refusal against; ' +
						'run this suite in an org installed for admins only'
				);
		System.runAs(userWithoutPermission)
		{
			Test.startTest();
			new SCHED_JobRunner().execute(null);
			Test.stopTest();
		}

		Test.getEventBus().deliver();
		List<LogEntry__c> entries = new SEL_LogEntry().findAllByMethod(CHECK_METHOD);
		Assert.areEqual(1, entries.size(), 'the refusal is one WARN');
		Assert.areEqual(LoggingLevel.WARN.name(), entries[0].LogLevel__c, 'at WARN');
	}
}
