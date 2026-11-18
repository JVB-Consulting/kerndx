// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for the SEL_Group selector.
 *
 * @see SEL_Group
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date October 2024, November 2026
 */
@IsTest(seeAllData=false isParallel=false)
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
	 * @description Starts a test group's label, so the label always differs from the group's API name.
	 */
	private static final String GROUP_LABEL_PREFIX = 'Beta testers ';

	/**
	 * @description The Type value of a queue. Queues are stored as groups, but the public group lookups leave them out.
	 */
	private static final String GROUP_TYPE_QUEUE = 'Queue';

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

	/**
	 * @description Verifies that the API name lookup finds a public group by its DeveloperName and not by its label, and the
	 * label lookup finds it by its label and not by its DeveloperName.
	 *
	 * @see SEL_Group.findPublicGroupsByDeveloperName
	 * @see SEL_Group.findPublicGroupsByLabel
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	private static void shouldFindAPublicGroupByApiNameOrByLabel()
	{
		String apiName = UTIL_Random.randomName();
		String label = GROUP_LABEL_PREFIX + apiName;
		Group newGroup = insertGroup(SEL_Group.TYPE_REGULAR, apiName, label);
		SEL_Group selector = new SEL_Group();

		Test.startTest();

		List<Group> groupsByApiName = selector.findPublicGroupsByDeveloperName(apiName);
		List<Group> groupsByLabel = selector.findPublicGroupsByLabel(label);
		List<Group> labelAsApiName = selector.findPublicGroupsByDeveloperName(label);
		List<Group> apiNameAsLabel = selector.findPublicGroupsByLabel(apiName);

		Test.stopTest();

		Assert.areEqual(1, groupsByApiName.size(), 'Expected one group for the API name');
		Assert.areEqual(newGroup.Id, groupsByApiName[0].Id, 'Expected the group with that API name');
		Assert.areEqual(1, groupsByLabel.size(), 'Expected one group for the label');
		Assert.areEqual(newGroup.Id, groupsByLabel[0].Id, 'Expected the group with that label');
		Assert.isTrue(labelAsApiName.isEmpty(), 'Expected the API name lookup to ignore labels');
		Assert.isTrue(apiNameAsLabel.isEmpty(), 'Expected the label lookup to ignore API names');
	}

	/**
	 * @description Verifies that the label lookup reads at most two groups when more groups share the label. Two rows are
	 * enough to tell a caller that the label is not unique.
	 *
	 * @see SEL_Group.findPublicGroupsByLabel
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	private static void shouldReadAtMostTwoGroupsForALabel()
	{
		String label = GROUP_LABEL_PREFIX + UTIL_Random.randomName();
		insertGroup(SEL_Group.TYPE_REGULAR, UTIL_Random.randomName(), label);
		insertGroup(SEL_Group.TYPE_REGULAR, UTIL_Random.randomName(), label);
		insertGroup(SEL_Group.TYPE_REGULAR, UTIL_Random.randomName(), label);

		Test.startTest();

		List<Group> foundGroups = new SEL_Group().findPublicGroupsByLabel(label);

		Test.stopTest();

		Assert.areEqual(SEL_Group.MAXIMUM_GROUPS_PER_LOOKUP, foundGroups.size(), 'Expected the lookup to stop at two groups');
	}

	/**
	 * @description Verifies that neither public group lookup returns a queue, even when the queue's API name and label are
	 * the value looked for.
	 *
	 * @see SEL_Group.findPublicGroupsByDeveloperName
	 * @see SEL_Group.findPublicGroupsByLabel
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	private static void shouldLeaveOutQueues()
	{
		String queueName = UTIL_Random.randomName();
		insertGroup(GROUP_TYPE_QUEUE, queueName, queueName);
		SEL_Group selector = new SEL_Group();

		Test.startTest();

		List<Group> groupsByApiName = selector.findPublicGroupsByDeveloperName(queueName);
		List<Group> groupsByLabel = selector.findPublicGroupsByLabel(queueName);

		Test.stopTest();

		Assert.isTrue(groupsByApiName.isEmpty(), 'Expected the API name lookup to leave out the queue');
		Assert.isTrue(groupsByLabel.isEmpty(), 'Expected the label lookup to leave out the queue');
	}

	/**
	 * @description Verifies that the membership check by group Id finds a direct member, finds a user who belongs only
	 * through a role in a nested group, and returns false for a blank group Id or user Id.
	 *
	 * @see SEL_Group.isUserInGroup
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	private static void shouldCheckMembershipByGroupId()
	{
		SEL_Group selector = new SEL_Group();
		Id groupId = selector.findByName(TEST_GROUP_NAME).Id;
		User roleUser = findUserInTestRole();

		Test.startTest();

		Boolean isDirectMember = selector.isUserInGroup(UserInfo.getUserId(), groupId);
		Boolean isRoleMember = selector.isUserInGroup(roleUser.Id, groupId);
		Boolean isMemberOfBlankGroup = selector.isUserInGroup(UserInfo.getUserId(), null);
		Boolean isBlankUserMember = selector.isUserInGroup(null, groupId);

		Test.stopTest();

		Assert.isTrue(isDirectMember, 'Expected the direct member to be found');
		Assert.isTrue(isRoleMember, 'Expected the user in a role of a nested group to be found');
		Assert.isFalse(isMemberOfBlankGroup, 'Expected false for a blank group Id');
		Assert.isFalse(isBlankUserMember, 'Expected false for a blank user Id');
	}

	/**
	 * @description Verifies that findByName and userIsInGroup still match the group's label (the Name field), not its API
	 * name. Both are part of the released API, so their meaning must not change.
	 *
	 * @see SEL_Group.findByName
	 * @see SEL_Group.userIsInGroup
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	private static void shouldKeepFindByNameAndUserIsInGroupMatchingTheLabel()
	{
		String apiName = UTIL_Random.randomName();
		String label = GROUP_LABEL_PREFIX + apiName;
		Group newGroup = insertGroup(SEL_Group.TYPE_REGULAR, apiName, label);
		TST_Builder.of(GroupMember.SObjectType)
				.withOverride(GroupMember.GroupId, newGroup.Id)
				.withOverride(GroupMember.UserOrGroupId, UserInfo.getUserId())
				.build();
		SEL_Group selector = new SEL_Group();

		Test.startTest();

		Group foundByLabel = selector.findByName(label);
		Group foundByApiName = selector.findByName(apiName);
		Boolean isInGroupByLabel = selector.userIsInGroup(UserInfo.getUserId(), label);
		Boolean isInGroupByApiName = selector.userIsInGroup(UserInfo.getUserId(), apiName);

		Test.stopTest();

		Assert.areEqual(newGroup.Id, foundByLabel?.Id, 'Expected findByName to find the group by its label');
		Assert.isNull(foundByApiName, 'Expected findByName not to match the API name');
		Assert.isTrue(isInGroupByLabel, 'Expected userIsInGroup to match the label');
		Assert.isFalse(isInGroupByApiName, 'Expected userIsInGroup not to match the API name');
	}

	/**
	 * @description Verifies that findAllUsers finds a user who is in a group only through a second group. The outer group's
	 * only member is the inner group, and the inner group's only member is the running user, so the user must be found by
	 * reading the inner group too.
	 *
	 * @see SEL_Group.findAllUsers
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	private static void shouldFindTheUsersOfANestedGroup()
	{
		String outerName = UTIL_Random.randomName();
		String innerName = UTIL_Random.randomName();
		Group outerGroup = insertGroup(SEL_Group.TYPE_REGULAR, outerName, GROUP_LABEL_PREFIX + outerName);
		Group innerGroup = insertGroup(SEL_Group.TYPE_REGULAR, innerName, GROUP_LABEL_PREFIX + innerName);
		TST_Builder.of(GroupMember.SObjectType)
				.withOverride(GroupMember.GroupId, outerGroup.Id)
				.withOverride(GroupMember.UserOrGroupId, innerGroup.Id)
				.build();
		TST_Builder.of(GroupMember.SObjectType)
				.withOverride(GroupMember.GroupId, innerGroup.Id)
				.withOverride(GroupMember.UserOrGroupId, UserInfo.getUserId())
				.build();

		Test.startTest();

		List<User> foundUsers = new SEL_Group().findAllUsers(new Set<Id> {outerGroup.Id});

		Test.stopTest();

		Assert.areEqual(1, foundUsers.size(), 'Expected exactly one user to be found, got ' + foundUsers);
		Assert.areEqual(UserInfo.getUserId(), foundUsers[0].Id, 'Expected the user who is a member of the inner group');
	}

	/**
	 * @description Inserts a group with the given type, API name and label.
	 *
	 * @param groupType The Type of the group, such as Regular for a public group or Queue.
	 * @param apiName The group's API name (DeveloperName).
	 * @param label The group's label (Name).
	 *
	 * @return The inserted group
	 */
	private static Group insertGroup(String groupType, String apiName, String label)
	{
		Map<SObjectField, Object> valueByField = new Map<SObjectField, Object>
		{
				Group.Type => groupType,
				Group.DeveloperName => apiName,
				Group.Name => label
		};
		return (Group)TST_Builder.of(Group.SObjectType).withOverrides(valueByField).build();
	}

	/**
	 * @description Finds the user that the test setup placed in the test role, which reaches the test group only through a
	 * nested group.
	 *
	 * @return The user in the test role
	 */
	private static User findUserInTestRole()
	{
		Id roleId = QRY_Builder.selectFrom(UserRole.SObjectType)
				.condition(UserRole.DeveloperName).equals(TEST_ROLE_NAME)
				.getFirst().Id;
		return new SEL_User().findByRoleId(new Set<Id> {roleId})[0];
	}
}