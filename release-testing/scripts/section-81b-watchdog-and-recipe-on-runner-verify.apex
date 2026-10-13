// Section 81b — The watchdog and the recipe on the job runner (verify + cleanup): run AFTER the fire time
// section 81 debugs. Proves both framework jobs did their real work from the runner, neither holding a slot.
Integer passed = 0;
Integer failed = 0;

// 81b-1: the watchdog, running from the job runner, marked the silently-stuck chain Stalled.
List<kern__AsyncChainExecution__c> probes = [SELECT Id, kern__Status__c FROM kern__AsyncChainExecution__c WHERE kern__ChainName__c = 'Watchdog On Runner Probe'];
if(probes.size() == 1 && probes[0].kern__Status__c == 'Stalled')
{
	passed++;
	System.debug('81b PASS: the watchdog ran from the job runner and marked the stuck chain Stalled');
}
else
{
	failed++;
	System.debug('81b FAIL: probe status = ' + (probes.isEmpty() ? 'MISSING' : probes[0].kern__Status__c) + ' — has the check fired yet? This script has already cleaned up: re-run the whole of section 81, and wait longer before 81b, before treating this as a product failure');
}

// 81b-2: the watchdog record itself: it ran, it succeeded, it never took a scheduled job of its own, and its
// cursor moved on to the next occurrence.
List<kern__ScheduledJob__c> watchdogRecords = [SELECT Id, CreatedDate, kern__LastRunOutcome__c, kern__LastRunReason__c, kern__ScheduledJobId__c, kern__NextRunAt__c, kern__LastRunJobId__c FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c = 'Watchdog On Runner'];
// The seed back-dated the cursor to ten minutes before the record existed, so a cursor later than the record's own
// creation is one the check moved on, however late this script runs.
if(watchdogRecords.size() == 1 && watchdogRecords[0].kern__LastRunOutcome__c == 'Succeeded' && watchdogRecords[0].kern__ScheduledJobId__c == null && watchdogRecords[0].kern__NextRunAt__c > watchdogRecords[0].CreatedDate)
{
	passed++;
	System.debug('81b PASS: the watchdog ran on the runner without a slot and its cursor moved on; run ' + watchdogRecords[0].kern__LastRunJobId__c + ', next ' + watchdogRecords[0].kern__NextRunAt__c);
}
else
{
	failed++;
	System.debug('81b FAIL: watchdog record ' + (watchdogRecords.isEmpty() ? 'MISSING' : watchdogRecords[0].kern__LastRunOutcome__c + ' / reason ' + watchdogRecords[0].kern__LastRunReason__c + ' / slot ' + watchdogRecords[0].kern__ScheduledJobId__c + ' / next ' + watchdogRecords[0].kern__NextRunAt__c));
}

// 81b-3: the subscriber recipe started its chain from the runner, and the chain is not Failed.
List<kern__AsyncChainExecution__c> recipeRuns = [SELECT Id, kern__Status__c FROM kern__AsyncChainExecution__c WHERE kern__ChainName__c = 'Nightly Order Export' ORDER BY CreatedDate DESC];
if(!recipeRuns.isEmpty() && recipeRuns[0].kern__Status__c != 'Failed')
{
	passed++;
	System.debug('81b PASS: the recipe started its chain from the runner; status ' + recipeRuns[0].kern__Status__c);
}
else
{
	failed++;
	System.debug('81b FAIL: recipe chain ' + (recipeRuns.isEmpty() ? 'MISSING' : recipeRuns[0].kern__Status__c));
}

// Cleanup: abort the one-off CronTrigger if it lingers, then delete both records, the probe chain, the recipe's
// chain execution and the log entries the section wrote — the org returns to the no-runner, no-watchdog baseline.
for(CronTrigger trigger_x : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Section 81 Job Runner Check'])
{
	System.abortJob(trigger_x.Id);
}
Set<Id> sectionRecordIds = new Set<Id>();
for(kern__ScheduledJob__c record : watchdogRecords)
{
	sectionRecordIds.add(record.Id);
}
for(kern__AsyncChainExecution__c chainRun : probes)
{
	sectionRecordIds.add(chainRun.Id);
}
for(kern__AsyncChainExecution__c chainRun : recipeRuns)
{
	sectionRecordIds.add(chainRun.Id);
}
List<kern__ScheduledJob__c> recipeRecords = [SELECT Id FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c = 'Recipe On Runner'];
for(kern__ScheduledJob__c record : recipeRecords)
{
	sectionRecordIds.add(record.Id);
}
delete [SELECT Id FROM kern__LogEntry__c WHERE kern__RecordId__c IN :sectionRecordIds];
delete recipeRuns;
delete probes;
delete watchdogRecords;
delete recipeRecords;
System.debug('Section 81b (verify): ' + passed + '/3 passed, ' + failed + ' failed — cleanup complete');
