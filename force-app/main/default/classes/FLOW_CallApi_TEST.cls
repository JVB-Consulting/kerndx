// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for the [FLOW_CallApi] class, validating successful callouts, custom parameter delimiters, and error handling.
 *
 * @see FLOW_CallApi
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FLOW_CallApi_TEST
{
	private static final String MSG_CONTAINS_VALUE = 'Response body should contain expected parameter';
	private static final String MSG_NOT_EMPTY = 'Response list should not be empty';
	private static final String MSG_NOT_NULL = 'Value should not be null';
	private static final String MSG_SUCCESSFUL = 'Callout should be successful';

	/**
	 * @description Creates a request DTO for synchronous callout testing.
	 *
	 * @return Configured DTO request
	 */
	private static FLOW_CallApi.DTO_Request setupRequestDto()
	{
		FLOW_CallApi.DTO_Request dtoRequest = new FLOW_CallApi.DTO_Request();
		dtoRequest.recordId = UserInfo.getUserId();
		dtoRequest.apiName = API_PostExample.class.getName();

		return dtoRequest;
	}

	/**
	 * @description Tests successful callout with a custom parameter delimiter.
	 *
	 * @see FLOW_CallApi.invokeApiCallSynchronously
	 */
	@IsTest
	private static void executeWithCustomDelimiter()
	{
		FLOW_CallApi.DTO_Request dtoRequest = setupRequestDto();
		dtoRequest.inputs = API_PostExample.PARAMETER_NAME + '=bar|bar=foo';
		dtoRequest.inputDelimiter = '|';

		Test.startTest();

		List<FLOW_CallApi.DTO_Response> dtoResponses =
				FLOW_CallApi.invokeApiCallSynchronously
						(
								new List<FLOW_CallApi.DTO_Request> {dtoRequest}
						);

		Test.stopTest();

		Assert.isTrue(!dtoResponses.isEmpty(), MSG_NOT_EMPTY);
		Assert.isTrue(dtoResponses.iterator().next().success, MSG_SUCCESSFUL);
		Assert.isTrue
				(
						dtoResponses.iterator().next().responseBody?.contains('bar') == true,
						MSG_CONTAINS_VALUE
				);
	}

	/**
	 * @description Tests successful callout with element value extraction.
	 *
	 * @see FLOW_CallApi.invokeApiCallSynchronously
	 */
	@IsTest
	private static void executeWithElementValue()
	{
		FLOW_CallApi.DTO_Request dtoRequest = setupRequestDto();
		dtoRequest.extractPath = API_PostExample.TITLE_FIELD_NAME;

		Test.startTest();

		List<FLOW_CallApi.DTO_Response> dtoResponses =
				FLOW_CallApi.invokeApiCallSynchronously
						(
								new List<FLOW_CallApi.DTO_Request> {dtoRequest}
						);

		Test.stopTest();

		Assert.isTrue(!dtoResponses.isEmpty(), MSG_NOT_EMPTY);
		Assert.isNotNull(dtoResponses.iterator().next().extractedValue, MSG_NOT_NULL);
	}

	/**
	 * @description Tests callout with invalid array extraction path on an object response,
	 * verifying that extracted value is null when path does not match.
	 *
	 * @see FLOW_CallApi.invokeApiCallSynchronously
	 */
	@IsTest
	private static void executeWithInvalidElementValue()
	{
		FLOW_CallApi.DTO_Request dtoRequest = setupRequestDto();
		dtoRequest.extractPath = '[0]';

		Test.startTest();

		List<FLOW_CallApi.DTO_Response> dtoResponses =
				FLOW_CallApi.invokeApiCallSynchronously
						(
								new List<FLOW_CallApi.DTO_Request> {dtoRequest}
						);

		Test.stopTest();

		Assert.isTrue(!dtoResponses.isEmpty(), MSG_NOT_EMPTY);
		Assert.isNull(dtoResponses.iterator().next().extractedValue, 'Extracted value should be null for invalid path');
	}

	/**
	 * @description Tests successful callout with standard response.
	 *
	 * @see FLOW_CallApi.invokeApiCallSynchronously
	 */
	@IsTest
	private static void executeWithStandardResponse()
	{
		FLOW_CallApi.DTO_Request dtoRequest = setupRequestDto();

		Test.startTest();

		List<FLOW_CallApi.DTO_Response> dtoResponses =
				FLOW_CallApi.invokeApiCallSynchronously
						(
								new List<FLOW_CallApi.DTO_Request> {dtoRequest}
						);

		Test.stopTest();

		Assert.isTrue(!dtoResponses.isEmpty(), MSG_NOT_EMPTY);
		Assert.isNotNull(dtoResponses.iterator().next().responseBody, 'Response body should not be null');
	}

	/**
	 * @description Tests handling of a failed callout, ensuring error response body is populated.
	 *
	 * @see FLOW_CallApi.invokeApiCallSynchronously
	 */
	@IsTest
	private static void handleFailedCallout()
	{
		API_MockFactory.registerErrorMock(API_PostExample.class.getName());
		FLOW_CallApi.DTO_Request dtoRequest = setupRequestDto();

		Test.startTest();

		List<FLOW_CallApi.DTO_Response> dtoResponses =
				FLOW_CallApi.invokeApiCallSynchronously
						(
								new List<FLOW_CallApi.DTO_Request> {dtoRequest}
						);

		Test.stopTest();

		Assert.isTrue(!dtoResponses.isEmpty(), MSG_NOT_EMPTY);
		FLOW_CallApi.DTO_Response response = dtoResponses.iterator().next();
		Assert.isFalse(response.success, 'Callout should have failed');
		Assert.isNotNull(response.responseBody, 'Error response body should be populated');
	}

	/**
	 * @description Tests extraction when the JSON response is invalid, verifying the catch block
	 * sets the extractedValue to the error message.
	 *
	 * @see FLOW_CallApi.invokeApiCallSynchronously
	 */
	@IsTest
	private static void executeWithMalformedJsonResponse()
	{
		API_MockFactory.forService(API_PostExample.class.getName()).body('not valid json').statusCode(200).register();
		FLOW_CallApi.DTO_Request dtoRequest = setupRequestDto();
		dtoRequest.extractPath = 'title';
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		List<FLOW_CallApi.DTO_Response> dtoResponses =
				FLOW_CallApi.invokeApiCallSynchronously
						(
								new List<FLOW_CallApi.DTO_Request> {dtoRequest}
						);

		Test.stopTest();

		Assert.isTrue(!dtoResponses.isEmpty(), MSG_NOT_EMPTY);
		Assert.isNotNull(dtoResponses.iterator().next().extractedValue, 'Error message should be set as extracted value');
	}

	/**
	 * @description Tests extraction when the JSON path resolves to null, verifying the null-check branch.
	 *
	 * @see FLOW_CallApi.invokeApiCallSynchronously
	 */
	@IsTest
	private static void executeWithNullElementValue()
	{
		FLOW_CallApi.DTO_Request dtoRequest = setupRequestDto();
		dtoRequest.extractPath = 'nonExistentField';

		Test.startTest();

		List<FLOW_CallApi.DTO_Response> dtoResponses =
				FLOW_CallApi.invokeApiCallSynchronously
						(
								new List<FLOW_CallApi.DTO_Request> {dtoRequest}
						);

		Test.stopTest();

		Assert.isTrue(!dtoResponses.isEmpty(), MSG_NOT_EMPTY);
		Assert.isNull(dtoResponses.iterator().next().extractedValue, 'Extracted value should be null for non-existent path');
	}

	/**
	 * @description Tests extraction when the JSON element is an array, verifying the toStringPretty branch.
	 *
	 * @see FLOW_CallApi.invokeApiCallSynchronously
	 */
	@IsTest
	private static void executeWithArrayElementValue()
	{
		API_MockFactory.forService(API_PostExample.class.getName()).body('{"items":["a","b"],"title":"test"}').statusCode(200).register();
		FLOW_CallApi.DTO_Request dtoRequest = setupRequestDto();
		dtoRequest.extractPath = 'items';

		Test.startTest();

		List<FLOW_CallApi.DTO_Response> dtoResponses =
				FLOW_CallApi.invokeApiCallSynchronously
						(
								new List<FLOW_CallApi.DTO_Request> {dtoRequest}
						);

		Test.stopTest();

		Assert.isTrue(!dtoResponses.isEmpty(), MSG_NOT_EMPTY);
		Assert.isNotNull(dtoResponses.iterator().next().extractedValue, 'Extracted array value should not be null');
	}

	/**
	 * @description Tests that an explicit idempotency key is passed through to the API call.
	 *
	 * @see FLOW_CallApi.invokeApiCallSynchronously
	 */
	@IsTest
	private static void shouldPassIdempotencyKeyToApiCall()
	{
		FLOW_CallApi.DTO_Request dtoRequest = setupRequestDto();
		dtoRequest.idempotencyKey = 'flow-key-12345';

		Test.startTest();

		List<FLOW_CallApi.DTO_Response> dtoResponses =
				FLOW_CallApi.invokeApiCallSynchronously
						(
								new List<FLOW_CallApi.DTO_Request> {dtoRequest}
						);

		Test.stopTest();

		FLOW_CallApi.DTO_Response dtoResponse = dtoResponses.iterator().next();
		Assert.isTrue(dtoResponse.success, MSG_SUCCESSFUL);

		ApiCall__c apiCall = (ApiCall__c)new SEL_ApiCall().findById(dtoResponse.apiCallId);
		Assert.areEqual('flow-key-12345', apiCall.IdempotencyKey__c, 'Idempotency key should be set on ApiCall');
	}
}