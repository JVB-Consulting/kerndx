// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for UTIL_ValidationTestHelper.
 * Tests the assertion methods and validation helper functionality.
 *
 * @see UTIL_ValidationTestHelper
 * @see UTIL_ValidationRule
 *
 * @author Jason van Beukering
 *
 * @group Testing
 *
 * @date January 2026, May 2026
 */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class UTIL_ValidationTestHelper_TEST
{
	/**
	 * @description Reference to SEL_Foobar.OBJECT_NAME for package-controlled object testing.
	 */
	private static final String TEST_OBJECT_NAME = SEL_Foobar.OBJECT_NAME;

	/**
	 * @description FoobarContext class name for validation rule testing.
	 */
	private static final String FOOBAR_CONTEXT_CLASS = UTIL_FormulaContext.FoobarContext.class.getName();

	/**
	 * @description Tests that assertRuleFails succeeds when rule fails.
	 */
	@IsTest
	private static void shouldAssertRuleFailsSucceedsWhenRuleFails()
	{
		LOG_Builder.ignoreTestMode = true;
		setupTestRule('Require_Positive', 'newRecord.' + SEL_Foobar.FIELD_INTEGER + ' <= 0', 'Integer required');

		Foobar__c record = TST_Factory.newFoobar();
		record.put(SEL_Foobar.FIELD_INTEGER, 0);

		assertValidationBehavior(record, 'Require_Positive', true);
	}

	/**
	 * @description Tests that assertRulePasses succeeds when rule passes.
	 */
	@IsTest
	private static void shouldAssertRulePassesSucceedsWhenRulePasses()
	{
		LOG_Builder.ignoreTestMode = true;
		setupTestRule('Require_Positive', 'newRecord.' + SEL_Foobar.FIELD_INTEGER + ' <= 0', 'Integer required');

		Foobar__c record = TST_Factory.newFoobar();
		record.put(SEL_Foobar.FIELD_INTEGER, 50);

		assertValidationBehavior(record, 'Require_Positive', false);
	}

	/**
	 * @description Tests assertRuleFails with update operation context.
	 */
	@IsTest
	private static void shouldAssertRuleFailsWithUpdateOperation()
	{
		LOG_Builder.ignoreTestMode = true;
		setupTestRule('Require_Positive', 'newRecord.' + SEL_Foobar.FIELD_INTEGER + ' <= 0', 'Integer required', TriggerOperation.BEFORE_UPDATE);

		Foobar__c oldRecord = TST_Factory.newFoobar();
		oldRecord.put(SEL_Foobar.FIELD_INTEGER, 100);
		Foobar__c newRecord = TST_Factory.newFoobar();
		newRecord.put(SEL_Foobar.FIELD_INTEGER, -1);

		assertValidationBehavior(newRecord, oldRecord, 'Require_Positive', TriggerOperation.BEFORE_UPDATE, true);
	}

	/**
	 * @description Tests assertRulePasses with update operation context.
	 */
	@IsTest
	private static void shouldAssertRulePassesWithUpdateOperation()
	{
		LOG_Builder.ignoreTestMode = true;
		setupTestRule('Require_Positive', 'newRecord.' + SEL_Foobar.FIELD_INTEGER + ' <= 0', 'Integer required', TriggerOperation.BEFORE_UPDATE);

		Foobar__c oldRecord = TST_Factory.newFoobar();
		oldRecord.put(SEL_Foobar.FIELD_INTEGER, -1);
		Foobar__c newRecord = TST_Factory.newFoobar();
		newRecord.put(SEL_Foobar.FIELD_INTEGER, 100);

		assertValidationBehavior(newRecord, oldRecord, 'Require_Positive', TriggerOperation.BEFORE_UPDATE, false);
	}

	/**
	 * @description Tests validate method returns full ValidationResult.
	 */
	@IsTest
	private static void shouldValidateReturnsValidationResult()
	{
		LOG_Builder.ignoreTestMode = true;
		setupTestRule('Require_Positive', 'newRecord.' + SEL_Foobar.FIELD_INTEGER + ' <= 0', 'Integer required');

		Foobar__c record = TST_Factory.newFoobar();
		record.put(SEL_Foobar.FIELD_INTEGER, -5);

		Test.startTest();
		UTIL_ValidationRule.ValidationResult result = UTIL_ValidationTestHelper.validate(record);
		Test.stopTest();

		Assert.isNotNull(result, 'Result should not be null');
		Assert.isFalse(result.isValid, 'Result should be invalid');
		Assert.areEqual(1, result.errors.size(), 'Should have one error');
		Assert.areEqual('Require_Positive', result.errors[0].ruleName, 'Rule name should match');
	}

	/**
	 * @description Tests validate method with operation context.
	 */
	@IsTest
	private static void shouldValidateReturnsValidationResultWithOperation()
	{
		LOG_Builder.ignoreTestMode = true;
		setupTestRule('Require_Positive', 'newRecord.' + SEL_Foobar.FIELD_INTEGER + ' <= 0', 'Integer required', TriggerOperation.BEFORE_UPDATE);

		Foobar__c oldRecord = TST_Factory.newFoobar();
		oldRecord.put(SEL_Foobar.FIELD_INTEGER, 100);
		Foobar__c newRecord = TST_Factory.newFoobar();
		newRecord.put(SEL_Foobar.FIELD_INTEGER, -1);

		Test.startTest();
		UTIL_ValidationRule.ValidationResult result = UTIL_ValidationTestHelper.validate(newRecord, oldRecord, TriggerOperation.BEFORE_UPDATE);
		Test.stopTest();

		Assert.isNotNull(result, 'Result should not be null');
		Assert.isFalse(result.isValid, 'Result should be invalid');
	}

	/**
	 * @description Tests that validation returns valid result when no rules configured.
	 */
	@IsTest
	private static void shouldReturnValidResultWhenNoRulesConfigured()
	{
		Foobar__c record = TST_Factory.newFoobar();
		record.put(SEL_Foobar.FIELD_INTEGER, 100);

		Test.startTest();
		UTIL_ValidationRule.ValidationResult result = UTIL_ValidationTestHelper.validate(record);
		Test.stopTest();

		Assert.isNotNull(result, 'Result should not be null');
		Assert.isTrue(result.isValid, 'Result should be valid when no rules configured');
	}

	/**
	 * @description Tests getActualErrorsSummary returns correct message when no errors exist.
	 */
	@IsTest
	private static void shouldReturnNoErrorsMessageWhenErrorsEmpty()
	{
		UTIL_ValidationRule.ValidationResult emptyResult = new UTIL_ValidationRule.ValidationResult(0, null);

		Test.startTest();
		String summary = UTIL_ValidationTestHelper.getActualErrorsSummary(emptyResult);
		Test.stopTest();

		Assert.areEqual('No validation errors were generated.', summary, 'Should return empty errors message');
	}

	/**
	 * @description Asserts validation behavior for insert operations.
	 *
	 * @param record The record to validate
	 * @param ruleName The rule developer name
	 * @param expectFail True if the rule should fail, false if it should pass
	 */
	private static void assertValidationBehavior(SObject record, String ruleName, Boolean expectFail)
	{
		Test.startTest();
		Exception caughtException = null;
		try
		{
			if(expectFail)
			{
				UTIL_ValidationTestHelper.assertRuleFails(record, ruleName);
			}
			else
			{
				UTIL_ValidationTestHelper.assertRulePasses(record, ruleName);
			}
		}
		catch(Exception caught)
		{
			caughtException = caught;
		}
		Test.stopTest();

		Assert.isNull(caughtException, 'Should not throw when rule ' + (expectFail ? 'fails' : 'passes') + ' as expected');
	}

	/**
	 * @description Asserts validation behavior for update operations.
	 *
	 * @param newRecord The new record to validate
	 * @param oldRecord The old record for update context
	 * @param ruleName The rule developer name
	 * @param operation The trigger operation
	 * @param expectFail True if the rule should fail, false if it should pass
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static void assertValidationBehavior
			(
					SObject newRecord,
					SObject oldRecord,
					String ruleName,
					TriggerOperation operation,
					Boolean expectFail
			)
	{
		Test.startTest();
		Exception caughtException = null;
		try
		{
			if(expectFail)
			{
				UTIL_ValidationTestHelper.assertRuleFails(newRecord, oldRecord, ruleName, operation);
			}
			else
			{
				UTIL_ValidationTestHelper.assertRulePasses(newRecord, oldRecord, ruleName, operation);
			}
		}
		catch(Exception caught)
		{
			caughtException = caught;
		}
		Test.stopTest();

		Assert.isNull(caughtException, 'Should not throw when rule ' + (expectFail ? 'fails' : 'passes') + ' as expected');
	}

	/**
	 * @description Sets up a test validation rule using the test cache override pattern.
	 *
	 * @param ruleName The rule developer name
	 * @param formula The rule formula
	 * @param errorMessage The error message
	 */
	private static void setupTestRule(String ruleName, String formula, String errorMessage)
	{
		setupTestRule(ruleName, formula, errorMessage, TriggerOperation.BEFORE_INSERT);
	}

	/**
	 * @description Sets up a test validation rule using the test cache override pattern with operation.
	 *
	 * @param ruleName The rule developer name
	 * @param formula The rule formula
	 * @param errorMessage The error message
	 * @param operation The trigger operation
	 */
	private static void setupTestRule(String ruleName, String formula, String errorMessage, TriggerOperation operation)
	{
		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(TEST_OBJECT_NAME);
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);

		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.DeveloperName => ruleName,
								ValidationRule__mdt.RuleFormula__c => formula,
								ValidationRule__mdt.ErrorMessage__c => errorMessage
						}
				);

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(operation.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(TEST_OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;
	}
}