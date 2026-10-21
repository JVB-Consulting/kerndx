/**
 * Section 60 cleanup: the issues and calls section 60 left
 *
 * Run 30 seconds after section-60-edge-mock-regex.apex. The section registers answers with statuses 211, 212, 221 and 222.
 * None of them is a success status, so each call is recorded as failed and opens an issue that the section does not
 * delete. This script deletes every API_EchoSubscriber issue and call of today created by the running user, with any
 * log entry of the service, then proves by query that none is left. When rows are left it prints a FAIL line and does
 * not throw: a throw would roll back the deletes it did make.
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-60-edge-mock-regex-cleanup.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

final String SERVICE_NAME = API_EchoSubscriber.class.getName();
final String LOG_PATTERN = '%' + SERVICE_NAME + '%';
final Id RUNNING_USER_ID = UserInfo.getUserId();

delete [SELECT Id FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE :LOG_PATTERN AND CreatedDate = TODAY LIMIT 9000];
List<kern__ApiCall__c> calls = [SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SERVICE_NAME AND CreatedDate = TODAY AND CreatedById = :RUNNING_USER_ID LIMIT 9000];
// The issues first: a call with an Open issue cannot be deleted, so the issues of these calls go too, whoever wrote them.
delete [SELECT Id FROM kern__ApiIssue__c WHERE (kern__ServiceName__c = :SERVICE_NAME AND CreatedDate = TODAY AND CreatedById = :RUNNING_USER_ID)
		OR kern__ApiCall__c IN :calls LIMIT 9000];
delete calls;

Integer logEntriesLeft = [SELECT COUNT() FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE :LOG_PATTERN AND CreatedDate = TODAY];
Integer issuesLeft = [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :SERVICE_NAME AND CreatedDate = TODAY AND CreatedById = :RUNNING_USER_ID];
Integer callsLeft = [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SERVICE_NAME AND CreatedDate = TODAY AND CreatedById = :RUNNING_USER_ID];
if(logEntriesLeft + issuesLeft + callsLeft == 0)
{
	System.debug('60-cleanup PASS: no API_EchoSubscriber log entry, issue or call of today is left');
}
else
{
	System.debug('60-cleanup FAIL: left behind: ' + logEntriesLeft + ' log entries, ' + issuesLeft + ' issues, ' + callsLeft + ' calls');
}
