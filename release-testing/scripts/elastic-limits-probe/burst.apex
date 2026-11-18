// Elastic limits probe: start a burst of slow background jobs in one transaction.
//
// Token:
//   __KIND__  queueables: queue 10 ElasticProbeSlowFiller jobs (about four seconds of processor time each);
//             batches: start 2 ElasticProbeSlowBatch jobs back to back (three parts of one number each, about four
//             seconds of processor time per part).
//
// Prints the time (Eastern), DailyAsyncApexExecutions remaining before and after in the same transaction, and every
// job id with its first status. A refused enqueue or batch start is printed and stops the burst. Each job's own
// AsyncApexJob row (created, completed, status) is the measurement; the jobs log nothing.
//
// Run: sf apex run -o YourSubscriberOrgAlias -f <rendered copy with the token replaced> --json > <file>
final String KIND = '__KIND__';
final Integer QUEUEABLE_COUNT = 10;
final Integer BATCH_COUNT = 2;
final Integer BATCH_SIZE = 1;
final String TIME_ZONE = 'America/New_York';
final String TIME_FORMAT = 'yyyy-MM-dd HH:mm:ss';

System.OrgLimit daily = OrgLimits.getMap().get('DailyAsyncApexExecutions');
System.debug('PROBE BURST time=' + System.now().format(TIME_FORMAT, TIME_ZONE) + ' kind=' + KIND + ' maximum=' + daily.getLimit()
		+ ' used=' + daily.getValue() + ' remainingBefore=' + (daily.getLimit() - daily.getValue()));

List<Id> jobIds = new List<Id>();
Integer jobCount = KIND == 'batches' ? BATCH_COUNT : QUEUEABLE_COUNT;
for(Integer index = 0; index < jobCount; index++)
{
	try
	{
		if(KIND == 'batches')
		{
			jobIds.add(Database.executeBatch(new ElasticProbeSlowBatch(), BATCH_SIZE));
		}
		else
		{
			jobIds.add(System.enqueueJob(new ElasticProbeSlowFiller()));
		}
	}
	catch(Exception enqueueError)
	{
		System.debug('PROBE BURST refused at job ' + (index + 1) + ': ' + enqueueError.getTypeName() + ': ' + enqueueError.getMessage());
		break;
	}
}

for(AsyncApexJob job : [SELECT Id, JobType, Status, CreatedDate FROM AsyncApexJob WHERE Id IN :jobIds ORDER BY CreatedDate])
{
	System.debug('PROBE BURST job id=' + job.Id + ' type=' + job.JobType + ' firstStatus=' + job.Status
			+ ' created=' + job.CreatedDate.format(TIME_FORMAT, TIME_ZONE));
}
System.OrgLimit dailyAfter = OrgLimits.getMap().get('DailyAsyncApexExecutions');
System.debug('PROBE BURST queued=' + jobIds.size() + ' remainingAfterEnqueueSameTransaction=' + (dailyAfter.getLimit() - dailyAfter.getValue())
		+ ' time=' + System.now().format(TIME_FORMAT, TIME_ZONE));
