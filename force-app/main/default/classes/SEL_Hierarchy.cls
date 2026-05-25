// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Data Access Layer for managing self-referencing hierarchical relationships.
 * Provides methods to traverse hierarchies, find ultimate parents (root ancestors), and propagate
 * updates to descendants.
 *
 * Works with any SObject that has a self-referencing lookup field (e.g., Account.ParentId).
 *
 * **Performance Optimizations:**
 * - Queries up to 5 parent levels per SOQL (Salesforce maximum)
 * - Bulkified operations minimize query count
 * - Caches field metadata within Selector instance
 * - Uses efficient Map-based lookups over iterations
 *
 * @see SEL_Hierarchy_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date January 2026, May 2026
 *
 * @since 1.0
 *
 * **Coverage Note:** All edge cases are tested including:
 * - Sharing scenarios where `getSObject(relationshipName)` returns null due to access restrictions
 *   (tested via `Foobar__Share` record-level sharing with different users)
 * - Data inconsistency detection in `findChangedAncestor` (tested via `@TestVisible` wrapper)
 *
 * @example
 * ```apex
 * // Simple usage - find ultimate parent
 * Id ultimateParent = SEL_Hierarchy.forField(Account.ParentId)
 *     .findUltimateParent(childAccountId);
 * // Reusable selector for multiple operations
 * SEL_Hierarchy.Selector accountHierarchy = SEL_Hierarchy.forField(Account.ParentId);
 * Id root = accountHierarchy.findUltimateParent(accountId);
 * Set<Id> children = accountHierarchy.findAllDescendants(root);
 * // Bulk operation
 * Map<Id, Id> ultimateParents = accountHierarchy.findUltimateParents(accountIds);
 * // Propagate ultimate parent to descendants (for trigger context)
 * List<SObject> updates = accountHierarchy.propagateToDescendants
 * (
 *     changedAccountIds,
 *     Account.UltimateParent__c
 * );
 * update updates;
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity,PMD.CognitiveComplexity,PMD.AvoidBooleanMethodParameters')
global inherited sharing class SEL_Hierarchy
{
	/**
	 * @description Default maximum hierarchy depth to prevent infinite loops from circular references.
	 */
	@TestVisible
	private static final Integer DEFAULT_MAX_DEPTH = 20;

	/**
	 * @description Maximum levels that can be traversed in a single SOQL parent relationship query.
	 */
	private static final Integer SOQL_MAX_PARENT_LEVELS = 5;
	private static final String FIELD_ID = 'Id';

	/**
	 * @description Creates a Selector for hierarchy operations using the specified parent field.
	 * The SObjectType is automatically inferred from the field.
	 *
	 * @param parentField The self-referencing lookup field (e.g., Account.ParentId).
	 *
	 * @return A configured Selector ready for hierarchy operations.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Simple one-liner
	 * Id ultimateParent = SEL_Hierarchy.forField(Account.ParentId).findUltimateParent(accountId);
	 * // Reusable selector
	 * SEL_Hierarchy.Selector accountHierarchy = SEL_Hierarchy.forField(Account.ParentId);
	 * Id root = accountHierarchy.findUltimateParent(childId);
	 * Set<Id> descendants = accountHierarchy.findAllDescendants(root);
	 * ```
	 */
	global static Selector forField(SObjectField parentField)
	{
		return new Selector(parentField);
	}

	/**
	 * @description Selector class that provides hierarchy operations for a specific SObject type.
	 * Created via `SEL_Hierarchy.forField(parentField)` - caches field metadata for efficient reuse.
	 *
	 * @since 1.0
	 */
	global inherited sharing class Selector
	{
		private Integer maxDepth = DEFAULT_MAX_DEPTH;
		private final SObjectType objectType;
		private final String parentFieldName;
		private final String relationshipName;

		/**
		 * @description Constructs a Selector for the given parent field.
		 * Field metadata is cached for efficient repeated operations.
		 *
		 * @param parentField The self-referencing lookup field.
		 */
		private Selector(SObjectField parentField)
		{
			DescribeFieldResult describe = parentField.getDescribe();
			// For self-referencing lookups, getReferenceTo() returns the same object type
			objectType = describe.getReferenceTo().iterator().next();
			parentFieldName = describe.name;
			relationshipName = describe.relationshipName;
		}

		/**
		 * @description Sets the maximum hierarchy depth for this selector.
		 * Useful for limiting traversal in known shallow hierarchies or testing.
		 *
		 * @param depth Maximum levels to traverse.
		 *
		 * @return This selector for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * SEL_Hierarchy.Selector hierarchy = SEL_Hierarchy.forField(Account.ParentId)
		 *     .withMaxDepth(10);
		 * ```
		 */
		global Selector withMaxDepth(Integer depth)
		{
			maxDepth = depth;
			return this;
		}

		/**
		 * @description Finds the ultimate parent (root ancestor) for a record.
		 * Traverses up the hierarchy until a record with no parent is found.
		 *
		 * @param recordId The Id of the record to find the ultimate parent for.
		 *
		 * @return The Id of the ultimate parent, or the record's own Id if it has no parent.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Account hierarchy: GrandChild -> Child -> Parent -> GrandParent (no parent)
		 * Id ultimateParent = SEL_Hierarchy.forField(Account.ParentId)
		 *     .findUltimateParent(grandChildAccountId);
		 * // Returns: GrandParent's Id
		 * ```
		 */
		global Id findUltimateParent(Id recordId)
		{
			if(recordId == null)
			{
				return null;
			}

			Map<Id, Id> result = findUltimateParentsInternal(new Set<Id> {recordId});
			return result.get(recordId);
		}

		/**
		 * @description Finds ultimate parents for multiple records in a single bulkified operation.
		 * Optimizes SOQL by querying in batches and traversing multiple parent levels per query.
		 *
		 * @param recordIds Set of record Ids to find ultimate parents for.
		 *
		 * @return Map of record Id to its ultimate parent Id. Records with no parent map to themselves.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<Id> accountIds = new Set<Id>{acc1.Id, acc2.Id, acc3.Id};
		 * Map<Id, Id> ultimateParents = SEL_Hierarchy.forField(Account.ParentId)
		 *     .findUltimateParents(accountIds);
		 * for(Id accountId : accountIds)
		 * {
		 *     System.debug('Ultimate parent: ' + ultimateParents.get(accountId));
		 * }
		 * ```
		 */
		global Map<Id, Id> findUltimateParents(Set<Id> recordIds)
		{
			if(recordIds == null || recordIds.isEmpty())
			{
				return new Map<Id, Id>();
			}

			return findUltimateParentsInternal(recordIds);
		}

		/**
		 * @description Finds all descendants (children, grandchildren, etc.) of a record.
		 *
		 * @param parentId The Id of the parent record.
		 *
		 * @return Set of all descendant record Ids (does not include the parent).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<Id> allDescendants = SEL_Hierarchy.forField(Account.ParentId)
		 *     .findAllDescendants(parentAccountId);
		 * ```
		 */
		global Set<Id> findAllDescendants(Id parentId)
		{
			if(parentId == null)
			{
				return new Set<Id>();
			}

			return findAllDescendants(new Set<Id> {parentId});
		}

		/**
		 * @description Finds all descendants for multiple parent records.
		 *
		 * @param parentIds Set of parent record Ids.
		 *
		 * @return Set of all descendant record Ids (does not include the parent Ids).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<Id> parentIds = new Set<Id>{parent1.Id, parent2.Id};
		 * Set<Id> allDescendants = SEL_Hierarchy.forField(Account.ParentId)
		 *     .findAllDescendants(parentIds);
		 * ```
		 */
		global Set<Id> findAllDescendants(Set<Id> parentIds)
		{
			if(parentIds == null || parentIds.isEmpty())
			{
				return new Set<Id>();
			}

			return findAllDescendantsInternal(parentIds);
		}

		/**
		 * @description Finds all ancestors (parents, grandparents, etc.) of a record.
		 * Returns ancestors ordered from immediate parent to ultimate parent (root).
		 *
		 * @param recordId The Id of the record to find ancestors for.
		 *
		 * @return List of ancestor SObjects ordered from immediate parent to ultimate parent.
		 *         Empty list if record has no parent.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Account hierarchy: GrandChild -> Child -> Parent -> GrandParent (no parent)
		 * List<Account> ancestors = (List<Account>)SEL_Hierarchy.forField(Account.ParentId)
		 *     .findAllAncestors(grandChildAccountId);
		 * // Returns: [Child, Parent, GrandParent] - ordered from closest to furthest
		 * ```
		 */
		global List<SObject> findAllAncestors(Id recordId)
		{
			if(recordId == null)
			{
				return new List<SObject>();
			}

			return findAllAncestorsInternal(new Set<Id> {recordId}).get(recordId);
		}

		/**
		 * @description Finds all ancestors for multiple records in a single bulkified operation.
		 *
		 * @param recordIds Set of record Ids to find ancestors for.
		 *
		 * @return Map of record Id to its list of ancestors. Each list is ordered from immediate parent to ultimate parent.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<Id> accountIds = new Set<Id>{acc1.Id, acc2.Id};
		 * Map<Id, List<SObject>> ancestorsByRecord = SEL_Hierarchy.forField(Account.ParentId)
		 *     .findAllAncestors(accountIds);
		 * for(Id accountId : accountIds)
		 * {
		 *     List<SObject> ancestors = ancestorsByRecord.get(accountId);
		 *     System.debug('Ancestors for ' + accountId + ': ' + ancestors);
		 * }
		 * ```
		 */
		global Map<Id, List<SObject>> findAllAncestors(Set<Id> recordIds)
		{
			if(recordIds == null || recordIds.isEmpty())
			{
				return new Map<Id, List<SObject>>();
			}

			return findAllAncestorsInternal(recordIds);
		}

		/**
		 * @description Updates all descendants of changed records with the new ultimate parent reference.
		 * Typically used in trigger context when a record's parent changes.
		 *
		 * **Use Case:** When Account A's parent changes, all of A's children (and their children)
		 * need their UltimateParent__c field updated to point to A's new ultimate parent.
		 *
		 * @param changedRecordIds Records whose parent has changed.
		 * @param ultimateParentField The field to store the ultimate parent reference.
		 *
		 * @return List of updated records (not yet committed to database).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // In a trigger action when parent changes:
		 * List<SObject> updates = SEL_Hierarchy.forField(Account.ParentId)
		 *     .propagateToDescendants(changedAccountIds, Account.UltimateParent__c);
		 * update updates;
		 * ```
		 */
		global List<SObject> propagateToDescendants(Set<Id> changedRecordIds, SObjectField ultimateParentField)
		{
			if(changedRecordIds == null || changedRecordIds.isEmpty())
			{
				return new List<SObject>();
			}

			String ultimateParentFieldName = ultimateParentField.getDescribe().name;

			// Step 1: Find ultimate parents for the changed records
			Map<Id, Id> ultimateParentsForChanged = findUltimateParentsInternal(changedRecordIds);

			// Step 2: Find all descendants and build parent->child map in single pass
			DescendantResult descendantResult = findDescendantsWithParentMap(changedRecordIds);

			// Step 3: Build update records
			List<SObject> recordsToUpdate = new List<SObject>();

			// Update the changed records themselves
			for(Id changedRecordId : changedRecordIds)
			{
				SObject record = objectType.newSObject(changedRecordId);
				record.put(ultimateParentFieldName, ultimateParentsForChanged.get(changedRecordId));
				recordsToUpdate.add(record);
			}

			// Update descendants - traverse parent map to find their ultimate parent
			for(Id descendantId : descendantResult.allDescendants)
			{
				// Walk up the cached parent map to find which changed record this descends from
				Id ancestorId = findChangedAncestor(descendantId, changedRecordIds, descendantResult.childToParentMap);
				Id ultimateParentId = ultimateParentsForChanged.get(ancestorId);

				SObject record = objectType.newSObject(descendantId);
				record.put(ultimateParentFieldName, ultimateParentId);
				recordsToUpdate.add(record);
			}

			return recordsToUpdate;
		}

		/**
		 * @description Calculates ultimate parent values for records without performing DML.
		 * Returns a map that can be used for updates or analysis.
		 *
		 * @param changedRecordIds Records whose parent has changed.
		 * @param includeDescendants Whether to include all descendants in the result.
		 *
		 * @return Map of record Id to its ultimate parent Id.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Map<Id, Id> ultimateParents = SEL_Hierarchy.forField(Account.ParentId)
		 *     .calculateUltimateParents(changedAccountIds, true);
		 * ```
		 */
		global Map<Id, Id> calculateUltimateParents(Set<Id> changedRecordIds, Boolean includeDescendants)
		{
			if(changedRecordIds == null || changedRecordIds.isEmpty())
			{
				return new Map<Id, Id>();
			}

			// Find ultimate parents for changed records
			Map<Id, Id> result = findUltimateParentsInternal(changedRecordIds);

			if(includeDescendants)
			{
				// Find all descendants with parent map
				DescendantResult descendantResult = findDescendantsWithParentMap(changedRecordIds);

				// Each descendant gets the ultimate parent of its changed ancestor
				for(Id descendantId : descendantResult.allDescendants)
				{
					Id ancestorId = findChangedAncestor(descendantId, changedRecordIds, descendantResult.childToParentMap);
					result.put(descendantId, result.get(ancestorId));
				}
			}

			return result;
		}

		/**
		 * @description Internal implementation of findUltimateParents.
		 *
		 * @param recordIds Set of record Ids to find ultimate parents for.
		 *
		 * @return Map of record Id to its ultimate parent Id.
		 */
		private Map<Id, Id> findUltimateParentsInternal(Set<Id> recordIds)
		{
			Map<Id, Id> ultimateParentMap = new Map<Id, Id>();

			// Track original record to current position in hierarchy
			Map<Id, Id> currentPositionMap = new Map<Id, Id>();
			Set<Id> unresolvedOriginalIds = new Set<Id>();

			for(Id recordId : recordIds)
			{
				currentPositionMap.put(recordId, recordId);
				unresolvedOriginalIds.add(recordId);
			}

			// Build query fields once
			List<String> queryFields = buildQueryFields();
			Integer currentDepth = 0;

			while(!unresolvedOriginalIds.isEmpty() && currentDepth < maxDepth)
			{
				// Collect unique positions to query (may be fewer than unresolved if multiple records share positions)
				Set<Id> positionsToQuery = new Set<Id>();

				for(Id originalId : unresolvedOriginalIds)
				{
					positionsToQuery.add(currentPositionMap.get(originalId));
				}

				Map<Id, SObject> recordMap = queryRecordsWithParents(queryFields, positionsToQuery);
				Set<Id> resolvedThisIteration = new Set<Id>();

				for(Id originalRecordId : unresolvedOriginalIds)
				{
					Id currentPositionId = currentPositionMap.get(originalRecordId);
					SObject currentRecord = recordMap.get(currentPositionId);

					if(currentRecord == null)
					{
						ultimateParentMap.put(originalRecordId, currentPositionId);
						resolvedThisIteration.add(originalRecordId);
						continue;
					}

					TraversalResult traversal = traverseParentLevels(currentRecord, null);

					if(traversal.foundUltimate)
					{
						ultimateParentMap.put(originalRecordId, traversal.lastId);
						resolvedThisIteration.add(originalRecordId);
					}
					else
					{
						currentPositionMap.put(originalRecordId, traversal.lastId);
					}
				}

				unresolvedOriginalIds.removeAll(resolvedThisIteration);
				currentDepth += SOQL_MAX_PARENT_LEVELS;
			}

			if(!unresolvedOriginalIds.isEmpty())
			{
				throw new HierarchyException('Maximum hierarchy depth (' + maxDepth + ') exceeded. Possible circular reference detected for records: ' + unresolvedOriginalIds);
			}

			return ultimateParentMap;
		}

		/**
		 * @description Internal implementation of findAllDescendants.
		 *
		 * @param parentIds Set of parent record Ids to find descendants for.
		 *
		 * @return Set of all descendant record Ids.
		 */
		private Set<Id> findAllDescendantsInternal(Set<Id> parentIds)
		{
			Set<Id> allDescendants = new Set<Id>();
			Set<Id> currentLevelParentIds = new Set<Id>(parentIds);
			Integer currentDepth = 0;

			while(!currentLevelParentIds.isEmpty() && currentDepth < maxDepth)
			{
				// Query all immediate children of current level
				List<SObject> children = QRY_Builder.selectFrom(objectType)
						.withSystemMode()
						.fields(new List<String> {FIELD_ID})
						.condition(parentFieldName).isIn(new List<Id>(currentLevelParentIds))
						.toList();

				if(children.isEmpty())
				{
					break;
				}

				Set<Id> childIds = new Set<Id>();
				for(SObject child : children)
				{
					if(!allDescendants.contains(child.Id))
					{
						childIds.add(child.Id);
					}
				}

				if(childIds.isEmpty())
				{
					break;
				}

				allDescendants.addAll(childIds);
				currentLevelParentIds = childIds;
				currentDepth++;
			}

			if(currentDepth >= maxDepth && !currentLevelParentIds.isEmpty())
			{
				throw new HierarchyException('Maximum hierarchy depth (' + maxDepth + ') exceeded while finding descendants. Possible circular reference.');
			}

			return allDescendants;
		}

		/**
		 * @description Internal implementation of findAllAncestors.
		 * Uses the same efficient multi-level SOQL traversal as findUltimateParentsInternal,
		 * but collects all ancestors along the way instead of just the ultimate parent.
		 *
		 * @param recordIds Set of record Ids to find ancestors for.
		 *
		 * @return Map of record Id to its list of ancestor SObjects (ordered from immediate parent to ultimate).
		 */
		private Map<Id, List<SObject>> findAllAncestorsInternal(Set<Id> recordIds)
		{
			Map<Id, List<SObject>> ancestorsByRecord = new Map<Id, List<SObject>>();

			// Initialize result map and track current position for each original record
			Map<Id, Id> currentPositionMap = new Map<Id, Id>();
			Set<Id> unresolvedOriginalIds = new Set<Id>();

			for(Id recordId : recordIds)
			{
				ancestorsByRecord.put(recordId, new List<SObject>());
				currentPositionMap.put(recordId, recordId);
				unresolvedOriginalIds.add(recordId);
			}

			List<String> queryFields = buildQueryFields();
			Integer currentDepth = 0;

			while(!unresolvedOriginalIds.isEmpty() && currentDepth < maxDepth)
			{
				Set<Id> positionsToQuery = new Set<Id>();
				for(Id originalId : unresolvedOriginalIds)
				{
					positionsToQuery.add(currentPositionMap.get(originalId));
				}

				Map<Id, SObject> recordMap = queryRecordsWithParents(queryFields, positionsToQuery);
				Set<Id> resolvedThisIteration = new Set<Id>();

				for(Id originalRecordId : unresolvedOriginalIds)
				{
					Id currentPositionId = currentPositionMap.get(originalRecordId);
					SObject currentRecord = recordMap.get(currentPositionId);

					if(currentRecord == null)
					{
						// Record not found (deleted?) - mark as resolved
						resolvedThisIteration.add(originalRecordId);
						continue;
					}

					// Traverse and collect ancestors
					List<SObject> ancestors = ancestorsByRecord.get(originalRecordId);
					TraversalResult traversal = traverseParentLevels(currentRecord, ancestors);

					if(traversal.foundUltimate)
					{
						resolvedThisIteration.add(originalRecordId);
					}
					else
					{
						currentPositionMap.put(originalRecordId, traversal.lastId);
					}
				}

				unresolvedOriginalIds.removeAll(resolvedThisIteration);
				currentDepth += SOQL_MAX_PARENT_LEVELS;
			}

			if(!unresolvedOriginalIds.isEmpty())
			{
				throw new HierarchyException
						(
								'Maximum hierarchy depth (' + maxDepth + ') exceeded while finding ancestors. Possible circular reference detected for records: ' + unresolvedOriginalIds
						);
			}

			return ancestorsByRecord;
		}

		/**
		 * @description Finds all descendants AND builds a child->parent map in a single pass.
		 *
		 * @param rootIds Set of root record Ids to find descendants for.
		 *
		 * @return DescendantResult containing all descendants and child-to-parent map.
		 */
		private DescendantResult findDescendantsWithParentMap(Set<Id> rootIds)
		{
			DescendantResult result = new DescendantResult();
			Set<Id> currentLevelParentIds = new Set<Id>(rootIds);
			Integer currentDepth = 0;

			while(!currentLevelParentIds.isEmpty() && currentDepth < maxDepth)
			{
				// Query children with their parent reference
				List<SObject> children = QRY_Builder.selectFrom(objectType)
						.withSystemMode()
						.fields(new List<String> {FIELD_ID, parentFieldName})
						.condition(parentFieldName).isIn(new List<Id>(currentLevelParentIds))
						.toList();

				if(children.isEmpty())
				{
					break;
				}

				Set<Id> childIds = new Set<Id>();
				for(SObject child : children)
				{
					Id childId = child.Id;
					if(!result.allDescendants.contains(childId))
					{
						childIds.add(childId);
						result.childToParentMap.put(childId, (Id)child.get(parentFieldName));
					}
				}

				// Note: childIds.isEmpty() check is unnecessary here because:
				// 1. findUltimateParentsInternal already validated no circular references in ancestors
				// 2. For self-referencing lookups, any descendant cycle creates an ancestor cycle
				// 3. Therefore, we will never encounter all-duplicate children at this point

				result.allDescendants.addAll(childIds);
				currentLevelParentIds = childIds;
				currentDepth++;
			}

			return result;
		}

		/**
		 * @description Queries records by Id with parent relationship fields pre-loaded.
		 *
		 * @param queryFields List of fields to query (from buildQueryFields).
		 * @param recordIds Set of record Ids to query.
		 *
		 * @return Map of record Id to SObject with parent relationships loaded.
		 */
		private Map<Id, SObject> queryRecordsWithParents(List<String> queryFields, Set<Id> recordIds)
		{
			return QRY_Builder.selectFrom(objectType)
					.withSystemMode()
					.fields(queryFields)
					.condition(FIELD_ID).isIn(new List<Id>(recordIds))
					.asMap();
		}

		/**
		 * @description Builds the list of fields to query for parent traversal.
		 *
		 * @return List of field API names including parent relationship traversals.
		 */
		private List<String> buildQueryFields()
		{
			List<String> queryFields = new List<String> {FIELD_ID, parentFieldName};
			String currentPath = relationshipName;

			for(Integer i = 0; i < SOQL_MAX_PARENT_LEVELS; i++)
			{
				queryFields.add(currentPath + UTIL_String.DOT + FIELD_ID);
				queryFields.add(currentPath + UTIL_String.DOT + parentFieldName);
				currentPath = currentPath + UTIL_String.DOT + relationshipName;
			}

			return queryFields;
		}

		/**
		 * @description Traverses up to SOQL_MAX_PARENT_LEVELS using pre-loaded relationship data.
		 * Extracts the common parent traversal logic used by both findUltimateParentsInternal
		 * and findAllAncestorsInternal.
		 *
		 * @param currentRecord The record to start traversing from (must have parent relationships loaded).
		 * @param ancestors Optional list to collect ancestor records into. Pass null to skip collection.
		 *
		 * @return TraversalResult containing the last valid Id and whether an ultimate parent was found.
		 */
		private TraversalResult traverseParentLevels(SObject currentRecord, List<SObject> ancestors)
		{
			TraversalResult result = new TraversalResult();
			result.lastId = currentRecord.Id;
			result.foundUltimate = false;

			SObject traversalRecord = currentRecord;

			for(Integer level = 0; level < SOQL_MAX_PARENT_LEVELS; level++)
			{
				Id parentId = (Id)traversalRecord.get(parentFieldName);

				if(parentId == null)
				{
					result.foundUltimate = true;
					break;
				}

				// Get parent record from pre-loaded relationship
				SObject parentRecord = traversalRecord.getSObject(relationshipName);

				if(parentRecord == null)
				{
					// Parent exists but not accessible (e.g., sharing restrictions)
					// Continue from parent on next iteration
					result.lastId = parentId;
					break;
				}

				// Optionally collect ancestor
				if(ancestors != null)
				{
					ancestors.add(parentRecord);
				}

				result.lastId = parentId;
				traversalRecord = parentRecord;
			}

			return result;
		}

		/**
		 * @description Test-only method to verify the exception handling in findChangedAncestor.
		 * This tests the defensive code that handles data inconsistency scenarios.
		 *
		 * @param descendantId The descendant record Id to trace ancestry for.
		 * @param changedRecordIds Set of changed record Ids that are potential ancestors.
		 * @param childToParentMap Cached map of child Id to parent Id.
		 *
		 * @return The Id of the changed ancestor record.
		 */
		@TestVisible
		private Id testFindChangedAncestor(Id descendantId, Set<Id> changedRecordIds, Map<Id, Id> childToParentMap)
		{
			return findChangedAncestor(descendantId, changedRecordIds, childToParentMap);
		}

		/**
		 * @description Walks up the parent map to find which changed record this descendant belongs to.
		 *
		 * @param descendantId The descendant record Id to trace ancestry for.
		 * @param changedRecordIds Set of changed record Ids that are potential ancestors.
		 * @param childToParentMap Cached map of child Id to parent Id.
		 *
		 * @return The Id of the changed ancestor record.
		 */
		private Id findChangedAncestor(Id descendantId, Set<Id> changedRecordIds, Map<Id, Id> childToParentMap)
		{
			Id currentId = descendantId;

			// Walk up the cached parent chain
			while(currentId != null)
			{
				Id parentId = childToParentMap.get(currentId);

				if(changedRecordIds.contains(parentId))
				{
					return parentId;
				}

				currentId = parentId;
			}

			// This line is unreachable because:
			// 1. All descendants were found starting from changedRecordIds in findDescendantsWithParentMap
			// 2. The childToParentMap captures the parent reference for every descendant
			// 3. Walking up the chain must eventually reach a changedRecordId
			// Throw an exception to detect any data inconsistency rather than silently assigning wrong parent
			throw new HierarchyException('Unable to find changed ancestor for descendant: ' + descendantId +
					'. This indicates a data inconsistency in the hierarchy.');
		}
	}

	/**
	 * @description Result of finding descendants with parent mapping.
	 */
	private class DescendantResult
	{
		public Set<Id> allDescendants = new Set<Id>();
		public Map<Id, Id> childToParentMap = new Map<Id, Id>();
	}

	/**
	 * @description Result of traversing parent levels in a single SOQL result.
	 */
	private class TraversalResult
	{
		public Id lastId;
		public Boolean foundUltimate;
	}

	/**
	 * @description Exception thrown when hierarchy operations encounter issues.
	 */
	public class HierarchyException extends Exception
	{
	}
}