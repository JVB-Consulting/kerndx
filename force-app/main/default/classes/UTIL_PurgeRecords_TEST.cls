// SPDX-License-Identifier: Apache-2.0
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
	 * @description Company name of the Minimum Access user who may delete API calls but cannot read API issues. They hold
	 * only a permission set built in the test that grants delete access to API calls and nothing else.
	 */
	private static final String API_CALL_DELETER_WITHOUT_ISSUE_ACCESS_COMPANY = 'UTIL_PurgeRecords_TEST-api-call-deleter';

	/**
	 * @description Name of the permission set built in the test that grants read, edit and delete access to API calls
	 * and nothing else. Salesforce grants delete only together with read and edit.
	 */
	private static final String API_CALL_DELETE_ONLY_PERMISSION_SET_NAME = 'PurgeRecordsTestApiCallDeleteAccess';

	/**
	 * @description Company name of the Minimum Access user who may delete API calls and can read API issues, but cannot
	 * read the Status field of an API issue. They hold the permission set that grants delete access to API calls, and a
	 * permission set built in the test that grants read access to API issues and to their API Call field only.
	 */
	private static final String API_CALL_DELETER_WITHOUT_ISSUE_STATUS_ACCESS_COMPANY = 'UTIL_PurgeRecords_TEST-no-issue-status';

	/**
	 * @description Name of the permission set built in the test that grants read access to API issues and to their API
	 * Call field, and to no other field of an API issue.
	 */
	private static final String API_ISSUE_READ_WITHOUT_STATUS_PERMISSION_SET_NAME = 'PurgeRecordsTestApiIssueReadNoStatus';

	/**
	 * @description Company name of the Minimum Access user who may delete API calls and can read API issues, but cannot
	 * read the API Call field of an API issue. They hold the permission set that grants delete access to API calls, and a
	 * permission set built in the test that grants read access to API issues and to their Status field only.
	 */
	private static final String API_CALL_DELETER_WITHOUT_ISSUE_API_CALL_ACCESS_COMPANY = 'UTIL_PurgeRecords_TEST-no-issue-api-call';

	/**
	 * @description Name of the permission set built in the test that grants read access to API issues and to their Status
	 * field, and to no other field of an API issue.
	 */
	private static final String API_ISSUE_READ_WITHOUT_API_CALL_PERMISSION_SET_NAME = 'PurgeRecordsTestApiIssueReadNoApiCall';

	/**
	 * @description Saves the test users in their own setup transaction, so a test can use System.runAs with any of them
	 * without a MIXED_DML_OPERATION error. A User is a setup object, and a save of a User cannot share a transaction with
	 * a save of other records. The users are: an administrator with the Kern Administrator permission set, a Minimum
	 * Access user, a resolver with only the Kern API Issue Resolver permission set, and a Standard User who may delete
	 * API issues but holds no Kern permission set that grants Delete API Records. The last user is never a System
	 * Administrator, because installing the package gives that profile every Kern permission. A Minimum Access user who
	 * may delete API calls but cannot read API issues is saved too, and so is a Minimum Access user who may delete API
	 * calls and can read API issues but not their Status field, and so is one who can read API issues but not their API
	 * Call field. The builder fills no field of the permission sets built here on its own, so none of their many system
	 * permissions is switched on at random. Tests that do not name a user run as the user who runs the tests.
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

		Id apiIssueDeletePermissionSetId = insertDeleteOnlyPermissionSet(API_ISSUE_DELETE_ONLY_PERMISSION_SET_NAME, ApiIssue__c.SObjectType);
		User apiIssueDeleter = TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_STANDARD_USER,
						API_ISSUE_DELETER_WITHOUT_PERMISSION_COMPANY,
						CTRL_RetryApiIssue.API_ISSUE_RESOLVER_PERMISSION_SET_NAME
				);
		TST_Factory.createPermissionSetAssignments(new List<User> {apiIssueDeleter}, apiIssueDeletePermissionSetId);

		User apiCallDeleter = TST_Factory.newMinimumAccessUser(API_CALL_DELETER_WITHOUT_ISSUE_ACCESS_COMPANY);
		TST_Factory.insertUsers(new List<User> {apiCallDeleter});
		Id apiCallDeletePermissionSetId = insertDeleteOnlyPermissionSet(API_CALL_DELETE_ONLY_PERMISSION_SET_NAME, ApiCall__c.SObjectType);
		TST_Factory.createPermissionSetAssignments(new List<User> {apiCallDeleter}, apiCallDeletePermissionSetId);

		User apiCallDeleterWithoutIssueStatus = TST_Factory.newMinimumAccessUser(API_CALL_DELETER_WITHOUT_ISSUE_STATUS_ACCESS_COMPANY);
		TST_Factory.insertUsers(new List<User> {apiCallDeleterWithoutIssueStatus});
		TST_Factory.createPermissionSetAssignments(new List<User> {apiCallDeleterWithoutIssueStatus}, apiCallDeletePermissionSetId);
		TST_Factory.createPermissionSetAssignments
				(
						new List<User> {apiCallDeleterWithoutIssueStatus},
						insertApiIssueReadPermissionSetForOneField(API_ISSUE_READ_WITHOUT_STATUS_PERMISSION_SET_NAME, ApiIssue__c.ApiCall__c)
				);

		User apiCallDeleterWithoutIssueApiCall = TST_Factory.newMinimumAccessUser(API_CALL_DELETER_WITHOUT_ISSUE_API_CALL_ACCESS_COMPANY);
		TST_Factory.insertUsers(new List<User> {apiCallDeleterWithoutIssueApiCall});
		TST_Factory.createPermissionSetAssignments(new List<User> {apiCallDeleterWithoutIssueApiCall}, apiCallDeletePermissionSetId);
		TST_Factory.createPermissionSetAssignments
				(
						new List<User> {apiCallDeleterWithoutIssueApiCall},
						insertApiIssueReadPermissionSetForOneField(API_ISSUE_READ_WITHOUT_API_CALL_PERMISSION_SET_NAME, ApiIssue__c.Status__c)
				);
	}

	/**
	 * @description Saves a permission set that grants read access to API issues and to one of their fields, and to no
	 * other field of an API issue. So a holder can read API issues but not their other fields.
	 *
	 * @param permissionSetName The name and label of the permission set.
	 * @param readableField The one field of an API issue the permission set lets the holder read.
	 *
	 * @return The Id of the saved permission set.
	 */
	private static Id insertApiIssueReadPermissionSetForOneField(String permissionSetName, SObjectField readableField)
	{
		PermissionSet readPermissionSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withOptionalFields(new List<String>(UTIL_SObjectDescribe.getDescribe(PermissionSet.SObjectType).getCreatableRequiredFields()))
				.withOverride(PermissionSet.Name, permissionSetName)
				.withOverride(PermissionSet.Label, permissionSetName)
				.build();
		String apiIssueObjectName = UTIL_SObjectDescribe.getObjectNameFromType(ApiIssue__c.SObjectType);
		SObjectType objectPermissionsType = new ObjectPermissions().getSObjectType();
		TST_Builder.of(objectPermissionsType)
				.withOptionalFields(new List<String>(UTIL_SObjectDescribe.getDescribe(objectPermissionsType).getCreatableRequiredFields()))
				.withOverride(ObjectPermissions.ParentId, readPermissionSet.Id)
				.withOverride(ObjectPermissions.SobjectType, apiIssueObjectName)
				.withOverride(ObjectPermissions.PermissionsRead, true)
				.build();
		SObjectType fieldPermissionsType = new FieldPermissions().getSObjectType();
		TST_Builder.of(fieldPermissionsType)
				.withOptionalFields(new List<String>(UTIL_SObjectDescribe.getDescribe(fieldPermissionsType).getCreatableRequiredFields()))
				.withOverride(FieldPermissions.ParentId, readPermissionSet.Id)
				.withOverride(FieldPermissions.SobjectType, apiIssueObjectName)
				.withOverride(FieldPermissions.Field, apiIssueObjectName + '.' + UTIL_SObjectDescribe.getCachedFieldName(readableField))
				.withOverride(FieldPermissions.PermissionsRead, true)
				.build();
		return readPermissionSet.Id;
	}

	/**
	 * @description Saves a permission set that grants read, edit and delete access to one object and nothing else.
	 *
	 * @param permissionSetName The name and label of the permission set.
	 * @param objectType The object the permission set gives access to.
	 *
	 * @return The Id of the saved permission set.
	 */
	private static Id insertDeleteOnlyPermissionSet(String permissionSetName, SObjectType objectType)
	{
		PermissionSet deleteOnlyPermissionSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withOptionalFields(new List<String>(UTIL_SObjectDescribe.getDescribe(PermissionSet.SObjectType).getCreatableRequiredFields()))
				.withOverride(PermissionSet.Name, permissionSetName)
				.withOverride(PermissionSet.Label, permissionSetName)
				.build();
		SObjectType objectPermissionsType = new ObjectPermissions().getSObjectType();
		TST_Builder.of(objectPermissionsType)
				.withOptionalFields(new List<String>(UTIL_SObjectDescribe.getDescribe(objectPermissionsType).getCreatableRequiredFields()))
				.withOverride(ObjectPermissions.ParentId, deleteOnlyPermissionSet.Id)
				.withOverride(ObjectPermissions.SobjectType, UTIL_SObjectDescribe.getObjectNameFromType(objectType))
				.withOverride(ObjectPermissions.PermissionsRead, true)
				.withOverride(ObjectPermissions.PermissionsEdit, true)
				.withOverride(ObjectPermissions.PermissionsDelete, true)
				.build();
		return deleteOnlyPermissionSet.Id;
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
	 * deletes one in the test. The issue is resolved, because a call with an open issue is never purged.
	 *
	 * @see UTIL_PurgeRecords.deleteAllRecords
	 */
	@IsTest
	private static void shouldPurgeApiCallsAndIssuesForAnAdministrator()
	{
		System.runAs(getTestAdmin())
		{
			ApiCall__c apiCall = (ApiCall__c)TST_Factory.getApiCallBuilder().build();
			ApiIssue__c apiIssue = insertOpenApiIssue(apiCall);
			resolve(apiIssue);

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
	 * @description A purge of API calls leaves out every call that still has an open issue, because the delete guard
	 * would refuse it (TRG_GuardApiCallWithOpenIssue). An administrator purges two calls, one with an open issue and one
	 * without. The call without an issue is deleted. The call with the open issue is kept, its issue is still open, and
	 * the purge logs no refusal for it.
	 *
	 * @see UTIL_PurgeRecords.deleteAllRecords
	 */
	@IsTest
	private static void shouldLeaveCallsWithAnOpenIssueOutOfThePurge()
	{
		LOG_Builder.ignoreTestMode = true;
		System.runAs(getTestAdmin())
		{
			List<ApiCall__c> apiCalls = TST_Factory.getApiCallBuilder().withCount(2).buildList();
			ApiCall__c callWithOpenIssue = apiCalls[0];
			ApiCall__c callWithoutIssue = apiCalls[1];
			ApiIssue__c openIssue = insertOpenApiIssue(callWithOpenIssue);

			Test.startTest();
			UTIL_PurgeRecords.deleteAllRecords(ApiCall__c.SObjectType);
			Test.stopTest();

			Assert.isNotNull(new SEL_ApiCall().findById(callWithOpenIssue.Id), 'Expected the API call with an open issue to be kept');
			Assert.isNull(new SEL_ApiCall().findById(callWithoutIssue.Id), 'Expected the API call without an issue to be purged');
			ApiIssue__c keptIssue = (ApiIssue__c)new SEL_ApiIssue().findById(openIssue.Id);
			Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, keptIssue.Status__c, 'Expected the issue to still be open');
			LogEntry__c refusal = findOpenIssueRefusal();
			Assert.isNull(refusal, 'Expected the purge to log no refusal for the call with an open issue, got ' + refusal?.Message__c);
		}
	}

	/**
	 * @description Once the issue of an API call is resolved, the purge no longer leaves the call out: an administrator
	 * purges API calls and the call is deleted.
	 *
	 * @see UTIL_PurgeRecords.deleteAllRecords
	 */
	@IsTest
	private static void shouldPurgeACallOnceItsIssueIsResolved()
	{
		System.runAs(getTestAdmin())
		{
			ApiCall__c apiCall = (ApiCall__c)TST_Factory.getApiCallBuilder().build();
			resolve(insertOpenApiIssue(apiCall));

			Test.startTest();
			UTIL_PurgeRecords.deleteAllRecords(ApiCall__c.SObjectType);
			Test.stopTest();

			Assert.isNull(new SEL_ApiCall().findById(apiCall.Id), 'Expected the API call with a resolved issue to be purged');
		}
	}

	/**
	 * @description The purge of old API calls leaves out every old call that still has an open issue, as the purge of all
	 * calls does. An administrator purges API calls older than a number of days. There are two old calls, one with an
	 * open issue and one without, and one recent call. Only the old call without an issue is deleted. The old call with
	 * the open issue is kept, its issue is still open, and the purge logs no refusal for it, which shows that the purge
	 * left it out instead of trying to delete it. The recent call is kept because it is not old enough.
	 *
	 * @see UTIL_PurgeRecords.deleteOlderThanNDays
	 */
	@IsTest
	private static void shouldLeaveOldCallsWithAnOpenIssueOutOfThePurgeOfOldCalls()
	{
		LOG_Builder.ignoreTestMode = true;
		System.runAs(getTestAdmin())
		{
			List<ApiCall__c> apiCalls = TST_Factory.getApiCallBuilder().withCount(3).buildList();
			ApiCall__c oldCallWithOpenIssue = apiCalls[0];
			ApiCall__c oldCallWithoutIssue = apiCalls[1];
			ApiCall__c recentCall = apiCalls[2];
			Test.setCreatedDate(oldCallWithOpenIssue.Id, Datetime.now().addDays(-DELETE_AFTER_DAYS));
			Test.setCreatedDate(oldCallWithoutIssue.Id, Datetime.now().addDays(-DELETE_AFTER_DAYS));
			ApiIssue__c openIssue = insertOpenApiIssue(oldCallWithOpenIssue);

			Test.startTest();
			UTIL_PurgeRecords.deleteOlderThanNDays(ApiCall__c.SObjectType, DELETE_AFTER_DAYS);
			Test.stopTest();

			Assert.isNotNull(new SEL_ApiCall().findById(oldCallWithOpenIssue.Id), 'Expected the old API call with an open issue to be kept');
			Assert.isNull(new SEL_ApiCall().findById(oldCallWithoutIssue.Id), 'Expected the old API call without an issue to be purged');
			Assert.isNotNull(new SEL_ApiCall().findById(recentCall.Id), 'Expected the recent API call to be kept');
			ApiIssue__c keptIssue = (ApiIssue__c)new SEL_ApiIssue().findById(openIssue.Id);
			Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, keptIssue.Status__c, 'Expected the issue to still be open');
			LogEntry__c refusal = findOpenIssueRefusal();
			Assert.isNull(refusal, 'Expected the purge to log no refusal for the old call with an open issue, got ' + refusal?.Message__c);
		}
	}

	/**
	 * @description Dismissing an issue marks it resolved without running its request again, and so frees its call for
	 * the purge. An administrator dismisses the open issue of an API call through the Dismiss action, then purges API
	 * calls, and the call is deleted.
	 *
	 * @see CTRL_RetryApiIssue.dismiss
	 * @see UTIL_PurgeRecords.deleteAllRecords
	 */
	@IsTest
	private static void shouldFreeACallForThePurgeOnceItsIssueIsDismissed()
	{
		System.runAs(getTestAdmin())
		{
			ApiCall__c apiCall = (ApiCall__c)TST_Factory.getApiCallBuilder().build();
			ApiIssue__c apiIssue = insertOpenApiIssue(apiCall);
			CTRL_RetryApiIssue.DTO_Response dismissResponse = CTRL_RetryApiIssue.dismiss(apiIssue.Id);
			Assert.isTrue(dismissResponse.callSuccessful, 'Expected the issue to be dismissed');

			Test.startTest();
			UTIL_PurgeRecords.deleteAllRecords(ApiCall__c.SObjectType);
			Test.stopTest();

			Assert.isNull(new SEL_ApiCall().findById(apiCall.Id), 'Expected the API call with a dismissed issue to be purged');
		}
	}

	/**
	 * @description Your org turns the BypassApiRecordDeleteGuard feature flag on for every user. A Minimum Access user who
	 * may delete API calls but cannot read API issues purges API calls. The purge must read API issues to leave out the
	 * calls that still have an open issue, so for this user it does not start: it throws nothing, deletes nothing and logs
	 * a warning at warn level that says the user cannot read API issues.
	 *
	 * @see UTIL_PurgeRecords.deleteAllRecords
	 */
	@IsTest
	private static void shouldSkipThePurgeOfApiCallsForAUserWhoCannotReadApiIssues()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.newFeatureFlag(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD);

		ApiCall__c apiCall = insertApiCallAndPurgeApiCallsAs(getApiCallDeleter());

		Assert.isNotNull(new SEL_ApiCall().findById(apiCall.Id), 'Expected the API call to be kept');
		LogEntry__c warning = findPurgeOfAllRecordsLogEntry();
		Assert.isNotNull(warning, 'Expected a warning that says the user cannot read API issues, got no log entry from the purge');
		Assert.areEqual(LoggingLevel.WARN.name(), warning.LogLevel__c, 'Expected the purge to log at warn, got ' + warning.LogLevel__c + ': ' + warning.Message__c);
		Assert.isTrue
				(
						warning.Message__c.contains(System.Label.DeleteApiCalls_ApiIssueReadAccessRequired),
						'Expected the message that the user cannot read API issues, got ' + warning.Message__c
				);
	}

	/**
	 * @description Read access to API issues is not enough: the purge of API calls also needs read access to the Status
	 * field of an API issue, because its query filters the issues on that field. Your org turns the
	 * BypassApiRecordDeleteGuard feature flag on for every user. A Minimum Access user who may delete API calls and can
	 * read API issues and their API Call field, but not their Status field, purges API calls. The purge does not start:
	 * it throws nothing, deletes nothing and logs a warning at warn level that says the user cannot read API issues.
	 *
	 * @see UTIL_PurgeRecords.deleteAllRecords
	 */
	@IsTest
	private static void shouldSkipThePurgeOfApiCallsForAUserWhoCannotReadTheStatusOfApiIssues()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.newFeatureFlag(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD);

		ApiCall__c apiCall = insertApiCallAndPurgeApiCallsAs(new SEL_User().findByCompanyName(API_CALL_DELETER_WITHOUT_ISSUE_STATUS_ACCESS_COMPANY));

		Assert.isNotNull(new SEL_ApiCall().findById(apiCall.Id), 'Expected the API call to be kept');
		LogEntry__c warning = findPurgeOfAllRecordsLogEntry();
		Assert.isNotNull(warning, 'Expected a warning that says the user cannot read API issues, got no log entry from the purge');
		Assert.areEqual(LoggingLevel.WARN.name(), warning.LogLevel__c, 'Expected the purge to log at warn, got ' + warning.LogLevel__c + ': ' + warning.Message__c);
		Assert.isTrue
				(
						warning.Message__c.contains(System.Label.DeleteApiCalls_ApiIssueReadAccessRequired),
						'Expected the message that the user cannot read API issues, got ' + warning.Message__c
				);
	}

	/**
	 * @description Read access to API issues and to their Status field is not enough: the purge of API calls also needs
	 * read access to the API Call field of an API issue, because its query returns the calls the issues point to. Your org
	 * turns the BypassApiRecordDeleteGuard feature flag on for every user. A Minimum Access user who may delete API calls
	 * and can read API issues and their Status field, but not their API Call field, purges API calls. The purge does not
	 * start: it throws nothing, deletes nothing and logs a warning at warn level that says the user cannot read API
	 * issues.
	 *
	 * @see UTIL_PurgeRecords.deleteAllRecords
	 */
	@IsTest
	private static void shouldSkipThePurgeOfApiCallsForAUserWhoCannotReadTheApiCallOfApiIssues()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.newFeatureFlag(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD);

		ApiCall__c apiCall = insertApiCallAndPurgeApiCallsAs(new SEL_User().findByCompanyName(API_CALL_DELETER_WITHOUT_ISSUE_API_CALL_ACCESS_COMPANY));

		Assert.isNotNull(new SEL_ApiCall().findById(apiCall.Id), 'Expected the API call to be kept');
		LogEntry__c warning = findPurgeOfAllRecordsLogEntry();
		Assert.isNotNull(warning, 'Expected a warning that says the user cannot read API issues, got no log entry from the purge');
		Assert.areEqual(LoggingLevel.WARN.name(), warning.LogLevel__c, 'Expected the purge to log at warn, got ' + warning.LogLevel__c + ': ' + warning.Message__c);
		Assert.isTrue
				(
						warning.Message__c.contains(System.Label.DeleteApiCalls_ApiIssueReadAccessRequired),
						'Expected the message that the user cannot read API issues, got ' + warning.Message__c
				);
	}

	/**
	 * @description Runs as the given user: saves an inbound API call in system mode, then purges every API call.
	 *
	 * @param user The user who saves the call and runs the purge.
	 *
	 * @return The saved API call.
	 */
	private static ApiCall__c insertApiCallAndPurgeApiCallsAs(User user)
	{
		ApiCall__c apiCall;
		System.runAs(user)
		{
			apiCall = TST_Factory.newInboundApiCall(API_Echo.class.getName());
			insertInSystemMode(apiCall);

			Test.startTest();
			UTIL_PurgeRecords.deleteAllRecords(ApiCall__c.SObjectType);
			Test.stopTest();
		}
		return apiCall;
	}

	/**
	 * @description Reads the log entry that the purge of all records wrote, for example the warning it logs when the user
	 * cannot read API issues.
	 *
	 * @return The log entry, or null when the purge of all records logged nothing.
	 */
	private static LogEntry__c findPurgeOfAllRecordsLogEntry()
	{
		return new SEL_LogEntry().findByMethod(UTIL_PurgeRecords.class.getName() + '/deleteAllRecords');
	}

	/**
	 * @description Reads the first log entry that holds the message the delete guard logs when it refuses to delete an
	 * API call that has an open issue.
	 *
	 * @return The log entry, or null when no such refusal was logged.
	 */
	private static LogEntry__c findOpenIssueRefusal()
	{
		for(LogEntry__c logEntry : new SEL_LogEntry().getAll())
		{
			if(String.valueOf(logEntry.Message__c).contains(System.Label.DeleteApiCall_OpenIssue))
			{
				return logEntry;
			}
		}
		return null;
	}

	/**
	 * @description The same user, who may delete API calls but cannot read API issues, deletes an API call that has an
	 * open issue. The delete guard reads the open issues without the user's access, so it still finds the issue: the
	 * delete is refused with the open-issue message, and the call is kept.
	 *
	 * @see TRG_GuardApiCallWithOpenIssue
	 */
	@IsTest
	private static void shouldRefuseTheDeleteOfACallWithAnOpenIssueForAUserWhoCannotReadApiIssues()
	{
		TST_Factory.newFeatureFlag(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD);
		ApiCall__c apiCall;
		System.runAs(getApiCallDeleter())
		{
			apiCall = TST_Factory.newInboundApiCall(API_Echo.class.getName());
			insertInSystemMode(apiCall);
			insertInSystemMode(TST_Factory.newApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(UTIL_Random.randomName())));

			Test.startTest();
			try
			{
				DML_Builder.newTransaction().doDelete(apiCall).execute();
				Assert.fail('Expected the delete to be refused');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, 'Expected a refused delete, got ' + error.getTypeName() + ': ' + error.getMessage());
				Assert.isTrue(error.getMessage().contains(System.Label.DeleteApiCall_OpenIssue), 'Expected the open-issue refusal, got ' + error.getMessage());
			}
			Test.stopTest();
		}

		Assert.isNotNull(new SEL_ApiCall().findById(apiCall.Id), 'Expected the API call with an open issue to be kept');
	}

	/**
	 * @description Saves a record in system mode, because the user who cannot read API issues may not create an API call
	 * or an API issue. The record is owned by the running user.
	 *
	 * @param record The record to save.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static void insertInSystemMode(SObject record)
	{
		DML_Builder.newTransaction().withSystemMode().doInsert(record).execute();
	}

	/**
	 * @description Saves an open issue for the given API call.
	 *
	 * @param apiCall The saved API call the issue belongs to.
	 *
	 * @return The saved open API issue.
	 */
	private static ApiIssue__c insertOpenApiIssue(ApiCall__c apiCall)
	{
		return TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(UTIL_Random.randomName()));
	}

	/**
	 * @description Marks the given issue resolved and saves it.
	 *
	 * @param apiIssue The saved API issue to resolve.
	 */
	private static void resolve(ApiIssue__c apiIssue)
	{
		apiIssue.Status__c = SEL_ApiIssue.STATUS_RESOLVED;
		DML_Builder.newTransaction().doUpdate(apiIssue).execute();
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

	/**
	 * @description Retrieves the committed Minimum Access user set up in @TestSetup who may delete API calls but cannot
	 * read API issues.
	 *
	 * @return The User record of that user.
	 */
	private static User getApiCallDeleter()
	{
		return new SEL_User().findByCompanyName(API_CALL_DELETER_WITHOUT_ISSUE_ACCESS_COMPANY);
	}
}