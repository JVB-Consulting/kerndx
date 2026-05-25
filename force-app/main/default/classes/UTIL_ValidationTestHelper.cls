// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Reusable utility class for testing validation rules.
 * This is NOT a test class itself but provides assertion methods for subscriber test classes
 * and the framework's own test classes to verify validation rule behavior.
 *
 * The class validates records in-memory using the validation framework and provides
 * focused assertions for specific rule failures or passes.
 *
 * @see UTIL_ValidationRule
 * @see UTIL_ValidationRule_TEST
 *
 * @author Jason van Beukering
 *
 * @group Testing
 *
 * @date January 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * @IsTest
 * private static void shouldRequireEmail()
 * {
 *     Account account = new Account(Name = 'Test');
 *     UTIL_ValidationTestHelper.assertRuleFails(account, 'Account_Requires_Email');
 * }
 * @IsTest
 * private static void shouldPassWhenEmailProvided()
 * {
 *     Account account = new Account(Name = 'Test', Email__c = 'test@test.com');
 *     UTIL_ValidationTestHelper.assertRulePasses(account, 'Account_Requires_Email');
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class UTIL_ValidationTestHelper
{
	/**
	 * @description Validates a record and asserts that a specific rule failed.
	 * The record is validated in-memory against all applicable validation rules,
	 * then the assertion verifies that the specified rule produced an error.
	 *
	 * @param record The record to validate
	 * @param ruleDeveloperName The DeveloperName of the validation rule expected to fail
	 *
	 * @throws System.AssertException if the rule did not fail for this record
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Account account = new Account(Name = 'Test');
	 * UTIL_ValidationTestHelper.assertRuleFails(account, 'Account_Requires_Email');
	 * ```
	 */
	global static void assertRuleFails(SObject record, String ruleDeveloperName)
	{
		assertRuleFails(record, null, ruleDeveloperName, TriggerOperation.BEFORE_INSERT);
	}

	/**
	 * @description Validates a record and asserts that a specific rule failed, with custom operation.
	 *
	 * @param record The new record to validate
	 * @param oldRecord The old version of the record (for update scenarios)
	 * @param ruleDeveloperName The DeveloperName of the validation rule expected to fail
	 * @param operation The trigger operation context
	 *
	 * @throws System.AssertException if the rule did not fail for this record
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Account oldAccount = new Account(Name = 'Test', Status__c = 'Draft');
	 * Account newAccount = oldAccount.clone();
	 * newAccount.Status__c = 'Active';
	 * UTIL_ValidationTestHelper.assertRuleFails(newAccount, oldAccount, 'Account_Cannot_Reactivate', TriggerOperation.BEFORE_UPDATE);
	 * ```
	 */
	global static void assertRuleFails(SObject record, SObject oldRecord, String ruleDeveloperName, TriggerOperation operation)
	{
		UTIL_ValidationRule.ValidationResult validationResult = validateSingleRecord(record, oldRecord, operation);
		UTIL_ValidationRule.ValidationError ruleError = findErrorByRuleName(validationResult, ruleDeveloperName);

		Assert.isNotNull
				(
						ruleError,
						'Expected validation rule "' + ruleDeveloperName + '" to fail, but it did not. ' +
						getActualErrorsSummary(validationResult)
				);
	}

	/**
	 * @description Validates a record and asserts that a specific rule did NOT fail.
	 * The record is validated in-memory against all applicable validation rules,
	 * then the assertion verifies that the specified rule did not produce an error.
	 *
	 * @param record The record to validate
	 * @param ruleDeveloperName The DeveloperName of the validation rule expected to pass
	 *
	 * @throws System.AssertException if the rule failed for this record
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Account account = new Account(Name = 'Test', Email__c = 'test@test.com');
	 * UTIL_ValidationTestHelper.assertRulePasses(account, 'Account_Requires_Email');
	 * ```
	 */
	global static void assertRulePasses(SObject record, String ruleDeveloperName)
	{
		assertRulePasses(record, null, ruleDeveloperName, TriggerOperation.BEFORE_INSERT);
	}

	/**
	 * @description Validates a record and asserts that a specific rule did NOT fail, with custom operation.
	 *
	 * @param record The new record to validate
	 * @param oldRecord The old version of the record (for update scenarios)
	 * @param ruleDeveloperName The DeveloperName of the validation rule expected to pass
	 * @param operation The trigger operation context
	 *
	 * @throws System.AssertException if the rule failed for this record
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Account oldAccount = new Account(Name = 'Test', Status__c = 'Active');
	 * Account newAccount = oldAccount.clone();
	 * newAccount.Status__c = 'Inactive';
	 * UTIL_ValidationTestHelper.assertRulePasses(newAccount, oldAccount, 'Account_Cannot_Reactivate', TriggerOperation.BEFORE_UPDATE);
	 * ```
	 */
	global static void assertRulePasses(SObject record, SObject oldRecord, String ruleDeveloperName, TriggerOperation operation)
	{
		UTIL_ValidationRule.ValidationResult validationResult = validateSingleRecord(record, oldRecord, operation);
		UTIL_ValidationRule.ValidationError ruleError = findErrorByRuleName(validationResult, ruleDeveloperName);

		Assert.isNull
				(
						ruleError,
						'Expected validation rule "' + ruleDeveloperName + '" to pass, but it failed with message: "' +
						(ruleError != null ? ruleError.message : '') + '"'
				);
	}

	/**
	 * @description Validates a record and returns the full result for advanced assertions.
	 * Use this when you need to make multiple assertions or custom assertions on a single validation run.
	 *
	 * @param record The record to validate
	 *
	 * @return The ValidationResult containing all errors/warnings
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Account account = new Account(Name = 'Test');
	 * UTIL_ValidationRule.ValidationResult result = UTIL_ValidationTestHelper.validate(account);
	 * Assert.areEqual(2, result.errors.size(), 'Expected 2 validation errors');
	 * ```
	 */
	global static UTIL_ValidationRule.ValidationResult validate(SObject record)
	{
		return validateSingleRecord(record, null, TriggerOperation.BEFORE_INSERT);
	}

	/**
	 * @description Validates a record and returns the full result for advanced assertions with operation context.
	 *
	 * @param record The new record to validate
	 * @param oldRecord The old version of the record (for update scenarios)
	 * @param operation The trigger operation context
	 *
	 * @return The ValidationResult containing all errors/warnings
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Account oldAccount = new Account(Id = '001000000000001', Name = 'Test');
	 * Account newAccount = oldAccount.clone(true, true, true, true);
	 * newAccount.Name = 'Updated';
	 * UTIL_ValidationRule.ValidationResult result = UTIL_ValidationTestHelper.validate(newAccount, oldAccount, TriggerOperation.BEFORE_UPDATE);
	 * Assert.isTrue(result.isValid, 'Expected record to pass validation');
	 * ```
	 */
	global static UTIL_ValidationRule.ValidationResult validate(SObject record, SObject oldRecord, TriggerOperation operation)
	{
		return validateSingleRecord(record, oldRecord, operation);
	}

	/**
	 * @description Validates a single record and returns the result.
	 *
	 * @param record The new record to validate
	 * @param oldRecord The old record (may be null)
	 * @param operation The trigger operation
	 *
	 * @return The validation result for the record
	 */
	private static UTIL_ValidationRule.ValidationResult validateSingleRecord(SObject record, SObject oldRecord, TriggerOperation operation)
	{
		List<SObject> newRecords = new List<SObject> {record};
		List<SObject> oldRecords = oldRecord != null ? new List<SObject> {oldRecord} : null;

		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate(newRecords, oldRecords, operation);

		return results.isEmpty() ? new UTIL_ValidationRule.ValidationResult(0, record.Id) : results[0];
	}

	/**
	 * @description Finds a validation error by rule DeveloperName.
	 *
	 * @param validationResult The validation result to search
	 * @param ruleDeveloperName The rule DeveloperName to find
	 *
	 * @return The matching ValidationError, or null if not found
	 */
	private static UTIL_ValidationRule.ValidationError findErrorByRuleName
			(
					UTIL_ValidationRule.ValidationResult validationResult,
					String ruleDeveloperName
			)
	{
		for(UTIL_ValidationRule.ValidationError error : validationResult.errors)
		{
			if(error.ruleName == ruleDeveloperName)
			{
				return error;
			}
		}
		return null;
	}

	/**
	 * @description Builds a summary of actual errors for assertion messages.
	 *
	 * @param validationResult The validation result
	 *
	 * @return A summary string of actual errors, or a message if none
	 */
	@TestVisible
	private static String getActualErrorsSummary(UTIL_ValidationRule.ValidationResult validationResult)
	{
		if(validationResult.errors.isEmpty())
		{
			return 'No validation errors were generated.';
		}

		List<String> errorSummaries = new List<String>();
		for(UTIL_ValidationRule.ValidationError error : validationResult.errors)
		{
			errorSummaries.add(error.ruleName);
		}
		return 'Actual failed rules: [' + String.join(errorSummaries, ', ') + ']';
	}
}