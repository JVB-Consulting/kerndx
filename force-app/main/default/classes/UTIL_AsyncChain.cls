// SPDX-License-Identifier: Apache-2.0
/**
 * @description Lightweight async chain runner for sequencing jobs with shared state, error handling,
 * and progress tracking. Delegates to existing async and logging infrastructure. Each step runs in a queueable
 * job of its own; the comments in this class call one such job a hop.
 *
 * @see UTIL_AsyncChain_TEST
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
	 * @description Text added to the end of ErrorMessage__c when a failing chain's context was too large
	 * for the ContextData__c field. The failure write saves the whole context or nothing, never a cut-short
	 * copy, so in that case nothing is saved. This marker is the only sign of that loss on the record.
	 * Without a saved context, a retry from the failed step has no state to resume from.
	 *
	 * @since 1.7
	 */
	@TestVisible
	private static final String CONTEXT_NOT_PRESERVED_MARKER = '[Context too large to preserve: retry from failed step unavailable]';

	/**
	 * @description Failure message written when a hop cannot create a step again from its class name:
	 * {0} is the class name, {1} the platform's own message. It states the rule a subscriber needs. The
	 * class must exist, must be a chain step, and must declare no constructor of its own. From inside the
	 * package, the platform can call only the implicit constructor of a class that declares none, or a
	 * global constructor on a global class.
	 */
	@TestVisible
	private static final String STEP_NOT_CREATABLE_MESSAGE =
			'Failed (Cannot create step {0}). The framework recreates each step by class name, so the class must exist, be a chain step, '
			+ 'and declare no constructor of its own (only a global class may declare a global one). Cause: {1}';

	/**
	 * @description The log message written when a run is launched while a correlation ID is already active. It goes
	 * into the launcher's log, under the launcher's correlation ID: {0} the chain name, {1} the correlation ID the run
	 * is recorded under, {2} the correlation ID it was launched under.
	 *
	 * @since 1.8
	 */
	private static final String CHAIN_LAUNCHED_MESSAGE =
			'Chain {0} launched under correlation {2}; its run is recorded under correlation {1}.';

	/**
	 * @description Refusal raised when a launch supplies a correlation another chain execution
	 * already holds: {0} is the correlation, {1} the holder, named as precisely as the caller's access
	 * allows. CorrelationId__c is a unique field. The platform hides which field and which record clashed,
	 * so without this message the caller gets a duplicate-value error that names nothing. This message
	 * states the rule and the way out instead.
	 *
	 * @since 1.7
	 */
	private static final String CORRELATION_COLLISION_MESSAGE =
			'Correlation {0} is already attached to {1}. A chain run owns its correlation exclusively, so give this chain '
			+ 'one of its own: pass a distinct id to execute(correlationId).';

	/**
	 * @description Holder wording for a correlation whose owning run the caller can see, so the
	 * refusal can name it: {0} is that run's record id.
	 *
	 * @since 1.7
	 */
	private static final String CORRELATION_HOLDER_NAMED = 'chain execution {0}';

	/**
	 * @description Holder wording for a correlation whose owning run the caller cannot see. It names no
	 * record on purpose. A read that respects sharing came back empty, and that is the same reason the
	 * platform hides the record id in the duplicate-value error. Naming the record would show the caller
	 * something sharing hides from them, so the refusal states the rule and the remedy instead.
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
	 * @description Number of characters per step that the execute() check holds back from the StepLog__c
	 * capacity. As steps run, each entry gains runtime members that were left out (because they were null)
	 * when the chain was built. The safety valve (the rewrite that drops step messages when the log grows too
	 * large) cannot drop these members. They are:
	 * `,"started":true` (15 characters, written by the hop before the step's own hop),
	 * `,"success":false` (16), `,"durationMs":` with its value (14 plus the digits), `,"attempt":99`
	 * (13, two digits) and, on a final failure, `,"permanentFailure":true` (24). On a step the watchdog
	 * refused to run again, `,"recoveryRefused":true` (23) comes instead of the permanent marker, so that
	 * step's worst case is 88. The realistic worst case is 89 characters. A step's duration is the time of
	 * its own transaction, so it has at most seven digits (under 10,000 seconds), and the reserve keeps
	 * eleven characters spare. On paper the figure is 101, with the 19 digits a Long can hold, but that
	 * cannot happen for the same reason. Because the runtime members are reserved up front, the valve's
	 * rewrite without messages always fits the field, for the whole life of the chain. The reserve counts
	 * chain steps only. The handler entries saved after the steps never gain runtime members, because the
	 * handler executor does not write the step log. Their fixed size still counts against the capacity the
	 * check measures. An operator's retry adds `,"manualRetryAfterMs":` and its value to the retried entry
	 * only when the log keeps this reserve free for every step that has not yet recorded a result (see
	 * serializeStepLogForManualRetry). So that marker never uses up the reserve.
	 */
	private static final Integer STEP_RUNTIME_RESERVE_LENGTH = 100;

	/**
	 * @description The longest duration DurationMs__c can store. The field is Number(10,0), so 9,999,999,999 milliseconds, about
	 * 115.7 days, and it is released, so it is never retyped. A run that took longer stores this value, which still reads true
	 * as "at least": without the cap its terminal write is refused and the run can never record its end.
	 *
	 * @since 1.8
	 */
	private static final Long STORED_DURATION_MAX_MILLISECONDS = 9999999999L;

	/**
	 * @description The wait an operator's retry records on the retried step when the instant the run failed is not known: the
	 * row carries no completion timestamp, or one later than the retry. The step was retried manually, and how long it waited
	 * is not known. A real wait is never negative, so the two never collide; the Chain Monitor's controller reads
	 * any negative value as a marker without a wait, and the step timeline never receives the number.
	 *
	 * @since 1.8
	 */
	private static final Long MANUAL_RETRY_WAIT_UNKNOWN = -1L;

	/**
	 * @description Maximum length of an active-run deduplication key, matching the ActiveDeduplicationKey__c field
	 * capacity so withDeduplicationKey rejects at build time any key the write at start could not save in full.
	 */
	private static final Integer DEDUPLICATION_KEY_MAX_LENGTH = 255;

	/**
	 * @description This class's fully-qualified name, worked out once. It is the prefix of the classMethod
	 * value on every log entry this class writes.
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
	 * @description Extra queueable stack depth a retry adds when it queues the step again, on top of the saved
	 * step count. The depth set when the chain started does not count retries, so this leaves room for them.
	 * It caps how deep the run may grow; it does not reserve anything. A chain that retries so often that it
	 * uses up the queueable stack depth becomes Stalled, and the watchdog recovers it from a new first job.
	 * A retry never lowers the depth in the executor's own options, so a chain launched deep inside another
	 * chain keeps the room its launch reserved.
	 */
	private static final Integer RETRY_STACK_DEPTH_ALLOWANCE = 20;

	/**
	 * @description How deep chains may nest: a chain launched from a step or a handler of another chain sits one level
	 * below its launcher, and the first chain of an action sits at level zero, so the sixth launch in a line of
	 * launches is refused before anything is written. A fixed framework limit beside the platform's queueable stack
	 * depth, so a step that launches its own chain by mistake stops here rather than at the org's daily async budget.
	 *
	 * @since 1.8
	 */
	private static final Integer MAXIMUM_NESTING_DEPTH = 5;

	/**
	 * @description The launch position recorded for a chain a completion handler launches, in place of a step index. A
	 * run's completion handler and its error handler each launch one chain of their own, so their positions differ.
	 *
	 * @since 1.8
	 */
	private static final String COMPLETION_HANDLER_POSITION = 'onComplete';

	/**
	 * @description The launch position recorded for a chain an error handler launches, whether it runs on a terminal
	 * failure or as a stall notification: the same handler, so the same one chain.
	 *
	 * @since 1.8
	 */
	private static final String ERROR_HANDLER_POSITION = 'onError';

	/**
	 * @description The maximum queueable stack depth a stall notification handler is enqueued with: its own hop, one
	 * level for a chain it launches, and the nesting reserve for the chains that chain's steps launch, the same room
	 * every handler and every framework-launched chain gets.
	 *
	 * @since 1.8
	 */
	private static final Integer NOTIFICATION_HANDLER_STACK_DEPTH = 2 + MAXIMUM_NESTING_DEPTH;

	/**
	 * @description Refusal raised when a launch from inside a chain job would nest deeper than the framework allows:
	 * {0} the chain name, {1} the level the new run would sit at, {2} the deepest level allowed.
	 *
	 * @since 1.8
	 */
	private static final String NESTING_DEPTH_EXCEEDED_MESSAGE =
			'Chain {0} cannot be launched from here: it would sit {1} levels below the first chain of the action, and chains '
			+ 'may nest at most {2} levels deep. Launch it from the action that started the first chain instead.';

	/**
	 * @description Refusal raised when a launch from inside a chain job finds no spare queueable stack level for the
	 * child's first hop: {0} the chain name, {1} the launching run's record id, {2} the depth the launching job runs
	 * at, {3} the maximum allowed for its group of jobs (the jobs queued one from another, from the same first job). A
	 * job started from inside a running job takes over that group's maximum and cannot set its own. So the child's
	 * first hop must fit under the launcher's maximum. The framework's default leaves room for that; a caller's own AsyncOptions may not.
	 *
	 * @since 1.8
	 */
	private static final String STACK_DEPTH_EXHAUSTED_MESSAGE =
			'Chain {0} cannot be launched from run {1}: the running job sits at queueable stack depth {2} of a maximum of {3}, '
			+ 'leaving no level for the new chain\'s first step. Raise maximumQueueableStackDepth on the chain running this '
			+ 'step, or launch the chain from outside it.';

	/**
	 * @description Refusal raised when a step or handler launches a second chain: any chain in the same transaction
	 * (the platform lets a running job add one queueable job, so the second chain could never run), or a different
	 * chain from the one it launched before (the framework remembers the one child a step launched under the step's own
	 * key, so a second chain would otherwise be answered with the first child's id and never run). {0} the chain
	 * refused, {1} the child already launched, worded by LAUNCHED_CHILD_NAMED or LAUNCHED_CHILD_UNNAMED.
	 *
	 * @since 1.8
	 */
	private static final String SECOND_LAUNCH_MESSAGE =
			'Chain {0} cannot be launched from here: this step or handler already launched {1}, and a step or handler may '
			+ 'launch one chain. Launch it from another step, or from the action that started the first chain.';

	/**
	 * @description Wording for a launched child the caller can see: {0} its chain name, {1} its run's record id.
	 *
	 * @since 1.8
	 */
	private static final String LAUNCHED_CHILD_NAMED = 'chain {0} (run {1})';

	/**
	 * @description Wording for a launched child the caller cannot see, deliberately unnamed for the reason
	 * CORRELATION_HOLDER_UNNAMED gives: a sharing-respecting read came back empty.
	 *
	 * @since 1.8
	 */
	private static final String LAUNCHED_CHILD_UNNAMED = 'another chain';

	/**
	 * @description Refusal raised when a launch from inside a chain job finds the job's one queueable enqueue already
	 * used, checked before anything is written so no run record is left Running with no job behind it: {0} the chain
	 * name, {1} the launching run's record id.
	 *
	 * @since 1.8
	 */
	private static final String ENQUEUE_ALREADY_USED_MESSAGE =
			'Chain {0} cannot be launched from run {1}: the running step or handler has already added its one queueable job. '
			+ 'Launch the chain before adding that job, or from a step of its own.';

	/**
	 * @description Refusal raised when a launch from inside a queueable job that is not a chain job finds the job's one
	 * queueable enqueue already used, checked before anything is written so no run record is left Running with no job
	 * behind it: {0} the chain name.
	 *
	 * @since 1.10
	 */
	private static final String LAUNCHING_JOB_ENQUEUE_ALREADY_USED_MESSAGE =
			'Chain {0} cannot be launched from here: the running queueable job has already added its one queueable job. '
			+ 'Launch the chain before adding that job, or from a job of its own.';

	/**
	 * @description Refusal raised when a launch from inside a queueable job that is not a chain job finds no spare
	 * queueable stack level for the chain's first hop: {0} the chain name, {1} the depth the running job sits at, {2}
	 * the maximum its group of jobs (the jobs queued one from another, from the same first job) was given. A job inside
	 * such a group cannot set a maximum of its own, so the chain's first hop must fit under the one the group has.
	 *
	 * @since 1.10
	 */
	private static final String LAUNCHING_JOB_STACK_DEPTH_EXHAUSTED_MESSAGE =
			'Chain {0} cannot be launched from here: the running job sits at queueable stack depth {1} of a maximum of {2}, '
			+ 'leaving no level for the new chain\'s first step. Raise maximumQueueableStackDepth on the job that runs this '
			+ 'code, or launch the chain from outside it.';

	/**
	 * @description Reserved context key for persisting the previous step result across async transactions.
	 */
	private static final String PREVIOUS_RESULT_KEY = '__previousStepResult';

	/**
	 * @description The step or handler running in this transaction, or null outside a chain job. Set by the executors
	 * around the work they run and cleared after it, so a launch made inside that work takes the nested path.
	 *
	 * @since 1.8
	 */
	private static RunningStep runningStep;

	/**
	 * @description Reserved context key for persisting the LOG_Builder context (correlation, parent transaction, context data).
	 */
	private static final String LOG_CONTEXT_KEY = '__logContext';

	/**
	 * @description Reserved context key carrying a run's nesting depth: zero for a chain launched outside any chain job,
	 * the launcher's depth plus one for a chain a step or a handler launched. A run whose context has no such key
	 * counts as zero.
	 *
	 * @since 1.8
	 */
	private static final String NESTING_DEPTH_KEY = '__nestingDepth';

	/**
	 * @description Feature flag name used for the global async chain kill switch.
	 */
	@TestVisible
	private static final String FEATURE_FLAG_NAME = 'AsyncChain';

	/**
	 * @description Developer name of the feature flag gating the operator abort capability. The
	 * flag's strategy names the custom permission; the controller and the health check both read
	 * this constant, so the name is spelled in one place only.
	 */
	public static final String ABORT_FEATURE_FLAG_NAME = 'AsyncChainAbort_Enabled';

	/**
	 * @description Developer name of the custom permission the abort flag's strategy checks. The
	 * health check and the abort test suite resolve grants of this permission by this constant, so
	 * the name is spelled in one place only.
	 */
	public static final String ABORT_CUSTOM_PERMISSION_NAME = 'AbortAsyncChain';

	/**
	 * @description API name of the permission set that is the designed source of the abort custom
	 * permission. Package installs also write the permission into profiles; this permission set is
	 * the assignment route the framework recommends and the health check verifies.
	 */
	public static final String ABORT_PERMISSION_SET_NAME = 'AsyncChainAbort';

	/**
	 * @description Developer name of the feature flag that controls the operator re-drive actions. A re-drive
	 * runs a stopped chain again: retry from the failed step, restart from the start, or clear stalled. The flag's strategy
	 * names the re-drive custom permission; the controller reads this constant, so the name is
	 * spelled in one place only.
	 *
	 * @since 1.7
	 */
	public static final String REDRIVE_FEATURE_FLAG_NAME = 'AsyncChainRedrive_Enabled';

	/**
	 * @description Developer name of the custom permission the re-drive flag's strategy checks.
	 * The re-drive test suite resolves grants of this permission by this constant, so the name is
	 * spelled in one place only.
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
	 * @description Developer name of the feature flag that controls the operator kill-switch toggle, which
	 * suspends and resumes all chain processing. It is kept apart from re-drive on purpose: the toggle
	 * affects the whole org, so it has its own flag, permission and permission set.
	 *
	 * @since 1.7
	 */
	public static final String KILL_SWITCH_TOGGLE_FEATURE_FLAG_NAME = 'AsyncChainKillSwitch_Enabled';

	/**
	 * @description Developer name of the custom permission the kill-switch flag's strategy checks.
	 * The re-drive test suite resolves grants of this permission by this constant, so the name is
	 * spelled in one place only.
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
	 * @description Availability code: the chain's state permits the operator re-drive action.
	 * A machine code shared by the method that works out availability, the action's own second check,
	 * and the Chain Monitor's label mapping. It is never shown to a user directly.
	 *
	 * @since 1.7
	 */
	public static final String REDRIVE_AVAILABLE = 'Available';

	/**
	 * @description Availability code: the chain is not in the Failed state the retry action
	 * starts from. Runs still in progress and runs that ended any other way can never be retried.
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
	 * @description Availability code: chain processing is suspended for the whole org. A re-drive would
	 * only create runs that the kill switch aborts as soon as their next job starts.
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
	 * A machine code shared by the method that works out availability, the action's own second check,
	 * and the Chain Monitor's label mapping. It is never shown to a user directly.
	 *
	 * @since 1.7
	 */
	public static final String RESTART_AVAILABLE = 'Available';

	/**
	 * @description The step index where the executor of a restart copy starts. A restart always runs from
	 * the beginning, so this is always the first entry. The watchdog re-drive and the operator retry are
	 * different: each works out its index from the saved step log.
	 *
	 * @since 1.7
	 */
	private static final Integer RESTART_RESUME_INDEX = 0;

	/**
	 * @description Availability code: the chain is not in a state a restart may act on. Only a
	 * run that ended badly, Failed or Aborted, can be run again from the start.
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
	 * @description Availability code: the copy of the context saved when the chain was built, or the step
	 * log, is missing, cannot be parsed, or holds no step that can run. So no restart copy can be built from it.
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
	 * @description Stall reason the watchdog sweep records on each stale candidate it marks. The watchdog
	 * sweep is the scheduled job that looks for chains that stopped moving.
	 */
	private static final String WATCHDOG_STALL_REASON = 'No live executor detected by watchdog sweep';

	/**
	 * @description Stall reason the sweep's async-budget check records when it parks a candidate,
	 * because the transaction has no queueable budget left to process it safely. To park a run is to
	 * leave it Stalled with a reason, so a later sweep picks it up again.
	 */
	private static final String WATCHDOG_PARKED_REASON = 'Parked: no async budget';

	/**
	 * @description Stall reason the sweep's query-budget check records when it parks the remaining
	 * candidates because the transaction is nearly out of database queries.
	 */
	private static final String WATCHDOG_PARKED_QUERY_BUDGET_REASON = 'Parked: no query budget';

	/**
	 * @description Terminal failure reason recorded when a re-drive candidate's persisted step log
	 * cannot be rebuilt into a chain that can run. Terminal on purpose: an unreadable step log never
	 * repairs itself, so the chain needs human attention, not another sweep.
	 */
	private static final String REDRIVE_UNRECOVERABLE_REASON =
			'Watchdog re-drive abandoned: the persisted step log is missing, unreadable, or inconsistent with recorded progress. Review the chain and start a replacement.';

	/**
	 * @description Upper limit on the number of chains one watchdog sweep may process. Each stale row
	 * costs the sweep up to two queries and one update, plus a notification or an executor enqueue.
	 * A batch with no limit would use up a per-transaction governor limit in the middle of the sweep.
	 * That raises a LimitException, which cannot be caught: it rolls back the whole sweep, and the same
	 * thing happens every time the sweep runs. It would happen exactly when many chains stall at once,
	 * which is the case the watchdog exists for. runWatchdogSweep lowers the configured batch size to
	 * this value. Two checks run for each candidate: the async-budget check in sweepCandidate and the
	 * query-budget check in the sweep loop. As soon as either budget runs short, they park the rest of
	 * the batch. The limit and the checks together keep the worst-case sweep inside its transaction
	 * budget. Chains beyond the limit stay where they are for the next sweep.
	 */
	private static final Integer WATCHDOG_SWEEP_BATCH_CEILING = 50;

	/**
	 * @description The number of synchronous queries that must still be free before the sweep decides what to do
	 * with a candidate. A candidate costs at most two queries: the check that its executor job is still
	 * alive, and one fresh read of the row by the branch that acts on it. One more query is held back as a
	 * margin. So if the check stops the sweep at a later candidate, the sweep can still pay for that
	 * candidate's park write (a park's own fresh read costs one query). When the remaining budget drops
	 * below this reserve, the sweep parks all the remaining candidates (see parkRemainingCandidates). It
	 * does not run a branch into a LimitException, which cannot be caught.
	 */
	private static final Integer WATCHDOG_CANDIDATE_QUERY_RESERVE = 3;

	/**
	 * @description Upper limit on the candidates one operator clear-stalled call looks at.
	 * It is kept apart from the watchdog's configured batch size on purpose. It is set below both the
	 * watchdog's own limit and the synchronous limit of 50 enqueues. The operator sweep runs inside an
	 * @AuraEnabled transaction, which may already be doing other work that the scheduled job is not, so
	 * it keeps a wider margin. The real limit is heap, not enqueues: a full batch of candidate rows sits
	 * in the operator's 10MB synchronous heap (Winter '27 and later; the async watchdog has 25MB).
	 * That is why the candidate and count queries also leave out the long-text fields that no part of the
	 * sweep reads. Candidates beyond the limit stay where they are (still Stalled, still candidates),
	 * and the operator can simply run the action again.
	 */
	@TestVisible
	private static final Integer MAX_OPERATOR_SWEEP_CANDIDATES = 40;

	/**
	 * @description The two reads the operator sweep always makes, one at the start and one at the end:
	 * the candidate query and the outcome count. clearStalledChains refuses at the start when the
	 * remaining query budget cannot pay even for these two. It then returns true zero counts, and does not
	 * run either read into a LimitException, which cannot be caught. The caller's transaction may arrive
	 * with its query budget already spent, for the same reason the DML reserve gives.
	 */
	private static final Integer OPERATOR_SWEEP_MINIMUM_QUERIES = 2;

	/**
	 * @description The number of synchronous queries that must still be free before the operator sweep handles
	 * each candidate: the watchdog's per-candidate reserve plus one more query. So the single read that counts
	 * the outcome after the sweep can always be paid for, even when this check stops the sweep. That
	 * count turns the sweep's work into the true numbers the operator sees, so it must never be the call
	 * that fails for lack of the budget the check was protecting.
	 */
	private static final Integer OPERATOR_CANDIDATE_QUERY_RESERVE = WATCHDOG_CANDIDATE_QUERY_RESERVE + 1;

	/**
	 * @description The number of DML statements that must still be free before the operator sweep handles each candidate.
	 * A candidate uses at most two statements: a re-drive's run key write and its job id write, or a
	 * single mark, park or degrade write. (A degrade write ends a run Failed when it cannot be recovered.)
	 * One more statement is held as a margin. The operator sweep runs inside an @AuraEnabled transaction,
	 * and that request may already have done DML of its own. The scheduled sweep has a transaction to
	 * itself, and it has no DML reserve on purpose: its batch limit and its own transaction bound its
	 * worst case. The operator path must check for room it cannot assume. When the remaining budget drops
	 * below this reserve, the sweep leaves its remaining candidates untouched (see clearStalledChains).
	 * It does not run a branch into a LimitException, which cannot be caught.
	 */
	private static final Integer OPERATOR_CANDIDATE_DML_RESERVE = 3;

	/**
	 * @description The AsyncApexJob statuses of a job that is waiting to run or running. A recorded
	 * executor job in one of these statuses is still alive. Completed, Aborted and Failed jobs are not.
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
	 * @description What happened to a chain run. Most values move Status__c; the handler values keep it and add a note.
	 * Every change to a run's Status__c names one of these and goes through applyRunTransition, which holds the table of
	 * where each run event is allowed from and where it leads (ALLOWED_FROM_STATUSES_BY_RUN_EVENT, TARGET_STATUS_BY_RUN_EVENT).
	 * Creating a run (the three places that insert one) is not a run event.
	 */
	private enum RunEvent
	{
		/**
		 * @description The last step's result ended the chain well.
		 */
		STEP_COMPLETED,
		/**
		 * @description A step's result ended the chain Failed, with the category the caller names.
		 */
		STEP_FAILED,
		/**
		 * @description The Finalizer found the executor's job crashed with an unhandled exception.
		 */
		QUEUEABLE_CRASHED,
		/**
		 * @description The Finalizer could not queue the next step or the retry link; the chain waits for recovery.
		 */
		ENQUEUE_FAILED,
		/**
		 * @description The Finalizer could not queue the completion or error handler of a chain that has ended.
		 */
		HANDLER_NOT_QUEUED,
		/**
		 * @description A completion or error handler ran and succeeded.
		 */
		HANDLER_SUCCEEDED,
		/**
		 * @description A completion or error handler ran and failed, or crashed.
		 */
		HANDLER_FAILED,
		/**
		 * @description The watchdog found a run stuck and marked it Stalled, or parked it.
		 */
		WATCHDOG_STALLED,
		/**
		 * @description The watchdog drives a stalled run again under a new run key.
		 */
		WATCHDOG_REDRIVEN,
		/**
		 * @description The watchdog could not recover a run and ended it Failed.
		 */
		RECOVERY_DEGRADED,
		/**
		 * @description The kill switch aborted the run. Also allowed from Aborted: when the kill switch writes over an
		 * operator abort, the run stays Aborted either way, and the kill switch's category tells operators more.
		 */
		KILL_SWITCH_ABORTED,
		/**
		 * @description An operator aborted the run from the Chain Monitor.
		 */
		OPERATOR_ABORTED,
		/**
		 * @description An operator retried a failed run from its failed step.
		 */
		OPERATOR_RETRIED
	}

	/**
	 * @description The statuses each run event may move a run from: the "Allowed from" column of the transition table. Built
	 * once, written out literally. The trigger backstop (the trigger that refuses a status change the engine would not
	 * make) asks isAllowedRunTransition whether a move from one status to another is allowed. That answer is worked out
	 * from this map and TARGET_STATUS_BY_RUN_EVENT and from nothing else.
	 */
	private static final Map<RunEvent, Set<String>> ALLOWED_FROM_STATUSES_BY_RUN_EVENT = new Map<RunEvent, Set<String>>
	{
			RunEvent.STEP_COMPLETED => new Set<String> {SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_STALLED},
			RunEvent.STEP_FAILED => new Set<String> {SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_STALLED},
			RunEvent.QUEUEABLE_CRASHED => new Set<String> {SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_STALLED},
			RunEvent.ENQUEUE_FAILED => new Set<String> {SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_STALLED},
			RunEvent.HANDLER_NOT_QUEUED => new Set<String> {SEL_AsyncChainExecution.STATUS_COMPLETED, SEL_AsyncChainExecution.STATUS_FAILED},
			RunEvent.HANDLER_SUCCEEDED => new Set<String>
			{
					SEL_AsyncChainExecution.STATUS_COMPLETED, SEL_AsyncChainExecution.STATUS_FAILED, SEL_AsyncChainExecution.STATUS_STALLED
			},
			RunEvent.HANDLER_FAILED => new Set<String> {SEL_AsyncChainExecution.STATUS_COMPLETED, SEL_AsyncChainExecution.STATUS_FAILED},
			RunEvent.WATCHDOG_STALLED => new Set<String> {SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_STALLED},
			RunEvent.WATCHDOG_REDRIVEN => new Set<String> {SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_STALLED},
			RunEvent.RECOVERY_DEGRADED => new Set<String> {SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_STALLED},
			RunEvent.KILL_SWITCH_ABORTED => new Set<String>
			{
					SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_STALLED, SEL_AsyncChainExecution.STATUS_ABORTED
			},
			RunEvent.OPERATOR_ABORTED => new Set<String> {SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_STALLED},
			RunEvent.OPERATOR_RETRIED => new Set<String> {SEL_AsyncChainExecution.STATUS_FAILED}
	};

	/**
	 * @description The status each run event moves a run to: the "To" column of the transition table. A null target means
	 * the run event keeps the status the run has (the handler run events and the handler note). applyRunTransition still writes
	 * Status__c for such a run event, with the value it just read, so every transition write carries the same fields.
	 */
	private static final Map<RunEvent, String> TARGET_STATUS_BY_RUN_EVENT = new Map<RunEvent, String>
	{
			RunEvent.STEP_COMPLETED => SEL_AsyncChainExecution.STATUS_COMPLETED,
			RunEvent.STEP_FAILED => SEL_AsyncChainExecution.STATUS_FAILED,
			RunEvent.QUEUEABLE_CRASHED => SEL_AsyncChainExecution.STATUS_FAILED,
			RunEvent.ENQUEUE_FAILED => SEL_AsyncChainExecution.STATUS_STALLED,
			RunEvent.HANDLER_NOT_QUEUED => null,
			RunEvent.HANDLER_SUCCEEDED => null,
			RunEvent.HANDLER_FAILED => SEL_AsyncChainExecution.STATUS_FAILED,
			RunEvent.WATCHDOG_STALLED => SEL_AsyncChainExecution.STATUS_STALLED,
			RunEvent.WATCHDOG_REDRIVEN => SEL_AsyncChainExecution.STATUS_RUNNING,
			RunEvent.RECOVERY_DEGRADED => SEL_AsyncChainExecution.STATUS_FAILED,
			RunEvent.KILL_SWITCH_ABORTED => SEL_AsyncChainExecution.STATUS_ABORTED,
			RunEvent.OPERATOR_ABORTED => SEL_AsyncChainExecution.STATUS_ABORTED,
			RunEvent.OPERATOR_RETRIED => SEL_AsyncChainExecution.STATUS_RUNNING
	};

	/**
	 * @description Start of the ERROR log and the refusal reason applyRunTransition writes when the table does not allow
	 * a run event from the run's fresh status, or when the write set it built breaks a rule a row must meet in its status.
	 */
	private static final String TRANSITION_REFUSED_PREFIX = 'Chain run transition refused: ';

	/**
	 * @description The fixed words that start the ERROR log applyRunTransition writes when the trigger backstop refuses
	 * the function's own write, so those refusals can be counted by the start of the log's short message.
	 */
	private static final String BACKSTOP_REFUSED_PREFIX = 'Chain run transition refused by the backstop: ';

	/**
	 * @description The end of the ERROR log that starts with BACKSTOP_REFUSED_PREFIX. It says why the backstop refused the write:
	 * another writer moved the run between the function's fresh read and its write.
	 */
	private static final String BACKSTOP_REFUSED_REASON = '; the row changed before the write';

	/**
	 * @description Matches the two placeholders of the AsyncChain_TransitionRefused label. The text around them is what
	 * the function looks for in a refused write's message.
	 */
	private static final String LABEL_PLACEHOLDER_PATTERN = '\\{[01]\\}';

	/**
	 * @description Matches any text, in place of each placeholder, when the label is turned into a pattern.
	 */
	private static final String ANY_TEXT_PATTERN = '.*';

	/**
	 * @description Separator written between a run's existing message and the note that a handler could not be queued.
	 */
	private static final String HANDLER_NOTE_SEPARATOR = '; ';

	/**
	 * @description Separator written between the handler note and the platform's reason for the refused enqueue.
	 */
	private static final String HANDLER_NOTE_REASON_SEPARATOR = ': ';

	/**
	 * @description Added to the crash message the handler Finalizer logs when the onError notification of a stalled run
	 * crashes. It says only that the record was not changed. The log is written before any run key check, so it never
	 * claims which status the run has: another executor may have moved the run since.
	 */
	private static final String STALLED_NOTIFICATION_CRASH_NOTE = ' | Stalled-run notification failed; the run record was not changed';

	/**
	 * @description The smallest width UTIL_String.abbreviate accepts: an ellipsis and one character. A message left less
	 * room than this ahead of the handler note is dropped rather than abbreviated.
	 */
	private static final Integer MINIMUM_ABBREVIATED_MESSAGE_LENGTH = 4;

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
	 * object. It is the structured alternative to the untyped getStatus(Id) map. ChainStatus exposes every
	 * tracked field (chain name, status, current step, correlation ID, step counts, error message,
	 * timing) plus the helper checks isRunning(), isTerminal() and isFailed().
	 *
	 * It reads through the same selector as getStatus(Id), which respects sharing: a caller only sees
	 * chains they have access to. To see every chain in the org, use the Chain Monitor console instead.
	 * For detail on each step, use the Chain Monitor. ChainStatus is a summary of one record and has no
	 * step list on purpose.
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
	 * @description Bulk version of getChainStatus. It turns a set of execution IDs into ChainStatus
	 * objects with a single query, so it does not use up the query limit when many IDs are needed. IDs
	 * that do not match a visible record are simply left out of the returned map. It uses the same
	 * selector as getChainStatus, which respects sharing, so a caller only sees chains they can access.
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
	 * @description Maps an AsyncChainExecution__c row onto a typed ChainStatus. The duration is read from
	 * ElapsedMs__c, the one definition of a run's elapsed time, so this accessor and the Chain Monitor
	 * always agree: the stored duration; else a live count for a Running or Stalled run; else the time
	 * between start and end for a Completed, Failed or Aborted run that stored none. A row that was never
	 * read from the database (one a test registered with TST_Mock) carries no formula value, so it falls
	 * back to the duration it stored; for a row that was read the two can never differ.
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

		status.durationMs = (execution.ElapsedMs__c ?? execution.DurationMs__c)?.longValue();
		status.durationLabel = UTIL_Date.formatDuration(status.durationMs);

		return status;
	}

	/**
	 * @description Typed, read-only snapshot of a chain execution returned by getChainStatus. A
	 * structured alternative to the getStatus(Id) map: each tracked field is a named property and the
	 * lifecycle can be checked through isRunning(), isTerminal() and isFailed(). It holds no step list and
	 * runs no queries: it is a plain value object built from a single AsyncChainExecution__c row.
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
		 * Prefer the isRunning()/isTerminal()/isFailed() checks over comparing this String.
		 * If the status is Stalled but completedAt is set, a recovery write changed a chain that had
		 * already finished. isTerminal() reports such a row as terminal.
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
		 * @description When the chain reached a terminal state; null while it is still running.
		 *
		 * @since 1.2
		 */
		global Datetime completedAt;

		/**
		 * @description Elapsed run time in milliseconds, the same value the Chain Monitor console shows. A
		 * finished chain reports the duration it stored. A chain that is still Running, or has Stalled, reports
		 * how long it has been going since startedAt. A Completed, Failed or Aborted chain that stored no
		 * duration reports the time between startedAt and completedAt. Null when no duration can be worked
		 * out, for example for a chain that recorded no start.
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
		 * @description Whether the chain has reached a terminal state, from which it will not move on:
		 * Completed, Failed or Aborted, or any row with a completion timestamp. The timestamp check covers
		 * a rare recovery write that can leave a finished chain showing Stalled. The completion timestamp
		 * is kept through that write, so it is the reliable sign that the chain has ended.
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
		 * @description True only for the Failed status. An Aborted chain returns false, so use isTerminal to learn whether
		 * the chain has ended for any reason. A Stalled chain also returns false: it has not ended, it is waiting for
		 * recovery. errorMessage holds the reason for the failure.
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
	 * @description Serializes the saved definition list so it can be stored in StepLog__c. Order rule:
	 * the list arrives as the chain's step entries in execution order, followed by its handler entries
	 * (isErrorHandler / isCompletionHandler), exactly as ChainBuilder.execute() first saved it. This
	 * method keeps that order. So the step indices in the saved document always equal the step indices
	 * at runtime, and readers may filter out the handler entries without shifting any index. If the
	 * serialized copy would still be larger than the field even with shortened messages, the message of
	 * every entry is dropped and the list is serialized again. The JSON document itself is never cut
	 * short: a cut-short document cannot be deserialized at the next step, and that failure would
	 * override the caller's continueOnError choice. The full failure records are kept in
	 * ErrorMessage__c and in the step-failure log entries.
	 *
	 * @param persistedDefinitions The full persisted definition list: steps first, handlers last.
	 *
	 * @return Valid definition-list JSON that fits within the StepLog__c field capacity. This is
	 * certain together with the per-step runtime reserve the execute() check holds back at build time.
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
	 * @description Filters a deserialized StepLog__c definition list down to its chain steps. It drops
	 * the handler entries, which the serialization order always places after the steps. Handler entries
	 * describe notifications, not chain work. They must never run as a step, never count toward step
	 * totals, and never shift step indices. Because they always come after the steps, the returned list
	 * keeps step order and step indices. Entries are returned by reference, so changes made at runtime
	 * (success, durationMs, message) also show in the full list a caller serializes again. The method is
	 * public so other framework classes can use it (CTRL_ChainMonitor's step timeline), but not global:
	 * subscribers never touch the saved document.
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
	 * The step is created again by class name in every hop, so the package must be able to create a
	 * subscriber step class. The platform only calls the implicit constructor of a class that declares
	 * none, or a global constructor on a global class. A step that declares its own public constructor
	 * cannot be created again, and the failure message says so.
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
		 * @description Declares whether this step is safe to execute more than once. Override it to
		 * return true only when a repeat run of work() cannot double the step's side effects, either
		 * because the work is naturally idempotent or because the step guards itself (e.g. via
		 * ChainContext.idempotencyKey()). The answer is read on the instance the chain was built with
		 * and saved in the run's step log. Two readers use it. The Chain Monitor shows retry from the
		 * failed step only for a step that declares itself idempotent. The watchdog uses it when a
		 * chain stalls on a step that had started and left no saved result: it runs the step again
		 * only if the step declares itself idempotent. Otherwise it ends the chain as Failed with a
		 * reason that names the step, because the step may already have done its work. The default
		 * false keeps retry hidden, and that second run off, until the author chooses otherwise. An
		 * ApiStep does not use this default: it answers for itself from its handler's request (see
		 * ApiStep). The declaration never changes how a healthy chain runs. It is a method rather than
		 * a field, so the declaration needs no constructor. The framework creates every step again by
		 * class name in each hop, and the package cannot create a step class that declares its own
		 * constructor.
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
		 * **A step may start another chain** by calling `UTIL_AsyncChain.newChain(...).execute()` inside
		 * this method. The new chain is a run of its own, with its own `AsyncChainExecution__c` record and
		 * its own tracking id. It records the parent run's correlation ID as the ID it was launched under,
		 * and keeps the parent's root correlation ID, so its log entries can be followed from the parent.
		 * What to expect:
		 * - The new chain runs later, in jobs of its own. The step does not wait for it, and its result
		 *   does not change this step's result.
		 * - It has its own ChainContext. Values it writes never reach this chain's context, and this
		 *   chain's context is not passed to it; use withInitialContext(...) to hand it values.
		 * - A step may start one chain. A second launch from the same step in the same transaction is
		 *   refused with an IllegalStateException. When this step runs again (a retry or a re-drive) and
		 *   the launch sets no deduplication key of its own, the same launch returns the chain the step
		 *   started before instead of starting a second one. If the run again launches a chain with a
		 *   different name, the launch is refused with an IllegalStateException, because one step
		 *   starts one chain.
		 * - Chains may nest at most five levels deep. A launch that would nest deeper, that finds no free
		 *   queueable stack level, or that comes after the step already added a queueable job of its own,
		 *   is refused with an IllegalStateException before anything is written.
		 * - The new chain's first step runs under this chain's maximum queueable stack depth. The
		 *   framework's default leaves room for that. If you pass your own AsyncOptions to the new chain,
		 *   its maximum must include the depth the launching job already runs at.
		 * If the new chain's steps belong to this work, add them to this chain with `.then(...)` instead.
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
		 * @description Optional per-step retry strategy. Return null (the default) for no retry: a
		 * failure is final on the first attempt. Retry only TRANSIENT failures, the kind that may pass on
		 * a second try (locks, timeouts, 5xx-style results). Combine
		 * UTIL_Retry.retryOnlyOnException(...) / dontRetryOnException(...) so a failure that will always
		 * happen again is never retried. A validation error retried N times, across many chains started
		 * by a trigger at once, uses up async budget with no chance of success. Steps that retry MUST be
		 * idempotent (safe to run more than once): use ChainContext.idempotencyKey(). Exception filters
		 * match the failure's exception wherever there is one: a step that THROWS and a step that RETURNS
		 * failed(exception) are filtered the same way. Only a failed(message) with no exception has
		 * nothing to filter, so only the attempt budget limits it. A step that knows a message-only
		 * failure will always happen again should return failedPermanently(...) instead. That refuses
		 * any retry, whatever this strategy answers.
		 *
		 * A chain that retries so often that it uses up the queueable stack depth becomes Stalled, and
		 * the watchdog recovers it from a new first job. Backoff works in whole minutes. The platform's
		 * delayed enqueue counts in minutes, so any backoff over 0 seconds is rounded UP to the next full
		 * minute (a 2-second backoff waits about 1 minute; only withBaseBackoff(0) queues the step again
		 * at once). Do not expect retry timing finer than a minute.
		 *
		 * The backoff delay applies only when the retried attempt is queued. It happens exactly once, on
		 * the retry itself, and the steps after a successful retry run with no added delay. A chain that
		 * has retried also has more room in the queueable stack depth for the rest of its run. Each retry
		 * really adds one more job to the jobs queued one from another, so the extra depth stays available to the hops that
		 * follow.
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
		 * @description True when the step declared this failure permanent: the failure will happen
		 * again on every try, so the chain refuses any retry whatever the configured retry
		 * budget, and records the failure with category StepException. Never null: false on
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
	 * The data is serialized into the chain context between transactions, so keep it small:
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
	 * knows will happen again on every try (a failed validation, a rejected business rule, a client
	 * error that can never succeed when sent again), so the chain must not spend retry budget on it.
	 * The retry strategy is never asked, the chain fails on this attempt, and FailureCategory__c
	 * records StepException.
	 *
	 * @param message A human-readable description of the failure that will always happen again.
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
	 * failure the step knows will always happen again. The exception is kept on the result exactly
	 * as with failed(exception). The permanent flag also refuses any retry, and it wins over both
	 * the attempt budget and every exception filter.
	 *
	 * @param error The exception that caused the failure that will always happen again.
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
		 * @description The 1-based attempt number of the currently executing step. Set by the
		 * executor before each work(). It holds for the current step only and is left out of serialize().
		 */
		@TestVisible
		private Integer currentAttempt;

		/**
		 * @description Whether no further retry remains for the currently executing step. Set by the
		 * executor before each work(). It holds for the current step only and is left out of serialize().
		 */
		@TestVisible
		private Boolean finalAttempt;

		/**
		 * @description The current step's retry strategy, kept here by the executor before each
		 * work() so isFinalAttempt(error) can ask the strategy's exception filters. It is declared
		 * transient on purpose. Strategies are code, not state, so a filter's Set<Type> should not be
		 * carried along when the platform serializes a queued handler. A handler that asks after the
		 * failure finds this field null, and so correctly reads the attempt as final.
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
		 * by the strategy's attempt budget alone. The value is set before work() runs, so it cannot
		 * know which exception the attempt will fail with. A strategy wrapped in an exception filter
		 * can still refuse the retry afterwards. When that happens, the framework corrects the value
		 * before it passes the failure on, so an onError handler always reads true for a failure
		 * that was final. To ask "would failing with THIS exception be final?" from inside work(),
		 * use isFinalAttempt(error).
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
		 * that an exception filter would refuse the retry, this overload asks the current
		 * step's full strategy, filters included, with the exception you are about to fail with.
		 * Call it from inside work(), before returning or throwing, when a last-chance side
		 * effect (release a lock, write a marker, alert someone) must run exactly when no retry
		 * will follow. Outside work(), for example in an onError handler, there is no strategy and
		 * the method returns true. That is correct there: a failure passed to the handler is final.
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
		 * field and upsert (a replay updates the same record instead of creating a duplicate), or write
		 * it to a marker for a side effect that cannot be upserted (a callout, an email) and skip when
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
		 * @description Returns the per-record idempotency key for a step that works through many
		 * records: the step-level key joined to the given record id. Use it so a replay after a
		 * partial failure only reprocesses the rows that did not complete the first time, instead of
		 * re-running or skipping the whole step. A null recordId falls back to the bare step-level key.
		 * An 18-character Id keeps the whole key well under the 255-character external-id limit, so this
		 * overload needs no length caveat. Treat the result as an opaque token. Pass a literal null as a
		 * typed variable or a cast ((Id) null), because a bare idempotencyKey(null) is ambiguous between
		 * this overload and the String overload.
		 *
		 * @param recordId The record being processed, which makes the key unique per record.
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
		 * @description Returns a custom idempotency key for a step that works through units that are
		 * not records (for example line numbers or external keys): the step-level key joined to the
		 * given grain, the value that names one unit. A null or blank grain falls back to the bare
		 * step-level key. The grain passes through verbatim, so the helper never hashes or truncates it.
		 * The composed key is typically stored on a Text external-id field capped at 255 characters; an
		 * over-long key fails loudly at upsert with a STRING_TOO_LONG DmlException (not silent
		 * truncation), so it surfaces in your own test. If you need a long composite grain, shorten it
		 * yourself (a one-line hash of just the grain) before passing it. Treat the result as an opaque
		 * token. Pass a literal null as a typed variable or a cast ((String) null), because a bare
		 * idempotencyKey(null) is ambiguous between this overload and the Id overload.
		 *
		 * @param grain A short value that names one unit of the step's work and does not change between attempts.
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
	 * @description Serializes the failing chain's context for the final save, and never cuts it short.
	 * A context that no longer fits the field is not stored at all, so the re-drive check can refuse it
	 * cleanly instead of parsing a cut-off document. The failure path cannot throw, because the chain is
	 * already failing. So the safe outcome is to store nothing and say so in ErrorMessage__c.
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
		 * @description AsyncOptions controlling queueable stack depth. When null, the framework creates a default with
		 * maximumQueueableStackDepth = steps.size() + 1 + MAXIMUM_NESTING_DEPTH, so the chains a step launches have room
		 * for their first hops. Inside a queueable job the count starts from the depth that job runs at, when the
		 * platform lets the framework read it. A launch inside a job whose group of jobs (the jobs queued one from another,
		 * from the same first job) already has a maximum queues its
		 * first hop without options, under that maximum; these options then apply from the second hop on. A delay set
		 * on the caller's own options is not applied to that first hop; withDelayMinutes is the way to delay it.
		 */
		private AsyncOptions asyncOptions;

		/**
		 * @description Best-effort delay in minutes before the chain's first step is enqueued. Null or
		 * zero means no delay. Set via withDelayMinutes and applied only to the first enqueue.
		 */
		@TestVisible
		private Integer firstStepDelayMinutes;

		/**
		 * @description Active-run deduplication key written on the run record at start. Null when unset,
		 * which the insert treats as no key.
		 */
		private String deduplicationKey;

		/**
		 * @description Whether the chain author declared the chain safe to restart from step 1.
		 * Set by allowRestart(); false until declared.
		 */
		private Boolean restartDeclared = false;

		/**
		 * @description Whether this launch's correlation was created by the framework rather than
		 * supplied by the caller. A new UUID cannot already belong to a run, so a duplicate error on
		 * such a launch never comes from the unique correlation field. This lets the retry path for a
		 * deduplication key tell a real correlation clash from a deduplication clash. In the second
		 * case, the lookup of the run that holds the key can come back empty, because the key was
		 * released and taken again around the lookup. Without this flag, a launch whose correlation
		 * could not have clashed would be refused with the correlation rule.
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
		 * Each call adds one more key-value pair to the initial context map.
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
		 * @description Sets the AsyncOptions controlling queueable stack depth. When provided, these options override
		 * the framework's default maximum. The default is one level per step, one for the first hop, and five more for
		 * the chains those steps may launch. Inside a chain, it is counted from the launching job's depth.
		 * In tests, pass options with an explicit maximumQueueableStackDepth that matches the expected chain depth, so
		 * the queued jobs run one after another within Test.startTest/stopTest.
		 * Inside a step or a handler of another chain, the options apply from the chain's second hop on. The first hop
		 * uses the launching chain's maximum, because the platform does not let a running job change it. So a
		 * duplicateSignature set here is not applied to that hop. The platform keeps counting depth from the launching
		 * job's depth. So a maximum set here for a chain launched from a step must include that depth, as the
		 * framework's default does. A maximum sized for a launch outside any chain runs out at a later hop and stalls
		 * the run.
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
		 * zero completed steps in the Chain Monitor until the delay ends. If the org has turned off
		 * Queueable delay, the first step runs at once instead. The value is kept within the platform range
		 * of 0 to 10 minutes; a null or zero delay is a no-op. Only the first step is delayed; every later
		 * step runs as soon as the step before it finishes.
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
		 * a duplicate. Any terminal status releases the key in the same update, so running the chain
		 * again after it ends is allowed on purpose. A Stalled run still holds its key until it is
		 * recovered or resolved. The key is stored exactly as given. The platform's unique text field
		 * ignores case, so keys that differ only in case clash. Chains with no steps complete at once
		 * and never hold a key. This is not the same as ChainContext.idempotencyKey(), which makes
		 * replay-safe keys for your own step side effects. This method stops a second run from
		 * starting at all.
		 *
		 * @param deduplicationKey Non-blank key, at most 255 characters: for example a schedule name or a
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
		 * side effects. The declaration is written on the run record at start, together with a copy
		 * of the initial context as the chain was built. The Chain Monitor offers its restart action
		 * only for such runs. A restart uses that saved copy, never the changed context a partial run
		 * left behind. It is off by default, so restart stays hidden until the author turns it on.
		 * The declaration never changes how the chain runs.
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
		 * neither fires if the chain is aborted by the framework kill switch. If you need
		 * "always-runs" cleanup (e.g. release a row lock, close a session), put the cleanup
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
		 * @description Executes the chain under a tracking id of its own, created by the framework. The launching
		 * transaction may already have an active correlation ID. If it does, the run records that ID as the one it was
		 * launched under. It also keeps the transaction's root correlation ID (the ID of the action that started the
		 * work), and writes one entry in the launcher's log that names the new run. If there is no active correlation
		 * ID, the run starts its own action and is its own root. Saves the chain configuration and queues the first
		 * step. A step or a handler of another chain may call this too; see the overload for what a launch from inside
		 * a chain does.
		 *
		 * @return The ID of the AsyncChainExecution__c record tracking this chain.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException If the serialized step list exceeds the StepLog__c field
		 * capacity less the per-step runtime reserve, or if a launch from inside a step or handler of another chain
		 * would nest too deep or find no room (see the correlation-ID overload this method delegates to).
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
			correlationMintedByFramework = true;
			return execute(UTIL_Random.randomUUID());
		}

		/**
		 * @description Executes the chain under the supplied correlation id, which becomes the run's own tracking id.
		 * The run records three things. First, the correlation ID active in this transaction, as the ID it was launched
		 * under (null when none is active). Second, the transaction's root correlation ID (the ID of the action that
		 * started the work) as its own root: the active correlation ID when no root exists yet, or the supplied ID when
		 * neither exists. Third, the transaction's full logging context, stored under the supplied ID, so every step
		 * logs with the run's ID and the action's root. A run launched while a correlation ID is active is announced
		 * once in the launcher's log. Saves the chain configuration and queues the first step.
		 *
		 * A run may be launched from inside a step, or from a completion or error handler, of another chain. Then it is
		 * recorded with that run's id as the id it was launched under. It sits one level below that run (chains may nest
		 * at most five levels deep). The launching run and step remember it, so a retry of that step gets the same run
		 * back instead of a second one. One chain may be launched per step or handler.
		 *
		 * A run may also be launched from inside any other queueable job. A job started from inside a running job whose
		 * group of jobs (the jobs queued one from another, from the same first job) already has a maximum queueable stack
		 * depth takes over that maximum and cannot set its own. So the first step of a chain launched there runs under the
		 * launching group's maximum: the launching chain's, or the one the other job was queued with. The framework's default maximum
		 * leaves room for that inside a chain. A launch that would find no room, would nest too deep, or comes from a job
		 * that has already added its one queueable job, is refused before anything is written. Inside a trigger fired by
		 * a save that a queueable job makes, the platform does not let the framework read the depth of the running job.
		 * The job may be a chain step or any other job. A job queued from there starts a new group of jobs, so the chain sets its own
		 * maximum as a launch outside any job does. A chain launched this way from a step's trigger is still recorded as
		 * launched under the step's run and remembered by that step. If the platform refuses the
		 * chain's first job anyway, the run record is deleted and the platform's exception reaches the caller, so no
		 * Running run is ever left without a job.
		 *
		 * @param correlationId The correlation ID to attach to all log entries for this chain.
		 *
		 * @return The ID of the AsyncChainExecution__c record tracking this chain.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException If the serialized step list exceeds the
		 * StepLog__c field capacity less the per-step runtime reserve (a chain that cannot persist
		 * its step list intact for its whole life must fail at definition time, never by silently
		 * truncating the persisted JSON); or if the supplied correlation ID is already attached to
		 * another chain run, since a run owns its correlation exclusively; or if the launch runs inside a step or
		 * handler of another chain and would nest deeper than five levels, find no spare queueable stack level for
		 * its first step, follow another launch from the same step or handler in the same transaction, follow a
		 * queueable job that step or handler already added, or start a different chain from a step or handler that
		 * launched one before; or if the launch runs inside another queueable job that has already added its one
		 * queueable job, or whose group of jobs has no spare queueable stack level for the first step.
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

			if(!steps.isEmpty())
			{
				// The launch commits to running the first step: its start is recorded in the insert, before the enqueue
				// below, so the watchdog can tell a first step that never ran from one that ran and left no result.
				steps[0].started = true;
			}
			String serializedStepList = serializeStepListWithinCapacity();
			executed = true;

			Boolean launchedInsideChainJob = runningStep != null;
			Id rememberedChildId = launchedInsideChainJob ? refuseASecondLaunchThenFindRememberedChildId() : null;
			if(rememberedChildId != null)
			{
				return rememberLaunch(rememberedChildId);
			}
			QueueableLineage lineage = readLineage(launchedInsideChainJob);
			if(launchedInsideChainJob)
			{
				refuseWhenThereIsNoRoomForTheChild(lineage);
			}

			String launchCorrelationId = String.isNotBlank(LOG_Builder.correlationId) ? LOG_Builder.correlationId : null;
			String rootCorrelationId = String.isNotBlank(LOG_Builder.rootCorrelationId) ? LOG_Builder.rootCorrelationId : (launchCorrelationId ?? correlationId);
			initialContext.put(LOG_CONTEXT_KEY, LOG_Engine.serializeContextWithCorrelationId(correlationId));
			initialContext.put(NESTING_DEPTH_KEY, launchedInsideChainJob ? runningStep.nestingDepth + 1 : 0);

			AsyncChainExecution__c execution = new AsyncChainExecution__c
					(
							ChainName__c = chainName,
							Status__c = SEL_AsyncChainExecution.STATUS_RUNNING,
							TotalSteps__c = steps.size(),
							CompletedSteps__c = 0,
							StartedAt__c = Datetime.now(),
							CorrelationId__c = correlationId,
							LaunchCorrelationId__c = launchCorrelationId,
							RootCorrelationId__c = rootCorrelationId,
							ContextData__c = JSON.serialize(initialContext),
							StepLog__c = serializedStepList
					);
			execution.RunKey__c = UTIL_Random.randomUUID();
			if(steps.isEmpty())
			{
				return rememberLaunch(completeSteplessRun(execution));
			}

			if(restartDeclared)
			{
				execution.AllowRestart__c = true;
				execution.InitialContextData__c = execution.ContextData__c;
			}
			execution.ActiveDeduplicationKey__c = deduplicationKey;
			execution.DeclaredDeduplicationKey__c = deduplicationKey;
			if(!launchedInsideChainJob)
			{
				refuseWhenTheLaunchingJobHasNoRoom(lineage);
			}
			String activeRunId = insertGuardedByDeduplicationKey(execution);
			if(activeRunId != null)
			{
				return rememberLaunch(activeRunId);
			}

			AsyncOptions options = asyncOptions ?? buildDefaultOptions(lineage.currentDepth);
			ChainExecutor executor = new ChainExecutor(execution.Id, 0, maxSteps, maxContextSize, errorHandler, completionHandler, options, execution.RunKey__c);
			Boolean borrowsTheLaunchingMaximum = launchedInsideChainJob ? lineage.isReadable : lineage.hasMaximum();
			stampExecutorJobId(execution, enqueueFirstExecutor(execution, executor, options, borrowsTheLaunchingMaximum));
			announceLaunch(chainName, correlationId, launchCorrelationId, execution.Id);

			return rememberLaunch(execution.Id);
		}

		/**
		 * @description Queues the chain's first executor. A launch inside a group of jobs (the jobs queued one from another,
		 * from the same first job) that already has a maximum uses that maximum: it is queued without options (see
		 * enqueueFirstExecutorUnderTheLaunchingMaximum). Any other launch is queued
		 * with a copy of the executor's options (see buildFirstEnqueueOptions). When the platform refuses the job, the run
		 * record just inserted is deleted and the platform's exception is thrown again unchanged. So a caller that catches
		 * the exception and goes on never keeps a Running run that has no job. The delete costs a DML statement only on
		 * that failure, so a launch that works spends nothing extra.
		 *
		 * @param execution The run record just inserted.
		 * @param executor The first executor.
		 * @param options The options the executor carries for the chain (the caller's own or the framework default).
		 * @param borrowsTheLaunchingMaximum True when the launching group of jobs already has a maximum queueable stack
		 * depth, which the platform does not let a job inside it change.
		 *
		 * @return The enqueued job's id.
		 *
		 * @throws Exception The platform's own refusal of the job, after the run record is deleted.
		 *
		 * @since 1.10
		 */
		private Id enqueueFirstExecutor(AsyncChainExecution__c execution, ChainExecutor executor, AsyncOptions options, Boolean borrowsTheLaunchingMaximum)
		{
			try
			{
				return borrowsTheLaunchingMaximum
						? enqueueFirstExecutorUnderTheLaunchingMaximum(executor)
						: System.enqueueJob(executor, buildFirstEnqueueOptions(options, firstStepDelayMinutes));
			}
			catch(Exception enqueueError)
			{
				DML_Builder.newTransaction().systemModeInternal().doDelete(execution).execute();
				throw enqueueError;
			}
		}

		/**
		 * @description Reads what the group of queueable jobs this launch runs in looks like. The group is the jobs queued
		 * one from another, from the same first job. This is the only place a launch asks the platform for its queueable
		 * stack depth. A launch inside a chain job asks only after it has checked for a child the step already launched,
		 * so a retried step that gets that child back does not ask the platform at all.
		 *
		 * A launch outside a chain job and outside any queueable job has no group: depth 0 and no maximum, and nothing
		 * is read. Any other launch asks the platform for the depth and the maximum. A launch inside a chain job asks
		 * without checking System.isQueueable() first, because a chain's steps and handlers always run inside a
		 * queueable job.
		 *
		 * Inside a trigger fired by a save that a queueable job makes, the platform refuses to answer, although the code
		 * runs inside that job. A job queued from there starts a new group of jobs at depth 1, whatever group the running
		 * job is in. So a group that cannot be read is treated as no group at all: depth 0 and no maximum, the same as a
		 * launch outside any job.
		 *
		 * @param launchedInsideChainJob True when the launch runs inside a step or handler of another chain.
		 *
		 * @return The group of jobs this launch runs in.
		 *
		 * @since 1.10
		 */
		private QueueableLineage readLineage(Boolean launchedInsideChainJob)
		{
			if(!launchedInsideChainJob && !System.isQueueable())
			{
				return new QueueableLineage(false, true, 0, null);
			}
			try
			{
				Integer maximumDepth = System.AsyncInfo.hasMaxStackDepth() ? System.AsyncInfo.getMaximumQueueableStackDepth() : null;
				return new QueueableLineage(true, true, System.AsyncInfo.getCurrentQueueableStackDepth(), maximumDepth);
			}
			catch(AsyncException unreadableLineage)
			{
				return new QueueableLineage(true, false, 0, null);
			}
		}

		/**
		 * @description Refuses, before anything is written, a launch from inside a queueable job that is not a chain job
		 * and could not run: one from a job that has already added its one queueable job, and one whose group of jobs has
		 * a maximum queueable stack depth and no spare level for the chain's first hop. A launch inside a chain job is
		 * checked by refuseWhenThereIsNoRoomForTheChild instead, and a launch outside any queueable job is not checked.
		 *
		 * @param lineage The group of jobs the launch runs in.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException The refusal, naming the chain and the reason.
		 *
		 * @since 1.10
		 */
		private void refuseWhenTheLaunchingJobHasNoRoom(QueueableLineage lineage)
		{
			if(!lineage.isInsideQueueable)
			{
				return;
			}
			if(UTIL_Limits.queueableJobs().isExhausted())
			{
				throw new UTIL_Exceptions.IllegalStateException(String.format(LAUNCHING_JOB_ENQUEUE_ALREADY_USED_MESSAGE, new List<String> {chainName}));
			}
			if(lineage.hasMaximum() && lineage.currentDepth + 1 > lineage.maximumDepth)
			{
				throw new UTIL_Exceptions.IllegalStateException(String.format(LAUNCHING_JOB_STACK_DEPTH_EXHAUSTED_MESSAGE,
						new List<String> {chainName, String.valueOf(lineage.currentDepth), String.valueOf(lineage.maximumDepth)}));
			}
		}

		/**
		 * @description Serializes the step list for the run record and refuses a chain whose list would not fit the
		 * StepLog__c field with the per-step runtime reserve left free: a chain that cannot persist its step list intact
		 * for its whole life fails at definition time, never by silently truncating the persisted JSON.
		 *
		 * @return The serialized step list.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException Naming the length, the allowance and the capacity.
		 *
		 * @since 1.8
		 */
		private String serializeStepListWithinCapacity()
		{
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
			return serializedStepList;
		}

		/**
		 * @description Runs the first checks on a launch from inside a step or handler of another chain. A second launch
		 * from the same step or handler in this transaction is refused. Then a launch with no deduplication key of its
		 * own looks for the chain the step or handler launched before (see findRememberedChildId). A launch with its own
		 * key does not look.
		 *
		 * @return The id of the chain the step or handler launched before, or null when there is none to return.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException When the step or handler already launched a chain in this
		 * transaction, or when the chain it launched before is a different chain.
		 */
		private Id refuseASecondLaunchThenFindRememberedChildId()
		{
			refuseWhenTheStepAlreadyLaunched();
			return deduplicationKey == null ? findRememberedChildId() : null;
		}

		/**
		 * @description Looks for the chain the running step or handler launched before, under the key the framework
		 * gives that launch: a run holding the key is the remembered child, still running or finished, so the launch
		 * returns it instead of starting a second chain. A remembered child of a different chain is refused, because
		 * one step launches one chain. Takes that key as the chain's deduplication key on the way.
		 *
		 * @return The remembered child's id, or null when the step has not launched a chain before.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException When the remembered child belongs to a different chain.
		 *
		 * @since 1.8
		 */
		private Id findRememberedChildId()
		{
			deduplicationKey = runningStep.launchKey();
			AsyncChainExecution__c rememberedChild = new SEL_AsyncChainExecution().findByDeclaredDeduplicationKey(deduplicationKey);
			if(rememberedChild != null && rememberedChild.ChainName__c != chainName)
			{
				throw new UTIL_Exceptions.IllegalStateException(String.format(SECOND_LAUNCH_MESSAGE,
						new List<String> {chainName, describeLaunchedChild(rememberedChild)}));
			}
			return rememberedChild?.Id;
		}

		/**
		 * @description Words a launched child for a refusal: its chain name and record id when a sharing-respecting read
		 * finds the run, the unnamed wording otherwise, so a refusal never names a run the caller's sharing hides (the
		 * rule asCorrelationCollision applies to a correlation's holder).
		 *
		 * @param child The child, read with sharing bypassed.
		 *
		 * @return The wording for the refusal.
		 *
		 * @since 1.8
		 */
		private String describeLaunchedChild(AsyncChainExecution__c child)
		{
			Boolean visible = new SEL_AsyncChainExecution().findByCorrelationId(child.CorrelationId__c) != null;
			return visible ? String.format(LAUNCHED_CHILD_NAMED, new List<String> {child.ChainName__c, child.Id}) : LAUNCHED_CHILD_UNNAMED;
		}

		/**
		 * @description Records the run this launch started, or the existing run it returned, as the running step's one
		 * launch, so a second launch in the same transaction is refused. Outside a chain job there is nothing to record.
		 *
		 * @param runId The run launched, or the existing run returned.
		 *
		 * @return The same id, for the caller to return.
		 *
		 * @since 1.8
		 */
		private Id rememberLaunch(Id runId)
		{
			if(runningStep != null)
			{
				runningStep.rememberLaunch(runId, chainName);
			}
			return runId;
		}

		/**
		 * @description Refuses a launch from a step or handler that already launched a chain in this transaction, or got
		 * an existing run back from a launch, whatever the chain. The platform lets a running job add one queueable job,
		 * so the second chain could never run, and answering it with the first child's id would hide that. A retry or a
		 * re-drive runs in a transaction of its own and gets the remembered child instead.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException Naming the chain refused and the run already launched.
		 *
		 * @since 1.8
		 */
		private void refuseWhenTheStepAlreadyLaunched()
		{
			if(runningStep.launchedRunId != null)
			{
				String launchedChild = String.format(LAUNCHED_CHILD_NAMED, new List<String> {runningStep.launchedChainName, runningStep.launchedRunId});
				throw new UTIL_Exceptions.IllegalStateException(String.format(SECOND_LAUNCH_MESSAGE, new List<String> {chainName, launchedChild}));
			}
		}

		/**
		 * @description Refuses, before anything is written, a launch from inside a chain job that could not run: one
		 * that would nest too deep, one whose group of jobs has no spare queueable stack level for the child's first hop, and
		 * one from a job that has already added its one queueable job.
		 *
		 * @param lineage The group of jobs the launch runs in.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException The refusal, naming the chain and the reason.
		 *
		 * @since 1.8
		 */
		private void refuseWhenThereIsNoRoomForTheChild(QueueableLineage lineage)
		{
			refuseWhenNestingTooDeep();
			refuseWhenNoStackLevelIsSpare(lineage);
			refuseWhenTheEnqueueIsAlreadyUsed();
		}

		/**
		 * @description Refuses a launch from inside a chain job whose one queueable enqueue is already used, before
		 * anything is written: a step that added a job of its own and then launches a chain would otherwise insert a
		 * run record the platform refuses to give a job.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException Naming the chain and the launching run.
		 *
		 * @since 1.8
		 */
		private void refuseWhenTheEnqueueIsAlreadyUsed()
		{
			if(UTIL_Limits.queueableJobs().isExhausted())
			{
				throw new UTIL_Exceptions.IllegalStateException(String.format(ENQUEUE_ALREADY_USED_MESSAGE,
						new List<String> {chainName, runningStep.executionId}));
			}
		}

		/**
		 * @description Completes a chain with no steps in the launching transaction: the run record is inserted already
		 * complete, the launch is announced and the completion logged.
		 *
		 * @param execution The run record, not yet inserted.
		 *
		 * @return The run record's id.
		 *
		 * @since 1.8
		 */
		private Id completeSteplessRun(AsyncChainExecution__c execution)
		{
			execution.Status__c = SEL_AsyncChainExecution.STATUS_COMPLETED;
			execution.CompletedAt__c = Datetime.now();
			execution.DeclaredDeduplicationKey__c = deduplicationKey;
			insertRunRecord(execution);
			announceLaunch(chainName, execution.CorrelationId__c, execution.LaunchCorrelationId__c, execution.Id);
			emitTerminalLog(LoggingLevel.INFO, 'Chain completed: ' + chainName + ' (no steps)', CLASS_NAME + '.ChainBuilder.execute', execution.Id);
			return execution.Id;
		}

		/**
		 * @description Refuses a launch from inside a chain job that would nest deeper than MAXIMUM_NESTING_DEPTH, before
		 * anything is written.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException Naming the chain, the level and the limit.
		 *
		 * @since 1.8
		 */
		private void refuseWhenNestingTooDeep()
		{
			Integer childDepth = runningStep.nestingDepth + 1;
			if(childDepth > MAXIMUM_NESTING_DEPTH)
			{
				throw new UTIL_Exceptions.IllegalStateException(String.format(NESTING_DEPTH_EXCEEDED_MESSAGE,
						new List<String> {chainName, String.valueOf(childDepth), String.valueOf(MAXIMUM_NESTING_DEPTH)}));
			}
		}

		/**
		 * @description Refuses a launch from inside a chain job whose group of jobs has a maximum queueable stack depth and
		 * no spare level for the child's first hop, before anything is written. Otherwise the platform would refuse the enqueue after
		 * the run record was inserted, leaving a Running record with no job behind it. A group with no maximum is not
		 * checked. That is also the case when the platform does not let the framework read the group, as in a trigger
		 * fired by the step's own save: the child then starts a new group of jobs, so the step's group needs no room.
		 *
		 * @param lineage The group of jobs the launch runs in.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException Naming the chain, the launching run, the depth and the maximum.
		 *
		 * @since 1.8
		 */
		private void refuseWhenNoStackLevelIsSpare(QueueableLineage lineage)
		{
			if(lineage.hasMaximum() && lineage.currentDepth + 1 > lineage.maximumDepth)
			{
				throw new UTIL_Exceptions.IllegalStateException(String.format(STACK_DEPTH_EXHAUSTED_MESSAGE,
						new List<String> {chainName, runningStep.executionId, String.valueOf(lineage.currentDepth), String.valueOf(lineage.maximumDepth)}));
			}
		}

		/**
		 * @description The framework's default maximum queueable stack depth for this chain: one level per step, one for
		 * the first hop, and one per nesting level the framework allows, so a chain the framework launched always has
		 * room for the first hops of the chains its steps launch. Inside a queued job the count starts from the depth the
		 * launching job runs at, because the platform's counter continues from it.
		 *
		 * @param launchDepth The queueable stack depth the launching job runs at: 0 outside any queueable job, or when
		 * the platform does not let the framework read it.
		 *
		 * @return The default maximum.
		 *
		 * @since 1.8
		 */
		private Integer defaultMaximumStackDepth(Integer launchDepth)
		{
			return launchDepth + steps.size() + 1 + MAXIMUM_NESTING_DEPTH;
		}

		/**
		 * @description Builds the options a chain runs under when the caller gave none: a new instance with only the
		 * framework's default maximum queueable stack depth (see defaultMaximumStackDepth).
		 *
		 * @param launchDepth The queueable stack depth the launching job runs at: 0 outside any queueable job, or when
		 * the platform does not let the framework read it.
		 *
		 * @return The default options.
		 *
		 * @since 1.10
		 */
		private AsyncOptions buildDefaultOptions(Integer launchDepth)
		{
			AsyncOptions defaultOptions = new AsyncOptions();
			defaultOptions.maximumQueueableStackDepth = defaultMaximumStackDepth(launchDepth);
			return defaultOptions;
		}

		/**
		 * @description Queues the first executor of a chain launched inside a group of jobs that already has a maximum
		 * queueable stack depth: from a chain job, or from any other queueable job queued with a maximum. The platform
		 * refuses a maximum set from inside a running job whose group of jobs already has one. So this hop is queued
		 * without options and uses the launching group's maximum. A caller's own maximum is not applied to this hop. The
		 * executor's own options, which its Finalizer uses from the second hop on, carry the depth the rest of the chain
		 * needs. A requested delay goes through the delay overload, which the platform accepts inside a job. A caller's
		 * duplicateSignature is not applied to this hop. A delay set on the caller's own options (minimumQueueableDelayInMinutes)
		 * is not applied to it either; withDelayMinutes is the way to delay it.
		 *
		 * @param executor The first executor.
		 *
		 * @return The enqueued job's id.
		 *
		 * @since 1.8
		 */
		private Id enqueueFirstExecutorUnderTheLaunchingMaximum(ChainExecutor executor)
		{
			return firstStepDelayMinutes != null && firstStepDelayMinutes > 0
					? System.enqueueJob(executor, firstStepDelayMinutes)
					: System.enqueueJob(executor);
		}

		/**
		 * @description Inserts the run record. A DUPLICATE_VALUE failure on a start with a deduplication key is
		 * ASSUMED to come from the deduplication key field. The platform hides the name of the clashing field from
		 * most callers, so a clash on the other unique field can be counted here too. A lookup of the run that holds
		 * the key (the winner), and a single retry, settle which it was. If a run holds the key, the start returns
		 * that run, which is the correct result. If the lookup is empty, the winner has released the key, or the
		 * clash was never on the deduplication key field, and the insert is tried again exactly once. A second
		 * failure gets the same lookup a second time. So a launch that lost a race to a new key holder still
		 * returns that run. A launch that was cleared of a deduplication clash twice, and whose correlation could
		 * really have clashed, is refused by the correlation rule instead of raising a database error that names
		 * nothing (see asRetryFailure for why a correlation the framework created is left out). The one extra
		 * query is spent only on a start that is already failing.
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
		 * @description Finds, for a SECOND failed start, the run that took the deduplication key while
		 * this launch was trying again. The retry happens because the first lookup of the key holder
		 * came back empty, so the key was free at that moment. If the retry then fails on a duplicate
		 * too, one of two things happened. Either another launch took the key in between (a real race,
		 * and the start belongs on that run), or the key field was never the one that clashed. Only a
		 * duplicate is worth a lookup. Any other platform failure is a different problem and must reach
		 * the caller as it was reported. An empty answer here clears the deduplication key field a
		 * second time, which leaves CorrelationId__c as the only unique field that can have clashed.
		 *
		 * @param retryError The exception the re-attempted insert raised.
		 *
		 * @return The Id of the run that won the race for the key, or null when no run holds the key.
		 *
		 * @since 1.7
		 */
		private String resolveRacedRun(DmlException retryError)
		{
			return isDuplicateValueFailure(retryError) ? new SEL_AsyncChainExecution().findByActiveDeduplicationKey(deduplicationKey)?.Id : null;
		}

		/**
		 * @description Handles a start that failed TWICE, after the lookup of the key holder came back
		 * empty both times. A correlation the framework created for this launch cannot already belong
		 * to anything, so its failure is left exactly as the platform reported it. There, a duplicate
		 * error together with an empty lookup means a deduplication race, not a correlation clash, and
		 * calling it one would send the caller after the wrong field. When the caller supplied the
		 * correlation, CorrelationId__c is the only field left that can have clashed, so the start is
		 * refused by the correlation rule.
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
		 * @description Finds, for a failed insert, the run that currently holds the key. A chain started
		 * without a deduplication key can never clash on the deduplication key field, so its failures
		 * never reach the lookup of the key holder. Failures of a chain with a key reach it only when
		 * isActiveDeduplicationKeyCollision assumes they come from the deduplication key field. Every
		 * other failure goes to asCorrelationCollision. That method turns the one clash a launch can
		 * have on the other unique field into a refusal that names the rule, and passes anything else
		 * on exactly as the platform reported it. A failure with a key that still happens on the retry
		 * is handled by resolveRacedRun, so both message forms end at the same refusal.
		 *
		 * @param insertError The exception the failed insert raised.
		 * @param correlationId The correlation the failed insert tried to attach.
		 *
		 * @return The Id of the run holding the key, or null when the key has already been released.
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
		 * flagged via isErrorHandler / isCompletionHandler. Order rule: handler entries always
		 * follow the step entries, so saved step indices equal runtime step indices, and readers
		 * can filter the handlers out without shifting anything. Saving the handlers lets code that
		 * has only the record to work from rebuild the chain's full shape after the executor's state
		 * is gone. That code is the watchdog sweep's stall notification and its re-drive, which
		 * rebuilds the chain from the record.
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
	 * @description Builds the AsyncOptions for the chain's FIRST enqueue: a copy of the options in use,
	 * with an optional delay for that one hop. A copy is required. The options in use may be the caller's
	 * own object, which is passed from executor to executor to every later hop, and a delay left on it
	 * would repeat on each of them (the Finalizer retry path describes the same risk).
	 * The copy carries every property AsyncOptions has on API 68.0 (maximumQueueableStackDepth,
	 * minimumQueueableDelayInMinutes, duplicateSignature). Check this list again on every
	 * apiVersion change, or a property added by a newer API is silently dropped from the
	 * first hop.
	 * AsyncOptions cannot be read back after the job is submitted, so this method is the only place a test can check
	 * the options that were built. Only UTIL_AsyncChain_TEST calls it.
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
	 * @description What the group of queueable jobs looks like to a chain launch. The group is the jobs queued one from
	 * another, from the same first job. This class holds whether the launch runs inside a queueable job, whether the
	 * platform let the framework read the group, the depth the running job sits at, and the maximum the group was
	 * given. A group the platform does not let the framework read looks like no group at all: depth 0 and no maximum.
	 */
	private class QueueableLineage
	{
		/**
		 * @description True when the launch runs inside a queueable job.
		 */
		private final Boolean isInsideQueueable;

		/**
		 * @description True when the platform answered the framework's questions about the group, or when there was nothing
		 * to ask. False inside a trigger fired by a save that a queueable job makes, where a job queued from there starts
		 * a new group of jobs.
		 */
		private final Boolean isReadable;

		/**
		 * @description The queueable stack depth the launching job runs at, or 0 outside a job or when it cannot be read.
		 */
		private final Integer currentDepth;

		/**
		 * @description The maximum queueable stack depth of the group, or null when the group has none or it cannot be read.
		 */
		private final Integer maximumDepth;

		/**
		 * @description Creates the description of a group of jobs.
		 *
		 * @param isInsideQueueable True when the launch runs inside a queueable job.
		 * @param isReadable True when the platform answered the questions about the group.
		 * @param currentDepth The depth the launching job runs at.
		 * @param maximumDepth The group's maximum, or null when it has none.
		 */
		private QueueableLineage(Boolean isInsideQueueable, Boolean isReadable, Integer currentDepth, Integer maximumDepth)
		{
			this.isInsideQueueable = isInsideQueueable;
			this.isReadable = isReadable;
			this.currentDepth = currentDepth;
			this.maximumDepth = maximumDepth;
		}

		/**
		 * @description Whether the group already has a maximum queueable stack depth, which a job inside it cannot change.
		 *
		 * @return True when the group has a maximum.
		 */
		private Boolean hasMaximum()
		{
			return maximumDepth != null;
		}
	}

	/**
	 * @description Inserts a run record on the one launch path that has no deduplication check: a
	 * chain with no steps. Such a chain completes at once, so it never takes a deduplication key. The
	 * only unique field that can clash is the correlation, so any duplicate here is that clash, and it
	 * gets the same refusal a chain with steps would give.
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
	 * @description Treats a failed launch insert as a correlation clash when it can only be one,
	 * and passes everything else through untouched. The field is found by ruling out the others,
	 * not by reading the message text. The platform hides both the clashing field and the record
	 * holding it from most callers. So a launch already cleared of a deduplication clash that still
	 * reports a duplicate can only have hit CorrelationId__c, the object's one other unique field.
	 * It names the run that already holds the correlation when the caller can see it (one read that
	 * respects sharing, on a path that is already failing), and uses the unnamed wording otherwise.
	 * Anything that is not a duplicate, such as a validation rule or a value the field cannot hold,
	 * is a different problem. It is handed back exactly as the platform reported it, because calling
	 * it a correlation clash would send the caller looking for the wrong thing.
	 * This assumes the object has exactly these two unique fields. A new unique field on
	 * AsyncChainExecution__c breaks that reasoning and must be handled here.
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
		AsyncChainExecution__c holderRun = new SEL_AsyncChainExecution().findByCorrelationId(correlationId);
		String holder = holderRun == null
				? CORRELATION_HOLDER_UNNAMED
				: String.format(CORRELATION_HOLDER_NAMED, new List<String> {holderRun.Id});
		return new UTIL_Exceptions.IllegalStateException(String.format(CORRELATION_COLLISION_MESSAGE, new List<String> {correlationId, holder}), insertError);
	}

	/**
	 * @description Writes one entry in the launcher's log when a chain is launched while a correlation ID is active.
	 * The entry is filed under that correlation ID and its root, points at the new run's record, and names the ID the
	 * run is recorded under and the ID it was launched under. A reader of the launching transaction's entries, or of
	 * the parent run's entries, sees what was launched and can open it. A launch with no active correlation ID starts
	 * its own action and writes nothing here.
	 *
	 * @param chainName The chain the launch started.
	 * @param runCorrelationId The correlation the run is recorded under.
	 * @param launchCorrelationId The correlation active in the launching transaction, or null.
	 * @param executionId The run record the entry points at.
	 *
	 * @since 1.8
	 */
	private static void announceLaunch(String chainName, String runCorrelationId, String launchCorrelationId, String executionId)
	{
		if(String.isBlank(launchCorrelationId))
		{
			return;
		}
		LOG_Builder.build()
				.info(String.format(CHAIN_LAUNCHED_MESSAGE, new List<String> {chainName, runCorrelationId, launchCorrelationId}))
				.at(CLASS_NAME + '.announceLaunch')
				.forRecord(executionId)
				.emit();
	}

	/**
	 * @description True when a failed write is assumed to clash on the deduplication key field: a
	 * DUPLICATE_VALUE whose message does NOT name CorrelationId__c. The field name is read through
	 * the describe cache, so the match is exact in both namespaced and unmanaged deploys. The check
	 * looks for the field that is NOT there, because the platform's messages vary. Field API names
	 * appear unchanged in translated platform messages. But for callers without access to all
	 * records, the platform hides the field name completely. So a check that looked for the
	 * deduplication field's name would fail for exactly those callers. This assumes
	 * AsyncChainExecution__c has exactly two unique fields (CorrelationId__c and
	 * ActiveDeduplicationKey__c). A new unique field must be added to the names this check rules out.
	 * Two callers use it. The first is the guarded first insert. There, when the field name is
	 * hidden, a CorrelationId__c clash on a start with a key can be counted here; the lookup of the
	 * key holder and the single retry sort that out safely. The second is the operator retry's update
	 * that takes the key back. That update writes no CorrelationId__c, so every DUPLICATE_VALUE there
	 * comes from the deduplication key field.
	 *
	 * @param duplicateError The exception the failed write raised.
	 *
	 * @return True for a clash assumed to be on the deduplication key field.
	 */
	private static Boolean isActiveDeduplicationKeyCollision(DmlException duplicateError)
	{
		return isDuplicateValueFailure(duplicateError)
				&& !duplicateError.getDmlMessage(0).contains(UTIL_SObjectDescribe.getCachedFieldName(AsyncChainExecution__c.CorrelationId__c));
	}

	/**
	 * @description True when a failed write is a clash on a unique field at all, and not some other
	 * write failure, such as one a subscriber validation rule or an oversized value can raise. Every
	 * check in this class for a unique-field clash starts here, so none of them can mistake an
	 * unrelated platform failure for a duplicate.
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
	 * A chain can stall in the middle of this step: for example, Salesforce ends the step's job after the request went
	 * out and before the result was saved. The chain's watchdog, the scheduled job that finds stuck chains, then runs the
	 * step again only when its request is safe to send twice: the handler's getHttpMethod() is GET, PUT or DELETE, or
	 * the handler's API setting has Idempotency Enabled, so every attempt carries an Idempotency-Key. Any other API step
	 * ends the chain as Failed, with a reason that names the step, because the external system may already have acted
	 * on the request. An API step whose request is safe to send twice can also be retried from the Chain Monitor after
	 * it fails. The step decides this when the chain is built, so it cannot see a createRequest() override that removes
	 * the Idempotency-Key header: for such a handler, do not rely on Idempotency Enabled.
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
		 * @description The API_Outbound subclass to execute. Used at build time only; not serialized.
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
		 * Set at build time by withRetry(). work() sets it again from the saved configuration before
		 * the callout, so the retry check after work() finds it on the newly created instance. Null
		 * when chain-level retry is not configured.
		 */
		private Integer retryMaxAttempts;

		/**
		 * @description Base backoff seconds fed to UTIL_Retry.exponential(). Stored only together
		 * with retryMaxAttempts: the two are both set or both absent.
		 */
		private Integer retryBackoffSeconds;

		/**
		 * @description Status codes that may be retried at chain level, or null (the default) to
		 * retry on any status. Set at build time. It is saved as a JSON string in the step
		 * configuration, and work() sets it again beside the two retry fields. The configuration
		 * map reaches work() in two forms: as the map built in memory, and after a round trip
		 * through deserializeUntyped. A JSON string is the one form that arrives the same both ways.
		 */
		private Set<Integer> retryableStatusCodes;

		/**
		 * @description No-argument constructor for reflection-based instantiation by the chain executor.
		 * Do not use it directly: use the Type constructor instead.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public ApiStep()
		{
			// Required by Type.newInstance(): the chain executor creates the step again through this constructor.
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
		 * NextRetry__c rescheduling is turned off for calls made by this step, so only one part of the
		 * framework decides retries, never two. The chain does not re-run the step when the external system may
		 * already have acted on a request that is not safe to repeat, which is a POST or PATCH sent
		 * with no Idempotency-Key: when the call got no response, when the external system responded
		 * with 500, 502 or 504, or when the external system accepted the request and the call then
		 * failed in your org. The step then fails at once, whatever retry budget is left, and its
		 * message starts with the reason. A handler that throws
		 * UTIL_Exceptions.PermanentFailureException fails the step at once too, whatever the
		 * method or key. A GET, PUT or DELETE, a request sent with an Idempotency-Key and a
		 * callout the platform refused before it left the org are re-run as usual. A status named in
		 * retryOn(...) is re-run whatever the method. Without this call the outbound engine alone
		 * decides retries. These rules cover a call that failed. A chain that stalled in the middle
		 * of this step follows the rule in the ApiStep class description, with or without this call.
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
		 * @description Restricts chain-level retry to the given HTTP status codes. It is the ApiStep
		 * version of UTIL_HttpClient's retryOn. A failed call whose status is outside the set is
		 * declared permanently failed: the chain fails on that attempt without spending the
		 * remaining retry budget, because the status shows the failure will happen again on every try (a 400
		 * returns 400 however often it is re-sent). Without this call every failed status
		 * retries, except a 500, 502 or 504 to a request that is not safe to repeat (see
		 * withRetry). A status named here is re-run whatever the method, a 500, 502 or 504 to a
		 * POST with no Idempotency-Key included: naming it accepts that the external system may
		 * act on the request twice. The one exception is a UTIL_Exceptions.PermanentFailureException
		 * thrown by the handler: it says the call must never be retried, so the step fails for good
		 * whatever this set holds. A failure with no status code at all (the transport threw
		 * before any response arrived) is re-run for a GET, PUT or DELETE, for a request sent
		 * with an Idempotency-Key and for a callout the platform refused before it left the org;
		 * for a POST or PATCH with no Idempotency-Key it fails at once whatever this set holds,
		 * as does a failure after the external system accepted such a request. So passing an
		 * empty set on purpose stops every failure that has a status code from retrying. Has no
		 * effect unless withRetry(...) enabled chain-level retry, matching the UTIL_HttpClient family.
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
		 * @description Whether a repeat run of this step is safe, worked out once, when the chain is built: true when the
		 * handler's request is safe to send again (see API_Outbound.isDeclaredRequestSafeToRepeat). The chain stores the
		 * answer in the step log. The watchdog reads it when the chain stalls after this step started and left no saved
		 * result (true: run the step again; false: end the chain Failed), and the Chain Monitor's retry-from-failed-step
		 * button reads it after the step failed. A step recreated by class name carries no handler type and answers
		 * false (creating a handler from no type throws, and every throw answers false). Creating the handler runs its
		 * configure() and its first read of the setting, one custom metadata query, the same read the handler makes when
		 * it sends; there is no callout and no DML. The logging context the handler's configure() opens is cleared once
		 * the answer is known, so the build leaves none behind. The handler is judged as created,
		 * with none of the step's parameters, triggering record or credential applied, so a handler whose getHttpMethod()
		 * depends on those inputs is judged on the answer it gives without them. A handler that cannot be created,
		 * whose configure() throws or whose setting read throws answers false, the safe answer, so a broken handler never
		 * stops the chain from being built. A handler whose createRequest() override removes the Idempotency-Key header
		 * sends its POST or PATCH with no key although Idempotency Enabled is set, which this answer cannot see: a step
		 * with such a handler should not rely on the setting.
		 *
		 * @return True when the handler's request is safe to send again; false otherwise.
		 */
		public override Boolean isIdempotent()
		{
			API_Outbound handler;
			try
			{
				handler = (API_Outbound)handlerType.newInstance();
				return handler.isDeclaredRequestSafeToRepeat();
			}
			catch(Exception handlerNotReadable)
			{
				return false;
			}
			finally
			{
				handler?.clearLoggingContext();
			}
		}

		/**
		 * @description Builds the chain-level retry strategy from the retry fields that work() sets
		 * before the callout: exponential backoff with maxAttempts minus 1 retries. Null when
		 * withRetry was never configured. Then the step makes a single attempt, and the outbound
		 * engine alone decides retries.
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
		 * a numeric status inside Integer range, and that status is not in the filter. A status
		 * the filter cannot read (blank, not a number, or too many digits for an Integer, since
		 * isNumeric does not check the range and valueOf can still throw) counts as retryable here.
		 * Without a status that can be read, nothing shows that the failure will always happen again. This filter
		 * decides by status alone. A failure with no status of a request that is not safe to
		 * repeat is stopped by work(), which asks the handler whether it refuses the repeat
		 * because the external system may have acted.
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
		 * @description Whether the chain must not re-run a failed call because the handler refuses
		 * the repeat: its code threw a UTIL_Exceptions.PermanentFailureException, or the external
		 * system may already have acted on a request that is not safe to repeat. The handler
		 * answers this only when the chain owns the retries, so it is never true without
		 * withRetry(...). A refusal status the step named in retryOn(...) is the author's own
		 * choice and is re-run; a call with no response, or one the external system accepted (a
		 * success status), is never re-run that way. A permanent failure outranks retryOn(...): it
		 * is the handler's explicit word that the call must never be retried, so the step stops
		 * whatever status the step named.
		 *
		 * @param handler The handler that made the call.
		 *
		 * @return True when the failure must not be re-run.
		 */
		private Boolean isRepeatRefusedByTheHandler(API_Outbound handler)
		{
			return handler.isRepeatRefusedByAPermanentFailure()
					|| (handler.isRepeatRefusedByTheHandler() && !isRefusalStatusNamedInRetryOn(handler.result.statusCode));
		}

		/**
		 * @description Whether the failed status is a refusal by the external system that the step
		 * named in retryOn(...). A blank status (no response) and a success status (the external
		 * system accepted the request) are never named this way.
		 *
		 * @param failedStatusCode The failed call's status code as recorded by the outbound engine.
		 *
		 * @return True when retryOn(...) names the refusal status.
		 */
		private Boolean isRefusalStatusNamedInRetryOn(String failedStatusCode)
		{
			if(retryableStatusCodes == null || failedStatusCode?.isNumeric() != true)
			{
				return false;
			}
			Integer statusCode = Integer.valueOf(failedStatusCode);
			return retryableStatusCodes.contains(statusCode) && !API_Base.HTTP_SUCCESS_CODES.contains(statusCode);
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
		 * and writes results back to the context for downstream steps. A failure the chain must
		 * not re-run (a status outside retryOn(...), a UTIL_Exceptions.PermanentFailureException
		 * from the handler, or a request that is not safe to repeat after the external system may
		 * have acted on it, as withRetry(...) describes) fails the step for good; the step's
		 * message then carries the handler's errors, which say why.
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
			// Lookup through the framework's type resolver: a plain Type.forName here only sees the kern namespace.
			// A subscriber's handler would pass then() as a name and then not be found when the step is created
			// again. The find method returns null when nothing matches, so this step still fails with a clear result.
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
			if(isPermanentByStatusFilter(handler.result.statusCode) || isRepeatRefusedByTheHandler(handler))
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
	 * isCompletionHandler). Handlers always come last, so saved step indices equal runtime step
	 * indices (see filterStepEntries). Public so other framework classes can use it
	 * (e.g., CTRL_ChainMonitor), but not global: subscribers work through ChainStep and StepResult.
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
		 * Copied from ChainStep.isIdempotent at build time. Null means false, and a null value is
		 * left out of the JSON, so the step log of a step that is not idempotent does not contain it.
		 */
		public Boolean isIdempotent;

		/**
		 * @description Whether an executor was ever enqueued to run this step, so the step may have run. Written in the
		 * transaction that queues the step's executor, before it is queued. For the first step that is the launch's
		 * insert. For every later step it is the previous hop's progress write. For a watchdog re-drive or an operator
		 * retry it is the write that gives the run a new run key, and for a restart it is the insert of the restart copy.
		 * It is removed only when the Finalizer fails to queue the step (the next step, or this step's retry) and the
		 * chain stalls, because then no executor exists for the step. Null means no executor was ever saved for the step.
		 * A null value is left out of the JSON. A step log saved by a package version without this member reads as never
		 * started, so the watchdog re-drives a stalled step of a chain that was running during the upgrade. The watchdog
		 * re-drives a step with this marker and no success marker only when the step declares itself idempotent: the
		 * step may already have done its work, a callout included.
		 */
		public Boolean started;

		/**
		 * @description Whether the watchdog refused to run this step again: the step started, left no result and never
		 * declared itself idempotent, so the watchdog ended the chain Failed at it (refuseRedriveOfStartedStep), which also
		 * sets success to false. Marks the entry as the step the chain stopped at even when it was added with continueOnError.
		 * Null means never refused. A null value is left out of the JSON, so the step log of a healthy chain does not
		 * contain it.
		 */
		public Boolean recoveryRefused;

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
		 * by the code that schedules retries. Null means the first attempt, and a null value is left
		 * out of the JSON. A step log with no attempt member is read as attempt 1, which keeps upgrades safe.
		 */
		public Integer attempt;

		/**
		 * @description Whether the step's terminal failure was declared permanent (failedPermanently).
		 * Set at runtime only when the final failure is saved. Null means false and is left out of the JSON.
		 */
		public Boolean permanentFailure;

		/**
		 * @description How long the step waited, in milliseconds, between the run's failure and an operator's retry. Written
		 * only by retryChainFromFailedStep: its presence says the step was retried manually, and MANUAL_RETRY_WAIT_UNKNOWN
		 * says the wait could not be measured. Null means never retried manually. A null value is left out of the JSON, so
		 * the step log of a step that was never retried manually does not contain it. The executor's rewrites never touch
		 * it, a second manual retry of the same step overwrites it, and a restart copy never copies it.
		 *
		 * @since 1.8
		 */
		public Long manualRetryAfterMs;

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
	 * @description Where a chain step stands, read from the runtime markers of its DTO_StepDefinition entry by
	 * resolveStepState. Public for the package's own classes (CTRL_ChainMonitor and the engine's retry checks), never global:
	 * it may change without notice.
	 */
	public enum StepState
	{
		/**
		 * @description No executor was ever committed for the step, so it never ran.
		 */
		NOT_STARTED,
		/**
		 * @description An executor was committed for the step and it has no result yet: it may be running, or it ran and
		 * stopped before its result was written.
		 */
		STARTED,
		/**
		 * @description The step recorded a success.
		 */
		SUCCEEDED,
		/**
		 * @description The step failed and the chain went on past it, because it was added with continueOnError.
		 */
		FAILED_CONTINUED,
		/**
		 * @description The step recorded a failure and was not added with continueOnError, so the chain did not go past it.
		 * A step that the watchdog refused to run again is RECOVERY_REFUSED instead.
		 */
		FAILED_STOPPED,
		/**
		 * @description The watchdog refused to run the step again (it started, left no result and never declared itself
		 * idempotent), and the chain stopped at it whatever its continueOnError says.
		 */
		RECOVERY_REFUSED
	}

	/**
	 * @description Resolves a step entry's state from its runtime markers. The rules are read in order and the first match
	 * wins: success == true is SUCCEEDED; success == false with recoveryRefused == true is RECOVERY_REFUSED; success == false
	 * with continueOnError == true is FAILED_CONTINUED; any other success == false is FAILED_STOPPED; started == true is
	 * STARTED; anything else is NOT_STARTED. The order only makes sure every combination of markers gives exactly one
	 * state, whether the engine can write that combination or not. A combination the engine never writes (for example
	 * success == true with recoveryRefused == true) does not become valid because it has an answer. The method reads
	 * markers and adds none. It serves CTRL_ChainMonitor and the engine's retry checks (isTerminalFailure,
	 * deriveResumeIndex, redriveStalledChain) and may change without notice.
	 *
	 * @param entry The step entry whose markers to read.
	 *
	 * @return The one state the markers resolve to.
	 */
	public static StepState resolveStepState(DTO_StepDefinition entry)
	{
		if(entry.success == true)
		{
			return StepState.SUCCEEDED;
		}
		if(entry.success == false)
		{
			if(entry.recoveryRefused == true)
			{
				return StepState.RECOVERY_REFUSED;
			}
			return entry.continueOnError == true ? StepState.FAILED_CONTINUED : StepState.FAILED_STOPPED;
		}
		return entry.started == true ? StepState.STARTED : StepState.NOT_STARTED;
	}

	/**
	 * @description Reports whether a state carries a result: the step ran to a success or a failure (SUCCEEDED,
	 * FAILED_CONTINUED, FAILED_STOPPED, RECOVERY_REFUSED). STARTED and NOT_STARTED carry none. deriveResumeIndex reads it to
	 * find the first entry a re-drive can resume at.
	 *
	 * @param state The resolved state of a step entry.
	 *
	 * @return True when the state is one of the four with a result.
	 */
	private static Boolean hasStepResult(StepState state)
	{
		return state == StepState.SUCCEEDED
				|| state == StepState.FAILED_CONTINUED
				|| state == StepState.FAILED_STOPPED
				|| state == StepState.RECOVERY_REFUSED;
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
		 * stored RunKey__c for a healthy run. Null for an executor queued by a package version
		 * without this field (a chain that was running during an upgrade).
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
		 * @description Only keeps the values. Nothing is checked, read or written until the platform runs execute. One
		 * executor runs the one step at currentStepIndex; the step after it gets an executor of its own.
		 *
		 * @param chainExecutionId The ID of the AsyncChainExecution__c record.
		 * @param currentStepIndex The zero-based index of the step to execute.
		 * @param maxSteps Maximum number of steps allowed.
		 * @param maxContextSize Maximum serialized context size in characters.
		 * @param errorHandler The error handler step definition, or null.
		 * @param completionHandler The completion handler step definition, or null.
		 * @param asyncOptions AsyncOptions for controlling queueable chaining depth.
		 * @param capturedRunKey The run key captured at enqueue time, or null for a run started by a package version without run keys.
		 */
		@TestVisible
		@SuppressWarnings('PMD.PrivateMethodParameterCap')
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

			// The saved document holds the handler entries after the steps (the serialization order rule).
			// Step counting (indexing, completion counting, the terminal check) works on the filtered list of steps.
			// Each save serializes the full document again, so the handler entries are kept on every rewrite.
			// Both lists share the same entries, so runtime step results show in both.
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
				markRunningStep(chainExecutionId, String.valueOf(currentStepIndex), context);
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
			clearRunningStep();

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
			// The id of the queueable job doing this step's work, which the watchdog reads to check that the run is alive.
			// Exactly two methods write CurrentJobId__c. One is stampExecutorJobId, called at the first enqueue and at every
			// watchdog or operator re-enqueue. The other is the progress write in persistProgressAndChainNext, whose field
			// list includes this value. So final writes leave the last known executor's job id in place, and
			// HandlerExecutor never writes it (handlers are notifications, not chain executors).
			execution.CurrentJobId__c = queueableContext.getJobId();

			String serializedContext = serializeContextWithinLimit(execution, context);
			if(serializedContext == null)
			{
				return;
			}

			Boolean chainContinues = currentStepIndex + 1 < steps.size();
			if(chainContinues)
			{
				// The next step's start is recorded in THIS hop's progress write, before the Finalizer queues its
				// executor. It is the only saved sign that can come before the step's work (a write inside the next hop
				// would block its callout), and it costs no DML statement of its own. The watchdog reads it to tell a step that
				// never ran from one that ran and left no result; see deriveResumeIndex and redriveStalledChain.
				steps[currentStepIndex + 1].started = true;
			}
			execution.ContextData__c = serializedContext;
			execution.StepLog__c = serializeStepLog(persistedDefinitions);

			if(!chainContinues)
			{
				handleChainCompletion(execution, context);
				return;
			}

			persistProgressAndChainNext(execution, continuedFailureAppended);
		}

		/**
		 * @description Loads the chain execution record and applies the entry guards: a deleted
		 * record, an externally aborted chain, and a stale run key each make this executor stop without
		 * running a step or writing to the record.
		 *
		 * @return The loaded execution record, or null when the executor must stop (the caller exits
		 * immediately without touching the record).
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
		 * @description Handles a failed step result: asks the step's retry strategy first, then
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
		@SuppressWarnings('PMD.PrivateMethodParameterCap')
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
			// The retry check comes before the continueOnError check, so a step added with continueOnError
			// only lets the chain go on after its final attempt. The strategy is read again after work() on
			// purpose: for ApiStep the strategy only exists once work() has run.
			UTIL_Retry.Strategy retryStrategy = resolveRetryStrategy(step);
			if(result.permanentFailure != true
					&& retryStrategy != null
					&& retryStrategy.shouldRetry(UTIL_Retry.newContext(attemptNumber - 1).withCustomData(result.error)))
			{
				scheduleRetry(execution, context, stepDefinition, retryStrategy, attemptNumber);
				return true;
			}

			// Every path below refuses a retry, so the failure is final. The value set before work() could not
			// know that, so correct it before this context is passed to any handler with the failure.
			// Rule: a path that refuses a retry sets finalAttempt again first, or says why it does not.
			context.finalAttempt = true;

			if(stepDefinition.continueOnError != true)
			{
				// Set the declared-permanent marker before this final StepLog serialization:
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
		 * @description Saves the step's progress and tells the Finalizer to queue the next step. The save
		 * is a sparse update (it sets only the named fields) and is fenced: it first checks that the run
		 * key still matches. A stale run key skips both the write and the enqueue, and the executor stops
		 * without doing anything more.
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
		 * @description Finalizer callback. It does one of three things:
		 * 1. On success, it queues the next step.
		 * 2. When scheduleRetry asked for a retry, it queues this executor again at the same step index.
		 *    The strategy's backoff delay applies to that one enqueue only. The rebuilt executor carries
		 *    options with no delay and with the raised stack depth, so the hops after the retry run
		 *    without added delay.
		 * 3. On an unhandled exception (governor limits, platform errors), it marks the chain as Failed.
		 *    This stops chains from staying in Running status after their job has died.
		 *
		 * Finalizers receive fresh governor limits from the platform.
		 * Enqueue failures are temporary (async budget used up, queue rejection) and lead to Stalled,
		 * where the run waits for recovery. A Queueable crash leads to Failed. Which one applies depends
		 * on where the failure happened, never on the exception text. A failed enqueue of the next step,
		 * or of a retry, also removes the started marker of the step it could not queue. No executor
		 * exists for that step, so the watchdog may re-drive it (see
		 * serializeStepLogWithoutTheFailedEnqueuesStart). A failed enqueue of the error or completion
		 * handler comes after the chain has ended. So the chain keeps its Failed or Completed status, and
		 * the row notes which handler was not run (see markHandlerNotQueuedFromFinalizer). Each of the
		 * three branches moves the run through applyRunTransition with its own run event.
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
						Integer retryDepth = persistedDefinitions.size() + 1 + RETRY_STACK_DEPTH_ALLOWANCE;
						retryOptions.maximumQueueableStackDepth = Math.max(asyncOptions?.maximumQueueableStackDepth ?? 0, retryDepth);
						retryOptions.minimumQueueableDelayInMinutes = retryDelayMinutes;
						// The backoff delay belongs to the retry enqueue ONLY. The constructor gets a copy
						// with no delay and only the raised depth. Those options are passed on to every later
						// hop, and a delay left on them would repeat on every remaining hop of the chain.
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
					String stallReason = 'Finalizer failed to enqueue next step: ' + enqueueError.getMessage();
					markChainStalledFromFinalizer(chainExecutionId, stallReason, serializeStepLogWithoutTheFailedEnqueuesStart());
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
					System.enqueueJob(pendingHandler, buildHandlerEnqueueOptions());
				}
				catch(Exception enqueueError)
				{
					markHandlerNotQueuedFromFinalizer(chainExecutionId, pendingHandler, enqueueError.getMessage());
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
		 * @description The options the Finalizer queues a completion or error handler with: a new instance with the
		 * chain's maximum queueable stack depth plus the nesting reserve. The handler runs one hop after the last step.
		 * With a caller's own tight options, that is already at the chain's maximum. So the reserve gives the handler
		 * room to launch one chain, or a queueable of its own, and gives the chain it launches room for its own first
		 * hops. A handler queued without options would have no maximum, which in a test leaves it no room to launch
		 * anything. A caller's delay or duplicate signature is never copied, the same rule as for a retry. A chain
		 * running without a maximum gives the handler none either.
		 *
		 * @return The handler's enqueue options.
		 *
		 * @since 1.8
		 */
		private AsyncOptions buildHandlerEnqueueOptions()
		{
			AsyncOptions handlerOptions = new AsyncOptions();
			Integer chainDepth = asyncOptions?.maximumQueueableStackDepth;
			handlerOptions.maximumQueueableStackDepth = chainDepth == null ? null : chainDepth + MAXIMUM_NESTING_DEPTH;
			return handlerOptions;
		}

		/**
		 * @description Marks a chain as Failed from the Finalizer context, through applyRunTransition with the
		 * QUEUEABLE_CRASHED run event fenced by this executor's captured run key: a re-driven chain must not be failed by its
		 * old executor, and a run that already ended or was aborted is refused by the table. Wraps the transition
		 * in try/catch because the Finalizer is the last recovery point: if the write fails (a row lock, for one), the
		 * error is logged but the Finalizer must not throw. The terminal log is written only after a write that went through.
		 *
		 * @param executionId The chain execution record ID.
		 * @param errorMessage The failure message.
		 */
		@TestVisible
		private void markChainFailedFromFinalizer(Id executionId, String errorMessage)
		{
			try
			{
				if(!applyRunTransition(buildFinalizerRequest(executionId, RunEvent.QUEUEABLE_CRASHED, errorMessage)))
				{
					return;
				}
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
		 * @description Marks a chain as Stalled from the Finalizer context after a transient enqueue failure, through
		 * applyRunTransition with the ENQUEUE_FAILED run event fenced by this executor's captured run key: a stale executor's
		 * Finalizer must not mark anything, and a chain that already ended or was aborted is refused by the table. After
		 * a write that went through, the stall is logged (at ERROR when the chain has no onError handler, at WARN otherwise), and
		 * this executor's own onError handler is notified only when the fresh row was not already Stalled, so a chain
		 * marked twice notifies once. Wraps the transition in try/catch because the Finalizer is the last recovery
		 * point: if the stall write fails, the error is logged, the notification is skipped, and the Finalizer must not
		 * throw.
		 *
		 * @param executionId The chain execution record ID.
		 * @param errorMessage The stall reason.
		 * @param stepLog The step log the stall write also carries (a failed step enqueue takes that step's start back), or null to leave the step log as it is.
		 */
		@TestVisible
		private void markChainStalledFromFinalizer(Id executionId, String errorMessage, String stepLog)
		{
			try
			{
				RunTransitionRequest request = buildFinalizerRequest(executionId, RunEvent.ENQUEUE_FAILED, errorMessage);
				if(stepLog != null)
				{
					request.record.StepLog__c = stepLog;
					request.callerFields.add(AsyncChainExecution__c.StepLog__c);
				}
				markStalledAndNotify(request, errorHandler, false);
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
		 * @description Records on a chain that has already ended that its completion or error handler was not run,
		 * because the Finalizer could not queue it, through applyRunTransition with the HANDLER_NOT_QUEUED run event fenced by
		 * this executor's captured run key. The status, failure category and end time stay as they are; the note
		 * from the AsyncChain_HandlerNotQueued label, naming the handler's position and name, goes after any message
		 * already on the row, with the platform's reason after it. No handler runs: queueing the onError handler again
		 * would fail for the same reason in the same transaction. After a write that went through, one ERROR log names the chain,
		 * the status it ended with and the note, so the missed handler is seen even when the row's message is not read.
		 * Wraps the transition in try/catch because the Finalizer must not throw.
		 *
		 * @param executionId The chain execution record ID.
		 * @param handler The handler executor that could not be queued.
		 * @param enqueueFailureMessage The platform's reason for the refused enqueue.
		 */
		private void markHandlerNotQueuedFromFinalizer(Id executionId, HandlerExecutor handler, String enqueueFailureMessage)
		{
			try
			{
				String handlerNote = String.format(System.Label.AsyncChain_HandlerNotQueued,
						new List<String> {handler.handlerPosition(), resolveStepDisplayName(handler.handlerDefinition)});
				String note = handlerNote + HANDLER_NOTE_REASON_SEPARATOR + enqueueFailureMessage;
				RunTransitionRequest request = buildFinalizerRequest(executionId, RunEvent.HANDLER_NOT_QUEUED, note);
				if(!applyRunTransition(request))
				{
					return;
				}

				LOG_Builder.build().error('Chain ' + request.record.ChainName__c + ' ended ' + request.record.Status__c + HANDLER_NOTE_REASON_SEPARATOR + note)
						.at(CLASS_NAME + '.ChainExecutor.Finalizer')
						.forRecord(executionId)
						.emit();
			}
			catch(Exception dmlError)
			{
				LOG_Builder.build().error('Finalizer handler note DML failed: ' + dmlError.getMessage() + ' | Enqueue failure: ' + enqueueFailureMessage)
						.at(CLASS_NAME + '.ChainExecutor.Finalizer')
						.forRecord(executionId)
						.emit();
			}
		}

		/**
		 * @description Builds a transition request for one of the Finalizer's branches: fenced by this executor's captured
		 * run key (the write happens only while the run key still matches), with the given run event and message, and no
		 * caller fields until the caller adds one.
		 *
		 * @param executionId The chain execution record ID.
		 * @param runEvent The run event the branch moves the run through.
		 * @param message The message the run event records.
		 *
		 * @return The request, ready for applyRunTransition.
		 */
		private RunTransitionRequest buildFinalizerRequest(Id executionId, RunEvent runEvent, String message)
		{
			return buildFencedRunTransitionRequest(new AsyncChainExecution__c(Id = executionId), runEvent, capturedRunKey, message);
		}

		/**
		 * @description Handles a step failure: ends the run Failed through applyRunTransition with the STEP_FAILED run event,
		 * fenced by this executor's captured run key, carrying the failed step's name, the context and the step log as
		 * caller fields and the given failure category. After a write that went through, it emits the terminal log and
		 * queues the error handler. A refused write (a stale key, or a run other code already ended) does nothing.
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
				Integer errorMessageFieldLength = UTIL_SObjectDescribe.getCachedFieldDescribe(AsyncChainExecution__c.ErrorMessage__c).length;
				Integer reservedLength = errorMessageFieldLength - CONTEXT_NOT_PRESERVED_MARKER.length() - UTIL_String.SPACE.length();
				String abbreviatedBase = UTIL_String.abbreviate(terminalMessage, reservedLength);
				// Blank, not just null: a step that fails with an empty message would otherwise leave the
				// marker behind a separator with nothing in front of it. The platform happens to trim that
				// leading space when it saves the long text area, so the record looks right either way.
				// This builds the message correctly rather than relying on that.
				terminalMessage = (String.isBlank(abbreviatedBase) ? UTIL_String.EMPTY : abbreviatedBase + UTIL_String.SPACE) + CONTEXT_NOT_PRESERVED_MARKER;
			}
			execution.CurrentStepName__c = UTIL_String.abbreviate(failedStepName, AsyncChainExecution__c.CurrentStepName__c);
			execution.ContextData__c = persistedContext;

			RunTransitionRequest request = buildFencedRunTransitionRequest(execution, RunEvent.STEP_FAILED, capturedRunKey, terminalMessage);
			request.failureCategory = failureCategory;
			request.callerFields.addAll(new List<SObjectField>
			{
					AsyncChainExecution__c.CurrentStepName__c,
					AsyncChainExecution__c.ContextData__c,
					AsyncChainExecution__c.StepLog__c
			});
			if(!applyRunTransition(request))
			{
				return;
			}

			emitTerminalLog(LoggingLevel.ERROR, 'Chain failed: ' + result.message, CLASS_NAME + '.ChainExecutor.handleStepFailure', execution.Id);

			if(errorHandler != null)
			{
				pendingHandler = new HandlerExecutor(execution.Id, context, errorHandler, SEL_AsyncChainExecution.STATUS_FAILED, result.message, capturedRunKey);
			}
		}

		/**
		 * @description Handles successful chain completion: ends the run Completed through applyRunTransition with the
		 * STEP_COMPLETED run event, fenced by this executor's captured run key, carrying the completed step count, the last
		 * step's name, the context and the step log as caller fields and the message this run accumulated from steps that
		 * failed but continued (see appendContinuedFailure). After a write that went through, it emits the terminal log
		 * and the performance log and queues the completion handler. A refused write (a stale key, or a run other code
		 * already ended) does nothing.
		 *
		 * @param execution The AsyncChainExecution__c record to update.
		 * @param context The current chain context.
		 */
		private void handleChainCompletion(AsyncChainExecution__c execution, ChainContext context)
		{
			execution.ContextData__c = UTIL_String.abbreviate(context.serialize(), AsyncChainExecution__c.ContextData__c);

			RunTransitionRequest request = buildFencedRunTransitionRequest(execution, RunEvent.STEP_COMPLETED, capturedRunKey, execution.ErrorMessage__c);
			request.callerFields.addAll(new List<SObjectField>
			{
					AsyncChainExecution__c.CompletedSteps__c,
					AsyncChainExecution__c.CurrentStepName__c,
					AsyncChainExecution__c.ContextData__c,
					AsyncChainExecution__c.StepLog__c
			});
			if(!applyRunTransition(request))
			{
				return;
			}

			emitTerminalLog(LoggingLevel.INFO, 'Chain completed: ' + request.record.ChainName__c, CLASS_NAME + '.ChainExecutor.handleChainCompletion', execution.Id);
			logChainPerformance(request.record);

			if(completionHandler != null)
			{
				pendingHandler = new HandlerExecutor(execution.Id, context, completionHandler, SEL_AsyncChainExecution.STATUS_COMPLETED, null, capturedRunKey);
			}
		}

		/**
		 * @description Ends the run Failed with the given message, for a failure of the chain itself rather than of a step
		 * (a context grown past its cap): through applyRunTransition with the STEP_FAILED run event and the StepException
		 * category, fenced by this executor's captured run key, carrying the completed step count and the current step's
		 * name as caller fields. After a write that went through, it emits the terminal log and the performance log. A
		 * refused write does nothing.
		 *
		 * @param execution The AsyncChainExecution__c record to update.
		 * @param message The failure message to record.
		 */
		private void markFailed(AsyncChainExecution__c execution, String message)
		{
			RunTransitionRequest request = buildFencedRunTransitionRequest(execution, RunEvent.STEP_FAILED, capturedRunKey, message);
			request.failureCategory = SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION;
			request.callerFields.addAll(new List<SObjectField> {AsyncChainExecution__c.CompletedSteps__c, AsyncChainExecution__c.CurrentStepName__c});
			if(!applyRunTransition(request))
			{
				return;
			}

			emitTerminalLog(LoggingLevel.ERROR, 'Chain failed: ' + message, CLASS_NAME + '.ChainExecutor.markFailed', execution.Id);
			logChainPerformance(request.record);
		}

		/**
		 * @description Aborts the run for the kill switch, through applyRunTransition with the KILL_SWITCH_ABORTED run
		 * event fenced by this executor's captured run key. An executor with a stale key (the old executor of a chain that
		 * was re-driven) that reaches the kill-switch path must not write a final abort over the current run. A run that
		 * already ended Completed or Failed is refused by the table. The in-memory record is never changed. After a write
		 * that went through, it emits the warning terminal log and the performance log.
		 *
		 * @param execution The AsyncChainExecution__c record to update.
		 * @param message The abort reason to record.
		 */
		@TestVisible
		private void markAborted(AsyncChainExecution__c execution, String message)
		{
			RunTransitionRequest request = buildFencedRunTransitionRequest(execution, RunEvent.KILL_SWITCH_ABORTED, capturedRunKey, message);
			if(!applyRunTransition(request))
			{
				return;
			}

			emitTerminalLog(LoggingLevel.WARN, 'Chain aborted: ' + message, CLASS_NAME + '.ChainExecutor.markAborted', execution.Id);
			logChainPerformance(request.record);
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
		 * to queue this executor again at the same step index. The write is fenced: it is skipped
		 * entirely when the run key no longer matches. The sparse update carries only the step log
		 * and context data, never the run key.
		 *
		 * @param execution The AsyncChainExecution__c record to update.
		 * @param context The current chain context.
		 * @param stepDefinition The definition of the step being re-attempted.
		 * @param retryStrategy The step's retry strategy, asked for the backoff delay.
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
		 * @description The persisted step log with the start of the step this Finalizer could not enqueue taken back, for
		 * the stall write: no executor exists for that step, so the watchdog may re-drive it as a step that never ran. After
		 * a failed next-step enqueue that is the next step, whose start this hop's progress write recorded before the enqueue
		 * was tried. After a failed retry-link enqueue it is this step: its earlier attempt ran and returned a failure the
		 * step's own retry strategy accepted for a repeat, and nothing was enqueued for the repeat, so taking the start back
		 * lets the watchdog run the repeat the strategy had already approved. The retry-pending markers (attempt, cleared
		 * success) stay as scheduleRetry wrote them.
		 *
		 * @return The step log to persist with the stall.
		 */
		private String serializeStepLogWithoutTheFailedEnqueuesStart()
		{
			Integer stepNotEnqueued = retryScheduled ? currentStepIndex : currentStepIndex + 1;
			filterStepEntries(persistedDefinitions)[stepNotEnqueued].started = null;
			return serializeStepLog(persistedDefinitions);
		}

		/**
		 * @description Builds the executor for a scheduled retry: the SAME step index and the SAME
		 * captured run key as this executor. A retry runs the same run again, so it does not get a new
		 * run key. Otherwise it is built the same way as the next-step executor.
		 *
		 * The options passed HERE are on purpose not the delayed retry options. The constructor's
		 * options are passed on to every later hop, which uses them to queue its own next step, so
		 * they carry only the raised stack depth. The backoff delay is set only on the AsyncOptions
		 * given to System.enqueueJob for the retry itself. If it were left on the options passed on,
		 * the delay would repeat on every remaining hop of the chain.
		 *
		 * @param carryForwardOptions The AsyncOptions with no delay that the rebuilt executor passes on
		 * to all later enqueues (raised stack depth only).
		 *
		 * @return The same-index executor to enqueue.
		 */
		private ChainExecutor buildSameIndexExecutor(AsyncOptions carryForwardOptions)
		{
			return new ChainExecutor(chainExecutionId, currentStepIndex, maxSteps, maxContextSize, errorHandler, completionHandler, carryForwardOptions, capturedRunKey);
		}

		/**
		 * @description Reads the execution record again and returns the fresh row when this executor
		 * still owns the record's current run, that is, when the captured run key matches the saved
		 * one. A mismatch means other code (a watchdog re-drive) has taken over the record. A missing
		 * record also means this executor may no longer write. Both return null, and the caller must
		 * skip its save and stop without doing anything more. Final writes take their refusal of an
		 * aborted row from this fresh row, never from in-memory values changed in the same method.
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
		/**
		 * @description The Id of the chain execution record this handler runs for. The record is read again before the handler
		 * runs, and the handler's outcome is written back to it.
		 */
		private final Id executionId;
		/**
		 * @description The chain's shared context, passed to the handler step. It is saved back to the execution record after
		 * the handler has run.
		 */
		private final ChainContext context;
		/**
		 * @description The definition of the completion or error handler step to create and run.
		 */
		private final DTO_StepDefinition handlerDefinition;
		/**
		 * @description The status the run had when this handler was queued: Completed for a completion handler, Failed or
		 * Stalled for an error handler. It names the handler's position and tells a stalled notification apart, whose
		 * failure or crash is only logged. What the write-back leaves on the record is decided by the run's fresh status
		 * in applyRunTransition, never by this field.
		 */
		private final String expectedStatus;
		/**
		 * @description The error that made the chain fail or stall, kept on the record when the handler succeeds and placed in
		 * front of the handler's own error when the handler fails. Null for a completion handler.
		 */
		private final String originalErrorMessage;
		/**
		 * @description The run key taken when this handler was put on the queue. The handler acts only while the execution
		 * record still stores the same run key. A different key means other code has taken over the run, and the handler
		 * then does nothing.
		 */
		private final String capturedRunKey;

		/**
		 * @description Only keeps the values. Nothing is read or written until the platform runs execute. The handler then
		 * acts only while the execution record still stores capturedRunKey; with any other key it only logs that it skipped.
		 *
		 * @param executionId The chain execution record ID.
		 * @param context The chain context to pass to the handler.
		 * @param handlerDefinition The handler step definition.
		 * @param expectedStatus The status the run had when this handler was queued: Completed, Failed or Stalled.
		 * @param originalErrorMessage The original error message (for error handlers), null for completion handlers.
		 * @param capturedRunKey The run key captured at enqueue time, or null for a run started by a package version without run keys.
		 */
		@TestVisible
		@SuppressWarnings('PMD.PrivateMethodParameterCap')
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
		 * @description The launch position of this handler: the completion handler's when the run completes, the error
		 * handler's otherwise, since a terminal failure and a stall notification run the same error handler.
		 *
		 * @return COMPLETION_HANDLER_POSITION or ERROR_HANDLER_POSITION.
		 *
		 * @since 1.8
		 */
		private String handlerPosition()
		{
			return expectedStatus == SEL_AsyncChainExecution.STATUS_COMPLETED ? COMPLETION_HANDLER_POSITION : ERROR_HANDLER_POSITION;
		}

		/**
		 * @description Runs the saved completion or error handler. On entry, findAuthorizedRun checks the run key (an
		 * executor with a stale run key logs the skip and does nothing). It then runs the handler step and writes the
		 * outcome back through applyRunTransition, again only while the captured run key matches, with the handler's
		 * context as the caller field. HANDLER_SUCCEEDED keeps the run's status and restores the original message.
		 * HANDLER_FAILED moves it to Failed with the original message and the handler's failure after it, and after a
		 * write that went through it emits the ERROR terminal log. A failed onError notification for a stalled run is not
		 * a transition: the failure is only logged, so the Stalled record, which can still be recovered, stays untouched.
		 * A refused write-back (a run that other code moved on) is logged by applyRunTransition and nothing else happens.
		 *
		 * @param queueableContext The Queueable context provided by the platform.
		 */
		public void execute(QueueableContext queueableContext)
		{
			System.attachFinalizer(this);
			hydrateLogContext(context, context.getCorrelationId());

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
				markRunningStep(executionId, handlerPosition(), context);
				result = handler.work(context);
			}
			catch(Exception handlerError)
			{
				result = failed(handlerError);
			}
			clearRunningStep();

			if(!result.success && expectedStatus == SEL_AsyncChainExecution.STATUS_STALLED)
			{
				// An onError notification for a stalled run is only a courtesy, not chain work. A broken handler
				// must not turn the Stalled record, which can still be recovered, into a final Failed one. Nor may it
				// overwrite the context a re-drive will rebuild the chain from. So the failure is logged and the
				// record is left untouched.
				LOG_Builder.build().error('Stalled onError handler failed: ' + result.message + ' | Stall reason: ' + originalErrorMessage)
						.at(CLASS_NAME + '.HandlerExecutor.execute')
						.forRecord(executionId)
						.emit();
				return;
			}

			String message = result.success ? originalErrorMessage : buildHandlerFailureMessage(result.message);
			RunTransitionRequest request = buildHandlerRequest(executionId, result.success ? RunEvent.HANDLER_SUCCEEDED : RunEvent.HANDLER_FAILED, message);
			request.record.ContextData__c = UTIL_String.abbreviate(context.serialize(), AsyncChainExecution__c.ContextData__c);
			request.callerFields.add(AsyncChainExecution__c.ContextData__c);
			if(!applyRunTransition(request))
			{
				return;
			}

			if(request.runEvent == RunEvent.HANDLER_FAILED)
			{
				emitTerminalLog(LoggingLevel.ERROR, 'Chain failed: ' + message, CLASS_NAME + '.HandlerExecutor.execute', executionId);
			}
		}

		/**
		 * @description Finalizer callback covering the handler's own crash: on UNHANDLED_EXCEPTION
		 * (governor limits, platform errors) it calls markHandlerFailed. That method writes only
		 * while the run key matches, leaves a Stalled record (which can still be recovered)
		 * untouched, and wraps its DML in try/catch: the Finalizer is the last recovery point
		 * and must not throw.
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
		 * @description Marks a chain as Failed from the HandlerExecutor Finalizer, through applyRunTransition with the
		 * HANDLER_FAILED run event fenced by the captured run key and no caller field. So a re-driven chain is not failed
		 * by its old executor, and a run that other code moved on is refused by the table. The run keeps the end time its
		 * final write set. applyRunTransition sets the StepException category only on a run that has none (a crashed
		 * completion handler), and keeps the category a Failed run already has. For an onError notification of a stalled
		 * run (expectedStatus Stalled), the crash is only logged and the record stays untouched. A Stalled run can still be
		 * recovered, and marking it Failed with a completion time would hide the chain from recovery. That log is written
		 * before any run key check, so another executor may have taken the run over by then. The log therefore says only
		 * that the record was not changed (STALLED_NOTIFICATION_CRASH_NOTE), never which status the run has. Wraps the transition
		 * in try/catch because the Finalizer is the last recovery point and must not throw. The terminal log is written
		 * only after a write that went through.
		 *
		 * @param handlerExecutionId The chain execution record ID.
		 * @param errorMessage The failure message.
		 */
		@TestVisible
		@SuppressWarnings('PMD.EmptyCatchBlock')
		private void markHandlerFailed(Id handlerExecutionId, String errorMessage)
		{
			if(expectedStatus == SEL_AsyncChainExecution.STATUS_STALLED)
			{
				LOG_Builder.build().error(errorMessage + STALLED_NOTIFICATION_CRASH_NOTE)
						.at(CLASS_NAME + '.HandlerExecutor.Finalizer')
						.forRecord(handlerExecutionId)
						.emit();
				return;
			}

			try
			{
				if(!applyRunTransition(buildHandlerRequest(handlerExecutionId, RunEvent.HANDLER_FAILED, errorMessage)))
				{
					return;
				}
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
		 * @description Builds a transition request for one of this handler's two run events, fenced by the run key this
		 * handler captured at enqueue time, with an Id-only record until the caller adds a caller field.
		 *
		 * @param runExecutionId The chain execution record ID.
		 * @param runEvent HANDLER_SUCCEEDED or HANDLER_FAILED.
		 * @param message The message the run event records.
		 *
		 * @return The request, ready for applyRunTransition.
		 */
		private RunTransitionRequest buildHandlerRequest(Id runExecutionId, RunEvent runEvent, String message)
		{
			return buildFencedRunTransitionRequest(new AsyncChainExecution__c(Id = runExecutionId), runEvent, capturedRunKey, message);
		}

		/**
		 * @description The message a failed handler leaves on the run: the original step failure, when the run had one,
		 * then the handler's own failure.
		 *
		 * @param handlerFailure The handler's failure message.
		 *
		 * @return The combined message.
		 */
		private String buildHandlerFailureMessage(String handlerFailure)
		{
			return String.isNotBlank(originalErrorMessage) ? originalErrorMessage + '; Handler failed: ' + handlerFailure : 'Handler failed: ' + handlerFailure;
		}

		/**
		 * @description Reads the execution record again and returns the fresh row when this handler
		 * executor still owns the record's current run, that is, when the captured run key matches the
		 * saved one. A mismatch means other code (a watchdog re-drive) has taken over the record. A
		 * missing record also means this executor may no longer write. Both return null, and the caller
		 * must skip its save and stop without doing anything more. Final writes take their refusal of an
		 * aborted row from this fresh row, never from in-memory values changed in the same method.
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
	 * @description Looks for chains that seem abandoned: Running or Stalled with no activity for
	 * longer than the threshold. sweepCandidate then decides what happens to each candidate. It runs
	 * the async-budget check, then the check for a run that has already ended, then the recovery
	 * decision, which depends on whether the executor job is still alive. That decision either only
	 * marks the run Stalled and notifies, or leaves a live executor alone, or re-drives a run whose
	 * executor is known to be dead. Called by the SCHED_ChainWatchdog scheduled job. The sweep is the
	 * part of the framework that decides recovery, so its writes do not check a captured run key.
	 *
	 * The rows the selector returns are only candidates, not proof of a dead executor. Only the
	 * AsyncApexJob check tells a chain that is really dead from one that is slow but alive, and only a
	 * proven dead executor leads to a re-drive. The stale threshold still matters (see sweepCandidate):
	 * set it generously, longer than the longest normal step.
	 *
	 * The batch is lowered to WATCHDOG_SWEEP_BATCH_CEILING before the selector runs. Before each
	 * candidate, the loop checks that the per-candidate query reserve is still left. A candidate costs
	 * up to two queries, so a batch within the limit can still use up the transaction's query budget.
	 * When the reserve is not there, the remaining candidates are parked (see parkRemainingCandidates)
	 * and the sweep stops. Parked candidates and candidates beyond the limit both stay where they are
	 * for a later sweep.
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
	 * @description Parks the sweep's remaining candidates when the per-candidate query-budget check
	 * stops the sweep. Each remaining candidate is parked with the query-budget reason (one fresh
	 * read and one update each) for as long as the query budget lasts. Any candidates after that are
	 * left completely untouched, still stale and still candidates, for a later sweep, exactly like
	 * chains beyond the batch limit.
	 *
	 * @param staleCandidates The sweep's full candidate list.
	 * @param firstParkedIndex The index of the first candidate the query-budget check stopped at.
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
	 * @description Decides what the sweep does with one stale candidate, in a fixed order: the
	 * async-budget check, the check for a run that has already ended, then the decision based on
	 * whether the executor job is alive. (Before this method runs, the sweep loop has already checked
	 * that the per-candidate query reserve is left; see runWatchdogSweep. So the branches below can
	 * pay for their job check and their fresh read.)
	 *
	 * The async-budget check runs first, before any other decision. Every action the sweep can take
	 * other than parking uses a queueable slot: a stall notification, a re-drive's executor enqueue,
	 * or the notification after a run that cannot be recovered is ended Failed. An enqueue with no
	 * slot left raises a LimitException, which cannot be caught and rolls back the whole sweep. The
	 * check reads the live counter for each candidate, not once per sweep, because each enqueue uses
	 * budget during the loop. So a sweep can start with budget and still, correctly, park its last
	 * candidates. The one slot the check finds is used by whichever branch runs, and a candidate
	 * never gets more than one enqueue.
	 *
	 * The check for a run that has already ended comes second. A candidate can reach Completed,
	 * Failed or Aborted between the selector's read and this decision. The sweep must then skip that
	 * row entirely: no mark, no notification, no re-drive. This check is not an extra query here. It
	 * happens at each branch's own fresh read: inside applyRunTransition, the transition table refuses
	 * a stall, a re-drive or a degrade from a finished status, and qualifiesForRedrive checks for a
	 * status that can be recovered when the re-drive branch starts. So every branch checks again as
	 * late as possible, and no branch can act on a run that has ended.
	 *
	 * The decision on whether the executor is alive then depends on the recorded CurrentJobId__c:
	 * - No usable job id (null, or text that is not a valid job id) means the sweep CANNOT CHECK. It
	 *   is never proof that the job is dead. Every chain started on a package version that records
	 *   the job id at enqueue (see stampExecutorJobId) has one. So a row without one was started
	 *   before job ids were recorded, or its start hit the enqueue failure, and there is no job to
	 *   check. The sweep then only marks the row Stalled and notifies, nothing more. It never
	 *   re-drives a run it cannot prove dead.
	 * - A live job means the run is slow but alive. Once the budget checks have passed, the sweep
	 *   leaves the row completely untouched (no second executor, no mark). Running a live chain twice
	 *   would be a worse fault than the stall it would fix. When the budget is used up, even a live
	 *   candidate is parked: checking the job and notifying both use the very resources the checks
	 *   just found missing.
	 * - A dead job, with the budget already checked, leads to an automatic re-drive through
	 *   redriveStalledChain. The whole check-and-re-drive branch runs inside the same per-chain
	 *   try/catch and logging as the mark branch (see redriveWhenProvablyDead), so one broken row
	 *   cannot stop the rest of the sweep.
	 *
	 * A remaining risk that the threshold covers: the recorded job id is the one from the LAST code
	 * that wrote it. That is first the enqueue-time write (stampExecutorJobId, at the first enqueue and
	 * at every watchdog or operator re-enqueue), then each progress write. From the second step on,
	 * that id is one step behind the live executor. So the check can read the previous, finished job
	 * while the next one still runs. The staleness threshold matters here: when it is set longer than
	 * the longest normal step, that one-step gap can never look stale.
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
	 * @description Parks a candidate that a budget check stopped. The row goes through the shared
	 * mark sequence with the given parked reason and, on purpose, NO onError notification.
	 * Notifying uses a queueable slot, and the async check just found none left (and with the query
	 * budget this low, any extra work only makes the shortage worse). For the same budget reason, the
	 * park also leaves out the unhandled-stall signal. That signal is the ERROR-level stall entry
	 * markStalledAndNotify records when a chain stalls with no handler. A handler skipped because of
	 * the budget must never look like a chain that has no handler, so the park's stall entry stays
	 * at WARN even for a chain without a handler. Parking is not a dead end: the row stays Stalled,
	 * so it stays among the selector's candidates. But the park write itself updates
	 * LastModifiedDate. So the row becomes a candidate again only after it is older than the
	 * staleness threshold again, not automatically on the very next sweep. After that, a sweep with
	 * enough budget processes it again. The notification still is not sent twice, because the row
	 * does not newly become Stalled.
	 *
	 * A remaining limit: the parked reason does not last, by design. ErrorMessage__c records only the
	 * LATEST sweep decision. So a later sweep with enough budget overwrites the parked reason with the
	 * stall reason, and a successful re-drive replaces it with the final state. Do not treat the field
	 * as a history: the log entries keep the sequence.
	 *
	 * @param stale The stale candidate a budget check parked.
	 * @param reason The plain-language parked reason naming the exhausted budget.
	 */
	private static void parkWithReason(AsyncChainExecution__c stale, String reason)
	{
		markStalledFromWatchdog(stale, reason, null, true);
	}

	/**
	 * @description For the watchdog sweep, checks whether one candidate's recorded executor job is
	 * alive, and re-drives the candidate when the job is known to be dead. Failures are kept to the
	 * one chain, as in the mark branch (markStalledFromWatchdog). Exceptions that can be caught,
	 * anywhere on this branch, are logged and dropped for that chain only. That covers the job
	 * check's query, redriveStalledChain's run key write and executor enqueue, and the final write
	 * inside markRedriveCandidateFailed for a run that cannot be recovered. So one broken row cannot
	 * stop the rest of the sweep. Governor limits cannot be caught, so the sweep's batch limit and
	 * its async- and query-budget checks guard against them instead.
	 *
	 * Each caught failure leaves a safe state behind, by design. A failed job check or a failed run
	 * key write leaves the candidate untouched and still stale, so a later sweep simply tries again.
	 * A failed executor enqueue AFTER the run key write was saved leaves the chain Running under the
	 * new key with no live executor. The recorded CurrentJobId__c still points at a dead job, so the
	 * next sweep finds that state again and re-drives it. A failed or refused final write, for a run
	 * that cannot be recovered, leaves the record on its old key and queues no notification. The
	 * notification is sent only after that write went through, so no handler is told of a failure
	 * that was never saved.
	 *
	 * @param stale The stale candidate with a recorded job id, returned by the selector.
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
	 * @description Reports whether the AsyncApexJob behind the given id still has a live platform
	 * status. The watchdog's recovery decision depends on this answer. True means the job's Status is
	 * one of the statuses of a job that is waiting to run or running (Queued, Processing, Preparing,
	 * Holding). Completed, Aborted and Failed jobs are dead.
	 *
	 * False means "no proof that THIS job id is alive". It is NOT proof that the chain is dead. The
	 * record's job id comes from the LAST code that wrote it: first the enqueue-time write
	 * (stampExecutorJobId, at the first enqueue and at every watchdog or operator re-enqueue), then
	 * each progress write. So from the second step on, it is one step behind the live executor. It is
	 * null on rows created by a package version that did not record job ids, and on a start that hit
	 * its enqueue failure (see stampExecutorJobId).
	 * So callers that decide recovery must treat a null asyncApexJobId as CANNOT CHECK (only mark and
	 * notify, never re-drive). They must also use a generous staleness threshold with any re-drive
	 * decision, longer than the longest normal step. A well-formed id that matches no AsyncApexJob row
	 * is also treated as dead. The framework records the id from its own executor, so that can happen
	 * only when someone edits the id by hand or the platform deletes old AsyncApexJob rows. In both
	 * cases a re-drive is the correct outcome.
	 *
	 * @param asyncApexJobId The recorded executor job id to check, or null when none was recorded (a row created before job ids were recorded).
	 *
	 * @return True when the job exists and holds a live status; false for a null id, an absent row, or a dead status.
	 */
	@TestVisible
	private static Boolean isExecutorLive(Id asyncApexJobId)
	{
		if(asyncApexJobId == null)
		{
			return false; // no job id, so the job cannot be proven alive
		}
		AsyncApexJob job = (AsyncApexJob)new SEL_AsyncApexJob().findById(asyncApexJobId);
		return job != null && LIVE_JOB_STATUSES.contains(job.Status);
	}

	/**
	 * @description For the watchdog sweep, sends one stale candidate through the shared
	 * markStalledAndNotify sequence, with the WATCHDOG_STALLED run event and no run key check. (The
	 * sweep is the part of the framework that decides recovery. The transition table refuses a run
	 * that ended between the sweep's read and the write.) The given reason and notification handler
	 * are passed on unchanged. A budget check parks with the parked reason and no handler. The mark
	 * path stalls with the sweep reason and the handler read from the candidate's saved step log.
	 * Failures are logged and dropped for that chain only, so an exception that can be caught on one
	 * broken row cannot stop the rest of the sweep. Governor limits cannot be caught, so the sweep's
	 * batch limit and its async- and query-budget checks guard against them instead. Note: this
	 * try/catch protects only the call itself. The arguments at the call sites are worked out BEFORE
	 * it, outside any per-chain protection. So every helper that produces an argument
	 * (resolvePersistedErrorHandler and anything added later) must never throw on its own: it must
	 * check for blank values, catch every exception, and never trust the contents of the candidate row.
	 *
	 * @param stale The stale candidate returned by the selector.
	 * @param reason The stall reason to record on the candidate.
	 * @param notificationHandler The onError handler to notify once per stall transition, or null for none.
	 * @param notificationWithheld True when the caller passed null for notificationHandler on
	 * purpose rather than because none exists. A budget park skips the notification to save the
	 * async budget even when the chain has a registered handler. Only a false value can produce
	 * the unhandled-stall ERROR: a park must never be logged as a chain with no handler.
	 */
	private static void markStalledFromWatchdog(AsyncChainExecution__c stale, String reason, DTO_StepDefinition notificationHandler, Boolean notificationWithheld)
	{
		try
		{
			RunTransitionRequest request = buildRunTransitionRequest(new AsyncChainExecution__c(Id = stale.Id), RunEvent.WATCHDOG_STALLED, reason);
			markStalledAndNotify(request, notificationHandler, notificationWithheld);
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
	 * blank or unparseable step log, or one without an error-handler entry, gives null. The stall
	 * itself must never fail because the notification handler cannot be found.
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
	 * when there is one, the implementing class name otherwise. It lives in one place because this
	 * choice decides what an admin reads in the performance timer, in a failure's ErrorMessage__c,
	 * and in the operator re-drive log. Those three places must never disagree about what a step is
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
	 * ever throwing: a blank or unparseable document gives null. It must never throw because its
	 * result is used as an argument in the sweep, which is worked out outside any per-chain
	 * try/catch, and a broken row must never stop the sweep around it.
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
	 * It accepts null, so it can take parseStepLog's result directly in the sweep's arguments,
	 * which must never throw.
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
	 * @description For the watchdog sweep, re-drives one candidate whose executor is known to be dead.
	 * It goes through applyRunTransition with the WATCHDOG_REDRIVEN run event, fenced by the run key
	 * the sweep read (the write happens only while that key still matches). The write gives the run a
	 * new key, so any old executor that wakes later with the old key is shut out. It also sets the
	 * chain back to Running with its stall category cleared, and records the resume step's start in
	 * the step log. After a write that went through, a new executor, rebuilt from the record, is
	 * queued at the resume point under the new key. A refused write (the run ended, or changed key,
	 * between the read at the start and the write) queues nothing.
	 * Only two kinds of code write RunKey__c. The first is the insert that creates the key: the first
	 * key set by ChainBuilder.execute(), and the restart copy made by restartChainFromStart. The second
	 * is the three run events inside applyRunTransition that give the run a new key: WATCHDOG_REDRIVEN
	 * here, RECOVERY_DEGRADED in markRedriveCandidateFailed, and OPERATOR_RETRIED in
	 * retryChainFromFailedStep. No executor write ever includes the field (see buildSparseUpdate).
	 * The data-masking trigger never rewrites it either: UTIL_FrameworkMasker leaves the field out
	 * when it expands a wildcard. Otherwise a random key whose digit groups look like a card number
	 * would be rewritten in the database copy only, and every executor of the run would be shut out.
	 *
	 * The caller must already have done two things. First, the check that the executor is dead:
	 * Status__c alone never proves that, so a selector candidate must also pass the AsyncApexJob
	 * check. Second, the async-budget check: queueing again uses a queueable slot, so the budget must
	 * be checked before the call. The method still reads the record again, to be safe, and goes on
	 * only when the run still qualifies: Running or Stalled, with the run key unchanged since the
	 * sweep's read, and no activity on the record newer than the sweep's read (see
	 * qualifiesForRedrive). So a chain that completed, failed, was aborted, was taken over by other
	 * code, or clearly moved on in the meantime is never re-driven. applyRunTransition repeats the
	 * key and status checks when it writes.
	 *
	 * The resume point comes from the saved step markers, not CompletedSteps__c. See
	 * deriveResumeIndex for exactly which steps are tried again, and for the fallback used on old
	 * step logs. Steps and handlers are rebuilt from the saved StepLog__c using the isErrorHandler /
	 * isCompletionHandler flags. The executor itself restores the ChainContext from ContextData__c
	 * when it starts. A candidate whose step log cannot be rebuilt into a chain that can run is
	 * marked Failed with a reason that says what to do instead. See markRedriveCandidateFailed for
	 * why Failed, not Stalled, is the safe outcome.
	 *
	 * Whether the resume step may be RUN AGAIN is decided from its state (resolveStepState, read from
	 * the started marker). A resume step that is STARTED (an executor was queued for it) and left no
	 * result may already have done its work. So it is run again only when it declares itself
	 * idempotent. Otherwise the chain ends Failed with a reason the subscriber can see
	 * (refuseRedriveOfStartedStep). A resume step with no start never ran: no executor for it was
	 * ever saved (the Finalizer removes the start when its enqueue fails), so it is re-driven. Rows
	 * saved by a package version without the marker have no start and are also re-driven, so a chain
	 * that was running during an upgrade is never refused. The run key write below records the
	 * resume step's start before the recovery executor is queued, so the next sweep can make the same
	 * decision about the re-driven run.
	 *
	 * A recovered chain runs with the framework's default maxSteps and AsyncOptions. The values set
	 * on the builder are not saved, and the defaults are the safe limits for a chain that has already
	 * shown it can stall. The context limit is the one exception. It is the larger of the framework
	 * default and the size of the saved context. A chain correctly built with a larger limit must not
	 * overflow, every time, as soon as recovery runs it again under the default.
	 *
	 * A successful re-enqueue at once records the new executor's job id on the record
	 * (stampExecutorJobId), before the WARN log, so the job check follows the re-driven executor from
	 * the moment it is queued. So there is no gap between the re-enqueue and the first progress write
	 * in which the record carries only the dead executor's id. The job check proves whether the
	 * re-driven executor itself is alive or dead. A recovery that is alive but slow is left untouched.
	 * A recovery that dies before its first progress write is found again through its own job id, not
	 * through another job that happens to be dead.
	 *
	 * If the re-enqueue itself fails after the run key write was saved, the job id is never recorded,
	 * and the chain is left Running under the new key with no live executor. The run key write does
	 * not change the dead executor's job id, which still shows a dead job, so the next sweep finds the
	 * row again. Because the run key write already recorded the resume step's start, that sweep cannot
	 * prove the step never ran. So it ends the chain Failed with the started-step reason (unless the
	 * step declares itself idempotent, in which case it is re-driven). That careful outcome is chosen
	 * over sending the work again, for a failure that the async-budget check makes almost impossible.
	 * The sweep's catch (redriveWhenProvablyDead) logs the enqueue failure for that chain and moves on,
	 * so it costs the sweep nothing beyond this one candidate.
	 *
	 * A remaining risk, small and limited to once: the executor's run key check reads the record
	 * before its write, not in the same step (there is no FOR UPDATE lock). So a progress write from
	 * an old executor that is still running can be saved just after the new run key is saved. It then
	 * counts CompletedSteps__c one too high, once. That old executor's next entry check shuts it out
	 * for good. The resume point is worked out from the step markers, not the count, so the extra
	 * count cannot move the resume point, except on old rows with no markers.
	 *
	 * @param execution The stale candidate as the sweep read it; its run key is the one the write checks.
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
			markRedriveCandidateFailed(fresh, findPersistedErrorHandler(persistedDefinitions), REDRIVE_UNRECOVERABLE_REASON, false);
			return;
		}

		DTO_StepDefinition resumeEntry = stepEntries[nextIndex];
		if(resolveStepState(resumeEntry) == StepState.STARTED && resumeEntry.isIdempotent != true)
		{
			refuseRedriveOfStartedStep(fresh, persistedDefinitions, resumeEntry);
			return;
		}

		// The resume step's start is recorded in the run key write, before its executor is queued, so a later
		// sweep can never mistake a re-driven step that ran and left no result for one that never ran.
		resumeEntry.started = true;
		fresh.StepLog__c = serializeStepLog(persistedDefinitions);
		RunTransitionRequest request = buildFencedRunTransitionRequest(fresh, RunEvent.WATCHDOG_REDRIVEN, execution.RunKey__c, null);
		request.callerFields.add(AsyncChainExecution__c.StepLog__c);
		if(!applyRunTransition(request))
		{
			return;
		}

		enqueueRecoveryExecutor(request.record, nextIndex, persistedDefinitions, stepEntries.size());

		LOG_Builder.build().warn('Chain re-driven by watchdog after a stall: resuming at step ' + resolveStepDisplayName(stepEntries[nextIndex]))
				.at(CLASS_NAME + '.redriveStalledChain')
				.forRecord(fresh.Id)
				.emit();
	}

	/**
	 * @description Works out the step index where a re-driven executor resumes, from the states of the
	 * saved step entries (resolveStepState). The first step entry whose state has no result (hasStepResult
	 * is false) was never attempted, and recovery resumes there. CompletedSteps__c cannot be the main
	 * source, because it counts successes only. After a continueOnError failure the count is behind the
	 * true position, and using it as the index would run a step again that already ran.
	 *
	 * Exactly which steps are tried again: a step that failed and let the chain go on is NOT tried
	 * again by a re-drive. It was attempted, and its state says so (FAILED_CONTINUED). The first entry
	 * with no result is the resume point. Whether that entry may really be run again is the caller's
	 * decision, taken from its state. A step whose work ran but whose progress write was never saved
	 * is STARTED. redriveStalledChain runs such a step again only when it declares itself idempotent,
	 * because its work, a callout included, may already have happened.
	 *
	 * A log with no result on any step entry is the old form (saved by a package version without
	 * runtime markers, or a chain that never ran a step). With nothing to read, the method falls back
	 * to CompletedSteps__c. When every entry of a log has a result, the method returns the entry count
	 * (every step was attempted, so nothing can resume). The caller's consistency check then ends the
	 * run as one that cannot be recovered, the same way the CompletedSteps__c count treats such a chain.
	 *
	 * @param stepEntries The filtered chain-step entries from the saved step log.
	 * @param completedSteps The saved success count, used only by the fallback for old step logs.
	 *
	 * @return The zero-based resume index; equal to the entry count when nothing is resumable.
	 */
	private static Integer deriveResumeIndex(List<DTO_StepDefinition> stepEntries, Decimal completedSteps)
	{
		Boolean logCarriesMarkers = false;
		Integer firstUnattemptedIndex = -1;
		for(Integer index = 0; index < stepEntries.size(); index++)
		{
			if(hasStepResult(resolveStepState(stepEntries[index])))
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
	 * @description Checks again, against a fresh read, that a re-drive candidate still qualifies at
	 * the moment of the re-drive. The record must still exist, still have a status that can be
	 * recovered (Running or Stalled), still carry the run key the sweep saw, and show no activity
	 * newer than the sweep's read. A changed key means other code took over the chain. A final
	 * status means it finished in the meantime. A LastModifiedDate newer than the sweep's read means
	 * something wrote the record after the sweep saw it. An executor that is alive and still working
	 * explains that; a dead one cannot. So none of those may be re-driven. The refusal on the
	 * timestamp is logged (the others are not) and costs nothing: both timestamps are already
	 * loaded, and the skipped row simply waits for a later sweep to look at it again by its new age.
	 * Null keys count as equal for rows from a package version without run keys (null == null
	 * passes), so such a chain qualifies and the re-drive gives it its first real key.
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
	 * @description Reports whether the fresh read shows activity newer than the sweep's read of the
	 * candidate: a LastModifiedDate strictly after the one the sweep read. It accepts a sweep row
	 * without the field (one built by hand or mocked), and then returns false, so the run key and
	 * status checks alone decide.
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
	 * @description Reports whether a status value is a finished one (Completed, Failed or Aborted),
	 * mirroring ChainStatus.isTerminal() for internal callers that hold only the raw picklist
	 * value. The check of the rules a row must meet in its status (findRunInvariantBreach) reads it
	 * for the rule that a finished run carries an end time and no active deduplication key.
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
	 * @description Writes a log entry, on a best-effort basis, after a chain's final status write.
	 * The event channel and the logging engine make the log safe, not this method.
	 * LogEntryEvent__e publishes at once and uses no DML statement or row of the calling
	 * transaction. LOG_Engine checks the limits first (canPublishImmediately), sends the entry to an
	 * async job when they are used up, and wraps its sending so the logger never breaks the business
	 * transaction. Call this only AFTER the final-status DML. ERROR-level entries always pass
	 * LOG_Engine's threshold. The INFO completion entry follows the configured LogLevelThreshold__c
	 * (to see completions, set the threshold at or below INFO). If another channel or risk ever really
	 * needs a safety check at the call, add it here, never at each call.
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
	 * @description Ends a re-drive candidate that the sweep cannot safely re-drive as Failed, with a reason that says what to do.
	 * That is a candidate whose saved step log cannot be rebuilt
	 * (blank, unparseable, or not matching the recorded progress), or one whose resume step started
	 * and left no result without declaring itself idempotent (see refuseRedriveOfStartedStep).
	 * Failed, not Stalled, is the safe outcome. Neither condition repairs itself, so every later
	 * sweep would try the same impossible re-drive again and park the row again forever. That would
	 * happen silently, because parking a row that is already Stalled sends no notification. Failing
	 * clearly once puts the chain in front of an admin in the Chain Monitor instead.
	 *
	 * The write goes through applyRunTransition with the RECOVERY_DEGRADED run event, fenced by the
	 * key the sweep read. The run ends Failed with the Stalled category, the reason, its end time and
	 * duration, and its deduplication key released. The write includes StepLog__c as a caller field
	 * only when the caller changed the log. A caller that marked the resume entry saves that mark in
	 * the same final write. For a run that cannot be recovered, nothing changed in the log that was
	 * read, so the field is left out rather than writing it back unchanged, which could be as large
	 * as the field allows.
	 *
	 * This final write cannot be undone by an old executor. It gives the run a new key together with
	 * the final fields. So an old executor that wakes later with the earlier key is shut out of the
	 * record, and cannot overwrite the Failed status with its own late state. RECOVERY_DEGRADED is
	 * one of the three run events inside applyRunTransition that give the run a new key, beside
	 * WATCHDOG_REDRIVEN and OPERATOR_RETRIED (see buildSparseUpdate).
	 *
	 * When the candidate's saved step log has an onError handler, the run is failed first and the
	 * handler is notified after. After a write that went through, the notification goes through the
	 * shared recovery-notification enqueue with the reason, under the new key the write saved, and the
	 * ERROR terminal log follows it. A refused write (the run ended, or changed key, between the read
	 * at the start and the write) notifies nothing and logs nothing beyond the refusal. So no handler
	 * is told of a failure that was never saved. The enqueue uses the one queueable slot the sweep's
	 * budget check found, the slot a successful re-drive would have given its executor. The handler may
	 * be notified more than once, and the enqueue itself never throws (the shared code falls back to a
	 * log).
	 *
	 * @param execution The freshly re-read candidate that cannot be re-driven.
	 * @param notificationHandler The persisted onError handler to notify, or null when none resolves.
	 * @param reason The actionable reason recorded on the chain, handed to the handler and logged.
	 * @param stepLogChanged Whether the caller changed StepLog__c on the record, so the terminal write must carry it.
	 */
	private static void markRedriveCandidateFailed(AsyncChainExecution__c execution, DTO_StepDefinition notificationHandler, String reason, Boolean stepLogChanged)
	{
		RunTransitionRequest request = buildFencedRunTransitionRequest(execution, RunEvent.RECOVERY_DEGRADED, execution.RunKey__c, reason);
		if(stepLogChanged)
		{
			request.callerFields.add(AsyncChainExecution__c.StepLog__c);
		}
		if(!applyRunTransition(request))
		{
			return;
		}

		enqueueRecoveryErrorHandler(request.record, reason, notificationHandler, SEL_AsyncChainExecution.STATUS_FAILED);

		emitTerminalLog(LoggingLevel.ERROR, reason, CLASS_NAME + '.redriveStalledChain', execution.Id);
	}

	/**
	 * @description Ends a re-drive candidate as Failed because its resume step started and left no result without
	 * declaring itself idempotent: an executor was enqueued for the step and the record never heard from it again, so its
	 * work, a callout included, may already have happened, and running it again could repeat that work. The reason is the
	 * subscriber-visible label, with the step named; the resume entry is marked as the failed step with that reason as its
	 * message, so the Chain Monitor shows which step stopped the chain and its retry check answers that the step never
	 * declared itself safe to run again. The final fields, the new run key, the notification and the log are the same as
	 * for any run that cannot be recovered (markRedriveCandidateFailed).
	 *
	 * @param execution The freshly re-read candidate whose resume step started.
	 * @param persistedDefinitions The candidate's parsed step log, which the resume entry belongs to.
	 * @param resumeEntry The started, undeclared step the sweep refuses to re-run.
	 */
	private static void refuseRedriveOfStartedStep(AsyncChainExecution__c execution, List<DTO_StepDefinition> persistedDefinitions, DTO_StepDefinition resumeEntry)
	{
		String reason = String.format(System.Label.AsyncChain_RecoveryStoppedAtStartedStep, new List<String> {resolveStepDisplayName(resumeEntry)});
		resumeEntry.success = false;
		resumeEntry.recoveryRefused = true;
		resumeEntry.message = UTIL_String.abbreviate(reason, STEP_MESSAGE_MAX_LENGTH);
		execution.StepLog__c = serializeStepLog(persistedDefinitions);
		markRedriveCandidateFailed(execution, findPersistedErrorHandler(persistedDefinitions), reason, true);
	}

	/**
	 * @description Marks a chain execution Aborted on an operator's request, through applyRunTransition with the
	 * OPERATOR_ABORTED run event and no run key check. applyRunTransition reads the run fresh (sharing is bypassed for
	 * this method only, so an operator can abort any chain the monitor shows). It refuses a run that is not Running or
	 * Stalled (a missing row, or one already Completed, Failed or Aborted). It writes all the final fields that the
	 * executor's own abort path writes: the OperatorAbort category, the shortened reason, the completion timestamp, the
	 * duration, and the release of the deduplication key, in the same update. A refusal is reported to the caller as
	 * false instead of a throw, and the Chain Monitor turns a false into its already-finished message. Who may call this
	 * at all is decided by the feature-flag check in CTRL_ChainMonitor, and the Apex code is where the rule is enforced.
	 * The abort takes effect at the next step boundary: the running step finishes, and then every final write refuses to
	 * save the finished work over the saved Aborted row. Emits exactly one WARN terminal log entry, strictly after the
	 * DML, from its own method, so operator aborts can be told apart from kill-switch aborts. The entry carries the reason
	 * exactly as given, with no prefix of its own. The reason is already a full sentence that names who aborted, and the
	 * Chain Monitor's live activity panel shows this text to an admin, where a prefix from the framework would say the
	 * same thing twice. Does not touch RunKey__c: aborting changes the status but does not give the run a new run key.
	 * Among the run events, only the three that give the run a new key (WATCHDOG_REDRIVEN, RECOVERY_DEGRADED,
	 * OPERATOR_RETRIED) write RunKey__c.
	 *
	 * @param executionId The AsyncChainExecution__c record to abort.
	 * @param reason The operator-supplied reason, recorded on ErrorMessage__c (abbreviated).
	 *
	 * @return True when the terminal write committed; false when the row is missing or not abortable.
	 */
	public static Boolean abortExecution(Id executionId, String reason)
	{
		if(!applyRunTransition(buildRunTransitionRequest(new AsyncChainExecution__c(Id = executionId), RunEvent.OPERATOR_ABORTED, reason)))
		{
			return false;
		}

		emitTerminalLog(LoggingLevel.WARN, reason, CLASS_NAME + '.abortExecution', executionId);

		return true;
	}

	/**
	 * @description Outcome of a Chain Monitor operator action. refusalCode carries the availability
	 * code the action refused on when it checked again on a fresh read, or null when the action ran.
	 * resultId carries the record the caller should show next: the retried execution itself, or
	 * null on refusal. CTRL_ChainMonitor turns every non-null refusalCode into an exception with a
	 * label. The Apex code enforces the rule, and the state of a button in the monitor is only a hint.
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
	 * @description Used by retryChainFromFailedStep and restartChainFromStart when the action does not go ahead: its own
	 * fresh check refused, or the save was refused. It only builds the outcome and writes nothing. resultId stays null,
	 * and CTRL_ChainMonitor turns the code into an error with a label.
	 *
	 * @param refusalCode The availability code the action refused on when it checked again on a fresh read.
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
	 * @description Used once the action has run. resultId is the retried run for a retry, or the new copy for a restart.
	 * refusalCode stays null, which is how the caller knows the action ran.
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
	 * @description Works out whether the chain's STATE permits a retry from its failed step. This is
	 * the chain-state half of the check, on the row the caller already holds. CTRL_ChainMonitor adds
	 * the feature-flag and custom-permission codes, the same way the abort flow does.
	 * retryChainFromFailedStep checks again on its own fresh read before acting, so this answer is
	 * a hint for the screen, and the Apex code still enforces the rule.
	 *
	 * Refusal order, most specific last: not Failed; processing suspended; context or step log
	 * missing, unparseable, or with no failed step that stopped the chain (no state that can be
	 * trusted to resume from); failed step declared its failure permanent (a second run cannot
	 * succeed, and a permanent failure wins over the idempotency declaration); failed step never
	 * declared isIdempotent (running a step again that did not declare this could double its side
	 * effects; rows from a package version without the declaration always end up here, and a
	 * null value never counts as allowed).
	 *
	 * @param execution The chain execution row to resolve, as the Chain Monitor's query reads it.
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
	 * @description Finds the failed entry that stopped the chain, in the filtered step entries: the LAST
	 * entry that failed and stopped the chain (see isTerminalFailure). An empty list, which is what
	 * every caller gets from a step log that cannot be parsed, has no such entry and returns null. So
	 * the order of checks in resolveRetryAvailability stays safe when parsing failed earlier.
	 *
	 * @param stepEntries The filtered chain-step entries; empty when the step log did not parse.
	 *
	 * @return The zero-based index of the terminal failed entry, or null when none exists.
	 */
	private static Integer findTerminalFailedIndex(List<DTO_StepDefinition> stepEntries)
	{
		for(Integer index = stepEntries.size() - 1; index >= 0; index--)
		{
			if(isTerminalFailure(stepEntries[index]))
			{
				return index;
			}
		}
		return null;
	}

	/**
	 * @description Reports whether a step entry failed and the chain stopped there: its state (resolveStepState) is
	 * FAILED_STOPPED or RECOVERY_REFUSED. A step that failed with continueOnError and was not refused (FAILED_CONTINUED) let
	 * the chain go on, so it is never the step the chain stopped at.
	 *
	 * @param entry The step entry to check.
	 *
	 * @return True when the entry is a failure the chain stopped at.
	 */
	private static Boolean isTerminalFailure(DTO_StepDefinition entry)
	{
		StepState state = resolveStepState(entry);
		return state == StepState.FAILED_STOPPED || state == StepState.RECOVERY_REFUSED;
	}

	/**
	 * @description True when the row's saved context parses as a JSON OBJECT, the one form from which
	 * the executor can rebuild a chain context. The failure write saves the whole context or nothing.
	 * So anything else here means the row was saved by an older package version or edited by hand.
	 * Either way there is no state that can be trusted to resume from. That the text parses at all is
	 * on purpose NOT enough. A valid JSON list would pass a parse check, give the run a new key, set
	 * the row to Running, and then fail as the executor starts. That would leave a Running row with no
	 * live executor. Retry and restart answer this same question through one shared method
	 * (parseContextObject).
	 *
	 * @param execution The chain execution row whose ContextData__c to check.
	 *
	 * @return True when the context parses as a JSON object.
	 */
	private static Boolean contextParsesCleanly(AsyncChainExecution__c execution)
	{
		return parseContextObject(execution.ContextData__c) != null;
	}

	/**
	 * @description Re-drives a Failed chain from its failed step on an operator's request. This is the
	 * one path that may take a Failed row back to Running, and it is separate from the watchdog's code
	 * on purpose: qualifiesForRedrive accepts only Running or Stalled, so nothing automatic can ever
	 * bring back a chain that has ended. It reads the row fresh through the monitoring selector and
	 * checks availability again before acting, the same double check the abort makes (the caller's
	 * earlier answer may be out of date because other code changed the row in the meantime). It
	 * refuses with the code instead of throwing, and CTRL_ChainMonitor turns every refusal into its
	 * exception with a label.
	 *
	 * The action is ONE sparse update, through applyRunTransition with the OPERATOR_RETRIED run event
	 * and no run key check. The failed entry's runtime markers are reset (success, message, attempt
	 * and duration), which gives the second run a fresh attempt budget, and its start is recorded
	 * again, before the enqueue. So a second run that stops without a result is refused by the
	 * watchdog like any other started step that never declared itself idempotent. applyRunTransition
	 * also gives the run a new key, which shuts out any old executor holding the old key
	 * (OPERATOR_RETRIED is one of the three run events that give the run a new key). It sets
	 * Status__c back to Running, and clears the final fields (CompletedAt__c, DurationMs__c,
	 * FailureCategory__c and ErrorMessage__c) in the SAME update. A Running row with CompletedAt__c
	 * set could be purged while the watchdog cannot see it, and old diagnostics would outlive the
	 * state they described. The declared deduplication key is taken back into
	 * ActiveDeduplicationKey__c in the same update. A DUPLICATE_VALUE clash counted as a clash on the
	 * deduplication key field (see isActiveDeduplicationKeyCollision) means another live run holds
	 * the key, and the action refuses with DuplicateRun. Any other DmlException is thrown again. When
	 * applyRunTransition refuses the write, because the run left Failed between the availability
	 * check and the write (for example, a second operator's retry), the action refuses with
	 * ChainNotRetryable, the same code the availability check gives for a run that is not Failed.
	 *
	 * The second run uses the framework's default limits, exactly as a watchdog re-drive does: values
	 * set on the builder are not saved, and the context limit is the larger of the default and the
	 * size of the saved context. Only the failed step runs again. Entries whose markers were kept
	 * keep them, so earlier work is never repeated. The new executor's job id is recorded through
	 * stampExecutorJobId before the WARN log, so the job check follows the re-driven executor from
	 * the moment it exists.
	 *
	 * Writes LastManualRetryAt__c, and marks the retried entry with the wait since the failure, in the
	 * same sparse update. No other path writes either value (the watchdog's re-drive, an abort and a
	 * restart copy do not, on purpose).
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
		Datetime retriedAt = Datetime.now();
		failedEntry.success = null;
		failedEntry.recoveryRefused = null; // hygiene: a refused entry never gets here, since the gate answers StepNotIdempotent first
		failedEntry.message = null;
		failedEntry.attempt = null;
		failedEntry.durationMs = null;
		failedEntry.manualRetryAfterMs = resolveManualRetryWait(fresh.CompletedAt__c, retriedAt);
		failedEntry.started = true; // recorded before the enqueue below, in the same update: the operator's run may also die without a result

		fresh.LastManualRetryAt__c = retriedAt;
		fresh.StepLog__c = serializeStepLogForManualRetry(persistedDefinitions, failedEntry, stepEntries.size() - failedIndex);
		RunTransitionRequest request = buildRunTransitionRequest(fresh, RunEvent.OPERATOR_RETRIED, null);
		request.callerFields.addAll(new List<SObjectField> {AsyncChainExecution__c.LastManualRetryAt__c, AsyncChainExecution__c.StepLog__c});

		try
		{
			if(!applyRunTransition(request))
			{
				return buildOperatorRefusal(REDRIVE_CHAIN_NOT_RETRYABLE);
			}
		}
		catch(DmlException updateError)
		{
			if(isActiveDeduplicationKeyCollision(updateError))
			{
				return buildOperatorRefusal(REDRIVE_DUPLICATE_RUN);
			}
			throw updateError;
		}

		enqueueRecoveryExecutor(request.record, failedIndex, persistedDefinitions, stepEntries.size());

		LOG_Builder.build().warn('Chain retried by operator from failed step: ' + resolveStepDisplayName(failedEntry))
				.at(CLASS_NAME + '.retryChainFromFailedStep')
				.forRecord(fresh.Id)
				.emit();

		return buildOperatorSuccess(fresh.Id);
	}

	/**
	 * @description Works out whether the chain's STATE permits a restart from the start. This is the
	 * chain-state half of the check, on the row the caller already holds. It reads ONLY the fields the
	 * selector reads by default. The caller's monitoring row does not carry the InitialContextData__c
	 * copy on purpose, so restartChainFromStart checks for that copy itself, on its own read. This
	 * answer is a hint for the screen, and the Apex code still enforces the rule. CTRL_ChainMonitor
	 * adds the feature-flag and custom-permission codes, the same way the abort flow does.
	 *
	 * Refusal order: not Failed or Aborted (only a run that ended badly may run again); processing
	 * suspended; allowRestart never declared (running a whole chain again that did not declare this
	 * could double its side effects; rows from a package version without the declaration always end
	 * up here, and a null value never counts as allowed).
	 *
	 * @param execution The chain execution row to resolve, as the Chain Monitor's query reads it.
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
	 * @description Restarts a Failed or Aborted chain from its first step on an operator's request. It
	 * does this by COPYING the run to a new record, never by changing the source. The ended row keeps
	 * its status, diagnostics and purge eligibility, as the audit record of the run that ended badly.
	 * It reads the row fresh through the restart's own query (the only query that ever reads the
	 * saved initial context), checks availability again, and checks here that the saved initial
	 * context and the step log are present, because the hint from the monitoring row cannot see the
	 * saved initial context, by design.
	 *
	 * The copy is built from what the chain DECLARED, never from runtime state:
	 * - a step log with definitions only. Only the configuration properties on an allow list are
	 *   copied, so any runtime marker a future release adds is unset by design. The one marker set
	 *   afterwards is the first step's start, which the restart records before its enqueue, exactly
	 *   as a launch does;
	 * - the InitialContextData__c copy, saved when the chain was built, as its context. Its
	 *   logging-context entry is REPLACED, so the copy's steps use the copy's own new correlation
	 *   id, never the source's;
	 * - a new RunKey__c created at insert (one of the places that set the field at insert);
	 * - counters at zero;
	 * - the declaration fields, so the copy can itself be restarted;
	 * - SourceExecution__c, so the line of restarts can still be queried.
	 * A declared deduplication key is taken back at insert. A DUPLICATE_VALUE clash counted as a
	 * clash on the deduplication key field refuses with DuplicateRun. Any other DmlException is
	 * thrown again.
	 *
	 * The order is required, not something to optimise: insert (the executor constructor needs the
	 * record id), then the enqueue at index 0 with the framework's default limits, then
	 * stampExecutorJobId (the job id exists only after the enqueue; recording it is the sparse
	 * update of a single field). The two linked log entries, WARN on the source and INFO on the
	 * copy, are written strictly after all DML.
	 *
	 * @param executionId The Failed or Aborted AsyncChainExecution__c record to restart from.
	 *
	 * @return The action outcome: refusalCode null and resultId = the COPY's id on success.
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
		// The one runtime marker a restart copy starts with: the restart commits to running the first step, exactly as a launch does.
		cloneStepEntries[RESTART_RESUME_INDEX].started = true;

		String cloneCorrelationId = UTIL_Random.randomUUID();
		AsyncChainExecution__c clone = new AsyncChainExecution__c(
				ChainName__c = source.ChainName__c,
				Status__c = SEL_AsyncChainExecution.STATUS_RUNNING,
				StartedAt__c = Datetime.now(),
				CompletedSteps__c = 0,
				TotalSteps__c = source.TotalSteps__c,
				CorrelationId__c = cloneCorrelationId,
				RootCorrelationId__c = source.RootCorrelationId__c ?? source.CorrelationId__c,
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
	 * result toast. The counts sort each candidate by its status after the sweep. redriven counts the
	 * rows set back to Running by a re-drive, because their executor was proven dead. markedFailed
	 * counts the runs that could not be recovered and were ended Failed. remainingStalled holds
	 * everything the sweep could not or would not move: candidates stopped by a budget check, rows
	 * only marked because their job could not be checked, and rows skipped because their executor
	 * is alive. The log entry for each candidate gives that row's own reason.
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
		 * @description How many candidates were proven dead and re-driven, so they are Running again.
		 */
		public Integer redriven = 0;

		/**
		 * @description How many candidates could not be recovered and were ended Failed.
		 */
		public Integer markedFailed = 0;

		/**
		 * @description How many candidates still wait for recovery: stopped by a budget check, only
		 * marked because their job could not be checked, skipped because a live executor still runs,
		 * left untouched because the calling user cannot read the row, or missing from the count's
		 * read entirely. (The branches that act read the row again with sharing respected, and never
		 * write a row they cannot see. That skip is silent, so this count is its only trace.)
		 */
		public Integer remainingStalled = 0;
	}

	/**
	 * @description Runs the watchdog sweep's decision for each candidate over every chain that is
	 * Stalled now, when an operator asks for it from the Chain Monitor. Every check the scheduled
	 * sweep makes is made here too: the same proof that the executor is dead, the same budget parks,
	 * the same handling of a run that cannot be recovered. That is because every candidate goes
	 * through the same method (sweepCandidate), never a second place that decides. Limits that apply
	 * only to the operator wrap that shared path:
	 * - the candidate limit (MAX_OPERATOR_SWEEP_CANDIDATES);
	 * - a check at the start that returns true zero counts when the transaction cannot pay even for
	 *   the sweep's own two reads;
	 * - the per-candidate query and DML reserves. They leave the remaining candidates completely
	 *   untouched, still Stalled and still candidates for the next call or the next scheduled sweep,
	 *   rather than spending park writes from a budget already found to be short.
	 * When a reserve stops the sweep early, the summary log entry says so, and after how many
	 * candidates. The counts alone cannot tell a budget stop from a sweep that found only live
	 * chains or chains whose job could not be checked.
	 *
	 * Public for the package's own classes only, on purpose: CTRL_ChainMonitor enforces the
	 * feature-flag, custom-permission and suspension checks. That is the same as for abort, plus the
	 * suspension check that abort on purpose does not have (stopping work during a suspension makes
	 * sense; re-driving runs into one does not).
	 *
	 * @return The counts for the operator's result toast.
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
	 * @description Sorts what the sweep did with each candidate, from a single read of their
	 * current statuses after the sweep. Running means a re-drive went through. Failed means the run
	 * could not be recovered and was ended Failed. Everything else, including rows the read no
	 * longer returns, still waits for recovery. A status read after the sweep cannot tell a budget
	 * park from a plain mark (both leave the row Stalled), so both count as remaining, and the log
	 * entry for each candidate gives the reason. The read selects Status__c only and respects
	 * sharing (findByIdsForSweepTally explains both choices). The sorting reads nothing else, and a
	 * row this read cannot see is always a row no acting branch touched. Either way, the
	 * subtraction counts it in remainingStalled.
	 *
	 * @param stalledCandidates The candidates the sweep inspected.
	 *
	 * @return The counts; candidates always equals the sum of the other three.
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
	 * @description Whether async chain processing is currently enabled: the AsyncChain feature
	 * flag, worked out through its strategies, including the runtime-switch hierarchy setting that
	 * the Chain Monitor's suspend and resume actions write. The package's own callers (the operator
	 * availability checks, the monitor's operations state) ask this method instead of using the
	 * private flag constant. The executor's own check when it starts stays where it is, at the
	 * point that aborts a running chain.
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
	 * profile-level rows override the org default, as hierarchy settings do. The setting write is
	 * the ONLY DML this method does: DML on a hierarchy setting is kept apart from DML on other
	 * objects in one transaction, as the other runtime-switch code does. The WARN entry is published
	 * as a platform event and costs the transaction no DML.
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
	 * stopped: restart or retry the ones that should run. The setting DML is kept apart, and the
	 * WARN entry costs no DML, exactly as in suspendChainProcessing.
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
	 * instance with a null Id when the setting was never initialised, so the write sets
	 * SetupOwnerId to the organisation id (the org hierarchy node, never the running user's own
	 * node), and upsert covers both create and update in one call.
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
	 * @description Parses a saved context document into its map form, and refuses a damaged one: it
	 * returns null when the document is blank, is not JSON, or is not a JSON object. A chain context
	 * cannot be rebuilt from any of those. This is the ONE strict parse check for both operator
	 * actions that run a chain again. The restart copy is built from the map it returns, and the
	 * retry check (contextParsesCleanly) accepts a row only when this returns non-null. So the two
	 * checks can never come to accept different things.
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
	 * @description Builds the restart copy's step log entries, with definitions only: for each saved
	 * entry, a NEW definition that copies ONLY the configuration properties (className, stepName,
	 * continueOnError, isIdempotent and the handler flags). It copies from an ALLOW list on purpose,
	 * and never removes values from a block list. So every runtime marker, including any marker a
	 * future release adds, is unset by design, and state from runs that already happened can never
	 * be carried into a new restart copy.
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
	 * @description Rebuilds the initial context, saved when the chain was built, as the restart copy's
	 * starting context. Every saved value is kept unchanged except the reserved logging-context entry,
	 * which is moved to the copy's own correlation id. Two live runs that share a correlation id would
	 * mix up the log trace and the monitor's links, so the copy's steps must use the copy's own id,
	 * never the source's. The copy's logging document is the launch's saved document, moved to the
	 * copy's correlation id, so the action's root and the launch's context values are kept through
	 * the restart. The logging engine's own helper makes that change, so its form always matches what
	 * the executor reads when it rebuilds the logging context.
	 *
	 * Builds its own copy rather than editing the caller's map: a method named for rebuilding a
	 * value should not quietly rewrite its argument.
	 *
	 * @param snapshotMap The parsed initial context, saved when the chain was built.
	 * @param cloneCorrelationId The restart copy's new correlation id.
	 *
	 * @return The serialized starting context for the restart copy.
	 */
	private static String rebuildInitialContextForClone(Map<String, Object> snapshotMap, String cloneCorrelationId)
	{
		Map<String, Object> cloneContext = new Map<String, Object>(snapshotMap);
		cloneContext.put(LOG_CONTEXT_KEY, LOG_Engine.replaceCorrelationId((String)snapshotMap.get(LOG_CONTEXT_KEY), cloneCorrelationId));
		return JSON.serialize(cloneContext);
	}

	/**
	 * @description The answer of decideRunTransition for one run event against one fresh status: the status the run moves to
	 * when the table allows the run event, or the reason it does not.
	 */
	private inherited sharing class RunTransitionDecision
	{
		/**
		 * @description The status the run reads after the run event; null when the run event is refused.
		 */
		private String targetStatus;

		/**
		 * @description Why the run event is refused, for the ERROR log; null when the run event is allowed.
		 */
		private String refusalReason;

		/**
		 * @description Whether the table allows the run event.
		 *
		 * @return True when the run may move.
		 */
		private Boolean isAllowed()
		{
			return refusalReason == null;
		}
	}

	/**
	 * @description What a caller hands applyRunTransition: the run, the run event, the fence (the run key check), the
	 * caller's own fields to write with it, and the message. After a true return the function leaves the freshly read
	 * row, with the fields it set, on record, and
	 * the status the row read before the write on statusBeforeTransition, so the caller's side effects (handler
	 * enqueue, terminal log, notification guard) read what was written.
	 */
	private inherited sharing class RunTransitionRequest
	{
		/**
		 * @description The run record to move.
		 */
		private Id executionId;

		/**
		 * @description The event that moves the run.
		 */
		private RunEvent runEvent;

		/**
		 * @description Whether fenceRunKey must equal the run's fresh RunKey__c for the write to happen: true for an
		 * executor, a handler and the sweep's re-drive and degrade, whose captured key proves the run is still the one
		 * they read; false for the watchdog's mark and the operator actions, which act on the fresh status alone.
		 */
		private Boolean enforceRunKeyFence = false;

		/**
		 * @description The run key the caller captured at enqueue time; compared against the fresh read when the fence is
		 * enforced. Null equals null, for rows saved by a package version without run keys.
		 */
		private String fenceRunKey;

		/**
		 * @description The caller's in-memory row, read for the values of callerFields only. Replaced by the fresh row,
		 * with the status-owned fields set, after a true return.
		 */
		private AsyncChainExecution__c record = new AsyncChainExecution__c();

		/**
		 * @description The fields copied from record into the same write as the status. A caller adds only fields that change
		 * along with the status and that the transition does not set itself: ContextData__c, StepLog__c, CurrentStepName__c,
		 * CompletedSteps__c and LastManualRetryAt__c. The status fields are set by applyRunTransition, never by a caller.
		 */
		private final List<SObjectField> callerFields = new List<SObjectField>();

		/**
		 * @description The message the run event records on ErrorMessage__c, where its column names one.
		 */
		private String message;

		/**
		 * @description The failure category STEP_FAILED records; read by no other run event.
		 */
		private String failureCategory;

		/**
		 * @description The status the row read before the write, set by applyRunTransition on a true return.
		 */
		private String statusBeforeTransition;
	}

	/**
	 * @description Builds a transition request fenced by the run key an executor, a handler or the sweep captured when
	 * it last read the run, for the given record (Id-only, or the caller's in-memory row whose caller fields the caller
	 * then names), run event and message.
	 *
	 * @param record The run record, with at least its Id.
	 * @param runEvent The run event that moves the run.
	 * @param fenceRunKey The captured run key the fresh row must still carry.
	 * @param message The message the run event records.
	 *
	 * @return The request, ready for applyRunTransition.
	 */
	private static RunTransitionRequest buildFencedRunTransitionRequest(AsyncChainExecution__c record, RunEvent runEvent, String fenceRunKey, String message)
	{
		RunTransitionRequest request = buildRunTransitionRequest(record, runEvent, message);
		request.enforceRunKeyFence = true;
		request.fenceRunKey = fenceRunKey;
		return request;
	}

	/**
	 * @description Builds a transition request with no run key check, for the watchdog's mark and the operator actions,
	 * which act on the fresh status alone: the given record (Id-only, or the caller's in-memory row whose caller
	 * fields the caller then names), run event and message.
	 *
	 * @param record The run record, with at least its Id.
	 * @param runEvent The run event that moves the run.
	 * @param message The message the run event records, or null for a run event that records none.
	 *
	 * @return The request, ready for applyRunTransition.
	 */
	private static RunTransitionRequest buildRunTransitionRequest(AsyncChainExecution__c record, RunEvent runEvent, String message)
	{
		RunTransitionRequest request = new RunTransitionRequest();
		request.executionId = record.Id;
		request.runEvent = runEvent;
		request.record = record;
		request.message = message;
		return request;
	}

	/**
	 * @description Decides, without side effects, whether the table allows the run event from the run's current status: the
	 * target status when it does (the fresh status itself for a run event that keeps it), the refusal reason otherwise.
	 *
	 * @param runEvent The event that would move the run.
	 * @param currentStatus The run's status as freshly read.
	 *
	 * @return The decision.
	 */
	private static RunTransitionDecision decideRunTransition(RunEvent runEvent, String currentStatus)
	{
		RunTransitionDecision decision = new RunTransitionDecision();
		if(ALLOWED_FROM_STATUSES_BY_RUN_EVENT.get(runEvent).contains(currentStatus))
		{
			decision.targetStatus = TARGET_STATUS_BY_RUN_EVENT.get(runEvent) ?? currentStatus;
			return decision;
		}
		decision.refusalReason = TRANSITION_REFUSED_PREFIX + runEvent.name() + ' from ' + currentStatus;
		return decision;
	}

	/**
	 * @description Whether some run event of the transition table moves a run from one status to another. It looks only
	 * at the status before and the status after, and works the answer out from ALLOWED_FROM_STATUSES_BY_RUN_EVENT and
	 * TARGET_STATUS_BY_RUN_EVENT and from nothing else. A run event that keeps the status makes the (from, from) pair
	 * legal. It exists for TRG_AsyncChainRunTransition, the package's own
	 * trigger action, and may change without notice.
	 *
	 * @param fromStatus The status the run reads before the write.
	 * @param toStatus The status the write would give it.
	 *
	 * @return True when at least one run event allows that move.
	 */
	public static Boolean isAllowedRunTransition(String fromStatus, String toStatus)
	{
		for(RunEvent runEvent : ALLOWED_FROM_STATUSES_BY_RUN_EVENT.keySet())
		{
			if(ALLOWED_FROM_STATUSES_BY_RUN_EVENT.get(runEvent).contains(fromStatus) && (TARGET_STATUS_BY_RUN_EVENT.get(runEvent) ?? fromStatus) == toStatus)
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * @description The one writer of a chain run's status fields. It works in this order:
	 * 1. Reads the row fresh through SEL_AsyncChainExecution.findByIdForTransition. A missing row is a WARN and false.
	 * 2. When the request asks for it, checks that the row still carries the run key the caller captured (the fence).
	 *    A stale key is a WARN and false.
	 * 3. Decides the run event against the fresh status. A refusal is an ERROR and false, never a throw.
	 * 4. Sets on the fresh row the status-owned fields the run event's column names, copies the caller's fields from
	 *    the request's record, and builds the sparse write (a record that carries only the fields in the write set)
	 *    from both through buildSparseUpdate.
	 * 5. Checks the four rules a row must meet in its status, on the row as it will read after the write: a Stalled run
	 *    has no end time and no duration; a finished run has an end time and no active deduplication key; a Running run
	 *    has no end time and no failure category; a Failed or Aborted run has a failure category. A broken rule is an
	 *    ERROR and false.
	 * 6. Writes in system mode and returns true, with the fresh row left on the request.
	 *
	 * The write can still fail at the trigger backstop (TRG_AsyncChainRunTransition) in one case: another writer moved the
	 * run between the fresh read and the write, and the move from the status the row has now is not one the engine
	 * makes. That one failure is caught here: an ERROR log that starts with BACKSTOP_REFUSED_PREFIX, then false, as for
	 * every other refusal. Every other DmlException the write raises propagates to the caller, whose own try/catch owns it.
	 *
	 * @param request The run, the run event, the fence, the caller fields and the message.
	 *
	 * @return True when the write went through; false when the row is missing, the fence failed, the table refused the run event,
	 * the write set broke one of the four rules, or the trigger backstop refused the write because the row moved in between.
	 */
	private static Boolean applyRunTransition(RunTransitionRequest request)
	{
		AsyncChainExecution__c fresh = new SEL_AsyncChainExecution().findByIdForTransition(request.executionId);
		if(fresh == null)
		{
			LOG_Builder.build().warn('Chain execution record deleted externally')
					.at(CLASS_NAME + '.applyRunTransition')
					.forRecord(request.executionId)
					.emit();
			return false;
		}
		if(request.enforceRunKeyFence && request.fenceRunKey != fresh.RunKey__c) // null == null passes (upgrade-safe)
		{
			LOG_Builder.build().warn('Chain step skipped: stale run key (fenced)')
					.at(CLASS_NAME + '.applyRunTransition')
					.forRecord(fresh.Id)
					.emit();
			return false;
		}

		RunTransitionDecision decision = decideRunTransition(request.runEvent, fresh.Status__c);
		if(!decision.isAllowed())
		{
			return refuseRunTransition(decision.refusalReason, fresh.Id);
		}

		String statusBeforeTransition = fresh.Status__c;
		List<SObjectField> writeSet = new List<SObjectField> {AsyncChainExecution__c.Status__c};
		fresh.Status__c = decision.targetStatus;
		applyRunEventColumn(request, fresh, writeSet);
		for(SObjectField callerField : request.callerFields)
		{
			fresh.put(callerField, request.record.get(callerField));
			writeSet.add(callerField);
		}
		String invariantRefusal = findRunInvariantBreach(fresh);
		if(invariantRefusal != null)
		{
			return refuseRunTransition(TRANSITION_REFUSED_PREFIX + request.runEvent.name() + ' from ' + statusBeforeTransition + ': ' + invariantRefusal, fresh.Id);
		}

		try
		{
			DML_Builder.newTransaction().systemModeInternal().doUpdate(buildSparseUpdate(fresh, writeSet)).execute();
		}
		catch(DmlException dmlError)
		{
			if(!isBackstopRefusal(dmlError))
			{
				throw dmlError;
			}
			return refuseRunTransition(BACKSTOP_REFUSED_PREFIX + request.runEvent.name() + ' from ' + statusBeforeTransition + BACKSTOP_REFUSED_REASON, fresh.Id);
		}
		request.record = fresh;
		request.statusBeforeTransition = statusBeforeTransition;
		return true;
	}

	/**
	 * @description Tells whether a failed write is the trigger backstop's refusal, as opposed to any other write failure.
	 * The backstop refuses with a validation error (status code FIELD_CUSTOM_VALIDATION_EXCEPTION) whose message is the
	 * AsyncChain_TransitionRefused label. The label's two placeholders carry the statuses the trigger saw, which are not
	 * the ones the function read when the row moved in between, so the check matches the label's fixed text with any
	 * text in place of each placeholder, rather than the whole formatted message.
	 *
	 * @param dmlError The failure the write raised.
	 *
	 * @return True when the backstop refused the write.
	 */
	private static Boolean isBackstopRefusal(DmlException dmlError)
	{
		if(dmlError.getNumDml() == 0 || dmlError.getDmlType(0) != StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION)
		{
			return false;
		}
		List<String> labelFragments = new List<String>();
		for(String fragment : System.Label.AsyncChain_TransitionRefused.split(LABEL_PLACEHOLDER_PATTERN))
		{
			labelFragments.add(Pattern.quote(fragment));
		}
		return Pattern.compile(String.join(labelFragments, ANY_TEXT_PATTERN)).matcher(dmlError.getMessage()).find();
	}

	/**
	 * @description Logs a refused transition at ERROR for the run and answers false, so every refusal in
	 * applyRunTransition reads the same way and none of them throws.
	 *
	 * @param reason The refusal reason, starting with TRANSITION_REFUSED_PREFIX.
	 * @param executionId The run the refusal is about.
	 *
	 * @return False, always.
	 */
	private static Boolean refuseRunTransition(String reason, Id executionId)
	{
		LOG_Builder.build().error(reason)
				.at(CLASS_NAME + '.applyRunTransition')
				.forRecord(executionId)
				.emit();
		return false;
	}

	/**
	 * @description Sets, on the fresh row, the status-owned fields the run event's column of the transition table names, and
	 * adds each to the write set. Status__c is already set and in the write set. Every run event has its column here. A
	 * run event that keeps the run finished (the two handler run events, the kill switch over an Aborted run) never puts
	 * CompletedAt__c or DurationMs__c in the write set: the first write into a finished status sets the end time and a
	 * later one keeps it, because an end time never changes once it is set. The three run events that give the run a new
	 * key (WATCHDOG_REDRIVEN, RECOVERY_DEGRADED, OPERATOR_RETRIED) are the only columns that put RunKey__c in the write set.
	 *
	 * @param request The request carrying the message and the failure category.
	 * @param fresh The freshly read row, with Status__c already set to the target.
	 * @param writeSet The fields the sparse write carries; this method adds to it.
	 */
	private static void applyRunEventColumn(RunTransitionRequest request, AsyncChainExecution__c fresh, List<SObjectField> writeSet)
	{
		switch on request.runEvent
		{
			when STEP_COMPLETED
			{
				endRun(fresh, writeSet, null, request.message);
			}
			when STEP_FAILED
			{
				endRun(fresh, writeSet, request.failureCategory, request.message);
			}
			when QUEUEABLE_CRASHED
			{
				endRun(fresh, writeSet, SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, request.message);
			}
			when KILL_SWITCH_ABORTED
			{
				abortRun(fresh, writeSet, SEL_AsyncChainExecution.FAILURE_CATEGORY_KILL_SWITCH, request.message);
			}
			when OPERATOR_ABORTED
			{
				abortRun(fresh, writeSet, SEL_AsyncChainExecution.FAILURE_CATEGORY_OPERATOR_ABORT, request.message);
			}
			when HANDLER_SUCCEEDED
			{
				fresh.ErrorMessage__c = UTIL_String.abbreviate(request.message, AsyncChainExecution__c.ErrorMessage__c);
				writeSet.add(AsyncChainExecution__c.ErrorMessage__c);
				// A stalled run is still the active run for its deduplication key. So the write-back of a stalled notification
				// leaves the key in place, and a start with the same key still returns this run. On a finished run the key is
				// normally already null (the final write cleared it), and this release protects upgrades: a chain whose final
				// write ran under an older package version releases its leftover key here. No test on a single version can see
				// this, so passing tests are no reason to remove it.
				if(fresh.Status__c != SEL_AsyncChainExecution.STATUS_STALLED)
				{
					fresh.ActiveDeduplicationKey__c = null;
					writeSet.add(AsyncChainExecution__c.ActiveDeduplicationKey__c);
				}
			}
			when HANDLER_FAILED
			{
				// A run that came from Completed has no category yet and gets StepException; a Failed run keeps the
				// category its step failure set, and the combined message carries both reasons.
				recordRunOutcome(fresh, writeSet, fresh.FailureCategory__c ?? SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, request.message);
			}
			when ENQUEUE_FAILED, WATCHDOG_STALLED
			{
				fresh.FailureCategory__c = SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED;
				fresh.ErrorMessage__c = UTIL_String.abbreviate(request.message, AsyncChainExecution__c.ErrorMessage__c);
				writeSet.addAll(new List<SObjectField> {AsyncChainExecution__c.FailureCategory__c, AsyncChainExecution__c.ErrorMessage__c});
			}
			when HANDLER_NOT_QUEUED
			{
				Integer messageLimit = UTIL_SObjectDescribe.getCachedFieldDescribe(AsyncChainExecution__c.ErrorMessage__c).length;
				fresh.ErrorMessage__c = appendNoteWithinLimit(fresh.ErrorMessage__c, request.message, messageLimit);
				writeSet.add(AsyncChainExecution__c.ErrorMessage__c);
			}
			when WATCHDOG_REDRIVEN
			{
				// A re-driven run is Running again, and a Running run carries no failure category.
				// The same write clears the failure category the stall set and gives the run a new key. The new key shuts the dead executor out.
				rotateRunKey(fresh, writeSet);
				fresh.FailureCategory__c = null;
				writeSet.add(AsyncChainExecution__c.FailureCategory__c);
			}
			when RECOVERY_DEGRADED
			{
				rotateRunKey(fresh, writeSet);
				endRun(fresh, writeSet, SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED, request.message);
			}
			when OPERATOR_RETRIED
			{
				rotateRunKey(fresh, writeSet);
				reopenRun(fresh, writeSet);
			}
		}
	}

	/**
	 * @description Gives the run a new key on the fresh row and adds RunKey__c to the write set, so an executor that
	 * later wakes with the old key is shut out of the run. The three run events that give the run a new key share it, and
	 * nothing else in a transition writes RunKey__c.
	 *
	 * @param fresh The freshly read row.
	 * @param writeSet The fields the sparse write carries; this method adds to it.
	 */
	private static void rotateRunKey(AsyncChainExecution__c fresh, List<SObjectField> writeSet)
	{
		fresh.RunKey__c = UTIL_Random.randomUUID();
		writeSet.add(AsyncChainExecution__c.RunKey__c);
	}

	/**
	 * @description Aborts the run on the fresh row, for the kill switch and the operator abort: records the outcome
	 * (recordRunOutcome) with the given category, and records the end (stampRunEnd) only when the run has no end time
	 * yet. So a run already Aborted keeps the end time and the duration its abort set, and the kill switch writes only
	 * the category and the reason again, because an end time never changes once it is set.
	 *
	 * @param fresh The freshly read row.
	 * @param writeSet The fields the sparse write carries; this method adds to it.
	 * @param failureCategory FAILURE_CATEGORY_KILL_SWITCH or FAILURE_CATEGORY_OPERATOR_ABORT.
	 * @param message The abort reason.
	 */
	private static void abortRun(AsyncChainExecution__c fresh, List<SObjectField> writeSet, String failureCategory, String message)
	{
		recordRunOutcome(fresh, writeSet, failureCategory, message);
		if(fresh.CompletedAt__c == null)
		{
			stampRunEnd(fresh, writeSet);
		}
	}

	/**
	 * @description Opens a finished run again on the fresh row, for the operator retry: the end time, the duration, the
	 * failure category and the message are cleared (a Running run carries no end time and no failure category, and old
	 * error details must not outlive the state they described). The run's declared deduplication key is taken again as
	 * its active key. So a start with the same key returns the retried run, and a live run that holds the key makes the
	 * retry fail through the platform's duplicate-value error. All five fields join the write set.
	 *
	 * @param fresh The freshly read row.
	 * @param writeSet The fields the sparse write carries; this method adds to it.
	 */
	private static void reopenRun(AsyncChainExecution__c fresh, List<SObjectField> writeSet)
	{
		fresh.CompletedAt__c = null;
		fresh.DurationMs__c = null;
		fresh.FailureCategory__c = null;
		fresh.ErrorMessage__c = null;
		fresh.ActiveDeduplicationKey__c = fresh.DeclaredDeduplicationKey__c;
		writeSet.addAll(new List<SObjectField>
		{
				AsyncChainExecution__c.CompletedAt__c,
				AsyncChainExecution__c.DurationMs__c,
				AsyncChainExecution__c.FailureCategory__c,
				AsyncChainExecution__c.ErrorMessage__c,
				AsyncChainExecution__c.ActiveDeduplicationKey__c
		});
	}

	/**
	 * @description Ends the run on the fresh row, for the run events whose first write moves it into a finished status:
	 * records the outcome (recordRunOutcome) and records the end time (stampRunEnd).
	 *
	 * @param fresh The freshly read row.
	 * @param writeSet The fields the sparse write carries; this method adds to it.
	 * @param failureCategory The SEL_AsyncChainExecution.FAILURE_CATEGORY_* value, or null for a run that ended well.
	 * @param message The message the run event records, or null.
	 */
	private static void endRun(AsyncChainExecution__c fresh, List<SObjectField> writeSet, String failureCategory, String message)
	{
		recordRunOutcome(fresh, writeSet, failureCategory, message);
		stampRunEnd(fresh, writeSet);
	}

	/**
	 * @description Records a run event's outcome on the fresh row: the failure category, the message and the release of
	 * the active deduplication key (a run that has ended, or is ending, holds no key), and adds the three to the write set.
	 *
	 * @param fresh The freshly read row.
	 * @param writeSet The fields the sparse write carries; this method adds to it.
	 * @param failureCategory The SEL_AsyncChainExecution.FAILURE_CATEGORY_* value, or null for a run that ended well.
	 * @param message The message the run event records, or null.
	 */
	private static void recordRunOutcome(AsyncChainExecution__c fresh, List<SObjectField> writeSet, String failureCategory, String message)
	{
		fresh.FailureCategory__c = failureCategory;
		fresh.ErrorMessage__c = UTIL_String.abbreviate(message, AsyncChainExecution__c.ErrorMessage__c);
		fresh.ActiveDeduplicationKey__c = null;
		writeSet.addAll(new List<SObjectField>
		{
				AsyncChainExecution__c.FailureCategory__c,
				AsyncChainExecution__c.ErrorMessage__c,
				AsyncChainExecution__c.ActiveDeduplicationKey__c
		});
	}

	/**
	 * @description Records the end of the run on the fresh row: the completion time now and the duration since the run
	 * started, capped at what the field holds (resolveStoredDuration), and adds both to the write set. Called by the
	 * first write into a finished status only, because an end time never changes once it is set.
	 *
	 * @param fresh The freshly read row.
	 * @param writeSet The fields the sparse write carries; this method adds to it.
	 */
	private static void stampRunEnd(AsyncChainExecution__c fresh, List<SObjectField> writeSet)
	{
		fresh.CompletedAt__c = Datetime.now();
		if(fresh.StartedAt__c != null)
		{
			fresh.DurationMs__c = resolveStoredDuration(fresh.StartedAt__c);
		}
		writeSet.addAll(new List<SObjectField> {AsyncChainExecution__c.CompletedAt__c, AsyncChainExecution__c.DurationMs__c});
	}

	/**
	 * @description Checks the rules a row must meet in its status, on the row as it will read after the write:
	 * - a Stalled run has no CompletedAt__c and no DurationMs__c;
	 * - a Completed, Failed or Aborted run has CompletedAt__c set and no ActiveDeduplicationKey__c;
	 * - a Running run has no CompletedAt__c and no FailureCategory__c;
	 * - a Failed or Aborted run has FailureCategory__c set.
	 * It guards against a future edit of a run event's column that would break one of them.
	 *
	 * @param freshRow The fresh row with the run event's fields set.
	 *
	 * @return Null when every rule holds, or the first broken rule named.
	 */
	private static String findRunInvariantBreach(AsyncChainExecution__c freshRow)
	{
		String status = freshRow.Status__c;
		if(status == SEL_AsyncChainExecution.STATUS_STALLED && (freshRow.CompletedAt__c != null || freshRow.DurationMs__c != null))
		{
			return 'a Stalled run must have no end time and no duration';
		}
		if(isTerminalStatus(status) && (freshRow.CompletedAt__c == null || freshRow.ActiveDeduplicationKey__c != null))
		{
			return 'a finished run must have an end time and no active deduplication key';
		}
		if(status == SEL_AsyncChainExecution.STATUS_RUNNING && (freshRow.CompletedAt__c != null || freshRow.FailureCategory__c != null))
		{
			return 'a Running run must have no end time and no failure category';
		}
		if((status == SEL_AsyncChainExecution.STATUS_FAILED || status == SEL_AsyncChainExecution.STATUS_ABORTED) && freshRow.FailureCategory__c == null)
		{
			return 'a Failed or Aborted run must have a failure category';
		}
		return null;
	}

	/**
	 * @description Appends the handler note to a run's existing message so the note survives whatever length the message
	 * has: a blank message gives the note alone; otherwise the message is abbreviated to the room the separator and the
	 * note leave, so a message that fills the field keeps its first characters and the note stays whole. When the note
	 * alone leaves no room for a message, the message is dropped and the note is abbreviated to the limit, because the
	 * note is the signal a reader needs.
	 *
	 * @param existingMessage The run's ErrorMessage__c as freshly read, or null.
	 * @param note The handler note with the platform's reason.
	 * @param messageLimit The length ErrorMessage__c stores.
	 *
	 * @return The message to write, never longer than the limit.
	 */
	private static String appendNoteWithinLimit(String existingMessage, String note, Integer messageLimit)
	{
		String separatedNote = HANDLER_NOTE_SEPARATOR + note;
		Integer roomForMessage = messageLimit - separatedNote.length();
		if(String.isBlank(existingMessage) || roomForMessage < MINIMUM_ABBREVIATED_MESSAGE_LENGTH)
		{
			return UTIL_String.abbreviate(note, messageLimit);
		}
		return UTIL_String.abbreviate(existingMessage, roomForMessage) + separatedNote;
	}

	/**
	 * @description The one stall sequence, for the Finalizer's stall (ChainExecutor.markChainStalledFromFinalizer, the
	 * ENQUEUE_FAILED run event fenced by the executor's captured key) and the watchdog's mark and parks
	 * (markStalledFromWatchdog, the WATCHDOG_STALLED run event, with no run key check): the request goes through applyRunTransition,
	 * which reads the run fresh, refuses a run that has ended (the transition table allows a stall from Running and
	 * Stalled only) and writes Status__c, FailureCategory__c and ErrorMessage__c, with StepLog__c when the request
	 * carries it as a caller field. After a write that went through, the stall is logged (emitStallLog) and the
	 * notification runs. A refused write skips both, and a DmlException passes up to the caller, which logs the failure.
	 *
	 * The notification guard is per-transition, not per-chain: it fires only on an actual change
	 * into Stalled, read from the status the run had before the write. A chain already Stalled that is marked
	 * again never re-notifies; a chain re-driven back to Running that stalls again legitimately
	 * notifies again. On a genuine transition with no resolvable handler and none withheld, the
	 * stall log entry is recorded at ERROR instead of WARN (see emitStallLog) so an unhandled
	 * stall surfaces by default.
	 *
	 * Stalled is not a finished status (the chain awaits recovery), so the write leaves CompletedAt__c and DurationMs__c
	 * unset and no performance log is emitted; a later re-drive finishes the chain and records its end time then.
	 *
	 * A remaining limit: a notification may be delivered more than once. A queued notification is not
	 * taken back if later writes fail, so onError handlers must cope with duplicate stall notifications.
	 *
	 * @param request The stall request: the run, ENQUEUE_FAILED or WATCHDOG_STALLED, the fence the caller chose, the
	 * stall reason as the message and StepLog__c as a caller field when the caller hands one.
	 * @param notificationHandler The onError handler definition to notify once per transition, or null for none.
	 * @param notificationWithheld True when the caller passed null for notificationHandler on
	 * purpose rather than because none exists. A budget park skips the notification to save the
	 * async budget even when the chain has a registered handler. Only a false value can produce
	 * the unhandled-stall ERROR: a park must never be logged as a chain with no handler.
	 */
	private static void markStalledAndNotify(RunTransitionRequest request, DTO_StepDefinition notificationHandler, Boolean notificationWithheld)
	{
		if(!applyRunTransition(request))
		{
			return;
		}

		Boolean stallTransition = request.statusBeforeTransition != SEL_AsyncChainExecution.STATUS_STALLED;
		emitStallLog(request.record, request.message, stallTransition && notificationHandler == null && !notificationWithheld);
		if(stallTransition)
		{
			enqueueRecoveryErrorHandler(request.record, request.message, notificationHandler, SEL_AsyncChainExecution.STATUS_STALLED);
		}
	}

	/**
	 * @description Logs a stall after its write went through: at ERROR when the transition into Stalled is a real one with
	 * no onError handler to notify, so an unhandled stall stands out; at WARN otherwise. Called by markStalledAndNotify
	 * for the watchdog's mark and the Finalizer's stall alike.
	 *
	 * @param execution The run as written.
	 * @param message The stall reason.
	 * @param unhandledStallTransition True for a genuine transition into Stalled with no resolvable onError handler and no notification withheld.
	 */
	private static void emitStallLog(AsyncChainExecution__c execution, String message, Boolean unhandledStallTransition)
	{
		LOG_Builder.LogEntry stallLog = unhandledStallTransition
				? LOG_Builder.build().error('Chain stalled with no onError handler registered: ' + message)
				: LOG_Builder.build().warn('Chain stalled: ' + message);
		stallLog.at(CLASS_NAME + '.markStalledAndNotify')
				.forRecord(execution.Id)
				.emit();
	}

	/**
	 * @description Queues the given onError handler for a recovery outcome: a transition into
	 * Stalled, or the final Failed of a run that cannot be recovered. The caller makes sure it is sent
	 * only once (the stall path sends only on a real status change; the Failed path sends once, at
	 * the end). The caller calls only after its write went through, and passes the row
	 * applyRunTransition wrote. So the handler executor takes the run key that write left (the key the
	 * stall kept, or the new key the Failed write set), and a later new run key shuts the notification
	 * out. The enqueue itself may fail in the same transaction that ran out of resources and caused the
	 * stall. So on failure it only writes an error log and never throws, the same rule the Finalizer
	 * follows for its other handler enqueues. A notification may therefore be delivered more than
	 * once; exactly-once delivery is never promised.
	 *
	 * @param execution The execution record as written, carrying the context data, the correlation ID and the run key.
	 * @param message The recovery reason, passed to the handler as the original error message.
	 * @param notificationHandler The onError handler definition to run, or null for none.
	 * @param expectedStatus The status the handler's success write-back records: Stalled for a stall, Failed for a run that cannot be recovered.
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
			AsyncOptions notificationOptions = new AsyncOptions();
			notificationOptions.maximumQueueableStackDepth = NOTIFICATION_HANDLER_STACK_DEPTH;
			System.enqueueJob(new HandlerExecutor(execution.Id, context, notificationHandler, expectedStatus, message, execution.RunKey__c), notificationOptions);
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
	 * @description Builds a sparse update record that carries only the given fields, copied from the
	 * in-memory execution record. An executor's save must never update the loaded record directly.
	 * An update DML writes every queried field back. So a write of the whole record would silently undo
	 * a new run key (RunKey__c) or an outside abort (Status__c) saved by other code after this
	 * executor's read. These rules apply to the fields:
	 * - RunKey__c is in no executor write. Only two kinds of code write it: the inserts that create a
	 *   key (ChainBuilder.execute()'s first insert, restartChainFromStart's insert of the restart copy)
	 *   and the three run events inside applyRunTransition that give the run a new key
	 *   (WATCHDOG_REDRIVEN, RECOVERY_DEGRADED, OPERATOR_RETRIED). So a new key is never part of an
	 *   executor's save. The data-masking trigger never rewrites the field either (UTIL_FrameworkMasker
	 *   leaves it out when it expands a wildcard).
	 * - Status__c is written only by applyRunTransition and by the inserts.
	 * - Exactly two methods write CurrentJobId__c: stampExecutorJobId, called at the first enqueue and
	 *   at every watchdog or operator re-enqueue, and the progress write. So final writes leave the
	 *   last known executor's job id in place for the watchdog's check that the job is alive.
	 * Before calling, every field in the list must have been queried or set on the in-memory record.
	 * Otherwise the copy would write a null that nobody meant to write.
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
	 * @description How long a run took, as DurationMs__c can store it: now minus the start, capped at the field's maximum.
	 * Every writer of DurationMs__c sets it through this method.
	 *
	 * @param startedAt The run's start; never null at a call site.
	 *
	 * @return The duration in milliseconds, at most STORED_DURATION_MAX_MILLISECONDS.
	 *
	 * @since 1.8
	 */
	private static Long resolveStoredDuration(Datetime startedAt)
	{
		return Math.min(Datetime.now().getTime() - startedAt.getTime(), STORED_DURATION_MAX_MILLISECONDS);
	}

	/**
	 * @description How long a failed run waited for the operator's retry. Never guessed: a run that recorded no end, or an
	 * end later than the retry, has no wait that can be known, and says so with MANUAL_RETRY_WAIT_UNKNOWN.
	 *
	 * @param failedAt The run's completion timestamp, read before the retry clears it.
	 * @param retriedAt The instant of the retry.
	 *
	 * @return The wait in milliseconds, or MANUAL_RETRY_WAIT_UNKNOWN.
	 *
	 * @since 1.8
	 */
	private static Long resolveManualRetryWait(Datetime failedAt, Datetime retriedAt)
	{
		Long waited = failedAt == null ? null : retriedAt.getTime() - failedAt.getTime();
		return waited == null || waited < 0 ? MANUAL_RETRY_WAIT_UNKNOWN : waited;
	}

	/**
	 * @description Serializes the retried run's step log, keeping the manual retry marker only when the log still leaves the
	 * per-step runtime reserve free for every step that has yet to record a result. A retry never fails because of the marker,
	 * and no later step persist overflows because of it: a log with no such room (a very large chain, near the field's
	 * capacity) is written without the marker, and the retry proceeds. The room is measured with a plain serialization, before
	 * serializeStepLog's message-dropping valve can see the marker: the marker is the first thing given up, and it never costs
	 * another step its message.
	 *
	 * @param persistedDefinitions The full persisted definition list, the retried entry already cleared and marked.
	 * @param retriedEntry The retried step's entry, inside that list.
	 * @param stepsYetToRecord The retried step and every step after it.
	 *
	 * @return Step-log JSON that fits the field and keeps the reserve free.
	 *
	 * @since 1.8
	 */
	private static String serializeStepLogForManualRetry(List<DTO_StepDefinition> persistedDefinitions, DTO_StepDefinition retriedEntry, Integer stepsYetToRecord)
	{
		Integer stepLogCapacity = UTIL_SObjectDescribe.getCachedFieldDescribe(AsyncChainExecution__c.StepLog__c).getLength();
		Integer markedLength = JSON.serialize(persistedDefinitions, true).length();
		if(markedLength + stepsYetToRecord * STEP_RUNTIME_RESERVE_LENGTH > stepLogCapacity)
		{
			retriedEntry.manualRetryAfterMs = null;
		}
		return serializeStepLog(persistedDefinitions);
	}

	/**
	 * @description Records the AsyncApexJob id of the executor just queued on the run record. Then
	 * the watchdog's job check (isExecutorLive) can prove the job is dead even for chains that have
	 * not yet reached a progress write: a chain still on its first step, a chain with one step that
	 * never makes a progress write at all, or a chain just re-driven. Exactly two methods write
	 * CurrentJobId__c: this one and the progress write. This one is called from all four enqueues
	 * where a chain starts or starts again: the first enqueue (ChainBuilder.execute), the watchdog
	 * re-drive (redriveStalledChain), the operator retry (retryChainFromFailedStep) and the operator
	 * restart copy (restartChainFromStart). The other enqueues in this class do not record the id, on
	 * purpose. The next hop and the retry inside ChainExecutor.Finalizer are already covered by the
	 * progress write (isExecutorLive explains why that id is one step behind). The handler enqueue
	 * never records it, because handlers are notifications, not chain executors.
	 *
	 * It runs after the enqueue succeeded. That order keeps the job id safe at every caller:
	 * - First enqueue, in the same transaction as the run record insert: an enqueue failure that is
	 *   not caught rolls the whole start back, so no job id can outlive its job. A caller that catches
	 *   that failure instead saves a Running row with a null job id. The sweep treats that as CANNOT
	 *   CHECK: it only marks and notifies, and never takes it as proof the job is dead (see
	 *   sweepCandidate). And the row cannot be seen outside the start transaction until it is saved,
	 *   so no new run key can be written at the same time as the job id.
	 * - Watchdog re-drive: if the enqueue fails, the job id is never recorded. So the dead executor's
	 *   job id stays in place and still shows a dead job, and the next sweep finds the row again (see
	 *   redriveStalledChain).
	 * - Operator retry: an enqueue failure that is not caught rolls the whole action back, so the row
	 *   simply stays Failed (see retryChainFromFailedStep).
	 * - Operator restart: the insert of the restart copy is in the same transaction, so the same
	 *   rollback removes the copy entirely, and no copy without a job id is left behind (see
	 *   restartChainFromStart).
	 * A caller that catches either of the last two failures instead saves the row as it was: a Running
	 * chain with a null job id, which the sweep treats as CANNOT CHECK, exactly as at the first enqueue.
	 * The sparse write carries only CurrentJobId__c, by the rule for executor saves (see
	 * buildSparseUpdate). A delayed first enqueue records the id too. The job keeps a live Queued
	 * status during its delay, so the check reads it as slow but alive, and never re-drives it by mistake.
	 *
	 * @param execution The run record to update: the row just inserted at a first enqueue or a restart copy, or the fresh read at a re-drive.
	 * @param executorJobId The enqueued executor's AsyncApexJob id.
	 */
	private static void stampExecutorJobId(AsyncChainExecution__c execution, Id executorJobId)
	{
		execution.CurrentJobId__c = executorJobId;
		DML_Builder.newTransaction().systemModeInternal().doUpdate(buildSparseUpdate(execution, new List<SObjectField> {AsyncChainExecution__c.CurrentJobId__c})).execute();
	}

	/**
	 * @description Queues an executor, rebuilt from the record, for a chain that runs again, and
	 * records the job id. It is the ONE set of recovery limits shared by all three ways a chain runs
	 * again (the watchdog re-drive, the operator retry, the operator restart). It exists so those
	 * limits are defined in one place. A chain that runs again uses the FRAMEWORK DEFAULTS, because
	 * the original run's AsyncOptions and builder values were never saved. The default includes the
	 * nesting reserve, so a step or a handler of such a run may launch a chain exactly as one of a new
	 * launch may. The subscriber guides describe these recovery defaults, so they must not differ from
	 * path to path. In detail: DEFAULT_MAX_STEPS; a context limit no lower than the saved document's
	 * own length (so a context already larger than the default is never cut short on resume); a stack
	 * depth with one hop for each remaining entry plus the executor itself; and one AsyncOptions
	 * instance used BOTH as the enqueue options and as the options the executor passes on. Handlers
	 * are read from the saved definitions, not worked out again, so the run keeps the handlers it was
	 * built with.
	 *
	 * The job id is recorded strictly AFTER the enqueue (the job id does not exist before it), in a
	 * sparse update of a single field. So it can never undo a new run key written at the same time
	 * (see stampExecutorJobId for what each caller's failure leaves behind).
	 *
	 * The caller must already have saved the record's new run key (or its insert), so the key this
	 * executor checks is the key the row now carries.
	 *
	 * @param execution The run record whose executor is queued; supplies the id, the context document and the current run key.
	 * @param resumeIndex The step index the executor resumes at.
	 * @param persistedDefinitions The persisted definition list the error and completion handlers are resolved from.
	 * @param remainingStepCount The number of chain-step entries the run still has to execute.
	 */
	private static void enqueueRecoveryExecutor(AsyncChainExecution__c execution, Integer resumeIndex, List<DTO_StepDefinition> persistedDefinitions, Integer remainingStepCount)
	{
		Integer effectiveMaxContextSize = Math.max(DEFAULT_MAX_CONTEXT_SIZE, execution.ContextData__c?.length() ?? 0);
		AsyncOptions options = new AsyncOptions();
		options.maximumQueueableStackDepth = remainingStepCount + 1 + MAXIMUM_NESTING_DEPTH;
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
	 * @description Restores the transaction's logging context from the serialized LOG context the
	 * chain carries. For a chain saved by a package version without a LOG context, it only passes on
	 * the correlation id. Both executors call it before the work they run. A handler's log entries,
	 * and a chain a handler launches, carry the run's ids only when the handler's transaction has
	 * restored them. Without this call, a handler's entries would carry no correlation.
	 *
	 * @param context The current chain context.
	 * @param correlationId The chain's correlation ID fallback.
	 */
	private static void hydrateLogContext(ChainContext context, String correlationId)
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
	 * @description What the framework knows about the step or handler running in this transaction, kept while its work
	 * runs so a chain it launches can be keyed by it and placed one level below it: the run's record id, the position
	 * (the step index, or the handler's position), the run's nesting depth, and the one run the step launched in this
	 * transaction, so a second launch can be refused.
	 *
	 * @since 1.8
	 */
	private class RunningStep
	{
		/**
		 * @description The run whose step or handler is running.
		 */
		private final Id executionId;

		/**
		 * @description The step index, or the handler's position.
		 */
		private final String position;

		/**
		 * @description The run's nesting depth below the first chain of the action.
		 */
		private final Integer nestingDepth;

		/**
		 * @description The run the step or handler launched in this transaction, or the existing run a launch returned;
		 * null until it does.
		 */
		private Id launchedRunId;

		/**
		 * @description The chain name of the run in launchedRunId, set at the same time. It is used only to name that run
		 * in the error that refuses a second launch from the same step or handler.
		 */
		private String launchedChainName;

		/**
		 * @description Records the running step or handler.
		 *
		 * @param executionId The run whose step or handler is running.
		 * @param position The step index, or the handler's position.
		 * @param nestingDepth The run's nesting depth.
		 */
		private RunningStep(Id executionId, String position, Integer nestingDepth)
		{
			this.executionId = executionId;
			this.position = position;
			this.nestingDepth = nestingDepth;
		}

		/**
		 * @description The key a launch from this step or handler is declared under when the caller set none.
		 *
		 * @return The run's record id and the position, joined by a colon.
		 */
		private String launchKey()
		{
			return executionId + ':' + position;
		}

		/**
		 * @description Records the one run this step or handler launched in this transaction, or the existing run a
		 * launch returned.
		 *
		 * @param runId The run launched, or the existing run returned.
		 * @param chainName Its chain name.
		 */
		private void rememberLaunch(Id runId, String chainName)
		{
			launchedRunId = runId;
			launchedChainName = chainName;
		}
	}

	/**
	 * @description Records the step or handler about to run in this transaction, so a chain it launches is keyed by it
	 * and sits one level below its run.
	 *
	 * @param executionId The run whose step or handler is about to run.
	 * @param position The step index, or the handler's position.
	 * @param context The run's context, which carries the run's nesting depth.
	 *
	 * @since 1.8
	 */
	private static void markRunningStep(Id executionId, String position, ChainContext context)
	{
		runningStep = new RunningStep(executionId, position, nestingDepthOf(context));
	}

	/**
	 * @description Clears the running-step marker once the work has returned, whatever its outcome, so nothing launched
	 * later in the transaction is mistaken for a step's launch.
	 *
	 * @since 1.8
	 */
	private static void clearRunningStep()
	{
		runningStep = null;
	}

	/**
	 * @description The nesting depth a run's context carries, or zero for a run whose context has no such key.
	 *
	 * @param context The run's context.
	 *
	 * @return The run's nesting depth.
	 *
	 * @since 1.8
	 */
	private static Integer nestingDepthOf(ChainContext context)
	{
		return context.has(NESTING_DEPTH_KEY) ? (Integer)context.get(NESTING_DEPTH_KEY) : 0;
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