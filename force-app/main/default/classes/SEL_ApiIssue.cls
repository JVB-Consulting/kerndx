// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the ApiIssue__c SObject. Provides query methods for
 * retrieving and filtering failed API calls, including deduplication via request
 * parameter hash and status-based filtering.
 *
 * @see SEL_Base
 * @see SEL_ApiIssue_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService('API_SendEmail');
 * List<ApiIssue__c> inbound = new SEL_ApiIssue().findUnresolvedInbound();
 * ApiIssue__c issue = (ApiIssue__c)new SEL_ApiIssue().findById(issueId);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SEL_ApiIssue extends SEL_Base
{
	/**
	 * @description The maximum number of characters that can be stored in the Request Parameters Hash field.
	 */
	public static final Integer REQUEST_PARAMETERS_HASH_LENGTH = ApiIssue__c.RequestParametersHash__c.getDescribe().getLength();

	/**
	 * @description Direction value indicating an inbound API issue. Mirrors the `Inbound` value of
	 * the `ApiIssue__c.Direction__c` picklist; subscribers may either reference this constant or
	 * use the literal directly.
	 */
	public static final String DIRECTION_INBOUND = 'Inbound';

	/**
	 * @description Direction value indicating an outbound API issue.
	 */
	public static final String DIRECTION_OUTBOUND = 'Outbound';

	/**
	 * @description Status value indicating an open API issue awaiting investigation or resolution.
	 */
	public static final String STATUS_OPEN = 'Open';

	/**
	 * @description Status value indicating an issue that was resolved by a successful retry.
	 */
	public static final String STATUS_RESOLVED = 'Resolved';

	/**
	 * @description Constructs an ApiIssue selector.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_ApiIssue instance = new SEL_ApiIssue();
	 * ```
	 */
	global SEL_ApiIssue()
	{
		super(ApiIssue__c.SObjectType);
	}

	/**
	 * @description Returns the core fields for ApiIssue__c queries.
	 *
	 * @return List of ApiIssue__c SObjectField tokens
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
				ApiIssue__c.ErrorMessages__c,
				ApiIssue__c.IdempotencyKey__c,
				ApiIssue__c.OriginatingRecordId__c,
				ApiIssue__c.RequestParametersHash__c,
				ApiIssue__c.RequestParameters__c,
				ApiIssue__c.ServiceName__c,
				ApiIssue__c.Status__c,
				ApiIssue__c.TriggeringRecordId__c,
				ApiIssue__c.ApiCall__c,
				ApiIssue__c.Direction__c,
				ApiIssue__c.RequestPath__c,
				ApiIssue__c.RequestMethod__c,
				ApiIssue__c.RequestBody__c,
				ApiIssue__c.ResolvedDate__c
		};
	}

	/**
	 * @description Framework-owned sObject selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically have no
	 * CRUD on framework-owned records (the framework owns their lifecycle), so USER_MODE reads
	 * would return empty and observability would silently break.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Retrieves all ApiIssue__c records. Only executes in test context
	 * to prevent full-table scans in production.
	 *
	 * @return List of all ApiIssue__c records in test context, empty list in production
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ApiIssue__c> result = instance.getAll();
	 * ```
	 */
	global List<ApiIssue__c> getAll()
	{
		return !Test.isRunningTest() ? new List<ApiIssue__c>() : query.toList();
	}

	/**
	 * @description Finds failed API call records matching the triggering object, service name, and request hash.
	 *
	 * @param recordId The Id of the triggering record
	 * @param serviceName The name of the web service
	 * @param hashParameter The request parameters hash to match
	 *
	 * @return List of matching failed ApiIssue__c records
	 *
	 * @since 1.0
	 */
	global List<ApiIssue__c> findByFailedApiCall(Id recordId, String serviceName, String hashParameter)
	{
		return query
				.condition(ApiIssue__c.TriggeringRecordId__c).equals(recordId)
				.condition(ApiIssue__c.Status__c).equals(STATUS_OPEN)
				.condition(ApiIssue__c.ServiceName__c).equals(serviceName)
				.condition(ApiIssue__c.RequestParametersHash__c).equals(hashParameter)
				.withLimit(UTIL_Limits.dmlRows().maximum())
				.toList();
	}

	/**
	 * @description Finds unresolved failures for a specific service.
	 *
	 * @param serviceName The service class name
	 *
	 * @return List of unresolved failure records
	 */
	public List<ApiIssue__c> findUnresolvedByService(String serviceName)
	{
		return query
				.condition(ApiIssue__c.ServiceName__c).equals(serviceName)
				.andCondition(ApiIssue__c.Status__c).equals(STATUS_OPEN)
				.orderBy(ApiIssue__c.CreatedDate).descending()
				.toList();
	}

	/**
	 * @description Finds unresolved inbound failures for replay.
	 *
	 * @return List of unresolved inbound failure records
	 */
	public List<ApiIssue__c> findUnresolvedInbound()
	{
		return query
				.condition(ApiIssue__c.Direction__c).equals(DIRECTION_INBOUND)
				.andCondition(ApiIssue__c.Status__c).equals(STATUS_OPEN)
				.orderBy(ApiIssue__c.CreatedDate).descending()
				.toList();
	}
}