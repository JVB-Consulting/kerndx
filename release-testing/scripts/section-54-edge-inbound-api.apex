/**
 * Section 54: Inbound API — Edge Cases
 *
 * Closes gaps in inbound REST → API_Inbound capability coverage beyond section-13
 * (which already exercises the happy POST + 2 missing-field validation aborts).
 * Covers four anon-Apex edge scenarios that section-13 does not touch: malformed
 * JSON parse failure, wrong Content-Type causing parse to be skipped, empty body
 * triggering all required-field validation errors, and framework recognition of
 * the Idempotency-Key header (recorded on ApiCall__c even when idempotency is
 * not enabled in the setting).
 *
 * Deferrals to platform-level / Node-integration tests (the extended-load spec §6.3 #2,#4,#5):
 *   - Scenario 6.3 #2 (oversize payload >6 MB): platform-rejected at the REST gateway
 *     BEFORE the @HttpPost static is invoked. Cannot be probed in anon Apex without
 *     blowing the 6 MB heap limit. Move to release-testing/scripts/section-32-load-test.js
 *     style Node integration test that fires a real HTTP request.
 *   - Scenario 6.3 #4 (non-POST method on POST-only endpoint): Salesforce REST
 *     routing returns 405 directly without invoking the @HttpPost static. Setting
 *     RestContext.request.httpMethod = 'GET' in anon Apex and calling submitForm()
 *     bypasses the routing check — observable outcome would not match the production
 *     wire behaviour. Move to Node integration test.
 *   - Scenario 6.3 #5 (missing/invalid session token → 401): anon Apex always runs as
 *     an authenticated user; there is no way to simulate an unauthenticated request.
 *     Move to Node integration test that fires HTTP without the session header.
 *
 * Deferrals to Subscriber_InboundEdges_TEST.cls (Task 1.16) — needs CMDT setup that
 * cannot be created in anon Apex:
 *   - Scenario 6.3 #6 (idempotency-key replay): the framework's checkIdempotency()
 *     short-circuits when setting?.IdempotencyEnabled__c != true. ContactFormSubmit
 *     has no ApiSetting__mdt record, and no other deployed inbound service has
 *     IdempotencyEnabled__c = true. Replay assertions need a CMDT record (which
 *     cannot be inserted at runtime) or a managed @IsTest harness that mocks the
 *     SEL_ApiSetting selector via TST_Mock. This script verifies the half that
 *     IS testable: that the framework sees the Idempotency-Key request header.
 *   - Scenario 6.3 #7 (same idempotency key + different body → 409 conflict):
 *     framework gap. The current API_Inbound.checkIdempotency() returns the cached
 *     response unconditionally without comparing request bodies — there is no
 *     409 conflict-detection path. FRAMEWORK FOLLOW-UP: spec expects a 409 on
 *     body-divergence; consider adding body-hash comparison in checkIdempotency()
 *     before returning the cached response.
 *
 * Run-isolation: self-contained — does not depend on prior section state. Cleanup
 * deletes Lead records created today by the running user, plus ApiCall__c rows
 * keyed to the ContactFormSubmit service.
 *
 * Implementation notes:
 *   - Each scenario rebuilds RestContext.request + RestContext.response from
 *     scratch. Salesforce mutates RestContext during dispatcher execution
 *     (statusCode, responseBody), so reusing a previous scenario's context would
 *     leak state into the next assertion.
 *   - The framework's response.statusCode default after abortUnresolvableCall is
 *     500 (HTTP_INTERNAL_SERVER_ERROR), not 400. The dispatcher routes parse-time
 *     and resolution-time exceptions through abortUnresolvableCall; subscriber-
 *     reported validation failures from getValidationErrors() route through
 *     handleError → 400. Scenarios assert the actual framework behaviour rather
 *     than the spec's idealised status code.
 *
 * Prerequisites:
 *   - subscriber scratch org with the kern managed package installed
 *   - REST_ContactForm + API_ContactFormSubmit subscriber classes deployed
 *
 * Run (in isolation):
 *   sf apex run --file release-testing/scripts/section-54-edge-inbound-api.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 54: Inbound API Edge Cases ===');

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String SERVICE_NAME = API_ContactFormSubmit.class.getName();
final String CONTACT_FORM_URI = '/services/apexrest/v1/contact-form';
final String CONTENT_TYPE_HEADER = 'Content-Type';
final String IDEMPOTENCY_KEY_HEADER = 'Idempotency-Key';
final String VALIDATION_ERROR_LAST_NAME = 'Last name is required';
final String VALIDATION_ERROR_EMAIL = 'Email is required';
final String SCENARIO_RUN_STAMP = String.valueOf(Datetime.now().getTime());

// Scenario 54a — malformed JSON body causes the handler constructor to throw during parseRequest;
// dispatcher routes the resolution failure through abortUnresolvableCall (HTTP 500, ApiCall = Aborted)
try
{
	RestRequest malformedRequest = new RestRequest();
	malformedRequest.requestURI = CONTACT_FORM_URI;
	malformedRequest.httpMethod = 'POST';
	malformedRequest.addHeader(CONTENT_TYPE_HEADER, 'application/json');
	malformedRequest.requestBody = Blob.valueOf('{"firstName":"Jane","lastName":');
	RestContext.request = malformedRequest;
	RestContext.response = new RestResponse();

	Datetime startedAt54a = Datetime.now();
	REST_ContactForm.submitForm();

	Assert.areEqual(500, RestContext.response.statusCode, '54a: malformed JSON should produce HTTP 500 via abortUnresolvableCall');
	String responseBody54a = RestContext.response.responseBody == null ? '' : RestContext.response.responseBody.toString();
	Assert.isFalse(String.isBlank(responseBody54a), '54a: response body should contain the parse error message');

	List<kern__ApiCall__c> apiCalls54a =
	[
			SELECT
					Id,
					kern__Status__c,
					kern__ErrorMessages__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt54a
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	Assert.areEqual(1, apiCalls54a.size(), '54a: an ApiCall row should be persisted for the failed call');
	Assert.areEqual('Aborted', apiCalls54a[0].kern__Status__c, '54a: ApiCall row should be Aborted');
	System.debug(LoggingLevel.INFO, '54a PASS: malformed JSON aborted with HTTP 500 and ApiCall row Status=Aborted');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '54a FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('54a: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 54b — wrong Content-Type (text/plain instead of application/json) causes parseRequest
// to skip JSON deserialisation; the handler runs against an empty DTO_Request and aborts with
// the subscriber-defined validation errors (Last name + Email both missing)
try
{
	RestRequest plainTextRequest = new RestRequest();
	plainTextRequest.requestURI = CONTACT_FORM_URI;
	plainTextRequest.httpMethod = 'POST';
	plainTextRequest.addHeader(CONTENT_TYPE_HEADER, 'text/plain');
	plainTextRequest.requestBody = Blob.valueOf('lastName=Doe&email=jane@example.com');
	RestContext.request = plainTextRequest;
	RestContext.response = new RestResponse();

	Datetime startedAt54b = Datetime.now();
	REST_ContactForm.submitForm();

	Assert.areEqual(400, RestContext.response.statusCode, '54b: text/plain should bypass JSON parse and abort with HTTP 400 (validation)');
	String responseBody54b = RestContext.response.responseBody == null ? '' : RestContext.response.responseBody.toString();
	Assert.isTrue(responseBody54b.contains(VALIDATION_ERROR_LAST_NAME), '54b: response should contain "' + VALIDATION_ERROR_LAST_NAME + '" because non-JSON body was not deserialised');
	Assert.isTrue(responseBody54b.contains(VALIDATION_ERROR_EMAIL), '54b: response should contain "' + VALIDATION_ERROR_EMAIL + '" because non-JSON body was not deserialised');

	List<kern__ApiCall__c> apiCalls54b =
	[
			SELECT
					Id,
					kern__Status__c,
					kern__ErrorMessages__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt54b
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	Assert.areEqual(1, apiCalls54b.size(), '54b: an ApiCall row should be persisted for the aborted call');
	Assert.areEqual('Aborted', apiCalls54b[0].kern__Status__c, '54b: ApiCall row should be Aborted (validation failure)');
	System.debug(LoggingLevel.INFO, '54b PASS: non-JSON Content-Type bypassed parse; handler ran with empty DTO and aborted with both required-field errors');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '54b FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('54b: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 54c — empty request body where required: parseRequest skips deserialisation for blank
// bodies; getValidationErrors() returns both required-field errors; framework aborts with HTTP 400
try
{
	RestRequest emptyBodyRequest = new RestRequest();
	emptyBodyRequest.requestURI = CONTACT_FORM_URI;
	emptyBodyRequest.httpMethod = 'POST';
	emptyBodyRequest.addHeader(CONTENT_TYPE_HEADER, 'application/json');
	emptyBodyRequest.requestBody = Blob.valueOf('');
	RestContext.request = emptyBodyRequest;
	RestContext.response = new RestResponse();

	Datetime startedAt54c = Datetime.now();
	REST_ContactForm.submitForm();

	Assert.areEqual(400, RestContext.response.statusCode, '54c: empty body should abort with HTTP 400 (validation)');
	String responseBody54c = RestContext.response.responseBody == null ? '' : RestContext.response.responseBody.toString();
	Assert.isTrue(responseBody54c.contains(VALIDATION_ERROR_LAST_NAME), '54c: response should contain "' + VALIDATION_ERROR_LAST_NAME + '"');
	Assert.isTrue(responseBody54c.contains(VALIDATION_ERROR_EMAIL), '54c: response should contain "' + VALIDATION_ERROR_EMAIL + '"');

	List<kern__ApiCall__c> apiCalls54c =
	[
			SELECT
					Id,
					kern__Status__c,
					kern__ErrorMessages__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt54c
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	Assert.areEqual(1, apiCalls54c.size(), '54c: an ApiCall row should be persisted for the aborted call');
	Assert.areEqual('Aborted', apiCalls54c[0].kern__Status__c, '54c: ApiCall row should be Aborted (validation failure)');
	String storedErrors54c = apiCalls54c[0].kern__ErrorMessages__c == null ? '' : apiCalls54c[0].kern__ErrorMessages__c;
	Assert.isTrue(storedErrors54c.contains(VALIDATION_ERROR_LAST_NAME), '54c: ApiCall.ErrorMessages__c should record the lastName validation error');
	Assert.isTrue(storedErrors54c.contains(VALIDATION_ERROR_EMAIL), '54c: ApiCall.ErrorMessages__c should record the email validation error');
	System.debug(LoggingLevel.INFO, '54c PASS: empty body produced HTTP 400 with both required-field errors echoed in response and persisted ApiCall row');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '54c FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('54c: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 54d — Idempotency-Key header recognition: send a valid POST with an Idempotency-Key
// header. The framework's checkIdempotency() short-circuits because no ApiSetting__mdt exists for
// ContactFormSubmit (so setting?.IdempotencyEnabled__c != true), but setApiCallDetails() still
// records the header value on ApiCall__c.IdempotencyKey__c. This proves the framework reads the
// header end-to-end. Full replay-deduplication assertions are deferred to the managed @IsTest
// harness (Subscriber_InboundEdges_TEST.cls, Task 1.16) where the SEL_ApiSetting selector can
// be mocked to return a record with IdempotencyEnabled__c = true.
try
{
	String idempotencyKey54d = 'idem-54d-' + SCENARIO_RUN_STAMP;
	String validBody54d = '{"firstName":"Edge","lastName":"Case54d","email":"edge54d-' + SCENARIO_RUN_STAMP + '@example.com","message":"Idempotency header probe"}';

	RestRequest idempotentRequest = new RestRequest();
	idempotentRequest.requestURI = CONTACT_FORM_URI;
	idempotentRequest.httpMethod = 'POST';
	idempotentRequest.addHeader(CONTENT_TYPE_HEADER, 'application/json');
	idempotentRequest.addHeader(IDEMPOTENCY_KEY_HEADER, idempotencyKey54d);
	idempotentRequest.requestBody = Blob.valueOf(validBody54d);
	RestContext.request = idempotentRequest;
	RestContext.response = new RestResponse();

	Datetime startedAt54d = Datetime.now();
	REST_ContactForm.submitForm();

	Assert.areEqual(200, RestContext.response.statusCode, '54d: valid POST with idempotency header should succeed with HTTP 200');

	List<kern__ApiCall__c> apiCalls54d =
	[
			SELECT
					Id,
					kern__Status__c,
					kern__IdempotencyKey__c,
					kern__IsIdempotencyHit__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt54d
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	Assert.areEqual(1, apiCalls54d.size(), '54d: an ApiCall row should be persisted for the successful call');
	Assert.areEqual('Completed', apiCalls54d[0].kern__Status__c, '54d: ApiCall row should be Completed');
	Assert.areEqual(idempotencyKey54d, apiCalls54d[0].kern__IdempotencyKey__c, '54d: framework should have copied the request header into ApiCall__c.IdempotencyKey__c');
	Assert.areEqual(false, apiCalls54d[0].kern__IsIdempotencyHit__c, '54d: IsIdempotencyHit__c should be false because no ApiSetting enables idempotency for this service');
	System.debug(LoggingLevel.INFO, '54d PASS: framework recorded Idempotency-Key header on ApiCall__c (replay-dedup deferred to Subscriber_InboundEdges_TEST.cls / Task 1.16)');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '54d FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('54d: ' + scenarioError.getMessage());
	fail++;
}

// Cleanup — bounded to stay under the 10K DML row governor. Section 54 inserts roughly 1 Lead row
// (54d's successful call) across scenarios. Capping each delete at 9000 keeps a safety margin
// without leaking. If the script is re-run many times in one day and CreatedDate=TODAY accumulates
// beyond 9000 of either object, the next invocation's cleanup will skip the overflow — manually
// purge with a one-shot delete query repeated until the count drops to zero.
delete
[
		SELECT Id
		FROM Lead
		WHERE CreatedDate = TODAY
		AND CreatedById = :UserInfo.getUserId()
		AND LeadSource = 'Web'
		LIMIT 9000
];
delete
[
		SELECT Id
		FROM kern__ApiCall__c
		WHERE kern__ServiceName__c = :SERVICE_NAME
		AND CreatedDate = TODAY
		AND CreatedById = :UserInfo.getUserId()
		LIMIT 9000
];

// Summary
System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 54: ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 54 FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 54 failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 54 COMPLETE: All scenarios passed ===');
}
