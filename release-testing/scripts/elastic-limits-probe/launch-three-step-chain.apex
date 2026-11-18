// Elastic limits probe: launch one chain of three SubscriberChainSteps steps.
//
// Token:
//   __HANDLER__  none, or the class name of a SubscriberChainSteps step to run as the chain's onError handler
//                (for example SubscriberChainSteps.ErrorHandlerStep).
//
// The run's correlation id starts with elasticprobe, which is how read-budget.apex and clean-up.apex find it. Prints the
// execution id and the run's first state, or the exception's type and message and whether a run row was left behind.
//
// Run: sf apex run -o YourSubscriberOrgAlias -f <rendered copy with the token replaced> --json > <file>
final String HANDLER = '__HANDLER__';
final String CHAIN_NAME = 'Elastic Probe Chain';
final String TIME_ZONE = 'America/New_York';
final String TIME_FORMAT = 'yyyy-MM-dd HH:mm:ss';
final String CORRELATION_ID = 'elasticprobe-chain-' + EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 12);

System.OrgLimit daily = OrgLimits.getMap().get('DailyAsyncApexExecutions');
System.debug('PROBE CHAIN LAUNCH time=' + System.now().format(TIME_FORMAT, TIME_ZONE) + ' remaining=' + (daily.getLimit() - daily.getValue())
		+ ' handler=' + HANDLER + ' correlation=' + CORRELATION_ID);
try
{
	kern.UTIL_AsyncChain.ChainBuilder builder = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
			.then(new SubscriberChainSteps.WriteContextStep())
			.then(new SubscriberChainSteps.WriteContextStep())
			.then(new SubscriberChainSteps.WriteContextStep());
	if(HANDLER != 'none')
	{
		builder.onError((kern.IF_Chain.Step)Type.forName(HANDLER).newInstance());
	}
	String executionId = builder.execute(CORRELATION_ID);
	kern__AsyncChainExecution__c run = [SELECT kern__Status__c, kern__CurrentJobId__c FROM kern__AsyncChainExecution__c WHERE Id = :executionId];
	List<AsyncApexJob> jobs = [SELECT Status FROM AsyncApexJob WHERE Id = :run.kern__CurrentJobId__c];
	System.debug('PROBE CHAIN LAUNCH accepted execution=' + executionId + ' status=' + run.kern__Status__c + ' job=' + run.kern__CurrentJobId__c
			+ ' jobStatus=' + (jobs.isEmpty() ? null : jobs[0].Status));
}
catch(Exception launchError)
{
	System.debug('PROBE CHAIN LAUNCH refused ' + launchError.getTypeName() + ': ' + launchError.getMessage());
	System.debug('PROBE CHAIN LAUNCH rows left for this correlation=' + [SELECT COUNT() FROM kern__AsyncChainExecution__c WHERE kern__CorrelationId__c = :CORRELATION_ID]);
}
