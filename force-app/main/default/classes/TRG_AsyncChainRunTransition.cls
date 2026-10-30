// SPDX-License-Identifier: Apache-2.0
/**
 * @description Refuses a change to a chain run that the engine would never make. Runs before every insert and every
 * update of AsyncChainExecution__c.
 *
 * The engine (UTIL_AsyncChain.applyRunTransition) is the only code that decides how a chain run moves from one status
 * to another. This trigger action makes none of those decisions. It checks each row being saved against two things
 * the engine already defines, and blocks the save when either fails.
 *
 * First, the move itself: a status change is allowed only when UTIL_AsyncChain.isAllowedRunTransition says so.
 * Second, the shape of the row after the save: a Stalled run has no end time and no duration; a Completed, Failed or
 * Aborted run has an end time and no active deduplication key; an end time never changes once it is set; a Running run
 * has no end time and no failure category; a Failed or Aborted run has a failure category.
 *
 * An update is checked only when its status or its end time changes. A row whose status stays the same can still have
 * its other fields edited, even when it already breaks one of the rules above. A new row is accepted in any of the five
 * statuses the engine writes, as long as its fields fit that status. Any other status, including Delayed, is refused.
 *
 * A refusal fails the save with the AsyncChain_TransitionRefused message (AsyncChain_BirthRefused for a new row) and
 * writes one ERROR log entry that starts with a fixed phrase, so refusals can be counted. The action works in memory
 * only: no query, no DML.
 *
 * @see UTIL_AsyncChain
 * @see TRG_AsyncChainRunTransition_TEST
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date October 2026
 */
@SuppressWarnings('ApexUnusedDeclaration,RedundantSuppression')
public inherited sharing class TRG_AsyncChainRunTransition extends TRG_Base implements IF_Trigger.BeforeInsert, IF_Trigger.BeforeUpdate
{
	/**
	 * @description This class's name, the first half of the location every refusal is logged at.
	 */
	private static final String CLASS_NAME = TRG_AsyncChainRunTransition.class.getName();

	/**
	 * @description The method name a refusal of a new row is logged at.
	 */
	private static final String METHOD_BEFORE_INSERT = 'beforeInsert';

	/**
	 * @description The method name a refusal of an update is logged at.
	 */
	private static final String METHOD_BEFORE_UPDATE = 'beforeUpdate';

	/**
	 * @description The fixed words every refusal log starts with, so refusals can be counted by the start of the log's
	 * short message.
	 */
	private static final String REFUSAL_LOG_PREFIX = 'Chain run status write refused by the backstop: ';

	/**
	 * @description The words that name the status a new row was given in a refusal log, before that status.
	 */
	private static final String NEW_ROW_STATUS_PREFIX = 'a new row in ';

	/**
	 * @description The words between the status a row has now and the status asked for, in a refusal log.
	 */
	private static final String STATUS_MOVE_SEPARATOR = ' to ';

	/**
	 * @description The text between the status move and the reason, in a refusal log.
	 */
	private static final String REASON_SEPARATOR = '; ';

	/**
	 * @description Logged when the status change is not one the engine ever makes.
	 */
	private static final String REASON_NOT_IN_TABLE = 'the engine never moves a run this way';

	/**
	 * @description Logged when a Stalled row carries an end time or a duration.
	 */
	private static final String REASON_STALLED_FIELDS = 'a Stalled run cannot have an end time or a duration';

	/**
	 * @description Logged when a Completed, Failed or Aborted row has no end time, or still holds an active deduplication key.
	 */
	private static final String REASON_FINISHED_FIELDS = 'a finished run must have an end time and no active deduplication key';

	/**
	 * @description Logged when an end time that was already set is changed to another value.
	 */
	private static final String REASON_END_TIME_CHANGED = 'an end time cannot change once it is set';

	/**
	 * @description Logged when a Running row carries an end time or a failure category.
	 */
	private static final String REASON_RUNNING_FIELDS = 'a Running run cannot have an end time or a failure category';

	/**
	 * @description Logged when a Failed or Aborted row has no failure category.
	 */
	private static final String REASON_NO_FAILURE_CATEGORY = 'a Failed or Aborted run must have a failure category';

	/**
	 * @description Logged when the status is not one of the five the engine writes. Delayed is one such status.
	 */
	private static final String REASON_STATUS_NOT_WRITTEN = 'the status is not one the engine writes';

	/**
	 * @description Checks every new row. A row is refused when its status is not one the engine writes, or when its
	 * fields do not fit its status.
	 *
	 * @param newRecords The chain run rows about to be inserted.
	 */
	public void beforeInsert(List<SObject> newRecords)
	{
		for(SObject record : newRecords)
		{
			AsyncChainExecution__c newRecord = (AsyncChainExecution__c)record;
			String reason = findInvariantBreach(newRecord);
			if(reason != null)
			{
				refuse(newRecord, null, reason);
			}
		}
	}

	/**
	 * @description Checks every updated row. A row is refused when its status change is one the engine never makes, or
	 * when its fields will not fit its status after the save. A row whose status and end time both stay as they were is
	 * left alone.
	 *
	 * @param newRecords The chain run rows with their new field values.
	 * @param oldRecords The same rows as they read before the update, in the same order.
	 */
	public void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords)
	{
		for(Integer index = 0; index < newRecords.size(); index++)
		{
			AsyncChainExecution__c newRecord = (AsyncChainExecution__c)newRecords[index];
			AsyncChainExecution__c oldRecord = (AsyncChainExecution__c)oldRecords[index];
			String reason = findUpdateRefusal(newRecord, oldRecord);
			if(reason != null)
			{
				refuse(newRecord, oldRecord, reason);
			}
		}
	}

	/**
	 * @description Decides whether one update is refused. Nothing is checked unless the status or the end time changes.
	 * A changed status must be a move the engine makes. An end time that was already set must not change. Then the row
	 * must fit its status.
	 *
	 * @param newRecord The row with its new field values.
	 * @param oldRecord The row as it read before the update.
	 *
	 * @return Why the update is refused, or null when it is allowed.
	 */
	private static String findUpdateRefusal(AsyncChainExecution__c newRecord, AsyncChainExecution__c oldRecord)
	{
		Boolean statusChanged = newRecord.Status__c != oldRecord.Status__c;
		Boolean endTimeChanged = newRecord.CompletedAt__c != oldRecord.CompletedAt__c;
		if(!statusChanged && !endTimeChanged)
		{
			return null;
		}
		if(statusChanged && !UTIL_AsyncChain.isAllowedRunTransition(oldRecord.Status__c, newRecord.Status__c))
		{
			return REASON_NOT_IN_TABLE;
		}
		if(endTimeChanged && oldRecord.CompletedAt__c != null && newRecord.CompletedAt__c != null)
		{
			return REASON_END_TIME_CHANGED;
		}
		return findInvariantBreach(newRecord);
	}

	/**
	 * @description Checks that the row's fields fit its status. A Running or Stalled row is checked as an unfinished run,
	 * a Completed, Failed or Aborted row as a finished run. Any other status is refused on its own.
	 *
	 * @param record The row as it will read after the save.
	 *
	 * @return Why the row does not fit its status, or null when it does.
	 */
	private static String findInvariantBreach(AsyncChainExecution__c record)
	{
		String status = record.Status__c;
		if(status == SEL_AsyncChainExecution.STATUS_RUNNING || status == SEL_AsyncChainExecution.STATUS_STALLED)
		{
			return findUnfinishedBreach(record);
		}
		if(status == SEL_AsyncChainExecution.STATUS_COMPLETED || status == SEL_AsyncChainExecution.STATUS_FAILED || status == SEL_AsyncChainExecution.STATUS_ABORTED)
		{
			return findFinishedBreach(record);
		}
		return REASON_STATUS_NOT_WRITTEN;
	}

	/**
	 * @description Checks a Running or Stalled row. Neither may have an end time. A Running row may not have a failure
	 * category. A Stalled row may not have a duration.
	 *
	 * @param record The row as it will read after the save, Running or Stalled.
	 *
	 * @return Why the row does not fit its status, or null when it does.
	 */
	private static String findUnfinishedBreach(AsyncChainExecution__c record)
	{
		Boolean running = record.Status__c == SEL_AsyncChainExecution.STATUS_RUNNING;
		Boolean secondFieldClear = running ? record.FailureCategory__c == null : record.DurationMs__c == null;
		if(record.CompletedAt__c == null && secondFieldClear)
		{
			return null;
		}
		return running ? REASON_RUNNING_FIELDS : REASON_STALLED_FIELDS;
	}

	/**
	 * @description Checks a Completed, Failed or Aborted row. Every finished row must have an end time and no active
	 * deduplication key. A Failed or Aborted row must also have a failure category.
	 *
	 * @param record The row as it will read after the save, Completed, Failed or Aborted.
	 *
	 * @return Why the row does not fit its status, or null when it does.
	 */
	private static String findFinishedBreach(AsyncChainExecution__c record)
	{
		if(record.CompletedAt__c == null || record.ActiveDeduplicationKey__c != null)
		{
			return REASON_FINISHED_FIELDS;
		}
		Boolean needsFailureCategory = record.Status__c == SEL_AsyncChainExecution.STATUS_FAILED || record.Status__c == SEL_AsyncChainExecution.STATUS_ABORTED;
		return needsFailureCategory && record.FailureCategory__c == null ? REASON_NO_FAILURE_CATEGORY : null;
	}

	/**
	 * @description Blocks the save of one row. An update gets the AsyncChain_TransitionRefused message, which names the
	 * status the row has now and the status asked for. A new row gets the AsyncChain_BirthRefused message, which names
	 * the status it was given. One ERROR log entry is written as well. It starts with the fixed words every refusal
	 * shares, then names the statuses and the reason, and is placed at beforeUpdate or at beforeInsert.
	 *
	 * @param newRecord The row being refused. Its Status__c is the status asked for.
	 * @param oldRecord The row as it read before the update, or null for a new row.
	 * @param reason Why the row is refused, in words, for the log.
	 */
	private static void refuse(AsyncChainExecution__c newRecord, AsyncChainExecution__c oldRecord, String reason)
	{
		String newStatus = newRecord.Status__c;
		Boolean isNewRow = oldRecord == null;
		String message = isNewRow
				? String.format(System.Label.AsyncChain_BirthRefused, new List<String> {newStatus})
				: String.format(System.Label.AsyncChain_TransitionRefused, new List<String> {oldRecord.Status__c, newStatus});
		String statusMove = isNewRow ? NEW_ROW_STATUS_PREFIX + newStatus : oldRecord.Status__c + STATUS_MOVE_SEPARATOR + newStatus;
		newRecord.addError(message);
		LOG_Builder.build().error(REFUSAL_LOG_PREFIX + statusMove + REASON_SEPARATOR + reason)
				.at(CLASS_NAME + '.' + (isNewRow ? METHOD_BEFORE_INSERT : METHOD_BEFORE_UPDATE))
				.forRecord(newRecord.Id)
				.emit();
	}
}
