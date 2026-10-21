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
 * @date February 2026, October 2026
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
	public static final Integer REQUEST_PARAMETERS_HASH_LENGTH = UTIL_SObjectDescribe.getCachedFieldDescribe(ApiIssue__c.RequestParametersHash__c).getLength();

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
	 * @description The start of the path, from an issue, to a field of its call: the name of the ApiCall__c lookup as a
	 * relationship, then a dot. It is built from the describe of the field, so it carries the package namespace when
	 * there is one.
	 */
	private static final String CALL_PATH = UTIL_SObjectDescribe.getCachedFieldDescribe(ApiIssue__c.ApiCall__c).getRelationshipName() + UTIL_String.DOT;

	/**
	 * @description The path, from an issue, to the service name of its call.
	 */
	private static final String CALL_SERVICE_NAME_FIELD = CALL_PATH + UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.ServiceName__c);

	/**
	 * @description The path, from an issue, to the Idempotency-Key of its call.
	 */
	private static final String CALL_IDEMPOTENCY_KEY_FIELD = CALL_PATH + UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.IdempotencyKey__c);

	/**
	 * @description The path, from an issue, to the status of its call.
	 */
	private static final String CALL_STATUS_FIELD = CALL_PATH + UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.Status__c);

	/**
	 * @description The path, from an issue, to the field that says its call was answered from an earlier call.
	 */
	private static final String CALL_IDEMPOTENCY_HIT_FIELD = CALL_PATH + UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.IsIdempotencyHit__c);

	/**
	 * @description The path, from an issue, to the user who created its call.
	 */
	private static final String CALL_SENDER_FIELD = CALL_PATH + UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.CreatedById);

	/**
	 * @description The path, from an issue, to the user who created the call its own call tries again: its call's
	 * PreviousAttempt__c lookup followed to that call's CreatedById.
	 */
	private static final String CALL_PREVIOUS_ATTEMPT_SENDER_FIELD = CALL_PATH
			+ UTIL_SObjectDescribe.getCachedFieldDescribe(ApiCall__c.PreviousAttempt__c).getRelationshipName()
			+ UTIL_String.DOT + UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.CreatedById);

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
				ApiIssue__c.ApiCall__c,
				ApiIssue__c.Direction__c,
				ApiIssue__c.ErrorMessages__c,
				ApiIssue__c.ExternalSystemMayHaveActed__c,
				ApiIssue__c.IdempotencyKey__c,
				ApiIssue__c.OriginatingRecordId__c,
				ApiIssue__c.RequestBody__c,
				ApiIssue__c.RequestMethod__c,
				ApiIssue__c.RequestParametersHash__c,
				ApiIssue__c.RequestParameters__c,
				ApiIssue__c.RequestPath__c,
				ApiIssue__c.ResolvedDate__c,
				ApiIssue__c.ServiceName__c,
				ApiIssue__c.Status__c,
				ApiIssue__c.TriggeringRecordId__c
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
	 * @description Finds every user's open issues for one request: the same triggering record, service name and request
	 * parameters hash. Use it to find out whether a request you know about has failed and is still open, for example to
	 * mark those issues resolved once the request succeeds.
	 *
	 * The method reads in system mode and ignores record sharing, so it returns the open issues of every user, not only
	 * the ones the running user owns or can see. That is safe because you must already hold the record Id, the service
	 * name and the request parameters hash to ask: you are asking about a request you know. The framework itself relies on
	 * this answer when a later call for the same request succeeds, and the user whose call succeeds is often not the user
	 * whose call failed. Your code decides what to show to whom: if you show the returned issues to a person, check that
	 * they may see them first.
	 *
	 * @param recordId The Id of the triggering record
	 * @param serviceName The name of the web service
	 * @param hashParameter The request parameters hash to match
	 *
	 * @return The open issues for the request, whoever owns them
	 *
	 * @since 1.0
	 */
	global List<ApiIssue__c> findByFailedApiCall(Id recordId, String serviceName, String hashParameter)
	{
		return query
				.systemModeInternal()
				.bypassSharingInternal()
				.condition(ApiIssue__c.TriggeringRecordId__c).equals(recordId)
				.condition(ApiIssue__c.Status__c).equals(STATUS_OPEN)
				.condition(ApiIssue__c.ServiceName__c).equals(serviceName)
				.condition(ApiIssue__c.RequestParametersHash__c).equals(hashParameter)
				.withLimit(UTIL_Limits.dmlRows().maximum())
				.toList();
	}

	/**
	 * @description Finds the open issues of the given API calls, whoever owns them. The delete guard on API calls
	 * (TRG_GuardApiCallWithOpenIssue) uses it to keep every call that still has an open issue.
	 *
	 * The method reads in system mode and ignores record sharing. API issues are private, so a read with the running
	 * user's sharing would miss the issues that user cannot see, and the deleting user could then delete a call whose
	 * issue is still open. The rows are never shown to anyone: they only refuse a delete.
	 *
	 * @param apiCallIds The Ids of the API calls to check
	 *
	 * @return The open issues of those calls, whoever owns them
	 */
	public List<ApiIssue__c> findOpenByApiCalls(Set<Id> apiCallIds)
	{
		return query
				.systemModeInternal()
				.bypassSharingInternal()
				.condition(ApiIssue__c.ApiCall__c).isIn(new List<Id>(apiCallIds))
				.andCondition(ApiIssue__c.Status__c).equals(STATUS_OPEN)
				.toList();
	}

	/**
	 * @description Finds the open issues of one inbound request, whoever owns them. A request is what one user sent to one
	 * service under one Idempotency-Key, however many times that user sent it. The issues found are those whose call
	 * belongs to the request and did not complete. Two parts of the framework use it (see API_Inbound):
	 *
	 * 1. A failed request with a key writes no issue of its own when this finds one. It only checks whether any row came
	 *    back.
	 * 2. A successful request with a key marks Resolved the issues this finds, and saves them.
	 *
	 * A call belongs to the user in two ways, as in SEL_ApiCall.findByServiceAndIdempotencyKey: the user created it
	 * (CreatedById), or it tries again a call the user created (its PreviousAttempt__c), which is how a run of the
	 * request by another person is found. A call answered from an earlier call (IsIdempotencyHit__c) is left out, because
	 * it ran nothing. Unlike that read of the calls, this read does not stop at the newest calls: only the first failed
	 * call of a request holds the open issue, and a caller may have sent the request many times since.
	 *
	 * The method reads in system mode and ignores record sharing. API issues and API calls are private, so a read with the
	 * running user's sharing would miss the issues that user cannot see: a failed request could then write a second open
	 * issue, or a request could leave an issue open after its retry succeeded. The rows are never shown to anyone: they
	 * decide whether an issue is written, or are saved as Resolved. It returns at most as many rows as one transaction
	 * may save.
	 *
	 * @param serviceName The service the request was sent to
	 * @param idempotencyKey The Idempotency-Key the request carried
	 * @param senderId The user who sent the request. While an issue's request is run again, it is the user who sent the
	 * call the request was read from.
	 *
	 * @return The open issues of the request, whoever owns them
	 */
	public List<ApiIssue__c> findOpenByIdempotencyKey(String serviceName, String idempotencyKey, Id senderId)
	{
		QRY_Condition.OrCondition sentByTheSender = new QRY_Condition.OrCondition();
		sentByTheSender.add(new QRY_Condition.FieldCondition(CALL_SENDER_FIELD, QRY_Condition.Operator.EQUALS, senderId));
		sentByTheSender.add(new QRY_Condition.FieldCondition(CALL_PREVIOUS_ATTEMPT_SENDER_FIELD, QRY_Condition.Operator.EQUALS, senderId));
		return query
				.systemModeInternal()
				.bypassSharingInternal()
				.condition(ApiIssue__c.Status__c).equals(STATUS_OPEN)
				.condition(CALL_SERVICE_NAME_FIELD).equals(serviceName)
				.condition(CALL_IDEMPOTENCY_KEY_FIELD).equals(idempotencyKey)
				.condition(CALL_STATUS_FIELD).notEquals(SEL_ApiCall.STATUS_COMPLETED)
				.condition(CALL_IDEMPOTENCY_HIT_FIELD).equals(false)
				.addCondition(sentByTheSender)
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