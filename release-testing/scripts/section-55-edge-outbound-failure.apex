/**
 * Section 55: Outbound API — Failure Composition Edge Cases
 *
 * Closes gaps in outbound retry/failure composition coverage beyond section-31
 * (which already exercises basic 500/200 mocks, retry config propagation,
 * failure-rate injection, and ApiIssue logging on a single delegation call).
 * Covers the failure-classification matrix (4xx 400/404/422 + 5xx 500/502/503),
 * the server error on a POST without an idempotency key that is not sent again,
 * retry queueing on 503 with explicit backoff, graceful handling of malformed
 * status codes, statistical validation of failureRate over a 20-call sample,
 * and the RETRY_THEN_LOG composition path — all through delegation mode via
 * API_EchoSubscriber, whose calls are POSTs without an idempotency key.
 *
 * Deferrals to managed @IsTest harness or framework follow-up:
 *   - Real timeout (spec scenario 3): covered by SubscriberOutboundRetry_TEST
 *     (shouldRetryATransportFailureOnAGet, shouldFailAnUnkeyedPostAtOnceWhenItGotNoAnswer)
 *     and by section 84's live step.
 *   - Malformed response body / parse error (spec scenario 5): covered by
 *     SubscriberOutboundRetry_TEST (shouldFailAtOnceWhenTheHandlerRefusesTheRetry)
 *     and by section 84's live step.
 *   - Retry waits backoff timing (spec scenario 7): UTIL_HttpClient's synchronous
 *     retry loop in DefaultOutboundHandler.sendRequest() iterates without any
 *     sleep/wait between attempts (Apex has no sleep primitive). Backoff is
 *     authored as data on apiCall.NextRetry__c for the async scheduler to
 *     respect, never as wall-clock-delaying behaviour in the sync path. Wall-
 *     clock backoff assertions belong in a Queueable-aware test (start/stopTest
 *     wrapping the async retry dequeue), not in anon Apex.
 *   - LOG_FAILURE skip-retry differentiation (spec scenario 8): the FailureAction
 *     enum has two members. LOG_FAILURE additionally sets KEY_SKIP_RETRY=true to
 *     short-circuit the synchronous retry loop. That loop only runs in ad-hoc
 *     mode (DefaultOutboundHandler.sendRequest), NOT in delegation mode where the
 *     subscriber handler inherits the single-shot API_Outbound.sendRequest. So
 *     LOG_FAILURE and RETRY_THEN_LOG are observationally identical in delegation
 *     mode — both toggle LogIssues=true; both queue NextRetry__c when MaxRetries>0.
 *     Scenario 55i exercises RETRY_THEN_LOG composition (the path that IS testable
 *     end-to-end). LOG_FAILURE differentiation belongs in a managed @IsTest that
 *     runs ad-hoc (not delegation) and inspects the retry-loop short-circuit.
 *
 * Run-isolation: self-contained — does not depend on prior section state.
 * Cleanup deletes ApiCall__c + ApiIssue__c rows created today by the running
 * user keyed to the API_EchoSubscriber service and proves by query that none is
 * left. The log entries this run writes land after it ends, so
 * section-55-edge-outbound-failure-cleanup.apex, run 30 seconds later, deletes
 * them and proves it.
 *
 * Implementation notes:
 *   - Each scenario re-registers the mock immediately before invocation;
 *     API_MockFactory keeps mocks in a per-transaction MEMORY_REGISTRY that
 *     persists across calls until clearMocks() is invoked.
 *   - The scheduled retry reads the status code in delegation mode as in ad-hoc
 *     mode: only a status in the handler's getRetryableStatusCodes() (by default
 *     408, 425, 429, 500, 502, 503, 504) is scheduled, so withRetry(N) on a 4xx
 *     call schedules nothing. A 500, 502 or 504 to a POST or PATCH sent without
 *     an idempotency key is not sent again either: the external system may have
 *     processed it, so the call ends Failed with the ServerErrorNotRepeated line
 *     and its issue is marked External System May Have Acted. 408, 425, 429 and
 *     503 say the request was not processed, so they are scheduled for any method.
 *   - For delegation mode, the subscriber handler inherits API_Outbound's
 *     single-shot sendRequest(), not the looping DefaultOutboundHandler version.
 *     When MaxRetries > 0 and the call fails, SEL_ApiCall.updateNextRetryInfo
 *     pre-increments Retries__c by 1 (it represents "scheduled" not "executed")
 *     and sets Status__c=Retry. With MaxRetries=0, Retries stays 0 and Status=
 *     Failed. NextRetry__c is only populated when backoffSeconds > 0, so
 *     scenarios 55e, 55f and 55i use the (maxRetries, backoffSeconds) overload.
 *   - Statistical scenario 55h uses 20 calls capped by the 150-statement DML
 *     governor (mocks bypass the 100-callout governor, so callouts aren't the
 *     bottleneck). Larger sample sizes belong in a managed @IsTest where each
 *     @IsTest method gets a fresh governor budget via Test.startTest().
 *
 * Prerequisites:
 *   - subscriber scratch org with the kern managed package installed
 *   - API_EchoSubscriber subscriber class deployed
 *   - kern__ApiSetting.EchoSubscriber CMDT record deployed (LogIssues=true,
 *     MaxRetryCount=null by default)
 *   - The MockAllAPIs feature flag on (fixture cmdt-states/mock-all-apis-enabled;
 *     phase 2 deploys it around this section and restores mock-all-apis-disabled
 *     after). Each scenario registers its answer through kern.API_MockFactory;
 *     outside a unit test a registered answer stands in for the callout only while
 *     MockAllAPIs is on, otherwise the handler makes its real call.
 *
 * Run (in isolation):
 *   sf apex run --file release-testing/scripts/section-55-edge-outbound-failure.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 55: Outbound API Failure Composition Edge Cases ===');

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();
kern.API_MockFactory.clearMocks();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String SERVICE_NAME = API_EchoSubscriber.class.getName();
final String STATUS_FAILED = 'Failed';
final String SCENARIO_RUN_STAMP = String.valueOf(Datetime.now().getTime());

// Scenario 55a — 4xx (400 Bad Request) NO retry config: framework persists with that status
// code, ApiIssue created (LogIssues=true on EchoSubscriber CMDT), Retries__c stays 0 because
// no retry was scheduled (MaxRetries=0). ApiIssue is queried by ServiceName + CreatedDate
// window, not by ApiCall__c FK, because the framework currently creates ApiIssue rows without
// back-populating the lookup (matches section-31 31f's pattern). The framework emits 2 issue
// rows per failed call (one structural, one logging), so the assertion is "at least 1" rather
// than exactly 1.
try
{
	kern.API_MockFactory.forService(SERVICE_NAME).body('{"error":"bad request"}').statusCode(400).register();
	Datetime startedAt55a = Datetime.now();
	kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
			.withParameter('message', 'fourxx-400-' + SCENARIO_RUN_STAMP)
			.invoke();

	List<kern__ApiCall__c> apiCalls55a =
	[
			SELECT
					Id,
					kern__StatusCode__c,
					kern__Status__c,
					kern__Retries__c,
					kern__MaxRetries__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt55a
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	Assert.areEqual(1, apiCalls55a.size(), '55a: an ApiCall row should be persisted for the 400 response');
	Assert.areEqual('400', apiCalls55a[0].kern__StatusCode__c, '55a: ApiCall.StatusCode__c should record HTTP 400');
	Assert.areEqual(STATUS_FAILED, apiCalls55a[0].kern__Status__c, '55a: ApiCall.Status__c should be Failed');
	Assert.areEqual(0, (apiCalls55a[0].kern__Retries__c ?? 0).intValue(), '55a: Retries__c should be 0 (no retry config)');

	Integer apiIssueCount55a =
	[
			SELECT COUNT()
			FROM kern__ApiIssue__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt55a
	];
	Assert.isTrue(apiIssueCount55a >= 1, '55a: at least one ApiIssue row should be created (LogIssues=true) for the 400 failure, got ' + apiIssueCount55a);
	System.debug(LoggingLevel.INFO, '55a PASS: 400 response persisted with StatusCode=400, Status=Failed, Retries=0, ' + apiIssueCount55a + ' ApiIssue(s) created');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '55a FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('55a: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 55b — 4xx (404 Not Found): same classification path as 55a, asserting StatusCode value
// is faithfully preserved (no normalisation to 500 or success)
try
{
	kern.API_MockFactory.forService(SERVICE_NAME).body('{"error":"not found"}').statusCode(404).register();
	Datetime startedAt55b = Datetime.now();
	kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
			.withParameter('message', 'fourxx-404-' + SCENARIO_RUN_STAMP)
			.invoke();

	List<kern__ApiCall__c> apiCalls55b =
	[
			SELECT
					Id,
					kern__StatusCode__c,
					kern__Status__c,
					kern__Retries__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt55b
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	Assert.areEqual(1, apiCalls55b.size(), '55b: an ApiCall row should be persisted for the 404 response');
	Assert.areEqual('404', apiCalls55b[0].kern__StatusCode__c, '55b: ApiCall.StatusCode__c should record HTTP 404');
	Assert.areEqual(STATUS_FAILED, apiCalls55b[0].kern__Status__c, '55b: ApiCall.Status__c should be Failed');
	Assert.areEqual(0, (apiCalls55b[0].kern__Retries__c ?? 0).intValue(), '55b: Retries__c should be 0');
	Integer apiIssueCount55b =
	[
			SELECT COUNT()
			FROM kern__ApiIssue__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt55b
	];
	Assert.isTrue(apiIssueCount55b >= 1, '55b: at least one ApiIssue row should be created for the 404 failure, got ' + apiIssueCount55b);
	System.debug(LoggingLevel.INFO, '55b PASS: 404 response persisted with StatusCode=404, Status=Failed, ' + apiIssueCount55b + ' ApiIssue(s) created');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '55b FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('55b: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 55c — 4xx (422 Unprocessable Entity): rounds out the 4xx triplet (400/404/422)
// confirming the framework treats every 4xx the same regardless of semantic
try
{
	kern.API_MockFactory.forService(SERVICE_NAME).body('{"error":"unprocessable"}').statusCode(422).register();
	Datetime startedAt55c = Datetime.now();
	kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
			.withParameter('message', 'fourxx-422-' + SCENARIO_RUN_STAMP)
			.invoke();

	List<kern__ApiCall__c> apiCalls55c =
	[
			SELECT
					Id,
					kern__StatusCode__c,
					kern__Status__c,
					kern__Retries__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt55c
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	Assert.areEqual(1, apiCalls55c.size(), '55c: an ApiCall row should be persisted for the 422 response');
	Assert.areEqual('422', apiCalls55c[0].kern__StatusCode__c, '55c: ApiCall.StatusCode__c should record HTTP 422');
	Assert.areEqual(STATUS_FAILED, apiCalls55c[0].kern__Status__c, '55c: ApiCall.Status__c should be Failed');
	Integer apiIssueCount55c =
	[
			SELECT COUNT()
			FROM kern__ApiIssue__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt55c
	];
	Assert.isTrue(apiIssueCount55c >= 1, '55c: at least one ApiIssue row should be created for the 422 failure, got ' + apiIssueCount55c);
	System.debug(LoggingLevel.INFO, '55c PASS: 422 response persisted with StatusCode=422, Status=Failed, ' + apiIssueCount55c + ' ApiIssue(s) created');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '55c FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('55c: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 55d — 5xx (500 Internal Server Error) NO retry config: ApiCall persists with that
// status code, ApiIssue created, NextRetry stays null. Confirms 5xx is treated identically to
// 4xx in absence of withRetry() — the difference only surfaces when MaxRetries > 0
try
{
	kern.API_MockFactory.forService(SERVICE_NAME).body('{"error":"server error"}').statusCode(500).register();
	Datetime startedAt55d = Datetime.now();
	kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
			.withParameter('message', 'fivexx-500-' + SCENARIO_RUN_STAMP)
			.invoke();

	List<kern__ApiCall__c> apiCalls55d =
	[
			SELECT
					Id,
					kern__StatusCode__c,
					kern__Status__c,
					kern__MaxRetries__c,
					kern__NextRetry__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt55d
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	Assert.areEqual(1, apiCalls55d.size(), '55d: an ApiCall row should be persisted for the 500 response');
	Assert.areEqual('500', apiCalls55d[0].kern__StatusCode__c, '55d: ApiCall.StatusCode__c should record HTTP 500');
	Assert.areEqual(STATUS_FAILED, apiCalls55d[0].kern__Status__c, '55d: ApiCall.Status__c should be Failed');
	Assert.areEqual(0, (apiCalls55d[0].kern__MaxRetries__c ?? 0).intValue(), '55d: MaxRetries__c should be 0 (no retry config)');
	Assert.isNull(apiCalls55d[0].kern__NextRetry__c, '55d: NextRetry__c should be null when MaxRetries=0');

	Integer apiIssueCount55d =
	[
			SELECT COUNT()
			FROM kern__ApiIssue__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt55d
	];
	Assert.isTrue(apiIssueCount55d >= 1, '55d: at least one ApiIssue row should be created for the 500 failure, got ' + apiIssueCount55d);
	System.debug(LoggingLevel.INFO, '55d PASS: 500 response persisted with StatusCode=500, MaxRetries=0, NextRetry__c null, ' + apiIssueCount55d + ' ApiIssue(s) created');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '55d FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('55d: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 55e — 5xx (502 Bad Gateway) WITH withRetry(2, 5) on a POST sent without an
// idempotency key: the external system may have processed the request, so it is not sent again
// although budget and a wait were given. MaxRetries__c is stamped to 2, but the call ends Failed
// with no NextRetry__c, no retry counted, the ServerErrorNotRepeated line in its errors, and an
// issue marked External System May Have Acted.
try
{
	kern.API_MockFactory.forService(SERVICE_NAME).body('{"error":"bad gateway"}').statusCode(502).register();
	Datetime startedAt55e = Datetime.now();
	Set<Id> issueIdsBefore55e = new Map<Id, kern__ApiIssue__c>([SELECT Id FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :SERVICE_NAME]).keySet();
	kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
			.withRetry(2, 5)
			.withParameter('message', 'fivexx-502-retry-' + SCENARIO_RUN_STAMP)
			.invoke();

	List<kern__ApiCall__c> apiCalls55e =
	[
			SELECT
					Id,
					kern__StatusCode__c,
					kern__Status__c,
					kern__Retries__c,
					kern__MaxRetries__c,
					kern__NextRetry__c,
					kern__ErrorMessages__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt55e
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	// The issue is told apart by Id, not by CreatedDate: a created date keeps whole seconds, so an
	// earlier scenario's issue saved in the same second would match a time filter too.
	List<kern__ApiIssue__c> apiIssues55e =
	[
			SELECT kern__ExternalSystemMayHaveActed__c
			FROM kern__ApiIssue__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND Id NOT IN :issueIdsBefore55e
	];
	String notRepeatedLine55e = String.format(System.Label.kern.OutboundCall_ServerErrorNotRepeated, new List<Object> {SERVICE_NAME, 502});
	Assert.areEqual(1, apiCalls55e.size(), '55e: an ApiCall row should be persisted for the 502 response');
	Assert.areEqual('502', apiCalls55e[0].kern__StatusCode__c, '55e: ApiCall.StatusCode__c should record HTTP 502');
	Assert.areEqual(STATUS_FAILED, apiCalls55e[0].kern__Status__c, '55e: a 502 to a POST without an idempotency key should end Failed, not Retry');
	Assert.areEqual(0, (apiCalls55e[0].kern__Retries__c ?? 0).intValue(), '55e: Retries__c should be 0 (the request is not sent again)');
	Assert.areEqual(2, (apiCalls55e[0].kern__MaxRetries__c ?? 0).intValue(), '55e: MaxRetries__c should be 2 (from withRetry(2, 5))');
	Assert.isNull(apiCalls55e[0].kern__NextRetry__c, '55e: NextRetry__c should stay empty (nothing is scheduled)');
	Assert.isTrue(apiCalls55e[0].kern__ErrorMessages__c?.contains(notRepeatedLine55e) == true,
			'55e: the errors should carry the ServerErrorNotRepeated line, got ' + apiCalls55e[0].kern__ErrorMessages__c);
	Assert.isFalse(apiIssues55e.isEmpty(), '55e: an ApiIssue row should be created (LogIssues=true)');
	for(kern__ApiIssue__c issue55e : apiIssues55e)
	{
		Assert.isTrue(issue55e.kern__ExternalSystemMayHaveActed__c, '55e: the issue should be marked External System May Have Acted');
	}
	System.debug(LoggingLevel.INFO,
			'55e PASS: 502 with withRetry(2, 5) on a POST without a key → Status=Failed, no NextRetry__c, Retries=0, ServerErrorNotRepeated line, issue marked');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '55e FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('55e: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 55f — 5xx (503 Service Unavailable) WITH withRetry(2, 5): same retry-queueing pattern
// as 55e but with a different status to round out the 500/502/503 triplet
try
{
	kern.API_MockFactory.forService(SERVICE_NAME).body('{"error":"unavailable"}').statusCode(503).register();
	Datetime startedAt55f = Datetime.now();
	kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
			.withRetry(2, 5)
			.withParameter('message', 'fivexx-503-retry-' + SCENARIO_RUN_STAMP)
			.invoke();

	List<kern__ApiCall__c> apiCalls55f =
	[
			SELECT
					Id,
					kern__StatusCode__c,
					kern__Status__c,
					kern__MaxRetries__c,
					kern__NextRetry__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt55f
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	Assert.areEqual(1, apiCalls55f.size(), '55f: an ApiCall row should be persisted for the 503 response');
	Assert.areEqual('503', apiCalls55f[0].kern__StatusCode__c, '55f: ApiCall.StatusCode__c should record HTTP 503');
	Assert.areEqual('Retry', apiCalls55f[0].kern__Status__c, '55f: ApiCall.Status__c should be Retry');
	Assert.areEqual(2, (apiCalls55f[0].kern__MaxRetries__c ?? 0).intValue(), '55f: MaxRetries__c should be 2');
	Assert.isNotNull(apiCalls55f[0].kern__NextRetry__c, '55f: NextRetry__c should be scheduled');
	System.debug(LoggingLevel.INFO, '55f PASS: 503 with withRetry(2, 5) → MaxRetries=2, Status=Retry, NextRetry__c scheduled');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '55f FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('55f: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 55g — graceful handling of unusual status code (0): mock returns statusCode=0 to
// stand in for a connection-refused/DNS-failure shape (real network failures cannot be reproduced
// because mocks bypass the HTTP transport). Verify the framework records '0' faithfully without
// a platform crash, marks ApiCall as Failed, and creates an ApiIssue. This proves no code path
// assumes statusCode >= 100 or is silently bucketed into 5xx.
try
{
	kern.API_MockFactory.forService(SERVICE_NAME).body('').statusCode(0).register();
	Datetime startedAt55g = Datetime.now();
	kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
			.withParameter('message', 'zerocode-' + SCENARIO_RUN_STAMP)
			.invoke();

	List<kern__ApiCall__c> apiCalls55g =
	[
			SELECT
					Id,
					kern__StatusCode__c,
					kern__Status__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt55g
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	Assert.areEqual(1, apiCalls55g.size(), '55g: an ApiCall row should be persisted even for statusCode=0');
	Assert.areEqual('0', apiCalls55g[0].kern__StatusCode__c, '55g: ApiCall.StatusCode__c should record the literal "0" without normalisation');
	Assert.areEqual(STATUS_FAILED, apiCalls55g[0].kern__Status__c, '55g: ApiCall.Status__c should be Failed (0 is not a 2xx success)');

	Integer apiIssueCount55g =
	[
			SELECT COUNT()
			FROM kern__ApiIssue__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt55g
	];
	Assert.isTrue(apiIssueCount55g >= 1, '55g: at least one ApiIssue row should be created for the statusCode=0 failure, got ' + apiIssueCount55g);
	System.debug(LoggingLevel.INFO, '55g PASS: statusCode=0 handled gracefully — recorded as "0", Status=Failed, ' + apiIssueCount55g + ' ApiIssue(s) created');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '55g FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('55g: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 55h — withFailureRate(50) over 20 calls: API_MockFactory uses Crypto.getRandomInteger()
// (unseeded, non-deterministic) so the result is a true random sample. With p=0.5, n=20, the
// expected fail count is 10 with a standard deviation ≈ 2.2 — a [3,17] band gives roughly a
// ±3σ window per side to absorb CI variance while still failing on a stuck 0%/100% mock.
//
// Sample size capped at 20 (not the spec's 100) because each failed delegation call writes an
// ApiCall row + 2 ApiIssue rows = 3-4 DML statements per failed call. The 150-statement DML
// governor (not the 100-callout governor — mocks bypass that) is the binding constraint:
// 8 setup calls (55a-55g) at 2-3 DML each ≈ 22-25, plus 20 failureRate calls at ~4 DML each
// ≈ 80, plus ~5 cleanup statements ≈ 110. Bumping the sample to 30 pushed us over 150 in
// dry runs. Larger samples belong in a managed @IsTest where the governor resets per @IsTest
// method via Test.startTest()/stopTest().
try
{
	kern.API_MockFactory.forService(SERVICE_NAME)
			.body('{"echo":"random"}')
			.statusCode(200)
			.withFailureRate(50)
			.register();

	Set<Id> existingApiCallIds55h = new Map<Id, kern__ApiCall__c>(
	[
			SELECT Id
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
	]).keySet();

	for(Integer i = 0; i < 20; i++)
	{
		kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.withParameter('message', 'failrate-' + SCENARIO_RUN_STAMP + '-' + i)
				.invoke();
	}

	List<kern__ApiCall__c> apiCalls55h =
	[
			SELECT
					Id,
					kern__StatusCode__c,
					kern__Status__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND Id NOT IN :existingApiCallIds55h
	];
	Assert.areEqual(20, apiCalls55h.size(), '55h: 20 calls should produce 20 ApiCall rows');

	Integer failureCount55h = 0;
	Integer successCount55h = 0;
	for(kern__ApiCall__c call : apiCalls55h)
	{
		if(call.kern__StatusCode__c == '500')
		{
			failureCount55h++;
		}
		else if(call.kern__StatusCode__c == '200')
		{
			successCount55h++;
		}
	}
	Assert.areEqual(20, failureCount55h + successCount55h, '55h: every call should be classified as either a simulated 500 or a passthrough 200');
	Assert.isTrue(failureCount55h >= 3, '55h: failureRate=50 over 20 calls should produce at least 3 failures (got ' + failureCount55h + '). Mock may be stuck at 0%.');
	Assert.isTrue(failureCount55h <= 17, '55h: failureRate=50 over 20 calls should produce at most 17 failures (got ' + failureCount55h + '). Mock may be stuck at 100%.');
	System.debug(LoggingLevel.INFO, '55h PASS: failureRate=50 over 20 calls produced ' + failureCount55h + ' failures, ' + successCount55h + ' successes (in band)');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '55h FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('55h: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 55i — onFailure(RETRY_THEN_LOG) composes with withRetry(2, 5) and a 503 mock: the
// FailureAction propagates KEY_LOG_FAILURES=true to the in-memory ApiSetting (logging-on),
// while retry is still queued (NextRetry__c set, Status=Retry). Confirms the composition path
// where the caller explicitly opts in to "retry to exhaustion, then log issue". The mock answers
// 503, which says the request was not processed, so the POST without a key may be scheduled; a
// 500 would end it Failed (see 55e).
//
// In delegation mode LOG_FAILURE behaves as RETRY_THEN_LOG (its retry skip acts only on the ad-hoc
// retry loop), so this scenario asserts the composition delegation can show.
try
{
	kern.API_MockFactory.forService(SERVICE_NAME).body('{"error":"retry-then-log"}').statusCode(503).register();
	// A row's CreatedDate has whole seconds, so an earlier scenario's rows can share this second. The rows already there
	// are left out by id, so only the rows this scenario creates are read and counted.
	Datetime startedAt55i = Datetime.now().addSeconds(-1);
	Set<Id> earlierCallIds55i = new Map<Id, kern__ApiCall__c>(
			[SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SERVICE_NAME AND CreatedDate >= :startedAt55i]).keySet();
	Set<Id> earlierIssueIds55i = new Map<Id, kern__ApiIssue__c>(
			[SELECT Id FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :SERVICE_NAME AND CreatedDate >= :startedAt55i]).keySet();
	kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
			.withRetry(2, 5)
			.onFailure(kern.UTIL_HttpClient.FailureAction.RETRY_THEN_LOG)
			.withParameter('message', 'retry-then-log-' + SCENARIO_RUN_STAMP)
			.invoke();

	List<kern__ApiCall__c> apiCalls55i =
	[
			SELECT
					Id,
					kern__StatusCode__c,
					kern__Status__c,
					kern__MaxRetries__c,
					kern__NextRetry__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt55i
			AND Id NOT IN :earlierCallIds55i
			ORDER BY CreatedDate DESC
			LIMIT 1
	];
	Assert.areEqual(1, apiCalls55i.size(), '55i: an ApiCall row should be persisted');
	Assert.areEqual('503', apiCalls55i[0].kern__StatusCode__c, '55i: ApiCall.StatusCode__c should record HTTP 503');
	Assert.areEqual('Retry', apiCalls55i[0].kern__Status__c, '55i: ApiCall.Status__c should be Retry (RETRY_THEN_LOG keeps retry queueing on)');
	Assert.areEqual(2, (apiCalls55i[0].kern__MaxRetries__c ?? 0).intValue(), '55i: MaxRetries__c should be 2');
	Assert.isNotNull(apiCalls55i[0].kern__NextRetry__c, '55i: NextRetry__c should be scheduled (RETRY_THEN_LOG keeps retry on)');

	Integer apiIssueCount55i =
	[
			SELECT COUNT()
			FROM kern__ApiIssue__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt55i
			AND Id NOT IN :earlierIssueIds55i
	];
	Assert.isTrue(apiIssueCount55i >= 1, '55i: at least one ApiIssue row should be created (RETRY_THEN_LOG enables logging), got ' + apiIssueCount55i);
	System.debug(LoggingLevel.INFO,
			'55i PASS: onFailure(RETRY_THEN_LOG) with withRetry(2, 5) → Status=Retry, NextRetry__c scheduled, ' + apiIssueCount55i + ' ApiIssue(s) created');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '55i FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('55i: ' + scenarioError.getMessage());
	fail++;
}

// Cleanup — bounded to stay under the 10K DML row governor. Section 55 inserts roughly 28
// ApiCall rows (8 single-shot scenarios 55a-55g + 20 from 55h's failureRate loop) plus a
// matching ~10-30 ApiIssue rows (~2 per failed call). Capping each delete at 9000 keeps a
// safety margin without leaking, and the SOQL is keyed to API_EchoSubscriber so that other
// services' ApiCall rows in the same scratch org are unaffected.
delete
[
		SELECT Id
		FROM kern__ApiIssue__c
		WHERE kern__ServiceName__c = :SERVICE_NAME
		AND CreatedDate = TODAY
		AND CreatedById = :UserInfo.getUserId()
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
// Log entries are written from a platform event after this transaction ends, so the ones this run
// emits are deleted by section-55-edge-outbound-failure-cleanup.apex, run 30 seconds later; the
// ones already written (an earlier run's) are deleted here. The Automated Process user writes them, so they are not
// filtered by creator.
final String LOG_PATTERN = '%' + SERVICE_NAME + '%';
delete
[
		SELECT Id
		FROM kern__LogEntry__c
		WHERE kern__ClassMethod__c LIKE :LOG_PATTERN
		AND CreatedDate = TODAY
		LIMIT 9000
];
Integer callsLeft = [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SERVICE_NAME AND CreatedDate = TODAY AND CreatedById = :UserInfo.getUserId()];
Integer issuesLeft = [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :SERVICE_NAME AND CreatedDate = TODAY AND CreatedById = :UserInfo.getUserId()];
if(callsLeft + issuesLeft == 0)
{
	System.debug(LoggingLevel.INFO, '55-cleanup PASS: no API_EchoSubscriber call or issue of today is left; '
			+ 'run section-55-edge-outbound-failure-cleanup.apex in 30 seconds for the log entries');
}
else
{
	System.debug(LoggingLevel.ERROR, '55-cleanup FAIL: left behind: ' + callsLeft + ' calls, ' + issuesLeft + ' issues');
	failures.add('55-cleanup: left behind ' + callsLeft + ' calls, ' + issuesLeft + ' issues');
	fail++;
}
kern.API_MockFactory.clearMocks();
kern.TRG_Base.clearAllBypasses();

// Summary
System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 55: ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 55 FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 55 failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 55 COMPLETE: All scenarios passed ===');
}
