// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for FLOW_BypassValidation invocable action.
 * Verifies that validation bypasses are correctly set for objects, groups, and rules.
 *
 * @see FLOW_BypassValidation
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
private class FLOW_BypassValidation_TEST
{
	private static final String TEST_OBJECT_NAME = SEL_Foobar.OBJECT_NAME;
	private static final String TEST_OBJECT_NAME_2 = SEL_RecordType.OBJECT_NAME;
	private static final String TEST_OBJECT_NAME_3 = SEL_User.OBJECT_NAME;
	private static final String TEST_GROUP_NAME = 'TestValidationGroup';
	private static final String TEST_RULE_NAME = 'TestValidationRule';

	/**
	 * @description Tests that an object bypass is correctly set via OBJECT_NAME bypassType.
	 */
	@IsTest
	private static void shouldBypassObjectByName()
	{
		FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
		request.bypassType = UTIL_ValidationRule.VALIDATION_BYPASS_TYPE.OBJECT_NAME.name();
		request.name = TEST_OBJECT_NAME;

		Test.startTest();
		FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request> {request});
		Test.stopTest();

		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_OBJECT_NAME), 'Object should be bypassed');
	}

	/**
	 * @description Tests that a group bypass is correctly set via GROUP_NAME bypassType.
	 */
	@IsTest
	private static void shouldBypassGroupByName()
	{
		FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
		request.bypassType = UTIL_ValidationRule.VALIDATION_BYPASS_TYPE.GROUP_NAME.name();
		request.name = TEST_GROUP_NAME;

		Test.startTest();
		FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request> {request});
		Test.stopTest();

		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_GROUP_NAME), 'Group should be bypassed');
	}

	/**
	 * @description Tests that a rule bypass is correctly set via RULE_NAME bypassType.
	 */
	@IsTest
	private static void shouldBypassRuleByName()
	{
		FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
		request.bypassType = UTIL_ValidationRule.VALIDATION_BYPASS_TYPE.RULE_NAME.name();
		request.name = TEST_RULE_NAME;

		Test.startTest();
		FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request> {request});
		Test.stopTest();

		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_RULE_NAME), 'Rule should be bypassed');
	}

	/**
	 * @description Tests that null bypassType defaults to OBJECT_NAME bypass.
	 */
	@IsTest
	private static void shouldDefaultToObjectNameWhenBypassTypeIsNull()
	{
		FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
		request.bypassType = null;
		request.name = TEST_OBJECT_NAME;

		Test.startTest();
		FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request> {request});
		Test.stopTest();

		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_OBJECT_NAME), 'Should default to object bypass');
	}

	/**
	 * @description Tests that empty bypassType defaults to OBJECT_NAME bypass.
	 */
	@IsTest
	private static void shouldDefaultToObjectNameWhenBypassTypeIsBlank()
	{
		FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
		request.bypassType = '';
		request.name = TEST_OBJECT_NAME_2;

		Test.startTest();
		FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request> {request});
		Test.stopTest();

		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_OBJECT_NAME_2), 'Should default to object bypass');
	}

	/**
	 * @description Tests that blank name is handled gracefully without creating a bypass.
	 */
	@IsTest
	private static void shouldHandleBlankNameGracefully()
	{
		FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
		request.bypassType = UTIL_ValidationRule.VALIDATION_BYPASS_TYPE.OBJECT_NAME.name();
		request.name = '';

		Test.startTest();
		FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request> {request});
		Test.stopTest();

		// Then - should not throw exception and no bypass should be set
		Assert.isFalse(UTIL_ValidationRule.isBypassed(''), 'Empty name should not create bypass');
	}

	/**
	 * @description Tests that null name is handled gracefully without throwing exception.
	 */
	@IsTest
	private static void shouldHandleNullNameGracefully()
	{
		FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
		request.bypassType = UTIL_ValidationRule.VALIDATION_BYPASS_TYPE.OBJECT_NAME.name();
		request.name = null;

		Test.startTest();
		FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request> {request});
		Test.stopTest();

		// Then - should not throw exception
		Assert.isNotNull(request, 'Request should still be valid');
	}

	/**
	 * @description Tests that lowercase bypassType is handled correctly.
	 */
	@IsTest
	private static void shouldHandleLowercaseBypassType()
	{
		FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
		request.bypassType = 'object_name'; // lowercase - intentionally testing case insensitivity
		request.name = TEST_OBJECT_NAME_3;

		Test.startTest();
		FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request> {request});
		Test.stopTest();

		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_OBJECT_NAME_3), 'Should handle lowercase bypass type');
	}

	/**
	 * @description Tests that invalid bypassType throws exception with user-friendly message.
	 */
	@IsTest
	private static void shouldThrowExceptionForInvalidBypassType()
	{
		FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
		request.bypassType = 'INVALID_TYPE'; // intentionally invalid
		request.name = TEST_OBJECT_NAME;

		// When/Then
		Test.startTest();
		try
		{
			FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request> {request});
			Assert.fail('Should have thrown exception for invalid bypass type');
		}
		catch(Exception e)
		{
			Assert.areEqual(FLOW_BypassValidation.ERROR_INVALID_BYPASS_TYPE, e.getMessage(), 'Should have user-friendly error message');
		}
		Test.stopTest();
	}

}