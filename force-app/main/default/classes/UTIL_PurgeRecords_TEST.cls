// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the batch class that facilitates the scheduled deletion of records.
 *
 * @see UTIL_PurgeRecords
 *
 * @author Jason van Beukering
 *
 * @group Bulk DML
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class UTIL_PurgeRecords_TEST
{
	private static final Integer DELETE_AFTER_DAYS = 10;
	private static final Integer NUMBER_OF_RECORDS_TO_CREATE = 10;
	private static final String MSG_INCORRECT_DELETE_COUNT = 'Incorrect number of items deleted';
	private static final String MSG_INVALID_OBJECT_EXCEPTION = 'Expected a ConfigurationException for invalid object name';
	private static final String MSG_NOT_ALL_DELETED = 'Not all items were deleted as expected';

	/**
	 * @description Company name discriminator for the committed test admin user set up in
	 * @TestSetup and retrieved via SEL_User.findByCompanyName.
	 */
	private static final String TEST_ADMIN_COMPANY = 'UTIL_PurgeRecords_TEST-admin';

	/**
	 * @description Company name discriminator for the committed low-privilege user (Minimum Access
	 * - Salesforce profile) set up in @TestSetup and used by the tier-A regression test.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'UTIL_PurgeRecords_TEST-low-privilege';

	/**
	 * @description Commits both a test-admin and a low-privilege user in @TestSetup's separate
	 * transaction so the tier-A test (shouldRejectDeleteAllRecordsForLowPrivilegeUser) can use
	 * System.runAs against either without triggering MIXED_DML_OPERATION. User is a Setup object,
	 * so User DML cannot mix with standard/custom-object DML in the same transaction;
	 * pre-provisioning here satisfies that boundary.
	 *
	 * Only the tier-A test uses these users — existing UTIL_PurgeRecords tests continue to run as
	 * the @IsTest running user without runAs.
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
	 * @description Creates a batch of Foobar__c records for purge coverage.
	 */
	private static void insertPurgeableFoobars()
	{
		TST_Factory.insertFoobars(NUMBER_OF_RECORDS_TO_CREATE);
	}

	/**
	 * @description Tests the deletion of all records for a given SObject type.
	 *
	 * @see UTIL_PurgeRecords.deleteAllRecords
	 */
	@IsTest
	private static void deleteAllItems()
	{
		insertPurgeableFoobars();

		Test.startTest();

		UTIL_PurgeRecords.deleteAllRecords(Foobar__c.SObjectType);

		Test.stopTest();

		Assert.isTrue(new SEL_Foobar().getAll().isEmpty(), MSG_NOT_ALL_DELETED);
	}

	/**
	 * @description Tests the deletion of records older than a specified number of days.
	 *
	 * @see UTIL_PurgeRecords.deleteOlderThanNDays
	 */
	@IsTest
	private static void deleteItemsOlderThanNDays()
	{
		insertPurgeableFoobars();

		Foobar__c foobar = TST_Factory.insertFoobar();
		Test.setCreatedDate(foobar.Id, Datetime.now().addDays(-DELETE_AFTER_DAYS));

		Integer numberOfItemsBeforeDelete = new SEL_Foobar().getAll().size();

		Test.startTest();

		UTIL_PurgeRecords.deleteOlderThanNDays(Foobar__c.SObjectType, DELETE_AFTER_DAYS);

		Test.stopTest();

		Integer numberOfItemsAfterDelete = new SEL_Foobar().getAll().size();
		Assert.areEqual(numberOfItemsBeforeDelete - 1, numberOfItemsAfterDelete, MSG_INCORRECT_DELETE_COUNT);
	}

	/**
	 * @description Tests the behavior when an invalid object name is provided to the deleteAllRecords method.
	 *
	 * @see UTIL_PurgeRecords.deleteAllRecords
	 */
	@IsTest
	private static void invalidRequest()
	{
		try
		{
			Test.startTest();

			UTIL_PurgeRecords.deleteAllRecords(UTIL_Random.randomName());

			Test.stopTest();

			Assert.fail('Error should have been throw');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.ConfigurationException.class, MSG_INVALID_OBJECT_EXCEPTION);
		}
	}

	/**
	 * @description Tier-A — regression gate against re-pinning
	 * UTIL_PurgeRecords to SYSTEM_MODE. Proves UTIL_PurgeRecords.deleteAllRecords on an
	 * arbitrary subscriber-visible SObject honours the flag-driven USER_MODE default: a
	 * low-privilege user (Minimum Access - Salesforce) with no FLS or DELETE permission on
	 * kern__ApiCall__c attempts to purge the table, the batch job's DML must evaluate
	 * CRUD/FLS against the running user, and the target records are not deleted.
	 *
	 * Catches: a regression that re-hard-codes `.withSystemMode()` inside UTIL_PurgeRecords' entry
	 * points (the configuration that commit 252be58 reverted). If a future refactor silently
	 * elevates, the low-privilege user's purge would succeed unnoticed — violating the framework's
	 * "global utilities on arbitrary subscriber targets honour the caller's flag-driven default"
	 * promise.
	 *
	 * @see UTIL_PurgeRecords.deleteAllRecords
	 */
	@IsTest
	private static void shouldRejectDeleteAllRecordsForLowPrivilegeUser()
	{
		User lowPrivilegeUser = getLowPrivilegeUser();
		ApiCall__c seededCall;

		System.runAs(getTestAdmin())
		{
			seededCall = (ApiCall__c)TST_Factory.getApiCallBuilder()
					.withOverride(ApiCall__c.ServiceName__c, 'TierA_T12_Service')
					.withOverride(ApiCall__c.OwnerId, lowPrivilegeUser.Id)
					.build();
		}

		System.runAs(lowPrivilegeUser)
		{
			Test.startTest();

			try
			{
				UTIL_PurgeRecords.deleteAllRecords(ApiCall__c.SObjectType);
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

			Assert.isNotNull(found, 'USER_MODE delete-all must be rejected for low-privilege user — ApiCall__c must still exist');
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup. Used by the
	 * tier-A test to seed the target record before the low-privilege user attempts to purge it.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the tier-A test to prove UTIL_PurgeRecords honours the
	 * flag-driven USER_MODE default on arbitrary subscriber-visible SObjects — the caller's lack
	 * of CRUD/FLS must cause the delete to be rejected.
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}
}