// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the LoginFrequency__c SObject. Provides query methods for
 * login frequency records used in user activity tracking.
 *
 * @see SEL_Base
 * @see SEL_LoginFrequency_TEST
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
public inherited sharing class SEL_LoginFrequency extends SEL_Base
{
	/**
	 * @description The field API name for CompositeKey__c.
	 */
	public static final String FIELD_USERID_WITH_LOGIN_YEAR_AND_MONTH = LoginFrequency__c.CompositeKey__c.getDescribe().name;

	/**
	 * @description Constructs a LoginFrequency selector.
	 */
	public SEL_LoginFrequency()
	{
		super(LoginFrequency__c.SObjectType);
	}

	/**
	 * @description Returns the core fields for LoginFrequency__c queries.
	 *
	 * @return List of LoginFrequency__c SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				LoginFrequency__c.TotalLoginCount__c,
				LoginFrequency__c.UniqueLoginCount__c,
				LoginFrequency__c.User__c,
				LoginFrequency__c.CompositeKey__c
		};
	}

	/**
	 * @description Framework-internal schema selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically have no
	 * CRUD on the framework-owned LoginFrequency__c rollup records, so USER_MODE reads would
	 * return empty and login-frequency aggregation would silently stop working.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Returns login frequency records matching the given concatenated user ID
	 * and login month values.
	 *
	 * @param concatenatedUserIdAndLoginMonth Set of concatenated user ID and login year/month strings
	 *
	 * @return List of matching LoginFrequency__c records
	 */
	public List<LoginFrequency__c> findByUserIdAndLoginMonth(Set<String> concatenatedUserIdAndLoginMonth)
	{
		return concatenatedUserIdAndLoginMonth?.isEmpty() == false
				? query.condition(LoginFrequency__c.CompositeKey__c).isIn(new List<String>(concatenatedUserIdAndLoginMonth)).toList()
				: new List<LoginFrequency__c>();
	}

	/**
	 * @description Returns all login frequency records. Intended for test context only.
	 *
	 * @return List of all LoginFrequency__c records
	 */
	@TestVisible
	private List<LoginFrequency__c> getAll()
	{
		return query.toList();
	}
}