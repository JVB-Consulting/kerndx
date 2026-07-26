// =============================================================================
// Section 78: Async Chain Abort — core.-prefixed custom-permission strategy gate, STRATEGY-RESOLUTION leg
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed — 1.6.0 or later, carrying the abort feature)
// Prerequisites:
//   - The managed package installed with the AsyncChainAbort permission set and the
//     AsyncChainAbort_Enabled feature-flag records (the abort capability ships in 1.6.0).
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-78-abort-gate.apex
//
// Section list (1 PASS expected — paired with section-78b for the GRANTED leg):
//   78a — the flag verdict equals the runner's real custom-permission state; this leg then grants
//         the set for 78b
//
// The grant lands in THIS (setup-object) transaction but is NOT visible to permission checks
// until a fresh transaction — run section-78b-abort-gate-granted.apex as a SECOND execution.
// =============================================================================

// Section 78a — abort gate, strategy-resolution leg. The strategy target core.AbortAsyncChain must
// resolve the PACKAGE permission: a bare target would resolve subscriber-local and pass nowhere; the
// kern__-qualified form would fail the no-namespace development org. A fixed "ungranted user is
// refused" assert is unsatisfiable here — a scratch-org System Administrator profile holds the
// kern__AbortAsyncChain custom permission out of the box, and any re-run after this leg's own grant
// would refail it forever. So the leg asserts the flag verdict EQUALS the runner's real
// custom-permission state (true for an admin, false for a restricted runner): a mismatch in either
// direction means the shipped core.-prefixed record no longer resolves the installed package's
// permission, or the flag record went inactive or missing.
Boolean holdsAbortPermission = FeatureManagement.checkPermission('kern__AbortAsyncChain');
Boolean flagEnabled = kern.UTIL_FeatureFlag.isEnabled('AsyncChainAbort_Enabled');
System.debug(flagEnabled == holdsAbortPermission
		? '78a PASS: flag verdict matches the runner\'s custom-permission state (holds=' + holdsAbortPermission + ')'
		: '78a FAIL: flag verdict ' + flagEnabled + ' contradicts the runner\'s custom-permission state ' + holdsAbortPermission);

Id abortPermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'AsyncChainAbort' AND NamespacePrefix = 'kern'].Id;
if([SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetId = :abortPermissionSetId] == 0)
{
	insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = abortPermissionSetId);
}

System.debug('Section 78 (strategy resolution): leg completed (1/1)');
