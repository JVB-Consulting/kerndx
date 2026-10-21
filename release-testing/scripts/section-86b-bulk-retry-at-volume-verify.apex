/**
 * Section 86b: the bulk retry at volume (verify the outbound leg and the jobs; subscriber org)
 *
 * Run at least 3 minutes after section 86. By then the bulk job's Queueables have finished, every call they made has
 * rested at Retry for 60 seconds, and the RetryOutboundApiCall flow has sent it once more and spent its one retry:
 *   86b-1. One call per request: exactly 150 calls for API_RetryLiveGet, one for each request of two issues, and each
 *          ended Failed with one retry counted and no time. With an org cache, most calls were refused by the open
 *          circuit breaker rather than leaving the org; they still fail and get their one retry, so the end state is
 *          the same. The PASS line says how many of the first attempts left the org.
 *   86b-2. The 300 issues of those requests all stay Open, and the two issues of every request read the same status:
 *          no call succeeded, so none was resolved.
 *   86b-3. The 20 issues held back (one of each request marked External System May Have Acted) all stay Open, and the
 *          job logged no "may already have processed" warning: they were never handed to it.
 *   86b-4. The 10 issues whose record has a call in progress all stay Open, the job's warnings about a call still in
 *          progress add up to 10 (one warning per Queueable that held any of them), and that call is still Processing.
 *   86b-5. The jobs: as many Queueables as section 86 expected (14 at the default job size of 20), all Completed with no
 *          error, none Failed or Aborted, and no call or replay deferred because the callout budget ran out.
 *   86b-6. No call was refused before it left the org: no "refused before it left the org" warning for the service.
 *          What it can show: a call that the platform refused for unsaved work earlier in its transaction. What it
 *          cannot show on its own: with an org cache, the circuit breaker is usually open by the time the Queueable that
 *          holds the busy requests sends its calls, so those calls are refused by the breaker and never reach the send
 *          point. The check is weak there; without an org cache every call reaches the send point and the check is
 *          strong. The warning the job logs before it sends is a Publish Immediately event, which leaves no unsaved work.
 * Then it prints the PERF_ROW lines for section 86: issuesSelected, callsSent (the calls the job made, one per
 * request), jobsRun, wallMsToDrain (the first job created to the last job finished) and issuesPerMinute (issues queued
 * per minute of that time). With an org cache it also prints the circuit breaker's count, for information only: the
 * Queueables run side by side and share the count through the cache with no lock, so the number is not exact.
 * If a job is still running, or a call still waits for its retry (up to two minutes past its time), the script prints
 * SECTION86 PENDING, deletes nothing, and is run again 30 seconds later.
 *
 * Expected: 7 passed, 0 failed (86b-1 to 86b-6 and 86b-cleanup).
 *
 * Cleanup (only once nothing is pending): resets the circuit breaker, deletes every RetryLive call and issue (the seeded
 * ones, the ones the failed calls logged, the call in progress), the busy Foobar and the job's warnings, then proves by
 * query that none is left. The handoff Foobar stays for section 86c. The RetryLive log entries (the reset writes one,
 * landing after this transaction) are deleted by section-84-outbound-retry-live-log-cleanup.apex, run after 86c.
 *
 * Prerequisites (the same as section 86):
 *   - section 86 ran and left its handoff Foobar (RetryLiveBulkHandoff)
 *   - the running user is the one who ran section 86 (the jobs are found by their creator) and holds the Kern
 *     Administrator permission set: Delete API Records, so the cleanup may delete API calls and issues
 *   - the RetryOutboundApiCall flow active, so every call gets its one retry and the script stops waiting
 *   - an org cache is optional: without one, the breaker line is not printed and 86b-6 is a strong check
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-86b-bulk-retry-at-volume-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug('=== Section 86b: the bulk retry at volume (verify) ===');

Integer pass = 0;
Integer fail = 0;

final String SERVICE_GET = API_RetryLiveGet.class.getName();
final String ROW_PATTERN = '%RetryLive%';
final String HANDOFF_NAME = 'RetryLiveBulkHandoff';
final String BUSY_CALL_SERVICE = 'RetryLiveBulkBusyCall';
final String PAIR_HASH_PATTERN = 'RetryLiveBulkPair%';
final String HELD_HASH_PATTERN = 'RetryLiveBulkHeld%';
final String BUSY_HASH_PATTERN = 'RetryLiveBulkBusy%';
final String PROCESSOR_LOCATION_PATTERN = '%CTRL_RetryApiIssue/FailureReplayProcessor';
final String OPEN_CALL_PATTERN = '%still in progress%';
final String MAY_HAVE_ACTED_PATTERN = '%may already have processed%';
final String DEFERRED_PATTERN = '%callout budget exhausted%';
final String REFUSED_PATTERN = '%refused before it left the org%';
final String SEND_LOCATION = SERVICE_GET + '/sendRequest';
final String CIRCUIT_OPEN_TEXT = System.Label.kern.OutboundCall_CircuitOpen.substringBefore('{0}');
final String LAUNCHER_CLASS = 'UTIL_AdaptiveAsynchronousProcessor';
final String PACKAGE_NAMESPACE = 'kern';
final String STATUS_OPEN = 'Open';
final String STATUS_RETRY = 'Retry';
final String STATUS_RETRYING = 'Retrying';
final String STATUS_FAILED = 'Failed';
final String STATUS_PROCESSING = 'Processing';
final String JOB_COMPLETED = 'Completed';
final Set<String> JOB_ENDED = new Set<String> {'Completed', 'Failed', 'Aborted'};
final Integer EXPECTED_CALLS = 150;
final Integer EXPECTED_PAIR_ISSUES = 300;
final Integer EXPECTED_HELD_ISSUES = 20;
final Integer EXPECTED_BUSY_ISSUES = 10;
// A call still at Retry this long after its time is past waiting: the flow did not send it, which 86b-1 then reports.
final Integer FLOW_GRACE_SECONDS = 120;
final Boolean IS_CACHE_ALLOCATED = kern.UTIL_Cache.isOrgAllocated();

List<kern__Foobar__c> handoffRows = [SELECT kern__TextAreaLong__c FROM kern__Foobar__c WHERE Name = :HANDOFF_NAME LIMIT 1];
if(handoffRows.isEmpty())
{
	throw new System.AssertException('Section 86b: the handoff row of section 86 is missing; run section 86 first');
}
Map<String, Object> handoff = (Map<String, Object>)JSON.deserializeUntyped(handoffRows[0].kern__TextAreaLong__c);
Long startedAtMs = Long.valueOf(String.valueOf(handoff.get('startedAtMs')));
Long finishedAtMs = Long.valueOf(String.valueOf(handoff.get('finishedAtMs')));
Integer expectedJobs = Integer.valueOf(String.valueOf(handoff.get('expectedJobs')));
Integer selectedCount = Integer.valueOf(String.valueOf(handoff.get('selectedCount')));
Integer queuedCount = Integer.valueOf(String.valueOf(handoff.get('queuedCount')));
// The bulk job's Queueables are all created in section 86's own transaction; the flow's retries start later jobs of the
// same class, so only the jobs created inside that transaction count.
Datetime windowStart = Datetime.newInstance(startedAtMs).addSeconds(-2);
Datetime windowEnd = Datetime.newInstance(finishedAtMs).addSeconds(5);

List<AsyncApexJob> jobs = [SELECT Id, Status, CreatedDate, CompletedDate, NumberOfErrors, ExtendedStatus FROM AsyncApexJob
		WHERE ApexClass.Name = :LAUNCHER_CLASS AND ApexClass.NamespacePrefix = :PACKAGE_NAMESPACE AND JobType = 'Queueable'
		AND CreatedById = :UserInfo.getUserId() AND CreatedDate >= :windowStart AND CreatedDate <= :windowEnd];
Boolean areJobsDone = jobs.size() >= expectedJobs;
for(AsyncApexJob job : jobs)
{
	areJobsDone = areJobsDone && JOB_ENDED.contains(job.Status);
}

List<kern__ApiCall__c> calls = [SELECT Id, kern__Status__c, kern__NextRetry__c, kern__Retries__c, kern__ErrorMessages__c FROM kern__ApiCall__c
		WHERE kern__ServiceName__c = :SERVICE_GET AND CreatedDate >= :windowStart];
Boolean isWaitingForRetry = false;
for(kern__ApiCall__c call : calls)
{
	isWaitingForRetry = isWaitingForRetry || call.kern__Status__c == STATUS_RETRYING
			|| (call.kern__Status__c == STATUS_RETRY && call.kern__NextRetry__c > Datetime.now().addSeconds(-FLOW_GRACE_SECONDS));
}

if(!areJobsDone || isWaitingForRetry)
{
	System.debug('SECTION86 PENDING: ' + jobs.size() + ' of ' + expectedJobs + ' jobs found (finished: ' + areJobsDone + '), ' + calls.size()
			+ ' calls, a call still waits for its retry: ' + isWaitingForRetry + '. Nothing was deleted. Run this script again in 30 seconds.');
}
else
{
	List<kern__LogEntry__c> processorWarnings = [SELECT Id, kern__ShortMessage__c FROM kern__LogEntry__c
			WHERE kern__ClassMethod__c LIKE :PROCESSOR_LOCATION_PATTERN AND CreatedDate >= :windowStart];
	Integer openCallSkips = 0;
	Integer mayHaveActedSkips = 0;
	for(kern__LogEntry__c warning : processorWarnings)
	{
		String message = warning.kern__ShortMessage__c ?? '';
		String leadingCount = message.substringBefore(' ');
		Integer count = leadingCount.isNumeric() ? Integer.valueOf(leadingCount) : 0;
		if(message.contains('still in progress'))
		{
			openCallSkips += count;
		}
		else if(message.contains('may already have processed'))
		{
			mayHaveActedSkips += count;
		}
	}

	// 86b-1: one call per request, each ended Failed with its one retry spent.
	List<String> problems = new List<String>();
	Integer refusedByOpenCircuit = 0;
	for(kern__ApiCall__c call : calls)
	{
		if(call.kern__Status__c != STATUS_FAILED || call.kern__NextRetry__c != null || call.kern__Retries__c != 1)
		{
			problems.add(call.Id + ' (' + call.kern__Status__c + ', retries ' + call.kern__Retries__c + ', time ' + call.kern__NextRetry__c + ')');
		}
		if(call.kern__ErrorMessages__c?.contains(CIRCUIT_OPEN_TEXT) == true)
		{
			refusedByOpenCircuit++;
		}
	}
	if(calls.size() == EXPECTED_CALLS && problems.isEmpty())
	{
		pass++;
		System.debug('SECTION86 PASS 86b-1: ' + calls.size() + ' calls, one per request, each ended Failed with one retry counted and no time; '
				+ refusedByOpenCircuit + ' carry the open-circuit refusal from their last attempt');
	}
	else
	{
		fail++;
		System.debug('SECTION86 FAIL 86b-1: expected ' + EXPECTED_CALLS + ' calls ended Failed with one retry and no time; got ' + calls.size() + ' calls, '
				+ problems.size() + ' not at that end state: ' + String.join(problems, ', ').left(2000));
	}

	// 86b-2: the two issues of every request stay Open together.
	Map<String, Set<String>> statusesByRequest = new Map<String, Set<String>>();
	Integer pairIssues = 0;
	Integer pairIssuesNotOpen = 0;
	for(kern__ApiIssue__c issue : [SELECT kern__RequestParametersHash__c, kern__Status__c, kern__ResolvedDate__c FROM kern__ApiIssue__c
			WHERE kern__ServiceName__c = :SERVICE_GET AND kern__RequestParametersHash__c LIKE :PAIR_HASH_PATTERN])
	{
		pairIssues++;
		if(issue.kern__Status__c != STATUS_OPEN || issue.kern__ResolvedDate__c != null)
		{
			pairIssuesNotOpen++;
		}
		if(!statusesByRequest.containsKey(issue.kern__RequestParametersHash__c))
		{
			statusesByRequest.put(issue.kern__RequestParametersHash__c, new Set<String>());
		}
		statusesByRequest.get(issue.kern__RequestParametersHash__c).add(issue.kern__Status__c);
	}
	Integer splitRequests = 0;
	for(Set<String> statuses : statusesByRequest.values())
	{
		splitRequests += statuses.size() > 1 ? 1 : 0;
	}
	if(pairIssues == EXPECTED_PAIR_ISSUES && pairIssuesNotOpen == 0 && splitRequests == 0)
	{
		pass++;
		System.debug('SECTION86 PASS 86b-2: the ' + pairIssues + ' issues of the ' + statusesByRequest.size() + ' requests all stay Open, two to a request');
	}
	else
	{
		fail++;
		System.debug('SECTION86 FAIL 86b-2: expected ' + EXPECTED_PAIR_ISSUES + ' issues all Open; got ' + pairIssues + ', ' + pairIssuesNotOpen
				+ ' not Open, ' + splitRequests + ' requests whose two issues differ');
	}

	// 86b-3: the requests held back never reached the job.
	Integer heldIssues = [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :SERVICE_GET AND kern__RequestParametersHash__c LIKE :HELD_HASH_PATTERN
			AND kern__Status__c = :STATUS_OPEN];
	if(heldIssues == EXPECTED_HELD_ISSUES && mayHaveActedSkips == 0)
	{
		pass++;
		System.debug('SECTION86 PASS 86b-3: the ' + heldIssues + ' issues held back stay Open and the job logged no "may already have processed" skip');
	}
	else
	{
		fail++;
		System.debug('SECTION86 FAIL 86b-3: expected ' + EXPECTED_HELD_ISSUES + ' Open issues held back and no skip warning; got ' + heldIssues
				+ ' Open and ' + mayHaveActedSkips + ' skipped');
	}

	// 86b-4: the requests whose record has a call in progress were skipped by the job and counted at warn.
	Integer busyIssues = [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :SERVICE_GET AND kern__RequestParametersHash__c LIKE :BUSY_HASH_PATTERN
			AND kern__Status__c = :STATUS_OPEN];
	Integer busyCalls = [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c = :BUSY_CALL_SERVICE AND kern__Status__c = :STATUS_PROCESSING];
	if(busyIssues == EXPECTED_BUSY_ISSUES && openCallSkips == EXPECTED_BUSY_ISSUES && busyCalls == 1)
	{
		pass++;
		System.debug('SECTION86 PASS 86b-4: the ' + busyIssues + ' issues with a call in progress stay Open, the job counted ' + openCallSkips
				+ ' skipped at warn, and the call is still Processing');
	}
	else
	{
		fail++;
		System.debug('SECTION86 FAIL 86b-4: expected ' + EXPECTED_BUSY_ISSUES + ' Open, ' + EXPECTED_BUSY_ISSUES + ' counted at warn and the call Processing; got '
				+ busyIssues + ' Open, ' + openCallSkips + ' counted, ' + busyCalls + ' calls Processing');
	}

	// 86b-5: the jobs all finished cleanly, and nothing was deferred for the callout budget.
	Integer deferredWarnings = [SELECT COUNT() FROM kern__LogEntry__c WHERE kern__ShortMessage__c LIKE :DEFERRED_PATTERN AND CreatedDate >= :windowStart];
	List<String> badJobs = new List<String>();
	Datetime firstCreated;
	Datetime lastCompleted;
	for(AsyncApexJob job : jobs)
	{
		if(job.Status != JOB_COMPLETED || (job.NumberOfErrors ?? 0) > 0)
		{
			badJobs.add(job.Id + ' ' + job.Status + ' ' + job.ExtendedStatus);
		}
		firstCreated = firstCreated == null || job.CreatedDate < firstCreated ? job.CreatedDate : firstCreated;
		lastCompleted = lastCompleted == null || job.CompletedDate > lastCompleted ? job.CompletedDate : lastCompleted;
	}
	if(jobs.size() == expectedJobs && badJobs.isEmpty() && deferredWarnings == 0)
	{
		pass++;
		System.debug('SECTION86 PASS 86b-5: ' + jobs.size() + ' Queueables, all Completed with no error, nothing deferred for the callout budget');
	}
	else
	{
		fail++;
		System.debug('SECTION86 FAIL 86b-5: expected ' + expectedJobs + ' Queueables all Completed and no deferral; got ' + jobs.size() + ', not completed: '
				+ badJobs + ', ' + deferredWarnings + ' deferral warnings');
	}

	// 86b-6: every call left the org or was refused by the open circuit; none was refused for unsaved work.
	Integer refusedWarnings = [SELECT COUNT() FROM kern__LogEntry__c WHERE kern__ClassMethod__c = :SEND_LOCATION AND kern__ShortMessage__c LIKE :REFUSED_PATTERN
			AND CreatedDate >= :windowStart];
	if(refusedWarnings == 0)
	{
		pass++;
		System.debug('SECTION86 PASS 86b-6: no call was refused before it left the org');
	}
	else
	{
		fail++;
		System.debug('SECTION86 FAIL 86b-6: ' + refusedWarnings + ' "refused before it left the org" warnings for ' + SERVICE_GET);
	}

	if(IS_CACHE_ALLOCATED)
	{
		kern.UTIL_CircuitBreaker.Metrics metrics = kern.UTIL_CircuitBreaker.monitor(SERVICE_GET).getMetrics();
		System.debug('SECTION86 INFO 86b-breaker: the circuit breaker counted ' + metrics.failureCount + ' failures (information only, see the header)');
	}

	Long wallMsToDrain = firstCreated == null || lastCompleted == null ? 0 : lastCompleted.getTime() - firstCreated.getTime();
	Decimal issuesPerMinute = ((Decimal)queuedCount * 60000 / Math.max(wallMsToDrain, 1000)).setScale(1);
	System.debug('PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 86, 'metric' => 'issuesSelected', 'value' => selectedCount}));
	System.debug('PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 86, 'metric' => 'callsSent', 'value' => calls.size()}));
	System.debug('PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 86, 'metric' => 'jobsRun', 'value' => jobs.size()}));
	System.debug('PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 86, 'metric' => 'wallMsToDrain', 'value' => wallMsToDrain}));
	System.debug('PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 86, 'metric' => 'issuesPerMinute', 'value' => issuesPerMinute}));

	// Cleanup: the breaker first (its reset writes a log entry that lands after this transaction), then every RetryLive
	// call and issue, the busy Foobar and the job's warnings. The handoff Foobar stays for section 86c.
	kern.UTIL_CircuitBreaker.monitor(SERVICE_GET).reset();
	List<kern__ApiCall__c> cleanupCalls = [SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN OR kern__URL__c LIKE :ROW_PATTERN];
	// The issues first: a call with an Open issue cannot be deleted, so the issues of these calls go too, whoever wrote them.
	delete [SELECT Id FROM kern__ApiIssue__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN OR kern__ApiCall__c IN :cleanupCalls];
	delete cleanupCalls;
	delete [SELECT Id FROM kern__Foobar__c WHERE Name LIKE :ROW_PATTERN AND Name != :HANDOFF_NAME];
	delete processorWarnings;

	Integer callsLeft = [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN OR kern__URL__c LIKE :ROW_PATTERN];
	Integer issuesLeft = [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN];
	Integer foobarsLeft = [SELECT COUNT() FROM kern__Foobar__c WHERE Name LIKE :ROW_PATTERN AND Name != :HANDOFF_NAME];
	Integer warningsLeft = [SELECT COUNT() FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE :PROCESSOR_LOCATION_PATTERN AND CreatedDate >= :windowStart];
	if(callsLeft + issuesLeft + foobarsLeft + warningsLeft == 0)
	{
		pass++;
		System.debug('SECTION86 PASS 86b-cleanup: no RetryLive call, issue or Foobar and no job warning is left; run section 86c next');
	}
	else
	{
		fail++;
		System.debug('SECTION86 FAIL 86b-cleanup: left behind: ' + callsLeft + ' calls, ' + issuesLeft + ' issues, ' + foobarsLeft + ' Foobars, '
				+ warningsLeft + ' job warnings');
	}

	System.debug('Section 86b: ' + pass + ' passed, ' + fail + ' failed');
}
