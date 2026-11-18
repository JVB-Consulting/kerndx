// Stuck Retry re-save probe: does the release note's backfill save send a call that is stuck at Retry?
//
// Run ws2-stuck-retry-resave-setup.apex first; it prints the two Ids this script takes.
//
// Tokens:
//   __STEP__        read:     print both calls, their API issues and every job created since __SINCE__. Changes nothing.
//                   backfill: run the backfill script from the Kern 1.12 release note (UTIL_BulkUpdates.copyField of
//                             Triggering Record Id into Triggering Record Index) with one more condition, Id equals the
//                             probe call, so the background job saves that one call and no other row in the org. Then reads.
//                   control:  save the control call with only Next Retry changed, to one minute from now. Status is not
//                             set, so it stays at Retry. The elastic limits probe (Task 1d) showed that such a save sends
//                             a stuck call at the new time, so this proves the retry flow is live on this org. Then reads.
//                   clean-up: delete both calls and their API issues, then empty them from the Recycle Bin. The
//                             object's trigger is turned off for this script only, because its delete guards refuse to
//                             delete a call that has ended. Then counts the rows left outside the Recycle Bin: both counts
//                             should be 0. The platform removes emptied rows from the Recycle Bin later, so a query
//                             with ALL ROWS can still show them as deleted for a while.
//   __PROBE_ID__    the probe call's Id.
//   __CONTROL_ID__  the control call's Id.
//   __SINCE__       the earliest job time to list, in GMT, as yyyy-MM-dd HH:mm:ss.
//
// A send is a job of UTIL_AdaptiveAsynchronousProcessor (the retry flow's action queues it) and a call that leaves
// Retry. The backfill itself also starts one job of that class: for one row it runs as a Queueable, and that job is
// not a send. So the call's status decides: a sent call leaves Retry (on this org the API_Echo handler cannot send an
// outbound request, so a sent call ends Aborted with no callout).
// Times are printed Eastern (America/New_York).
// Run: sf apex run -o YourDevOrgAlias -f <rendered copy with the tokens replaced> --json > <file>
final String STEP = '__STEP__';
final Id PROBE_ID = (Id)'__PROBE_ID__';
final Id CONTROL_ID = (Id)'__CONTROL_ID__';
final Datetime SINCE = Datetime.valueOfGmt('__SINCE__');
final String TIME_ZONE = 'America/New_York';
final String TIME_FORMAT = 'yyyy-MM-dd HH:mm:ss';
final Set<Id> CALL_IDS = new Set<Id>{ PROBE_ID, CONTROL_ID };

System.debug('WS2 PROBE step=' + STEP + ' time=' + System.now().format(TIME_FORMAT, TIME_ZONE));

if(STEP == 'backfill')
{
	QRY_Condition.Evaluable callsToFill = new QRY_Condition.AndCondition()
			.add(new QRY_Condition.FieldCondition('Id', QRY_Condition.Operator.EQUALS, PROBE_ID))
			.add(new QRY_Condition.FieldCondition('TriggeringRecordId__c', QRY_Condition.Operator.NOT_EQUALS, null))
			.add(new QRY_Condition.FieldCondition('TriggeringRecordIndex__c', QRY_Condition.Operator.EQUALS, null));
	UTIL_BulkUpdates.copyField('ApiCall__c', 'TriggeringRecordId__c', 'TriggeringRecordIndex__c', callsToFill, 200, false);
	System.debug('WS2 PROBE backfill started time=' + System.now().format(TIME_FORMAT, TIME_ZONE));
}
else if(STEP == 'control')
{
	Datetime nextRetry = System.now().addMinutes(1);
	update new ApiCall__c(Id = CONTROL_ID, NextRetry__c = nextRetry);
	System.debug('WS2 PROBE control saved time=' + System.now().format(TIME_FORMAT, TIME_ZONE) + ' nextRetry=' + nextRetry.format(TIME_FORMAT, TIME_ZONE));
}
else if(STEP == 'clean-up')
{
	TRG_Base.bypass(ApiCall__c.SObjectType);
	TRG_Base.bypass(ApiIssue__c.SObjectType);
	List<ApiIssue__c> issues = [SELECT Id FROM ApiIssue__c WHERE ApiCall__c IN :CALL_IDS];
	if(!issues.isEmpty())
	{
		delete issues;
		Database.emptyRecycleBin(issues);
	}
	List<ApiCall__c> calls = [SELECT Id FROM ApiCall__c WHERE Id IN :CALL_IDS];
	if(!calls.isEmpty())
	{
		delete calls;
		Database.emptyRecycleBin(calls);
	}
	TRG_Base.clearAllBypasses();
	System.debug('WS2 LEFT calls=' + [SELECT COUNT() FROM ApiCall__c WHERE Id IN :CALL_IDS] + ' issues='
			+ [SELECT COUNT() FROM ApiIssue__c WHERE ApiCall__c IN :CALL_IDS]);
}

if(STEP != 'clean-up')
{
	for(ApiCall__c row : [SELECT Id, Name, Status__c, NextRetry__c, Retries__c, TriggeringRecordIndex__c, LastModifiedDate, ErrorMessages__c FROM ApiCall__c
			WHERE Id IN :CALL_IDS ORDER BY Id])
	{
		String role = row.Id == PROBE_ID ? 'probe' : 'control';
		System.debug('WS2 CALL ' + role + ' id=' + row.Id + ' name=' + row.Name + ' status=' + row.Status__c + ' nextRetry='
				+ row.NextRetry__c?.format(TIME_FORMAT, TIME_ZONE) + ' retries=' + row.Retries__c + ' index=' + row.TriggeringRecordIndex__c
				+ ' lastModified=' + row.LastModifiedDate.format(TIME_FORMAT, TIME_ZONE) + ' errors=' + row.ErrorMessages__c?.abbreviate(300));
	}
	for(ApiIssue__c issue : [SELECT Id, Name, ApiCall__c, CreatedDate FROM ApiIssue__c WHERE ApiCall__c IN :CALL_IDS])
	{
		System.debug('WS2 ISSUE id=' + issue.Id + ' name=' + issue.Name + ' call=' + issue.ApiCall__c + ' created=' + issue.CreatedDate.format(TIME_FORMAT, TIME_ZONE));
	}
	for(AsyncApexJob job : [SELECT Id, ApexClass.Name, JobType, Status, CreatedDate, CompletedDate, ParentJobId, ExtendedStatus FROM AsyncApexJob
			WHERE CreatedDate >= :SINCE AND JobType IN ('Queueable', 'BatchApex', 'Future', 'ScheduledApex') ORDER BY CreatedDate])
	{
		System.debug('WS2 JOB id=' + job.Id + ' class=' + job.ApexClass?.Name + ' type=' + job.JobType + ' status=' + job.Status + ' created='
				+ job.CreatedDate.format(TIME_FORMAT, TIME_ZONE) + ' completed=' + job.CompletedDate?.format(TIME_FORMAT, TIME_ZONE)
				+ ' parent=' + job.ParentJobId + ' extended=' + job.ExtendedStatus);
	}
}
