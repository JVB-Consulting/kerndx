// Elastic limits probe: seed two stuck chain runs for one watchdog pass (section 79's seed shape).
//
// First deletes the rows this script seeded earlier (correlation id starting elasticprobe-seed). Then inserts, each
// Running with LastModifiedDate back-dated 45 minutes and no end time, so any threshold under 45 minutes sees it as
// stuck:
//   1. Re-drive: CurrentJobId__c holds the id of a Completed ElasticProbeFiller job read from the org, so the watchdog
//      can prove the run's job is dead. The step log's first step succeeded and its second step
//      (SubscriberChainSteps.NoWriteStep, which needs nothing from the first) has not started, so the watchdog's
//      re-drive reaches its enqueue of that step.
//   2. Stall and notify: the same, but with no CurrentJobId__c and an onError handler entry
//      (SubscriberChainSteps.ErrorHandlerStep), so the sweep marks it Stalled and queues the handler.
// Needs audit-field back-dating (KernE2EAuditFieldAccess) and at least one Completed ElasticProbeFiller job; it stops
// with a message when there is none. Prints both ids.
//
// Run: sf apex run -o YourSubscriberOrgAlias -f seed-redrivable-chain.apex --json > <file>
final String SEED_MARKER = 'elasticprobe-seed%';
final String TIME_ZONE = 'America/New_York';
final String TIME_FORMAT = 'yyyy-MM-dd HH:mm:ss';

delete [SELECT Id FROM kern__AsyncChainExecution__c WHERE kern__CorrelationId__c LIKE :SEED_MARKER];

List<AsyncApexJob> fillers = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'ElasticProbeFiller' AND Status = 'Completed' ORDER BY CompletedDate DESC LIMIT 1];
if(fillers.isEmpty())
{
	System.debug('PROBE SEED stopped: no Completed ElasticProbeFiller job in the org; queue one with spend-budget.apex first');
	return;
}

List<Map<String, Object>> redriveLog = new List<Map<String, Object>>
{
		new Map<String, Object> {'className' => 'SubscriberChainSteps.WriteContextStep', 'stepName' => 'Write Context', 'started' => true, 'success' => true, 'durationMs' => 120},
		new Map<String, Object> {'className' => 'SubscriberChainSteps.NoWriteStep', 'stepName' => 'No Write'}
};
List<Map<String, Object>> stallLog = new List<Map<String, Object>>(redriveLog);
stallLog.add(new Map<String, Object> {'className' => 'SubscriberChainSteps.ErrorHandlerStep', 'stepName' => 'Error Handler', 'isErrorHandler' => true});

List<kern__AsyncChainExecution__c> rows = new List<kern__AsyncChainExecution__c>();
for(Integer index = 0; index < 2; index++)
{
	Boolean isRedrive = index == 0;
	rows.add(new kern__AsyncChainExecution__c(
			kern__ChainName__c = isRedrive ? 'Elastic Probe Redrive' : 'Elastic Probe Stall',
			kern__Status__c = 'Running',
			kern__CorrelationId__c = 'elasticprobe-seed-' + (isRedrive ? 'redrive-' : 'stall-') + EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 10),
			kern__CurrentStepName__c = 'No Write',
			kern__CurrentJobId__c = isRedrive ? fillers[0].Id : null,
			kern__TotalSteps__c = 2,
			kern__CompletedSteps__c = 1,
			kern__StartedAt__c = System.now().addMinutes(-46),
			CreatedDate = System.now().addMinutes(-46),
			kern__StepLog__c = JSON.serialize(isRedrive ? redriveLog : stallLog),
			LastModifiedDate = System.now().addMinutes(-45)
	));
}
insert rows;
for(kern__AsyncChainExecution__c inserted : [SELECT Id, kern__ChainName__c, kern__CurrentJobId__c, LastModifiedDate FROM kern__AsyncChainExecution__c WHERE Id IN :rows])
{
	System.debug('PROBE SEED ' + inserted.kern__ChainName__c + ' id=' + inserted.Id + ' job=' + inserted.kern__CurrentJobId__c
			+ ' modified=' + inserted.LastModifiedDate.format(TIME_FORMAT, TIME_ZONE) + ' backDated=' + (inserted.LastModifiedDate < System.now().addMinutes(-40)));
}
