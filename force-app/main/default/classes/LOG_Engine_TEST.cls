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
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssTypeCount,PMD.NcssCount')
@IsTest(seeAllData=false isParallel=false)
private class LOG_Engine_TEST
{
	/**
	 * @description The largest number of immediate event publishes the platform allows in one transaction. The DML limit
	 * test publishes this many log events and expects at least this many log records to be saved.
	 */
	private static final Integer IMMEDIATE_PUBLISH_LIMIT = UTIL_Limits.publishImmediateDml().maximum();

	/**
	 * @description A made-up class and method name the tests log under. The tests then find the saved log record by
	 * this name.
	 */
	private static final String CLASS_METHOD = 'Foobar/method';

	/**
	 * @description The class and method name the test factory logs under when it publishes log events, used to find
	 * the records those events produced.
	 */
	private static final String CLASS_METHOD_PUBLISH = TST_Factory.class.getName() + '/publishLogEvents';

	/**
	 * @description Random text the tests log as the message, so a saved log record can be checked against the exact
	 * text that was sent.
	 */
	private static final String MESSAGE = UTIL_Random.randomName();

	/**
	 * @description A correlation a child job continues under, distinct from the action's.
	 */
	private static final String CHILD_CORRELATION_ID = 'child-run-correlation';

	/**
	 * @description A run's own correlation, chosen by the framework for a context document.
	 */
	private static final String RUN_CORRELATION_ID = 'run-correlation-456';

	/**
	 * @description A context document written before roots existed: a correlation and nothing else.
	 */
	private static final String LEGACY_DOCUMENT = '{"correlationId":"legacy-correlation-123"}';

	/**
	 * @description The correlation the legacy document carries.
	 */
	private static final String LEGACY_CORRELATION_ID = 'legacy-correlation-123';

	/**
	 * @description An exception type relayed by a client entry, the way a browser failure names its own class.
	 */
	private static final String RELAYED_EXCEPTION_TYPE = 'RelayedClientException';

	/**
	 * @description A stack trace relayed by a client entry, the way a browser failure carries its own JavaScript stack.
	 */
	private static final String RELAYED_STACK_TRACE = 'Class.RelayedClient.submit: line 1, column 1';

	/**
	 * @description The action class that saves log events as log records. The mocked log-event trigger setting runs it first.
	 */
	private static final String PERSIST_ACTION_CLASS = TRG_PersistLogEntry.class.getName();

	/**
	 * @description The full name of the test action that writes one log entry while the log events are delivered.
	 * The trigger framework creates the action from this name.
	 */
	private static final String NESTED_ENTRY_ACTION_CLASS = NestedEntryWriter.class.getName();

	/**
	 * @description The developer name of the mocked trigger action row for the test action.
	 */
	private static final String NESTED_ENTRY_ACTION_NAME = 'NestedEntryWriterForTheDeliveryTest';

	/**
	 * @description The order of the test action, so it runs after the persist action.
	 */
	private static final Integer NESTED_ENTRY_ACTION_ORDER = 2;

	/**
	 * @description The class and method name the test action logs under, so the test can find the entry it wrote.
	 */
	private static final String NESTED_ENTRY_CLASS_METHOD = 'NestedEntryWriter/afterInsert';

	/**
	 * @description Set to true once the test action has written its entry, so it writes only one in the transaction.
	 */
	private static Boolean hasWrittenNestedEntry = false;

	/**
	 * @description The JSON field name of a context document's correlation id.
	 */
	private static final String DOCUMENT_CORRELATION_FIELD = 'correlationId';

	/**
	 * @description The JSON field name of a context document's root correlation id.
	 */
	private static final String DOCUMENT_ROOT_FIELD = 'rootCorrelationId';

	/**
	 * @description The JSON field name of a context document's parent transaction id.
	 */
	private static final String DOCUMENT_PARENT_FIELD = 'parentTransactionId';

	/**
	 * @description The JSON field name of a context document's context values.
	 */
	private static final String DOCUMENT_CONTEXT_FIELD = 'contextData';

	/**
	 * @description The key of a context value set on the live transaction, expected to travel with every document.
	 */
	private static final String CONTEXT_KEY = 'liveKey';

	/**
	 * @description The value under CONTEXT_KEY.
	 */
	private static final String CONTEXT_VALUE = 'liveValue';

	/**
	 * @description An empty correlation id, as a caller's setCorrelationId('') leaves it: no correlation at all.
	 */
	private static final String BLANK_CORRELATION_ID = '';

	/**
	 * @description A context document whose correlation is an empty string and which carries no root.
	 */
	private static final String BLANK_CORRELATION_DOCUMENT = '{"correlationId":""}';

	/**
	 * @description An email value the platform refuses with INVALID_EMAIL_ADDRESS.
	 */
	private static final String INVALID_EMAIL = 'not-a-valid-email';

	/**
	 * @description Opening of a refused DML result built from JSON, up to the refused row's Id. The platform
	 * hands out a refused delete, undelete or upsert result only from a real refusal, so the test builds one.
	 */
	private static final String REFUSED_ROW_JSON_HEAD = '{"success":false,"id":"';

	/**
	 * @description Closing of a refused DML result built from JSON: a validation error, so the row reads as
	 * refused rather than locked.
	 */
	private static final String REFUSED_ROW_JSON_TAIL = '","errors":[{"statusCode":"FIELD_CUSTOM_VALIDATION_EXCEPTION","message":"refused by a validation rule","fields":[]}]}';

	/**
	 * @description Assertion message for the refused row Id each logged entry must carry.
	 */
	private static final String MESSAGE_REFUSED_ROW_IDS = 'Each entry should carry the Id of its own refused row, whatever the result type';

	/**
	 * @description The caller's own summary of a failure, logged beside the exception that caused it.
	 */
	private static final String FAILURE_SUMMARY = 'Order total could not be calculated';

	/**
	 * @description The details of a timed operation, logged as a performance entry's message.
	 */
	private static final String PERFORMANCE_DETAILS = 'Recalculated the order lines';

	/**
	 * @description The duration of a timed operation, in milliseconds.
	 */
	private static final Long PERFORMANCE_DURATION_MILLISECONDS = 42;

	/**
	 * @description A parent transaction id an asynchronous job is told it continues from.
	 */
	private static final String PARENT_TRANSACTION_ID = 'parent-transaction-789';

	/**
	 * @description The key of a decimal context value.
	 */
	private static final String AMOUNT_CONTEXT_KEY = 'orderAmount';

	/**
	 * @description A decimal context value, one of the plain values the engine stores as text.
	 */
	private static final Decimal AMOUNT_CONTEXT_VALUE = 12.5;

	/**
	 * @description The text the engine stores for AMOUNT_CONTEXT_VALUE.
	 */
	private static final String AMOUNT_CONTEXT_TEXT = '12.5';

	/**
	 * @description The key of a map context value, which the engine stores as JSON.
	 */
	private static final String MAP_CONTEXT_KEY = 'orderLine';

	/**
	 * @description The JSON the engine stores for the map context value.
	 */
	private static final String MAP_CONTEXT_JSON = '{"sku":"ABC-1"}';

	/**
	 * @description The key of a context value that cannot be serialised to JSON.
	 */
	private static final String REQUEST_CONTEXT_KEY = 'outboundRequest';

	/**
	 * @description The endpoint of the request stored as a context value.
	 */
	private static final String REQUEST_ENDPOINT = 'https://callout.example.com/orders';

	/**
	 * @description An HTTP status a callout reports with no webservice context set before it.
	 */
	private static final String GATEWAY_TIMEOUT_STATUS = '504';

	/**
	 * @description The number of buffered entries at which the engine flushes its buffer on its own.
	 */
	private static final Integer MAXIMUM_BUFFER_SIZE = 500;

	/**
	 * @description Failure message for checks on how many log records or entries were found.
	 */
	private static final String MSG_CORRECT_SIZE = 'Incorrect number of items';

	/**
	 * @description Failure message for checks that the logger accepts an entry, for example when the class filter or
	 * the level threshold lets it through.
	 */
	private static final String MSG_LOGGING_ALLOWED = 'Logging should be allowed';

	/**
	 * @description Failure message for checks that the logger turns an entry away because the class filter does not
	 * match it.
	 */
	private static final String MSG_LOGGING_NOT_ALLOWED = 'Logging should not be allowed';

	/**
	 * @description Failure message for checks that a log record the test expects was saved.
	 */
	private static final String MSG_NOT_EMPTY = 'Log records should be present';

	/**
	 * @description Failure message for checks that a call finished normally and left the expected value behind,
	 * instead of failing with an exception.
	 */
	private static final String MSG_NO_EXCEPTION = 'No exception should be thrown';

	/**
	 * @description Failure message for checks that nothing was saved, because logging is switched off or the entries are
	 * below the level the settings allow.
	 */
	private static final String MSG_NO_LOGS = 'No log records should be created';

	/**
	 * @description Failure message for the check that exactly one queueable job was started.
	 */
	private static final String MSG_QUEUEABLE_JOB = 'One queueable job should be enqueued';

	/**
	 * @description Failure message for checks that a field on a saved log record holds the value the test sent.
	 */
	private static final String MSG_VALUE_EQUALITY = 'Value should match expected';

	/**
	 * @description Failure message for checks that a saved log record names the type of the exception that was logged.
	 */
	private static final String MSG_WRONG_TYPE = 'Incorrect exception type';

	/**
	 * @description Company name given to the admin user created in test setup. It is unique to this class, so getTestAdmin
	 * can find that one user again by company name.
	 */
	private static final String TEST_ADMIN_COMPANY = 'LOG_Engine_TEST-admin';

	/**
	 * @description Company name given to the user created in test setup on the Minimum Access profile, the user a test
	 * runs as to log with very few permissions. It is unique to this class, so getLowPrivilegeUser can find that one user
	 * again by company name.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'LOG_Engine_TEST-low-privilege';

	/**
	 * @description A made-up class and method name the low-privilege user logs under. The test then finds the saved
	 * log record by this name.
	 */
	private static final String TIER_A_CLASS_METHOD = 'LowPrivilegeEmitter.emit';

	/**
	 * @description The message the low-privilege user logs. The test checks the saved log record carries this text.
	 */
	private static final String TIER_A_MESSAGE = 'low-privilege-emission';

	/**
	 * @description DeveloperName of the masking rule that cannot compile and is set to block DML.
	 */
	private static final String BLOCKING_RULE_NAME = 'BlockingRuleForTheLoggerTests';

	/**
	 * @description A regular expression the platform cannot compile, so the rule fails whenever it runs.
	 */
	private static final String INVALID_PATTERN = '([bad';

	/**
	 * @description The replacement the failing rule would have written had it compiled.
	 */
	private static final String MASK_REPLACEMENT = 'X';

	/**
	 * @description The execution order of the failing masking rule.
	 */
	private static final Decimal BLOCKING_RULE_ORDER = 10;

	/**
	 * @description The message of the entry the blocking masking rule must stop from being published.
	 */
	private static final String BLOCKED_MESSAGE = 'This entry must be dropped, never published unmasked';

	/**
	 * @description The class method the blocked entry is emitted under, so the drop can be asserted by lookup.
	 */
	private static final String BLOCKED_CLASS_METHOD = 'LOG_Engine_TEST/emitDropsAnEntryAMaskingRuleBlocks';

	/**
	 * @description Assertion message for a blocked entry that must never reach the log entry table.
	 */
	private static final String MESSAGE_ENTRY_DROPPED = 'The blocked entry must not be persisted';

	/**
	 * @description A made-up identity number the hydration tests store in an unreadable context. A masking rule matches
	 * it, so it must never appear as written in the hydration failure text.
	 */
	private static final String SENSITIVE_VALUE = '123-45-6789';

	/**
	 * @description The pattern of the masking rule that matches the sensitive value.
	 */
	private static final String SENSITIVE_VALUE_PATTERN = '\\d{3}-\\d{2}-\\d{4}';

	/**
	 * @description What the masking rule writes in place of the sensitive value.
	 */
	private static final String SENSITIVE_VALUE_MASK = '***-**-****';

	/**
	 * @description DeveloperName of the masking rule that matches the sensitive value.
	 */
	private static final String SENSITIVE_VALUE_RULE_NAME = 'SensitiveValueRuleForTheLoggerTests';

	/**
	 * @description A stored context that cannot be read back (the JSON is cut short) and that holds the sensitive value.
	 */
	private static final String UNREADABLE_CONTEXT_WITH_SENSITIVE_VALUE = '{"correlationId":"abc","contextData":{"identity":"' + SENSITIVE_VALUE + '"';

	/**
	 * @description The message of the error the hydration tests hand to the failure text.
	 */
	private static final String HYDRATION_ERROR_MESSAGE = 'Unexpected end of input';

	/**
	 * @description The class method the entry deflected onto the batch route is emitted under, so it can be found by lookup.
	 */
	private static final String DEFLECTED_CLASS_METHOD = 'LOG_Engine_TEST/publishesThroughTheBatchRoute';

	/**
	 * @description The message of the entry the batch route carries once the queueable budget is spent.
	 */
	private static final String DEFLECTED_MESSAGE = 'This entry is carried by the batch route';

	/**
	 * @description Assertion message for the queueable budget the logger must not spend once it is exhausted.
	 */
	private static final String MESSAGE_NO_JOB_ENQUEUED = 'No further job may be enqueued once the queueable budget is spent';

	/**
	 * @description Assertion message for the entry the batch route must still publish.
	 */
	private static final String MESSAGE_ENTRY_PUBLISHED = 'The entry must still be published through the batch route';

	/**
	 * @description The package namespace prefix a managed install carries on every framework class name.
	 */
	private static final String NAMESPACE_PREFIX = 'kern.';

	/**
	 * @description A framework class-method as a managed install records it: namespace, outer class, inner class, method.
	 */
	private static final String FRAMEWORK_CLASS_METHOD = 'kern.UTIL_AsyncChain.ChainExecutor.execute';

	/**
	 * @description A subscriber class-method: no namespace, class and method.
	 */
	private static final String SUBSCRIBER_CLASS_METHOD = 'AccountTriggerHandler.handleAfterUpdate';

	/**
	 * @description The component bridge's label for a named component and action.
	 */
	private static final String COMPONENT_CLASS_METHOD = 'LWC/orderPanel.submitOrder';

	/**
	 * @description The Flow bridge's label for a named Flow.
	 */
	private static final String FLOW_CLASS_METHOD = 'Flow/Order Intake';

	/**
	 * @description The write-log bridge's default label in a managed install.
	 */
	private static final String WRITE_LOG_CLASS_METHOD = 'kern.FLOW_WriteLog/writeLog';

	/**
	 * @description The Flow bridge's label for a Flow whose own name holds a dot.
	 */
	private static final String DOTTED_FLOW_CLASS_METHOD = 'Flow/Order v1.2';

	/**
	 * @description A Flow class-method with a second slash after the name, a shape no bridge writes today, proving
	 * the name stops at the next slash.
	 */
	private static final String DOTTED_FLOW_STEP_CLASS_METHOD = 'Flow/Order v1.2/Decision';

	/**
	 * @description The whole name of the Flow whose name holds a dot.
	 */
	private static final String DOTTED_FLOW_NAME = 'Order v1.2';

	/**
	 * @description A class-method carrying a namespace Apex can see the class in, standing in for the namespace of an
	 * org that has one of its own.
	 */
	private static final String OWN_NAMESPACE_CLASS_METHOD = 'System.Url.toExternalForm';

	/**
	 * @description The same location with a slash before the method, the form the test bridges write.
	 */
	private static final String OWN_NAMESPACE_CLASS_METHOD_SLASH_FORM = 'System.Url/toExternalForm';

	/**
	 * @description A namespace Apex can see the class in, with no method after the class.
	 */
	private static final String OWN_NAMESPACE_CLASS_ONLY = 'System.Url';

	/**
	 * @description A class-method whose first word is no namespace Apex can see a class in, so the first word stays.
	 */
	private static final String UNKNOWN_NAMESPACE_CLASS_METHOD = 'acme.OrderService.submit';

	/**
	 * @description A measured top frame of the caller-only stack for a method of a top-level class.
	 */
	private static final String TOP_LEVEL_CLASS_FRAME = 'Class.OrderService.submit: line 12, column 1';

	/**
	 * @description A measured top frame for a method of an inner class: the outer class comes before the inner one.
	 */
	private static final String INNER_CLASS_FRAME = 'Class.OrderService.Validator.check: line 34, column 1';

	/**
	 * @description A measured top frame for a trigger, which names the trigger and no method.
	 */
	private static final String TRIGGER_FRAME = 'Trigger.OrderTrigger: line 7, column 1';

	/**
	 * @description A measured top frame for anonymous Apex, which names neither a class nor a method.
	 */
	private static final String ANONYMOUS_BLOCK_FRAME = 'AnonymousBlock: line 1, column 1';

	/**
	 * @description A line that is not a frame at all, as an unreadable stack would leave on top.
	 */
	private static final String UNREADABLE_FRAME = 'external entry point';

	/**
	 * @description The name of this test class, carrying the package namespace where the framework has one.
	 */
	private static final String TEST_CLASS_FULL_NAME = LOG_Engine_TEST.class.getName();

	/**
	 * @description The name of this test class as the log stores a source: without the package namespace.
	 */
	private static final String TEST_CLASS_SOURCE_NAME = TEST_CLASS_FULL_NAME.removeStart(UTIL_System.getManagedPackageNamespacePrefix(UTIL_String.DOT));

	/**
	 * @description The class and method the engine should work out for the emit that gives no `.at()`.
	 */
	private static final String DERIVED_CLASS_METHOD = TEST_CLASS_FULL_NAME + UTIL_String.DOT + 'shouldNameTheCallerWhenAnEntryIsEmittedWithoutAt';

	/**
	 * @description The class and method the engine must not work out for the emit that carries an exception.
	 */
	private static final String EXCEPTION_CLASS_METHOD = TEST_CLASS_FULL_NAME + UTIL_String.DOT + 'shouldLeaveTheClassMethodBlankWhenAnExceptionIsLoggedWithoutAt';

	/**
	 * @description The origin a worked-out class-method gives an entry: the class-method carries the package prefix
	 * when the tests run inside the package, which makes the entry the framework's own rather than plain Apex.
	 */
	private static final String EXPECTED_DERIVED_ORIGIN = String.isBlank(UTIL_System.getManagedPackageNamespacePrefix(UTIL_String.DOT))
			? LOG_Engine.Origin.APEX.name()
			: LOG_Engine.Origin.FRAMEWORK.name();

	/**
	 * @description The number of contexts the engine keeps before it refuses a push.
	 */
	private static final Integer MAXIMUM_CONTEXT_DEPTH = 10;

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
	 * @description A log entry written while another entry is being delivered must not take that entry's exception
	 * type or stack trace. Those values stay open while `Test.getEventBus().deliver()` runs. A test action on the
	 * log-event trigger writes one plain DEBUG entry inside the first entry's delivery. That inner entry must be saved
	 * with neither the first entry's exception type nor its relayed stack trace. Each step of the test is wrapped, so
	 * an error in any step fails the test with the step's name, even in an org that hides the package's own lines in
	 * a stack trace.
	 */
	@IsTest
	private static void nestedEmitDuringDeliveryDoesNotInheritTheOwnerEmitChannels()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;
		try
		{
			registerLogEventTriggerWithNestedEntryAction();
		}
		catch(Exception error)
		{
			failAtStage(NestedEmitStage.REGISTER_TEST_ACTION.name(), error);
		}

		Test.startTest();
		try
		{
			LOG_Builder.build()
					.error(MESSAGE)
					.withExceptionTypeInternal(RELAYED_EXCEPTION_TYPE)
					.withStackTraceInternal(RELAYED_STACK_TRACE)
					.at(CLASS_METHOD)
					.emit();
		}
		catch(Exception error)
		{
			failAtStage(NestedEmitStage.EMIT_FIRST_ENTRY.name(), error);
		}
		try
		{
			Test.stopTest();
		}
		catch(Exception error)
		{
			failAtStage(NestedEmitStage.DELIVER_EVENTS.name(), error);
		}

		try
		{
			LogEntry__c ownerRow = new SEL_LogEntry().findByMethod(CLASS_METHOD);
			Assert.isNotNull(ownerRow, MSG_NOT_EMPTY);
			Assert.areEqual(RELAYED_EXCEPTION_TYPE, ownerRow.ExceptionType__c, MSG_VALUE_EQUALITY);
			Assert.areEqual(RELAYED_STACK_TRACE, ownerRow.StackTrace__c, MSG_VALUE_EQUALITY);
		}
		catch(Exception error)
		{
			failAtStage(NestedEmitStage.READ_FIRST_ENTRY.name(), error);
		}

		try
		{
			List<LogEntry__c> nestedRows = new SEL_LogEntry().findAllByMethod(NESTED_ENTRY_CLASS_METHOD);
			Assert.areEqual(1, nestedRows.size(), 'Expected the test action to save exactly one entry during the delivery');
			LogEntry__c nestedRow = nestedRows[0];
			Assert.isNull(nestedRow.ExceptionType__c, 'Expected an entry written during another entry\'s delivery to carry no exception type');
			// An org that hides the package's own lines saves the nested entry with no stack trace at all
			Assert.isFalse((nestedRow.StackTrace__c ?? UTIL_String.EMPTY).contains(RELAYED_STACK_TRACE),
					'Expected an entry written during another entry\'s delivery not to carry that entry\'s relayed stack trace');
		}
		catch(Exception error)
		{
			failAtStage(NestedEmitStage.READ_NESTED_ENTRY.name(), error);
		}
	}

	/**
	 * @description Fails the test with the name of the step that threw and the error's type, message and line, so a
	 * run in an org that hides the package's own lines in a stack trace still says where the test broke.
	 *
	 * @param stage The name of the step that threw.
	 * @param error The error the step threw.
	 */
	private static void failAtStage(String stage, Exception error)
	{
		Assert.fail('Expected the step ' + stage + ' to finish, but it threw ' + error.getTypeName() + ': ' + error.getMessage()
				+ ' (line ' + error.getLineNumber() + ')');
	}

	/**
	 * @description The origin is the bridge's when a Flow or component context is on top, the framework's when
	 * the class carries the package namespace, and Apex otherwise; a blank namespace never yields Framework.
	 *
	 * @see LOG_Engine.resolveOrigin
	 */
	@IsTest
	private static void shouldResolveOriginFromTheContextThenTheNamespace()
	{
		Assert.areEqual(LOG_Engine.Origin.FLOW, LOG_Engine.resolveOrigin(SUBSCRIBER_CLASS_METHOD, NAMESPACE_PREFIX, LOG_Engine.OperationType.FLOW.name()),
				'A Flow context on top wins over the class name');
		Assert.areEqual(LOG_Engine.Origin.COMPONENT, LOG_Engine.resolveOrigin(COMPONENT_CLASS_METHOD, NAMESPACE_PREFIX, LOG_Engine.OperationType.LWC.name()),
				'A component context on top is Component');
		Assert.areEqual(LOG_Engine.Origin.FLOW, LOG_Engine.resolveOrigin(WRITE_LOG_CLASS_METHOD, NAMESPACE_PREFIX, LOG_Engine.OperationType.FLOW.name()),
				'A Flow context on top wins over the namespace');
		Assert.areEqual(LOG_Engine.Origin.COMPONENT, LOG_Engine.resolveOrigin(FRAMEWORK_CLASS_METHOD, NAMESPACE_PREFIX, LOG_Engine.OperationType.LWC.name()),
				'A component context on top wins over the namespace');
		Assert.areEqual(LOG_Engine.Origin.FRAMEWORK, LOG_Engine.resolveOrigin(FRAMEWORK_CLASS_METHOD, NAMESPACE_PREFIX, null),
				'A namespaced class with no bridge context is the framework');
		Assert.areEqual(LOG_Engine.Origin.FRAMEWORK, LOG_Engine.resolveOrigin(FRAMEWORK_CLASS_METHOD, NAMESPACE_PREFIX, LOG_Engine.OperationType.TRIGGER_ACTION.name()),
				'A framework context that is not a bridge falls through to the namespace check');
		Assert.areEqual(LOG_Engine.Origin.APEX, LOG_Engine.resolveOrigin(SUBSCRIBER_CLASS_METHOD, NAMESPACE_PREFIX, null), 'A class without the namespace is Apex');
		Assert.areEqual(LOG_Engine.Origin.APEX, LOG_Engine.resolveOrigin(SUBSCRIBER_CLASS_METHOD, NAMESPACE_PREFIX, LOG_Engine.OperationType.QUERY.name()),
				'A query context around subscriber code is still Apex');
		Assert.areEqual(LOG_Engine.Origin.APEX, LOG_Engine.resolveOrigin(FRAMEWORK_CLASS_METHOD, UTIL_String.EMPTY, null),
				'In an org with no namespace the framework line is Apex');
		Assert.areEqual(LOG_Engine.Origin.APEX, LOG_Engine.resolveOrigin(null, NAMESPACE_PREFIX, null), 'A blank class-method is Apex, never an exception');
	}

	/**
	 * @description The source is the writer's plain name: the package namespace, a namespace Apex can see the class in
	 * and a bridge prefix are removed, then the text before the first slash or dot is kept.
	 *
	 * @see LOG_Engine.resolveSource
	 */
	@IsTest
	private static void shouldResolveSourceAsTheWritersPlainName()
	{
		Assert.areEqual('UTIL_AsyncChain', LOG_Engine.resolveSource(FRAMEWORK_CLASS_METHOD, NAMESPACE_PREFIX), 'The namespace goes, the outer class stays');
		Assert.areEqual('orderPanel', LOG_Engine.resolveSource(COMPONENT_CLASS_METHOD, NAMESPACE_PREFIX), 'The component prefix goes, the component stays, the action goes');
		Assert.areEqual('unknown', LOG_Engine.resolveSource(LOG_Engine.COMPONENT_SOURCE_PREFIX + 'unknown', NAMESPACE_PREFIX),
				'An unnamed component keeps the bridge\'s placeholder');
		Assert.areEqual('Order Intake', LOG_Engine.resolveSource(FLOW_CLASS_METHOD, NAMESPACE_PREFIX), 'The Flow prefix goes, the Flow name stays');
		Assert.areEqual(DOTTED_FLOW_NAME, LOG_Engine.resolveSource(DOTTED_FLOW_CLASS_METHOD, NAMESPACE_PREFIX), 'A dot is part of a Flow name, so the whole name stays');
		Assert.areEqual(DOTTED_FLOW_NAME, LOG_Engine.resolveSource(DOTTED_FLOW_STEP_CLASS_METHOD, NAMESPACE_PREFIX),
				'A step after the Flow name goes, and the name before it stays whole');
		Assert.areEqual('FLOW_WriteLog', LOG_Engine.resolveSource(WRITE_LOG_CLASS_METHOD, NAMESPACE_PREFIX), 'The write-log default keeps the class');
		Assert.areEqual('AccountTriggerHandler', LOG_Engine.resolveSource(SUBSCRIBER_CLASS_METHOD, NAMESPACE_PREFIX), 'A subscriber class keeps its class');
		Assert.areEqual('MyClass', LOG_Engine.resolveSource('MyClass', NAMESPACE_PREFIX), 'A bare class is itself');
		Assert.areEqual('Url', LOG_Engine.resolveSource(OWN_NAMESPACE_CLASS_METHOD, NAMESPACE_PREFIX), 'A namespace Apex can see the class in goes, the class stays');
		Assert.areEqual('Url', LOG_Engine.resolveSource(OWN_NAMESPACE_CLASS_METHOD_SLASH_FORM, NAMESPACE_PREFIX), 'The slash form loses its namespace the same way');
		Assert.areEqual('Url', LOG_Engine.resolveSource(OWN_NAMESPACE_CLASS_ONLY, NAMESPACE_PREFIX), 'A namespace and a class with no method still lose the namespace');
		Assert.areEqual('acme', LOG_Engine.resolveSource(UNKNOWN_NAMESPACE_CLASS_METHOD, UTIL_String.EMPTY),
				'A first word Apex cannot see as a namespace is kept, as the parser always did');
		Assert.isNull(LOG_Engine.resolveSource(UTIL_String.EMPTY, NAMESPACE_PREFIX), 'A blank class-method has no source');
		Assert.isNull(LOG_Engine.resolveSource(LOG_Engine.FLOW_SOURCE_PREFIX, NAMESPACE_PREFIX), 'A bare prefix has no source');
	}

	/**
	 * @description Through the real path, an emitted entry carries its origin and source, and a Flow context that
	 * was pushed and popped around one emit does not reach the next.
	 *
	 * @see LOG_Engine.Logger.getEvents
	 */
	@IsTest
	private static void shouldStampOriginAndSourceOnEveryEmittedEntry()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;
		String flowClassMethod = LOG_Engine.FLOW_SOURCE_PREFIX + UTIL_Random.randomName();
		String apexClassMethod = UTIL_Random.randomName() + UTIL_String.DOT + UTIL_Random.randomName();

		Test.startTest();
		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.FLOW, new Map<String, String> {LOG_Engine.CONTEXT_SOURCE => LOG_Engine.FLOW_SOURCE_MARKER});
		try
		{
			LOG_Builder.build().info(MESSAGE).at(flowClassMethod).emit();
		}
		finally
		{
			LOG_Engine.popOperationContext();
		}
		LOG_Builder.build().info(MESSAGE).at(apexClassMethod).emit();
		Test.stopTest();

		LogEntry__c flowRow = new SEL_LogEntry().findByMethod(flowClassMethod);
		Assert.isNotNull(flowRow, MSG_NOT_EMPTY);
		Assert.areEqual(LOG_Engine.Origin.FLOW.name(), flowRow.Origin__c, 'An emit inside the Flow context is Flow');
		Assert.areEqual(flowClassMethod.substringAfter(LOG_Engine.SOURCE_PREFIX_DELIMITER), flowRow.Source__c, 'The Flow entry names the Flow');

		LogEntry__c apexRow = new SEL_LogEntry().findByMethod(apexClassMethod);
		Assert.isNotNull(apexRow, MSG_NOT_EMPTY);
		Assert.areEqual(LOG_Engine.Origin.APEX.name(), apexRow.Origin__c, 'An emit after the bridge popped is Apex: the context did not leak');
		Assert.areEqual(apexClassMethod.substringBefore(UTIL_String.DOT), apexRow.Source__c, 'The Apex entry names its class');
	}

	/**
	 * @description Through the real path, an entry written at a location whose first word is a namespace Apex can see
	 * the class in is stored under the class name, and the location itself keeps every word it was given.
	 *
	 * @see LOG_Engine.Logger.getEvents
	 */
	@IsTest
	private static void shouldStoreTheSourceWithoutANamespaceApexCanSee()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();
		LOG_Builder.build().info(MESSAGE).at(OWN_NAMESPACE_CLASS_METHOD).emit();
		Test.stopTest();

		LogEntry__c row = new SEL_LogEntry().findByMethod(OWN_NAMESPACE_CLASS_METHOD);
		Assert.isNotNull(row, MSG_NOT_EMPTY);
		Assert.areEqual('Url', row.Source__c, 'The stored source drops a namespace Apex can see');
		Assert.areEqual(OWN_NAMESPACE_CLASS_METHOD, row.ClassMethod__c, 'The stored location keeps every word it was given');
	}

	/**
	 * @description The class and method come off the top frame of the stack: a top-level class keeps its class and
	 * method, an inner class keeps the outer class before the inner one, a trigger keeps its own name, and anonymous
	 * Apex keeps the name the platform gives it. A stack with no readable frame on top names nobody.
	 *
	 * @see LOG_Engine.resolveClassMethodFromStack
	 */
	@IsTest
	private static void shouldResolveTheClassMethodFromTheTopStackFrame()
	{
		Assert.areEqual('OrderService.submit', LOG_Engine.resolveClassMethodFromStack(TOP_LEVEL_CLASS_FRAME), 'A class frame keeps its class and method');
		Assert.areEqual('OrderService.Validator.check', LOG_Engine.resolveClassMethodFromStack(INNER_CLASS_FRAME),
				'An inner class keeps the outer class before the inner one');
		Assert.areEqual('OrderTrigger', LOG_Engine.resolveClassMethodFromStack(TRIGGER_FRAME), 'A trigger frame keeps the trigger name');
		Assert.areEqual('AnonymousBlock', LOG_Engine.resolveClassMethodFromStack(ANONYMOUS_BLOCK_FRAME), 'Anonymous Apex keeps the name the platform gives it');
		Assert.areEqual('OrderService.submit', LOG_Engine.resolveClassMethodFromStack(TOP_LEVEL_CLASS_FRAME + UTIL_String.LF + INNER_CLASS_FRAME),
				'Only the top frame is read, because the one below it is the caller of the caller');
		Assert.isNull(LOG_Engine.resolveClassMethodFromStack(UNREADABLE_FRAME), 'A line that is not a frame names nobody');
		Assert.isNull(LOG_Engine.resolveClassMethodFromStack(UTIL_String.EMPTY), 'A stack with no frames left names nobody');
		Assert.isNull(LOG_Engine.resolveClassMethodFromStack(null), 'No stack at all names nobody, and never throws');
	}

	/**
	 * @description An entry emitted with no `.at()` takes its class and method from the top frame of the caller-only
	 * stack the engine already builds, and its source and origin follow from that. A class-method the caller gave wins.
	 * When the package is installed in a customer org, the platform hides the package's own lines in a stack trace, so
	 * the stack names no class. There the entry is still saved, with no class-method, no source and the Apex origin.
	 *
	 * @see LOG_Engine.resolveClassMethodFromStack
	 */
	@IsTest
	private static void shouldNameTheCallerWhenAnEntryIsEmittedWithoutAt()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;
		String givenClassMethod = UTIL_Random.randomName() + UTIL_String.DOT + UTIL_Random.randomName();

		Test.startTest();
		LOG_Builder.build().info(MESSAGE).emit();
		LOG_Builder.build().info(MESSAGE).at(givenClassMethod).emit();
		Test.stopTest();

		LogEntry__c givenRow = new SEL_LogEntry().findByMethod(givenClassMethod);
		Assert.isNotNull(givenRow, 'Expected a class-method the caller gave to be kept as it was');

		if(hasMaskedFrames())
		{
			LogEntry__c unnamedRow;
			for(LogEntry__c row : new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_INFO))
			{
				if(row.Id != givenRow.Id)
				{
					unnamedRow = row;
				}
			}
			Assert.isNotNull(unnamedRow, 'Expected the entry emitted without at() to be saved even when the stack names no class');
			Assert.isNull(unnamedRow.ClassMethod__c, 'Expected no class-method when the stack names no class');
			Assert.isNull(unnamedRow.Source__c, 'Expected no source when the stack names no class');
			Assert.areEqual(LOG_Engine.Origin.APEX.name(), unnamedRow.Origin__c, 'Expected the Apex origin when the stack names no class');
			return;
		}

		LogEntry__c derivedRow = new SEL_LogEntry().findByMethod(DERIVED_CLASS_METHOD);
		Assert.isNotNull(derivedRow, 'Expected an entry emitted without at() to name the method that wrote it');
		Assert.areEqual(TEST_CLASS_SOURCE_NAME, derivedRow.Source__c, 'Expected the worked-out class-method to give the entry its source');
		Assert.areEqual(EXPECTED_DERIVED_ORIGIN, derivedRow.Origin__c, 'Expected the worked-out class-method to give the entry its origin');
	}

	/**
	 * @description Says whether this org hides the package's own lines in a stack trace. A customer org that installed
	 * the package shows each of those lines only as the namespace in brackets, so no line names this test class.
	 *
	 * @return True when no line of a fresh stack trace names this test class.
	 */
	private static Boolean hasMaskedFrames()
	{
		return !(new DmlException().getStackTraceString() ?? UTIL_String.EMPTY).contains(TEST_CLASS_FULL_NAME);
	}

	/**
	 * @description An exception carries its own stack, so an entry logged from one keeps no class-method when the
	 * caller gave none: the engine works one out only where it built the caller-only stack itself.
	 *
	 * @see LOG_Engine.Logger.getEvents
	 */
	@IsTest
	private static void shouldLeaveTheClassMethodBlankWhenAnExceptionIsLoggedWithoutAt()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();
		try
		{
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE);
		}
		catch(Exception caught)
		{
			LOG_Builder.build().error(caught).emit();
		}
		Test.stopTest();

		Assert.isFalse(new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR).isEmpty(), MSG_NOT_EMPTY);
		Assert.isNull(new SEL_LogEntry().findByMethod(EXCEPTION_CLASS_METHOD), 'An entry logged from an exception keeps no class-method of its own');
	}

	/**
	 * @description Mocks the log-event trigger's setting with two actions: the real persist action, then the test action
	 * that writes one log entry of its own during the delivery. Neither action uses a feature flag.
	 */
	private static void registerLogEventTriggerWithNestedEntryAction()
	{
		String objectName = TRG_Base.resolveSObjectName(new List<SObject> {new LogEntryEvent__e()}, null);
		TriggerSetting__mdt setting = TST_Factory.newTriggerSetting(objectName, new Map<SObjectField, Object> {TriggerSetting__mdt.ObjectApiNameOverride__c => objectName});
		TriggerAction__mdt persistAction = TST_Factory.newTriggerActionForContext(PERSIST_ACTION_CLASS, setting, TriggerOperation.AFTER_INSERT);
		TriggerAction__mdt nestedEntryAction = TST_Factory.newTriggerActionForContext(NESTED_ENTRY_ACTION_CLASS, setting, TriggerOperation.AFTER_INSERT);

		nestedEntryAction.Order__c = NESTED_ENTRY_ACTION_ORDER;
		nestedEntryAction.DeveloperName = NESTED_ENTRY_ACTION_NAME;
		TST_Mock.register(TriggerSetting__mdt.SObjectType,
				TST_Factory.newTriggerSettingWithActions(setting, new List<TriggerAction__mdt> {persistAction, nestedEntryAction}));
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
	 * @description Verifies that the level-taking overload logs a refused DML row at that level, which is
	 * how a transaction records a refusal the caller declared as expected below ERROR.
	 *
	 * @see LOG_Engine.log
	 */
	@IsTest
	private static void shouldLogDmlOperationResultsAtTheGivenLevel()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;

		Foobar__c refusedRecord = TST_Factory.newFoobarWithEmail(INVALID_EMAIL);
		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
		dmlTransaction.setAllowPartial(true);
		dmlTransaction.setSuppressLogging(true);
		dmlTransaction.doInsert(refusedRecord);
		dmlTransaction.commitWork();

		Test.startTest();

		Boolean hadFailures = LOG_Engine.log(dmlTransaction.getInsertResults(), CLASS_METHOD, LoggingLevel.WARN);

		Test.stopTest();

		Assert.isTrue(hadFailures, 'The refused row should be reported as a failure');
		List<LogEntry__c> warnEntries = new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_WARN);
		Assert.areEqual(1, warnEntries.size(), MSG_CORRECT_SIZE);
		Assert.areEqual(CLASS_METHOD, warnEntries[0].ClassMethod__c, 'The WARN entry should carry the caller');
		Assert.isTrue(new SEL_LogEntry().findByLogLevel(LOG_Engine.LEVEL_ERROR).isEmpty(), 'Nothing should be logged at ERROR');
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

		Assert.areEqual(1, new SEL_LogEntry().findAllByMethod('API_SendEmail/send').size(),
				MSG_CORRECT_SIZE);
		Assert.isTrue(new SEL_LogEntry().findAllByMethod('TST_NoisyJob/run').isEmpty(),
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

		TST_Factory.publishLogEvents(IMMEDIATE_PUBLISH_LIMIT);

		Test.stopTest();

		Integer logCount = new SEL_LogEntry().findAllByMethod(CLASS_METHOD_PUBLISH).size();

		Assert.isTrue(logCount >= IMMEDIATE_PUBLISH_LIMIT, MSG_CORRECT_SIZE + ': Expected: >= ' + IMMEDIATE_PUBLISH_LIMIT + ', Actual: ' + logCount);
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
	 * @description An exception logged with the caller's own summary keeps both: the summary becomes the entry's short
	 * message and the exception's text its message, and the entry still names the exception type and the record.
	 *
	 * @see LOG_Engine.log
	 */
	@IsTest
	@SuppressWarnings('PMD.UnusedLocalVariable,ApexUnusedDeclaration')
	private static void logExceptionWithTheCallersSummary()
	{
		final String recordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		String exceptionMessage;

		setupTestData();
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		try
		{
			Double badNumber = 1 / 0;
		}
		catch(Exception caughtException)
		{
			exceptionMessage = caughtException.getMessage();
			LOG_Engine.log(caughtException, FAILURE_SUMMARY, CLASS_METHOD, recordId, LoggingLevel.ERROR);
		}

		Test.stopTest();

		LogEntry__c retrievedLog = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.areEqual(FAILURE_SUMMARY, retrievedLog.ShortMessage__c, 'The caller\'s summary should be the short message');
		Assert.areEqual(exceptionMessage, retrievedLog.Message__c, 'The exception\'s own text should be the message');
		Assert.areEqual('System.MathException', retrievedLog.ExceptionType__c, MSG_WRONG_TYPE);
		Assert.areEqual(recordId, retrievedLog.RecordId__c, MSG_VALUE_EQUALITY);
	}

	/**
	 * @description A performance entry is written at DEBUG with the operation's name as its short message, the details
	 * as its message and the measured duration in its own field.
	 *
	 * @see LOG_Engine.logPerformance
	 */
	@IsTest
	private static void logPerformanceRecordsTheDuration()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		LOG_Engine.logPerformance(MESSAGE, PERFORMANCE_DETAILS, CLASS_METHOD, PERFORMANCE_DURATION_MILLISECONDS);

		Test.stopTest();

		LogEntry__c retrievedLog = new SEL_LogEntry().findByMethod(CLASS_METHOD);

		Assert.areEqual(PERFORMANCE_DURATION_MILLISECONDS, retrievedLog.DurationMs__c.longValue(), 'The entry should carry the measured duration');
		Assert.areEqual(MESSAGE, retrievedLog.ShortMessage__c, 'The operation name should be the short message');
		Assert.areEqual(PERFORMANCE_DETAILS, retrievedLog.Message__c, 'The details should be the message');
		Assert.areEqual(LOG_Engine.LEVEL_DEBUG, retrievedLog.LogLevel__c, MSG_VALUE_EQUALITY);
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
	 * @description While saving is suspended, and outside an event trigger the framework runs, an ERROR entry does not
	 * wait: it joins the buffer and the whole buffer is written at once, so the entries buffered before it are written
	 * too. Inside an event trigger the framework runs, an ERROR waits for the trigger's own flush instead.
	 *
	 * @see LOG_Engine.suspendSaving
	 * @see LOG_Engine.getBufferSize
	 */
	@IsTest
	private static void errorEntryFlushesTheSuspendedBuffer()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();

		LOG_Engine.suspendSaving();
		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.DEBUG);
		Integer bufferedBeforeError = LOG_Engine.getBufferSize();
		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.ERROR);
		Integer bufferedAfterError = LOG_Engine.getBufferSize();
		LOG_Engine.resumeSaving();

		Test.stopTest();

		Assert.areEqual(1, bufferedBeforeError, 'A DEBUG entry should wait in the buffer while saving is suspended');
		Assert.areEqual(0, bufferedAfterError, 'An ERROR entry should flush the buffer at once');
		Assert.areEqual(2, new SEL_LogEntry().findAllByMethod(CLASS_METHOD).size(), 'Both the buffered entry and the ERROR entry should be written');
	}

	/**
	 * @description The buffer flushes on its own when it reaches its cap, so a long suspended run cannot grow it without
	 * bound, and a publish that fails during that flush never breaks the transaction that logged.
	 *
	 * @see LOG_Engine.suspendSaving
	 * @see LOG_Engine.flushBuffer
	 */
	@IsTest
	private static void fullBufferFlushesOnItsOwnAndSurvivesAFailedPublish()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;
		LOG_Engine.simulatePublishFailure = true;
		List<String> messagesBelowTheCap = new List<String>();
		for(Integer index = 1; index < MAXIMUM_BUFFER_SIZE; index++)
		{
			messagesBelowTheCap.add(MESSAGE + index);
		}

		Test.startTest();

		LOG_Engine.suspendSaving();
		LOG_Engine.log(messagesBelowTheCap, CLASS_METHOD, LoggingLevel.DEBUG);
		Integer bufferedBelowTheCap = LOG_Engine.getBufferSize();
		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.DEBUG);
		Integer bufferedAtTheCap = LOG_Engine.getBufferSize();
		LOG_Engine.resumeSaving();

		Test.stopTest();

		Assert.areEqual(MAXIMUM_BUFFER_SIZE - 1, bufferedBelowTheCap, 'Entries below the cap should wait in the buffer');
		Assert.areEqual(0, bufferedAtTheCap, 'Reaching the cap should flush the buffer, even when the publish fails');
		Assert.isTrue(new SEL_LogEntry().findAllByMethod(CLASS_METHOD).isEmpty(), 'The publish should have failed: a publish that went through would have delivered rows');
	}

	/**
	 * @description An audit entry emitted in a unit test is dropped unless the test opts in to publishing, so tests that
	 * do not exercise the audit channel pay nothing for it; once opted in, the entry waits in the audit buffer and never
	 * in the application buffer.
	 *
	 * @see LOG_Engine.logAudit
	 * @see LOG_Engine.getAuditBufferSize
	 */
	@IsTest
	private static void auditEntryNeedsTheTestModeOptInAndUsesItsOwnBuffer()
	{
		setupTestData();

		Test.startTest();

		LOG_Engine.suspendSaving();
		LOG_Engine.logAudit(MESSAGE, MESSAGE, CLASS_METHOD, null, LoggingLevel.INFO);
		Integer auditBufferedWithoutOptIn = LOG_Engine.getAuditBufferSize();
		LOG_Engine.ignoreTestMode = true;
		LOG_Engine.logAudit(MESSAGE, MESSAGE, CLASS_METHOD, null, LoggingLevel.INFO);
		Integer auditBufferedWithOptIn = LOG_Engine.getAuditBufferSize();
		Integer applicationBuffered = LOG_Engine.getBufferSize();
		LOG_Engine.resumeSaving();

		Test.stopTest();

		Assert.areEqual(0, auditBufferedWithoutOptIn, 'An audit entry in a unit test without the opt-in should be dropped');
		Assert.areEqual(1, auditBufferedWithOptIn, 'An opted-in audit entry should wait in the audit buffer');
		Assert.areEqual(0, applicationBuffered, 'An audit entry should never land in the application buffer');
	}

	/**
	 * @description Tests that an entry written after a correlation is started carries that correlation as its root:
	 * an action's own entries name the action in both fields.
	 *
	 * @see LOG_Engine.startCorrelation
	 */
	@IsTest
	private static void startCorrelationStampsTheRootOnEveryEntry()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;
		String correlationId = LOG_Engine.startCorrelation();

		Test.startTest();
		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.DEBUG);
		Test.stopTest();

		LogEntry__c retrievedLog = new SEL_LogEntry().findByMethod(CLASS_METHOD);
		Assert.isNotNull(retrievedLog, MSG_NOT_EMPTY);
		Assert.areEqual(correlationId, retrievedLog.CorrelationId__c, 'The entry carries the correlation');
		Assert.areEqual(correlationId, retrievedLog.RootCorrelationId__c, 'An action\'s own entries carry its correlation as the root');
	}

	/**
	 * @description An entry written after a parent transaction is set names that parent, so a job's entries link back to
	 * the transaction that started the job.
	 *
	 * @see LOG_Engine.setParentTransactionId
	 */
	@IsTest
	private static void setParentTransactionIdStampsTheParentOnEveryEntry()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;
		LOG_Engine.setParentTransactionId(PARENT_TRANSACTION_ID);

		Test.startTest();
		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.DEBUG);
		Test.stopTest();

		LogEntry__c retrievedLog = new SEL_LogEntry().findByMethod(CLASS_METHOD);
		Assert.areEqual(PARENT_TRANSACTION_ID, retrievedLog.ParentTransactionId__c, 'The entry should name the parent transaction');
	}

	/**
	 * @description Tests that setting a correlation when the request has none makes it the root: the first correlation a
	 * request establishes names the action.
	 *
	 * @see LOG_Engine.setCorrelationId
	 */
	@IsTest
	private static void setCorrelationIdAdoptsTheRootWhenNoneIsSet()
	{
		Test.startTest();
		LOG_Engine.setCorrelationId(CHILD_CORRELATION_ID);
		Test.stopTest();

		Assert.areEqual(CHILD_CORRELATION_ID, LOG_Engine.getCorrelationId(), 'The live correlation follows the set');
		Assert.areEqual(CHILD_CORRELATION_ID, LOG_Engine.getRootCorrelationId(), 'The first correlation a request establishes is its root');
	}

	/**
	 * @description Tests that changing the live correlation later never moves the root: the action that started
	 * everything keeps its identity while a child continues under an id of its own.
	 *
	 * @see LOG_Engine.setCorrelationId
	 */
	@IsTest
	private static void setCorrelationIdNeverMovesAnExistingRoot()
	{
		String rootId = LOG_Engine.startCorrelation();

		Test.startTest();
		LOG_Engine.setCorrelationId(CHILD_CORRELATION_ID);
		Test.stopTest();

		Assert.areEqual(CHILD_CORRELATION_ID, LOG_Engine.getCorrelationId(), 'The live correlation follows the set');
		Assert.areEqual(rootId, LOG_Engine.getRootCorrelationId(), 'The root stays with the action that started everything');
	}

	/**
	 * @description Tests that serializing under a chosen correlation id keeps the root, the parent transaction and the
	 * context values, leaves the live context untouched, and hydrates as a child of the same action.
	 *
	 * @see LOG_Engine.serializeContextWithCorrelationId
	 */
	@IsTest
	private static void serializeContextWithCorrelationIdKeepsTheRootAndTheContext()
	{
		String actionCorrelationId = LOG_Engine.startCorrelation();
		LOG_Engine.globalContextData.put(CONTEXT_KEY, CONTEXT_VALUE);

		Test.startTest();
		String serialized = LOG_Engine.serializeContextWithCorrelationId(RUN_CORRELATION_ID);

		Assert.areEqual(actionCorrelationId, LOG_Engine.currentCorrelationId, 'Serializing under a chosen id must not re-tag the live transaction');
		Assert.areEqual(actionCorrelationId, LOG_Engine.currentRootCorrelationId, 'Serializing under a chosen id must not move the live root');
		Map<String, Object> document = (Map<String, Object>)JSON.deserializeUntyped(serialized);
		Assert.areEqual(RUN_CORRELATION_ID, document.get(DOCUMENT_CORRELATION_FIELD), 'The document carries the chosen correlation id');
		Assert.areEqual(actionCorrelationId, document.get(DOCUMENT_ROOT_FIELD), 'The document carries the action as the root');
		Assert.isTrue(document.containsKey(DOCUMENT_PARENT_FIELD), 'The document carries the parent transaction');
		Assert.isTrue(document.containsKey(DOCUMENT_CONTEXT_FIELD), 'The document carries the context values');

		LOG_Engine.currentCorrelationId = null;
		LOG_Engine.currentRootCorrelationId = null;
		LOG_Engine.globalContextData.clear();
		LOG_Engine.hydrateContext(serialized);
		Test.stopTest();

		Assert.areEqual(RUN_CORRELATION_ID, LOG_Engine.getCorrelationId(), 'Hydrating adopts the chosen correlation id');
		Assert.areEqual(actionCorrelationId, LOG_Engine.getRootCorrelationId(), 'Hydrating keeps the action as the root');
		Assert.areEqual(CONTEXT_VALUE, LOG_Engine.globalContextData.get(CONTEXT_KEY), 'Hydrating restores the context values');
	}

	/**
	 * @description Tests that a chosen-id document written with no live correlation names the chosen id as its root:
	 * the execution starts the action.
	 *
	 * @see LOG_Engine.serializeContextWithCorrelationId
	 */
	@IsTest
	private static void serializeContextWithCorrelationIdStartsTheActionWhenThereIsNone()
	{
		Test.startTest();
		String serialized = LOG_Engine.serializeContextWithCorrelationId(RUN_CORRELATION_ID);
		Test.stopTest();

		Map<String, Object> document = (Map<String, Object>)JSON.deserializeUntyped(serialized);
		Assert.areEqual(RUN_CORRELATION_ID, document.get(DOCUMENT_CORRELATION_FIELD), 'The document carries the chosen correlation id');
		Assert.areEqual(RUN_CORRELATION_ID, document.get(DOCUMENT_ROOT_FIELD), 'With no live correlation the chosen id is the root');
	}

	/**
	 * @description Tests that a chosen-id document written while the live correlation is an empty string names the
	 * chosen id as its root: a blank correlation is no correlation, so the execution starts the action.
	 *
	 * @see LOG_Engine.serializeContextWithCorrelationId
	 */
	@IsTest
	private static void serializeContextWithCorrelationIdTreatsABlankLiveCorrelationAsNone()
	{
		LOG_Engine.setCorrelationId(BLANK_CORRELATION_ID);

		Test.startTest();
		String serialized = LOG_Engine.serializeContextWithCorrelationId(RUN_CORRELATION_ID);
		Test.stopTest();

		Map<String, Object> document = (Map<String, Object>)JSON.deserializeUntyped(serialized);
		Assert.areEqual(RUN_CORRELATION_ID, document.get(DOCUMENT_CORRELATION_FIELD), 'The document carries the chosen correlation id');
		Assert.areEqual(RUN_CORRELATION_ID, document.get(DOCUMENT_ROOT_FIELD), 'A blank live correlation is no correlation, so the chosen id is the root');
	}

	/**
	 * @description Tests that a context document without a root, written before roots existed, hydrates with its
	 * correlation as the root.
	 *
	 * @see LOG_Engine.hydrateContext
	 */
	@IsTest
	private static void hydrateContextNamesTheCorrelationAsRootWhenTheDocumentHasNone()
	{
		Test.startTest();
		LOG_Engine.hydrateContext(LEGACY_DOCUMENT);
		Test.stopTest();

		Assert.areEqual(LEGACY_CORRELATION_ID, LOG_Engine.getCorrelationId(), 'The document\'s correlation is restored');
		Assert.areEqual(LEGACY_CORRELATION_ID, LOG_Engine.getRootCorrelationId(), 'A document without a root names its correlation as the root');
	}

	/**
	 * @description Tests that a context document this request wrote is recognised as its own: the document names the
	 * running request as its parent transaction.
	 *
	 * @see LOG_Engine.wasContextWrittenByCurrentRequest
	 */
	@IsTest
	private static void contextWrittenByTheCurrentRequestIsItsOwn()
	{
		String ownDocument = LOG_Engine.serializeContext();

		Test.startTest();
		Boolean isOwn = LOG_Engine.wasContextWrittenByCurrentRequest(ownDocument);
		Test.stopTest();

		Assert.isTrue(isOwn, 'A document written by the running request names it as the parent transaction');
	}

	/**
	 * @description Tests that a document written by another request, a document that names no parent, and a blank or
	 * unreadable document are not the running request's own.
	 *
	 * @see LOG_Engine.wasContextWrittenByCurrentRequest
	 */
	@IsTest
	private static void contextNotWrittenByTheCurrentRequestIsNotItsOwn()
	{
		LOG_Engine.DTO_LoggerContext otherRequestsContext = new LOG_Engine.DTO_LoggerContext();
		otherRequestsContext.correlationId = RUN_CORRELATION_ID;
		otherRequestsContext.parentTransactionId = UTIL_Random.randomUUID();
		String otherRequestsDocument = JSON.serialize(otherRequestsContext);
		String parentlessDocument = LOG_Engine.serializeContext(RUN_CORRELATION_ID);

		Test.startTest();
		Boolean otherRequests = LOG_Engine.wasContextWrittenByCurrentRequest(otherRequestsDocument);
		Boolean parentless = LOG_Engine.wasContextWrittenByCurrentRequest(parentlessDocument);
		Boolean blank = LOG_Engine.wasContextWrittenByCurrentRequest(null);
		Boolean unreadable = LOG_Engine.wasContextWrittenByCurrentRequest('not json');
		Test.stopTest();

		Assert.isFalse(otherRequests, 'A document naming another request as its parent is not the running request\'s own');
		Assert.isFalse(parentless, 'A document naming no parent is not the running request\'s own');
		Assert.isFalse(blank, 'A blank document is not the running request\'s own');
		Assert.isFalse(unreadable, 'An unreadable document is not the running request\'s own');
	}

	/**
	 * @description Tests that re-keying a stored document to a new correlation keeps its root, its parent transaction and
	 * its context values, and that a document without a root names its old correlation as the root.
	 *
	 * @see LOG_Engine.replaceCorrelationId
	 */
	@IsTest
	private static void replaceCorrelationIdKeepsEverythingButTheCorrelation()
	{
		String actionCorrelationId = LOG_Engine.startCorrelation();
		LOG_Engine.globalContextData.put(CONTEXT_KEY, CONTEXT_VALUE);
		String fullDocument = LOG_Engine.serializeContext();

		Test.startTest();
		String rekeyedFull = LOG_Engine.replaceCorrelationId(fullDocument, RUN_CORRELATION_ID);
		String rekeyedLegacy = LOG_Engine.replaceCorrelationId(LEGACY_DOCUMENT, RUN_CORRELATION_ID);
		Test.stopTest();

		Map<String, Object> full = (Map<String, Object>)JSON.deserializeUntyped(rekeyedFull);
		Assert.areEqual(RUN_CORRELATION_ID, full.get(DOCUMENT_CORRELATION_FIELD), 'The re-keyed document carries the new correlation');
		Assert.areEqual(actionCorrelationId, full.get(DOCUMENT_ROOT_FIELD), 'The re-keyed document keeps its root');
		Assert.isTrue(full.containsKey(DOCUMENT_PARENT_FIELD), 'The re-keyed document keeps its parent transaction');
		Assert.areEqual(CONTEXT_VALUE, ((Map<String, Object>)full.get(DOCUMENT_CONTEXT_FIELD)).get(CONTEXT_KEY), 'The re-keyed document keeps its context values');

		Map<String, Object> legacy = (Map<String, Object>)JSON.deserializeUntyped(rekeyedLegacy);
		Assert.areEqual(RUN_CORRELATION_ID, legacy.get(DOCUMENT_CORRELATION_FIELD), 'The legacy document carries the new correlation');
		Assert.areEqual(LEGACY_CORRELATION_ID, legacy.get(DOCUMENT_ROOT_FIELD), 'A legacy document names its old correlation as the root');
	}

	/**
	 * @description Tests that re-keying a blank or unreadable document yields a document carrying the new correlation as
	 * both correlation and root, so a run whose stored context was lost still names itself.
	 *
	 * @see LOG_Engine.replaceCorrelationId
	 */
	@IsTest
	private static void replaceCorrelationIdStartsFreshForABlankOrUnreadableDocument()
	{
		Test.startTest();
		String fromBlank = LOG_Engine.replaceCorrelationId(null, RUN_CORRELATION_ID);
		String fromUnreadable = LOG_Engine.replaceCorrelationId('not json', RUN_CORRELATION_ID);
		Test.stopTest();

		for(String rekeyed : new List<String> {fromBlank, fromUnreadable})
		{
			Map<String, Object> document = (Map<String, Object>)JSON.deserializeUntyped(rekeyed);
			Assert.areEqual(RUN_CORRELATION_ID, document.get(DOCUMENT_CORRELATION_FIELD), 'The document carries the new correlation');
			Assert.areEqual(RUN_CORRELATION_ID, document.get(DOCUMENT_ROOT_FIELD), 'The document names the new correlation as its root');
		}
	}

	/**
	 * @description Tests that re-keying a document whose correlation is an empty string names the new correlation as
	 * the root: a blank correlation is no correlation, so nothing older than the new id names the action.
	 *
	 * @see LOG_Engine.replaceCorrelationId
	 */
	@IsTest
	private static void replaceCorrelationIdTreatsABlankStoredCorrelationAsNone()
	{
		Test.startTest();
		String rekeyed = LOG_Engine.replaceCorrelationId(BLANK_CORRELATION_DOCUMENT, RUN_CORRELATION_ID);
		Test.stopTest();

		Map<String, Object> document = (Map<String, Object>)JSON.deserializeUntyped(rekeyed);
		Assert.areEqual(RUN_CORRELATION_ID, document.get(DOCUMENT_CORRELATION_FIELD), 'The document carries the new correlation');
		Assert.areEqual(RUN_CORRELATION_ID, document.get(DOCUMENT_ROOT_FIELD), 'A blank stored correlation is no correlation, so the new id is the root');
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
	 * @description A callout that reports its outcome with no webservice context set before it still has the outcome
	 * recorded under its correlation, with no duration when none was measured.
	 *
	 * @see LOG_Engine.updateWebserviceContext
	 */
	@IsTest
	private static void updateWebserviceContextWithoutAPriorContext()
	{
		Test.startTest();

		LOG_Engine.updateWebserviceContext(RUN_CORRELATION_ID, GATEWAY_TIMEOUT_STATUS, null);

		Test.stopTest();

		Map<String, String> webserviceContext = LOG_Engine.webserviceContextsByCorrelation.get(RUN_CORRELATION_ID);
		Assert.isNotNull(webserviceContext, 'The outcome should create a context for the correlation');
		Assert.areEqual(GATEWAY_TIMEOUT_STATUS, webserviceContext.get('statusCode'), 'Status code should be set');
		Assert.isNull(webserviceContext.get('calloutDurationMs'), 'No duration should be recorded when none was measured');
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
	 * @description A push refused at the cap must not cost its caller the context underneath: the pop that follows the
	 * refused push removes nothing, so the caller's later lines keep the context the caller pushed.
	 *
	 * @see LOG_Engine.pushOperationContext
	 */
	@IsTest
	private static void shouldKeepTheCallersContextWhenAPushIsRefusedAtTheCap()
	{
		LOG_Engine.clearContextStack();
		fillTheContextStackToTheCap();

		Test.startTest();
		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.FLOW, new Map<String, String>());
		LOG_Engine.popOperationContext();
		Test.stopTest();

		Assert.areEqual(MAXIMUM_CONTEXT_DEPTH, LOG_Engine.getContextStackDepth(), 'A refused push and its pop leave the stack as it was');
		Assert.areEqual(LOG_Engine.OperationType.QUERY.name(), LOG_Engine.getCurrentOperationType(), 'The caller keeps the context it pushed');

		LOG_Engine.clearContextStack();
	}

	/**
	 * @description Refused pushes unwind in the order they were made, and the contexts that were really pushed pop
	 * normally once the refused ones have gone.
	 *
	 * @see LOG_Engine.popOperationContext
	 */
	@IsTest
	private static void shouldUnwindNestedRefusedPushesBeforeTheRealOnes()
	{
		LOG_Engine.clearContextStack();
		fillTheContextStackToTheCap();

		Test.startTest();
		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.FLOW, new Map<String, String>());
		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.LWC, new Map<String, String>());
		LOG_Engine.popOperationContext();
		LOG_Engine.popOperationContext();

		Assert.areEqual(MAXIMUM_CONTEXT_DEPTH, LOG_Engine.getContextStackDepth(), 'Two refused pushes unwind without touching the stack');

		for(Integer index = 0; index < MAXIMUM_CONTEXT_DEPTH; index++)
		{
			LOG_Engine.popOperationContext();
		}
		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'The contexts that were really pushed still pop');
	}

	/**
	 * @description Clearing the stack forgets the pushes the engine refused, so the first pop after a clear works on
	 * the cleared stack rather than on a refusal from before it.
	 *
	 * @see LOG_Engine.clearContextStack
	 */
	@IsTest
	private static void shouldForgetRefusedPushesWhenTheContextStackIsCleared()
	{
		LOG_Engine.clearContextStack();
		fillTheContextStackToTheCap();
		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.FLOW, new Map<String, String>());

		Test.startTest();
		LOG_Engine.clearContextStack();
		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.QUERY, new Map<String, String>());
		LOG_Engine.popOperationContext();
		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'A cleared stack forgets the pushes it refused');
	}

	/**
	 * @description Pushes contexts until the stack holds as many as the engine keeps, so the next push is refused.
	 */
	private static void fillTheContextStackToTheCap()
	{
		for(Integer index = 0; index < MAXIMUM_CONTEXT_DEPTH; index++)
		{
			LOG_Engine.pushOperationContext(LOG_Engine.OperationType.QUERY, new Map<String, String>());
		}
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
	 * @description A global context value is stored as text whatever its type: a plain value such as a decimal as its
	 * own text, a map as JSON, and a value JSON cannot serialise, such as an outbound request, as its text form instead
	 * of failing the caller.
	 *
	 * @see LOG_Engine.setGlobalContext
	 */
	@IsTest
	private static void setGlobalContextStoresEveryValueAsText()
	{
		HttpRequest outboundRequest = new HttpRequest();
		outboundRequest.setEndpoint(REQUEST_ENDPOINT);

		Test.startTest();

		LOG_Engine.setGlobalContext(AMOUNT_CONTEXT_KEY, AMOUNT_CONTEXT_VALUE);
		LOG_Engine.setGlobalContext(MAP_CONTEXT_KEY, new Map<String, String> {'sku' => 'ABC-1'});
		LOG_Engine.setGlobalContext(REQUEST_CONTEXT_KEY, outboundRequest);
		Map<String, String> merged = LOG_Engine.getMergedContext();

		Test.stopTest();

		Assert.areEqual(AMOUNT_CONTEXT_TEXT, merged.get(AMOUNT_CONTEXT_KEY), 'A decimal should be stored as its own text');
		Assert.areEqual(MAP_CONTEXT_JSON, merged.get(MAP_CONTEXT_KEY), 'A map should be stored as JSON');
		Assert.isTrue(merged.get(REQUEST_CONTEXT_KEY).contains(REQUEST_ENDPOINT), 'A value JSON cannot serialise should be stored as its text form');
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
	 * @description Builds a refused DML result of the given type from JSON, carrying the refused row's Id.
	 *
	 * @param recordId The Id of the refused row.
	 * @param resultType Database.DeleteResult, Database.UndeleteResult or Database.UpsertResult.
	 *
	 * @return The refused result, typed as the caller asked.
	 */
	private static Object refusedResult(Id recordId, Type resultType)
	{
		return JSON.deserialize(REFUSED_ROW_JSON_HEAD + recordId + REFUSED_ROW_JSON_TAIL, resultType);
	}

	/**
	 * @description Tests that a refused delete, undelete or upsert result logs an entry that carries the refused
	 * row's Id, read from each result type in turn.
	 *
	 * @see LOG_Engine.log
	 */
	@IsTest
	private static void shouldCarryTheRefusedRowIdForEveryResultType()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;
		Id deletedRowId = UTIL_Random.randomId(Foobar__c.SObjectType);
		Id undeletedRowId = UTIL_Random.randomId(Foobar__c.SObjectType);
		Id upsertedRowId = UTIL_Random.randomId(Foobar__c.SObjectType);
		List<Object> results = new List<Object>
		{
				refusedResult(deletedRowId, Database.DeleteResult.class),
				refusedResult(undeletedRowId, Database.UndeleteResult.class),
				refusedResult(upsertedRowId, Database.UpsertResult.class)
		};

		Test.startTest();

		Boolean hadFailures = LOG_Engine.log(results, CLASS_METHOD, LoggingLevel.ERROR);

		Test.stopTest();

		Assert.isTrue(hadFailures, 'Every refused row should be reported as a failure');
		Set<String> loggedRowIds = new Set<String>();
		for(LogEntry__c entry : new SEL_LogEntry().findAllByMethod(CLASS_METHOD))
		{
			loggedRowIds.add(entry.RecordId__c);
		}
		Set<String> refusedRowIds = new Set<String> {String.valueOf(deletedRowId), String.valueOf(undeletedRowId), String.valueOf(upsertedRowId)};
		Assert.areEqual(refusedRowIds, loggedRowIds, MESSAGE_REFUSED_ROW_IDS);
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
		String classMethod = LOG_Engine_TEST.class.getName() + '/shouldLogListOfStringMessages';

		Test.startTest();

		LOG_Engine.log(messages, classMethod, LoggingLevel.ERROR);

		Test.stopTest();

		List<LogEntry__c> entries = new SEL_LogEntry().findAllByMethod(classMethod);
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
		// SYSTEM_MODE keeps the fixture independent of the running user's record-type and field access,
		// which the test-running user lacks in namespaced packaging/subscriber orgs.
		List<Database.UpsertResult> results = Database.upsert(new List<SObject> {record}, false, System.AccessLevel.SYSTEM_MODE);
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

	/**
	 * @description Confirms the event-trigger-context detector recognises every kind of event: a custom
	 * platform event (`__e`), a change event (`*ChangeEvent`) and a standard platform event such as
	 * `BatchApexErrorEvent`, whose name carries neither suffix. These are the contexts where publishing a
	 * `LogEntryEvent__e` makes the platform redeliver the source event and loop. Ordinary objects stay
	 * non-event, including the calendar `Event`, whose name ends in "Event" but which can be queried, and
	 * so do empty or null lists, so normal logging is never re-routed.
	 *
	 * @see LOG_Engine.isChangeEventOrPlatformEvent
	 */
	@IsTest
	private static void eventTriggerContextDetectionClassifiesEventSObjects()
	{
		Assert.isTrue(LOG_Engine.isChangeEventOrPlatformEvent(new List<SObject> {new BatchApexErrorEvent()}),
				'A standard platform event with no suffix must be detected as event-trigger context');
		Assert.isFalse(LOG_Engine.isChangeEventOrPlatformEvent(new List<SObject> {new Event()}),
				'The calendar Event object can be queried, so it must not be detected as event-trigger context');
		Assert.isTrue(LOG_Engine.isChangeEventOrPlatformEvent(new List<SObject> {new LogEntryEvent__e()}),
				'A platform event (__e) must be detected as event-trigger context');
		Assert.isTrue(LOG_Engine.isChangeEventOrPlatformEvent(new List<SObject> {new AccountChangeEvent()}),
				'A change event (ChangeEvent) must be detected as event-trigger context');
		Assert.isFalse(LOG_Engine.isChangeEventOrPlatformEvent(new List<SObject> {new Account()}),
				'An ordinary SObject must not be detected as event-trigger context');
		Assert.isFalse(LOG_Engine.isChangeEventOrPlatformEvent(new List<SObject>()),
				'An empty record list must not be detected as event-trigger context');
		Assert.isFalse(LOG_Engine.isChangeEventOrPlatformEvent(null),
				'A null record list must not be detected as event-trigger context');
	}

	/**
	 * @description Guards the classifier for a user who cannot read an ordinary object. Plain Apex DML does not check
	 * object access, so a trigger on an ordinary object can run for such a user, and its logs must still go out by
	 * publishing: an ordinary object classified as an event would have its logs written inside the transaction and
	 * rolled back with a failure. The describe the classifier reads must therefore answer "can be queried" for the
	 * object itself, not for the running user. This method describes both objects for the first time inside the runAs
	 * block, so the cached answer is the restricted user's.
	 *
	 * @see LOG_Engine.isChangeEventOrPlatformEvent
	 */
	@IsTest
	private static void eventTriggerContextDetectionIgnoresTheRunningUsersObjectAccess()
	{
		User userWithoutObjectAccess = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);

		System.runAs(userWithoutObjectAccess)
		{
			Assert.isFalse(UTIL_SObjectDescribe.isObjectAccessible(Foobar__c.SObjectType), 'Precondition: the running user cannot read the ordinary object');
			Assert.isFalse(LOG_Engine.isChangeEventOrPlatformEvent(new List<SObject> {new Foobar__c()}),
					'An ordinary object the running user cannot read must not be detected as event-trigger context');
			Assert.isTrue(LOG_Engine.isChangeEventOrPlatformEvent(new List<SObject> {new BatchApexErrorEvent()}),
					'A standard platform event must be detected as event-trigger context for any running user');
		}
	}

	/**
	 * @description Only the outermost event dispatch owns the event-trigger context: a second
	 * `beginEventTriggerContext` while already in context returns `false` so a nested re-entrant
	 * dispatch leaves teardown to the owner. This guards against a nested dispatch's
	 * `endEventTriggerContext` clearing the flag while the outer dispatch is still emitting logs —
	 * which would let those outer logs publish and reopen the loop.
	 *
	 * @see LOG_Engine.beginEventTriggerContext
	 */
	@IsTest
	private static void nestedEventTriggerContextDoesNotReenter()
	{
		Boolean outerEntered = LOG_Engine.beginEventTriggerContext(new List<SObject> {new LogEntryEvent__e()});
		Boolean nestedEntered = LOG_Engine.beginEventTriggerContext(new List<SObject> {new LogEntryEvent__e()});
		LOG_Engine.endEventTriggerContext();

		Assert.isTrue(outerEntered, 'The outermost event dispatch must enter and own the context');
		Assert.isFalse(nestedEntered, 'A nested event dispatch must not re-enter (the outer owner tears the context down)');
	}

	/**
	 * @description When entering event-trigger context switches suspended-saving on (the common
	 * case — no outer `LogScope`), `endEventTriggerContext` must switch it back off. Guards the
	 * ownership-restore logic: a failure here would silently leave saving suspended for the rest of
	 * the transaction, swallowing subsequent logging.
	 *
	 * @see LOG_Engine.endEventTriggerContext
	 */
	@IsTest
	private static void endEventTriggerContextRestoresSuspendedSavingWhenItOwnedTheFlip()
	{
		Assert.isFalse(LOG_Engine.isSavingSuspended, 'Precondition: saving is not suspended');

		LOG_Engine.beginEventTriggerContext(new List<SObject> {new LogEntryEvent__e()});
		Assert.isTrue(LOG_Engine.isSavingSuspended, 'Entering event context buffers emits by suspending saving');

		LOG_Engine.endEventTriggerContext();
		Assert.isFalse(LOG_Engine.isSavingSuspended, 'The owner that switched suspended-saving on must switch it back off');
		Assert.isFalse(LOG_Engine.isEventTriggerContext, 'Event-trigger context must be cleared on exit');
	}

	/**
	 * @description When an OUTER `suspendSaving`/`LogScope` already suspended saving before an event
	 * dispatch begins, `endEventTriggerContext` must NOT switch saving back off — the outer scope
	 * owns that lifecycle. Guards against a nested event context stealing the outer scope's suspension
	 * (which would prematurely resume the outer scope's buffered logging).
	 *
	 * @see LOG_Engine.endEventTriggerContext
	 */
	@IsTest
	private static void endEventTriggerContextLeavesOuterSuspendedSavingUntouched()
	{
		LOG_Engine.suspendSaving();
		Assert.isTrue(LOG_Engine.isSavingSuspended, 'Precondition: an outer scope suspended saving');

		LOG_Engine.beginEventTriggerContext(new List<SObject> {new LogEntryEvent__e()});
		LOG_Engine.endEventTriggerContext();

		Assert.isTrue(LOG_Engine.isSavingSuspended, 'A nested event context must leave an outer scope\'s suspended-saving on');
		Assert.isFalse(LOG_Engine.isEventTriggerContext, 'Event-trigger context must still be cleared on exit');

		LOG_Engine.resumeSaving();
	}

	/**
	 * @description The core loop-fix invariant for buffered (non-ERROR) logs: a routine
	 * fingerprinted DEBUG entry emitted while inside a change-event/platform-event trigger context
	 * must NOT publish a `LogEntryEvent__e` (publishing would make the platform redeliver the source
	 * event and loop). Instead it persists directly to `LogEntry__c` via DML at the dispatch
	 * boundary, collapsed by the shared flood-control persister into one detail row. `getPublishImmediateDML`
	 * staying flat proves no platform-event publish occurred; the detail row proves the log was not lost.
	 *
	 * @see LOG_Engine.beginEventTriggerContext
	 * @see LOG_Engine.endEventTriggerContext
	 */
	@IsTest
	private static void eventTriggerContextBuffersAndPersistsViaDmlWithoutPublishing()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;
		String fingerprint = 'event-context-debug:' + UTIL_Random.randomName();

		Test.startTest();
		LOG_Engine.beginEventTriggerContext(new List<SObject> {new LogEntryEvent__e()});
		Integer publishBefore = UTIL_Limits.publishImmediateDml().used();
		LOG_Builder.build().debug('routine skip during change-event dispatch').withFingerprintInternal(fingerprint).at(CLASS_METHOD).emit();
		LOG_Engine.endEventTriggerContext();
		Integer publishAfter = UTIL_Limits.publishImmediateDml().used();
		Test.stopTest();

		Assert.areEqual(publishBefore, publishAfter,
				'No LogEntryEvent__e may be published from inside a change-event/platform-event trigger context');
		Assert.isTrue(hasDetailRowForFingerprint(fingerprint),
				'The in-context log must still persist via direct DML (flood-controlled detail row)');
	}

	/**
	 * @description The loop-fix invariant for ERROR logs: an ERROR emitted inside a change-event /
	 * platform-event trigger context must persist its forensic row (observability during CDC
	 * dispatch is preserved) WITHOUT publishing a `LogEntryEvent__e`. Inside that context an ERROR
	 * waits in the buffer like any other entry, so the row is written by direct DML when the context
	 * ends, never through `EventBus.publish`.
	 *
	 * @see LOG_Engine.beginEventTriggerContext
	 * @see LOG_Engine.endEventTriggerContext
	 */
	@IsTest
	private static void eventTriggerContextErrorPersistsWithoutPublishing()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;
		String fingerprint = 'event-context-error:' + UTIL_Random.randomName();

		Test.startTest();
		LOG_Engine.beginEventTriggerContext(new List<SObject> {new LogEntryEvent__e()});
		Integer publishBefore = UTIL_Limits.publishImmediateDml().used();
		LOG_Builder.build().error('action failed during change-event dispatch').withFingerprintInternal(fingerprint).at(CLASS_METHOD).emit();
		LOG_Engine.endEventTriggerContext();
		Integer publishAfter = UTIL_Limits.publishImmediateDml().used();
		Test.stopTest();

		Assert.areEqual(publishBefore, publishAfter,
				'An ERROR inside change-event/platform-event trigger context must not publish a LogEntryEvent__e');
		Assert.isTrue(hasDetailRowForFingerprint(fingerprint),
				'The in-context ERROR must persist via direct DML so observability survives the loop fix');
	}

	/**
	 * @description Inside a platform-event trigger an ERROR entry waits in the buffer instead of being
	 * written at once: a trigger on `BatchApexErrorEvent`, the object the batch-error listener runs on,
	 * receives up to 2,000 events, and one insert per error entry would spend its DML budget. The
	 * statement count stays flat while the entries are emitted, and all of them are written when the
	 * context ends, still without publishing a `LogEntryEvent__e`.
	 *
	 * @see LOG_Engine.beginEventTriggerContext
	 * @see LOG_Engine.endEventTriggerContext
	 */
	@IsTest
	private static void errorEntriesInsideEventTriggerContextPersistInOneFlush()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;
		List<String> fingerprints = new List<String>
		{
				'event-context-buffered-error:' + UTIL_Random.randomName(),
				'event-context-buffered-error:' + UTIL_Random.randomName(),
				'event-context-buffered-error:' + UTIL_Random.randomName()
		};

		Test.startTest();
		LOG_Engine.beginEventTriggerContext(new List<SObject> {new BatchApexErrorEvent()});
		Integer publishBefore = UTIL_Limits.publishImmediateDml().used();
		Integer dmlStatementsBefore = UTIL_Limits.dmlStatements().used();
		for(String fingerprint : fingerprints)
		{
			LOG_Builder.build().error('batch job failed during platform-event dispatch').withFingerprintInternal(fingerprint).at(CLASS_METHOD).emit();
		}
		Integer dmlStatementsAfterEmitting = UTIL_Limits.dmlStatements().used();
		LOG_Engine.endEventTriggerContext();
		Integer publishAfter = UTIL_Limits.publishImmediateDml().used();
		Test.stopTest();

		Assert.areEqual(dmlStatementsBefore, dmlStatementsAfterEmitting, 'ERROR entries inside event-trigger context must wait in the buffer, not insert one by one');
		for(String fingerprint : fingerprints)
		{
			Assert.isTrue(hasDetailRowForFingerprint(fingerprint), 'Every buffered ERROR entry must be written when the event-trigger context ends');
		}
		Assert.areEqual(publishBefore, publishAfter, 'No LogEntryEvent__e may be published from inside a platform-event trigger context');
	}

	/**
	 * @description The engine counts the DML statements its own log writes spend inside an event-trigger context, so the
	 * post-trigger action guard can tell them apart from DML an action performed itself: the count moves by exactly the
	 * statements the context's closing flush spent.
	 *
	 * @see LOG_Engine.getFrameworkLogPersistenceDmlStatements
	 * @see LOG_Engine.endEventTriggerContext
	 */
	@IsTest
	private static void eventTriggerContextCountsTheDmlItsOwnLogWritesSpend()
	{
		setupTestData();

		Test.startTest();
		LOG_Engine.beginEventTriggerContext(new List<SObject> {new LogEntryEvent__e()});
		LOG_Engine.log(MESSAGE, CLASS_METHOD, LoggingLevel.DEBUG);
		Integer countedBefore = LOG_Engine.getFrameworkLogPersistenceDmlStatements();
		Integer dmlStatementsBefore = UTIL_Limits.dmlStatements().used();
		LOG_Engine.endEventTriggerContext();
		Integer dmlStatementsSpent = UTIL_Limits.dmlStatements().used() - dmlStatementsBefore;
		Integer counted = LOG_Engine.getFrameworkLogPersistenceDmlStatements() - countedBefore;
		Test.stopTest();

		Assert.isTrue(dmlStatementsSpent > 0, 'Closing the context should write the buffered entry by DML');
		Assert.areEqual(dmlStatementsSpent, counted, 'The engine should count exactly the DML statements its own log writes spent');
	}

	/**
	 * @description Regression guard: outside any event-trigger context, logs must STILL publish
	 * immediately via `EventBus.publish` (the deliberate `PublishImmediately` behaviour that lets
	 * ERROR rows survive a business-transaction rollback). Proven by `getPublishImmediateDML`
	 * advancing on emit — the loop fix must change nothing for ordinary logging.
	 *
	 * @see LOG_Engine.publishEvents
	 */
	@IsTest
	private static void normalContextStillPublishesImmediately()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;

		Test.startTest();
		Integer publishBefore = UTIL_Limits.publishImmediateDml().used();
		LOG_Builder.build().error('ordinary error outside any event trigger').at(CLASS_METHOD).emit();
		Integer publishAfter = UTIL_Limits.publishImmediateDml().used();
		Test.stopTest();

		Assert.isTrue(publishAfter > publishBefore,
				'Outside event-trigger context, logs must still publish immediately (PublishImmediately preserved)');
	}

	/**
	 * @description Scans persisted log rows for the flood-control detail row carrying the given
	 * fingerprint. Used by the event-trigger-context tests to prove an in-context emit persisted via
	 * direct DML rather than being lost when the platform-event publish was suppressed.
	 *
	 * @param fingerprint The raw fingerprint key passed to `withFingerprintInternal`.
	 *
	 * @return `true` when a `LogEntry__c` row exists whose `Fingerprint__c` is the detail key for the fingerprint.
	 */
	private static Boolean hasDetailRowForFingerprint(String fingerprint)
	{
		String detailKey = TRG_PersistLogEntry.PREFIX_DETAIL + fingerprint;
		for(LogEntry__c row : new SEL_LogEntry().getAll())
		{
			if(detailKey.equals(row.Fingerprint__c))
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * @description Tests that levelSeverityRank ranks the log levels by ascending severity
	 * (DEBUG < INFO < WARN < ERROR) and returns -1 for a null or unrecognised level, so the Log Console can
	 * sort the Level column by severity rather than alphabetically.
	 */
	@IsTest
	private static void shouldRankLevelsBySeverity()
	{
		Test.startTest();
		Integer debugRank = LOG_Engine.levelSeverityRank(LOG_Engine.LEVEL_DEBUG);
		Integer infoRank = LOG_Engine.levelSeverityRank(LOG_Engine.LEVEL_INFO);
		Integer warnRank = LOG_Engine.levelSeverityRank(LOG_Engine.LEVEL_WARN);
		Integer errorRank = LOG_Engine.levelSeverityRank(LOG_Engine.LEVEL_ERROR);
		Integer unknownRank = LOG_Engine.levelSeverityRank('NOT_A_LEVEL');
		Integer nullRank = LOG_Engine.levelSeverityRank(null);
		Test.stopTest();

		Assert.isTrue(debugRank < infoRank && infoRank < warnRank && warnRank < errorRank, 'Levels must rank by ascending severity: DEBUG < INFO < WARN < ERROR');
		Assert.areEqual(-1, unknownRank, 'An unrecognised level ranks -1 so it sorts before DEBUG on an ascending sort');
		Assert.areEqual(-1, nullRank, 'A null level ranks -1');
	}

	/**
	 * @description A masking rule set to block DML that fails on a log entry must not take the business transaction
	 * down: the emit completes and the entry is dropped rather than published unmasked.
	 *
	 * @see LOG_Engine.DTO_LogMessages.getEvents
	 */
	@IsTest
	private static void emitDropsAnEntryAMaskingRuleBlocks()
	{
		TST_Factory.newFeatureFlag(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);
		registerBlockingWildcardRuleOnLogEntryEvents();
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();
		LOG_Builder.build().error(BLOCKED_MESSAGE).emitAt(BLOCKED_CLASS_METHOD);
		Test.stopTest();

		Assert.isNull(new SEL_LogEntry().findByMethod(BLOCKED_CLASS_METHOD), MESSAGE_ENTRY_DROPPED);
	}

	/**
	 * @description When a stored context cannot be restored, the debug text carries the stored context as the log
	 * entry masking leaves it: a value a masking rule on log entries matches appears masked, never as written.
	 *
	 * @see LOG_Engine.describeHydrationFailure
	 */
	@IsTest
	private static void shouldMaskTheStoredContextInTheHydrationFailureText()
	{
		TST_Factory.newFeatureFlag(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);
		registerSensitiveValueRuleOnLogEntryEvents();
		IllegalArgumentException failure = new IllegalArgumentException(HYDRATION_ERROR_MESSAGE);

		Test.startTest();
		String text = LOG_Engine.describeHydrationFailure(failure, UNREADABLE_CONTEXT_WITH_SENSITIVE_VALUE);
		Test.stopTest();

		String expected = LOG_Engine.HYDRATION_FAILURE_PREFIX + HYDRATION_ERROR_MESSAGE + LOG_Engine.HYDRATION_PAYLOAD_SEPARATOR
				+ UNREADABLE_CONTEXT_WITH_SENSITIVE_VALUE.replace(SENSITIVE_VALUE, SENSITIVE_VALUE_MASK);
		Assert.areEqual(expected, text, 'Expected the error and the masked stored context, got ' + text);
		Assert.isFalse(text.contains(SENSITIVE_VALUE), 'Expected no unmasked sensitive value, got ' + text);
	}

	/**
	 * @description When the masking of a stored context that cannot be restored is blocked by a rule, the debug text
	 * holds the error alone: the stored context is left out rather than written unmasked.
	 *
	 * @see LOG_Engine.describeHydrationFailure
	 */
	@IsTest
	private static void shouldLeaveTheStoredContextOutOfTheHydrationFailureTextWhenMaskingBlocks()
	{
		TST_Factory.newFeatureFlag(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);
		registerBlockingWildcardRuleOnLogEntryEvents();
		IllegalArgumentException failure = new IllegalArgumentException(HYDRATION_ERROR_MESSAGE);

		Test.startTest();
		String text = LOG_Engine.describeHydrationFailure(failure, UNREADABLE_CONTEXT_WITH_SENSITIVE_VALUE);
		Test.stopTest();

		String expected = LOG_Engine.HYDRATION_FAILURE_PREFIX + HYDRATION_ERROR_MESSAGE;
		Assert.areEqual(expected, text, 'Expected the error alone, got ' + text);
	}

	/**
	 * @description When the masking switch itself cannot be read, a stored context that cannot be restored still gives the
	 * debug text with the error alone, and restoring it does not throw. The switch's flag is replaced by a flag row read
	 * with its name only, so reading the switch throws on the fields the flag check reads; the test first proves that it
	 * does, so it cannot pass on a switch that reads cleanly.
	 *
	 * @see LOG_Engine.describeHydrationFailure
	 */
	@IsTest
	private static void shouldLeaveTheStoredContextOutOfTheHydrationFailureTextWhenTheMaskingSwitchCannotBeRead()
	{
		FeatureFlag__mdt flagReadWithNameOnly = (FeatureFlag__mdt)QRY_Builder.selectFrom(FeatureFlag__mdt.SObjectType)
				.fields(new List<SObjectField> {FeatureFlag__mdt.DeveloperName})
				.condition(FeatureFlag__mdt.DeveloperName).equals(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED)
				.getFirst();
		SEL_FeatureFlag.activeFlags.put(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED, flagReadWithNameOnly);
		IllegalArgumentException failure = new IllegalArgumentException(HYDRATION_ERROR_MESSAGE);

		Test.startTest();
		try
		{
			Boolean switchState = UTIL_FrameworkMasker.isMaskingEnabled;
			Assert.fail('Expected reading the masking switch to throw, got ' + switchState);
		}
		catch(SObjectException switchFailure)
		{
			Assert.isNotNull(switchFailure.getMessage(), 'Expected the switch read to fail with a message, got null');
		}
		LOG_Engine.hydrateContext(UNREADABLE_CONTEXT_WITH_SENSITIVE_VALUE);
		String text = LOG_Engine.describeHydrationFailure(failure, UNREADABLE_CONTEXT_WITH_SENSITIVE_VALUE);
		Test.stopTest();

		String expected = LOG_Engine.HYDRATION_FAILURE_PREFIX + HYDRATION_ERROR_MESSAGE;
		Assert.areEqual(expected, text, 'Expected the error alone, got ' + text);
	}

	/**
	 * @description Registers one active wildcard masking target on LogEntryEvent__e whose rule replaces the sensitive
	 * value the hydration tests store, the way a subscriber rule would mask an identity number.
	 */
	private static void registerSensitiveValueRuleOnLogEntryEvents()
	{
		MaskingRule__mdt rule = (MaskingRule__mdt)TST_Builder.of(MaskingRule__mdt.SObjectType)
				.withOverride(MaskingRule__mdt.DeveloperName, SENSITIVE_VALUE_RULE_NAME)
				.withOverride(MaskingRule__mdt.Mode__c, SEL_MaskingRule.MODE_REGEX)
				.withOverride(MaskingRule__mdt.Pattern__c, SENSITIVE_VALUE_PATTERN)
				.withOverride(MaskingRule__mdt.Replacement__c, SENSITIVE_VALUE_MASK)
				.withOverride(MaskingRule__mdt.IsActive__c, true)
				.withOverride(MaskingRule__mdt.Order__c, BLOCKING_RULE_ORDER)
				.withOverride(MaskingRule__mdt.FailureAction__c, SEL_MaskingRule.FAILURE_LOG_AND_CONTINUE)
				.withoutInsertion(true)
				.build();
		TST_Mock.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.IsActive__c, true)
				.withOverride(MaskingTarget__mdt.SObjectType__c, UTIL_SObjectDescribe.getObjectNameFromType(LogEntryEvent__e.SObjectType))
				.withOverride(MaskingTarget__mdt.Field__c, null)
				.withOverride(MaskingTarget__mdt.Rule__c, rule)
				.build();
	}

	/**
	 * @description Registers one active wildcard masking target on LogEntryEvent__e whose rule cannot compile and is
	 * set to block DML, mirroring the masker's own failure-action fixtures.
	 */
	private static void registerBlockingWildcardRuleOnLogEntryEvents()
	{
		MaskingRule__mdt rule = (MaskingRule__mdt)TST_Builder.of(MaskingRule__mdt.SObjectType)
				.withOverride(MaskingRule__mdt.DeveloperName, BLOCKING_RULE_NAME)
				.withOverride(MaskingRule__mdt.Mode__c, SEL_MaskingRule.MODE_REGEX)
				.withOverride(MaskingRule__mdt.Pattern__c, INVALID_PATTERN)
				.withOverride(MaskingRule__mdt.Replacement__c, MASK_REPLACEMENT)
				.withOverride(MaskingRule__mdt.IsActive__c, true)
				.withOverride(MaskingRule__mdt.Order__c, BLOCKING_RULE_ORDER)
				.withOverride(MaskingRule__mdt.FailureAction__c, SEL_MaskingRule.FAILURE_BLOCK_DML)
				.withoutInsertion(true)
				.build();
		TST_Mock.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.IsActive__c, true)
				.withOverride(MaskingTarget__mdt.SObjectType__c, UTIL_SObjectDescribe.getObjectNameFromType(LogEntryEvent__e.SObjectType))
				.withOverride(MaskingTarget__mdt.Field__c, null)
				.withOverride(MaskingTarget__mdt.Rule__c, rule)
				.build();
	}

	/**
	 * @description Checks that the adaptive launcher switches strategy: when the DML budget cannot carry a log entry and
	 * the queueable budget is already spent, the fallback re-routes to Batch Apex, so the entry is still published and
	 * no further queueable job is enqueued. A future launcher change that re-routes this case onto a throwing path
	 * fails here first, because a spent queueable budget must never take the business transaction down.
	 *
	 * @see LOG_Engine.publishEventsTo
	 */
	@IsTest
	private static void publishesThroughTheBatchRouteWhenTheQueueableBudgetIsSpent()
	{
		setupTestData();
		LOG_Engine.ignoreTestMode = true;
		LOG_Engine.simulateDMLimitsBreach = true;

		Test.startTest();
		spendTheQueueableBudget();
		LOG_Engine.log(DEFLECTED_MESSAGE, DEFLECTED_CLASS_METHOD, LoggingLevel.ERROR);
		Assert.areEqual(UTIL_Limits.queueableJobs().maximum(), UTIL_Limits.queueableJobs().used(), MESSAGE_NO_JOB_ENQUEUED);
		Test.stopTest();

		Assert.isNotNull(new SEL_LogEntry().findByMethod(DEFLECTED_CLASS_METHOD), MESSAGE_ENTRY_PUBLISHED);
	}

	/**
	 * @description Enqueues no-operation jobs until the transaction's queueable budget is spent. Spending the budget
	 * is the point of the loop, so the enqueue inside it is deliberate rather than an oversight.
	 */
	@SuppressWarnings('PMD.OperationWithLimitsInLoop')
	private static void spendTheQueueableBudget()
	{
		while(!UTIL_Limits.queueableJobs().isExhausted())
		{
			System.enqueueJob(new NoOperationJob());
		}
	}

	/**
	 * @description A queueable that does nothing; exists only to spend the queueable budget in a test.
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock,PMD.QueueableWithoutFinalizer')
	private class NoOperationJob implements Queueable
	{
		/**
		 * @description No-op execute: the job exists to consume one unit of the queueable budget.
		 *
		 * @param context The QueueableContext.
		 */
		public void execute(QueueableContext context)
		{
		}
	}

	/**
	 * @description The steps of the test of an entry written while another entry is delivered, in the order they run.
	 * A failure names the step it happened in.
	 */
	private enum NestedEmitStage
	{
		/**
		 * @description The test trigger action is registered.
		 */
		REGISTER_TEST_ACTION,
		/**
		 * @description The first log entry is written.
		 */
		EMIT_FIRST_ENTRY,
		/**
		 * @description The log events are delivered, which runs the test trigger action.
		 */
		DELIVER_EVENTS,
		/**
		 * @description The first log entry is read back.
		 */
		READ_FIRST_ENTRY,
		/**
		 * @description The entry written during delivery is read back.
		 */
		READ_NESTED_ENTRY
	}

	/**
	 * @description A test trigger action on the log event. While the log events are delivered, it writes one plain
	 * DEBUG log entry of its own, so a test can check what that inner entry carries. The trigger framework creates it
	 * by name, so it declares no constructor.
	 */
	public inherited sharing class NestedEntryWriter extends TRG_Base implements IF_Trigger.AfterInsert
	{
		/**
		 * @description Writes one DEBUG log entry, only the first time it runs in the transaction. The entry is a new
		 * log event, and its delivery runs this action again, so the guard stops it from writing forever.
		 *
		 * @param newRecords The log events being delivered.
		 */
		public void afterInsert(List<SObject> newRecords)
		{
			if(hasWrittenNestedEntry)
			{
				return;
			}
			hasWrittenNestedEntry = true;
			LOG_Builder.build().debug(MESSAGE).at(NESTED_ENTRY_CLASS_METHOD).emit();
		}
	}
}