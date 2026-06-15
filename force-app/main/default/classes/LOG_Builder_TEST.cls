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
 * @description Tests the LOG_Builder class for fluent builder API, buffering, scoping, and context features.
 *
 * @see LOG_Builder
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date February 2026, June 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.UnusedLocalVariable,ApexUnusedDeclaration,PMD.CyclomaticComplexity')
@IsTest(SeeAllData=false IsParallel=true)
private class LOG_Builder_TEST
{
	private static final Id RECORD_ID = UTIL_Random.randomId(Foobar__c.SObjectType);
	private static final String CLASS_METHOD = 'foo/method';
	private static final String ERROR_DML_EXCEPTION = 'DML exception was not logged as expected';
	private static final String ERROR_INCORRECT_LOG_COUNT = 'Incorrect number of logs written';
	private static final String ERROR_INCORRECT_MESSAGE = 'Message__c does not match the logged message';
	private static final String ERROR_INVALID_EXCEPTION_TYPE = 'ExceptionType__c does not match MathException';
	private static final String ERROR_INVALID_LOG_LEVEL = 'LogLevel__c does not match expected level';
	private static final String ERROR_INVALID_RECORD_ID = 'RecordId__c does not match the provided record ID';
	private static final String ERROR_INVALID_SHORT_MESSAGE = 'ShortMessage__c does not match the short message';
	private static final String ERROR_INVALID_USER_ID = 'UserId__c does not match the current user ID';
	private static final String ERROR_NO_LOG_FOUND = 'No Log Entry found';
	private static final String LEVEL_DEBUG = LOG_Engine.LEVEL_DEBUG;
	private static final String LEVEL_ERROR = LOG_Engine.LEVEL_ERROR;
	private static final String LEVEL_INFO = LOG_Engine.LEVEL_INFO;
	private static final String LEVEL_WARN = LOG_Engine.LEVEL_WARN;

	/**
	 * @description Tests logging a debug message with a long message.
	 *
	 * @see LOG_Builder.LogEntry.debug
	 */
	@IsTest
	private static void debugWritesCorrectLongMessage()
	{
		String logMessage = UTIL_Random.randomName();
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.build().debug(logMessage).at(CLASS_METHOD).emit();

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.areEqual(logMessage, logEntry.Message__c, ERROR_INCORRECT_MESSAGE);
		Assert.areEqual(LEVEL_DEBUG, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(UserInfo.getUserId(), logEntry.UserId__c, ERROR_INVALID_USER_ID);
	}

	/**
	 * @description Tests logging multiple debug messages.
	 *
	 * @see LOG_Builder.LogEntry.debug
	 */
	@IsTest
	private static void debugMultipleWritesCorrectValues()
	{
		List<String> logMessages = new List<String> {UTIL_Random.randomName(), UTIL_Random.randomName()};
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.build().debug(logMessages).at(CLASS_METHOD).emit();

		Test.stopTest();

		List<LogEntry__c> logEntries = new SEL_LogEntry().findAllByMethod(CLASS_METHOD);

		Assert.areEqual(logMessages.size(), logEntries.size(), ERROR_INCORRECT_LOG_COUNT);
		Assert.areEqual(LEVEL_DEBUG, logEntries[0].LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(UserInfo.getUserId(), logEntries[0].UserId__c, ERROR_INVALID_USER_ID);
	}

	/**
	 * @description Tests logging a debug message with a short and long message.
	 *
	 * @see LOG_Builder.LogEntry.debug
	 * @see LOG_Builder.LogEntry.withSummary
	 */
	@IsTest
	private static void debugWritesCorrectShortMessage()
	{
		String briefMessage = UTIL_Random.randomName();
		String longMessage = UTIL_Random.randomName();
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.build().debug(longMessage).withSummary(briefMessage).at(CLASS_METHOD).emit();

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.areEqual(LEVEL_DEBUG, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(longMessage, logEntry.Message__c, ERROR_INCORRECT_MESSAGE);
		Assert.areEqual(briefMessage, logEntry.ShortMessage__c, ERROR_INVALID_SHORT_MESSAGE);
		Assert.areEqual(UserInfo.getUserId(), logEntry.UserId__c, ERROR_INVALID_USER_ID);
	}

	/**
	 * @description Tests logging a debug message with a record ID.
	 *
	 * @see LOG_Builder.LogEntry.debug
	 * @see LOG_Builder.LogEntry.forRecord
	 */
	@IsTest
	private static void debugWithIdWritesCorrectValues()
	{
		String logMessage = UTIL_Random.randomName();
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.build().debug(logMessage).at(CLASS_METHOD).forRecord(RECORD_ID).emit();

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.areEqual(logMessage, logEntry.Message__c, ERROR_INCORRECT_MESSAGE);
		Assert.areEqual(LEVEL_DEBUG, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(RECORD_ID, logEntry.RecordId__c, ERROR_INVALID_RECORD_ID);
		Assert.areEqual(UserInfo.getUserId(), logEntry.UserId__c, ERROR_INVALID_USER_ID);
	}

	/**
	 * @description Tests logging a DML operation failure.
	 *
	 * @see LOG_Builder.errorDMLOperationResults
	 */
	@IsTest
	private static void errorDMLOperationResults()
	{
		Foobar__c newFoobar = TST_Factory.newFoobar();
		newFoobar.Email__c = UTIL_Random.randomName();
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		// Raw Database.insert required to obtain Database.SaveResult for LOG_Builder.errorDMLOperationResults().
		Database.SaveResult saveResult = Database.insert(newFoobar, false);
		LOG_Builder.errorDMLOperationResults(new List<Database.SaveResult> {saveResult}, CLASS_METHOD);

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(CLASS_METHOD);
		Assert.isNotNull(logEntry, ERROR_DML_EXCEPTION);
		Assert.areEqual(LEVEL_ERROR, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
	}

	/**
	 * @description Tests logging an error message.
	 *
	 * @see LOG_Builder.LogEntry.error
	 */
	@IsTest
	private static void errorWritesCorrectValues()
	{
		String logMessage = UTIL_Random.randomName();
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.build().error(logMessage).at(CLASS_METHOD).emit();

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.areEqual(logMessage, logEntry.Message__c, ERROR_INCORRECT_MESSAGE);
		Assert.areEqual(LEVEL_ERROR, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(UserInfo.getUserId(), logEntry.UserId__c, ERROR_INVALID_USER_ID);
	}

	/**
	 * @description Tests logging an exception.
	 *
	 * @see LOG_Builder.LogEntry.error
	 */
	@IsTest
	private static void errorWritesCorrectValuesForException()
	{
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		try
		{
			Double invalidNumber = 1 / 0; // Force MathException
		}
		catch(Exception error)
		{
			LOG_Builder.build().error(error).at(CLASS_METHOD).emit();
		}

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.areEqual(System.MathException.class.getName(), logEntry.ExceptionType__c, ERROR_INVALID_EXCEPTION_TYPE);
		Assert.areEqual(LEVEL_ERROR, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(UserInfo.getUserId(), logEntry.UserId__c, ERROR_INVALID_USER_ID);
	}

	/**
	 * @description Tests logging an exception with a record ID.
	 *
	 * @see LOG_Builder.LogEntry.error
	 * @see LOG_Builder.LogEntry.forRecord
	 */
	@IsTest
	private static void errorWithIdWritesCorrectValuesForException()
	{
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		try
		{
			Double invalidNumber = 1 / 0; // Force MathException
		}
		catch(Exception error)
		{
			LOG_Builder.build().error(error).at(CLASS_METHOD).forRecord(RECORD_ID).emit();
		}

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.areEqual(LEVEL_ERROR, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(RECORD_ID, logEntry.RecordId__c, ERROR_INVALID_RECORD_ID);
		Assert.areEqual(UserInfo.getUserId(), logEntry.UserId__c, ERROR_INVALID_USER_ID);
		Assert.areEqual(System.MathException.class.getName(), logEntry.ExceptionType__c, ERROR_INVALID_EXCEPTION_TYPE);
	}

	/**
	 * @description Tests logging multiple error messages.
	 *
	 * @see LOG_Builder.LogEntry.error
	 */
	@IsTest
	private static void errorMultipleWritesCorrectValues()
	{
		List<String> logMessages = new List<String> {UTIL_Random.randomName(), UTIL_Random.randomName()};
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.build().error(logMessages).at(CLASS_METHOD).emit();

		Test.stopTest();

		List<LogEntry__c> logEntries = new SEL_LogEntry().findByLogLevel(LEVEL_ERROR);

		Assert.areEqual(logMessages.size(), logEntries.size(), ERROR_INCORRECT_LOG_COUNT);
		Assert.areEqual(UserInfo.getUserId(), logEntries.iterator().next().UserId__c, ERROR_INVALID_USER_ID);
	}

	/**
	 * @description Tests logging an info message.
	 *
	 * @see LOG_Builder.LogEntry.info
	 */
	@IsTest
	private static void infoWritesCorrectValues()
	{
		String logMessage = UTIL_Random.randomName();
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.build().info(logMessage).at(CLASS_METHOD).emit();

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.areEqual(logMessage, logEntry.Message__c, ERROR_INCORRECT_MESSAGE);
		Assert.areEqual(LEVEL_INFO, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(UserInfo.getUserId(), logEntry.UserId__c, ERROR_INVALID_USER_ID);
	}

	/**
	 * @description Tests logging multiple info messages.
	 *
	 * @see LOG_Builder.LogEntry.info
	 */
	@IsTest
	private static void infoMultipleWritesCorrectValues()
	{
		List<String> logMessages = new List<String> {UTIL_Random.randomName(), UTIL_Random.randomName()};
		//To cover the get of the property which isn't accessed anywhere else
		LOG_Builder.ignoreTestMode = LOG_Builder.ignoreTestMode == false ? true : LOG_Builder.ignoreTestMode;

		Test.startTest();

		LOG_Builder.build().info(logMessages).at(CLASS_METHOD).emit();

		Test.stopTest();

		List<LogEntry__c> logEntries = new SEL_LogEntry().findAllByMethod(CLASS_METHOD);

		Assert.areEqual(logMessages.size(), logEntries.size(), ERROR_INCORRECT_LOG_COUNT);
		Assert.areEqual(LEVEL_INFO, logEntries[0].LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(UserInfo.getUserId(), logEntries[0].UserId__c, ERROR_INVALID_USER_ID);
	}

	/**
	 * @description Tests logging a warning message.
	 *
	 * @see LOG_Builder.LogEntry.warn
	 */
	@IsTest
	private static void warnWritesCorrectValues()
	{
		String logMessage = UTIL_Random.randomName();
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.build().warn(logMessage).at(CLASS_METHOD).emit();

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.areEqual(logMessage, logEntry.Message__c, ERROR_INCORRECT_MESSAGE);
		Assert.areEqual(LEVEL_WARN, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(UserInfo.getUserId(), logEntry.UserId__c, ERROR_INVALID_USER_ID);
	}

	/**
	 * @description Tests logging multiple warning messages.
	 *
	 * @see LOG_Builder.LogEntry.warn
	 */
	@IsTest
	private static void warnMultipleWritesCorrectValues()
	{
		List<String> logMessages = new List<String> {UTIL_Random.randomName(), UTIL_Random.randomName()};
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.build().warn(logMessages).at(CLASS_METHOD).emit();

		Test.stopTest();

		List<LogEntry__c> logEntries = new SEL_LogEntry().findAllByMethod(CLASS_METHOD);

		Assert.areEqual(logMessages.size(), logEntries.size(), ERROR_INCORRECT_LOG_COUNT);
		Assert.areEqual(LEVEL_WARN, logEntries[0].LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(UserInfo.getUserId(), logEntries[0].UserId__c, ERROR_INVALID_USER_ID);
	}

	/**
	 * @description Tests logging a warning message with a record ID.
	 *
	 * @see LOG_Builder.LogEntry.warn
	 * @see LOG_Builder.LogEntry.forRecord
	 */
	@IsTest
	private static void warnWithIdWritesCorrectValues()
	{
		String logMessage = UTIL_Random.randomName();
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.build().warn(logMessage).at(CLASS_METHOD).forRecord(RECORD_ID).emit();

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.isNotNull(logEntry, ERROR_NO_LOG_FOUND);
		Assert.areEqual(LEVEL_WARN, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(logMessage, logEntry.Message__c, ERROR_INCORRECT_MESSAGE);
		Assert.areEqual(RECORD_ID, logEntry.RecordId__c, ERROR_INVALID_RECORD_ID);
		Assert.areEqual(UserInfo.getUserId(), logEntry.UserId__c, ERROR_INVALID_USER_ID);
	}

	/**
	 * @description Tests that startCorrelation generates a unique correlation ID.
	 *
	 * @see LOG_Builder.startCorrelation
	 */
	@IsTest
	private static void startCorrelationGeneratesUniqueId()
	{
		Test.startTest();

		String correlationId1 = LOG_Builder.startCorrelation();
		String correlationId2 = LOG_Builder.startCorrelation();

		Test.stopTest();

		Assert.isNotNull(correlationId1, 'First correlation ID should not be null');
		Assert.isNotNull(correlationId2, 'Second correlation ID should not be null');
		Assert.areNotEqual(correlationId1, correlationId2, 'Correlation IDs should be unique');
	}

	/**
	 * @description Tests setting and getting correlation ID.
	 *
	 * @see LOG_Builder.setCorrelationId
	 * @see LOG_Builder.correlationId
	 */
	@IsTest
	private static void setAndGetCorrelationId()
	{
		String expectedCorrelationId = 'test-correlation-123';

		Test.startTest();

		LOG_Builder.setCorrelationId(expectedCorrelationId);
		String actualCorrelationId = LOG_Builder.correlationId;

		Test.stopTest();

		Assert.areEqual(expectedCorrelationId, actualCorrelationId, 'Correlation ID should match');
	}

	/**
	 * @description Tests setting parent transaction ID.
	 *
	 * @see LOG_Builder.setParentTransactionId
	 */
	@IsTest
	private static void setParentTransactionId()
	{
		String parentTransactionId = 'parent-txn-456';

		Test.startTest();

		LOG_Builder.setParentTransactionId(parentTransactionId);

		Test.stopTest();

		Assert.areEqual(parentTransactionId, LOG_Engine.currentParentTransactionId, 'Parent transaction ID should be set');
	}

	/**
	 * @description Tests serializing and hydrating context for async jobs.
	 *
	 * @see LOG_Builder.serializeContext
	 * @see LOG_Builder.hydrateContext
	 */
	@IsTest
	private static void serializeAndHydrateContext()
	{
		String correlationId = 'async-correlation-789';
		LOG_Builder.setCorrelationId(correlationId);
		LOG_Builder.setGlobalContext('testKey', 'testValue');

		Test.startTest();

		String serialized = LOG_Builder.serializeContext();

		// Clear state to simulate new transaction
		LOG_Engine.currentCorrelationId = null;
		LOG_Engine.globalContextData.clear();

		LOG_Builder.hydrateContext(serialized);

		Test.stopTest();

		Assert.areEqual(correlationId, LOG_Builder.correlationId, 'Correlation ID should be restored');
		Assert.isTrue(LOG_Engine.globalContextData.containsKey('testKey'), 'Global context should be restored');
	}

	/**
	 * @description Tests that serializeContext excludes contextData field when no context is set.
	 * This prevents wasteful empty objects in the serialized JSON.
	 *
	 * @see LOG_Builder.serializeContext
	 */
	@IsTest
	private static void serializeContextExcludesEmptyContextData()
	{
		LOG_Builder.setCorrelationId(null);
		LOG_Engine.globalContextData.clear();

		String correlationId = LOG_Builder.startCorrelation();

		Test.startTest();

		String serialized = LOG_Builder.serializeContext();

		Test.stopTest();

		Assert.isTrue(serialized.contains('correlationId'), 'Should contain correlationId');
		Assert.isTrue(serialized.contains('parentTransactionId'), 'Should contain parentTransactionId');
		Assert.isFalse(serialized.contains('contextData'), 'Should NOT contain contextData when empty');
	}

	/**
	 * @description Tests that hydrateContext handles null/blank input gracefully.
	 *
	 * @see LOG_Builder.hydrateContext
	 */
	@IsTest
	private static void hydrateContextHandlesBlankInput()
	{
		Test.startTest();

		LOG_Builder.hydrateContext(null);
		LOG_Builder.hydrateContext('');
		LOG_Builder.hydrateContext('   ');

		Test.stopTest();

		Assert.isNull(LOG_Builder.correlationId, 'Correlation ID should remain null');
	}

	/**
	 * @description Tests that hydrateContext handles invalid JSON gracefully.
	 *
	 * @see LOG_Builder.hydrateContext
	 */
	@IsTest
	private static void hydrateContextHandlesInvalidJson()
	{
		Test.startTest();

		LOG_Builder.hydrateContext('not valid json {{{');

		Test.stopTest();

		Assert.isNull(LOG_Builder.correlationId, 'Correlation ID should remain null after invalid JSON');
	}

	/**
	 * @description Tests setting and clearing global context.
	 *
	 * @see LOG_Builder.setGlobalContext
	 * @see LOG_Builder.clearGlobalContext
	 */
	@IsTest
	private static void setAndClearGlobalContext()
	{
		Test.startTest();

		LOG_Builder.setGlobalContext('orderId', 'ORD-123');
		Assert.isTrue(LOG_Engine.globalContextData.containsKey('orderId'), 'Context should contain orderId');

		LOG_Builder.clearGlobalContext('orderId');

		Test.stopTest();

		Assert.isFalse(LOG_Engine.globalContextData.containsKey('orderId'), 'Context should not contain orderId after clear');
	}

	/**
	 * @description Tests clearing all global context.
	 *
	 * @see LOG_Builder.clearAllGlobalContext
	 */
	@IsTest
	private static void clearAllGlobalContext()
	{
		LOG_Builder.setGlobalContext('key1', 'value1');
		LOG_Builder.setGlobalContext('key2', 'value2');

		Test.startTest();

		LOG_Builder.clearAllGlobalContext();

		Test.stopTest();

		Assert.isTrue(LOG_Engine.globalContextData.isEmpty(), 'All global context should be cleared');
	}

	/**
	 * @description Tests that complex objects are serialized as JSON in context.
	 *
	 * @see LOG_Builder.setGlobalContext
	 */
	@IsTest
	private static void setGlobalContextSerializesComplexObjects()
	{
		Map<String, String> complexObject = new Map<String, String> {'nested' => 'value'};

		Test.startTest();

		LOG_Builder.setGlobalContext('complexKey', complexObject);

		Test.stopTest();

		String storedValue = LOG_Engine.globalContextData.get('complexKey');
		Assert.isTrue(storedValue.contains('nested'), 'Complex object should be JSON serialized');
	}

	/**
	 * @description Tests that logs are buffered when saving is suspended.
	 *
	 * @see LOG_Builder.suspendSaving
	 * @see LOG_Engine.getBufferSize
	 */
	@IsTest
	private static void suspendSavingBuffersLogs()
	{
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.suspendSaving();
		LOG_Builder.build().debug('Buffered message 1').at(CLASS_METHOD).emit();
		LOG_Builder.build().debug('Buffered message 2').at(CLASS_METHOD).emit();

		Integer bufferSize = LOG_Engine.getBufferSize();

		LOG_Builder.resumeSaving();

		Test.stopTest();

		Assert.areEqual(2, bufferSize, 'Buffer should contain 2 logs');
		Assert.areEqual(0, LOG_Engine.getBufferSize(), 'Buffer should be empty after resume');
	}

	/**
	 * @description Tests that ERROR logs bypass buffering.
	 *
	 * @see LOG_Builder.suspendSaving
	 */
	@IsTest
	private static void errorLogsBypassBuffer()
	{
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.suspendSaving();
		LOG_Builder.build().debug('Buffered debug').at(CLASS_METHOD).emit();
		LOG_Builder.build().error('Error bypasses buffer').at(CLASS_METHOD).emit();

		// After error, buffer should be flushed
		Integer bufferSizeAfterError = LOG_Engine.getBufferSize();

		LOG_Builder.resumeSaving();

		Test.stopTest();

		Assert.areEqual(0, bufferSizeAfterError, 'Buffer should be flushed after ERROR log');
	}

	/**
	 * @description Tests manual buffer flush.
	 *
	 * @see LOG_Builder.flushBuffer
	 */
	@IsTest
	private static void manualFlushBuffer()
	{
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.suspendSaving();
		LOG_Builder.build().debug('Buffered message').at(CLASS_METHOD).emit();

		Assert.areEqual(1, LOG_Engine.getBufferSize(), 'Buffer should contain 1 log');

		LOG_Builder.flushBuffer();

		Assert.areEqual(0, LOG_Engine.getBufferSize(), 'Buffer should be empty after flush');

		LOG_Builder.resumeSaving();

		Test.stopTest();
	}

	/**
	 * @description Tests that PerformanceTimer measures elapsed time.
	 *
	 * @see UTIL_PerformanceTimer
	 * @see UTIL_PerformanceTimer.stopSilent
	 */
	@IsTest
	@SuppressWarnings('PMD.EmptyWhileStmt,PMD.EmptyStatementBlock')
	private static void performanceTimerMeasuresElapsedTime()
	{
		Test.startTest();

		UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer('Test Operation', CLASS_METHOD);
		timer.start();

		// Simulate some work
		Long startMs = System.currentTimeMillis();
		while(System.currentTimeMillis() - startMs < 5)
		{
			// Wait ~5ms
		}

		Long elapsedMs = timer.stopSilent();

		Test.stopTest();

		Assert.isTrue(elapsedMs >= 5, 'Elapsed time should be at least 5ms, was: ' + elapsedMs);
	}

	/**
	 * @description Tests that stopSilent does not create a log entry.
	 *
	 * @see UTIL_PerformanceTimer.stopSilent
	 */
	@IsTest
	private static void stopSilentDoesNotLog()
	{
		LOG_Builder.ignoreTestMode = true;
		String uniqueMethod = 'PerformanceTimer/stopSilentTest_' + System.currentTimeMillis();

		Test.startTest();

		UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer('Silent Operation', uniqueMethod);
		timer.start();
		timer.stopSilent();

		Test.stopTest();

		List<LogEntry__c> logs = new SEL_LogEntry().findAllByMethod(uniqueMethod);
		Assert.isTrue(logs.isEmpty(), 'stopSilent should not create log entries');
	}

	/**
	 * @description Tests that stop creates a performance log entry when performance logging is enabled.
	 *
	 * @see UTIL_PerformanceTimer.stop
	 */
	@IsTest
	private static void stopCreatesPerformanceLog()
	{
		LOG_Builder.ignoreTestMode = true;
		String uniqueMethod = 'PerformanceTimer/stopTest_' + System.currentTimeMillis();

		// Set up filter with performance logging enabled (0ms threshold = log all)
		TST_Factory.setupLoggerForTest(true, 0);

		Test.startTest();

		UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer('Logged Operation', uniqueMethod);
		timer.start();
		timer.stop();

		Test.stopTest();

		List<LogEntry__c> logs = new SEL_LogEntry().findAllByMethod(uniqueMethod);
		Assert.isFalse(logs.isEmpty(), 'stop should create a performance log entry');
		Assert.isTrue(logs[0].ShortMessage__c.contains('completed in'), 'ShortMessage should contain performance summary');
	}

	/**
	 * @description Tests that performance logs respect threshold settings.
	 *
	 * @see UTIL_PerformanceTimer.stop
	 */
	@IsTest
	private static void performanceTimerRespectsThreshold()
	{
		LOG_Builder.ignoreTestMode = true;
		String uniqueMethod = 'PerformanceTimer/thresholdTest_' + System.currentTimeMillis();

		// Set up filter with high threshold (10 seconds - operation won't exceed this)
		TST_Factory.setupLoggerForTest(true, 10000);

		Test.startTest();

		UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer('Fast Operation', uniqueMethod);
		timer.start();
		timer.stop();

		Test.stopTest();

		List<LogEntry__c> logs = new SEL_LogEntry().findAllByMethod(uniqueMethod);
		Assert.isTrue(logs.isEmpty(), 'Operations below threshold should not be logged');
	}

	/**
	 * @description Tests that performance logging can be disabled.
	 *
	 * @see UTIL_PerformanceTimer.stop
	 */
	@IsTest
	private static void performanceLoggingCanBeDisabled()
	{
		LOG_Builder.ignoreTestMode = true;
		String uniqueMethod = 'PerformanceTimer/disabledTest_' + System.currentTimeMillis();

		// Set up filter with performance logging disabled
		TST_Factory.setupLoggerForTest(false, 0);

		Test.startTest();

		UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer('Disabled Operation', uniqueMethod);
		timer.start();
		Long elapsedMs = timer.stopSilent();

		Test.stopTest();

		List<LogEntry__c> logs = new SEL_LogEntry().findAllByMethod(uniqueMethod);
		Assert.isTrue(logs.isEmpty(), 'Disabled performance logging should not create logs');
		Assert.isTrue(elapsedMs >= 0, 'Should still return elapsed time even when disabled');
	}

	/**
	 * @description Tests that non-serializable objects fall back to String.valueOf().
	 * Some objects cannot be serialized via JSON.serialize() and should gracefully
	 * fall back to using String.valueOf() instead of crashing.
	 *
	 * @see LOG_Builder.setGlobalContext
	 */
	@IsTest
	private static void setGlobalContextFallsBackForNonSerializableObjects()
	{
		Test.startTest();

		// HttpRequest cannot be JSON serialized - it will throw an exception
		// The catch block should fall back to String.valueOf()
		HttpRequest nonSerializableObject = new HttpRequest();
		nonSerializableObject.setEndpoint('https://test.example.com');
		LOG_Builder.setGlobalContext('httpRequest', nonSerializableObject);

		Test.stopTest();

		// Verify the context was set using the fallback (String.valueOf)
		Assert.isTrue(LOG_Engine.globalContextData.containsKey('httpRequest'), 'Context should contain httpRequest key');
		Assert.isNotNull(LOG_Engine.globalContextData.get('httpRequest'), 'Context value should not be null');
	}

	/**
	 * @description Tests that the buffer auto-flushes when MAX_BUFFER_SIZE is exceeded.
	 * This prevents memory issues from unbounded buffer growth.
	 *
	 * @see LOG_Builder.suspendSaving
	 * @see LOG_Engine.MAX_BUFFER_SIZE
	 */
	@IsTest
	private static void bufferAutoFlushesWhenMaxSizeExceeded()
	{
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.suspendSaving();

		// Add logs up to MAX_BUFFER_SIZE (500) - should trigger auto-flush
		for(Integer i = 0; i < 501; i++)
		{
			LOG_Engine.logBuffer.add(new LogEntryEvent__e(Message__c = 'Test message ' + i));
		}

		// Manually trigger the check by adding one more log through the normal path
		// which will check the buffer size
		LOG_Builder.build().debug('Trigger buffer check').at(CLASS_METHOD).emit();

		// Buffer should have been flushed (size reset)
		Integer bufferSizeAfterFlush = LOG_Engine.getBufferSize();

		LOG_Builder.resumeSaving();

		Test.stopTest();

		// After auto-flush, buffer should be small (just the new log we added)
		Assert.isTrue(bufferSizeAfterFlush <= 2, 'Buffer should have been auto-flushed when exceeding MAX_BUFFER_SIZE');
	}

	/**
	 * @description Tests that publish failures are caught and don't crash the application.
	 * The logger should never cause a business transaction to fail.
	 *
	 * @see LOG_Engine.safePublish
	 * @see LOG_Builder.flushBuffer
	 */
	@IsTest
	private static void publishFailureDoesNotCrashApplication()
	{
		LOG_Builder.ignoreTestMode = true;
		LOG_Engine.simulatePublishFailure = true;

		Test.startTest();

		// Suspend saving so we can control when flush happens
		LOG_Builder.suspendSaving();
		LOG_Builder.build().debug('Test message for flush').at(CLASS_METHOD).emit();

		// Flush should catch the simulated exception and not throw
		Exception caughtException;
		try
		{
			LOG_Builder.flushBuffer();
		}
		catch(Exception error)
		{
			caughtException = error;
		}

		LOG_Builder.resumeSaving();
		LOG_Engine.simulatePublishFailure = false;

		Test.stopTest();

		Assert.isNull(caughtException, 'Publish failure should be caught and not propagate');
		Assert.areEqual(0, LOG_Engine.getBufferSize(), 'Buffer should be cleared even on failure');
	}

	/**
	 * @description Tests that direct publish failures in simulatePublishFailure() are caught.
	 * This covers the catch block in the immediate publish path.
	 *
	 * @see LOG_Engine.simulatePublishFailure
	 */
	@IsTest
	private static void directPublishFailureDoesNotCrashApplication()
	{
		LOG_Builder.ignoreTestMode = true;
		LOG_Engine.simulatePublishFailure = true;

		Test.startTest();

		// Direct logging (not suspended) should also catch publish failures
		Exception caughtException;
		try
		{
			LOG_Builder.build().debug('Test direct publish failure').at(CLASS_METHOD).emit();
		}
		catch(Exception error)
		{
			caughtException = error;
		}

		LOG_Engine.simulatePublishFailure = false;

		Test.stopTest();

		Assert.isNull(caughtException, 'Direct publish failure should be caught and not propagate');
	}

	/**
	 * @description Tests that the fluent builder emits an error log with exception and record context.
	 *
	 * @see LOG_Builder.build
	 * @see LOG_Builder.LogEntry.emit
	 */
	@IsTest
	private static void builderEmitsErrorWithExceptionAndRecord()
	{
		LOG_Builder.ignoreTestMode = true;
		String builderMethod = 'BuilderTest/errorWithRecord_' + System.currentTimeMillis();

		Test.startTest();

		try
		{
			Double invalidNumber = 1 / 0;
		}
		catch(Exception error)
		{
			LOG_Builder.build()
					.error(error)
					.at(builderMethod)
					.forRecord(RECORD_ID)
					.emit();
		}

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(builderMethod);

		Assert.areEqual(LEVEL_ERROR, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(RECORD_ID, logEntry.RecordId__c, ERROR_INVALID_RECORD_ID);
		Assert.areEqual(System.MathException.class.getName(), logEntry.ExceptionType__c, ERROR_INVALID_EXCEPTION_TYPE);
	}

	/**
	 * @description Tests that the fluent builder emits an info log with summary and message.
	 *
	 * @see LOG_Builder.build
	 * @see LOG_Builder.LogEntry.emit
	 */
	@IsTest
	private static void builderEmitsInfoWithSummary()
	{
		LOG_Builder.ignoreTestMode = true;
		String builderMethod = 'BuilderTest/infoSummary_' + System.currentTimeMillis();
		String expectedMessage = UTIL_Random.randomName();
		String expectedSummary = UTIL_Random.randomName();

		Test.startTest();

		LOG_Builder.build()
				.info(expectedMessage)
				.withSummary(expectedSummary)
				.at(builderMethod)
				.emit();

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(builderMethod);

		Assert.areEqual(LEVEL_INFO, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(expectedMessage, logEntry.Message__c, ERROR_INCORRECT_MESSAGE);
		Assert.areEqual(expectedSummary, logEntry.ShortMessage__c, ERROR_INVALID_SHORT_MESSAGE);
	}

	/**
	 * @description Tests that per-entry context is set during emit and cleaned up afterwards.
	 *
	 * @see LOG_Builder.LogEntry.withContext
	 */
	@IsTest
	private static void builderContextIsCleanedUpAfterEmit()
	{
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.build()
				.debug('Context test')
				.at(CLASS_METHOD)
				.withContext('transientKey', 'transientValue')
				.emit();

		Test.stopTest();

		Assert.isFalse(LOG_Engine.globalContextData.containsKey('transientKey'), 'Per-entry context should be cleaned up after emit');
	}

	/**
	 * @description Tests the builder with a warn level, string record ID, and debug level.
	 *
	 * @see LOG_Builder.LogEntry.warn
	 * @see LOG_Builder.LogEntry.forRecord
	 */
	@IsTest
	private static void builderEmitsWarnWithStringRecordId()
	{
		LOG_Builder.ignoreTestMode = true;
		String builderMethod = 'BuilderTest/warnStringId_' + System.currentTimeMillis();
		String expectedMessage = UTIL_Random.randomName();

		Test.startTest();

		LOG_Builder.build()
				.warn(expectedMessage)
				.at(builderMethod)
				.forRecord((String)RECORD_ID)
				.emit();

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(builderMethod);

		Assert.areEqual(LEVEL_WARN, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(expectedMessage, logEntry.Message__c, ERROR_INCORRECT_MESSAGE);
		Assert.areEqual(RECORD_ID, logEntry.RecordId__c, ERROR_INVALID_RECORD_ID);
	}

	/**
	 * @description Tests the builder with error string message (non-exception path).
	 *
	 * @see LOG_Builder.LogEntry.error
	 */
	@IsTest
	private static void builderEmitsErrorWithStringMessage()
	{
		LOG_Builder.ignoreTestMode = true;
		String builderMethod = 'BuilderTest/errorString_' + System.currentTimeMillis();
		String expectedMessage = UTIL_Random.randomName();

		Test.startTest();

		LOG_Builder.build()
				.error(expectedMessage)
				.at(builderMethod)
				.emit();

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(builderMethod);

		Assert.areEqual(LEVEL_ERROR, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(expectedMessage, logEntry.Message__c, ERROR_INCORRECT_MESSAGE);
	}

	/**
	 * @description Tests the builder with exception but no record ID.
	 *
	 * @see LOG_Builder.LogEntry.error
	 * @see LOG_Builder.LogEntry.emit
	 */
	@IsTest
	private static void builderEmitsErrorWithExceptionWithoutRecord()
	{
		LOG_Builder.ignoreTestMode = true;
		String builderMethod = 'BuilderTest/errorNoRecord_' + System.currentTimeMillis();

		Test.startTest();

		try
		{
			Double invalidNumber = 1 / 0;
		}
		catch(Exception error)
		{
			LOG_Builder.build()
					.error(error)
					.at(builderMethod)
					.emit();
		}

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(builderMethod);

		Assert.areEqual(LEVEL_ERROR, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(System.MathException.class.getName(), logEntry.ExceptionType__c, ERROR_INVALID_EXCEPTION_TYPE);
	}

	/**
	 * @description Tests that emitAt sets the class method and emits the log entry in one call.
	 *
	 * @see LOG_Builder.LogEntry.emitAt
	 */
	@IsTest
	private static void emitAtSetsClassMethodAndEmits()
	{
		String logMessage = UTIL_Random.randomName();
		String builderMethod = 'EmitAtTest/shortcut_' + System.currentTimeMillis();
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.build().error(logMessage).emitAt(builderMethod);

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(builderMethod);

		Assert.areEqual(logMessage, logEntry.Message__c, ERROR_INCORRECT_MESSAGE);
		Assert.areEqual(LEVEL_ERROR, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
		Assert.areEqual(UserInfo.getUserId(), logEntry.UserId__c, ERROR_INVALID_USER_ID);
	}

	/**
	 * @description Tests that LogScope buffers logs and flushes on close.
	 *
	 * @see LOG_Builder.scope
	 * @see LOG_Builder.LogScope.close
	 */
	@IsTest
	private static void scopeBuffersLogsAndFlushesOnClose()
	{
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.LogScope scope = LOG_Builder.scope();
		LOG_Builder.build().debug('Scoped message 1').at(CLASS_METHOD).emit();
		LOG_Builder.build().debug('Scoped message 2').at(CLASS_METHOD).emit();

		Integer bufferSizeDuringScope = LOG_Engine.getBufferSize();

		scope.close();

		Integer bufferSizeAfterClose = LOG_Engine.getBufferSize();

		Test.stopTest();

		Assert.areEqual(2, bufferSizeDuringScope, 'Buffer should contain 2 logs during scope');
		Assert.areEqual(0, bufferSizeAfterClose, 'Buffer should be empty after scope close');
	}

	/**
	 * @description Tests that calling close() multiple times on a LogScope is a safe no-op.
	 *
	 * @see LOG_Builder.LogScope.close
	 */
	@IsTest
	private static void scopeCloseIsIdempotent()
	{
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		LOG_Builder.LogScope scope = LOG_Builder.scope();
		LOG_Builder.build().debug('Scoped message').at(CLASS_METHOD).emit();
		scope.close();
		scope.close();

		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getBufferSize(), 'Buffer should be empty after double close');
	}

	/**
	 * @description Tests that LogScope resumes publishing so subsequent logs are not buffered.
	 *
	 * @see LOG_Builder.scope
	 */
	@IsTest
	private static void scopeResumesPublishingAfterClose()
	{
		LOG_Builder.ignoreTestMode = true;
		String scopedMethod = 'ScopeTest/resume_' + System.currentTimeMillis();

		Test.startTest();

		LOG_Builder.LogScope scope = LOG_Builder.scope();
		scope.close();

		LOG_Builder.build().debug('After scope').at(scopedMethod).emit();

		Test.stopTest();

		LogEntry__c logEntry = new SEL_LogEntry().findByMethod(scopedMethod);

		Assert.isNotNull(logEntry, 'Log should be published after scope is closed');
		Assert.areEqual(LEVEL_DEBUG, logEntry.LogLevel__c, ERROR_INVALID_LOG_LEVEL);
	}

	/**
	 * @description Tests the full real path: a subscriber entry built with withFingerprint
	 * persists as a detail: row plus a rollup: counter (first occurrence of a novel key).
	 */
	@IsTest
	private static void shouldPersistFingerprintedEntryAsDetailPlusRollup()
	{
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();
		LOG_Builder.build().warn('Fingerprinted entry').withFingerprint('builder-test-key').emitAt('BuilderTest.run');
		Test.stopTest();

		Boolean detailFound = false;
		Boolean rollupFound = false;
		for(LogEntry__c row : new SEL_LogEntry().getAll())
		{
			if('detail:builder-test-key'.equals(row.Fingerprint__c))
			{
				detailFound = true;
			}
			if(row.Fingerprint__c != null && row.Fingerprint__c.startsWith('rollup:builder-test-key:'))
			{
				rollupFound = true;
				Assert.areEqual(1, row.OccurrenceCount__c?.intValue(), 'First occurrence counts once');
			}
		}
		Assert.isTrue(detailFound, 'withFingerprint must produce the detail row through the real emit path');
		Assert.isTrue(rollupFound, 'withFingerprint must produce the windowed rollup row');
	}

	/**
	 * @description Tests that the fingerprint channel is cleared after emit — a subsequent
	 * un-fingerprinted entry must persist as a plain row, not inherit the previous key.
	 */
	@IsTest
	private static void shouldNotLeakFingerprintIntoSubsequentEntries()
	{
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();
		LOG_Builder.build().warn('Fingerprinted entry').withFingerprint('leak-test-key').emitAt('BuilderTest.first');
		LOG_Builder.build().warn('Plain entry').emitAt('BuilderTest.second');
		Test.stopTest();

		for(LogEntry__c row : new SEL_LogEntry().getAll())
		{
			if('BuilderTest.second'.equals(row.ClassMethod__c))
			{
				Assert.isNull(row.Fingerprint__c, 'Fingerprint must not leak into the next entry');
				return;
			}
		}
		Assert.fail('The plain entry should have persisted');
	}

	/**
	 * @description Tests key normalization: keys over 200 characters and keys invading the
	 * reserved bypass: prefix are SHA-256 hashed (never truncated, never colliding with
	 * framework keys); blank keys are ignored.
	 */
	@IsTest
	private static void shouldNormalizeOversizedAndReservedFingerprintKeys()
	{
		String oversized = 'k'.repeat(LOG_Builder.MAXIMUM_RAW_FINGERPRINT_LENGTH + 1);
		String reserved = LOG_Builder.RESERVED_FINGERPRINT_PREFIX + 'sneaky-subscriber-key';

		Assert.areEqual(UTIL_Crypto.generateSHA256Hash(oversized), LOG_Builder.normalizeFingerprintKeyForTest(oversized),
				'Oversized keys are hashed, not truncated');
		Assert.areEqual(UTIL_Crypto.generateSHA256Hash(reserved), LOG_Builder.normalizeFingerprintKeyForTest(reserved),
				'Keys invading the reserved bypass: prefix are hashed');
		Assert.areEqual('plain-key', LOG_Builder.normalizeFingerprintKeyForTest(' plain-key '),
				'Short keys are trimmed and stored as-is for readability');
		Assert.isNull(LOG_Builder.normalizeFingerprintKeyForTest('   '), 'Blank keys normalize to null');
	}

	/**
	 * @description Tests that withFingerprintInternal stamps a reserved-prefix key verbatim
	 * (no normalization/hashing) — the framework path that lets bypass-audit keep readable
	 * `bypass:` keys, in contrast to the subscriber-facing withFingerprint which would hash them.
	 */
	@IsTest
	private static void shouldStampReservedFingerprintVerbatimViaInternalSetter()
	{
		LOG_Builder.ignoreTestMode = true;
		String reservedKey = LOG_Builder.RESERVED_FINGERPRINT_PREFIX + 'health-check';

		Test.startTest();
		LOG_Builder.build().warn('Internal fingerprint').withFingerprintInternal(reservedKey).emitAt('BuilderTest.internal');
		Test.stopTest();

		Boolean detailFound = false;
		for(LogEntry__c row : new SEL_LogEntry().getAll())
		{
			if(('detail:' + reservedKey).equals(row.Fingerprint__c))
			{
				detailFound = true;
			}
		}
		Assert.isTrue(detailFound, 'withFingerprintInternal must stamp the reserved key verbatim, producing detail:' + reservedKey);
	}

	/**
	 * @description Tests that withFingerprintInternal length-caps an oversized pre-composed key by
	 * SHA-256 hashing it (the same 200-char budget the subscriber path enforces), so a future
	 * framework caller cannot overflow the 216-char Fingerprint__c field and sink the persist batch.
	 */
	@IsTest
	private static void shouldLengthCapOversizedKeyViaInternalSetter()
	{
		LOG_Builder.ignoreTestMode = true;
		String oversized = 'x'.repeat(LOG_Builder.MAXIMUM_RAW_FINGERPRINT_LENGTH + 1);
		String expectedDetailKey = 'detail:' + UTIL_Crypto.generateSHA256Hash(oversized);

		Test.startTest();
		LOG_Builder.build().warn('Oversized internal fingerprint').withFingerprintInternal(oversized).emitAt('BuilderTest.internalCap');
		Test.stopTest();

		Boolean cappedDetailFound = false;
		for(LogEntry__c row : new SEL_LogEntry().getAll())
		{
			if(expectedDetailKey.equals(row.Fingerprint__c))
			{
				cappedDetailFound = true;
			}
		}
		Assert.isTrue(cappedDetailFound, 'withFingerprintInternal must SHA-256 hash an oversized key, producing ' + expectedDetailKey);
	}

	/**
	 * @description Tests the reconciliation breadcrumb: when withFingerprint hashes a key (here an
	 * oversized one), the original key is recorded in the detail row's context under
	 * LOG_Engine.CONTEXT_FINGERPRINT_SOURCE so the opaque hash stays traceable to the input.
	 */
	@IsTest
	private static void shouldRecordOriginalKeyBreadcrumbWhenFingerprintHashed()
	{
		LOG_Builder.ignoreTestMode = true;
		String oversized = 'k'.repeat(LOG_Builder.MAXIMUM_RAW_FINGERPRINT_LENGTH + 1);

		Test.startTest();
		LOG_Builder.build().warn('Hashed key entry').withFingerprint(oversized).emitAt('BuilderTest.breadcrumb');
		Test.stopTest();

		Boolean breadcrumbFound = false;
		for(LogEntry__c row : new SEL_LogEntry().getAll())
		{
			if(row.Fingerprint__c == null || !row.Fingerprint__c.startsWith('detail:'))
			{
				continue;
			}
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(row);
			if(context != null && oversized.equals(context.get(LOG_Engine.CONTEXT_FINGERPRINT_SOURCE)))
			{
				breadcrumbFound = true;
			}
		}
		Assert.isTrue(breadcrumbFound, 'A hashed fingerprint must record the original key in ContextData for reconciliation');
	}

	/**
	 * @description Tests that a verbatim (short, non-reserved) fingerprint adds no breadcrumb — the
	 * stored fingerprint already shows the key, so no context noise is added.
	 */
	@IsTest
	private static void shouldNotAddBreadcrumbForVerbatimFingerprint()
	{
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();
		LOG_Builder.build().warn('Verbatim key entry').withFingerprint('plain-readable-key').emitAt('BuilderTest.verbatim');
		Test.stopTest();

		for(LogEntry__c row : new SEL_LogEntry().getAll())
		{
			if('detail:plain-readable-key'.equals(row.Fingerprint__c))
			{
				Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(row);
				Boolean hasBreadcrumb = context != null && context.containsKey(LOG_Engine.CONTEXT_FINGERPRINT_SOURCE);
				Assert.isFalse(hasBreadcrumb, 'Verbatim keys need no breadcrumb — the fingerprint already shows the key');
				return;
			}
		}
		Assert.fail('The verbatim-key detail row should have persisted');
	}
}