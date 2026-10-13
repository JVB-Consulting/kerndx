// Consoles at volume, the probe: one root fanned out to the target depth under one token-keyed action.
// Tokens: __APEX_NAMESPACE__ __RUN_TOKEN__ __TARGET_DEPTH__ __BUSY_MILLISECONDS__ (filled by the runner).
String actionId = SubscriberChainSteps.volumeRunId('__RUN_TOKEN__', SubscriberChainSteps.KIND_ACTION, 0, 0, 0);
__APEX_NAMESPACE__LOG_Builder.setCorrelationId(actionId);
__APEX_NAMESPACE__UTIL_AsyncChain.ChainBuilder root = __APEX_NAMESPACE__UTIL_AsyncChain.newChain(SubscriberChainSteps.VOLUME_CHAIN_NAMES[0])
		.withInitialContext(SubscriberChainSteps.KEY_VOLUME_DEPTH, 0)
		.withInitialContext(SubscriberChainSteps.KEY_VOLUME_TARGET_DEPTH, __TARGET_DEPTH__)
		.withInitialContext(SubscriberChainSteps.KEY_VOLUME_ORDINAL, 0)
		.withInitialContext(SubscriberChainSteps.KEY_VOLUME_ROOT_ORDINAL, 0)
		.withInitialContext(SubscriberChainSteps.KEY_VOLUME_RUN_IDENTIFIER, '__RUN_TOKEN__')
		.withInitialContext(SubscriberChainSteps.KEY_BUSY_MILLISECONDS, __BUSY_MILLISECONDS__);
for(Integer step = 0; step < SubscriberChainSteps.VOLUME_FAN_OUT; step++)
{
	root.then(new SubscriberChainSteps.FanOutStep());
}
String executionId = root.execute(SubscriberChainSteps.volumeRunId('__RUN_TOKEN__', SubscriberChainSteps.KIND_RECONCILIATION_RUN, 0, 0, 0));
System.debug('VOLUME_PROBE action=' + actionId + ' root=' + executionId + ' enqueued=' + Limits.getQueueableJobs() + '/' + Limits.getLimitQueueableJobs()
		+ ' dml=' + Limits.getDmlStatements());
