// Section 81 — The watchdog and the recipe on the job runner (seed): both framework jobs run from the job
// runner instead of owning a scheduled job of their own, so neither costs a slot.
//
// Prerequisites:
//   - kern__JobRunnerManagement assigned to the runbook user (Phase 1.4): a record may only enter job-runner
//     mode as a user who holds Manage Job Runner, and the check itself refuses without it.
//   - Audit-field back-dating (RUNBOOK Phase 1.4), as section 79 needs it: the probe chain is inserted with a
//     back-dated LastModifiedDate so it satisfies the shipped stale predicate without a 30-minute wait.
//   - The subscriber class Recipe_ScheduledChain_DEMO deployed (Phase 1.4).
//
// Run section-81b-watchdog-and-recipe-on-runner-verify.apex AFTER the fire time this script debugs.
Integer passed = 0;
Integer failed = 0;

// 81-seed-1: a Running chain whose last activity is 45 minutes old — the shape a chain takes when the platform
// silently drops its queueable mid-run (the section 79 probe, under its own chain name).
delete [SELECT Id FROM kern__AsyncChainExecution__c WHERE kern__ChainName__c = 'Watchdog On Runner Probe'];
kern__AsyncChainExecution__c probe = new kern__AsyncChainExecution__c(
		kern__ChainName__c = 'Watchdog On Runner Probe',
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
kern__AsyncChainExecution__c insertedProbe = [SELECT LastModifiedDate FROM kern__AsyncChainExecution__c WHERE Id = :probe.Id];
if(insertedProbe.LastModifiedDate < System.now().addMinutes(-40))
{
	passed++;
	System.debug('81-seed PASS: probe chain inserted with back-dated LastModifiedDate ' + insertedProbe.LastModifiedDate);
}
else
{
	failed++;
	System.debug('81-seed FAIL: LastModifiedDate was not back-dated (' + insertedProbe.LastModifiedDate + ') — check the audit-fields two-step deploy + KernE2EAuditFieldAccess (RUNBOOK Phase 1.4)');
}

// 81-seed-2 and 81-seed-3: the watchdog and the recipe, both set to run on the job runner, both due.
delete [SELECT Id FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c IN ('Watchdog On Runner', 'Recipe On Runner')];
// The recipe's chain name: cleared so 81b-3 can only see the run this section starts.
delete [SELECT Id FROM kern__AsyncChainExecution__c WHERE kern__ChainName__c = 'Nightly Order Export'];
List<kern__ScheduledJob__c> onRunner = new List<kern__ScheduledJob__c>{
		new kern__ScheduledJob__c(
				kern__SchedulerName__c = 'Watchdog On Runner',
				kern__ClassName__c = 'kern.SCHED_ChainWatchdog',
				kern__CronExpression__c = '0 */5 * * * ?',
				kern__IsActive__c = true,
				kern__Timezone__c = 'UTC',
				kern__ExecutionMode__c = 'JobRunner',
				kern__Parameters__c = '{"nameValueMap":{"StaleThresholdMinutes":"30","BatchSize":"50"}}'
		),
		new kern__ScheduledJob__c(
				kern__SchedulerName__c = 'Recipe On Runner',
				kern__ClassName__c = 'Recipe_ScheduledChain_DEMO',
				kern__CronExpression__c = '0 */5 * * * ?',
				kern__IsActive__c = true,
				kern__Timezone__c = 'UTC',
				kern__ExecutionMode__c = 'JobRunner',
				kern__Parameters__c = '{"nameValueMap":{"batchLimit":"5"}}'
		)
};
insert onRunner;
Datetime dueAt = System.now().addMinutes(-10);
for(kern__ScheduledJob__c record : onRunner)
{
	record.kern__NextRunAt__c = dueAt;
}
update onRunner;
for(kern__ScheduledJob__c record : [SELECT kern__SchedulerName__c, kern__NextRunAt__c, kern__ScheduledJobId__c FROM kern__ScheduledJob__c WHERE Id IN :onRunner ORDER BY kern__SchedulerName__c])
{
	if(record.kern__NextRunAt__c < System.now() && record.kern__ScheduledJobId__c == null)
	{
		passed++;
		System.debug('81-seed PASS: ' + record.kern__SchedulerName__c + ' is due on the runner and owns no scheduled job of its own');
	}
	else
	{
		failed++;
		System.debug('81-seed FAIL: ' + record.kern__SchedulerName__c + ' cursor ' + record.kern__NextRunAt__c + ' slot ' + record.kern__ScheduledJobId__c);
	}
}

// 81a: one job runner check through the real platform scheduler, on the next minute boundary.
Datetime fireAt = System.now().addSeconds(75);
String cron = '0 ' + fireAt.minute() + ' ' + fireAt.hour() + ' ' + fireAt.day() + ' ' + fireAt.month() + ' ? ' + fireAt.year();
Id cronId = System.schedule('Section 81 Job Runner Check', cron, new kern.SCHED_JobRunner());
if(cronId != null)
{
	passed++;
	System.debug('81-seed PASS: one job runner check scheduled, fires at ' + fireAt + ' (cron ' + cron + ')');
}
else
{
	failed++;
	System.debug('81-seed FAIL: System.schedule returned no job id');
}

System.debug('Section 81 (seed): ' + passed + '/4 passed, ' + failed + ' failed — run section-81b after ' + fireAt);
