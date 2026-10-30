// SPDX-License-Identifier: Apache-2.0
public with sharing class KernNoDirectDML_Positive
{
	public static void writeRaw(List<Account> accounts)
	{
		insert accounts;
		update accounts;
		upsert accounts;
		delete accounts;
		undelete accounts;
		merge accounts[0] accounts[1];
		Database.insert(accounts, false);
		Database.update(accounts);
		Database.emptyRecycleBin(accounts);
	}
}
