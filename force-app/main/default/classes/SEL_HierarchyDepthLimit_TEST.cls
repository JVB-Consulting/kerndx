// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests for the depth limit of SEL_Hierarchy: every search stops at the limit set by withMaxDepth (20 by
 * default), throws a HierarchyException when records are still to resolve there, and still succeeds for a hierarchy exactly as
 * deep as the limit. Records that point at each other in a circle end in the same error for every search that walks up the
 * hierarchy, which propagateToDescendants and calculateUltimateParents do first. findAllDescendants instead returns the records
 * of a circle shorter than the limit (findAllDescendantsHandlesCircularReference in SEL_Hierarchy_TEST). The other hierarchy
 * behaviour is tested in SEL_Hierarchy_TEST.
 *
 * NOTE: isParallel=false is required because the test setup inserts a User, and User DML is not permitted in parallel tests.
 *
 * @see SEL_Hierarchy
 * @see SEL_Hierarchy_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_HierarchyDepthLimit_TEST
{
	/**
	 * @description Company name of the admin user created in the test setup. Each test finds that user by this name and runs
	 * as them.
	 */
	private static final String TEST_ADMIN_COMPANY = 'SEL_HierarchyDepthLimit_TEST-admin';

	/**
	 * @description The lookup from a Foobar__c record to another Foobar__c record. It is the parent link the tests build their
	 * record trees with and ask the selector to follow.
	 */
	private static final SObjectField PARENT_FIELD = Foobar__c.Lookup__c;

	/**
	 * @description A small depth limit the tests give the selector, so a hierarchy as deep as the limit, or one level deeper,
	 * needs only a few records.
	 */
	private static final Integer SMALL_DEPTH_LIMIT = 3;

	/**
	 * @description The default depth limit the global ApexDoc of withMaxDepth promises a selector starts with.
	 */
	private static final Integer DOCUMENTED_DEFAULT_DEPTH_LIMIT = 20;

	/**
	 * @description The depth limit the circle tests give the selector: above the three records of the circle, so the circle
	 * itself, not a short limit, is what makes the search reach it.
	 */
	private static final Integer CIRCLE_DEPTH_LIMIT = 10;

	/**
	 * @description How many records createCircle links into a circle.
	 */
	private static final Integer CIRCLE_SIZE = 3;

	/**
	 * @description Words every depth-limit error message contains, because records that point at each other in a circle are
	 * the usual reason a search reaches the limit. A test that builds such a circle checks the error names it.
	 */
	private static final String CIRCULAR_REFERENCE_PHRASE = 'circular reference';

	/**
	 * @description Creates the admin user the tests run as. It runs in its own transaction before the test methods, because a
	 * User cannot be inserted inside a test that also runs as another user.
	 */
	@TestSetup
	private static void setupTestData()
	{
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_SYSTEM_ADMIN, TEST_ADMIN_COMPANY, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);
	}

	/**
	 * @description Proves that a selector starts with the default limit of 20 levels that the global ApexDoc of withMaxDepth
	 * states, so the documented number and the code cannot drift apart.
	 */
	@IsTest
	private static void shouldStartWithTheDocumentedDefaultDepthLimit()
	{
		Assert.areEqual(DOCUMENTED_DEFAULT_DEPTH_LIMIT, SEL_Hierarchy.DEFAULT_MAX_DEPTH, 'Expected the documented default limit, got ' + SEL_Hierarchy.DEFAULT_MAX_DEPTH);
	}

	/**
	 * @description Proves that findAllDescendants throws when the record has one level of descendants more than the limit,
	 * instead of returning a set that leaves the deepest record out.
	 */
	@IsTest
	private static void findAllDescendantsThrowsWhenHierarchyIsDeeperThanLimit()
	{
		System.runAs(findTestAdmin())
		{
			List<Foobar__c> hierarchy = createHierarchy(SMALL_DEPTH_LIMIT + 2);

			Test.startTest();
			try
			{
				Set<Id> descendants = SEL_Hierarchy.forField(PARENT_FIELD).withMaxDepth(SMALL_DEPTH_LIMIT).findAllDescendants(hierarchy[0].Id);
				Assert.fail('Expected a HierarchyException for a hierarchy deeper than the limit, got ' + descendants.size() + ' descendants');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, SEL_Hierarchy.HierarchyException.class, 'Expected a HierarchyException from findAllDescendants, got ' + error.getTypeName());
				Assert.areEqual(buildDepthLimitMessage(), error.getMessage(), 'Expected the descendant depth message from findAllDescendants, got ' + error.getMessage());
			}
			Test.stopTest();
		}
	}

	/**
	 * @description Proves that findAllDescendants still succeeds when the descendants go exactly as deep as the limit: the
	 * search checks one level further, finds nothing left, and returns every descendant without the starting record.
	 */
	@IsTest
	private static void findAllDescendantsSucceedsWhenHierarchyIsExactlyAtLimit()
	{
		System.runAs(findTestAdmin())
		{
			List<Foobar__c> hierarchy = createHierarchy(SMALL_DEPTH_LIMIT + 1);
			Set<Id> expectedIds = new Map<Id, Foobar__c>(hierarchy).keySet();
			expectedIds.remove(hierarchy[0].Id);

			Test.startTest();
			Set<Id> descendants = SEL_Hierarchy.forField(PARENT_FIELD).withMaxDepth(SMALL_DEPTH_LIMIT).findAllDescendants(hierarchy[0].Id);
			Test.stopTest();

			Assert.areEqual(expectedIds, descendants, 'Expected every descendant down to the limit, got ' + descendants);
		}
	}

	/**
	 * @description Proves that propagateToDescendants throws when the changed record has one level of descendants more than
	 * the limit. Without the error the deepest record would be left out of the records to update and keep a stale ultimate
	 * parent, with nothing to tell the caller.
	 */
	@IsTest
	private static void propagateToDescendantsThrowsWhenHierarchyIsDeeperThanLimit()
	{
		System.runAs(findTestAdmin())
		{
			List<Foobar__c> hierarchy = createHierarchy(SMALL_DEPTH_LIMIT + 2);

			Test.startTest();
			try
			{
				List<SObject> recordsToUpdate = SEL_Hierarchy.forField(PARENT_FIELD).withMaxDepth(SMALL_DEPTH_LIMIT)
						.propagateToDescendants(new Set<Id> {hierarchy[0].Id}, Foobar__c.Text__c);
				Assert.fail('Expected a HierarchyException for a hierarchy deeper than the limit, got ' + recordsToUpdate.size() + ' records to update');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, SEL_Hierarchy.HierarchyException.class, 'Expected a HierarchyException from propagateToDescendants, got ' + error.getTypeName());
				Assert.areEqual(buildDepthLimitMessage(), error.getMessage(), 'Expected the descendant depth message from propagateToDescendants, got ' + error.getMessage());
			}
			Test.stopTest();
		}
	}

	/**
	 * @description Proves that propagateToDescendants still succeeds when the descendants go exactly as deep as the limit: the
	 * search checks one level further, finds nothing left, and returns the changed record and every descendant, each holding
	 * only its Id and the new ultimate parent.
	 */
	@IsTest
	private static void propagateToDescendantsSucceedsWhenHierarchyIsExactlyAtLimit()
	{
		System.runAs(findTestAdmin())
		{
			List<Foobar__c> hierarchy = createHierarchy(SMALL_DEPTH_LIMIT + 1);
			Id rootId = hierarchy[0].Id;
			Set<Id> expectedIds = new Map<Id, Foobar__c>(hierarchy).keySet();

			Test.startTest();
			List<SObject> recordsToUpdate = SEL_Hierarchy.forField(PARENT_FIELD).withMaxDepth(SMALL_DEPTH_LIMIT)
					.propagateToDescendants(new Set<Id> {rootId}, Foobar__c.Text__c);
			Test.stopTest();

			Map<Id, SObject> recordsById = new Map<Id, SObject>(recordsToUpdate);
			Assert.areEqual(SMALL_DEPTH_LIMIT + 1, recordsToUpdate.size(), 'Expected the root and every descendant, got ' + recordsToUpdate.size());
			Assert.areEqual(expectedIds, recordsById.keySet(), 'Expected the Ids of the whole hierarchy, got ' + recordsById.keySet());
			for(SObject record : recordsToUpdate)
			{
				Assert.areEqual(rootId, record.get(Foobar__c.Text__c), 'Expected the root as ultimate parent, got ' + record.get(Foobar__c.Text__c));
				Assert.areEqual(2, record.getPopulatedFieldsAsMap().size(), 'Expected only Id and the ultimate parent field, got ' + record.getPopulatedFieldsAsMap().keySet());
			}
		}
	}

	/**
	 * @description Proves that calculateUltimateParents with descendants throws when the changed record has one level of
	 * descendants more than the limit, instead of returning a map that leaves the deepest record out.
	 */
	@IsTest
	private static void calculateUltimateParentsThrowsWhenHierarchyIsDeeperThanLimit()
	{
		System.runAs(findTestAdmin())
		{
			List<Foobar__c> hierarchy = createHierarchy(SMALL_DEPTH_LIMIT + 2);

			Test.startTest();
			try
			{
				Map<Id, Id> result = SEL_Hierarchy.forField(PARENT_FIELD).withMaxDepth(SMALL_DEPTH_LIMIT)
						.calculateUltimateParents(new Set<Id> {hierarchy[0].Id}, true);
				Assert.fail('Expected a HierarchyException for a hierarchy deeper than the limit, got ' + result.size() + ' entries');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, SEL_Hierarchy.HierarchyException.class, 'Expected a HierarchyException from calculateUltimateParents, got ' + error.getTypeName());
				Assert.areEqual(buildDepthLimitMessage(), error.getMessage(), 'Expected the descendant depth message from calculateUltimateParents, got ' + error.getMessage());
			}
			Test.stopTest();
		}
	}

	/**
	 * @description Proves that calculateUltimateParents with descendants still succeeds when the descendants go exactly as
	 * deep as the limit, mapping the changed record and every descendant to the root.
	 */
	@IsTest
	private static void calculateUltimateParentsSucceedsWhenHierarchyIsExactlyAtLimit()
	{
		System.runAs(findTestAdmin())
		{
			List<Foobar__c> hierarchy = createHierarchy(SMALL_DEPTH_LIMIT + 1);
			Id rootId = hierarchy[0].Id;
			Set<Id> expectedIds = new Map<Id, Foobar__c>(hierarchy).keySet();

			Test.startTest();
			Map<Id, Id> result = SEL_Hierarchy.forField(PARENT_FIELD).withMaxDepth(SMALL_DEPTH_LIMIT)
					.calculateUltimateParents(new Set<Id> {rootId}, true);
			Test.stopTest();

			Assert.areEqual(expectedIds, result.keySet(), 'Expected the Ids of the whole hierarchy, got ' + result.keySet());
			Assert.areEqual(new Set<Id> {rootId}, new Set<Id>(result.values()), 'Expected every record to map to the root, got ' + result.values());
		}
	}

	/**
	 * @description Proves that findUltimateParents ends a circular reference with a HierarchyException: walking up a circle
	 * never reaches a record without a parent, so the search reaches the limit with the record still to resolve.
	 */
	@IsTest
	private static void findUltimateParentsThrowsExceptionForCircularReference()
	{
		System.runAs(findTestAdmin())
		{
			List<Foobar__c> circle = createCircle();

			Test.startTest();
			try
			{
				Map<Id, Id> result = SEL_Hierarchy.forField(PARENT_FIELD).withMaxDepth(CIRCLE_DEPTH_LIMIT).findUltimateParents(new Set<Id> {circle[0].Id});
				Assert.fail('Expected a HierarchyException for a circular reference from findUltimateParents, got ' + result);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, SEL_Hierarchy.HierarchyException.class, 'Expected a HierarchyException from findUltimateParents, got ' + error.getTypeName());
				Assert.isTrue(error.getMessage().contains(CIRCULAR_REFERENCE_PHRASE), 'Expected findUltimateParents to name a circular reference, got ' + error.getMessage());
			}
			Test.stopTest();
		}
	}

	/**
	 * @description Proves that findAllAncestors ends a circular reference with a HierarchyException instead of collecting the
	 * same records again and again until the limit.
	 */
	@IsTest
	private static void findAllAncestorsThrowsExceptionForCircularReference()
	{
		System.runAs(findTestAdmin())
		{
			List<Foobar__c> circle = createCircle();

			Test.startTest();
			try
			{
				List<SObject> ancestors = SEL_Hierarchy.forField(PARENT_FIELD).withMaxDepth(CIRCLE_DEPTH_LIMIT).findAllAncestors(circle[0].Id);
				Assert.fail('Expected a HierarchyException for a circular reference from findAllAncestors, got ' + ancestors.size() + ' ancestors');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, SEL_Hierarchy.HierarchyException.class, 'Expected a HierarchyException from findAllAncestors, got ' + error.getTypeName());
				Assert.isTrue(error.getMessage().contains(CIRCULAR_REFERENCE_PHRASE), 'Expected findAllAncestors to name a circular reference, got ' + error.getMessage());
			}
			Test.stopTest();
		}
	}

	/**
	 * @description Proves that calculateUltimateParents with descendants ends a circular reference with a HierarchyException
	 * instead of looping or returning a map: in a circle every record is its own ancestor, so the upward search reaches the
	 * limit with records still to resolve.
	 */
	@IsTest
	private static void calculateUltimateParentsWithDescendantsThrowsOnCircularReference()
	{
		System.runAs(findTestAdmin())
		{
			List<Foobar__c> circle = createCircle();

			Test.startTest();
			try
			{
				Map<Id, Id> result = SEL_Hierarchy.forField(PARENT_FIELD).withMaxDepth(CIRCLE_DEPTH_LIMIT)
						.calculateUltimateParents(new Set<Id> {circle[0].Id}, true);
				Assert.fail('Expected a HierarchyException for a circular reference from calculateUltimateParents, got ' + result);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, SEL_Hierarchy.HierarchyException.class, 'Expected a HierarchyException from calculateUltimateParents, got ' + error.getTypeName());
				Assert.isTrue(error.getMessage().contains(CIRCULAR_REFERENCE_PHRASE), 'Expected calculateUltimateParents to name a circular reference, got ' + error.getMessage());
			}
			Test.stopTest();
		}
	}

	/**
	 * @description Proves that propagateToDescendants ends a circular reference with a HierarchyException instead of looping
	 * or returning records: in a circle every record is its own ancestor, so the upward search reaches the limit with records
	 * still to resolve.
	 */
	@IsTest
	private static void propagateToDescendantsThrowsOnCircularReference()
	{
		System.runAs(findTestAdmin())
		{
			List<Foobar__c> circle = createCircle();

			Test.startTest();
			try
			{
				List<SObject> recordsToUpdate = SEL_Hierarchy.forField(PARENT_FIELD).withMaxDepth(CIRCLE_DEPTH_LIMIT)
						.propagateToDescendants(new Set<Id> {circle[0].Id}, Foobar__c.Text__c);
				Assert.fail('Expected a HierarchyException for a circular reference from propagateToDescendants, got ' + recordsToUpdate.size() + ' records to update');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, SEL_Hierarchy.HierarchyException.class, 'Expected a HierarchyException from propagateToDescendants, got ' + error.getTypeName());
				Assert.isTrue(error.getMessage().contains(CIRCULAR_REFERENCE_PHRASE), 'Expected propagateToDescendants to name a circular reference, got ' + error.getMessage());
			}
			Test.stopTest();
		}
	}

	/**
	 * @description Builds the message both descendant searches throw at SMALL_DEPTH_LIMIT, from the selector's own template.
	 *
	 * @return The expected error message for a search stopped at SMALL_DEPTH_LIMIT.
	 */
	private static String buildDepthLimitMessage()
	{
		return String.format(SEL_Hierarchy.DESCENDANT_DEPTH_EXCEEDED_MESSAGE, new List<Object> {String.valueOf(SMALL_DEPTH_LIMIT)});
	}

	/**
	 * @description Inserts a chain of records where each record's parent is the one before it.
	 *
	 * @param recordCount How many records the chain holds, the root included: the root has recordCount - 1 levels below it.
	 *
	 * @return The records ordered from the root (index 0) to the deepest record.
	 */
	@SuppressWarnings('PMD.OperationWithLimitsInLoop')
	private static List<Foobar__c> createHierarchy(Integer recordCount)
	{
		List<Foobar__c> chain = new List<Foobar__c> {TST_Factory.insertFoobar()};

		while(chain.size() < recordCount)
		{
			Id parentId = chain[chain.size() - 1].Id;
			chain.add((Foobar__c)TST_Factory.getFoobarBuilder().withOverride(PARENT_FIELD, parentId).build());
		}

		return chain;
	}

	/**
	 * @description Inserts CIRCLE_SIZE records that point at each other in a circle: each record's parent is the one before it,
	 * and the first record's parent is the last.
	 *
	 * @return The records of the circle, in the order they were linked.
	 */
	private static List<Foobar__c> createCircle()
	{
		List<Foobar__c> circle = createHierarchy(CIRCLE_SIZE);
		Foobar__c first = circle[0];
		first.put(PARENT_FIELD, circle[CIRCLE_SIZE - 1].Id);
		DML_Builder.newTransaction().doUpdate(first).execute();
		return circle;
	}

	/**
	 * @description Finds the admin user created in the test setup, so each test body runs as a committed user with the
	 * framework's admin permission set.
	 *
	 * @return The test admin User record.
	 */
	private static User findTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}
}
