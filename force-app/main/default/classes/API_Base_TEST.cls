// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the behavior of the [API_Base] class, covering ServiceCallResult properties,
 * WebserviceStatus enum behavior, and base-class validation logic.
 *
 * @see API_Base
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class API_Base_TEST
{
	/**
	 * @description Error message expected when status text is incorrect.
	 */
	private static final String MSG_WRONG_STATUS = 'Incorrect status text';

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
}