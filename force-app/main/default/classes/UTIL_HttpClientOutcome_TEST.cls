// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests for the outbound client's outcome contract: the synthetic response, retry parking and credential redaction.
 * An "unkeyed" POST is a POST sent without an Idempotency-Key header. With no key, the external system cannot tell a
 * repeat from a new request, so sending it again could do the work twice.
 *
 * @see UTIL_HttpClient
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date August 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
private class UTIL_HttpClientOutcome_TEST
{
	/**
	 * @description Test credential name.
	 */
	private static final String TEST_CREDENTIAL = 'TestCredential';

	/**
	 * @description Test URL path for callouts.
	 */
	private static final String TEST_PATH = '/api/v1/resource';

	/**
	 * @description The service name for DefaultOutboundHandler mock registration.
	 * DefaultOutboundHandler.getServiceName() returns the credential name.
	 */
	private static final String HANDLER_SERVICE = TEST_CREDENTIAL;

	/**
	 * @description Valid JSON response body for success mocks.
	 */
	private static final String RESPONSE_BODY = '{"status":"ok","id":"12345"}';

	/**
	 * @description Error JSON response body for failure mocks.
	 */
	private static final String ERROR_BODY = '{"error":"Internal Server Error"}';

	/**
	 * @description The credential a test caller sets by hand; random so no fixed value can pass by coincidence.
	 */
	private static final String CALLER_BEARER_TOKEN = UTIL_Random.randomAlphanumeric(32);

	/**
	 * @description A non-credential custom header, stored as set.
	 */
	private static final String HEADER_ACCEPT = 'Accept';

	/**
	 * @description The value of the non-credential custom header, stored as set.
	 */
	private static final String ACCEPT_JSON = 'application/json';

	/**
	 * @description Credential merge-field text: carries no secret and must be stored verbatim for retries.
	 */
	private static final String MERGE_FIELD_API_KEY = '{!$Credential.ProbeCredential.ApiKey}';

	/**
	 * @description The credential header whose value is credential merge-field text.
	 */
	private static final String HEADER_API_KEY = 'X-Api-Key';

	/**
	 * @description A retry budget larger than the synchronous retry ceiling, so budget is left over for a scheduled
	 * retry once the in-transaction attempts are spent. Without that leftover nothing is ever scheduled and an
	 * assertion on NextRetry__c would pass whatever the handler does.
	 */
	private static final Integer RETRY_BUDGET_BEYOND_SYNCHRONOUS = 5;

	/**
	 * @description The backoff, in seconds, requested for the scheduled retry.
	 */
	private static final Integer RETRY_BACKOFF_SECONDS = 30;

	/**
	 * @description The stored-header input key the fluent client writes (mirror of the private KEY_HTTP_HEADERS).
	 */
	private static final String STORED_HEADERS_KEY = '__httpHeaders';

	/**
	 * @description The stored credential input key the fluent client writes (mirror of the private KEY_CREDENTIAL).
	 */
	private static final String STORED_CREDENTIAL_KEY = '__credential';

	/**
	 * @description The stored path input key the fluent client writes (mirror of the private KEY_PATH).
	 */
	private static final String STORED_PATH_KEY = '__path';

	/**
	 * @description The status code a response carries when no HTTP exchange ever happened. No real
	 * exchange can report it, so it is what tells a caller the response was built by the framework.
	 */
	private static final Integer NO_EXCHANGE_STATUS_CODE = 0;

	/**
	 * @description The message a delegate handler's exception carries when it records no readable text.
	 */
	private static final String BLANK_EXCEPTION_MESSAGE = '';

	/**
	 * @description The prefix every Apex stack-trace line starts with. The status line of a response
	 * must never contain it: the trace is the second recorded error, never the first.
	 */
	private static final String STACK_TRACE_MARKER = 'Class.';

	/**
	 * @description A request body, so the call carries content the masking rules have something to redact.
	 */
	private static final String REQUEST_BODY = '{"name":"value"}';

	/**
	 * @description DeveloperName of the masking rule that cannot compile and is set to block DML.
	 */
	private static final String BLOCKING_RULE_NAME = 'BlockingRuleForTheOutcomeTests';

	/**
	 * @description A regular expression the platform cannot compile, so the rule fails whenever it runs.
	 */
	private static final String INVALID_PATTERN = '([bad';

	/**
	 * @description The replacement the failing rule would have written had it compiled.
	 */
	private static final String MASK_REPLACEMENT = 'X';

	/**
	 * @description The execution order of the failing masking rule.
	 */
	private static final Decimal BLOCKING_RULE_ORDER = 10;

	/**
	 * @description A global context key the transaction that builds a call sets, so a later run of the call can be
	 * seen to carry it.
	 */
	private static final String CALLER_CONTEXT_KEY = 'callerContextKey';

	/**
	 * @description The value stored under the caller's global context key.
	 */
	private static final String CALLER_CONTEXT_VALUE = 'set by the transaction that built the call';

	/**
	 * @description Assertion message: send() answers its caller whatever the framework recorded for the call.
	 */
	private static final String MESSAGE_SEND_MUST_ANSWER = 'A masking rule that blocks the failure attachments must not stop send() from answering';

	/**
	 * @description Assertion message: the block reaches the caller as recorded result state.
	 */
	private static final String MESSAGE_BLOCK_RECORDED = 'The block must be recorded on the handler result';

	/**
	 * @description Assertion message: a blocked redaction writes nothing.
	 */
	private static final String MESSAGE_NO_ATTACHMENT = 'Nothing may be attached when a masking rule blocked the redaction';

	/**
	 * @description Assertion message: a blocking rule that failed once still blocks the call record's own insert.
	 */
	private static final String MESSAGE_NO_CALL_RECORD = 'No call record may be written when a masking rule set to block DML failed on its request field';

	/**
	 * @description Assertion message: a blocking rule that failed on the logger still blocks the failure attachments.
	 */
	private static final String MESSAGE_NO_ATTACHMENT_AFTER_LOGGER_FAILURE = 'Nothing may be attached when the blocking rule had already failed on a log entry';

	/**
	 * @description Assertion message: a call record that cannot be saved is a log entry, not an exception.
	 */
	private static final String MESSAGE_SAVE_FAILURE_LOGGED = 'A call record that cannot be saved must leave a log entry behind';

	/**
	 * @description Assertion message: a later run of the stored call writes entries, so the context assertions have rows.
	 */
	private static final String MESSAGE_LATER_RUN_WRITES_ENTRIES = 'A later run of the stored call must write at least one log entry';

	/**
	 * @description Assertion message: the stored logger context gives the later run's entries the caller's transaction as parent.
	 */
	private static final String MESSAGE_LATER_RUN_PARENT_IS_THE_CALLER_TRANSACTION = 'Every later-run entry must carry the transaction that built the call as its parent';

	/**
	 * @description Assertion message: the stored logger context gives the later run's entries the caller's global context.
	 */
	private static final String MESSAGE_LATER_RUN_CARRIES_THE_CALLER_CONTEXT = 'Every later-run entry must carry the global context of the transaction that built the call';

	/**
	 * @description Assertion message: the call records the trace the logger attributes it by.
	 */
	private static final String MESSAGE_TRACE_RECORDED = 'The call must record the trace it ran under, so the correlation assertion has something to compare';

	/**
	 * @description Assertion message: an outbound call's entries correlate by the trace of the run, never by the stored correlation id.
	 */
	private static final String MESSAGE_CORRELATION_IS_THE_CALL_TRACE = 'The entries of a run must correlate by the trace that run got, not by the stored correlation id';

	/**
	 * @description Registers a mock response for the DefaultOutboundHandler with the given parameters.
	 *
	 * @param body The JSON response body
	 * @param statusCode The HTTP status code
	 * @param status The HTTP status text
	 */
	private static void registerMock(String body, Integer statusCode, String status)
	{
		API_MockFactory.forService(HANDLER_SERVICE)
				.body(body).statusCode(statusCode).status(status).register();
	}

	/**
	 * @description Registers a success mock for the DefaultOutboundHandler.
	 */
	private static void registerSuccessMock()
	{
		registerMock(RESPONSE_BODY, API_Base.HTTP_OK, 'OK');
	}

	/**
	 * @description Registers a server error mock for the DefaultOutboundHandler.
	 */
	private static void registerServerErrorMock()
	{
		registerMock(ERROR_BODY, API_Base.HTTP_INTERNAL_SERVER_ERROR, 'Internal Server Error');
	}

	/**
	 * @description Registers a bad request mock for the DefaultOutboundHandler.
	 */
	private static void registerBadRequestMock()
	{
		registerMock(ERROR_BODY, API_Base.HTTP_BAD_REQUEST, 'Bad Request');
	}

	/**
	 * @description Registers a too many requests mock for the DefaultOutboundHandler.
	 */
	private static void registerTooManyRequestsMock()
	{
		registerMock(ERROR_BODY, API_Base.HTTP_TOO_MANY_REQUESTS, 'Too Many Requests');
	}

	/**
	 * @description Registers a gateway timeout mock for the DefaultOutboundHandler.
	 */
	private static void registerGatewayTimeoutMock()
	{
		registerMock(ERROR_BODY, API_Base.HTTP_GATEWAY_TIMEOUT, 'Gateway Timeout');
	}

	/**
	 * @description Tests that retries are exhausted and the final failed response is returned.
	 */
	@IsTest
	private static void shouldExhaustRetriesAndReturnFinalResponse()
	{
		registerServerErrorMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withRetry(2);
		assertSend(builder, API_Base.HTTP_INTERNAL_SERVER_ERROR);

		Assert.areEqual(2, (Integer)builder.handlerInstance.apiCall.Retries__c, 'Should record all retries');
	}

	/**
	 * @description Tests that retry only occurs on configured status codes.
	 */
	@IsTest
	private static void shouldRetryOnlyOnConfiguredStatusCodes()
	{
		registerTooManyRequestsMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.withRetry(2)
				.retryOn(new Set<Integer> {429});
		assertSend(builder, API_Base.HTTP_TOO_MANY_REQUESTS);

		Decimal retries = builder.handlerInstance.apiCall.Retries__c;
		Assert.areEqual(2, (Integer)retries, 'Expected two immediate re-sends of a 429 that retryOn named, got ' + retries);
	}

	/**
	 * @description A caller who names 425 in retryOn(...) chose the immediate re-send: the loop re-sends it at once, as it
	 * does for a named 429, although the same code waits for the scheduled retry when no codes are named.
	 */
	@IsTest
	private static void shouldResendAtOnceATooEarlyResponseThatRetryOnNames()
	{
		registerMock(ERROR_BODY, API_Base.HTTP_TOO_EARLY, 'Too Early');

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.withRetry(2)
				.retryOn(new Set<Integer> {API_Base.HTTP_TOO_EARLY});
		assertSend(builder, API_Base.HTTP_TOO_EARLY);

		Decimal retries = builder.handlerInstance.apiCall.Retries__c;
		Assert.areEqual(2, (Integer)retries, 'Expected two immediate re-sends of a 425 that retryOn named, got ' + retries);
	}

	/**
	 * @description Tests that a 400 client error is not retried by default.
	 */
	@IsTest
	private static void shouldNotRetryOnClientError()
	{
		registerBadRequestMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withRetry(2);
		assertSend(builder, API_Base.HTTP_BAD_REQUEST);

		Assert.isNull(builder.handlerInstance.apiCall.Retries__c, 'Should not retry on 400');
	}

	/**
	 * @description Tests that a call is aborted when circuit breaker is OPEN.
	 * Requires Platform Cache to persist circuit breaker state between instances.
	 */
	@IsTest
	private static void shouldAbortWhenCircuitBreakerOpen()
	{
		if(!UTIL_Cache.isOrgAllocated())
		{
			return;
		}

		registerSuccessMock();

		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(TEST_CREDENTIAL);
		breaker.forceOpen();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withCircuitBreaker();

		Test.startTest();
		builder.send();
		Test.stopTest();

		Assert.isTrue(builder.handlerInstance.result.isAborted, 'Should abort when circuit breaker is open');
	}

	/**
	 * @description Tests that circuit breaker success is recorded after a successful call.
	 */
	@IsTest
	private static void shouldRecordCircuitBreakerSuccess()
	{
		registerSuccessMock();

		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(TEST_CREDENTIAL);

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withCircuitBreaker();
		assertSend(builder);

		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Circuit should be closed');
	}

	/**
	 * @description Tests that a ApiIssue__c record is created with LOG_FAILURE action.
	 */
	@IsTest
	private static void shouldCreateFailureRecordOnLogFailure()
	{
		registerServerErrorMock();

		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.onFailure(UTIL_HttpClient.FailureAction.LOG_FAILURE)
				.withTriggeringRecord(record.Id);
		assertSend(builder);

		String serviceName = builder.handlerInstance.apiCall.ServiceName__c;
		List<ApiIssue__c> failures = new SEL_ApiIssue().findUnresolvedByService(serviceName);

		Assert.areEqual(1, failures.size(), 'Should create one failure record');
	}

	/**
	 * @description Tests that LOG_FAILURE skips retry and logs immediately.
	 */
	@IsTest
	private static void shouldSkipRetryWithLogFailureAction()
	{
		registerServerErrorMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.onFailure(UTIL_HttpClient.FailureAction.LOG_FAILURE)
				.withRetry(3);
		assertSend(builder);

		Assert.isNull(builder.handlerInstance.apiCall.Retries__c, 'Should not retry with LOG_FAILURE');
	}

	/**
	 * @description Tests that send() returns a cached response on subsequent calls.
	 */
	@IsTest
	private static void shouldReturnCachedResponse()
	{
		registerSuccessMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH);

		Test.startTest();
		HttpResponse first = builder.send();
		HttpResponse second = builder.send();
		Test.stopTest();

		assertNotAborted(builder);
		Assert.isTrue(first === second, 'Should return same cached response instance');
	}

	/**
	 * @description Proves send() answers its caller when the callout throws while the call is being
	 * processed. Nothing ever came back over the wire, so the call has no response of its own; the
	 * caller is handed one anyway, and the status line it carries is the first error recorded for the
	 * call rather than the stack trace that follows it.
	 */
	@IsTest
	private static void sendReturnsSyntheticResponseWhenProcessingThrows()
	{
		API_MockFactory.forService(HANDLER_SERVICE).withTransportFailure().register();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH);

		Test.startTest();
		HttpResponse response = builder.send();
		Test.stopTest();

		List<String> recordedErrors = builder.invoke().result.errors;

		Assert.isNotNull(response, 'send() must hand back a response object when processing throws');
		Assert.areEqual(NO_EXCHANGE_STATUS_CODE, response.getStatusCode(), 'No wire exchange happened, so the status code is 0');
		Assert.isTrue(String.isBlank(response.getBody()), 'The body is left unset, which the platform reads back as an empty string, never as content');
		Assert.areEqual(recordedErrors[0], response.getStatus(), 'The status line is the first error recorded for the call, and nothing else');
		Assert.isTrue(recordedErrors.size() > 1, 'The handler records the stack trace after the message, so the first error is a real choice among several');
		Assert.isFalse(response.getStatus().contains(STACK_TRACE_MARKER), 'The status line carries the first error, never a stack trace');
		ApiCall__c storedCall = builder.handlerInstance.apiCall;
		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, storedCall.Status__c, 'Expected a POST with no Idempotency-Key and no retry budget to end Failed, got ' + storedCall.Status__c);
		Assert.isNull(storedCall.NextRetry__c, 'Expected no retry time on a Failed row, got ' + storedCall.NextRetry__c);
	}

	/**
	 * @description Proves the framework's own record of the failure outlives the caller. The caller
	 * dereferences the response it was handed, and the ApiCall__c row written for the failed call is
	 * still queryable afterwards: a NullPointerException at the dereference would have rolled it back.
	 */
	@IsTest
	private static void sendKeepsTheFailureRecordWhenProcessingThrows()
	{
		API_MockFactory.forService(HANDLER_SERVICE).withTransportFailure().register();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH);

		Test.startTest();
		Integer statusCode = builder.send().getStatusCode();
		Test.stopTest();

		List<ApiCall__c> persisted = new SEL_ApiCall().findByField(ApiCall__c.ServiceName__c, UTIL_HttpClient.DefaultOutboundHandler.class.getName());

		Assert.areEqual(NO_EXCHANGE_STATUS_CODE, statusCode, 'The caller reads the status code off the response without a NullPointerException');
		Assert.areEqual(1, persisted.size(), 'The ApiCall__c record written for the failed call survives the caller');
		Assert.isTrue(String.isNotBlank(persisted[0].ErrorMessages__c), 'The surviving record carries the error that was recorded');
		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, persisted[0].Status__c, 'Expected a POST with no key and no retry budget to end Failed, got ' + persisted[0].Status__c);
		Assert.isNull(persisted[0].NextRetry__c, 'Expected no retry time on a Failed row, got ' + persisted[0].NextRetry__c);
	}

	/**
	 * @description Proves the string terminals keep answering exactly as they do for any other call
	 * that produced no response: asString() gives null rather than the empty string a response body
	 * reads back as, so asMap() still gives an empty map and deserialize() still sees no content.
	 */
	@IsTest
	private static void asStringReturnsNullWhenTheResponseWasSynthesized()
	{
		API_MockFactory.forService(HANDLER_SERVICE).withTransportFailure().register();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH);

		Test.startTest();
		String body = builder.asString();
		Map<String, Object> parsed = builder.asMap();
		Test.stopTest();

		Assert.isNull(body, 'asString() answers null when the call produced no response of its own');
		Assert.isTrue(parsed.isEmpty(), 'asMap() answers an empty map when the call produced no response of its own');
	}

	/**
	 * @description Proves the status line falls back to the label when nothing recorded an error. The
	 * delegate handler here accepts the call and returns without sending anything, so the call ends
	 * with neither a response nor an error, and the caller still gets a status line it can read.
	 */
	@IsTest
	private static void sendCarriesTheLabelWhenNoErrorWasRecorded()
	{
		Test.startTest();
		HttpResponse response = UTIL_HttpClient.useHandler(TestSilentHandler.class).send();
		Test.stopTest();

		Assert.isNotNull(response, 'send() must hand back a response object when the delegate sends nothing');
		Assert.areEqual(NO_EXCHANGE_STATUS_CODE, response.getStatusCode(), 'No wire exchange happened, so the status code is 0');
		Assert.areEqual(System.Label.OutboundCall_NoRecordedError, response.getStatus(), 'With no error recorded the status line falls back to the label');
	}

	/**
	 * @description Proves the status line falls back to the label when the error that was recorded
	 * carries no readable message. The delegate handler here fails with an exception built on a blank
	 * message, so the first error recorded against it is blank and the caller still gets a status line.
	 */
	@IsTest
	private static void sendCarriesTheLabelWhenTheRecordedErrorHasNoMessage()
	{
		Test.startTest();
		HttpResponse response = UTIL_HttpClient.useHandler(TestBlankMessageHandler.class).send();
		Test.stopTest();

		Assert.isNotNull(response, 'send() must hand back a response object when the delegate fails');
		Assert.areEqual(NO_EXCHANGE_STATUS_CODE, response.getStatusCode(), 'No response came back, so the status code is 0');
		Assert.areEqual(System.Label.OutboundCall_NoRecordedError, response.getStatus(), 'A blank recorded error falls back to the label');
	}

	/**
	 * @description A masking rule set to block DML that fails while the failure attachments are redacted must not
	 * escape send(): the call still answers with the synthetic response, the block is recorded on the result, and no
	 * attachment is registered even though file storage is forced on. The same rule blocks the call record's own
	 * insert at the trigger, which `sendWritesNoCallRecordWhenAMaskingRuleBlocksItsRedaction` checks.
	 *
	 * @see API_Base.createRelatedContentVersions
	 */
	@IsTest
	private static void sendAnswersWhenAMaskingRuleBlocksTheFailureAttachments()
	{
		TST_Factory.newFeatureFlag(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);
		registerBlockingMaskingRuleFor(ApiCall__c.Request__c);
		API_Base.simulateStoreToFile = true;
		API_MockFactory.forService(HANDLER_SERVICE).withTransportFailure().register();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH).body(REQUEST_BODY);

		Test.startTest();
		HttpResponse response = builder.send();
		Test.stopTest();

		List<String> recordedErrors = builder.invoke().result.errors;

		Assert.areEqual(NO_EXCHANGE_STATUS_CODE, response.getStatusCode(), MESSAGE_SEND_MUST_ANSWER);
		Assert.isTrue(String.join(recordedErrors, UTIL_String.EMPTY).contains(BLOCKING_RULE_NAME), MESSAGE_BLOCK_RECORDED);
		Assert.isTrue(new SEL_ContentVersion().getAll().isEmpty(), MESSAGE_NO_ATTACHMENT);
	}

	/**
	 * @description A masking rule set to block DML keeps blocking for the whole transaction once it has failed, so the
	 * call record's own insert is blocked at the trigger as well: send() still answers with the synthetic response and
	 * no ApiCall__c row is written at all, rather than one carrying the raw request the rule was meant to redact.
	 *
	 * @see UTIL_FrameworkMasker.handleRuleFailure
	 * @see TRG_Dispatcher.applyMaskingIfConfigured
	 */
	@IsTest
	private static void sendWritesNoCallRecordWhenAMaskingRuleBlocksItsRedaction()
	{
		TST_Factory.newFeatureFlag(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);
		registerBlockingMaskingRuleFor(ApiCall__c.Request__c);
		API_Base.simulateStoreToFile = true;
		API_MockFactory.forService(HANDLER_SERVICE).withTransportFailure().register();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH).body(REQUEST_BODY);

		Test.startTest();
		HttpResponse response = builder.send();
		Test.stopTest();

		List<ApiCall__c> persisted = new SEL_ApiCall().findByServiceName(UTIL_HttpClient.DefaultOutboundHandler.class.getName());

		Assert.areEqual(NO_EXCHANGE_STATUS_CODE, response.getStatusCode(), MESSAGE_SEND_MUST_ANSWER);
		Assert.isTrue(persisted.isEmpty(), MESSAGE_NO_CALL_RECORD);
	}

	/**
	 * @description A masking rule blocking the call record's insert surfaces as row-level failures on the
	 * dispatcher's partial commit, owned by the transaction's row-failure logging: exactly one ERROR entry
	 * at the commit, and never a swallowed-statement entry, because the commit's catch is not involved.
	 *
	 * @see DML_Transaction.commitWork
	 */
	@IsTest
	private static void sendKeepsRowFailureLoggingWhenAMaskingRuleBlocksTheCallRecord()
	{
		TST_Factory.newFeatureFlag(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);
		registerBlockingMaskingRuleFor(ApiCall__c.Request__c);
		LOG_Builder.ignoreTestMode = true;
		API_Base.simulateStoreToFile = true;
		API_MockFactory.forService(HANDLER_SERVICE).withTransportFailure().register();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH).body(REQUEST_BODY);

		Test.startTest();
		HttpResponse response = builder.send();
		Test.stopTest();

		Assert.areEqual(NO_EXCHANGE_STATUS_CODE, response.getStatusCode(), MESSAGE_SEND_MUST_ANSWER);
		List<LogEntry__c> commitEntries = new SEL_LogEntry().findAllByMethod(DML_Transaction.CLASS_METHOD_COMMIT);
		Assert.areEqual(1, commitEntries.size(), 'The blocked insert should leave exactly one entry at the commit');
		Assert.areEqual(LOG_Engine.LEVEL_ERROR, commitEntries[0].LogLevel__c, 'The row failure should log at ERROR');
		String contextData = commitEntries[0].ContextData__c;
		Boolean carriesSwallowContext = contextData?.contains(DML_Transaction.CONTEXT_KEY_PARTIAL_COMMIT_OUTCOME) == true;
		Assert.isFalse(carriesSwallowContext, 'A row-level failure must never carry the swallowed-statement context');
	}

	/**
	 * @description The same blocking rule wired to both a log entry event and the call record's request field fails on
	 * the logger first, where the entry is dropped so the business transaction survives. It must still block the
	 * failure attachments redacted afterwards: nothing is attached, so no oversized payload reaches file storage
	 * unredacted, and send() still answers with the synthetic response.
	 *
	 * @see UTIL_FrameworkMasker.handleRuleFailure
	 * @see API_Dispatcher.handleError
	 */
	@IsTest
	private static void sendAttachesNothingWhenTheBlockingRuleAlreadyFailedOnTheLogger()
	{
		TST_Factory.newFeatureFlag(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);
		registerBlockingMaskingRuleOnLogEntryEventsAndCallRecords();
		API_Base.simulateStoreToFile = true;
		LOG_Builder.ignoreTestMode = true;
		API_MockFactory.forService(HANDLER_SERVICE).withTransportFailure().register();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH).body(REQUEST_BODY);

		Test.startTest();
		HttpResponse response = builder.send();
		Test.stopTest();

		Assert.areEqual(NO_EXCHANGE_STATUS_CODE, response.getStatusCode(), MESSAGE_SEND_MUST_ANSWER);
		Assert.isTrue(new SEL_ContentVersion().getAll().isEmpty(), MESSAGE_NO_ATTACHMENT_AFTER_LOGGER_FAILURE);
	}

	/**
	 * @description Registers one active masking target on the given ApiCall__c field whose rule cannot compile and is
	 * set to block DML, mirroring the masker's own failure-action fixtures.
	 *
	 * @param targetField The ApiCall__c field the failing rule applies to
	 */
	private static void registerBlockingMaskingRuleFor(SObjectField targetField)
	{
		registerTargetFor(buildBlockingRule(), ApiCall__c.SObjectType, targetField);
	}

	/**
	 * @description Registers the same blocking rule against a wildcard LogEntryEvent__e target and the call record's
	 * request field, so the rule fails on the logger before the failure attachments are redacted.
	 */
	private static void registerBlockingMaskingRuleOnLogEntryEventsAndCallRecords()
	{
		MaskingRule__mdt rule = buildBlockingRule();
		registerTargetFor(rule, LogEntryEvent__e.SObjectType, null);
		registerTargetFor(rule, ApiCall__c.SObjectType, ApiCall__c.Request__c);
	}

	/**
	 * @description Builds the uninserted masking rule the blocking fixtures share: a regular expression the platform
	 * cannot compile, set to block DML so every run of it throws.
	 *
	 * @return The uninserted blocking rule
	 */
	private static MaskingRule__mdt buildBlockingRule()
	{
		return (MaskingRule__mdt)TST_Builder.of(MaskingRule__mdt.SObjectType)
				.withOverride(MaskingRule__mdt.DeveloperName, BLOCKING_RULE_NAME)
				.withOverride(MaskingRule__mdt.Mode__c, SEL_MaskingRule.MODE_REGEX)
				.withOverride(MaskingRule__mdt.Pattern__c, INVALID_PATTERN)
				.withOverride(MaskingRule__mdt.Replacement__c, MASK_REPLACEMENT)
				.withOverride(MaskingRule__mdt.IsActive__c, true)
				.withOverride(MaskingRule__mdt.Order__c, BLOCKING_RULE_ORDER)
				.withOverride(MaskingRule__mdt.FailureAction__c, SEL_MaskingRule.FAILURE_BLOCK_DML)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Registers one active masking target wiring the given rule to an object, either to a single field or,
	 * when no field is given, to every field the object carries.
	 *
	 * @param rule The rule the target wires up
	 * @param targetType The SObjectType the target applies to
	 * @param targetField The field the target applies to, or null for a wildcard target
	 */
	private static void registerTargetFor(MaskingRule__mdt rule, SObjectType targetType, SObjectField targetField)
	{
		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(targetType);
		String fieldName = targetField == null ? null : objectName + UTIL_String.DOT + UTIL_SObjectDescribe.getCachedFieldName(targetField);

		TST_Mock.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.IsActive__c, true)
				.withOverride(MaskingTarget__mdt.SObjectType__c, objectName)
				.withOverride(MaskingTarget__mdt.Field__c, fieldName)
				.withOverride(MaskingTarget__mdt.Rule__c, rule)
				.build();
	}

	/**
	 * @description The call record's own save can fail under the dispatcher's unit of work; that failure is a log
	 * entry, never an exception out of send(), and the response still arrives.
	 *
	 * @see API_Dispatcher.recordTimingMetrics
	 */
	@IsTest
	private static void sendAnswersWhenTheCallRecordCannotBeSaved()
	{
		API_Dispatcher.simulateApiCallCommitFailure = true;
		LOG_Builder.ignoreTestMode = true;
		registerSuccessMock();

		HttpResponse response = assertSend(UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH), API_Base.HTTP_OK);

		Assert.isNotNull(response, MESSAGE_SEND_MUST_ANSWER);
		Assert.isNotNull(new SEL_LogEntry().findByMethod(DML_Transaction.CLASS_METHOD_COMMIT), MESSAGE_SAVE_FAILURE_LOGGED);
	}

	/**
	 * @description The stored logger context of an ad-hoc call built with a correlation id is the logger context of the
	 * transaction that built the call, so a later run of the stored record (the scheduled retry, in a request of its
	 * own) restores it: every entry that run writes carries the caller's transaction as its parent and the caller's
	 * global context. The entries' own correlation is the trace the run got, which every outbound call sets
	 * deliberately to bridge distributed traces to log entries, never the stored correlation id.
	 *
	 * @see API_Dispatcher.hydrateLoggerContext
	 * @see API_Base.applyLoggingContext
	 */
	@IsTest
	private static void storedLoggerContextCarriesTheCallerTransactionIntoALaterRun()
	{
		registerSuccessMock();
		LOG_Builder.setGlobalContext(CALLER_CONTEXT_KEY, CALLER_CONTEXT_VALUE);

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withCorrelationId(UTIL_Random.randomUUID());
		builder.send();
		assertNotAborted(builder);
		ApiCall__c storedCall = (ApiCall__c)new SEL_ApiCall().findById(builder.handlerInstance.apiCall.Id);

		// The caller's own send can write log entries too, for example a debug entry for a trigger action that a feature flag
		// skips. Those entries belong to the caller's request, not to the later run, so they are saved now and left out below.
		Test.getEventBus().deliver();
		Set<Id> callerEntryIds = new Map<Id, LogEntry__c>(new SEL_LogEntry().getAll()).keySet();

		// The later run is another request than the caller's. The stored document names the caller's request as its parent,
		// which here is the test's own request, so it is re-homed to a request id of its own, read and written through the
		// engine's own type: a stored value that is not a readable context document fails here.
		String callerRequestId = UTIL_Random.randomUUID();
		LOG_Engine.DTO_LoggerContext storedContext = (LOG_Engine.DTO_LoggerContext)JSON.deserialize(storedCall.LoggerContext__c, LOG_Engine.DTO_LoggerContext.class);
		storedContext.parentTransactionId = callerRequestId;
		storedCall.LoggerContext__c = JSON.serialize(storedContext);

		// The later run starts with nothing of the caller's transaction live: no correlation, no parent, no context, no trace.
		LOG_Builder.setCorrelationId(null);
		LOG_Builder.setParentTransactionId(null);
		LOG_Builder.clearAllGlobalContext();
		API_Base.clearTraceContext();
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.newLoggerSettings().withWebserviceLogging(0).apply();

		Test.startTest();
		API_Dispatcher.execute(storedCall);
		Test.stopTest();

		ApiCall__c laterRunCall = (ApiCall__c)new SEL_ApiCall().findById(storedCall.Id);
		List<LogEntry__c> laterRunEntries = new List<LogEntry__c>();
		for(LogEntry__c entry : new SEL_LogEntry().getAll())
		{
			if(!callerEntryIds.contains(entry.Id))
			{
				laterRunEntries.add(entry);
			}
		}

		Assert.isTrue(String.isNotBlank(laterRunCall.TraceId__c), MESSAGE_TRACE_RECORDED);
		Assert.isFalse(laterRunEntries.isEmpty(), MESSAGE_LATER_RUN_WRITES_ENTRIES);
		for(LogEntry__c entry : laterRunEntries)
		{
			Assert.areEqual(callerRequestId, entry.ParentTransactionId__c, MESSAGE_LATER_RUN_PARENT_IS_THE_CALLER_TRANSACTION);
			Boolean carriesCallerContext = (entry.ContextData__c?.contains(CALLER_CONTEXT_KEY) ?? false) && entry.ContextData__c.contains(CALLER_CONTEXT_VALUE);
			Assert.isTrue(carriesCallerContext, MESSAGE_LATER_RUN_CARRIES_THE_CALLER_CONTEXT);
			Assert.areEqual(laterRunCall.TraceId__c, entry.CorrelationId__c, MESSAGE_CORRELATION_IS_THE_CALL_TRACE);
		}
	}

	/**
	 * @description Tests the failed API call record has error details populated.
	 */
	@IsTest
	private static void shouldLogFailedApiCallRecordWithErrors()
	{
		registerServerErrorMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH);
		assertSend(builder);

		Assert.isTrue(builder.handlerInstance.result.hasFailed, 'Result should be failed');
	}

	/**
	 * @description Tests that a credential header set on the builder reaches the live request but not the stored
	 * record: the request the handler sent carries the bearer token, while the request parameters written to the
	 * call record carry the redaction marker in its place and a non-credential custom header as set.
	 */
	@IsTest
	private static void shouldStoreCredentialHeadersRedactedWhileSendingThemLive()
	{
		registerSuccessMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.header(API_Base.HTTP_HEADER_AUTHORIZATION, API_Base.HTTP_AUTH_TOKEN_BEARER + CALLER_BEARER_TOKEN)
				.header(HEADER_API_KEY, MERGE_FIELD_API_KEY)
				.header(HEADER_ACCEPT, ACCEPT_JSON);
		assertSend(builder, API_Base.HTTP_OK);

		String storedParameters = builder.handlerInstance.apiCall.RequestParameters__c;
		String sentAuthorization = builder.handlerInstance.result.requestHeaders.get(API_Base.HTTP_HEADER_AUTHORIZATION);

		Assert.areEqual(API_Base.HTTP_AUTH_TOKEN_BEARER + CALLER_BEARER_TOKEN, sentAuthorization, 'The live request must carry the credential the caller set');
		Assert.isFalse(storedParameters.contains(CALLER_BEARER_TOKEN), 'The stored request parameters must not carry the credential');
		Assert.isTrue(storedParameters.contains(API_Base.REDACTED_HEADER_VALUE), 'The stored request parameters carry the redaction marker in its place');
		Assert.isTrue(storedParameters.contains(MERGE_FIELD_API_KEY), 'Credential merge-field text is stored verbatim so a retry can send it for the platform to substitute');
		Assert.isTrue(storedParameters.contains(ACCEPT_JSON), 'A non-credential custom header is stored as set');
	}

	/**
	 * @description Tests that a FAILED call whose credential header was redacted is parked for a human instead of
	 * retried: no NextRetry__c is scheduled, and the error text carries the labelled reason naming the header.
	 */
	@IsTest
	private static void shouldParkAFailedCallWhoseCredentialHeaderWasRedacted()
	{
		registerServerErrorMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.header(API_Base.HTTP_HEADER_AUTHORIZATION, API_Base.HTTP_AUTH_TOKEN_BEARER + CALLER_BEARER_TOKEN)
				.withRetry(RETRY_BUDGET_BEYOND_SYNCHRONOUS, RETRY_BACKOFF_SECONDS);
		Test.startTest();
		builder.send();
		Test.stopTest();

		ApiCall__c storedCall = builder.handlerInstance.apiCall;
		Assert.isNull(storedCall.NextRetry__c, 'A failed call whose credential was redacted must not schedule its own retry');
		Assert.isTrue(storedCall.ErrorMessages__c.contains(credentialNotStoredMessage(API_Base.HTTP_HEADER_AUTHORIZATION)),
				'The stored call must say, in the labelled words, why it will not retry');
	}

	/**
	 * @description Tests that a dispatch of a STORED call whose credential header already carries the redaction
	 * marker (a scheduled retry, or the issue-list retry) aborts in validation before any callout, with the
	 * labelled message, and schedules nothing further.
	 */
	@IsTest
	private static void shouldAbortARetryWhoseStoredCredentialHeaderWasRedacted()
	{
		DTO_NameValues storedInputs = new DTO_NameValues();
		storedInputs.add(STORED_HEADERS_KEY, JSON.serialize(new Map<String, String> {API_Base.HTTP_HEADER_AUTHORIZATION => API_Base.REDACTED_HEADER_VALUE}));
		ApiCall__c storedCall = TST_Factory.newOutboundApiCall(UTIL_HttpClient.DefaultOutboundHandler.class.getName(), UserInfo.getUserId());
		storedCall.RequestParameters__c = storedInputs.serialize();

		Test.startTest();
		List<API_Base> handlers = API_Dispatcher.execute(new List<ApiCall__c> {storedCall});
		Integer calloutsMade = UTIL_Limits.callouts().used();
		Test.stopTest();

		Assert.areEqual(0, calloutsMade, 'The abort must happen before any callout leaves the org');
		Assert.isTrue(handlers[0].result.isAborted, 'The retry must abort in validation');
		Assert.isTrue(handlers[0].apiCall.ErrorMessages__c.contains(credentialNotStoredMessage(API_Base.HTTP_HEADER_AUTHORIZATION)),
				'The abort must carry the labelled message naming the header');
		Assert.isNull(handlers[0].apiCall.NextRetry__c, 'An aborted retry must not reschedule itself');
	}

	/**
	 * @description Tests the pass-through on the dispatch path directly (not only at store time): a stored call whose
	 * credential header is merge-field text is neither parked nor aborted - it dispatches, sends, and carries no
	 * credential message - because the platform substitutes the secret at send time on every attempt.
	 */
	@IsTest
	private static void shouldDispatchAStoredMergeFieldCredentialHeaderWithoutParkOrAbort()
	{
		registerSuccessMock();
		DTO_NameValues storedInputs = new DTO_NameValues();
		storedInputs.add(STORED_CREDENTIAL_KEY, TEST_CREDENTIAL);
		storedInputs.add(STORED_PATH_KEY, TEST_PATH);
		storedInputs.add(STORED_HEADERS_KEY, JSON.serialize(new Map<String, String> {HEADER_API_KEY => MERGE_FIELD_API_KEY}));
		ApiCall__c storedCall = TST_Factory.newOutboundApiCall(UTIL_HttpClient.DefaultOutboundHandler.class.getName(), UserInfo.getUserId());
		storedCall.RequestParameters__c = storedInputs.serialize();

		Test.startTest();
		List<API_Base> handlers = API_Dispatcher.execute(new List<ApiCall__c> {storedCall});
		Integer calloutsMade = UTIL_Limits.callouts().used();
		Test.stopTest();

		Assert.areEqual(1, calloutsMade, 'The merge-field header must let the callout leave the org rather than silently skip the send');
		Assert.isFalse(handlers[0].result.isAborted, 'A stored credential merge-field header must not abort the dispatch');
		String errorText = handlers[0].apiCall.ErrorMessages__c;
		Assert.isTrue(errorText == null || !errorText.contains(credentialNotStoredMessage(HEADER_API_KEY)),
				'A merge-field header must not raise the credential-not-stored message');
	}

	/**
	 * @description Builds the credential-not-stored message for one header name, exactly as the framework formats it.
	 *
	 * @param headerName The header name the message calls out
	 *
	 * @return The formatted label text
	 */
	private static String credentialNotStoredMessage(String headerName)
	{
		return String.format(System.Label.RetryApiIssue_CredentialHeaderNotStored, new List<Object> {headerName});
	}

	/**
	 * @description Tests that retries are skipped when the callout budget is exhausted.
	 * The initial attempt proceeds but no retries are performed.
	 */
	@IsTest
	private static void shouldSkipRetriesWhenCalloutBudgetExhausted()
	{
		registerServerErrorMock();
		API_Dispatcher.simulateCalloutBudgetExhausted = true;

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withRetry(2);

		Test.startTest();
		builder.send();
		Test.stopTest();

		Assert.isNull(builder.handlerInstance.apiCall.Retries__c, 'Should not retry when callout budget is exhausted');
	}

	/**
	 * @description The scheduled half of an ad-hoc call honours retryOn(...) the way the synchronous half does: a 409
	 * the caller named is re-sent three times in the transaction and the leftover budget is scheduled with a time.
	 */
	@IsTest
	private static void shouldScheduleTheLeftoverRetryOnlyForTheCodesRetryOnNames()
	{
		API_MockFactory.forService(HANDLER_SERVICE).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_CONFLICT).register();
		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.withRetry(RETRY_BUDGET_BEYOND_SYNCHRONOUS, RETRY_BACKOFF_SECONDS)
				.retryOn(new Set<Integer> {API_Base.HTTP_CONFLICT});

		Test.startTest();
		builder.send();
		Test.stopTest();

		ApiCall__c storedCall = builder.handlerInstance.apiCall;
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, storedCall.Status__c, 'Expected the leftover budget scheduled (Retry) for a code retryOn named, got ' + storedCall.Status__c);
		Assert.isNotNull(storedCall.NextRetry__c, 'Expected a scheduled retry to carry a time, got null');
		Assert.areEqual(UTIL_HttpClient.MAX_SYNCHRONOUS_RETRIES + 1, storedCall.Retries__c,
				'Expected three synchronous attempts and then the scheduled one, got ' + storedCall.Retries__c);
		assertOneSavedRowRetrying(storedCall);
	}

	/**
	 * @description A status retryOn(...) leaves out is final in both halves: a 500 under retryOn({409}) is neither re-sent
	 * in the transaction nor scheduled.
	 */
	@IsTest
	private static void shouldNotScheduleTheLeftoverRetryForAStatusRetryOnLeavesOut()
	{
		registerServerErrorMock();
		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.withRetry(RETRY_BUDGET_BEYOND_SYNCHRONOUS, RETRY_BACKOFF_SECONDS)
				.retryOn(new Set<Integer> {API_Base.HTTP_CONFLICT});

		Test.startTest();
		builder.send();
		Test.stopTest();

		ApiCall__c storedCall = builder.handlerInstance.apiCall;
		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, storedCall.Status__c, 'Expected a status outside retryOn to end Failed, got ' + storedCall.Status__c);
		Assert.isNull(storedCall.NextRetry__c, 'Expected nothing to be scheduled, got ' + storedCall.NextRetry__c);
		Assert.areEqual(0, (storedCall.Retries__c ?? 0).intValue(), 'Expected no synchronous attempt either, got ' + storedCall.Retries__c);
		assertOneSavedRowFailed(storedCall);
	}

	/**
	 * @description An empty set given to retryOn(...) retries nothing: a 500, which is re-sent and then scheduled when
	 * retryOn(...) is not called, is neither re-sent in the transaction nor scheduled, and the call ends Failed with no
	 * next retry time. It runs with budget beyond the synchronous ceiling and a wait, so the empty set is what stops the
	 * retry, never an exhausted budget or a missing wait.
	 */
	@IsTest
	private static void shouldRetryNothingWhenRetryOnIsGivenAnEmptySet()
	{
		registerServerErrorMock();
		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.withRetry(RETRY_BUDGET_BEYOND_SYNCHRONOUS, RETRY_BACKOFF_SECONDS)
				.retryOn(new Set<Integer>());

		Test.startTest();
		builder.send();
		Test.stopTest();

		ApiCall__c storedCall = builder.handlerInstance.apiCall;
		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, storedCall.Status__c, 'Expected a 500 under an empty retryOn set to end Failed, got ' + storedCall.Status__c);
		Assert.isNull(storedCall.NextRetry__c, 'Expected nothing to be scheduled under an empty retryOn set, got ' + storedCall.NextRetry__c);
		Assert.areEqual(0, (storedCall.Retries__c ?? 0).intValue(), 'Expected no re-send in the transaction under an empty retryOn set, got ' + storedCall.Retries__c);
		assertOneSavedRowFailed(storedCall);
	}

	/**
	 * @description retryOn(null) is the same as not calling retryOn(...), unlike an empty set: a 500 to a GET is re-sent
	 * in the transaction under the shared default and the leftover budget is scheduled with a time.
	 */
	@IsTest
	private static void shouldTreatANullRetryOnSetAsNotCalled()
	{
		registerServerErrorMock();
		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.withRetry(RETRY_BUDGET_BEYOND_SYNCHRONOUS, RETRY_BACKOFF_SECONDS)
				.retryOn(null);

		Test.startTest();
		builder.send();
		Test.stopTest();

		ApiCall__c storedCall = builder.handlerInstance.apiCall;
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, storedCall.Status__c, 'Expected the leftover budget to be scheduled (Retry) under retryOn(null), got ' + storedCall.Status__c);
		Assert.areEqual(UTIL_HttpClient.MAX_SYNCHRONOUS_RETRIES + 1, storedCall.Retries__c,
				'Expected three synchronous attempts and then the scheduled one, got ' + storedCall.Retries__c);
		assertOneSavedRowRetrying(storedCall);
	}

	/**
	 * @description A 429 response means "wait": with no retryOn(...) codes the synchronous loop does not re-send it at once
	 * and leaves it to the scheduled retry, which waits the backoff. The loop's break-out is what keeps the count at one
	 * while 429 is in the shared default. The stored row stays at Retry with a time, the pair the retry flow picks up.
	 */
	@IsTest
	private static void shouldLeaveARateLimitResponseToTheScheduledRetry()
	{
		API_MockFactory.forService(HANDLER_SERVICE).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_TOO_MANY_REQUESTS).register();
		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withRetry(RETRY_BUDGET_BEYOND_SYNCHRONOUS, RETRY_BACKOFF_SECONDS);

		Test.startTest();
		builder.send();
		Test.stopTest();

		ApiCall__c storedCall = builder.handlerInstance.apiCall;
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, storedCall.Status__c, 'Expected a 429 to be scheduled (Retry), not re-sent at once, got ' + storedCall.Status__c);
		Assert.isNotNull(storedCall.NextRetry__c, 'Expected a scheduled retry to carry a time, got null');
		Assert.areEqual(1, storedCall.Retries__c, 'Expected one attempt in the transaction, none synchronous, then the scheduled one, got ' + storedCall.Retries__c);
		List<ApiCall__c> retryingCalls = SEL_ApiCall.assertServiceRetrying(storedCall.ServiceName__c);
		Assert.areEqual(1, retryingCalls.size(), 'Expected one saved row at Retry with a time, got ' + retryingCalls.size());
	}

	/**
	 * @description A 425 response means "wait" as a 429 does: with no retryOn(...) codes the synchronous loop does not
	 * re-send it at once, and the stored row stays at Retry with a time for the scheduled retry.
	 */
	@IsTest
	private static void shouldLeaveATooEarlyResponseToTheScheduledRetry()
	{
		API_MockFactory.forService(HANDLER_SERVICE).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_TOO_EARLY).register();
		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withRetry(RETRY_BUDGET_BEYOND_SYNCHRONOUS, RETRY_BACKOFF_SECONDS);

		Test.startTest();
		builder.send();
		Test.stopTest();

		ApiCall__c storedCall = builder.handlerInstance.apiCall;
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, storedCall.Status__c, 'Expected a 425 to be scheduled (Retry), not re-sent at once, got ' + storedCall.Status__c);
		Assert.isNotNull(storedCall.NextRetry__c, 'Expected a scheduled retry to carry a time, got null');
		Assert.areEqual(1, storedCall.Retries__c, 'Expected one attempt in the transaction, none synchronous, then the scheduled one, got ' + storedCall.Retries__c);
		List<ApiCall__c> retryingCalls = SEL_ApiCall.assertServiceRetrying(storedCall.ServiceName__c);
		Assert.areEqual(1, retryingCalls.size(), 'Expected one saved row at Retry with a time, got ' + retryingCalls.size());
	}

	/**
	 * @description A 408 is in the shared default: the loop re-sends it in the transaction and the leftover is scheduled.
	 */
	@IsTest
	private static void shouldResendARequestTimeoutResponseSynchronouslyThenScheduleTheLeftover()
	{
		API_MockFactory.forService(HANDLER_SERVICE).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_REQUEST_TIMEOUT).register();
		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withRetry(RETRY_BUDGET_BEYOND_SYNCHRONOUS, RETRY_BACKOFF_SECONDS);

		Test.startTest();
		builder.send();
		Test.stopTest();

		ApiCall__c storedCall = builder.handlerInstance.apiCall;
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, storedCall.Status__c, 'Expected the leftover budget to be scheduled (Retry), got ' + storedCall.Status__c);
		Assert.isNotNull(storedCall.NextRetry__c, 'Expected a scheduled retry to carry a time, got null');
		Assert.areEqual(UTIL_HttpClient.MAX_SYNCHRONOUS_RETRIES + 1, storedCall.Retries__c,
				'Expected three synchronous attempts and then the scheduled one, got ' + storedCall.Retries__c);
		assertOneSavedRowRetrying(storedCall);
	}

	/**
	 * @description An ad-hoc POST with no idempotency key that got no response fails at once with the labelled line. It
	 * runs with budget beyond the synchronous ceiling, so the refusal comes from the engine, never from an exhausted
	 * budget. The send point sits in the base sendRequest, which the synchronous loop reaches through super, so a throw
	 * escapes the loop and the scheduled retry decides.
	 */
	@IsTest
	private static void shouldFailAnUnkeyedPostAtOnceOnATransportFailure()
	{
		API_MockFactory.forService(HANDLER_SERVICE).withTransportFailure().register();
		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH).withRetry(RETRY_BUDGET_BEYOND_SYNCHRONOUS, RETRY_BACKOFF_SECONDS);

		Test.startTest();
		builder.send();
		Test.stopTest();

		ApiCall__c storedCall = builder.handlerInstance.apiCall;
		String notRepeatedText = String.format(System.Label.OutboundCall_NoResponseNotRepeated, new List<Object> {HANDLER_SERVICE});
		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, storedCall.Status__c, 'Expected a POST with no Idempotency-Key that got no response to end Failed, got ' + storedCall.Status__c);
		Assert.isNull(storedCall.NextRetry__c, 'Expected nothing to be scheduled, got ' + storedCall.NextRetry__c);
		Assert.isTrue(storedCall.ErrorMessages__c.contains(notRepeatedText), 'Expected the row to say the request was not repeated, got ' + storedCall.ErrorMessages__c);
		ApiCall__c savedCall = assertOneSavedRowFailed(storedCall);
		Assert.isTrue(savedCall.ErrorMessages__c.contains(notRepeatedText), 'Expected the saved row to say the request was not repeated, got ' + savedCall.ErrorMessages__c);
	}

	/**
	 * @description The same POST sent with withIdempotencyKey(...) is safe to repeat, so a send that got no response is
	 * scheduled with a time. It is its own test because a second callout made after a failed one in the same test is
	 * refused by the platform before it reaches the mock.
	 */
	@IsTest
	private static void shouldScheduleAKeyedPostOnATransportFailure()
	{
		API_MockFactory.forService(HANDLER_SERVICE).withTransportFailure().register();
		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH)
				.withRetry(RETRY_BUDGET_BEYOND_SYNCHRONOUS, RETRY_BACKOFF_SECONDS)
				.withIdempotencyKey(UTIL_Random.randomName());

		Test.startTest();
		builder.send();
		Test.stopTest();

		ApiCall__c storedCall = builder.handlerInstance.apiCall;
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, storedCall.Status__c, 'Expected a keyed POST that got no response to be scheduled (Retry), got ' + storedCall.Status__c);
		Assert.isNotNull(storedCall.NextRetry__c, 'Expected a scheduled retry to carry a time, got null');
	}

	/**
	 * @description An ad-hoc POST with no idempotency key that gets a 504 is sent once and not again in the transaction:
	 * the external system may have processed it. The scheduled retry refuses it for the same reason, so the row ends
	 * Failed with no time and the labelled line, and its one issue says the external system may have acted. It runs with
	 * budget beyond the synchronous ceiling and a wait, so the refusal comes from the rule, never from a spent budget.
	 */
	@IsTest
	private static void shouldNotResendAnUnkeyedPostAfterAGatewayTimeout()
	{
		registerGatewayTimeoutMock();

		ApiCall__c storedCall = sendUnkeyedPostWithRetryBudget();

		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, storedCall.Status__c, 'Expected a POST without an Idempotency-Key that got a 504 to end Failed, got ' + storedCall.Status__c);
		assertSentOnceAndNotRepeated(storedCall, API_Base.HTTP_GATEWAY_TIMEOUT);
	}

	/**
	 * @description The same ad-hoc POST with no idempotency key that gets a 500 is sent once and ends Failed with the
	 * labelled line and one issue that says the external system may have acted.
	 */
	@IsTest
	private static void shouldNotResendAnUnkeyedPostAfterAnInternalServerError()
	{
		registerServerErrorMock();

		ApiCall__c storedCall = sendUnkeyedPostWithRetryBudget();

		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, storedCall.Status__c, 'Expected a POST without an Idempotency-Key that got a 500 to end Failed, got ' + storedCall.Status__c);
		assertSentOnceAndNotRepeated(storedCall, API_Base.HTTP_INTERNAL_SERVER_ERROR);
	}

	/**
	 * @description The same ad-hoc POST with no idempotency key that gets a 502 is sent once and ends Failed with the
	 * labelled line and one issue that says the external system may have acted.
	 */
	@IsTest
	private static void shouldNotResendAnUnkeyedPostAfterABadGateway()
	{
		registerMock(ERROR_BODY, API_Base.HTTP_BAD_GATEWAY, 'Bad Gateway');

		ApiCall__c storedCall = sendUnkeyedPostWithRetryBudget();

		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, storedCall.Status__c, 'Expected a POST without an Idempotency-Key that got a 502 to end Failed, got ' + storedCall.Status__c);
		assertSentOnceAndNotRepeated(storedCall, API_Base.HTTP_BAD_GATEWAY);
	}

	/**
	 * @description Sends an ad-hoc POST with no idempotency key, retry budget beyond the synchronous ceiling and a wait, to
	 * the mock already registered.
	 *
	 * @return The call row the request left behind.
	 */
	private static ApiCall__c sendUnkeyedPostWithRetryBudget()
	{
		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH)
				.onFailure(UTIL_HttpClient.FailureAction.RETRY_THEN_LOG)
				.withRetry(RETRY_BUDGET_BEYOND_SYNCHRONOUS, RETRY_BACKOFF_SECONDS);

		Test.startTest();
		builder.send();
		Test.stopTest();

		return builder.handlerInstance.apiCall;
	}

	/**
	 * @description Asserts that a POST was sent once and not again: no attempt counted, no time, the labelled line on the
	 * row and one issue that says the external system may have acted.
	 *
	 * @param storedCall The call row the request left behind.
	 * @param statusCode The status the registered mock responds with.
	 */
	private static void assertSentOnceAndNotRepeated(ApiCall__c storedCall, Integer statusCode)
	{
		String notRepeatedText = String.format(System.Label.OutboundCall_ServerErrorNotRepeated, new List<Object> {HANDLER_SERVICE, statusCode});
		Integer attemptsCounted = (storedCall.Retries__c ?? 0).intValue();
		Assert.areEqual(0, attemptsCounted, 'Expected the POST to be sent once after ' + statusCode + ', with no re-send and no scheduled attempt, got ' + attemptsCounted);
		Assert.isNull(storedCall.NextRetry__c, 'Expected nothing to be scheduled, got ' + storedCall.NextRetry__c);
		Assert.isTrue(storedCall.ErrorMessages__c.contains(notRepeatedText), 'Expected the row to say the request was not sent again, got ' + storedCall.ErrorMessages__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(storedCall.ServiceName__c);
		Assert.areEqual(1, issues.size(), 'Expected one issue, got ' + issues.size());
		Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue to say the external system may have acted, got false');
	}

	/**
	 * @description A GET is safe to repeat, so the loop re-sends a 504 at once until the synchronous attempts run out.
	 */
	@IsTest
	private static void shouldResendAGetAtOnceAfterAGatewayTimeout()
	{
		registerGatewayTimeoutMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withRetry(2);
		assertSend(builder, API_Base.HTTP_GATEWAY_TIMEOUT);

		Decimal retries = builder.handlerInstance.apiCall.Retries__c;
		Assert.areEqual(2, (Integer)retries, 'Expected two immediate re-sends of a 504 to a GET, got ' + retries);
	}

	/**
	 * @description A code the caller names in retryOn(...) is the caller's choice, so the loop re-sends it at once
	 * whatever the method: a POST without an Idempotency-Key that gets a 504 named there is re-sent until its two
	 * retries are used up. With no wait given, nothing is scheduled, so the row ends Failed with no time. The budget
	 * ended the call, not the rule, so the row has no line saying the request was not sent again; its one issue still
	 * says the external system may have acted, because that is a fact about the 504 and the POST.
	 */
	@IsTest
	private static void shouldResendAnUnkeyedPostAtOnceAfterAGatewayTimeoutThatRetryOnNames()
	{
		registerGatewayTimeoutMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH)
				.onFailure(UTIL_HttpClient.FailureAction.RETRY_THEN_LOG)
				.withRetry(2)
				.retryOn(new Set<Integer> {API_Base.HTTP_GATEWAY_TIMEOUT});
		assertSend(builder, API_Base.HTTP_GATEWAY_TIMEOUT);

		ApiCall__c storedCall = builder.handlerInstance.apiCall;
		Assert.areEqual(2, (Integer)storedCall.Retries__c, 'Expected two immediate re-sends of a 504 that retryOn named, got ' + storedCall.Retries__c);
		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, storedCall.Status__c, 'Expected the call to end Failed once its retries were used up, got ' + storedCall.Status__c);
		Assert.isNull(storedCall.NextRetry__c, 'Expected nothing to be scheduled without a wait, got ' + storedCall.NextRetry__c);
		assertFlaggedWithoutTheNotRepeatedLine(storedCall);
	}

	/**
	 * @description A code the caller names in retryOn(...) is the caller's choice in the later retry too: a POST without
	 * an Idempotency-Key that gets a 504 named there is re-sent three times in the transaction, and the leftover budget
	 * is then scheduled, so the row stays at Retry with a time and four attempts counted. The row has no line saying the
	 * request was not sent again, and its one issue says the external system may have acted, because that is a fact
	 * about the 504 and the POST whatever the caller chose.
	 */
	@IsTest
	private static void shouldScheduleTheLeftoverRetryForAGatewayTimeoutRetryOnNamesOnAnUnkeyedPost()
	{
		registerGatewayTimeoutMock();
		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH)
				.onFailure(UTIL_HttpClient.FailureAction.RETRY_THEN_LOG)
				.withRetry(RETRY_BUDGET_BEYOND_SYNCHRONOUS, RETRY_BACKOFF_SECONDS)
				.retryOn(new Set<Integer> {API_Base.HTTP_GATEWAY_TIMEOUT});

		Test.startTest();
		builder.send();
		Test.stopTest();

		ApiCall__c storedCall = builder.handlerInstance.apiCall;
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, storedCall.Status__c, 'Expected the leftover budget scheduled (Retry) for a 504 retryOn named, got ' + storedCall.Status__c);
		Assert.isNotNull(storedCall.NextRetry__c, 'Expected a scheduled retry to carry a time, got null');
		Assert.areEqual(UTIL_HttpClient.MAX_SYNCHRONOUS_RETRIES + 1, storedCall.Retries__c,
				'Expected three synchronous attempts and then the scheduled one, got ' + storedCall.Retries__c);
		assertFlaggedWithoutTheNotRepeatedLine(storedCall);
	}

	/**
	 * @description Asserts that a POST the caller chose to repeat through retryOn(...) carries no line saying it was not
	 * sent again, and that its one issue says the external system may have acted.
	 *
	 * @param storedCall The call the builder made, read from its handler.
	 */
	private static void assertFlaggedWithoutTheNotRepeatedLine(ApiCall__c storedCall)
	{
		String notRepeatedText = String.format(System.Label.OutboundCall_ServerErrorNotRepeated, new List<Object> {HANDLER_SERVICE, API_Base.HTTP_GATEWAY_TIMEOUT});
		Assert.isFalse(storedCall.ErrorMessages__c?.contains(notRepeatedText) == true, 'Expected no not-sent-again line, got ' + storedCall.ErrorMessages__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(storedCall.ServiceName__c);
		Assert.areEqual(1, issues.size(), 'Expected one issue, got ' + issues.size());
		Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue to say the external system may have acted, got false');
	}

	/**
	 * @description Asserts that the call was saved, not only held in memory: one saved row for the service, at Retry with
	 * a time, with the attempt count the handler's copy holds.
	 *
	 * @param storedCall The call the builder made, read from its handler.
	 */
	private static void assertOneSavedRowRetrying(ApiCall__c storedCall)
	{
		List<ApiCall__c> savedCalls = SEL_ApiCall.assertServiceRetrying(storedCall.ServiceName__c);
		Assert.areEqual(1, savedCalls.size(), 'Expected one saved row at Retry with a time, got ' + savedCalls.size());
		Assert.areEqual(storedCall.Retries__c, savedCalls[0].Retries__c, 'Expected the saved attempt count ' + storedCall.Retries__c + ', got ' + savedCalls[0].Retries__c);
	}

	/**
	 * @description Asserts that the call was saved, not only held in memory: one saved row for the service, Failed with no
	 * next retry time and no attempt spent.
	 *
	 * @param storedCall The call the builder made, read from its handler.
	 *
	 * @return The saved row.
	 */
	private static ApiCall__c assertOneSavedRowFailed(ApiCall__c storedCall)
	{
		List<ApiCall__c> savedCalls = SEL_ApiCall.assertServiceFailed(storedCall.ServiceName__c);
		Assert.areEqual(1, savedCalls.size(), 'Expected one saved Failed row, got ' + savedCalls.size());
		Assert.isNull(savedCalls[0].NextRetry__c, 'Expected no next retry time on the saved row, got ' + savedCalls[0].NextRetry__c);
		Assert.areEqual(0, (savedCalls[0].Retries__c ?? 0).intValue(), 'Expected no attempt spent on the saved row, got ' + savedCalls[0].Retries__c);
		return savedCalls[0];
	}

	/**
	 * @description A POST sent with withIdempotencyKey(...) is safe to repeat, so the loop re-sends a 504 at once until the
	 * synchronous attempts run out.
	 */
	@IsTest
	private static void shouldResendAKeyedPostAtOnceAfterAGatewayTimeout()
	{
		registerGatewayTimeoutMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH)
				.withRetry(2)
				.withIdempotencyKey(UTIL_Random.randomName());
		assertSend(builder, API_Base.HTTP_GATEWAY_TIMEOUT);

		Decimal retries = builder.handlerInstance.apiCall.Retries__c;
		Assert.areEqual(2, (Integer)retries, 'Expected two immediate re-sends of a 504 to a keyed POST, got ' + retries);
	}

	/**
	 * @description Executes the request within a Test.startTest/stopTest boundary and asserts
	 * the handler was not unexpectedly aborted during validation.
	 *
	 * @param builder The configured request builder
	 *
	 * @return The HTTP response from the callout
	 */
	private static HttpResponse assertSend(UTIL_HttpClient.RequestBuilder builder)
	{
		Test.startTest();
		HttpResponse response = builder.send();
		Test.stopTest();
		assertNotAborted(builder);
		return response;
	}

	/**
	 * @description Executes the request, asserts not aborted, and verifies the expected HTTP status code.
	 *
	 * @param builder The configured request builder
	 * @param expectedStatusCode The expected HTTP status code
	 *
	 * @return The HTTP response from the callout
	 */
	private static HttpResponse assertSend(UTIL_HttpClient.RequestBuilder builder, Integer expectedStatusCode)
	{
		HttpResponse response = assertSend(builder);
		Assert.areEqual(expectedStatusCode, response.getStatusCode(), 'Expected HTTP ' + expectedStatusCode + ', got ' + response.getStatusCode());
		return response;
	}

	/**
	 * @description Asserts that the handler was not unexpectedly aborted during validation.
	 * Surfaces the actual abort reason instead of a cryptic NullPointerException on the response.
	 *
	 * @param builder The request builder after send() has been called
	 */
	private static void assertNotAborted(UTIL_HttpClient.RequestBuilder builder)
	{
		Assert.isFalse(builder.handlerInstance.result.isAborted, 'Call was unexpectedly aborted: ' + builder.handlerInstance.result.errors);
	}

	/**
	 * @description Delegate handler that decides there is nothing to send. It accepts the API call and
	 * returns without a callout, so the call ends with no response and no recorded error.
	 */
	public class TestSilentHandler extends API_Outbound
	{
		/**
		 * @description Configure handler with no triggering record requirement.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
		}

		/**
		 * @description Accepts the API call without performing a callout.
		 *
		 * @param apiCallRecord The API call to process
		 */
		public override void process(ApiCall__c apiCallRecord)
		{
			setApiCall(apiCallRecord);
		}
	}

	/**
	 * @description Delegate handler that fails with an exception carrying no readable message, so the
	 * first error recorded against it is blank.
	 */
	public class TestBlankMessageHandler extends API_Outbound
	{
		/**
		 * @description Configure handler with no triggering record requirement.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
		}

		/**
		 * @description Fails the API call with an exception whose message is blank.
		 *
		 * @param apiCallRecord The API call to process
		 */
		public override void process(ApiCall__c apiCallRecord)
		{
			setApiCall(apiCallRecord);
			throw new BlankMessageException(BLANK_EXCEPTION_MESSAGE);
		}
	}

	/**
	 * @description Exception a delegate handler throws with a blank message, standing in for a
	 * subscriber exception that records no readable text against the call.
	 */
	public class BlankMessageException extends Exception
	{
	}
}