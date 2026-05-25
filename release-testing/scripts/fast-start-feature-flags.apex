// Fast Start - Feature Flags: Tier 1 verification script
// Run from: Developer Console > Debug > Open Execute Anonymous Window
// Expected: prints false (flag inactive by default), then true after CMDT IsActive flip

Boolean enabled = kern.UTIL_FeatureFlag.isEnabled('FastStart_NewPricing');
System.debug('FastStart_NewPricing enabled: ' + enabled);
