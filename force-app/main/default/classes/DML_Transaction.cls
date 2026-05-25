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
 * @description Transaction engine for managing complex DML operations across multiple SObjects.
 * Handles dependency ordering via topological sort, parent-child relationship resolution,
 * and lifecycle hooks for extensibility.
 *
 * @see DML_Transaction_TEST
 * @see DML_Builder
 * @see DML_SharingProxy
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
 * DML_Transaction aTransaction = new DML_Transaction();
 * aTransaction.registerInsert(account);
 * aTransaction.registerInsert(contact, Contact.AccountId, account);
 * aTransaction.commitWork();
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.AvoidGlobalModifier,PMD.ExcessivePublicCount,PMD.ExcessiveClassLength,PMD.AvoidBooleanMethodParameters')
global virtual inherited sharing class DML_Transaction
{
	/**
	 * @description Enum to specify the type of DML operation to perform.
	 */
	private enum OperationType
	{
		DML_UNDELETE,
		DML_INSERT,
		DML_UPSERT,
		DML_UPDATE,
		DML_DELETE
	}

	/**
	 * @description Class and method name for logging context in commitWork.
	 */
	@TestVisible
	private static final String CLASS_METHOD_COMMIT = DML_Transaction.class.getName() + '.commitWork';

	/**
	 * @description Whether to allow partial success for DML operations.
	 */
	@TestVisible
	private Boolean allowPartial = false;

	/**
	 * @description Whether to suppress LOG_Builder error logging for partial results.
	 */
	@TestVisible
	private Boolean suppressLogging = false;

	/**
	 * @description Access level to apply on every DML operation. Null means "use flag-driven default"
	 * (`UserModeDml_Enabled`). Subscriber-reachable paths inherit the default; framework internals
	 * opt out explicitly via `DML_Builder.withSystemMode()` or direct `setAccessLevel()`.
	 */
	@TestVisible
	private AccessLevel accessLevel;

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
	global void setAllowPartial(Boolean allow)
	{
		this.allowPartial = allow;
	}

	/**
	 * @description Sets whether to suppress LOG_Builder error logging for partial DML results.
	 * When enabled, partial failures are not logged.
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
	global void setSuppressLogging(Boolean suppress)
	{
		this.suppressLogging = suppress;
	}

	/**
	 * @description Sets the `AccessLevel` that will be passed to every DML operation via the
	 * `DML_SharingProxy` three-arg methods. When null, the proxy resolves to the flag-driven
	 * default (`UserModeDml_Enabled`).
	 *
	 * @param accessLevel The `AccessLevel` to apply; null to inherit the flag-driven default.
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
	 * @description Commits all registered DML operations with configurable sharing enforcement.
	 *
	 * @param enforceSharing If true, enforces sharing; if false, bypasses sharing; if null, inherits sharing.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DML_Transaction dmlTransaction = new DML_Transaction();
	 * dmlTransaction.doInsert(new Account(Name = 'Test'));
	 * dmlTransaction.commitWork(false);
	 * ```
	 */
	global virtual void commitWork(Boolean enforceSharing)
	{
		Boolean wasSuccessful = true;
		Savepoint savePoint = allObjectsToCommit.isEmpty() ? null : Database.setSavepoint();

		try
		{
			onCommitWorkStarting();

			if(!allObjectsToCommit.isEmpty())
			{
				onDMLStarting();

				DML_SharingProxy.SharingType shareType = enforceSharing == null
						? DML_SharingProxy.SharingType.INHERITED
						: enforceSharing
								? DML_SharingProxy.SharingType.ENFORCE
								: DML_SharingProxy.SharingType.BYPASS;

				DML_SharingProxy.DatabaseProxy databaseProxy = DML_SharingProxy.getSharingProxy(shareType);

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
				Database.rollback(savePoint);
				Database.releaseSavepoint(savePoint);
				throw error;
			}
		}
		finally
		{
			onCommitWorkFinished(wasSuccessful);
		}
	}

	/**
	 * @description Hook called before the commit process starts.
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
	 * @description Hook called before DML operations start.
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
	 * @description Hook called after the commit process finalizes, indicating success or failure.
	 *
	 * @param wasSuccessful Whether the commit was successful.
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
	@SuppressWarnings('PMD.EmptyStatementBlock,RedundantSuppression')
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
					collectedUpsertResults.addAll(results);
					logPartialResults(results);
				}

				populateChildRelationships(parentObjectType);
			}
		}
	}

	/**
	 * @description Performs update operations for registered SObjects, handling dirty relationships.
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
							recordToUpdate.put(relationship.relationshipField, relationship.parentRecord.Id);
							registeredDirtyRelationships.remove(i);
						}
					}
				}
			}

			if(!recordsToUpdate.isEmpty())
			{
				List<Database.SaveResult> results = databaseProxy.doUpdate(recordsToUpdate, !allowPartial, accessLevel);
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
					collectedDeleteResults.addAll(results);
					logPartialResults(results);
				}
			}
		}
	}

	/**
	 * @description Logs partial DML results when in partial mode and logging is not suppressed.
	 *
	 * @param results The DML results to log (SaveResult, UpsertResult, DeleteResult, or UndeleteResult).
	 */
	private void logPartialResults(List<Object> results)
	{
		if(allowPartial && !suppressLogging && results != null)
		{
			LOG_Builder.errorDMLOperationResults(results, CLASS_METHOD_COMMIT);
		}
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
	 * Self-referential types (e.g., Foobar__c → Foobar__c) are not cycles; they are handled
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
		 * @description The child SObject in the relationship.
		 */
		private final SObject childRecord;

		/**
		 * @description The parent SObject in the relationship.
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