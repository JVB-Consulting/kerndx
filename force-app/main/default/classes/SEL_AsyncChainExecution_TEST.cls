// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for SEL_AsyncChainExecution selector.
 *
 * @see SEL_AsyncChainExecution
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date April 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_AsyncChainExecution_TEST
{
	/**
	 * @description Company name discriminator for the committed test admin user set up in
	 * @TestSetup and retrieved via SEL_User.findByCompanyName.
	 */
	private static final String TEST_ADMIN_COMPANY = 'SEL_AsyncChainExecution_TEST-admin';

	/**
	 * @description Company name discriminator for the committed low-privilege user (Minimum Access
	 * - Salesforce profile) set up in @TestSetup and used by the tier-A regression test.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'SEL_AsyncChainExecution_TEST-low-privilege';

	/**
	 * @description Commits both a test-admin and a low-privilege user in @TestSetup's separate
	 * transaction so the tier-A test (shouldFindByStatusForLowPrivilegeUser) can use System.runAs
	 * against either without triggering MIXED_DML_OPERATION. User is a Setup object, so User DML
	 * cannot mix with standard/custom-object DML in the same transaction; pre-provisioning here
	 * satisfies that boundary.
	 *
	 * Only the tier-A test uses these users — existing SEL_AsyncChainExecution tests continue to
	 * run as the @IsTest running user without runAs.
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
	 * @description Tests that getFields returns a non-empty list containing the expected default fields.
	 */
	@IsTest
	private static void shouldReturnAllDefaultFields()
	{
		SEL_AsyncChainExecution selector = new SEL_AsyncChainExecution();
		List<SObjectField> fields = selector.getFields();
		Assert.isFalse(fields.isEmpty(), 'Default fields should not be empty');
		Assert.isTrue(fields.contains(AsyncChainExecution__c.ChainName__c), 'Should contain ChainName__c');
		Assert.isTrue(fields.contains(AsyncChainExecution__c.CorrelationId__c), 'Should contain CorrelationId__c');
	}

	/**
	 * @description Tests that findByStatus returns records matching the given status.
	 */
	@IsTest
	private static void shouldFindByStatus()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'TestChain');

		List<AsyncChainExecution__c> results = new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_RUNNING);
		Assert.isFalse(results.isEmpty(), 'Should find running chains');
	}

	/**
	 * @description Tests that findByCorrelationId returns the correct record for a known correlation ID.
	 */
	@IsTest
	private static void shouldFindByCorrelationId()
	{
		String correlationId = UTIL_Random.randomUUID();
		TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.ChainName__c, 'TestChain')
				.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_COMPLETED)
				.withOverride(AsyncChainExecution__c.CorrelationId__c, correlationId)
				.build();

		AsyncChainExecution__c result = new SEL_AsyncChainExecution().findByCorrelationId(correlationId);
		Assert.isNotNull(result, 'Should find by correlation ID');
		Assert.areEqual('TestChain', result.ChainName__c, 'Chain name should match');
	}

	/**
	 * @description Tests that findByChainName returns records with the given chain name.
	 */
	@IsTest
	private static void shouldFindByChainName()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, 'UniqueChainName');

		List<AsyncChainExecution__c> results = new SEL_AsyncChainExecution().findByChainName('UniqueChainName');
		Assert.isFalse(results.isEmpty(), 'Should find by chain name');
	}

	/**
	 * @description Tests that findByCorrelationId returns null when no record exists for the given ID.
	 */
	@IsTest
	private static void shouldReturnNullForMissingCorrelationId()
	{
		AsyncChainExecution__c result = new SEL_AsyncChainExecution().findByCorrelationId('nonexistent-id');
		Assert.isNull(result, 'Should return null for missing correlation ID');
	}

	/**
	 * @description Tests that findFiltered returns paginated, filtered, and sorted results.
	 */
	@IsTest
	private static void shouldFindFilteredByStatusAndName()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'AccountChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'AccountChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, 'DataSync');

		QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered(
				new List<String> {SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_COMPLETED},
				'Account', AsyncChainExecution__c.CreatedDate, true, 1, 10
		);

		Assert.areEqual(2, page.records.size(), 'Should match Running and Completed AccountChain');
		Assert.areEqual(2, page.totalRecords, 'Total should be 2');
	}

	/**
	 * @description Tests that findFiltered returns all records when no filters are applied.
	 */
	@IsTest
	private static void shouldFindFilteredWithNoFilters()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'Chain1');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'Chain2');

		QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered(
				null, null, AsyncChainExecution__c.CreatedDate, false, 1, 10
		);

		Assert.areEqual(2, page.records.size(), 'Should return all records');
		Assert.areEqual(2, page.totalRecords, 'Total should be 2');
	}

	/**
	 * @description Tests that findFiltered respects pagination boundaries.
	 */
	@IsTest
	private static void shouldFindFilteredWithPagination()
	{
		for(Integer index = 0; index < 5; index++)
		{
			TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'Chain' + index);
		}

		QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered(
				null, null, AsyncChainExecution__c.CreatedDate, true, 1, 2
		);

		Assert.areEqual(2, page.records.size(), 'Should return page size');
		Assert.areEqual(5, page.totalRecords, 'Total should be 5');
		Assert.isTrue(page.hasMorePages, 'Should have more pages');
		Assert.areEqual(3, page.totalPages, 'Should have 3 pages');
	}

	/**
	 * @description Tier-A — proves SEL_AsyncChainExecution.findByStatus returns
	 * rows when invoked by a subscriber user on the Minimum Access - Salesforce profile who has no
	 * FLS on kern__AsyncChainExecution__c. The framework-owned selector declares
	 * `systemModeRequired() = true`, so its internal QRY_Builder must elevate to SYSTEM_MODE and
	 * the query must return the seeded rows regardless of the running user's FLS.
	 *
	 * Catches: a future refactor that demotes SEL_AsyncChainExecution.systemModeRequired() to
	 * false, or deletes the override entirely, would cause the low-privilege user's query to fail
	 * with "No such column" under USER_MODE — this test fails at 2GP validated-build time rather
	 * than at subscriber scratch-org time.
	 *
	 * AsyncChainExecution__c has OWD=Private, so the seeded record's OwnerId is set to the
	 * low-privilege user to satisfy sharing (SYSTEM_MODE elevates FLS but not sharing under
	 * `inherited sharing`). This mirrors the realistic subscriber-admin scenario where a
	 * subscriber user triggers a chain that records its own execution.
	 *
	 * @see SEL_AsyncChainExecution.findByStatus
	 * @see SEL_AsyncChainExecution.systemModeRequired
	 */
	@IsTest
	private static void shouldFindByStatusForLowPrivilegeUser()
	{
		User lowPrivilegeUser = getLowPrivilegeUser();

		System.runAs(getTestAdmin())
		{
			TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.ChainName__c, 'LowPrivilegeChain')
					.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_RUNNING)
					.withOverride(AsyncChainExecution__c.CorrelationId__c, UTIL_Random.randomUUID())
					.withOverride(AsyncChainExecution__c.OwnerId, lowPrivilegeUser.Id)
					.build();
		}

		System.runAs(lowPrivilegeUser)
		{
			List<AsyncChainExecution__c> results = new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_RUNNING);

			Assert.isFalse(results.isEmpty(), 'Should find the seeded AsyncChainExecution__c for low-privilege caller');
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup. Used by the
	 * tier-A test to seed the AsyncChainExecution__c row before the low-privilege user queries it.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the tier-A test to exercise
	 * SEL_AsyncChainExecution.findByStatus and prove the framework-owned selector elevates
	 * internally via systemModeRequired().
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}
}