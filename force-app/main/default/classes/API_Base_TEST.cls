// SPDX-License-Identifier: BUSL-1.1
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
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
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

		MaskingRule__mdt rule = (MaskingRule__mdt)TST_Builder.of(MaskingRule__mdt.SObjectType)
				.withOverride(MaskingRule__mdt.DeveloperName, 'BadPattern')
				.withOverride(MaskingRule__mdt.Mode__c, SEL_MaskingRule.MODE_REGEX)
				.withOverride(MaskingRule__mdt.Pattern__c, '(invalid[')
				.withOverride(MaskingRule__mdt.Replacement__c, '***')
				.withOverride(MaskingRule__mdt.IsActive__c, true)
				.withoutInsertion(true)
				.build();

		String apiCallObjectName = UTIL_SObjectDescribe.getObjectNameFromType(ApiCall__c.SObjectType);
		String requestFieldName = UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.Request__c);

		TST_Mock.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.IsActive__c, true)
				.withOverride(MaskingTarget__mdt.SObjectType__c, apiCallObjectName)
				.withOverride(MaskingTarget__mdt.Field__c, apiCallObjectName + UTIL_String.DOT + requestFieldName)
				.withOverride(MaskingTarget__mdt.CallerClass__c, API_PostExample.class.getName())
				.withOverride(MaskingTarget__mdt.Rule__c, rule)
				.build();

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
}