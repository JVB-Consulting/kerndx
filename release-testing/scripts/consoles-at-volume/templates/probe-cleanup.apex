// Consoles at volume, the probe: removes the probe's rows, jobs and log entries. Runs after the report is recorded.
// Tokens: __FIELD_NAMESPACE__ (filled by the runner).
// The underscore is escaped through a bound variable: an inline literal 'Volume\\_%' matches nothing (measured 2026-09-24).
String volumeChainNames = 'Volume\\_%';
delete [SELECT Id FROM __FIELD_NAMESPACE__AsyncChainExecution__c WHERE __FIELD_NAMESPACE__ChainName__c LIKE :volumeChainNames LIMIT 9000];
delete [SELECT Id FROM __FIELD_NAMESPACE__LogEntry__c WHERE __FIELD_NAMESPACE__ClassMethod__c LIKE 'SubscriberChainSteps.%' LIMIT 9000];
for(CronTrigger job : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE 'Consoles At Volume%'])
{
	System.abortJob(job.Id);
}
System.debug('VOLUME_PROBE cleanup=done');
