// =============================================================================
// Section 14: DML_Builder — Transaction Management
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern managed package installed
//   - Account trigger bypassed to avoid interference
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-14-dml-builder.apex
// =============================================================================

kern.TRG_Base.bypass(Schema.Account.SObjectType);
kern.TRG_Base.bypass('Contact');

List<Id> cleanupAccountIds = new List<Id>();
List<Id> cleanupContactIds = new List<Id>();

try
{
	// Test 14a: Basic insert via DML_Builder
	{
		Account account = new Account(Name = 'DML Builder 14a', Industry = 'Technology');

		kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
				.doInsert(account)
				.execute();

		System.assert(result.isSuccess(), '14a FAIL: Transaction should succeed');
		System.assert(account.Id != null, '14a FAIL: Account should have an Id after insert');
		cleanupAccountIds.add(account.Id);

		List<Id> insertedIds = result.getInsertedIds();
		System.assert(!insertedIds.isEmpty(), '14a FAIL: getInsertedIds() should return the new Id');
		System.debug('14a PASS: Basic DML_Builder insert succeeded, Id: ' + account.Id);
	}

	// Test 14b: Parent-child chaining — Contact auto-linked to Account
	{
		Account parentAccount = new Account(Name = 'DML Parent 14b', Industry = 'Finance');
		Contact childContact = new Contact(LastName = 'DML Child 14b');

		kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
				.doInsert(parentAccount)
				.doInsert(childContact, Schema.Contact.AccountId, parentAccount)
				.execute();

		System.assert(result.isSuccess(), '14b FAIL: Transaction should succeed');
		System.assert(parentAccount.Id != null, '14b FAIL: Account should have an Id');
		System.assert(childContact.Id != null, '14b FAIL: Contact should have an Id');
		cleanupAccountIds.add(parentAccount.Id);
		cleanupContactIds.add(childContact.Id);

		Contact queriedContact =
		[
				SELECT AccountId
				FROM Contact
				WHERE Id = :childContact.Id
		];
		System.assertEquals(parentAccount.Id, queriedContact.AccountId, '14b FAIL: Contact AccountId should be auto-set to parent Account Id');
		System.debug('14b PASS: Parent-child chaining correctly set Contact.AccountId to Account.Id');
	}

	// Test 14c: Multi-operation transaction — insert + update in one execution
	{
		Account account = new Account(Name = 'DML Multi 14c', Industry = 'Technology');

		kern.DML_Builder.TransactionResult insertResult = kern.DML_Builder.newTransaction()
				.doInsert(account)
				.execute();

		System.assert(insertResult.isSuccess(), '14c FAIL: Insert should succeed');
		cleanupAccountIds.add(account.Id);

		account.Description = 'Updated via DML_Builder';

		kern.DML_Builder.TransactionResult updateResult = kern.DML_Builder.newTransaction()
				.doUpdate(account)
				.execute();

		System.assert(updateResult.isSuccess(), '14c FAIL: Update should succeed');

		Account result =
		[
				SELECT Description
				FROM Account
				WHERE Id = :account.Id
		];
		System.assertEquals('Updated via DML_Builder', result.Description, '14c FAIL: Description should be updated');
		System.debug('14c PASS: Insert + Update via DML_Builder both succeeded');
	}

	// Test 14d: TransactionResult — success/failure counts
	{
		List<Account> accounts = new List<Account>();
		for(Integer i = 0; i < 3; i++)
		{
			accounts.add(new Account(Name = 'DML Batch 14d-' + i, Industry = 'Technology'));
		}

		kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
				.doInsert(accounts)
				.execute();

		System.assert(result.isSuccess(), '14d FAIL: Batch insert should succeed');
		System.assertEquals(3, result.getSuccessCount(), '14d FAIL: Success count should be 3');
		System.assertEquals(0, result.getFailureCount(), '14d FAIL: Failure count should be 0');
		System.assert(result.getErrors().isEmpty(), '14d FAIL: No errors expected');

		for(Account account : accounts)
		{
			cleanupAccountIds.add(account.Id);
		}
		System.debug('14d PASS: TransactionResult reports correct success/failure counts');
	}

	// Test 14e: Delete via DML_Builder
	{
		Account account = new Account(Name = 'DML Delete 14e', Industry = 'Technology');
		insert account;

		kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
				.doDelete(account)
				.execute();

		System.assert(result.isSuccess(), '14e FAIL: Delete should succeed');

		List<Account> remaining =
		[
				SELECT Id
				FROM Account
				WHERE Id = :account.Id
		];
		System.assert(remaining.isEmpty(), '14e FAIL: Account should be deleted');
		System.debug('14e PASS: DML_Builder delete removed record');
	}

	// Test 14f: Multiple parent-child chains in one transaction
	{
		Account parent1 = new Account(Name = 'DML Parent1 14f', Industry = 'Technology');
		Account parent2 = new Account(Name = 'DML Parent2 14f', Industry = 'Finance');
		Contact child1 = new Contact(LastName = 'Child of Parent1 14f');
		Contact child2 = new Contact(LastName = 'Child of Parent2 14f');

		kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
				.doInsert(parent1)
				.doInsert(parent2)
				.doInsert(child1, Schema.Contact.AccountId, parent1)
				.doInsert(child2, Schema.Contact.AccountId, parent2)
				.execute();

		System.assert(result.isSuccess(), '14f FAIL: Multi-chain transaction should succeed');
		cleanupAccountIds.add(parent1.Id);
		cleanupAccountIds.add(parent2.Id);
		cleanupContactIds.add(child1.Id);
		cleanupContactIds.add(child2.Id);

		Contact c1 =
		[
				SELECT AccountId
				FROM Contact
				WHERE Id = :child1.Id
		];
		Contact c2 =
		[
				SELECT AccountId
				FROM Contact
				WHERE Id = :child2.Id
		];
		System.assertEquals(parent1.Id, c1.AccountId, '14f FAIL: Contact1 should belong to Account1');
		System.assertEquals(parent2.Id, c2.AccountId, '14f FAIL: Contact2 should belong to Account2');
		System.debug('14f PASS: Multiple parent-child chains correctly linked in single transaction');
	}

	// Test 14g: Bulk-200 boundary — TransactionResult.getSuccessCount() == 200
	{
		List<Account> bulkAccounts = new List<Account>();
		for(Integer i = 0; i < 200; i++)
		{
			bulkAccounts.add(new Account(Name = 'DML Bulk 14g-' + i, Industry = 'Technology'));
		}

		kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
				.doInsert(bulkAccounts)
				.execute();

		System.assert(result.isSuccess(), '14g FAIL: Bulk transaction should succeed');
		System.assertEquals(200, result.getSuccessCount(), '14g FAIL: getSuccessCount should be 200, got: ' + result.getSuccessCount());
		System.assertEquals(0, result.getFailureCount(), '14g FAIL: getFailureCount should be 0, got: ' + result.getFailureCount());
		System.assert(result.getErrors().isEmpty(), '14g FAIL: No errors expected on bulk insert');

		for(Account account : bulkAccounts)
		{
			cleanupAccountIds.add(account.Id);
		}
		System.debug('14g PASS: DML_Builder bulk-200 insert succeeded — getSuccessCount()=200, getFailureCount()=0');
	}

	System.debug('=== Section 14 COMPLETE: All DML_Builder tests passed ===');
}
finally
{
	kern.TRG_Base.clearAllBypasses();

	if(!cleanupContactIds.isEmpty())
	{
		delete
		[
				SELECT Id
				FROM Contact
				WHERE Id IN :cleanupContactIds
		];
	}
	if(!cleanupAccountIds.isEmpty())
	{
		List<Task> tasks =
		[
				SELECT Id
				FROM Task
				WHERE WhatId IN :cleanupAccountIds
		];
		if(!tasks.isEmpty()) delete tasks;
		delete
		[
				SELECT Id
				FROM Account
				WHERE Id IN :cleanupAccountIds
		];
		System.debug('Cleanup: Deleted test records');
	}
}
