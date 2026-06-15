// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Runs `PostTriggerAction__mdt`-configured post-trigger actions at the
 * outermost dispatch unwind, in `Order__c` ascending. Each row is gated through three
 * cheap-first filters before the action is instantiated:
 *
 * 1. Feature-flag gate (`BypassFeatureFlag__c` / `RequiredFeatureFlag__c`)
 * 2. Optional `TriggerSetting__c` scope filter — when set, the parent setting's
 *    `SObjectType__c` must appear in the dispatch's `touchedSObjectTypes`
 * 3. Optional Apex entry-criteria evaluator (`EntryCriteriaContextClassName__c`)
 *
 * Rows that survive the gates are dispatched under a per-row performance timer
 * with a no-DML contract guard. Action exceptions route through `FailureAction__c`
 * policy (`LogAndContinue` or `BlockDml`); `LimitException` and the no-DML guard's
 * own `PostActionDmlException` always rethrow regardless of policy.
 *
 * A static `isRunning` guard prevents recursion if a post-action triggers DML that
 * itself fires more triggers — the inner dispatch returns immediately on re-entry.
 *
 * @see TRG_Dispatcher
 * @see SEL_PostTriggerAction
 * @see PostTriggerAction__mdt
 * @see IF_Trigger.PostAction
 * @see IF_Trigger.PostActionEntryCriteria
 * @see IF_Trigger.PostActionContext
 * @see UTIL_PostTriggerAction_TEST
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date May 2026
 *
 * @since 1.1
 */
public inherited sharing class UTIL_PostTriggerAction
{
	/**
	 * @description Format string used to build the no-DML guard's exception message when
	 * a post-action's `execute(context)` performs DML inside the dispatcher unwind.
	 * Placeholder `{0}` is the post-action's ApexClassName. The contract explicitly
	 * names "synchronous DML" — asynchronous DML (Queueable / Future / Scheduled) and
	 * Platform-Event publishes are the supported escape hatches for post-actions that
	 * need to mutate state.
	 */
	@TestVisible
	private static final String DML_VIOLATION_MESSAGE =
			'Post-trigger action "{0}" performed synchronous DML. Post-trigger actions run once after all ' +
			'trigger actions complete and must not perform synchronous DML (compute, log, or enqueue async only).';

	/**
	 * @description `triggerOperation` label passed to `UTIL_TriggerPerformanceTimer` when
	 * timing a post-action. Post-actions are transaction-scoped, not record-scoped, so
	 * none of the seven `TriggerOperation` enum values apply. The literal `'POST_TRIGGER'`
	 * is what surfaces in performance-log entries (`ClassMethod__c` and the trigger-context
	 * map) — subscribers can filter post-action perf logs with this token.
	 */
	@TestVisible
	private static final String OPERATION_LABEL = 'POST_TRIGGER';

	/**
	 * @description `at(...)` location surfaced on log entries emitted when a row's
	 * `FailureAction__c` policy routes a caught exception through `LogAndContinue`.
	 * Computed via `class.getName()` so the emitted `ClassMethod__c` is namespace-aware.
	 */
	private static final String AT_LOCATION_HANDLE_FAILURE = UTIL_PostTriggerAction.class.getName() + '.handleFailure';

	/**
	 * @description Discrete event identifier emitted on the `eventName` context key when
	 * a post-action's unhandled exception is routed through `handleFailure`.
	 */
	private static final String EVENT_NAME_POST_ACTION_FAILED = 'postAction.failed';

	/**
	 * @description Recursion guard. A post-action whose `execute(context)` performs an
	 * async enqueue is fine, but a post-action whose work re-enters trigger dispatch in
	 * the same transaction (e.g. via a Platform-Event publish that itself fires a CDC
	 * subscriber) would otherwise re-invoke the entire post-action pipeline. The guard
	 * short-circuits on re-entry.
	 */
	@TestVisible
	private static Boolean isRunning = false;

	/**
	 * @description Entry point. Called once by `TRG_Dispatcher` at the outermost dispatch
	 * unwind with a context carrying the set of SObject types whose triggers participated
	 * in the transaction. Walks `SEL_PostTriggerAction.findActiveOrdered()` rows in
	 * `Order__c` ascending, applies the three cheap-first gates, and dispatches survivors
	 * under a per-row performance timer with the no-DML contract guard.
	 *
	 * The `BypassExecution__c` gate is enforced upstream by the selector's SOQL filter
	 * (`findActiveOrdered()` returns only non-bypassed rows), so it is not re-checked here;
	 * the three in-loop gates are the feature flags, the optional `TriggerSetting__c` scope,
	 * and the optional Apex entry-criteria evaluator.
	 *
	 * @param context The post-action context for this dispatch.
	 */
	public static void run(IF_Trigger.PostActionContext context)
	{
		if(isRunning)
		{
			return;
		}
		List<PostTriggerAction__mdt> rows = SEL_PostTriggerAction.findActiveOrdered();
		if(rows.isEmpty())
		{
			return;
		}
		isRunning = true;
		try
		{
			for(PostTriggerAction__mdt row : rows)
			{
				if(isFeatureFlagGated(row))
				{
					continue;
				}
				if(isSettingScopeFiltered(row, context))
				{
					continue;
				}
				if(isEntryCriteriaFalse(row, context))
				{
					continue;
				}
				runOne(row, context);
			}
		}
		finally
		{
			isRunning = false;
		}
	}

	/**
	 * @description Feature-flag gate. A row is skipped when its `BypassFeatureFlag__c` is
	 * an active flag, OR when its `RequiredFeatureFlag__c` is set but the flag is not
	 * active. Mirrors the `SEL_TriggerAction.shouldExecute` semantics so subscribers see
	 * one consistent rule across trigger-action and post-action surfaces.
	 *
	 * @param row The post-action CMDT row.
	 *
	 * @return `true` to skip this row, `false` to proceed.
	 */
	private static Boolean isFeatureFlagGated(PostTriggerAction__mdt row)
	{
		if(UTIL_FeatureFlag.isEnabled(row.BypassFeatureFlag__r?.DeveloperName))
		{
			return true;
		}
		if(row.RequiredFeatureFlag__c != null && !UTIL_FeatureFlag.isEnabled(row.RequiredFeatureFlag__r?.DeveloperName))
		{
			return true;
		}
		return false;
	}

	/**
	 * @description Optional-lookup smart-semantics filter. When `TriggerSetting__c` is
	 * null the row is cross-object and proceeds. When set, the parent setting's
	 * `SObjectType__c` must appear in the dispatch's `touchedSObjectTypes` — otherwise
	 * the post-action is skipped because none of its scoped object's triggers
	 * participated. Mis-configured rows (blank `SObjectType__c`, or a name that doesn't
	 * resolve via `UTIL_SObjectDescribe`) are skipped fail-soft.
	 *
	 * @param row The post-action CMDT row.
	 * @param context The post-action context.
	 *
	 * @return `true` to skip this row, `false` to proceed.
	 */
	private static Boolean isSettingScopeFiltered(PostTriggerAction__mdt row, IF_Trigger.PostActionContext context)
	{
		if(row.TriggerSetting__c == null)
		{
			return false;
		}
		String parentSObjectName = row.TriggerSetting__r?.SObjectType__c;
		if(String.isBlank(parentSObjectName))
		{
			return true;
		}
		Schema.SObjectType parentType = UTIL_SObjectDescribe.getSObjectTypeByName(parentSObjectName);
		return parentType == null || !context.touchedSObjectTypes.contains(parentType);
	}

	/**
	 * @description Apex entry-criteria evaluator. When `EntryCriteriaContextClassName__c`
	 * is blank the row proceeds. When set, the named class is instantiated as an
	 * `IF_Trigger.PostActionEntryCriteria` and its `shouldRun(context)` is consulted —
	 * `false` skips the row, `true` proceeds. Mis-typed class names propagate as
	 * `TypeException` (wrong-interface binding) or `IllegalArgumentException` (unresolvable
	 * class name) so the configuration error surfaces rather than silently routing through
	 * `FailureAction__c`.
	 *
	 * @param row The post-action CMDT row.
	 * @param context The post-action context.
	 *
	 * @return `true` to skip this row, `false` to proceed.
	 */
	private static Boolean isEntryCriteriaFalse(PostTriggerAction__mdt row, IF_Trigger.PostActionContext context)
	{
		if(String.isBlank(row.EntryCriteriaContextClassName__c))
		{
			return false;
		}
		IF_Trigger.PostActionEntryCriteria evaluator =
				(IF_Trigger.PostActionEntryCriteria)UTIL_System.getTypeForClassName(row.EntryCriteriaContextClassName__c).newInstance();
		return !evaluator.shouldRun(context);
	}

	/**
	 * @description Dispatches a single post-action row under a performance timer with the
	 * no-DML contract guard. The action class is instantiated as `IF_Trigger.PostAction`;
	 * a wrong-interface binding propagates as `TypeException`. After `execute(context)`
	 * returns, the DML statement counter is checked — if any DML occurred, a
	 * `PostActionDmlException` is thrown and routes through `handleFailure`, which
	 * always rethrows the DML exception regardless of `FailureAction__c` policy.
	 *
	 * @param row The post-action CMDT row.
	 * @param context The post-action context.
	 */
	private static void runOne(PostTriggerAction__mdt row, IF_Trigger.PostActionContext context)
	{
		IF_Trigger.PostAction action =
				(IF_Trigger.PostAction)UTIL_System.getTypeForClassName(row.ApexClassName__c).newInstance();
		UTIL_TriggerPerformanceTimer timer =
				new UTIL_TriggerPerformanceTimer(row.ApexClassName__c, OPERATION_LABEL, null, null);
		timer.withPostActionSettings(row);
		timer.start();
		try
		{
			Integer dmlStatementsBefore = Limits.getDmlStatements();
			action.execute(context);
			if(Limits.getDmlStatements() > dmlStatementsBefore)
			{
				throw new UTIL_Exceptions.PostActionDmlException(String.format(DML_VIOLATION_MESSAGE, new List<String> {row.ApexClassName__c}));
			}
		}
		catch(Exception caught)
		{
			handleFailure(caught, row);
		}
		finally
		{
			timer.stop();
		}
	}

	/**
	 * @description Routes a caught post-action exception. Always rethrows
	 * `LimitException`-style governor exhaustion (via `UTIL_Exceptions.isFatalGovernorError`)
	 * and always rethrows the framework's own `PostActionDmlException` (the no-DML
	 * contract is enforced regardless of policy). Other exceptions emit a structured
	 * log entry and apply `FailureAction__c` — `LogAndContinue` (default) returns
	 * normally; `BlockDml` rethrows so the originating DML rolls back.
	 *
	 * @param caught The unhandled exception thrown by the post-action.
	 * @param row The post-action CMDT row.
	 */
	private static void handleFailure(Exception caught, PostTriggerAction__mdt row)
	{
		if(UTIL_Exceptions.isFatalGovernorError(caught))
		{
			throw caught;
		}
		if(caught instanceof UTIL_Exceptions.PostActionDmlException)
		{
			throw caught;
		}
		String failureAction = String.isNotBlank(row.FailureAction__c)
				? row.FailureAction__c
				: SEL_TriggerAction.FAILURE_ACTION_LOG_AND_CONTINUE;
		LOG_Builder.build()
				.error(caught)
				.at(AT_LOCATION_HANDLE_FAILURE)
				.withContext(LOG_Engine.CONTEXT_EVENT_NAME, EVENT_NAME_POST_ACTION_FAILED)
				.withContext(LOG_Engine.CONTEXT_ACTION_CLASS_NAME, row.ApexClassName__c)
				.withContext(LOG_Engine.CONTEXT_ACTION_NAME, row.DeveloperName)
				.withContext(LOG_Engine.CONTEXT_FAILURE_ACTION, failureAction)
				.emit();
		if(failureAction == SEL_TriggerAction.FAILURE_ACTION_BLOCK_DML)
		{
			throw caught;
		}
	}
}