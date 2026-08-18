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
 * @date April 2026, August 2026
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
	 * @description Suffix appended to ErrorMessage__c when a failing chain's context outgrew the
	 * ContextData__c field and was therefore not persisted at all: the failure persist stores the
	 * complete context or none, never a truncated document, and this marker is the record's only
	 * trace of that loss — without a stored context, a retry from the failed step has no state to
	 * resume from.
	 *
	 * @since 1.7
	 */
	@TestVisible
	private static final String CONTEXT_NOT_PRESERVED_MARKER = '[Context too large to preserve: retry from failed step unavailable]';

	/**
	 * @description Failure message written when a step cannot be recreated from its class name in a
	 * hop: {0} is the class name, {1} the platform's own message. States the rule a subscriber
	 * needs — the class must exist, be a chain step, and declare no constructor of its own (from
	 * inside the package the platform reaches only the implicit constructor of a class that declares
	 * none, or a global constructor on a global class).
	 */
	@TestVisible
	private static final String STEP_NOT_CREATABLE_MESSAGE =
			'Failed (Cannot create step {0}) — the framework recreates each step by class name, so the class must exist, be a chain step, '
			+ 'and declare no constructor of its own (only a global class may declare a global one). Cause: {1}';

	/**
	 * @description Announcement a launch writes when it could not give its chain the transaction's
	 * log correlation because an earlier chain in the same transaction already holds it: {0} is the
	 * chain name, {1} the correlation this chain is recorded under, {2} the transaction correlation.
	 * Filed under the transaction correlation on purpose — a reader who only knows the correlation
	 * their own service started can follow this entry to the chain it launched.
	 *
	 * @since 1.7
	 */
	private static final String CORRELATION_MINTED_MESSAGE =
			'Chain {0} recorded under a new correlation {1}: correlation {2} is already attached to an earlier chain in this transaction.';

	/**
	 * @description Refusal raised when a launch supplies a correlation another chain execution
	 * already holds: {0} is the correlation, {1} the holder named as precisely as the transaction
	 * can. CorrelationId__c is a unique index and the platform redacts which field and which record
	 * collided, so without this the caller gets an unattributed duplicate-value error; this states
	 * the rule and the way out instead.
	 *
	 * @since 1.7
	 */
	private static final String CORRELATION_COLLISION_MESSAGE =
			'Correlation {0} is already attached to {1}. A chain run owns its correlation exclusively, so give this chain '
			+ 'one of its own: pass a distinct id to execute(correlationId).';

	/**
	 * @description Holder wording for a correlation whose owning run was launched in THIS
	 * transaction, where the launch registry can name it exactly: {0} is that run's record id.
	 *
	 * @since 1.7
	 */
	private static final String CORRELATION_HOLDER_NAMED = 'chain execution {0}';

	/**
	 * @description Holder wording for a correlation attached outside this transaction. Deliberately
	 * unnamed rather than looked up: the run holding it may be one this caller is not allowed to
	 * see, which is the very reason the platform redacts the record id from the duplicate-value
	 * error in the first place. Naming it would leak across that boundary, so the refusal spends its
	 * words on the rule and the remedy instead.
	 *
	 * @since 1.7
	 */
	private static final String CORRELATION_HOLDER_UNNAMED = 'another chain execution';

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
	 * @description Developer name of the feature flag gating the operator re-drive capability —
	 * retry from the failed step, restart from the start, and clear stalled. The flag's strategy
	 * names the re-drive custom permission; the controller reads this constant, so the gate has
	 * exactly one spelling.
	 *
	 * @since 1.7
	 */
	public static final String REDRIVE_FEATURE_FLAG_NAME = 'AsyncChainRedrive_Enabled';

	/**
	 * @description Developer name of the custom permission the re-drive flag's strategy checks.
	 * The re-drive test suite resolves grants of this permission by this constant, so the gate has
	 * exactly one spelling.
	 *
	 * @since 1.7
	 */
	public static final String REDRIVE_CUSTOM_PERMISSION_NAME = 'RedriveAsyncChain';

	/**
	 * @description API name of the permission set that is the designed source of the re-drive
	 * custom permission. Package installs also write the permission into profiles; this permission
	 * set is the assignment route the framework recommends.
	 *
	 * @since 1.7
	 */
	public static final String REDRIVE_PERMISSION_SET_NAME = 'AsyncChainRedrive';

	/**
	 * @description Developer name of the feature flag gating the operator kill-switch toggle —
	 * suspending and resuming all chain processing. A separate gate from re-drive on purpose: the
	 * toggle's blast radius is org-wide, so it carries its own flag, permission and permission set.
	 *
	 * @since 1.7
	 */
	public static final String KILL_SWITCH_TOGGLE_FEATURE_FLAG_NAME = 'AsyncChainKillSwitch_Enabled';

	/**
	 * @description Developer name of the custom permission the kill-switch flag's strategy checks.
	 * The re-drive test suite resolves grants of this permission by this constant, so the gate has
	 * exactly one spelling.
	 *
	 * @since 1.7
	 */
	public static final String KILL_SWITCH_TOGGLE_CUSTOM_PERMISSION_NAME = 'ManageAsyncChainKillSwitch';

	/**
	 * @description API name of the permission set that is the designed source of the kill-switch
	 * custom permission. Package installs also write the permission into profiles; this permission
	 * set is the assignment route the framework recommends.
	 *
	 * @since 1.7
	 */
	public static final String KILL_SWITCH_TOGGLE_PERMISSION_SET_NAME = 'AsyncChainKillSwitch';

	/**
	 * @description Statuses an operator abort may act on. Delayed is reserved and never written.
	 */
	private static final Set<String> ABORTABLE_STATUSES = new Set<String>
	{
			SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_STALLED
	};

	/**
	 * @description Availability code: the chain's state permits the operator re-drive action.
	 * Machine code shared by the resolver, the action's own re-resolution, and the Chain Monitor's
	 * label mapping — never shown to a user directly.
	 *
	 * @since 1.7
	 */
	public static final String REDRIVE_AVAILABLE = 'Available';

	/**
	 * @description Availability code: the chain is not in the Failed state the retry action
	 * re-enters — live rows and other terminal rows are never retry candidates.
	 *
	 * @since 1.7
	 */
	public static final String REDRIVE_CHAIN_NOT_RETRYABLE = 'ChainNotRetryable';

	/**
	 * @description Availability code: the failed step never declared itself safe to execute more
	 * than once, so re-running it could double its side effects.
	 *
	 * @since 1.7
	 */
	public static final String REDRIVE_STEP_NOT_IDEMPOTENT = 'StepNotIdempotent';

	/**
	 * @description Availability code: the failed step declared its failure permanent, so a re-run
	 * cannot succeed; the operator's recourse is a restart from the start or a code fix.
	 *
	 * @since 1.7
	 */
	public static final String REDRIVE_FAILURE_PERMANENT = 'FailurePermanent';

	/**
	 * @description Availability code: the chain's persisted context or step log is absent or does
	 * not parse, so there is no trustworthy state to resume from.
	 *
	 * @since 1.7
	 */
	public static final String REDRIVE_CONTEXT_UNAVAILABLE = 'ContextUnavailable';

	/**
	 * @description Availability code: chain processing is suspended org-wide, and re-driving into
	 * the kill switch would only manufacture runs the next executor entry consult aborts.
	 *
	 * @since 1.7
	 */
	public static final String REDRIVE_PROCESSING_SUSPENDED = 'ChainProcessingSuspended';

	/**
	 * @description Availability code: another live run currently holds the chain's declared
	 * deduplication key, so re-claiming it would break the concurrency lock the key exists for.
	 *
	 * @since 1.7
	 */
	public static final String REDRIVE_DUPLICATE_RUN = 'DuplicateRun';

	/**
	 * @description Availability code: the chain's state permits the operator restart action.
	 * Machine code shared by the resolver, the action's own re-resolution, and the Chain Monitor's
	 * label mapping — never shown to a user directly.
	 *
	 * @since 1.7
	 */
	public static final String RESTART_AVAILABLE = 'Available';

	/**
	 * @description The step index a restart clone's executor resumes at. A restart is a run from the
	 * beginning by definition, so this is always the first entry — unlike the watchdog re-drive and
	 * the operator retry, which each derive their index from the persisted step log.
	 *
	 * @since 1.7
	 */
	private static final Integer RESTART_RESUME_INDEX = 0;

	/**
	 * @description Availability code: the chain is not in a state a restart may act on — only a
	 * run that ended badly, Failed or Aborted, can be re-run from the start.
	 *
	 * @since 1.7
	 */
	public static final String RESTART_CHAIN_NOT_RESTARTABLE = 'ChainNotRestartable';

	/**
	 * @description Availability code: the chain never declared allowRestart() at build time, so
	 * re-running the whole chain could double its side effects; restart stays hidden until the
	 * author opts in.
	 *
	 * @since 1.7
	 */
	public static final String RESTART_NOT_DECLARED = 'RestartNotDeclared';

	/**
	 * @description Availability code: the chain's as-built context snapshot or step log is absent,
	 * unparseable, or holds no runnable step definitions, so no clone can be built from it.
	 *
	 * @since 1.7
	 */
	public static final String RESTART_CONTEXT_UNAVAILABLE = 'ContextUnavailable';

	/**
	 * @description Statuses an operator restart may act on: the two bad endings. Completed chains
	 * are never re-run through the monitor, and live chains already have an executor.
	 */
	private static final Set<String> RESTARTABLE_STATUSES = new Set<String>
	{
			SEL_AsyncChainExecution.STATUS_FAILED, SEL_AsyncChainExecution.STATUS_ABORTED
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
	 * @description Ceiling on the candidates one operator clear-stalled invocation inspects.
	 * Deliberately decoupled from the watchdog's configured batch size and sized below both the
	 * watchdog's own ceiling and the 50-enqueue synchronous limit: the operator sweep runs inside
	 * an @AuraEnabled transaction that carries ambient work the scheduled context does not, so it
	 * keeps a wider margin. The binding constraint is heap, not enqueues: a full batch of
	 * candidate rows rides the operator's 6MB synchronous heap — half the async watchdog's —
	 * which is why the candidate and tally projections also shed the long-text payloads no sweep
	 * leg reads. Candidates beyond the ceiling stay in place — still Stalled, still candidates —
	 * and the operator can simply run the action again.
	 */
	@TestVisible
	private static final Integer MAX_OPERATOR_SWEEP_CANDIDATES = 40;

	/**
	 * @description The operator sweep's own bookend reads — the candidate selector and the
	 * outcome tally. clearStalledChains refuses at entry when the remaining query budget cannot
	 * cover even these two, returning truthful zero counts instead of running either read into an
	 * uncatchable LimitException: the caller's transaction may arrive with its query budget
	 * already spent, the same ambient-consumption premise the DML reserve documents.
	 */
	private static final Integer OPERATOR_SWEEP_MINIMUM_QUERIES = 2;

	/**
	 * @description Synchronous query budget the operator sweep proves before each candidate: the
	 * watchdog's per-candidate reserve plus one more query, so the outcome tally's single
	 * post-sweep read stays affordable even when this gate fires — the tally turns the sweep's
	 * work into the truthful counts the operator sees, so it must never be the call that dies on
	 * the very budget the gate was protecting.
	 */
	private static final Integer OPERATOR_CANDIDATE_QUERY_RESERVE = WATCHDOG_CANDIDATE_QUERY_RESERVE + 1;

	/**
	 * @description DML-statement budget the operator sweep proves before each candidate. A swept
	 * candidate spends at most two statements — a re-drive's rotation write and its job-id stamp,
	 * or a single mark, park, or degrade write — and one more is held as margin because the
	 * operator sweep runs inside an @AuraEnabled transaction whose request may carry DML of its
	 * own, unlike the scheduled sweep's dedicated transaction. The scheduled sweep carries no DML
	 * reserve on purpose: its batch clamp and dedicated transaction bound its worst case, while
	 * the operator path must prove headroom it cannot assume. When the remaining budget drops
	 * below this reserve, the sweep leaves its remaining candidates untouched (see
	 * clearStalledChains) instead of running a decision leg into an uncatchable LimitException.
	 */
	private static final Integer OPERATOR_CANDIDATE_DML_RESERVE = 3;

	/**
	 * @description The platform's pre-execution/executing AsyncApexJob statuses — the set that
	 * proves a stamped executor job is still alive. Completed, Aborted and Failed are dead.
	 */
	private static final Set<String> LIVE_JOB_STATUSES = new Set<String> {'Queued', 'Processing', 'Preparing', 'Holding'};

	/**
	 * @description The chain execution each correlation was attached to by a launch in THIS
	 * transaction. CorrelationId__c is a unique index, so one correlation drives exactly one run:
	 * a service that starts a log correlation and then launches several chains would have every
	 * launch after the first collide on that index. The no-argument execute() consults this registry
	 * before adopting the active correlation — the first launch adopts it, later launches in the
	 * same transaction record their own — and the collision refusal reads it to name the run holding
	 * a correlation the caller supplied itself. Only successful inserts are registered: a launch that
	 * deduplicated onto a running chain never attached its correlation to anything. Scoped to the
	 * transaction by nature, which is exactly why the refusal also has an unnamed-holder form.
	 *
	 * @since 1.7
	 */
	private static final Map<String, Id> EXECUTION_IDS_BY_CORRELATION_ID = new Map<String, Id>();

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
			if(chainStep.isIdempotent() == true)
			{
				definition.isIdempotent = true;
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
	 * The step is recreated by class name in every hop, so a subscriber step class must be
	 * creatable across the package boundary: the platform only reaches the implicit constructor
	 * of a class that declares none (or a global constructor on a global class) — a step that
	 * declares its own public constructor cannot be recreated, which the failure message states.
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
			throw new UTIL_Exceptions.ConfigurationException(String.format(STEP_NOT_CREATABLE_MESSAGE, new List<String> {stepDefinition.className, error.getMessage()}));
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
		 * @description Declares whether this step is safe to execute more than once — override to
		 * return true only when a repeat run of work() cannot double the step's side effects, either
		 * because the work is naturally idempotent or because the step guards itself (e.g. via
		 * ChainContext.idempotencyKey()). Read on the instance the chain was built with, persisted
		 * into the run's step log, and consulted by the Chain Monitor's retry-from-failed-step gate;
		 * the default false keeps retry hidden until the author opts in. The declaration never
		 * changes how the chain runs. It is a method rather than a field so the declaration needs no
		 * constructor: the framework recreates every step by class name in each hop, and a step
		 * class that declares its own constructor cannot be recreated across the package boundary.
		 *
		 * @return True when a repeat run of this step is safe; false (the default) otherwise.
		 *
		 * @since 1.7
		 *
		 * @example
		 * ```apex
		 * public override Boolean isIdempotent()
		 * {
		 *     return true;
		 * }
		 * ```
		 */
		global virtual Boolean isIdempotent()
		{
			return false;
		}

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
		 * ChainContext.idempotencyKey(). Exception filters match the failure's exception wherever one
		 * exists: a step that THROWS and a step that RETURNS failed(exception) are filtered identically.
		 * Only a message-only failed(message) carries no exception, so nothing but the attempt budget
		 * gates it; a step that recognises a deterministic message-only failure should return
		 * failedPermanently(...) instead, which refuses retry outright whatever this strategy answers.
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
		 * @description True when the step declared this failure permanent: the failure is
		 * deterministic, so the chain refuses any retry regardless of the configured retry
		 * budget and records the failure with category StepException. Never null: false on
		 * every result except one built by failedPermanently().
		 *
		 * @since 1.7
		 */
		global Boolean permanentFailure {get; private set;}

		/**
		 * @description Package-private constructor. Use outer class factory methods: succeeded() / failed() / failedPermanently().
		 */
		@TestVisible
		private StepResult()
		{
			permanentFailure = false;
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
	 * @description Creates a permanently failed step result from a message: a failure the step
	 * knows is deterministic (a validation verdict, a rejected business rule, a client error that
	 * can never succeed on re-send), so the chain must not spend retry budget on it. The retry
	 * strategy is never consulted, the chain fails on this attempt, and FailureCategory__c
	 * records StepException.
	 *
	 * @param message A human-readable description of the deterministic failure.
	 *
	 * @return A StepResult with success false, the provided message, and the permanent flag set.
	 *
	 * @since 1.7
	 *
	 * @example
	 * ```apex
	 * return UTIL_AsyncChain.failedPermanently('Order was cancelled upstream');
	 * ```
	 */
	global static StepResult failedPermanently(String message)
	{
		StepResult result = failed(message);
		result.permanentFailure = true;
		return result;
	}

	/**
	 * @description Creates a permanently failed step result from an exception, for a caught
	 * failure the step recognises as deterministic. The exception rides the result exactly as
	 * with failed(exception); the permanent flag additionally refuses any retry, outranking
	 * both the attempt budget and every exception filter.
	 *
	 * @param error The exception that caused the deterministic failure.
	 *
	 * @return A StepResult with success false, the exception message and reference, and the permanent flag set.
	 *
	 * @since 1.7
	 */
	global static StepResult failedPermanently(Exception error)
	{
		StepResult result = failed(error);
		result.permanentFailure = true;
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
		 * @description The current step's retry strategy, stashed by the executor before each
		 * work() so isFinalAttempt(error) can consult the strategy's exception filters. Declared
		 * transient on purpose: strategies are code, not state — a filter's Set<Type> should not
		 * ride the platform's serialization of a handler enqueue — and a handler probing after the
		 * failure correctly reads final from the null stash.
		 */
		@TestVisible
		private transient UTIL_Retry.Strategy currentRetryStrategy;

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
		 * @description True when no further retry remains for the currently executing step, judged
		 * by the strategy's attempt budget alone. The stamp is written before work() runs, so it
		 * cannot know which exception the attempt will fail with, and a strategy wrapped in an
		 * exception filter can still refuse the retry afterwards; when that happens the framework
		 * corrects the stamp before dispatching the failure, so an onError handler always reads
		 * true for a failure that was final. To ask "would failing with THIS exception be final?"
		 * from inside work(), use isFinalAttempt(error).
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
		 * @description True when failing the current attempt with the given exception would be
		 * final. Unlike isFinalAttempt(), which reads the attempt budget alone and cannot know
		 * that an exception filter would refuse the retry, this overload consults the current
		 * step's full strategy, filters included, with the exception you are about to fail with.
		 * Call it from inside work(), before returning or throwing, when a last-chance side
		 * effect (release a lock, write a marker, alert someone) must run exactly when no retry
		 * will follow. Outside work() — in an onError handler — no strategy is in scope and the
		 * probe reads true, which is correct there: a dispatched failure is final.
		 *
		 * @param error The exception the step is about to fail with, or null for a message-only failure.
		 *
		 * @return True when a failure with this exception ends the step's attempts.
		 *
		 * @since 1.7
		 *
		 * @example
		 * ```apex
		 * if(context.isFinalAttempt(caught)) { releaseLock(); }
		 * return UTIL_AsyncChain.failed(caught);
		 * ```
		 */
		global Boolean isFinalAttempt(Exception error)
		{
			if(currentRetryStrategy == null)
			{
				return true;
			}
			return !currentRetryStrategy.shouldRetry(UTIL_Retry.newContext(getAttempt() - 1).withCustomData(error));
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
	 * @description Serializes the failing chain's context for terminal persistence, refusing to truncate:
	 * a context that no longer fits the field is not stored at all, so re-drive validation can reject
	 * cleanly instead of parsing a cut-off document. The failure path cannot throw - the chain is
	 * already failing - which is why absence, marked in ErrorMessage__c, is the honest degradation.
	 *
	 * @param context The chain context at failure time.
	 *
	 * @return The full serialized context, or null when it exceeds the ContextData__c field length.
	 *
	 * @since 1.7
	 */
	@TestVisible
	private static String serializeContextForFailurePersist(ChainContext context)
	{
		String serialized = context.serialize();
		Integer fieldLength = UTIL_SObjectDescribe.getCachedFieldDescribe(AsyncChainExecution__c.ContextData__c).length;
		return serialized != null && serialized.length() > fieldLength ? null : serialized;
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
		 * @description Whether the chain author declared the chain safe to restart from step 1.
		 * Set by allowRestart(); false until declared.
		 */
		private Boolean restartDeclared = false;

		/**
		 * @description Whether this launch's correlation was minted by the framework rather than
		 * supplied by the caller or inherited from the transaction. A freshly minted UUID cannot
		 * already be attached to a run, so a duplicate on such a launch is never the correlation
		 * index. That is what lets the keyed retry path tell a genuine correlation clash from a
		 * deduplication collision whose winner lookup came back empty, which can happen when the key
		 * is released and re-claimed around the lookup: without it, a launch whose correlation could
		 * not possibly have collided would be refused with the correlation rule.
		 *
		 * @since 1.7
		 */
		private Boolean correlationMintedByFramework = false;

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
		 * @description Declares this chain safe to restart from its first step. A restart re-runs
		 * EVERY step, so declare it only when the whole chain can run twice without doubling its
		 * side effects. The declaration stamps the run record at start and captures the as-built
		 * initial context beside it; the Chain Monitor's restart action is offered only for declared
		 * runs and replays that snapshot, never the evolved context a partial run left behind. Off
		 * by default, so restart stays hidden until the author opts in — the declaration never
		 * changes how the chain runs.
		 *
		 * @return This builder, for chaining.
		 *
		 * @since 1.7
		 *
		 * @example
		 * ```apex
		 * String runId = UTIL_AsyncChain.newChain('NightlyAccountSync')
		 *     .then(new SyncStep())
		 *     .allowRestart()
		 *     .execute();
		 * ```
		 */
		global ChainBuilder allowRestart()
		{
			this.restartDeclared = true;
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
		 * @description Executes the chain, giving it the transaction's log correlation when one is
		 * active and a fresh one otherwise. Persists the chain configuration and enqueues the first step.
		 *
		 * First-adopter rule: a correlation can be attached to exactly one chain run, so only the
		 * FIRST chain launched under an active correlation adopts it. Later launches in the same
		 * transaction — the shape a service that starts a correlation and then kicks off several
		 * chains produces — are recorded under a correlation of their own and announce it once, under
		 * the transaction's correlation, so the whole transaction still reads as one story. Before
		 * this rule the second launch failed on the unique index with an unattributed database error.
		 *
		 * @return The ID of the AsyncChainExecution__c record tracking this chain.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException If the serialized step list exceeds the
		 * StepLog__c field capacity less the per-step runtime reserve — see the correlation-ID
		 * overload this method delegates to — or if the active correlation is already attached to a
		 * chain run started in an EARLIER transaction, which the first-adopter rule cannot see.
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
			String activeCorrelationId = LOG_Builder.correlationId;
			if(String.isBlank(activeCorrelationId))
			{
				correlationMintedByFramework = true;
				return execute(UTIL_Random.randomUUID());
			}
			if(!EXECUTION_IDS_BY_CORRELATION_ID.containsKey(activeCorrelationId))
			{
				return execute(activeCorrelationId);
			}

			String mintedCorrelationId = UTIL_Random.randomUUID();
			correlationMintedByFramework = true;
			String executionId = execute(mintedCorrelationId);
			if(EXECUTION_IDS_BY_CORRELATION_ID.containsKey(mintedCorrelationId))
			{
				announceMintedCorrelation(chainName, mintedCorrelationId, activeCorrelationId, executionId);
			}
			return executionId;
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
		 * truncating the persisted JSON — or if the supplied correlation ID is already attached to
		 * another chain run, since a run owns its correlation exclusively.
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
				insertRunRecord(execution);
				EXECUTION_IDS_BY_CORRELATION_ID.put(correlationId, execution.Id);
				emitTerminalLog(LoggingLevel.INFO, 'Chain completed: ' + chainName + ' (no steps)', CLASS_NAME + '.ChainBuilder.execute', execution.Id);
				return execution.Id;
			}

			if(restartDeclared)
			{
				execution.AllowRestart__c = true;
				execution.InitialContextData__c = execution.ContextData__c;
			}
			execution.ActiveDeduplicationKey__c = deduplicationKey;
			execution.DeclaredDeduplicationKey__c = deduplicationKey;
			String activeRunId = insertGuardedByDeduplicationKey(execution);
			if(activeRunId != null)
			{
				return activeRunId;
			}
			EXECUTION_IDS_BY_CORRELATION_ID.put(correlationId, execution.Id);

			AsyncOptions options = asyncOptions != null ? asyncOptions : new AsyncOptions();

			if(asyncOptions == null)
			{
				options.maximumQueueableStackDepth = steps.size() + 1;
			}

			ChainExecutor executor = new ChainExecutor(execution.Id, 0, maxSteps, maxContextSize, errorHandler, completionHandler, options, execution.RunKey__c);

			Id executorJobId = System.enqueueJob(executor, buildFirstEnqueueOptions(options, firstStepDelayMinutes));
			stampExecutorJobId(execution, executorJobId);

			return execution.Id;
		}

		/**
		 * @description Inserts the run record. A DUPLICATE_VALUE failure on a keyed start is
		 * attributed to the deduplication index PRESUMPTIVELY — the platform redacts the colliding
		 * field's name from most callers, so a keyed collision on another unique field can attribute
		 * here too. The winner lookup and single retry disambiguate: a run holding the key means the
		 * start deduplicates onto it (correct landing); an empty lookup means the winner released the
		 * key — or the collision was never on the deduplication index — and the insert is re-attempted
		 * exactly once. A second failure gets the same lookup a second time, so a launch that raced a
		 * new key holder still lands on it, and a launch cleared of the deduplication index twice
		 * whose correlation could actually have collided is refused by that rule instead of surfacing
		 * an unattributed database error (see asRetryFailure for why a framework-minted correlation
		 * is exempt). The one extra query is spent only on an already-failing start.
		 *
		 * @param execution The fully-populated run record to insert.
		 *
		 * @return The active run's Id when the start deduplicated onto it; null when this run's
		 *         insert succeeded.
		 */
		private String insertGuardedByDeduplicationKey(AsyncChainExecution__c execution)
		{
			String activeRunId = null;
			try
			{
				DML_Builder.newTransaction().systemModeInternal().doInsert(execution).execute();
			}
			catch(DmlException insertError)
			{
				activeRunId = resolveActiveRun(insertError, execution.CorrelationId__c);
				if(activeRunId == null)
				{
					try
					{
						DML_Builder.newTransaction().systemModeInternal().doInsert(execution).execute();
					}
					catch(DmlException retryError)
					{
						activeRunId = resolveRacedRun(retryError);
						if(activeRunId == null)
						{
							throw asRetryFailure(retryError, execution.CorrelationId__c);
						}
					}
				}
			}
			return activeRunId;
		}

		/**
		 * @description Resolves a SECOND failed start to the run that claimed the deduplication key
		 * while this launch was re-attempting. The retry exists because the first failure's winner
		 * lookup came back empty, meaning the key was free at that moment; if the retry then fails on
		 * a duplicate too, either another launch took the key in between (a real race, and the start
		 * belongs on that run) or the key was never the colliding index at all. Only a duplicate is
		 * worth a lookup — any other platform failure is a different problem and must reach the caller
		 * as it was reported. An empty answer here is the second clearance of the deduplication index,
		 * which leaves CorrelationId__c as the only unique index that can have collided.
		 *
		 * @param retryError The exception the re-attempted insert raised.
		 *
		 * @return The racing winner's Id, or null when no run holds the key.
		 *
		 * @since 1.7
		 */
		private String resolveRacedRun(DmlException retryError)
		{
			return isDuplicateValueFailure(retryError) ? new SEL_AsyncChainExecution().findByActiveDeduplicationKey(deduplicationKey)?.Id : null;
		}

		/**
		 * @description Reads a start that failed TWICE, once the winner lookup has come back empty
		 * both times. A correlation the framework minted for this launch cannot already be attached
		 * to anything, so its failure is left exactly as the platform reported it — the winner lookup
		 * disagreeing with the index is a deduplication race, not a correlation clash, and calling it
		 * one would send the caller after the wrong field. A correlation the caller supplied, or one
		 * inherited from the transaction, is the only remaining candidate and is refused by that rule.
		 *
		 * @param retryError The exception the re-attempted insert raised.
		 * @param correlationId The correlation the failed insert tried to attach.
		 *
		 * @return The typed refusal, or the platform's own exception.
		 *
		 * @since 1.7
		 */
		private Exception asRetryFailure(DmlException retryError, String correlationId)
		{
			return correlationMintedByFramework ? retryError : asCorrelationCollision(retryError, correlationId);
		}

		/**
		 * @description Resolves a failed insert to the run currently holding the key. A chain started
		 * without a deduplication key can never collide on the deduplication index, so its failures
		 * never reach the winner lookup; keyed failures reach it only when the predicate
		 * presumptively attributes them to the deduplication index. Everything else leaves through
		 * the correlation reading, which turns the one collision a chain launch can suffer on the
		 * other unique index into a refusal that names the rule, and passes anything else along
		 * exactly as the platform reported it. A keyed failure that survives the retry is finished off
		 * by resolveRacedRun, so both message forms end at the same refusal.
		 *
		 * @param insertError The exception the failed insert raised.
		 * @param correlationId The correlation the failed insert tried to attach.
		 *
		 * @return The winner's Id, or null when the key has already been released.
		 */
		private String resolveActiveRun(DmlException insertError, String correlationId)
		{
			if(String.isBlank(deduplicationKey) || !isActiveDeduplicationKeyCollision(insertError))
			{
				throw asCorrelationCollision(insertError, correlationId);
			}
			AsyncChainExecution__c activeRun = new SEL_AsyncChainExecution().findByActiveDeduplicationKey(deduplicationKey);
			return activeRun?.Id;
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
	 * @description Builds the AsyncOptions for the chain's FIRST enqueue: a clone of the effective
	 * options carrying an optional one-hop delay. A clone is mandatory - the effective options may be
	 * the caller's own object, which rides the executor baton to every later hop, and a delay left on
	 * it would repeat on each of them (the Finalizer retry path documents the same hazard).
	 * The property copy is EXHAUSTIVE for API 67.0 (maximumQueueableStackDepth,
	 * minimumQueueableDelayInMinutes, duplicateSignature) - re-audit this list on every
	 * apiVersion bump, or a property added by a newer API is silently stripped from the
	 * first hop.
	 * Internal seam: AsyncOptions cannot be inspected after submission, so this method is the only possible witness of the built options — used only by UTIL_AsyncChain_TEST.
	 *
	 * @param effectiveOptions The options the chain runs under (caller-supplied or framework default).
	 * @param firstStepDelayMinutes The withDelayMinutes value, or null for an immediate start.
	 *
	 * @return A first-enqueue-only AsyncOptions instance.
	 *
	 * @since 1.7
	 */
	@TestVisible
	private static AsyncOptions buildFirstEnqueueOptions(AsyncOptions effectiveOptions, Integer firstStepDelayMinutes)
	{
		AsyncOptions firstEnqueueOptions = new AsyncOptions();
		firstEnqueueOptions.maximumQueueableStackDepth = effectiveOptions.maximumQueueableStackDepth;
		firstEnqueueOptions.duplicateSignature = effectiveOptions.duplicateSignature;
		if(firstStepDelayMinutes != null && firstStepDelayMinutes > 0)
		{
			firstEnqueueOptions.minimumQueueableDelayInMinutes = firstStepDelayMinutes;
		}
		return firstEnqueueOptions;
	}

	/**
	 * @description Inserts a run record on the one launch path that has no deduplication guard to
	 * shelter under — a chain with no steps, which completes on the spot and therefore never claims
	 * a deduplication key. Its only unique index in play is the correlation, so any duplicate here
	 * is that collision and gets the same refusal a chain with steps would give.
	 *
	 * @param execution The fully-populated run record to insert.
	 *
	 * @since 1.7
	 */
	private static void insertRunRecord(AsyncChainExecution__c execution)
	{
		try
		{
			DML_Builder.newTransaction().systemModeInternal().doInsert(execution).execute();
		}
		catch(DmlException insertError)
		{
			throw asCorrelationCollision(insertError, execution.CorrelationId__c);
		}
	}

	/**
	 * @description Reads a failed launch insert as a correlation collision when it can only be one,
	 * and passes everything else through untouched. Attribution is by elimination, not by message
	 * text: the platform redacts both the colliding field and the record holding it from most
	 * callers, so a launch that has already been cleared of the deduplication index and still
	 * reports a duplicate can only have hit CorrelationId__c, the object's one other unique index.
	 * Anything that is not a duplicate — a validation rule, a value the field cannot hold — is a
	 * different problem entirely and is handed back exactly as the platform reported it, because
	 * dressing it up as a correlation clash would send the caller hunting the wrong thing.
	 * Enumeration assumption: a future unique field on AsyncChainExecution__c breaks the
	 * elimination and must be reflected here.
	 *
	 * @param insertError The exception the failed insert raised.
	 * @param correlationId The correlation the failed insert tried to attach.
	 *
	 * @return The typed refusal for a correlation collision, or the original exception.
	 *
	 * @since 1.7
	 */
	private static Exception asCorrelationCollision(DmlException insertError, String correlationId)
	{
		if(!isDuplicateValueFailure(insertError))
		{
			return insertError;
		}
		Id holderId = EXECUTION_IDS_BY_CORRELATION_ID.get(correlationId);
		String holder = holderId == null
				? CORRELATION_HOLDER_UNNAMED
				: String.format(CORRELATION_HOLDER_NAMED, new List<String> {holderId});
		return new UTIL_Exceptions.IllegalStateException(String.format(CORRELATION_COLLISION_MESSAGE, new List<String> {correlationId, holder}), insertError);
	}

	/**
	 * @description Announces, once, that a launch had to record its chain under a correlation of its
	 * own because the transaction's was already attached to an earlier chain. Emitted after the run
	 * exists and pointed at it, while the transaction's correlation is still the active one, so the
	 * entry lands in the story the caller is already reading and leads from there to the new chain.
	 *
	 * @param chainName The chain the launch started.
	 * @param mintedCorrelationId The correlation the chain is recorded under.
	 * @param activeCorrelationId The transaction's correlation, already attached to an earlier chain.
	 * @param executionId The run record the announcement points at.
	 *
	 * @since 1.7
	 */
	private static void announceMintedCorrelation(String chainName, String mintedCorrelationId, String activeCorrelationId, String executionId)
	{
		LOG_Builder.build()
				.info(String.format(CORRELATION_MINTED_MESSAGE, new List<String> {chainName, mintedCorrelationId, activeCorrelationId}))
				.at(CLASS_NAME + '.announceMintedCorrelation')
				.forRecord(executionId)
				.emit();
	}

	/**
	 * @description True when a failed write presumptively collides on the deduplication index: a
	 * DUPLICATE_VALUE whose message does NOT name CorrelationId__c (resolved through the describe
	 * cache, so the match is exact in both namespaced and unmanaged deploys). The check is
	 * negative because that is what survives the platform's message variability: field API names
	 * embed verbatim in localized platform messages, while redaction blanks the field position
	 * entirely for callers without org-wide record access — so a positive match on the
	 * deduplication field's name would fail for exactly those callers. Enumeration assumption:
	 * AsyncChainExecution__c carries exactly two unique indexes (CorrelationId__c and
	 * ActiveDeduplicationKey__c); a future unique field must join the negative list. Two callers:
	 * the guarded first insert (where, under redaction, a keyed CorrelationId__c collision can
	 * attribute here — the winner lookup and single retry disambiguate it safely) and the operator
	 * retry's key re-claim update (which writes no CorrelationId__c, so every DUPLICATE_VALUE
	 * there is the deduplication index).
	 *
	 * @param duplicateError The exception the failed write raised.
	 *
	 * @return True for a presumptive deduplication-index collision.
	 */
	private static Boolean isActiveDeduplicationKeyCollision(DmlException duplicateError)
	{
		return isDuplicateValueFailure(duplicateError)
				&& !duplicateError.getDmlMessage(0).contains(UTIL_SObjectDescribe.getCachedFieldName(AsyncChainExecution__c.CorrelationId__c));
	}

	/**
	 * @description True when a failed write is a unique-index collision at all, as opposed to any
	 * other write failure a subscriber validation rule or an oversized value can raise. Every
	 * unique-index reading in this class starts here, so none of them can mistake an unrelated
	 * platform failure for a duplicate.
	 *
	 * @param writeError The exception the failed write raised.
	 *
	 * @return True for a duplicate-value failure carrying at least one row error.
	 *
	 * @since 1.7
	 */
	private static Boolean isDuplicateValueFailure(DmlException writeError)
	{
		return writeError.getNumDml() > 0 && writeError.getDmlType(0) == StatusCode.DUPLICATE_VALUE;
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
		 * @description Status codes eligible for chain-level retry, or null (the default) to keep
		 * the released retry-any behaviour. Build-time only; persisted as a JSON string in the
		 * step config and re-stashed by work() beside the retry pair, because the config map
		 * reaches work() both as the in-memory build map and as a deserializeUntyped round trip,
		 * and a JSON string is the one shape that arrives identically through both.
		 */
		private Set<Integer> retryableStatusCodes;

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
		 * @description Restricts chain-level retry to the given HTTP status codes, the ApiStep
		 * sibling of UTIL_HttpClient's retryOn. A failed call whose status is outside the set is
		 * declared permanently failed: the chain fails on that attempt without spending the
		 * remaining retry budget, because the status proved the failure deterministic (a 400
		 * returns 400 however often it is re-sent). Without this call every failed status
		 * retries, exactly as before. A failure with no status code at all (the transport threw
		 * before any response arrived) always stays retryable: without a status, nothing proves
		 * the failure deterministic. An explicitly-passed empty set therefore stops every
		 * status-bearing failure from retrying. Has no effect unless withRetry(...) enabled
		 * chain-level retry, matching the UTIL_HttpClient family.
		 *
		 * @param statusCodes The status codes eligible for retry.
		 *
		 * @return This ApiStep for method chaining.
		 *
		 * @since 1.7
		 *
		 * @example
		 * ```apex
		 * new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
		 *     .withRetry(3, 30)
		 *     .retryOn(new Set<Integer> {500, 503})
		 * ```
		 */
		global ApiStep retryOn(Set<Integer> statusCodes)
		{
			this.retryableStatusCodes = statusCodes;
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
		 * @description Decides whether a failed call's status excludes it from chain-level retry:
		 * true only when chain retry is configured, a retryOn filter was set, the response carried
		 * a numeric status inside Integer range, and that status is not in the filter. Every
		 * unfilterable status — blank, non-numeric, or too many digits for an Integer (isNumeric
		 * cannot see range, so valueOf can still throw) — fails open to retryable: without a
		 * provable status nothing proves the failure deterministic, and a statusless transport
		 * failure must never read permanent.
		 *
		 * @param failedStatusCode The failed call's status code as recorded by the outbound engine.
		 *
		 * @return True when the failure must not be retried.
		 */
		@TestVisible
		private Boolean isPermanentByStatusFilter(String failedStatusCode)
		{
			if(retryMaxAttempts == null || retryMaxAttempts <= 1 || retryableStatusCodes == null)
			{
				return false;
			}
			if(String.isBlank(failedStatusCode) || !failedStatusCode.isNumeric())
			{
				return false;
			}
			try
			{
				return !retryableStatusCodes.contains(Integer.valueOf(failedStatusCode));
			}
			catch(System.TypeException statusOutsideIntegerRange)
			{
				return false;
			}
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
			if(retryableStatusCodes != null)
			{
				config.put('retryableStatusCodes', JSON.serialize(retryableStatusCodes));
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
			String persistedRetryableStatusCodes = (String)config.get('retryableStatusCodes');
			retryableStatusCodes = persistedRetryableStatusCodes == null
					? null
					: (Set<Integer>)JSON.deserialize(persistedRetryableStatusCodes, Set<Integer>.class);

			String handlerClassName = (String)config.get('handlerClassName');
			// Resolver-aware lookup: a raw Type.forName here only sees the kern namespace, so a
			// subscriber-owned handler would survive then() as a name and die at rehydration. The
			// find variant returns null on a miss, preserving this step's graceful failure result.
			Type resolvedHandlerType = UTIL_System.findTypeForClassName(handlerClassName, API_Outbound.class);

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
			if(isPermanentByStatusFilter(handler.result.statusCode))
			{
				return UTIL_AsyncChain.failedPermanently(errorMessage);
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
		 * @description Whether the step author declared the step safe to execute more than once.
		 * Copied from ChainStep.isIdempotent at build time; null = false (suppressed from JSON, so
		 * healthy step logs stay byte-identical to those persisted before this field existed).
		 */
		public Boolean isIdempotent;

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
		 * @description Whether the step's terminal failure was declared permanent (failedPermanently).
		 * Set at runtime only on the terminal failure persist; null = false (suppressed from JSON).
		 */
		public Boolean permanentFailure;

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
			String displayName = resolveStepDisplayName(stepDefinition);
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
				context.currentRetryStrategy = preWorkStrategy;
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
			// Watchdog liveness stamp: the id of the queueable job doing this step's work. CurrentJobId__c
			// has exactly two writer methods — stampExecutorJobId, called at first enqueue and at every
			// watchdog or operator re-enqueue, and the progress write in persistProgressAndChainNext,
			// whose intended field list carries this assignment — so terminal writes leave the last known
			// executor's job id in place, and HandlerExecutor never stamps it (handlers are
			// notifications, not chain executors).
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
			if(result.permanentFailure != true
					&& retryStrategy != null
					&& retryStrategy.shouldRetry(UTIL_Retry.newContext(attemptNumber - 1).withCustomData(result.error)))
			{
				scheduleRetry(execution, context, stepDefinition, retryStrategy, attemptNumber);
				return true;
			}

			// Every path below is a denied retry, so the failure is final; the pre-work stamp could not
			// know that, so correct it before the failure dispatch hands this context to any handler.
			// Standing rule: a path that denies a retry re-stamps finalAttempt first, or documents why not.
			context.finalAttempt = true;

			if(stepDefinition.continueOnError != true)
			{
				// Stamp the declared-permanent marker before this terminal StepLog serialization:
				// handleStepFailure persists the serialized copy verbatim and never re-serializes.
				if(result.permanentFailure == true)
				{
					stepDefinition.permanentFailure = true;
				}
				execution.StepLog__c = serializeStepLog(persistedDefinitions);
				String failureCategory = result.permanentFailure != true && retryStrategy != null && attemptNumber > 1
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
				markStalledAndNotify(executionId, errorMessage, errorHandler, true, capturedRunKey, false);
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
			String failedStepName = resolveStepDisplayName(stepDefinition);
			String persistedContext = serializeContextForFailurePersist(context);
			String terminalMessage = result.message;
			if(persistedContext == null)
			{
				Integer reservedLength =
						UTIL_SObjectDescribe.getCachedFieldDescribe(AsyncChainExecution__c.ErrorMessage__c).length - CONTEXT_NOT_PRESERVED_MARKER.length() - UTIL_String.SPACE.length();
				String abbreviatedBase = UTIL_String.abbreviate(terminalMessage, reservedLength);
				// Blank, not just null: a step that fails with an empty message would otherwise leave the
				// marker behind a separator with nothing in front of it. The platform happens to trim that
				// leading space when it saves the long text area, so the record looks right either way —
				// this builds the message correctly rather than relying on that.
				terminalMessage = (String.isBlank(abbreviatedBase) ? UTIL_String.EMPTY : abbreviatedBase + UTIL_String.SPACE) + CONTEXT_NOT_PRESERVED_MARKER;
			}
			execution.CurrentStepName__c = UTIL_String.abbreviate(failedStepName, AsyncChainExecution__c.CurrentStepName__c);
			execution.Status__c = SEL_AsyncChainExecution.STATUS_FAILED;
			execution.FailureCategory__c = failureCategory;
			execution.ErrorMessage__c = UTIL_String.abbreviate(terminalMessage, AsyncChainExecution__c.ErrorMessage__c);
			execution.CompletedAt__c = Datetime.now();
			execution.ActiveDeduplicationKey__c = null;
			setDuration(execution);
			execution.ContextData__c = persistedContext;

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
	 *   of death. Every chain started on a package version that stamps at enqueue (see
	 *   stampExecutorJobId) carries a stamp, so an unstamped row is one started before stamping
	 *   existed, or one whose start caught the enqueue failure — there is no correlation to
	 *   probe. The sweep degrades to detect-mark-notify — it marks the row Stalled and notifies,
	 *   nothing more — and never re-drives what it cannot prove dead.
	 * - A live job means slow-but-alive: once the budget gates have passed, the sweep leaves the
	 *   row completely untouched — no double-drive, no mark — because duplicate execution of a
	 *   live chain is a worse defect than the stall it would fix. Under exhausted budget even a
	 *   live candidate is parked: probing and notifying both spend the very resources the gates
	 *   just proved absent.
	 * - A dead job, with budget already proven, auto-re-drives via redriveStalledChain. The whole
	 *   probe-and-re-drive leg runs behind the same per-chain try/log discipline as the mark leg —
	 *   see redriveWhenProvablyDead — so one broken row cannot abort the rest of the sweep.
	 *
	 * Residual the threshold carries: the stamped job id is the LAST stamping writer's — the
	 * enqueue-time stamp (stampExecutorJobId, at first enqueue and at every watchdog or operator
	 * re-enqueue), then each progress write. From the second step onward that id lags the live
	 * executor by one step, so the probe can read a dead predecessor while its successor still
	 * runs. The staleness threshold is load-bearing here — configured longer than the longest
	 * legitimate step, the one-step lag window can never look stale.
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
			markStalledFromWatchdog(stale, WATCHDOG_STALL_REASON, resolvePersistedErrorHandler(stale), false);
			return;
		}
		redriveWhenProvablyDead(stale);
	}

	/**
	 * @description Parks a candidate a budget gate refused: the row is routed through the shared
	 * mark sequence with the given parked reason and deliberately NO onError notification —
	 * notifying costs a queueable slot the async gate just proved absent (and with the query
	 * budget this low, any extra work only deepens the shortage). By the same budget argument the
	 * park withholds the unhandled-stall signal too — the ERROR-level stall entry markStalled
	 * records when a chain stalls with no handler: a handler withheld by budget necessity must
	 * never read as a chain that has no handler, so the park's stall entry stays at WARN even for
	 * a handler-less chain. Parking is not a dead end: the row stays Stalled, which keeps it
	 * inside the selector's candidate population — but the park write itself refreshes
	 * LastModifiedDate, so the row re-enters candidacy only after it re-ages past the staleness
	 * threshold, not automatically on the very next sweep. Once it re-ages, a budget-rich sweep
	 * re-processes it, and the single-fire guard still suppresses re-notification because the row
	 * no longer transitions into Stalled.
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
		markStalledFromWatchdog(stale, reason, null, true);
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
	 * False means "no live proof for THIS job id", NOT proof the chain is dead. The record's
	 * stamped id is the LAST stamping writer's job — the enqueue-time stamp (stampExecutorJobId,
	 * at first enqueue and at every watchdog or operator re-enqueue), then each progress write —
	 * so from the second step onward it lags the live executor by one step, and rows created
	 * before the package version that introduced stamping — or by a start that caught its enqueue
	 * failure (see stampExecutorJobId) — carry null.
	 * Callers deciding recovery must therefore treat a null asyncApexJobId as CANNOT-CHECK
	 * (degrade, never re-drive) and pair any re-drive decision with a generous staleness
	 * threshold — longer than the longest legitimate step. A well-formed id that matches no
	 * AsyncApexJob row probes as no-row and is likewise treated as dead; because the framework
	 * stamps the id from its own executor context, that shape is reachable only through a manual
	 * edit of the stamp or the platform purging old AsyncApexJob rows — and in both cases re-drive
	 * is the correct outcome.
	 *
	 * @param asyncApexJobId The stamped executor job id to probe, or null when no stamp has landed (a row created before stamping existed).
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
	 * @param notificationWithheld True when the caller passed null for notificationHandler on
	 * purpose rather than because none exists — a budget park skips the notification to save the
	 * async budget even when the chain has a registered handler. Only a false value can produce
	 * the unhandled-stall ERROR: a park must never be logged as a chain with no handler.
	 */
	private static void markStalledFromWatchdog(AsyncChainExecution__c stale, String reason, DTO_StepDefinition notificationHandler, Boolean notificationWithheld)
	{
		try
		{
			markStalledAndNotify(stale.Id, reason, notificationHandler, false, null, notificationWithheld);
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
	 * @description Resolves the human-readable name of a step entry: the author-supplied stepName
	 * when there is one, the implementing class name otherwise. Single-sourced because the fallback
	 * decides what an admin reads in the performance timer, in a failure's ErrorMessage__c, and in
	 * the operator re-drive log — three surfaces that must never disagree about what a step is
	 * called.
	 *
	 * @param stepDefinition The step entry to name.
	 *
	 * @return The step's display name.
	 */
	private static String resolveStepDisplayName(DTO_StepDefinition stepDefinition)
	{
		return String.isNotBlank(stepDefinition.stepName) ? stepDefinition.stepName : stepDefinition.className;
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
	 * the new key. RunKey__c has exactly five writers — two insert-time minting sites
	 * (ChainBuilder.execute()'s initial stamp and restartChainFromStart's clone) and three
	 * rotations (this one, markRedriveCandidateFailed's terminal-authoritative rotation, and
	 * retryChainFromFailedStep's operator rotation) — no executor write set ever carries the field
	 * (see buildSparseUpdate).
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
	 * A successful re-enqueue immediately stamps the fresh executor's job id onto the record
	 * (stampExecutorJobId), before the WARN emission, so the liveness probe tracks the re-driven
	 * executor from the moment it is enqueued. That closes the window between re-enqueue and the
	 * first progress write, when the record used to carry only the dead predecessor's id: the
	 * probe now proves the re-driven executor's own life or death, so a live-but-slow recovery is
	 * left untouched and a recovery that dies before its first progress write is re-detected
	 * through its own job id, not through a proxy that happens to probe dead.
	 *
	 * If the re-enqueue itself fails after the rotation persisted, the stamp never runs and the
	 * chain is left Running under the new key with no live executor — exactly the shape the next
	 * sweep detects and re-drives: the dead predecessor's stamp is untouched by the rotation write
	 * set and still probes dead. The sweep-side catch (redriveWhenProvablyDead) logs that failure
	 * per chain and moves on, so the enqueue failure costs the sweep nothing beyond this one
	 * candidate's delay.
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

		enqueueRecoveryExecutor(fresh, nextIndex, persistedDefinitions, stepEntries.size());

		LOG_Builder.build().warn('Chain re-driven by watchdog after a stall: resuming at step ' + resolveStepDisplayName(stepEntries[nextIndex]))
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
	 * one of RunKey__c's exactly five writers, beside the two insert-time minting sites
	 * (ChainBuilder.execute, restartChainFromStart's clone) and the other two rotations
	 * (redriveStalledChain, retryChainFromFailedStep) — see buildSparseUpdate.
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
	 * kill-switch aborts. The signal carries the reason verbatim, with no prefix of its own: the
	 * reason is already a full sentence naming the actor, and the Chain Monitor's live activity panel
	 * shows this text to an admin, where a prefix of the framework's own said the same thing twice.
	 * Does not touch RunKey__c: aborting is a status transition, not a rotation, and RunKey__c keeps
	 * its exactly-five writers.
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

		emitTerminalLog(LoggingLevel.WARN, reason, CLASS_NAME + '.abortExecution', executionId);

		return true;
	}

	/**
	 * @description Outcome of a Chain Monitor operator action. refusalCode carries the availability
	 * code the action's own fresh-read re-resolution refused on, or null when the action ran;
	 * resultId carries the record the caller should surface next — the retried execution itself, or
	 * null on refusal. CTRL_ChainMonitor maps every non-null refusalCode to a labeled exception:
	 * Apex is the enforcement point, and button state in the monitor is only a hint.
	 *
	 * @since 1.7
	 */
	public inherited sharing class OperatorActionOutcome
	{
		/**
		 * @description The availability code the action refused on, or null when the action ran.
		 */
		public String refusalCode;

		/**
		 * @description The record the caller should surface after a successful action; null on refusal.
		 */
		public Id resultId;
	}

	/**
	 * @description Builds the refusal outcome of an operator action.
	 *
	 * @param refusalCode The availability code the action's fresh-read re-resolution refused on.
	 *
	 * @return The refusal outcome, with no result record.
	 */
	private static OperatorActionOutcome buildOperatorRefusal(String refusalCode)
	{
		OperatorActionOutcome outcome = new OperatorActionOutcome();
		outcome.refusalCode = refusalCode;
		return outcome;
	}

	/**
	 * @description Builds the success outcome of an operator action.
	 *
	 * @param resultId The record the caller should surface after the action.
	 *
	 * @return The success outcome, with no refusal code.
	 */
	private static OperatorActionOutcome buildOperatorSuccess(Id resultId)
	{
		OperatorActionOutcome outcome = new OperatorActionOutcome();
		outcome.resultId = resultId;
		return outcome;
	}

	/**
	 * @description Resolves whether the chain's STATE permits a retry from its failed step — the
	 * chain-state half of the gate, on the row the caller already holds. The capability-flag and
	 * custom-permission codes are layered by CTRL_ChainMonitor exactly as the abort flow layers
	 * them; retryChainFromFailedStep re-resolves on its own fresh read before acting, so this
	 * resolution is a UI hint and Apex stays the enforcement point.
	 *
	 * Refusal order, most-specific last: not Failed; processing suspended; context or step log
	 * absent, unparseable, or recording no terminal failed step (no trustworthy state to resume
	 * from); failed step declared its failure permanent (a re-run cannot succeed — permanence
	 * outranks the idempotency declaration); failed step never declared isIdempotent (re-running
	 * an undeclared step could double its side effects; pre-upgrade rows always land here, never
	 * null-eligible).
	 *
	 * @param execution The chain execution row to resolve, read through the monitoring projection.
	 *
	 * @return An availability code: Available, or the specific refusal.
	 *
	 * @since 1.7
	 */
	public static String resolveRetryAvailability(AsyncChainExecution__c execution)
	{
		if(execution == null || execution.Status__c != SEL_AsyncChainExecution.STATUS_FAILED)
		{
			return REDRIVE_CHAIN_NOT_RETRYABLE;
		}
		if(!isChainProcessingEnabled())
		{
			return REDRIVE_PROCESSING_SUSPENDED;
		}
		if(String.isBlank(execution.ContextData__c) || String.isBlank(execution.StepLog__c))
		{
			return REDRIVE_CONTEXT_UNAVAILABLE;
		}
		List<DTO_StepDefinition> stepEntries = filterStepEntries(parseStepLog(execution.StepLog__c) ?? new List<DTO_StepDefinition>());
		Integer failedIndex = findTerminalFailedIndex(stepEntries);
		if(failedIndex == null || !contextParsesCleanly(execution))
		{
			return REDRIVE_CONTEXT_UNAVAILABLE;
		}
		if(stepEntries[failedIndex].permanentFailure == true)
		{
			return REDRIVE_FAILURE_PERMANENT;
		}
		if(stepEntries[failedIndex].isIdempotent != true)
		{
			return REDRIVE_STEP_NOT_IDEMPOTENT;
		}
		return REDRIVE_AVAILABLE;
	}

	/**
	 * @description Finds the terminal failed entry in the filtered step entries: the LAST entry
	 * whose marker says it failed without continuing — the step the chain died on. An empty list —
	 * which is what an unparseable step log resolves to at every call site — has no such entry and
	 * returns null, so the resolver's call order stays safe when parsing failed upstream.
	 *
	 * @param stepEntries The filtered chain-step entries; empty when the step log did not parse.
	 *
	 * @return The zero-based index of the terminal failed entry, or null when none exists.
	 */
	private static Integer findTerminalFailedIndex(List<DTO_StepDefinition> stepEntries)
	{
		for(Integer index = stepEntries.size() - 1; index >= 0; index--)
		{
			if(stepEntries[index].success == false && stepEntries[index].continueOnError != true)
			{
				return index;
			}
		}
		return null;
	}

	/**
	 * @description True when the row's persisted context parses as a JSON OBJECT — the one shape
	 * the executor's hydration can rebuild a chain context from. The failure persist stores the
	 * complete context or none, so anything else here means the row predates that rule or was
	 * edited by hand — either way there is no trustworthy state to resume from. Parse-only
	 * acceptance is deliberately NOT enough: a valid JSON list would pass a parse probe, rotate
	 * the run key, flip the row to Running, and then die at executor entry — a Running row with
	 * no live executor. Retry and restart answer this same question through the one shared
	 * predicate (parseContextObject).
	 *
	 * @param execution The chain execution row whose ContextData__c to probe.
	 *
	 * @return True when the context parses as a JSON object.
	 */
	private static Boolean contextParsesCleanly(AsyncChainExecution__c execution)
	{
		return parseContextObject(execution.ContextData__c) != null;
	}

	/**
	 * @description Re-drives a Failed chain from its failed step on an operator's request — the one
	 * path that may re-enter a Failed row, and deliberately NEW machinery beside the watchdog's:
	 * qualifiesForRedrive stays Running/Stalled-only, so nothing automatic can ever resurrect a
	 * terminal chain. Reads fresh through the monitoring selector and re-resolves availability
	 * before acting (the abort double-check posture — the caller's earlier resolution may have
	 * raced another actor), refusing with the code instead of throwing; CTRL_ChainMonitor turns
	 * every refusal into its labeled exception.
	 *
	 * The action is ONE sparse update: the failed entry's runtime markers reset (success, message,
	 * attempt and duration — a fresh attempt budget for the re-run), RunKey__c rotates (fencing any
	 * zombie executor holding the old key; one of the field's exactly five writers), Status__c returns to
	 * Running, and the terminal bookkeeping clears — CompletedAt__c, DurationMs__c,
	 * FailureCategory__c and ErrorMessage__c — in the SAME update, because a Running row with
	 * CompletedAt__c set is purge-eligible while watchdog-invisible, and stale diagnostics would
	 * outlive the state they described. A declared deduplication key re-claims into
	 * ActiveDeduplicationKey__c in the same update; a DUPLICATE_VALUE collision attributed to the
	 * deduplication index (see isActiveDeduplicationKeyCollision) means another live run holds the
	 * key and refuses with DuplicateRun — any other DmlException rethrows.
	 *
	 * The re-run executes under the framework-default envelope exactly as a watchdog re-drive does:
	 * builder-time overrides are not persisted, and the context cap is the larger of the default
	 * and the persisted context's size. Only the failed step re-executes — entries whose markers
	 * survived keep them, so prior work is never repeated. The fresh executor's job id stamps
	 * through stampExecutorJobId before the WARN emission, keeping the liveness probe on the
	 * re-driven executor from the moment it exists.
	 *
	 * @param executionId The Failed AsyncChainExecution__c record to re-drive.
	 *
	 * @return The action outcome: refusalCode null and resultId = the execution id on success.
	 *
	 * @since 1.7
	 */
	public static OperatorActionOutcome retryChainFromFailedStep(Id executionId)
	{
		AsyncChainExecution__c fresh = new SEL_AsyncChainExecution().findByIdForMonitoring(executionId);
		String availability = resolveRetryAvailability(fresh);
		if(availability != REDRIVE_AVAILABLE)
		{
			return buildOperatorRefusal(availability);
		}

		List<DTO_StepDefinition> persistedDefinitions = parseStepLog(fresh.StepLog__c);
		List<DTO_StepDefinition> stepEntries = filterStepEntries(persistedDefinitions);
		Integer failedIndex = findTerminalFailedIndex(stepEntries);
		DTO_StepDefinition failedEntry = stepEntries[failedIndex];
		failedEntry.success = null;
		failedEntry.message = null;
		failedEntry.attempt = null;
		failedEntry.durationMs = null;

		fresh.RunKey__c = UTIL_Random.randomUUID();
		fresh.Status__c = SEL_AsyncChainExecution.STATUS_RUNNING;
		fresh.CompletedAt__c = null;
		fresh.DurationMs__c = null;
		fresh.FailureCategory__c = null;
		fresh.ErrorMessage__c = null;
		fresh.StepLog__c = serializeStepLog(persistedDefinitions);
		List<SObjectField> retryFields = new List<SObjectField>
		{
				AsyncChainExecution__c.RunKey__c,
				AsyncChainExecution__c.Status__c,
				AsyncChainExecution__c.CompletedAt__c,
				AsyncChainExecution__c.DurationMs__c,
				AsyncChainExecution__c.FailureCategory__c,
				AsyncChainExecution__c.ErrorMessage__c,
				AsyncChainExecution__c.StepLog__c
		};
		if(String.isNotBlank(fresh.DeclaredDeduplicationKey__c))
		{
			fresh.ActiveDeduplicationKey__c = fresh.DeclaredDeduplicationKey__c;
			retryFields.add(AsyncChainExecution__c.ActiveDeduplicationKey__c);
		}

		try
		{
			DML_Builder.newTransaction().systemModeInternal().doUpdate(buildSparseUpdate(fresh, retryFields)).execute();
		}
		catch(DmlException updateError)
		{
			if(isActiveDeduplicationKeyCollision(updateError))
			{
				return buildOperatorRefusal(REDRIVE_DUPLICATE_RUN);
			}
			throw updateError;
		}

		enqueueRecoveryExecutor(fresh, failedIndex, persistedDefinitions, stepEntries.size());

		LOG_Builder.build().warn('Chain retried by operator from failed step: ' + resolveStepDisplayName(failedEntry))
				.at(CLASS_NAME + '.retryChainFromFailedStep')
				.forRecord(fresh.Id)
				.emit();

		return buildOperatorSuccess(fresh.Id);
	}

	/**
	 * @description Resolves whether the chain's STATE permits a restart from the start — the
	 * chain-state half of the gate, on the row the caller already holds. Consults ONLY
	 * default-projection fields: the caller's monitoring row deliberately does not carry the
	 * InitialContextData__c snapshot, so snapshot presence is resolved by restartChainFromStart
	 * itself on its dedicated read — this resolution is a UI hint, and Apex stays the enforcement
	 * point. The capability-flag and custom-permission codes are layered by CTRL_ChainMonitor
	 * exactly as the abort flow layers them.
	 *
	 * Refusal order: not Failed or Aborted (only a run that ended badly may be re-run); processing
	 * suspended; allowRestart never declared (re-running a whole undeclared chain could double its
	 * side effects — pre-upgrade rows always land here, never null-eligible).
	 *
	 * @param execution The chain execution row to resolve, read through the monitoring projection.
	 *
	 * @return An availability code: Available, or the specific refusal.
	 *
	 * @since 1.7
	 */
	public static String resolveRestartAvailability(AsyncChainExecution__c execution)
	{
		if(execution == null || !RESTARTABLE_STATUSES.contains(execution.Status__c))
		{
			return RESTART_CHAIN_NOT_RESTARTABLE;
		}
		if(!isChainProcessingEnabled())
		{
			return REDRIVE_PROCESSING_SUSPENDED;
		}
		if(execution.AllowRestart__c != true)
		{
			return RESTART_NOT_DECLARED;
		}
		return RESTART_AVAILABLE;
	}

	/**
	 * @description Restarts a Failed or Aborted chain from its first step on an operator's request
	 * — by CLONING to a fresh record, never by mutating the source: the terminal row keeps its
	 * status, diagnostics and purge eligibility as the audit record of the run that ended badly.
	 * Reads fresh through the dedicated restart projection (the only query that ever pulls the
	 * snapshot), re-resolves availability, and resolves the snapshot-presence and step-log
	 * conjuncts here — the monitoring-row hint cannot see the snapshot by design.
	 *
	 * The clone is built from DECLARATIONS, never from runtime state: a definition-only step log
	 * (an allowlist copy of the configuration properties, so any runtime marker a future release
	 * adds is unset by construction), the as-built InitialContextData__c snapshot as its context —
	 * with the snapshot's logging-context entry REPLACED so the clone's steps hydrate the clone's
	 * own fresh correlation id, never the source's — a fresh RunKey__c minted at insert (one of
	 * the field's five writers), counters at zero, the declaration fields copied so the clone is
	 * itself restartable, and SourceExecution__c stamped so the restart tree stays queryable. A
	 * declared deduplication key re-claims at insert; a DUPLICATE_VALUE collision attributed to
	 * the deduplication index refuses with DuplicateRun — any other DmlException rethrows.
	 *
	 * Order is mandatory, not an optimisation target: insert (the executor constructor needs the
	 * record id), then enqueue at index 0 under the framework-default envelope, then
	 * stampExecutorJobId (the job id exists only after the enqueue; the stamp is the sparse
	 * single-field update). The paired lineage logs — WARN on the source, INFO on the clone — emit
	 * strictly after all DML.
	 *
	 * @param executionId The Failed or Aborted AsyncChainExecution__c record to restart from.
	 *
	 * @return The action outcome: refusalCode null and resultId = the CLONE's id on success.
	 *
	 * @since 1.7
	 */
	public static OperatorActionOutcome restartChainFromStart(Id executionId)
	{
		AsyncChainExecution__c source = new SEL_AsyncChainExecution().findByIdForRestart(executionId);
		String availability = resolveRestartAvailability(source);
		if(availability != RESTART_AVAILABLE)
		{
			return buildOperatorRefusal(availability);
		}
		Map<String, Object> snapshotMap = parseContextObject(source.InitialContextData__c);
		List<DTO_StepDefinition> definitionEntries = buildDefinitionOnlyEntries(parseStepLog(source.StepLog__c) ?? new List<DTO_StepDefinition>());
		List<DTO_StepDefinition> cloneStepEntries = filterStepEntries(definitionEntries);
		if(snapshotMap == null || cloneStepEntries.isEmpty())
		{
			return buildOperatorRefusal(RESTART_CONTEXT_UNAVAILABLE);
		}

		String cloneCorrelationId = UTIL_Random.randomUUID();
		AsyncChainExecution__c clone = new AsyncChainExecution__c(
				ChainName__c = source.ChainName__c,
				Status__c = SEL_AsyncChainExecution.STATUS_RUNNING,
				StartedAt__c = Datetime.now(),
				CompletedSteps__c = 0,
				TotalSteps__c = source.TotalSteps__c,
				CorrelationId__c = cloneCorrelationId,
				RunKey__c = UTIL_Random.randomUUID(),
				AllowRestart__c = true,
				SourceExecution__c = source.Id,
				DeclaredDeduplicationKey__c = source.DeclaredDeduplicationKey__c,
				ActiveDeduplicationKey__c = source.DeclaredDeduplicationKey__c,
				InitialContextData__c = source.InitialContextData__c,
				StepLog__c = serializeStepLog(definitionEntries),
				ContextData__c = rebuildInitialContextForClone(snapshotMap, cloneCorrelationId));

		try
		{
			DML_Builder.newTransaction().systemModeInternal().doInsert(clone).execute();
		}
		catch(DmlException insertError)
		{
			if(isActiveDeduplicationKeyCollision(insertError))
			{
				return buildOperatorRefusal(REDRIVE_DUPLICATE_RUN);
			}
			throw insertError;
		}

		enqueueRecoveryExecutor(clone, RESTART_RESUME_INDEX, definitionEntries, cloneStepEntries.size());

		LOG_Builder.build().warn('Chain restarted from the Chain Monitor as ' + clone.Id)
				.at(CLASS_NAME + '.restartChainFromStart')
				.forRecord(source.Id)
				.emit();
		LOG_Builder.build().info('Chain restarted from ' + source.Id)
				.at(CLASS_NAME + '.restartChainFromStart')
				.forRecord(clone.Id)
				.emit();

		return buildOperatorSuccess(clone.Id);
	}

	/**
	 * @description Counts of what one operator clear-stalled sweep did, for the Chain Monitor's
	 * result toast. The buckets classify each candidate's post-sweep status: redriven counts the
	 * rows a proven-dead candidate's re-drive flipped back to Running, markedFailed counts the
	 * unrecoverable degrades, and remainingStalled holds everything the sweep could not or would
	 * not move — budget-refused candidates, CANNOT-CHECK detect-marks, and live-executor skips
	 * alike; the per-candidate log entries carry each row's specific reason.
	 *
	 * @since 1.7
	 */
	public inherited sharing class ClearStalledResult
	{
		/**
		 * @description How many stalled candidates the sweep inspected, bounded by
		 * MAX_OPERATOR_SWEEP_CANDIDATES; always the sum of the other three counts.
		 */
		public Integer candidates = 0;

		/**
		 * @description How many candidates were proven dead and re-driven — Running again.
		 */
		public Integer redriven = 0;

		/**
		 * @description How many candidates were unrecoverable and terminally failed.
		 */
		public Integer markedFailed = 0;

		/**
		 * @description How many candidates still await recovery: refused by a budget gate,
		 * detect-marked because liveness could not be checked, skipped because a live executor
		 * still runs, left untouched because the calling context cannot read the row (the acting
		 * legs re-read sharing-respecting and never write what they cannot see — and that skip is
		 * silent, so this count is its only trace), or gone from the tally's re-read entirely.
		 */
		public Integer remainingStalled = 0;
	}

	/**
	 * @description Runs the watchdog sweep's per-candidate decision path over every currently
	 * stalled chain, on operator demand from the Chain Monitor: every gate the scheduled sweep
	 * applies, applies here — the same liveness proof, the same budget parks, the same
	 * unrecoverable degrade — because every candidate routes through the same per-candidate
	 * member (sweepCandidate), never a second decision site. Two operator-specific bounds wrap
	 * that shared path: the candidate ceiling (MAX_OPERATOR_SWEEP_CANDIDATES), an entry guard
	 * that returns truthful zero counts when the transaction cannot afford even the sweep's own
	 * two reads, and the per-candidate query and DML reserves, which leave the remaining tail
	 * completely untouched — still Stalled, still candidates for the next invocation or the next
	 * scheduled sweep — rather than spending park writes out of a budget already proven short.
	 * When a reserve stops the sweep early, the summary log entry says so and after how many
	 * candidates: the counts alone cannot distinguish a budget stop from a sweep that found only
	 * live or unprovable chains.
	 *
	 * Package-internal on purpose: CTRL_ChainMonitor is the enforcement point for the
	 * feature-flag, custom-permission, and suspension gates — the same package-internal posture
	 * as abort, plus the suspension interlock that abort deliberately does not carry (stopping
	 * things during a suspension stays coherent; re-driving into one does not).
	 *
	 * @return The per-bucket counts for the operator's result toast.
	 *
	 * @since 1.7
	 */
	public static ClearStalledResult clearStalledChains()
	{
		if(UTIL_Limits.soqlQueries().remaining() < OPERATOR_SWEEP_MINIMUM_QUERIES)
		{
			LOG_Builder.build().warn('Stalled chains cleared by operator: refused at entry, the transaction cannot afford the sweep\'s own candidate and tally reads')
					.at(CLASS_NAME + '.clearStalledChains')
					.emit();
			return new ClearStalledResult();
		}

		List<AsyncChainExecution__c> stalledCandidates = new SEL_AsyncChainExecution().findStalledForOperatorSweep(MAX_OPERATOR_SWEEP_CANDIDATES);
		Integer sweptCandidates = 0;
		for(Integer index = 0; index < stalledCandidates.size(); index++)
		{
			if(UTIL_Limits.soqlQueries().remaining() < OPERATOR_CANDIDATE_QUERY_RESERVE || UTIL_Limits.dmlStatements().remaining() < OPERATOR_CANDIDATE_DML_RESERVE)
			{
				break;
			}
			sweepCandidate(stalledCandidates[index]);
			sweptCandidates++;
		}

		ClearStalledResult result = tallyClearStalledOutcome(stalledCandidates);

		String summaryMessage = 'Stalled chains cleared by operator: ' + result.candidates + ' candidates, ' + result.redriven + ' re-driven, '
				+ result.markedFailed + ' marked failed, ' + result.remainingStalled + ' remaining';
		if(sweptCandidates < result.candidates)
		{
			summaryMessage += ' (budget gate stopped the sweep after ' + sweptCandidates + ' of ' + result.candidates + ' candidates)';
		}
		LOG_Builder.build().warn(summaryMessage)
				.at(CLASS_NAME + '.clearStalledChains')
				.emit();

		return result;
	}

	/**
	 * @description Classifies what the sweep did with each candidate from a single post-sweep
	 * re-read of their current statuses: Running means a re-drive landed, Failed means the
	 * unrecoverable degrade fired, and everything else — including rows the re-read no longer
	 * returns — still awaits recovery. A post-sweep status cannot distinguish a budget park from
	 * a detect-mark (both leave the row Stalled), so those share the remaining bucket and the
	 * per-candidate log entries carry the specific reasons. The re-read projects Status__c only
	 * and respects sharing (findByIdsForSweepTally documents both choices): the classification
	 * reads nothing else, and a row this read cannot see is by construction a row no acting leg
	 * touched — subtraction lands it in remainingStalled either way.
	 *
	 * @param stalledCandidates The candidates the sweep inspected.
	 *
	 * @return The per-bucket counts; candidates always equals the sum of the other three.
	 */
	private static ClearStalledResult tallyClearStalledOutcome(List<AsyncChainExecution__c> stalledCandidates)
	{
		ClearStalledResult result = new ClearStalledResult();
		result.candidates = stalledCandidates.size();
		for(AsyncChainExecution__c swept : new SEL_AsyncChainExecution().findByIdsForSweepTally(new Map<Id, AsyncChainExecution__c>(stalledCandidates).keySet()))
		{
			if(swept.Status__c == SEL_AsyncChainExecution.STATUS_RUNNING)
			{
				result.redriven++;
			}
			else if(swept.Status__c == SEL_AsyncChainExecution.STATUS_FAILED)
			{
				result.markedFailed++;
			}
		}
		result.remainingStalled = result.candidates - result.redriven - result.markedFailed;
		return result;
	}

	/**
	 * @description Whether async chain processing is currently enabled — the AsyncChain feature
	 * flag resolved through its strategies, including the runtime-switch hierarchy setting the
	 * Chain Monitor's suspend and resume actions write. Package-internal consumers (the operator
	 * availability gates, the monitor's operations state) consult this instead of the private
	 * flag constant; the executor's own entry consult stays where it is, at the boundary that
	 * aborts a running chain.
	 *
	 * @return True when chain processing is enabled for the running user's context.
	 *
	 * @since 1.7
	 */
	public static Boolean isChainProcessingEnabled()
	{
		return UTIL_FeatureFlag.isEnabled(FEATURE_FLAG_NAME);
	}

	/**
	 * @description Suspends all async chain processing org-wide by writing the org-default
	 * runtime-switch row to disabled: running chains stop at their next executor entry (the
	 * kill-switch abort) and new chains stop at once, until resumeChainProcessing. User- and
	 * profile-level rows override the org default with hierarchy semantics. The setting write is
	 * the ONLY DML this method performs — hierarchy-setting DML stays isolated from object DML
	 * in one transaction, per the runtime-switch precedent; the WARN entry publishes as a
	 * platform event and costs the transaction no DML.
	 *
	 * @since 1.7
	 */
	public static void suspendChainProcessing()
	{
		writeChainProcessingSwitch(false);

		LOG_Builder.build().warn('Chain processing suspended by operator: running chains stop at their next step boundary, new chains stop at once')
				.at(CLASS_NAME + '.suspendChainProcessing')
				.emit();
	}

	/**
	 * @description Resumes async chain processing by rewriting the org-default runtime-switch row
	 * to enabled: new chains run again at once. Chains that stopped during the suspension stay
	 * stopped — restart or retry the ones that should run. Setting-DML isolation and the
	 * no-DML-cost WARN follow suspendChainProcessing exactly.
	 *
	 * @since 1.7
	 */
	public static void resumeChainProcessing()
	{
		writeChainProcessingSwitch(true);

		LOG_Builder.build().warn('Chain processing resumed by operator')
				.at(CLASS_NAME + '.resumeChainProcessing')
				.emit();
	}

	/**
	 * @description Writes the ORG-default runtime-switch row. getOrgDefaults() returns an unsaved
	 * instance with a null Id when the setting was never initialised, so the write pins
	 * SetupOwnerId to the organisation id — the org hierarchy node, never the running user's own
	 * node — and upsert covers create-and-update in one shape.
	 *
	 * @param enabled The ChainsEnabled__c value to persist on the org-default row.
	 */
	private static void writeChainProcessingSwitch(Boolean enabled)
	{
		AsyncChainRuntimeSwitch__c orgDefault = AsyncChainRuntimeSwitch__c.getOrgDefaults();
		if(orgDefault.Id == null)
		{
			orgDefault.SetupOwnerId = UserInfo.getOrganizationId();
		}
		orgDefault.ChainsEnabled__c = enabled;
		DML_Builder.newTransaction().systemModeInternal().doUpsert(orgDefault).execute();
	}

	/**
	 * @description Parses a persisted context document into its map form, refusing corruption:
	 * null when the document is blank, is not JSON, or is not a JSON object — the shapes a chain
	 * context cannot be rebuilt from. The ONE parse-strictness predicate for both operator
	 * re-entry paths: the restart clone builds from the map it returns, and the retry gate
	 * (contextParsesCleanly) accepts a row only when this returns non-null, so the two gates can
	 * never drift apart in what they admit.
	 *
	 * @param contextDocument The persisted context document (ContextData__c or InitialContextData__c).
	 *
	 * @return The document as a map, or null when no trustworthy context exists.
	 */
	private static Map<String, Object> parseContextObject(String contextDocument)
	{
		if(String.isBlank(contextDocument))
		{
			return null;
		}
		try
		{
			return (Map<String, Object>)JSON.deserializeUntyped(contextDocument);
		}
		catch(Exception parseError)
		{
			return null;
		}
	}

	/**
	 * @description Builds the clone's definition-only step log entries: for each persisted entry a
	 * NEW definition copying ONLY the configuration properties — className, stepName,
	 * continueOnError, isIdempotent and the handler flags. An ALLOWLIST by design, never a
	 * denylist scrub: every runtime marker, including any marker a future release adds, is unset
	 * by construction, so executed state can never ride into a fresh clone.
	 *
	 * @param persistedDefinitions The source run's parsed step log.
	 *
	 * @return New definition entries carrying configuration only.
	 */
	private static List<DTO_StepDefinition> buildDefinitionOnlyEntries(List<DTO_StepDefinition> persistedDefinitions)
	{
		List<DTO_StepDefinition> definitionEntries = new List<DTO_StepDefinition>();
		for(DTO_StepDefinition persisted : persistedDefinitions)
		{
			DTO_StepDefinition definition = new DTO_StepDefinition();
			definition.className = persisted.className;
			definition.stepName = persisted.stepName;
			definition.continueOnError = persisted.continueOnError;
			definition.isIdempotent = persisted.isIdempotent;
			definition.isErrorHandler = persisted.isErrorHandler;
			definition.isCompletionHandler = persisted.isCompletionHandler;
			definitionEntries.add(definition);
		}
		return definitionEntries;
	}

	/**
	 * @description Rebuilds the as-built snapshot as the clone's starting context: every snapshot
	 * value survives untouched except the reserved logging-context entry, which is REPLACED with a
	 * minimal document carrying the clone's own correlation id — two live runs sharing a
	 * correlation id would corrupt the log trace and the monitor deep-links, so the clone's steps
	 * must hydrate the clone's identity, never the source's. The replacement document comes from
	 * the logging framework's own serializer (LOG_Builder.serializeContext for a supplied id), so
	 * its shape can never drift from what the executor's hydration reads.
	 *
	 * Builds its own copy rather than editing the caller's map: a method named for rebuilding a
	 * value should not quietly rewrite its argument.
	 *
	 * @param snapshotMap The parsed as-built snapshot.
	 * @param cloneCorrelationId The clone's freshly minted correlation id.
	 *
	 * @return The serialized starting context for the clone.
	 */
	private static String rebuildInitialContextForClone(Map<String, Object> snapshotMap, String cloneCorrelationId)
	{
		Map<String, Object> cloneContext = new Map<String, Object>(snapshotMap);
		cloneContext.put(LOG_CONTEXT_KEY, LOG_Builder.serializeContext(cloneCorrelationId));
		return JSON.serialize(cloneContext);
	}

	/**
	 * @description The one shared stall sequence. Both stall writers — the Finalizer (after a
	 * transient enqueue failure) and the watchdog sweep — route through here; nothing calls the
	 * bare markStalled writer directly, because that writer carries no fence and no notification
	 * deduplication of its own. The sequence: a fresh re-read of the execution record, an
	 * authorization check, a prior-status snapshot, the sparse Status__c / FailureCategory__c /
	 * ErrorMessage__c write, then the conditional notification step. A failed stall write
	 * propagates to the caller before the notification step, so the notification is skipped and
	 * the caller owns the failure logging.
	 *
	 * Authorization differs by caller. The Finalizer passes enforceRunKeyFence=true and is
	 * authorized by run-key equality against the fresh read (see buildSparseUpdate for why
	 * executor writes must fence). The watchdog passes false — the sweep is the recovery
	 * authority and needs no fence — but it refuses rows that reached a terminal status
	 * (Completed, Failed or Aborted) between its selector read and this re-read: it may only
	 * touch recoverable rows. Both callers refuse an already-Aborted row before that split,
	 * because an operator abort does not rotate the run key, so the Finalizer's fence alone
	 * cannot detect it.
	 *
	 * The notification guard is per-transition, not per-chain: it fires only on an actual change
	 * into Stalled observed in the same fresh re-read. A chain already Stalled that is marked
	 * again never re-notifies; a chain re-driven back to Running that stalls again legitimately
	 * notifies again. On a genuine transition with no resolvable handler and none withheld, the
	 * stall log entry is recorded at ERROR instead of WARN (see markStalled) so an unhandled
	 * stall surfaces by default.
	 *
	 * Residual: notification delivery is at-least-once. An enqueued notification is not un-sent
	 * if later writes fail, so onError handlers must tolerate duplicate stall notifications.
	 *
	 * @param executionId The chain execution record ID.
	 * @param errorMessage The stall reason.
	 * @param notificationHandler The onError handler definition to notify once per transition, or null for none.
	 * @param enforceRunKeyFence Whether the write is fenced by a captured run key (the Finalizer) or unfenced (the watchdog).
	 * @param fenceRunKey The run key captured at enqueue time; compared against the fresh read when the fence is enforced.
	 * @param notificationWithheld True when the caller passed null for notificationHandler on
	 * purpose rather than because none exists — a budget park skips the notification to save the
	 * async budget even when the chain has a registered handler. Only a false value can produce
	 * the unhandled-stall ERROR: a park must never be logged as a chain with no handler.
	 */
	private static void markStalledAndNotify
			(
					Id executionId,
					String errorMessage,
					DTO_StepDefinition notificationHandler,
					Boolean enforceRunKeyFence,
					String fenceRunKey,
					Boolean notificationWithheld
			)
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
		Boolean unhandledStallTransition = stallTransition && notificationHandler == null && !notificationWithheld;

		markStalled(execution, errorMessage, unhandledStallTransition);

		if(stallTransition)
		{
			enqueueRecoveryErrorHandler(execution, errorMessage, notificationHandler, SEL_AsyncChainExecution.STATUS_STALLED);
		}
	}

	/**
	 * @description Marks the execution as Stalled with the given reason and logs the stall — at
	 * ERROR when the transition is a genuine unhandled stall, at WARN otherwise.
	 * Stalled is non-terminal — the chain awaits recovery — so CompletedAt__c and DurationMs__c
	 * stay unset and no performance log is emitted; a later re-drive finishes the chain and
	 * stamps its terminal fields then.
	 *
	 * @param execution The AsyncChainExecution__c record to update.
	 * @param message The stall reason to record.
	 * @param unhandledStallTransition True for a genuine transition into Stalled with no resolvable onError handler and no notification withheld by a budget park
	 * (see parkWithReason) — the one case recorded at ERROR so it stands out; every other stall keeps WARN.
	 */
	private static void markStalled(AsyncChainExecution__c execution, String message, Boolean unhandledStallTransition)
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

		LOG_Builder.LogEntry stallLog = unhandledStallTransition
				? LOG_Builder.build().error('Chain stalled with no onError handler registered: ' + message)
				: LOG_Builder.build().warn('Chain stalled: ' + message);
		stallLog.at(CLASS_NAME + '.markStalled')
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
	 * this executor's read. RunKey__c belongs in no executor write set — its exactly five writers
	 * are two insert-time minting sites (ChainBuilder.execute()'s initial insert,
	 * restartChainFromStart's clone insert) and three rotations (redriveStalledChain's rotation
	 * write set, markRedriveCandidateFailed's terminal-authoritative rotation,
	 * retryChainFromFailedStep's operator rotation) — rotation never rides an executor persist;
	 * Status__c belongs only in the write sets of status-transition sites; CurrentJobId__c has
	 * exactly two writer methods — stampExecutorJobId, called at first enqueue and at every
	 * watchdog or operator re-enqueue, and the progress write's set — so terminal writes leave the
	 * last known executor's job id in place for the watchdog's liveness check. Precondition: every
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
	 * @description Stamps the just-enqueued executor's AsyncApexJob id onto the run record so the
	 * watchdog's liveness probe (isExecutorLive) can prove death for chains that have not yet
	 * reached a progress write: a chain still on its first step, a single-step chain that never
	 * progress-writes at all, or a chain just re-driven. CurrentJobId__c has exactly two writer
	 * methods — this one and the progress write. This one is called from all four CHAIN-ENTRY
	 * enqueues, the points where a chain starts or restarts running: the first enqueue
	 * (ChainBuilder.execute), the watchdog re-drive (redriveStalledChain), the operator retry
	 * (retryChainFromFailedStep) and the operator restart's clone (restartChainFromStart). The
	 * file's other enqueues deliberately do not stamp: the mid-chain hop and the retry link inside
	 * ChainExecutor.Finalizer are already tracked by the progress write (whose one-step lag is
	 * documented at isExecutorLive), and the handler enqueue never stamps because handlers are
	 * notifications, not chain executors.
	 *
	 * Runs after the enqueue succeeded, an ordering that keeps the stamp safe at every call site.
	 * At first enqueue — same transaction as the run-record insert — an enqueue failure that
	 * propagates uncaught rolls the whole start back, so no stamp can outlive its job; a caller
	 * that catches that failure instead commits a Running row with a null stamp, which the sweep
	 * treats as CANNOT-CHECK — degrade, never proof of death (see sweepCandidate); and because the
	 * row is invisible outside the start transaction until it commits, no concurrent run-key
	 * rotation can interleave with the stamp. At a watchdog re-drive enqueue, an enqueue failure
	 * means the stamp never runs, so the dead predecessor's stamp stays in place and still probes
	 * dead — the next sweep re-detects the row (see redriveStalledChain). At the operator retry an
	 * enqueue failure that propagates uncaught rolls the whole action back, so the row simply stays
	 * Failed (see retryChainFromFailedStep). At the operator restart the clone insert shares that
	 * transaction, so the same rollback removes the clone entirely and no unstamped orphan survives
	 * (see restartChainFromStart). A caller that catches either failure instead commits the row it
	 * had reached — a Running chain with a null stamp — which the sweep treats as CANNOT-CHECK,
	 * exactly as at first enqueue. The sparse write carries only CurrentJobId__c per the
	 * executor-persist discipline (see buildSparseUpdate). A delayed first enqueue stamps too: the
	 * job holds a live Queued status through its delay window, so the probe reads slow-but-alive,
	 * never a false re-drive.
	 *
	 * @param execution The run record to stamp: the just-inserted row at a first enqueue or a restart clone, or the fresh re-read at a re-drive.
	 * @param executorJobId The enqueued executor's AsyncApexJob id.
	 */
	private static void stampExecutorJobId(AsyncChainExecution__c execution, Id executorJobId)
	{
		execution.CurrentJobId__c = executorJobId;
		DML_Builder.newTransaction().systemModeInternal().doUpdate(buildSparseUpdate(execution, new List<SObjectField> {AsyncChainExecution__c.CurrentJobId__c})).execute();
	}

	/**
	 * @description Enqueues a rehydrated executor for a chain re-entering execution, and stamps the
	 * job id — the ONE recovery envelope shared by all three re-entry paths (the watchdog re-drive,
	 * the operator retry, the operator restart). It exists so that envelope has a single definition:
	 * a re-entering run executes under FRAMEWORK DEFAULTS, because the original run's AsyncOptions
	 * and builder overrides were never persisted. That is the documented recovery-defaults semantics
	 * the subscriber guides state, so it must not drift per path. Concretely: DEFAULT_MAX_STEPS, a
	 * context cap floored at the persisted document's own length (so a context already larger than
	 * the default is never truncated on resume), a stack depth reserving one hop per remaining entry
	 * plus the executor itself, and one AsyncOptions instance serving as BOTH the enqueue options
	 * and the baton the executor carries forward. Handlers are resolved from the persisted
	 * definitions rather than re-derived, so a re-entering run keeps the handlers it was built with.
	 *
	 * The stamp lands strictly AFTER the enqueue — the job id does not exist before it — and is a
	 * single-field sparse update, so it can never revert a concurrent rotation (see
	 * stampExecutorJobId for the per-call-site failure analysis).
	 *
	 * Precondition the caller owns: the record's run-key rotation (or its insert) is already
	 * committed, so the key this executor is fenced on is the key the row now carries.
	 *
	 * @param execution The run record whose executor is enqueued; supplies the id, the context document and the authoritative run key.
	 * @param resumeIndex The step index the executor resumes at.
	 * @param persistedDefinitions The persisted definition list the error and completion handlers are resolved from.
	 * @param remainingStepCount The number of chain-step entries the run still has to execute.
	 */
	private static void enqueueRecoveryExecutor(AsyncChainExecution__c execution, Integer resumeIndex, List<DTO_StepDefinition> persistedDefinitions, Integer remainingStepCount)
	{
		Integer effectiveMaxContextSize = Math.max(DEFAULT_MAX_CONTEXT_SIZE, execution.ContextData__c?.length() ?? 0);
		AsyncOptions options = new AsyncOptions();
		options.maximumQueueableStackDepth = remainingStepCount + 1;
		Id executorJobId = System.enqueueJob
				(
						new ChainExecutor
								(
										execution.Id, resumeIndex, DEFAULT_MAX_STEPS, effectiveMaxContextSize,
										findPersistedErrorHandler(persistedDefinitions),
										findPersistedCompletionHandler(persistedDefinitions),
										options, execution.RunKey__c
								),
						options
				);
		stampExecutorJobId(execution, executorJobId);
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
				'data' => result.data,
				'permanentFailure' => result.permanentFailure
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
			previous.permanentFailure = resultMap.get('permanentFailure') == true;
			context.setPreviousStepResult(previous);
			context.data.remove(PREVIOUS_RESULT_KEY);
		}
	}
}