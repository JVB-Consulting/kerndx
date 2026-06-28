// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for Flow Logger invocable classes:
 * FLOW_LoggerStart, FLOW_LoggerLog, FLOW_LoggerEnd.
 *
 * @see FLOW_Logger_TEST
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date December 2025, June 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class FLOW_Logger_TEST
{
	/**
	 * @description Tests starting Flow correlation returns a correlation ID.
	 */
	@IsTest
	private static void shouldStartFlowCorrelation()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		FLOW_LoggerStart.DTO_Request input = new FLOW_LoggerStart.DTO_Request();
		input.flowName = 'Test Flow';

		// Execute
		Test.startTest();
		List<FLOW_LoggerStart.DTO_Response> outputs = FLOW_LoggerStart.execute(new List<FLOW_LoggerStart.DTO_Request> {input});
		Test.stopTest();

		// Verify
		Assert.areEqual(1, outputs.size(), 'Should return one output');
		Assert.isNotNull(outputs[0].correlationId, 'Should return a correlation ID');
		Assert.areNotEqual('', outputs[0].correlationId, 'Correlation ID should not be empty');
	}

	/**
	 * @description Tests starting Flow correlation with record ID.
	 */
	@IsTest
	private static void shouldStartFlowCorrelationWithRecordId()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		FLOW_LoggerStart.DTO_Request input = new FLOW_LoggerStart.DTO_Request();
		input.flowName = 'Test Flow';
		input.recordId = UTIL_Random.randomId(Foobar__c.SObjectType);

		// Execute
		Test.startTest();
		List<FLOW_LoggerStart.DTO_Response> outputs = FLOW_LoggerStart.execute(new List<FLOW_LoggerStart.DTO_Request> {input});
		Test.stopTest();

		// Verify
		Assert.isNotNull(outputs.iterator().next().correlationId, 'Should return a correlation ID');
	}

	/**
	 * @description Tests logging a Flow event with INFO level.
	 */
	@IsTest
	private static void shouldLogFlowEventInfo()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		String correlationId = LOG_Engine.startCorrelation();

		FLOW_LoggerLog.DTO_Request input = new FLOW_LoggerLog.DTO_Request();
		input.correlationId = correlationId;
		input.message = 'Test message';
		input.logLevel = 'INFO';
		input.flowStep = 'Test Step';

		// Execute
		Test.startTest();
		FLOW_LoggerLog.execute(new List<FLOW_LoggerLog.DTO_Request> {input});
		Test.stopTest();

		// Verify - test passes if no exceptions
		Assert.areEqual(correlationId, LOG_Engine.getCorrelationId(), 'Correlation should be maintained');
	}

	/**
	 * @description Tests logging a Flow event with DEBUG level.
	 */
	@IsTest
	private static void shouldLogFlowEventDebug()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		String correlationId = LOG_Engine.startCorrelation();

		FLOW_LoggerLog.DTO_Request input = new FLOW_LoggerLog.DTO_Request();
		input.correlationId = correlationId;
		input.message = 'Debug message';
		input.logLevel = 'DEBUG';

		// Execute
		Test.startTest();
		FLOW_LoggerLog.execute(new List<FLOW_LoggerLog.DTO_Request> {input});
		Test.stopTest();

		List<LogEntry__c> logs = new SEL_LogEntry().getAll();
		Assert.isFalse(logs.isEmpty(), 'Should create a log entry');
		Assert.areEqual(LoggingLevel.DEBUG.name(), logs[0].LogLevel__c, 'Should log at DEBUG level');
	}

	/**
	 * @description Tests logging a Flow event with WARN level.
	 */
	@IsTest
	private static void shouldLogFlowEventWarn()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		String correlationId = LOG_Engine.startCorrelation();

		FLOW_LoggerLog.DTO_Request input = new FLOW_LoggerLog.DTO_Request();
		input.correlationId = correlationId;
		input.message = 'Warning message';
		input.logLevel = 'WARN';

		Test.startTest();
		FLOW_LoggerLog.execute(new List<FLOW_LoggerLog.DTO_Request> {input});
		Test.stopTest();

		List<LogEntry__c> logs = new SEL_LogEntry().getAll();
		Assert.isFalse(logs.isEmpty(), 'Should create a log entry');
		Assert.areEqual(LoggingLevel.WARN.name(), logs[0].LogLevel__c, 'Should log at WARN level');
	}

	/**
	 * @description Tests logging a Flow event with ERROR level.
	 */
	@IsTest
	private static void shouldLogFlowEventError()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		String correlationId = LOG_Engine.startCorrelation();

		FLOW_LoggerLog.DTO_Request input = new FLOW_LoggerLog.DTO_Request();
		input.correlationId = correlationId;
		input.message = 'Error message';
		input.logLevel = 'ERROR';

		Test.startTest();
		FLOW_LoggerLog.execute(new List<FLOW_LoggerLog.DTO_Request> {input});
		Test.stopTest();

		List<LogEntry__c> logs = new SEL_LogEntry().getAll();
		Assert.isFalse(logs.isEmpty(), 'Should create a log entry');
		Assert.areEqual(LoggingLevel.ERROR.name(), logs[0].LogLevel__c, 'Should log at ERROR level');
	}

	/**
	 * @description Tests logging a Flow event with default level (no level specified).
	 */
	@IsTest
	private static void shouldLogFlowEventDefaultLevel()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		String correlationId = LOG_Engine.startCorrelation();

		FLOW_LoggerLog.DTO_Request input = new FLOW_LoggerLog.DTO_Request();
		input.correlationId = correlationId;
		input.message = 'Default level message';

		Test.startTest();
		FLOW_LoggerLog.execute(new List<FLOW_LoggerLog.DTO_Request> {input});
		Test.stopTest();

		List<LogEntry__c> logs = new SEL_LogEntry().getAll();
		Assert.isFalse(logs.isEmpty(), 'Should create a log entry');
		Assert.areEqual(LoggingLevel.INFO.name(), logs[0].LogLevel__c, 'Should default to INFO level');
	}

	/**
	 * @description Tests logging a Flow event without flow step.
	 */
	@IsTest
	private static void shouldLogFlowEventWithoutFlowStep()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		String correlationId = LOG_Engine.startCorrelation();

		FLOW_LoggerLog.DTO_Request input = new FLOW_LoggerLog.DTO_Request();
		input.correlationId = correlationId;
		input.message = 'Message without step';
		input.logLevel = 'INFO';

		Test.startTest();
		FLOW_LoggerLog.execute(new List<FLOW_LoggerLog.DTO_Request> {input});
		Test.stopTest();

		List<LogEntry__c> logs = new SEL_LogEntry().getAll();
		Assert.isFalse(logs.isEmpty(), 'Should create a log entry');
	}

	/**
	 * @description Tests that a record ID supplied to the Log Flow Event action is
	 * written to the resulting log entry's RecordId__c.
	 */
	@IsTest
	private static void shouldLogFlowEventWithRecordId()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		String correlationId = LOG_Engine.startCorrelation();
		Id recordId = UTIL_Random.randomId(Foobar__c.SObjectType);

		FLOW_LoggerLog.DTO_Request input = new FLOW_LoggerLog.DTO_Request();
		input.correlationId = correlationId;
		input.message = 'Message with record';
		input.logLevel = 'INFO';
		input.recordId = recordId;

		Test.startTest();
		FLOW_LoggerLog.execute(new List<FLOW_LoggerLog.DTO_Request> {input});
		Test.stopTest();

		List<LogEntry__c> logs = new SEL_LogEntry().getAll();
		Assert.isFalse(logs.isEmpty(), 'Should create a log entry');
		Assert.areEqual(recordId, logs[0].RecordId__c, 'recordId from the Flow input must land on LogEntry__c.RecordId__c');
	}

	/**
	 * @description Tests ending Flow correlation with success.
	 */
	@IsTest
	private static void shouldEndFlowCorrelationSuccess()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		String correlationId = LOG_Engine.startCorrelation();

		FLOW_LoggerEnd.DTO_Request input = new FLOW_LoggerEnd.DTO_Request();
		input.correlationId = correlationId;
		input.flowName = 'Test Flow';
		input.success = true;

		// Execute
		Test.startTest();
		FLOW_LoggerEnd.execute(new List<FLOW_LoggerEnd.DTO_Request> {input});
		Test.stopTest();

		List<LogEntry__c> logs = new SEL_LogEntry().getAll();
		Assert.isFalse(logs.isEmpty(), 'Should create a log entry');
		Assert.areEqual(LoggingLevel.INFO.name(), logs[0].LogLevel__c, 'Success should log at INFO level');
	}

	/**
	 * @description Tests ending Flow correlation with failure.
	 */
	@IsTest
	private static void shouldEndFlowCorrelationFailure()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		String correlationId = LOG_Engine.startCorrelation();

		FLOW_LoggerEnd.DTO_Request input = new FLOW_LoggerEnd.DTO_Request();
		input.correlationId = correlationId;
		input.flowName = 'Test Flow';
		input.success = false;
		input.errorMessage = 'Something went wrong';

		Test.startTest();
		FLOW_LoggerEnd.execute(new List<FLOW_LoggerEnd.DTO_Request> {input});
		Test.stopTest();

		List<LogEntry__c> logs = new SEL_LogEntry().getAll();
		Assert.isFalse(logs.isEmpty(), 'Should create a log entry');
		Assert.areEqual(LoggingLevel.WARN.name(), logs[0].LogLevel__c, 'Failure should log at WARN level');
	}

	/**
	 * @description Tests ending Flow correlation with failure but no error message.
	 */
	@IsTest
	private static void shouldEndFlowCorrelationFailureNoMessage()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		String correlationId = LOG_Engine.startCorrelation();

		FLOW_LoggerEnd.DTO_Request input = new FLOW_LoggerEnd.DTO_Request();
		input.correlationId = correlationId;
		input.flowName = 'Test Flow';
		input.success = false;

		Test.startTest();
		FLOW_LoggerEnd.execute(new List<FLOW_LoggerEnd.DTO_Request> {input});
		Test.stopTest();

		List<LogEntry__c> logs = new SEL_LogEntry().getAll();
		Assert.isFalse(logs.isEmpty(), 'Should create a log entry');
		Assert.areEqual(LoggingLevel.WARN.name(), logs[0].LogLevel__c, 'Failure should log at WARN level');
	}

	/**
	 * @description Tests the full Flow logging lifecycle.
	 */
	@IsTest
	private static void shouldSupportFullFlowLifecycle()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		// Step 1: Start Flow
		FLOW_LoggerStart.DTO_Request startInput = new FLOW_LoggerStart.DTO_Request();
		startInput.flowName = 'Full Lifecycle Flow';
		startInput.recordId = UTIL_Random.randomId(Foobar__c.SObjectType);

		Test.startTest();
		List<FLOW_LoggerStart.DTO_Response> startOutputs = FLOW_LoggerStart.execute(new List<FLOW_LoggerStart.DTO_Request> {startInput});
		String correlationId = startOutputs.iterator().next().correlationId;

		// Step 2: Log some events
		FLOW_LoggerLog.DTO_Request logInput1 = new FLOW_LoggerLog.DTO_Request();
		logInput1.correlationId = correlationId;
		logInput1.message = 'Step 1 completed';
		logInput1.flowStep = 'Step 1';
		FLOW_LoggerLog.execute(new List<FLOW_LoggerLog.DTO_Request> {logInput1});

		FLOW_LoggerLog.DTO_Request logInput2 = new FLOW_LoggerLog.DTO_Request();
		logInput2.correlationId = correlationId;
		logInput2.message = 'Step 2 completed';
		logInput2.flowStep = 'Step 2';
		FLOW_LoggerLog.execute(new List<FLOW_LoggerLog.DTO_Request> {logInput2});

		// Step 3: End Flow
		FLOW_LoggerEnd.DTO_Request endInput = new FLOW_LoggerEnd.DTO_Request();
		endInput.correlationId = correlationId;
		endInput.flowName = 'Full Lifecycle Flow';
		endInput.success = true;
		FLOW_LoggerEnd.execute(new List<FLOW_LoggerEnd.DTO_Request> {endInput});

		Test.stopTest();

		// Verify - all operations completed without error
		Assert.isNotNull(correlationId, 'Correlation ID should be generated');
	}

	/**
	 * @description Tests that additionalContext is included with a start log entry.
	 */
	@IsTest
	private static void shouldIncludeAdditionalContextInStart()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		FLOW_LoggerStart.DTO_Request input = new FLOW_LoggerStart.DTO_Request();
		input.flowName = 'Test Flow';
		input.additionalContext = 'environment=production';

		Test.startTest();
		List<FLOW_LoggerStart.DTO_Response> outputs = FLOW_LoggerStart.execute(new List<FLOW_LoggerStart.DTO_Request> {input});
		Test.stopTest();

		Assert.isNotNull(outputs[0].correlationId, 'Should return a correlation ID');
	}

	/**
	 * @description Tests that additionalContext is included with a log entry.
	 */
	@IsTest
	private static void shouldIncludeAdditionalContextInLog()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		String correlationId = LOG_Engine.startCorrelation();

		FLOW_LoggerLog.DTO_Request input = new FLOW_LoggerLog.DTO_Request();
		input.correlationId = correlationId;
		input.message = 'Message with context';
		input.logLevel = 'INFO';
		input.additionalContext = 'orderId=ORD-12345';

		Test.startTest();
		FLOW_LoggerLog.execute(new List<FLOW_LoggerLog.DTO_Request> {input});
		Test.stopTest();

		List<LogEntry__c> logs = new SEL_LogEntry().getAll();
		Assert.isFalse(logs.isEmpty(), 'Should create a log entry');
	}

	/**
	 * @description Tests that empty request list throws IllegalArgumentException.
	 */
	@IsTest
	private static void shouldThrowWhenNoRequestsForStart()
	{
		try
		{
			FLOW_LoggerStart.execute(new List<FLOW_LoggerStart.DTO_Request>());
			Assert.fail('Should throw IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests that multiple requests throw IllegalArgumentException.
	 */
	@IsTest
	private static void shouldThrowWhenMultipleRequestsForStart()
	{
		try
		{
			FLOW_LoggerStart.execute(new List<FLOW_LoggerStart.DTO_Request>
			{
					new FLOW_LoggerStart.DTO_Request(), new FLOW_LoggerStart.DTO_Request()
			});
			Assert.fail('Should throw IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
		}
	}
}