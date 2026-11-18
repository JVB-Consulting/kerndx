// Elastic limits probe: use up the org's daily background-job allowance until a set number of executions is left.
//
// Tokens:
//   __LEAVE__  the number of executions to leave REMAINING (the maximum less what is used), not the number to spend.
//   __BATCH__  the most jobs to queue in this run: 50 with elastic limits off, at most 10 with them on, so a slow
//              drain shows early.
//
// It reads DailyAsyncApexExecutions once, works out (remaining - __LEAVE__), and queues exactly
// Math.min(that, __BATCH__) ElasticProbeFiller jobs, without reading the counter again inside the loop. After the loop,
// in the same transaction, it reads the counter once more: a count that moved there moved when the jobs were queued,
// before any of them ran. A refused enqueue is printed and stops the loop. Run it again after the state gate until the
// target is reached.
//
// Run: sf apex run -o YourSubscriberOrgAlias -f <rendered copy with the tokens replaced> --json > <file>
final Integer LEAVE = __LEAVE__;
final Integer BATCH = __BATCH__;
final String TIME_ZONE = 'America/New_York';
final String TIME_FORMAT = 'yyyy-MM-dd HH:mm:ss';

System.OrgLimit daily = OrgLimits.getMap().get('DailyAsyncApexExecutions');
Integer remainingBefore = daily.getLimit() - daily.getValue();
Integer toQueue = Math.max(0, Math.min(remainingBefore - LEAVE, BATCH));
System.debug('PROBE SPEND time=' + System.now().format(TIME_FORMAT, TIME_ZONE) + ' maximum=' + daily.getLimit() + ' remainingBefore=' + remainingBefore
		+ ' leave=' + LEAVE + ' toQueue=' + toQueue);

List<Id> queuedIds = new List<Id>();
for(Integer index = 0; index < toQueue; index++)
{
	try
	{
		queuedIds.add(System.enqueueJob(new ElasticProbeFiller()));
	}
	catch(Exception enqueueError)
	{
		System.debug('PROBE SPEND refused at job ' + (index + 1) + ': ' + enqueueError.getTypeName() + ': ' + enqueueError.getMessage());
		break;
	}
}

System.OrgLimit dailyAfter = OrgLimits.getMap().get('DailyAsyncApexExecutions');
System.debug('PROBE SPEND queued=' + queuedIds.size() + ' remainingAfterEnqueueSameTransaction=' + (dailyAfter.getLimit() - dailyAfter.getValue())
		+ ' firstJob=' + (queuedIds.isEmpty() ? null : queuedIds[0]) + ' lastJob=' + (queuedIds.isEmpty() ? null : queuedIds[queuedIds.size() - 1]));
