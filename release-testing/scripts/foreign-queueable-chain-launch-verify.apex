// Chain launch from a trigger inside a Queueable: verification. See RUNBOOK.md,
// "Chain launch from a trigger inside a Queueable".
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites: release-testing/scripts/foreign-queueable-chain-launch.apex ran, and its jobs finished (about 60 seconds).
//
// Prints one PASS or FAIL line for each of the three cases.
// OtherPackageQueueableChain and SubscriberQueueableChain: only runs created since the newest ChainStepParentChain run
// (the start of this attempt) count. PASS means the newest such run is Completed with 2 completed steps, and none is left
// Running without a job id. WAIT means no run from this attempt exists yet, or the newest one is still running with a job.
// ChainStepChain: PASS means the newest ChainStepParentChain run is Completed with 2 steps, and the newest ChainStepChain
// run is Completed with 2 steps, its launch id equals the parent's correlation id, and its declared deduplication key is
// the parent's record id followed by ':0'.
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/foreign-queueable-chain-launch-verify.apex > tmp/foreign-queueable-verify.log 2>&1
//   grep USER_DEBUG tmp/foreign-queueable-verify.log

Map<String, List<kern__AsyncChainExecution__c>> runsByChain = new Map<String, List<kern__AsyncChainExecution__c>>();
List<String> chainNames = new List<String>{ 'OtherPackageQueueableChain', 'SubscriberQueueableChain', 'ChainStepParentChain', 'ChainStepChain' };
for(String chainName : chainNames)
{
	runsByChain.put(chainName, new List<kern__AsyncChainExecution__c>());
}
for(kern__AsyncChainExecution__c run :
[
		SELECT kern__ChainName__c,
				kern__Status__c,
				kern__CompletedSteps__c,
				kern__CurrentJobId__c,
				kern__ErrorMessage__c,
				kern__CorrelationId__c,
				kern__LaunchCorrelationId__c,
				kern__DeclaredDeduplicationKey__c,
				CreatedDate
		FROM kern__AsyncChainExecution__c
		WHERE kern__ChainName__c IN :chainNames
		ORDER BY CreatedDate DESC
])
{
	runsByChain.get(run.kern__ChainName__c).add(run);
}

// The launch script saves the ChainStepParentChain run before it returns, so its creation time marks the start of this attempt.
List<kern__AsyncChainExecution__c> attemptMarkers = runsByChain.get('ChainStepParentChain');
Datetime attemptStart = attemptMarkers.isEmpty() ? null : attemptMarkers[0].CreatedDate;
for(String chainName : new List<String>{ 'OtherPackageQueueableChain', 'SubscriberQueueableChain' })
{
	List<kern__AsyncChainExecution__c> runs = new List<kern__AsyncChainExecution__c>();
	Integer runningWithoutJob = 0;
	for(kern__AsyncChainExecution__c run : runsByChain.get(chainName))
	{
		if(attemptStart != null && run.CreatedDate >= attemptStart)
		{
			runs.add(run);
			if(run.kern__Status__c == 'Running' && String.isBlank(run.kern__CurrentJobId__c))
			{
				runningWithoutJob++;
			}
		}
	}

	if(runs.isEmpty())
	{
		System.debug('foreign-queueable-verify WAIT: ' + chainName + ': no run from this attempt yet, wait and run the verify script again');
	}
	else if(runs[0].kern__Status__c == 'Running' && String.isNotBlank(runs[0].kern__CurrentJobId__c))
	{
		System.debug('foreign-queueable-verify WAIT: ' + chainName + ': still running, wait and run again');
	}
	else if(runs[0].kern__Status__c == 'Completed' && runs[0].kern__CompletedSteps__c == 2 && runningWithoutJob == 0)
	{
		System.debug('foreign-queueable-verify PASS: ' + chainName + ': Completed with 2 steps, ' + runs.size() + ' run(s), none Running without a job');
	}
	else
	{
		System.debug('foreign-queueable-verify FAIL: ' + chainName + ': newest run ' + runs[0].kern__Status__c + ' with '
				+ runs[0].kern__CompletedSteps__c + ' completed step(s), job id ' + runs[0].kern__CurrentJobId__c + ', error '
				+ runs[0].kern__ErrorMessage__c + '; runs Running without a job: ' + runningWithoutJob);
	}
}

List<kern__AsyncChainExecution__c> parents = runsByChain.get('ChainStepParentChain');
List<kern__AsyncChainExecution__c> children = runsByChain.get('ChainStepChain');
if(parents.isEmpty())
{
	System.debug('foreign-queueable-verify FAIL: ChainStepChain: no ChainStepParentChain run found');
}
else
{
	kern__AsyncChainExecution__c parent = parents[0];
	String parentState = 'parent ' + parent.kern__Status__c + ' with ' + parent.kern__CompletedSteps__c + ' completed step(s)';
	if(parent.kern__Status__c == 'Running' && String.isNotBlank(parent.kern__CurrentJobId__c))
	{
		System.debug('foreign-queueable-verify WAIT: ChainStepChain: ' + parentState + ', still running, wait and run again');
	}
	else if(children.isEmpty())
	{
		System.debug('foreign-queueable-verify FAIL: ChainStepChain: no child run found; ' + parentState);
	}
	else
	{
		kern__AsyncChainExecution__c child = children[0];
		String parentId = String.valueOf(parent.Id);
		Boolean parentDone = parent.kern__Status__c == 'Completed' && parent.kern__CompletedSteps__c == 2;
		Boolean childDone = child.kern__Status__c == 'Completed' && child.kern__CompletedSteps__c == 2;
		Boolean linked = child.kern__LaunchCorrelationId__c == parent.kern__CorrelationId__c
				&& child.kern__DeclaredDeduplicationKey__c == parentId + ':0';
		String childState = 'child ' + child.kern__Status__c + ' with ' + child.kern__CompletedSteps__c + ' completed step(s), launch id '
				+ child.kern__LaunchCorrelationId__c + ' (parent correlation id ' + parent.kern__CorrelationId__c + '), key '
				+ child.kern__DeclaredDeduplicationKey__c + ', error ' + child.kern__ErrorMessage__c;
		Boolean childStillRunning = linked && child.kern__Status__c == 'Running' && String.isNotBlank(child.kern__CurrentJobId__c);
		String verdict = parentDone && childDone && linked ? 'PASS' : (childStillRunning ? 'WAIT' : 'FAIL');
		System.debug('foreign-queueable-verify ' + verdict + ': ChainStepChain: ' + parentState + '; ' + childState);
	}
}
