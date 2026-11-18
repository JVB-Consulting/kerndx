// SPDX-License-Identifier: Apache-2.0
/**
 * @description A background job that does nothing. The elastic limits probe queues it many times to use up the org's
 * daily allowance of background Apex jobs, so the probe can see what happens when little or none of the allowance is
 * left. It is deployed only to the probe's own org, from the probe's own temporary project.
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date November 2026
 */
@SuppressWarnings('PMD.QueueableWithoutFinalizer')
public with sharing class ElasticProbeFiller implements Queueable
{
	/**
	 * @description Does nothing. Each run still counts as one background job against the org's daily allowance, and
	 * that is the only reason the job exists.
	 *
	 * @param context The platform's context for the job; unused.
	 */
	public void execute(QueueableContext context)
	{
		return;
	}
}
