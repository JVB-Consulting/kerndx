// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests the behavior of the [API_Base] class, covering ServiceCallResult properties,
 * WebserviceStatus enum behavior, and base-class validation logic.
 *
 * @see API_Base
 * @see DML_ThrowingLockProxy_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssTypeCount,PMD.NcssCount')
@IsTest(seeAllData=false isParallel=true)
private class API_Base_TEST
{
	/**
	 * @description Error message expected when status text is incorrect.
	 */
	private static final String MSG_WRONG_STATUS = 'Incorrect status text';

	/**
	 * @description The bearer credential the Authorization probe header carries; random so no fixed value can pass by
	 * coincidence.
	 */
	private static final String REDACTION_PROBE_TOKEN = 'Bearer ' + UTIL_Random.randomAlphanumeric(24);
	/**
	 * @description The session cookie the Set-Cookie probe header carries; random for the same reason.
	 */
	private static final String REDACTION_PROBE_COOKIE = 'sid=' + UTIL_Random.randomAlphanumeric(16);
	/**
	 * @description The secret a vendor's proprietary header carries, proving a fragment match redacts an unlisted
	 * header name; random for the same reason.
	 */
	private static final String REDACTION_PROBE_VENDOR_SECRET = UTIL_Random.randomAlphanumeric(20);
	/**
	 * @description The value of the non-credential header, which must be copied through as sent.
	 */
	private static final String REDACTION_PROBE_CONTENT_TYPE = 'application/json';
	/**
	 * @description A bare credential merge field: placeholder text holding no secret, so it is kept verbatim.
	 */
	private static final String REDACTION_PROBE_MERGE_FIELD = '{!$Credential.ProbeCredential.ApiKey}';
	/**
	 * @description The scheme-prefixed form of a credential merge field, proving the prefix is matched anywhere in the
	 * value rather than only at its start.
	 */
	private static final String REDACTION_PROBE_BEARER_MERGE_FIELD = 'Bearer {!$Credential.ProbeCredential.Token}';
	/**
	 * @description A merge expression that is not a credential reference, proving an arbitrary '{!' earns no
	 * pass-through and is still redacted on a credential header.
	 */
	private static final String REDACTION_PROBE_PLAIN_EXPRESSION = '{!$Label.SomeLabel}';
	/**
	 * @description The Authorization header in upper case, proving the name comparison is case-insensitive.
	 */
	private static final String REDACTION_HEADER_UPPER_AUTHORIZATION = 'AUTHORIZATION';
	/**
	 * @description The response header that carries a cookie, an exact CREDENTIAL_HEADER_NAMES member.
	 */
	private static final String REDACTION_HEADER_SET_COOKIE = 'Set-Cookie';
	/**
	 * @description The vendor key header in lower case, an exact CREDENTIAL_HEADER_NAMES member; carries a blank value
	 * here, proving an absent credential stays blank rather than reading as redacted.
	 */
	private static final String REDACTION_HEADER_LOWER_API_KEY = 'x-api-key';
	/**
	 * @description A proprietary header on no list, caught only by the 'secret' name fragment.
	 */
	private static final String REDACTION_HEADER_VENDOR_SECRET = 'X-Vendor-Secret';
	/**
	 * @description A header whose name looks like a credential's but that holds no secret, caught by the 'token' name
	 * fragment. It shows that the framework redacts more than it must, on purpose: it redacts this header rather than
	 * risk letting a real credential through.
	 */
	private static final String REDACTION_HEADER_TOKEN_TYPE = 'X-Token-Type';
	/**
	 * @description The value of that metadata header: a public OAuth type identifier, not a secret, and redacted all
	 * the same.
	 */
	private static final String REDACTION_PROBE_TOKEN_TYPE = 'urn:ietf:params:oauth:token-type:access_token';
	/**
	 * @description The tracing header, operational rather than credential-bearing, which must stay visible.
	 */
	private static final String REDACTION_HEADER_TRACE_PARENT = 'traceparent';
	/**
	 * @description The tracing header's value; random so its pass-through cannot pass by coincidence.
	 */
	private static final String REDACTION_PROBE_TRACE_PARENT = '00-' + UTIL_Random.randomAlphanumeric(16) + '-01';
	/**
	 * @description An operational header whose name ends in 'Key' yet carries no secret, proving 'key' is deliberately
	 * absent from CREDENTIAL_HEADER_NAME_FRAGMENTS.
	 */
	private static final String REDACTION_HEADER_IDEMPOTENCY_KEY = 'Idempotency-Key';
	/**
	 * @description That header's value; random so its pass-through cannot pass by coincidence.
	 */
	private static final String REDACTION_PROBE_IDEMPOTENCY_KEY = 'order-' + UTIL_Random.randomAlphanumeric(8);

	/**
	 * @description The name of the record the inbound lock-retry handler registers, read back to prove the retried commit
	 * saved it.
	 */
	private static final String SAVED_RECORD_NAME = 'Saved after an inbound lock retry';

	/**
	 * @description The message the after-commit handler fails with once its records are saved.
	 */
	private static final String MESSAGE_THROWN_AFTER_COMMIT = 'the handler threw after its records were saved';

	/**
	 * @description The message a stopwatch refuses its start with when it has stopped and was not reset. A stopwatch
	 * that is asked to stop while it is not running refuses with a different message, which is how a test tells the two
	 * refusals apart.
	 */
	private static final String MESSAGE_STOPWATCH_NEEDS_A_RESET = 'Stopwatch must be reset before being restarted.';

	/**
	 * @description The length of the request, response and request parameters fields of an API call: 131,072 characters.
	 */
	private static final Integer PAYLOAD_FIELD_LENGTH = SEL_ApiCall.REQUEST_LENGTH;

	/**
	 * @description The length of a payload the masking tests make too long for its field.
	 */
	private static final Integer OVERSIZED_PAYLOAD_LENGTH = 140000;

	/**
	 * @description The pattern of the secret most masking tests hide: the word secret, a hyphen, then letters and digits.
	 */
	private static final String SECRET_PATTERN = 'secret-[A-Za-z0-9]+';

	/**
	 * @description A secret that SECRET_PATTERN finds. Its last part is random, so no fixed text can pass by chance.
	 */
	private static final String SECRET = 'secret-' + UTIL_Random.randomAlphanumeric(12);

	/**
	 * @description The text a test rule writes in place of a secret.
	 */
	private static final String HIDDEN_TOKEN = '[HIDDEN]';

	/**
	 * @description The text the rule limited to the first test handler writes in place of a secret.
	 */
	private static final String FIRST_HANDLER_TOKEN = '[FIRST]';

	/**
	 * @description The text the rule limited to the second test handler writes in place of a secret.
	 */
	private static final String SECOND_HANDLER_TOKEN = '[SECOND]';

	/**
	 * @description The pattern of a second kind of secret, which the rule that applies to every caller hides.
	 */
	private static final String OPEN_SECRET_PATTERN = 'open-[A-Za-z0-9]+';

	/**
	 * @description A secret that OPEN_SECRET_PATTERN finds, with a random last part.
	 */
	private static final String OPEN_SECRET = 'open-' + UTIL_Random.randomAlphanumeric(12);

	/**
	 * @description The text the rule that applies to every caller writes in place of an open secret.
	 */
	private static final String UNSCOPED_TOKEN = '[UNSCOPED]';

	/**
	 * @description The word a growing test rule finds. The rule writes the word twice in its place, so every pass over
	 * the text adds the word again, and the saved text shows how many passes ran over it.
	 */
	private static final String GROWING_WORD = 'grow';

	/**
	 * @description The three dots the framework puts at the end of a text it cuts to fit its field.
	 */
	private static final String CUT_MARKER = '...';

	/**
	 * @description The pattern of the three dots the framework puts at the end of a text it cuts to fit its field. A
	 * raw payload has no such dots, so a rule with this pattern changes a text only when a second pass runs over the cut
	 * text.
	 */
	private static final String CUT_MARKER_PATTERN = '\\.\\.\\.$';

	/**
	 * @description The text the rule with CUT_MARKER_PATTERN writes in place of the three dots. It is shorter than the
	 * dots, so the changed text still fits its field and is not cut again.
	 */
	private static final String CUT_MARKER_REPLACEMENT = '#';

	/**
	 * @description A pattern that is not a valid regular expression, so a rule with it fails every time it runs.
	 */
	private static final String BROKEN_PATTERN = '([bad';

	/**
	 * @description A pattern that never matches the payloads of the tests. A rule with it gives a field a masking pass
	 * that changes nothing.
	 */
	private static final String NEVER_MATCHING_PATTERN = 'zz-never-zz';

	/**
	 * @description How many small secret values the token array request holds before its last, long value.
	 */
	private static final Integer SMALL_TOKEN_COUNT = 9000;

	/**
	 * @description The end of the token array request: the close of its last value, object and array.
	 */
	private static final String TOKEN_ARRAY_TAIL = '"}]';

	/**
	 * @description The length of the letters after `secret-` in the long secret of the test where masking shrinks a
	 * request to fit its field.
	 */
	private static final Integer LONG_SECRET_LENGTH = 30000;

	/**
	 * @description The length of the padding after the long secret: the request with the secret is longer than its field,
	 * and the request with the secret hidden fits.
	 */
	private static final Integer PADDING_THAT_FITS_AFTER_MASKING_LENGTH = 110000;

	/**
	 * @description The length of the longest request the masking reads: 2,000,000 characters.
	 */
	private static final Integer LONGEST_REQUEST_LENGTH = 2000000;

	/**
	 * @description How many small secret values the longest token array request holds before its last value: as many as
	 * fit in the same share of the text as in the token array request of the field length.
	 */
	private static final Integer LONGEST_REQUEST_SMALL_TOKEN_COUNT = 137329;

	/**
	 * @description A small secret value as it appears in the token array request. No masked text may still hold it.
	 */
	private static final String SMALL_TOKEN_VALUE = '"x"';

	/**
	 * @description The response body the masking tests' mock sends back.
	 */
	private static final String SUCCESS_RESPONSE_BODY = '{}';

	/**
	 * @description The address the masking test handler sends its requests to, when a test sets no other one.
	 */
	private static final String MASKING_TEST_URL = 'https://example.com/masking-test';

	/**
	 * @description A service name that no API setting names, so no handler class is known for it.
	 */
	private static final String SERVICE_WITH_NO_SETTING = 'ServiceWithNoSetting';

	/**
	 * @description The start of the title of the file that holds a whole request body.
	 */
	private static final String REQUEST_FILE_TITLE = 'RequestBody';

	/**
	 * @description The start of the title of the file that holds a whole response body.
	 */
	private static final String RESPONSE_FILE_TITLE = 'ResponseBody';

	/**
	 * @description The start of the title of the file that holds a whole address.
	 */
	private static final String URL_FILE_TITLE = 'Url';

	/**
	 * @description The start of the title of the file that holds the whole request parameters.
	 */
	private static final String PARAMETERS_FILE_TITLE = 'RequestParameters';

	/**
	 * @description The name of the request parameter the masking tests fill.
	 */
	private static final String PARAMETER_NAME = 'note';

	/**
	 * @description Finds the CPU time in the details of a masking performance log entry, for example "CPU: 12ms".
	 */
	private static final Pattern CPU_IN_DETAILS = Pattern.compile('CPU: (\\d+)ms');

	/**
	 * @description The request body the masking test handler sends in the running test.
	 */
	private static String maskingTestRequestBody;

	/**
	 * @description The address the masking test handler sends its request to in the running test.
	 */
	private static String maskingTestUrl = MASKING_TEST_URL;

	/**
	 * @description The response body the inbound masking test handler writes, after its records are saved, in the
	 * running test.
	 */
	private static String maskingTestResponseBody;

	/**
	 * @description The response the inbound tests write when the response itself is not what they test. Its last part
	 * is random, so no fixed text can pass by chance.
	 */
	private static final String INBOUND_RESPONSE_BODY = '{"status":"accepted","reference":"' + UTIL_Random.randomAlphanumeric(12) + '"}';

	/**
	 * @description The idempotency key the replay test sends twice, with a random part.
	 */
	private static final String IDEMPOTENCY_KEY = 'masking-test-' + UTIL_Random.randomAlphanumeric(12);

	/**
	 * @description How many times the inbound lock-retry handler wrote the REST response in the running test.
	 */
	private static Integer responseWriteCount = 0;

	/**
	 * @description Tests that setting failed to true on ServiceCallResult produces correct state.
	 *
	 * @see API_Base.ServiceCallResult.hasFailed
	 */
	@IsTest
	private static void serviceCallResultFailedState()
	{
		API_Base.ServiceCallResult callResult = new API_Base.ServiceCallResult();

		callResult.hasFailed = true;

		Assert.isTrue(callResult.hasFailed, 'Should be in failed state');
		Assert.isFalse(callResult.isSuccess, 'Should not be in success state');
		Assert.isFalse(callResult.isAborted, 'Should not be in aborted state');
		Assert.areEqual('Failed', callResult.statusText, MSG_WRONG_STATUS);
	}

	/**
	 * @description Tests that setting success to true on ServiceCallResult produces correct state.
	 *
	 * @see API_Base.ServiceCallResult.isSuccess
	 */
	@IsTest
	private static void serviceCallResultSuccessState()
	{
		API_Base.ServiceCallResult callResult = new API_Base.ServiceCallResult();

		callResult.isSuccess = true;

		Assert.isTrue(callResult.isSuccess, 'Should be in success state');
		Assert.isFalse(callResult.hasFailed, 'Should not be in failed state');
		Assert.isFalse(callResult.isAborted, 'Should not be in aborted state');
		Assert.areEqual('Completed', callResult.statusText, MSG_WRONG_STATUS);
	}

	/**
	 * @description Tests that setting aborted to true on ServiceCallResult produces correct state.
	 *
	 * @see API_Base.ServiceCallResult.isAborted
	 */
	@IsTest
	private static void serviceCallResultAbortedState()
	{
		API_Base.ServiceCallResult callResult = new API_Base.ServiceCallResult();

		callResult.isAborted = true;

		Assert.isTrue(callResult.isAborted, 'Should be in aborted state');
		Assert.isFalse(callResult.isSuccess, 'Should not be in success state');
		Assert.isFalse(callResult.hasFailed, 'Should not be in failed state');
		Assert.areEqual('Aborted', callResult.statusText, MSG_WRONG_STATUS);
	}

	/**
	 * @description Tests that statusText returns the string representation when status is null.
	 *
	 * @see API_Base.ServiceCallResult.statusText
	 */
	@IsTest
	private static void serviceCallResultStatusTextWhenNull()
	{
		API_Base.ServiceCallResult callResult = new API_Base.ServiceCallResult();

		String statusText = callResult.statusText;

		Assert.areEqual(String.valueOf((Object)null), statusText, 'Uninitialized status should return null string');
	}

	/**
	 * @description Tests that setting failed to false does not change the existing status.
	 *
	 * @see API_Base.ServiceCallResult.hasFailed
	 */
	@IsTest
	private static void serviceCallResultSetFailedFalsePreservesState()
	{
		API_Base.ServiceCallResult callResult = new API_Base.ServiceCallResult();
		callResult.isSuccess = true;

		callResult.hasFailed = false;

		Assert.isTrue(callResult.isSuccess, 'Should still be in success state');
	}

	/**
	 * @description Tests that the errors list is initialized and accumulates errors.
	 *
	 * @see API_Base.ServiceCallResult.errors
	 */
	@IsTest
	private static void serviceCallResultErrorsAccumulate()
	{
		API_Base.ServiceCallResult callResult = new API_Base.ServiceCallResult();

		callResult.errors.add('Error 1');
		callResult.errors.add('Error 2');

		Assert.areEqual(2, callResult.errors.size(), 'Should have accumulated both errors');
	}

	/**
	 * @description Tests HTTP status code constants are defined correctly.
	 *
	 * @see API_Base.HTTP_OK
	 */
	@IsTest
	private static void httpStatusCodeConstants()
	{
		Assert.areEqual(200, API_Base.HTTP_OK, 'HTTP_OK should be 200');
		Assert.areEqual(201, API_Base.HTTP_CREATED, 'HTTP_CREATED should be 201');
		Assert.areEqual(400, API_Base.HTTP_BAD_REQUEST, 'HTTP_BAD_REQUEST should be 400');
		Assert.areEqual(500, API_Base.HTTP_INTERNAL_SERVER_ERROR, 'HTTP_INTERNAL_SERVER_ERROR should be 500');
	}

	/**
	 * @description Tests that the WebserviceStatus enum contains the expected values.
	 *
	 * @see API_Base.WebserviceStatus
	 */
	@IsTest
	private static void apiCallStatusEnumValues()
	{
		List<API_Base.WebserviceStatus> statuses = API_Base.WebserviceStatus.values();

		Assert.areEqual(3, statuses.size(), 'Should have exactly 3 status values');
		Assert.isNotNull(API_Base.WebserviceStatus.COMPLETED, 'COMPLETED should exist');
		Assert.isNotNull(API_Base.WebserviceStatus.FAILED, 'FAILED should exist');
		Assert.isNotNull(API_Base.WebserviceStatus.ABORTED, 'ABORTED should exist');
	}

	/**
	 * @description Tests that a masking rule with an invalid regex is handled gracefully by
	 * the framework's LogAndContinue default — the rule's failure is recorded on the
	 * MaskingResult but the API call itself completes normally.
	 *
	 * @see UTIL_FrameworkMasker.handleRuleFailure
	 */
	@IsTest
	private static void invalidMaskingRuleRegexHandledGracefully()
	{
		LOG_Builder.ignoreTestMode = true;

		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, newRegexRule('BadPattern', BROKEN_PATTERN, HIDDEN_TOKEN, null), API_PostExample.class.getName());

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId());

		Test.startTest();
		API_Dispatcher.execute(apiCall);
		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(API_PostExample.class.getName());
	}

	/**
	 * @description Tests that the disabled API check correctly aborts a service call.
	 *
	 * @see API_Base.isDisabled
	 * @see API_Base.performValidation
	 */
	@IsTest
	private static void disabledApiIsAborted()
	{
		TST_Factory.disableAllApis();

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId());

		Test.startTest();

		API_Base handler = API_Dispatcher.execute(apiCall);

		Test.stopTest();

		Assert.isTrue(handler.result.isAborted, 'Disabled API should abort');
	}

	/**
	 * @description Tests that a disabled API via feature flag correctly aborts a service call.
	 *
	 * @see API_Base.isDisabled
	 * @see API_Base.FLAG_DISABLE_ALL_APIS
	 */
	@IsTest
	private static void disabledApiIsAbortedViaFeatureFlag()
	{
		TST_Factory.newFeatureFlag(API_Base.FLAG_DISABLE_ALL_APIS);

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId());

		Test.startTest();

		API_Base handler = API_Dispatcher.execute(apiCall);

		Test.stopTest();

		Assert.isTrue(handler.result.isAborted, 'API disabled via feature flag should abort');
	}

	/**
	 * @description Tests that mocking via feature flag returns a mock response.
	 *
	 * @see API_Base.isMocking
	 * @see API_Base.FLAG_MOCK_ALL_APIS
	 */
	@IsTest
	private static void mockAllApisViaFeatureFlag()
	{
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_ALL_APIS);

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId());

		Test.startTest();

		API_Base handler = API_Dispatcher.execute(apiCall);

		Test.stopTest();

		Assert.isTrue(handler.result.isMocked, 'API should be mocking via feature flag');
		Assert.isTrue(handler.result.isSuccess, 'Mocked API should succeed');
	}

	/**
	 * @description Tests that the correlationId property is populated after executing an API call.
	 *
	 * @see API_Base.correlationId
	 */
	@IsTest
	private static void correlationIdIsPopulatedAfterExecution()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId());

		Test.startTest();

		API_Base handler = API_Dispatcher.execute(apiCall);

		Test.stopTest();

		Assert.isNotNull(handler.correlationId, 'Correlation ID should be populated');
		Assert.areNotEqual('', handler.correlationId, 'Correlation ID should not be empty');
	}

	/**
	 * @description Tests that fromHttpString returns null when given a null method string.
	 *
	 * @see API_Base.fromHttpString
	 */
	@IsTest
	private static void fromHttpStringShouldReturnNullForNullInput()
	{
		Test.startTest();

		API_Base.HttpMethod result = API_Base.fromHttpString(null);

		Test.stopTest();

		Assert.isNull(result, 'Should return null for null input');
	}

	/**
	 * @description Tests that fromHttpString correctly parses standard HTTP method strings.
	 *
	 * @see API_Base.fromHttpString
	 */
	@IsTest
	private static void fromHttpStringShouldParseValidMethods()
	{
		Assert.areEqual(API_Base.HttpMethod.GET, API_Base.fromHttpString('GET'), 'Should parse GET');
		Assert.areEqual(API_Base.HttpMethod.POST, API_Base.fromHttpString('POST'), 'Should parse POST');
		Assert.areEqual(API_Base.HttpMethod.DELETION, API_Base.fromHttpString('DELETE'), 'Should parse DELETE');
	}

	/**
	 * @description Tests that toHttpString converts enum values to correct HTTP method strings.
	 *
	 * @see API_Base.toHttpString
	 */
	@IsTest
	private static void toHttpStringShouldConvertEnumValues()
	{
		Assert.areEqual('GET', API_Base.toHttpString(API_Base.HttpMethod.GET), 'Should convert GET');
		Assert.areEqual('DELETE', API_Base.toHttpString(API_Base.HttpMethod.DELETION), 'Should convert DELETION to DELETE');
	}

	/**
	 * @description Tests that the permission check for ContentVersion creation is evaluated
	 * when content exceeds the field maximum length without simulateStoreToFile.
	 */
	@IsTest
	private static void shouldEvaluateCreatePermissionWhenContentExceedsFieldLength()
	{
		ApiCall__c apiCallRecord = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId());

		Test.startTest();

		API_Base handler = API_Dispatcher.execute(apiCallRecord);

		Test.stopTest();

		String longUrl = '';
		for(Integer i = 0; i <= SEL_ApiCall.URL_LENGTH / 10; i++)
		{
			longUrl += 'abcdefghij';
		}
		handler.result.url = longUrl;

		List<ContentVersion> versions = handler.createRelatedContentVersions();

		Boolean hasUrlFile = false;
		for(ContentVersion version : versions)
		{
			if(version.Title.contains('Url'))
			{
				hasUrlFile = true;
			}
		}
		Assert.isTrue(hasUrlFile, 'Should create ContentVersion file for URL exceeding field length');
	}

	/**
	 * @description Tests that subscriber validation errors abort the service call.
	 *
	 * @see API_Base.performValidation
	 * @see API_Base.getValidationErrors
	 */
	@IsTest
	private static void shouldAbortWhenSubscriberValidationReturnsErrors()
	{
		API_PostExample.simulatedValidationError = 'Subscriber validation failed';

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId());

		Test.startTest();

		API_Base handler = API_Dispatcher.execute(apiCall);

		Test.stopTest();

		Assert.isTrue(handler.result.isAborted, 'Should abort when subscriber returns validation errors');
	}

	/**
	 * @description Tests that Safe Mode can be entered and exited correctly.
	 *
	 * @see API_Base.SafeModeContext
	 * @see API_Base.enterSafeMode
	 * @see API_Base.isSafeModeActive
	 */
	@IsTest
	private static void shouldActivateAndDeactivateSafeMode()
	{
		Assert.isFalse(API_Base.isSafeModeActive(), 'Safe Mode should not be active initially');

		API_Base.SafeModeContext safeMode = API_Base.enterSafeMode();

		Assert.isTrue(API_Base.isSafeModeActive(), 'Safe Mode should be active after entering');

		safeMode.close();

		Assert.isFalse(API_Base.isSafeModeActive(), 'Safe Mode should not be active after exiting');
	}

	/**
	 * @description Tests that Safe Mode supports nested scopes correctly.
	 *
	 * @see API_Base.SafeModeContext
	 */
	@IsTest
	private static void shouldSupportNestedSafeModeContexts()
	{
		API_Base.SafeModeContext outerScope = API_Base.enterSafeMode();
		API_Base.SafeModeContext innerScope = API_Base.enterSafeMode();

		Assert.isTrue(API_Base.isSafeModeActive(), 'Safe Mode should be active with nested scopes');

		innerScope.close();

		Assert.isTrue(API_Base.isSafeModeActive(), 'Safe Mode should still be active after inner close');

		outerScope.close();

		Assert.isFalse(API_Base.isSafeModeActive(), 'Safe Mode should be inactive after all scopes close');
	}

	/**
	 * @description Tests that calling close multiple times is idempotent (only decrements once).
	 *
	 * @see API_Base.SafeModeContext
	 */
	@IsTest
	private static void safeModeCloseShouldBeIdempotent()
	{
		API_Base.SafeModeContext safeMode = API_Base.enterSafeMode();

		safeMode.close();
		safeMode.close();

		Assert.isFalse(API_Base.isSafeModeActive(), 'Safe Mode should not be active');
		Assert.areEqual(0, API_Base.safeModeActiveScopeCount, 'Scope count should not be negative');
	}

	/**
	 * @description Tests that DML is rolled back when Safe Mode is active during outbound processing.
	 *
	 * @see API_Base.commitWork
	 * @see API_Base.SafeModeContext
	 */
	@IsTest
	private static void shouldRollbackDmlWhenSafeModeIsActive()
	{
		API_Base.SafeModeContext safeMode = API_Base.enterSafeMode();

		try
		{
			ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId());

			Test.startTest();

			API_Dispatcher.execute(apiCall);

			Test.stopTest();
		}
		finally
		{
			safeMode.close();
		}

		List<ApiCall__c> apiCalls = new SEL_ApiCall().toList();
		Assert.isTrue(apiCalls.isEmpty(), 'DML should be rolled back in Safe Mode');
	}

	/**
	 * @description Tests that creating a handler pushes no logging context: the code that runs a handler owns the
	 * context, around each piece of the handler's work.
	 *
	 * @see API_Base.configure
	 */
	@IsTest
	private static void shouldPushNoContextWhenAHandlerIsOnlyCreated()
	{
		API_InboundTestHelper.setupRestContext();

		Integer depthBeforeCreating = LOG_Engine.getContextStackDepth();

		Test.startTest();

		new API_Echo();

		Test.stopTest();

		Assert.areEqual(depthBeforeCreating, LOG_Engine.getContextStackDepth(), 'Creating a handler pushes no logging context.');
	}

	/**
	 * @description Tests that a validation exception in getValidationErrors is caught by the base class handler.
	 *
	 * @see API_Base.performValidation
	 */
	@IsTest
	private static void shouldHandleValidationException()
	{
		API_PostExample.simulateValidationThrow = true;

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId());

		Test.startTest();

		API_Base handler = API_Dispatcher.execute(apiCall);

		Test.stopTest();

		Assert.isTrue(handler.result.isAborted, 'Should abort when validation throws an exception');
	}

	/**
	 * @description Tests that a row lock while an inbound handler's records are saved retries the save once: the first
	 * commit attempt is refused with the platform's lock refusal, the second saves the record, the call ends Completed on
	 * one row, and the caller gets one response, a success. The stand-in is set after the test has started, so it
	 * refuses only the commit's statements.
	 *
	 * @see API_Base.commitWork
	 */
	@IsTest
	private static void shouldRetryAnInboundCommitOnceOnARowLockAndRespondOnce()
	{
		responseWriteCount = 0;
		String serviceName = RecordSavingInbound.class.getName();

		API_Base handler = dispatchInboundWithOneLockRefusal(serviceName);

		List<ApiCall__c> completed = SEL_ApiCall.assertServiceCompleted(serviceName);
		Assert.areEqual(1, completed.size(), 'Expected one call row after the retried commit, got ' + completed.size());
		Assert.areEqual(completed[0].Id, handler.apiCall.Id, 'Expected the handler to hold the saved row\'s Id, got ' + handler.apiCall.Id);
		Assert.areEqual(1, responseWriteCount, 'Expected the REST response to be written once, got ' + responseWriteCount);
		Integer statusCode = RestContext.response.statusCode;
		Assert.areEqual(API_Base.HTTP_OK, statusCode, 'Expected the caller to get a response with status 200, got ' + statusCode);
		Integer savedCount = new SEL_Foobar().findByField(Foobar__c.Name, SAVED_RECORD_NAME).size();
		Assert.areEqual(1, savedCount, 'Expected the record the handler registered to be saved on the second attempt, got ' + savedCount);
		Assert.isNotNull(handler.apiCall.CommitDurationMs__c, 'Expected a commit time on the call after the retried commit, got null');
	}

	/**
	 * @description Tests that a handler whose own after-commit step throws once its records are saved keeps its one call
	 * row: the row the commit saved ends Failed with the step's message and no retry time, and no second row appears for
	 * the service.
	 *
	 * @see API_Base.commitWork
	 */
	@IsTest
	private static void shouldKeepTheSavedCallRowWhenAnAfterCommitStepThrows()
	{
		API_InboundTestHelper.setupRestContext();
		String serviceName = ThrowingAfterCommitInbound.class.getName();

		Test.startTest();

		API_Dispatcher.execute(TST_Factory.newInboundApiCall(serviceName));

		Test.stopTest();

		List<ApiCall__c> failed = SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_THROWN_AFTER_COMMIT);
		Assert.areEqual(1, failed.size(), 'Expected the one row the commit saved and no second row, got ' + failed.size());
		Assert.isNull(failed[0].NextRetry__c, 'Expected no next retry time on the failed inbound call, got ' + failed[0].NextRetry__c);
	}

	/**
	 * @description Tests that a handler whose own after-commit step throws once a retried commit has saved its records
	 * keeps its one call row: the first attempt is refused for a row lock, the second saves the row, the step then throws,
	 * and the row the second attempt saved ends Failed with the step's message, with no second row for the service.
	 *
	 * @see API_Base.onCommitWorkStarting
	 */
	@IsTest
	private static void shouldKeepTheSavedCallRowWhenAnAfterCommitStepThrowsAfterALockRetry()
	{
		String serviceName = ThrowingAfterCommitInbound.class.getName();

		dispatchInboundWithOneLockRefusal(serviceName);

		List<ApiCall__c> failed = SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_THROWN_AFTER_COMMIT);
		Assert.areEqual(1, failed.size(), 'Expected the one row the retried commit saved and no second row, got ' + failed.size());
		Assert.isNull(failed[0].NextRetry__c, 'Expected no next retry time on the failed inbound call, got ' + failed[0].NextRetry__c);
	}

	/**
	 * @description Tests that a second commit on a handler that has already committed is refused, because its stopwatches
	 * have stopped, and that the refused commit leaves the call record's Id alone: the Id still names the row the first
	 * commit saved.
	 *
	 * @see API_Base.commitWork
	 */
	@IsTest
	private static void shouldRefuseASecondCommitOnOneHandlerAndKeepTheSavedCallId()
	{
		API_InboundTestHelper.setupRestContext();

		Test.startTest();

		API_Base handler = API_Dispatcher.execute(TST_Factory.newInboundApiCall(RecordSavingInbound.class.getName()));

		Test.stopTest();

		Id savedCallId = handler.apiCall.Id;
		Assert.isNotNull(savedCallId, 'Expected the first commit to save the call row, got no Id');

		try
		{
			handler.commitWork();
			Assert.fail('Expected a second commit on one handler to be refused');
		}
		catch(Exception refused)
		{
			Assert.isInstanceOfType(refused, UTIL_Exceptions.IllegalStateException.class, 'Expected the stopwatch refusal, got ' + refused.getTypeName());
		}

		Assert.areEqual(savedCallId, handler.apiCall.Id, 'Expected the refused commit to keep the saved call Id, got ' + handler.apiCall.Id);
	}

	/**
	 * @description Tests that a commit refused before its commit stopwatch has started fails with that first refusal,
	 * and not with a second one raised while the commit ends. A handler that has already committed holds a stopped commit
	 * stopwatch. The test starts the handler's service stopwatch again, so a second commit gets as far as starting the
	 * commit stopwatch, which refuses because it was never reset. The caller must see that refusal: stopping a stopwatch
	 * that never started would raise another exception of the same type and hide the first.
	 *
	 * @see API_Base.commitWork
	 */
	@IsTest
	private static void shouldReportTheFirstRefusalWhenTheCommitStopwatchCannotStart()
	{
		API_InboundTestHelper.setupRestContext();

		Test.startTest();

		API_Base handler = API_Dispatcher.execute(TST_Factory.newInboundApiCall(RecordSavingInbound.class.getName()));

		Test.stopTest();

		handler.serviceProcessingTime.reset();
		handler.serviceProcessingTime.start();

		try
		{
			handler.commitWork();
			Assert.fail('Expected a commit whose commit stopwatch cannot start to be refused');
		}
		catch(Exception refused)
		{
			Assert.isInstanceOfType(refused, UTIL_Exceptions.IllegalStateException.class, 'Expected the stopwatch refusal, got ' + refused.getTypeName());
			String message = refused.getMessage();
			Assert.areEqual(MESSAGE_STOPWATCH_NEEDS_A_RESET, message, 'Expected the refusal of the stopwatch\'s start to reach the caller, got ' + message);
		}
	}

	/**
	 * @description Tests that the base step that resolves earlier issues does nothing by itself. A handler that keeps
	 * this step finishes a successful save of a successful call, and its setting has Resolve Issues on. The open issue
	 * is for the same service, with no triggering record, and has the same request hash as the call. The outbound step
	 * would resolve such an issue. It stays Open here, and no save runs.
	 *
	 * @see API_Base.onCommitWorkFinished
	 */
	@IsTest
	private static void shouldResolveNoIssueWhenAHandlerKeepsTheBaseResolveStep()
	{
		String serviceName = BaseResolveStepHandler.class.getName();
		String requestParameters = UTIL_Random.randomName();
		String requestHash = UTIL_String.abbreviate(UTIL_Crypto.generateMD5Hash(requestParameters), SEL_ApiIssue.REQUEST_PARAMETERS_HASH_LENGTH);
		ApiCall__c matchingCall = (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType)
				.withOverride(ApiCall__c.ServiceName__c, serviceName)
				.withOverride(ApiCall__c.RequestParameters__c, requestParameters)
				.withOverride(ApiCall__c.TriggeringRecordId__c, null)
				.withoutInsertion()
				.build();
		ApiIssue__c openIssue = (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.ServiceName__c, serviceName)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
				.withOverride(ApiIssue__c.TriggeringRecordId__c, null)
				.withOverride(ApiIssue__c.RequestParametersHash__c, requestHash)
				.build();
		ApiSetting__mdt resolvingSetting = (ApiSetting__mdt)TST_Builder.of(ApiSetting__mdt.SObjectType)
				.withOverride(ApiSetting__mdt.ClassName__c, serviceName)
				.withOverride(ApiSetting__mdt.ResolveIssues__c, true)
				.withoutInsertion()
				.build();
		BaseResolveStepHandler handler = new BaseResolveStepHandler();
		handler.assignApiCallWhenMissing(matchingCall);
		handler.applySettings(resolvingSetting);
		handler.result.isSuccess = true;

		Test.startTest();

		Integer statementsBefore = UTIL_Limits.dmlStatements().used();
		handler.onCommitWorkFinished(true);
		Integer statementsAfter = UTIL_Limits.dmlStatements().used();

		Test.stopTest();

		Assert.areEqual(statementsBefore, statementsAfter, 'Expected the base resolve step to run no save, got ' + (statementsAfter - statementsBefore));
		String status = ((ApiIssue__c)new SEL_ApiIssue().findById(openIssue.Id)).Status__c;
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, status, 'Expected the open issue to stay Open after the base resolve step, got ' + status);
	}

	/**
	 * @description Dispatches one inbound call while a stand-in refuses the first statement of the handler's commit with
	 * a lock refusal, and takes the stand-in away again whatever happens. The stand-in is set after the test has started,
	 * so it refuses only the commit's statements.
	 *
	 * @param serviceName The inbound handler to dispatch.
	 *
	 * @return The handler that ran the call.
	 */
	private static API_Base dispatchInboundWithOneLockRefusal(String serviceName)
	{
		API_InboundTestHelper.setupRestContext();

		try
		{
			Test.startTest();
			DML_SharingProxy.sharingProxyForTest = new DML_ThrowingLockProxy_TEST(1);
			API_Base handler = API_Dispatcher.execute(TST_Factory.newInboundApiCall(serviceName));
			Test.stopTest();
			return handler;
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
		}
	}

	/**
	 * @description Tests that parseTraceParentHeader logs warning and generates new context for invalid header.
	 *
	 * @see API_Base.parseTraceParentHeader
	 */
	@IsTest
	private static void shouldGenerateNewContextForInvalidTraceParentHeader()
	{
		API_Base.clearTraceContext();

		Test.startTest();

		API_Base.TraceContext result = API_Base.parseTraceParentHeader('invalid-header');

		Test.stopTest();

		Assert.isNotNull(result, 'Should generate new context for invalid header');
		Assert.isNotNull(result.traceId, 'Should have trace ID');
		Assert.isNotNull(result.spanId, 'Should have span ID');
	}

	/**
	 * @description Tests that redactCredentialHeaders does each of the following, in both its Map and DTO_NameValues
	 * forms. It replaces the value of every credential header, matched by exact name or by a name fragment, whatever
	 * its letter case. It keeps a blank credential blank, and keeps credential merge-field text as written, including
	 * the forms that start with a scheme. It copies every operational header as sent (Idempotency-Key and traceparent,
	 * which shows that 'key' is not a fragment). It redacts, on purpose, a header whose name looks like a credential's but carries no secret
	 * (X-Token-Type). It does not let a merge expression that is not a credential pass through unredacted. It never
	 * changes its input, and it treats a null input as empty.
	 */
	@IsTest
	private static void redactCredentialHeadersReplacesCredentialValuesOnly()
	{
		Map<String, String> headers = new Map<String, String>
		{
				REDACTION_HEADER_UPPER_AUTHORIZATION => REDACTION_PROBE_TOKEN,
				REDACTION_HEADER_SET_COOKIE => REDACTION_PROBE_COOKIE,
				REDACTION_HEADER_VENDOR_SECRET => REDACTION_PROBE_VENDOR_SECRET,
				REDACTION_HEADER_TOKEN_TYPE => REDACTION_PROBE_TOKEN_TYPE,
				REDACTION_HEADER_LOWER_API_KEY => '',
				REDACTION_HEADER_IDEMPOTENCY_KEY => REDACTION_PROBE_IDEMPOTENCY_KEY,
				REDACTION_HEADER_TRACE_PARENT => REDACTION_PROBE_TRACE_PARENT,
				API_Base.HTTP_CONTENT_TYPE => REDACTION_PROBE_CONTENT_TYPE
		};

		Map<String, String> redacted = API_Base.redactCredentialHeaders(headers);
		Map<String, String> mergeField = API_Base.redactCredentialHeaders(new Map<String, String>
		{
				REDACTION_HEADER_UPPER_AUTHORIZATION => REDACTION_PROBE_MERGE_FIELD,
				REDACTION_HEADER_LOWER_API_KEY => REDACTION_PROBE_BEARER_MERGE_FIELD,
				REDACTION_HEADER_SET_COOKIE => REDACTION_PROBE_PLAIN_EXPRESSION
		});
		DTO_NameValues redactedValues = API_Base.redactCredentialHeaders(new DTO_NameValues(headers));

		Assert.areEqual(API_Base.REDACTED_HEADER_VALUE, redacted.get(REDACTION_HEADER_UPPER_AUTHORIZATION), 'An Authorization value is redacted whatever the name casing');
		Assert.areEqual(API_Base.REDACTED_HEADER_VALUE, redacted.get(REDACTION_HEADER_SET_COOKIE), 'A Set-Cookie value is redacted');
		Assert.areEqual(API_Base.REDACTED_HEADER_VALUE, redacted.get(REDACTION_HEADER_VENDOR_SECRET), 'A vendor header whose name contains a credential fragment is redacted');
		Assert.areEqual(API_Base.REDACTED_HEADER_VALUE, redacted.get(REDACTION_HEADER_TOKEN_TYPE),
				'Expected a header whose name only looks like a credential\'s to be redacted on purpose, rather than risk leaking a credential');
		Assert.areEqual('', redacted.get(REDACTION_HEADER_LOWER_API_KEY), 'A blank credential stays blank rather than reading as redacted');
		Assert.areEqual(REDACTION_PROBE_IDEMPOTENCY_KEY, redacted.get(REDACTION_HEADER_IDEMPOTENCY_KEY), 'Idempotency-Key is operational, not a credential, and stays visible');
		Assert.areEqual(REDACTION_PROBE_TRACE_PARENT, redacted.get(REDACTION_HEADER_TRACE_PARENT), 'The tracing header stays visible');
		Assert.areEqual(REDACTION_PROBE_CONTENT_TYPE, redacted.get(API_Base.HTTP_CONTENT_TYPE), 'A non-credential header is copied as sent');
		Assert.areEqual(REDACTION_PROBE_MERGE_FIELD, mergeField.get(REDACTION_HEADER_UPPER_AUTHORIZATION), 'Credential merge-field text carries no secret and is kept verbatim');
		Assert.areEqual(REDACTION_PROBE_BEARER_MERGE_FIELD, mergeField.get(REDACTION_HEADER_LOWER_API_KEY),
				'A scheme-prefixed credential merge field (Bearer {!$Credential...}) is kept verbatim');
		Assert.areEqual(API_Base.REDACTED_HEADER_VALUE, mergeField.get(REDACTION_HEADER_SET_COOKIE), 'A non-credential merge expression earns no pass-through');
		Assert.areEqual(REDACTION_PROBE_TOKEN, headers.get(REDACTION_HEADER_UPPER_AUTHORIZATION), 'The input map is not mutated');
		Assert.areEqual(API_Base.REDACTED_HEADER_VALUE, redactedValues.get(REDACTION_HEADER_UPPER_AUTHORIZATION), 'The DTO_NameValues form redacts the same names');
		Assert.areEqual(REDACTION_PROBE_CONTENT_TYPE, redactedValues.get(API_Base.HTTP_CONTENT_TYPE), 'The DTO_NameValues form copies the rest');
		Assert.isTrue(API_Base.redactCredentialHeaders((Map<String, String>)null).isEmpty(), 'A null map yields an empty map');
		Assert.isTrue(API_Base.redactCredentialHeaders((DTO_NameValues)null).isEmpty(), 'A null DTO yields an empty DTO');
		Assert.isFalse(API_Base.isCredentialHeader(null), 'A null header name is not a credential header');
		Assert.isFalse(API_Base.isCredentialHeader(''), 'A blank header name is not a credential header');
	}

	/**
	 * @description Tests that a request longer than its field is masked once, before the save: the field holds the
	 * masked request cut to fit, the request file holds the whole masked request, and the file is built from the text
	 * kept from that first pass, so no masking runs again after the save.
	 *
	 * @see API_Base.setApiCallDetails
	 * @see API_Base.createRelatedContentVersions
	 */
	@IsTest
	private static void shouldMaskAnOversizedPayloadOnceAndAttachTheFullMaskedText()
	{
		enableMaskerPerformanceLogging();
		registerRuleThatNeverMatchesOnEveryField();
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, newRegexRule('HideSecret', SECRET_PATTERN, HIDDEN_TOKEN, null), null);
		String padding = 'v'.repeat(OVERSIZED_PAYLOAD_LENGTH);
		String wholeMaskedBody = HIDDEN_TOKEN + ' ' + padding;

		ApiCall__c stored = dispatchMaskingTestCall(MaskingTestOutbound.class.getName(), SECRET + ' ' + padding, SUCCESS_RESPONSE_BODY, null);

		String fieldText = stored.Request__c;
		Assert.areEqual(UTIL_String.abbreviate(wholeMaskedBody, ApiCall__c.Request__c), fieldText, 'Expected the field to hold the masked request cut to fit, got '
				+ fieldText?.left(40));
		String fileText = readFilesByTitle(stored.Id).get(REQUEST_FILE_TITLE);
		Assert.areEqual(wholeMaskedBody, fileText, 'Expected the request file to hold the whole masked request, got ' + fileText?.length() + ' characters');
		Integer filePathRuns = findMaskerEntries(ContentVersion.SObjectType).size();
		Assert.areEqual(0, filePathRuns, 'Expected no masking after the save, because the file uses the text kept from the first pass, got ' + filePathRuns);
	}

	/**
	 * @description Tests that a request that fits its field but grows past it when the shipped secret-keys rule masks
	 * it (a list of 9,000 small secret values and one long one) is saved cut in the field, and that the file holds the
	 * whole masked text the trigger kept. No secret value is left in either.
	 *
	 * @see API_Base.createRelatedContentVersions
	 */
	@IsTest
	private static void shouldAttachTheUncutTextWhenMaskingGrewAFittingPayloadPastTheField()
	{
		MaskingRule__mdt secretKeysRule = findShippedRule(SEL_MaskingRule.RULE_MASK_SECRET_KEYS);
		Assert.isNotNull(secretKeysRule, 'Expected the shipped secret-keys rule to be deployed to the org');
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, secretKeysRule, null);
		String head = buildTokenArrayHead();
		Integer lastValueLength = PAYLOAD_FIELD_LENGTH - head.length() - TOKEN_ARRAY_TAIL.length();
		Integer replacementLength = secretKeysRule.Replacement__c.length();
		Integer expectedFileLength = PAYLOAD_FIELD_LENGTH + SMALL_TOKEN_COUNT * (replacementLength - 1) + replacementLength - lastValueLength;

		ApiCall__c stored = dispatchMaskingTestCall(MaskingTestOutbound.class.getName(), head + 'x'.repeat(lastValueLength) + TOKEN_ARRAY_TAIL, SUCCESS_RESPONSE_BODY, null);

		String fieldText = stored.Request__c;
		Assert.areEqual(PAYLOAD_FIELD_LENGTH, fieldText.length(), 'Expected the masked request to be cut to the field length, got ' + fieldText.length());
		Assert.isFalse(fieldText.contains(SMALL_TOKEN_VALUE), 'Expected no secret value left in the field');
		String fileText = readFilesByTitle(stored.Id).get(REQUEST_FILE_TITLE);
		Assert.isNotNull(fileText, 'Expected a request file for a masked request longer than its field');
		Assert.areEqual(expectedFileLength, fileText.length(), 'Expected the file to hold the whole masked request, got ' + fileText.length() + ' characters');
		Assert.isFalse(fileText.contains(SMALL_TOKEN_VALUE), 'Expected no secret value left in the file');
	}

	/**
	 * @description Tests the smallest growth: a request of exactly the field length whose one secret is one character
	 * shorter than the text the shipped secret-keys rule writes. The masked request is one character too long, so the
	 * field holds it cut and the file holds all of it, one character longer than the field.
	 *
	 * @see API_Base.createRelatedContentVersions
	 */
	@IsTest
	private static void shouldAttachTheUncutTextWhenMaskingGrewAFittingPayloadByOneCharacter()
	{
		MaskingRule__mdt secretKeysRule = findShippedRule(SEL_MaskingRule.RULE_MASK_SECRET_KEYS);
		Assert.isNotNull(secretKeysRule, 'Expected the shipped secret-keys rule to be deployed to the org');
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, secretKeysRule, null);
		String secretValue = 'a'.repeat(secretKeysRule.Replacement__c.length() - 1);
		String head = '{"password":"' + secretValue + '","pad":"';
		String tail = '"}';
		String requestBody = head + 'v'.repeat(PAYLOAD_FIELD_LENGTH - head.length() - tail.length()) + tail;

		ApiCall__c stored = dispatchMaskingTestCall(MaskingTestOutbound.class.getName(), requestBody, SUCCESS_RESPONSE_BODY, null);

		String fieldText = stored.Request__c;
		Assert.areEqual(PAYLOAD_FIELD_LENGTH, fieldText.length(), 'Expected the masked request to be cut to the field length, got ' + fieldText.length());
		Assert.isFalse(fieldText.contains(secretValue), 'Expected the secret to be hidden in the field');
		String fileText = readFilesByTitle(stored.Id).get(REQUEST_FILE_TITLE);
		Assert.isNotNull(fileText, 'Expected a request file for a masked request one character longer than its field');
		Assert.areEqual(PAYLOAD_FIELD_LENGTH + 1, fileText.length(), 'Expected the file to hold the whole masked request, got ' + fileText.length() + ' characters');
		Assert.isFalse(fileText.contains(secretValue), 'Expected the secret to be hidden in the file');
	}

	/**
	 * @description Tests that a request longer than its field that masking shrinks to fit is saved whole in the field,
	 * with no file, and that nothing is masked again after the save. The secret is long, but shorter than
	 * `UTIL_String.PATTERN_SEARCH_PIECE_OVERLAP`, so the search in pieces of a long request finds it whole.
	 *
	 * @see API_Base.createRelatedContentVersions
	 */
	@IsTest
	private static void shouldNotAttachAFileWhenTheMaskedPayloadFits()
	{
		enableMaskerPerformanceLogging();
		registerRuleThatNeverMatchesOnEveryField();
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, newRegexRule('HideSecret', SECRET_PATTERN, HIDDEN_TOKEN, null), null);
		String rest = ' ' + 'b'.repeat(PADDING_THAT_FITS_AFTER_MASKING_LENGTH) + ' end of the request';

		ApiCall__c stored = dispatchMaskingTestCall(MaskingTestOutbound.class.getName(), 'secret-' + 'a'.repeat(LONG_SECRET_LENGTH) + rest, SUCCESS_RESPONSE_BODY, null);

		Assert.areEqual(HIDDEN_TOKEN + rest, stored.Request__c, 'Expected the field to hold the whole masked request, got ' + stored.Request__c?.left(40));
		Map<String, String> filesByTitle = readFilesByTitle(stored.Id);
		Assert.isTrue(filesByTitle.isEmpty(), 'Expected no file when the masked request fits its field, got ' + filesByTitle.keySet());
		Integer filePathRuns = findMaskerEntries(ContentVersion.SObjectType).size();
		Assert.areEqual(0, filePathRuns, 'Expected no masking after the save, got ' + filePathRuns);
	}

	/**
	 * @description Tests that when a handler step changes the request field after the framework wrote it and before the
	 * save, the trigger masks the changed text, and the file step, which has no answer for the request it sent, masks
	 * that request again: one masking run after the save, and no file because the masked request fits.
	 *
	 * @see API_Base.createRelatedContentVersions
	 */
	@IsTest
	private static void shouldMaskAgainWhenAnotherStepChangedTheFieldBeforeMasking()
	{
		enableMaskerPerformanceLogging();
		registerRuleThatNeverMatchesOnEveryField();
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, newRegexRule('HideSecret', SECRET_PATTERN, HIDDEN_TOKEN, null), null);
		String requestBody = 'plain request';

		ApiCall__c stored = dispatchMaskingTestCall(FieldChangingMaskingTestOutbound.class.getName(), requestBody, SUCCESS_RESPONSE_BODY, null);

		Assert.areEqual(requestBody + ' ' + HIDDEN_TOKEN, stored.Request__c, 'Expected the trigger to mask the changed request, got ' + stored.Request__c);
		Integer filePathRuns = findMaskerEntries(ContentVersion.SObjectType).size();
		Assert.areEqual(1, filePathRuns, 'Expected the file step to mask the request it sent once again, got ' + filePathRuns);
		Map<String, String> filesByTitle = readFilesByTitle(stored.Id);
		Assert.isTrue(filesByTitle.isEmpty(), 'Expected no file when the masked request fits its field, got ' + filesByTitle.keySet());
	}

	/**
	 * @description Tests that an address and request parameters longer than their fields are masked the same way as a
	 * request body: each field holds its masked text cut to fit, each file holds the whole masked text, no secret is
	 * left in either, and nothing is masked again after the save.
	 *
	 * @see API_Base.setApiCallDetails
	 */
	@IsTest
	private static void shouldMaskTheUrlAndParametersTheSameWay()
	{
		enableMaskerPerformanceLogging();
		registerRuleThatNeverMatchesOnEveryField();
		MaskingRule__mdt secretRule = newRegexRule('HideSecret', SECRET_PATTERN, HIDDEN_TOKEN, null);
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.URL__c, secretRule, null);
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.RequestParameters__c, secretRule, null);
		String urlPadding = '&pad=' + 'p'.repeat(400);
		maskingTestUrl = MASKING_TEST_URL + '?key=' + SECRET + urlPadding;

		ApiCall__c stored = dispatchMaskingTestCall(MaskingTestOutbound.class.getName(), null, SUCCESS_RESPONSE_BODY, new Map<String, String>
		{
				PARAMETER_NAME => SECRET + ' ' + 'p'.repeat(OVERSIZED_PAYLOAD_LENGTH)
		});

		Map<String, String> filesByTitle = readFilesByTitle(stored.Id);
		String wholeMaskedUrl = MASKING_TEST_URL + '?key=' + HIDDEN_TOKEN + urlPadding;
		Assert.areEqual(UTIL_String.abbreviate(wholeMaskedUrl, ApiCall__c.URL__c), stored.URL__c, 'Expected the address field to hold the masked address cut to fit, got '
				+ stored.URL__c);
		Assert.areEqual(wholeMaskedUrl, filesByTitle.get(URL_FILE_TITLE), 'Expected the address file to hold the whole masked address');
		String parametersFile = filesByTitle.get(PARAMETERS_FILE_TITLE);
		Assert.isNotNull(parametersFile, 'Expected a parameters file for masked parameters longer than their field');
		Assert.isFalse(parametersFile.contains(SECRET), 'Expected the secret to be hidden in the parameters file');
		Assert.isTrue(parametersFile.contains(HIDDEN_TOKEN), 'Expected the parameters file to show where the secret was');
		Assert.areEqual(UTIL_String.abbreviate(parametersFile, ApiCall__c.RequestParameters__c), stored.RequestParameters__c,
				'Expected the parameters field to hold the masked parameters cut to fit');
		Integer filePathRuns = findMaskerEntries(ContentVersion.SObjectType).size();
		Assert.areEqual(0, filePathRuns, 'Expected no masking after the save, got ' + filePathRuns);
	}

	/**
	 * @description Tests the number of masking passes on a save with all four payloads: a request longer than its field
	 * that no rule changes, a token array response that fits but grows past its field when the shipped secret-keys rule
	 * masks it, and an address and parameters that fit. The request is masked before the save and left alone by the
	 * trigger, so its cut text still ends with the three dots a second pass would replace. The trigger runs twice, on
	 * the insert and on the update after the callout: the insert masks the response, and the update finds every payload
	 * masked already. A second pass over the raw response would keep its whole masked text again, but after the save
	 * the masker holds nothing for it, for the handler's class or for no caller. Nothing is masked again after the save:
	 * the request file is the text kept from the first pass and the response file is the whole text the trigger kept.
	 *
	 * @see API_Base.setApiCallDetails
	 * @see API_Base.buildApiCallChangesToSave
	 */
	@IsTest
	private static void shouldCountOneMaskingPassPerPayload()
	{
		enableMaskerPerformanceLogging();
		MaskingRule__mdt secretKeysRule = findShippedRule(SEL_MaskingRule.RULE_MASK_SECRET_KEYS);
		Assert.isNotNull(secretKeysRule, 'Expected the shipped secret-keys rule to be deployed to the org');
		MaskingRule__mdt secretRule = newRegexRule('HideSecret', SECRET_PATTERN, HIDDEN_TOKEN, null);
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, newRegexRule('ReplaceCutMarker', CUT_MARKER_PATTERN, CUT_MARKER_REPLACEMENT, null), null);
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Response__c, secretKeysRule, null);
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.URL__c, secretRule, null);
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.RequestParameters__c, secretRule, null);
		maskingTestUrl = MASKING_TEST_URL + '?key=' + SECRET;
		String head = buildTokenArrayHead();
		String responseBody = head + 'x'.repeat(PAYLOAD_FIELD_LENGTH - head.length() - TOKEN_ARRAY_TAIL.length()) + TOKEN_ARRAY_TAIL;

		String serviceName = MaskingTestOutbound.class.getName();
		ApiCall__c stored = dispatchMaskingTestCall(serviceName, 'r'.repeat(OVERSIZED_PAYLOAD_LENGTH), responseBody, new Map<String, String> {PARAMETER_NAME => SECRET});

		Assert.isTrue(stored.Request__c.endsWith(CUT_MARKER), 'Expected no second pass over the cut request, got the end ' + stored.Request__c.right(10));
		Assert.isFalse(stored.Response__c.contains(SMALL_TOKEN_VALUE), 'Expected no secret value left in the response field');
		List<Integer> triggerCpuTimes = readMaskingCpuTimes(findMaskerEntries(ApiCall__c.SObjectType));
		Assert.areEqual(2, triggerCpuTimes.size(), 'Expected one masking run on the insert and one on the update, got ' + triggerCpuTimes);
		for(String callerClassName : new List<String> {serviceName, UTIL_String.EMPTY})
		{
			UTIL_FrameworkMasker.MaskedValueState state = UTIL_FrameworkMasker.takeMaskedValueAnswer(ApiCall__c.Response__c, callerClassName, responseBody).state;
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.NOT_SEEN, state, 'Expected no pass over the raw response after the file took its text, for the caller "'
					+ callerClassName + '", got ' + state);
		}
		Integer filePathRuns = findMaskerEntries(ContentVersion.SObjectType).size();
		Assert.areEqual(0, filePathRuns, 'Expected no masking after the save, got ' + filePathRuns);
		Integer requestRunsBeforeTheSave = findPayloadMaskingEntries(ApiCall__c.Request__c).size();
		Assert.areEqual(1, requestRunsBeforeTheSave, 'Expected the request, longer than its field, masked once before the save, got ' + requestRunsBeforeTheSave);
		Integer parametersRunsBeforeTheSave = findPayloadMaskingEntries(ApiCall__c.RequestParameters__c).size();
		Assert.areEqual(0, parametersRunsBeforeTheSave, 'Expected the parameters, which fit, left to the trigger, got ' + parametersRunsBeforeTheSave);
		Map<String, String> filesByTitle = readFilesByTitle(stored.Id);
		Assert.isTrue(filesByTitle.containsKey(REQUEST_FILE_TITLE) && filesByTitle.containsKey(RESPONSE_FILE_TITLE), 'Expected a request and a response file, got '
				+ filesByTitle.keySet());
	}

	/**
	 * @description Tests that the update after the callout leaves the payloads that did not change as the insert saved
	 * them. The request rule writes its word twice, so a second pass over the saved text would add the word again: the
	 * saved request equals the output of the one pass on the insert. The response fits but grows one character past its
	 * field when masked, so the insert keeps its whole masked text and the file step takes it. A second pass over the
	 * raw response on the update would keep that text again; after the save the masker holds nothing for it, for the
	 * handler's class or for no caller.
	 *
	 * @see API_Base.buildApiCallChangesToSave
	 */
	@IsTest
	private static void shouldNotReMaskAnUnchangedPayloadOnTheUpdate()
	{
		enableMaskerPerformanceLogging();
		String serviceName = MaskingTestOutbound.class.getName();
		String grownToken = '[' + 'H'.repeat(SECRET.length() - 1) + ']';
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, newRegexRule('GrowWord', GROWING_WORD, GROWING_WORD + GROWING_WORD, null), null);
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Response__c, newRegexRule('HideSecretLonger', SECRET_PATTERN, grownToken, null), null);
		String responseBody = SECRET + ' ' + 'v'.repeat(PAYLOAD_FIELD_LENGTH - SECRET.length() - 1);

		ApiCall__c stored = dispatchMaskingTestCall(serviceName, 'please ' + GROWING_WORD, responseBody, null);

		Assert.areEqual('please ' + GROWING_WORD + GROWING_WORD, stored.Request__c, 'Expected the request as the one pass on the insert left it, got ' + stored.Request__c);
		String responseFile = readFilesByTitle(stored.Id).get(RESPONSE_FILE_TITLE);
		Assert.areEqual(PAYLOAD_FIELD_LENGTH + 1, responseFile?.length(), 'Expected the response file to hold the whole masked response');
		for(String callerClassName : new List<String> {serviceName, UTIL_String.EMPTY})
		{
			UTIL_FrameworkMasker.MaskedValueState state = UTIL_FrameworkMasker.takeMaskedValueAnswer(ApiCall__c.Response__c, callerClassName, responseBody).state;
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.NOT_SEEN, state, 'Expected no pass over the raw response after the file took its text, for the caller "'
					+ callerClassName + '", got ' + state);
		}
		List<Integer> triggerCpuTimes = readMaskingCpuTimes(findMaskerEntries(ApiCall__c.SObjectType));
		Assert.areEqual(2, triggerCpuTimes.size(), 'Expected one masking run on the insert and one on the update, got ' + triggerCpuTimes);
	}

	/**
	 * @description Tests that a rule set to block the save that fails while a request longer than its field is masked
	 * before the save refuses the save: no call row is stored for the service and no file is made.
	 *
	 * @see API_Base.setApiCallDetails
	 */
	@IsTest
	private static void shouldRefuseTheSaveWhenABlockDmlRuleFailsWhileMaskingBeforeTheSave()
	{
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, newRegexRule('BrokenBlockingRule', BROKEN_PATTERN, HIDDEN_TOKEN, SEL_MaskingRule.FAILURE_BLOCK_DML), null);
		String serviceName = MaskingTestOutbound.class.getName();

		dispatchMaskingTestCall(serviceName, SECRET + ' ' + 'v'.repeat(OVERSIZED_PAYLOAD_LENGTH), SUCCESS_RESPONSE_BODY, null);

		List<ApiCall__c> storedCalls = new SEL_ApiCall().findByServiceName(serviceName);
		Assert.isTrue(storedCalls.isEmpty(), 'Expected the save to be refused, got ' + storedCalls.size() + ' stored calls');
		List<ContentVersion> files = new SEL_ContentVersion().toList();
		Assert.isTrue(files.isEmpty(), 'Expected no file when the save is refused, got ' + files.size());
	}

	/**
	 * @description Tests that a rule set to write the failure marker that fails while a request longer than its field is
	 * masked before the save stores the marker in the field, and no request file, because the marker fits the field.
	 *
	 * @see API_Base.setApiCallDetails
	 */
	@IsTest
	private static void shouldWriteTheMarkerWhenAWriteFailureMarkerRuleFailsWhileMaskingBeforeTheSave()
	{
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, newRegexRule('BrokenMarkerRule', BROKEN_PATTERN, HIDDEN_TOKEN, SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER),
				null);

		ApiCall__c stored = dispatchMaskingTestCall(MaskingTestOutbound.class.getName(), SECRET + ' ' + 'v'.repeat(OVERSIZED_PAYLOAD_LENGTH), SUCCESS_RESPONSE_BODY, null);

		Assert.areEqual(UTIL_FrameworkMasker.FAILURE_MARKER, stored.Request__c, 'Expected the failure marker in the request field, got ' + stored.Request__c?.left(40));
		Map<String, String> filesByTitle = readFilesByTitle(stored.Id);
		Assert.isFalse(filesByTitle.containsKey(REQUEST_FILE_TITLE), 'Expected no request file when the field holds the failure marker');
	}

	/**
	 * @description Tests that a masking target limited to one handler class hides a secret in the request that handler
	 * saves on its API call.
	 *
	 * @see TRG_Dispatcher.run
	 */
	@IsTest
	private static void shouldMaskACallerScopedTargetForItsHandlerOnTheSave()
	{
		String serviceName = MaskingTestOutbound.class.getName();
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, newRegexRule('HideSecretForHandler', SECRET_PATTERN, FIRST_HANDLER_TOKEN, null), serviceName);

		ApiCall__c stored = dispatchMaskingTestCall(serviceName, 'request with ' + SECRET, SUCCESS_RESPONSE_BODY, null);

		Assert.areEqual('request with ' + FIRST_HANDLER_TOKEN, stored.Request__c, 'Expected the target limited to this handler to hide the secret, got ' + stored.Request__c);
	}

	/**
	 * @description Tests that a masking target limited to another handler class does not change the request this
	 * handler saves.
	 *
	 * @see TRG_Dispatcher.run
	 */
	@IsTest
	private static void shouldNotMaskACallerScopedTargetForAnotherHandler()
	{
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, newRegexRule('HideSecretForOther', SECRET_PATTERN, SECOND_HANDLER_TOKEN, null),
				OtherMaskingTestOutbound.class.getName());
		String requestBody = 'request with ' + SECRET;

		ApiCall__c stored = dispatchMaskingTestCall(MaskingTestOutbound.class.getName(), requestBody, SUCCESS_RESPONSE_BODY, null);

		Assert.areEqual(requestBody, stored.Request__c, 'Expected a target limited to another handler to change nothing, got ' + stored.Request__c);
	}

	/**
	 * @description Tests that a masking target with no caller class hides the secret on the calls of two different
	 * handlers saved together.
	 *
	 * @see TRG_Dispatcher.run
	 */
	@IsTest
	private static void shouldMaskAnUnscopedTargetForBothHandlers()
	{
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, newRegexRule('HideSecretForAll', SECRET_PATTERN, UNSCOPED_TOKEN, null), null);

		List<ApiCall__c> stored = dispatchTwoMaskingTestCalls('request with ' + SECRET);

		for(ApiCall__c storedCall : stored)
		{
			Assert.areEqual('request with ' + UNSCOPED_TOKEN, storedCall.Request__c, 'Expected the target for every caller to hide the secret for '
					+ storedCall.ServiceName__c + ', got ' + storedCall.Request__c);
		}
	}

	/**
	 * @description Tests that an API call whose service has no setting, and an API issue with no service name, get the
	 * masking pass for no caller: the target for every caller hides its secret, and a target limited to a handler does
	 * not change anything. The call is saved as Failed: a shipped flow clears the payloads of an outbound call that is
	 * still waiting to be sent.
	 *
	 * @see TRG_Dispatcher.run
	 */
	@IsTest
	private static void shouldTreatAServiceWithNoHandlerAsUnscoped()
	{
		String scopedCaller = MaskingTestOutbound.class.getName();
		MaskingRule__mdt openRule = newRegexRule('HideOpenSecret', OPEN_SECRET_PATTERN, UNSCOPED_TOKEN, null);
		MaskingRule__mdt scopedRule = newRegexRule('HideSecretForHandler', SECRET_PATTERN, FIRST_HANDLER_TOKEN, null);
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, openRule, null);
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, scopedRule, scopedCaller);
		registerTarget(ApiIssue__c.SObjectType, ApiIssue__c.RequestBody__c, openRule, null);
		registerTarget(ApiIssue__c.SObjectType, ApiIssue__c.RequestBody__c, scopedRule, scopedCaller);
		TST_Factory.newOutboundApiSetting(scopedCaller, null);
		String rawText = OPEN_SECRET + ' ' + SECRET;

		Test.startTest();

		ApiCall__c apiCall = (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType)
				.withOverride(ApiCall__c.ServiceName__c, SERVICE_WITH_NO_SETTING)
				.withOverride(ApiCall__c.Status__c, SEL_ApiCall.STATUS_FAILED)
				.withOverride(ApiCall__c.Request__c, rawText)
				.build();
		ApiIssue__c apiIssue = (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.ServiceName__c, null)
				.withOverride(ApiIssue__c.RequestBody__c, rawText)
				.build();

		Test.stopTest();

		String expectedText = UNSCOPED_TOKEN + ' ' + SECRET;
		String storedRequest = ((ApiCall__c)new SEL_ApiCall().findById(apiCall.Id)).Request__c;
		Assert.areEqual(expectedText, storedRequest, 'Expected only the target for every caller on a call whose service has no setting, got ' + storedRequest);
		String storedIssueBody = ((ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id)).RequestBody__c;
		Assert.areEqual(expectedText, storedIssueBody, 'Expected only the target for every caller on an issue with no service name, got ' + storedIssueBody);
	}

	/**
	 * @description Tests that two handlers saved together in one transaction each get the targets limited to their own
	 * class: the same secret is hidden with the first handler's text on the first call and the second handler's text on
	 * the second.
	 *
	 * @see TRG_Dispatcher.run
	 */
	@IsTest
	private static void shouldResolveTwoHandlersInOneTransaction()
	{
		String firstServiceName = MaskingTestOutbound.class.getName();
		String secondServiceName = OtherMaskingTestOutbound.class.getName();
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, newRegexRule('HideSecretForFirst', SECRET_PATTERN, FIRST_HANDLER_TOKEN, null), firstServiceName);
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, newRegexRule('HideSecretForSecond', SECRET_PATTERN, SECOND_HANDLER_TOKEN, null), secondServiceName);

		List<ApiCall__c> stored = dispatchTwoMaskingTestCalls('request with ' + SECRET);

		Map<String, String> expectedTokenByService = new Map<String, String> {firstServiceName => FIRST_HANDLER_TOKEN, secondServiceName => SECOND_HANDLER_TOKEN};
		for(ApiCall__c storedCall : stored)
		{
			String expectedText = 'request with ' + expectedTokenByService.get(storedCall.ServiceName__c);
			Assert.areEqual(expectedText, storedCall.Request__c, 'Expected the target of ' + storedCall.ServiceName__c + ' only, got ' + storedCall.Request__c);
		}
	}

	/**
	 * @description Tests that the trigger masks a log entry and a record of another object with the pass for no caller:
	 * the target for every caller hides its secret, and a target limited to a handler class does not change anything.
	 *
	 * @see TRG_Dispatcher.run
	 */
	@IsTest
	private static void shouldLeaveLogEntriesAndOtherObjectsUnscoped()
	{
		String scopedCaller = MaskingTestOutbound.class.getName();
		MaskingRule__mdt openRule = newRegexRule('HideOpenSecret', OPEN_SECRET_PATTERN, UNSCOPED_TOKEN, null);
		MaskingRule__mdt scopedRule = newRegexRule('HideSecretForHandler', SECRET_PATTERN, FIRST_HANDLER_TOKEN, null);
		registerTarget(Foobar__c.SObjectType, Foobar__c.Text__c, openRule, null);
		registerTarget(Foobar__c.SObjectType, Foobar__c.Text__c, scopedRule, scopedCaller);
		registerTarget(LogEntry__c.SObjectType, LogEntry__c.Message__c, openRule, null);
		registerTarget(LogEntry__c.SObjectType, LogEntry__c.Message__c, scopedRule, scopedCaller);
		TST_Factory.newOutboundApiSetting(scopedCaller, null);
		SEL_TriggerAction.applyMaskingByObjectNameMap = new Map<String, Boolean>
		{
				SEL_Foobar.OBJECT_NAME => true,
				UTIL_SObjectDescribe.getObjectNameFromType(LogEntry__c.SObjectType) => true
		};
		String rawText = OPEN_SECRET + ' ' + SECRET;
		Foobar__c foobar = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withOverride(Foobar__c.Text__c, rawText).withoutInsertion().build();
		LogEntry__c logEntry = (LogEntry__c)TST_Builder.of(LogEntry__c.SObjectType).withOverride(LogEntry__c.Message__c, rawText).withoutInsertion().build();

		Test.startTest();

		runDispatcherBeforeInsert(new List<SObject> {foobar});
		runDispatcherBeforeInsert(new List<SObject> {logEntry});

		Test.stopTest();

		String expectedText = UNSCOPED_TOKEN + ' ' + SECRET;
		Assert.areEqual(expectedText, foobar.Text__c, 'Expected only the target for every caller on another object, got ' + foobar.Text__c);
		Assert.areEqual(expectedText, logEntry.Message__c, 'Expected only the target for every caller on a log entry, got ' + logEntry.Message__c);
	}

	/**
	 * @description Tests that an inbound call stores the response its handler writes after the call's records are
	 * saved, and the status code written with it: the save after the commit sends every field the commit changed after
	 * its statements ran.
	 *
	 * @see API_Base.onDMLFinished
	 * @see API_Base.buildApiCallChangesToSave
	 */
	@IsTest
	private static void shouldStoreTheInboundResponseWrittenAfterTheSave()
	{
		registerRuleThatNeverMatchesOnEveryField();

		ApiCall__c stored = dispatchMaskingTestInboundCall('{"order":"1"}', INBOUND_RESPONSE_BODY, null);

		Assert.areEqual(INBOUND_RESPONSE_BODY, stored.Response__c, 'Expected the stored response to be the one the handler wrote, got ' + stored.Response__c);
		Assert.areEqual(String.valueOf(API_Base.HTTP_OK), stored.StatusCode__c, 'Expected the stored status code 200, got ' + stored.StatusCode__c);
		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, stored.Status__c, 'Expected the inbound call Completed, got ' + stored.Status__c);
	}

	/**
	 * @description Tests that a second inbound request with the same idempotency key and body gets the response of the
	 * first one back. The first request runs through the handler and stores its response; the second reads it from the
	 * stored call, so an empty stored response would replay an empty body.
	 *
	 * @see API_Base.buildApiCallChangesToSave
	 */
	@IsTest
	private static void shouldReplayTheStoredResponseForARepeatedIdempotencyKey()
	{
		registerRuleThatNeverMatchesOnEveryField();
		registerIdempotentMaskingTestInboundSetting();
		String requestBody = '{"order":"' + UTIL_Random.randomAlphanumeric(8) + '"}';
		Map<String, String> headers = new Map<String, String> {API_Base.HEADER_IDEMPOTENCY_KEY => IDEMPOTENCY_KEY};

		Test.startTest();

		runMaskingTestInboundCall(requestBody, INBOUND_RESPONSE_BODY, headers);
		runMaskingTestInboundCall(requestBody, OPEN_SECRET, headers);

		Test.stopTest();

		String replayedBody = RestContext.response.responseBody?.toString();
		Assert.areEqual(INBOUND_RESPONSE_BODY, replayedBody, 'Expected the replay to send the stored response of the first request, got ' + replayedBody);
	}

	/**
	 * @description Tests the number of masking passes on an inbound call with a request longer than its field and a
	 * token array response that fits but grows past its field when the shipped secret-keys rule masks it. The inbound
	 * commit writes the call details before and after its statements, and the response only after them. The request is
	 * masked once before the save: the second write reuses that text. The response is masked once, by the file step,
	 * which also writes the masked text to the record, so the update after the commit sends masked text the trigger
	 * leaves alone, and the masker holds nothing for the raw response afterwards, for the handler's class or for no
	 * caller.
	 *
	 * @see API_Base.setApiCallDetails
	 * @see API_Base.createRelatedContentVersions
	 */
	@IsTest
	private static void shouldMaskEachInboundPayloadOnce()
	{
		enableMaskerPerformanceLogging();
		MaskingRule__mdt secretKeysRule = findShippedRule(SEL_MaskingRule.RULE_MASK_SECRET_KEYS);
		Assert.isNotNull(secretKeysRule, 'Expected the shipped secret-keys rule to be deployed to the org');
		registerRuleThatNeverMatchesOnEveryField();
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, newRegexRule('HideSecret', SECRET_PATTERN, HIDDEN_TOKEN, null), null);
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Response__c, secretKeysRule, null);
		String head = buildTokenArrayHead();
		String responseBody = head + 'x'.repeat(PAYLOAD_FIELD_LENGTH - head.length() - TOKEN_ARRAY_TAIL.length()) + TOKEN_ARRAY_TAIL;

		ApiCall__c stored = dispatchMaskingTestInboundCall(SECRET + ' ' + 'v'.repeat(OVERSIZED_PAYLOAD_LENGTH), responseBody, null);

		Integer requestRunsBeforeTheSave = findPayloadMaskingEntries(ApiCall__c.Request__c).size();
		Assert.areEqual(1, requestRunsBeforeTheSave, 'Expected the request masked once although the inbound commit writes it twice, got ' + requestRunsBeforeTheSave);
		Integer filePathRuns = findMaskerEntries(ContentVersion.SObjectType).size();
		Assert.areEqual(1, filePathRuns, 'Expected the file step to mask the response, written after the save, once, got ' + filePathRuns);
		List<Integer> triggerCpuTimes = readMaskingCpuTimes(findMaskerEntries(ApiCall__c.SObjectType));
		Assert.areEqual(2, triggerCpuTimes.size(), 'Expected one masking run on the insert and one on the update, got ' + triggerCpuTimes);
		for(String callerClassName : new List<String> {MaskingTestInbound.class.getName(), UTIL_String.EMPTY})
		{
			UTIL_FrameworkMasker.MaskedValueState state = UTIL_FrameworkMasker.takeMaskedValueAnswer(ApiCall__c.Response__c, callerClassName, responseBody).state;
			Assert.areEqual(UTIL_FrameworkMasker.MaskedValueState.NOT_SEEN, state, 'Expected no trigger pass over the raw response, for the caller "'
					+ callerClassName + '", got ' + state);
		}
		Assert.isFalse(stored.Request__c.contains(SECRET), 'Expected the secret hidden in the stored request');
		Assert.areEqual(PAYLOAD_FIELD_LENGTH, stored.Response__c?.length(), 'Expected the masked response cut to the field length');
		Assert.isFalse(stored.Response__c.contains(SMALL_TOKEN_VALUE), 'Expected no secret value left in the stored response');
		Map<String, String> filesByTitle = readFilesByTitle(stored.Id);
		Assert.isTrue(filesByTitle.containsKey(REQUEST_FILE_TITLE) && filesByTitle.containsKey(RESPONSE_FILE_TITLE), 'Expected a request and a response file, got '
				+ filesByTitle.keySet());
	}

	/**
	 * @description Tests that an inbound response longer than its field, written only after the call's records are
	 * saved, is masked once, when the call details are written: the field holds the masked response cut to fit, the
	 * response file holds all of it, and the file step masks nothing again.
	 *
	 * @see API_Base.setApiCallDetails
	 */
	@IsTest
	private static void shouldMaskAnOversizedInboundResponseOnce()
	{
		enableMaskerPerformanceLogging();
		registerRuleThatNeverMatchesOnEveryField();
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Response__c, newRegexRule('HideSecret', SECRET_PATTERN, HIDDEN_TOKEN, null), null);
		String padding = 'v'.repeat(OVERSIZED_PAYLOAD_LENGTH);
		String wholeMaskedResponse = HIDDEN_TOKEN + ' ' + padding;

		ApiCall__c stored = dispatchMaskingTestInboundCall('{"order":"1"}', SECRET + ' ' + padding, null);

		Integer responseRunsBeforeTheSave = findPayloadMaskingEntries(ApiCall__c.Response__c).size();
		Assert.areEqual(1, responseRunsBeforeTheSave, 'Expected the response masked once, got ' + responseRunsBeforeTheSave);
		Integer filePathRuns = findMaskerEntries(ContentVersion.SObjectType).size();
		Assert.areEqual(0, filePathRuns, 'Expected no masking in the file step, got ' + filePathRuns);
		Assert.areEqual(UTIL_String.abbreviate(wholeMaskedResponse, ApiCall__c.Response__c), stored.Response__c, 'Expected the masked response cut to fit in the field');
		Assert.areEqual(wholeMaskedResponse, readFilesByTitle(stored.Id).get(RESPONSE_FILE_TITLE), 'Expected the response file to hold the whole masked response');
	}

	/**
	 * @description Tests that the update after an inbound commit leaves a request that did not change as the insert
	 * saved it: the request rule writes its word twice, so a second pass over the saved text would add the word again.
	 *
	 * @see API_Base.buildApiCallChangesToSave
	 */
	@IsTest
	private static void shouldNotReMaskAnUnchangedInboundRequestOnTheUpdate()
	{
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, newRegexRule('GrowWord', GROWING_WORD, GROWING_WORD + GROWING_WORD, null), null);

		ApiCall__c stored = dispatchMaskingTestInboundCall('please ' + GROWING_WORD, INBOUND_RESPONSE_BODY, null);

		Assert.areEqual('please ' + GROWING_WORD + GROWING_WORD, stored.Request__c, 'Expected the request as the one pass on the insert left it, got ' + stored.Request__c);
		Assert.areEqual(INBOUND_RESPONSE_BODY, stored.Response__c, 'Expected the response the handler wrote after the save, got ' + stored.Response__c);
	}

	/**
	 * @description Tests that an inbound request longer than its field is masked once when the commit is refused for a
	 * row lock and runs again: the second attempt writes the call details again and reuses the masked text. The call is
	 * saved once, with the masked request, and the request file holds the whole masked request.
	 *
	 * @see API_Base.setApiCallDetails
	 */
	@IsTest
	private static void shouldMaskAnOversizedInboundRequestOnceAcrossALockRetry()
	{
		enableMaskerPerformanceLogging();
		registerRuleThatNeverMatchesOnEveryField();
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, newRegexRule('HideSecret', SECRET_PATTERN, HIDDEN_TOKEN, null), null);
		String padding = 'v'.repeat(OVERSIZED_PAYLOAD_LENGTH);
		String serviceName = MaskingTestInbound.class.getName();

		try
		{
			Test.startTest();
			setUpMaskingTestInboundContext(SECRET + ' ' + padding, INBOUND_RESPONSE_BODY, null);
			DML_SharingProxy.sharingProxyForTest = new DML_ThrowingLockProxy_TEST(1);
			API_Dispatcher.execute(TST_Factory.newInboundApiCall(serviceName));
			Test.stopTest();
		}
		finally
		{
			DML_SharingProxy.sharingProxyForTest = null;
		}

		List<ApiCall__c> completed = SEL_ApiCall.assertServiceCompleted(serviceName);
		Assert.areEqual(1, completed.size(), 'Expected one call row after the retried commit, got ' + completed.size());
		Integer requestRunsBeforeTheSave = findPayloadMaskingEntries(ApiCall__c.Request__c).size();
		Assert.areEqual(1, requestRunsBeforeTheSave, 'Expected the request masked once across both attempts, got ' + requestRunsBeforeTheSave);
		String wholeMaskedRequest = HIDDEN_TOKEN + ' ' + padding;
		Assert.areEqual(UTIL_String.abbreviate(wholeMaskedRequest, ApiCall__c.Request__c), completed[0].Request__c, 'Expected the masked request cut to fit in the field');
		Assert.areEqual(wholeMaskedRequest, readFilesByTitle(completed[0].Id).get(REQUEST_FILE_TITLE), 'Expected the request file to hold the whole masked request');
	}

	/**
	 * @description Tests that one synchronous inbound save of a 2,000,000-character JSON request full of secret values
	 * finishes, with the shipped secret-keys and token rules on the request. No secret value is left in the stored request
	 * or in the request file. Reading a JSON value this long as JSON takes about seven seconds, so a synchronous save
	 * masks it with the quick text search instead.
	 *
	 * @see API_Base.setApiCallDetails
	 */
	@IsTest
	private static void shouldCompleteASynchronousInboundSaveOfALongestSecretBearingJsonRequest()
	{
		MaskingRule__mdt secretKeysRule = findShippedRule(SEL_MaskingRule.RULE_MASK_SECRET_KEYS);
		MaskingRule__mdt tokenRule = findShippedRule(SEL_MaskingRule.RULE_MASK_JWT);
		Assert.isNotNull(secretKeysRule, 'Expected the shipped secret-keys rule to be deployed to the org');
		Assert.isNotNull(tokenRule, 'Expected the shipped token rule to be deployed to the org');
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, secretKeysRule, null);
		registerTarget(ApiCall__c.SObjectType, ApiCall__c.Request__c, tokenRule, null);
		String head = '[' + '{"token":"x"},'.repeat(LONGEST_REQUEST_SMALL_TOKEN_COUNT) + '{"token":"';
		String requestBody = head + 'x'.repeat(LONGEST_REQUEST_LENGTH - head.length() - TOKEN_ARRAY_TAIL.length()) + TOKEN_ARRAY_TAIL;
		head = null;

		ApiCall__c stored = dispatchMaskingTestInboundCall(requestBody, INBOUND_RESPONSE_BODY, null);

		requestBody = null;
		Assert.isFalse(stored.Request__c.contains(SMALL_TOKEN_VALUE), 'Expected no secret value left in the stored request');
		Assert.isTrue(stored.Request__c.startsWith('[{"token":"' + secretKeysRule.Replacement__c + '"}'), 'Expected the stored request masked, got ' + stored.Request__c.left(40));
		String fileText = readFilesByTitle(stored.Id).get(REQUEST_FILE_TITLE);
		Assert.isFalse(fileText.contains(SMALL_TOKEN_VALUE), 'Expected no secret value left in the request file');
		Assert.areEqual(LONGEST_REQUEST_SMALL_TOKEN_COUNT + 1, fileText.countMatches(secretKeysRule.Replacement__c), 'Expected every secret value replaced in the file');
	}

	/**
	 * @description Runs the trigger dispatcher on records in memory, as the before-insert step of a save would, with no
	 * configured trigger action, so only the masking step runs.
	 *
	 * @param records The records of one object to mask in place.
	 */
	private static void runDispatcherBeforeInsert(List<SObject> records)
	{
		TRG_Dispatcher dispatcher = new TRG_Dispatcher();
		dispatcher.triggerNew = records;
		dispatcher.context = TriggerOperation.BEFORE_INSERT;
		dispatcher.actionMetadataOverride = new Map<TriggerOperation, List<TriggerAction__mdt>>
		{
				TriggerOperation.BEFORE_INSERT => new List<TriggerAction__mdt>()
		};
		dispatcher.run();
	}

	/**
	 * @description Registers the API setting of a masking test handler, then sends one call through the dispatcher, with
	 * the given request body, mocked response body and request parameters, and reads the stored call back.
	 *
	 * @param serviceName The masking test handler class to run.
	 * @param requestBody The request body the handler sends; may be null.
	 * @param responseBody The response body the mock sends back.
	 * @param parameters The request parameters of the call; may be null.
	 *
	 * @return The stored call, or null when no call row was saved.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static ApiCall__c dispatchMaskingTestCall(String serviceName, String requestBody, String responseBody, Map<String, String> parameters)
	{
		TST_Factory.newOutboundApiSetting(serviceName, null);
		maskingTestRequestBody = requestBody;
		API_MockFactory.forService(serviceName).body(responseBody).statusCode(API_Base.HTTP_OK).register();
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId(), parameters ?? new Map<String, String>());

		Test.startTest();

		API_Dispatcher.execute(apiCall);

		Test.stopTest();

		return apiCall.Id == null ? null : (ApiCall__c)new SEL_ApiCall().findById(apiCall.Id);
	}

	/**
	 * @description Sends one inbound request to the inbound masking test handler through the dispatcher, with the given
	 * request body and the response body the handler writes after the save, and reads the stored call back.
	 *
	 * @param requestBody The body of the inbound request.
	 * @param responseBody The response body the handler writes after its records are saved.
	 * @param headers Extra request headers; may be null.
	 *
	 * @return The stored call.
	 */
	private static ApiCall__c dispatchMaskingTestInboundCall(String requestBody, String responseBody, Map<String, String> headers)
	{
		Test.startTest();

		API_Base handler = runMaskingTestInboundCall(requestBody, responseBody, headers);

		Test.stopTest();

		return (ApiCall__c)new SEL_ApiCall().findById(handler.apiCall.Id);
	}

	/**
	 * @description Sets up the REST context and runs one inbound request through the dispatcher's inbound entry, for
	 * the inbound masking test handler.
	 *
	 * @param requestBody The body of the inbound request.
	 * @param responseBody The response body the handler writes after its records are saved.
	 * @param headers Extra request headers; may be null.
	 *
	 * @return The handler that ran the request.
	 */
	private static API_Base runMaskingTestInboundCall(String requestBody, String responseBody, Map<String, String> headers)
	{
		setUpMaskingTestInboundContext(requestBody, responseBody, headers);
		return API_Dispatcher.processInboundService(MaskingTestInbound.class.getName());
	}

	/**
	 * @description Sets up the REST context of an inbound request and the response the inbound masking test handler
	 * writes.
	 *
	 * @param requestBody The body of the inbound request.
	 * @param responseBody The response body the handler writes after its records are saved.
	 * @param headers Extra request headers; may be null.
	 */
	private static void setUpMaskingTestInboundContext(String requestBody, String responseBody, Map<String, String> headers)
	{
		API_InboundTestHelper.setupRestContext();
		RestContext.request.requestBody = Blob.valueOf(requestBody);
		for(String headerName : (headers ?? new Map<String, String>()).keySet())
		{
			RestContext.request.headers.put(headerName, headers.get(headerName));
		}
		maskingTestResponseBody = responseBody;
	}

	/**
	 * @description Registers the API setting of the inbound masking test handler, with idempotency on, so a request sent
	 * again with the same idempotency key gets the stored response back.
	 */
	private static void registerIdempotentMaskingTestInboundSetting()
	{
		TST_Mock.of(ApiSetting__mdt.SObjectType).withOverrides(new Map<SObjectField, Object>
		{
				ApiSetting__mdt.ClassName__c => MaskingTestInbound.class.getName(),
				ApiSetting__mdt.Direction__c => SEL_ApiSetting.DIRECTION_INBOUND,
				ApiSetting__mdt.IsActive__c => true,
				ApiSetting__mdt.IdempotencyEnabled__c => true
		}).build();
	}

	/**
	 * @description Registers the API settings of both masking test handlers, then sends one call for each through the
	 * dispatcher in one batch, with the same request body, and reads the stored calls back.
	 *
	 * @param requestBody The request body both handlers send.
	 *
	 * @return The stored calls, one for each handler.
	 */
	private static List<ApiCall__c> dispatchTwoMaskingTestCalls(String requestBody)
	{
		List<ApiCall__c> apiCalls = new List<ApiCall__c>();
		for(String serviceName : new List<String> {MaskingTestOutbound.class.getName(), OtherMaskingTestOutbound.class.getName()})
		{
			TST_Factory.newOutboundApiSetting(serviceName, null);
			API_MockFactory.forService(serviceName).body(SUCCESS_RESPONSE_BODY).statusCode(API_Base.HTTP_OK).register();
			apiCalls.add(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		}
		maskingTestRequestBody = requestBody;

		Test.startTest();

		API_Dispatcher.execute(apiCalls);

		Test.stopTest();

		return new SEL_ApiCall().findById(new Map<Id, ApiCall__c>(apiCalls).keySet());
	}

	/**
	 * @description Builds a test masking rule in regular expression mode, held in memory only.
	 *
	 * @param developerName The rule name.
	 * @param rulePattern The regular expression the rule finds.
	 * @param replacement The text the rule writes in place of each match.
	 * @param failureAction What happens when the rule fails; null for the default, which logs and keeps the value.
	 *
	 * @return The rule.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static MaskingRule__mdt newRegexRule(String developerName, String rulePattern, String replacement, String failureAction)
	{
		return (MaskingRule__mdt)TST_Builder.of(MaskingRule__mdt.SObjectType).withOverrides(new Map<SObjectField, Object>
		{
				MaskingRule__mdt.DeveloperName => developerName,
				MaskingRule__mdt.Mode__c => SEL_MaskingRule.MODE_REGEX,
				MaskingRule__mdt.Pattern__c => rulePattern,
				MaskingRule__mdt.Replacement__c => replacement,
				MaskingRule__mdt.IsActive__c => true,
				MaskingRule__mdt.FailureAction__c => failureAction
		}).withoutInsertion(true).build();
	}

	/**
	 * @description Registers an active masking target that links a rule to a field, or to every text field of the
	 * object when no field is given. The masker reads only the registered targets in the running test.
	 *
	 * @param objectType The object the target names.
	 * @param field The field the target names; null for every text field of the object.
	 * @param rule The rule the target runs.
	 * @param callerClassName The handler class the target is limited to; null for every caller.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static void registerTarget(SObjectType objectType, SObjectField field, MaskingRule__mdt rule, String callerClassName)
	{
		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(objectType);
		TST_Mock.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.IsActive__c, true)
				.withOverride(MaskingTarget__mdt.SObjectType__c, objectName)
				.withOverride(MaskingTarget__mdt.Field__c, field == null ? null : objectName + UTIL_String.DOT + UTIL_SObjectDescribe.getCachedFieldName(field))
				.withOverride(MaskingTarget__mdt.CallerClass__c, callerClassName)
				.withOverride(MaskingTarget__mdt.Rule__c, rule)
				.build();
	}

	/**
	 * @description Registers a rule that never matches for every text field of an API call, so each payload field gets
	 * a masking pass on the save even when no other test rule names it.
	 */
	private static void registerRuleThatNeverMatchesOnEveryField()
	{
		registerTarget(ApiCall__c.SObjectType, null, newRegexRule('NeverMatches', NEVER_MATCHING_PATTERN, HIDDEN_TOKEN, null), null);
	}

	/**
	 * @description Finds a shipped masking rule by its name.
	 *
	 * @param developerName The rule name, from the SEL_MaskingRule constants.
	 *
	 * @return The deployed rule, or null when it is not in the org.
	 */
	private static MaskingRule__mdt findShippedRule(String developerName)
	{
		for(MaskingRule__mdt rule : new SEL_MaskingTarget().getAllRulesById().values())
		{
			if(rule.DeveloperName == developerName)
			{
				return rule;
			}
		}
		return null;
	}

	/**
	 * @description Switches the masking performance log on for every masking run, whatever its length, and lets the
	 * test save log entries, so each run leaves one entry the test can read.
	 */
	private static void enableMaskerPerformanceLogging()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.newLoggerSettings().withMaskerLogging(0).apply();
	}

	/**
	 * @description Reads the masking performance log entries written for one object: the trigger runs write them under
	 * the object they mask, and the file step under ContentVersion.
	 *
	 * @param objectType The object whose masking runs to read.
	 *
	 * @return The entries, one for each masking run.
	 */
	private static List<LogEntry__c> findMaskerEntries(SObjectType objectType)
	{
		return new SEL_LogEntry().findAllByMethod(UTIL_MaskerPerformanceTimer.class.getName() + '/' + UTIL_SObjectDescribe.getObjectNameFromType(objectType));
	}

	/**
	 * @description Reads the masking performance log entries the handler wrote when it masked a payload too long for
	 * its field before the save: one entry each time, under the payload field's name.
	 *
	 * @param field The payload field of the API call.
	 *
	 * @return The entries, one for each time the handler masked that payload.
	 */
	private static List<LogEntry__c> findPayloadMaskingEntries(SObjectField field)
	{
		return new SEL_LogEntry().findAllByMethod(UTIL_MaskerPerformanceTimer.class.getName() + '/' + UTIL_SObjectDescribe.getObjectNameFromType(ApiCall__c.SObjectType)
				+ UTIL_String.DOT + UTIL_SObjectDescribe.getCachedFieldName(field));
	}

	/**
	 * @description Reads the CPU time each masking performance log entry reports, in the order the entries were
	 * written. Log entries are numbered as they are saved, so the order of their names is the order of the runs.
	 *
	 * @param entries The masking performance log entries.
	 *
	 * @return The CPU time of each entry in milliseconds, earliest run first; an entry with no CPU time adds nothing.
	 */
	private static List<Integer> readMaskingCpuTimes(List<LogEntry__c> entries)
	{
		Map<String, LogEntry__c> entriesByName = new Map<String, LogEntry__c>();
		for(LogEntry__c entry : entries)
		{
			entriesByName.put(entry.Name, entry);
		}
		List<String> names = new List<String>(entriesByName.keySet());
		names.sort();

		List<Integer> cpuTimes = new List<Integer>();
		for(String name : names)
		{
			Matcher cpuMatcher = CPU_IN_DETAILS.matcher(entriesByName.get(name).Message__c ?? UTIL_String.EMPTY);
			if(cpuMatcher.find())
			{
				cpuTimes.add(Integer.valueOf(cpuMatcher.group(1)));
			}
		}
		return cpuTimes;
	}

	/**
	 * @description Reads the files attached to a stored call, by the start of their title.
	 *
	 * @param apiCallId The stored call.
	 *
	 * @return The text of each file, keyed by its title without the file extension.
	 */
	private static Map<String, String> readFilesByTitle(Id apiCallId)
	{
		Map<String, String> filesByTitle = new Map<String, String>();
		for(ContentVersion version : new SEL_ContentVersion().findByFirstPublishLocationId(apiCallId))
		{
			filesByTitle.put(version.Title.substringBefore(SEL_ContentVersion.TEXT_FILE_EXTENSION), version.VersionData.toString());
		}
		return filesByTitle;
	}

	/**
	 * @description Builds the start of the token array request: a list of SMALL_TOKEN_COUNT objects whose token is the
	 * one-letter secret x, then the start of the last object, whose token the caller fills.
	 *
	 * @return The start of the request.
	 */
	private static String buildTokenArrayHead()
	{
		return '[' + '{"token":"x"},'.repeat(SMALL_TOKEN_COUNT) + '{"token":"';
	}

	/**
	 * @description An outbound handler for the masking tests. It sends the request body and the address the running
	 * test sets, needs no triggering record, and accepts any response body, so a test chooses every payload of the call.
	 */
	public virtual class MaskingTestOutbound extends API_Outbound
	{
		/**
		 * @description Sets the payload types and clears the need for a triggering record.
		 */
		public override void configure()
		{
			super.configure();
			requestPayload = new DTO_Base();
			responsePayload = new DTO_Base();
			requiresTriggeringRecord = false;
		}

		/**
		 * @description Sends the request body the running test set.
		 *
		 * @return The request body.
		 */
		public override String getBody()
		{
			return maskingTestRequestBody;
		}

		/**
		 * @description Sends the request to the address the running test set.
		 *
		 * @return The address.
		 */
		public override String getWebServiceEndPoint()
		{
			return maskingTestUrl;
		}

		/**
		 * @description Accepts any response body: the masking tests read the stored text, not a parsed response.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public override void parseResponse()
		{
		}
	}

	/**
	 * @description An inbound handler for the masking tests. It accepts any request body and writes the response body
	 * the running test sets. It writes it in updateCallResult, which runs after the call's records are saved, as a
	 * handler that answers with saved data does.
	 */
	public class MaskingTestInbound extends API_Inbound
	{
		/**
		 * @description Accepts any request body: the masking tests read the stored text, not a parsed request.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public override void parseRequest()
		{
		}

		/**
		 * @description Writes the response body the running test set.
		 */
		public override void updateCallResult()
		{
			result.responseBody = maskingTestResponseBody;
		}
	}

	/**
	 * @description A second masking test handler, so a test can save calls of two different handler classes together.
	 */
	public class OtherMaskingTestOutbound extends MaskingTestOutbound
	{
	}

	/**
	 * @description A masking test handler with a step of its own that adds a secret to the request field after the
	 * framework wrote it and before the save.
	 */
	public class FieldChangingMaskingTestOutbound extends MaskingTestOutbound
	{
		/**
		 * @description Writes the call details, then adds the secret to the end of the request field.
		 */
		public override void setApiCallDetails()
		{
			super.setApiCallDetails();
			apiCall.Request__c = apiCall.Request__c + ' ' + SECRET;
		}
	}

	/**
	 * @description An inbound handler that registers one record for the commit and counts each time it writes the REST
	 * response, so a test can tell a retried commit from a second response.
	 */
	public virtual class RecordSavingInbound extends API_Inbound
	{
		/**
		 * @description Registers the record the commit must save.
		 */
		public override void onSuccess()
		{
			doInsert(TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().withOverride(Foobar__c.Name, SAVED_RECORD_NAME).build());
		}

		/**
		 * @description Counts the response, then writes it.
		 */
		public override void writeResponse()
		{
			responseWriteCount++;
			super.writeResponse();
		}
	}

	/**
	 * @description The record-saving inbound handler with an after-commit step of its own that throws once its records
	 * are saved, before the base step runs. After an attempt that saved nothing it runs the base step, so a commit
	 * refused for a row lock is still run again.
	 */
	public class ThrowingAfterCommitInbound extends RecordSavingInbound
	{
		/**
		 * @description Throws in place of the base step once the records are saved.
		 *
		 * @param wasSuccessful Whether the attempt saved its records.
		 */
		@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
		public override void onCommitWorkFinished(Boolean wasSuccessful)
		{
			if(wasSuccessful)
			{
				throw new UTIL_Exceptions.IllegalStateException(MESSAGE_THROWN_AFTER_COMMIT);
			}
			super.onCommitWorkFinished(wasSuccessful);
		}
	}

	/**
	 * @description The smallest handler built straight on the base class. It gives only the content type, the one
	 * thing the base class leaves open, so it keeps every base step as it is, including the step that resolves earlier
	 * issues.
	 */
	public class BaseResolveStepHandler extends API_Base
	{
		/**
		 * @description Gives the content type of the handler's calls.
		 *
		 * @return The JSON content type.
		 */
		public override String getEncoding()
		{
			return API_Base.HTTP_ENCODING_JSON;
		}
	}
}