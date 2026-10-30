// SPDX-License-Identifier: BSD-3-Clause
/**
 * Copyright (c), FinancialForce.com, inc
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 * - Neither the name of the FinancialForce.com, inc nor the names of its contributors
 * may be used to endorse or promote products derived from this software without
 * specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * @description The engine that saves a set of DML operations across many SObjects as one transaction. This set is
 * called a unit of work: the records registered to be saved together. By default, if one record fails, the whole save
 * is rolled back. In partial mode, the records that save stay saved. The engine saves parent object types before their
 * children, by sorting the types so each parent comes first. It fills each child's
 * lookup with its parent's new Id. It also offers hooks, methods a subclass can override to run its own code at
 * fixed points of the save.
 *
 * @see DML_Transaction_TEST
 * @see DML_Builder
 * @see DML_SharingProxy
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
 * DML_Transaction aTransaction = new DML_Transaction();
 * aTransaction.registerInsert(account);
 * aTransaction.registerInsert(contact, Contact.AccountId, account);
 * aTransaction.commitWork();
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.AvoidGlobalModifier,PMD.ExcessivePublicCount,PMD.ExcessiveClassLength,PMD.NcssCount,PMD.NcssTypeCount')
global virtual inherited sharing class DML_Transaction
{
	/**
	 * @description The kind of database write a record in the transaction is waiting for. When the transaction is committed the
	 * writes go to the database one kind at a time, in the order listed here: undeletes, inserts, upserts, updates, deletes.
	 */
	private enum OperationType
	{
		/**
		 * @description Restores a deleted record from the Recycle Bin. Restores are written before any other kind, and a record
		 * queued twice is restored once.
		 */
		DML_UNDELETE,
		/**
		 * @description Creates a new record. Parent object types are created before their child types, whatever order the records
		 * were queued in, and each new parent Id is then copied onto its waiting children.
		 */
		DML_INSERT,
		/**
		 * @description Creates the record when it does not exist yet and updates it when it does, matched on the record Id or on
		 * the external Id field chosen for the object type.
		 */
		DML_UPSERT,
		/**
		 * @description Saves changes to a record that already exists. Updates are written after the inserts and upserts, and a
		 * record queued twice is updated once.
		 */
		DML_UPDATE,
		/**
		 * @description Deletes an existing record. Deletes are written after every other kind, and a record queued twice is
		 * deleted once.
		 */
		DML_DELETE
	}

	/**
	 * @description Class and method name for logging context in commitWork.
	 */
	@TestVisible
	private static final String CLASS_METHOD_COMMIT = DML_Transaction.class.getName() + '.commitWork';

	/**
	 * @description Context key for the outcome of a partial-mode save. It is set on the log entry written when a
	 * DML statement throws an exception and partial mode catches it.
	 */
	@TestVisible
	private static final String CONTEXT_KEY_PARTIAL_COMMIT_OUTCOME = 'partialCommitOutcome';

	/**
	 * @description Context value that says what a partial-mode save did with an exception thrown during the save:
	 * the statements that had already saved stay saved, and the registered operations not yet run never ran.
	 */
	@TestVisible
	private static final String MESSAGE_STATEMENT_FAILURE_SWALLOWED = 'Partial mode swallowed this exception raised during the commit: '
			+ 'statements that had already committed stand, and registered operations not yet performed never ran.';

	/**
	 * @description The status code the platform reports when another transaction holds a record (a row lock). The
	 * message of a thrown refusal also contains this name, and isLockRefusalException looks for it there.
	 */
	@TestVisible
	private static final String LOCK_REFUSAL_TOKEN = StatusCode.UNABLE_TO_LOCK_ROW.name();

	/**
	 * @description Context key: how many retries the commit used before it saved or gave up.
	 */
	@TestVisible
	private static final String CONTEXT_KEY_RETRIES_USED = 'retriesUsed';

	/**
	 * @description Context key: how many rows a partial commit recovered through a retry.
	 */
	@TestVisible
	private static final String CONTEXT_KEY_ROWS_RECOVERED = 'rowsRecovered';

	/**
	 * @description Context key: how many rows a partial commit still had refused after its last round.
	 */
	@TestVisible
	private static final String CONTEXT_KEY_ROWS_STILL_REFUSED = 'rowsStillRefused';

	/**
	 * @description Context key: what stopped the retries, if they stopped. Either the retry count ran out, or the
	 * headroom guard stopped them. The headroom guard is the check that enough DML limits are left for another attempt.
	 */
	@TestVisible
	private static final String CONTEXT_KEY_RETRY_STOPPED_BY = 'retryStoppedBy';

	/**
	 * @description Context value: the configured retry count was used up.
	 */
	@TestVisible
	private static final String RETRY_STOPPED_BY_COUNT = 'count';

	/**
	 * @description Context value: the remaining DML limits could not cover another attempt.
	 */
	@TestVisible
	private static final String RETRY_STOPPED_BY_HEADROOM = 'headroom';

	/**
	 * @description The message of the WARN entry a save writes when it met a row lock: either a retry ran, or the
	 * headroom guard stopped the partial-mode retry rounds before one could run.
	 */
	@TestVisible
	private static final String MESSAGE_RETRY_SUMMARY = 'The platform refused a row lock during this commit; the context carries the retry outcome.';

	/**
	 * @description A value a test sets for the headroom guard: the number of DML statements the guard treats as
	 * left. Null, the default and the production value, reads the real limit. A test cannot really use up 150
	 * statements to reach the guard, so it sets this instead.
	 */
	@TestVisible
	private static Integer remainingDmlStatementsForTest;

	/**
	 * @description A value a test sets for the headroom guard: the number of DML rows the guard treats as left.
	 * Null reads the real limit.
	 */
	@TestVisible
	private static Integer remainingDmlRowsForTest;

	/**
	 * @description Whether to allow partial success for DML operations.
	 */
	@TestVisible
	private Boolean allowPartial = false;

	/**
	 * @description Whether to suppress LOG_Builder error logging for partial results and commit failures.
	 */
	@TestVisible
	private Boolean suppressLogging = false;

	/**
	 * @description Status codes the caller declared as expected refusals. In partial mode a failed row whose
	 * errors all carry one of them is logged at WARN instead of ERROR. Empty by default, which keeps every
	 * failed row at ERROR.
	 */
	@TestVisible
	private Set<StatusCode> expectedRefusalStatusCodes = new Set<StatusCode>();

	/**
	 * @description Access level to apply on every DML operation. Null means "use the default that the
	 * `UserModeDml_Enabled` flag sets". Code a subscriber can reach uses the default; framework code chooses
	 * explicitly with `DML_Builder.withSystemMode()` or by calling `setAccessLevel()` directly.
	 */
	@TestVisible
	private AccessLevel accessLevel;

	/**
	 * @description How many times a save refused for a row lock is tried again. Zero, the default, means the
	 * save runs once.
	 */
	@TestVisible
	private Integer retriesOnLock = 0;

	/**
	 * @description Retries the current commit has used; reset at the start of every commit.
	 */
	private Integer retriesUsed = 0;

	/**
	 * @description Rows a partial commit recovered through a retry; reset at the start of every commit.
	 */
	private Integer rowsRecovered = 0;

	/**
	 * @description Rows a partial commit still had refused after its last round; reset at the start of every commit.
	 */
	private Integer rowsStillRefused = 0;

	/**
	 * @description What stopped the retries when they stopped: RETRY_STOPPED_BY_COUNT or RETRY_STOPPED_BY_HEADROOM.
	 */
	private String retryStoppedBy;

	/**
	 * @description The DML statements the save still has to run. A partial-mode retry round keeps this many
	 * statements free, so the rest of the save can still run.
	 */
	private Integer statementsStillPlanned = 0;

	/**
	 * @description For the update and the undelete, the extra statement counted in statementsStillPlanned because
	 * DML_SharingProxy.PermissionKeepingProxy may split that statement in two: 1 or 0. The step that runs the
	 * statement takes this off statementsStillPlanned together with the statement itself.
	 */
	private final Map<OperationType, Integer> statementsAddedBySplitByKind = new Map<OperationType, Integer>();

	/**
	 * @description Relationships registered via registerDirty (update with relationship).
	 */
	private final List<DTO_Relationship> registeredDirtyRelationships;

	/**
	 * @description All objects grouped by operation type and SObject type.
	 */
	private final Map<OperationType, Map<SObjectType, List<SObject>>> allObjectsToCommit;

	/**
	 * @description Parent-to-child relationship map for populating foreign keys after parent insert/upsert.
	 */
	private final Map<SObjectType, List<DTO_Relationship>> parentToChildRelationshipsMap;

	/**
	 * @description Dependency graph for topological sorting of SObject types.
	 */
	private final Map<SObjectType, Set<SObjectType>> objectTypeDependencyMap;

	/**
	 * @description External ID field mapping per SObject type for upsert operations.
	 */
	private final Map<SObjectType, SObjectField> upsertExternalIdFieldMap;

	/**
	 * @description Collected insert results from committed DML operations.
	 */
	private final List<Database.SaveResult> collectedInsertResults;

	/**
	 * @description Collected update results from committed DML operations.
	 */
	private final List<Database.SaveResult> collectedUpdateResults;

	/**
	 * @description Collected upsert results from committed DML operations.
	 */
	private final List<Database.UpsertResult> collectedUpsertResults;

	/**
	 * @description Collected delete results from committed DML operations.
	 */
	private final List<Database.DeleteResult> collectedDeleteResults;

	/**
	 * @description Collected undelete results from committed DML operations.
	 */
	private final List<Database.UndeleteResult> collectedUndeleteResults;

	/**
	 * @description Initializes a new transaction with empty collections for managing DML operations.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * ```
	 */
	global DML_Transaction()
	{
		allObjectsToCommit = new Map<OperationType, Map<SObjectType, List<SObject>>>();
		objectTypeDependencyMap = new Map<SObjectType, Set<SObjectType>>();
		parentToChildRelationshipsMap = new Map<SObjectType, List<DTO_Relationship>>();
		registeredDirtyRelationships = new List<DTO_Relationship>();
		upsertExternalIdFieldMap = new Map<SObjectType, SObjectField>();
		collectedInsertResults = new List<Database.SaveResult>();
		collectedUpdateResults = new List<Database.SaveResult>();
		collectedUpsertResults = new List<Database.UpsertResult>();
		collectedDeleteResults = new List<Database.DeleteResult>();
		collectedUndeleteResults = new List<Database.UndeleteResult>();
	}

	/**
	 * @description Saves a record by inserting (if no Id) or updating (if Id exists).
	 * Convenience method for mixed operations.
	 *
	 * @param record The SObject to save.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doSave(new Account(Name = 'Test'));
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global void doSave(SObject record)
	{
		if(record.Id == null)
		{
			doInsert(record);
		}
		else
		{
			doUpdate(record);
		}
	}

	/**
	 * @description Registers a record for insertion.
	 *
	 * @param record The SObject to insert.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doInsert(new Account(Name = 'Test'));
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global void doInsert(SObject record)
	{
		addObjectToOperationMap(OperationType.DML_INSERT, record);
	}

	/**
	 * @description Registers multiple records for insertion.
	 *
	 * @param records The list of SObjects to insert.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doInsert(new List<Account>{new Account(Name = 'A'), new Account(Name = 'B')});
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global void doInsert(List<SObject> records)
	{
		for(SObject record : records)
		{
			doInsert(record);
		}
	}

	/**
	 * @description Registers a child record for insertion with a relationship to a parent record.
	 * The child's relationship field will be populated with the parent's Id after commit.
	 *
	 * @param child The child SObject to insert.
	 * @param relationshipField The field linking the child to the parent (e.g., Contact.AccountId).
	 * @param parent The parent SObject.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * Account parent = new Account(Name = 'Parent');
	 * Contact child = new Contact(LastName = 'Child');
	 * dmlTransaction.doInsert(parent);
	 * dmlTransaction.doInsert(child, Contact.AccountId, parent);
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global void doInsert(SObject child, SObjectField relationshipField, SObject parent)
	{
		doInsert(child);
		registerRelationship(parent, relationshipField, child);
	}

	/**
	 * @description Registers a record for update.
	 *
	 * @param record The SObject to update.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doUpdate(existingAccount);
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global void doUpdate(SObject record)
	{
		addObjectToOperationMap(OperationType.DML_UPDATE, record);
	}

	/**
	 * @description Registers multiple records for update.
	 *
	 * @param records The list of SObjects to update.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doUpdate(existingAccounts);
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global void doUpdate(List<SObject> records)
	{
		for(SObject record : records)
		{
			doUpdate(record);
		}
	}

	/**
	 * @description Registers a record for update with a relationship to a parent record.
	 *
	 * @param record The SObject to update.
	 * @param relationshipField The field linking the record to the parent.
	 * @param parent The parent SObject whose Id will be set on the relationship field.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doUpdate(contact, Contact.AccountId, newAccount);
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global void doUpdate(SObject record, SObjectField relationshipField, SObject parent)
	{
		doUpdate(record);
		registeredDirtyRelationships.add(new DTO_Relationship(parent, relationshipField, record));
	}

	/**
	 * @description Registers a record for deletion.
	 *
	 * @param record The SObject to delete.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doDelete(obsoleteRecord);
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global void doDelete(SObject record)
	{
		addObjectToOperationMap(OperationType.DML_DELETE, record);
	}

	/**
	 * @description Registers multiple records for deletion.
	 *
	 * @param records The list of SObjects to delete.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doDelete(obsoleteRecords);
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global void doDelete(List<SObject> records)
	{
		for(SObject record : records)
		{
			doDelete(record);
		}
	}

	/**
	 * @description Registers a record for upsert using a specific external ID field.
	 * All records of the same SObjectType within a single transaction must use the same external ID field.
	 *
	 * @param record The SObject to upsert.
	 * @param externalIdField The external ID field for matching.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doUpsert(account, Account.ExternalId__c);
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global void doUpsert(SObject record, SObjectField externalIdField)
	{
		SObjectType objectType = record.getSObjectType();
		SObjectField existingField = upsertExternalIdFieldMap.get(objectType);

		if(existingField != null && existingField != externalIdField)
		{
			throw new UTIL_Exceptions.IllegalStateException
					(
							'Cannot use different external ID fields for the same SObjectType in a single transaction. ' +
							'Type: ' + objectType + ', Existing field: ' + existingField + ', New field: ' + externalIdField
					);
		}

		upsertExternalIdFieldMap.put(objectType, externalIdField);
		addObjectToOperationMap(OperationType.DML_UPSERT, record);
	}

	/**
	 * @description Registers multiple records for upsert using a specific external ID field.
	 *
	 * @param records The list of SObjects to upsert.
	 * @param externalIdField The external ID field for matching.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doUpsert(accounts, Account.ExternalId__c);
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global void doUpsert(List<SObject> records, SObjectField externalIdField)
	{
		for(SObject record : records)
		{
			doUpsert(record, externalIdField);
		}
	}

	/**
	 * @description Registers a child record for upsert with a parent relationship and external ID field.
	 *
	 * @param child The child SObject to upsert.
	 * @param relationshipField The field linking the child to the parent.
	 * @param externalIdField The external ID field for matching.
	 * @param parent The parent SObject.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doUpsert(child, Contact.AccountId, Contact.ExternalId__c, parent);
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global void doUpsert(SObject child, SObjectField relationshipField, SObjectField externalIdField, SObject parent)
	{
		doUpsert(child, externalIdField);
		registerRelationship(parent, relationshipField, child);
	}

	/**
	 * @description Registers a record for upsert without an external ID field.
	 * Uses the record's Id field for matching if present.
	 *
	 * @param record The SObject to upsert.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doUpsert(account);
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global void doUpsert(SObject record)
	{
		addObjectToOperationMap(OperationType.DML_UPSERT, record);
	}

	/**
	 * @description Registers multiple records for upsert without an external ID field.
	 *
	 * @param records The list of SObjects to upsert.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doUpsert(accounts);
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global void doUpsert(List<SObject> records)
	{
		for(SObject record : records)
		{
			doUpsert(record);
		}
	}

	/**
	 * @description Registers a record for undelete.
	 *
	 * @param record The SObject to undelete.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doUndelete(deletedAccount);
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global void doUndelete(SObject record)
	{
		addObjectToOperationMap(OperationType.DML_UNDELETE, record);
	}

	/**
	 * @description Registers multiple records for undelete.
	 *
	 * @param records The list of SObjects to undelete.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doUndelete(deletedAccounts);
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global void doUndelete(List<SObject> records)
	{
		for(SObject record : records)
		{
			doUndelete(record);
		}
	}

	/**
	 * @description Sets whether partial success is allowed for DML operations.
	 * When enabled, failed records do not cause the entire transaction to roll back.
	 *
	 * @param allow True to allow partial success, false for all-or-nothing (default).
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.setAllowPartial(true);
	 * dmlTransaction.doInsert(records);
	 * dmlTransaction.commitWork();
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	global void setAllowPartial(Boolean allow)
	{
		this.allowPartial = allow;
	}

	/**
	 * @description Sets whether to turn off LOG_Builder error logging for DML failures. When it is on, failed rows
	 * in a partial save are not logged, and neither is a failed save. That covers the ERROR entry an all-or-nothing
	 * save writes after it rolls back, just before it throws the exception again. It also covers the ERROR entry a
	 * partial save writes when it catches an exception thrown during the save and carries on. It also covers the
	 * warning `commitWork(false)` logs in user mode when it leaves out fields the user cannot create or edit.
	 *
	 * @param suppress True to suppress logging, false to allow logging (default).
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.setAllowPartial(true);
	 * dmlTransaction.setSuppressLogging(true);
	 * dmlTransaction.doInsert(records);
	 * dmlTransaction.commitWork();
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	global void setSuppressLogging(Boolean suppress)
	{
		this.suppressLogging = suppress;
	}

	/**
	 * @description Declares the status codes of refusals the caller expects and handles. In partial mode a
	 * failed row whose errors all carry one of them is logged at WARN instead of ERROR; every other failed
	 * row still logs at ERROR, and the save's results are unchanged. Only the package itself calls this:
	 * `DML_Builder` passes its `expectRefusal()` declarations to the transaction through this method.
	 *
	 * @param statusCodes The expected status codes; null means none.
	 */
	public void setExpectedRefusalStatusCodes(Set<StatusCode> statusCodes)
	{
		this.expectedRefusalStatusCodes = statusCodes ?? new Set<StatusCode>();
	}

	/**
	 * @description Sets how many times a save refused for a row lock is tried again. Only the package itself calls
	 * this. Callers set the count through DML_Builder.withRetryOnLock, and in an async job PROC_ExecuteDML passes
	 * the count to each batch.
	 *
	 * @param retries Extra attempts after the first; null, zero or a negative count means the commit runs once.
	 *
	 * @example
	 * ```apex
	 * dmlTransaction.setRetryOnLock(1);
	 * ```
	 */
	public void setRetryOnLock(Integer retries)
	{
		retriesOnLock = Math.max(retries ?? 0, 0);
	}

	/**
	 * @description Sets the `AccessLevel` passed to every DML operation through the `DML_SharingProxy` methods
	 * that take an access level. When it is null, the proxy uses the default that the `UserModeDml_Enabled`
	 * flag sets.
	 *
	 * @param accessLevel The `AccessLevel` to apply; null to use the default that the flag sets.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction transaction = new DML_Transaction();
	 * transaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
	 * transaction.doInsert(records);
	 * transaction.commitWork();
	 * ```
	 */
	global void setAccessLevel(AccessLevel accessLevel)
	{
		this.accessLevel = accessLevel;
	}

	/**
	 * @description Commits all registered DML operations using inherited sharing.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doInsert(new Account(Name = 'Test'));
	 * dmlTransaction.commitWork();
	 * ```
	 */
	global virtual void commitWork()
	{
		commitWork(null);
	}

	/**
	 * @description Saves all registered DML operations, with the record sharing you choose. A retry count can be set,
	 * usually through DML_Builder.withRetryOnLock. When it is set and the platform refuses a row lock, the save is
	 * rolled back and runs again. The hooks run once for each attempt. Static values a failed attempt set are not
	 * reset. A retry puts back the registered records as they were when commitWork was called. Records a hook
	 * registers during an attempt are not put back, and a record the hook registers again keeps the Id the
	 * rolled-back attempt gave it. Every attempt empties the transaction's in-memory query cache (the query results
	 * kept in memory for reuse) before its first statement and again when it ends, whatever the outcome. So a read
	 * after a save never gets rows from before the save, or from a save that was rolled back.
	 *
	 * In user mode (no access level set while the `UserModeDml_Enabled` flag is on, or
	 * `setAccessLevel(AccessLevel.USER_MODE)`), enforceSharing set to false still keeps the running user's object and
	 * field permissions. A field the user cannot create or edit is left out of the save and logged
	 * as a warning, with no error. A save the user has no object permission for, an upsert on an external Id field the
	 * user cannot read or edit, and a save that would leave out the field that links a record to its parent are
	 * refused as user mode refuses them. A record that names its parent only by an external Id the user cannot read is
	 * refused by Salesforce, with a message that does not name the field. These checks use only the running user's own
	 * permissions. When user mode is set with a permission set, through
	 * `setAccessLevel(AccessLevel.USER_MODE.withPermissionSetId(permissionSetId))`, a field that only the permission
	 * set lets the user edit is still left out. A refused save is sent with that access level, so the platform takes
	 * the permission set into account when it decides. That save runs in user mode, so it also applies record
	 * sharing. In system mode, set through `setAccessLevel(AccessLevel.SYSTEM_MODE)` or by turning the flag off, false
	 * waives those permission checks too.
	 *
	 * @param enforceSharing True enforces the running user's record sharing, null uses the calling class's sharing, and
	 * false ignores record sharing.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doUpdate(recordOwnedByAnotherUser);
	 * // Ignores record sharing; the running user's object and field permissions still apply.
	 * dmlTransaction.commitWork(false);
	 * DML_Transaction systemTransaction = new DML_Transaction();
	 * systemTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
	 * systemTransaction.doUpdate(recordOwnedByAnotherUser);
	 * // Ignores record sharing and the running user's object and field permissions.
	 * systemTransaction.commitWork(false);
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	global virtual void commitWork(Boolean enforceSharing)
	{
		retriesUsed = 0;
		rowsRecovered = 0;
		rowsStillRefused = 0;
		retryStoppedBy = null;
		RegistrationSnapshot snapshot = retriesOnLock > 0 && !allowPartial ? new RegistrationSnapshot(this) : null;
		Boolean keepsUserPermissions = enforceSharing == false
				&& DML_SharingProxy.matchesAccessLevel(accessLevel ?? DML_SharingProxy.defaultAccessLevel(), System.AccessLevel.USER_MODE);

		while(true)
		{
			statementsStillPlanned = countPlannedStatements(keepsUserPermissions);
			try
			{
				commitAttempt(enforceSharing, keepsUserPermissions);
				break;
			}
			catch(RetryAttemptException signal)
			{
				retriesUsed++;
				snapshot.restore();
			}
		}

		logRetrySummary();
	}

	/**
	 * @description One attempt at the save. It sets the savepoint, runs the hooks, runs the statements through the
	 * sharing proxy with parents first, and rolls back on failure. When nothing is registered, no savepoint is set
	 * before onCommitWorkStarting runs. If that hook then registers work, the savepoint is set before the first
	 * statement, so a later failure rolls back the hook's work too. If the hook registers nothing, there is no
	 * savepoint. A failure on that path then skips the rollback, and the exception is logged and thrown again
	 * unchanged. After the rollback, a lock refusal that may be retried is passed to commitWork as a
	 * RetryAttemptException. Every other failure is logged, unless logging is turned off, and thrown again. When a
	 * partial save is allowed, there is no rollback and the failure is logged, not thrown. Every attempt empties the
	 * transaction's in-memory query cache before its first statement and again when it ends, whatever the outcome.
	 * So a read after a save never gets rows from before the save, or from a save that was rolled back. Rows cached
	 * during the save are not kept, because they may be older than the save: a read in a before trigger has the
	 * values before the save, and a read of a parent has its roll-up totals before they were updated.
	 *
	 * @param enforceSharing If true, enforces sharing; if false, bypasses sharing; if null, inherits sharing.
	 * @param keepsUserPermissions True when the save ignores record sharing but would otherwise run in user mode. The
	 * statements then go through DML_SharingProxy.PermissionKeepingProxy, which saves in system mode and keeps the
	 * running user's object and field permissions.
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	private void commitAttempt(Boolean enforceSharing, Boolean keepsUserPermissions)
	{
		// A write can change any cached read (roll-ups, formulas, parent fields, cascades, sharing), and trigger
		// actions fire inside the write, so the query cache is emptied before anything reaches the database.
		QRY_Engine.clearQueryResultMemoryCache();
		Boolean wasSuccessful = true;
		Integer statementsAtStart = UTIL_Limits.dmlStatements().used();
		Integer rowsAtStart = UTIL_Limits.dmlRows().used();
		SavePoint savePoint = allObjectsToCommit.isEmpty() ? null : Database.setSavepoint();

		try
		{
			onCommitWorkStarting();

			if(!allObjectsToCommit.isEmpty())
			{
				savePoint = savePoint ?? Database.setSavepoint();
				onDMLStarting();

				DML_SharingProxy.SharingType shareType = enforceSharing == null
						? DML_SharingProxy.SharingType.INHERITED
						: enforceSharing
								? DML_SharingProxy.SharingType.ENFORCE
								: DML_SharingProxy.SharingType.BYPASS;

				DML_SharingProxy.DatabaseProxy databaseProxy = DML_SharingProxy.getSharingProxy(shareType);
				if(keepsUserPermissions)
				{
					databaseProxy = newPermissionKeepingProxy(databaseProxy);
				}

				performUndeletes(databaseProxy);
				performInserts(databaseProxy);
				performUpserts(databaseProxy);
				performUpdates(databaseProxy);
				performDeletes(databaseProxy);

				onDMLFinished();
				onCommitWorkFinishing();
			}
		}
		catch(Exception error)
		{
			wasSuccessful = false;

			if(!allowPartial)
			{
				if(savePoint != null)
				{
					Database.rollback(savePoint);
					Database.releaseSavepoint(savePoint);
				}
				if(canRetryCommit(error, UTIL_Limits.dmlStatements().used() - statementsAtStart, UTIL_Limits.dmlRows().used() - rowsAtStart))
				{
					throw new RetryAttemptException(error);
				}
				if(!suppressLogging)
				{
					logCommitFailure(error);
				}
				throw error;
			}

			if(!suppressLogging)
			{
				LOG_Builder.build().error(error).withContext(CONTEXT_KEY_PARTIAL_COMMIT_OUTCOME, MESSAGE_STATEMENT_FAILURE_SWALLOWED).at(CLASS_METHOD_COMMIT).emit();
			}
		}
		finally
		{
			// Rows cached during the save may be older than it (before-trigger reads, roll-ups) or show a save that was rolled back, so empty them.
			QRY_Engine.clearQueryResultMemoryCache();
			onCommitWorkFinished(wasSuccessful);
		}
	}

	/**
	 * @description Puts a proxy that keeps the running user's object and field permissions around the given proxy, and
	 * tells it which records wait for a parent's Id: the children registered with a parent, for insert and update. The
	 * new proxy refuses a statement that would leave such a field out, because the child would then be saved with no
	 * parent and no error. It also tells the new proxy whether logging is turned off, so it logs no warning then.
	 *
	 * @param innerProxy The proxy that runs each statement.
	 *
	 * @return The proxy every statement of this attempt goes through, a retried statement included.
	 */
	private DML_SharingProxy.PermissionKeepingProxy newPermissionKeepingProxy(DML_SharingProxy.DatabaseProxy innerProxy)
	{
		DML_SharingProxy.PermissionKeepingProxy proxy = new DML_SharingProxy.PermissionKeepingProxy(innerProxy, suppressLogging);
		for(List<DTO_Relationship> relationships : parentToChildRelationshipsMap.values())
		{
			for(DTO_Relationship relationship : relationships)
			{
				proxy.addParentLink(relationship.childRecord, relationship.relationshipField);
			}
		}
		for(DTO_Relationship relationship : registeredDirtyRelationships)
		{
			proxy.addParentLink(relationship.childRecord, relationship.relationshipField);
		}
		return proxy;
	}

	/**
	 * @description Writes the failure entry of an all-or-nothing save that will not run again. The retry details are
	 * added only when a retry count was set, so a caller who never asked for a retry sees no retry details.
	 *
	 * @param error The failure being rethrown.
	 */
	private void logCommitFailure(Exception error)
	{
		LOG_Builder.LogEntry entry = LOG_Builder.build().error(error).at(CLASS_METHOD_COMMIT);
		if(retriesOnLock > 0)
		{
			addRetryContext(entry);
		}
		entry.emit();
	}

	/**
	 * @description Whether commitWork may run the save again after this failure. Three things must hold: the refusal
	 * is a row lock, retries are left, and the limits left still cover what the failed attempt used. That use is
	 * measured, not guessed: its savepoint, its statements and its rollback. When the retries stop, this method
	 * records what stopped them.
	 *
	 * @param error The failure of the attempt that just rolled back.
	 * @param statementsUsed The DML statements the attempt consumed.
	 * @param rowsUsed The DML rows the attempt consumed.
	 *
	 * @return True when the commit should run again.
	 */
	private Boolean canRetryCommit(Exception error, Integer statementsUsed, Integer rowsUsed)
	{
		if(retriesOnLock == 0 || !isLockRefusalException(error))
		{
			return false;
		}
		if(retriesUsed >= retriesOnLock)
		{
			retryStoppedBy = RETRY_STOPPED_BY_COUNT;
			return false;
		}
		if(remainingDmlStatements() < statementsUsed || remainingDmlRows() < rowsUsed)
		{
			retryStoppedBy = RETRY_STOPPED_BY_HEADROOM;
			return false;
		}
		return true;
	}

	/**
	 * @description The DML statements the headroom guard treats as left: the value a test set, if any, else the real limit.
	 *
	 * @return Remaining DML statements.
	 */
	private static Integer remainingDmlStatements()
	{
		return remainingDmlStatementsForTest ?? UTIL_Limits.dmlStatements().remaining();
	}

	/**
	 * @description The DML rows the headroom guard treats as left: the value a test set, if any, else the real limit.
	 *
	 * @return Remaining DML rows.
	 */
	private static Integer remainingDmlRows()
	{
		return remainingDmlRowsForTest ?? UTIL_Limits.dmlRows().remaining();
	}

	/**
	 * @description Whether a thrown failure is the platform's row-lock refusal: a DmlException whose message contains
	 * UNABLE_TO_LOCK_ROW. The method reads the message, not the rows, because a DmlException built in a test has no
	 * rows. The platform's message names the status code of the first refused row.
	 *
	 * @param error The failure to classify.
	 *
	 * @return True when the failure is a lock refusal.
	 */
	@TestVisible
	private static Boolean isLockRefusalException(Exception error)
	{
		return error instanceof DmlException && error.getMessage() != null && error.getMessage().contains(LOCK_REFUSAL_TOKEN);
	}

	/**
	 * @description Whether a DML result is a row refused only for a lock: it failed, and every error it carries is
	 * UNABLE_TO_LOCK_ROW. A row that also carries another error would be refused again, so it is not retried.
	 *
	 * @param result The DML result to classify.
	 *
	 * @return True when the row was refused only for a lock.
	 */
	@TestVisible
	private static Boolean isLockRefusedRow(Object result)
	{
		List<Database.Error> errors = LOG_Engine.getOperationErrors(result);

		if(errors.isEmpty())
		{
			return false;
		}

		for(Database.Error error : errors)
		{
			if(error.getStatusCode() != StatusCode.UNABLE_TO_LOCK_ROW)
			{
				return false;
			}
		}

		return true;
	}

	/**
	 * @description Adds the retry counters to a log entry: retries used, rows recovered, rows still refused, and what
	 * stopped the retries when something did.
	 *
	 * @param entry The entry to enrich.
	 */
	private void addRetryContext(LOG_Builder.LogEntry entry)
	{
		entry.withContext(CONTEXT_KEY_RETRIES_USED, retriesUsed).withContext(CONTEXT_KEY_ROWS_RECOVERED, rowsRecovered);
		entry.withContext(CONTEXT_KEY_ROWS_STILL_REFUSED, rowsStillRefused);
		if(retryStoppedBy != null)
		{
			entry.withContext(CONTEXT_KEY_RETRY_STOPPED_BY, retryStoppedBy);
		}
	}

	/**
	 * @description Writes the one WARN entry a save must write when it met a row lock, unless logging is turned off.
	 * A save meets a row lock when a retry ran, when rows were saved on a retry, or when rows stayed refused because
	 * the headroom guard stopped the partial-mode retry rounds. An all-or-nothing save that never got through does
	 * not reach this method: its refusal was already thrown and logged as a failure.
	 */
	private void logRetrySummary()
	{
		if(suppressLogging || (retriesUsed == 0 && rowsRecovered == 0 && rowsStillRefused == 0))
		{
			return;
		}
		LOG_Builder.LogEntry entry = LOG_Builder.build().warn(MESSAGE_RETRY_SUMMARY).at(CLASS_METHOD_COMMIT);
		addRetryContext(entry);
		entry.emit();
	}

	/**
	 * @description Counts the DML statements the save will run: one for all undeletes, one for each inserted type,
	 * one for each upserted type, one for all updates, and one for each deleted type. The update count includes the
	 * update the save adds midway when a record looks up to a parent of its own type. When the statements go through
	 * DML_SharingProxy.PermissionKeepingProxy and a partial save is allowed, the update or the undelete of records of
	 * more than one object may be split in two: one statement for the objects the user may save, and one for the
	 * objects the user may not. Each such statement counts as two (see countStatementsAddedBySplit). A partial-mode
	 * retry round keeps this many statements free.
	 *
	 * @param keepsUserPermissions True when the statements go through DML_SharingProxy.PermissionKeepingProxy.
	 *
	 * @return The statements still to be issued by the perform steps.
	 */
	private Integer countPlannedStatements(Boolean keepsUserPermissions)
	{
		Set<SObjectType> selfReferencingChildTypes = getSelfReferencingChildTypes();
		Integer planned = 0;
		for(OperationType kind : allObjectsToCommit.keySet())
		{
			planned += kind == OperationType.DML_UNDELETE || kind == OperationType.DML_UPDATE ? 1 : allObjectsToCommit.get(kind).size();
		}
		if(!allObjectsToCommit.containsKey(OperationType.DML_UPDATE) && !selfReferencingChildTypes.isEmpty())
		{
			planned++;
		}
		statementsAddedBySplitByKind.clear();
		statementsAddedBySplitByKind.put(OperationType.DML_UNDELETE, countStatementsAddedBySplit(OperationType.DML_UNDELETE, new Set<SObjectType>(), keepsUserPermissions));
		statementsAddedBySplitByKind.put(OperationType.DML_UPDATE, countStatementsAddedBySplit(OperationType.DML_UPDATE, selfReferencingChildTypes, keepsUserPermissions));
		return planned + statementsAddedBySplitByKind.get(OperationType.DML_UNDELETE) + statementsAddedBySplitByKind.get(OperationType.DML_UPDATE);
	}

	/**
	 * @description Counts the extra statement that DML_SharingProxy.PermissionKeepingProxy may add to the one
	 * statement that holds every update, or every undelete. The proxy splits that statement in two when a partial
	 * save is allowed and the user may save the records of some of its objects but not of others. Which objects the
	 * proxy refuses is known only during the save, so any such statement with records of more than one object counts
	 * one more.
	 *
	 * @param kind The update or the undelete.
	 * @param typesAddedMidway The objects whose records the save adds to the statement midway, or an empty set.
	 * @param keepsUserPermissions True when the statements go through DML_SharingProxy.PermissionKeepingProxy.
	 *
	 * @return 1 when the statement may be split in two; 0 otherwise.
	 */
	private Integer countStatementsAddedBySplit(OperationType kind, Set<SObjectType> typesAddedMidway, Boolean keepsUserPermissions)
	{
		if(!keepsUserPermissions || !allowPartial)
		{
			return 0;
		}
		Set<SObjectType> statementTypes = new Set<SObjectType>(typesAddedMidway);
		statementTypes.addAll(allObjectsToCommit.get(kind)?.keySet() ?? new Set<SObjectType>());
		return statementTypes.size() > 1 ? 1 : 0;
	}

	/**
	 * @description Finds the objects of the registered children that point to a parent of their own type. For such
	 * a child the step that fills in parent Ids adds an update midway through the save, and that statement must be
	 * counted.
	 *
	 * @return The objects of the children that share their parent's type, or an empty set.
	 */
	private Set<SObjectType> getSelfReferencingChildTypes()
	{
		Set<SObjectType> childTypes = new Set<SObjectType>();
		for(List<DTO_Relationship> relationships : parentToChildRelationshipsMap.values())
		{
			for(DTO_Relationship relationship : relationships)
			{
				SObjectType childType = relationship.childRecord.getSObjectType();
				if(childType == relationship.parentRecord.getSObjectType())
				{
					childTypes.add(childType);
				}
			}
		}
		return childTypes;
	}

	/**
	 * @description Saves again the rows a partial-mode statement refused for a row lock. It does this in rounds, up to
	 * the retry count, before the save moves on, so a parent saved on a retry still passes its Id to its children.
	 * Each round keeps only the rows still refused for a lock, and keeps free the statements the rest of the save
	 * needs. Returns the latest result of each retried row, by the row's original position. The caller puts these
	 * results back in place.
	 *
	 * @param kind The operation the statement performed.
	 * @param records The statement's records, in the order the results describe.
	 * @param results The statement's results, one per record.
	 * @param databaseProxy The proxy the statement went through.
	 *
	 * @return The latest result of every retried row, keyed by original position.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private Map<Integer, Object> retryLockRefusedRows(OperationType kind, List<SObject> records, List<Object> results, DML_SharingProxy.DatabaseProxy databaseProxy)
	{
		Map<Integer, Object> replacements = new Map<Integer, Object>();
		if(!allowPartial || retriesOnLock == 0)
		{
			return replacements;
		}

		List<Integer> refusedIndexes = new List<Integer>();
		for(Integer index = 0; index < results.size(); index++)
		{
			if(isLockRefusedRow(results[index]))
			{
				refusedIndexes.add(index);
			}
		}

		Integer round = 0;
		while(!refusedIndexes.isEmpty() && round < retriesOnLock)
		{
			if(remainingDmlStatements() - statementsStillPlanned < 1 || remainingDmlRows() < refusedIndexes.size())
			{
				retryStoppedBy = RETRY_STOPPED_BY_HEADROOM;
				break;
			}
			round++;

			List<SObject> retriedRecords = new List<SObject>();
			for(Integer index : refusedIndexes)
			{
				retriedRecords.add(records[index]);
			}
			List<Object> retriedResults = reissue(kind, retriedRecords, databaseProxy);

			List<Integer> stillRefused = new List<Integer>();
			for(Integer position = 0; position < refusedIndexes.size(); position++)
			{
				Integer originalIndex = refusedIndexes[position];
				Object retriedResult = retriedResults[position];
				replacements.put(originalIndex, retriedResult);
				if(isLockRefusedRow(retriedResult))
				{
					stillRefused.add(originalIndex);
				}
				else if(LOG_Engine.getOperationErrors(retriedResult).isEmpty())
				{
					rowsRecovered++;
				}
			}
			refusedIndexes = stillRefused;
		}

		if(!refusedIndexes.isEmpty() && round >= retriesOnLock)
		{
			retryStoppedBy = RETRY_STOPPED_BY_COUNT;
		}
		rowsStillRefused += refusedIndexes.size();
		retriesUsed = Math.max(retriesUsed, round);
		return replacements;
	}

	/**
	 * @description Runs one more statement for the given rows in partial mode, through the same proxy method and with
	 * the same arguments as the first statement. An upsert reads its external Id field from the transaction's own
	 * map, as the first statement did.
	 *
	 * @param kind The operation to repeat.
	 * @param records The rows to save again; an upsert's rows share one type, which names its external Id field.
	 * @param databaseProxy The proxy to go through.
	 *
	 * @return The statement's results, one per row.
	 */
	private List<Object> reissue(OperationType kind, List<SObject> records, DML_SharingProxy.DatabaseProxy databaseProxy)
	{
		switch on kind
		{
			when DML_UNDELETE
			{
				return databaseProxy.doUndelete(records, false, accessLevel);
			}
			when DML_INSERT
			{
				return databaseProxy.doInsert(records, false, accessLevel);
			}
			when DML_UPSERT
			{
				SObjectField externalIdField = upsertExternalIdFieldMap.get(records[0].getSObjectType());
				return externalIdField == null ? databaseProxy.doUpsert(records, false, accessLevel) : databaseProxy.doUpsert(records, externalIdField, false, accessLevel);
			}
			when DML_UPDATE
			{
				return databaseProxy.doUpdate(records, false, accessLevel);
			}
			when else
			{
				return databaseProxy.doDelete(records, false, accessLevel);
			}
		}
	}

	/**
	 * @description Tells commitWork that the attempt was rolled back after a lock refusal that may be retried. It
	 * carries the refusal as its cause. It is always caught inside commitWork and never reaches the caller.
	 */
	private class RetryAttemptException extends Exception
	{
	}

	/**
	 * @description A copy of what the save uses up as it runs, taken before the first attempt, so that a retry starts
	 * from the same registered records. It holds five things. First, the records by operation and type: the insert
	 * and upsert maps lose each type as it is saved, and a record that looks up to a parent of its own type adds an
	 * extra update to the update map midway. Second, the relationships registered for update, which are removed as
	 * they are applied. Third, the child relationships, which the step that fills in parent Ids reads on every
	 * attempt. Fourth, the records that had no Id before the first attempt: the Ids the rolled-back attempt gave
	 * them must be cleared before they can be inserted again. Fifth, the value of every registered child
	 * relationship field. A child of its parent's own type is inserted in the same statement as the parent, before
	 * the fill-in step can replace the rolled-back parent Id that the first attempt wrote into it.
	 */
	private class RegistrationSnapshot
	{
		/**
		 * @description The transaction whose registration was captured.
		 */
		private final DML_Transaction owner;

		/**
		 * @description The registered records by operation and type, each list copied.
		 */
		private final Map<OperationType, Map<SObjectType, List<SObject>>> recordsByOperation = new Map<OperationType, Map<SObjectType, List<SObject>>>();

		/**
		 * @description The relationships registered for update (through registerDirty) before the first attempt.
		 */
		private final List<DTO_Relationship> dirtyRelationships;

		/**
		 * @description The child relationships registered before the first attempt, by parent type.
		 */
		private final Map<SObjectType, List<DTO_Relationship>> childRelationshipsByParent = new Map<SObjectType, List<DTO_Relationship>>();

		/**
		 * @description The insert and upsert records that had no Id before the first attempt.
		 */
		private final List<SObject> recordsToClearOnRetry = new List<SObject>();

		/**
		 * @description Every registered child relationship field with the value it held before the first attempt.
		 */
		private final List<RelationshipFieldValue> relationshipFieldValues = new List<RelationshipFieldValue>();

		/**
		 * @description Captures the owner's registration.
		 *
		 * @param owner The transaction about to run its first attempt.
		 */
		private RegistrationSnapshot(DML_Transaction owner)
		{
			this.owner = owner;
			captureRecords();
			dirtyRelationships = new List<DTO_Relationship>(owner.registeredDirtyRelationships);
			captureChildRelationships();
		}

		/**
		 * @description Copies the registered records by operation and type, noting the insert and upsert records
		 * that have no Id yet.
		 */
		private void captureRecords()
		{
			for(OperationType kind : owner.allObjectsToCommit.keySet())
			{
				Map<SObjectType, List<SObject>> copy = new Map<SObjectType, List<SObject>>();
				for(SObjectType objectType : owner.allObjectsToCommit.get(kind).keySet())
				{
					List<SObject> records = owner.allObjectsToCommit.get(kind).get(objectType);
					copy.put(objectType, new List<SObject>(records));
					if(kind == OperationType.DML_INSERT || kind == OperationType.DML_UPSERT)
					{
						for(SObject record : records)
						{
							if(record.Id == null)
							{
								recordsToClearOnRetry.add(record);
							}
						}
					}
				}
				recordsByOperation.put(kind, copy);
			}
		}

		/**
		 * @description Copies the child relationships by parent type and notes the value each relationship field
		 * holds before the first attempt.
		 */
		private void captureChildRelationships()
		{
			for(SObjectType parentType : owner.parentToChildRelationshipsMap.keySet())
			{
				List<DTO_Relationship> relationships = owner.parentToChildRelationshipsMap.get(parentType);
				childRelationshipsByParent.put(parentType, new List<DTO_Relationship>(relationships));
				for(DTO_Relationship relationship : relationships)
				{
					relationshipFieldValues.add(new RelationshipFieldValue(relationship));
				}
			}
		}

		/**
		 * @description Puts the owner back where it was before the first attempt: clears the Ids the failed attempt
		 * assigned, puts back the child relationship values it overwrote, restores the three registration
		 * collections and empties the collected results.
		 */
		private void restore()
		{
			for(SObject record : recordsToClearOnRetry)
			{
				record.Id = null;
			}
			for(RelationshipFieldValue relationshipFieldValue : relationshipFieldValues)
			{
				relationshipFieldValue.restore();
			}
			owner.allObjectsToCommit.clear();
			for(OperationType kind : recordsByOperation.keySet())
			{
				Map<SObjectType, List<SObject>> copy = new Map<SObjectType, List<SObject>>();
				for(SObjectType objectType : recordsByOperation.get(kind).keySet())
				{
					copy.put(objectType, new List<SObject>(recordsByOperation.get(kind).get(objectType)));
				}
				owner.allObjectsToCommit.put(kind, copy);
			}
			owner.registeredDirtyRelationships.clear();
			owner.registeredDirtyRelationships.addAll(dirtyRelationships);
			owner.parentToChildRelationshipsMap.clear();
			for(SObjectType parentType : childRelationshipsByParent.keySet())
			{
				owner.parentToChildRelationshipsMap.put(parentType, new List<DTO_Relationship>(childRelationshipsByParent.get(parentType)));
			}
			owner.collectedInsertResults.clear();
			owner.collectedUpdateResults.clear();
			owner.collectedUpsertResults.clear();
			owner.collectedDeleteResults.clear();
			owner.collectedUndeleteResults.clear();
		}
	}

	/**
	 * @description A child record's relationship field and the value it held before the first attempt, so a retry
	 * starts from that value rather than from a rolled-back parent's Id.
	 */
	private class RelationshipFieldValue
	{
		/**
		 * @description The child record carrying the relationship field.
		 */
		private final SObject childRecord;

		/**
		 * @description The relationship field that the step which fills in parent Ids writes.
		 */
		private final SObjectField relationshipField;

		/**
		 * @description The field's value before the first attempt, usually null.
		 */
		private final Object valueBefore;

		/**
		 * @description Captures the field's value before the first attempt.
		 *
		 * @param relationship The registered child relationship.
		 */
		private RelationshipFieldValue(DTO_Relationship relationship)
		{
			childRecord = relationship.childRecord;
			relationshipField = relationship.relationshipField;
			valueBefore = childRecord.get(relationshipField);
		}

		/**
		 * @description Puts the value the field held before the first attempt back on the child record.
		 */
		private void restore()
		{
			childRecord.put(relationshipField, valueBefore);
		}
	}

	/**
	 * @description Hook called before the commit process starts. Work registered here is committed with the rest
	 * and, in an all-or-nothing commit, rolled back with it when a later statement fails. A read made here is cached
	 * like any other read and is from before this commit's write. It runs once for each attempt of the commit: when the
	 * commit is set to try again after a row lock (DML_Builder.withRetryOnLock does that, and an API handler's commit
	 * tries again once), it runs again for the new attempt. So write what you do here so that it is safe to run more than
	 * once.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void onCommitWorkStarting()
	 * {
	 *     super.onCommitWorkStarting();
	 *     // custom pre-commit logic
	 * }
	 * ```
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
	global virtual void onCommitWorkStarting()
	{
	}

	/**
	 * @description Hook called before DML operations start. A read made here is cached like any other read and is from
	 * before this commit's write.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void onDMLStarting()
	 * {
	 *     super.onDMLStarting();
	 *     // custom pre-DML logic
	 * }
	 * ```
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
	global virtual void onDMLStarting()
	{
	}

	/**
	 * @description Hook called after DML operations complete.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void onDMLFinished()
	 * {
	 *     super.onDMLFinished();
	 *     // custom post-DML logic
	 * }
	 * ```
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
	global virtual void onDMLFinished()
	{
	}

	/**
	 * @description Hook called after DML operations but before finalization.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void onCommitWorkFinishing()
	 * {
	 *     super.onCommitWorkFinishing();
	 *     // custom pre-finalization logic
	 * }
	 * ```
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
	global virtual void onCommitWorkFinishing()
	{
	}

	/**
	 * @description Hook called after the commit process finalizes, indicating success or failure. It runs after the
	 * transaction's in-memory query cache has been emptied, so a read made here is cached like any other and sees the
	 * rows as they are after the attempt, whether it was saved or rolled back. It runs once for each attempt of the
	 * commit: when the commit is set to try again after a row lock (DML_Builder.withRetryOnLock does that, and an API
	 * handler's commit tries again once), it runs with false after the attempt that was refused and again after the next
	 * attempt. So write what you do here so that it is safe to run more than once, and do work that must happen once only
	 * when the value is true.
	 *
	 * @param wasSuccessful Whether the attempt that just ended was successful.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global override void onCommitWorkFinished(Boolean wasSuccessful)
	 * {
	 *     super.onCommitWorkFinished(wasSuccessful);
	 *     if(wasSuccessful)
	 *     {
	 *         // custom post-commit logic
	 *     }
	 * }
	 * ```
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock,RedundantSuppression,PMD.AvoidBooleanMethodParameters')
	global virtual void onCommitWorkFinished(Boolean wasSuccessful)
	{
	}

	/**
	 * @description Registers a parent-child relationship for foreign key population after parent DML.
	 * Use this method when the child record has already been registered via doInsert() and only
	 * the relationship needs to be established.
	 *
	 * @param parent The parent SObject.
	 * @param relationshipField The field on the child linking to the parent.
	 * @param child The child SObject.
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doInsert(parent);
	 * dmlTransaction.doInsert(child);
	 * dmlTransaction.registerRelationshipOnly(parent, Child__c.Parent__c, child);
	 * dmlTransaction.commitWork();
	 * ```
	 */
	protected void registerRelationshipOnly(SObject parent, SObjectField relationshipField, SObject child)
	{
		registerRelationship(parent, relationshipField, child);
	}

	/**
	 * @description Internal method that registers a parent-child relationship for foreign key population.
	 *
	 * @param parent The parent SObject.
	 * @param relationshipField The field on the child linking to the parent.
	 * @param child The child SObject.
	 */
	private void registerRelationship(SObject parent, SObjectField relationshipField, SObject child)
	{
		if(parent != null && relationshipField != null)
		{
			SObjectType childType = child.getSObjectType();
			SObjectType parentType = parent.getSObjectType();

			addDependency(parentType, childType);

			List<DTO_Relationship> relationships = parentToChildRelationshipsMap.get(parentType);
			if(relationships == null)
			{
				relationships = new List<DTO_Relationship>();
				parentToChildRelationshipsMap.put(parentType, relationships);
			}

			relationships.add(new DTO_Relationship(parent, relationshipField, child));
		}
	}

	/**
	 * @description Adds a dependency between a parent and child SObject type for topological ordering.
	 *
	 * @param parentType The parent SObject type.
	 * @param childType The child SObject type that depends on the parent.
	 */
	private void addDependency(SObjectType parentType, SObjectType childType)
	{
		Set<SObjectType> parentTypes = objectTypeDependencyMap.get(childType);
		if(parentTypes == null)
		{
			parentTypes = new Set<SObjectType>();
			objectTypeDependencyMap.put(childType, parentTypes);
		}
		parentTypes.add(parentType);
	}

	/**
	 * @description Adds an SObject to the appropriate operation map for DML processing.
	 * For UPDATE/DELETE/UNDELETE operations, prevents duplicate registrations of the same record
	 * (identified by reference, since records with IDs may be registered multiple times).
	 *
	 * @param operation The DML operation type.
	 * @param record The SObject to add.
	 */
	private void addObjectToOperationMap(OperationType operation, SObject record)
	{
		Map<SObjectType, List<SObject>> objectsByTypeMap = allObjectsToCommit.get(operation);
		if(objectsByTypeMap == null)
		{
			objectsByTypeMap = new Map<SObjectType, List<SObject>>();
			allObjectsToCommit.put(operation, objectsByTypeMap);
		}

		List<SObject> objectList = objectsByTypeMap.get(record.getSObjectType());
		if(objectList == null)
		{
			objectList = new List<SObject>();
			objectsByTypeMap.put(record.getSObjectType(), objectList);
		}

		// For operations on existing records, prevent duplicate registrations
		if(operation == OperationType.DML_UPDATE || operation == OperationType.DML_DELETE || operation == OperationType.DML_UNDELETE)
		{
			if(!objectList.contains(record))
			{
				objectList.add(record);
			}
		}
		else
		{
			objectList.add(record);
		}
	}

	/**
	 * @description Performs undelete operations for registered SObjects.
	 * Undelete executes before inserts so undeleted records can serve as parents.
	 *
	 * @param databaseProxy The proxy for performing DML operations.
	 */
	private void performUndeletes(DML_SharingProxy.DatabaseProxy databaseProxy)
	{
		Map<SObjectType, List<SObject>> objectsToUndeleteMap = allObjectsToCommit.get(OperationType.DML_UNDELETE);
		if(objectsToUndeleteMap != null)
		{
			List<SObject> recordsToUndelete = new List<SObject>();
			for(SObjectType objectType : objectsToUndeleteMap.keySet())
			{
				recordsToUndelete.addAll(objectsToUndeleteMap.get(objectType));
			}

			if(!recordsToUndelete.isEmpty())
			{
				List<Database.UndeleteResult> results = databaseProxy.doUndelete(recordsToUndelete, !allowPartial, accessLevel);
				statementsStillPlanned -= 1 + (statementsAddedBySplitByKind.get(OperationType.DML_UNDELETE) ?? 0);
				Map<Integer, Object> retried = retryLockRefusedRows(OperationType.DML_UNDELETE, recordsToUndelete, results, databaseProxy);
				for(Integer index : retried.keySet())
				{
					results[index] = (Database.UndeleteResult)retried.get(index);
				}
				collectedUndeleteResults.addAll(results);
				logPartialResults(results);
			}
		}
	}

	/**
	 * @description Performs insert operations for registered SObjects, respecting dependencies.
	 *
	 * @param databaseProxy The proxy for performing DML operations.
	 */
	private void performInserts(DML_SharingProxy.DatabaseProxy databaseProxy)
	{
		Map<SObjectType, List<SObject>> objectsToInsertMap = allObjectsToCommit.get(OperationType.DML_INSERT);
		if(objectsToInsertMap != null)
		{
			Set<SObjectType> allInsertTypes = objectsToInsertMap.keySet();

			for(SObjectType parentObjectType : getTopologicallyOrderedTypes(allInsertTypes))
			{
				List<SObject> recordsToInsert = objectsToInsertMap.remove(parentObjectType);
				if(recordsToInsert != null)
				{
					List<Database.SaveResult> results = databaseProxy.doInsert(recordsToInsert, !allowPartial, accessLevel);
					statementsStillPlanned--;
					Map<Integer, Object> retried = retryLockRefusedRows(OperationType.DML_INSERT, recordsToInsert, results, databaseProxy);
					for(Integer index : retried.keySet())
					{
						results[index] = (Database.SaveResult)retried.get(index);
					}
					collectedInsertResults.addAll(results);
					logPartialResults(results);
				}

				populateChildRelationships(parentObjectType);
			}
		}
	}

	/**
	 * @description Performs upsert operations for registered SObjects, respecting dependencies and external IDs.
	 *
	 * @param databaseProxy The proxy for performing DML operations.
	 */
	private void performUpserts(DML_SharingProxy.DatabaseProxy databaseProxy)
	{
		Map<SObjectType, List<SObject>> objectsToUpsertMap = allObjectsToCommit.get(OperationType.DML_UPSERT);
		if(objectsToUpsertMap != null)
		{
			Set<SObjectType> allUpsertTypes = objectsToUpsertMap.keySet();

			for(SObjectType parentObjectType : getTopologicallyOrderedTypes(allUpsertTypes))
			{
				List<SObject> recordsToUpsert = objectsToUpsertMap.remove(parentObjectType);
				if(recordsToUpsert != null)
				{
					SObjectField externalIdField = upsertExternalIdFieldMap.get(parentObjectType);
					List<Database.UpsertResult> results;
					if(externalIdField != null)
					{
						results = databaseProxy.doUpsert(recordsToUpsert, externalIdField, !allowPartial, accessLevel);
					}
					else
					{
						results = databaseProxy.doUpsert(recordsToUpsert, !allowPartial, accessLevel);
					}
					statementsStillPlanned--;
					Map<Integer, Object> retried = retryLockRefusedRows(OperationType.DML_UPSERT, recordsToUpsert, results, databaseProxy);
					for(Integer index : retried.keySet())
					{
						results[index] = (Database.UpsertResult)retried.get(index);
					}
					collectedUpsertResults.addAll(results);
					logPartialResults(results);
				}

				populateChildRelationships(parentObjectType);
			}
		}
	}

	/**
	 * @description Performs update operations for registered SObjects, including the relationships registered for update.
	 * In partial mode, skips relationship writes whose parent failed to obtain an Id, so the
	 * child's existing lookup value is left untouched.
	 *
	 * @param databaseProxy The proxy for performing DML operations.
	 */
	private void performUpdates(DML_SharingProxy.DatabaseProxy databaseProxy)
	{
		Map<SObjectType, List<SObject>> objectsToUpdateMap = allObjectsToCommit.get(OperationType.DML_UPDATE);
		if(objectsToUpdateMap != null)
		{
			List<SObject> recordsToUpdate = new List<SObject>();
			for(SObjectType objectType : objectsToUpdateMap.keySet())
			{
				for(SObject recordToUpdate : objectsToUpdateMap.get(objectType))
				{
					recordsToUpdate.add(recordToUpdate);
					for(Integer i = registeredDirtyRelationships.size() - 1; i >= 0; i--)
					{
						DTO_Relationship relationship = registeredDirtyRelationships[i];
						if(recordToUpdate == relationship.childRecord)
						{
							registeredDirtyRelationships.remove(i);
							if(allowPartial && relationship.parentRecord.Id == null)
							{
								continue;
							}
							recordToUpdate.put(relationship.relationshipField, relationship.parentRecord.Id);
						}
					}
				}
			}

			if(!recordsToUpdate.isEmpty())
			{
				List<Database.SaveResult> results = databaseProxy.doUpdate(recordsToUpdate, !allowPartial, accessLevel);
				statementsStillPlanned -= 1 + (statementsAddedBySplitByKind.get(OperationType.DML_UPDATE) ?? 0);
				Map<Integer, Object> retried = retryLockRefusedRows(OperationType.DML_UPDATE, recordsToUpdate, results, databaseProxy);
				for(Integer index : retried.keySet())
				{
					results[index] = (Database.SaveResult)retried.get(index);
				}
				collectedUpdateResults.addAll(results);
				logPartialResults(results);
			}
		}
	}

	/**
	 * @description Performs delete operations for registered SObjects in reverse topological order.
	 *
	 * @param databaseProxy The proxy for performing DML operations.
	 */
	private void performDeletes(DML_SharingProxy.DatabaseProxy databaseProxy)
	{
		Map<SObjectType, List<SObject>> objectsToDeleteMap = allObjectsToCommit.get(OperationType.DML_DELETE);
		if(objectsToDeleteMap != null)
		{
			Set<SObjectType> allDeleteTypes = objectsToDeleteMap.keySet();
			List<SObjectType> typesToProcess = getTopologicallyOrderedTypes(allDeleteTypes);

			for(Integer i = typesToProcess.size() - 1; i >= 0; i--)
			{
				SObjectType objectType = typesToProcess[i];
				List<SObject> recordsToDelete = objectsToDeleteMap.get(objectType);
				if(recordsToDelete != null)
				{
					List<Database.DeleteResult> results = databaseProxy.doDelete(recordsToDelete, !allowPartial, accessLevel);
					statementsStillPlanned--;
					Map<Integer, Object> retried = retryLockRefusedRows(OperationType.DML_DELETE, recordsToDelete, results, databaseProxy);
					for(Integer index : retried.keySet())
					{
						results[index] = (Database.DeleteResult)retried.get(index);
					}
					collectedDeleteResults.addAll(results);
					logPartialResults(results);
				}
			}
		}
	}

	/**
	 * @description Logs the failed rows of a partial commit when logging is not suppressed: rows whose
	 * errors all carry a declared expected status code at WARN, every other failed row at ERROR.
	 *
	 * @param results The DML results to log (SaveResult, UpsertResult, DeleteResult, or UndeleteResult).
	 */
	private void logPartialResults(List<Object> results)
	{
		if(!allowPartial || suppressLogging || results == null)
		{
			return;
		}

		List<Object> expectedRefusals = new List<Object>();
		List<Object> otherResults = new List<Object>();

		for(Object result : results)
		{
			if(isExpectedRefusal(result))
			{
				expectedRefusals.add(result);
			}
			else
			{
				otherResults.add(result);
			}
		}

		LOG_Builder.errorDMLOperationResults(otherResults, CLASS_METHOD_COMMIT);
		LOG_Engine.log(expectedRefusals, CLASS_METHOD_COMMIT, LoggingLevel.WARN);
	}

	/**
	 * @description Whether a DML result is a failed row whose every error carries a declared expected status
	 * code. A successful row is never an expected refusal; a row mixing an expected and an unexpected
	 * error is not one either. It is visible to tests for DML_Transaction_TEST only. Real DML on this platform
	 * reports one error per row, so the test checks the rule that every error must match with a result built
	 * from JSON that carries two errors.
	 *
	 * @param result The DML result to classify.
	 *
	 * @return True when the row failed only for declared reasons.
	 */
	@TestVisible
	private Boolean isExpectedRefusal(Object result)
	{
		List<Database.Error> errors = LOG_Engine.getOperationErrors(result);

		if(errors.isEmpty() || expectedRefusalStatusCodes.isEmpty())
		{
			return false;
		}

		for(Database.Error error : errors)
		{
			if(!expectedRefusalStatusCodes.contains(error.getStatusCode()))
			{
				return false;
			}
		}

		return true;
	}

	/**
	 * @description Returns collected insert results from committed DML operations.
	 *
	 * @return List of insert SaveResult objects.
	 */
	public List<Database.SaveResult> getInsertResults()
	{
		return collectedInsertResults;
	}

	/**
	 * @description Returns collected update results from committed DML operations.
	 *
	 * @return List of update SaveResult objects.
	 */
	public List<Database.SaveResult> getUpdateResults()
	{
		return collectedUpdateResults;
	}

	/**
	 * @description Returns collected upsert results from committed DML operations.
	 *
	 * @return List of UpsertResult objects.
	 */
	public List<Database.UpsertResult> getUpsertResults()
	{
		return collectedUpsertResults;
	}

	/**
	 * @description Returns collected delete results from committed DML operations.
	 *
	 * @return List of DeleteResult objects.
	 */
	public List<Database.DeleteResult> getDeleteResults()
	{
		return collectedDeleteResults;
	}

	/**
	 * @description Returns collected undelete results from committed DML operations.
	 *
	 * @return List of UndeleteResult objects.
	 */
	public List<Database.UndeleteResult> getUndeleteResults()
	{
		return collectedUndeleteResults;
	}

	/**
	 * @description Returns SObject types in topological order (parent before child).
	 *
	 * @param allTypes All the types to process.
	 *
	 * @return A list of SObject types ordered by dependency.
	 */
	@TestVisible
	private List<SObjectType> getTopologicallyOrderedTypes(Set<SObjectType> allTypes)
	{
		List<SObjectType> orderedTypes = new List<SObjectType>();
		Set<SObjectType> visitedTypes = new Set<SObjectType>();
		Set<SObjectType> inProgressTypes = new Set<SObjectType>();

		for(SObjectType objectType : allTypes)
		{
			visit(objectType, visitedTypes, inProgressTypes, orderedTypes);
		}

		return orderedTypes;
	}

	/**
	 * @description Recursively visits SObject types for topological sorting with cycle detection.
	 * Types that look up to themselves (e.g., Foobar__c to Foobar__c) are not cycles; they are handled
	 * separately via doUpdate in populateChildRelationships.
	 *
	 * @param objectType The SObject type to process.
	 * @param visitedTypes Set of types already visited.
	 * @param inProgressTypes Set of types currently being processed (for cycle detection).
	 * @param orderedTypes List accumulating the ordered result.
	 */
	private void visit(SObjectType objectType, Set<SObjectType> visitedTypes, Set<SObjectType> inProgressTypes, List<SObjectType> orderedTypes)
	{
		if(inProgressTypes.contains(objectType))
		{
			throw new UTIL_Exceptions.IllegalStateException('Cyclic dependency detected for ' + objectType);
		}

		if(!visitedTypes.contains(objectType))
		{
			inProgressTypes.add(objectType);

			if(objectTypeDependencyMap.containsKey(objectType))
			{
				for(SObjectType nextObjectType : objectTypeDependencyMap.get(objectType))
				{
					if(nextObjectType != objectType)
					{
						visit(nextObjectType, visitedTypes, inProgressTypes, orderedTypes);
					}
				}
			}

			inProgressTypes.remove(objectType);
			visitedTypes.add(objectType);
			orderedTypes.add(objectType);
		}
	}

	/**
	 * @description Populates relationship fields on child records with parent IDs after parent DML.
	 * In partial mode, skips children whose parent failed to obtain an Id.
	 *
	 * @param parentObjectType The SObjectType of the parent records that were just processed.
	 */
	private void populateChildRelationships(SObjectType parentObjectType)
	{
		List<DTO_Relationship> relationships = parentToChildRelationshipsMap.get(parentObjectType);

		if(relationships != null)
		{
			for(DTO_Relationship relationship : relationships)
			{
				if(allowPartial && relationship.parentRecord.Id == null)
				{
					continue;
				}

				relationship.childRecord.put(relationship.relationshipField, relationship.parentRecord.Id);

				if(relationship.childRecord.getSObjectType() == relationship.parentRecord.getSObjectType()
						&& relationship.childRecord.Id != null)
				{
					doUpdate(relationship.childRecord);
				}
			}
		}
	}

	/**
	 * @description Represents a relationship between a parent and child SObject.
	 */
	private class DTO_Relationship
	{
		/**
		 * @description The record whose relationship field gets the parent's Id once the parent is saved. The
		 * transaction writes the Id into this same record object, not into a copy.
		 */
		private final SObject childRecord;

		/**
		 * @description The record the child points to. Its Id is read after it is saved. When partial success is
		 * allowed and the parent has no Id, the child's relationship field is left as it is.
		 */
		private final SObject parentRecord;

		/**
		 * @description The field on the child that references the parent.
		 */
		private final SObjectField relationshipField;

		/**
		 * @description Constructs a relationship between a parent and child SObject.
		 *
		 * @param parentRecord The parent SObject.
		 * @param relationshipField The field linking the child to the parent.
		 * @param childRecord The child SObject.
		 */
		private DTO_Relationship(SObject parentRecord, SObjectField relationshipField, SObject childRecord)
		{
			this.childRecord = childRecord;
			this.parentRecord = parentRecord;
			this.relationshipField = relationshipField;
		}
	}
}