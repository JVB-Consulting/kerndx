// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the PermissionSetAssignment SObject. Provides methods for checking
 * permission set and permission set group assignments for users.
 *
 * @see SEL_Base
 * @see SEL_PermissionSetAssignment_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
public inherited sharing class SEL_PermissionSetAssignment extends SEL_Base
{
	/**
	 * @description The Permission Set (or Group) name relationship path.
	 */
	public static final String FIELD_PERMISSION_SET_NAME = 'PermissionSet.Name';

	/**
	 * @description The API name of the user assigned the permission set.
	 */
	public static final String FIELD_ASSIGNEE_ID = PermissionSetAssignment.AssigneeId.getDescribe().name;

	/**
	 * @description The API name of the assigned permission set.
	 */
	public static final String FIELD_PERMISSION_SET_ID = PermissionSetAssignment.PermissionSetId.getDescribe().name;

	/**
	 * @description Constructs a PermissionSetAssignment selector with the PermissionSetAssignment SObjectType.
	 */
	public SEL_PermissionSetAssignment()
	{
		super(PermissionSetAssignment.SObjectType);
	}

	/**
	 * @description Returns an empty list as this selector uses count queries and specific field selections.
	 *
	 * @return Empty list of SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>();
	}

	/**
	 * @description Returns relationship field paths for PermissionSetAssignment queries.
	 *
	 * @return List of field path strings including the permission set name relationship
	 */
	public override List<String> getFieldPaths()
	{
		return new List<String> {FIELD_PERMISSION_SET_NAME};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users can typically only
	 * see their own PermissionSetAssignment records, but framework permission-check machinery
	 * often needs to evaluate assignments for OTHER users (context user lookups, batch processing),
	 * so USER_MODE reads would return scoped-out results and the check would silently fail.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Checks if the running user has a permission set or permission set group assigned.
	 *
	 * @param permissionSetName The API name of the permission set or group
	 *
	 * @return True if assigned to the running user
	 *
	 * @example
	 * ```apex
	 * Boolean isAssigned = new SEL_PermissionSetAssignment().isAssigned('My_Permission_Set');
	 * ```
	 */
	public Boolean isAssigned(String permissionSetName)
	{
		return isAssigned(permissionSetName, UserInfo.getUserId());
	}

	/**
	 * @description Checks if a specific user has a permission set or permission set group assigned.
	 *
	 * @param permissionSetName The API name of the permission set or group
	 * @param userId The user to check
	 *
	 * @return True if the user has the permission set assigned
	 *
	 * @example
	 * ```apex
	 * Boolean isAssigned = new SEL_PermissionSetAssignment().isAssigned('My_Permission_Set', someUserId);
	 * ```
	 */
	public Boolean isAssigned(String permissionSetName, Id userId)
	{
		Boolean isAssigned = String.isNotBlank(permissionSetName) && String.isNotBlank(userId);

		if(isAssigned)
		{
			isAssigned = query
					.condition(PermissionSetAssignment.AssigneeId).equals(userId)
					.condition(FIELD_PERMISSION_SET_NAME).equals(permissionSetName)
					.count() > 0;
		}

		return isAssigned;
	}

	/**
	 * @description Checks if a user has ANY of the specified permission sets assigned.
	 *
	 * @param userId The user to check
	 * @param permissionSetIds Set of PermissionSet IDs to check against
	 *
	 * @return True if the user has at least one of the permission sets assigned
	 *
	 * @example
	 * ```apex
	 * Boolean hasAny = new SEL_PermissionSetAssignment().hasAnyAssignment(someUserId, permSetIds);
	 * ```
	 */
	public Boolean hasAnyAssignment(Id userId, Set<Id> permissionSetIds)
	{
		if(String.isBlank(userId) || permissionSetIds == null || permissionSetIds.isEmpty())
		{
			return false;
		}

		return query
				.condition(PermissionSetAssignment.AssigneeId).equals(userId)
				.condition(PermissionSetAssignment.PermissionSetId).isIn(new List<Id>(permissionSetIds))
				.count() > 0;
	}
}