// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_PermissionSetAssignment selector.
 *
 * @see SEL_PermissionSetAssignment
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false)
private class SEL_PermissionSetAssignment_TEST
{
	/**
	 * @description Unique Federation Identifier used to locate the test user across test methods.
	 */
	private static final String TEST_FEDERATION_ID = '9a5e78d1-2c3f-4b8a-9d6e-7f1a2b3c4d5e';

	/**
	 * @description Sets up a standard user with a known FederationIdentifier for use in all tests.
	 */
	@TestSetup
	private static void setup()
	{
		User newUser = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER);
		newUser.FederationIdentifier = TEST_FEDERATION_ID;
		insert newUser;

		TST_Factory.createPermissionSetAssignments(new List<User> {newUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);
	}

	/**
	 * @description Tests that isAssigned(name) returns true for the running user with an assigned permission set.
	 */
	@IsTest
	private static void isAssignedForRunningUserReturnsTrue()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		System.runAs(testUser)
		{
			Test.startTest();

			Boolean isAssigned = new SEL_PermissionSetAssignment().isAssigned(SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

			Test.stopTest();

			Assert.isTrue(isAssigned, 'Permission set should be assigned to running user');
		}
	}

	/**
	 * @description Tests that isAssigned(name) returns false for a non-existent permission set.
	 */
	@IsTest
	private static void isAssignedForRunningUserReturnsFalseForNonExistent()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		System.runAs(testUser)
		{
			Test.startTest();

			Boolean isAssigned = new SEL_PermissionSetAssignment().isAssigned('NonExistent_Permission_Set');

			Test.stopTest();

			Assert.isFalse(isAssigned, 'Non-existent permission set should not be assigned');
		}
	}

	/**
	 * @description Tests that isAssigned(name) returns false for blank permission set name.
	 */
	@IsTest
	private static void isAssignedForRunningUserReturnsFalseForBlank()
	{
		Test.startTest();

		Boolean isAssigned = new SEL_PermissionSetAssignment().isAssigned('');

		Test.stopTest();

		Assert.isFalse(isAssigned, 'Blank permission set name should return false');
	}

	/**
	 * @description Tests that isAssigned(name, userId) returns true for a user with an assigned permission set.
	 */
	@IsTest
	private static void isAssignedForSpecificUserReturnsTrue()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		Test.startTest();

		Boolean isAssigned = new SEL_PermissionSetAssignment().isAssigned(SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME, testUser.Id);

		Test.stopTest();

		Assert.isTrue(isAssigned, 'Permission set should be assigned to specified user');
	}

	/**
	 * @description Tests that isAssigned(name, userId) returns false for a user without the permission set.
	 */
	@IsTest
	private static void isAssignedForSpecificUserReturnsFalseForNonAssigned()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		Test.startTest();

		Boolean isAssigned = new SEL_PermissionSetAssignment().isAssigned(SEL_PermissionSet.READ_ONLY_PERMISSION_SET_API_NAME, testUser.Id);

		Test.stopTest();

		Assert.isFalse(isAssigned, 'Unassigned permission set should return false');
	}

	/**
	 * @description Tests that isAssigned(name, userId) returns false for blank user ID.
	 */
	@IsTest
	private static void isAssignedForSpecificUserReturnsFalseForBlankUserId()
	{
		Test.startTest();

		Boolean isAssigned = new SEL_PermissionSetAssignment().isAssigned(SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME, null);

		Test.stopTest();

		Assert.isFalse(isAssigned, 'Null user ID should return false');
	}

	/**
	 * @description Tests that hasAnyAssignment returns true when user has one of the permission sets.
	 */
	@IsTest
	private static void hasAnyAssignmentReturnsTrueWhenAssigned()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		PermissionSet adminPermSet =
		[
				SELECT Id
				FROM PermissionSet
				WHERE Name = :SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				LIMIT 1
		];
		PermissionSet readOnlyPermSet =
		[
				SELECT Id
				FROM PermissionSet
				WHERE Name = :SEL_PermissionSet.READ_ONLY_PERMISSION_SET_API_NAME
				LIMIT 1
		];

		Set<Id> permissionSetIds = new Set<Id> {adminPermSet.Id, readOnlyPermSet.Id};

		Test.startTest();

		Boolean hasAny = new SEL_PermissionSetAssignment().hasAnyAssignment(testUser.Id, permissionSetIds);

		Test.stopTest();

		Assert.isTrue(hasAny, 'User should have at least one of the permission sets');
	}

	/**
	 * @description Tests that hasAnyAssignment returns false when user has none of the permission sets.
	 */
	@IsTest
	private static void hasAnyAssignmentReturnsFalseWhenNotAssigned()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		PermissionSet readOnlyPermSet = new SEL_PermissionSet().findByName(SEL_PermissionSet.READ_ONLY_PERMISSION_SET_API_NAME);

		Set<Id> permissionSetIds = new Set<Id> {readOnlyPermSet.Id};

		Test.startTest();

		Boolean hasAny = new SEL_PermissionSetAssignment().hasAnyAssignment(testUser.Id, permissionSetIds);

		Test.stopTest();

		Assert.isFalse(hasAny, 'User should not have any of the permission sets');
	}

	/**
	 * @description Tests that hasAnyAssignment returns false for null user ID.
	 */
	@IsTest
	private static void hasAnyAssignmentReturnsFalseForNullUserId()
	{
		Test.startTest();

		Boolean hasAny = new SEL_PermissionSetAssignment().hasAnyAssignment(null, new Set<Id> {UserInfo.getUserId()});

		Test.stopTest();

		Assert.isFalse(hasAny, 'Null user ID should return false');
	}

	/**
	 * @description Tests that hasAnyAssignment returns false for empty permission set IDs.
	 */
	@IsTest
	private static void hasAnyAssignmentReturnsFalseForEmptySet()
	{
		Test.startTest();

		Boolean hasAny = new SEL_PermissionSetAssignment().hasAnyAssignment(UserInfo.getUserId(), new Set<Id>());

		Test.stopTest();

		Assert.isFalse(hasAny, 'Empty permission set IDs should return false');
	}
}