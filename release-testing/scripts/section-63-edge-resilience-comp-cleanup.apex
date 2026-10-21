/**
 * Section 63 cleanup: the log entries section 63 wrote
 *
 * Run 30 seconds after section-63-edge-resilience-comp.apex. Its failed call and its circuit breakers write log entries
 * from a platform event after the section's own transaction ends, so the section cannot delete them itself. This script
 * deletes every API_EchoSubscriber log entry and every log entry naming one of the section's S63_ circuit breakers of
 * today (written by the Automated Process user, so not filtered by creator), with the calls and issues of the service
 * the running user created today, then proves by query that none is left. When rows are left it prints a FAIL line and
 * does not throw: a throw would roll back the deletes it did make.
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-63-edge-resilience-comp-cleanup.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

final String SERVICE_NAME = API_EchoSubscriber.class.getName();
final String LOG_PATTERN = '%' + SERVICE_NAME + '%';
final String CIRCUIT_LOG_PATTERN = '%S63_%';
final Id RUNNING_USER_ID = UserInfo.getUserId();

delete [SELECT Id FROM kern__LogEntry__c WHERE (kern__ClassMethod__c LIKE :LOG_PATTERN OR kern__ShortMessage__c LIKE :CIRCUIT_LOG_PATTERN) AND CreatedDate = TODAY LIMIT 9000];
List<kern__ApiCall__c> calls = [SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SERVICE_NAME AND CreatedDate = TODAY AND CreatedById = :RUNNING_USER_ID LIMIT 9000];
// The issues first: a call with an Open issue cannot be deleted, so the issues of these calls go too, whoever wrote them.
delete [SELECT Id FROM kern__ApiIssue__c WHERE (kern__ServiceName__c = :SERVICE_NAME AND CreatedDate = TODAY AND CreatedById = :RUNNING_USER_ID)
		OR kern__ApiCall__c IN :calls LIMIT 9000];
delete calls;

Integer logEntriesLeft = [SELECT COUNT() FROM kern__LogEntry__c
		WHERE (kern__ClassMethod__c LIKE :LOG_PATTERN OR kern__ShortMessage__c LIKE :CIRCUIT_LOG_PATTERN) AND CreatedDate = TODAY];
Integer issuesLeft = [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :SERVICE_NAME AND CreatedDate = TODAY AND CreatedById = :RUNNING_USER_ID];
Integer callsLeft = [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SERVICE_NAME AND CreatedDate = TODAY AND CreatedById = :RUNNING_USER_ID];
if(logEntriesLeft + issuesLeft + callsLeft == 0)
{
	System.debug('63-cleanup PASS: no API_EchoSubscriber or S63_ circuit log entry, issue or call of today is left');
}
else
{
	System.debug('63-cleanup FAIL: left behind: ' + logEntriesLeft + ' log entries, ' + issuesLeft + ' issues, ' + callsLeft + ' calls');
}
