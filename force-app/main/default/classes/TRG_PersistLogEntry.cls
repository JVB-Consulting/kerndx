// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Trigger action on the Log Entry Platform Event; creates LogEntry__c records from platform events.
 * Originally adapted from [ApexLogger](https://github.com/mlockett/ApexLogger).
 *
 * @see TRG_PersistLogEntry_TEST
 * @see TRG_Base
 * @see IF_Trigger
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date January 2026, May 2026
 */
@SuppressWarnings('ApexUnusedDeclaration')
public inherited sharing class TRG_PersistLogEntry extends TRG_Base implements IF_Trigger.AfterInsert
{
	/**
	 * @description Will ensure that the events raised are logged to the LogEntry__c object.
	 *
	 * @param newRecords The platform events being inserted.
	 */
	public void afterInsert(List<SObject> newRecords)
	{
		List<LogEntry__c> entriesToInsert = new List<LogEntry__c>();

		for(SObject record : newRecords)
		{
			LogEntryEvent__e event = (LogEntryEvent__e)record;

			LogEntry__c logEntry = new LogEntry__c();

			logEntry.ClassMethod__c = UTIL_String.abbreviate(event.ClassMethod__c, LogEntry__c.ClassMethod__c);
			logEntry.ContextData__c = UTIL_String.abbreviate(event.ContextData__c, LogEntry__c.ContextData__c);
			logEntry.CorrelationId__c = UTIL_String.abbreviate(event.CorrelationId__c, LogEntry__c.CorrelationId__c);
			logEntry.DurationMs__c = event.DurationMs__c;
			logEntry.ExceptionType__c = UTIL_String.abbreviate(event.ExceptionType__c, LogEntry__c.ExceptionType__c);
			logEntry.ExecutionEvent__c = event.ExecutionEvent__c;
			logEntry.Limits__c = UTIL_String.abbreviate(event.Limits__c, LogEntry__c.Limits__c);
			logEntry.LineNumber__c = event.LineNumber__c;
			logEntry.LogLevel__c = event.LogLevel__c;
			logEntry.Message__c = UTIL_String.abbreviate(event.Message__c, LogEntry__c.Message__c);
			logEntry.ParentTransactionId__c = UTIL_String.abbreviate(event.ParentTransactionId__c, LogEntry__c.ParentTransactionId__c);
			logEntry.RecordId__c = UTIL_String.abbreviate(event.RecordId__c, LogEntry__c.RecordId__c);
			logEntry.ShortMessage__c = UTIL_String.abbreviate(event.ShortMessage__c, LogEntry__c.ShortMessage__c);
			logEntry.StackTrace__c = UTIL_String.abbreviate(event.StackTrace__c, LogEntry__c.StackTrace__c);
			logEntry.TransactionId__c = UTIL_String.abbreviate(event.TransactionId__c, LogEntry__c.TransactionId__c);
			logEntry.UserId__c = UTIL_String.abbreviate(event.UserId__c, LogEntry__c.UserId__c);

			entriesToInsert.add(logEntry);
		}

		DML_Builder.newTransaction().systemModeInternal().doInsert(entriesToInsert).execute();
	}
}