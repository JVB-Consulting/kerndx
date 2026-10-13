// Consoles at volume: back-dated Stalled rows whose current step had started, for the watchdog to end at volume.
// Each row meets every rule the watchdog checks before it ends a run Failed at a started step (the same row as
// section 79c, many times over):
//   - Stalled, no end time, no duration, and a last change older than the run's stale threshold: a candidate.
//   - CurrentJobId__c holds a well-formed background job id that matches no job in the org. The watchdog treats a
//     job it cannot find as dead, so it goes on to recovery instead of only marking the row Stalled again.
//   - The step log has two steps. The first has a result (success), so the log carries the step markers. The second
//     has started and has no result, and it has no isIdempotent marker, so it is not safe to run twice. That step is
//     where recovery would resume, so the watchdog refuses to run it again and ends the run Failed with the
//     AsyncChain_RecoveryStoppedAtStartedStep text and an end time. It decides from the step log alone and never runs
//     the step.
// The manifest marks the rows synthesized; what the watchdog does to them is the evidence. Needs audit-field
// back-dating (RUNBOOK Phase 1.4). The driver sends the rows in slices; __FIRST_ORDINAL__ keeps their ids apart.
// Tokens: __APEX_NAMESPACE__ __FIELD_NAMESPACE__ __COUNT__ __FIRST_ORDINAL__ __RUN_TOKEN__ __ACTION_ID__
__APEX_NAMESPACE__LOG_Builder.setCorrelationId('__ACTION_ID__');
String actionId = '__ACTION_ID__';
// A background job id (prefix 707) with a valid checksum that no job in the org carries, as in section 79c.
String deadJobId = '707000000000000AAA';
// The second segment of the rows' ids: the ten screen-fixture rows use 0, these rows use 1, so the two never collide.
Integer startedStepSegment = 1;
List<__FIELD_NAMESPACE__AsyncChainExecution__c> rows = new List<__FIELD_NAMESPACE__AsyncChainExecution__c>();
Datetime now = Datetime.now();
for(Integer ordinal = __FIRST_ORDINAL__; ordinal < __FIRST_ORDINAL__ + __COUNT__; ordinal++)
{
	Integer silentMinutes = 20 + ordinal;
	List<Map<String, Object>> stepLog = new List<Map<String, Object>>
	{
			new Map<String, Object>
			{
					'className' => 'SubscriberChainSteps.VerifyContextStep', 'stepName' => 'Verify Context', 'started' => true, 'success' => true, 'durationMs' => 211
			},
			new Map<String, Object> {'className' => 'SubscriberChainSteps.CreateFoobarStep', 'stepName' => 'Create Foobar', 'started' => true}
	};
	__FIELD_NAMESPACE__AsyncChainExecution__c row = new __FIELD_NAMESPACE__AsyncChainExecution__c();
	row.put('__FIELD_NAMESPACE__ChainName__c', 'Volume_StartedStepStall');
	row.put('__FIELD_NAMESPACE__Status__c', 'Stalled');
	row.put('__FIELD_NAMESPACE__FailureCategory__c', 'Stalled');
	row.put('__FIELD_NAMESPACE__CorrelationId__c', SubscriberChainSteps.volumeRunId('__RUN_TOKEN__', SubscriberChainSteps.KIND_STALLED_ROW, 0, startedStepSegment, ordinal));
	row.put('__FIELD_NAMESPACE__RootCorrelationId__c', actionId);
	row.put('__FIELD_NAMESPACE__LaunchCorrelationId__c', actionId);
	row.put('__FIELD_NAMESPACE__CurrentStepName__c', 'Create Foobar');
	row.put('__FIELD_NAMESPACE__CurrentJobId__c', deadJobId);
	row.put('__FIELD_NAMESPACE__TotalSteps__c', 2);
	row.put('__FIELD_NAMESPACE__CompletedSteps__c', 1);
	row.put('__FIELD_NAMESPACE__StartedAt__c', now.addMinutes(-(silentMinutes + 1)));
	row.put('__FIELD_NAMESPACE__StepLog__c', JSON.serialize(stepLog));
	row.put('CreatedDate', now.addMinutes(-(silentMinutes + 1)));
	row.put('LastModifiedDate', now.addMinutes(-silentMinutes));
	rows.add(row);
}
insert rows;
List<String> executionIds = new List<String>();
for(__FIELD_NAMESPACE__AsyncChainExecution__c row : rows)
{
	executionIds.add(row.Id);
}
System.debug('VOLUME_LAUNCH stage=stalledStarted action=' + actionId + ' ordinal=__FIRST_ORDINAL__ ids=' + String.join(executionIds, ',') + ' launched='
		+ executionIds.size() + ' dml=' + Limits.getDmlStatements() + '/' + Limits.getLimitDmlStatements() + ' enqueued=0/0');
