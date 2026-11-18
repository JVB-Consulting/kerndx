// SPDX-License-Identifier: Apache-2.0
/**
 * @description Selector for Salesforce Group objects. Provides query methods for group lookup
 * and recursive group membership resolution including role-based groups, role hierarchies,
 * and nested group membership.
 *
 * @see SEL_Base
 * @see SEL_Group_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date October 2024, November 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * Group foundGroup = new SEL_Group().findByName('Approvers');
 * Boolean isMember = new SEL_Group().userIsInGroup(userId, 'Approvers');
 * List<User> members = new SEL_Group().findAllUsers(new Set<Id>{groupId});
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SEL_Group extends SEL_Base
{
	/**
	 * @description The child relationship name for GroupMembers on the Group object.
	 */
	private static final String RELATIONSHIP_MEMBERS = 'GroupMembers';

	/**
	 * @description The Type value of a public group. Queues and role groups have other Type values.
	 */
	public static final String TYPE_REGULAR = 'Regular';

	/**
	 * @description The most rows a public group lookup reads. Two rows are enough to see that a value names more
	 * than one group, without reading every group that has it.
	 */
	@TestVisible
	private static final Integer MAXIMUM_GROUPS_PER_LOOKUP = 2;

	/**
	 * @description Reads Group records, such as public groups, queues and role groups. Every query skips the running user's object and field permission checks (system mode).
	 * Record sharing follows the class that calls the selector. Creating the selector runs no query.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_Group instance = new SEL_Group();
	 * ```
	 */
	global SEL_Group()
	{
		super(Group.SObjectType);
	}

	/**
	 * @description Returns the default fields for Group queries.
	 *
	 * @return List of SObjectField tokens to include in queries.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObjectField> result = instance.getFields();
	 * ```
	 */
	global override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				Group.DeveloperName,
				Group.Name,
				Group.RelatedId,
				Group.Type
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically can't
	 * read Group records they're not members of, and the framework often needs to look up public
	 * groups referenced in bypass / feature-flag configuration, so USER_MODE reads would break
	 * group-based access evaluation.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Finds a Group by its Name field.
	 *
	 * @param groupName The Name to search for.
	 *
	 * @return The found Group, or null if not found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Group result = instance.findByName('myName');
	 * ```
	 */
	global Group findByName(String groupName)
	{
		return (Group)query.condition('Name').equals(groupName).getFirst();
	}

	/**
	 * @description Finds the public groups whose API name (DeveloperName, shown as Group Name in Setup) is the given
	 * value. Queues and role groups are left out. It reads at most two rows, so a caller can tell one match from
	 * more than one.
	 *
	 * @param developerName The API name to look for.
	 *
	 * @return The matching public groups: none, one, or two when more than one group has the value.
	 */
	public List<Group> findPublicGroupsByDeveloperName(String developerName)
	{
		return query
				.condition(Group.DeveloperName).equals(developerName)
				.andCondition(Group.Type).equals(TYPE_REGULAR)
				.withLimit(MAXIMUM_GROUPS_PER_LOOKUP)
				.toList();
	}

	/**
	 * @description Finds the public groups whose label (the Name field) is the given value. Labels are not unique, so
	 * several groups can have the same one. Queues and role groups are left out. It reads at most two rows, so a
	 * caller can tell one match from more than one.
	 *
	 * @param groupLabel The label to look for.
	 *
	 * @return The matching public groups: none, one, or two when more than one group has the label.
	 */
	public List<Group> findPublicGroupsByLabel(String groupLabel)
	{
		return query
				.condition(Group.Name).equals(groupLabel)
				.andCondition(Group.Type).equals(TYPE_REGULAR)
				.withLimit(MAXIMUM_GROUPS_PER_LOOKUP)
				.toList();
	}

	/**
	 * @description Finds Group records by their RelatedId field and Type, typically used for
	 * locating system-generated groups associated with UserRoles.
	 *
	 * @param relatedIds Set of RelatedId values to match (typically UserRole IDs).
	 * @param groupType The Type of group to filter by (e.g., 'Role', 'RoleAndSubordinates').
	 *
	 * @return List of Group records matching the specified criteria.
	 */
	@TestVisible
	List<Group> findByRelatedAndType(Set<Id> relatedIds, String groupType)
	{
		return query
				.condition(Group.Type).equals(groupType)
				.andCondition(Group.RelatedId).isIn(new List<Id>(relatedIds))
				.toList();
	}

	/**
	 * @description Recursively finds all users contained within the specified public groups,
	 * including users from embedded roles, role hierarchies, and nested groups.
	 * This method handles complex group structures by:
	 * - Processing Role and RoleAndSubordinates groups
	 * - Traversing nested group memberships
	 * - Collecting users from role hierarchies
	 * - Avoiding infinite loops through iterative processing
	 *
	 * @param parentGroupIds Set of Group IDs to analyze for user membership.
	 *
	 * @return List of User records that are members of the specified groups (directly or indirectly).
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<Id> groupIds = new Set<Id>{ '00G3X000001AbcD' };
	 * List<User> allUsers = new SEL_Group().findAllUsers(groupIds);
	 * ```
	 */
	@SuppressWarnings('PMD.CognitiveComplexity')
	global List<User> findAllUsers(Set<Id> parentGroupIds)
	{
		Set<Id> foundUserIds = new Set<Id>();
		Set<Id> roleIds = new Set<Id>();
		Set<Id> subordinateRoleIds = new Set<Id>();

		do
		{
			List<Group> foundGroups = findByIdWithMembers(parentGroupIds);

			parentGroupIds.clear();

			for(Group foundGroup : foundGroups)
			{
				switch on foundGroup.Type
				{
					when 'Role'
					{
						roleIds.add(foundGroup.RelatedId);
					}
					when 'RoleAndSubordinates', 'RoleAndSubordinatesInternal'
					{
						subordinateRoleIds.add(foundGroup.RelatedId);
					}
					when else
					{
						for(GroupMember foundMember : foundGroup.GroupMembers)
						{
							Set<Id> idSetToUse = foundMember.UserOrGroupId.getSobjectType() == User.SObjectType ? foundUserIds : parentGroupIds;
							idSetToUse.add(foundMember.UserOrGroupId);
						}
					}
				}
			}
		}
		while(!parentGroupIds.isEmpty());

		roleIds.addAll(subordinateRoleIds);
		roleIds.addAll(UTIL_SObject.extractIds(new SEL_UserRole().findAllChildRoles(subordinateRoleIds)));

		SEL_User userSelector = new SEL_User();
		Map<Id, User> userByIdMap = new Map<Id, User>((List<User>)userSelector.findById(foundUserIds));
		userByIdMap.putAll(userSelector.findByRoleId(roleIds));

		return userByIdMap.values();
	}

	/**
	 * @description Checks whether a user is a member of a named group.
	 *
	 * @param userId The User Id to check.
	 * @param groupName The Name of the group to check membership in.
	 *
	 * @return True if the user is a member of the group.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Boolean result = instance.userIsInGroup(recordId, 'myName');
	 * ```
	 */
	global Boolean userIsInGroup(Id userId, String groupName)
	{
		Boolean isInGroup = false;

		if(String.isNotBlank(userId) && String.isNotBlank(groupName))
		{
			Group foundGroup = findByName(groupName);
			isInGroup = foundGroup != null && isUserInGroup(userId, foundGroup.Id);
		}

		return isInGroup;
	}

	/**
	 * @description Checks whether a user is a member of the group with the given Id. A user counts as a member when
	 * they are in the group directly, through a nested group, or through a role the group includes (see findAllUsers).
	 *
	 * @param userId The User Id to check.
	 * @param groupId The Id of the group to check membership in.
	 *
	 * @return True if the user is a member of the group. False when either Id is blank.
	 */
	public Boolean isUserInGroup(Id userId, Id groupId)
	{
		if(String.isBlank(userId) || String.isBlank(groupId))
		{
			return false;
		}

		return !UTIL_SObject.findWhere(findAllUsers(new Set<Id> {groupId}), 'Id', userId).isEmpty();
	}

	/**
	 * @description Retrieves Group records by their IDs and includes their GroupMembers child relationship.
	 *
	 * @param groupIds Set of Group IDs to retrieve with their members.
	 *
	 * @return List of Group records with populated GroupMembers child relationship.
	 */
	private List<Group> findByIdWithMembers(Set<Id> groupIds)
	{
		QRY_Builder.Builder memberRead = QRY_Builder.selectFrom(GroupMember.SObjectType)
				.systemModeInternal()
				.fields(new List<SObjectField> {GroupMember.UserOrGroupId});

		return query
				.subselect(memberRead, RELATIONSHIP_MEMBERS)
				.condition(Group.Id).isIn(new List<Id>(groupIds))
				.toList();
	}
}