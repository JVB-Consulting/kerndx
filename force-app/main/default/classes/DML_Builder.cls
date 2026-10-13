// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Fluent DML API for building and running database operations: you set it up by chaining
 * method calls. A static method, newTransaction(), starts a transaction. Chained methods add operations and
 * change how they run. A final method, execute(), saves all operations through DML_Transaction.
 *
 * @see DML_Builder_TEST
 * @see DML_Transaction
 *
 * @author Jason van Beukering
 *
 * @group DML
 *
 * @date February 2026, October 2026
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
	 * @description Message of the IllegalArgumentException a null expectRefusal() argument raises.
	 */
	private static final String ERROR_EXPECTED_REFUSAL_STATUS_CODE_REQUIRED = 'expectRefusal() requires a status code';

	/**
	 * @description The retries withRetryOnLock() applies when no count is given.
	 */
	private static final Integer DEFAULT_RETRIES_ON_LOCK = 1;

	/**
	 * @description The most retries withRetryOnLock(retries) accepts: each contended attempt can wait about ten seconds.
	 */
	private static final Integer MAXIMUM_RETRIES_ON_LOCK = 5;

	/**
	 * @description Message of the IllegalArgumentException withRetryOnLock raises for a count outside its range.
	 */
	private static final String ERROR_RETRIES_ON_LOCK_OUT_OF_RANGE = 'withRetryOnLock accepts 1 to ' + MAXIMUM_RETRIES_ON_LOCK + ' retries.';

	/**
	 * @description A test-only value for the check on how many DML rows one transaction may save. When it is not
	 * null, `execute()` uses it instead of `UTIL_Limits.dmlRows().maximum()`. This lets a unit test reach the
	 * over-the-limit case with a few records. Saving 10,001 real records would be far too slow, and would use up the
	 * CPU time limit before the check runs. Production code leaves this `null`.
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
	 * @description A record sharing choice that only the framework sets. It is null whenever the save runs in the
	 * caller's own transaction, and `execute()` then picks inherited sharing or no sharing from `isBypassSharing`.
	 * `PROC_ExecuteDML` sets it inside an async job. The job itself runs `without sharing`, so inherited sharing
	 * would not be safe there.
	 */
	private Boolean sharingEnforcementOverride;

	/**
	 * @description Whether to suppress LOG_Builder error logging.
	 */
	@TestVisible
	private Boolean isSuppressLogging = false;

	/**
	 * @description Status codes the caller declared as expected refusals through expectRefusal().
	 */
	@TestVisible
	private Set<StatusCode> expectedRefusalStatusCodes = new Set<StatusCode>();

	/**
	 * @description Explicit access level for DML operations. Null means "use the default that the
	 * `UserModeDml_Enabled` flag sets". Transactions a subscriber can start use the default; framework code
	 * chooses system mode with `.withSystemMode()`.
	 */
	@TestVisible
	private AccessLevel accessLevel;

	/**
	 * @description Whether to suppress DmlException re-throw in all-or-nothing mode.
	 */
	@TestVisible
	private Boolean isSuppressExceptions = false;

	/**
	 * @description How many times a commit refused for a row lock is tried again; null means the commit runs once.
	 */
	private Integer retriesOnLock;

	/**
	 * @description The bypass audit entries this builder will write for DML. The bypass audit records each time
	 * code skips the user's access checks. `bypassSharing` and `withSystemMode` add their entry to the queue with
	 * `auditQueue.queue(...)` when they are called. The two final methods, `execute()` and `async()`, first call
	 * `recordOperationFootprints()`, which adds the object and the operation of each registered save. They then
	 * call `auditQueue.flush()`. So a builder that is dropped before it runs writes nothing. The queue is created
	 * the first time it is used: when a bypass method is called, or when the builder runs.
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
	 * @description The framework's own version of `bypassSharing()`. It ignores record sharing for this save but adds no
	 * `BypassEvent` entry to the bypass audit. It is the save-side twin of `QRY_Builder.Builder.bypassSharingInternal()`.
	 * Only the framework's own saves that must reach every user's records use it, for example resolving the framework's
	 * own record of a failed request (an `ApiIssue__c`) whoever made the request. No subscriber is skipping a check in
	 * these saves, so they must not fill the audit trail. It is public, not global, so subscribers cannot call it.
	 * Application code that really needs to ignore sharing must call `bypassSharing()`, so the choice is audited.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .systemModeInternal()
	 *     .bypassSharingInternal()
	 *     .doUpdate(issues)
	 *     .execute();
	 * ```
	 */
	public DML_Builder bypassSharingInternal()
	{
		isBypassSharing = true;
		return this;
	}

	/**
	 * @description Sets record sharing explicitly for a save inside an async job. Only the framework calls this.
	 * When it is set, `execute()` passes this value to `DML_Transaction.commitWork`, instead of choosing inherited
	 * sharing or no sharing from the bypass flag. Inside an async job, a class with `inherited sharing` takes its
	 * sharing from the job, which runs `without sharing`. So the builder made inside the job must set ENFORCE or
	 * BYPASS itself, and must never use INHERITED there. This call writes no bypass audit entry. If the subscriber
	 * chose to ignore sharing, `bypassSharing()` already recorded that before the job was queued. Code that saves
	 * in its own transaction never calls this, so it still gets inherited sharing by default.
	 *
	 * @param enforceSharing True to enforce record sharing, false to bypass it.
	 *
	 * @return This builder instance for fluent chaining.
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	public DML_Builder withSharingEnforcement(Boolean enforceSharing)
	{
		this.sharingEnforcementOverride = enforceSharing;
		return this;
	}

	/**
	 * @description Forces `AccessLevel.USER_MODE` on every DML operation in this transaction,
	 * whatever the `UserModeDml_Enabled` feature flag says. Use it when a flow that serves your users must check
	 * object and field access (CRUD/FLS), even in orgs where an admin has turned the flag off.
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
	 * Use it when code must write objects that the running user is not meant to have object or field access
	 * (CRUD/FLS) to, such as logs, records that track background work, or other objects the framework owns.
	 * The choice is recorded in the bypass audit when the save runs.
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
	 * @description The framework's own version of `withSystemMode()`. It sets `AccessLevel.SYSTEM_MODE` but adds
	 * no `BypassEvent` entry to the bypass audit. Framework triggers and framework code use it to save the
	 * framework's own data, where system mode is always needed and no subscriber is skipping a check. An example is
	 * `TRG_PersistLogEntry`, which saves `LogEntry__c` rows after a `LogEntryEvent__e` arrives. Auditing these
	 * saves would cause two problems. First, the audit trail would fill with the framework's own routine work.
	 * Second, it would never stop: each audit entry publishes a new `LogEntryEvent__e`, and saving that event
	 * would write another audit entry. The method is public, not global, so subscribers cannot call it. Subscriber
	 * code that really needs system mode must call `withSystemMode()`, so the choice is audited.
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
	 * `.withUserMode()` or `.withSystemMode()` was called, returns that value. Otherwise returns
	 * the default that the `UserModeDml_Enabled` flag sets. Only tests call it, to check the choice.
	 *
	 * @return The effective `AccessLevel` for this transaction.
	 */
	@TestVisible
	private AccessLevel resolvedAccessLevel()
	{
		return accessLevel ?? DML_SharingProxy.defaultAccessLevel();
	}

	/**
	 * @description Turns off LOG_Builder error logging for DML failures. This covers the entry for each failed row
	 * of a partial save. It also covers the single ERROR entry the transaction writes when a save fails completely,
	 * or when partial mode catches an exception thrown during the save.
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
	 * @description Declares a refusal you expect and handle, so a row refused for that reason is logged at
	 * WARN instead of ERROR when the transaction allows partial success. Every other failed row still
	 * logs at ERROR, and the result is unchanged: the row still counts in `getFailureCount()` and
	 * `getErrors()`, and `isSuccess()` is still false. Call it once per status code. It has no effect in
	 * all-or-nothing mode, where any refusal fails the whole transaction. A row that also carries an error
	 * you did not declare logs at ERROR. The setting also applies after `.async()`. In a background job the log is
	 * the only place a refusal shows up, and the setting hides nothing there: the job logs the same refusal at WARN.
	 *
	 * @param statusCode The status code of the refusal you expect, such as `StatusCode.DUPLICATE_VALUE`
	 * for a unique field that blocks a second copy when two processes save the same record at the same time, a
	 * clash that does no harm.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @throws IllegalArgumentException When statusCode is null.
	 *
	 * @since 1.8
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doInsert(contacts)
	 *     .allowPartial()
	 *     .expectRefusal(StatusCode.DUPLICATE_VALUE)
	 *     .execute();
	 * ```
	 */
	global DML_Builder expectRefusal(StatusCode statusCode)
	{
		if(statusCode == null)
		{
			throw new IllegalArgumentException(ERROR_EXPECTED_REFUSAL_STATUS_CODE_REQUIRED);
		}
		this.expectedRefusalStatusCodes.add(statusCode);
		return this;
	}

	/**
	 * @description Tries the save again, once, when the platform refuses it because another transaction holds a
	 * record (UNABLE_TO_LOCK_ROW). This refusal is called a row lock. In all-or-nothing mode the whole save is rolled
	 * back and runs again. In partial mode only the rows refused for a lock are saved again, before the save moves
	 * on, and the rows that saved stay saved. Nothing else is retried: any other refusal is reported at once. There
	 * is no pause between attempts. The platform already waits up to about ten seconds for the lock before it
	 * refuses. So when another transaction holds the record, each attempt costs about ten seconds, and when none
	 * does, the setting costs nothing extra. The retries stop early when the DML limits left cannot cover another
	 * attempt. One WARN entry records a save that met a lock and then got through. A save still refused after its
	 * last attempt carries the same details on its ERROR entry. suppressLogging() turns off both. The setting also
	 * applies after .async(), where every batch applies it within its own limits. A retry cannot undo two things.
	 * Platform events published immediately during a rolled-back attempt are published again. And static values a
	 * failed attempt set, such as a trigger's own "already ran" flag, are not reset.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @since 1.8
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doUpdate(records)
	 *     .withRetryOnLock()
	 *     .execute();
	 * ```
	 */
	global DML_Builder withRetryOnLock()
	{
		return withRetryOnLock(DEFAULT_RETRIES_ON_LOCK);
	}

	/**
	 * @description Tries the save again up to the given number of times when the platform refuses it because
	 * another transaction holds a record (UNABLE_TO_LOCK_ROW). The count is the extra attempts after the first, from
	 * 1 to 5. Each attempt can wait about ten seconds when the record is held. A request that runs longer than five
	 * seconds in the user's own transaction counts toward the org's limit on long-running requests at the same
	 * time. So code that a user waits on should keep the default, and larger counts belong in asynchronous work.
	 * Everything else is as withRetryOnLock() describes.
	 *
	 * @param retries Extra attempts after the first, 1 to 5.
	 *
	 * @return This builder instance for fluent chaining.
	 *
	 * @throws IllegalArgumentException When retries is null or outside 1 to 5.
	 *
	 * @since 1.8
	 *
	 * @example
	 * ```apex
	 * DML_Builder.newTransaction()
	 *     .doUpdate(records)
	 *     .withRetryOnLock(3)
	 *     .async()
	 *     .execute();
	 * ```
	 */
	global DML_Builder withRetryOnLock(Integer retries)
	{
		if(retries == null || retries < 1 || retries > MAXIMUM_RETRIES_ON_LOCK)
		{
			throw new IllegalArgumentException(ERROR_RETRIES_ON_LOCK_OUT_OF_RANGE);
		}
		retriesOnLock = retries;
		return this;
	}

	/**
	 * @description Stops a DmlException from being thrown again in all-or-nothing mode. The failure shows on the
	 * returned TransactionResult instead of reaching the caller as an exception. The save's single ERROR entry,
	 * written in DML_Transaction.commitWork, still records it unless suppressLogging() is also set.
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
	 * @description Switches to asynchronous mode. Returns a DML_AsyncBuilder that hands the work to
	 * PROC_ExecuteDML and UTIL_AsynchronousJobLauncher, which pick a Queueable or Batch job to suit the volume.
	 *
	 * Five settings you made still apply in the job: the access mode (`.withUserMode()` or
	 * `.withSystemMode()`), partial success (`.allowPartial()`), ignoring record sharing
	 * (`.bypassSharing()`), the refusals you declared with `.expectRefusal()`, which the job logs
	 * at WARN as a save in your own transaction would, and the row-lock retry count (`.withRetryOnLock()`),
	 * which every batch applies within its own limits. The async job itself runs `without sharing`, so the job
	 * sets record sharing explicitly: enforced by default, ignored only when `.bypassSharing()` was called. The
	 * sharing of your own class does not carry into the job. `.suppressExceptions()` and `.suppressLogging()` are
	 * dropped on purpose. They change the return value and error logging of a save in your own transaction, and an
	 * async job has no caller to return a result to. The job's failures are always logged and reported through the
	 * async framework's own error handling.
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
		recordOperationFootprints();
		auditQueue.flush();
		return new DML_AsyncBuilder(this);
	}

	/**
	 * @description Adds each registered operation's object, operation name and row count to the audit queue, so
	 * that `flush()` writes one `BYPASS` entry for each object touched. It runs in the final methods, as the query
	 * builder does, so every `do*` method, now and in future, is covered without extra code in each one. It returns
	 * at once when the queue holds no bypass, so a save without a bypass costs only this one call. A list typed to
	 * one object counts as a single `recordOperation` call. Only a plain `List<SObject>` is counted record by
	 * record, so that a list mixing objects still counts each row against its own object. The operation name comes
	 * from the `DatabaseOperation` value (`DML_INSERT` becomes `insert`).
	 */
	private void recordOperationFootprints()
	{
		if(!auditQueue.hasPendingEmission())
		{
			return;
		}
		for(DTO_Operation operation : operations)
		{
			if(operation.records == null)
			{
				continue;
			}
			String verb = operation.operationType.name().substringAfter('_').toLowerCase();
			SObjectType listType = operation.records.getSObjectType();
			if(listType != null)
			{
				Integer concreteRows = 0;
				for(SObject record : operation.records)
				{
					if(record != null)
					{
						concreteRows++;
					}
				}
				if(concreteRows > 0)
				{
					auditQueue.recordOperation(String.valueOf(listType), verb, concreteRows);
				}
				continue;
			}
			for(SObject record : operation.records)
			{
				if(record == null)
				{
					continue;
				}
				auditQueue.recordOperation(String.valueOf(record.getSObjectType()), verb, 1);
			}
		}
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
		recordOperationFootprints();
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
		dmlTransaction.setExpectedRefusalStatusCodes(expectedRefusalStatusCodes);
		dmlTransaction.setAccessLevel(accessLevel);
		dmlTransaction.setRetryOnLock(retriesOnLock);

		for(DTO_Operation operation : operations)
		{
			registerOnTransaction(dmlTransaction, operation);
		}

		try
		{
			Boolean enforceSharing = sharingEnforcementOverride ?? (isBypassSharing ? false : null);
			dmlTransaction.commitWork(enforceSharing);
		}
		catch(DmlException error)
		{
			if(isSuppressExceptions)
			{
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
	 * @description Runs DML in an async job. It groups the registered operations by type and hands them to
	 * PROC_ExecuteDML through UTIL_AsynchronousJobLauncher, which picks a Queueable or Batch job to suit the volume.
	 * It carries these settings of the parent builder into the job: access mode, partial success, ignoring
	 * sharing, expected refusals and the row-lock retry count. The job enforces record sharing unless
	 * `.bypassSharing()` was called. The job itself runs `without sharing`, so inherited sharing cannot be used.
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
		 * @description The `AccessLevel` the caller chose on the parent `DML_Builder`. It is passed to
		 * `PROC_ExecuteDML`, so a subscriber's `.withUserMode()` or `.withSystemMode()` still applies when the job
		 * runs. `null` means the default that the `UserModeDml_Enabled` flag sets.
		 */
		private final AccessLevel accessLevel;

		/**
		 * @description Whether `.bypassSharing()` was called on the parent builder. It is passed to
		 * `PROC_ExecuteDML`, so the choice to ignore sharing, already recorded in the bypass audit, still applies
		 * when the job runs. Without it the job enforces record sharing by default.
		 */
		private final Boolean isBypassSharing;

		/**
		 * @description The parent builder's expected refusals, handed to `PROC_ExecuteDML` so the job logs
		 * them at WARN.
		 */
		private final Set<StatusCode> expectedRefusalStatusCodes;

		/**
		 * @description The parent builder's retry count for row-lock refusals, handed to `PROC_ExecuteDML` so every
		 * batch of the job applies the same retries inside its own limits. Null means none.
		 */
		private final Integer retriesOnLock;

		/**
		 * @description Optional batch size override.
		 */
		private Integer batchSize;

		/**
		 * @description Constructs a DML_AsyncBuilder that carries the parent builder's operations and
		 * the settings that still apply in the async job.
		 *
		 * @param parent The DML_Builder whose registered operations and settings to carry.
		 */
		private DML_AsyncBuilder(DML_Builder parent)
		{
			this.operations = parent.operations;
			this.isPartial = parent.isPartial;
			this.accessLevel = parent.accessLevel;
			this.isBypassSharing = parent.isBypassSharing;
			this.expectedRefusalStatusCodes = parent.expectedRefusalStatusCodes;
			this.retriesOnLock = parent.retriesOnLock;
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

				if(isBypassSharing == true)
				{
					processor.requestSharingBypass();
				}

				if(!expectedRefusalStatusCodes.isEmpty())
				{
					processor.expectRefusals(expectedRefusalStatusCodes);
				}

				if(retriesOnLock != null)
				{
					processor.retryOnLock(retriesOnLock);
				}

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