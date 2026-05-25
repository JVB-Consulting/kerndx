// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_ApiIssue selector.
 *
 * @see SEL_ApiIssue
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_ApiIssue_TEST
{
	/**
	 * @description Company name discriminator for the committed test admin user set up in
	 * @TestSetup and retrieved via SEL_User.findByCompanyName.
	 */
	private static final String TEST_ADMIN_COMPANY = 'SEL_ApiIssue_TEST-admin';

	/**
	 * @description Company name discriminator for the committed low-privilege user (Minimum Access
	 * - Salesforce profile) set up in @TestSetup and used by the tier-A regression test.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'SEL_ApiIssue_TEST-low-privilege';

	/**
	 * @description Commits both a test-admin and a low-privilege user in @TestSetup's separate
	 * transaction so the tier-A test (shouldFindUnresolvedByServiceForLowPrivilegeUser) can use
	 * System.runAs against either without triggering MIXED_DML_OPERATION. User is a Setup object,
	 * so User DML cannot mix with standard/custom-object DML in the same transaction;
	 * pre-provisioning here satisfies that boundary.
	 *
	 * Only the tier-A test uses these users — existing SEL_ApiIssue tests continue to run as the
	 * @IsTest running user without runAs.
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
	 * @description Tests that findByFailedApiCall returns matching failed records.
	 */
	@IsTest
	private static void shouldFindByFailedApiCall()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

		String serviceName = UTIL_Random.randomName();
		String hashParameter = UTIL_Crypto.generateMD5Hash(serviceName);

		TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.TriggeringRecordId__c, record.Id)
				.withOverride(ApiIssue__c.ServiceName__c, serviceName)
				.withOverride(ApiIssue__c.RequestParametersHash__c, hashParameter)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
				.build();

		List<ApiIssue__c> results = new SEL_ApiIssue().findByFailedApiCall(record.Id, serviceName, hashParameter);

		Assert.areEqual(1, results.size(), 'Should return the matching failure record');
	}

	/**
	 * @description Tests that getAll returns records within a test context.
	 */
	@IsTest
	private static void shouldGetAllInTestContext()
	{
		TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
				.build();

		List<ApiIssue__c> results = new SEL_ApiIssue().getAll();

		Assert.isFalse(results.isEmpty(), 'Should return records in test context');
	}

	/**
	 * @description Tests that findUnresolvedByService returns matching open records.
	 */
	@IsTest
	private static void shouldFindUnresolvedByService()
	{
		String serviceName = UTIL_Random.randomName();

		TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.ServiceName__c, serviceName)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
				.build();

		List<ApiIssue__c> results = new SEL_ApiIssue().findUnresolvedByService(serviceName);

		Assert.areEqual(1, results.size(), 'Should return the matching unresolved record');
	}

	/**
	 * @description Tests that findUnresolvedByService returns empty for resolved records.
	 */
	@IsTest
	private static void shouldReturnEmptyWhenAllResolved()
	{
		String serviceName = UTIL_Random.randomName();

		TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.ServiceName__c, serviceName)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_RESOLVED)
				.build();

		List<ApiIssue__c> results = new SEL_ApiIssue().findUnresolvedByService(serviceName);

		Assert.isTrue(results.isEmpty(), 'Should return empty list when all records are resolved');
	}

	/**
	 * @description Tests that findUnresolvedInbound returns inbound failures.
	 */
	@IsTest
	private static void shouldFindUnresolvedInbound()
	{
		TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_INBOUND)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
				.build();

		List<ApiIssue__c> results = new SEL_ApiIssue().findUnresolvedInbound();

		Assert.areEqual(1, results.size(), 'Should return the inbound failure record');
	}

	/**
	 * @description Tests that findUnresolvedInbound excludes outbound failures.
	 */
	@IsTest
	private static void shouldExcludeOutboundFromInboundQuery()
	{
		TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_OUTBOUND)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
				.build();

		List<ApiIssue__c> results = new SEL_ApiIssue().findUnresolvedInbound();

		Assert.isTrue(results.isEmpty(), 'Should not return outbound failures');
	}

	/**
	 * @description Tier-A — proves SEL_ApiIssue.findUnresolvedByService
	 * returns rows when invoked by a subscriber user on the Minimum Access - Salesforce profile
	 * who has no FLS on kern__ApiIssue__c. The framework-owned selector declares
	 * `systemModeRequired() = true`, so its internal QRY_Builder must elevate to SYSTEM_MODE and
	 * the query must return the seeded rows regardless of the running user's FLS.
	 *
	 * Catches: a future refactor that demotes SEL_ApiIssue.systemModeRequired() to false, or
	 * deletes the override entirely, would cause the low-privilege user's query to fail with "No
	 * such column" under USER_MODE — this test fails at 2GP validated-build time rather than at
	 * subscriber scratch-org time.
	 *
	 * Note on method selection — T10's plan entry cites `findByItemHash(...)`; the selector does
	 * not expose that method. `findUnresolvedByService` covers the same elevation-via-
	 * systemModeRequired regression surface since both go through the shared SEL_Base.query
	 * property.
	 *
	 * @see SEL_ApiIssue.findUnresolvedByService
	 * @see SEL_ApiIssue.systemModeRequired
	 */
	@IsTest
	private static void shouldFindUnresolvedByServiceForLowPrivilegeUser()
	{
		final String serviceName = UTIL_Random.randomName();

		System.runAs(getTestAdmin())
		{
			TST_Builder.of(ApiIssue__c.SObjectType)
					.withOverride(ApiIssue__c.ServiceName__c, serviceName)
					.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
					.build();
		}

		System.runAs(getLowPrivilegeUser())
		{
			List<ApiIssue__c> results = new SEL_ApiIssue().findUnresolvedByService(serviceName);

			Assert.areEqual(1, results.size(), 'Should find the seeded ApiIssue__c for low-privilege caller');
			Assert.areEqual(serviceName, results[0].ServiceName__c, 'ServiceName should match the seeded value');
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup. Used by the
	 * tier-A test to seed the ApiIssue__c row before the low-privilege user queries it.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the tier-A test to exercise SEL_ApiIssue.findUnresolvedByService
	 * and prove the framework-owned selector elevates internally via systemModeRequired().
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}
}