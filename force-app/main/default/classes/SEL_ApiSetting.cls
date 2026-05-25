// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the ApiSetting__mdt custom metadata type. Provides query methods
 * for retrieving API service configuration including credential relationship fields.
 *
 * @see SEL_Base
 * @see SEL_ApiSetting_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
public inherited sharing class SEL_ApiSetting extends SEL_Base
{
	/**
	 * @description Relationship path for ApiCredential__r.NamedCredential__c (namespace-safe).
	 */
	private static final String PATH_API_CREDENTIAL_NAMED_CREDENTIAL =
			ApiSetting__mdt.ApiCredential__c.getDescribe().getRelationshipName() + UTIL_String.DOT +
			UTIL_SObjectDescribe.getCachedFieldName(ApiCredential__mdt.NamedCredential__c);

	/**
	 * @description Relationship path for BypassFeatureFlag__r.DeveloperName (namespace-safe).
	 */
	private static final String PATH_BYPASS_FEATURE_FLAG_DEVELOPER_NAME =
			ApiSetting__mdt.BypassFeatureFlag__c.getDescribe().getRelationshipName() + '.DeveloperName';
	/**
	 * @description Relationship path for RequiredFeatureFlag__r.DeveloperName (namespace-safe).
	 */
	private static final String PATH_REQUIRED_FEATURE_FLAG_DEVELOPER_NAME =
			ApiSetting__mdt.RequiredFeatureFlag__c.getDescribe().getRelationshipName() + '.DeveloperName';

	/**
	 * @description Direction value indicating an inbound API setting.
	 */
	public static final String DIRECTION_INBOUND = 'Inbound';

	/**
	 * @description Direction value indicating an outbound API setting.
	 */
	public static final String DIRECTION_OUTBOUND = 'Outbound';

	/**
	 * @description Constructs an ApiSetting selector.
	 */
	public SEL_ApiSetting()
	{
		super(ApiSetting__mdt.SObjectType);
	}

	/**
	 * @description Returns the core fields for ApiSetting__mdt queries.
	 *
	 * @return List of ApiSetting__mdt SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				ApiSetting__mdt.MasterLabel,
				ApiSetting__mdt.ApiCredential__c,
				ApiSetting__mdt.CircuitBreakerEnabled__c,
				ApiSetting__mdt.CircuitBreakerFailureThreshold__c,
				ApiSetting__mdt.CircuitBreakerSuccessThreshold__c,
				ApiSetting__mdt.CircuitBreakerTimeout__c,
				ApiSetting__mdt.ClassName__c,
				ApiSetting__mdt.DeveloperName,
				ApiSetting__mdt.Direction__c,
				ApiSetting__mdt.EndpointPath__c,
				ApiSetting__mdt.IdempotencyEnabled__c,
				ApiSetting__mdt.IsActive__c,
				ApiSetting__mdt.LogIssues__c,
				ApiSetting__mdt.MaxRetryCount__c,
				ApiSetting__mdt.MockingEnabled__c,
				ApiSetting__mdt.NamespacePrefix,
				ApiSetting__mdt.Priority__c,
				ApiSetting__mdt.RequiredFeatureFlag__c,
				ApiSetting__mdt.BypassFeatureFlag__c,
				ApiSetting__mdt.ResolveIssues__c,
				ApiSetting__mdt.RetryBackoffSeconds__c,
				ApiSetting__mdt.RetryIssues__c
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
				PATH_API_CREDENTIAL_NAMED_CREDENTIAL,
				PATH_BYPASS_FEATURE_FLAG_DEVELOPER_NAME,
				PATH_REQUIRED_FEATURE_FLAG_DEVELOPER_NAME
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
	 * @description Finds an ApiSetting__mdt record by its class name.
	 *
	 * @param className The fully qualified Apex class name of the web service handler
	 *
	 * @return The matching record or null if not found
	 */
	public ApiSetting__mdt findByClassName(String className)
	{
		return (ApiSetting__mdt)findFirstByField(ApiSetting__mdt.ClassName__c, className);
	}

	/**
	 * @description Finds all active inbound routes for dynamic routing.
	 *
	 * @return List of active inbound settings ordered by priority
	 */
	public List<ApiSetting__mdt> findActiveInboundRoutes()
	{
		return query
				.condition(ApiSetting__mdt.Direction__c).equals(DIRECTION_INBOUND)
				.andCondition(ApiSetting__mdt.IsActive__c).equals(true)
				.andCondition(ApiSetting__mdt.EndpointPath__c).isNotNull()
				.orderBy(ApiSetting__mdt.Priority__c).ascending()
				.toList();
	}

	/**
	 * @description Finds all active API settings filtered by direction.
	 *
	 * @param direction The direction to filter by (Inbound or Outbound)
	 *
	 * @return List of active settings for the specified direction
	 */
	public List<ApiSetting__mdt> findActiveByDirection(String direction)
	{
		return query
				.condition(ApiSetting__mdt.Direction__c).equals(direction)
				.andCondition(ApiSetting__mdt.IsActive__c).equals(true)
				.orderBy(ApiSetting__mdt.MasterLabel).ascending()
				.toList();
	}
}