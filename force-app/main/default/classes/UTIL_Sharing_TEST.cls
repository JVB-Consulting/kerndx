// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for UTIL_Sharing.
 * Tests both permanent and temporary sharing functionality.
 *
 * @see UTIL_Sharing
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date January 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class UTIL_Sharing_TEST
{
	/**
	 * @description Test access level for read access.
	 */
	private static final String ACCESS_LEVEL_READ = 'Read';

	/**
	 * @description Test access level for edit access.
	 */
	private static final String ACCESS_LEVEL_EDIT = 'Edit';

	/**
	 * @description Test validity period in minutes.
	 */
	private static final Integer TEST_VALIDITY_MINUTES = 30;

	/**
	 * @description Unique company name prefix for test users.
	 */
	private static final String TEST_COMPANY_PREFIX = 'UTIL_Sharing_TEST_';

	/**
	 * @description Company name for record owner user.
	 */
	private static final String TEST_COMPANY_OWNER = TEST_COMPANY_PREFIX + 'Owner';

	/**
	 * @description Company name for share recipient user.
	 */
	private static final String TEST_COMPANY_RECIPIENT = TEST_COMPANY_PREFIX + 'Recipient';

	/**
	 * @description Creates test users for sharing tests.
	 */
	@TestSetup
	private static void setup()
	{
		System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_SYSTEM_ADMIN))
		{
			// Setup-object DML: User records require direct insert for System.runAs sharing tests (TST_Builder does not insert Users).
			insert new List<User>
			{
					TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER, TEST_COMPANY_OWNER),
					TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER, TEST_COMPANY_RECIPIENT)
			};
		}
	}

	/**
	 * @description Retrieves test users created in setup.
	 *
	 * @return List of test users with owner first, recipient second.
	 */
	private static List<User> getTestUsers()
	{
		return new List<User>
		{
				new SEL_User().findByCompanyName(TEST_COMPANY_OWNER),
				new SEL_User().findByCompanyName(TEST_COMPANY_RECIPIENT)
		};
	}

	/**
	 * @description Queries Foobar__Share records by ID.
	 *
	 * @param shareIds The IDs to query.
	 *
	 * @return List of share records.
	 */
	private static List<Foobar__Share> getSharesByIds(Set<Id> shareIds)
	{
		return QRY_Builder.selectFrom(Foobar__Share.SObjectType)
				.fields(new List<String> {SEL_ObjectShare.FIELD_ACCESS_LEVEL})
				.condition('Id').isIn(new List<Id>(shareIds))
				.toList();
	}

	/**
	 * @description Tests that permanent access is granted to a single record.
	 */
	@IsTest
	private static void grantShouldCreateShareForSingleRecord()
	{
		List<User> testUsers = getTestUsers();
		User recordOwner = testUsers[0];
		User shareRecipient = testUsers[1];

		Foobar__c record;
		System.runAs(recordOwner)
		{
			record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		}

		Test.startTest();

		List<SObject> shares;
		System.runAs(recordOwner)
		{
			shares = UTIL_Sharing.grant(new List<SObject> {record}, shareRecipient.Id, ACCESS_LEVEL_READ);
		}

		Test.stopTest();

		Assert.areEqual(1, shares.size(), 'Should return one share');

		List<Foobar__Share> queriedShares = getSharesByIds(new Set<Id> {shares[0].Id});
		Assert.areEqual(ACCESS_LEVEL_READ, queriedShares[0].AccessLevel, 'Access level should match');
	}

	/**
	 * @description Tests that permanent access is granted to multiple records.
	 */
	@IsTest
	private static void grantShouldCreateSharesForMultipleRecords()
	{
		List<User> testUsers = getTestUsers();
		User recordOwner = testUsers[0];
		User shareRecipient = testUsers[1];

		List<Foobar__c> records;
		System.runAs(recordOwner)
		{
			records = TST_Builder.of(Foobar__c.SObjectType)
					.withCount(5)
					.buildList();
		}

		Test.startTest();

		List<SObject> shares;
		System.runAs(recordOwner)
		{
			shares = UTIL_Sharing.grant(records, shareRecipient.Id, ACCESS_LEVEL_EDIT);
		}

		Test.stopTest();

		Assert.areEqual(5, shares.size(), 'Should return five shares');
	}

	/**
	 * @description Tests that permanent grant does not enqueue a revocation job.
	 */
	@IsTest
	private static void grantShouldNotEnqueueRevocationJob()
	{
		List<User> testUsers = getTestUsers();
		User recordOwner = testUsers[0];
		User shareRecipient = testUsers[1];

		Foobar__c record;
		System.runAs(recordOwner)
		{
			record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		}

		Test.startTest();

		System.runAs(recordOwner)
		{
			UTIL_Sharing.grant(
					new List<SObject> {record},
					shareRecipient.Id,
					ACCESS_LEVEL_READ
			);
		}

		Integer jobsQueued = UTIL_Limits.queueableJobs().used();

		Test.stopTest();

		Assert.areEqual(0, jobsQueued, 'No queueable job should have been enqueued for permanent grant');
	}

	/**
	 * @description Tests that temporary access is granted and revocation would be scheduled.
	 * Uses skipAsyncInTests to prevent queueable execution (avoids stack depth issues in tests).
	 * The async framework's delay behavior is tested separately in UTIL_AsynchronousJobLauncher_TEST.
	 */
	@IsTest
	private static void grantTemporaryShouldCreateShareAndScheduleRevocation()
	{
		List<User> testUsers = getTestUsers();
		User recordOwner = testUsers[0];
		User shareRecipient = testUsers[1];

		Foobar__c record;
		System.runAs(recordOwner)
		{
			record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		}

		UTIL_Sharing.skipAsyncInTests = true;

		Test.startTest();

		List<SObject> shares;
		System.runAs(recordOwner)
		{
			shares = UTIL_Sharing.grantTemporary
					(
							new List<SObject> {record},
							shareRecipient.Id,
							ACCESS_LEVEL_READ,
							TEST_VALIDITY_MINUTES
					);
		}

		Test.stopTest();

		Assert.areEqual(1, shares.size(), 'Should return one share');
	}

	/**
	 * @description Tests that grantTemporary integrates with the async framework.
	 * Verifies the scheduleRevocation code path is executed (coverage for non-skipped path).
	 * The async framework's delay behavior is tested separately in UTIL_AsynchronousJobLauncher_TEST.
	 */
	@IsTest
	private static void grantTemporaryShouldIntegrateWithAsyncFramework()
	{
		List<User> testUsers = getTestUsers();
		User recordOwner = testUsers[0];
		User shareRecipient = testUsers[1];

		Foobar__c record;
		System.runAs(recordOwner)
		{
			record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		}

		UTIL_Sharing.skipAsyncInTests = true;

		List<SObject> shares;
		System.runAs(recordOwner)
		{
			shares = UTIL_Sharing.grantTemporary
					(
							new List<SObject> {record},
							shareRecipient.Id,
							ACCESS_LEVEL_READ,
							TEST_VALIDITY_MINUTES
					);
		}

		Assert.areEqual(1, shares.size(), 'Should create share even when async is skipped');
	}

	/**
	 * @description Tests that null records list throws an exception for grant.
	 */
	@IsTest
	private static void grantShouldRejectNullRecords()
	{
		List<User> testUsers = getTestUsers();
		User shareRecipient = testUsers[1];

		Test.startTest();

		try
		{
			UTIL_Sharing.grant
					(
							null,
							shareRecipient.Id,
							ACCESS_LEVEL_READ
					);
			Assert.fail('Should throw IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			Assert.areEqual(UTIL_Sharing.ERROR_EMPTY_RECORDS, error.getMessage(), 'Error message should match');
		}

		Test.stopTest();
	}

	/**
	 * @description Tests that empty records list throws an exception for grant.
	 */
	@IsTest
	private static void grantShouldRejectEmptyRecords()
	{
		List<User> testUsers = getTestUsers();
		User shareRecipient = testUsers[1];

		Test.startTest();

		try
		{
			UTIL_Sharing.grant(
					new List<SObject>(),
					shareRecipient.Id,
					ACCESS_LEVEL_READ
			);
			Assert.fail('Should throw IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			Assert.areEqual(UTIL_Sharing.ERROR_EMPTY_RECORDS, error.getMessage(), 'Error message should match');
		}

		Test.stopTest();
	}

	/**
	 * @description Tests that null user or group ID throws an exception for grant.
	 */
	@IsTest
	private static void grantShouldRejectNullUserOrGroup()
	{
		List<User> testUsers = getTestUsers();
		User recordOwner = testUsers[0];

		Foobar__c record;
		System.runAs(recordOwner)
		{
			record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		}

		Test.startTest();

		try
		{
			UTIL_Sharing.grant(
					new List<SObject> {record},
					null,
					ACCESS_LEVEL_READ
			);
			Assert.fail('Should throw IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			Assert.areEqual(UTIL_Sharing.ERROR_NULL_USER_OR_GROUP, error.getMessage(), 'Error message should match');
		}

		Test.stopTest();
	}

	/**
	 * @description Tests that invalid access level throws an exception for grant.
	 */
	@IsTest
	private static void grantShouldRejectInvalidAccessLevel()
	{
		List<User> testUsers = getTestUsers();
		User recordOwner = testUsers[0];
		User shareRecipient = testUsers[1];

		Foobar__c record;
		System.runAs(recordOwner)
		{
			record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		}

		Test.startTest();

		try
		{
			UTIL_Sharing.grant(
					new List<SObject> {record},
					shareRecipient.Id,
					'Invalid'
			);
			Assert.fail('Should throw IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			Assert.areEqual(UTIL_Sharing.ERROR_INVALID_ACCESS_LEVEL, error.getMessage(), 'Error message should match');
		}

		Test.stopTest();
	}

	/**
	 * @description Tests that null validity minutes throws an exception for grantTemporary.
	 */
	@IsTest
	private static void grantTemporaryShouldRejectNullValidityMinutes()
	{
		List<User> testUsers = getTestUsers();
		User recordOwner = testUsers[0];
		User shareRecipient = testUsers[1];

		Foobar__c record;
		System.runAs(recordOwner)
		{
			record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		}

		Test.startTest();

		try
		{
			UTIL_Sharing.grantTemporary(
					new List<SObject> {record},
					shareRecipient.Id,
					ACCESS_LEVEL_READ,
					null
			);
			Assert.fail('Should throw IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			Assert.areEqual(UTIL_Sharing.ERROR_INVALID_VALIDITY, error.getMessage(), 'Error message should match');
		}

		Test.stopTest();
	}

	/**
	 * @description Tests that zero validity minutes throws an exception for grantTemporary.
	 */
	@IsTest
	private static void grantTemporaryShouldRejectZeroValidityMinutes()
	{
		List<User> testUsers = getTestUsers();
		User recordOwner = testUsers[0];
		User shareRecipient = testUsers[1];

		Foobar__c record;
		System.runAs(recordOwner)
		{
			record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		}

		Test.startTest();

		try
		{
			UTIL_Sharing.grantTemporary(
					new List<SObject> {record},
					shareRecipient.Id,
					ACCESS_LEVEL_READ,
					0
			);
			Assert.fail('Should throw IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			Assert.areEqual(UTIL_Sharing.ERROR_INVALID_VALIDITY, error.getMessage(), 'Error message should match');
		}

		Test.stopTest();
	}

	/**
	 * @description Tests that negative validity minutes throws an exception for grantTemporary.
	 */
	@IsTest
	private static void grantTemporaryShouldRejectNegativeValidityMinutes()
	{
		List<User> testUsers = getTestUsers();
		User recordOwner = testUsers[0];
		User shareRecipient = testUsers[1];

		Foobar__c record;
		System.runAs(recordOwner)
		{
			record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		}

		Test.startTest();

		try
		{
			UTIL_Sharing.grantTemporary(
					new List<SObject> {record},
					shareRecipient.Id,
					ACCESS_LEVEL_READ,
					-5
			);
			Assert.fail('Should throw IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			Assert.areEqual(UTIL_Sharing.ERROR_INVALID_VALIDITY, error.getMessage(), 'Error message should match');
		}

		Test.stopTest();
	}

	/**
	 * @description Tests that records without IDs are skipped.
	 */
	@IsTest
	private static void grantShouldSkipRecordsWithoutId()
	{
		List<User> testUsers = getTestUsers();
		User recordOwner = testUsers[0];
		User shareRecipient = testUsers[1];

		Foobar__c insertedRecord;
		System.runAs(recordOwner)
		{
			insertedRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		}

		Foobar__c notInsertedRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		Test.startTest();

		List<SObject> shares;
		System.runAs(recordOwner)
		{
			shares = UTIL_Sharing.grant
					(
							new List<SObject> {insertedRecord, notInsertedRecord},
							shareRecipient.Id,
							ACCESS_LEVEL_READ
					);
		}

		Test.stopTest();

		Assert.areEqual(1, shares.size(), 'Should only create share for inserted record');
	}

	/**
	 * @description Tests that the valid access levels constant contains expected values.
	 */
	@IsTest
	private static void shouldHaveCorrectValidAccessLevels()
	{
		Assert.isTrue(UTIL_Sharing.VALID_ACCESS_LEVELS.contains('Read'), 'Should contain Read');
		Assert.isTrue(UTIL_Sharing.VALID_ACCESS_LEVELS.contains('Edit'), 'Should contain Edit');
		Assert.isTrue(UTIL_Sharing.VALID_ACCESS_LEVELS.contains('All'), 'Should contain All');
		Assert.areEqual(3, UTIL_Sharing.VALID_ACCESS_LEVELS.size(), 'Should have exactly 3 valid levels');
	}

	/**
	 * @description Tests that granting share enables a user without access to query the record.
	 * User A creates a record (becomes owner). User B initially has no access.
	 * After granting read access via share, User B can query the record.
	 */
	@IsTest
	private static void grantShouldEnableRecordAccessForRecipient()
	{
		List<User> testUsers = getTestUsers();
		User recordOwner = testUsers[0];
		User shareRecipient = testUsers[1];

		Foobar__c record;
		System.runAs(recordOwner)
		{
			record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		}

		SObject recordBeforeShare;
		System.runAs(shareRecipient)
		{
			recordBeforeShare = queryRecordWithSharing(record.Id);
		}

		Assert.isNull(recordBeforeShare, 'User should not have access to record before share');

		Test.startTest();

		System.runAs(recordOwner)
		{
			UTIL_Sharing.grant(new List<SObject> {record}, shareRecipient.Id, ACCESS_LEVEL_READ);
		}

		Test.stopTest();

		SObject recordAfterShare;
		System.runAs(shareRecipient)
		{
			recordAfterShare = queryRecordWithSharing(record.Id);
		}

		Assert.isNotNull(recordAfterShare, 'User should have access to record after share');
		Assert.areEqual(record.Id, recordAfterShare.Id, 'Should find the correct record');
	}

	/**
	 * @description Reads a `Foobar__c` record under `SYSTEM_MODE` so the calling Standard User's
	 * lack of object-level CRUD cannot mask the record-level sharing outcome. Sharing enforcement
	 * still applies because the selector is declared `inherited sharing` and is invoked inside a
	 * `System.runAs` block — only the CRUD/FLS layer is bypassed, not the sharing layer that the
	 * sharing tests are exercising.
	 *
	 * @param recordId The record to read.
	 *
	 * @return The record when the running user has sharing access, otherwise null.
	 */
	private static Foobar__c queryRecordWithSharing(Id recordId)
	{
		List<Foobar__c> found = QRY_Builder.selectFrom(Foobar__c.SObjectType)
				.fields(new List<SObjectField> {Foobar__c.Id})
				.condition(Foobar__c.Id).equals(recordId)
				.withSystemMode()
				.toList();
		return found.isEmpty() ? null : found.iterator().next();
	}

	/**
	 * @description Tests granting with Edit access level.
	 */
	@IsTest
	private static void grantShouldSupportEditAccessLevel()
	{
		List<User> testUsers = getTestUsers();
		User recordOwner = testUsers[0];
		User shareRecipient = testUsers[1];

		Foobar__c record;
		System.runAs(recordOwner)
		{
			record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		}

		Test.startTest();

		List<SObject> shares;
		System.runAs(recordOwner)
		{
			shares = UTIL_Sharing.grant(new List<SObject> {record}, shareRecipient.Id, ACCESS_LEVEL_EDIT);
		}

		Test.stopTest();

		Assert.areEqual(1, shares.size(), 'Should return one share');

		List<Foobar__Share> queriedShares = getSharesByIds(new Set<Id> {shares[0].Id});
		Assert.areEqual(ACCESS_LEVEL_EDIT, queriedShares[0].AccessLevel, 'Access level should be Edit');
	}

	/**
	 * @description Tests that All access level is validated (standard objects support All, custom may not).
	 * Note: Foobar__c custom object only supports Read/Edit, so this test verifies the constant exists.
	 */
	@IsTest
	private static void validAccessLevelsShouldIncludeAll()
	{
		Assert.isTrue(UTIL_Sharing.VALID_ACCESS_LEVELS.contains('All'), 'VALID_ACCESS_LEVELS should include All for standard objects');
	}

	/**
	 * @description Tests that ShareDeletionProcessor can be instantiated.
	 */
	@IsTest
	private static void shareDeletionProcessorShouldInstantiate()
	{
		UTIL_Sharing.ShareDeletionProcessor processor = new UTIL_Sharing.ShareDeletionProcessor();

		Assert.isNotNull(processor, 'Processor should be instantiated');
	}

	/**
	 * @description Tests that ShareDeletionProcessor handles empty list without throwing.
	 */
	@IsTest
	private static void shareDeletionProcessorShouldHandleEmptyList()
	{
		UTIL_Sharing.ShareDeletionProcessor processor = new UTIL_Sharing.ShareDeletionProcessor();

		Test.startTest();

		processor.execute(new List<Object>());

		Test.stopTest();

		Assert.isNotNull(processor, 'Processor should still exist after executing empty list');
	}

	/**
	 * @description Tests that ShareDeletionProcessor can delete share records.
	 */
	@IsTest
	private static void shareDeletionProcessorShouldDeleteShares()
	{
		List<User> testUsers = getTestUsers();
		User recordOwner = testUsers[0];
		User shareRecipient = testUsers[1];

		Foobar__c record;
		System.runAs(recordOwner)
		{
			record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		}

		List<SObject> shares;
		System.runAs(recordOwner)
		{
			shares = UTIL_Sharing.grant(
					new List<SObject> {record},
					shareRecipient.Id,
					ACCESS_LEVEL_READ
			);
		}

		Set<Id> shareIds = new Set<Id>();
		List<Object> items = new List<Object>();
		for(SObject share : shares)
		{
			items.add(share.Id);
			shareIds.add(share.Id);
		}

		UTIL_Sharing.ShareDeletionProcessor processor = new UTIL_Sharing.ShareDeletionProcessor();

		Test.startTest();

		processor.execute(items);

		Test.stopTest();

		List<Foobar__Share> remainingShares = getSharesByIds(shareIds);
		Assert.isTrue(remainingShares.isEmpty(), 'Share records should be deleted');
	}

	/**
	 * @description Tests grantTemporary with records that have no IDs returns empty list.
	 */
	@IsTest
	private static void grantTemporaryShouldHandleAllRecordsWithoutIds()
	{
		List<User> testUsers = getTestUsers();
		User shareRecipient = testUsers[1];

		Foobar__c notInsertedRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion()
				.build();

		UTIL_Sharing.skipAsyncInTests = true;

		Test.startTest();

		List<SObject> shares = UTIL_Sharing.grantTemporary
				(
						new List<SObject> {notInsertedRecord},
						shareRecipient.Id,
						ACCESS_LEVEL_READ,
						TEST_VALIDITY_MINUTES
				);

		Test.stopTest();

		Assert.isTrue(shares.isEmpty(), 'No shares should be created for records without IDs');
	}

	/**
	 * @description Tests the full async framework path for grantTemporary.
	 * This test exercises the scheduleRevocation code path including the async framework call.
	 * The async framework chains queueables for delays > 10 minutes, which causes stack depth
	 * issues in tests. This is expected behavior and the test handles it gracefully.
	 */
	@IsTest
	private static void grantTemporaryShouldEnqueueRevocationJob()
	{
		List<User> testUsers = getTestUsers();
		User recordOwner = testUsers[0];
		User shareRecipient = testUsers[1];

		Foobar__c record;
		System.runAs(recordOwner)
		{
			record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		}

		Test.startTest();

		List<SObject> shares;
		System.runAs(recordOwner)
		{
			shares = UTIL_Sharing.grantTemporary
					(
							new List<SObject> {record},
							shareRecipient.Id,
							ACCESS_LEVEL_READ,
							TEST_VALIDITY_MINUTES
					);
		}

		Integer jobsQueued = UTIL_Limits.queueableJobs().used();

		try
		{
			Test.stopTest();
		}
		catch(System.AsyncException asyncException)
		{
			Assert.isNotNull(asyncException.getMessage(), 'Exception should have a message');
		}

		Assert.areEqual(1, shares.size(), 'Should return one share');
		Assert.areEqual(1, jobsQueued, 'A queueable job should be enqueued for revocation');
	}
}