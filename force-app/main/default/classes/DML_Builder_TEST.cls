// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for DML_Builder.
 *
 * @see DML_Builder
 *
 * @author Jason van Beukering
 *
 * @group DML
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssCount,PMD.NcssTypeCount')
@IsTest(seeAllData=false isParallel=false)
private class DML_Builder_TEST
{
	/**
	 * @description Company name given to the admin user created in test setup. It is unique to this class, so getTestAdmin
	 * can find that one user again by company name.
	 */
	private static final String TEST_ADMIN_COMPANY = 'DML_Builder_TEST-admin';

	/**
	 * @description Company name given to the user created in test setup on the Minimum Access profile, the user a test
	 * runs as to act with very few permissions. It is unique to this class, so getLowPrivilegeUser can find that one user
	 * again by company name.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'DML_Builder_TEST-low-privilege';

	/**
	 * @description An email value the platform refuses with INVALID_EMAIL_ADDRESS.
	 */
	private static final String INVALID_EMAIL = 'not-a-valid-email';

	/**
	 * @description An external Id longer than the field's 50 characters, which the platform refuses with STRING_TOO_LONG.
	 */
	private static final String OVERLONG_EXTERNAL_ID = 'x'.repeat(60);

	/**
	 * @description The class-method the transaction logs its commit rows under.
	 */
	private static final String COMMIT_CLASS_METHOD = DML_Transaction.class.getName() + '.commitWork';

	/**
	 * @description The class-method the builder used to log its own entry under, before the engine
	 * became the single place a failed commit is recorded.
	 */
	private static final String EXECUTE_CLASS_METHOD = DML_Builder.class.getName() + '.execute';

	/**
	 * @description Assertion message for value equality checks.
	 */
	private static final String MSG_VALUE_EQUALITY = 'Value should match expected';

	/**
	 * @description The retry counts outside the accepted range, each of which the builder must refuse.
	 */
	private static final List<Integer> RETRIES_OUT_OF_RANGE = new List<Integer> {0, 6, null};

	/**
	 * @description The fragment of the refusal message that names the accepted range.
	 */
	private static final String RETRIES_RANGE_FRAGMENT = '1 to 5';

	/**
	 * @description The email on a row the test administrator owns, saved before a user with fewer rights tries to change it.
	 */
	private static final String SEEDED_EMAIL = 'seeded-by-owner@kerndx.test.invalid';

	/**
	 * @description The email a user with fewer rights tries to save. A test checks that this value is never saved and
	 * never written to a log.
	 */
	private static final String CHANGED_EMAIL = 'changed-by-restricted-user@kerndx.test.invalid';

	/**
	 * @description How many random letters and digits make up the external Id of a seeded row.
	 */
	private static final Integer EXTERNAL_ID_LENGTH = 20;

	/**
	 * @description The phone number given to each Account a test saves. Some orgs that install the package have their
	 * own rule that an Account needs a phone number or a website, so a saved Account carries one.
	 */
	private static final String ACCOUNT_PHONE = '555-0100';

	/**
	 * @description The industry given to each Account a test saves. Some orgs that install the package have their own
	 * rule that an Account needs an industry, so a saved Account carries one.
	 */
	private static final String ACCOUNT_INDUSTRY = 'Technology';

	/**
	 * @description The status code the platform gives when user mode refuses a save the user lacks a permission for. It
	 * is on the row when a user with no create or edit permission saves with allowPartial(), and on the DmlException when a user
	 * saves a field the user cannot create.
	 */
	private static final StatusCode USER_MODE_REFUSAL_STATUS = StatusCode.CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY;

	/**
	 * @description The status code the platform puts on the row when a user with no delete permission deletes a record
	 * in user mode with allowPartial().
	 */
	private static final StatusCode USER_MODE_DELETE_REFUSAL_STATUS = StatusCode.DELETE_FAILED;

	/**
	 * @description Object permissions that let a user read records and nothing else.
	 */
	private static final List<SObjectField> READ_PERMISSIONS = new List<SObjectField> {ObjectPermissions.PermissionsRead};

	/**
	 * @description The status code the platform gives when a child names its parent by a reference that holds no field,
	 * because the save left out the key the user cannot read.
	 */
	private static final StatusCode EMPTY_PARENT_REFERENCE_STATUS = StatusCode.INVALID_FIELD;

	/**
	 * @description The Foobar__c system fields that say who created and last changed a row, and when. No user can write
	 * them.
	 */
	private static final List<SObjectField> SYSTEM_AUDIT_FIELDS = new List<SObjectField>
	{
			Foobar__c.CreatedDate, Foobar__c.CreatedById, Foobar__c.LastModifiedDate, Foobar__c.LastModifiedById, Foobar__c.SystemModstamp
	};

	/**
	 * @description The other Foobar__c system fields that Salesforce fills in itself: whether the row is in the recycle
	 * bin, and when someone last logged an activity on it, viewed it or opened a page that refers to it. No user can
	 * write them.
	 */
	private static final List<SObjectField> OTHER_SYSTEM_FIELDS = new List<SObjectField>
	{
			Foobar__c.IsDeleted, Foobar__c.LastActivityDate, Foobar__c.LastViewedDate, Foobar__c.LastReferencedDate
	};

	/**
	 * @description The message of a save refusal built in Apex code, as a subscriber's own code could throw it. It does not carry
	 * the platform's row phrase, so the framework knows the exception holds no rows.
	 */
	private static final String APEX_BUILT_REFUSAL_MESSAGE = 'A trigger refused the save';

	/**
	 * @description The Foobar__c field whose value Salesforce works out itself: a formula field. No user can write it.
	 */
	private static final List<SObjectField> CALCULATED_FIELDS = new List<SObjectField> {Foobar__c.Formula__c};

	/**
	 * @description Where the warning about fields left out of a save is logged from: the class that keeps the user's
	 * permissions when a save ignores record sharing.
	 */
	private static final String FIELDS_LEFT_OUT_LOCATION = DML_SharingProxy.class.getName() + '.PermissionKeepingProxy';

	/**
	 * @description The start of the target of a bypass audit event for a save that ignores record sharing. The object
	 * name follows it, for example sharing:Account.
	 */
	private static final String SHARING_AUDIT_TARGET_PREFIX = 'sharing:';

	/**
	 * @description The start of the target of a bypass audit event for a save in system mode, which skips the user's
	 * object and field permissions. The object name follows it, for example system-mode:Account.
	 */
	private static final String SYSTEM_MODE_AUDIT_TARGET_PREFIX = 'system-mode:';

	/**
	 * @description In the warning about fields left out of a save, the text between an object name and the list of
	 * that object's fields, as in Account (Site).
	 */
	private static final String WARNING_FIELD_LIST_START = ' (';

	/**
	 * @description Object permissions that let a user read and edit records.
	 */
	private static final List<SObjectField> READ_EDIT_PERMISSIONS = new List<SObjectField> {ObjectPermissions.PermissionsRead, ObjectPermissions.PermissionsEdit};

	/**
	 * @description Object permissions that let a user read and create records.
	 */
	private static final List<SObjectField> READ_CREATE_PERMISSIONS = new List<SObjectField> {ObjectPermissions.PermissionsRead, ObjectPermissions.PermissionsCreate};

	/**
	 * @description A text value held as an Object, so a test can convert it to a number and get a TypeException at run time.
	 */
	private static final Object TEXT_THAT_IS_NOT_A_NUMBER = 'not a number';

	/**
	 * @description Object permissions that let a user read, create and edit records.
	 */
	private static final List<SObjectField> READ_CREATE_EDIT_PERMISSIONS = new List<SObjectField>
	{
			ObjectPermissions.PermissionsRead, ObjectPermissions.PermissionsCreate, ObjectPermissions.PermissionsEdit
	};

	/**
	 * @description Object permissions that let a user read, edit and delete records.
	 */
	private static final List<SObjectField> READ_EDIT_DELETE_PERMISSIONS = new List<SObjectField>
	{
			ObjectPermissions.PermissionsRead, ObjectPermissions.PermissionsEdit, ObjectPermissions.PermissionsDelete
	};

	/**
	 * @description Creates a dedicated test admin user so System.runAs in each test starts a fresh
	 * permission-evaluation context, bypassing the synthetic-org permission-cache staleness issue
	 * that affected mutating the running user's permissionSet mid-transaction. Also commits a
	 * low-privilege user (Minimum Access - Salesforce profile) so the tier-A regression test
	 * (shouldRejectAsyncUserModeUpdateForLowPrivilegeUser) can use System.runAs without triggering
	 * MIXED_DML_OPERATION — User is a Setup object, User DML cannot mix with standard/custom-object
	 * DML in the same transaction; pre-provisioning here satisfies that boundary.
	 */
	@TestSetup
	private static void setupTestUsers()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);

		User lowPrivilegeUser = TST_Factory.newMinimumAccessUser(LOW_PRIVILEGE_COMPANY);
		insert lowPrivilegeUser;
	}

	/**
	 * @description Tests all single-record DML operations (insert, update, upsert, delete, undelete).
	 */
	@IsTest
	private static void shouldPerformAllDmlOperationsSuccessfully()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(record)
					.execute();

			Assert.isNotNull(record.Id, 'Record should have an Id after insert');

			String updatedName = UTIL_Random.randomName();
			record.Name = updatedName;

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpdate(record)
					.execute();

			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(record.Id);
			Assert.areEqual(updatedName, found.Name, MSG_VALUE_EQUALITY);

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpsert(record)
					.execute();

			found = (Foobar__c)new SEL_Foobar().findById(record.Id);
			Assert.isNotNull(found, 'Record should exist after upsert');

			DML_Builder.newTransaction()
					.withSystemMode()
					.doDelete(record)
					.execute();

			found = (Foobar__c)new SEL_Foobar().findById(record.Id);
			Assert.isNull(found, 'Record should be deleted');

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUndelete(record)
					.execute();

			Test.stopTest();

			found = (Foobar__c)new SEL_Foobar().findById(record.Id);
			Assert.isNotNull(found, 'Record should be undeleted');
		}
	}

	/**
	 * @description Tests insert and update list overloads.
	 */
	@IsTest
	private static void shouldPerformListOperationsSuccessfully()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
					.withCount(3)
					.withoutInsertion()
					.buildList();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(records)
					.execute();

			for(SObject record : records)
			{
				Assert.isNotNull(record.Id, 'Record should have an Id');
			}

			String updatedName = UTIL_Random.randomName();
			for(SObject record : records)
			{
				((Foobar__c)record).Name = updatedName;
			}

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpdate(records)
					.execute();

			Test.stopTest();

			List<Foobar__c> found = new SEL_Foobar().getAll();
			Assert.areEqual(3, found.size(), MSG_VALUE_EQUALITY);
			for(Foobar__c foundRecord : found)
			{
				Assert.areEqual(updatedName, foundRecord.Name, MSG_VALUE_EQUALITY);
			}
		}
	}

	/**
	 * @description Tests that an empty transaction executes without error.
	 */
	@IsTest
	private static void shouldHandleEmptyTransactionWithoutError()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			DML_Builder.newTransaction().withSystemMode().execute();

			Test.stopTest();

			Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), 'No records should exist');
		}
	}

	/**
	 * @description Tests upsert with an external ID field.
	 */
	@IsTest
	private static void shouldUpsertWithExternalIdField()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.ExternalId__c, 'EXT-BUILDER-001')
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpsert(record, Foobar__c.ExternalId__c)
					.execute();

			Test.stopTest();

			Assert.isNotNull(record.Id, 'Record should have an Id after upsert');
			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(record.Id);
			Assert.areEqual('EXT-BUILDER-001', found.ExternalId__c, MSG_VALUE_EQUALITY);
		}
	}

	/**
	 * @description Tests upsert list overload with an external ID field.
	 */
	@IsTest
	private static void shouldUpsertListWithExternalIdField()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record1 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.ExternalId__c, 'EXT-LIST-001')
					.withoutInsertion()
					.build();

			Foobar__c record2 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.ExternalId__c, 'EXT-LIST-002')
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpsert(new List<SObject> {record1, record2}, Foobar__c.ExternalId__c)
					.execute();

			Test.stopTest();

			List<Foobar__c> found = new SEL_Foobar().getAll();
			Assert.areEqual(2, found.size(), MSG_VALUE_EQUALITY);
		}
	}

	/**
	 * @description Tests delete and undelete list overloads.
	 */
	@IsTest
	private static void shouldDeleteAndUndeleteList()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
					.withCount(2)
					.buildList();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doDelete(records)
					.execute();

			Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), 'Records should be deleted');

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUndelete(records)
					.execute();

			Test.stopTest();

			Assert.areEqual(2, new SEL_Foobar().getAll().size(), 'Records should be undeleted');
		}
	}

	/**
	 * @description Tests that allowPartial mode does not throw on partial failure.
	 */
	@IsTest
	private static void shouldAllowPartialSuccess()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c validRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(validRecord)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isNotNull(validRecord.Id, 'Valid record should have been inserted');
		}
	}

	/**
	 * @description Tests that bypassSharing allows DML for restricted users.
	 */
	@IsTest
	private static void shouldBypassSharingForInsert()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			record.Name = UTIL_Random.randomName();

			try
			{
				System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
				{
					Test.startTest();

					DML_Builder.newTransaction()
							.withSystemMode()
							.doUpdate(record)
							.bypassSharing()
							.execute();

					Test.stopTest();
				}
			}
			catch(Exception error)
			{
				Assert.fail('Sharing should have been bypassed: ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Tests that suppressLogging prevents error logging in partial mode.
	 */
	@IsTest
	private static void shouldSuppressLogging()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(record)
					.allowPartial()
					.suppressLogging()
					.execute();

			Test.stopTest();

			Assert.isNotNull(record.Id, 'Record should have been inserted');
		}
	}

	/**
	 * @description Verifies an all-or-nothing failure still throws and now leaves exactly one ERROR
	 * entry at the transaction's commit, where partial-mode failures already log.
	 */
	@IsTest
	private static void shouldLogAllOrNothingFailureOnce()
	{
		System.runAs(getTestAdmin())
		{
			captureLogEntries();
			Foobar__c refusedRecord = TST_Factory.newFoobarWithEmail(INVALID_EMAIL);

			Test.startTest();

			try
			{
				DML_Builder.newTransaction()
						.withSystemMode()
						.doInsert(refusedRecord)
						.execute();

				Assert.fail('Expected DmlException');
			}
			catch(DmlException error)
			{
				Assert.isTrue(error.getMessage().contains(String.valueOf(StatusCode.INVALID_EMAIL_ADDRESS)), 'Unexpected failure: ' + error.getMessage());
			}

			Test.stopTest();

			Assert.areEqual(1, countCommitRowsAt(LOG_Engine.LEVEL_ERROR), 'The all-or-nothing failure should log exactly once at ERROR at the commit');
			Assert.isNull(new SEL_LogEntry().findByMethod(EXECUTE_CLASS_METHOD), 'Nothing should log at the builder');
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(new SEL_LogEntry().findByMethod(COMMIT_CLASS_METHOD));
			Assert.isTrue(context == null || !context.containsKey(DML_Transaction.CONTEXT_KEY_RETRIES_USED), 'A commit that never asked for a retry should carry no retry context');
		}
	}

	/**
	 * @description Verifies suppressLogging() silences the all-or-nothing commit-failure entry while
	 * the exception still propagates.
	 */
	@IsTest
	private static void shouldSuppressAllOrNothingFailureLogging()
	{
		System.runAs(getTestAdmin())
		{
			captureLogEntries();
			Foobar__c refusedRecord = TST_Factory.newFoobarWithEmail(INVALID_EMAIL);

			Test.startTest();

			try
			{
				DML_Builder.newTransaction()
						.withSystemMode()
						.doInsert(refusedRecord)
						.suppressLogging()
						.execute();

				Assert.fail('Expected DmlException');
			}
			catch(DmlException error)
			{
				Assert.isTrue(error.getMessage().contains(String.valueOf(StatusCode.INVALID_EMAIL_ADDRESS)), 'Unexpected failure: ' + error.getMessage());
			}

			Test.stopTest();

			Assert.areEqual(0, countCommitRowsAt(LOG_Engine.LEVEL_ERROR), 'suppressLogging() should silence the commit-failure entry');
		}
	}

	/**
	 * @description Verifies a suppressed-exception failure produces exactly one ERROR entry, at the
	 * transaction's commit: the builder no longer writes a second entry of its own.
	 */
	@IsTest
	private static void shouldLogSuppressedExceptionFailureOnceAtCommit()
	{
		System.runAs(getTestAdmin())
		{
			captureLogEntries();
			Foobar__c refusedRecord = TST_Factory.newFoobarWithEmail(INVALID_EMAIL);

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(refusedRecord)
					.suppressExceptions()
					.execute();

			Test.stopTest();

			Assert.isNull(refusedRecord.Id, 'The failed insert should leave no Id');
			Assert.areEqual(1, countCommitRowsAt(LOG_Engine.LEVEL_ERROR), 'The failure should log exactly once, at the commit');
			Assert.isNull(new SEL_LogEntry().findByMethod(EXECUTE_CLASS_METHOD), 'The builder should no longer write its own entry');
		}
	}

	/**
	 * @description Verifies the fluent declaration: a refusal declared with expectRefusal() is logged at
	 * WARN by a partial commit, nothing at ERROR, and the result still counts the row as a failure.
	 */
	@IsTest
	private static void shouldLogExpectedRefusalAtWarn()
	{
		System.runAs(getTestAdmin())
		{
			captureLogEntries();
			Foobar__c savedRecord = TST_Factory.newFoobar();
			Foobar__c refusedRecord = TST_Factory.newFoobarWithEmail(INVALID_EMAIL);

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(new List<SObject> {savedRecord, refusedRecord})
					.allowPartial()
					.expectRefusal(StatusCode.INVALID_EMAIL_ADDRESS)
					.execute();

			Test.stopTest();

			Assert.isFalse(result.isSuccess(), 'The refused row should still make the result unsuccessful');
			Assert.areEqual(1, result.getSuccessCount(), 'The valid row should count as a success');
			Assert.areEqual(1, result.getInsertedIds().size(), 'The valid row should be returned as inserted');
			Assert.areEqual(1, result.getFailureCount(), 'The refused row should still count as a failure');
			Assert.areEqual(1, result.getErrors().size(), 'The refusal should still be returned as an error');
			Assert.areEqual(1, countCommitRowsAt(LOG_Engine.LEVEL_WARN), 'The expected refusal should be logged once at WARN');
			Assert.areEqual(0, countCommitRowsAt(LOG_Engine.LEVEL_ERROR), 'Nothing should be logged at ERROR');
		}
	}

	/**
	 * @description Verifies that repeated declarations accumulate: a code declared on the first call is
	 * still honoured after a second call.
	 */
	@IsTest
	private static void shouldAccumulateExpectedRefusals()
	{
		System.runAs(getTestAdmin())
		{
			captureLogEntries();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(TST_Factory.newFoobarWithEmail(INVALID_EMAIL))
					.allowPartial()
					.expectRefusal(StatusCode.INVALID_EMAIL_ADDRESS)
					.expectRefusal(StatusCode.DUPLICATE_VALUE)
					.execute();

			Test.stopTest();

			Assert.areEqual(1, countCommitRowsAt(LOG_Engine.LEVEL_WARN), 'A code declared before another should still be honoured');
		}
	}

	/**
	 * @description Verifies that a null status code is rejected before it can silently declare nothing.
	 */
	@IsTest
	private static void shouldRejectNullExpectedRefusal()
	{
		System.runAs(getTestAdmin())
		{
			DML_Builder builder = DML_Builder.newTransaction();

			try
			{
				builder.expectRefusal(null);
				Assert.fail('A null status code should be rejected');
			}
			catch(Exception caughtException)
			{
				Assert.isInstanceOfType(caughtException, IllegalArgumentException.class, 'A null status code should raise IllegalArgumentException');
			}

			Assert.isTrue(builder.expectedRefusalStatusCodes.isEmpty(), 'A rejected declaration should leave the builder unchanged');
		}
	}

	/**
	 * @description Verifies the two members return the builder and that a count outside 1 to 5, or null, raises
	 * IllegalArgumentException, like expectRefusal does on null.
	 */
	@IsTest
	private static void withRetryOnLockShouldReturnTheBuilderAndRefuseCountsOutOfRange()
	{
		DML_Builder builder = DML_Builder.newTransaction();

		Assert.areEqual(builder, builder.withRetryOnLock(), 'The no-argument member should return the builder');
		Assert.areEqual(builder, builder.withRetryOnLock(5), 'The ceiling should be accepted');

		for(Integer retries : RETRIES_OUT_OF_RANGE)
		{
			try
			{
				builder.withRetryOnLock(retries);
				Assert.fail('A count of ' + retries + ' should raise IllegalArgumentException');
			}
			catch(IllegalArgumentException error)
			{
				Assert.isTrue(error.getMessage().contains(RETRIES_RANGE_FRAGMENT), 'The refusal should name the accepted range');
			}
		}
	}

	/**
	 * @description Verifies the dial end to end through the builder with the count it was given: a commit refused
	 * twice for a row lock saves on its third attempt, which the default of one retry could not do, and the result
	 * reports success.
	 */
	@IsTest
	private static void withRetryOnLockShouldRecoverASynchronousCommit()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.newFoobar();
			DML_SharingProxy.sharingProxyForTest = new DML_ThrowingLockProxy_TEST(2);
			DML_Builder.TransactionResult result;

			try
			{
				Test.startTest();
				result = DML_Builder.newTransaction().withSystemMode().doInsert(record).withRetryOnLock(2).execute();
				Test.stopTest();
			}
			finally
			{
				DML_SharingProxy.sharingProxyForTest = null;
			}

			Assert.isTrue(result.isSuccess(), 'The commit should succeed on its third attempt');
			Assert.areEqual(1, result.getInsertedIds().size(), 'The row should be inserted once');
			Assert.isNotNull(new SEL_Foobar().findById(record.Id), 'The row should exist');
		}
	}

	/**
	 * @description A save refused by a DmlException built in Apex code, which holds no failed rows, counts every record in the save
	 * as failed, because the whole save was rolled back. Asking such an exception for its rows would end the transaction.
	 */
	@IsTest
	private static void getFailureCountShouldCountEveryRecordWhenTheRefusalHoldsNoRows()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = new List<Foobar__c> {TST_Factory.newFoobar(), TST_Factory.newFoobar()};
			DML_SharingProxy.sharingProxyForTest = new DML_ThrowingLockProxy_TEST(1, APEX_BUILT_REFUSAL_MESSAGE);
			DML_Builder.TransactionResult result;

			try
			{
				Test.startTest();
				result = DML_Builder.newTransaction().withSystemMode().doInsert(records).suppressExceptions().execute();
				Test.stopTest();
			}
			finally
			{
				DML_SharingProxy.sharingProxyForTest = null;
			}

			Assert.isFalse(result.isSuccess(), 'Expected the refused save to report a failure');
			Assert.areEqual(records.size(), result.getFailureCount(), 'Expected every record in the refused save to count as failed');
		}
	}

	/**
	 * @description Verifies the no-argument member retries exactly once: a commit refused twice is not recovered,
	 * and with exceptions suppressed the builder reports the failure.
	 */
	@IsTest
	private static void withRetryOnLockShouldRetryOnceByDefault()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.newFoobar();
			DML_SharingProxy.sharingProxyForTest = new DML_ThrowingLockProxy_TEST(2);
			DML_Builder.TransactionResult result;

			try
			{
				Test.startTest();
				result = DML_Builder.newTransaction().withSystemMode().doInsert(record).withRetryOnLock().suppressExceptions().execute();
				Test.stopTest();
			}
			finally
			{
				DML_SharingProxy.sharingProxyForTest = null;
			}

			Assert.isFalse(result.isSuccess(), 'One retry should not recover a commit refused twice');
			Assert.isNull(record.Id, 'The row should not be saved');
		}
	}

	/**
	 * @description Tests that suppressExceptions prevents DmlException from being thrown.
	 */
	@IsTest
	private static void shouldSuppressExceptionOnFailure()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpdate(record)
					.suppressExceptions()
					.execute();

			Test.stopTest();

			Assert.isNull(record.Id, 'Record should not have an Id');
		}
	}

	/**
	 * @description Tests that default all-or-nothing mode throws DmlException on failure.
	 */
	@IsTest
	private static void shouldThrowByDefault()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			try
			{
				DML_Builder.newTransaction()
						.withSystemMode()
						.doUpdate(record)
						.execute();

				Assert.fail('Expected DmlException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests chaining doInsert and doUpdate operations.
	 */
	@IsTest
	private static void shouldExecuteChainedInsertAndUpdate()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c insertRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c existingRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			String updatedName = UTIL_Random.randomName();
			existingRecord.Name = updatedName;

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(insertRecord)
					.doUpdate(existingRecord)
					.execute();

			Test.stopTest();

			Assert.isNotNull(insertRecord.Id, 'Inserted record should have an Id');
			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(existingRecord.Id);
			Assert.areEqual(updatedName, found.Name, MSG_VALUE_EQUALITY);
		}
	}

	/**
	 * @description Tests chaining parent and child inserts with a relationship field.
	 */
	@IsTest
	private static void shouldExecuteChainedParentChildInsert()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c child = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(parent)
					.doInsert(child, Foobar__c.Lookup__c, parent)
					.execute();

			Test.stopTest();

			Assert.isNotNull(parent.Id, 'Parent should have an Id');
			Foobar__c foundChild = (Foobar__c)new SEL_Foobar().findById(child.Id);
			Assert.areEqual(parent.Id, foundChild.Lookup__c, MSG_VALUE_EQUALITY);
		}
	}

	/**
	 * @description Tests chained operations with bypass sharing.
	 */
	@IsTest
	private static void shouldExecuteChainedWithBypassSharing()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record1 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c record2 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			try
			{
				System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
				{
					Test.startTest();

					DML_Builder.newTransaction()
							.withSystemMode()
							.doInsert(record1)
							.doInsert(record2)
							.bypassSharing()
							.execute();

					Test.stopTest();
				}
			}
			catch(Exception error)
			{
				Assert.fail('Sharing should have been bypassed: ' + error.getMessage());
			}

			Assert.isNotNull(record1.Id, 'Record 1 should have an Id');
			Assert.isNotNull(record2.Id, 'Record 2 should have an Id');
		}
	}

	/**
	 * @description Tests chained operations with partial success mode.
	 */
	@IsTest
	private static void shouldExecuteChainedWithPartialSuccess()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c insertRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c updateRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			updateRecord.Name = UTIL_Random.randomName();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(insertRecord)
					.doUpdate(updateRecord)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isNotNull(insertRecord.Id, 'Inserted record should have an Id');
		}
	}

	/**
	 * @description Tests doUpsert list overload without an external ID field.
	 */
	@IsTest
	private static void shouldUpsertListWithoutExternalIdField()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
					.withCount(2)
					.withoutInsertion()
					.buildList();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpsert(records)
					.execute();

			Test.stopTest();

			List<Foobar__c> found = new SEL_Foobar().getAll();
			Assert.areEqual(2, found.size(), MSG_VALUE_EQUALITY);
		}
	}

	/**
	 * @description Tests that a chained transaction throws DmlException on failure.
	 */
	@IsTest
	private static void shouldThrowOnChainedFailure()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c validRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c invalidRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			try
			{
				DML_Builder.newTransaction()
						.withSystemMode()
						.doInsert(validRecord)
						.doUpdate(invalidRecord)
						.execute();

				Assert.fail('Expected DmlException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Tests chained upsert without external ID routes through transaction path.
	 */
	@IsTest
	private static void shouldExecuteChainedUpsertWithoutExternalId()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record1 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c record2 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(record1)
					.doUpsert(record2)
					.execute();

			Test.stopTest();

			Assert.isNotNull(record1.Id, 'Record 1 should have an Id');
			Assert.isNotNull(record2.Id, 'Record 2 should have an Id');
		}
	}

	/**
	 * @description Tests suppressExceptions in a chained transaction path.
	 */
	@IsTest
	private static void shouldSuppressExceptionOnChainedFailure()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c validRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c invalidRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(validRecord)
					.doUpdate(invalidRecord)
					.suppressExceptions()
					.execute();

			Test.stopTest();

			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(validRecord.Id);
			Assert.isNull(found, 'Insert should have been rolled back');
		}
	}

	/**
	 * @description Tests chained undelete operation in the transaction path.
	 */
	@IsTest
	private static void shouldExecuteChainedWithUndelete()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record1 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			TST_Builder.of(Foobar__c.SObjectType).build();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doDelete(record1)
					.execute();

			Foobar__c record3 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(record3)
					.doUndelete(record1)
					.execute();

			Test.stopTest();

			Assert.isNotNull(record3.Id, 'New record should have an Id');
			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(record1.Id);
			Assert.isNotNull(found, 'Record should be undeleted');
		}
	}

	/**
	 * @description Tests chained undelete with bypass sharing in the transaction path.
	 */
	@IsTest
	private static void shouldExecuteChainedUndeleteWithBypassSharing()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doDelete(record)
					.execute();

			Foobar__c insertRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(insertRecord)
					.doUndelete(record)
					.bypassSharing()
					.execute();

			Test.stopTest();

			Assert.isNotNull(insertRecord.Id, 'New record should have an Id');
		}
	}

	/**
	 * @description Tests chained delete in the transaction path.
	 */
	@IsTest
	private static void shouldExecuteChainedWithDelete()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record1 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			Foobar__c record2 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(record2)
					.doDelete(record1)
					.execute();

			Test.stopTest();

			Assert.isNotNull(record2.Id, 'Inserted record should have an Id');
			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(record1.Id);
			Assert.isNull(found, 'Deleted record should not exist');
		}
	}

	/**
	 * @description Tests chained upsert with external ID in the transaction path.
	 */
	@IsTest
	private static void shouldExecuteChainedUpsertWithExternalId()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record1 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c record2 = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.ExternalId__c, 'EXT-CHAINED-001')
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(record1)
					.doUpsert(record2, Foobar__c.ExternalId__c)
					.execute();

			Test.stopTest();

			Assert.isNotNull(record1.Id, 'Inserted record should have an Id');
			Assert.isNotNull(record2.Id, 'Upserted record should have an Id');
		}
	}

	/**
	 * @description Tests async insert via DML_AsyncBuilder.
	 */
	@IsTest
	private static void shouldInsertRecordsAsynchronously()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.newFoobars(5);

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(records)
					.async()
					.execute();

			Test.stopTest();

			Assert.areEqual(5, new SEL_Foobar().getAll().size(), 'Should have inserted 5 records asynchronously');
		}
	}

	/**
	 * @description Tests async delete via DML_AsyncBuilder.
	 */
	@IsTest
	private static void shouldDeleteRecordsAsynchronously()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(5);

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doDelete(records)
					.async()
					.execute();

			Test.stopTest();

			Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), 'All records should be deleted asynchronously');
		}
	}

	/**
	 * @description Tests async update with partial success via DML_AsyncBuilder.
	 */
	@IsTest
	private static void shouldUpdateRecordsAsynchronouslyWithPartialSuccess()
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

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpdate(records)
					.allowPartial()
					.async()
					.execute();

			Test.stopTest();

			List<Foobar__c> updatedRecords = new SEL_Foobar().getAll();
			for(Foobar__c record : updatedRecords)
			{
				Assert.areEqual(testDateTime, record.Datetime__c, MSG_VALUE_EQUALITY);
			}
		}
	}

	/**
	 * @description Proves a refusal declared before the switch to a background job still logs at WARN when
	 * the job commits it, while an undeclared refusal in the same job still logs at ERROR, so a caller who
	 * declared one refusal on the synchronous side is not handed an ERROR row it already accounted for and
	 * loses no visibility of the refusals it did not declare.
	 */
	@IsTest
	private static void shouldApplyExpectedRefusalOnTheAsyncLeg()
	{
		System.runAs(getTestAdmin())
		{
			captureLogEntries();
			Foobar__c savedRecord = TST_Factory.newFoobar();
			Foobar__c refusedRecord = TST_Factory.newFoobarWithEmail(INVALID_EMAIL);
			Foobar__c refusedByLength = TST_Factory.newFoobar();
			refusedByLength.ExternalId__c = OVERLONG_EXTERNAL_ID;

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(new List<SObject> {savedRecord, refusedRecord, refusedByLength})
					.allowPartial()
					.expectRefusal(StatusCode.INVALID_EMAIL_ADDRESS)
					.async()
					.execute();

			Test.stopTest();

			Assert.areEqual(1, new SEL_Foobar().getAll().size(), 'The valid row should be saved by the job');
			Assert.areEqual(1, countCommitRowsAt(LOG_Engine.LEVEL_WARN), 'The job should log the expected refusal at WARN');
			Assert.areEqual(1, countCommitRowsAt(LOG_Engine.LEVEL_ERROR), 'The job should log the undeclared refusal at ERROR');
		}
	}

	/**
	 * @description Verifies the dial crosses the async hand-off with its count: the job's batch is refused twice for a
	 * row lock and recovers on its third attempt, so the row exists after the job runs.
	 */
	@IsTest
	private static void withRetryOnLockShouldCrossTheAsyncHandOff()
	{
		System.runAs(getTestAdmin())
		{
			captureLogEntries();
			Foobar__c record = TST_Factory.newFoobar();
			DML_SharingProxy.sharingProxyForTest = new DML_ThrowingLockProxy_TEST(2);

			try
			{
				Test.startTest();
				DML_Builder.newTransaction().withSystemMode().doInsert(record).withRetryOnLock(2).async().execute();
				Test.stopTest();
			}
			finally
			{
				DML_SharingProxy.sharingProxyForTest = null;
			}

			Assert.areEqual(1, new SEL_Foobar().getAll().size(), 'The job should save the row on its third attempt');
			Assert.areEqual(1, countCommitRowsAt(LOG_Engine.LEVEL_WARN), 'The job should log the retry once at WARN');
			Assert.areEqual(0, countCommitRowsAt(LOG_Engine.LEVEL_ERROR), 'Nothing should be logged at ERROR');
		}
	}

	/**
	 * @description Tests async DML with batch size override.
	 */
	@IsTest
	private static void shouldExecuteAsyncWithBatchSize()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> records = TST_Factory.insertFoobars(5);

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doDelete(records)
					.async()
					.withBatchSize(2)
					.execute();

			Test.stopTest();

			Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), 'All records should be deleted asynchronously with batch size');
		}
	}

	/**
	 * @description Tests that async with no operations is a no-op.
	 */
	@IsTest
	private static void shouldHandleEmptyAsyncOperations()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.async()
					.execute();

			Test.stopTest();

			Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), 'No records should exist after empty async execution');
		}
	}

	/**
	 * @description Tests that execute returns a success result with correct inserted IDs.
	 */
	@IsTest
	private static void shouldReturnSuccessResultWithInsertedIds()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
					.withCount(3)
					.withoutInsertion()
					.buildList();

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(records)
					.execute();

			Test.stopTest();

			Assert.isTrue(result.isSuccess(), 'Transaction should be successful');
			Assert.areEqual(3, result.getInsertedIds().size(), 'Should have 3 inserted IDs');
			Assert.areEqual(3, result.getSuccessCount(), 'Should have 3 successes');
			Assert.areEqual(0, result.getFailureCount(), 'Should have 0 failures');
			Assert.isTrue(result.getErrors().isEmpty(), 'Should have no errors');
		}
	}

	/**
	 * @description Tests that execute returns a result reflecting partial failures.
	 */
	@IsTest
	private static void shouldReturnPartialResultWithErrors()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c validRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Foobar__c invalidRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Email__c, 'not-a-valid-email')
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(new List<SObject> {validRecord, invalidRecord})
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isFalse(result.isSuccess(), 'Transaction should not be fully successful');
			Assert.areEqual(1, result.getInsertedIds().size(), 'Should have 1 inserted ID');
			Assert.areEqual(1, result.getSuccessCount(), 'Should have 1 success');
			Assert.areEqual(1, result.getFailureCount(), 'Should have 1 failure');
			Assert.isFalse(result.getErrors().isEmpty(), 'Should have errors');
		}
	}

	/**
	 * @description Tests that an empty transaction returns a success result.
	 */
	@IsTest
	private static void shouldReturnSuccessResultForEmptyTransaction()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction().withSystemMode().execute();

			Test.stopTest();

			Assert.isTrue(result.isSuccess(), 'Empty transaction should be successful');
			Assert.isTrue(result.getInsertedIds().isEmpty(), 'Should have no inserted IDs');
			Assert.areEqual(0, result.getSuccessCount(), 'Should have 0 successes');
			Assert.areEqual(0, result.getFailureCount(), 'Should have 0 failures');
		}
	}

	/**
	 * @description Tests that a suppressed exception returns a failure result.
	 */
	@IsTest
	private static void shouldReturnFailureResultWhenExceptionSuppressed()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doUpdate(record)
					.suppressExceptions()
					.execute();

			Test.stopTest();

			Assert.isFalse(result.isSuccess(), 'Transaction should not be successful');
			Assert.areEqual(0, result.getSuccessCount(), 'Should have 0 successes when DML exception occurred');
			Assert.isTrue(result.getFailureCount() > 0, 'Should have failures');
		}
	}

	/**
	 * @description Tests that execute returns a success result for mixed insert and update operations.
	 */
	@IsTest
	private static void shouldReturnSuccessResultForMixedOperations()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c existingRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			existingRecord.Name = UTIL_Random.randomName();

			Foobar__c newRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doInsert(newRecord)
					.doUpdate(existingRecord)
					.execute();

			Test.stopTest();

			Assert.isTrue(result.isSuccess(), 'Transaction should be successful');
			Assert.areEqual(1, result.getInsertedIds().size(), 'Should have 1 inserted ID');
			Assert.areEqual(2, result.getSuccessCount(), 'Should have 2 successes');
		}
	}

	/**
	 * @description Tests TransactionResult error and failure metrics for a partial update failure.
	 */
	@IsTest
	private static void shouldReturnErrorsForPartialUpdateFailure()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			record.Email__c = 'not-a-valid-email';

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doUpdate(record)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isFalse(result.getErrors().isEmpty(), 'Should have errors for invalid update');
			Assert.areEqual(1, result.getFailureCount(), 'Should have 1 failure');
		}
	}

	/**
	 * @description Tests TransactionResult error and failure metrics for a partial upsert failure.
	 */
	@IsTest
	private static void shouldReturnErrorsForPartialUpsertFailure()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			record.Email__c = 'not-a-valid-email';

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doUpsert(record)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isFalse(result.getErrors().isEmpty(), 'Should have errors for invalid upsert');
			Assert.areEqual(1, result.getFailureCount(), 'Should have 1 failure');
		}
	}

	/**
	 * @description Tests TransactionResult error and failure metrics for a partial delete failure.
	 */
	@IsTest
	private static void shouldReturnErrorsForPartialDeleteFailure()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			delete record;

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doDelete(record)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isFalse(result.getErrors().isEmpty(), 'Should have errors for deleting already-deleted record');
			Assert.areEqual(1, result.getFailureCount(), 'Should have 1 failure');
		}
	}

	/**
	 * @description Tests TransactionResult error and failure metrics for a partial undelete failure.
	 */
	@IsTest
	private static void shouldReturnErrorsForPartialUndeleteFailure()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doUndelete(record)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isFalse(result.getErrors().isEmpty(), 'Should have errors for undeleting active record');
			Assert.areEqual(1, result.getFailureCount(), 'Should have 1 failure');
		}
	}

	/**
	 * @description Tests TransactionResult methods after an update operation with allowPartial.
	 */
	@IsTest
	private static void shouldReturnResultMetricsForUpdateOperation()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			record.Name = UTIL_Random.randomName();

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doUpdate(record)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isTrue(result.isSuccess(), 'Transaction should be successful');
			Assert.areEqual(1, result.getSuccessCount(), 'Should have 1 success');
			Assert.areEqual(0, result.getFailureCount(), 'Should have 0 failures');
			Assert.isTrue(result.getErrors().isEmpty(), 'Should have no errors');
		}
	}

	/**
	 * @description Tests TransactionResult methods after an upsert operation with allowPartial.
	 */
	@IsTest
	private static void shouldReturnResultMetricsForUpsertOperation()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withoutInsertion()
					.build();

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doUpsert(record)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isTrue(result.isSuccess(), 'Transaction should be successful');
			Assert.areEqual(1, result.getSuccessCount(), 'Should have 1 success');
			Assert.areEqual(0, result.getFailureCount(), 'Should have 0 failures');
			Assert.isTrue(result.getErrors().isEmpty(), 'Should have no errors');
		}
	}

	/**
	 * @description Tests TransactionResult methods after a delete operation with allowPartial.
	 */
	@IsTest
	private static void shouldReturnResultMetricsForDeleteOperation()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doDelete(record)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isTrue(result.isSuccess(), 'Transaction should be successful');
			Assert.areEqual(1, result.getSuccessCount(), 'Should have 1 success');
			Assert.areEqual(0, result.getFailureCount(), 'Should have 0 failures');
			Assert.isTrue(result.getErrors().isEmpty(), 'Should have no errors');
		}
	}

	/**
	 * @description Tests TransactionResult methods after an undelete operation with allowPartial.
	 */
	@IsTest
	private static void shouldReturnResultMetricsForUndeleteOperation()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
			delete record;

			Test.startTest();

			DML_Builder.TransactionResult result = DML_Builder.newTransaction()
					.withSystemMode()
					.doUndelete(record)
					.allowPartial()
					.execute();

			Test.stopTest();

			Assert.isTrue(result.isSuccess(), 'Transaction should be successful');
			Assert.areEqual(1, result.getSuccessCount(), 'Should have 1 success');
			Assert.areEqual(0, result.getFailureCount(), 'Should have 0 failures');
			Assert.isTrue(result.getErrors().isEmpty(), 'Should have no errors');
		}
	}

	/**
	 * @description Flag disabled: DML_SharingProxy.defaultAccessLevel() returns SYSTEM_MODE.
	 */
	@IsTest
	private static void shouldDefaultDmlToSystemModeWhenFlagDisabled()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true, false);

			Assert.areEqual(AccessLevel.SYSTEM_MODE, DML_SharingProxy.defaultAccessLevel(), 'DML default must be SYSTEM_MODE when flag is disabled');
		}
	}

	/**
	 * @description Flag enabled: DML_SharingProxy.defaultAccessLevel() returns USER_MODE.
	 */
	@IsTest
	private static void shouldDefaultDmlToUserModeWhenFlagEnabled()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

			Assert.areEqual(AccessLevel.USER_MODE, DML_SharingProxy.defaultAccessLevel(), 'DML default must be USER_MODE when flag is enabled');
		}
	}

	/**
	 * @description `.withSystemMode()` overrides a flag-driven USER_MODE default.
	 */
	@IsTest
	private static void shouldLetDmlBuilderWithSystemModeOverrideFlag()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

			DML_Builder builder = DML_Builder.newTransaction().withSystemMode();

			Assert.areEqual(AccessLevel.SYSTEM_MODE, builder.resolvedAccessLevel(), '.withSystemMode() must force SYSTEM_MODE regardless of flag');
		}
	}

	/**
	 * @description `.withUserMode()` overrides a flag-driven SYSTEM_MODE default.
	 */
	@IsTest
	private static void shouldLetDmlBuilderWithUserModeOverrideFlag()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true, false);

			DML_Builder builder = DML_Builder.newTransaction().withUserMode();

			Assert.areEqual(AccessLevel.USER_MODE, builder.resolvedAccessLevel(), '.withUserMode() must force USER_MODE regardless of flag');
		}
	}

	/**
	 * @description Neither explicit method called → builder resolves to flag-driven default.
	 */
	@IsTest
	private static void shouldResolveToFlagDefaultWhenNoExplicitCall()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

			DML_Builder builder = DML_Builder.newTransaction();

			Assert.areEqual(AccessLevel.USER_MODE, builder.resolvedAccessLevel(), 'resolvedAccessLevel() must return flag-driven default when no explicit call');
		}
	}

	/**
	 * @description Tier-A — regression gate for BUG 1. Proves that
	 * DML_Builder.newTransaction().doUpdate(...).withUserMode().async().execute() honours the
	 * explicit USER_MODE even in the async Queueable path. A low-privilege user (Minimum
	 * Access - Salesforce) who lacks FLS on Foobar__c attempts to async-update a Foobar__c
	 * record seeded by admin. Because the builder-chain explicitly calls .withUserMode(), the
	 * framework must propagate AccessLevel.USER_MODE through DML_AsyncBuilder → PROC_ExecuteDML,
	 * the queueable's DML must evaluate FLS against the running user, and the update must be
	 * rejected (the seeded value is preserved).
	 *
	 * The `UserModeDml_Enabled` flag is forced OFF so the rejection can only come from the
	 * explicitly threaded USER_MODE dial: with the flag OFF the flag-driven default is
	 * SYSTEM_MODE, so a framework that drops the dial across the async hand-off writes the
	 * record and fails this test. (Before the flag was forced, the test passed for the wrong reason: the
	 * dropped dial coincided with the flag-ON default.)
	 *
	 * Catches: a regression that re-hard-codes .withSystemMode() inside PROC_ExecuteDML.execute()
	 * (the bug commit f22a88d fixed) — the low-privilege user's update would silently succeed,
	 * violating the framework's "global API contract" promise that .withUserMode() means USER_MODE
	 * end-to-end.
	 *
	 * @see DML_Builder.async
	 * @see PROC_ExecuteDML.execute
	 */
	@IsTest
	private static void shouldRejectAsyncUserModeUpdateForLowPrivilegeUser()
	{
		final String originalEmail = 'seeded-admin@kerndx.test.invalid';
		final String attemptedEmail = 'mutated-low-privilege@kerndx.test.invalid';
		Foobar__c seededRecord;

		System.runAs(getTestAdmin())
		{
			seededRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Email__c, originalEmail)
					.build();
		}

		System.runAs(getLowPrivilegeUser())
		{
			TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true, false);

			seededRecord.Email__c = attemptedEmail;

			Test.startTest();

			DML_Builder.newTransaction()
					.withUserMode()
					.doUpdate(seededRecord)
					.allowPartial()
					.suppressExceptions()
					.async()
					.execute();

			Test.stopTest();
		}

		System.runAs(getTestAdmin())
		{
			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(seededRecord.Id);

			Assert.areEqual(originalEmail, found.Email__c, 'USER_MODE async update must be rejected for low-privilege user — Email__c should be unchanged');
		}
	}

	/**
	 * @description Proves the audited SYSTEM_MODE elevation and the `.bypassSharing()` dial BOTH
	 * survive the async hand-off. A low-privilege user with no access to an admin-owned
	 * Foobar__c (Private OWD) runs `.withSystemMode().bypassSharing().doUpdate(...).async()`:
	 * SYSTEM_MODE must reach the queueable's DML (waiving CRUD/FLS for the low-privilege user)
	 * and the bypass must select the without-sharing proxy, so the unshared write lands. The
	 * `UserModeDml_Enabled` flag is forced ON (the direction that enforces too much), so a framework
	 * that drops the dials falls back to USER_MODE, CRUD-rejects the write, and fails this test.
	 *
	 * @see DML_Builder.bypassSharing
	 * @see DML_Builder.async
	 * @see PROC_ExecuteDML.execute
	 */
	@IsTest
	private static void shouldHonourBypassSharingOnAsyncSystemModeUpdate()
	{
		final String originalEmail = 'seeded-bypass-async@kerndx.test.invalid';
		final String attemptedEmail = 'written-via-bypass-async@kerndx.test.invalid';
		Foobar__c seededRecord;

		System.runAs(getTestAdmin())
		{
			seededRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Email__c, originalEmail)
					.build();
		}

		System.runAs(getLowPrivilegeUser())
		{
			TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

			seededRecord.Email__c = attemptedEmail;

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.bypassSharing()
					.doUpdate(seededRecord)
					.async()
					.execute();

			Test.stopTest();
		}

		System.runAs(getTestAdmin())
		{
			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(seededRecord.Id);

			Assert.areEqual(attemptedEmail, found.Email__c,
					'SYSTEM_MODE + .bypassSharing() async update must land for a low-privilege user — the audited elevation and the bypass dial must survive the async hand-off');
		}
	}

	/**
	 * @description Proves a SYSTEM_MODE async write WITHOUT `.bypassSharing()` is rejected by
	 * record sharing. Under SYSTEM_MODE the Database API waives CRUD/FLS entirely, so sharing is
	 * the only control that can reject the write. The bypass sibling test landing under the
	 * identical configuration proves the record is otherwise writable. The `UserModeDml_Enabled`
	 * flag is forced OFF (the direction that discloses too much), so a framework that drops the dials resolves
	 * the flag-driven SYSTEM_MODE default inside a without-sharing frame, silently writes the
	 * unshared record, and fails this test.
	 *
	 * @see DML_Builder.async
	 * @see PROC_ExecuteDML.execute
	 */
	@IsTest
	private static void shouldEnforceSharingOnAsyncSystemModeUpdateWithoutBypass()
	{
		final String originalEmail = 'seeded-enforce-async@kerndx.test.invalid';
		final String attemptedEmail = 'blocked-by-sharing-async@kerndx.test.invalid';
		Foobar__c seededRecord;

		System.runAs(getTestAdmin())
		{
			seededRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Email__c, originalEmail)
					.build();
		}

		System.runAs(getLowPrivilegeUser())
		{
			TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true, false);

			seededRecord.Email__c = attemptedEmail;

			Test.startTest();

			DML_Builder.newTransaction()
					.withSystemMode()
					.doUpdate(seededRecord)
					.allowPartial()
					.async()
					.execute();

			Test.stopTest();
		}

		System.runAs(getTestAdmin())
		{
			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(seededRecord.Id);

			Assert.areEqual(originalEmail, found.Email__c, 'SYSTEM_MODE async update without .bypassSharing() must be rejected by record sharing — Email__c should be unchanged');
		}
	}

	/**
	 * @description Verifies the pre-execute row-count guard fires when total registered
	 * records exceed Salesforce's per-transaction DML row limit. Without the guard the
	 * platform raises an uncatchable `System.LimitException` mid-commit; the framework
	 * converts that into a `UTIL_Exceptions.IllegalStateException` thrown BEFORE any DML
	 * runs so subscribers can catch it and split the work. Uses the `maxDmlRowsForTest`
	 * `@TestVisible` test setting to drive the guard with 6 records instead of 10,001, keeping
	 * the test body well under the synchronous-CPU governor budget.
	 */
	@IsTest
	private static void shouldRejectTransactionExceedingPlatformDmlRowLimit()
	{
		DML_Builder.maxDmlRowsForTest = 5;
		Integer overflowCount = DML_Builder.maxDmlRowsForTest + 1;
		List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(overflowCount)
				.withoutInsertion()
				.buildList();

		try
		{
			DML_Builder.newTransaction().doInsert(records).execute();
			Assert.fail('Pre-execute guard should have thrown for ' + overflowCount + ' rows');
		}
		catch(UTIL_Exceptions.IllegalStateException expected)
		{
			Assert.isTrue(
					expected.getMessage().contains(String.valueOf(overflowCount)),
					'Exception message should report the actual row count. Got: ' + expected.getMessage());
			Assert.isTrue(
					expected.getMessage().contains('.async()'),
					'Exception message should suggest .async() as the remediation. Got: ' + expected.getMessage());
		}
	}

	/**
	 * @description Verifies the pre-execute row-count guard does NOT fire at the boundary
	 * (exactly the configured limit). Catches off-by-one regressions in the comparison
	 * operator (`>` vs `>=`). Uses the `maxDmlRowsForTest` test setting to keep the test fast.
	 * Any post-guard exception (e.g. unrelated platform error during the actual insert)
	 * is allowed to propagate. The test only verifies the framework guard let the work
	 * through.
	 */
	@IsTest
	private static void shouldAllowTransactionAtExactPlatformDmlRowLimit()
	{
		DML_Builder.maxDmlRowsForTest = 5;
		List<SObject> records = TST_Builder.of(Foobar__c.SObjectType)
				.withCount(DML_Builder.maxDmlRowsForTest)
				.withoutInsertion()
				.buildList();

		try
		{
			DML_Builder.newTransaction().doInsert(records).execute();
		}
		catch(UTIL_Exceptions.IllegalStateException unexpected)
		{
			Assert.fail('Row-count guard must NOT fire at exactly the limit. Got: ' + unexpected.getMessage());
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

	/**
	 * @description Counts the rows the transaction's commit logged at the given level, leaving aside the bypass
	 * audit rows that withSystemMode() writes under the test method's own name.
	 *
	 * @param loggingLevel The level to count
	 *
	 * @return The number of commit rows logged at that level
	 */
	private static Integer countCommitRowsAt(String loggingLevel)
	{
		Integer rowCount = 0;

		for(LogEntry__c entry : new SEL_LogEntry().findAllByMethod(COMMIT_CLASS_METHOD))
		{
			if(entry.LogLevel__c == loggingLevel)
			{
				rowCount++;
			}
		}

		return rowCount;
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the tier-A test to prove USER_MODE async DML is rejected when
	 * the caller lacks FLS on the target SObject.
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}

	/**
	 * @description Tests that `withSystemMode` emits a `dml` bypass audit entry recording the
	 * `system-mode` target — proving subscriber-reachable DML opt-outs from USER_MODE-by-default
	 * leave a forensic trail.
	 *
	 * @see DML_Builder.withSystemMode
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitBypassAuditOnDmlSystemMode()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		Test.startTest();
		DML_Builder.newTransaction().doInsert(record).withSystemMode().execute();
		Test.stopTest();

		Map<String, Object> context = findBypassAuditContext(SYSTEM_MODE_AUDIT_TARGET_PREFIX + String.valueOf(Foobar__c.SObjectType));
		Assert.isNotNull(context, 'withSystemMode should emit an object-qualified bypass audit entry');
		Assert.areEqual(UTIL_BypassAudit.SURFACE_DML, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Surface should be dml');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
	}

	/**
	 * @description Tests that `systemModeInternal` flips the access level to SYSTEM_MODE WITHOUT
	 * enqueuing a bypass audit entry. The framework-internal channel is the path used by
	 * `TRG_PersistLogEntry` to write `LogEntry__c` rows after `LogEntryEvent__e` delivery — that
	 * write is not a subscriber-facing bypass, and auditing it would create an
	 * emit→deliver→persist→emit cascade with no fixpoint. Without this contract, every framework
	 * platform-event persist would emit a noise audit and (in test mode where
	 * `Test.getEventBus().deliver()` runs synchronously) recurse until CPU exhausted.
	 *
	 * @see DML_Builder.systemModeInternal
	 * @see TRG_PersistLogEntry
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldNotEmitBypassAuditOnDmlSystemModeInternal()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		Test.startTest();
		DML_Builder.newTransaction().doInsert(record).systemModeInternal().execute();
		Test.stopTest();

		Assert.isNull(findBypassAuditContext(SYSTEM_MODE_AUDIT_TARGET_PREFIX + String.valueOf(Foobar__c.SObjectType)),
				'systemModeInternal must not emit a bypass audit entry');
	}

	/**
	 * @description bypassSharingInternal() lets the framework save a record the running user cannot see. Foobar__c is
	 * Private and the test administrator owns the record. A Minimum Access user saves a change to it from a class declared
	 * with sharing, in system mode. Without the bypass the save is refused, which proves the user cannot see the record.
	 * With the bypass the same save goes through.
	 */
	@IsTest
	private static void shouldSaveARecordTheUserCannotSeeWithTheInternalSharingBypass()
	{
		final String originalEmail = 'seeded-internal-bypass@kerndx.test.invalid';
		final String changedEmail = 'saved-through-internal-bypass@kerndx.test.invalid';
		Foobar__c seededRecord;
		System.runAs(getTestAdmin())
		{
			seededRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Email__c, originalEmail).build();
		}
		seededRecord.Email__c = changedEmail;
		DML_Builder.TransactionResult refused;
		DML_Builder.TransactionResult saved;

		System.runAs(getLowPrivilegeUser())
		{
			Test.startTest();
			refused = new SharingEnforcedSaver().save(seededRecord, false);
			saved = new SharingEnforcedSaver().save(seededRecord, true);
			Test.stopTest();
		}

		Assert.isFalse(refused.isSuccess(), 'Expected the save without the bypass to be refused, because the user cannot see the record');
		Assert.isTrue(saved.isSuccess(), 'Expected the save with the internal sharing bypass to go through');
		System.runAs(getTestAdmin())
		{
			Foobar__c found = (Foobar__c)new SEL_Foobar().findById(seededRecord.Id);
			Assert.areEqual(changedEmail, found.Email__c, 'Expected the change saved through the internal sharing bypass');
		}
	}

	/**
	 * @description bypassSharingInternal() adds no entry to the bypass audit: only the framework calls it, for its own
	 * saves, so it must not fill the audit trail the way the audited bypassSharing() does.
	 */
	@IsTest
	private static void shouldNotEmitBypassAuditOnDmlBypassSharingInternal()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		Test.startTest();
		DML_Builder.newTransaction().doInsert(record).bypassSharingInternal().execute();
		Test.stopTest();

		Assert.isNull(findBypassAuditContext(SHARING_AUDIT_TARGET_PREFIX + String.valueOf(Foobar__c.SObjectType)),
				'Expected bypassSharingInternal to add no bypass audit entry');
	}

	/**
	 * @description Tests that `bypassSharing` emits a `dml` bypass audit entry recording the
	 * `sharing` target.
	 *
	 * @see DML_Builder.bypassSharing
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitBypassAuditOnDmlBypassSharing()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		Test.startTest();
		DML_Builder.newTransaction().doInsert(record).bypassSharing().execute();
		Test.stopTest();

		Map<String, Object> context = findBypassAuditContext(SHARING_AUDIT_TARGET_PREFIX + String.valueOf(Foobar__c.SObjectType));
		Assert.isNotNull(context, 'bypassSharing should emit an object-qualified bypass audit entry');
		Assert.areEqual(UTIL_BypassAudit.SURFACE_DML, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Surface should be dml');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
		String caller = (String)context.get(UTIL_BypassAudit.CONTEXT_CALLER);
		if(String.isBlank(UTIL_System.getManagedPackageNamespace()))
		{
			Assert.isTrue(caller.startsWith('DML_Builder_TEST'),
					'DML bypass through the builder should resolve the caller past DML_Builder to the subscriber test method. Actual: ' + caller);
		}
		else
		{
			Assert.areEqual(UTIL_BypassAudit.class.getName() + '.emit', caller,
					'In a namespaced org every frame carries the package namespace, so the documented fallback caller applies. Actual: ' + caller);
		}
	}

	/**
	 * @description Tests that `async()` flushes queued bypass audits before handing off to
	 * `DML_AsyncBuilder`. Without this flush, a subscriber chaining `bypassSharing().async().execute()`
	 * records the bypass intent on the source builder but never emits an audit, leaving a forensic
	 * gap. The async path runs on a different builder instance with no `auditQueue`, so the source
	 * builder is the only place to flush before handoff.
	 *
	 * @see DML_Builder.async
	 * @see UTIL_BypassAudit.AuditQueue.flush
	 */
	@IsTest
	private static void shouldEmitBypassAuditWhenAsyncCalledAfterBypassSharing()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		Test.startTest();
		DML_Builder.newTransaction().doInsert(record).bypassSharing().async();
		Test.stopTest();

		Map<String, Object> context = findBypassAuditContext(SHARING_AUDIT_TARGET_PREFIX + String.valueOf(Foobar__c.SObjectType));
		Assert.isNotNull(context, 'async() should flush queued bypass audits before handing off to DML_AsyncBuilder');
		Assert.areEqual(UTIL_BypassAudit.SURFACE_DML, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Surface should be dml');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
	}

	/**
	 * @description Tests that audit footprint recording skips null operations gracefully — a
	 * null records list, a null member of a generic `List<SObject>`, and an all-null concretely
	 * typed list (each registrable through the public `do*` surface and reachable at terminal
	 * time, before any DML validation occurs) must neither throw nor contaminate the footprints,
	 * while a real record in the same transaction still gets its object-qualified audit entry
	 * with an uninflated row count. The all-null typed list also checks that the typed-list fast
	 * path mints no zero-row phantom entry for its object. Uses the `async()` terminal so the
	 * audit path runs without attempting actual DML against the null entries.
	 *
	 * @see DML_Builder.async
	 * @see UTIL_BypassAudit.AuditQueue.recordOperation
	 */
	@IsTest
	private static void shouldSkipNullRecordsWhenRecordingAuditFootprints()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		Test.startTest();
		DML_Builder.newTransaction()
				.doInsert((List<SObject>)null)
				.doInsert(new List<SObject> {null})
				.doInsert(new List<Account> {null})
				.doInsert(record)
				.bypassSharing()
				.async();
		Test.stopTest();

		Map<String, Object> context = findBypassAuditContext(SHARING_AUDIT_TARGET_PREFIX + String.valueOf(Foobar__c.SObjectType));
		Assert.isNotNull(context, 'The real record should still produce its object-qualified audit entry');
		Assert.areEqual('1', String.valueOf(context.get(UTIL_BypassAudit.CONTEXT_ROW_COUNT)), 'Null operations and null members must not inflate the row count');
		Assert.isNull(findBypassAuditContext(SHARING_AUDIT_TARGET_PREFIX + 'null'), 'Null records must not contaminate the audit footprints');
		Assert.isNull(findBypassAuditContext(SHARING_AUDIT_TARGET_PREFIX + String.valueOf(Account.SObjectType)),
				'An all-null typed list must not mint a zero-row phantom entry for its object');
	}

	/**
	 * @description Tests that a concretely typed record list aggregates to a single
	 * object-qualified audit footprint carrying the summed row count, rather than one entry per
	 * record — the typed-list fast path of the footprint recorder. Uses the `async()` terminal so
	 * the audit path runs without attempting actual DML, mirroring the null-handling sibling.
	 *
	 * @see DML_Builder.async
	 * @see UTIL_BypassAudit.AuditQueue.recordOperation
	 */
	@IsTest
	private static void shouldAggregateTypedListRowsIntoOneAuditFootprint()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		List<Foobar__c> records = new List<Foobar__c>();
		records.add((Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build());
		records.add((Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build());

		Test.startTest();
		DML_Builder.newTransaction()
				.doInsert(records)
				.bypassSharing()
				.async();
		Test.stopTest();

		Map<String, Object> context = findBypassAuditContext(SHARING_AUDIT_TARGET_PREFIX + String.valueOf(Foobar__c.SObjectType));
		Assert.isNotNull(context, 'A typed record list should produce its object-qualified audit entry');
		Assert.areEqual('2', String.valueOf(context.get(UTIL_BypassAudit.CONTEXT_ROW_COUNT)),
				'The typed-list fast path must aggregate all rows into one entry with the summed row count');
	}

	/**
	 * @description With the UserModeDml_Enabled flag off, a save with no access mode runs in system mode, which skips the
	 * user's object and field permissions. bypassSharing() alone then saves every field, the hidden one included,
	 * because the org turned those checks off for every save. The bypass must not add a field check of its own here.
	 */
	@IsTest
	private static void bypassSharingAloneWithTheDmlFlagOffSavesEveryField()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		String changedName = UTIL_Random.randomName();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true, false);

		System.runAs(restricted)
		{
			DML_Builder.newTransaction().doUpdate(newChangeOf(row.Id, changedName, CHANGED_EMAIL)).bypassSharing().execute();
		}

		Foobar__c found = readFoobarAsAdmin(row.Id);
		Assert.areEqual(changedName, found.Name, 'Expected the new name to be saved');
		Assert.areEqual(CHANGED_EMAIL, found.Email__c, 'Expected the hidden field to be saved, because the flag turns field checks off');
	}

	/**
	 * @description withSystemMode() with bypassSharing() skips record sharing and the user's object and field permissions.
	 * A user who may only read Foobar__c, and cannot see the hidden field, still saves both fields on a row another user
	 * owns.
	 */
	@IsTest
	private static void systemModeWithBypassSharingSavesEveryField()
	{
		User restricted = insertRestrictedUser(READ_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		String changedName = UTIL_Random.randomName();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		System.runAs(restricted)
		{
			DML_Builder.newTransaction().withSystemMode().bypassSharing().doUpdate(newChangeOf(row.Id, changedName, CHANGED_EMAIL)).execute();
		}

		Foobar__c found = readFoobarAsAdmin(row.Id);
		Assert.areEqual(changedName, found.Name, 'Expected the new name to be saved');
		Assert.areEqual(CHANGED_EMAIL, found.Email__c, 'Expected the hidden field to be saved, because system mode skips field checks');
	}

	/**
	 * @description bypassSharing() alone does not let a user delete a record when the user has no delete permission on the
	 * object. The platform refuses the delete the way user mode refuses it, with a TypeException, and the row is still
	 * there.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesADeleteWithoutDeletePermission()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		try
		{
			System.runAs(restricted)
			{
				DML_Builder.newTransaction().doDelete(newChangeOf(row.Id, null, null)).bypassSharing().execute();
			}
			Assert.fail('Expected TypeException; the delete went through without delete permission');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, TypeException.class, 'Expected the refusal user mode gives. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
		}

		Assert.isNotNull(readFoobarAsAdmin(row.Id), 'Expected the row to still be there');
	}

	/**
	 * @description bypassSharing() alone writes exactly one bypass audit entry, for record sharing. It writes no entry for
	 * system mode, because the user's object and field permissions are not skipped.
	 */
	@IsTest
	private static void bypassSharingAloneWritesOneSharingAuditEntry()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		System.runAs(restricted)
		{
			Test.startTest();
			DML_Builder.newTransaction().doUpdate(newChangeOf(row.Id, UTIL_Random.randomName(), null)).bypassSharing().allowPartial().execute();
			Test.stopTest();
		}

		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);
		Assert.areEqual(1, countBypassAuditEntries(SHARING_AUDIT_TARGET_PREFIX + objectName), 'Expected one bypass audit entry for record sharing');
		Assert.areEqual(0, countBypassAuditEntries(SYSTEM_MODE_AUDIT_TARGET_PREFIX + objectName), 'Expected no bypass audit entry for system mode');
	}

	/**
	 * @description bypassSharing() alone on a save run in a background job writes exactly one bypass audit entry, for
	 * record sharing, when the save is queued. The job itself adds no entry, for record sharing or for system mode.
	 */
	@IsTest
	private static void bypassSharingAloneInABackgroundJobWritesOneSharingAuditEntry()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		System.runAs(restricted)
		{
			Test.startTest();
			DML_Builder.newTransaction().doUpdate(newChangeOf(row.Id, UTIL_Random.randomName(), null)).bypassSharing().allowPartial().async().execute();
			Test.stopTest();
		}

		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);
		Assert.areEqual(1, countBypassAuditEntries(SHARING_AUDIT_TARGET_PREFIX + objectName), 'Expected one bypass audit entry for record sharing');
		Assert.areEqual(0, countBypassAuditEntries(SYSTEM_MODE_AUDIT_TARGET_PREFIX + objectName), 'Expected no bypass audit entry for system mode');
	}

	/**
	 * @description bypassSharing() alone does not let a user create a record when the user has no create permission on
	 * the object. The platform refuses the insert the way user mode refuses it, with a TypeException, and no row is
	 * saved.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesAnInsertWithoutCreatePermissionAsUserModeDoes()
	{
		User restricted = insertRestrictedUser(READ_PERMISSIONS, Foobar__c.Email__c);
		String newName = UTIL_Random.randomName();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, newName).withoutInsertion().build();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		try
		{
			System.runAs(restricted)
			{
				DML_Builder.newTransaction().doInsert(record).bypassSharing().execute();
			}
			Assert.fail('Expected TypeException; the insert went through without create permission');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, TypeException.class, 'Expected the refusal user mode gives. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
		}

		Assert.areEqual(0, countFoobarsNamedAsAdmin(newName), 'Expected no row to be saved');
	}

	/**
	 * @description With allowPartial(), the refused insert of a user with no create permission is not thrown. The result
	 * for the row is unsuccessful, with the status code the platform gives when the user cannot create the record, and
	 * no row is saved. The caller declared that status code with expectRefusal(), so the refusal is logged as a warning
	 * and not as an error.
	 */
	@IsTest
	private static void bypassSharingAloneWithAllowPartialReportsTheRefusalPerRow()
	{
		User restricted = insertRestrictedUser(READ_PERMISSIONS, Foobar__c.Email__c);
		String newName = UTIL_Random.randomName();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, newName).withoutInsertion().build();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		captureLogEntries();
		DML_Builder.TransactionResult result;

		System.runAs(restricted)
		{
			Test.startTest();
			result = DML_Builder.newTransaction().doInsert(record).bypassSharing().allowPartial().expectRefusal(USER_MODE_REFUSAL_STATUS).execute();
			Test.stopTest();
		}

		Assert.isFalse(result.isSuccess(), 'Expected the result to report the refusal');
		Assert.areEqual(1, result.getErrors().size(), 'Expected one error for the refused row');
		Database.Error error = result.getErrors()[0];
		Assert.areEqual(USER_MODE_REFUSAL_STATUS, error.getStatusCode(), 'Expected the status code user mode gives. Actual message: ' + error.getMessage());
		Assert.areEqual(0, countFoobarsNamedAsAdmin(newName), 'Expected no row to be saved');
		Assert.areEqual(0, countCommitRowsAt(LOG_Engine.LEVEL_ERROR), 'Expected the declared refusal not to be logged as an error');
		Assert.areEqual(1, countCommitRowsAt(LOG_Engine.LEVEL_WARN), 'Expected the declared refusal to be logged once as a warning');
	}

	/**
	 * @description With suppressExceptions(), bypassSharing() alone gives back a failed result, instead of throwing, when
	 * the user has no create permission on the object. The result counts the one record as a failure and no record as a
	 * success. It holds no per-row error, because the save was refused as a whole. No row is saved.
	 */
	@IsTest
	private static void bypassSharingAloneWithSuppressExceptionsReturnsTheRefusal()
	{
		User restricted = insertRestrictedUser(READ_PERMISSIONS, Foobar__c.Email__c);
		String newName = UTIL_Random.randomName();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, newName).withoutInsertion().build();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		DML_Builder.TransactionResult result;

		System.runAs(restricted)
		{
			result = DML_Builder.newTransaction().doInsert(record).bypassSharing().suppressExceptions().execute();
		}

		Assert.isFalse(result.isSuccess(), 'Expected the result to report the refusal');
		Assert.areEqual(1, result.getFailureCount(), 'Expected the one record to count as a failure');
		Assert.areEqual(0, result.getSuccessCount(), 'Expected no record to count as a success');
		Assert.isTrue(result.getErrors().isEmpty(), 'Expected no per-row error, because the whole save was refused');
		Assert.areEqual(0, countFoobarsNamedAsAdmin(newName), 'Expected no row to be saved');
	}

	/**
	 * @description With suppressExceptions(), a save in user mode gives back a failed result, instead of throwing, when
	 * the user has no create permission on the object. This is the same save as the bypassSharing() test, without the
	 * bypass. No row is saved.
	 */
	@IsTest
	private static void userModeWithSuppressExceptionsReturnsTheObjectPermissionRefusal()
	{
		User restricted = insertRestrictedUser(READ_PERMISSIONS, Foobar__c.Email__c);
		String newName = UTIL_Random.randomName();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, newName).withoutInsertion().build();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		DML_Builder.TransactionResult result;

		System.runAs(restricted)
		{
			result = DML_Builder.newTransaction().doInsert(record).suppressExceptions().execute();
		}

		Assert.isFalse(result.isSuccess(), 'Expected the result to report the refusal');
		Assert.areEqual(1, result.getFailureCount(), 'Expected the one record to count as a failure');
		Assert.areEqual(0, result.getSuccessCount(), 'Expected no record to count as a success');
		Assert.isTrue(result.getErrors().isEmpty(), 'Expected no per-row error, because the whole save was refused');
		Assert.areEqual(0, countFoobarsNamedAsAdmin(newName), 'Expected no row to be saved');
	}

	/**
	 * @description suppressExceptions() turns only a refusal for a missing object permission into a failed result. A
	 * TypeException with another cause, here a bad conversion of a value inside the save, is still thrown, even when
	 * the user may create the record.
	 */
	@IsTest
	private static void suppressExceptionsStillThrowsATypeExceptionThatIsNotAPermissionRefusal()
	{
		User restricted = insertRestrictedUser(READ_CREATE_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, UTIL_Random.randomName()).withoutInsertion().build();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		DML_SharingProxy.sharingProxyForTest = new BadConversionInsertProxy();

		try
		{
			System.runAs(restricted)
			{
				DML_Builder.newTransaction().doInsert(record).suppressExceptions().execute();
			}
			Assert.fail('Expected TypeException; suppressExceptions() hid a TypeException that was not a permission refusal');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, TypeException.class, 'Expected the TypeException from the bad conversion. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
		}
	}

	/**
	 * @description In system mode, suppressExceptions() still throws a TypeException that comes from a bad conversion of a
	 * value inside the save. This holds even when the user has no create permission, because system mode does not check
	 * object permissions, so the TypeException cannot be a permission refusal.
	 */
	@IsTest
	private static void systemModeWithSuppressExceptionsStillThrowsATypeException()
	{
		User restricted = insertRestrictedUser(READ_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, UTIL_Random.randomName()).withoutInsertion().build();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		DML_SharingProxy.sharingProxyForTest = new BadConversionInsertProxy();

		try
		{
			System.runAs(restricted)
			{
				DML_Builder.newTransaction().doInsert(record).withSystemMode().suppressExceptions().execute();
			}
			Assert.fail('Expected TypeException; suppressExceptions() hid a TypeException in system mode');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, TypeException.class, 'Expected the TypeException from the bad conversion. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
		}
	}

	/**
	 * @description With allowPartial(), a save in user mode does not throw when the user has no edit permission on the
	 * object. The platform reports the refusal on the row instead, with the status code it gives when the user cannot
	 * change the record, and the row keeps its name. Without allowPartial() the same update throws a TypeException.
	 */
	@IsTest
	private static void allowPartialUpdateWithoutEditPermissionReportsWhatTheUserModeRefusalDoes()
	{
		User restricted = insertRestrictedUser(READ_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		DML_Builder.TransactionResult result;

		System.runAs(restricted)
		{
			result = DML_Builder.newTransaction().doUpdate(newChangeOf(row.Id, UTIL_Random.randomName(), null)).allowPartial().execute();
		}

		Assert.isFalse(result.isSuccess(), 'Expected the result to report the refusal');
		Assert.areEqual(1, result.getFailureCount(), 'Expected the one record to count as a failure');
		Assert.areEqual(1, result.getErrors().size(), 'Expected one error for the refused row');
		Database.Error error = result.getErrors()[0];
		Assert.areEqual(USER_MODE_REFUSAL_STATUS, error.getStatusCode(), 'Expected the status code user mode gives. Actual message: ' + error.getMessage());
		Assert.areEqual(row.Name, readFoobarAsAdmin(row.Id).Name, 'Expected the row to keep its name');
	}

	/**
	 * @description With allowPartial(), a delete in user mode does not throw when the user has no delete permission on
	 * the object. The platform reports the refusal on the row instead, with the status code it gives when a delete
	 * fails, and the row is still there. This status code is not the one the platform gives for a refused insert or
	 * update.
	 */
	@IsTest
	private static void allowPartialDeleteWithoutDeletePermissionReportsWhatTheUserModeRefusalDoes()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		DML_Builder.TransactionResult result;

		System.runAs(restricted)
		{
			result = DML_Builder.newTransaction().doDelete(newChangeOf(row.Id, null, null)).allowPartial().execute();
		}

		Assert.isFalse(result.isSuccess(), 'Expected the result to report the refusal');
		Assert.areEqual(1, result.getFailureCount(), 'Expected the one record to count as a failure');
		Assert.areEqual(1, result.getErrors().size(), 'Expected one error for the refused row');
		Database.Error error = result.getErrors()[0];
		Assert.areEqual(USER_MODE_DELETE_REFUSAL_STATUS, error.getStatusCode(), 'Expected the status code user mode gives. Actual message: ' + error.getMessage());
		Assert.isNotNull(readFoobarAsAdmin(row.Id), 'Expected the row to still be there');
	}

	/**
	 * @description bypassSharing() alone does not let a user change a record when the user has no edit permission on the
	 * object. The platform refuses the update the way user mode refuses it, with a TypeException, and the row keeps its
	 * name.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesAnUpdateWithoutEditPermission()
	{
		User restricted = insertRestrictedUser(READ_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		try
		{
			System.runAs(restricted)
			{
				DML_Builder.newTransaction().doUpdate(newChangeOf(row.Id, UTIL_Random.randomName(), null)).bypassSharing().execute();
			}
			Assert.fail('Expected TypeException; the update went through without edit permission');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, TypeException.class, 'Expected the refusal user mode gives. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
		}

		Assert.areEqual(row.Name, readFoobarAsAdmin(row.Id).Name, 'Expected the row to keep its name');
	}

	/**
	 * @description bypassSharingInternal() is the framework's own sharing bypass. Under the default user mode it must not
	 * turn into the bypass that bypassSharing() gives: user mode still applies the user's record sharing, so a change to a
	 * row the user cannot see is refused. The same holds when the save runs in a background job.
	 */
	@IsTest
	private static void internalBypassUnderUserModeStillAppliesSharing()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		System.runAs(restricted)
		{
			try
			{
				DML_Builder.newTransaction().bypassSharingInternal().doUpdate(newChangeOf(row.Id, UTIL_Random.randomName(), null)).execute();
				Assert.fail('Expected DmlException; the save went through although the user cannot see the row');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, 'Expected the refusal record sharing gives');
			}

			Test.startTest();
			DML_Builder.newTransaction()
					.bypassSharingInternal()
					.doUpdate(newChangeOf(row.Id, UTIL_Random.randomName(), null))
					.allowPartial()
					.suppressExceptions()
					.async()
					.execute();
			Test.stopTest();
		}

		Assert.areEqual(row.Name, readFoobarAsAdmin(row.Id).Name, 'Expected the row to keep its name after both saves');
	}

	/**
	 * @description bypassSharing() alone ignores record sharing. A user who may read and edit Foobar__c changes the name
	 * of a row another user owns, although Foobar__c records are private and the user cannot see that row.
	 */
	@IsTest
	private static void bypassSharingAloneUpdatesARecordOwnedByAnotherUser()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		String changedName = UTIL_Random.randomName();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		System.runAs(restricted)
		{
			DML_Builder.newTransaction().doUpdate(newChangeOf(row.Id, changedName, null)).bypassSharing().execute();
		}

		Assert.areEqual(changedName, readFoobarAsAdmin(row.Id).Name, 'Expected the new name to be saved on a row the user cannot see');
	}

	/**
	 * @description bypassSharing() alone still applies the user's field permissions. The user changes the name and the
	 * one field the user can neither read nor edit. The name is saved. The hidden field is left out of the save, so it
	 * keeps the value its owner saved.
	 */
	@IsTest
	private static void bypassSharingAloneDoesNotSaveAFieldTheUserCannotEdit()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		String changedName = UTIL_Random.randomName();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		System.runAs(restricted)
		{
			DML_Builder.newTransaction().doUpdate(newChangeOf(row.Id, changedName, CHANGED_EMAIL)).bypassSharing().execute();
		}

		Foobar__c found = readFoobarAsAdmin(row.Id);
		Assert.areEqual(changedName, found.Name, 'Expected the new name to be saved');
		Assert.areEqual(SEEDED_EMAIL, found.Email__c, 'Expected the field the user cannot edit to keep its old value');
	}

	/**
	 * @description bypassSharing() alone saves a parent and a child that both carry a value in the field the user cannot
	 * create. Both records are saved without that field. The caller's records get their new Ids, and the child's lookup
	 * points at the parent, because the save copies the Ids back before it fills in the child's parent field. The user
	 * may read, create and edit Foobar__c records. Edit is needed because the parent and the child are the same object,
	 * and the save writes the child's parent field in a second statement, an update.
	 */
	@IsTest
	private static void bypassSharingAloneInsertsWithoutTheHiddenFieldAndGivesBackTheIds()
	{
		User restricted = insertRestrictedUser(READ_CREATE_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c parent = newUnsavedFoobarWithEmail();
		Foobar__c child = newUnsavedFoobarWithEmail();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		System.runAs(restricted)
		{
			DML_Builder.newTransaction().doInsert(parent).doInsert(child, Foobar__c.Lookup__c, parent).bypassSharing().execute();
		}

		Assert.isNotNull(parent.Id, 'Expected the parent record to carry its new Id');
		Assert.isNotNull(child.Id, 'Expected the child record to carry its new Id');
		Foobar__c savedParent = readFoobarAsAdmin(parent.Id);
		Foobar__c savedChild = readFoobarAsAdmin(child.Id);
		Assert.areEqual(parent.Id, savedChild.Lookup__c, 'Expected the child to point at the parent');
		Assert.isNull(savedParent.Email__c, 'Expected the parent to be saved without the field the user cannot create');
		Assert.isNull(savedChild.Email__c, 'Expected the child to be saved without the field the user cannot create');
	}

	/**
	 * @description bypassSharing() alone ignores record sharing on a delete. A user with delete permission on Foobar__c
	 * deletes a row another user owns, although the user cannot see that row.
	 */
	@IsTest
	private static void bypassSharingAloneDeletesARecordOwnedByAnotherUser()
	{
		User restricted = insertRestrictedUser(READ_EDIT_DELETE_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		System.runAs(restricted)
		{
			DML_Builder.newTransaction().doDelete(newChangeOf(row.Id, null, null)).bypassSharing().execute();
		}

		Assert.isNull(readFoobarAsAdmin(row.Id), 'Expected the row to be deleted');
	}

	/**
	 * @description bypassSharing() alone ignores record sharing on an undelete. The owner deletes a row. A user with
	 * delete permission on Foobar__c then brings the row back from the recycle bin, although the user cannot see it.
	 */
	@IsTest
	private static void bypassSharingAloneUndeletesARecordOwnedByAnotherUser()
	{
		User restricted = insertRestrictedUser(READ_EDIT_DELETE_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		System.runAs(getTestAdmin())
		{
			DML_Builder.newTransaction().doDelete(row).execute();
		}

		System.runAs(restricted)
		{
			DML_Builder.newTransaction().doUndelete(newChangeOf(row.Id, null, null)).bypassSharing().execute();
		}

		Assert.isNotNull(readFoobarAsAdmin(row.Id), 'Expected the row to be back');
	}

	/**
	 * @description bypassSharing() alone ignores record sharing on an upsert matched on an external Id. The user can read
	 * and edit the external Id field, so the upsert finds the row another user owns and changes its name. No second row
	 * is created.
	 */
	@IsTest
	private static void bypassSharingAloneUpsertsByAKeyTheUserCanRead()
	{
		User restricted = insertRestrictedUser(READ_CREATE_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		String changedName = UTIL_Random.randomName();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		System.runAs(restricted)
		{
			DML_Builder.newTransaction().doUpsert(newUpsertOf(row.ExternalId__c, changedName), Foobar__c.ExternalId__c).bypassSharing().execute();
		}

		Assert.areEqual(changedName, readFoobarAsAdmin(row.Id).Name, 'Expected the upsert to change the name of the matched row');
		Assert.areEqual(1, countFoobarsAsAdmin(Foobar__c.ExternalId__c, new List<Object> {row.ExternalId__c}), 'Expected no second row with the same key');
	}

	/**
	 * @description bypassSharing() alone does not let a user match an upsert on an external Id the user cannot read. A
	 * match would tell the user which row holds that value, and would change it. The platform refuses the upsert as user
	 * mode refuses it, with an SObjectException that says the key field cannot be reached, and the row keeps its name.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesAnUpsertOnAKeyTheUserCannotRead()
	{
		User restricted = insertRestrictedUser(READ_CREATE_EDIT_PERMISSIONS, Foobar__c.ExternalId__c);
		Foobar__c row = insertRowOwnedByAdmin();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		try
		{
			System.runAs(restricted)
			{
				DML_Builder.newTransaction().doUpsert(newUpsertOf(row.ExternalId__c, UTIL_Random.randomName()), Foobar__c.ExternalId__c).bypassSharing().execute();
			}
			Assert.fail('Expected SObjectException; the upsert went through on a key the user cannot read');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, SObjectException.class, 'Expected the refusal user mode gives. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
		}

		Assert.areEqual(row.Name, readFoobarAsAdmin(row.Id).Name, 'Expected the row to keep its name');
	}

	/**
	 * @description bypassSharing() ignores record sharing when the caller also asks for user mode, in either order. User
	 * mode keeps the user's object and field permissions; it does not cancel the sharing bypass. Each of two saves
	 * changes the name of a row another user owns.
	 */
	@IsTest
	private static void bypassSharingWithExplicitUserModeUpdatesARecordOwnedByAnotherUser()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		String nameWithUserModeFirst = UTIL_Random.randomName();
		String nameWithBypassFirst = UTIL_Random.randomName();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		System.runAs(restricted)
		{
			DML_Builder.newTransaction().withUserMode().bypassSharing().doUpdate(newChangeOf(row.Id, nameWithUserModeFirst, null)).execute();
		}
		Assert.areEqual(nameWithUserModeFirst, readFoobarAsAdmin(row.Id).Name, 'Expected the save with user mode set first to change the name');

		System.runAs(restricted)
		{
			DML_Builder.newTransaction().bypassSharing().withUserMode().doUpdate(newChangeOf(row.Id, nameWithBypassFirst, null)).execute();
		}
		Assert.areEqual(nameWithBypassFirst, readFoobarAsAdmin(row.Id).Name, 'Expected the save with the bypass set first to change the name');
	}

	/**
	 * @description bypassSharing() alone also works when the save runs in a background job. The job ignores record
	 * sharing and keeps the user's field permissions: the name of a row another user owns changes, and the field the
	 * user cannot edit keeps its old value.
	 */
	@IsTest
	private static void bypassSharingAloneAppliesInsideTheAsyncJob()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		String changedName = UTIL_Random.randomName();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		System.runAs(restricted)
		{
			Test.startTest();
			DML_Builder.newTransaction().doUpdate(newChangeOf(row.Id, changedName, CHANGED_EMAIL)).bypassSharing().async().execute();
			Test.stopTest();
		}

		Foobar__c found = readFoobarAsAdmin(row.Id);
		Assert.areEqual(changedName, found.Name, 'Expected the job to save the new name');
		Assert.areEqual(SEEDED_EMAIL, found.Email__c, 'Expected the job to leave out the field the user cannot edit');
	}

	/**
	 * @description bypassSharing() alone refuses a child record whose parent field the user cannot create. The save
	 * fills in that field from the parent's new Id, so leaving it out would save a child with no parent and no error.
	 * The user may read, create and edit Foobar__c records. Edit is needed because the parent and the child are the
	 * same object, and the save writes the child's parent field in a second statement, an update. The platform refuses
	 * the save just as user mode does today, with a DmlException naming the parent field, and neither record is saved.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesAChildWhoseParentFieldTheUserCannotCreate()
	{
		User restricted = insertRestrictedUser(READ_CREATE_EDIT_PERMISSIONS, Foobar__c.Lookup__c);
		String parentName = UTIL_Random.randomName();
		String childName = UTIL_Random.randomName();
		Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, parentName).withoutInsertion().build();
		Foobar__c child = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, childName).withoutInsertion().build();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		try
		{
			System.runAs(restricted)
			{
				DML_Builder.newTransaction().doInsert(parent).doInsert(child, Foobar__c.Lookup__c, parent).bypassSharing().execute();
			}
			Assert.fail('Expected the save to be refused; it went through with a parent field the user cannot create');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Expected the refusal user mode gives. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
			DmlException refusal = (DmlException)error;
			Assert.areEqual(USER_MODE_REFUSAL_STATUS, refusal.getDmlType(0), 'Expected the status code user mode gives');
			Assert.isTrue(refusal.getDmlFieldNames(0).contains(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Lookup__c)), 'Expected the refusal to name the parent field');
		}

		Assert.areEqual(0, countFoobarsAsAdmin(Foobar__c.Name, new List<Object> {parentName, childName}), 'Expected neither record to be saved');
	}

	/**
	 * @description bypassSharing() alone refuses a child record of another object whose parent field the user cannot
	 * create. Here the parent is an Account and the child is a Contact. The save fills in the Contact's Account field
	 * from the new Account's Id before it inserts the Contact, so leaving that field out would save a Contact with no
	 * Account and no error. The user may read, create and edit Account and Contact records, but cannot see the
	 * Contact's Account field. The platform refuses the save just as user mode does today, and neither record is saved.
	 */
	@IsTest
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static void bypassSharingAloneRefusesAChildOfAnotherObjectWhoseParentFieldTheUserCannotCreate()
	{
		User restricted = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {Account.SObjectType, Contact.SObjectType},
						READ_CREATE_EDIT_PERMISSIONS,
						Contact.AccountId
				);
		String accountName = UTIL_Random.randomName();
		String contactLastName = UTIL_Random.randomName();
		Account parent = (Account)TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, accountName)
				.withOverride(Account.Phone, ACCOUNT_PHONE)
				.withOverride(Account.Industry, ACCOUNT_INDUSTRY)
				.withoutInsertion()
				.build();
		Contact child = (Contact)TST_Builder.of(Contact.SObjectType).withOverride(Contact.LastName, contactLastName).withoutInsertion().build();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		System.runAs(restricted)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isFieldAccessible(Contact.AccountId), 'Expected the user to be unable to see the Contact Account field');
		}

		try
		{
			System.runAs(restricted)
			{
				DML_Builder.newTransaction().doInsert(parent).doInsert(child, Contact.AccountId, parent).bypassSharing().execute();
			}
			Assert.fail('Expected the save to be refused; it went through with a parent field the user cannot create');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Expected the refusal user mode gives. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
			DmlException refusal = (DmlException)error;
			Assert.areEqual(USER_MODE_REFUSAL_STATUS, refusal.getDmlType(0), 'Expected the status code user mode gives. Actual message: ' + refusal.getMessage());
			Assert.isTrue(refusal.getDmlFieldNames(0).contains(UTIL_SObjectDescribe.getCachedFieldName(Contact.AccountId)), 'Expected the refusal to name the parent field');
		}

		Assert.areEqual(0, countRowsAsAdmin(Account.SObjectType, Account.Name, accountName), 'Expected the Account not to be saved');
		Assert.areEqual(0, countRowsAsAdmin(Contact.SObjectType, Contact.LastName, contactLastName), 'Expected the Contact not to be saved');
	}

	/**
	 * @description bypassSharing() alone keeps leaving out the field the user cannot edit when a save is tried again
	 * after a row lock. A row lock is the platform refusing a save because another process holds the record. A stand-in
	 * database layer refuses the first statement with a lock, and the save is sent again. The name changes and the
	 * hidden field keeps its old value.
	 */
	@IsTest
	private static void bypassSharingAloneKeepsTheStripWhenALockedStatementIsRetried()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		String changedName = UTIL_Random.randomName();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		System.runAs(restricted)
		{
			DML_SharingProxy.sharingProxyForTest = new DML_ThrowingLockProxy_TEST(1);
			try
			{
				Test.startTest();
				DML_Builder.newTransaction().doUpdate(newChangeOf(row.Id, changedName, CHANGED_EMAIL)).bypassSharing().withRetryOnLock().execute();
				Test.stopTest();
			}
			finally
			{
				DML_SharingProxy.sharingProxyForTest = null;
			}
		}

		Foobar__c found = readFoobarAsAdmin(row.Id);
		Assert.areEqual(changedName, found.Name, 'Expected the retried save to change the name');
		Assert.areEqual(SEEDED_EMAIL, found.Email__c, 'Expected the retried save to leave out the field the user cannot edit');
	}

	/**
	 * @description With allowPartial(), bypassSharing() alone checks the object permission for each object in a delete
	 * of rows of two objects. The user may delete Foobar__c rows and has no permission on Account. The Foobar__c row
	 * another user owns is deleted. The Account row stays, and its result is the platform's refusal.
	 */
	@IsTest
	private static void bypassSharingAloneWithAllowPartialDeletesOnlyTheTypesTheUserMayDelete()
	{
		User restricted = insertMinimumAccessUser(READ_EDIT_DELETE_PERMISSIONS);
		Foobar__c row = insertRowOwnedByAdmin();
		Account accountRow = insertAccountOwnedByAdmin();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		DML_Builder.TransactionResult result;

		System.runAs(restricted)
		{
			result = DML_Builder.newTransaction()
					.doDelete(new List<SObject> {newChangeOf(row.Id, null, null), newAccountChangeOf(accountRow.Id, null)})
					.bypassSharing()
					.allowPartial()
					.execute();
		}

		Assert.isNull(readFoobarAsAdmin(row.Id), 'Expected the Foobar__c row to be deleted');
		Assert.isNotNull(readAccountAsAdmin(accountRow.Id), 'Expected the Account row to still be there');
		Assert.areEqual(1, result.getSuccessCount(), 'Expected one row to be deleted');
		Assert.areEqual(1, result.getFailureCount(), 'Expected the Account row to be refused');
		Assert.areEqual(1, result.getErrors().size(), 'Expected the platform error for the Account row');
		Database.Error error = result.getErrors()[0];
		Assert.areEqual(USER_MODE_DELETE_REFUSAL_STATUS, error.getStatusCode(), 'Expected the status code user mode gives. Actual message: ' + error.getMessage());
	}

	/**
	 * @description With allowPartial(), bypassSharing() alone checks the object permission for each object in one update
	 * of rows of two objects. An update sends both objects in one statement, so the save splits it by object. The user
	 * may edit Foobar__c rows and has no permission on Account. The Foobar__c row another user owns gets its new name.
	 * The Account row keeps its name, and its result is the platform's refusal.
	 */
	@IsTest
	private static void bypassSharingAloneWithAllowPartialUpdatesOnlyTheTypesTheUserMayEdit()
	{
		User restricted = insertMinimumAccessUser(READ_EDIT_PERMISSIONS);
		Foobar__c row = insertRowOwnedByAdmin();
		Account accountRow = insertAccountOwnedByAdmin();
		String changedName = UTIL_Random.randomName();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		DML_Builder.TransactionResult result;

		System.runAs(restricted)
		{
			result = DML_Builder.newTransaction()
					.doUpdate(new List<SObject> {newChangeOf(row.Id, changedName, null), newAccountChangeOf(accountRow.Id, UTIL_Random.randomName())})
					.bypassSharing()
					.allowPartial()
					.execute();
		}

		Assert.areEqual(changedName, readFoobarAsAdmin(row.Id).Name, 'Expected the Foobar__c row to get its new name');
		Assert.areEqual(accountRow.Name, readAccountAsAdmin(accountRow.Id).Name, 'Expected the Account row to keep its name');
		Assert.areEqual(1, result.getSuccessCount(), 'Expected one row to be saved');
		Assert.areEqual(1, result.getFailureCount(), 'Expected the Account row to be refused');
		Assert.areEqual(1, result.getErrors().size(), 'Expected the platform error for the Account row');
	}

	/**
	 * @description The proxy that keeps the user's permissions when a save ignores record sharing gives back each
	 * result at the place of its record, also when every object is permitted. It saves the records grouped by object,
	 * which can differ from the order the caller gave them in. The caller here gives a Foobar__c row, an Account row
	 * and a second Foobar__c row, in that order, and each result carries the Id of the record at the same place. The
	 * test calls the proxy itself, because DML_Transaction always hands it the records already grouped by object.
	 */
	@IsTest
	private static void bypassSharingAloneGivesBackEachResultAtThePlaceOfItsRecord()
	{
		Foobar__c firstRow = insertRowOwnedByAdmin();
		Account accountRow = insertAccountOwnedByAdmin();
		Foobar__c secondRow = insertRowOwnedByAdmin();
		List<SObject> changes = new List<SObject>
		{
				newChangeOf(firstRow.Id, UTIL_Random.randomName(), null),
				newAccountChangeOf(accountRow.Id, UTIL_Random.randomName()),
				newChangeOf(secondRow.Id, UTIL_Random.randomName(), null)
		};
		DML_SharingProxy.PermissionKeepingProxy proxy = new DML_SharingProxy.PermissionKeepingProxy
				(
						DML_SharingProxy.getSharingProxy(DML_SharingProxy.SharingType.BYPASS),
						false
				);
		List<Database.SaveResult> results;

		System.runAs(getTestAdmin())
		{
			results = proxy.doUpdate(changes, true, null);
		}

		Assert.areEqual(changes.size(), results.size(), 'Expected one result for each record');
		for(Integer index = 0; index < changes.size(); index++)
		{
			Assert.areEqual(changes[index].Id, results[index].getId(), 'Expected the result at place ' + index + ' to belong to the record at that place');
		}
	}

	/**
	 * @description The warning about fields left out of a save names each field under the object it belongs to. The
	 * user saves a Contact that names its parent Account through the Contact's Account field. That parent Account holds
	 * only Site, a field the user cannot create. The save leaves Site out of the parent, and the warning names Site
	 * under Account, not under Contact. With allowPartial(), the platform's answer to the parent reference, now empty,
	 * goes on the Contact's result, so the save does not throw.
	 */
	@IsTest
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static void bypassSharingAloneWarningNamesAParentFieldUnderTheParentObject()
	{
		User restricted = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {Account.SObjectType, Contact.SObjectType},
						READ_CREATE_EDIT_PERMISSIONS,
						Account.Site
				);
		Contact child = (Contact)TST_Builder.of(Contact.SObjectType).withOverride(Contact.LastName, UTIL_Random.randomName()).withoutInsertion().build();
		Account parentReference = (Account)Account.SObjectType.newSObject();
		parentReference.Site = UTIL_Random.randomName();
		child.Account = parentReference;
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		System.runAs(restricted)
		{
			Test.startTest();
			DML_Builder.newTransaction().doInsert(child).bypassSharing().allowPartial().execute();
			Test.stopTest();
		}

		String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Account.Site);
		String accountPart = UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType) + WARNING_FIELD_LIST_START;
		String contactPart = UTIL_SObjectDescribe.getObjectNameFromType(Contact.SObjectType) + WARNING_FIELD_LIST_START;
		Assert.areEqual(1, countWarningsNaming(accountPart, fieldName), 'Expected the warning to name the field under Account');
		Assert.areEqual(0, countWarningsNaming(contactPart, fieldName), 'Expected the warning not to name the field under Contact');
	}

	/**
	 * @description When bypassSharing() alone leaves a field out of a save because the user cannot edit it, the save
	 * writes one warning to the log. The warning names the object and the field, so an administrator can see what was
	 * not saved. It never contains the value the user tried to save. The save changes two rows in one all-or-nothing
	 * update, and still writes only one warning: one for each save, not one for each record.
	 */
	@IsTest
	private static void bypassSharingAloneLogsOneWarningNamingTheRemovedField()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c firstRow = insertRowOwnedByAdmin();
		Foobar__c secondRow = insertRowOwnedByAdmin();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		System.runAs(restricted)
		{
			Test.startTest();
			DML_Builder.newTransaction()
					.doUpdate(new List<SObject>
					{
							newChangeOf(firstRow.Id, UTIL_Random.randomName(), CHANGED_EMAIL), newChangeOf(secondRow.Id, UTIL_Random.randomName(), CHANGED_EMAIL)
					})
					.bypassSharing()
					.execute();
			Test.stopTest();
		}

		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);
		String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Email__c);
		Assert.areEqual(1, countWarningsNaming(objectName, fieldName), 'Expected one warning naming the object and the field left out of the save');
		Assert.areEqual(0, countLogRowsContaining(CHANGED_EMAIL), 'Expected no log row to contain the value the user tried to save');
	}

	/**
	 * @description bypassSharing() alone ignores record sharing on an upsert matched on the record Id, and keeps the
	 * user's field permissions. One record of the upsert changes a row another user owns, and the other record is new.
	 * The row gets its new name and keeps the old value of the field the user cannot edit. The new record is saved
	 * without that field, and its new Id is given back on the caller's record.
	 */
	@IsTest
	private static void bypassSharingAloneUpsertsByRecordIdAndGivesBackTheNewId()
	{
		User restricted = insertRestrictedUser(READ_CREATE_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		Foobar__c fresh = newUnsavedFoobarWithEmail();
		String changedName = UTIL_Random.randomName();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		System.runAs(restricted)
		{
			DML_Builder.newTransaction().doUpsert(new List<SObject> {newChangeOf(row.Id, changedName, CHANGED_EMAIL), fresh}).bypassSharing().execute();
		}

		Foobar__c found = readFoobarAsAdmin(row.Id);
		Assert.areEqual(changedName, found.Name, 'Expected the existing row to get its new name');
		Assert.areEqual(SEEDED_EMAIL, found.Email__c, 'Expected the existing row to keep the old value of the field the user cannot edit');
		Assert.isNotNull(fresh.Id, 'Expected the new Id to be given back on the caller\'s record');
		Assert.isNull(readFoobarAsAdmin(fresh.Id).Email__c, 'Expected the new record to be saved without the field the user cannot create');
		Assert.areEqual(1, countFoobarsNamedAsAdmin(changedName), 'Expected no second row with the changed name');
	}

	/**
	 * @description bypassSharing() alone does not let a user find a parent record by an external Id the user cannot
	 * read. The child names its parent only by that key, so a match would tell the user which record holds the value.
	 * The save leaves the hidden key out of the parent reference, so the reference is empty and the platform refuses
	 * the insert with a DmlException. User mode refuses this save with the same exception and the same status code. No
	 * child record is saved, and the answer is the same whether or not a record holds the key. The test shows this
	 * with two keys: the key of a saved parent, and a random key that no record holds.
	 */
	@IsTest
	private static void bypassSharingAloneRefusesAChildWhoseParentIsFoundByAKeyTheUserCannotRead()
	{
		User restricted = insertRestrictedUser(READ_CREATE_EDIT_PERMISSIONS, Foobar__c.ExternalId__c);
		Foobar__c parent = insertRowOwnedByAdmin();
		String childName = UTIL_Random.randomName();
		Foobar__c child = newChildOfParentKey(childName, parent.ExternalId__c);
		String unknownKeyChildName = UTIL_Random.randomName();
		Foobar__c unknownKeyChild = newChildOfParentKey(unknownKeyChildName, UTIL_Random.randomAlphanumeric(EXTERNAL_ID_LENGTH));
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		try
		{
			System.runAs(restricted)
			{
				DML_Builder.newTransaction().doInsert(child).bypassSharing().execute();
			}
			Assert.fail('Expected the save to be refused; it went through with a parent found by a key the user cannot read');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Expected the platform to refuse the save. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
			DmlException refusal = (DmlException)error;
			Assert.areEqual(EMPTY_PARENT_REFERENCE_STATUS, refusal.getDmlType(0), 'Expected the status for an empty parent reference. Actual message: ' + refusal.getMessage());
		}

		try
		{
			System.runAs(restricted)
			{
				DML_Builder.newTransaction().doInsert(unknownKeyChild).bypassSharing().execute();
			}
			Assert.fail('Expected the save to be refused; it went through with a parent named by a key no record holds');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Expected the same refusal for a key no record holds. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
			DmlException refusal = (DmlException)error;
			Assert.areEqual(EMPTY_PARENT_REFERENCE_STATUS, refusal.getDmlType(0), 'Expected the same status for a key no record holds. Actual message: ' + refusal.getMessage());
		}

		Assert.areEqual(0, countFoobarsAsAdmin(Foobar__c.Name, new List<Object> {childName, unknownKeyChildName}), 'Expected no child record to be saved');
	}

	/**
	 * @description bypassSharing() alone saves a child record that finds its parent by an external Id the user can read.
	 * The parent belongs to another user, so the match ignores record sharing. The child is saved and linked to the
	 * parent. Next to the test where the user cannot read the key, this shows that the hidden key is what refuses that
	 * save.
	 */
	@IsTest
	private static void bypassSharingAloneSavesAChildWhoseParentIsFoundByAKeyTheUserCanRead()
	{
		User restricted = insertRestrictedUser(READ_CREATE_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c parent = insertRowOwnedByAdmin();
		Foobar__c child = newChildOfParentKey(UTIL_Random.randomName(), parent.ExternalId__c);
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		System.runAs(restricted)
		{
			DML_Builder.newTransaction().doInsert(child).bypassSharing().execute();
		}

		Assert.isNotNull(child.Id, 'Expected the child to be saved');
		Assert.areEqual(parent.Id, readFoobarAsAdmin(child.Id).Lookup__c, 'Expected the child to be linked to the parent found by the key');
	}

	/**
	 * @description With suppressLogging(), bypassSharing() alone still leaves out the field the user cannot edit, but
	 * writes no warning about it. The caller turned logging off, and the warning obeys that setting.
	 */
	@IsTest
	private static void bypassSharingAloneWithSuppressLoggingLeavesOutTheFieldWithoutAWarning()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		String changedName = UTIL_Random.randomName();
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		System.runAs(restricted)
		{
			Test.startTest();
			DML_Builder.newTransaction().doUpdate(newChangeOf(row.Id, changedName, CHANGED_EMAIL)).bypassSharing().allowPartial().suppressLogging().execute();
			Test.stopTest();
		}

		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);
		Assert.areEqual(0, countWarningsNaming(objectName, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Email__c)), 'Expected no warning naming the field');
		Foobar__c found = readFoobarAsAdmin(row.Id);
		Assert.areEqual(changedName, found.Name, 'Expected the new name to be saved');
		Assert.areEqual(SEEDED_EMAIL, found.Email__c, 'Expected the field the user cannot edit to be left out all the same');
	}

	/**
	 * @description The warning about fields left out of a save names only the fields that depend on the user's
	 * permissions. The record was read with the system fields that say who created and last changed it, and when. No
	 * user can write those, so the save leaves them out without naming them. It names the field this user cannot edit.
	 */
	@IsTest
	private static void bypassSharingAloneWarningNamesOnlyTheFieldsThatDependOnTheUser()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		Foobar__c change = readFoobarWithSystemFieldsAsAdmin(row.Id, new List<SObjectField> {Foobar__c.Name, Foobar__c.Email__c});
		String changedName = UTIL_Random.randomName();
		change.Name = changedName;
		change.Email__c = CHANGED_EMAIL;
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		System.runAs(restricted)
		{
			Test.startTest();
			DML_Builder.newTransaction().doUpdate(change).bypassSharing().execute();
			Test.stopTest();
		}

		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);
		Assert.areEqual(changedName, readFoobarAsAdmin(row.Id).Name, 'Expected the new name to be saved');
		Assert.areEqual(1, countFieldsLeftOutWarnings(), 'Expected one warning about fields left out of the save');
		Assert.areEqual(1, countWarningsNaming(objectName, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Email__c)), 'Expected the warning to name the field');
		for(SObjectField systemField : SYSTEM_AUDIT_FIELDS)
		{
			String systemFieldName = UTIL_SObjectDescribe.getCachedFieldName(systemField);
			Assert.areEqual(0, countWarningsNaming(objectName, systemFieldName), 'Expected no warning to name the system field ' + systemFieldName);
		}
	}

	/**
	 * @description When a save leaves out only fields no user can write, bypassSharing() alone writes no warning. The
	 * record was read with the system fields that say who created and last changed it, and when, and the user can edit
	 * every field the change sets.
	 */
	@IsTest
	private static void bypassSharingAloneLogsNoWarningWhenOnlyFieldsNoUserCanWriteAreLeftOut()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		Foobar__c change = readFoobarWithSystemFieldsAsAdmin(row.Id, new List<SObjectField> {Foobar__c.Name});
		String changedName = UTIL_Random.randomName();
		change.Name = changedName;
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		System.runAs(restricted)
		{
			Test.startTest();
			DML_Builder.newTransaction().doUpdate(change).bypassSharing().execute();
			Test.stopTest();
		}

		Assert.areEqual(changedName, readFoobarAsAdmin(row.Id).Name, 'Expected the new name to be saved');
		Assert.areEqual(0, countFieldsLeftOutWarnings(), 'Expected no warning about fields left out of the save');
	}

	/**
	 * @description The warning about fields left out of a save does not name a formula field, an auto number or a
	 * system field. A Foobar__c record was read with its formula field and its system fields, and a Case was read with
	 * its case number, which is an auto number. Both were changed and saved together with bypassSharing() alone. The
	 * save leaves all of those fields out, because no user can write them, but the warning names only the field this
	 * user cannot edit. That field keeps its old value.
	 */
	@IsTest
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static void bypassSharingAloneWarningLeavesOutFormulaAutoNumberAndSystemFields()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		Case caseRow = insertCaseOwnedByAdmin();
		Foobar__c change = readFoobarWithCalculatedAndSystemFieldsAsAdmin(row.Id, new List<SObjectField> {Foobar__c.Name, Foobar__c.Email__c});
		Case caseChange = readCaseAsAdmin(caseRow.Id);
		Assert.isNotNull(change.Formula__c, 'Expected the read to return the formula field, so the save carries it');
		Assert.isNotNull(caseChange.CaseNumber, 'Expected the read to return the case number, so the save carries it');
		String changedName = UTIL_Random.randomName();
		String changedSubject = UTIL_Random.randomName();
		change.Name = changedName;
		change.Email__c = CHANGED_EMAIL;
		caseChange.Subject = changedSubject;
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		System.runAs(restricted)
		{
			Test.startTest();
			DML_Builder.newTransaction().doUpdate(change).doUpdate(caseChange).bypassSharing().execute();
			Test.stopTest();
		}

		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);
		String casePart = UTIL_SObjectDescribe.getObjectNameFromType(Case.SObjectType) + WARNING_FIELD_LIST_START;
		Foobar__c found = readFoobarAsAdmin(row.Id);
		Assert.areEqual(changedName, found.Name, 'Expected the new name to be saved');
		Assert.areEqual(SEEDED_EMAIL, found.Email__c, 'Expected the field the user cannot edit to keep its old value');
		Assert.areEqual(changedSubject, readCaseAsAdmin(caseRow.Id).Subject, 'Expected the new case subject to be saved');
		Assert.areEqual(1, countFieldsLeftOutWarnings(), 'Expected one warning about fields left out of the save');
		Assert.areEqual(1, countWarningsNaming(objectName, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Email__c)), 'Expected the warning to name the field');
		String caseNumberName = UTIL_SObjectDescribe.getCachedFieldName(Case.CaseNumber);
		Assert.areEqual(0, countWarningsNaming(casePart, caseNumberName), 'Expected no warning to name the case number');
		List<SObjectField> fieldsNoUserCanWrite = new List<SObjectField>(CALCULATED_FIELDS);
		fieldsNoUserCanWrite.addAll(SYSTEM_AUDIT_FIELDS);
		fieldsNoUserCanWrite.addAll(OTHER_SYSTEM_FIELDS);
		for(SObjectField field : fieldsNoUserCanWrite)
		{
			String fieldName = UTIL_SObjectDescribe.getCachedFieldName(field);
			Assert.areEqual(0, countWarningsNaming(objectName, fieldName), 'Expected no warning to name the field no user can write: ' + fieldName);
		}
	}

	/**
	 * @description When a save leaves out only a formula field, an auto number and system fields, bypassSharing() alone
	 * writes no warning. A Foobar__c record was read with its formula field and its system fields, and a Case was read
	 * with its case number, which is an auto number. The user can edit every field the change sets on both.
	 */
	@IsTest
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static void bypassSharingAloneLogsNoWarningWhenOnlyFormulaAutoNumberAndSystemFieldsAreLeftOut()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c row = insertRowOwnedByAdmin();
		Case caseRow = insertCaseOwnedByAdmin();
		Foobar__c change = readFoobarWithCalculatedAndSystemFieldsAsAdmin(row.Id, new List<SObjectField> {Foobar__c.Name});
		Case caseChange = readCaseAsAdmin(caseRow.Id);
		Assert.isNotNull(change.Formula__c, 'Expected the read to return the formula field, so the save carries it');
		Assert.isNotNull(caseChange.CaseNumber, 'Expected the read to return the case number, so the save carries it');
		String changedName = UTIL_Random.randomName();
		String changedSubject = UTIL_Random.randomName();
		change.Name = changedName;
		caseChange.Subject = changedSubject;
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		System.runAs(restricted)
		{
			Test.startTest();
			DML_Builder.newTransaction().doUpdate(change).doUpdate(caseChange).bypassSharing().execute();
			Test.stopTest();
		}

		Assert.areEqual(changedName, readFoobarAsAdmin(row.Id).Name, 'Expected the new name to be saved');
		Assert.areEqual(changedSubject, readCaseAsAdmin(caseRow.Id).Subject, 'Expected the new case subject to be saved');
		Assert.areEqual(0, countFieldsLeftOutWarnings(), 'Expected no warning about fields left out of the save');
	}

	/**
	 * @description Records what user mode does when a user who may edit but not create Foobar__c records upserts a row
	 * the user owns, matched on its Id. Record sharing does not stand in the way, because the user owns the row. The
	 * platform refuses the upsert with a DmlException, and the row keeps its name. So an upsert needs both the create
	 * and the edit permission, even when every record already exists. bypassSharing() alone checks the same two
	 * permissions.
	 */
	@IsTest
	private static void userModeRefusesAnUpsertByIdFromAUserWhoCannotCreate()
	{
		User restricted = insertRestrictedUser(READ_EDIT_PERMISSIONS, Foobar__c.Email__c);
		Foobar__c ownRow;
		System.runAs(getTestAdmin())
		{
			ownRow = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, UTIL_Random.randomName())
					.withOverride(Foobar__c.OwnerId, restricted.Id)
					.build();
		}
		TST_Factory.newFeatureFlag(DML_SharingProxy.FLAG_USER_MODE_DML, true);

		try
		{
			System.runAs(restricted)
			{
				DML_Builder.newTransaction().doUpsert(newChangeOf(ownRow.Id, UTIL_Random.randomName(), null)).execute();
			}
			Assert.fail('Expected user mode to refuse the upsert; it went through without the create permission');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Expected the refusal user mode gives. Actual: ' + error.getTypeName() + ': ' + error.getMessage());
		}

		Assert.areEqual(ownRow.Name, readFoobarAsAdmin(ownRow.Id).Name, 'Expected the row to keep its name');
	}

	/**
	 * @description Counts the bypass audit events written for a save (the DML surface) whose target matches the given
	 * value. The log merges events that are the same into one detail row, and keeps how many there were on a rollup
	 * row. So this method adds up the count on each matching rollup row. Two events that are the same give 2, not 1.
	 *
	 * @param target The bypass audit target to count, for example sharing: followed by the object name
	 *
	 * @return The number of matching events
	 */
	private static Integer countBypassAuditEntries(String target)
	{
		String rollupBypassPrefix = TRG_PersistLogEntry.PREFIX_ROLLUP + LOG_Builder.RESERVED_FINGERPRINT_PREFIX;
		Integer entryCount = 0;
		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			if(entry.Fingerprint__c?.startsWith(rollupBypassPrefix) == true
					&& target.equals(context?.get(UTIL_BypassAudit.CONTEXT_TARGET))
					&& UTIL_BypassAudit.SURFACE_DML.equals(context?.get(UTIL_BypassAudit.CONTEXT_SURFACE)))
			{
				entryCount += entry.OccurrenceCount__c?.intValue() ?? 0;
			}
		}
		return entryCount;
	}

	/**
	 * @description Counts the WARN log events whose text names both the given object and the given field. An event with
	 * no fingerprint is saved as one plain row, which counts once. A fingerprint is a key that marks events that are the
	 * same. The log merges those into one detail row and keeps how many there were on a rollup row, so a rollup row adds
	 * its count and a detail row adds nothing. The bypass audit also writes WARN rows, but they never name a field, so
	 * they are not counted.
	 *
	 * @param objectName The object name the warning must contain
	 * @param fieldName The field name the warning must contain
	 *
	 * @return The number of matching WARN events
	 */
	private static Integer countWarningsNaming(String objectName, String fieldName)
	{
		Integer warningCount = 0;
		for(LogEntry__c entry : new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN))
		{
			String text = joinLogText(entry);
			if(!text.contains(objectName) || !text.contains(fieldName))
			{
				continue;
			}
			if(String.isBlank(entry.Fingerprint__c))
			{
				warningCount++;
			}
			else if(entry.Fingerprint__c.startsWith(TRG_PersistLogEntry.PREFIX_ROLLUP))
			{
				warningCount += entry.OccurrenceCount__c?.intValue() ?? 0;
			}
		}
		return warningCount;
	}

	/**
	 * @description Counts the log rows, at any level, whose text contains the given value.
	 *
	 * @param value The value to look for
	 *
	 * @return The number of log rows that contain the value
	 */
	private static Integer countLogRowsContaining(String value)
	{
		Integer rowCount = 0;
		for(LogEntry__c entry : new SEL_LogEntry().getAll())
		{
			if(joinLogText(entry).contains(value))
			{
				rowCount++;
			}
		}
		return rowCount;
	}

	/**
	 * @description Joins the text fields of one log row: the message, the short message and the context data.
	 *
	 * @param entry The log row
	 *
	 * @return The text of the row, with an empty string in place of any blank field
	 */
	private static String joinLogText(LogEntry__c entry)
	{
		return (entry.Message__c ?? '') + ' ' + (entry.ShortMessage__c ?? '') + ' ' + (entry.ContextData__c ?? '');
	}

	/**
	 * @description Saves a user on the Minimum Access profile who has the given object permissions on Foobar__c and can
	 * read and edit every Foobar__c field except Email__c. The profile gives no access to Account, so the user has no
	 * permission at all on Account records.
	 *
	 * @param permissionFields The ObjectPermissions fields to turn on for Foobar__c
	 *
	 * @return The saved user
	 */
	private static User insertMinimumAccessUser(List<SObjectField> permissionFields)
	{
		return TST_Factory.insertUserWithOneHiddenField(SEL_Profile.PROFILE_MINIMUM_ACCESS, new List<SObjectType> {Foobar__c.SObjectType}, permissionFields, Foobar__c.Email__c);
	}

	/**
	 * @description Saves, as the test administrator, one Account row with a random name, a phone number and an industry.
	 *
	 * @return The saved row
	 */
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static Account insertAccountOwnedByAdmin()
	{
		Account accountRow;
		System.runAs(getTestAdmin())
		{
			accountRow = (Account)TST_Builder.of(Account.SObjectType)
					.withOverride(Account.Name, UTIL_Random.randomName())
					.withOverride(Account.Phone, ACCOUNT_PHONE)
					.withOverride(Account.Industry, ACCOUNT_INDUSTRY)
					.build();
		}
		return accountRow;
	}

	/**
	 * @description Saves, as the test administrator, one Case with a random subject. Salesforce gives the Case its case
	 * number, an auto number that no user can write. The business hours field is left empty, because tests cannot
	 * create business hours records.
	 *
	 * @return The saved Case
	 */
	@SuppressWarnings('PMD.KernNoStandardObjectInPackageTests')
	private static Case insertCaseOwnedByAdmin()
	{
		Case caseRow;
		System.runAs(getTestAdmin())
		{
			caseRow = (Case)TST_Builder.of(Case.SObjectType).withOptionalField(Case.BusinessHoursId).withOverride(Case.Subject, UTIL_Random.randomName()).build();
		}
		return caseRow;
	}

	/**
	 * @description Reads one Case as the test administrator, in system mode and without record sharing. It reads the
	 * subject and the case number.
	 *
	 * @param recordId The Id of the Case to read
	 *
	 * @return The Case, or null when no Case with that Id exists
	 */
	private static Case readCaseAsAdmin(Id recordId)
	{
		Case found;
		System.runAs(getTestAdmin())
		{
			found = (Case)QRY_Builder.selectFrom(Case.SObjectType)
					.fields(new List<SObjectField> {Case.Subject, Case.CaseNumber})
					.condition(Case.Id).equals(recordId)
					.withSystemMode()
					.bypassSharing()
					.getFirst();
		}
		return found;
	}

	/**
	 * @description Builds an unsaved change to an existing Account row. It holds only the Id and, when given, the name.
	 *
	 * @param recordId The Id of the row to change
	 * @param name The new name, or null to leave the name out of the change
	 *
	 * @return The change, ready to save
	 */
	private static Account newAccountChangeOf(Id recordId, String name)
	{
		Account change = (Account)Account.SObjectType.newSObject(recordId);
		if(name != null)
		{
			change.Name = name;
		}
		return change;
	}

	/**
	 * @description Reads one Account row as the test administrator, in system mode and without record sharing.
	 *
	 * @param recordId The Id of the row to read
	 *
	 * @return The row, or null when no row with that Id exists
	 */
	private static Account readAccountAsAdmin(Id recordId)
	{
		Account found;
		System.runAs(getTestAdmin())
		{
			found = (Account)QRY_Builder.selectFrom(Account.SObjectType)
					.fields(new List<SObjectField> {Account.Name})
					.condition(Account.Id).equals(recordId)
					.withSystemMode()
					.bypassSharing()
					.getFirst();
		}
		return found;
	}

	/**
	 * @description Builds an unsaved Foobar__c record with a random name and the changed email, which a user who cannot
	 * edit Email__c must not be able to save.
	 *
	 * @return The unsaved record
	 */
	private static Foobar__c newUnsavedFoobarWithEmail()
	{
		return (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Name, UTIL_Random.randomName())
				.withOverride(Foobar__c.Email__c, CHANGED_EMAIL)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Builds an unsaved Foobar__c record for an upsert matched on the external Id. It holds only the
	 * external Id and the name, so the save carries no field the test did not mean to change.
	 *
	 * @param externalId The external Id that finds the row to change
	 * @param name The new name
	 *
	 * @return The record, ready to upsert
	 */
	private static Foobar__c newUpsertOf(String externalId, String name)
	{
		Foobar__c record = (Foobar__c)Foobar__c.SObjectType.newSObject();
		record.ExternalId__c = externalId;
		record.Name = name;
		return record;
	}

	/**
	 * @description Saves a Standard User who has the given object permissions on Foobar__c and can read and edit every
	 * Foobar__c field except one. The Standard User profile gives no access to Foobar__c, so the user has exactly the
	 * object permissions the test asks for.
	 *
	 * @param permissionFields The ObjectPermissions fields to turn on for Foobar__c
	 * @param hiddenField The one Foobar__c field the user can neither read nor edit
	 *
	 * @return The saved user
	 */
	private static User insertRestrictedUser(List<SObjectField> permissionFields, SObjectField hiddenField)
	{
		return TST_Factory.insertUserWithOneHiddenField(SEL_Profile.PROFILE_STANDARD_USER, new List<SObjectType> {Foobar__c.SObjectType}, permissionFields, hiddenField);
	}

	/**
	 * @description Saves, as the test administrator, one Foobar__c row with a random name, the seeded email and a random
	 * external Id. Foobar__c records are private, so another user cannot see the row through record sharing.
	 *
	 * @return The saved row
	 */
	private static Foobar__c insertRowOwnedByAdmin()
	{
		Foobar__c row;
		System.runAs(getTestAdmin())
		{
			row = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
					.withOverride(Foobar__c.Name, UTIL_Random.randomName())
					.withOverride(Foobar__c.Email__c, SEEDED_EMAIL)
					.withOverride(Foobar__c.ExternalId__c, UTIL_Random.randomAlphanumeric(EXTERNAL_ID_LENGTH))
					.build();
		}
		return row;
	}

	/**
	 * @description Builds an unsaved change to an existing Foobar__c row. It holds only the Id and the fields given, so
	 * the save carries no field the test did not mean to change.
	 *
	 * @param recordId The Id of the row to change
	 * @param name The new name, or null to leave the name out of the change
	 * @param email The new email, or null to leave the email out of the change
	 *
	 * @return The change, ready to save
	 */
	private static Foobar__c newChangeOf(Id recordId, String name, String email)
	{
		Foobar__c change = (Foobar__c)Foobar__c.SObjectType.newSObject(recordId);
		if(name != null)
		{
			change.Name = name;
		}
		if(email != null)
		{
			change.Email__c = email;
		}
		return change;
	}

	/**
	 * @description Reads one Foobar__c row as the test administrator, in system mode and without record sharing, so the
	 * read sees every row and every field whatever the user who saved it could see.
	 *
	 * @param recordId The Id of the row to read
	 *
	 * @return The row, or null when no row with that Id exists
	 */
	private static Foobar__c readFoobarAsAdmin(Id recordId)
	{
		Foobar__c found;
		System.runAs(getTestAdmin())
		{
			found = (Foobar__c)QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new List<SObjectField> {Foobar__c.Name, Foobar__c.Email__c, Foobar__c.ExternalId__c, Foobar__c.Lookup__c})
					.condition(Foobar__c.Id).equals(recordId)
					.withSystemMode()
					.bypassSharing()
					.getFirst();
		}
		return found;
	}

	/**
	 * @description Counts, as the test administrator, the Foobar__c rows whose given field holds one of the given values,
	 * in system mode and without record sharing, so the count sees every row.
	 *
	 * @param field The Foobar__c field to match on
	 * @param values The values to look for
	 *
	 * @return The number of rows whose field holds one of those values
	 */
	private static Integer countFoobarsAsAdmin(SObjectField field, List<Object> values)
	{
		Integer rowCount;
		System.runAs(getTestAdmin())
		{
			rowCount = QRY_Builder.selectFrom(Foobar__c.SObjectType).condition(field).isIn(values).withSystemMode().bypassSharing().count();
		}
		return rowCount;
	}

	/**
	 * @description Counts, as the test administrator, the rows of the given object whose given field holds the given
	 * value, in system mode and without record sharing, so the count sees every row.
	 *
	 * @param objectType The object whose rows are counted
	 * @param field The field to match on
	 * @param value The value to look for
	 *
	 * @return The number of rows whose field holds that value
	 */
	private static Integer countRowsAsAdmin(SObjectType objectType, SObjectField field, String value)
	{
		Integer rowCount;
		System.runAs(getTestAdmin())
		{
			rowCount = QRY_Builder.selectFrom(objectType).condition(field).equals(value).withSystemMode().bypassSharing().count();
		}
		return rowCount;
	}

	/**
	 * @description Counts, as the test administrator, the Foobar__c rows with the given name, in system mode and without
	 * record sharing, so the count sees every row.
	 *
	 * @param name The name to look for
	 *
	 * @return The number of rows with that name
	 */
	private static Integer countFoobarsNamedAsAdmin(String name)
	{
		return countFoobarsAsAdmin(Foobar__c.Name, new List<Object> {name});
	}

	/**
	 * @description Builds an unsaved Foobar__c child that names its parent only by the parent's external Id, through the
	 * Lookup__c relationship.
	 *
	 * @param name The child's name
	 * @param parentKey The external Id of the parent
	 *
	 * @return The unsaved child
	 */
	private static Foobar__c newChildOfParentKey(String name, String parentKey)
	{
		Foobar__c child = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Name, name).withoutInsertion().build();
		Foobar__c parentReference = (Foobar__c)Foobar__c.SObjectType.newSObject();
		parentReference.ExternalId__c = parentKey;
		child.Lookup__r = parentReference;
		return child;
	}

	/**
	 * @description Reads one Foobar__c row as the test administrator, in system mode and without record sharing, with
	 * the given fields and the system fields that say who created and last changed the row, and when. The test then
	 * changes the row it read and saves it, as a page that reads a record and saves it back does.
	 *
	 * @param recordId The Id of the row to read
	 * @param fields The fields to read besides the system fields
	 *
	 * @return The row
	 */
	private static Foobar__c readFoobarWithSystemFieldsAsAdmin(Id recordId, List<SObjectField> fields)
	{
		List<SObjectField> fieldsToRead = new List<SObjectField>(fields);
		fieldsToRead.addAll(SYSTEM_AUDIT_FIELDS);
		Foobar__c found;
		System.runAs(getTestAdmin())
		{
			found = (Foobar__c)QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(fieldsToRead)
					.condition(Foobar__c.Id).equals(recordId)
					.withSystemMode()
					.bypassSharing()
					.getFirst();
		}
		return found;
	}

	/**
	 * @description Reads one Foobar__c row as the test administrator, as readFoobarWithSystemFieldsAsAdmin does, and
	 * also reads the formula field and the other system fields.
	 *
	 * @param recordId The Id of the row to read
	 * @param fields The fields to read besides the formula field and the system fields
	 *
	 * @return The row
	 */
	private static Foobar__c readFoobarWithCalculatedAndSystemFieldsAsAdmin(Id recordId, List<SObjectField> fields)
	{
		List<SObjectField> fieldsToRead = new List<SObjectField>(fields);
		fieldsToRead.addAll(CALCULATED_FIELDS);
		fieldsToRead.addAll(OTHER_SYSTEM_FIELDS);
		return readFoobarWithSystemFieldsAsAdmin(recordId, fieldsToRead);
	}

	/**
	 * @description Counts the WARN log events written by the check that leaves out of a save the fields the user cannot
	 * create or edit. An event with no fingerprint is saved as one plain row, which counts once. A fingerprint is a key
	 * that marks events that are the same. The log merges those into one detail row and keeps how many there were on a
	 * rollup row, so a rollup row adds its count and a detail row adds nothing.
	 *
	 * @return The number of those WARN events
	 */
	private static Integer countFieldsLeftOutWarnings()
	{
		Integer warningCount = 0;
		for(LogEntry__c entry : new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN))
		{
			if(!FIELDS_LEFT_OUT_LOCATION.equalsIgnoreCase(entry.ClassMethod__c))
			{
				continue;
			}
			if(String.isBlank(entry.Fingerprint__c))
			{
				warningCount++;
			}
			else if(entry.Fingerprint__c.startsWith(TRG_PersistLogEntry.PREFIX_ROLLUP))
			{
				warningCount += entry.OccurrenceCount__c?.intValue() ?? 0;
			}
		}
		return warningCount;
	}

	/**
	 * @description Locates the most-recent bypass audit entry whose `target` matches the supplied
	 * value and whose `surface` is `dml`. Filtering by both target and surface keeps assertions
	 * stable when other framework-internal audits (e.g., `query` system-mode emissions) also fire
	 * during test setup.
	 *
	 * @param target The bypass audit `target` context value to find.
	 *
	 * @return The inner context map for the matching audit entry, or `null` if none exists.
	 */
	private static Map<String, Object> findBypassAuditContext(String target)
	{
		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			if(context != null
					&& target.equals(context.get(UTIL_BypassAudit.CONTEXT_TARGET))
					&& UTIL_BypassAudit.SURFACE_DML.equals(context.get(UTIL_BypassAudit.CONTEXT_SURFACE)))
			{
				return context;
			}
		}
		return null;
	}

	/**
	 * @description A fake database layer that throws a TypeException on every insert of the test object, from a real bad
	 * conversion of a value, so a test can check that suppressExceptions() still throws a TypeException that is not a
	 * permission refusal. A test installs it through DML_SharingProxy.sharingProxyForTest. The framework's own log rows
	 * go straight to the real database layer.
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	private inherited sharing class BadConversionInsertProxy extends DML_SharingProxy.DatabaseProxy
	{
		/**
		 * @description Converts a text value to a number before an insert of the test object, which throws a
		 * TypeException. Any other insert goes to the real database layer.
		 *
		 * @param records The records to insert
		 * @param allOrNothing Whether the statement is all-or-nothing
		 * @param accessLevel The access level to use
		 *
		 * @return The real database layer's results for an insert that is not of the test object
		 */
		public override List<Database.SaveResult> doInsert(List<SObject> records, Boolean allOrNothing, AccessLevel accessLevel)
		{
			if(DML_ThrowingLockProxy_TEST.isTestObjectStatement(records))
			{
				records[0].put(Foobar__c.Name, String.valueOf((Integer)TEXT_THAT_IS_NOT_A_NUMBER));
			}
			return super.doInsert(records, allOrNothing, accessLevel);
		}
	}

	/**
	 * @description Saves a record from a class declared with sharing, so the running user's record sharing applies the
	 * way it does in a Lightning controller. This test class declares no sharing, so a save made straight from a test
	 * method does not apply record sharing.
	 */
	private with sharing class SharingEnforcedSaver
	{
		/**
		 * @description Saves a change to one record in system mode, with or without the framework's internal sharing bypass.
		 *
		 * @param record The record to save
		 * @param bypassSharing True to save through bypassSharingInternal(), false to apply the user's record sharing
		 *
		 * @return The result of the save; a refused save is reported in the result, not thrown
		 */
		@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
		public DML_Builder.TransactionResult save(SObject record, Boolean bypassSharing)
		{
			DML_Builder builder = DML_Builder.newTransaction().systemModeInternal().doUpdate(record).allowPartial();
			if(bypassSharing)
			{
				builder.bypassSharingInternal();
			}
			return builder.execute();
		}
	}
}