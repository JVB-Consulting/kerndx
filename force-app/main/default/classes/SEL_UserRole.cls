// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the UserRole SObject. Provides query methods for retrieving
 * user roles and traversing the role hierarchy.
 *
 * @see SEL_Base
 * @see SEL_UserRole_TEST
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
 * UserRole role = (UserRole)new SEL_UserRole().findById(roleId);
 * List<UserRole> childRoles = new SEL_UserRole().findAllChildRoles(new Set<Id>{parentRoleId});
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SEL_UserRole extends SEL_Base
{
	/**
	 * @description Constructs a UserRole selector.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_UserRole instance = new SEL_UserRole();
	 * ```
	 */
	global SEL_UserRole()
	{
		super(UserRole.SObjectType);
	}

	/**
	 * @description Returns the core fields for UserRole queries.
	 *
	 * @return List of UserRole SObjectField tokens
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
				UserRole.ParentRoleId
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically lack
	 * View All Users / Manage Users equivalent permissions on the role hierarchy, so USER_MODE
	 * reads would return empty and framework hierarchy / visibility machinery would silently
	 * break.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Recursively finds all child roles (direct and indirect descendants) for
	 * the given parent role Ids. Useful for determining the full role hierarchy beneath one
	 * or more starting roles.
	 *
	 * @param parentRoleIds Set of starting parent UserRole Ids
	 *
	 * @return List of all descendant UserRole records (excluding the original parent roles)
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<UserRole> result = instance.findAllChildRoles(recordIds);
	 * ```
	 */
	global List<UserRole> findAllChildRoles(Set<Id> parentRoleIds)
	{
		List<UserRole> allUserRoles = new List<UserRole>();

		List<UserRole> childRoles;
		do
		{
			childRoles = query
					.condition(UserRole.ParentRoleId).isIn(UTIL_Set.idToObject(parentRoleIds))
					.toList();

			allUserRoles.addAll(childRoles);
			parentRoleIds = UTIL_SObject.extractIds(childRoles);
		}
		while(!childRoles.isEmpty());

		return allUserRoles;
	}
}