// SPDX-License-Identifier: MIT
/**
 * MIT License
 *
 * Copyright (c) Mike Lockett 2024
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/**
 * @description Tests the behavior of the logger, adapted from [ApexLogger](https://github.com/mlockett/ApexLogger).
 *
 * @see LOG_Engine
 * @see TRG_PersistLogEntry
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
@IsTest(SeeAllData=false IsParallel=false)
private class LOG_Engine_TEST
{
	private static final Integer SOQL_QUERY_LIMIT = UTIL_Limits.publishImmediateDml().maximum();
	private static final Integer RECORDS_TO_INSERT = SOQL_QUERY_LIMIT - 1;
	private static final String CLASS_METHOD = 'Foobar/method';
	private static final String CLASS_METHOD_PUBLISH = TST_Factory.class.getName() + '/publishLogEvents';
	private static final String MESSAGE = UTIL_Random.randomName();
	private static final String MSG_CORRECT_SIZE = 'Incorrect number of items';
	private static final String MSG_LOGGING_ALLOWED = 'Logging should be allowed';
	private static final String MSG_LOGGING_NOT_ALLOWED = 'Logging should not be allowed';
	private static final String MSG_NOT_EMPTY = 'Log records should be present';
	private static final String MSG_NO_EXCEPTION = 'No exception should be thrown';
	private static final String MSG_NO_LOGS = 'No log records should be created';
	private static final String MSG_QUEUEABLE_JOB = 'One queueable job should be enqueued';
	private static final String MSG_VALUE_EQUALITY = 'Value should match expected';
	private static final String MSG_WRONG_TYPE = 'Incorrect exception type';
	private static final String TEST_ADMIN_COMPANY = 'LOG_Engine_TEST-admin';
	private static final String LOW_PRIVILEGE_COMPANY = 'LOG_Engine_TEST-low-privilege';
	private static final String TIER_A_CLASS_METHOD = 'LowPrivilegeEmitter.emit';
	private static final String TIER_A_MESSAGE = 'low-privilege-emission';

	/**
	 * @description Commits both a test-admin and a low-privilege user in @TestSetup's separate
	 * transaction so the tier-A test (shouldEmitLogEntryForLowPrivilegeUser) can use System.runAs
	 * against either without triggering MIXED_DML_OPERATION. User is a Setup object, so User DML
	 * cannot mix with standard/custom-object DML in the same transaction; pre-provisioning here
	 * satisfies that boundary.
	 *
	 * Only the tier-A test uses these users — existing LOG_Engine tests continue to run as the
	 * @IsTest running user without runAs.
	 */
	@TestSetup
	private static void setupTestUsers()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);

		User lowPrivilegeUser = TST_Factory.newMinimumAccessUser(LOW_PRIVILEGE_COMPANY);
		insert lowPrivilegeUser;
	}

	/**
	 * @description Returns a pre-configured builder for an org-level LogSetting__c with
	 * SetupOwnerId, IsEnabled__c, and LogLevelThreshold__c (WARN) set. Callers chain additional
	 * overrides before .build() to insert the record. Dedupes the opening of two tests that
	 * both build an org-level LogSetting__c with the same first three overrides.
	 *
	 * @return A TST_Builder.Builder positioned to insert an org-level LogSetting__c with
	 * WARN threshold.
	 */
	private static TST_Builder.Builder orgLevelLogSettingBuilder()
	{
		return TST_Builder.of(LogSetting__c.SObjectType)
				.withOverride(LogSetting__c.SetupOwnerId, UserInfo.getOrganizationId())
				.withOverride(LogSetting__c.IsEnabled__c, true)
				.withOverride(LogSetting__c.LogLevelThreshold__c, LOG_Engine.LEVEL_WARN);
	}

	/**
	 * @description Configures a LogSetting__c override with DEBUG threshold for logger tests.
	 */
	private static void setupTestData()
	{
		LogSetting__c setting = new LogSetting__c();
		setting.IsEnabled__c = true;
		setting.LogLevelThreshold__c = LOG_Engine.LEVEL_DEBUG;
		setting.EnablePerformanceLogging__c = true;
		setting.EnableQueryPerformanceLogging__c = true;
		setting.EnableTriggerPerformanceLogging__c = true;
		setting.EnableValidationPerformanceLogging__c = true;
		setting.PerformanceThresholdMs__c = 10000;
		setting.QueryPerformanceThresholdMs__c = 1000;
		setting.TriggerPerformanceThresholdMs__c = 500;
		setting.ValidationPerformanceThresholdMs__c = 100;
		LOG_Engine.logSettingOverride = setting;
	}

	/**
	 * @description Tests that DEBUG and INFO logs are dropped when threshold is WARN.
	 *
	 * @see LOG_Engine.isLoggable
	 */
	@IsTest
	private static void shouldFilterByThreshold()
	{
		setupTestData();
		LOG_Engine.logSettingOverride.LogLevelThreshold__c = LOG_Engine.LEVEL_WARN;
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.DEBUG);
		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.INFO);

		Test.stopTest();

		Integer logCount = new SEL_LogEntry().getRecordCount();

		Assert.areEqual(0, logCount, MSG_NO_LOGS);
	}

	/**
	 * @description Tests that ERROR always passes even when logging is disabled.
	 *
	 * @see LOG_Engine.isLoggable
	 */
	@IsTest
	private static void shouldAlwaysEmitError()
	{
		setupTestData();
		LOG_Engine.logSettingOverride.IsEnabled__c = false;
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.ERROR);

		Test.stopTest();

		LogEntry__c retrievedLog = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.isNotNull(retrievedLog, MSG_NOT_EMPTY);
		Assert.areEqual(LOG_Engine.LEVEL_ERROR, retrievedLog.LogLevel__c, MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests the kill switch: IsEnabled=false drops DEBUG/INFO/WARN.
	 *
	 * @see LOG_Engine.isLoggable
	 */
	@IsTest
	private static void shouldApplyKillSwitch()
	{
		setupTestData();
		LOG_Engine.logSettingOverride.IsEnabled__c = false;
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.DEBUG);
		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.INFO);
		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.WARN);

		Test.stopTest();

		Integer logCount = new SEL_LogEntry().getRecordCount();

		Assert.areEqual(0, logCount, MSG_NO_LOGS);
	}

	/**
	 * @description Tests that ClassFilter filters by class name pattern.
	 *
	 * @see LOG_Engine.isLoggable
	 */
	@IsTest
	private static void shouldFilterByClassPattern()
	{
		setupTestData();
		LOG_Engine.logSettingOverride.ClassFilter__c = 'API_*';
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		LOG_Engine.log(MESSAGE, 'API_SendEmail/send', LoggingLevel.WARN);
		LOG_Engine.log(MESSAGE, 'TRG_SetDefaults/beforeInsert', LoggingLevel.WARN);

		Test.stopTest();

		List<LogEntry__c> entries = new SEL_LogEntry().getAll();

		Assert.areEqual(1, entries.size(), MSG_CORRECT_SIZE);
		Assert.isTrue(entries[0].ClassMethod__c.startsWith('API_'), 'Only API_ class should be logged');
	}

	/**
	 * @description Tests comma-separated ClassFilter with multiple patterns.
	 *
	 * @see LOG_Engine.matchesClassFilter
	 */
	@IsTest
	private static void shouldMatchMultiplePatterns()
	{
		Test.startTest();

		Boolean matchesApi = LOG_Engine.matchesClassFilter('API_SendEmail', 'API_*,SVC_*');
		Boolean matchesSvc = LOG_Engine.matchesClassFilter('SVC_Payment', 'API_*,SVC_*');
		Boolean noMatch = LOG_Engine.matchesClassFilter('TRG_SetDefaults', 'API_*,SVC_*');

		Test.stopTest();

		Assert.isTrue(matchesApi, MSG_LOGGING_ALLOWED);
		Assert.isTrue(matchesSvc, MSG_LOGGING_ALLOWED);
		Assert.isFalse(noMatch, MSG_LOGGING_NOT_ALLOWED);
	}

	/**
	 * @description Tests exact class name match without wildcard.
	 *
	 * @see LOG_Engine.matchesClassFilter
	 */
	@IsTest
	private static void shouldMatchExactClassName()
	{
		Test.startTest();

		Boolean exactMatch = LOG_Engine.matchesClassFilter('API_SendEmail', 'API_SendEmail');
		Boolean noMatch = LOG_Engine.matchesClassFilter('API_SendSms', 'API_SendEmail');

		Test.stopTest();

		Assert.isTrue(exactMatch, MSG_LOGGING_ALLOWED);
		Assert.isFalse(noMatch, MSG_LOGGING_NOT_ALLOWED);
	}

	/**
	 * @description Tests that null classMethod passes through when ClassFilter is set.
	 *
	 * @see LOG_Engine.isLoggable
	 */
	@IsTest
	private static void shouldPassWhenClassMethodNull()
	{
		setupTestData();
		LOG_Engine.logSettingOverride.ClassFilter__c = 'API_*';

		Test.startTest();

		Boolean result = LOG_Engine.isLoggable(LoggingLevel.WARN, null);

		Test.stopTest();

		Assert.isTrue(result, MSG_LOGGING_ALLOWED);
	}

	/**
	 * @description Tests that SuppressClassMethod denylist drops matching classes even when
	 * ClassFilter is blank (so the allowlist wouldn't reject them). Common subscriber pattern:
	 * "log everything except this noisy class".
	 *
	 * @see LOG_Engine.isLoggable
	 */
	@IsTest
	private static void shouldSuppressDenylistedClassWhenAllowlistBlank()
	{
		setupTestData();
		LOG_Engine.logSettingOverride.ClassFilter__c = null;
		LOG_Engine.logSettingOverride.SuppressClassMethod__c = 'TST_*';
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		LOG_Engine.log(MESSAGE, 'API_SendEmail/send', LoggingLevel.WARN);
		LOG_Engine.log(MESSAGE, 'TST_NoisyJob/run', LoggingLevel.WARN);

		Test.stopTest();

		List<LogEntry__c> entries = new SEL_LogEntry().getAll();

		Assert.areEqual(1, entries.size(), MSG_CORRECT_SIZE);
		Assert.isTrue(entries[0].ClassMethod__c.startsWith('API_'),
				'Denylisted TST_ class should be suppressed; only API_ class should be logged');
	}

	/**
	 * @description Tests that SuppressClassMethod takes precedence when a class matches BOTH
	 * the ClassFilter allowlist AND the SuppressClassMethod denylist. Suppression wins.
	 *
	 * @see LOG_Engine.isLoggable
	 */
	@IsTest
	private static void shouldSuppressEvenWhenAllowlistMatches()
	{
		setupTestData();
		LOG_Engine.logSettingOverride.ClassFilter__c = 'API_*';
		LOG_Engine.logSettingOverride.SuppressClassMethod__c = 'API_HighVolume*';
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		LOG_Engine.log(MESSAGE, 'API_SendEmail/send', LoggingLevel.WARN);
		LOG_Engine.log(MESSAGE, 'API_HighVolumeImport/process', LoggingLevel.WARN);

		Test.stopTest();

		List<LogEntry__c> entries = new SEL_LogEntry().getAll();

		Assert.areEqual(1, entries.size(), MSG_CORRECT_SIZE);
		Assert.isTrue(entries[0].ClassMethod__c.startsWith('API_SendEmail'),
				'API_HighVolume* should be suppressed even though ClassFilter API_* allowed it');
	}

	/**
	 * @description Tests that blank ClassFilter allows all classes.
	 *
	 * @see LOG_Engine.isLoggable
	 */
	@IsTest
	private static void shouldPassAllClassesWhenFilterBlank()
	{
		setupTestData();
		LOG_Engine.logSettingOverride.ClassFilter__c = null;

		Test.startTest();

		Boolean result = LOG_Engine.isLoggable(LoggingLevel.WARN, 'TRG_SetDefaults/beforeInsert');

		Test.stopTest();

		Assert.isTrue(result, MSG_LOGGING_ALLOWED);
	}

	/**
	 * @description Tests handling DML limit breaches during log publishing.
	 *
	 * @see TST_Factory.publishLogEvents
	 */
	@IsTest
	private static void handleDmlLimitFailure()
	{
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		TST_Factory.publishLogEvents(RECORDS_TO_INSERT + 1);

		Test.stopTest();

		Integer logCount = new SEL_LogEntry().findAllByMethod(CLASS_METHOD_PUBLISH).size();

		Assert.isTrue(logCount >= SOQL_QUERY_LIMIT, MSG_CORRECT_SIZE + ': Expected: >= ' + SOQL_QUERY_LIMIT + ', Actual: ' + logCount);
	}

	/**
	 * @description Tests the isLoggable method with threshold and class filter scenarios.
	 *
	 * @see LOG_Engine.isLoggable
	 */
	@IsTest
	private static void shouldFilterByThresholdAndClassFilter()
	{
		setupTestData();

		Test.startTest();

		Assert.isTrue(LOG_Engine.isLoggable(LoggingLevel.DEBUG, CLASS_METHOD), 'DEBUG should pass with DEBUG threshold');

		LOG_Engine.logSettingOverride.LogLevelThreshold__c = LOG_Engine.LEVEL_WARN;
		Assert.isFalse(LOG_Engine.isLoggable(LoggingLevel.DEBUG, CLASS_METHOD), 'DEBUG should fail with WARN threshold');
		Assert.isFalse(LOG_Engine.isLoggable(LoggingLevel.INFO, CLASS_METHOD), 'INFO should fail with WARN threshold');
		Assert.isTrue(LOG_Engine.isLoggable(LoggingLevel.WARN, CLASS_METHOD), 'WARN should pass with WARN threshold');
		Assert.isTrue(LOG_Engine.isLoggable(LoggingLevel.ERROR, CLASS_METHOD), 'ERROR always passes');

		LOG_Engine.logSettingOverride.LogLevelThreshold__c = LOG_Engine.LEVEL_DEBUG;
		LOG_Engine.logSettingOverride.ClassFilter__c = 'API_*';
		Assert.isFalse(LOG_Engine.isLoggable(LoggingLevel.WARN, 'TRG_SetDefaults/beforeInsert'), 'Non-matching class should fail');
		Assert.isTrue(LOG_Engine.isLoggable(LoggingLevel.WARN, 'API_SendEmail/send'), 'Matching class should pass');

		Test.stopTest();
	}

	/**
	 * @description Tests asynchronous logging when DML limits are breached.
	 *
	 * @see LOG_Engine.log
	 */
	@IsTest
	private static void logAsynchronouslyWithLimits()
	{
		setupTestData();

		LOG_Engine.ignoreTestMode = true;
		LOG_Engine.simulateDMLimitsBreach = true;

		Test.startTest();

		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.WARN);

		Assert.areEqual(1, UTIL_Limits.queueableJobs().used(), MSG_QUEUEABLE_JOB);

		Test.stopTest();

		LogEntry__c retrievedLog = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.areEqual(MESSAGE, retrievedLog.Message__c, MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests logging an exception with DEBUG level.
	 *
	 * @see LOG_Engine.log
	 */
	@IsTest
	@SuppressWarnings('PMD.UnusedLocalVariable,ApexUnusedDeclaration')
	private static void logDebugExceptionCorrectly()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		try
		{
			Double badNumber = 1 / 0;
		}
		catch(Exception caughtException)
		{
			LOG_Engine.log(caughtException, CLASS_METHOD, LoggingLevel.DEBUG);
		}

		Test.stopTest();

		LogEntry__c retrievedLog = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.isTrue(retrievedLog.ExceptionType__c.equals('System.MathException'), MSG_WRONG_TYPE);
		Assert.areEqual(LOG_Engine.LEVEL_DEBUG, retrievedLog.LogLevel__c, MSG_VALUE_EQUALITY);
		Assert.areEqual(UserInfo.getUserId(), retrievedLog.UserId__c, MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests logging an exception correctly.
	 *
	 * @see LOG_Engine.log
	 */
	@IsTest
	@SuppressWarnings('PMD.UnusedLocalVariable,ApexUnusedDeclaration')
	private static void logExceptionCorrectly()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		try
		{
			Double badNumber = 1 / 0;
		}
		catch(Exception caughtException)
		{
			LOG_Engine.log(caughtException, CLASS_METHOD, LoggingLevel.ERROR);
		}

		Test.stopTest();

		LogEntry__c retrievedLog = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.isTrue(retrievedLog.ExceptionType__c.equals('System.MathException'), MSG_WRONG_TYPE);
		Assert.areEqual(LOG_Engine.LEVEL_ERROR, retrievedLog.LogLevel__c, MSG_VALUE_EQUALITY);
		Assert.areEqual(UserInfo.getUserId(), retrievedLog.UserId__c, MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests logging an exception with a record ID.
	 *
	 * @see LOG_Engine.log
	 */
	@IsTest
	@SuppressWarnings('PMD.UnusedLocalVariable,ApexUnusedDeclaration')
	private static void logExceptionWithRecordId()
	{
		final String recordId = UTIL_Random.randomId(Foobar__c.SObjectType);

		setupTestData();
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		try
		{
			Double badNumber = 1 / 0;
		}
		catch(Exception caughtException)
		{
			LOG_Engine.log(caughtException, CLASS_METHOD, recordId, LoggingLevel.ERROR);
		}

		Test.stopTest();

		LogEntry__c retrievedLog = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.isTrue(retrievedLog.ExceptionType__c.equals('System.MathException'), MSG_WRONG_TYPE);
		Assert.areEqual(LOG_Engine.LEVEL_ERROR, retrievedLog.LogLevel__c, MSG_VALUE_EQUALITY);
		Assert.areEqual(recordId, retrievedLog.RecordId__c, MSG_VALUE_EQUALITY);
		Assert.areEqual(UserInfo.getUserId(), retrievedLog.UserId__c, MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests logging a message with correct field values.
	 *
	 * @see LOG_Engine.log
	 */
	@IsTest
	private static void logMessageCorrectly()
	{
		setupTestData();

		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.WARN);

		Test.stopTest();

		LogEntry__c retrievedLog = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.areEqual(MESSAGE, retrievedLog.Message__c, MSG_VALUE_EQUALITY);
		Assert.areEqual(LOG_Engine.LEVEL_WARN, retrievedLog.LogLevel__c, MSG_VALUE_EQUALITY);
		Assert.areEqual(UserInfo.getUserId(), retrievedLog.UserId__c, MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests immediate publishing of log events in unit tests.
	 *
	 * @see LOG_Engine.log
	 */
	@IsTest
	private static void verifyImmediateEventPublishing()
	{
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		LOG_Engine.log((String)null, (String)null, (String)null, (Id)null, null);

		Test.stopTest();

		Assert.isTrue(!new SEL_LogEntry().getAll().isEmpty(), MSG_NOT_EMPTY);
	}

	/**
	 * @description Tests the isLoggable method without a configured LogSetting__c override.
	 * Code-level defaults should apply (DEBUG threshold, all enabled).
	 *
	 * @see LOG_Engine.isLoggable
	 */
	@IsTest
	private static void shouldBeLoggableWithDefaultSettings()
	{
		LOG_Engine.logSettingOverride = null;

		Test.startTest();

		Boolean isLoggable = LOG_Engine.isLoggable(LoggingLevel.DEBUG, CLASS_METHOD);

		Test.stopTest();

		Assert.isTrue(isLoggable, MSG_NO_EXCEPTION);
	}

	/**
	 * @description Tests that hydrateContext handles malformed JSON gracefully without throwing.
	 *
	 * @see LOG_Engine.hydrateContext
	 */
	@IsTest
	private static void hydrateContextHandlesMalformedJson()
	{
		// Store original values to verify they remain unchanged
		LOG_Engine.currentCorrelationId = 'original-correlation';

		Test.startTest();

		// This should not throw - malformed JSON is caught and logged
		LOG_Engine.hydrateContext('{ invalid json :::');
		LOG_Engine.hydrateContext(null);
		LOG_Engine.hydrateContext('');

		Test.stopTest();

		// Original correlation should remain unchanged after failed hydration
		Assert.areEqual('original-correlation', LOG_Engine.currentCorrelationId, MSG_NO_EXCEPTION);
	}

	/**
	 * @description Tests that MaxContextDataSize__c is used for context truncation when configured.
	 *
	 * @see LOG_Engine.serializeContextData
	 */
	@IsTest
	private static void serializeContextDataUsesConfiguredMaxSize()
	{
		setupTestData();

		LOG_Engine.logSettingOverride.MaxContextDataSize__c = 50;

		// Set global context that would exceed 50 chars when serialized
		LOG_Engine.globalContextData.put('longKey1', 'This is a long value that should be truncated');
		LOG_Engine.globalContextData.put('longKey2', 'Another long value to ensure we exceed the limit');

		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.DEBUG);

		Test.stopTest();

		// Verify the log was created (the truncation happens internally)
		LogEntry__c retrievedLog = new SEL_LogEntry().findByMethod(CLASS_METHOD);
		Assert.isNotNull(retrievedLog, MSG_NOT_EMPTY);

		if(String.isNotBlank(retrievedLog.ContextData__c))
		{
			Assert.isTrue(retrievedLog.ContextData__c.length() <= 53, 'Context should be truncated to configured max size');
		}
	}

	/**
	 * @description Tests that safePublish handles exceptions without propagating them.
	 * Since we cannot directly simulate EventBus failures, we verify the code path executes.
	 *
	 * @see LOG_Engine.flushBuffer
	 */
	@IsTest
	private static void flushBufferHandlesLargeBuffer()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		// Add logs directly to buffer to test chunked publishing
		for(Integer i = 0; i < 75; i++)
		{
			LOG_Engine.logBuffer.add(new LogEntryEvent__e(
					Message__c = 'Batch message ' + i,
					LogLevel__c = LOG_Engine.LEVEL_DEBUG
			));
		}

		// Flush should handle batching (50 per batch) without errors
		LOG_Engine.flushBuffer();

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.logBuffer.size(), 'Buffer should be empty after flush');
	}

	/**
	 * @description Tests that context serialization handles empty webservice context map.
	 *
	 * @see LOG_Engine.serializeContextData
	 */
	@IsTest
	private static void serializeContextWithEmptyWebserviceContext()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;

		// Ensure webservice context map exists but is empty for default key
		LOG_Engine.webserviceContextsByCorrelation.put('default', new Map<String, String>());

		// Set some global context
		LOG_Engine.globalContextData.put('testKey', 'testValue');

		Test.startTest();

		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.DEBUG);

		Test.stopTest();

		// Verify log was created
		LogEntry__c retrievedLog = new SEL_LogEntry().findByMethod(CLASS_METHOD);
		Assert.isNotNull(retrievedLog, MSG_NOT_EMPTY);

		Assert.isTrue(retrievedLog.ContextData__c.contains('testKey'), 'Global context should be present');
	}

	/**
	 * @description Tests setting webservice context.
	 *
	 * @see LOG_Engine.setWebserviceContext
	 */
	@IsTest
	private static void setWebserviceContext()
	{
		Test.startTest();

		LOG_Engine.setWebserviceContext(null, 'API_TestService', 'https://api.example.com/test', 'POST');

		Test.stopTest();

		// Webservice context is stored under 'default' key when no correlation ID is set
		Map<String, String> webserviceContext = LOG_Engine.webserviceContextsByCorrelation.get('default');
		Assert.isNotNull(webserviceContext, 'Webservice context should exist');
		Assert.areEqual('API_TestService', webserviceContext.get('serviceName'), 'Service name should be set');
		Assert.areEqual('https://api.example.com/test', webserviceContext.get('endpoint'), 'Endpoint should be set');
		Assert.areEqual('POST', webserviceContext.get('httpMethod'), 'HTTP method should be set');
	}

	/**
	 * @description Tests updating webservice context with response details.
	 *
	 * @see LOG_Engine.updateWebserviceContext
	 */
	@IsTest
	private static void updateWebserviceContext()
	{
		LOG_Engine.setWebserviceContext(null, 'API_TestService', 'https://api.example.com/test', 'POST');

		Test.startTest();

		LOG_Engine.updateWebserviceContext(null, '200', 150);

		Test.stopTest();

		// Webservice context is stored under 'default' key when no correlation ID is set
		Map<String, String> webserviceContext = LOG_Engine.webserviceContextsByCorrelation.get('default');
		Assert.isNotNull(webserviceContext, 'Webservice context should exist');
		Assert.areEqual('200', webserviceContext.get('statusCode'), 'Status code should be set');
		Assert.areEqual('150', webserviceContext.get('calloutDurationMs'), 'Duration should be set');
	}

	/**
	 * @description Tests clearing webservice context.
	 *
	 * @see LOG_Engine.clearWebserviceContext
	 */
	@IsTest
	private static void clearWebserviceContext()
	{
		LOG_Engine.setWebserviceContext(null, 'API_TestService', 'https://api.example.com/test', 'POST');
		LOG_Engine.updateWebserviceContext(null, '200', 150);

		Test.startTest();

		LOG_Engine.clearWebserviceContext(null);

		Test.stopTest();

		// Webservice context for 'default' key should be removed
		Assert.isFalse(LOG_Engine.webserviceContextsByCorrelation.containsKey('default'), 'Webservice context should be cleared');
	}

	/**
	 * @description Tests that webservice context is correctly isolated by correlation ID.
	 *
	 * @see LOG_Engine.setWebserviceContext
	 */
	@IsTest
	private static void webserviceContextIsolatedByCorrelation()
	{
		final String correlationId1 = 'handler-correlation-1';
		final String correlationId2 = 'handler-correlation-2';

		Test.startTest();

		LOG_Engine.setWebserviceContext(correlationId1, 'API_Service1', 'https://api1.example.com', 'GET');
		LOG_Engine.setWebserviceContext(correlationId2, 'API_Service2', 'https://api2.example.com', 'POST');
		LOG_Engine.updateWebserviceContext(correlationId1, '200', 100);
		LOG_Engine.updateWebserviceContext(correlationId2, '201', 200);

		Test.stopTest();

		// Verify each correlation has its own isolated context
		Map<String, String> context1 = LOG_Engine.webserviceContextsByCorrelation.get(correlationId1);
		Map<String, String> context2 = LOG_Engine.webserviceContextsByCorrelation.get(correlationId2);

		Assert.isNotNull(context1, 'Context 1 should exist');
		Assert.isNotNull(context2, 'Context 2 should exist');

		Assert.areEqual('API_Service1', context1.get('serviceName'), 'Service 1 name should be isolated');
		Assert.areEqual('API_Service2', context2.get('serviceName'), 'Service 2 name should be isolated');
		Assert.areEqual('200', context1.get('statusCode'), 'Service 1 status should be isolated');
		Assert.areEqual('201', context2.get('statusCode'), 'Service 2 status should be isolated');

		// Clear one context and verify the other remains
		LOG_Engine.clearWebserviceContext(correlationId1);
		Assert.isFalse(LOG_Engine.webserviceContextsByCorrelation.containsKey(correlationId1), 'Context 1 should be cleared');
		Assert.isTrue(LOG_Engine.webserviceContextsByCorrelation.containsKey(correlationId2), 'Context 2 should still exist');
	}

	/**
	 * @description Tests pushing and popping operation context from the stack.
	 *
	 * @see LOG_Engine.pushOperationContext
	 * @see LOG_Engine.popOperationContext
	 */
	@IsTest
	private static void shouldPushAndPopOperationContext()
	{
		// Ensure clean state
		LOG_Engine.clearContextStack();

		Test.startTest();

		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.QUERY, new Map<String, String> {'key1' => 'value1'});
		Assert.areEqual('QUERY', LOG_Engine.getCurrentOperationType(), 'Operation type should be QUERY');
		Assert.areEqual(1, LOG_Engine.getContextStackDepth(), 'Stack depth should be 1');

		LOG_Engine.popOperationContext();
		Assert.isNull(LOG_Engine.getCurrentOperationType(), 'Operation type should be null after pop');
		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Stack depth should be 0 after pop');

		Test.stopTest();
	}

	/**
	 * @description Tests that nested contexts are merged correctly with later contexts overriding earlier ones.
	 *
	 * @see LOG_Engine.getMergedContext
	 */
	@IsTest
	private static void shouldMergeNestedContexts()
	{
		// Ensure clean state
		LOG_Engine.clearContextStack();
		LOG_Engine.clearAllGlobalContext();

		Test.startTest();

		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.API_CALL, new Map<String, String> {'shared' => 'parent', 'parentOnly' => 'p'});
		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.QUERY, new Map<String, String> {'shared' => 'child', 'childOnly' => 'c'});

		Map<String, String> merged = LOG_Engine.getMergedContext();

		Test.stopTest();

		Assert.areEqual('child', merged.get('shared'), 'Child should override parent for shared key');
		Assert.areEqual('p', merged.get('parentOnly'), 'Parent-only value should exist');
		Assert.areEqual('c', merged.get('childOnly'), 'Child-only value should exist');

		LOG_Engine.clearContextStack();
	}

	/**
	 * @description Tests that the context stack respects the maximum depth limit.
	 *
	 * @see LOG_Engine.pushOperationContext
	 */
	@IsTest
	private static void shouldLimitContextStackDepth()
	{
		// Ensure clean state
		LOG_Engine.clearContextStack();

		Test.startTest();

		// Try to push more contexts than the max depth allows
		// Use different enum values to simulate real usage
		List<LOG_Engine.OperationType> types = new List<LOG_Engine.OperationType>
		{
				LOG_Engine.OperationType.API_CALL, LOG_Engine.OperationType.QUERY, LOG_Engine.OperationType.FLOW,
				LOG_Engine.OperationType.LWC, LOG_Engine.OperationType.TRIGGER_ACTION, LOG_Engine.OperationType.API_BATCH
		};
		for(Integer i = 0; i < 15; i++)
		{
			LOG_Engine.pushOperationContext(types[Math.mod(i, types.size())], new Map<String, String> {'index' => String.valueOf(i)});
		}

		Test.stopTest();

		// Should stop at MAX_CONTEXT_DEPTH (10)
		Assert.isTrue(LOG_Engine.contextStack.size() <= 10, 'Stack depth should not exceed maximum');

		LOG_Engine.clearContextStack();
	}

	/**
	 * @description Tests that clearContextStack removes all contexts.
	 *
	 * @see LOG_Engine.clearContextStack
	 */
	@IsTest
	private static void shouldClearContextStack()
	{
		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.API_CALL, new Map<String, String>());
		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.QUERY, new Map<String, String>());

		Test.startTest();

		LOG_Engine.clearContextStack();

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Stack should be empty after clear');
		Assert.isNull(LOG_Engine.getCurrentOperationType(), 'No operation type after clear');
	}

	/**
	 * @description Tests that pop on an empty stack is safe (no exception).
	 *
	 * @see LOG_Engine.popOperationContext
	 */
	@IsTest
	private static void shouldHandlePopOnEmptyStack()
	{
		LOG_Engine.clearContextStack();

		Test.startTest();

		// Should not throw
		LOG_Engine.popOperationContext();
		LOG_Engine.popOperationContext();

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Stack should remain at 0');
	}

	/**
	 * @description Tests that context stack is included in serialized log context data.
	 *
	 * @see LOG_Engine.serializeContextData
	 */
	@IsTest
	private static void shouldIncludeStackContextInLogs()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;

		// Ensure clean state
		LOG_Engine.clearContextStack();
		LOG_Engine.clearAllGlobalContext();

		Test.startTest();

		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.API_CALL, new Map<String, String>
		{
				LOG_Engine.CONTEXT_SERVICE_NAME => 'API_TestService',
				LOG_Engine.CONTEXT_ENDPOINT => 'https://test.example.com'
		});

		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.DEBUG);

		LOG_Engine.popOperationContext();

		Test.stopTest();

		LogEntry__c retrievedLog = new SEL_LogEntry().findByMethod(CLASS_METHOD);
		Assert.isNotNull(retrievedLog, MSG_NOT_EMPTY);

		Assert.isTrue(retrievedLog.ContextData__c.contains('serviceName'), 'Context should include serviceName');
		Assert.isTrue(retrievedLog.ContextData__c.contains('API_TestService'), 'Context should include service value');
		Assert.isTrue(retrievedLog.ContextData__c.contains('_operationType'), 'Context should include operation type');

		LOG_Engine.clearContextStack();
	}

	/**
	 * @description Tests that global context, stack context, and webservice context are all merged in correct order.
	 *
	 * @see LOG_Engine.getMergedContext
	 */
	@IsTest
	private static void shouldMergeAllContextSources()
	{
		// Ensure clean state
		LOG_Engine.clearContextStack();
		LOG_Engine.clearAllGlobalContext();
		LOG_Engine.webserviceContextsByCorrelation.clear();

		Test.startTest();

		// Set global context (base layer)
		LOG_Engine.setGlobalContext('source', 'global');
		LOG_Engine.setGlobalContext('globalOnly', 'g');

		// Push stack context (middle layer)
		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.QUERY, new Map<String, String>
		{
				LOG_Engine.CONTEXT_SOURCE => 'stack',
				'stackOnly' => 's'
		});

		// Set webservice context (top layer)
		LOG_Engine.setWebserviceContext(null, 'API_Test', 'https://test.com', 'POST');

		Map<String, String> merged = LOG_Engine.getMergedContext();

		Test.stopTest();

		// Webservice context should override stack which overrides global
		Assert.areEqual('API_Test', merged.get('serviceName'), 'Webservice context should be present');
		Assert.areEqual('stack', merged.get('source'), 'Stack should override global for shared key');
		Assert.areEqual('g', merged.get('globalOnly'), 'Global-only value should be present');
		Assert.areEqual('s', merged.get('stackOnly'), 'Stack-only value should be present');
	}

	/**
	 * @description Tests that UndeleteResult operations are logged correctly.
	 *
	 * @see LOG_Engine.log
	 */
	@IsTest
	private static void logUndeleteResult()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;

		Foobar__c record = TST_Factory.insertFoobar();
		DML_Builder.newTransaction().doDelete(record).execute();

		Test.startTest();

		// Raw Database.undelete required to obtain Database.UndeleteResult instances for LOG_Engine.log(results, method).
		List<Database.UndeleteResult> results = Database.undelete(new List<Foobar__c> {record}, false);
		Boolean hasErrors = LOG_Engine.log(results, CLASS_METHOD);

		Test.stopTest();

		Assert.isFalse(hasErrors, 'Successful undelete should not produce errors');
	}

	/**
	 * @description Tests pushing context with null context data map.
	 *
	 * @see LOG_Engine.pushOperationContext
	 */
	@IsTest
	private static void shouldHandleNullContextData()
	{
		LOG_Engine.clearContextStack();

		Test.startTest();

		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.LWC, null);

		Test.stopTest();

		Assert.areEqual(1, LOG_Engine.getContextStackDepth(), 'Should push even with null context data');
		Assert.areEqual('LWC', LOG_Engine.getCurrentOperationType(), 'Operation type should be set');

		Map<String, String> merged = LOG_Engine.getMergedContext();
		Assert.areEqual('LWC', merged.get('_operationType'), 'Operation type should be in merged context');
		Assert.areEqual('0', merged.get('_depth'), 'Depth should be 0 for first context');

		LOG_Engine.clearContextStack();
	}

	/**
	 * @description Tests the log overload that accepts a List of String messages.
	 *
	 * @see LOG_Engine.log
	 */
	@IsTest
	private static void shouldLogListOfStringMessages()
	{
		LOG_Builder.ignoreTestMode = true;
		List<String> messages = new List<String> {'Message one', 'Message two'};

		Test.startTest();

		LOG_Engine.log(messages, LOG_Engine_TEST.class.getName() + '/shouldLogListOfStringMessages', LoggingLevel.ERROR);

		Test.stopTest();

		List<LogEntry__c> entries = new SEL_LogEntry().getAll();
		Assert.areEqual(2, entries.size(), 'Should create one log entry per message');
	}

	/**
	 * @description Tests that log handles DeleteResult objects correctly.
	 *
	 * @see LOG_Engine.log
	 */
	@IsTest
	private static void shouldLogDeleteResults()
	{
		LOG_Builder.ignoreTestMode = true;
		Foobar__c record = TST_Factory.insertFoobar();
		// Raw Database.delete required to obtain Database.DeleteResult instances for LOG_Engine.log(List<Object>, method).
		List<Database.DeleteResult> results = Database.delete(new List<SObject> {record}, false);
		List<Object> resultObjects = new List<Object>();
		resultObjects.addAll(results);

		Test.startTest();

		Boolean hasErrors = LOG_Engine.log(resultObjects, LOG_Engine_TEST.class.getName() + '/shouldLogDeleteResults');

		Test.stopTest();

		Assert.isFalse(hasErrors, 'Successful delete should not report errors');
	}

	/**
	 * @description Tests that log handles UpsertResult objects correctly.
	 *
	 * @see LOG_Engine.log
	 */
	@IsTest
	private static void shouldLogUpsertResults()
	{
		LOG_Builder.ignoreTestMode = true;
		Foobar__c record = TST_Factory.newFoobar();
		// Raw Database.upsert required to obtain Database.UpsertResult instances for LOG_Engine.log(List<Object>, method).
		List<Database.UpsertResult> results = Database.upsert(new List<SObject> {record}, false);
		List<Object> resultObjects = new List<Object>();
		resultObjects.addAll(results);

		Test.startTest();

		Boolean hasErrors = LOG_Engine.log(resultObjects, LOG_Engine_TEST.class.getName() + '/shouldLogUpsertResults');

		Test.stopTest();

		Assert.isFalse(hasErrors, 'Successful upsert should not report errors');
	}

	/**
	 * @description Tests that log handles UndeleteResult objects correctly.
	 *
	 * @see LOG_Engine.log
	 */
	@IsTest
	private static void shouldLogUndeleteResults()
	{
		LOG_Builder.ignoreTestMode = true;
		Foobar__c record = TST_Factory.insertFoobar();
		DML_Builder.newTransaction().doDelete(record).execute();
		// Raw Database.undelete required to obtain Database.UndeleteResult instances for LOG_Engine.log(List<Object>, method).
		List<Database.UndeleteResult> results = Database.undelete(new List<SObject> {record}, false);
		List<Object> resultObjects = new List<Object>();
		resultObjects.addAll(results);

		Test.startTest();

		Boolean hasErrors = LOG_Engine.log(resultObjects, LOG_Engine_TEST.class.getName() + '/shouldLogUndeleteResults');

		Test.stopTest();

		Assert.isFalse(hasErrors, 'Successful undelete should not report errors');
	}

	/**
	 * @description Tests that formatDuplicateError produces the expected message format.
	 *
	 * @see LOG_Engine.formatDuplicateError
	 */
	@IsTest
	private static void shouldFormatDuplicateErrorMessage()
	{
		String result = LOG_Engine.formatDuplicateError('Foobar__c', 'TestRule');

		Assert.isTrue(result.contains('duplicate record was detected'), 'Should format as duplicate error message');
		Assert.isTrue(result.contains('Foobar__c'), 'Should contain entity type');
		Assert.isTrue(result.contains('TestRule'), 'Should contain rule name');
	}

	/**
	 * @description Tests that publish failure is handled gracefully without crashing the transaction.
	 *
	 * @see LOG_Engine.safePublish
	 */
	@IsTest
	private static void shouldHandlePublishFailureGracefully()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;
		LOG_Engine.simulatePublishFailure = true;

		Test.startTest();

		TST_Factory.publishLogEvents(1);

		Test.stopTest();

		Assert.isTrue(true, 'Transaction should not crash on publish failure');
	}

	/**
	 * @description Tests that extractClassName handles slash and dot separators.
	 *
	 * @see LOG_Engine.extractClassName
	 */
	@IsTest
	private static void shouldExtractClassName()
	{
		Test.startTest();

		Assert.areEqual('API_SendEmail', LOG_Engine.extractClassName('API_SendEmail/send'), 'Should extract from slash separator');
		Assert.areEqual('API_SendEmail', LOG_Engine.extractClassName('API_SendEmail.send'), 'Should extract from dot separator');
		Assert.areEqual('API_SendEmail', LOG_Engine.extractClassName('API_SendEmail'), 'Should return full string when no separator');
		Assert.isNull(LOG_Engine.extractClassName(null), 'Should return null for null input');
		Assert.areEqual('', LOG_Engine.extractClassName(''), 'Should return empty for empty input');

		Test.stopTest();
	}

	/**
	 * @description Tests that getLogSetting returns code-level defaults when no record configured.
	 *
	 * @see LOG_Engine.getLogSetting
	 */
	@IsTest
	private static void shouldReturnCodeLevelDefaults()
	{
		LOG_Engine.logSettingOverride = null;

		Test.startTest();

		LogSetting__c setting = LOG_Engine.getLogSetting();

		Test.stopTest();

		Assert.isTrue(setting.IsEnabled__c, 'Should default to enabled');
		Assert.areEqual(LOG_Engine.LEVEL_DEBUG, setting.LogLevelThreshold__c, 'Should default to DEBUG threshold');
		Assert.isTrue(setting.EnablePerformanceLogging__c, 'Should default to enabled');
		Assert.isTrue(setting.EnableQueryPerformanceLogging__c, 'Should default to enabled');
		Assert.isTrue(setting.EnableTriggerPerformanceLogging__c, 'Should default to enabled');
		Assert.isTrue(setting.EnableValidationPerformanceLogging__c, 'Should default to enabled');
	}

	/**
	 * @description Tests that getLogSetting resolves an inserted org-level LogSetting__c record
	 * from the hierarchy, confirming the custom setting metadata and getInstance() work end-to-end.
	 *
	 * @see LOG_Engine.getLogSetting
	 */
	@IsTest
	private static void shouldResolveInsertedOrgLevelRecord()
	{
		orgLevelLogSettingBuilder()
				.withOverride(LogSetting__c.EnablePerformanceLogging__c, false)
				.withOverride(LogSetting__c.PerformanceThresholdMs__c, 5000)
				.build();

		LOG_Engine.logSettingOverride = null;

		Test.startTest();

		LogSetting__c resolved = LOG_Engine.getLogSetting();

		Test.stopTest();

		Assert.areEqual(LOG_Engine.LEVEL_WARN, resolved.LogLevelThreshold__c, 'Should resolve org-level threshold');
		Assert.isFalse(resolved.EnablePerformanceLogging__c, 'Should resolve org-level performance toggle');
		Assert.areEqual(5000, resolved.PerformanceThresholdMs__c, 'Should resolve org-level performance threshold');
	}

	/**
	 * @description Tests that the kill switch drops matching-class logs while ERROR still passes.
	 *
	 * @see LOG_Engine.isLoggable
	 */
	@IsTest
	private static void shouldDropMatchingClassWhenKillSwitchActive()
	{
		setupTestData();
		LOG_Engine.logSettingOverride.IsEnabled__c = false;
		LOG_Engine.logSettingOverride.ClassFilter__c = 'API_*';

		Test.startTest();

		Boolean warnResult = LOG_Engine.isLoggable(LoggingLevel.WARN, 'API_SendEmail/send');
		Boolean errorResult = LOG_Engine.isLoggable(LoggingLevel.ERROR, 'API_SendEmail/send');

		Test.stopTest();

		Assert.isFalse(warnResult, 'Kill switch should drop WARN even when class matches filter');
		Assert.isTrue(errorResult, 'ERROR should always pass regardless of kill switch');
	}

	/**
	 * @description Tests that ERROR passes even when the class does not match the filter.
	 *
	 * @see LOG_Engine.isLoggable
	 */
	@IsTest
	private static void shouldEmitErrorRegardlessOfClassFilter()
	{
		setupTestData();
		LOG_Engine.logSettingOverride.ClassFilter__c = 'API_*';

		Test.startTest();

		Boolean result = LOG_Engine.isLoggable(LoggingLevel.ERROR, 'TRG_SetDefaults/beforeInsert');

		Test.stopTest();

		Assert.isTrue(result, 'ERROR should pass even when class does not match filter');
	}

	/**
	 * @description Tests that an invalid LogLevelThreshold value drops all non-ERROR logs.
	 * When the threshold cannot be resolved to a known ordinal, isLoggable returns false
	 * for all levels except ERROR (which always passes).
	 *
	 * @see LOG_Engine.isLoggable
	 */
	@IsTest
	private static void shouldDropNonErrorWhenThresholdInvalid()
	{
		setupTestData();
		LOG_Engine.logSettingOverride.LogLevelThreshold__c = 'INVALID';

		Test.startTest();

		Boolean debugResult = LOG_Engine.isLoggable(LoggingLevel.DEBUG, CLASS_METHOD);
		Boolean warnResult = LOG_Engine.isLoggable(LoggingLevel.WARN, CLASS_METHOD);
		Boolean errorResult = LOG_Engine.isLoggable(LoggingLevel.ERROR, CLASS_METHOD);

		Test.stopTest();

		Assert.isFalse(debugResult, 'Invalid threshold should drop DEBUG');
		Assert.isFalse(warnResult, 'Invalid threshold should drop WARN');
		Assert.isTrue(errorResult, 'ERROR should always pass regardless of invalid threshold');
	}

	/**
	 * @description Tests that ClassFilter handles whitespace-padded and trailing-comma patterns.
	 *
	 * @see LOG_Engine.matchesClassFilter
	 */
	@IsTest
	private static void shouldHandleWhitespaceAndTrailingCommaInFilter()
	{
		Test.startTest();

		Boolean paddedMatch = LOG_Engine.matchesClassFilter('API_SendEmail', ' API_* , SVC_* ');
		Boolean trailingComma = LOG_Engine.matchesClassFilter('API_SendEmail', 'API_*,');
		Boolean leadingComma = LOG_Engine.matchesClassFilter('API_SendEmail', ',API_*');

		Test.stopTest();

		Assert.isTrue(paddedMatch, 'Should match with whitespace-padded patterns');
		Assert.isTrue(trailingComma, 'Should match with trailing comma');
		Assert.isTrue(leadingComma, 'Should match with leading comma');
	}

	/**
	 * @description Tests that a filter pattern with no matching entries returns false.
	 *
	 * @see LOG_Engine.matchesClassFilter
	 */
	@IsTest
	private static void shouldReturnFalseWhenNoPatternMatches()
	{
		Test.startTest();

		Boolean result = LOG_Engine.matchesClassFilter('TRG_SetDefaults', 'API_*,SVC_*,BATCH_*');

		Test.stopTest();

		Assert.isFalse(result, 'Non-matching class should return false');
	}

	/**
	 * @description Tests threshold + class filter combined using real LogSetting__c record.
	 * Inserts an org-level record with WARN threshold and API_* class filter, then verifies
	 * actual log entries are created only for matching class+level combinations.
	 *
	 * @see LOG_Engine.isLoggable
	 * @see LOG_Engine.getLogSetting
	 */
	@IsTest
	private static void shouldFilterByThresholdAndClassWithInsertedRecord()
	{
		orgLevelLogSettingBuilder()
				.withOverride(LogSetting__c.ClassFilter__c, 'API_*')
				.withOverride(LogSetting__c.EnablePerformanceLogging__c, true)
				.withOverride(LogSetting__c.EnableQueryPerformanceLogging__c, true)
				.withOverride(LogSetting__c.EnableTriggerPerformanceLogging__c, true)
				.withOverride(LogSetting__c.EnableValidationPerformanceLogging__c, true)
				.withOverride(LogSetting__c.PerformanceThresholdMs__c, 10000)
				.withOverride(LogSetting__c.QueryPerformanceThresholdMs__c, 1000)
				.withOverride(LogSetting__c.TriggerPerformanceThresholdMs__c, 500)
				.withOverride(LogSetting__c.ValidationPerformanceThresholdMs__c, 100)
				.build();

		LOG_Engine.logSettingOverride = null;
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		LOG_Engine.log(MESSAGE, 'API_SendEmail/send', LoggingLevel.DEBUG);
		LOG_Engine.log(MESSAGE, 'API_SendEmail/send', LoggingLevel.WARN);
		LOG_Engine.log(MESSAGE, 'TRG_SetDefaults/beforeInsert', LoggingLevel.WARN);
		LOG_Engine.log(MESSAGE, 'TRG_SetDefaults/beforeInsert', LoggingLevel.ERROR);

		Test.stopTest();

		List<LogEntry__c> entries = new SEL_LogEntry().getAll();

		Assert.areEqual(2, entries.size(), 'Only WARN+API and ERROR+TRG should pass');
	}

	/**
	 * @description Tests end-to-end correlation: multiple LOG_Builder.emit() calls in the same
	 * transaction produce LogEntry__c records that share the same CorrelationId__c and TransactionId__c.
	 * Verifies the full pipeline: LOG_Builder → LOG_Engine → EventBus → TRG_PersistLogEntry → LogEntry__c.
	 *
	 * @see LOG_Engine.startCorrelation
	 * @see LOG_Engine.publishEvents
	 * @see TRG_PersistLogEntry
	 */
	@IsTest
	private static void shouldCorrelateLogsAcrossMultipleEmits()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;
		LOG_Engine.currentCorrelationId = null;

		String correlationId = LOG_Engine.startCorrelation();

		String controllerMethod = 'CTRL_Account/saveAccount';
		String triggerMethod = 'TRG_SetDefaults/beforeInsert';
		String apiMethod = 'API_Notify/process';

		Test.startTest();

		LOG_Engine.log(MESSAGE, controllerMethod, LoggingLevel.INFO);
		LOG_Engine.log(MESSAGE, triggerMethod, LoggingLevel.DEBUG);
		LOG_Engine.log(MESSAGE, apiMethod, LoggingLevel.INFO);

		Test.stopTest();

		List<LogEntry__c> logs = QRY_Builder.selectFrom(LogEntry__c.SObjectType)
				.fields(new List<SObjectField> {LogEntry__c.ClassMethod__c, LogEntry__c.CorrelationId__c, LogEntry__c.TransactionId__c})
				.condition(LogEntry__c.CorrelationId__c).equals(correlationId)
				.condition(LogEntry__c.ClassMethod__c).isIn(new Set<Object> {controllerMethod, triggerMethod, apiMethod})
				.orderBy(LogEntry__c.ClassMethod__c).ascending()
				.withSystemMode()
				.toList();

		Assert.areEqual(3, logs.size(), 'Three correlated log entries should exist');

		String sharedTransactionId = logs[0].TransactionId__c;
		Set<String> classMethodValues = new Set<String>();

		for(LogEntry__c log : logs)
		{
			Assert.areEqual(correlationId, log.CorrelationId__c, 'All entries should share the correlation ID');
			Assert.areEqual(sharedTransactionId, log.TransactionId__c, 'All entries should share the same transaction ID');
			classMethodValues.add(log.ClassMethod__c);
		}

		Assert.isTrue(classMethodValues.contains(controllerMethod), 'Controller log should be present');
		Assert.isTrue(classMethodValues.contains(triggerMethod), 'Trigger log should be present');
		Assert.isTrue(classMethodValues.contains(apiMethod), 'API log should be present');
	}

	/**
	 * @description Tier-A pilot — proves LOG_Builder / LOG_Engine reaches
	 * persistence from a subscriber user on the Minimum Access - Salesforce profile who has no
	 * FLS on kern__LogEntry__c. emitAt must not throw, publishEvents must not swallow an
	 * EventBus.publish DmlException for the no-FLS caller, and the platform-event consumer must
	 * complete so the LogEntry__c row lands.
	 *
	 * Note on scope — the actual insert runs inside TRG_PersistLogEntry as the Automated Process
	 * user, not as the triggering user, so this test does NOT prove FLS-elevation-on-INSERT is
	 * correctly applied by the framework. The stronger FLS-elevation claim is covered by T8
	 * (`SEL_LogEntry` query under runAs(lowPrivilegeUser) exercising systemModeRequired = true).
	 * What T1 catches is end-to-end reachability: a future refactor that demotes
	 * TRG_PersistLogEntry to user-mode DML, or drops a `withSystemMode()` on the insert, or
	 * lets emit's upstream validation throw for a no-FLS caller, fails this test at 2GP
	 * validated-build time rather than at subscriber scratch-org time.
	 *
	 * @see LOG_Builder
	 * @see LOG_Engine
	 * @see TRG_LogEntryEvent
	 */
	@IsTest
	private static void shouldEmitLogEntryForLowPrivilegeUser()
	{
		System.runAs(getLowPrivilegeUser())
		{
			setupTestData();
			LOG_Engine.ignoreTestMode = true;

			Test.startTest();

			LOG_Builder.build().info(TIER_A_MESSAGE).emitAt(TIER_A_CLASS_METHOD);

			Test.stopTest();
		}

		System.runAs(getTestAdmin())
		{
			LogEntry__c entry = new SEL_LogEntry().findByMethod(TIER_A_CLASS_METHOD);

			Assert.isNotNull(entry, 'LogEntry__c should land for low-privilege emit');
			Assert.areEqual(LOG_Engine.LEVEL_INFO, entry.LogLevel__c, 'LogEntry__c should carry INFO level');
			Assert.areEqual(TIER_A_MESSAGE, entry.Message__c, 'LogEntry__c should carry the emitted message');
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup. Used by the
	 * tier-A test to assert outcomes under full FLS after the low-privilege emit completes.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the tier-A test to exercise LOG_Builder and prove the
	 * subscribers-without-internal-FLS contract holds for the logging primitive.
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}
}