// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Processor for generic DML operations using the adaptive async framework.
 * Implements IF_Async.Processable to enable automatic selection between Queueable and Batch execution.
 * Supports INSERT, UPDATE, DELETE, UPSERT, and UNDELETE operations.
 *
 * @see PROC_ExecuteDML_TEST
 * @see IF_Async.Processable
 * @see UTIL_AsynchronousJobLauncher
 *
 * @author Jason van Beukering
 *
 * @group Bulk DML
 *
 * @date February 2026, August 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * PROC_ExecuteDML processor = new PROC_ExecuteDML(DML_Builder.DatabaseOperation.DML_UPDATE, false);
 * UTIL_AsynchronousJobLauncher.process(
 *     new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(queryable), processor
 * );
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.AvoidBooleanMethodParameters')
global inherited sharing class PROC_ExecuteDML implements IF_Async.Processable
{
	/**
	 * @description Constant for logging the class and method name during execution.
	 */
	@TestVisible
	private static final String CLASS_METHOD_EXECUTE = PROC_ExecuteDML.class.getName() + '/execute';

	/**
	 * @description The DML operation to perform on the records.
	 */
	private final DML_Builder.DatabaseOperation operation;

	/**
	 * @description Whether the operation should be all-or-nothing (true) or allow partial success (false).
	 */
	private final Boolean allOrNothing;

	/**
	 * @description Caller-selected `AccessLevel` for the DML commit. `null` inherits the flag-driven
	 * default resolved by `DML_SharingProxy.defaultAccessLevel()` (the secure-by-default posture: USER_MODE when
	 * `UserModeDml_Enabled` is on). Explicit `SYSTEM_MODE` preserves the framework-internal elevation
	 * required by utilities such as `UTIL_PurgeRecords` and `UTIL_BulkUpdates`. Explicit `USER_MODE`
	 * honours a subscriber's secure-by-default opt-in through `DML_Builder.async().execute()`.
	 */
	private final AccessLevel accessLevel;

	/**
	 * @description Whether the caller requested a record-sharing bypass for the commit. Crosses the
	 * async serialization boundary as part of the processor's state. Defaults to false — the
	 * secure enforce-default — including for payloads queued before this field existed, which
	 * deserialize it as null.
	 */
	private Boolean isBypassSharingRequested = false;

	/**
	 * @description Constructs a DML processor with the specified operation and default all-or-nothing behavior.
	 * Access mode inherits the flag-driven default.
	 *
	 * @param operation The DML operation to perform (DML_INSERT, DML_UPDATE, DML_DELETE, DML_UPSERT, DML_UNDELETE).
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * PROC_ExecuteDML processor = new PROC_ExecuteDML(DML_Builder.DatabaseOperation.DML_INSERT);
	 * ```
	 */
	global PROC_ExecuteDML(DML_Builder.DatabaseOperation operation)
	{
		this(operation, true, null);
	}

	/**
	 * @description Constructs a DML processor with the specified operation and transaction behavior.
	 * Access mode inherits the flag-driven default.
	 *
	 * @param operation The DML operation to perform (DML_INSERT, DML_UPDATE, DML_DELETE, DML_UPSERT, DML_UNDELETE).
	 * @param allOrNothing If true, the entire transaction rolls back on any failure; if false, allows partial success.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * PROC_ExecuteDML processor = new PROC_ExecuteDML(DML_Builder.DatabaseOperation.DML_UPDATE, false);
	 * ```
	 */
	global PROC_ExecuteDML(DML_Builder.DatabaseOperation operation, Boolean allOrNothing)
	{
		this(operation, allOrNothing, null);
	}

	/**
	 * @description Constructs a DML processor with an explicit `AccessLevel`. Use this overload when
	 * the async commit must pin a specific access mode regardless of the `UserModeDml_Enabled` flag —
	 * framework utilities that own their lifecycle pass `AccessLevel.SYSTEM_MODE`, and the
	 * `DML_Builder.async()` path passes the caller's chosen `AccessLevel` so subscriber `.withUserMode()`
	 * opt-ins survive the sync-to-async boundary.
	 *
	 * @param operation The DML operation to perform (DML_INSERT, DML_UPDATE, DML_DELETE, DML_UPSERT, DML_UNDELETE).
	 * @param allOrNothing If true, the entire transaction rolls back on any failure; if false, allows partial success.
	 * @param accessLevel Explicit `AccessLevel` for the DML commit, or `null` to inherit the flag-driven default.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * PROC_ExecuteDML processor = new PROC_ExecuteDML(DML_Builder.DatabaseOperation.DML_DELETE, true, AccessLevel.SYSTEM_MODE);
	 * ```
	 */
	global PROC_ExecuteDML(DML_Builder.DatabaseOperation operation, Boolean allOrNothing, AccessLevel accessLevel)
	{
		this.operation = operation;
		this.allOrNothing = allOrNothing != null ? allOrNothing : true;
		this.accessLevel = accessLevel;
	}

	/**
	 * @description Marks the commit as a deliberate record-sharing bypass. Namespace-internal:
	 * `DML_Builder.DML_AsyncBuilder` calls this while threading a subscriber's `.bypassSharing()`
	 * dial across the async hand-off — the audited opt-out already happened on the synchronous
	 * side. A subscriber constructing `PROC_ExecuteDML` directly cannot reach this method and gets
	 * the secure enforce-default.
	 *
	 * @since 1.7
	 */
	public void requestSharingBypass()
	{
		this.isBypassSharingRequested = true;
	}

	/**
	 * @description Executes the configured DML operation on the provided list of records. The
	 * commit pins its record-sharing context explicitly — enforced unless `requestSharingBypass()`
	 * was called — and re-applies the configured access mode without a separate bypass-audit
	 * entry; this holds for a direct synchronous invocation exactly as it does inside an async
	 * job, so a synchronous caller that needs its own class sharing context or an audited opt-out
	 * should commit through `DML_Builder` instead.
	 *
	 * @param items The list of SObject records to process.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Account> accounts = new List<Account>();
	 * accounts.add(new Account(Name = 'Test'));
	 * new PROC_ExecuteDML(DML_Builder.DatabaseOperation.DML_INSERT).execute(accounts);
	 * ```
	 */
	global void execute(List<Object> items)
	{
		List<SObject> records = new List<SObject>();
		for(Object item : items)
		{
			records.add((SObject)item);
		}

		DML_Builder builder = DML_Builder.newTransaction();
		// Tri-state: SYSTEM_MODE and USER_MODE override explicitly; null inherits the flag-driven default.
		// The comparator, not raw ==, because a deserialized AccessLevel identity-matches neither singleton.
		// systemModeInternal: this re-applies a selection audited on the synchronous side of the hand-off
		// (or made by a framework utility), so it must not enqueue a second bypass-audit entry.
		if(DML_SharingProxy.matchesAccessLevel(accessLevel, System.AccessLevel.SYSTEM_MODE))
		{
			builder.systemModeInternal();
		}
		else if(DML_SharingProxy.matchesAccessLevel(accessLevel, System.AccessLevel.USER_MODE))
		{
			builder.withUserMode();
		}

		// The job's own frame is `without sharing`, so INHERITED must never cross the hand-off: the
		// rebuilt builder selects sharing explicitly — enforce unless the caller requested a bypass.
		builder.withSharingEnforcement(!(isBypassSharingRequested ?? false));

		switch on operation
		{
			when DML_INSERT
			{
				builder.doInsert(records);
			}
			when DML_UPDATE
			{
				builder.doUpdate(records);
			}
			when DML_DELETE
			{
				builder.doDelete(records);
			}
			when DML_UPSERT
			{
				builder.doUpsert(records);
			}
			when DML_UNDELETE
			{
				builder.doUndelete(records);
			}
		}

		if(!allOrNothing)
		{
			builder.allowPartial();
		}

		try
		{
			builder.execute();
		}
		catch(DmlException error)
		{
			LOG_Builder.build().error(error).at(CLASS_METHOD_EXECUTE).emit();
			throw error;
		}
	}
}