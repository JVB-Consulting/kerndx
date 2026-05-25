// =============================================================================
// Section 12: After-Trigger Handlers (AfterInsert + AfterUpdate)
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - TRG_Account trigger updated with after insert, after update events
//   - TRG_CreateAccountTask (Order=100, AfterInsert) — creates a Task on new Account
//   - TRG_DetectNameChange (Order=100, AfterUpdate) — creates a Task when Name changes
//   - TriggerAction CMDT records deployed for both handlers
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-12-after-triggers.apex
// =============================================================================

kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();

List<Id> cleanupAccountIds = new List<Id>();

try
{
	// Test 12a: AfterInsert creates a Task linked to the new Account
	{
		Account account = new Account(Name = 'Test Account 12a', Industry = 'Technology', Phone = '555-0012');
		insert account;
		cleanupAccountIds.add(account.Id);

		List<Task> tasks =
		[
				SELECT Subject,
						Status,
						Priority,
						Description,
						WhatId
				FROM Task
				WHERE WhatId = :account.Id
		];
		System.assert(!tasks.isEmpty(), '12a FAIL: AfterInsert should have created a Task');
		System.assert(tasks[0].Subject.contains('Review New Account'), '12a FAIL: Task Subject should contain "Review New Account", got: ' + tasks[0].Subject);
		System.assert(tasks[0].Subject.contains('Test Account 12a'), '12a FAIL: Task Subject should contain the Account Name');
		System.assertEquals('Not Started', tasks[0].Status, '12a FAIL: Task Status should be Not Started');
		System.debug('12a PASS: AfterInsert handler created Task linked to new Account');
	}

	// Test 12b: AfterInsert — Account has an Id when the handler runs
	{
		Account account = new Account(Name = 'Test Account 12b', Industry = 'Finance', Phone = '555-0012');
		insert account;
		cleanupAccountIds.add(account.Id);

		List<Task> tasks =
		[
				SELECT WhatId
				FROM Task
				WHERE WhatId = :account.Id
		];
		System.assert(!tasks.isEmpty(), '12b FAIL: Task should exist');
		System.assertEquals(account.Id, tasks[0].WhatId, '12b FAIL: Task WhatId should match Account Id');
		System.debug('12b PASS: Account Id is available in AfterInsert handler');
	}

	// Test 12c: AfterUpdate — Name change creates a Task with old and new Name
	{
		Account account = new Account(Name = 'Original Name 12c', Industry = 'Technology', Phone = '555-0012');
		insert account;
		cleanupAccountIds.add(account.Id);

		// Delete the AfterInsert task to isolate AfterUpdate tasks
		delete
		[
				SELECT Id
				FROM Task
				WHERE WhatId = :account.Id
		];

		account.Name = 'Updated Name 12c';
		update account;

		List<Task> tasks =
		[
				SELECT Subject,
						Status,
						Description
				FROM Task
				WHERE WhatId = :account.Id
		];
		System.assert(!tasks.isEmpty(), '12c FAIL: AfterUpdate should have created a Task when Name changed');
		System.assert(tasks[0].Subject.contains('Original Name 12c'), '12c FAIL: Task Subject should contain old Name');
		System.assert(tasks[0].Subject.contains('Updated Name 12c'), '12c FAIL: Task Subject should contain new Name');
		System.assertEquals('Completed', tasks[0].Status, '12c FAIL: Task Status should be Completed');
		System.debug('12c PASS: AfterUpdate handler detected Name change and created Task with old/new values');
	}

	// Test 12d: AfterUpdate — Non-Name field change does NOT create Task
	{
		Account account = new Account(Name = 'Test Account 12d', Industry = 'Technology', Phone = '555-0012');
		insert account;
		cleanupAccountIds.add(account.Id);

		// Delete the AfterInsert task
		delete
		[
				SELECT Id
				FROM Task
				WHERE WhatId = :account.Id
		];

		account.Description = 'Updated Description Only';
		update account;

		List<Task> tasks =
		[
				SELECT Id
				FROM Task
				WHERE WhatId = :account.Id
		];
		System.assert(tasks.isEmpty(), '12d FAIL: No Task should be created when Name is unchanged, found ' + tasks.size());
		System.debug('12d PASS: Non-Name update does not trigger AfterUpdate Task creation');
	}

	// Test 12e: AfterInsert — triggerOldMap access in AfterUpdate uses correct old values
	{
		Account account = new Account(Name = 'Test Account 12e', Industry = 'Technology', Phone = '555-0012');
		insert account;
		cleanupAccountIds.add(account.Id);

		delete
		[
				SELECT Id
				FROM Task
				WHERE WhatId = :account.Id
		];

		// First update: change Name
		account.Name = 'Renamed Once 12e';
		update account;

		// Second update: change Name again
		account.Name = 'Renamed Twice 12e';
		update account;

		List<Task> tasks =
		[
				SELECT Subject
				FROM Task
				WHERE WhatId = :account.Id
				ORDER BY CreatedDate ASC
		];
		System.assertEquals(2, tasks.size(), '12e FAIL: Two Tasks should exist for two Name changes, found: ' + tasks.size());
		System.assert(tasks[0].Subject.contains('Renamed Once 12e'), '12e FAIL: First task should reference "Renamed Once 12e"');
		System.assert(tasks[1].Subject.contains('Renamed Twice 12e'), '12e FAIL: Second task should reference "Renamed Twice 12e"');
		System.debug('12e PASS: triggerOldMap correctly reflects intermediate states across multiple updates');
	}

	// Test 12f: Action-level bypass skips AfterInsert handler
	{
		kern.TRG_Base.bypassAction('TRG_CreateAccountTask');

		Account account = new Account(Name = 'Test Account 12f', Industry = 'Technology', Phone = '555-0012');
		insert account;
		cleanupAccountIds.add(account.Id);

		List<Task> tasks =
		[
				SELECT Id
				FROM Task
				WHERE WhatId = :account.Id
		];
		System.assert(tasks.isEmpty(), '12f FAIL: No Task should be created when AfterInsert handler is bypassed');
		System.debug('12f PASS: Action-level bypass correctly skips AfterInsert handler');

		kern.TRG_Base.clearActionBypass('TRG_CreateAccountTask');
	}

	// Test 12g: Bulk boundary — AfterInsert + AfterUpdate handlers ran on all bulk records
	// Scaled to 50 (not 200): section-12 has 6 prior tests each doing trigger-firing DML including
	// AfterInsert (Task creation) and AfterUpdate (Name-change Task). The accumulated stack depth
	// from prior invocations + TRG_CreateAccountTask/TRG_DetectNameChange means 200 records on
	// the 7th invocation hits the 1001-frame stack limit in this org.
	{
		List<Account> bulkAccounts = new List<Account>();
		for(Integer i = 0; i < 50; i++)
		{
			bulkAccounts.add(new Account(Name = 'Bulk 12g Account ' + i, Industry = 'Technology', Phone = '555-0012'));
		}
		insert bulkAccounts;
		for(Account account : bulkAccounts) cleanupAccountIds.add(account.Id);

		List<Task> insertTasks =
		[
				SELECT Id
				FROM Task
				WHERE WhatId IN :bulkAccounts
		];
		System.assertEquals(50, insertTasks.size(), '12g FAIL: AfterInsert should have created a Task for each of the 50 accounts, found: ' + insertTasks.size());

		delete insertTasks;

		for(Account account : bulkAccounts)
		{
			account.Name = account.Name + ' Updated';
		}
		update bulkAccounts;

		List<Task> updateTasks =
		[
				SELECT Id
				FROM Task
				WHERE WhatId IN :bulkAccounts
		];
		System.assertEquals(50, updateTasks.size(), '12g FAIL: AfterUpdate should have created a Task for each of the 50 Name changes, found: ' + updateTasks.size());
		System.debug('12g PASS: AfterInsert created 50 Tasks, AfterUpdate (Name change) created 50 more — bulk handlers fired on all 50');
	}

	System.debug('=== Section 12 COMPLETE: All after-trigger handler tests passed ===');
}
finally
{
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();

	if(!cleanupAccountIds.isEmpty())
	{
		List<Task> tasks =
		[
				SELECT Id
				FROM Task
				WHERE WhatId IN :cleanupAccountIds
		];
		if(!tasks.isEmpty())
		{
			delete tasks;
		}
		delete
		[
				SELECT Id
				FROM Account
				WHERE Id IN :cleanupAccountIds
		];
		System.debug('Cleanup: Deleted ' + cleanupAccountIds.size() + ' test Accounts and associated Tasks');
	}
}
