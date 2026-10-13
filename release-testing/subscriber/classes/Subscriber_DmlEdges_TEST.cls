// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Subscriber proof for `DML_Builder` `runAs` scenarios deferred from
 * `release-testing/scripts/section-52-edge-dml-builder.apex` (the extended-load spec §6.15, Task 1.14).
 * Anonymous Apex cannot impersonate via `System.runAs` — only `@IsTest` context can — so the
 * two scenarios that need a Standard User context live here.
 *
 * Spec note: the extended-load spec §6.15 asks for `.bypassSharing()` as the contract. Under
 * secure-by-default, USER_MODE became the default for CRUD/FLS at the DML layer, so
 * `.bypassSharing()` alone (which only flips sharing, not CRUD/FLS) is not enough for a
 * user the framework has not granted CRUD to. The composability of the two overrides is
 * what these tests verify.
 *
 * `kern__Foobar__c` is used (the framework's canonical test object) and the Standard User
 * profile is granted no kern managed-package permission sets, so the user has no
 * `kern__Foobar__c` CRUD.
 *
 * A third test proves a failed save is logged once: an all-or-nothing insert that the Account validation rules refuse
 * writes one ERROR entry at the commit and none at the builder.
 *
 * @see kern.DML_Builder
 * @see kern.UTIL_FeatureFlag
 * @see kern.LOG_Builder
 * @see kern.QRY_Builder
 *
 * @author Jason van Beukering
 *
 * @group DML
 *
 * @date May 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class Subscriber_DmlEdges_TEST
{
	/**
	 * @description Profile name for the Standard User fixture used by `System.runAs`.
	 */
	private static final String STANDARD_PROFILE = 'Standard User';

	/**
	 * @description The name of the Account the validation rules refuse. The Account has no phone, no website and no
	 * industry, which the subscriber's Account validation rules require.
	 */
	private static final String REFUSED_ACCOUNT_NAME = 'DmlEdges refused account';

	/**
	 * @description The log level of the entry a failed save writes.
	 */
	private static final String LOG_LEVEL_ERROR = 'ERROR';

	/**
	 * @description The end of the location the commit writes its failure entry at.
	 */
	private static final String COMMIT_LOCATION_SUFFIX = 'DML_Transaction.commitWork';

	/**
	 * @description The end of the location the builder would write a second failure entry at; it must write none.
	 */
	private static final String BUILDER_LOCATION_SUFFIX = 'DML_Builder.execute';

	/**
	 * @description A Standard User without `kern__Foobar__c` CRUD should still be able to
	 * insert a record when the caller chains `.bypassSharing().withSystemMode()`. The
	 * `.bypassSharing()` flip alone only escalates sharing (secure-by-default keeps
	 * USER_MODE for CRUD/FLS); pairing with `.withSystemMode()` lifts both gates, restoring
	 * the legacy framework-internal write semantics. The composability of the two overrides
	 * is the contract under test.
	 */
	@IsTest
	private static void shouldWriteWithBypassSharingAsStandardUser()
	{
		User standardUser = createStandardUser();
		Boolean succeeded = false;
		String thrownTypeName = null;
		String thrownMessage = null;

		Test.startTest();

		System.runAs(standardUser)
		{
			try
			{
				kern__Foobar__c record = (kern__Foobar__c)kern.TST_Builder.of(kern__Foobar__c.SObjectType)
						.withOverride(kern__Foobar__c.Name, 'BypassSharing-StandardUser')
						.withoutInsertion()
						.build();
				kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
						.doInsert(record)
						.bypassSharing()
						.withSystemMode()
						.execute();
				succeeded = result.isSuccess();
			}
			catch(Exception unexpected)
			{
				succeeded = false;
				thrownTypeName = unexpected.getTypeName();
				thrownMessage = unexpected.getMessage();
			}
		}

		Test.stopTest();

		Assert.isTrue(succeeded,
				'Expected no throw, got ' + thrownTypeName + ': ' + thrownMessage);
	}

	/**
	 * @description An explicit `.withUserMode()` chain forces USER_MODE regardless of the
	 * subscriber-overrideable flag. A Standard User without `kern__Foobar__c` CRUD must be
	 * rejected — `.allowPartial()` keeps the rejection out of the exception path so the
	 * caller can inspect `getSuccessCount()` / `getFailureCount()` on the `TransactionResult`.
	 * The seed record is created via the admin-context test method body (before runAs), so
	 * the row exists in the org for the Standard User to attempt to update.
	 */
	@IsTest
	private static void shouldRejectFlsRestrictedWriteUnderUserMode()
	{
		User standardUser = createStandardUser();
		kern__Foobar__c seedRecord = (kern__Foobar__c)kern.TST_Builder.of(kern__Foobar__c.SObjectType)
				.withOverride(kern__Foobar__c.Name, 'UserMode-StandardUser-seed')
				.build();
		Integer successCount = -1;
		Integer failureCount = -1;
		Boolean executedCleanly = false;

		Test.startTest();

		String thrownTypeName = null;
		String thrownMessage = null;

		System.runAs(standardUser)
		{
			try
			{
				seedRecord.put(kern__Foobar__c.Name, 'UserMode-StandardUser-update');
				kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
						.doUpdate(seedRecord)
						.withUserMode()
						.allowPartial()
						.execute();
				successCount = result.getSuccessCount();
				failureCount = result.getFailureCount();
				executedCleanly = true;
			}
			catch(Exception unexpected)
			{
				executedCleanly = false;
				thrownTypeName = unexpected.getTypeName();
				thrownMessage = unexpected.getMessage();
			}
		}

		Test.stopTest();

		Assert.isTrue(executedCleanly,
				'Expected no throw, got ' + thrownTypeName + ': ' + thrownMessage);
		Assert.areEqual(0, successCount, 'Expected zero successes when the Standard User lacks kern__Foobar__c CRUD');
		Assert.areEqual(1, failureCount, 'Expected exactly one failure for the rejected update');
	}

	/**
	 * @description An all-or-nothing insert that a validation rule refuses throws a DmlException and is logged once, by
	 * the commit that refused it: one ERROR entry whose location ends with DML_Transaction.commitWork, and no entry whose
	 * location ends with DML_Builder.execute. The location may carry the package namespace in front, so the test reads
	 * its end.
	 *
	 * @date October 2026
	 */
	@IsTest
	private static void shouldLogARefusedAllOrNothingInsertOnceAtTheCommit()
	{
		kern.LOG_Builder.ignoreTestMode = true;
		Account refusedAccount = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, REFUSED_ACCOUNT_NAME)
				.withOverride(Account.Phone, null)
				.withOverride(Account.Website, null)
				.withOverride(Account.Industry, null)
				.withoutInsertion()
				.build();

		Test.startTest();

		try
		{
			kern.DML_Builder.newTransaction().doInsert(refusedAccount).execute();
			Assert.fail('Expected the Account validation rules to refuse the insert');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class, 'Expected the refused all-or-nothing insert to throw a DmlException');
		}
		Test.getEventBus().deliver();

		Test.stopTest();

		Integer commitErrorEntries = 0;
		Integer builderEntries = 0;
		for(kern__LogEntry__c entry : findCurrentUsersLogEntries())
		{
			String location = entry.kern__ClassMethod__c ?? '';
			if(location.endsWith(COMMIT_LOCATION_SUFFIX) && entry.kern__LogLevel__c == LOG_LEVEL_ERROR)
			{
				commitErrorEntries++;
			}
			if(location.endsWith(BUILDER_LOCATION_SUFFIX))
			{
				builderEntries++;
			}
		}
		Assert.areEqual(1, commitErrorEntries, 'Expected one ERROR entry from the commit that refused the insert');
		Assert.areEqual(0, builderEntries, 'Expected no second entry from the builder for the same failure');
	}

	/**
	 * @description Reads the log entries the running user wrote in this test, with their location and level.
	 *
	 * @return The running user's log entries.
	 *
	 * @date October 2026
	 */
	private static List<kern__LogEntry__c> findCurrentUsersLogEntries()
	{
		return (List<kern__LogEntry__c>)kern.QRY_Builder.selectFrom(kern__LogEntry__c.SObjectType)
				.fields(new List<SObjectField> {kern__LogEntry__c.kern__ClassMethod__c, kern__LogEntry__c.kern__LogLevel__c})
				.condition(kern__LogEntry__c.kern__UserId__c).equals(UserInfo.getUserId())
				.toList();
	}

	/**
	 * @description Creates a Standard User with no kern managed-package permission sets. The
	 * test context never commits this user — they exist only for the scope of `System.runAs`.
	 *
	 * @return The Standard User instance.
	 */
	private static User createStandardUser()
	{
		Profile standardProfile =
		[
				SELECT Id
				FROM Profile
				WHERE Name = :STANDARD_PROFILE
				LIMIT 1
		];
		String suffix = String.valueOf(Crypto.getRandomInteger()).right(8);
		User standardUser = new User
				(
						FirstName = 'DmlEdges',
						LastName = 'Subscriber',
						Email = 'dml-edges-' + suffix + '@kerndx.test',
						Username = 'dml-edges-' + suffix + '@kerndx.test.invalid',
						Alias = 'dml' + suffix.right(3),
						TimeZoneSidKey = 'America/New_York',
						LocaleSidKey = 'en_US',
						EmailEncodingKey = 'UTF-8',
						LanguageLocaleKey = 'en_US',
						ProfileId = standardProfile.Id
				);
		insert standardUser;
		return standardUser;
	}
}
