// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernNoRawEnqueueJob_Negative
{
	public static void enqueueThroughLauncher(List<Object> items, kern.IF_Async.Processable processor)
	{
		UTIL_AsynchronousJobLauncher.process(items, processor);
		kern.UTIL_AsynchronousJobLauncher.process(items, processor);
	}
}
