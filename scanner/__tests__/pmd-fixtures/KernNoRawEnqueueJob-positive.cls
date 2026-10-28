// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernNoRawEnqueueJob_Positive
{
	public static void enqueueRaw(Queueable job)
	{
		Id jobId = System.enqueueJob(job);
		System.enqueueJob(job, 5);
	}
}
