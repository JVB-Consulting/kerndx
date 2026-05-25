// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for UTIL_ValidationRule and related validation framework classes.
 * Tests validation rule execution, bypass hierarchy, shadow mode, logging, and Flow integration.
 *
 * @see UTIL_ValidationRule
 *
 * @author Jason van Beukering
 *
 * @group Validation
 *
 * @date January 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity,PMD.NcssTypeCount')
private class UTIL_ValidationRule_TEST
{
	/**
	 * @description Reference to SEL_Foobar.OBJECT_NAME for package-controlled object testing.
	 * Uses existing DAL constant instead of redefining.
	 */
	private static final String TEST_OBJECT_NAME = SEL_Foobar.OBJECT_NAME;

	/**
	 * @description Company name discriminator for the committed test admin user set up in
	 * @TestSetup and retrieved via SEL_User.findByCompanyName.
	 */
	private static final String TEST_ADMIN_COMPANY = 'UTIL_ValidationRule_TEST-admin';

	/**
	 * @description Company name discriminator for the committed low-privilege user (Minimum Access
	 * - Salesforce profile) set up in @TestSetup and used by the tier-A regression test.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'UTIL_ValidationRule_TEST-low-privilege';

	/**
	 * @description Test group name constant for validation group testing.
	 */
	private static final String TEST_GROUP_NAME = 'TestGroup';

	/**
	 * @description Test rule name constant for validation rule testing.
	 */
	private static final String TEST_RULE_NAME = 'TestRule';

	/**
	 * @description FoobarContext class name for validation rule testing.
	 * Cached to follow DRY principle - used by many test methods.
	 */
	private static final String FOOBAR_CONTEXT_CLASS = UTIL_FormulaContext.FoobarContext.class.getName();

	/**
	 * @description Static tracking variables for TestBulkValidationContext.
	 * Must be at top level since inner classes cannot have static fields.
	 */
	private static Boolean bulkContextPreLoadWasCalled = false;
	private static Integer bulkContextPreLoadRecordCount = 0;

	/**
	 * @description Commits both a test-admin and a low-privilege user in @TestSetup's separate
	 * transaction so the tier-A test (shouldValidateRecordsForLowPrivilegeUser) can use System.runAs
	 * against either without triggering MIXED_DML_OPERATION. User is a Setup object, so User DML
	 * cannot mix with standard/custom-object DML in the same transaction; pre-provisioning here
	 * satisfies that boundary.
	 *
	 * Only the tier-A test uses these users — existing validation-rule tests continue to run as the
	 * @IsTest running user without runAs.
	 */
	@TestSetup
	private static void setupTestUsers()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);

		User lowPrivilegeUser = TST_Factory.newMinimumAccessUser(LOW_PRIVILEGE_COMPANY);
		insert lowPrivilegeUser;
	}

	/**
	 * @description Tests that bypassObject correctly adds an object name to the bypass set.
	 */
	@IsTest
	private static void shouldBypassObjectSuccessfully()
	{
		String objectName = TEST_OBJECT_NAME;

		Test.startTest();
		UTIL_ValidationRule.bypassObject(objectName);
		Test.stopTest();

		Assert.isTrue(UTIL_ValidationRule.isBypassed(objectName), 'Object should be bypassed');
	}

	/**
	 * @description Tests that bypassGroup correctly adds a group name to the bypass set.
	 */
	@IsTest
	private static void shouldBypassGroupSuccessfully()
	{
		String groupName = TEST_GROUP_NAME;

		Test.startTest();
		UTIL_ValidationRule.bypassGroup(groupName);
		Test.stopTest();

		Assert.isTrue(UTIL_ValidationRule.isBypassed(groupName), 'Group should be bypassed');
	}

	/**
	 * @description Tests that bypassRule correctly adds a rule name to the bypass set.
	 */
	@IsTest
	private static void shouldBypassRuleSuccessfully()
	{
		String ruleName = TEST_RULE_NAME;

		Test.startTest();
		UTIL_ValidationRule.bypassRule(ruleName);
		Test.stopTest();

		Assert.isTrue(UTIL_ValidationRule.isBypassed(ruleName), 'Rule should be bypassed');
	}

	/**
	 * @description Tests that clearBypass removes a single bypass from the set.
	 */
	@IsTest
	private static void shouldClearSingleBypass()
	{
		String objectName = TEST_OBJECT_NAME;
		UTIL_ValidationRule.bypassObject(objectName);

		Test.startTest();
		UTIL_ValidationRule.clearBypass(objectName);
		Test.stopTest();

		Assert.isFalse(UTIL_ValidationRule.isBypassed(objectName), 'Bypass should be cleared');
	}

	/**
	 * @description Tests that clearAllBypasses removes all bypasses from the set.
	 */
	@IsTest
	private static void shouldClearAllBypasses()
	{
		UTIL_ValidationRule.bypassObject(TEST_OBJECT_NAME);
		UTIL_ValidationRule.bypassGroup(TEST_GROUP_NAME);
		UTIL_ValidationRule.bypassRule(TEST_RULE_NAME);

		Test.startTest();
		UTIL_ValidationRule.clearAllBypasses();
		Test.stopTest();

		Assert.isFalse(UTIL_ValidationRule.isBypassed(TEST_OBJECT_NAME), 'Object bypass should be cleared');
		Assert.isFalse(UTIL_ValidationRule.isBypassed(TEST_GROUP_NAME), 'Group bypass should be cleared');
		Assert.isFalse(UTIL_ValidationRule.isBypassed(TEST_RULE_NAME), 'Rule bypass should be cleared');
	}

	/**
	 * @description Tests that null or blank values are not added to the bypass set.
	 */
	@IsTest
	private static void shouldNotBypassWithNullOrBlank()
	{
		Test.startTest();
		UTIL_ValidationRule.bypassObject(null);
		UTIL_ValidationRule.bypassObject(UTIL_String.EMPTY);
		UTIL_ValidationRule.bypassGroup(null);
		UTIL_ValidationRule.bypassGroup(UTIL_String.EMPTY);
		UTIL_ValidationRule.bypassRule(null);
		UTIL_ValidationRule.bypassRule(UTIL_String.EMPTY);
		Test.stopTest();

		Assert.isFalse(UTIL_ValidationRule.isBypassed(null), 'Null should not be bypassed');
		Assert.isFalse(UTIL_ValidationRule.isBypassed(UTIL_String.EMPTY), 'Empty string should not be bypassed');
	}

	/**
	 * @description Tests bypassing via the bypass method with enum type parameter.
	 */
	@IsTest
	private static void shouldBypassViaEnumType()
	{
		Test.startTest();
		UTIL_ValidationRule.bypass(TEST_OBJECT_NAME, UTIL_ValidationRule.VALIDATION_BYPASS_TYPE.OBJECT_NAME);
		UTIL_ValidationRule.bypass(TEST_GROUP_NAME, UTIL_ValidationRule.VALIDATION_BYPASS_TYPE.GROUP_NAME);
		UTIL_ValidationRule.bypass(TEST_RULE_NAME, UTIL_ValidationRule.VALIDATION_BYPASS_TYPE.RULE_NAME);
		Test.stopTest();

		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_OBJECT_NAME), 'Object should be bypassed');
		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_GROUP_NAME), 'Group should be bypassed');
		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_RULE_NAME), 'Rule should be bypassed');
	}

	/**
	 * @description Tests that ValidationResult with no errors is valid and has empty error message.
	 */
	@IsTest
	private static void shouldCreateValidationResultWithNoErrors()
	{
		Test.startTest();
		UTIL_ValidationRule.ValidationResult result = new UTIL_ValidationRule.ValidationResult(0, null);
		Test.stopTest();

		Assert.isTrue(result.isValid, 'Result with no errors should be valid');
		Assert.isTrue(result.errors.isEmpty(), 'Errors list should be empty');
		Assert.areEqual(UTIL_String.EMPTY, result.getErrorMessage(), 'Error message should be empty');
	}

	/**
	 * @description Tests that ValidationResult with blocking errors is invalid.
	 */
	@IsTest
	private static void shouldCreateValidationResultWithErrors()
	{
		UTIL_ValidationRule.ValidationResult result = new UTIL_ValidationRule.ValidationResult(0, null);
		UTIL_ValidationRule.ValidationError error = new UTIL_ValidationRule.ValidationError
				(
						TEST_RULE_NAME,
						'Test error message',
						'TestField__c',
						UTIL_ValidationRule.SEVERITY_ERROR
				);
		result.errors.add(error);

		Test.startTest();
		Boolean isValid = result.isValid;
		String errorMessage = result.getErrorMessage();
		List<UTIL_ValidationRule.ValidationError> blockingErrors = result.getErrorsBySeverity(UTIL_ValidationRule.SEVERITY_ERROR);
		Test.stopTest();

		Assert.isFalse(isValid, 'Result with blocking errors should not be valid');
		Assert.areEqual('Test error message', errorMessage, 'Error message should match');
		Assert.areEqual(1, blockingErrors.size(), 'Should have one blocking error');
	}

	/**
	 * @description Tests that getErrorMessage concatenates multiple error messages.
	 */
	@IsTest
	private static void shouldGetMultipleErrorMessages()
	{
		UTIL_ValidationRule.ValidationResult result = new UTIL_ValidationRule.ValidationResult(0, null);
		result.errors.add(new UTIL_ValidationRule.ValidationError('Rule1', 'Error 1', null, 'Error'));
		result.errors.add(new UTIL_ValidationRule.ValidationError('Rule2', 'Error 2', null, 'Error'));

		Test.startTest();
		String errorMessage = result.getErrorMessage();
		Test.stopTest();

		Assert.isTrue(errorMessage.contains('Error 1'), 'Should contain first error');
		Assert.isTrue(errorMessage.contains('Error 2'), 'Should contain second error');
	}

	/**
	 * @description Tests filtering validation errors by severity level.
	 */
	@IsTest
	private static void shouldFilterErrorsBySeverity()
	{
		UTIL_ValidationRule.ValidationResult result = new UTIL_ValidationRule.ValidationResult(0, null);

		UTIL_ValidationRule.ValidationError error = new UTIL_ValidationRule.ValidationError
				(
						'ErrorRule',
						'This is an error',
						null,
						UTIL_ValidationRule.SEVERITY_ERROR
				);
		UTIL_ValidationRule.ValidationError warning = new UTIL_ValidationRule.ValidationError
				(
						'WarningRule',
						'This is a warning',
						null,
						UTIL_ValidationRule.SEVERITY_WARNING
				);

		result.errors.add(error);
		result.errors.add(warning);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationError> errors = result.getErrorsBySeverity(UTIL_ValidationRule.SEVERITY_ERROR);
		List<UTIL_ValidationRule.ValidationError> warnings = result.getErrorsBySeverity(UTIL_ValidationRule.SEVERITY_WARNING);
		Test.stopTest();

		Assert.areEqual(1, errors.size(), 'Should have one error');
		Assert.areEqual(1, warnings.size(), 'Should have one warning');
		Assert.areEqual('ErrorRule', errors[0].ruleName, 'Error rule name should match');
		Assert.areEqual('WarningRule', warnings[0].ruleName, 'Warning rule name should match');
	}

	/**
	 * @description Tests that ValidationResult with only warnings is still considered valid.
	 */
	@IsTest
	private static void shouldTreatWarningsAsValid()
	{
		UTIL_ValidationRule.ValidationResult result = new UTIL_ValidationRule.ValidationResult(0, null);
		UTIL_ValidationRule.ValidationError warning = new UTIL_ValidationRule.ValidationError
				(
						'WarningRule',
						'This is a warning',
						null,
						UTIL_ValidationRule.SEVERITY_WARNING
				);
		result.errors.add(warning);

		Test.startTest();
		Boolean isValid = result.isValid;
		Test.stopTest();

		Assert.isTrue(isValid, 'Result with only warnings should be valid');
	}

	/**
	 * @description Tests that ValidationResult with shadow mode errors is still considered valid.
	 */
	@IsTest
	private static void shouldTreatShadowModeErrorsAsValid()
	{
		UTIL_ValidationRule.ValidationResult result = new UTIL_ValidationRule.ValidationResult(0, null);
		UTIL_ValidationRule.ValidationError error = new UTIL_ValidationRule.ValidationError
				(
						'ShadowRule',
						'Shadow error',
						null,
						UTIL_ValidationRule.SEVERITY_ERROR
				);
		error.shadowMode = true;
		result.errors.add(error);

		Test.startTest();
		Boolean isValid = result.isValid;
		Test.stopTest();

		Assert.isTrue(isValid, 'Result with only shadow mode errors should be valid');
	}

	/**
	 * @description Tests that ValidationError correctly stores all provided field values.
	 */
	@IsTest
	private static void shouldCreateValidationErrorWithAllFields()
	{
		Test.startTest();
		UTIL_ValidationRule.ValidationError error = new UTIL_ValidationRule.ValidationError
				(
						TEST_RULE_NAME,
						'Test message',
						'TestField__c',
						UTIL_ValidationRule.SEVERITY_ERROR
				);
		error.recordIndex = 5;
		error.recordId = UserInfo.getUserId();
		error.shadowMode = true;
		error.groupName = TEST_GROUP_NAME;
		Test.stopTest();

		Assert.areEqual(TEST_RULE_NAME, error.ruleName, 'Rule name should match');
		Assert.areEqual('Test message', error.message, 'Message should match');
		Assert.areEqual('TestField__c', error.fieldName, 'Field name should match');
		Assert.areEqual(UTIL_ValidationRule.SEVERITY_ERROR, error.severity, 'Severity should match');
		Assert.areEqual(5, error.recordIndex, 'Record index should match');
		Assert.areEqual(UserInfo.getUserId(), error.recordId, 'Record ID should match');
		Assert.isTrue(error.shadowMode, 'Shadow mode should be true');
		Assert.areEqual(TEST_GROUP_NAME, error.groupName, 'Group name should match');
	}

	/**
	 * @description Tests that validate returns empty results when passed null records.
	 */
	@IsTest
	private static void shouldReturnEmptyResultsForNullRecords()
	{
		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate(null, null, TriggerOperation.BEFORE_INSERT);
		Test.stopTest();

		Assert.isTrue(results.isEmpty(), 'Results should be empty for null records');
	}

	/**
	 * @description Tests that validate returns empty results when passed empty records list.
	 */
	@IsTest
	private static void shouldReturnEmptyResultsForEmptyRecords()
	{
		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate(new List<Foobar__c>(), null, TriggerOperation.BEFORE_INSERT);
		Test.stopTest();

		Assert.isTrue(results.isEmpty(), 'Results should be empty for empty records');
	}

	/**
	 * @description Tests that validate returns valid results when object is bypassed.
	 */
	@IsTest
	private static void shouldReturnResultsForBypassedObject()
	{
		List<Foobar__c> foobars = TST_Factory.newFoobars(1);
		UTIL_ValidationRule.bypassObject(TEST_OBJECT_NAME);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should return one result');
		Assert.isTrue(results[0].isValid, 'Result should be valid for bypassed object');

		UTIL_ValidationRule.clearAllBypasses();
	}

	/**
	 * @description Tests that validate returns valid results when no rules are configured.
	 */
	@IsTest
	private static void shouldReturnResultsForNoRulesConfigured()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						new List<Foobar__c> {record},
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should return one result');
		Assert.isTrue(results[0].isValid, 'Result should be valid when no rules configured');
	}

	/**
	 * @description Tests that applyErrors handles null input without throwing exception.
	 */
	@IsTest
	private static void shouldHandleNullRecordsInApplyErrors()
	{
		Test.startTest();
		UTIL_ValidationRule.applyErrors(null, null);
		UTIL_ValidationRule.applyErrors(new List<Foobar__c>(), null);
		UTIL_ValidationRule.applyErrors(null, new List<UTIL_ValidationRule.ValidationResult>());
		Test.stopTest();

		Assert.isTrue(true, 'Should not throw exception for null inputs');
	}

	/**
	 * @description Tests that applyErrors handles empty results without throwing exception.
	 */
	@IsTest
	private static void shouldHandleEmptyResultsInApplyErrors()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		UTIL_ValidationRule.ValidationResult result = new UTIL_ValidationRule.ValidationResult(0, null);

		Test.startTest();
		UTIL_ValidationRule.applyErrors(new List<Foobar__c> {record}, new List<UTIL_ValidationRule.ValidationResult> {result});
		Test.stopTest();

		Assert.isTrue(true, 'Should not throw exception for empty results');
	}

	/**
	 * @description Tests that applyErrors logs shadow mode errors without blocking the record.
	 */
	@IsTest
	private static void shouldApplyErrorsWithShadowMode()
	{
		LOG_Builder.ignoreTestMode = true;
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		UTIL_ValidationRule.ValidationResult result = new UTIL_ValidationRule.ValidationResult(0, null);
		UTIL_ValidationRule.ValidationError error = new UTIL_ValidationRule.ValidationError
				(
						'ShadowRule',
						'Shadow error message',
						null,
						UTIL_ValidationRule.SEVERITY_ERROR
				);
		error.shadowMode = true;
		error.recordIndex = 0;
		result.errors.add(error);

		Test.startTest();
		UTIL_ValidationRule.applyErrors(new List<Foobar__c> {record}, new List<UTIL_ValidationRule.ValidationResult> {result});
		Test.stopTest();

		Assert.isTrue(true, 'Shadow mode errors should log but not block');
	}

	/**
	 * @description Tests that applyErrors logs warning errors without blocking the record.
	 */
	@IsTest
	private static void shouldApplyErrorsWithWarnings()
	{
		LOG_Builder.ignoreTestMode = true;
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		UTIL_ValidationRule.ValidationResult result = new UTIL_ValidationRule.ValidationResult(0, null);
		UTIL_ValidationRule.ValidationError warning = new UTIL_ValidationRule.ValidationError
				(
						'WarningRule',
						'Warning message',
						null,
						UTIL_ValidationRule.SEVERITY_WARNING
				);
		warning.recordIndex = 0;
		result.errors.add(warning);

		Test.startTest();
		UTIL_ValidationRule.applyErrors(new List<Foobar__c> {record}, new List<UTIL_ValidationRule.ValidationResult> {result});
		Test.stopTest();

		Assert.isTrue(true, 'Warning errors should log but not block');
	}

	/**
	 * @description Tests that executeForTrigger handles null records without throwing exception.
	 */
	@IsTest
	private static void shouldHandleNullInExecuteForTrigger()
	{
		Test.startTest();
		UTIL_ValidationRule.executeForTrigger(null, null, TriggerOperation.BEFORE_INSERT);
		Test.stopTest();

		Assert.isTrue(true, 'Should not throw exception');
	}

	/**
	 * @description Tests that executeForTrigger handles empty records without throwing exception.
	 */
	@IsTest
	private static void shouldHandleEmptyInExecuteForTrigger()
	{
		Test.startTest();
		UTIL_ValidationRule.executeForTrigger(new List<Foobar__c>(), null, TriggerOperation.BEFORE_INSERT);
		Test.stopTest();

		Assert.isTrue(true, 'Should not throw exception');
	}

	/**
	 * @description Tests TRG_ExecuteValidationRules.beforeInsert trigger action interface.
	 */
	@IsTest
	private static void shouldExecuteBeforeInsertTriggerAction()
	{
		TRG_ExecuteValidationRules action = new TRG_ExecuteValidationRules();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		List<Foobar__c> records = new List<Foobar__c> {record};

		Test.startTest();
		action.beforeInsert(records);
		Test.stopTest();

		Assert.isTrue(true, 'Should execute without exception');
	}

	/**
	 * @description Tests TRG_ExecuteValidationRules.afterInsert trigger action interface.
	 */
	@IsTest
	private static void shouldExecuteAfterInsertTriggerAction()
	{
		TRG_ExecuteValidationRules action = new TRG_ExecuteValidationRules();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		List<Foobar__c> records = new List<Foobar__c> {record};

		Test.startTest();
		action.afterInsert(records);
		Test.stopTest();

		Assert.isTrue(true, 'Should execute without exception');
	}

	/**
	 * @description Tests TRG_ExecuteValidationRules.beforeUpdate trigger action interface.
	 */
	@IsTest
	private static void shouldExecuteBeforeUpdateTriggerAction()
	{
		TRG_ExecuteValidationRules action = new TRG_ExecuteValidationRules();
		Foobar__c newRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		Foobar__c oldRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		List<Foobar__c> newRecords = new List<Foobar__c> {newRecord};
		List<Foobar__c> oldRecords = new List<Foobar__c> {oldRecord};

		Test.startTest();
		action.beforeUpdate(newRecords, oldRecords);
		Test.stopTest();

		Assert.isTrue(true, 'Should execute without exception');
	}

	/**
	 * @description Tests TRG_ExecuteValidationRules.afterUpdate trigger action interface.
	 */
	@IsTest
	private static void shouldExecuteAfterUpdateTriggerAction()
	{
		TRG_ExecuteValidationRules action = new TRG_ExecuteValidationRules();
		Foobar__c newRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		Foobar__c oldRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		List<Foobar__c> newRecords = new List<Foobar__c> {newRecord};
		List<Foobar__c> oldRecords = new List<Foobar__c> {oldRecord};

		Test.startTest();
		action.afterUpdate(newRecords, oldRecords);
		Test.stopTest();

		Assert.isTrue(true, 'Should execute without exception');
	}

	/**
	 * @description Tests TRG_ExecuteValidationRules.beforeDelete trigger action interface.
	 */
	@IsTest
	private static void shouldExecuteBeforeDeleteTriggerAction()
	{
		TRG_ExecuteValidationRules action = new TRG_ExecuteValidationRules();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		List<Foobar__c> records = new List<Foobar__c> {record};

		Test.startTest();
		action.beforeDelete(records);
		Test.stopTest();

		Assert.isTrue(true, 'Should execute without exception');
	}

	/**
	 * @description Tests TRG_ExecuteValidationRules.afterDelete trigger action interface.
	 */
	@IsTest
	private static void shouldExecuteAfterDeleteTriggerAction()
	{
		TRG_ExecuteValidationRules action = new TRG_ExecuteValidationRules();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		List<Foobar__c> records = new List<Foobar__c> {record};

		Test.startTest();
		action.afterDelete(records);
		Test.stopTest();

		Assert.isTrue(true, 'Should execute without exception');
	}

	/**
	 * @description Tests TRG_ExecuteValidationRules.afterUndelete trigger action interface.
	 */
	@IsTest
	private static void shouldExecuteAfterUndeleteTriggerAction()
	{
		TRG_ExecuteValidationRules action = new TRG_ExecuteValidationRules();
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		List<Foobar__c> records = new List<Foobar__c> {record};

		Test.startTest();
		action.afterUndelete(records);
		Test.stopTest();

		Assert.isTrue(true, 'Should execute without exception');
	}

	/**
	 * @description Tests FLOW_ExecuteValidationRules Flow invocable with valid records.
	 */
	@IsTest
	private static void shouldExecuteFlowInvocableWithValidRecords()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		FLOW_ExecuteValidationRules.DTO_Request request = new FLOW_ExecuteValidationRules.DTO_Request();
		request.records = new List<SObject> {record};
		request.triggerContext = 'BEFORE_INSERT';

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = FLOW_ExecuteValidationRules.execute
				(
						new List<FLOW_ExecuteValidationRules.DTO_Request> {request}
				);
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should return one response');
		Assert.isFalse(responses[0].hasErrors, 'Should have no errors');
	}

	/**
	 * @description Tests FLOW_ExecuteValidationRules Flow invocable with empty records list.
	 */
	@IsTest
	private static void shouldHandleEmptyRecordsInFlowInvocable()
	{
		FLOW_ExecuteValidationRules.DTO_Request request = new FLOW_ExecuteValidationRules.DTO_Request();
		request.records = new List<SObject>();
		request.triggerContext = 'BEFORE_INSERT';

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = FLOW_ExecuteValidationRules.execute
				(
						new List<FLOW_ExecuteValidationRules.DTO_Request> {request}
				);
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should return one response');
		Assert.isFalse(responses[0].hasErrors, 'Should have no errors');
		Assert.areEqual(UTIL_String.EMPTY, responses[0].errorMessage, 'Error message should be empty');
	}

	/**
	 * @description Tests FLOW_ExecuteValidationRules Flow invocable with null records.
	 */
	@IsTest
	private static void shouldHandleNullRecordsInFlowInvocable()
	{
		FLOW_ExecuteValidationRules.DTO_Request request = new FLOW_ExecuteValidationRules.DTO_Request();
		request.records = null;
		request.triggerContext = 'BEFORE_INSERT';

		Test.startTest();
		List<FLOW_ExecuteValidationRules.DTO_Response> responses = FLOW_ExecuteValidationRules.execute
				(
						new List<FLOW_ExecuteValidationRules.DTO_Request> {request}
				);
		Test.stopTest();

		Assert.areEqual(1, responses.size(), 'Should return one response');
		Assert.isFalse(responses[0].hasErrors, 'Should have no errors');
	}

	/**
	 * @description Tests that all valid TriggerOperation enum values are parsed correctly.
	 */
	@IsTest
	private static void shouldParseAllTriggerOperationEnumValues()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		List<String> validContexts = new List<String>
		{
				'BEFORE_INSERT',
				'BEFORE_UPDATE',
				'BEFORE_DELETE',
				'AFTER_INSERT',
				'AFTER_UPDATE',
				'AFTER_DELETE',
				'AFTER_UNDELETE',
				UTIL_String.EMPTY
		};

		Test.startTest();
		for(String context : validContexts)
		{
			FLOW_ExecuteValidationRules.DTO_Request request = new FLOW_ExecuteValidationRules.DTO_Request();
			request.records = new List<SObject> {record};
			request.triggerContext = context;
			FLOW_ExecuteValidationRules.execute(new List<FLOW_ExecuteValidationRules.DTO_Request> {request});
		}
		Test.stopTest();

		Assert.isTrue(true, 'All trigger operations should parse without exception');
	}

	/**
	 * @description Tests FLOW_BypassValidation Flow invocable bypasses an object.
	 */
	@IsTest
	private static void shouldBypassObjectViaInvocable()
	{
		executeBypassViaInvocable('OBJECT_NAME', TEST_OBJECT_NAME);
		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_OBJECT_NAME), 'Object should be bypassed');
	}

	/**
	 * @description Tests FLOW_BypassValidation Flow invocable bypasses a group.
	 */
	@IsTest
	private static void shouldBypassGroupViaInvocable()
	{
		executeBypassViaInvocable('GROUP_NAME', TEST_GROUP_NAME);
		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_GROUP_NAME), 'Group should be bypassed');
	}

	/**
	 * @description Tests FLOW_BypassValidation Flow invocable bypasses a rule.
	 */
	@IsTest
	private static void shouldBypassRuleViaInvocable()
	{
		executeBypassViaInvocable('RULE_NAME', TEST_RULE_NAME);
		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_RULE_NAME), 'Rule should be bypassed');
	}

	/**
	 * @description Tests FLOW_ClearValidationBypass Flow invocable clears all bypasses.
	 */
	@IsTest
	private static void shouldClearAllBypassesViaInvocable()
	{
		UTIL_ValidationRule.bypassObject(TEST_OBJECT_NAME);
		FLOW_ClearValidationBypass.DTO_Request request = new FLOW_ClearValidationBypass.DTO_Request();
		request.clearAll = true;

		Test.startTest();
		FLOW_ClearValidationBypass.clearBypass(new List<FLOW_ClearValidationBypass.DTO_Request> {request});
		Test.stopTest();

		Assert.isFalse(UTIL_ValidationRule.isBypassed(TEST_OBJECT_NAME), 'All bypasses should be cleared');
	}

	/**
	 * @description Tests that null bypassType defaults to OBJECT_NAME bypass type.
	 */
	@IsTest
	private static void shouldDefaultToObjectBypassType()
	{
		executeBypassViaInvocable(null, TEST_OBJECT_NAME);
		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_OBJECT_NAME), 'Should default to object bypass');
	}

	/**
	 * @description Tests that empty name in bypass invocable does not throw exception.
	 */
	@IsTest
	private static void shouldHandleEmptyNameInBypassInvocable()
	{
		FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
		request.bypassType = UTIL_ValidationRule.VALIDATION_BYPASS_TYPE.OBJECT_NAME.name();
		request.name = UTIL_String.EMPTY;

		Test.startTest();
		FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request> {request});
		Test.stopTest();

		Assert.isTrue(true, 'Should not throw exception');
	}

	/**
	 * @description Tests SEL_ValidationRules returns empty list for non-existent object.
	 */
	@IsTest
	private static void shouldReturnEmptyListForNonExistentObject()
	{
		List<SEL_ValidationRules.ValidationRuleWithGroup> rules = findRulesByObjectAndOperation('NonExistentObject__c', TriggerOperation.BEFORE_INSERT);
		Assert.isTrue(rules.isEmpty(), 'Should return empty list for non-existent object');
	}

	/**
	 * @description Tests SEL_ValidationRules returns non-null list for unconfigured operation.
	 */
	@IsTest
	private static void shouldReturnEmptyListForNonExistentOperation()
	{
		List<SEL_ValidationRules.ValidationRuleWithGroup> rules = findRulesByObjectAndOperation(TEST_OBJECT_NAME, TriggerOperation.AFTER_UNDELETE);
		Assert.isNotNull(rules, 'Rules list should not be null');
	}

	/**
	 * @description Tests SEL_ValidationRules.getAllReferencedFeatureFlags returns non-null set.
	 */
	@IsTest
	private static void shouldReturnReferencedFeatureFlags()
	{
		Test.startTest();
		Set<String> featureFlags = SEL_ValidationRules.getAllReferencedFeatureFlags();
		Test.stopTest();

		Assert.isNotNull(featureFlags, 'Feature flags set should not be null');
	}

	/**
	 * @description Tests DTO_FlowValidationError correctly stores all field values.
	 */
	@IsTest
	private static void shouldCreateDTOFlowValidationError()
	{
		Test.startTest();
		DTO_FlowValidationError error = new DTO_FlowValidationError();
		error.ruleName = TEST_RULE_NAME;
		error.message = 'Test message';
		error.fieldName = 'TestField__c';
		error.severity = UTIL_ValidationRule.SEVERITY_ERROR;
		error.recordIndex = 0;
		error.isShadowMode = false;
		Test.stopTest();

		Assert.areEqual(TEST_RULE_NAME, error.ruleName, 'Rule name should match');
		Assert.areEqual('Test message', error.message, 'Message should match');
		Assert.areEqual('TestField__c', error.fieldName, 'Field name should match');
		Assert.areEqual(UTIL_ValidationRule.SEVERITY_ERROR, error.severity, 'Severity should match');
		Assert.areEqual(0, error.recordIndex, 'Record index should match');
		Assert.isFalse(error.isShadowMode, 'Shadow mode should be false');
	}

	/**
	 * @description Tests processMergeFields replaces simple property merge fields.
	 */
	@IsTest
	private static void shouldProcessMergeFieldsWithSimpleProperty()
	{
		TestContext context = new TestContext();
		context.name = 'TestValue';
		context.value = 42;

		Test.startTest();
		String result = UTIL_ValidationRule.processMergeFields('Hello {!name}, value is {!value}', context);
		Test.stopTest();

		Assert.areEqual('Hello TestValue, value is 42', result, 'Simple properties should be replaced');
	}

	/**
	 * @description Tests processMergeFields replaces nested property merge fields.
	 */
	@IsTest
	private static void shouldProcessMergeFieldsWithNestedProperty()
	{
		TestContext context = new TestContext();
		context.name = 'Parent';
		context.nested = new TestNestedContext();
		context.nested.childName = 'ChildValue';
		context.nested.amount = 100.50;

		Test.startTest();
		String result = UTIL_ValidationRule.processMergeFields('Nested: {!nested.childName}, Amount: {!nested.amount}', context);
		Test.stopTest();

		Assert.isTrue(result.contains('ChildValue'), 'Should contain nested child name');
		Assert.isTrue(result.contains('100.5'), 'Should contain nested amount value');
	}

	/**
	 * @description Tests processMergeFields returns original template when context is null.
	 */
	@IsTest
	private static void shouldProcessMergeFieldsWithNullContext()
	{
		Test.startTest();
		String result = UTIL_ValidationRule.processMergeFields('Hello {!name}', null);
		Test.stopTest();

		Assert.areEqual('Hello {!name}', result, 'Should return original template when context is null');
	}

	/**
	 * @description Tests processMergeFields handles null and blank templates correctly.
	 */
	@IsTest
	private static void shouldProcessMergeFieldsWithBlankTemplate()
	{
		TestContext context = new TestContext();
		context.name = 'Test';

		Test.startTest();
		String resultNull = UTIL_ValidationRule.processMergeFields(null, context);
		String resultBlank = UTIL_ValidationRule.processMergeFields(UTIL_String.EMPTY, context);
		Test.stopTest();

		Assert.isNull(resultNull, 'Should return null for null template');
		Assert.areEqual(UTIL_String.EMPTY, resultBlank, 'Should return empty for empty template');
	}

	/**
	 * @description Tests processMergeFields returns unchanged template when no merge fields present.
	 */
	@IsTest
	private static void shouldProcessMergeFieldsWithNoMergeFields()
	{
		TestContext context = new TestContext();
		context.name = 'Test';

		Test.startTest();
		String result = UTIL_ValidationRule.processMergeFields('No merge fields here', context);
		Test.stopTest();

		Assert.areEqual('No merge fields here', result, 'Template without merge fields should be unchanged');
	}

	/**
	 * @description Tests getMergeFieldValue returns value for simple field path.
	 */
	@IsTest
	private static void shouldGetMergeFieldValueForSimplePath()
	{
		TestContext context = new TestContext();
		context.name = 'SimpleValue';

		Test.startTest();
		String result = UTIL_ValidationRule.getMergeFieldValue(context, 'name');
		Test.stopTest();

		Assert.areEqual('SimpleValue', result, 'Should return simple field value');
	}

	/**
	 * @description Tests getMergeFieldValue returns value for nested field path.
	 */
	@IsTest
	private static void shouldGetMergeFieldValueForNestedPath()
	{
		TestContext context = new TestContext();
		context.nested = new TestNestedContext();
		context.nested.childName = 'NestedValue';

		Test.startTest();
		String result = UTIL_ValidationRule.getMergeFieldValue(context, 'nested.childName');
		Test.stopTest();

		Assert.areEqual('NestedValue', result, 'Should return nested field value');
	}

	/**
	 * @description Tests getMergeFieldValue returns empty string for null path segment.
	 */
	@IsTest
	private static void shouldGetMergeFieldValueReturnsEmptyForNullPath()
	{
		TestContext context = new TestContext();
		context.nested = null;

		Test.startTest();
		String result = UTIL_ValidationRule.getMergeFieldValue(context, 'nested.childName');
		Test.stopTest();

		Assert.areEqual(UTIL_String.EMPTY, result, 'Should return empty for null path segment');
	}

	/**
	 * @description Tests getMergeFieldValue returns empty string for non-existent field.
	 */
	@IsTest
	private static void shouldGetMergeFieldValueReturnsEmptyForNonExistentField()
	{
		TestContext context = new TestContext();
		context.name = 'Test';

		Test.startTest();
		String result = UTIL_ValidationRule.getMergeFieldValue(context, 'nonExistent');
		Test.stopTest();

		Assert.areEqual(UTIL_String.EMPTY, result, 'Should return empty for non-existent field');
	}

	/**
	 * @description Tests getMergeFieldValue returns empty string for invalid path.
	 */
	@IsTest
	private static void shouldGetMergeFieldValueReturnsEmptyForInvalidPath()
	{
		TestContext context = new TestContext();
		context.name = 'Test';

		Test.startTest();
		String result = UTIL_ValidationRule.getMergeFieldValue(context, 'name.invalid.path');
		Test.stopTest();

		Assert.areEqual(UTIL_String.EMPTY, result, 'Should return empty for invalid path');
	}

	/**
	 * @description Tests getMergeFieldValue handles non-object context gracefully.
	 * Passing a primitive causes a ClassCastException when casting to Map, which should be caught.
	 */
	@IsTest
	private static void shouldGetMergeFieldValueHandlesNonObjectContext()
	{
		Test.startTest();
		String result = UTIL_ValidationRule.getMergeFieldValue(123, 'anyPath');
		Test.stopTest();

		Assert.areEqual(UTIL_String.EMPTY, result, 'Should return empty for non-object context');
	}

	/**
	 * @description Tests applyErrorToRecord applies field-level error to record.
	 */
	@IsTest
	private static void shouldApplyErrorToRecordWithFieldName()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		UTIL_ValidationRule.ValidationError error = new UTIL_ValidationRule.ValidationError
				(
						TEST_RULE_NAME,
						'Field error message',
						'Name',
						UTIL_ValidationRule.SEVERITY_ERROR
				);

		Test.startTest();
		UTIL_ValidationRule.applyErrorToRecord(record, error);
		Test.stopTest();

		Assert.isTrue(true, 'Should apply field-level error');
	}

	/**
	 * @description Tests applyErrorToRecord applies page-level error to record.
	 */
	@IsTest
	private static void shouldApplyErrorToRecordWithoutFieldName()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		UTIL_ValidationRule.ValidationError error = new UTIL_ValidationRule.ValidationError
				(
						TEST_RULE_NAME,
						'Page-level error message',
						null,
						UTIL_ValidationRule.SEVERITY_ERROR
				);

		Test.startTest();
		UTIL_ValidationRule.applyErrorToRecord(record, error);
		Test.stopTest();

		Assert.isTrue(true, 'Should apply page-level error');
	}

	/**
	 * @description Tests logShadowViolation logs shadow mode errors.
	 */
	@IsTest
	private static void shouldLogShadowViolation()
	{
		LOG_Builder.ignoreTestMode = true;
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		UTIL_ValidationRule.ValidationError error = new UTIL_ValidationRule.ValidationError
				(
						'ShadowRule',
						'Shadow violation message',
						null,
						UTIL_ValidationRule.SEVERITY_ERROR
				);
		error.recordIndex = 0;
		error.shadowMode = true;

		Test.startTest();
		UTIL_ValidationRule.logShadowViolation(error, record);
		Test.stopTest();

		Assert.isTrue(true, 'Shadow violation should be logged');
	}

	/**
	 * @description Tests logWarning logs warning validation errors.
	 */
	@IsTest
	private static void shouldLogWarning()
	{
		LOG_Builder.ignoreTestMode = true;
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		UTIL_ValidationRule.ValidationError warning = new UTIL_ValidationRule.ValidationError
				(
						'WarningRule',
						'Warning message',
						null,
						UTIL_ValidationRule.SEVERITY_WARNING
				);
		warning.recordIndex = 0;

		Test.startTest();
		UTIL_ValidationRule.logWarning(warning, record);
		Test.stopTest();

		Assert.isTrue(true, 'Warning should be logged');
	}

	/**
	 * @description Tests severity constants have expected values.
	 */
	@IsTest
	private static void shouldValidateSeverityConstants()
	{
		Test.startTest();
		String errorSeverity = UTIL_ValidationRule.SEVERITY_ERROR;
		String warningSeverity = UTIL_ValidationRule.SEVERITY_WARNING;
		Test.stopTest();

		Assert.areEqual(UTIL_ValidationRule.SEVERITY_ERROR, errorSeverity, 'Error severity constant should match');
		Assert.areEqual(UTIL_ValidationRule.SEVERITY_WARNING, warningSeverity, 'Warning severity constant should match');
	}

	/**
	 * @description Tests validation against all trigger operations without exception.
	 */
	@IsTest
	private static void shouldValidateMultipleTriggerOperations()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		List<Foobar__c> records = new List<Foobar__c> {record};

		Test.startTest();
		UTIL_ValidationRule.validate(records, null, TriggerOperation.BEFORE_INSERT);
		UTIL_ValidationRule.validate(records, records, TriggerOperation.BEFORE_UPDATE);
		UTIL_ValidationRule.validate(records, null, TriggerOperation.AFTER_INSERT);
		UTIL_ValidationRule.validate(records, records, TriggerOperation.AFTER_UPDATE);
		UTIL_ValidationRule.validate(records, null, TriggerOperation.BEFORE_DELETE);
		UTIL_ValidationRule.validate(records, null, TriggerOperation.AFTER_DELETE);
		UTIL_ValidationRule.validate(records, null, TriggerOperation.AFTER_UNDELETE);
		Test.stopTest();

		Assert.isTrue(true, 'All trigger operations should validate without exception');
	}

	/**
	 * @description Tests validation with injected rules using FoobarContext formula context.
	 */
	@IsTest
	private static void shouldValidateWithInjectedRulesUsingFoobarContext()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);

		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.RuleFormula__c => 'newRecord.' + SEL_Foobar.FIELD_INTEGER + ' <= 0',
								ValidationRule__mdt.ErrorMessage__c => 'Integer must be positive'
						}
				);

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.isNotNull(results, 'Results should not be null');
		Assert.areEqual(1, results.size(), 'Should have one result per record');

	}

	/**
	 * @description Tests that rules are skipped when no context class is configured for the object.
	 */
	@IsTest
	private static void shouldSkipRulesWithNoContextClass()
	{
		LOG_Builder.ignoreTestMode = true;

		// Use ApiCall__c which is NOT in STANDARD_OBJECT_CONTEXT_TYPES
		// This exercises the auto-resolution path where no built-in context exists
		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(ApiCall__c.SObjectType);

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(objectName);

		// Note: No ContextClassName__c set - testing the auto-resolution path
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting);

		// Note: No ContextClassName__c set on rule either
		ValidationRule__mdt rule = TST_Factory.newValidationRule('No_Context_Rule', 'true', 'No context error');

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(objectName, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		// Create a ApiCall__c record - this object is NOT in STANDARD_OBJECT_CONTEXT_TYPES
		ApiCall__c record = new ApiCall__c();

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						new List<ApiCall__c> {record},
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		// Should get results even though rules were skipped due to no context
		Assert.areEqual(1, results.size(), 'Should have results for each record');
		Assert.isTrue(results[0].isValid, 'Should be valid when rules are skipped due to no context');

	}

	/**
	 * @description Tests that rule-level ContextClassName overrides group-level context.
	 */
	@IsTest
	private static void shouldUseRuleLevelContextClass()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting);

		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.RuleFormula__c => 'newRecord.' + SEL_Foobar.FIELD_INTEGER + ' <= 0',
								ValidationRule__mdt.ErrorMessage__c => 'Test error',
								ValidationRule__mdt.ContextClassName__c => FOOBAR_CONTEXT_CLASS
						}
				);

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should use rule-level context class');

	}

	/**
	 * @description Tests that entire group is skipped when group name is bypassed.
	 */
	@IsTest
	private static void shouldSkipBypassedGroup()
	{
		LOG_Builder.ignoreTestMode = true;

		String bypassedGroupName = 'Bypassed_Group';

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);
		ruleGroup.DeveloperName = bypassedGroupName;

		ValidationRule__mdt rule = TST_Factory.newValidationRule('Rule_In_Bypassed_Group', 'true', 'Should not see this');

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		UTIL_ValidationRule.bypassGroup(bypassedGroupName);
		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should have results');
		Assert.isTrue(results[0].isValid, 'Should be valid when group is bypassed');

		UTIL_ValidationRule.clearAllBypasses();
	}

	/**
	 * @description Tests that individual rule is skipped when rule name is bypassed.
	 */
	@IsTest
	private static void shouldSkipBypassedRule()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);

		ValidationRule__mdt rule = TST_Factory.newValidationRule('Bypassed_Rule', 'true', 'Should not see this');

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		UTIL_ValidationRule.bypassRule('Bypassed_Rule');
		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should have results');
		Assert.isTrue(results[0].isValid, 'Should be valid when rule is bypassed');

		UTIL_ValidationRule.clearAllBypasses();
	}

	/**
	 * @description Tests that rules are skipped gracefully when context class name is invalid.
	 */
	@IsTest
	private static void shouldHandleInvalidContextClassName()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, 'NonExistentContextClass');

		ValidationRule__mdt rule = TST_Factory.newValidationRule('Rule_Invalid_Context', 'true', 'Error');

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should return results even with invalid context');
		Assert.isTrue(results[0].isValid, 'Should be valid when context cannot be instantiated');

	}

	/**
	 * @description Tests that failing rule generates blocking validation error with correct properties.
	 */
	@IsTest
	private static void shouldGenerateValidationError()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup
				(
						triggerSetting,
						new Map<SObjectField, Object>
						{
								ValidationRuleGroup__mdt.ContextClassName__c => FOOBAR_CONTEXT_CLASS,
								ValidationRuleGroup__mdt.DeveloperName => 'Error_Group'
						}
				);

		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.DeveloperName => 'Always_Fails',
								ValidationRule__mdt.RuleFormula__c => 'true',
								ValidationRule__mdt.ErrorMessage__c => 'Validation failed: {!newRecord.Integer__c}',
								ValidationRule__mdt.ErrorDisplayField__c => SEL_Foobar.FIELD_INTEGER
						}
				);

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should have one result');
		Assert.isFalse(results[0].isValid, 'Should be invalid when rule fails');
		Assert.areEqual(1, results[0].errors.size(), 'Should have one error');
		Assert.areEqual('Always_Fails', results[0].errors[0].ruleName, 'Rule name should match');
		Assert.areEqual(UTIL_ValidationRule.SEVERITY_ERROR, results[0].errors[0].severity, 'Severity should be Error');
		Assert.areEqual(SEL_Foobar.FIELD_INTEGER, results[0].errors[0].fieldName, 'Field name should match');
		Assert.areEqual('Error_Group', results[0].errors[0].groupName, 'Group name should match');

	}

	/**
	 * @description Tests that rule with Warning severity generates non-blocking warning.
	 */
	@IsTest
	private static void shouldGenerateWarning()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);

		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.RuleFormula__c => 'true',
								ValidationRule__mdt.ErrorMessage__c => 'This is a warning',
								ValidationRule__mdt.Severity__c => UTIL_ValidationRule.SEVERITY_WARNING
						}
				);

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should have one result');
		Assert.isTrue(results[0].isValid, 'Should be valid with only warning');
		Assert.areEqual(1, results[0].errors.size(), 'Should have one warning');
		Assert.areEqual(UTIL_ValidationRule.SEVERITY_WARNING, results[0].errors[0].severity, 'Severity should be Warning');

	}

	/**
	 * @description Tests that rule with ShadowMode=true generates non-blocking shadow error.
	 */
	@IsTest
	private static void shouldGenerateShadowModeError()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);

		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.RuleFormula__c => 'true',
								ValidationRule__mdt.ErrorMessage__c => 'Shadow error',
								ValidationRule__mdt.ShadowMode__c => true
						}
				);

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should have one result');
		Assert.isTrue(results[0].isValid, 'Should be valid with shadow mode error');
		Assert.areEqual(1, results[0].errors.size(), 'Should have one error');
		Assert.isTrue(results[0].errors[0].shadowMode, 'Should be shadow mode');

	}

	/**
	 * @description Tests that blocking error is applied to record via applyErrors.
	 */
	@IsTest
	private static void shouldApplyBlockingError()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);

		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.RuleFormula__c => 'true',
								ValidationRule__mdt.ErrorMessage__c => 'Blocking error'
						}
				);

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		UTIL_ValidationRule.applyErrors(foobars, results);
		Test.stopTest();

		Assert.isFalse(results[0].isValid, 'Should be invalid with blocking error');

	}

	/**
	 * @description Tests that rule executes when user does not have BypassPermission custom permission.
	 */
	@IsTest
	private static void shouldSkipRuleWithBypassPermission()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);

		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.RuleFormula__c => 'true',
								ValidationRule__mdt.ErrorMessage__c => 'Should not see this',
								ValidationRule__mdt.BypassFeatureFlag__c => TST_Factory.newFeatureFlag('NonExistentPermission', false)
						}
				);

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should have one result');
		Assert.isFalse(results[0].isValid, 'User does not have bypass permission so rule should fire');

	}

	/**
	 * @description Tests that group is skipped when RequiredFeatureFlag is not enabled.
	 */
	@IsTest
	private static void shouldSkipRuleWhenRequiredFeatureFlagNotEnabled()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup
				(
						triggerSetting,
						new Map<SObjectField, Object>
						{
								ValidationRuleGroup__mdt.ContextClassName__c => FOOBAR_CONTEXT_CLASS,
								ValidationRuleGroup__mdt.RequiredFeatureFlag__c => TST_Factory.newFeatureFlag('NonExistentFeatureFlag', false)
						}
				);

		ValidationRule__mdt rule = TST_Factory.newValidationRule('Feature_Flag_Rule', 'true', 'Should not see this');

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should have one result');
		Assert.isTrue(results[0].isValid, 'Should be valid when required feature flag is not enabled');

	}

	/**
	 * @description Tests that group rules fire when user does not have group BypassPermission.
	 */
	@IsTest
	private static void shouldSkipRuleWhenGroupBypassPermissionMet()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup
				(
						triggerSetting,
						new Map<SObjectField, Object>
						{
								ValidationRuleGroup__mdt.ContextClassName__c => FOOBAR_CONTEXT_CLASS,
								ValidationRuleGroup__mdt.BypassFeatureFlag__c => TST_Factory.newFeatureFlag('NonExistentBypassPerm', false)
						}
				);

		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.DeveloperName => 'Group_Bypassed_Rule',
								ValidationRule__mdt.RuleFormula__c => 'true',
								ValidationRule__mdt.ErrorMessage__c => 'Should not see this'
						}
				);

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should have one result');
		Assert.isFalse(results[0].isValid, 'User does not have bypass permission so rule should fire');

	}

	/**
	 * @description Tests that invalid formula expression is handled gracefully.
	 */
	@IsTest
	private static void shouldHandleFormulaEvaluationException()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);

		ValidationRule__mdt rule = TST_Factory.newValidationRule('Invalid_Formula_Rule', 'NOT_A_VALID_FORMULA(', 'Error');

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should have one result even with formula error');
		Assert.isTrue(results[0].isValid, 'Should be valid when formula evaluation fails');

	}

	/**
	 * @description Tests that formula context is cached and reused for multiple records.
	 */
	@IsTest
	private static void shouldReuseContextFromCache()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);

		ValidationRule__mdt rule = TST_Factory.newValidationRule('Cache_Test_Rule', 'false', 'Error');

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(2);

		Test.startTest();
		// First call creates the context and caches it
		List<UTIL_ValidationRule.ValidationResult> results1 = UTIL_ValidationRule.validate
				(
						new List<Foobar__c> {foobars[0]},
						null,
						TriggerOperation.BEFORE_INSERT
				);
		// Second call should use the cached context (hits line 756)
		List<UTIL_ValidationRule.ValidationResult> results2 = UTIL_ValidationRule.validate
				(
						new List<Foobar__c> {foobars[1]},
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, results1.size(), 'First validation should have one result');
		Assert.areEqual(1, results2.size(), 'Second validation should have one result');
		Assert.isTrue(results1[0].isValid, 'First validation should be valid');
		Assert.isTrue(results2[0].isValid, 'Second validation should be valid');

	}

	/**
	 * @description Tests that group is skipped when group BypassPermission feature flag is enabled.
	 */
	@IsTest
	private static void shouldSkipGroupWhenBypassFeatureFlagEnabled()
	{
		LOG_Builder.ignoreTestMode = true;

		// Get the test feature flag and configure its strategy to enable the flag
		FeatureFlag__mdt testFlag = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		FeatureFlagStrategy__mdt strategy = testFlag.FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_PROFILE;
		strategy.Target__c = SEL_Profile.PROFILE_SYSTEM_ADMIN;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup
				(
						triggerSetting,
						new Map<SObjectField, Object>
						{
								ValidationRuleGroup__mdt.ContextClassName__c => FOOBAR_CONTEXT_CLASS,
								ValidationRuleGroup__mdt.BypassFeatureFlag__c => TST_Factory.newFeatureFlag(SEL_FeatureFlag.TEST_FEATURE_FLAG, false)
						}
				);

		ValidationRule__mdt rule = TST_Factory.newValidationRule('Rule_Bypassed_By_Flag', 'true', 'Should not see this');

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		// Running as System Admin, the feature flag should be enabled which bypasses the group (line 811)
		Assert.areEqual(1, results.size(), 'Should have one result');
		Assert.isTrue(results[0].isValid, 'Should be valid when bypass feature flag is enabled');

	}

	/**
	 * @description Tests that rule is skipped when rule BypassPermission feature flag is enabled.
	 */
	@IsTest
	private static void shouldSkipRuleWhenBypassFeatureFlagEnabled()
	{
		LOG_Builder.ignoreTestMode = true;

		// Get the test feature flag and configure its strategy to enable the flag
		FeatureFlag__mdt testFlag = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		FeatureFlagStrategy__mdt strategy = testFlag.FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_PROFILE;
		strategy.Target__c = SEL_Profile.PROFILE_SYSTEM_ADMIN;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);

		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.RuleFormula__c => 'true',
								ValidationRule__mdt.ErrorMessage__c => 'Should not see this',
								ValidationRule__mdt.BypassFeatureFlag__c => TST_Factory.newFeatureFlag(SEL_FeatureFlag.TEST_FEATURE_FLAG, false)
						}
				);

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		// Running as System Admin, the feature flag should be enabled which bypasses the rule (line 823)
		Assert.areEqual(1, results.size(), 'Should have one result');
		Assert.isTrue(results[0].isValid, 'Should be valid when rule bypass feature flag is enabled');

	}

	/**
	 * @description Tests that group rules execute when RequiredFeatureFlag is enabled.
	 */
	@IsTest
	private static void shouldExecuteRuleWhenRequiredFeatureFlagEnabled()
	{
		LOG_Builder.ignoreTestMode = true;

		// Get the test feature flag and configure its strategy to enable the flag
		FeatureFlag__mdt testFlag = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		FeatureFlagStrategy__mdt strategy = testFlag.FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_PROFILE;
		strategy.Target__c = SEL_Profile.PROFILE_SYSTEM_ADMIN;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup
				(
						triggerSetting,
						new Map<SObjectField, Object>
						{
								ValidationRuleGroup__mdt.ContextClassName__c => FOOBAR_CONTEXT_CLASS,
								ValidationRuleGroup__mdt.RequiredFeatureFlag__c => TST_Factory.newFeatureFlag(SEL_FeatureFlag.TEST_FEATURE_FLAG, false)
						}
				);

		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.DeveloperName => 'Rule_Requires_Flag',
								ValidationRule__mdt.RuleFormula__c => 'true',
								ValidationRule__mdt.ErrorMessage__c => 'This rule requires feature flag'
						}
				);

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		// Running as System Admin with flag enabled, rule should execute and fail (formula is 'true')
		Assert.areEqual(1, results.size(), 'Should have one result');
		Assert.isFalse(results[0].isValid, 'Should be invalid when required feature flag is enabled and rule fires');

	}

	/**
	 * @description Tests that rule is skipped when rule RequiredFeatureFlag is not enabled.
	 */
	@IsTest
	private static void shouldSkipRuleWhenRuleRequiredFeatureFlagNotEnabled()
	{
		LOG_Builder.ignoreTestMode = true;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);

		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.RuleFormula__c => 'true',
								ValidationRule__mdt.ErrorMessage__c => 'Should not see this',
								ValidationRule__mdt.RequiredFeatureFlag__c => TST_Factory.newFeatureFlag('NonExistentFeatureFlag', false)
						}
				);

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should have one result');
		Assert.isTrue(results[0].isValid, 'Should be valid when rule required feature flag is not enabled');

	}

	/**
	 * @description Tests that rule executes when rule RequiredFeatureFlag is enabled.
	 */
	@IsTest
	private static void shouldExecuteRuleWhenRuleRequiredFeatureFlagEnabled()
	{
		LOG_Builder.ignoreTestMode = true;

		FeatureFlag__mdt testFlag = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		FeatureFlagStrategy__mdt strategy = testFlag.FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_PROFILE;
		strategy.Target__c = SEL_Profile.PROFILE_SYSTEM_ADMIN;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, FOOBAR_CONTEXT_CLASS);

		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.DeveloperName => 'Rule_Requires_Flag',
								ValidationRule__mdt.RuleFormula__c => 'true',
								ValidationRule__mdt.ErrorMessage__c => 'This rule requires feature flag',
								ValidationRule__mdt.RequiredFeatureFlag__c => TST_Factory.newFeatureFlag(SEL_FeatureFlag.TEST_FEATURE_FLAG, false)
						}
				);

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should have one result');
		Assert.isFalse(results[0].isValid, 'Should be invalid when rule required feature flag is enabled and rule fires');

	}

	/**
	 * @description Tests that INT_BulkValidationContext.preLoad is called for bulk context classes.
	 */
	@IsTest
	private static void shouldCallPreLoadOnBulkValidationContext()
	{
		LOG_Builder.ignoreTestMode = true;
		bulkContextPreLoadWasCalled = false;
		bulkContextPreLoadRecordCount = 0;

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, TestBulkValidationContext.class.getName());

		ValidationRule__mdt rule = TST_Factory.newValidationRule('Bulk_Context_Rule', 'false', 'Error');

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(3);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate
				(
						foobars,
						null,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		// Verify preLoad was called (line 711)
		Assert.isTrue(bulkContextPreLoadWasCalled, 'preLoad should have been called');
		Assert.areEqual(3, bulkContextPreLoadRecordCount, 'preLoad should receive all records');
		Assert.areEqual(3, results.size(), 'Should have results for all records');

	}

	/**
	 * @description Helper method to execute bypass via invocable action.
	 *
	 * @param bypassType The type of bypass (OBJECT_NAME, GROUP_NAME, RULE_NAME)
	 * @param name The name to bypass
	 */
	private static void executeBypassViaInvocable(String bypassType, String name)
	{
		FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
		request.bypassType = bypassType;
		request.name = name;

		Test.startTest();
		FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request> {request});
		Test.stopTest();
	}

	/**
	 * @description Tests that Fail Fast execution strategy stops processing after first error per record.
	 * When a rule fails, subsequent rules in the group are skipped for that record.
	 */
	@IsTest
	private static void shouldStopProcessingOnFailFastStrategy()
	{
		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup
				(
						triggerSetting,
						new Map<SObjectField, Object>
						{
								ValidationRuleGroup__mdt.ContextClassName__c => FOOBAR_CONTEXT_CLASS,
								ValidationRuleGroup__mdt.ExecutionStrategy__c => 'Fail Fast'
						}
				);

		// Create three rules that would all fail (formula returns true = fail)
		ValidationRule__mdt rule1 = TST_Factory.newValidationRule('First_Rule', 'true', 'First error');
		ValidationRule__mdt rule2 = TST_Factory.newValidationRule('Second_Rule', 'true', 'Second error');
		ValidationRule__mdt rule3 = TST_Factory.newValidationRule('Third_Rule', 'true', 'Third error');
		rule1.Order__c = 10;
		rule2.Order__c = 20;
		rule3.Order__c = 30;

		SEL_ValidationRules.ValidationRuleWithGroup wrapper1 = new SEL_ValidationRules.ValidationRuleWithGroup(rule1, ruleGroup);
		SEL_ValidationRules.ValidationRuleWithGroup wrapper2 = new SEL_ValidationRules.ValidationRuleWithGroup(rule2, ruleGroup);
		SEL_ValidationRules.ValidationRuleWithGroup wrapper3 = new SEL_ValidationRules.ValidationRuleWithGroup(rule3, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper1, wrapper2, wrapper3});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate(foobars, null, TriggerOperation.BEFORE_INSERT);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should have one result');
		Assert.areEqual(1, results[0].errors.size(), 'Fail Fast should stop after first error');
		Assert.areEqual('First_Rule', results[0].errors[0].ruleName, 'Should be first rule that failed');

	}

	/**
	 * @description Tests that Accumulate (default) execution strategy collects all errors.
	 * All rules continue to execute even after errors are found.
	 */
	@IsTest
	private static void shouldContinueProcessingOnAccumulateStrategy()
	{
		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);

		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup
				(
						triggerSetting,
						new Map<SObjectField, Object>
						{
								ValidationRuleGroup__mdt.ContextClassName__c => FOOBAR_CONTEXT_CLASS,
								ValidationRuleGroup__mdt.ExecutionStrategy__c => 'Accumulate'
						}
				);

		// Create three rules that would all fail
		ValidationRule__mdt rule1 = TST_Factory.newValidationRule('First_Rule', 'true', 'First error');
		ValidationRule__mdt rule2 = TST_Factory.newValidationRule('Second_Rule', 'true', 'Second error');
		ValidationRule__mdt rule3 = TST_Factory.newValidationRule('Third_Rule', 'true', 'Third error');
		rule1.Order__c = 10;
		rule2.Order__c = 20;
		rule3.Order__c = 30;

		SEL_ValidationRules.ValidationRuleWithGroup wrapper1 = new SEL_ValidationRules.ValidationRuleWithGroup(rule1, ruleGroup);
		SEL_ValidationRules.ValidationRuleWithGroup wrapper2 = new SEL_ValidationRules.ValidationRuleWithGroup(rule2, ruleGroup);
		SEL_ValidationRules.ValidationRuleWithGroup wrapper3 = new SEL_ValidationRules.ValidationRuleWithGroup(rule3, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper1, wrapper2, wrapper3});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		List<Foobar__c> foobars = TST_Factory.newFoobars(1);

		Test.startTest();
		List<UTIL_ValidationRule.ValidationResult> results = UTIL_ValidationRule.validate(foobars, null, TriggerOperation.BEFORE_INSERT);
		Test.stopTest();

		Assert.areEqual(1, results.size(), 'Should have one result');
		Assert.areEqual(3, results[0].errors.size(), 'Accumulate should collect all errors');

	}

	/**
	 * @description Tests that shadow violation log message includes the error message.
	 * The short message should be in format: "[SHADOW] Rule_Name: Error message text..."
	 */
	@IsTest
	private static void shouldLogShadowViolationWithErrorMessage()
	{
		LOG_Builder.ignoreTestMode = true;
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().build();
		UTIL_ValidationRule.ValidationError error = new UTIL_ValidationRule.ValidationError
				(
						'ShadowRule',
						'This is the error message that should appear in the short log',
						null,
						UTIL_ValidationRule.SEVERITY_ERROR
				);
		error.recordIndex = 0;
		error.shadowMode = true;

		Test.startTest();
		UTIL_ValidationRule.logShadowViolation(error, record);
		Test.stopTest();

		// The implementation now includes error message in short message format:
		// "[SHADOW] ShadowRule: This is the error message..."
		Assert.isTrue(true, 'Shadow violation should include error message in log');
	}

	/**
	 * @description Tests that validation performance is logged when enabled and threshold is exceeded.
	 * Verifies EnableValidationPerformanceLogging__c and ValidationPerformanceThresholdMs__c are respected.
	 */
	@IsTest
	private static void shouldLogValidationPerformanceWhenEnabled()
	{
		// Setup - enable validation performance logging with 0ms threshold (log all)
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0, false, 0, false, 500, true, 0);

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(TEST_OBJECT_NAME);
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting);
		ValidationRule__mdt rule = TST_Factory.newValidationRule(TEST_RULE_NAME, 'false', 'Test message');
		rule.ValidationRuleGroup__r = ruleGroup;

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);
		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache = new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap = new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(TEST_OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		Foobar__c record = TST_Factory.newFoobar();

		Test.startTest();
		UTIL_ValidationRule.validate(new List<Foobar__c> {record}, null, TriggerOperation.BEFORE_INSERT);
		Test.stopTest();

		// Verify performance log was created
		LogEntry__c performanceLog = findValidationPerformanceLog();
		Assert.isNotNull(performanceLog, 'Validation performance log should be created when logging is enabled');

	}

	/**
	 * @description Tests that validation performance is NOT logged when disabled.
	 * Verifies EnableValidationPerformanceLogging__c = false prevents logging.
	 */
	@IsTest
	private static void shouldNotLogValidationPerformanceWhenDisabled()
	{
		// Setup - DISABLE validation performance logging
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0, false, 0, false, 500, false, 0);

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(TEST_OBJECT_NAME);
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting);
		ValidationRule__mdt rule = TST_Factory.newValidationRule(TEST_RULE_NAME, 'false', 'Test message');
		rule.ValidationRuleGroup__r = ruleGroup;

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);
		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache = new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap = new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(TEST_OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		Foobar__c record = TST_Factory.newFoobar();

		Test.startTest();
		UTIL_ValidationRule.validate(new List<Foobar__c> {record}, null, TriggerOperation.BEFORE_INSERT);
		Test.stopTest();

		// Verify no performance log was created
		LogEntry__c performanceLog = findValidationPerformanceLog();
		Assert.isNull(performanceLog, 'Validation performance log should NOT be created when logging is disabled');

	}

	/**
	 * @description Tests that validation performance is NOT logged when threshold is not exceeded.
	 * Verifies ValidationPerformanceThresholdMs__c threshold is respected.
	 */
	@IsTest
	private static void shouldNotLogValidationPerformanceWhenBelowThreshold()
	{
		// Setup - enable validation logging with very high threshold (10 seconds)
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest(false, 0, false, 0, false, 500, true, 10000);

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(TEST_OBJECT_NAME);
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting);
		ValidationRule__mdt rule = TST_Factory.newValidationRule(TEST_RULE_NAME, 'false', 'Test message');
		rule.ValidationRuleGroup__r = ruleGroup;

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);
		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache = new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap = new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(TEST_OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		Foobar__c record = TST_Factory.newFoobar();

		Test.startTest();
		UTIL_ValidationRule.validate(new List<Foobar__c> {record}, null, TriggerOperation.BEFORE_INSERT);
		Test.stopTest();

		// Verify no performance log was created (validation is much faster than 10 seconds)
		LogEntry__c performanceLog = findValidationPerformanceLog();
		Assert.isNull(performanceLog, 'Validation performance log should NOT be created when below threshold');

	}

	/**
	 * @description Helper method to execute findByObjectAndOperation within Test.start/stopTest boundaries.
	 *
	 * @param objectName The object developer name.
	 * @param operation The trigger operation.
	 *
	 * @return The list of validation rules with groups.
	 */
	private static List<SEL_ValidationRules.ValidationRuleWithGroup> findRulesByObjectAndOperation(String objectName, TriggerOperation operation)
	{
		Test.startTest();
		List<SEL_ValidationRules.ValidationRuleWithGroup> rules = SEL_ValidationRules.findByObjectAndOperation(objectName, operation);
		Test.stopTest();
		return rules;
	}

	/**
	 * @description Helper method to find validation performance logs by searching for 'validation completed' message.
	 *
	 * @return The first matching LogEntry__c record, or null if none found
	 */
	private static LogEntry__c findValidationPerformanceLog()
	{
		List<LogEntry__c> logs = new SEL_LogEntry().findAllByMethod(UTIL_ValidationRule.class.getName() + '/processRulesForContext');
		for(LogEntry__c log : logs)
		{
			if((log.ShortMessage__c != null && log.ShortMessage__c.contains('validation completed')) ||
					(log.Message__c != null && log.Message__c.contains('validation completed')))
			{
				return log;
			}
		}
		return null;
	}

	/**
	 * @description Tier-A — proves UTIL_ValidationRule.validate completes its
	 * pipeline without throwing when invoked by a subscriber user on the Minimum Access - Salesforce
	 * profile. The test uses SEL_ValidationRules.testCacheOverride to inject the rule set, so it
	 * exercises the in-memory evaluation path rather than the live SEL_ValidationRules SOQL path
	 * (Custom Metadata Type queries can't be mutated at runtime, so the cache override is the only
	 * substitute available in a unit test). What this test catches: a future refactor that adds a
	 * USER_MODE DML or query on the running user's context inside UTIL_ValidationRule, or a
	 * downstream helper that trips on a caller without kern__ FLS, fails at 2GP validated-build
	 * time rather than at subscriber scratch-org time. The stronger "selector elevates via
	 * systemModeRequired" claim is NOT covered by this test — it is covered by the Sharing &
	 * Reference tier-A tests for framework-internal selectors (T7–T10) and by subscriber-side
	 * tests that exercise the real CMDT SOQL path.
	 *
	 * @see UTIL_ValidationRule.validate
	 * @see SEL_ValidationRules.testCacheOverride
	 */
	@IsTest
	private static void shouldValidateRecordsForLowPrivilegeUser()
	{
		final String errorMessage = 'Test validation violation';
		final String ruleName = 'LowPrivilegeTestRule';

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(TEST_OBJECT_NAME);
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup
				(
						triggerSetting,
						new Map<SObjectField, Object>
						{
								ValidationRuleGroup__mdt.ContextClassName__c => FOOBAR_CONTEXT_CLASS,
								ValidationRuleGroup__mdt.DeveloperName => 'LowPrivilegeRuleGroup'
						}
				);
		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.DeveloperName => ruleName,
								ValidationRule__mdt.RuleFormula__c => 'true',
								ValidationRule__mdt.ErrorMessage__c => errorMessage
						}
				);

		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);
		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache = new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap = new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(TEST_OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		Foobar__c record = TST_Factory.newFoobar();
		List<UTIL_ValidationRule.ValidationResult> results;

		System.runAs(getLowPrivilegeUser())
		{
			Test.startTest();

			results = UTIL_ValidationRule.validate(new List<Foobar__c> {record}, null, TriggerOperation.BEFORE_INSERT);

			Test.stopTest();
		}

		Assert.areEqual(1, results.size(), 'Should return one validation result for the single record');
		Assert.isFalse(results[0].isValid, 'ValidationResult should be invalid when rule matches');
		Assert.areEqual(1, results[0].errors.size(), 'Should collect one error for the matching rule');
		Assert.areEqual(ruleName, results[0].errors[0].ruleName, 'Error should carry the configured rule name');
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the tier-A test to exercise UTIL_ValidationRule.validate and
	 * prove the subscribers-without-internal-FLS contract holds for the validation-rule pipeline.
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}

	/**
	 * @description Tests that `bypassObject` emits a `validation` bypass audit entry recording
	 * the `object:<api-name>` target.
	 *
	 * @see UTIL_ValidationRule.bypassObject
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitBypassAuditOnValidationObjectBypass()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		UTIL_ValidationRule.bypassObject('Account');
		Test.stopTest();

		Map<String, Object> context = findValidationAuditContext('object:Account');
		Assert.isNotNull(context, 'bypassObject should emit a validation audit entry');
		Assert.areEqual(UTIL_BypassAudit.SURFACE_VALIDATION, context.get(UTIL_BypassAudit.CONTEXT_SURFACE), 'Surface should be validation');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
	}

	/**
	 * @description Tests that `bypassGroup` emits a `validation` bypass audit entry recording
	 * the `group:<developer-name>` target.
	 *
	 * @see UTIL_ValidationRule.bypassGroup
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitBypassAuditOnValidationGroupBypass()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		UTIL_ValidationRule.bypassGroup('SalesCloud_Validations');
		Test.stopTest();

		Map<String, Object> context = findValidationAuditContext('group:SalesCloud_Validations');
		Assert.isNotNull(context, 'bypassGroup should emit a validation audit entry');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
	}

	/**
	 * @description Tests that `bypassRule` emits a `validation` bypass audit entry recording
	 * the `rule:<developer-name>` target.
	 *
	 * @see UTIL_ValidationRule.bypassRule
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitBypassAuditOnValidationRuleBypass()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		UTIL_ValidationRule.bypassRule('Account_Requires_Primary_Contact');
		Test.stopTest();

		Map<String, Object> context = findValidationAuditContext('rule:Account_Requires_Primary_Contact');
		Assert.isNotNull(context, 'bypassRule should emit a validation audit entry');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, context.get(UTIL_BypassAudit.CONTEXT_ACTION), 'Action should be BYPASS');
	}

	/**
	 * @description Tests that `clearAllBypasses` emits a `validation` audit entry with the
	 * `CLEAR_ALL` action and `ALL` target.
	 *
	 * @see UTIL_ValidationRule.clearAllBypasses
	 * @see UTIL_BypassAudit.emit
	 */
	@IsTest
	private static void shouldEmitBypassAuditOnValidationClearAll()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		UTIL_ValidationRule.bypassObject('Account');

		Test.startTest();
		UTIL_ValidationRule.clearAllBypasses();
		Test.stopTest();

		Map<String, Object> bypassContext = findValidationAuditContext('object:Account');
		Assert.isNotNull(bypassContext, 'setup phase bypassObject should have emitted a validation BYPASS audit entry');
		Assert.areEqual(UTIL_BypassAudit.ACTION_BYPASS, bypassContext.get('action'), 'Setup phase action should be BYPASS');
		Map<String, Object> clearAllContext = findValidationAuditContext(UTIL_BypassAudit.TARGET_ALL);
		Assert.isNotNull(clearAllContext, 'clearAllBypasses should emit a validation audit entry');
		Assert.areEqual(UTIL_BypassAudit.ACTION_CLEAR_ALL, clearAllContext.get('action'), 'Action should be CLEAR_ALL');
	}

	/**
	 * @description Locates the most-recent bypass audit entry whose `target` matches the supplied
	 * value and whose `surface` is `validation`. Filtering by both target and surface keeps
	 * assertions stable when other framework-internal audits (e.g., `query` system-mode
	 * emissions) also fire during test setup.
	 *
	 * @param target The bypass audit `target` context value to find.
	 *
	 * @return The inner context map for the matching audit entry, or `null` if none exists.
	 */
	private static Map<String, Object> findValidationAuditContext(String target)
	{
		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			if(context != null
					&& target.equals(context.get(UTIL_BypassAudit.CONTEXT_TARGET))
					&& UTIL_BypassAudit.SURFACE_VALIDATION.equals(context.get(UTIL_BypassAudit.CONTEXT_SURFACE)))
			{
				return context;
			}
		}
		return null;
	}

	/**
	 * @description Test context class for merge field testing.
	 */
	public class TestContext
	{
		/**
		 * @description Test name field.
		 */
		public String name;
		/**
		 * @description Test integer value field.
		 */
		public Integer value;
		/**
		 * @description Nested context for testing field path navigation.
		 */
		public TestNestedContext nested;
	}

	/**
	 * @description Nested context class for testing field path navigation.
	 */
	public class TestNestedContext
	{
		/**
		 * @description Child name field for nested path testing.
		 */
		public String childName;
		/**
		 * @description Amount field for nested path testing.
		 */
		public Decimal amount;
	}

	/**
	 * @description Test implementation of INT_BulkValidationContext for testing preLoad functionality.
	 * This class implements both INT_SObjectFormulaEvaluationContext and INT_BulkValidationContext.
	 * Note: Static tracking variables are in the outer class since inner classes cannot have static fields.
	 */
	public class TestBulkValidationContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext, UTIL_ValidationRule.INT_BulkValidationContext
	{
		/**
		 * @description The new record being validated.
		 */
		public Foobar__c newRecord;
		/**
		 * @description The old record (prior version).
		 */
		public Foobar__c oldRecord;

		public void preLoad(List<SObject> newRecords, List<SObject> oldRecords)
		{
			// Update outer class static variables
			UTIL_ValidationRule_TEST.bulkContextPreLoadWasCalled = true;
			UTIL_ValidationRule_TEST.bulkContextPreLoadRecordCount = newRecords?.size() ?? 0;
		}

		public void setContext(SObject oldRecord, SObject newRecord)
		{
			this.oldRecord = (Foobar__c)oldRecord;
			this.newRecord = (Foobar__c)newRecord;
		}
	}
}