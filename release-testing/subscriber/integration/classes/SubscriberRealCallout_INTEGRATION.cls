// SPDX-License-Identifier: Apache-2.0
// The static analyser's Apex parser predates the IntegrationTest annotation and reports it as non-existent.
/**
 * @description Proves that a callout made through the framework from inside an Apex integration test reaches the
 * real endpoint, and that a mock registered through the mock factory still takes precedence there. Apex integration
 * tests are a Developer Preview: the class compiles only in a scratch org created with the ApexIntegrationTests
 * feature, so it lives apart from the other subscriber artifacts and the release runbook deploys it on its own,
 * together with the named credential it generates for the org. The endpoint is the org itself. It also runs a
 * handler with a canned answer and no credential through the fluent client's delegation entry point and expects the
 * real answer.
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date September 2026, October 2026
 */
@SuppressWarnings('PMD.AvoidNonExistentAnnotations')
@IntegrationTest
private class SubscriberRealCallout_INTEGRATION
{
	/**
	 * @description The named credential the runbook generates for the org, pointing at the org's own domain.
	 */
	private static final String ENDPOINT_CONNECTION_NAME = 'SubscriberIntegrationEndpoint';

	/**
	 * @description The REST API's version list, which answers with no session.
	 */
	private static final String ENDPOINT_PATH = '/services/data/';

	/**
	 * @description A fragment every entry of the version list carries, so the body is provably the endpoint's own.
	 */
	private static final String ENDPOINT_ANSWER_MARKER = '/services/data/v';

	/**
	 * @description The body the framework's generic handler answers when it mocks a callout in a unit test.
	 */
	private static final String DEFAULT_MOCK_BODY = '{"success":true}';

	/**
	 * @description The body a registered mock answers.
	 */
	private static final String MOCK_BODY = '{"answer":"mock"}';

	/**
	 * @description A status no real endpoint returns, so a mocked answer is unmistakable.
	 */
	private static final Integer MOCK_STATUS = 299;

	/**
	 * @description The status the version list answers.
	 */
	private static final Integer HTTP_OK = 200;

	/**
	 * @description With no mock registered, the callout reaches the endpoint and answers the version list.
	 */
	@IntegrationTest
	private static void calloutReachesTheEndpointWhenNoMockIsRegistered()
	{
		HttpResponse response = kern.UTIL_HttpClient.get(ENDPOINT_CONNECTION_NAME, ENDPOINT_PATH).send();

		Assert.areEqual(HTTP_OK, response.getStatusCode(), 'The callout must reach the endpoint');
		Assert.areNotEqual(DEFAULT_MOCK_BODY, response.getBody(), 'The framework must not answer its default mock body inside an integration test');
		Assert.isTrue(response.getBody().contains(ENDPOINT_ANSWER_MARKER), 'The body must be the endpoint\'s own answer, the list of API versions');
	}

	/**
	 * @description A mock registered through the mock factory answers instead of the endpoint.
	 */
	@IntegrationTest
	private static void registeredMockKeepsPrecedence()
	{
		kern.API_MockFactory.forService(ENDPOINT_CONNECTION_NAME).body(MOCK_BODY).statusCode(MOCK_STATUS).register();

		HttpResponse response = kern.UTIL_HttpClient.get(ENDPOINT_CONNECTION_NAME, ENDPOINT_PATH).send();

		Assert.areEqual(MOCK_STATUS, response.getStatusCode(), 'A registered mock must answer inside an integration test');
		Assert.areEqual(MOCK_BODY, response.getBody(), 'The registered mock body must be answered');
	}

	/**
	 * @description A handler with a canned answer and no credential, run through the fluent client's delegation
	 * entry point, makes its real call inside an integration test.
	 */
	@IntegrationTest
	private static void delegatedHandlerReachesTheEndpointWithoutACredential()
	{
		kern.API_Outbound handler = kern.UTIL_HttpClient.useHandler(API_VersionList.class).invoke();

		Assert.isFalse(handler.result.isMocked, 'The canned answer must not stand in outside a unit test');
		Assert.areEqual(String.valueOf(HTTP_OK), handler.result.statusCode, 'The delegated callout must reach the endpoint');
		Assert.areNotEqual(API_VersionList.CANNED_BODY, handler.result.responseBody, 'The handler\'s canned answer must not be the body');
		Assert.isTrue(handler.result.responseBody.contains(ENDPOINT_ANSWER_MARKER), 'The body must be the endpoint\'s own answer, the list of API versions');
	}
}
