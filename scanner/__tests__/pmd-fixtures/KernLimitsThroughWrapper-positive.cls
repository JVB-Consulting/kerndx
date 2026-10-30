// SPDX-License-Identifier: Apache-2.0
public with sharing class KernLimitsThroughWrapperPositive
{
	public Integer readQueries()
	{
		return Limits.getQueries();
	}

	public Boolean isQueueableQueueFull()
	{
		return Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs();
	}

	public Integer readDmlStatementsQualified()
	{
		return System.Limits.getDmlStatements();
	}

	public with sharing class UTIL_Limits
	{
		public Integer readCpuTime()
		{
			return Limits.getCpuTime();
		}
	}
}
