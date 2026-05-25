// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests DML_Builder.async() from subscriber code. Verifies that async DML
 * insert, bulk insert, and batch size configuration work through the managed package.
 *
 * @author your.name@company.com
 *
 * @group DML
 *
 * @date March 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class SubscriberAsyncDml_TEST
{
	/**
	 * @description Tests async insert of a single record.
	 */
	@IsTest
	private static void shouldInsertRecordAsynchronously()
	{
		kern.TRG_Base.bypass(Schema.Account.SObjectType);

		Account account = new Account(Name = 'Async DML Test', Industry = 'Technology');

		Test.startTest();
		kern.DML_Builder.newTransaction()
				.doInsert(Account)
				.async()
				.execute();
		Test.stopTest();

		List<Account> results =
		[
				SELECT Name,
						Industry
				FROM Account
				WHERE Name = 'Async DML Test'
		];

		Assert.isFalse(results.isEmpty(), 'Async insert should create the record');
		Assert.areEqual('Technology', results[0].Industry, 'Industry should match');
	}

	/**
	 * @description Tests async insert of multiple records in bulk.
	 */
	@IsTest
	private static void shouldInsertMultipleRecordsAsynchronously()
	{
		kern.TRG_Base.bypass(Schema.Account.SObjectType);

		List<Account> accounts = new List<Account>();
		for(Integer i = 0; i < 5; i++)
		{
			accounts.add(new Account(Name = 'Async Bulk ' + i, Industry = 'Finance'));
		}

		Test.startTest();
		kern.DML_Builder.newTransaction()
				.doInsert(accounts)
				.async()
				.execute();
		Test.stopTest();

		List<Account> results =
		[
				SELECT Name
				FROM Account
				WHERE Name LIKE 'Async Bulk %'
				ORDER BY Name
		];

		Assert.areEqual(5, results.size(), 'Async bulk insert should create all 5 records');
	}

	/**
	 * @description Tests async insert with explicit batch size configuration.
	 */
	@IsTest
	private static void shouldInsertWithBatchSize()
	{
		kern.TRG_Base.bypass(Schema.Account.SObjectType);

		List<Account> accounts = new List<Account>();
		for(Integer i = 0; i < 3; i++)
		{
			accounts.add(new Account(Name = 'Async Batch ' + i, Industry = 'Healthcare'));
		}

		Test.startTest();
		kern.DML_Builder.newTransaction()
				.doInsert(accounts)
				.async()
				.withBatchSize(200)
				.execute();
		Test.stopTest();

		List<Account> results =
		[
				SELECT Name
				FROM Account
				WHERE Name LIKE 'Async Batch %'
		];

		Assert.areEqual(3, results.size(), 'Async insert with batch size should create all records');
	}
}
