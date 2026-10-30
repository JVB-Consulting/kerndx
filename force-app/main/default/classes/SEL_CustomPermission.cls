// SPDX-License-Identifier: Apache-2.0
/**
 * @description Selectors for checking Custom Permissions for any user.
 *
 * This class solves two platform limitations:
 * 1. FeatureManagement.checkPermission() only works for the running user
 * 2. FeatureManagement.checkPermission() has namespace isolation (cannot check subscriber permissions from managed package)
 *
 * SUBSCRIBER-FIRST DESIGN:
 * As a framework package, the framework assumes most custom permissions will be created by subscribers.
 * The hasLocalPermission() method checks permissions in the subscriber's namespace (NamespacePrefix = null).
 *
 * HOW IT WORKS:
 * 1. Find the CustomPermission record by DeveloperName and NamespacePrefix.
 * 2. Read the PermissionSetId of every PermissionSetAssignment of the user.
 * 3. Read SetupEntityAccess to find the permission sets that hold this permission.
 * 4. The user has the permission when one of their permission sets is among them. Otherwise the answer is false.
 *
 * PERMISSION SET GROUPS:
 * When a user is assigned a permission set group, the assignment's PermissionSetId is the group's summary permission set. This is
 * a permission set (Type 'Group') that Salesforce builds for each group. It holds the permissions the group really grants: the
 * permissions of its permission sets, minus the ones its muting permission set takes away. So a group assignment is checked in
 * the same way as a permission set assigned on its own. While Salesforce is still recalculating a group, its summary
 * permission set can be out of date for a short time, and the answer this class gives follows it. A mute in one group does not
 * take away a permission that another group, or a permission set assigned on its own, grants.
 *
 * PERFORMANCE OPTIMIZATIONS:
 * - The permission sets assigned to each user are cached per transaction
 * - CustomPermission IDs are cached by name+namespace
 * - SetupEntityAccess results are cached by permission ID
 * - Final permission check results are cached by user+permission+namespace
 *
 * @see CustomPermission
 * @see SetupEntityAccess
 * @see PermissionSetAssignment
 * @see SEL_PermissionSetAssignment
 * @see SEL_CustomPermission_TEST
 * @see FeatureManagement
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date January 2026, October 2026
 */
public inherited sharing class SEL_CustomPermission
{
	/**
	 * @description API name of the framework test custom permission.
	 * Used for testing custom permission checking functionality.
	 */
	@TestVisible
	private static final String FRAMEWORK_TEST_PERMISSION = 'FrameworkTestPermission';

	/**
	 * @description Cache: Final permission check results.
	 * Key format: "userId:permissionName:namespace"
	 * Populated on first check, persists for transaction duration only.
	 */
	@TestVisible
	private static final Map<String, Boolean> PERMISSION_RESULT_CACHE = new Map<String, Boolean>();

	/**
	 * @description Cache: the Ids of the permission sets assigned to each user. For a permission set group assignment this is the
	 * group's summary permission set.
	 * Key = UserId, Value = Set of PermissionSet.Id
	 * Populated on first access per user, persists for transaction duration only.
	 */
	@TestVisible
	private static final Map<Id, Set<Id>> ASSIGNED_PERMISSION_SET_CACHE = new Map<Id, Set<Id>>();

	/**
	 * @description Cache: CustomPermission.Id by DeveloperName and NamespacePrefix.
	 * Key format: "permissionName:namespace" (namespace can be empty string for local)
	 * Populated on first access, persists for transaction duration only.
	 */
	@TestVisible
	private static final Map<String, Id> PERMISSION_ID_CACHE = new Map<String, Id>();

	/**
	 * @description Cache: Set of PermissionSet IDs that grant each CustomPermission.
	 * Key = CustomPermission.Id, Value = Set of PermissionSet.Id
	 * Populated on first access, persists for transaction duration only.
	 */
	@TestVisible
	private static final Map<Id, Set<Id>> PERMISSION_SET_CACHE = new Map<Id, Set<Id>>();

	/**
	 * @description Checks if a user has a LOCAL (subscriber-created) custom permission.
	 *
	 * This is the primary method for checking subscriber permissions from a managed package.
	 * It queries permissions where NamespacePrefix is null (subscriber namespace).
	 *
	 * @param userId The user to check
	 * @param permissionApiName The DeveloperName of the custom permission (no namespace prefix)
	 *
	 * @return True if the user has the local permission, false otherwise
	 *
	 * @example
	 * ```apex
	 * // Check if user has a subscriber-created custom permission
	 * Boolean hasAccess = SEL_CustomPermission.hasLocalPermission(someUserId, 'Edit_Confidential_Records');
	 * if(hasAccess)
	 * {
	 *     LOG_Builder.build().info('User has the local custom permission').emitAt('MyClass.checkAccess');
	 * }
	 * ```
	 */
	public static Boolean hasLocalPermission(Id userId, String permissionApiName)
	{
		return hasPermission(userId, permissionApiName, null);
	}

	/**
	 * @description Checks if a user has a PACKAGE custom permission.
	 *
	 * This method checks permissions in the framework package namespace (kern).
	 * For the running user, it uses the optimized FeatureManagement.checkPermission().
	 *
	 * @param userId The user to check
	 * @param permissionApiName The DeveloperName of the custom permission (no namespace prefix)
	 *
	 * @return True if the user has the package permission, false otherwise
	 *
	 * @example
	 * ```apex
	 * // Check if user has a Kern package custom permission
	 * Boolean hasAccess = SEL_CustomPermission.hasPackagePermission(someUserId, 'Unlock_Framework');
	 * if(hasAccess)
	 * {
	 *     LOG_Builder.build().info('User has the package custom permission').emitAt('MyClass.checkAccess');
	 * }
	 * ```
	 */
	public static Boolean hasPackagePermission(Id userId, String permissionApiName)
	{
		if(String.isBlank(userId) || String.isBlank(permissionApiName))
		{
			return false;
		}

		// Optimization: For running user checking package permissions, use platform API (no SOQL)
		if(userId == UserInfo.getUserId())
		{
			return FeatureManagement.checkPermission(permissionApiName);
		}

		return hasPermission(userId, permissionApiName, UTIL_System.getManagedPackageNamespace());
	}

	/**
	 * @description Checks if a user has a custom permission in the specified namespace.
	 *
	 * This is the most flexible method, because you name the namespace yourself.
	 * Use null or empty string for subscriber (local) permissions.
	 *
	 * @param userId The user to check
	 * @param permissionApiName The DeveloperName of the custom permission
	 * @param namespacePrefix The namespace (null/empty for subscriber, 'kern' for package, etc.)
	 *
	 * @return True if the user has the permission, false otherwise
	 *
	 * @example
	 * ```apex
	 * // Check subscriber permission
	 * Boolean hasLocal = SEL_CustomPermission.hasPermission(userId, 'My_Permission', null);
	 * // Check package permission
	 * Boolean hasPackage = SEL_CustomPermission.hasPermission(userId, 'Framework_Admin', 'kern');
	 * // Check another package's permission
	 * Boolean hasOther = SEL_CustomPermission.hasPermission(userId, 'Some_Permission', 'OtherPkg');
	 * ```
	 */
	public static Boolean hasPermission(Id userId, String permissionApiName, String namespacePrefix)
	{
		if(String.isBlank(userId) || String.isBlank(permissionApiName))
		{
			return false;
		}

		String cacheKey = buildResultCacheKey(userId, permissionApiName, namespacePrefix);

		if(PERMISSION_RESULT_CACHE.containsKey(cacheKey))
		{
			return PERMISSION_RESULT_CACHE.get(cacheKey);
		}

		Boolean result = checkPermissionViaSOQL(userId, permissionApiName, namespacePrefix);
		PERMISSION_RESULT_CACHE.put(cacheKey, result);

		return result;
	}

	/**
	 * @description Joins the user Id, the permission name and the namespace with colons. Both names are made lower case, so the result
	 * cache ignores case. A null namespace counts as an empty one.
	 *
	 * @param userId The user ID
	 * @param permissionName The permission DeveloperName
	 * @param namespace The namespace prefix (can be null)
	 *
	 * @return Cache key in format "userId:permissionName:namespace"
	 */
	private static String buildResultCacheKey(Id userId, String permissionName, String namespace)
	{
		return userId + ':' + permissionName.toLowerCase() + ':' + (namespace ?? '').toLowerCase();
	}

	/**
	 * @description Joins the permission name and the namespace with a colon. Both are made lower case, so the cache of permission Ids
	 * ignores case. A null namespace counts as an empty one.
	 *
	 * @param permissionName The permission DeveloperName
	 * @param namespace The namespace prefix (can be null)
	 *
	 * @return Cache key in format "permissionName:namespace"
	 */
	private static String buildPermissionIdCacheKey(String permissionName, String namespace)
	{
		return permissionName.toLowerCase() + ':' + (namespace ?? '').toLowerCase();
	}

	/**
	 * @description Reads the database to check whether the user has the permission.
	 *
	 * Steps:
	 * 1. Get the CustomPermission Id. When there is no such permission, the answer is false.
	 * 2. Get the permission sets assigned to the user. A permission set group counts through its summary permission set.
	 * 3. Get the permission sets that hold the permission.
	 * 4. The answer is true when one permission set is in both lists.
	 *
	 * @param userId The user to check
	 * @param permissionApiName The DeveloperName of the custom permission
	 * @param namespacePrefix The namespace (null for local)
	 *
	 * @return True if user has the permission
	 */
	private static Boolean checkPermissionViaSOQL(Id userId, String permissionApiName, String namespacePrefix)
	{
		Id permissionId = getCustomPermissionId(permissionApiName, namespacePrefix);

		if(permissionId == null)
		{
			return false;
		}

		Set<Id> assignedPermissionSetIds = getAssignedPermissionSetIds(userId);

		if(assignedPermissionSetIds.isEmpty())
		{
			return false;
		}

		return hasIntersection(assignedPermissionSetIds, getPermissionSetsWithPermission(permissionId));
	}

	/**
	 * @description Checks if two sets have any common elements.
	 *
	 * @param setA First set of IDs
	 * @param setB Second set of IDs
	 *
	 * @return True if there is at least one common element
	 */
	private static Boolean hasIntersection(Set<Id> setA, Set<Id> setB)
	{
		for(Id idFromA : setA)
		{
			if(setB.contains(idFromA))
			{
				return true;
			}
		}

		return false;
	}

	/**
	 * @description Gets the Ids of the permission sets assigned to a user, read from PermissionSetAssignment.PermissionSetId.
	 *
	 * A permission set assigned on its own gives its own Id. A permission set group gives the Id of the group's summary permission
	 * set, which holds what the group really grants, with mutes already applied.
	 *
	 * Results are cached per user for the transaction duration.
	 *
	 * @param userId The user to read the assignments of
	 *
	 * @return The assigned permission set Ids. The set is empty when the user has no assignments.
	 */
	private static Set<Id> getAssignedPermissionSetIds(Id userId)
	{
		if(!ASSIGNED_PERMISSION_SET_CACHE.containsKey(userId))
		{
			Set<Object> permissionSetIds = QRY_Builder.selectFrom(PermissionSetAssignment.SObjectType)
					.systemModeInternal()
					.fields(new List<SObjectField> {PermissionSetAssignment.PermissionSetId})
					.condition(PermissionSetAssignment.AssigneeId).equals(userId)
					.asValueSet(PermissionSetAssignment.PermissionSetId);

			ASSIGNED_PERMISSION_SET_CACHE.put(userId, UTIL_Set.extractIds(permissionSetIds));
		}

		return ASSIGNED_PERMISSION_SET_CACHE.get(userId);
	}

	/**
	 * @description Retrieves the CustomPermission record ID for the given API name and namespace.
	 *
	 * Results are cached for the transaction duration.
	 *
	 * @param apiName The DeveloperName of the custom permission
	 * @param namespacePrefix The namespace (null for subscriber/local permissions)
	 *
	 * @return The CustomPermission.Id, or null if not found
	 */
	public static Id getCustomPermissionId(String apiName, String namespacePrefix)
	{
		String cacheKey = buildPermissionIdCacheKey(apiName, namespacePrefix);

		if(!PERMISSION_ID_CACHE.containsKey(cacheKey))
		{
			CustomPermission permission;

			if(String.isBlank(namespacePrefix))
			{
				// Local/subscriber permission - NamespacePrefix is null
				permission = (CustomPermission)QRY_Builder.selectFrom(CustomPermission.SObjectType)
						.systemModeInternal()
						.condition(CustomPermission.DeveloperName).equals(apiName)
						.andCondition(CustomPermission.NamespacePrefix).isNull()
						.getFirst();
			}
			else
			{
				// Package permission - specific namespace
				permission = (CustomPermission)QRY_Builder.selectFrom(CustomPermission.SObjectType)
						.systemModeInternal()
						.condition(CustomPermission.DeveloperName).equals(apiName)
						.andCondition(CustomPermission.NamespacePrefix).equals(namespacePrefix)
						.getFirst();
			}

			PERMISSION_ID_CACHE.put(cacheKey, permission?.Id);
		}

		return PERMISSION_ID_CACHE.get(cacheKey);
	}

	/**
	 * @description Retrieves all PermissionSet IDs that grant the specified custom permission.
	 *
	 * Uses SetupEntityAccess junction object to find which permission sets
	 * contain this custom permission. Results are cached.
	 *
	 * @param permissionId The CustomPermission.Id to look up
	 *
	 * @return Set of PermissionSet IDs that grant this permission
	 */
	@TestVisible
	private static Set<Id> getPermissionSetsWithPermission(Id permissionId)
	{
		if(!PERMISSION_SET_CACHE.containsKey(permissionId))
		{
			Set<Object> parentIds = QRY_Builder.selectFrom(SetupEntityAccess.SObjectType)
					.systemModeInternal()
					.fields(new List<SObjectField> {SetupEntityAccess.ParentId})
					.condition(SetupEntityAccess.SetupEntityId).equals(permissionId)
					.asValueSet(SetupEntityAccess.ParentId);

			PERMISSION_SET_CACHE.put(permissionId, UTIL_Set.extractIds(parentIds));
		}

		return PERMISSION_SET_CACHE.get(permissionId);
	}
}