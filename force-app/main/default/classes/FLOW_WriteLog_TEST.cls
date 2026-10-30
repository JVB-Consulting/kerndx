// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests the behaviour of the associated invocable class
 *
 * @see FLOW_WriteLog
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date September 2025, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class FLOW_WriteLog_TEST
{
	/**
	 * @description Key of the map the logger wraps its merged context in when it serialises `ContextData__c`.
	 */
	private static final String CONTEXT_DATA_KEY = 'contextData';

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

		List<LogEntry__c> foundLogs = new SEL_LogEntry().findAllByMethod(classMethod);
		Assert.areEqual(dtoRequests.size(), foundLogs.size(), 'Incorrect number of logs written');

		LogEntry__c foundLog = foundLogs.iterator().next();

		Assert.areEqual(LoggingLevel.INFO.name(), foundLog.LogLevel__c, 'Invalid Log Value');
		Assert.areEqual(classMethod, foundLog.ClassMethod__c, 'Invalid Log Value');
		Assert.areEqual('[Flow] ' + message, foundLog.Message__c, 'The message should carry the Flow provenance prefix');
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

		List<LogEntry__c> foundLogs = new SEL_LogEntry().findAllByMethod(classMethod);
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

		List<LogEntry__c> foundLogs = new SEL_LogEntry().findAllByMethod(classMethod);
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

		List<LogEntry__c> foundLogs = new SEL_LogEntry().findAllByMethod(classMethod);
		Assert.areEqual(1, foundLogs.size(), 'Should have one log entry');
		Assert.areEqual(LoggingLevel.WARN.name(), foundLogs[0].LogLevel__c, 'Log level should be WARN');
	}

	/**
	 * @description A line written by the Flow action is stamped Flow, names the class the Flow passed as its
	 * source, and leaves the context stack as it found it.
	 *
	 * @see FLOW_WriteLog.writeLog
	 */
	@IsTest
	private static void writeLogStampsFlowOriginAndKeepsTheStackBalanced()
	{
		final String classMethod = FLOW_WriteLog_TEST.class.getName() + '.stamped';
		FLOW_WriteLog.DTO_Request dtoRequest = new FLOW_WriteLog.DTO_Request();
		dtoRequest.classMethod = classMethod;
		dtoRequest.message = UTIL_Random.randomDescription();
		LOG_Builder.ignoreTestMode = true;
		Integer depthBefore = LOG_Engine.getContextStackDepth();

		Test.startTest();
		FLOW_WriteLog.writeLog(new List<FLOW_WriteLog.DTO_Request> {dtoRequest});
		Test.stopTest();

		Assert.areEqual(depthBefore, LOG_Engine.getContextStackDepth(), 'The action pops the context it pushed');
		LogEntry__c foundLog = new SEL_LogEntry().findByMethod(classMethod);
		Assert.isNotNull(foundLog, 'The line was written');
		Assert.areEqual(LOG_Engine.Origin.FLOW.name(), foundLog.Origin__c, 'A Flow wrote this line');
		String expectedSource = classMethod.removeStart(UTIL_System.getManagedPackageNamespacePrefix(UTIL_String.DOT)).substringBefore(UTIL_String.DOT);
		Assert.areEqual(expectedSource, foundLog.Source__c, 'The source is the class the Flow passed');
		Map<String, Object> envelope = (Map<String, Object>)JSON.deserializeUntyped(foundLog.ContextData__c);
		Map<String, Object> contextData = (Map<String, Object>)envelope.get(CONTEXT_DATA_KEY);
		Assert.areEqual(LOG_Engine.FLOW_SOURCE_MARKER, contextData.get(LOG_Engine.CONTEXT_SOURCE),
				'The context carries the Flow marker its sibling action writes');
	}

	/**
	 * @description A request that names no class and method is written under the action's own default label, whose
	 * slash and method text every value already stored on an entry depends on.
	 *
	 * @see FLOW_WriteLog.writeLog
	 */
	@IsTest
	private static void writeLogLabelsABlankClassMethodWithTheActionsDefault()
	{
		final String expectedClassMethod = FLOW_WriteLog.class.getName() + '/writeLog';
		FLOW_WriteLog.DTO_Request dtoRequest = new FLOW_WriteLog.DTO_Request();
		dtoRequest.message = UTIL_Random.randomDescription();
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();
		FLOW_WriteLog.writeLog(new List<FLOW_WriteLog.DTO_Request> {dtoRequest});
		Test.stopTest();

		LogEntry__c foundLog = new SEL_LogEntry().findByMethod(expectedClassMethod);
		Assert.isNotNull(foundLog, 'The line was written under the action\'s default label, with the slash and the method text every stored value depends on');
	}
}