// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Release-test asynchronous step that throws an unhandled exception from `execute()` to
 * exercise the framework's queueable error-surfacing path. When this step is run through
 * `kern.UTIL_AsynchronousJobLauncher.process(...)`, the managed `AsyncProcessorQueueable` runs it and
 * the uncaught exception leaves the queueable Failed with the exception captured in
 * `AsyncApexJob.ExtendedStatus` — the reliable subscriber-observable signal that section 75/75b assert
 * (queueables have no platform auto-fired error event, unlike Batch, so the framework must surface the
 * failure). The framework Finalizer additionally attempts `logUnhandledException`, but that
 * finalizer-context `LogEntry` did not persist in real async execution on the validated build — see
 * the RUNBOOK "Section 75 notes".
 *
 * @author Jason van Beukering
 *
 * @group Release Testing
 *
 * @date June 2026
 */
global with sharing class TST_UnhandledThrowStep implements kern.IF_Async.Processable
{
	/**
	 * @description Message of the exception thrown to leave the queueable with an unhandled-exception
	 * result so the framework Finalizer logs it.
	 */
	public static final String FAILURE_MESSAGE = 'Intentional TST_UnhandledThrowStep release-test failure';

	/**
	 * @description Throws immediately so the managed `AsyncProcessorQueueable` finishes with an
	 * `UNHANDLED_EXCEPTION` result and its Finalizer records the framework error log.
	 *
	 * @param items The job-scope items supplied by the asynchronous launcher (carried into the log).
	 */
	global void execute(List<Object> items)
	{
		throw new IllegalArgumentException(FAILURE_MESSAGE);
	}
}
