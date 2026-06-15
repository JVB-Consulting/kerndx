/**
 * Section 75: Queueable Unhandled-Exception Surfacing (Launch)
 *
 * Proves the subscriber-observable contract for unhandled exceptions in framework-run asynchronous
 * work: a queueable launched through kern.UTIL_AsynchronousJobLauncher.process(...) that throws an
 * uncaught exception is SURFACED as a Failed AsyncApexJob (with the exception captured in
 * ExtendedStatus) rather than vanishing silently. Queueables have no platform auto-fired error event
 * (unlike Batch jobs, which raise BatchApexErrorEvent), so the framework must surface the failure for
 * subscribers to observe.
 *
 * This guards the v67 queueable error path in UTIL_AdaptiveAsynchronousProcessor on a real Summer-'26
 * subscriber org: a managed-package async job that throws is coverage @IsTest cannot fully reach (a
 * queueable's unhandled exception in test context surfaces as a test failure, not the real
 * Finalizer/AsyncApexJob path).
 *
 * NOTE on the framework error LOG: the framework Finalizer's logUnhandledException additionally emits a
 * kern__LogEntry__c via a PublishImmediately LogEntryEvent__e. On the validated build that
 * finalizer-context log did NOT persist in real async execution (plain anon emits and synchronous
 * trigger-error logs DO persist), so this section asserts the reliable AsyncApexJob signal instead —
 * see RUNBOOK "Section 75 notes" for the finalizer-log observation.
 *
 * Launch + verify split (mirrors section 34 / 56 / 71): the queueable runs AFTER the launching
 * transaction commits, so a single execute-anonymous transaction cannot both enqueue the job and
 * observe its terminal status. Section 75 enqueues the throwing step here; section 75b asserts the
 * Failed AsyncApexJob after ~30s of execution time.
 *
 * Run-isolation: section 75b finds the most-recent Failed queueable whose ExtendedStatus carries
 * TST_UnhandledThrowStep.FAILURE_MESSAGE (re-runs accumulate jobs; most-recent + the marker disambiguate).
 *
 * Prerequisites:
 *   - subscriber scratch org with the kern managed package installed
 *   - TST_UnhandledThrowStep deployed (global step implementing kern.IF_Async.Processable that throws)
 *
 * Run (in two stages — separated by ~30s of queueable execution time):
 *   sf apex run --file release-testing/scripts/section-75-queueable-unhandled-exception.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *   (wait ~30 seconds for the queueable to run and fail)
 *   sf apex run --file release-testing/scripts/section-75b-queueable-unhandled-exception-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 75: Queueable Unhandled-Exception Logging (Launch) ===');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

// Scenario 75a (launch) — enqueue a global async step that throws uncaught via the public launcher.
// The managed AsyncProcessorQueueable runs the step; the uncaught exception leaves the job Failed with
// the exception captured in ExtendedStatus. The terminal assertion (the Failed AsyncApexJob carrying
// the exception identity) lives in section 75b after the job runs.
try
{
	List<Object> jobScopeItems = new List<Object>
	{
			'Section75_item_0',
			'Section75_item_1'
	};
	Id jobId = kern.UTIL_AsynchronousJobLauncher.process(jobScopeItems, new TST_UnhandledThrowStep());

	Assert.isNotNull(jobId, '75a-launch: the launcher should return an enqueued AsyncApexJob id');
	System.debug(LoggingLevel.INFO, '75a-launch PASS: enqueued the throwing async step (job ' + jobId
			+ '); it will surface as a Failed AsyncApexJob once it runs');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '75a-launch FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('75a-launch: ' + scenarioError.getMessage());
	fail++;
}

// No cleanup here — section 75b needs the delivered error log to exist for verification.

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 75 (Launch): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 75 (Launch) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 75 (Launch) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 75 (Launch) COMPLETE: throwing step enqueued. Run section 75b after ~30s to verify the Failed AsyncApexJob. ===');
}
