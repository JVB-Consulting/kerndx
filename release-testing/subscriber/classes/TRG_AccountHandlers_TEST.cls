// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for Account trigger handlers: TRG_ValidateAccountName,
 * TRG_StampAccountSource (beforeUpdate), and TRG_DetectNameChange (afterUpdate).
 *
 * @see TRG_ValidateAccountName
 * @see TRG_StampAccountSource
 * @see TRG_DetectNameChange
 *
 * @author your.name@company.com
 *
 * @group Trigger Actions
 *
 * @date March 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class TRG_AccountHandlers_TEST
{
	/**
	 * @description Tests that inserting an Account with BLOCKED in the name is rejected.
	 */
	@IsTest
	private static void shouldBlockInsertWhenNameContainsBlocked()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');

		try
		{
			insert new Account(Name = 'BLOCKED Test Account', Industry = 'Technology', Phone = '555-0100');
			Assert.fail('Should throw DmlException for BLOCKED name');
		}
		catch(DmlException error)
		{
			Assert.isTrue(error.getMessage().contains('BLOCKED'), 'Error should mention BLOCKED');
		}
	}

	/**
	 * @description Tests that updating an Account name re-stamps source and creates a name-change task.
	 */
	@IsTest
	private static void shouldStampSourceAndDetectNameChangeOnUpdate()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');

		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, 'Technology')
				.withOverride(Account.Phone, '555-0100')
				.build();

		record.AccountSource = null;
		record.Name = 'Updated Name ' + Datetime.now().getTime();
		update record;

		Account updated =
		[
				SELECT AccountSource
				FROM Account
				WHERE Id = :record.Id
		];
		Assert.areEqual('Subscriber Trigger', updated.AccountSource, 'Should re-stamp source on name change');

		List<Task> tasks =
		[
				SELECT Subject
				FROM Task
				WHERE WhatId = :record.Id
				AND Subject LIKE 'Name Changed:%'
		];
		Assert.isFalse(tasks.isEmpty(), 'Should create a name-change detection task');
	}
}
