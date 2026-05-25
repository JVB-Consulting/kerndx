// =============================================================================
// Section 65: Framework-Wide Bypass Audit (subscriber-observable behaviour)
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
//
// Verifies that when subscribers call the global bypass APIs, the framework
// produces structured `kern__LogEntry__c` rows with `category=BypassEvent` for
// every surface (trigger, query, DML, validation), and that the
// `BypassAudit_Enabled` `FeatureFlag__mdt` record is shipped active by default
// so the audit trail flows without subscriber configuration.
//
// SCOPE — subscriber-observable only. This script does NOT call
// `kern.UTIL_BypassAudit` directly; that helper is framework-internal (`public`,
// not `global`) and subscribers cannot reference it. The audit trail is the
// observable contract — this script verifies the trail lands when subscribers
// use the documented global APIs (`TRG_Base`, `QRY_Builder`, `DML_Builder`,
// `UTIL_ValidationRule`).
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-65-bypass-audit-framework-wide.apex
// =============================================================================

// Reset state on the global bypass surfaces — guarantees a clean audit trail
// for this section's assertions
kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

// Allow the framework's audit log entries to publish in the script context
kern.LOG_Builder.ignoreTestMode = true;

DateTime sectionStart = DateTime.now().addSeconds(-1);

// Test 65a: Trigger-surface emission via TRG_Base.bypass / clearBypass
{
	kern.TRG_Base.bypass(Account.SObjectType);
	kern.TRG_Base.clearBypass(Account.SObjectType);
}

// Test 65b: Query-surface emission via QRY_Builder.withSystemMode
{
	kern.QRY_Builder.selectFrom(Account.SObjectType).withSystemMode().toList();
}

// Test 65c: Query-surface emission via QRY_Builder.bypassSharing
{
	kern.QRY_Builder.selectFrom(Account.SObjectType).bypassSharing().toList();
}

// Test 65d: DML-surface emission via DML_Builder.withSystemMode
{
	Account record = new Account(Name = 'Test 65d', Phone = '555-0165', Industry = 'Technology');
	kern.DML_Builder.newTransaction().doInsert(record).withSystemMode().execute();
}

// Test 65e: Validation-surface emission via UTIL_ValidationRule.bypassObject
{
	kern.UTIL_ValidationRule.bypassObject('Account');
	kern.UTIL_ValidationRule.clearBypass('Account');
}

// Pull recent log entries written via UTIL_BypassAudit.emit and filter to
// `category=BypassEvent` in Apex (Long-Text fields like ContextData__c cannot
// be filtered with SOQL LIKE). Subscribers' real forensic queries either
// parse ContextData__c JSON in Apex / Flow / report formula, or join via
// SEL_LogEntry helpers — neither path requires SOQL LIKE on the long-text body.
List<kern__LogEntry__c> recentEntries =
[
		SELECT kern__ContextData__c, kern__Message__c, kern__ClassMethod__c
		FROM kern__LogEntry__c
		WHERE CreatedDate >= :sectionStart
				AND kern__ClassMethod__c = 'kern.UTIL_BypassAudit.emit'
		ORDER BY CreatedDate DESC
];

List<kern__LogEntry__c> auditEntries = new List<kern__LogEntry__c>();
Set<String> observedSurfaces = new Set<String>();
for(kern__LogEntry__c entry : recentEntries)
{
	Map<String, Object> envelope = (Map<String, Object>)JSON.deserializeUntyped(entry.kern__ContextData__c);
	Map<String, Object> context = (Map<String, Object>)envelope.get('contextData');
	if(context == null || !'BypassEvent'.equals(context.get('category')))
	{
		continue;
	}
	auditEntries.add(entry);
	String surface = (String)context.get('surface');
	if(String.isNotBlank(surface))
	{
		observedSurfaces.add(surface);
	}
}

System.debug('Section 65: ' + auditEntries.size() + ' bypass audit entries found');

if(observedSurfaces.contains('trigger-object'))
{
	System.debug('PASS: 65a — trigger-object surface emission landed');
}
else
{
	System.debug('FAIL: 65a — missing trigger-object surface emission');
}

if(observedSurfaces.contains('query'))
{
	System.debug('PASS: 65b/65c — query surface emission landed');
}
else
{
	System.debug('FAIL: 65b/65c — missing query surface emission');
}

if(observedSurfaces.contains('dml'))
{
	System.debug('PASS: 65d — dml surface emission landed');
}
else
{
	System.debug('FAIL: 65d — missing dml surface emission');
}

if(observedSurfaces.contains('validation'))
{
	System.debug('PASS: 65e — validation surface emission landed');
}
else
{
	System.debug('FAIL: 65e — missing validation surface emission');
}

// Test 65f: Kill-switch contract — `BypassAudit_Enabled` ships active so the
// audit trail flows without subscriber configuration; subscribers can disable
// in noisy environments via a `FeatureFlagStrategy__mdt` override on the
// `kern__BypassAudit_Enabled` `FeatureFlag__mdt` record.
if(kern.UTIL_FeatureFlag.isEnabled('BypassAudit_Enabled'))
{
	System.debug('PASS: 65f — BypassAudit_Enabled flag defaults to true');
}
else
{
	System.debug('FAIL: 65f — BypassAudit_Enabled flag should default to true');
}

System.debug('Section 65: complete');
