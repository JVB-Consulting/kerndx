// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the OrgWideEmailAddress SObject. Provides query methods for
 * retrieving organization-wide email addresses configured in Salesforce.
 *
 * @see SEL_Base
 * @see SEL_OrgWideEmailAddress_TEST
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
 * List<OrgWideEmailAddress> addresses = new SEL_OrgWideEmailAddress().findByName(new Set<String>{'noreply@company.com'});
 * OrgWideEmailAddress randomAddress = (OrgWideEmailAddress)new SEL_OrgWideEmailAddress().getRandomItem();
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SEL_OrgWideEmailAddress extends SEL_Base
{
	/**
	 * @description Constructs an OrgWideEmailAddress selector.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_OrgWideEmailAddress instance = new SEL_OrgWideEmailAddress();
	 * ```
	 */
	global SEL_OrgWideEmailAddress()
	{
		super(OrgWideEmailAddress.SObjectType);
	}

	/**
	 * @description Returns the core fields for OrgWideEmailAddress queries.
	 *
	 * @return List of OrgWideEmailAddress SObjectField tokens
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
				OrgWideEmailAddress.Address,
				OrgWideEmailAddress.IsAllowAllProfiles,
				OrgWideEmailAddress.DisplayName,
				OrgWideEmailAddress.IsVerified,
				OrgWideEmailAddress.Purpose
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. OWE addresses are a Setup entity
	 * that running users typically can't read, so USER_MODE reads would return empty and email
	 * dispatch would silently fail to find a valid from-address.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Retrieves OrgWideEmailAddress records matching the provided email addresses.
	 *
	 * @param addresses A set of email addresses to search for
	 *
	 * @return List of matching OrgWideEmailAddress records
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<OrgWideEmailAddress> addresses = new SEL_OrgWideEmailAddress()
	 *     .findByName(new Set<String>{'noreply@company.com'});
	 * ```
	 */
	global List<OrgWideEmailAddress> findByName(Set<String> addresses)
	{
		return findByField(OrgWideEmailAddress.Address, UTIL_Set.stringToObject(addresses));
	}

	/**
	 * @description Retrieves a random OrgWideEmailAddress that is available to all profiles.
	 *
	 * @return A random OrgWideEmailAddress available to all profiles, or null if none found
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * OrgWideEmailAddress randomEmail = new SEL_OrgWideEmailAddress().getRandomItem();
	 * ```
	 */
	global override SObject getRandomItem()
	{
		return query
				.condition(OrgWideEmailAddress.IsAllowAllProfiles).equals(true)
				.getRandomItem();
	}
}