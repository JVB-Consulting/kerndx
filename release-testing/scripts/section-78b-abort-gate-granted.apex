// =============================================================================
// Section 78b: Async Chain Abort — core.-prefixed custom-permission strategy gate, GRANTED leg
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Package: kern (managed — 1.6.0 or later, carrying the abort feature)
// Prerequisites:
//   - Run section-78-abort-gate.apex FIRST (it assigns the AsyncChainAbort permission set).
//   - Run this script in a SECOND, separate execution: the grant is not visible to permission
//     checks inside the granting transaction (permission-cache staleness), and this keeps the
//     non-setup AsyncChainExecution__c seed DML apart from section 78's setup-object DML.
//
// Run with:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-78b-abort-gate-granted.apex
//
// Section list (2 PASS expected — paired with section-78 for the STRATEGY-RESOLUTION leg):
//   78b — core.AbortAsyncChain resolves for the grantee (fresh transaction, caches rebuilt)
//   78c — a contradictory row reads terminal through the released isTerminal predicate
// =============================================================================

// Section 78b — abort gate, granted state (fresh transaction: permission caches rebuilt), plus the
// contradictory-row probe through the released API — the only abort-adjacent member a subscriber
// can reach.
Boolean granted = kern.UTIL_FeatureFlag.isEnabled('AsyncChainAbort_Enabled');
System.debug(granted
		? '78b PASS: core.AbortAsyncChain resolves for a grantee'
		: '78b FAIL: core.AbortAsyncChain did not resolve for a grantee');

try
{
	kern__AsyncChainExecution__c stalledSeed = new kern__AsyncChainExecution__c(
			kern__ChainName__c = 'Section78b', kern__Status__c = 'Stalled',
			kern__TotalSteps__c = 1, kern__CompletedSteps__c = 0, kern__CompletedAt__c = Datetime.now());
	insert stalledSeed;
	kern.UTIL_AsyncChain.ChainStatus terminalProbe = kern.UTIL_AsyncChain.getChainStatus(stalledSeed.Id);
	System.debug(terminalProbe != null && terminalProbe.isTerminal()
			? '78c PASS: contradictory row reads terminal through the released predicate'
			: '78c FAIL: contradictory row not terminal in subscriber context');
	delete stalledSeed;
}
catch(Exception seedError)
{
	System.debug('78c FAIL: contradictory-row probe errored: ' + seedError.getMessage());
}

System.debug('Section 78b (granted): leg completed (2/2)');
