// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the PermissionSetGroup SObject. Provides default field configuration
 * and query methods for PermissionSetGroup records. In test context, automatically recalculates
 * groups that are not yet updated.
 *
 * @see SEL_Base
 * @see SEL_PermissionSetGroup_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * PermissionSetGroup foundGroup = new SEL_PermissionSetGroup().findByName('ReadOnly');
 * List<PermissionSetGroup> groups = new SEL_PermissionSetGroup().findByName(new Set<String>{'ReadOnly', 'EditAccess'});
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SEL_PermissionSetGroup extends SEL_Base
{
	/**
	 * @description The group status indicating that the permission set group permissions have been recalculated and are up to date.
	 */
	public static final String STATUS_UPDATED = 'Updated';

	/**
	 * @description Constructs a PermissionSetGroup selector with the PermissionSetGroup SObjectType.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_PermissionSetGroup instance = new SEL_PermissionSetGroup();
	 * ```
	 */
	global SEL_PermissionSetGroup()
	{
		super(PermissionSetGroup.SObjectType);
	}

	/**
	 * @description Returns the core fields for PermissionSetGroup queries.
	 *
	 * @return List of PermissionSetGroup SObjectField tokens
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
				PermissionSetGroup.DeveloperName,
				PermissionSetGroup.HasActivationRequired,
				PermissionSetGroup.NamespacePrefix,
				PermissionSetGroup.Status
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically lack
	 * permissions to read permission-set-group metadata, so USER_MODE reads would return empty
	 * and framework permission-check machinery would silently fail.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Finds a PermissionSetGroup by developer name. Returns the first match or null.
	 *
	 * @param developerName The unique developer name of the PermissionSetGroup to retrieve
	 *
	 * @return The PermissionSetGroup record that matches the specified name, or null if no match is found
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * PermissionSetGroup foundGroup = new SEL_PermissionSetGroup().findByName('ReadOnly');
	 * ```
	 */
	global PermissionSetGroup findByName(String developerName)
	{
		return (PermissionSetGroup)UTIL_List.peekFirst(findByName(new Set<String> {developerName}));
	}

	/**
	 * @description Finds PermissionSetGroups by developer names. In test context, recalculates
	 * groups that are not yet updated.
	 *
	 * @param groupNames A set of unique developer names of the PermissionSetGroup records to retrieve
	 *
	 * @return A list of PermissionSetGroup records that match the specified names
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> names = new Set<String>{'ReadOnly', 'EditAccess'};
	 * List<PermissionSetGroup> groups = new SEL_PermissionSetGroup().findByName(names);
	 * ```
	 */
	global List<PermissionSetGroup> findByName(Set<String> groupNames)
	{
		List<PermissionSetGroup> foundGroups = new List<PermissionSetGroup>();

		for(SObject foundRecord : query.condition(PermissionSetGroup.DeveloperName).isIn(new List<String>(groupNames)).toList())
		{
			PermissionSetGroup foundGroup = (PermissionSetGroup)foundRecord;

			if(Test.isRunningTest() && !STATUS_UPDATED.equalsIgnoreCase(foundGroup.Status))
			{
				Test.calculatePermissionSetGroup(foundGroup.Id);
			}

			foundGroups.add(foundGroup);
		}

		return foundGroups;
	}
}