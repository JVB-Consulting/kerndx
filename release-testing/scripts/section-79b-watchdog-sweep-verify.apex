// Section 79b — Chain Watchdog sweep (verify + cleanup): run AFTER section 79's scheduled fire time.
Integer passed = 0;
Integer failed = 0;

List<kern__AsyncChainExecution__c> probes = [SELECT Id, kern__Status__c, kern__CompletedAt__c FROM kern__AsyncChainExecution__c WHERE kern__ChainName__c = 'Watchdog Sweep Probe'];
if(probes.size() == 1 && probes[0].kern__Status__c == 'Stalled')
{
	passed++;
	System.debug('79b PASS: the scheduled sweep marked the silently-stuck Running chain Stalled');
}
else
{
	failed++;
	System.debug('79b FAIL: probe status = ' + (probes.isEmpty() ? 'MISSING' : probes[0].kern__Status__c) + ' — did the CronTrigger fire yet? Re-run 79b after the fire time before treating this as a product failure');
}

// Observational (not counted): the stall notification trail. The probe carries no persisted onError
// handler, and LogEntry persistence is platform-event-driven (async), so this reports rather than
// gates. A zero here with 79b green is NOT a failure.
if(!probes.isEmpty())
{
	Integer stallLogCount = [SELECT COUNT() FROM kern__LogEntry__c WHERE kern__RecordId__c = :probes[0].Id];
	System.debug('79b observation: ' + stallLogCount + ' log entry(ies) recorded against the stalled probe');
}

// Cleanup: abort the one-off CronTrigger if it lingers, delete the probe and any of its log entries —
// the org returns to the watchdog-unscheduled, no-probe baseline.
for(CronTrigger trigger_x : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Section 79 Watchdog Sweep'])
{
	System.abortJob(trigger_x.Id);
}
if(!probes.isEmpty())
{
	delete [SELECT Id FROM kern__LogEntry__c WHERE kern__RecordId__c = :probes[0].Id];
	delete probes;
}
System.debug('Section 79b (watchdog sweep verify): ' + passed + '/1 passed, ' + failed + ' failed — cleanup complete');
