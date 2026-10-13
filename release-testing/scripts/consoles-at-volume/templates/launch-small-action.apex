// Consoles at volume: one small action, its launches under its token-keyed action id, in one transaction (the first
// correlation a transaction sets is the root of every run and entry that follows). The plan is the action's launches
// as JSON, [{"shape":"OrderSync","count":3}, ...]; the shapes are today's seven from seed-chain-scenarios.apex plus a
// two-level nested import and a handler that launches a chain. Every run id is keyed by the token.
// Tokens: __APEX_NAMESPACE__ __ACTION_ID__ __RUN_TOKEN__ __ACTION_ORDINAL__ __LAUNCH_PLAN__
__APEX_NAMESPACE__LOG_Builder.setCorrelationId('__ACTION_ID__');
String actionId = '__ACTION_ID__';
String runToken = '__RUN_TOKEN__';
Integer actionOrdinal = __ACTION_ORDINAL__;
List<Object> plan = (List<Object>)JSON.deserializeUntyped('__LAUNCH_PLAN__');
List<String> executionIds = new List<String>();
Integer launchIndex = 0;
for(Object entry : plan)
{
	Map<String, Object> launch = (Map<String, Object>)entry;
	String shape = (String)launch.get('shape');
	Integer count = (Integer)launch.get('count');
	for(Integer index = 0; index < count; index++)
	{
		String runId = SubscriberChainSteps.volumeRunId(runToken, SubscriberChainSteps.KIND_SMALL_ACTION_RUN, actionOrdinal + 1, launchIndex, 0);
		if(shape == 'OrderSync')
		{
			executionIds.add(__APEX_NAMESPACE__UTIL_AsyncChain.newChain('Volume_OrderSync')
					.withInitialContext(SubscriberChainSteps.KEY_API_RESPONSE, 'seeded')
					.then(new SubscriberChainSteps.CreateFoobarStep())
					.then(new SubscriberChainSteps.UpdateFoobarStep())
					.then(new SubscriberChainSteps.VerifyContextStep())
					.onComplete(new SubscriberChainSteps.CompletionHandlerStep())
					.execute(runId));
		}
		else if(shape == 'InvoiceExport')
		{
			executionIds.add(__APEX_NAMESPACE__UTIL_AsyncChain.newChain('Volume_InvoiceExport')
					.withInitialContext(SubscriberChainSteps.KEY_API_RESPONSE, 'seeded')
					.then(new SubscriberChainSteps.CreateFoobarStep())
					.then(new SubscriberChainSteps.UpdateFoobarStep())
					.then(new SubscriberChainSteps.FailingStep())
					.then(new SubscriberChainSteps.UpdateFoobarStep())
					.then(new SubscriberChainSteps.VerifyContextStep())
					.onError(new SubscriberChainSteps.ErrorHandlerStep())
					.execute(runId));
		}
		else if(shape == 'PartialSync')
		{
			executionIds.add(__APEX_NAMESPACE__UTIL_AsyncChain.newChain('Volume_PartialSync')
					.then(new SubscriberChainSteps.CreateFoobarStep())
					.then(new SubscriberChainSteps.OptionalFailingStep(), true)
					.then(new SubscriberChainSteps.UpdateFoobarStep())
					.execute(runId));
		}
		else if(shape == 'RecoverableImport')
		{
			executionIds.add(__APEX_NAMESPACE__UTIL_AsyncChain.newChain('Volume_RecoverableImport').then(new SubscriberChainSteps.RecoveringStep()).allowRestart().execute(runId));
		}
		else if(shape == 'RestartableLoad')
		{
			executionIds.add(__APEX_NAMESPACE__UTIL_AsyncChain.newChain('Volume_RestartableLoad').then(new SubscriberChainSteps.FailingStep()).allowRestart().execute(runId));
		}
		else if(shape == 'NightlyReconciliation')
		{
			__APEX_NAMESPACE__UTIL_AsyncChain.ChainBuilder nightly = __APEX_NAMESPACE__UTIL_AsyncChain.newChain('Volume_NightlyReconciliation');
			for(Integer step = 0; step < 30; step++)
			{
				nightly.then(new SubscriberChainSteps.WriteContextStep());
			}
			executionIds.add(nightly.execute(runId));
		}
		else if(shape == 'DeferredNotification')
		{
			executionIds.add(__APEX_NAMESPACE__UTIL_AsyncChain.newChain('Volume_DeferredNotification')
					.then(new SubscriberChainSteps.CreateFoobarStep())
					.withDelayMinutes(10)
					.execute(runId));
		}
		else if(shape == 'NestedImport')
		{
			// Its fan-out children are keyed under root ordinal 1000 plus the action's ordinal, clear of the reconciliation's roots.
			executionIds.add(__APEX_NAMESPACE__UTIL_AsyncChain.newChain('Volume_NestedImport')
					.withInitialContext(SubscriberChainSteps.KEY_VOLUME_DEPTH, 0)
					.withInitialContext(SubscriberChainSteps.KEY_VOLUME_TARGET_DEPTH, 2)
					.withInitialContext(SubscriberChainSteps.KEY_VOLUME_ORDINAL, 0)
					.withInitialContext(SubscriberChainSteps.KEY_VOLUME_ROOT_ORDINAL, 1000 + actionOrdinal)
					.withInitialContext(SubscriberChainSteps.KEY_VOLUME_RUN_IDENTIFIER, runToken)
					.withInitialContext(SubscriberChainSteps.KEY_BUSY_MILLISECONDS, 300)
					.then(new SubscriberChainSteps.FanOutStep())
					.then(new SubscriberChainSteps.NarratingStep())
					.execute(runId));
		}
		else if(shape == 'OrderSyncNotified')
		{
			executionIds.add(__APEX_NAMESPACE__UTIL_AsyncChain.newChain('Volume_OrderSyncNotified')
					.withInitialContext(SubscriberChainSteps.KEY_API_RESPONSE, 'seeded')
					.then(new SubscriberChainSteps.CreateFoobarStep())
					.then(new SubscriberChainSteps.UpdateFoobarStep())
					.onComplete(new SubscriberChainSteps.LaunchChildChainStep())
					.execute(runId));
		}
		else
		{
			throw new IllegalArgumentException('Unknown small-action shape ' + shape);
		}
		launchIndex++;
	}
}
System.debug('VOLUME_LAUNCH stage=small action=' + actionId + ' ordinal=' + actionOrdinal + ' ids=' + String.join(executionIds, ',')
		+ ' launched=' + executionIds.size() + ' dml=' + Limits.getDmlStatements() + '/' + Limits.getLimitDmlStatements()
		+ ' enqueued=' + Limits.getQueueableJobs() + '/' + Limits.getLimitQueueableJobs());
