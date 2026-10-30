// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests for TRG_GuardApiCallWithOpenIssue, the trigger action that refuses the delete of an API call that
 * still has an open API issue. It refuses every user: a holder of the Delete API Records permission, and a System
 * Administrator the Bypass API Record Delete Guard feature flag is on for.
 *
 * Some tests delete saved calls through the trigger. The others call the action directly on saved calls, to count the
 * queries it makes and to reach the case where no query is left, which a delete through the trigger cannot reach: the
 * action that deletes a call's files runs after this one and needs a query of its own.
 *
 * The trigger framework decides the feature flag once in a transaction, for the user who first fires a trigger on the
 * object. So every test that deletes through the trigger saves its records inside the System.runAs block of the user
 * who deletes them.
 *
 * @see TRG_GuardApiCallWithOpenIssue
 * @see TRG_GuardApiRecordDeletion
 * @see SEL_ApiIssue
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.KernNoStandardObjectInPackageTests')
@IsTest(seeAllData=false isParallel=false)
private class TRG_GuardApiCallWithOpenIssue_TEST
{
	/**
	 * @description Company name of the Standard User who holds only the Kern Administrator permission set, which grants
	 * the Delete API Records permission.
	 */
	private static final String DELETE_PERMISSION_HOLDER_COMPANY = 'TRG_GuardApiCallWithOpenIssue_TEST-holder';

	/**
	 * @description Company name of the System Administrator who also holds the Kern Administrator permission set.
	 */
	private static final String SYSTEM_ADMINISTRATOR_COMPANY = 'TRG_GuardApiCallWithOpenIssue_TEST-system-administrator';

	/**
	 * @description Company name of the Standard User who holds only the Kern API Issue Resolver permission set. This user
	 * does not hold the Delete API Records permission, so the permission check refuses every delete they make.
	 */
	private static final String RESOLVER_COMPANY = 'TRG_GuardApiCallWithOpenIssue_TEST-resolver';

	/**
	 * @description Number of API calls in one delete batch: the most a trigger receives at once.
	 */
	private static final Integer BATCH_SIZE = 200;

	/**
	 * @description Creates the three users. They are created in setup so that System.runAs checks their permissions
	 * afresh in each test.
	 */
	@TestSetup
	private static void setupUsers()
	{
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, DELETE_PERMISSION_HOLDER_COMPANY, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_SYSTEM_ADMIN, SYSTEM_ADMINISTRATOR_COMPANY, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, RESOLVER_COMPANY, CTRL_RetryApiIssue.API_ISSUE_RESOLVER_PERMISSION_SET_NAME);
	}

	/**
	 * @description A user without the Delete API Records permission deletes an API call that has an open issue and a
	 * file. The permission check runs first, so the user sees its message and not the open-issue message. The action
	 * that deletes the call's files runs after both checks, and the refused delete is undone as a whole, so the call,
	 * its issue and its file are all still there.
	 */
	@IsTest
	private static void shouldShowThePermissionRefusalAndKeepTheCallItsIssueAndItsFileWhenTheUserMayNotDelete()
	{
		User resolver = new SEL_User().findByCompanyName(RESOLVER_COMPANY);
		Assert.isFalse
				(
						UTIL_FeatureFlag.isEnabled(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD, resolver.Id),
						'Expected the ' + API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD + ' feature flag to be off for the resolver'
				);

		System.runAs(resolver)
		{
			ApiCall__c callWithOpenIssue = insertApiCallWithFile();
			ApiIssue__c openIssue = insertApiIssue(callWithOpenIssue, SEL_ApiIssue.STATUS_OPEN);

			Test.startTest();
			assertDeleteRefusedForPermission(callWithOpenIssue);
			Test.stopTest();

			Assert.isNotNull(new SEL_ApiCall().findById(callWithOpenIssue.Id), 'Expected the API call to still be there');
			ApiIssue__c keptIssue = (ApiIssue__c)new SEL_ApiIssue().findById(openIssue.Id);
			Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, keptIssue.Status__c, 'Expected the issue to still be open');
			Assert.areEqual(1, new SEL_ContentVersion().findByFirstPublishLocationId(callWithOpenIssue.Id).size(), 'Expected the file of the refused call to be kept');
		}
	}

	/**
	 * @description A user who holds the Delete API Records permission may delete API calls, but not one with an open
	 * issue. The delete fails with the labelled message, and the call and its issue are still there.
	 */
	@IsTest
	private static void shouldRefuseToDeleteACallWithAnOpenIssueForAHolderOfDeleteApiRecords()
	{
		ApiIssue__c openIssue = deleteCallWithOpenIssueAs(new SEL_User().findByCompanyName(DELETE_PERMISSION_HOLDER_COMPANY));

		Assert.isNotNull(new SEL_ApiCall().findById(openIssue.ApiCall__c), 'Expected the API call to still be there');
		ApiIssue__c keptIssue = (ApiIssue__c)new SEL_ApiIssue().findById(openIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, keptIssue.Status__c, 'Expected the issue to still be open');
	}

	/**
	 * @description The Bypass API Record Delete Guard feature flag is on for every user, and a System Administrator
	 * deletes an API call with an open issue. The flag lifts only the permission check: this action reads no flag, so the
	 * delete still fails with the labelled message and the call is still there.
	 */
	@IsTest
	private static void shouldRefuseToDeleteACallWithAnOpenIssueForAnAdministratorWithTheBypassOn()
	{
		User systemAdministrator = new SEL_User().findByCompanyName(SYSTEM_ADMINISTRATOR_COMPANY);
		TST_Factory.newFeatureFlag(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD);
		Assert.isTrue
				(
						UTIL_FeatureFlag.isEnabled(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD, systemAdministrator.Id),
						'Expected the ' + API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD + ' feature flag to be on for the System Administrator'
				);

		ApiIssue__c openIssue = deleteCallWithOpenIssueAs(systemAdministrator);

		Assert.isNotNull(new SEL_ApiCall().findById(openIssue.ApiCall__c), 'Expected the API call to still be there');
		ApiIssue__c keptIssue = (ApiIssue__c)new SEL_ApiIssue().findById(openIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, keptIssue.Status__c, 'Expected the issue to still be open');
	}

	/**
	 * @description An API call whose only issue is resolved has nothing left to deal with, so the holder of the Delete
	 * API Records permission deletes it and the call is gone.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldDeleteACallWhoseIssueIsResolved()
	{
		System.runAs(new SEL_User().findByCompanyName(DELETE_PERMISSION_HOLDER_COMPANY))
		{
			ApiCall__c apiCall = (ApiCall__c)TST_Factory.getApiCallBuilder().build();
			insertApiIssue(apiCall, SEL_ApiIssue.STATUS_RESOLVED);

			Test.startTest();
			DML_Builder.newTransaction().withSystemMode().doDelete(apiCall).execute();
			Test.stopTest();

			Assert.isNull(new SEL_ApiCall().findById(apiCall.Id), 'Expected the API call with a resolved issue to be deleted');
		}
	}

	/**
	 * @description A delete that allows some rows to fail is given two API calls, one with an open issue and one without.
	 * Only the call with the open issue is refused, with the labelled message, and kept. The other call is deleted.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldKeepOnlyTheRefusedCallInAPartialDelete()
	{
		System.runAs(new SEL_User().findByCompanyName(DELETE_PERMISSION_HOLDER_COMPANY))
		{
			List<ApiCall__c> apiCalls = TST_Factory.getApiCallBuilder().withCount(2).buildList();
			ApiCall__c callWithOpenIssue = apiCalls[0];
			ApiCall__c callWithoutIssue = apiCalls[1];
			insertApiIssue(callWithOpenIssue, SEL_ApiIssue.STATUS_OPEN);

			Test.startTest();
			DML_Builder.TransactionResult result = DML_Builder.newTransaction().withSystemMode().allowPartial().doDelete(apiCalls).execute();
			Test.stopTest();

			Assert.areEqual(1, result.getFailureCount(), 'Expected exactly one refused API call');
			Assert.areEqual(System.Label.DeleteApiCall_OpenIssue, result.getErrors().iterator().next().getMessage(), 'Expected the refusal to carry the label text');
			Assert.isNotNull(new SEL_ApiCall().findById(callWithOpenIssue.Id), 'Expected the API call with an open issue to be kept');
			Assert.isNull(new SEL_ApiCall().findById(callWithoutIssue.Id), 'Expected the API call without an issue to be deleted');
		}
	}

	/**
	 * @description The action is given a full batch of saved API calls. Two of them have an open issue, and one more has
	 * only a resolved issue. The action makes exactly one query for the whole batch, and refuses only the two calls with
	 * an open issue.
	 */
	@IsTest
	private static void shouldReadOpenIssuesOncePerBatch()
	{
		List<ApiCall__c> apiCalls = TST_Factory.getApiCallBuilder().withCount(BATCH_SIZE).buildList();
		insertApiIssue(apiCalls[0], SEL_ApiIssue.STATUS_OPEN);
		insertApiIssue(apiCalls[1], SEL_ApiIssue.STATUS_OPEN);
		insertApiIssue(apiCalls[2], SEL_ApiIssue.STATUS_RESOLVED);

		Test.startTest();
		Integer queriesBefore = UTIL_Limits.soqlQueries().used();
		new TRG_GuardApiCallWithOpenIssue().beforeDelete(apiCalls);
		Integer queriesUsed = UTIL_Limits.soqlQueries().used() - queriesBefore;
		Test.stopTest();

		Assert.areEqual(1, queriesUsed, 'Expected one query for the whole batch');
		Integer refusedCount = 0;
		for(ApiCall__c apiCall : apiCalls)
		{
			if(apiCall.hasErrors())
			{
				assertRefusedOnce(apiCall, System.Label.DeleteApiCall_OpenIssue);
				refusedCount++;
			}
		}
		Assert.areEqual(2, refusedCount, 'Expected only the two calls with an open issue to be refused');
		Assert.isTrue(apiCalls[0].hasErrors() && apiCalls[1].hasErrors(), 'Expected the calls with an open issue to be the refused ones');
	}

	/**
	 * @description When the transaction has no query left, the action cannot check for open issues. It refuses every
	 * call it was given with the labelled message, even a call that has no issue, rather than let a delete through
	 * unchecked.
	 */
	@IsTest
	private static void shouldRefuseEveryCallWhenNoQueryIsLeft()
	{
		List<ApiCall__c> apiCalls = TST_Factory.getApiCallBuilder().withCount(2).buildList();

		Test.startTest();
		useEveryQuery();
		new TRG_GuardApiCallWithOpenIssue().beforeDelete(apiCalls);
		Test.stopTest();

		Assert.isTrue(apiCalls[0].hasErrors() && apiCalls[1].hasErrors(), 'Expected every call to be refused');
		for(ApiCall__c apiCall : apiCalls)
		{
			assertRefusedOnce(apiCall, System.Label.DeleteApiCall_OpenIssue);
		}
	}

	/**
	 * @description The permission check (TRG_GuardApiRecordDeletion) runs first and refuses every call it is given. This
	 * action then has no call left to check: it makes no query and adds no second error, so each call keeps only the
	 * permission message.
	 */
	@IsTest
	private static void shouldNotReadIssuesForCallsAnEarlierActionRefused()
	{
		List<ApiCall__c> apiCalls = TST_Factory.getApiCallBuilder().withCount(2).buildList();
		insertApiIssue(apiCalls[0], SEL_ApiIssue.STATUS_OPEN);
		new TRG_GuardApiRecordDeletion().beforeDelete(apiCalls);

		Test.startTest();
		Integer queriesBefore = UTIL_Limits.soqlQueries().used();
		new TRG_GuardApiCallWithOpenIssue().beforeDelete(apiCalls);
		Integer queriesUsed = UTIL_Limits.soqlQueries().used() - queriesBefore;
		Test.stopTest();

		Assert.areEqual(0, queriesUsed, 'Expected no query when every call is already refused');
		for(ApiCall__c apiCall : apiCalls)
		{
			assertRefusedOnce(apiCall, System.Label.DeleteApiRecords_PermissionRequired);
		}
	}

	/**
	 * @description Saves an API call with an open issue as the given user, then, as that user, deletes the call in system
	 * mode, so neither object access nor field access can stop it. Asserts the delete fails with the labelled message.
	 *
	 * @param deleter The user who saves and deletes the call.
	 *
	 * @return The open issue of the call whose delete was refused.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static ApiIssue__c deleteCallWithOpenIssueAs(User deleter)
	{
		ApiIssue__c apiIssue;
		System.runAs(deleter)
		{
			ApiCall__c apiCall = (ApiCall__c)TST_Factory.getApiCallBuilder().build();
			apiIssue = insertApiIssue(apiCall, SEL_ApiIssue.STATUS_OPEN);

			Test.startTest();
			try
			{
				DML_Builder.newTransaction().withSystemMode().doDelete(apiCall).execute();
				Assert.fail('Expected the delete to be refused');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, 'Expected a refused save, got ' + error.getTypeName());
				Assert.isTrue(error.getMessage().contains(System.Label.DeleteApiCall_OpenIssue), 'Expected the labelled refusal, got ' + error.getMessage());
			}
			Test.stopTest();
		}
		return apiIssue;
	}

	/**
	 * @description Deletes a saved API call in system mode and asserts the permission check refused it: the error carries
	 * the permission message and not the open-issue message.
	 *
	 * @param apiCall The saved API call to delete.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static void assertDeleteRefusedForPermission(ApiCall__c apiCall)
	{
		try
		{
			DML_Builder.newTransaction().withSystemMode().doDelete(apiCall).execute();
			Assert.fail('Expected the delete to be refused');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Expected a refused save, got ' + error.getTypeName());
			Assert.isTrue(error.getMessage().contains(System.Label.DeleteApiRecords_PermissionRequired), 'Expected the permission refusal, got ' + error.getMessage());
			Assert.isFalse(error.getMessage().contains(System.Label.DeleteApiCall_OpenIssue), 'Expected no open-issue refusal, got ' + error.getMessage());
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

		ContentVersion newVersion = TST_Factory.newContentVersion(apiCall.Id, UTIL_Random.randomName(), Blob.valueOf(UTIL_Random.randomDescription()));
		DML_Builder.newTransaction().doInsert(newVersion).execute();
		return apiCall;
	}

	/**
	 * @description Saves an issue for the given API call, with the given status.
	 *
	 * @param apiCall The saved API call the issue belongs to.
	 * @param status The status of the issue: Open or Resolved.
	 *
	 * @return The saved API issue.
	 */
	private static ApiIssue__c insertApiIssue(ApiCall__c apiCall, String status)
	{
		return (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverrides(TST_Factory.newApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(UTIL_Random.randomName())).getPopulatedFieldsAsMap())
				.withOverride(ApiIssue__c.Status__c, status)
				.build();
	}

	/**
	 * @description Runs small queries until the transaction has no query left, and asserts that none is left.
	 */
	private static void useEveryQuery()
	{
		Integer maximumQueries = UTIL_Limits.soqlQueries().maximum();
		for(Integer attempt = 0; attempt < maximumQueries && !UTIL_Limits.soqlQueries().isExhausted(); attempt++)
		{
			new SEL_ApiCall().findById(UTIL_Random.randomId(ApiCall__c.SObjectType));
		}
		Assert.isTrue(UTIL_Limits.soqlQueries().isExhausted(), 'Expected no query to be left');
	}

	/**
	 * @description Asserts the call was refused with exactly one error carrying the given message.
	 *
	 * @param apiCall The call the action was given.
	 * @param expectedMessage The text the one error must carry.
	 */
	private static void assertRefusedOnce(ApiCall__c apiCall, String expectedMessage)
	{
		List<Database.Error> callErrors = apiCall.getErrors();
		Assert.areEqual(1, callErrors.size(), 'Expected exactly one error on the refused call');
		Assert.areEqual(expectedMessage, callErrors.iterator().next().getMessage(), 'Expected the refusal to carry the label text');
	}
}
