// Watchdog automation probe: 50 stuck chain runs for one pass of the chain watchdog, in an org with the Kern package installed.
// Each row meets every rule the watchdog checks before it recovers a run:
//   - Stalled, no end time, no duration. The watchdog is scheduled with a stale threshold of 0 minutes, so a row saved
//     a few seconds before the pass is already old enough.
//   - When the org has the stall time field (StalledAt__c, from Kern 1.12), it is set: a Stalled run carries the time
//     it stalled. On 1.11 the field does not exist and is left out.
//   - CurrentJobId__c holds a well-formed background job id that matches no job in the org. The watchdog treats a job
//     it cannot find as dead, so it goes on to recovery.
//   - The step log has two steps. The first has a result (success). The second has started and has no result.
// The __PATH__ token chooses what the watchdog does with the second step:
//   - failed: the second step has no isIdempotent marker, so it is not safe to run twice. The watchdog ends the run
//     Failed with the "Recovery stopped at step ..." reason. One save per run.
//   - restart: the second step is marked 'isIdempotent' => true, so it is safe to run again. The watchdog restarts the
//     run: a new RunKey__c, a new CurrentJobId__c and a queued ChainExecutor. Two saves per run.
// The step classes do not exist in this org; the watchdog decides from the step log alone and never runs the step.
// Every row carries the root correlation id below, so probe.js can find and delete the probe's rows and no others.
// Prints each row's Id, RunKey__c and CurrentJobId__c as seeded.
// Tokens (filled by probe.js):
//   __PATH__            failed or restart
//   __NAMESPACE__       the package's field prefix, for example kern__ (empty on an org without a namespace)
//   __APEX_NAMESPACE__  the package's class prefix, for example kern. (empty on an org without a namespace)
String path = '__PATH__';
if(path != 'failed' && path != 'restart')
{
	throw new IllegalArgumentException('The path must be failed or restart, not ' + path);
}
String actionId = 'WatchdogAutomationProbe';
__APEX_NAMESPACE__LOG_Builder.setCorrelationId(actionId);
// A new, well-formed background job id (prefix 707) that no job in the org carries.
String deadJobId = __APEX_NAMESPACE__UTIL_Random.randomId(AsyncApexJob.SObjectType);
Integer rowCount = 50;
String stalledAtField = '__NAMESPACE__StalledAt__c';
Boolean hasStalledAtField = false;
for(String fieldName : __NAMESPACE__AsyncChainExecution__c.SObjectType.getDescribe().fields.getMap().keySet())
{
	hasStalledAtField = hasStalledAtField || fieldName.equalsIgnoreCase(stalledAtField);
}
List<__NAMESPACE__AsyncChainExecution__c> rows = new List<__NAMESPACE__AsyncChainExecution__c>();
Datetime now = Datetime.now();
for(Integer ordinal = 0; ordinal < rowCount; ordinal++)
{
	Integer silentMinutes = 20 + ordinal;
	Map<String, Object> startedStep = new Map<String, Object> {'className' => 'SubscriberChainSteps.CreateFoobarStep', 'stepName' => 'Create Foobar', 'started' => true};
	if(path == 'restart')
	{
		startedStep.put('isIdempotent', true);
	}
	List<Map<String, Object>> stepLog = new List<Map<String, Object>>
	{
			new Map<String, Object>
			{
					'className' => 'SubscriberChainSteps.VerifyContextStep', 'stepName' => 'Verify Context', 'started' => true, 'success' => true, 'durationMs' => 211
			},
			startedStep
	};
	__NAMESPACE__AsyncChainExecution__c row = new __NAMESPACE__AsyncChainExecution__c();
	row.put('__NAMESPACE__ChainName__c', 'Volume_StartedStepStall');
	row.put('__NAMESPACE__Status__c', 'Stalled');
	row.put('__NAMESPACE__FailureCategory__c', 'Stalled');
	row.put('__NAMESPACE__CorrelationId__c', UUID.randomUUID().toString());
	row.put('__NAMESPACE__RootCorrelationId__c', actionId);
	row.put('__NAMESPACE__LaunchCorrelationId__c', actionId);
	row.put('__NAMESPACE__CurrentStepName__c', 'Create Foobar');
	row.put('__NAMESPACE__CurrentJobId__c', deadJobId);
	row.put('__NAMESPACE__TotalSteps__c', 2);
	row.put('__NAMESPACE__CompletedSteps__c', 1);
	row.put('__NAMESPACE__StartedAt__c', now.addMinutes(-(silentMinutes + 1)));
	row.put('__NAMESPACE__StepLog__c', JSON.serialize(stepLog));
	if(hasStalledAtField)
	{
		row.put(stalledAtField, now.addMinutes(-silentMinutes));
	}
	rows.add(row);
}
insert rows;
for(__NAMESPACE__AsyncChainExecution__c seeded : [
		SELECT Id, __NAMESPACE__RunKey__c, __NAMESPACE__CurrentJobId__c
		FROM __NAMESPACE__AsyncChainExecution__c
		WHERE Id IN :rows
		ORDER BY Id
])
{
	System.debug('PROBE_SEED id=' + seeded.Id + ' runKey=' + seeded.__NAMESPACE__RunKey__c + ' jobId=' + seeded.__NAMESPACE__CurrentJobId__c);
}
System.debug('PROBE_SEED path=' + path + ' seeded=' + rows.size() + ' stalledAtField=' + hasStalledAtField);
