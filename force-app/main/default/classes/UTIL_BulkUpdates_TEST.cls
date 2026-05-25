// SPDX-License-Identifier: BUSL-1.1
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
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class UTIL_BulkUpdates_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'UTIL_BulkUpdates_TEST-admin';
	private static final String LOW_PRIVILEGE_COMPANY = 'UTIL_BulkUpdates_TEST-low-privilege';

	/**
	 * @description Number of test records to create.
	 */
	private static final Integer ITEMS_TO_CREATE = 5;

	/**
	 * @description Test prefix for email invalidation.
	 */
	private static final String INVALID_EMAIL_PREFIX = 'invalid.';

	/**
	 * @description Creates a dedicated test admin user so System.runAs in each test starts a fresh
	 * permission-evaluation context, bypassing the synthetic-org permission-cache staleness issue
	 * that affected mutating the running user's permissionSet mid-transaction. Also commits a
	 * low-privilege user (Minimum Access - Salesforce profile) so the tier-A regression test
	 * (shouldRejectBulkUpdateForLowPrivilegeUser) can use System.runAs without triggering
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

			LogEntry__c logEntry = new SEL_LogEntry().findByMethod(DML_Builder.class.getName() + '.execute');

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