// SPDX-License-Identifier: BUSL-1.1
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
 * HOW IT WORKS (SCOPED EVALUATION):
 * 1. Find the CustomPermission record by DeveloperName and NamespacePrefix
 * 2. Query user's PermissionSetAssignment records, separating:
 *    - Direct Permission Sets (not part of a group)
 *    - Permission Set Group assignments
 * 3. Expand Permission Set Groups to get component Permission Sets, identifying which are Muting
 * 4. Query SetupEntityAccess to find which Permission Sets grant this permission
 * 5. Evaluate with scoped muting logic:
 *    - Direct grants: If any direct Permission Set grants → TRUE
 *    - Group grants: For each Permission Set Group, if a non-muting component grants AND no muting component revokes → TRUE
 *    - Otherwise → FALSE
 *
 * MUTING PERMISSION SET HANDLING:
 * Muting Permission Sets within a Permission Set Group can revoke specific permissions. A mute in Group A
 * does NOT block a valid grant from Group B. The evaluation is scoped per-group.
 *
 * PERFORMANCE OPTIMIZATIONS:
 * - User assignment data is cached per transaction
 * - CustomPermission IDs are cached by name+namespace
 * - SetupEntityAccess results are cached by permission ID
 * - Final permission check results are cached by user+permission+namespace
 *
 * @see CustomPermission
 * @see SetupEntityAccess
 * @see PermissionSetGroupComponent
 * @see SEL_PermissionSetAssignment
 * @see SEL_CustomPermission_TEST
 * @see FeatureManagement
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date January 2026, June 2026
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
	 * @description Permission Set Type value for Muting Permission Sets.
	 */
	private static final String PERMISSION_SET_TYPE_MUTING = 'Group';

	/**
	 * @description Cache: Final permission check results.
	 * Key format: "userId:permissionName:namespace"
	 * Populated on first check, persists for transaction duration only.
	 */
	@TestVisible
	private static final Map<String, Boolean> PERMISSION_RESULT_CACHE = new Map<String, Boolean>();

	/**
	 * @description Cache: User's assignment data including direct sets and Permission Set Group components.
	 * Key = UserId, Value = UserAssignmentData containing structured assignment information.
	 * Populated on first access per user, persists for transaction duration only.
	 */
	@TestVisible
	private static final Map<Id, UserAssignmentData> USER_ASSIGNMENT_CACHE = new Map<Id, UserAssignmentData>();

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
	 * @description Encapsulates a user's permission set assignment data for scoped evaluation.
	 * Optimized for minimal heap usage - no redundant data storage.
	 */
	@TestVisible
	private class UserAssignmentData
	{
		/**
		 * @description Permission Sets assigned directly to the user (not via Permission Set Group).
		 */
		public Set<Id> directPermissionSetIds = new Set<Id>();

		/**
		 * @description Map of Permission Set Group ID to its component data.
		 */
		public Map<Id, PermissionSetGroupComponentData> permissionSetGroupComponents = new Map<Id, PermissionSetGroupComponentData>();

		/**
		 * @description Returns true if the user has any permission set assignments.
		 *
		 * @return True if user has direct assignments or Permission Set Group assignments
		 */
		public Boolean hasAssignments()
		{
			return !directPermissionSetIds.isEmpty() || !permissionSetGroupComponents.isEmpty();
		}
	}

	/**
	 * @description Component data for a single Permission Set Group.
	 */
	@TestVisible
	private class PermissionSetGroupComponentData
	{
		/**
		 * @description Non-muting (regular) Permission Set IDs in this group.
		 */
		public Set<Id> regularComponentIds = new Set<Id>();

		/**
		 * @description Muting Permission Set IDs in this group.
		 */
		public Set<Id> mutingComponentIds = new Set<Id>();
	}

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
	 *     System.debug('User has the local custom permission');
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
	 *     System.debug('User has the package custom permission');
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
	 * This is the most flexible method, allowing explicit namespace specification.
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
	 * @description Builds a cache key for permission result caching.
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
	 * @description Builds a cache key for permission ID caching.
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
	 * @description Performs the SOQL-based permission check with scoped muting evaluation.
	 *
	 * Algorithm:
	 * 1. Get the CustomPermission ID
	 * 2. Get user's assignment data (direct sets and Permission Set Group components with muting info)
	 * 3. Get all Permission Sets that grant this permission
	 * 4. Evaluate with scoped logic:
	 *    - If any direct Permission Set grants → TRUE
	 *    - For each Permission Set Group: if non-muting grants AND no muting revokes → TRUE
	 *    - Otherwise → FALSE
	 *
	 * @param userId The user to check
	 * @param permissionApiName The DeveloperName of the custom permission
	 * @param namespacePrefix The namespace (null for local)
	 *
	 * @return True if user has the permission
	 */
	@SuppressWarnings('PMD.CognitiveComplexity')
	private static Boolean checkPermissionViaSOQL(Id userId, String permissionApiName, String namespacePrefix)
	{
		Id permissionId = getCustomPermissionId(permissionApiName, namespacePrefix);

		if(permissionId == null)
		{
			return false;
		}

		UserAssignmentData assignmentData = getUserAssignmentData(userId);

		if(!assignmentData.hasAssignments())
		{
			return false;
		}

		Set<Id> grantingPermissionSetIds = getPermissionSetsWithPermission(permissionId);

		if(grantingPermissionSetIds.isEmpty())
		{
			return false;
		}

		// Check direct Permission Set grants
		if(hasDirectGrant(assignmentData.directPermissionSetIds, grantingPermissionSetIds))
		{
			return true;
		}

		// Check Permission Set Group grants with scoped muting evaluation
		return hasPermissionSetGroupGrant(assignmentData.permissionSetGroupComponents, grantingPermissionSetIds);
	}

	/**
	 * @description Checks if any direct Permission Set grants the permission.
	 *
	 * @param directPermissionSetIds The user's directly assigned Permission Set IDs
	 * @param grantingPermissionSetIds The Permission Set IDs that grant the target permission
	 *
	 * @return True if any direct Permission Set grants the permission
	 */
	private static Boolean hasDirectGrant(Set<Id> directPermissionSetIds, Set<Id> grantingPermissionSetIds)
	{
		for(Id directPermissionSetId : directPermissionSetIds)
		{
			if(grantingPermissionSetIds.contains(directPermissionSetId))
			{
				return true;
			}
		}

		return false;
	}

	/**
	 * @description Checks if any Permission Set Group grants the permission (with scoped muting).
	 *
	 * For each Permission Set Group, checks if a non-muting component grants AND no muting component revokes.
	 * Muting is scoped per-Permission Set Group - a mute in Group A doesn't block a grant from Group B.
	 *
	 * @param permissionSetGroupComponents Map of Permission Set Group ID to component data (regular and muting sets)
	 * @param grantingPermissionSetIds The Permission Set IDs that grant the target permission
	 *
	 * @return True if any Permission Set Group grants the permission without being muted
	 */
	@TestVisible
	private static Boolean hasPermissionSetGroupGrant(Map<Id, PermissionSetGroupComponentData> permissionSetGroupComponents, Set<Id> grantingPermissionSetIds)
	{
		for(Id permissionSetGroupId : permissionSetGroupComponents.keySet())
		{
			PermissionSetGroupComponentData componentData = permissionSetGroupComponents.get(permissionSetGroupId);

			Boolean hasGrant = hasIntersection(componentData.regularComponentIds, grantingPermissionSetIds);

			if(!hasGrant)
			{
				continue;
			}

			Boolean hasMute = hasIntersection(componentData.mutingComponentIds, grantingPermissionSetIds);

			if(hasGrant && !hasMute)
			{
				return true;
			}
		}

		return false;
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
	 * @description Gets structured assignment data for a user including direct sets and Permission Set Group components.
	 *
	 * This method queries PermissionSetAssignment to separate direct assignments from Permission Set Group assignments,
	 * then expands Permission Set Groups to get component Permission Sets with muting information.
	 *
	 * Results are cached per user for the transaction duration.
	 *
	 * @param userId The user to get assignment data for
	 *
	 * @return UserAssignmentData containing direct sets and Permission Set Group component maps
	 */
	@TestVisible
	private static UserAssignmentData getUserAssignmentData(Id userId)
	{
		if(USER_ASSIGNMENT_CACHE.containsKey(userId))
		{
			return USER_ASSIGNMENT_CACHE.get(userId);
		}

		UserAssignmentData assignmentData = new UserAssignmentData();
		Set<Id> permissionSetGroupIds = new Set<Id>();

		// Step 1: Query user's permission set assignments
		List<PermissionSetAssignment> assignments = QRY_Builder.selectFrom(PermissionSetAssignment.SObjectType)
				.systemModeInternal()
				.fields(new List<SObjectField>
				{
						PermissionSetAssignment.PermissionSetId,
						PermissionSetAssignment.PermissionSetGroupId
				})
				.condition(PermissionSetAssignment.AssigneeId).equals(userId)
				.toList();

		for(PermissionSetAssignment assignment : assignments)
		{
			// Collect direct permission set assignments (PermissionSetGroupId is null)
			if(assignment.PermissionSetGroupId == null && assignment.PermissionSetId != null)
			{
				assignmentData.directPermissionSetIds.add(assignment.PermissionSetId);
			}

			// Collect permission set group assignments for expansion
			if(assignment.PermissionSetGroupId != null)
			{
				permissionSetGroupIds.add(assignment.PermissionSetGroupId);
			}
		}

		// Step 2: Expand Permission Set Groups to get components with muting info
		if(!permissionSetGroupIds.isEmpty())
		{
			expandPermissionSetGroups(permissionSetGroupIds, assignmentData);
		}

		USER_ASSIGNMENT_CACHE.put(userId, assignmentData);
		return assignmentData;
	}

	/**
	 * @description Expands Permission Set Groups to get component Permission Sets with muting identification.
	 *
	 * @param permissionSetGroupIds The Permission Set Group IDs to expand
	 * @param assignmentData The assignment data to populate with Permission Set Group component information
	 */
	private static void expandPermissionSetGroups(Set<Id> permissionSetGroupIds, UserAssignmentData assignmentData)
	{
		// Query Permission Set Group components with PermissionSet.Type to identify muting permission sets
		List<PermissionSetGroupComponent> components = QRY_Builder.selectFrom(PermissionSetGroupComponent.SObjectType)
				.systemModeInternal()
				.fields(new List<String>
				{
						'PermissionSetId',
						'PermissionSetGroupId',
						'PermissionSet.Type'
				})
				.condition(PermissionSetGroupComponent.PermissionSetGroupId).isIn(new List<Id>(permissionSetGroupIds))
				.toList();

		for(PermissionSetGroupComponent component : components)
		{
			Id permissionSetGroupId = component.PermissionSetGroupId;
			Id permissionSetId = component.PermissionSetId;
			String permissionSetType = component.PermissionSet?.Type;

			// Initialize Permission Set Group component data if not exists
			if(!assignmentData.permissionSetGroupComponents.containsKey(permissionSetGroupId))
			{
				assignmentData.permissionSetGroupComponents.put(permissionSetGroupId, new PermissionSetGroupComponentData());
			}

			PermissionSetGroupComponentData componentData = assignmentData.permissionSetGroupComponents.get(permissionSetGroupId);

			// Categorize as muting or regular
			if(permissionSetType == PERMISSION_SET_TYPE_MUTING)
			{
				componentData.mutingComponentIds.add(permissionSetId);
			}
			else
			{
				componentData.regularComponentIds.add(permissionSetId);
			}
		}
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
	@TestVisible
	private static Id getCustomPermissionId(String apiName, String namespacePrefix)
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

			PERMISSION_SET_CACHE.put(permissionId, UTIL_Set.extractIds(parentIds) ?? new Set<Id>());
		}

		return PERMISSION_SET_CACHE.get(permissionId);
	}
}