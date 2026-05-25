// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the behaviour of the associated invocable class
 *
 * @see FLOW_WriteLog
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date September 2025, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FLOW_WriteLog_TEST
{
	/**
	 * @description Checks to see the messages are logged as expected
	 *
	 * @see FLOW_WriteLog.writeLog
	 */
	@IsTest
	private static void writeLog()
	{
		final Id recordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		final String classMethod = FLOW_WriteLog_TEST.class.getName() + '.writeLog';
		final String message = UTIL_Random.randomDescription();
		final String shortMessage = UTIL_Random.randomName();

		List<FLOW_WriteLog.DTO_Request> dtoRequests = new List<FLOW_WriteLog.DTO_Request>();

		for(Integer i = 0; i < 3; i++)
		{
			FLOW_WriteLog.DTO_Request dtoRequest = new FLOW_WriteLog.DTO_Request();

			dtoRequest.classMethod = classMethod;
			dtoRequest.logLevel = 'INVALID'; //Tests that it converts invalid logLevel to "INFO"
			dtoRequest.message = message;
			dtoRequest.recordId = recordId;
			dtoRequest.shortMessage = shortMessage;

			dtoRequests.add(dtoRequest);
		}

		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		FLOW_WriteLog.writeLog(dtoRequests);

		Test.stopTest();

		List<LogEntry__c> foundLogs = new SEL_LogEntry().getAll();
		Assert.areEqual(dtoRequests.size(), foundLogs.size(), 'Incorrect number of logs written');

		LogEntry__c foundLog = foundLogs.iterator().next();

		Assert.areEqual(LoggingLevel.INFO.name(), foundLog.LogLevel__c, 'Invalid Log Value');
		Assert.areEqual(classMethod, foundLog.ClassMethod__c, 'Invalid Log Value');
		Assert.areEqual(message, foundLog.Message__c, 'Invalid Log Value');
		Assert.areEqual(recordId, foundLog.RecordId__c, 'Invalid Log Value');
		Assert.areEqual(shortMessage, foundLog.ShortMessage__c, 'Invalid Log Value');
	}

	/**
	 * @description Tests that correlation ID is set when provided from Flow.
	 *
	 * @see FLOW_WriteLog.writeLog
	 */
	@IsTest
	private static void writeLogSetsCorrelationId()
	{
		final String correlationId = 'flow-correlation-' + System.currentTimeMillis();
		final String classMethod = FLOW_WriteLog_TEST.class.getName() + '.writeLogSetsCorrelationId';

		FLOW_WriteLog.DTO_Request dtoRequest = new FLOW_WriteLog.DTO_Request();
		dtoRequest.classMethod = classMethod;
		dtoRequest.correlationId = correlationId;
		dtoRequest.logLevel = 'INFO';
		dtoRequest.message = 'Test message with correlation';

		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		FLOW_WriteLog.writeLog(new List<FLOW_WriteLog.DTO_Request> {dtoRequest});

		Test.stopTest();

		Assert.areEqual(correlationId, LOG_Builder.correlationId, 'Correlation ID should be set from Flow');
	}

	/**
	 * @description Tests that blank correlation ID does not affect logging.
	 *
	 * @see FLOW_WriteLog.writeLog
	 */
	@IsTest
	private static void writeLogHandlesBlankCorrelationId()
	{
		final String classMethod = FLOW_WriteLog_TEST.class.getName() + '.writeLogHandlesBlankCorrelationId';

		// Clear any existing correlation
		LOG_Engine.currentCorrelationId = null;

		FLOW_WriteLog.DTO_Request dtoRequest = new FLOW_WriteLog.DTO_Request();
		dtoRequest.classMethod = classMethod;
		dtoRequest.correlationId = null; // Explicitly null
		dtoRequest.logLevel = 'INFO';
		dtoRequest.message = 'Test message without correlation';

		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		FLOW_WriteLog.writeLog(new List<FLOW_WriteLog.DTO_Request> {dtoRequest});

		Test.stopTest();

		Assert.isNull(LOG_Builder.correlationId, 'Correlation ID should remain null when not provided');
	}

	/**
	 * @description Tests that ERROR log level is correctly applied.
	 *
	 * @see FLOW_WriteLog.writeLog
	 */
	@IsTest
	private static void writeLogWithErrorLevel()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		final String classMethod = FLOW_WriteLog_TEST.class.getName() + '.writeLogWithErrorLevel';
		final String message = UTIL_Random.randomDescription();

		FLOW_WriteLog.DTO_Request dtoRequest = new FLOW_WriteLog.DTO_Request();
		dtoRequest.classMethod = classMethod;
		dtoRequest.logLevel = 'ERROR';
		dtoRequest.message = message;

		Test.startTest();

		FLOW_WriteLog.writeLog(new List<FLOW_WriteLog.DTO_Request> {dtoRequest});

		Test.stopTest();

		List<LogEntry__c> foundLogs = new SEL_LogEntry().getAll();
		Assert.areEqual(1, foundLogs.size(), 'Should have one log entry');
		Assert.areEqual(LoggingLevel.ERROR.name(), foundLogs[0].LogLevel__c, 'Log level should be ERROR');
	}

	/**
	 * @description Tests that DEBUG log level is correctly applied.
	 *
	 * @see FLOW_WriteLog.writeLog
	 */
	@IsTest
	private static void writeLogWithDebugLevel()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		final String classMethod = FLOW_WriteLog_TEST.class.getName() + '.writeLogWithDebugLevel';
		final String message = UTIL_Random.randomDescription();

		FLOW_WriteLog.DTO_Request dtoRequest = new FLOW_WriteLog.DTO_Request();
		dtoRequest.classMethod = classMethod;
		dtoRequest.logLevel = 'DEBUG';
		dtoRequest.message = message;

		Test.startTest();

		FLOW_WriteLog.writeLog(new List<FLOW_WriteLog.DTO_Request> {dtoRequest});

		Test.stopTest();

		List<LogEntry__c> foundLogs = new SEL_LogEntry().getAll();
		Assert.areEqual(1, foundLogs.size(), 'Should have one log entry');
		Assert.areEqual(LoggingLevel.DEBUG.name(), foundLogs[0].LogLevel__c, 'Log level should be DEBUG');
	}

	/**
	 * @description Tests that WARN log level is correctly applied.
	 *
	 * @see FLOW_WriteLog.writeLog
	 */
	@IsTest
	private static void writeLogWithWarnLevel()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		final String classMethod = FLOW_WriteLog_TEST.class.getName() + '.writeLogWithWarnLevel';
		final String message = UTIL_Random.randomDescription();

		FLOW_WriteLog.DTO_Request dtoRequest = new FLOW_WriteLog.DTO_Request();
		dtoRequest.classMethod = classMethod;
		dtoRequest.logLevel = 'WARN';
		dtoRequest.message = message;

		Test.startTest();

		FLOW_WriteLog.writeLog(new List<FLOW_WriteLog.DTO_Request> {dtoRequest});

		Test.stopTest();

		List<LogEntry__c> foundLogs = new SEL_LogEntry().getAll();
		Assert.areEqual(1, foundLogs.size(), 'Should have one log entry');
		Assert.areEqual(LoggingLevel.WARN.name(), foundLogs[0].LogLevel__c, 'Log level should be WARN');
	}
}