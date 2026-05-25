// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Trigger action that invokes an auto-launched Flow as a trigger callback.
 * Subscribers configure flow actions via `TriggerAction__mdt` records by setting
 * `FlowName__c` (the framework dispatches through `TRG_InvokeFlow` automatically;
 * subscribers leave `ApexClassName__c` blank). `FailureAction__c` controls how
 * runtime exceptions surface. The framework reads its configuration via the
 * `IF_Trigger.Configurable` hook and invokes the target flow via the 2-arg form
 * `Flow.Interview.createInterview(flowName, variables).start()`. The 3-arg form
 * is not used because passing `null` as the namespace argument raises an
 * uncatchable `System.UnexpectedException` on `start()`.
 *
 * For each trigger record the framework constructs a per-record interview, supplies
 * `record` (in/out) and — for update contexts — `recordPrior` (in only), executes the
 * flow, and copies the populated fields from the flow's output `record` variable back
 * onto the trigger record via `getPopulatedFieldsAsMap()`. Test authors can register
 * canned responses via `TST_InvokeFlowMock.forFlow(name)...register()` to bypass the
 * `Flow.Interview` runtime entirely.
 *
 * Failure handling (`FailureAction__c`):
 * - `LogAndContinue` (default): emits a `LogEntryEvent__e` via `LOG_Builder` and lets
 *   DML proceed.
 * - `BlockDml`: calls `record.addError(...)` to block the save and surface the
 *   formatted error to the user.
 *
 * Audit emission is gated by `LogSetting__c.EnableFlowActionLogging__c` with three
 * values: `Off`, `ErrorsOnly` (default), `AlwaysOn`. Performance monitoring is
 * inherited from the dispatcher's existing `UTIL_TriggerPerformanceTimer` wrapping —
 * `flowName` is appended automatically when present.
 *
 * @see TRG_InvokeFlow_TEST
 * @see TRG_Base
 * @see IF_Trigger
 * @see TST_InvokeFlowMock
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date April 2026, May 2026
 *
 * @since 1.0
 */
// Suppressed because: framework-level dispatch action coordinates 7 IF_Trigger contexts plus the
// IF_Trigger.Configurable hook plus dual-phase Flow.Interview catch — splitting further would
// fragment the per-context branch table and obscure the per-record loop's audit-emit semantics.
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
public inherited sharing class TRG_InvokeFlow extends TRG_Base implements
				IF_Trigger.AfterDelete,
				IF_Trigger.AfterInsert,
				IF_Trigger.AfterUndelete,
				IF_Trigger.AfterUpdate,
				IF_Trigger.BeforeDelete,
				IF_Trigger.BeforeInsert,
				IF_Trigger.BeforeUpdate,
				IF_Trigger.Configurable
{
	/**
	 * @description Name of the flow input variable carrying the trigger record.
	 */
	private static final String RECORD_VAR = 'record';

	/**
	 * @description Name of the flow input variable carrying the pre-update record (update contexts only).
	 */
	private static final String RECORD_PRIOR_VAR = 'recordPrior';

	/**
	 * @description `LogSetting__c.EnableFlowActionLogging__c` value emitting per-record entries on error only.
	 */
	private static final String LOG_MODE_ERRORS_ONLY = 'ErrorsOnly';

	/**
	 * @description `LogSetting__c.EnableFlowActionLogging__c` value emitting a per-batch summary on success and per-record entries on error.
	 */
	private static final String LOG_MODE_ALWAYS_ON = 'AlwaysOn';

	/**
	 * @description Audit event name used by both per-record and per-batch log entries (queryable on the `eventName` context key).
	 */
	private static final String EVENT_NAME = 'flow-action.invoke';

	/**
	 * @description Class+method location string used in `LOG_Builder.at(...)` calls.
	 * Computed via `class.getName()` so the emitted `ClassMethod__c` is namespace-aware
	 * (`TRG_InvokeFlow.run` in unmanaged dev orgs / `kern.TRG_InvokeFlow.run` in managed
	 * subscriber installs) — matches the convention used across `LOG_Builder.at(...)`
	 * sites elsewhere in the framework so downstream diagnostic queries resolve cleanly
	 * in either context.
	 */
	private static final String AT_LOCATION = TRG_InvokeFlow.class.getName() + '.run';

	/**
	 * @description Prefix applied to wrapped configuration-error messages.
	 */
	private static final String CONFIG_ERROR_PREFIX = 'Configuration error: ';

	/**
	 * @description Template applied by `String.format` to build the BlockDml addError message.
	 * Tokens: `{0}` flow API name, `{1}` original error message, `{2}` triggering record Id (or "null").
	 */
	private static final String BLOCK_DML_MESSAGE_TEMPLATE = '[{0}] {1} (record: {2})';

	/**
	 * @description Discriminator distinguishing classes of flow-action failure for downstream
	 * audit pivoting on the `errorKind` log context key.
	 */
	private enum ErrorKind
	{
		/**
		 * @description Type-resolution failure raised during `Flow.Interview.createInterview`.
		 */
		CONFIGURATION,
		/**
		 * @description Non-`TypeException` failure raised during `createInterview` (defense-in-depth branch).
		 */
		CONFIGURATION_UNEXPECTED,
		/**
		 * @description Failure raised during `interview.start()` or by a mock's `exceptionToThrow`.
		 */
		RUNTIME
	}

	/**
	 * @description Maps `ErrorKind` enum values to their wire-format strings (kebab-cased to match
	 * the audit-event naming convention of `flow-action.invoke`).
	 */
	private static final Map<ErrorKind, String> ERROR_KIND_LABEL = new Map<ErrorKind, String>
	{
			ErrorKind.CONFIGURATION => 'configuration',
			ErrorKind.CONFIGURATION_UNEXPECTED => 'configuration-unexpected',
			ErrorKind.RUNTIME => 'runtime'
	};

	/**
	 * @description Active TriggerAction__mdt configuration for this dispatch. Set by `setConfig`.
	 */
	@TestVisible
	private TriggerAction__mdt actionConfig;

	/**
	 * @description Test-only seam — when set to a non-null Exception, `invokeSingle` throws
	 * it instead of calling `Flow.Interview.createInterview`. Lets tests drive the
	 * `catch(Exception unexpectedConfigError)` defense-in-depth branch without coercing
	 * the platform Flow runtime into raising a non-`TypeException` class. Production
	 * code paths leave this `null`.
	 */
	@TestVisible
	private static Exception simulateCreateInterviewExceptionForTest = null;

	/**
	 * @description Stores the active TriggerAction__mdt configuration for this dispatch.
	 * Called exactly once by `TRG_Dispatcher` between `newInstance()` and the
	 * trigger-context interface method, per `TriggerAction__mdt` row.
	 *
	 * Implementations MUST NOT mutate `config` — the dispatcher's recursion-identity
	 * fingerprint relies on `config.DeveloperName` being stable across the action's
	 * lifetime. Subclasses overriding `setConfig` must call `super.setConfig(config)`
	 * and treat the supplied row as read-only.
	 *
	 * @param config The active TriggerAction__mdt record for this dispatch.
	 */
	public void setConfig(TriggerAction__mdt config)
	{
		this.actionConfig = config;
	}

	/**
	 * @description Dispatches the configured flow once per record in `newRecords`.
	 *
	 * @param newRecords Records about to be inserted.
	 */
	public void beforeInsert(List<SObject> newRecords)
	{
		run(TriggerOperation.BEFORE_INSERT, newRecords, null);
	}

	/**
	 * @description Dispatches the configured flow once per record in `newRecords`.
	 *
	 * @param newRecords Records that were inserted.
	 */
	public void afterInsert(List<SObject> newRecords)
	{
		run(TriggerOperation.AFTER_INSERT, newRecords, null);
	}

	/**
	 * @description Dispatches the configured flow once per record in `newRecords`, supplying
	 * the matching pre-update record as `recordPrior` (input-only).
	 *
	 * @param newRecords Records with their proposed values.
	 * @param oldRecords Records with their pre-update values.
	 */
	public void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords)
	{
		run(TriggerOperation.BEFORE_UPDATE, newRecords, oldRecords);
	}

	/**
	 * @description Dispatches the configured flow once per record in `newRecords`, supplying
	 * the matching pre-update record as `recordPrior` (input-only).
	 *
	 * @param newRecords Records with their committed values.
	 * @param oldRecords Records with their pre-update values.
	 */
	public void afterUpdate(List<SObject> newRecords, List<SObject> oldRecords)
	{
		run(TriggerOperation.AFTER_UPDATE, newRecords, oldRecords);
	}

	/**
	 * @description Dispatches the configured flow once per record in `oldRecords`.
	 *
	 * @param oldRecords Records about to be deleted.
	 */
	public void beforeDelete(List<SObject> oldRecords)
	{
		run(TriggerOperation.BEFORE_DELETE, null, oldRecords);
	}

	/**
	 * @description Dispatches the configured flow once per record in `oldRecords`.
	 *
	 * @param oldRecords Records that were deleted.
	 */
	public void afterDelete(List<SObject> oldRecords)
	{
		run(TriggerOperation.AFTER_DELETE, null, oldRecords);
	}

	/**
	 * @description Dispatches the configured flow once per record in `newRecords`.
	 *
	 * @param newRecords Records that were restored from the Recycle Bin.
	 */
	public void afterUndelete(List<SObject> newRecords)
	{
		run(TriggerOperation.AFTER_UNDELETE, newRecords, null);
	}

	/**
	 * @description Per-context dispatch entrypoint. Resolves the failure strategy + input mode,
	 * loops the trigger records invoking the flow per-record, then emits a single audit
	 * `LogEntryEvent__e` per `LogSetting__c.EnableFlowActionLogging__c`. Wrapped in
	 * try/finally so audit emission always runs even on unexpected exceptions.
	 *
	 * @param triggerContext The trigger operation context (for log/audit metadata).
	 * @param newRecords The post-image records (or null for delete contexts).
	 * @param oldRecords The pre-image records (or null for non-update/non-delete contexts).
	 */
	private void run(TriggerOperation triggerContext, List<SObject> newRecords, List<SObject> oldRecords)
	{
		String flowName = actionConfig?.FlowName__c;
		String failureAction = String.isNotBlank(actionConfig?.FailureAction__c) ?
				actionConfig.FailureAction__c : SEL_TriggerAction.FAILURE_ACTION_LOG_AND_CONTINUE;
		List<SObject> drivingRecords = (newRecords != null) ? newRecords : oldRecords;
		Map<Id, SObject> oldRecordsById = UTIL_SObject.indexById(oldRecords, 'Id');
		RunStats stats = new RunStats(drivingRecords);
		Long startMs = System.currentTimeMillis();

		try
		{
			if(stats.recordCount == 0 || String.isBlank(flowName))
			{
				return;
			}
			processRecords(drivingRecords, oldRecordsById, flowName, failureAction, stats);
		}
		finally
		{
			Long durationMs = System.currentTimeMillis() - startMs;
			emitAuditEvent(flowName, triggerContext, stats, durationMs);
		}
	}

	/**
	 * @description Loops the trigger records invoking the flow per-record, accumulating
	 * attempted / failed Ids onto `stats` for the closing audit emission.
	 *
	 * @param drivingRecords The post- or pre-image records driving dispatch.
	 * @param oldRecordsById Pre-image records indexed by Id for `recordPrior` lookup, or null.
	 * @param flowName The configured flow API name.
	 * @param failureAction The resolved `FailureAction__c` policy for the dispatch.
	 * @param stats The mutable run-statistics accumulator.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static void processRecords
			(
					List<SObject> drivingRecords,
					Map<Id, SObject> oldRecordsById,
					String flowName,
					String failureAction,
					RunStats stats
			)
	{
		Boolean isMocked = TST_InvokeFlowMock.isMocked(flowName);
		for(SObject record : drivingRecords)
		{
			if(record.Id != null)
			{
				stats.attemptedRecordIds.add(record.Id);
			}
			SObject priorRecord = (record.Id != null && oldRecordsById != null) ? oldRecordsById.get(record.Id) : null;
			Boolean recordSucceeded = invokeSingle(record, priorRecord, flowName, failureAction, isMocked);
			if(!recordSucceeded && record.Id != null)
			{
				stats.failedRecordIds.add(record.Id);
			}
		}
	}

	/**
	 * @description Mutable accumulator carrying per-dispatch run statistics (record count and
	 * the attempted / failed Id lists). Built once per `run()` call.
	 */
	private class RunStats
	{
		/**
		 * @description Total records the dispatch is iterating, captured up-front.
		 */
		final Integer recordCount;
		/**
		 * @description Ids the dispatch attempted to process (excludes records without an Id).
		 * Includes Ids whose invocation subsequently failed — `attempted` is a superset of `failed`.
		 */
		final List<Id> attemptedRecordIds;
		/**
		 * @description Ids whose flow invocation failed (subset of `attemptedRecordIds`).
		 */
		final List<Id> failedRecordIds;

		RunStats(List<SObject> drivingRecords)
		{
			recordCount = drivingRecords?.size() ?? 0;
			attemptedRecordIds = new List<Id>();
			failedRecordIds = new List<Id>();
		}
	}

	/**
	 * @description Invokes the configured flow for a single trigger record. Short-circuits to
	 * `TST_InvokeFlowMock` when a mock is registered for the flow name. Otherwise constructs a
	 * `Flow.Interview` via the 3-arg form (with explicit namespace) and runs it. The 2-arg form
	 * fails with `TypeException: Invalid type` when invoking managed-package flows across
	 * namespace boundaries — the platform does not reliably auto-resolve the namespace from a
	 * bare or pre-prefixed flow name. The 3-arg form with an empty-string namespace is safe;
	 * only a literal `null` namespace triggers an uncatchable `System.UnexpectedException` on
	 * `start()`.
	 *
	 * @param record The trigger record to pass into the flow as `record`.
	 * @param priorRecord The pre-update record to pass as `recordPrior`, or null when none.
	 * @param flowName The flow API name to invoke.
	 * @param failureAction The configured `FailureAction__c` value driving error routing.
	 * @param isMocked True when running under `TST_InvokeFlowMock`; bypasses `Flow.Interview` lookup and routes through the mock recorder.
	 *
	 * @return True when the flow completed without error, false otherwise.
	 */
	// Suppressed because: dual-phase Flow.Interview catch (createInterview lookup vs start runtime) +
	// mock short-circuit + mock-result handling fan out to ~11 branches; combining them in one
	// method keeps the read-flow linear so reviewers can trace the per-record happy/error path.
	@SuppressWarnings('PMD.CyclomaticComplexity,PMD.ExcessiveParameterList')
	private static Boolean invokeSingle(SObject record, SObject priorRecord, String flowName, String failureAction, Boolean isMocked)
	{
		Map<String, Object> variables = new Map<String, Object> {RECORD_VAR => record};
		if(priorRecord != null)
		{
			variables.put(RECORD_PRIOR_VAR, priorRecord);
		}

		Flow.Interview interview = null;
		if(isMocked)
		{
			TST_InvokeFlowMock.recordInvocation(flowName, record, priorRecord);
		}
		else
		{
			interview = createInterviewOrFail(record, flowName, failureAction, variables);
			if(interview == null)
			{
				return false;
			}
		}

		try
		{
			if(isMocked)
			{
				TST_InvokeFlowMock.MockResult mockResult = TST_InvokeFlowMock.getMockResult(flowName);
				if(mockResult.exceptionToThrow != null)
				{
					throw mockResult.exceptionToThrow;
				}
				return handleMockResult(record, flowName, failureAction, mockResult);
			}
			interview.start();
		}
		catch(Exception caught)
		{
			if(UTIL_Exceptions.isFatalGovernorError(caught))
			{
				throw caught;
			}
			handleFailure(new FailureContext(record, flowName, failureAction, caught.getMessage(), caught, ErrorKind.RUNTIME));
			return false;
		}

		applyResults(record, (SObject)interview.getVariableValue(RECORD_VAR));
		return true;
	}

	/**
	 * @description Constructs a `Flow.Interview` via the 3-arg form with explicit namespace
	 * parsed from a `namespace__name` shape in `flowName`, falling back to empty-string
	 * (unmanaged / current org) namespace when no prefix is present. Routes configuration
	 * errors through `handleFailure`. Returns `null` when construction fails so the caller
	 * can short-circuit. The empty-string namespace is safe; only literal `null` triggers
	 * the uncatchable `System.UnexpectedException` on `start()`.
	 *
	 * @param record The trigger record (for failure-context recording).
	 * @param flowName The flow API name to instantiate (may include `namespace__name` prefix for cross-namespace flows).
	 * @param failureAction The configured `FailureAction__c` value driving error routing.
	 * @param variables The flow input variables map.
	 *
	 * @return The constructed `Flow.Interview`, or `null` when construction failed.
	 */
	private static Flow.Interview createInterviewOrFail(SObject record, String flowName, String failureAction, Map<String, Object> variables)
	{
		try
		{
			if(simulateCreateInterviewExceptionForTest != null)
			{
				throw simulateCreateInterviewExceptionForTest;
			}
			return UTIL_System.createInterview(flowName, variables);
		}
		catch(System.TypeException configError)
		{
			handleFailure(new FailureContext(record, flowName, failureAction, CONFIG_ERROR_PREFIX + configError.getMessage(), configError, ErrorKind.CONFIGURATION));
			return null;
		}
		catch(Exception unexpectedConfigError)
		{
			if(UTIL_Exceptions.isFatalGovernorError(unexpectedConfigError))
			{
				throw unexpectedConfigError;
			}
			FailureContext failure = new FailureContext
					(
							record,
							flowName,
							failureAction,
							CONFIG_ERROR_PREFIX + unexpectedConfigError.getMessage(),
							unexpectedConfigError,
							ErrorKind.CONFIGURATION_UNEXPECTED
					);
			handleFailure(failure);
			return null;
		}
	}

	/**
	 * @description Applies a successful or failing mock outcome to the trigger record.
	 * Mirrors the runtime path so tests exercise the same error routing as production.
	 *
	 * @param record The trigger record receiving the mocked output.
	 * @param flowName The flow API name (for failure formatting and audit context).
	 * @param failureAction The configured `FailureAction__c` value driving error routing.
	 * @param mockResult The registered mock result.
	 *
	 * @return True when the mock represents success, false when it represents failure.
	 */
	private static Boolean handleMockResult(SObject record, String flowName, String failureAction, TST_InvokeFlowMock.MockResult mockResult)
	{
		if(mockResult.success)
		{
			applyResults(record, mockResult.outputRecord);
			return true;
		}
		handleFailure(new FailureContext(record, flowName, failureAction, mockResult.errorMessage, null, ErrorKind.RUNTIME));
		return false;
	}

	/**
	 * @description Bundles the parameters describing a single flow failure so failure-routing helpers
	 * can take one argument instead of six. Built at the failure call site; never reused across records.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private class FailureContext
	{
		final SObject record;
		final String flowName;
		final String failureAction;
		final String errorMessage;
		final Exception sourceException;
		final ErrorKind errorKind;

		FailureContext(SObject record, String flowName, String failureAction, String errorMessage, Exception sourceException, ErrorKind errorKind)
		{
			this.record = record;
			this.flowName = flowName;
			this.failureAction = failureAction;
			this.errorMessage = errorMessage;
			this.sourceException = sourceException;
			this.errorKind = errorKind;
		}
	}

	/**
	 * @description Copies the populated fields from the flow's output record onto the
	 * trigger record. Uses `getPopulatedFieldsAsMap()` so only fields the flow assigned
	 * are written back — fields the flow left untouched are preserved.
	 *
	 * Two filters apply:
	 * 1. **Typo guard.** Field names that don't exist on the trigger record's SObjectType are
	 *    skipped. `UTIL_SObjectDescribe.getFieldDescribe(name)` returns null for non-existent
	 *    fields and is namespace-aware — when the running Apex namespace differs from the
	 *    record's namespace (managed-package vs subscriber org), the lookup resolves through the
	 *    framework's request-cached describe wrapper rather than raw `Schema.fields.getMap()`.
	 * 2. **Non-editability defense-in-depth.** `try { put } catch(SObjectException)` silences
	 *    platform-level non-editable writes (read-only formulas, system audit fields like
	 *    `IsDeleted`/`CreatedDate`, calculated fields, auto-numbers). The catch is the safety
	 *    net for cases where the flow runtime returns the input record envelope with system
	 *    fields populated even though the flow didn't assign them. We deliberately do NOT
	 *    pre-filter on `isUpdateable()` because that flag also reflects the running user's
	 *    FLS — and this framework's contract is "write what the flow assigns; let DML enforce
	 *    FLS at the boundary".
	 *
	 * @param triggerRecord The trigger record receiving the field updates.
	 * @param flowOutput The new SObject instance returned by `Flow.Interview.getVariableValue`.
	 */
	private static void applyResults(SObject triggerRecord, SObject flowOutput)
	{
		if(flowOutput == null)
		{
			return;
		}
		UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(triggerRecord.getSObjectType());
		Map<String, Object> populated = flowOutput.getPopulatedFieldsAsMap();
		for(String fieldName : populated.keySet())
		{
			if(describe.getFieldDescribe(fieldName) == null)
			{
				continue;
			}
			tryPutField(triggerRecord, fieldName, populated.get(fieldName));
		}
	}

	/**
	 * @description Defense-in-depth wrapper around `SObject.put` that silences platform-level
	 * non-editable writes (read-only formula fields, system audit fields like `IsDeleted`/
	 * `CreatedDate`, calculated fields, auto-numbers). The describe-based typo guard in
	 * `applyResults` already filters non-existent field names; this catch covers the remaining
	 * runtime cases where `isUpdateable()` would falsely include the field at metadata level
	 * (e.g., the platform Flow runtime returning the input record envelope with system fields
	 * populated even though the flow didn't assign them).
	 *
	 * Extracted from the `applyResults` loop so the empty-catch suppression scope is local
	 * to this single line.
	 *
	 * @param triggerRecord The trigger record receiving the field assignment.
	 * @param fieldName The field API name (validated by caller).
	 * @param value The value to assign.
	 */
	@SuppressWarnings('PMD.EmptyCatchBlock')
	private static void tryPutField(SObject triggerRecord, String fieldName, Object value)
	{
		try
		{
			triggerRecord.put(fieldName, value);
		}
		catch(SObjectException nonEditable)
		{
			// Platform-level non-editable (formula / system audit / calculated): silently skip.
		}
	}

	/**
	 * @description Routes a flow failure through the configured `FailureAction__c` strategy.
	 * `LogAndContinue` emits a structured `LogEntryEvent__e` and lets DML proceed;
	 * `BlockDml` calls `record.addError(...)` with `[flowName] errorMessage (record: id)`.
	 *
	 * @param context The bundled failure context for the record being routed.
	 */
	private static void handleFailure(FailureContext context)
	{
		emitErrorEntry(context);
		if(context.failureAction == SEL_TriggerAction.FAILURE_ACTION_BLOCK_DML)
		{
			String formattedMessage = String.format
					(
							BLOCK_DML_MESSAGE_TEMPLATE,
							new List<Object> {context.flowName, context.errorMessage, String.valueOf(context.record.Id)}
					);
			context.record.addError(formattedMessage);
		}
	}

	/**
	 * @description Emits an error-level audit log entry for a failed flow invocation.
	 * Always emitted on the failure path regardless of the `LogAndContinue`/`BlockDml`
	 * strategy because the error is the audit signal callers query for.
	 *
	 * @param context The bundled failure context for the record being audited.
	 */
	private static void emitErrorEntry(FailureContext context)
	{
		LOG_Builder.LogEntry entry = (context.sourceException != null) ?
				LOG_Builder.build().error(context.sourceException) :
				LOG_Builder.build().error(context.errorMessage);
		entry.at(AT_LOCATION)
				.forRecord(context.record?.Id)
				.withContext(LOG_Engine.CONTEXT_EVENT_NAME, EVENT_NAME)
				.withContext(LOG_Engine.CONTEXT_FLOW_NAME, context.flowName)
				.withContext(LOG_Engine.CONTEXT_ERROR_MESSAGE, context.errorMessage)
				.withContext(LOG_Engine.CONTEXT_ERROR_KIND, ERROR_KIND_LABEL.get(context.errorKind))
				.emit();
	}

	/**
	 * @description Emits the per-batch summary or per-record audit entries based on
	 * `LogSetting__c.EnableFlowActionLogging__c`. Called from the `run()` finally block
	 * so audit always fires, even on unexpected exception paths.
	 *
	 * Modes:
	 * - `Off`: no entries.
	 * - `ErrorsOnly` (default): no entries — the per-record error entries emitted via
	 *   `emitErrorEntry` carry the audit signal.
	 * - `AlwaysOn`: a single per-batch summary entry covering every record processed
	 *   (success + failure), summarising counts.
	 *
	 * @param flowName The flow API name.
	 * @param triggerContext The trigger operation context.
	 * @param stats The mutable run-statistics accumulator carrying record count + attempted/failed Ids.
	 * @param durationMs Elapsed milliseconds across the dispatch loop.
	 */
	private static void emitAuditEvent(String flowName, TriggerOperation triggerContext, RunStats stats, Long durationMs)
	{
		if(resolveLoggingMode() != LOG_MODE_ALWAYS_ON)
		{
			return;
		}

		Integer errorCount = stats.failedRecordIds.size();
		Boolean success = (errorCount == 0);
		LOG_Builder.build()
				.info(EVENT_NAME + ': ' + flowName)
				.at(AT_LOCATION)
				.withContext(LOG_Engine.CONTEXT_EVENT_NAME, EVENT_NAME)
				.withContext(LOG_Engine.CONTEXT_FLOW_NAME, flowName)
				.withContext(LOG_Engine.CONTEXT_TRIGGER_OPERATION, triggerContext?.name())
				.withContext(LOG_Engine.CONTEXT_RECORD_COUNT, stats.recordCount)
				.withContext(LOG_Engine.CONTEXT_DURATION_MS, durationMs)
				.withContext(LOG_Engine.CONTEXT_SUCCESS, success)
				.withContext(LOG_Engine.CONTEXT_ERROR_COUNT, errorCount)
				.withContext(LOG_Engine.CONTEXT_RECORD_IDS, stats.attemptedRecordIds)
				.emit();
	}

	/**
	 * @description Resolves the effective `LogSetting__c.EnableFlowActionLogging__c` value,
	 * defaulting to `ErrorsOnly` when the setting is null or blank.
	 *
	 * @return The resolved logging mode (`Off` / `ErrorsOnly` / `AlwaysOn`).
	 */
	private static String resolveLoggingMode()
	{
		LogSetting__c setting = LOG_Engine.getLogSetting();
		String mode = setting?.EnableFlowActionLogging__c;
		return String.isNotBlank(mode) ? mode : LOG_MODE_ERRORS_ONLY;
	}
}