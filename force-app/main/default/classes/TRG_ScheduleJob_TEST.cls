// SPDX-License-Identifier: Apache-2.0
/**
 * @description Test class for TRG_ScheduleJob trigger action.
 *
 * @see TRG_ScheduleJob
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date January 2026, November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity,PMD.NcssTypeCount')
@IsTest(seeAllData=false isParallel=false)
private class TRG_ScheduleJob_TEST
{
	/**
	 * @description Company name given to the admin user created in the test setup. It is unique to this class, so
	 * getTestAdmin can find that one user again by company name.
	 */
	private static final String TEST_ADMIN_COMPANY = 'TRG_ScheduleJob_TEST-admin';
	/**
	 * @description Failure message shown when a save is refused with a different kind of exception than the one the
	 * test expects.
	 */
	private static final String ERROR_INCORRECT_EXCEPTION = 'Incorrect Exception was thrown';
	/**
	 * @description Failure message shown when a save that the trigger must refuse goes through without an
	 * exception.
	 */
	private static final String NO_EXCEPTION_WAS_THROWN_AS_EXPECTED = 'No exception was thrown as expected';

	/**
	 * @description Company name identifying the administrator who also holds the Kern Job Runner Management permission set.
	 */
	private static final String MANAGING_ADMIN_COMPANY = 'TRG_ScheduleJob_TEST-managing';

	/**
	 * @description Company name identifying the Standard User who holds the Kern Job Runner Management permission set.
	 */
	private static final String STANDARD_USER_WITH_JOB_RUNNER_PERMISSION_COMPANY = 'TRG_ScheduleJob_TEST-with-permission';

	/**
	 * @description Company name identifying the Standard User who holds no job runner permission.
	 */
	private static final String STANDARD_USER_WITHOUT_JOB_RUNNER_PERMISSION_COMPANY = 'TRG_ScheduleJob_TEST-without-permission';

	/**
	 * @description Counts the calls a save makes to a job's setParameterValues, so a test can prove a save configures
	 * the job it schedules exactly once. A static of the outer class because Apex allows none in an inner class.
	 */
	private static Integer parameterInjectionCount = 0;

	/**
	 * @description Full name of the inner class JobSavingAction, the Foobar trigger action that saves a scheduled job from
	 * inside itself.
	 */
	private static final String JOB_SAVING_ACTION = TRG_ScheduleJob_TEST.class.getName() + '.JobSavingAction';

	/**
	 * @description The job JobSavingAction saves: it inserts the job when it has no Id yet, and updates it otherwise. A
	 * static of the outer class because Apex allows none in an inner class.
	 */
	private static ScheduledJob__c jobSavedByAnotherAction;

	/**
	 * @description Full name of the inner class SwitchOffRefusingAction, the scheduled job trigger action that refuses
	 * every update of a job.
	 */
	private static final String SWITCH_OFF_REFUSING_ACTION = TRG_ScheduleJob_TEST.class.getName() + '.SwitchOffRefusingAction';

	/**
	 * @description The error SwitchOffRefusingAction adds to each job it refuses, as a subscriber's own rule would.
	 */
	private static final String SWITCH_OFF_REFUSED_MESSAGE = 'This test refuses every update of a job.';

	/**
	 * @description The time zone a job-runner record's expression is read in, the evaluator's own default spelling.
	 */
	private static final String TIMEZONE_UTC = 'UTC';

	/**
	 * @description A second time zone, for a test that changes the time zone a job's expression is read in.
	 */
	private static final String TIMEZONE_NEW_YORK = 'America/New_York';

	/**
	 * @description An expression that fires every five minutes, so the seeded cursor is always within five minutes.
	 */
	private static final String CRON_EVERY_FIVE_MINUTES = '0 */5 * * * ?';

	/**
	 * @description An expression that fires on every seventh hour. Seven does not divide the hours of a day, so the gap across midnight is shorter.
	 */
	private static final String CRON_EVERY_SEVENTH_HOUR = '0 0 */7 * * ?';

	/**
	 * @description A cron expression that fires every hour of one weekday. Moved to another zone, some of its hours would
	 * land on the day before, so the move is refused.
	 */
	private static final String CRON_EVERY_HOUR_ON_MONDAYS = '0 0 * ? * MON';

	/**
	 * @description An expression naming four minutes of every hour, a grammar System.schedule refuses and Kern reads.
	 */
	private static final String CRON_MINUTES_AS_A_LIST = '0 0,15,30,45 * * * ?';

	/**
	 * @description An expression for the thirtieth of February, a date that never comes.
	 */
	private static final String CRON_THAT_NEVER_FIRES = '0 0 0 30 2 ?';

	/**
	 * @description An expression whose minutes field is out of range, so the evaluator cannot read it.
	 */
	private static final String CRON_WITH_AN_UNREADABLE_MINUTE = '0 61 * * * ?';

	/**
	 * @description The token the evaluator names when it refuses CRON_WITH_AN_UNREADABLE_MINUTE.
	 */
	private static final String UNREADABLE_MINUTE_TOKEN = '61';

	/**
	 * @description An expression firing once a day, for proving that an administrator's cron edit still re-schedules.
	 */
	private static final String CRON_HALF_PAST_THREE = '0 30 3 * * ?';

	/**
	 * @description The expression a runner record that checks at quarter past every hour carries.
	 */
	private static final String CRON_QUARTER_PAST_EVERY_HOUR = '0 15 * * * ?';

	/**
	 * @description The scheduler name Health Check gives the runner record that checks at quarter past every hour.
	 */
	private static final String RUNNER_RECORD_SCHEDULER_NAME = 'Job runner :15';

	/**
	 * @description The name of AttributeScheduler's one required parameter.
	 */
	private static final String REQUIRED_PARAMETER_NAME = 'param1';

	/**
	 * @description A value for AttributeScheduler's required parameter.
	 */
	private static final String REQUIRED_PARAMETER_VALUE = 'value1';

	/**
	 * @description A run priority for a job, used to edit a job without changing which code it runs.
	 */
	private static final Integer EDITED_RUN_PRIORITY = 5;

	/**
	 * @description The same parameter value in different letter case, the edit Apex's own string equality cannot see.
	 */
	private static final String REQUIRED_PARAMETER_VALUE_IN_OTHER_CASE = 'Value1';

	/**
	 * @description The label of AttributeScheduler's required parameter, the wording the trigger's refusal names.
	 */
	private static final String REQUIRED_PARAMETER_LABEL = 'Parameter 1';

	/**
	 * @description The most jobs one read of the due jobs may return. It is far more than a test creates, so every due job is returned.
	 */
	private static final Integer DUE_JOB_CHECK_LIMIT = 200;

	/**
	 * @description Creates a dedicated test admin user so System.runAs in each test starts a fresh
	 * permission-evaluation context, bypassing the synthetic-org permission-cache staleness issue
	 * that affected mutating the running user's permissionSet mid-transaction.
	 */
	@TestSetup
	private static void setupTestAdmin()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);

		setupManagingAdmin();
		setupStandardUsersWithAndWithoutJobRunnerPermission();
	}

	/**
	 * @description Tests that a scheduled job starts when a ScheduledJob__c record is inserted with Active = true.
	 */
	@IsTest
	private static void shouldStartJobOnInsert()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			ScheduledJob__c scheduler = TST_Factory.insertScheduledJob(PlainSchedulable.class.getName());

			Test.stopTest();

			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			Assert.isNotNull(scheduler.ScheduledJobId__c, 'Scheduled Job was not started');
		}
	}

	/**
	 * @description Tests that a scheduled job starts with valid attributes.
	 */
	@IsTest
	private static void shouldStartJobWithValidAttributes()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			ScheduledJob__c scheduler = TST_Factory.insertScheduledJob(AttributeScheduler.class.getName(), new Map<String, String> {'param1' => 'value1'});

			Test.stopTest();

			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			Assert.isNotNull(scheduler.ScheduledJobId__c, 'Scheduled Job was not started');
		}
	}

	/**
	 * @description Tests that insertion fails with invalid attributes.
	 */
	@IsTest
	private static void shouldFailWithInvalidAttributes()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();

				TST_Factory.insertScheduledJob(AttributeScheduler.class.getName(), new Map<String, String> {UTIL_Random.randomName() => UTIL_Random.randomName()});

				Test.stopTest();

				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
			}
		}
	}

	/**
	 * @description Tests that a scheduled job stops when Active is set to false.
	 */
	@IsTest
	private static void shouldStopJobOnDeactivate()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			ScheduledJob__c scheduler = TST_Factory.insertScheduledJob(PlainSchedulable.class.getName());
			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			Assert.isNotNull(scheduler.ScheduledJobId__c, 'Scheduled Job was not started');

			scheduler.IsActive__c = false;
			DML_Builder.newTransaction().doUpdate(scheduler).execute();

			Test.stopTest();

			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			Assert.isNull(scheduler.ScheduledJobId__c, 'Scheduled Job was not aborted');
		}
	}

	/**
	 * @description Tests that stopping an already-aborted job does not throw an error.
	 */
	@IsTest
	private static void shouldHandleAlreadyAbortedJob()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			ScheduledJob__c scheduler = TST_Factory.insertScheduledJob(PlainSchedulable.class.getName());
			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);

			System.abortJob(scheduler.ScheduledJobId__c);

			scheduler.IsActive__c = false;
			try
			{
				DML_Builder.newTransaction().doUpdate(scheduler).execute();
			}
			catch(Exception caughtException)
			{
				Assert.fail('Error was thrown and should have been squashed: ' + caughtException.getMessage());
			}

			Test.stopTest();
		}
	}

	/**
	 * @description Tests that deleting a ScheduledJob__c record aborts the scheduled job.
	 */
	@IsTest
	private static void shouldAbortJobOnDelete()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			ScheduledJob__c scheduler = TST_Factory.insertScheduledJob(PlainSchedulable.class.getName());
			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);

			DML_Builder.newTransaction().doDelete(scheduler).execute();

			CronTrigger job = (CronTrigger)QRY_Builder.selectFrom(CronTrigger.SObjectType)
					.condition('Id').equals(scheduler.ScheduledJobId__c)
					.getFirst();

			Test.stopTest();

			Assert.isNull(job, 'Scheduled Job was not aborted');
		}
	}

	/**
	 * @description Tests that insertion fails with an invalid class name.
	 */
	@IsTest
	private static void shouldFailWithInvalidClassName()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();

				TST_Factory.insertScheduledJob(UTIL_Random.randomName());

				Test.stopTest();

				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
			}
		}
	}

	/**
	 * @description Tests that insertion fails with a class that is not Schedulable.
	 */
	@IsTest
	private static void shouldFailWithNonSchedulableClass()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();

				TST_Factory.insertScheduledJob(TRG_ScheduleJob.class.getName());

				Test.stopTest();

				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
			}
		}
	}

	/**
	 * @description Tests that insertion fails with an invalid cron expression.
	 */
	@IsTest
	private static void shouldFailWithInvalidCronExpression()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();

				TST_Builder.of(ScheduledJob__c.SObjectType)
						.withOverride(ScheduledJob__c.ClassName__c, PlainSchedulable.class.getName())
						.withOverride(ScheduledJob__c.CronExpression__c, UTIL_Random.randomName())
						.build();

				Test.stopTest();

				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
			}
		}
	}

	/**
	 * @description Tests that insertion fails when a required parameter is missing from attributes.
	 */
	@IsTest
	private static void shouldFailWhenRequiredParameterMissing()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();

				TST_Factory.insertScheduledJob(AttributeScheduler.class.getName(), new Map<String, String> {'otherParam' => 'value1'});

				Test.stopTest();

				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
			}
		}
	}

	/**
	 * @description Tests that an inactive job can be activated by setting IsActive__c to true.
	 */
	@IsTest
	private static void shouldStartJobWhenActivatingInactiveRecord()
	{
		System.runAs(getTestAdmin())
		{
			ScheduledJob__c scheduler = TST_Factory.insertInactiveScheduledJob(PlainSchedulable.class.getName());
			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			Assert.isNull(scheduler.ScheduledJobId__c, 'Inactive job should not have a ScheduledJobId');

			Test.startTest();

			scheduler.IsActive__c = true;
			DML_Builder.newTransaction().doUpdate(scheduler).execute();

			Test.stopTest();

			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			Assert.isTrue(scheduler.IsActive__c, 'Job should be active');
			Assert.isNotNull(scheduler.ScheduledJobId__c, 'Activated job should have a ScheduledJobId');
		}
	}

	/**
	 * @description Tests the full activate, deactivate, reactivate lifecycle.
	 */
	@IsTest
	private static void shouldHandleActivateDeactivateReactivateCycle()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			ScheduledJob__c scheduler = TST_Factory.insertScheduledJob(PlainSchedulable.class.getName());
			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			String firstJobId = scheduler.ScheduledJobId__c;
			Assert.isNotNull(firstJobId, 'First activation should create a ScheduledJobId');

			scheduler.IsActive__c = false;
			DML_Builder.newTransaction().doUpdate(scheduler).execute();
			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			Assert.isNull(scheduler.ScheduledJobId__c, 'Deactivation should clear ScheduledJobId');

			scheduler.IsActive__c = true;
			DML_Builder.newTransaction().doUpdate(scheduler).execute();
			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			Assert.isNotNull(scheduler.ScheduledJobId__c, 'Reactivation should create a new ScheduledJobId');
			Assert.areNotEqual(firstJobId, scheduler.ScheduledJobId__c, 'Reactivation should produce a different ScheduledJobId');

			Test.stopTest();
		}
	}

	/**
	 * @description Tests that activating an inactive job with empty parameters succeeds.
	 */
	@IsTest
	private static void shouldActivateJobWithEmptyParameters()
	{
		System.runAs(getTestAdmin())
		{
			ScheduledJob__c scheduler = TST_Factory.insertInactiveScheduledJob(PlainSchedulable.class.getName());
			scheduler.Parameters__c = UTIL_String.EMPTY_JSON_RESPONSE;
			DML_Builder.newTransaction().doUpdate(scheduler).execute();

			Test.startTest();

			scheduler.IsActive__c = true;
			DML_Builder.newTransaction().doUpdate(scheduler).execute();

			Test.stopTest();

			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			Assert.isNotNull(scheduler.ScheduledJobId__c, 'Job with empty parameters should activate');
		}
	}

	/**
	 * @description Tests that activating an inactive job with null parameters succeeds.
	 */
	@IsTest
	private static void shouldActivateJobWithNullParameters()
	{
		System.runAs(getTestAdmin())
		{
			ScheduledJob__c scheduler = TST_Factory.insertInactiveScheduledJob(PlainSchedulable.class.getName());

			Test.startTest();

			scheduler.IsActive__c = true;
			DML_Builder.newTransaction().doUpdate(scheduler).execute();

			Test.stopTest();

			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			Assert.isNotNull(scheduler.ScheduledJobId__c, 'Job with null parameters should activate');
		}
	}

	/**
	 * @description Tests that scheduling an IF_Schedulable with empty parameter definitions succeeds.
	 */
	@IsTest
	private static void shouldStartJobForSchedulableWithEmptyDefinitions()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			ScheduledJob__c scheduler = TST_Factory.insertScheduledJob(EmptyDefinitionScheduler.class.getName());

			Test.stopTest();

			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			Assert.isNotNull(scheduler.ScheduledJobId__c, 'Job with empty definitions should be scheduled');
		}
	}

	/**
	 * @description Tests that a DmlException is thrown when setParameterValues throws.
	 */
	@IsTest
	private static void shouldFailWhenSetParameterValuesThrows()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();

				TST_Factory.insertScheduledJob(ThrowingScheduler.class.getName(), new Map<String, String> {'param1' => 'value1'});

				Test.stopTest();

				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
			}
		}
	}

	/**
	 * @description Adds, beside the existing test admin, an administrator who holds the Kern Job Runner Management
	 * permission set and no other Kern set: the set gives both the field-level access every save of a scheduled job
	 * needs and the permission the job-runner paths are gated on, so the set itself is what these tests prove.
	 */
	private static void setupManagingAdmin()
	{
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_SYSTEM_ADMIN, MANAGING_ADMIN_COMPANY, UTIL_ScheduledJobRunner.JOB_RUNNER_MANAGEMENT_PERMISSION_SET_NAME);
	}

	/**
	 * @description Adds the two Standard Users that every permission check in this class runs as. A package install writes
	 * the ManageJobRunner custom permission into profiles: the System Administrator profile on the default admins-only
	 * install, every profile on an all-users install. Both users therefore live on the Standard User profile, which
	 * the default install leaves without that permission. The user with the permission holds the Kern Job Runner
	 * Management set alone. The user without it keeps the Kern Administrator set, for field access to the scheduled job
	 * rows, so the permission check is what refuses it.
	 */
	private static void setupStandardUsersWithAndWithoutJobRunnerPermission()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_STANDARD_USER,
						STANDARD_USER_WITH_JOB_RUNNER_PERMISSION_COMPANY,
						UTIL_ScheduledJobRunner.JOB_RUNNER_MANAGEMENT_PERMISSION_SET_NAME
				);
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_STANDARD_USER,
						STANDARD_USER_WITHOUT_JOB_RUNNER_PERMISSION_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);
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
	 * @description Reads back the Standard User who may put a job on the job runner.
	 *
	 * @return The Standard User holding the Kern Job Runner Management permission set.
	 */
	private static User getStandardUserWithJobRunnerPermission()
	{
		return new SEL_User().findByCompanyName(STANDARD_USER_WITH_JOB_RUNNER_PERMISSION_COMPANY);
	}

	/**
	 * @description Reads back the Standard User who may not put a job on the job runner, and asserts that the user really lacks the permission. On an
	 * all-users package install the profile grant makes every user a permission holder, and a refusal test run there is not
	 * testing a non-holder. The assertion says so instead of editing the org's setup rows to create one.
	 *
	 * @return The Standard User, guaranteed to lack the Manage Job Runner permission.
	 */
	private static User getStandardUserWithoutJobRunnerPermission()
	{
		User standardUser = new SEL_User().findByCompanyName(STANDARD_USER_WITHOUT_JOB_RUNNER_PERMISSION_COMPANY);
		Assert.isFalse
				(
						SEL_CustomPermission.hasPackagePermission(standardUser.Id, UTIL_ScheduledJobRunner.MANAGE_JOB_RUNNER_CUSTOM_PERMISSION_NAME),
						'This org grants ' +
						UTIL_ScheduledJobRunner.MANAGE_JOB_RUNNER_CUSTOM_PERMISSION_NAME +
						' to the Standard User profile (an all-users package install), so no non-holder exists to prove the refusal against; ' +
						'run this suite in an org installed for admins only'
				);
		return standardUser;
	}

	/**
	 * @description Builds the parameter map a test job takes, holding the one parameter its definitions declare.
	 *
	 * @param value The value for that parameter.
	 *
	 * @return The parameter map.
	 */
	private static Map<String, String> buildRequiredParameterMap(String value)
	{
		return new Map<String, String> {REQUIRED_PARAMETER_NAME => value};
	}

	/**
	 * @description Builds the same parameter map in the JSON form the Parameters__c field holds.
	 *
	 * @param value The value for that parameter.
	 *
	 * @return The serialized parameters.
	 */
	private static String serializeRequiredParameter(String value)
	{
		return new DTO_NameValues(buildRequiredParameterMap(value)).serialize();
	}

	/**
	 * @description Builds an uncommitted active record in job-runner mode, on the given expression.
	 *
	 * @param cronExpression The expression the record carries.
	 *
	 * @return The uncommitted record.
	 */
	private static ScheduledJob__c newJobRunnerRecord(String cronExpression)
	{
		return (ScheduledJob__c)TST_Builder.of(ScheduledJob__c.SObjectType)
				.withOverride(ScheduledJob__c.SchedulerName__c, UTIL_Random.randomName())
				.withOverride(ScheduledJob__c.ClassName__c, PlainSchedulable.class.getName())
				.withOverride(ScheduledJob__c.CronExpression__c, cronExpression)
				.withOverride(ScheduledJob__c.IsActive__c, true)
				.withOverride(ScheduledJob__c.Timezone__c, TIMEZONE_UTC)
				.withOverride(ScheduledJob__c.ExecutionMode__c, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Builds an uncommitted record of the shape Health Check gives the job runner's own schedulable. It is
	 * inactive because the runner's schedulable itself arrives later in this plan: an inactive record exercises the
	 * Health Check guard on every path without needing that class to resolve.
	 *
	 * @return The uncommitted runner record.
	 */
	private static ScheduledJob__c newRunnerRecord()
	{
		return (ScheduledJob__c)TST_Builder.of(ScheduledJob__c.SObjectType)
				.withOverride(ScheduledJob__c.SchedulerName__c, RUNNER_RECORD_SCHEDULER_NAME)
				.withOverride(ScheduledJob__c.ClassName__c, UTIL_ScheduledJobRunner.RUNNER_CLASS_NAME)
				.withOverride(ScheduledJob__c.CronExpression__c, CRON_QUARTER_PAST_EVERY_HOUR)
				.withOverride(ScheduledJob__c.IsActive__c, false)
				.withOverride(ScheduledJob__c.Timezone__c, UserInfo.getTimeZone().getID())
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Tests that a record on the job runner is saved with a seeded next-run cursor in the next five minutes
	 * and no platform job of its own.
	 */
	@IsTest
	private static void jobRunnerRecordSeedsItsCursorAndNeverGetsAPlatformJob()
	{
		System.runAs(getManagingAdmin())
		{
			Test.startTest();

			ScheduledJob__c record = newJobRunnerRecord(CRON_EVERY_FIVE_MINUTES);
			DML_Builder.newTransaction().doInsert(record).execute();

			Test.stopTest();

			ScheduledJob__c saved = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
			Assert.isNull(saved.ScheduledJobId__c, 'a job-runner record owns no CronTrigger');
			Assert.isNotNull(saved.NextRunAt__c, 'the trigger seeds the cursor');
			Assert.isTrue(saved.NextRunAt__c > Datetime.now(), 'to the next future window');
			Assert.isTrue(saved.NextRunAt__c <= Datetime.now().addMinutes(5), 'within five minutes for a */5 expression');
		}
	}

	/**
	 * @description Tests that an expression naming several minutes of the hour, which System.schedule refuses, saves on
	 * the job runner because Kern evaluates the expression itself.
	 */
	@IsTest
	private static void jobRunnerRecordAcceptsTheWiderMinutesGrammarThePlatformRefuses()
	{
		System.runAs(getManagingAdmin())
		{
			ScheduledJob__c record = newJobRunnerRecord(CRON_MINUTES_AS_A_LIST);
			DML_Builder.newTransaction().doInsert(record).execute();

			ScheduledJob__c saved = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
			Assert.isNotNull(saved.NextRunAt__c, 'Kern evaluates the expression, so a list of minutes saves');
		}
	}

	/**
	 * @description Tests that an expression with no fire inside the evaluator's horizon is refused on the cron field.
	 */
	@IsTest
	private static void jobRunnerRecordRefusesAnExpressionThatNeverFires()
	{
		System.runAs(getManagingAdmin())
		{
			try
			{
				DML_Builder.newTransaction().doInsert(newJobRunnerRecord(CRON_THAT_NEVER_FIRES)).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				Assert.isTrue(error.getMessage().contains(System.Label.ScheduledJob_ExpressionCannotFireWithinHorizon), 'the error names the horizon: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Tests that an expression the evaluator cannot read is refused on the cron field, naming the token.
	 */
	@IsTest
	private static void jobRunnerRecordRefusesAMalformedExpressionOnTheCronField()
	{
		System.runAs(getManagingAdmin())
		{
			try
			{
				DML_Builder.newTransaction().doInsert(newJobRunnerRecord(CRON_WITH_AN_UNREADABLE_MINUTE)).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				String expectedMessage = String.format(System.Label.ScheduledJob_CronExpressionInvalid, new List<Object> {UNREADABLE_MINUTE_TOKEN});
				Assert.isTrue(error.getMessage().contains(expectedMessage), 'the evaluator message reaches the field error: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Tests that a record on the job runner is validated exactly as an own-mode record is: a class that does
	 * not resolve is refused, and no cursor is seeded.
	 */
	@IsTest
	private static void jobRunnerRecordRefusesAClassThatDoesNotResolve()
	{
		System.runAs(getManagingAdmin())
		{
			String unknownClassName = UTIL_Random.randomName();
			ScheduledJob__c record = newJobRunnerRecord(CRON_EVERY_FIVE_MINUTES);
			record.ClassName__c = unknownClassName;

			try
			{
				DML_Builder.newTransaction().doInsert(record).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				Assert.isTrue(error.getMessage().contains(unknownClassName), 'the error names the class that could not be resolved: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Tests that a user without the Manage Job Runner permission cannot put a new job on the runner.
	 */
	@IsTest
	private static void enteringJobRunnerModeWithoutThePermissionIsRefused()
	{
		System.runAs(getStandardUserWithoutJobRunnerPermission())
		{
			try
			{
				DML_Builder.newTransaction().doInsert(newJobRunnerRecord(CRON_EVERY_FIVE_MINUTES)).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				Assert.isTrue(error.getMessage().contains(System.Label.ScheduledJob_ManageJobRunnerPermissionRequired), 'the error names the permission: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Tests that a user without the permission cannot move an existing job onto the runner either: the gate
	 * is on entering the mode, whichever save enters it.
	 */
	@IsTest
	private static void enteringJobRunnerModeOnAnExistingRecordWithoutThePermissionIsRefused()
	{
		System.runAs(getStandardUserWithoutJobRunnerPermission())
		{
			ScheduledJob__c record = TST_Factory.insertInactiveScheduledJob(PlainSchedulable.class.getName());
			record = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
			record.ExecutionMode__c = UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER;

			try
			{
				DML_Builder.newTransaction().doUpdate(record).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				Assert.isTrue(error.getMessage().contains(System.Label.ScheduledJob_ManageJobRunnerPermissionRequired), 'the move is gated: ' + error.getMessage());
			}

			ScheduledJob__c unchanged = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
			Assert.areNotEqual(UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER, unchanged.ExecutionMode__c, 'the record stayed in own mode');
		}
	}

	/**
	 * @description Inserts a job on the job runner as the Standard User who holds the Manage Job Runner permission, so a
	 * test can then try to change it as a user who does not. Its expression is one the platform scheduler also accepts,
	 * so taking the job off the runner can only be refused for want of the permission, never for its expression.
	 *
	 * @return The saved job, read back from the database.
	 */
	private static ScheduledJob__c insertJobRunnerRecordAsPermissionHolder()
	{
		ScheduledJob__c record = newJobRunnerRecord(CRON_QUARTER_PAST_EVERY_HOUR);

		System.runAs(getStandardUserWithJobRunnerPermission())
		{
			DML_Builder.newTransaction().doInsert(record).execute();
		}

		return (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
	}

	/**
	 * @description Gives the overlap policy a job does not have, so a test can change it whatever its stored value is.
	 *
	 * @param currentPolicy The job's overlap policy now.
	 *
	 * @return Allow when the job has Skip, and Skip otherwise.
	 */
	private static String findOtherOverlapPolicy(String currentPolicy)
	{
		return UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP.equals(currentPolicy) ? UTIL_ScheduledJobRunner.OVERLAP_POLICY_ALLOW : UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP;
	}

	/**
	 * @description Saves a change to a job as the Standard User who does not hold the Manage Job Runner permission, and
	 * asserts that the save is refused with the permission message and that the stored job keeps its old value.
	 *
	 * @param change The job's id and only the fields being changed.
	 * @param changedField The field the test checks afterwards.
	 * @param reason What the change is, for the failure message.
	 */
	private static void assertChangeRefusedWithoutThePermission(ScheduledJob__c change, SObjectField changedField, String reason)
	{
		Object storedValue = new SEL_ScheduledJob().findById(change.Id).get(changedField);

		System.runAs(getStandardUserWithoutJobRunnerPermission())
		{
			try
			{
				DML_Builder.newTransaction().doUpdate(change).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				String message = error.getMessage();
				Assert.isTrue(message.contains(System.Label.ScheduledJob_ManageJobRunnerPermissionRequired), 'Expected ' + reason + ' to be refused: ' + message);
			}
		}

		Assert.areEqual(storedValue, new SEL_ScheduledJob().findById(change.Id).get(changedField), 'Expected the stored job to keep its old value after ' + reason);
	}

	/**
	 * @description Tests that a user without the Manage Job Runner permission cannot change the run priority of a job
	 * that is on the job runner.
	 */
	@IsTest
	private static void changingThePriorityOfAJobRunnerRecordWithoutThePermissionIsRefused()
	{
		ScheduledJob__c record = insertJobRunnerRecordAsPermissionHolder();

		assertChangeRefusedWithoutThePermission
				(
						new ScheduledJob__c(Id = record.Id, RunPriority__c = EDITED_RUN_PRIORITY),
						ScheduledJob__c.RunPriority__c,
						'a priority change'
				);
	}

	/**
	 * @description Tests that a user without the Manage Job Runner permission cannot take a job off the job runner by
	 * moving it back to a scheduled job of its own.
	 */
	@IsTest
	private static void takingAJobOffTheRunnerWithoutThePermissionIsRefused()
	{
		ScheduledJob__c record = insertJobRunnerRecordAsPermissionHolder();

		assertChangeRefusedWithoutThePermission
				(
						new ScheduledJob__c(Id = record.Id, ExecutionMode__c = UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB),
						ScheduledJob__c.ExecutionMode__c,
						'taking the job off the runner'
				);
	}

	/**
	 * @description Tests that a user without the Manage Job Runner permission cannot change what a job on the job runner
	 * does when its previous run is still running.
	 */
	@IsTest
	private static void changingTheOverlapPolicyOfAJobRunnerRecordWithoutThePermissionIsRefused()
	{
		ScheduledJob__c record = insertJobRunnerRecordAsPermissionHolder();

		assertChangeRefusedWithoutThePermission
				(
						new ScheduledJob__c(Id = record.Id, OverlapPolicy__c = findOtherOverlapPolicy(record.OverlapPolicy__c)),
						ScheduledJob__c.OverlapPolicy__c,
						'an overlap policy change'
				);
	}

	/**
	 * @description Tests that a user without the Manage Job Runner permission cannot change when a job on the job runner
	 * runs, by changing either its cron expression or its time zone.
	 */
	@IsTest
	private static void changingTheScheduleOfAJobRunnerRecordWithoutThePermissionIsRefused()
	{
		ScheduledJob__c record = insertJobRunnerRecordAsPermissionHolder();

		assertChangeRefusedWithoutThePermission
				(
						new ScheduledJob__c(Id = record.Id, CronExpression__c = CRON_HALF_PAST_THREE),
						ScheduledJob__c.CronExpression__c,
						'a cron expression change'
				);
		assertChangeRefusedWithoutThePermission
				(
						new ScheduledJob__c(Id = record.Id, Timezone__c = TIMEZONE_NEW_YORK),
						ScheduledJob__c.Timezone__c,
						'a time zone change'
				);
	}

	/**
	 * @description Tests that a user without the Manage Job Runner permission cannot switch off a job on the job runner.
	 */
	@IsTest
	private static void deactivatingAJobRunnerRecordWithoutThePermissionIsRefused()
	{
		ScheduledJob__c record = insertJobRunnerRecordAsPermissionHolder();

		assertChangeRefusedWithoutThePermission(new ScheduledJob__c(Id = record.Id, IsActive__c = false), ScheduledJob__c.IsActive__c, 'switching the job off');
	}

	/**
	 * @description Tests that a user without the Manage Job Runner permission cannot change the class of a job on the job
	 * runner, because that changes which code it runs.
	 */
	@IsTest
	private static void changingTheClassOfAJobRunnerRecordWithoutThePermissionIsRefused()
	{
		ScheduledJob__c record = insertJobRunnerRecordAsPermissionHolder();
		ScheduledJob__c change = new ScheduledJob__c(Id = record.Id, ClassName__c = AttributeScheduler.class.getName());
		change.Parameters__c = serializeRequiredParameter(REQUIRED_PARAMETER_VALUE);

		assertChangeRefusedWithoutThePermission(change, ScheduledJob__c.ClassName__c, 'a class change');
	}

	/**
	 * @description Tests that changing only the parameters of a job on the runner is gated too: the values a job runs
	 * with are as much a part of what it does as the class name.
	 */
	@IsTest
	private static void changingOnlyTheParametersOfAJobRunnerRecordNeedsThePermission()
	{
		ScheduledJob__c record = insertJobRunnerRecordAsPermissionHolder();

		assertChangeRefusedWithoutThePermission
				(
						new ScheduledJob__c(Id = record.Id, Parameters__c = serializeRequiredParameter(REQUIRED_PARAMETER_VALUE)),
						ScheduledJob__c.Parameters__c,
						'a parameters-only change'
				);
	}

	/**
	 * @description Tests that a user without the Manage Job Runner permission cannot delete a job that is on the job
	 * runner, because deleting it takes it off the runner.
	 */
	@IsTest
	private static void deletingAJobOnTheJobRunnerWithoutThePermissionIsRefused()
	{
		ScheduledJob__c record = insertJobRunnerRecordAsPermissionHolder();

		System.runAs(getStandardUserWithoutJobRunnerPermission())
		{
			try
			{
				DML_Builder.newTransaction().doDelete(record).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				Assert.isTrue(error.getMessage().contains(System.Label.ScheduledJob_ManageJobRunnerPermissionRequired), 'Expected the delete to be refused: ' + error.getMessage());
			}
		}

		Assert.isNotNull(new SEL_ScheduledJob().findById(record.Id), 'Expected the job to stay on the runner');
	}

	/**
	 * @description Tests that a user who holds the Manage Job Runner permission can delete a job that is on the job runner.
	 * The test runs as the managing administrator, because the Kern Job Runner Management set alone does not grant delete
	 * on scheduled jobs.
	 */
	@IsTest
	private static void aUserWithThePermissionCanDeleteAJobOnTheJobRunner()
	{
		ScheduledJob__c record = insertJobRunnerRecordAsPermissionHolder();

		System.runAs(getManagingAdmin())
		{
			DML_Builder.newTransaction().doDelete(record).execute();
		}

		Assert.isNull(new SEL_ScheduledJob().findById(record.Id), 'Expected the job to be deleted');
	}

	/**
	 * @description Tests that a user without the Manage Job Runner permission can still delete a job that has a scheduled
	 * job of its own.
	 */
	@IsTest
	private static void aUserWithoutThePermissionCanDeleteAJobNeverOnTheRunner()
	{
		System.runAs(getStandardUserWithoutJobRunnerPermission())
		{
			ScheduledJob__c record = TST_Factory.insertInactiveScheduledJob(PlainSchedulable.class.getName());

			DML_Builder.newTransaction().doDelete(record).execute();

			Assert.isNull(new SEL_ScheduledJob().findById(record.Id), 'Expected the job to be deleted');
		}
	}

	/**
	 * @description Tests that a user who holds the Manage Job Runner permission can change the priority, the overlap
	 * policy, the cron expression, the time zone and the active flag of a job on the job runner, and can take it off the
	 * runner.
	 */
	@IsTest
	private static void aUserWithThePermissionCanMakeEachChangeToAJobRunnerRecord()
	{
		ScheduledJob__c record = insertJobRunnerRecordAsPermissionHolder();
		String otherOverlapPolicy = findOtherOverlapPolicy(record.OverlapPolicy__c);

		System.runAs(getStandardUserWithJobRunnerPermission())
		{
			Test.startTest();

			DML_Builder.newTransaction().doUpdate(new ScheduledJob__c(Id = record.Id, RunPriority__c = EDITED_RUN_PRIORITY)).execute();
			DML_Builder.newTransaction().doUpdate(new ScheduledJob__c(Id = record.Id, OverlapPolicy__c = otherOverlapPolicy)).execute();
			DML_Builder.newTransaction().doUpdate(new ScheduledJob__c(Id = record.Id, CronExpression__c = CRON_HALF_PAST_THREE, Timezone__c = TIMEZONE_NEW_YORK)).execute();
			DML_Builder.newTransaction().doUpdate(new ScheduledJob__c(Id = record.Id, IsActive__c = false)).execute();

			ScheduledJob__c saved = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
			Assert.areEqual(EDITED_RUN_PRIORITY, saved.RunPriority__c, 'Expected the new priority to be saved');
			Assert.areEqual(otherOverlapPolicy, saved.OverlapPolicy__c, 'Expected the new overlap policy to be saved');
			Assert.areEqual(CRON_HALF_PAST_THREE, saved.CronExpression__c, 'Expected the new cron expression to be saved');
			Assert.areEqual(TIMEZONE_NEW_YORK, saved.Timezone__c, 'Expected the new time zone to be saved');
			Assert.isFalse(saved.IsActive__c, 'Expected the job to be switched off');

			ScheduledJob__c offTheRunner = new ScheduledJob__c(Id = record.Id, ExecutionMode__c = UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB);
			DML_Builder.newTransaction().doUpdate(offTheRunner).execute();

			Test.stopTest();

			saved = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
			Assert.areEqual(UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB, saved.ExecutionMode__c, 'Expected the job to be taken off the runner');
		}
	}

	/**
	 * @description Tests that the permission check leaves alone a job that is not and never was on the job runner: a user
	 * without the Manage Job Runner permission can change its priority, overlap policy, cron expression, time zone and
	 * active flag.
	 */
	@IsTest
	private static void aUserWithoutThePermissionCanChangeEachSettingOfAJobNeverOnTheRunner()
	{
		System.runAs(getStandardUserWithoutJobRunnerPermission())
		{
			Test.startTest();

			ScheduledJob__c record = TST_Factory.insertInactiveScheduledJob(PlainSchedulable.class.getName());
			record = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
			String otherOverlapPolicy = findOtherOverlapPolicy(record.OverlapPolicy__c);

			record.RunPriority__c = EDITED_RUN_PRIORITY;
			DML_Builder.newTransaction().doUpdate(record).execute();

			record.OverlapPolicy__c = otherOverlapPolicy;
			DML_Builder.newTransaction().doUpdate(record).execute();

			record.CronExpression__c = CRON_HALF_PAST_THREE;
			record.Timezone__c = TIMEZONE_NEW_YORK;
			DML_Builder.newTransaction().doUpdate(record).execute();

			record.IsActive__c = true;
			DML_Builder.newTransaction().doUpdate(record).execute();

			Test.stopTest();

			ScheduledJob__c saved = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
			Assert.areEqual(EDITED_RUN_PRIORITY, saved.RunPriority__c, 'Expected the new priority to be saved');
			Assert.areEqual(otherOverlapPolicy, saved.OverlapPolicy__c, 'Expected the new overlap policy to be saved');
			Assert.areEqual(CRON_HALF_PAST_THREE, saved.CronExpression__c, 'Expected the new cron expression to be saved');
			Assert.areEqual(TIMEZONE_NEW_YORK, saved.Timezone__c, 'Expected the new time zone to be saved');
			Assert.isTrue(saved.IsActive__c, 'Expected the job to be switched on');
			Assert.isNotNull(saved.ScheduledJobId__c, 'Expected the job to get a platform job of its own once switched on');
		}
	}

	/**
	 * @description Tests that the job runner's own writes of a job's run fields (the next run time, the last run time,
	 * the last outcome and its reason, and the last run's job id) still save on a job that is on the job runner when the
	 * running user does not hold the Manage Job Runner permission.
	 */
	@IsTest
	private static void jobRunnerRunFieldWritesOnAJobRunnerRecordSucceedWithoutThePermission()
	{
		ScheduledJob__c record = insertJobRunnerRecordAsPermissionHolder();
		Datetime nextRunAt = record.NextRunAt__c.addHours(1);

		System.runAs(getStandardUserWithoutJobRunnerPermission())
		{
			ScheduledJob__c runFields = new ScheduledJob__c(Id = record.Id, NextRunAt__c = nextRunAt, LastRunAt__c = Datetime.now(), LastRunJobId__c = null);
			runFields.LastRunOutcome__c = UTIL_ScheduledJobRunner.OUTCOME_SKIPPED;
			runFields.LastRunReason__c = UTIL_ScheduledJobRunner.REASON_PREVIOUS_RUN_STILL_RUNNING;
			new UTIL_ScheduledJobRunner.FrameworkWriter().updateRecord(runFields);
		}

		ScheduledJob__c saved = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
		Assert.areEqual(nextRunAt, saved.NextRunAt__c, 'Expected the job runner to move the next run time');
		Assert.areEqual(UTIL_ScheduledJobRunner.OUTCOME_SKIPPED, saved.LastRunOutcome__c, 'Expected the job runner to record the last outcome');
		Assert.areEqual(UTIL_ScheduledJobRunner.REASON_PREVIOUS_RUN_STILL_RUNNING, saved.LastRunReason__c, 'Expected the job runner to record the reason');
		Assert.isNotNull(saved.LastRunAt__c, 'Expected the job runner to record the last run time');
	}

	/**
	 * @description Tests that Health Check's allowance for leaving the job runner lets a user without the Manage Job
	 * Runner permission move a job from the job runner to a scheduled job of its own, and that nothing else gets past
	 * under it: a priority change on a job on the job runner is still refused, and so is a priority change made in the
	 * same save that takes the job off the job runner.
	 */
	@IsTest
	private static void theAllowanceForLeavingTheJobRunnerLetsOnlyThatChangeThroughWithoutThePermission()
	{
		ScheduledJob__c leaving = insertJobRunnerRecordAsPermissionHolder();
		ScheduledJob__c staying = insertJobRunnerRecordAsPermissionHolder();
		TRG_ScheduleJob.allowLeavingTheJobRunner = true;

		try
		{
			assertChangeRefusedWithoutThePermission
					(
							new ScheduledJob__c(Id = staying.Id, RunPriority__c = EDITED_RUN_PRIORITY),
							ScheduledJob__c.RunPriority__c,
							'a priority change under the allowance'
					);

			ScheduledJob__c leavingWithPriority = new ScheduledJob__c(Id = staying.Id, RunPriority__c = EDITED_RUN_PRIORITY);
			leavingWithPriority.ExecutionMode__c = UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB;
			assertChangeRefusedWithoutThePermission(leavingWithPriority, ScheduledJob__c.ExecutionMode__c, 'leaving the runner with a priority change');

			System.runAs(getStandardUserWithoutJobRunnerPermission())
			{
				Test.startTest();
				DML_Builder.newTransaction()
						.doUpdate(new ScheduledJob__c(Id = leaving.Id, ExecutionMode__c = UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB))
						.execute();
				Test.stopTest();
			}
		}
		finally
		{
			TRG_ScheduleJob.allowLeavingTheJobRunner = false;
		}

		ScheduledJob__c saved = (ScheduledJob__c)new SEL_ScheduledJob().findById(leaving.Id);
		Assert.areEqual(UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB, saved.ExecutionMode__c, 'Expected the allowance to let the job leave the runner');
		Assert.areEqual(leaving.RunPriority__c, saved.RunPriority__c, 'Expected the job that left the runner to keep its priority');
	}

	/**
	 * @description Tests that a change of letter case alone is a change: a user without the permission cannot re-case a
	 * job-runner record's parameters past the gate, which Apex's own string equality would have let through.
	 */
	@IsTest
	private static void aCaseOnlyParametersChangeOnAJobRunnerRecordNeedsThePermission()
	{
		ScheduledJob__c record = newJobRunnerRecord(CRON_EVERY_FIVE_MINUTES);
		record.Parameters__c = serializeRequiredParameter(REQUIRED_PARAMETER_VALUE);

		System.runAs(getStandardUserWithJobRunnerPermission())
		{
			DML_Builder.newTransaction().doInsert(record).execute();
		}

		System.runAs(getStandardUserWithoutJobRunnerPermission())
		{
			record.Parameters__c = serializeRequiredParameter(REQUIRED_PARAMETER_VALUE_IN_OTHER_CASE);

			try
			{
				DML_Builder.newTransaction().doUpdate(record).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				Assert.isTrue(error.getMessage().contains(System.Label.ScheduledJob_ManageJobRunnerPermissionRequired), 'a case-only change is a change: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Tests that a case-only edit of an own-mode record re-schedules it: the administrator asked for a
	 * different parameter value, so the platform job must be rebuilt with it.
	 */
	@IsTest
	private static void aCaseOnlyParametersEditOfAnOwnModeRecordStillReschedules()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			ScheduledJob__c ownMode = TST_Factory.insertScheduledJob(PlainSchedulable.class.getName(), buildRequiredParameterMap(REQUIRED_PARAMETER_VALUE));
			ownMode = (ScheduledJob__c)new SEL_ScheduledJob().findById(ownMode.Id);
			String cronTriggerBefore = ownMode.ScheduledJobId__c;

			ownMode.Parameters__c = serializeRequiredParameter(REQUIRED_PARAMETER_VALUE_IN_OTHER_CASE);
			DML_Builder.newTransaction().doUpdate(ownMode).execute();

			Test.stopTest();

			ScheduledJob__c after = (ScheduledJob__c)new SEL_ScheduledJob().findById(ownMode.Id);
			Assert.isNotNull(after.ScheduledJobId__c, 'still scheduled');
			Assert.areNotEqual(cronTriggerBefore, after.ScheduledJobId__c, 'a case-only parameter edit re-schedules, as every own-mode edit did before this plan');
		}
	}

	/**
	 * @description Tests that a write of only the framework-owned run fields lands without re-entering validation or
	 * scheduling: the record keeps the CronTrigger it already owns.
	 */
	@IsTest
	private static void frameworkOwnedWritesReenterNeitherValidationNorScheduling()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			ScheduledJob__c ownMode = TST_Factory.insertScheduledJob(PlainSchedulable.class.getName());
			ownMode = (ScheduledJob__c)new SEL_ScheduledJob().findById(ownMode.Id);
			String cronTriggerBefore = ownMode.ScheduledJobId__c;

			ownMode.LastRunOutcome__c = UTIL_ScheduledJobRunner.OUTCOME_SKIPPED;
			ownMode.LastRunAt__c = Datetime.now();
			ownMode.NextRunAt__c = Datetime.now();
			ownMode.LastRunJobId__c = null;
			ownMode.LastRunReason__c = UTIL_ScheduledJobRunner.REASON_PREVIOUS_RUN_STILL_RUNNING;
			DML_Builder.newTransaction().doUpdate(ownMode).execute();

			Test.stopTest();

			ScheduledJob__c after = (ScheduledJob__c)new SEL_ScheduledJob().findById(ownMode.Id);
			Assert.areEqual(cronTriggerBefore, after.ScheduledJobId__c, 'an own-mode record keeps the same CronTrigger: the framework write did not re-schedule');
			Assert.areEqual(UTIL_ScheduledJobRunner.OUTCOME_SKIPPED, after.LastRunOutcome__c, 'the write landed');
		}
	}

	/**
	 * @description Tests that an administrator's cron edit of an own-mode record re-schedules it exactly as before.
	 */
	@IsTest
	private static void anAdminEditOfAnOwnModeRecordStillReschedules()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			ScheduledJob__c ownMode = TST_Factory.insertScheduledJob(PlainSchedulable.class.getName());
			ownMode = (ScheduledJob__c)new SEL_ScheduledJob().findById(ownMode.Id);
			String cronTriggerBefore = ownMode.ScheduledJobId__c;

			ownMode.CronExpression__c = CRON_HALF_PAST_THREE;
			DML_Builder.newTransaction().doUpdate(ownMode).execute();

			Test.stopTest();

			ScheduledJob__c after = (ScheduledJob__c)new SEL_ScheduledJob().findById(ownMode.Id);
			Assert.isNotNull(after.ScheduledJobId__c, 'still scheduled');
			Assert.areNotEqual(cronTriggerBefore, after.ScheduledJobId__c, 'a cron edit re-schedules exactly as before this plan');
		}
	}

	/**
	 * @description Tests that editing only the description of an active own-mode record leaves its platform job alone.
	 * A second administrator makes the edit, so the test can prove the job still belongs to the user who scheduled it
	 * and was not aborted and scheduled again as the editor.
	 */
	@IsTest
	private static void aDescriptionOnlyEditOfAnOwnModeRecordKeepsItsPlatformJob()
	{
		User schedulingUser = getTestAdmin();
		ScheduledJob__c ownMode;

		System.runAs(schedulingUser)
		{
			ownMode = TST_Factory.insertScheduledJob(PlainSchedulable.class.getName());
		}

		System.runAs(getManagingAdmin())
		{
			Test.startTest();

			ownMode = (ScheduledJob__c)new SEL_ScheduledJob().findById(ownMode.Id);
			String cronTriggerBefore = ownMode.ScheduledJobId__c;
			Assert.isNotNull(cronTriggerBefore, 'Expected the active own-mode record to own a platform job before the edit');

			ownMode.Description__c = UTIL_Random.randomName();
			DML_Builder.newTransaction().doUpdate(ownMode).execute();

			Test.stopTest();

			ScheduledJob__c after = (ScheduledJob__c)new SEL_ScheduledJob().findById(ownMode.Id);
			Assert.areEqual(ownMode.Description__c, after.Description__c, 'Expected the new description to be saved');
			Assert.areEqual(cronTriggerBefore, after.ScheduledJobId__c, 'Expected a description-only edit to keep the same platform job id');

			CronTrigger platformJob = (CronTrigger)QRY_Builder.selectFrom(CronTrigger.SObjectType)
					.fields(new List<SObjectField> {CronTrigger.OwnerId})
					.condition('Id').equals(cronTriggerBefore)
					.getFirst();
			Assert.isNotNull(platformJob, 'Expected the platform job to still exist, not aborted by a description-only edit');
			Assert.areEqual(schedulingUser.Id, platformJob.OwnerId, 'Expected the platform job to still belong to the user who scheduled it, not to the editor');
		}
	}

	/**
	 * @description Tests that moving a record onto the job runner aborts the platform job it owned and seeds its cursor,
	 * and that moving it back gives it a platform job again.
	 */
	@IsTest
	private static void switchingAnOwnModeRecordToTheRunnerAbortsItsPlatformJobAndSwitchingBackSchedulesOne()
	{
		System.runAs(getManagingAdmin())
		{
			Test.startTest();

			ScheduledJob__c record = TST_Factory.insertScheduledJob(PlainSchedulable.class.getName());
			record = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
			Assert.isNotNull(record.ScheduledJobId__c, 'own mode owns a CronTrigger');
			String cronTriggerBefore = record.ScheduledJobId__c;

			record.ExecutionMode__c = UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER;
			DML_Builder.newTransaction().doUpdate(record).execute();

			record = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
			Assert.isNull(record.ScheduledJobId__c, 'the switch clears the id');
			CronTrigger abortedJob = (CronTrigger)QRY_Builder.selectFrom(CronTrigger.SObjectType)
					.condition('Id').equals(cronTriggerBefore)
					.getFirst();
			Assert.isNull(abortedJob, 'and the platform job it owned is really gone, not merely unlinked from the record');
			Assert.isNotNull(record.NextRunAt__c, 'and seeds the cursor');

			record.ExecutionMode__c = UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB;
			DML_Builder.newTransaction().doUpdate(record).execute();

			Test.stopTest();

			record = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
			Assert.isNotNull(record.ScheduledJobId__c, 'switching back schedules a CronTrigger again');
		}
	}

	/**
	 * @description Tests the guard on the job runner's own records and the flag that opens it: a direct insert is
	 * refused, the same insert succeeds with the flag Health Check sets, a later direct update and a direct delete are
	 * refused, and the delete succeeds with the flag. What the record's own scheduling looks like is not in scope here;
	 * that belongs to Health Check's own tests, once the runner's schedulable exists.
	 */
	@IsTest
	private static void aRunnerRecordCanOnlyBeWrittenByHealthCheck()
	{
		System.runAs(getManagingAdmin())
		{
			ScheduledJob__c runner = newRunnerRecord();

			try
			{
				DML_Builder.newTransaction().doInsert(runner).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				Assert.isTrue(error.getMessage().contains(System.Label.ScheduledJob_RunnerRecordManagedByHealthCheck), 'a direct insert is refused: ' + error.getMessage());
			}

			Test.startTest();

			TRG_ScheduleJob.allowRunnerRecordManagement = true;
			DML_Builder.newTransaction().doInsert(runner).execute();
			TRG_ScheduleJob.allowRunnerRecordManagement = false;

			Test.stopTest();

			List<ScheduledJob__c> savedRunnerRecords = new SEL_ScheduledJob().findRunnerRecords();
			Assert.areEqual(1, savedRunnerRecords.size(), 'Health Check\'s path saved exactly one runner record');
			Assert.isFalse(savedRunnerRecords[0].IsActive__c, 'saved as the fixture built it, inactive');
			Assert.isNull(savedRunnerRecords[0].ScheduledJobId__c, 'and owning no platform job yet');

			runner = savedRunnerRecords[0];
			runner.Description__c = 'an edit outside Health Check';

			try
			{
				DML_Builder.newTransaction().doUpdate(runner).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				Assert.isTrue(error.getMessage().contains(System.Label.ScheduledJob_RunnerRecordManagedByHealthCheck), 'a direct update is refused: ' + error.getMessage());
			}

			try
			{
				DML_Builder.newTransaction().doDelete(runner).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				String message = error.getMessage();
				Assert.isTrue(message.contains(System.Label.ScheduledJob_RunnerRecordManagedByHealthCheck), 'Expected a direct delete to be refused: ' + message);
			}

			Assert.areEqual(1, new SEL_ScheduledJob().findRunnerRecords().size(), 'Expected the runner record to survive the refused delete');

			TRG_ScheduleJob.allowRunnerRecordManagement = true;
			DML_Builder.newTransaction().doDelete(runner).execute();
			TRG_ScheduleJob.allowRunnerRecordManagement = false;

			Assert.isTrue(new SEL_ScheduledJob().findRunnerRecords().isEmpty(), 'Expected Health Check\'s path to delete the runner record');
		}
	}

	/**
	 * @description Tests the two ways a save could otherwise take a runner record out of Health Check's hands: renaming
	 * its class away from the runner's schedulable, and blanking the platform job id Health Check reads to know the
	 * runner is alive. Both are refused outside Health Check, and both are allowed on Health Check's own path.
	 */
	@IsTest
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static void aRunnerRecordCannotBeRenamedOrDetachedOutsideHealthCheck()
	{
		System.runAs(getManagingAdmin())
		{
			ScheduledJob__c runner = newRunnerRecord();

			TRG_ScheduleJob.allowRunnerRecordManagement = true;
			DML_Builder.newTransaction().doInsert(runner).execute();
			runner.ScheduledJobId__c = String.valueOf(UTIL_Random.randomId(CronTrigger.SObjectType));
			// Arranges the platform job id Health Check recorded; the id is the framework's to write, never the manager's.
			DML_Builder.newTransaction().withSystemMode().doUpdate(runner).execute();
			TRG_ScheduleJob.allowRunnerRecordManagement = false;

			Assert.isNotNull(((ScheduledJob__c)new SEL_ScheduledJob().findById(runner.Id)).ScheduledJobId__c, 'Health Check records the platform job it created');

			ScheduledJob__c renamed = (ScheduledJob__c)new SEL_ScheduledJob().findById(runner.Id);
			renamed.ClassName__c = PlainSchedulable.class.getName();

			try
			{
				DML_Builder.newTransaction().doUpdate(renamed).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				Assert.isTrue(error.getMessage().contains(System.Label.ScheduledJob_RunnerRecordManagedByHealthCheck), 'renaming the class away is refused: ' + error.getMessage());
			}

			ScheduledJob__c detached = (ScheduledJob__c)new SEL_ScheduledJob().findById(runner.Id);
			detached.ScheduledJobId__c = null;

			try
			{
				// The trigger's guard is under test, not field access: it refuses the blanked id whoever writes it.
				DML_Builder.newTransaction().withSystemMode().doUpdate(detached).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				Assert.isTrue(error.getMessage().contains(System.Label.ScheduledJob_RunnerRecordManagedByHealthCheck), 'blanking the job id is refused: ' + error.getMessage());
			}

			Assert.isNotNull(((ScheduledJob__c)new SEL_ScheduledJob().findById(runner.Id)).ScheduledJobId__c, 'so the live platform job stays reachable from the record');

			ScheduledJob__c healthCheckWrite = (ScheduledJob__c)new SEL_ScheduledJob().findById(runner.Id);
			healthCheckWrite.ScheduledJobId__c = null;
			healthCheckWrite.ClassName__c = PlainSchedulable.class.getName();

			TRG_ScheduleJob.allowRunnerRecordManagement = true;
			// Stands in for Health Check's own write, which runs in system mode.
			DML_Builder.newTransaction().withSystemMode().doUpdate(healthCheckWrite).execute();
			TRG_ScheduleJob.allowRunnerRecordManagement = false;

			Assert.isTrue(new SEL_ScheduledJob().findRunnerRecords().isEmpty(), 'Health Check may do both: its write landed');
		}
	}

	/**
	 * @description Tests that a job on the job runner comes back switched off when it is restored from the Recycle Bin. A
	 * user who holds the Manage Job Runner permission deletes the job, and a user without that permission restores it.
	 * The restore succeeds: switching the job off is a save the framework makes, not a change by that user. Because the
	 * job is off, the job runner's read of the jobs that are due does not return it, even at its next run time.
	 */
	@IsTest
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static void shouldRestoreAJobOnTheRunnerSwitchedOff()
	{
		ScheduledJob__c record = insertJobRunnerRecordAsPermissionHolder();

		System.runAs(getManagingAdmin())
		{
			DML_Builder.newTransaction().doDelete(record).execute();
		}

		System.runAs(getStandardUserWithoutJobRunnerPermission())
		{
			// Only the user who deleted a record, or a user with wider access, may restore it. That access is not under test here.
			DML_Builder.newTransaction().withSystemMode().bypassSharing().doUndelete(record).execute();
		}

		ScheduledJob__c restored = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
		Assert.isNotNull(restored, 'Expected the job to be restored');
		Assert.isFalse(restored.IsActive__c, 'Expected the restored job to be switched off');
		Assert.isNotNull(restored.NextRunAt__c, 'Expected the restored job to keep its next run time');

		Set<Id> dueJobIds = new Map<Id, ScheduledJob__c>(new SEL_ScheduledJob().findDueJobRunnerRecordsForUpdate(restored.NextRunAt__c, DUE_JOB_CHECK_LIMIT)).keySet();
		Assert.isFalse(dueJobIds.contains(record.Id), 'Expected the job runner not to start a restored job that is switched off');
	}

	/**
	 * @description Tests that an active job with a scheduled job of its own comes back switched off when it is restored
	 * from the Recycle Bin. Deleting the job stopped its platform job, so the restored job must not point at that platform
	 * job any more, and the restore must not schedule a new one.
	 */
	@IsTest
	private static void shouldRestoreAnOwnScheduleJobSwitchedOffWithNoPlatformJob()
	{
		System.runAs(getTestAdmin())
		{
			ScheduledJob__c record = TST_Factory.insertScheduledJob(PlainSchedulable.class.getName());
			Assert.isNotNull(((ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id)).ScheduledJobId__c, 'Expected the job to start with a platform job');

			DML_Builder.newTransaction().doDelete(record).execute();
			Integer platformJobsAfterDelete = QRY_Builder.selectFrom(CronTrigger.SObjectType).count();

			DML_Builder.newTransaction().doUndelete(record).execute();

			ScheduledJob__c restored = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
			Assert.isFalse(restored.IsActive__c, 'Expected the restored job to be switched off');
			Assert.isNull(restored.ScheduledJobId__c, 'Expected the restored job not to point at the platform job its delete stopped');
			Assert.areEqual(platformJobsAfterDelete, QRY_Builder.selectFrom(CronTrigger.SObjectType).count(), 'Expected the restore not to schedule a platform job');
		}
	}

	/**
	 * @description Tests that one of the job runner's own records cannot be restored from the Recycle Bin: the restore is
	 * refused and the record stays there. With the allowance Health Check sets around its own writes, the restore goes
	 * through and the record comes back switched off, like every other restored job.
	 */
	@IsTest
	private static void shouldRefuseRestoringARunnerRecordOutsideHealthCheck()
	{
		System.runAs(getManagingAdmin())
		{
			ScheduledJob__c runner = newRunnerRecord();
			runner.IsActive__c = true;

			TRG_ScheduleJob.allowRunnerRecordManagement = true;
			DML_Builder.newTransaction().doInsert(runner).execute();
			Assert.isTrue(((ScheduledJob__c)new SEL_ScheduledJob().findById(runner.Id)).IsActive__c, 'Expected the runner record to start switched on');
			DML_Builder.newTransaction().doDelete(runner).execute();
			TRG_ScheduleJob.allowRunnerRecordManagement = false;

			try
			{
				DML_Builder.newTransaction().doUndelete(runner).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				String message = error.getMessage();
				Assert.isTrue(message.contains(System.Label.ScheduledJob_RunnerRecordManagedByHealthCheck), 'Expected the restore to be refused: ' + message);
			}

			Assert.isTrue(new SEL_ScheduledJob().findRunnerRecords().isEmpty(), 'Expected the runner record to stay in the Recycle Bin');

			TRG_ScheduleJob.allowRunnerRecordManagement = true;
			DML_Builder.newTransaction().doUndelete(runner).execute();
			TRG_ScheduleJob.allowRunnerRecordManagement = false;

			List<ScheduledJob__c> restoredRunnerRecords = new SEL_ScheduledJob().findRunnerRecords();
			Assert.areEqual(1, restoredRunnerRecords.size(), 'Expected the restore with the Health Check allowance to bring the runner record back');
			Assert.isFalse(restoredRunnerRecords[0].IsActive__c, 'Expected the restored runner record to be switched off');
		}
	}

	/**
	 * @description Tests that a restore is refused when the save that switches the restored job off fails. Here another
	 * trigger action refuses every update of a job, as a subscriber's validation rule or flow could.
	 *
	 * The restore action's own row is set to log a failure and go on, as a subscriber may set it, so only the action
	 * itself can refuse the restore. The job must stay in the Recycle Bin, because a restored job must never come back switched on.
	 */
	@IsTest
	private static void shouldRefuseARestoreWhenTheJobCannotBeSwitchedOff()
	{
		TriggerSetting__mdt setting = TST_Factory.newTriggerSetting(UTIL_SObjectDescribe.getObjectNameFromType(ScheduledJob__c.SObjectType));

		TriggerAction__mdt restoreRow = TST_Factory.newTriggerActionForContext(TRG_ScheduleJob.class.getName(), setting, TriggerOperation.AFTER_UNDELETE);
		restoreRow.FailureAction__c = SEL_TriggerAction.FAILURE_ACTION_LOG_AND_CONTINUE;

		TriggerAction__mdt refusingRow = TST_Factory.newTriggerActionForContext(SWITCH_OFF_REFUSING_ACTION, setting, TriggerOperation.BEFORE_UPDATE);
		refusingRow.AllowNonSelfInitiated__c = true;

		TST_Mock.register(TriggerSetting__mdt.SObjectType, TST_Factory.newTriggerSettingWithActions(setting, new List<TriggerAction__mdt> {restoreRow, refusingRow}));

		System.runAs(getTestAdmin())
		{
			ScheduledJob__c record = newJobRunnerRecord(CRON_EVERY_FIVE_MINUTES);
			DML_Builder.newTransaction().doInsert(record).execute();
			DML_Builder.newTransaction().doDelete(record).execute();

			try
			{
				DML_Builder.newTransaction().doUndelete(record).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				String message = error.getMessage();
				Assert.isTrue(message.contains(System.Label.ScheduledJob_RestoreNotSwitchedOff), 'Expected the restore to be refused: ' + message);
			}

			Assert.isNull(new SEL_ScheduledJob().findById(record.Id), 'Expected the job to stay in the Recycle Bin');
		}
	}

	/**
	 * @description Tests that a restored job with a scheduled job of its own is scheduled again when someone turns it back
	 * on through a normal save, as any job is when it is switched on.
	 */
	@IsTest
	private static void shouldScheduleARestoredOwnScheduleJobWhenItIsTurnedOnAgain()
	{
		System.runAs(getTestAdmin())
		{
			ScheduledJob__c record = TST_Factory.insertScheduledJob(PlainSchedulable.class.getName());

			DML_Builder.newTransaction().doDelete(record).execute();
			DML_Builder.newTransaction().doUndelete(record).execute();

			Test.startTest();

			ScheduledJob__c turnOn = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
			turnOn.IsActive__c = true;
			DML_Builder.newTransaction().doUpdate(turnOn).execute();

			Test.stopTest();

			ScheduledJob__c turnedOn = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
			Assert.isTrue(turnedOn.IsActive__c, 'Expected the job to be switched on');
			Assert.isNotNull(turnedOn.ScheduledJobId__c, 'Expected the job to point at a platform job');
			CronTrigger platformJob = (CronTrigger)QRY_Builder.selectFrom(CronTrigger.SObjectType)
					.condition('Id').equals(turnedOn.ScheduledJobId__c)
					.getFirst();
			Assert.isNotNull(platformJob, 'Expected turning the job on to schedule a new platform job');
		}
	}

	/**
	 * @description Tests that a restored job on the job runner gets a new next run time when a user who holds the Manage
	 * Job Runner permission turns it back on through a normal save. The test first moves the job's next run time into the
	 * past, so only a new one from the save can be in the future.
	 */
	@IsTest
	private static void shouldSeedTheCursorOfARestoredRunnerJobWhenItIsTurnedOnAgain()
	{
		ScheduledJob__c record = insertJobRunnerRecordAsPermissionHolder();
		record.NextRunAt__c = Datetime.now().addDays(-1);
		new UTIL_ScheduledJobRunner.FrameworkWriter().updateRecord(record);

		System.runAs(getManagingAdmin())
		{
			DML_Builder.newTransaction().doDelete(record).execute();
			DML_Builder.newTransaction().doUndelete(record).execute();

			ScheduledJob__c turnOn = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
			turnOn.IsActive__c = true;
			DML_Builder.newTransaction().doUpdate(turnOn).execute();
		}

		ScheduledJob__c turnedOn = (ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id);
		Assert.isTrue(turnedOn.IsActive__c, 'Expected the job to be switched on');
		Assert.isTrue(turnedOn.NextRunAt__c > Datetime.now(), 'Expected turning the job on to give it a next run time in the future');
		Assert.isNull(turnedOn.ScheduledJobId__c, 'Expected a job on the job runner to have no platform job of its own');
	}

	/**
	 * @description Tests that a save configures the job it schedules exactly once: a subscriber's setParameterValues may
	 * create records or call out, so the trigger must not run it twice for one save.
	 */
	@IsTest
	private static void anOwnModeSaveConfiguresItsJobExactlyOnce()
	{
		System.runAs(getTestAdmin())
		{
			parameterInjectionCount = 0;

			Test.startTest();

			ScheduledJob__c record = TST_Factory.insertScheduledJob(CountingScheduler.class.getName(), buildRequiredParameterMap(REQUIRED_PARAMETER_VALUE));

			Test.stopTest();

			Assert.isNotNull(((ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id)).ScheduledJobId__c, 'the job was scheduled');
			Assert.areEqual(1, parameterInjectionCount, 'the save configured the job exactly once');
		}
	}

	/**
	 * @description Saves a job from inside another trigger action. A dispatcher runs the Foobar before insert step with
	 * JobSavingAction as its only action, and that action saves the job. The job's own trigger then runs while
	 * JobSavingAction is first on the stack, as it does when a trigger action or a flow saves a job. The action row
	 * blocks the save on an error, so a refusal of the job reaches the caller as it does on a direct save.
	 *
	 * @param job The job to insert (no Id) or update (with an Id).
	 */
	private static void saveJobFromInsideAnotherAction(ScheduledJob__c job)
	{
		jobSavedByAnotherAction = job;

		TriggerAction__mdt savingRow = TST_Factory.newTriggerActionForContext
				(
						JOB_SAVING_ACTION,
						TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME),
						TriggerOperation.BEFORE_INSERT
				);
		savingRow.FailureAction__c = SEL_TriggerAction.FAILURE_ACTION_BLOCK_DML;

		TRG_Dispatcher dispatcher = new TRG_Dispatcher();
		dispatcher.triggerNew = new List<Foobar__c>
		{
				(Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Id, UTIL_Random.randomId(Foobar__c.SObjectType)).withoutInsertion().build()
		};
		dispatcher.context = TriggerOperation.BEFORE_INSERT;
		dispatcher.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt> {savingRow}
		};

		dispatcher.run();
	}

	/**
	 * @description Tests that a user without the Manage Job Runner permission cannot change a job on the job runner by
	 * having another trigger action save the change. The save is refused with the same message a direct save gets, and
	 * the stored job keeps its old value.
	 */
	@IsTest
	@SuppressWarnings('PMD.KernUseTestBuilder')
	private static void shouldRefuseARunnerJobChangeMadeFromInsideAnotherAction()
	{
		ScheduledJob__c record = insertJobRunnerRecordAsPermissionHolder();

		System.runAs(getStandardUserWithoutJobRunnerPermission())
		{
			try
			{
				saveJobFromInsideAnotherAction(new ScheduledJob__c(Id = record.Id, RunPriority__c = EDITED_RUN_PRIORITY));
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				Assert.isTrue
						(
								error.getMessage().contains(System.Label.ScheduledJob_ManageJobRunnerPermissionRequired),
								'Expected the change saved by another action to be refused with the permission message: ' + error.getMessage()
						);
			}
		}

		Assert.areEqual
				(
						record.RunPriority__c,
						new SEL_ScheduledJob().findById(record.Id).get(ScheduledJob__c.RunPriority__c),
						'Expected the stored job to keep its old priority'
				);
	}

	/**
	 * @description Tests that an active job of its own inserted by another trigger action is scheduled, and that the
	 * insert configures the job exactly once, so the trigger runs once for the save.
	 */
	@IsTest
	private static void shouldScheduleAJobInsertedFromInsideAnotherAction()
	{
		System.runAs(getTestAdmin())
		{
			parameterInjectionCount = 0;
			ScheduledJob__c record = (ScheduledJob__c)TST_Builder.of(ScheduledJob__c.SObjectType)
					.withOverride(ScheduledJob__c.SchedulerName__c, UTIL_Random.randomName())
					.withOverride(ScheduledJob__c.ClassName__c, CountingScheduler.class.getName())
					.withOverride(ScheduledJob__c.CronExpression__c, CRON_HALF_PAST_THREE)
					.withOverride(ScheduledJob__c.IsActive__c, true)
					.withOverride(ScheduledJob__c.Timezone__c, UserInfo.getTimeZone().getID())
					.withOverride(ScheduledJob__c.ExecutionMode__c, UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB)
					.withOverride(ScheduledJob__c.Parameters__c, serializeRequiredParameter(REQUIRED_PARAMETER_VALUE))
					.withoutInsertion()
					.build();

			Test.startTest();

			saveJobFromInsideAnotherAction(record);

			Test.stopTest();

			Assert.isNotNull(record.Id, 'Expected the other action to have inserted the job');
			Assert.isNotNull(((ScheduledJob__c)new SEL_ScheduledJob().findById(record.Id)).ScheduledJobId__c, 'Expected a platform job for the inserted job');
			Assert.areEqual(1, parameterInjectionCount, 'Expected the insert to configure the job exactly once');
		}
	}

	/**
	 * @description A Foobar before insert trigger action that saves jobSavedByAnotherAction from inside itself, so the
	 * job's own trigger runs while this action is first on the stack.
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	public class JobSavingAction implements IF_Trigger.BeforeInsert
	{
		/**
		 * @description Inserts jobSavedByAnotherAction when it has no Id, and updates it otherwise.
		 *
		 * @param triggerNew The Foobar records of the step; unused.
		 */
		public void beforeInsert(List<SObject> triggerNew)
		{
			ScheduledJob__c job = TRG_ScheduleJob_TEST.jobSavedByAnotherAction;
			if(job.Id == null)
			{
				DML_Builder.newTransaction().doInsert(job).execute();
			}
			else
			{
				DML_Builder.newTransaction().doUpdate(job).execute();
			}
		}
	}

	/**
	 * @description A scheduled job before update trigger action that refuses every update, so a test can make the save
	 * that switches a restored job off fail.
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	public class SwitchOffRefusingAction implements IF_Trigger.BeforeUpdate
	{
		/**
		 * @description Adds an error to each job of the update.
		 *
		 * @param triggerNew The jobs being updated.
		 * @param triggerOld The jobs as they were before the update; unused.
		 */
		public void beforeUpdate(List<SObject> triggerNew, List<SObject> triggerOld)
		{
			for(SObject job : triggerNew)
			{
				job.addError(SWITCH_OFF_REFUSED_MESSAGE);
			}
		}
	}

	/**
	 * @description Tests the helpers the job runner shares with the trigger: a class name becomes a job, parameters are
	 * injected, a missing required parameter is named, and an empty JSON object deserializes to no attributes.
	 */
	@IsTest
	private static void sharedHelpersResolveInjectAndRefuseMissingParameters()
	{
		Schedulable plain = TRG_ScheduleJob.resolveJobInstance(PlainSchedulable.class.getName());
		Assert.isInstanceOfType(plain, PlainSchedulable.class, 'the class resolves to a Schedulable');

		Schedulable configurable = TRG_ScheduleJob.resolveJobInstance(AttributeScheduler.class.getName());
		String serializedParameters = serializeRequiredParameter(REQUIRED_PARAMETER_VALUE);
		TRG_ScheduleJob.injectParameters(configurable, TRG_ScheduleJob.deserializeAttributes(serializedParameters));
		Assert.isTrue(configurable instanceof IF_Schedulable, 'a SCHED_Base subclass takes parameters');

		try
		{
			TRG_ScheduleJob.injectParameters(TRG_ScheduleJob.resolveJobInstance(AttributeScheduler.class.getName()), TRG_ScheduleJob.deserializeAttributes(null));
			Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, ERROR_INCORRECT_EXCEPTION);
			Assert.isTrue(error.getMessage().contains(REQUIRED_PARAMETER_LABEL), 'the missing required parameter is named: ' + error.getMessage());
		}

		Assert.isTrue(TRG_ScheduleJob.deserializeAttributes(UTIL_String.EMPTY_JSON_RESPONSE).isEmpty(), 'an empty JSON object deserializes to no attributes');
	}

	/**
	 * @description IF_Schedulable that counts how often a save gives it its parameters. It implements the interface
	 * directly rather than extending SCHED_Base because SCHED_Base declares setParameterValues non-virtual, so a
	 * fixture that must see the call cannot inherit it.
	 */
	@SuppressWarnings('PMD.KernUseSchedulerBase')
	public class CountingScheduler implements Schedulable, IF_Schedulable
	{
		/**
		 * @description Executes the scheduled job (no-op for testing).
		 *
		 * @param context The SchedulableContext.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public void execute(SchedulableContext context)
		{
		}

		/**
		 * @description Returns the parameter definitions for this test scheduler, none of them required.
		 *
		 * @return List of parameter definitions.
		 */
		public List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
		{
			return new List<DTO_ScheduledParameterDefinition>
			{
					DTO_ScheduledParameterDefinition.of(REQUIRED_PARAMETER_NAME, REQUIRED_PARAMETER_LABEL)
			};
		}

		/**
		 * @description Counts the call instead of keeping the values, standing in for a subscriber implementation with
		 * side effects.
		 *
		 * @param parameterValues The parameter values (counted, not kept).
		 */
		public void setParameterValues(DTO_NameValues parameterValues)
		{
			parameterInjectionCount++;
		}
	}

	/**
	 * @description Plain Schedulable class without IF_Schedulable for testing.
	 */
	public class PlainSchedulable implements Schedulable
	{
		/**
		 * @description Executes the scheduled job (no-op for testing).
		 *
		 * @param context The SchedulableContext.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public void execute(SchedulableContext context)
		{
		}
	}

	/**
	 * @description SCHED_Base subclass with no overridden parameter definitions for testing.
	 */
	public class EmptyDefinitionScheduler extends SCHED_Base
	{
		/**
		 * @description Executes the scheduled job (no-op for testing).
		 *
		 * @param context The SchedulableContext.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public void execute(SchedulableContext context)
		{
		}
	}

	/**
	 * @description IF_Schedulable that throws from setParameterValues for testing error handling.
	 */
	public class ThrowingScheduler implements Schedulable, IF_Schedulable
	{
		/**
		 * @description Executes the scheduled job (no-op for testing).
		 *
		 * @param context The SchedulableContext.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public void execute(SchedulableContext context)
		{
		}

		/**
		 * @description Returns the parameter definitions for this test scheduler.
		 *
		 * @return List of parameter definitions.
		 */
		public List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
		{
			return new List<DTO_ScheduledParameterDefinition>
			{
					DTO_ScheduledParameterDefinition.of('param1', 'Parameter 1').required()
			};
		}

		/**
		 * @description Always throws to test the error handling path.
		 *
		 * @param parameterValues The parameter values (ignored).
		 */
		public void setParameterValues(DTO_NameValues parameterValues)
		{
			throw new IllegalArgumentException('Invalid parameter configuration');
		}
	}

	/**
	 * @description Tests that a scheduled job with null Timezone__c uses the raw cron expression (backward compatible).
	 */
	@IsTest
	private static void shouldScheduleWithNullTimezone()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			ScheduledJob__c scheduler = TST_Factory.insertScheduledJob(PlainSchedulable.class.getName());

			Test.stopTest();

			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			Assert.isNotNull(scheduler.ScheduledJobId__c, 'Job with null timezone should schedule using raw cron');
			Assert.isNull(scheduler.Timezone__c, 'Timezone should be null when not set');
		}
	}

	/**
	 * @description Tests that a scheduled job with a matching timezone schedules without shifting the cron.
	 */
	@IsTest
	private static void shouldScheduleWithMatchingTimezone()
	{
		System.runAs(getTestAdmin())
		{
			TRG_Base.bypass(ScheduledJob__c.SObjectType);

			ScheduledJob__c scheduler = TST_Factory.insertInactiveScheduledJob(PlainSchedulable.class.getName());
			scheduler.Timezone__c = UserInfo.getTimeZone().getID();
			scheduler.IsActive__c = true;

			TRG_Base.clearBypass(ScheduledJob__c.SObjectType);

			Test.startTest();

			DML_Builder.newTransaction().doUpdate(scheduler).execute();

			Test.stopTest();

			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			Assert.isNotNull(scheduler.ScheduledJobId__c, 'Job with matching timezone should schedule successfully');
		}
	}

	/**
	 * @description Tests that a scheduled job with a different timezone shifts the cron expression before scheduling.
	 */
	@IsTest
	private static void shouldScheduleWithDifferentTimezone()
	{
		System.runAs(getTestAdmin())
		{
			String userTimezone = UserInfo.getTimeZone().getID();
			String differentTimezone = userTimezone == 'Australia/Brisbane' ? 'Africa/Johannesburg' : 'Australia/Brisbane';

			TRG_Base.bypass(ScheduledJob__c.SObjectType);

			ScheduledJob__c scheduler = TST_Factory.insertInactiveScheduledJob(PlainSchedulable.class.getName());
			scheduler.Timezone__c = differentTimezone;
			scheduler.IsActive__c = true;

			TRG_Base.clearBypass(ScheduledJob__c.SObjectType);

			Test.startTest();

			DML_Builder.newTransaction().doUpdate(scheduler).execute();

			Test.stopTest();

			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			Assert.isNotNull(scheduler.ScheduledJobId__c, 'Job with different timezone should schedule with shifted cron');
			Assert.areEqual(differentTimezone, scheduler.Timezone__c, 'Timezone should persist after scheduling');
		}
	}

	/**
	 * @description A schedule whose hours field is a step is converted to a list of hours before it reaches the platform,
	 * and the platform takes that list, so the save starts a job. Seven does not divide the 24 hours of a day, so the
	 * hours of this step are not evenly spaced across midnight.
	 */
	@IsTest
	private static void shouldScheduleAConvertedHourStep()
	{
		System.runAs(getTestAdmin())
		{
			ScheduledJob__c scheduler = buildActiveJobInAnotherTimezone(CRON_EVERY_SEVENTH_HOUR);

			Test.startTest();

			DML_Builder.newTransaction().doUpdate(scheduler).execute();

			Test.stopTest();

			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			Assert.isNotNull(scheduler.ScheduledJobId__c, 'Expected the platform to take the converted hours');
		}
	}

	/**
	 * @description A schedule that one cron expression cannot carry into the saving user's time zone is refused, and the
	 * person saving it sees the reason on the cron expression field, not a raw error. A wildcard hours field on one named
	 * weekday cannot be rewritten for any other zone, because some of its hours would land on the day before.
	 */
	@IsTest
	private static void shouldRefuseScheduleThatCannotKeepItsTimesInTheSavingUsersTimezone()
	{
		System.runAs(getTestAdmin())
		{
			ScheduledJob__c scheduler = buildActiveJobInAnotherTimezone(CRON_EVERY_HOUR_ON_MONDAYS);

			try
			{
				Test.startTest();

				DML_Builder.newTransaction().doUpdate(scheduler).execute();

				Test.stopTest();

				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(DmlException error)
			{
				List<Object> timezones = new List<Object> {scheduler.Timezone__c, UserInfo.getTimeZone().getID()};
				String expected = String.format(System.Label.ScheduledJob_ScheduleCannotKeepTimesAcrossTimeZones, timezones);
				Assert.isTrue(error.getMessage().contains(expected), 'Expected the labelled refusal in: ' + error.getMessage());
				String fieldName = UTIL_SObjectDescribe.getCachedFieldName(ScheduledJob__c.CronExpression__c);
				Assert.isTrue(error.getMessage().contains(fieldName), 'Expected the error on the cron expression field in: ' + error.getMessage());
			}

			scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);
			Assert.isNull(scheduler.ScheduledJobId__c, 'Expected no platform job for a refused schedule');
		}
	}

	/**
	 * @description Schedulable class that accepts configurable attributes for testing.
	 */
	public class AttributeScheduler extends SCHED_Base
	{
		/**
		 * @description Executes the scheduled job (no-op for testing).
		 *
		 * @param context The SchedulableContext.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public void execute(SchedulableContext context)
		{
		}

		/**
		 * @description Returns the parameter definitions for this test scheduler.
		 *
		 * @return List of parameter definitions.
		 */
		public override List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
		{
			return new List<DTO_ScheduledParameterDefinition>
			{
					DTO_ScheduledParameterDefinition.of('param1', 'Parameter 1').required()
			};
		}
	}

	/**
	 * @description Builds an inserted job, not yet saved as active, that is written for a time zone other than the running
	 * user's. Saving it starts the job in the trigger.
	 *
	 * @param cronExpression The cron expression of the job.
	 *
	 * @return The job, with the changes not yet saved.
	 */
	private static ScheduledJob__c buildActiveJobInAnotherTimezone(String cronExpression)
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);

		ScheduledJob__c scheduler = TST_Factory.insertInactiveScheduledJob(PlainSchedulable.class.getName());
		scheduler.Timezone__c = UserInfo.getTimeZone().getID() == 'Australia/Brisbane' ? 'Africa/Johannesburg' : 'Australia/Brisbane';
		scheduler.CronExpression__c = cronExpression;
		scheduler.IsActive__c = true;

		TRG_Base.clearBypass(ScheduledJob__c.SObjectType);

		return scheduler;
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup for use with
	 * System.runAs, so each test body runs with a fresh permission-evaluation context.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}
}