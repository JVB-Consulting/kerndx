// SPDX-License-Identifier: Apache-2.0
/**
 * @description Runs `PostTriggerAction__mdt`-configured post-trigger actions at the
 * outermost dispatch unwind, in `Order__c` ascending. Each row is gated through three
 * cheap-first filters before the action is instantiated:
 *
 * 1. Feature-flag gate (`BypassFeatureFlag__c` / `RequiredFeatureFlag__c`)
 * 2. Optional `TriggerSetting__c` scope filter: when it is set, the object of the linked
 *    setting must appear in the dispatch's `touchedSObjectTypes`
 * 3. Optional Apex entry-criteria evaluator (`EntryCriteriaContextClassName__c`)
 *
 * Rows that survive the gates are dispatched under a per-row performance timer
 * with a no-DML contract guard. The guard discounts the logging framework's own
 * log persistence (inside a platform-event / change-event trigger dispatch,
 * `LOG_Engine` persists via direct DML instead of publishing), so post-actions can
 * log, as their contract allows, without being blamed for the engine's DML.
 * Action exceptions route through `FailureAction__c`
 * policy (`LogAndContinue` or `BlockDml`); `LimitException` and the no-DML guard's
 * own `PostActionDmlException` always rethrow regardless of policy.
 *
 * A static `isRunning` guard prevents recursion if a post-action triggers DML that
 * itself fires more triggers: the inner dispatch returns immediately on re-entry.
 *
 * @see TRG_Dispatcher
 * @see SEL_PostTriggerAction
 * @see SEL_TriggerAction
 * @see PostTriggerAction__mdt
 * @see IF_Trigger.PostAction
 * @see IF_Trigger.PostActionEntryCriteria
 * @see IF_Trigger.PostActionContext
 * @see LOG_Engine
 * @see UTIL_PostTriggerAction_TEST
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date May 2026, November 2026
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
	 * @description Skips a row that is limited to one trigger setting when that setting's object did not take part
	 * in the transaction. A row with no `TriggerSetting__c` is not limited to one object, so it always goes on. A row
	 * with a setting goes on only when the setting's object (see resolveSettingObjectName) is in the dispatch's
	 * `touchedSObjectTypes`. A row is also skipped, without an error, when its setting names no object or names one
	 * that `UTIL_SObjectDescribe` cannot find.
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
		String parentSObjectName = resolveSettingObjectName(row.TriggerSetting__r);
		if(String.isBlank(parentSObjectName))
		{
			return true;
		}
		Schema.SObjectType parentType = UTIL_SObjectDescribe.getSObjectTypeByName(parentSObjectName);
		return parentType == null || !context.touchedSObjectTypes.contains(parentType);
	}

	/**
	 * @description Works out the API name of the object a trigger setting is for. A name typed in
	 * `ObjectApiNameOverride__c` comes first: a setting for a change event (for example a Change Data Capture event)
	 * names its object there, because `SObjectType__c` cannot point to a change event. Next it reads
	 * `SObjectType__r.QualifiedApiName` when the query filled it in. For a custom object this is the only place that
	 * holds the name, because `SObjectType__c` holds the object's record id (it starts with `01I`). When the
	 * relationship is empty, as on a setting a test builds in memory, it falls back to `SObjectType__c`, which then
	 * holds the name. `SEL_TriggerAction` reads a trigger setting's object in the same order. The typed name is
	 * returned as the admin typed it: the caller looks it up with `UTIL_SObjectDescribe.getSObjectTypeByName`, which
	 * ignores letter case. That is the same lookup `SEL_TriggerAction` uses to correct the case of a typed name.
	 *
	 * @param setting The trigger setting linked to the post-action row, or null.
	 *
	 * @return The object API name, or null when the setting is null or names no object.
	 */
	private static String resolveSettingObjectName(TriggerSetting__mdt setting)
	{
		String typedObjectName = setting?.ObjectApiNameOverride__c;
		if(String.isNotBlank(typedObjectName))
		{
			return typedObjectName;
		}
		return setting?.SObjectType__r?.QualifiedApiName ?? setting?.SObjectType__c;
	}

	/**
	 * @description Apex entry-criteria evaluator. When `EntryCriteriaContextClassName__c`
	 * is blank the row proceeds. When set, the named class is instantiated as an
	 * `IF_Trigger.PostActionEntryCriteria` and its `shouldRun(context)` is consulted:
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
	 * no-DML contract guard. The timer takes the row's performance settings and the threshold of the row's trigger
	 * setting; a row with no trigger setting gives no threshold. The action class is instantiated as `IF_Trigger.PostAction`;
	 * a wrong-interface binding propagates as `TypeException`. After `execute(context)`
	 * returns, the DML statement counter is checked — if any DML occurred, a
	 * `PostActionDmlException` is thrown and routes through `handleFailure`, which
	 * always rethrows the DML exception regardless of `FailureAction__c` policy.
	 *
	 * The guard discounts the logging framework's own persistence: inside a platform-event /
	 * change-event trigger dispatch `LOG_Engine` persists log entries via direct DML instead of
	 * publishing (an ERROR-level emit, or an emit that crosses the engine's buffer cap, flushes
	 * synchronously), so a post-action that merely logs — the documented contract — must not be
	 * blamed for the engine's DML. `LOG_Engine.getFrameworkLogPersistenceDmlStatements()` is
	 * sampled around `execute(context)` and its delta subtracted from the measured statements;
	 * DML the post-action performs itself always still counts.
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
		timer.withPostActionSettings(row).withTriggerSettingThreshold(row.TriggerSetting__r?.PerformanceThresholdMs__c);
		timer.start();
		try
		{
			Integer dmlStatementsBefore = UTIL_Limits.dmlStatements().used();
			Integer frameworkLogDmlStatementsBefore = LOG_Engine.getFrameworkLogPersistenceDmlStatements();
			action.execute(context);
			Integer frameworkLogDmlStatementsDuringAction = LOG_Engine.getFrameworkLogPersistenceDmlStatements() - frameworkLogDmlStatementsBefore;
			if(UTIL_Limits.dmlStatements().used() - frameworkLogDmlStatementsDuringAction > dmlStatementsBefore)
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