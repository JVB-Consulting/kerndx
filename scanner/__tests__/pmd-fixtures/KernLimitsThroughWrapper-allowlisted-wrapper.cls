// SPDX-License-Identifier: BUSL-1.1
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
