// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Lightweight async chain runner for sequencing jobs with shared state, error handling,
 * and progress tracking. Delegates to existing async and logging infrastructure.
 *
 * @see UTIL_AsyncChain_TEST
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date April 2026, July 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * UTIL_AsyncChain.newChain('DataMigration')
 *     .then(new LoadDataStep())
 *     .then(new TransformDataStep())
 *     .onError(new NotifyAdminStep())
 *     .execute();
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.ExcessiveParameterList,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength,PMD.NcssTypeCount')
global inherited sharing class UTIL_AsyncChain
{
	/**
	 * @description Default maximum number of steps permitted in a single chain.
	 */
	private static final Integer DEFAULT_MAX_STEPS = 50;

	/**
	 * @description Default maximum serialized context size in characters.
	 */
	private static final Integer DEFAULT_MAX_CONTEXT_SIZE = 32768;

	/**
	 * @description Maximum length of a step failure message persisted in the StepLog__c copy of the
	 * step list. The full message is preserved in the step-failure log entry, with an abbreviated
	 * copy in ErrorMessage__c; this bounded duplicate exists so one oversized message can never
	 * overflow the serialized step list and corrupt its JSON.
	 */
	private static final Integer STEP_MESSAGE_MAX_LENGTH = 255;

	/**
	 * @description Per-step character reserve the execute() guard withholds from the StepLog__c
	 * capacity. As steps execute, each entry gains runtime fields that were null-suppressed at build
	 * time — `,"success":false` (16 characters) plus `,"durationMs":` and up to a 19-digit value
	 * (33 characters) plus `,"attempt":99` (13 characters) — and the safety valve cannot drop those.
	 * Reserving them up front (with deliberate margin for future runtime-gained keys) makes the
	 * valve's message-dropped rewrite provably fit the field for the whole life of the chain.
	 * The reserve counts chain steps only: the handler entries persisted after the steps never gain
	 * runtime fields (the handler executor does not write the step log), though their static size
	 * does count against the capacity the guard measures.
	 */
	private static final Integer STEP_RUNTIME_RESERVE_LENGTH = 80;

	/**
	 * @description Maximum length of an active-run deduplication key, matching the ActiveDeduplicationKey__c field
	 * capacity so withDeduplicationKey rejects at build time any key the stamp write could not persist intact.
	 */
	private static final Integer DEDUPLICATION_KEY_MAX_LENGTH = 255;

	/**
	 * @description This class's fully-qualified name, resolved once — the prefix for every
	 * log emission's classMethod value.
	 */
	private static final String CLASS_NAME = UTIL_AsyncChain.class.getName();

	/**
	 * @description Platform ceiling for a Queueable enqueue delay, in minutes. System.enqueueJob only
	 * accepts a delay of 0 to 10 minutes, so withDelayMinutes clamps to this range.
	 */
	private static final Integer MAX_QUEUEABLE_DELAY_MINUTES = 10;

	/**
	 * @description Floor for a Queueable enqueue delay, in minutes.
	 */
	private static final Integer MIN_QUEUEABLE_DELAY_MINUTES = 0;

	/**
	 * @description Queueable stack-depth headroom a retry re-enqueue adds on top of the persisted
	 * definition count: depth for the retry links the chain's root sizing never priced in. A cap on
	 * how deep the run may grow, not a reservation — a chain that retries enough to exhaust
	 * queueable stack depth degrades to Stalled and is recovered by the watchdog from a fresh root.
	 */
	private static final Integer RETRY_STACK_DEPTH_ALLOWANCE = 20;

	/**
	 * @description Reserved context key for persisting the previous step result across async transactions.
	 */
	private static final String PREVIOUS_RESULT_KEY = '__previousStepResult';

	/**
	 * @description Reserved context key for persisting the LOG_Builder context (correlation, parent transaction, context data).
	 */
	private static final String LOG_CONTEXT_KEY = '__logContext';

	/**
	 * @description Feature flag name used for the global async chain kill switch.
	 */
	@TestVisible
	private static final String FEATURE_FLAG_NAME = 'AsyncChain';

	/**
	 * @description Developer name of the feature flag gating the operator abort capability. The
	 * flag's strategy names the custom permission; the controller and the health check both read
	 * this constant, so the gate has exactly one spelling.
	 */
	public static final String ABORT_FEATURE_FLAG_NAME = 'AsyncChainAbort_Enabled';

	/**
	 * @description Developer name of the custom permission the abort flag's strategy checks. The
	 * health check and the abort test suite resolve grants of this permission by this constant, so
	 * the gate has exactly one spelling.
	 */
	public static final String ABORT_CUSTOM_PERMISSION_NAME = 'AbortAsyncChain';

	/**
	 * @description API name of the permission set that is the designed source of the abort custom
	 * permission. Package installs also write the permission into profiles; this permission set is
	 * the assignment route the framework recommends and the health check verifies.
	 */
	public static final String ABORT_PERMISSION_SET_NAME = 'AsyncChainAbort';

	/**
	 * @description Statuses an operator abort may act on. Delayed is reserved and never written.
	 */
	private static final Set<String> ABORTABLE_STATUSES = new Set<String>
	{
			SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_STALLED
	};

	/**
	 * @description Stall reason the watchdog sweep records on each stale candidate it marks.
	 */
	private static final String WATCHDOG_STALL_REASON = 'No live executor detected by watchdog sweep';

	/**
	 * @description Stall reason the sweep's async-budget gate records when it parks a candidate
	 * because the transaction has no queueable budget left to process it safely.
	 */
	private static final String WATCHDOG_PARKED_REASON = 'Parked: no async budget';

	/**
	 * @description Stall reason the sweep's query-budget gate records when it parks the remaining
	 * candidates because the transaction is nearly out of database queries.
	 */
	private static final String WATCHDOG_PARKED_QUERY_BUDGET_REASON = 'Parked: no query budget';

	/**
	 * @description Terminal failure reason recorded when a re-drive candidate's persisted step log
	 * cannot be rehydrated into a runnable chain. Terminal on purpose: an unreadable step log never
	 * repairs itself, so the chain needs human attention, not another sweep.
	 */
	private static final String REDRIVE_UNRECOVERABLE_REASON =
			'Watchdog re-drive abandoned: the persisted step log is missing, unreadable, or inconsistent with recorded progress. Review the chain and start a replacement.';

	/**
	 * @description Ceiling on the number of chains one watchdog sweep may process. Each stale row
	 * costs the sweep up to two queries and one update (plus a notification or executor enqueue),
	 * so an unbounded batch would exhaust a per-transaction governor budget mid-sweep — an
	 * uncatchable LimitException that rolls back the entire sweep and repeats on every fire,
	 * exactly during the mass-stall incidents the watchdog exists for. runWatchdogSweep clamps the
	 * configured batch size to this value; the clamp bounds the batch, and the per-candidate
	 * budget gates — the async-budget gate in sweepCandidate and the query-budget gate in the
	 * sweep loop — park the tail the moment either budget actually runs short, which together
	 * keeps the worst-case sweep inside its transaction budget. Chains beyond the ceiling stay in
	 * place for the next sweep.
	 */
	private static final Integer WATCHDOG_SWEEP_BATCH_CEILING = 50;

	/**
	 * @description Synchronous query budget the sweep proves before each candidate's decision legs
	 * run. A candidate costs at most two queries — the executor liveness probe and the acting
	 * leg's single fresh re-read — and one more is held back as margin so a gate that fires on a
	 * later candidate can still afford that candidate's park write (a park's own fresh re-read
	 * costs one query). When the remaining budget drops below this reserve, the sweep parks its
	 * remaining tail (see parkRemainingCandidates) instead of running a decision leg into an
	 * uncatchable LimitException.
	 */
	private static final Integer WATCHDOG_CANDIDATE_QUERY_RESERVE = 3;

	/**
	 * @description The platform's pre-execution/executing AsyncApexJob statuses — the set that
	 * proves a stamped executor job is still alive. Completed, Aborted and Failed are dead.
	 */
	private static final Set<String> LIVE_JOB_STATUSES = new Set<String> {'Queued', 'Processing', 'Preparing', 'Holding'};

	/**
	 * @description Flag to simulate an unhandled Queueable crash for testing the Finalizer recovery path.
	 */
	@TestVisible
	private static Boolean simulateCrash = false;

	/**
	 * @description Flag to simulate a Finalizer enqueue failure for testing the graceful degradation path.
	 */
	@TestVisible
	private static Boolean simulateEnqueueFailure = false;

	/**
	 * @description Flag to simulate a HandlerExecutor crash for testing the handler Finalizer recovery path.
	 */
	@TestVisible
	private static Boolean simulateHandlerCrash = false;

	/**
	 * @description Context key prefix for persisting ApiStep configuration across async transactions.
	 */
	@TestVisible
	private static final String API_STEP_CONFIG_KEY_PREFIX = '__apiStep_';

	/**
	 * @description Context key prefix for storing ApiStep results for downstream steps.
	 */
	@TestVisible
	private static final String API_STEP_RESULT_KEY_PREFIX = '__apiResult_';

	/**
	 * @description Creates a new chain builder for composing a sequence of async steps.
	 *
	 * @param chainName A descriptive name for the chain, used in logs and status tracking.
	 *
	 * @return A new ChainBuilder instance for fluent configuration.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_AsyncChain.ChainBuilder builder = UTIL_AsyncChain.newChain('DataMigration');
	 * ```
	 */
	global static ChainBuilder newChain(String chainName)
	{
		return new ChainBuilder(chainName);
	}

	/**
	 * @description Retrieves the current status of a chain execution as a map of key-value pairs.
	 *
	 * @param chainExecutionId The ID of the AsyncChainExecution__c record to query.
	 *
	 * @return A map containing executionId, chainName, status, totalSteps, completedSteps, and errorMessage. Returns null if the record is not found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, Object> status = UTIL_AsyncChain.getStatus(executionId);
	 * String currentStatus = (String)status.get('status');
	 * ```
	 */
	global static Map<String, Object> getStatus(Id chainExecutionId)
	{
		AsyncChainExecution__c execution = (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(chainExecutionId);

		if(execution == null)
		{
			return null;
		}

		return new Map<String, Object>
		{
				'executionId' => execution.Id,
				'chainName' => execution.ChainName__c,
				'status' => execution.Status__c,
				'totalSteps' => execution.TotalSteps__c,
				'completedSteps' => execution.CompletedSteps__c,
				'errorMessage' => execution.ErrorMessage__c
		};
	}

	/**
	 * @description Retrieves the current status of a chain execution as a typed ChainStatus value
	 * object — the structured alternative to the untyped getStatus(Id) map. ChainStatus exposes every
	 * tracked field (chain name, status, current step, correlation ID, step counts, error message,
	 * timing) plus the convenience predicates isRunning(), isTerminal() and isFailed().
	 *
	 * Reads through the same sharing-respecting selector path as getStatus(Id): a caller only sees
	 * chains they have access to. For an org-wide observability view of every chain, use the Chain
	 * Monitor console instead. For per-step detail, parse the Chain Monitor's step DTOs — ChainStatus
	 * is a single-record summary and intentionally carries no step list.
	 *
	 * @param chainExecutionId The ID of the AsyncChainExecution__c record to query.
	 *
	 * @return A ChainStatus describing the execution, or null if the record is not found or not visible.
	 *
	 * @since 1.2
	 *
	 * @example
	 * ```apex
	 * UTIL_AsyncChain.ChainStatus status = UTIL_AsyncChain.getChainStatus(executionId);
	 * if(status != null && status.isFailed())
	 * {
	 *     String reason = status.errorMessage;
	 * }
	 * ```
	 */
	global static ChainStatus getChainStatus(Id chainExecutionId)
	{
		AsyncChainExecution__c execution = (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(chainExecutionId);
		return execution == null ? null : toChainStatus(execution);
	}

	/**
	 * @description Bulk variant of getChainStatus — resolves a set of execution IDs to ChainStatus
	 * objects in a single query, so it is safe to call from within a loop budget. IDs that do not
	 * resolve to a visible record are simply absent from the returned map. Uses the same
	 * sharing-respecting selector path as getChainStatus, so a caller only sees chains they can access.
	 *
	 * @param chainExecutionIds The IDs of the AsyncChainExecution__c records to query.
	 *
	 * @return A map of execution ID to ChainStatus for every record found; empty when nothing resolves.
	 *
	 * @since 1.2
	 *
	 * @example
	 * ```apex
	 * Map<Id, UTIL_AsyncChain.ChainStatus> statuses = UTIL_AsyncChain.getChainStatuses(executionIds);
	 * ```
	 */
	global static Map<Id, ChainStatus> getChainStatuses(Set<Id> chainExecutionIds)
	{
		Map<Id, ChainStatus> results = new Map<Id, ChainStatus>();

		for(SObject record : new SEL_AsyncChainExecution().findById(chainExecutionIds))
		{
			AsyncChainExecution__c execution = (AsyncChainExecution__c)record;
			results.put(execution.Id, toChainStatus(execution));
		}

		return results;
	}

	/**
	 * @description Maps an AsyncChainExecution__c row onto a typed ChainStatus. Replicates the Chain
	 * Monitor's live-duration rule (CTRL_ChainMonitor.toChainDetail) so the typed accessor and the
	 * console report the same elapsed time: when DurationMs__c is not yet persisted but the chain is
	 * still Running, the elapsed time is computed live from StartedAt__c.
	 *
	 * @param execution The execution record to map.
	 *
	 * @return A populated ChainStatus.
	 */
	private static ChainStatus toChainStatus(AsyncChainExecution__c execution)
	{
		ChainStatus status = new ChainStatus();

		status.executionId = execution.Id;
		status.chainName = execution.ChainName__c;
		status.status = execution.Status__c;
		status.currentStepName = execution.CurrentStepName__c;
		status.correlationId = execution.CorrelationId__c;
		status.totalSteps = execution.TotalSteps__c != null ? execution.TotalSteps__c.intValue() : 0;
		status.completedSteps = execution.CompletedSteps__c != null ? execution.CompletedSteps__c.intValue() : 0;
		status.errorMessage = execution.ErrorMessage__c;
		status.startedAt = execution.StartedAt__c;
		status.completedAt = execution.CompletedAt__c;

		if(execution.DurationMs__c != null)
		{
			status.durationMs = execution.DurationMs__c.longValue();
		}
		else if(execution.StartedAt__c != null && execution.Status__c == SEL_AsyncChainExecution.STATUS_RUNNING)
		{
			status.durationMs = Datetime.now().getTime() - execution.StartedAt__c.getTime();
		}

		status.durationLabel = UTIL_Date.formatDuration(status.durationMs);

		return status;
	}

	/**
	 * @description Typed, read-only snapshot of a chain execution returned by getChainStatus. A
	 * structured alternative to the getStatus(Id) map: each tracked field is a named property and the
	 * lifecycle is queryable through isRunning(), isTerminal() and isFailed(). Holds no step list and
	 * performs no queries — it is a plain value object built from a single AsyncChainExecution__c row.
	 *
	 * @since 1.2
	 *
	 * @example
	 * ```apex
	 * UTIL_AsyncChain.ChainStatus status = UTIL_AsyncChain.getChainStatus(executionId);
	 * Boolean stillRunning = status.isRunning();
	 * Integer done = status.completedSteps;
	 * ```
	 */
	global inherited sharing class ChainStatus
	{
		/**
		 * @description The AsyncChainExecution__c record ID.
		 *
		 * @since 1.2
		 */
		global Id executionId;

		/**
		 * @description The descriptive chain name supplied to newChain(...).
		 *
		 * @since 1.2
		 */
		global String chainName;

		/**
		 * @description The lifecycle status: one of Running, Completed, Failed, Stalled or Aborted.
		 * The framework writes Stalled when a temporary platform limit stops it from scheduling the
		 * chain's next piece of work: the chain waits for recovery instead of failing. The
		 * SCHED_ChainWatchdog scheduled job also writes Stalled when its sweep finds a chain
		 * silently stuck with no recent activity.
		 * (The picklist also defines Delayed, which the framework does not currently write.)
		 * Prefer the isRunning()/isTerminal()/isFailed() predicates over comparing this String.
		 * A Stalled value beside a populated completedAt means a recovery overwrite landed on a
		 * finished chain; isTerminal() reports that row terminal.
		 *
		 * @since 1.2
		 */
		global String status;

		/**
		 * @description The name of the step currently executing (or last executed), if recorded.
		 *
		 * @since 1.2
		 */
		global String currentStepName;

		/**
		 * @description The correlation ID that ties this chain's log entries together.
		 *
		 * @since 1.2
		 */
		global String correlationId;

		/**
		 * @description The total number of steps in the chain.
		 *
		 * @since 1.2
		 */
		global Integer totalSteps;

		/**
		 * @description The number of steps completed so far.
		 *
		 * @since 1.2
		 */
		global Integer completedSteps;

		/**
		 * @description The failure message, when the chain has failed; otherwise null.
		 *
		 * @since 1.2
		 */
		global String errorMessage;

		/**
		 * @description When the chain started executing.
		 *
		 * @since 1.2
		 */
		global Datetime startedAt;

		/**
		 * @description When the chain reached a terminal state; null while still in flight.
		 *
		 * @since 1.2
		 */
		global Datetime completedAt;

		/**
		 * @description Elapsed run time in milliseconds. For a still-Running chain with no persisted
		 * duration, this is computed live from startedAt, matching the Chain Monitor console.
		 *
		 * @since 1.2
		 */
		global Long durationMs;

		/**
		 * @description A compact, human-readable form of durationMs (for example "1m 30s"); null when
		 * no duration is available.
		 *
		 * @since 1.2
		 */
		global String durationLabel;

		/**
		 * @description Whether the chain is currently running. A Stalled chain reports as neither
		 * running nor terminal: it is waiting for recovery after a temporary platform limit stopped
		 * the framework from scheduling its next piece of work, or after the SCHED_ChainWatchdog
		 * scheduled job found it silently stuck. The reserved Delayed status, which the framework
		 * does not currently write, is reported the same way.
		 *
		 * @return true when the status is Running.
		 *
		 * @since 1.2
		 *
		 * @example
		 * ```apex
		 * if(status.isRunning()) { return; }
		 * ```
		 */
		global Boolean isRunning()
		{
			return status == SEL_AsyncChainExecution.STATUS_RUNNING;
		}

		/**
		 * @description Whether the chain has reached a terminal state from which it will not advance —
		 * Completed, Failed or Aborted, or any row carrying a completion timestamp. The timestamp
		 * conjunct covers a rare recovery overwrite that can leave a finished chain reading Stalled:
		 * the completion timestamp survives that overwrite, so it is the reliable end-of-life signal.
		 *
		 * @return true when the status is Completed, Failed or Aborted, or completedAt is set.
		 *
		 * @since 1.2
		 *
		 * @example
		 * ```apex
		 * if(status.isTerminal()) { notifyDone(status); }
		 * ```
		 */
		global Boolean isTerminal()
		{
			return status == SEL_AsyncChainExecution.STATUS_COMPLETED
					|| status == SEL_AsyncChainExecution.STATUS_FAILED
					|| status == SEL_AsyncChainExecution.STATUS_ABORTED
					|| completedAt != null;
		}

		/**
		 * @description Whether the chain failed.
		 *
		 * @return true when the status is Failed.
		 *
		 * @since 1.2
		 *
		 * @example
		 * ```apex
		 * if(status.isFailed()) { escalate(status.errorMessage); }
		 * ```
		 */
		global Boolean isFailed()
		{
			return status == SEL_AsyncChainExecution.STATUS_FAILED;
		}
	}

	/**
	 * @description Builds a DTO_StepDefinition from an IF_Chain.Step instance.
	 * Extracts stepName and continueOnError from ChainStep if applicable, otherwise uses defaults.
	 *
	 * @param step The step to build the definition from.
	 *
	 * @return A populated DTO_StepDefinition.
	 */
	private static DTO_StepDefinition buildDefinition(IF_Chain.Step step)
	{
		String className = UTIL_System.getRuntimeTypeName(step);
		DTO_StepDefinition definition = new DTO_StepDefinition();
		definition.className = className;

		if(step instanceof ChainStep)
		{
			ChainStep chainStep = (ChainStep)step;
			if(String.isNotBlank(chainStep.stepName) && chainStep.stepName != className)
			{
				definition.stepName = chainStep.stepName;
			}
			if(chainStep.continueOnError)
			{
				definition.continueOnError = true;
			}
		}

		return definition;
	}

	/**
	 * @description Serializes the persisted definition list for persistence in StepLog__c. Ordering
	 * contract: the list arrives as the chain's step entries in execution order followed by its
	 * handler entries (isErrorHandler / isCompletionHandler), exactly as ChainBuilder.execute()
	 * first persisted it, and this method preserves that order — step indices in the persisted
	 * document therefore always equal runtime step indices, and consumers may filter the handler
	 * entries out without shifting any index. When the serialized copy would exceed the field
	 * capacity even with bounded messages, the per-entry message values are dropped and the list
	 * re-serialized — the JSON document itself is never truncated, because a truncated document
	 * fails to deserialize at the next step and would override the caller's continueOnError intent.
	 * The canonical failure records live in ErrorMessage__c and the step-failure log entries.
	 *
	 * @param persistedDefinitions The full persisted definition list: steps first, handlers last.
	 *
	 * @return Valid definition-list JSON that fits within the StepLog__c field capacity — guaranteed
	 * in combination with the per-step runtime reserve the execute() guard withholds at build time.
	 */
	private static String serializeStepLog(List<DTO_StepDefinition> persistedDefinitions)
	{
		String serialized = JSON.serialize(persistedDefinitions, true);
		Integer fieldCapacity = UTIL_SObjectDescribe.getCachedFieldDescribe(AsyncChainExecution__c.StepLog__c).getLength();
		if(serialized.length() > fieldCapacity)
		{
			for(DTO_StepDefinition stepDefinition : persistedDefinitions)
			{
				stepDefinition.message = null;
			}
			serialized = JSON.serialize(persistedDefinitions, true);
		}
		return serialized;
	}

	/**
	 * @description Filters a deserialized StepLog__c definition list down to its chain steps,
	 * dropping the handler entries the serialisation contract appends after them. Handler entries
	 * are notification shape, not chain work: they must never run as a step, never count toward
	 * step totals, and never shift step indices — which the append-after-steps ordering guarantees,
	 * so the returned list preserves step order and step indices. Entries are returned by
	 * reference, so runtime mutations (success, durationMs, message) flow back into the full list
	 * a caller re-serialises. Public for internal framework access (CTRL_ChainMonitor's step
	 * timeline) but not global — subscribers never touch the persisted document.
	 *
	 * @param persistedDefinitions The full deserialized StepLog__c list: steps first, handlers last.
	 *
	 * @return The chain-step entries only, in execution order.
	 */
	public static List<DTO_StepDefinition> filterStepEntries(List<DTO_StepDefinition> persistedDefinitions)
	{
		List<DTO_StepDefinition> stepEntries = new List<DTO_StepDefinition>();
		for(DTO_StepDefinition definition : persistedDefinitions)
		{
			if(definition.isErrorHandler != true && definition.isCompletionHandler != true)
			{
				stepEntries.add(definition);
			}
		}
		return stepEntries;
	}

	/**
	 * @description Instantiates a ChainStep from its class name using the framework type resolver.
	 *
	 * @param stepDefinition The step definition containing the class name to instantiate.
	 *
	 * @return A new ChainStep instance.
	 *
	 * @throws UTIL_Exceptions.ConfigurationException If the class cannot be found or instantiated.
	 */
	private static IF_Chain.Step instantiateStep(DTO_StepDefinition stepDefinition)
	{
		try
		{
			Type stepType = UTIL_System.getTypeForClassName(stepDefinition.className, IF_Chain.Step.class);
			return (IF_Chain.Step)stepType.newInstance();
		}
		catch(Exception error)
		{
			throw new UTIL_Exceptions.ConfigurationException
					(
							'Failed (Class Not Found: ' + stepDefinition.className + ') — ensure the class exists and has a public no-arg constructor.'
					);
		}
	}

	/**
	 * @description Abstract base class for individual steps in an async chain.
	 * Each step runs in its own Queueable transaction, providing governor limit isolation.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * public class LoadDataStep extends UTIL_AsyncChain.ChainStep
	 * {
	 *     public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
	 *     {
	 *         List<Account> accounts = new SEL_Account().toList();
	 *         context.put('accountCount', accounts.size());
	 *         return UTIL_AsyncChain.succeeded('Loaded ' + accounts.size() + ' accounts');
	 *     }
	 * }
	 * ```
	 */
	global inherited sharing abstract class ChainStep implements IF_Chain.Step
	{
		/**
		 * @description Whether to continue the chain if this step fails. Default: false.
		 * Subscribers should use the builder overload then(step, true) instead.
		 */
		@TestVisible
		private Boolean continueOnError = false;

		/**
		 * @description Optional step name for identification in logs and status.
		 *
		 * @since 1.0
		 */
		global String stepName;

		/**
		 * @description Execute the step's business logic.
		 * Each step runs in its own Queueable transaction, so callouts and DML are both permitted.
		 * However, standard Apex ordering rules still apply WITHIN a step: perform all callouts
		 * before any DML. A step that does DML then a callout will throw CalloutException.
		 *
		 * **Do not call `UTIL_AsyncChain.newChain(...).execute()` from inside this method.** Async
		 * chains do not support nested execution. The inner chain consumes Queueable stack-depth
		 * budget against the outer chain (capped by `AsyncOptions.maximumQueueableStackDepth`,
		 * default 50), and ChainContext writes happen on the OUTER chain's `AsyncChainExecution__c`
		 * row only — the inner chain has its own row, totally disconnected. Either add the inner
		 * steps to the parent chain via `.then(...)` or enqueue a separate Queueable from outside
		 * the chain (e.g. from `onComplete`'s handler step) that targets a fresh chain.
		 *
		 * @param context Shared chain context for reading/writing state between steps.
		 *
		 * @return StepResult indicating success or failure.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		 * {
		 *     String previousValue = (String)context.get('inputKey');
		 *     context.put('outputKey', 'processed');
		 *     return UTIL_AsyncChain.succeeded('Done');
		 * }
		 * ```
		 */
		global abstract StepResult work(ChainContext context);

		/**
		 * @description Optional per-step retry strategy. Return null (the default) for no retry — a
		 * failure is final on the first attempt, exactly as before this member existed. Retry TRANSIENT
		 * failures only (locks, timeouts, 5xx-shaped results): compose
		 * UTIL_Retry.retryOnlyOnException(...) / dontRetryOnException(...) so deterministic failures are
		 * never re-burned; a validation error retried N times across a storm of trigger-spawned chains
		 * costs async budget with zero chance of success. Steps that retry MUST be idempotent — pair with
		 * ChainContext.idempotencyKey(). Exception filters apply only when the step failed by THROWING;
		 * a failed StepResult carries no exception, so only the attempt budget gates it.
		 *
		 * A chain retrying enough to exhaust queueable stack depth degrades to Stalled and is
		 * recovered by the watchdog from a fresh root. Backoff has whole-minute granularity — the
		 * platform's delayed enqueue is minute-based, so any computed backoff over 0 seconds rounds UP
		 * to the next full minute (a 2-second backoff waits ~1 minute; only withBaseBackoff(0)
		 * re-enqueues immediately); do not expect sub-minute retry precision.
		 *
		 * The backoff delay applies only to the retried attempt's enqueue: it fires exactly once, on
		 * the retry itself, and the steps after a recovered retry run without any added delay. A chain
		 * that has retried also carries increased queueable stack-depth headroom for the remainder of
		 * its run — each retry link genuinely deepens the chain, so the extra depth stays available to
		 * the hops that follow.
		 *
		 * @return The retry strategy for this step, or null (the default) for no retry.
		 *
		 * @since 1.6
		 */
		global virtual UTIL_Retry.Strategy createRetryStrategy()
		{
			return null;
		}
	}

	/**
	 * @description Immutable result object returned by each ChainStep to indicate success or failure.
	 * Use the static factory methods to create instances.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_AsyncChain.StepResult result = UTIL_AsyncChain.succeeded('All records processed');
	 * UTIL_AsyncChain.StepResult failure = UTIL_AsyncChain.failed('Missing required field');
	 * ```
	 */
	global inherited sharing class StepResult
	{
		/**
		 * @description Whether the step completed successfully.
		 *
		 * @since 1.0
		 */
		global Boolean success {get; private set;}

		/**
		 * @description Optional human-readable message describing the outcome.
		 *
		 * @since 1.0
		 */
		global String message {get; private set;}

		/**
		 * @description Optional payload data returned by the step.
		 *
		 * @since 1.0
		 */
		global Object data {get; private set;}

		/**
		 * @description The exception that caused the step to fail, if applicable.
		 *
		 * @since 1.0
		 */
		global Exception error {get; private set;}

		/**
		 * @description Package-private constructor. Use outer class factory methods: succeeded() / failed().
		 */
		@TestVisible
		private StepResult()
		{
		}
	}

	/**
	 * @description Creates a successful step result with no message.
	 *
	 * @return A StepResult with success set to true.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * return UTIL_AsyncChain.succeeded();
	 * ```
	 */
	global static StepResult succeeded()
	{
		StepResult result = new StepResult();
		result.success = true;
		return result;
	}

	/**
	 * @description Creates a successful step result with a descriptive message.
	 *
	 * @param message A human-readable description of the successful outcome.
	 *
	 * @return A StepResult with success set to true and the provided message.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * return UTIL_AsyncChain.succeeded('Processed 42 records');
	 * ```
	 */
	global static StepResult succeeded(String message)
	{
		StepResult result = succeeded();
		result.message = message;
		return result;
	}

	/**
	 * @description Creates a successful step result with a message and data payload.
	 * The data is serialized into the chain context between transactions, so keep it small —
	 * use record IDs or primitive values, not full SObject graphs or large collections.
	 *
	 * @param message A human-readable description of the successful outcome.
	 * @param data Arbitrary data to pass to subsequent steps via the context. Prefer IDs and primitives.
	 *
	 * @return A StepResult with success set to true, the provided message, and data.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Id> processedIds = new List<Id>{ record.Id };
	 * return UTIL_AsyncChain.succeeded('Processed records', processedIds);
	 * ```
	 */
	global static StepResult succeeded(String message, Object data)
	{
		StepResult result = succeeded(message);
		result.data = data;
		return result;
	}

	/**
	 * @description Creates a failed step result with a descriptive message.
	 *
	 * @param message A human-readable description of the failure.
	 *
	 * @return A StepResult with success set to false and the provided message.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * return UTIL_AsyncChain.failed('Required field is blank');
	 * ```
	 */
	global static StepResult failed(String message)
	{
		StepResult result = new StepResult();
		result.success = false;
		result.message = message;
		return result;
	}

	/**
	 * @description Creates a failed step result from an exception, using the exception message.
	 *
	 * @param error The exception that caused the failure.
	 *
	 * @return A StepResult with success set to false, the exception message, and the exception reference.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * try { riskyOperation(); }
	 * catch(Exception error) { return UTIL_AsyncChain.failed(error); }
	 * ```
	 */
	global static StepResult failed(Exception error)
	{
		StepResult result = failed(error.getMessage());
		result.error = error;
		return result;
	}

	/**
	 * @description Shared state container passed between chain steps. Provides key-value storage
	 * for inter-step communication and access to chain metadata such as execution ID and correlation ID.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * context.put('accountId', account.Id);
	 * Id accountId = (Id)context.get('accountId');
	 * Boolean hasKey = context.has('accountId');
	 * ```
	 */
	global inherited sharing class ChainContext
	{
		/**
		 * @description Internal key-value data store for inter-step communication.
		 */
		private Map<String, Object> data;

		/**
		 * @description The ID of the AsyncChainExecution__c record tracking this chain.
		 */
		private final String chainExecutionId;

		/**
		 * @description The correlation ID for log correlation across transactions.
		 */
		private final String correlationId;

		/**
		 * @description The zero-based index of the currently executing step.
		 */
		@TestVisible
		private Integer currentStepIndex;

		/**
		 * @description The 1-based attempt number of the currently executing step. Stamped by the
		 * executor before each work(); a transient per-step stamp, excluded from serialize().
		 */
		@TestVisible
		private Integer currentAttempt;

		/**
		 * @description Whether no further retry remains for the currently executing step. Stamped by
		 * the executor before each work(); a transient per-step stamp, excluded from serialize().
		 */
		@TestVisible
		private Boolean finalAttempt;

		/**
		 * @description The result of the most recently completed step.
		 */
		private StepResult previousStepResult;

		/**
		 * @description Constructor for framework use only. Creates a new context with the given execution and correlation IDs.
		 *
		 * @param chainExecutionId The ID of the AsyncChainExecution__c record.
		 * @param correlationId The correlation ID for log correlation.
		 */
		@TestVisible
		private ChainContext(String chainExecutionId, String correlationId)
		{
			this.data = new Map<String, Object>();
			this.chainExecutionId = chainExecutionId;
			this.correlationId = correlationId;
		}

		/**
		 * @description Retrieves a value from the context by key.
		 *
		 * @param key The key to look up.
		 *
		 * @return The stored value, or null if not found.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Object value = context.get('recordCount');
		 * ```
		 */
		global Object get(String key)
		{
			return data.get(key);
		}

		/**
		 * @description Retrieves a value from the context and deserializes it to the specified type.
		 * Useful for retrieving complex objects that were stored via put() and serialized between transactions.
		 *
		 * @param key The key to look up.
		 * @param targetType The Apex Type to deserialize the value into.
		 *
		 * @return The deserialized value, or null if the key is not found.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<String> names = (List<String>)context.getAs('nameList', List<String>.class);
		 * ```
		 */
		global Object getAs(String key, Type targetType)
		{
			Object value = data.get(key);

			if(value == null)
			{
				return null;
			}

			if(targetType != null && Type.forName(UTIL_System.getRuntimeTypeName(value)) == targetType)
			{
				return value;
			}

			return JSON.deserialize(JSON.serialize(value), targetType);
		}

		/**
		 * @description Stores a value in the context under the given key.
		 *
		 * @param key The key to store the value under.
		 * @param value The value to store.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * context.put('batchSize', 200);
		 * ```
		 */
		global void put(String key, Object value)
		{
			data.put(key, value);
		}

		/**
		 * @description Checks whether the context contains a value for the given key.
		 *
		 * @param key The key to check.
		 *
		 * @return True if the key exists in the context, false otherwise.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * if(context.has('accountId'))
		 * {
		 *     Id accountId = (Id)context.get('accountId');
		 * }
		 * ```
		 */
		global Boolean has(String key)
		{
			return data.containsKey(key);
		}

		/**
		 * @description Returns the ID of the AsyncChainExecution__c record tracking this chain.
		 *
		 * @return The chain execution record ID.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String executionId = context.getChainExecutionId();
		 * ```
		 */
		global String getChainExecutionId()
		{
			return chainExecutionId;
		}

		/**
		 * @description Returns the correlation ID for this chain, used for log correlation across transactions.
		 *
		 * @return The correlation ID string.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String correlationId = context.getCorrelationId();
		 * ```
		 */
		global String getCorrelationId()
		{
			return correlationId;
		}

		/**
		 * @description Returns the result of the most recently completed step. Returns null for the first step.
		 *
		 * @return The previous step's StepResult, or null if this is the first step.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.StepResult previous = context.getPreviousStepResult();
		 * if(previous != null && previous.success)
		 * {
		 *     String message = previous.message;
		 * }
		 * ```
		 */
		global StepResult getPreviousStepResult()
		{
			return previousStepResult;
		}

		/**
		 * @description Returns the zero-based index of the currently executing step.
		 * To build a replay-safe key for this step, call context.idempotencyKey() rather than composing
		 * the execution id and step index by hand.
		 *
		 * @return The current step index, or null for contexts not yet assigned to a step.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String key = context.idempotencyKey();
		 * String rowKey = context.idempotencyKey(recordId);
		 * ```
		 */
		global Integer getCurrentStepIndex()
		{
			return currentStepIndex;
		}

		/**
		 * @description The 1-based attempt number of the currently executing step. 1 on the first
		 * attempt and for every step without a retry strategy; increments per retry.
		 *
		 * @return The 1-based attempt number of the currently executing step.
		 *
		 * @since 1.6
		 */
		global Integer getAttempt()
		{
			return currentAttempt ?? 1;
		}

		/**
		 * @description True when no further retry remains for the currently executing step — the
		 * strategy's budget is exhausted (or no strategy is configured), so a failure now is final.
		 * Retry-aware steps should branch on isFinalAttempt() for last-chance side effects, e.g. alerting.
		 *
		 * @return True when a failure of the current attempt is final; false when a retry remains.
		 *
		 * @since 1.6
		 */
		global Boolean isFinalAttempt()
		{
			return finalAttempt ?? true;
		}

		/**
		 * @description Returns the step-level idempotency key for the currently executing step: the
		 * chain execution id joined to the step index. The key stays identical when the same step
		 * replays, so a step that does one logical unit of work can store this key on an external-id
		 * field and upsert (a replay updates the same record instead of creating a duplicate), or stamp
		 * it on a marker for a side effect that cannot be upserted (a callout, an email) and skip when
		 * the marker is already present. Treat the result as an opaque token: compare it or store it
		 * whole, and do not split it to read back the run or step (use getChainExecutionId() and
		 * getCurrentStepIndex() for those). Call it from within a step's work(context), where the step
		 * index is always assigned.
		 *
		 * @return The step-level key, the execution id + "-" + step index.
		 *
		 * @since 1.2
		 *
		 * @example
		 * ```apex
		 * String key = context.idempotencyKey();
		 * ```
		 */
		global String idempotencyKey()
		{
			return getChainExecutionId() + '-' + String.valueOf(getCurrentStepIndex());
		}

		/**
		 * @description Returns the record-grain idempotency key for a step that fans out over many
		 * records: the step-level key joined to the given record id. Use it so a replay after a
		 * partial failure only reprocesses the rows that did not complete the first time, instead of
		 * re-running or skipping the whole step. A null recordId falls back to the bare step-level key.
		 * An 18-character Id keeps the whole key well under the 255-character external-id limit, so this
		 * overload needs no length caveat. Treat the result as an opaque token. Pass a literal null as a
		 * typed variable or a cast ((Id) null), because a bare idempotencyKey(null) is ambiguous between
		 * this overload and the String overload.
		 *
		 * @param recordId The record being processed, used as the per-record grain.
		 *
		 * @return The step-level key + "-" + recordId, or the bare step-level key when recordId is null.
		 *
		 * @since 1.2
		 *
		 * @example
		 * ```apex
		 * String rowKey = context.idempotencyKey(record.Id);
		 * ```
		 */
		global String idempotencyKey(Id recordId)
		{
			return recordId == null ? idempotencyKey() : idempotencyKey() + '-' + recordId;
		}

		/**
		 * @description Returns a custom-grain idempotency key for a step that fans out over a unit that
		 * is not a record id (for example a line number or an external key): the step-level key joined
		 * to the given grain. A null or blank grain falls back to the bare step-level key. The grain
		 * passes through verbatim, so the helper never hashes or truncates it. The composed key is
		 * typically stored on a Text external-id field capped at 255 characters; an over-long key fails
		 * loudly at upsert with a STRING_TOO_LONG DmlException (not silent truncation), so it surfaces
		 * in your own test. If you need a long composite grain, shorten it yourself (a one-line hash of
		 * just the grain) before passing it. Treat the result as an opaque token. Pass a literal null as
		 * a typed variable or a cast ((String) null), because a bare idempotencyKey(null) is ambiguous
		 * between this overload and the Id overload.
		 *
		 * @param grain The stable fan-out token, kept short, that does not change between attempts.
		 *
		 * @return The step-level key + "-" + grain, or the bare step-level key when grain is blank.
		 *
		 * @since 1.2
		 *
		 * @example
		 * ```apex
		 * String lineKey = context.idempotencyKey('orderLine-' + lineNumber);
		 * ```
		 */
		global String idempotencyKey(String grain)
		{
			return String.isNotBlank(grain) ? idempotencyKey() + '-' + grain : idempotencyKey();
		}

		/**
		 * @description Sets the previous step result. Framework use only.
		 *
		 * @param result The StepResult to set as the previous step result.
		 */
		@TestVisible
		private void setPreviousStepResult(StepResult result)
		{
			this.previousStepResult = result;
		}

		/**
		 * @description Serializes the context data map to a JSON string for persistence.
		 *
		 * @return A JSON string representation of the context data.
		 */
		@TestVisible
		private String serialize()
		{
			return JSON.serialize(data);
		}

	}

	/**
	 * @description Deserializes a JSON string back into a ChainContext with the given metadata.
	 *
	 * @param serializedData The JSON string to deserialize.
	 * @param chainExecutionId The chain execution record ID.
	 * @param correlationId The correlation ID for log correlation.
	 *
	 * @return A new ChainContext populated with the deserialized data.
	 */
	@TestVisible
	private static ChainContext deserializeContext(String serializedData, String chainExecutionId, String correlationId)
	{
		ChainContext context = new ChainContext(chainExecutionId, correlationId);

		if(String.isNotBlank(serializedData))
		{
			context.data = (Map<String, Object>)JSON.deserializeUntyped(serializedData);
		}

		return context;
	}

	/**
	 * @description Fluent builder for configuring and executing an async chain.
	 * Provides methods for adding steps, setting context, configuring error/completion handlers, and executing the chain.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String executionId = UTIL_AsyncChain.newChain('OrderProcessing')
	 *     .then(new ValidateOrderStep())
	 *     .then(new ProcessPaymentStep())
	 *     .withInitialContext('orderId', order.Id)
	 *     .onError(new NotifyAdminStep())
	 *     .onComplete(new SendConfirmationStep())
	 *     .execute();
	 * ```
	 */
	global inherited sharing class ChainBuilder
	{
		/**
		 * @description The descriptive name for this chain.
		 */
		private final String chainName;

		/**
		 * @description The ordered list of step definitions to execute.
		 */
		private final List<DTO_StepDefinition> steps;

		/**
		 * @description Initial context data to seed the chain with.
		 */
		private final Map<String, Object> initialContext;

		/**
		 * @description The error handler step definition, invoked when a step fails.
		 */
		private DTO_StepDefinition errorHandler;

		/**
		 * @description The completion handler step definition, invoked when all steps succeed.
		 */
		private DTO_StepDefinition completionHandler;

		/**
		 * @description Maximum number of steps allowed in this chain.
		 */
		private Integer maxSteps;

		/**
		 * @description Maximum serialized context size in characters.
		 */
		private Integer maxContextSize;

		/**
		 * @description AsyncOptions controlling queueable stack depth. When null, the framework
		 * creates a default with maximumQueueableStackDepth = steps.size() + 1.
		 */
		private AsyncOptions asyncOptions;

		/**
		 * @description Best-effort delay in minutes before the chain's first step is enqueued. Null or
		 * zero means no delay. Set via withDelayMinutes and applied only to the first enqueue.
		 */
		@TestVisible
		private Integer firstStepDelayMinutes;

		/**
		 * @description Active-run deduplication key stamped on the run record at start. Null when unset,
		 * which the insert treats as no key.
		 */
		private String deduplicationKey;

		/**
		 * @description Guards against accidental double-execution of the same builder.
		 */
		private Boolean executed = false;

		/**
		 * @description Private constructor to enforce creation via the newChain() factory method.
		 *
		 * @param chainName The descriptive name for this chain.
		 */
		private ChainBuilder(String chainName)
		{
			this.chainName = chainName;
			this.steps = new List<DTO_StepDefinition>();
			this.initialContext = new Map<String, Object>();
			this.maxSteps = DEFAULT_MAX_STEPS;
			this.maxContextSize = DEFAULT_MAX_CONTEXT_SIZE;
		}

		/**
		 * @description Appends a step to the end of the chain.
		 *
		 * @param step The IF_Chain.Step implementation to add.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.newChain('MyChain')
		 *     .then(new FirstStep())
		 *     .then(new SecondStep())
		 *     .execute();
		 * ```
		 */
		global ChainBuilder then(IF_Chain.Step step)
		{
			validateStepCapacity();
			if(step instanceof ApiStep)
			{
				((ApiStep)step).writeConfig(initialContext, steps.size());
			}
			steps.add(buildDefinition(step));
			return this;
		}

		/**
		 * @description Appends a step to the chain with explicit control over error continuation.
		 * Use this overload for IF_Chain.Step implementations that cannot extend ChainStep.
		 *
		 * @param step The IF_Chain.Step implementation to add.
		 * @param continueOnError When true, the chain continues past this step's failure.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.newChain('MyChain')
		 *     .then(new CriticalStep())
		 *     .then(new OptionalStep(), true)
		 *     .then(new FinalStep())
		 *     .execute();
		 * ```
		 */
		@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
		global ChainBuilder then(IF_Chain.Step step, Boolean continueOnError)
		{
			validateStepCapacity();
			if(step instanceof ApiStep)
			{
				((ApiStep)step).writeConfig(initialContext, steps.size());
			}
			DTO_StepDefinition definition = buildDefinition(step);
			if(continueOnError == true)
			{
				definition.continueOnError = true;
			}
			steps.add(definition);
			return this;
		}

		/**
		 * @description Build-time guard that mirrors the runtime cap enforced by ChainExecutor.
		 * Throws when the next `.then(step)` call would push the chain past `maxSteps`, so
		 * subscribers discover the cap when defining the chain rather than mid-execution
		 * (when partial work has already been committed and rollback is impossible across
		 * Queueable transaction boundaries).
		 */
		private void validateStepCapacity()
		{
			if(steps.size() >= maxSteps)
			{
				throw new UTIL_Exceptions.IllegalStateException(
						'Chain step capacity exceeded: maxSteps=' + maxSteps
						+ ' but step #' + (steps.size() + 1) + ' attempted to be added. '
						+ 'Increase via .withMaxSteps(...) before adding more steps, '
						+ 'or split the work into multiple chains.');
			}
		}

		/**
		 * @description Seeds the chain context with an initial key-value pair before execution begins.
		 * This is additive — each call adds one key-value pair to the initial context map.
		 *
		 * @param key The context key.
		 * @param value The context value.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.newChain('MyChain')
		 *     .withInitialContext('recordId', record.Id)
		 *     .withInitialContext('batchSize', 200)
		 *     .then(new ProcessStep())
		 *     .execute();
		 * ```
		 */
		global ChainBuilder withInitialContext(String key, Object value)
		{
			initialContext.put(key, value);
			return this;
		}

		/**
		 * @description Sets the maximum number of steps the chain is allowed to execute.
		 * Prevents runaway chains from consuming unlimited resources. Default: 50.
		 *
		 * @param maximumSteps The maximum number of steps permitted.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.newChain('ShortChain')
		 *     .withMaxSteps(10)
		 *     .then(new MyStep())
		 *     .execute();
		 * ```
		 */
		global ChainBuilder withMaxSteps(Integer maximumSteps)
		{
			this.maxSteps = maximumSteps;
			return this;
		}

		/**
		 * @description Sets the maximum serialized context size in characters.
		 * Prevents context overflow from storing large object graphs. Default: 32768.
		 *
		 * @param maximumSize The maximum context size in characters.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.newChain('LargeContextChain')
		 *     .withMaxContextSize(65536)
		 *     .then(new DataHeavyStep())
		 *     .execute();
		 * ```
		 */
		global ChainBuilder withMaxContextSize(Integer maximumSize)
		{
			this.maxContextSize = maximumSize;
			return this;
		}

		/**
		 * @description Sets the AsyncOptions controlling queueable stack depth. When provided,
		 * these options override the framework default (maximumQueueableStackDepth = steps.size() + 1).
		 * In tests, pass options with an explicit maximumQueueableStackDepth matching the expected
		 * chain depth to enable chained Queueable execution within Test.startTest/stopTest.
		 *
		 * @param options The AsyncOptions to use for queueable enqueuing.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * AsyncOptions options = new AsyncOptions();
		 * options.maximumQueueableStackDepth = 4;
		 * UTIL_AsyncChain.newChain('MyChain')
		 *     .then(new Step1()).then(new Step2()).then(new Step3())
		 *     .withAsyncOptions(options)
		 *     .execute();
		 * ```
		 */
		global ChainBuilder withAsyncOptions(AsyncOptions options)
		{
			this.asyncOptions = options;
			return this;
		}

		/**
		 * @description Defers the chain's first step by the given number of minutes. This is best-effort:
		 * the platform enqueues the first step with a Queueable delay, so the chain shows as Running with
		 * zero completed steps in the Chain Monitor until the delay elapses, and the delay degrades to
		 * immediate if the org has disabled Queueable delay. The value is clamped to the platform range
		 * of 0 to 10 minutes; a null or zero delay is a no-op. Only the first step is delayed; every later
		 * step runs as soon as its predecessor finishes.
		 *
		 * @param minutes The delay before the first step, in minutes (clamped to 0 to 10). Null is a no-op.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.2
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.newChain('NightlyRollup')
		 *     .then(new AggregateStep())
		 *     .withDelayMinutes(5)
		 *     .execute();
		 * ```
		 */
		global ChainBuilder withDelayMinutes(Integer minutes)
		{
			if(minutes == null)
			{
				this.firstStepDelayMinutes = null;
			}
			else
			{
				this.firstStepDelayMinutes = Math.max(MIN_QUEUEABLE_DELAY_MINUTES, Math.min(MAX_QUEUEABLE_DELAY_MINUTES, minutes));
			}
			return this;
		}

		/**
		 * @description Guards against two overlapping runs of the same logical chain. While a run holds
		 * the key, a second execute() with the same key returns the active run's Id instead of starting
		 * a duplicate. Any terminal status releases the key in the same update, so a sequential re-run
		 * is deliberately allowed; a Stalled run still holds its key until it is recovered or resolved.
		 * The key is stored verbatim; the platform's unique text index is case-insensitive, so keys
		 * differing only in case collide. Zero-step chains complete immediately and never hold a key.
		 * Distinct from ChainContext.idempotencyKey(), which generates replay-safe keys for your own
		 * step side effects — this method prevents a second run from starting at all.
		 *
		 * @param deduplicationKey Non-blank key, at most 255 characters — e.g. a schedule name or a
		 *                 template like 'nightly-sync-' + recordId.
		 *
		 * @return This builder, for chaining.
		 *
		 * @since 1.6
		 *
		 * @example
		 * ```apex
		 * String runId = UTIL_AsyncChain.newChain('NightlyAccountSync')
		 *     .then(new SyncStep())
		 *     .withDeduplicationKey('nightly-account-sync')
		 *     .execute();
		 * ```
		 */
		global ChainBuilder withDeduplicationKey(String deduplicationKey)
		{
			if(String.isBlank(deduplicationKey))
			{
				throw new UTIL_Exceptions.IllegalStateException('Deduplication key must not be blank.');
			}
			if(deduplicationKey.length() > DEDUPLICATION_KEY_MAX_LENGTH)
			{
				throw new UTIL_Exceptions.IllegalStateException(
						'Deduplication key exceeds ' + DEDUPLICATION_KEY_MAX_LENGTH + ' characters: ' + deduplicationKey.length());
			}
			this.deduplicationKey = deduplicationKey;
			return this;
		}

		/**
		 * @description Registers an error handler step that executes when any step fails
		 * (unless the failing step has continueOnError set to true).
		 *
		 * @param errorHandlerStep The IF_Chain.Step to execute on failure. Receives the chain context with the failure details.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.newChain('MyChain')
		 *     .then(new RiskyStep())
		 *     .onError(new NotifyAdminStep())
		 *     .execute();
		 * ```
		 */
		global ChainBuilder onError(IF_Chain.Step errorHandlerStep)
		{
			DTO_StepDefinition definition = buildDefinition(errorHandlerStep);
			definition.isErrorHandler = true;
			this.errorHandler = definition;
			return this;
		}

		/**
		 * @description Registers a completion handler step that executes ONLY when every step in
		 * the chain completes successfully. The completion handler does NOT run when the chain
		 * terminates in failure (i.e. when a step returns a failed StepResult OR throws and the
		 * step is not marked `continueOnError`).
		 *
		 * **Failure-path handler is a separate registration.** To run a step on failure, register
		 * an error handler via `.onError(...)`. The two handlers are mutually exclusive at runtime:
		 * exactly one of them fires per chain (success → onComplete, failure → onError), and
		 * neither fires if the chain is aborted by the framework kill switch. Subscribers needing
		 * "always-runs" cleanup (e.g. release a row lock, close a session) should put the cleanup
		 * inside the final step's `work()` body and use `continueOnError = true` on the step
		 * before it, so the final step runs regardless of upstream failures.
		 *
		 * @param completionHandlerStep The IF_Chain.Step to execute on successful completion.
		 *
		 * @return This ChainBuilder for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsyncChain.newChain('MyChain')
		 *     .then(new ProcessStep())
		 *     .onComplete(new SendConfirmationStep())   // success-only
		 *     .onError(new NotifyAdminStep())           // failure-only
		 *     .execute();
		 * ```
		 */
		global ChainBuilder onComplete(IF_Chain.Step completionHandlerStep)
		{
			DTO_StepDefinition definition = buildDefinition(completionHandlerStep);
			definition.isCompletionHandler = true;
			this.completionHandler = definition;
			return this;
		}

		/**
		 * @description Executes the chain with an auto-generated correlation ID.
		 * Persists the chain configuration and enqueues the first step.
		 *
		 * @return The ID of the AsyncChainExecution__c record tracking this chain.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException If the serialized step list exceeds the
		 * StepLog__c field capacity less the per-step runtime reserve — see the correlation-ID
		 * overload this method delegates to.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String executionId = UTIL_AsyncChain.newChain('MyChain')
		 *     .then(new MyStep())
		 *     .execute();
		 * ```
		 */
		global String execute()
		{
			String existingCorrelationId = LOG_Builder.correlationId;
			return execute(String.isNotBlank(existingCorrelationId) ? existingCorrelationId : UTIL_Random.randomUUID());
		}

		/**
		 * @description Executes the chain with a caller-supplied correlation ID for log tracing.
		 * Persists the chain configuration and enqueues the first step.
		 *
		 * @param correlationId The correlation ID to attach to all log entries for this chain.
		 *
		 * @return The ID of the AsyncChainExecution__c record tracking this chain.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException If the serialized step list exceeds the
		 * StepLog__c field capacity less the per-step runtime reserve — a chain that cannot persist
		 * its step list intact for its whole life must fail at definition time, never by silently
		 * truncating the persisted JSON.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String executionId = UTIL_AsyncChain.newChain('MyChain')
		 *     .then(new MyStep())
		 *     .execute('my-correlation-id');
		 * ```
		 */
		global String execute(String correlationId)
		{
			if(executed)
			{
				throw new UTIL_Exceptions.IllegalStateException('Chain has already been executed. Create a new ChainBuilder via newChain().');
			}

			String serializedStepList = JSON.serialize(buildPersistedDefinitions(), true);
			Integer stepLogCapacity = UTIL_SObjectDescribe.getCachedFieldDescribe(AsyncChainExecution__c.StepLog__c).getLength();
			Integer allowedStepListLength = stepLogCapacity - steps.size() * STEP_RUNTIME_RESERVE_LENGTH;
			if(serializedStepList.length() > allowedStepListLength)
			{
				throw new UTIL_Exceptions.IllegalStateException(
						'Chain step log overflow: ' + serializedStepList.length() + ' / ' + allowedStepListLength
						+ ' characters (StepLog__c capacity ' + stepLogCapacity + ' less ' + STEP_RUNTIME_RESERVE_LENGTH
						+ ' per step reserved for runtime step results). Shorten step names or split the work into multiple chains.');
			}
			executed = true;

			initialContext.put(LOG_CONTEXT_KEY, LOG_Builder.serializeContext());

			AsyncChainExecution__c execution = new AsyncChainExecution__c
					(
							ChainName__c = chainName,
							Status__c = SEL_AsyncChainExecution.STATUS_RUNNING,
							TotalSteps__c = steps.size(),
							CompletedSteps__c = 0,
							StartedAt__c = Datetime.now(),
							CorrelationId__c = correlationId,
							ContextData__c = JSON.serialize(initialContext),
							StepLog__c = serializedStepList
					);
			execution.RunKey__c = UTIL_Random.randomUUID();
			if(steps.isEmpty())
			{
				execution.Status__c = SEL_AsyncChainExecution.STATUS_COMPLETED;
				execution.CompletedAt__c = Datetime.now();
				DML_Builder.newTransaction().systemModeInternal().doInsert(execution).execute();
				emitTerminalLog(LoggingLevel.INFO, 'Chain completed: ' + chainName + ' (no steps)', CLASS_NAME + '.ChainBuilder.execute', execution.Id);
				return execution.Id;
			}

			execution.ActiveDeduplicationKey__c = deduplicationKey;
			String activeRunId = insertGuardedByDeduplicationKey(execution);
			if(activeRunId != null)
			{
				return activeRunId;
			}

			AsyncOptions options = asyncOptions != null ? asyncOptions : new AsyncOptions();

			if(asyncOptions == null)
			{
				options.maximumQueueableStackDepth = steps.size() + 1;
			}

			ChainExecutor executor = new ChainExecutor(execution.Id, 0, maxSteps, maxContextSize, errorHandler, completionHandler, options, execution.RunKey__c);

			if(firstStepDelayMinutes != null && firstStepDelayMinutes > 0)
			{
				System.enqueueJob(executor, firstStepDelayMinutes);
			}
			else if(asyncOptions != null)
			{
				System.enqueueJob(executor, options);
			}
			else
			{
				System.enqueueJob(executor);
			}

			return execution.Id;
		}

		/**
		 * @description Inserts the run record. A DUPLICATE_VALUE failure on a keyed start is
		 * attributed to the deduplication index PRESUMPTIVELY — the platform redacts the colliding
		 * field's name from most callers, so a keyed collision on another unique field can attribute
		 * here too. The winner lookup and single retry disambiguate: a run holding the key means the
		 * start deduplicates onto it (correct landing); an empty lookup means the winner released the
		 * key — or the collision was never on the deduplication index — and the insert is re-attempted
		 * exactly once, so a second failure surfaces the real platform error.
		 *
		 * @param execution The fully-populated run record to insert.
		 *
		 * @return The active run's Id when the start deduplicated onto it; null when this run's
		 *         insert succeeded.
		 */
		private String insertGuardedByDeduplicationKey(AsyncChainExecution__c execution)
		{
			try
			{
				DML_Builder.newTransaction().systemModeInternal().doInsert(execution).execute();
			}
			catch(DmlException insertError)
			{
				String activeRunId = resolveActiveRun(insertError);
				if(activeRunId != null)
				{
					return activeRunId;
				}
				DML_Builder.newTransaction().systemModeInternal().doInsert(execution).execute();
			}
			return null;
		}

		/**
		 * @description Resolves a failed insert to the run currently holding the key. A chain started
		 * without a deduplication key can never collide on the deduplication index, so its failures
		 * always rethrow verbatim before any attribution — the keyless CorrelationId__c collision
		 * keeps its pre-existing uncaught behaviour structurally, independent of message wording.
		 * Keyed failures rethrow unless the predicate presumptively attributes them to the
		 * deduplication index.
		 *
		 * @param insertError The exception the failed insert raised.
		 *
		 * @return The winner's Id, or null when the key has already been released.
		 */
		private String resolveActiveRun(DmlException insertError)
		{
			if(String.isBlank(deduplicationKey) || !isActiveDeduplicationKeyCollision(insertError))
			{
				throw insertError;
			}
			AsyncChainExecution__c activeRun = new SEL_AsyncChainExecution().findByActiveDeduplicationKey(deduplicationKey);
			return activeRun?.Id;
		}

		/**
		 * @description True when a failed insert presumptively collides on the deduplication index: a
		 * DUPLICATE_VALUE whose message does NOT name CorrelationId__c (resolved through the describe
		 * cache, so the match is exact in both namespaced and unmanaged deploys). The check is
		 * negative because that is what survives the platform's message variability: field API names
		 * embed verbatim in localized platform messages, while redaction blanks the field position
		 * entirely for callers without org-wide record access — so a positive match on the
		 * deduplication field's name would fail for exactly those callers. Enumeration assumption:
		 * AsyncChainExecution__c carries exactly two unique indexes (CorrelationId__c and
		 * ActiveDeduplicationKey__c); a future unique field must join the negative list. Under
		 * redaction a keyed CorrelationId__c collision can attribute here — the caller's winner
		 * lookup and single retry disambiguate it safely.
		 *
		 * @param insertError The exception the failed insert raised.
		 *
		 * @return True for a presumptive deduplication-index collision.
		 */
		private Boolean isActiveDeduplicationKeyCollision(DmlException insertError)
		{
			return insertError.getNumDml() > 0
					&& insertError.getDmlType(0) == StatusCode.DUPLICATE_VALUE
					&& !insertError.getDmlMessage(0).contains(UTIL_SObjectDescribe.getCachedFieldName(AsyncChainExecution__c.CorrelationId__c));
		}

		/**
		 * @description Assembles the definition list persisted to StepLog__c: every chain step in
		 * execution order, then the onError / onComplete handler definitions (when registered),
		 * flagged via isErrorHandler / isCompletionHandler. Ordering contract: handler entries
		 * always follow the step entries, so persisted step indices equal runtime step indices and
		 * consumers can filter the handlers out without shifting anything. Persisting the handlers
		 * is what lets record-only actors — the watchdog sweep's stall notification and its
		 * re-drive rehydration — rebuild the chain's full shape after the executor state is gone.
		 *
		 * @return The combined step and handler definition list, handlers last.
		 */
		private List<DTO_StepDefinition> buildPersistedDefinitions()
		{
			List<DTO_StepDefinition> persistedDefinitions = new List<DTO_StepDefinition>(steps);
			if(errorHandler != null)
			{
				persistedDefinitions.add(errorHandler);
			}
			if(completionHandler != null)
			{
				persistedDefinitions.add(completionHandler);
			}
			return persistedDefinitions;
		}

	}

	/**
	 * @description Chain step adapter that executes any API_Outbound handler as part of an async chain.
	 * Wraps the full web service lifecycle (validation, callout, response parsing, DML, ApiCall__c persistence)
	 * via UTIL_HttpClient delegation mode, allowing existing outbound services to run inside chains with
	 * zero changes to the service class.
	 *
	 * Configuration is stored in the ChainContext (not on the step instance) because steps are serialized
	 * as class names and instantiated via reflection. At build-time, the ChainBuilder calls writeConfig()
	 * to persist the step's configuration into the initial context. At execution-time, work() reads the
	 * configuration back from the context using the current step index.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_AsyncChain.newChain('OrderProcessing')
	 *     .withInitialContext('orderId', order.Id)
	 *     .then(new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
	 *         .triggeringRecordFrom('orderId')
	 *         .withParameter(API_ChargePayment.PARAM_AMOUNT, '99.99'))
	 *     .then(new UTIL_AsyncChain.ApiStep(API_SendConfirmation.class)
	 *         .triggeringRecordFrom('orderId')
	 *         .withParameterFrom('recipient', 'customerEmail'))
	 *     .onError(new NotifyAdminStep())
	 *     .execute();
	 * ```
	 */
	global inherited sharing class ApiStep extends ChainStep
	{
		/**
		 * @description The API_Outbound subclass to execute. Build-time only — not serialized.
		 */
		private final Type handlerType;

		/**
		 * @description Named Credential override for this handler instance. Build-time only.
		 */
		private String credentialOverride;

		/**
		 * @description Static parameters passed directly to the handler. Build-time only.
		 */
		private final Map<String, String> staticParameters
		{
			get
			{
				if(staticParameters == null)
				{
					staticParameters = new Map<String, String>();
				}
				return staticParameters;
			}
			set;
		}

		/**
		 * @description Mappings from handler parameter names to ChainContext keys. Build-time only.
		 */
		private final Map<String, String> contextMappings
		{
			get
			{
				if(contextMappings == null)
				{
					contextMappings = new Map<String, String>();
				}
				return contextMappings;
			}
			set;
		}

		/**
		 * @description Static triggering record ID. Build-time only.
		 */
		private String triggeringRecordIdValue;

		/**
		 * @description ChainContext key containing the triggering record ID. Build-time only.
		 */
		private String triggeringRecordContextKey;

		/**
		 * @description Total chain-level attempts for this step including the first (2 = one retry).
		 * Set at build-time by withRetry() and re-stashed from the persisted config by work() before
		 * the callout, so the post-work retry consult sees it on the fresh instance. Null when
		 * chain-level retry is not configured.
		 */
		private Integer retryMaxAttempts;

		/**
		 * @description Base backoff seconds fed to UTIL_Retry.exponential(). Stored only together
		 * with retryMaxAttempts — the pair is whole or absent.
		 */
		private Integer retryBackoffSeconds;

		/**
		 * @description No-argument constructor for reflection-based instantiation by the chain executor.
		 * Do not use directly — use the Type constructor instead.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public ApiStep()
		{
			// Required by Type.newInstance() — chain executor rehydrates via the Type constructor.
		}

		/**
		 * @description Creates an ApiStep that wraps the specified API_Outbound handler.
		 *
		 * @param handlerType The API_Outbound subclass to execute (e.g., API_SendEmail.class).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new UTIL_AsyncChain.ApiStep(API_SendEmail.class)
		 *     .withParameter(API_SendEmail.PARAM_RECIPIENT, 'test@example.com')
		 *     .triggeringRecordFrom('recordId')
		 * ```
		 */
		global ApiStep(Type handlerType)
		{
			UTIL_System.assertTypeAssignable(API_Outbound.class, handlerType);
			this.handlerType = handlerType;
			this.stepName = handlerType.getName();
		}

		/**
		 * @description Overrides the Named Credential used for this API call.
		 *
		 * @param namedCredential The Named Credential developer name.
		 *
		 * @return This ApiStep for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new UTIL_AsyncChain.ApiStep(API_SendEmail.class)
		 *     .credential('AlternateGateway')
		 * ```
		 */
		global ApiStep credential(String namedCredential)
		{
			this.credentialOverride = namedCredential;
			return this;
		}

		/**
		 * @description Adds a static parameter value to pass to the handler.
		 *
		 * @param name The parameter name (use the handler's PARAM_* constants).
		 * @param value The parameter value.
		 *
		 * @return This ApiStep for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
		 *     .withParameter(API_ChargePayment.PARAM_AMOUNT, '99.99')
		 *     .withParameter(API_ChargePayment.PARAM_CURRENCY, 'USD')
		 * ```
		 */
		global ApiStep withParameter(String name, String value)
		{
			this.staticParameters.put(name, value);
			return this;
		}

		/**
		 * @description Maps a handler parameter to a ChainContext key, resolved at execution-time.
		 * Use this when the parameter value is produced by a prior step in the chain.
		 *
		 * @param parameterName The handler parameter name.
		 * @param contextKey The ChainContext key to read the value from.
		 *
		 * @return This ApiStep for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new UTIL_AsyncChain.ApiStep(API_SendConfirmation.class)
		 *     .withParameterFrom('recipient', 'customerEmail')
		 * ```
		 */
		global ApiStep withParameterFrom(String parameterName, String contextKey)
		{
			this.contextMappings.put(parameterName, contextKey);
			return this;
		}

		/**
		 * @description Sets a static triggering record ID for this API call.
		 *
		 * @param recordId The Salesforce record ID.
		 *
		 * @return This ApiStep for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new UTIL_AsyncChain.ApiStep(API_SendEmail.class)
		 *     .triggeringRecord(account.Id)
		 * ```
		 */
		global ApiStep triggeringRecord(Id recordId)
		{
			this.triggeringRecordIdValue = String.valueOf(recordId);
			return this;
		}

		/**
		 * @description Sets the triggering record ID from a ChainContext key, resolved at execution-time.
		 *
		 * @param contextKey The ChainContext key containing the record ID.
		 *
		 * @return This ApiStep for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
		 *     .triggeringRecordFrom('orderId')
		 * ```
		 */
		global ApiStep triggeringRecordFrom(String contextKey)
		{
			this.triggeringRecordContextKey = contextKey;
			return this;
		}

		/**
		 * @description Opt-in chain-level retry for this API step. When configured, the chain re-runs
		 * the whole step (a fresh callout) with exponential backoff, and the outbound engine's own
		 * NextRetry__c rescheduling is suppressed for calls made by this step — one retry authority,
		 * never two. Without this call the outbound engine keeps sole ownership of retries, exactly
		 * as before.
		 *
		 * @param maxAttempts Total attempts including the first (2 = one retry). Null or <= 1 disables.
		 * @param baseBackoffSeconds Base delay fed to UTIL_Retry.exponential(); null = 0.
		 *
		 * @return This ApiStep for method chaining.
		 *
		 * @since 1.6
		 *
		 * @example
		 * ```apex
		 * new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
		 *     .triggeringRecordFrom('orderId')
		 *     .withRetry(3, 30)
		 * ```
		 */
		global ApiStep withRetry(Integer maxAttempts, Integer baseBackoffSeconds)
		{
			Boolean retryDisabled = maxAttempts == null || maxAttempts <= 1;
			this.retryMaxAttempts = retryDisabled ? null : maxAttempts;
			this.retryBackoffSeconds = retryDisabled ? null : baseBackoffSeconds;
			return this;
		}

		/**
		 * @description Builds the chain-level retry strategy from the configuration stash work()
		 * reads before the callout: exponential backoff with maxAttempts - 1 retries. Null when
		 * withRetry was never configured, which preserves the pre-existing single-attempt behaviour
		 * and the outbound engine's sole ownership of retries.
		 *
		 * @return The configured strategy, or null when this step has no chain-level retry.
		 *
		 * @since 1.6
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return retryMaxAttempts == null || retryMaxAttempts <= 1
					? null
					: UTIL_Retry.exponential().withMaxRetries(retryMaxAttempts - 1).withBaseBackoff(retryBackoffSeconds ?? 0);
		}

		/**
		 * @description Persists this step's configuration into the chain's initial context map.
		 * Called by ChainBuilder.then() at build-time so the configuration survives reflection instantiation.
		 *
		 * @param initialContext The chain's initial context map to write configuration into.
		 * @param stepIndex The zero-based index of this step in the chain.
		 */
		@TestVisible
		private void writeConfig(Map<String, Object> initialContext, Integer stepIndex)
		{
			Map<String, Object> config = new Map<String, Object>();
			config.put('handlerClassName', handlerType.getName());

			if(String.isNotBlank(credentialOverride))
			{
				config.put('credential', credentialOverride);
			}
			if(!staticParameters.isEmpty())
			{
				config.put('staticParams', staticParameters);
			}
			if(!contextMappings.isEmpty())
			{
				config.put('contextMappings', contextMappings);
			}
			if(String.isNotBlank(triggeringRecordIdValue))
			{
				config.put('triggeringRecordId', triggeringRecordIdValue);
			}
			if(String.isNotBlank(triggeringRecordContextKey))
			{
				config.put('triggeringRecordContextKey', triggeringRecordContextKey);
			}
			if(retryMaxAttempts != null)
			{
				config.put('retryMaxAttempts', retryMaxAttempts);
				config.put('retryBackoffSeconds', retryBackoffSeconds);
			}

			initialContext.put(API_STEP_CONFIG_KEY_PREFIX + stepIndex, config);
		}

		/**
		 * @description Executes the API_Outbound handler via UTIL_HttpClient delegation mode.
		 * Reads configuration from the ChainContext, builds the request, invokes the handler,
		 * and writes results back to the context for downstream steps.
		 *
		 * @param context Shared chain context for reading configuration and writing results.
		 *
		 * @return StepResult indicating success or failure of the API call.
		 *
		 * @since 1.0
		 */
		global override StepResult work(ChainContext context)
		{
			Integer stepIndex = context.getCurrentStepIndex();
			Map<String, Object> config = (Map<String, Object>)context.get(API_STEP_CONFIG_KEY_PREFIX + stepIndex);

			if(config == null)
			{
				return UTIL_AsyncChain.failed('ApiStep configuration not found for step index ' + stepIndex);
			}

			retryMaxAttempts = (Integer)config.get('retryMaxAttempts');
			retryBackoffSeconds = (Integer)config.get('retryBackoffSeconds');

			String handlerClassName = (String)config.get('handlerClassName');
			Type resolvedHandlerType = Type.forName(handlerClassName);

			if(resolvedHandlerType == null)
			{
				return UTIL_AsyncChain.failed('Handler class not found: ' + handlerClassName);
			}

			UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.useHandler(resolvedHandlerType);

			String credential = (String)config.get('credential');
			if(String.isNotBlank(credential))
			{
				builder.credential(credential);
			}

			Map<String, Object> staticParams = (Map<String, Object>)config.get('staticParams');
			if(staticParams != null)
			{
				for(String parameterName : staticParams.keySet())
				{
					builder.withParameter(parameterName, String.valueOf(staticParams.get(parameterName)));
				}
			}

			Map<String, Object> mappings = (Map<String, Object>)config.get('contextMappings');
			if(mappings != null)
			{
				for(String parameterName : mappings.keySet())
				{
					String contextKey = (String)mappings.get(parameterName);
					Object contextValue = context.get(contextKey);
					if(contextValue != null)
					{
						builder.withParameter(parameterName, String.valueOf(contextValue));
					}
				}
			}

			String staticRecordId = (String)config.get('triggeringRecordId');
			String recordContextKey = (String)config.get('triggeringRecordContextKey');
			if(String.isNotBlank(staticRecordId))
			{
				builder.withTriggeringRecord(Id.valueOf(staticRecordId));
			}
			else if(String.isNotBlank(recordContextKey))
			{
				Object recordIdValue = context.get(recordContextKey);
				if(recordIdValue != null)
				{
					builder.withTriggeringRecord(Id.valueOf(String.valueOf(recordIdValue)));
				}
			}

			builder.withCorrelationId(context.getCorrelationId());

			if(retryMaxAttempts > 1)
			{
				builder.suppressHandlerSelfRetryScheduling();
			}

			API_Outbound handler = builder.invoke();

			Map<String, Object> apiResult = new Map<String, Object>
			{
					'success' => handler.result.isSuccess,
					'statusCode' => handler.result.statusCode,
					'apiCallId' => handler.apiCall?.Id
			};

			String errors = handler.errorText;
			if(String.isNotBlank(errors))
			{
				apiResult.put('errors', errors);
			}

			context.put(API_STEP_RESULT_KEY_PREFIX + stepIndex, apiResult);

			if(handler.result.isSuccess)
			{
				return UTIL_AsyncChain.succeeded(handlerClassName + ' completed (HTTP ' + handler.result.statusCode + ')');
			}

			String errorMessage = handlerClassName + ' failed';
			if(String.isNotBlank(errors))
			{
				errorMessage += ': ' + errors;
			}
			return UTIL_AsyncChain.failed(errorMessage);
		}
	}

	/**
	 * @description Step definition DTO representing a single step's configuration and runtime state.
	 * Serialized to the StepLog__c field as a JSON array: the chain's step entries in execution
	 * order, followed by its onError / onComplete handler entries (isErrorHandler /
	 * isCompletionHandler) — handlers always last, so persisted step indices equal runtime step
	 * indices (see filterStepEntries). Public for internal framework access
	 * (e.g., CTRL_ChainMonitor) but not global — subscribers interact via ChainStep and StepResult.
	 */
	public inherited sharing class DTO_StepDefinition
	{
		/**
		 * @description Fully-qualified or short class name.
		 */
		public String className;

		/**
		 * @description Display name for logs and status.
		 */
		public String stepName;

		/**
		 * @description Whether to continue the chain if this step fails. Null = false (suppressed from JSON).
		 */
		public Boolean continueOnError;

		/**
		 * @description Whether this step succeeded. Set at runtime after step execution.
		 */
		public Boolean success;

		/**
		 * @description Step execution duration in milliseconds. Set at runtime.
		 */
		public Long durationMs;

		/**
		 * @description Failure message. Set at runtime only when the step fails.
		 */
		public String message;

		/**
		 * @description 1-based attempt number of the step's most recent execution. Written at runtime
		 * by the retry scheduler; null-suppressed = first attempt (upgrade-safe: step logs persisted
		 * before this field existed deserialize with a null attempt and read as attempt 1).
		 */
		public Integer attempt;

		/**
		 * @description True for onError() handler.
		 */
		public Boolean isErrorHandler;

		/**
		 * @description True for onComplete() handler. Null = false (suppressed from JSON).
		 */
		public Boolean isCompletionHandler;
	}

	/**
	 * @description Queueable executor that runs a single chain step per transaction and enqueues
	 * the next step upon completion. Also implements Finalizer for unhandled exception recovery.
	 */
	@TestVisible
	@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
	private inherited sharing class ChainExecutor implements Queueable, Database.AllowsCallouts, Finalizer
	{
		/**
		 * @description The ID of the AsyncChainExecution__c record being executed.
		 */
		private final Id chainExecutionId;

		/**
		 * @description The zero-based index of the current step to execute.
		 */
		private final Integer currentStepIndex;

		/**
		 * @description Maximum number of steps allowed in this chain.
		 */
		private final Integer maxSteps;

		/**
		 * @description Maximum serialized context size in characters.
		 */
		private final Integer maxContextSize;

		/**
		 * @description The error handler step definition, if configured.
		 */
		private final DTO_StepDefinition errorHandler;

		/**
		 * @description The completion handler step definition, if configured.
		 */
		private final DTO_StepDefinition completionHandler;

		/**
		 * @description AsyncOptions controlling queueable stack depth for chained execution.
		 */
		private final AsyncOptions asyncOptions;

		/**
		 * @description The run key captured when this executor was enqueued; matches the record's
		 * stored RunKey__c for a healthy run. Null for executors serialized before the field
		 * existed (pre-upgrade in-flight chains).
		 */
		private final String capturedRunKey;

		/**
		 * @description Flag set during execute() to signal that the Finalizer should chain to the next step.
		 */
		private Boolean shouldChainNext = false;

		/**
		 * @description Flag set by scheduleRetry to signal that the Finalizer should re-enqueue this
		 * executor at the SAME step index (a retry link) instead of chaining to the next step.
		 */
		private Boolean retryScheduled = false;

		/**
		 * @description Enqueue delay for the scheduled retry, in minutes: the strategy's computed
		 * backoff clamped to the platform enqueue window by clampBackoffToEnqueueWindow.
		 */
		private Integer retryDelayMinutes;

		/**
		 * @description The full persisted StepLog__c definition list deserialized by execute(): steps
		 * first, handlers last. Held on the instance so scheduleRetry can re-serialize the full
		 * document and the Finalizer's retry re-enqueue can size its stack-depth cap.
		 */
		private List<DTO_StepDefinition> persistedDefinitions;

		/**
		 * @description Pending handler to enqueue from the Finalizer for transaction isolation.
		 * Set by handleChainCompletion or handleStepFailure when a handler is configured.
		 */
		private HandlerExecutor pendingHandler;

		/**
		 * @description Constructs a new ChainExecutor for the given chain execution.
		 *
		 * @param chainExecutionId The ID of the AsyncChainExecution__c record.
		 * @param currentStepIndex The zero-based index of the step to execute.
		 * @param maxSteps Maximum number of steps allowed.
		 * @param maxContextSize Maximum serialized context size in characters.
		 * @param errorHandler The error handler step definition, or null.
		 * @param completionHandler The completion handler step definition, or null.
		 * @param asyncOptions AsyncOptions for controlling queueable chaining depth.
		 * @param capturedRunKey The run key captured at enqueue time, or null for legacy executions.
		 */
		@TestVisible
		private ChainExecutor
				(
						Id chainExecutionId,
						Integer currentStepIndex,
						Integer maxSteps,
						Integer maxContextSize,
						DTO_StepDefinition errorHandler,
						DTO_StepDefinition completionHandler,
						AsyncOptions asyncOptions,
						String capturedRunKey
				)
		{
			this.chainExecutionId = chainExecutionId;
			this.currentStepIndex = currentStepIndex;
			this.maxSteps = maxSteps;
			this.maxContextSize = maxContextSize;
			this.errorHandler = errorHandler;
			this.completionHandler = completionHandler;
			this.asyncOptions = asyncOptions;
			this.capturedRunKey = capturedRunKey;
		}

		/**
		 * @description Executes the current step and enqueues the next step if the chain should continue.
		 *
		 * @param queueableContext The Queueable context provided by the platform.
		 */
		public void execute(QueueableContext queueableContext)
		{
			System.attachFinalizer(this);

			AsyncChainExecution__c execution = loadAuthorizedExecution();
			if(execution == null)
			{
				return;
			}

			// The persisted document carries handler entries after the steps (the serialisation ordering
			// contract). Step arithmetic — indexing, completion counting, the terminal check — runs on the
			// filtered step view; persists re-serialise the full document so the handler entries survive
			// every rewrite. The views share entry references, so runtime step results flow into both.
			persistedDefinitions = (List<DTO_StepDefinition>)JSON.deserialize(execution.StepLog__c, List<DTO_StepDefinition>.class);
			List<DTO_StepDefinition> steps = filterStepEntries(persistedDefinitions);
			ChainContext context = deserializeContext(execution.ContextData__c, execution.Id, execution.CorrelationId__c);
			hydrateLogContext(context, execution.CorrelationId__c);

			if(!UTIL_FeatureFlag.isEnabled(FEATURE_FLAG_NAME))
			{
				markAborted(execution, 'Kill switch active');
				return;
			}

			if(simulateCrash)
			{
				simulateCrash = false;
				throw new UTIL_Exceptions.IllegalStateException('Simulated Queueable crash');
			}
			context.currentStepIndex = currentStepIndex;
			restorePreviousStepResult(context);

			DTO_StepDefinition stepDefinition = steps[currentStepIndex];
			String displayName = String.isNotBlank(stepDefinition.stepName) ? stepDefinition.stepName : stepDefinition.className;
			StepResult result;
			String executorClass = CLASS_NAME + '.ChainExecutor.execute';

			UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer('Chain step: ' + displayName, executorClass);
			timer.start();

			IF_Chain.Step step;
			Integer attemptNumber = stepDefinition.attempt ?? 1;

			try
			{
				step = instantiateStep(stepDefinition);
				UTIL_Retry.Strategy preWorkStrategy = resolveRetryStrategy(step);
				context.currentAttempt = attemptNumber;
				context.finalAttempt = preWorkStrategy == null
						|| !preWorkStrategy.shouldRetry(UTIL_Retry.newContext(attemptNumber - 1));
				result = step.work(context);
			}
			catch(Exception error)
			{
				result = failed(error);
				LOG_Builder.build().error(error)
						.at(executorClass)
						.forRecord(execution.Id)
						.emit();
			}

			timer.stop();
			Long stepDurationMs = timer.getTime();

			stepDefinition.success = result.success;
			stepDefinition.durationMs = stepDurationMs;
			if(!result.success)
			{
				stepDefinition.message = UTIL_String.abbreviate(result.message, STEP_MESSAGE_MAX_LENGTH);
			}

			context.setPreviousStepResult(result);
			persistPreviousStepResult(context, result);

			if(!result.success && haltChainForFailedResult(execution, context, stepDefinition, result, step, attemptNumber))
			{
				return;
			}

			Boolean continuedFailureAppended = !result.success && stepDefinition.continueOnError == true;
			if(continuedFailureAppended)
			{
				LOG_Builder.build().warn('Step failed but continuing: ' + displayName + ' (' + stepDurationMs + 'ms)')
						.at(executorClass)
						.forRecord(execution.Id)
						.withContext('message', result.message)
						.withContext('durationMs', stepDurationMs)
						.emit();
				appendContinuedFailure(execution, displayName, result.message);
			}

			if(result.success)
			{
				execution.CompletedSteps__c = (execution.CompletedSteps__c == null ? 0 : execution.CompletedSteps__c) + 1;
			}
			execution.CurrentStepName__c = UTIL_String.abbreviate(displayName, AsyncChainExecution__c.CurrentStepName__c);
			// Watchdog liveness stamp: the id of the queueable job doing this step's work. It persists only
			// through the progress write's intended field list — terminal writes leave the last known executor's
			// job id in place — and HandlerExecutor never stamps it (handlers are notifications, not chain executors).
			execution.CurrentJobId__c = queueableContext.getJobId();

			String serializedContext = serializeContextWithinLimit(execution, context);
			if(serializedContext == null)
			{
				return;
			}

			execution.ContextData__c = serializedContext;
			execution.StepLog__c = serializeStepLog(persistedDefinitions);

			if(currentStepIndex + 1 >= steps.size())
			{
				handleChainCompletion(execution, context);
				return;
			}

			persistProgressAndChainNext(execution, continuedFailureAppended);
		}

		/**
		 * @description Loads the chain execution record and applies the entry guards: a deleted
		 * record, an externally aborted chain, and a stale run key each silence this executor.
		 *
		 * @return The loaded execution record, or null when the executor must go silent (the caller
		 * exits immediately without touching the record).
		 */
		private AsyncChainExecution__c loadAuthorizedExecution()
		{
			AsyncChainExecution__c execution = (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(chainExecutionId);

			if(execution == null)
			{
				LOG_Builder.build().warn('Chain execution record deleted externally')
						.at(CLASS_NAME + '.ChainExecutor.execute')
						.forRecord(chainExecutionId)
						.emit();
				return null;
			}

			if(execution.Status__c == SEL_AsyncChainExecution.STATUS_ABORTED)
			{
				return null;
			}

			if(execution.RunKey__c != capturedRunKey)
			{
				LOG_Builder.build().warn('Chain step skipped: stale run key (fenced)')
						.at(CLASS_NAME + '.ChainExecutor.execute')
						.forRecord(execution.Id)
						.emit();
				return null;
			}

			return execution;
		}

		/**
		 * @description Hydrates the transaction's logging context from the serialized LOG context the
		 * chain carries, falling back to plain correlation-id propagation for chains persisted before
		 * a LOG context existed.
		 *
		 * @param context The current chain context.
		 * @param correlationId The chain's correlation ID fallback.
		 */
		private void hydrateLogContext(ChainContext context, String correlationId)
		{
			String serializedLogContext = (String)context.get(LOG_CONTEXT_KEY);
			if(String.isNotBlank(serializedLogContext))
			{
				LOG_Builder.hydrateContext(serializedLogContext);
			}
			else
			{
				LOG_Builder.setCorrelationId(correlationId);
			}
		}

		/**
		 * @description Dispatches a failed step result: consults the step's retry strategy first, then
		 * persists the categorised terminal failure unless the step was registered with
		 * continueOnError.
		 *
		 * @param execution The execution record being processed.
		 * @param context The current chain context.
		 * @param stepDefinition The failed step's persisted definition.
		 * @param result The failed StepResult.
		 * @param step The instantiated step, or null when instantiation failed.
		 * @param attemptNumber The 1-based attempt number that just failed.
		 *
		 * @return True when the chain halts here (a retry was scheduled or the terminal failure was
		 * persisted) and the caller must return immediately; false when continueOnError lets the
		 * chain continue past the failure.
		 */
		private Boolean haltChainForFailedResult
				(
						AsyncChainExecution__c execution,
						ChainContext context,
						DTO_StepDefinition stepDefinition,
						StepResult result,
						IF_Chain.Step step,
						Integer attemptNumber
				)
		{
			// The retry consult precedes the continueOnError dispatch, so a continued step only
			// continues on its final attempt. Resolved again post-work on purpose: for ApiStep the
			// strategy only materialises during work().
			UTIL_Retry.Strategy retryStrategy = resolveRetryStrategy(step);
			if(retryStrategy != null
					&& retryStrategy.shouldRetry(UTIL_Retry.newContext(attemptNumber - 1).withCustomData(result.error)))
			{
				scheduleRetry(execution, context, stepDefinition, retryStrategy, attemptNumber);
				return true;
			}

			if(stepDefinition.continueOnError != true)
			{
				execution.StepLog__c = serializeStepLog(persistedDefinitions);
				String failureCategory = retryStrategy != null && attemptNumber > 1
						? SEL_AsyncChainExecution.FAILURE_CATEGORY_RETRIES_EXHAUSTED
						: SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION;
				handleStepFailure(execution, context, stepDefinition, result, failureCategory);
				return true;
			}

			return false;
		}

		/**
		 * @description Serializes the chain context and applies the size guards: a context over the
		 * configured cap fails the chain terminally; a context past 80% of the cap logs a warning.
		 *
		 * @param execution The execution record being processed.
		 * @param context The current chain context.
		 *
		 * @return The serialized context to persist, or null when the chain was failed for overflow
		 * (the caller exits immediately).
		 */
		private String serializeContextWithinLimit(AsyncChainExecution__c execution, ChainContext context)
		{
			String serializedContext = context.serialize();
			Integer contextSize = serializedContext.length();
			Integer warningThreshold = (Integer)(maxContextSize * 0.8);

			if(contextSize > maxContextSize)
			{
				markFailed(execution, 'Chain context overflow: ' + contextSize + ' / ' + maxContextSize
						+ ' characters. Store record IDs in context, not full SObject graphs.');
				return null;
			}

			if(contextSize > warningThreshold)
			{
				LOG_Builder.build().warn('Chain context approaching limit: ' + contextSize + ' / ' + maxContextSize + ' characters')
						.at(CLASS_NAME + '.ChainExecutor.execute')
						.forRecord(execution.Id)
						.emit();
			}

			return serializedContext;
		}

		/**
		 * @description Persists the step's progress through the fenced sparse update and signals the
		 * Finalizer to enqueue the next step. A stale run key skips both the write and the enqueue —
		 * the executor goes silent.
		 *
		 * @param execution The execution record carrying the progress values to persist.
		 * @param continuedFailureAppended Whether a continueOnError failure was accumulated this step,
		 * adding ErrorMessage__c to the write set.
		 */
		private void persistProgressAndChainNext(AsyncChainExecution__c execution, Boolean continuedFailureAppended)
		{
			List<SObjectField> progressFields = new List<SObjectField>
			{
					AsyncChainExecution__c.CompletedSteps__c,
					AsyncChainExecution__c.CurrentStepName__c,
					AsyncChainExecution__c.CurrentJobId__c,
					AsyncChainExecution__c.ContextData__c,
					AsyncChainExecution__c.StepLog__c
			};
			if(continuedFailureAppended)
			{
				progressFields.add(AsyncChainExecution__c.ErrorMessage__c);
			}

			if(findAuthorizedRun(execution.Id) == null)
			{
				return;
			}

			DML_Builder.newTransaction().systemModeInternal().doUpdate(buildSparseUpdate(execution, progressFields)).execute();
			shouldChainNext = true;
		}

		/**
		 * @description Finalizer callback that chains to the next step on success — or, when
		 * scheduleRetry signalled a retry, re-enqueues this executor at the same step index, applying
		 * the strategy's backoff delay to that one enqueue only (the rebuilt executor carries a
		 * delay-free options baton with the bumped stack depth, so post-recovery hops run without
		 * added delay) — or marks the chain as Failed on unhandled exception (governor limits,
		 * platform errors). Prevents zombie chains stuck in Running status. Finalizers receive
		 * fresh governor limits from the platform.
		 * Enqueue failures are transient (async budget exhausted, queue rejection) and route to
		 * Stalled — awaiting recovery — while a Queueable crash routes to Failed: the classification
		 * is by call site, never by sniffing exception text.
		 *
		 * @param finalizerContext The Finalizer context provided by the platform.
		 */
		@SuppressWarnings('PMD.EmptyCatchBlock')
		public void execute(FinalizerContext finalizerContext)
		{
			if(finalizerContext.getResult() == ParentJobResult.SUCCESS && (shouldChainNext || retryScheduled))
			{
				try
				{
					if(simulateEnqueueFailure)
					{
						simulateEnqueueFailure = false;
						throw new UTIL_Exceptions.IllegalStateException('Simulated enqueue failure');
					}
					if(retryScheduled)
					{
						AsyncOptions retryOptions = new AsyncOptions();
						retryOptions.maximumQueueableStackDepth = persistedDefinitions.size() + 1 + RETRY_STACK_DEPTH_ALLOWANCE;
						retryOptions.minimumQueueableDelayInMinutes = retryDelayMinutes;
						// The backoff delay belongs to the retry enqueue ONLY. The constructor gets a
						// delay-free copy carrying just the bumped depth: those options become the baton
						// every subsequent hop re-uses, and a delay left on them would repeat on every
						// remaining hop of the chain.
						AsyncOptions carryForwardOptions = new AsyncOptions();
						carryForwardOptions.maximumQueueableStackDepth = retryOptions.maximumQueueableStackDepth;
						System.enqueueJob(buildSameIndexExecutor(carryForwardOptions), retryOptions);
						return;
					}
					ChainExecutor nextExecutor =
							new ChainExecutor(chainExecutionId, currentStepIndex + 1, maxSteps, maxContextSize, errorHandler, completionHandler, asyncOptions, capturedRunKey);
					System.enqueueJob(nextExecutor, asyncOptions);
				}
				catch(Exception enqueueError)
				{
					markChainStalledFromFinalizer(chainExecutionId, 'Finalizer failed to enqueue next step: ' + enqueueError.getMessage());
				}
			}
			else if(finalizerContext.getResult() == ParentJobResult.SUCCESS && pendingHandler != null)
			{
				try
				{
					if(simulateEnqueueFailure)
					{
						simulateEnqueueFailure = false;
						throw new UTIL_Exceptions.IllegalStateException('Simulated handler enqueue failure');
					}
					System.enqueueJob(pendingHandler);
				}
				catch(Exception enqueueError)
				{
					markChainStalledFromFinalizer(chainExecutionId, 'Finalizer failed to enqueue handler: ' + enqueueError.getMessage());
				}
			}
			else if(finalizerContext.getResult() == ParentJobResult.UNHANDLED_EXCEPTION)
			{
				Exception unhandledError = finalizerContext.getException();
				String errorMessage = unhandledError != null ? unhandledError.getMessage() : 'Unknown unhandled exception';
				markChainFailedFromFinalizer(chainExecutionId, 'Queueable crashed (unhandled exception): ' + errorMessage);
			}
		}

		/**
		 * @description Marks a chain as Failed from the Finalizer context. Wraps DML in try/catch
		 * because the Finalizer is the last recovery point — if DML fails (e.g., row lock), the
		 * error is logged but the Finalizer must not throw. Skips the write entirely when the run
		 * key no longer matches: a re-driven chain must not be failed by its stale predecessor.
		 *
		 * @param executionId The chain execution record ID.
		 * @param errorMessage The failure message.
		 */
		@TestVisible
		@SuppressWarnings('PMD.EmptyCatchBlock')
		private void markChainFailedFromFinalizer(Id executionId, String errorMessage)
		{
			// Fence re-read outside the try: it must stay non-throwing (system-mode selector; a missing row reads null) — a throw would escape the Finalizer's no-throw contract.
			AsyncChainExecution__c current = findAuthorizedRun(executionId);
			if(current == null || SEL_AsyncChainExecution.STATUS_ABORTED.equals(current.Status__c))
			{
				return;
			}

			try
			{
				AsyncChainExecution__c execution = new AsyncChainExecution__c
						(
								Id = executionId,
								Status__c = SEL_AsyncChainExecution.STATUS_FAILED,
								FailureCategory__c = SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION,
								ErrorMessage__c = UTIL_String.abbreviate(errorMessage, AsyncChainExecution__c.ErrorMessage__c),
								CompletedAt__c = Datetime.now(),
								ActiveDeduplicationKey__c = null
						);
				DML_Builder.newTransaction().systemModeInternal().doUpdate(execution).execute();
			}
			catch(Exception dmlError)
			{
				LOG_Builder.build().error('Finalizer DML failed: ' + dmlError.getMessage() + ' | Original: ' + errorMessage)
						.at(CLASS_NAME + '.ChainExecutor.Finalizer')
						.forRecord(executionId)
						.emit();
				return;
			}

			emitTerminalLog(LoggingLevel.ERROR, errorMessage, CLASS_NAME + '.ChainExecutor.Finalizer', executionId);
		}

		/**
		 * @description Marks a chain as Stalled from the Finalizer context after a transient enqueue
		 * failure, by delegating to the shared markStalledAndNotify sequence with this executor's
		 * captured run key as the fence: a stale executor's Finalizer must not mark anything, and
		 * the notification it passes along is this executor's own onError handler. Wraps the
		 * delegation in try/catch because the Finalizer is the last recovery point — if the stall
		 * write fails, the error is logged, the notification is skipped, and the Finalizer must
		 * not throw.
		 *
		 * @param executionId The chain execution record ID.
		 * @param errorMessage The stall reason.
		 */
		@TestVisible
		private void markChainStalledFromFinalizer(Id executionId, String errorMessage)
		{
			try
			{
				markStalledAndNotify(executionId, errorMessage, errorHandler, true, capturedRunKey);
			}
			catch(Exception dmlError)
			{
				LOG_Builder.build().error('Finalizer stall DML failed: ' + dmlError.getMessage() + ' | Original: ' + errorMessage)
						.at(CLASS_NAME + '.ChainExecutor.Finalizer')
						.forRecord(executionId)
						.emit();
			}
		}

		/**
		 * @description Handles a step failure by updating the execution record and optionally running the error handler.
		 *
		 * @param execution The AsyncChainExecution__c record to update.
		 * @param context The current chain context.
		 * @param stepDefinition The definition of the step that failed.
		 * @param result The failed StepResult.
		 * @param failureCategory The SEL_AsyncChainExecution.FAILURE_CATEGORY_* value recorded on the
		 * execution for this terminal transition: FAILURE_CATEGORY_RETRIES_EXHAUSTED when a retrying
		 * step's attempt budget ran out (attempt > 1), FAILURE_CATEGORY_STEP_EXCEPTION for a failure
		 * that consumed no retry budget.
		 */
		private void handleStepFailure(AsyncChainExecution__c execution, ChainContext context, DTO_StepDefinition stepDefinition, StepResult result, String failureCategory)
		{
			String failedStepName = String.isNotBlank(stepDefinition.stepName) ? stepDefinition.stepName : stepDefinition.className;
			execution.CurrentStepName__c = UTIL_String.abbreviate(failedStepName, AsyncChainExecution__c.CurrentStepName__c);
			execution.Status__c = SEL_AsyncChainExecution.STATUS_FAILED;
			execution.FailureCategory__c = failureCategory;
			execution.ErrorMessage__c = UTIL_String.abbreviate(result.message, AsyncChainExecution__c.ErrorMessage__c);
			execution.CompletedAt__c = Datetime.now();
			execution.ActiveDeduplicationKey__c = null;
			setDuration(execution);
			execution.ContextData__c = UTIL_String.abbreviate(context.serialize(), AsyncChainExecution__c.ContextData__c);

			List<SObjectField> failureFields = new List<SObjectField>
			{
					AsyncChainExecution__c.CurrentStepName__c,
					AsyncChainExecution__c.Status__c,
					AsyncChainExecution__c.FailureCategory__c,
					AsyncChainExecution__c.ErrorMessage__c,
					AsyncChainExecution__c.CompletedAt__c,
					AsyncChainExecution__c.DurationMs__c,
					AsyncChainExecution__c.ContextData__c,
					AsyncChainExecution__c.StepLog__c,
					AsyncChainExecution__c.ActiveDeduplicationKey__c
			};

			AsyncChainExecution__c current = findAuthorizedRun(execution.Id);
			if(current == null || SEL_AsyncChainExecution.STATUS_ABORTED.equals(current.Status__c))
			{
				return;
			}

			DML_Builder.newTransaction().systemModeInternal().doUpdate(buildSparseUpdate(execution, failureFields)).execute();
			emitTerminalLog(LoggingLevel.ERROR, 'Chain failed: ' + result.message, CLASS_NAME + '.ChainExecutor.handleStepFailure', execution.Id);

			if(errorHandler != null)
			{
				pendingHandler = new HandlerExecutor(execution.Id, context, errorHandler, SEL_AsyncChainExecution.STATUS_FAILED, result.message, capturedRunKey);
			}
		}

		/**
		 * @description Handles successful chain completion by updating the execution record
		 * and optionally running the completion handler.
		 *
		 * @param execution The AsyncChainExecution__c record to update.
		 * @param context The current chain context.
		 */
		private void handleChainCompletion(AsyncChainExecution__c execution, ChainContext context)
		{
			execution.Status__c = SEL_AsyncChainExecution.STATUS_COMPLETED;
			execution.CompletedAt__c = Datetime.now();
			execution.ActiveDeduplicationKey__c = null;
			setDuration(execution);
			execution.ContextData__c = UTIL_String.abbreviate(context.serialize(), AsyncChainExecution__c.ContextData__c);

			List<SObjectField> completionFields = new List<SObjectField>
			{
					AsyncChainExecution__c.CompletedSteps__c,
					AsyncChainExecution__c.CurrentStepName__c,
					AsyncChainExecution__c.Status__c,
					AsyncChainExecution__c.ErrorMessage__c,
					AsyncChainExecution__c.CompletedAt__c,
					AsyncChainExecution__c.DurationMs__c,
					AsyncChainExecution__c.ContextData__c,
					AsyncChainExecution__c.StepLog__c,
					AsyncChainExecution__c.ActiveDeduplicationKey__c
			};

			AsyncChainExecution__c current = findAuthorizedRun(execution.Id);
			if(current == null || SEL_AsyncChainExecution.STATUS_ABORTED.equals(current.Status__c))
			{
				return;
			}

			DML_Builder.newTransaction().systemModeInternal().doUpdate(buildSparseUpdate(execution, completionFields)).execute();
			emitTerminalLog(LoggingLevel.INFO, 'Chain completed: ' + execution.ChainName__c, CLASS_NAME + '.ChainExecutor.handleChainCompletion', execution.Id);
			logChainPerformance(execution);

			if(completionHandler != null)
			{
				pendingHandler = new HandlerExecutor(execution.Id, context, completionHandler, SEL_AsyncChainExecution.STATUS_COMPLETED, null, capturedRunKey);
			}
		}

		/**
		 * @description Marks the execution as failed with the given message.
		 *
		 * @param execution The AsyncChainExecution__c record to update.
		 * @param message The failure message to record.
		 */
		private void markFailed(AsyncChainExecution__c execution, String message)
		{
			AsyncChainExecution__c current = findAuthorizedRun(execution.Id);
			if(current == null || SEL_AsyncChainExecution.STATUS_ABORTED.equals(current.Status__c))
			{
				return;
			}

			execution.Status__c = SEL_AsyncChainExecution.STATUS_FAILED;
			execution.FailureCategory__c = SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION;
			execution.ErrorMessage__c = UTIL_String.abbreviate(message, AsyncChainExecution__c.ErrorMessage__c);
			execution.CompletedAt__c = Datetime.now();
			execution.ActiveDeduplicationKey__c = null;
			setDuration(execution);

			List<SObjectField> overflowFailureFields = new List<SObjectField>
			{
					AsyncChainExecution__c.CompletedSteps__c,
					AsyncChainExecution__c.CurrentStepName__c,
					AsyncChainExecution__c.Status__c,
					AsyncChainExecution__c.FailureCategory__c,
					AsyncChainExecution__c.ErrorMessage__c,
					AsyncChainExecution__c.CompletedAt__c,
					AsyncChainExecution__c.DurationMs__c,
					AsyncChainExecution__c.ActiveDeduplicationKey__c
			};

			DML_Builder.newTransaction().systemModeInternal().doUpdate(buildSparseUpdate(execution, overflowFailureFields)).execute();
			emitTerminalLog(LoggingLevel.ERROR, 'Chain failed: ' + message, CLASS_NAME + '.ChainExecutor.markFailed', execution.Id);
			logChainPerformance(execution);
		}

		/**
		 * @description Marks the execution as aborted with the given message and logs a warning.
		 * Fenced like every other persist site: a stale-key executor (a re-driven chain's
		 * superseded predecessor) waking into the kill-switch path must not stamp a terminal abort
		 * over the current run. The fence runs before the field mutations, so a fenced call leaves
		 * the in-memory record untouched as well as the persisted one. Kill-switch behaviour for
		 * the authorized executor is unchanged.
		 * Deliberately does not refuse an already-Aborted row: the kill switch re-stamping an
		 * operator abort is idempotent on the terminal status, and its category is the stronger
		 * operational signal.
		 *
		 * @param execution The AsyncChainExecution__c record to update.
		 * @param message The abort reason to record.
		 */
		@TestVisible
		private void markAborted(AsyncChainExecution__c execution, String message)
		{
			if(findAuthorizedRun(execution.Id) == null)
			{
				return;
			}

			execution.Status__c = SEL_AsyncChainExecution.STATUS_ABORTED;
			execution.FailureCategory__c = SEL_AsyncChainExecution.FAILURE_CATEGORY_KILL_SWITCH;
			execution.ErrorMessage__c = UTIL_String.abbreviate(message, AsyncChainExecution__c.ErrorMessage__c);
			execution.CompletedAt__c = Datetime.now();
			execution.ActiveDeduplicationKey__c = null;
			setDuration(execution);

			List<SObjectField> abortFields = new List<SObjectField>
			{
					AsyncChainExecution__c.Status__c,
					AsyncChainExecution__c.FailureCategory__c,
					AsyncChainExecution__c.ErrorMessage__c,
					AsyncChainExecution__c.CompletedAt__c,
					AsyncChainExecution__c.DurationMs__c,
					AsyncChainExecution__c.ActiveDeduplicationKey__c
			};

			DML_Builder.newTransaction().systemModeInternal().doUpdate(buildSparseUpdate(execution, abortFields)).execute();

			emitTerminalLog(LoggingLevel.WARN, 'Chain aborted: ' + message, CLASS_NAME + '.ChainExecutor.markAborted', execution.Id);
			logChainPerformance(execution);
		}

		/**
		 * @description Computes and sets the total chain duration from StartedAt to now.
		 *
		 * @param execution The execution record to update.
		 */
		private void setDuration(AsyncChainExecution__c execution)
		{
			if(execution.StartedAt__c != null)
			{
				execution.DurationMs__c = Datetime.now().getTime() - execution.StartedAt__c.getTime();
			}
		}

		/**
		 * @description Resolves the step's retry strategy, if any. Only ChainStep subclasses expose
		 * createRetryStrategy(); a pure IF_Chain.Step (or a step that failed to instantiate) has none.
		 *
		 * @param step The instantiated step, or null when instantiation failed.
		 *
		 * @return The step's retry strategy, or null for no retry.
		 */
		private UTIL_Retry.Strategy resolveRetryStrategy(IF_Chain.Step step)
		{
			return step instanceof ChainStep ? ((ChainStep)step).createRetryStrategy() : null;
		}

		/**
		 * @description Persists the re-attempt state for a scheduled retry and signals the Finalizer
		 * to re-enqueue this executor at the same step index. A fenced persist site: the write is
		 * skipped entirely when the run key no longer matches, and the sparse update carries only the
		 * step log and context data — never the run key.
		 *
		 * @param execution The AsyncChainExecution__c record to update.
		 * @param context The current chain context.
		 * @param stepDefinition The definition of the step being re-attempted.
		 * @param retryStrategy The step's retry strategy, consulted for the backoff delay.
		 * @param attemptNumber The 1-based attempt number that just failed.
		 */
		private void scheduleRetry
				(
						AsyncChainExecution__c execution,
						ChainContext context,
						DTO_StepDefinition stepDefinition,
						UTIL_Retry.Strategy retryStrategy,
						Integer attemptNumber
				)
		{
			stepDefinition.attempt = attemptNumber + 1;
			stepDefinition.success = null; // being re-attempted: resume markers stay truthful
			execution.StepLog__c = serializeStepLog(persistedDefinitions);
			execution.ContextData__c = UTIL_String.abbreviate(context.serialize(), AsyncChainExecution__c.ContextData__c);
			List<SObjectField> retryFields = new List<SObjectField>
			{
					AsyncChainExecution__c.StepLog__c,
					AsyncChainExecution__c.ContextData__c
			};
			if(findAuthorizedRun(execution.Id) == null)
			{
				return;
			}
			DML_Builder.newTransaction().systemModeInternal().doUpdate(buildSparseUpdate(execution, retryFields)).execute();
			retryDelayMinutes = clampBackoffToEnqueueWindow(retryStrategy.calculateBackoff(UTIL_Retry.newContext(attemptNumber - 1)));
			retryScheduled = true;
			LOG_Builder.build()
					.warn('Chain step retry scheduled: attempt ' + stepDefinition.attempt + ' at step index ' + currentStepIndex + ', delay ' + retryDelayMinutes + ' minute(s)')
					.at(CLASS_NAME + '.ChainExecutor.scheduleRetry')
					.forRecord(execution.Id)
					.emit();
		}

		/**
		 * @description Builds the executor for a scheduled retry: the SAME step index and the SAME
		 * captured run key as this executor — a retry link re-runs the same logical run and is not a
		 * run-key rotation point. Mirrors the next-step executor construction otherwise.
		 *
		 * The options passed HERE are deliberately not the delayed retry options: the constructor's
		 * options become the baton every subsequent hop inherits and re-uses for its own next-step
		 * enqueue, so they carry only the bumped stack depth. The backoff delay lives solely on the
		 * AsyncOptions handed to System.enqueueJob for the retry link itself — left on the baton, the
		 * delay would repeat on every remaining hop of the chain.
		 *
		 * @param carryForwardOptions The delay-free AsyncOptions the rebuilt executor carries forward
		 * for all subsequent enqueues (bumped stack depth only).
		 *
		 * @return The same-index executor to enqueue.
		 */
		private ChainExecutor buildSameIndexExecutor(AsyncOptions carryForwardOptions)
		{
			return new ChainExecutor(chainExecutionId, currentStepIndex, maxSteps, maxContextSize, errorHandler, completionHandler, carryForwardOptions, capturedRunKey);
		}

		/**
		 * @description Re-reads the execution record and returns the fresh row when this executor
		 * still owns the record's current run — the captured run key matches the persisted one. A
		 * mismatch means another actor (a watchdog re-drive) has claimed the record, and a missing
		 * record also revokes authorization: both return null, and the caller must skip its persist
		 * and go silent. Terminal write sites take their aborted-row refusal from this fresh row,
		 * never from in-memory state mutated in the same method.
		 *
		 * @param executionId The chain execution record ID.
		 *
		 * @return The freshly-read record while this executor owns the run; null otherwise.
		 */
		private AsyncChainExecution__c findAuthorizedRun(Id executionId)
		{
			AsyncChainExecution__c current = (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(executionId);
			return current != null && capturedRunKey == current.RunKey__c ? current : null; // null == null passes (upgrade-safe)
		}

		/**
		 * @description Emits a chain-level performance log if performance logging is enabled and the
		 * total chain duration exceeds the configured threshold. Uses LOG_Engine.logPerformance()
		 * which respects LogSetting__c.EnablePerformanceLogging__c and PerformanceThresholdMs__c.
		 *
		 * @param execution The execution record with DurationMs__c set.
		 */
		private void logChainPerformance(AsyncChainExecution__c execution)
		{
			Long duration = execution.DurationMs__c != null ? execution.DurationMs__c.longValue() : 0;

			String summary = 'Chain ' + execution.ChainName__c + ' ' + execution.Status__c
					+ ': ' + (Integer)execution.CompletedSteps__c + '/' + (Integer)execution.TotalSteps__c
					+ ' steps in ' + duration + 'ms (wall-clock)';

			LOG_Engine.logPerformance(
					summary,
					null,
					CLASS_NAME + '.ChainExecutor',
					duration
			);
		}

		/**
		 * @description Appends a non-fatal step failure summary to ErrorMessage for admin visibility.
		 * Called when a step with continueOnError fails but the chain continues.
		 *
		 * @param execution The execution record to update.
		 * @param stepName The name of the step that failed.
		 * @param failureMessage The failure reason.
		 */
		private void appendContinuedFailure(AsyncChainExecution__c execution, String stepName, String failureMessage)
		{
			String entry = stepName + ': ' + failureMessage;
			String combined = String.isBlank(execution.ErrorMessage__c)
					? 'Non-fatal step failures: ' + entry
					: execution.ErrorMessage__c + '; ' + entry;
			execution.ErrorMessage__c = UTIL_String.abbreviate(combined, AsyncChainExecution__c.ErrorMessage__c);
		}

	}

	/**
	 * @description Lightweight Queueable that executes a completion or error handler in its own
	 * transaction, guaranteeing governor limit isolation from the step that triggered it.
	 * Prevents CalloutException when a handler needs to make HTTP callouts after a step did DML.
	 */
	@TestVisible
	private inherited sharing class HandlerExecutor implements Queueable, Database.AllowsCallouts, Finalizer
	{
		private final Id executionId;
		private final ChainContext context;
		private final DTO_StepDefinition handlerDefinition;
		private final String expectedStatus;
		private final String originalErrorMessage;
		private final String capturedRunKey;

		/**
		 * @description Constructs a HandlerExecutor.
		 *
		 * @param executionId The chain execution record ID.
		 * @param context The chain context to pass to the handler.
		 * @param handlerDefinition The handler step definition.
		 * @param expectedStatus The status to set if the handler succeeds.
		 * @param originalErrorMessage The original error message (for error handlers), null for completion handlers.
		 * @param capturedRunKey The run key captured at enqueue time, or null for legacy executions.
		 */
		@TestVisible
		private HandlerExecutor
				(
						Id executionId,
						ChainContext context,
						DTO_StepDefinition handlerDefinition,
						String expectedStatus,
						String originalErrorMessage,
						String capturedRunKey
				)
		{
			this.executionId = executionId;
			this.context = context;
			this.handlerDefinition = handlerDefinition;
			this.expectedStatus = expectedStatus;
			this.originalErrorMessage = originalErrorMessage;
			this.capturedRunKey = capturedRunKey;
		}

		/**
		 * @description Runs the persisted completion or error handler. Fenced on entry via
		 * findAuthorizedRun (a stale-run-key executor logs the skip and does nothing), it runs the
		 * handler step, then writes the expected status back on success. A failed handler
		 * escalates the record to Failed — except a stalled onError notification, whose failure
		 * is only logged so the recoverable Stalled record stays untouched. The write-back is
		 * fenced again immediately before the DML.
		 *
		 * @param queueableContext The Queueable context provided by the platform.
		 */
		public void execute(QueueableContext queueableContext)
		{
			System.attachFinalizer(this);

			if(findAuthorizedRun(executionId) == null)
			{
				LOG_Builder.build().warn('Chain handler skipped: stale run key (fenced)')
						.at(CLASS_NAME + '.HandlerExecutor.execute')
						.forRecord(executionId)
						.emit();
				return;
			}

			if(simulateHandlerCrash)
			{
				simulateHandlerCrash = false;
				throw new UTIL_Exceptions.IllegalStateException('Simulated handler crash');
			}

			StepResult result;

			try
			{
				IF_Chain.Step handler = instantiateStep(handlerDefinition);
				result = handler.work(context);
			}
			catch(Exception handlerError)
			{
				result = failed(handlerError);
			}

			AsyncChainExecution__c execution = new AsyncChainExecution__c(Id = executionId);
			execution.ContextData__c = UTIL_String.abbreviate(context.serialize(), AsyncChainExecution__c.ContextData__c);

			String escalationMessage = null;

			if(result.success)
			{
				execution.Status__c = expectedStatus;
				execution.ErrorMessage__c = UTIL_String.abbreviate(originalErrorMessage, AsyncChainExecution__c.ErrorMessage__c);
			}
			else if(expectedStatus == SEL_AsyncChainExecution.STATUS_STALLED)
			{
				// A stalled onError notification is a courtesy, not chain work: a broken handler must not
				// escalate the recoverable Stalled record to terminal Failed, nor overwrite the context a
				// re-drive will rehydrate from, so the failure is logged and the record is left untouched.
				LOG_Builder.build().error('Stalled onError handler failed: ' + result.message + ' | Stall reason: ' + originalErrorMessage)
						.at(CLASS_NAME + '.HandlerExecutor.execute')
						.forRecord(executionId)
						.emit();
				return;
			}
			else
			{
				escalationMessage = String.isNotBlank(originalErrorMessage)
						? originalErrorMessage + '; Handler failed: ' + result.message
						: 'Handler failed: ' + result.message;
				execution.Status__c = SEL_AsyncChainExecution.STATUS_FAILED;
				execution.ErrorMessage__c = UTIL_String.abbreviate(escalationMessage, AsyncChainExecution__c.ErrorMessage__c);
			}

			// A terminal write-back (Completed, or the Failed escalation) releases the deduplication
			// key in the same DML. A successful stalled onError notification writes Stalled back and
			// must leave the held key in place: a stalled chain is still the key's active run, so a
			// same-key start keeps landing on it instead of opening a duplicate.
			// In-version this clearing is null-over-null (the terminal sites have already cleared);
			// it is kept as upgrade-straddle protection — a chain whose terminal write ran
			// pre-upgrade code releases its leftover key here — and must not be removed on the
			// strength of green tests: no single-version test can observe it.
			if(execution.Status__c != SEL_AsyncChainExecution.STATUS_STALLED)
			{
				execution.ActiveDeduplicationKey__c = null;
			}

			AsyncChainExecution__c current = findAuthorizedRun(executionId);
			if(current == null || SEL_AsyncChainExecution.STATUS_ABORTED.equals(current.Status__c))
			{
				return;
			}

			DML_Builder.newTransaction().systemModeInternal().doUpdate(execution).execute();

			if(escalationMessage != null)
			{
				emitTerminalLog(LoggingLevel.ERROR, 'Chain failed: ' + escalationMessage, CLASS_NAME + '.HandlerExecutor.execute', executionId);
			}
		}

		/**
		 * @description Finalizer callback covering the handler's own crash: on UNHANDLED_EXCEPTION
		 * (governor limits, platform errors) it delegates to markHandlerFailed, which fences on
		 * the run key, leaves a recoverable Stalled record untouched, and wraps its DML in
		 * try/catch — the Finalizer is the last recovery point and must not throw.
		 *
		 * @param finalizerContext The Finalizer context provided by the platform.
		 */
		public void execute(FinalizerContext finalizerContext)
		{
			if(finalizerContext.getResult() == ParentJobResult.UNHANDLED_EXCEPTION)
			{
				Exception unhandledError = finalizerContext.getException();
				String errorMessage = 'Handler crashed: ' + (unhandledError != null ? unhandledError.getMessage() : 'Unknown');
				markHandlerFailed(executionId, errorMessage);
			}
		}

		/**
		 * @description Marks a chain as Failed from the HandlerExecutor Finalizer. Wraps DML in
		 * try/catch. Skips the write entirely when the run key no longer matches: a re-driven
		 * chain must not be failed by its stale predecessor. For a stalled onError notification
		 * (expectedStatus Stalled) the crash is only logged and the record stays untouched:
		 * Stalled is recoverable, and stamping Failed with a completion time would hide the
		 * chain from recovery. A completion-handler crash (expectedStatus Completed) escalates a
		 * Completed-bound chain to Failed and stamps the StepException failure category; an
		 * onError-handler crash writes no category, keeping the step's earlier one.
		 *
		 * @param handlerExecutionId The chain execution record ID.
		 * @param errorMessage The failure message.
		 */
		@TestVisible
		@SuppressWarnings('PMD.EmptyCatchBlock')
		private void markHandlerFailed(Id handlerExecutionId, String errorMessage)
		{
			AsyncChainExecution__c current = findAuthorizedRun(handlerExecutionId);
			if(current == null || SEL_AsyncChainExecution.STATUS_ABORTED.equals(current.Status__c))
			{
				return;
			}

			if(expectedStatus == SEL_AsyncChainExecution.STATUS_STALLED)
			{
				LOG_Builder.build().error(errorMessage + ' | Chain left Stalled awaiting recovery')
						.at(CLASS_NAME + '.HandlerExecutor.Finalizer')
						.forRecord(handlerExecutionId)
						.emit();
				return;
			}

			try
			{
				AsyncChainExecution__c execution = new AsyncChainExecution__c
						(
								Id = handlerExecutionId,
								Status__c = SEL_AsyncChainExecution.STATUS_FAILED,
								ErrorMessage__c = UTIL_String.abbreviate(errorMessage, AsyncChainExecution__c.ErrorMessage__c),
								CompletedAt__c = Datetime.now(),
								ActiveDeduplicationKey__c = null
						);
				if(expectedStatus == SEL_AsyncChainExecution.STATUS_COMPLETED)
				{
					// A completion-handler crash flips a Completed-bound chain to Failed, so this
					// escalation stamps its own category. An onError notification write stays
					// category-free: the record keeps the step's earlier category.
					execution.FailureCategory__c = SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION;
				}
				DML_Builder.newTransaction().systemModeInternal().doUpdate(execution).execute();
				emitTerminalLog(LoggingLevel.ERROR, errorMessage, CLASS_NAME + '.HandlerExecutor.Finalizer', handlerExecutionId);
			}
			catch(Exception dmlError)
			{
				LOG_Builder.build().error('Handler Finalizer DML failed: ' + dmlError.getMessage())
						.at(CLASS_NAME + '.HandlerExecutor.Finalizer')
						.forRecord(handlerExecutionId)
						.emit();
			}
		}

		/**
		 * @description Re-reads the execution record and returns the fresh row when this handler
		 * executor still owns the record's current run — the captured run key matches the persisted
		 * one. A mismatch means another actor (a watchdog re-drive) has claimed the record, and a
		 * missing record also revokes authorization: both return null, and the caller must skip its
		 * persist and go silent. Terminal write sites take their aborted-row refusal from this fresh
		 * row, never from in-memory state mutated in the same method.
		 *
		 * @param executionId The chain execution record ID.
		 *
		 * @return The freshly-read record while this executor owns the run; null otherwise.
		 */
		private AsyncChainExecution__c findAuthorizedRun(Id executionId)
		{
			AsyncChainExecution__c current = (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(executionId);
			return current != null && capturedRunKey == current.RunKey__c ? current : null; // null == null passes (upgrade-safe)
		}
	}

	/**
	 * @description Sweeps for chains that look abandoned — Running or Stalled with no activity for
	 * longer than the threshold — and decides each candidate's fate per sweepCandidate: the
	 * async-budget gate, the terminal-status gate, then the liveness-gated recovery decision
	 * (degrade to detect-mark-notify, skip a live executor, or auto-re-drive a provably dead one).
	 * Invoked by the SCHED_ChainWatchdog scheduled job; the sweep is the recovery authority, so its
	 * writes are not fenced by a captured run key.
	 *
	 * The selector's rows are candidates, not proof of a dead executor: only the AsyncApexJob
	 * liveness probe separates a genuinely dead chain from a slow-but-alive one, and only a dead
	 * proof re-drives. The stale threshold is still load-bearing (see sweepCandidate) — configure
	 * it generously, longer than the longest legitimate step.
	 *
	 * The effective batch is clamped to WATCHDOG_SWEEP_BATCH_CEILING before the selector runs, and
	 * the loop proves the per-candidate query reserve before each candidate's decision legs run —
	 * a candidate costs up to two queries, so a batch the clamp admits can still outrun the
	 * transaction's query budget. When the reserve cannot be proven, the remaining tail is parked
	 * (see parkRemainingCandidates) and the sweep stops; parked and beyond-ceiling candidates alike
	 * stay in place for a later sweep.
	 *
	 * @param thresholdMinutes Minutes since the last modification before a chain becomes a candidate.
	 * @param batchSize Maximum number of chains inspected per sweep; values above 50 are clamped to 50.
	 */
	public static void runWatchdogSweep(Integer thresholdMinutes, Integer batchSize)
	{
		Integer effectiveBatchSize = batchSize == null ? null : Math.min(batchSize, WATCHDOG_SWEEP_BATCH_CEILING);
		List<AsyncChainExecution__c> staleCandidates = new SEL_AsyncChainExecution().findStaleRunning(thresholdMinutes, effectiveBatchSize);
		for(Integer index = 0; index < staleCandidates.size(); index++)
		{
			if(UTIL_Limits.soqlQueries().remaining() < WATCHDOG_CANDIDATE_QUERY_RESERVE)
			{
				parkRemainingCandidates(staleCandidates, index);
				return;
			}
			sweepCandidate(staleCandidates[index]);
		}
	}

	/**
	 * @description Parks the sweep's remaining tail when the per-candidate query-budget gate
	 * refuses to run another decision leg: each remaining candidate is parked with the
	 * query-budget reason (one fresh re-read and one update apiece) for as long as the query
	 * budget lasts, and any candidates beyond that are left completely untouched — still stale,
	 * still candidates — for a later sweep, exactly like chains beyond the batch ceiling.
	 *
	 * @param staleCandidates The sweep's full candidate list.
	 * @param firstParkedIndex The index of the first candidate the query-budget gate refused.
	 */
	private static void parkRemainingCandidates(List<AsyncChainExecution__c> staleCandidates, Integer firstParkedIndex)
	{
		for(Integer index = firstParkedIndex; index < staleCandidates.size(); index++)
		{
			if(UTIL_Limits.soqlQueries().isExhausted())
			{
				return;
			}
			parkWithReason(staleCandidates[index], WATCHDOG_PARKED_QUERY_BUDGET_REASON);
		}
	}

	/**
	 * @description Decides what the sweep does with one stale candidate, in fixed order: the
	 * async-budget gate, the terminal-status gate, then the liveness decision. (Before this method
	 * runs, the sweep loop has already proven the per-candidate query reserve — see
	 * runWatchdogSweep — so the legs below can afford their probe and fresh re-read.)
	 *
	 * The async-budget gate runs first, before any other decision: every action the sweep can take
	 * beyond parking — a stall notification, a re-drive's executor enqueue, an unrecoverable
	 * degrade's notification — costs a queueable slot, and an enqueue with none left raises an
	 * uncatchable LimitException that rolls back the whole sweep. The gate re-reads the live
	 * counter per candidate rather than once per sweep, because each enqueue spends budget
	 * mid-loop: a sweep can start with budget and legitimately park its tail. The one slot the
	 * gate proves is spent by whichever leg runs — never more than one enqueue per candidate.
	 *
	 * The terminal-status gate runs second: a candidate can reach Completed, Failed or Aborted
	 * between the selector's read and this decision, and the sweep must skip such a row entirely —
	 * no mark, no notification, no re-drive. The gate is enforced at each leg's fresh re-read (the
	 * shared mark sequence's unfenced terminal skip, and qualifiesForRedrive's recoverable-status
	 * check) rather than as an extra query here, so every leg re-checks at the last responsible
	 * moment and no leg can act on a terminal row.
	 *
	 * The liveness decision then routes on the stamped CurrentJobId__c:
	 * - No usable stamp (null, or text that is not a valid job id) means CANNOT-CHECK, never proof
	 *   of death: single-step chains never progress-write and pre-upgrade rows never stamped a job
	 *   id, so there is no correlation to probe. The sweep degrades to detect-mark-notify and
	 *   never re-drives what it cannot prove dead.
	 * - A live job means slow-but-alive: once the budget gates have passed, the sweep leaves the
	 *   row completely untouched — no double-drive, no mark — because duplicate execution of a
	 *   live chain is a worse defect than the stall it would fix. Under exhausted budget even a
	 *   live candidate is parked: probing and notifying both spend the very resources the gates
	 *   just proved absent.
	 * - A dead job, with budget already proven, auto-re-drives via redriveStalledChain. The whole
	 *   probe-and-re-drive leg runs behind the same per-chain try/log discipline as the mark leg —
	 *   see redriveWhenProvablyDead — so one broken row cannot abort the rest of the sweep.
	 *
	 * Residual the threshold carries: the stamped job id is the LAST progress writer's, which lags
	 * the live executor by one step, so the probe can read a dead predecessor while its successor
	 * still runs. The staleness threshold is load-bearing here — configured longer than the
	 * longest legitimate step, the one-step lag window can never look stale.
	 *
	 * @param stale The stale candidate returned by the selector.
	 */
	@TestVisible
	private static void sweepCandidate(AsyncChainExecution__c stale)
	{
		if(UTIL_Limits.queueableJobs().isExhausted())
		{
			parkWithReason(stale, WATCHDOG_PARKED_REASON);
			return;
		}
		if(!(stale.CurrentJobId__c instanceof Id))
		{
			markStalledFromWatchdog(stale, WATCHDOG_STALL_REASON, resolvePersistedErrorHandler(stale));
			return;
		}
		redriveWhenProvablyDead(stale);
	}

	/**
	 * @description Parks a candidate a budget gate refused: the row is routed through the shared
	 * mark sequence with the given parked reason and deliberately NO onError notification —
	 * notifying costs a queueable slot the async gate just proved absent (and with the query
	 * budget this low, any extra work only deepens the shortage). Parking is not a dead end: the
	 * row stays Stalled, which keeps it inside the selector's candidate population — but the park
	 * write itself refreshes LastModifiedDate, so the row re-enters candidacy only after it
	 * re-ages past the staleness threshold, not automatically on the very next sweep. Once it
	 * re-ages, a budget-rich sweep re-processes it, and the single-fire guard still suppresses
	 * re-notification because the row no longer transitions into Stalled.
	 *
	 * Residual: the parked reason is transient by design. ErrorMessage__c records only the LATEST
	 * sweep decision, so a later budget-rich sweep overwrites the parked reason with the stall
	 * reason, and a successful re-drive supersedes it with terminal state. Do not treat the field
	 * as a history — the log stream carries the sequence.
	 *
	 * @param stale The stale candidate a budget gate parked.
	 * @param reason The plain-language parked reason naming the exhausted budget.
	 */
	private static void parkWithReason(AsyncChainExecution__c stale, String reason)
	{
		markStalledFromWatchdog(stale, reason, null);
	}

	/**
	 * @description Probes one stamped candidate's executor liveness and re-drives it when provably
	 * dead, on behalf of the watchdog sweep — with the same per-chain failure isolation as the
	 * mark leg (markStalledFromWatchdog): catchable exceptions anywhere on the leg — the liveness
	 * probe's query, redriveStalledChain's rotation write and executor enqueue, the unrecoverable
	 * degrade's terminal write inside markRedriveCandidateFailed — are logged and swallowed per
	 * chain, so one broken row cannot abort the rest of the sweep. Governor limits, which no catch
	 * can intercept, are guarded by the sweep's batch clamp and its async- and query-budget gates
	 * instead.
	 *
	 * What each caught failure leaves behind is safe by construction: a failed probe or a failed
	 * rotation write leaves the candidate untouched and still stale, so a later sweep simply
	 * retries it. A failed executor enqueue AFTER the rotation write persisted leaves the chain
	 * Running under the rotated key with no live executor — the stamped CurrentJobId__c still
	 * probes dead, so the next sweep re-detects that shape and re-drives it. A failed terminal
	 * write in the unrecoverable degrade leaves the record on its pre-degrade key, and the degrade
	 * notification enqueued just before it carries the rotated key it captured, so that
	 * notification fences itself out instead of announcing a failure that never committed.
	 *
	 * @param stale The stamped stale candidate returned by the selector.
	 */
	private static void redriveWhenProvablyDead(AsyncChainExecution__c stale)
	{
		try
		{
			if(isExecutorLive(stale.CurrentJobId__c))
			{
				return;
			}
			redriveStalledChain(stale);
		}
		catch(Exception redriveError)
		{
			LOG_Builder.build().error('Watchdog re-drive failed: ' + redriveError.getMessage())
					.at(CLASS_NAME + '.redriveWhenProvablyDead')
					.forRecord(stale.Id)
					.emit();
		}
	}

	/**
	 * @description Reports whether the AsyncApexJob behind the given id still holds a live platform
	 * status — the liveness proof the watchdog's recovery decision gates on. True means the job's
	 * Status is one of the platform's pre-execution/executing set (Queued, Processing, Preparing,
	 * Holding); Completed, Aborted and Failed are dead.
	 *
	 * False means "no live proof for THIS job id", NOT proof the chain is dead: the record's stamped
	 * id is the LAST progress writer's job, which lags the live executor by one step, and
	 * single-step chains carry null. Callers deciding recovery must therefore treat a null jobId as
	 * CANNOT-CHECK (degrade, never re-drive) and pair any re-drive decision with a generous
	 * staleness threshold — longer than the longest legitimate step. A well-formed id that matches
	 * no AsyncApexJob row probes as no-row and is likewise treated as dead; because the framework
	 * stamps the id from its own executor context, that shape is reachable only through a manual
	 * edit of the stamp or the platform purging old AsyncApexJob rows — and in both cases re-drive
	 * is the correct outcome.
	 *
	 * @param asyncApexJobId The stamped executor job id to probe, or null when no progress write has stamped one.
	 *
	 * @return True when the job exists and holds a live status; false for a null id, an absent row, or a dead status.
	 */
	@TestVisible
	private static Boolean isExecutorLive(Id asyncApexJobId)
	{
		if(asyncApexJobId == null)
		{
			return false; // no correlation → cannot prove alive
		}
		AsyncApexJob job = (AsyncApexJob)new SEL_AsyncApexJob().findById(asyncApexJobId);
		return job != null && LIVE_JOB_STATUSES.contains(job.Status);
	}

	/**
	 * @description Routes one stale candidate through the shared markStalledAndNotify sequence on
	 * behalf of the watchdog sweep: no run-key fence (the sweep is the recovery authority), and the
	 * given reason and notification handler carried through unchanged — the budget gate parks with
	 * the parked reason and no handler, the mark path stalls with the sweep reason and the handler
	 * resolved from the candidate's persisted step log. Failures are logged and swallowed per
	 * chain, so a catchable exception on one broken row cannot abort the rest of the sweep;
	 * governor limits, which no catch can intercept, are guarded by the sweep's batch clamp and
	 * its async- and query-budget gates instead. Defensive note: this try protects only the call itself — the
	 * arguments at the call sites are evaluated BEFORE it, outside any per-chain protection, so
	 * every argument-producing helper (resolvePersistedErrorHandler and anything added later) must
	 * be contract-non-throwing in its own right: blank-guarded and catch-all, never trusting the
	 * candidate row's contents.
	 *
	 * @param stale The stale candidate returned by the selector.
	 * @param reason The stall reason to record on the candidate.
	 * @param notificationHandler The onError handler to notify once per stall transition, or null for none.
	 */
	private static void markStalledFromWatchdog(AsyncChainExecution__c stale, String reason, DTO_StepDefinition notificationHandler)
	{
		try
		{
			markStalledAndNotify(stale.Id, reason, notificationHandler, false, null);
		}
		catch(Exception dmlError)
		{
			LOG_Builder.build().error('Watchdog stall DML failed: ' + dmlError.getMessage() + ' | Original: ' + reason)
					.at(CLASS_NAME + '.runWatchdogSweep')
					.forRecord(stale.Id)
					.emit();
		}
	}

	/**
	 * @description Resolves a chain's onError handler definition from its persisted step log, for
	 * callers that hold only the record (the watchdog sweep) rather than live executor state. A
	 * blank or unparseable step log, or one without an error-handler entry, resolves to null — the
	 * stall itself must never fail because the notification cannot be resolved.
	 *
	 * @param execution The execution record carrying the persisted step log.
	 *
	 * @return The persisted error-handler definition, or null when none can be resolved.
	 */
	private static DTO_StepDefinition resolvePersistedErrorHandler(AsyncChainExecution__c execution)
	{
		return findPersistedErrorHandler(parseStepLog(execution.StepLog__c));
	}

	/**
	 * @description Deserializes a persisted StepLog__c document into its definition list without
	 * ever throwing: a blank or unparseable document yields null. The contract-non-throwing shape
	 * exists because parse results feed sweep argument positions evaluated outside any per-chain
	 * try, and a broken row must never abort the surrounding sweep.
	 *
	 * @param stepLogJson The raw StepLog__c document.
	 *
	 * @return The deserialized definition list (steps first, handlers last), or null when the
	 * document is blank or unreadable.
	 */
	private static List<DTO_StepDefinition> parseStepLog(String stepLogJson)
	{
		if(String.isBlank(stepLogJson))
		{
			return null;
		}

		try
		{
			return (List<DTO_StepDefinition>)JSON.deserialize(stepLogJson, List<DTO_StepDefinition>.class);
		}
		catch(Exception parseError)
		{
			return null;
		}
	}

	/**
	 * @description Finds the first persisted error-handler entry in a parsed definition list.
	 * Null-tolerant so it can sit directly on parseStepLog output in the sweep's non-throwing
	 * argument positions.
	 *
	 * @param persistedDefinitions The parsed definition list, or null when parsing failed.
	 *
	 * @return The error-handler definition, or null when none exists.
	 */
	private static DTO_StepDefinition findPersistedErrorHandler(List<DTO_StepDefinition> persistedDefinitions)
	{
		for(DTO_StepDefinition definition : persistedDefinitions ?? new List<DTO_StepDefinition>())
		{
			if(definition.isErrorHandler == true)
			{
				return definition;
			}
		}
		return null;
	}

	/**
	 * @description Finds the first persisted completion-handler entry in a parsed definition list.
	 * Null-tolerant, mirroring findPersistedErrorHandler.
	 *
	 * @param persistedDefinitions The parsed definition list, or null when parsing failed.
	 *
	 * @return The completion-handler definition, or null when none exists.
	 */
	private static DTO_StepDefinition findPersistedCompletionHandler(List<DTO_StepDefinition> persistedDefinitions)
	{
		for(DTO_StepDefinition definition : persistedDefinitions ?? new List<DTO_StepDefinition>())
		{
			if(definition.isCompletionHandler == true)
			{
				return definition;
			}
		}
		return null;
	}

	/**
	 * @description Re-drives one provably-dead re-drive candidate on behalf of the watchdog sweep:
	 * rotates RunKey__c (fencing any zombie executor that later wakes with the old key), sets the
	 * chain back to Running, and enqueues a rehydrated executor at the derived resume point under
	 * the new key. RunKey__c has exactly three writers — ChainBuilder.execute()'s initial stamp,
	 * this rotation, and markRedriveCandidateFailed's terminal-authoritative rotation — the sweep
	 * is the rotation authority; no executor write set ever carries the field (see
	 * buildSparseUpdate).
	 *
	 * Preconditions the caller owns: the liveness decision (Status__c alone is never proof of a
	 * dead executor — pair the selector candidacy with the AsyncApexJob probe) and the async-budget
	 * gate (the re-enqueue costs a queueable slot, so the budget must be checked before calling).
	 * The method still defensively re-reads the record and only proceeds when it still qualifies —
	 * Running or Stalled with the run key unchanged since the sweep's read, and no activity on the
	 * record newer than the sweep's view (see qualifiesForRedrive) — so a chain that completed,
	 * failed, aborted, was claimed by another actor, or demonstrably progressed in the meantime is
	 * never re-driven.
	 *
	 * The resume point comes from the persisted step markers, not CompletedSteps__c — see
	 * deriveResumeIndex for the exact re-attempt semantics and the legacy fallback. Steps and
	 * handlers are rehydrated from the persisted StepLog__c via the isErrorHandler /
	 * isCompletionHandler flags; the executor itself restores the ChainContext from ContextData__c
	 * when it wakes. A candidate whose step log cannot be rehydrated into a runnable chain is
	 * marked Failed with an actionable reason instead — see markRedriveCandidateFailed for why
	 * Failed, not Stalled, is the safe degrade.
	 *
	 * A recovered chain runs with the framework-default maxSteps and AsyncOptions: the
	 * builder-time overrides are not persisted, and the defaults are the safe envelope for a chain
	 * that already proved it can stall. The context cap is the one exception: the effective cap is
	 * the larger of the framework default and the persisted context's existing size, because a
	 * chain legitimately built with a larger builder-time cap must not deterministically overflow
	 * the moment recovery re-runs it under the default.
	 *
	 * If the re-enqueue itself fails after the rotation persisted, the chain is left Running under
	 * the new key with no live executor — exactly the shape the next sweep detects and re-drives:
	 * the stamped CurrentJobId__c is untouched by the rotation write set and still probes dead. The
	 * sweep-side catch (redriveWhenProvablyDead) logs that failure per chain and moves on, so the
	 * enqueue failure costs the sweep nothing beyond this one candidate's delay.
	 *
	 * Residual (bounded, self-limiting): the executor's persist fence re-reads before, not
	 * atomically with, its write — no FOR UPDATE — so a zombie's in-flight progress write can land
	 * just after the rotation commits and over-count CompletedSteps__c by one, once; the zombie's
	 * next entry check fences it for good. The resume derivation reads the step markers, not the
	 * count, so the over-count cannot shift the resume point except on legacy marker-less rows.
	 *
	 * @param execution The stale candidate as the sweep read it; its run key anchors the claim check.
	 */
	@TestVisible
	private static void redriveStalledChain(AsyncChainExecution__c execution)
	{
		AsyncChainExecution__c fresh = (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(execution.Id);
		if(!qualifiesForRedrive(fresh, execution))
		{
			return;
		}

		List<DTO_StepDefinition> persistedDefinitions = parseStepLog(fresh.StepLog__c);
		List<DTO_StepDefinition> stepEntries = filterStepEntries(persistedDefinitions ?? new List<DTO_StepDefinition>());
		Integer nextIndex = deriveResumeIndex(stepEntries, fresh.CompletedSteps__c);

		if(stepEntries.isEmpty() || nextIndex >= stepEntries.size())
		{
			markRedriveCandidateFailed(fresh, findPersistedErrorHandler(persistedDefinitions));
			return;
		}

		fresh.RunKey__c = UTIL_Random.randomUUID();
		fresh.Status__c = SEL_AsyncChainExecution.STATUS_RUNNING;
		List<SObjectField> redriveFields = new List<SObjectField>
		{
				AsyncChainExecution__c.RunKey__c,
				AsyncChainExecution__c.Status__c
		};
		DML_Builder.newTransaction().systemModeInternal().doUpdate(buildSparseUpdate(fresh, redriveFields)).execute();

		Integer effectiveMaxContextSize = Math.max(DEFAULT_MAX_CONTEXT_SIZE, fresh.ContextData__c?.length() ?? 0);
		AsyncOptions options = new AsyncOptions();
		options.maximumQueueableStackDepth = stepEntries.size() + 1;
		System.enqueueJob
				(
						new ChainExecutor
								(
										fresh.Id, nextIndex, DEFAULT_MAX_STEPS, effectiveMaxContextSize,
										findPersistedErrorHandler(persistedDefinitions),
										findPersistedCompletionHandler(persistedDefinitions),
										options, fresh.RunKey__c
								),
						options
				);

		LOG_Builder.build().warn('Chain re-driven by watchdog: run key rotated, executor re-enqueued at step index ' + nextIndex)
				.at(CLASS_NAME + '.redriveStalledChain')
				.forRecord(fresh.Id)
				.emit();
	}

	/**
	 * @description Derives the step index a re-driven executor resumes at, from the persisted step
	 * entries' runtime success markers: the first step entry whose marker is null was never
	 * attempted, and that is where recovery resumes. CompletedSteps__c cannot be the primary
	 * source because it counts successes only — after a continueOnError failure the count lags the
	 * true position, and indexing by it would replay a step that already ran.
	 *
	 * Re-attempt semantics, precisely: a step that failed and continued is NOT re-attempted by a
	 * re-drive — it was attempted and its marker says so (success == false); the first UNATTEMPTED
	 * step resumes. A step whose work committed but whose progress write never landed carries no
	 * marker, so it re-runs — the framework's existing at-least-once step semantics, not a new
	 * liability.
	 *
	 * A log carrying no marker on any step entry is the legacy shape (persisted before runtime
	 * markers, or a chain that never ran a step); with nothing to read, the derivation falls back
	 * to CompletedSteps__c. A log whose every entry carries a marker derives the entry count —
	 * every step was attempted, nothing can resume — which the caller's consistency check routes
	 * to the unrecoverable degrade, exactly as the CompletedSteps arithmetic always treated a
	 * fully-counted chain that never finalised.
	 *
	 * @param stepEntries The filtered chain-step entries from the persisted step log.
	 * @param completedSteps The persisted success count, used only by the legacy fallback.
	 *
	 * @return The zero-based resume index; equal to the entry count when nothing is resumable.
	 */
	private static Integer deriveResumeIndex(List<DTO_StepDefinition> stepEntries, Decimal completedSteps)
	{
		Boolean logCarriesMarkers = false;
		Integer firstUnattemptedIndex = -1;
		for(Integer index = 0; index < stepEntries.size(); index++)
		{
			if(stepEntries[index].success != null)
			{
				logCarriesMarkers = true;
			}
			else if(firstUnattemptedIndex == -1)
			{
				firstUnattemptedIndex = index;
			}
		}

		if(!logCarriesMarkers)
		{
			return completedSteps?.intValue() ?? 0;
		}
		return firstUnattemptedIndex == -1 ? stepEntries.size() : firstUnattemptedIndex;
	}

	/**
	 * @description Re-checks that a re-drive candidate still qualifies at the moment of the
	 * re-drive, against a fresh read (the shared fresh-re-read idiom): the record still exists,
	 * still holds a recoverable status (Running or Stalled), still carries the run key the sweep
	 * observed, and shows no activity newer than the sweep's candidate view. A changed key means
	 * another actor claimed the chain, a terminal status means it concurrently finished, and a
	 * LastModifiedDate newer than the sweep's read means something wrote the record after the
	 * sweep saw it — a demonstrably-alive executor mid-flight explains that, a dead one cannot —
	 * so none of those may be re-driven. The timestamp rejection is logged (the others stay
	 * silent, as before) and costs nothing: both timestamps are already in hand, and the skipped
	 * row simply waits for a later sweep to re-evaluate it against its refreshed age. Null keys
	 * compare equal for pre-upgrade rows (null == null passes), so a legacy chain qualifies and
	 * the re-drive stamps its first real key.
	 *
	 * @param fresh The freshly re-read execution record, or null when the record is gone.
	 * @param sweepView The candidate row as the sweep read it, carrying the observed run key and LastModifiedDate.
	 *
	 * @return True when the candidate may still be re-driven.
	 */
	private static Boolean qualifiesForRedrive(AsyncChainExecution__c fresh, AsyncChainExecution__c sweepView)
	{
		Boolean recoverableAndUnclaimed = fresh != null
				&& fresh.RunKey__c == sweepView.RunKey__c // null == null passes (upgrade-safe)
				&& (fresh.Status__c == SEL_AsyncChainExecution.STATUS_RUNNING
				|| fresh.Status__c == SEL_AsyncChainExecution.STATUS_STALLED);

		if(recoverableAndUnclaimed && hasNewerActivityThanSweepRead(fresh, sweepView))
		{
			LOG_Builder.build().warn('Watchdog re-drive skipped: the record changed after the sweep read it, so a live executor may be mid-flight')
					.at(CLASS_NAME + '.qualifiesForRedrive')
					.forRecord(fresh.Id)
					.emit();
			return false;
		}

		return recoverableAndUnclaimed;
	}

	/**
	 * @description Reports whether the fresh re-read carries activity newer than the sweep's
	 * candidate view: a LastModifiedDate strictly after the one the sweep read. Null-tolerant for
	 * views that never carried the field (a hand-built or mocked view), which yield false so the
	 * run-key and status checks alone decide.
	 *
	 * @param fresh The freshly re-read execution record.
	 * @param sweepView The candidate row as the sweep read it.
	 *
	 * @return True when the fresh read is provably newer than the sweep's view.
	 */
	private static Boolean hasNewerActivityThanSweepRead(AsyncChainExecution__c fresh, AsyncChainExecution__c sweepView)
	{
		return fresh.LastModifiedDate != null
				&& sweepView.LastModifiedDate != null
				&& fresh.LastModifiedDate > sweepView.LastModifiedDate;
	}

	/**
	 * @description Reports whether a status value is terminal — Completed, Failed or Aborted —
	 * mirroring ChainStatus.isTerminal() for internal callers that hold only the raw picklist
	 * value. The sweep's terminal-status gate uses this negative check on the unfenced mark path,
	 * where qualifiesForRedrive uses the positive recoverable check (Running or Stalled): the
	 * polarity difference is deliberate — an executor enqueue is higher-stakes than a stall write,
	 * so the re-drive leg additionally refuses statuses it does not recognise, while the mark leg
	 * refuses only what is provably finished.
	 *
	 * @param status The raw Status__c value from a fresh read.
	 *
	 * @return True when the status is Completed, Failed or Aborted.
	 */
	private static Boolean isTerminalStatus(String status)
	{
		return status == SEL_AsyncChainExecution.STATUS_COMPLETED
				|| status == SEL_AsyncChainExecution.STATUS_FAILED
				|| status == SEL_AsyncChainExecution.STATUS_ABORTED;
	}

	/**
	 * @description Emits a best-effort terminal-transition signal after a terminal chain write.
	 * Emission safety is owned by the channel and the logging engine, not by this call site:
	 * LogEntryEvent__e publishes immediately (zero DML-statement or row impact on the calling
	 * transaction), and LOG_Engine pre-checks the governing limits (canPublishImmediately),
	 * reroutes to an async job when they are exhausted, and wraps its dispatch so the logger never
	 * crashes the business transaction. Call strictly AFTER the terminal-status DML. ERROR-level
	 * signals pass LOG_Engine's threshold unconditionally; the INFO completion signal honours the
	 * configured LogLevelThreshold__c (live completion visibility needs threshold at or below INFO).
	 * If a future channel or hazard ever genuinely needs a call-site safety check, add it here,
	 * never at individual sites.
	 *
	 * @param level The signal level: INFO for Completed, WARN for Aborted, ERROR for Failed.
	 * @param message The log message.
	 * @param classMethod The emitting site in ClassName.method form.
	 * @param executionId The chain execution record the signal announces.
	 */
	private static void emitTerminalLog(LoggingLevel level, String message, String classMethod, Id executionId)
	{
		LOG_Builder.build(level.name(), message)
				.at(classMethod)
				.forRecord(executionId)
				.emit();
	}

	/**
	 * @description Marks a re-drive candidate whose persisted step log cannot be rehydrated
	 * (blank, unparseable, or inconsistent with the recorded progress) as terminally Failed with
	 * an actionable reason. Failed — not Stalled — is the safe degrade: the step log does not
	 * repair itself, so every future sweep would re-attempt the same impossible re-drive and
	 * re-park the row forever, silently, because a re-park of an already-Stalled row fires no
	 * notification. Failing loudly once puts the chain in front of an admin in the Chain Monitor
	 * instead.
	 *
	 * The degrade is terminal-authoritative: the write set rotates RunKey__c together with the
	 * terminal fields, so a zombie executor that later wakes with the pre-degrade key is fenced
	 * off the record and cannot overwrite the actionable Failed with its own late state. This is
	 * the third RunKey__c writer, beside ChainBuilder.execute()'s initial stamp and
	 * redriveStalledChain's rotation (see buildSparseUpdate).
	 *
	 * When the candidate's persisted step log resolves an onError handler, the degrade notifies
	 * then fails: the notification routes through the shared recovery-notification enqueue with
	 * the actionable reason, captured under the rotated key — so if the terminal write below then
	 * fails to land, the record keeps its old key and the enqueued notification fences itself out
	 * instead of announcing a failure that never committed. The enqueue spends the one queueable
	 * slot the sweep's budget gate proved, the slot a successful re-drive would have given its
	 * executor; delivery is at-least-once and the enqueue itself never throws (the shared
	 * machinery degrades to a log).
	 *
	 * @param execution The freshly re-read candidate that cannot be rehydrated.
	 * @param notificationHandler The persisted onError handler to notify, or null when none resolves.
	 */
	private static void markRedriveCandidateFailed(AsyncChainExecution__c execution, DTO_StepDefinition notificationHandler)
	{
		execution.RunKey__c = UTIL_Random.randomUUID();
		execution.Status__c = SEL_AsyncChainExecution.STATUS_FAILED;
		execution.FailureCategory__c = SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED;
		execution.ErrorMessage__c = UTIL_String.abbreviate(REDRIVE_UNRECOVERABLE_REASON, AsyncChainExecution__c.ErrorMessage__c);
		execution.CompletedAt__c = Datetime.now();
		execution.ActiveDeduplicationKey__c = null;
		if(execution.StartedAt__c != null)
		{
			execution.DurationMs__c = Datetime.now().getTime() - execution.StartedAt__c.getTime();
		}

		enqueueRecoveryErrorHandler(execution, REDRIVE_UNRECOVERABLE_REASON, notificationHandler, SEL_AsyncChainExecution.STATUS_FAILED);

		List<SObjectField> failureFields = new List<SObjectField>
		{
				AsyncChainExecution__c.RunKey__c,
				AsyncChainExecution__c.Status__c,
				AsyncChainExecution__c.FailureCategory__c,
				AsyncChainExecution__c.ErrorMessage__c,
				AsyncChainExecution__c.CompletedAt__c,
				AsyncChainExecution__c.DurationMs__c,
				AsyncChainExecution__c.ActiveDeduplicationKey__c
		};
		DML_Builder.newTransaction().systemModeInternal().doUpdate(buildSparseUpdate(execution, failureFields)).execute();

		emitTerminalLog(LoggingLevel.ERROR, REDRIVE_UNRECOVERABLE_REASON, CLASS_NAME + '.redriveStalledChain', execution.Id);
	}

	/**
	 * @description Marks a chain execution Aborted on an operator's request, with the full terminal
	 * bookkeeping of the executor's own abort path: OperatorAbort category, abbreviated reason,
	 * completion timestamp, duration, and the deduplication-key release in the same update. Refuses
	 * anything not currently Running or Stalled and reports the refusal to the caller instead of
	 * throwing — the Chain Monitor turns a false into its already-finished message. Reads through
	 * the monitoring selector path (sharing bypassed, method-scoped) so an operator can abort any
	 * chain the monitor shows; who may call this at all is decided by the feature-flag gate in
	 * CTRL_ChainMonitor, and Apex remains the enforcement point. The abort lands at the next step
	 * boundary: the running step finishes, every terminal write site then refuses the finished
	 * work's persist against the committed Aborted row. Emits exactly one WARN terminal signal,
	 * strictly after the DML, at its own site so operator aborts are distinguishable from
	 * kill-switch aborts. Does not touch RunKey__c: aborting is a status transition, not a
	 * rotation, and RunKey__c keeps its exactly-three writers.
	 *
	 * @param executionId The AsyncChainExecution__c record to abort.
	 * @param reason The operator-supplied reason, recorded on ErrorMessage__c (abbreviated).
	 *
	 * @return True when the terminal write committed; false when the row is missing or not abortable.
	 */
	public static Boolean abortExecution(Id executionId, String reason)
	{
		AsyncChainExecution__c execution = new SEL_AsyncChainExecution().findByIdForMonitoring(executionId);

		if(execution == null || !ABORTABLE_STATUSES.contains(execution.Status__c))
		{
			return false;
		}

		execution.Status__c = SEL_AsyncChainExecution.STATUS_ABORTED;
		execution.FailureCategory__c = SEL_AsyncChainExecution.FAILURE_CATEGORY_OPERATOR_ABORT;
		execution.ErrorMessage__c = UTIL_String.abbreviate(reason, AsyncChainExecution__c.ErrorMessage__c);
		execution.CompletedAt__c = Datetime.now();
		execution.ActiveDeduplicationKey__c = null;
		if(execution.StartedAt__c != null)
		{
			execution.DurationMs__c = Datetime.now().getTime() - execution.StartedAt__c.getTime();
		}

		List<SObjectField> abortFields = new List<SObjectField>
		{
				AsyncChainExecution__c.Status__c,
				AsyncChainExecution__c.FailureCategory__c,
				AsyncChainExecution__c.ErrorMessage__c,
				AsyncChainExecution__c.CompletedAt__c,
				AsyncChainExecution__c.DurationMs__c,
				AsyncChainExecution__c.ActiveDeduplicationKey__c
		};

		DML_Builder.newTransaction().systemModeInternal().doUpdate(buildSparseUpdate(execution, abortFields)).execute();

		emitTerminalLog(LoggingLevel.WARN, 'Chain aborted by operator: ' + reason, CLASS_NAME + '.abortExecution', executionId);

		return true;
	}

	/**
	 * @description The one shared stall sequence, used by both the Finalizer and the watchdog
	 * sweep: fresh re-read, optional run-key fence, prior-status snapshot, sparse
	 * {Status, FailureCategory, ErrorMessage} write, then the conditional single-fire onError notification. The
	 * guard is per-transition, not per-chain: the notification fires only on an actual change into
	 * Stalled observed in that same fresh re-read, so a chain already Stalled that is marked again
	 * never re-notifies, while a chain re-driven back to Running that stalls again notifies again.
	 * The bare markStalled writer carries no fence or deduplication of its own — every caller goes through
	 * this sequence, never the bare writer. A failed stall write propagates to the caller before
	 * the notification step, so the notification is skipped and the caller owns the failure
	 * logging.
	 *
	 * The unfenced (watchdog) path additionally refuses terminal rows on the fresh re-read: a
	 * candidate that reached Completed, Failed or Aborted since the sweep's selector read must not
	 * be marked back to Stalled or notified — the sweep is a recovery authority over recoverable
	 * rows only. The fenced Finalizer path keeps its fence-only semantics: its authorization is
	 * run-key equality, exactly as before.
	 * Both paths refuse an already-Aborted row before the fence-split: an operator abort does not
	 * rotate the run key, so the Finalizer's fence alone cannot see it.
	 *
	 * Residual: notification delivery is at-least-once. The single-fire guard deduplicates per observed
	 * transition into Stalled, but a re-driven chain that stalls again legitimately notifies
	 * again, and an enqueued notification is not un-sent if later writes fail. onError handlers
	 * must tolerate duplicate stall notifications.
	 *
	 * @param executionId The chain execution record ID.
	 * @param errorMessage The stall reason.
	 * @param notificationHandler The onError handler definition to notify once per transition, or null for none.
	 * @param enforceRunKeyFence Whether the write is fenced by a captured run key (the Finalizer) or unfenced (the watchdog).
	 * @param fenceRunKey The run key captured at enqueue time; compared against the fresh read when the fence is enforced.
	 */
	private static void markStalledAndNotify(Id executionId, String errorMessage, DTO_StepDefinition notificationHandler, Boolean enforceRunKeyFence, String fenceRunKey)
	{
		AsyncChainExecution__c execution = (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(executionId);
		if(execution == null || (enforceRunKeyFence && fenceRunKey != execution.RunKey__c)) // null == null passes (upgrade-safe)
		{
			return;
		}
		if(SEL_AsyncChainExecution.STATUS_ABORTED.equals(execution.Status__c))
		{
			return;
		}
		if(!enforceRunKeyFence && isTerminalStatus(execution.Status__c))
		{
			return;
		}

		Boolean stallTransition = execution.Status__c != SEL_AsyncChainExecution.STATUS_STALLED;

		markStalled(execution, errorMessage);

		if(stallTransition)
		{
			enqueueRecoveryErrorHandler(execution, errorMessage, notificationHandler, SEL_AsyncChainExecution.STATUS_STALLED);
		}
	}

	/**
	 * @description Marks the execution as Stalled with the given reason and logs a warning.
	 * Stalled is non-terminal — the chain awaits recovery — so CompletedAt__c and DurationMs__c
	 * stay unset and no performance log is emitted; a later re-drive finishes the chain and
	 * stamps its terminal fields then.
	 *
	 * @param execution The AsyncChainExecution__c record to update.
	 * @param message The stall reason to record.
	 */
	private static void markStalled(AsyncChainExecution__c execution, String message)
	{
		execution.Status__c = SEL_AsyncChainExecution.STATUS_STALLED;
		execution.FailureCategory__c = SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED;
		execution.ErrorMessage__c = UTIL_String.abbreviate(message, AsyncChainExecution__c.ErrorMessage__c);

		List<SObjectField> stallFields = new List<SObjectField>
		{
				AsyncChainExecution__c.Status__c,
				AsyncChainExecution__c.FailureCategory__c,
				AsyncChainExecution__c.ErrorMessage__c
		};
		DML_Builder.newTransaction().systemModeInternal().doUpdate(buildSparseUpdate(execution, stallFields)).execute();

		LOG_Builder.build().warn('Chain stalled: ' + message)
				.at(CLASS_NAME + '.markStalled')
				.forRecord(execution.Id)
				.emit();
	}

	/**
	 * @description Enqueues the given onError handler for a recovery outcome — a transition into
	 * Stalled, or the unrecoverable degrade's terminal Failed. The caller owns the deduplication (the
	 * stall path fires only on an actual status change; the degrade fires once, terminally). The
	 * handler executor captures the in-memory record's current run key — the fenced Finalizer
	 * caller passes the key its fence just matched, the degrade passes its freshly-rotated key —
	 * so a notification whose authorising write never lands fences itself out. The enqueue itself
	 * may fail in the same resource-exhausted transaction that caused the stall, so it degrades to
	 * an error log and never throws — the same discipline the Finalizer applies to its other
	 * handler enqueues. Delivery is therefore at-least-once, never guaranteed-exactly-once.
	 *
	 * @param execution The freshly-read execution record carrying the context data and correlation ID.
	 * @param message The recovery reason, passed to the handler as the original error message.
	 * @param notificationHandler The onError handler definition to run, or null for none.
	 * @param expectedStatus The status the handler's success write-back records: Stalled for a stall, Failed for the degrade.
	 */
	private static void enqueueRecoveryErrorHandler(AsyncChainExecution__c execution, String message, DTO_StepDefinition notificationHandler, String expectedStatus)
	{
		if(notificationHandler == null)
		{
			return;
		}

		try
		{
			if(simulateEnqueueFailure)
			{
				simulateEnqueueFailure = false;
				throw new UTIL_Exceptions.IllegalStateException('Simulated stalled onError enqueue failure');
			}
			ChainContext context = deserializeContext(execution.ContextData__c, execution.Id, execution.CorrelationId__c);
			System.enqueueJob(new HandlerExecutor(execution.Id, context, notificationHandler, expectedStatus, message, execution.RunKey__c));
		}
		catch(Exception enqueueError)
		{
			String failureContext = expectedStatus == SEL_AsyncChainExecution.STATUS_STALLED ? 'Stalled onError enqueue failed' : 'Unrecoverable-degrade onError enqueue failed';
			LOG_Builder.build().error(failureContext + ': ' + enqueueError.getMessage() + ' | Recovery reason: ' + message)
					.at(CLASS_NAME + '.enqueueRecoveryErrorHandler')
					.forRecord(execution.Id)
					.emit();
		}
	}

	/**
	 * @description Converts a strategy's backoff in seconds to the whole-minute enqueue delay the
	 * platform supports: any backoff over 0 seconds rounds UP to the next full minute, clamped to
	 * the platform's enqueue-delay ceiling. Outer-class static (Apex does not permit statics on
	 * inner types); called from ChainExecutor.scheduleRetry.
	 *
	 * @param backoffSeconds The strategy's computed backoff in seconds, or null.
	 *
	 * @return The enqueue delay in minutes, 0 to MAX_QUEUEABLE_DELAY_MINUTES.
	 */
	private static Integer clampBackoffToEnqueueWindow(Integer backoffSeconds)
	{
		Integer minutes = backoffSeconds == null || backoffSeconds <= 0 ? 0 : (Integer)Math.ceil(backoffSeconds / 60.0);
		return Math.min(MAX_QUEUEABLE_DELAY_MINUTES, minutes);
	}

	/**
	 * @description Builds a sparse update record carrying only the given fields, copied from the
	 * in-memory execution record. Executor persists must never update the loaded record directly:
	 * an update DML writes every queried field back, so a full-record write would silently revert
	 * a concurrent run-key rotation (RunKey__c) or an external abort (Status__c) committed after
	 * this executor's read. RunKey__c belongs in no executor write set — its exactly three writers
	 * are ChainBuilder.execute()'s initial insert, redriveStalledChain's rotation write set, and
	 * markRedriveCandidateFailed's terminal-authoritative rotation (the sweep is the rotation
	 * authority); Status__c belongs only in the write sets of status-transition sites;
	 * CurrentJobId__c belongs only in the progress write's set, so terminal writes leave the last
	 * known executor's job id in place for the watchdog's liveness check. Precondition: every
	 * intended field must be queried-or-assigned on the in-memory record, or the copy would stamp
	 * an unintended null.
	 *
	 * @param execution The in-memory execution record holding the values to persist.
	 * @param intendedFields The fields the persist site intends to change.
	 *
	 * @return A new AsyncChainExecution__c carrying only the Id and the intended fields.
	 */
	private static AsyncChainExecution__c buildSparseUpdate(AsyncChainExecution__c execution, List<SObjectField> intendedFields)
	{
		AsyncChainExecution__c sparse = new AsyncChainExecution__c(Id = execution.Id);
		for(SObjectField intendedField : intendedFields)
		{
			sparse.put(intendedField, execution.get(intendedField));
		}
		return sparse;
	}

	/**
	 * @description Persists the previous step result into the context data map for cross-transaction access.
	 *
	 * @param context The chain context to update.
	 * @param result The step result to persist.
	 */
	private static void persistPreviousStepResult(ChainContext context, StepResult result)
	{
		Map<String, Object> resultMap = new Map<String, Object>
		{
				'success' => result.success,
				'message' => result.message,
				'data' => result.data
		};
		context.put(PREVIOUS_RESULT_KEY, resultMap);
	}

	/**
	 * @description Restores the previous step result from the persisted context data map.
	 *
	 * @param context The chain context to read from and update.
	 */
	private static void restorePreviousStepResult(ChainContext context)
	{
		if(context.has(PREVIOUS_RESULT_KEY))
		{
			Map<String, Object> resultMap = (Map<String, Object>)context.get(PREVIOUS_RESULT_KEY);
			StepResult previous = new StepResult();
			previous.success = (Boolean)resultMap.get('success');
			previous.message = (String)resultMap.get('message');
			previous.data = resultMap.get('data');
			context.setPreviousStepResult(previous);
			context.data.remove(PREVIOUS_RESULT_KEY);
		}
	}
}