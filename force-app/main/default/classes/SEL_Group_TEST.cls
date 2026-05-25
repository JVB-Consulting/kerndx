// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for the SEL_Group selector.
 *
 * @see SEL_Group
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date October 2024, May 2026
 */
@IsTest(SeeAllData=false IsParallel=false)
private class SEL_Group_TEST
{
	/**
	 * @description Test group name used throughout the test class.
	 */
	private static final String TEST_GROUP_NAME = 'B9a9ea48cbbdfd2aa14910b09d';

	/**
	 * @description Test role developer name used to identify a test-created role.
	 */
	private static final String TEST_ROLE_NAME = 'A7c3fa12dbe9f04bb28301ea6d';

	/**
	 * @description Sets up required test data including roles, groups, and group members.
	 */
	@TestSetup
	private static void setup()
	{
		UserRole newParentRole = new UserRole();
		newParentRole.DeveloperName = UTIL_Random.randomName();
		newParentRole.Name = UTIL_Random.randomName();
		insert newParentRole;

		UserRole newChildLevel1 = new UserRole();
		newChildLevel1.DeveloperName = UTIL_Random.randomName();
		newChildLevel1.Name = UTIL_Random.randomName();
		newChildLevel1.ParentRoleId = newParentRole.Id;
		insert newChildLevel1;

		SEL_Group selector = new SEL_Group();

		Group relatedGroupChildLevel1 = selector.findByRelatedAndType(new Set<Id> {newChildLevel1.Id}, 'RoleAndSubordinatesInternal').iterator().next();

		UserRole newChildLevel2 = new UserRole();
		newChildLevel2.DeveloperName = TEST_ROLE_NAME;
		newChildLevel2.Name = TEST_ROLE_NAME;
		newChildLevel2.ParentRoleId = newChildLevel1.Id;
		insert newChildLevel2;

		Group relatedGroupChildLevel2 = selector.findByRelatedAndType(new Set<Id> {newChildLevel2.Id}, 'Role').iterator().next();

		Group newGroup1 = new Group();
		newGroup1.DeveloperName = TEST_GROUP_NAME;
		newGroup1.Name = TEST_GROUP_NAME;
		insert newGroup1;

		GroupMember newMember1 = new GroupMember();
		newMember1.GroupId = newGroup1.Id;
		newMember1.UserOrGroupId = relatedGroupChildLevel1.Id;
		insert newMember1;

		GroupMember newMember2 = new GroupMember();
		newMember2.GroupId = newGroup1.Id;
		newMember2.UserOrGroupId = UserInfo.getUserId();
		insert newMember2;

		Group newGroup2 = new Group();
		newGroup2.DeveloperName = UTIL_Random.randomName();
		newGroup2.Name = UTIL_Random.randomName();
		insert newGroup2;

		GroupMember newMember3 = new GroupMember();
		newMember3.GroupId = newGroup1.Id;
		newMember3.UserOrGroupId = newGroup2.Id;
		insert newMember3;

		GroupMember newMember4 = new GroupMember();
		newMember4.GroupId = newGroup2.Id;
		newMember4.UserOrGroupId = relatedGroupChildLevel2.Id;
		insert newMember4;

		User newUser = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER);
		newUser.UserRoleId = newChildLevel2.Id;
		insert newUser;
	}

	/**
	 * @description Verifies that findAllUsers recursively resolves all group members.
	 *
	 * @see SEL_Group.findAllUsers
	 */
	@IsTest
	private static void shouldFindAllUsers()
	{
		SEL_Group selector = new SEL_Group();
		Group foundGroup = selector.findByName(TEST_GROUP_NAME);

		System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
		{
			Test.startTest();

			List<User> foundUsers = selector.findAllUsers(new Set<Id> {foundGroup.Id});

			Test.stopTest();

			Assert.areEqual(2, foundUsers.size(), 'Expected 2 users to be found');
		}
	}

	/**
	 * @description Verifies that userIsInGroup returns true for a user that belongs to the group.
	 *
	 * @see SEL_Group.userIsInGroup
	 */
	@IsTest
	private static void shouldConfirmUserIsInGroup()
	{
		SEL_Group selector = new SEL_Group();

		System.runAs(new User(Id = UserInfo.getUserId()))
		{
			Test.startTest();

			Boolean isInGroup = selector.userIsInGroup(UserInfo.getUserId(), TEST_GROUP_NAME);

			Test.stopTest();

			Assert.isTrue(isInGroup, 'User was not found in Group as expected');
		}
	}

	/**
	 * @description Verifies that findByName returns the expected group.
	 *
	 * @see SEL_Group.findByName
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	private static void shouldFindByName()
	{
		Test.startTest();

		Group foundGroup = new SEL_Group().findByName(TEST_GROUP_NAME);

		Test.stopTest();

		Assert.isNotNull(foundGroup, 'Group should be found by name');
		Assert.areEqual(TEST_GROUP_NAME, foundGroup.Name, 'Group name should match');
	}

	/**
	 * @description Verifies that findByRelatedAndType returns groups for the specified role and type.
	 *
	 * @see SEL_Group.findByRelatedAndType
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	private static void shouldFindByRelatedAndType()
	{
		SObject role = QRY_Builder.selectFrom(UserRole.SObjectType)
				.condition(UserRole.DeveloperName).equals(TEST_ROLE_NAME)
				.getFirst();

		Test.startTest();

		List<Group> foundGroups = new SEL_Group().findByRelatedAndType(new Set<Id> {role.Id}, 'Role');

		Test.stopTest();

		Assert.isFalse(foundGroups.isEmpty(), 'Should find role-based groups');
	}
}