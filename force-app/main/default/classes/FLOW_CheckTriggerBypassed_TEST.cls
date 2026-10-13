// SPDX-License-Identifier: Apache-2.0
/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @description Will test the behaviour of FLOW_CheckTriggerBypassed
 * adapted from:[apex-trigger-actions-framework](https://github.com/mitchspano/apex-trigger-actions-framework/blob/master/README.md#metadata-driven-trigger-actions)
 *
 * @see FLOW_CheckTriggerBypassed
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class FLOW_CheckTriggerBypassed_TEST
{
	/**
	 * @description A made-up name the tests bypass and then ask about. It stands in for an object name or an action class
	 * name, depending on the kind of bypass the test sets. One test also sends it as the bypass type, where it is not a
	 * valid type, to prove the request is refused.
	 */
	private static final String BYPASS_ITEM_NAME = 'BypassedItemName';

	/**
	 * @description Will check that that actions for an object are bypassed
	 */
	@IsTest
	private static void objectName()
	{
		assertIsBypassed(TRG_Base.BypassType.OBJECT_NAME);
	}

	/**
	 * @description Will check that an action is bypassed
	 *
	 * @param bypassType The type of bypass to check
	 *
	 * @see FLOW_CheckTriggerBypassed.isBypassed
	 */
	private static void assertIsBypassed(TRG_Base.BypassType bypassType)
	{
		if(bypassType == TRG_Base.BypassType.OBJECT_NAME)
		{
			TRG_Base.bypass(BYPASS_ITEM_NAME);
		}
		else
		{
			TRG_Base.bypassAction(BYPASS_ITEM_NAME);
		}

		FLOW_CheckTriggerBypassed.DTO_Request dtoRequest = new FLOW_CheckTriggerBypassed.DTO_Request();

		dtoRequest.name = BYPASS_ITEM_NAME;
		dtoRequest.bypassType = bypassType.name();

		Test.startTest();

		Boolean isBypassed = FLOW_CheckTriggerBypassed.isBypassed(new List<FLOW_CheckTriggerBypassed.DTO_Request> {dtoRequest}).iterator().next();

		Test.stopTest();

		Assert.isTrue(isBypassed, 'Expected the item to be reported as bypassed, got ' + isBypassed);
	}

	/**
	 * @description Will check that that action for a class is bypassed
	 */
	@IsTest
	private static void className()
	{
		assertIsBypassed(TRG_Base.BypassType.CLASS_NAME);
	}

	/**
	 * @description Checks that if an invalid type is passed and exception is thrown as expected
	 */
	@IsTest
	private static void invalidNumberOfRequests()
	{
		try
		{
			Test.startTest();

			FLOW_CheckTriggerBypassed.isBypassed(new List<FLOW_CheckTriggerBypassed.DTO_Request>());

			Test.stopTest();

			Assert.fail('Expected an IllegalArgumentException for an empty request list, got no exception');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException, got ' + error.getTypeName());
			Assert.isTrue(error.getMessage().contains(FLOW_CheckTriggerBypassed.class.getName()), 'Expected the message to name the class, got ' + error.getMessage());
		}
	}

	/**
	 * @description Checks that the method fails if an invalid bypass type is provided
	 */
	@IsTest
	private static void invalidBypassType()
	{
		try
		{
			FLOW_CheckTriggerBypassed.DTO_Request dtoRequest = new FLOW_CheckTriggerBypassed.DTO_Request();

			dtoRequest.name = BYPASS_ITEM_NAME;
			dtoRequest.bypassType = BYPASS_ITEM_NAME;

			Test.startTest();

			FLOW_CheckTriggerBypassed.isBypassed(new List<FLOW_CheckTriggerBypassed.DTO_Request> {dtoRequest});

			Test.stopTest();

			Assert.fail('Expected a NoSuchElementException for an invalid bypass type, got no exception');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, NoSuchElementException.class, 'Expected a NoSuchElementException, got ' + error.getTypeName());
			Assert.areEqual(TRG_Base.ERROR_INVALID_BYPASS_TYPE, error.getMessage(), 'Expected the invalid bypass type message, got ' + error.getMessage());
		}
	}
}