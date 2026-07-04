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
 * @date December 2025, July 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class CTRL_Logger_TEST
{
	/**
	 * @description A representative client-side JavaScript error stack as captured by the LWC logger.
	 */
	private static final String CLIENT_STACK = 'Error: boom\n    at submitOrder (c/orderPanel.js:42:13)';

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

	/**
	 * @description Tests that persistLogs persists the client context payload into ContextData__c and
	 * promotes the client JavaScript error stack into StackTrace__c — excluding the promoted keys from
	 * the persisted context — and that the stack does not leak onto a following entry without one.
	 */
	@IsTest
	private static void shouldPersistClientContextAndPromoteErrorStack()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		CTRL_Logger.DTO_ClientLogEntry crashEntry = createEntry(LoggingLevel.ERROR, 'Component crashed', 'client-payload-test');
		crashEntry.context = JSON.serialize(new Map<String, Object>
		{
				LOG_Engine.CONTEXT_ACTION_NAME => 'SubmitOrder',
				LOG_Engine.CONTEXT_ERROR_STACK => CLIENT_STACK,
				'errorMessage' => 'boom',
				'recordCount' => 3
		});
		CTRL_Logger.DTO_ClientLogEntry plainEntry = createEntry(LoggingLevel.INFO, 'Follow-up entry', 'client-payload-test');
		plainEntry.context = JSON.serialize(new Map<String, Object> {LOG_Engine.CONTEXT_ACTION_NAME => 'RefreshList'});

		// Execute
		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(new List<CTRL_Logger.DTO_ClientLogEntry> {crashEntry, plainEntry}));
		Test.stopTest();

		// Verify
		LogEntry__c crashRow = new SEL_LogEntry().findByMethod(LOG_Engine.OperationType.LWC.name() + '/SubmitOrder');
		Assert.isNotNull(crashRow, 'The crash entry should persist');
		Assert.areEqual(CLIENT_STACK, crashRow.StackTrace__c, 'The client JavaScript stack should persist as the stack trace');
		Assert.isTrue(crashRow.ContextData__c.contains('errorMessage'), 'The client context keys should persist into ContextData__c');
		Assert.isTrue(crashRow.ContextData__c.contains('recordCount'), 'All non-promoted client context keys should persist');
		Assert.isFalse(crashRow.ContextData__c.contains(LOG_Engine.CONTEXT_ERROR_STACK), 'The stack is promoted to StackTrace__c, not duplicated in context');

		LogEntry__c plainRow = new SEL_LogEntry().findByMethod(LOG_Engine.OperationType.LWC.name() + '/RefreshList');
		Assert.isNotNull(plainRow, 'The follow-up entry should persist');
		Assert.areNotEqual(CLIENT_STACK, plainRow.StackTrace__c, 'The stack override must not leak onto entries that did not supply one');
	}

	/**
	 * @description Tests that a client errorStack that cannot be promoted (a non-string value) is kept in
	 * the persisted context instead of being dropped, so no client payload is silently lost.
	 */
	@IsTest
	private static void shouldKeepUnpromotableErrorStackInContext()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		CTRL_Logger.DTO_ClientLogEntry entry = createEntry(LoggingLevel.ERROR, 'Crash with structured stack', 'unpromotable-stack-test');
		entry.context = JSON.serialize(new Map<String, Object>
		{
				LOG_Engine.CONTEXT_ACTION_NAME => 'StructuredStack',
				LOG_Engine.CONTEXT_ERROR_STACK => new List<String> {'frameOne', 'frameTwo'}
		});

		// Execute
		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(new List<CTRL_Logger.DTO_ClientLogEntry> {entry}));
		Test.stopTest();

		// Verify
		LogEntry__c row = new SEL_LogEntry().findByMethod(LOG_Engine.OperationType.LWC.name() + '/StructuredStack');
		Assert.isNotNull(row, 'The entry should persist');
		Assert.isTrue(row.ContextData__c.contains('frameOne'), 'An unpromotable errorStack value must stay in the persisted context');
		Assert.isFalse(row.StackTrace__c?.contains('frameOne') ?? false, 'An unpromotable value must not be promoted into the stack trace');
	}

	/**
	 * @description Tests that an LWC entry without a client stack persists a synthetic Apex trace free of
	 * logging-framework plumbing frames (builder, engine, LWC bridge), leaving only genuine caller frames.
	 * In a subscriber org the platform masks every managed-code frame to '(kern)', so no matchable frame
	 * survives the strip and the contract becomes: persist no stack at all rather than masked noise.
	 */
	@IsTest
	private static void shouldStripFrameworkFramesFromSyntheticStack()
	{
		// Setup
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		CTRL_Logger.DTO_ClientLogEntry entry = createEntry(LoggingLevel.INFO, 'No client stack', 'frame-strip-test');
		entry.context = JSON.serialize(new Map<String, Object> {LOG_Engine.CONTEXT_ACTION_NAME => 'FrameStrip'});

		// Execute
		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(new List<CTRL_Logger.DTO_ClientLogEntry> {entry}));
		Test.stopTest();

		// Verify
		LogEntry__c row = new SEL_LogEntry().findByMethod(LOG_Engine.OperationType.LWC.name() + '/FrameStrip');
		Assert.isNotNull(row, 'The entry should persist');

		Boolean managedFramesVisible = new DmlException().getStackTraceString().contains(CTRL_Logger_TEST.class.getName() + '.');

		if(managedFramesVisible)
		{
			Assert.isTrue(row.StackTrace__c.contains(CTRL_Logger_TEST.class.getName() + '.'), 'The genuine caller frame should survive the strip');
			Assert.isFalse(row.StackTrace__c.contains(CTRL_Logger.class.getName() + '.'), 'LWC-bridge frames are logging plumbing and should be stripped');
			Assert.isFalse(row.StackTrace__c.contains(LOG_Engine.class.getName() + '.'), 'Engine frames are logging plumbing and should be stripped');
		}
		else
		{
			Assert.isNull(row.StackTrace__c, 'With every managed frame masked, the strip should persist no stack rather than masked noise');
		}
	}
}