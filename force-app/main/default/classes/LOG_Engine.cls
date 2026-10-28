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
 * @description For writing persistent logs using platform events; originally adapted from [ApexLogger](https://github.com/mlockett/ApexLogger)
 *
 * @see LogEntryEvent__e
 * @see LOG_Engine_TEST
 * @see LogSetting__c
 * @see LOG_Builder
 * @see LOG_Builder_TEST
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.AvoidGlobalModifier,PMD.CognitiveComplexity,PMD.ExcessiveClassLength,PMD.ExcessivePublicCount,PMD.NcssTypeCount,PMD.NcssCount')
public inherited sharing class LOG_Engine
{
	/**
	 * @description Cached running-user Id captured once per transaction. Stamped onto every
	 * `LogEntryEvent__e.UserId__c` so subscribers can query persisted logs by emitting user
	 * (the trigger handler runs as the Automated Process user, so `CreatedById` is not useful).
	 */
	private static final Id CURRENT_USER_ID = UserInfo.getUserId();

	/**
	 * @description The engine publishes at most 50 events in one `EventBus.publish` call. A lower number means more
	 * publishes; a higher number risks errors when the data is too large.
	 */
	private static final Integer BATCH_SIZE = 50;

	/**
	 * @description Length of `LogEntryEvent__e.ClassMethod__c` from the SObject describe; cached
	 * once so `UTIL_String.abbreviate` can truncate `classMethod` strings to fit without re-running
	 * `getDescribe()` on every persist.
	 */
	private static final Integer CLASS_METHOD_LENGTH = LogEntryEvent__e.ClassMethod__c.getDescribe().length;

	/**
	 * @description The character the bridges put between their prefix and the writer's name in `ClassMethod__c`,
	 * as in `LWC/orderPanel.submitOrder` and `Flow/Order Intake`.
	 */
	public static final String SOURCE_PREFIX_DELIMITER = '/';

	/**
	 * @description The value the Flow bridges push under the `source` context key.
	 */
	public static final String FLOW_SOURCE_MARKER = 'Flow';

	/**
	 * @description The prefix the Flow bridges put before a Flow's name or step in `ClassMethod__c`. Shared with
	 * `resolveSource` so the writer and the reader can never disagree.
	 */
	public static final String FLOW_SOURCE_PREFIX = FLOW_SOURCE_MARKER + SOURCE_PREFIX_DELIMITER;

	/**
	 * @description Shape of one Apex stack-trace frame, used by `DTO_LogMessages.getStackTrace` to keep the
	 * frames of a synthetic trace and drop every other line. A frame is a location token followed by
	 * `: line N, column M`; the token holds any number of dotted segments (the `Class.` prefix, a namespace,
	 * the outer class, an inner class, the method), so an inner class's frame in a namespaced org survives.
	 * A managed frame masked to `(namespace)` in a subscriber org and a blank line have no location and are
	 * dropped. Compiled once because regex compilation is non-trivial.
	 */
	private static final Pattern STACK_LINE = Pattern.compile('^[^\\s:]+: line \\d+, column \\d+$');

	/**
	 * @description The start of each stack-trace line (frame) that belongs to the logging framework itself: the
	 * builder, the engine, and the classes that pass logs from Lightning web components and Flows (the bridges).
	 * These frames are removed from a generated stack trace, so they do not fill the saved `StackTrace__c` field.
	 * Each prefix matches the full start of a class frame (`Class.<resolved name>.`). It takes the name from the
	 * class itself, not from fixed text, so it includes the package namespace in a managed install
	 * (`Class.kern.LOG_Engine.`). It also cannot match a subscriber class whose name only ends with a framework
	 * class name (`Class.AppLOG_Engine.run`). An entry logged through a bridge, with no caller frames left, saves an
	 * empty stack trace rather than a misleading one.
	 */
	private static final Set<String> FRAMEWORK_FRAME_PREFIXES = new Set<String>
	{
			frameworkFramePrefix(LOG_Builder.class),
			frameworkFramePrefix(LOG_Engine.class),
			frameworkFramePrefix(CTRL_Logger.class),
			frameworkFramePrefix(FLOW_LoggerLog.class),
			frameworkFramePrefix(FLOW_LoggerStart.class),
			frameworkFramePrefix(FLOW_LoggerEnd.class),
			frameworkFramePrefix(UTIL_BypassAudit.class)
	};

	/**
	 * @description Format string for the lead line of a persisted DML error message. Tokens are
	 * substituted with the operation name and the failing record id.
	 */
	private static final String DML_ERROR_FORMAT = 'The following {0} for record Id "{1}"';

	/**
	 * @description Format string for `Database.DUPLICATES_DETECTED` errors recorded by
	 * `errorDMLOperationResults`. Tokens: matching SObject + duplicate-rule developer name.
	 */
	private static final String DUPLICATE_ERROR_FORMAT = 'duplicate record was detected on "{0}" based on rule "{1}"';

	/**
	 * @description Format string for general DML errors recorded by `errorDMLOperationResults`.
	 * Tokens: error message + comma-joined field name list.
	 */
	private static final String EXTRACTED_ERROR_FORMAT = 'error occurred "{0}" for the following fields "{1}"';

	/**
	 * @description When test is running, event will not be published unless ignoreTestMode is set to true
	 */
	public static Boolean ignoreTestMode = false;

	/**
	 * @description Set this value to true in an unit test to ensure we test that events can be published by a Queueable job
	 */
	@TestVisible
	private static Boolean simulateDMLimitsBreach = false;

	/**
	 * @description The start of the debug text written when a stored logging context cannot be restored. The error
	 * message follows it.
	 */
	@TestVisible
	private static final String HYDRATION_FAILURE_PREFIX = 'Failed to hydrate logging context. Error: ';

	/**
	 * @description Separates the error from the masked stored context in the debug text written when a stored logging
	 * context cannot be restored.
	 */
	@TestVisible
	private static final String HYDRATION_PAYLOAD_SEPARATOR = ' | Payload: ';

	/**
	 * @description String name of `LoggingLevel.WARN`, read once and kept for the comparisons that run on every
	 * log: the level threshold check and the severity lookup. `LoggingLevel.WARN.name()` calls the platform every
	 * time, so keeping the value saves that cost on each emit.
	 */
	@TestVisible
	private static final String LEVEL_WARN = LoggingLevel.WARN.name();

	/**
	 * @description String name of `LoggingLevel.DEBUG` cached once. Used for default-threshold
	 * setup and ordinal lookups.
	 */
	@TestVisible
	private static final String LEVEL_DEBUG = LoggingLevel.DEBUG.name();

	/**
	 * @description String name of `LoggingLevel.ERROR` cached once. Used by `publishEventsTo` to
	 * detect ERROR entries that bypass the suspended-saving buffer, except inside a platform-event or
	 * change-event trigger the dispatcher runs, where they wait with the rest until the trigger ends.
	 */
	@TestVisible
	private static final String LEVEL_ERROR = LoggingLevel.ERROR.name();

	/**
	 * @description String name of `LoggingLevel.INFO` cached once.
	 */
	@TestVisible
	private static final String LEVEL_INFO = LoggingLevel.INFO.name();

	/**
	 * @description Ordinal weights used by `isLoggable` to compare an entry's level against the
	 * configured `LogSetting__c.LogLevelThreshold__c`. Higher ordinal = more severe.
	 */
	@TestVisible
	private static final Map<String, Integer> LEVEL_ORDINALS = new Map<String, Integer>
	{
			LEVEL_DEBUG => 0, LEVEL_INFO => 1, LEVEL_WARN => 2, LEVEL_ERROR => 3
	};

	/**
	 * @description Default masker performance threshold (ms) applied when `LogSetting__c` is not
	 * configured. Mirrors the field default so behaviour is consistent across configured /
	 * unconfigured orgs.
	 */
	private static final Integer DEFAULT_MASKER_THRESHOLD = 100;

	/**
	 * @description Default general performance threshold (ms) applied when `LogSetting__c` is not
	 * configured.
	 */
	private static final Integer DEFAULT_PERFORMANCE_THRESHOLD = 10000;

	/**
	 * @description Default query performance threshold (ms) applied when `LogSetting__c` is not
	 * configured.
	 */
	private static final Integer DEFAULT_QUERY_THRESHOLD = 1000;

	/**
	 * @description Default trigger performance threshold (ms) applied when `LogSetting__c` is not
	 * configured.
	 */
	private static final Integer DEFAULT_TRIGGER_THRESHOLD = 500;

	/**
	 * @description Default validation performance threshold (ms) applied when `LogSetting__c` is
	 * not configured.
	 */
	private static final Integer DEFAULT_VALIDATION_THRESHOLD = 100;

	/**
	 * @description Override for LogSetting__c. When set, getLogSetting() returns this value
	 * instead of LogSetting__c.getInstance(), enabling tests to control logging behaviour without deploying records.
	 */
	public static LogSetting__c logSettingOverride;

	/**
	 * @description Enum representing the types of operations that can be tracked in the context stack.
	 * Used with pushOperationContext() to categorize log entries by operation type.
	 *
	 * Values:
	 * - API_CALL: Webservice/API operations (inbound or outbound HTTP calls)
	 * - API_BATCH: Batch webservice processing (multiple API calls in a single transaction)
	 * - LWC: LWC client-side operations (logs from Lightning Web Components)
	 * - FLOW: Flow operations (logs from Salesforce Flows)
	 * - TRIGGER_ACTION: Trigger operations (logs from trigger actions)
	 * - QUERY: Query/SOQL operations (database query performance logs)
	 */
	public enum OperationType
	{
		/**
		 * @description Webservice/API operations (inbound or outbound HTTP calls)
		 */
		API_CALL,
		/**
		 * @description Batch webservice processing (multiple API calls in a single transaction)
		 */
		API_BATCH,
		/**
		 * @description LWC client-side operations (logs from Lightning Web Components)
		 */
		LWC,
		/**
		 * @description Flow operations (logs from Salesforce Flows)
		 */
		FLOW,
		/**
		 * @description A trigger action. Used when the framework logs how long a trigger action took; that log entry
		 * carries the trigger details.
		 */
		TRIGGER_ACTION,
		/**
		 * @description Query/SOQL operations (database query performance logs)
		 */
		QUERY,
		/**
		 * @description Validation context operations (validation rule processing performance logs)
		 */
		VALIDATION
	}

	/**
	 * @description The prefix the component bridge puts before a component's name in `ClassMethod__c`. Shared
	 * with `resolveSource`.
	 */
	public static final String COMPONENT_SOURCE_PREFIX = OperationType.LWC.name() + SOURCE_PREFIX_DELIMITER;

	/**
	 * @description Who wrote a log entry: the framework's own code, your Apex, a Flow, or a Lightning web
	 * component. Stored on the entry's `Origin__c` field by `name()`.
	 *
	 * @since 1.8
	 */
	public enum Origin
	{
		/**
		 * @description The framework's own code, recognised by the package namespace on the class name.
		 */
		FRAMEWORK,
		/**
		 * @description Apex outside the framework's namespace.
		 */
		APEX,
		/**
		 * @description A Flow, through one of the framework's Flow actions.
		 */
		FLOW,
		/**
		 * @description A Lightning web component, through the framework's client logger.
		 */
		COMPONENT
	}

	/**
	 * @description Context key for the source of the log entry (e.g., 'LWC', 'Flow', 'Apex').
	 */
	public static final String CONTEXT_SOURCE = 'source';
	/**
	 * @description Context key for the webservice handler class name.
	 */
	public static final String CONTEXT_SERVICE_NAME = 'serviceName';
	/**
	 * @description Context key for the HTTP method (GET, POST, PUT, DELETE, PATCH).
	 */
	public static final String CONTEXT_HTTP_METHOD = 'httpMethod';
	/**
	 * @description Context key for the API endpoint URL.
	 */
	public static final String CONTEXT_ENDPOINT = 'endpoint';
	/**
	 * @description Context key for the HTTP status code.
	 */
	public static final String CONTEXT_STATUS_CODE = 'statusCode';
	/**
	 * @description Context key for callout duration in milliseconds.
	 */
	public static final String CONTEXT_CALLOUT_DURATION_MS = 'calloutDurationMs';
	/**
	 * @description Context key for the SObject type name.
	 */
	public static final String CONTEXT_OBJECT_NAME = 'objectName';
	/**
	 * @description Context key for batch size in batch operations.
	 */
	public static final String CONTEXT_BATCH_SIZE = 'batchSize';
	/**
	 * @description Context key for the record scope (Ids in process) of a failed asynchronous job.
	 */
	public static final String CONTEXT_JOB_SCOPE = 'jobScope';
	/**
	 * @description Context key for whether the platform cut a failed batch job's record scope short because it was too long to carry whole.
	 */
	public static final String CONTEXT_JOB_SCOPE_TRUNCATED = 'jobScopeTruncated';
	/**
	 * @description Context key for the step a failed batch job was in when it failed (START, EXECUTE or FINISH).
	 */
	public static final String CONTEXT_BATCH_PHASE = 'batchPhase';
	/**
	 * @description Context key for the platform's id of the request in which a batch job failed.
	 */
	public static final String CONTEXT_REQUEST_ID = 'requestId';
	/**
	 * @description Context key for the Flow name.
	 */
	public static final String CONTEXT_FLOW_NAME = 'flowName';
	/**
	 * @description Context key for the current Flow step/element.
	 */
	public static final String CONTEXT_FLOW_STEP = 'flowStep';
	/**
	 * @description Context key for the Flow execution status (SUCCESS, FAILED).
	 */
	public static final String CONTEXT_FLOW_STATUS = 'flowStatus';
	/**
	 * @description Context key for the record Id being processed.
	 */
	public static final String CONTEXT_RECORD_ID = 'recordId';
	/**
	 * @description Context key for the trigger action class name.
	 */
	public static final String CONTEXT_ACTION_CLASS_NAME = 'actionClassName';
	/**
	 * @description Context key for the trigger operation (BEFORE_INSERT, AFTER_UPDATE, etc.).
	 */
	public static final String CONTEXT_TRIGGER_OPERATION = 'triggerOperation';
	/**
	 * @description Context key for the number of records being processed.
	 */
	public static final String CONTEXT_RECORD_COUNT = 'recordCount';
	/**
	 * @description Context key for the query type (SOQL, SOSL).
	 */
	public static final String CONTEXT_QUERY_TYPE = 'queryType';
	/**
	 * @description Context key for the SOQL query string.
	 */
	public static final String CONTEXT_SOQL = 'soql';
	/**
	 * @description Context key for JSON-serialized bind variables.
	 */
	public static final String CONTEXT_BIND_VARIABLES = 'bindVariables';
	/**
	 * @description Context key for the number of rows returned.
	 */
	public static final String CONTEXT_ROW_COUNT = 'rowCount';
	/**
	 * @description Context key indicating whether result came from cache.
	 */
	public static final String CONTEXT_IS_CACHED = 'isCached';
	/**
	 * @description Context key for cache status (HIT, MISS, STORED, BYPASS).
	 */
	public static final String CONTEXT_CACHE_STATUS = 'cacheStatus';
	/**
	 * @description Context key for LWC action name.
	 */
	public static final String CONTEXT_ACTION_NAME = 'actionName';
	/**
	 * @description Context key for the JavaScript error stack that the Lightning web component logger captured in
	 * the browser. `CTRL_Logger` saves it in `StackTrace__c` instead of the Apex stack trace, which for these
	 * entries shows only framework code.
	 */
	public static final String CONTEXT_ERROR_STACK = 'errorStack';
	/**
	 * @description Context key for the exception class that a failure in the browser reported: the Apex exception
	 * name that an Aura failure passes on, or the JavaScript error name. `CTRL_Logger` saves it in
	 * `ExceptionType__c`, so a failure in a Lightning web component names its type the way a failure in Apex does,
	 * and is grouped with the same problems.
	 */
	public static final String CONTEXT_EXCEPTION_TYPE = 'exceptionType';
	/**
	 * @description Context key for validation context class name.
	 */
	public static final String CONTEXT_CONTEXT_CLASS_NAME = 'contextClassName';
	/**
	 * @description Context key for validation rule count.
	 */
	public static final String CONTEXT_RULE_COUNT = 'ruleCount';
	/**
	 * @description Context key for the discrete event identifier (e.g., 'flow-action.invoke', 'action.failed').
	 */
	public static final String CONTEXT_EVENT_NAME = 'eventName';
	/**
	 * @description Context key for the human-readable error message attached to a failure entry.
	 */
	public static final String CONTEXT_ERROR_MESSAGE = 'errorMessage';
	/**
	 * @description Context key for an error classification discriminator (e.g., 'configuration', 'runtime').
	 */
	public static final String CONTEXT_ERROR_KIND = 'errorKind';
	/**
	 * @description Context key for elapsed wall-clock duration in milliseconds.
	 */
	public static final String CONTEXT_DURATION_MS = 'durationMs';
	/**
	 * @description Context key for a boolean success/failure indicator.
	 */
	public static final String CONTEXT_SUCCESS = 'success';
	/**
	 * @description Context key for a count of records that errored within a batch.
	 */
	public static final String CONTEXT_ERROR_COUNT = 'errorCount';
	/**
	 * @description Context key for a list of record Ids associated with a batch entry.
	 */
	public static final String CONTEXT_RECORD_IDS = 'recordIds';
	/**
	 * @description Context key for the failure-routing policy applied to an unhandled action exception.
	 */
	public static final String CONTEXT_FAILURE_ACTION = 'failureAction';
	/**
	 * @description Context key that records the original fingerprint key a caller passed. It is written only when
	 * the key was changed (hashed) while being cleaned up, so the stored hash can still be matched to the key the
	 * caller supplied.
	 */
	public static final String CONTEXT_FINGERPRINT_SOURCE = 'fingerprintSource';

	/**
	 * @description Transaction-scoped correlation id propagated onto every emitted
	 * `LogEntryEvent__e.CorrelationId__c`. Set via `startCorrelation()` / `setCorrelationId()`
	 * to thread logs across enqueueable / batch / future hand-offs.
	 */
	@TestVisible
	private static String currentCorrelationId;

	/**
	 * @description Transaction-scoped root correlation id: the tracking id of the action that started everything this
	 * transaction belongs to. Set by the first correlation a request establishes and never moved afterwards; carried
	 * by every context document, so a chain or job that runs under a tracking id of its own still names the action.
	 * Stamped onto every emitted `LogEntryEvent__e.RootCorrelationId__c`.
	 */
	@TestVisible
	private static String currentRootCorrelationId;

	/**
	 * @description The fingerprint for the current emit only. A value that lives for one emit is called a channel.
	 * `LOG_Builder.LogEntry.emitInternal` sets it just before the log call and clears it in its finally block, the
	 * same way it sets and clears the entry's own context. Every `LogEntryEvent__e` built while it is set carries it.
	 */
	private static String currentFingerprint;

	/**
	 * @description The stack trace to use instead of the Apex call stack, for the current emit only.
	 * `LOG_Builder.LogEntry.emitInternal` sets it just before the log call and clears it in its finally block, like
	 * the fingerprint. It is used when the real stack is known but is not the current Apex call stack, for example
	 * a JavaScript stack that `CTRL_Logger` passes on from the browser. A real exception's own stack trace is always
	 * used instead of it.
	 */
	private static String currentStackTrace;

	/**
	 * @description The exception type to record, for the current emit only. `LOG_Builder.LogEntry.emitInternal`
	 * sets it just before the log call and clears it in its finally block, like the stack trace. It is used when the
	 * failure's type is known but no Apex exception carries it, such as the exception class that a failure in the
	 * browser reported and `CTRL_Logger` passes on. A real exception's own type is always used instead of it.
	 */
	private static String currentExceptionType;

	/**
	 * @description Transaction-scoped parent-transaction id stamped onto every emitted
	 * `LogEntryEvent__e.ParentTransactionId__c`. Used to distinguish sub-transactions of a
	 * correlated chain from the originating transaction.
	 */
	@TestVisible
	private static String currentParentTransactionId;

	/**
	 * @description Transaction-scoped key/value pairs serialised into every emitted
	 * `LogEntryEvent__e.ContextData__c` ("global context"). Lazy-allocated so transactions
	 * that never emit a contextual log incur no map allocation.
	 */
	@TestVisible
	private static Map<String, String> globalContextData
	{
		get
		{
			if(globalContextData == null)
			{
				globalContextData = new Map<String, String>();
			}
			return globalContextData;
		}
		private set;
	}

	/**
	 * @description Per-correlation webservice context keyed by correlation id. Each entry holds a
	 * `Map<String, String>` of HTTP / service metadata isolated for that handler so batch
	 * scenarios with concurrent in-flight callouts do not leak service context across handlers.
	 * Lazy-allocated so non-webservice transactions incur no map allocation.
	 */
	@TestVisible
	private static Map<String, Map<String, String>> webserviceContextsByCorrelation
	{
		get
		{
			if(webserviceContextsByCorrelation == null)
			{
				webserviceContextsByCorrelation = new Map<String, Map<String, String>>();
			}
			return webserviceContextsByCorrelation;
		}
		private set;
	}

	/**
	 * @description Whether `LOG_Engine.publishEvents` should buffer incoming events instead of
	 * publishing them immediately. Toggled by `LOG_Builder.suspendSaving()` /
	 * `LOG_Builder.resumeSaving()` to coalesce many emits in trigger/batch contexts before a
	 * single chunked `flushBuffer()` publish.
	 */
	@TestVisible
	private static Boolean isSavingSuspended = false;

	/**
	 * @description Whether the current transaction is executing inside a platform-event /
	 * change-event trigger dispatch where publishing a `LogEntryEvent__e` would make the platform
	 * redeliver the source event and loop. Set by `beginEventTriggerContext` (owned by the outermost
	 * event dispatch) and cleared by `endEventTriggerContext`. While true, `dispatchEvents` persists
	 * logs via direct DML instead of publishing.
	 */
	@TestVisible
	private static Boolean isEventTriggerContext = false;

	/**
	 * @description Whether `beginEventTriggerContext` was the caller that switched suspended-saving
	 * on (it buffers in-context emits for a single bulk persist). When `true`, `endEventTriggerContext`
	 * restores `isSavingSuspended` to `false`; when `false` an outer `LogScope`/`suspendSaving` already
	 * owned suspension and its lifecycle is left untouched.
	 */
	private static Boolean eventContextDidSuspendSaving = false;

	/**
	 * @description Running count of the DML statements the framework used to save its own logs. Inside an event
	 * trigger, `dispatchEvents` saves logs by calling `TRG_PersistLogEntry.persist`. That is the only way the engine
	 * sends logs out that counts in `Limits.getDmlStatements()`; publishing counts in
	 * `Limits.getPublishImmediateDML()` instead. `UTIL_PostTriggerAction.runOne` reads this count through
	 * `getFrameworkLogPersistenceDmlStatements`. A post-action may not do DML, and the check for that subtracts the
	 * engine's own log saves from the DML it measured. So a post-action that logs is not blamed for DML the logger
	 * did. Only the engine changes this value, and it lasts for one transaction, like the event-trigger state above.
	 */
	private static Integer frameworkLogPersistenceDmlStatements = 0;

	/**
	 * @description Application log buffer: the `LogEntryEvent__e` events waiting to be published. It collects
	 * events while `isSavingSuspended` is `true`. `flushBuffer()` then publishes them in batches through
	 * `safePublish`, at most `BATCH_SIZE` events in one publish, so one publish never carries too much data. Audit
	 * entries are kept separately in `auditLogBuffer`, so that `BypassEvent` entries do not change the results of
	 * tests that count this buffer.
	 */
	@TestVisible
	private static List<LogEntryEvent__e> logBuffer
	{
		get
		{
			if(logBuffer == null)
			{
				logBuffer = new List<LogEntryEvent__e>();
			}
			return logBuffer;
		}
		private set;
	}

	/**
	 * @description Audit log buffer. It collects the `BypassEvent` `LogEntryEvent__e` events sent through
	 * `LOG_Engine.publishAuditEvents` (from `LOG_Builder.LogEntry.emitAsAudit()`). `flushBuffer()` publishes it
	 * together with `logBuffer`, so subscribers see a single publisher of platform events. It is kept apart from
	 * `logBuffer` for two reasons. Tests that count the application log buffer are not affected by audit entries.
	 * And it stops a loop where an audit entry is emitted, delivered and saved, and its save emits another one.
	 */
	@TestVisible
	private static List<LogEntryEvent__e> auditLogBuffer
	{
		get
		{
			if(auditLogBuffer == null)
			{
				auditLogBuffer = new List<LogEntryEvent__e>();
			}
			return auditLogBuffer;
		}
		private set;
	}

	/**
	 * @description The buffer size above which `publishEventsTo` publishes the buffer by itself, to limit memory
	 * use when saving stays suspended for a long time. Each batch sent to `safePublish` holds at most
	 * `BATCH_SIZE` (50) events: the engine publishes at most 50 events in one `EventBus.publish` call.
	 */
	private static final Integer MAX_BUFFER_SIZE = 500;

	/**
	 * @description When a test sets this to `true`, `safePublish` throws a `TestSimulatedException`. Tests use it
	 * to check that a failed publish never makes the business transaction fail.
	 */
	@TestVisible
	private static Boolean simulatePublishFailure = false;

	/**
	 * @description Stack of operation contexts for nested operation tracking. Each entry
	 * represents a nested operation (webservice, query, trigger, flow, lwc). Contexts are merged
	 * when serializing to logs; later contexts override earlier ones. Lazy-allocated so
	 * transactions that never push an operation context incur no list allocation.
	 */
	@TestVisible
	private static List<Object> contextStack
	{
		get
		{
			if(contextStack == null)
			{
				contextStack = new List<Object>();
			}
			return contextStack;
		}
		private set;
	}

	/**
	 * @description Maximum depth of context stack to prevent memory issues in deeply nested operations.
	 */
	private static final Integer MAX_CONTEXT_DEPTH = 10;

	/**
	 * @description How many pushes the engine has refused at the cap and not yet seen popped. A pop spends one of
	 * these before it looks at the stack, so a caller whose push was refused never removes the context of the caller
	 * underneath it. Per transaction, like the stack itself.
	 */
	private static Integer refusedPushCount = 0;

	/**
	 * @description Builds the anchored stack-frame prefix (`Class.<resolved name>.`) for a
	 * framework class, resolving the name from the type so it carries the namespace in a managed
	 * install.
	 *
	 * @param frameworkType The framework class whose frames count as the logging framework's own code.
	 *
	 * @return The anchored frame prefix for the class.
	 *
	 * @date July 2026
	 */
	private static String frameworkFramePrefix(Type frameworkType)
	{
		return UTIL_System.STACK_CLASS_PREFIX + frameworkType.getName() + UTIL_String.DOT;
	}

	/**
	 * @description Returns the effective LogSetting__c for the current user.
	 * Uses the hierarchy custom setting order: the user's value, then the profile's, then the org's.
	 * When no record exists, applies code-level defaults matching original AllUsers behaviour.
	 * In tests, returns logSettingOverride when set.
	 *
	 * @return LogSetting__c The effective log setting with defaults applied
	 */
	public static LogSetting__c getLogSetting()
	{
		if(logSettingOverride != null)
		{
			return logSettingOverride;
		}

		LogSetting__c setting = LogSetting__c.getInstance();

		if(setting.LogLevelThreshold__c == null)
		{
			setting.EnablePerformanceLogging__c = true;
			setting.EnableQueryPerformanceLogging__c = true;
			setting.EnableTriggerPerformanceLogging__c = true;
			setting.EnableValidationPerformanceLogging__c = true;
			setting.IsEnabled__c = true;
			setting.LogLevelThreshold__c = LEVEL_DEBUG;
			setting.MaskerPerformanceThresholdMs__c = DEFAULT_MASKER_THRESHOLD;
			setting.PerformanceThresholdMs__c = DEFAULT_PERFORMANCE_THRESHOLD;
			setting.QueryPerformanceThresholdMs__c = DEFAULT_QUERY_THRESHOLD;
			setting.TriggerPerformanceThresholdMs__c = DEFAULT_TRIGGER_THRESHOLD;
			setting.ValidationPerformanceThresholdMs__c = DEFAULT_VALIDATION_THRESHOLD;
		}

		return setting;
	}

	/**
	 * @description writes log with message
	 *
	 * @param longMessage message to be logged
	 * @param classMethod <class>/<method> if applicable
	 * @param logLevel the System.LoggingLevel to log as
	 */
	public static void log(String longMessage, String classMethod, LoggingLevel logLevel)
	{
		log(longMessage, classMethod, (Id)null, logLevel);
	}

	/**
	 * @description will write logs for each of the messages provided
	 *
	 * @param longMessages List of log messages
	 * @param classMethod <class>/<method> if applicable
	 * @param logLevel the System.LoggingLevel to log as
	 */
	public static void log(List<String> longMessages, String classMethod, LoggingLevel logLevel)
	{
		log(new DTO_LogMessages(longMessages, logLevel, classMethod));
	}

	/**
	 * @description writes log with message
	 *
	 * @param longMessage message to be logged
	 * @param classMethod <class>/<method> if applicable
	 * @param recordId record Id related to log event
	 * @param logLevel the System.LoggingLevel to log as
	 */
	public static void log(String longMessage, String classMethod, Id recordId, LoggingLevel logLevel)
	{
		log((String)null, longMessage, classMethod, recordId, logLevel);
	}

	/**
	 * @description writes log with message
	 *
	 * @param shortMessage message to be logged
	 * @param longMessage message to be logged
	 * @param classMethod <class>/<method> if applicable
	 * @param recordId record Id related to log event
	 * @param logLevel the System.LoggingLevel to log as
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	public static void log(String shortMessage, String longMessage, String classMethod, Id recordId, LoggingLevel logLevel)
	{
		log(new DTO_LogMessages(shortMessage, longMessage, recordId, logLevel, classMethod));
	}

	/**
	 * @description writes log with exception data
	 *
	 * @param error the exception to be logged
	 * @param classMethod <class>/<method> if applicable
	 * @param logLevel the System.LoggingLevel to log as
	 */
	public static void log(Exception error, String classMethod, LoggingLevel logLevel)
	{
		log(new DTO_LogMessages(error, logLevel, classMethod));
	}

	/**
	 * @description writes log with exception data
	 *
	 * @param error the exception to be logged
	 * @param classMethod <class>/<method> if applicable
	 * @param recordId record Id related to log event
	 * @param logLevel the System.LoggingLevel to log as
	 */
	public static void log(Exception error, String classMethod, Id recordId, System.LoggingLevel logLevel)
	{
		log(new DTO_LogMessages(error, recordId, logLevel, classMethod));
	}

	/**
	 * @description Writes a log entry with exception data and a summary of the caller's own; the
	 * summary becomes the entry's short message, the exception's text its message, and the stack
	 * trace lands in the entry's own stack-trace field as it does for every exception entry.
	 *
	 * @param error the exception to be logged
	 * @param shortMessage the caller's own summary of the entry
	 * @param classMethod <class>/<method> if applicable
	 * @param recordId record Id related to log event
	 * @param logLevel the System.LoggingLevel to log as
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	public static void log(Exception error, String shortMessage, String classMethod, Id recordId, LoggingLevel logLevel)
	{
		log(new DTO_LogMessages(error, shortMessage, recordId, logLevel, classMethod));
	}

	/**
	 * @description Will iterate through save results from DML operations and log errors encountered
	 *
	 * @param operationResults Results from an DML Operation, could be any of save result types listed below
	 * @param classMethod <class>/<method> if applicable
	 *
	 * @return Will return true if any errors were found and logged
	 *
	 * @see Database.DeleteResult
	 * @see Database.SaveResult
	 * @see Database.UpsertResult
	 */
	public static Boolean log(List<Object> operationResults, String classMethod)
	{
		return log(operationResults, classMethod, LoggingLevel.ERROR);
	}

	/**
	 * @description Iterates DML results and logs every failed row at the given level. ERROR is the level
	 * every framework path uses; DML_Transaction logs a caller's expected refusals at WARN.
	 *
	 * @param operationResults Results from a DML operation, any mix of the four Database result types
	 * @param classMethod <class>/<method> if applicable
	 * @param logLevel The level every failed row is logged at
	 *
	 * @return True if any failed row was found and logged
	 *
	 * @see Database.DeleteResult
	 * @see Database.SaveResult
	 * @see Database.UndeleteResult
	 * @see Database.UpsertResult
	 */
	public static Boolean log(List<Object> operationResults, String classMethod, LoggingLevel logLevel)
	{
		DTO_LogMessages dtoLogMessages = new DTO_LogMessages(logLevel, classMethod);

		for(Object operationResult : operationResults)
		{
			List<Database.Error> errors = getOperationErrors(operationResult);

			if(!errors.isEmpty())
			{
				Id recordId = getOperationRecordId(operationResult);
				dtoLogMessages.addMessage(String.format(DML_ERROR_FORMAT, new List<Object> {extractErrorMessage(errors), recordId}), recordId);
			}
		}

		log(dtoLogMessages);

		return !dtoLogMessages.isEmpty;
	}

	/**
	 * @description Returns the errors carried by a DML result of any of the four Database result types.
	 * A successful result carries none: the list is empty, never null, even for a Database.UndeleteResult,
	 * whose platform-supplied error list is null on success.
	 *
	 * @param operationResult A Database.SaveResult, Database.DeleteResult, Database.UndeleteResult or Database.UpsertResult
	 *
	 * @return The result's errors, empty when the row succeeded
	 */
	public static List<Database.Error> getOperationErrors(Object operationResult)
	{
		List<Database.Error> errors;

		if(operationResult instanceof Database.SaveResult)
		{
			errors = ((Database.SaveResult)operationResult).errors;
		}
		else if(operationResult instanceof Database.DeleteResult)
		{
			errors = ((Database.DeleteResult)operationResult).errors;
		}
		else if(operationResult instanceof Database.UndeleteResult)
		{
			errors = ((Database.UndeleteResult)operationResult).errors;
		}
		else
		{
			errors = ((Database.UpsertResult)operationResult).errors;
		}

		return errors ?? new List<Database.Error>();
	}

	/**
	 * @description Returns the record Id carried by a DML result of any of the four Database result types.
	 *
	 * @param operationResult A Database.SaveResult, Database.DeleteResult, Database.UndeleteResult or Database.UpsertResult
	 *
	 * @return The result's record Id, null when the platform assigned none
	 */
	private static Id getOperationRecordId(Object operationResult)
	{
		if(operationResult instanceof Database.SaveResult)
		{
			return ((Database.SaveResult)operationResult).id;
		}
		if(operationResult instanceof Database.DeleteResult)
		{
			return ((Database.DeleteResult)operationResult).id;
		}
		if(operationResult instanceof Database.UndeleteResult)
		{
			return ((Database.UndeleteResult)operationResult).id;
		}
		return ((Database.UpsertResult)operationResult).id;
	}

	/**
	 * @description Will extract an error message from a database errors provided (assuming operation has failed)
	 *
	 * @param errors The errors encountered
	 *
	 * @return An concatenated error message
	 */
	public static String extractErrorMessage(List<Database.Error> errors)
	{
		List<String> errorMessages = new List<String>();

		for(Database.Error error : errors)
		{
			String errorMessage;

			if(error instanceof Database.DuplicateError)
			{
				// kern-coverage-exempt: Database.DuplicateError and Datacloud.DuplicateResult are platform-synthesised only when an active DuplicateRule matches during DML;
				// managed package test context cannot rely on subscriber-defined duplicate rules
				Datacloud.DuplicateResult duplicateResult = ((Database.DuplicateError)error).getDuplicateResult();
				// kern-coverage-exempt: duplicateRuleEntityType and duplicateRule on the platform-supplied Datacloud.DuplicateResult
				// can only be read from an actual duplicate-rule match emitted by DML runtime
				errorMessage = formatDuplicateError(duplicateResult.duplicateRuleEntityType, duplicateResult.duplicateRule);
			}
			else
			{
				errorMessage = error.getMessage();
				String fields = UTIL_String.join(error.getFields(), UTIL_String.COMMA);

				errorMessage = String.format(EXTRACTED_ERROR_FORMAT, new List<String>
				{
						errorMessage, fields
				});
			}

			errorMessages.add(errorMessage);
		}

		return UTIL_String.join(errorMessages, UTIL_String.COMMA);
	}

	/**
	 * @description Formats a duplicate error message from entity type and rule name.
	 *
	 * @param entityType The SObject type that triggered the duplicate rule.
	 * @param ruleName The name of the duplicate rule that matched.
	 *
	 * @return The formatted duplicate error message.
	 */
	@TestVisible
	private static String formatDuplicateError(String entityType, String ruleName)
	{
		return String.format(DUPLICATE_ERROR_FORMAT, new List<String> {entityType, ruleName});
	}

	/**
	 * @description will write logs for each of the messages provided
	 *
	 * @param dtoLogMessages List of log messages
	 */
	private static void log(DTO_LogMessages dtoLogMessages)
	{
		log(dtoLogMessages, false);
	}

	/**
	 * @description A version of `log(DTO_LogMessages)` that can send to the audit log. When `isAudit` is `true`, it
	 * sends the resulting `LogEntryEvent__e` events through `publishAuditEvents`, so they collect in the separate
	 * audit buffer instead of the application log buffer.
	 *
	 * In a test, audit entries are emitted only when the test sets `LOG_Builder.ignoreTestMode = true`, the same
	 * as application logs. Without it, an audit entry returns BEFORE `dtoLogMessages.getEvents()` runs. So the
	 * framework's first lookups of custom metadata and EntityDefinition (made by
	 * `UTIL_FrameworkMasker.isMaskingEnabled` inside `getEvents`) do not add queries to tests that do not test
	 * the audit log. Tests that DO test the audit log set `ignoreTestMode = true`.
	 *
	 * @param dtoLogMessages List of log messages.
	 * @param isAudit `true` to route to the audit buffer (`publishAuditEvents`); `false` for app.
	 */
	private static void log(DTO_LogMessages dtoLogMessages, Boolean isAudit)
	{
		if(!dtoLogMessages.isEmpty && isLoggable(dtoLogMessages.logLevel, dtoLogMessages.classMethod))
		{
			if(isAudit && Test.isRunningTest() && !ignoreTestMode)
			{
				return;
			}
			List<LogEntryEvent__e> events = dtoLogMessages.getEvents();
			if(isAudit)
			{
				publishAuditEvents(events);
			}
			else
			{
				publishEvents(events);
			}
			deliverInTestWithEmitChannelsClosed();
		}
	}

	/**
	 * @description A version of `log(String, String, String, Id, LoggingLevel)` that sends to the audit log.
	 * `LOG_Builder.LogEntry.emitAsAudit()` uses it to send `BypassEvent` audit entries to the separate audit buffer,
	 * so they do not change the results of tests that count the application log buffer.
	 * It is public, not global, so subscribers cannot call it.
	 *
	 * @param shortMessage Short message for the log entry.
	 * @param longMessage Long message body for the log entry.
	 * @param classMethod `<class>/<method>` location identifier.
	 * @param recordId Optional related record id.
	 * @param logLevel `System.LoggingLevel` of the entry.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	public static void logAudit(String shortMessage, String longMessage, String classMethod, Id recordId, LoggingLevel logLevel)
	{
		log(new DTO_LogMessages(shortMessage, longMessage, recordId, logLevel, classMethod), true);
	}

	/**
	 * @description Determines whether an entry should be logged based on the hierarchical LogSetting__c.
	 * Checks in this order: ERROR always passes, then the switch that turns logging off, then the level threshold,
	 * then the class filter.
	 *
	 * @param logLevel The debug logging level
	 * @param classMethod The class/method context (e.g., 'ClassName/methodName')
	 *
	 * @return Whether the entry should be logged
	 */
	@TestVisible
	private static Boolean isLoggable(LoggingLevel logLevel, String classMethod)
	{
		String logLevelName = logLevel.name();

		if(LEVEL_ERROR.equals(logLevelName))
		{
			return true;
		}

		LogSetting__c setting = getLogSetting();

		if(!setting.IsEnabled__c)
		{
			return false;
		}

		Integer entryOrdinal = LEVEL_ORDINALS.get(logLevelName);
		Integer thresholdOrdinal = LEVEL_ORDINALS.get(setting.LogLevelThreshold__c);

		if(entryOrdinal == null || thresholdOrdinal == null || entryOrdinal < thresholdOrdinal)
		{
			return false;
		}

		String classFilter = setting.ClassFilter__c;
		String suppressFilter = setting.SuppressClassMethod__c;

		if((String.isNotBlank(classFilter) || String.isNotBlank(suppressFilter)) && String.isNotBlank(classMethod))
		{
			String className = extractClassName(classMethod);

			if(String.isNotBlank(className))
			{
				if(String.isNotBlank(classFilter) && !matchesClassFilter(className, classFilter))
				{
					return false;
				}
				if(String.isNotBlank(suppressFilter) && matchesClassFilter(className, suppressFilter))
				{
					return false;
				}
			}
		}

		return true;
	}

	/**
	 * @description Returns the severity rank of a log level (DEBUG < INFO < WARN < ERROR). This is the same order
	 * the framework uses to compare a level with the configured threshold. It is public so that readers of the
	 * log (the Log Console) sort the Level column by severity, matching the `LogLevel__c` picklist order the
	 * All-entries view sorts by, rather than re-implementing the ranking. Returns -1 for a null or unknown level
	 * so such rows sort before DEBUG on an ascending sort.
	 *
	 * @param level The log level name (e.g. 'ERROR').
	 *
	 * @return The severity rank (DEBUG=0, INFO=1, WARN=2, ERROR=3), or -1 for a null or unrecognised level.
	 *
	 * @date July 2026
	 *
	 * @example
	 * ```apex
	 * Integer rank = LOG_Engine.levelSeverityRank('WARN');
	 * ```
	 */
	public static Integer levelSeverityRank(String level)
	{
		Integer rank = LEVEL_ORDINALS.get(level);
		return rank == null ? -1 : rank;
	}

	/**
	 * @description Works out the class and method an entry was written at from the stack the engine built for it.
	 * The top frame of that stack is the caller's, because the framework's own frames have already been taken out.
	 * A frame names a location and then its line, so the text before the first colon is the location, and the
	 * `Class.` or `Trigger.` a frame opens with is dropped because the writer's name is what follows it. A top frame
	 * that is not a frame at all gives nothing back, so the entry keeps no class-method rather than a wrong one.
	 *
	 * @param stackTrace The caller's frames, newest first, or blank when no frames were left after the framework's.
	 *
	 * @return The class and method the top frame names, or null when there is no readable frame on top.
	 *
	 * @example
	 * ```apex
	 * String classMethod = LOG_Engine.resolveClassMethodFromStack('Class.OrderService.submit: line 12, column 1');
	 * ```
	 */
	public static String resolveClassMethodFromStack(String stackTrace)
	{
		String topFrame = (stackTrace ?? UTIL_String.EMPTY).substringBefore(UTIL_String.LF).trim();
		Integer locationEndIndex = topFrame.indexOf(UTIL_String.COLON);
		String location = locationEndIndex > 0 ? topFrame.substring(0, locationEndIndex) : null;
		return UTIL_System.stripFrameQualifier(location);
	}

	/**
	 * @description Works out who wrote an entry. A Flow or component bridge's operation context on top of the
	 * stack wins; otherwise a class name that starts with the package namespace is the framework's own; anything
	 * else is Apex outside the framework. The method reads nothing else: the caller passes the namespace prefix, so
	 * a test can reach the Framework result even in an org with no namespace.
	 *
	 * @param classMethod The class and method the entry was written at, as the builder received it.
	 * @param namespacePrefix The package namespace followed by a dot (`kern.`), or blank in an org with no namespace.
	 * @param operationType The operation type on top of the context stack, or null when the stack is empty.
	 *
	 * @return The origin; never null.
	 *
	 * @example
	 * ```apex
	 * LOG_Engine.Origin origin = LOG_Engine.resolveOrigin('kern.UTIL_AsyncChain.ChainExecutor.execute', 'kern.', null);
	 * ```
	 */
	public static Origin resolveOrigin(String classMethod, String namespacePrefix, String operationType)
	{
		if(LOG_Engine.OperationType.FLOW.name() == operationType)
		{
			return Origin.FLOW;
		}
		if(LOG_Engine.OperationType.LWC.name() == operationType)
		{
			return Origin.COMPONENT;
		}
		if(String.isNotBlank(namespacePrefix) && classMethod?.startsWith(namespacePrefix) == true)
		{
			return Origin.FRAMEWORK;
		}
		return Origin.APEX;
	}

	/**
	 * @description The writer's plain name for grouping: the namespace prefix goes first, and so does a namespace of
	 * the org's own when Apex can see the class in it. After a Flow prefix the name runs to the next slash, or to the
	 * end, because a Flow may have a dot in its own name. Anything else keeps the text before the first slash or dot,
	 * which is the rule `extractClassName` has always applied. The name is only a good guess for grouping, never an
	 * exact identity; `ClassMethod__c` keeps the exact location.
	 *
	 * @param classMethod The class and method the entry was written at.
	 * @param namespacePrefix The package namespace followed by a dot, or blank.
	 *
	 * @return The source name, or null when the class-method is blank or nothing remains after the prefixes.
	 *
	 * @example
	 * ```apex
	 * String source = LOG_Engine.resolveSource('LWC/orderPanel.submitOrder', 'kern.'); // orderPanel
	 * ```
	 */
	public static String resolveSource(String classMethod, String namespacePrefix)
	{
		if(String.isBlank(classMethod))
		{
			return null;
		}

		String remainder = removePrefix(classMethod, namespacePrefix);
		String source;

		if(remainder.startsWith(FLOW_SOURCE_PREFIX))
		{
			source = remainder.substring(FLOW_SOURCE_PREFIX.length()).substringBefore(SOURCE_PREFIX_DELIMITER);
		}
		else if(remainder.startsWith(COMPONENT_SOURCE_PREFIX))
		{
			source = extractClassName(remainder.substring(COMPONENT_SOURCE_PREFIX.length()));
		}
		else
		{
			source = extractClassName(removeNamespaceApexCanSee(remainder));
		}

		return String.isBlank(source) ? null : source;
	}

	/**
	 * @description Removes a leading namespace that is not the package's, such as the namespace of the org itself, so a
	 * class in such an org groups under its class name and not under the namespace. The first word is taken as a
	 * namespace when Apex can see a class named by the second word in it; a location with no second word, or whose first
	 * word is no namespace, is returned unchanged.
	 *
	 * @param location The class-method with the package prefix already removed.
	 *
	 * @return The location without its namespace, or the location as given.
	 */
	private static String removeNamespaceApexCanSee(String location)
	{
		Integer firstDot = location.indexOf(UTIL_String.DOT);

		if(firstDot <= 0)
		{
			return location;
		}

		String namespace = location.substring(0, firstDot);
		String afterNamespace = location.substring(firstDot + 1);
		String className = afterNamespace.substringBefore(UTIL_String.DOT).substringBefore(SOURCE_PREFIX_DELIMITER);

		return UTIL_System.isClassInNamespace(namespace, className) ? afterNamespace : location;
	}

	/**
	 * @description Removes a leading prefix when the value starts with it; otherwise returns the value unchanged.
	 *
	 * @param value The text to trim.
	 * @param prefix The prefix to remove, or blank for none.
	 *
	 * @return The value without the prefix.
	 */
	private static String removePrefix(String value, String prefix)
	{
		return String.isNotBlank(prefix) && value?.startsWith(prefix) == true ? value.substring(prefix.length()) : value;
	}

	/**
	 * @description Extracts the source class name from a ClassMethod value. It is the one method that reads the
	 * `ClassMethod__c` format this engine writes. It handles both the 'ClassName/methodName' (test) and
	 * 'ClassName.methodName' forms, and returns the full text when there is no separator. It is public so that
	 * readers of the log (the Log Console) interpret the source class exactly as the engine records it, rather
	 * than re-implementing the split.
	 *
	 * @param classMethod The class/method string.
	 *
	 * @return The class name portion, or the full string if no separator found.
	 *
	 * @example
	 * ```apex
	 * String className = LOG_Engine.extractClassName('AccountTriggerHandler.handleAfterUpdate');
	 * ```
	 */
	public static String extractClassName(String classMethod)
	{
		if(String.isBlank(classMethod))
		{
			return classMethod;
		}

		Integer slashIndex = classMethod.indexOf('/');

		if(slashIndex > 0)
		{
			return classMethod.substring(0, slashIndex);
		}

		Integer dotIndex = classMethod.indexOf(UTIL_String.DOT);

		if(dotIndex > 0)
		{
			return classMethod.substring(0, dotIndex);
		}

		return classMethod;
	}

	/**
	 * @description Checks whether a class name matches a comma-separated filter pattern.
	 * Each pattern is trimmed and supports a trailing wildcard (*).
	 * An exact match or a startsWith match (when pattern ends with *) returns true.
	 *
	 * @param className The class name to check
	 * @param filterPattern Comma-separated patterns (e.g., 'API_*,SVC_Payment*')
	 *
	 * @return Whether the class name matches any pattern
	 */
	@TestVisible
	private static Boolean matchesClassFilter(String className, String filterPattern)
	{
		for(String pattern : filterPattern.split(UTIL_String.COMMA))
		{
			String trimmed = pattern.trim();

			if(String.isBlank(trimmed))
			{
				continue;
			}

			if(trimmed.endsWith('*'))
			{
				if(className.startsWith(trimmed.removeEnd('*')))
				{
					return true;
				}
			}
			else if(className.equals(trimmed))
			{
				return true;
			}
		}

		return false;
	}

	/**
	 * @description Generates and sets a new correlation ID for this transaction. The first correlation a request
	 * establishes also becomes its root; a later start never moves the root.
	 *
	 * @return String The generated correlation ID
	 */
	public static String startCorrelation()
	{
		currentCorrelationId = UTIL_Random.randomUUID();
		adoptRootCorrelationIfBlank(currentCorrelationId);
		return currentCorrelationId;
	}

	/**
	 * @description Sets the correlation ID (for child transactions). The first correlation a request establishes also
	 * becomes its root; a later set never moves the root.
	 *
	 * @param correlationId The correlation ID from parent transaction
	 */
	public static void setCorrelationId(String correlationId)
	{
		currentCorrelationId = correlationId;
		adoptRootCorrelationIfBlank(correlationId);
	}

	/**
	 * @description Returns the tracking id that groups the log entries of related work. It is set by startCorrelation,
	 * setCorrelationId or hydrateContext; the value is read as it is, nothing is generated here.
	 *
	 * @return String The current correlation ID or null
	 */
	public static String getCorrelationId()
	{
		return currentCorrelationId;
	}

	/**
	 * @description Returns the root correlation id: the tracking id of the action that started everything this
	 * transaction belongs to. It equals the correlation id until a chain or job continues the action under a tracking
	 * id of its own.
	 *
	 * @return String The root correlation id, or null when no correlation has been established
	 */
	public static String getRootCorrelationId()
	{
		return currentRootCorrelationId;
	}

	/**
	 * @description Makes the supplied id the root when this request has none yet. The first correlation a request
	 * establishes names the action; a later change of the live correlation never moves the root.
	 *
	 * @param correlationId The correlation just established
	 */
	private static void adoptRootCorrelationIfBlank(String correlationId)
	{
		if(String.isBlank(currentRootCorrelationId) && String.isNotBlank(correlationId))
		{
			currentRootCorrelationId = correlationId;
		}
	}

	/**
	 * @description Sets the fingerprint applied to events built during the current emit call.
	 * It is public, not global, so subscribers set a fingerprint through `LOG_Builder.withFingerprint` instead.
	 *
	 * @param fingerprintKey The normalized grouping key.
	 */
	public static void setCurrentFingerprint(String fingerprintKey)
	{
		currentFingerprint = fingerprintKey;
	}

	/**
	 * @description Clears the fingerprint set for the current emit, so it cannot reach later entries.
	 */
	public static void clearCurrentFingerprint()
	{
		currentFingerprint = null;
	}

	/**
	 * @description Sets the stack trace to use, instead of the Apex call stack, for events built during the
	 * current emit call. It is public, not global, so subscribers go through `LOG_Builder`. The class that passes
	 * Lightning web component logs to Apex uses it to save the JavaScript stack from the browser instead of the
	 * Apex stack. The text is cut to the length of the `StackTrace__c` field.
	 *
	 * @param stackTrace The caller-supplied stack trace text.
	 *
	 * @date July 2026
	 */
	public static void setCurrentStackTrace(String stackTrace)
	{
		currentStackTrace = UTIL_String.abbreviate(stackTrace, UTIL_SObjectDescribe.getCachedFieldDescribe(LogEntryEvent__e.StackTrace__c).length);
	}

	/**
	 * @description Clears the stack trace set for the current emit, so it cannot reach later entries.
	 *
	 * @date July 2026
	 */
	public static void clearCurrentStackTrace()
	{
		currentStackTrace = null;
	}

	/**
	 * @description Sets the exception type applied to events built during the current emit call.
	 * It is public, not global, so subscribers go through `LOG_Builder`. The class that passes Lightning web
	 * component logs to Apex uses it to name the failure the browser reported when no Apex exception carries that
	 * name. The text is cut to the length of the `ExceptionType__c` field, so a name that is too long loses only its
	 * end, and the entry is still saved.
	 *
	 * @param exceptionType The caller-supplied exception class name.
	 */
	public static void setCurrentExceptionType(String exceptionType)
	{
		currentExceptionType = UTIL_String.abbreviate(exceptionType, UTIL_SObjectDescribe.getCachedFieldDescribe(LogEntryEvent__e.ExceptionType__c).length);
	}

	/**
	 * @description Clears the exception type set for the current emit, so it cannot reach later entries.
	 */
	public static void clearCurrentExceptionType()
	{
		currentExceptionType = null;
	}

	/**
	 * @description Sets the parent transaction ID for hierarchical tracking.
	 *
	 * @param parentTransactionId The parent's transaction ID
	 */
	public static void setParentTransactionId(String parentTransactionId)
	{
		currentParentTransactionId = parentTransactionId;
	}

	/**
	 * @description Serializes current context for transfer to async jobs.
	 *
	 * @return String JSON containing correlationId, parentTransactionId, contextData (if any)
	 */
	public static String serializeContext()
	{
		DTO_LoggerContext context = new DTO_LoggerContext();
		context.correlationId = currentCorrelationId;
		context.rootCorrelationId = currentRootCorrelationId;
		context.parentTransactionId = Request.getCurrent()?.getRequestId();
		if(!globalContextData.isEmpty())
		{
			context.contextData = globalContextData;
		}
		return JSON.serializePretty(context, true);
	}

	/**
	 * @description Serializes a logging context FOR the supplied correlation id. The result is a small document that
	 * carries only that id. It carries no parent transaction and none of the current context values, because it is
	 * written for a DIFFERENT run and outlives this request. The current transaction's context is never read or
	 * changed. Changing it instead (set, serialize, restore) would put the wrong id on every log this transaction
	 * emits after the restore.
	 *
	 * @param correlationId The correlation id the serialized context carries.
	 *
	 * @return String JSON carrying exactly the supplied correlationId.
	 */
	public static String serializeContext(String correlationId)
	{
		DTO_LoggerContext context = new DTO_LoggerContext();
		context.correlationId = correlationId;
		return JSON.serializePretty(context, true);
	}

	/**
	 * @description Serializes the current context under the supplied correlation id: the full document (the parent
	 * transaction id, the root correlation id, the context values) with the correlation replaced, for an execution that
	 * continues this transaction's story under a tracking id of its own, such as a chain run. The live context is
	 * read, never changed. When this request has no root yet, the live correlation is the root; when it has neither,
	 * the supplied id is the root, because the execution starts the action.
	 *
	 * @param correlationId The correlation id the serialized context carries
	 *
	 * @return String JSON context for the supplied correlation id, ready for hydrateContext
	 */
	public static String serializeContextWithCorrelationId(String correlationId)
	{
		DTO_LoggerContext context = new DTO_LoggerContext();
		context.correlationId = correlationId;
		String liveRootCorrelationId = String.isNotBlank(currentRootCorrelationId) ? currentRootCorrelationId : currentCorrelationId;
		context.rootCorrelationId = String.isNotBlank(liveRootCorrelationId) ? liveRootCorrelationId : correlationId;
		context.parentTransactionId = Request.getCurrent()?.getRequestId();
		if(!globalContextData.isEmpty())
		{
			context.contextData = globalContextData;
		}
		return JSON.serializePretty(context, true);
	}

	/**
	 * @description Rewrites a stored context document so it carries the supplied correlation id, keeping the root, the
	 * parent transaction id and the context values it already holds. A document without a root names its old
	 * correlation as the root; a blank or unreadable document becomes one carrying the supplied id as both. Used when a
	 * run is cloned by a restart and must keep the launch's context under an id of its own.
	 *
	 * @param serializedContext The stored JSON context, from serializeContext or serializeContextWithCorrelationId
	 * @param correlationId The correlation id the rewritten context carries
	 *
	 * @return String JSON context carrying the supplied correlation id, ready for hydrateContext
	 */
	public static String replaceCorrelationId(String serializedContext, String correlationId)
	{
		DTO_LoggerContext context = new DTO_LoggerContext();
		try
		{
			if(String.isNotBlank(serializedContext))
			{
				context = (DTO_LoggerContext)JSON.deserialize(serializedContext, DTO_LoggerContext.class);
			}
		}
		catch(JSONException unreadable)
		{
			context = new DTO_LoggerContext();
		}
		String storedRootCorrelationId = String.isNotBlank(context.rootCorrelationId) ? context.rootCorrelationId : context.correlationId;
		context.rootCorrelationId = String.isNotBlank(storedRootCorrelationId) ? storedRootCorrelationId : correlationId;
		context.correlationId = correlationId;
		return JSON.serializePretty(context, true);
	}

	/**
	 * @description Restores context from serialized string in async jobs. A document without a root, written before
	 * roots existed, restores with its correlation as the root. Restoring replaces the live correlation, root and
	 * parent transaction, because the document describes the execution this transaction continues.
	 *
	 * @param serializedContext JSON from serializeContext()
	 */
	@SuppressWarnings('PMD.AvoidDebugStatements')
	public static void hydrateContext(String serializedContext)
	{
		if(String.isBlank(serializedContext))
		{
			return;
		}

		try
		{
			DTO_LoggerContext context = (DTO_LoggerContext)JSON.deserialize(serializedContext, DTO_LoggerContext.class);
			currentCorrelationId = context.correlationId;
			currentRootCorrelationId = String.isNotBlank(context.rootCorrelationId) ? context.rootCorrelationId : context.correlationId;
			currentParentTransactionId = context.parentTransactionId;

			if(context.contextData != null)
			{
				globalContextData = context.contextData;
			}
		}
		catch(Exception error)
		{
			System.debug(LoggingLevel.WARN, describeHydrationFailure(error, serializedContext));
		}
	}

	/**
	 * @description Builds the debug text for a stored context that could not be restored: the error, then the stored
	 * context so the lost correlation can be traced. The stored context goes through the same masking a log entry's context
	 * data gets before it is published. When masking blocks the text or fails, or the masking switch itself cannot be read,
	 * the text holds the error alone, so the stored context never reaches the debug log unmasked. Nothing in this method
	 * throws, so the catch in hydrateContext that calls it cannot throw either.
	 *
	 * @param error The failure raised while restoring the stored context
	 * @param serializedContext The stored context that could not be restored
	 *
	 * @return The error, followed by the stored context as masking left it, or the error alone when masking did not complete
	 */
	@TestVisible
	private static String describeHydrationFailure(Exception error, String serializedContext)
	{
		String failure = HYDRATION_FAILURE_PREFIX + error.getMessage();
		LogEntryEvent__e carrier = new LogEntryEvent__e(ContextData__c = serializedContext);

		try
		{
			if(UTIL_FrameworkMasker.isMaskingEnabled)
			{
				UTIL_FrameworkMasker.forRecord(carrier).apply();
			}
		}
		catch(Exception maskingFailure)
		{
			return failure;
		}

		return failure + HYDRATION_PAYLOAD_SEPARATOR + carrier.ContextData__c;
	}

	/**
	 * @description Tells whether a stored context document was written by the request now running: the document names
	 * this request as its parent transaction. Such a document describes the live context itself, so restoring it would
	 * only make the transaction its own parent. A blank or unreadable document, and one that names no parent, were not
	 * written by this request.
	 *
	 * @param serializedContext The stored JSON context, from serializeContext or serializeContextWithCorrelationId
	 *
	 * @return True when the document names the request now running as its parent transaction
	 */
	public static Boolean wasContextWrittenByCurrentRequest(String serializedContext)
	{
		if(String.isBlank(serializedContext))
		{
			return false;
		}

		try
		{
			DTO_LoggerContext context = (DTO_LoggerContext)JSON.deserialize(serializedContext, DTO_LoggerContext.class);
			String currentRequestId = Request.getCurrent()?.getRequestId();
			return String.isNotBlank(currentRequestId) && currentRequestId.equals(context.parentTransactionId);
		}
		catch(JSONException unreadable)
		{
			return false;
		}
	}

	/**
	 * @description Logs a performance metric entry.
	 *
	 * @param message The performance message
	 * @param details Additional metric details
	 * @param classMethod The class.method context
	 * @param durationMs The operation duration
	 */
	public static void logPerformance(String message, String details, String classMethod, Long durationMs)
	{
		DTO_LogMessages dtoLogMessages = new DTO_LogMessages(message, details, null, LoggingLevel.DEBUG, classMethod);
		dtoLogMessages.durationMs = durationMs;

		if(!dtoLogMessages.isEmpty && isLoggable(LoggingLevel.DEBUG, classMethod))
		{
			publishEvents(dtoLogMessages.getEvents());

			deliverInTestWithEmitChannelsClosed();
		}
	}

	/**
	 * @description Sets a global context value for all logs in this transaction.
	 * Complex objects (Maps, Lists, SObjects) are JSON serialized to ensure valid output.
	 *
	 * @param key The context key
	 * @param value The context value (primitives or complex objects)
	 */
	public static void setGlobalContext(String key, Object value)
	{
		if(String.isNotBlank(key) && value != null)
		{
			// Primitives can use String.valueOf; complex objects need JSON serialization
			if(value instanceof String || value instanceof Integer || value instanceof Long ||
					value instanceof Decimal || value instanceof Boolean || value instanceof Id)
			{
				globalContextData.put(key, String.valueOf(value));
			}
			else
			{
				try
				{
					globalContextData.put(key, JSON.serialize(value));
				}
				catch(Exception error)
				{
					// Fallback for non-serializable objects (e.g. HttpRequest)
					globalContextData.put(key, String.valueOf(value));
				}
			}
		}
	}

	/**
	 * @description Removes one key from the global context, so log entries emitted later in this transaction no
	 * longer carry it. Does nothing when the key is not there.
	 *
	 * @param key The key to remove
	 */
	public static void clearGlobalContext(String key)
	{
		globalContextData.remove(key);
	}

	/**
	 * @description Empties the global context, including values restored by hydrateContext, so log entries emitted
	 * later in this transaction carry none of them. The operation context stack and the webservice context are
	 * not touched.
	 */
	public static void clearAllGlobalContext()
	{
		globalContextData.clear();
	}

	/**
	 * @description Pushes a new operation context onto the stack.
	 * The context will be merged with parent contexts when logging.
	 * Use this at the start of operations (webservice, query, trigger, flow, lwc).
	 *
	 * Once the stack already holds as many contexts as the engine keeps, the push is refused and nothing is added.
	 * The engine remembers the refusal, so the `popOperationContext()` that goes with it removes nothing and the
	 * caller underneath keeps the context it pushed.
	 *
	 * @param operationType The type of operation from the OperationType enum (WEBSERVICE, QUERY,
	 *        TRIGGER_ACTION, FLOW, LWC, WEBSERVICE_BATCH)
	 * @param contextData Key-value pairs of context information specific to this operation
	 *
	 * @example
	 * ```apex
	 * LOG_Engine.pushOperationContext(LOG_Engine.OperationType.QUERY, new Map<String, String>{
	 *     CONTEXT_OBJECT_NAME => 'Account',
	 *     CONTEXT_QUERY_TYPE => 'SOQL'
	 * });
	 * try {
	 *     // ... query execution ...
	 * } finally {
	 *     LOG_Engine.popOperationContext();
	 * }
	 * ```
	 */
	public static void pushOperationContext(OperationType operationType, Map<String, String> contextData)
	{
		if(contextStack.size() >= MAX_CONTEXT_DEPTH)
		{
			refusedPushCount++;
			return; // Prevent memory issues in deeply nested operations
		}

		Map<String, String> context = new Map<String, String>();
		context.put('_operationType', operationType.name());
		context.put('_depth', String.valueOf(contextStack.size()));

		if(contextData != null)
		{
			context.putAll(contextData);
		}

		contextStack.add(context);
	}

	/**
	 * @description Pops the most recent operation context from the stack.
	 * Call this when an operation completes to prevent context bleeding into subsequent logs.
	 * Always use in a finally block to ensure cleanup even on exceptions.
	 *
	 * A pop that goes with a push the engine refused at the cap removes nothing: it spends the refusal instead, so
	 * the context of the caller underneath survives.
	 */
	public static void popOperationContext()
	{
		if(refusedPushCount > 0)
		{
			refusedPushCount--;
			return;
		}

		if(!contextStack.isEmpty())
		{
			contextStack.remove(contextStack.size() - 1);
		}
	}

	/**
	 * @description Gets the current operation type from the top of the stack.
	 *
	 * @return The operation type string, or null if stack is empty
	 */
	public static String getCurrentOperationType()
	{
		if(contextStack.isEmpty())
		{
			return null;
		}
		return ((Map<String, String>)UTIL_List.peek(contextStack)).get('_operationType');
	}

	/**
	 * @description Returns the current depth of the context stack.
	 * Useful for debugging nested operation tracking.
	 *
	 * @return Integer The number of contexts currently on the stack
	 */
	public static Integer getContextStackDepth()
	{
		return contextStack.size();
	}

	/**
	 * @description Clears the entire context stack.
	 * Use at the start of a new transaction or after error recovery to ensure clean state.
	 * Any pushes the engine refused at the cap are forgotten with it, so the next pop works on the cleared stack.
	 */
	public static void clearContextStack()
	{
		contextStack.clear();
		refusedPushCount = 0;
	}

	/**
	 * @description Merges all contexts in the stack into a single map.
	 * Later contexts override earlier ones for the same keys.
	 * Order: globalContext, then stack[0], stack[1] and so on, then webserviceContext.
	 *
	 * @return Map<String, String> Merged context map containing all context data
	 */
	@TestVisible
	private static Map<String, String> getMergedContext()
	{
		Map<String, String> merged = new Map<String, String>();

		// 1. Start with global context (base layer)
		merged.putAll(globalContextData);

		// 2. Layer on each stack context (later overrides earlier)
		for(Integer i = 0; i < contextStack.size(); i++)
		{
			merged.putAll((Map<String, String>)UTIL_List.peekAt(contextStack, i));
		}

		// 3. Add webservice context if present (backward compatibility)
		String correlationKey = getCurrentOrDefaultCorrelation();
		Map<String, String> webserviceContext = webserviceContextsByCorrelation.get(correlationKey);
		if(webserviceContext != null && !webserviceContext.isEmpty())
		{
			merged.putAll(webserviceContext);
		}

		return merged;
	}

	/**
	 * @description Merges all context sources (global, stack, webservice) and serializes to JSON via DTO with truncation.
	 * Order: global context first, then the stack contexts, then the webservice context for the current
	 * correlation, which overrides the others.
	 * Uses MaxContextDataSize__c from active filter if configured, otherwise uses default field length.
	 *
	 * @return String JSON serialized context using DTO_LoggerContext structure, or null if empty
	 */
	private static String serializeContextData()
	{
		Map<String, String> merged = getMergedContext();

		if(merged.isEmpty())
		{
			return null;
		}

		// Use DTO for consistent serialization/deserialization
		DTO_LoggerContext dto = new DTO_LoggerContext();
		dto.contextData = merged;

		String serialized = JSON.serializePretty(dto, true);

		return UTIL_String.abbreviate
				(
						serialized,
						(Integer)getLogSetting().MaxContextDataSize__c ?? UTIL_SObjectDescribe.getCachedFieldDescribe(LogEntryEvent__e.ContextData__c).length
				);
	}

	/**
	 * @description Sets webservice context for a specific correlation ID.
	 * Each handler in a batch gets its own isolated context.
	 *
	 * @param correlationId The handler's correlation ID (null uses current correlation)
	 * @param serviceName The API class name (e.g., 'API_SendEmail')
	 * @param endpoint The target URL
	 * @param httpMethod The HTTP method (GET, POST, etc.)
	 */
	public static void setWebserviceContext(String correlationId, String serviceName, String endpoint, String httpMethod)
	{
		String key = String.isNotBlank(correlationId) ? correlationId : getCurrentOrDefaultCorrelation();
		Map<String, String> context = webserviceContextsByCorrelation.get(key);

		if(context == null)
		{
			context = new Map<String, String>();
			webserviceContextsByCorrelation.put(key, context);
		}

		context.put(CONTEXT_SERVICE_NAME, serviceName);
		context.put(CONTEXT_ENDPOINT, endpoint);
		context.put(CONTEXT_HTTP_METHOD, httpMethod);
	}

	/**
	 * @description Updates webservice context after callout completes.
	 *
	 * @param correlationId The handler's correlation ID (null uses current correlation)
	 * @param statusCode The HTTP response status code
	 * @param durationMs The callout duration in milliseconds
	 */
	public static void updateWebserviceContext(String correlationId, String statusCode, Long durationMs)
	{
		String key = String.isNotBlank(correlationId) ? correlationId : getCurrentOrDefaultCorrelation();
		Map<String, String> context = webserviceContextsByCorrelation.get(key);
		if(context == null)
		{
			context = new Map<String, String>();
			webserviceContextsByCorrelation.put(key, context);
		}
		context.put(CONTEXT_STATUS_CODE, statusCode);
		context.put(CONTEXT_CALLOUT_DURATION_MS, durationMs != null ? String.valueOf(durationMs) : null);
	}

	/**
	 * @description Drops the service, endpoint and response details stored for one handler, so later log entries
	 * under that correlation id no longer carry them. Call it when the handler is finished. Does nothing when no
	 * details are stored for the id.
	 *
	 * @param correlationId The handler's correlation ID (null uses current correlation)
	 */
	public static void clearWebserviceContext(String correlationId)
	{
		String key = String.isNotBlank(correlationId) ? correlationId : getCurrentOrDefaultCorrelation();
		webserviceContextsByCorrelation.remove(key);
	}

	/**
	 * @description Returns the current correlation ID or a default key.
	 *
	 * @return String The correlation ID to use for context storage
	 */
	private static String getCurrentOrDefaultCorrelation()
	{
		return String.isNotBlank(currentCorrelationId) ? currentCorrelationId : 'default';
	}

	/**
	 * @description Suspends log publishing - logs are buffered.
	 */
	public static void suspendSaving()
	{
		isSavingSuspended = true;
	}

	/**
	 * @description Resumes log publishing and flushes buffer.
	 */
	public static void resumeSaving()
	{
		isSavingSuspended = false;
		flushBuffer();
	}

	/**
	 * @description Enters the event-trigger state for the rest of the current trigger run, when the trigger's
	 * records are a platform event (custom `__e` or standard) or a change event. In that state, every log this
	 * transaction emits is saved to `LogEntry__c` with direct DML instead of being published as a
	 * `LogEntryEvent__e`. Publishing a platform event from inside a platform event or change event trigger makes
	 * the platform deliver the original event again, so the dispatcher would loop without end. Buffering is turned
	 * on, so the logs are saved together in one DML statement when the trigger run ends (`endEventTriggerContext`),
	 * not one statement per emit. Only the outermost event trigger run owns the state. A nested run that starts
	 * inside it returns `false` and leaves the clean-up to the owner.
	 *
	 * @param records The dispatched trigger's `Trigger.new` records.
	 *
	 * @return `true` when this call entered (and therefore owns) the event-trigger context.
	 */
	public static Boolean beginEventTriggerContext(List<SObject> records)
	{
		if(isEventTriggerContext)
		{
			return false;
		}
		if(!isChangeEventOrPlatformEvent(records))
		{
			return false;
		}
		isEventTriggerContext = true;
		eventContextDidSuspendSaving = !isSavingSuspended;
		isSavingSuspended = true;
		return true;
	}

	/**
	 * @description Leaves the event-trigger state entered by `beginEventTriggerContext`. It FIRST saves any logs
	 * waiting in the buffer, while the state flag is still set, so the flush goes through `dispatchEvents` to direct
	 * DML and not to `EventBus.publish`. It then turns suspended saving back off, but only if this owner turned it
	 * on, and clears the state flag. The dispatcher calls it from its `finally` block, so a trigger run that fails
	 * still leaves the state.
	 */
	public static void endEventTriggerContext()
	{
		flushBuffer();
		if(eventContextDidSuspendSaving)
		{
			isSavingSuspended = false;
			eventContextDidSuspendSaving = false;
		}
		isEventTriggerContext = false;
	}

	/**
	 * @description Reports whether the supplied records are events of any kind: the kinds whose
	 * triggers make the platform redeliver the source event when a platform event is published during
	 * their execution. Two name endings settle the common cases: `__e` names a custom platform event
	 * and `ChangeEvent` a change event. A standard platform event such as `BatchApexErrorEvent` carries
	 * neither ending, so a name with neither is settled by what every event has in common, standard or
	 * custom: it cannot be queried, while every ordinary object can. The name and that answer both come
	 * from the cached describe wrapper, so the object is described at most once per transaction.
	 * Returns `false` for a null or empty list so a delete-context dispatch (no `Trigger.new`) is
	 * treated as non-event.
	 *
	 * @param records The records to classify.
	 *
	 * @return `true` when the records are events of any kind.
	 */
	@TestVisible
	private static Boolean isChangeEventOrPlatformEvent(List<SObject> records)
	{
		if(records == null || records.isEmpty())
		{
			return false;
		}
		SObjectType objectType = records[0].getSObjectType();
		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(objectType);
		if(objectName.endsWith(UTIL_SObjectDescribe.CHANGE_EVENT_SUFFIX) || objectName.endsWith(UTIL_SObjectDescribe.PLATFORM_EVENT_SUFFIX))
		{
			return true;
		}
		return !UTIL_SObjectDescribe.getDescribe(objectType).getDescribe().isQueryable();
	}

	/**
	 * @description The single place a batch of log events leaves the engine. In the event-trigger state the events
	 * are saved to `LogEntry__c` through `TRG_PersistLogEntry.persist`: direct DML, no publish, so no loop.
	 * Otherwise they are published as `LogEntryEvent__e` as usual. Both the immediate path (`publishEventsTo`) and
	 * the buffer flush path (`safePublish`) go through here, so the choice not to publish is made in one place
	 * only. The DML statements the save uses are added to `frameworkLogPersistenceDmlStatements`. This happens in a
	 * `finally` block, so a save that fails still counts what it used. The check that a post-action does no DML
	 * reads that count, so it does not count the framework's own log DML.
	 *
	 * @param events The events to dispatch.
	 *
	 * @return The publish save results, or `null` when persisted via DML in event-trigger context.
	 */
	private static List<Database.SaveResult> dispatchEvents(List<LogEntryEvent__e> events)
	{
		if(isInEventTriggerContext())
		{
			Integer dmlStatementsBefore = UTIL_Limits.dmlStatements().used();
			try
			{
				TRG_PersistLogEntry.persist(events);
			}
			finally
			{
				frameworkLogPersistenceDmlStatements += UTIL_Limits.dmlStatements().used() - dmlStatementsBefore;
			}
			return null;
		}
		return EventBus.publishWithAccessLevel(events, AccessLevel.SYSTEM_MODE);
	}

	/**
	 * @description Whether the code is running inside a platform event or change event trigger, and so must not
	 * publish `LogEntryEvent__e`. It is true when the dispatcher has entered the state itself
	 * (`beginEventTriggerContext`). It is also true when any event trigger is running. That second check is a safety
	 * net for a subscriber's platform event trigger that calls kern logging without going through `TRG_Dispatcher`.
	 *
	 * @return `true` when log publishing must be suppressed in favour of direct-DML persistence.
	 */
	private static Boolean isInEventTriggerContext()
	{
		if(isEventTriggerContext)
		{
			return true;
		}
		return Trigger.isExecuting && isChangeEventOrPlatformEvent(Trigger.new);
	}

	/**
	 * @description Delivers the published events at once, in a unit test only, with the values set for one emit (the
	 * channels) cleared during the delivery. The delivery runs before the emitting entry clears its own channels. A
	 * log emitted during the delivery would otherwise read that entry's fingerprint, stack trace and exception type
	 * and be saved with them. Examples are a trigger action on the log event that writes its own entry, or a
	 * subscriber trigger on the saved rows. It never delivers from inside a platform event or change event trigger:
	 * the test event bus would deliver the current batch again and save every event twice. In that state the engine
	 * saves with direct DML and never publishes.
	 */
	private static void deliverInTestWithEmitChannelsClosed()
	{
		if(!Test.isRunningTest() || isInEventTriggerContext())
		{
			return;
		}
		String ownerFingerprint = currentFingerprint;
		String ownerStackTrace = currentStackTrace;
		String ownerExceptionType = currentExceptionType;
		currentFingerprint = null;
		currentStackTrace = null;
		currentExceptionType = null;
		try
		{
			Test.getEventBus().deliver();
		}
		finally
		{
			currentFingerprint = ownerFingerprint;
			currentStackTrace = ownerStackTrace;
			currentExceptionType = ownerExceptionType;
		}
	}

	/**
	 * @description Flushes all buffered logs in batches. The engine publishes at most 50 events in one
	 * `EventBus.publish` call. A lower number means more publishes; a higher number risks errors when the data is
	 * too large. Publication failures are caught to prevent the logger from rolling back business transactions.
	 *
	 * Both the application log buffer and the audit log buffer are flushed via the same chunked
	 * `safePublish` path, so there is a single publisher of platform events. Application logs
	 * flush first, then audit logs.
	 */
	@SuppressWarnings('PMD.AvoidDebugStatements')
	public static void flushBuffer()
	{
		flushBufferInternal(logBuffer);
		flushBufferInternal(auditLogBuffer);
	}

	/**
	 * @description Chunked-publish helper used by `flushBuffer` to drain a single buffer.
	 *
	 * @param buffer The buffer to drain.
	 */
	private static void flushBufferInternal(List<LogEntryEvent__e> buffer)
	{
		if(buffer.isEmpty())
		{
			return;
		}

		List<LogEntryEvent__e> batch = new List<LogEntryEvent__e>();
		for(LogEntryEvent__e event : buffer)
		{
			batch.add(event);
			// Publish at most BATCH_SIZE events at a time, so one publish never carries too much data.
			if(batch.size() == BATCH_SIZE)
			{
				safePublish(batch);
				batch.clear();
			}
		}

		if(!batch.isEmpty())
		{
			safePublish(batch);
		}

		buffer.clear();
	}

	/**
	 * @description Safely publishes events, catching exceptions to prevent logger from crashing the app.
	 *
	 * @param events The events to publish
	 */
	@SuppressWarnings('PMD.AvoidDebugStatements')
	private static void safePublish(List<LogEntryEvent__e> events)
	{
		try
		{
			if(simulatePublishFailure)
			{
				throw new TestSimulatedException('Simulated publish failure for testing');
			}
			dispatchEvents(events);
		}
		catch(Exception error)
		{
			System.debug(LoggingLevel.ERROR, 'FAILED TO PUBLISH LOG EVENTS: ' + error.getMessage());
		}
	}

	/**
	 * @description Returns count of buffered application logs. Audit-buffer entries are tracked
	 * separately via {@link #getAuditBufferSize} so test assertions that count application-log
	 * buffering are not contaminated by `BypassEvent`-shape audit emissions.
	 *
	 * @return Integer Number of logs in the application buffer
	 */
	public static Integer getBufferSize()
	{
		return logBuffer.size();
	}

	/**
	 * @description Returns count of buffered audit logs. Used by tests that need to assert
	 * `BypassEvent`-shape entries are emitted (or not). Application-log assertions should use
	 * {@link #getBufferSize} which excludes the audit buffer.
	 *
	 * @return Integer Number of logs in the audit buffer
	 */
	public static Integer getAuditBufferSize()
	{
		return auditLogBuffer.size();
	}

	/**
	 * @description Returns the running count of DML statements the framework used in this transaction to save its
	 * own logs. That is the direct DML used instead of publishing inside a platform event or change event trigger.
	 * `UTIL_PostTriggerAction.runOne` reads it before and after a post-action's `execute(context)`. A post-action may
	 * not do DML, and the check for that subtracts the engine's own log saves, so the post-action is blamed only for
	 * DML it did itself. It is public, not global, so subscribers cannot call it.
	 *
	 * @return The DML statements consumed so far by framework log persistence.
	 *
	 * @date August 2026
	 */
	public static Integer getFrameworkLogPersistenceDmlStatements()
	{
		return frameworkLogPersistenceDmlStatements;
	}

	/**
	 * @description Publishes the log events. During a unit test it does not publish them unless ignoreTestMode is
	 * true. It catches publish errors, so logging never makes the business transaction fail. While saving is
	 * suspended, it adds the events to the buffer instead (ERROR entries are the exception, see `publishEventsTo`).
	 *
	 * @param logEvents LogEntryEvent__e events to be published
	 *
	 * @return A List of database errors
	 */
	@TestVisible
	@SuppressWarnings('PMD.AvoidDebugStatements')
	private static List<Database.SaveResult> publishEvents(List<LogEntryEvent__e> logEvents)
	{
		return publishEventsTo(logEvents, logBuffer);
	}

	/**
	 * @description The audit version of `publishEvents`. It sends `BypassEvent` audit entries to the separate
	 * `auditLogBuffer`, so audit entries do not change the results of tests that count the application log buffer.
	 * That is also why `UTIL_BypassAudit.emit` needs no test-mode check to keep that buffer clean.
	 *
	 * It publishes exactly as `publishEvents` does: in the same batches through `safePublish` in `flushBuffer`, and
	 * saved by `TRG_PersistLogEntry` as the same kind of `LogEntry__c` row.
	 *
	 * @param auditEvents LogEntryEvent__e events to be published as audit entries
	 *
	 * @return A List of database errors
	 */
	@TestVisible
	@SuppressWarnings('PMD.AvoidDebugStatements')
	private static List<Database.SaveResult> publishAuditEvents(List<LogEntryEvent__e> auditEvents)
	{
		return publishEventsTo(auditEvents, auditLogBuffer);
	}

	/**
	 * @description Shared implementation of `publishEvents` and `publishAuditEvents`. Routes
	 * suspended-saving events into the supplied buffer, bypasses buffering for ERROR-level
	 * events, and falls back to async dispatch when DML budget is exhausted. The application
	 * vs audit split is purely about which buffer accumulates suspended events; the actual
	 * platform-event publish path is identical so subscribers see one publisher.
	 *
	 * The ERROR bypass does not apply inside a platform-event or change-event trigger that the
	 * framework's dispatcher runs, because that dispatcher owns the event-trigger context and its
	 * cleanup flushes the buffer when the trigger ends. There an ERROR entry waits in the buffer like
	 * any other: a direct insert rolls back with a failed transaction whether it ran early or late,
	 * and one insert per error entry would spend the DML budget on a trigger that receives up to 2,000
	 * events. `MAX_BUFFER_SIZE` still flushes a long run automatically. A subscriber's own event
	 * trigger that does not run through the dispatcher has no such cleanup, so there an ERROR still
	 * flushes at once, written by direct DML through `dispatchEvents`.
	 *
	 * The asynchronous fallback picks its route from the remaining budgets (the adaptive launcher),
	 * so a spent queueable budget re-routes to batch rather than throwing; a transaction with no
	 * asynchronous budget left at all is the platform's own limit, outside this method's control.
	 *
	 * @param events The events to publish.
	 * @param buffer The buffer to accumulate suspended events into.
	 *
	 * @return A list of database save results, or `null` when buffering or test-mode skipping.
	 */
	@SuppressWarnings('PMD.AvoidDebugStatements,PMD.CognitiveComplexity')
	private static List<Database.SaveResult> publishEventsTo(List<LogEntryEvent__e> events, List<LogEntryEvent__e> buffer)
	{
		List<Database.SaveResult> saveResults;

		// Check for ERROR logs - these bypass buffering for safety
		Boolean hasErrorLog = false;
		for(LogEntryEvent__e logEvent : events)
		{
			if(logEvent.LogLevel__c == LEVEL_ERROR)
			{
				hasErrorLog = true;
				break;
			}
		}

		// Inside a dispatcher-owned event trigger an ERROR waits for the dispatcher's flush like any other entry
		Boolean flushNow = hasErrorLog && !isEventTriggerContext;

		// Handle buffering
		if(isSavingSuspended && !flushNow)
		{
			buffer.addAll(events);

			// Safety: auto-flush if buffer too large
			if(buffer.size() >= MAX_BUFFER_SIZE)
			{
				flushBuffer();
			}
			return null;
		}
		else if(isSavingSuspended && flushNow)
		{
			// Add to buffer then flush everything (ERROR bypass)
			buffer.addAll(events);
			flushBuffer();
			return null;
		}

		// don't publish event during unit tests unless ignoreTestMode is true
		if(ignoreTestMode || !Test.isRunningTest())
		{
			// Ensure that the dml limits will not been breached when publishing the events
			if(canPublishImmediately(events))
			{
				try
				{
					if(simulatePublishFailure)
					{
						throw new TestSimulatedException('Simulated publish failure for testing');
					}
					saveResults = dispatchEvents(events);
				}
				catch(Exception error)
				{
					// Logger should never crash the business transaction
					System.debug(LoggingLevel.ERROR, 'FAILED TO PUBLISH LOG EVENTS: ' + error.getMessage());
				}
			}
			else
			{
				UTIL_AsynchronousJobLauncher.process(events, new LoggerProcessor());
			}
		}
		else
		{
			//Record log entries as system debug if running in test context
			System.debug(LoggingLevel.DEBUG, events);
		}

		return saveResults;
	}

	/**
	 * @description Method will check current governor limits and determine if the events provided can be published immediately
	 *
	 * @param logEvents List of items to publish
	 *
	 * @return True if publishing the event immediately won't breach governor limits
	 */
	private static Boolean canPublishImmediately(List<LogEntryEvent__e> logEvents)
	{
		if(simulateDMLimitsBreach)
		{
			return false;
		}

		Boolean publishImmediately = !UTIL_Limits.publishImmediateDml().isExhausted();
		publishImmediately = publishImmediately && logEvents.size() <= UTIL_Limits.dmlRows().remaining();

		return publishImmediately;
	}

	/**
	 * @description Represents a list of messages to be logged
	 */
	private inherited sharing class DTO_LogMessages
	{
		/**
		 * @description Contains error for this logger (if one was provided)
		 */
		private final Exception error;
		/**
		 * @description Log level for this logger
		 */
		private final LoggingLevel logLevel;
		/**
		 * @description All the messages that have been created
		 */
		private final List<DTO_LogMessage> logMessages = new List<DTO_LogMessage>();
		/**
		 * @description Duration in milliseconds for performance logs
		 */
		private Long durationMs;

		/**
		 * @description Default class constructor
		 *
		 * @param logLevel Log Level
		 * @param classMethod <class>/<method> if applicable
		 */
		private DTO_LogMessages(LoggingLevel logLevel, String classMethod)
		{
			this.logLevel = logLevel ?? LoggingLevel.DEBUG;
			this.classMethod = classMethod;
		}

		/**
		 * @description Default class constructor
		 *
		 * @param shortMessage Message to add to list of messages
		 * @param longMessage Message to add to list of messages
		 * @param recordId The record Id for which the message should be logged
		 * @param logLevel Log Level
		 * @param classMethod <class>/<method> if applicable
		 */
		@SuppressWarnings('PMD.ExcessiveParameterList')
		private DTO_LogMessages(String shortMessage, String longMessage, Id recordId, LoggingLevel logLevel, String classMethod)
		{
			this(logLevel, classMethod);
			addMessage(shortMessage, longMessage, recordId);
		}

		/**
		 * @description Default class constructor
		 *
		 * @param longMessages Messages to add to list of messages
		 * @param logLevel Log Level
		 * @param classMethod <class>/<method> if applicable
		 */
		private DTO_LogMessages(List<String> longMessages, LoggingLevel logLevel, String classMethod)
		{
			this(logLevel, classMethod);
			addMessages(longMessages);
		}

		/**
		 * @description Default class constructor
		 *
		 * @param error Error from which to retrieve the message
		 * @param logLevel Log Level
		 * @param classMethod <class>/<method> if applicable
		 */
		private DTO_LogMessages(Exception error, LoggingLevel logLevel, String classMethod)
		{
			this(error, null, logLevel, classMethod);
		}

		/**
		 * @description Default class constructor
		 *
		 * @param error Error from which to retrieve the message
		 * @param recordId Record Id of the object for which error was thrown
		 * @param logLevel Log Level
		 * @param classMethod <class>/<method> if applicable
		 */
		private DTO_LogMessages(Exception error, Id recordId, LoggingLevel logLevel, String classMethod)
		{
			this(logLevel, classMethod);
			this.error = error;
			addMessage(error, recordId);
		}

		/**
		 * @description Default class constructor
		 *
		 * @param error Error from which to retrieve the message
		 * @param shortMessage The caller's own summary, persisted as the entry's short message
		 * @param recordId Record Id of the object for which error was thrown
		 * @param logLevel Log Level
		 * @param classMethod <class>/<method> if applicable
		 */
		@SuppressWarnings('PMD.ExcessiveParameterList')
		private DTO_LogMessages(Exception error, String shortMessage, Id recordId, LoggingLevel logLevel, String classMethod)
		{
			this(logLevel, classMethod);
			this.error = error;
			addMessage(shortMessage, error.getMessage(), recordId);
		}

		/**
		 * @description Add a message to the list
		 *
		 * @param longMessage Message text
		 * @param recordId Associated Record Id (if applicable)
		 */
		private void addMessage(String longMessage, Id recordId)
		{
			addMessage(null, longMessage, recordId);
		}

		/**
		 * @description Add a message to the list
		 *
		 * @param shortMessage Message text
		 * @param longMessage Message text
		 * @param recordId Associated Record Id (if applicable)
		 */
		private void addMessage(String shortMessage, String longMessage, Id recordId)
		{
			logMessages.add(new DTO_LogMessage(shortMessage, longMessage, recordId));
		}

		/**
		 * @description Add a message to the list
		 *
		 * @param error Exception from which to retrieve the message
		 * @param recordId Associated Record Id (if applicable)
		 */
		private void addMessage(Exception error, Id recordId)
		{
			addMessage(error.getMessage(), recordId);
		}

		/**
		 * @description will add multiple messages to the list
		 *
		 * @param longMessages List of message to add
		 */
		private void addMessages(List<String> longMessages)
		{
			for(String message : longMessages)
			{
				addMessage(message, null);
			}
		}

		/**
		 * @description Returns true if no messages have been added to the list
		 */
		@SuppressWarnings('ApexControlFlowAnalysis')
		private Boolean isEmpty
		{
			get
			{
				return logMessages.isEmpty();
			}
		}

		/**
		 * @description The class method for this logger
		 */
		private String classMethod
		{
			get;
			set
			{
				classMethod = UTIL_String.abbreviate(value, CLASS_METHOD_LENGTH);
			}
		}

		/**
		 * @description Will construct a list off events from the log messages. An entry a masking
		 * rule blocks is dropped rather than published unmasked; a debug line records why.
		 *
		 * @return List of items
		 */
		@SuppressWarnings('PMD.AvoidDebugStatements')
		private List<LogEntryEvent__e> getEvents()
		{
			List<LogEntryEvent__e> events = new List<LogEntryEvent__e>();

			// Request.getCurrent()/getQuiddity() are null in sessionless contexts (Auth registration
			// handlers, inbound email services, some guest flows); a log emit must never throw there
			String executionEvent = (Request.getCurrent()?.getQuiddity() ?? Quiddity.UNDEFINED).name();
			String stackTrace = getStackTrace(error);
			String namespacePrefix = UTIL_System.getManagedPackageNamespacePrefix(UTIL_String.DOT);

			// Only where the engine built the stack itself is its top frame the caller's, so only there can the
			// caller's class and method be read off it when the caller named none
			if(String.isBlank(classMethod) && error == null && String.isBlank(currentStackTrace))
			{
				classMethod = resolveClassMethodFromStack(stackTrace);
			}

			String origin = resolveOrigin(classMethod, namespacePrefix, getCurrentOperationType()).name();
			String source = UTIL_String.abbreviate(resolveSource(classMethod, namespacePrefix), LogEntryEvent__e.Source__c);

			for(DTO_LogMessage dtoLogMessage : logMessages)
			{
				LogEntryEvent__e event = dtoLogMessage.getEvent();

				event.ClassMethod__c = classMethod;
				event.ExceptionType__c = error?.getTypeName() ?? currentExceptionType;
				event.ExecutionEvent__c = executionEvent;
				event.Limits__c = getDebugLimits();
				event.LineNumber__c = error?.getLineNumber();
				event.LogLevel__c = logLevel.name();
				event.Origin__c = origin;
				event.Source__c = source;
				event.StackTrace__c = stackTrace;
				event.UserId__c = CURRENT_USER_ID;

				// Correlation fields
				event.CorrelationId__c = currentCorrelationId;
				event.RootCorrelationId__c = currentRootCorrelationId;
				event.TransactionId__c = Request.getCurrent()?.getRequestId();
				event.ParentTransactionId__c = currentParentTransactionId;
				event.Fingerprint__c = currentFingerprint;

				// Context data and duration
				event.ContextData__c = serializeContextData();
				event.DurationMs__c = durationMs;

				if(UTIL_FrameworkMasker.isMaskingEnabled)
				{
					try
					{
						UTIL_FrameworkMasker.forRecord(event).apply();
					}
					catch(UTIL_Exceptions.MaskingBlockedException blocked)
					{
						// A rule set to block DML failed on this entry: the entry must not be published unmasked, and the
						// logger must not take the business transaction down with it. This debug line is the only
						// breadcrumb the transaction keeps, so it carries the reason, the origin and the correlation.
						System.debug(LoggingLevel.WARN, 'Log entry dropped because a masking rule blocked it: ' + blocked.getMessage()
								+ ' | classMethod: ' + classMethod + ' | correlationId: ' + currentCorrelationId);
						continue;
					}
				}

				events.add(event);
			}

			return events;
		}

		/**
		 * @description Will return the stack trace to be included in the error log. A real
		 * exception's own trace wins; otherwise a stack trace the caller supplied (the channel for one emit
		 * set via `setCurrentStackTrace`, e.g. a client-side JavaScript stack) is used; otherwise
		 * the stack is calculated from the current call stack with framework infrastructure frames
		 * stripped. Calculation idea taken from https://salesforce.stackexchange.com/questions/153835
		 *
		 * @param error If the log was called with an exception, this will be used else the stack will be calculated
		 *
		 * @return The stack track of the log entry
		 *
		 * @date July 2026
		 */
		private String getStackTrace(Exception error)
		{
			String stackTrace;

			if(error != null)
			{
				stackTrace = error.getStackTraceString();
			}
			else if(String.isNotBlank(currentStackTrace))
			{
				stackTrace = currentStackTrace;
			}
			else
			{
				List<String> stackTraceLines = new DmlException().getStackTraceString().split(UTIL_String.LF);

				for(Integer i = stackTraceLines.size() - 1; i >= 0; i--)
				{
					String stackTraceLine = stackTraceLines[i];

					Matcher patternMatcher = STACK_LINE.matcher(stackTraceLine);

					if(!patternMatcher.find() || isFrameworkFrame(stackTraceLine))
					{
						stackTraceLines.remove(i);
					}
				}

				stackTrace = UTIL_String.join(stackTraceLines, UTIL_String.LF);
			}

			return stackTrace;
		}

		/**
		 * @description Returns whether a stack-trace line belongs to the logging framework's own
		 * code (builder, engine, and the classes that pass logs from components and Flows) rather than caller code.
		 *
		 * @param stackTraceLine The raw stack-trace line to classify.
		 *
		 * @return True when the line starts with any anchored framework frame prefix.
		 *
		 * @date July 2026
		 */
		private Boolean isFrameworkFrame(String stackTraceLine)
		{
			for(String prefix : FRAMEWORK_FRAME_PREFIXES)
			{
				if(stackTraceLine.startsWith(prefix))
				{
					return true;
				}
			}

			return false;
		}

		/**
		 * @description returns limits for debugging and error tracing purposes
		 *
		 * @return debug limits
		 */
		private String getDebugLimits()
		{
			return UTIL_Limits.toDebugString();
		}
	}

	/**
	 * @description DTO representing a message to be logged
	 */
	private inherited sharing class DTO_LogMessage
	{
		/**
		 * @description Object Record Id associated to this message
		 */
		private final Id recordId;

		/**
		 * @description An abbreviated message
		 */
		private final String shortMessage
		{
			get
			{
				return UTIL_String.abbreviate(shortMessage ?? message, LogEntryEvent__e.ShortMessage__c);
			}
			set;
		}

		/**
		 * @description The full message
		 */
		private final String message
		{
			get
			{
				return UTIL_String.abbreviate(message, LogEntryEvent__e.Message__c);
			}
			set;
		}

		/**
		 * @description Default object constructor
		 *
		 * @param shortMessage The short message to log
		 * @param longMessage The long message to log
		 * @param recordId The related object id (if any)
		 */
		private DTO_LogMessage(String shortMessage, String longMessage, Id recordId)
		{
			this.message = longMessage;
			this.recordId = recordId;
			this.shortMessage = shortMessage;
		}

		/**
		 * @description Will construct an event an populate it appropriately
		 *
		 * @return An app love event
		 */
		private LogEntryEvent__e getEvent()
		{
			LogEntryEvent__e newEvent = new LogEntryEvent__e();

			newEvent.Message__c = message;
			newEvent.RecordId__c = recordId;
			newEvent.ShortMessage__c = shortMessage;

			return newEvent;
		}
	}

	/**
	 * @description Processor implementation that handles the publishing of Log Entry Events
	 */
	private inherited sharing class LoggerProcessor implements IF_Async.Processable
	{
		/**
		 * @description Publishes the Log Events provided
		 *
		 * @param items The list of Events to Process
		 */
		public void execute(List<Object> items)
		{
			List<LogEntryEvent__e> logEvents = new List<LogEntryEvent__e>();

			for(Object item : items)
			{
				logEvents.add((LogEntryEvent__e)item);
			}

			EventBus.publishWithAccessLevel(logEvents, AccessLevel.SYSTEM_MODE);
		}
	}

	/**
	 * @description DTO for serializing logger context to async jobs.
	 * Provides structured, typed access to correlation and context data.
	 */
	@TestVisible
	private inherited sharing class DTO_LoggerContext
	{
		/**
		 * @description The tracking id that the logs of the receiving job are written under. Restoring the context makes it the
		 * live correlation id of that job.
		 */
		public String correlationId;
		/**
		 * @description The tracking id of the action that started the whole story, which stays the same however many jobs follow.
		 * When a stored context has none, its correlationId is used as the root.
		 */
		public String rootCorrelationId;
		/**
		 * @description The request id of the transaction that wrote this context, so the receiving job can name the transaction
		 * it continues. Left empty when the context is written for a correlation id alone.
		 */
		public String parentTransactionId;
		/**
		 * @description Name and value pairs. In a context handed to another job they are the pairs attached to every log of the
		 * writing transaction, carried over so the receiving job logs them too; they are left empty when the writing transaction
		 * had none. The same field, on its own, is also the stored shape of one log entry's context values.
		 */
		public Map<String, String> contextData;
	}

	/**
	 * @description Exception used exclusively for testing error handling paths.
	 * Avoids misusing semantically-specific exceptions like CalloutException.
	 */
	@TestVisible
	private inherited sharing class TestSimulatedException extends Exception
	{
	}
}