// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for FLOW_ExecuteValidationRules invocable action.
 * Verifies that the invocable correctly executes validation rules and returns results. Every test that reaches the
 * rule lookup registers its own rules through SEL_ValidationRules.testCacheOverride, so no validation rule record in
 * the org changes a result.
 *
 * @see FLOW_ExecuteValidationRules
 * @see UTIL_ValidationRule
 *
 * @author Jason van Beukering
 *
 * @group Validation
 *
 * @date January 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class FLOW_ExecuteValidationRules_TEST
{
	/**
	 * @description Name of the formula context class for Foobar records. Each rule group the tests build is given
	 * this name as its context class.
	 */
	private static final String FOOBAR_CONTEXT_CLASS = UTIL_FormulaContext.FoobarContext.class.getName();
	/**
	 * @description A rule formula that is always true, so the rule reports an error for every record it checks.
	 */
	private static final String ALWAYS_FAILING_FORMULA = 'true';
	/**
	 * @description A rule formula that is always false, so the rule checks every record and reports nothing.
	 */
	private static final String NEVER_FAILING_FORMULA = 'false';
	/**
	 * @description The developer name of the rule that never fails, used by the tests that expect a clean result.
	 */
	private static final String PASSING_RULE_NAME = 'Flow_Passing_Rule';
	/**
	 * @description The developer name of the rule a trigger context test registers for one trigger context only. It
	 * reports its error only when the action runs that exact context.
	 */
	private static final String CONTEXT_RULE_NAME = 'Flow_Context_Rule';
	/**
	 * @description The developer name of the blocking rule in the blocking error test.
	 */
	private static final String BLOCKING_RULE_NAME = 'Flow_Blocking_Rule';
	/**
	 * @description The message of the blocking rule in the blocking error test.
	 */
	private static final String BLOCKING_RULE_MESSAGE = 'Blocking error for flow';
	/**
	 * @description The developer name of the warning rule in the warning test.
	 */
	private static final String WARNING_RULE_NAME = 'Flow_Warning_Rule';
	/**
	 * @description The message of the warning rule in the warning test.
	 */
	private static final String WARNING_RULE_MESSAGE = 'Warning for flow';
	/**
	 * @description The message of the shadow mode rule in the shadow mode test.
	 */
	private static final String SHADOW_RULE_MESSAGE = 'Shadow mode error';
	/**
	 * @description The message of the Error rule in the test that mixes an error and a warning.
	 */
	private static final String MIXED_ERROR_MESSAGE = 'Error message';
	/**
	 * @description The message of the Warning rule in the test that mixes an error and a warning.
	 */
	private static final String MIXED_WARNING_MESSAGE = 'Warning message';
	/**
	 * @description A trigger context text that is not a trigger operation.
	 */
	private static final String INVALID_TRIGGER_CONTEXT = 'INVALID_CONTEXT';
	/**
	 * @description An empty trigger context text, which the action treats as before insert.
	 */
	private static final String BLANK_TRIGGER_CONTEXT = '';
	/**
	 * @description The summary error message of a response that has no blocking error: an empty text.
	 */
	private static final String EMPTY_ERROR_MESSAGE = '';
	/**
	 * @description The before insert trigger context written as the text a flow passes in.
	 */
	private static final String BEFORE_INSERT_CONTEXT = TriggerOperation.BEFORE_INSERT.name();
	/**
	 * @description The before update trigger context written with mixed capitals, as a flow builder might type it.
	 */
	private static final String MIXED_CASE_BEFORE_UPDATE_CONTEXT = 'Before_Update';
	/**
	 * @description The number of records the multiple records test validates in one request.
	 */
	private static final Integer MULTIPLE_RECORD_COUNT = 3;
	/**
	 * @description The number of responses the action returns for one request: always one, whatever the request holds.
	 */
	private static final Integer ONE_RESPONSE = 1;
	/**
	 * @description The number of requests the bulk test sends in one call, and so the number of responses it expects.
	 */
	private static final Integer TWO_REQUESTS = 2;
	/**
	 * @description The number of errors or warnings one rule reports for the one record a test validates.
	 */
	private static final Integer ONE_FINDING = 1;
	/**
	 * @description The position of the first record in a request, which an error carries as its record index.
	 */
	private static final Integer FIRST_RECORD_POSITION = 0;

	/**
	 * @description A record that breaks no rule gets one response that reports no errors and no warnings. A rule that
	 * never fails is registered, so the record is checked and passes. The two lists are still present, so a caller
	 * can read them without first checking for null.
	 */
	@IsTest
	private static void shouldReturnResponseWithNoErrorsForValidRecords()
	{
		registerRules(TriggerOperation.BEFORE_INSERT, new List<SEL_ValidationRules.ValidationRuleWithGroup> {newPassingRule()});

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = executeValidation(TST_Factory.newFoobars(1), BEFORE_INSERT_CONTEXT);
		Test.stopTest();

		Assert.areEqual(ONE_RESPONSE, responses.size(), 'Expected one response, got ' + responses.size());
		Assert.isFalse(responses[0].hasErrors, 'Expected no errors for a valid record, got errors');
		Assert.isFalse(responses[0].hasWarnings, 'Expected no warnings for a valid record, got warnings');
		Assert.isNotNull(responses[0].errors, 'Expected an errors list, got null');
		Assert.isNotNull(responses[0].warnings, 'Expected a warnings list, got null');
		Assert.isTrue(responses[0].errors.isEmpty(), 'Expected an empty errors list for a valid record, got ' + responses[0].errors.size());
		Assert.isTrue(responses[0].warnings.isEmpty(), 'Expected an empty warnings list for a valid record, got ' + responses[0].warnings.size());
		Assert.areEqual(EMPTY_ERROR_MESSAGE, responses[0].errorMessage, 'Expected an empty error message, got ' + responses[0].errorMessage);
	}

	/**
	 * @description A request with no record list at all still gets one response, with no errors, no warnings and
	 * an empty error message. The action does not fail when a flow passes nothing in.
	 */
	@IsTest
	private static void shouldReturnEmptyResponseForNullRecords()
	{
		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = executeValidation(null, BEFORE_INSERT_CONTEXT);
		Test.stopTest();

		Assert.areEqual(ONE_RESPONSE, responses.size(), 'Expected one response, got ' + responses.size());
		Assert.isFalse(responses[0].hasErrors, 'Expected no errors for null records, got errors');
		Assert.isFalse(responses[0].hasWarnings, 'Expected no warnings for null records, got warnings');
		Assert.areEqual(EMPTY_ERROR_MESSAGE, responses[0].errorMessage, 'Expected an empty error message, got ' + responses[0].errorMessage);
	}

	/**
	 * @description A request whose record list is empty still gets one response, and that response reports no
	 * errors. There is nothing to validate, and that is not treated as a failure.
	 */
	@IsTest
	private static void shouldReturnEmptyResponseForEmptyRecordsList()
	{
		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = executeValidation(new List<SObject>(), BEFORE_INSERT_CONTEXT);
		Test.stopTest();

		Assert.areEqual(ONE_RESPONSE, responses.size(), 'Expected one response, got ' + responses.size());
		Assert.isFalse(responses[0].hasErrors, 'Expected no errors for an empty list, got errors');
	}

	/**
	 * @description A request with an empty trigger context text runs the before insert rules: a rule registered only
	 * for before insert reports its error.
	 */
	@IsTest
	private static void shouldDefaultToBeforeInsertWhenTriggerContextIsBlank()
	{
		assertContextRunsRulesOf(BLANK_TRIGGER_CONTEXT, TriggerOperation.BEFORE_INSERT);
	}

	/**
	 * @description A request with no trigger context (null) runs the before insert rules: a rule registered only for
	 * before insert reports its error.
	 */
	@IsTest
	private static void shouldDefaultToBeforeInsertWhenTriggerContextIsNull()
	{
		assertContextRunsRulesOf(null, TriggerOperation.BEFORE_INSERT);
	}

	/**
	 * @description The text BEFORE_INSERT runs the before insert rules: a rule registered only for that context
	 * reports its error.
	 */
	@IsTest
	private static void shouldParseBeforeInsertTriggerContext()
	{
		assertContextRunsRulesOf(TriggerOperation.BEFORE_INSERT.name(), TriggerOperation.BEFORE_INSERT);
	}

	/**
	 * @description The text BEFORE_UPDATE runs the before update rules: a rule registered only for that context
	 * reports its error.
	 */
	@IsTest
	private static void shouldParseBeforeUpdateTriggerContext()
	{
		assertContextRunsRulesOf(TriggerOperation.BEFORE_UPDATE.name(), TriggerOperation.BEFORE_UPDATE);
	}

	/**
	 * @description The text AFTER_INSERT runs the after insert rules: a rule registered only for that context reports
	 * its error.
	 */
	@IsTest
	private static void shouldParseAfterInsertTriggerContext()
	{
		assertContextRunsRulesOf(TriggerOperation.AFTER_INSERT.name(), TriggerOperation.AFTER_INSERT);
	}

	/**
	 * @description The text AFTER_UPDATE runs the after update rules: a rule registered only for that context reports
	 * its error.
	 */
	@IsTest
	private static void shouldParseAfterUpdateTriggerContext()
	{
		assertContextRunsRulesOf(TriggerOperation.AFTER_UPDATE.name(), TriggerOperation.AFTER_UPDATE);
	}

	/**
	 * @description The text BEFORE_DELETE runs the before delete rules: a rule registered only for that context
	 * reports its error.
	 */
	@IsTest
	private static void shouldParseBeforeDeleteTriggerContext()
	{
		assertContextRunsRulesOf(TriggerOperation.BEFORE_DELETE.name(), TriggerOperation.BEFORE_DELETE);
	}

	/**
	 * @description The text AFTER_DELETE runs the after delete rules: a rule registered only for that context reports
	 * its error.
	 */
	@IsTest
	private static void shouldParseAfterDeleteTriggerContext()
	{
		assertContextRunsRulesOf(TriggerOperation.AFTER_DELETE.name(), TriggerOperation.AFTER_DELETE);
	}

	/**
	 * @description The text AFTER_UNDELETE runs the after undelete rules: a rule registered only for that context
	 * reports its error.
	 */
	@IsTest
	private static void shouldParseAfterUndeleteTriggerContext()
	{
		assertContextRunsRulesOf(TriggerOperation.AFTER_UNDELETE.name(), TriggerOperation.AFTER_UNDELETE);
	}

	/**
	 * @description A trigger context text that is not a real trigger operation makes the action throw, and the
	 * exception message names the bad value. A misspelt context in a flow is therefore reported, not silently
	 * replaced by a default.
	 */
	@IsTest
	private static void shouldThrowExceptionForInvalidTriggerContext()
	{
		Test.startTest();
		try
		{
			executeValidation(TST_Factory.newFoobars(1), INVALID_TRIGGER_CONTEXT);
			Assert.fail('Expected a NoSuchElementException for an invalid trigger context, got no exception');
		}
		catch(System.NoSuchElementException error)
		{
			Assert.isTrue(error.getMessage().contains(INVALID_TRIGGER_CONTEXT), 'Expected the message to name the invalid value, got ' + error.getMessage());
		}
		Test.stopTest();
	}

	/**
	 * @description One request that carries three records gets one response for the whole request, not one per
	 * record. A rule that always fails reports one error per record, and each error carries the position of its
	 * record in the request, so a flow can tell which record failed.
	 */
	@IsTest
	private static void shouldHandleMultipleRecordsInSingleRequest()
	{
		registerRules(TriggerOperation.BEFORE_INSERT, new List<SEL_ValidationRules.ValidationRuleWithGroup> {newContextRule()});

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = executeValidation(TST_Factory.newFoobars(MULTIPLE_RECORD_COUNT), BEFORE_INSERT_CONTEXT);
		Test.stopTest();

		Assert.areEqual(ONE_RESPONSE, responses.size(), 'Expected one response for the request, got ' + responses.size());
		Assert.areEqual(MULTIPLE_RECORD_COUNT, responses[0].errors.size(), 'Expected one error per record, got ' + responses[0].errors.size());

		for(Integer recordIndex = 0; recordIndex < MULTIPLE_RECORD_COUNT; recordIndex++)
		{
			Integer reportedIndex = responses[0].errors[recordIndex].recordIndex;
			Assert.areEqual(recordIndex, reportedIndex, 'Expected the error to carry record position ' + recordIndex + ', got ' + reportedIndex);
		}
	}

	/**
	 * @description Two requests passed in one call get two responses, one for each request and in the same order.
	 * Only the first request's context has a failing rule, so only the first response reports an error. This is the
	 * shape a flow relies on when it runs the action for several interviews at once.
	 */
	@IsTest
	private static void shouldHandleMultipleRequestsInBulk()
	{
		registerRules(TriggerOperation.BEFORE_INSERT, new List<SEL_ValidationRules.ValidationRuleWithGroup> {newContextRule()});

		List<SObject> updatedRecords = TST_Factory.newFoobars(1);

		FLOW_ExecuteValidationRules.DTO_Request failingRequest = new FLOW_ExecuteValidationRules.DTO_Request();
		failingRequest.records = TST_Factory.newFoobars(1);
		failingRequest.triggerContext = BEFORE_INSERT_CONTEXT;

		FLOW_ExecuteValidationRules.DTO_Request passingRequest = new FLOW_ExecuteValidationRules.DTO_Request();
		passingRequest.records = updatedRecords;
		passingRequest.oldRecords = updatedRecords;
		passingRequest.triggerContext = TriggerOperation.BEFORE_UPDATE.name();

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses =
				FLOW_ExecuteValidationRules.execute(new List<FLOW_ExecuteValidationRules.DTO_Request> {failingRequest, passingRequest});
		Test.stopTest();

		Assert.areEqual(TWO_REQUESTS, responses.size(), 'Expected one response per request, got ' + responses.size());
		Assert.isTrue(responses[0].hasErrors, 'Expected the first response to report the before insert error, got none');
		Assert.isFalse(responses[1].hasErrors, 'Expected the second response to report no error, got errors');
	}

	/**
	 * @description A trigger context written in lower case (before_insert) runs the before insert rules: a rule
	 * registered only for before insert reports its error. The letter case a flow builder types does not matter.
	 */
	@IsTest
	private static void shouldHandleLowercaseTriggerContext()
	{
		assertContextRunsRulesOf(TriggerOperation.BEFORE_INSERT.name().toLowerCase(), TriggerOperation.BEFORE_INSERT);
	}

	/**
	 * @description A trigger context written in mixed case (Before_Update) runs the before update rules: a rule
	 * registered only for before update reports its error. A flow builder may type the context with any capitals.
	 */
	@IsTest
	private static void shouldHandleMixedCaseTriggerContext()
	{
		assertContextRunsRulesOf(MIXED_CASE_BEFORE_UPDATE_CONTEXT, TriggerOperation.BEFORE_UPDATE);
	}

	/**
	 * @description A rule that always fails and has the default severity comes back as a blocking error. The error
	 * carries the rule name, the message, the field the message belongs to, the Error severity and the record's
	 * position, it is not marked as shadow mode, and the summary error message contains the rule's text. The flow
	 * gets everything it needs to show the error to the user.
	 */
	@IsTest
	private static void shouldReturnBlockingErrors()
	{
		LOG_Builder.ignoreTestMode = true;

		registerRules
				(
						TriggerOperation.BEFORE_INSERT,
						new List<SEL_ValidationRules.ValidationRuleWithGroup>
						{
								newRule
										(
												new Map<SObjectField, Object>
												{
														ValidationRule__mdt.DeveloperName => BLOCKING_RULE_NAME,
														ValidationRule__mdt.RuleFormula__c => ALWAYS_FAILING_FORMULA,
														ValidationRule__mdt.ErrorMessage__c => BLOCKING_RULE_MESSAGE,
														ValidationRule__mdt.ErrorDisplayField__c => SEL_Foobar.FIELD_INTEGER
												}
										)
						}
				);

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = executeValidation(TST_Factory.newFoobars(1), BEFORE_INSERT_CONTEXT);
		Test.stopTest();

		Assert.areEqual(ONE_RESPONSE, responses.size(), 'Expected one response, got ' + responses.size());
		Assert.isTrue(responses[0].hasErrors, 'Expected a blocking error, got none');
		Assert.isFalse(responses[0].hasWarnings, 'Expected no warnings, got warnings');
		Assert.areEqual(ONE_FINDING, responses[0].errors.size(), 'Expected one error, got ' + responses[0].errors.size());

		DTO_FlowValidationError error = responses[0].errors[0];

		Assert.areEqual(BLOCKING_RULE_NAME, error.ruleName, 'Expected the blocking rule name, got ' + error.ruleName);
		Assert.areEqual(BLOCKING_RULE_MESSAGE, error.message, 'Expected the blocking rule message, got ' + error.message);
		Assert.areEqual(SEL_Foobar.FIELD_INTEGER, error.fieldName, 'Expected the display field, got ' + error.fieldName);
		Assert.areEqual(UTIL_ValidationRule.SEVERITY_ERROR, error.severity, 'Expected Error severity, got ' + error.severity);
		Assert.areEqual(FIRST_RECORD_POSITION, error.recordIndex, 'Expected the first record position, got ' + error.recordIndex);
		Assert.isFalse(error.isShadowMode, 'Expected the error not to be in shadow mode, got shadow mode');
		Assert.isTrue(responses[0].errorMessage.contains(BLOCKING_RULE_MESSAGE), 'Expected the summary to contain the rule message, got ' + responses[0].errorMessage);
	}

	/**
	 * @description A failing rule with the Warning severity is returned in the warnings list and not as a blocking
	 * error, and the summary error message stays empty. A flow can show the warning and still let the user
	 * continue.
	 */
	@IsTest
	private static void shouldReturnWarnings()
	{
		LOG_Builder.ignoreTestMode = true;

		registerRules
				(
						TriggerOperation.BEFORE_INSERT,
						new List<SEL_ValidationRules.ValidationRuleWithGroup>
						{
								newRule
										(
												new Map<SObjectField, Object>
												{
														ValidationRule__mdt.DeveloperName => WARNING_RULE_NAME,
														ValidationRule__mdt.RuleFormula__c => ALWAYS_FAILING_FORMULA,
														ValidationRule__mdt.ErrorMessage__c => WARNING_RULE_MESSAGE,
														ValidationRule__mdt.Severity__c => UTIL_ValidationRule.SEVERITY_WARNING
												}
										)
						}
				);

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = executeValidation(TST_Factory.newFoobars(1), BEFORE_INSERT_CONTEXT);
		Test.stopTest();

		Assert.areEqual(ONE_RESPONSE, responses.size(), 'Expected one response, got ' + responses.size());
		Assert.isFalse(responses[0].hasErrors, 'Expected no blocking errors, got errors');
		Assert.isTrue(responses[0].hasWarnings, 'Expected a warning, got none');
		Assert.areEqual(ONE_FINDING, responses[0].warnings.size(), 'Expected one warning, got ' + responses[0].warnings.size());
		Assert.areEqual(WARNING_RULE_NAME, responses[0].warnings[0].ruleName, 'Expected the warning rule name, got ' + responses[0].warnings[0].ruleName);
		Assert.areEqual(UTIL_ValidationRule.SEVERITY_WARNING, responses[0].warnings[0].severity, 'Expected Warning severity, got ' + responses[0].warnings[0].severity);
		Assert.areEqual(EMPTY_ERROR_MESSAGE, responses[0].errorMessage, 'Expected an empty error message for warnings only, got ' + responses[0].errorMessage);
	}

	/**
	 * @description A failing rule in shadow mode (the rule is watched but does not block yet) is returned in the
	 * warnings list, not as a blocking error. The entry is marked as shadow mode and keeps its Error severity, so
	 * the caller can tell it apart from a real warning.
	 */
	@IsTest
	private static void shouldReturnShadowModeErrorsAsWarnings()
	{
		LOG_Builder.ignoreTestMode = true;

		registerRules
				(
						TriggerOperation.BEFORE_INSERT,
						new List<SEL_ValidationRules.ValidationRuleWithGroup>
						{
								newRule
										(
												new Map<SObjectField, Object>
												{
														ValidationRule__mdt.RuleFormula__c => ALWAYS_FAILING_FORMULA,
														ValidationRule__mdt.ErrorMessage__c => SHADOW_RULE_MESSAGE,
														ValidationRule__mdt.ShadowMode__c => true
												}
										)
						}
				);

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = executeValidation(TST_Factory.newFoobars(1), BEFORE_INSERT_CONTEXT);
		Test.stopTest();

		Assert.areEqual(ONE_RESPONSE, responses.size(), 'Expected one response, got ' + responses.size());
		Assert.isFalse(responses[0].hasErrors, 'Expected shadow mode errors not to block, got errors');
		Assert.isTrue(responses[0].hasWarnings, 'Expected shadow mode errors as warnings, got none');
		Assert.areEqual(ONE_FINDING, responses[0].warnings.size(), 'Expected one warning, got ' + responses[0].warnings.size());
		Assert.isTrue(responses[0].warnings[0].isShadowMode, 'Expected the warning to be marked as shadow mode, got not marked');
		Assert.areEqual(UTIL_ValidationRule.SEVERITY_ERROR, responses[0].warnings[0].severity, 'Expected Error severity, got ' + responses[0].warnings[0].severity);
	}

	/**
	 * @description When one record fails an Error rule and a Warning rule in the same run, the response reports
	 * both: one entry in the errors list and one in the warnings list. Neither kind hides the other.
	 */
	@IsTest
	private static void shouldReturnBothErrorsAndWarnings()
	{
		LOG_Builder.ignoreTestMode = true;

		registerRules
				(
						TriggerOperation.BEFORE_INSERT,
						new List<SEL_ValidationRules.ValidationRuleWithGroup>
						{
								newRule
										(
												new Map<SObjectField, Object>
												{
														ValidationRule__mdt.RuleFormula__c => ALWAYS_FAILING_FORMULA,
														ValidationRule__mdt.ErrorMessage__c => MIXED_ERROR_MESSAGE
												}
										),
								newRule
										(
												new Map<SObjectField, Object>
												{
														ValidationRule__mdt.RuleFormula__c => ALWAYS_FAILING_FORMULA,
														ValidationRule__mdt.ErrorMessage__c => MIXED_WARNING_MESSAGE,
														ValidationRule__mdt.Severity__c => UTIL_ValidationRule.SEVERITY_WARNING
												}
										)
						}
				);

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = executeValidation(TST_Factory.newFoobars(1), BEFORE_INSERT_CONTEXT);
		Test.stopTest();

		Assert.areEqual(ONE_RESPONSE, responses.size(), 'Expected one response, got ' + responses.size());
		Assert.isTrue(responses[0].hasErrors, 'Expected an error, got none');
		Assert.isTrue(responses[0].hasWarnings, 'Expected a warning, got none');
		Assert.areEqual(ONE_FINDING, responses[0].errors.size(), 'Expected one error, got ' + responses[0].errors.size());
		Assert.areEqual(ONE_FINDING, responses[0].warnings.size(), 'Expected one warning, got ' + responses[0].warnings.size());
	}

	/**
	 * @description Registers an always-failing rule for one trigger context only, runs the action with the given
	 * context text and checks that exactly that rule reported its error. The rule exists for no other context, so the
	 * error appears only when the text resolves to the expected context. Update contexts also carry old records.
	 *
	 * @param contextText The trigger context text the request carries
	 * @param expectedOperation The trigger context the text must resolve to
	 */
	private static void assertContextRunsRulesOf(String contextText, TriggerOperation expectedOperation)
	{
		registerRules(expectedOperation, new List<SEL_ValidationRules.ValidationRuleWithGroup> {newContextRule()});

		List<SObject> records = TST_Factory.newFoobars(1);
		Boolean isUpdate = expectedOperation == TriggerOperation.BEFORE_UPDATE || expectedOperation == TriggerOperation.AFTER_UPDATE;

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = executeValidation(records, contextText, isUpdate ? records : null);
		Test.stopTest();

		Assert.areEqual(ONE_RESPONSE, responses.size(), 'Expected one response, got ' + responses.size());
		Assert.areEqual(ONE_FINDING, responses[0].errors.size(), 'Expected the ' + expectedOperation.name() + ' rule to report one error, got ' + responses[0].errors.size());
		Assert.areEqual(CONTEXT_RULE_NAME, responses[0].errors[0].ruleName, 'Expected the context rule to report the error, got ' + responses[0].errors[0].ruleName);
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
	 * @description Builds the always-failing rule that a trigger context test registers for one context only.
	 *
	 * @return The rule with its group
	 */
	private static SEL_ValidationRules.ValidationRuleWithGroup newContextRule()
	{
		return newRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.DeveloperName => CONTEXT_RULE_NAME,
								ValidationRule__mdt.RuleFormula__c => ALWAYS_FAILING_FORMULA
						}
				);
	}

	/**
	 * @description Builds a rule that checks every record and never reports an error.
	 *
	 * @return The rule with its group
	 */
	private static SEL_ValidationRules.ValidationRuleWithGroup newPassingRule()
	{
		return newRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.DeveloperName => PASSING_RULE_NAME,
								ValidationRule__mdt.RuleFormula__c => NEVER_FAILING_FORMULA
						}
				);
	}

	/**
	 * @description Builds a Foobar validation rule with the given field values, in a rule group that uses the Foobar
	 * formula context.
	 *
	 * @param ruleFields The rule's field values
	 *
	 * @return The rule with its group
	 */
	private static SEL_ValidationRules.ValidationRuleWithGroup newRule(Map<SObjectField, Object> ruleFields)
	{
		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);
		return new SEL_ValidationRules.ValidationRuleWithGroup(TST_Factory.newValidationRule(ruleFields), ruleGroup);
	}

	/**
	 * @description Makes the validation rule lookup return the given rules for Foobar records in one trigger context,
	 * and no rules for any other context. No validation rule record in the org is read.
	 *
	 * @param operation The trigger context the rules run in
	 * @param wrappers The rules with their groups
	 */
	private static void registerRules(TriggerOperation operation, List<SEL_ValidationRules.ValidationRuleWithGroup> wrappers)
	{
		SEL_ValidationRules.testCacheOverride = new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>
		{
				SEL_Foobar.OBJECT_NAME => new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> {operation.name() => wrappers}
		};
	}
}
