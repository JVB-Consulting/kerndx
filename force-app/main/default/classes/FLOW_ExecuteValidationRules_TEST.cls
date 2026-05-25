// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for FLOW_ExecuteValidationRules invocable action.
 * Verifies that the invocable correctly executes validation rules and returns results.
 *
 * @see FLOW_ExecuteValidationRules
 * @see UTIL_ValidationRule
 *
 * @author Jason van Beukering
 *
 * @group Validation
 *
 * @date January 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FLOW_ExecuteValidationRules_TEST
{
	private static final String FOOBAR_CONTEXT_CLASS = UTIL_FormulaContext.FoobarContext.class.getName();

	@IsTest
	private static void shouldReturnResponseWithNoErrorsForValidRecords()
	{
		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses =
				executeValidation(new List<SObject> {TST_Factory.newFoobarWithName('Test Record')}, 'BEFORE_INSERT');
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should return one response');
		Assert.isFalse(responses[0].hasErrors, 'Should have no errors for valid record');
		Assert.isFalse(responses[0].hasWarnings, 'Should have no warnings');
		Assert.isNotNull(responses[0].errors, 'Errors list should not be null');
		Assert.isNotNull(responses[0].warnings, 'Warnings list should not be null');
	}

	@IsTest
	private static void shouldReturnEmptyResponseForNullRecords()
	{
		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = executeValidation(null, 'BEFORE_INSERT');
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should return one response');
		Assert.isFalse(responses[0].hasErrors, 'Should have no errors for null records');
		Assert.isFalse(responses[0].hasWarnings, 'Should have no warnings');
		Assert.areEqual('', responses[0].errorMessage, 'Error message should be empty');
	}

	@IsTest
	private static void shouldReturnEmptyResponseForEmptyRecordsList()
	{
		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = executeValidation(new List<SObject>(), 'BEFORE_INSERT');
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should return one response');
		Assert.isFalse(responses[0].hasErrors, 'Should have no errors for empty list');
	}

	@IsTest
	private static void shouldDefaultToBeforeInsertWhenTriggerContextIsBlank()
	{
		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses =
				executeValidation(new List<SObject> {TST_Factory.newFoobarWithName('Test Record')}, '');
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should return one response');
		Assert.isFalse(responses[0].hasErrors, 'Should execute without error');
	}

	@IsTest
	private static void shouldDefaultToBeforeInsertWhenTriggerContextIsNull()
	{
		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses =
				executeValidation(new List<SObject> {TST_Factory.newFoobarWithName('Test Record')}, null);
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should return one response');
		Assert.isFalse(responses[0].hasErrors, 'Should execute without error');
	}

	@IsTest
	private static void shouldParseBeforeInsertTriggerContext()
	{
		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses =
				executeValidation(new List<SObject> {TST_Factory.newFoobar()}, 'BEFORE_INSERT');
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should parse BEFORE_INSERT context');
	}

	@IsTest
	private static void shouldParseBeforeUpdateTriggerContext()
	{
		Foobar__c record = TST_Factory.newFoobar();
		List<SObject> records = new List<SObject> {record};

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = executeValidation(records, 'BEFORE_UPDATE', records);
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should parse BEFORE_UPDATE context');
	}

	@IsTest
	private static void shouldParseAfterInsertTriggerContext()
	{
		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses =
				executeValidation(new List<SObject> {TST_Factory.newFoobar()}, 'AFTER_INSERT');
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should parse AFTER_INSERT context');
	}

	@IsTest
	private static void shouldParseAfterUpdateTriggerContext()
	{
		Foobar__c record = TST_Factory.newFoobar();
		List<SObject> records = new List<SObject> {record};

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = executeValidation(records, 'AFTER_UPDATE', records);
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should parse AFTER_UPDATE context');
	}

	@IsTest
	private static void shouldParseBeforeDeleteTriggerContext()
	{
		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses =
				executeValidation(new List<SObject> {TST_Factory.newFoobar()}, 'BEFORE_DELETE');
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should parse BEFORE_DELETE context');
	}

	@IsTest
	private static void shouldParseAfterDeleteTriggerContext()
	{
		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses =
				executeValidation(new List<SObject> {TST_Factory.newFoobar()}, 'AFTER_DELETE');
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should parse AFTER_DELETE context');
	}

	@IsTest
	private static void shouldParseAfterUndeleteTriggerContext()
	{
		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses =
				executeValidation(new List<SObject> {TST_Factory.newFoobar()}, 'AFTER_UNDELETE');
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should parse AFTER_UNDELETE context');
	}

	@IsTest
	private static void shouldThrowExceptionForInvalidTriggerContext()
	{
		Test.startTest();
		try
		{
			executeValidation(new List<SObject> {TST_Factory.newFoobar()}, 'INVALID_CONTEXT');
			Assert.fail('Should have thrown exception for invalid trigger context');
		}
		catch(System.NoSuchElementException e)
		{
			Assert.isTrue(e.getMessage().contains('INVALID_CONTEXT'), 'Exception should mention invalid value');
		}
		Test.stopTest();
	}

	@IsTest
	private static void shouldHandleMultipleRecordsInSingleRequest()
	{
		List<SObject> records = new List<SObject>
		{
				TST_Factory.newFoobarWithName('Record 1'),
				TST_Factory.newFoobarWithName('Record 2'),
				TST_Factory.newFoobarWithName('Record 3')
		};

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = executeValidation(records, 'BEFORE_INSERT');
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should return one response for batch');
		Assert.isFalse(responses[0].hasErrors, 'Should have no errors');
	}

	@IsTest
	private static void shouldHandleMultipleRequestsInBulk()
	{
		List<FLOW_ExecuteValidationRules.DTO_Request> requests = new List<FLOW_ExecuteValidationRules.DTO_Request>();

		FLOW_ExecuteValidationRules.DTO_Request request1 = new FLOW_ExecuteValidationRules.DTO_Request();
		request1.records = new List<SObject> {TST_Factory.newFoobarWithName('Record 1')};
		request1.triggerContext = 'BEFORE_INSERT';
		requests.add(request1);

		FLOW_ExecuteValidationRules.DTO_Request request2 = new FLOW_ExecuteValidationRules.DTO_Request();
		request2.records = new List<SObject> {TST_Factory.newFoobarWithName('Record 2')};
		request2.triggerContext = 'BEFORE_INSERT';
		requests.add(request2);

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = FLOW_ExecuteValidationRules.execute(requests);
		Test.stopTest();

		Assert.areEqual(2, responses.size(), 'Should return response for each request');
	}

	@IsTest
	private static void shouldInitializeErrorAndWarningLists()
	{
		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses =
				executeValidation(new List<SObject> {TST_Factory.newFoobar()}, 'BEFORE_INSERT');
		Test.stopTest();

		Assert.isNotNull(responses[0].errors, 'Errors list should be initialized');
		Assert.isNotNull(responses[0].warnings, 'Warnings list should be initialized');
		Assert.isTrue(responses[0].errors.isEmpty(), 'Errors list should be empty for valid record');
		Assert.isTrue(responses[0].warnings.isEmpty(), 'Warnings list should be empty for valid record');
	}

	/**
	 * @description Tests that the DTO_FlowValidationError class can be instantiated and its properties set correctly.
	 */
	@IsTest
	private static void shouldCreateFlowValidationErrorDTO()
	{
		Test.startTest();
		DTO_FlowValidationError error = new DTO_FlowValidationError();
		error.ruleName = 'TestRule';
		error.message = 'Test error message';
		error.fieldName = 'TestField__c';
		error.severity = UTIL_ValidationRule.SEVERITY_ERROR;
		error.recordIndex = 0;
		error.isShadowMode = false;
		Test.stopTest();

		Assert.areEqual('TestRule', error.ruleName, 'Rule name should be set');
		Assert.areEqual('Test error message', error.message, 'Message should be set');
		Assert.areEqual('TestField__c', error.fieldName, 'Field name should be set');
		Assert.areEqual(UTIL_ValidationRule.SEVERITY_ERROR, error.severity, 'Severity should be set');
		Assert.areEqual(0, error.recordIndex, 'Record index should be set');
		Assert.isFalse(error.isShadowMode, 'Shadow mode should be set');
	}

	@IsTest
	private static void shouldHandleLowercaseTriggerContext()
	{
		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses =
				executeValidation(new List<SObject> {TST_Factory.newFoobar()}, 'before_insert');
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should handle lowercase trigger context');
	}

	@IsTest
	private static void shouldReturnBlockingErrors()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);
		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.DeveloperName => 'Flow_Blocking_Rule',
								ValidationRule__mdt.RuleFormula__c => 'true',
								ValidationRule__mdt.ErrorMessage__c => 'Blocking error for flow',
								ValidationRule__mdt.ErrorDisplayField__c => SEL_Foobar.FIELD_INTEGER
						}
				);

		configureTestCache(new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup));

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses =
				executeValidation(TST_Factory.newFoobars(1), 'BEFORE_INSERT');
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should return one response');
		Assert.isTrue(responses[0].hasErrors, 'Should have errors');
		Assert.isFalse(responses[0].hasWarnings, 'Should not have warnings');
		Assert.areEqual(1, responses[0].errors.size(), 'Should have one error');
		Assert.areEqual('Flow_Blocking_Rule', responses[0].errors[0].ruleName, 'Rule name should match');
		Assert.areEqual('Blocking error for flow', responses[0].errors[0].message, 'Message should match');
		Assert.areEqual(SEL_Foobar.FIELD_INTEGER, responses[0].errors[0].fieldName, 'Field name should match');
		Assert.areEqual(UTIL_ValidationRule.SEVERITY_ERROR, responses[0].errors[0].severity, 'Severity should be Error');
		Assert.isFalse(responses[0].errors[0].isShadowMode, 'Should not be shadow mode');
		Assert.isTrue(responses[0].errorMessage.contains('Blocking error for flow'), 'Error message should contain error text');
	}

	@IsTest
	private static void shouldReturnWarnings()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);
		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.DeveloperName => 'Flow_Warning_Rule',
								ValidationRule__mdt.RuleFormula__c => 'true',
								ValidationRule__mdt.ErrorMessage__c => 'Warning for flow',
								ValidationRule__mdt.Severity__c => UTIL_ValidationRule.SEVERITY_WARNING
						}
				);

		configureTestCache(new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup));

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses =
				executeValidation(TST_Factory.newFoobars(1), 'BEFORE_INSERT');
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should return one response');
		Assert.isFalse(responses[0].hasErrors, 'Should not have blocking errors');
		Assert.isTrue(responses[0].hasWarnings, 'Should have warnings');
		Assert.areEqual(1, responses[0].warnings.size(), 'Should have one warning');
		Assert.areEqual('Flow_Warning_Rule', responses[0].warnings[0].ruleName, 'Rule name should match');
		Assert.areEqual(UTIL_ValidationRule.SEVERITY_WARNING, responses[0].warnings[0].severity, 'Severity should be Warning');
		Assert.areEqual('', responses[0].errorMessage, 'Error message should be empty for warnings only');
	}

	@IsTest
	private static void shouldReturnShadowModeErrorsAsWarnings()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);
		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.RuleFormula__c => 'true',
								ValidationRule__mdt.ErrorMessage__c => 'Shadow mode error',
								ValidationRule__mdt.ShadowMode__c => true
						}
				);

		configureTestCache(new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup));

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses =
				executeValidation(TST_Factory.newFoobars(1), 'BEFORE_INSERT');
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should return one response');
		Assert.isFalse(responses[0].hasErrors, 'Shadow mode errors should not be blocking');
		Assert.isTrue(responses[0].hasWarnings, 'Shadow mode errors should appear as warnings');
		Assert.areEqual(1, responses[0].warnings.size(), 'Should have one warning');
		Assert.isTrue(responses[0].warnings[0].isShadowMode, 'Should be marked as shadow mode');
		Assert.areEqual(UTIL_ValidationRule.SEVERITY_ERROR, responses[0].warnings[0].severity, 'Severity should still be Error');
	}

	@IsTest
	private static void shouldReturnBothErrorsAndWarnings()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);
		ValidationRule__mdt errorRule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.RuleFormula__c => 'true',
								ValidationRule__mdt.ErrorMessage__c => 'Error message'
						}
				);
		ValidationRule__mdt warningRule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.RuleFormula__c => 'true',
								ValidationRule__mdt.ErrorMessage__c => 'Warning message',
								ValidationRule__mdt.Severity__c => UTIL_ValidationRule.SEVERITY_WARNING
						}
				);

		configureTestCache
				(
						new SEL_ValidationRules.ValidationRuleWithGroup(errorRule, ruleGroup),
						new SEL_ValidationRules.ValidationRuleWithGroup(warningRule, ruleGroup)
				);

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses =
				executeValidation(TST_Factory.newFoobars(1), 'BEFORE_INSERT');
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should return one response');
		Assert.isTrue(responses[0].hasErrors, 'Should have errors');
		Assert.isTrue(responses[0].hasWarnings, 'Should have warnings');
		Assert.areEqual(1, responses[0].errors.size(), 'Should have one error');
		Assert.areEqual(1, responses[0].warnings.size(), 'Should have one warning');
	}

	/**
	 * @description Executes validation rules for the given records and trigger context.
	 *
	 * @param records The records to validate
	 * @param triggerContext The trigger context string
	 *
	 * @return The list of validation responses
	 */
	private static List<FLOW_ExecuteValidationRules.DTO_Response> executeValidation(List<SObject> records, String triggerContext)
	{
		return executeValidation(records, triggerContext, null);
	}

	/**
	 * @description Executes validation rules for the given records, trigger context, and old records.
	 *
	 * @param records The records to validate
	 * @param triggerContext The trigger context string
	 * @param oldRecords The old records for update contexts
	 *
	 * @return The list of validation responses
	 */
	private static List<FLOW_ExecuteValidationRules.DTO_Response> executeValidation
			(
					List<SObject> records,
					String triggerContext,
					List<SObject> oldRecords
			)
	{
		FLOW_ExecuteValidationRules.DTO_Request request = new FLOW_ExecuteValidationRules.DTO_Request();
		request.records = records;
		request.triggerContext = triggerContext;
		request.oldRecords = oldRecords;
		return FLOW_ExecuteValidationRules.execute(new List<FLOW_ExecuteValidationRules.DTO_Request> {request});
	}

	/**
	 * @description Configures the validation rule test cache with a single wrapper.
	 *
	 * @param wrapper The validation rule wrapper to register
	 */
	private static void configureTestCache(SEL_ValidationRules.ValidationRuleWithGroup wrapper)
	{
		configureTestCache(wrapper, null);
	}

	/**
	 * @description Configures the validation rule test cache with two wrappers.
	 *
	 * @param wrapper1 The first validation rule wrapper
	 * @param wrapper2 The second validation rule wrapper
	 */
	private static void configureTestCache
			(
					SEL_ValidationRules.ValidationRuleWithGroup wrapper1,
					SEL_ValidationRules.ValidationRuleWithGroup wrapper2
			)
	{
		List<SEL_ValidationRules.ValidationRuleWithGroup> wrappers = new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper1};
		if(wrapper2 != null)
		{
			wrappers.add(wrapper2);
		}

		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), wrappers);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;
	}
}