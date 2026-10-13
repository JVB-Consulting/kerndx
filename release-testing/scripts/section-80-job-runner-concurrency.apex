// Section 80 — Job runner concurrency (seed): one due job, then two checks launched at the same instant from the shell.
// Prerequisites: kern__JobRunnerManagement assigned to the runbook user (Phase 1.4); the runner flag on (shipped default).
// The seed also creates the JobRunner row of kern__ScheduleSetting__c when the org has none. Every check records its time on that row, and
// Activate creates it before it schedules the first check, so a runner's own checks never run without it. This section launches its checks
// without activating the runner, so it creates the row itself and the two parallel checks meet the state a real runner's checks meet.
Integer passed = 0;
Integer failed = 0;
delete [SELECT Id FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c = 'Job Runner Concurrency Probe'];
if(kern__ScheduleSetting__c.getValues('JobRunner') == null)
{
	insert new kern__ScheduleSetting__c(Name = 'JobRunner');
}
kern__ScheduledJob__c probe = new kern__ScheduledJob__c(
		kern__SchedulerName__c = 'Job Runner Concurrency Probe',
		kern__ClassName__c = 'kern.SCHED_PurgeRecords',
		kern__CronExpression__c = '0 */5 * * * ?',
		kern__IsActive__c = true,
		kern__Timezone__c = 'UTC',
		kern__ExecutionMode__c = 'JobRunner',
		kern__Parameters__c = '{"nameValueMap":{"objectName":"kern__LogEntry__c","minimumNumberOfDays":"9999","batchSize":"200"}}'
);
insert probe;
update new kern__ScheduledJob__c(Id = probe.Id, kern__NextRunAt__c = System.now().addMinutes(-10));
kern__ScheduledJob__c seeded = [SELECT kern__NextRunAt__c, kern__LastRunJobId__c FROM kern__ScheduledJob__c WHERE Id = :probe.Id];
if(seeded.kern__NextRunAt__c < System.now() && seeded.kern__LastRunJobId__c == null)
{
	passed++;
	System.debug('80-seed PASS: one due job-runner row, never run: ' + probe.Id);
}
else
{
	failed++;
	System.debug('80-seed FAIL: cursor ' + seeded.kern__NextRunAt__c + ' stamp ' + seeded.kern__LastRunJobId__c);
}
System.debug('Section 80 (seed): ' + passed + '/1 passed, ' + failed + ' failed — now launch two checks at once (see the RUNBOOK note), then run 80b');
