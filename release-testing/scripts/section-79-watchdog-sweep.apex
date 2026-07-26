// Section 79 — Chain Watchdog sweep (launch): the scheduled watchdog detects a silently-stuck chain.
//
// Prerequisites:
//   - The 1.6.0+ managed package (SCHED_ChainWatchdog ships in 1.6.0).
//   - Audit-field back-dating enabled (the two-step audit-fields deploy + KernE2EAuditFieldAccess,
//     RUNBOOK Phase 1.4): the probe chain is inserted with a back-dated LastModifiedDate so it
//     satisfies the shipped stale predicate (Status Running/Stalled, LastModifiedDate older than
//     StaleThresholdMinutes, CompletedAt null) without waiting 30 real minutes.
//
// Run section-79b-watchdog-sweep-verify.apex AFTER the scheduled fire time this script debugs
// (the one-off CronTrigger fires on the next minute boundary, ~90 seconds out).
Integer passed = 0;
Integer failed = 0;

// 79-seed: a Running chain whose last activity is 45 minutes old — the shape a chain takes when the
// platform silently drops its queueable mid-run.
delete [SELECT Id FROM kern__AsyncChainExecution__c WHERE kern__ChainName__c = 'Watchdog Sweep Probe'];
kern__AsyncChainExecution__c probe = new kern__AsyncChainExecution__c(
		kern__ChainName__c = 'Watchdog Sweep Probe',
		kern__Status__c = 'Running',
		kern__CorrelationId__c = EncodingUtil.convertToHex(Crypto.generateAesKey(128)),
		kern__CurrentStepName__c = 'Publish Audit Event',
		kern__TotalSteps__c = 4,
		kern__CompletedSteps__c = 3,
		kern__StartedAt__c = System.now().addMinutes(-46),
		CreatedDate = System.now().addMinutes(-46),
		kern__StepLog__c = JSON.serialize(new List<Map<String, Object>>{
				new Map<String, Object>{'className' => 'AccountSyncValidate', 'stepName' => 'Validate Payload', 'success' => true, 'durationMs' => 312},
				new Map<String, Object>{'className' => 'AccountSyncEnrich', 'stepName' => 'Enrich From CRM', 'success' => true, 'durationMs' => 1187},
				new Map<String, Object>{'className' => 'AccountSyncUpsert', 'stepName' => 'Upsert Accounts', 'success' => true, 'durationMs' => 904},
				new Map<String, Object>{'className' => 'AccountSyncAudit', 'stepName' => 'Publish Audit Event'}
		}),
		LastModifiedDate = System.now().addMinutes(-45)
);
insert probe;
kern__AsyncChainExecution__c inserted = [SELECT LastModifiedDate FROM kern__AsyncChainExecution__c WHERE Id = :probe.Id];
if(inserted.LastModifiedDate < System.now().addMinutes(-40))
{
	passed++;
	System.debug('79-seed PASS: probe inserted with back-dated LastModifiedDate ' + inserted.LastModifiedDate);
}
else
{
	failed++;
	System.debug('79-seed FAIL: LastModifiedDate was not back-dated (' + inserted.LastModifiedDate + ') — check the audit-fields two-step deploy + KernE2EAuditFieldAccess (RUNBOOK Phase 1.4); the sweep cannot see this probe as stale');
}

// 79a: schedule the REAL watchdog through the platform scheduler — a one-off CronTrigger on the next
// minute boundary, carrying the recommended parameters through the shipped typed-parameter surface.
kern.SCHED_ChainWatchdog job = new kern.SCHED_ChainWatchdog();
kern.DTO_NameValues attributes = new kern.DTO_NameValues();
attributes.add('StaleThresholdMinutes', '30');
attributes.add('BatchSize', '50');
job.setParameterValues(attributes);
Datetime fireAt = System.now().addSeconds(75);
String cron = '0 ' + fireAt.minute() + ' ' + fireAt.hour() + ' ' + fireAt.day() + ' ' + fireAt.month() + ' ? ' + fireAt.year();
Id cronId = System.schedule('Section 79 Watchdog Sweep', cron, job);
if(cronId != null)
{
	passed++;
	System.debug('79a PASS: watchdog scheduled via the platform scheduler, fires at ' + fireAt + ' (cron ' + cron + ')');
}
else
{
	failed++;
	System.debug('79a FAIL: System.schedule returned no job id');
}

System.debug('Section 79 (watchdog sweep launch): ' + passed + '/2 passed, ' + failed + ' failed — run section-79b after ' + fireAt);
