// SPDX-License-Identifier: Apache-2.0
/**
 * @description Checks that the invalidation of an SObject's email field works as expected
 *
 * @see PROC_UpdateFields
 * @see UTIL_BulkUpdates
 *
 * @author Jason van Beukering
 *
 * @group Bulk DML
 *
 * @date February 2026, November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
@IsTest(seeAllData=false isParallel=false)
private class UTIL_BulkUpdates_TEST
{
	/**
	 * @description Company name given to the admin user created in the test setup. It is unique to this class, so
	 * the tests can find that one user again by company name.
	 */
	private static final String TEST_ADMIN_COMPANY = 'UTIL_BulkUpdates_TEST-admin';
	/**
	 * @description Company name given to the minimum-access user created in the test setup, so the tests that need
	 * a user without permissions can find that one user again by company name.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'UTIL_BulkUpdates_TEST-low-privilege';
	/**
	 * @description Company name given to the user created in the test setup who can read and edit test records and
	 * their fields, except the email field, which the user cannot see at all. The tests find that one user again by
	 * company name.
	 */
	private static final String HIDDEN_SOURCE_COMPANY = 'UTIL_BulkUpdates_TEST-hidden-source';

	/**
	 * @description Number of test records to create.
	 */
	private static final Integer ITEMS_TO_CREATE = 5;

	/**
	 * @description Test prefix for email invalidation.
	 */
	private static final String INVALID_EMAIL_PREFIX = 'invalid.';

	/**
	 * @description The number of rows each copy job reads at a time in the copy tests. It is more than the rows the tests
	 * save, so a batch job reads them all in one pass.
	 */
	private static final Integer RECORDS_PER_BATCH = 200;

	/**
	 * @description The length of a short text value in the copy tests. It fits in the 50-character External Id field.
	 */
	private static final Integer SHORT_VALUE_LENGTH = 20;

	/**
	 * @description The length of a long text value in the copy tests. It does not fit in the 50-character External Id
	 * field.
	 */
	private static final Integer LONG_VALUE_LENGTH = 60;

	/**
	 * @description The status of a job that has ended, as Salesforce stores it on the job record.
	 */
	private static final String JOB_STATUS_COMPLETED = 'Completed';

	/**
	 * @description The name of the feature setting that makes reads follow the running user's object and field access.
	 * A test removes it from the active settings to make reads ignore that access.
	 */
	private static final String USER_MODE_QUERIES_FLAG = 'UserModeQueries_Enabled';

	/**
	 * @description Creates a dedicated test admin user so System.runAs in each test starts a fresh
	 * permission-evaluation context, bypassing the synthetic-org permission-cache staleness issue
	 * that affected mutating the running user's permissionSet mid-transaction. Also commits a
	 * low-privilege user (Minimum Access - Salesforce profile) so the tier-A regression test
	 * (shouldRejectBulkUpdateForLowPrivilegeUser) can use System.runAs without triggering
	 * MIXED_DML_OPERATION — User is a Setup object, User DML cannot mix with standard/custom-object
	 * DML in the same transaction; pre-provisioning here satisfies that boundary. Also commits a user who cannot see the
	 * email field of the test object, for the tests that copy from a field the user cannot read.
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

		User hiddenSourceUser = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {Foobar__c.SObjectType},
						new List<SObjectField> {ObjectPermissions.PermissionsRead, ObjectPermissions.PermissionsEdit},
						Foobar__c.Email__c
				);
		hiddenSourceUser.CompanyName = HIDDEN_SOURCE_COMPANY;
		DML_Builder.newTransaction().doUpdate(hiddenSourceUser).execute();
	}

	/**
	 * @description Tests the scenario where "valid" emails are found that need to be invalidated
	 *
	 * @see UTIL_BulkUpdates.invalidateEmailFields
	 */
	@IsTest
	private static void invalidateEmailFieldsSuffix()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(ITEMS_TO_CREATE);

			Test.startTest();

			UTIL_BulkUpdates.invalidateEmailFields(Foobar__c.Email__c);

			Test.stopTest();

			List<Foobar__c> foundFoobars = new SEL_Foobar().getAll();

			for(Foobar__c foundFoobar : foundFoobars)
			{
				Assert.isTrue(foundFoobar.Email__c?.endsWith(SEL_User.INVALID_EMAIL_SUFFIX) == true, 'Email was not invalidated');
			}
		}
	}

	/**
	 * @description Tests the scenario where "valid" emails are found that need to be invalidated using PREFIX
	 *
	 * @see PROC_UpdateFields.DTO_Field.setObjectValue
	 */
	@IsTest
	private static void invalidateEmailFieldsPrefix()
	{
		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(ITEMS_TO_CREATE);

			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();

			parameters.objectName = SEL_Foobar.OBJECT_NAME;

			PROC_UpdateFields.DTO_Field dtoField = new PROC_UpdateFields.DTO_Field();

			dtoField.name = SEL_Foobar.FIELD_EMAIL;
			dtoField.value = INVALID_EMAIL_PREFIX;
			dtoField.updateMethod = PROC_UpdateFields.FieldUpdateMethod.PREFIX;

			parameters.updateFields.add(dtoField);

			parameters.searchConditions = new QRY_Condition.AndCondition()
					.add(new QRY_Condition.FieldCondition(SEL_Foobar.FIELD_EMAIL).notEquals(null));

			PROC_UpdateFields processor = new PROC_UpdateFields(parameters);
			IF_Queryable queryable = processor.buildQueryable();

			Test.startTest();

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(queryable)
							.withBatchSize(ITEMS_TO_CREATE);

			UTIL_AsynchronousJobLauncher.process(request, processor);

			Test.stopTest();

			List<Foobar__c> foundFoobars = new SEL_Foobar().getAll();

			for(Foobar__c foundFoobar : foundFoobars)
			{
				Assert.isTrue(foundFoobar.Email__c?.startsWith(INVALID_EMAIL_PREFIX) == true, 'Email was not invalidated');
			}
		}
	}

	/**
	 * @description Tests the scenario where no emails are found that need to be invalidated
	 *
	 * @see UTIL_BulkUpdates.invalidateEmailFields
	 */
	@IsTest
	private static void invalidateNoItemsFound()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> newItems = TST_Factory.newFoobars(ITEMS_TO_CREATE);

			for(Foobar__c newItem : newItems)
			{
				newItem.Email__c += 'invalid';
			}

			DML_Builder.newTransaction().doInsert(newItems).execute();

			Test.startTest();

			UTIL_BulkUpdates.invalidateEmailFields(SEL_Foobar.OBJECT_NAME, SEL_Foobar.FIELD_EMAIL);

			Test.stopTest();

			List<Foobar__c> foundFoobars = new SEL_Foobar().getAll();

			for(Foobar__c foundFoobar : foundFoobars)
			{
				Assert.isFalse(foundFoobar.Email__c?.endsWith(SEL_User.INVALID_EMAIL_SUFFIX) == true, 'Suffix should not have been added');
			}
		}
	}

	/**
	 * @description Tests the behaviour when an invalid field name is provided
	 */
	@IsTest
	private static void invalidFieldName()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				Test.startTest();

				UTIL_BulkUpdates.invalidateEmailFields(SEL_Foobar.OBJECT_NAME, UTIL_Random.randomName());

				Test.stopTest();

				Assert.fail('Error should have been thrown');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, QueryException.class, 'Incorrect exception thrown');
			}
		}
	}

	/**
	 * @description Checks that the owner is updated as expected
	 *
	 * @see UTIL_BulkUpdates.updateOwner
	 */
	@IsTest
	private static void updateOwner()
	{
		System.runAs(getTestAdmin())
		{
			User newReadOnlyUser;
			System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_SYSTEM_ADMIN))
			{
				// User DML must be inside System.runAs(System Admin) to satisfy MIXED_DML_OPERATION; platform-forced.
				newReadOnlyUser = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER);
				insert newReadOnlyUser;
			}

			List<Foobar__c> newItems = TST_Factory.newFoobars(ITEMS_TO_CREATE);

			for(Foobar__c newItem : newItems)
			{
				newItem.OwnerId = newReadOnlyUser.Id;
			}

			DML_Builder.newTransaction().doInsert(newItems).execute();

			List<Foobar__c> foundFoobars = new SEL_Foobar().getAll();

			for(Foobar__c foundFoobar : foundFoobars)
			{
				Assert.areEqual(newReadOnlyUser.Id, foundFoobar.OwnerId, 'Owner was not changed');
			}

			Test.startTest();

			UTIL_BulkUpdates.updateOwner(SEL_Foobar.OBJECT_NAME, SEL_Profile.PROFILE_STANDARD_USER, UserInfo.getUserName());

			Test.stopTest();

			foundFoobars = new SEL_Foobar().getAll();

			for(Foobar__c foundFoobar : foundFoobars)
			{
				Assert.areEqual(UserInfo.getUserId(), foundFoobar.OwnerId, 'Owner was not changed');
			}
		}
	}

	/**
	 * @description Checks that users are deactivated for the profile and users given
	 *
	 * @see UTIL_BulkUpdates.deactivateUsers
	 */
	@IsTest
	private static void deactivateUsers()
	{
		System.runAs(getTestAdmin())
		{
			LOG_Builder.ignoreTestMode = true;

			final Integer deactivateAfter = 1;

			List<User> newUsers = TST_Factory.insertUsers(SEL_Profile.PROFILE_CHATTER_FREE_USER, 2);
			User userNotToDeactivate = newUsers[0];
			User userToDeactivate = newUsers[1];
			Test.setCreatedDate(userToDeactivate.Id, Datetime.now().addDays(-(deactivateAfter)));

			Test.startTest();

			UTIL_BulkUpdates.deactivateUsers(new Set<String> {SEL_Profile.PROFILE_CHATTER_FREE_USER}, deactivateAfter);

			Test.stopTest();

			userNotToDeactivate = (User)new SEL_User().findById(userNotToDeactivate.Id);
			userToDeactivate = (User)new SEL_User().findById(userToDeactivate.Id);

			Assert.isTrue(userNotToDeactivate.IsActive, 'User should still be active');

			LogEntry__c logEntry = new SEL_LogEntry().findByMethod(DML_Transaction.CLASS_METHOD_COMMIT);

			if(logEntry == null)
			{
				Assert.isFalse(userToDeactivate.IsActive, 'User should not active');
			}
			else
			{
				Assert.isTrue
						(
								logEntry.Message__c.contains('UNABLE_TO_LOCK_ROW') || logEntry.Message__c.containsIgnoreCase('unable to obtain exclusive access'),
								'Unexpected error logged: ' + logEntry.Message__c
						);
			}
		}
	}

	/**
	 * @description Tier-A — regression gate against re-pinning
	 * UTIL_BulkUpdates to SYSTEM_MODE. Proves UTIL_BulkUpdates.updateField on an arbitrary
	 * subscriber-visible SObject honours the flag-driven USER_MODE default: a low-privilege user
	 * (Minimum Access - Salesforce) with no FLS on kern__ApiCall__c attempts a bulk update, the
	 * queueable's DML must evaluate FLS against the running user, and the target record is
	 * unchanged after Test.stopTest.
	 *
	 * Catches: a regression that re-hard-codes `parameters.accessLevel = AccessLevel.SYSTEM_MODE`
	 * inside the UTIL_BulkUpdates entry points (the configuration that commit 252be58 reverted).
	 * If a future refactor silently elevates, the low-privilege user's update would land
	 * unnoticed — violating the framework's "global utilities on arbitrary subscriber targets
	 * honour the caller's flag-driven default" promise.
	 *
	 * @see UTIL_BulkUpdates.updateField
	 * @see PROC_UpdateFields.execute
	 */
	@IsTest
	private static void shouldRejectBulkUpdateForLowPrivilegeUser()
	{
		User lowPrivilegeUser = getLowPrivilegeUser();
		final String attemptedStatus = 'TierA-attempted-status';
		ApiCall__c seededCall;

		System.runAs(getTestAdmin())
		{
			seededCall = (ApiCall__c)TST_Factory.getApiCallBuilder()
					.withOverride(ApiCall__c.ServiceName__c, 'TierA_T11_Service')
					.withOverride(ApiCall__c.OwnerId, lowPrivilegeUser.Id)
					.build();
		}

		System.runAs(lowPrivilegeUser)
		{
			Test.startTest();

			try
			{
				UTIL_BulkUpdates.updateField
						(
								String.valueOf(ApiCall__c.SObjectType),
								String.valueOf(ApiCall__c.Status__c),
								attemptedStatus,
								null,
								200,
								false
						);
			}
			catch(Exception expected)
			{
				Assert.isTrue
						(
								expected instanceof QueryException || expected instanceof System.SecurityException,
								'Expected QueryException or SecurityException for low-privilege user under USER_MODE; got ' + expected.getTypeName() + ': ' + expected.getMessage()
						);
			}

			Test.stopTest();
		}

		System.runAs(getTestAdmin())
		{
			ApiCall__c found = (ApiCall__c)new SEL_ApiCall().findById(seededCall.Id);

			Assert.areNotEqual(attemptedStatus, found.Status__c, 'USER_MODE bulk update must be rejected for low-privilege user — Status__c must not match the attempted value');
		}
	}

	/**
	 * @description The copy option puts each row's own source value into the target field. Every row has a different
	 * name, so a row that got another row's value would show.
	 *
	 * @see UTIL_BulkUpdates.copyField
	 */
	@IsTest
	private static void shouldCopyTheSourceFieldOnEachRow()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> foobars = insertFoobarsWithNames();

			Test.startTest();

			copyFoobarField(Foobar__c.Name, Foobar__c.Text__c, false);

			Test.stopTest();

			List<Foobar__c> savedFoobars = new SEL_Foobar().getAll();
			Assert.areEqual(foobars.size(), savedFoobars.size(), 'Expected every test row to be read back');
			Set<String> copiedValues = new Set<String>();
			for(Foobar__c savedFoobar : savedFoobars)
			{
				Assert.areEqual(savedFoobar.Name, savedFoobar.Text__c, 'Expected the row to hold its own name in the text field');
				copiedValues.add(savedFoobar.Text__c);
			}
			Assert.areEqual(foobars.size(), copiedValues.size(), 'Expected each row to hold a different value');
		}
	}

	/**
	 * @description The copy option refuses a source field that the object does not have, before any job starts.
	 *
	 * @see UTIL_BulkUpdates.copyField
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRefuseAMissingSourceField()
	{
		System.runAs(getTestAdmin())
		{
			assertCopyRefused(SEL_Foobar.OBJECT_NAME, UTIL_Random.randomName(), UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c));
		}
	}

	/**
	 * @description The copy option refuses a target field that the object does not have, before any job starts.
	 *
	 * @see UTIL_BulkUpdates.copyField
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRefuseAMissingTargetField()
	{
		System.runAs(getTestAdmin())
		{
			assertCopyRefused(SEL_Foobar.OBJECT_NAME, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name), UTIL_Random.randomName());
		}
	}

	/**
	 * @description The copy option refuses to copy a text field into a number field, before any job starts.
	 *
	 * @see UTIL_BulkUpdates.copyField
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRefuseFieldsOfDifferentTypeFamilies()
	{
		System.runAs(getTestAdmin())
		{
			assertCopyRefused(SEL_Foobar.OBJECT_NAME, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name), UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.NumberInteger__c));
		}
	}

	/**
	 * @description The copy option does not compare field lengths. It accepts a long text area as the source of a
	 * 50-character text field, and copies values that fit.
	 *
	 * @see UTIL_BulkUpdates.copyField
	 */
	@IsTest
	private static void shouldAcceptALongerTextSourceField()
	{
		System.runAs(getTestAdmin())
		{
			Assert.isTrue
					(
							UTIL_SObjectDescribe.getCachedFieldDescribe(Foobar__c.TextAreaLong__c).getLength() >
									UTIL_SObjectDescribe.getCachedFieldDescribe(Foobar__c.ExternalId__c).getLength(),
							'Expected the source field to be longer than the target field'
					);
			List<Foobar__c> foobars = insertFoobarsWithLongText(false);

			Test.startTest();

			copyFoobarField(Foobar__c.TextAreaLong__c, Foobar__c.ExternalId__c, false);

			Test.stopTest();

			for(Foobar__c savedFoobar : readFoobars(foobars))
			{
				Assert.areEqual(savedFoobar.TextAreaLong__c, savedFoobar.ExternalId__c, 'Expected a value that fits to be copied');
			}
		}
	}

	/**
	 * @description When the copy is not all or nothing, a value too long for the target fails only its own row. The other
	 * rows are copied.
	 *
	 * @see UTIL_BulkUpdates.copyField
	 */
	@IsTest
	private static void shouldFailOnlyTheLongRowWhenNotAllOrNothing()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> foobars = insertFoobarsWithLongText(true);

			Test.startTest();

			copyFoobarField(Foobar__c.TextAreaLong__c, Foobar__c.ExternalId__c, false);

			Test.stopTest();

			for(Foobar__c savedFoobar : readFoobars(foobars))
			{
				if(savedFoobar.TextAreaLong__c.length() == LONG_VALUE_LENGTH)
				{
					Assert.isNull(savedFoobar.ExternalId__c, 'Expected the row with a value too long for the target to be left alone');
				}
				else
				{
					Assert.areEqual(savedFoobar.TextAreaLong__c, savedFoobar.ExternalId__c, 'Expected a row with a value that fits to be copied');
				}
			}
		}
	}

	/**
	 * @description When the copy is all or nothing, one value too long for the target fails every row that the job read
	 * with it. The job's save throws the save error, which reaches the test when the job runs.
	 *
	 * @see UTIL_BulkUpdates.copyField
	 */
	@IsTest
	private static void shouldFailTheWholeBatchWhenAllOrNothing()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> foobars = insertFoobarsWithLongText(true);

			Test.startTest();

			copyFoobarField(Foobar__c.TextAreaLong__c, Foobar__c.ExternalId__c, true);

			try
			{
				Test.stopTest();
				Assert.fail('Expected the save of the rows to fail');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, 'Expected a save error, got ' + error.getMessage());
			}

			for(Foobar__c savedFoobar : readFoobars(foobars))
			{
				Assert.isNull(savedFoobar.ExternalId__c, 'Expected no row to be copied when one row fails');
			}
		}
	}

	/**
	 * @description Salesforce will not put a decimal number into a whole number field, and that error would stop the
	 * whole chunk of rows. So the copy option refuses annual revenue, a currency field, as the source of the number of
	 * employees, a whole number field, before any job starts.
	 *
	 * @see UTIL_BulkUpdates.copyField
	 */
	@IsTest
	private static void shouldRefuseADecimalSourceForAWholeNumberTarget()
	{
		System.runAs(getTestAdmin())
		{
			Assert.areEqual(DisplayType.INTEGER, UTIL_SObjectDescribe.getCachedFieldDescribe(Account.NumberOfEmployees).getType(), 'Expected a whole number target');

			assertCopyRefused
					(
							UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType),
							UTIL_SObjectDescribe.getCachedFieldName(Account.AnnualRevenue),
							UTIL_SObjectDescribe.getCachedFieldName(Account.NumberOfEmployees)
					);
		}
	}

	/**
	 * @description The copy option accepts a text field as the source of a lookup field, and starts the job. A text
	 * value that is not a valid record Id fails only its own row when the row is saved.
	 *
	 * @see UTIL_BulkUpdates.copyField
	 */
	@IsTest
	private static void shouldAcceptATextSourceForALookupTarget()
	{
		System.runAs(getTestAdmin())
		{
			copyFoobarField(Foobar__c.Text__c, Foobar__c.Lookup__c, false);

			Assert.areEqual(1, countJobs(), 'Expected the copy to start one job');
		}
	}

	/**
	 * @description The copy option accepts a whole number field as the source of another whole number field, and starts
	 * the job. The height and the width of a web link are both whole number fields.
	 *
	 * @see UTIL_BulkUpdates.copyField
	 */
	@IsTest
	private static void shouldAcceptAWholeNumberSourceForAWholeNumberTarget()
	{
		System.runAs(getTestAdmin())
		{
			Assert.areEqual(DisplayType.INTEGER, UTIL_SObjectDescribe.getCachedFieldDescribe(WebLink.Height).getType(), 'Expected a whole number source');
			Assert.areEqual(DisplayType.INTEGER, UTIL_SObjectDescribe.getCachedFieldDescribe(WebLink.Width).getType(), 'Expected a whole number target');

			UTIL_BulkUpdates.copyField
					(
							UTIL_SObjectDescribe.getObjectNameFromType(WebLink.SObjectType),
							UTIL_SObjectDescribe.getCachedFieldName(WebLink.Height),
							UTIL_SObjectDescribe.getCachedFieldName(WebLink.Width),
							null,
							RECORDS_PER_BATCH,
							false
					);

			Assert.areEqual(1, countJobs(), 'Expected the copy to start one job');
		}
	}

	/**
	 * @description The copy option refuses the same field as both the source and the target, before any job starts.
	 *
	 * @see UTIL_BulkUpdates.copyField
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRefuseTheSameFieldAsSourceAndTarget()
	{
		System.runAs(getTestAdmin())
		{
			assertCopyRefused(SEL_Foobar.OBJECT_NAME, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c), UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c));
		}
	}

	/**
	 * @description The copy option refuses a target field that no user can change, before any job starts. The target is
	 * a text formula field, so it can take the text of the source field, but Salesforce would refuse to save a value
	 * into it.
	 *
	 * @see UTIL_BulkUpdates.copyField
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRefuseATargetFieldThatCannotBeWritten()
	{
		System.runAs(getTestAdmin())
		{
			assertCopyRefused(SEL_Foobar.OBJECT_NAME, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name), UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Formula__c));
		}
	}

	/**
	 * @description The copy option refuses a source field that the running user cannot read, before any job starts. The
	 * user here can edit the target field but cannot see the source field at all. Without the refusal, the copy would put
	 * values the user may not read into a field the user can read.
	 *
	 * @see UTIL_BulkUpdates.copyField
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRefuseASourceFieldTheUserCannotRead()
	{
		assertCopyFromHiddenFieldRefused();
	}

	/**
	 * @description The copy option refuses a source field that the running user cannot read, also when the package's
	 * feature settings make reads ignore the user's field access. The read that finds the rows would then return the
	 * hidden field, so only the check before the job keeps its values out of the target field.
	 *
	 * @see UTIL_BulkUpdates.copyField
	 */
	@IsTest
	private static void shouldRefuseASourceFieldTheUserCannotReadWhenReadsIgnoreFieldAccess()
	{
		SEL_FeatureFlag.activeFlags.remove(USER_MODE_QUERIES_FLAG);
		Assert.isFalse(QRY_Builder.userModeQueriesEnabled(), 'Expected reads to ignore the user\'s field access once the setting is removed');

		assertCopyFromHiddenFieldRefused();
	}

	/**
	 * @description The copy option refuses a target field that the running user can read but cannot edit, before any job
	 * starts. A user who can edit the field describes it first in the same test, before any other code describes it.
	 * A saved answer from that describe would say the field can be edited, so the refusal proves the check reads the field
	 * again for the user who calls the copy. The user here may read test records but not edit them, so no field of the
	 * record can be edited.
	 *
	 * @see UTIL_BulkUpdates.copyField
	 */
	@IsTest
	private static void shouldRefuseATargetFieldTheUserCanReadButNotEdit()
	{
		System.runAs(new SEL_User().findByCompanyName(HIDDEN_SOURCE_COMPANY))
		{
			Assert.isTrue(UTIL_SObjectDescribe.getCachedFieldDescribe(Foobar__c.Text__c).isUpdateable(), 'Expected the first user to be able to edit the target field');
		}

		User readOnlyUser = TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {Foobar__c.SObjectType},
						new List<SObjectField> {ObjectPermissions.PermissionsRead},
						Foobar__c.Formula__c
				);

		System.runAs(readOnlyUser)
		{
			Assert.isTrue(Foobar__c.Text__c.getDescribe().isAccessible(), 'Expected the user to be able to read the target field');
			Assert.isFalse(Foobar__c.Text__c.getDescribe().isUpdateable(), 'Expected the user not to be able to edit the target field');

			assertCopyRefused(SEL_Foobar.OBJECT_NAME, UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name), UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c));
		}
	}

	/**
	 * @description Checks, as the user from the test setup who cannot see the email field, that a copy from that field
	 * into the text field is refused before any job starts.
	 */
	private static void assertCopyFromHiddenFieldRefused()
	{
		System.runAs(new SEL_User().findByCompanyName(HIDDEN_SOURCE_COMPANY))
		{
			Assert.isFalse(Foobar__c.Email__c.getDescribe().isAccessible(), 'Expected the user not to be able to read the source field');
			Assert.isTrue(Foobar__c.Text__c.getDescribe().isUpdateable(), 'Expected the user to be able to edit the target field');

			try
			{
				copyFoobarField(Foobar__c.Email__c, Foobar__c.Text__c, false);
				Assert.fail('Expected the copy from a field the user cannot read to be refused');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException, got ' + error.getMessage());
			}
		}

		Assert.areEqual(0, countJobs(), 'Expected no job to be started for a refused copy');
	}

	/**
	 * @description The copy works through the bulk update utility and through a batch job. One set of rows is copied by
	 * copyField, which chooses how its job runs, and another by a batch job set up by hand. Every row is copied, and the
	 * batch job ends. shouldEndARunOverNonIdRows in TRG_SetTriggeringRecordIndex_TEST proves a queued job by its Id.
	 *
	 * @see UTIL_BulkUpdates.copyField
	 * @see PROC_UpdateFields.buildQueryable
	 */
	@IsTest
	private static void shouldCopyAcrossABatchAndAQueueableStrategy()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> foobars = insertFoobarsWithNames();
			for(Integer index = 0; index < foobars.size(); index++)
			{
				foobars[index].Checkbox__c = Math.mod(index, 2) == 0;
			}
			DML_Builder.newTransaction().doUpdate(foobars).execute();

			Test.startTest();

			UTIL_BulkUpdates.copyField
					(
							SEL_Foobar.OBJECT_NAME,
							UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name),
							UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c),
							buildCheckboxCondition(true),
							RECORDS_PER_BATCH,
							false
					);

			PROC_UpdateFields.DTO_Parameters parameters = new PROC_UpdateFields.DTO_Parameters();
			parameters.objectName = SEL_Foobar.OBJECT_NAME;
			parameters.searchConditions = buildCheckboxCondition(false);
			PROC_UpdateFields.DTO_Field fieldUpdate = new PROC_UpdateFields.DTO_Field();
			fieldUpdate.name = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c);
			fieldUpdate.value = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name);
			fieldUpdate.updateMethod = PROC_UpdateFields.FieldUpdateMethod.COPY_FROM_FIELD;
			parameters.updateFields.add(fieldUpdate);
			PROC_UpdateFields processor = new PROC_UpdateFields(parameters);
			Id batchJobId = UTIL_AsynchronousJobLauncher.process
					(
							new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(processor.buildQueryable())
									.withBatchSize(RECORDS_PER_BATCH)
									.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.BATCH),
							processor
					);

			Test.stopTest();

			for(Foobar__c savedFoobar : readFoobars(foobars))
			{
				Assert.areEqual(savedFoobar.Name, savedFoobar.Text__c, 'Expected every row to be copied, whichever job read it');
			}
			AsyncApexJob batchJob = new SEL_AsyncApexJob().findByIds(new List<Id> {batchJobId}).iterator().next();
			Assert.areEqual(JOB_STATUS_COMPLETED, batchJob.Status, 'Expected the batch job to end');
		}
	}

	/**
	 * @description Saves test rows, each with its own random name.
	 *
	 * @return The saved rows.
	 */
	private static List<Foobar__c> insertFoobarsWithNames()
	{
		List<Object> names = new List<Object>();
		for(Integer index = 0; index < ITEMS_TO_CREATE; index++)
		{
			names.add(UTIL_Random.randomAlphanumeric(SHORT_VALUE_LENGTH));
		}
		return TST_Builder.of(Foobar__c.SObjectType)
				.withCount(ITEMS_TO_CREATE)
				.withCycle(Foobar__c.Name, names)
				.buildList();
	}

	/**
	 * @description Saves test rows with a short value in the long text area, and, when asked, one row with a value too
	 * long for the 50-character External Id field.
	 *
	 * @param includeLongValue Whether one row gets a value that does not fit in the External Id field.
	 *
	 * @return The saved rows.
	 */
	private static List<Foobar__c> insertFoobarsWithLongText(Boolean includeLongValue)
	{
		List<Object> values = new List<Object>();
		for(Integer index = 0; index < ITEMS_TO_CREATE; index++)
		{
			Boolean isLongRow = includeLongValue && index == 0;
			values.add(UTIL_Random.randomAlphanumeric(isLongRow ? LONG_VALUE_LENGTH : SHORT_VALUE_LENGTH));
		}
		return TST_Builder.of(Foobar__c.SObjectType)
				.withCount(ITEMS_TO_CREATE)
				.withCycle(Foobar__c.TextAreaLong__c, values)
				.buildList();
	}

	/**
	 * @description Starts a copy between two fields of the test object, on every row, through the bulk update utility.
	 *
	 * @param sourceField The field to copy from.
	 * @param targetField The field to copy into.
	 * @param isAllOrNothing Whether one failed row fails every row the job read with it.
	 */
	private static void copyFoobarField(SObjectField sourceField, SObjectField targetField, Boolean isAllOrNothing)
	{
		UTIL_BulkUpdates.copyField
				(
						SEL_Foobar.OBJECT_NAME,
						UTIL_SObjectDescribe.getCachedFieldName(sourceField),
						UTIL_SObjectDescribe.getCachedFieldName(targetField),
						null,
						RECORDS_PER_BATCH,
						isAllOrNothing
				);
	}

	/**
	 * @description Builds a search for test rows with the checkbox ticked or not ticked.
	 *
	 * @param isTicked Whether to find the ticked rows.
	 *
	 * @return The search conditions.
	 */
	private static QRY_Condition.Evaluable buildCheckboxCondition(Boolean isTicked)
	{
		return new QRY_Condition.AndCondition()
				.add(new QRY_Condition.FieldCondition(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Checkbox__c)).equals(isTicked));
	}

	/**
	 * @description Reads the given test rows as they are stored.
	 *
	 * @param foobars The saved rows.
	 *
	 * @return The stored rows, with their name, text, long text and External Id fields.
	 */
	private static List<Foobar__c> readFoobars(List<Foobar__c> foobars)
	{
		List<Foobar__c> savedFoobars = QRY_Builder.selectFrom(Foobar__c.SObjectType)
				.fields(new List<SObjectField> {Foobar__c.Name, Foobar__c.Text__c, Foobar__c.TextAreaLong__c, Foobar__c.ExternalId__c})
				.condition(Foobar__c.Id).isIn(foobars)
				.toList();
		Assert.areEqual(foobars.size(), savedFoobars.size(), 'Expected every test row to be read back');
		return savedFoobars;
	}

	/**
	 * @description Checks that the bulk update utility refuses a copy between two fields with an IllegalArgumentException,
	 * and that no job was started.
	 *
	 * @param objectName The API name of the object.
	 * @param sourceFieldName The API name of the field to copy from.
	 * @param targetFieldName The API name of the field to copy into.
	 */
	private static void assertCopyRefused(String objectName, String sourceFieldName, String targetFieldName)
	{
		try
		{
			UTIL_BulkUpdates.copyField(objectName, sourceFieldName, targetFieldName, null, RECORDS_PER_BATCH, false);
			Assert.fail('Expected the copy of ' + sourceFieldName + ' into ' + targetFieldName + ' to be refused');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException, got ' + error.getMessage());
		}

		Assert.areEqual(0, countJobs(), 'Expected no job to be started for a refused copy');
	}

	/**
	 * @description Counts the background jobs started in this test.
	 *
	 * @return The number of jobs.
	 */
	private static Integer countJobs()
	{
		return new SEL_AsyncApexJob().count();
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
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the tier-A test to prove UTIL_BulkUpdates honours the
	 * flag-driven USER_MODE default on arbitrary subscriber-visible SObjects — the caller's lack
	 * of FLS must cause the update to be rejected.
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}
}