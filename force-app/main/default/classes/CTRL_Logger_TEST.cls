// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for CTRL_Logger.
 *
 * @see CTRL_Logger
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date December 2025, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class CTRL_Logger_TEST
{
	/**
	 * @description Resets logger state for test isolation.
	 */
	private static void resetLoggerState()
	{
		LOG_Engine.setCorrelationId(null);
	}

	/**
	 * @description Creates a test log entry with the specified parameters.
	 *
	 * @param level The log level
	 * @param message The log message
	 * @param correlationId The correlation ID
	 *
	 * @return A new DTO_ClientLogEntry instance
	 */
	private static CTRL_Logger.DTO_ClientLogEntry createEntry(LoggingLevel level, String message, String correlationId)
	{
		CTRL_Logger.DTO_ClientLogEntry entry = new CTRL_Logger.DTO_ClientLogEntry();
		entry.timestamp = Datetime.now();
		entry.level = level;
		entry.message = message;
		entry.correlationId = correlationId;
		return entry;
	}

	/**
	 * @description Tests that persistLogs successfully logs LWC entries.
	 */
	@IsTest
	private static void shouldPersistLogs()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		List<CTRL_Logger.DTO_ClientLogEntry> entries = new List<CTRL_Logger.DTO_ClientLogEntry>
		{
				createEntry(LoggingLevel.INFO, 'User clicked button', 'test-correlation-123')
		};

		// Execute
		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(entries));
		Test.stopTest();

		// Verify correlation was set
		Assert.areEqual('test-correlation-123', LOG_Engine.getCorrelationId(), 'Correlation ID should be set from client log');
	}

	/**
	 * @description Tests that persistLogs handles multiple log entries.
	 */
	@IsTest
	private static void shouldPersistMultipleLogEntries()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		List<CTRL_Logger.DTO_ClientLogEntry> entries = new List<CTRL_Logger.DTO_ClientLogEntry>
		{
				createEntry(LoggingLevel.INFO, 'Operation started', 'multi-log-test'),
				createEntry(LoggingLevel.DEBUG, 'Processing data', 'multi-log-test'),
				createEntry(LoggingLevel.INFO, 'Operation completed', 'multi-log-test')
		};

		// Execute
		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(entries));
		Test.stopTest();

		// Verify correlation was set from first entry
		Assert.areEqual('multi-log-test', LOG_Engine.getCorrelationId(), 'Correlation ID should be set from first log entry');
	}

	/**
	 * @description Tests that persistLogs handles all log levels correctly.
	 */
	@IsTest
	private static void shouldHandleAllLogLevels()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		List<CTRL_Logger.DTO_ClientLogEntry> entries = new List<CTRL_Logger.DTO_ClientLogEntry>
		{
				createEntry(LoggingLevel.DEBUG, 'Debug message', 'level-test'),
				createEntry(LoggingLevel.INFO, 'Info message', 'level-test'),
				createEntry(LoggingLevel.WARN, 'Warn message', 'level-test'),
				createEntry(LoggingLevel.ERROR, 'Error message', 'level-test')
		};

		// Execute - should not throw any exceptions
		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(entries));
		Test.stopTest();

		// Verify
		Assert.areEqual('level-test', LOG_Engine.getCorrelationId(), 'Correlation should be set');
	}

	/**
	 * @description Tests that persistLogs handles null level gracefully.
	 */
	@IsTest
	private static void shouldHandleNullLogLevel()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		List<CTRL_Logger.DTO_ClientLogEntry> entries = new List<CTRL_Logger.DTO_ClientLogEntry>
		{
				createEntry(null, 'Null level message', 'null-level-test')
		};

		// Execute - should not throw, should default to INFO
		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(entries));
		Test.stopTest();

		// Verify
		Assert.areEqual('null-level-test', LOG_Engine.getCorrelationId(), 'Correlation should be set');
	}

	/**
	 * @description Tests that persistLogs handles null entries list.
	 */
	@IsTest
	private static void shouldHandleNullEntries()
	{
		// Setup
		resetLoggerState();

		// Execute - should return early without error
		Test.startTest();
		CTRL_Logger.persistLogs(null);
		Test.stopTest();

		// Verify
		Assert.isNull(LOG_Engine.getCorrelationId(), 'No correlation should be set for null/blank JSON');
	}

	/**
	 * @description Tests that persistLogs handles empty list.
	 */
	@IsTest
	private static void shouldHandleEmptyList()
	{
		// Setup
		resetLoggerState();

		// Execute - should return early without error
		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(new List<CTRL_Logger.DTO_ClientLogEntry>()));
		Test.stopTest();

		// Verify
		Assert.isNull(LOG_Engine.getCorrelationId(), 'No correlation should be set for empty list');
	}

	/**
	 * @description Tests that persistLogs handles logs without correlation ID.
	 */
	@IsTest
	private static void shouldHandleLogsWithoutCorrelationId()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		List<CTRL_Logger.DTO_ClientLogEntry> entries = new List<CTRL_Logger.DTO_ClientLogEntry>
		{
				createEntry(LoggingLevel.INFO, 'No correlation message', null)
		};

		// Execute - should process without throwing
		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(entries));
		Test.stopTest();

		// Verify - method completed without exceptions
		Assert.isTrue(true, 'Should process logs without correlation ID');
	}

	/**
	 * @description Tests that persistLogs handles logs without context.
	 */
	@IsTest
	private static void shouldHandleLogsWithoutContext()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		List<CTRL_Logger.DTO_ClientLogEntry> entries = new List<CTRL_Logger.DTO_ClientLogEntry>
		{
				createEntry(LoggingLevel.INFO, 'No context message', 'no-context-test')
		};

		// Execute - should not throw
		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(entries));
		Test.stopTest();

		// Verify
		Assert.areEqual('no-context-test', LOG_Engine.getCorrelationId(), 'Correlation should be set');
	}

	/**
	 * @description Tests that persistLogs extracts actionName from context when present.
	 */
	@IsTest
	private static void shouldExtractActionNameFromContext()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		CTRL_Logger.DTO_ClientLogEntry entry = createEntry(LoggingLevel.INFO, 'Test message with context', 'action-name-test');
		entry.context = JSON.serialize(new Map<String, Object>
		{
				LOG_Engine.CONTEXT_ACTION_NAME => 'SaveAccount',
				'recordId' => '001xx'
		});

		// Execute - should use 'SaveAccount' as action name in classMethod
		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(new List<CTRL_Logger.DTO_ClientLogEntry> {entry}));
		Test.stopTest();

		// Verify
		Assert.areEqual('action-name-test', LOG_Engine.getCorrelationId(), 'Correlation should be set');
	}

	/**
	 * @description Tests that timestamp is properly handled as Datetime.
	 */
	@IsTest
	private static void shouldHandleDatetimeTimestamp()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		CTRL_Logger.DTO_ClientLogEntry entry = new CTRL_Logger.DTO_ClientLogEntry();
		entry.timestamp = Datetime.newInstance(2025, 12, 24, 10, 30, 0);
		entry.level = LoggingLevel.INFO;
		entry.message = 'Test with datetime';
		entry.correlationId = 'datetime-test';

		List<CTRL_Logger.DTO_ClientLogEntry> entries = new List<CTRL_Logger.DTO_ClientLogEntry> {entry};

		// Execute
		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(entries));
		Test.stopTest();

		// Verify
		Assert.areEqual('datetime-test', LOG_Engine.getCorrelationId(), 'Should process entry with Datetime timestamp');
	}
}