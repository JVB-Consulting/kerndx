// SPDX-License-Identifier: Apache-2.0
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
 * @date February 2026, October 2026
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
	public static final Integer CALL_OUT_TIME_TAKEN_LENGTH = UTIL_SObjectDescribe.getCachedFieldDescribe(ApiCall__c.CalloutDurationMs__c).getPrecision();

	/**
	 * @description The maximum number of characters that can be stored in the Request__c field.
	 */
	public static final Integer REQUEST_LENGTH = UTIL_SObjectDescribe.getCachedFieldDescribe(ApiCall__c.Request__c).getLength();

	/**
	 * @description The maximum number of characters that can be stored in the RequestParameters__c field.
	 */
	public static final Integer REQUEST_PARAMETERS_LENGTH = UTIL_SObjectDescribe.getCachedFieldDescribe(ApiCall__c.RequestParameters__c).getLength();

	/**
	 * @description The maximum number of characters that can be stored in the Response__c field.
	 */
	public static final Integer RESPONSE_LENGTH = UTIL_SObjectDescribe.getCachedFieldDescribe(ApiCall__c.Response__c).getLength();

	/**
	 * @description The maximum number of characters that can be stored in the URL__c field.
	 */
	public static final Integer URL_LENGTH = UTIL_SObjectDescribe.getCachedFieldDescribe(ApiCall__c.URL__c).getLength();

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
	 * @description The Status__c value of a call that ended in an error and will not be retried automatically.
	 */
	public static final String STATUS_FAILED = 'Failed';

	/**
	 * @description Status indicating the API call is being sent.
	 */
	public static final String STATUS_PROCESSING = 'Processing';

	/**
	 * @description Status indicating the API call is queued for processing.
	 */
	public static final String STATUS_QUEUED = 'Queued';

	/**
	 * @description The Status__c value of a call that failed and waits for an automatic retry at the time in NextRetry__c.
	 */
	public static final String STATUS_RETRY = 'Retry';

	/**
	 * @description Status indicating the API call is being sent again by its automatic retry.
	 */
	public static final String STATUS_RETRYING = 'Retrying';

	/**
	 * @description The Direction__c value of a call another system made into this org.
	 */
	public static final String TYPE_INBOUND = 'Inbound';

	/**
	 * @description The Direction__c value of a call this org made to another system.
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
	 * @description The most calls findByServiceAndIdempotencyKey returns for one key. Every inbound request with a key
	 * makes that read, so it stays small: each call read can hold a response as long as the Response field. A caller that
	 * sends the same key more often than this has its oldest calls left out of the read.
	 */
	@TestVisible
	private static final Integer MAXIMUM_CALLS_PER_IDEMPOTENCY_KEY = 20;

	/**
	 * @description The path, from a call, to the user who sent the call it tries again: the PreviousAttempt__c lookup
	 * followed to that call's CreatedById. It is built from the describe of the fields, so it carries the package
	 * namespace when there is one.
	 */
	private static final String PREVIOUS_ATTEMPT_SENDER_FIELD = UTIL_SObjectDescribe.getCachedFieldDescribe(ApiCall__c.PreviousAttempt__c).getRelationshipName()
			+ UTIL_String.DOT + UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.CreatedById);

	/**
	 * @description The statuses that mean a call is in progress or will be sent: Batched, Processing, Queued, Retry and
	 * Retrying. A new status with that meaning is added here in the same change. A list, because the query condition
	 * that matches one of several values takes a list.
	 */
	private static final List<String> OPEN_STATUSES = new List<String> {STATUS_BATCHED, STATUS_PROCESSING, STATUS_QUEUED, STATUS_RETRY, STATUS_RETRYING};

	/**
	 * @description Reads ApiCall__c records: the record kept for each web service call, inbound or outbound. Every query skips the running user's object and field permission
	 * checks (system mode). Record sharing follows the class that calls the selector, unless a method says otherwise. Creating the selector runs no query.
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
				ApiCall__c.IsPermanentFailure__c,
				ApiCall__c.LoggerContext__c,
				ApiCall__c.ManualDeadLetter__c,
				ApiCall__c.MaxRetries__c,
				ApiCall__c.Name,
				ApiCall__c.NextRetry__c,
				ApiCall__c.ParentSpanId__c,
				ApiCall__c.PreviousAttempt__c,
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
	 * @description Framework-owned sObject selector: always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically have no
	 * CRUD on framework-owned records (the framework owns their lifecycle), so USER_MODE reads
	 * would return empty and observability would silently break.
	 *
	 * @return `true`, because this selector requires SYSTEM_MODE.
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
	 * @description Finds the calls one user sent to one service with the given Idempotency-Key, whatever their status,
	 * newest first. An inbound request with a key reads them once, before it runs, to decide three things: whether a
	 * completed call already holds the answer, whether this request is a retry of an earlier call that did not complete,
	 * and which earlier calls may hold an open issue. A key belongs to the user who sent it: a call another user sent with
	 * the same key is a different request, so it is never read here. A call that was itself answered from an earlier call
	 * (IsIdempotencyHit__c) is left out, because it ran nothing.
	 *
	 * A call counts as the user's call in two ways:
	 *
	 * 1. The user created it (CreatedById).
	 * 2. It tries again a call the user created (its PreviousAttempt__c). This is how the call of an issue's request run
	 *    again is found. A person who runs the request again creates that call, but the request still belongs to the user
	 *    who sent it first. So when that user sends the request again after it was run again with success, the user gets
	 *    the answer that run stored, and the request does not run twice. A request links only to a call its own sender
	 *    created (see API_Inbound.checkIdempotency), so a call found this way that the user did not create is a run of
	 *    one of the user's requests by another person: the framework sets the link in no other way.
	 *
	 * The read returns at most MAXIMUM_CALLS_PER_IDEMPOTENCY_KEY calls, and only the fields those decisions need: the
	 * user who created the call, the status, the hash of the body and the response. It ignores record sharing on purpose,
	 * for this read only (the inbound request's check of its key, API_Inbound). ApiCall__c is Private, and a call of the
	 * user can belong to another owner. So the answer depends only on who sent the calls, never on which calls the user
	 * can see.
	 *
	 * @param serviceName The service the calls belong to.
	 * @param idempotencyKey The Idempotency-Key the calls carried.
	 * @param senderId The user who sent the calls: the running user of the inbound request, saved on each call as the
	 * user who created it (CreatedById). While an issue's request is run again, it is the user who sent the call the
	 * request was read from.
	 *
	 * @return The calls of the user for the service with the key, newest first.
	 */
	public List<ApiCall__c> findByServiceAndIdempotencyKey(String serviceName, String idempotencyKey, Id senderId)
	{
		QRY_Condition.OrCondition sentByTheSender = new QRY_Condition.OrCondition();
		sentByTheSender.add(new QRY_Condition.FieldCondition(ApiCall__c.CreatedById, QRY_Condition.Operator.EQUALS, senderId));
		sentByTheSender.add(new QRY_Condition.FieldCondition(PREVIOUS_ATTEMPT_SENDER_FIELD, QRY_Condition.Operator.EQUALS, senderId));
		return query
				.bypassSharingInternal()
				.onlyFields(new List<SObjectField> {ApiCall__c.CreatedById, ApiCall__c.IdempotencyKeyBodyHash__c, ApiCall__c.Response__c, ApiCall__c.Status__c})
				.condition(ApiCall__c.ServiceName__c).equals(serviceName)
				.condition(ApiCall__c.IdempotencyKey__c).equals(idempotencyKey)
				.addCondition(sentByTheSender)
				.condition(ApiCall__c.IsIdempotencyHit__c).equals(false)
				.orderBy(ApiCall__c.CreatedDate).descending()
				.orderBy(ApiCall__c.Id).descending()
				.withLimit(MAXIMUM_CALLS_PER_IDEMPOTENCY_KEY)
				.toList();
	}

	/**
	 * @description Retrieves ApiCall__c records that are batched and outbound. Bypasses sharing
	 * rules: this is the batched-callout sweep, which must see every user's batched calls.
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
	 * @description Finds the calls among the given ids that are still in progress or waiting to be sent: Queued, Processing,
	 * Retry, Retrying or Batched. Bypasses sharing rules for this one read on purpose: ApiCall__c is Private, and the read
	 * must see a call another user started, or the bulk retry would send a request that is already on its way. The bulk
	 * retry job runs without sharing, so the bypass is stated here so that a caller with sharing gets the same answer.
	 * Nothing else reads through this method.
	 *
	 * @param callIds The call ids to look at
	 *
	 * @return The open calls among them
	 */
	public List<ApiCall__c> findOpenById(Set<Id> callIds)
	{
		return query
				.bypassSharingInternal()
				.condition(ApiCall__c.Id).isIn(new List<Id>(callIds))
				.condition(ApiCall__c.Status__c).isIn(OPEN_STATUSES)
				.withLimit(UTIL_Limits.soqlQueryRows().maximum())
				.toList();
	}

	/**
	 * @description Finds the calls made for any of the given records that are still in progress or waiting to be sent:
	 * Queued, Processing, Retry, Retrying or Batched. Bypasses sharing rules for this one read on purpose: ApiCall__c is
	 * Private, and the read must see a call another user started, or the bulk retry would send a request that is already
	 * on its way. The bulk retry job runs without sharing, so the bypass is stated here so that a caller with sharing gets
	 * the same answer. Nothing else reads through this method.
	 *
	 * @param triggeringRecordIds The ids of the records the calls were made for
	 *
	 * @return The open calls made for those records
	 */
	public List<ApiCall__c> findOpenByTriggeringRecordIds(Set<Id> triggeringRecordIds)
	{
		return query
				.bypassSharingInternal()
				.condition(ApiCall__c.TriggeringRecordId__c).isIn(new List<Id>(triggeringRecordIds))
				.condition(ApiCall__c.Status__c).isIn(OPEN_STATUSES)
				.withLimit(UTIL_Limits.soqlQueryRows().maximum())
				.toList();
	}

	/**
	 * @description Finds the calls with the given ids and reads only what each call kept of its request: the address
	 * with its query string, the HTTP method, the body, the parameters, the Idempotency-Key, the hash of the body as it
	 * was received, whether the call failed permanently, and the user who sent it (CreatedById), because the request
	 * run again checks its key as that user. It reads no other field: the response alone can hold
	 * 131,072 characters, and a check of many issues would hold all of them in memory. Running an inbound issue's request
	 * again reads the request from the issue's call through this method. Bypasses sharing rules for this one read on
	 * purpose: ApiCall__c is Private, and a user who may run issues again sees every issue, so the read must see the call
	 * of an issue another user's request wrote. Nothing else reads through this method.
	 *
	 * @param callIds The ids of the calls to read
	 *
	 * @return The calls found, with their request fields only
	 */
	public List<ApiCall__c> findRequestById(Set<Id> callIds)
	{
		return query
				.bypassSharingInternal()
				.onlyFields(new List<SObjectField>
				{
						ApiCall__c.CreatedById,
						ApiCall__c.HttpMethod__c,
						ApiCall__c.IdempotencyKeyBodyHash__c,
						ApiCall__c.IdempotencyKey__c,
						ApiCall__c.IsPermanentFailure__c,
						ApiCall__c.RequestParameters__c,
						ApiCall__c.Request__c,
						ApiCall__c.URL__c
				})
				.condition(ApiCall__c.Id).isIn(new List<Id>(callIds))
				.withLimit(UTIL_Limits.soqlQueryRows().maximum())
				.toList();
	}

	/**
	 * @description Finds the calls with the given ids and reads only the small fields of the request each call kept: the
	 * address with its query string, the Idempotency-Key, the hash of the body as it was received, and whether the call
	 * failed permanently. It does not read the body or the parameters, which can each hold 131,072 characters. Retry
	 * Selected and the bulk retry read the calls of every selected inbound issue through this method when they schedule
	 * the job, so a large selection does not fill the memory a request may use; the job reads each request whole just
	 * before it runs it (see findRequestById). Bypasses sharing rules for this one read on purpose: ApiCall__c is Private,
	 * and a user who may run issues again sees every issue, so the read must see the call of an issue another user's
	 * request wrote. Nothing else reads through this method.
	 *
	 * @param callIds The ids of the calls to read
	 *
	 * @return The calls found, with those fields only
	 */
	public List<ApiCall__c> findRequestWithoutBodyById(Set<Id> callIds)
	{
		return query
				.bypassSharingInternal()
				.onlyFields(new List<SObjectField>
				{
						ApiCall__c.IdempotencyKeyBodyHash__c,
						ApiCall__c.IdempotencyKey__c,
						ApiCall__c.IsPermanentFailure__c,
						ApiCall__c.URL__c
				})
				.condition(ApiCall__c.Id).isIn(new List<Id>(callIds))
				.withLimit(UTIL_Limits.soqlQueryRows().maximum())
				.toList();
	}

	/**
	 * @description Finds the calls with the given ids and reads only whether each one failed in a way that
	 * running it again cannot fix (IsPermanentFailure__c). Sending an outbound issue's call again checks this first,
	 * and needs nothing else of the call, so the large request and response fields are not read. Bypasses sharing rules
	 * for this one read on purpose: ApiCall__c is Private, and a user may hold the Retry API Issue permission without
	 * seeing every call. Without the bypass, a call another user wrote would be missing from the answer, so it would
	 * look as if it had not failed permanently, and its request would be sent again. Nothing else reads through this
	 * method.
	 *
	 * @param callIds The ids of the calls to read
	 *
	 * @return The calls found, each with its id and its permanent failure field only
	 */
	public List<ApiCall__c> findPermanentFailureById(Set<Id> callIds)
	{
		return query
				.bypassSharingInternal()
				.onlyFields(new List<SObjectField> {ApiCall__c.IsPermanentFailure__c})
				.condition(ApiCall__c.Id).isIn(new List<Id>(callIds))
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
	 * @description Verifies that every API call of a service is in the state the RetryOutboundApiCall flow picks up:
	 * Status__c is Retry and NextRetry__c is set. The flow's entry conditions are exactly NextRetry__c not null,
	 * Status__c equal to Retry and Direction__c equal to Outbound. So a row at Retry with no next retry time is never
	 * retried, and a test that checks only one of the two fields proves nothing about the retry. It is public, not
	 * global, so only the package's own code can call it (its tests use it).
	 *
	 * @param serviceName The name of the API class to check.
	 *
	 * @return List of ApiCall__c records at Retry with a next retry time for the service.
	 */
	public static List<ApiCall__c> assertServiceRetrying(String serviceName)
	{
		List<ApiCall__c> items = assertServiceHasCorrectStatus(serviceName, null, STATUS_RETRY);
		for(ApiCall__c item : items)
		{
			Assert.isNotNull(item.NextRetry__c, ERROR_INCORRECT_STATUS + ': a Retry row carries no next retry time, so the flow never picks it up: ' + item.Id);
		}
		return items;
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