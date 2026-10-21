// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Proves, on a subscriber org and through the global API only, what an inbound service writes when a request
 * fails. Every request goes to the REST endpoint REST_SubscriberApi.createAccount(), as a caller's request would. When
 * the service has Log Issues on, a failed request leaves one Open API issue linked to the call of the request, and the
 * call keeps the body it received. When the caller sends the same body again with the same Idempotency-Key and the
 * request now succeeds, the new call links to the failed call and the issue is marked Resolved.
 *
 * @see REST_SubscriberApi
 * @see API_SubscriberCreateAccount
 * @see kern.SEL_ApiIssue
 * @see kern.SEL_ApiCall
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class SubscriberInboundIssue_TEST
{
	/**
	 * @description The service the endpoint sends each request to. The calls and issues of the request carry this name.
	 */
	private static final String SERVICE_NAME = API_SubscriberCreateAccount.class.getName();

	/**
	 * @description The path a caller sends a request to. It matches the endpoint path of the setting each test registers.
	 */
	private static final String REQUEST_URI = '/services/apexrest/subscriber/accounts';

	/**
	 * @description The endpoint path of the setting each test registers.
	 */
	private static final String ENDPOINT_PATH = '/subscriber/accounts';

	/**
	 * @description The routing priority of the setting each test registers. Any value works, because each test registers
	 * one setting.
	 */
	private static final Integer ROUTE_PRIORITY = 100;

	/**
	 * @description The HTTP method of each request.
	 */
	private static final String HTTP_METHOD_POST = 'POST';

	/**
	 * @description The name of the header that carries the content type of the body.
	 */
	private static final String HEADER_CONTENT_TYPE = 'Content-Type';

	/**
	 * @description The content type of each body: JSON, the only body the service reads.
	 */
	private static final String CONTENT_TYPE_JSON = 'application/json';

	/**
	 * @description The name of the header that carries the Idempotency-Key, the value a caller sends again with each retry
	 * of one request.
	 */
	private static final String HEADER_IDEMPOTENCY_KEY = 'Idempotency-Key';

	/**
	 * @description The industry each request sends. The service requires one.
	 */
	private static final String INDUSTRY = 'Technology';

	/**
	 * @description A phone number short enough for the Account field. The subscriber org's Account rule asks for a phone or
	 * a website, so each request sends one.
	 */
	private static final String VALID_PHONE = '555-0100';

	/**
	 * @description The status a request answers with when the service refuses it before it runs.
	 */
	private static final Integer HTTP_BAD_REQUEST = 400;

	/**
	 * @description The status a request answers with when the records it tried to save could not be saved.
	 */
	private static final Integer HTTP_INTERNAL_SERVER_ERROR = 500;

	/**
	 * @description The status a request answers with when it succeeds.
	 */
	private static final Integer HTTP_OK = 200;

	/**
	 * @description The status of a call whose request failed while it ran.
	 */
	private static final String STATUS_FAILED = 'Failed';

	/**
	 * @description The status of a call whose request was refused before it ran.
	 */
	private static final String STATUS_ABORTED = 'Aborted';

	/**
	 * @description The status of a call whose request succeeded.
	 */
	private static final String STATUS_COMPLETED = 'Completed';

	/**
	 * @description The status of an issue nobody has dealt with yet.
	 */
	private static final String STATUS_OPEN = 'Open';

	/**
	 * @description The status of an issue whose request has since succeeded.
	 */
	private static final String STATUS_RESOLVED = 'Resolved';

	/**
	 * @description The direction of a request that an outside system sent to the org.
	 */
	private static final String DIRECTION_INBOUND = 'Inbound';

	/**
	 * @description A stored time keeps whole seconds, so a time read back is compared with a bound one second earlier than
	 * the time the test took before the request.
	 */
	private static final Integer ONE_SECOND_TOLERANCE = 1;

	/**
	 * @description A request whose phone number is longer than the Account field cannot save its Account, so the request
	 * fails with status 500. The service has Log Issues on, so the failure leaves one Open inbound issue linked to the
	 * Failed call. The call keeps the body it received, and the issue keeps no copy of it.
	 */
	@IsTest
	private static void shouldLeaveOneOpenIssueLinkedToTheFailedCall()
	{
		registerSetting(true);
		Integer phoneFieldLength = kern.UTIL_SObjectDescribe.getCachedFieldDescribe(Account.Phone).getLength();
		String body = buildBody(kern.UTIL_Random.randomNumeric(phoneFieldLength + 1));
		setupRequest(body, null);

		Test.startTest();
		REST_SubscriberApi.createAccount();
		Test.stopTest();

		Assert.areEqual(HTTP_INTERNAL_SERVER_ERROR, RestContext.response.statusCode, 'Expected status 500 when the Account cannot be saved');
		kern__ApiCall__c failedCall = findOneCall();
		Assert.areEqual(STATUS_FAILED, failedCall.kern__Status__c, 'Expected the call to end Failed, got ' + failedCall.kern__Status__c);
		Assert.areEqual(body, failedCall.kern__Request__c, 'Expected the call to keep the body it received');
		kern__ApiIssue__c issue = findOneIssue();
		Assert.areEqual(STATUS_OPEN, issue.kern__Status__c, 'Expected the issue to be Open, got ' + issue.kern__Status__c);
		Assert.areEqual(failedCall.Id, issue.kern__ApiCall__c, 'Expected the issue to link to the failed call');
		Assert.areEqual(DIRECTION_INBOUND, issue.kern__Direction__c, 'Expected an inbound issue, got ' + issue.kern__Direction__c);
		Assert.isNull(issue.kern__RequestBody__c, 'Expected the issue to keep no copy of the body: the call holds it');
	}

	/**
	 * @description A request sent with an Idempotency-Key while the service is not active is refused with status 400 and
	 * leaves one Open issue. Once the service is active again, the caller sends the same body with the same key. The retry
	 * succeeds, its call links to the refused call, and the issue of the refused call is marked Resolved with the time it
	 * was resolved.
	 */
	@IsTest
	private static void shouldLinkAndResolveWhenTheCallerRetriesWithTheSameKey()
	{
		registerSetting(false);
		String body = buildBody(VALID_PHONE);
		String idempotencyKey = kern.UTIL_Random.randomUUID();
		setupRequest(body, idempotencyKey);
		REST_SubscriberApi.createAccount();
		Assert.areEqual(HTTP_BAD_REQUEST, RestContext.response.statusCode, 'Expected status 400 while the service is not active');
		kern__ApiCall__c refusedCall = findOneCall();
		Assert.areEqual(STATUS_ABORTED, refusedCall.kern__Status__c, 'Expected the refused call to end Aborted, got ' + refusedCall.kern__Status__c);
		kern__ApiIssue__c openIssue = findOneIssue();
		Assert.areEqual(refusedCall.Id, openIssue.kern__ApiCall__c, 'Expected the issue to link to the refused call');
		kern.TST_Mock.clear(kern__ApiSetting__mdt.SObjectType);
		registerSetting(true);
		Datetime resolvedAfter = Datetime.now().addSeconds(-ONE_SECOND_TOLERANCE);
		setupRequest(body, idempotencyKey);

		Test.startTest();
		REST_SubscriberApi.createAccount();
		Test.stopTest();

		Assert.areEqual(HTTP_OK, RestContext.response.statusCode, 'Expected status 200 for the retry once the service is active');
		kern__ApiCall__c retryCall = findCallOtherThan(refusedCall.Id);
		Assert.areEqual(STATUS_COMPLETED, retryCall.kern__Status__c, 'Expected the retry to complete, got ' + retryCall.kern__Status__c);
		Assert.areEqual(refusedCall.Id, retryCall.kern__PreviousAttempt__c, 'Expected the retry to link to the refused call');
		kern__ApiIssue__c resolvedIssue = findOneIssue();
		Assert.areEqual(openIssue.Id, resolvedIssue.Id, 'Expected the retry to write no issue of its own');
		Assert.areEqual(STATUS_RESOLVED, resolvedIssue.kern__Status__c, 'Expected the issue of the refused call to be Resolved');
		Assert.isTrue(resolvedIssue.kern__ResolvedDate__c >= resolvedAfter, 'Expected the issue to record when it was resolved, got '
				+ resolvedIssue.kern__ResolvedDate__c);
	}

	/**
	 * @description Registers the setting of the service through the test mock, routed to the endpoint path, with Log
	 * Issues, Idempotency Enabled and Resolve Issues on.
	 *
	 * @param isActive Whether the service accepts requests. A service that is not active refuses each request before it
	 * runs.
	 */
	private static void registerSetting(Boolean isActive)
	{
		kern.TST_Factory.newInboundApiSetting(SERVICE_NAME, ENDPOINT_PATH, ROUTE_PRIORITY, new Map<SObjectField, Object>
		{
				kern__ApiSetting__mdt.kern__IdempotencyEnabled__c => true,
				kern__ApiSetting__mdt.kern__IsActive__c => isActive,
				kern__ApiSetting__mdt.kern__LogIssues__c => true,
				kern__ApiSetting__mdt.kern__ResolveIssues__c => true
		});
	}

	/**
	 * @description Sets up a POST request to the endpoint with a JSON body and, when given, an Idempotency-Key header.
	 *
	 * @param body The body to send.
	 * @param idempotencyKey The key to send, or null to send none.
	 */
	private static void setupRequest(String body, String idempotencyKey)
	{
		RestRequest incomingRequest = new RestRequest();
		incomingRequest.requestURI = REQUEST_URI;
		incomingRequest.httpMethod = HTTP_METHOD_POST;
		incomingRequest.addHeader(HEADER_CONTENT_TYPE, CONTENT_TYPE_JSON);
		if(idempotencyKey != null)
		{
			incomingRequest.addHeader(HEADER_IDEMPOTENCY_KEY, idempotencyKey);
		}
		incomingRequest.requestBody = Blob.valueOf(body);
		RestContext.request = incomingRequest;
		RestContext.response = new RestResponse();
	}

	/**
	 * @description Builds the JSON body of a request that creates one Account with a random name.
	 *
	 * @param phone The phone number the body sends.
	 *
	 * @return The body.
	 */
	private static String buildBody(String phone)
	{
		return JSON.serialize(new Map<String, Object>
		{
				'accountName' => kern.UTIL_Random.randomName(),
				'industry' => INDUSTRY,
				'phone' => phone
		});
	}

	/**
	 * @description Reads the one call the service has so far.
	 *
	 * @return The call.
	 */
	private static kern__ApiCall__c findOneCall()
	{
		List<kern__ApiCall__c> calls = new kern.SEL_ApiCall().findByServiceName(SERVICE_NAME);
		Assert.areEqual(1, calls.size(), 'Expected one call for the request, got ' + calls.size());
		return calls.iterator().next();
	}

	/**
	 * @description Reads the two calls the service has and returns the one that is not the given call.
	 *
	 * @param knownCallId The call already known.
	 *
	 * @return The other call.
	 */
	private static kern__ApiCall__c findCallOtherThan(Id knownCallId)
	{
		List<kern__ApiCall__c> calls = new kern.SEL_ApiCall().findByServiceName(SERVICE_NAME);
		Assert.areEqual(2, calls.size(), 'Expected two calls, the refused one and the retry, got ' + calls.size());
		kern__ApiCall__c otherCall;
		for(kern__ApiCall__c apiCall : calls)
		{
			otherCall = apiCall.Id == knownCallId ? otherCall : apiCall;
		}
		return otherCall;
	}

	/**
	 * @description Reads the one issue the test has so far.
	 *
	 * @return The issue.
	 */
	private static kern__ApiIssue__c findOneIssue()
	{
		List<kern__ApiIssue__c> issues = new kern.SEL_ApiIssue().getAll();
		Assert.areEqual(1, issues.size(), 'Expected one issue, got ' + issues.size());
		return issues.iterator().next();
	}
}
