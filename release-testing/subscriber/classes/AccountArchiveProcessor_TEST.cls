// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for AccountArchiveProcessor.
 *
 * @see AccountArchiveProcessor
 *
 * @author your.name@company.com
 *
 * @group Account Management
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(IsParallel=true)
private class AccountArchiveProcessor_TEST
{
	/**
	 * @description Tests async processing via the framework launcher.
	 */
	@IsTest
	private static void shouldArchiveAccountsViaFramework()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		Account record = (Account)kern.TST_Builder.of(Account.SObjectType).build();

		Test.startTest();
		kern.UTIL_AsynchronousJobLauncher.process(
				new List<Object> {record},
				new AccountArchiveProcessor()
		);
		Test.stopTest();

		Account result = (Account)kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Description})
				.condition(Account.Id).equals(record.Id)
				.getFirst();
		Assert.areEqual(AccountArchiveProcessor.DESCRIPTION_ARCHIVED, result.Description, 'Should be archived');
	}

	/**
	 * @description Tests the processor execute method directly.
	 */
	@IsTest
	private static void shouldProcessRecordsDirectly()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		Account record = (Account)kern.TST_Builder.of(Account.SObjectType).build();

		new AccountArchiveProcessor().execute(new List<Object> {record});

		Account result = (Account)kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Description})
				.condition(Account.Id).equals(record.Id)
				.getFirst();
		Assert.areEqual(AccountArchiveProcessor.DESCRIPTION_ARCHIVED, result.Description, 'Should be archived');
	}
}
