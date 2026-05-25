// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for FLOW_CheckObjectPermissions
 *
 * @see FLOW_CheckObjectPermissions
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false)
private class FLOW_CheckObjectPermissions_TEST
{
	private static final String ERROR_PERMISSIONS_INCORRECT = 'Permissions Incorrect';

	/**
	 * @description Method to validate Object level access for different objects for Chatter Free User
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	private static void validateAccessForChatterFreeUsers()
	{
		assertPermissionsAreValid(SEL_Profile.PROFILE_CHATTER_FREE_USER);
	}

	/**
	 * @description Generic method which takes List of DTO objects as parameter and validate access for given objects
	 *
	 * @param runAsUserProfileName The profile to use when checking user permissions
	 */
	private static void assertPermissionsAreValid(String runAsUserProfileName)
	{
		List<FLOW_CheckObjectPermissions.DTO_Request> dtoRequests =
				TST_Factory.createObjectPermissionCheckRequests(new List<String> {SEL_Foobar.OBJECT_NAME, SEL_User.OBJECT_NAME});

		System.runAs(TST_Factory.newUser(runAsUserProfileName))
		{
			Test.startTest();

			List<FLOW_CheckObjectPermissions.DTO_Response> dtoObjectPermissions = FLOW_CheckObjectPermissions.checkPermissions(dtoRequests);

			Test.stopTest();

			for(Integer i = 0; i < dtoRequests.size(); i++)
			{
				FLOW_CheckObjectPermissions.DTO_Request dtoRequest = dtoRequests[i];
				FLOW_CheckObjectPermissions.DTO_Response dtoObjectPermission = dtoObjectPermissions[i];

				DescribeSObjectResult describe = UTIL_SObjectDescribe.getDescribe(dtoRequest.objectApiName).getDescribe();

				Assert.areEqual(describe.isAccessible(), dtoObjectPermission.hasReadAccess, ERROR_PERMISSIONS_INCORRECT);
				Assert.areEqual(describe.isCreateable(), dtoObjectPermission.hasCreateAccess, ERROR_PERMISSIONS_INCORRECT);
				Assert.areEqual(describe.isDeletable(), dtoObjectPermission.hasDeleteAccess, ERROR_PERMISSIONS_INCORRECT);
				Assert.areEqual(describe.isUpdateable(), dtoObjectPermission.hasEditAccess, ERROR_PERMISSIONS_INCORRECT);
			}
		}
	}

	/**
	 * @description Method to validate Object level access for different objects for System administrator profile
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	private static void validateAccessForSystemAdministrators()
	{
		assertPermissionsAreValid(SEL_Profile.PROFILE_SYSTEM_ADMIN);
	}

	/**
	 * @description Method to validate Object level access with Incorrect Object API name
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	private static void validateAccessWithIncorrectObjectName()
	{
		Test.startTest();

		FLOW_CheckObjectPermissions.DTO_Response dtoObjectPermission = FLOW_CheckObjectPermissions.checkPermissions
				(
						TST_Factory.createObjectPermissionCheckRequests(new List<String> {UTIL_Random.randomName()})
				).iterator().next();

		Test.stopTest();

		Assert.isFalse(dtoObjectPermission.isValidObject, 'Invalid object should not be valid');
		Assert.isFalse(dtoObjectPermission.hasReadAccess, ERROR_PERMISSIONS_INCORRECT);
		Assert.isFalse(dtoObjectPermission.hasCreateAccess, ERROR_PERMISSIONS_INCORRECT);
		Assert.isFalse(dtoObjectPermission.hasDeleteAccess, ERROR_PERMISSIONS_INCORRECT);
		Assert.isFalse(dtoObjectPermission.hasEditAccess, ERROR_PERMISSIONS_INCORRECT);
	}
}