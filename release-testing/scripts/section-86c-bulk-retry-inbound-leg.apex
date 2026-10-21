/**
 * Section 86c: the bulk retry at volume, the inbound leg (verify; subscriber org)
 *
 * Run after section 86b. Section 86 put 120 inbound issues for API_SubscriberCreateAccount in the same selection as the
 * outbound ones, each linked to a Failed inbound call that holds its request. The job replays an inbound issue in the
 * org: it reads the request (path, method, body and key) from the call, checks the body against the hash the call
 * keeps, sends it through the inbound route again, with its changes kept, and marks the issue Resolved with the date
 * when the replay succeeds. The new call of the replay links to the call it replayed (Previous Attempt). Each replay
 * runs after the outbound calls of its Queueable; it is deferred only when the callout budget is spent, which cannot
 * happen here, because a Queueable holds at most 100 requests (section 86b-5 checks no deferral).
 *   86c-1. All 120 inbound issues are Resolved, each with a resolved date.
 *   86c-2. Each replay created its record: 120 Accounts named RetryLiveBulkInbound 0 to 119, one per issue.
 *   86c-3. The inbound calls since section 86 are the 120 Failed calls section 86 seeded, each still Failed, and one
 *          call per replay: 120 more, all Completed, each linked to a different seeded call. 240 in all.
 * If a job of section 86 is still running, or section 86b has not deleted the outbound rows yet, the script prints
 * SECTION86 PENDING, deletes nothing, and is run again later.
 *
 * Expected: 4 passed, 0 failed (86c-1 to 86c-3 and 86c-cleanup).
 *
 * Cleanup (only once nothing is pending): deletes the 120 Accounts, the 120 inbound issues, then the 240 inbound calls
 * (the issues go first: a call with an Open issue cannot be deleted), the log entries written since section 86 that
 * name API_SubscriberCreateAccount in their location or message, and the handoff Foobar, then proves by query that none
 * is left. Then run section-84-outbound-retry-live-log-cleanup.apex for the RetryLive log entries.
 *
 * Prerequisites:
 *   - sections 86 and 86b ran, and the handoff Foobar of section 86 (RetryLiveBulkHandoff) is still there
 *   - the running user is the one who ran section 86 and holds the Kern Administrator permission set (Delete API
 *     Records, so the cleanup may delete API calls and issues)
 *   - API_SubscriberCreateAccount and its setting SubscriberCreateAccount deployed and active, with Mocking Enabled off
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-86c-bulk-retry-inbound-leg.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug('=== Section 86c: the bulk retry at volume, the inbound leg (verify) ===');

Integer pass = 0;
Integer fail = 0;

final String SERVICE_INBOUND = API_SubscriberCreateAccount.class.getName();
final String ROW_PATTERN = '%RetryLive%';
final String HANDOFF_NAME = 'RetryLiveBulkHandoff';
final String INBOUND_MARKER = 'RetryLiveBulkInbound';
final String INBOUND_PATTERN = INBOUND_MARKER + '%';
// The log entries the replays wrote name the inbound service in their location or their message.
final String SERVICE_LOG_PATTERN = '%' + SERVICE_INBOUND + '%';
final String LAUNCHER_CLASS = 'UTIL_AdaptiveAsynchronousProcessor';
final String PACKAGE_NAMESPACE = 'kern';
final String STATUS_RESOLVED = 'Resolved';
final String STATUS_COMPLETED = 'Completed';
final Set<String> JOB_ENDED = new Set<String> {'Completed', 'Failed', 'Aborted'};
final String STATUS_FAILED = 'Failed';
final Integer EXPECTED_INBOUND = 120;
final Integer EXPECTED_INBOUND_CALLS = EXPECTED_INBOUND * 2;

List<kern__Foobar__c> handoffRows = [SELECT Id, kern__TextAreaLong__c FROM kern__Foobar__c WHERE Name = :HANDOFF_NAME LIMIT 1];
if(handoffRows.isEmpty())
{
	throw new System.AssertException('Section 86c: the handoff row of section 86 is missing; run section 86 first');
}
Map<String, Object> handoff = (Map<String, Object>)JSON.deserializeUntyped(handoffRows[0].kern__TextAreaLong__c);
Datetime windowStart = Datetime.newInstance(Long.valueOf(String.valueOf(handoff.get('startedAtMs')))).addSeconds(-2);
Datetime windowEnd = Datetime.newInstance(Long.valueOf(String.valueOf(handoff.get('finishedAtMs')))).addSeconds(5);
Integer expectedJobs = Integer.valueOf(String.valueOf(handoff.get('expectedJobs')));

List<AsyncApexJob> jobs = [SELECT Id, Status FROM AsyncApexJob
		WHERE ApexClass.Name = :LAUNCHER_CLASS AND ApexClass.NamespacePrefix = :PACKAGE_NAMESPACE AND JobType = 'Queueable'
		AND CreatedById = :UserInfo.getUserId() AND CreatedDate >= :windowStart AND CreatedDate <= :windowEnd];
Boolean areJobsDone = jobs.size() >= expectedJobs;
for(AsyncApexJob job : jobs)
{
	areJobsDone = areJobsDone && JOB_ENDED.contains(job.Status);
}
Integer outboundRowsLeft = [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN];

if(!areJobsDone || outboundRowsLeft > 0)
{
	System.debug('SECTION86 PENDING: jobs finished: ' + areJobsDone + ' (' + jobs.size() + ' of ' + expectedJobs + ' found), ' + outboundRowsLeft
			+ ' RetryLive issues left (section 86b deletes them). Nothing was deleted. Run section 86b, then this script again.');
}
else
{
	// 86c-1: every inbound issue was replayed and resolved.
	List<kern__ApiIssue__c> inboundIssues = [SELECT Id, kern__Status__c, kern__ResolvedDate__c, kern__ApiCall__c FROM kern__ApiIssue__c
			WHERE kern__ServiceName__c = :SERVICE_INBOUND AND kern__ApiCall__r.kern__IdempotencyKey__c LIKE :INBOUND_PATTERN];
	Integer unresolved = 0;
	for(kern__ApiIssue__c issue : inboundIssues)
	{
		unresolved += issue.kern__Status__c == STATUS_RESOLVED && issue.kern__ResolvedDate__c != null ? 0 : 1;
	}
	if(inboundIssues.size() == EXPECTED_INBOUND && unresolved == 0)
	{
		pass++;
		System.debug('SECTION86 PASS 86c-1: all ' + inboundIssues.size() + ' inbound issues are Resolved with a resolved date');
	}
	else
	{
		fail++;
		System.debug('SECTION86 FAIL 86c-1: expected ' + EXPECTED_INBOUND + ' inbound issues Resolved with a date; got ' + inboundIssues.size() + ', '
				+ unresolved + ' not resolved');
	}

	// 86c-2: each replay kept its change: one Account per issue.
	Set<String> accountNames = new Set<String>();
	for(Account account : [SELECT Name FROM Account WHERE Name LIKE :INBOUND_PATTERN])
	{
		accountNames.add(account.Name);
	}
	Integer accountCount = [SELECT COUNT() FROM Account WHERE Name LIKE :INBOUND_PATTERN];
	if(accountNames.size() == EXPECTED_INBOUND && accountCount == EXPECTED_INBOUND)
	{
		pass++;
		System.debug('SECTION86 PASS 86c-2: the replays created ' + accountCount + ' Accounts, one per issue');
	}
	else
	{
		fail++;
		System.debug('SECTION86 FAIL 86c-2: expected ' + EXPECTED_INBOUND + ' Accounts with distinct names; got ' + accountCount + ' Accounts, '
				+ accountNames.size() + ' distinct names');
	}

	// 86c-3: the seeded calls stay Failed, and each replay left one completed call linked to a different seeded call.
	Set<Id> seededCallIds = new Set<Id>();
	for(kern__ApiIssue__c issue : inboundIssues)
	{
		seededCallIds.add(issue.kern__ApiCall__c);
	}
	List<kern__ApiCall__c> inboundCalls = [SELECT Id, kern__Status__c, kern__PreviousAttempt__c FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SERVICE_INBOUND
			AND CreatedDate >= :windowStart];
	Integer seededNotFailed = 0;
	Integer replaysNotCompleted = 0;
	Set<Id> replayedCallIds = new Set<Id>();
	for(kern__ApiCall__c call : inboundCalls)
	{
		if(seededCallIds.contains(call.Id))
		{
			seededNotFailed += call.kern__Status__c == STATUS_FAILED ? 0 : 1;
		}
		else
		{
			replaysNotCompleted += call.kern__Status__c == STATUS_COMPLETED && seededCallIds.contains(call.kern__PreviousAttempt__c) ? 0 : 1;
			replayedCallIds.add(call.kern__PreviousAttempt__c);
		}
	}
	Integer replayCount = inboundCalls.size() - seededCallIds.size();
	if(inboundCalls.size() == EXPECTED_INBOUND_CALLS && seededCallIds.size() == EXPECTED_INBOUND && seededNotFailed == 0 && replaysNotCompleted == 0
			&& replayedCallIds.size() == EXPECTED_INBOUND)
	{
		pass++;
		System.debug('SECTION86 PASS 86c-3: ' + inboundCalls.size() + ' inbound calls: the ' + seededCallIds.size() + ' seeded calls still Failed, and '
				+ replayCount + ' replay calls, all Completed, each linked to a different seeded call');
	}
	else
	{
		fail++;
		System.debug('SECTION86 FAIL 86c-3: expected ' + EXPECTED_INBOUND_CALLS + ' inbound calls (' + EXPECTED_INBOUND + ' seeded and Failed, '
				+ EXPECTED_INBOUND + ' Completed replays each linked to a different seeded call); got ' + inboundCalls.size() + ' calls, '
				+ seededCallIds.size() + ' seeded, ' + seededNotFailed + ' seeded not Failed, ' + replaysNotCompleted + ' replays not Completed or not linked, '
				+ replayedCallIds.size() + ' seeded calls replayed');
	}

	// Cleanup: the replays' records, the inbound issues and calls, then the handoff.
	delete [SELECT Id FROM Account WHERE Name LIKE :INBOUND_PATTERN];
	// The issues first: a call with an Open issue cannot be deleted.
	delete inboundIssues;
	// A replay that failed has an Open issue of its own; delete it too, or the call cannot be deleted.
	delete [SELECT Id FROM kern__ApiIssue__c WHERE kern__ApiCall__c IN :inboundCalls];
	delete inboundCalls;
	delete handoffRows;
	delete [SELECT Id FROM kern__LogEntry__c WHERE (kern__ClassMethod__c LIKE :SERVICE_LOG_PATTERN OR kern__ShortMessage__c LIKE :SERVICE_LOG_PATTERN)
			AND CreatedDate >= :windowStart];

	Integer left = [SELECT COUNT() FROM kern__LogEntry__c WHERE (kern__ClassMethod__c LIKE :SERVICE_LOG_PATTERN OR kern__ShortMessage__c LIKE :SERVICE_LOG_PATTERN)
			AND CreatedDate >= :windowStart]
			+ [SELECT COUNT() FROM Account WHERE Name LIKE :INBOUND_PATTERN]
			+ [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :SERVICE_INBOUND AND CreatedDate >= :windowStart]
			+ [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SERVICE_INBOUND AND CreatedDate >= :windowStart]
			+ [SELECT COUNT() FROM kern__Foobar__c WHERE Name = :HANDOFF_NAME];
	if(left == 0)
	{
		pass++;
		System.debug('SECTION86 PASS 86c-cleanup: no Account, inbound issue, inbound call, replay log entry or handoff of section 86 is left; '
				+ 'run section-84-outbound-retry-live-log-cleanup.apex next');
	}
	else
	{
		fail++;
		System.debug('SECTION86 FAIL 86c-cleanup: ' + left + ' rows of section 86 left behind');
	}

	System.debug('Section 86c: ' + pass + ' passed, ' + fail + ' failed');
}
