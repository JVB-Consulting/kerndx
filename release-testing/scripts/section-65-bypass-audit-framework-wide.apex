// =============================================================================
// Section 65: Framework-Wide Bypass Audit (subscriber-observable behaviour) — Launch
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
//
// Launch half of the section-65 launch + verify split. The audit trail persists
// asynchronously (LogEntryEvent__e delivery + TRG_PersistLogEntry), so emission
// and verification must run in separate transactions — same reason as the
// section-66/66b split. A single-transaction script only passed when platform-
// event delivery happened to outrun its own SOQL, which is why this section was
// historically flaky inside the Phase 2 suite.
//
// Exercises the four global bypass surfaces (trigger, query, DML, validation),
// asserts the `BypassAudit_Enabled` kill-switch ships default-on, and persists a
// `kern__Foobar__c` handoff row carrying the verification window start + the
// emitting user for `section-65b-bypass-audit-verify.apex`.
//
// SCOPE — subscriber-observable only. This script does NOT call
// `kern.UTIL_BypassAudit` directly; that helper is framework-internal (`public`,
// not `global`) and subscribers cannot reference it. The audit trail is the
// observable contract — the verify half checks the trail lands when subscribers
// use the documented global APIs (`TRG_Base`, `QRY_Builder`, `DML_Builder`,
// `UTIL_ValidationRule`).
//
// Run (two stages, ~30s apart for PE delivery):
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-65-bypass-audit-framework-wide.apex
//   (wait ~10-60s for LogEntryEvent__e delivery + TRG_PersistLogEntry persistence)
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-65b-bypass-audit-verify.apex
// =============================================================================

// Reset state on the global bypass surfaces — guarantees a clean audit trail
// for this section's assertions
kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

// Allow the framework's audit log entries to publish in the script context
kern.LOG_Builder.ignoreTestMode = true;

Datetime sectionStart = Datetime.now().addSeconds(-1);

// Test 65a (emit): Trigger-surface emission via TRG_Base.bypass / clearBypass
{
	kern.TRG_Base.bypass(Account.SObjectType);
	kern.TRG_Base.clearBypass(Account.SObjectType);
}

// Test 65b (emit): Query-surface emission via QRY_Builder.withSystemMode —
// the verify half expects the object-qualified target `system-mode:Account`
{
	kern.QRY_Builder.selectFrom(Account.SObjectType).withSystemMode().toList();
}

// Test 65c (emit): Query-surface emission via QRY_Builder.bypassSharing —
// the verify half expects the object-qualified target `sharing:Account`
{
	kern.QRY_Builder.selectFrom(Account.SObjectType).bypassSharing().toList();
}

// Test 65d (emit): DML-surface emission via DML_Builder.withSystemMode — the
// verify half expects `system-mode:Account` with operation=insert, rowCount=1
{
	Account record = new Account(Name = 'Test 65d', Phone = '555-0165', Industry = 'Technology');
	kern.DML_Builder.newTransaction().doInsert(record).withSystemMode().execute();
}

// Test 65e (emit): Validation-surface emission via UTIL_ValidationRule.bypassObject
{
	kern.UTIL_ValidationRule.bypassObject('Account');
	kern.UTIL_ValidationRule.clearBypass('Account');
}

// Persist the handoff row the verify half reads: the verification window start
// and the emitting user (persisted audit rows carry kern__UserId__c = emitting
// user; CreatedById is the Automated Process user — section-50b FINDING A37).
kern__Foobar__c handoff = new kern__Foobar__c(
		Name = 'Section65BypassAudit_' + String.valueOf(System.currentTimeMillis()),
		kern__TextAreaLong__c = JSON.serialize(new Map<String, Object>
		{
				'windowStartMs' => sectionStart.getTime(),
				'launchUserId' => UserInfo.getUserId()
		}));
insert handoff;
System.debug('PASS: 65-launch — bypass exercises emitted on trigger/query/DML/validation surfaces; handoff persisted');

// Test 65f: Kill-switch contract — `BypassAudit_Enabled` ships active so the
// audit trail flows without subscriber configuration; subscribers can disable
// in noisy environments via a `FeatureFlagStrategy__mdt` override on the
// `kern__BypassAudit_Enabled` `FeatureFlag__mdt` record. Synchronous check —
// stays in the launch half because it needs no persistence wait.
if(kern.UTIL_FeatureFlag.isEnabled('BypassAudit_Enabled'))
{
	System.debug('PASS: 65f — BypassAudit_Enabled flag defaults to true');
}
else
{
	System.debug('FAIL: 65f — BypassAudit_Enabled flag should default to true');
}

System.debug('Section 65 (launch): complete');
