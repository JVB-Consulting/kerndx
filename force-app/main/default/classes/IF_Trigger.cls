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
 * @description Contracts for metadata-driven trigger action handlers. Each nested interface
 * corresponds to a Salesforce trigger event and defines the callback signature that
 * handler classes must implement. Handlers extend TRG_Base and declare the interfaces
 * matching the events they handle; the TRG_Dispatcher invokes the correct callback
 * at runtime based on TriggerAction__mdt configuration.
 * Adapted from: [apex-trigger-actions-framework](https://github.com/mitchspano/apex-trigger-actions-framework/blob/master/README.md#metadata-driven-trigger-actions)
 *
 * @see TRG_Base
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * public class TRG_SetDefaults extends TRG_Base implements IF_Trigger.BeforeInsert
 * {
 *     public void beforeInsert(List<SObject> newRecords)
 *     {
 *         for(SObject record : newRecords)
 *         {
 *             record.put('Status__c', 'New');
 *         }
 *     }
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class IF_Trigger
{
	/**
	 * @description Optional contract for data-driven trigger actions whose behaviour is configured
	 * by their `TriggerAction__mdt` row (FlowName, mode, failure strategy, etc.). Implementing
	 * classes are handed their active metadata record once per dispatch via `setConfig`, after
	 * `newInstance()` and before the trigger-context interface method (`beforeInsert`, etc.).
	 * Non-`Configurable` actions are unaffected — the dispatcher only invokes the hook when an
	 * action explicitly implements this interface.
	 *
	 * Subscriber implementers should be aware of Salesforce known issue
	 * a028c00000qPwkPAAS: `instanceof` may fail for classes installed across two different
	 * managed packages. If a subscriber installs both KernDX and a second managed package whose
	 * action class implements `kern.IF_Trigger.Configurable`, the dispatcher's `instanceof`
	 * check could silently miss `setConfig` calls. Mitigation: subscriber implementers in a
	 * managed-package context should validate the integration against a release-test that
	 * inserts a record and asserts `setConfig` fired before relying on it.
	 *
	 * @since 1.0
	 */
	public interface Configurable
	{
		/**
		 * @description Called exactly once by `TRG_Dispatcher` between `newInstance()` and the
		 * trigger-context interface method, per `TriggerAction__mdt` row. Lets a data-driven
		 * action read its configuration before the trigger callback fires.
		 *
		 * @param config The active TriggerAction__mdt record for this dispatch.
		 *
		 * @since 1.0
		 */
		void setConfig(TriggerAction__mdt config);
	}

	/**
	 * @description Handler contract for the before-insert trigger event.
	 *
	 * @since 1.0
	 */
	global interface BeforeInsert
	{
		/**
		 * @description Called before records are committed to the database, allowing
		 * field defaulting, validation, or in-memory enrichment of the incoming batch.
		 *
		 * @param newRecords The batch of SObjects about to be inserted.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * public class TRG_SetAccountDefaults extends TRG_Base implements IF_Trigger.BeforeInsert
		 * {
		 *     public void beforeInsert(List<SObject> newRecords)
		 *     {
		 *         for(SObject record : newRecords)
		 *         {
		 *             record.put('Status__c', 'Draft');
		 *         }
		 *     }
		 * }
		 * ```
		 */
		void beforeInsert(List<SObject> newRecords);
	}

	/**
	 * @description Handler contract for the after-insert trigger event.
	 *
	 * @since 1.0
	 */
	global interface AfterInsert
	{
		/**
		 * @description Called after records have been inserted and assigned IDs, enabling
		 * cross-object updates, platform event publishing, or asynchronous follow-up work.
		 *
		 * @param newRecords The batch of SObjects that were inserted (with IDs populated).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * public class TRG_PublishAccountEvent extends TRG_Base implements IF_Trigger.AfterInsert
		 * {
		 *     public void afterInsert(List<SObject> newRecords)
		 *     {
		 *         for(SObject record : newRecords)
		 *         {
		 *             LOG_Builder.build().info('Created ' + record.Id).emitAt('TRG_PublishAccountEvent');
		 *         }
		 *     }
		 * }
		 * ```
		 */
		void afterInsert(List<SObject> newRecords);
	}

	/**
	 * @description Handler contract for the before-update trigger event.
	 *
	 * @since 1.0
	 */
	global interface BeforeUpdate
	{
		/**
		 * @description Called before modified records are saved, enabling field-level
		 * validation, change detection, or in-memory transformations using old and new state.
		 *
		 * @param newRecords The batch of SObjects with their proposed field values.
		 * @param oldRecords The batch of SObjects with their values prior to the update.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * public class TRG_TrackStatusChange extends TRG_Base implements IF_Trigger.BeforeUpdate
		 * {
		 *     public void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords)
		 *     {
		 *         for(Integer i = 0; i < newRecords.size(); i++)
		 *         {
		 *             if(newRecords[i].get('Status__c') != oldRecords[i].get('Status__c'))
		 *             {
		 *                 newRecords[i].put('StatusChangedDate__c', System.now());
		 *             }
		 *         }
		 *     }
		 * }
		 * ```
		 */
		void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords);
	}

	/**
	 * @description Handler contract for the after-update trigger event.
	 *
	 * @since 1.0
	 */
	global interface AfterUpdate
	{
		/**
		 * @description Called after records have been updated and committed, enabling
		 * cascading updates to related objects, notifications, or audit trail entries.
		 *
		 * @param newRecords The batch of SObjects with their committed field values.
		 * @param oldRecords The batch of SObjects with their values prior to the update.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * public class TRG_SyncAccountToExternal extends TRG_Base implements IF_Trigger.AfterUpdate
		 * {
		 *     public void afterUpdate(List<SObject> newRecords, List<SObject> oldRecords)
		 *     {
		 *         for(Integer i = 0; i < newRecords.size(); i++)
		 *         {
		 *             if(newRecords[i].get('Name') != oldRecords[i].get('Name'))
		 *             {
		 *                 LOG_Builder.build().info('Name changed').emitAt('TRG_SyncAccountToExternal');
		 *             }
		 *         }
		 *     }
		 * }
		 * ```
		 */
		void afterUpdate(List<SObject> newRecords, List<SObject> oldRecords);
	}

	/**
	 * @description Handler contract for the before-delete trigger event.
	 *
	 * @since 1.0
	 */
	global interface BeforeDelete
	{
		/**
		 * @description Called before records are removed from the database, enabling
		 * deletion guards, referential integrity checks, or pre-delete archival logic.
		 *
		 * @param oldRecords The batch of SObjects about to be deleted.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * public class TRG_PreventProtectedDelete extends TRG_Base implements IF_Trigger.BeforeDelete
		 * {
		 *     public void beforeDelete(List<SObject> oldRecords)
		 *     {
		 *         for(SObject record : oldRecords)
		 *         {
		 *             if((Boolean)record.get('IsProtected__c') == true)
		 *             {
		 *                 record.addError('Protected records cannot be deleted');
		 *             }
		 *         }
		 *     }
		 * }
		 * ```
		 */
		void beforeDelete(List<SObject> oldRecords);
	}

	/**
	 * @description Handler contract for the after-delete trigger event.
	 *
	 * @since 1.0
	 */
	global interface AfterDelete
	{
		/**
		 * @description Called after records have been deleted, enabling cleanup of
		 * orphaned child records, external system notifications, or aggregate recalculation.
		 *
		 * @param oldRecords The batch of SObjects that were deleted.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * public class TRG_CleanupOrphanedFiles extends TRG_Base implements IF_Trigger.AfterDelete
		 * {
		 *     public void afterDelete(List<SObject> oldRecords)
		 *     {
		 *         Set<Id> deletedIds = new Map<Id, SObject>(oldRecords).keySet();
		 *         LOG_Builder.build().info('Cleaned up ' + deletedIds.size() + ' records').emitAt('TRG_CleanupOrphanedFiles');
		 *     }
		 * }
		 * ```
		 */
		void afterDelete(List<SObject> oldRecords);
	}

	/**
	 * @description Handler contract for the after-undelete trigger event.
	 *
	 * @since 1.0
	 */
	global interface AfterUndelete
	{
		/**
		 * @description Called after records have been restored from the Recycle Bin,
		 * enabling re-linking of relationships, reactivation of dependent processes,
		 * or synchronisation with external systems.
		 *
		 * @param newRecords The batch of SObjects that were restored.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * public class TRG_RestoreRelatedData extends TRG_Base implements IF_Trigger.AfterUndelete
		 * {
		 *     public void afterUndelete(List<SObject> newRecords)
		 *     {
		 *         for(SObject record : newRecords)
		 *         {
		 *             LOG_Builder.build().info('Restored ' + record.Id).emitAt('TRG_RestoreRelatedData');
		 *         }
		 *     }
		 * }
		 * ```
		 */
		void afterUndelete(List<SObject> newRecords);
	}

	/**
	 * @description Handler contract for a post-trigger action — an Apex class that runs
	 * exactly once at the end of a trigger transaction, after every trigger action on every
	 * touched SObject has completed. Use for cross-object or transaction-scoped work that
	 * cannot be done from inside an individual trigger action: audit aggregation, asynchronous
	 * job enqueue, transaction-wide telemetry. DML is contractually prohibited — the framework
	 * throws if a post-trigger action performs DML, regardless of the row's FailureAction
	 * setting.
	 *
	 * Registered via `PostTriggerAction__mdt`. The framework fires post-actions at the
	 * outermost dispatch unwind, in `Order__c` ascending. Optional gates apply in order:
	 * BypassExecution → BypassFeatureFlag / RequiredFeatureFlag → TriggerSetting scope →
	 * EntryCriteriaContextClassName.
	 *
	 * @since 1.1
	 */
	global interface PostAction
	{
		/**
		 * @description Called once per outermost dispatch with the context of touched
		 * SObject types. Implementations should be idempotent within a single transaction —
		 * a transaction with N top-level DML statements fires post-actions N times.
		 *
		 * @param context The post-action context for this dispatch. Carries the set of
		 * SObject types whose triggers participated in the transaction.
		 *
		 * @since 1.1
		 *
		 * @example
		 * ```apex
		 * public class TRG_EmitTransactionAudit implements IF_Trigger.PostAction
		 * {
		 *     public void execute(IF_Trigger.PostActionContext context)
		 *     {
		 *         if(context.touchedSObjectTypes.isEmpty()) return;
		 *         LOG_Builder.build()
		 *             .info('Transaction touched ' + context.touchedSObjectTypes.size() + ' SObject(s)')
		 *             .emitAt('TRG_EmitTransactionAudit');
		 *     }
		 * }
		 * ```
		 */
		void execute(IF_Trigger.PostActionContext context);
	}

	/**
	 * @description Optional entry-criteria contract for a post-trigger action. Implementing
	 * classes are referenced from `PostTriggerAction__mdt.EntryCriteriaContextClassName__c`
	 * and consulted before the post-action's `execute(context)` is invoked. Returning false
	 * skips the row; returning true proceeds to execution. Use for context-level gating
	 * (e.g. "only run when Account records were touched AND feature flag X is enabled").
	 *
	 * Evaluators should be cheap — configuration lookups, feature-flag checks, Set membership
	 * tests, at most one bounded SOQL. Expensive evaluators undermine the cost benefit of
	 * having an entry criteria at all.
	 *
	 * @since 1.1
	 */
	global interface PostActionEntryCriteria
	{
		/**
		 * @description Called once per outermost dispatch before the gated post-action.
		 * Returning false skips the post-action; returning true proceeds to execution.
		 *
		 * @param context The post-action context for this dispatch. Carries the set of
		 * SObject types whose triggers participated in the transaction.
		 *
		 * @return `true` if the gated post-action should run; `false` to skip it.
		 *
		 * @since 1.1
		 *
		 * @example
		 * ```apex
		 * public class TRG_PostActionEntryBrandA implements IF_Trigger.PostActionEntryCriteria
		 * {
		 *     public Boolean shouldRun(IF_Trigger.PostActionContext context)
		 *     {
		 *         if(!context.touchedSObjectTypes.contains(Account.SObjectType)) return false;
		 *         return UTIL_FeatureFlag.isEnabled('BrandA_Sales_Enabled');
		 *     }
		 * }
		 * ```
		 */
		Boolean shouldRun(IF_Trigger.PostActionContext context);
	}

	/**
	 * @description Context handed to a post-trigger action when the dispatcher unwinds the
	 * outermost trigger dispatch. Carries the set of SObject types whose triggers
	 * participated in the transaction so the post-action can branch on which objects were
	 * touched without re-querying.
	 *
	 * The framework constructs and supplies this object — subscribers should not need to
	 * construct it directly outside of unit tests.
	 *
	 * **Why `Set&lt;SObjectType&gt;` rather than record IDs:** the post-action runs
	 * once per outermost dispatch with no per-record context, so the type-level discriminator
	 * is what's load-bearing. Per-record IDs would (1) carry an unbounded heap cost in batch
	 * contexts, (2) leak record material across post-actions written by different teams in
	 * the same org. Subscribers needing per-record context should maintain their own
	 * domain-specific statics during their trigger actions and consult them inside the
	 * post-action.
	 *
	 * @since 1.1
	 *
	 * @example
	 * ```apex
	 * // Inside a PostAction.execute(context):
	 * if(context.touchedSObjectTypes.contains(Account.SObjectType))
	 * {
	 *     // Account triggers participated; run Account-domain work.
	 * }
	 * ```
	 */
	global class PostActionContext
	{
		/**
		 * @description The SObject types whose triggers participated in the transaction.
		 * The framework stores a defensive copy on construction and the setter is private,
		 * so the framework's own source set cannot be mutated through this reference;
		 * subscribers must still treat the returned Set as read-only — a single context
		 * instance is shared across every post-action in the dispatch, so mutating it has
		 * no defined effect and could affect other post-actions. An empty set is possible —
		 * a post-action that ran solely because of a bypassed-but-still-fired trigger could
		 * see an empty context. Subscribers should null-check defensively even though the
		 * constructor guarantees a non-null Set.
		 *
		 * @since 1.1
		 */
		global Set<SObjectType> touchedSObjectTypes {get; private set;}

		/**
		 * @description Constructs a post-action context with the supplied set of touched
		 * SObject types. A null argument is normalised to an empty Set so subscribers can
		 * safely call `.contains(...)` without null-checking. Intended for framework and
		 * unit-test construction; subscribers receive instances via `PostAction.execute`.
		 *
		 * @param touched The set of SObject types whose triggers participated, or null.
		 *
		 * @since 1.1
		 */
		global PostActionContext(Set<SObjectType> touched)
		{
			this.touchedSObjectTypes =
					touched != null ? new Set<SObjectType>(touched) : new Set<SObjectType>();
		}
	}
}