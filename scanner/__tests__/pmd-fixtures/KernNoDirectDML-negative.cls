// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernNoDirectDML_Negative
{
	public static void writeThroughBuilder(List<Account> accounts)
	{
		DML_Builder.newTransaction().doInsert(accounts).commitWork();
		kern.DML_Builder.newTransaction().doUpdate(accounts).commitWork();
	}
}
