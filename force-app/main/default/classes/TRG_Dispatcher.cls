// SPDX-License-Identifier: Apache-2.0
/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @description Factory class for instantiating and executing configured trigger actions.
 * Manages the lifecycle of trigger actions and supports bypassing specific actions.
 * Adapted from: [Apex Trigger Actions Framework](https://github.com/mitchspano/apex-trigger-actions-framework/blob/master/README.md#metadata-driven-trigger-actions)
 *
 * @see TRG_Dispatcher_TEST
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, June 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * trigger TRG_Foobar on Foobar__c (before insert, before update)
 * {
 *     new TRG_Dispatcher().run();
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity')
global inherited sharing class TRG_Dispatcher
{
	/**
	 * @description Stack of action frames tracking the current trigger execution chain.
	 * Doubles as the outermost-unwind signal for the post-trigger-action hook: when `run()`
	 * finishes and `ACTION_STACK` is empty, the current dispatch is the outermost one and
	 * post-trigger actions fire. No separate depth counter is kept — the stack is the single
	 * source of truth for dispatch depth.
	 */
	private static final List<Object> ACTION_STACK = new List<Object>();

	/**
	 * @description Distinct `SObjectType`s whose triggers participated in the current
	 * transaction's dispatch chain. Each `run()` adds the dispatched object's type (when it
	 * resolves) before executing actions. At the outermost unwind the set is snapshotted into
	 * an `IF_Trigger.PostActionContext` and handed to `UTIL_PostTriggerAction.run`, then cleared.
	 *
	 * Clearing happens at every outermost unwind — including when a trigger action throws — so a
	 * later top-level DML in the same transaction (for example, an Apex caller that catches a
	 * `BlockDml` failure and continues) never inherits a stale touched-type set. Bounded by the
	 * distinct-SObject count, so its heap footprint is independent of `Trigger.new` size.
	 */
	private static final Set<SObjectType> TOUCHED_SOBJECT_TYPES = new Set<SObjectType>();

	/**
	 * @description Format string for the `TypeException` message surfaced by
	 * `assertActionImplementsInterface` when a configured action class does not implement the
	 * interface its trigger context requires. Placeholders: `{0}` the action class name,
	 * `{1}` the required interface, `{2}` the trigger operation, `{3}` the SObject name. The
	 * trailing sentence directs the admin to the `TriggerAction__mdt` configuration to correct it.
	 */
	private static final String INVALID_TYPE_ERROR = 'Action class "{0}" does not implement {1} as required for the {2} context on {3}. ' +
			'Verify the TriggerAction__mdt configuration.';

	/**
	 * @description Default Apex class name used when a TriggerAction row populates `FlowName__c`
	 * and leaves `ApexClassName__c` blank — the framework dispatches the row through the built-in
	 * flow runner. The MutuallyExclusiveTarget validation rule blocks rows that populate both.
	 */
	private static final String FLOW_ACTION_DEFAULT_CLASS = TRG_InvokeFlow.class.getName();

	/**
	 * @description Discrete event identifier emitted on the `eventName` context key when an
	 * action's unhandled exception is routed through `handleActionFailure`.
	 */
	private static final String EVENT_NAME_ACTION_FAILED = 'action.failed';

	/**
	 * @description Class+method location string used in `LOG_Builder.at(...)` calls inside
	 * `handleActionFailure`. Computed via `class.getName()` so the emitted `ClassMethod__c`
	 * is namespace-aware (`TRG_Dispatcher.dispatchAction` in unmanaged dev orgs /
	 * `kern.TRG_Dispatcher.dispatchAction` in managed subscriber installs) — matches the
	 * convention used across `LOG_Builder.at(...)` sites elsewhere in the framework so
	 * downstream diagnostic queries resolve cleanly in either context.
	 */
	private static final String AT_LOCATION_DISPATCH_ACTION = TRG_Dispatcher.class.getName() + '.dispatchAction';

	/**
	 * @description Override map for injecting trigger action metadata in tests.
	 */
	@TestVisible
	private Map<TriggerOperation, List<TriggerAction__mdt>> actionMetadataOverride;

	/**
	 * @description The current trigger operation type.
	 */
	@TestVisible
	private TriggerOperation context
	{
		get
		{
			if(context == null)
			{
				context = Trigger.operationType;
			}
			return context;
		}
		private set;
	}

	/**
	 * @description The list of "new" SObjects in the trigger context.
	 */
	@TestVisible
	private List<SObject> triggerNew
	{
		get
		{
			if(triggerNew == null)
			{
				triggerNew = Trigger.new;
			}
			return triggerNew;
		}
		private set;
	}

	/**
	 * @description The list of "old" SObjects in the trigger context.
	 */
	@TestVisible
	private List<SObject> triggerOld
	{
		get
		{
			if(triggerOld == null)
			{
				triggerOld = Trigger.old;
			}
			return triggerOld;
		}
		private set;
	}

	/**
	 * @description The API name of the SObject being processed.
	 */
	@TestVisible
	private String sObjectName
	{
		get
		{
			if(String.isBlank(sObjectName))
			{
				sObjectName = TRG_Base.resolveSObjectName(triggerNew, triggerOld);
			}
			return sObjectName;
		}
		private set;
	}

	/**
	 * @description Entry point for trigger execution. Reads the trigger context, checks bypass status,
	 * dispatches to configured trigger action handlers, and — at the outermost dispatch unwind — runs
	 * any configured post-trigger actions.
	 *
	 * **Post-trigger-action hook.** Each invocation records the dispatched object's `SObjectType` and,
	 * when the current dispatch is the outermost one (`ACTION_STACK` empty after action execution) and
	 * it completed without an unhandled exception, hands the accumulated touched-type set to
	 * `UTIL_PostTriggerAction.run`. Outermost detection reuses `ACTION_STACK` — a self-initiated DML
	 * that re-enters `run()` unwinds while the outer action frame is still on the stack, so only the
	 * true outermost unwind fires. A dispatch that is object-bypassed or that aborts via a throwing
	 * action does not fire post-actions (post-actions run only after the trigger-action chain
	 * completes). Because each trigger timing (before/after) is a separate top-level dispatch,
	 * post-actions can fire once per timing per DML operation; post-actions are expected to be
	 * idempotent or to gate on `touchedSObjectTypes`.
	 *
	 * @throws UTIL_Exceptions.ConfigurationException If a TriggerAction__mdt row reaches dispatch with both `ApexClassName__c` and `FlowName__c` blank.
	 * The `MutuallyExclusiveTarget` validation rule blocks this configuration at deploy time, so the path is reachable only via Tooling-API insertion that bypasses the VR.
	 * @throws UTIL_Exceptions.IllegalStateException If called outside of a trigger execution context.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * trigger TRG_Foobar on Foobar__c (before insert, before update)
	 * {
	 *     new TRG_Dispatcher().run();
	 * }
	 * ```
	 */
	global void run()
	{
		if(!Trigger.isExecuting && context == null)
		{
			throw new UTIL_Exceptions.IllegalStateException(TRG_Base.HANDLER_OUTSIDE_TRIGGER_MESSAGE);
		}

		if(TRG_Base.isBypassed(sObjectName))
		{
			return;
		}

		// Enter event-trigger context when dispatching a platform event / change event. While in it,
		// LOG_Engine persists logs to LogEntry__c via direct DML instead of publishing a
		// LogEntryEvent__e — publishing a platform event from inside a platform-event/change-event
		// trigger makes the platform redeliver the source event, re-running this dispatcher unbounded.
		// Only the outermost event dispatch enters (returns true); nested dispatches inherit it.
		Boolean enteredEventTriggerContext = LOG_Engine.beginEventTriggerContext(triggerNew);
		Boolean completedNormally = false;
		try
		{
			recordTouchedSObjectType();
			applyMaskingIfConfigured();
			executeActions(context, triggerNew, triggerOld);
			completedNormally = true;
		}
		finally
		{
			// Suppress the post-trigger-action hook for the framework's own LogEntryEvent__e
			// delivery. The hook runs SEL_PostTriggerAction.findActiveOrdered() at every outermost
			// unwind; because persisting a log entry is itself a dispatch, running the hook on each
			// delivered log event re-enters the dispatcher and — should the hook path emit a further
			// log event — can self-feed a logging cascade. Log persistence is internal plumbing:
			// logic that must run when a log row is persisted belongs in a TriggerAction__mdt, not a
			// transaction-scoped post-trigger action.
			Boolean isFrameworkLoggingEvent = triggerNew != null && !triggerNew.isEmpty()
					&& triggerNew[0].getSObjectType() == LogEntryEvent__e.SObjectType;
			if(!isFrameworkLoggingEvent)
			{
				dispatchPostActionsAtOutermostUnwind(completedNormally);
			}
			// Flush in-context logs via DML and exit event-trigger context AFTER the post-action
			// hook, so any logs the hook emits are captured by the same direct-DML persist.
			if(enteredEventTriggerContext)
			{
				LOG_Engine.endEventTriggerContext();
			}
		}
	}

	/**
	 * @description Records the dispatched object's `SObjectType` in `TOUCHED_SOBJECT_TYPES` so the
	 * outermost-unwind hook can report which objects' triggers participated in the transaction. The
	 * name is resolved through `UTIL_SObjectDescribe.getSObjectTypeByName`, which returns null for a
	 * name that is not in the global describe (for example, a Platform-Event or Change-Data-Capture
	 * entity that does not resolve to a queryable `SObjectType`). A null resolution is dropped
	 * fail-soft: a post-action scoped to that object simply sees nothing for it.
	 */
	private void recordTouchedSObjectType()
	{
		SObjectType currentType = UTIL_SObjectDescribe.getSObjectTypeByName(sObjectName);
		if(currentType != null)
		{
			TOUCHED_SOBJECT_TYPES.add(currentType);
		}
	}

	/**
	 * @description Runs the post-trigger-action hook when the current dispatch is the outermost one.
	 * Called from `run()`'s `finally` so the touched-type set is cleared on every outermost unwind —
	 * including an aborted dispatch — preventing a stale set from leaking into a later top-level DML.
	 * Post-actions themselves fire only when the dispatch completed normally; an aborted dispatch
	 * clears state but runs no post-action (post-actions run after the action chain completes, and
	 * must never replace the in-flight exception that aborted it).
	 *
	 * When the current dispatch is not the outermost (a nested re-entrant dispatch, signalled by a
	 * non-empty `ACTION_STACK`), this is a no-op — the outer dispatch owns the hook.
	 *
	 * @param completedNormally `true` when `run()`'s action execution completed without an unhandled exception.
	 */
	private static void dispatchPostActionsAtOutermostUnwind(Boolean completedNormally)
	{
		if(!ACTION_STACK.isEmpty())
		{
			return;
		}
		Set<SObjectType> snapshot = new Set<SObjectType>(TOUCHED_SOBJECT_TYPES);
		TOUCHED_SOBJECT_TYPES.clear();
		if(completedNormally)
		{
			UTIL_PostTriggerAction.run(new IF_Trigger.PostActionContext(snapshot));
		}
	}

	/**
	 * @description Runs the data masking framework against `Trigger.new` when all three
	 * gates pass: the operation is before-insert or before-update, the `MaskingFramework_Enabled`
	 * feature flag is on, and the object's `TriggerSetting__mdt.ApplyMasking__c` is checked.
	 * Masking happens as a pre-step — before any configured `TriggerAction__mdt` handlers run —
	 * so subsequent actions see the redacted records. A `UTIL_MaskerPerformanceTimer` times
	 * the run and auto-emits a single aggregate log entry when `LogSetting__c.EnableMaskerPerformanceLogging__c`
	 * is on and elapsed meets or exceeds the configured threshold. Logging defaults off so
	 * subscribers pay zero log volume by default.
	 */
	private void applyMaskingIfConfigured()
	{
		if(context != TriggerOperation.BEFORE_INSERT && context != TriggerOperation.BEFORE_UPDATE)
		{
			return;
		}
		if(!UTIL_FrameworkMasker.isMaskingEnabled)
		{
			return;
		}
		if(!SEL_TriggerAction.shouldApplyMaskingFor(sObjectName))
		{
			return;
		}

		UTIL_MaskerPerformanceTimer timer = new UTIL_MaskerPerformanceTimer(sObjectName, triggerNew.size());
		timer.start();
		UTIL_FrameworkMasker.forRecords(triggerNew).apply();
		timer.stop();
	}

	/**
	 * @description Executes configured trigger actions for the current context and object.
	 *
	 * @param context The current trigger operation (e.g., BEFORE_INSERT, AFTER_UPDATE).
	 * @param newRecords The list of new or updated records.
	 * @param oldRecords The list of previous or deleted records.
	 */
	private void executeActions(TriggerOperation context, List<SObject> newRecords, List<SObject> oldRecords)
	{
		for(TriggerAction__mdt triggerMetadata : getActionMetadata(context))
		{
			String className = resolveClassName(triggerMetadata);
			if(TRG_Base.isActionBypassed(className) || TRG_Base.isBypassed(sObjectName))
			{
				continue;
			}
			executeAction(context, triggerMetadata, className, newRecords, oldRecords);
		}
	}

	/**
	 * @description Resolves the effective Apex class name for a TriggerAction row. Returns the
	 * configured `ApexClassName__c` when populated; otherwise defaults to `TRG_InvokeFlow` when
	 * `FlowName__c` is populated (the framework's built-in flow runner). The MutuallyExclusiveTarget
	 * validation rule on `TriggerAction__mdt` blocks rows that populate both fields or neither, so
	 * production callers can rely on exactly one branch matching at deploy time.
	 *
	 * @param triggerMetadata The active TriggerAction__mdt row.
	 *
	 * @return The Apex class name the dispatcher should resolve and instantiate.
	 */
	private static String resolveClassName(TriggerAction__mdt triggerMetadata)
	{
		if(String.isNotBlank(triggerMetadata.ApexClassName__c))
		{
			return triggerMetadata.ApexClassName__c;
		}
		if(String.isNotBlank(triggerMetadata.FlowName__c))
		{
			return FLOW_ACTION_DEFAULT_CLASS;
		}
		throw new UTIL_Exceptions.ConfigurationException
				(
						'TriggerAction "' + triggerMetadata.DeveloperName + '" must populate either ApexClassName__c or FlowName__c.'
				);
	}

	/**
	 * @description Executes a single configured trigger action. Resolves the action class,
	 * applies the `IF_Trigger.Configurable` hook, manages the recursion stack frame, and
	 * dispatches under the entry-criteria filter and performance timer.
	 *
	 * Extracted from `executeActions` to keep that method's cognitive complexity bounded;
	 * the for-loop is the natural unit to keep there.
	 *
	 * @param context The current trigger operation.
	 * @param triggerMetadata The active TriggerAction__mdt configuration.
	 * @param className The Apex class name resolved from `triggerMetadata` by the caller.
	 * @param newRecords The list of new or updated records.
	 * @param oldRecords The list of previous or deleted records.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private void executeAction
			(
					TriggerOperation context,
					TriggerAction__mdt triggerMetadata,
					String className,
					List<SObject> newRecords,
					List<SObject> oldRecords
			)
	{
		Type actionType = UTIL_System.getTypeForClassName(className);
		Object triggerAction = actionType.newInstance();
		Boolean isConfigurable = triggerAction instanceof IF_Trigger.Configurable;
		if(isConfigurable)
		{
			((IF_Trigger.Configurable)triggerAction).setConfig(triggerMetadata);
		}
		assertActionImplementsInterface(context, triggerAction, className);
		String fingerprint = isConfigurable ? triggerMetadata.DeveloperName : null;
		ACTION_STACK.add(new ActionStackFrame(actionType, fingerprint));
		try
		{
			if(canExecuteAction(actionType, fingerprint, triggerMetadata))
			{
				dispatchUnderTimer(context, triggerAction, triggerMetadata, className, newRecords, oldRecords);
			}
		}
		finally
		{
			ACTION_STACK.remove(ACTION_STACK.size() - 1);
		}
	}

	/**
	 * @description Combines the recursion-shield and self-initiated guards that gate dispatch.
	 *
	 * @param actionType The action's resolved Apex Type.
	 * @param fingerprint The recursion fingerprint (DeveloperName for Configurable actions, null otherwise).
	 * @param triggerMetadata The active TriggerAction__mdt row.
	 *
	 * @return `true` when the dispatch should proceed.
	 */
	private static Boolean canExecuteAction(Type actionType, String fingerprint, TriggerAction__mdt triggerMetadata)
	{
		Boolean recursionAllowed = triggerMetadata.AllowRecursion__c || !inRecursion(actionType, fingerprint);
		Boolean cascadeAllowed = triggerMetadata.AllowNonSelfInitiated__c || selfInitiated(actionType);
		return recursionAllowed && cascadeAllowed;
	}

	/**
	 * @description Wraps the entry-criteria filter and performance timer around the dispatch call.
	 *
	 * @param context The current trigger operation.
	 * @param triggerAction The instantiated trigger action.
	 * @param triggerMetadata The active TriggerAction__mdt row.
	 * @param className The action's class name.
	 * @param newRecords The list of new or updated records.
	 * @param oldRecords The list of previous or deleted records.
	 */
	// Suppressed because: thin orchestration shim wires together six dispatch primitives (context,
	// action, metadata, className, newRecords, oldRecords) that come from different origins in the
	// caller; bundling them upstream would propagate the wide-arg shape further from the caller.
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private void dispatchUnderTimer
			(
					TriggerOperation context,
					Object triggerAction,
					TriggerAction__mdt triggerMetadata,
					String className,
					List<SObject> newRecords,
					List<SObject> oldRecords
			)
	{
		String contextClassName = UTIL_FormulaFilter.resolveContextClass(sObjectName, triggerMetadata.EntryCriteriaContextClassName__c);
		UTIL_FormulaFilter formulaFilter = new UTIL_FormulaFilter(className, contextClassName, triggerMetadata.EntryCriteriaFormula__c);
		UTIL_FormulaFilter.DTO_FilterResults filterResults = formulaFilter.filter(oldRecords, newRecords);

		Integer recordCount = filterResults.newRecords?.size() ?? filterResults.oldRecords?.size() ?? 0;
		UTIL_TriggerPerformanceTimer timer = new UTIL_TriggerPerformanceTimer(className, context.name(), sObjectName, recordCount);
		timer.withActionSettings(triggerMetadata);

		timer.start();
		try
		{
			dispatchAction(context, triggerAction, filterResults.newRecords, filterResults.oldRecords);
		}
		catch(Exception caught)
		{
			handleActionFailure(caught, triggerMetadata, className, context);
		}
		finally
		{
			timer.stop();
		}
	}

	/**
	 * @description Routes an unhandled action exception through the row's `FailureAction__c`
	 * policy. Governor-level exceptions (`System.LimitException`) always rethrow regardless
	 * of policy — exhaustion is never swallowed. For all other exceptions:
	 *
	 * - `BlockDml` rethrows so the DML rolls back and the original error surfaces.
	 * - `LogAndContinue` (default) emits a structured `LogEntryEvent__e` via `LOG_Builder`
	 *   and lets DML proceed.
	 *
	 * Flow actions (`TRG_InvokeFlow`) catch their own per-record runtime exceptions internally
	 * and apply per-record `FailureAction` policy there; the dispatcher catch fires for that
	 * action only on fatal governor blow rethrows or framework bugs.
	 *
	 * @param caught The unhandled exception thrown by the action.
	 * @param triggerMetadata The active TriggerAction__mdt row.
	 * @param className The resolved class name driving the action.
	 * @param context The current trigger operation.
	 */
	private static void handleActionFailure(Exception caught, TriggerAction__mdt triggerMetadata, String className, TriggerOperation context)
	{
		if(UTIL_Exceptions.isFatalGovernorError(caught))
		{
			throw caught;
		}
		String failureAction = String.isNotBlank(triggerMetadata.FailureAction__c) ?
				triggerMetadata.FailureAction__c : SEL_TriggerAction.FAILURE_ACTION_LOG_AND_CONTINUE;
		LOG_Builder.build()
				.error(caught)
				.at(AT_LOCATION_DISPATCH_ACTION)
				.withContext(LOG_Engine.CONTEXT_EVENT_NAME, EVENT_NAME_ACTION_FAILED)
				.withContext(LOG_Engine.CONTEXT_ACTION_CLASS_NAME, className)
				.withContext(LOG_Engine.CONTEXT_ACTION_NAME, triggerMetadata.DeveloperName)
				.withContext(LOG_Engine.CONTEXT_TRIGGER_OPERATION, context?.name())
				.withContext(LOG_Engine.CONTEXT_FAILURE_ACTION, failureAction)
				.emit();
		if(failureAction == SEL_TriggerAction.FAILURE_ACTION_BLOCK_DML)
		{
			throw caught;
		}
	}

	/**
	 * @description Casts the trigger action to the appropriate interface for the given context
	 * and invokes the corresponding handler method.
	 *
	 * @param operation The current trigger operation.
	 * @param triggerAction The action to dispatch.
	 * @param newRecords The list of new or updated records.
	 * @param oldRecords The list of previous or deleted records.
	 */
	private static void dispatchAction(TriggerOperation operation, Object triggerAction, List<SObject> newRecords, List<SObject> oldRecords)
	{
		switch on operation
		{
			when BEFORE_INSERT
			{
				((IF_Trigger.BeforeInsert)triggerAction).beforeInsert(newRecords);
			}
			when AFTER_INSERT
			{
				((IF_Trigger.AfterInsert)triggerAction).afterInsert(newRecords);
			}
			when BEFORE_UPDATE
			{
				((IF_Trigger.BeforeUpdate)triggerAction).beforeUpdate(newRecords, oldRecords);
			}
			when AFTER_UPDATE
			{
				((IF_Trigger.AfterUpdate)triggerAction).afterUpdate(newRecords, oldRecords);
			}
			when BEFORE_DELETE
			{
				((IF_Trigger.BeforeDelete)triggerAction).beforeDelete(oldRecords);
			}
			when AFTER_DELETE
			{
				((IF_Trigger.AfterDelete)triggerAction).afterDelete(oldRecords);
			}
			when AFTER_UNDELETE
			{
				((IF_Trigger.AfterUndelete)triggerAction).afterUndelete(newRecords);
			}
		}
	}

	/**
	 * @description Retrieves trigger action metadata for the given trigger context.
	 * Uses the test override map if available, otherwise queries via SEL_TriggerAction.
	 *
	 * @param triggerContext The current trigger context.
	 *
	 * @return A list of `TriggerAction__mdt` records.
	 */
	private List<TriggerAction__mdt> getActionMetadata(TriggerOperation triggerContext)
	{
		if(actionMetadataOverride != null)
		{
			return actionMetadataOverride.get(triggerContext) ?? new List<TriggerAction__mdt>();
		}
		return SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation(sObjectName, triggerContext);
	}

	/**
	 * @description Determines whether the given (actionType, fingerprint) pair already appears
	 * more than once on the execution stack, indicating a recursive trigger invocation. The
	 * fingerprint discriminates between two `TriggerAction__mdt` rows that point at the same
	 * `Configurable` action class (e.g., two flow-action rows): each row is its own logical
	 * action and must execute independently. Non-`Configurable` actions pass `null` and the
	 * `(actionType, null)` tuple matches today's actionType-only behaviour exactly.
	 *
	 * @param actionClassType The class type of the action to check.
	 * @param fingerprint The TriggerAction__mdt DeveloperName for `Configurable` actions, otherwise null.
	 *
	 * @return `true` if a second occurrence is found on the stack, `false` otherwise.
	 */
	private static Boolean inRecursion(Type actionClassType, String fingerprint)
	{
		Integer occurrences = 0;
		for(Object frame : ACTION_STACK)
		{
			ActionStackFrame stackFrame = (ActionStackFrame)frame;
			if(stackFrame.actionType == actionClassType && fingerprintsMatch(stackFrame.fingerprint, fingerprint) && ++occurrences > 1)
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * @description Null-safe fingerprint comparator. Two null fingerprints match (legacy
	 * non-Configurable actions); two equal non-null fingerprints match (same CMDT row repeated
	 * by self-initiated DML); a null/non-null mix never matches (different rows).
	 *
	 * The mixed-null branch is unreachable from production dispatch (`inRecursion` short-circuits
	 * via `actionType ==` before this runs, and frames sharing `actionType` share fingerprint
	 * nullity because nullity is class-determined by `instanceof IF_Trigger.Configurable`), but
	 * is exposed `@TestVisible` so the truth table can be exercised directly for coverage.
	 *
	 * @param leftFingerprint One fingerprint string (may be null).
	 * @param rightFingerprint The other fingerprint string (may be null).
	 *
	 * @return `true` if both null or both equal, `false` otherwise.
	 */
	@TestVisible
	private static Boolean fingerprintsMatch(String leftFingerprint, String rightFingerprint)
	{
		if(leftFingerprint == null && rightFingerprint == null)
		{
			return true;
		}
		if(leftFingerprint == null || rightFingerprint == null)
		{
			return false;
		}
		return leftFingerprint == rightFingerprint;
	}

	/**
	 * @description Checks whether the current action is the same type as the handler
	 * at the root of the execution stack, indicating the DML was self-initiated.
	 *
	 * @param handlerType The class type of the action to check.
	 *
	 * @return `true` if the stack is empty or the root frame matches the given type, `false` otherwise.
	 */
	private static Boolean selfInitiated(Type handlerType)
	{
		return ACTION_STACK.isEmpty() || ((ActionStackFrame)ACTION_STACK.get(0)).actionType == handlerType;
	}

	/**
	 * @description Asserts that the trigger action object implements the interface required
	 * for the given trigger operation. Throws a TypeException with a diagnostic message
	 * if the action is not assignable to the expected interface.
	 *
	 * @param operation The trigger operation context.
	 * @param triggerAction The action instance to validate.
	 * @param className The class name of the action (for error reporting).
	 */
	// Suppressed because: each cast inside the switch is intentionally not assigned — the cast
	// throws TypeException when the action does not implement the expected interface, which the
	// catch translates into a structured INVALID_TYPE_ERROR for diagnostic surfacing.
	@SuppressWarnings('ApexUnnecessaryCast')
	private void assertActionImplementsInterface(TriggerOperation operation, Object triggerAction, String className)
	{
		try
		{
			switch on operation
			{
				when BEFORE_INSERT
				{
					triggerAction = (IF_Trigger.BeforeInsert)triggerAction;
				}
				when AFTER_INSERT
				{
					triggerAction = (IF_Trigger.AfterInsert)triggerAction;
				}
				when BEFORE_UPDATE
				{
					triggerAction = (IF_Trigger.BeforeUpdate)triggerAction;
				}
				when AFTER_UPDATE
				{
					triggerAction = (IF_Trigger.AfterUpdate)triggerAction;
				}
				when BEFORE_DELETE
				{
					triggerAction = (IF_Trigger.BeforeDelete)triggerAction;
				}
				when AFTER_DELETE
				{
					triggerAction = (IF_Trigger.AfterDelete)triggerAction;
				}
				when AFTER_UNDELETE
				{
					triggerAction = (IF_Trigger.AfterUndelete)triggerAction;
				}
			}
		}
		catch(TypeException error)
		{
			Type requiredInterface = TRG_Base.HANDLER_INTERFACES.get(operation);
			error.setMessage(String.format(INVALID_TYPE_ERROR, new List<Object> {className, requiredInterface.getName(), operation, sObjectName}));
			LOG_Builder.build().error(error).at(TRG_Dispatcher.class.getName() + '/assertActionImplementsInterface').emit();
			throw error;
		}
	}

	/**
	 * @description Represents a single frame on the trigger action execution stack,
	 * capturing the resolved type of the action being processed plus an optional
	 * fingerprint that discriminates between multiple `TriggerAction__mdt` rows that
	 * resolve to the same `Configurable` action class.
	 */
	private class ActionStackFrame
	{
		/**
		 * @description The resolved Apex type of the trigger action class.
		 */
		private final Type actionType;
		/**
		 * @description The TriggerAction__mdt DeveloperName when the action implements
		 * `IF_Trigger.Configurable`, otherwise null. Together with `actionType` forms
		 * the recursion-identity tuple used by `inRecursion`.
		 */
		private final String fingerprint;

		/**
		 * @description Creates a stack frame for the given action type and fingerprint.
		 *
		 * @param actionType The resolved Apex type of the trigger action class.
		 * @param fingerprint The TriggerAction__mdt DeveloperName for `Configurable` actions, otherwise null.
		 */
		private ActionStackFrame(Type actionType, String fingerprint)
		{
			this.actionType = actionType;
			this.fingerprint = fingerprint;
		}
	}
}