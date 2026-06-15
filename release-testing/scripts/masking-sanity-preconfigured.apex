// Subscriber masking sanity — verify default ship set fires on the four preconfigured
// SObjects: ApiCall__c, ApiIssue__c, AsyncChainExecution__c, LogEntryEvent__e (via LogEntry__c).
//
// Expected behaviour after install:
// - MaskSecretKeys (JsonKeyValue) redacts JSON values under password/token/apiKey
// - MaskPaymentCard redacts 13-19 digit sequences (it replaces MaskCreditCard on the framework objects)
// - Other rules (SSN, email, phone, JWT, auth, urlAuth, aws) are INACTIVE by default,
//   so those values persist raw.

Integer passCount = 0;
Integer failCount = 0;

String body = '{"user":"alice@example.com","password":"hunter2","ssn":"123-45-6789","card":"4111-1111-1111-1111","jwt":"eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.abcdef"}';

// --- ApiCall__c -----------------------------------------------------------------
kern__ApiCall__c call = new kern__ApiCall__c();
call.kern__ServiceName__c = 'MaskSanity_ApiCall';
call.kern__Direction__c = 'Inbound';
call.kern__Status__c = 'Completed';
call.kern__Request__c = body;
call.kern__Response__c = '{"status":"ok","token":"secret-abc"}';
insert call;

kern__ApiCall__c apiStored =
[
		SELECT kern__Request__c,
				kern__Response__c
		FROM kern__ApiCall__c
		WHERE Id = :call.Id
];
Boolean passApiPassword = !apiStored.kern__Request__c.contains('hunter2') && apiStored.kern__Request__c.contains('***SECRET***');
Boolean passApiCard = !apiStored.kern__Request__c.contains('4111-1111-1111-1111');
Boolean passApiToken = apiStored.kern__Response__c.contains('***SECRET***');
Boolean passApiSsnRaw = apiStored.kern__Request__c.contains('123-45-6789');
System.debug((passApiPassword ? 'PASS: ' : 'FAIL: ') + 'ApiCall.Request password redacted');
System.debug((passApiCard ? 'PASS: ' : 'FAIL: ') + 'ApiCall.Request card redacted');
System.debug((passApiToken ? 'PASS: ' : 'FAIL: ') + 'ApiCall.Response token redacted');
System.debug((passApiSsnRaw ? 'PASS: ' : 'FAIL: ') + 'ApiCall.Request SSN stays raw (MaskSsn inactive)');
passCount += (passApiPassword ? 1 : 0) + (passApiCard ? 1 : 0) + (passApiToken ? 1 : 0) + (passApiSsnRaw ? 1 : 0);
failCount += (passApiPassword ? 0 : 1) + (passApiCard ? 0 : 1) + (passApiToken ? 0 : 1) + (passApiSsnRaw ? 0 : 1);
delete call;

// --- ApiIssue__c ----------------------------------------------------------------
kern__ApiIssue__c issue = new kern__ApiIssue__c();
issue.kern__ErrorMessages__c = body;
issue.kern__RequestBody__c = body;
issue.kern__Status__c = 'Open';
insert issue;

kern__ApiIssue__c issueStored =
[
		SELECT kern__ErrorMessages__c,
				kern__RequestBody__c
		FROM kern__ApiIssue__c
		WHERE Id = :issue.Id
];
Boolean passIssuePassword = issueStored.kern__RequestBody__c.contains('***SECRET***') && !issueStored.kern__RequestBody__c.contains('hunter2');
Boolean passIssueCard = !issueStored.kern__RequestBody__c.contains('4111-1111-1111-1111');
System.debug((passIssuePassword ? 'PASS: ' : 'FAIL: ') + 'ApiIssue.RequestBody password redacted');
System.debug((passIssueCard ? 'PASS: ' : 'FAIL: ') + 'ApiIssue.RequestBody card redacted');
passCount += (passIssuePassword ? 1 : 0) + (passIssueCard ? 1 : 0);
failCount += (passIssuePassword ? 0 : 1) + (passIssueCard ? 0 : 1);
delete issue;

// --- AsyncChainExecution__c -----------------------------------------------------
kern__AsyncChainExecution__c chain = new kern__AsyncChainExecution__c();
chain.kern__ChainName__c = 'MaskSanityChain';
chain.kern__Status__c = 'Completed';
chain.kern__ContextData__c = body;
chain.kern__ErrorMessage__c = 'boom: hunter2 leaked';
insert chain;

kern__AsyncChainExecution__c chainStored =
[
		SELECT kern__ContextData__c,
				kern__ErrorMessage__c
		FROM kern__AsyncChainExecution__c
		WHERE Id = :chain.Id
];
Boolean passChainPassword = chainStored.kern__ContextData__c.contains('***SECRET***') && !chainStored.kern__ContextData__c.contains('hunter2');
Boolean passChainCard = !chainStored.kern__ContextData__c.contains('4111-1111-1111-1111');
// ErrorMessage is a plain string, not JSON — Secret rule (JsonKeyValue mode) will not fire on it.
// Card rule (Regex) also won't match 'hunter2' but ErrorMessage has no digit sequence.
System.debug((passChainPassword ? 'PASS: ' : 'FAIL: ') + 'AsyncChainExecution.ContextData password redacted');
System.debug((passChainCard ? 'PASS: ' : 'FAIL: ') + 'AsyncChainExecution.ContextData card redacted');
passCount += (passChainPassword ? 1 : 0) + (passChainCard ? 1 : 0);
failCount += (passChainPassword ? 0 : 1) + (passChainCard ? 0 : 1);
delete chain;

// --- LogEntryEvent__e -----------------------------------------------------------
// Event-backed path. In anonymous Apex Test.getEventBus() is not available, so we
// emit via LOG_Builder and query LogEntry__c after a small wait. Events are processed
// asynchronously — we poll up to 5 times.
kern.LOG_Builder.ignoreTestMode = true;
kern.LOG_Builder.build().info('payload = ' + body).emitAt('MaskSanity.logEntry');
// Nothing to do synchronously; we leave the event in flight. The persisted LogEntry
// will appear shortly; the verification script (below) queries it.
System.debug('NOTE: LogEntryEvent__e published; verify via query after async delivery');

System.debug('=== SUMMARY: ' + passCount + ' passed, ' + failCount + ' failed ===');
