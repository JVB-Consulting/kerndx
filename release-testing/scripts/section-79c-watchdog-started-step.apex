// Section 79c: Chain Watchdog, a stuck chain whose current step had started (launch).
//
// Section 79 proves the watchdog marks Stalled a stuck chain whose background job it cannot check. This section proves
// the other end of the 1.8 recovery: the watchdog can prove the chain's background job is dead, but the step the chain
// stopped at had already started and left no result, and that step never said it is safe to run twice. Running it
// again could repeat its work, so the watchdog ends the chain Failed instead, with the AsyncChain_RecoveryStoppedAtStartedStep
// text naming the step, and an end time.
//
// The probe row meets each rule the watchdog checks, in order:
//   - Status Running, LastModifiedDate 45 minutes old (older than the 30-minute threshold), no end time: a candidate.
//   - kern__CurrentJobId__c holds a well-formed background job id that matches no job in the org. The watchdog treats a job it
//     cannot find as dead, so it goes on to recovery instead of only marking the chain Stalled.
//   - The step log has two steps. The first has a result (success), so the log carries the step markers. The second has
//     started (started true) and has no result, and it has no isIdempotent marker, so the step is not safe to run twice.
//     That step is where recovery would resume, and it is refused.
// The second step's class, SubscriberChainSteps.CreateFoobarStep, saves a record and does not declare itself idempotent.
// The watchdog decides from the step log alone and never runs the step.
//
// Prerequisites:
//   - The 1.8 managed package (the watchdog's started-step refusal ships in 1.8).
//   - Audit-field back-dating enabled (RUNBOOK Phase 1.4), as for section 79.
//   - No other run of this section is waiting: the seed deletes an earlier probe of the same name first.
//
// Run section-79d-watchdog-started-step-verify.apex AFTER the scheduled fire time this script prints (the one-off
// schedule fires on the next minute boundary, about 90 seconds out).
Integer passed = 0;
Integer failed = 0;

final String PROBE_CHAIN_NAME = 'Watchdog Started Step Probe';
final String JOB_NAME = 'Section 79c Watchdog Started Step';
final String FIRST_STEP_CLASS = 'SubscriberChainSteps.VerifyContextStep';
final String STARTED_STEP_CLASS = 'SubscriberChainSteps.CreateFoobarStep';
final String STARTED_STEP_NAME = 'Create Foobar';
// A background job id (prefix 707) with a valid checksum that no job in the org carries.
final String DEAD_JOB_ID = '707000000000000AAA';

// 79c-seed: a Running chain whose current step started 45 minutes ago and never wrote a result.
delete [SELECT Id FROM kern__AsyncChainExecution__c WHERE kern__ChainName__c = :PROBE_CHAIN_NAME];
kern__AsyncChainExecution__c probe = new kern__AsyncChainExecution__c(
		kern__ChainName__c = PROBE_CHAIN_NAME,
		kern__Status__c = 'Running',
		kern__CorrelationId__c = EncodingUtil.convertToHex(Crypto.generateAesKey(128)),
		kern__CurrentStepName__c = STARTED_STEP_NAME,
		kern__CurrentJobId__c = DEAD_JOB_ID,
		kern__TotalSteps__c = 2,
		kern__CompletedSteps__c = 1,
		kern__StartedAt__c = System.now().addMinutes(-46),
		CreatedDate = System.now().addMinutes(-46),
		kern__StepLog__c = JSON.serialize(new List<Map<String, Object>>{
				new Map<String, Object>{'className' => FIRST_STEP_CLASS, 'stepName' => 'Verify Context', 'started' => true, 'success' => true, 'durationMs' => 211},
				new Map<String, Object>{'className' => STARTED_STEP_CLASS, 'stepName' => STARTED_STEP_NAME, 'started' => true}
		}),
		LastModifiedDate = System.now().addMinutes(-45)
);
insert probe;
kern__AsyncChainExecution__c inserted = [SELECT LastModifiedDate, kern__CurrentJobId__c FROM kern__AsyncChainExecution__c WHERE Id = :probe.Id];
if(inserted.LastModifiedDate < System.now().addMinutes(-40) && inserted.kern__CurrentJobId__c == DEAD_JOB_ID)
{
	passed++;
	System.debug('79c-seed PASS: probe inserted with back-dated LastModifiedDate ' + inserted.LastModifiedDate + ' and a job id that matches no job');
}
else
{
	failed++;
	System.debug('79c-seed FAIL: LastModifiedDate ' + inserted.LastModifiedDate + ', job id ' + inserted.kern__CurrentJobId__c
			+ '; check the audit-fields deploy (RUNBOOK Phase 1.4): the watchdog cannot see this probe as stuck');
}

// 79c-schedule: the real watchdog through the platform scheduler, a one-off schedule on the next minute boundary. A
// schedule left by an earlier run would block the name, so it is removed first.
for(CronTrigger lingeringTrigger : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = :JOB_NAME])
{
	System.abortJob(lingeringTrigger.Id);
}
kern.SCHED_ChainWatchdog job = new kern.SCHED_ChainWatchdog();
kern.DTO_NameValues attributes = new kern.DTO_NameValues();
attributes.add('StaleThresholdMinutes', '30');
attributes.add('BatchSize', '50');
job.setParameterValues(attributes);
Datetime fireAt = System.now().addSeconds(75);
String cron = '0 ' + fireAt.minute() + ' ' + fireAt.hour() + ' ' + fireAt.day() + ' ' + fireAt.month() + ' ? ' + fireAt.year();
Id cronId = System.schedule(JOB_NAME, cron, job);
if(cronId != null)
{
	passed++;
	System.debug('79c-schedule PASS: watchdog scheduled through the platform scheduler, fires at ' + fireAt + ' (cron ' + cron + ')');
}
else
{
	failed++;
	System.debug('79c-schedule FAIL: System.schedule returned no job id');
}

System.debug('Section 79c (watchdog started step launch): ' + passed + '/2 passed, ' + failed + ' failed; run section-79d after ' + fireAt);
