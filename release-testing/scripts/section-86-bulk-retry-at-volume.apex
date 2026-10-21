/**
 * Section 86: the bulk retry at volume, through the global Flow action (subscriber org)
 *
 * Proves the bulk retry over hundreds of issues on the subscriber org, started the way a subscriber starts it: the
 * global Flow action kern.FLOW_RetryApiIssues.retryApiIssues, called once with every seeded issue's id. It seeds 450
 * Open issues in one selection:
 *   - 300 outbound issues for API_RetryLiveGet, as 150 requests of two issues each (two issues of one request share
 *     the service, the record, the parameters hash and the idempotency key). The service sends to a Named Credential
 *     that does not exist, so every call fails at the send point.
 *   - 20 outbound issues held back: 10 requests of two issues, one of each marked External System May Have Acted. A
 *     request any of whose issues is marked is never handed to the job, so all 20 stay Open and none is queued.
 *   - 10 outbound issues whose record (a Foobar) has a call still in progress (status Processing). They are queued; the
 *     job reads the open call when it runs, skips them, and logs the count at warn.
 *   - 120 inbound issues for API_SubscriberCreateAccount, each linked to a Failed inbound call that holds the request
 *     (path, method, body, key) and the SHA-256 hex of the body, as a failed request leaves them. Each request creates
 *     one Account. The issue keeps no copy of the request, as an issue the framework writes keeps none: the replay reads
 *     it from the call, and proves the body is an exact copy by its hash. Every inbound issue is its own request, and
 *     the job replays each after the outbound calls of its batch.
 * The action answers at once: 430 of the 450 open issues queued (300 + 10 + 120), with the labelled message. The job
 * holds 280 requests (150 + 10 + 120) and starts min(the FLOW_CallApiAsync job size, 100) requests per Queueable, 20
 * when no Asynchronous Job Setting changes it, so 14 Queueables run side by side. A batch never holds more requests
 * than the 100 callouts one transaction may make, so no outbound call and no inbound replay is deferred.
 *
 * Checks printed here: 86-1 the seed and the job size; 86-2 the action's answer. Expected: 2 passed, 0 failed. A check
 * does not throw (a throw would roll back the seed and the job); each prints one SECTION86 PASS or SECTION86 FAIL line.
 *
 * Section 86b, run at least 3 minutes later, checks the outbound leg and the jobs, prints the PERF_ROW lines and deletes
 * the outbound rows. Section 86c, run after 86b, checks the inbound leg and deletes its rows. Then run
 * section-84-outbound-retry-live-log-cleanup.apex for the RetryLive log entries. The window: every call rests at Retry for
 * 60 seconds after it fails, the RetryOutboundApiCall flow sends it once more, and 86b reads the end state, so 86b prints
 * SECTION86 PENDING (and deletes nothing) until the jobs have finished and every call has had its one retry.
 *
 * Run-isolation: refuses to start while rows of an earlier run are left (RetryLive calls, issues or Foobars, or inbound
 * calls, their issues and Accounts marked RetryLiveBulkInbound). Run sections 86b and 86c, or 84b, to delete them.
 *
 * Prerequisites:
 *   - subscriber org with the kern managed package installed
 *   - API_RetryLiveGet, API_SubscriberCreateAccount and their settings deployed (kern__ApiSetting.RetryLiveGet and
 *     RetryLiveUnreachable; kern__ApiSetting.SubscriberCreateAccount active, with Retry Issues on, so its issues may be
 *     replayed, and Mocking Enabled off: section 27 turns it on for its own run and must have turned it off again); no
 *     Named Credential called RetryLiveDoesNotExist
 *   - the RetryOutboundApiCall flow active (the end state 86b reads is after its one retry)
 *   - no active masking rule that changes the inbound bodies (section 76b turns MaskPhoneUS on and 76c turns it off again):
 *     a call whose body was changed no longer matches its hash, and the replay refuses it
 *   - the running user holds the Retry API Issue permission (the Kern Administrator permission set grants it) and the
 *     Delete API Records permission (the same set; 86b and 86c delete API calls and issues). Without the first the action
 *     queues nothing: this section prints one FAIL line that names the permission and rolls the seed back
 *   - no Asynchronous Job Setting for FLOW_CallApiAsync below 6: a smaller job size needs more than 50 Queueables, so the
 *     job would run them one after another and the window 86b reads would not hold them all
 *   - an org cache is optional: with one, the circuit breaker of API_RetryLiveGet opens after 5 failures and refuses the
 *     rest of the calls, which still fail and still get their one retry; 86b reports how many left the org
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-86-bulk-retry-at-volume.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *   then, at least 3 minutes later, section-86b-bulk-retry-at-volume-verify.apex, then section-86c-bulk-retry-inbound-leg.apex
 */

System.debug('=== Section 86: the bulk retry at volume ===');

Integer pass = 0;
Integer fail = 0;

final String SERVICE_GET = API_RetryLiveGet.class.getName();
final String SERVICE_INBOUND = API_SubscriberCreateAccount.class.getName();
final String ROW_PATTERN = '%RetryLive%';
final String INBOUND_MARKER = 'RetryLiveBulkInbound';
final String INBOUND_PATTERN = INBOUND_MARKER + '%';
final String HANDOFF_NAME = 'RetryLiveBulkHandoff';
final String BUSY_RECORD_NAME = 'RetryLiveBulkBusyRecord';
final String BUSY_CALL_SERVICE = 'RetryLiveBulkBusyCall';
final String PAIR_HASH_PREFIX = 'RetryLiveBulkPair';
final String HELD_HASH_PREFIX = 'RetryLiveBulkHeld';
final String BUSY_HASH_PREFIX = 'RetryLiveBulkBusy';
final String JOB_SIZE_SETTING_NAME = 'kern_FLOW_CallApiAsync';
final String STATUS_OPEN = 'Open';
final String STATUS_PROCESSING = 'Processing';
final String STATUS_FAILED = 'Failed';
final String HASH_ALGORITHM = 'SHA-256';
final String DIRECTION_OUTBOUND = 'Outbound';
final String DIRECTION_INBOUND = 'Inbound';
final String INBOUND_PATH = '/subscriber/accounts';
final String INBOUND_METHOD = 'POST';
final String INBOUND_INDUSTRY = 'Technology';
final String INBOUND_PHONE = '555-0100'; // the subscriber artifacts' Account rule requires a Phone or a Website
final Integer PAIR_COUNT = 150;
final Integer HELD_PAIR_COUNT = 10;
final Integer BUSY_COUNT = 10;
final Integer INBOUND_COUNT = 120;
final Integer SELECTED_COUNT = PAIR_COUNT * 2 + HELD_PAIR_COUNT * 2 + BUSY_COUNT + INBOUND_COUNT;
final Integer QUEUED_COUNT = PAIR_COUNT * 2 + BUSY_COUNT + INBOUND_COUNT;
final Integer REQUEST_COUNT = PAIR_COUNT + BUSY_COUNT + INBOUND_COUNT;
final Integer DEFAULT_JOB_SIZE = 20;
final Integer MAXIMUM_CALLOUT_JOB_SIZE = 100;
final Integer MINIMUM_PARALLEL_JOB_SIZE = 6;
final Long STARTED_AT_MS = System.currentTimeMillis();

Integer leftoverRows = [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN OR kern__URL__c LIKE :ROW_PATTERN]
		+ [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ServiceName__c LIKE :ROW_PATTERN]
		+ [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SERVICE_INBOUND AND kern__IdempotencyKey__c LIKE :INBOUND_PATTERN]
		+ [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :SERVICE_INBOUND AND kern__ApiCall__r.kern__IdempotencyKey__c LIKE :INBOUND_PATTERN]
		+ [SELECT COUNT() FROM kern__Foobar__c WHERE Name LIKE :ROW_PATTERN]
		+ [SELECT COUNT() FROM Account WHERE Name LIKE :INBOUND_PATTERN];
if(leftoverRows > 0)
{
	throw new System.AssertException('Section 86: ' + leftoverRows + ' rows of an earlier run are left; '
			+ 'run sections 86b and 86c (or 84b) to delete them, then run this section again');
}

// The job size the bulk retry uses: the FLOW_CallApiAsync Asynchronous Job Setting when one exists, never above 100.
Integer jobSize = DEFAULT_JOB_SIZE;
for(kern__AsynchronousJobSetting__mdt setting : [SELECT kern__BatchSize__c FROM kern__AsynchronousJobSetting__mdt WHERE DeveloperName = :JOB_SIZE_SETTING_NAME])
{
	if(setting.kern__BatchSize__c != null && setting.kern__BatchSize__c >= 1)
	{
		jobSize = setting.kern__BatchSize__c.intValue();
	}
}
jobSize = Math.min(jobSize, MAXIMUM_CALLOUT_JOB_SIZE);
if(jobSize < MINIMUM_PARALLEL_JOB_SIZE)
{
	throw new System.AssertException('Section 86: the FLOW_CallApiAsync job size is ' + jobSize + '; set it to at least ' + MINIMUM_PARALLEL_JOB_SIZE
			+ ' (or delete the setting) so the job runs its Queueables side by side, then run this section again');
}
Integer expectedJobs = (Integer)Math.ceil((Decimal)REQUEST_COUNT / jobSize);

kern.UTIL_CircuitBreaker.monitor(SERVICE_GET).reset();
System.Savepoint beforeSeed = Database.setSavepoint();

// 86-1: the seed. The busy record has a call still in progress, which the job reads when it runs.
List<kern__ApiIssue__c> issues = new List<kern__ApiIssue__c>();
try
{
	kern__Foobar__c busyRecord = new kern__Foobar__c(Name = BUSY_RECORD_NAME);
	insert busyRecord;
	insert new kern__ApiCall__c(
			kern__ServiceName__c = BUSY_CALL_SERVICE,
			kern__Direction__c = DIRECTION_OUTBOUND,
			kern__Status__c = STATUS_PROCESSING,
			kern__TriggeringRecordId__c = busyRecord.Id
	);

	for(Integer index = 0; index < PAIR_COUNT; index++)
	{
		for(Integer copy = 0; copy < 2; copy++)
		{
			issues.add(new kern__ApiIssue__c(kern__ServiceName__c = SERVICE_GET, kern__Status__c = STATUS_OPEN, kern__Direction__c = DIRECTION_OUTBOUND,
					kern__RequestParametersHash__c = PAIR_HASH_PREFIX + index));
		}
	}
	for(Integer index = 0; index < HELD_PAIR_COUNT; index++)
	{
		for(Integer copy = 0; copy < 2; copy++)
		{
			issues.add(new kern__ApiIssue__c(kern__ServiceName__c = SERVICE_GET, kern__Status__c = STATUS_OPEN, kern__Direction__c = DIRECTION_OUTBOUND,
					kern__RequestParametersHash__c = HELD_HASH_PREFIX + index, kern__ExternalSystemMayHaveActed__c = copy == 0));
		}
	}
	for(Integer index = 0; index < BUSY_COUNT; index++)
	{
		issues.add(new kern__ApiIssue__c(kern__ServiceName__c = SERVICE_GET, kern__Status__c = STATUS_OPEN, kern__Direction__c = DIRECTION_OUTBOUND,
				kern__RequestParametersHash__c = BUSY_HASH_PREFIX + index, kern__TriggeringRecordId__c = busyRecord.Id));
	}
	// Each inbound request is held by a Failed call, as a failed request leaves it; the hash proves the body is an exact copy.
	List<kern__ApiCall__c> inboundCalls = new List<kern__ApiCall__c>();
	for(Integer index = 0; index < INBOUND_COUNT; index++)
	{
		String body = JSON.serialize(new Map<String, Object> {'accountName' => INBOUND_MARKER + ' ' + index, 'industry' => INBOUND_INDUSTRY, 'phone' => INBOUND_PHONE});
		inboundCalls.add(new kern__ApiCall__c(kern__ServiceName__c = SERVICE_INBOUND, kern__Status__c = STATUS_FAILED, kern__Direction__c = DIRECTION_INBOUND,
				kern__URL__c = INBOUND_PATH, kern__HttpMethod__c = INBOUND_METHOD, kern__Request__c = body, kern__IdempotencyKey__c = INBOUND_MARKER + index,
				kern__IdempotencyKeyBodyHash__c = EncodingUtil.convertToHex(Crypto.generateDigest(HASH_ALGORITHM, Blob.valueOf(body)))));
	}
	insert inboundCalls;
	for(kern__ApiCall__c inboundCall : inboundCalls)
	{
		issues.add(new kern__ApiIssue__c(kern__ServiceName__c = SERVICE_INBOUND, kern__Status__c = STATUS_OPEN, kern__Direction__c = DIRECTION_INBOUND,
				kern__ApiCall__c = inboundCall.Id));
	}
	insert issues;

	Integer seeded = [SELECT COUNT() FROM kern__ApiIssue__c WHERE Id IN :issues AND kern__Status__c = :STATUS_OPEN];
	if(seeded == SELECTED_COUNT)
	{
		pass++;
		System.debug('SECTION86 PASS 86-1: seeded ' + seeded + ' open issues, the ' + INBOUND_COUNT + ' failed inbound calls that hold their requests and '
				+ 'one call in progress; job size ' + jobSize
				+ ', so ' + REQUEST_COUNT + ' requests make ' + expectedJobs + ' Queueables');
	}
	else
	{
		fail++;
		System.debug('SECTION86 FAIL 86-1: expected ' + SELECTED_COUNT + ' open issues, seeded ' + seeded);
	}
}
catch(Exception scenarioError)
{
	fail++;
	System.debug('SECTION86 FAIL 86-1: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
}

// 86-2: the action, called once with every id, as an administrator who holds the Retry API Issue permission.
try
{
	kern.FLOW_RetryApiIssues.DTO_Request request = new kern.FLOW_RetryApiIssues.DTO_Request();
	request.apiIssueIds = new List<String>();
	for(kern__ApiIssue__c issue : issues)
	{
		request.apiIssueIds.add(String.valueOf(issue.Id));
	}
	kern.FLOW_RetryApiIssues.DTO_Response response = kern.FLOW_RetryApiIssues.retryApiIssues(new List<kern.FLOW_RetryApiIssues.DTO_Request> {request}).get(0);

	if(response.message == System.Label.kern.RetryApiIssue_PermissionRequired)
	{
		Database.rollback(beforeSeed);
		fail++;
		System.debug('SECTION86 FAIL 86-2: the running user does not hold the Retry API Issue permission, so nothing was queued and the seed was '
				+ 'rolled back. Assign the Kern Administrator permission set to the running user and run this section again.');
	}
	else
	{
		String expectedMessage = String.format(System.Label.kern.RetryApiIssues_Queued, new List<Object> {QUEUED_COUNT, SELECTED_COUNT});
		Boolean isQueued = response.success == true && response.jobId != null && response.queuedCount == QUEUED_COUNT && response.message == expectedMessage;
		if(isQueued)
		{
			pass++;
			System.debug('SECTION86 PASS 86-2: the action queued ' + response.queuedCount + ' of ' + SELECTED_COUNT + ' open issues (the 20 held back were not '
					+ 'handed to the job), first job ' + response.jobId + ', with the labelled message');
		}
		else
		{
			fail++;
			System.debug('SECTION86 FAIL 86-2: expected success, a job id, ' + QUEUED_COUNT + ' queued and the labelled message; got success ' + response.success
					+ ', job ' + response.jobId + ', queued ' + response.queuedCount + ', message: ' + response.message);
		}

		// What 86b and 86c read: when the jobs were started, the job size, how many jobs to expect and the two counts.
		insert new kern__Foobar__c(Name = HANDOFF_NAME, kern__TextAreaLong__c = JSON.serialize(new Map<String, Object>
		{
				'startedAtMs' => STARTED_AT_MS,
				'finishedAtMs' => System.currentTimeMillis(),
				'jobSize' => jobSize,
				'expectedJobs' => expectedJobs,
				'selectedCount' => SELECTED_COUNT,
				'queuedCount' => response.queuedCount,
				'firstJobId' => response.jobId
		}));
	}
}
catch(Exception scenarioError)
{
	fail++;
	System.debug('SECTION86 FAIL 86-2: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
}

System.debug('Section 86: ' + pass + ' passed, ' + fail + ' failed. '
		+ 'Run section-86b-bulk-retry-at-volume-verify.apex at least 3 minutes from now, then section-86c-bulk-retry-inbound-leg.apex.');
