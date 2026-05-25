// Tier 1 anonymous Apex demonstration for Fast Start - Test Data.
// Run from: Developer Console > Debug > Open Execute Anonymous Window
// Or:  sf apex run --file release-testing/scripts/fast-start-test-data.apex -o YourOrgAlias
//
// Cleanup: the Account created below is deleted at the end of this script.
// All kern.TST_* calls here use only global methods (safe from anonymous Apex).

// --- Build and insert a single Account with one field override ---
// Phone is set to satisfy subscriber-side Account validation rules — adjust to suit your org.
Account newAccount = (Account)kern.TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Industry, 'Technology')
	.withOverride(Account.Phone, '555-0100')
	.build();

System.debug('Account.Id    : ' + newAccount.Id);
System.debug('Account.Name  : ' + newAccount.Name);
System.debug('Account.Industry: ' + newAccount.Industry);

// --- Bulk: 3 accounts with cycling industry values ---
List<SObject> bulkAccounts = kern.TST_Builder.of(Account.SObjectType)
	.withCycle(Account.Industry, new List<Object>{ 'Technology', 'Finance', 'Healthcare' })
	.withOverride(Account.Phone, '555-0100')
	.withCount(3)
	.buildList();

System.debug('Bulk count: ' + bulkAccounts.size());
for(SObject account : bulkAccounts)
{
	System.debug('Bulk.Id=' + account.Id + ' Industry=' + account.get('Industry'));
}

// --- In-memory only (no DML, no Id) ---
Account inMemory = (Account)kern.TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Name, 'In-Memory Co')
	.withoutInsertion()
	.build();

System.debug('In-memory Id (should be null): ' + inMemory.Id);

// --- In-memory with mock Id (no DML, but Id is populated) ---
Account mockIdAccount = (Account)kern.TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Name, 'Mock Id Co')
	.withoutInsertion(true)
	.build();

System.debug('Mock Id (not null): ' + mockIdAccount.Id);

// --- Cleanup: delete the 4 inserted records (single + 3 bulk) ---
List<Id> toDelete = new List<Id>();
toDelete.add(newAccount.Id);
for(SObject account : bulkAccounts)
{
	toDelete.add(account.Id);
}

List<SObject> deleteTargets = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.condition(Account.Id).isIn(toDelete)
	.toList();

kern.DML_Builder.newTransaction().doDelete(deleteTargets).execute();
System.debug('Cleanup complete. Deleted ' + deleteTargets.size() + ' accounts.');
