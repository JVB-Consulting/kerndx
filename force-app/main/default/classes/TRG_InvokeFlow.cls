// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Trigger action that invokes an auto-launched Flow as a trigger callback.
 * Subscribers configure flow actions via `TriggerAction__mdt` records by setting
 * `FlowName__c` (the framework dispatches through `TRG_InvokeFlow` automatically;
 * subscribers leave `ApexClassName__c` blank). `FailureAction__c` controls how
 * runtime exceptions surface. The framework reads its configuration via the
 * `IF_Trigger.Configurable` hook and invokes the target flow via the 3-arg form
 * `Flow.Interview.createInterview(namespace, flowName, variables).start()` with an
 * empty-string namespace parsed from any `namespace__name` prefix. Only a literal
 * `null` namespace raises an uncatchable `System.UnexpectedException` on `start()`,
 * which is why the empty-string form is used.
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
 * @date April 2026, June 2026
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
	 * @description Name of the flow input variable carrying the typed `DTO_ChangeEventHeader` for
	 * Change Event (CDC) dispatches. Subscriber flows registered against a Change Event entity
	 * declare an Apex-defined variable named `header` (Apex Class = `DTO_ChangeEventHeader`) to
	 * receive the change-event metadata. Non-CDC dispatches omit this variable.
	 */
	private static final String HEADER_VAR = 'header';

	/**
	 * @description Field name on a Change Event SObject carrying the platform
	 * `EventBus.ChangeEventHeader`. Read once per CDC record and projected onto
	 * `DTO_ChangeEventHeader` for the flow input variable.
	 */
	private static final String CHANGE_EVENT_HEADER_FIELD = 'ChangeEventHeader';

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
	 * @description Maximum number of underlying record Ids surfaced in the CDC aggregate
	 * audit's `CONTEXT_RECORD_IDS` payload. A single CDC dispatch can carry far more than
	 * 200 underlying record Ids when multiple Change Event records aggregate into one
	 * dispatch loop. The audit's purpose is "what was the dispatch targeting" — the first
	 * MAX_AUDITED_IDS Ids surface in `CONTEXT_RECORD_IDS` for spot-checking while
	 * `CONTEXT_RECORD_COUNT` carries the true uncapped total.
	 */
	private static final Integer MAX_AUDITED_IDS = 200;

	/**
	 * @description `errorKind` value tagged on the warning audit entry emitted when a
	 * Change Event dispatch resolves a `BlockDml` failure policy. The framework cannot
	 * actually call `record.addError(...)` on a Change Event record (the underlying change
	 * has already committed — there is nothing to roll back), so the policy is degraded
	 * to `LogAndContinue` semantics and a distinct queryable signal is emitted naming the
	 * degrade so subscribers can pivot diagnostic queries on the degrade event.
	 */
	private static final String ERROR_KIND_CDC_BLOCK_DML_DEGRADED = 'cdc-block-dml-degraded';

	/**
	 * @description Warning message template for the BlockDml-on-CDC degrade emission.
	 * Tokens: `{0}` flow API name. Substitutes into the audit entry's `Message__c` so
	 * subscribers reading the log see why the configured `BlockDml` policy did not block.
	 */
	private static final String CDC_BLOCK_DML_DEGRADE_MESSAGE_TEMPLATE =
			'BlockDml is not supported on Change Event dispatch (cannot roll back a committed change) — degraded to LogAndContinue: {0}';

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
	 * @description Test-only seam — when set to a non-null `DTO_ChangeEventHeader`,
	 * the CDC dispatch path uses it as the injected `header` flow input variable instead
	 * of projecting one from the platform `EventBus.ChangeEventHeader` on the record.
	 *
	 * Why this seam exists: the production cast
	 * `(EventBus.ChangeEventHeader)record.get('ChangeEventHeader')` works for real
	 * platform-delivered Change Event records, but crashes the platform with
	 * `UNKNOWN_EXCEPTION` (an uncatchable runtime error, not a normal Apex exception)
	 * when applied to a JSON-deserialized Change Event SObject. Both `TST_Builder` and
	 * `TST_Mock` serialize → deserialize through JSON for `withoutInsertion()` builds,
	 * so any in-memory Change Event SObject constructed in unit tests carries the same
	 * platform-unsafe `ChangeEventHeader` shape. The real CDC delivery path is exercised
	 * end-to-end by subscriber-org integration tests via `Test.enableChangeDataCapture()`
	 * + `Test.getEventBus().deliver()`, where Salesforce-internal CDC infrastructure
	 * produces a castable header.
	 */
	@TestVisible
	private static DTO_ChangeEventHeader simulateChangeEventHeaderForTest = null;

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
			String resolvedObjectName = TRG_Base.resolveSObjectName(newRecords, oldRecords);
			stats.isCdcDispatch = String.isNotBlank(resolvedObjectName) && resolvedObjectName.endsWith(UTIL_SObjectDescribe.CHANGE_EVENT_SUFFIX);
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
	 * attempted / failed Ids onto `stats` for the closing audit emission. For CDC dispatches
	 * the per-record loop projects the platform `EventBus.ChangeEventHeader` onto a
	 * `DTO_ChangeEventHeader`, accumulates the header's underlying record Ids into the
	 * audit list (capped at `MAX_AUDITED_IDS`), and threads the typed header into
	 * `invokeSingle` so the Flow input variables map carries the `header` variable.
	 *
	 * @param drivingRecords The post- or pre-image records driving dispatch.
	 * @param oldRecordsById Pre-image records indexed by Id for `recordPrior` lookup, or null.
	 * @param flowName The configured flow API name.
	 * @param failureAction The resolved `FailureAction__c` policy for the dispatch.
	 * @param stats The mutable run-statistics accumulator. `stats.isCdcDispatch` is read to
	 * decide whether to project the change-event header and accumulate audit ids from it.
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
			DTO_ChangeEventHeader changeEventHeader = null;
			if(stats.isCdcDispatch)
			{
				changeEventHeader = buildChangeEventHeaderDto(record);
				accumulateCdcAuditIds(stats, changeEventHeader);
			}
			else if(record.Id != null)
			{
				stats.attemptedRecordIds.add(record.Id);
			}
			SObject priorRecord = (record.Id != null && oldRecordsById != null) ? oldRecordsById.get(record.Id) : null;
			Boolean recordSucceeded = invokeSingle(record, priorRecord, flowName, failureAction, isMocked, changeEventHeader);
			if(!recordSucceeded)
			{
				if(stats.isCdcDispatch)
				{
					stats.failedCdcRecordCount++;
				}
				else if(record.Id != null)
				{
					stats.failedRecordIds.add(record.Id);
				}
			}
		}
	}

	/**
	 * @description Accumulates the underlying record Ids carried on a Change Event header
	 * into the dispatch's audit list and increments the running total. The audit list is
	 * capped at `MAX_AUDITED_IDS` (the first N Ids surface in `CONTEXT_RECORD_IDS` for
	 * spot-checking), but the running total reflects the full uncapped sum surfaced in
	 * `CONTEXT_RECORD_COUNT` so subscribers querying the audit always see "how many
	 * underlying records did the dispatch target". A header carrying a null `recordIds`
	 * (defensive; production CDC always populates it) is a no-op.
	 *
	 * @param stats The mutable run-statistics accumulator.
	 * @param header The projected Change Event header carrying the underlying record Ids.
	 */
	private static void accumulateCdcAuditIds(RunStats stats, DTO_ChangeEventHeader header)
	{
		List<String> headerIds = header.recordIds;
		if(headerIds == null)
		{
			return;
		}
		stats.totalCdcRecordIdCount += headerIds.size();
		Integer remainingCapacity = MAX_AUDITED_IDS - stats.attemptedCdcRecordIds.size();
		if(remainingCapacity <= 0)
		{
			return;
		}
		Integer take = Math.min(remainingCapacity, headerIds.size());
		for(Integer i = 0; i < take; i++)
		{
			stats.attemptedCdcRecordIds.add(headerIds[i]);
		}
	}

	/**
	 * @description Mutable accumulator carrying per-dispatch run statistics. For non-CDC
	 * dispatches the `recordCount` / `attemptedRecordIds` / `failedRecordIds` triad surfaces
	 * in the closing audit. For CDC dispatches the dispatch counters do not match user-meaningful
	 * "records affected" semantics (one change-event record can carry many underlying record
	 * Ids), so a parallel `totalCdcRecordIdCount` / `attemptedCdcRecordIds` / `failedCdcRecordCount`
	 * triad is populated from the projected change-event header and surfaces instead of the
	 * dispatch counters. `isCdcDispatch` is set by `run()` once per dispatch and read by
	 * `processRecords` + `emitAuditEvent` to choose which triad to use.
	 */
	private class RunStats
	{
		/**
		 * @description Total records the dispatch is iterating, captured up-front. For CDC
		 * dispatches this is the change-event record count (not the underlying record Id
		 * count surfaced in the audit) — the audit uses `totalCdcRecordIdCount` instead.
		 */
		final Integer recordCount;
		/**
		 * @description Ids the non-CDC dispatch attempted to process (excludes records without
		 * an Id). Includes Ids whose invocation subsequently failed — `attempted` is a superset
		 * of `failed`. Unused for CDC dispatches; see `attemptedCdcRecordIds`.
		 */
		final List<Id> attemptedRecordIds;
		/**
		 * @description Ids whose non-CDC flow invocation failed (subset of `attemptedRecordIds`).
		 * Unused for CDC dispatches; see `failedCdcRecordCount`.
		 */
		final List<Id> failedRecordIds;
		/**
		 * @description True when the dispatch targets a Change Event entity. Set once in `run()`
		 * after the empty-records short-circuit; read by `processRecords` and `emitAuditEvent`
		 * to route through the CDC accumulator + audit branches.
		 */
		Boolean isCdcDispatch;
		/**
		 * @description Total underlying record Ids across all change-event records in the
		 * dispatch (uncapped sum of `header.recordIds.size()`). Surfaces in `CONTEXT_RECORD_COUNT`
		 * for CDC dispatches. Unused for non-CDC dispatches.
		 */
		Integer totalCdcRecordIdCount;
		/**
		 * @description Underlying record Ids surfaced in the CDC audit, capped at `MAX_AUDITED_IDS`.
		 * The first N Ids encountered across all change-event records — `totalCdcRecordIdCount`
		 * carries the full count. Unused for non-CDC dispatches.
		 */
		final List<String> attemptedCdcRecordIds;
		/**
		 * @description Number of change-event records whose flow invocation failed. Surfaces in
		 * `CONTEXT_ERROR_COUNT` for CDC dispatches. Per-record error context (one entry per
		 * failed change-event record) emits via `emitErrorEntry` regardless of this counter.
		 */
		Integer failedCdcRecordCount;

		RunStats(List<SObject> drivingRecords)
		{
			attemptedCdcRecordIds = new List<String>();
			attemptedRecordIds = new List<Id>();
			failedCdcRecordCount = 0;
			failedRecordIds = new List<Id>();
			isCdcDispatch = false;
			recordCount = drivingRecords?.size() ?? 0;
			totalCdcRecordIdCount = 0;
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
	 * @param changeEventHeader The projected `DTO_ChangeEventHeader` for CDC dispatches, or null
	 * for non-CDC dispatches. When non-null, the header is injected as the `header` flow input
	 * variable and threaded to the mock recorder; a non-null value also signals the CDC
	 * branch in failure routing (BlockDml is degraded to LogAndContinue).
	 *
	 * @return True when the flow completed without error, false otherwise.
	 */
	// Suppressed because: dual-phase Flow.Interview catch (createInterview lookup vs start runtime) +
	// mock short-circuit + mock-result handling fan out to ~11 branches; combining them in one
	// method keeps the read-flow linear so reviewers can trace the per-record happy/error path.
	@SuppressWarnings('PMD.CyclomaticComplexity,PMD.ExcessiveParameterList')
	private static Boolean invokeSingle(SObject record, SObject priorRecord, String flowName, String failureAction, Boolean isMocked, DTO_ChangeEventHeader changeEventHeader)
	{
		Boolean isChangeEvent = (changeEventHeader != null);
		Map<String, Object> variables = new Map<String, Object> {RECORD_VAR => record};
		if(priorRecord != null)
		{
			variables.put(RECORD_PRIOR_VAR, priorRecord);
		}
		if(isChangeEvent)
		{
			variables.put(HEADER_VAR, changeEventHeader);
		}

		Flow.Interview interview = null;
		if(isMocked)
		{
			TST_InvokeFlowMock.recordInvocation(flowName, record, priorRecord, changeEventHeader);
		}
		else
		{
			interview = createInterviewOrFail(record, flowName, failureAction, variables, isChangeEvent);
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
				return handleMockResult(record, flowName, failureAction, mockResult, isChangeEvent);
			}
			interview.start();
		}
		catch(Exception caught)
		{
			if(UTIL_Exceptions.isFatalGovernorError(caught))
			{
				throw caught;
			}
			handleFailure(new FailureContext(record, flowName, failureAction, caught.getMessage(), caught, ErrorKind.RUNTIME, isChangeEvent));
			return false;
		}

		applyResults(record, (SObject)interview.getVariableValue(RECORD_VAR));
		return true;
	}

	/**
	 * @description Projects the platform `EventBus.ChangeEventHeader` carried on a Change
	 * Event SObject onto a Flow-accessible `DTO_ChangeEventHeader`. When
	 * `simulateChangeEventHeaderForTest` is set, returns the simulated DTO instead — the
	 * production cast `(EventBus.ChangeEventHeader)record.get(...)` cannot be exercised
	 * from unit-mode Apex tests because `TST_Builder`, `TST_Mock`, and raw `JSON.deserialize`
	 * construct in-memory Change Event SObjects whose `ChangeEventHeader` field crashes
	 * the platform on cast (`UNKNOWN_EXCEPTION`, uncatchable). Real CDC delivery via
	 * `Test.enableChangeDataCapture()` produces castable headers and is covered by the
	 * subscriber-org integration tests.
	 *
	 * @param record The Change Event SObject (e.g. `AccountChangeEvent`, `Foobar__ChangeEvent`).
	 *
	 * @return The projected `DTO_ChangeEventHeader` for injection as the `header` flow input variable.
	 */
	private static DTO_ChangeEventHeader buildChangeEventHeaderDto(SObject record)
	{
		return simulateChangeEventHeaderForTest ?? new DTO_ChangeEventHeader((EventBus.ChangeEventHeader)record.get(CHANGE_EVENT_HEADER_FIELD));
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
	 * @param isChangeEvent True when the dispatch targets a Change Event entity (threaded into `FailureContext` for CDC-aware failure routing).
	 *
	 * @return The constructed `Flow.Interview`, or `null` when construction failed.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static Flow.Interview createInterviewOrFail(SObject record, String flowName, String failureAction, Map<String, Object> variables, Boolean isChangeEvent)
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
			handleFailure(new FailureContext(record, flowName, failureAction, CONFIG_ERROR_PREFIX + configError.getMessage(), configError, ErrorKind.CONFIGURATION, isChangeEvent));
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
							ErrorKind.CONFIGURATION_UNEXPECTED,
							isChangeEvent
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
	 * @param isChangeEvent True when the dispatch targets a Change Event entity (threaded into `FailureContext` for CDC-aware failure routing).
	 *
	 * @return True when the mock represents success, false when it represents failure.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static Boolean handleMockResult(SObject record, String flowName, String failureAction, TST_InvokeFlowMock.MockResult mockResult, Boolean isChangeEvent)
	{
		if(mockResult.success)
		{
			applyResults(record, mockResult.outputRecord);
			return true;
		}
		handleFailure(new FailureContext(record, flowName, failureAction, mockResult.errorMessage, null, ErrorKind.RUNTIME, isChangeEvent));
		return false;
	}

	/**
	 * @description Bundles the parameters describing a single flow failure so failure-routing helpers
	 * can take one argument instead of seven. Built at the failure call site; never reused across records.
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
		final Boolean isChangeEvent;

		FailureContext(SObject record, String flowName, String failureAction, String errorMessage, Exception sourceException, ErrorKind errorKind, Boolean isChangeEvent)
		{
			this.record = record;
			this.flowName = flowName;
			this.failureAction = failureAction;
			this.errorMessage = errorMessage;
			this.sourceException = sourceException;
			this.errorKind = errorKind;
			this.isChangeEvent = isChangeEvent;
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
	 * For Change Event dispatches `BlockDml` is **degraded** to `LogAndContinue` semantics
	 * because the underlying change has already committed by the time CDC fires — calling
	 * `record.addError(...)` cannot roll back a committed change. The degrade emits a
	 * distinct warning audit entry tagged `errorKind = cdc-block-dml-degraded` so
	 * subscribers can pivot queries on the policy switch.
	 *
	 * @param context The bundled failure context for the record being routed.
	 */
	private static void handleFailure(FailureContext context)
	{
		emitErrorEntry(context);
		if(context.failureAction != SEL_TriggerAction.FAILURE_ACTION_BLOCK_DML)
		{
			return;
		}
		if(context.isChangeEvent)
		{
			emitCdcBlockDmlDegradeWarning(context);
			return;
		}
		String formattedMessage = String.format
				(
						BLOCK_DML_MESSAGE_TEMPLATE,
						new List<Object> {context.flowName, context.errorMessage, String.valueOf(context.record.Id)}
				);
		context.record.addError(formattedMessage);
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
	 * @description Emits a warning-level audit log entry naming the `BlockDml`-on-CDC
	 * degrade. Carries `errorKind = cdc-block-dml-degraded` + `failureAction = BlockDml`
	 * so subscribers can pivot diagnostic queries on the degrade event. The parallel
	 * `emitErrorEntry` still emits for the underlying flow failure; this warning is the
	 * additional signal naming the policy switch.
	 *
	 * @param context The bundled failure context for the record being degraded.
	 */
	private static void emitCdcBlockDmlDegradeWarning(FailureContext context)
	{
		String warningMessage = String.format
				(
						CDC_BLOCK_DML_DEGRADE_MESSAGE_TEMPLATE,
						new List<Object> {context.flowName}
				);
		LOG_Builder.build()
				.warn(warningMessage)
				.at(AT_LOCATION)
				.forRecord(context.record?.Id)
				.withContext(LOG_Engine.CONTEXT_EVENT_NAME, EVENT_NAME)
				.withContext(LOG_Engine.CONTEXT_FLOW_NAME, context.flowName)
				.withContext(LOG_Engine.CONTEXT_ERROR_KIND, ERROR_KIND_CDC_BLOCK_DML_DEGRADED)
				.withContext(LOG_Engine.CONTEXT_FAILURE_ACTION, SEL_TriggerAction.FAILURE_ACTION_BLOCK_DML)
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

		Integer errorCount = stats.isCdcDispatch ? stats.failedCdcRecordCount : stats.failedRecordIds.size();
		Integer auditRecordCount = stats.isCdcDispatch ? stats.totalCdcRecordIdCount : stats.recordCount;
		Object auditRecordIds = stats.isCdcDispatch ? (Object)stats.attemptedCdcRecordIds : (Object)stats.attemptedRecordIds;
		Boolean success = (errorCount == 0);
		LOG_Builder.build()
				.info(EVENT_NAME + ': ' + flowName)
				.at(AT_LOCATION)
				.withContext(LOG_Engine.CONTEXT_EVENT_NAME, EVENT_NAME)
				.withContext(LOG_Engine.CONTEXT_FLOW_NAME, flowName)
				.withContext(LOG_Engine.CONTEXT_TRIGGER_OPERATION, triggerContext?.name())
				.withContext(LOG_Engine.CONTEXT_RECORD_COUNT, auditRecordCount)
				.withContext(LOG_Engine.CONTEXT_DURATION_MS, durationMs)
				.withContext(LOG_Engine.CONTEXT_SUCCESS, success)
				.withContext(LOG_Engine.CONTEXT_ERROR_COUNT, errorCount)
				.withContext(LOG_Engine.CONTEXT_RECORD_IDS, auditRecordIds)
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