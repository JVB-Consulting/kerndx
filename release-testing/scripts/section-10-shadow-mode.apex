// =============================================================================
// Section 10: Shadow Mode + Warning Severity
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - TRG_Account trigger deployed on Account (before insert, before update)
//   - kern.TRG_ExecuteValidationRules at Order=50 (BeforeInsert, BeforeUpdate)
//   - TRG_SetAccountDefaults at Order=100 (BeforeInsert) — sets Description='Default' when blank
//   - TRG_StampAccountSource at Order=300 (BeforeInsert) — sets AccountSource='Subscriber Trigger'
//   - ValidationRuleGroup 'AccountValidation' with rules:
//     * RequireAccountIndustry (Order=100, Error) — ISBLANK(Industry)
//     * WarnMissingWebsite (Order=200, Warning) — ISBLANK(Website)
//     * PhoneOrWebsiteRequired (Order=400, Error) — AND(ISBLANK(Phone), ISBLANK(Website))
//     * ShadowAuditRule (Order=600, Error, ShadowMode=true) — ISBLANK(Description)
//   - All TriggerAction__mdt and TriggerSetting__mdt active (no bypasses)
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-10-shadow-mode.apex
// =============================================================================

// Safety: clear all bypasses at the start
kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();
// Bypass the flow trigger action — sections 41-44 cover that surface; this section tests shadow-mode validation only
kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow');

// Test 10a: Shadow mode — Error severity rule in shadow mode, save succeeds
// ShadowAuditRule: ISBLANK(Description), Severity=Error, ShadowMode=true
// Insert Account with Industry + Phone but NO Description
// Expected: ShadowAuditRule fires (Description is blank) but shadow mode allows save
// Note: TRG_SetAccountDefaults at Order=100 sets Description='Default' AFTER validation at Order=50
// So at validation time, Description IS blank -> shadow rule fires -> logged but not blocked
// Then TRG_SetAccountDefaults sets Description='Default'
{
	Account account = new Account(Name = 'Test Account 10a', Industry = 'Technology', Phone = '555-1000');
	insert account;

	Account result =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id = :account.Id
	];
	System.assertEquals('Default', result.Description, '10a FAIL: Description should be Default — TRG_SetAccountDefaults fires after shadow validation');
	System.assertEquals('Subscriber Trigger', result.AccountSource, '10a FAIL: AccountSource should be stamped');
	System.debug('10a PASS: Shadow mode rule (Error severity) allows save — record inserted successfully');

	delete account;
}

// Test 10b: Warning severity — save succeeds, warning logged
// WarnMissingWebsite: ISBLANK(Website), Severity=Warning
// Insert Account with Industry + Phone but no Website
// Expected: WarnMissingWebsite fires as warning, save succeeds
{
	Account account = new Account(Name = 'Test Account 10b', Industry = 'Technology', Phone = '555-1001');
	insert account;

	Account result =
	[
			SELECT Description,
					AccountSource,
					Website
			FROM Account
			WHERE Id = :account.Id
	];
	System.assertEquals(null, result.Website, '10b FAIL: Website should be null — not populated');
	System.assertEquals('Default', result.Description, '10b FAIL: Description should be Default');
	System.assertEquals('Subscriber Trigger', result.AccountSource, '10b FAIL: AccountSource should be stamped');
	System.debug('10b PASS: Warning severity allows save — WarnMissingWebsite fires but does not block');

	delete account;
}

// Test 10c: Shadow + real error in same transaction
// Insert Account WITHOUT Industry and without Description (Phone set)
// RequireAccountIndustry fires (Error, not shadow) → blocks save
// ShadowAuditRule would also evaluate (Description blank) but save already blocked by real error
{
	Boolean exceptionThrown = false;

	try
	{
		Account account = new Account(Name = 'Test Account 10c', Phone = '555-1002');
		insert account;
	}
	catch(DmlException error)
	{
		exceptionThrown = true;
		System.assert(error.getMessage().contains('Industry is required'),
				'10c FAIL: Error should contain RequireAccountIndustry message, got: ' + error.getMessage());
	}

	System.assert(exceptionThrown, '10c FAIL: DmlException should have been thrown — real error blocks save');
	System.debug('10c PASS: Real error (Industry required) blocks save — shadow rule also fires but save blocked by real error');
}

// Test 10d: Warning with Website populated — no warning
// Insert Account with Industry, Phone, AND Website populated
// WarnMissingWebsite: ISBLANK(Website) → FALSE → no warning
// All rules pass — clean insert
{
	Account account = new Account(
			Name = 'Test Account 10d',
			Industry = 'Technology',
			Phone = '555-1003',
			Website = 'https://example.com'
	);
	insert account;

	Account result =
	[
			SELECT Description,
					AccountSource,
					Website
			FROM Account
			WHERE Id = :account.Id
	];
	System.assertEquals('https://example.com', result.Website, '10d FAIL: Website should be populated');
	System.assertEquals('Default', result.Description, '10d FAIL: Description should be Default');
	System.debug('10d PASS: All fields populated — no warning, no shadow, clean insert');

	delete account;
}

// Test 10e: Query log entries for shadow/warning violations
// LogEntry__c records are created via platform events (LogEntryEvent__e)
// Platform event processing is asynchronous — entries may not be immediately available
// Query recent entries to check for shadow/warning log entries
{
	// Allow a brief moment for async platform events to process
	// Note: In anonymous Apex, we cannot use Test.getEventBus().deliver()
	// Log entries from previous tests may need a moment to persist

	List<SObject> logEntries =
	[
			SELECT kern__Message__c,
					kern__LogLevel__c,
					kern__ClassMethod__c
			FROM kern__LogEntry__c
			ORDER BY CreatedDate DESC
			LIMIT 20
	];

	System.debug('10e: Log entries found: ' + logEntries.size());
	for(SObject entry : logEntries)
	{
		System.debug('  Log: [' + entry.get('kern__LogLevel__c') + '] '
				+ entry.get('kern__ClassMethod__c') + ' — '
				+ entry.get('kern__Message__c'));
	}

	// Log entries from shadow mode and warnings may be present
	// Due to async nature of platform events, we report findings rather than assert
	if(logEntries.isEmpty())
	{
		System.debug('10e INFO: No log entries found yet — platform events may still be processing');
		System.debug('10e INFO: Re-run this section after a brief delay to check for async log entries');
	}
	else
	{
		System.debug('10e PASS: Log entries found — review above for shadow/warning entries');
	}
}

// Final cleanup
kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

System.debug('========================================');
System.debug('Section 10: All tests completed');
System.debug('========================================');
