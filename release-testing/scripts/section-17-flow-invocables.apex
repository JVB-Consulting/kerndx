// =============================================================================
// Section 17: Flow Invocable Methods
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern managed package installed
//   - Account trigger + handlers deployed
//
// Tests direct invocation of @InvocableMethod classes from subscriber code.
// These are the same methods that Flows call, tested programmatically.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-17-flow-invocables.apex
// =============================================================================

kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
// Bypass the flow trigger action — sections 41-44 cover that surface; this section tests Flow invocables (FLOW_*), not flow trigger actions
kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow');

List<Id> cleanupIds = new List<Id>();

try
{
	// Test 17a: FLOW_BypassTrigger — bypass object via invocable
	{
		kern.FLOW_BypassTrigger.DTO_Request request = new kern.FLOW_BypassTrigger.DTO_Request();
		request.action = 'BYPASS';
		request.bypassType = 'OBJECT_NAME';
		request.name = 'Account';

		kern.FLOW_BypassTrigger.execute(new List<kern.FLOW_BypassTrigger.DTO_Request> {request});

		Boolean isBypassed = kern.TRG_Base.isBypassed(Account.SObjectType);
		System.assert(isBypassed, '17a FAIL: Account should be bypassed after FLOW_BypassTrigger');

		// Insert should work without trigger effects
		Account account = new Account(Name = 'Flow Bypass 17a', Industry = 'Technology');
		insert account;
		cleanupIds.add(account.Id);

		Account result =
		[
				SELECT Description,
						AccountSource
				FROM Account
				WHERE Id = :account.Id
		];
		System.assert(result.Description == null || result.Description != 'Default', '17a FAIL: Description should NOT be defaulted when bypassed');

		System.debug('17a PASS: FLOW_BypassTrigger correctly bypasses Account triggers');
	}

	// Test 17b: FLOW_BypassTrigger — clear bypass via invocable
	{
		kern.FLOW_BypassTrigger.DTO_Request request = new kern.FLOW_BypassTrigger.DTO_Request();
		request.action = 'CLEAR';
		request.bypassType = 'OBJECT_NAME';
		request.name = 'Account';

		kern.FLOW_BypassTrigger.execute(new List<kern.FLOW_BypassTrigger.DTO_Request> {request});

		Boolean isBypassed = kern.TRG_Base.isBypassed(Account.SObjectType);
		System.assert(!isBypassed, '17b FAIL: Account should NOT be bypassed after CLEAR');

		// Insert should trigger handlers — provide Description to satisfy validation rule
		// (validation fires before SetAccountDefaults). Verify via AccountSource (set by StampAccountSource)
		Account account = new Account(Name = 'Flow Clear 17b', Industry = 'Technology', Phone = '555-1700', Description = 'Provided');
		insert account;
		cleanupIds.add(account.Id);

		Account result =
		[
				SELECT Description,
						AccountSource
				FROM Account
				WHERE Id = :account.Id
		];
		System.assertEquals('Subscriber Trigger', result.AccountSource, '17b FAIL: StampAccountSource should fire after bypass cleared');

		System.debug('17b PASS: FLOW_BypassTrigger CLEAR correctly restores trigger execution');
	}

	// Test 17c: FLOW_BypassTrigger — bypass specific action class
	{
		kern.FLOW_BypassTrigger.DTO_Request request = new kern.FLOW_BypassTrigger.DTO_Request();
		request.action = 'BYPASS';
		request.bypassType = 'CLASS_NAME';
		request.name = 'TRG_SetAccountDefaults';

		kern.FLOW_BypassTrigger.execute(new List<kern.FLOW_BypassTrigger.DTO_Request> {request});

		Boolean isActionBypassed = kern.TRG_Base.isActionBypassed('TRG_SetAccountDefaults');
		System.assert(isActionBypassed, '17c FAIL: TRG_SetAccountDefaults should be action-bypassed');

		// Provide Description to satisfy validation — since SetDefaults is bypassed, it should NOT be overwritten
		Account account = new Account(Name = 'Flow Action Bypass 17c', Industry = 'Technology', Phone = '555-1700', Description = 'ProvidedNotDefault');
		insert account;
		cleanupIds.add(account.Id);

		Account result =
		[
				SELECT Description,
						AccountSource
				FROM Account
				WHERE Id = :account.Id
		];
		System.assertEquals('ProvidedNotDefault', result.Description, '17c FAIL: Description should NOT be overwritten when SetAccountDefaults is bypassed');
		System.assertEquals('Subscriber Trigger', result.AccountSource, '17c FAIL: StampAccountSource should still fire');

		kern.TRG_Base.clearAllActionBypasses();
		System.debug('17c PASS: FLOW_BypassTrigger CLASS_NAME bypass correctly skips specific handler');
	}

	// Test 17d: FLOW_CheckFeatureFlag — check flag status
	{
		List<Boolean> results = kern.FLOW_CheckFeatureFlag.isEnabled(new List<String> {'DisableAllOutboundAPIs'});

		System.assert(!results.isEmpty(), '17d FAIL: Should return a result');
		System.assert(results[0] == true || results[0] == false, '17d FAIL: Should return a Boolean');
		System.debug('17d PASS: FLOW_CheckFeatureFlag returns Boolean for DisableAllOutboundAPIs: ' + results[0]);
	}

	// Test 17e: FLOW_CheckTriggerBypassed — check bypass state
	{
		// First, bypass Account
		kern.TRG_Base.bypass(Account.SObjectType);

		kern.FLOW_CheckTriggerBypassed.DTO_Request request = new kern.FLOW_CheckTriggerBypassed.DTO_Request();
		request.bypassType = 'OBJECT_NAME';
		request.name = 'Account';

		List<Boolean> results = kern.FLOW_CheckTriggerBypassed.isBypassed(
				new List<kern.FLOW_CheckTriggerBypassed.DTO_Request> {request}
		);

		System.assert(!results.isEmpty(), '17e FAIL: Should return a result');
		System.assert(results[0], '17e FAIL: Account should be reported as bypassed');

		kern.TRG_Base.clearAllBypasses();

		results = kern.FLOW_CheckTriggerBypassed.isBypassed(
				new List<kern.FLOW_CheckTriggerBypassed.DTO_Request> {request}
		);

		System.assert(!results[0], '17e FAIL: Account should NOT be bypassed after clear');
		System.debug('17e PASS: FLOW_CheckTriggerBypassed correctly reports bypass state');
	}

	// Test 17f: FLOW_BypassValidation — bypass validation rules
	// FINDING: FLOW_BypassValidation.DTO_Request has only bypassType + name (no action field).
	// The invocable only bypasses — clearing must be done via UTIL_ValidationRule directly.
	{
		kern.FLOW_BypassValidation.DTO_Request request = new kern.FLOW_BypassValidation.DTO_Request();
		request.bypassType = 'OBJECT_NAME';
		request.name = 'Account';

		kern.FLOW_BypassValidation.bypass(new List<kern.FLOW_BypassValidation.DTO_Request> {request});

		Boolean isBypassed = kern.UTIL_ValidationRule.isBypassed('Account');
		System.assert(isBypassed, '17f FAIL: Account validation should be bypassed');

		// Insert without Industry should succeed (validation bypassed)
		Account account = new Account(Name = 'Flow Val Bypass 17f', Phone = '555-1700');
		insert account;
		cleanupIds.add(account.Id);

		// Clear via UTIL_ValidationRule (no FLOW invocable for clearing)
		kern.UTIL_ValidationRule.clearAllBypasses();

		System.assert(!kern.UTIL_ValidationRule.isBypassed('Account'), '17f FAIL: Validation bypass should be cleared');

		System.debug('17f PASS: FLOW_BypassValidation correctly bypasses validation rules');
	}

	// Test 17g: FLOW_BypassTrigger — CLEAR_ALL action
	{
		// Set up multiple bypasses
		kern.TRG_Base.bypass(Account.SObjectType);
		kern.TRG_Base.bypassAction('TRG_SetAccountDefaults');

		System.assert(kern.TRG_Base.isBypassed(Account.SObjectType), '17g setup FAIL: Account should be bypassed');

		kern.FLOW_BypassTrigger.DTO_Request request = new kern.FLOW_BypassTrigger.DTO_Request();
		request.action = 'CLEAR_ALL';
		request.bypassType = 'OBJECT_NAME';
		request.name = 'Account';

		kern.FLOW_BypassTrigger.execute(new List<kern.FLOW_BypassTrigger.DTO_Request> {request});

		System.assert(!kern.TRG_Base.isBypassed(Account.SObjectType), '17g FAIL: All object bypasses should be cleared');
		System.debug('17g PASS: FLOW_BypassTrigger CLEAR_ALL clears all object bypasses');

		kern.TRG_Base.clearAllActionBypasses();
	}

	// Test 17h: FLOW_BypassTrigger — error on multiple requests
	{
		Boolean exceptionThrown = false;
		try
		{
			kern.FLOW_BypassTrigger.DTO_Request req1 = new kern.FLOW_BypassTrigger.DTO_Request();
			req1.action = 'BYPASS';
			req1.bypassType = 'OBJECT_NAME';
			req1.name = 'Account';

			kern.FLOW_BypassTrigger.DTO_Request req2 = new kern.FLOW_BypassTrigger.DTO_Request();
			req2.action = 'BYPASS';
			req2.bypassType = 'OBJECT_NAME';
			req2.name = 'Contact';

			kern.FLOW_BypassTrigger.execute(new List<kern.FLOW_BypassTrigger.DTO_Request> {req1, req2});
		}
		catch(Exception error)
		{
			exceptionThrown = true;
			System.debug('17h Exception: ' + error.getMessage());
		}

		System.assert(exceptionThrown, '17h FAIL: Should throw exception for multiple requests');
		System.debug('17h PASS: FLOW_BypassTrigger correctly rejects multiple requests');

		kern.TRG_Base.clearAllBypasses();
	}

	System.debug('=== Section 17 COMPLETE: All Flow Invocable tests passed ===');
}
finally
{
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.UTIL_ValidationRule.clearAllBypasses();

	if(!cleanupIds.isEmpty())
	{
		List<Task> tasks =
		[
				SELECT Id
				FROM Task
				WHERE WhatId IN :cleanupIds
		];
		if(!tasks.isEmpty()) delete tasks;
		delete
		[
				SELECT Id
				FROM Account
				WHERE Id IN :cleanupIds
		];
		System.debug('Cleanup: Deleted ' + cleanupIds.size() + ' test Account(s)');
	}
}
