// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SVC_AccountValidator.
 *
 * @see SVC_AccountValidator
 *
 * @author your.name@company.com
 *
 * @group Account Management
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(IsParallel=true)
private class SVC_AccountValidator_TEST
{
	/**
	 * @description Tests that a valid Account produces no issues.
	 */
	@IsTest
	private static void shouldPassWhenAllFieldsPopulated()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, 'Technology')
				.withOverride(Account.BillingCity, 'Melbourne')
				.build();

		List<String> issues = new SVC_AccountValidator().validate(record.Id);

		Assert.isTrue(issues.isEmpty(), 'Should have no issues for valid Account');
	}

	/**
	 * @description Tests that missing fields produce issues.
	 */
	@IsTest
	private static void shouldFailWhenFieldsMissing()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		Account record = (Account)kern.TST_Builder.of(Account.SObjectType).build();

		List<String> issues = new SVC_AccountValidator().validate(record.Id);

		Assert.areEqual(2, issues.size(), 'Should find two issues');
		Assert.isTrue(issues.contains('Industry is required'), 'Should flag missing Industry');
		Assert.isTrue(issues.contains('Billing City is required'), 'Should flag missing Billing City');
	}

	/**
	 * @description Tests that an exception is thrown and logged when the Account does not exist.
	 */
	@IsTest
	private static void shouldThrowWhenAccountNotFound()
	{
		try
		{
			new SVC_AccountValidator().validate('001000000000001AAA');
			Assert.fail('Should throw NullPointerException for non-existent Account');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, NullPointerException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests that log entries are created with record correlation.
	 */
	@IsTest
	private static void shouldCreateLogEntriesWithRecordCorrelation()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		kern.LOG_Builder.ignoreTestMode = true;

		Account record = (Account)kern.TST_Builder.of(Account.SObjectType).build();

		Test.startTest();
		new SVC_AccountValidator().validate(record.Id);
		Test.getEventBus().deliver();
		Test.stopTest();

		String recordIdString = String.valueOf(record.Id);
		List<kern__LogEntry__c> logs =
		[
				SELECT kern__Message__c,
						kern__LogLevel__c,
						kern__RecordId__c,
						kern__ClassMethod__c
				FROM kern__LogEntry__c
				WHERE kern__RecordId__c = :recordIdString
		];

		Assert.isTrue(logs.size() >= 4, 'Should create at least 4 log entries');

		for(kern__LogEntry__c logEntry : logs)
		{
			Assert.areEqual(
					'SVC_AccountValidator.validate',
					logEntry.kern__ClassMethod__c,
					'All logs should reference the validate method'
			);
		}
	}
}
