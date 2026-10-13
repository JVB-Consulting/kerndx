// Section 80b — Job runner concurrency (verify + cleanup): run after the two parallel checks have returned.
Integer passed = 0;
Integer failed = 0;
List<kern__ScheduledJob__c> probes = [SELECT Id, CreatedDate, kern__NextRunAt__c, kern__LastRunJobId__c, kern__LastRunOutcome__c FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c = 'Job Runner Concurrency Probe'];
if(probes.size() == 1 && probes[0].kern__LastRunJobId__c != null && probes[0].kern__NextRunAt__c > System.now().addMinutes(-1))
{
	passed++;
	System.debug('80b PASS: the row was claimed once; cursor ' + probes[0].kern__NextRunAt__c + ', run ' + probes[0].kern__LastRunJobId__c);
}
else
{
	failed++;
	System.debug('80b FAIL: probe ' + (probes.isEmpty() ? 'MISSING' : probes[0].kern__LastRunJobId__c + ' / ' + probes[0].kern__NextRunAt__c + ' / ' + probes[0].kern__LastRunOutcome__c));
}
// The window starts when the seed created the row: every run either check started falls inside it, and a run from an earlier section, which ended before the seed ran, falls outside it.
Integer runsFromTheseChecks = -1;
Datetime windowStart = System.now().addMinutes(-5);
if(!probes.isEmpty())
{
	Datetime probeCreatedAt = probes[0].CreatedDate;
	windowStart = probeCreatedAt;
	runsFromTheseChecks = [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.NamespacePrefix = 'kern' AND ApexClass.Name = 'UTIL_ScheduledJobRunner' AND JobType = 'Queueable' AND CreatedDate >= :probeCreatedAt];
}
if(runsFromTheseChecks == 1)
{
	passed++;
	System.debug('80b PASS: exactly one run was queued by the two checks (I2)');
}
else
{
	failed++;
	System.debug('80b FAIL: ' + runsFromTheseChecks + ' runs were queued since the seed created the row; two checks must never start one occurrence twice');
}
Integer checkEntries = [SELECT COUNT() FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE '%UTIL_ScheduledJobRunner.checkForDueJobs' AND CreatedDate >= :windowStart];
System.debug('80b observation: ' + checkEntries + ' check log entry(ies) since the seed created the row (a lock-out WARN is one clean exit; a quiet second check that found nothing due writes none)');
if(!probes.isEmpty())
{
	delete [SELECT Id FROM kern__LogEntry__c WHERE kern__RecordId__c = :probes[0].Id];
}
// A lock-out WARN carries no record id, so it is swept by the method that wrote it rather than by the row it names.
delete [SELECT Id FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE '%UTIL_ScheduledJobRunner.checkForDueJobs' AND CreatedDate >= :windowStart];
delete probes;
System.debug('Section 80b (verify): ' + passed + '/2 passed, ' + failed + ' failed — cleanup complete');
