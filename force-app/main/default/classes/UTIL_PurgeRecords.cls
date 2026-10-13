// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Provides utility methods for purging records from Salesforce objects using adaptive async processing.
 * Automatically selects between Queueable and Batch execution based on data volume and governor limits.
 * Supports deleting all records or records older than a specified number of days.
 *
 * All entry points inherit the flag-driven default `AccessLevel` resolved by
 * `DML_SharingProxy.defaultAccessLevel()` — under the secure-by-default posture this is
 * `USER_MODE`, so the invoking user must have delete CRUD on the target object for the purge to
 * succeed. This is deliberate: `UTIL_PurgeRecords` is `global`, so any subscriber Apex caller can
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
 * @see PROC_ExecuteDML
 * @see UTIL_FeatureFlag
 * @see UTIL_PurgeRecords_TEST
 *
 * @author Jason van Beukering
 *
 * @group Bulk DML
 *
 * @date February 2026, October 2026
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
	 * System.debug('All Contact records deleted atomically');
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
	 * System.debug('All Lead records deleted in batches of 200');
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
	 * System.debug('Deleted Task records older than 30 days');
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
	 * System.debug('Deleted Opportunity records older than 180 days in batches of 100');
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

		QRY_Condition.Evaluable searchConditions = new QRY_Condition.FieldCondition(
				String.isBlank(dateFieldApiName) ? 'CreatedDate' : dateFieldApiName
		).lessThan(new QRY_Condition.DateLiteral().last(daysThreshold - 1, QRY_Condition.UnitOfTime.DAY));

		IF_Queryable queryable = buildPurgeQuery(objectApiName, searchConditions);

		UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
				new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(queryable)
						.withBatchSize(batchSize);

		UTIL_AsynchronousJobLauncher.process(request, new PROC_ExecuteDML(DML_Builder.DatabaseOperation.DML_DELETE, allOrNothing));
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
	 * @param objectApiName The API name of the object to purge.
	 * @param entryName The name of the purge entry that was called, logged as the location.
	 *
	 * @return True when the purge may go ahead, false when it is skipped.
	 */
	private static Boolean canPurge(String objectApiName, String entryName)
	{
		SObjectType objectType = UTIL_SObjectDescribe.getSObjectTypeByName(objectApiName);
		Boolean isApiRecord = objectType == ApiCall__c.SObjectType || objectType == ApiIssue__c.SObjectType;
		if(!isApiRecord || UTIL_FeatureFlag.isEnabled(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD))
		{
			return true;
		}
		LOG_Builder.build().warn(System.Label.DeleteApiRecords_PermissionRequired).emitAt(UTIL_PurgeRecords.class.getName() + '/' + entryName);
		return false;
	}

	/**
	 * @description Builds a queryable for the purge operation.
	 *
	 * @param objectApiName The API name of the SObject to query.
	 * @param searchConditions Optional conditions to filter records.
	 *
	 * @return An IF_Queryable instance for retrieving records to delete.
	 */
	private static IF_Queryable buildPurgeQuery(String objectApiName, QRY_Condition.Evaluable searchConditions)
	{
		QRY_Builder.Builder query = QRY_Builder.selectFrom(UTIL_SObjectDescribe.getSObjectTypeByName(objectApiName))
				.fields(new List<String>(SEARCH_FIELDS));

		if(searchConditions != null)
		{
			query.addCondition(searchConditions);
		}

		return query;
	}
}