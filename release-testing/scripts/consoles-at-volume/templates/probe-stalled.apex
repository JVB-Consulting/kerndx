// Consoles at volume, the probe: a step that spends the transaction's single enqueue, then a step that needs one.
// Tokens: __APEX_NAMESPACE__ (filled by the runner).
String executionId = __APEX_NAMESPACE__UTIL_AsyncChain.newChain('Volume_StallProbe')
		.then(new SubscriberChainSteps.EnqueueSpendingStep())
		.then(new SubscriberChainSteps.NarratingStep())
		.execute();
System.debug('VOLUME_PROBE stall=' + executionId);
