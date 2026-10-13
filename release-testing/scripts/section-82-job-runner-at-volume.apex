// Section 82 — The job runner at volume (seed): more jobs are due than one check may start.
// The promise a subscriber with dozens of jobs relies on: the check starts them in run-priority order up to its
// per-check limit, leaves the rest untouched for the next check, and says so once.
// Prerequisites: kern__JobRunnerManagement assigned to the runbook user (Phase 1.4); the runner flag on.
// The probes carry a daily expression on purpose: a started row's cursor moves to its next occurrence, and with a
// five-minute expression a row started by the first check would fall due again inside the section and the second
// check would start it a second time, failing 82c on a healthy product.
Integer passed = 0;
Integer failed = 0;
Integer checkLimit = 25;
List<kern__AsynchronousJobSetting__mdt> limitRows = [SELECT kern__BatchSize__c FROM kern__AsynchronousJobSetting__mdt WHERE DeveloperName = 'JobRunnerCheckLimit' LIMIT 1];
if(!limitRows.isEmpty() && limitRows[0].kern__BatchSize__c != null)
{
	checkLimit = Integer.valueOf(limitRows[0].kern__BatchSize__c);
}
Integer overTheLimit = 10;
delete [SELECT Id FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c LIKE 'Volume Probe%'];
List<kern__ScheduledJob__c> probes = new List<kern__ScheduledJob__c>();
for(Integer index = 1; index <= checkLimit + overTheLimit; index++)
{
	Decimal runPriority = index <= 10 ? 1 : (index <= 20 ? 2 : null);
	probes.add(new kern__ScheduledJob__c(
			kern__SchedulerName__c = 'Volume Probe ' + String.valueOf(index).leftPad(2, '0'),
			kern__ClassName__c = 'kern.SCHED_PurgeRecords',
			kern__CronExpression__c = '0 0 0 * * ?',
			kern__IsActive__c = true,
			kern__Timezone__c = 'UTC',
			kern__ExecutionMode__c = 'JobRunner',
			kern__RunPriority__c = runPriority,
			kern__Parameters__c = '{"nameValueMap":{"objectName":"kern__LogEntry__c","minimumNumberOfDays":"9999","batchSize":"200"}}'
	));
}
insert probes;
Datetime dueAt = System.now().addMinutes(-10);
for(kern__ScheduledJob__c probe : probes)
{
	probe.kern__NextRunAt__c = dueAt;
}
update probes;
Integer dueNow = [SELECT COUNT() FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c LIKE 'Volume Probe%' AND kern__NextRunAt__c <= :System.now() AND kern__LastRunJobId__c = null];
if(dueNow == checkLimit + overTheLimit)
{
	passed++;
	System.debug('82-seed PASS: ' + dueNow + ' due job-runner rows, limit ' + checkLimit + ', seeded due at ' + dueAt);
}
else
{
	failed++;
	System.debug('82-seed FAIL: ' + dueNow + ' due rows, expected ' + (checkLimit + overTheLimit) + ' (limit ' + checkLimit + ')');
}
System.debug('Section 82 (seed): ' + passed + '/1 passed, ' + failed + ' failed — now run one check (see the RUNBOOK note), then 82b');
