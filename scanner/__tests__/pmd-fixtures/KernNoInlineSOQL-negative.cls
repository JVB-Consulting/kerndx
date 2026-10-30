// SPDX-License-Identifier: Apache-2.0
public with sharing class KernNoInlineSOQL_Negative
{
	public static void queryThroughFramework()
	{
		List<Account> accounts = SEL_Accounts.newInstance().selectById(new Set<Id>());
		List<SObject> rows = kern.QRY_Builder.selectFrom(Account.SObjectType).toList();
	}
}
