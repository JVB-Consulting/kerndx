// SPDX-License-Identifier: Apache-2.0
/**
 * @description Test class for FLOW_BypassValidation invocable action.
 * Verifies that each request switches off the kind of validation it names (an object, a rule group or a single rule),
 * by running one always-failing rule before and after the request and counting the errors it reports.
 *
 * @see FLOW_BypassValidation
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
private class FLOW_BypassValidation_TEST
{
	/**
	 * @description The object the validation rule checks. The object bypass tests switch off validation for this object.
	 */
	private static final String TEST_OBJECT_NAME = SEL_Foobar.OBJECT_NAME;
	/**
	 * @description The developer name of the rule group the tests build. The group bypass test switches off this group.
	 * It is different from the object name and the rule name, so a bypass of the wrong kind leaves the rule running.
	 */
	private static final String TEST_GROUP_NAME = 'TestValidationGroup';
	/**
	 * @description The developer name of the rule the tests build. The rule bypass test switches off this rule. It is
	 * different from the object name and the group name, so a bypass of the wrong kind leaves the rule running.
	 */
	private static final String TEST_RULE_NAME = 'TestValidationRule';
	/**
	 * @description A rule formula that is always true, so the rule reports an error for every record it checks.
	 */
	private static final String ALWAYS_FAILING_FORMULA = 'true';
	/**
	 * @description A bypass type written in lower case, to prove the action reads the type whatever its letter case.
	 */
	private static final String LOWER_CASE_OBJECT_BYPASS_TYPE = UTIL_ValidationRule.VALIDATION_BYPASS_TYPE.OBJECT_NAME.name().toLowerCase();
	/**
	 * @description A bypass type written in mixed case, to prove the action reads the type whatever the case of each letter.
	 */
	private static final String MIXED_CASE_GROUP_BYPASS_TYPE = 'Group_Name';
	/**
	 * @description A bypass type that is not one of the valid values.
	 */
	private static final String INVALID_BYPASS_TYPE = 'INVALID_TYPE';
	/**
	 * @description An empty bypass type, which the action treats as an object bypass.
	 */
	private static final String BLANK_BYPASS_TYPE = '';
	/**
	 * @description The number of errors the always-failing rule reports for the one record a run checks.
	 */
	private static final Integer ERRORS_WHEN_RULE_RUNS = 1;
	/**
	 * @description The number of errors a run reports when the rule has been switched off.
	 */
	private static final Integer ERRORS_WHEN_RULE_BYPASSED = 0;

	/**
	 * @description A request of type OBJECT_NAME switches off validation for that object. The rule stops reporting its
	 * error, so the bypass was set for the object and not for a group or rule of the same name.
	 */
	@IsTest
	private static void shouldBypassObjectByName()
	{
		assertBypassSwitchesOffRule(UTIL_ValidationRule.VALIDATION_BYPASS_TYPE.OBJECT_NAME.name(), TEST_OBJECT_NAME);
	}

	/**
	 * @description A request of type GROUP_NAME switches off every rule in that group. The rule in the group stops
	 * reporting its error, so the bypass was set for the group and not for an object or rule of the same name.
	 */
	@IsTest
	private static void shouldBypassGroupByName()
	{
		assertBypassSwitchesOffRule(UTIL_ValidationRule.VALIDATION_BYPASS_TYPE.GROUP_NAME.name(), TEST_GROUP_NAME);
	}

	/**
	 * @description A request of type RULE_NAME switches off that one rule. The rule stops reporting its error, so the
	 * bypass was set for the rule and not for an object or group of the same name.
	 */
	@IsTest
	private static void shouldBypassRuleByName()
	{
		assertBypassSwitchesOffRule(UTIL_ValidationRule.VALIDATION_BYPASS_TYPE.RULE_NAME.name(), TEST_RULE_NAME);
	}

	/**
	 * @description A request with no bypass type (null) is treated as an object bypass: naming the object switches off
	 * its validation.
	 */
	@IsTest
	private static void shouldDefaultToObjectNameWhenBypassTypeIsNull()
	{
		assertBypassSwitchesOffRule(null, TEST_OBJECT_NAME);
	}

	/**
	 * @description A request with an empty bypass type is treated as an object bypass: naming the object switches off
	 * its validation.
	 */
	@IsTest
	private static void shouldDefaultToObjectNameWhenBypassTypeIsBlank()
	{
		assertBypassSwitchesOffRule(BLANK_BYPASS_TYPE, TEST_OBJECT_NAME);
	}

	/**
	 * @description A request with an empty name is skipped before its bypass type is read: even a type that is not valid
	 * raises no error, and the rule still reports its error afterwards because nothing was switched off.
	 */
	@IsTest
	private static void shouldHandleBlankNameGracefully()
	{
		registerAlwaysFailingRule();

		FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
		request.bypassType = INVALID_BYPASS_TYPE;
		request.name = UTIL_String.EMPTY;

		Test.startTest();
		FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request> {request});
		Integer errorCount = countValidationErrors();
		Test.stopTest();

		Assert.areEqual(ERRORS_WHEN_RULE_RUNS, errorCount, 'Expected the rule to still report its error after a request with an empty name, got ' + errorCount);
	}

	/**
	 * @description A request with no name is skipped before its bypass type is read: even a type that is not valid
	 * raises no error, and the rule still reports its error afterwards because nothing was switched off.
	 */
	@IsTest
	private static void shouldHandleNullNameGracefully()
	{
		registerAlwaysFailingRule();

		FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
		request.bypassType = INVALID_BYPASS_TYPE;
		request.name = null;

		Test.startTest();
		FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request> {request});
		Integer errorCount = countValidationErrors();
		Test.stopTest();

		Assert.areEqual(ERRORS_WHEN_RULE_RUNS, errorCount, 'Expected the rule to still report its error after a nameless request, got ' + errorCount);
	}

	/**
	 * @description A bypass type written in lower case is read the same as upper case: naming the object with the type
	 * object_name switches off its validation.
	 */
	@IsTest
	private static void shouldHandleLowercaseBypassType()
	{
		assertBypassSwitchesOffRule(LOWER_CASE_OBJECT_BYPASS_TYPE, TEST_OBJECT_NAME);
	}

	/**
	 * @description A bypass type written in mixed case is read the same as upper case: naming the rule group with the type
	 * Group_Name switches off every rule in the group.
	 */
	@IsTest
	private static void shouldHandleMixedCaseBypassType()
	{
		assertBypassSwitchesOffRule(MIXED_CASE_GROUP_BYPASS_TYPE, TEST_GROUP_NAME);
	}

	/**
	 * @description A bypass type that is not valid makes the action throw a NoSuchElementException whose message lists
	 * the valid types, so a flow builder sees what to type instead.
	 */
	@IsTest
	private static void shouldThrowExceptionForInvalidBypassType()
	{
		FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
		request.bypassType = INVALID_BYPASS_TYPE;
		request.name = TEST_OBJECT_NAME;

		Test.startTest();
		try
		{
			FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request> {request});
			Assert.fail('Expected a NoSuchElementException for an invalid bypass type, got no exception');
		}
		catch(NoSuchElementException error)
		{
			Assert.areEqual(FLOW_BypassValidation.ERROR_INVALID_BYPASS_TYPE, error.getMessage(), 'Expected the list of valid bypass types, got ' + error.getMessage());
		}
		Test.stopTest();
	}

	/**
	 * @description Registers the always-failing rule, checks that it reports its error, sends one bypass request and
	 * checks that the rule no longer reports it. The rule is named TEST_RULE_NAME, sits in the group TEST_GROUP_NAME
	 * and checks TEST_OBJECT_NAME, so only a bypass of the kind the name belongs to switches it off.
	 *
	 * @param bypassType The bypass type the request carries
	 * @param name The name the request carries
	 */
	private static void assertBypassSwitchesOffRule(String bypassType, String name)
	{
		registerAlwaysFailingRule();

		FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
		request.bypassType = bypassType;
		request.name = name;

		Test.startTest();
		Integer errorCountBefore = countValidationErrors();
		FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request> {request});
		Integer errorCountAfter = countValidationErrors();
		Test.stopTest();

		Assert.areEqual(ERRORS_WHEN_RULE_RUNS, errorCountBefore, 'Expected the rule to report its error before the bypass, got ' + errorCountBefore);
		Assert.areEqual(ERRORS_WHEN_RULE_BYPASSED, errorCountAfter, 'Expected the bypass to switch the rule off, got ' + errorCountAfter + ' errors');
	}

	/**
	 * @description Makes the validation rule lookup return one always-failing rule, named TEST_RULE_NAME in the group
	 * TEST_GROUP_NAME, for TEST_OBJECT_NAME records before insert. No validation rule record in the org is read.
	 */
	private static void registerAlwaysFailingRule()
	{
		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(TEST_OBJECT_NAME);
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup
				(
						triggerSetting,
						new Map<SObjectField, Object>
						{
								ValidationRuleGroup__mdt.DeveloperName => TEST_GROUP_NAME,
								ValidationRuleGroup__mdt.ContextClassName__c => UTIL_FormulaContext.FoobarContext.class.getName()
						}
				);
		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.DeveloperName => TEST_RULE_NAME,
								ValidationRule__mdt.RuleFormula__c => ALWAYS_FAILING_FORMULA
						}
				);

		SEL_ValidationRules.testCacheOverride = new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>
		{
				TEST_OBJECT_NAME => new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>
				{
						TriggerOperation.BEFORE_INSERT.name() => new List<SEL_ValidationRules.ValidationRuleWithGroup>
						{
								new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup)
						}
				}
		};
	}

	/**
	 * @description Validates one new record of TEST_OBJECT_NAME before insert and counts the errors reported.
	 *
	 * @return The number of validation errors reported for the record
	 */
	private static Integer countValidationErrors()
	{
		Integer errorCount = 0;

		for(UTIL_ValidationRule.ValidationResult result : UTIL_ValidationRule.validate(TST_Factory.newFoobars(1), null, TriggerOperation.BEFORE_INSERT))
		{
			errorCount += result.errors.size();
		}

		return errorCount;
	}
}
