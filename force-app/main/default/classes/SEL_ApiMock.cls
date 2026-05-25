// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the ApiMock__mdt custom metadata type. Provides query methods
 * for retrieving mock response configurations by API setting.
 *
 * @see SEL_Base
 * @see SEL_ApiMock_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
public inherited sharing class SEL_ApiMock extends SEL_Base
{
	/**
	 * @description Relationship path for ApiSetting__r.DeveloperName (namespace-safe).
	 */
	private static final String PATH_API_SETTING_DEVELOPER_NAME = ApiMock__mdt.ApiSetting__c.getDescribe().getRelationshipName() + '.DeveloperName';

	/**
	 * @description Constructs an ApiMock selector.
	 */
	public SEL_ApiMock()
	{
		super(ApiMock__mdt.SObjectType);
	}

	/**
	 * @description Returns the core fields for ApiMock__mdt queries.
	 *
	 * @return List of ApiMock__mdt SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				ApiMock__mdt.ApiSetting__c,
				ApiMock__mdt.IsActive__c,
				ApiMock__mdt.Priority__c,
				ApiMock__mdt.ResponseBody__c,
				ApiMock__mdt.StatusCode__c,
				ApiMock__mdt.ResponseHeaders__c,
				ApiMock__mdt.MatchRequestBodyPattern__c,
				ApiMock__mdt.IsRegex__c,
				ApiMock__mdt.DelayMs__c,
				ApiMock__mdt.FailureRate__c
		};
	}

	/**
	 * @description Returns the relationship field paths for ApiSetting__mdt queries.
	 * Includes the Named Credential reference from the ApiCredential__r parent relationship.
	 *
	 * @return List of relationship field path strings
	 */
	public override List<String> getFieldPaths()
	{
		return new List<String>
		{
				PATH_API_SETTING_DEVELOPER_NAME
		};
	}

	/**
	 * @description Framework-internal CMDT selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Subscribers typically grant
	 * running users no CRUD on `kern__*__mdt` records by design, so USER_MODE reads would
	 * return empty and framework behaviour would silently break.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Finds active mock records for a given API setting developer name.
	 * Adds DeveloperName as a stable secondary sort so ties on Priority__c are deterministic
	 * across orgs (otherwise the platform decides which same-priority mock wins).
	 *
	 * @param apiSettingDeveloperName The developer name of the parent ApiSetting__mdt record
	 *
	 * @return List of matching mock records ordered by Priority__c then DeveloperName ascending
	 */
	public List<ApiMock__mdt> findByApiSetting(String apiSettingDeveloperName)
	{
		return query
				.condition(PATH_API_SETTING_DEVELOPER_NAME).equals(apiSettingDeveloperName)
				.andCondition(ApiMock__mdt.IsActive__c).equals(true)
				.orderBy(ApiMock__mdt.Priority__c).ascending()
				.orderBy(ApiMock__mdt.DeveloperName).ascending()
				.toList();
	}
}