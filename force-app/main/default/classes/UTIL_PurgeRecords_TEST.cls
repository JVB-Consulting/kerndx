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
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class UTIL_PurgeRecords_TEST
{
	/**
	 * @description Age in days used by the test of deleting old records. One record is given a created date this many days
	 * in the past, and the purge is asked to delete records that old, so exactly that record should go.
	 */
	private static final Integer DELETE_AFTER_DAYS = 10;

	/**
	 * @description Number of Foobar__c records a purge test creates before it runs the purge.
	 */
	private static final Integer NUMBER_OF_RECORDS_TO_CREATE = 10;

	/**
	 * @description Failure message for the check that the purge of old records deleted exactly one record.
	 */
	private static final String MSG_INCORRECT_DELETE_COUNT = 'Incorrect number of items deleted';

	/**
	 * @description Failure message for the check that an object name that does not exist is refused with a
	 * ConfigurationException.
	 */
	private static final String MSG_INVALID_OBJECT_EXCEPTION = 'Expected a ConfigurationException for invalid object name';

	/**
	 * @description Failure message for the check that no Foobar__c record is left after all records are purged.
	 */
	private static final String MSG_NOT_ALL_DELETED = 'Not all items were deleted as expected';

	/**
	 * @description Company name discriminator for the committed test admin user set up in
	 * @TestSetup and retrieved via SEL_User.findByCompanyName.
	 */
	private static final String TEST_ADMIN_COMPANY = 'UTIL_PurgeRecords_TEST-admin';

	/**
	 * @description Company name of the committed low-privilege user (Minimum Access - Salesforce profile) set up in
	 * @TestSetup and used by the test that proves the purge runs with the caller's own access.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'UTIL_PurgeRecords_TEST-low-privilege';

	/**
	 * @description Company name of the Standard User who holds only the Kern API Issue Resolver permission set: they see
	 * every API issue but do not hold the Delete API Records permission.
	 */
	private static final String API_ISSUE_RESOLVER_USER_COMPANY = 'UTIL_PurgeRecords_TEST-resolver';

	/**
	 * @description Company name of the Standard User who may delete API issues as far as object access goes, but does
	 * not hold the Delete API Records permission. They hold the Kern API Issue Resolver permission set and a permission
	 * set built in the test that grants delete access to API issues and nothing else.
	 */
	private static final String API_ISSUE_DELETER_WITHOUT_PERMISSION_COMPANY = 'UTIL_PurgeRecords_TEST-api-issue-deleter';

	/**
	 * @description Name of the permission set built in the test that grants read, edit and delete access to API issues
	 * and nothing else. Salesforce grants delete only together with read and edit.
	 */
	private static final String API_ISSUE_DELETE_ONLY_PERMISSION_SET_NAME = 'PurgeRecordsTestApiIssueDeleteAccess';

	/**
	 * @description Saves the test users in their own setup transaction, so a test can use System.runAs with any of them
	 * without a MIXED_DML_OPERATION error. A User is a setup object, and a save of a User cannot share a transaction with
	 * a save of other records. The users are: an administrator with the Kern Administrator permission set, a Minimum
	 * Access user, a resolver with only the Kern API Issue Resolver permission set, and a Standard User who may delete
	 * API issues but holds no Kern permission set that grants Delete API Records. The last user is never a System
	 * Administrator, because installing the package gives that profile every Kern permission. The builder fills no
	 * field of the permission set built here on its own, so none of its many system permissions is switched on at
	 * random. Tests that do not name a user run as the user who runs the tests.
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

		TST_Factory.insertUsers(new List<User> {TST_Factory.newMinimumAccessUser(LOW_PRIVILEGE_COMPANY)});

		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, API_ISSUE_RESOLVER_USER_COMPANY, CTRL_RetryApiIssue.API_ISSUE_RESOLVER_PERMISSION_SET_NAME);

		PermissionSet deleteOnlyPermissionSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withOptionalFields(new List<String>(UTIL_SObjectDescribe.getDescribe(PermissionSet.SObjectType).getCreatableRequiredFields()))
				.withOverride(PermissionSet.Name, API_ISSUE_DELETE_ONLY_PERMISSION_SET_NAME)
				.withOverride(PermissionSet.Label, API_ISSUE_DELETE_ONLY_PERMISSION_SET_NAME)
				.build();
		SObjectType objectPermissionsType = new ObjectPermissions().getSObjectType();
		TST_Builder.of(objectPermissionsType)
				.withOptionalFields(new List<String>(UTIL_SObjectDescribe.getDescribe(objectPermissionsType).getCreatableRequiredFields()))
				.withOverride(ObjectPermissions.ParentId, deleteOnlyPermissionSet.Id)
				.withOverride(ObjectPermissions.SobjectType, UTIL_SObjectDescribe.getObjectNameFromType(ApiIssue__c.SObjectType))
				.withOverride(ObjectPermissions.PermissionsRead, true)
				.withOverride(ObjectPermissions.PermissionsEdit, true)
				.withOverride(ObjectPermissions.PermissionsDelete, true)
				.build();
		User apiIssueDeleter = TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_STANDARD_USER,
						API_ISSUE_DELETER_WITHOUT_PERMISSION_COMPANY,
						CTRL_RetryApiIssue.API_ISSUE_RESOLVER_PERMISSION_SET_NAME
				);
		TST_Factory.createPermissionSetAssignments(new List<User> {apiIssueDeleter}, deleteOnlyPermissionSet.Id);
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
	 * @description The purge runs with the running user's own access (USER_MODE): it reads and deletes only what that user
	 * may read and delete. A Minimum Access user, who has no access to Foobar__c at all, purges every Foobar__c record. The
	 * purge is refused with a QueryException or a SecurityException and the record is still there. A change that makes the
	 * purge read or delete in system mode, which ignores the user's object access, would let this purge go through, and
	 * this test would fail. The test uses Foobar__c because a purge of API calls or API issues stops earlier, at the
	 * check of who may delete them, which the tests of the BypassApiRecordDeleteGuard feature flag below cover.
	 *
	 * @see UTIL_PurgeRecords.deleteAllRecords
	 */
	@IsTest
	private static void shouldRejectDeleteAllRecordsForLowPrivilegeUser()
	{
		Foobar__c seededFoobar;
		System.runAs(getTestAdmin())
		{
			seededFoobar = TST_Factory.insertFoobar();
		}

		System.runAs(getLowPrivilegeUser())
		{
			Test.startTest();
			try
			{
				UTIL_PurgeRecords.deleteAllRecords(Foobar__c.SObjectType);
				Assert.fail('Expected the purge to be refused for a user with no access to Foobar__c');
			}
			catch(Exception expected)
			{
				Assert.isTrue
						(
								expected instanceof QueryException || expected instanceof System.SecurityException,
								'Expected a QueryException or a SecurityException for a user with no access, got ' + expected.getTypeName() + ': ' + expected.getMessage()
						);
			}
			Test.stopTest();
		}

		Assert.isNotNull(new SEL_Foobar().findById(seededFoobar.Id), 'Expected the Foobar__c record to still exist after the refused purge');
	}

	/**
	 * @description API calls and API issues can be deleted only by a user the BypassApiRecordDeleteGuard feature flag is
	 * on for. A built-in rule turns the flag on for every holder of the Delete API Records permission, which the Kern
	 * Administrator permission set grants. So a purge run by such an administrator, as the scheduled purge is, deletes
	 * every API call and every API issue. Nothing in the test changes the flag. The records are saved inside the
	 * administrator's System.runAs block, because the trigger framework decides the flag for the first user who saves or
	 * deletes one in the test.
	 *
	 * @see UTIL_PurgeRecords.deleteAllRecords
	 */
	@IsTest
	private static void shouldPurgeApiCallsAndIssuesForAnAdministrator()
	{
		System.runAs(getTestAdmin())
		{
			ApiCall__c apiCall = (ApiCall__c)TST_Factory.getApiCallBuilder().build();
			ApiIssue__c apiIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(UTIL_Random.randomName()));

			Test.startTest();
			UTIL_PurgeRecords.deleteAllRecords(ApiIssue__c.SObjectType);
			UTIL_PurgeRecords.deleteAllRecords(ApiCall__c.SObjectType);
			Test.stopTest();

			Assert.isNull(new SEL_ApiIssue().findById(apiIssue.Id), 'Expected the purge to delete the API issue');
			Assert.isNull(new SEL_ApiCall().findById(apiCall.Id), 'Expected the purge to delete the API call');
		}
	}

	/**
	 * @description A purge of API issues run by a user the BypassApiRecordDeleteGuard feature flag is off for would only be
	 * refused row by row. Here that user is a resolver, who does not hold the Delete API Records permission. So the purge
	 * asks the flag first: it deletes nothing, starts no job and logs one warning with the Delete API Records message. The
	 * issue is saved inside the resolver's System.runAs block, so one user saves and purges, and the flag is decided for
	 * that user only.
	 *
	 * @see UTIL_PurgeRecords.deleteAllRecords
	 */
	@IsTest
	private static void shouldSkipThePurgeOfApiIssuesForAUserWithoutTheDeletePermission()
	{
		LOG_Builder.ignoreTestMode = true;
		ApiIssue__c apiIssue;
		System.runAs(new SEL_User().findByCompanyName(API_ISSUE_RESOLVER_USER_COMPANY))
		{
			ApiCall__c apiCall = (ApiCall__c)TST_Factory.getApiCallBuilder().build();
			apiIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(UTIL_Random.randomName()));

			Test.startTest();
			UTIL_PurgeRecords.deleteAllRecords(ApiIssue__c.SObjectType);
			Test.stopTest();
		}

		Assert.isNotNull(new SEL_ApiIssue().findById(apiIssue.Id), 'Expected the API issue to be kept');
		LogEntry__c warning = new SEL_LogEntry().findByMethod(UTIL_PurgeRecords.class.getName() + '/deleteAllRecords');
		Assert.isNotNull(warning, 'Expected a warning for the skipped purge');
		Assert.areEqual(LoggingLevel.WARN.name(), warning.LogLevel__c, 'Expected the skipped purge to be logged at warn');
		Assert.isTrue(warning.Message__c.contains(System.Label.DeleteApiRecords_PermissionRequired), 'Expected the label, got ' + warning.Message__c);
	}

	/**
	 * @description The purge of old API calls makes the same check: run by a resolver, for whom the flag is off, it deletes
	 * nothing, starts no job and logs one warning with the Delete API Records message. The resolver saves the call and
	 * purges, so one user does both.
	 *
	 * @see UTIL_PurgeRecords.deleteOlderThanNDays
	 */
	@IsTest
	private static void shouldSkipThePurgeOfOldApiCallsForAUserWithoutTheDeletePermission()
	{
		LOG_Builder.ignoreTestMode = true;
		ApiCall__c apiCall;
		System.runAs(new SEL_User().findByCompanyName(API_ISSUE_RESOLVER_USER_COMPANY))
		{
			apiCall = (ApiCall__c)TST_Factory.getApiCallBuilder().build();
			Test.setCreatedDate(apiCall.Id, Datetime.now().addDays(-DELETE_AFTER_DAYS));

			Test.startTest();
			UTIL_PurgeRecords.deleteOlderThanNDays(ApiCall__c.SObjectType, DELETE_AFTER_DAYS);
			Test.stopTest();
		}

		Assert.isNotNull(new SEL_ApiCall().findById(apiCall.Id), 'Expected the API call to be kept');
		LogEntry__c warning = new SEL_LogEntry().findByMethod(UTIL_PurgeRecords.class.getName() + '/deleteOlderThanNDays');
		Assert.isNotNull(warning, 'Expected a warning for the skipped purge');
		Assert.areEqual(LoggingLevel.WARN.name(), warning.LogLevel__c, 'Expected the skipped purge to be logged at warn');
		Assert.isTrue(warning.Message__c.contains(System.Label.DeleteApiRecords_PermissionRequired), 'Expected the label, got ' + warning.Message__c);
	}

	/**
	 * @description Your org turns the BypassApiRecordDeleteGuard feature flag on for every user, one of the two ways to
	 * widen it. A Standard User who may delete API issues but does not hold the Delete API Records permission purges
	 * API issues, and the purge deletes them: the purge asks the same flag the delete guard does. The issue is saved
	 * inside that user's System.runAs block, because the trigger framework decides the flag for the first user who saves
	 * or deletes one in the test.
	 *
	 * @see UTIL_PurgeRecords.deleteAllRecords
	 */
	@IsTest
	private static void shouldPurgeApiIssuesForAUserWithoutThePermissionWhenTheFlagIsOnForEveryUser()
	{
		User apiIssueDeleter = new SEL_User().findByCompanyName(API_ISSUE_DELETER_WITHOUT_PERMISSION_COMPANY);
		Assert.isFalse
				(
						UTIL_FeatureFlag.isEnabled(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD, apiIssueDeleter.Id),
						'Expected the flag to be off for a Standard User without the Delete API Records permission. If the package was'
						+ ' installed for all users, every profile holds that permission and this test cannot run as written.'
				);
		TST_Factory.newFeatureFlag(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD);

		System.runAs(apiIssueDeleter)
		{
			ApiCall__c apiCall = (ApiCall__c)TST_Factory.getApiCallBuilder().build();
			ApiIssue__c apiIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(UTIL_Random.randomName()));

			Test.startTest();
			UTIL_PurgeRecords.deleteAllRecords(ApiIssue__c.SObjectType);
			Test.stopTest();

			Assert.isNull(new SEL_ApiIssue().findById(apiIssue.Id), 'Expected the purge to delete the API issue');
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup. The test of the low-privilege purge uses
	 * this user to save the record before the low-privilege user tries to purge it.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. The test of the low-privilege purge uses this user to prove that the purge runs with the
	 * caller's own access: a user without access to the object cannot purge it.
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}
}