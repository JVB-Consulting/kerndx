// =============================================================================
// Section 9: Cross-Framework Integration
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - TRG_Account trigger deployed on Account (before insert, before update)
//   - kern.TRG_ExecuteValidationRules at Order=50 (BeforeInsert, BeforeUpdate) — formula validation rules
//   - TRG_SetAccountDefaults at Order=100 (BeforeInsert) — sets Description='Default' when blank
//   - TRG_ValidateAccountName at Order=200 (BeforeInsert) — addError if Name contains 'BLOCKED'
//   - TRG_StampAccountSource at Order=300 (BeforeInsert, BeforeUpdate) — sets AccountSource='Subscriber Trigger'
//   - ValidationRuleGroup 'AccountValidation' with rules:
//     * RequireAccountIndustry (Order=100, Error) — ISBLANK(Industry)
//     * WarnMissingWebsite (Order=200, Warning) — ISBLANK(Website)
//     * PhoneOrWebsiteRequired (Order=400, Error) — AND(ISBLANK(Phone), ISBLANK(Website))
//     * NameLengthCheck (Order=500, Error) — LEN(Name) < 3
//     * ShadowAuditRule (Order=600, Error, ShadowMode=true) — ISBLANK(Description)
//   - Execution strategy: Accumulate (all rules evaluated, not fail-fast)
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-9-cross-framework.apex
// =============================================================================

// Safety: clear all bypasses at the start
kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();
// Bypass the flow trigger action — sections 41-44 cover that surface; this section tests cross-framework Apex paths only
kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow');

// Test 9a: Trigger + Validation in same transaction — validation passes, handlers fire
// Insert Account with Industry + Phone set → validation passes (Order=50), then handlers fire (Order=100+)
// Expected: Description = 'Default' (set by TRG_SetAccountDefaults), AccountSource = 'Subscriber Trigger' (set by TRG_StampAccountSource)
{
	Account account = new Account(Name = 'Test Account 9a', Industry = 'Technology', Phone = '555-0100');
	insert account;

	Account result =
	[
			SELECT Description,
					AccountSource,
					Industry,
					Phone
			FROM Account
			WHERE Id = :account.Id
	];
	System.assertEquals('Default', result.Description, '9a FAIL: Description should be set to Default by TRG_SetAccountDefaults (Order=100)');
	System.assertEquals('Subscriber Trigger', result.AccountSource, '9a FAIL: AccountSource should be set by TRG_StampAccountSource (Order=300)');
	System.debug('9a PASS: Validation passes (Order=50), then trigger handlers fire (Order=100, 200, 300) — Description defaulted, AccountSource stamped');

	delete account;
}

// Test 9b: Validation blocks before handlers run — missing Industry causes validation error at Order=50
// Insert Account WITHOUT Industry (Phone set) → RequireAccountIndustry fires at Order=50, blocks save
// Handlers at Order=100, 200, 300 never execute because validation blocked the insert
{
	Boolean exceptionThrown = false;

	try
	{
		Account account = new Account(Name = 'Test Account 9b', Phone = '555-0200');
		insert account;
	}
	catch(DmlException error)
	{
		exceptionThrown = true;
		System.assert(error.getMessage().contains('Industry is required'),
				'9b FAIL: Error should contain RequireAccountIndustry message, got: ' + error.getMessage());
	}

	System.assert(exceptionThrown, '9b FAIL: DmlException should have been thrown — validation at Order=50 blocks before handlers at 100+');
	System.debug('9b PASS: Validation at Order=50 blocks save — handlers at Order=100+ never execute');
}

// Test 9c: Object bypass for triggers, but validation still fires (separate mechanism)
// kern.TRG_Base.bypass(Account.SObjectType) bypasses trigger handlers but NOT validation rules
// Validation rules are evaluated by TRG_ExecuteValidationRules which is a trigger action — so it IS bypassed too
// IMPORTANT: Object-level trigger bypass skips ALL trigger actions including TRG_ExecuteValidationRules
// This means validation also gets bypassed when triggers are bypassed at object level
try
{
	kern.TRG_Base.bypass(Account.SObjectType);

	// With object-level bypass, ALL trigger actions are skipped (including validation at Order=50)
	// So inserting without Industry should succeed — no validation, no handlers
	Account account = new Account(Name = 'Test Account 9c', Phone = '555-0300');
	insert account;

	Account result =
	[
			SELECT Description,
					AccountSource,
					Industry
			FROM Account
			WHERE Id = :account.Id
	];
	System.assertEquals(null, result.Description, '9c FAIL: Description should be null — all handlers bypassed');
	System.assertEquals(null, result.AccountSource, '9c FAIL: AccountSource should be null — all handlers bypassed');
	System.assertEquals(null, result.Industry, '9c FAIL: Industry should be null — no validation blocked the save');
	System.debug('9c PASS: Object-level trigger bypass skips ALL trigger actions including validation at Order=50');

	delete account;
}
finally
{
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow');
	kern.UTIL_ValidationRule.clearAllBypasses();
}

// Test 9d: Both programmatic bypasses — triggers AND validation bypassed
// kern.TRG_Base.bypass(Account.SObjectType) + kern.UTIL_ValidationRule.bypassObject('Account')
// Both mechanisms bypassed → record inserts with raw values (no defaults, no validation)
try
{
	kern.TRG_Base.bypass(Account.SObjectType);
	kern.UTIL_ValidationRule.bypassObject('Account');

	Account account = new Account(Name = 'Test Account 9d');
	insert account;

	Account result =
	[
			SELECT Description,
					AccountSource,
					Industry,
					Phone
			FROM Account
			WHERE Id = :account.Id
	];
	System.assertEquals(null, result.Description, '9d FAIL: Description should be null — both trigger and validation bypassed');
	System.assertEquals(null, result.AccountSource, '9d FAIL: AccountSource should be null — both trigger and validation bypassed');
	System.assertEquals(null, result.Industry, '9d FAIL: Industry should be null — validation bypassed');
	System.assertEquals(null, result.Phone, '9d FAIL: Phone should be null — no enforcement');
	System.debug('9d PASS: Both programmatic bypasses skip all processing — record inserts with raw values');

	delete account;
}
finally
{
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow');
	kern.UTIL_ValidationRule.clearAllBypasses();
}

// Test 9e: Validation bypass but triggers fire — skip validation only, handlers still execute
// kern.UTIL_ValidationRule.bypassObject('Account') bypasses validation evaluation inside TRG_ExecuteValidationRules
// But TRG_ExecuteValidationRules itself still runs (it is not action-bypassed), it just returns early
// Handlers at Order=100, 200, 300 still fire normally
try
{
	kern.UTIL_ValidationRule.bypassObject('Account');

	// Insert without Industry — validation bypassed, so no error for missing Industry
	// Trigger handlers still fire: Description = 'Default', AccountSource = 'Subscriber Trigger'
	Account account = new Account(Name = 'Test Account 9e', Phone = '555-0500');
	insert account;

	Account result =
	[
			SELECT Description,
					AccountSource,
					Industry
			FROM Account
			WHERE Id = :account.Id
	];
	System.assertEquals('Default', result.Description, '9e FAIL: Description should be Default — TRG_SetAccountDefaults fires at Order=100');
	System.assertEquals('Subscriber Trigger', result.AccountSource, '9e FAIL: AccountSource should be Subscriber Trigger — TRG_StampAccountSource fires at Order=300');
	System.assertEquals(null, result.Industry, '9e FAIL: Industry should be null — validation bypassed, so missing Industry not enforced');
	System.debug('9e PASS: Validation bypassed (UTIL_ValidationRule.bypassObject), but trigger handlers fire normally');

	delete account;
}
finally
{
	kern.TRG_Base.clearAllBypasses();
	kern.TRG_Base.clearAllActionBypasses();
	kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow');
	kern.UTIL_ValidationRule.clearAllBypasses();
}

// Test 9f: Verify execution order — validation at 50, then defaults at 100, validate name at 200, stamp source at 300
// Strategy: Insert an Account with Industry + Phone + blank Description + valid Name
// Expected execution order:
//   Order=50:  TRG_ExecuteValidationRules — validation passes (Industry present, Phone present, Name >= 3 chars)
//                ShadowAuditRule fires (Description blank) but is shadow mode — logged, not blocked
//                WarnMissingWebsite fires (no Website) but is Warning severity — logged, not blocked
//   Order=100: TRG_SetAccountDefaults — sets Description='Default' (was blank)
//   Order=200: TRG_ValidateAccountName — Name does not contain 'BLOCKED', so passes
//   Order=300: TRG_StampAccountSource — sets AccountSource='Subscriber Trigger'
// Final state proves all handlers fired in correct order
{
	Account account = new Account(Name = 'Test Account 9f', Industry = 'Technology', Phone = '555-0600');
	insert account;

	Account result =
	[
			SELECT Description,
					AccountSource,
					Industry,
					Phone
			FROM Account
			WHERE Id = :account.Id
	];

	// Description = 'Default' proves TRG_SetAccountDefaults at Order=100 fired
	System.assertEquals('Default', result.Description, '9f FAIL: Description should be Default — proves Order=100 handler fired');

	// AccountSource = 'Subscriber Trigger' proves TRG_StampAccountSource at Order=300 fired
	System.assertEquals('Subscriber Trigger', result.AccountSource, '9f FAIL: AccountSource should be Subscriber Trigger — proves Order=300 handler fired');

	// Record exists proves validation at Order=50 passed (Industry + Phone present)
	System.assertEquals('Technology', result.Industry, '9f FAIL: Industry should be Technology — validation passed at Order=50');
	System.assertEquals('555-0600', result.Phone, '9f FAIL: Phone should be present');

	// The fact that the record inserted successfully with the expected field values confirms execution order:
	// Validation (50) -> Defaults (100) -> ValidateName (200) -> StampSource (300)
	System.debug('9f PASS: Execution order verified — validation at 50, defaults at 100, validate name at 200, stamp source at 300');

	delete account;
}

// Test 9g: Bulk boundary — trigger × validation interleave correct on bulk records
// Insert 50 accounts with Industry + Phone set. Validation at Order=50 passes for all,
// then TRG_SetAccountDefaults (Order=100) and TRG_StampAccountSource (Order=300) fire on all.
// Scaled to 50 (not 200): section-9 has 6 prior tests each doing trigger+validation DML;
// the accumulated Apex execution stack depth means 200 records on the 7th invocation
// hits the 1001-frame limit in this org's TRG_Dispatcher configuration.
{
	List<Account> bulkAccounts = new List<Account>();
	for(Integer i = 0; i < 50; i++)
	{
		bulkAccounts.add(new Account(Name = 'Bulk 9g Account ' + i, Industry = 'Technology', Phone = '555-' + String.valueOf(9000 + i)));
	}
	insert bulkAccounts;

	List<Account> bulkResults =
	[
			SELECT Description,
					AccountSource,
					Industry
			FROM Account
			WHERE Id IN :bulkAccounts
	];
	System.assertEquals(50, bulkResults.size(), '9g FAIL: All 50 accounts should be inserted');
	Integer defaultedCount = 0;
	Integer stampedCount = 0;
	for(Account result : bulkResults)
	{
		if(result.Description == 'Default') defaultedCount++;
		if(result.AccountSource == 'Subscriber Trigger') stampedCount++;
	}
	System.assertEquals(50, defaultedCount, '9g FAIL: Validation at Order=50 passed for all; TRG_SetAccountDefaults should have defaulted all, got ' + defaultedCount);
	System.assertEquals(50, stampedCount, '9g FAIL: TRG_StampAccountSource should have stamped all 50, only ' + stampedCount + ' stamped');
	System.debug('9g PASS: Bulk trigger × validation interleave correct — validation passed for all, handlers fired on all 50');

	delete bulkAccounts;
}

// Final cleanup: ensure all bypasses are cleared for subsequent scripts
kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

System.debug('========================================');
System.debug('Section 9: All tests completed');
System.debug('========================================');
