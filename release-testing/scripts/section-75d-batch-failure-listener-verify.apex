/**
 * Section 75d: Batch failure log and batch size from the job setting (Verify)
 *
 * Verification half of section 75c. Reads the handoff row 75c saved and checks:
 *   - 75d-raising-job: the TST_RaisingBatch job has finished and the platform counted at least one failed call.
 *   - 75d-error-log: the framework's batch failure trigger wrote one ERROR entry per failed call (as many as the job's
 *     error count), each filed under TST_RaisingBatch/execute, linked to the job, carrying the exception message and
 *     the exception type, with EXECUTE as the phase in its context.
 *   - 75d-size-warn: the launch wrote the batch-size WARN for TST_SizeProbeHandler: size 75, a chunk of 100, a short run
 *     of 25 rows, and 50 and 100 as the sizes that fit. It reads only the rows under the WARN's key (its sample row and
 *     its daily counter row) changed at or after the start time 75c saved, so a row an earlier run left never counts.
 *   - 75d-size-job: the launcher's job ran as a batch with no failed call, in at least 4 calls (290 rows at 75 a call;
 *     at the default size of 200 it would take 2), and ticked all 290 rows. The number of calls is printed: 6 means
 *     the platform also cut each chunk of 100 into 75 and 25, as the WARN says.
 * When every check passes, it deletes the Foobar rows, the handoff row and the log entries 75c and the jobs wrote.
 *
 * The log entries arrive through platform events, so the script waits up to about eight seconds of processing time
 * for them. The runner should start it about 60 seconds after 75c.
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-75d-batch-failure-listener-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

final String HANDOFF_NAME_PREFIX = 'Section75cHandoff_';
final String ERROR_LEVEL = 'ERROR';
final String WARN_LEVEL = 'WARN';
final String RAISING_LOCATION_PATTERN = '%TST_RaisingBatch/execute';
final String RAISING_EXCEPTION_NAME = 'RaisingBatchException';
final String EXECUTE_PHASE = 'EXECUTE';
final String SCOPE_SIZE_KEY_PATTERN = '%batch-scope-size-does-not-fit:%TST_SizeProbeHandler:75%';
final String EXPECTED_SCOPE_SIZE = '75';
final String EXPECTED_RETRIEVE_CHUNK = '100';
final String EXPECTED_FITTING_SIZES = '50, 100';
final Integer MINIMUM_SIZE_JOB_CALLS = 4;
final Set<String> FINISHED_JOB_STATUSES = new Set<String> {'Completed', 'Failed', 'Aborted'};
final Integer LOG_WAIT_INTERVAL_MILLISECONDS = 2000;
final Integer LOG_WAIT_CPU_LIMIT_MILLISECONDS = 8000;

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 75d: Batch failure log and batch size from the job setting (Verify) ===');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

List<kern__Foobar__c> handoffRows =
[
		SELECT Id,
				kern__TextAreaLong__c
		FROM kern__Foobar__c
		WHERE Name LIKE :(HANDOFF_NAME_PREFIX + '%')
		ORDER BY CreatedDate DESC
		LIMIT 1
];
Map<String, Object> handoff = handoffRows.isEmpty()
		? new Map<String, Object>()
		: (Map<String, Object>)JSON.deserializeUntyped(handoffRows[0].kern__TextAreaLong__c);
String raisingJobText = (String)handoff.get('raisingJobId');
String launcherJobText = (String)handoff.get('launcherJobId');
Id raisingJobId = raisingJobText == null ? null : Id.valueOf(raisingJobText);
Id launcherJobId = launcherJobText == null ? null : Id.valueOf(launcherJobText);
String rowNamePrefix = (String)handoff.get('rowNamePrefix');
Integer rowCount = (Integer)handoff.get('rowCount');
String launchedAtText = (String)handoff.get('launchedAt');
// A saved row's change time has whole seconds, so the window opens one second before the start time 75c saved.
Datetime warnWindowStart = launchedAtText == null
		? Datetime.now()
		: ((Datetime)JSON.deserialize('"' + launchedAtText + '"', Datetime.class)).addSeconds(-1);

AsyncApexJob raisingJob = raisingJobId == null ? null
		: [SELECT Id, Status, NumberOfErrors, TotalJobItems, ApexClass.Name FROM AsyncApexJob WHERE Id = :raisingJobId];
AsyncApexJob launcherJob = launcherJobId == null ? null
		: [SELECT Id, Status, JobType, NumberOfErrors, TotalJobItems, ApexClass.Name FROM AsyncApexJob WHERE Id = :launcherJobId];

// Wait for the log entries: one ERROR per failed call of the raising job, and a size WARN row changed since the start.
Integer expectedErrorEntries = raisingJob == null ? 0 : raisingJob.NumberOfErrors;
List<kern__LogEntry__c> errorEntries = new List<kern__LogEntry__c>();
List<kern__LogEntry__c> warnEntries = new List<kern__LogEntry__c>();
String raisingJobPattern = raisingJobId == null ? null : String.valueOf(raisingJobId).left(15) + '%';
while(true)
{
	errorEntries =
	[
			SELECT Id,
					kern__ClassMethod__c,
					kern__Message__c,
					kern__ExceptionType__c,
					kern__ContextData__c,
					kern__RecordId__c
			FROM kern__LogEntry__c
			WHERE kern__RecordId__c LIKE :raisingJobPattern
			AND kern__LogLevel__c = :ERROR_LEVEL
	];
	warnEntries =
	[
			SELECT Id,
					kern__LogLevel__c,
					kern__Message__c,
					kern__ContextData__c
			FROM kern__LogEntry__c
			WHERE kern__Fingerprint__c LIKE :SCOPE_SIZE_KEY_PATTERN
			AND LastModifiedDate >= :warnWindowStart
	];
	Boolean allArrived = expectedErrorEntries > 0 && errorEntries.size() >= expectedErrorEntries && !warnEntries.isEmpty();
	if(allArrived || Limits.getCpuTime() >= LOG_WAIT_CPU_LIMIT_MILLISECONDS)
	{
		break;
	}
	Long waitUntil = System.currentTimeMillis() + LOG_WAIT_INTERVAL_MILLISECONDS;
	while(System.currentTimeMillis() < waitUntil && Limits.getCpuTime() < LOG_WAIT_CPU_LIMIT_MILLISECONDS)
	{
		Math.sqrt(2.0);
	}
}

// 75d-raising-job: the failing batch finished, and the platform counted its failed calls.
try
{
	Assert.isNotNull(raisingJob, '75d-raising-job: Expected the handoff row from section 75c to name the TST_RaisingBatch job; run 75c first');
	Assert.isTrue(FINISHED_JOB_STATUSES.contains(raisingJob.Status),
			'75d-raising-job: Expected the TST_RaisingBatch job to have finished, it reads ' + raisingJob.Status + '; wait longer and run 75d again');
	Assert.isTrue(raisingJob.NumberOfErrors >= 1, '75d-raising-job: Expected at least one failed call, got ' + raisingJob.NumberOfErrors);
	System.debug(LoggingLevel.INFO, '75d-raising-job PASS: the job finished ' + raisingJob.Status + ' with ' + raisingJob.NumberOfErrors
			+ ' failed calls out of ' + raisingJob.TotalJobItems);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '75d-raising-job FAIL: ' + scenarioError.getMessage());
	failures.add('75d-raising-job: ' + scenarioError.getMessage());
	fail++;
}

// 75d-error-log: one ERROR entry per failed call, each placed and linked as the batch failure trigger writes it.
try
{
	Assert.isTrue(expectedErrorEntries >= 1, '75d-error-log: Expected 75d-raising-job to have found failed calls to look the entries up by');
	Assert.areEqual(expectedErrorEntries, errorEntries.size(),
			'75d-error-log: Expected one ERROR entry per failed call of job ' + raisingJobId + '; none means the batch failure trigger did not log');
	for(kern__LogEntry__c entry : errorEntries)
	{
		Assert.isTrue(entry.kern__ClassMethod__c != null && entry.kern__ClassMethod__c.endsWith('TST_RaisingBatch/execute'),
				'75d-error-log: Expected the entry filed under TST_RaisingBatch/execute, got ' + entry.kern__ClassMethod__c);
		Assert.isTrue(entry.kern__Message__c != null && entry.kern__Message__c.contains(TST_RaisingBatch.FAILURE_MESSAGE),
				'75d-error-log: Expected the entry to carry the exception message, got ' + entry.kern__Message__c);
		Assert.isTrue(entry.kern__ExceptionType__c != null && entry.kern__ExceptionType__c.contains(RAISING_EXCEPTION_NAME),
				'75d-error-log: Expected the exception type to name ' + RAISING_EXCEPTION_NAME + ', got ' + entry.kern__ExceptionType__c);
		Map<String, Object> context = (Map<String, Object>)((Map<String, Object>)JSON.deserializeUntyped(entry.kern__ContextData__c)).get('contextData');
		Assert.areEqual(EXECUTE_PHASE, context.get('batchPhase'), '75d-error-log: Expected EXECUTE as the phase in the context, got ' + context);
	}
	System.debug(LoggingLevel.INFO, '75d-error-log PASS: ' + errorEntries.size() + ' ERROR entries filed under '
			+ errorEntries[0].kern__ClassMethod__c + ', linked to job ' + raisingJobId + ', phase EXECUTE');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '75d-error-log FAIL: ' + scenarioError.getMessage());
	failures.add('75d-error-log: ' + scenarioError.getMessage());
	fail++;
}

// 75d-size-warn: the launch wrote the batch-size WARN, with the size it read from the job setting.
try
{
	Assert.isFalse(warnEntries.isEmpty(),
			'75d-size-warn: Expected a batch-size WARN row for TST_SizeProbeHandler at size 75 changed since the start time 75c saved');
	for(kern__LogEntry__c warning : warnEntries)
	{
		Assert.areEqual(WARN_LEVEL, warning.kern__LogLevel__c, '75d-size-warn: Expected the entry at WARN');
		Assert.isTrue(warning.kern__Message__c.contains('Batch size 75') && warning.kern__Message__c.contains('chunk of 100')
				&& warning.kern__Message__c.contains('short run of 25'),
				'75d-size-warn: Expected the message to name size 75, the chunk of 100 and the short run of 25, got ' + warning.kern__Message__c);
		Map<String, Object> context = (Map<String, Object>)((Map<String, Object>)JSON.deserializeUntyped(warning.kern__ContextData__c)).get('contextData');
		Assert.areEqual(EXPECTED_SCOPE_SIZE, String.valueOf(context.get('scopeSize')), '75d-size-warn: Expected scopeSize 75 in the context, got ' + context);
		Assert.areEqual(EXPECTED_RETRIEVE_CHUNK, String.valueOf(context.get('retrieveChunk')), '75d-size-warn: Expected retrieveChunk 100, got ' + context);
		Assert.areEqual(EXPECTED_FITTING_SIZES, String.valueOf(context.get('fittingScopeSizes')),
				'75d-size-warn: Expected the fitting sizes 50, 100, got ' + context);
	}
	System.debug(LoggingLevel.INFO, '75d-size-warn PASS: the launch read size 75 from the job setting and warned: ' + warnEntries[0].kern__Message__c);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '75d-size-warn FAIL: ' + scenarioError.getMessage());
	failures.add('75d-size-warn: ' + scenarioError.getMessage());
	fail++;
}

// 75d-size-job: the launcher's batch ran at 75 a call over every row, with no failed call.
try
{
	Assert.isNotNull(launcherJob, '75d-size-job: Expected the handoff row from section 75c to name the launcher job; run 75c first');
	Assert.areEqual('Completed', launcherJob.Status, '75d-size-job: Expected the launcher job Completed, it reads ' + launcherJob.Status);
	Assert.areEqual(0, launcherJob.NumberOfErrors, '75d-size-job: Expected no failed call in the launcher job');
	Assert.isTrue(launcherJob.TotalJobItems >= MINIMUM_SIZE_JOB_CALLS,
			'75d-size-job: Expected at least ' + MINIMUM_SIZE_JOB_CALLS + ' calls at size 75, got ' + launcherJob.TotalJobItems
			+ ' (2 would mean the default size of 200 was used)');
	Integer tickedRows = [SELECT COUNT() FROM kern__Foobar__c WHERE Name LIKE :(rowNamePrefix + '%') AND kern__Checkbox__c = TRUE];
	Assert.areEqual(rowCount, tickedRows, '75d-size-job: Expected TST_SizeProbeHandler to tick every row');
	System.debug(LoggingLevel.INFO, '75d-size-job PASS: the launcher job (' + launcherJob.ApexClass.Name + ') ran ' + launcherJob.TotalJobItems
			+ ' calls over ' + tickedRows + ' rows with no failure');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '75d-size-job FAIL: ' + scenarioError.getMessage());
	failures.add('75d-size-job: ' + scenarioError.getMessage());
	fail++;
}

if(fail == 0)
{
	delete errorEntries;
	delete [SELECT Id FROM kern__LogEntry__c WHERE kern__Fingerprint__c LIKE :SCOPE_SIZE_KEY_PATTERN];
	delete [SELECT Id FROM kern__Foobar__c WHERE Name LIKE :(rowNamePrefix + '%')];
	delete handoffRows;
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 75d (Verify): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 75d (Verify) failed: ' + fail + ' scenarios');
}
