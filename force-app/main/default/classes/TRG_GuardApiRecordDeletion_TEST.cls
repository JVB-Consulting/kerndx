// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for TRG_GuardApiRecordDeletion, the trigger action that refuses the delete of an API call or an
 * API issue. The trigger framework runs it only for a user the BypassApiRecordDeleteGuard feature flag is off for, and a
 * built-in rule turns that flag on for every user who holds the Delete API Records custom permission.
 *
 * One test calls the action directly on rows built in memory and reads the result from the rows' own errors. The others
 * delete saved rows through the trigger, with the real flag and its built-in rule, to prove that a user without the
 * permission is refused, that the files of a refused API call are kept, and that an administrator can still delete. One
 * more turns the flag on for every user, the way your org can widen it, and proves a user without the permission then
 * deletes. Another takes the flag out of the active flags, as deactivating its record does, and proves that even an
 * administrator is then refused.
 *
 * The trigger framework decides the flag once in a transaction, for the user who first fires a trigger on the object,
 * and keeps that answer. So every test saves its records inside the System.runAs block of the user who deletes them: a
 * record saved first as the user who runs the test would fix the answer for that user instead.
 *
 * @see TRG_GuardApiRecordDeletion
 * @see TRG_DeleteApiCallDocuments
 * @see UTIL_FeatureFlag
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexUnitTestClassShouldHaveAsserts,PMD.KernNoStandardObjectInPackageTests')
@IsTest(seeAllData=false isParallel=false)
private class TRG_GuardApiRecordDeletion_TEST
{
	/**
	 * @description Company name of the test user who holds only the Kern API Issue Resolver permission set: a Standard
	 * User who can see and retry every issue, and must not be able to delete one.
	 */
	private static final String API_ISSUE_RESOLVER_USER_COMPANY = 'TRG_GuardApiRecordDeletion_TEST-resolver';

	/**
	 * @description Company name of the test user who holds only the Kern Administrator permission set, which grants the
	 * Delete API Records permission.
	 */
	private static final String ADMINISTRATOR_USER_COMPANY = 'TRG_GuardApiRecordDeletion_TEST-administrator';

	/**
	 * @description Creates two Standard Users: one who holds only the Kern API Issue Resolver permission set and one who
	 * holds only the Kern Administrator permission set. They are created in setup so that System.runAs checks their
	 * permissions afresh in each test.
	 */
	@TestSetup
	private static void setupUsers()
	{
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, API_ISSUE_RESOLVER_USER_COMPANY, CTRL_RetryApiIssue.API_ISSUE_RESOLVER_PERMISSION_SET_NAME);
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, ADMINISTRATOR_USER_COMPANY, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);
	}

	/**
	 * @description The action is given an API issue and an API call to delete. It refuses both with the labelled message,
	 * whoever runs it: deciding who may delete is the job of the feature flag, which makes the trigger framework skip the
	 * action for a user the flag is on for.
	 */
	@IsTest
	private static void shouldRefuseEveryApiIssueAndApiCallItIsGiven()
	{
		ApiIssue__c apiIssue = (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType).withoutInsertion().build();
		ApiCall__c apiCall = (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType).withoutInsertion().build();

		new TRG_GuardApiRecordDeletion().beforeDelete(new List<SObject> {apiIssue, apiCall});

		assertRefused(apiIssue);
		assertRefused(apiCall);
	}

	/**
	 * @description A resolver owns an API issue and deletes it in system mode, so neither record sharing nor object access
	 * stops the delete: only the trigger can. The flag is as the package ships it, and the resolver does not hold the
	 * Delete API Records permission, so the flag is off for them. The delete fails with the labelled message and the
	 * issue is still there.
	 */
	@IsTest
	private static void shouldRefuseAResolverWhoDeletesAnApiIssueThroughTheTrigger()
	{
		assertApiIssueDeleteRefusedFor(getUserWithApiIssueResolverPermissionSet());
	}

	/**
	 * @description Your org turns the flag on for every user, one of the two ways to widen it. A resolver, who does not
	 * hold the Delete API Records permission, deletes an API issue they own in system mode. The trigger framework skips
	 * the guard, so the delete goes through and the issue is gone.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldLetAResolverDeleteAnApiIssueWhenTheFlagIsOnForEveryUser()
	{
		User resolver = getUserWithApiIssueResolverPermissionSet();
		TST_Factory.newFeatureFlag(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD);

		System.runAs(resolver)
		{
			ApiIssue__c apiIssue = insertApiIssueOwnedByTheRunningUser();

			Test.startTest();
			DML_Builder.newTransaction().withSystemMode().doDelete(apiIssue).execute();
			Test.stopTest();

			Assert.isNull(new SEL_ApiIssue().findById(apiIssue.Id), 'Expected the API issue to be deleted');
		}
	}

	/**
	 * @description A user with the Kern Administrator permission set, which grants the Delete API Records permission,
	 * deletes an API issue. The flag's built-in rule turns the flag on for that user, so the trigger framework skips the
	 * guard and the issue is gone. Nothing in the test changes the flag.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldLetAnAdministratorDeleteAnApiIssue()
	{
		System.runAs(getAdministrator())
		{
			ApiIssue__c apiIssue = insertApiIssueOwnedByTheRunningUser();

			Test.startTest();
			DML_Builder.newTransaction().doDelete(apiIssue).execute();
			Test.stopTest();

			Assert.isNull(new SEL_ApiIssue().findById(apiIssue.Id), 'Expected the API issue to be deleted');
		}
	}

	/**
	 * @description When the BypassApiRecordDeleteGuard feature flag record is deactivated, the flag is off for everyone,
	 * even for a user who holds the Delete API Records permission. The test takes the flag out of the active flags, the
	 * way deactivating its record does, before anything is saved. Then a user with the Kern Administrator permission set
	 * deletes an API issue they own, and the delete fails with the labelled message: nobody can delete until the flag is
	 * active again.
	 */
	@IsTest
	private static void shouldRefuseAnAdministratorWhenTheDeleteFlagIsDeactivated()
	{
		SEL_FeatureFlag.activeFlags.remove(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD);

		assertApiIssueDeleteRefusedFor(getAdministrator());
	}

	/**
	 * @description A resolver owns an API call with a file and deletes the call in system mode. The guard runs before the
	 * action that deletes the call's files, and a refused delete undoes everything the delete started: the call fails with
	 * the labelled message, and both the call and its file are still there.
	 */
	@IsTest
	private static void shouldKeepTheFilesOfAnApiCallWhoseDeleteIsRefused()
	{
		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			ApiCall__c apiCall = insertApiCallWithFile();

			Test.startTest();
			assertDeleteRefused(apiCall);
			Test.stopTest();

			Assert.isNotNull(new SEL_ApiCall().findById(apiCall.Id), 'Expected the API call to still be there');
			Assert.areEqual(1, new SEL_ContentVersion().getAll().size(), 'Expected the file of the refused API call to be kept');
		}
	}

	/**
	 * @description A user with the Kern Administrator permission set deletes an API call with a file. The flag's built-in
	 * rule turns the flag on for that user, so the guard does not run, and the file clean-up still runs: the call and its
	 * file are both gone.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldDeleteAnApiCallAndItsFilesForAnAdministrator()
	{
		System.runAs(getAdministrator())
		{
			ApiCall__c apiCall = insertApiCallWithFile();

			Test.startTest();
			DML_Builder.newTransaction().doDelete(apiCall).execute();
			Test.stopTest();

			Assert.isNull(new SEL_ApiCall().findById(apiCall.Id), 'Expected the API call to be deleted');
			Assert.isTrue(new SEL_ContentVersion().getAll().isEmpty(), 'Expected the file of the deleted API call to be deleted too');
		}
	}

	/**
	 * @description Saves an API call owned by the running user, in system mode because a resolver may not create one,
	 * and saves one file on it.
	 *
	 * @return The saved API call.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static ApiCall__c insertApiCallWithFile()
	{
		ApiCall__c apiCall = TST_Factory.newInboundApiCall(API_Echo.class.getName());
		DML_Builder.newTransaction().withSystemMode().doInsert(apiCall).execute();

		ContentVersion newVersion = TST_Factory.newContentVersion(null);
		newVersion.FirstPublishLocationId = apiCall.Id;
		DML_Builder.newTransaction().doInsert(newVersion).execute();
		return apiCall;
	}

	/**
	 * @description Saves an API issue, and the failed API call it records, owned by the running user. API issues are
	 * private, so a user can delete only an issue they own, even in system mode, which skips object and field access but
	 * not record sharing.
	 *
	 * @return The saved API issue.
	 */
	private static ApiIssue__c insertApiIssueOwnedByTheRunningUser()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		return TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));
	}

	/**
	 * @description Finds the test user who holds only the Kern API Issue Resolver permission set, and asserts that the
	 * flag is off for this user as the package ships it. An org that turned the flag on for this user, or gave the Delete
	 * API Records permission to every Standard User, has no user to test the refusal against, and the assertion says so.
	 *
	 * @return The resolver.
	 */
	private static User getUserWithApiIssueResolverPermissionSet()
	{
		User resolver = new SEL_User().findByCompanyName(API_ISSUE_RESOLVER_USER_COMPANY);
		Assert.isFalse
				(
						UTIL_FeatureFlag.isEnabled(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD, resolver.Id),
						'Expected the ' + API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD +
						' feature flag to be off for a Standard User with only the resolver permission set'
				);
		return resolver;
	}

	/**
	 * @description Finds the test user who holds only the Kern Administrator permission set.
	 *
	 * @return The administrator.
	 */
	private static User getAdministrator()
	{
		return new SEL_User().findByCompanyName(ADMINISTRATOR_USER_COMPANY);
	}

	/**
	 * @description Saves an API issue owned by the given user, then, as that user, deletes it in system mode and asserts
	 * the delete fails with the labelled refusal and the issue is still there.
	 *
	 * @param deleter The user who saves and deletes the issue.
	 */
	private static void assertApiIssueDeleteRefusedFor(User deleter)
	{
		System.runAs(deleter)
		{
			ApiIssue__c apiIssue = insertApiIssueOwnedByTheRunningUser();

			Test.startTest();
			assertDeleteRefused(apiIssue);
			Test.stopTest();

			Assert.isNotNull(new SEL_ApiIssue().findById(apiIssue.Id), 'Expected the API issue to still be there');
		}
	}

	/**
	 * @description Deletes a saved record in system mode, so neither object access nor field access can stop it, and
	 * asserts the delete fails with the labelled refusal.
	 *
	 * @param record The saved API call or API issue to delete.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static void assertDeleteRefused(SObject record)
	{
		try
		{
			DML_Builder.newTransaction().withSystemMode().doDelete(record).execute();
			Assert.fail('Expected the delete to be refused');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Expected a refused save, got ' + error.getTypeName());
			Assert.isTrue(error.getMessage().contains(System.Label.DeleteApiRecords_PermissionRequired), 'Expected the labelled refusal, got ' + error.getMessage());
		}
	}

	/**
	 * @description Asserts the action refused the row with exactly one error carrying the labelled message.
	 *
	 * @param record The row the action was given.
	 */
	private static void assertRefused(SObject record)
	{
		Assert.isTrue(record.hasErrors(), 'Expected the action to refuse the delete');
		List<Database.Error> recordErrors = record.getErrors();
		Assert.areEqual(1, recordErrors.size(), 'Expected exactly one error on the refused row');
		Assert.areEqual(System.Label.DeleteApiRecords_PermissionRequired, recordErrors.iterator().next().getMessage(), 'Expected the refusal to carry the label text');
	}
}
