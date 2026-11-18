// Elastic limits probe: one due job-runner row (a copy of section-80-job-runner-concurrency.apex's seed, changed).
//
// What changed from section 80's seed: the row is named Elastic Probe Runner Job, so it is found and deleted by name;
// it runs SCHED_SubscriberJob (which records its parameters and does nothing else) instead of kern.SCHED_PurgeRecords,
// because the purge spends more executions once it starts; and it prints its id with a PROBE line instead of the
// section's pass count.
//
// Prerequisites: kern__JobRunnerManagement assigned to the running user; the runner flag on (shipped default). Like
// section 80, it creates the JobRunner row of kern__ScheduleSetting__c when the org has none.
//
// Run: sf apex run -o YourSubscriberOrgAlias -f seed-job-runner-row.apex --json > <file>
final String JOB_NAME = 'Elastic Probe Runner Job';
delete [SELECT Id FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c = :JOB_NAME];
Boolean createdSetting = false;
if(kern__ScheduleSetting__c.getValues('JobRunner') == null)
{
	insert new kern__ScheduleSetting__c(Name = 'JobRunner');
	createdSetting = true;
}
kern__ScheduledJob__c probe = new kern__ScheduledJob__c(
		kern__SchedulerName__c = JOB_NAME,
		kern__ClassName__c = SCHED_SubscriberJob.class.getName(),
		kern__CronExpression__c = '0 */5 * * * ?',
		kern__IsActive__c = true,
		kern__Timezone__c = 'UTC',
		kern__ExecutionMode__c = 'JobRunner',
		kern__Parameters__c = '{"nameValueMap":{"objectName":"Account"}}'
);
insert probe;
update new kern__ScheduledJob__c(Id = probe.Id, kern__NextRunAt__c = System.now().addMinutes(-10));
kern__ScheduledJob__c seeded = [SELECT kern__NextRunAt__c, kern__LastRunJobId__c FROM kern__ScheduledJob__c WHERE Id = :probe.Id];
System.debug('PROBE RUNNER SEED id=' + probe.Id + ' due=' + (seeded.kern__NextRunAt__c < System.now()) + ' lastRunJobId=' + seeded.kern__LastRunJobId__c
		+ ' createdJobRunnerSetting=' + createdSetting);
