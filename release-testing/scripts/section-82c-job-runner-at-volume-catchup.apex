// Section 82c — The job runner at volume (catch-up + cleanup): run after the second check has returned.
// The next check picks up what the first one had no room for, and says nothing more about it.
Integer passed = 0;
Integer failed = 0;
List<kern__ScheduledJob__c> probes = [SELECT Id, kern__SchedulerName__c, kern__NextRunAt__c, kern__LastRunJobId__c FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c LIKE 'Volume Probe%'];

// 82c-1: nothing is still waiting — every seeded row has now been started and its cursor has moved on.
Integer stillWaiting = 0;
for(kern__ScheduledJob__c probe : probes)
{
	if(probe.kern__LastRunJobId__c == null || probe.kern__NextRunAt__c <= System.now())
	{
		stillWaiting++;
	}
}
if(!probes.isEmpty() && stillWaiting == 0)
{
	passed++;
	System.debug('82c PASS: all ' + probes.size() + ' rows have been started and carry a cursor in the future');
}
else
{
	failed++;
	System.debug('82c FAIL: ' + stillWaiting + ' of ' + probes.size() + ' rows are still waiting after the second check');
}

// 82c-2: the warning was written once, by the check that ran out of room, and not again by the one that caught up.
// SOQL has no minute-level date literal, so the window is a bound instant wide enough to hold both checks.
Datetime windowStart = System.now().addMinutes(-10);
List<kern__LogEntry__c> checkEntries = [SELECT Id, kern__Message__c FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE '%UTIL_ScheduledJobRunner.checkForDueJobs' AND CreatedDate >= :windowStart];
Integer leftWaitingWarnings = 0;
for(kern__LogEntry__c entry : checkEntries)
{
	if(entry.kern__Message__c != null && entry.kern__Message__c.contains('left for the next check'))
	{
		leftWaitingWarnings++;
	}
}
if(leftWaitingWarnings == 1)
{
	passed++;
	System.debug('82c PASS: the left-waiting warning was written once across both checks');
}
else
{
	failed++;
	System.debug('82c FAIL: ' + leftWaitingWarnings + ' left-waiting warning(s) across both checks, expected 1');
}

// Cleanup: the probe rows and every log entry the section wrote — the org returns to the no-runner baseline.
Set<Id> probeIds = new Map<Id, kern__ScheduledJob__c>(probes).keySet();
delete [SELECT Id FROM kern__LogEntry__c WHERE kern__RecordId__c IN :probeIds];
delete checkEntries;
delete probes;
System.debug('Section 82c (catch-up): ' + passed + '/2 passed, ' + failed + ' failed — cleanup complete');
