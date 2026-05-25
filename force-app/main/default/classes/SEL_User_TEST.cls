// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_User.
 *
 * @see SEL_User
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity')
@IsTest(SeeAllData=false IsParallel=false)
private class SEL_User_TEST
{
	/**
	 * @description The number of test users to create for multi-user query assertions.
	 */
	private static final Integer NUMBER_OF_USERS_TO_CREATE = 3;

	/**
	 * @description Will create required unit test data
	 */
	@TestSetup
	private static void setup()
	{
		List<User> newUsers = TST_Factory.insertUsers(SEL_Profile.PROFILE_STANDARD_USER, NUMBER_OF_USERS_TO_CREATE);
		TST_Factory.createPermissionSetAssignments(newUsers, SEL_PermissionSet.READ_ONLY_PERMISSION_SET_API_NAME);
	}

	/**
	 * @description Test the method to check if the current user is system administrator profile
	 *
	 * @see SEL_User.isCurrentUserSystemAdmin
	 */
	@IsTest
	private static void isCurrentUserSystemAdmin()
	{
		System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_SYSTEM_ADMIN))
		{
			Test.startTest();

			Boolean isSysAdmin = new SEL_User().isCurrentUserSystemAdmin();

			Assert.isTrue(isSysAdmin, 'User should be system admin');

			Test.stopTest();
		}
	}

	/**
	 * @description Will test that the method works as expected
	 *
	 * @see SEL_User.findRandomActiveByProfileName
	 */
	@IsTest
	private static void findRandomActiveByProfileName()
	{
		TST_Factory.insertUsers(SEL_Profile.PROFILE_CHATTER_FREE_USER, NUMBER_OF_USERS_TO_CREATE);

		Test.startTest();

		Id referenceUserId = new SEL_User().findRandomActiveByProfileName(SEL_Profile.PROFILE_CHATTER_FREE_USER).Id;
		Boolean randomBehaviorFound = false;

		for(Integer i = 1; i < 10; i++)
		{
			Id currentUserId = new SEL_User().findRandomActiveByProfileName(SEL_Profile.PROFILE_CHATTER_FREE_USER).Id;

			if(referenceUserId != currentUserId)
			{
				randomBehaviorFound = true;
				break;
			}
		}

		Test.stopTest();

		Assert.isTrue(randomBehaviorFound, 'Random User not retrieved');
	}

	/**
	 * @description tests that user is not found if fake or random federation id is used
	 *
	 * @see SEL_User.findByFederationId
	 */
	@IsTest
	private static void findUserByFederationIdNegative()
	{
		Assert.isNull(new SEL_User().findByFederationId(UTIL_Random.randomEmail()), 'Expected nothing to be found.');
	}

	/**
	 * @description Tests that the method runs successfully as well as that query is only run once even if method called multiple times
	 *
	 * @see SEL_User.getCurrentUser
	 */
	@IsTest
	private static void getCurrentUser()
	{
		Test.startTest();

		new SEL_User().getCurrentUser();
		new SEL_User().getCurrentUser();

		Assert.areEqual(1, UTIL_Limits.soqlQueries().used(), 'Query should only be run once');

		Test.stopTest();
	}

	/**
	 * @description Tests that the method retrieves expected records
	 *
	 * @see SEL_User.findActiveByProfileAndPermissionSetName
	 */
	@IsTest
	private static void findActiveByProfileAndPermissionSetName()
	{
		Test.startTest();

		List<User> usersWithPermissionSet =
				new SEL_User().findActiveByProfileAndPermissionSetName(SEL_Profile.PROFILE_STANDARD_USER, SEL_PermissionSet.READ_ONLY_PERMISSION_SET_API_NAME);

		Test.stopTest();

		Assert.areEqual(NUMBER_OF_USERS_TO_CREATE, usersWithPermissionSet.size(), 'Incorrect Number of Users returned');
	}

	/**
	 * @description Tests that the method retrieves expected records
	 *
	 * @see SEL_User.findRandomActiveByProfileAndPermissionSetName
	 */
	@IsTest
	private static void findRandomActiveByProfileAndPermissionSetName()
	{
		Test.startTest();

		User usesWithPermissionSet = new SEL_User().findRandomActiveByProfileAndPermissionSetName
				(SEL_Profile.PROFILE_STANDARD_USER, SEL_PermissionSet.READ_ONLY_PERMISSION_SET_API_NAME);

		Test.stopTest();

		Assert.isNotNull(usesWithPermissionSet, 'User not found');
		Assert.areEqual(SEL_Profile.PROFILE_STANDARD_USER, usesWithPermissionSet.Profile.Name, 'User has incorrect profile');
	}

	/**
	 * @description Tests that an alias is generated correctly
	 *
	 * @see SEL_User.generateAlias
	 */
	@IsTest
	private static void generateAlias()
	{
		Test.startTest();

		String alias1 = new SEL_User().generateAlias('  Jason    van  Thor Bob');
		String alias2 = new SEL_User().generateAlias('THISISASINGLEWORD');

		Test.stopTest();

		Assert.areEqual('JVanThoB', alias1, 'Incorrect Alias Generated');
		Assert.areEqual('Thisisas', alias2, 'Incorrect Alias Generated');
	}

	/**
	 * @description Will test that community user name generation is unique
	 *
	 * @see SEL_User.generateUniqueCommunityNickname
	 */
	@IsTest
	private static void generateUniqueCommunityNickname1()
	{
		final Integer maximumLength = User.CommunityNickname.getDescribe().length;
		final String name = 'Billy boB thornton JNR';

		Test.startTest();

		String nickName1 = new SEL_User().generateUniqueCommunityNickname(name, null);
		String nickName2 = new SEL_User().generateUniqueCommunityNickname(name, new Set<String> {nickName1, nickName1.toUpperCase() + '1'});
		String nickName3 = new SEL_User().generateUniqueCommunityNickname(UTIL_Random.randomAlphabetic(maximumLength + 1), null);

		Test.stopTest();

		Assert.areEqual('BillyBobThorntonJnr', nickName1, 'Incorrect Nickname Generated');
		Assert.areEqual('BillyBobThorntonJnr2', nickName2, 'Incorrect Nickname Generated');
		Assert.areEqual(maximumLength, nickName3.length(), 'Nickname too long');
	}

	/**
	 * @description Will test that community user name generation is unique
	 *
	 * @see SEL_User.generateUniqueCommunityNickname
	 */
	@IsTest
	private static void generateUniqueCommunityNickname2()
	{
		User foundUser = new SEL_User().findRandomActiveByProfileAndPermissionSetName(SEL_Profile.PROFILE_STANDARD_USER, SEL_PermissionSet.READ_ONLY_PERMISSION_SET_API_NAME);

		Test.startTest();

		String nickname = new SEL_User().generateUniqueCommunityNickname(foundUser.Name);

		Assert.areEqual(1, UTIL_Limits.soqlQueries().used(), 'Query not run for existing Nick Names');

		Test.stopTest();

		Assert.areNotEqual(foundUser.CommunityNickname, nickname, 'Nick Name not generated correctly');
	}

	/**
	 * @description Tests that findByUsername(String) returns a user when a valid username is provided.
	 *
	 * @see SEL_User.findByUsername(String)
	 */
	@IsTest
	private static void findByUsernameSingleReturnsUser()
	{
		User testUser = new SEL_User().findRandomActiveByProfileAndPermissionSetName(SEL_Profile.PROFILE_STANDARD_USER, SEL_PermissionSet.READ_ONLY_PERMISSION_SET_API_NAME);

		Test.startTest();

		User foundUser = new SEL_User().findByUsername(testUser.Username);

		Test.stopTest();

		Assert.isNotNull(foundUser, 'User should be found by username');
		Assert.areEqual(testUser.Id, foundUser.Id, 'Should return the same user');
	}

	/**
	 * @description Tests that findByUsername(String) returns null for blank username.
	 *
	 * @see SEL_User.findByUsername(String)
	 */
	@IsTest
	private static void findByUsernameSingleReturnsNullForBlank()
	{
		Test.startTest();

		User foundUser = new SEL_User().findByUsername('');

		Test.stopTest();

		Assert.isNull(foundUser, 'Should return null for blank username');
	}

	/**
	 * @description Tests that findByUsername(String) returns null for non-existent username.
	 *
	 * @see SEL_User.findByUsername(String)
	 */
	@IsTest
	private static void findByUsernameSingleReturnsNullForNonExistent()
	{
		Test.startTest();

		User foundUser = new SEL_User().findByUsername('nonexistent.user@test.invalid.com');

		Test.stopTest();

		Assert.isNull(foundUser, 'Should return null for non-existent username');
	}

	/**
	 * @description Tests that findProfileIdByUserId returns the correct profile ID.
	 *
	 * @see SEL_User.findProfileIdByUserId
	 */
	@IsTest
	private static void findProfileIdByUserIdReturnsProfileId()
	{
		User testUser = new SEL_User().findRandomActiveByProfileAndPermissionSetName(SEL_Profile.PROFILE_STANDARD_USER, SEL_PermissionSet.READ_ONLY_PERMISSION_SET_API_NAME);

		Test.startTest();

		Id profileId = new SEL_User().findProfileIdByUserId(testUser.Id);

		Test.stopTest();

		Assert.isNotNull(profileId, 'Profile ID should be returned');
		Assert.areEqual(testUser.ProfileId, profileId, 'Should return the correct profile ID');
	}

	/**
	 * @description Tests that findProfileIdByUserId returns null for blank userId.
	 *
	 * @see SEL_User.findProfileIdByUserId
	 */
	@IsTest
	private static void findProfileIdByUserIdReturnsNullForBlank()
	{
		Test.startTest();

		Id profileId = new SEL_User().findProfileIdByUserId(null);

		Test.stopTest();

		Assert.isNull(profileId, 'Should return null for null userId');
	}

	/**
	 * @description Tests that findByCompanyName returns user when found.
	 *
	 * @see SEL_User.findByCompanyName
	 */
	@IsTest
	private static void findByCompanyNameReturnsUserWhenFound()
	{
		String companyName = 'test-company-' + System.currentTimeMillis();
		User testUser = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER, companyName);
		insert testUser;

		Test.startTest();
		User foundUser = new SEL_User().findByCompanyName(companyName);
		Test.stopTest();

		Assert.isNotNull(foundUser, 'Should find the user');
		Assert.areEqual(testUser.Id, foundUser.Id, 'Should return the correct user');
	}

	/**
	 * @description Tests that findByCompanyName returns null when not found.
	 *
	 * @see SEL_User.findByCompanyName
	 */
	@IsTest
	private static void findByCompanyNameReturnsNullWhenNotFound()
	{
		String nonExistentCompany = 'non-existent-' + System.currentTimeMillis();

		Test.startTest();
		User foundUser = new SEL_User().findByCompanyName(nonExistentCompany);
		Test.stopTest();

		Assert.isNull(foundUser, 'Should return null when user not found');
	}

	/**
	 * @description Tests that findByRoleId returns users matching the given role IDs.
	 *
	 * @see SEL_User.findByRoleId
	 */
	@IsTest
	private static void findByRoleIdReturnsUsers()
	{
		User currentUser = new SEL_User().getCurrentUser();

		Test.startTest();
		List<User> users = new SEL_User().findByRoleId(new Set<Id> {currentUser.UserRoleId});
		Test.stopTest();

		Assert.isFalse(users.isEmpty(), 'Should return users for the role');
	}

	/**
	 * @description Tests that findByProfileName returns users matching the given profile names.
	 *
	 * @see SEL_User.findByProfileName
	 */
	@IsTest
	private static void findByProfileNameReturnsUsers()
	{
		Test.startTest();
		List<User> users = new SEL_User().findByProfileName(new Set<String> {SEL_Profile.PROFILE_STANDARD_USER});
		Test.stopTest();

		Assert.isFalse(users.isEmpty(), 'Should return users for the profile');
	}

	/**
	 * @description Tests that findActiveUsers returns up to the specified number of active users.
	 *
	 * @see SEL_User.findActiveUsers
	 */
	@IsTest
	private static void findActiveUsersReturnsUsers()
	{
		Test.startTest();
		List<User> users = new SEL_User().findActiveUsers(3);
		Test.stopTest();

		Assert.isFalse(users.isEmpty(), 'Should return active users');
		Assert.isTrue(users.size() <= 3, 'Should not exceed the limit');
	}

	/**
	 * @description Tests that findActiveByProfileName returns active users for the given profile.
	 *
	 * @see SEL_User.findActiveByProfileName
	 */
	@IsTest
	private static void findActiveByProfileNameReturnsUsers()
	{
		Test.startTest();
		List<User> users = new SEL_User().findActiveByProfileName(SEL_Profile.PROFILE_STANDARD_USER);
		Test.stopTest();

		Assert.isFalse(users.isEmpty(), 'Should return active users for the profile');
	}

	/**
	 * @description Tests that findByProfileAndCompany returns users matching profile and company.
	 *
	 * @see SEL_User.findByProfileAndCompany
	 */
	@IsTest
	private static void findByProfileAndCompanyReturnsUsers()
	{
		String companyName = 'test-company-' + System.currentTimeMillis();
		User testUser = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER, companyName);
		insert testUser;

		Test.startTest();
		List<User> users = new SEL_User().findByProfileAndCompany(SEL_Profile.PROFILE_STANDARD_USER, companyName);
		Test.stopTest();

		Assert.isFalse(users.isEmpty(), 'Should return users matching profile and company');
	}

	/**
	 * @description Tests that findByUsername(Set) returns users matching the given usernames.
	 *
	 * @see SEL_User.findByUsername
	 */
	@IsTest
	private static void findByUsernameSetReturnsUsers()
	{
		User testUser = new SEL_User().findRandomActiveByProfileAndPermissionSetName(SEL_Profile.PROFILE_STANDARD_USER, SEL_PermissionSet.READ_ONLY_PERMISSION_SET_API_NAME);

		Test.startTest();
		List<User> users = new SEL_User().findByUsername(new Set<String> {testUser.Username});
		Test.stopTest();

		Assert.areEqual(1, users.size(), 'Should return exactly one user');
		Assert.areEqual(testUser.Id, users[0].Id, 'Should return the correct user');
	}
}