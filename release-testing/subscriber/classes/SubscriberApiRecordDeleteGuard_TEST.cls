// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Subscriber-side proof of the delete guard on API issues, through the global surface. API calls and API
 * issues are the history of every call to and from other systems, so only a user the BypassApiRecordDeleteGuard feature
 * flag is on for may delete them. A built-in rule turns that flag on for every holder of the Delete API Records custom
 * permission, which the Kern Administrator permission set grants and the Kern API Issue Resolver set does not.
 *
 * Three checks: a resolver's delete is refused with the labelled message; an administrator's delete goes through; and a
 * purge a resolver starts deletes nothing, starts no job and writes one warning, not one error for each row.
 *
 * The tests assume the package was installed for administrators only. If the Standard User profile holds the Delete API
 * Records permission, no user exists that the guard refuses, and the refusal test fails on that precondition with a
 * message that says so.
 *
 * Each issue is saved by the user who then deletes it, inside their System.runAs: the trigger builds its list of actions
 * once per transaction, for the first user who saves, so an issue the test's running user saved first would drop the
 * guard for every user after it.
 *
 * @see kern.DML_Builder
 * @see kern.UTIL_PurgeRecords
 * @see kern.UTIL_FeatureFlag
 * @see kern.TST_Factory
 * @see kern.TST_Builder
 * @see kern.SEL_ApiIssue
 * @see kern.QRY_Builder
 * @see kern.LOG_Builder
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class SubscriberApiRecordDeleteGuard_TEST
{
	/**
	 * @description The profile both users are created with.
	 */
	private static final String PROFILE_STANDARD_USER = 'Standard User';

	/**
	 * @description The permission set the resolver holds: it can see and retry every issue, but cannot delete one.
	 */
	private static final String API_ISSUE_RESOLVER_PERMISSION_SET = 'ApiIssueResolver';

	/**
	 * @description The permission set the administrator holds; it carries the Delete API Records custom permission.
	 */
	private static final String ADMINISTRATOR_PERMISSION_SET = 'Administrator';

	/**
	 * @description Company name of the resolver, by which the tests find the user setup created.
	 */
	private static final String API_ISSUE_RESOLVER_USER_COMPANY = 'SubscriberApiRecordDeleteGuard_TEST-resolver';

	/**
	 * @description Company name of the administrator, by which the tests find the user setup created.
	 */
	private static final String ADMINISTRATOR_USER_COMPANY = 'SubscriberApiRecordDeleteGuard_TEST-administrator';

	/**
	 * @description The API name of the object the purge is asked to empty, with the package prefix the subscriber org sees.
	 */
	private static final String API_ISSUE_OBJECT_NAME = 'kern__ApiIssue__c';

	/**
	 * @description The feature flag that lets a user delete API records; off for a resolver when the package is installed
	 * for administrators only.
	 */
	private static final String BYPASS_DELETE_GUARD_FLAG = 'BypassApiRecordDeleteGuard';

	/**
	 * @description How many issues the purge test seeds: enough that the purge would run in more than one batch if it
	 * started a job.
	 */
	private static final Integer PURGE_ISSUE_COUNT = 500;

	/**
	 * @description The resolver and the administrator, created in setup so System.runAs starts a fresh permission
	 * evaluation for each test.
	 */
	@TestSetup
	private static void setupUsers()
	{
		kern.TST_Factory.newUserWithPermissionSet(PROFILE_STANDARD_USER, API_ISSUE_RESOLVER_USER_COMPANY, API_ISSUE_RESOLVER_PERMISSION_SET);
		kern.TST_Factory.newUserWithPermissionSet(PROFILE_STANDARD_USER, ADMINISTRATOR_USER_COMPANY, ADMINISTRATOR_PERMISSION_SET);
	}

	/**
	 * @description A resolver saves an issue and deletes it, in system mode so object access does not refuse either
	 * first: the guard refuses the delete with the labelled message, and the issue is still there.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldRefuseAResolverWhoDeletesAnApiIssue()
	{
		User resolver = new kern.SEL_User().findByCompanyName(API_ISSUE_RESOLVER_USER_COMPANY);
		kern__ApiIssue__c issue;

		System.runAs(resolver)
		{
			Assert.isFalse
					(
							kern.UTIL_FeatureFlag.isEnabled(BYPASS_DELETE_GUARD_FLAG, resolver.Id),
							'Expected the delete flag to be off for a resolver: install the package for administrators only, not for all users'
					);
			issue = saveIssueOwnedBy(resolver.Id);
			Test.startTest();
			try
			{
				kern.DML_Builder.newTransaction().withSystemMode().doDelete(issue).execute();
				Assert.fail('Expected the delete guard to refuse the resolver\'s delete');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, 'Expected a refused save, got ' + error.getTypeName());
				Assert.isTrue
						(
								error.getMessage().contains(System.Label.kern.DeleteApiRecords_PermissionRequired),
								'Expected the Delete API Records message, got ' + error.getMessage()
						);
			}
			Test.stopTest();
		}

		Assert.isNotNull(new kern.SEL_ApiIssue().findById(issue.Id), 'Expected the refused issue to still be there');
	}

	/**
	 * @description An administrator, who holds the Delete API Records permission through the Kern Administrator permission
	 * set, saves an issue and deletes it with an ordinary save: the guard lets it through and the issue is gone.
	 */
	@IsTest
	private static void shouldLetAnAdministratorDeleteAnApiIssue()
	{
		User administrator = new kern.SEL_User().findByCompanyName(ADMINISTRATOR_USER_COMPANY);
		kern__ApiIssue__c issue;

		System.runAs(administrator)
		{
			issue = saveIssueOwnedBy(administrator.Id);
			Test.startTest();
			kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction().doDelete(issue).execute();
			Test.stopTest();

			Assert.isTrue(result.isSuccess(), 'Expected the administrator\'s delete to succeed, got ' + result.getErrors());
		}

		Assert.isNull(new kern.SEL_ApiIssue().findById(issue.Id), 'Expected the administrator\'s delete to remove the issue');
	}

	/**
	 * @description A resolver asks the purge to delete every API issue, over five hundred of them: the purge checks the
	 * delete flag once, deletes nothing, starts no job and writes one warning with the Delete API Records message. No
	 * row reaches the delete guard, so no error is written for any row.
	 */
	@IsTest
	private static void shouldDeleteNothingAndWarnOnceWhenAResolverPurgesApiIssues()
	{
		User resolver = new kern.SEL_User().findByCompanyName(API_ISSUE_RESOLVER_USER_COMPANY);
		kern.TST_Builder.of(kern__ApiIssue__c.SObjectType).withCount(PURGE_ISSUE_COUNT).buildList();
		kern.LOG_Builder.ignoreTestMode = true;

		System.runAs(resolver)
		{
			Test.startTest();
			kern.UTIL_PurgeRecords.deleteAllRecords(API_ISSUE_OBJECT_NAME, false, null);
			Test.stopTest();
		}

		Integer remainingCount = new kern.SEL_ApiIssue().count();
		Assert.areEqual(PURGE_ISSUE_COUNT, remainingCount, 'Expected every issue to remain after a resolver\'s purge, got ' + remainingCount);
		Integer warningCount = countEntriesCarryingTheDeleteMessage(LoggingLevel.WARN.name());
		Assert.areEqual(1, warningCount, 'Expected one warning for the whole purge, got ' + warningCount);
		Integer errorCount = countEntriesCarryingTheDeleteMessage(LoggingLevel.ERROR.name());
		Assert.areEqual(0, errorCount, 'Expected no error entry, as no row reached the delete guard, got ' + errorCount);
	}

	/**
	 * @description Saves one open issue owned by the given user, in system mode so that the user can save it inside
	 * their own System.runAs without create access on the object.
	 *
	 * @param ownerId The user who owns the issue.
	 *
	 * @return The saved issue.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static kern__ApiIssue__c saveIssueOwnedBy(Id ownerId)
	{
		kern__ApiIssue__c issue = (kern__ApiIssue__c)kern.TST_Builder.of(kern__ApiIssue__c.SObjectType)
				.withOverride(kern__ApiIssue__c.OwnerId, ownerId)
				.withoutInsertion()
				.build();
		kern.DML_Builder.newTransaction().withSystemMode().doInsert(issue).execute();
		return issue;
	}

	/**
	 * @description Counts the saved log entries at the given level whose message carries the Delete API Records text. The
	 * message is a long text field, which a query cannot filter on, so the level is filtered in the query and the message
	 * here.
	 *
	 * @param logLevel The level to count, as the log entry stores it.
	 *
	 * @return How many entries at that level carry the message.
	 */
	private static Integer countEntriesCarryingTheDeleteMessage(String logLevel)
	{
		List<kern__LogEntry__c> entries = (List<kern__LogEntry__c>)kern.QRY_Builder.selectFrom(kern__LogEntry__c.SObjectType)
				.fields(new List<SObjectField> {kern__LogEntry__c.kern__Message__c})
				.condition(kern__LogEntry__c.kern__LogLevel__c).equals(logLevel)
				.toList();
		Integer matchingCount = 0;
		for(kern__LogEntry__c entry : entries)
		{
			if(entry.kern__Message__c?.contains(System.Label.kern.DeleteApiRecords_PermissionRequired) == true)
			{
				matchingCount++;
			}
		}
		return matchingCount;
	}
}
