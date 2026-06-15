// Fast Start - DML: Tier 1 verification script
// Run from: Developer Console > Debug > Open Execute Anonymous Window
// Expected: all three System.debug lines print true / an Id / true

// 1. Simple insert
// Populate Phone and Industry to satisfy any subscriber-side Account validation rules.
Account demoAccount = new Account(Name = 'Fast Start DML Demo', Phone = '555-0100', Industry = 'Technology');

kern.DML_Builder.TransactionResult insertResult = kern.DML_Builder.newTransaction()
		.doInsert(demoAccount)
		.execute();

System.debug('Insert success: ' + insertResult.isSuccess());
System.debug('Account Id: ' + demoAccount.Id);

// 2. Parent-child insert — Contact.AccountId is set automatically after Account inserts
Contact demoContact = new Contact(LastName = 'Demo');

kern.DML_Builder.newTransaction()
		.doInsert(demoContact, Contact.AccountId, demoAccount)
		.execute();

System.debug('Contact AccountId matches Account Id: ' + (demoContact.AccountId == demoAccount.Id));

// 3. Cleanup — delete the Account; the linked Contact is cascade-deleted automatically.
kern.DML_Builder.newTransaction()
		.doDelete(demoAccount)
		.execute();

System.debug('Cleanup complete');
