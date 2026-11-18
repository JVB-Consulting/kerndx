// SPDX-License-Identifier: Apache-2.0
/**
 * @description A background job that keeps the processor busy for about four seconds and does nothing else. The
 * elastic limits probe queues ten of them at once to see whether the platform makes them wait (throttles them) once
 * the org has used its daily allowance of background Apex jobs. Each job's own job row is the measurement: it writes
 * nothing and logs nothing. It is deployed only to the probe's own org, from the probe's own temporary project.
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date November 2026
 */
@SuppressWarnings('PMD.QueueableWithoutFinalizer')
public with sharing class ElasticProbeSlowFiller implements Queueable
{
	/**
	 * @description How long the job keeps the processor busy, in milliseconds of processor time.
	 */
	private static final Integer BUSY_MILLISECONDS = 4000;

	/**
	 * @description Keeps the processor busy until the job has used four seconds of processor time, then returns.
	 *
	 * @param context The platform's context for the job; unused.
	 */
	public void execute(QueueableContext context)
	{
		Integer rounds = 0;
		while(Limits.getCpuTime() < BUSY_MILLISECONDS)
		{
			rounds++;
		}
	}
}
