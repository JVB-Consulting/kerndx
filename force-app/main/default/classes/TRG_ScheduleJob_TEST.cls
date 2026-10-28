// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for TRG_ScheduleJob trigger action.
 *
 * @see TRG_ScheduleJob
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date January 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
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
	 * @description The time zone a job-runner record's expression is read in, the evaluator's own default spelling.
	 */
	private static final String TIMEZONE_UTC = 'UTC';

	/**
	 * @description An expression that fires every five minutes, so the seeded cursor is always within five minutes.
	 */
	private static final String CRON_EVERY_FIVE_MINUTES = '0 */5 * * * ?';

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
	 * @description Tests that a user without the permission may still edit a job that is on the runner (here its run
	 * priority, which still reaches the permission check), but not change which code it runs.
	 */
	@IsTest
	private static void changingClassOrParametersOfAJobRunnerRecordNeedsThePermissionButOtherEditsDoNot()
	{
		ScheduledJob__c record = newJobRunnerRecord(CRON_EVERY_FIVE_MINUTES);

		System.runAs(getStandardUserWithJobRunnerPermission())
		{
			DML_Builder.newTransaction().doInsert(record).execute();
		}

		System.runAs(getStandardUserWithoutJobRunnerPermission())
		{
			record.RunPriority__c = EDITED_RUN_PRIORITY;
			DML_Builder.newTransaction().doUpdate(record).execute();

			record.ClassName__c = AttributeScheduler.class.getName();
			record.Parameters__c = serializeRequiredParameter(REQUIRED_PARAMETER_VALUE);

			try
			{
				DML_Builder.newTransaction().doUpdate(record).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				Assert.isTrue(error.getMessage().contains(System.Label.ScheduledJob_ManageJobRunnerPermissionRequired), 'a class change is gated: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Tests that changing only the parameters of a job on the runner is gated too: the values a job runs
	 * with are as much a part of what it does as the class name.
	 */
	@IsTest
	private static void changingOnlyTheParametersOfAJobRunnerRecordNeedsThePermission()
	{
		ScheduledJob__c record = newJobRunnerRecord(CRON_EVERY_FIVE_MINUTES);

		System.runAs(getStandardUserWithJobRunnerPermission())
		{
			DML_Builder.newTransaction().doInsert(record).execute();
		}

		System.runAs(getStandardUserWithoutJobRunnerPermission())
		{
			record.Parameters__c = serializeRequiredParameter(REQUIRED_PARAMETER_VALUE);

			try
			{
				DML_Builder.newTransaction().doUpdate(record).execute();
				Assert.fail(NO_EXCEPTION_WAS_THROWN_AS_EXPECTED);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, ERROR_INCORRECT_EXCEPTION);
				Assert.isTrue(error.getMessage().contains(System.Label.ScheduledJob_ManageJobRunnerPermissionRequired), 'a parameters-only change is gated: ' + error.getMessage());
			}
		}
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
	 * refused, the same insert succeeds with the flag Health Check sets, a later direct update is refused, and a delete
	 * is allowed from anywhere. What the record's own scheduling looks like is not in scope here; that belongs to Health
	 * Check's own tests, once the runner's schedulable exists.
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

			DML_Builder.newTransaction().doDelete(runner).execute();
			Assert.isTrue(new SEL_ScheduledJob().findRunnerRecords().isEmpty(), 'a delete is allowed from anywhere');
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