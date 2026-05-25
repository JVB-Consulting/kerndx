// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for FLOW_BypassTrigger.
 *
 * @see FLOW_BypassTrigger
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FLOW_BypassTrigger_TEST
{
	/**
	 * @description Test value for the bypassed item name.
	 */
	private static final String BYPASS_ITEM_NAME = 'BypassedItemName';

	/**
	 * @description Tests that an object-level bypass is applied.
	 */
	@IsTest
	private static void shouldBypassObjectName()
	{
		FLOW_BypassTrigger.DTO_Request request = newRequest('BYPASS', 'OBJECT_NAME', BYPASS_ITEM_NAME);

		Test.startTest();

		FLOW_BypassTrigger.execute(new List<FLOW_BypassTrigger.DTO_Request> {request});

		Test.stopTest();

		Assert.isTrue(TRG_Base.isBypassed(BYPASS_ITEM_NAME), 'The object should be bypassed');
	}

	/**
	 * @description Tests that a class-level bypass is applied.
	 */
	@IsTest
	private static void shouldBypassClassName()
	{
		FLOW_BypassTrigger.DTO_Request request = newRequest('BYPASS', 'CLASS_NAME', BYPASS_ITEM_NAME);

		Test.startTest();

		FLOW_BypassTrigger.execute(new List<FLOW_BypassTrigger.DTO_Request> {request});

		Test.stopTest();

		Assert.isTrue(TRG_Base.isActionBypassed(BYPASS_ITEM_NAME), 'The action should be bypassed');
	}

	/**
	 * @description Tests that default action is BYPASS when action is null.
	 */
	@IsTest
	private static void shouldDefaultToBypassAction()
	{
		FLOW_BypassTrigger.DTO_Request request = newRequest(null, 'OBJECT_NAME', BYPASS_ITEM_NAME);

		Test.startTest();

		FLOW_BypassTrigger.execute(new List<FLOW_BypassTrigger.DTO_Request> {request});

		Test.stopTest();

		Assert.isTrue(TRG_Base.isBypassed(BYPASS_ITEM_NAME), 'The object should be bypassed when action defaults');
	}

	/**
	 * @description Tests that a specific object-level bypass is cleared.
	 */
	@IsTest
	private static void shouldClearObjectBypass()
	{
		TRG_Base.bypass(BYPASS_ITEM_NAME);

		FLOW_BypassTrigger.DTO_Request request = newRequest('CLEAR', 'OBJECT_NAME', BYPASS_ITEM_NAME);

		Test.startTest();

		FLOW_BypassTrigger.execute(new List<FLOW_BypassTrigger.DTO_Request> {request});

		Test.stopTest();

		Assert.isFalse(TRG_Base.isBypassed(BYPASS_ITEM_NAME), 'The object bypass should be cleared');
	}

	/**
	 * @description Tests that a specific class-level bypass is cleared.
	 */
	@IsTest
	private static void shouldClearClassBypass()
	{
		TRG_Base.bypassAction(BYPASS_ITEM_NAME);

		FLOW_BypassTrigger.DTO_Request request = newRequest('CLEAR', 'CLASS_NAME', BYPASS_ITEM_NAME);

		Test.startTest();

		FLOW_BypassTrigger.execute(new List<FLOW_BypassTrigger.DTO_Request> {request});

		Test.stopTest();

		Assert.isFalse(TRG_Base.isActionBypassed(BYPASS_ITEM_NAME), 'The action bypass should be cleared');
	}

	/**
	 * @description Tests that all object-level bypasses are cleared.
	 */
	@IsTest
	private static void shouldClearAllObjectBypasses()
	{
		TRG_Base.bypass(BYPASS_ITEM_NAME);

		FLOW_BypassTrigger.DTO_Request request = newRequest('CLEAR_ALL', 'OBJECT_NAME', BYPASS_ITEM_NAME);

		Test.startTest();

		FLOW_BypassTrigger.execute(new List<FLOW_BypassTrigger.DTO_Request> {request});

		Test.stopTest();

		Assert.isFalse(TRG_Base.isBypassed(BYPASS_ITEM_NAME), 'All object bypasses should be cleared');
	}

	/**
	 * @description Tests that all class-level bypasses are cleared.
	 */
	@IsTest
	private static void shouldClearAllClassBypasses()
	{
		TRG_Base.bypassAction(BYPASS_ITEM_NAME);

		FLOW_BypassTrigger.DTO_Request request = newRequest('CLEAR_ALL', 'CLASS_NAME', BYPASS_ITEM_NAME);

		Test.startTest();

		FLOW_BypassTrigger.execute(new List<FLOW_BypassTrigger.DTO_Request> {request});

		Test.stopTest();

		Assert.isFalse(TRG_Base.isActionBypassed(BYPASS_ITEM_NAME), 'All action bypasses should be cleared');
	}

	/**
	 * @description Tests that an exception is thrown when no requests are provided.
	 */
	@IsTest
	private static void shouldThrowWhenNoRequests()
	{
		try
		{
			Test.startTest();

			FLOW_BypassTrigger.execute(new List<FLOW_BypassTrigger.DTO_Request>());

			Test.stopTest();

			Assert.fail('Should throw IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			Assert.isTrue(error.getMessage().contains(FLOW_BypassTrigger.class.getName()), 'Error should reference the class name');
		}
	}

	/**
	 * @description Tests that an exception is thrown when an invalid bypass type is provided.
	 */
	@IsTest
	private static void shouldThrowWhenInvalidBypassType()
	{
		FLOW_BypassTrigger.DTO_Request request = newRequest('BYPASS', 'INVALID', BYPASS_ITEM_NAME);

		try
		{
			Test.startTest();

			FLOW_BypassTrigger.execute(new List<FLOW_BypassTrigger.DTO_Request> {request});

			Test.stopTest();

			Assert.fail('Should throw NoSuchElementException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, NoSuchElementException.class, 'Incorrect Exception Type');
			Assert.areEqual(TRG_Base.ERROR_INVALID_BYPASS_TYPE, error.getMessage(), 'Error message should match');
		}
	}

	/**
	 * @description Tests that an exception is thrown when an invalid action is provided.
	 */
	@IsTest
	private static void shouldThrowWhenInvalidAction()
	{
		FLOW_BypassTrigger.DTO_Request request = newRequest('INVALID', 'OBJECT_NAME', BYPASS_ITEM_NAME);

		try
		{
			Test.startTest();

			FLOW_BypassTrigger.execute(new List<FLOW_BypassTrigger.DTO_Request> {request});

			Test.stopTest();

			Assert.fail('Should throw NoSuchElementException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, NoSuchElementException.class, 'Incorrect Exception Type');
			Assert.areEqual(TRG_Base.ERROR_INVALID_BYPASS_ACTION, error.getMessage(), 'Error message should match');
		}
	}

	/**
	 * @description Creates a new DTO_Request with the given values.
	 *
	 * @param action The action to perform
	 * @param bypassType The bypass type
	 * @param name The item name
	 *
	 * @return A populated DTO_Request
	 */
	private static FLOW_BypassTrigger.DTO_Request newRequest(String action, String bypassType, String name)
	{
		FLOW_BypassTrigger.DTO_Request request = new FLOW_BypassTrigger.DTO_Request();
		request.action = action;
		request.bypassType = bypassType;
		request.name = name;
		return request;
	}
}