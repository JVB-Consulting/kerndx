// Consoles at volume: one batch of roots of the reconciliation action, five fanning steps each, every root keyed by
// the run token, all under the action's token-keyed id, which this transaction adopts before launching.
// Tokens: __APEX_NAMESPACE__ __ACTION_ID__ __RUN_TOKEN__ __ROOT_START__ __ROOT_COUNT__ __TARGET_DEPTH__
// __BUSY_MILLISECONDS__ __STAGGER__ (true or false: a minute's delay per root so a batch's roots start apart).
__APEX_NAMESPACE__LOG_Builder.setCorrelationId('__ACTION_ID__');
String actionId = '__ACTION_ID__';
String runToken = '__RUN_TOKEN__';
Boolean stagger = __STAGGER__;
List<String> executionIds = new List<String>();
for(Integer root = __ROOT_START__; root < __ROOT_START__ + __ROOT_COUNT__; root++)
{
	__APEX_NAMESPACE__UTIL_AsyncChain.ChainBuilder chain = __APEX_NAMESPACE__UTIL_AsyncChain.newChain(SubscriberChainSteps.VOLUME_CHAIN_NAMES[0])
			.withInitialContext(SubscriberChainSteps.KEY_VOLUME_DEPTH, 0)
			.withInitialContext(SubscriberChainSteps.KEY_VOLUME_TARGET_DEPTH, __TARGET_DEPTH__)
			.withInitialContext(SubscriberChainSteps.KEY_VOLUME_ORDINAL, 0)
			.withInitialContext(SubscriberChainSteps.KEY_VOLUME_ROOT_ORDINAL, root)
			.withInitialContext(SubscriberChainSteps.KEY_VOLUME_RUN_IDENTIFIER, runToken)
			.withInitialContext(SubscriberChainSteps.KEY_BUSY_MILLISECONDS, __BUSY_MILLISECONDS__);
	for(Integer step = 0; step < SubscriberChainSteps.VOLUME_FAN_OUT; step++)
	{
		chain.then(new SubscriberChainSteps.FanOutStep());
	}
	if(stagger)
	{
		chain.withDelayMinutes(Math.min(root - __ROOT_START__, 10));
	}
	executionIds.add(chain.execute(SubscriberChainSteps.volumeRunId(runToken, SubscriberChainSteps.KIND_RECONCILIATION_RUN, root, 0, 0)));
}
System.debug('VOLUME_LAUNCH stage=reconciliation action=' + actionId + ' ordinal=__ROOT_START__ ids=' + String.join(executionIds, ',')
		+ ' launched=' + executionIds.size() + ' dml=' + Limits.getDmlStatements() + '/' + Limits.getLimitDmlStatements()
		+ ' enqueued=' + Limits.getQueueableJobs() + '/' + Limits.getLimitQueueableJobs());
