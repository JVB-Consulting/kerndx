// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the invocable action for retrieving picklist values via ConnectApi.
 * SeeAllData=true is required because ConnectApi methods are not supported in data-siloed tests.
 *
 * @see FLOW_GetPicklistValues
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexUnitTestShouldNotUseSeeAllDataTrue')
private class FLOW_GetPicklistValues_TEST
{
	/**
	 * @description Object API name used across tests.
	 */
	private static final String TEST_OBJECT_NAME = SEL_Foobar.OBJECT_NAME;

	/**
	 * @description Record type developer name used across tests.
	 */
	private static final String TEST_RECORD_TYPE = SEL_Foobar.RT_DEFAULT;

	/**
	 * @description Tests that picklist values are retrieved successfully for a valid object and record type.
	 *
	 * @see FLOW_GetPicklistValues.getPickListValues
	 */
	@IsTest
	private static void shouldRetrievePicklistValuesSuccessfully()
	{
		TST_Factory.assignAdministratorPermissionSet();

		System.runAs(new User(Id = UserInfo.getUserId()))
		{
			FLOW_GetPicklistValues.DTO_Request dtoRequest = new FLOW_GetPicklistValues.DTO_Request();
			dtoRequest.objectApiName = TEST_OBJECT_NAME;
			dtoRequest.recordTypeApiName = TEST_RECORD_TYPE;

			List<FLOW_GetPicklistValues.DTO_Response> dtoResponses =
					FLOW_GetPicklistValues.getPickListValues(new List<FLOW_GetPicklistValues.DTO_Request> {dtoRequest});

			Assert.isFalse(dtoResponses.isEmpty(), 'No responses returned');

			FLOW_GetPicklistValues.DTO_Response dtoResponse = dtoResponses.iterator().next();

			Assert.isTrue(dtoResponse.callSuccessful, 'Call not successful, error received: ' + dtoResponse.errorText);
			Assert.isFalse(dtoResponse.pickLists.isEmpty(), 'No picklist values returned');
		}
	}

	/**
	 * @description Tests that cached responses are returned on subsequent calls.
	 *
	 * @see FLOW_GetPicklistValues.getPickListValues
	 */
	@IsTest
	private static void shouldReturnCachedResponseOnSecondCall()
	{
		TST_Factory.assignAdministratorPermissionSet();

		System.runAs(new User(Id = UserInfo.getUserId()))
		{
			FLOW_GetPicklistValues.DTO_Request dtoRequest = new FLOW_GetPicklistValues.DTO_Request();
			dtoRequest.objectApiName = TEST_OBJECT_NAME;
			dtoRequest.recordTypeApiName = TEST_RECORD_TYPE;

			List<FLOW_GetPicklistValues.DTO_Request> dtoRequests = new List<FLOW_GetPicklistValues.DTO_Request> {dtoRequest};

			List<FLOW_GetPicklistValues.DTO_Response> firstResponses = FLOW_GetPicklistValues.getPickListValues(dtoRequests);
			List<FLOW_GetPicklistValues.DTO_Response> secondResponses = FLOW_GetPicklistValues.getPickListValues(dtoRequests);

			Assert.isTrue(firstResponses.iterator().next().callSuccessful, 'First call should succeed');
			Assert.isTrue(secondResponses.iterator().next().callSuccessful, 'Cached call should succeed');
		}
	}

	/**
	 * @description Tests that an error is returned when an invalid record type is provided.
	 *
	 * @see FLOW_GetPicklistValues.getPickListValues
	 */
	@IsTest
	private static void shouldReturnErrorForInvalidRecordType()
	{
		FLOW_GetPicklistValues.DTO_Request dtoRequest = new FLOW_GetPicklistValues.DTO_Request();
		dtoRequest.objectApiName = TEST_OBJECT_NAME;
		dtoRequest.recordTypeApiName = UTIL_Random.randomName();

		List<FLOW_GetPicklistValues.DTO_Response> dtoResponses =
				FLOW_GetPicklistValues.getPickListValues(new List<FLOW_GetPicklistValues.DTO_Request> {dtoRequest});

		Assert.isFalse(dtoResponses.isEmpty(), 'No responses returned');

		FLOW_GetPicklistValues.DTO_Response dtoResponse = dtoResponses.iterator().next();

		Assert.isFalse(dtoResponse.callSuccessful, 'Call should have failed');
		Assert.isTrue(String.isNotBlank(dtoResponse.errorText), 'No error message returned');
	}

	/**
	 * @description Tests that an error response is returned when the ConnectApi call throws an exception.
	 *
	 * @see FLOW_GetPicklistValues.getPickListValues
	 */
	@IsTest
	private static void shouldReturnErrorWhenConnectApiThrowsException()
	{
		FLOW_GetPicklistValues.testException = new IllegalArgumentException('ConnectApi failure');

		FLOW_GetPicklistValues.DTO_Request dtoRequest = new FLOW_GetPicklistValues.DTO_Request();
		dtoRequest.objectApiName = TEST_OBJECT_NAME;
		dtoRequest.recordTypeApiName = TEST_RECORD_TYPE;

		List<FLOW_GetPicklistValues.DTO_Response> dtoResponses =
				FLOW_GetPicklistValues.getPickListValues(new List<FLOW_GetPicklistValues.DTO_Request> {dtoRequest});

		FLOW_GetPicklistValues.DTO_Response dtoResponse = dtoResponses.iterator().next();

		Assert.isFalse(dtoResponse.callSuccessful, 'Call should have failed');
		Assert.areEqual('ConnectApi failure', dtoResponse.errorText, 'Error message should match exception');
	}

	/**
	 * @description Tests that an exception is thrown when more than one request is provided.
	 *
	 * @see FLOW_GetPicklistValues.getPickListValues
	 */
	@IsTest
	private static void shouldThrowExceptionForMultipleRequests()
	{
		FLOW_GetPicklistValues.DTO_Request dtoRequest = new FLOW_GetPicklistValues.DTO_Request();

		try
		{
			FLOW_GetPicklistValues.getPickListValues(new List<FLOW_GetPicklistValues.DTO_Request> {dtoRequest, dtoRequest});

			Assert.fail('Exception should have been thrown');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect error thrown');
		}
	}

	/**
	 * @description Tests that an exception is thrown when no requests are provided.
	 *
	 * @see FLOW_GetPicklistValues.getPickListValues
	 */
	@IsTest
	private static void shouldThrowExceptionForNoRequests()
	{
		try
		{
			FLOW_GetPicklistValues.getPickListValues(new List<FLOW_GetPicklistValues.DTO_Request>());

			Assert.fail('Exception should have been thrown');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect error thrown');
		}
	}
}