// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the ApiCall__c object. Provides query methods for
 * service call management, status tracking, and assertion utilities for test verification.
 *
 * @see SEL_Base
 * @see SEL_ApiCall_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, June 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * List<ApiCall__c> calls = new SEL_ApiCall().findByServiceName('API_SendEmail');
 * ApiCall__c call = (ApiCall__c)new SEL_ApiCall().findById(callId);
 * ApiCall__c existing = new SEL_ApiCall().findByIdempotencyKey('550e8400-e29b-41d4-a716-446655440000');
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SEL_ApiCall extends SEL_Base
{
	/**
	 * @description The maximum number of digits that can be stored in the CalloutDurationMs__c field.
	 */
	public static final Integer CALL_OUT_TIME_TAKEN_LENGTH = ApiCall__c.CalloutDurationMs__c.getDescribe().getPrecision();

	/**
	 * @description The maximum number of characters that can be stored in the Request__c field.
	 */
	public static final Integer REQUEST_LENGTH = ApiCall__c.Request__c.getDescribe().getLength();

	/**
	 * @description The maximum number of characters that can be stored in the RequestParameters__c field.
	 */
	public static final Integer REQUEST_PARAMETERS_LENGTH = ApiCall__c.RequestParameters__c.getDescribe().getLength();

	/**
	 * @description The maximum number of characters that can be stored in the Response__c field.
	 */
	public static final Integer RESPONSE_LENGTH = ApiCall__c.Response__c.getDescribe().getLength();

	/**
	 * @description The maximum number of characters that can be stored in the URL__c field.
	 */
	public static final Integer URL_LENGTH = ApiCall__c.URL__c.getDescribe().getLength();

	/**
	 * @description Status indicating the API call was aborted. Mirrors the `Aborted` value of the
	 * `ApiCall__c.Status__c` picklist; subscribers may either reference this constant or use the
	 * literal directly.
	 */
	public static final String STATUS_ABORTED = 'Aborted';

	/**
	 * @description Status indicating the API call is batched for processing.
	 */
	public static final String STATUS_BATCHED = 'Batched';

	/**
	 * @description Status indicating the API call completed successfully.
	 */
	public static final String STATUS_COMPLETED = 'Completed';

	/**
	 * @description Status indicating the API call failed.
	 */
	public static final String STATUS_FAILED = 'Failed';

	/**
	 * @description Status indicating the API call is queued for processing.
	 */
	public static final String STATUS_QUEUED = 'Queued';

	/**
	 * @description Status indicating the API call is set for retry.
	 */
	public static final String STATUS_RETRY = 'Retry';

	/**
	 * @description Type indicating an inbound API call.
	 */
	public static final String TYPE_INBOUND = 'Inbound';

	/**
	 * @description Type indicating an outbound API call.
	 */
	public static final String TYPE_OUTBOUND = 'Outbound';

	/**
	 * @description Error message when no API calls are found for a service.
	 */
	private static final String ERROR_INCORRECT_ERROR_MESSAGE = 'Error message does not contain the expected phrase';

	/**
	 * @description Error message when API call status does not match expected.
	 */
	private static final String ERROR_INCORRECT_STATUS = 'Incorrect status for API call';

	/**
	 * @description Error message when no API calls are found for a service.
	 */
	private static final String ERROR_NO_ITEMS_FOUND = 'No API calls found for service';

	/**
	 * @description Constructs a new SEL_ApiCall selector instance.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SEL_ApiCall instance = new SEL_ApiCall();
	 * ```
	 */
	global SEL_ApiCall()
	{
		super(ApiCall__c.SObjectType);
	}

	/**
	 * @description Returns the default fields for ApiCall__c queries.
	 *
	 * @return List of SObjectField tokens to include in queries.
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
				ApiCall__c.CreatedById,
				ApiCall__c.CreatedDate,
				ApiCall__c.DeadLettered__c,
				ApiCall__c.Direction__c,
				ApiCall__c.ErrorMessages__c,
				ApiCall__c.IdempotencyKey__c,
				ApiCall__c.IdempotencyKeyBodyHash__c,
				ApiCall__c.IsIdempotencyHit__c,
				ApiCall__c.LoggerContext__c,
				ApiCall__c.ManualDeadLetter__c,
				ApiCall__c.MaxRetries__c,
				ApiCall__c.Name,
				ApiCall__c.NextRetry__c,
				ApiCall__c.ParentSpanId__c,
				ApiCall__c.RequestParameters__c,
				ApiCall__c.Request__c,
				ApiCall__c.Response__c,
				ApiCall__c.Retries__c,
				ApiCall__c.ServiceName__c,
				ApiCall__c.StatusCode__c,
				ApiCall__c.Status__c,
				ApiCall__c.TotalDurationMs__c,
				ApiCall__c.TraceId__c,
				ApiCall__c.TriggeringRecordId__c,
				ApiCall__c.TriggeringRecordUrl__c,
				ApiCall__c.URL__c
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
	 * @description Retrieves ApiCall__c records by a specific service name.
	 *
	 * @param serviceName The name of the service to filter on.
	 *
	 * @return List of ApiCall__c records with the specified Service__c value.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ApiCall__c> apiCalls = new SEL_ApiCall().findByServiceName('MyExternalService');
	 * ```
	 */
	global List<ApiCall__c> findByServiceName(String serviceName)
	{
		return query
				.condition(ApiCall__c.ServiceName__c).equals(serviceName)
				.toList();
	}

	/**
	 * @description Finds an ApiCall__c record by its idempotency key (External ID lookup).
	 *
	 * @param idempotencyKey The idempotency key to search for
	 *
	 * @return The matching ApiCall__c record, or null if not found
	 *
	 * @example
	 * ```apex
	 * ApiCall__c existing = new SEL_ApiCall().findByIdempotencyKey('550e8400-e29b-41d4-a716-446655440000');
	 * ```
	 */
	public ApiCall__c findByIdempotencyKey(String idempotencyKey)
	{
		return (ApiCall__c)findFirstByField(ApiCall__c.IdempotencyKey__c, idempotencyKey);
	}

	/**
	 * @description Finds a successfully completed ApiCall__c record by its idempotency key.
	 * Only returns records with Completed status — failed or aborted calls are ignored
	 * so that clients can retry after a failure.
	 *
	 * @param idempotencyKey The idempotency key to search for
	 *
	 * @return The matching completed ApiCall__c record, or null if not found or not completed
	 */
	public ApiCall__c findCompletedByIdempotencyKey(String idempotencyKey)
	{
		return (ApiCall__c)query
				.condition(ApiCall__c.IdempotencyKey__c).equals(idempotencyKey)
				.andCondition(ApiCall__c.Status__c).equals(STATUS_COMPLETED)
				.getFirst();
	}

	/**
	 * @description Retrieves ApiCall__c records that are batched and outbound. Bypasses sharing
	 * rules: this is the batched-callout sweep, which must see every user's batched calls —
	 * `ApiCall__c` has a Private sharing model, so a sweep scheduled by a user without View All
	 * would otherwise silently skip rows owned by other users.
	 *
	 * @return List of ApiCall__c records with Status__c = "Batched" and Type__c = "Outbound".
	 *
	 * @example
	 * ```apex
	 * List<ApiCall__c> batched = new SEL_ApiCall().findByBatchedOutbound();
	 * ```
	 */
	public List<ApiCall__c> findByBatchedOutbound()
	{
		return query
				.bypassSharingInternal()
				.condition(ApiCall__c.Direction__c).equals(TYPE_OUTBOUND)
				.condition(ApiCall__c.Status__c).equals(STATUS_BATCHED)
				.withLimit(UTIL_Limits.soqlQueryRows().maximum())
				.toList();
	}

	/**
	 * @description Updates the retry information for an ApiCall__c record.
	 *
	 * @param item The ApiCall__c record to update.
	 * @param nextRetryTime The datetime for the next retry attempt.
	 */
	public static void updateNextRetryInfo(ApiCall__c item, Datetime nextRetryTime)
	{
		item.NextRetry__c = nextRetryTime;
		item.Retries__c = (item.Retries__c ?? 0) + 1;
		item.Status__c = STATUS_RETRY;
	}

	/**
	 * @description Verifies that API calls for a specific service name have an aborted status.
	 *
	 * @param serviceName The name of the API class to check.
	 *
	 * @return List of ApiCall__c records with "Aborted" status for the specified service.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ApiCall__c> aborted = SEL_ApiCall.assertServiceAborted('MyExternalService');
	 * ```
	 */
	global static List<ApiCall__c> assertServiceAborted(String serviceName)
	{
		return assertServiceAborted(serviceName, null);
	}

	/**
	 * @description Verifies that API calls for a specific service name have an aborted status
	 * and optionally checks for a specific error phrase.
	 *
	 * @param serviceName The name of the API class to check.
	 * @param errorPhrase Optional phrase to look for in the Errors__c field (null to ignore).
	 *
	 * @return List of matching aborted ApiCall__c records.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ApiCall__c> aborted = SEL_ApiCall.assertServiceAborted('MyExternalService', 'Connection timeout');
	 * ```
	 */
	global static List<ApiCall__c> assertServiceAborted(String serviceName, String errorPhrase)
	{
		return assertServiceHasCorrectStatus(serviceName, errorPhrase, STATUS_ABORTED);
	}

	/**
	 * @description Verifies that API calls for a specific service name have a completed status.
	 *
	 * @param serviceName The name of the API class to check.
	 *
	 * @return List of ApiCall__c records with "Completed" status for the specified service.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ApiCall__c> result = SEL_ApiCall.assertServiceCompleted('SEL_ApiCall');
	 * ```
	 */
	global static List<ApiCall__c> assertServiceCompleted(String serviceName)
	{
		return assertServiceHasCorrectStatus(serviceName, null, STATUS_COMPLETED);
	}

	/**
	 * @description Verifies that API calls for a specific service name have a failed status.
	 *
	 * @param serviceName The name of the API class to check.
	 *
	 * @return List of ApiCall__c records with "Failed" status for the specified service.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ApiCall__c> result = SEL_ApiCall.assertServiceFailed('SEL_ApiCall');
	 * ```
	 */
	global static List<ApiCall__c> assertServiceFailed(String serviceName)
	{
		return assertServiceFailed(serviceName, null);
	}

	/**
	 * @description Verifies that API calls for a specific service name have a failed status
	 * and optionally checks for a specific error phrase.
	 *
	 * @param serviceName The name of the API class to check.
	 * @param errorPhrase Optional phrase to look for in the Errors__c field (null to ignore).
	 *
	 * @return List of matching failed ApiCall__c records.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ApiCall__c> result = SEL_ApiCall.assertServiceFailed('SEL_ApiCall', 'value');
	 * ```
	 */
	global static List<ApiCall__c> assertServiceFailed(String serviceName, String errorPhrase)
	{
		return assertServiceHasCorrectStatus(serviceName, errorPhrase, STATUS_FAILED);
	}

	/**
	 * @description Internal helper that verifies API calls for a service have the expected status
	 * and optionally contain a specific error phrase. Used by the public assert methods.
	 *
	 * @param serviceName The name of the API class to check.
	 * @param errorPhrase Optional phrase to look for in Errors__c (null to ignore).
	 * @param expectedStatus The expected status value.
	 *
	 * @return List of matching ApiCall__c records.
	 */
	private static List<ApiCall__c> assertServiceHasCorrectStatus(String serviceName, String errorPhrase, String expectedStatus)
	{
		List<ApiCall__c> items = new SEL_ApiCall().findByServiceName(serviceName);

		Assert.isFalse(items.isEmpty(), ERROR_NO_ITEMS_FOUND + ': "' + serviceName + '"');

		for(ApiCall__c item : items)
		{
			Assert.areEqual(expectedStatus, item.Status__c, ERROR_INCORRECT_STATUS + ': ' + item.Id);
			Assert.isTrue(errorPhrase == null || (item.ErrorMessages__c != null && item.ErrorMessages__c.contains(errorPhrase)), ERROR_INCORRECT_ERROR_MESSAGE);
		}

		return items;
	}
}