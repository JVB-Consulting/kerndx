/**
 * Section 84 log cleanup: the log entries sections 84 to 84e wrote
 *
 * Run 30 seconds after section 84b (and, on the development org, 30 seconds after 84e). The handlers, the circuit
 * breakers and their resets write log entries from a platform event after each script's transaction ends, so the
 * verify scripts cannot prove them gone themselves. This script deletes every log entry whose location or message
 * names RetryLive (written by the Automated Process user, so not filtered by creator), then proves by query that none
 * is left. It resets nothing, so it writes no log entry of its own.
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-84-outbound-retry-live-log-cleanup.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

final String ROW_PATTERN = '%RetryLive%';

List<kern__LogEntry__c> logEntries = [SELECT Id FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE :ROW_PATTERN OR kern__ShortMessage__c LIKE :ROW_PATTERN];
delete logEntries;

Integer logEntriesLeft = [SELECT COUNT() FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE :ROW_PATTERN OR kern__ShortMessage__c LIKE :ROW_PATTERN];
if(logEntriesLeft == 0)
{
	System.debug('SECTION84 PASS 84-log-cleanup: deleted ' + logEntries.size() + ' RetryLive log entries; none is left');
}
else
{
	System.debug('SECTION84 FAIL 84-log-cleanup: ' + logEntriesLeft + ' RetryLive log entries left behind');
}
