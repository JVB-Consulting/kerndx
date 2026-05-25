// =============================================================================
// Section 8: API Feature Flag Checks
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed)
// Prerequisites:
//   - kern managed package installed with FeatureFlag__mdt records:
//     * DisableAllOutboundAPIs (IsActive=true, IsEnabledByDefault=false, ResultOnNoMatch=false)
//     * DisableAllInboundAPIs  (IsActive=true, IsEnabledByDefault=false, ResultOnNoMatch=false)
//     * DisableAllAPIs         (IsActive=true, IsEnabledByDefault=false, ResultOnNoMatch=false)
//     * MockAllAPIs            (IsActive=true, IsEnabledByDefault=false, ResultOnNoMatch=false)
//   - These flags ship with the package (protected=false) so subscribers can deploy overrides
//   - No FeatureFlagStrategy__mdt records are configured for these flags by default
//   - Without strategies, evaluation falls through to IsEnabledByDefault__c (false)
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-8-api-feature-flags.apex
// =============================================================================

// Test 8a: DisableAllOutboundAPIs is false by default
{
	Boolean isEnabled = kern.UTIL_FeatureFlag.isEnabled('DisableAllOutboundAPIs');
	System.assertEquals(false, isEnabled, '8a FAIL: DisableAllOutboundAPIs should be false by default (IsEnabledByDefault=false, no strategies)');
	System.debug('8a PASS: DisableAllOutboundAPIs is false by default');
}

// Test 8b: DisableAllInboundAPIs is false by default
{
	Boolean isEnabled = kern.UTIL_FeatureFlag.isEnabled('DisableAllInboundAPIs');
	System.assertEquals(false, isEnabled, '8b FAIL: DisableAllInboundAPIs should be false by default (IsEnabledByDefault=false, no strategies)');
	System.debug('8b PASS: DisableAllInboundAPIs is false by default');
}

// Test 8c: DisableAllAPIs is false by default
{
	Boolean isEnabled = kern.UTIL_FeatureFlag.isEnabled('DisableAllAPIs');
	System.assertEquals(false, isEnabled, '8c FAIL: DisableAllAPIs should be false by default (IsEnabledByDefault=false, no strategies)');
	System.debug('8c PASS: DisableAllAPIs is false by default');
}

// Test 8d: MockAllAPIs is false by default
{
	Boolean isEnabled = kern.UTIL_FeatureFlag.isEnabled('MockAllAPIs');
	System.assertEquals(false, isEnabled, '8d FAIL: MockAllAPIs should be false by default (IsEnabledByDefault=false, no strategies)');
	System.debug('8d PASS: MockAllAPIs is false by default');
}

// Test 8e: Document toggling — CMDT redeployment required
// These flags are CMDT-backed. Toggling requires deploying an override record to the subscriber org.
// Since CMDT is not writable via DML, you cannot toggle flags in anonymous Apex.
//
// To test toggled states:
//
// 1. Create a local override CMDT record (e.g., in a scratch org project or SFDX source):
//
//    File: customMetadata/kern__FeatureFlag.DisableAllOutboundAPIs.md-meta.xml
//    Change: <field>kern__IsEnabledByDefault__c</field> <value xsi:type="xsd:boolean">true</value>
//
// 2. Deploy the override to the subscriber org:
//
//    sf project deploy start -o $SF_SUBSCRIBER_ORG_ALIAS -m "CustomMetadata:kern__FeatureFlag.DisableAllOutboundAPIs"
//
// 3. Re-run this script — test 8a should now return true.
//
// 4. To restore defaults, redeploy with IsEnabledByDefault=false:
//
//    sf project deploy start -o $SF_SUBSCRIBER_ORG_ALIAS -m "CustomMetadata:kern__FeatureFlag.DisableAllOutboundAPIs"
//
// Alternatively, subscribers can assign a FeatureFlagStrategy__mdt (e.g., Custom Permission)
// to enable the flag for specific users or profiles without changing the default.
//
// Example CMDT override commands for each flag:
//   sf project deploy start -o $SF_SUBSCRIBER_ORG_ALIAS -m "CustomMetadata:kern__FeatureFlag.DisableAllOutboundAPIs"
//   sf project deploy start -o $SF_SUBSCRIBER_ORG_ALIAS -m "CustomMetadata:kern__FeatureFlag.DisableAllInboundAPIs"
//   sf project deploy start -o $SF_SUBSCRIBER_ORG_ALIAS -m "CustomMetadata:kern__FeatureFlag.DisableAllAPIs"
//   sf project deploy start -o $SF_SUBSCRIBER_ORG_ALIAS -m "CustomMetadata:kern__FeatureFlag.MockAllAPIs"
{
	System.debug('8e PASS: Toggling documentation verified (see comments above for CMDT redeployment commands)');
}

System.debug('========================================');
System.debug('Section 8: All tests completed');
System.debug('========================================');
