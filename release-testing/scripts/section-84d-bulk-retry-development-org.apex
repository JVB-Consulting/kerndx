/**
 * Section 84d: the bulk retry of one service's API issues, live (development org)
 *
 * This section starts the bulk retry through CTRL_RetryApiIssue.scheduleBulkRetry(service, delay), the form that retries
 * every open issue of one service. That form is not global, so a subscriber org cannot call it; the section runs on the
 * development org (the no-namespace copy, with the kern. and kern__ prefixes stripped). A subscriber org starts the same
 * background job for the issues it selects through the global Flow action kern.FLOW_RetryApiIssues.retryApiIssues;
 * section 86 runs that on the subscriber org, at volume. This section seeds three Open issues for API_RetryLiveGet, the
 * third marked External System May Have Acted, and schedules the bulk retry for the service. The job runs in its own
 * transaction; section 84e reads what it did:
 *   - every issue it retried was sent as one batch, so no callout was refused for work left pending by an earlier item;
 *   - the marked issue was skipped and stays Open, and the skip is logged.
 *
 * Run-isolation: refuses to start while RetryLive rows are left (run section 84b or 84e to delete them).
 *
 * Prerequisites:
 *   - the development org, with the no-namespace copies of API_RetryLiveGet and its settings deployed
 *   - the running user holds the Retry API Issue permission (the Kern Administrator set grants it)
 *
 * Run:
 *   sf apex run --file <no-namespace copy of this file> -o <your development org alias>
 *   then, 30 seconds later, the no-namespace copy of section-84e-bulk-retry-development-org-verify.apex
 */

final String SERVICE_GET = API_RetryLiveGet.class.getName();
final String ROW_PATTERN = '%RetryLive%';
final Integer SEEDED_ISSUES = 3;

Integer leftoverRows = [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN]
		+ [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN];
if(leftoverRows > 0)
{
	throw new System.AssertException('Section 84d: ' + leftoverRows + ' RetryLive rows are left; run section 84b or 84e to delete them first');
}
kern.UTIL_CircuitBreaker.monitor(SERVICE_GET).reset();

List<kern__ApiIssue__c> issues = new List<kern__ApiIssue__c>();
for(Integer index = 0; index < SEEDED_ISSUES; index++)
{
	issues.add(new kern__ApiIssue__c(
			kern__ServiceName__c = SERVICE_GET,
			kern__Status__c = 'Open',
			kern__Direction__c = 'Outbound',
			kern__RequestParametersHash__c = kern.UTIL_Random.randomAlphanumeric(20),
			kern__ExternalSystemMayHaveActed__c = index == SEEDED_ISSUES - 1
	));
}
insert issues;

Id jobId = kern.CTRL_RetryApiIssue.scheduleBulkRetry(SERVICE_GET, 0);
System.debug('SECTION84 ' + (jobId != null ? 'PASS' : 'FAIL') + ' 84d: seeded ' + SEEDED_ISSUES + ' issues (one marked) and scheduled the bulk retry, job ' + jobId
		+ '. Run section-84e-bulk-retry-development-org-verify.apex 30 seconds from now.');
