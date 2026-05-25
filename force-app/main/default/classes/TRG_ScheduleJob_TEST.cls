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
 * @date January 2026, February 2026, March 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class TRG_ScheduleJob_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'TRG_ScheduleJob_TEST-admin';
	private static final String ERROR_INCORRECT_EXCEPTION = 'Incorrect Exception was thrown';
	private static final String NO_EXCEPTION_WAS_THROWN_AS_EXPECTED = 'No exception was thrown as expected';

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