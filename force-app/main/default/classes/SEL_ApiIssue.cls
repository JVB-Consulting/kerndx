// SPDX-License-Identifier: Apache-2.0
/**
 * @description Selector for the ApiIssue__c SObject. Provides query methods for
 * retrieving and filtering failed API calls, including deduplication via request
 * parameter hash and status-based filtering.
 *
 * @see SEL_Base
 * @see SEL_ApiCall
 * @see SEL_ApiIssue_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, November 2026
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
	 * @description The Direction__c value of an issue raised by a call this org made to another system.
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
	 * @description The fields the finders by triggering record return: small fields that say which issue it is and how
	 * it stands, and no request.
	 */
	private static final List<SObjectField> SUMMARY_FIELDS = new List<SObjectField>
	{
			ApiIssue__c.CreatedDate,
			ApiIssue__c.ServiceName__c,
			ApiIssue__c.Status__c,
			ApiIssue__c.TriggeringRecordIndex__c
	};

	/**
	 * @description Reads ApiIssue__c records: the issues raised for failed web service calls. Its queries skip the running user's object and field permission checks (system
	 * mode), except the two finders by triggering record, findByTriggeringRecordIds and findByTriggeringRecordValues. Those two run in user mode, so they respect the running
	 * user's object access, field access and record sharing. For the other queries, record sharing follows the class that calls the selector, unless a method says otherwise.
	 * Creating the selector runs no query.
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
	 * @description Framework-owned sObject selector: its queries run in `AccessLevel.SYSTEM_MODE`
	 * whatever the `UserModeQueries_Enabled` feature flag says. Running users often have no
	 * access to framework-owned records (the framework owns their lifecycle), so user mode reads
	 * would return nothing and the issues would silently disappear from view. The two finders by
	 * triggering record are the exception: findByTriggeringRecordIds and
	 * findByTriggeringRecordValues run in user mode, so they respect the running user's object
	 * access, field access and record sharing.
	 *
	 * @return `true`, because this selector requires SYSTEM_MODE.
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
	 * @description Finds the issues raised for calls made for the given records, newest first, and returns at most
	 * rowLimit of them. Issues saved at the same moment are ordered by their own Id, newest first, so the order is the
	 * same every time.
	 *
	 * An issue is found by its Triggering Record Index field (TriggeringRecordIndex__c), which holds the record Id exactly
	 * as it was written on the issue. This method finds values stored in the full form of 18 characters, which is the form
	 * the framework writes. It does not find a value stored in the short form of 15 characters. Code that sets the
	 * Triggering Record Id field (TriggeringRecordId__c) itself should write the full form, for example
	 * String.valueOf(recordId).
	 *
	 * Each issue holds only these fields: Id, ServiceName__c, Status__c, CreatedDate and TriggeringRecordIndex__c. To get
	 * the request of an issue, read that issue by its Id.
	 *
	 * Triggering Record Index is filled each time an issue is saved. An issue saved before the field existed has it blank
	 * until the update script in the release notes is run, and this method does not find it.
	 *
	 * The read checks the running user's access. The user needs read access to the API Issue object and to each field
	 * above, and gets only the issues that record sharing lets them see. A user without that object or field access gets
	 * an error (a QueryException) instead of a result.
	 *
	 * In a test, the mocked issues are filtered the way the query filters saved ones: only those whose Triggering
	 * Record Index holds one of the values come back. A mock is never saved, so Triggering Record Index is not filled
	 * for it: set it on the mock yourself, because a mock that sets only Triggering Record Id is not found. The match in
	 * a test is exact, so a value in another case is not found. An answer scripted
	 * with TST_Mock.registerNext is filtered the same way, so give its mocks the values this method searches for.
	 *
	 * @param recordIds The Ids of the records the failed calls were made for. A null Id in the set is ignored. The set you
	 * pass is not changed.
	 * @param rowLimit The most issues to return: 1 or more.
	 *
	 * @return The issues found, newest first. An empty list when the set holds no Id; then no query is run.
	 *
	 * @throws IllegalArgumentException When recordIds is null, or rowLimit is null or less than 1.
	 *
	 * @since 1.12
	 *
	 * @example
	 * ```apex
	 * List<ApiIssue__c> issues = new SEL_ApiIssue().findByTriggeringRecordIds(new Set<Id> {accountId}, 10);
	 * ```
	 */
	global List<ApiIssue__c> findByTriggeringRecordIds(Set<Id> recordIds, Integer rowLimit)
	{
		Set<String> searchValues = SEL_ApiCall.getSearchValuesForRecordIds(recordIds, rowLimit);
		return searchValues.isEmpty() ? new List<ApiIssue__c>() : queryByTriggeringRecordIndex(searchValues, rowLimit);
	}

	/**
	 * @description Finds the issues with one of the given values in Triggering Record Index (TriggeringRecordIndex__c),
	 * newest first, and returns at most rowLimit of them. Issues saved at the same moment are ordered by their own Id,
	 * newest first, so the order is the same every time. Use it when the failed calls were made for something that is not
	 * a record in this org, such as an order number from another system; for record Ids, findByTriggeringRecordIds is
	 * simpler.
	 *
	 * Such a value can come from an inbound call, from an issue your own code saves, or from an outbound call whose class
	 * sets requiresTriggeringRecord to false. An issue keeps the whole value of the call that failed, up to 80 characters.
	 *
	 * Triggering Record Index holds the Triggering Record Id field (TriggeringRecordId__c) exactly as it was written on
	 * the issue. Each value is matched as you write it, but the match ignores upper and lower case: 'ORD-1' also finds an
	 * issue whose Triggering Record Index is 'ord-1'. Do not use this method for record Ids in the short form of 15
	 * characters: the short forms of two different records can differ only by case, so it could return issues raised for
	 * another record.
	 *
	 * Each issue holds only these fields: Id, ServiceName__c, Status__c, CreatedDate and TriggeringRecordIndex__c. To get
	 * the request of an issue, read that issue by its Id.
	 *
	 * Triggering Record Index is filled each time an issue is saved. An issue saved before the field existed has it blank
	 * until the update script in the release notes is run, and this method does not find it.
	 *
	 * The read checks the running user's access. The user needs read access to the API Issue object and to each field
	 * above, and gets only the issues that record sharing lets them see. A user without that object or field access gets
	 * an error (a QueryException) instead of a result.
	 *
	 * In a test, the mocked issues are filtered the way the query filters saved ones: only those whose Triggering
	 * Record Index holds one of the values come back. A mock is never saved, so Triggering Record Index is not filled
	 * for it: set it on the mock yourself, because a mock that sets only Triggering Record Id is not found. The match in
	 * a test is exact, so a value in another case is not found. An answer scripted
	 * with TST_Mock.registerNext is filtered the same way, so give its mocks the values this method searches for.
	 *
	 * @param values The values to look for. A null or blank value in the set is ignored. The set you pass is not changed.
	 * @param rowLimit The most issues to return: 1 or more.
	 *
	 * @return The issues found, newest first. An empty list when the set holds no value; then no query is run.
	 *
	 * @throws IllegalArgumentException When values is null, or rowLimit is null or less than 1.
	 *
	 * @since 1.12
	 *
	 * @example
	 * ```apex
	 * List<ApiIssue__c> issues = new SEL_ApiIssue().findByTriggeringRecordValues(new Set<String> {'ORD-99182'}, 10);
	 * ```
	 */
	global List<ApiIssue__c> findByTriggeringRecordValues(Set<String> values, Integer rowLimit)
	{
		Set<String> searchValues = SEL_ApiCall.getSearchValuesForTextValues(values, rowLimit);
		return searchValues.isEmpty() ? new List<ApiIssue__c>() : queryByTriggeringRecordIndex(searchValues, rowLimit);
	}

	/**
	 * @description The one query of the finders by triggering record. It runs with the running user's object, field and
	 * sharing access (user mode), which replaces the system mode this selector uses for its other reads.
	 *
	 * @param searchValues The values to look for, none null or blank
	 * @param rowLimit The most rows to return
	 *
	 * @return The issues whose Triggering Record Index matches one of the values, ignoring case, newest first. In a test,
	 * the mocked issues whose Triggering Record Index matches exactly, cut to the row limit.
	 */
	private List<ApiIssue__c> queryByTriggeringRecordIndex(Set<String> searchValues, Integer rowLimit)
	{
		return query
				.withUserMode()
				.onlyFields(SUMMARY_FIELDS)
				.condition(ApiIssue__c.TriggeringRecordIndex__c).isIn(new List<String>(searchValues))
				.orderBy(ApiIssue__c.CreatedDate).descending()
				.orderBy(ApiIssue__c.Id).descending()
				.withLimit(rowLimit)
				.toList();
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
	 * @description Finds every user's open issues for one request whose Triggering Record Id field holds the given text,
	 * such as an order number from another system. It matches the same service name and request parameters
	 * hash as findByFailedApiCall, and compares the issue's Triggering Record Id field with the text you pass.
	 *
	 * The match is exact, upper and lower case included: 'AB1' does not find the issue of 'ab1'. The database ignores case
	 * when it compares text, so the method drops the rows that differ only in case after the read. A blank value finds the
	 * open issues whose Triggering Record Id field is blank.
	 *
	 * Some values of exactly 15 letters and digits are accepted as a record Id in its short form. The framework checks such
	 * a value both ways. It looks for the record Id with findByFailedApiCall, and for the same 15 characters with this
	 * method.
	 *
	 * It reads the Triggering Record Id field itself, not Triggering Record Index. Issues saved before Triggering Record
	 * Index existed may have that field blank.
	 *
	 * The method reads in system mode and ignores record sharing, for the same reason as findByFailedApiCall. The
	 * framework uses it to resolve the open issues of a request when a later call for the same request succeeds.
	 *
	 * @param triggeringRecordValue The text to look for in the issue's Triggering Record Id field
	 * @param serviceName The name of the web service
	 * @param hashParameter The request parameters hash to match
	 *
	 * @return The open issues for the request, whoever owns them
	 */
	public List<ApiIssue__c> findOpenByTriggeringRecordValue(String triggeringRecordValue, String serviceName, String hashParameter)
	{
		List<ApiIssue__c> sameTextIssues = new List<ApiIssue__c>();
		List<ApiIssue__c> openIssues = query
				.systemModeInternal()
				.bypassSharingInternal()
				.condition(ApiIssue__c.TriggeringRecordId__c).equals(triggeringRecordValue)
				.condition(ApiIssue__c.Status__c).equals(STATUS_OPEN)
				.condition(ApiIssue__c.ServiceName__c).equals(serviceName)
				.condition(ApiIssue__c.RequestParametersHash__c).equals(hashParameter)
				.withLimit(UTIL_Limits.dmlRows().maximum())
				.toList();
		for(ApiIssue__c openIssue : openIssues)
		{
			if(String.isBlank(triggeringRecordValue) || triggeringRecordValue.equals(openIssue.TriggeringRecordId__c))
			{
				sameTextIssues.add(openIssue);
			}
		}
		return sameTextIssues;
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
	 * @description Finds the open outbound issues, whoever owns them, of the given services, records and request
	 * parameters hashes. An issue with no direction counts as outbound.
	 *
	 * Retry Selected and the bulk retry use it to find the open issues of each request that the operator did not select,
	 * or cannot see, and check them before they send the request.
	 *
	 * Each filter is checked on its own, so an issue can match one request's service and another request's hash. The
	 * caller keeps only the issues of its own requests.
	 *
	 * The records are matched on the triggering record ID field. A blank value in the list matches an issue with no
	 * triggering record.
	 *
	 * The method reads in system mode and ignores record sharing. API issues are private, so a read with the running
	 * user's sharing would miss the issues that user cannot see. A request could then be sent again although another of
	 * its open issues says it must not be.
	 *
	 * The rows are never shown to anyone: they only hold a request back. It reads only the fields the checks need. If
	 * the requests have more open issues than the transaction can still read, the read fails and nothing is sent.
	 *
	 * @param serviceNames The services the requests were sent to
	 * @param requestParametersHashes The request parameters hashes of the requests
	 * @param triggeringRecordValues The triggering record IDs of the requests; a blank value matches an issue with no record
	 *
	 * @return The open outbound issues found, whoever owns them
	 */
	public List<ApiIssue__c> findOpenOutboundByRequestParametersHashes(Set<String> serviceNames, Set<String> requestParametersHashes, Set<String> triggeringRecordValues)
	{
		return query
				.systemModeInternal()
				.bypassSharingInternal()
				.onlyFields(new List<SObjectField>
				{
						ApiIssue__c.ApiCall__c,
						ApiIssue__c.Direction__c,
						ApiIssue__c.ExternalSystemMayHaveActed__c,
						ApiIssue__c.IdempotencyKey__c,
						ApiIssue__c.RequestParametersHash__c,
						ApiIssue__c.ServiceName__c,
						ApiIssue__c.Status__c,
						ApiIssue__c.TriggeringRecordId__c
				})
				.condition(ApiIssue__c.Status__c).equals(STATUS_OPEN)
				.condition(ApiIssue__c.Direction__c).notEquals(DIRECTION_INBOUND)
				.condition(ApiIssue__c.ServiceName__c).isIn(new List<String>(serviceNames))
				.condition(ApiIssue__c.RequestParametersHash__c).isIn(new List<String>(requestParametersHashes))
				.condition(ApiIssue__c.TriggeringRecordId__c).isIn(new List<String>(triggeringRecordValues))
				.withLimit(UTIL_Limits.soqlQueryRows().maximum())
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
	 * @description Builds a read of the API Call field of every open issue, to use inside another query, for example to
	 * leave out the calls that still have an open issue. It selects one field.
	 *
	 * It names system mode only because every framework query must name an access mode (whether the running user's object
	 * and field permissions are checked). The choice changes nothing here: this query is sent as part of the outer query, so
	 * it always runs with the access mode of the outer query.
	 *
	 * @return The read, ready to pass to isIn or notIn of another query.
	 *
	 * @see UTIL_PurgeRecords.buildPurgeQuery
	 */
	public static QRY_Builder.Builder buildApiCallsWithOpenIssueSubquery()
	{
		return QRY_Builder.selectFrom(ApiIssue__c.SObjectType)
				.systemModeInternal()
				.fields(new List<SObjectField> {ApiIssue__c.ApiCall__c})
				.condition(ApiIssue__c.Status__c).equals(STATUS_OPEN);
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