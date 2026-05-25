// =============================================================================
// Section 27: Multi-Mock Selection — Priority, Pattern Matching, Catch-All
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern__ApiMock__mdt records deployed (7 records for SubscriberCreateAccount + EchoSubscriber)
//   - kern__ApiSetting.SubscriberCreateAccount MockingEnabled__c = true (CMDT state: section27-mock-enabled)
//   - kern__FeatureFlag.MockAllAPIs IsEnabledByDefault__c = true (CMDT state: section27-mock-enabled)
//   - REST_SubscriberApi, API_SubscriberCreateAccount, API_EchoSubscriber deployed
//
// Tests priority-based mock selection for both inbound and outbound API paths.
// When multiple ApiMock__mdt records exist for a service, the lowest Priority__c
// that matches the request body is selected. Inactive mocks are skipped.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-27-mock-selection.apex
// =============================================================================

try
{
	// =========================================================================
	// INBOUND MOCK SELECTION (4 tests)
	// =========================================================================
	// Mocks configured for SubscriberCreateAccount:
	//   Inactive  — Priority 1, pattern "urgent", IsActive=false, status 503
	//   Urgent    — Priority 10, pattern "urgent", status 200
	//   Standard  — Priority 50, pattern "standard", status 201
	//   Default   — Priority 100, no pattern (catch-all), status 202

	// Test 27a: Request body contains "urgent" — Priority 10 mock selected (not inactive Priority 1)
	{
		RestRequest request = new RestRequest();
		request.requestURI = '/services/apexrest/subscriber/accounts';
		request.httpMethod = 'POST';
		request.addHeader('Content-Type', 'application/json');
		request.requestBody = Blob.valueOf('{"accountName":"urgent-order","industry":"Technology"}');

		RestResponse response = new RestResponse();
		RestContext.request = request;
		RestContext.response = response;

		REST_SubscriberApi.createAccount();

		String body = response.responseBody != null ? response.responseBody.toString() : '';
		System.debug('27a Response status: ' + response.statusCode + ', body: ' + body);

		System.assertEquals(200, response.statusCode, '27a FAIL: Urgent mock should return status 200');
		System.assert(body.contains('"mock":"urgent"'), '27a FAIL: Response should contain urgent mock body');
		System.debug('27a PASS: Priority 10 "urgent" mock selected — inactive Priority 1 mock correctly skipped');
	}

	// Test 27b: Request body contains "standard" — Priority 50 mock selected
	{
		RestRequest request = new RestRequest();
		request.requestURI = '/services/apexrest/subscriber/accounts';
		request.httpMethod = 'POST';
		request.addHeader('Content-Type', 'application/json');
		request.requestBody = Blob.valueOf('{"accountName":"standard-order","industry":"Finance"}');

		RestResponse response = new RestResponse();
		RestContext.request = request;
		RestContext.response = response;

		REST_SubscriberApi.createAccount();

		String body = response.responseBody != null ? response.responseBody.toString() : '';
		System.debug('27b Response status: ' + response.statusCode + ', body: ' + body);

		System.assertEquals(201, response.statusCode, '27b FAIL: Standard mock should return status 201');
		System.assert(body.contains('"mock":"standard"'), '27b FAIL: Response should contain standard mock body');
		System.debug('27b PASS: Priority 50 "standard" mock selected by pattern match');
	}

	// Test 27c: Request body has no matching pattern — Catch-all Priority 100 selected
	{
		RestRequest request = new RestRequest();
		request.requestURI = '/services/apexrest/subscriber/accounts';
		request.httpMethod = 'POST';
		request.addHeader('Content-Type', 'application/json');
		request.requestBody = Blob.valueOf('{"accountName":"no-match-order","industry":"Retail"}');

		RestResponse response = new RestResponse();
		RestContext.request = request;
		RestContext.response = response;

		REST_SubscriberApi.createAccount();

		String body = response.responseBody != null ? response.responseBody.toString() : '';
		System.debug('27c Response status: ' + response.statusCode + ', body: ' + body);

		System.assertEquals(202, response.statusCode, '27c FAIL: Catch-all mock should return status 202');
		System.assert(body.contains('"mock":"default"'), '27c FAIL: Response should contain default mock body');
		System.debug('27c PASS: Catch-all Priority 100 mock selected when no pattern matches');
	}

	// Test 27d: Inactive mock with Priority 1 is skipped — proves IsActive__c filtering
	// This is implicitly proven by 27a (status 200 not 503), but we verify explicitly
	{
		RestRequest request = new RestRequest();
		request.requestURI = '/services/apexrest/subscriber/accounts';
		request.httpMethod = 'POST';
		request.addHeader('Content-Type', 'application/json');
		request.requestBody = Blob.valueOf('{"accountName":"urgent-verify","industry":"Technology"}');

		RestResponse response = new RestResponse();
		RestContext.request = request;
		RestContext.response = response;

		REST_SubscriberApi.createAccount();

		System.assertNotEquals(503, response.statusCode, '27d FAIL: Inactive mock (503) should never be selected');
		System.assertEquals(200, response.statusCode, '27d FAIL: Active urgent mock (200) should win over inactive (503)');
		System.debug('27d PASS: Inactive mock with highest priority (1) correctly skipped');
	}

	// =========================================================================
	// OUTBOUND MOCK SELECTION (4 tests)
	// =========================================================================
	// Mocks configured for EchoSubscriber:
	//   Priority  — Priority 10, pattern "priority-test", status 200
	//   Regex     — Priority 50, pattern "order-[0-9]+" (IsRegex), status 201
	//   Default   — Priority 100, no pattern (catch-all), status 202

	// Test 27e: Verify MockAllAPIs feature flag is enabled (prerequisite)
	{
		Boolean isMockEnabled = kern.UTIL_FeatureFlag.isEnabled('MockAllAPIs');
		System.assert(isMockEnabled, '27e FAIL: MockAllAPIs feature flag must be enabled for outbound mock tests');
		System.debug('27e PASS: MockAllAPIs feature flag is enabled');
	}

	// Test 27f: Invoke EchoSubscriber with no matching body — catch-all mock selected
	{
		kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.withParameter('message', 'hello-world')
				.invoke();

		List<kern__ApiCall__c> calls =
		[
				SELECT kern__Response__c,
						kern__StatusCode__c,
						kern__IsMockedResponse__c
				FROM kern__ApiCall__c
				WHERE kern__ServiceName__c = 'API_EchoSubscriber'
				ORDER BY CreatedDate DESC
				LIMIT 1
		];

		System.assert(!calls.isEmpty(), '27f FAIL: ApiCall__c should be created for outbound mock call');
		System.debug('27f Response: ' + calls[0].kern__Response__c + ', Status: ' + calls[0].kern__StatusCode__c);

		System.assert(calls[0].kern__IsMockedResponse__c, '27f FAIL: IsMockedResponse__c should be true');
		System.assert(calls[0].kern__Response__c != null && calls[0].kern__Response__c.contains('"echo-default"'),
				'27f FAIL: Response should contain catch-all mock body');
		System.debug('27f PASS: Outbound catch-all mock selected, ApiCall__c recorded with IsMockedResponse=true');
	}

	// Test 27g: Verify catch-all mock status code
	{
		List<kern__ApiCall__c> calls =
		[
				SELECT kern__StatusCode__c
				FROM kern__ApiCall__c
				WHERE kern__ServiceName__c = 'API_EchoSubscriber'
				ORDER BY CreatedDate DESC
				LIMIT 1
		];

		System.assert(!calls.isEmpty(), '27g FAIL: ApiCall__c should exist from previous test');
		System.assertEquals('202', calls[0].kern__StatusCode__c, '27g FAIL: StatusCode should be 202 from catch-all mock');
		System.debug('27g PASS: StatusCode__c matches expected catch-all mock (202)');
	}

	// Test 27h: Verify no Account was created by inbound mocks (mocking bypasses handler logic)
	{
		List<Account> accounts =
		[
				SELECT Id
				FROM Account
				WHERE Name IN ('urgent-order', 'standard-order', 'no-match-order', 'urgent-verify')
				AND CreatedDate = TODAY
		];
		System.assert(accounts.isEmpty(), '27h FAIL: Mocked inbound calls should NOT create Account records');
		System.debug('27h PASS: Inbound mocking correctly bypassed handler logic — no Accounts created');
	}

	System.debug('=== Section 27 COMPLETE: All mock selection tests passed ===');
}
finally
{
	List<kern__ApiCall__c> apiCalls =
	[
			SELECT Id
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c IN ('API_SubscriberCreateAccount', 'API_EchoSubscriber')
	];
	if(!apiCalls.isEmpty())
	{
		delete apiCalls;
		System.debug('Cleanup: Deleted ' + apiCalls.size() + ' test ApiCall record(s)');
	}
}
