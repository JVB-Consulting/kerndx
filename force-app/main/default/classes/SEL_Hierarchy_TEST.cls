// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for SEL_Hierarchy - validates hierarchy traversal and update functionality.
 *
 * NOTE: IsParallel=false is required because some tests use User DML (via TestSetup)
 * for testing sharing/access restrictions. User DML is not permitted in parallel tests.
 *
 * @see SEL_Hierarchy
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date January 2026, May 2026
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
 * ```
 */
@IsTest(SeeAllData=false IsParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
private class SEL_Hierarchy_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'SEL_Hierarchy_TEST-admin';
	private static final SObjectField PARENT_FIELD = Foobar__c.Lookup__c;

	/**
	 * @description Unique company name for test user created in TestSetup.
	 * User DML is not allowed in parallel tests, so we create the user in TestSetup
	 * which runs in a separate transaction before test methods.
	 *
	 * @see TST_Factory.newUser
	 * @see SEL_User.findByCompanyName
	 */
	private static final String TEST_USER_COMPANY_NAME = 'dal-hierarchy-test-user';

	/**
	 * @description Creates test data that requires DML on restricted objects (User).
	 * This runs in a separate transaction before test methods, avoiding parallel test restrictions.
	 */
	@TestSetup
	private static void setupTestData()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);

		User standardUser = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER, TEST_USER_COMPANY_NAME);
		insert standardUser;
	}

	/**
	 * @description Retrieves the test user created in TestSetup.
	 *
	 * @return The test user for sharing/access tests
	 */
	private static User getTestUser()
	{
		return new SEL_User().findByCompanyName(TEST_USER_COMPANY_NAME);
	}

	/**
	 * @description Verifies that forField creates a valid Selector for a self-referencing lookup field.
	 */
	@IsTest
	private static void forFieldShouldCreateSelectorForValidField()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			SEL_Hierarchy.Selector selector = SEL_Hierarchy.forField(Account.ParentId);
			Test.stopTest();

			Assert.isNotNull(selector, 'Should create a valid selector');
		}
	}

	/**
	 * @description Verifies that withMaxDepth returns the selector for method chaining.
	 */
	@IsTest
	private static void withMaxDepthShouldReturnSelectorForChaining()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			SEL_Hierarchy.Selector selector = SEL_Hierarchy.forField(PARENT_FIELD)
					.withMaxDepth(10);
			Test.stopTest();

			Assert.isNotNull(selector, 'Should return selector for method chaining');
		}
	}

	/**
	 * @description Verifies that findUltimateParent returns null when given null input.
	 */
	@IsTest
	private static void findUltimateParentReturnsNullForNullInput()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Id result = SEL_Hierarchy.forField(PARENT_FIELD).findUltimateParent(null);
			Test.stopTest();

			Assert.isNull(result, 'Should return null for null input');
		}
	}

	/**
	 * @description Verifies that a record with no parent returns its own Id as the ultimate parent.
	 */
	@IsTest
	private static void findUltimateParentReturnsSelfWhenNoParent()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c rootRecord = TST_Factory.insertFoobar();

			Test.startTest();
			Id result = SEL_Hierarchy.forField(PARENT_FIELD).findUltimateParent(rootRecord.Id);
			Test.stopTest();

			Assert.areEqual(rootRecord.Id, result, 'Should return own Id when no parent exists');
		}
	}

	/**
	 * @description Verifies that a child record returns its parent as the ultimate parent in a single-level hierarchy.
	 */
	@IsTest
	private static void findUltimateParentReturnsRootForSingleLevelHierarchy()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id).build();

			Test.startTest();
			Id result = SEL_Hierarchy.forField(PARENT_FIELD).findUltimateParent(child.Id);
			Test.stopTest();

			Assert.areEqual(parent.Id, result, 'Should return parent Id');
		}
	}

	/**
	 * @description Verifies that findUltimateParent traverses multiple levels to find the root ancestor.
	 */
	@IsTest
	private static void findUltimateParentReturnsRootForMultiLevelHierarchy()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c grandParent = TST_Factory.insertFoobar();
			Foobar__c parent = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, grandParent.Id).build();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id).build();

			Test.startTest();
			Id result = SEL_Hierarchy.forField(PARENT_FIELD).findUltimateParent(child.Id);
			Test.stopTest();

			Assert.areEqual(grandParent.Id, result, 'Should return grandparent (root) Id');
		}
	}

	/**
	 * @description Verifies that findUltimateParent handles hierarchies deeper than SOQL's 5-level parent traversal limit.
	 */
	@IsTest
	private static void findUltimateParentHandlesDeepHierarchy()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> hierarchy = createHierarchy(7);
			Foobar__c root = hierarchy[0];
			Foobar__c deepestChild = hierarchy[hierarchy.size() - 1];

			Test.startTest();
			Id result = SEL_Hierarchy.forField(PARENT_FIELD).findUltimateParent(deepestChild.Id);
			Test.stopTest();

			Assert.areEqual(root.Id, result, 'Should traverse deep hierarchy to find root');
		}
	}

	/**
	 * @description Verifies that findUltimateParents returns an empty map for null input.
	 */
	@IsTest
	private static void findUltimateParentsReturnsEmptyMapForNullInput()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Map<Id, Id> result = SEL_Hierarchy.forField(PARENT_FIELD).findUltimateParents(null);
			Test.stopTest();

			Assert.isTrue(result.isEmpty(), 'Should return empty map for null input');
		}
	}

	/**
	 * @description Verifies that findUltimateParents returns an empty map for an empty input set.
	 */
	@IsTest
	private static void findUltimateParentsReturnsEmptyMapForEmptySet()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Map<Id, Id> result = SEL_Hierarchy.forField(PARENT_FIELD).findUltimateParents(new Set<Id>());
			Test.stopTest();

			Assert.isTrue(result.isEmpty(), 'Should return empty map for empty input set');
		}
	}

	/**
	 * @description Verifies that findUltimateParents correctly maps records from multiple separate hierarchies.
	 */
	@IsTest
	private static void findUltimateParentsHandlesMultipleHierarchies()
	{
		System.runAs(getTestAdmin())
		{
			// Hierarchy 1: Root1 -> Child1
			Foobar__c root1 = TST_Factory.insertFoobar();
			Foobar__c child1 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root1.Id).build();

			// Hierarchy 2: Root2 -> Mid2 -> Child2
			Foobar__c root2 = TST_Factory.insertFoobar();
			Foobar__c mid2 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root2.Id).build();
			Foobar__c child2 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, mid2.Id).build();

			Test.startTest();
			Set<Id> recordIds = new Set<Id> {child1.Id, child2.Id, root1.Id};
			Map<Id, Id> result = SEL_Hierarchy.forField(PARENT_FIELD).findUltimateParents(recordIds);
			Test.stopTest();

			Assert.areEqual(root1.Id, result.get(child1.Id), 'Child1 should map to Root1');
			Assert.areEqual(root2.Id, result.get(child2.Id), 'Child2 should map to Root2');
			Assert.areEqual(root1.Id, result.get(root1.Id), 'Root1 should map to itself');
		}
	}

	/**
	 * @description Verifies that findUltimateParents throws HierarchyException for circular references.
	 */
	@IsTest
	private static void findUltimateParentsThrowsExceptionForCircularReference()
	{
		System.runAs(getTestAdmin())
		{
			List<SObject> records = TST_Factory.insertFoobars(3);
			Foobar__c record1 = (Foobar__c)records[0];
			Foobar__c record2 = (Foobar__c)records[1];
			Foobar__c record3 = (Foobar__c)records[2];

			// Create circular reference: 1 -> 2 -> 3 -> 1
			record1.Lookup__c = record2.Id;
			record2.Lookup__c = record3.Id;
			record3.Lookup__c = record1.Id;
			DML_Builder.newTransaction().doUpdate(records).execute();

			Test.startTest();
			try
			{
				SEL_Hierarchy.forField(PARENT_FIELD)
						.withMaxDepth(10)
						.findUltimateParents(new Set<Id> {record1.Id});
				Assert.fail('Should throw HierarchyException for circular reference');
			}
			catch(SEL_Hierarchy.HierarchyException error)
			{
				Assert.isTrue(error.getMessage().contains('Maximum hierarchy depth'), 'Exception message should mention max depth');
			}
			Test.stopTest();
		}
	}

	/**
	 * @description Verifies that findAllDescendants returns an empty set for null Id input.
	 */
	@IsTest
	private static void findAllDescendantsReturnsEmptySetForNullInput()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Set<Id> result = SEL_Hierarchy.forField(PARENT_FIELD).findAllDescendants((Id)null);
			Test.stopTest();

			Assert.isTrue(result.isEmpty(), 'Should return empty set for null input');
		}
	}

	/**
	 * @description Verifies that findAllDescendants returns an empty set for null Set input.
	 */
	@IsTest
	private static void findAllDescendantsReturnsEmptySetForNullSetInput()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Set<Id> result = SEL_Hierarchy.forField(PARENT_FIELD).findAllDescendants((Set<Id>)null);
			Test.stopTest();

			Assert.isTrue(result.isEmpty(), 'Should return empty set for null set input');
		}
	}

	/**
	 * @description Verifies that findAllDescendants returns an empty set for an empty Set input.
	 */
	@IsTest
	private static void findAllDescendantsReturnsEmptySetForEmptySetInput()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Set<Id> result = SEL_Hierarchy.forField(PARENT_FIELD).findAllDescendants(new Set<Id>());
			Test.stopTest();

			Assert.isTrue(result.isEmpty(), 'Should return empty set for empty set input');
		}
	}

	/**
	 * @description Verifies that findAllDescendants returns an empty set when the record has no children.
	 */
	@IsTest
	private static void findAllDescendantsReturnsEmptySetWhenNoChildren()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c loneRecord = TST_Factory.insertFoobar();

			Test.startTest();
			Set<Id> result = SEL_Hierarchy.forField(PARENT_FIELD).findAllDescendants(loneRecord.Id);
			Test.stopTest();

			Assert.isTrue(result.isEmpty(), 'Should return empty set when no descendants exist');
		}
	}

	/**
	 * @description Verifies that findAllDescendants returns all immediate children of a parent.
	 */
	@IsTest
	private static void findAllDescendantsReturnsImmediateChildren()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			List<Foobar__c> children = new List<Foobar__c>();
			for(Integer i = 0; i < 3; i++)
			{
				Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
						.withOverride(Foobar__c.Lookup__c, parent.Id).build();
				children.add(child);
			}

			Test.startTest();
			Set<Id> result = SEL_Hierarchy.forField(PARENT_FIELD).findAllDescendants(parent.Id);
			Test.stopTest();

			Assert.areEqual(3, result.size(), 'Should find all 3 children');
			for(Foobar__c child : children)
			{
				Assert.isTrue(result.contains(child.Id), 'Should contain child: ' + child.Id);
			}
		}
	}

	/**
	 * @description Verifies that findAllDescendants returns descendants at all levels of the hierarchy.
	 */
	@IsTest
	private static void findAllDescendantsReturnsAllLevels()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id).build();
			Foobar__c grandChild = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, child.Id).build();

			Test.startTest();
			Set<Id> result = SEL_Hierarchy.forField(PARENT_FIELD).findAllDescendants(parent.Id);
			Test.stopTest();

			Assert.areEqual(2, result.size(), 'Should find child and grandchild');
			Assert.isTrue(result.contains(child.Id), 'Should contain child');
			Assert.isTrue(result.contains(grandChild.Id), 'Should contain grandchild');
		}
	}

	/**
	 * @description Verifies that findAllDescendants handles tree structures with multiple branches.
	 */
	@IsTest
	private static void findAllDescendantsHandlesMultipleBranches()
	{
		System.runAs(getTestAdmin())
		{
			//         Root
			//        /    \
			//    Child1  Child2
			//      |
			//  GrandChild
			Foobar__c root = TST_Factory.insertFoobar();
			Foobar__c child1 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root.Id).build();
			Foobar__c child2 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root.Id).build();
			Foobar__c grandChild = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, child1.Id).build();

			Test.startTest();
			Set<Id> result = SEL_Hierarchy.forField(PARENT_FIELD).findAllDescendants(root.Id);
			Test.stopTest();

			Assert.areEqual(3, result.size(), 'Should find all 3 descendants');
			Assert.isTrue(result.contains(child1.Id), 'Should contain child1');
			Assert.isTrue(result.contains(child2.Id), 'Should contain child2');
			Assert.isTrue(result.contains(grandChild.Id), 'Should contain grandchild');
		}
	}

	/**
	 * @description Verifies that findAllDescendants finds descendants from multiple parent records.
	 */
	@IsTest
	private static void findAllDescendantsFromMultipleParents()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent1 = TST_Factory.insertFoobar();
			Foobar__c parent2 = TST_Factory.insertFoobar();
			Foobar__c child1 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent1.Id).build();
			Foobar__c child2 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent2.Id).build();

			Test.startTest();
			Set<Id> result = SEL_Hierarchy.forField(PARENT_FIELD).findAllDescendants(new Set<Id> {parent1.Id, parent2.Id});
			Test.stopTest();

			Assert.areEqual(2, result.size(), 'Should find both children');
			Assert.isTrue(result.contains(child1.Id), 'Should contain child1');
			Assert.isTrue(result.contains(child2.Id), 'Should contain child2');
		}
	}

	/**
	 * @description Verifies that findAllAncestors returns an empty list for null Id input.
	 */
	@IsTest
	private static void findAllAncestorsReturnsEmptyListForNullInput()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			List<SObject> result = SEL_Hierarchy.forField(PARENT_FIELD).findAllAncestors((Id)null);
			Test.stopTest();

			Assert.isTrue(result.isEmpty(), 'Should return empty list for null input');
		}
	}

	/**
	 * @description Verifies that findAllAncestors returns an empty map for null Set input.
	 */
	@IsTest
	private static void findAllAncestorsReturnsEmptyMapForNullSetInput()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Map<Id, List<SObject>> result = SEL_Hierarchy.forField(PARENT_FIELD).findAllAncestors((Set<Id>)null);
			Test.stopTest();

			Assert.isTrue(result.isEmpty(), 'Should return empty map for null set input');
		}
	}

	/**
	 * @description Verifies that findAllAncestors returns an empty map for an empty Set input.
	 */
	@IsTest
	private static void findAllAncestorsReturnsEmptyMapForEmptySetInput()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Map<Id, List<SObject>> result = SEL_Hierarchy.forField(PARENT_FIELD).findAllAncestors(new Set<Id>());
			Test.stopTest();

			Assert.isTrue(result.isEmpty(), 'Should return empty map for empty set input');
		}
	}

	/**
	 * @description Verifies that findAllAncestors returns an empty list when the record has no parent.
	 */
	@IsTest
	private static void findAllAncestorsReturnsEmptyListWhenNoParent()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c rootRecord = TST_Factory.insertFoobar();

			Test.startTest();
			List<SObject> result = SEL_Hierarchy.forField(PARENT_FIELD).findAllAncestors(rootRecord.Id);
			Test.stopTest();

			Assert.isTrue(result.isEmpty(), 'Should return empty list when no parent exists');
		}
	}

	/**
	 * @description Verifies that findAllAncestors returns the immediate parent for a single-level hierarchy.
	 */
	@IsTest
	private static void findAllAncestorsReturnsImmediateParent()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c parent = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id).build();

			Test.startTest();
			List<SObject> result = SEL_Hierarchy.forField(PARENT_FIELD).findAllAncestors(child.Id);
			Test.stopTest();

			Assert.areEqual(1, result.size(), 'Should return one ancestor');
			Assert.areEqual(parent.Id, result[0].Id, 'Should be the immediate parent');
		}
	}

	/**
	 * @description Verifies that findAllAncestors returns ancestors in order from immediate parent to ultimate parent.
	 */
	@IsTest
	private static void findAllAncestorsReturnsAllAncestorsInOrder()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c grandParent = TST_Factory.insertFoobar();
			Foobar__c parent = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, grandParent.Id).build();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, parent.Id).build();

			Test.startTest();
			List<SObject> result = SEL_Hierarchy.forField(PARENT_FIELD).findAllAncestors(child.Id);
			Test.stopTest();

			Assert.areEqual(2, result.size(), 'Should return 2 ancestors');
			Assert.areEqual(parent.Id, result[0].Id, 'First ancestor should be immediate parent');
			Assert.areEqual(grandParent.Id, result[1].Id, 'Second ancestor should be grandparent');
		}
	}

	/**
	 * @description Verifies that findAllAncestors handles bulk operations with multiple records from different hierarchies.
	 */
	@IsTest
	private static void findAllAncestorsBulkHandlesMultipleRecords()
	{
		System.runAs(getTestAdmin())
		{
			// Hierarchy 1: Root1 -> Child1
			Foobar__c root1 = TST_Factory.insertFoobar();
			Foobar__c child1 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root1.Id).build();

			// Hierarchy 2: Root2 -> Mid2 -> Child2
			Foobar__c root2 = TST_Factory.insertFoobar();
			Foobar__c mid2 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root2.Id).build();
			Foobar__c child2 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, mid2.Id).build();

			Test.startTest();
			Map<Id, List<SObject>> result = SEL_Hierarchy.forField(PARENT_FIELD)
					.findAllAncestors(new Set<Id> {child1.Id, child2.Id});
			Test.stopTest();

			List<SObject> ancestors1 = result.get(child1.Id);
			List<SObject> ancestors2 = result.get(child2.Id);

			Assert.areEqual(1, ancestors1.size(), 'Child1 should have 1 ancestor');
			Assert.areEqual(root1.Id, ancestors1[0].Id, 'Child1 ancestor should be Root1');

			Assert.areEqual(2, ancestors2.size(), 'Child2 should have 2 ancestors');
			Assert.areEqual(mid2.Id, ancestors2[0].Id, 'Child2 first ancestor should be Mid2');
			Assert.areEqual(root2.Id, ancestors2[1].Id, 'Child2 second ancestor should be Root2');
		}
	}

	/**
	 * @description Verifies that findAllAncestors handles hierarchies deeper than SOQL's 5-level parent traversal limit.
	 */
	@IsTest
	private static void findAllAncestorsHandlesDeepHierarchy()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> hierarchy = createHierarchy(7);
			Foobar__c root = hierarchy[0];
			Foobar__c deepestChild = hierarchy[hierarchy.size() - 1];

			Test.startTest();
			List<SObject> result = SEL_Hierarchy.forField(PARENT_FIELD).findAllAncestors(deepestChild.Id);
			Test.stopTest();

			Assert.areEqual(6, result.size(), 'Should find 6 ancestors');
			Assert.areEqual(hierarchy[5].Id, result[0].Id, 'First ancestor should be immediate parent (level 5)');
			Assert.areEqual(root.Id, result[5].Id, 'Last ancestor should be root');
		}
	}

	/**
	 * @description Verifies that findAllAncestors throws HierarchyException for circular references.
	 */
	@IsTest
	private static void findAllAncestorsThrowsExceptionForCircularReference()
	{
		System.runAs(getTestAdmin())
		{
			// Create circular reference: A -> B -> C -> A
			Foobar__c recordA = TST_Factory.insertFoobar();
			Foobar__c recordB = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, recordA.Id).build();
			Foobar__c recordC = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, recordB.Id).build();

			recordA.Lookup__c = recordC.Id;
			DML_Builder.newTransaction().doUpdate(recordA).execute();

			Test.startTest();
			try
			{
				SEL_Hierarchy.forField(PARENT_FIELD)
						.withMaxDepth(10)
						.findAllAncestors(recordA.Id);
				Assert.fail('Should throw HierarchyException for circular reference');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, SEL_Hierarchy.HierarchyException.class, 'Should throw HierarchyException');
				Assert.isTrue(error.getMessage().contains('circular reference'), 'Message should mention circular reference');
			}
			Test.stopTest();
		}
	}

	/**
	 * @description Verifies that findAllAncestors gracefully handles a deleted record Id by returning an empty ancestors list.
	 */
	@IsTest
	private static void findAllAncestorsHandlesDeletedRecordId()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();
			Id deletedRecordId = record.Id;
			DML_Builder.newTransaction().doDelete(record).execute();

			Test.startTest();
			Map<Id, List<SObject>> result = SEL_Hierarchy.forField(PARENT_FIELD).findAllAncestors(new Set<Id> {deletedRecordId});
			Test.stopTest();

			Assert.isTrue(result.containsKey(deletedRecordId), 'Result should contain entry for deleted record');
			Assert.isTrue(result.get(deletedRecordId).isEmpty(), 'Ancestors list should be empty for deleted record');
		}
	}

	/**
	 * @description Verifies that propagateToDescendants returns an empty list for null input.
	 */
	@IsTest
	private static void propagateToDescendantsReturnsEmptyListForNullInput()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			List<SObject> result = SEL_Hierarchy.forField(PARENT_FIELD)
					.propagateToDescendants(null, Foobar__c.Text__c);
			Test.stopTest();

			Assert.isTrue(result.isEmpty(), 'Should return empty list for null input');
		}
	}

	/**
	 * @description Verifies that propagateToDescendants returns an empty list for empty input.
	 */
	@IsTest
	private static void propagateToDescendantsReturnsEmptyListForEmptyInput()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			List<SObject> result = SEL_Hierarchy.forField(PARENT_FIELD)
					.propagateToDescendants(new Set<Id>(), Foobar__c.Text__c);
			Test.stopTest();

			Assert.isTrue(result.isEmpty(), 'Should return empty list for empty input');
		}
	}

	/**
	 * @description Verifies that propagateToDescendants correctly updates the changed record and all its descendants.
	 */
	@IsTest
	private static void propagateToDescendantsUpdatesChangedRecordAndDescendants()
	{
		System.runAs(getTestAdmin())
		{
			// Hierarchy: NewParent, OldRoot -> Child -> GrandChild
			// Child's parent will change from OldRoot to NewParent
			Foobar__c newUltimateParent = TST_Factory.insertFoobar();
			Foobar__c oldRoot = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, oldRoot.Id).build();
			Foobar__c grandChild = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, child.Id).build();

			child.Lookup__c = newUltimateParent.Id;
			DML_Builder.newTransaction().doUpdate(child).execute();

			Test.startTest();
			List<SObject> recordsToUpdate = SEL_Hierarchy.forField(PARENT_FIELD)
					.propagateToDescendants(new Set<Id> {child.Id}, Foobar__c.Text__c);
			Test.stopTest();

			Assert.areEqual(2, recordsToUpdate.size(), 'Should return child and grandchild for update');

			Map<Id, SObject> updateMap = new Map<Id, SObject>();
			for(SObject record : recordsToUpdate)
			{
				updateMap.put(record.Id, record);
			}

			Assert.areEqual
					(
							newUltimateParent.Id,
							updateMap.get(child.Id).get('Text__c'),
							'Child should have newUltimateParent as ultimate parent'
					);
			Assert.areEqual
					(
							newUltimateParent.Id,
							updateMap.get(grandChild.Id).get('Text__c'),
							'GrandChild should have newUltimateParent as ultimate parent'
					);
		}
	}

	/**
	 * @description Verifies that calculateUltimateParents returns an empty map for null input.
	 */
	@IsTest
	private static void calculateUltimateParentsReturnsEmptyMapForNullInput()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Map<Id, Id> result = SEL_Hierarchy.forField(PARENT_FIELD)
					.calculateUltimateParents(null, false);
			Test.stopTest();

			Assert.isTrue(result.isEmpty(), 'Should return empty map for null input');
		}
	}

	/**
	 * @description Verifies that calculateUltimateParents returns an empty map for empty input.
	 */
	@IsTest
	private static void calculateUltimateParentsReturnsEmptyMapForEmptyInput()
	{
		System.runAs(getTestAdmin())
		{
			Test.startTest();
			Map<Id, Id> result = SEL_Hierarchy.forField(PARENT_FIELD)
					.calculateUltimateParents(new Set<Id>(), false);
			Test.stopTest();

			Assert.isTrue(result.isEmpty(), 'Should return empty map for empty input');
		}
	}

	/**
	 * @description Verifies that calculateUltimateParents returns only changed records when includeDescendants is false.
	 */
	@IsTest
	private static void calculateUltimateParentsWithoutDescendants()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c root = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root.Id).build();

			Test.startTest();
			Map<Id, Id> result = SEL_Hierarchy.forField(PARENT_FIELD)
					.calculateUltimateParents(new Set<Id> {child.Id}, false);
			Test.stopTest();

			Assert.areEqual(1, result.size(), 'Should only contain the changed record');
			Assert.areEqual(root.Id, result.get(child.Id), 'Child should map to root');
		}
	}

	/**
	 * @description Verifies that calculateUltimateParents includes all descendants when includeDescendants is true.
	 */
	@IsTest
	private static void calculateUltimateParentsWithDescendants()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c root = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root.Id).build();
			Foobar__c grandChild = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, child.Id).build();
			Foobar__c greatGrandChild = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, grandChild.Id).build();

			Test.startTest();
			Map<Id, Id> result = SEL_Hierarchy.forField(PARENT_FIELD)
					.calculateUltimateParents(new Set<Id> {root.Id}, true);
			Test.stopTest();

			Assert.areEqual(4, result.size(), 'Should contain root and all 3 descendants');
			Assert.areEqual(root.Id, result.get(root.Id), 'Root should map to itself');
			Assert.areEqual(root.Id, result.get(child.Id), 'Child should map to root');
			Assert.areEqual(root.Id, result.get(grandChild.Id), 'GrandChild should map to root');
			Assert.areEqual(root.Id, result.get(greatGrandChild.Id), 'GreatGrandChild should map to root');
		}
	}

	/**
	 * @description Verifies that calculateUltimateParents throws HierarchyException for circular references when including descendants.
	 */
	@IsTest
	private static void calculateUltimateParentsWithDescendantsThrowsOnCircularReference()
	{
		System.runAs(getTestAdmin())
		{
			// Create circular reference: A -> B -> C -> A
			Foobar__c recordA = TST_Factory.insertFoobar();
			Foobar__c recordB = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, recordA.Id).build();
			Foobar__c recordC = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, recordB.Id).build();

			recordA.Lookup__c = recordC.Id;
			DML_Builder.newTransaction().doUpdate(recordA).execute();

			Test.startTest();
			try
			{
				SEL_Hierarchy.forField(PARENT_FIELD)
						.calculateUltimateParents(new Set<Id> {recordA.Id}, true);
				Assert.fail('Should throw HierarchyException for circular reference');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, SEL_Hierarchy.HierarchyException.class, 'Should throw HierarchyException');
				Assert.isTrue(error.getMessage().contains('circular reference'), 'Message should mention circular reference');
			}
			Test.stopTest();
		}
	}

	/**
	 * @description Verifies that calculateUltimateParents handles a hierarchy where the root has no parent.
	 */
	@IsTest
	private static void calculateUltimateParentsHandlesDescendantCircleBackToRoot()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c root = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root.Id).build();
			Foobar__c grandChild = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, child.Id).build();

			Test.startTest();
			Map<Id, Id> result = SEL_Hierarchy.forField(PARENT_FIELD)
					.calculateUltimateParents(new Set<Id> {root.Id}, true);
			Test.stopTest();

			Assert.areEqual(3, result.size(), 'Should contain root, child, and grandChild');
			Assert.areEqual(root.Id, result.get(root.Id), 'Root maps to itself');
			Assert.areEqual(root.Id, result.get(child.Id), 'Child maps to root');
			Assert.areEqual(root.Id, result.get(grandChild.Id), 'GrandChild maps to root');
		}
	}

	/**
	 * @description Verifies that the DEFAULT_MAX_DEPTH constant has a reasonable value.
	 */
	@IsTest
	private static void defaultMaxDepthConstantIsAccessible()
	{
		System.runAs(getTestAdmin())
		{
			Assert.isTrue(
					SEL_Hierarchy.DEFAULT_MAX_DEPTH >= 10,
					'Default max depth should be at least 10 to handle typical hierarchies'
			);
			Assert.isTrue(
					SEL_Hierarchy.DEFAULT_MAX_DEPTH <= 100,
					'Default max depth should be at most 100 to prevent excessive queries'
			);
		}
	}

	/**
	 * @description Verifies that findChangedAncestor throws HierarchyException for data inconsistency scenarios.
	 */
	@IsTest
	private static void findChangedAncestorThrowsExceptionForDataInconsistency()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c descendant = TST_Factory.insertFoobar();
			Foobar__c unrelatedRecord = TST_Factory.insertFoobar();

			SEL_Hierarchy.Selector selector = SEL_Hierarchy.forField(PARENT_FIELD);

			// Corrupted data: descendant maps to null parent (chain ends without reaching changedRecordIds)
			Set<Id> changedRecordIds = new Set<Id> {unrelatedRecord.Id};
			Map<Id, Id> childToParentMap = new Map<Id, Id> {descendant.Id => null};

			Test.startTest();
			try
			{
				selector.testFindChangedAncestor(descendant.Id, changedRecordIds, childToParentMap);
				Assert.fail('Should throw HierarchyException for data inconsistency');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, SEL_Hierarchy.HierarchyException.class, 'Should throw HierarchyException');
				Assert.isTrue(error.getMessage().contains('Unable to find changed ancestor'), 'Message should mention inability to find ancestor');
				Assert.isTrue(error.getMessage().contains('data inconsistency'), 'Message should mention data inconsistency');
			}
			Test.stopTest();
		}
	}

	/**
	 * @description Verifies that findUltimateParent uses an optimal number of queries by traversing 5 parent levels per SOQL.
	 */
	@IsTest
	private static void findUltimateParentUsesOptimalQueryCount()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> hierarchy = createHierarchy(12);
			Id deepestChildId = hierarchy[hierarchy.size() - 1].Id;
			Id expectedRootId = hierarchy[0].Id;

			Integer queriesBefore = UTIL_Limits.soqlQueries().used();

			Test.startTest();
			Id ultimateParentId = SEL_Hierarchy.forField(PARENT_FIELD).findUltimateParent(deepestChildId);
			Test.stopTest();

			Integer queriesUsed = UTIL_Limits.soqlQueries().used() - queriesBefore;

			Assert.areEqual(expectedRootId, ultimateParentId, 'Should find correct root ancestor');
			Assert.isTrue(queriesUsed <= 3, 'Should use at most 3 queries for 12-level hierarchy, used: ' + queriesUsed);
		}
	}

	/**
	 * @description Verifies that findUltimateParents shares queries when processing multiple records in bulk.
	 */
	@IsTest
	private static void findUltimateParentsInBulkSharesQueries()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> hierarchy1 = createHierarchy(6);
			List<Foobar__c> hierarchy2 = createHierarchy(6);

			Id child1Id = hierarchy1[hierarchy1.size() - 1].Id;
			Id child2Id = hierarchy2[hierarchy2.size() - 1].Id;
			Id root1Id = hierarchy1[0].Id;
			Id root2Id = hierarchy2[0].Id;

			Integer queriesBefore = UTIL_Limits.soqlQueries().used();

			Test.startTest();
			Map<Id, Id> ultimateParents = SEL_Hierarchy.forField(PARENT_FIELD)
					.findUltimateParents(new Set<Id> {child1Id, child2Id});
			Test.stopTest();

			Integer queriesUsed = UTIL_Limits.soqlQueries().used() - queriesBefore;

			Assert.areEqual(root1Id, ultimateParents.get(child1Id), 'Should find root of hierarchy 1');
			Assert.areEqual(root2Id, ultimateParents.get(child2Id), 'Should find root of hierarchy 2');
			Assert.isTrue(queriesUsed <= 2, 'Bulk operation should share queries, used: ' + queriesUsed);
		}
	}

	/**
	 * @description Verifies that findAllDescendants uses one query per level of the hierarchy.
	 */
	@IsTest
	private static void findAllDescendantsUsesOneQueryPerLevel()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c root = TST_Factory.insertFoobar();
			Foobar__c child1 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root.Id).build();
			Foobar__c child2 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root.Id).build();
			Foobar__c grandChild1 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, child1.Id).build();
			Foobar__c grandChild2 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, child1.Id).build();

			Integer queriesBefore = UTIL_Limits.soqlQueries().used();

			Test.startTest();
			Set<Id> descendants = SEL_Hierarchy.forField(PARENT_FIELD).findAllDescendants(root.Id);
			Test.stopTest();

			Integer queriesUsed = UTIL_Limits.soqlQueries().used() - queriesBefore;

			Assert.areEqual(4, descendants.size(), 'Should find all 4 descendants');
			Assert.isTrue(descendants.contains(child1.Id), 'Should contain child1');
			Assert.isTrue(descendants.contains(child2.Id), 'Should contain child2');
			Assert.isTrue(descendants.contains(grandChild1.Id), 'Should contain grandChild1');
			Assert.isTrue(descendants.contains(grandChild2.Id), 'Should contain grandChild2');
			Assert.isTrue(queriesUsed <= 3, 'Should use at most 3 queries for 2-level descendant tree, used: ' + queriesUsed);
		}
	}

	/**
	 * @description Verifies that findUltimateParents handles a deleted record by returning its own Id.
	 */
	@IsTest
	private static void findUltimateParentsHandlesDeletedRecordId()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c record = TST_Factory.insertFoobar();
			Id deletedRecordId = record.Id;
			DML_Builder.newTransaction().doDelete(record).execute();

			Test.startTest();
			Map<Id, Id> result = SEL_Hierarchy.forField(PARENT_FIELD).findUltimateParents(new Set<Id> {deletedRecordId});
			Test.stopTest();

			Assert.areEqual(deletedRecordId, result.get(deletedRecordId), 'Should return deleted record ID as ultimate parent');
		}
	}

	/**
	 * @description Verifies that findUltimateParents handles a mix of existing and deleted records.
	 */
	@IsTest
	private static void findUltimateParentsHandlesMixOfExistingAndDeletedRecords()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c existingRoot = TST_Factory.insertFoobar();
			Foobar__c existingChild = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, existingRoot.Id).build();

			Foobar__c recordToDelete = TST_Factory.insertFoobar();
			Id deletedRecordId = recordToDelete.Id;
			DML_Builder.newTransaction().doDelete(recordToDelete).execute();

			Test.startTest();
			Set<Id> recordIds = new Set<Id> {existingChild.Id, deletedRecordId};
			Map<Id, Id> result = SEL_Hierarchy.forField(PARENT_FIELD).findUltimateParents(recordIds);
			Test.stopTest();

			Assert.areEqual(existingRoot.Id, result.get(existingChild.Id), 'Existing record should find its root');
			Assert.areEqual(deletedRecordId, result.get(deletedRecordId), 'Deleted record should return its own ID');
		}
	}

	/**
	 * @description Verifies that findUltimateParent handles gracefully when a mid-hierarchy record is deleted.
	 */
	@IsTest
	private static void findUltimateParentsHandlesMidHierarchyDeletion()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c root = TST_Factory.insertFoobar();
			Foobar__c level1 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root.Id).build();
			Foobar__c level2 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, level1.Id).build();
			Foobar__c level3 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, level2.Id).build();

			DML_Builder.newTransaction().doDelete(level1).execute();

			Test.startTest();
			Id result = SEL_Hierarchy.forField(PARENT_FIELD).findUltimateParent(level3.Id);
			Test.stopTest();

			Assert.isNotNull(result, 'Should return a result even with mid-hierarchy deletion');
		}
	}

	/**
	 * @description Verifies that findAllDescendants handles circular references without infinite loops.
	 */
	@IsTest
	private static void findAllDescendantsHandlesCircularReference()
	{
		System.runAs(getTestAdmin())
		{
			// Create circular reference: A -> B -> C -> A
			Foobar__c recordA = TST_Factory.insertFoobar();
			Foobar__c recordB = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, recordA.Id).build();
			Foobar__c recordC = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, recordB.Id).build();

			recordA.Lookup__c = recordC.Id;
			DML_Builder.newTransaction().doUpdate(recordA).execute();

			Test.startTest();
			Set<Id> descendants = SEL_Hierarchy.forField(PARENT_FIELD).findAllDescendants(recordA.Id);
			Test.stopTest();

			Assert.isTrue(descendants.contains(recordB.Id), 'Should contain B');
			Assert.isTrue(descendants.contains(recordC.Id), 'Should contain C');
		}
	}

	/**
	 * @description Verifies that findAllDescendants throws HierarchyException when max depth is exceeded.
	 */
	@IsTest
	private static void findAllDescendantsThrowsExceptionForMaxDepthExceeded()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c root = TST_Factory.insertFoobar();
			Foobar__c level1 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root.Id).build();
			Foobar__c level2 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, level1.Id).build();
			Foobar__c level3 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, level2.Id).build();
			TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, level3.Id).build();

			Test.startTest();
			try
			{
				SEL_Hierarchy.forField(PARENT_FIELD).withMaxDepth(2).findAllDescendants(root.Id);
				Assert.fail('Should throw HierarchyException when max depth exceeded');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, SEL_Hierarchy.HierarchyException.class, 'Should throw HierarchyException');
				Assert.isTrue(error.getMessage().contains('Maximum hierarchy depth'), 'Message should mention max depth');
			}
			Test.stopTest();
		}
	}

	/**
	 * @description Verifies that findUltimateParent handles inaccessible parents due to sharing restrictions.
	 */
	@IsTest
	private static void findUltimateParentHandlesInaccessibleParentDueToSharing()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c root = TST_Factory.insertFoobar();
			Foobar__c mid = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root.Id).build();
			Foobar__c leaf = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, mid.Id).build();

			User standardUser = getTestUser();

			Foobar__Share leafShare = new Foobar__Share();
			leafShare.ParentId = leaf.Id;
			leafShare.UserOrGroupId = standardUser.Id;
			leafShare.AccessLevel = 'Read';
			leafShare.RowCause = SEL_ObjectShare.ROW_CAUSE_MANUAL;
			DML_Builder.newTransaction().doInsert(leafShare).execute();

			System.runAs(standardUser)
			{
				Test.startTest();
				Id ultimateParent = SEL_Hierarchy.forField(PARENT_FIELD).findUltimateParent(leaf.Id);
				Test.stopTest();

				Assert.areEqual(mid.Id, ultimateParent, 'Should return inaccessible parent Id as ultimate parent');
			}
		}
	}

	/**
	 * @description Verifies that findAllAncestors handles inaccessible parents due to sharing restrictions.
	 */
	@IsTest
	private static void findAllAncestorsHandlesInaccessibleParentDueToSharing()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c root = TST_Factory.insertFoobar();
			Foobar__c mid = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root.Id).build();
			Foobar__c leaf = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, mid.Id).build();

			User standardUser = getTestUser();

			Foobar__Share leafShare = new Foobar__Share();
			leafShare.ParentId = leaf.Id;
			leafShare.UserOrGroupId = standardUser.Id;
			leafShare.AccessLevel = 'Read';
			leafShare.RowCause = SEL_ObjectShare.ROW_CAUSE_MANUAL;
			DML_Builder.newTransaction().doInsert(leafShare).execute();

			System.runAs(standardUser)
			{
				Test.startTest();
				List<SObject> ancestors = SEL_Hierarchy.forField(PARENT_FIELD).findAllAncestors(leaf.Id);
				Test.stopTest();

				Assert.isTrue(ancestors.isEmpty(), 'Should return empty ancestors list when parent is inaccessible');
			}
		}
	}

	/**
	 * @description Verifies that findUltimateParents handles bulk operations with inaccessible parents due to sharing.
	 */
	@IsTest
	private static void findUltimateParentsHandlesInaccessibleParentDueToSharingBulk()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c root1 = TST_Factory.insertFoobar();
			Foobar__c mid1 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root1.Id).build();
			Foobar__c leaf1 = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, mid1.Id).build();

			Foobar__c root2 = TST_Factory.insertFoobar();

			User standardUser = getTestUser();

			Foobar__Share leaf1Share = new Foobar__Share();
			leaf1Share.ParentId = leaf1.Id;
			leaf1Share.UserOrGroupId = standardUser.Id;
			leaf1Share.AccessLevel = 'Read';
			leaf1Share.RowCause = SEL_ObjectShare.ROW_CAUSE_MANUAL;

			Foobar__Share root2Share = new Foobar__Share();
			root2Share.ParentId = root2.Id;
			root2Share.UserOrGroupId = standardUser.Id;
			root2Share.AccessLevel = 'Read';
			root2Share.RowCause = SEL_ObjectShare.ROW_CAUSE_MANUAL;

			DML_Builder.newTransaction()
					.doInsert(new List<Foobar__Share> {leaf1Share, root2Share}).execute();

			System.runAs(standardUser)
			{
				Test.startTest();
				Map<Id, Id> ultimateParents = SEL_Hierarchy.forField(PARENT_FIELD)
						.findUltimateParents(new Set<Id> {leaf1.Id, root2.Id});
				Test.stopTest();

				Assert.areEqual(mid1.Id, ultimateParents.get(leaf1.Id), 'Leaf1 should return inaccessible parent Id');
				Assert.areEqual(root2.Id, ultimateParents.get(root2.Id), 'Root2 should return itself as ultimate parent');
			}
		}
	}

	/**
	 * @description Verifies that a single Selector instance can be reused for multiple operations.
	 */
	@IsTest
	private static void selectorCanBeReusedForMultipleOperations()
	{
		System.runAs(getTestAdmin())
		{
			Foobar__c root = TST_Factory.insertFoobar();
			Foobar__c child = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, root.Id).build();
			Foobar__c grandChild = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, child.Id).build();

			Test.startTest();
			SEL_Hierarchy.Selector selector = SEL_Hierarchy.forField(PARENT_FIELD);

			Id ultimateParent = selector.findUltimateParent(grandChild.Id);
			Set<Id> descendants = selector.findAllDescendants(root.Id);
			Map<Id, Id> bulkParents = selector.findUltimateParents(new Set<Id> {child.Id, grandChild.Id});
			Test.stopTest();

			Assert.areEqual(root.Id, ultimateParent, 'findUltimateParent should work');
			Assert.areEqual(2, descendants.size(), 'findAllDescendants should work');
			Assert.areEqual(root.Id, bulkParents.get(child.Id), 'findUltimateParents should work for child');
			Assert.areEqual(root.Id, bulkParents.get(grandChild.Id), 'findUltimateParents should work for grandchild');
		}
	}

	/**
	 * @description Creates a linear hierarchy of specified depth.
	 * Returns list ordered from root (index 0) to deepest child (last index).
	 *
	 * @param depth Number of levels in the hierarchy (minimum 1 for root only).
	 *
	 * @return List of Foobar__c records ordered from root to deepest child.
	 */
	@SuppressWarnings('PMD.OperationWithLimitsInLoop')
	private static List<Foobar__c> createHierarchy(Integer depth)
	{
		List<Foobar__c> hierarchy = new List<Foobar__c>();

		Foobar__c root = TST_Factory.insertFoobar();
		hierarchy.add(root);

		Foobar__c previousRecord = root;
		for(Integer i = 1; i < depth; i++)
		{
			Foobar__c record = (Foobar__c)TST_Factory.getFoobarBuilder()
					.withOverride(Foobar__c.Lookup__c, previousRecord.Id).build();
			hierarchy.add(record);
			previousRecord = record;
		}

		return hierarchy;
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup for use with
	 * System.runAs, so each test body runs with a fresh permission-evaluation context.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}
}