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
 * @see kern.DML_Builder
 * @see kern.UTIL_FeatureFlag
 *
 * @author Jason van Beukering
 *
 * @group DML
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class Subscriber_DmlEdges_TEST
{
	/**
	 * @description Profile name for the Standard User fixture used by `System.runAs`.
	 */
	private static final String STANDARD_PROFILE = 'Standard User';

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
	 * @description Creates a Standard User with no kern managed-package permission sets. The
	 * test context never commits this user — they exist only for the scope of `System.runAs`.
	 *
	 * @return The Standard User instance.
	 */
	private static User createStandardUser()
	{
		Profile standardProfile = [SELECT Id FROM Profile WHERE Name = :STANDARD_PROFILE LIMIT 1];
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
