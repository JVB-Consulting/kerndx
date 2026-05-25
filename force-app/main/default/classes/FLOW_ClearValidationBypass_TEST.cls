// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for FLOW_ClearValidationBypass invocable action.
 * Verifies that validation bypasses are correctly cleared.
 *
 * @see FLOW_ClearValidationBypass
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
private class FLOW_ClearValidationBypass_TEST
{
	/**
	 * @description Test group name for validation bypass.
	 */
	private static final String TEST_GROUP_NAME = 'TestGroup';
	/**
	 * @description Test object name for validation bypass.
	 */
	private static final String TEST_OBJECT_NAME = SEL_Foobar.OBJECT_NAME;
	/**
	 * @description Second test object name for validation bypass.
	 */
	private static final String TEST_OBJECT_NAME_2 = SEL_RecordType.OBJECT_NAME;
	/**
	 * @description Test rule name for validation bypass.
	 */
	private static final String TEST_RULE_NAME = 'TestRule';

	/**
	 * @description Tests that an object bypass is correctly cleared.
	 */
	@IsTest
	private static void shouldClearObjectBypass()
	{
		UTIL_ValidationRule.bypassObject(TEST_OBJECT_NAME);
		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_OBJECT_NAME), 'Object should be bypassed before clear');

		FLOW_ClearValidationBypass.DTO_Request request = new FLOW_ClearValidationBypass.DTO_Request();
		request.name = TEST_OBJECT_NAME;

		Test.startTest();
		FLOW_ClearValidationBypass.clearBypass(new List<FLOW_ClearValidationBypass.DTO_Request> {request});
		Test.stopTest();

		Assert.isFalse(UTIL_ValidationRule.isBypassed(TEST_OBJECT_NAME), 'Object should no longer be bypassed');
	}

	/**
	 * @description Tests that a group bypass is correctly cleared.
	 */
	@IsTest
	private static void shouldClearGroupBypass()
	{
		UTIL_ValidationRule.bypassGroup(TEST_GROUP_NAME);
		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_GROUP_NAME), 'Group should be bypassed before clear');

		FLOW_ClearValidationBypass.DTO_Request request = new FLOW_ClearValidationBypass.DTO_Request();
		request.name = TEST_GROUP_NAME;

		Test.startTest();
		FLOW_ClearValidationBypass.clearBypass(new List<FLOW_ClearValidationBypass.DTO_Request> {request});
		Test.stopTest();

		Assert.isFalse(UTIL_ValidationRule.isBypassed(TEST_GROUP_NAME), 'Group should no longer be bypassed');
	}

	/**
	 * @description Tests that a rule bypass is correctly cleared.
	 */
	@IsTest
	private static void shouldClearRuleBypass()
	{
		UTIL_ValidationRule.bypassRule(TEST_RULE_NAME);
		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_RULE_NAME), 'Rule should be bypassed before clear');

		FLOW_ClearValidationBypass.DTO_Request request = new FLOW_ClearValidationBypass.DTO_Request();
		request.name = TEST_RULE_NAME;

		Test.startTest();
		FLOW_ClearValidationBypass.clearBypass(new List<FLOW_ClearValidationBypass.DTO_Request> {request});
		Test.stopTest();

		Assert.isFalse(UTIL_ValidationRule.isBypassed(TEST_RULE_NAME), 'Rule should no longer be bypassed');
	}

	/**
	 * @description Tests that blank name is handled gracefully as a no-op.
	 */
	@IsTest
	private static void shouldHandleBlankName()
	{
		FLOW_ClearValidationBypass.DTO_Request request = new FLOW_ClearValidationBypass.DTO_Request();
		request.name = '';

		Test.startTest();
		FLOW_ClearValidationBypass.clearBypass(new List<FLOW_ClearValidationBypass.DTO_Request> {request});
		Test.stopTest();

		Assert.isNotNull(request, 'Request should still be valid');
	}

	/**
	 * @description Tests that null name is handled gracefully as a no-op.
	 */
	@IsTest
	private static void shouldHandleNullName()
	{
		FLOW_ClearValidationBypass.DTO_Request request = new FLOW_ClearValidationBypass.DTO_Request();
		request.name = null;

		Test.startTest();
		FLOW_ClearValidationBypass.clearBypass(new List<FLOW_ClearValidationBypass.DTO_Request> {request});
		Test.stopTest();

		Assert.isNotNull(request, 'Request should still be valid');
	}

	/**
	 * @description Tests that clearing a non-existent bypass does not throw exception.
	 */
	@IsTest
	private static void shouldNotThrowExceptionForNonExistentBypass()
	{
		FLOW_ClearValidationBypass.DTO_Request request = new FLOW_ClearValidationBypass.DTO_Request();
		request.name = 'NonExistentBypass';

		Test.startTest();
		FLOW_ClearValidationBypass.clearBypass(new List<FLOW_ClearValidationBypass.DTO_Request> {request});
		Test.stopTest();

		Assert.isFalse(UTIL_ValidationRule.isBypassed('NonExistentBypass'), 'Should not be bypassed');
	}

	/**
	 * @description Tests that clearAll clears all active bypasses.
	 */
	@IsTest
	private static void shouldClearAllBypasses()
	{
		UTIL_ValidationRule.bypassObject(TEST_OBJECT_NAME);
		UTIL_ValidationRule.bypassGroup(TEST_GROUP_NAME);
		UTIL_ValidationRule.bypassRule(TEST_RULE_NAME);

		FLOW_ClearValidationBypass.DTO_Request request = new FLOW_ClearValidationBypass.DTO_Request();
		request.clearAll = true;

		Test.startTest();
		FLOW_ClearValidationBypass.clearBypass(new List<FLOW_ClearValidationBypass.DTO_Request> {request});
		Test.stopTest();

		Assert.isFalse(UTIL_ValidationRule.isBypassed(TEST_OBJECT_NAME), 'Object should no longer be bypassed');
		Assert.isFalse(UTIL_ValidationRule.isBypassed(TEST_GROUP_NAME), 'Group should no longer be bypassed');
		Assert.isFalse(UTIL_ValidationRule.isBypassed(TEST_RULE_NAME), 'Rule should no longer be bypassed');
	}

	/**
	 * @description Tests that providing a name without clearAll only clears that specific bypass.
	 */
	@IsTest
	private static void shouldClearOnlyNamedBypass()
	{
		UTIL_ValidationRule.bypassObject(TEST_OBJECT_NAME);
		UTIL_ValidationRule.bypassObject(TEST_OBJECT_NAME_2);

		FLOW_ClearValidationBypass.DTO_Request request = new FLOW_ClearValidationBypass.DTO_Request();
		request.name = TEST_OBJECT_NAME;

		Test.startTest();
		FLOW_ClearValidationBypass.clearBypass(new List<FLOW_ClearValidationBypass.DTO_Request> {request});
		Test.stopTest();

		Assert.isFalse(UTIL_ValidationRule.isBypassed(TEST_OBJECT_NAME), 'First object should no longer be bypassed');
		Assert.isTrue(UTIL_ValidationRule.isBypassed(TEST_OBJECT_NAME_2), 'Second object should still be bypassed');

		UTIL_ValidationRule.clearAllBypasses();
	}

	/**
	 * @description Tests that clearAll ignores the name field.
	 */
	@IsTest
	private static void shouldClearAllBypassesIgnoringName()
	{
		UTIL_ValidationRule.bypassObject(TEST_OBJECT_NAME);
		UTIL_ValidationRule.bypassGroup(TEST_GROUP_NAME);

		FLOW_ClearValidationBypass.DTO_Request request = new FLOW_ClearValidationBypass.DTO_Request();
		request.clearAll = true;
		request.name = 'SomeOtherName';

		Test.startTest();
		FLOW_ClearValidationBypass.clearBypass(new List<FLOW_ClearValidationBypass.DTO_Request> {request});
		Test.stopTest();

		Assert.isFalse(UTIL_ValidationRule.isBypassed(TEST_OBJECT_NAME), 'Object should no longer be bypassed');
		Assert.isFalse(UTIL_ValidationRule.isBypassed(TEST_GROUP_NAME), 'Group should no longer be bypassed');
	}
}