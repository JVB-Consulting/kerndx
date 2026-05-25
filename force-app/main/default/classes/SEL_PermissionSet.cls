// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the PermissionSet SObject. Provides default field configuration
 * and query methods for PermissionSet records, including namespace-aware lookup.
 *
 * @see SEL_Base
 * @see SEL_PermissionSet_TEST
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
 * PermissionSet adminSet = new SEL_PermissionSet().findByName('Administrator');
 * PermissionSet permissionSet = (PermissionSet)new SEL_PermissionSet().findById(permissionSetId);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SEL_PermissionSet extends SEL_Base
{
	/**
	 * @description API name of the Administrator Permission Set.
	 */
	public static final String ADMIN_PERMISSION_SET_API_NAME = 'Administrator';

	/**
	 * @description API name of the Read Only Permission Set.
	 */
	@TestVisible
	private static final String READ_ONLY_PERMISSION_SET_API_NAME = 'ReadOnly';

	/**
	 * @description Indicator if a permission set is actually a group.
	 */
	public static final String GROUP_TYPE = 'Group';

	/**
	 * @description Constructs a PermissionSet selector with the PermissionSet SObjectType.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_PermissionSet instance = new SEL_PermissionSet();
	 * ```
	 */
	global SEL_PermissionSet()
	{
		super(PermissionSet.SObjectType);
	}

	/**
	 * @description Returns the core fields for PermissionSet queries.
	 *
	 * @return List of PermissionSet SObjectField tokens
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
				PermissionSet.IsCustom,
				PermissionSet.Label,
				PermissionSet.LicenseId,
				PermissionSet.Name,
				PermissionSet.Type
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically lack the
	 * Manage Permission Sets / View All Data permissions needed to read PermissionSet metadata,
	 * so USER_MODE reads would return empty and framework permission-check machinery would
	 * silently fail.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Retrieves a PermissionSet record by name, searching both subscriber org (NamespacePrefix = null)
	 * and managed package namespace. Subscriber org version takes precedence.
	 *
	 * @param name The API name of the PermissionSet to retrieve (without namespace prefix)
	 *
	 * @return The matching PermissionSet, or null if not found
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * PermissionSet result = new SEL_PermissionSet().findByName('ReadOnly');
	 * ```
	 */
	global PermissionSet findByName(String name)
	{
		QRY_Condition.AndCondition subscriberOrgCheck = new QRY_Condition.AndCondition();
		subscriberOrgCheck.add(new QRY_Condition.FieldCondition(PermissionSet.Name.getDescribe().name, QRY_Condition.Operator.EQUALS, name));
		subscriberOrgCheck.add(new QRY_Condition.FieldCondition(PermissionSet.NamespacePrefix.getDescribe().name, QRY_Condition.Operator.EQUALS, null));

		QRY_Condition.AndCondition managedPackageCheck = new QRY_Condition.AndCondition();
		managedPackageCheck.add(new QRY_Condition.FieldCondition(PermissionSet.Name.getDescribe().name, QRY_Condition.Operator.EQUALS, name));
		managedPackageCheck.add(new QRY_Condition.FieldCondition
				(
						PermissionSet.NamespacePrefix.getDescribe().name,
						QRY_Condition.Operator.EQUALS,
						UTIL_System.getManagedPackageNamespace()
				));

		QRY_Condition.OrCondition orCondition = new QRY_Condition.OrCondition();
		orCondition.add(subscriberOrgCheck);
		orCondition.add(managedPackageCheck);

		return (PermissionSet)query
				.addCondition(orCondition)
				.orderBy(PermissionSet.NamespacePrefix).descending().nullsFirst()
				.getFirst();
	}
}