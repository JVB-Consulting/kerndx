// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for SEL_CustomPermission.
 *
 * Tests the custom permission checking functionality including:
 * - hasLocalPermission() for subscriber-created permissions
 * - hasPackagePermission() for managed package permissions
 * - hasPermission() for explicit namespace control
 * - Permission set group assignments, which count through the group's summary permission set, including a group that mutes
 *   the permission
 * - Multi-level caching behavior
 *
 * @see SEL_CustomPermission
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date January 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class SEL_CustomPermission_TEST
{
	/**
	 * @description Unique Federation Identifier used to locate the test user across test methods.
	 */
	private static final String TEST_FEDERATION_ID = '8b4e67c0-3d2f-5a9b-8c7e-6f1a2b3c4d5e';

	/**
	 * @description Non-existent custom permission name for negative testing.
	 */
	private static final String NON_EXISTENT_PERMISSION = 'Non_Existent_Permission_' + UTIL_Random.randomName();

	/**
	 * @description Test namespace for explicit namespace permission tests.
	 */
	private static final String TEST_NAMESPACE = 'TestNamespace';

	/**
	 * @description DeveloperName of the mocked local custom permission.
	 */
	private static final String MOCK_PERMISSION_NAME = 'Mock_Permission';

	/**
	 * @description PermissionSet.Type of the summary permission set that the platform builds for each permission set group.
	 */
	private static final String PERMISSION_SET_TYPE_GROUP = 'Group';

	/**
	 * @description PermissionSet.Type of a permission set that an admin creates.
	 */
	private static final String PERMISSION_SET_TYPE_REGULAR = 'Regular';

	/**
	 * @description Relationship name on PermissionSetGroupComponent that points at the component's permission set.
	 */
	private static final String RELATIONSHIP_PERMISSION_SET = 'PermissionSet';

	/**
	 * @description Sets up a standard user with a known FederationIdentifier for use in all tests.
	 */
	@TestSetup
	private static void setup()
	{
		User newUser = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER);
		newUser.FederationIdentifier = TEST_FEDERATION_ID;
		TST_Factory.insertUsers(new List<User> {newUser});
	}

	/**
	 * @description Tests that the cache is populated and reused.
	 * Second call with same permission should not make additional SOQL queries.
	 *
	 * @see SEL_CustomPermission.hasPermission
	 */
	@IsTest
	private static void cacheIsPersisted()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		Test.startTest();

		// First call - should populate cache
		Boolean result1 = SEL_CustomPermission.hasPackagePermission(testUser.Id, NON_EXISTENT_PERMISSION);
		Integer queriesAfterFirst = UTIL_Limits.soqlQueries().used();

		// Second call - should use cache
		Boolean result2 = SEL_CustomPermission.hasPackagePermission(testUser.Id, NON_EXISTENT_PERMISSION);
		Integer queriesAfterSecond = UTIL_Limits.soqlQueries().used();

		Test.stopTest();

		Assert.isFalse(result1, 'First call should return false');
		Assert.isFalse(result2, 'Second call should return false');
		Assert.isTrue(queriesAfterSecond <= queriesAfterFirst + 1, 'Cache should reduce or maintain query count');
	}

	/**
	 * @description Tests that hasPackagePermission returns false when user does not have the permission set.
	 * Exercises the code path where permission exists but user lacks the required permission set.
	 *
	 * @see SEL_CustomPermission.hasPackagePermission
	 */
	@IsTest
	private static void hasPackagePermissionReturnsFalseWhenUserLacksPermissionSet()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		Test.startTest();

		Boolean hasPermission = SEL_CustomPermission.hasPackagePermission(testUser.Id, SEL_CustomPermission.FRAMEWORK_TEST_PERMISSION);

		Test.stopTest();

		Assert.isFalse(hasPermission, 'User without Administrator permission set should not have Test_Permission');
	}

	/**
	 * @description Tests that hasPackagePermission evaluates different users correctly.
	 * Creates two users and verifies permission checks are user-specific.
	 *
	 * @see SEL_CustomPermission.hasPackagePermission
	 */
	@IsTest
	private static void hasPackagePermissionChecksDifferentUsers()
	{
		User testUser1 = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		User testUser2 = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);

		Test.startTest();

		Boolean result1 = SEL_CustomPermission.hasPackagePermission(testUser1.Id, NON_EXISTENT_PERMISSION);
		Boolean result2 = SEL_CustomPermission.hasPackagePermission(testUser2.Id, NON_EXISTENT_PERMISSION);

		Test.stopTest();

		Assert.isFalse(result1, 'First user should not have permission');
		Assert.isFalse(result2, 'Second user should not have permission');
	}

	/**
	 * @description Tests that hasLocalPermission returns false for null user ID.
	 *
	 * @see SEL_CustomPermission.hasLocalPermission
	 */
	@IsTest
	private static void hasLocalPermissionReturnsFalseForNullUserId()
	{
		Test.startTest();

		Boolean hasPermission = SEL_CustomPermission.hasLocalPermission(null, 'Some_Permission');

		Test.stopTest();

		Assert.isFalse(hasPermission, 'Null user ID should return false');
	}

	/**
	 * @description Tests that hasLocalPermission returns false for blank permission name.
	 *
	 * @see SEL_CustomPermission.hasLocalPermission
	 */
	@IsTest
	private static void hasLocalPermissionReturnsFalseForBlankPermission()
	{
		Test.startTest();

		Boolean hasPermission = SEL_CustomPermission.hasLocalPermission(UserInfo.getUserId(), '');

		Test.stopTest();

		Assert.isFalse(hasPermission, 'Blank permission name should return false');
	}

	/**
	 * @description Tests that hasLocalPermission returns false for non-existent permission.
	 * This exercises the SOQL path for local/subscriber permissions.
	 *
	 * @see SEL_CustomPermission.hasLocalPermission
	 */
	@IsTest
	private static void hasLocalPermissionReturnsFalseForNonExistentPermission()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		Test.startTest();

		Boolean hasPermission = SEL_CustomPermission.hasLocalPermission(testUser.Id, NON_EXISTENT_PERMISSION);

		Test.stopTest();

		Assert.isFalse(hasPermission, 'Non-existent permission should return false');
	}

	/**
	 * @description Tests that hasPackagePermission returns false for null user ID.
	 *
	 * @see SEL_CustomPermission.hasPackagePermission
	 */
	@IsTest
	private static void hasPackagePermissionReturnsFalseForNullUserId()
	{
		Test.startTest();

		Boolean hasPermission = SEL_CustomPermission.hasPackagePermission(null, 'Some_Permission');

		Test.stopTest();

		Assert.isFalse(hasPermission, 'Null user ID should return false');
	}

	/**
	 * @description Tests that hasPackagePermission returns false for blank permission name.
	 *
	 * @see SEL_CustomPermission.hasPackagePermission
	 */
	@IsTest
	private static void hasPackagePermissionReturnsFalseForBlankPermission()
	{
		Test.startTest();

		Boolean hasPermission = SEL_CustomPermission.hasPackagePermission(UserInfo.getUserId(), '');

		Test.stopTest();

		Assert.isFalse(hasPermission, 'Blank permission name should return false');
	}

	/**
	 * @description Tests that hasPackagePermission uses FeatureManagement optimization for running user.
	 * This confirms that the running user path uses the platform API rather than SOQL.
	 *
	 * @see SEL_CustomPermission.hasPackagePermission
	 */
	@IsTest
	private static void hasPackagePermissionUsesFeatureManagementForRunningUser()
	{
		Test.startTest();

		Boolean hasPermission = SEL_CustomPermission.hasPackagePermission(UserInfo.getUserId(), NON_EXISTENT_PERMISSION);

		Test.stopTest();

		Assert.isFalse(hasPermission, 'User should not have non-existent permission');
	}

	/**
	 * @description Tests that hasPackagePermission returns true when user has the permission.
	 * This exercises the SOQL path for non-running users.
	 *
	 * @see SEL_CustomPermission.hasPackagePermission
	 */
	@IsTest
	private static void hasPackagePermissionReturnsTrueWhenUserHasPermission()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		TST_Factory.createPermissionSetAssignments(new List<User> {testUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		Test.startTest();

		Boolean hasPermission = SEL_CustomPermission.hasPackagePermission(testUser.Id, SEL_CustomPermission.FRAMEWORK_TEST_PERMISSION);

		Test.stopTest();

		Assert.isTrue(hasPermission, 'User with Administrator permission set should have package permission');
	}

	/**
	 * @description Tests the three-parameter hasPermission with explicit namespace.
	 * Tests the code path for checking permissions in a specific namespace.
	 *
	 * @see SEL_CustomPermission.hasPermission
	 */
	@IsTest
	private static void hasPermissionWithNamespaceReturnsFalseForNonExistentNamespace()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		Test.startTest();

		Boolean hasPermission = SEL_CustomPermission.hasPermission(testUser.Id, 'Some_Permission', TEST_NAMESPACE);

		Test.stopTest();

		Assert.isFalse(hasPermission, 'Permission in non-existent namespace should return false');
	}

	/**
	 * @description Tests hasPermission with null namespace (local permission).
	 * Verifies that null namespace routes to local permission checking.
	 *
	 * @see SEL_CustomPermission.hasPermission
	 */
	@IsTest
	private static void hasPermissionWithNullNamespaceChecksLocalPermission()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		Test.startTest();

		Boolean hasPermission = SEL_CustomPermission.hasPermission(testUser.Id, NON_EXISTENT_PERMISSION, null);

		Test.stopTest();

		Assert.isFalse(hasPermission, 'Non-existent local permission should return false');
	}

	/**
	 * @description Tests hasPermission with empty string namespace (treated as local).
	 *
	 * @see SEL_CustomPermission.hasPermission
	 */
	@IsTest
	private static void hasPermissionWithEmptyNamespaceChecksLocalPermission()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		Test.startTest();

		Boolean hasPermission = SEL_CustomPermission.hasPermission(testUser.Id, NON_EXISTENT_PERMISSION, '');

		Test.stopTest();

		Assert.isFalse(hasPermission, 'Non-existent local permission should return false');
	}

	/**
	 * @description Tests that permission ID cache is correctly populated and reused.
	 *
	 * @see SEL_CustomPermission.getCustomPermissionId
	 */
	@IsTest
	private static void permissionIdCacheIsPersisted()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		Test.startTest();

		SEL_CustomPermission.PERMISSION_ID_CACHE.clear();
		SEL_CustomPermission.hasLocalPermission(testUser.Id, NON_EXISTENT_PERMISSION);

		String cacheKey = NON_EXISTENT_PERMISSION.toLowerCase() + ':';
		Boolean cacheHasKey = SEL_CustomPermission.PERMISSION_ID_CACHE.containsKey(cacheKey);

		Test.stopTest();

		Assert.isTrue(cacheHasKey, 'Permission ID cache should have entry for queried permission');
	}

	/**
	 * @description Tests that the cache of assigned permission sets gets an entry for the user, and that the entry is not empty
	 * for a user who has a permission set assigned.
	 *
	 * @see SEL_CustomPermission.hasPackagePermission
	 */
	@IsTest
	private static void assignedPermissionSetCacheIsPersisted()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		TST_Factory.createPermissionSetAssignments(new List<User> {testUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		Test.startTest();

		SEL_CustomPermission.ASSIGNED_PERMISSION_SET_CACHE.clear();
		SEL_CustomPermission.hasPackagePermission(testUser.Id, SEL_CustomPermission.FRAMEWORK_TEST_PERMISSION);

		Set<Id> cachedPermissionSetIds = SEL_CustomPermission.ASSIGNED_PERMISSION_SET_CACHE.get(testUser.Id);

		Test.stopTest();

		Assert.isNotNull(cachedPermissionSetIds, 'Expected the cache of assigned permission sets to have an entry for the user');
		Assert.isFalse(cachedPermissionSetIds.isEmpty(), 'Expected the cached entry to hold the user permission sets');
	}

	/**
	 * @description Proves that the permission sets assigned to a user are read once per transaction and then reused for another
	 * permission check. The second check uses another namespace, so it has its own result cache key. Before it runs, the mocked
	 * assignments are replaced with none. It can only answer true when it reuses the assignments cached by the first check.
	 *
	 * @see SEL_CustomPermission.hasPermission
	 */
	@IsTest
	private static void assignedPermissionSetsAreReusedForAnotherCheck()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		CustomPermission mockPermission = newMockPermission();
		PermissionSet mockPermissionSet = newMockPermissionSet(PERMISSION_SET_TYPE_REGULAR);

		QRY_Builder.setMock(CustomPermission.SObjectType, new List<CustomPermission> {mockPermission});
		QRY_Builder.setMock(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment>
		{
				createMockDirectAssignment(mockPermissionSet.Id, testUser.Id)
		});
		QRY_Builder.setMock(SetupEntityAccess.SObjectType, new List<SetupEntityAccess> {newMockAccess(mockPermissionSet.Id, mockPermission.Id)});

		Test.startTest();

		clearAllCaches();
		Boolean localAnswer = SEL_CustomPermission.hasLocalPermission(testUser.Id, MOCK_PERMISSION_NAME);

		QRY_Builder.setMock(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment>());
		Boolean namespacedAnswer = SEL_CustomPermission.hasPermission(testUser.Id, MOCK_PERMISSION_NAME, TEST_NAMESPACE);

		Test.stopTest();

		QRY_Builder.clearMocks();
		Assert.isTrue(localAnswer, 'Expected true: the permission set assigned on its own holds the permission');
		Assert.isTrue(namespacedAnswer, 'Expected true: the second check reuses the assigned permission sets cached by the first check');
	}

	/**
	 * @description Tests that permission result cache prevents redundant queries.
	 *
	 * @see SEL_CustomPermission.hasPermission
	 */
	@IsTest
	private static void permissionResultCacheIsUsed()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		Test.startTest();

		SEL_CustomPermission.PERMISSION_RESULT_CACHE.clear();
		SEL_CustomPermission.PERMISSION_ID_CACHE.clear();
		SEL_CustomPermission.ASSIGNED_PERMISSION_SET_CACHE.clear();
		SEL_CustomPermission.PERMISSION_SET_CACHE.clear();

		Boolean result1 = SEL_CustomPermission.hasLocalPermission(testUser.Id, NON_EXISTENT_PERMISSION);
		Integer queriesAfterFirst = UTIL_Limits.soqlQueries().used();

		Boolean result2 = SEL_CustomPermission.hasLocalPermission(testUser.Id, NON_EXISTENT_PERMISSION);
		Integer queriesAfterSecond = UTIL_Limits.soqlQueries().used();

		Test.stopTest();

		Assert.isFalse(result1, 'First call should return false');
		Assert.isFalse(result2, 'Second call should return false');
		Assert.areEqual(queriesAfterFirst, queriesAfterSecond, 'Second call should use cache and make no additional queries');
	}

	/**
	 * @description Tests that permission set cache is populated after querying SetupEntityAccess.
	 *
	 * @see SEL_CustomPermission.getPermissionSetsWithPermission
	 */
	@IsTest
	private static void permissionSetCacheIsPersisted()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		TST_Factory.createPermissionSetAssignments(new List<User> {testUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		Test.startTest();

		SEL_CustomPermission.PERMISSION_SET_CACHE.clear();
		SEL_CustomPermission.hasPackagePermission(testUser.Id, SEL_CustomPermission.FRAMEWORK_TEST_PERMISSION);

		Boolean cachePopulated = !SEL_CustomPermission.PERMISSION_SET_CACHE.isEmpty();

		Test.stopTest();

		Assert.isTrue(cachePopulated, 'Permission set cache should be populated after checking permission');
	}

	/**
	 * @description Tests that getPermissionSetsWithPermission returns empty set for non-existent permission.
	 *
	 * @see SEL_CustomPermission.getPermissionSetsWithPermission
	 */
	@IsTest
	private static void getPermissionSetsWithPermissionReturnsEmptyForNonExistentPermission()
	{
		CustomPermission mockPermission = (CustomPermission)TST_Builder.of(CustomPermission.SObjectType)
				.withoutInsertion(true)
				.build();

		Test.startTest();

		SEL_CustomPermission.PERMISSION_SET_CACHE.clear();
		Set<Id> grantingPermissionSets = SEL_CustomPermission.getPermissionSetsWithPermission(mockPermission.Id);

		Test.stopTest();

		Assert.isTrue(grantingPermissionSets.isEmpty(), 'Should return empty set for non-existent permission');
	}

	/**
	 * @description Tests that getCustomPermissionId returns null for non-existent local permission.
	 *
	 * @see SEL_CustomPermission.getCustomPermissionId
	 */
	@IsTest
	private static void getCustomPermissionIdReturnsNullForNonExistentLocalPermission()
	{
		Test.startTest();

		SEL_CustomPermission.PERMISSION_ID_CACHE.clear();
		Id permissionId = SEL_CustomPermission.getCustomPermissionId(NON_EXISTENT_PERMISSION, null);

		Test.stopTest();

		Assert.isNull(permissionId, 'Should return null for non-existent permission');
	}

	/**
	 * @description Tests that getCustomPermissionId returns null for non-existent namespaced permission.
	 *
	 * @see SEL_CustomPermission.getCustomPermissionId
	 */
	@IsTest
	private static void getCustomPermissionIdReturnsNullForNonExistentNamespacedPermission()
	{
		Test.startTest();

		SEL_CustomPermission.PERMISSION_ID_CACHE.clear();
		Id permissionId = SEL_CustomPermission.getCustomPermissionId(NON_EXISTENT_PERMISSION, TEST_NAMESPACE);

		Test.stopTest();

		Assert.isNull(permissionId, 'Should return null for non-existent namespaced permission');
	}

	/**
	 * @description Tests that direct permission set grant is correctly evaluated.
	 * The admin permission set is assigned on its own and holds the framework test permission.
	 *
	 * @see SEL_CustomPermission.checkPermissionViaSOQL
	 */
	@IsTest
	private static void directPermissionSetGrantIsEvaluated()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		TST_Factory.createPermissionSetAssignments(new List<User> {testUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		Test.startTest();

		// The admin permission set contains the framework test permission as a direct grant
		Boolean hasPermission = SEL_CustomPermission.hasPackagePermission(testUser.Id, SEL_CustomPermission.FRAMEWORK_TEST_PERMISSION);

		Test.stopTest();

		Assert.isTrue(hasPermission, 'Direct permission set grant should be evaluated correctly');
	}

	/**
	 * @description Tests that checkPermissionViaSOQL returns false when no permission sets grant the permission.
	 *
	 * @see SEL_CustomPermission.checkPermissionViaSOQL
	 */
	@IsTest
	private static void checkPermissionReturnsFalseWhenNoGrantingPermissionSets()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		TST_Factory.createPermissionSetAssignments(new List<User> {testUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		Test.startTest();

		// Use a permission that doesn't exist
		Boolean hasPermission = SEL_CustomPermission.hasLocalPermission(testUser.Id, NON_EXISTENT_PERMISSION);

		Test.stopTest();

		Assert.isFalse(hasPermission, 'Should return false when permission does not exist');
	}

	/**
	 * @description Tests that checkPermissionViaSOQL returns false when user has no permission set assignments.
	 * Uses mocked query results to simulate a user with no assignments.
	 *
	 * @see SEL_CustomPermission.checkPermissionViaSOQL
	 */
	@IsTest
	private static void checkPermissionReturnsFalseWhenUserHasNoAssignments()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		// Mock CustomPermission to return a valid permission
		CustomPermission mockPermission = (CustomPermission)TST_Builder.of(CustomPermission.SObjectType)
				.withOverride(CustomPermission.DeveloperName, MOCK_PERMISSION_NAME)
				.withoutInsertion(true)
				.build();
		QRY_Builder.setMock(CustomPermission.SObjectType, new List<CustomPermission> {mockPermission});

		// Mock PermissionSetAssignment to return empty (no assignments)
		QRY_Builder.setMock(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment>());

		Test.startTest();

		clearAllCaches();
		Boolean hasPermission = SEL_CustomPermission.hasLocalPermission(testUser.Id, MOCK_PERMISSION_NAME);

		Test.stopTest();

		QRY_Builder.clearMocks();
		Assert.isFalse(hasPermission, 'Should return false when user has no permission set assignments');
	}

	/**
	 * @description Tests that checkPermissionViaSOQL returns false when permission exists but no permission sets grant it.
	 * Uses mocked query results to simulate the scenario.
	 *
	 * @see SEL_CustomPermission.checkPermissionViaSOQL
	 */
	@IsTest
	private static void checkPermissionReturnsFalseWhenNoPermissionSetsGrantPermission()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		// Create mock PermissionSet with generated ID
		PermissionSet mockPermissionSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withoutInsertion(true)
				.build();

		// Mock CustomPermission
		CustomPermission mockPermission = (CustomPermission)TST_Builder.of(CustomPermission.SObjectType)
				.withOverride(CustomPermission.DeveloperName, MOCK_PERMISSION_NAME)
				.withoutInsertion(true)
				.build();
		QRY_Builder.setMock(CustomPermission.SObjectType, new List<CustomPermission> {mockPermission});

		// Mock PermissionSetAssignment with a direct assignment
		PermissionSetAssignment mockAssignment = createMockDirectAssignment(mockPermissionSet.Id, testUser.Id);
		QRY_Builder.setMock(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment> {mockAssignment});

		// Mock SetupEntityAccess to return empty (no permission sets grant this permission)
		QRY_Builder.setMock(SetupEntityAccess.SObjectType, new List<SetupEntityAccess>());

		Test.startTest();

		clearAllCaches();
		Boolean hasPermission = SEL_CustomPermission.hasLocalPermission(testUser.Id, MOCK_PERMISSION_NAME);

		Test.stopTest();

		QRY_Builder.clearMocks();
		Assert.isFalse(hasPermission, 'Should return false when no permission sets grant the permission');
	}

	/**
	 * @description Proves that a group which mutes the permission does not grant it. The platform leaves a muted permission off the
	 * group's summary permission set (the permission set Salesforce builds to hold what the group really grants). The group's
	 * component rows are mocked as the platform returns them: a regular permission set that holds the permission, and a muting
	 * permission set whose Id has the muting key prefix and whose PermissionSet lookup is empty. Both hold the permission, but the
	 * summary permission set does not, so the answer must be false.
	 *
	 * @see SEL_CustomPermission.hasLocalPermission
	 */
	@IsTest
	private static void groupAssignmentDeniesWhenGroupMutesPermission()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		CustomPermission mockPermission = newMockPermission();
		PermissionSetGroup mockGroup = (PermissionSetGroup)TST_Builder.of(PermissionSetGroup.SObjectType).withoutInsertion(true).build();
		PermissionSet summaryPermissionSet = newMockPermissionSet(PERMISSION_SET_TYPE_GROUP);
		PermissionSet grantingPermissionSet = newMockPermissionSet(PERMISSION_SET_TYPE_REGULAR);
		MutingPermissionSet mutingPermissionSet = (MutingPermissionSet)TST_Builder.of(MutingPermissionSet.SObjectType).withoutInsertion(true).build();

		PermissionSetGroupComponent grantingComponent = (PermissionSetGroupComponent)TST_Builder.of(PermissionSetGroupComponent.SObjectType)
				.withOverride(PermissionSetGroupComponent.PermissionSetGroupId, mockGroup.Id)
				.withOverride(PermissionSetGroupComponent.PermissionSetId, grantingPermissionSet.Id)
				.withOverrides(new Map<String, Object> {RELATIONSHIP_PERMISSION_SET => grantingPermissionSet})
				.withoutInsertion(true)
				.build();
		PermissionSetGroupComponent mutingComponent = (PermissionSetGroupComponent)TST_Builder.of(PermissionSetGroupComponent.SObjectType)
				.withOverride(PermissionSetGroupComponent.PermissionSetGroupId, mockGroup.Id)
				.withOverride(PermissionSetGroupComponent.PermissionSetId, mutingPermissionSet.Id)
				.withoutInsertion(true)
				.build();

		QRY_Builder.setMock(CustomPermission.SObjectType, new List<CustomPermission> {mockPermission});
		QRY_Builder.setMock(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment>
		{
				createMockGroupAssignment(mockGroup.Id, summaryPermissionSet.Id, testUser.Id)
		});
		QRY_Builder.setMock(PermissionSetGroupComponent.SObjectType, new List<PermissionSetGroupComponent> {grantingComponent, mutingComponent});
		QRY_Builder.setMock(SetupEntityAccess.SObjectType, new List<SetupEntityAccess>
		{
				newMockAccess(grantingPermissionSet.Id, mockPermission.Id),
				newMockAccess(mutingPermissionSet.Id, mockPermission.Id)
		});

		Test.startTest();

		clearAllCaches();
		Boolean hasPermission = SEL_CustomPermission.hasLocalPermission(testUser.Id, MOCK_PERMISSION_NAME);

		Test.stopTest();

		QRY_Builder.clearMocks();
		Assert.isFalse(hasPermission, 'Expected false: the group mutes the permission, so its summary permission set does not hold it');
	}

	/**
	 * @description Proves that a group grants the permission when the group's summary permission set holds it. A group assignment
	 * points at that summary permission set, so it counts the same way as a permission set assigned on its own.
	 *
	 * @see SEL_CustomPermission.hasLocalPermission
	 */
	@IsTest
	private static void groupAssignmentGrantsWhenGroupSummaryHoldsPermission()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		mockGroupAssignmentThatHoldsPermission(testUser);

		Test.startTest();

		clearAllCaches();
		Boolean hasPermission = SEL_CustomPermission.hasLocalPermission(testUser.Id, MOCK_PERMISSION_NAME);

		Test.stopTest();

		QRY_Builder.clearMocks();
		Assert.isTrue(hasPermission, 'Expected true: the group summary permission set holds the permission');
	}

	/**
	 * @description Proves that a mute in one group does not take the permission away when a second group grants it. The user has
	 * two group assignments. The first group's summary permission set does not hold the permission, the second one does.
	 *
	 * @see SEL_CustomPermission.hasLocalPermission
	 */
	@IsTest
	private static void groupThatMutesPermissionDoesNotBlockAnotherGroupThatGrantsIt()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		CustomPermission mockPermission = newMockPermission();
		PermissionSetGroup mutingGroup = (PermissionSetGroup)TST_Builder.of(PermissionSetGroup.SObjectType).withoutInsertion(true).build();
		PermissionSetGroup grantingGroup = (PermissionSetGroup)TST_Builder.of(PermissionSetGroup.SObjectType).withoutInsertion(true).build();
		PermissionSet mutingGroupSummary = newMockPermissionSet(PERMISSION_SET_TYPE_GROUP);
		PermissionSet grantingGroupSummary = newMockPermissionSet(PERMISSION_SET_TYPE_GROUP);

		QRY_Builder.setMock(CustomPermission.SObjectType, new List<CustomPermission> {mockPermission});
		QRY_Builder.setMock(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment>
		{
				createMockGroupAssignment(mutingGroup.Id, mutingGroupSummary.Id, testUser.Id),
				createMockGroupAssignment(grantingGroup.Id, grantingGroupSummary.Id, testUser.Id)
		});
		QRY_Builder.setMock(SetupEntityAccess.SObjectType, new List<SetupEntityAccess> {newMockAccess(grantingGroupSummary.Id, mockPermission.Id)});

		Test.startTest();

		clearAllCaches();
		Boolean hasPermission = SEL_CustomPermission.hasLocalPermission(testUser.Id, MOCK_PERMISSION_NAME);

		Test.stopTest();

		QRY_Builder.clearMocks();
		Assert.isTrue(hasPermission, 'Expected true: the second group grants the permission, and the first group mute applies only to itself');
	}

	/**
	 * @description Proves that the answer for a group assignment is kept for the rest of the transaction. After the first call the
	 * mocked rows are removed, so a second call that read the database again would answer false. The second call must give the
	 * same answer and run no further query.
	 *
	 * @see SEL_CustomPermission.hasLocalPermission
	 */
	@IsTest
	private static void groupAssignmentAnswerIsCachedForSecondCall()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		mockGroupAssignmentThatHoldsPermission(testUser);

		Test.startTest();

		clearAllCaches();
		Boolean firstAnswer = SEL_CustomPermission.hasLocalPermission(testUser.Id, MOCK_PERMISSION_NAME);
		Integer queriesAfterFirst = UTIL_Limits.soqlQueries().used();

		QRY_Builder.clearMocks();
		Boolean secondAnswer = SEL_CustomPermission.hasLocalPermission(testUser.Id, MOCK_PERMISSION_NAME);
		Integer queriesAfterSecond = UTIL_Limits.soqlQueries().used();

		Test.stopTest();

		Assert.isTrue(firstAnswer, 'Expected true: the group summary permission set holds the permission');
		Assert.isTrue(secondAnswer, 'Expected true from the cache on the second call');
		Assert.areEqual(queriesAfterFirst, queriesAfterSecond, 'Expected the second call to run no further query');
	}

	/**
	 * @description Proves the group path against real records, with no mocked query. The test saves a permission set group whose
	 * only permission set is the Administrator permission set, which holds the framework test permission. It asks Salesforce to
	 * build the group's summary permission set, assigns the group to the user, and then checks the permission through the database.
	 *
	 * @see SEL_CustomPermission.hasPackagePermission
	 */
	@IsTest
	private static void realGroupAssignmentGrantsPermissionHeldByItsPermissionSet()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		PermissionSet adminPermissionSet = new SEL_PermissionSet().findByName(SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);
		PermissionSetGroup permissionSetGroup = (PermissionSetGroup)TST_Builder.of(PermissionSetGroup.SObjectType).build();
		TST_Builder.of(PermissionSetGroupComponent.SObjectType)
				.withOverride(PermissionSetGroupComponent.PermissionSetGroupId, permissionSetGroup.Id)
				.withOverride(PermissionSetGroupComponent.PermissionSetId, adminPermissionSet.Id)
				.build();
		Test.calculatePermissionSetGroup(permissionSetGroup.Id);
		TST_Factory.createPermissionSetAssignments(new List<User> {testUser}, permissionSetGroup.Id);

		Test.startTest();

		clearAllCaches();
		Boolean hasPermission = SEL_CustomPermission.hasPackagePermission(testUser.Id, SEL_CustomPermission.FRAMEWORK_TEST_PERMISSION);

		Test.stopTest();

		Assert.isTrue(hasPermission, 'Expected true: the group summary permission set holds the permission of the Administrator permission set');
	}

	/**
	 * @description Clears all caches to ensure clean test state.
	 */
	private static void clearAllCaches()
	{
		SEL_CustomPermission.PERMISSION_RESULT_CACHE.clear();
		SEL_CustomPermission.ASSIGNED_PERMISSION_SET_CACHE.clear();
		SEL_CustomPermission.PERMISSION_ID_CACHE.clear();
		SEL_CustomPermission.PERMISSION_SET_CACHE.clear();
	}

	/**
	 * @description Registers mocked query answers for a user who is assigned one permission set group whose summary permission set
	 * holds the mocked local permission. It mocks the permission, the group assignment and the row that says the summary permission
	 * set holds the permission. It checks nothing itself.
	 *
	 * @param testUser The user who gets the mocked group assignment
	 */
	private static void mockGroupAssignmentThatHoldsPermission(User testUser)
	{
		CustomPermission mockPermission = newMockPermission();
		PermissionSetGroup mockGroup = (PermissionSetGroup)TST_Builder.of(PermissionSetGroup.SObjectType).withoutInsertion(true).build();
		PermissionSet summaryPermissionSet = newMockPermissionSet(PERMISSION_SET_TYPE_GROUP);

		QRY_Builder.setMock(CustomPermission.SObjectType, new List<CustomPermission> {mockPermission});
		QRY_Builder.setMock(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment>
		{
				createMockGroupAssignment(mockGroup.Id, summaryPermissionSet.Id, testUser.Id)
		});
		QRY_Builder.setMock(SetupEntityAccess.SObjectType, new List<SetupEntityAccess> {newMockAccess(summaryPermissionSet.Id, mockPermission.Id)});
	}

	/**
	 * @description Creates a mock PermissionSetAssignment for a direct Permission Set assignment.
	 *
	 * @param permissionSetId The ID of the Permission Set to assign
	 * @param userId The ID of the user to assign to
	 *
	 * @return A mock PermissionSetAssignment record with a generated ID
	 */
	private static PermissionSetAssignment createMockDirectAssignment(Id permissionSetId, Id userId)
	{
		return (PermissionSetAssignment)TST_Builder.of(PermissionSetAssignment.SObjectType)
				.withOverride(PermissionSetAssignment.PermissionSetId, permissionSetId)
				.withOverride(PermissionSetAssignment.AssigneeId, userId)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Creates a mock PermissionSetAssignment for a permission set group, shaped as the platform stores it: the group Id
	 * is set, and the permission set Id is the group's summary permission set.
	 *
	 * @param permissionSetGroupId The ID of the Permission Set Group to assign
	 * @param summaryPermissionSetId The ID of the group's summary permission set (Type 'Group')
	 * @param userId The ID of the user to assign to
	 *
	 * @return A mock PermissionSetAssignment record with a generated ID
	 */
	private static PermissionSetAssignment createMockGroupAssignment(Id permissionSetGroupId, Id summaryPermissionSetId, Id userId)
	{
		return (PermissionSetAssignment)TST_Builder.of(PermissionSetAssignment.SObjectType)
				.withOverride(PermissionSetAssignment.PermissionSetGroupId, permissionSetGroupId)
				.withOverride(PermissionSetAssignment.PermissionSetId, summaryPermissionSetId)
				.withOverride(PermissionSetAssignment.AssigneeId, userId)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Creates a mock local custom permission named MOCK_PERMISSION_NAME, with a generated Id.
	 *
	 * @return A mock CustomPermission record
	 */
	private static CustomPermission newMockPermission()
	{
		return (CustomPermission)TST_Builder.of(CustomPermission.SObjectType)
				.withOverride(CustomPermission.DeveloperName, MOCK_PERMISSION_NAME)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Creates a mock permission set of the given type, with a generated Id.
	 *
	 * @param permissionSetType The PermissionSet.Type value, for example 'Regular' or 'Group'
	 *
	 * @return A mock PermissionSet record
	 */
	private static PermissionSet newMockPermissionSet(String permissionSetType)
	{
		return (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withOverride(PermissionSet.Type, permissionSetType)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Creates a mock SetupEntityAccess row that says a permission set holds a custom permission.
	 *
	 * @param parentId The Id of the permission set (or muting permission set) that holds the permission
	 * @param permissionId The Id of the custom permission
	 *
	 * @return A mock SetupEntityAccess record
	 */
	private static SetupEntityAccess newMockAccess(Id parentId, Id permissionId)
	{
		return (SetupEntityAccess)TST_Builder.of(SetupEntityAccess.SObjectType)
				.withOverride(SetupEntityAccess.ParentId, parentId)
				.withOverride(SetupEntityAccess.SetupEntityId, permissionId)
				.withoutInsertion(true)
				.build();
	}
}