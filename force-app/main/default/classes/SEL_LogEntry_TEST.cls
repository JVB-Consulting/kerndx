// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_LogEntry selector.
 *
 * @see SEL_LogEntry
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_LogEntry_TEST
{
	/**
	 * @description The class method name used in test log records.
	 */
	private static final String TEST_CLASS_METHOD = 'SEL_LogEntry_TEST/shouldFindByMethod';

	/**
	 * @description Company name discriminator for the committed test admin user set up in
	 * @TestSetup and retrieved via SEL_User.findByCompanyName.
	 */
	private static final String TEST_ADMIN_COMPANY = 'SEL_LogEntry_TEST-admin';

	/**
	 * @description Company name discriminator for the committed low-privilege user (Minimum Access
	 * - Salesforce profile) set up in @TestSetup and used by the tier-A regression test.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'SEL_LogEntry_TEST-low-privilege';

	/**
	 * @description Commits both a test-admin and a low-privilege user in @TestSetup's separate
	 * transaction so the tier-A test (shouldFindByMethodForLowPrivilegeUser) can use System.runAs
	 * against either without triggering MIXED_DML_OPERATION. User is a Setup object, so User DML
	 * cannot mix with standard/custom-object DML in the same transaction; pre-provisioning here
	 * satisfies that boundary.
	 *
	 * Only the tier-A test uses these users — existing SEL_LogEntry tests continue to run as the
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
	 * @description Tests that findByMethod returns a matching log record.
	 */
	@IsTest
	private static void shouldFindByMethod()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.ClassMethod__c, TEST_CLASS_METHOD)
				.build();

		LogEntry__c result = new SEL_LogEntry().findByMethod(TEST_CLASS_METHOD);

		Assert.isNotNull(result, 'Should return matching log record');
		Assert.areEqual(TEST_CLASS_METHOD, result.ClassMethod__c, 'Should match the class method');
	}

	/**
	 * @description Tests that findAllByMethod returns all matching log records.
	 */
	@IsTest
	private static void shouldFindAllByMethod()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.ClassMethod__c, TEST_CLASS_METHOD)
				.withCount(2)
				.buildList();

		List<LogEntry__c> results = new SEL_LogEntry().findAllByMethod(TEST_CLASS_METHOD);

		Assert.areEqual(2, results.size(), 'Should return all matching records');
	}

	/**
	 * @description Tests that findPerformanceLogByMethod returns the log whose
	 * ShortMessage contains the performance needle.
	 */
	@IsTest
	private static void shouldFindPerformanceLogByShortMessage()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.ClassMethod__c, TEST_CLASS_METHOD)
				.withOverride(LogEntry__c.ShortMessage__c, 'My op completed in 42ms')
				.build();

		LogEntry__c result = new SEL_LogEntry().findPerformanceLogByMethod(TEST_CLASS_METHOD);

		Assert.isNotNull(result, 'Should match on ShortMessage');
	}

	/**
	 * @description Tests that findPerformanceLogByMethod also matches when the needle
	 * is only in the Message field (ShortMessage can be blank).
	 */
	@IsTest
	private static void shouldFindPerformanceLogByMessage()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.ClassMethod__c, TEST_CLASS_METHOD)
				.withOverride(LogEntry__c.Message__c, 'My op completed in 42ms')
				.build();

		LogEntry__c result = new SEL_LogEntry().findPerformanceLogByMethod(TEST_CLASS_METHOD);

		Assert.isNotNull(result, 'Should match on Message when ShortMessage is blank');
	}

	/**
	 * @description Tests that findPerformanceLogByMethod returns null when no log for
	 * the given method contains the performance needle.
	 */
	@IsTest
	private static void shouldReturnNullWhenNoPerformanceNeedleMatches()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.ClassMethod__c, TEST_CLASS_METHOD)
				.withOverride(LogEntry__c.ShortMessage__c, 'Unrelated message')
				.build();

		LogEntry__c result = new SEL_LogEntry().findPerformanceLogByMethod(TEST_CLASS_METHOD);

		Assert.isNull(result, 'Should return null when no log contains the needle');
	}

	/**
	 * @description Tests that findByLogLevel returns matching log records.
	 */
	@IsTest
	private static void shouldFindByLogLevel()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.LogLevel__c, 'Error')
				.build();

		List<LogEntry__c> results = new SEL_LogEntry().findByLogLevel('Error');

		Assert.isFalse(results.isEmpty(), 'Should return matching log records');
	}

	/**
	 * @description Tests that getRecordCount returns the correct count.
	 */
	@IsTest
	private static void shouldGetRecordCount()
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withCount(3)
				.buildList();

		Integer result = new SEL_LogEntry().getRecordCount();

		Assert.areEqual(3, result, 'Should return count of 3');
	}

	/**
	 * @description Tests that getAll returns records within a test context.
	 */
	@IsTest
	private static void shouldGetAll()
	{
		TST_Builder.of(LogEntry__c.SObjectType).build();

		List<LogEntry__c> results = new SEL_LogEntry().getAll();

		Assert.isFalse(results.isEmpty(), 'Should return records in test context');
	}

	/**
	 * @description Tests that `findAllOrderedByCreatedDateDesc` returns records ordered by CreatedDate
	 * descending in test context. Bypass-audit and performance-log assertions rely on this ordering
	 * so the first match in iteration is the most-recent emission.
	 */
	@IsTest
	private static void shouldFindAllOrderedByCreatedDateDesc()
	{
		TST_Builder.of(LogEntry__c.SObjectType).withCount(3).buildList();

		List<LogEntry__c> results = new SEL_LogEntry().findAllOrderedByCreatedDateDesc();

		Assert.isFalse(results.isEmpty(), 'Should return records in test context');
		for(Integer i = 1; i < results.size(); i++)
		{
			Assert.isTrue(results[i - 1].CreatedDate >= results[i].CreatedDate,
					'Records must be ordered CreatedDate descending so first match is most-recent');
		}
	}

	/**
	 * @description Tests that `parseContextDataForTest` returns the inner context map when the
	 * envelope is well-formed JSON wrapping a `contextData` key.
	 */
	@IsTest
	private static void shouldParseContextDataEnvelopeForTest()
	{
		LogEntry__c entry = new LogEntry__c(ContextData__c = '{"contextData":{"surface":"query","action":"BYPASS"}}');

		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);

		Assert.isNotNull(context, 'Should unwrap the contextData envelope');
		Assert.areEqual('query', context.get('surface'), 'Should expose the surface key');
		Assert.areEqual('BYPASS', context.get('action'), 'Should expose the action key');
	}

	/**
	 * @description Tests that `parseContextDataForTest` returns null for a null entry, a null
	 * `ContextData__c`, or a blank `ContextData__c`. Centralised null-handling lets test helpers
	 * skip per-call guards.
	 */
	@IsTest
	private static void shouldReturnNullForNullOrBlankContextData()
	{
		Assert.isNull(SEL_LogEntry.parseContextDataForTest(null), 'Should return null for null entry');
		Assert.isNull(SEL_LogEntry.parseContextDataForTest(new LogEntry__c()), 'Should return null for null ContextData__c');
		Assert.isNull(SEL_LogEntry.parseContextDataForTest(new LogEntry__c(ContextData__c = '')), 'Should return null for blank ContextData__c');
	}

	/**
	 * @description Tier-A — proves SEL_LogEntry.findByMethod returns rows when
	 * invoked by a subscriber user on the Minimum Access - Salesforce profile who has no FLS on
	 * kern__LogEntry__c. The framework-owned selector declares `systemModeRequired() = true`, so
	 * its internal QRY_Builder must elevate to SYSTEM_MODE and the query must return the seeded
	 * rows regardless of the running user's FLS.
	 *
	 * Catches: a future refactor that demotes SEL_LogEntry.systemModeRequired() to false, or
	 * deletes the override entirely, would cause the low-privilege user's query to fail with "No
	 * such column: kern__ClassMethod__c" — this test fails at 2GP validated-build time rather than
	 * at subscriber scratch-org time.
	 *
	 * Note on method selection — T8's plan entry cites `findByCorrelationId(id)`; the selector
	 * does not expose that method. `findByMethod` covers the same elevation-via-systemModeRequired
	 * regression surface since both go through the shared SEL_Base.query property.
	 *
	 * @see SEL_LogEntry.findByMethod
	 * @see SEL_LogEntry.systemModeRequired
	 */
	@IsTest
	private static void shouldFindByMethodForLowPrivilegeUser()
	{
		final String classMethod = 'SEL_LogEntry_TEST/shouldFindByMethodForLowPrivilegeUser';

		System.runAs(getTestAdmin())
		{
			TST_Builder.of(LogEntry__c.SObjectType)
					.withOverride(LogEntry__c.ClassMethod__c, classMethod)
					.build();
		}

		System.runAs(getLowPrivilegeUser())
		{
			LogEntry__c result = new SEL_LogEntry().findByMethod(classMethod);

			Assert.isNotNull(result, 'Should find the seeded LogEntry__c for low-privilege caller');
			Assert.areEqual(classMethod, result.ClassMethod__c, 'ClassMethod__c should match the seeded value');
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup. Used by the
	 * tier-A test to seed the LogEntry__c row before the low-privilege user queries it.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the tier-A test to exercise SEL_LogEntry.findByMethod and
	 * prove the framework-owned selector elevates internally via systemModeRequired().
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}
}