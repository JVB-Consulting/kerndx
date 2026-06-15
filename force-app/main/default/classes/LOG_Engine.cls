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
 * @date February 2026, June 2026
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.AvoidGlobalModifier,PMD.CognitiveComplexity,PMD.ExcessiveClassLength,PMD.ExcessivePublicCount,PMD.NcssTypeCount')
public inherited sharing class LOG_Engine
{
	/**
	 * @description Cached running-user Id captured once per transaction. Stamped onto every
	 * `LogEntryEvent__e.UserId__c` so subscribers can query persisted logs by emitting user
	 * (the trigger handler runs as the Automated Process user, so `CreatedById` is not useful).
	 */
	private static final Id CURRENT_USER_ID = UserInfo.getUserId();

	/**
	 * @description Maximum events per `EventBus.publish` batch. With `ContextData__c` permitted up
	 * to 32KB, 50 events conservatively stays under the 1MB platform-event payload limit
	 * (~1.6MB headroom). Lowering risks more publishes; raising risks payload-size errors.
	 */
	private static final Integer BATCH_SIZE = 50;

	/**
	 * @description Length of `LogEntryEvent__e.ClassMethod__c` from the SObject describe; cached
	 * once so `UTIL_String.abbreviate` can truncate `classMethod` strings to fit without re-running
	 * `getDescribe()` on every persist.
	 */
	private static final Integer CLASS_METHOD_LENGTH = LogEntryEvent__e.ClassMethod__c.getDescribe().length;

	/**
	 * @description Regex used by `DTO_LogMessages.getStackTrace` to parse Apex stack-trace lines
	 * into class/method/line components. Compiled once because regex compilation is non-trivial.
	 */
	private static final Pattern STACK_LINE = Pattern.compile('^(?:Class\\.)?([^.]+)\\.?([^.:]+)?[.:]?([^.:]*): line (\\d+), column (\\d+)$');

	/**
	 * @description Frame-prefix marker used to strip self-references from generated stack traces
	 * so `LOG_Builder` infrastructure frames don't dominate the persisted `StackTrace__c` field.
	 */
	private static final String CLASS_SUFFIX = 'LOG_Builder.';

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
	 * @description String name of `LoggingLevel.WARN` cached once for repeated comparisons in the
	 * threshold-filter and ordinal-lookup hot paths. `LoggingLevel.WARN.name()` calls into the
	 * platform every invocation; caching avoids the per-emit overhead.
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
	 * detect ERROR entries that bypass the suspended-saving buffer.
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
		 * @description Trigger operations (logs from trigger actions)
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
	 * @description Context key recording the original fingerprint key a caller passed, written only
	 * when the key was transformed (hashed) during normalization so the opaque stored fingerprint
	 * stays reconcilable with what the caller supplied.
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
	 * @description Per-emit fingerprint channel — set by `LOG_Builder.LogEntry.emitInternal` just
	 * before the log call and cleared in its finally, mirroring the per-entry context push/pop.
	 * Carried onto every `LogEntryEvent__e` built while set.
	 */
	private static String currentFingerprint;

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
	 * @description Application log buffer. Accumulates `LogEntryEvent__e` events while
	 * `isSavingSuspended` is `true`, then drains via `flushBuffer()` in chunked batches through
	 * `safePublish` to honor the platform-event 1MB payload limit. Audit-shape entries are
	 * tracked separately on `auditLogBuffer` so test assertions that count buffer size are not
	 * polluted by `BypassEvent` emissions.
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
	 * @description Audit log buffer. Accumulates `BypassEvent`-shape `LogEntryEvent__e` events
	 * routed through `LOG_Engine.publishAuditEvents` (via `LOG_Builder.LogEntry.emitAsAudit()`).
	 * Drained alongside `logBuffer` by `flushBuffer()` so subscribers see one platform-event
	 * publisher; isolated from `logBuffer` so application-log buffer-size assertions aren't
	 * contaminated by audit emissions and the `emit→deliver→persist→emit` cascade has no
	 * fixpoint to land in.
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
	 * @description Buffer-size threshold beyond which `publishEventsTo` auto-flushes to bound
	 * memory under sustained suspended-saving load. Each chunk to `safePublish` is limited to
	 * `BATCH_SIZE` (50) events to stay under the 1MB platform-event payload limit.
	 */
	private static final Integer MAX_BUFFER_SIZE = 500;

	/**
	 * @description Test seam: when `true`, `safePublish` throws a `TestSimulatedException` so
	 * tests can verify the logger never crashes the business transaction on publish failure.
	 */
	@TestVisible
	private static Boolean simulatePublishFailure = false;

	/**
	 * @description Stack of operation contexts for nested operation tracking. Each entry
	 * represents a nested operation (webservice, query, trigger, flow, lwc). Contexts are merged
	 * when serializing to logs — later contexts override earlier ones. Lazy-allocated so
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
	 * @description Returns the effective LogSetting__c for the current user.
	 * Uses hierarchical custom setting resolution (User → Profile → Org).
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
		log(null, longMessage, classMethod, recordId, logLevel);
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
		DTO_LogMessages dtoLogMessages = new DTO_LogMessages(LoggingLevel.ERROR, classMethod);

		for(Object operationResult : operationResults)
		{
			Boolean operationFailed;
			Id recordId;
			List<Database.Error> errors;

			if(operationResult instanceof Database.SaveResult)
			{
				Database.SaveResult saveResult = (Database.SaveResult)operationResult;
				errors = saveResult.errors;
				operationFailed = !saveResult.success;
				recordId = saveResult.id;
			}
			else if(operationResult instanceof Database.DeleteResult)
			{
				Database.DeleteResult deleteResult = (Database.DeleteResult)operationResult;
				errors = deleteResult.errors;
				operationFailed = !deleteResult.success;
				recordId = deleteResult.id;
			}
			else if(operationResult instanceof Database.UndeleteResult)
			{
				Database.UndeleteResult undeleteResult = (Database.UndeleteResult)operationResult;
				errors = undeleteResult.errors;
				operationFailed = !undeleteResult.success;
				recordId = undeleteResult.id;
			}
			else
			{
				Database.UpsertResult upsertResult = (Database.UpsertResult)operationResult;
				errors = upsertResult.errors;
				operationFailed = !upsertResult.success;
				recordId = upsertResult.id;
			}

			if(operationFailed)
			{
				String errorMessage = extractErrorMessage(errors);
				dtoLogMessages.addMessage(String.format(DML_ERROR_FORMAT, new List<Object> {errorMessage, recordId}), recordId);
			}
		}

		log(dtoLogMessages);

		return !dtoLogMessages.isEmpty;
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
	 * @description Audit-routing variant of `log(DTO_LogMessages)` — when `isAudit` is `true`,
	 * routes the resulting `LogEntryEvent__e` events through `publishAuditEvents` so they
	 * accumulate in the dedicated audit buffer rather than the application log buffer.
	 *
	 * Audit emissions in test context require an explicit `LOG_Builder.ignoreTestMode = true`
	 * opt-in (matching the application-log path's existing test-mode skip). Without the opt-in,
	 * audit emissions short-circuit BEFORE `dtoLogMessages.getEvents()` runs so the framework's
	 * cold-cache CMDT/EntityDefinition lookups (driven by `UTIL_FrameworkMasker.isMaskingEnabled`
	 * inside `getEvents`) do not inflate SOQL counts in tests that do not exercise the audit
	 * channel. Tests that DO exercise the audit channel set `ignoreTestMode = true` to opt in.
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
			//Ensure that the events are published in unit tests — but never deliver re-entrantly
			//from inside a platform-event/change-event trigger: the test event bus would redeliver
			//the in-flight batch, double-persisting every delivered event. In event-trigger context
			//the engine persists via direct DML and never publishes, so there is nothing to deliver.
			if(Test.isRunningTest() && !isInEventTriggerContext())
			{
				Test.getEventBus().deliver();
			}
		}
	}

	/**
	 * @description Audit-routing variant of `log(String, String, String, Id, LoggingLevel)`.
	 * Used by `LOG_Builder.LogEntry.emitAsAudit()` to route `BypassEvent`-shape audit entries
	 * through the dedicated audit buffer so they don't pollute application-log buffer assertions.
	 * Public-but-not-global so subscribers cannot bind to it.
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
	 * Evaluation order: ERROR always passes → kill switch → threshold check → class filter.
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
	 * @description Extracts the class name from a classMethod string.
	 * Handles both 'ClassName/methodName' and 'ClassName.methodName' formats.
	 *
	 * @param classMethod The class/method string
	 *
	 * @return The class name portion, or the full string if no separator found
	 */
	@TestVisible
	private static String extractClassName(String classMethod)
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

		Integer dotIndex = classMethod.indexOf('.');

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
	 * @description Generates and sets a new correlation ID for this transaction.
	 *
	 * @return String The generated correlation ID
	 */
	public static String startCorrelation()
	{
		currentCorrelationId = UTIL_Random.randomUUID();
		return currentCorrelationId;
	}

	/**
	 * @description Sets the correlation ID (for child transactions).
	 *
	 * @param correlationId The correlation ID from parent transaction
	 */
	public static void setCorrelationId(String correlationId)
	{
		currentCorrelationId = correlationId;
	}

	/**
	 * @description Returns the current correlation ID.
	 *
	 * @return String The current correlation ID or null
	 */
	public static String getCorrelationId()
	{
		return currentCorrelationId;
	}

	/**
	 * @description Sets the fingerprint applied to events built during the current emit call.
	 * Public-but-not-global so subscribers route through `LOG_Builder.withFingerprint`.
	 *
	 * @param fingerprintKey The normalized grouping key.
	 */
	public static void setCurrentFingerprint(String fingerprintKey)
	{
		currentFingerprint = fingerprintKey;
	}

	/**
	 * @description Clears the per-emit fingerprint channel so it cannot leak into later entries.
	 */
	public static void clearCurrentFingerprint()
	{
		currentFingerprint = null;
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
		context.parentTransactionId = Request.getCurrent().getRequestId();
		if(!globalContextData.isEmpty())
		{
			context.contextData = globalContextData;
		}
		return JSON.serializePretty(context, true);
	}

	/**
	 * @description Restores context from serialized string in async jobs.
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
			currentParentTransactionId = context.parentTransactionId;

			if(context.contextData != null)
			{
				globalContextData = context.contextData;
			}
		}
		catch(Exception error)
		{
			// Include the payload that caused the failure to help debug async context loss
			System.debug(LoggingLevel.WARN, 'Failed to hydrate logging context. Error: ' + error.getMessage() + ' | Payload: ' + serializedContext);
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

			//See log(DTO_LogMessages, Boolean): never deliver re-entrantly from inside a
			//platform-event/change-event trigger — the test event bus would redeliver the
			//in-flight batch and double-persist every delivered event.
			if(Test.isRunningTest() && !isInEventTriggerContext())
			{
				Test.getEventBus().deliver();
			}
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
	 * @description Clears a specific global context key.
	 *
	 * @param key The key to remove
	 */
	public static void clearGlobalContext(String key)
	{
		globalContextData.remove(key);
	}

	/**
	 * @description Clears all global context.
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
	 */
	public static void popOperationContext()
	{
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
	 */
	public static void clearContextStack()
	{
		contextStack.clear();
	}

	/**
	 * @description Merges all contexts in the stack into a single map.
	 * Later contexts override earlier ones for the same keys.
	 * Order: globalContext → stack[0] → stack[1] → ... → webserviceContext
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
	 * Order: global (base) → stack contexts → webservice for current correlation (override).
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
	 * @description Clears webservice context for a specific correlation ID.
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
	 * @description Enters event-trigger context for the remainder of the current dispatch when the
	 * dispatched records are a platform event (`__e`) or change event (`*ChangeEvent`). In that
	 * context every log this transaction emits is persisted to `LogEntry__c` via direct DML instead
	 * of being published as a `LogEntryEvent__e` — publishing a platform event from inside a
	 * platform-event / change-event trigger makes the platform redeliver the source event, which
	 * would loop the dispatcher unbounded. Buffering is switched on so the suppressed-publish persist
	 * coalesces into one bulk DML at the dispatch boundary (`endEventTriggerContext`) rather than one
	 * per emit. Only the outermost event dispatch owns the context; a nested re-entrant dispatch
	 * returns `false` and leaves teardown to the owner.
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
	 * @description Exits the event-trigger context entered by `beginEventTriggerContext`. Drains any
	 * buffered in-context logs FIRST — while the context flag is still set, so the flush routes
	 * through `dispatchEvents` to direct DML rather than `EventBus.publish` — then restores the prior
	 * suspended-saving state (only if this owner switched it on) and clears the context flag. Called
	 * from the dispatcher's `finally` so an aborted dispatch still tears the context down.
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
	 * @description Reports whether the supplied records belong to a platform event (`__e`) or a
	 * change event (`*ChangeEvent`) — the SObject kinds whose triggers cause the platform to
	 * redeliver the source event when a platform event is published during their execution. Reads the
	 * API name straight off the record's `SObjectType` token (no describe call). Returns `false` for
	 * a null or empty list so a delete-context dispatch (no `Trigger.new`) is treated as non-event.
	 *
	 * @param records The records to classify.
	 *
	 * @return `true` when the records are a platform event or change event.
	 */
	@TestVisible
	private static Boolean isChangeEventOrPlatformEvent(List<SObject> records)
	{
		if(records == null || records.isEmpty())
		{
			return false;
		}
		String objectName = String.valueOf(records[0].getSObjectType());
		return objectName.endsWith(UTIL_SObjectDescribe.CHANGE_EVENT_SUFFIX) || objectName.endsWith(UTIL_SObjectDescribe.PLATFORM_EVENT_SUFFIX);
	}

	/**
	 * @description Single egress for a chunk of log events. In event-trigger context the events are
	 * persisted to `LogEntry__c` via `TRG_PersistLogEntry.persist` (direct DML, no publish, loop-safe);
	 * otherwise they publish normally as `LogEntryEvent__e`. Both the immediate path
	 * (`publishEventsTo`) and the buffered flush path (`safePublish`) route through here so the
	 * publish-suppression decision is made in exactly one place.
	 *
	 * @param events The events to dispatch.
	 *
	 * @return The publish save results, or `null` when persisted via DML in event-trigger context.
	 */
	private static List<Database.SaveResult> dispatchEvents(List<LogEntryEvent__e> events)
	{
		if(isInEventTriggerContext())
		{
			TRG_PersistLogEntry.persist(events);
			return null;
		}
		return EventBus.publishWithAccessLevel(events, AccessLevel.SYSTEM_MODE);
	}

	/**
	 * @description Whether the current execution is inside a platform-event / change-event trigger
	 * and must therefore suppress `LogEntryEvent__e` publishing. True when the dispatcher has entered
	 * the context explicitly (`beginEventTriggerContext`), or — as a backstop for a subscriber
	 * platform-event trigger that calls kern logging without going through `TRG_Dispatcher` — when an
	 * event trigger is currently executing.
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
	 * @description Flushes all buffered logs in chunked batches to avoid 1MB payload limit.
	 * Salesforce Platform Events have a 1MB limit per publish call. With large ContextData__c
	 * (up to 32KB), we conservatively batch 50 events per publish (~1.6MB headroom).
	 * Publication failures are caught to prevent the logger from rolling back business transactions.
	 *
	 * Both the application log buffer and the audit log buffer are flushed via the same chunked
	 * `safePublish` path so a single platform-event publisher is honored — application logs
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
			// Safety: Publish in chunks to avoid 1MB payload limit
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
	 * @description publishes event... optionally suppresses when in test... deals with errors
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
	 * @description Audit-routing sibling of `publishEvents`. Routes `BypassEvent`-shape audit
	 * entries through the dedicated `auditLogBuffer` so test assertions that count application
	 * log buffer size are not contaminated by audit emissions, and the test-mode guard in
	 * `UTIL_BypassAudit.emit` is no longer needed for buffer-pollution avoidance.
	 *
	 * Shares wire-format and chunked-publish semantics with `publishEvents` — same `safePublish`
	 * batcher in `flushBuffer`, same persisted `LogEntry__c` row shape via `TRG_PersistLogEntry`.
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

		// Handle buffering
		if(isSavingSuspended && !hasErrorLog)
		{
			buffer.addAll(events);

			// Safety: auto-flush if buffer too large
			if(buffer.size() >= MAX_BUFFER_SIZE)
			{
				flushBuffer();
			}
			return null;
		}
		else if(isSavingSuspended && hasErrorLog)
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
	private class DTO_LogMessages
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
		 * @description Will construct a list off events from the log messages
		 *
		 * @return List of items
		 */
		private List<LogEntryEvent__e> getEvents()
		{
			List<LogEntryEvent__e> events = new List<LogEntryEvent__e>();

			String executionEvent = Request.getCurrent().getQuiddity().name();
			String stackTrace = getStackTrace(error);

			for(DTO_LogMessage dtoLogMessage : logMessages)
			{
				LogEntryEvent__e event = dtoLogMessage.getEvent();

				event.ClassMethod__c = classMethod;
				event.ExceptionType__c = error?.getTypeName();
				event.ExecutionEvent__c = executionEvent;
				event.Limits__c = getDebugLimits();
				event.LineNumber__c = error?.getLineNumber();
				event.LogLevel__c = logLevel.name();
				event.StackTrace__c = stackTrace;
				event.UserId__c = CURRENT_USER_ID;

				// Correlation fields
				event.CorrelationId__c = currentCorrelationId;
				event.TransactionId__c = Request.getCurrent().getRequestId();
				event.ParentTransactionId__c = currentParentTransactionId;
				event.Fingerprint__c = currentFingerprint;

				// Context data and duration
				event.ContextData__c = serializeContextData();
				event.DurationMs__c = durationMs;

				if(UTIL_FrameworkMasker.isMaskingEnabled)
				{
					UTIL_FrameworkMasker.forRecord(event).apply();
				}

				events.add(event);
			}

			return events;
		}

		/**
		 * @description Will return the stack trace to be included in the error log,
		 * uses an idea from Idea taken from https://salesforce.stackexchange.com/questions/153835
		 *
		 * @param error If the log was called with an exception, this will be used else the stack will be calculated
		 *
		 * @return The stack track of the log entry
		 */
		private String getStackTrace(Exception error)
		{
			String stackTrace;

			if(error != null)
			{
				stackTrace = error.getStackTraceString();
			}
			else
			{
				List<String> stackTraceLines = new DmlException().getStackTraceString().split(UTIL_String.LF);

				for(Integer i = stackTraceLines.size() - 1; i >= 0; i--)
				{
					String stackTraceLine = stackTraceLines[i];

					Matcher patternMatcher = STACK_LINE.matcher(stackTraceLine);

					if(!patternMatcher.find() || stackTraceLine.contains(CLASS_SUFFIX))
					{
						stackTraceLines.remove(i);
					}
				}

				stackTrace = UTIL_String.join(stackTraceLines, UTIL_String.LF);
			}

			return stackTrace;
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
	private class DTO_LogMessage
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
	private class LoggerProcessor implements IF_Async.Processable
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
	private class DTO_LoggerContext
	{
		public String correlationId;
		public String parentTransactionId;
		public Map<String, String> contextData;
	}

	/**
	 * @description Exception used exclusively for testing error handling paths.
	 * Avoids misusing semantically-specific exceptions like CalloutException.
	 */
	@TestVisible
	private class TestSimulatedException extends Exception
	{
	}
}