// SPDX-License-Identifier: Apache-2.0
/**
 * @description Release-test asynchronous step that throws an unhandled exception from `execute()` to
 * exercise the framework's queueable error-surfacing path. When this step is run through
 * `kern.UTIL_AsynchronousJobLauncher.process(...)`, the managed `AsyncProcessorQueueable` runs it and
 * the uncaught exception leaves the queueable Failed with the exception captured in
 * `AsyncApexJob.ExtendedStatus`. Queueables have no failure event from the platform (batch jobs do), so
 * the framework must report the failure itself: the queueable's finalizer (the code the platform runs
 * after the job, even when it failed) calls `logUnhandledException`, which writes one ERROR log entry
 * linked to the failed job. Section 75b checks both: the Failed job, and that ERROR entry.
 *
 * @author Jason van Beukering
 *
 * @group Release Testing
 *
 * @date June 2026, October 2026
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
