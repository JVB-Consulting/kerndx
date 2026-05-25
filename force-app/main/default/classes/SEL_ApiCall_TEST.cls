// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_ApiCall selector.
 *
 * @see SEL_ApiCall
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_ApiCall_TEST
{
	/**
	 * @description Test service name for API call creation.
	 */
	private static final String TEST_SERVICE_NAME = 'TestService';

	/**
	 * @description Company name discriminator for the committed test admin user set up in
	 * @TestSetup and retrieved via SEL_User.findByCompanyName.
	 */
	private static final String TEST_ADMIN_COMPANY = 'SEL_ApiCall_TEST-admin';

	/**
	 * @description Company name discriminator for the committed low-privilege user (Minimum Access
	 * - Salesforce profile) set up in @TestSetup and used by the tier-A regression test.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'SEL_ApiCall_TEST-low-privilege';

	/**
	 * @description Commits both a test-admin and a low-privilege user in @TestSetup's separate
	 * transaction so the tier-A test (shouldFindByServiceNameForLowPrivilegeUser) can use
	 * System.runAs against either without triggering MIXED_DML_OPERATION. User is a Setup object,
	 * so User DML cannot mix with standard/custom-object DML in the same transaction;
	 * pre-provisioning here satisfies that boundary.
	 *
	 * Only the tier-A test uses these users — existing SEL_ApiCall tests continue to run as the
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
	 * @description Creates a pre-configured ApiCall builder with common test fields.
	 *
	 * @param status The status value for the API call
	 * @param direction The direction (inbound/outbound) for the API call
	 *
	 * @return A TST_Builder.Builder ready for further chaining or .build()
	 */
	private static TST_Builder.Builder apiCallBuilder(String status, String direction)
	{
		return TST_Factory.getApiCallBuilder()
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.ServiceName__c => TEST_SERVICE_NAME,
						ApiCall__c.Status__c => status,
						ApiCall__c.Direction__c => direction
				});
	}

	/**
	 * @description Creates a pre-configured outbound ApiCall builder with common test fields.
	 *
	 * @param status The status value for the API call
	 *
	 * @return A TST_Builder.Builder ready for further chaining or .build()
	 */
	private static TST_Builder.Builder apiCallBuilder(String status)
	{
		return apiCallBuilder(status, SEL_ApiCall.TYPE_OUTBOUND);
	}

	/**
	 * @description Tests that findByServiceName returns matching API calls.
	 */
	@IsTest
	private static void shouldFindByServiceName()
	{
		apiCallBuilder(SEL_ApiCall.STATUS_QUEUED).build();

		List<ApiCall__c> results = new SEL_ApiCall().findByServiceName(TEST_SERVICE_NAME);

		Assert.areEqual(1, results.size(), 'Should find one API call');
		Assert.areEqual(TEST_SERVICE_NAME, results[0].ServiceName__c, 'Service name should match');
	}

	/**
	 * @description Tests that findByBatchedOutbound returns only batched outbound items.
	 */
	@IsTest
	private static void shouldFindByBatchedOutbound()
	{
		apiCallBuilder(SEL_ApiCall.STATUS_BATCHED).build();

		List<ApiCall__c> results = new SEL_ApiCall().findByBatchedOutbound();

		Assert.areEqual(1, results.size(), 'Should find one batched outbound item');
	}

	/**
	 * @description Tests that assertServiceCompleted passes for completed API calls.
	 */
	@IsTest
	private static void shouldAssertServiceCompleted()
	{
		apiCallBuilder(SEL_ApiCall.STATUS_COMPLETED).build();

		List<ApiCall__c> results = SEL_ApiCall.assertServiceCompleted(TEST_SERVICE_NAME);

		Assert.areEqual(1, results.size(), 'Should find one completed item');
	}

	/**
	 * @description Tests that assertServiceAborted passes for aborted API calls with an error phrase.
	 */
	@IsTest
	private static void shouldAssertServiceAbortedWithErrorPhrase()
	{
		apiCallBuilder(SEL_ApiCall.STATUS_ABORTED)
				.withOverride(ApiCall__c.ErrorMessages__c, 'Connection timeout occurred')
				.build();

		List<ApiCall__c> results = SEL_ApiCall.assertServiceAborted(TEST_SERVICE_NAME, 'Connection timeout');

		Assert.areEqual(1, results.size(), 'Should find one aborted item');
	}

	/**
	 * @description Tests that findByIdempotencyKey returns matching API call.
	 */
	@IsTest
	private static void shouldFindByIdempotencyKey()
	{
		String idempotencyKey = UTIL_Random.randomUUID();

		apiCallBuilder(SEL_ApiCall.STATUS_COMPLETED)
				.withOverride(ApiCall__c.IdempotencyKey__c, idempotencyKey)
				.build();

		ApiCall__c result = new SEL_ApiCall().findByIdempotencyKey(idempotencyKey);

		Assert.isNotNull(result, 'Should find API call by idempotency key');
		Assert.areEqual(idempotencyKey, result.IdempotencyKey__c, 'Idempotency key should match');
	}

	/**
	 * @description Tests that findCompletedByIdempotencyKey returns only completed records.
	 */
	@IsTest
	private static void shouldFindCompletedByIdempotencyKey()
	{
		String idempotencyKey = UTIL_Random.randomUUID();

		apiCallBuilder(SEL_ApiCall.STATUS_COMPLETED, SEL_ApiCall.TYPE_INBOUND)
				.withOverride(ApiCall__c.IdempotencyKey__c, idempotencyKey)
				.build();

		ApiCall__c result = new SEL_ApiCall().findCompletedByIdempotencyKey(idempotencyKey);

		Assert.isNotNull(result, 'Should find completed API call by idempotency key');
		Assert.areEqual(idempotencyKey, result.IdempotencyKey__c, 'Idempotency key should match');
	}

	/**
	 * @description Tests that findCompletedByIdempotencyKey ignores failed records.
	 */
	@IsTest
	private static void shouldIgnoreFailedCallForCompletedIdempotencyLookup()
	{
		String idempotencyKey = UTIL_Random.randomUUID();

		apiCallBuilder(SEL_ApiCall.STATUS_FAILED, SEL_ApiCall.TYPE_INBOUND)
				.withOverride(ApiCall__c.IdempotencyKey__c, idempotencyKey)
				.build();

		ApiCall__c result = new SEL_ApiCall().findCompletedByIdempotencyKey(idempotencyKey);

		Assert.isNull(result, 'Should not return failed API call for completed idempotency lookup');
	}

	/**
	 * @description Tests that findByIdempotencyKey returns null when no match exists.
	 */
	@IsTest
	private static void shouldReturnNullForNonExistentIdempotencyKey()
	{
		ApiCall__c result = new SEL_ApiCall().findByIdempotencyKey('non-existent-key');

		Assert.isNull(result, 'Should return null for non-existent idempotency key');
	}

	/**
	 * @description Tests that updateNextRetryInfo correctly sets retry fields.
	 */
	@IsTest
	private static void shouldUpdateNextRetryInfo()
	{
		ApiCall__c item = (ApiCall__c)apiCallBuilder(SEL_ApiCall.STATUS_QUEUED)
				.withOverride(ApiCall__c.Retries__c, 0)
				.withoutInsertion()
				.build();

		Datetime nextRetry = Datetime.now().addMinutes(5);

		SEL_ApiCall.updateNextRetryInfo(item, nextRetry);

		Assert.areEqual(nextRetry, item.NextRetry__c, 'NextRetry__c should be set');
		Assert.areEqual(1, item.Retries__c, 'Retries__c should be incremented');
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, item.Status__c, 'Status__c should be Retry');
	}

	/**
	 * @description Tier-A — proves SEL_ApiCall.findByServiceName returns rows
	 * when invoked by a subscriber user on the Minimum Access - Salesforce profile who has no FLS
	 * on kern__ApiCall__c. The framework-owned selector declares `systemModeRequired() = true`, so
	 * its internal QRY_Builder must elevate to SYSTEM_MODE and the query must return the seeded
	 * rows regardless of the running user's FLS.
	 *
	 * Catches: a future refactor that demotes SEL_ApiCall.systemModeRequired() to false, or deletes
	 * the override entirely, would cause the low-privilege user's query to fail with "No such
	 * column: kern__Status__c" — this test fails at 2GP validated-build time rather than at
	 * subscriber scratch-org time.
	 *
	 * @see SEL_ApiCall.findByServiceName
	 * @see SEL_ApiCall.systemModeRequired
	 */
	@IsTest
	private static void shouldFindByServiceNameForLowPrivilegeUser()
	{
		User lowPrivilegeUser = getLowPrivilegeUser();
		ApiCall__c seededCall;

		System.runAs(getTestAdmin())
		{
			seededCall = (ApiCall__c)apiCallBuilder(SEL_ApiCall.STATUS_QUEUED)
					.withOverride(ApiCall__c.OwnerId, lowPrivilegeUser.Id)
					.build();
		}

		Assert.isNotNull(seededCall?.Id, 'Seeded ApiCall__c should have an Id');

		System.runAs(lowPrivilegeUser)
		{
			List<ApiCall__c> results = new SEL_ApiCall().findByServiceName(TEST_SERVICE_NAME);

			Assert.areEqual(1, results.size(), 'Should find the seeded API call for low-privilege caller');
			Assert.areEqual(TEST_SERVICE_NAME, results[0].ServiceName__c, 'ServiceName should match the seeded value');
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup. Used by the
	 * tier-A test to seed the ApiCall__c row before the low-privilege user queries it.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the tier-A test to exercise SEL_ApiCall.findByServiceName and
	 * prove the framework-owned selector elevates internally via systemModeRequired().
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}
}