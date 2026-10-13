/**
 * Upgrade leg (a), last step: delete the log entry the baseline call wrote, and prove none is left
 *
 * Run at least 30 seconds after upgrade-stranded-call-baseline.apex. The log entry is written by the Automated Process
 * user from a platform event, so it is not filtered by creator.
 *
 * Run:
 *   sf apex run --file release-testing/scripts/upgrade-stranded-call-log-cleanup.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */
List<kern__LogEntry__c> baselineLogs = [SELECT Id FROM kern__LogEntry__c WHERE kern__ShortMessage__c LIKE '%Baseline17DoesNotExist%' OR kern__ClassMethod__c LIKE '%Baseline17%'];
delete baselineLogs;
System.debug(LoggingLevel.ERROR, 'BASELINE17 log entries deleted=' + baselineLogs.size() + ' left='
		+ [SELECT COUNT() FROM kern__LogEntry__c WHERE kern__ShortMessage__c LIKE '%Baseline17DoesNotExist%' OR kern__ClassMethod__c LIKE '%Baseline17%']);
