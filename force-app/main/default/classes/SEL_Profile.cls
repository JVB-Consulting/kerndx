// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the Profile SObject. Provides default field configuration,
 * query methods, and commonly used profile name constants.
 *
 * @see SEL_Base
 * @see SEL_Profile_TEST
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
 * Profile adminProfile = new SEL_Profile().findByName('System Administrator');
 * Profile standardUser = new SEL_Profile().findByName('Standard User');
 * Profile profile = (Profile)new SEL_Profile().findById(profileId);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SEL_Profile extends SEL_Base
{
	/**
	 * @description Transaction-scoped cache of Profile records keyed by name.
	 * Avoids repeated SOQL queries for the same profile within a transaction.
	 */
	private static final Map<String, Profile> PROFILE_BY_NAME_CACHE = new Map<String, Profile>();

	/**
	 * @description Constant representing the name of the Chatter Free User profile.
	 */
	public static final String PROFILE_CHATTER_FREE_USER = 'Chatter Free User';

	/**
	 * @description Constant representing the name of the Minimum Access - Salesforce profile.
	 * Used to create low-privilege test users that lack FLS on almost every object, for tier-A
	 * in-package tests that validate the framework's "subscriber-without-internal-FLS" contract
	 * (framework elevates bookkeeping internally via systemModeRequired selectors).
	 */
	public static final String PROFILE_MINIMUM_ACCESS = 'Minimum Access - Salesforce';

	/**
	 * @description Constant representing the name of the Standard User profile.
	 */
	public static final String PROFILE_STANDARD_USER = 'Standard User';

	/**
	 * @description Constant representing the name of the System Administrator profile.
	 */
	public static final String PROFILE_SYSTEM_ADMIN = 'System Administrator';

	/**
	 * @description Constructs a Profile selector with the Profile SObjectType.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_Profile instance = new SEL_Profile();
	 * ```
	 */
	global SEL_Profile()
	{
		super(Profile.SObjectType);
	}

	/**
	 * @description Returns the core fields for Profile queries.
	 *
	 * @return List of Profile SObjectField tokens
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
				Profile.Description,
				Profile.Name,
				Profile.UserLicenseId,
				Profile.UserType
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically lack the
	 * Manage Profiles / View All Data permissions needed to read Profile metadata, so USER_MODE
	 * reads would return empty and framework profile-based evaluation (feature-flag strategies,
	 * masking targeting) would silently fail.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Finds a Profile record by name. Results are cached within the transaction
	 * to avoid repeated SOQL queries for the same profile.
	 *
	 * @param profileName The name of the profile to retrieve
	 *
	 * @return The matching Profile record, or null if not found
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Profile adminProfile = new SEL_Profile().findByName('System Administrator');
	 * ```
	 */
	global Profile findByName(String profileName)
	{
		Profile foundProfile;

		if(PROFILE_BY_NAME_CACHE.containsKey(profileName))
		{
			foundProfile = PROFILE_BY_NAME_CACHE.get(profileName);
		}
		else
		{

			foundProfile = (Profile)findFirstByField(Profile.Name, profileName);
			PROFILE_BY_NAME_CACHE.put(profileName, foundProfile);
		}

		return foundProfile;
	}
}