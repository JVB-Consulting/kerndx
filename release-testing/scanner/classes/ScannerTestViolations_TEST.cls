// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Deliberate test-class violations for KernDX PMD rules.
 *
 * Expected violations:
 * - KernNoLegacyAssert (x3: assert, assertEquals, assertNotEquals)
 * - KernUseTestBuilder (x1: new Account(...) in test)
 * - KernNoDirectDML (x1: insert in test)
 * - KernNoInlineSOQL (x1: inline SOQL in test)
 */
@IsTest(SeeAllData=false IsParallel=true)
private class ScannerTestViolations_TEST
{
	/**
	 * @description Violates KernNoLegacyAssert — System.assert().
	 */
	@IsTest
	private static void violateLegacyAssert()
	{
		System.assert(true, 'Should use Assert.isTrue');
	}

	/**
	 * @description Violates KernNoLegacyAssert — System.assertEquals().
	 */
	@IsTest
	private static void violateLegacyAssertEquals()
	{
		System.assertEquals(1, 1, 'Should use Assert.areEqual');
	}

	/**
	 * @description Violates KernNoLegacyAssert — System.assertNotEquals().
	 */
	@IsTest
	private static void violateLegacyAssertNotEquals()
	{
		System.assertNotEquals(1, 2, 'Should use Assert.areNotEqual');
	}

	/**
	 * @description Violates KernUseTestBuilder — new Account(Name = ...) in test.
	 */
	@IsTest
	private static void violateTestBuilder()
	{
		Account account = new Account(Name = 'Should use TST_Builder');
	}

	/**
	 * @description Violates KernNoDirectDML — insert in test.
	 */
	@IsTest
	private static void violateDirectDmlInTest()
	{
		Account account = new Account(Name = 'Test');
		insert Account;
	}

	/**
	 * @description Violates KernNoInlineSOQL — inline SOQL in test.
	 */
	@IsTest
	private static void violateInlineSoqlInTest()
	{
		List<Account> accounts =
		[
				SELECT Id
				FROM Account
				LIMIT 1
		];
	}
}
