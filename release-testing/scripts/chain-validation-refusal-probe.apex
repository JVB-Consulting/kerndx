// Chain save refused by a subscriber validation rule. See RUNBOOK.md, "Chain save refused by a subscriber validation rule".
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}, with the 1.4 artifacts and release-testing/fixtures/chain-validation-refusal/ deployed.
//
// Starts two two-step chains, both built from SubscriberChainSteps.WriteContextStep:
//   - SubscriberValidationRefusalProbe: the fixture's validation rule refuses the save that moves this run to Completed,
//     with a message that is not the chain engine's own refusal message.
//   - SubscriberValidationRefusalControl: the same chain under another name, which the rule does not match, so it
//     shows the steps themselves complete.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/chain-validation-refusal-probe.apex
//   (wait about 60 seconds for the chains)
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/chain-validation-refusal-probe-verify.apex > tmp/chain-validation-refusal-verify.log 2>&1

String probeRunId = kern.UTIL_AsyncChain.newChain('SubscriberValidationRefusalProbe')
		.then(new SubscriberChainSteps.WriteContextStep())
		.then(new SubscriberChainSteps.WriteContextStep())
		.execute();
String controlRunId = kern.UTIL_AsyncChain.newChain('SubscriberValidationRefusalControl')
		.then(new SubscriberChainSteps.WriteContextStep())
		.then(new SubscriberChainSteps.WriteContextStep())
		.execute();
System.debug('chain-validation-refusal launch: probe run ' + probeRunId + ', control run ' + controlRunId);
