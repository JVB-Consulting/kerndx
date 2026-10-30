// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for PROC_ExecuteDML processor.
 *
 * @see PROC_ExecuteDML
 *
 * @author Jason van Beukering
 *
 * @group Bulk DML
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class PROC_ExecuteDML_TEST
{
	/**
	 * @description Company name of the admin user created in the test setup. Each test finds that user by this name and
	 * runs as them.
	 */
	private static final String TEST_ADMIN_COMPANY = 'PROC_ExecuteDML_TEST-admin';

	/**
	 * @description An email value the platform refuses with INVALID_EMAIL_ADDRESS.
	 */
	private static final String INVALID_EMAIL = 'not-a-valid-email';

	/**
	 * @description DML operation constant for delete.
	 */
	private static final DML_Builder.DatabaseOperation OPERATION_DELETE = DML_Builder.DatabaseOperation.DML_DELETE;

	/**
	 * @description DML operation constant for insert.
	 */
	private static final DML_Builder.DatabaseOperation OPERATION_INSERT = DML_Builder.DatabaseOperation.DML_INSERT;

	/**
	 * @description DML operation constant for update.
	 */
	private static final DML_Builder.DatabaseOperation OPERATION_UPDATE = DML_Builder.DatabaseOperation.DML_UPDATE;

	/**
	 * @description DML operation constant for upsert.
	 */
	private static final DML_Builder.DatabaseOperation OPERATION_UPSERT = DML_Builder.DatabaseOperation.DML_UPSERT;

	/**
	 * @description DML operation constant for undelete.
	 */
	private static final DML_Builder.DatabaseOperation OPERATION_UNDELETE = DML_Builder.DatabaseOperation.DML_UNDELETE;

	/**
	 * @description Error message for unexpected record count.
	 */
	private static final String MSG_INCORRECT_COUNT = 'Expected {0} records, found {1}';

	/**
	 * @description Error message when records were not deleted.
	 */
	private static final String MSG_NOT_DELETED = 'Expected records to be deleted';

	/**
	 * @description Error message when records were not inserted.
	 */
	private static final String MSG_NOT_INSERTED = 'Expected records to be inserted';

	/**
	 * @description Error message when field was not updated.
	 */
	private static final String MSG_NOT_UPDATED = 'Expected field to be updated';

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
	 * @description Tests INSERT operation.
	 */
	@IsTest
	private static void shouldInsertRecords()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.newFoobars(5);

			Test.startTest();

			new PROC_ExecuteDML(OPERATION_INSERT).execute(records);

			Test.stopTest();

			List<Foobar__c> insertedRecords = new SEL_Foobar().getAll();
			Assert.areEqual(5, insertedRecords.size(), String.format(MSG_INCORRECT_COUNT, new List<Object> {5, insertedRecords.size()}));
		}
	}

	/**
	 * @description Tests UPDATE operation.
	 */
	@IsTest
	private static void shouldUpdateRecords()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(5);
			Datetime testDateTime = UTIL_Random.randomDateTime();

			for(Foobar__c record : records)
			{
				record.Datetime__c = testDateTime;
			}

			Test.startTest();

			new PROC_ExecuteDML(OPERATION_UPDATE).execute(records);

			Test.stopTest();

			List<Foobar__c> updatedRecords = new SEL_Foobar().getAll();
			for(Foobar__c record : updatedRecords)
			{
				Assert.areEqual(testDateTime, record.Datetime__c, MSG_NOT_UPDATED);
			}
		}
	}

	/**
	 * @description Tests DELETE operation.
	 */
	@IsTest
	private static void shouldDeleteRecords()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(5);

			Test.startTest();

			new PROC_ExecuteDML(OPERATION_DELETE).execute(records);

			Test.stopTest();

			Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), MSG_NOT_DELETED);
		}
	}

	/**
	 * @description Tests UPSERT operation with new records.
	 */
	@IsTest
	private static void shouldUpsertNewRecords()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.newFoobars(5);

			Test.startTest();

			new PROC_ExecuteDML(OPERATION_UPSERT).execute(records);

			Test.stopTest();

			List<Foobar__c> upsertedRecords = new SEL_Foobar().getAll();
			Assert.areEqual(5, upsertedRecords.size(), String.format(MSG_INCORRECT_COUNT, new List<Object> {5, upsertedRecords.size()}));
		}
	}

	/**
	 * @description Tests UPSERT operation with existing records.
	 */
	@IsTest
	private static void shouldUpsertExistingRecords()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(5);
			Datetime testDateTime = UTIL_Random.randomDateTime();

			for(Foobar__c record : records)
			{
				record.Datetime__c = testDateTime;
			}

			Test.startTest();

			new PROC_ExecuteDML(OPERATION_UPSERT).execute(records);

			Test.stopTest();

			List<Foobar__c> upsertedRecords = new SEL_Foobar().getAll();
			Assert.areEqual(5, upsertedRecords.size(), String.format(MSG_INCORRECT_COUNT, new List<Object> {5, upsertedRecords.size()}));
			for(Foobar__c record : upsertedRecords)
			{
				Assert.areEqual(testDateTime, record.Datetime__c, MSG_NOT_UPDATED);
			}
		}
	}

	/**
	 * @description Tests UNDELETE operation.
	 */
	@IsTest
	private static void shouldUndeleteRecords()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(5);
			DML_Builder.newTransaction().doDelete(records).execute();

			Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), 'Records should be deleted before undelete test');

			Test.startTest();

			new PROC_ExecuteDML(OPERATION_UNDELETE).execute(records);

			Test.stopTest();

			List<Foobar__c> undeletedRecords = new SEL_Foobar().getAll();
			Assert.areEqual(5, undeletedRecords.size(), String.format(MSG_INCORRECT_COUNT, new List<Object> {5, undeletedRecords.size()}));
		}
	}

	/**
	 * @description Tests partial success mode (allOrNothing = false).
	 */
	@IsTest
	private static void shouldAllowPartialSuccess()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(5);

			Test.startTest();

			new PROC_ExecuteDML(OPERATION_DELETE, false).execute(records);

			Test.stopTest();

			Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), MSG_NOT_DELETED);
		}
	}

	/**
	 * @description Proves a processor told which refusals to expect logs one of them at WARN rather than
	 * ERROR when the commit allows partial success, which is what lets the declaration made on the
	 * synchronous side keep its meaning once the job runs.
	 */
	@IsTest
	private static void shouldLogExpectedRefusalAtWarn()
	{
		System.runAs(getTestAdmin())
		{
			captureLogEntries();
			PROC_ExecuteDML processor = new PROC_ExecuteDML(OPERATION_INSERT, false, AccessLevel.SYSTEM_MODE);
			processor.expectRefusals(new Set<StatusCode> {StatusCode.INVALID_EMAIL_ADDRESS});

			Test.startTest();

			processor.execute(new List<Object> {TST_Factory.newFoobarWithEmail(INVALID_EMAIL)});

			Test.stopTest();

			Assert.areEqual(1, new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN).size(), 'The expected refusal should be logged once at WARN');
			Assert.isTrue(new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR).isEmpty(), 'Nothing should be logged at ERROR');
		}
	}

	/**
	 * @description Verifies the carried count reaches the job's builder as given: a batch refused twice for a row lock
	 * recovers on its third attempt, which one retry, the builder's default, could not do.
	 */
	@IsTest
	private static void retryOnLockShouldReachTheBatchBuilder()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().withCount(2).buildList();
			PROC_ExecuteDML processor = new PROC_ExecuteDML(OPERATION_INSERT, true, AccessLevel.SYSTEM_MODE);
			processor.retryOnLock(2);
			DML_SharingProxy.sharingProxyForTest = new DML_ThrowingLockProxy_TEST(2);

			try
			{
				Test.startTest();
				processor.execute(records);
				Test.stopTest();
			}
			finally
			{
				DML_SharingProxy.sharingProxyForTest = null;
			}

			Assert.isNotNull(records[0].Id, 'The batch should save on its third attempt');
			Assert.isNotNull(records[1].Id, 'Every row of the batch should be saved');
		}
	}

	/**
	 * @description Tests all-or-nothing mode (default behavior).
	 */
	@IsTest
	private static void shouldDefaultToAllOrNothing()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.newFoobars(5);

			Test.startTest();

			new PROC_ExecuteDML(OPERATION_INSERT).execute(records);

			Test.stopTest();

			Assert.areEqual(5, new SEL_Foobar().getAll().size(), MSG_NOT_INSERTED);
		}
	}

	/**
	 * @description Tests that null allOrNothing parameter defaults to true.
	 */
	@IsTest
	private static void shouldHandleNullAllOrNothing()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.newFoobars(5);

			Test.startTest();

			new PROC_ExecuteDML(OPERATION_INSERT, null).execute(records);

			Test.stopTest();

			Assert.areEqual(5, new SEL_Foobar().getAll().size(), MSG_NOT_INSERTED);
		}
	}

	/**
	 * @description Tests integration with UTIL_AsynchronousJobLauncher.
	 */
	@IsTest
	private static void shouldWorkWithAsynchronousJobLauncher()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(5);

			Test.startTest();

			UTIL_AsynchronousJobLauncher.process(records, new PROC_ExecuteDML(OPERATION_DELETE));

			Test.stopTest();

			Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), MSG_NOT_DELETED);
		}
	}

	/**
	 * @description Tests that DML exceptions are logged at the transaction's commit and rethrown.
	 */
	@IsTest
	private static void shouldLogDmlExceptions()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.newFoobar();
			record.Email__c = UTIL_Random.randomName();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();

			try
			{
				new PROC_ExecuteDML(OPERATION_INSERT).execute(new List<SObject> {record});
				Assert.fail('Expected DmlException to be thrown');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, 'Expected DmlException');
			}

			Test.stopTest();

			Test.getEventBus().deliver();

			LogEntry__c logEntry = new SEL_LogEntry().findByMethod(DML_Transaction.CLASS_METHOD_COMMIT);
			Assert.isNotNull(logEntry, 'Expected log entry for DML exception');
		}
	}

	/**
	 * @description Three-arg constructor with explicit SYSTEM_MODE commits regardless of the
	 * UserModeDml_Enabled flag state.
	 */
	@IsTest
	private static void shouldCommitWithExplicitSystemMode()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

			Test.startTest();
			new PROC_ExecuteDML(OPERATION_INSERT, true, System.AccessLevel.SYSTEM_MODE).execute(new List<SObject> {record});
			Test.stopTest();

			Assert.isNotNull(record.Id, MSG_NOT_INSERTED);
		}
	}

	/**
	 * @description Three-arg constructor with explicit USER_MODE honours the caller's opt-in — a
	 * running user with full FLS sees the DML commit; a running user without FLS would see a
	 * `DmlException` (exercised end-to-end by the subscriber-side tests).
	 */
	@IsTest
	private static void shouldCommitWithExplicitUserModeWhenUserHasFls()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

			Test.startTest();
			new PROC_ExecuteDML(OPERATION_INSERT, true, System.AccessLevel.USER_MODE).execute(new List<SObject> {record});
			Test.stopTest();

			Assert.isNotNull(record.Id, MSG_NOT_INSERTED);
		}
	}

	/**
	 * @description Three-arg constructor with `null` access level inherits the flag-driven default
	 * (DML_SharingProxy.defaultAccessLevel). With UserModeDml_Enabled on (shipped state) this is
	 * USER_MODE; an FLS-endowed running user (the test user) still commits.
	 */
	@IsTest
	private static void shouldInheritFlagDrivenDefaultWhenAccessLevelNull()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

			Test.startTest();
			new PROC_ExecuteDML(OPERATION_INSERT, true, null).execute(new List<SObject> {record});
			Test.stopTest();

			Assert.isNotNull(record.Id, MSG_NOT_INSERTED);
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

	/**
	 * @description Makes log rows observable: platform events are delivered at Test.stopTest() and a
	 * DEBUG threshold keeps every level, so a WARN row is never filtered by an org-level setting.
	 */
	private static void captureLogEntries()
	{
		LogSetting__c setting = new LogSetting__c();
		setting.IsEnabled__c = true;
		setting.LogLevelThreshold__c = LOG_Engine.LEVEL_DEBUG;
		LOG_Engine.logSettingOverride = setting;
		LOG_Builder.ignoreTestMode = true;
	}
}