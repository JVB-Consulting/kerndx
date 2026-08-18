// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Controller for the Chain Monitor LWC components. Provides methods to query, filter,
 * sort, and paginate chain executions, and to retrieve parsed step detail DTOs. The LWC layer
 * receives display-ready DTOs and does not parse the StepLog JSON directly.
 *
 * @see CTRL_ChainMonitor_TEST
 * @see CTRL_ChainMonitorRedrive_TEST
 * @see CTRL_ChainMonitorTypes
 * @see LOG_Builder
 * @see SEL_AsyncChainExecution
 * @see SEL_LogEntry
 * @see UTIL_AsyncChain
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date April 2026, August 2026
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.CognitiveComplexity,PMD.ExcessiveClassLength')
public with sharing class CTRL_ChainMonitor
{
	/**
	 * @description Class name for log source attribution on the operator action endpoints.
	 */
	private static final String CLASS_NAME = CTRL_ChainMonitor.class.getName();

	/**
	 * @description Default page size for chain list queries.
	 */
	@TestVisible
	private static final Integer DEFAULT_PAGE_SIZE = 20;

	/**
	 * @description Server-side ceiling for client-supplied page sizes. The page size arrives from
	 * the client payload, so without a cap a crafted request could page the whole object in one query.
	 */
	private static final Integer MAX_PAGE_SIZE = 100;

	/**
	 * @description Step completed successfully.
	 */
	@TestVisible
	private static final String STEP_STATUS_SUCCESS = 'success';

	/**
	 * @description Step failed but chain continued (continueOnError).
	 */
	@TestVisible
	private static final String STEP_STATUS_WARNING = 'warning';

	/**
	 * @description Step failed and chain stopped.
	 */
	@TestVisible
	private static final String STEP_STATUS_FAILED = 'failed';

	/**
	 * @description Step has not yet executed. The LWC determines which pending step is currently
	 * running based on the chain's Status__c field.
	 */
	@TestVisible
	private static final String STEP_STATUS_PENDING = 'pending';

	/**
	 * @description Abort availability code carried on CTRL_ChainMonitorTypes.DTO_ChainDetail.abortAvailability: the chain
	 * has already finished, so there is nothing to abort. The action-agnostic codes (available,
	 * capability disabled, permission missing) live in the shared OPERATOR_* family below.
	 */
	@TestVisible
	private static final String ABORT_CHAIN_NOT_ABORTABLE = 'ChainNotAbortable';

	/**
	 * @description Reason recorded on ErrorMessage__c for an operator abort. Deliberately a literal
	 * English constant, not a label: it lands on record data, not in the UI copy path.
	 */
	private static final String OPERATOR_ABORT_REASON = 'Aborted by operator from the Chain Monitor';

	/**
	 * @description Availability code shared by the operator action gates (retry, restart,
	 * clear-stalled, kill-switch toggle): the action is available to the running user. Stable
	 * machine codes, never user-facing text — the monitor maps every code to a Custom Label.
	 *
	 * @since 1.7
	 */
	@TestVisible
	private static final String OPERATOR_AVAILABLE = 'Available';

	/**
	 * @description Availability code shared by the operator action gates: the action's capability
	 * flag is absent, inactive, or strategyless — the org-wide off state.
	 *
	 * @since 1.7
	 */
	@TestVisible
	private static final String OPERATOR_CAPABILITY_DISABLED = 'CapabilityDisabled';

	/**
	 * @description Availability code shared by the operator action gates: the capability flag is
	 * live but the running user lacks the permission its strategy names.
	 *
	 * @since 1.7
	 */
	@TestVisible
	private static final String OPERATOR_PERMISSION_MISSING = 'PermissionMissing';

	/**
	 * @description How many persisted log entries the live-stream seed returns — the most recent
	 * rows of the chain's correlated trace, rendered as history beneath the live tail. Bounded so
	 * the seed of a pathological correlation stays a UI-sized payload.
	 *
	 * @since 1.7
	 */
	@TestVisible
	private static final Integer LOG_STREAM_SEED_ROW_CAP = 20;

	/**
	 * @description The statuses of a run that has not finished, and so has no recorded duration to
	 * show. Both are re-drivable rather than terminal: Running is still working through its steps,
	 * and Stalled lost its background job but can be picked up again.
	 */
	private static final Set<String> UNFINISHED_STATUSES = new Set<String>
	{
			SEL_AsyncChainExecution.STATUS_RUNNING,
			SEL_AsyncChainExecution.STATUS_STALLED
	};

	/**
	 * @description Map of sortable field names to SObjectField tokens for compile-time safety.
	 */
	private static final Map<String, SObjectField> SORTABLE_FIELDS = new Map<String, SObjectField>
	{
			'ChainName' => AsyncChainExecution__c.ChainName__c,
			'Status' => AsyncChainExecution__c.Status__c,
			'StartedAt' => AsyncChainExecution__c.StartedAt__c,
			'DurationMs' => AsyncChainExecution__c.DurationMs__c,
			'CreatedDate' => AsyncChainExecution__c.CreatedDate
	};

	/**
	 * @description Retrieves a paginated, filtered, and sorted list of chain executions for the
	 * Chain Monitor list view. Delegates to SEL_AsyncChainExecution and uses framework pagination.
	 *
	 * @param requestJson The filter, sort, and pagination parameters.
	 *
	 * @return A CTRL_ChainMonitorTypes.DTO_ChainPage with records, pagination metadata, and total count.
	 *
	 * @example
	 * ```apex
	 * CTRL_ChainMonitorTypes.DTO_Request request = new CTRL_ChainMonitorTypes.DTO_Request();
	 * request.statusFilters = new List<String>{'Running', 'Failed'};
	 * request.pageNumber = 1;
	 * CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(request);
	 * ```
	 */
	@AuraEnabled
	public static CTRL_ChainMonitorTypes.DTO_ChainPage getChainExecutions(String requestJson)
	{
		CTRL_ChainMonitorTypes.DTO_Request request = String.isBlank(requestJson)
				? new CTRL_ChainMonitorTypes.DTO_Request()
				: (CTRL_ChainMonitorTypes.DTO_Request)JSON.deserialize(requestJson, CTRL_ChainMonitorTypes.DTO_Request.class);

		SObjectField resolvedSortField = SORTABLE_FIELDS.get(request.sortField);
		if(resolvedSortField == null)
		{
			resolvedSortField = AsyncChainExecution__c.CreatedDate;
		}

		Integer resolvedPageSize = request.pageSize != null && request.pageSize > 0 ? request.pageSize : DEFAULT_PAGE_SIZE;
		resolvedPageSize = Math.min(resolvedPageSize, MAX_PAGE_SIZE);
		Integer resolvedPageNumber = request.pageNumber != null && request.pageNumber > 0 ? request.pageNumber : 1;

		QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered
				(
						request.statusFilters, request.nameFilter, resolvedSortField,
						request.sortAscending != true, resolvedPageNumber, resolvedPageSize
				);

		List<CTRL_ChainMonitorTypes.DTO_ChainSummary> summaries = new List<CTRL_ChainMonitorTypes.DTO_ChainSummary>();
		for(SObject record : page.records)
		{
			summaries.add(toChainSummary((AsyncChainExecution__c)record));
		}

		CTRL_ChainMonitorTypes.DTO_ChainPage result = new CTRL_ChainMonitorTypes.DTO_ChainPage();

		result.hasMorePages = page.hasMorePages;
		result.pageNumber = page.pageNumber;
		result.records = summaries;
		result.totalCount = page.totalRecords;
		result.totalPages = page.totalPages;

		return result;
	}

	/**
	 * @description Retrieves the full detail of a chain execution, including parsed step definitions
	 * as display-ready DTOs.
	 *
	 * @param executionId The ID of the AsyncChainExecution__c record.
	 *
	 * @return A CTRL_ChainMonitorTypes.DTO_ChainDetail with all chain metadata and parsed step details. Null if not found.
	 *
	 * @example
	 * ```apex
	 * CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(executionId);
	 * ```
	 */
	@AuraEnabled
	public static CTRL_ChainMonitorTypes.DTO_ChainDetail getChainDetail(Id executionId)
	{
		AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByIdForMonitoring(executionId);

		if(execution == null)
		{
			return null;
		}

		return toChainDetail(execution);
	}

	/**
	 * @description Retrieves parsed step definitions for a single chain execution. Lightweight method
	 * for the embedded record page component that only needs the step timeline.
	 *
	 * @param executionId The ID of the AsyncChainExecution__c record.
	 *
	 * @return List of CTRL_ChainMonitorTypes.DTO_StepDetail representing each step in the chain. Empty list if not found.
	 *
	 * @example
	 * ```apex
	 * List<CTRL_ChainMonitorTypes.DTO_StepDetail> steps = CTRL_ChainMonitor.getStepTimeline(executionId);
	 * ```
	 */
	@AuraEnabled(Cacheable=true)
	public static List<CTRL_ChainMonitorTypes.DTO_StepDetail> getStepTimeline(Id executionId)
	{
		AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByIdForMonitoring(executionId);

		if(execution == null)
		{
			return new List<CTRL_ChainMonitorTypes.DTO_StepDetail>();
		}

		return parseSteps(execution);
	}

	/**
	 * @description Resolves the chain execution that carries a correlation id, so a deep link
	 * arriving from the Log Console lands on the linked chain instead of the default selection.
	 * Uses the monitoring read, which sees chains org-wide exactly as the console's list does.
	 *
	 * @param correlationId The correlation id carried by the deep link.
	 *
	 * @return The Id of the matching AsyncChainExecution__c record, or null when the correlation
	 * id is blank or no registered chain carries it.
	 *
	 * @example
	 * ```apex
	 * Id executionId = CTRL_ChainMonitor.findChainExecutionIdByCorrelation('550e8400-e29b-41d4-a716-446655440000');
	 * ```
	 */
	@AuraEnabled
	public static Id findChainExecutionIdByCorrelation(String correlationId)
	{
		return new SEL_AsyncChainExecution().findByCorrelationIdForMonitoring(correlationId)?.Id;
	}

	/**
	 * @description Exposes the managed-package namespace prefix so the monitor LWC can build its
	 * streaming channel and payload key for the org it is actually running in: 'kern__' in a
	 * managed install, an empty string in an unmanaged (no-namespace) deploy.
	 *
	 * @return The namespace prefix with '__' delimiter, or an empty string when no namespace applies.
	 *
	 * @example
	 * ```apex
	 * String namespacePrefix = CTRL_ChainMonitor.getNamespacePrefix(); // 'kern__' or ''
	 * ```
	 */
	@AuraEnabled(Cacheable=true)
	public static String getNamespacePrefix()
	{
		return UTIL_System.getManagedPackageNamespacePrefix();
	}

	/**
	 * @description Aborts a running or stalled chain on the operator's behalf. The feature flag is
	 * the single gate (its strategy decides who); Apex is the enforcement point, so every refusal
	 * throws — the Chain Monitor's button state is only a hint. Returns the freshly re-read detail
	 * so the acting operator's panel repaints without a second round trip.
	 *
	 * @param executionId The AsyncChainExecution__c record to abort.
	 *
	 * @return The post-abort chain detail.
	 *
	 * @example
	 * ```apex
	 * CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.abortChain(executionId);
	 * ```
	 */
	@AuraEnabled
	public static CTRL_ChainMonitorTypes.DTO_ChainDetail abortChain(Id executionId)
	{
		AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByIdForMonitoring(executionId);

		if(execution == null)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_AbortUnavailableChainEnded);
		}

		String availability = resolveAbortAvailability(execution);

		if(availability == ABORT_CHAIN_NOT_ABORTABLE)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_AbortUnavailableChainEnded);
		}
		if(availability == OPERATOR_CAPABILITY_DISABLED)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_AbortUnavailableDisabled);
		}
		if(availability == OPERATOR_PERMISSION_MISSING)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_AbortUnavailableMissingPermission);
		}

		if(!UTIL_AsyncChain.abortExecution(executionId, OPERATOR_ABORT_REASON))
		{
			// kern-coverage-exempt: race-window guard; abortExecution can refuse after the availability check passed, unreachable in one transaction
			throw new AuraHandledException(System.Label.ChainMonitor_AbortFailed);
		}

		return getChainDetail(executionId);
	}

	/**
	 * @description Re-drives a Failed chain from its failed step on the operator's behalf. The
	 * feature-flag gate layers over the engine's state resolution and Apex is the enforcement
	 * point, so every refusal throws its labeled exception — button state in the monitor is only a
	 * hint. The engine re-resolves on its own fresh read before acting, and a refusal it detects
	 * there (a race with another actor, or another live run claiming the deduplication key) maps
	 * through the same labels. An engine failure that is neither a refusal nor a key collision is
	 * logged and surfaced as the generic retry-failed label.
	 *
	 * @param executionId The Failed AsyncChainExecution__c record to re-drive.
	 *
	 * @return The freshly re-read detail of the re-driven chain.
	 *
	 * @since 1.7
	 *
	 * @example
	 * ```apex
	 * CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.retryChainFromFailedStep(executionId);
	 * ```
	 */
	@AuraEnabled
	public static CTRL_ChainMonitorTypes.DTO_ChainDetail retryChainFromFailedStep(Id executionId)
	{
		AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByIdForMonitoring(executionId);

		if(execution == null)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_RetryUnavailableChainEnded);
		}

		throwOnRetryRefusal(resolveRetryAvailability(execution));

		UTIL_AsyncChain.OperatorActionOutcome outcome;
		try
		{
			outcome = UTIL_AsyncChain.retryChainFromFailedStep(executionId);
		}
		catch(Exception failure)
		{
			LOG_Builder.build().error(failure).at(CLASS_NAME + '.retryChainFromFailedStep').forRecord(executionId).emit();
			throw new AuraHandledException(System.Label.ChainMonitor_RetryFailed);
		}

		if(outcome.refusalCode != null)
		{
			throwOnRetryRefusal(outcome.refusalCode);
		}

		return getChainDetail(outcome.resultId);
	}

	/**
	 * @description Restarts a Failed or Aborted chain from its first step on the operator's behalf,
	 * by cloning to a fresh record — the source row is never mutated. Gate layering, enforcement
	 * posture, and refusal mapping follow retryChainFromFailedStep exactly; the engine resolves the
	 * snapshot-presence conjuncts on its own dedicated read. An engine failure that is neither a
	 * refusal nor a key collision — including a clone context that outgrows its field when the
	 * rebuild replaces the snapshot's logging-context entry — is logged and surfaced as the generic
	 * restart-failed label.
	 *
	 * @param executionId The Failed or Aborted AsyncChainExecution__c record to restart from.
	 *
	 * @return The CLONE's freshly read detail, so the monitor can re-point at the new run.
	 *
	 * @since 1.7
	 *
	 * @example
	 * ```apex
	 * CTRL_ChainMonitorTypes.DTO_ChainDetail cloneDetail = CTRL_ChainMonitor.restartChainFromStart(executionId);
	 * ```
	 */
	@AuraEnabled
	public static CTRL_ChainMonitorTypes.DTO_ChainDetail restartChainFromStart(Id executionId)
	{
		AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByIdForMonitoring(executionId);

		if(execution == null)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_RestartUnavailableChainEnded);
		}

		throwOnRestartRefusal(resolveRestartAvailability(execution));

		UTIL_AsyncChain.OperatorActionOutcome outcome;
		try
		{
			outcome = UTIL_AsyncChain.restartChainFromStart(executionId);
		}
		catch(Exception failure)
		{
			LOG_Builder.build().error(failure).at(CLASS_NAME + '.restartChainFromStart').forRecord(executionId).emit();
			throw new AuraHandledException(System.Label.ChainMonitor_RestartFailed);
		}

		if(outcome.refusalCode != null)
		{
			throwOnRestartRefusal(outcome.refusalCode);
		}

		return getChainDetail(outcome.resultId);
	}

	/**
	 * @description Runs the operator clear-stalled sweep on the operator's behalf and returns its
	 * per-bucket counts for the result toast. The suspension gate lives HERE and only here: the
	 * engine's clearStalledChains carries no suspension conjunct, because its truthful zero counts
	 * would be indistinguishable from "nothing stalled" — so this controller resolution is the
	 * suspension interlock's sole enforcement point. The capability and permission gates layer
	 * exactly as on the other re-drive actions.
	 *
	 * @return The sweep's per-bucket counts.
	 *
	 * @since 1.7
	 *
	 * @example
	 * ```apex
	 * CTRL_ChainMonitorTypes.DTO_ClearStalledResult result = CTRL_ChainMonitor.clearStalledChains();
	 * ```
	 */
	@AuraEnabled
	public static CTRL_ChainMonitorTypes.DTO_ClearStalledResult clearStalledChains()
	{
		throwOnSharedOperatorRefusal(resolveClearStalledAvailability());

		return toClearStalledResult(UTIL_AsyncChain.clearStalledChains());
	}

	/**
	 * @description Reads the operations-control state for the monitor's list header: whether chain
	 * processing is currently enabled, the availability of the kill-switch toggle and the
	 * clear-stalled sweep for the running user, and — for a user the sweep is open to — how many
	 * chains are waiting for it, which the sweep's confirmation dialog names before the operator
	 * commits. Deliberately non-cacheable — the state must repaint truthfully right after a toggle,
	 * and the monitor re-reads it immediately before opening that dialog so the number is true at
	 * the moment of the decision.
	 *
	 * @return The operations state.
	 *
	 * @since 1.7
	 *
	 * @example
	 * ```apex
	 * CTRL_ChainMonitorTypes.DTO_OperationsState state = CTRL_ChainMonitor.getChainOperationsState();
	 * ```
	 */
	@AuraEnabled
	public static CTRL_ChainMonitorTypes.DTO_OperationsState getChainOperationsState()
	{
		CTRL_ChainMonitorTypes.DTO_OperationsState state = new CTRL_ChainMonitorTypes.DTO_OperationsState();

		state.chainProcessingEnabled = UTIL_AsyncChain.isChainProcessingEnabled();
		state.killSwitchAvailability = resolveKillSwitchAvailability();
		state.clearStalledAvailability = resolveClearStalledAvailability();
		// The waiting count feeds the sweep's confirmation dialog, and it is read through a sharing
		// bypass, so it is gathered only for a caller the sweep is actually open to.
		state.stalledChainCount = state.clearStalledAvailability == OPERATOR_AVAILABLE ? new SEL_AsyncChainExecution().countStalledAwaitingSweep() : 0;

		return state;
	}

	/**
	 * @description Suspends all async chain processing org-wide on the operator's behalf. The
	 * engine's hierarchy-setting write is the ONLY DML in this transaction — the endpoint performs
	 * no other DML by design, because mixing setting DML with object DML is a real production
	 * hazard that tests cannot witness (System.runAs waives the restriction), so this shape is the
	 * isolation's only enforcement. The suspension gate deliberately does not apply to the toggle
	 * itself: resume must stay reachable while suspended.
	 *
	 * @return The fresh operations state, so the control repaints without a second round trip.
	 *
	 * @since 1.7
	 *
	 * @example
	 * ```apex
	 * CTRL_ChainMonitorTypes.DTO_OperationsState state = CTRL_ChainMonitor.suspendChainProcessing();
	 * ```
	 */
	@AuraEnabled
	public static CTRL_ChainMonitorTypes.DTO_OperationsState suspendChainProcessing()
	{
		throwOnKillSwitchRefusal(resolveKillSwitchAvailability());

		UTIL_AsyncChain.suspendChainProcessing();

		return getChainOperationsState();
	}

	/**
	 * @description Resumes async chain processing on the operator's behalf. Gate, DML isolation,
	 * and return shape follow suspendChainProcessing exactly; chains that stopped during the
	 * suspension stay stopped — retry or restart the ones that should run.
	 *
	 * @return The fresh operations state, so the control repaints without a second round trip.
	 *
	 * @since 1.7
	 *
	 * @example
	 * ```apex
	 * CTRL_ChainMonitorTypes.DTO_OperationsState state = CTRL_ChainMonitor.resumeChainProcessing();
	 * ```
	 */
	@AuraEnabled
	public static CTRL_ChainMonitorTypes.DTO_OperationsState resumeChainProcessing()
	{
		throwOnKillSwitchRefusal(resolveKillSwitchAvailability());

		UTIL_AsyncChain.resumeChainProcessing();

		return getChainOperationsState();
	}

	/**
	 * @description Seeds the detail panel's live log stream with the chain's most recent persisted
	 * entries, bridging the stream's subscribe-forward blind spot. The seed never throws: it
	 * degrades to an empty list when the caller's context cannot read LogEntry__c at all, when the
	 * chain is missing, or when no entries exist — a caller granted only the monitor's read
	 * surface sees a live-only stream, never framework log rows their permissions deny. Once the
	 * caller's own object access is established, the read spans BOTH reference legs — the chain's
	 * correlation id and its record reference — so a chain launched from a transaction with no
	 * active log correlation (whose entries carry only the record id) still seeds its history; the
	 * legs share the Log Console posture, spanning every user's framework-owned rows so the trace
	 * is complete. The chain row itself is read through a correlation-only projection: the default
	 * projection would haul two 131KB long-texts the detail read has already paid for. The mapped
	 * message is the entry's short message — the engine derives one from the full message whenever
	 * the emitter set none, so a persisted framework row always carries it and the long-text bodies
	 * stay out of the lean projection. The read returns the TRUE newest rows of any trace size
	 * (same-timestamp ties broken by Id), which this endpoint hands back oldest first.
	 *
	 * @param executionId The AsyncChainExecution__c record whose trace to seed from.
	 *
	 * @return The most recent persisted entries, oldest first, capped at LOG_STREAM_SEED_ROW_CAP.
	 *
	 * @since 1.7
	 *
	 * @example
	 * ```apex
	 * List<CTRL_ChainMonitorTypes.DTO_LogStreamEntry> entries = CTRL_ChainMonitor.getChainLogEntries(executionId);
	 * ```
	 */
	@AuraEnabled
	public static List<CTRL_ChainMonitorTypes.DTO_LogStreamEntry> getChainLogEntries(Id executionId)
	{
		List<CTRL_ChainMonitorTypes.DTO_LogStreamEntry> entries = new List<CTRL_ChainMonitorTypes.DTO_LogStreamEntry>();

		if(!UTIL_SObjectDescribe.isObjectAccessible(LogEntry__c.SObjectType))
		{
			return entries;
		}

		AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByIdForLogStreamSeed(executionId);

		if(execution == null)
		{
			return entries;
		}

		List<LogEntry__c> rows = new SEL_LogEntry().findNewestByCorrelationIdOrRecordId(execution.CorrelationId__c, executionId, LOG_STREAM_SEED_ROW_CAP);
		for(Integer index = rows.size() - 1; index >= 0; index--)
		{
			CTRL_ChainMonitorTypes.DTO_LogStreamEntry entry = new CTRL_ChainMonitorTypes.DTO_LogStreamEntry();

			entry.timestamp = rows[index].CreatedDate;
			entry.logLevel = rows[index].LogLevel__c;
			entry.message = rows[index].ShortMessage__c;

			entries.add(entry);
		}

		return entries;
	}

	/**
	 * @description Converts an AsyncChainExecution__c record to a summary DTO for the list view.
	 *
	 * @param record The AsyncChainExecution__c record.
	 *
	 * @return A populated CTRL_ChainMonitorTypes.DTO_ChainSummary.
	 */
	private static CTRL_ChainMonitorTypes.DTO_ChainSummary toChainSummary(AsyncChainExecution__c record)
	{
		CTRL_ChainMonitorTypes.DTO_ChainSummary summary = new CTRL_ChainMonitorTypes.DTO_ChainSummary();

		summary.executionId = record.Id;
		summary.chainName = record.ChainName__c;
		summary.status = record.Status__c;
		summary.completedSteps = record.CompletedSteps__c?.intValue() ?? 0;
		summary.totalSteps = record.TotalSteps__c?.intValue() ?? 0;
		summary.startedAt = record.StartedAt__c;
		summary.durationMs = resolveElapsedMilliseconds(record);
		summary.durationLabel = UTIL_Date.formatDuration(summary.durationMs);

		return summary;
	}

	/**
	 * @description Converts an AsyncChainExecution__c record to a full detail DTO with parsed steps.
	 *
	 * @param execution The AsyncChainExecution__c record.
	 *
	 * @return A populated CTRL_ChainMonitorTypes.DTO_ChainDetail.
	 */
	private static CTRL_ChainMonitorTypes.DTO_ChainDetail toChainDetail(AsyncChainExecution__c execution)
	{
		CTRL_ChainMonitorTypes.DTO_ChainDetail detail = new CTRL_ChainMonitorTypes.DTO_ChainDetail();

		detail.chainName = execution.ChainName__c;
		detail.completedAt = execution.CompletedAt__c;
		detail.completedSteps = execution.CompletedSteps__c != null ? execution.CompletedSteps__c.intValue() : 0;
		detail.correlationId = execution.CorrelationId__c;
		detail.errorMessage = execution.ErrorMessage__c;
		detail.executionId = execution.Id;
		detail.startedAt = execution.StartedAt__c;
		detail.status = execution.Status__c;
		detail.abortAvailability = resolveAbortAvailability(execution);
		detail.retryAvailability = resolveRetryAvailability(execution);
		detail.restartAvailability = resolveRestartAvailability(execution);
		detail.sourceExecutionId = execution.SourceExecution__c;
		detail.totalSteps = execution.TotalSteps__c?.intValue() ?? 0;

		detail.durationMs = resolveElapsedMilliseconds(execution);
		detail.durationLabel = UTIL_Date.formatDuration(detail.durationMs);
		detail.steps = parseSteps(execution);
		detail.activeDurationMs = sumStepDurations(detail.steps);
		detail.activeDurationLabel = UTIL_Date.formatDuration(detail.activeDurationMs);
		return detail;
	}

	/**
	 * @description How long a run has taken, for the one duration both the list row and the Timing
	 * card show. A run that finished recorded the answer when it ended, so that value wins. A run
	 * that has not finished records nothing, so its answer is the time since it started, which keeps
	 * growing until the run ends: that is the number a stuck-chain triage reads off a Running or a
	 * Stalled row. A completion timestamp means the run ended whatever its status says, so
	 * counting on from its start is never right for one: an operator-aborted row and a stalled row
	 * that recovery clobbered both carry that timestamp, and both stop here rather than reporting a
	 * total that would climb forever.
	 *
	 * @param execution The chain execution row, projecting DurationMs__c, StartedAt__c,
	 * CompletedAt__c and Status__c.
	 *
	 * @return The run's duration in milliseconds, or null when the row records none and none can
	 * honestly be derived.
	 */
	private static Long resolveElapsedMilliseconds(AsyncChainExecution__c execution)
	{
		if(execution.DurationMs__c != null)
		{
			return execution.DurationMs__c.longValue();
		}

		Boolean stillGoing = execution.StartedAt__c != null && execution.CompletedAt__c == null && UNFINISHED_STATUSES.contains(execution.Status__c);

		return stillGoing ? Datetime.now().getTime() - execution.StartedAt__c.getTime() : null;
	}

	/**
	 * @description Adds up what the steps themselves spent running. A re-driven chain keeps its
	 * original start, so its wall-clock duration counts every idle minute an operator took before
	 * pressing Retry; this total is the same run with the waiting taken out. Steps that never ran
	 * record no duration and contribute nothing, and a step that ran more than once contributes
	 * only its latest attempt — the step log keeps one entry per step, so an earlier attempt's
	 * duration is overwritten by a retry and cleared outright by an operator re-drive.
	 *
	 * @param steps The parsed step details of one execution.
	 *
	 * @return The summed step duration in milliseconds, or null when no step recorded one.
	 */
	private static Long sumStepDurations(List<CTRL_ChainMonitorTypes.DTO_StepDetail> steps)
	{
		Long total = null;

		for(CTRL_ChainMonitorTypes.DTO_StepDetail step : steps)
		{
			if(step.durationMs != null)
			{
				total = (total ?? 0) + step.durationMs;
			}
		}

		return total;
	}

	/**
	 * @description Resolves why the abort action is or is not available for this chain and the
	 * running user, as a stable code. Order matters: a non-abortable status wins (nothing else is
	 * relevant for a finished chain); an enabled gate means available; an absent-or-inactive flag,
	 * or a flag with no active strategies, is the org-wide off state; otherwise the flag is live
	 * and the user simply lacks the permission its strategy names.
	 *
	 * @param execution The freshly read execution record.
	 *
	 * @return One of the ABORT_* availability codes.
	 */
	private static String resolveAbortAvailability(AsyncChainExecution__c execution)
	{
		if(execution.Status__c != SEL_AsyncChainExecution.STATUS_RUNNING && execution.Status__c != SEL_AsyncChainExecution.STATUS_STALLED)
		{
			return ABORT_CHAIN_NOT_ABORTABLE;
		}

		return resolveCapabilityAvailability(UTIL_AsyncChain.ABORT_FEATURE_FLAG_NAME);
	}

	/**
	 * @description Resolves why the retry action is or is not available for this chain and the
	 * running user, layering the capability gate over the engine's state resolution: a state
	 * refusal wins (nothing else matters for an ineligible chain), then the capability flag decides
	 * available, org-wide off, or missing permission — the abort resolution order exactly. The
	 * engine's state half parses the row's step log and context; that cost is bounded because
	 * availability rides only the single-record detail read, never the list projection. Within one
	 * detail read the step log is consequently parsed more than once — the engine resolver and the
	 * step-timeline mapping each parse independently — an accepted cost: sharing one parse would
	 * couple the engine resolver's signature to the controller's rendering.
	 *
	 * @param execution The freshly read execution record.
	 *
	 * @return The layered availability code.
	 */
	private static String resolveRetryAvailability(AsyncChainExecution__c execution)
	{
		return layerCapabilityGate(UTIL_AsyncChain.resolveRetryAvailability(execution), UTIL_AsyncChain.REDRIVE_FEATURE_FLAG_NAME);
	}

	/**
	 * @description Resolves why the restart action is or is not available for this chain and the
	 * running user — the retry layering with the engine's restart state resolution.
	 *
	 * @param execution The freshly read execution record.
	 *
	 * @return The layered availability code.
	 */
	private static String resolveRestartAvailability(AsyncChainExecution__c execution)
	{
		return layerCapabilityGate(UTIL_AsyncChain.resolveRestartAvailability(execution), UTIL_AsyncChain.REDRIVE_FEATURE_FLAG_NAME);
	}

	/**
	 * @description Resolves why the clear-stalled sweep is or is not available for the running
	 * user. The suspension conjunct is resolved HERE because the engine deliberately carries none
	 * (its zero counts could not distinguish a suspension refusal from an empty org), making this
	 * resolution the suspension interlock's sole enforcement point; the capability gate then
	 * layers as on every re-drive action.
	 *
	 * @return The availability code.
	 */
	private static String resolveClearStalledAvailability()
	{
		if(!UTIL_AsyncChain.isChainProcessingEnabled())
		{
			return UTIL_AsyncChain.REDRIVE_PROCESSING_SUSPENDED;
		}

		return resolveCapabilityAvailability(UTIL_AsyncChain.REDRIVE_FEATURE_FLAG_NAME);
	}

	/**
	 * @description Resolves why the kill-switch toggle is or is not available for the running user.
	 * Deliberately NO suspension conjunct: the toggle must stay reachable while processing is
	 * suspended, or resume would be impossible.
	 *
	 * @return The availability code.
	 */
	private static String resolveKillSwitchAvailability()
	{
		return resolveCapabilityAvailability(UTIL_AsyncChain.KILL_SWITCH_TOGGLE_FEATURE_FLAG_NAME);
	}

	/**
	 * @description Layers the capability gate over an engine state resolution: a state refusal
	 * passes through untouched, and only an eligible state consults the flag.
	 *
	 * @param stateAvailability The engine's chain-state availability code.
	 * @param featureFlagName The capability flag gating the action.
	 *
	 * @return The layered availability code.
	 */
	private static String layerCapabilityGate(String stateAvailability, String featureFlagName)
	{
		return stateAvailability == OPERATOR_AVAILABLE ? resolveCapabilityAvailability(featureFlagName) : stateAvailability;
	}

	/**
	 * @description Resolves the capability half of an operator gate from its feature flag: an
	 * enabled gate is available; an absent-or-inactive flag, or a flag with no active strategies,
	 * is the org-wide off state; otherwise the flag is live and the running user simply lacks the
	 * permission its strategy names — the order the shipped abort flow established, and every
	 * action gate (abort included) resolves its capability half through this one member.
	 *
	 * @param featureFlagName The capability flag gating the action.
	 *
	 * @return Available, CapabilityDisabled, or PermissionMissing.
	 */
	private static String resolveCapabilityAvailability(String featureFlagName)
	{
		if(UTIL_FeatureFlag.isEnabled(featureFlagName))
		{
			return OPERATOR_AVAILABLE;
		}

		FeatureFlag__mdt flag = SEL_FeatureFlag.activeFlags.get(featureFlagName);
		return flag == null || flag.FeatureFlagStrategies__r.isEmpty() ? OPERATOR_CAPABILITY_DISABLED : OPERATOR_PERMISSION_MISSING;
	}

	/**
	 * @description Maps every non-available retry availability code to its labeled refusal; returns
	 * silently on Available. Both the pre-action resolution and the engine's own fresh-read refusal
	 * route through this one mapping, so a code has exactly one label. The chain-ended label is the
	 * mapping's tail: ChainNotRetryable and any code outside the enumerated family land there,
	 * because refresh-and-rescan is the honest advice for a state the monitor does not recognise.
	 *
	 * @param availability The availability code to map.
	 */
	private static void throwOnRetryRefusal(String availability)
	{
		if(availability == OPERATOR_AVAILABLE)
		{
			return;
		}
		throwOnSharedOperatorRefusal(availability);
		if(availability == UTIL_AsyncChain.REDRIVE_STEP_NOT_IDEMPOTENT)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_RetryUnavailableStepNotIdempotent);
		}
		if(availability == UTIL_AsyncChain.REDRIVE_FAILURE_PERMANENT)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_RetryUnavailablePermanent);
		}
		if(availability == UTIL_AsyncChain.REDRIVE_CONTEXT_UNAVAILABLE)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_RetryUnavailableContext);
		}
		throw new AuraHandledException(System.Label.ChainMonitor_RetryUnavailableChainEnded);
	}

	/**
	 * @description Maps every non-available restart availability code to its labeled refusal;
	 * returns silently on Available. Both the pre-action resolution and the engine's own fresh-read
	 * refusal route through this one mapping, so a code has exactly one label. The chain-ended
	 * label is the mapping's tail: ChainNotRestartable and any code outside the enumerated family
	 * land there, because refresh-and-rescan is the honest advice for a state the monitor does not
	 * recognise.
	 *
	 * @param availability The availability code to map.
	 */
	private static void throwOnRestartRefusal(String availability)
	{
		if(availability == OPERATOR_AVAILABLE)
		{
			return;
		}
		throwOnSharedOperatorRefusal(availability);
		if(availability == UTIL_AsyncChain.RESTART_NOT_DECLARED)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_RestartUnavailableNotDeclared);
		}
		if(availability == UTIL_AsyncChain.RESTART_CONTEXT_UNAVAILABLE)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_RestartUnavailableContext);
		}
		throw new AuraHandledException(System.Label.ChainMonitor_RestartUnavailableChainEnded);
	}

	/**
	 * @description Maps the availability codes every re-drive action shares — suspension, duplicate
	 * run, and the two capability-layer refusals — to their labeled exceptions; codes outside the
	 * shared family pass through untouched for the caller's own mapping. The clear-stalled endpoint
	 * uses this mapping directly: its resolver can only return shared-family codes.
	 *
	 * @param availability The availability code to map.
	 */
	private static void throwOnSharedOperatorRefusal(String availability)
	{
		if(availability == UTIL_AsyncChain.REDRIVE_PROCESSING_SUSPENDED)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_RedriveUnavailableSuspended);
		}
		if(availability == UTIL_AsyncChain.REDRIVE_DUPLICATE_RUN)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_RedriveUnavailableDuplicateRun);
		}
		if(availability == OPERATOR_CAPABILITY_DISABLED)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_RedriveUnavailableDisabled);
		}
		if(availability == OPERATOR_PERMISSION_MISSING)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_RedriveUnavailableMissingPermission);
		}
	}

	/**
	 * @description Maps the kill-switch toggle's refusal codes to their labeled exceptions; returns
	 * silently on Available. The toggle's resolver returns only the capability-layer codes, so this
	 * mapping is exhaustive by construction.
	 *
	 * @param availability The availability code to map.
	 */
	private static void throwOnKillSwitchRefusal(String availability)
	{
		if(availability == OPERATOR_CAPABILITY_DISABLED)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_KillSwitchUnavailableDisabled);
		}
		if(availability == OPERATOR_PERMISSION_MISSING)
		{
			throw new AuraHandledException(System.Label.ChainMonitor_KillSwitchUnavailableMissingPermission);
		}
	}

	/**
	 * @description Converts the engine's clear-stalled tally to the @AuraEnabled DTO the monitor's
	 * result toast reads. A wrap rather than a re-exposure: the engine carrier's fields are not
	 * Aura-serializable, and the controller owns the client-facing shape.
	 *
	 * @param outcome The engine's tally.
	 *
	 * @return The mapped counts DTO.
	 */
	private static CTRL_ChainMonitorTypes.DTO_ClearStalledResult toClearStalledResult(UTIL_AsyncChain.ClearStalledResult outcome)
	{
		CTRL_ChainMonitorTypes.DTO_ClearStalledResult result = new CTRL_ChainMonitorTypes.DTO_ClearStalledResult();

		result.candidates = outcome.candidates;
		result.redriven = outcome.redriven;
		result.markedFailed = outcome.markedFailed;
		result.remainingStalled = outcome.remainingStalled;

		return result;
	}

	/**
	 * @description Parses the StepLog__c JSON into a list of display-ready step DTOs using typed
	 * deserialization via UTIL_AsyncChain.DTO_StepDefinition. Determines step status based on runtime
	 * fields, chain status, and step index. The handler entries the framework persists after the
	 * step entries are excluded: the timeline shows chain steps only, so its length and indices
	 * stay aligned with TotalSteps__c / CompletedSteps__c and with the LWC's running-step logic.
	 *
	 * @param execution The AsyncChainExecution__c record containing the StepLog__c JSON.
	 *
	 * @return List of CTRL_ChainMonitorTypes.DTO_StepDetail. Empty list if StepLog is blank.
	 */
	@TestVisible
	private static List<CTRL_ChainMonitorTypes.DTO_StepDetail> parseSteps(AsyncChainExecution__c execution)
	{
		List<CTRL_ChainMonitorTypes.DTO_StepDetail> results = new List<CTRL_ChainMonitorTypes.DTO_StepDetail>();

		if(String.isBlank(execution.StepLog__c))
		{
			return results;
		}

		List<UTIL_AsyncChain.DTO_StepDefinition> definitions =
				(List<UTIL_AsyncChain.DTO_StepDefinition>)JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);

		for(UTIL_AsyncChain.DTO_StepDefinition definition : UTIL_AsyncChain.filterStepEntries(definitions))
		{
			CTRL_ChainMonitorTypes.DTO_StepDetail step = new CTRL_ChainMonitorTypes.DTO_StepDetail();

			step.className = definition.className;
			step.stepName = definition.stepName;
			step.name = String.isNotBlank(definition.stepName) ? definition.stepName : definition.className;
			step.continueOnError = definition.continueOnError == true;
			step.success = definition.success;
			step.errorMessage = definition.message;

			if(definition.durationMs != null)
			{
				step.durationMs = definition.durationMs;
				step.durationLabel = UTIL_Date.formatDuration(definition.durationMs);
			}

			if(step.success == true)
			{
				step.stepStatus = STEP_STATUS_SUCCESS;
			}
			else if(step.success == false && step.continueOnError)
			{
				step.stepStatus = STEP_STATUS_WARNING;
			}
			else if(step.success == false)
			{
				step.stepStatus = STEP_STATUS_FAILED;
			}
			else
			{
				step.stepStatus = STEP_STATUS_PENDING;
			}

			results.add(step);
		}

		return results;
	}

}