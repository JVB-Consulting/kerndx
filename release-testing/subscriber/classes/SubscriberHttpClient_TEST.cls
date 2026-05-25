// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests UTIL_HttpClient ad-hoc mode from subscriber code. Verifies static factory
 * methods (get/post/put/del/patch), builder chaining, and response deserialization using
 * API_MockFactory to mock responses by credential name.
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date March 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class SubscriberHttpClient_TEST
{
	/**
	 * @description Test credential name used as the mock service key.
	 */
	private static final String TEST_CREDENTIAL = 'SubscriberTestCredential';

	/**
	 * @description Registers a mock response for the test credential and returns the body.
	 *
	 * @param responseBody The JSON body for the mock response.
	 * @param statusCode The HTTP status code.
	 */
	private static void registerMock(String responseBody, Integer statusCode)
	{
		kern.API_MockFactory.forService(TEST_CREDENTIAL)
				.body(responseBody)
				.statusCode(StatusCode)
				.register();
	}

	/**
	 * @description Tests a GET request via UTIL_HttpClient.get() ad-hoc factory.
	 */
	@IsTest
	private static void shouldExecuteGetRequest()
	{
		registerMock('{"id":1,"name":"Test"}', 200);

		Test.startTest();
		HttpResponse response = kern.UTIL_HttpClient.get(TEST_CREDENTIAL, '/items/1').send();
		Test.stopTest();

		Assert.isNotNull(response, 'Response should not be null');
		Assert.areEqual(200, response.getStatusCode(), 'Status code should be 200');
		Assert.isTrue(response.getBody().contains('"name":"Test"'), 'Body should contain expected JSON');
	}

	/**
	 * @description Tests a POST request with a JSON body.
	 */
	@IsTest
	private static void shouldExecutePostWithBody()
	{
		registerMock('{"created":true,"id":"new-001"}', 201);

		Test.startTest();
		HttpResponse response = kern.UTIL_HttpClient.post(TEST_CREDENTIAL, '/items')
				.body('{"name":"New Item"}')
				.send();
		Test.stopTest();

		Assert.isNotNull(response, 'Response should not be null');
		Assert.areEqual(201, response.getStatusCode(), 'Status code should be 201');
		Assert.isTrue(response.getBody().contains('"created":true'), 'Body should confirm creation');
	}

	/**
	 * @description Tests a PUT request with a JSON body.
	 */
	@IsTest
	private static void shouldExecutePutRequest()
	{
		registerMock('{"updated":true}', 200);

		Test.startTest();
		HttpResponse response = kern.UTIL_HttpClient.put(TEST_CREDENTIAL, '/items/1')
				.body('{"name":"Updated Item"}')
				.send();
		Test.stopTest();

		Assert.isNotNull(response, 'Response should not be null');
		Assert.areEqual(200, response.getStatusCode(), 'Status code should be 200');
	}

	/**
	 * @description Tests a DELETE request.
	 */
	@IsTest
	private static void shouldExecuteDeleteRequest()
	{
		registerMock('{"deleted":true}', 200);

		Test.startTest();
		HttpResponse response = kern.UTIL_HttpClient.del(TEST_CREDENTIAL, '/items/1').send();
		Test.stopTest();

		Assert.isNotNull(response, 'Response should not be null');
		Assert.areEqual(200, response.getStatusCode(), 'Status code should be 200');
	}

	/**
	 * @description Tests builder chaining — headers, timeout, and asMap() deserialization.
	 */
	@IsTest
	private static void shouldChainBuilderMethodsAndDeserialize()
	{
		registerMock('{"status":"ok","count":42}', 200);

		Test.startTest();
		Map<String, Object> data = kern.UTIL_HttpClient.get(TEST_CREDENTIAL, '/status')
				.header('X-Custom-Header', 'subscriber-test')
				.header('Accept', 'application/json')
				.timeout(30000)
				.asMap();
		Test.stopTest();

		Assert.isNotNull(data, 'Deserialized map should not be null');
		Assert.areEqual('ok', data.get('status'), 'Status should be ok');
		Assert.areEqual(42, (Integer)data.get('count'), 'Count should be 42');
	}

	/**
	 * @description Tests PATCH request via UTIL_HttpClient.patch().
	 */
	@IsTest
	private static void shouldExecutePatchRequest()
	{
		registerMock('{"patched":true}', 200);

		Test.startTest();
		HttpResponse response = kern.UTIL_HttpClient.patch(TEST_CREDENTIAL, '/items/1')
				.body('{"name":"Patched"}')
				.send();
		Test.stopTest();

		Assert.isNotNull(response, 'Response should not be null');
		Assert.areEqual(200, response.getStatusCode(), 'Status code should be 200');
	}

	/**
	 * @description Tests asString() terminal method.
	 */
	@IsTest
	private static void shouldReturnResponseAsString()
	{
		registerMock('{"message":"hello"}', 200);

		Test.startTest();
		String body = kern.UTIL_HttpClient.get(TEST_CREDENTIAL, '/hello').asString();
		Test.stopTest();

		Assert.isNotNull(body, 'String body should not be null');
		Assert.isTrue(body.contains('"message":"hello"'), 'Body should contain expected content');
	}
}
