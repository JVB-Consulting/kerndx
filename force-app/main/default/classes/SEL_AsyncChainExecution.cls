// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the AsyncChainExecution__c object. Each record is one run of a chain. The class reads runs
 * for the Chain Monitor, for status checks and by correlation id (the id that ties a run to its log entries). The
 * Chain Monitor's list read takes its filters in one object. The Log Console shows a banner for one user action; that
 * banner reads the runs launched under the action. The Chain Monitor's Launched-under column reads the runs behind a
 * page of ids.
 *
 * @see SEL_Base
 * @see SEL_AsyncChainExecution_TEST
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date April 2026, October 2026
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
@SuppressWarnings('PMD.ExcessiveParameterList,PMD.AvoidBooleanMethodParameters,PMD.ExcessivePublicCount')
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
	 * @description Status indicating the chain execution stopped making progress. The watchdog (the scheduled job that
	 * looks for chains that stopped moving) marked it as stalled.
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
	 * @description Failure category indicating the framework's recovery code acted on a chain that lost its background job.
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
	 * @description The exact fields that two screens read: the Chain Monitor list and the Log Console's banner for one
	 * user action (`CTRL_ChainMonitor.toChainSummary`, `CTRL_LogConsole.getActionSummary`). The default field list also
	 * holds three long-text fields that no list row shows: ContextData__c and StepLog__c (131KB each) and
	 * ErrorMessage__c. Loading them for every row of a list page could use too much heap (the memory limit of one
	 * request). So the list reads ask for this shorter list instead.
	 * Nothing on this path reads CompletedAt__c or DurationMs__c, because the list reads ElapsedMs__c. The two fields
	 * stay in this list until it is next trimmed.
	 * What each field is for:
	 * Name is the chain number that the consoles show beside the chain name.
	 * CorrelationId__c is the id a page matches against to find the run that launched each run.
	 * LaunchCorrelationId__c, RootCorrelationId__c and SourceExecution__c decide what the Launched-under column shows.
	 * ElapsedMs__c is the duration the list shows and sorts by. It is the stored duration, or the time since the start
	 * for a run that has not finished.
	 */
	private static final List<SObjectField> SUMMARY_FIELDS = new List<SObjectField>
	{
			AsyncChainExecution__c.ChainName__c,
			AsyncChainExecution__c.CompletedAt__c,
			AsyncChainExecution__c.CompletedSteps__c,
			AsyncChainExecution__c.CorrelationId__c,
			AsyncChainExecution__c.DurationMs__c,
			AsyncChainExecution__c.ElapsedMs__c,
			AsyncChainExecution__c.LaunchCorrelationId__c,
			AsyncChainExecution__c.Name,
			AsyncChainExecution__c.RootCorrelationId__c,
			AsyncChainExecution__c.SourceExecution__c,
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
	 * @description Returns the default fields for AsyncChainExecution__c queries. The list leaves out
	 * InitialContextData__c on purpose. That field is a copy of the chain's starting data, kept for chains that allow a
	 * restart. It is a third 131KB long-text field. In the default list it would load on every step of such a chain and
	 * on every Chain Monitor detail read, which uses heap for nothing (SUMMARY_FIELDS leaves out long text for the same
	 * reason). So a read made for a restart must ask for that field by name.
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
				AsyncChainExecution__c.ElapsedMs__c,
				AsyncChainExecution__c.ErrorMessage__c,
				AsyncChainExecution__c.FailureCategory__c,
				AsyncChainExecution__c.LastManualRetryAt__c,
				AsyncChainExecution__c.LastModifiedDate,
				AsyncChainExecution__c.LaunchCorrelationId__c,
				AsyncChainExecution__c.RootCorrelationId__c,
				AsyncChainExecution__c.RunKey__c,
				AsyncChainExecution__c.SourceExecution__c,
				AsyncChainExecution__c.StartedAt__c,
				AsyncChainExecution__c.Status__c,
				AsyncChainExecution__c.StepLog__c,
				AsyncChainExecution__c.TotalSteps__c
		};
	}

	/**
	 * @description This selector reads a framework-owned object, so it always runs in `AccessLevel.SYSTEM_MODE`, whatever
	 * the `UserModeQueries_Enabled` feature flag says. The running user usually has no object access (create, read,
	 * update, delete) on framework-owned records, because the framework manages them. Reads in USER_MODE would then come
	 * back empty, and chains would stop working with no error.
	 *
	 * @return `true`: this selector needs SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Retrieves a single AsyncChainExecution__c record by ID for the Chain Monitor
	 * console. It ignores sharing rules, for these reasons. The console shows chains from the whole org. The framework
	 * permission sets decide who may open it (tab and object access). Each run record is private (the org-wide default
	 * is Private) and is owned by the user who started the chain. A read that kept sharing would hide other users'
	 * chains with no warning. The engine's own reads and the status read for subscribers (`UTIL_AsyncChain.getStatus`)
	 * do NOT use this method on purpose, so they keep the caller's sharing access.
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
	 * @description Reads one AsyncChainExecution__c record, with the default field list, for
	 * `UTIL_AsyncChain.applyRunTransition`, the engine method that moves a chain run from one status to another. Only that
	 * method calls this read. It ignores sharing rules, for two reasons. Every save that follows this read runs in system
	 * mode. And the watchdog must be able to mark as Stalled a run that its own user does not own. The method is `public`
	 * so the package's own classes can call it, and it may change without notice.
	 *
	 * @param executionId The ID of the AsyncChainExecution__c record.
	 *
	 * @return The matching AsyncChainExecution__c record, or null if not found.
	 *
	 * @example
	 * ```apex
	 * AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByIdForTransition(executionId);
	 * ```
	 */
	public AsyncChainExecution__c findByIdForTransition(Id executionId)
	{
		return (AsyncChainExecution__c)query
				.bypassSharingInternal()
				.condition(AsyncChainExecution__c.Id).equals(executionId)
				.getFirst();
	}

	/**
	 * @description Retrieves a single AsyncChainExecution__c record for the Chain Monitor's
	 * restart action. It reads the default field list and also InitialContextData__c, the copy of the chain's starting
	 * data. This is the ONLY query that reads that copy. The field is a third 131KB long-text field. In the default list
	 * it would load on every step of a chain that allows a restart and on every monitor detail read. So the copy loads
	 * once, at the moment a restart needs it. It ignores sharing for the same reason as findByIdForMonitoring: the
	 * monitor shows private runs from the whole org. CTRL_ChainMonitor decides who may restart at all, from a feature
	 * flag and a permission check.
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
	 * @description Retrieves ONLY the correlation id of a chain execution. The Chain Monitor's live log stream needs it
	 * for its first load: it reads the log entries that carry this id. The default field list would load two 131KB
	 * long-text fields into the request's heap again, right after the detail read already loaded them. It ignores
	 * sharing for the same reason as findByIdForMonitoring: the monitor shows private runs from the whole org, and the
	 * framework permission sets decide who may open it.
	 *
	 * @param executionId The ID of the AsyncChainExecution__c record.
	 *
	 * @return The matching row with CorrelationId__c only, or null if not found.
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
	 * @description Retrieves the chain runs the watchdog should look at. The watchdog is the scheduled job that looks for
	 * chains that stopped moving. A run qualifies when it is Running or Stalled and was last changed before the
	 * threshold. The oldest come first, and the list stops at the batch size.
	 *
	 * It ignores sharing rules. The watchdog is a recovery job for the whole org. Each run record is private and is
	 * owned by the user who started the chain. A read that kept sharing would skip, with no warning, every chain that
	 * the watchdog's own user does not own.
	 *
	 * A returned run is only a candidate: an old Status__c alone does not prove the chain is dead. The watchdog
	 * then checks the run's background job (its AsyncApexJob row). It leaves a live job alone, starts a dead chain
	 * again, and only marks Stalled a run whose job it cannot check. The threshold still matters: set it generously,
	 * longer than the longest normal step.
	 *
	 * A run with an end time (CompletedAt__c) is never returned. A real stall has never finished, so a Stalled run with
	 * an end time is a finished run whose status was overwritten by mistake. Starting it again would bring back a
	 * finished chain whose deduplication key was already released. This filter can only remove a candidate, never add
	 * one. The package blocks saving a Stalled run that has an end time, so this filter is a second check. It stays
	 * because rows overwritten before that block existed are still in subscriber orgs.
	 *
	 * @param thresholdMinutes Minutes since the last change before a chain becomes a candidate.
	 * @param batchSize Maximum number of candidates to return.
	 *
	 * @return The candidate AsyncChainExecution__c records, oldest first; empty when either
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
	 * @description Retrieves the runs for the Chain Monitor's Clear Stalled action, which an operator starts by hand. A
	 * run qualifies when it is Stalled and has no end time. The oldest come first, and the list stops at the batch size.
	 *
	 * It differs from findStaleRunning, the scheduled watchdog's read, in two ways, on purpose:
	 * 1. There is no age threshold. The operator asked for the sweep now. A check made on each candidate, whether
	 *    its chain is still alive, tells a dead chain from a slow one; the age of the row does not.
	 * 2. Running runs are not read. Only the scheduled watchdog decides when a Running chain is old enough to be
	 *    a stall candidate.
	 *
	 * A run with an end time (CompletedAt__c) is never returned. A Stalled run with an end time is a finished run whose
	 * status was overwritten by mistake. Starting it again would bring back a finished chain whose deduplication key was
	 * already released. It ignores sharing for the same reason as findStaleRunning: recovery covers private runs from
	 * the whole org. The package blocks saving a Stalled run that has an end time, so the end-time filter is a second
	 * check. It stays because rows overwritten before that block existed are still in subscriber orgs.
	 *
	 * The query reads the default field list WITHOUT two long-text fields: ContextData__c (131KB) and ErrorMessage__c
	 * (32KB). No step of the sweep that only decides reads them from a candidate row. Each step that acts reads the
	 * whole row again, fresh, before it reads or writes either field. A full batch of rows with the default field list
	 * would load both fields into the operator's 10MB synchronous heap (Winter '27 and later). SUMMARY_FIELDS
	 * describes the same heap risk for list pages. StepLog__c stays: the step that finds and marks a stalled run reads
	 * the notification handler from the candidate row itself.
	 *
	 * @param batchSize Maximum number of candidates to return.
	 *
	 * @return The Stalled candidate AsyncChainExecution__c records, oldest first; empty when the batch
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

		List<SObjectField> candidateFields = new List<SObjectField>(getFields());
		candidateFields.remove(candidateFields.indexOf(AsyncChainExecution__c.ContextData__c));
		candidateFields.remove(candidateFields.indexOf(AsyncChainExecution__c.ErrorMessage__c));

		return query.bypassSharingInternal()
				.onlyFields(candidateFields)
				.condition(AsyncChainExecution__c.Status__c).equals(STATUS_STALLED)
				.andCondition(AsyncChainExecution__c.CompletedAt__c).isNull()
				.orderBy(AsyncChainExecution__c.LastModifiedDate).ascending()
				.withLimit(batchSize)
				.toList();
	}

	/**
	 * @description Counts the chains waiting for the Chain Monitor's Clear Stalled action. It counts exactly the runs
	 * findStalledForOperatorSweep reads: Stalled runs with no end time. The Clear Stalled dialog shows this number
	 * before the operator confirms, so it must count the same runs the sweep will act on. Unlike the candidate read,
	 * the count has no limit, on purpose. It says how many chains are waiting, not how many one sweep looks at. So the
	 * dialog says the sweep works through them oldest first; it does not promise to clear them all. It ignores sharing
	 * for the same reason as findStalledForOperatorSweep: recovery covers private runs from the whole org. The package
	 * blocks saving a Stalled run that has an end time, so the end-time filter is a second check. It stays because rows
	 * overwritten before that block existed are still in subscriber orgs.
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
	 * @description Retrieves ONLY the statuses of the given chain executions. The Clear Stalled action uses them to count
	 * its results: it sorts each candidate it looked at by its status after the sweep, and reads nothing else. Loading
	 * the default field list's long-text fields again, beside the candidate list still in memory, would double the
	 * sweep's peak heap for nothing (SUMMARY_FIELDS gives the same reason).
	 * This read keeps sharing, on purpose. Every step of the sweep that acts reads its candidate again through the same
	 * default read, which also keeps sharing. So a run this count cannot see is always a run no step changed. That run
	 * counts as still waiting for recovery whether the read keeps sharing or not. Both choices give the same count, so
	 * the read takes the safer one and keeps sharing.
	 *
	 * @param executionIds The IDs of the chain executions to sort by status.
	 *
	 * @return The matching rows with Status__c only; empty when the id set is null or empty.
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
	 * @description Finds the run that now holds the given deduplication key (the key that stops two copies of the same
	 * chain running at once). A run holds the key only while it is active. When a run ends, the same update clears the
	 * key. So the query does not filter on status. It ignores sharing, because the duplicate check must see the active
	 * run whatever records the caller can see. Only the matching run is returned.
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
	 * @description Finds the run declared under the given deduplication key, running or finished, newest first. A step
	 * or a handler can launch another chain (a child). The framework gives that child a key made of the launching run's
	 * id and the launch position. Before it launches, it asks here. So when the step runs again (a retry, or a
	 * re-drive, which starts the same run again from that step), it gets the child it already launched, not a second
	 * one. It ignores sharing for the same reason as the active-key lookup: the step may run again as a user who cannot
	 * see the child. Only the matching run is returned.
	 *
	 * @param deduplicationKey The declared deduplication key to resolve.
	 *
	 * @return The newest run declared under the key, or null when none was.
	 *
	 * @since 1.8
	 *
	 * @example
	 * ```apex
	 * AsyncChainExecution__c child = new SEL_AsyncChainExecution().findByDeclaredDeduplicationKey(parentRunId + ':0');
	 * ```
	 */
	public AsyncChainExecution__c findByDeclaredDeduplicationKey(String deduplicationKey)
	{
		return (AsyncChainExecution__c)query.bypassSharingInternal()
				.condition(AsyncChainExecution__c.DeclaredDeduplicationKey__c).equals(deduplicationKey)
				.orderBy(AsyncChainExecution__c.CreatedDate).descending()
				.getFirst();
	}

	/**
	 * @description Retrieves the chain execution carrying a correlation id for the Chain Monitor
	 * console. It ignores sharing for the same reason as findByIdForMonitoring: the console lists and opens chains from
	 * the whole org. The Open in Chain Monitor link is shown whenever a chain exists. So following that link must find
	 * the same records the console shows. The engine's own reads and the status read for subscribers keep using
	 * findByCorrelationId, which keeps the caller's sharing access. A blank correlation id returns null without a query.
	 *
	 * @param correlationId The CorrelationId__c carried by the Open in Chain Monitor link.
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
	 * @description Retrieves one filtered, sorted page of AsyncChainExecution__c records for the Chain Monitor's list
	 * view. The filters come in one object: the statuses to keep, a chain name search, the action the runs were launched
	 * under, the sort and the page. So a new filter later is a new field on that object, never a new method signature.
	 * It reads only the fields the list shows (`SUMMARY_FIELDS`), never the long-text fields; use
	 * `findByIdForMonitoring` for full detail. It ignores sharing rules. The console shows chains from the whole org, and
	 * the framework permission sets decide who may open it. A read that kept sharing would hide other users' chains with
	 * no warning.
	 *
	 * @param criteria The list filters, sort and page.
	 *
	 * @return A QRY_Builder.QueryPage with records, totalRecords, hasMorePages, etc.
	 *
	 * @example
	 * ```apex
	 * SEL_AsyncChainExecution.ListCriteria criteria = new SEL_AsyncChainExecution.ListCriteria();
	 * criteria.statuses = new List<String> {'Running', 'Failed'};
	 * criteria.sortField = AsyncChainExecution__c.CreatedDate;
	 * criteria.sortDescending = true;
	 * criteria.page = 1;
	 * criteria.pageSize = 20;
	 * QRY_Builder.QueryPage page = new SEL_AsyncChainExecution().findFiltered(criteria);
	 * ```
	 */
	public QRY_Builder.QueryPage findFiltered(ListCriteria criteria)
	{
		QRY_Builder.Builder filteredQuery = query.bypassSharingInternal().onlyFields(SUMMARY_FIELDS);

		if(criteria.statuses?.isEmpty() == false)
		{
			filteredQuery = filteredQuery.condition(AsyncChainExecution__c.Status__c).isIn(criteria.statuses);
		}

		if(String.isNotBlank(criteria.name))
		{
			filteredQuery = filteredQuery.andCondition(AsyncChainExecution__c.ChainName__c).contains(criteria.name);
		}

		if(String.isNotBlank(criteria.rootCorrelationId))
		{
			filteredQuery = filteredQuery.andCondition(AsyncChainExecution__c.RootCorrelationId__c).equals(criteria.rootCorrelationId);
		}

		return filteredQuery.orderBy(criteria.sortField, criteria.sortDescending, criteria.sortDescending).getPage(criteria.page, criteria.pageSize);
	}

	/**
	 * @description The first page of the runs launched under one action, ordered by start time and then by chain number.
	 * The Log Console's banner for that action reads it. The page's totalRecords is an exact count from the database. So
	 * the banner's chain count and failed count are exact, for three runs or for fifty thousand. The rows on the page
	 * become the small run labels in the banner. It ignores sharing, like every read for the consoles. A blank action
	 * id gives an empty page without a query.
	 *
	 * @param rootCorrelationId The action's tracking id.
	 * @param statuses The statuses to keep; null or empty keeps every status.
	 * @param pageSize The rows on the page.
	 *
	 * @return Page one of the action's runs with the summary fields (SUMMARY_FIELDS) and an exact total.
	 *
	 * @example
	 * ```apex
	 * QRY_Builder.QueryPage failedRuns = new SEL_AsyncChainExecution().findByRootPage(rootCorrelationId, new List<String> {'Failed'}, 5);
	 * ```
	 */
	public QRY_Builder.QueryPage findByRootPage(String rootCorrelationId, List<String> statuses, Integer pageSize)
	{
		if(String.isBlank(rootCorrelationId))
		{
			QRY_Builder.QueryPage empty = new QRY_Builder.QueryPage();
			empty.pageSize = pageSize;
			return empty;
		}
		QRY_Builder.Builder scoped = query.bypassSharingInternal().onlyFields(SUMMARY_FIELDS)
				.condition(AsyncChainExecution__c.RootCorrelationId__c).equals(rootCorrelationId);
		if(statuses?.isEmpty() == false)
		{
			scoped = scoped.andCondition(AsyncChainExecution__c.Status__c).isIn(statuses);
		}
		return scoped.orderBy(AsyncChainExecution__c.StartedAt__c, false, false).orderBy(AsyncChainExecution__c.Name, false, false).getPage(1, pageSize);
	}

	/**
	 * @description Checks whether any run launched under an action is in one of the given statuses. It is one small
	 * query that stops at the first match. The Log Console's banner uses it to say "still running". It ignores sharing,
	 * like every read for the consoles. A blank action id or an empty status list answers false without a query.
	 *
	 * @param rootCorrelationId The action's tracking id.
	 * @param statuses The statuses that count.
	 *
	 * @return True when at least one such run exists.
	 *
	 * @example
	 * ```apex
	 * Boolean stillRunning = new SEL_AsyncChainExecution().existsByRootAndStatuses(rootCorrelationId, new List<String> {'Running', 'Stalled'});
	 * ```
	 */
	public Boolean existsByRootAndStatuses(String rootCorrelationId, List<String> statuses)
	{
		return String.isNotBlank(rootCorrelationId) && statuses?.isEmpty() == false
				&& query.bypassSharingInternal()
				.condition(AsyncChainExecution__c.RootCorrelationId__c).equals(rootCorrelationId)
				.andCondition(AsyncChainExecution__c.Status__c).isIn(statuses)
				.exists();
	}

	/**
	 * @description The runs holding any of the given correlation ids, with the summary fields. It is one read for a
	 * whole page of log entries, where the Chain column names the run behind each row. It is also one read for a page
	 * of runs, where the run that launched each run is the one holding its launch id. It ignores sharing, like every
	 * read for the consoles. An empty or null set reads nothing.
	 *
	 * @param correlationIds The correlation ids to look up.
	 *
	 * @return The matching runs with the summary fields; empty for no ids.
	 *
	 * @example
	 * ```apex
	 * List<AsyncChainExecution__c> runs = new SEL_AsyncChainExecution().findByCorrelationIds(correlationIds);
	 * ```
	 */
	public List<AsyncChainExecution__c> findByCorrelationIds(Set<String> correlationIds)
	{
		if(correlationIds == null || correlationIds.isEmpty())
		{
			return new List<AsyncChainExecution__c>();
		}
		return query.bypassSharingInternal().onlyFields(SUMMARY_FIELDS)
				.condition(AsyncChainExecution__c.CorrelationId__c).isIn(new List<String>(correlationIds))
				.toList();
	}

	/**
	 * @description The runs with the given ids, with the summary fields. A restart creates a new run, a copy of the old
	 * one. For a page of such copies, this is one read for the runs they were restarted from, so the Launched-under
	 * column can name each source. It ignores sharing, like every read for the consoles. An empty or null set reads
	 * nothing.
	 *
	 * @param executionIds The run ids to look up.
	 *
	 * @return The matching runs with the summary fields; empty for no ids.
	 *
	 * @example
	 * ```apex
	 * List<AsyncChainExecution__c> sources = new SEL_AsyncChainExecution().findByIdsForSummary(sourceIds);
	 * ```
	 */
	public List<AsyncChainExecution__c> findByIdsForSummary(Set<Id> executionIds)
	{
		if(executionIds == null || executionIds.isEmpty())
		{
			return new List<AsyncChainExecution__c>();
		}
		return query.bypassSharingInternal().onlyFields(SUMMARY_FIELDS)
				.condition(AsyncChainExecution__c.Id).isIn(new List<Id>(executionIds))
				.toList();
	}

	/**
	 * @description The filters of the Chain Monitor's list read, held as one object in place of a parameter per filter.
	 * So a new filter later is a new field, never a new method signature. It follows the same pattern as
	 * SEL_LogEntry.BrowseCriteria.
	 *
	 * @date September 2026
	 */
	public class ListCriteria
	{
		/**
		 * @description Status values to keep. Null or empty keeps every status.
		 */
		public List<String> statuses;

		/**
		 * @description Chain name search text, matched anywhere in the name. Blank keeps every name.
		 */
		public String name;

		/**
		 * @description The tracking id of an action. Set, it keeps the runs launched under that action. Blank keeps every run.
		 */
		public String rootCorrelationId;

		/**
		 * @description The field to order by.
		 */
		public SObjectField sortField;

		/**
		 * @description True to order descending.
		 */
		public Boolean sortDescending;

		/**
		 * @description The 1-based page number.
		 */
		public Integer page;

		/**
		 * @description The number of rows per page.
		 */
		public Integer pageSize;
	}
}