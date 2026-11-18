// SPDX-License-Identifier: Apache-2.0
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
 * @date February 2026, November 2026
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
	 * @description The DML operation to perform on the records.
	 */
	private final DML_Builder.DatabaseOperation operation;

	/**
	 * @description Whether the operation should be all-or-nothing (true) or allow partial success (false).
	 */
	private final Boolean allOrNothing;

	/**
	 * @description The `AccessLevel` the caller chose for saving the records. Null means the default from
	 * `DML_SharingProxy.defaultAccessLevel()`: USER_MODE when the `UserModeDml_Enabled` flag is on, which is the
	 * safer choice. An explicit `SYSTEM_MODE` skips the running user's object and field permission checks. An explicit
	 * `USER_MODE` keeps a subscriber's choice of the safer mode made through `DML_Builder.async().execute()`. Any other
	 * value, such as a user mode level that names a permission set, is not changed by the job and is not turned into the
	 * flag's default. It is not final, because `withAccessLevelInternal` sets it after the processor is built.
	 */
	private AccessLevel accessLevel;

	/**
	 * @description Whether the caller asked to ignore record sharing for the save. The value is saved with the job
	 * and read back when the job runs. It is false by default, so sharing is enforced. A job queued before this
	 * field existed reads it back as null, which also means sharing is enforced.
	 */
	private Boolean isBypassSharingRequested = false;

	/**
	 * @description The status codes the caller declared as expected refusals through `DML_Builder.expectRefusal()`.
	 * The value is saved with the job and read back when the job runs. A job queued before this field existed reads
	 * it back as null, which means none.
	 */
	private Set<StatusCode> expectedRefusalStatusCodes = new Set<StatusCode>();

	/**
	 * @description How many times the caller asked to retry after a row lock, set through
	 * `DML_Builder.withRetryOnLock()`. A row lock is the platform refusing a save because another process holds the
	 * record. The value is saved with the job and read back when the job runs. Null means each batch runs once.
	 * Null is also what a job queued before this field existed reads back.
	 */
	private Integer retriesOnLock;

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
	 * @description Constructs a DML processor with an explicit `AccessLevel`. Use this constructor when the
	 * async save must use one access mode, whatever the `UserModeDml_Enabled` flag says. `DML_Builder.async()` keeps
	 * the access level the caller chose, so your `.withUserMode()` still applies when the job runs later.
	 *
	 * System mode skips the running user's object and field permission checks, so it is recorded in the bypass audit.
	 * When you pass `AccessLevel.SYSTEM_MODE`, the constructor writes one audit entry at once, while your code is still
	 * running and can be named as the caller. The records are not known yet, because they reach the processor later,
	 * often in a background job. So the entry's target is `system-mode` with no object name. The entry names the
	 * operation (`insert`, `update`, `delete`, `upsert` or `undelete`) and the class and method that built the processor.
	 *
	 * @param operation The DML operation to perform (DML_INSERT, DML_UPDATE, DML_DELETE, DML_UPSERT, DML_UNDELETE).
	 * @param allOrNothing If true, the entire transaction rolls back on any failure; if false, allows partial success.
	 * @param accessLevel Explicit `AccessLevel` for the DML commit, or `null` to inherit the flag-driven default. The
	 * job does not change the level you pass. A level that names a permission set is not turned into the default
	 * that the flag sets.
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
		if(DML_SharingProxy.matchesAccessLevel(accessLevel, System.AccessLevel.SYSTEM_MODE))
		{
			UTIL_BypassAudit.emit(UTIL_BypassAudit.SURFACE_DML, UTIL_BypassAudit.ACTION_BYPASS, UTIL_BypassAudit.TARGET_SYSTEM_MODE, new Map<String, Object>
			{
					UTIL_BypassAudit.CONTEXT_OPERATION => operation?.name().substringAfter('_').toLowerCase()
			});
		}
	}

	/**
	 * @description Sets the access level the save uses, as the three-argument constructor does, but writes no entry in
	 * the bypass audit. Only the framework calls this. `DML_Builder.DML_AsyncBuilder` calls it because the builder has
	 * already recorded its own entry when `async()` ran, so the save is recorded once.
	 *
	 * @param accessLevel The `AccessLevel` for the save, or null to use the default that the `UserModeDml_Enabled`
	 * flag sets.
	 *
	 * @return This processor, so the calls can be chained.
	 */
	public PROC_ExecuteDML withAccessLevelInternal(AccessLevel accessLevel)
	{
		this.accessLevel = accessLevel;
		return this;
	}

	/**
	 * @description Marks the save as one that ignores record sharing on purpose. Only the package itself calls
	 * this. `DML_Builder.DML_AsyncBuilder` calls it to carry a subscriber's `.bypassSharing()` choice into the
	 * async job. The choice was already recorded in the bypass audit before the job was queued. A subscriber who
	 * builds `PROC_ExecuteDML` directly cannot reach this method, so sharing is enforced, the safer default.
	 */
	public void requestSharingBypass()
	{
		this.isBypassSharingRequested = true;
	}

	/**
	 * @description Carries a caller's expected refusals into the async job. Only the package itself calls this.
	 * `DML_Builder.DML_AsyncBuilder` calls it so that a partial save inside the job logs those refusals at WARN
	 * instead of ERROR, exactly as a save in the same transaction would.
	 *
	 * @param statusCodes The expected status codes; null means none.
	 */
	public void expectRefusals(Set<StatusCode> statusCodes)
	{
		this.expectedRefusalStatusCodes = statusCodes ?? new Set<StatusCode>();
	}

	/**
	 * @description Carries a caller's row-lock retry count into the async job. Only the package itself calls this.
	 * `DML_Builder.DML_AsyncBuilder` calls it so that every batch of the job retries its own row-lock refusals,
	 * exactly as a save in the same transaction would.
	 *
	 * @param retries Extra attempts after the first; null means none.
	 */
	public void retryOnLock(Integer retries)
	{
		retriesOnLock = retries;
	}

	/**
	 * @description Runs the configured DML operation on the given records. The save always sets record sharing
	 * itself: sharing is enforced unless `requestSharingBypass()` was called. The save also applies the configured
	 * access mode again, without a new entry in the bypass audit. This is the same when you call this method
	 * directly in your own transaction as when it runs inside an async job. A caller that needs the sharing of its
	 * own class, or a recorded bypass, should save through `DML_Builder` instead.
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

		// The save gets the caller's access level as it is, so a level that names a permission set keeps it. Null keeps
		// the flag's default. No second bypass audit entry: a system mode choice was audited before the job was queued,
		// or was made by a framework utility.
		DML_Builder builder = DML_Builder.newTransaction().withAccessLevelInternal(accessLevel);

		// The job itself runs `without sharing`, so inherited sharing must never be used here. The
		// builder sets sharing explicitly: enforced unless the caller asked to ignore sharing.
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

		for(StatusCode statusCode : expectedRefusalStatusCodes ?? new Set<StatusCode>())
		{
			builder.expectRefusal(statusCode);
		}

		if(retriesOnLock != null)
		{
			builder.withRetryOnLock(retriesOnLock);
		}

		builder.execute();
	}
}