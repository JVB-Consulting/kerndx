// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for DTO_InvocationResult. Verifies the computed success property
 * returns the correct value for various HTTP status code ranges.
 *
 * @see DTO_InvocationResult
 *
 * @author Jason van Beukering
 *
 * @group Data Transfer Objects
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class DTO_InvocationResult_TEST
{
	/**
	 * @description Tests that success is true for HTTP 200 OK.
	 */
	@IsTest
	private static void shouldReportSuccessForOkResponse()
	{
		DTO_InvocationResult invocationResult = new DTO_InvocationResult();
		invocationResult.statusCode = API_Base.HTTP_OK;
		Assert.isTrue(invocationResult.success, 'HTTP 200 should be successful');
	}

	/**
	 * @description Tests that success is true for HTTP 201 Created.
	 */
	@IsTest
	private static void shouldReportSuccessForCreatedResponse()
	{
		DTO_InvocationResult invocationResult = new DTO_InvocationResult();
		invocationResult.statusCode = API_Base.HTTP_CREATED;
		Assert.isTrue(invocationResult.success, 'HTTP 201 should be successful');
	}

	/**
	 * @description Tests that success is true at the upper boundary of the 2xx range.
	 */
	@IsTest
	private static void shouldReportSuccessAtUpperBoundaryOf2xxRange()
	{
		DTO_InvocationResult invocationResult = new DTO_InvocationResult();
		invocationResult.statusCode = 299;
		Assert.isTrue(invocationResult.success, 'HTTP 299 should be successful');
	}

	/**
	 * @description Tests that success is false for HTTP 400 Bad Request.
	 */
	@IsTest
	private static void shouldReportFailureForBadRequest()
	{
		DTO_InvocationResult invocationResult = new DTO_InvocationResult();
		invocationResult.statusCode = API_Base.HTTP_BAD_REQUEST;
		Assert.isFalse(invocationResult.success, 'HTTP 400 should not be successful');
	}

	/**
	 * @description Tests that success is false for HTTP 500 Internal Server Error.
	 */
	@IsTest
	private static void shouldReportFailureForInternalServerError()
	{
		DTO_InvocationResult invocationResult = new DTO_InvocationResult();
		invocationResult.statusCode = API_Base.HTTP_INTERNAL_SERVER_ERROR;
		Assert.isFalse(invocationResult.success, 'HTTP 500 should not be successful');
	}

	/**
	 * @description Tests that success is false when no status code has been set.
	 */
	@IsTest
	private static void shouldReportFailureWhenStatusCodeIsNull()
	{
		DTO_InvocationResult invocationResult = new DTO_InvocationResult();
		Assert.isFalse(invocationResult.success, 'Null status code should not be successful');
	}

	/**
	 * @description Tests that the constructor initializes default collections.
	 */
	@IsTest
	private static void shouldInitializeDefaultCollections()
	{
		DTO_InvocationResult invocationResult = new DTO_InvocationResult();
		Assert.isNotNull(invocationResult.errors, 'Errors list should be initialized');
		Assert.isTrue(invocationResult.errors.isEmpty(), 'Errors list should be empty');
		Assert.isNotNull(invocationResult.requestHeaders, 'Request headers should be initialized');
		Assert.isNotNull(invocationResult.responseHeaders, 'Response headers should be initialized');
	}

	/**
	 * @description Tests that timing duration fields are assignable and readable.
	 */
	@IsTest
	private static void shouldSupportTimingDurationFields()
	{
		DTO_InvocationResult invocationResult = new DTO_InvocationResult();
		invocationResult.handlerDurationMs = 120;
		invocationResult.calloutDurationMs = 50;
		invocationResult.commitDurationMs = 26;

		Assert.areEqual(120, invocationResult.handlerDurationMs, 'Handler duration should be set');
		Assert.areEqual(50, invocationResult.calloutDurationMs, 'Callout duration should be set');
		Assert.areEqual(26, invocationResult.commitDurationMs, 'Commit duration should be set');
	}
}