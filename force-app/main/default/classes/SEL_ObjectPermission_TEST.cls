// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_ObjectPermission.
 *
 * @see SEL_ObjectPermission
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class SEL_ObjectPermission_TEST
{
	/**
	 * @description Number of test users to create.
	 */
	private static final Integer NUMBER_OF_USERS = 1;

	/**
	 * @description Checks that the check for read access is working as expected.
	 *
	 * @see SEL_ObjectPermission.hasReadAccess
	 */
	@IsTest
	private static void hasReadAccess()
	{
		User newUser = insertNewUser(SEL_PermissionSet.READ_ONLY_PERMISSION_SET_API_NAME);

		Test.startTest();

		Boolean hasAccess = SEL_ObjectPermission.hasReadAccess(newUser.Id, Foobar__c.SObjectType);

		Test.stopTest();

		Assert.isTrue(hasAccess, 'User does not have read access');
	}

	/**
	 * @description Creates a user with an optional additional permission set assignment.
	 *
	 * @param additionalPermissionset If set to a non-blank value, a permissionset will be added
	 *
	 * @return Newly created user
	 */
	private static User insertNewUser(String additionalPermissionset)
	{
		List<User> newUsers;

		System.runAs(new SEL_User().getCurrentUser())
		{
			newUsers = TST_Factory.insertUsers(SEL_Profile.PROFILE_STANDARD_USER, NUMBER_OF_USERS);

			if(String.isNotBlank(additionalPermissionset))
			{
				TST_Factory.createPermissionSetAssignments(newUsers, additionalPermissionset);
			}
		}
		return newUsers.iterator().next();
	}

	/**
	 * @description Checks that the check for read access (multiple users) is working as expected.
	 *
	 * @see SEL_ObjectPermission.hasReadAccess
	 */
	@IsTest
	private static void hasReadAccessBulk()
	{
		User newUser = insertNewUser(SEL_PermissionSet.READ_ONLY_PERMISSION_SET_API_NAME);

		Test.startTest();

		Set<Id> userIdsWithAccess = SEL_ObjectPermission.hasReadAccess(new Set<Id> {newUser.Id}, Foobar__c.SObjectType);

		Test.stopTest();

		Assert.isFalse(userIdsWithAccess.isEmpty(), 'User does not have read access');
	}

	/**
	 * @description Checks that the check for create access is working as expected.
	 *
	 * @see SEL_ObjectPermission.hasCreateAccess
	 */
	@IsTest
	private static void hasCreateAccess()
	{
		User newUser = insertNewUser(SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		Test.startTest();

		Boolean hasAccess = SEL_ObjectPermission.hasCreateAccess(newUser.Id, Foobar__c.SObjectType);

		Test.stopTest();

		Assert.isTrue(hasAccess, 'User does not have create access');
	}

	/**
	 * @description Checks that a user without a permission set does not have read access.
	 *
	 * @see SEL_ObjectPermission.hasReadAccess
	 */
	@IsTest
	private static void hasNoReadAccess()
	{
		User newUser = insertNewUser(UTIL_String.EMPTY);

		Test.startTest();

		Boolean hasAccess = SEL_ObjectPermission.hasReadAccess(newUser.Id, Foobar__c.SObjectType);

		Test.stopTest();

		Assert.isFalse(hasAccess, 'User should not have read access');
	}
}