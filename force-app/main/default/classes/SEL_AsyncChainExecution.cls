// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the AsyncChainExecution__c object. Provides query methods for
 * chain execution monitoring, status tracking, and correlation lookup.
 *
 * @see SEL_Base
 * @see SEL_AsyncChainExecution_TEST
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date April 2026, August 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * List<AsyncChainExecution__c> running = new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_RUNNING);
 * AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByCorrelationId('my-correlation-id');
 * List<AsyncChainExecution__c> executions = new SEL_AsyncChainExecution().findByChainName('MyChain');
 * ```
 */
@SuppressWarnings('PMD.ExcessiveParameterList,PMD.AvoidBooleanMethodParameters')
public inherited sharing class SEL_AsyncChainExecution extends SEL_Base
{
	/**
	 * @description Status indicating the chain execution is currently running.
	 */
	public static final String STATUS_RUNNING = 'Running';

	/**
	 * @description Status indicating the chain execution completed successfully.
	 */
	public static final String STATUS_COMPLETED = 'Completed';

	/**
	 * @description Status indicating the chain execution failed.
	 */
	public static final String STATUS_FAILED = 'Failed';

	/**
	 * @description Status indicating the chain execution was aborted.
	 */
	public static final String STATUS_ABORTED = 'Aborted';

	/**
	 * @description Status indicating the chain execution stopped progressing and was flagged as stalled by the watchdog.
	 */
	public static final String STATUS_STALLED = 'Stalled';

	/**
	 * @description Failure category indicating a step failed or crashed during execution.
	 */
	public static final String FAILURE_CATEGORY_STEP_EXCEPTION = 'StepException';

	/**
	 * @description Failure category indicating the AsyncChain feature flag stopped the chain.
	 */
	public static final String FAILURE_CATEGORY_KILL_SWITCH = 'KillSwitch';

	/**
	 * @description Failure category indicating the recovery machinery acted on a chain that lost its background job.
	 */
	public static final String FAILURE_CATEGORY_STALLED = 'Stalled';

	/**
	 * @description Failure category indicating a retrying step exhausted its retry budget without succeeding.
	 */
	public static final String FAILURE_CATEGORY_RETRIES_EXHAUSTED = 'RetriesExhausted';

	/**
	 * @description Failure category recorded when an operator aborts the chain from the Chain Monitor.
	 */
	public static final String FAILURE_CATEGORY_OPERATOR_ABORT = 'OperatorAbort';

	/**
	 * @description The exact fields the Chain Monitor list view reads (`CTRL_ChainMonitor.toChainSummary`).
	 * The default projection also carries three long-text payload fields (ContextData__c, StepLog__c —
	 * 131KB each — and ErrorMessage__c) that list rows never display; hauling them per row is a heap
	 * risk at list page sizes, so `findFiltered` projects this summary list instead. CompletedAt__c is
	 * a timestamp, not a payload: the list row needs it to tell a run still going from one that has
	 * ended, which is what decides whether its duration cell counts on from the start.
	 */
	private static final List<SObjectField> SUMMARY_FIELDS = new List<SObjectField>
	{
			AsyncChainExecution__c.ChainName__c,
			AsyncChainExecution__c.CompletedAt__c,
			AsyncChainExecution__c.CompletedSteps__c,
			AsyncChainExecution__c.DurationMs__c,
			AsyncChainExecution__c.StartedAt__c,
			AsyncChainExecution__c.Status__c,
			AsyncChainExecution__c.TotalSteps__c
	};

	/**
	 * @description Constructs a new SEL_AsyncChainExecution selector instance.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_AsyncChainExecution selector = new SEL_AsyncChainExecution();
	 * ```
	 */
	public SEL_AsyncChainExecution()
	{
		super(AsyncChainExecution__c.SObjectType);
	}

	/**
	 * @description Returns the default fields for AsyncChainExecution__c queries. Deliberately
	 * excludes InitialContextData__c: a third 131KB long-text would otherwise ride every executor
	 * hop and Chain Monitor detail read for restart-declared chains (the SUMMARY_FIELDS heap-guard
	 * precedent), so a restart-time read must project the snapshot explicitly.
	 *
	 * @return List of SObjectField tokens to include in queries.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObjectField> fields = new SEL_AsyncChainExecution().getFields();
	 * ```
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				AsyncChainExecution__c.ActiveDeduplicationKey__c,
				AsyncChainExecution__c.AllowRestart__c,
				AsyncChainExecution__c.ChainName__c,
				AsyncChainExecution__c.CompletedAt__c,
				AsyncChainExecution__c.CompletedSteps__c,
				AsyncChainExecution__c.ContextData__c,
				AsyncChainExecution__c.CorrelationId__c,
				AsyncChainExecution__c.CurrentJobId__c,
				AsyncChainExecution__c.CurrentStepName__c,
				AsyncChainExecution__c.DeclaredDeduplicationKey__c,
				AsyncChainExecution__c.DurationMs__c,
				AsyncChainExecution__c.ErrorMessage__c,
				AsyncChainExecution__c.FailureCategory__c,
				AsyncChainExecution__c.LastModifiedDate,
				AsyncChainExecution__c.RunKey__c,
				AsyncChainExecution__c.SourceExecution__c,
				AsyncChainExecution__c.StartedAt__c,
				AsyncChainExecution__c.Status__c,
				AsyncChainExecution__c.StepLog__c,
				AsyncChainExecution__c.TotalSteps__c
		};
	}

	/**
	 * @description Framework-owned sObject selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically have no
	 * CRUD on framework-owned records (the framework owns their lifecycle), so USER_MODE reads
	 * would return empty and chain orchestration would silently break.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Retrieves a single AsyncChainExecution__c record by ID for the Chain Monitor
	 * console. Bypasses sharing rules: the console is an org-wide observability surface gated by
	 * the framework permission sets (tab + object access), and the rows are Private-OWD records
	 * owned by whichever user enqueued each chain — a `with sharing` controller would otherwise
	 * silently hide other users' chains. Orchestration and subscriber-facing status reads
	 * (`UTIL_AsyncChain.getStatus`) deliberately do NOT use this method, so they keep respecting
	 * the caller's sharing access.
	 *
	 * @param executionId The ID of the AsyncChainExecution__c record.
	 *
	 * @return The matching AsyncChainExecution__c record, or null if not found.
	 *
	 * @example
	 * ```apex
	 * AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByIdForMonitoring(executionId);
	 * ```
	 */
	public AsyncChainExecution__c findByIdForMonitoring(Id executionId)
	{
		return (AsyncChainExecution__c)query
				.bypassSharingInternal()
				.condition(AsyncChainExecution__c.Id).equals(executionId)
				.getFirst();
	}

	/**
	 * @description Retrieves a single AsyncChainExecution__c record for the Chain Monitor's
	 * restart action, projecting the InitialContextData__c snapshot on top of the default field
	 * list. This is the ONLY query that ever pulls the snapshot: a third 131KB long-text on the
	 * default projection would ride every executor hop and monitor detail read for
	 * restart-declared chains, so the snapshot loads exactly once, at the moment a restart
	 * actually needs it. Bypasses sharing for the same reason as findByIdForMonitoring — the
	 * monitor is an org-wide observability surface over Private-OWD rows, and who may restart at
	 * all is decided by the feature-flag and permission gates in CTRL_ChainMonitor.
	 *
	 * @param executionId The ID of the AsyncChainExecution__c record.
	 *
	 * @return The matching AsyncChainExecution__c record with the snapshot projected, or null if not found.
	 *
	 * @since 1.7
	 *
	 * @example
	 * ```apex
	 * AsyncChainExecution__c source = new SEL_AsyncChainExecution().findByIdForRestart(executionId);
	 * ```
	 */
	public AsyncChainExecution__c findByIdForRestart(Id executionId)
	{
		return (AsyncChainExecution__c)query
				.bypassSharingInternal()
				.addField(AsyncChainExecution__c.InitialContextData__c)
				.condition(AsyncChainExecution__c.Id).equals(executionId)
				.getFirst();
	}

	/**
	 * @description Retrieves ONLY the correlation id of a chain execution, for the Chain Monitor's
	 * live-stream seed: the seed needs one field to key its correlated-trace read, and the default
	 * projection would haul two 131KB long-text payloads into the request's heap right after the
	 * detail read already paid for them. Bypasses sharing for the same reason as
	 * findByIdForMonitoring — the monitor is an org-wide observability surface over Private-OWD
	 * rows, gated by the framework permission sets.
	 *
	 * @param executionId The ID of the AsyncChainExecution__c record.
	 *
	 * @return The matching row projecting CorrelationId__c only, or null if not found.
	 *
	 * @since 1.7
	 *
	 * @example
	 * ```apex
	 * AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByIdForLogStreamSeed(executionId);
	 * ```
	 */
	public AsyncChainExecution__c findByIdForLogStreamSeed(Id executionId)
	{
		return (AsyncChainExecution__c)query
				.bypassSharingInternal()
				.onlyFields(new List<SObjectField> {AsyncChainExecution__c.CorrelationId__c})
				.condition(AsyncChainExecution__c.Id).equals(executionId)
				.getFirst();
	}

	/**
	 * @description Retrieves AsyncChainExecution__c records with a specific status.
	 *
	 * @param status The status value to filter on.
	 *
	 * @return List of AsyncChainExecution__c records matching the given status.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<AsyncChainExecution__c> running = new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_RUNNING);
	 * ```
	 */
	public List<AsyncChainExecution__c> findByStatus(String status)
	{
		return query.condition(AsyncChainExecution__c.Status__c).equals(status).toList();
	}

	/**
	 * @description Retrieves stale-candidate chain executions for the watchdog sweep: Running or
	 * Stalled chains whose last modification is older than the threshold, oldest first, capped at
	 * the batch size. Bypasses sharing rules: the watchdog is an org-wide framework recovery job,
	 * and the chains are Private-OWD records owned by whichever user enqueued each chain — a
	 * sharing-respecting read would silently skip recovery for every chain its automated user does
	 * not own. Rows are candidates only: a stale Status__c alone is not proof of a dead chain. The
	 * current sweep marks every candidate this method returns, so advise a generous threshold; a
	 * liveness check joins the decision in a later stage of the watchdog.
	 *
	 * Rows carrying a completion timestamp are excluded outright: a Stalled row with a non-null
	 * CompletedAt__c is a clobbered terminal row (a legitimate stall has never completed), and
	 * re-driving it would resurrect a finished chain with its deduplication key already released.
	 * The filter can only ever exclude a candidate, never re-include one.
	 *
	 * @param thresholdMinutes Minutes since the last modification before a chain becomes a candidate.
	 * @param batchSize Maximum number of candidates to return.
	 *
	 * @return Stale-candidate AsyncChainExecution__c records, oldest first; empty when either
	 * argument is null or the batch size is not positive.
	 *
	 * @example
	 * ```apex
	 * List<AsyncChainExecution__c> staleExecutions = new SEL_AsyncChainExecution().findStaleRunning(30, 50);
	 * ```
	 */
	public List<AsyncChainExecution__c> findStaleRunning(Integer thresholdMinutes, Integer batchSize)
	{
		if(thresholdMinutes == null || batchSize == null || batchSize <= 0)
		{
			return new List<AsyncChainExecution__c>();
		}

		Datetime cutoff = Datetime.now().addMinutes(-thresholdMinutes);

		return query.bypassSharingInternal()
				.condition(AsyncChainExecution__c.Status__c).isIn(new List<String> {STATUS_RUNNING, STATUS_STALLED})
				.andCondition(AsyncChainExecution__c.LastModifiedDate).lessThan(cutoff)
				.andCondition(AsyncChainExecution__c.CompletedAt__c).isNull()
				.orderBy(AsyncChainExecution__c.LastModifiedDate).ascending()
				.withLimit(batchSize)
				.toList();
	}

	/**
	 * @description Retrieves the candidates for the Chain Monitor's operator clear-stalled sweep:
	 * Stalled chains with no completion timestamp, oldest first, capped at the batch size. Two
	 * deliberate differences from findStaleRunning, the scheduled sweep's finder: no staleness
	 * threshold (the operator asked for a sweep NOW, and the shared per-candidate liveness probe —
	 * not row age — is what separates a dead chain from a slow one), and no Running rows (only the
	 * scheduled watchdog decides when a Running chain has aged into a stall candidate). Rows
	 * carrying a completion timestamp are excluded outright — a Stalled row with a non-null
	 * CompletedAt__c is a clobbered terminal row, and re-driving it would resurrect a finished
	 * chain whose deduplication key was already released. Bypasses sharing for the same reason as
	 * findStaleRunning: recovery is an org-wide framework concern over Private-OWD rows.
	 *
	 * The projection is the default field list MINUS the two long-text payloads no sweep decision
	 * leg reads off a candidate row — ContextData__c (131KB) and ErrorMessage__c (32KB); the
	 * acting legs take their own fresh full re-reads before consulting or writing either. A full
	 * batch of default-projection rows would haul both into the operator's 6MB synchronous heap —
	 * the same heap risk SUMMARY_FIELDS documents for list page sizes. StepLog__c stays: the
	 * detect-mark leg resolves the notification handler from the candidate row itself.
	 *
	 * @param batchSize Maximum number of candidates to return.
	 *
	 * @return Stalled-candidate AsyncChainExecution__c records, oldest first; empty when the batch
	 * size is null or not positive.
	 *
	 * @since 1.7
	 *
	 * @example
	 * ```apex
	 * List<AsyncChainExecution__c> stalledChains = new SEL_AsyncChainExecution().findStalledForOperatorSweep(40);
	 * ```
	 */
	public List<AsyncChainExecution__c> findStalledForOperatorSweep(Integer batchSize)
	{
		if(batchSize == null || batchSize <= 0)
		{
			return new List<AsyncChainExecution__c>();
		}

		List<SObjectField> candidateProjection = new List<SObjectField>(getFields());
		candidateProjection.remove(candidateProjection.indexOf(AsyncChainExecution__c.ContextData__c));
		candidateProjection.remove(candidateProjection.indexOf(AsyncChainExecution__c.ErrorMessage__c));

		return query.bypassSharingInternal()
				.onlyFields(candidateProjection)
				.condition(AsyncChainExecution__c.Status__c).equals(STATUS_STALLED)
				.andCondition(AsyncChainExecution__c.CompletedAt__c).isNull()
				.orderBy(AsyncChainExecution__c.LastModifiedDate).ascending()
				.withLimit(batchSize)
				.toList();
	}

	/**
	 * @description Counts the chains waiting for the Chain Monitor's operator clear-stalled sweep,
	 * over exactly the population findStalledForOperatorSweep takes: Stalled rows with no
	 * completion timestamp. The clear-stalled dialog names this number before the operator commits,
	 * so it has to describe the same rows the sweep will act on. Deliberately unbounded, unlike the
	 * candidate read: the count answers how many chains are waiting, not how many one invocation
	 * inspects, so the dialog's wording says the sweep works through them oldest first rather than
	 * promising it clears them all. Bypasses sharing for the same reason as
	 * findStalledForOperatorSweep: recovery is an org-wide framework concern over Private-OWD rows.
	 *
	 * @return How many stalled chain executions are waiting for the sweep; zero when none are.
	 *
	 * @example
	 * ```apex
	 * Integer waiting = new SEL_AsyncChainExecution().countStalledAwaitingSweep();
	 * ```
	 */
	public Integer countStalledAwaitingSweep()
	{
		return query.bypassSharingInternal()
				.condition(AsyncChainExecution__c.Status__c).equals(STATUS_STALLED)
				.andCondition(AsyncChainExecution__c.CompletedAt__c).isNull()
				.count();
	}

	/**
	 * @description Retrieves ONLY the statuses of the given chain executions, for the operator
	 * sweep's outcome tally: the tally classifies each inspected candidate by its post-sweep
	 * status and reads nothing else, so hauling the default projection's long-text payloads a
	 * second time — beside the still-referenced candidate list — would double the sweep's heap
	 * peak for no reader (the SUMMARY_FIELDS rationale). Deliberately respects sharing: every
	 * acting sweep leg re-reads its candidate through the same sharing-respecting default read,
	 * so a row this tally cannot see is by construction a row no leg touched — it counts as
	 * still awaiting recovery under either read posture, and the smaller bypass surface wins.
	 *
	 * @param executionIds The IDs of the chain executions to classify.
	 *
	 * @return The matching rows projecting Status__c only; empty when the id set is null or empty.
	 *
	 * @since 1.7
	 *
	 * @example
	 * ```apex
	 * List<AsyncChainExecution__c> statuses = new SEL_AsyncChainExecution().findByIdsForSweepTally(executionIds);
	 * ```
	 */
	public List<AsyncChainExecution__c> findByIdsForSweepTally(Set<Id> executionIds)
	{
		if(executionIds == null || executionIds.isEmpty())
		{
			return new List<AsyncChainExecution__c>();
		}

		return query.onlyFields(new List<SObjectField> {AsyncChainExecution__c.Status__c})
				.condition(AsyncChainExecution__c.Id).isIn(new List<Id>(executionIds))
				.toList();
	}

	/**
	 * @description Retrieves a single AsyncChainExecution__c record by its correlation ID.
	 *
	 * @param correlationId The correlation ID to search for.
	 *
	 * @return The matching AsyncChainExecution__c record, or null if not found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByCorrelationId('550e8400-e29b-41d4-a716-446655440000');
	 * ```
	 */
	public AsyncChainExecution__c findByCorrelationId(String correlationId)
	{
		return (AsyncChainExecution__c)query
				.condition(AsyncChainExecution__c.CorrelationId__c).equals(correlationId).getFirst();
	}

	/**
	 * @description Finds the run currently holding the given active-run deduplication key. Key
	 * presence is the activeness signal — terminal transitions clear the key in the same update, so
	 * no status predicate belongs here. Bypasses sharing because the deduplication guard must see the active run
	 * regardless of the caller's record visibility; only the matched run is returned.
	 *
	 * @param deduplicationKey The subscriber-supplied deduplication key to resolve.
	 *
	 * @return The run holding the key, or null when the key is free.
	 *
	 * @since 1.6
	 *
	 * @example
	 * ```apex
	 * AsyncChainExecution__c activeRun = new SEL_AsyncChainExecution().findByActiveDeduplicationKey('nightly-sync');
	 * ```
	 */
	public AsyncChainExecution__c findByActiveDeduplicationKey(String deduplicationKey)
	{
		return (AsyncChainExecution__c)query.bypassSharingInternal()
				.condition(AsyncChainExecution__c.ActiveDeduplicationKey__c).equals(deduplicationKey)
				.getFirst();
	}

	/**
	 * @description Returns whether any registered async chain execution shares the given correlation id.
	 * Sharing is bypassed so the check is consistent with how the console reads its log rows and how the
	 * Chain Monitor lists chains org-wide: the console offers Open in Chain Monitor whenever there is a chain
	 * to open, not only when the viewer happens to share the chain record. A blank correlation returns false
	 * without querying.
	 *
	 * @param correlationId The CorrelationId__c to probe for a registered chain.
	 *
	 * @return True when a chain execution carries the correlation id; false for a blank id or no match.
	 *
	 * @example
	 * ```apex
	 * Boolean hasChain = new SEL_AsyncChainExecution().existsByCorrelationId('8f2c-ord-4471');
	 * ```
	 */
	public Boolean existsByCorrelationId(String correlationId)
	{
		return String.isNotBlank(correlationId)
				&& query.bypassSharingInternal()
				.condition(AsyncChainExecution__c.CorrelationId__c).equals(correlationId)
				.getFirst() != null;
	}

	/**
	 * @description Retrieves the chain execution carrying a correlation id for the Chain Monitor
	 * console. Sharing is bypassed for the same reason as findByIdForMonitoring and
	 * existsByCorrelationId: the console lists and opens chains org-wide, and the Open in Chain
	 * Monitor deep link is offered whenever a chain exists, so resolving that link must see the
	 * same records the console itself shows. Orchestration and subscriber-facing status reads keep
	 * using findByCorrelationId, which respects the caller's sharing access. A blank correlation
	 * returns null without querying.
	 *
	 * @param correlationId The CorrelationId__c carried by the deep link.
	 *
	 * @return The matching AsyncChainExecution__c record, or null for a blank id or no match.
	 *
	 * @example
	 * ```apex
	 * AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByCorrelationIdForMonitoring('8f2c-ord-4471');
	 * ```
	 */
	public AsyncChainExecution__c findByCorrelationIdForMonitoring(String correlationId)
	{
		if(String.isBlank(correlationId))
		{
			return null;
		}

		return (AsyncChainExecution__c)query
				.bypassSharingInternal()
				.condition(AsyncChainExecution__c.CorrelationId__c).equals(correlationId)
				.getFirst();
	}

	/**
	 * @description Retrieves AsyncChainExecution__c records by chain name, ordered by creation date descending.
	 *
	 * @param chainName The chain name to filter on.
	 *
	 * @return List of AsyncChainExecution__c records for the given chain name, newest first.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<AsyncChainExecution__c> executions = new SEL_AsyncChainExecution().findByChainName('MyChain');
	 * ```
	 */
	public List<AsyncChainExecution__c> findByChainName(String chainName)
	{
		return query.condition(AsyncChainExecution__c.ChainName__c).equals(chainName)
				.orderBy(AsyncChainExecution__c.CreatedDate).descending().toList();
	}

	/**
	 * @description Retrieves a paginated, filtered, and sorted page of AsyncChainExecution__c records.
	 * Used by the Chain Monitor controller for list view queries. Projects only the summary fields
	 * the list view reads (`SUMMARY_FIELDS`) — never the long-text payload fields; use
	 * `findByIdForMonitoring` for full detail. Bypasses sharing rules: the
	 * console is an org-wide observability surface gated by the framework permission sets, and a
	 * `with sharing` controller would otherwise silently hide other users' Private-OWD chains.
	 *
	 * @param statusFilters List of status values to filter on. Null or empty returns all statuses.
	 * @param nameFilter Chain name search string (LIKE filter). Null or blank returns all names.
	 * @param sortField The SObjectField to sort by.
	 * @param sortDescending True for descending sort, false for ascending.
	 * @param page The 1-based page number.
	 * @param pageSize The number of records per page.
	 *
	 * @return A QRY_Builder.QueryPage with records, totalRecords, hasMorePages, etc.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered(
	 *     new List<String>{'Running', 'Failed'}, null,
	 *     AsyncChainExecution__c.CreatedDate, true, 1, 20
	 * );
	 * ```
	 */
	public QRY_Builder.QueryPage findFiltered
			(
					List<String> statusFilters,
					String nameFilter,
					SObjectField sortField,
					Boolean sortDescending,
					Integer page,
					Integer pageSize
			)
	{
		QRY_Builder.Builder filteredQuery = query.bypassSharingInternal().onlyFields(SUMMARY_FIELDS);

		if(statusFilters?.isEmpty() == false)
		{
			filteredQuery = filteredQuery.condition(AsyncChainExecution__c.Status__c).isIn(statusFilters);
		}

		if(String.isNotBlank(nameFilter))
		{
			filteredQuery = filteredQuery.andCondition(AsyncChainExecution__c.ChainName__c).contains(nameFilter);
		}

		return filteredQuery.orderBy(sortField, sortDescending, sortDescending).getPage(page, pageSize);
	}
}