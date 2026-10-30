// SPDX-License-Identifier: Apache-2.0
/**
 * @description Controller for the Chain Monitor LWC components. It reads chain executions with filters, sorting and
 * pages, and it returns each chain's steps already parsed. The LWC components receive data ready to show, and never
 * parse the StepLog JSON themselves. It also runs the operator actions: abort, retry, restart, Clear Stalled, and
 * suspend or resume chain processing.
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
 * @date April 2026, October 2026
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.CognitiveComplexity,PMD.ExcessiveClassLength')
public with sharing class CTRL_ChainMonitor
{
	/**
	 * @description Class name that the operator actions write on their log entries, to say where each entry came from.
	 */
	private static final String CLASS_NAME = CTRL_ChainMonitor.class.getName();

	/**
	 * @description Default page size for chain list queries.
	 */
	@TestVisible
	private static final Integer DEFAULT_PAGE_SIZE = 20;

	/**
	 * @description The largest page size the server accepts from the browser. The page size comes in the request the
	 * browser sends. Without a limit, a crafted request could read the whole object in one query.
	 */
	private static final Integer MAX_PAGE_SIZE = 100;

	/**
	 * @description The separator between a chain's name and its number in the label the consoles show for a run. It is
	 * punctuation and the same in every language, so it is not a Custom Label.
	 */
	private static final String CHAIN_LABEL_SEPARATOR = ' · ';

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
	 * @description The step has no result yet. Either the step never started and the chain is Running, or the chain is
	 * Stalled.
	 */
	@TestVisible
	private static final String STEP_STATUS_PENDING = 'pending';

	/**
	 * @description The step has started, has no result yet, and the chain is Running. It is the step running now.
	 */
	@TestVisible
	private static final String STEP_STATUS_RUNNING = 'running';

	/**
	 * @description The step started, but the chain ended before the step saved a result. The chain ended as Completed,
	 * Failed or Aborted. The step may have done some of its work, or all of it.
	 */
	@TestVisible
	private static final String STEP_STATUS_NO_RESULT_RECORDED = 'noResultRecorded';

	/**
	 * @description The step never started, and the chain has ended as Completed, Failed or Aborted.
	 */
	@TestVisible
	private static final String STEP_STATUS_DID_NOT_RUN = 'didNotRun';

	/**
	 * @description Abort availability code sent in CTRL_ChainMonitorTypes.DTO_ChainDetail.abortAvailability: the chain
	 * has already finished, so there is nothing to abort. The codes that every action shares (available, capability
	 * disabled, permission missing) are the OPERATOR_* constants below.
	 */
	@TestVisible
	private static final String ABORT_CHAIN_NOT_ABORTABLE = 'ChainNotAbortable';

	/**
	 * @description Reason saved in ErrorMessage__c when an operator aborts a chain. It is an English constant on
	 * purpose, not a Custom Label: it is saved as record data and is not screen text.
	 */
	private static final String OPERATOR_ABORT_REASON = 'Aborted by operator from the Chain Monitor';

	/**
	 * @description Availability code shared by the checks on the operator actions (retry, restart, Clear Stalled, and
	 * the kill switch, which stops all chain processing): the action is available to the running user. These codes
	 * are fixed values for the code to read, never screen text. The monitor turns every code into a Custom Label.
	 *
	 * @since 1.7
	 */
	@TestVisible
	private static final String OPERATOR_AVAILABLE = 'Available';

	/**
	 * @description Availability code shared by the checks on the operator actions: the action's feature flag is
	 * missing, inactive, or has no active strategy (the rule that says who the flag is on for). The action is off for
	 * the whole org.
	 *
	 * @since 1.7
	 */
	@TestVisible
	private static final String OPERATOR_CAPABILITY_DISABLED = 'CapabilityDisabled';

	/**
	 * @description Availability code shared by the checks on the operator actions: the feature flag is on, but the
	 * running user does not have the permission that the flag's strategy names.
	 *
	 * @since 1.7
	 */
	@TestVisible
	private static final String OPERATOR_PERMISSION_MISSING = 'PermissionMissing';

	/**
	 * @description How many saved log entries the live log stream loads when it opens. They are the chain's most
	 * recent log entries, shown as history below the new entries that arrive live. The number is limited so that a
	 * chain with a very large number of log entries still sends a small answer to the screen.
	 *
	 * @since 1.7
	 */
	@TestVisible
	private static final Integer LOG_STREAM_HISTORY_ROW_CAP = 20;

	/**
	 * @description Map of sortable field names to SObjectField tokens, so the compiler checks each field. Duration sorts
	 * by ElapsedMs__c, the same value the row shows, so a run that has not finished sorts by how long it has been going.
	 * The formula stops counting at the end time (CompletedAt__c), whatever the status says. So a run an operator
	 * aborted, and a Stalled run with an end time (a finished run whose status was overwritten), never show a total
	 * that grows forever.
	 */
	private static final Map<String, SObjectField> SORTABLE_FIELDS = new Map<String, SObjectField>
	{
			'ChainName' => AsyncChainExecution__c.ChainName__c,
			'Status' => AsyncChainExecution__c.Status__c,
			'StartedAt' => AsyncChainExecution__c.StartedAt__c,
			'DurationMs' => AsyncChainExecution__c.ElapsedMs__c,
			'CreatedDate' => AsyncChainExecution__c.CreatedDate
	};

	/**
	 * @description Retrieves a paginated, filtered, and sorted list of chain executions for the
	 * Chain Monitor list view. It reads through SEL_AsyncChainExecution and uses the framework's paging.
	 * When the list is filtered by an action (the request's rootCorrelationId), the page also says what launched each
	 * run. For that, it makes at most two more reads for the whole page: one for the launching runs that are not on the
	 * page, and one for the runs that page runs were restarted from. When the list is not filtered by an action, it makes
	 * one query.
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

		SEL_AsyncChainExecution.ListCriteria criteria = new SEL_AsyncChainExecution.ListCriteria();
		criteria.statuses = request.statusFilters;
		criteria.name = request.nameFilter;
		criteria.rootCorrelationId = request.rootCorrelationId;
		criteria.sortField = resolvedSortField;
		criteria.sortDescending = request.sortAscending != true;
		criteria.page = resolvedPageNumber;
		criteria.pageSize = resolvedPageSize;
		QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered(criteria);

		List<AsyncChainExecution__c> runs = page.records;
		Map<Id, CTRL_ChainMonitorTypes.DTO_LaunchOrigin> origins = String.isNotBlank(request.rootCorrelationId)
				? resolveLaunchOrigins(runs)
				: new Map<Id, CTRL_ChainMonitorTypes.DTO_LaunchOrigin>();
		List<CTRL_ChainMonitorTypes.DTO_ChainSummary> summaries = new List<CTRL_ChainMonitorTypes.DTO_ChainSummary>();
		for(AsyncChainExecution__c record : runs)
		{
			CTRL_ChainMonitorTypes.DTO_ChainSummary summary = toChainSummary(record);
			CTRL_ChainMonitorTypes.DTO_LaunchOrigin origin = origins.get(record.Id);
			summary.launchCorrelationId = record.LaunchCorrelationId__c;
			summary.launchKind = origin?.launchKind?.name();
			summary.launchedUnderLabel = origin?.launchedUnderLabel;
			summary.launchedUnderExecutionId = origin?.launchedUnderExecutionId;
			summaries.add(summary);
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
	@AuraEnabled(cacheable=true)
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
	 * @description Finds the chain execution that carries a correlation id. So when the Log Console's Open in Chain
	 * Monitor link opens the monitor, it shows the linked chain instead of the default selection. It uses the
	 * monitoring read, which sees chains from the whole org, exactly as the console's list does.
	 *
	 * @param correlationId The correlation id carried by the Open in Chain Monitor link.
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
	 * @description Returns the managed-package namespace prefix. The monitor LWC needs it to build the name of its
	 * streaming channel and the field names in each event, for the org it is running in: 'kern__' in a managed install,
	 * an empty string in an unmanaged (no-namespace) deploy.
	 *
	 * @return The namespace prefix with '__' delimiter, or an empty string when no namespace applies.
	 *
	 * @example
	 * ```apex
	 * String namespacePrefix = CTRL_ChainMonitor.getNamespacePrefix(); // 'kern__' or ''
	 * ```
	 */
	@AuraEnabled(cacheable=true)
	public static String getNamespacePrefix()
	{
		return UTIL_System.getManagedPackageNamespacePrefix();
	}

	/**
	 * @description Aborts a running or stalled chain for the operator. The feature flag is the only check, and its
	 * strategy decides who may abort. The check that counts is made here in Apex, so every refusal throws. Whether the
	 * Chain Monitor's button is enabled is only a hint. The method returns the chain detail, read again after the
	 * abort, so the operator's panel updates without a second call to the server.
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
	 * @description Starts a Failed chain again from its failed step, for the operator. Two checks run, in order. First
	 * the engine decides whether the chain's state allows a retry. Then the feature flag decides whether the action is
	 * on and the user has the permission. The check that counts is made here in Apex, so every refusal throws an
	 * exception with its own Custom Label. Whether the monitor's button is enabled is only a hint.
	 * Before it acts, the engine reads the chain again and checks again. It may refuse there: another user acted at the
	 * same moment, or another active run holds the deduplication key. That refusal uses the same labels. Any other
	 * engine failure is logged and shown with the general retry-failed label.
	 *
	 * @param executionId The Failed AsyncChainExecution__c record to start again.
	 *
	 * @return The chain's detail, read again after the retry.
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
	 * @description Restarts a Failed or Aborted chain from its first step, for the operator. It copies the chain to a
	 * new record and never changes the original record. The order of the checks, where the check that counts is made,
	 * and how a refusal becomes a label all work exactly as in retryChainFromFailedStep. The engine checks, on its own
	 * read, that the copy of the chain's starting data is present. Any other engine failure is logged and shown with
	 * the general restart-failed label. One such failure: the new copy's context data grows too large for its field
	 * when the engine replaces the logging details stored in the starting data.
	 *
	 * @param executionId The Failed or Aborted AsyncChainExecution__c record to restart from.
	 *
	 * @return The detail of the NEW run, read fresh, so the monitor can switch to it.
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
	 * @description Runs the Clear Stalled sweep for the operator and returns its counts by outcome, for the message
	 * shown after it. The check for suspended processing is made HERE and only here. The engine's clearStalledChains
	 * does not check for it, because its counts of zero would then look the same as "nothing stalled". So this
	 * controller is the only place that stops the sweep while processing is suspended. The feature flag and
	 * permission checks then run exactly as on the other actions that start chains again.
	 *
	 * @return The sweep's counts by outcome.
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
	 * @description Reads the state of the controls in the monitor's list header. It returns:
	 * 1. whether chain processing is enabled now;
	 * 2. whether the running user may use the kill switch (the switch that stops all chain processing);
	 * 3. whether the running user may run the Clear Stalled sweep;
	 * 4. for a user who may run the sweep, how many chains are waiting for it. The sweep's confirmation dialog
	 *    shows this number before the operator confirms.
	 * The result is not cached, on purpose. The header must show the true state right after the switch is used. And
	 * the monitor reads it again just before it opens that dialog, so the number is true when the operator decides.
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
		// The sweep's confirmation dialog shows the waiting count. The count is read without sharing,
		// so it is read only for a caller who may run the sweep.
		state.stalledChainCount = state.clearStalledAvailability == OPERATOR_AVAILABLE ? new SEL_AsyncChainExecution().countStalledAwaitingSweep() : 0;

		return state;
	}

	/**
	 * @description Suspends all async chain processing in the org, for the operator. The
	 * engine writes one hierarchy custom setting, and that is the ONLY DML in this transaction. The
	 * method does no other DML on purpose. In production, a transaction that saves a setting and
	 * other records together can fail. Tests cannot show this, because System.runAs lifts the
	 * restriction. So keeping this method free of other DML is the only thing that prevents it.
	 * The suspension check does not apply to this switch itself, so that resume still works while
	 * processing is suspended.
	 *
	 * @return The header state, read fresh, so the control updates without a second call to the server.
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
	 * @description Resumes async chain processing, for the operator. The check, the rule that no other DML runs in the
	 * same transaction, and the returned value all work exactly as in suspendChainProcessing. Chains that stopped
	 * during the suspension stay stopped. Retry or restart the ones that should run.
	 *
	 * @return The header state, read fresh, so the control updates without a second call to the server.
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
	 * @description Fills the detail panel's live log stream with the chain's most recent saved log entries. The stream
	 * only receives entries logged after it opens, so without this it would miss everything logged before.
	 * This method never throws. It returns an empty list when the caller cannot read LogEntry__c at all, when the
	 * chain is missing, or when no entries exist. So a caller who may only read the monitor sees a stream of live
	 * entries only, never log rows their permissions deny.
	 * Once the caller's own object access is confirmed, the read matches entries in two ways: by the chain's
	 * correlation id and by its record id. So a chain launched from a transaction with no active log correlation
	 * (whose entries carry only the record id) still shows its history. Both ways read like the Log Console does,
	 * across every user's framework-owned rows, so the history is complete.
	 * The chain row itself is read with only its correlation fields. The default field list would load two 131KB
	 * long-text fields that the detail read has already loaded. The message shown is the entry's short message. When
	 * the code that logged the entry set no short message, the engine makes one from the full message. So a saved
	 * framework row always has a short message, and the long-text fields are never read here.
	 * The read returns the TRUE newest rows however many entries the chain has (rows with the same time are ordered
	 * by Id). This method returns them oldest first.
	 *
	 * @param executionId The AsyncChainExecution__c record whose log entries to load.
	 *
	 * @return The most recent saved entries, oldest first, capped at LOG_STREAM_HISTORY_ROW_CAP.
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

		List<LogEntry__c> rows = new SEL_LogEntry().findNewestByCorrelationIdOrRecordId(execution.CorrelationId__c, executionId, LOG_STREAM_HISTORY_ROW_CAP);
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
		summary.durationMs = record.ElapsedMs__c?.longValue();
		summary.durationLabel = UTIL_Date.formatDuration(summary.durationMs);

		return summary;
	}

	/**
	 * @description Converts an AsyncChainExecution__c record to a full detail DTO with parsed steps. It names what
	 * launched the run through resolveLaunchOrigins, which may make one read for the launching run or for the run it
	 * was restarted from.
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
		detail.launchCorrelationId = execution.LaunchCorrelationId__c;
		detail.rootCorrelationId = execution.RootCorrelationId__c;
		CTRL_ChainMonitorTypes.DTO_LaunchOrigin origin = resolveLaunchOrigins(new List<AsyncChainExecution__c> {execution}).get(execution.Id);
		detail.launchKind = origin.launchKind.name();
		detail.launchedUnderName = origin.launchedUnderLabel;
		detail.launchedUnderExecutionId = origin.launchedUnderExecutionId;
		detail.errorMessage = execution.ErrorMessage__c;
		detail.executionId = execution.Id;
		detail.startedAt = execution.StartedAt__c;
		detail.status = execution.Status__c;
		detail.abortAvailability = resolveAbortAvailability(execution);
		detail.retryAvailability = resolveRetryAvailability(execution);
		detail.restartAvailability = resolveRestartAvailability(execution);
		detail.sourceExecutionId = execution.SourceExecution__c;
		detail.totalSteps = execution.TotalSteps__c?.intValue() ?? 0;

		detail.durationMs = execution.ElapsedMs__c?.longValue();
		detail.durationLabel = UTIL_Date.formatDuration(detail.durationMs);
		detail.steps = parseSteps(execution);
		detail.activeDurationMs = sumStepDurations(detail.steps);
		detail.activeDurationLabel = UTIL_Date.formatDuration(detail.activeDurationMs);
		return detail;
	}

	/**
	 * @description Works out how each run of a page entered its action, for the whole page at once. First, each run is
	 * matched by correlation id and by id against the page's own runs. Then the launching runs and the restart sources
	 * that are not on the page are read, in one query each. It never looks further than one level up. Both consoles
	 * call this and never work out the four cases themselves: the Log Console's run labels, and the monitor's column
	 * and detail.
	 *
	 * @param runs The runs of one page, read with the short summary field list.
	 *
	 * @return How each run entered its action, keyed by run id.
	 *
	 * @example
	 * ```apex
	 * Map<Id, CTRL_ChainMonitorTypes.DTO_LaunchOrigin> origins = CTRL_ChainMonitor.resolveLaunchOrigins(page.records);
	 * ```
	 */
	public static Map<Id, CTRL_ChainMonitorTypes.DTO_LaunchOrigin> resolveLaunchOrigins(List<AsyncChainExecution__c> runs)
	{
		Map<String, AsyncChainExecution__c> runsByCorrelation = new Map<String, AsyncChainExecution__c>();
		Map<Id, AsyncChainExecution__c> runsById = new Map<Id, AsyncChainExecution__c>();
		for(AsyncChainExecution__c run : runs)
		{
			runsByCorrelation.put(run.CorrelationId__c, run);
			runsById.put(run.Id, run);
		}
		Set<String> missingLaunchIds = new Set<String>();
		Set<Id> missingSourceIds = new Set<Id>();
		for(AsyncChainExecution__c run : runs)
		{
			if(String.isNotBlank(run.LaunchCorrelationId__c) && !runsByCorrelation.containsKey(run.LaunchCorrelationId__c))
			{
				missingLaunchIds.add(run.LaunchCorrelationId__c);
			}
			else if(String.isBlank(run.LaunchCorrelationId__c) && run.SourceExecution__c != null && !runsById.containsKey(run.SourceExecution__c))
			{
				missingSourceIds.add(run.SourceExecution__c);
			}
		}
		SEL_AsyncChainExecution selector = new SEL_AsyncChainExecution();
		for(AsyncChainExecution__c launcher : selector.findByCorrelationIds(missingLaunchIds))
		{
			runsByCorrelation.put(launcher.CorrelationId__c, launcher);
		}
		for(AsyncChainExecution__c source : selector.findByIdsForSummary(missingSourceIds))
		{
			runsById.put(source.Id, source);
		}
		Map<Id, CTRL_ChainMonitorTypes.DTO_LaunchOrigin> origins = new Map<Id, CTRL_ChainMonitorTypes.DTO_LaunchOrigin>();
		for(AsyncChainExecution__c run : runs)
		{
			origins.put(run.Id, resolveLaunchOrigin(run, runsByCorrelation, runsById));
		}
		return origins;
	}

	/**
	 * @description Decides the Launched-under case for one run. The four cases are checked in this order:
	 * 1. A run holds its launch id: a step of that run launched it.
	 * 2. It has a launch id that no run holds: the action's own code launched it.
	 * 3. It has no launch id but has a source run: it is a copy made by a restart.
	 * 4. It has neither: it started the action.
	 *
	 * @param run The run.
	 * @param runsByCorrelation The runs that may hold its launch id, by correlation.
	 * @param runsById The runs that may be its source, by id.
	 *
	 * @return How the run entered its action.
	 */
	private static CTRL_ChainMonitorTypes.DTO_LaunchOrigin resolveLaunchOrigin
			(
					AsyncChainExecution__c run,
					Map<String, AsyncChainExecution__c> runsByCorrelation,
					Map<Id, AsyncChainExecution__c> runsById
			)
	{
		CTRL_ChainMonitorTypes.DTO_LaunchOrigin origin = new CTRL_ChainMonitorTypes.DTO_LaunchOrigin();
		if(String.isNotBlank(run.LaunchCorrelationId__c))
		{
			AsyncChainExecution__c launcher = runsByCorrelation.get(run.LaunchCorrelationId__c);
			origin.launchKind = launcher == null ? CTRL_ChainMonitorTypes.LaunchKind.ACTION : CTRL_ChainMonitorTypes.LaunchKind.CHAIN;
			origin.launchedUnderLabel = launcher == null ? null : chainLabel(launcher);
			origin.launchedUnderExecutionId = launcher?.Id;
			return origin;
		}
		if(run.SourceExecution__c != null)
		{
			AsyncChainExecution__c source = runsById.get(run.SourceExecution__c);
			origin.launchKind = CTRL_ChainMonitorTypes.LaunchKind.RESTART;
			origin.launchedUnderLabel = source == null ? null : chainLabel(source);
			origin.launchedUnderExecutionId = run.SourceExecution__c;
			return origin;
		}
		origin.launchKind = CTRL_ChainMonitorTypes.LaunchKind.ORIGIN;
		return origin;
	}

	/**
	 * @description The label the consoles show for a run: its chain name and its chain number.
	 *
	 * @param run A run read with the short summary field list.
	 *
	 * @return The label, for example "OrderSync · CHAIN-00214".
	 *
	 * @example
	 * ```apex
	 * String label = CTRL_ChainMonitor.chainLabel(run);
	 * ```
	 */
	public static String chainLabel(AsyncChainExecution__c run)
	{
		return run.ChainName__c + CHAIN_LABEL_SEPARATOR + run.Name;
	}

	/**
	 * @description Adds up the time the steps themselves spent running. A chain that an operator retried keeps its
	 * original start time. So its clock duration counts every idle minute before the operator pressed Retry. This total
	 * is the same run with the waiting taken out. Steps that never ran record no duration and add nothing. A step that
	 * ran more than once adds only its latest attempt. The step log keeps one entry per step: a retry inside the chain
	 * overwrites an earlier attempt's duration, and an operator's retry clears it completely.
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
	 * @description Copies the engine's manual retry value onto the step detail. The step log has this value only on a
	 * step an operator retried. A value of zero or more is how long the run had stayed failed. A negative value means
	 * the wait could not be measured, and it is never shown as a number.
	 *
	 * @param step The step detail being built.
	 * @param definition The step's entry in the step log.
	 */
	private static void applyManualRetryMarker(CTRL_ChainMonitorTypes.DTO_StepDetail step, UTIL_AsyncChain.DTO_StepDefinition definition)
	{
		step.manuallyRetried = definition.manualRetryAfterMs != null;
		if(step.manuallyRetried && definition.manualRetryAfterMs >= 0)
		{
			step.manualRetryAfterMs = definition.manualRetryAfterMs;
			step.manualRetryAfterLabel = UTIL_Date.formatDuration(definition.manualRetryAfterMs);
		}
	}

	/**
	 * @description Resolves why the abort action is or is not available for this chain and the
	 * running user, as a fixed code. The order matters:
	 * 1. A status that cannot be aborted comes first. Nothing else matters for a finished chain.
	 * 2. A feature flag that is on for the user means available.
	 * 3. A flag that is missing or inactive, or has no active strategy, means the action is off for the whole org.
	 * 4. Otherwise the flag is on, and the user does not have the permission its strategy names.
	 *
	 * @param execution The freshly read execution record.
	 *
	 * @return ChainNotAbortable when the status cannot be aborted. Otherwise Available, CapabilityDisabled or
	 * PermissionMissing, from the feature flag check.
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
	 * running user. The engine checks the chain's state first. A refusal there comes first, because nothing else
	 * matters for a chain that cannot be retried. Then the feature flag decides: available, off for the whole org, or
	 * permission missing. This is exactly the order the abort check uses.
	 * The engine's state check parses the row's step log and context. That cost stays small, because availability is
	 * worked out only for the detail read of one record, never for the list. As a result, one detail read parses the
	 * step log more than once: the engine's check and the step timeline each parse it on their own. That cost is
	 * accepted. Sharing one parse would tie the engine method's signature to how the controller builds the screen.
	 *
	 * @param execution The freshly read execution record.
	 *
	 * @return The availability code from both checks.
	 */
	private static String resolveRetryAvailability(AsyncChainExecution__c execution)
	{
		return checkFeatureFlagWhenStateAllows(UTIL_AsyncChain.resolveRetryAvailability(execution), UTIL_AsyncChain.REDRIVE_FEATURE_FLAG_NAME);
	}

	/**
	 * @description Resolves why the restart action is or is not available for this chain and the
	 * running user. It works like the retry check, with the engine's restart state check in place of the retry one.
	 *
	 * @param execution The freshly read execution record.
	 *
	 * @return The availability code from both checks.
	 */
	private static String resolveRestartAvailability(AsyncChainExecution__c execution)
	{
		return checkFeatureFlagWhenStateAllows(UTIL_AsyncChain.resolveRestartAvailability(execution), UTIL_AsyncChain.REDRIVE_FEATURE_FLAG_NAME);
	}

	/**
	 * @description Resolves why the Clear Stalled sweep is or is not available for the running user. The check for
	 * suspended processing is made HERE, because the engine does not make it, on purpose: its counts of zero could not
	 * tell a refusal because of suspension from an org with nothing stalled. So this is the only place that stops the
	 * sweep while processing is suspended. The feature flag check then runs as on every action that starts chains
	 * again.
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
	 * @description Resolves why the kill switch (the switch that stops all chain processing) is or is not available
	 * for the running user. It does NOT check for suspended processing, on purpose: the switch must stay usable while
	 * processing is suspended, or nobody could resume it.
	 *
	 * @return The availability code.
	 */
	private static String resolveKillSwitchAvailability()
	{
		return resolveCapabilityAvailability(UTIL_AsyncChain.KILL_SWITCH_TOGGLE_FEATURE_FLAG_NAME);
	}

	/**
	 * @description Adds the feature flag check after the engine's state check. A refusal from the state check is
	 * returned unchanged. Only when the state allows the action is the flag checked.
	 *
	 * @param stateAvailability The engine's availability code for the chain's state.
	 * @param featureFlagName The feature flag that turns the action on.
	 *
	 * @return The availability code from both checks.
	 */
	private static String checkFeatureFlagWhenStateAllows(String stateAvailability, String featureFlagName)
	{
		return stateAvailability == OPERATOR_AVAILABLE ? resolveCapabilityAvailability(featureFlagName) : stateAvailability;
	}

	/**
	 * @description Resolves the feature flag part of an operator action's check:
	 * 1. A flag that is on for the user means available.
	 * 2. A flag that is missing or inactive, or has no active strategy, means the action is off for the whole org.
	 * 3. Otherwise the flag is on, and the running user does not have the permission its strategy names.
	 * Every action's check, abort included, resolves its feature flag part through this one method.
	 *
	 * @param featureFlagName The feature flag that turns the action on.
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
	 * @description Turns every retry availability code other than Available into an exception with its Custom Label.
	 * For Available it returns and does nothing. Both the check made before the action and the engine's refusal after
	 * its own fresh read go through this one method, so each code has exactly one label. The chain-ended label comes
	 * last: ChainNotRetryable and any code not listed here end there. For a state the monitor does not know, the honest
	 * advice is to refresh and look again.
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
	 * @description Turns every restart availability code other than Available into an exception with its Custom Label.
	 * For Available it returns and does nothing. Both the check made before the action and the engine's refusal after
	 * its own fresh read go through this one method, so each code has exactly one label. The chain-ended label comes
	 * last: ChainNotRestartable and any code not listed here end there. For a state the monitor does not know, the
	 * honest advice is to refresh and look again.
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
	 * @description Turns the availability codes that every action that starts chains again shares into exceptions with
	 * their Custom Labels. The shared codes are: processing suspended, a duplicate run, and the two feature flag
	 * refusals. Any other code passes through unchanged, for the caller to handle. The Clear Stalled action calls this
	 * method directly, because its check can return only the shared codes.
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
	 * @description Turns the kill switch's refusal codes into exceptions with their Custom Labels. For Available it
	 * returns and does nothing. The kill switch's check returns only the feature flag codes, so this method always
	 * covers every code it can receive.
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
	 * @description Copies the engine's Clear Stalled counts into the @AuraEnabled DTO that the monitor's result message
	 * reads. It copies rather than returning the engine's object, for two reasons. The engine object's fields cannot
	 * be sent to the components. And the controller owns the shape the browser receives.
	 *
	 * @param outcome The engine's counts.
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
	 * @description Reads the chain's step log (StepLog__c) and turns each step into a row the timeline can show. Each row
	 * carries one word for the step's status, such as "success" or "running". The word comes from what the step record
	 * says and from the chain's status, never from where the step sits in the list (see toStepStatus). The error handler
	 * and completion handler entries stored after the steps are left out. So the timeline shows chain steps only, and its
	 * length matches TotalSteps__c and CompletedSteps__c.
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
		String chainStatus = execution.Status__c;

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
			applyManualRetryMarker(step, definition);
			step.stepStatus = toStepStatus(UTIL_AsyncChain.resolveStepState(definition), chainStatus);

			results.add(step);
		}

		return results;
	}

	/**
	 * @description Picks the word the timeline shows for one step. The word depends on two things: what the step record
	 * says about the step, and the status of the chain. A step with a result always shows that result. A step with no
	 * result depends on the chain. While the chain is Running, a started step shows "running" and a step that never started
	 * shows "pending". While the chain is Stalled, both show "pending". Once the chain has ended (Completed, Failed or
	 * Aborted), a started step shows "noResultRecorded" and a step that never started shows "didNotRun". A chain in any
	 * other status (Delayed, which the engine never writes) has not ended, so both show "pending".
	 *
	 * @param state What the step record says about the step.
	 * @param chainStatus The chain's Status__c value.
	 *
	 * @return One of the seven step words.
	 */
	private static String toStepStatus(UTIL_AsyncChain.StepState state, String chainStatus)
	{
		Boolean isChainRunning = chainStatus == SEL_AsyncChainExecution.STATUS_RUNNING;
		Boolean hasChainEnded = chainStatus == SEL_AsyncChainExecution.STATUS_COMPLETED
				|| chainStatus == SEL_AsyncChainExecution.STATUS_FAILED
				|| chainStatus == SEL_AsyncChainExecution.STATUS_ABORTED;

		switch on state
		{
			when SUCCEEDED
			{
				return STEP_STATUS_SUCCESS;
			}
			when FAILED_CONTINUED
			{
				return STEP_STATUS_WARNING;
			}
			when FAILED_STOPPED, RECOVERY_REFUSED
			{
				return STEP_STATUS_FAILED;
			}
			when STARTED
			{
				if(isChainRunning)
				{
					return STEP_STATUS_RUNNING;
				}
				return hasChainEnded ? STEP_STATUS_NO_RESULT_RECORDED : STEP_STATUS_PENDING;
			}
			when else
			{
				return hasChainEnded ? STEP_STATUS_DID_NOT_RUN : STEP_STATUS_PENDING;
			}
		}
	}

}