// Consoles at volume: a batch of one wave chain kind under its own token-keyed action, so its rows form one small
// action. Kinds: slowExport (busy steps for the operator aborts: three a launched run and never fewer than five, so
// every abort is pressed through the screen while its chain still runs, at five seconds of CPU a step and about ten
// seconds a press, capped at the engine's fifty; the count is the launching transaction's, so keep a shape's aborts
// within one launch chunk of twenty-five or a later chunk's chains end before their presses), switchedOff (one step,
// launched while chains are suspended), deferredDispatch (a ten-minute delay, whose first hop the driver aborts for
// the dead-job stalls; its first step is not safe to repeat, so the watchdog ends the run Failed),
// idempotentDeferredDispatch (the same, but its first step declares itself safe to repeat and carries on past its own
// failure, so the watchdog re-drives the run and it ends Completed), stallProbe (a step that spends the transaction's
// enqueue), orderSync (the exploration's live-stream batch).
// Tokens: __APEX_NAMESPACE__ __ACTION_ID__ __RUN_TOKEN__ __KIND__ __KIND_INDEX__ __COUNT__ __BUSY_MILLISECONDS__
__APEX_NAMESPACE__LOG_Builder.setCorrelationId('__ACTION_ID__');
String actionId = '__ACTION_ID__';
String runToken = '__RUN_TOKEN__';
String kind = '__KIND__';
List<String> executionIds = new List<String>();
for(Integer launch = 0; launch < __COUNT__; launch++)
{
	String runId = SubscriberChainSteps.volumeRunId(runToken, SubscriberChainSteps.KIND_WAVE_RUN, __KIND_INDEX__, 0, launch);
	if(kind == 'slowExport')
	{
		__APEX_NAMESPACE__UTIL_AsyncChain.ChainBuilder slowExport = __APEX_NAMESPACE__UTIL_AsyncChain.newChain('Volume_SlowExport')
				.withInitialContext(SubscriberChainSteps.KEY_BUSY_MILLISECONDS, __BUSY_MILLISECONDS__);
		for(Integer step = 0; step < Math.min(50, Math.max(5, __COUNT__ * 3)); step++)
		{
			slowExport.then(new SubscriberChainSteps.BusyStep());
		}
		executionIds.add(slowExport.execute(runId));
	}
	else if(kind == 'switchedOff')
	{
		executionIds.add(__APEX_NAMESPACE__UTIL_AsyncChain.newChain('Volume_SwitchedOff').then(new SubscriberChainSteps.NarratingStep()).execute(runId));
	}
	else if(kind == 'deferredDispatch')
	{
		executionIds.add(__APEX_NAMESPACE__UTIL_AsyncChain.newChain('Volume_DeferredDispatch')
				.withInitialContext(SubscriberChainSteps.KEY_BUSY_MILLISECONDS, __BUSY_MILLISECONDS__)
				.then(new SubscriberChainSteps.NarratingStep())
				.then(new SubscriberChainSteps.BusyStep())
				.withDelayMinutes(10)
				.execute(runId));
	}
	else if(kind == 'idempotentDeferredDispatch')
	{
		executionIds.add(__APEX_NAMESPACE__UTIL_AsyncChain.newChain('Volume_IdempotentDeferredDispatch')
				.withInitialContext(SubscriberChainSteps.KEY_BUSY_MILLISECONDS, __BUSY_MILLISECONDS__)
				.then(new SubscriberChainSteps.RecoveringStep(), true)
				.then(new SubscriberChainSteps.NarratingStep())
				.then(new SubscriberChainSteps.BusyStep())
				.withDelayMinutes(10)
				.execute(runId));
	}
	else if(kind == 'stallProbe')
	{
		executionIds.add(__APEX_NAMESPACE__UTIL_AsyncChain.newChain('Volume_StallProbe')
				.then(new SubscriberChainSteps.EnqueueSpendingStep())
				.then(new SubscriberChainSteps.NarratingStep())
				.execute(runId));
	}
	else if(kind == 'orderSync')
	{
		executionIds.add(__APEX_NAMESPACE__UTIL_AsyncChain.newChain('Volume_OrderSync')
				.withInitialContext(SubscriberChainSteps.KEY_API_RESPONSE, 'seeded')
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.then(new SubscriberChainSteps.UpdateFoobarStep())
				.then(new SubscriberChainSteps.VerifyContextStep())
				.execute(runId));
	}
	else
	{
		throw new IllegalArgumentException('Unknown wave kind ' + kind);
	}
}
System.debug('VOLUME_LAUNCH stage=' + kind + ' action=' + actionId + ' ordinal=0 ids=' + String.join(executionIds, ',')
		+ ' launched=' + executionIds.size() + ' dml=' + Limits.getDmlStatements() + '/' + Limits.getLimitDmlStatements()
		+ ' enqueued=' + Limits.getQueueableJobs() + '/' + Limits.getLimitQueueableJobs());
