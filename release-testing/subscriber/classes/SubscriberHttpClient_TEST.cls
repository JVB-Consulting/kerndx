// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests UTIL_HttpClient ad-hoc mode from subscriber code. Verifies static factory
 * methods (get/post/put/del/patch), builder chaining, and response deserialization using
 * API_MockFactory to mock responses by credential name.
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date March 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class SubscriberHttpClient_TEST
{
	/**
	 * @description Test credential name used as the mock service key.
	 */
	private static final String TEST_CREDENTIAL = 'SubscriberTestCredential';

	/**
	 * @description The credential header the caller sets by hand.
	 */
	private static final String HEADER_AUTHORIZATION = 'Authorization';

	/**
	 * @description The scheme word in front of the token in the Authorization header.
	 */
	private static final String BEARER_PREFIX = 'Bearer ';

	/**
	 * @description The text the framework stores in place of a credential header's value.
	 */
	private static final String REDACTED_MARKER = '[REDACTED]';

	/**
	 * @description A retry budget beyond the ad-hoc client's limit of three attempts in one transaction, so budget is left
	 * for a scheduled retry.
	 */
	private static final Integer RETRY_BUDGET_BEYOND_SYNCHRONOUS = 5;

	/**
	 * @description The retry wait, in seconds.
	 */
	private static final Integer RETRY_BACKOFF_SECONDS = 30;

	/**
	 * @description The status of an ApiCall record that ended in failure.
	 */
	private static final String STATUS_FAILED = 'Failed';

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
	 * @description Tests builder chaining: headers, timeout, and asMap() deserialization.
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

	/**
	 * @description A POST with an idempotency key that gets no answer is safe to repeat, so it would wait for a scheduled
	 * retry. When the caller set the Authorization header by hand, the stored call keeps the redaction marker in place of
	 * the token. A retry could not send the token, so the call is held back for a person: it ends Failed with no retry
	 * time, and its error text names the header in the labelled words.
	 */
	@IsTest
	private static void shouldStoreAHandSetCredentialHeaderRedactedAndHoldTheCallBackFromRetry()
	{
		String token = kern.UTIL_Random.randomName();
		String idempotencyKey = kern.UTIL_Random.randomName();
		kern.API_MockFactory.forService(TEST_CREDENTIAL).withTransportFailure().register();

		Test.startTest();
		kern.UTIL_HttpClient.post(TEST_CREDENTIAL, '/items')
				.header(HEADER_AUTHORIZATION, BEARER_PREFIX + token)
				.withIdempotencyKey(idempotencyKey)
				.withRetry(RETRY_BUDGET_BEYOND_SYNCHRONOUS, RETRY_BACKOFF_SECONDS)
				.send();
		Test.stopTest();

		List<kern__ApiCall__c> rows = (List<kern__ApiCall__c>)new kern.SEL_ApiCall().findByField(kern__ApiCall__c.kern__IdempotencyKey__c, idempotencyKey);
		Assert.areEqual(1, rows.size(), 'Expected one stored call with the key, got ' + rows.size());
		kern__ApiCall__c storedCall = rows[0];
		String expectedLine = String.format(System.Label.kern.RetryApiIssue_CredentialHeaderNotStored, new List<Object> {HEADER_AUTHORIZATION});
		Assert.isFalse(storedCall.kern__RequestParameters__c.contains(token), 'Expected the stored call not to carry the token');
		Assert.isTrue(storedCall.kern__RequestParameters__c.contains(REDACTED_MARKER), 'Expected the stored call to carry the redaction marker');
		Assert.areEqual(STATUS_FAILED, storedCall.kern__Status__c, 'Expected the call to be held back as Failed, got ' + storedCall.kern__Status__c);
		Assert.isNull(storedCall.kern__NextRetry__c, 'Expected no retry time on a call whose credential was not stored');
		Assert.isTrue(storedCall.kern__ErrorMessages__c.contains(expectedLine), 'Expected the error text to name the header, got ' + storedCall.kern__ErrorMessages__c);
	}
}
