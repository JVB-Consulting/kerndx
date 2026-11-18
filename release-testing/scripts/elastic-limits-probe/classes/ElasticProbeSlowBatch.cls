// SPDX-License-Identifier: Apache-2.0
/**
 * @description A batch job over three numbers, run one number at a time. Each of its three parts keeps the processor
 * busy for about four seconds and does nothing else. The elastic limits probe starts two of them back to back to see
 * whether the platform makes the second wait for the first once the org has used its daily allowance of background
 * Apex jobs. Each job's own job row is the measurement: it writes nothing and logs nothing. It is deployed only to the
 * probe's own org, from the probe's own temporary project.
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date November 2026
 */
public with sharing class ElasticProbeSlowBatch implements Database.Batchable<Integer>
{
	/**
	 * @description How long each part keeps the processor busy, in milliseconds of processor time.
	 */
	private static final Integer BUSY_MILLISECONDS = 4000;

	/**
	 * @description Gives the batch its three numbers. Started with a size of 1, the batch runs three parts.
	 *
	 * @param context The platform's context for the batch; unused.
	 *
	 * @return The numbers 1, 2 and 3.
	 */
	public Iterable<Integer> start(Database.BatchableContext context)
	{
		return new List<Integer> {1, 2, 3};
	}

	/**
	 * @description Keeps the processor busy until this part has used four seconds of processor time, then returns.
	 *
	 * @param context The platform's context for the batch; unused.
	 *
	 * @param numbers The numbers in this part; unused.
	 */
	public void execute(Database.BatchableContext context, List<Integer> numbers)
	{
		Integer rounds = 0;
		while(Limits.getCpuTime() < BUSY_MILLISECONDS)
		{
			rounds++;
		}
	}

	/**
	 * @description Does nothing. The batch's job row records when it ended.
	 *
	 * @param context The platform's context for the batch; unused.
	 */
	public void finish(Database.BatchableContext context)
	{
		return;
	}
}
