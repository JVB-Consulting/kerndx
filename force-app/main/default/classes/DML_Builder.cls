// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Fluent DML API for building and executing database operations. Uses a static factory
 * entry point to create a transaction context, fluent methods to register operations and configure
 * behaviour, and a terminal method to commit all operations via DML_Transaction.
 *
 * @see DML_Builder_TEST
 * @see DML_Transaction
 *
 * @author Jason van Beukering
 *
 * @group DML
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * DML_Builder.TransactionResult result = DML_Builder.newTransaction()
 *     .doInsert(account)
 *     .doInsert(contact, Contact.AccountId, account)
 *     .doUpdate(existingRecord)
 *     .allowPartial()
 *     .execute();
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.AvoidGlobalModifier,PMD.ExcessivePublicCount,PMD.ExcessiveClassLength')
global inherited sharing class DML_Builder
{
	/**
	 * @description Enum to specify the type of DML operation for external use.
	 *
	 * @since 1.0
	 */
	global enum DatabaseOperation
	{
		/**
		 * @description Insert operation.
		 */
		DML_INSERT,

		/**
		 * @description Update operation.
		 */
		DML_UPDATE,

		/**
		 * @description Delete operation.
		 */
		DML_DELETE,

		/**
		 * @description Upsert operation.
		 */
		DML_UPSERT,

		/**
		 * @description Undelete operation.
		 */
		DML_UNDELETE
	}

	/**
	 * @description Class and method name for logging.
	 */
	@TestVisible
	private static final String CLASS_METHOD_EXECUTE = DML_Builder.class.getName() + '.execute';

	/**
	 * @description Test-only override for the per-transaction DML row guard. When non-null,
	 * `execute()` uses this value instead of `UTIL_Limits.dmlRows().maximum()` so a unit test
	 * can drive the over-limit branch with a handful of records (10,001 real records is
	 * prohibitively slow and would burn the synchronous CPU governor before the guard fires).
	 * Production code paths leave this `null`.
	 */
	@TestVisible
	private static Integer maxDmlRowsForTest = null;

	/**
	 * @description Ordered list of registered DML operations.
	 */
	private final List<DTO_Operation> operations = new List<DTO_Operation>();

	/**
	 * @description Whether to allow partial success for DML operations.
	 */
	@TestVisible
	private Boolean isPartial = false;

	/**
	 * @description Whether to bypass sharing rules.
	 */
	@TestVisible
	private Boolean isBypassSharing = false;

	/**
	 * @description Whether to suppress LOG_Builder error logging.
	 */
	@TestVisible
	private Boolean isSuppressLogging = false;

	/**
	 * @description Explicit access level for DML operations. Null means "use the flag-driven default"
	 * (`UserModeDml_Enabled`). Subscriber-reachable transactions inherit the default; framework
	 * internals opt out via `.withSystemMode()`.
	 */
	@TestVisible
	private AccessLevel accessLevel;

	/**
	 * @description Whether to suppress DmlException re-throw in all-or-nothing mode.
	 */
	@TestVisible
	private Boolean isSuppressExceptions = false;

	/**
	 * @description Setter-time bypass-audit queue keyed to the DML surface. Setter calls
	 * (`bypassSharing` / `withSystemMode`) enqueue their target via `auditQueue.queue(...)`;
	 * `execute()` calls `auditQueue.flush()` so a builder dropped before execution emits
	 * nothing. Lazy-initialised so the secure-by-default execution path (no bypass setters
	 * called) does not allocate the queue.
	 */
	@TestVisible
	private final UTIL_BypassAudit.AuditQueue auditQueue
	{
		get
		{
			if(auditQueue == null)
			{
				auditQueue = new UTIL_BypassAudit.AuditQueue(UTIL_BypassAudit.SURFACE_DML);
			}
			return auditQueue;
		}
		private set;
	}

	/**
	 * @description Private constructor to force use of newTransaction() static factory.
	 */
	private DML_Builder()
	{
	}

	/**
	 * @description Creates a new DML_Builder instance representing a DML transaction.
	 *
	 * @return A new DML_Builder instance.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doInsert(account)
	 *     .execute();
	 * ```
	 */
	global static DML_Builder newTransaction()
	{
		return new DML_Builder();
	}

	/**
	 * @description Registers a single record for insertion.
	 *
	 * @param record The SObject to insert.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doInsert(new Account(Name = 'Test'))
	 *     .execute();
	 * ```
	 */
	global DML_Builder doInsert(SObject record)
	{
		operations.add(new DTO_Operation(DatabaseOperation.DML_INSERT, new List<SObject> {record}));
		return this;
	}

	/**
	 * @description Registers multiple records for insertion.
	 *
	 * @param records The list of SObjects to insert.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doInsert(accounts)
	 *     .execute();
	 * ```
	 */
	global DML_Builder doInsert(List<SObject> records)
	{
		operations.add(new DTO_Operation(DatabaseOperation.DML_INSERT, records));
		return this;
	}

	/**
	 * @description Registers a child record for insertion with a relationship to a parent record.
	 *
	 * @param child The child SObject to insert.
	 * @param relationshipField The field linking the child to the parent.
	 * @param parent The parent SObject.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doInsert(account)
	 *     .doInsert(contact, Contact.AccountId, account)
	 *     .execute();
	 * ```
	 */
	global DML_Builder doInsert(SObject child, SObjectField relationshipField, SObject parent)
	{
		DTO_Operation operation = new DTO_Operation(DatabaseOperation.DML_INSERT, new List<SObject> {child});
		operation.relationshipField = relationshipField;
		operation.parentRecord = parent;
		operations.add(operation);
		return this;
	}

	/**
	 * @description Registers a single record for update.
	 *
	 * @param record The SObject to update.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doUpdate(account)
	 *     .execute();
	 * ```
	 */
	global DML_Builder doUpdate(SObject record)
	{
		operations.add(new DTO_Operation(DatabaseOperation.DML_UPDATE, new List<SObject> {record}));
		return this;
	}

	/**
	 * @description Registers multiple records for update.
	 *
	 * @param records The list of SObjects to update.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doUpdate(accounts)
	 *     .execute();
	 * ```
	 */
	global DML_Builder doUpdate(List<SObject> records)
	{
		operations.add(new DTO_Operation(DatabaseOperation.DML_UPDATE, records));
		return this;
	}

	/**
	 * @description Registers a single record for deletion.
	 *
	 * @param record The SObject to delete.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doDelete(record)
	 *     .execute();
	 * ```
	 */
	global DML_Builder doDelete(SObject record)
	{
		operations.add(new DTO_Operation(DatabaseOperation.DML_DELETE, new List<SObject> {record}));
		return this;
	}

	/**
	 * @description Registers multiple records for deletion.
	 *
	 * @param records The list of SObjects to delete.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doDelete(records)
	 *     .execute();
	 * ```
	 */
	global DML_Builder doDelete(List<SObject> records)
	{
		operations.add(new DTO_Operation(DatabaseOperation.DML_DELETE, records));
		return this;
	}

	/**
	 * @description Registers a single record for upsert.
	 *
	 * @param record The SObject to upsert.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doUpsert(account)
	 *     .execute();
	 * ```
	 */
	global DML_Builder doUpsert(SObject record)
	{
		operations.add(new DTO_Operation(DatabaseOperation.DML_UPSERT, new List<SObject> {record}));
		return this;
	}

	/**
	 * @description Registers multiple records for upsert.
	 *
	 * @param records The list of SObjects to upsert.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doUpsert(accounts)
	 *     .execute();
	 * ```
	 */
	global DML_Builder doUpsert(List<SObject> records)
	{
		operations.add(new DTO_Operation(DatabaseOperation.DML_UPSERT, records));
		return this;
	}

	/**
	 * @description Registers a single record for upsert with a specific external ID field.
	 *
	 * @param record The SObject to upsert.
	 * @param externalIdField The external ID field for matching.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doUpsert(account, Account.ExternalId__c)
	 *     .execute();
	 * ```
	 */
	global DML_Builder doUpsert(SObject record, SObjectField externalIdField)
	{
		DTO_Operation operation = new DTO_Operation(DatabaseOperation.DML_UPSERT, new List<SObject> {record});
		operation.externalIdField = externalIdField;
		operations.add(operation);
		return this;
	}

	/**
	 * @description Registers multiple records for upsert with a specific external ID field.
	 *
	 * @param records The list of SObjects to upsert.
	 * @param externalIdField The external ID field for matching.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doUpsert(accounts, Account.ExternalId__c)
	 *     .execute();
	 * ```
	 */
	global DML_Builder doUpsert(List<SObject> records, SObjectField externalIdField)
	{
		DTO_Operation operation = new DTO_Operation(DatabaseOperation.DML_UPSERT, records);
		operation.externalIdField = externalIdField;
		operations.add(operation);
		return this;
	}

	/**
	 * @description Registers a single record for undelete.
	 *
	 * @param record The SObject to undelete.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doUndelete(record)
	 *     .execute();
	 * ```
	 */
	global DML_Builder doUndelete(SObject record)
	{
		operations.add(new DTO_Operation(DatabaseOperation.DML_UNDELETE, new List<SObject> {record}));
		return this;
	}

	/**
	 * @description Registers multiple records for undelete.
	 *
	 * @param records The list of SObjects to undelete.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doUndelete(records)
	 *     .execute();
	 * ```
	 */
	global DML_Builder doUndelete(List<SObject> records)
	{
		operations.add(new DTO_Operation(DatabaseOperation.DML_UNDELETE, records));
		return this;
	}

	/**
	 * @description Enables partial success mode. Failed records do not cause the entire transaction to fail.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doUpdate(records)
	 *     .allowPartial()
	 *     .execute();
	 * ```
	 */
	global DML_Builder allowPartial()
	{
		this.isPartial = true;
		return this;
	}

	/**
	 * @description Bypasses sharing rules for DML operations.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doUpdate(records)
	 *     .bypassSharing()
	 *     .execute();
	 * ```
	 */
	global DML_Builder bypassSharing()
	{
		this.isBypassSharing = true;
		auditQueue.queueSharing();
		return this;
	}

	/**
	 * @description Forces `AccessLevel.USER_MODE` on every DML operation in this transaction,
	 * regardless of the `UserModeDml_Enabled` feature flag. Use when a subscriber-facing flow
	 * must enforce CRUD/FLS even in orgs where the flag has been disabled as a kill-switch.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doInsert(accountFromSubscriberUI)
	 *     .withUserMode()
	 *     .execute();
	 * ```
	 */
	global DML_Builder withUserMode()
	{
		this.accessLevel = System.AccessLevel.USER_MODE;
		return this;
	}

	/**
	 * @description Forces `AccessLevel.SYSTEM_MODE` on every DML operation in this transaction.
	 * Use when the framework writes objects the running user has no FLS/CRUD on by design
	 * (logs, orchestration records, framework-owned sObjects).
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doInsert(logEntryEvent)
	 *     .withSystemMode()
	 *     .execute();
	 * ```
	 */
	global DML_Builder withSystemMode()
	{
		this.accessLevel = System.AccessLevel.SYSTEM_MODE;
		auditQueue.queueSystemMode();
		return this;
	}

	/**
	 * @description Framework-internal sibling of `withSystemMode()` that sets `AccessLevel.SYSTEM_MODE`
	 * without enqueuing a `BypassEvent` audit entry. Use from framework triggers and operational code
	 * that persists the framework's own data (e.g., `TRG_PersistLogEntry` writing `LogEntry__c` rows
	 * after `LogEntryEvent__e` delivery) where SYSTEM_MODE is structurally required and the write is
	 * not a subscriber-facing bypass — auditing it would (a) pollute the forensic trail with framework
	 * machinery noise, and (b) create an emit→deliver→persist→emit cascade that has no fixpoint
	 * (every audit emission produces a new `LogEntryEvent__e` whose persistence emits another audit).
	 * Public-but-not-global so subscribers cannot bind to it; subscriber DML that legitimately opts
	 * out of USER_MODE must call `withSystemMode()` so the opt-out is audited.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .systemModeInternal()
	 *     .doInsert(logEntries)
	 *     .execute();
	 * ```
	 */
	public DML_Builder systemModeInternal()
	{
		this.accessLevel = System.AccessLevel.SYSTEM_MODE;
		return this;
	}

	/**
	 * @description Returns the `AccessLevel` that will be applied when `execute()` runs. When
	 * `.withUserMode()` / `.withSystemMode()` were called, returns their value; otherwise returns
	 * the flag-driven default. Test-only accessor for observability.
	 *
	 * @return The effective `AccessLevel` for this transaction.
	 */
	@TestVisible
	private AccessLevel resolvedAccessLevel()
	{
		return accessLevel ?? DML_SharingProxy.defaultAccessLevel();
	}

	/**
	 * @description Suppresses LOG_Builder error logging for DML failures.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doUpdate(records)
	 *     .allowPartial()
	 *     .suppressLogging()
	 *     .execute();
	 * ```
	 */
	global DML_Builder suppressLogging()
	{
		this.isSuppressLogging = true;
		return this;
	}

	/**
	 * @description Suppresses DmlException re-throw in all-or-nothing mode. Errors are logged
	 * via LOG_Builder instead of propagating to the caller.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doInsert(record)
	 *     .suppressExceptions()
	 *     .execute();
	 * ```
	 */
	global DML_Builder suppressExceptions()
	{
		this.isSuppressExceptions = true;
		return this;
	}

	/**
	 * @description Switches to asynchronous execution mode. Returns a DML_AsyncBuilder that delegates to
	 * PROC_ExecuteDML and UTIL_AsynchronousJobLauncher for adaptive async processing.
	 *
	 * @return A DML_AsyncBuilder for configuring and executing async DML.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doUpdate(records)
	 *     .allowPartial()
	 *     .async()
	 *     .execute();
	 * ```
	 */
	global DML_AsyncBuilder async()
	{
		auditQueue.flush();
		return new DML_AsyncBuilder(operations, isPartial, accessLevel);
	}

	/**
	 * @description Commits all registered DML operations via DML_Transaction and returns the result.
	 *
	 * @return A TransactionResult containing the outcome of all DML operations.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Builder.TransactionResult result = DML_Builder.newTransaction()
	 *     .doInsert(account)
	 *     .doInsert(contact, Contact.AccountId, account)
	 *     .execute();
	 * ```
	 */
	global TransactionResult execute()
	{
		auditQueue.flush();
		if(operations.isEmpty())
		{
			return new TransactionResult();
		}

		Integer totalRows = 0;
		for(DTO_Operation operation : operations)
		{
			totalRows += operation.records?.size() ?? 0;
		}
		Integer maxDmlRows = maxDmlRowsForTest ?? UTIL_Limits.dmlRows().maximum();
		if(totalRows > maxDmlRows)
		{
			throw new UTIL_Exceptions.IllegalStateException(
					'DML_Builder transaction exceeds the Salesforce per-transaction DML row limit ('
					+ totalRows + ' > ' + maxDmlRows + '). '
					+ 'Split the work across multiple transactions, or chain via .async() to dispatch '
					+ 'an asynchronous job that processes the records in batches.');
		}

		DML_Transaction dmlTransaction = new DML_Transaction();
		dmlTransaction.setAllowPartial(isPartial);
		dmlTransaction.setSuppressLogging(isSuppressLogging);
		dmlTransaction.setAccessLevel(accessLevel);

		for(DTO_Operation operation : operations)
		{
			registerOnTransaction(dmlTransaction, operation);
		}

		try
		{
			Boolean enforceSharing = isBypassSharing ? false : null;
			dmlTransaction.commitWork(enforceSharing);
		}
		catch(DmlException error)
		{
			if(isSuppressExceptions)
			{
				if(!isSuppressLogging)
				{
					LOG_Builder.build().error(error).at(CLASS_METHOD_EXECUTE).emit();
				}
				return new TransactionResult(error);
			}
			throw error;
		}

		return new TransactionResult(dmlTransaction);
	}

	/**
	 * @description Registers a single operation on a DML_Transaction instance.
	 *
	 * @param dmlTransaction The transaction to register the operation on.
	 * @param operation The operation to register.
	 */
	private static void registerOnTransaction(DML_Transaction dmlTransaction, DTO_Operation operation)
	{
		switch on operation.operationType
		{
			when DML_INSERT
			{
				if(operation.relationshipField != null)
				{
					for(SObject record : operation.records)
					{
						dmlTransaction.doInsert(record, operation.relationshipField, operation.parentRecord);
					}
				}
				else
				{
					dmlTransaction.doInsert(operation.records);
				}
			}
			when DML_UPDATE
			{
				dmlTransaction.doUpdate(operation.records);
			}
			when DML_DELETE
			{
				dmlTransaction.doDelete(operation.records);
			}
			when DML_UPSERT
			{
				if(operation.externalIdField != null)
				{
					dmlTransaction.doUpsert(operation.records, operation.externalIdField);
				}
				else
				{
					dmlTransaction.doUpsert(operation.records);
				}
			}
			when DML_UNDELETE
			{
				dmlTransaction.doUndelete(operation.records);
			}
		}
	}

	/**
	 * @description Async DML execution wrapper. Groups registered operations by type and delegates
	 * to PROC_ExecuteDML with UTIL_AsynchronousJobLauncher for adaptive async processing.
	 *
	 * @since 1.0
	 */
	global class DML_AsyncBuilder
	{
		/**
		 * @description The registered DML operations to execute asynchronously.
		 */
		private final List<DTO_Operation> operations;

		/**
		 * @description Whether to allow partial success.
		 */
		private final Boolean isPartial;

		/**
		 * @description Caller-selected `AccessLevel` inherited from the parent `DML_Builder`. Propagated
		 * to `PROC_ExecuteDML` so a subscriber's `.withUserMode()` / `.withSystemMode()` opt-in survives
		 * the sync-to-async boundary. `null` inherits the flag-driven default.
		 */
		private final AccessLevel accessLevel;

		/**
		 * @description Optional batch size override.
		 */
		private Integer batchSize;

		/**
		 * @description Constructs a DML_AsyncBuilder with operations and configuration from the parent builder.
		 *
		 * @param operations The registered DML operations.
		 * @param isPartial Whether to allow partial success.
		 * @param accessLevel Inherited `AccessLevel` from the parent builder, or `null` for flag-driven default.
		 */
		private DML_AsyncBuilder(List<DTO_Operation> operations, Boolean isPartial, AccessLevel accessLevel)
		{
			this.operations = operations;
			this.isPartial = isPartial;
			this.accessLevel = accessLevel;
		}

		/**
		 * @description Sets the batch size for async processing.
		 *
		 * @param batchSize The number of records to process per batch/queueable execution.
		 *
		 * @return This DML_AsyncBuilder instance for fluent chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * DML_Builder.newTransaction()
		 *     .doDelete(records)
		 *     .async()
		 *     .withBatchSize(200)
		 *     .execute();
		 * ```
		 */
		global DML_AsyncBuilder withBatchSize(Integer batchSize)
		{
			this.batchSize = batchSize;
			return this;
		}

		/**
		 * @description Enqueues the registered DML operations for asynchronous execution.
		 * Groups records by operation type and launches one async job per type.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * DML_Builder.newTransaction()
		 *     .doUpdate(records)
		 *     .allowPartial()
		 *     .async()
		 *     .execute();
		 * ```
		 */
		global void execute()
		{
			if(operations.isEmpty())
			{
				return;
			}

			Map<DatabaseOperation, List<SObject>> recordsByOperation = new Map<DatabaseOperation, List<SObject>>();

			for(DTO_Operation operation : operations)
			{
				if(!recordsByOperation.containsKey(operation.operationType))
				{
					recordsByOperation.put(operation.operationType, new List<SObject>());
				}
				recordsByOperation.get(operation.operationType).addAll(operation.records);
			}

			Boolean allOrNothing = !isPartial;

			for(DatabaseOperation operationType : recordsByOperation.keySet())
			{
				List<SObject> records = recordsByOperation.get(operationType);
				PROC_ExecuteDML processor = new PROC_ExecuteDML(operationType, allOrNothing, accessLevel);

				if(batchSize != null)
				{
					UTIL_AsynchronousJobLauncher.process(records, processor, batchSize);
				}
				else
				{
					UTIL_AsynchronousJobLauncher.process(records, processor);
				}
			}
		}
	}

	/**
	 * @description Result object returned by execute() containing the outcome of all DML operations
	 * in the transaction. Provides methods to inspect success/failure status, retrieve generated IDs,
	 * and access errors.
	 *
	 * @since 1.0
	 */
	global class TransactionResult
	{
		/**
		 * @description Insert operation results.
		 */
		private final List<Database.SaveResult> insertResults;

		/**
		 * @description Update operation results.
		 */
		private final List<Database.SaveResult> updateResults;

		/**
		 * @description Upsert operation results.
		 */
		private final List<Database.UpsertResult> upsertResults;

		/**
		 * @description Delete operation results.
		 */
		private final List<Database.DeleteResult> deleteResults;

		/**
		 * @description Undelete operation results.
		 */
		private final List<Database.UndeleteResult> undeleteResults;

		/**
		 * @description Whether a DmlException occurred that was suppressed.
		 */
		private final Boolean hasDmlException;

		/**
		 * @description The DmlException that occurred, if any.
		 */
		private final DmlException dmlException;

		/**
		 * @description Constructs an empty success TransactionResult for no-op transactions.
		 */
		private TransactionResult()
		{
			this.insertResults = new List<Database.SaveResult>();
			this.updateResults = new List<Database.SaveResult>();
			this.upsertResults = new List<Database.UpsertResult>();
			this.deleteResults = new List<Database.DeleteResult>();
			this.undeleteResults = new List<Database.UndeleteResult>();
			this.hasDmlException = false;
			this.dmlException = null;
		}

		/**
		 * @description Constructs a TransactionResult from a completed DML_Transaction.
		 *
		 * @param dmlTransaction The transaction that was committed.
		 */
		private TransactionResult(DML_Transaction dmlTransaction)
		{
			this.insertResults = dmlTransaction.getInsertResults();
			this.updateResults = dmlTransaction.getUpdateResults();
			this.upsertResults = dmlTransaction.getUpsertResults();
			this.deleteResults = dmlTransaction.getDeleteResults();
			this.undeleteResults = dmlTransaction.getUndeleteResults();
			this.hasDmlException = false;
			this.dmlException = null;
		}

		/**
		 * @description Constructs a failure TransactionResult from a caught DmlException.
		 *
		 * @param error The DmlException that caused the failure.
		 */
		private TransactionResult(DmlException error)
		{
			this.insertResults = new List<Database.SaveResult>();
			this.updateResults = new List<Database.SaveResult>();
			this.upsertResults = new List<Database.UpsertResult>();
			this.deleteResults = new List<Database.DeleteResult>();
			this.undeleteResults = new List<Database.UndeleteResult>();
			this.hasDmlException = true;
			this.dmlException = error;
		}

		/**
		 * @description Returns true if all DML operations completed successfully.
		 *
		 * @return True if no failures occurred.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * DML_Builder.TransactionResult result = DML_Builder.newTransaction()
		 *     .doInsert(record)
		 *     .execute();
		 * Assert.isTrue(result.isSuccess(), 'Should succeed');
		 * ```
		 */
		global Boolean isSuccess()
		{
			if(hasDmlException)
			{
				return false;
			}
			return getFailureCount() == 0;
		}

		/**
		 * @description Returns the IDs of all successfully inserted records.
		 *
		 * @return List of inserted record IDs.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Id> newIds = result.getInsertedIds();
		 * ```
		 */
		global List<Id> getInsertedIds()
		{
			List<Id> ids = new List<Id>();
			for(Database.SaveResult result : insertResults)
			{
				if(result.isSuccess())
				{
					ids.add(result.getId());
				}
			}
			return ids;
		}

		/**
		 * @description Returns all errors from failed DML operations across all operation types.
		 *
		 * @return List of Database.Error objects from all failed operations.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Database.Error> errors = result.getErrors();
		 * ```
		 */
		global List<Database.Error> getErrors()
		{
			List<Database.Error> errors = new List<Database.Error>();

			for(Database.SaveResult result : insertResults)
			{
				if(!result.isSuccess())
				{
					errors.addAll(result.getErrors());
				}
			}
			for(Database.SaveResult result : updateResults)
			{
				if(!result.isSuccess())
				{
					errors.addAll(result.getErrors());
				}
			}
			for(Database.UpsertResult result : upsertResults)
			{
				if(!result.isSuccess())
				{
					errors.addAll(result.getErrors());
				}
			}
			for(Database.DeleteResult result : deleteResults)
			{
				if(!result.isSuccess())
				{
					errors.addAll(result.getErrors());
				}
			}
			for(Database.UndeleteResult result : undeleteResults)
			{
				if(!result.isSuccess())
				{
					errors.addAll(result.getErrors());
				}
			}

			return errors;
		}

		/**
		 * @description Returns the count of successful DML operations across all operation types.
		 *
		 * @return Number of successful operations.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer successCount = result.getSuccessCount();
		 * ```
		 */
		global Integer getSuccessCount()
		{
			if(hasDmlException)
			{
				return 0;
			}

			Integer count = 0;
			for(Database.SaveResult result : insertResults)
			{
				if(result.isSuccess())
				{
					count++;
				}
			}
			for(Database.SaveResult result : updateResults)
			{
				if(result.isSuccess())
				{
					count++;
				}
			}
			for(Database.UpsertResult result : upsertResults)
			{
				if(result.isSuccess())
				{
					count++;
				}
			}
			for(Database.DeleteResult result : deleteResults)
			{
				if(result.isSuccess())
				{
					count++;
				}
			}
			for(Database.UndeleteResult result : undeleteResults)
			{
				if(result.isSuccess())
				{
					count++;
				}
			}
			return count;
		}

		/**
		 * @description Returns the count of failed DML operations across all operation types.
		 *
		 * @return Number of failed operations.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer failureCount = result.getFailureCount();
		 * ```
		 */
		global Integer getFailureCount()
		{
			if(hasDmlException)
			{
				return dmlException.getNumDml();
			}

			Integer count = 0;
			for(Database.SaveResult result : insertResults)
			{
				if(!result.isSuccess())
				{
					count++;
				}
			}
			for(Database.SaveResult result : updateResults)
			{
				if(!result.isSuccess())
				{
					count++;
				}
			}
			for(Database.UpsertResult result : upsertResults)
			{
				if(!result.isSuccess())
				{
					count++;
				}
			}
			for(Database.DeleteResult result : deleteResults)
			{
				if(!result.isSuccess())
				{
					count++;
				}
			}
			for(Database.UndeleteResult result : undeleteResults)
			{
				if(!result.isSuccess())
				{
					count++;
				}
			}
			return count;
		}
	}

	/**
	 * @description Data holder for a registered DML operation.
	 */
	private class DTO_Operation
	{
		/**
		 * @description The type of DML operation.
		 */
		private final DatabaseOperation operationType;

		/**
		 * @description The records to operate on.
		 */
		private final List<SObject> records;

		/**
		 * @description The external ID field for upsert operations.
		 */
		private SObjectField externalIdField;

		/**
		 * @description The relationship field linking a child to a parent.
		 */
		private SObjectField relationshipField;

		/**
		 * @description The parent record for relationship-based operations.
		 */
		private SObject parentRecord;

		/**
		 * @description Constructs a new operation descriptor.
		 *
		 * @param operationType The type of DML operation.
		 * @param records The records to operate on.
		 */
		private DTO_Operation(DatabaseOperation operationType, List<SObject> records)
		{
			this.operationType = operationType;
			this.records = records;
		}
	}
}