// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for FastStart_Validation_DEMO — wrapper-service smoke tests.
 *
 * The FastStart_RequiresDescription rule fixture is deployed INACTIVE
 * (kern__BypassExecution__c=true) so it does not contaminate other Account inserts in the
 * subscriber test org. Subscribers can activate the rule (flip the flag) and then use
 * kern.UTIL_ValidationTestHelper.assertRuleFails / assertRulePasses to evaluate it in-memory —
 * those helpers are shown in the Fast Start - Custom Validations.md doc text.
 *
 * Note: kern.TST_Factory.newValidationRule is @TestVisible private inside the kern
 * namespace and @TestVisible does not cross namespaces, so it is NOT callable from
 * subscriber @IsTest classes. CMDT deploy is the only valid subscriber setup path.
 *
 * @see FastStart_Validation_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FastStart_Validation_DEMO_TEST
{
	/**
	 * @description Verifies that validateAndSave returns a successful result when the
	 *              Account passes all active validation rules. Bypasses org-level rules
	 *              so the test focuses on the wrapper's behaviour.
	 */
	@IsTest
	private static void shouldSucceedWhenAccountIsValid()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');

		Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Description, 'A valid description')
			.withoutInsertion()
			.build();

		kern.DML_Builder.TransactionResult result = new FastStart_Validation_DEMO().validateAndSave(account);

		Assert.isTrue(result.isSuccess(), 'Save should succeed for a valid Account');
		Assert.areEqual(1, result.getSuccessCount(), 'One record should be inserted');
	}

	/**
	 * @description Verifies that validateAndSave surfaces failures when a rule rejects
	 *              the record. Uses an Account that fails a known org-level rule
	 *              (Name = null) instead of attempting to set up an isolated kern
	 *              ValidationRule fixture (which would require @TestVisible private
	 *              factory methods not visible from subscriber @IsTest context).
	 */
	@IsTest
	private static void shouldFailWhenAccountIsInvalid()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');

		Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, null)
			.withoutInsertion()
			.build();

		kern.DML_Builder.TransactionResult result = new FastStart_Validation_DEMO().validateAndSave(account);

		Assert.isFalse(result.isSuccess(), 'Save should fail for an invalid Account');
		Assert.isTrue(result.getFailureCount() > 0, 'Failure count should be non-zero');
	}
}
