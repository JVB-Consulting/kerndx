// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernLimitsThroughWrapperNegative
{
	public Integer readQueries()
	{
		return UTIL_Limits.soqlQueries().used();
	}

	public Boolean isQueueableQueueFull()
	{
		return UTIL_Limits.queueableJobs().isExhausted();
	}

	public Integer readDmlStatementsRemaining()
	{
		return kern.UTIL_Limits.dmlStatements().remaining();
	}

	public Integer readFromMapNamedLimits()
	{
		Map<String, Integer> limits = new Map<String, Integer>{ 'x' => 1 };
		return limits.get('x');
	}
}
