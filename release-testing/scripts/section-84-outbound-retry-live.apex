/**
 * Section 84: Outbound retry classification, live
 *
 * Proves, against the platform's own refusal rather than a mock, where a failed outbound call rests:
 *   84a. Three handlers sent in one batch to a Named Credential that does not exist (RetryLiveDoesNotExist), so every
 *        send fails at the send point: the GET (API_RetryLiveGet) and the keyed POST (API_RetryLiveKeyedPost, Idempotency
 *        Enabled, its row records the key it carried) are safe to repeat and rest at Retry with a time and one retry
 *        counted; the unkeyed POST (API_RetryLivePost) fails at once with the OutboundCall_NoResponseNotRepeated line,
 *        no retry counted, and an issue whose External System May Have Acted is true. All three callouts left the org (the callout count moved
 *        by three), and no row rests at Retry without a time.
 *   84b. A callout the org refuses before it leaves, because a save earlier in the transaction left work pending (an
 *        unkeyed ad-hoc POST with one retry): it rests at Retry with a time, its issue is not marked, the callout count
 *        did not move, and its circuit breaker counted no failure.
 *   84c. The same refused callout with no retry left ends Failed with no time, its issue still not marked, no breaker
 *        failure.
 *   84d. A half-open circuit whose trial request ends with no outcome (a refused or before-send failure records none)
 *        refuses further calls only until the cool-off has passed again, then starts a new round of trials.
 *   84e. Enqueues RetryLiveNeverSentJob twice: once to save inside a Queueable, once to delete the Foobar 84b saved;
 *        each then makes an unkeyed POST the org refuses. Section 84b reads both rows.
 *   84f. Two breaker names on one credential keep separate counts, and an open circuit with retry budget left schedules
 *        the call at the cool-off. These steps run in section 84b, not here: 84f-1 needs two callouts that leave the
 *        org, which is possible only before a transaction's first save, and this script saves from 84a on.
 *
 * Not a live step here: the handler's one lock retry on its commit. A row lock refused once retries the commit and never
 * the callout; the package tests that hold a real lock prove it
 * (API_Outbound_TEST.shouldRetryTheCommitOnceOnARowLockWithoutResendingTheCallout, API_Base_TEST.shouldRetryAnInboundCommitOnceOnARowLockAndRespondOnce),
 * and SubscriberOutboundRetry_TEST.shouldRunTheHandlersCommitHooksOncePerAttempt proves a subscriber outbound handler's
 * own commit hooks run once per attempt.
 *
 * The script saves nothing before 84a's batch: a save first would make the org refuse the three callouts, which is
 * 84b's case, not 84a's. It does not throw on a failure either, because a throw would roll back the rows and the jobs
 * section 84b reads; every check prints one SECTION84 PASS or SECTION84 FAIL line instead.
 *
 * Run-isolation: refuses to start while rows of an earlier run are left (run section 84b, which deletes them). Section
 * 84b, run at least 90 seconds later, checks the scheduled retries, the queued jobs and the breaker counts, then deletes
 * every row this section and its retries created (calls, issues, log entries, the Foobar) and proves the deletion by
 * query.
 *
 * Prerequisites:
 *   - subscriber org with the kern managed package installed
 *   - API_RetryLiveGet, API_RetryLivePost, API_RetryLiveKeyedPost and RetryLiveNeverSentJob deployed
 *   - kern__ApiCredential.RetryLiveUnreachable and kern__ApiSetting.RetryLiveGet, RetryLivePost and RetryLiveKeyedPost
 *     deployed; no Named Credential called RetryLiveDoesNotExist, RetryLiveNeverSentSave, RetryLiveNeverSentNoBudget,
 *     RetryLiveNeverSentQueueable, RetryLiveNeverSentDelete or RetryLiveSeparateCounts exists
 *   - the RetryOutboundApiCall flow active (section 84b relies on it)
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-84-outbound-retry-live.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *   then, at least 90 seconds later, section-84b-outbound-retry-live-verify.apex
 */

System.debug('=== Section 84: Outbound retry classification, live ===');

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
// The breakers section 84b's 84f steps use, reset here too so a run never starts from an earlier run's counts.
final List<String> STEP_84F_CIRCUITS = new List<String> {'RetryLiveSeparateCounts', 'RetryLiveCountOne', 'RetryLiveCountTwo', 'RetryLiveOpenCircuit'};
final String NEVER_SENT_PATH = '/never-sent';
final String FOOBAR_NAME = 'RetryLiveDeleteTarget';
final String STATUS_RETRY = 'Retry';
final String STATUS_FAILED = 'Failed';
final String ROW_PATTERN = '%RetryLive%';
final Integer NEVER_SENT_BACKOFF_SECONDS = 600;
final Integer COOL_OFF_SPIN_MILLISECONDS = 2100;
final Boolean IS_CACHE_ALLOCATED = kern.UTIL_Cache.isOrgAllocated();

// An ad-hoc call is stored under the framework's own handler name, so its address, which names its credential, is what
// marks it as this section's.
Integer leftoverRows = [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN OR kern__URL__c LIKE :ROW_PATTERN]
		+ [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN]
		+ [SELECT COUNT() FROM kern__Foobar__c WHERE Name LIKE :ROW_PATTERN];
if(leftoverRows > 0)
{
	throw new System.AssertException('Section 84: ' + leftoverRows + ' rows of an earlier run are left; '
			+ 'run section-84b-outbound-retry-live-verify.apex to delete them, then run this section again');
}

for(String circuitName : new List<String>
{
		SERVICE_GET, SERVICE_POST, SERVICE_KEYED_POST, NEVER_SENT_SAVE, NEVER_SENT_NO_BUDGET, NEVER_SENT_QUEUEABLE, NEVER_SENT_DELETE, CIRCUIT_HALF_OPEN
})
{
	kern.UTIL_CircuitBreaker.monitor(circuitName).reset();
}
for(String circuitName : STEP_84F_CIRCUITS)
{
	kern.UTIL_CircuitBreaker.monitor(circuitName).reset();
}

// 84a: the three handlers in one batch, each sent to the Named Credential that does not exist.
try
{
	Integer calloutsBefore = kern.UTIL_Limits.callouts().used();
	kern.API_Dispatcher.execute(new List<kern__ApiCall__c>
	{
			kern.TST_Factory.newOutboundApiCall(SERVICE_GET), kern.TST_Factory.newOutboundApiCall(SERVICE_POST), kern.TST_Factory.newOutboundApiCall(SERVICE_KEYED_POST)
	});
	Integer calloutsUsed = kern.UTIL_Limits.callouts().used() - calloutsBefore;

	Map<String, kern__ApiCall__c> rowsByService = new Map<String, kern__ApiCall__c>();
	for(kern__ApiCall__c row : [SELECT Id, kern__ServiceName__c, kern__Status__c, kern__NextRetry__c, kern__Retries__c, kern__ErrorMessages__c, kern__IdempotencyKey__c
			FROM kern__ApiCall__c WHERE kern__ServiceName__c IN (:SERVICE_GET, :SERVICE_POST, :SERVICE_KEYED_POST)])
	{
		rowsByService.put(row.kern__ServiceName__c, row);
	}
	List<kern__ApiIssue__c> postIssues = [SELECT Id, kern__ExternalSystemMayHaveActed__c FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :SERVICE_POST];
	String noResponseLine = String.format(System.Label.kern.OutboundCall_NoResponseNotRepeated, new List<Object> {SERVICE_POST});

	List<String> problems = new List<String>();
	if(rowsByService.size() != 3)
	{
		problems.add('expected one row per handler, got ' + rowsByService.keySet());
	}
	if(calloutsUsed != 3)
	{
		problems.add('expected all three callouts to leave the org, the callout count moved by ' + calloutsUsed);
	}
	for(String serviceName : new List<String> {SERVICE_GET, SERVICE_KEYED_POST})
	{
		kern__ApiCall__c row = rowsByService.get(serviceName);
		if(row == null || row.kern__Status__c != STATUS_RETRY || row.kern__NextRetry__c == null || row.kern__Retries__c != 1)
		{
			problems.add(serviceName + ' expected Retry with a time and one retry, got ' + row);
		}
	}
	// The keyed POST is safe to repeat because it carries an Idempotency-Key: the row records the key the request carried.
	kern__ApiCall__c keyedPostRow = rowsByService.get(SERVICE_KEYED_POST);
	if(keyedPostRow == null || String.isBlank(keyedPostRow.kern__IdempotencyKey__c))
	{
		problems.add(SERVICE_KEYED_POST + ' expected the Idempotency-Key it carried to be recorded on its row, got ' + keyedPostRow);
	}
	kern__ApiCall__c postRow = rowsByService.get(SERVICE_POST);
	if(postRow == null || postRow.kern__Status__c != STATUS_FAILED || postRow.kern__NextRetry__c != null || (postRow.kern__Retries__c ?? 0) != 0
			|| postRow.kern__ErrorMessages__c == null || !postRow.kern__ErrorMessages__c.contains(noResponseLine))
	{
		problems.add(SERVICE_POST + ' expected Failed, no time, no retry and the no-response line, got ' + postRow);
	}
	if(postIssues.size() != 1 || postIssues[0].kern__ExternalSystemMayHaveActed__c != true)
	{
		problems.add(SERVICE_POST + ' expected one issue marked External System May Have Acted, got ' + postIssues);
	}
	for(kern__ApiCall__c row : rowsByService.values())
	{
		if(row.kern__Status__c == STATUS_RETRY && row.kern__NextRetry__c == null)
		{
			problems.add(row.kern__ServiceName__c + ' rests at Retry with no time');
		}
	}

	if(problems.isEmpty())
	{
		pass++;
		System.debug('SECTION84 PASS 84a: GET and keyed POST rest at Retry with a time and one retry, the keyed POST recorded its key, '
				+ 'the unkeyed POST ended Failed with the no-response line and a marked issue, three callouts left the org');
	}
	else
	{
		fail++;
		System.debug('SECTION84 FAIL 84a: ' + String.join(problems, '; '));
	}
}
catch(Exception scenarioError)
{
	fail++;
	System.debug('SECTION84 FAIL 84a: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
}

// 84b: a save leaves work pending, so the org refuses the next callout before it leaves. The Foobar saved here is the
// one the delete job of 84e deletes, and the call names it as its triggering record, which is how its issue is found.
kern__Foobar__c deleteTarget = new kern__Foobar__c(Name = FOOBAR_NAME);
try
{
	insert deleteTarget;
	Integer calloutsBefore = kern.UTIL_Limits.callouts().used();
	kern.UTIL_HttpClient.post(NEVER_SENT_SAVE, NEVER_SENT_PATH)
			.withTriggeringRecord(deleteTarget.Id)
			.withRetry(1, NEVER_SENT_BACKOFF_SECONDS)
			.onFailure(kern.UTIL_HttpClient.FailureAction.RETRY_THEN_LOG)
			.withCircuitBreaker()
			.send();
	Integer calloutsUsed = kern.UTIL_Limits.callouts().used() - calloutsBefore;

	String callPattern = '%' + NEVER_SENT_SAVE + '%';
	String marker = String.valueOf(deleteTarget.Id);
	List<kern__ApiCall__c> rows = [SELECT Id, kern__Status__c, kern__NextRetry__c FROM kern__ApiCall__c WHERE kern__URL__c LIKE :callPattern];
	List<kern__ApiIssue__c> issues = [SELECT Id, kern__ExternalSystemMayHaveActed__c FROM kern__ApiIssue__c WHERE kern__TriggeringRecordId__c = :marker];
	Integer breakerFailures = IS_CACHE_ALLOCATED ? kern.UTIL_CircuitBreaker.monitor(NEVER_SENT_SAVE).getMetrics().failureCount : 0;

	List<String> problems = new List<String>();
	if(rows.size() != 1 || rows[0].kern__Status__c != STATUS_RETRY || rows[0].kern__NextRetry__c == null)
	{
		problems.add('expected one row at Retry with a time, got ' + rows);
	}
	if(issues.size() != 1 || issues[0].kern__ExternalSystemMayHaveActed__c == true)
	{
		problems.add('expected one unmarked issue, got ' + issues);
	}
	if(calloutsUsed != 0)
	{
		problems.add('expected the callout count not to move, it moved by ' + calloutsUsed);
	}
	if((breakerFailures ?? 0) != 0)
	{
		problems.add('expected no breaker failure, got ' + breakerFailures);
	}

	if(problems.isEmpty())
	{
		pass++;
		System.debug('SECTION84 PASS 84b: a callout refused after a save rests at Retry with a time, unmarked, '
				+ 'with no breaker failure (breaker checked: ' + IS_CACHE_ALLOCATED + ')');
	}
	else
	{
		fail++;
		System.debug('SECTION84 FAIL 84b: ' + String.join(problems, '; '));
	}
}
catch(Exception scenarioError)
{
	fail++;
	System.debug('SECTION84 FAIL 84b: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
}

// 84c: the same refusal with no retry left. A Foobar saved here marks the call and its issue (section 84b deletes it).
try
{
	kern__Foobar__c noBudgetMarker = new kern__Foobar__c(Name = FOOBAR_NAME + 'NoBudget');
	insert noBudgetMarker;
	kern.UTIL_HttpClient.post(NEVER_SENT_NO_BUDGET, NEVER_SENT_PATH)
			.withTriggeringRecord(noBudgetMarker.Id)
			.onFailure(kern.UTIL_HttpClient.FailureAction.LOG_FAILURE)
			.withCircuitBreaker()
			.send();

	String callPattern = '%' + NEVER_SENT_NO_BUDGET + '%';
	String marker = String.valueOf(noBudgetMarker.Id);
	List<kern__ApiCall__c> rows = [SELECT Id, kern__Status__c, kern__NextRetry__c FROM kern__ApiCall__c WHERE kern__URL__c LIKE :callPattern];
	List<kern__ApiIssue__c> issues = [SELECT Id, kern__ExternalSystemMayHaveActed__c FROM kern__ApiIssue__c WHERE kern__TriggeringRecordId__c = :marker];
	Integer breakerFailures = IS_CACHE_ALLOCATED ? kern.UTIL_CircuitBreaker.monitor(NEVER_SENT_NO_BUDGET).getMetrics().failureCount : 0;

	List<String> problems = new List<String>();
	if(rows.size() != 1 || rows[0].kern__Status__c != STATUS_FAILED || rows[0].kern__NextRetry__c != null)
	{
		problems.add('expected one row Failed with no time, got ' + rows);
	}
	if(issues.size() != 1 || issues[0].kern__ExternalSystemMayHaveActed__c == true)
	{
		problems.add('expected one unmarked issue, got ' + issues);
	}
	if((breakerFailures ?? 0) != 0)
	{
		problems.add('expected no breaker failure, got ' + breakerFailures);
	}

	if(problems.isEmpty())
	{
		pass++;
		System.debug('SECTION84 PASS 84c: a refused callout with no retry left ended Failed with no time, unmarked, with no breaker failure');
	}
	else
	{
		fail++;
		System.debug('SECTION84 FAIL 84c: ' + String.join(problems, '; '));
	}
}
catch(Exception scenarioError)
{
	fail++;
	System.debug('SECTION84 FAIL 84c: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
}

// 84d: a half-open circuit whose one trial ended with no outcome starts a new round once the cool-off has passed again.
// The timeout is counted in whole seconds and must be exceeded, so each wait spins a little over two seconds.
try
{
	if(!IS_CACHE_ALLOCATED)
	{
		pass++;
		System.debug('SECTION84 PASS 84d: skipped, no org cache is allocated, so the circuit breaker keeps no state between calls');
	}
	else
	{
		kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor(CIRCUIT_HALF_OPEN)
				.withFailureThreshold(1)
				.withTimeout(1)
				.withSuccessThreshold(1)
				.withHalfOpenMaxAttempts(1);
		breaker.forceOpen();
		// The first state read after a transition is the transition's own; read it now so the trial below is the first
		// read after the cool-off.
		kern.UTIL_CircuitBreaker.State stateAfterForceOpen = breaker.getState();
		Long spinStart = System.currentTimeMillis();
		while(System.currentTimeMillis() - spinStart < COOL_OFF_SPIN_MILLISECONDS)
		{
		}
		Boolean firstTrialAllowed = breaker.allowRequest();
		kern.UTIL_CircuitBreaker.State stateDuringTrial = breaker.getState();
		Boolean allowedWithTrialUsed = breaker.allowRequest();
		spinStart = System.currentTimeMillis();
		while(System.currentTimeMillis() - spinStart < COOL_OFF_SPIN_MILLISECONDS)
		{
		}
		Boolean allowedInNewRound = breaker.allowRequest();
		breaker.reset();

		if(stateAfterForceOpen == kern.UTIL_CircuitBreaker.State.OPEN && firstTrialAllowed && stateDuringTrial == kern.UTIL_CircuitBreaker.State.HALF_OPEN
				&& !allowedWithTrialUsed && allowedInNewRound)
		{
			pass++;
			System.debug('SECTION84 PASS 84d: the trial was let through, a second call was refused while the round lasted, and a new round let a call through after the cool-off');
		}
		else
		{
			fail++;
			System.debug('SECTION84 FAIL 84d: after forceOpen ' + stateAfterForceOpen + ', first trial ' + firstTrialAllowed + ' in state ' + stateDuringTrial
					+ ', second call ' + allowedWithTrialUsed + ', after the cool-off ' + allowedInNewRound);
		}
	}
}
catch(Exception scenarioError)
{
	fail++;
	System.debug('SECTION84 FAIL 84d: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
}

// 84e: the two queued refusals, read by section 84b. Enqueued last, after every callout of this transaction.
try
{
	System.enqueueJob(new RetryLiveNeverSentJob(NEVER_SENT_QUEUEABLE, null));
	System.enqueueJob(new RetryLiveNeverSentJob(NEVER_SENT_DELETE, deleteTarget.Id));
	pass++;
	System.debug('SECTION84 PASS 84e: queued the save-in-a-Queueable call and the call after a delete of ' + deleteTarget.Id);
}
catch(Exception scenarioError)
{
	fail++;
	System.debug('SECTION84 FAIL 84e: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
}

System.debug('Section 84: ' + pass + ' passed, ' + fail + ' failed. '
		+ 'Run section-84b-outbound-retry-live-verify.apex at least 90 seconds from now; it deletes every row this section created.');
