// SPDX-License-Identifier: Apache-2.0
public inherited sharing class UTIL_Limits
{
	public static Integer readQueries()
	{
		return Limits.getQueries();
	}

	public inherited sharing class LimitCheck
	{
		public Integer maximum()
		{
			return System.Limits.getLimitQueries();
		}
	}
}
