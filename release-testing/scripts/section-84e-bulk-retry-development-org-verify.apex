/**
 * Section 84e: the bulk retry of one service's API issues, live (verify; development org)
 *
 * Runs where section 84d runs: the development org, because 84d starts the job through the per-service form that a
 * subscriber org cannot call. Section 86b verifies the same job on the subscriber org, started through the global Flow
 * action kern.FLOW_RetryApiIssues.retryApiIssues.
 *
 * Run 30 seconds after section 84d, before the retries the bulk job scheduled come due (60 seconds):
 *   84e-1. The bulk job sent one call for each of the two unmarked issues, and the org refused none of them for work
 *          left pending by an earlier item: no "refused before it left the org" warning was logged for the service, and,
 *          with an org cache allocated, the service's circuit breaker counted one failure for each call. A refused call
 *          counts no breaker failure, so the count shows both calls left the org even if a warning has not landed yet.
 *   84e-2. The marked issue was skipped: it stays Open, and the skip is logged at warn.
 * If the job has not made its two calls yet, the script prints SECTION84 PENDING, deletes nothing, and is run again.
 *
 * Cleanup (only once nothing is pending): resets the breaker, deletes every RetryLive call, issue and log entry and the
 * skip warning, then proves by query that no call, issue or skip warning is left. The RetryLive log entries (the reset
 * writes one, landing after this transaction) are proved by section-84-outbound-retry-live-log-cleanup.apex, run 30
 * seconds later.
 *
 * Run:
 *   sf apex run --file <no-namespace copy of this file> -o <your development org alias>
 */

final String SERVICE_GET = API_RetryLiveGet.class.getName();
final String ROW_PATTERN = '%RetryLive%';
final String REFUSED_PATTERN = '%refused before it left the org%';
final String SKIP_LOCATION_PATTERN = '%FailureReplayProcessor%';
final String SKIP_PATTERN = '%skipped%';
final Integer EXPECTED_CALLS = 2;
final Boolean IS_CACHE_ALLOCATED = kern.UTIL_Cache.isOrgAllocated();

List<kern__ApiCall__c> calls = [SELECT Id, kern__Status__c, kern__NextRetry__c FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SERVICE_GET];
List<kern__ApiIssue__c> markedIssues = [SELECT Id, kern__Status__c FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :SERVICE_GET AND kern__ExternalSystemMayHaveActed__c = true];
AggregateResult seeded = [SELECT MIN(CreatedDate) seededAt FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :SERVICE_GET];
Datetime seededAt = (Datetime)seeded.get('seededAt') ?? Datetime.now().addHours(-1);
List<kern__LogEntry__c> skipWarnings = [SELECT Id FROM kern__LogEntry__c
		WHERE kern__ClassMethod__c LIKE :SKIP_LOCATION_PATTERN AND kern__ShortMessage__c LIKE :SKIP_PATTERN AND CreatedDate >= :seededAt];

if(calls.size() < EXPECTED_CALLS || skipWarnings.isEmpty())
{
	System.debug('SECTION84 PENDING: the bulk job has made ' + calls.size() + ' of ' + EXPECTED_CALLS + ' calls and logged ' + skipWarnings.size() + ' skip warnings; '
			+ 'nothing was deleted. Run this script again in 30 seconds.');
}
else
{
	Integer refusedWarnings = [SELECT COUNT() FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE :ROW_PATTERN AND kern__ShortMessage__c LIKE :REFUSED_PATTERN];
	Integer breakerFailures = IS_CACHE_ALLOCATED ? kern.UTIL_CircuitBreaker.monitor(SERVICE_GET).getMetrics().failureCount : null;
	Boolean isOneBatch = calls.size() == EXPECTED_CALLS && refusedWarnings == 0 && (!IS_CACHE_ALLOCATED || breakerFailures == EXPECTED_CALLS);
	System.debug('SECTION84 ' + (isOneBatch ? 'PASS' : 'FAIL') + ' 84e-1: ' + calls.size() + ' calls sent for the unmarked issues, '
			+ refusedWarnings + ' refused for pending work, '
			+ (IS_CACHE_ALLOCATED ? breakerFailures + ' breaker failures counted' : 'breaker count skipped (no org cache is allocated)')
			+ (isOneBatch ? '' : '; a run more than 60 seconds after section 84d also fails, because the scheduled retries add calls and failures'));

	Boolean isSkipped = markedIssues.size() == 1 && markedIssues[0].kern__Status__c == 'Open' && !skipWarnings.isEmpty();
	System.debug('SECTION84 ' + (isSkipped ? 'PASS' : 'FAIL') + ' 84e-2: the marked issue ' + markedIssues + ' was skipped, ' + skipWarnings.size() + ' skip warnings logged');

	// The breaker first: its reset writes a log entry that lands after this transaction ends, so the RetryLive log
	// entries are deleted and proved by section-84-outbound-retry-live-log-cleanup.apex, run 30 seconds later.
	kern.UTIL_CircuitBreaker.monitor(SERVICE_GET).reset();
	delete [SELECT Id FROM kern__ApiIssue__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN];
	delete [SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN];
	delete [SELECT Id FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE :ROW_PATTERN OR kern__ShortMessage__c LIKE :ROW_PATTERN];
	delete skipWarnings;

	Integer left = [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN]
			+ [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN]
			+ [SELECT COUNT() FROM kern__LogEntry__c
				WHERE kern__ClassMethod__c LIKE :SKIP_LOCATION_PATTERN AND kern__ShortMessage__c LIKE :SKIP_PATTERN AND CreatedDate >= :seededAt];
	System.debug('SECTION84 ' + (left == 0 ? 'PASS' : 'FAIL') + ' 84e-cleanup: ' + left + ' calls, issues and skip warnings left behind; '
			+ 'run section-84-outbound-retry-live-log-cleanup.apex in 30 seconds for the RetryLive log entries');
}
