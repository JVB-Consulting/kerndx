/**
 * Section 75b: Queueable Unhandled-Exception Surfacing (Verify)
 *
 * Verification half of the section-75 launch + verify split. Section 75 enqueues a global async step
 * (TST_UnhandledThrowStep) through kern.UTIL_AsynchronousJobLauncher.process(...) that throws an
 * uncaught exception; this script asserts that the framework launcher SURFACED that unhandled
 * exception as a Failed AsyncApexJob (queueables have no platform auto-fired error event, so the
 * framework must not let the failure vanish silently). Mirrors the section 34 / 56 / 71 launch +
 * verify pattern: the queueable runs after the launching transaction commits.
 *
 * Two signals are checked. The AsyncApexJob's Failed status with the exception in ExtendedStatus
 * proves the launcher did not swallow the failure. The ERROR log entry the framework's finalizer
 * writes through logUnhandledException proves the failure reaches the Log Console. An earlier build
 * recorded that this finalizer entry did not persist in a subscriber org (RUNBOOK "Section 75 notes");
 * from 1.8 that is a FAIL line, and a FAIL is a framework defect to raise before promotion.
 *
 * Run-isolation is by the exception message: the failed step's ExtendedStatus carries
 * TST_UnhandledThrowStep.FAILURE_MESSAGE, so this run's job is found by that marker (most-recent
 * Failed queueable carrying the marker; re-runs accumulate jobs, most-recent + the marker disambiguate).
 *
 * Scenario coverage:
 *   - 75b: a Failed queueable AsyncApexJob carrying the step's failure marker exists — the framework
 *     launcher surfaced the unhandled exception instead of swallowing it.
 *   - 75b-identity: the surfaced job's ExtendedStatus carries the genuine exception message and the job is a
 *     Queueable — the exception identity survived the framework's async wrapper.
 *   - 75b-error-log: one ERROR log entry, filed under AsyncProcessorQueueable/logUnhandledException,
 *     linked to the failed job and carrying the step's failure message.
 *
 * Prerequisites:
 *   - Section 75 launch executed in this org within the last few minutes
 *   - At least ~30 seconds of wall-clock time elapsed since launch (queueable execution window)
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-75b-queueable-unhandled-exception-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 75b: Queueable Unhandled-Exception Surfacing (Verify) ===');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String FAILURE_MARKER_75 = TST_UnhandledThrowStep.FAILURE_MESSAGE;
final String JOB_TYPE_QUEUEABLE = 'Queueable';
final String JOB_STATUS_FAILED = 'Failed';

// This run's surfaced job — the most-recent Failed queueable whose ExtendedStatus carries the step's
// failure marker.
Datetime recentWindow = Datetime.now().addMinutes(-15);
List<AsyncApexJob> surfacedJobs =
[
		SELECT Id,
				Status,
				JobType,
				ExtendedStatus,
				NumberOfErrors
		FROM AsyncApexJob
		WHERE JobType = :JOB_TYPE_QUEUEABLE
		AND Status = :JOB_STATUS_FAILED
		AND ExtendedStatus LIKE :('%' + FAILURE_MARKER_75 + '%')
		AND CreatedDate >= :recentWindow
		ORDER BY CreatedDate DESC
		LIMIT 1
];
AsyncApexJob runJob = surfacedJobs.isEmpty() ? null : surfacedJobs[0];

// Verify 75b — the framework launcher surfaced the unhandled exception as a Failed queueable job.
try
{
	Assert.isNotNull(runJob,
			'75b-verify: expected a Failed queueable AsyncApexJob carrying the TST_UnhandledThrowStep failure marker '
			+ '(the job may still be running — increase the wait, or confirm the step threw)');
	Assert.areEqual(JOB_STATUS_FAILED, runJob.Status, '75b-verify: the framework-launched step should surface as a Failed job, not be swallowed');
	System.debug(LoggingLevel.INFO, '75b-verify PASS: the framework launcher surfaced the unhandled exception as Failed AsyncApexJob ' + runJob.Id);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '75b-verify FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('75b-verify: ' + scenarioError.getMessage());
	fail++;
}

// Verify 75b-identity — the surfaced job preserves the genuine exception identity (the step's message) and is
// a Queueable (the framework's async wrapper carried the exception through intact).
try
{
	Assert.isNotNull(runJob, '75b-identity: depends on the 75b surfaced job');
	Assert.isTrue(runJob.ExtendedStatus != null && runJob.ExtendedStatus.contains(FAILURE_MARKER_75),
			'75b-identity: the surfaced job ExtendedStatus should carry the step exception message, got ' + runJob.ExtendedStatus);
	Assert.areEqual(JOB_TYPE_QUEUEABLE, runJob.JobType, '75b-identity: the surfaced job should be a Queueable launched by the framework');
	System.debug(LoggingLevel.INFO, '75b-identity PASS: the surfaced job preserved the exception identity ("' + runJob.ExtendedStatus + '")');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '75b-identity FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('75b-identity: ' + scenarioError.getMessage());
	fail++;
}

// Verify 75b-error-log: the framework wrote one ERROR log entry for the failed job. The queueable's finalizer (the
// code the platform runs after the job, even when it failed) calls logUnhandledException, which logs the exception at
// ERROR, filed under AsyncProcessorQueueable/logUnhandledException and linked to the failed job's id. The entry arrives
// through a platform event, so this check waits up to about eight seconds of processing time for it. If it never
// arrives, that is a framework defect to raise before the release is promoted, not a note.
final String ERROR_LEVEL = 'ERROR';
final String FINALIZER_LOCATION_PATTERN = '%AsyncProcessorQueueable%logUnhandledException%';
final Integer LOG_WAIT_INTERVAL_MILLISECONDS = 2000;
final Integer LOG_WAIT_CPU_LIMIT_MILLISECONDS = 8000;
try
{
	Assert.isNotNull(runJob, '75b-error-log: Expected the Failed job from 75b-verify to look its log entry up by');
	String jobIdPattern = String.valueOf(runJob.Id).left(15) + '%';
	List<kern__LogEntry__c> errorEntries = new List<kern__LogEntry__c>();
	while(true)
	{
		errorEntries =
		[
				SELECT Id,
						kern__LogLevel__c,
						kern__ClassMethod__c,
						kern__Message__c,
						kern__RecordId__c
				FROM kern__LogEntry__c
				WHERE kern__RecordId__c LIKE :jobIdPattern
				AND kern__LogLevel__c = :ERROR_LEVEL
				AND kern__ClassMethod__c LIKE :FINALIZER_LOCATION_PATTERN
		];
		if(!errorEntries.isEmpty() || Limits.getCpuTime() >= LOG_WAIT_CPU_LIMIT_MILLISECONDS)
		{
			break;
		}
		Long waitUntil = System.currentTimeMillis() + LOG_WAIT_INTERVAL_MILLISECONDS;
		while(System.currentTimeMillis() < waitUntil && Limits.getCpuTime() < LOG_WAIT_CPU_LIMIT_MILLISECONDS)
		{
			Math.sqrt(2.0);
		}
	}
	Assert.areEqual(1, errorEntries.size(), '75b-error-log: Expected one ERROR entry from logUnhandledException linked to job ' + runJob.Id
			+ '; none means the finalizer log did not persist, a framework defect to raise before promotion');
	Assert.isTrue(errorEntries[0].kern__Message__c != null && errorEntries[0].kern__Message__c.contains(FAILURE_MARKER_75),
			'75b-error-log: Expected the ERROR entry to carry the step exception message, got ' + errorEntries[0].kern__Message__c);
	System.debug(LoggingLevel.INFO, '75b-error-log PASS: the finalizer wrote one ERROR entry (' + errorEntries[0].kern__ClassMethod__c
			+ ') linked to job ' + runJob.Id);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '75b-error-log FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('75b-error-log: ' + scenarioError.getMessage());
	fail++;
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 75b (Verify): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 75b (Verify) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 75b (Verify) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 75b (Verify) COMPLETE: All scenarios verified ===');
}
