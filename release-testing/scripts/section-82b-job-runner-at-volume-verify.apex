// Section 82b — The job runner at volume (verify): run after the first check has returned.
Integer passed = 0;
Integer failed = 0;
Integer checkLimit = 25;
List<kern__AsynchronousJobSetting__mdt> limitRows = [SELECT kern__BatchSize__c FROM kern__AsynchronousJobSetting__mdt WHERE DeveloperName = 'JobRunnerCheckLimit' LIMIT 1];
if(!limitRows.isEmpty() && limitRows[0].kern__BatchSize__c != null)
{
	checkLimit = Integer.valueOf(limitRows[0].kern__BatchSize__c);
}
List<kern__ScheduledJob__c> probes = [SELECT Id, kern__SchedulerName__c, kern__RunPriority__c, kern__NextRunAt__c, kern__LastRunJobId__c FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c LIKE 'Volume Probe%' ORDER BY kern__RunPriority__c ASC NULLS LAST, Id ASC];
List<Id> startedIds = new List<Id>();
List<Id> leftWaitingIds = new List<Id>();
Datetime seededDueAt = null;
for(kern__ScheduledJob__c probe : probes)
{
	if(probe.kern__LastRunJobId__c == null)
	{
		leftWaitingIds.add(probe.Id);
		seededDueAt = seededDueAt == null || probe.kern__NextRunAt__c < seededDueAt ? probe.kern__NextRunAt__c : seededDueAt;
	}
	else
	{
		startedIds.add(probe.Id);
	}
}

// 82b-1: exactly the limit was started, and they are the rows the claim's order names — run priority ascending
// with the blanks last, then the oldest cursor, then the lowest Id. Every seeded cursor was the same instant, so
// priority and Id decide the whole order.
List<Id> expectedIds = new List<Id>();
for(kern__ScheduledJob__c probe : probes)
{
	if(expectedIds.size() < checkLimit)
	{
		expectedIds.add(probe.Id);
	}
}
Boolean startedInClaimOrder = startedIds.size() == checkLimit && new Set<Id>(startedIds).containsAll(expectedIds);
Boolean cursorsMovedOn = startedInClaimOrder;
for(kern__ScheduledJob__c probe : probes)
{
	if(probe.kern__LastRunJobId__c != null && seededDueAt != null && probe.kern__NextRunAt__c <= seededDueAt)
	{
		cursorsMovedOn = false;
	}
}
if(startedInClaimOrder && cursorsMovedOn)
{
	passed++;
	System.debug('82b PASS: exactly ' + checkLimit + ' rows were started, in the claim\'s order, each with its cursor moved past the seeded due time');
}
else
{
	failed++;
	System.debug('82b FAIL: ' + startedIds.size() + ' started of ' + probes.size() + ' (limit ' + checkLimit + '), claim order ' + startedInClaimOrder + ', cursors moved ' + cursorsMovedOn);
}

// 82b-2: the rest were left exactly as they were — still due, never started.
Integer expectedLeftWaiting = probes.size() - checkLimit;
// The seeded cursor is checked against the clock too, so ten rows all moved on to one new instant cannot pass as untouched.
Boolean leftUntouched = leftWaitingIds.size() == expectedLeftWaiting && seededDueAt != null && seededDueAt < System.now().addMinutes(-5);
for(kern__ScheduledJob__c probe : probes)
{
	if(probe.kern__LastRunJobId__c == null && probe.kern__NextRunAt__c != seededDueAt)
	{
		leftUntouched = false;
	}
}
if(leftUntouched)
{
	passed++;
	System.debug('82b PASS: the other ' + leftWaitingIds.size() + ' rows keep the seeded cursor ' + seededDueAt + ' and carry no run id');
}
else
{
	failed++;
	System.debug('82b FAIL: ' + leftWaitingIds.size() + ' rows left waiting, expected ' + expectedLeftWaiting + ', all holding the seeded cursor ' + seededDueAt);
}

// 82b-3: the platform saw exactly the limit start, one run per started row. The runs are looked up by the ids the
// rows themselves carry, so an unrelated run from an earlier section can neither be counted in nor stand in for one.
Set<Id> startedRunIds = new Set<Id>();
for(kern__ScheduledJob__c probe : probes)
{
	if(probe.kern__LastRunJobId__c != null)
	{
		startedRunIds.add(Id.valueOf(probe.kern__LastRunJobId__c));
	}
}
Integer runsQueued = [SELECT COUNT() FROM AsyncApexJob WHERE Id IN :startedRunIds AND ApexClass.NamespacePrefix = 'kern' AND ApexClass.Name = 'UTIL_ScheduledJobRunner' AND JobType = 'Queueable'];
if(startedRunIds.size() == checkLimit && runsQueued == checkLimit)
{
	passed++;
	System.debug('82b PASS: exactly ' + runsQueued + ' runs of the runner\'s own queueable were queued, one distinct run per started row');
}
else
{
	failed++;
	System.debug('82b FAIL: ' + startedRunIds.size() + ' distinct run stamps and ' + runsQueued + ' matching runner runs, expected ' + checkLimit + ' of each');
}

// 82b-4: one warning, naming how many were left and what the limit is. Message__c is a Long Text Area, which
// SOQL LIKE cannot filter, so the window is pulled and matched here. SOQL has no minute-level date literal either,
// so the window itself is a bound instant.
Datetime windowStart = System.now().addMinutes(-5);
List<kern__LogEntry__c> checkEntries = [SELECT kern__Message__c FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE '%UTIL_ScheduledJobRunner.checkForDueJobs' AND CreatedDate >= :windowStart];
List<String> leftWaitingWarnings = new List<String>();
for(kern__LogEntry__c entry : checkEntries)
{
	if(entry.kern__Message__c != null && entry.kern__Message__c.contains('left for the next check'))
	{
		leftWaitingWarnings.add(entry.kern__Message__c);
	}
}
if(leftWaitingWarnings.size() == 1 && leftWaitingWarnings[0].contains(String.valueOf(expectedLeftWaiting) + ' due job') && leftWaitingWarnings[0].contains('at most ' + checkLimit + ' jobs'))
{
	passed++;
	System.debug('82b PASS: one warning, naming ' + expectedLeftWaiting + ' left and a limit of ' + checkLimit + ': ' + leftWaitingWarnings[0]);
}
else
{
	failed++;
	System.debug('82b FAIL: ' + leftWaitingWarnings.size() + ' left-waiting warning(s) of ' + checkEntries.size() + ' check entry(ies): ' + leftWaitingWarnings + ' — log persistence is event-driven, so re-run 82b once before treating this as a product failure');
}

System.debug('Section 82b (verify): ' + passed + '/4 passed, ' + failed + ' failed — now run a second check, then 82c');
