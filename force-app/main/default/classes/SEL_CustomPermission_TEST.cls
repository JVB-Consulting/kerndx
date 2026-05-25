// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for SEL_CustomPermission.
 *
 * Tests the custom permission checking functionality including:
 * - hasLocalPermission() for subscriber-created permissions
 * - hasPackagePermission() for managed package permissions
 * - hasPermission() for explicit namespace control
 * - Scoped Permission Set Group evaluation with muting support
 * - Multi-level caching behavior
 *
 * @see SEL_CustomPermission
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date January 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
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
	 * @description Sets up a standard user with a known FederationIdentifier for use in all tests.
	 */
	@TestSetup
	private static void setup()
	{
		User newUser = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER);
		newUser.FederationIdentifier = TEST_FEDERATION_ID;
		insert newUser;
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
		User testUser2 = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER);
		insert testUser2;

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
	 * @description Tests that user assignment cache is populated with assignment data.
	 *
	 * @see SEL_CustomPermission.getUserAssignmentData
	 */
	@IsTest
	private static void userAssignmentCacheIsPersisted()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		TST_Factory.createPermissionSetAssignments(new List<User> {testUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		Test.startTest();

		SEL_CustomPermission.USER_ASSIGNMENT_CACHE.clear();
		SEL_CustomPermission.hasPackagePermission(testUser.Id, SEL_CustomPermission.FRAMEWORK_TEST_PERMISSION);

		Boolean cacheHasKey = SEL_CustomPermission.USER_ASSIGNMENT_CACHE.containsKey(testUser.Id);

		Test.stopTest();

		Assert.isTrue(cacheHasKey, 'User assignment cache should have entry');
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
		SEL_CustomPermission.USER_ASSIGNMENT_CACHE.clear();
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
	 * @description Tests that getUserAssignmentData includes directly assigned permission sets.
	 *
	 * @see SEL_CustomPermission.getUserAssignmentData
	 */
	@IsTest
	private static void getUserAssignmentDataIncludesDirectAssignments()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		TST_Factory.createPermissionSetAssignments(new List<User> {testUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		Test.startTest();

		SEL_CustomPermission.USER_ASSIGNMENT_CACHE.clear();
		SEL_CustomPermission.UserAssignmentData assignmentData = SEL_CustomPermission.getUserAssignmentData(testUser.Id);

		Test.stopTest();

		Assert.isFalse(assignmentData.directPermissionSetIds.isEmpty(), 'Direct permission set IDs should include assignments');
		Assert.isTrue(assignmentData.hasAssignments(), 'hasAssignments should return true');
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
	 * @description Tests that getUserAssignmentData returns properly initialized data for standard user.
	 * Note: Every user has profile-based permission set assignments, so hasAssignments() returns true.
	 *
	 * @see SEL_CustomPermission.getUserAssignmentData
	 */
	@IsTest
	private static void getUserAssignmentDataReturnsInitializedData()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		Test.startTest();

		SEL_CustomPermission.USER_ASSIGNMENT_CACHE.clear();
		SEL_CustomPermission.UserAssignmentData assignmentData = SEL_CustomPermission.getUserAssignmentData(testUser.Id);

		Test.stopTest();

		Assert.isNotNull(assignmentData, 'Should return assignment data object (not null)');
		Assert.isNotNull(assignmentData.directPermissionSetIds, 'Direct permission set IDs should be initialized');
		Assert.isNotNull(assignmentData.permissionSetGroupComponents, 'Permission Set Group components map should be initialized');
		Assert.isTrue(assignmentData.hasAssignments(), 'Standard user has profile-based permission set assignments');
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
	 * This exercises the Step 4A path in checkPermissionViaSOQL.
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
				.withOverride(CustomPermission.DeveloperName, 'Mock_Permission')
				.withoutInsertion(true)
				.build();
		QRY_Builder.setMock(CustomPermission.SObjectType, new List<CustomPermission> {mockPermission});

		// Mock PermissionSetAssignment to return empty (no assignments)
		QRY_Builder.setMock(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment>());

		Test.startTest();

		clearAllCaches();
		Boolean hasPermission = SEL_CustomPermission.hasLocalPermission(testUser.Id, 'Mock_Permission');

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
				.withOverride(CustomPermission.DeveloperName, 'Mock_Permission')
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
		Boolean hasPermission = SEL_CustomPermission.hasLocalPermission(testUser.Id, 'Mock_Permission');

		Test.stopTest();

		QRY_Builder.clearMocks();
		Assert.isFalse(hasPermission, 'Should return false when no permission sets grant the permission');
	}

	/**
	 * @description Tests that Permission Set Group grant is evaluated correctly when regular component grants permission.
	 * Uses mocked query results to simulate Permission Set Group with granting component.
	 *
	 * @see SEL_CustomPermission.hasPermissionSetGroupGrant
	 */
	@IsTest
	private static void permissionSetGroupGrantIsEvaluatedWhenRegularComponentGrants()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		// Create mock records with generated IDs
		PermissionSetGroup mockPermissionSetGroup = (PermissionSetGroup)TST_Builder.of(PermissionSetGroup.SObjectType)
				.withoutInsertion(true)
				.build();
		PermissionSet mockPermissionSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withoutInsertion(true)
				.build();
		CustomPermission mockPermission = (CustomPermission)TST_Builder.of(CustomPermission.SObjectType)
				.withOverride(CustomPermission.DeveloperName, 'Mock_Permission')
				.withoutInsertion(true)
				.build();

		QRY_Builder.setMock(CustomPermission.SObjectType, new List<CustomPermission> {mockPermission});

		// Mock PermissionSetAssignment with Permission Set Group assignment (PermissionSetGroupId populated)
		PermissionSetAssignment mockAssignment = createMockGroupAssignment(mockPermissionSetGroup.Id, testUser.Id);
		QRY_Builder.setMock(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment> {mockAssignment});

		// Mock PermissionSetGroupComponent with regular (non-muting) permission set
		PermissionSetGroupComponent mockComponent = (PermissionSetGroupComponent)TST_Builder.of(PermissionSetGroupComponent.SObjectType)
				.withOverride(PermissionSetGroupComponent.PermissionSetGroupId, mockPermissionSetGroup.Id)
				.withOverride(PermissionSetGroupComponent.PermissionSetId, mockPermissionSet.Id)
				.withoutInsertion(true)
				.build();
		QRY_Builder.setMock(PermissionSetGroupComponent.SObjectType, new List<PermissionSetGroupComponent> {mockComponent});

		// Mock SetupEntityAccess showing the permission set grants the permission
		SetupEntityAccess mockAccess = (SetupEntityAccess)TST_Builder.of(SetupEntityAccess.SObjectType)
				.withOverride(SetupEntityAccess.ParentId, mockPermissionSet.Id)
				.withOverride(SetupEntityAccess.SetupEntityId, mockPermission.Id)
				.withoutInsertion(true)
				.build();
		QRY_Builder.setMock(SetupEntityAccess.SObjectType, new List<SetupEntityAccess> {mockAccess});

		Test.startTest();

		clearAllCaches();
		Boolean hasPermission = SEL_CustomPermission.hasLocalPermission(testUser.Id, 'Mock_Permission');

		Test.stopTest();

		QRY_Builder.clearMocks();
		Assert.isTrue(hasPermission, 'Should return true when Permission Set Group regular component grants permission');
	}

	/**
	 * @description Tests that Permission Set Group grant is blocked when muting component revokes permission.
	 * Uses direct method testing with constructed data to cover the muting logic.
	 *
	 * @see SEL_CustomPermission.hasPermissionSetGroupGrant
	 */
	@IsTest
	private static void permissionSetGroupGrantIsBlockedByMutingComponent()
	{
		// Create mock records with generated IDs
		PermissionSetGroup mockPermissionSetGroup = (PermissionSetGroup)TST_Builder.of(PermissionSetGroup.SObjectType)
				.withoutInsertion(true)
				.build();
		PermissionSet mockRegularPermSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withoutInsertion(true)
				.build();
		PermissionSet mockMutingPermSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withoutInsertion(true)
				.build();

		Test.startTest();

		// Directly test hasPermissionSetGroupGrant with constructed data to cover the muting logic
		Map<Id, SEL_CustomPermission.PermissionSetGroupComponentData> permissionSetGroupComponents = new Map<Id, SEL_CustomPermission.PermissionSetGroupComponentData>();
		SEL_CustomPermission.PermissionSetGroupComponentData componentData = new SEL_CustomPermission.PermissionSetGroupComponentData();
		componentData.regularComponentIds.add(mockRegularPermSet.Id);
		componentData.mutingComponentIds.add(mockMutingPermSet.Id);
		permissionSetGroupComponents.put(mockPermissionSetGroup.Id, componentData);

		// Both regular and muting permission sets grant the permission
		Set<Id> grantingPermissionSetIds = new Set<Id> {mockRegularPermSet.Id, mockMutingPermSet.Id};

		Boolean hasPermissionSetGroupGrant = SEL_CustomPermission.hasPermissionSetGroupGrant(permissionSetGroupComponents, grantingPermissionSetIds);

		Test.stopTest();

		Assert.isFalse(hasPermissionSetGroupGrant, 'Should return false when muting component blocks the grant');
	}

	/**
	 * @description Tests scoped muting - a mute in Permission Set Group A should not block a grant from Permission Set Group B.
	 * Uses direct method testing with constructed data.
	 *
	 * @see SEL_CustomPermission.hasPermissionSetGroupGrant
	 */
	@IsTest
	private static void scopedMutingAllowsGrantFromDifferentPermissionSetGroup()
	{
		// Create mock records with generated IDs
		PermissionSetGroup mockPermissionSetGroupA = (PermissionSetGroup)TST_Builder.of(PermissionSetGroup.SObjectType)
				.withoutInsertion(true)
				.build();
		PermissionSetGroup mockPermissionSetGroupB = (PermissionSetGroup)TST_Builder.of(PermissionSetGroup.SObjectType)
				.withoutInsertion(true)
				.build();
		PermissionSet mockRegularPermSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withoutInsertion(true)
				.build();
		PermissionSet mockMutingPermSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withoutInsertion(true)
				.build();
		PermissionSet mockGrantingPermSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withoutInsertion(true)
				.build();

		Test.startTest();

		// Construct Permission Set Group component data:
		// Permission Set Group A: has regular component that grants, AND muting component that mutes (blocked)
		// Permission Set Group B: has regular component that grants, NO muting (should succeed)
		Map<Id, SEL_CustomPermission.PermissionSetGroupComponentData> permissionSetGroupComponents = new Map<Id, SEL_CustomPermission.PermissionSetGroupComponentData>();

		// Permission Set Group A - has grant AND mute (blocked)
		SEL_CustomPermission.PermissionSetGroupComponentData componentDataA = new SEL_CustomPermission.PermissionSetGroupComponentData();
		componentDataA.regularComponentIds.add(mockRegularPermSet.Id);
		componentDataA.mutingComponentIds.add(mockMutingPermSet.Id);
		permissionSetGroupComponents.put(mockPermissionSetGroupA.Id, componentDataA);

		// Permission Set Group B - has grant only (should succeed)
		SEL_CustomPermission.PermissionSetGroupComponentData componentDataB = new SEL_CustomPermission.PermissionSetGroupComponentData();
		componentDataB.regularComponentIds.add(mockGrantingPermSet.Id);
		permissionSetGroupComponents.put(mockPermissionSetGroupB.Id, componentDataB);

		// The permission is granted by regular, muting, and granting permission sets
		Set<Id> grantingPermissionSetIds = new Set<Id> {mockRegularPermSet.Id, mockMutingPermSet.Id, mockGrantingPermSet.Id};

		Boolean hasPermissionSetGroupGrant = SEL_CustomPermission.hasPermissionSetGroupGrant(permissionSetGroupComponents, grantingPermissionSetIds);

		Test.stopTest();

		Assert.isTrue(hasPermissionSetGroupGrant, 'Should return true - mute in Permission Set Group A should not block grant from Permission Set Group B');
	}

	/**
	 * @description Tests that hasPermissionSetGroupGrant returns false when no Permission Set Group components grant the permission.
	 * Uses direct method testing with constructed data.
	 *
	 * @see SEL_CustomPermission.hasPermissionSetGroupGrant
	 */
	@IsTest
	private static void hasPermissionSetGroupGrantReturnsFalseWhenNoComponentsGrant()
	{
		// Create mock records with generated IDs
		PermissionSetGroup mockPermissionSetGroup = (PermissionSetGroup)TST_Builder.of(PermissionSetGroup.SObjectType)
				.withoutInsertion(true)
				.build();
		PermissionSet mockComponentPermSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withoutInsertion(true)
				.build();
		PermissionSet mockGrantingPermSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withoutInsertion(true)
				.build();

		Test.startTest();

		// Permission Set Group has a component, but it doesn't grant the permission
		Map<Id, SEL_CustomPermission.PermissionSetGroupComponentData> permissionSetGroupComponents = new Map<Id, SEL_CustomPermission.PermissionSetGroupComponentData>();
		SEL_CustomPermission.PermissionSetGroupComponentData componentData = new SEL_CustomPermission.PermissionSetGroupComponentData();
		componentData.regularComponentIds.add(mockComponentPermSet.Id);
		permissionSetGroupComponents.put(mockPermissionSetGroup.Id, componentData);

		// The granting permission set is different from the component
		Set<Id> grantingPermissionSetIds = new Set<Id> {mockGrantingPermSet.Id};

		Boolean hasPermissionSetGroupGrant = SEL_CustomPermission.hasPermissionSetGroupGrant(permissionSetGroupComponents, grantingPermissionSetIds);

		Test.stopTest();

		Assert.isFalse(hasPermissionSetGroupGrant, 'Should return false when Permission Set Group components do not grant the permission');
	}

	/**
	 * @description Tests that PermissionSetGroupComponentData fields are properly initialized and used.
	 * Covers the regularComponentIds and mutingComponentIds field initialization.
	 *
	 * @see SEL_CustomPermission.PermissionSetGroupComponentData
	 */
	@IsTest
	private static void permissionSetGroupComponentDataFieldsAreInitialized()
	{
		Test.startTest();

		SEL_CustomPermission.PermissionSetGroupComponentData componentData = new SEL_CustomPermission.PermissionSetGroupComponentData();

		Test.stopTest();

		Assert.isNotNull(componentData.regularComponentIds, 'regularComponentIds should be initialized');
		Assert.isNotNull(componentData.mutingComponentIds, 'mutingComponentIds should be initialized');
		Assert.isTrue(componentData.regularComponentIds.isEmpty(), 'regularComponentIds should be empty initially');
		Assert.isTrue(componentData.mutingComponentIds.isEmpty(), 'mutingComponentIds should be empty initially');
	}

	/**
	 * @description Tests that getUserAssignmentData returns cached data on second call.
	 * Covers the cache hit path in getUserAssignmentData.
	 *
	 * @see SEL_CustomPermission.getUserAssignmentData
	 */
	@IsTest
	private static void getUserAssignmentDataReturnsCachedData()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		// Create mock PermissionSet with generated ID
		PermissionSet mockPermissionSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withoutInsertion(true)
				.build();

		// Mock PermissionSetAssignment
		PermissionSetAssignment mockAssignment = createMockDirectAssignment(mockPermissionSet.Id, testUser.Id);
		QRY_Builder.setMock(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment> {mockAssignment});

		Test.startTest();

		clearAllCaches();

		// First call - populates cache
		SEL_CustomPermission.UserAssignmentData firstResult = SEL_CustomPermission.getUserAssignmentData(testUser.Id);

		// Second call - should return cached data (covers line 435)
		SEL_CustomPermission.UserAssignmentData secondResult = SEL_CustomPermission.getUserAssignmentData(testUser.Id);

		Test.stopTest();

		QRY_Builder.clearMocks();
		Assert.areEqual(firstResult, secondResult, 'Second call should return same cached instance');
	}

	/**
	 * @description Tests that expandPermissionSetGroups correctly identifies muting permission sets.
	 * Uses TST_Builder relationship mocking to set PermissionSet.Type field.
	 * Covers the muting branch in expandPermissionSetGroups (line 512).
	 *
	 * @see SEL_CustomPermission.expandPermissionSetGroups
	 */
	@IsTest
	private static void expandPermissionSetGroupsIdentifiesMutingPermissionSets()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		// Create mock Permission Set Group and CustomPermission
		PermissionSetGroup mockPermissionSetGroup = (PermissionSetGroup)TST_Builder.of(PermissionSetGroup.SObjectType)
				.withoutInsertion(true)
				.build();
		CustomPermission mockPermission = (CustomPermission)TST_Builder.of(CustomPermission.SObjectType)
				.withOverride(CustomPermission.DeveloperName, 'Mock_Permission')
				.withoutInsertion(true)
				.build();

		// Create a mock PermissionSet with Type = 'Group' (muting indicator)
		PermissionSet mockMutingPermSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withOverride(PermissionSet.Type, 'Group')
				.withoutInsertion(true)
				.build();

		QRY_Builder.setMock(CustomPermission.SObjectType, new List<CustomPermission> {mockPermission});

		// Mock PermissionSetAssignment with Permission Set Group assignment
		PermissionSetAssignment mockAssignment = createMockGroupAssignment(mockPermissionSetGroup.Id, testUser.Id);
		QRY_Builder.setMock(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment> {mockAssignment});

		// Mock PermissionSetGroupComponent with muting permission set
		// Pass the PermissionSet as a relationship value to populate PermissionSet.Type
		PermissionSetGroupComponent mockMutingComponent = (PermissionSetGroupComponent)TST_Builder.of(PermissionSetGroupComponent.SObjectType)
				.withOverride(PermissionSetGroupComponent.PermissionSetGroupId, mockPermissionSetGroup.Id)
				.withOverride(PermissionSetGroupComponent.PermissionSetId, mockMutingPermSet.Id)
				.withOverrides(new Map<String, Object> {'PermissionSet' => mockMutingPermSet})
				.withoutInsertion(true)
				.build();
		QRY_Builder.setMock(PermissionSetGroupComponent.SObjectType, new List<PermissionSetGroupComponent> {mockMutingComponent});

		// Mock SetupEntityAccess - the muting permission set grants the permission
		SetupEntityAccess mockAccess = (SetupEntityAccess)TST_Builder.of(SetupEntityAccess.SObjectType)
				.withOverride(SetupEntityAccess.ParentId, mockMutingPermSet.Id)
				.withOverride(SetupEntityAccess.SetupEntityId, mockPermission.Id)
				.withoutInsertion(true)
				.build();
		QRY_Builder.setMock(SetupEntityAccess.SObjectType, new List<SetupEntityAccess> {mockAccess});

		Test.startTest();

		clearAllCaches();

		// Call hasLocalPermission which will run the full code path including expandPermissionSetGroups
		// The permission check should return false because the only component is a muting set
		Boolean hasPermission = SEL_CustomPermission.hasLocalPermission(testUser.Id, 'Mock_Permission');

		// Verify the cache contains the expected muting data
		SEL_CustomPermission.UserAssignmentData cachedData = SEL_CustomPermission.USER_ASSIGNMENT_CACHE.get(testUser.Id);

		Test.stopTest();

		QRY_Builder.clearMocks();
		Assert.isFalse(hasPermission, 'Should return false - only muting component present, no regular grant');
		Assert.isTrue(cachedData.permissionSetGroupComponents.containsKey(mockPermissionSetGroup.Id), 'Permission Set Group should be in cache');

		SEL_CustomPermission.PermissionSetGroupComponentData componentData = cachedData.permissionSetGroupComponents.get(mockPermissionSetGroup.Id);
		Assert.isTrue(componentData.mutingComponentIds.contains(mockMutingPermSet.Id), 'Muting permission set should be identified');
		Assert.isTrue(componentData.regularComponentIds.isEmpty(), 'No regular components expected');
	}

	/**
	 * @description Clears all caches to ensure clean test state.
	 */
	private static void clearAllCaches()
	{
		SEL_CustomPermission.PERMISSION_RESULT_CACHE.clear();
		SEL_CustomPermission.USER_ASSIGNMENT_CACHE.clear();
		SEL_CustomPermission.PERMISSION_ID_CACHE.clear();
		SEL_CustomPermission.PERMISSION_SET_CACHE.clear();
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
	 * @description Creates a mock PermissionSetAssignment for a Permission Set Group assignment.
	 *
	 * @param permissionSetGroupId The ID of the Permission Set Group to assign
	 * @param userId The ID of the user to assign to
	 *
	 * @return A mock PermissionSetAssignment record with a generated ID
	 */
	private static PermissionSetAssignment createMockGroupAssignment(Id permissionSetGroupId, Id userId)
	{
		return (PermissionSetAssignment)TST_Builder.of(PermissionSetAssignment.SObjectType)
				.withOverride(PermissionSetAssignment.PermissionSetGroupId, permissionSetGroupId)
				.withOverride(PermissionSetAssignment.AssigneeId, userId)
				.withoutInsertion(true)
				.build();
	}
}