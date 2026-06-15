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
 * Why the AsyncApexJob signal (not the framework error LOG): the framework Finalizer's
 * logUnhandledException emits a kern__LogEntry__c via a PublishImmediately LogEntryEvent__e, but on
 * the validated subscriber build that finalizer-context log does not persist in real async execution
 * (plain anon emits and synchronous trigger-error logs DO persist) — see RUNBOOK "Section 75 notes".
 * The AsyncApexJob's Failed status + the exception captured in ExtendedStatus is the reliable,
 * package-current proof that the framework launcher surfaced the unhandled exception with its identity
 * intact.
 *
 * Run-isolation is by the exception message: the failed step's ExtendedStatus carries
 * TST_UnhandledThrowStep.FAILURE_MESSAGE, so this run's job is found by that marker (most-recent
 * Failed queueable carrying the marker; re-runs accumulate jobs, most-recent + the marker disambiguate).
 *
 * Scenario coverage:
 *   - 75b: a Failed queueable AsyncApexJob carrying the step's failure marker exists — the framework
 *     launcher surfaced the unhandled exception instead of swallowing it.
 *   - 75c: the surfaced job's ExtendedStatus carries the genuine exception message and the job is a
 *     Queueable — the exception identity survived the framework's async wrapper.
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
			'75b-verify: expected a Failed queueable AsyncApexJob carrying the TST_UnhandledThrowStep failure marker (the job may still be running — increase the wait, or confirm the step threw)');
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

// Verify 75c — the surfaced job preserves the genuine exception identity (the step's message) and is
// a Queueable (the framework's async wrapper carried the exception through intact).
try
{
	Assert.isNotNull(runJob, '75c-verify: depends on the 75b surfaced job');
	Assert.isTrue(runJob.ExtendedStatus != null && runJob.ExtendedStatus.contains(FAILURE_MARKER_75),
			'75c-verify: the surfaced job ExtendedStatus should carry the step exception message, got ' + runJob.ExtendedStatus);
	Assert.areEqual(JOB_TYPE_QUEUEABLE, runJob.JobType, '75c-verify: the surfaced job should be a Queueable launched by the framework');
	System.debug(LoggingLevel.INFO, '75c-verify PASS: the surfaced job preserved the exception identity ("' + runJob.ExtendedStatus + '")');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '75c-verify FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('75c-verify: ' + scenarioError.getMessage());
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
