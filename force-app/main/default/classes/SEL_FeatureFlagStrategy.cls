// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the FeatureFlagStrategy__mdt custom metadata type. Provides default
 * field configuration, strategy type constants, and query capabilities for feature flag strategies.
 *
 * @see SEL_Base
 * @see SEL_FeatureFlagStrategy_TEST
 *
 * @author Jason van Beukering
 *
 * @group Feature Flags
 *
 * @date February 2026, May 2026
 */
public inherited sharing class SEL_FeatureFlagStrategy extends SEL_Base
{
	/**
	 * @description Strategy type that reads a field from a List Custom Setting record.
	 */
	public static final String TYPE_LIST_CUSTOM_SETTING = 'List Custom Setting';

	/**
	 * @description Strategy type that reads a field from a Custom Metadata record.
	 */
	public static final String TYPE_CUSTOM_METADATA = 'Custom Metadata';

	/**
	 * @description Strategy type that checks the running user's Profile.
	 */
	public static final String TYPE_PROFILE = 'Profile';

	/**
	 * @description Strategy type that reads a field from a Hierarchical Custom Setting.
	 */
	public static final String TYPE_HIERARCHICAL_CUSTOM_SETTING = 'Hierarchical Custom Setting';

	/**
	 * @description Strategy type that checks membership in a Public Group.
	 */
	public static final String TYPE_PUBLIC_GROUP = 'Public Group';

	/**
	 * @description Strategy type that checks assignment to a Permission Set Group.
	 */
	public static final String TYPE_PERMISSION_SET_GROUP = 'Permission Set Group';

	/**
	 * @description Strategy type that checks whether the user has a specific Custom Permission.
	 */
	public static final String TYPE_CUSTOM_PERMISSION = 'Custom Permission';

	/**
	 * @description Constructs a FeatureFlagStrategy selector with the FeatureFlagStrategy__mdt SObjectType.
	 */
	public SEL_FeatureFlagStrategy()
	{
		super(FeatureFlagStrategy__mdt.SObjectType);
	}

	/**
	 * @description Returns the core fields for FeatureFlagStrategy__mdt queries.
	 *
	 * @return List of FeatureFlagStrategy__mdt SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				FeatureFlagStrategy__mdt.CustomHandler__c,
				FeatureFlagStrategy__mdt.DeveloperName,
				FeatureFlagStrategy__mdt.ExpectedValue__c,
				FeatureFlagStrategy__mdt.FeatureFlag__c,
				FeatureFlagStrategy__mdt.IsActive__c,
				FeatureFlagStrategy__mdt.Order__c,
				FeatureFlagStrategy__mdt.Target__c,
				FeatureFlagStrategy__mdt.Type__c
		};
	}
}