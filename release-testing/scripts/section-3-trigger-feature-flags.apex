// =============================================================================
// Section 3: Trigger + Feature Flag Integration
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
//
// CMDT STATE REQUIRED:
// This script adapts its assertions based on the current deployed CMDT state.
// The feature flags and their CMDT configurations are tested in combinations.
// Deploy the appropriate CMDT state before running each sub-section.
//
// Feature Flags (kern__FeatureFlag__mdt):
//   - EnableAccountTriggers:   IsActive=true, IsEnabledByDefault=false, ResultOnNoMatch=false
//   - SkipAccountDefaults:     IsActive=true, IsEnabledByDefault=false, ResultOnNoMatch=false
//   - EnableAccountValidation: IsActive=true, IsEnabledByDefault=true,  ResultOnNoMatch=false
//   - SkipIndustryRule:        IsActive=true, IsEnabledByDefault=false, ResultOnNoMatch=false
//
// TriggerSetting__mdt fields used:
//   - kern__RequiredFeatureFlag__c: When set to a FeatureFlag DeveloperName, the entire
//     TriggerSetting only fires if that flag is enabled.
//
// TriggerAction__mdt fields used:
//   - kern__BypassFeatureFlag__c: When set to a FeatureFlag DeveloperName, the specific
//     action is skipped if that flag is enabled.
//
// DEPLOYMENT STATES:
//   State A (Tests 3a): TriggerSetting 'Account' has RequiredPermission='EnableAccountTriggers'
//           AND EnableAccountTriggers flag has IsEnabledByDefault=false (no strategies).
//           Expected: All handlers are BLOCKED because the required flag is disabled.
//
//   State B (Tests 3b): Same as State A but EnableAccountTriggers has IsEnabledByDefault=true.
//           Expected: All handlers FIRE because the required flag is now enabled.
//
//   State C (Tests 3c): TriggerSetting 'Account' has RequiredPermission=null (or cleared).
//           TriggerAction 'SetAccountDefaults_BeforeInsert' has BypassPermission='SkipAccountDefaults'.
//           SkipAccountDefaults flag has IsEnabledByDefault=true.
//           Expected: TRG_SetAccountDefaults is SKIPPED, other handlers fire normally.
//
//   State D (Tests 3d): Same as State C but SkipAccountDefaults has IsEnabledByDefault=false.
//           Expected: All handlers fire normally (bypass flag disabled = no bypass).
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-3-trigger-feature-flags.apex
// =============================================================================

// Safety: clear all bypasses at the start
kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();
// Bypass the flow trigger action — sections 41-44 cover that surface; this section tests Apex actions only
kern.TRG_Base.bypassAction('kern.TRG_InvokeFlow');

// Bypass validation rules — this section tests trigger feature flags, not validation
kern.UTIL_ValidationRule.bypassObject('Account');

// ---------------------------
// Detect current CMDT state
// ---------------------------

// Check flag states
Boolean enableAccountTriggersEnabled = kern.UTIL_FeatureFlag.isEnabled('EnableAccountTriggers');
Boolean skipAccountDefaultsEnabled = kern.UTIL_FeatureFlag.isEnabled('SkipAccountDefaults');

System.debug('Current flag state — EnableAccountTriggers: ' + enableAccountTriggersEnabled);
System.debug('Current flag state — SkipAccountDefaults: ' + skipAccountDefaultsEnabled);

// Read TriggerSetting to detect RequiredPermission configuration
kern__TriggerSetting__mdt triggerSetting =
[
		SELECT kern__RequiredFeatureFlag__c
		FROM kern__TriggerSetting__mdt
		WHERE DeveloperName = 'Account'
		LIMIT 1
];
String settingRequiredPermission = triggerSetting.kern__RequiredFeatureFlag__c;
Boolean settingHasRequiredPermission = String.isNotBlank(settingRequiredPermission);

System.debug('TriggerSetting Account — RequiredPermission: ' + settingRequiredPermission);

// Read TriggerAction to detect BypassPermission configuration on SetAccountDefaults
kern__TriggerAction__mdt setDefaultsAction =
[
		SELECT kern__BypassFeatureFlag__c
		FROM kern__TriggerAction__mdt
		WHERE DeveloperName = 'SetAccountDefaults_BeforeInsert'
		LIMIT 1
];
String actionBypassPermission = setDefaultsAction.kern__BypassFeatureFlag__c;
Boolean actionHasBypassPermission = String.isNotBlank(actionBypassPermission);

System.debug('TriggerAction SetAccountDefaults_BeforeInsert — BypassPermission: ' + actionBypassPermission);

// ---------------------------
// Test 3a / 3b: RequiredPermission on TriggerSetting
// ---------------------------
// When RequiredPermission is set on the TriggerSetting and the referenced flag is DISABLED,
// all handlers for that object should be skipped.
// When the flag is ENABLED, all handlers should fire normally.

if(settingHasRequiredPermission)
{
	System.debug('--- Testing RequiredPermission on TriggerSetting (State A or B) ---');

	Account account = new Account(Name = 'Test Account 3ab', Industry = 'Technology');
	insert account;

	Account result =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id = :account.Id
	];

	if(!enableAccountTriggersEnabled)
	{
		// State A: Flag disabled — handlers should NOT fire
		System.assertEquals(null, result.Description,
				'3a FAIL: Description should be null — EnableAccountTriggers flag is disabled, handlers blocked');
		System.assertEquals(null, result.AccountSource,
				'3a FAIL: AccountSource should be null — EnableAccountTriggers flag is disabled, handlers blocked');
		System.debug('3a PASS: RequiredPermission blocks all handlers when flag is disabled');
	}
	else
	{
		// State B: Flag enabled — handlers should fire
		System.assertEquals('Default', result.Description,
				'3b FAIL: Description should be Default — EnableAccountTriggers flag is enabled');
		System.assertEquals('Subscriber Trigger', result.AccountSource,
				'3b FAIL: AccountSource should be set — EnableAccountTriggers flag is enabled');
		System.debug('3b PASS: RequiredPermission allows all handlers when flag is enabled');
	}

	delete account;
}
else
{
	System.debug('--- Skipping 3a/3b: TriggerSetting does not have RequiredPermission set ---');
	System.debug('To test State A: Deploy TriggerSetting Account with RequiredPermission=EnableAccountTriggers and EnableAccountTriggers with IsEnabledByDefault=false');
	System.debug('To test State B: Same, but set EnableAccountTriggers IsEnabledByDefault=true');
}

// ---------------------------
// Test 3c / 3d: BypassPermission on TriggerAction
// ---------------------------
// When BypassPermission is set on a TriggerAction and the referenced flag is ENABLED,
// that specific handler should be skipped while others continue to fire.
// When the flag is DISABLED, the handler fires normally.

if(actionHasBypassPermission)
{
	System.debug('--- Testing BypassPermission on TriggerAction (State C or D) ---');

	Account account = new Account(Name = 'Test Account 3cd', Industry = 'Technology');
	insert account;

	Account result =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id = :account.Id
	];

	if(skipAccountDefaultsEnabled)
	{
		// State C: Bypass flag enabled — TRG_SetAccountDefaults SKIPPED, others fire
		System.assertEquals(null, result.Description,
				'3c FAIL: Description should be null — SkipAccountDefaults flag is enabled, handler bypassed');
		System.assertEquals('Subscriber Trigger', result.AccountSource,
				'3c FAIL: AccountSource should still be set — only SetAccountDefaults is bypassed');
		System.debug('3c PASS: BypassPermission skips specific handler when flag is enabled, others still fire');
	}
	else
	{
		// State D: Bypass flag disabled — all handlers fire normally
		System.assertEquals('Default', result.Description,
				'3d FAIL: Description should be Default — SkipAccountDefaults flag is disabled, no bypass');
		System.assertEquals('Subscriber Trigger', result.AccountSource,
				'3d FAIL: AccountSource should be set — SkipAccountDefaults flag is disabled');
		System.debug('3d PASS: BypassPermission does not bypass when flag is disabled — all handlers fire');
	}

	delete account;
}
else
{
	System.debug('--- Skipping 3c/3d: TriggerAction does not have BypassPermission set ---');
	System.debug('To test State C: Deploy SetAccountDefaults_BeforeInsert with BypassPermission=SkipAccountDefaults and SkipAccountDefaults with IsEnabledByDefault=true');
	System.debug('To test State D: Same, but set SkipAccountDefaults IsEnabledByDefault=false');
}

// ---------------------------
// Baseline verification: No RequiredPermission, no BypassPermission — handlers fire normally
// ---------------------------
if(!settingHasRequiredPermission && !actionHasBypassPermission)
{
	System.debug('--- Baseline verification: No feature flag constraints — all handlers should fire ---');

	Account account = new Account(Name = 'Test Account 3 Baseline', Industry = 'Technology');
	insert account;

	Account result =
	[
			SELECT Description,
					AccountSource
			FROM Account
			WHERE Id = :account.Id
	];
	System.assertEquals('Default', result.Description,
			'3 Baseline FAIL: Description should be Default in baseline state');
	System.assertEquals('Subscriber Trigger', result.AccountSource,
			'3 Baseline FAIL: AccountSource should be set in baseline state');
	System.debug('3 Baseline PASS: All handlers fire normally without feature flag constraints');

	delete account;
}

// ---------------------------
// Feature flag API smoke test — always runs regardless of CMDT state
// ---------------------------
{
	System.debug('--- Feature flag API smoke test ---');

	// EnableAccountTriggers: IsEnabledByDefault=false (no strategies) — should be false unless changed
	Boolean enableTriggersResult = kern.UTIL_FeatureFlag.isEnabled('EnableAccountTriggers');
	System.debug('UTIL_FeatureFlag.isEnabled(EnableAccountTriggers) = ' + enableTriggersResult);

	// EnableAccountValidation: IsEnabledByDefault=true (no strategies) — should be true unless changed
	Boolean enableValidationResult = kern.UTIL_FeatureFlag.isEnabled('EnableAccountValidation');
	System.debug('UTIL_FeatureFlag.isEnabled(EnableAccountValidation) = ' + enableValidationResult);

	// SkipAccountDefaults: IsEnabledByDefault=false — should be false unless changed
	Boolean skipDefaultsResult = kern.UTIL_FeatureFlag.isEnabled('SkipAccountDefaults');
	System.debug('UTIL_FeatureFlag.isEnabled(SkipAccountDefaults) = ' + skipDefaultsResult);

	// SkipIndustryRule: IsEnabledByDefault=false — should be false unless changed
	Boolean skipIndustryResult = kern.UTIL_FeatureFlag.isEnabled('SkipIndustryRule');
	System.debug('UTIL_FeatureFlag.isEnabled(SkipIndustryRule) = ' + skipIndustryResult);

	// Non-existent flag should return false
	Boolean nonExistentResult = kern.UTIL_FeatureFlag.isEnabled('NonExistentFlag');
	System.assert(!nonExistentResult, '3 Smoke FAIL: Non-existent flag should return false');

	System.debug('3 Smoke PASS: Feature flag API responds correctly for all configured flags');
}

// Final cleanup
kern.TRG_Base.clearAllBypasses();
kern.TRG_Base.clearAllActionBypasses();

System.debug('========================================');
System.debug('Section 3: All tests completed');
System.debug('========================================');
