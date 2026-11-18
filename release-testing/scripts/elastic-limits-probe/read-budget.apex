// Elastic limits probe: read the org's daily background-job allowance and everything the probe may have left running.
//
// Prints, one PROBE line each:
//   - the time (Eastern), DailyAsyncApexExecutions used, maximum and remaining;
//   - every org limit (OrgLimits.getMap()) whose name contains "Async", with its used and maximum values. Elastic limits
//     may report their ceiling under another name than DailyAsyncApexExecutions, so read all of them;
//   - every schedule (CronTrigger) not deleted, with its job name and state; probe schedules are named "Elastic Probe ...";
//   - every probe outbound call (handler API_RetryLiveGet) with its status, NextRetry__c, retries and the first 1000
//     characters of its error text, flagged when it is at Queued, Retry or Retrying, and every probe API issue with
//     whether it is marked External System May Have Acted and the start of its error text;
//   - today's log entries (newest 20) filed under FLOW_CallApiAsync, under SCHED_OutboundRetryWatchdog, or at a
//     processor's enqueueNextHop (a next background job Salesforce refused to start), with the start of each message;
//     an enqueueNextHop entry also prints the start of its context, which names the items the job did not process;
//   - the paused or failed interviews of the RetryOutboundApiCall and InvokeOutboundApiCall flows (FlowInterview), or a
//     line saying anonymous Apex cannot read FlowInterview;
//   - every probe chain run (CorrelationId__c starting elasticprobe) with its status and error;
//   - every probe runner row (kern__ScheduledJob__c named Elastic Probe Runner Job);
//   - the number of background jobs at Queued, Holding, Preparing or Processing, by class;
//   - the last 20 AsyncApexJob rows.
// It changes nothing and queues nothing, so it spends none of the allowance.
//
// Run: sf apex run -o YourSubscriberOrgAlias -f read-budget.apex --json > <file>
final String TIME_ZONE = 'America/New_York';
final String TIME_FORMAT = 'yyyy-MM-dd HH:mm:ss';
final String PROBE_SERVICE = 'API_RetryLiveGet';
final String PROBE_CHAIN_MARKER = 'elasticprobe%';
final String PROBE_SCHEDULE_PATTERN = 'Elastic Probe%';
final String PROBE_RUNNER_JOB = 'Elastic Probe Runner Job';
final Set<String> PENDING_CALL_STATUSES = new Set<String> {'Queued', 'Retry', 'Retrying'};
final List<String> LIVE_JOB_STATUSES = new List<String> {'Queued', 'Holding', 'Preparing', 'Processing'};
final List<String> PROBE_LOG_LOCATIONS = new List<String> {'%FLOW_CallApiAsync/%', '%SCHED_OutboundRetryWatchdog/%', '%/enqueueNextHop'};
final Integer MESSAGE_LENGTH = 1000;

System.OrgLimit daily = OrgLimits.getMap().get('DailyAsyncApexExecutions');
Datetime readAt = System.now();
System.debug('PROBE BUDGET time=' + readAt.format(TIME_FORMAT, TIME_ZONE) + ' used=' + daily.getValue() + ' maximum=' + daily.getLimit()
		+ ' remaining=' + (daily.getLimit() - daily.getValue()));
Map<String, System.OrgLimit> allLimits = OrgLimits.getMap();
List<String> limitNames = new List<String>(allLimits.keySet());
limitNames.sort();
Integer asyncLimitCount = 0;
for(String limitName : limitNames)
{
	if(limitName.containsIgnoreCase('Async'))
	{
		asyncLimitCount++;
		System.OrgLimit asyncLimit = allLimits.get(limitName);
		System.debug('PROBE ASYNC LIMIT name=' + limitName + ' used=' + asyncLimit.getValue() + ' maximum=' + asyncLimit.getLimit());
	}
}
System.debug('PROBE ASYNC LIMITS names=' + asyncLimitCount + ' of ' + limitNames.size());

Integer probeSchedules = 0;
for(CronTrigger cronRow : [SELECT Id, CronJobDetail.Name, CronJobDetail.JobType, State, NextFireTime, PreviousFireTime, TimesTriggered
		FROM CronTrigger WHERE State != 'DELETED' ORDER BY CreatedDate])
{
	Boolean isProbe = cronRow.CronJobDetail.Name != null && cronRow.CronJobDetail.Name.startsWith('Elastic Probe');
	if(isProbe)
	{
		probeSchedules++;
	}
	System.debug('PROBE SCHEDULE ' + (isProbe ? 'probe' : 'other') + ' id=' + cronRow.Id + ' name=' + cronRow.CronJobDetail.Name
			+ ' type=' + cronRow.CronJobDetail.JobType + ' state=' + cronRow.State + ' next=' + cronRow.NextFireTime?.format(TIME_FORMAT, TIME_ZONE)
			+ ' previous=' + cronRow.PreviousFireTime?.format(TIME_FORMAT, TIME_ZONE) + ' fired=' + cronRow.TimesTriggered);
}

Integer pendingCalls = 0;
for(kern__ApiCall__c call : [SELECT Id, kern__Status__c, kern__NextRetry__c, kern__Retries__c, kern__Direction__c, kern__ErrorMessages__c, CreatedDate,
		LastModifiedDate FROM kern__ApiCall__c WHERE kern__ServiceName__c = :PROBE_SERVICE ORDER BY CreatedDate])
{
	Boolean isPending = PENDING_CALL_STATUSES.contains(call.kern__Status__c);
	if(isPending)
	{
		pendingCalls++;
	}
	System.debug('PROBE CALL ' + (isPending ? 'pending' : 'settled') + ' id=' + call.Id + ' status=' + call.kern__Status__c
			+ ' nextRetry=' + call.kern__NextRetry__c?.format(TIME_FORMAT, TIME_ZONE) + ' retries=' + call.kern__Retries__c
			+ ' created=' + call.CreatedDate.format(TIME_FORMAT, TIME_ZONE) + ' modified=' + call.LastModifiedDate.format(TIME_FORMAT, TIME_ZONE)
			+ ' errors=' + call.kern__ErrorMessages__c?.abbreviate(MESSAGE_LENGTH));
}
for(kern__ApiIssue__c issue : [SELECT Id, Name, kern__Status__c, kern__ApiCall__c, kern__ExternalSystemMayHaveActed__c, kern__ErrorMessages__c, CreatedDate
		FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :PROBE_SERVICE ORDER BY CreatedDate])
{
	System.debug('PROBE ISSUE id=' + issue.Id + ' name=' + issue.Name + ' status=' + issue.kern__Status__c + ' call=' + issue.kern__ApiCall__c
			+ ' created=' + issue.CreatedDate.format(TIME_FORMAT, TIME_ZONE) + ' mayHaveActed=' + issue.kern__ExternalSystemMayHaveActed__c
			+ ' errors=' + issue.kern__ErrorMessages__c?.abbreviate(MESSAGE_LENGTH));
}
for(kern__LogEntry__c entry : [SELECT Id, kern__LogLevel__c, kern__ClassMethod__c, kern__RecordId__c, kern__Message__c, kern__ContextData__c, CreatedDate
		FROM kern__LogEntry__c WHERE CreatedDate = TODAY AND kern__ClassMethod__c LIKE :PROBE_LOG_LOCATIONS ORDER BY CreatedDate DESC LIMIT 20])
{
	Boolean isNextHop = entry.kern__ClassMethod__c.endsWith('/enqueueNextHop');
	System.debug('PROBE LOG level=' + entry.kern__LogLevel__c + ' at=' + entry.kern__ClassMethod__c + ' record=' + entry.kern__RecordId__c
			+ ' created=' + entry.CreatedDate.format(TIME_FORMAT, TIME_ZONE) + ' message=' + entry.kern__Message__c?.abbreviate(MESSAGE_LENGTH)
			+ (isNextHop ? ' context=' + entry.kern__ContextData__c?.abbreviate(MESSAGE_LENGTH) : ''));
}

Integer pausedInterviews = 0;
try
{
	List<SObject> interviews = Database.query('SELECT Id, InterviewLabel, InterviewStatus, CurrentElement, CreatedDate FROM FlowInterview ORDER BY CreatedDate');
	for(SObject interview : interviews)
	{
		String label = (String)interview.get('InterviewLabel');
		Boolean isProbeFlow = label != null && (label.contains('Retry') || label.contains('Invoke') || label.contains('Outbound'));
		if(isProbeFlow)
		{
			pausedInterviews++;
		}
		System.debug('PROBE INTERVIEW ' + (isProbeFlow ? 'outbound-flow' : 'other') + ' id=' + interview.Id + ' label=' + label
				+ ' status=' + interview.get('InterviewStatus') + ' element=' + interview.get('CurrentElement')
				+ ' created=' + ((Datetime)interview.get('CreatedDate')).format(TIME_FORMAT, TIME_ZONE));
	}
	System.debug('PROBE INTERVIEWS readable=true rows=' + interviews.size());
}
catch(Exception interviewError)
{
	System.debug('PROBE INTERVIEWS readable=false ' + interviewError.getTypeName() + ': ' + interviewError.getMessage());
}

Integer runningChains = 0;
for(kern__AsyncChainExecution__c run : [SELECT Id, kern__ChainName__c, kern__Status__c, kern__CurrentJobId__c, kern__CompletedSteps__c, kern__TotalSteps__c,
		kern__ErrorMessage__c, kern__StartedAt__c, kern__CompletedAt__c, LastModifiedDate
		FROM kern__AsyncChainExecution__c WHERE kern__CorrelationId__c LIKE :PROBE_CHAIN_MARKER ORDER BY CreatedDate])
{
	if(run.kern__Status__c == 'Running')
	{
		runningChains++;
	}
	System.debug('PROBE CHAIN id=' + run.Id + ' name=' + run.kern__ChainName__c + ' status=' + run.kern__Status__c + ' job=' + run.kern__CurrentJobId__c
			+ ' steps=' + run.kern__CompletedSteps__c + '/' + run.kern__TotalSteps__c + ' started=' + run.kern__StartedAt__c?.format(TIME_FORMAT, TIME_ZONE)
			+ ' completed=' + run.kern__CompletedAt__c?.format(TIME_FORMAT, TIME_ZONE) + ' modified=' + run.LastModifiedDate.format(TIME_FORMAT, TIME_ZONE)
			+ ' error=' + run.kern__ErrorMessage__c);
}

for(kern__ScheduledJob__c runnerRow : [SELECT Id, kern__ClassName__c, kern__IsActive__c, kern__NextRunAt__c, kern__LastRunJobId__c, kern__LastRunAt__c, kern__LastRunOutcome__c, kern__LastRunReason__c, LastModifiedDate
		FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c = :PROBE_RUNNER_JOB])
{
	System.debug('PROBE RUNNER id=' + runnerRow.Id + ' class=' + runnerRow.kern__ClassName__c + ' active=' + runnerRow.kern__IsActive__c
			+ ' nextRunAt=' + runnerRow.kern__NextRunAt__c?.format(TIME_FORMAT, TIME_ZONE) + ' lastRunJobId=' + runnerRow.kern__LastRunJobId__c + ' lastRunAt=' + runnerRow.kern__LastRunAt__c?.format(TIME_FORMAT, TIME_ZONE) + ' outcome=' + runnerRow.kern__LastRunOutcome__c + ' reason=' + runnerRow.kern__LastRunReason__c
			+ ' modified=' + runnerRow.LastModifiedDate.format(TIME_FORMAT, TIME_ZONE));
}

Integer liveJobs = 0;
for(AggregateResult row : [SELECT ApexClass.Name className, Status status, COUNT(Id) total FROM AsyncApexJob
		WHERE Status IN :LIVE_JOB_STATUSES AND JobType != 'BatchApexWorker' GROUP BY ApexClass.Name, Status])
{
	liveJobs += (Integer)row.get('total');
	System.debug('PROBE LIVE class=' + row.get('className') + ' status=' + row.get('status') + ' count=' + row.get('total'));
}

for(AsyncApexJob job : [SELECT Id, ApexClass.Name, JobType, Status, ExtendedStatus, NumberOfErrors, CreatedDate, CompletedDate
		FROM AsyncApexJob WHERE JobType != 'TestRequest' ORDER BY CreatedDate DESC LIMIT 20])
{
	System.debug('PROBE JOB id=' + job.Id + ' class=' + job.ApexClass?.Name + ' type=' + job.JobType + ' status=' + job.Status
			+ ' created=' + job.CreatedDate.format(TIME_FORMAT, TIME_ZONE) + ' completed=' + job.CompletedDate?.format(TIME_FORMAT, TIME_ZONE)
			+ ' errors=' + job.NumberOfErrors + ' extended=' + job.ExtendedStatus);
}

System.debug('PROBE GATE remaining=' + (daily.getLimit() - daily.getValue()) + ' probeSchedules=' + probeSchedules + ' pendingCalls=' + pendingCalls
		+ ' outboundInterviews=' + pausedInterviews + ' runningChains=' + runningChains + ' liveJobs=' + liveJobs);
