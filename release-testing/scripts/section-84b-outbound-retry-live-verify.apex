/**
 * Section 84b: Outbound retry classification, live (verify)
 *
 * Run at least 90 seconds after section 84. By then the RetryOutboundApiCall flow has fired at each scheduled time, the
 * queued attempt has failed at the send point again, and the budget of one retry is spent:
 *   84b-1. The GET and keyed POST rows ended Failed with one retry counted; the unkeyed POST row is unchanged (Failed,
 *          no retry counted).
 *   84b-2. The two calls RetryLiveNeverSentJob made (a save inside a Queueable, and a delete before the call) were refused
 *          before they left the org: each rests at Retry with a time, its issue unmarked, its circuit breaker with no
 *          failure.
 *   84b-3. No RetryLive row rests at Retry without a time.
 *   84b-4. With an org cache allocated, the circuit breakers counted every callout that left the org: 2 for the GET,
 *          1 for the unkeyed POST, 2 for the keyed POST. Without one, the check is skipped and says so.
 * Then the two 84f steps, which need an org cache (without one each is skipped and says so). They run here and not in
 * section 84 because a callout can leave the org only before the transaction's first save, and section 84 saves from 84a
 * on; this script saves nothing until 84f-2.
 *   84f-1. Two names on one credential keep separate breakers: two ad-hoc GETs to a Named Credential that does not exist
 *          (RetryLiveSeparateCounts), one under the breaker name RetryLiveCountOne and one under RetryLiveCountTwo, both
 *          with skipLogging() so neither saves anything and the second callout can still leave the org. Each breaker
 *          counts one failure, and the credential's own breaker counts none.
 *   84f-2. An open circuit with retry budget left: the breaker RetryLiveOpenCircuit is forced open, then one
 *          API_RetryLiveGet call is made through useHandler(...) under that breaker name. The call is not sent; its row
 *          rests at Retry with one retry counted, a time at least the 60-second cool-off away, and the
 *          OutboundCall_CircuitOpen line naming the breaker. A breaker of its own is used because API_RetryLiveGet's own
 *          breaker holds the counts 84b-4 reads. The row is deleted by the cleanup below in this same transaction, so
 *          its scheduled retry never runs.
 * If a row still reads Retrying or waits for its time (up to two minutes past it), or a queued job has not run yet, the
 * script prints SECTION84 PENDING, deletes nothing, and is run again 30 seconds later.
 *
 * Cleanup (only once nothing is pending): resets every circuit breaker the section used, deletes every call, issue and
 * log entry whose service or location names RetryLive and the Foobars section 84 and its job saved, then proves by query
 * that no call, issue or Foobar is left and prints SECTION84 PASS or FAIL for it. The log entries (a reset writes one,
 * and it lands after this transaction ends) are deleted and proved by section-84-outbound-retry-live-log-cleanup.apex,
 * run 30 seconds later.
 *
 * Prerequisite added by 84f: no Named Credential called RetryLiveSeparateCounts exists.
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-84b-outbound-retry-live-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug('=== Section 84b: Outbound retry classification, live (verify) ===');

Integer pass = 0;
Integer fail = 0;

final String SERVICE_GET = API_RetryLiveGet.class.getName();
final String SERVICE_POST = API_RetryLivePost.class.getName();
final String SERVICE_KEYED_POST = API_RetryLiveKeyedPost.class.getName();
final String NEVER_SENT_SAVE = 'RetryLiveNeverSentSave';
final String NEVER_SENT_NO_BUDGET = 'RetryLiveNeverSentNoBudget';
final String NEVER_SENT_QUEUEABLE = 'RetryLiveNeverSentQueueable';
final String NEVER_SENT_DELETE = 'RetryLiveNeverSentDelete';
final String CIRCUIT_HALF_OPEN = 'RetryLiveHalfOpen';
final String SEPARATE_COUNTS_CREDENTIAL = 'RetryLiveSeparateCounts';
final String SEPARATE_COUNTS_PATH = '/separate-counts';
final String CIRCUIT_COUNT_ONE = 'RetryLiveCountOne';
final String CIRCUIT_COUNT_TWO = 'RetryLiveCountTwo';
final String CIRCUIT_OPEN = 'RetryLiveOpenCircuit';
// API_RetryLiveGet's setting names no cool-off, so the framework's default of 60 seconds applies.
final Integer COOL_OFF_SECONDS = 60;
// A stored time keeps whole seconds, so it can sit up to a second before the time the script read.
final Integer STORED_TIME_TOLERANCE_SECONDS = 1;
final String STATUS_RETRY = 'Retry';
final String STATUS_RETRYING = 'Retrying';
final String STATUS_FAILED = 'Failed';
final String ROW_PATTERN = '%RetryLive%';
final Boolean IS_CACHE_ALLOCATED = kern.UTIL_Cache.isOrgAllocated();
// A row still at Retry this long after its time is past waiting: the flow did not fire, which 84b-1 then reports.
final Integer FLOW_GRACE_SECONDS = 120;
final Map<String, Integer> EXPECTED_BREAKER_FAILURES = new Map<String, Integer> {SERVICE_GET => 2, SERVICE_POST => 1, SERVICE_KEYED_POST => 2};

Map<String, kern__ApiCall__c> rowsByService = new Map<String, kern__ApiCall__c>();
// A handler's call is stored under the handler's name; an ad-hoc call under the framework's own handler name, so its
// address, which names its credential, is what tells it apart.
final List<String> AD_HOC_CREDENTIALS = new List<String> {NEVER_SENT_SAVE, NEVER_SENT_NO_BUDGET, NEVER_SENT_QUEUEABLE, NEVER_SENT_DELETE};
List<kern__ApiCall__c> allRows = [SELECT Id, kern__ServiceName__c, kern__URL__c, kern__TriggeringRecordId__c, kern__Status__c, kern__NextRetry__c, kern__Retries__c
		FROM kern__ApiCall__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN OR kern__URL__c LIKE :ROW_PATTERN];
Set<String> triggeringRecordIds = new Set<String>();
for(kern__ApiCall__c row : allRows)
{
	String key = row.kern__ServiceName__c;
	for(String credential : AD_HOC_CREDENTIALS)
	{
		if(row.kern__URL__c?.contains(credential) == true)
		{
			key = credential;
		}
	}
	rowsByService.put(key, row);
	if(row.kern__TriggeringRecordId__c != null)
	{
		triggeringRecordIds.add(row.kern__TriggeringRecordId__c);
	}
}

Boolean isPending = !rowsByService.containsKey(NEVER_SENT_QUEUEABLE) || !rowsByService.containsKey(NEVER_SENT_DELETE);
for(String serviceName : new List<String> {SERVICE_GET, SERVICE_KEYED_POST})
{
	kern__ApiCall__c row = rowsByService.get(serviceName);
	isPending = isPending || row?.kern__Status__c == STATUS_RETRYING
			|| (row?.kern__Status__c == STATUS_RETRY && row.kern__NextRetry__c > Datetime.now().addSeconds(-FLOW_GRACE_SECONDS));
}

if(isPending)
{
	System.debug('SECTION84 PENDING: a scheduled retry or a queued job has not finished; nothing was deleted. Run this script again in 30 seconds. Rows: ' + allRows);
}
else
{
	// 84b-1: the scheduled retries ran and spent the budget; the unkeyed POST was never retried.
	List<String> problems = new List<String>();
	for(String serviceName : new List<String> {SERVICE_GET, SERVICE_KEYED_POST})
	{
		kern__ApiCall__c row = rowsByService.get(serviceName);
		if(row == null || row.kern__Status__c != STATUS_FAILED || row.kern__NextRetry__c != null || row.kern__Retries__c != 1)
		{
			problems.add(serviceName + ' expected Failed, no time, one retry counted, got ' + row);
		}
	}
	kern__ApiCall__c postRow = rowsByService.get(SERVICE_POST);
	if(postRow == null || postRow.kern__Status__c != STATUS_FAILED || postRow.kern__NextRetry__c != null || (postRow.kern__Retries__c ?? 0) != 0)
	{
		problems.add(SERVICE_POST + ' expected unchanged (Failed, no time, no retry), got ' + postRow);
	}
	if(problems.isEmpty())
	{
		pass++;
		System.debug('SECTION84 PASS 84b-1: the GET and keyed POST ended Failed with their one retry spent; the unkeyed POST was never retried');
	}
	else
	{
		fail++;
		System.debug('SECTION84 FAIL 84b-1: ' + String.join(problems, '; '));
	}

	// 84b-2: the calls the queued job made after a save and after a delete were refused before they left the org.
	problems = new List<String>();
	// Each job's call names the record it saved or deleted as its triggering record, and so does the call's issue.
	Map<String, kern__ApiIssue__c> issuesByTriggeringRecord = new Map<String, kern__ApiIssue__c>();
	for(kern__ApiIssue__c issue : [SELECT Id, kern__TriggeringRecordId__c, kern__ExternalSystemMayHaveActed__c
			FROM kern__ApiIssue__c WHERE kern__TriggeringRecordId__c IN :triggeringRecordIds])
	{
		issuesByTriggeringRecord.put(issue.kern__TriggeringRecordId__c, issue);
	}
	for(String serviceName : new List<String> {NEVER_SENT_QUEUEABLE, NEVER_SENT_DELETE})
	{
		kern__ApiCall__c row = rowsByService.get(serviceName);
		kern__ApiIssue__c issue = row == null ? null : issuesByTriggeringRecord.get(row.kern__TriggeringRecordId__c);
		Integer breakerFailures = IS_CACHE_ALLOCATED ? kern.UTIL_CircuitBreaker.monitor(serviceName).getMetrics().failureCount : 0;
		if(row == null || row.kern__Status__c != STATUS_RETRY || row.kern__NextRetry__c == null)
		{
			problems.add(serviceName + ' expected Retry with a time, got ' + row);
		}
		if(issue == null || issue.kern__ExternalSystemMayHaveActed__c == true)
		{
			problems.add(serviceName + ' expected an unmarked issue, got ' + issue);
		}
		if((breakerFailures ?? 0) != 0)
		{
			problems.add(serviceName + ' expected no breaker failure, got ' + breakerFailures);
		}
	}
	if(problems.isEmpty())
	{
		pass++;
		System.debug('SECTION84 PASS 84b-2: the calls refused after a save in a Queueable and after a delete rest at Retry with a time, unmarked, with no breaker failure');
	}
	else
	{
		fail++;
		System.debug('SECTION84 FAIL 84b-2: ' + String.join(problems, '; '));
	}

	// 84b-3: the invariant across every row of the section.
	problems = new List<String>();
	for(kern__ApiCall__c row : allRows)
	{
		if(row.kern__Status__c == STATUS_RETRY && row.kern__NextRetry__c == null)
		{
			problems.add(row.kern__ServiceName__c + ' ' + row.Id);
		}
	}
	if(problems.isEmpty())
	{
		pass++;
		System.debug('SECTION84 PASS 84b-3: no RetryLive row rests at Retry without a time (' + allRows.size() + ' rows read)');
	}
	else
	{
		fail++;
		System.debug('SECTION84 FAIL 84b-3: rows at Retry with no time: ' + String.join(problems, ', '));
	}

	// 84b-4: the breaker counted every callout that left the org.
	if(!IS_CACHE_ALLOCATED)
	{
		pass++;
		System.debug('SECTION84 PASS 84b-4: skipped, no org cache is allocated, so the circuit breakers keep no count');
	}
	else
	{
		problems = new List<String>();
		for(String serviceName : EXPECTED_BREAKER_FAILURES.keySet())
		{
			Integer counted = kern.UTIL_CircuitBreaker.monitor(serviceName).getMetrics().failureCount;
			if(counted != EXPECTED_BREAKER_FAILURES.get(serviceName))
			{
				problems.add(serviceName + ' expected ' + EXPECTED_BREAKER_FAILURES.get(serviceName) + ', got ' + counted);
			}
		}
		if(problems.isEmpty())
		{
			pass++;
			System.debug('SECTION84 PASS 84b-4: the breakers counted 2, 1 and 2 failures for the GET, the unkeyed POST and the keyed POST');
		}
		else
		{
			fail++;
			System.debug('SECTION84 FAIL 84b-4: ' + String.join(problems, '; '));
		}
	}

	// 84f-1: two breaker names on one credential keep separate counts. Nothing is saved before these two callouts.
	try
	{
		if(!IS_CACHE_ALLOCATED)
		{
			pass++;
			System.debug('SECTION84 PASS 84f-1: skipped, no org cache is allocated, so the circuit breakers keep no count');
		}
		else
		{
			for(String circuitName : new List<String> {CIRCUIT_COUNT_ONE, CIRCUIT_COUNT_TWO, SEPARATE_COUNTS_CREDENTIAL})
			{
				kern.UTIL_CircuitBreaker.monitor(circuitName).reset();
			}
			Integer calloutsBefore = kern.UTIL_Limits.callouts().used();
			kern.UTIL_HttpClient.get(SEPARATE_COUNTS_CREDENTIAL, SEPARATE_COUNTS_PATH).withCircuitBreaker(CIRCUIT_COUNT_ONE).skipLogging().send();
			kern.UTIL_HttpClient.get(SEPARATE_COUNTS_CREDENTIAL, SEPARATE_COUNTS_PATH).withCircuitBreaker(CIRCUIT_COUNT_TWO).skipLogging().send();
			Integer calloutsUsed = kern.UTIL_Limits.callouts().used() - calloutsBefore;
			Integer countOne = kern.UTIL_CircuitBreaker.monitor(CIRCUIT_COUNT_ONE).getMetrics().failureCount ?? 0;
			Integer countTwo = kern.UTIL_CircuitBreaker.monitor(CIRCUIT_COUNT_TWO).getMetrics().failureCount ?? 0;
			Integer credentialCount = kern.UTIL_CircuitBreaker.monitor(SEPARATE_COUNTS_CREDENTIAL).getMetrics().failureCount ?? 0;
			if(calloutsUsed == 2 && countOne == 1 && countTwo == 1 && credentialCount == 0)
			{
				pass++;
				System.debug('SECTION84 PASS 84f-1: two breaker names on one credential counted one failure each, and the credential\'s own breaker none');
			}
			else
			{
				fail++;
				System.debug('SECTION84 FAIL 84f-1: callouts that left the org ' + calloutsUsed + ' (expected 2), ' + CIRCUIT_COUNT_ONE + ' ' + countOne
						+ ', ' + CIRCUIT_COUNT_TWO + ' ' + countTwo + ' (expected 1 each), ' + SEPARATE_COUNTS_CREDENTIAL + ' ' + credentialCount + ' (expected 0)');
			}
		}
	}
	catch(Exception scenarioError)
	{
		fail++;
		System.debug('SECTION84 FAIL 84f-1: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	}

	// 84f-2: an open circuit with retry budget left schedules the call at the cool-off. This step saves the call, so it
	// runs after every callout of this script.
	try
	{
		if(!IS_CACHE_ALLOCATED)
		{
			pass++;
			System.debug('SECTION84 PASS 84f-2: skipped, no org cache is allocated, so a forced-open breaker keeps no state between calls');
		}
		else
		{
			kern.UTIL_CircuitBreaker.monitor(CIRCUIT_OPEN).forceOpen();
			Set<Id> earlierGetRows = new Map<Id, kern__ApiCall__c>([SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SERVICE_GET]).keySet();
			Datetime dispatchedAt = Datetime.now();
			kern.UTIL_HttpClient.useHandler(API_RetryLiveGet.class).withCircuitBreaker(CIRCUIT_OPEN).invoke();
			List<kern__ApiCall__c> rows = [SELECT Id, kern__Status__c, kern__NextRetry__c, kern__Retries__c, kern__ErrorMessages__c
					FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SERVICE_GET AND Id NOT IN :earlierGetRows];
			String circuitOpenLine = String.format(System.Label.kern.OutboundCall_CircuitOpen, new List<Object> {CIRCUIT_OPEN});
			Datetime earliestRetry = dispatchedAt.addSeconds(COOL_OFF_SECONDS - STORED_TIME_TOLERANCE_SECONDS);

			List<String> openCircuitProblems = new List<String>();
			if(rows.size() != 1)
			{
				openCircuitProblems.add('expected one new ' + SERVICE_GET + ' row, got ' + rows);
			}
			else
			{
				kern__ApiCall__c row = rows[0];
				if(row.kern__Status__c != STATUS_RETRY || row.kern__NextRetry__c == null || row.kern__NextRetry__c < earliestRetry || row.kern__Retries__c != 1)
				{
					openCircuitProblems.add('expected Retry, one retry and a time at or after ' + earliestRetry + ', got ' + row);
				}
				if(row.kern__ErrorMessages__c == null || !row.kern__ErrorMessages__c.contains(circuitOpenLine))
				{
					openCircuitProblems.add('expected the open-circuit line naming ' + CIRCUIT_OPEN + ', got ' + row.kern__ErrorMessages__c);
				}
			}
			if(openCircuitProblems.isEmpty())
			{
				pass++;
				System.debug('SECTION84 PASS 84f-2: a call refused by an open circuit rests at Retry with one retry, a time at the cool-off and the open-circuit line');
			}
			else
			{
				fail++;
				System.debug('SECTION84 FAIL 84f-2: ' + String.join(openCircuitProblems, '; '));
			}
		}
	}
	catch(Exception scenarioError)
	{
		fail++;
		System.debug('SECTION84 FAIL 84f-2: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	}

	// Cleanup: the breakers first, then every row the section and its retries created, then the proof by query. A reset
	// writes a log entry of its own, which lands after this transaction ends with any other entry still on its way, so
	// the log entries are proved by section-84-outbound-retry-live-log-cleanup.apex, run 30 seconds later. The 84f-2 row
	// is a RetryLive row, so the deletes below remove it and its issue before its scheduled retry can run.
	for(String circuitName : new List<String>
	{
			SERVICE_GET, SERVICE_POST, SERVICE_KEYED_POST, NEVER_SENT_SAVE, NEVER_SENT_NO_BUDGET, NEVER_SENT_QUEUEABLE, NEVER_SENT_DELETE, CIRCUIT_HALF_OPEN,
			SEPARATE_COUNTS_CREDENTIAL, CIRCUIT_COUNT_ONE, CIRCUIT_COUNT_TWO, CIRCUIT_OPEN
	})
	{
		kern.UTIL_CircuitBreaker.monitor(circuitName).reset();
	}
	delete [SELECT Id FROM kern__ApiIssue__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN OR kern__TriggeringRecordId__c IN :triggeringRecordIds];
	delete [SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN OR kern__URL__c LIKE :ROW_PATTERN];
	delete [SELECT Id FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE :ROW_PATTERN OR kern__ShortMessage__c LIKE :ROW_PATTERN];
	delete [SELECT Id FROM kern__Foobar__c WHERE Name LIKE :ROW_PATTERN];

	Integer callsLeft = [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN OR kern__URL__c LIKE :ROW_PATTERN];
	Integer issuesLeft = [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN OR kern__TriggeringRecordId__c IN :triggeringRecordIds];
	Integer foobarsLeft = [SELECT COUNT() FROM kern__Foobar__c WHERE Name LIKE :ROW_PATTERN];
	if(callsLeft + issuesLeft + foobarsLeft == 0)
	{
		pass++;
		System.debug('SECTION84 PASS 84b-cleanup: no RetryLive call, issue or Foobar is left; '
				+ 'run section-84-outbound-retry-live-log-cleanup.apex in 30 seconds for the log entries');
	}
	else
	{
		fail++;
		System.debug('SECTION84 FAIL 84b-cleanup: left behind: ' + callsLeft + ' calls, ' + issuesLeft + ' issues, ' + foobarsLeft + ' Foobars');
	}

	System.debug('Section 84b: ' + pass + ' passed, ' + fail + ' failed');
}
