// Section 79d: Chain Watchdog, a stuck chain whose current step had started (verify and cleanup). Run AFTER section
// 79c's scheduled fire time.
//
// Expected: the watchdog proved the background job dead, found that the step to resume had started without a result
// and never said it is safe to run twice, and ended the chain Failed: an end time, and the error message holds the
// AsyncChain_RecoveryStoppedAtStartedStep text naming the step. The step log marks that step as the one recovery
// refused. While the one-off schedule has not fired yet, the script reports it, deletes nothing and is run again after
// the fire time.
Integer passed = 0;
Integer failed = 0;

final String PROBE_CHAIN_NAME = 'Watchdog Started Step Probe';
final String JOB_NAME = 'Section 79c Watchdog Started Step';
final String STARTED_STEP_NAME = 'Create Foobar';
final String STATUS_FAILED = 'Failed';
final String EXPECTED_REASON = String.format(System.Label.kern.AsyncChain_RecoveryStoppedAtStartedStep, new List<String> {STARTED_STEP_NAME});

List<kern__AsyncChainExecution__c> probes = [SELECT Id, kern__Status__c, kern__CompletedAt__c, kern__ErrorMessage__c, kern__StepLog__c
		FROM kern__AsyncChainExecution__c WHERE kern__ChainName__c = :PROBE_CHAIN_NAME];
List<CronTrigger> waitingSchedules = [SELECT Id, NextFireTime FROM CronTrigger WHERE CronJobDetail.Name = :JOB_NAME AND State = 'WAITING'];

if(!waitingSchedules.isEmpty())
{
	failed++;
	System.debug('79d FAIL: the one-off watchdog has not fired yet (next fire ' + waitingSchedules[0].NextFireTime
			+ '); nothing was deleted, run this script again after that time');
}
else
{
	// 79d: Failed, with the end time and the started-step text, and the step log marks the refused step.
	List<String> problems = new List<String>();
	if(probes.size() != 1)
	{
		problems.add('expected one probe, found ' + probes.size());
	}
	else
	{
		kern__AsyncChainExecution__c probe = probes[0];
		if(probe.kern__Status__c != STATUS_FAILED)
		{
			problems.add('status ' + probe.kern__Status__c + ', expected ' + STATUS_FAILED);
		}
		if(probe.kern__CompletedAt__c == null)
		{
			problems.add('no end time');
		}
		if(probe.kern__ErrorMessage__c == null || !probe.kern__ErrorMessage__c.contains(EXPECTED_REASON))
		{
			problems.add('error message does not hold the started-step text: ' + probe.kern__ErrorMessage__c);
		}
		List<Object> stepLog = String.isBlank(probe.kern__StepLog__c) ? new List<Object>() : (List<Object>)JSON.deserializeUntyped(probe.kern__StepLog__c);
		Map<String, Object> refusedStep = stepLog.size() == 2 ? (Map<String, Object>)stepLog[1] : null;
		if(refusedStep == null || refusedStep.get('recoveryRefused') != true || refusedStep.get('success') != false)
		{
			problems.add('the step log does not mark the second step as the one recovery refused: ' + probe.kern__StepLog__c);
		}
	}
	if(problems.isEmpty())
	{
		passed++;
		System.debug('79d PASS: the watchdog ended the chain Failed at the started step it would not run twice, with an end time and the label text');
	}
	else
	{
		failed++;
		System.debug('79d FAIL: ' + String.join(problems, '; '));
	}

	// Cleanup: abort the one-off schedule if it lingers, then delete the probe and its log entries.
	for(CronTrigger lingeringTrigger : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = :JOB_NAME])
	{
		System.abortJob(lingeringTrigger.Id);
	}
	if(!probes.isEmpty())
	{
		delete [SELECT Id FROM kern__LogEntry__c WHERE kern__RecordId__c = :probes[0].Id];
		delete probes;
	}
}
System.debug('Section 79d (watchdog started step verify): ' + passed + '/1 passed, ' + failed + ' failed');
