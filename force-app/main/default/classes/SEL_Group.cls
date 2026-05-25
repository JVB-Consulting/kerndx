// SPDX-License-Identifier: BUSL-1.1
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
 * @date October 2024, May 2026
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
	 * @description Constructs a new SEL_Group selector instance.
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
			List<User> foundUsers = foundGroup == null ? new List<User>() : findAllUsers(new Set<Id> {foundGroup.Id});
			isInGroup = !UTIL_SObject.findWhere(foundUsers, 'Id', userId).isEmpty();
		}

		return isInGroup;
	}

	/**
	 * @description Retrieves Group records by their IDs and includes their GroupMembers child relationship.
	 * Uses manual SOQL because QRY_Builder does not support child relationship subqueries.
	 *
	 * @param groupIds Set of Group IDs to retrieve with their members.
	 *
	 * @return List of Group records with populated GroupMembers child relationship.
	 */
	@SuppressWarnings('PMD.ApexSOQLInjection')
	private List<Group> findByIdWithMembers(Set<Id> groupIds)
	{
		List<String> fieldNames = new List<String>();

		for(SObjectField field : getFields())
		{
			fieldNames.add(field.getDescribe().getName());
		}

		String memberField = GroupMember.UserOrGroupId.getDescribe().name;

		String soql = 'SELECT ' + String.join(fieldNames, ', ') +
				', (SELECT ' + memberField + ' FROM ' + RELATIONSHIP_MEMBERS + ')' +
				' FROM ' + UTIL_SObjectDescribe.getObjectNameFromType(Group.SObjectType) +
				' WHERE Id IN :groupIds';

		return Database.query(soql, AccessLevel.SYSTEM_MODE);
	}
}