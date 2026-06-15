// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Provides methods for querying and evaluating user access permissions on Salesforce objects.
 * Simplifies permission checks by exposing operations such as read or create access for single or
 * multiple users via PermissionSetAssignment with semi-join into ObjectPermissions.
 *
 * @see SEL_PermissionSetAssignment
 * @see SEL_ObjectPermission_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, June 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * Boolean canRead = SEL_ObjectPermission.hasReadAccess(userId, Account.SObjectType);
 * Boolean canCreate = SEL_ObjectPermission.hasCreateAccess(userId, Case.SObjectType);
 * Set<Id> readers = SEL_ObjectPermission.hasReadAccess(userIds, Account.SObjectType);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SEL_ObjectPermission
{
	/**
	 * @description The permissionset for the object permission.
	 */
	private static final String FIELD_PARENT_ID = ObjectPermissions.ParentId.getDescribe().name;

	/**
	 * @description Needs to use a constant as the object field conflicts with SObjectType property on SObjects.
	 */
	private static final String FIELD_SOBJECT_TYPE = 'SobjectType';

	/**
	 * @description API name of the object used when performing queries.
	 */
	private static final String OBJECT_NAME = 'ObjectPermissions';

	/**
	 * @description A Permission that a User might have on a SObjectType.
	 *
	 * @since 1.0
	 */
	global enum ObjectPermissionType
	{
		/**
		 * @description User can create new object (of a given type).
		 */
		CREATE,
		/**
		 * @description User can delete an existing object (of a given type). Delete is a reserved word, hence the abbreviation.
		 */
		DEL,
		/**
		 * @description User can edit an existing object (of a given type).
		 */
		EDIT,
		/**
		 * @description User can edit all existing objects (of a given type).
		 */
		MODIFY_ALL,
		/**
		 * @description User can view/read an existing object (of a given type).
		 */
		READ,
		/**
		 * @description User can view/read all existing objects (of a given type).
		 */
		VIEW_ALL
	}

	/**
	 * @description A map to translate an operation to a field when checking a users permission.
	 */
	private static final Map<ObjectPermissionType, SObjectField> OPERATION_TYPE_TO_FIELD_MAP = new Map<SEL_ObjectPermission.ObjectPermissionType, SObjectField>
	{
			ObjectPermissionType.CREATE => ObjectPermissions.PermissionsCreate,
			ObjectPermissionType.DEL => ObjectPermissions.PermissionsDelete,
			ObjectPermissionType.EDIT => ObjectPermissions.PermissionsEdit,
			ObjectPermissionType.MODIFY_ALL => ObjectPermissions.PermissionsModifyAllRecords,
			ObjectPermissionType.READ => ObjectPermissions.PermissionsRead,
			ObjectPermissionType.VIEW_ALL => ObjectPermissions.PermissionsViewAllRecords
	};

	/**
	 * @description Determines if a specified user has read access to a particular Salesforce object type.
	 *
	 * @param userId The Id of the User to check for read access
	 * @param objectType The SObjectType of the object to check access for
	 *
	 * @return True if the user has read access to the object; otherwise, false
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Boolean result = SEL_ObjectPermission.hasReadAccess(recordId, Account.SObjectType);
	 * ```
	 */
	global static Boolean hasReadAccess(Id userId, SObjectType objectType)
	{
		return hasAccess(ObjectPermissionType.READ, userId, objectType);
	}

	/**
	 * @description Checks if a set of specified users has read access to a given object type.
	 *
	 * @param userIds A Set of User Ids to check for read access
	 * @param objectType The SObjectType of the object to check access for
	 *
	 * @return The Ids of users that have read access to the object type
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<Id> result = SEL_ObjectPermission.hasReadAccess(recordIds, Account.SObjectType);
	 * ```
	 */
	global static Set<Id> hasReadAccess(Set<Id> userIds, SObjectType objectType)
	{
		return hasAccess(ObjectPermissionType.READ, userIds, objectType);
	}

	/**
	 * @description Checks if a specified user has create access to a particular object type.
	 *
	 * @param userId The Id of the User to check for create access
	 * @param objectType The SObjectType of the object to check access for
	 *
	 * @return True if the user has create access; otherwise, false
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Boolean result = SEL_ObjectPermission.hasCreateAccess(recordId, Account.SObjectType);
	 * ```
	 */
	global static Boolean hasCreateAccess(Id userId, SObjectType objectType)
	{
		return hasAccess(ObjectPermissionType.CREATE, userId, objectType);
	}

	/**
	 * @description Checks if a specific user has the required access level for a particular SObjectType.
	 *
	 * @param objectAccessLevel The ObjectPermissionType (e.g., CREATE, READ) to check for
	 * @param userId The Id of the user to check access for
	 * @param objectType The SObjectType of the object for which access is being checked
	 *
	 * @return True if the user has the specified access level; otherwise, false
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Boolean result = SEL_ObjectPermission.hasAccess(new ObjectPermissionType(), recordId, Account.SObjectType);
	 * ```
	 */
	global static Boolean hasAccess(ObjectPermissionType objectAccessLevel, Id userId, SObjectType objectType)
	{
		return hasAccess(objectAccessLevel, new Set<Id> {userId}, objectType).contains(userId);
	}

	/**
	 * @description Verifies if multiple users have a specified access level for a given object type.
	 *
	 * @param objectAccessLevel The ObjectPermissionType (e.g., MODIFY_ALL, VIEW_ALL) to check for
	 * @param userIds A Set of User Ids to check access for
	 * @param objectType The SObjectType of the object for which access is being checked
	 *
	 * @return The Ids of users that have the required access level
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<Id> result = SEL_ObjectPermission.hasAccess(new ObjectPermissionType(), recordIds, Account.SObjectType);
	 * ```
	 */
	global static Set<Id> hasAccess(ObjectPermissionType objectAccessLevel, Set<Id> userIds, SObjectType objectType)
	{
		Set<Id> foundUserIds = new Set<Id>();

		if(!userIds.isEmpty())
		{
			QRY_Builder.Builder subquery = QRY_Builder.selectFrom(UTIL_SObjectDescribe.getSObjectTypeByName(OBJECT_NAME))
					.systemModeInternal()
					.fields(new List<String> {FIELD_PARENT_ID})
					.condition(OPERATION_TYPE_TO_FIELD_MAP.get(objectAccessLevel).getDescribe().name).equals(true)
					.andCondition(FIELD_SOBJECT_TYPE).equals(objectType.getDescribe().name);

			foundUserIds = UTIL_SObject.extractIds
					(
							QRY_Builder.selectFrom(PermissionSetAssignment.SObjectType)
									.systemModeInternal()
									.fields(new List<String> {SEL_PermissionSetAssignment.FIELD_ASSIGNEE_ID})
									.condition(SEL_PermissionSetAssignment.FIELD_ASSIGNEE_ID).isIn(UTIL_Set.toList(userIds))
									.andCondition(SEL_PermissionSetAssignment.FIELD_PERMISSION_SET_ID).isIn(subquery)
									.groupBy(SEL_PermissionSetAssignment.FIELD_ASSIGNEE_ID)
									.toList(),
							SEL_PermissionSetAssignment.FIELD_ASSIGNEE_ID
					);
		}

		return foundUserIds;
	}
}