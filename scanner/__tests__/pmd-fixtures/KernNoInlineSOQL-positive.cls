// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernNoInlineSOQL_Positive
{
	public static void queryRaw()
	{
		List<Account> accounts = [SELECT Id FROM Account];
		List<SObject> dynamic = Database.query('SELECT Id FROM Account');
		List<SObject> bound = Database.queryWithBinds('SELECT Id FROM Account', new Map<String, Object>(), AccessLevel.USER_MODE);
		Integer total = Database.countQuery('SELECT COUNT() FROM Account');
		Database.QueryLocator locator = Database.getQueryLocator('SELECT Id FROM Account');
		Database.Cursor cursor = Database.getCursor('SELECT Id FROM Account');
	}
}
