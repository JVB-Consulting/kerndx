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
 * @date December 2025, September 2026
 */
@IsTest(seeAllData=false isParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class CTRL_Logger_TEST
{
	/**
	 * @description A representative client-side JavaScript error stack as captured by the LWC logger.
	 */
	private static final String CLIENT_STACK = 'Error: boom\n    at submitOrder (c/orderPanel.js:42:13)';

	/**
	 * @description The LWC bundle a client entry reports itself as coming from.
	 */
	private static final String COMPONENT_NAME = 'orderPanel';

	/**
	 * @description The action a client entry reports itself as performing.
	 */
	private static final String ACTION_NAME = 'submitOrder';

	/**
	 * @description The server message an Aura failure relays from a failed Apex call.
	 */
	private static final String APEX_FAILURE_MESSAGE = 'Too many apex pagination cursor rows: 100001';

	/**
	 * @description The Apex exception class an Aura failure reports alongside its message.
	 */
	private static final String APEX_EXCEPTION_TYPE = 'System.LimitException';

	/**
	 * @description Correlation scoping the grouping test's entries and its problems read, so entries the
	 * org's own automation logs during the same transaction cannot enter the fold the test measures.
	 */
	private static final String GROUPING_TEST_CORRELATION = 'grouping-test';

	/**
	 * @description The leading segment of a deliberately over-length exception type, long enough that a
	 * value cut to the field length still proves the most identifying part of the name survived.
	 */
	private static final String LONG_EXCEPTION_TYPE_PREFIX = 'System.QueryLocatorIteratorException';

	/**
	 * @description Client context that is not JSON, used to make one entry of a batch fail while the
	 * bridge is reading it.
	 */
	private static final String MALFORMED_CONTEXT_JSON = '{not valid json';

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
	 * @description Tests that the operation context the bridge pushes is popped even when an entry in the
	 * batch cannot be read. The second entry carries context that is not JSON, so the call gives up part
	 * way through the loop. Afterwards the engine's context stack must stand exactly where it stood before
	 * the call, or every later entry in the same transaction would be stamped with a context the bridge had
	 * already finished with.
	 */
	@IsTest
	private static void shouldPopTheOperationContextWhenAnEntryCannotBeRead()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		CTRL_Logger.DTO_ClientLogEntry readable = createEntry(LoggingLevel.INFO, 'the first entry reads cleanly', 'context-pop-test');
		CTRL_Logger.DTO_ClientLogEntry unreadable = createEntry(LoggingLevel.INFO, 'the second entry does not', 'context-pop-test');
		unreadable.context = MALFORMED_CONTEXT_JSON;

		Integer depthBeforeTheCall = LOG_Engine.getContextStackDepth();

		Test.startTest();
		try
		{
			CTRL_Logger.persistLogs(JSON.serialize(new List<CTRL_Logger.DTO_ClientLogEntry> {readable, unreadable}));
			Assert.fail('An entry whose context is not JSON must still fail the call');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, JSONException.class, 'The failure to read the entry must reach the caller unchanged');
		}
		Test.stopTest();

		Assert.areEqual(depthBeforeTheCall, LOG_Engine.getContextStackDepth(),
				'The operation context the bridge pushed must be popped even when an entry in the batch throws');
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
		Assert.isNotNull(new SEL_LogEntry().findByMethod(LOG_Engine.OperationType.LWC.name() + '/SaveAccount'), 'An entry naming only an action should be labelled with it');
	}

	/**
	 * @description Tests that a client entry naming the component it came from is labelled with that
	 * component instead of the unnamed-source stand-in, so an administrator reading the log can tell
	 * which component failed, and that the promoted name is not duplicated into the persisted context.
	 * The same payload carries an exception type, which lands on the entry's type field rather than
	 * staying a context key, so the labelled entry is also a typed one.
	 */
	@IsTest
	private static void shouldNameTheComponentInTheClassMethod()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		CTRL_Logger.DTO_ClientLogEntry entry = createEntry(LoggingLevel.ERROR, 'callControllerMethod: ' + APEX_FAILURE_MESSAGE, 'component-name-test');
		entry.context = JSON.serialize(new Map<String, Object>
		{
				CTRL_Logger.CONTEXT_COMPONENT_NAME => COMPONENT_NAME,
				LOG_Engine.CONTEXT_ERROR_STACK => CLIENT_STACK,
				LOG_Engine.CONTEXT_ERROR_MESSAGE => APEX_FAILURE_MESSAGE,
				LOG_Engine.CONTEXT_EXCEPTION_TYPE => APEX_EXCEPTION_TYPE
		});

		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(new List<CTRL_Logger.DTO_ClientLogEntry> {entry}));
		Test.stopTest();

		LogEntry__c row = new SEL_LogEntry().findByMethod(LOG_Engine.OperationType.LWC.name() + '/' + COMPONENT_NAME);
		Assert.isNotNull(row, 'The entry should be labelled with the component that produced it');
		Assert.areEqual('callControllerMethod: ' + APEX_FAILURE_MESSAGE, row.Message__c, 'The failure text should persist as the entry message');
		Assert.areEqual(CLIENT_STACK, row.StackTrace__c, 'The client JavaScript stack should persist as the stack trace');
		Assert.areEqual(APEX_EXCEPTION_TYPE, row.ExceptionType__c, 'The Apex exception type should persist as the entry exception type');
		Assert.isFalse(row.ContextData__c.contains(CTRL_Logger.CONTEXT_COMPONENT_NAME), 'The component name is promoted into the label, not duplicated in context');
	}

	/**
	 * @description Tests that a client entry naming both a component and an action is labelled with
	 * both, so an entry logged inside a named operation still reads as component-then-action.
	 */
	@IsTest
	private static void shouldCombineComponentAndActionInTheClassMethod()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		CTRL_Logger.DTO_ClientLogEntry entry = createEntry(LoggingLevel.ERROR, 'Submit failed', 'component-action-test');
		entry.context = JSON.serialize(new Map<String, Object>
		{
				CTRL_Logger.CONTEXT_COMPONENT_NAME => COMPONENT_NAME,
				LOG_Engine.CONTEXT_ACTION_NAME => ACTION_NAME
		});

		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(new List<CTRL_Logger.DTO_ClientLogEntry> {entry}));
		Test.stopTest();

		LogEntry__c row = new SEL_LogEntry().findByMethod(LOG_Engine.OperationType.LWC.name() + '/' + COMPONENT_NAME + '.' + ACTION_NAME);
		Assert.isNotNull(row, 'The entry should be labelled with the component and the action');
		Assert.isFalse(row.ContextData__c?.contains(LOG_Engine.CONTEXT_ACTION_NAME) ?? false, 'Both promoted names belong in the label, not in the context');
	}

	/**
	 * @description A client entry is stamped Component and names its component as the source, action dropped.
	 */
	@IsTest
	private static void shouldStampComponentOriginWithTheComponentAsSource()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		CTRL_Logger.DTO_ClientLogEntry entry = createEntry(LoggingLevel.INFO, UTIL_Random.randomDescription(), UTIL_Random.randomName());
		entry.context = JSON.serialize(new Map<String, Object>
		{
				CTRL_Logger.CONTEXT_COMPONENT_NAME => COMPONENT_NAME,
				LOG_Engine.CONTEXT_ACTION_NAME => ACTION_NAME
		});

		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(new List<CTRL_Logger.DTO_ClientLogEntry> {entry}));
		Test.stopTest();

		LogEntry__c row = new SEL_LogEntry().findByMethod(LOG_Engine.COMPONENT_SOURCE_PREFIX + COMPONENT_NAME + UTIL_String.DOT + ACTION_NAME);
		Assert.isNotNull(row, 'The entry was written under the component label');
		Assert.areEqual(LOG_Engine.Origin.COMPONENT.name(), row.Origin__c, 'A component wrote this line');
		Assert.areEqual(COMPONENT_NAME, row.Source__c, 'The source is the component, not the action');
	}

	/**
	 * @description Tests that a component name the client sent as something other than text cannot be
	 * promoted into the label and stays in the persisted context, so no client payload is lost and the
	 * label falls back to the unnamed-source stand-in.
	 */
	@IsTest
	private static void shouldKeepUnusableComponentNameInContext()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		CTRL_Logger.DTO_ClientLogEntry entry = createEntry(LoggingLevel.ERROR, 'Structured component name', 'unusable-component-test');
		entry.context = JSON.serialize(new Map<String, Object>
		{
				CTRL_Logger.CONTEXT_COMPONENT_NAME => new Map<String, String> {'bundle' => COMPONENT_NAME}
		});

		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(new List<CTRL_Logger.DTO_ClientLogEntry> {entry}));
		Test.stopTest();

		LogEntry__c row = new SEL_LogEntry().findByMethod(LOG_Engine.OperationType.LWC.name() + '/' + CTRL_Logger.UNKNOWN_SOURCE);
		Assert.isNotNull(row, 'An entry naming nothing usable should fall back to the unnamed-source label');
		Assert.isTrue(row.ContextData__c.contains(CTRL_Logger.CONTEXT_COMPONENT_NAME), 'An unpromotable component name must stay in the persisted context');
	}

	/**
	 * @description Tests that an action name the client sent as something other than text costs nothing:
	 * the entry falls back to the unnamed-source label and keeps the value in its context, and the rest
	 * of the batch still persists — reading such a value as text used to throw and take every entry in
	 * the same call down with it.
	 */
	@IsTest
	private static void shouldKeepUnusableActionNameInContext()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		CTRL_Logger.DTO_ClientLogEntry structuredActionEntry = createEntry(LoggingLevel.ERROR, 'Structured action name', 'unusable-action-test');
		structuredActionEntry.context = JSON.serialize(new Map<String, Object>
		{
				LOG_Engine.CONTEXT_ACTION_NAME => new List<String> {ACTION_NAME}
		});
		CTRL_Logger.DTO_ClientLogEntry healthyEntry = createEntry(LoggingLevel.ERROR, 'Well-formed sibling', 'unusable-action-test');
		healthyEntry.context = JSON.serialize(new Map<String, Object> {CTRL_Logger.CONTEXT_COMPONENT_NAME => COMPONENT_NAME});

		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(new List<CTRL_Logger.DTO_ClientLogEntry> {structuredActionEntry, healthyEntry}));
		Test.stopTest();

		LogEntry__c row = new SEL_LogEntry().findByMethod(LOG_Engine.OperationType.LWC.name() + '/' + CTRL_Logger.UNKNOWN_SOURCE);
		Assert.isNotNull(row, 'An entry whose action name is not text should fall back to the unnamed-source label');
		Assert.isTrue(row.ContextData__c.contains(ACTION_NAME), 'An unpromotable action name must stay in the persisted context');

		LogEntry__c siblingRow = new SEL_LogEntry().findByMethod(LOG_Engine.OperationType.LWC.name() + '/' + COMPONENT_NAME);
		Assert.isNotNull(siblingRow, 'One unreadable name must not cost the other entries in the same batch');
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
	 * @description Tests that the Apex exception class a failed controller call reported reaches the entry's
	 * own exception type instead of sitting in the context payload, so the console drawer names the failure
	 * and problem grouping can key on it, and that the type does not leak onto a following entry that
	 * reported none.
	 */
	@IsTest
	private static void shouldPromoteClientExceptionTypeAndNotLeakItOntoTheNextEntry()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		CTRL_Logger.DTO_ClientLogEntry failureEntry = createEntry(LoggingLevel.ERROR, APEX_FAILURE_MESSAGE, 'exception-type-test');
		failureEntry.context = JSON.serialize(new Map<String, Object>
		{
				LOG_Engine.CONTEXT_ACTION_NAME => 'PromoteType',
				LOG_Engine.CONTEXT_EXCEPTION_TYPE => APEX_EXCEPTION_TYPE,
				LOG_Engine.CONTEXT_ERROR_MESSAGE => APEX_FAILURE_MESSAGE
		});
		CTRL_Logger.DTO_ClientLogEntry plainEntry = createEntry(LoggingLevel.INFO, 'Follow-up entry', 'exception-type-test');
		plainEntry.context = JSON.serialize(new Map<String, Object> {LOG_Engine.CONTEXT_ACTION_NAME => 'NoType'});

		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(new List<CTRL_Logger.DTO_ClientLogEntry> {failureEntry, plainEntry}));
		Test.stopTest();

		LogEntry__c failureRow = new SEL_LogEntry().findByMethod(LOG_Engine.OperationType.LWC.name() + '/PromoteType');
		Assert.isNotNull(failureRow, 'The failure entry should persist');
		Assert.areEqual(APEX_EXCEPTION_TYPE, failureRow.ExceptionType__c, 'The client exception type should persist as the entry exception type');
		Assert.isFalse(failureRow.ContextData__c.contains(LOG_Engine.CONTEXT_EXCEPTION_TYPE), 'A promoted exception type belongs in its own field, not duplicated in context');
		Assert.isTrue(failureRow.ContextData__c.contains(LOG_Engine.CONTEXT_ERROR_MESSAGE), 'The remaining client context keys should still persist');

		LogEntry__c plainRow = new SEL_LogEntry().findByMethod(LOG_Engine.OperationType.LWC.name() + '/NoType');
		Assert.isNotNull(plainRow, 'The follow-up entry should persist');
		Assert.isNull(plainRow.ExceptionType__c, 'The exception type must not leak onto entries that reported none');
	}

	/**
	 * @description Tests that a client exception type sent as something other than text is kept in the
	 * persisted context instead of being dropped, so no client payload is lost when it cannot be promoted.
	 */
	@IsTest
	private static void shouldKeepUnpromotableExceptionTypeInContext()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		CTRL_Logger.DTO_ClientLogEntry entry = createEntry(LoggingLevel.ERROR, 'Structured exception type', 'unpromotable-type-test');
		entry.context = JSON.serialize(new Map<String, Object>
		{
				LOG_Engine.CONTEXT_ACTION_NAME => 'StructuredType',
				LOG_Engine.CONTEXT_EXCEPTION_TYPE => new List<String> {APEX_EXCEPTION_TYPE}
		});

		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(new List<CTRL_Logger.DTO_ClientLogEntry> {entry}));
		Test.stopTest();

		LogEntry__c row = new SEL_LogEntry().findByMethod(LOG_Engine.OperationType.LWC.name() + '/StructuredType');
		Assert.isNotNull(row, 'The entry should persist');
		Assert.isTrue(row.ContextData__c.contains(APEX_EXCEPTION_TYPE), 'An unpromotable exception type must stay in the persisted context');
		Assert.isNull(row.ExceptionType__c, 'An unpromotable value must not be promoted into the exception type');
	}

	/**
	 * @description Tests that an exception type longer than the field it lands in is cut to fit, so the
	 * entry that carried it still persists and still names the most identifying part of the type.
	 */
	@IsTest
	private static void shouldCutAnOverlongClientExceptionTypeToTheFieldLength()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Integer fieldLength = LogEntry__c.ExceptionType__c.getDescribe().length;
		String overlongType = LONG_EXCEPTION_TYPE_PREFIX + 'X'.repeat(fieldLength);
		CTRL_Logger.DTO_ClientLogEntry entry = createEntry(LoggingLevel.ERROR, 'Overlong exception type', 'overlong-type-test');
		entry.context = JSON.serialize(new Map<String, Object>
		{
				LOG_Engine.CONTEXT_ACTION_NAME => 'OverlongType',
				LOG_Engine.CONTEXT_EXCEPTION_TYPE => overlongType
		});

		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(new List<CTRL_Logger.DTO_ClientLogEntry> {entry}));
		Test.stopTest();

		LogEntry__c row = new SEL_LogEntry().findByMethod(LOG_Engine.OperationType.LWC.name() + '/OverlongType');
		Assert.isNotNull(row, 'An over-length exception type must not cost the entry that carried it');
		Assert.areEqual(fieldLength, row.ExceptionType__c.length(), 'The exception type should be cut to the field length');
		Assert.isTrue(row.ExceptionType__c.startsWith(LONG_EXCEPTION_TYPE_PREFIX), 'The most identifying part of the type should survive the cut');
	}

	/**
	 * @description Tests that client entries sharing an exception type fold into one problem in the console's
	 * Problems view, counted together. Problem grouping keys on the exception type, so a client failure that
	 * carries none cannot join the failures it repeats — the promotion is what puts it in the right group.
	 * The problems read is scoped to this test's correlation, and the selection matches on the full
	 * identity (exception type AND class method): an org's own automation can log entries in the same
	 * transaction (a permission-gated trigger action skipping, for one), and in test context that
	 * entry can even inherit this test's type and correlation from the emit's open per-emit channels,
	 * so only the class-method half of the identity reliably tells the seeded problem apart.
	 */
	@IsTest
	private static void shouldGroupClientEntriesByTheirPromotedExceptionType()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		List<CTRL_Logger.DTO_ClientLogEntry> entries = new List<CTRL_Logger.DTO_ClientLogEntry>();
		for(Integer occurrence = 0; occurrence < 2; occurrence++)
		{
			CTRL_Logger.DTO_ClientLogEntry entry = createEntry(LoggingLevel.ERROR, APEX_FAILURE_MESSAGE, GROUPING_TEST_CORRELATION);
			entry.context = JSON.serialize(new Map<String, Object>
			{
					CTRL_Logger.CONTEXT_COMPONENT_NAME => COMPONENT_NAME,
					LOG_Engine.CONTEXT_ACTION_NAME => ACTION_NAME,
					LOG_Engine.CONTEXT_EXCEPTION_TYPE => APEX_EXCEPTION_TYPE
			});
			entries.add(entry);
		}

		Test.startTest();
		CTRL_Logger.persistLogs(JSON.serialize(entries));
		Test.stopTest();

		String expectedClassMethod = LOG_Engine.OperationType.LWC.name() + '/' + COMPONENT_NAME + '.' + ACTION_NAME;
		CTRL_LogConsole.DTO_LogProblemPage page = CTRL_LogConsole.getLogProblems(JSON.serialize(new Map<String, Object> {'correlationId' => GROUPING_TEST_CORRELATION}));
		CTRL_LogConsole.DTO_LogProblem grouped = null;
		for(CTRL_LogConsole.DTO_LogProblem problem : page.records)
		{
			if(APEX_EXCEPTION_TYPE.equals(problem.exceptionType) && expectedClassMethod.equals(problem.classMethod))
			{
				grouped = problem;
			}
		}

		Assert.isNotNull(grouped, 'The client failures should fold into a problem carrying their exception type');
		Assert.areEqual(2, grouped.occurrenceCount, 'Both occurrences of the same client failure should count towards one problem');
		Assert.areEqual(expectedClassMethod, grouped.classMethod, 'The problem should name the component and action that failed');
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