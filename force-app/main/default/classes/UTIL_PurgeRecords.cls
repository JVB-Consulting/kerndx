// SPDX-License-Identifier: Apache-2.0
/**
 * @description Provides utility methods for purging records from Salesforce objects using adaptive async processing.
 * Automatically selects between Queueable and Batch execution based on data volume and governor limits.
 * Supports deleting all records or records older than a specified number of days.
 *
 * All entry points inherit the flag-driven default `AccessLevel` resolved by
 * `DML_SharingProxy.defaultAccessLevel()` — under the secure-by-default posture this is
 * `USER_MODE`, so the invoking user must have delete CRUD on the target object for the purge to
 * succeed. This is deliberate: `UTIL_PurgeRecords` is `global`, so any Apex caller in your org can
 * reach it, and silently elevating to SYSTEM_MODE would let a low-privilege user destructively
 * delete records they have no native right to delete. Integrations that genuinely need admin-mandate
 * semantics (for example, cleanup utilities behind a custom permission gate) should construct a
 * `PROC_ExecuteDML(operation, allOrNothing, AccessLevel.SYSTEM_MODE)` explicitly and pair it with a
 * caller-side permission check; the framework declines to make that elevation implicit.
 *
 * API calls and API issues can be deleted only by a user the BypassApiRecordDeleteGuard feature flag is on for. A
 * built-in rule turns the flag on for every holder of the Delete API Records permission, which the Kern Administrator
 * permission set grants, and your org can widen it to more users. A purge of either, run by anyone else, deletes
 * nothing, starts no job and logs one warning that says so. Schedule such a purge as a user the flag is on for.
 *
 * A purge of API calls leaves out every call that still has an open API issue, because such a call is never deleted,
 * not even by an administrator. The purge reads as the user who runs it, so it leaves out such a call only when that user
 * can read every open issue. The Kern Administrator permission set gives this access. When the user cannot see the open
 * issue of a call, the delete guard refuses that call, one call at a time, and logs each refusal. A user who cannot read
 * API issues is told so in one warning, and the purge of API calls does not start. A call that is left out is purged by
 * a later run, once its issue is resolved or dismissed.
 *
 * A purge of chain runs (AsyncChainExecution__c) by their end time (CompletedAt__c) also deletes a run that stays
 * Stalled, when the time it stalled (StalledAt__c) is older than the same number of days. A Stalled run never gets an
 * end time, so without this rule it would be kept forever. The user who runs the purge must be able to read both the
 * Status and the Stalled At fields of a chain run; the Kern Administrator permission set gives this access. An upgrade
 * does not give a new field to profiles or to permission sets your org made itself. Without that access, the purge
 * deletes by end time only, so every stalled run is kept, and it logs one warning that says so.
 *
 * @see PROC_ExecuteDML
 * @see UTIL_FeatureFlag
 * @see UTIL_PurgeRecords_TEST
 *
 * @author Jason van Beukering
 *
 * @group Bulk DML
 *
 * @date February 2026, November 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * UTIL_PurgeRecords.deleteAllRecords(LogEntry__c.SObjectType);
 * UTIL_PurgeRecords.deleteOlderThanNDays('LogEntry__c', 90);
 * UTIL_PurgeRecords.deleteOlderThanNDays('Task', 'CreatedDate', 30, false, 200);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity,PMD.AvoidBooleanMethodParameters')
global inherited sharing class UTIL_PurgeRecords
{
	/**
	 * @description Fields to query for deletion (only Id is needed).
	 */
	private static final Set<String> SEARCH_FIELDS = new Set<String> {'Id'};

	/**
	 * @description Deletes all records of the specified SObject type with default non-atomic behavior.
	 *
	 * @param sObjectType The SObject type containing records to delete.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_PurgeRecords.deleteAllRecords(Account.SObjectType);
	 * ```
	 */
	global static void deleteAllRecords(SObjectType sObjectType)
	{
		deleteAllRecords(sObjectType, false);
	}

	/**
	 * @description Deletes all records of the specified SObject type with specified atomicity.
	 *
	 * @param objectApiName The API name of the SObject containing the records to delete.
	 * @param isAtomic If true, ensures the entire operation is atomic; if false, allows partial deletes.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_PurgeRecords.deleteAllRecords('Contact', true);
	 * // An asynchronous job now deletes the Contact records, so they are not gone yet when this line runs.
	 * ```
	 */
	global static void deleteAllRecords(String objectApiName, Boolean isAtomic)
	{
		deleteAllRecords(objectApiName, isAtomic, null);
	}

	/**
	 * @description Deletes all records of the specified SObject type with default non-atomic behavior.
	 *
	 * @param objectApiName The API name of the SObject containing the records to delete.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_PurgeRecords.deleteAllRecords('Account');
	 * ```
	 */
	global static void deleteAllRecords(String objectApiName)
	{
		deleteAllRecords(objectApiName, false);
	}

	/**
	 * @description Deletes all records of the specified SObject type with configurable atomicity.
	 *
	 * @param sObjectType The SObject type containing records to delete.
	 * @param isAtomic If true, ensures the entire operation is atomic; if false, allows partial deletes.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_PurgeRecords.deleteAllRecords(Account.SObjectType, true);
	 * ```
	 */
	global static void deleteAllRecords(SObjectType sObjectType, Boolean isAtomic)
	{
		deleteAllRecords(UTIL_SObjectDescribe.getObjectNameFromType(sObjectType), isAtomic);
	}

	/**
	 * @description Deletes all records of the specified SObject type with customizable atomicity and batch size.
	 *
	 * @param objectApiName The API name of the SObject containing the records to delete.
	 * @param isAtomic If true, ensures the entire operation is atomic; if false, allows partial deletes.
	 * @param batchSize The size of each batch for processing records. Defaults to maximum batch size if null.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_PurgeRecords.deleteAllRecords('Lead', false, 200);
	 * // An asynchronous job now deletes the Lead records, 200 records in each batch.
	 * ```
	 */
	global static void deleteAllRecords(String objectApiName, Boolean isAtomic, Integer batchSize)
	{
		if(!canPurge(objectApiName, 'deleteAllRecords'))
		{
			return;
		}

		Boolean allOrNothing = isAtomic != null ? isAtomic : false;
		Integer effectiveBatchSize = batchSize != null ? batchSize : UTIL_SObjectDescribe.MAXIMUM_BATCH_SIZE;

		IF_Queryable queryable = buildPurgeQuery(objectApiName, null);

		UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
				new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(queryable)
						.withBatchSize(effectiveBatchSize);

		UTIL_AsynchronousJobLauncher.process(request, new PROC_ExecuteDML(DML_Builder.DatabaseOperation.DML_DELETE, allOrNothing));
	}

	/**
	 * @description Deletes records older than the specified number of days from the given SObject type,
	 * using CreatedDate as the default date field.
	 *
	 * @param objectApiName The API name of the SObject containing the records to delete.
	 * @param daysThreshold Records older than this number of days will be deleted.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_PurgeRecords.deleteOlderThanNDays('Task', 30);
	 * // An asynchronous job now deletes the Task records created more than 30 days ago.
	 * ```
	 */
	global static void deleteOlderThanNDays(String objectApiName, Integer daysThreshold)
	{
		deleteOlderThanNDays(objectApiName, null, daysThreshold);
	}

	/**
	 * @description Deletes records older than the specified number of days from the given SObject type,
	 * using CreatedDate as the default date field.
	 *
	 * @param sObjectType The SObject type containing records to delete.
	 * @param daysThreshold Records older than this number of days will be deleted.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_PurgeRecords.deleteOlderThanNDays(Task.SObjectType, 30);
	 * ```
	 */
	global static void deleteOlderThanNDays(SObjectType sObjectType, Integer daysThreshold)
	{
		deleteOlderThanNDays(UTIL_SObjectDescribe.getObjectNameFromType(sObjectType), daysThreshold);
	}

	/**
	 * @description Deletes records older than the specified number of days based on the specified date field.
	 *
	 * @param objectApiName The API name of the SObject containing the records to delete.
	 * @param dateFieldApiName The API name of the date field used for filtering records.
	 * @param daysThreshold Records with a date field value older than this number of days will be deleted.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_PurgeRecords.deleteOlderThanNDays('Task', 'CreatedDate', 30);
	 * ```
	 */
	global static void deleteOlderThanNDays(String objectApiName, String dateFieldApiName, Integer daysThreshold)
	{
		deleteOlderThanNDays(objectApiName, dateFieldApiName, daysThreshold, false);
	}

	/**
	 * @description Deletes records older than the specified number of days with configurable atomicity.
	 *
	 * @param objectApiName The API name of the SObject containing the records to delete.
	 * @param dateFieldApiName The API name of the date field used for filtering records.
	 * @param daysThreshold Records with a date field value older than this number of days will be deleted.
	 * @param isAtomic If true, ensures the entire operation is atomic; if false, allows partial deletes.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_PurgeRecords.deleteOlderThanNDays('Task', 'CreatedDate', 30, true);
	 * ```
	 */
	global static void deleteOlderThanNDays(String objectApiName, String dateFieldApiName, Integer daysThreshold, Boolean isAtomic)
	{
		deleteOlderThanNDays(objectApiName, dateFieldApiName, daysThreshold, isAtomic, UTIL_SObjectDescribe.MAXIMUM_BATCH_SIZE);
	}

	/**
	 * @description Deletes records older than the specified number of days with customizable date field, atomicity, and batch size.
	 *
	 * @param objectApiName The API name of the SObject containing the records to delete.
	 * @param dateFieldApiName The API name of the date field to filter records by. Defaults to CreatedDate if null.
	 * @param daysThreshold Records older than this number of days will be deleted.
	 * @param isAtomic If true, ensures the entire operation is atomic; if false, allows partial deletes.
	 * @param batchSize The size of each batch for processing records. Defaults to maximum batch size.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_PurgeRecords.deleteOlderThanNDays('Opportunity', 'CloseDate', 180, false, 100);
	 * // An asynchronous job now deletes the Opportunity records whose CloseDate is more than 180 days ago, 100 records in each batch.
	 * ```
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList,PMD.GlobalMethodParameterCap')
	global static void deleteOlderThanNDays
			(
					String objectApiName,
					String dateFieldApiName,
					Integer daysThreshold,
					Boolean isAtomic,
					Integer batchSize
			)
	{
		if(!canPurge(objectApiName, 'deleteOlderThanNDays'))
		{
			return;
		}

		Boolean allOrNothing = isAtomic != null ? isAtomic : false;

		String dateField = String.isBlank(dateFieldApiName) ? 'CreatedDate' : dateFieldApiName;
		QRY_Condition.Evaluable searchConditions = new QRY_Condition.FieldCondition(dateField).lessThan(buildAgeCutoff(daysThreshold));
		if(isChainRunPurgeByEndTime(objectApiName, dateField))
		{
			searchConditions = addStalledChainRunRule(searchConditions, daysThreshold);
		}

		IF_Queryable queryable = buildPurgeQuery(objectApiName, searchConditions);

		UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
				new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(queryable)
						.withBatchSize(batchSize);

		UTIL_AsynchronousJobLauncher.process(request, new PROC_ExecuteDML(DML_Builder.DatabaseOperation.DML_DELETE, allOrNothing));
	}

	/**
	 * @description Builds the cutoff of a purge of old records: a date more than the given number of days ago.
	 *
	 * @param daysThreshold Records older than this number of days are deleted.
	 *
	 * @return The date condition value that a date field must be earlier than.
	 */
	private static QRY_Condition.DateLiteral buildAgeCutoff(Integer daysThreshold)
	{
		return new QRY_Condition.DateLiteral().last(daysThreshold - 1, QRY_Condition.UnitOfTime.DAY);
	}

	/**
	 * @description Checks whether a purge of old records is a purge of chain runs by their end time (CompletedAt__c). A
	 * Stalled run has no end time, because it never finished, so such a purge would keep it forever. Such a purge also
	 * deletes old Stalled runs (see addStalledChainRunRule).
	 *
	 * @param objectApiName The API name of the object to purge.
	 * @param dateFieldApiName The API name of the date field the purge filters on.
	 *
	 * @return True when the purge is of chain runs by CompletedAt__c.
	 */
	private static Boolean isChainRunPurgeByEndTime(String objectApiName, String dateFieldApiName)
	{
		SObjectType objectType = UTIL_SObjectDescribe.getSObjectTypeByName(objectApiName);
		return objectType == AsyncChainExecution__c.SObjectType
				&& UTIL_SObjectDescribe.getDescribe(objectType).getField(dateFieldApiName) == AsyncChainExecution__c.CompletedAt__c;
	}

	/**
	 * @description Adds the rule for runs that stay Stalled to a purge of chain runs by their end time: the purge also
	 * deletes a Stalled run whose stall time (StalledAt__c) is older than the same number of days. A Stalled run with no
	 * stall time is kept.
	 *
	 * The purge reads as the user who runs it, and a query cannot filter on a field the user cannot read. When that user
	 * cannot read the Status or the Stalled At field of a chain run, the purge deletes by end time only, so every stalled
	 * run is kept. This logs one warning that says so and names the two fields the user needs. An upgrade does not give a
	 * new field to profiles or to permission sets your org made itself, so this warning is how such an org finds out.
	 *
	 * @param endTimeCondition The condition on the end time.
	 * @param daysThreshold Records older than this number of days are deleted.
	 *
	 * @return The condition on the end time or the stall time, or the condition on the end time alone when the user cannot
	 * read both fields.
	 */
	private static QRY_Condition.Evaluable addStalledChainRunRule(QRY_Condition.Evaluable endTimeCondition, Integer daysThreshold)
	{
		if(!canReadStallTimeFields())
		{
			LOG_Builder.build().warn(System.Label.PurgeChainRuns_StallTimeReadAccessRequired).emitAt(UTIL_PurgeRecords.class.getName() + '/deleteOlderThanNDays');
			return endTimeCondition;
		}
		return new QRY_Condition.OrCondition()
				.add(endTimeCondition)
				.add(new QRY_Condition.AndCondition()
						.add(new QRY_Condition.FieldCondition(AsyncChainExecution__c.Status__c).equals(SEL_AsyncChainExecution.STATUS_STALLED))
						.add(new QRY_Condition.FieldCondition(AsyncChainExecution__c.StalledAt__c).lessThan(buildAgeCutoff(daysThreshold))));
	}

	/**
	 * @description Checks whether the running user can read the Status and Stalled At fields of a chain run. The purge of
	 * chain runs needs both to find the runs that stay Stalled.
	 *
	 * @return True when the user can read both fields, false otherwise.
	 */
	private static Boolean canReadStallTimeFields()
	{
		return UTIL_SObjectDescribe.getCachedFieldDescribe(AsyncChainExecution__c.Status__c).isAccessible()
				&& UTIL_SObjectDescribe.getCachedFieldDescribe(AsyncChainExecution__c.StalledAt__c).isAccessible();
	}

	/**
	 * @description Checks whether the running user may purge the given object. Only API calls and API issues need a check:
	 * they can be deleted only by a user the BypassApiRecordDeleteGuard feature flag is on for, the same flag the delete
	 * guard (TRG_GuardApiRecordDeletion) answers to. A built-in rule turns the flag on for holders of the Delete API
	 * Records custom permission, which the Kern Administrator permission set grants. Without this check, a purge run by
	 * anyone else would be refused one row at a time and log an error for every row. So for a user the flag is off for,
	 * this logs one warning with the Delete API Records message, at the entry that was called, and the purge starts no
	 * job.
	 *
	 * A purge of API calls also needs read access to API issues and to their Status and API Call fields, because its
	 * query leaves out every call that still has an open issue, and that query runs as the user. Without this access the
	 * query would fail. So for such a user this logs one warning that says so, in the same way, and the purge starts no
	 * job.
	 *
	 * @param objectApiName The API name of the object to purge.
	 * @param entryName The name of the purge entry that was called, logged as the location.
	 *
	 * @return True when the purge may go ahead, false when it is skipped.
	 */
	private static Boolean canPurge(String objectApiName, String entryName)
	{
		SObjectType objectType = UTIL_SObjectDescribe.getSObjectTypeByName(objectApiName);
		Boolean isApiRecord = objectType == ApiCall__c.SObjectType || objectType == ApiIssue__c.SObjectType;
		String refusal;
		if(isApiRecord && !UTIL_FeatureFlag.isEnabled(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD))
		{
			refusal = System.Label.DeleteApiRecords_PermissionRequired;
		}
		else if(objectType == ApiCall__c.SObjectType && !canReadApiIssues())
		{
			refusal = System.Label.DeleteApiCalls_ApiIssueReadAccessRequired;
		}
		if(refusal == null)
		{
			return true;
		}
		LOG_Builder.build().warn(refusal).emitAt(UTIL_PurgeRecords.class.getName() + '/' + entryName);
		return false;
	}

	/**
	 * @description Checks whether the running user can read API issues and their Status and API Call fields. The purge of
	 * API calls needs all three to leave out the calls that still have an open issue.
	 *
	 * @return True when the user can read API issues and both fields, false otherwise.
	 */
	private static Boolean canReadApiIssues()
	{
		return UTIL_SObjectDescribe.isObjectAccessible(ApiIssue__c.SObjectType)
				&& UTIL_SObjectDescribe.getCachedFieldDescribe(ApiIssue__c.Status__c).isAccessible()
				&& UTIL_SObjectDescribe.getCachedFieldDescribe(ApiIssue__c.ApiCall__c).isAccessible();
	}

	/**
	 * @description Builds a queryable for the purge operation. For API calls it leaves out every call that still has an
	 * open issue: the delete guard (TRG_GuardApiCallWithOpenIssue) would refuse each of them, so the purge does not try.
	 * The query reads as the user who runs the purge, so it leaves out only the open issues that user can read. When the
	 * user cannot see the open issue of a call, the call stays in the query, and the delete guard refuses it and logs the
	 * refusal. Such a call is purged by a later run, once its issue is resolved or dismissed.
	 *
	 * @param objectApiName The API name of the SObject to query.
	 * @param searchConditions Optional conditions to filter records.
	 *
	 * @return An IF_Queryable instance for retrieving records to delete.
	 */
	private static IF_Queryable buildPurgeQuery(String objectApiName, QRY_Condition.Evaluable searchConditions)
	{
		SObjectType objectType = UTIL_SObjectDescribe.getSObjectTypeByName(objectApiName);
		QRY_Builder.Builder query = QRY_Builder.selectFrom(objectType)
				.fields(new List<String>(SEARCH_FIELDS));

		if(searchConditions != null)
		{
			query.addCondition(searchConditions);
		}

		if(objectType == ApiCall__c.SObjectType)
		{
			query.condition(ApiCall__c.Id).notIn(SEL_ApiIssue.buildApiCallsWithOpenIssueSubquery());
		}

		return query;
	}
}