// Elastic limits probe: delete everything the probe created, then count what is left.
//
// Token:
//   __KEEP__  the id of one kern__ApiCall__c to leave in place (a stranded retry kept for the next step), or none.
//
// Safe to run again after a partial failure: each category is in its own try, so one failure does not stop the rest.
// Deletes: probe chain runs (correlation id starting elasticprobe); probe outbound calls (handler API_RetryLiveGet)
// and their API issues, except the kept call and its issues; probe runner rows (Elastic Probe Runner Job); the
// launcher's Accounts (named ElasticProbe_...). Aborts every probe schedule (named Elastic Probe ...), never the
// Salesforce jobs. Deletes a paused interview of the two outbound flows only when it belongs to the probe: the record it
// waits on (FlowRecordRelation) is a probe call, or is an API call that no longer exists. Any other interview in the
// org is left alone, and so is an interview of the kept call. If anonymous Apex cannot read or delete interviews, it
// says so. Then prints one PROBE LEFT line per category with the count left: each expected 0 (or 1 kept call).
//
// Run: sf apex run -o YourSubscriberOrgAlias -f <rendered copy with the token replaced> --json > <file>
final String KEEP = '__KEEP__';
final Id KEEP_ID = KEEP == 'none' ? null : (Id)KEEP;
final String PROBE_SERVICE = 'API_RetryLiveGet';
final String PROBE_CHAIN_MARKER = 'elasticprobe%';
final String PROBE_SCHEDULE_PATTERN = 'Elastic Probe%';
final String PROBE_RUNNER_JOB = 'Elastic Probe Runner Job';
final String PROBE_ACCOUNT_PATTERN = 'ElasticProbe_%';

// Finds the outbound-flow interviews that belong to the probe. An interview belongs to the probe when a record it waits
// on is one of the probe's calls (read before they were deleted) or is an API call that no longer exists. The kept call's
// interviews are never returned. An interview with no record link is printed and left alone.
List<SObject> findProbeInterviews(Set<Id> probeCallIds, Id keepId, List<Id> unlinkedInterviewIds)
{
	Map<Id, SObject> outboundInterviews = new Map<Id, SObject>();
	for(SObject interview : Database.query('SELECT Id, InterviewLabel, InterviewStatus FROM FlowInterview'))
	{
		String label = (String)interview.get('InterviewLabel');
		if(label != null && (label.contains('Retry') || label.contains('Invoke') || label.contains('Outbound')))
		{
			outboundInterviews.put(interview.Id, interview);
		}
	}
	List<SObject> probeInterviews = new List<SObject>();
	if(outboundInterviews.isEmpty())
	{
		return probeInterviews;
	}
	Set<Id> interviewIds = outboundInterviews.keySet();
	Map<Id, Set<Id>> recordIdsByInterview = new Map<Id, Set<Id>>();
	Set<Id> linkedCallIds = new Set<Id>();
	for(SObject relation : Database.query('SELECT ParentId, RelatedRecordId FROM FlowRecordRelation WHERE ParentId IN :interviewIds'))
	{
		Id interviewId = (Id)relation.get('ParentId');
		Id recordId = (Id)relation.get('RelatedRecordId');
		if(!recordIdsByInterview.containsKey(interviewId))
		{
			recordIdsByInterview.put(interviewId, new Set<Id>());
		}
		recordIdsByInterview.get(interviewId).add(recordId);
		if(recordId != null && recordId.getSObjectType() == kern__ApiCall__c.SObjectType)
		{
			linkedCallIds.add(recordId);
		}
	}
	Set<Id> existingCallIds = new Map<Id, kern__ApiCall__c>([SELECT Id FROM kern__ApiCall__c WHERE Id IN :linkedCallIds]).keySet();
	for(Id interviewId : interviewIds)
	{
		Set<Id> recordIds = recordIdsByInterview.get(interviewId);
		if(recordIds == null)
		{
			System.debug('PROBE CLEAN interview left alone, no record link: id=' + interviewId + ' label=' + outboundInterviews.get(interviewId).get('InterviewLabel'));
			unlinkedInterviewIds.add(interviewId);
			continue;
		}
		Boolean isKept = keepId != null && recordIds.contains(keepId);
		Boolean isProbe = false;
		for(Id recordId : recordIds)
		{
			Boolean isApiCall = recordId != null && recordId.getSObjectType() == kern__ApiCall__c.SObjectType;
			if(probeCallIds.contains(recordId) || (isApiCall && !existingCallIds.contains(recordId)))
			{
				isProbe = true;
			}
		}
		if(isProbe && !isKept)
		{
			probeInterviews.add(outboundInterviews.get(interviewId));
		}
	}
	return probeInterviews;
}

Set<Id> probeCallIds = new Set<Id>();
try
{
	probeCallIds = new Map<Id, kern__ApiCall__c>([SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c = :PROBE_SERVICE]).keySet();
}
catch(Exception cleanUpError)
{
	System.debug('PROBE CLEAN probe call ids unreadable: ' + cleanUpError.getTypeName() + ': ' + cleanUpError.getMessage());
}

try
{
	delete [SELECT Id FROM kern__AsyncChainExecution__c WHERE kern__CorrelationId__c LIKE :PROBE_CHAIN_MARKER];
}
catch(Exception cleanUpError)
{
	System.debug('PROBE CLEAN chain runs failed: ' + cleanUpError.getTypeName() + ': ' + cleanUpError.getMessage());
}
try
{
	delete [SELECT Id FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :PROBE_SERVICE AND (kern__ApiCall__c = null OR kern__ApiCall__c != :KEEP_ID)];
}
catch(Exception cleanUpError)
{
	System.debug('PROBE CLEAN issues failed: ' + cleanUpError.getTypeName() + ': ' + cleanUpError.getMessage());
}
try
{
	delete [SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c = :PROBE_SERVICE AND Id != :KEEP_ID];
}
catch(Exception cleanUpError)
{
	System.debug('PROBE CLEAN calls failed: ' + cleanUpError.getTypeName() + ': ' + cleanUpError.getMessage());
}
try
{
	delete [SELECT Id FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c = :PROBE_RUNNER_JOB];
}
catch(Exception cleanUpError)
{
	System.debug('PROBE CLEAN runner rows failed: ' + cleanUpError.getTypeName() + ': ' + cleanUpError.getMessage());
}
try
{
	delete [SELECT Id FROM Account WHERE Name LIKE :PROBE_ACCOUNT_PATTERN];
}
catch(Exception cleanUpError)
{
	System.debug('PROBE CLEAN launcher accounts failed: ' + cleanUpError.getTypeName() + ': ' + cleanUpError.getMessage());
}
try
{
	for(CronTrigger cronRow : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE :PROBE_SCHEDULE_PATTERN AND State != 'DELETED'])
	{
		System.abortJob(cronRow.Id);
	}
}
catch(Exception cleanUpError)
{
	System.debug('PROBE CLEAN schedules failed: ' + cleanUpError.getTypeName() + ': ' + cleanUpError.getMessage());
}

try
{
	List<SObject> probeInterviews = findProbeInterviews(probeCallIds, KEEP_ID, new List<Id>());
	if(!probeInterviews.isEmpty())
	{
		delete probeInterviews;
	}
}
catch(Exception cleanUpError)
{
	System.debug('PROBE CLEAN flow interviews cannot be read or deleted from Apex: ' + cleanUpError.getTypeName() + ': ' + cleanUpError.getMessage());
}

String interviewsLeft = 'unknown';
Integer unlinkedInterviews = null;
try
{
	List<Id> unlinkedInterviewIds = new List<Id>();
	interviewsLeft = String.valueOf(findProbeInterviews(probeCallIds, KEEP_ID, unlinkedInterviewIds).size());
	unlinkedInterviews = unlinkedInterviewIds.size();
}
catch(Exception readError)
{
	System.debug('PROBE LEFT flow interviews unreadable: ' + readError.getMessage());
}

System.debug('PROBE LEFT chain runs=' + [SELECT COUNT() FROM kern__AsyncChainExecution__c WHERE kern__CorrelationId__c LIKE :PROBE_CHAIN_MARKER]);
System.debug('PROBE LEFT calls=' + [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c = :PROBE_SERVICE] + ' kept=' + KEEP);
System.debug('PROBE LEFT issues=' + [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :PROBE_SERVICE]);
System.debug('PROBE LEFT runner rows=' + [SELECT COUNT() FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c = :PROBE_RUNNER_JOB]);
System.debug('PROBE LEFT launcher accounts=' + [SELECT COUNT() FROM Account WHERE Name LIKE :PROBE_ACCOUNT_PATTERN]);
System.debug('PROBE LEFT probe schedules=' + [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE :PROBE_SCHEDULE_PATTERN AND State != 'DELETED']);
System.debug('PROBE LEFT probe flow interviews=' + interviewsLeft);
System.debug('PROBE LEFT outbound flow interviews with no record link=' + (unlinkedInterviews == null ? 'unknown' : String.valueOf(unlinkedInterviews)));
