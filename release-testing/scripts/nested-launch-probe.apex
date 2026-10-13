// Nested chain launch probe: three parents in one action. See RUNBOOK.md, "Nested chain launch probe".
kern.LOG_Builder.startCorrelation();
AsyncOptions tightCap = new AsyncOptions();
tightCap.maximumQueueableStackDepth = 2;
kern.UTIL_AsyncChain.newChain('SubscriberNestedParent')
		.then(new SubscriberChainSteps.LaunchChildChainStep())
		.withAsyncOptions(tightCap)
		.execute();
kern.UTIL_AsyncChain.newChain('SubscriberNestedHandlerParent')
		.then(new SubscriberChainSteps.WriteContextStep())
		.onComplete(new SubscriberChainSteps.LaunchChildChainStep())
		.execute();
kern.UTIL_AsyncChain.newChain('SubscriberNestedUncappedParent')
		.then(new SubscriberChainSteps.LaunchChildChainStep())
		.withAsyncOptions(new AsyncOptions())
		.execute();
