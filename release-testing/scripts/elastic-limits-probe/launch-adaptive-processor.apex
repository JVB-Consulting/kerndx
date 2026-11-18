// Elastic limits probe: hand AccountArchiveProcessor a list of Accounts through kern.UTIL_AsynchronousJobLauncher
// (a copy of section-49-load-async-launcher.apex, changed).
//
// What changed from section 49: one input size per run instead of both; an optional dispatch delay; an optional second
// launch in the same transaction; an optional chainable strategy with a set job size; every launch's exception is
// caught and printed instead of failing the script (a thrown script rolls everything back, and the probe needs to see
// what the caller sees); no handoff Foobar, because no verify script reads it; the Accounts are named ElasticProbe...
// so clean-up.apex finds them. Each run also prints one "PROBE LAUNCHER items=" line with its Account ids in order.
//
// Tokens:
//   __ITEMS__   49 (at or under the batch threshold of 50, so a queueable strategy) or 51 (over it, so a batch).
//   __DELAY__   0 for no delay, or the delay in minutes (1 for the probe's delayed dispatch). With auto it is the
//               launcher's dispatch delay (withDelayMinutes): the job the launch queues is a UTIL_AsynchronousJobLauncher
//               handler, which starts the work when the delay is over. With chainable it is a minimum delay on every job
//               of the chain (AsyncOptions.minimumQueueableDelayInMinutes, through withAsyncOptions): the job the launch
//               queues is the chain's first UTIL_AdaptiveAsynchronousProcessor job, and each next job waits as long.
//   __RUNS__    1, or 2 to launch two of the same back to back in one transaction.
//   __STRATEGY__  auto: the launcher chooses the job type, as before. chainable: the request asks for a chain of Queueables
//               (kern.IF_Async.AsynchronousExecutionStrategy.CHAINABLE), each job taking __JOB_SIZE__ items and starting
//               the next job from its Finalizer. Runbook section 89 uses chainable with 3 items, a job size of 1 and a
//               delay of 1, so the first job starts and the second is refused at the daily limit.
//   __JOB_SIZE__  the number of items each job of a chainable launch takes (ignored with auto; pass 0).
//
// Prerequisites: AccountArchiveProcessor deployed (release-testing/subscriber/classes/).
//
// Run: sf apex run -o YourSubscriberOrgAlias -f <rendered copy with the tokens replaced> --json > <file>
final Integer ITEMS = __ITEMS__;
final Integer DELAY_MINUTES = __DELAY__;
final Integer RUNS = __RUNS__;
final String STRATEGY = '__STRATEGY__';
final Integer JOB_SIZE = __JOB_SIZE__;
final Integer THRESHOLD = 50;
final String TIME_ZONE = 'America/New_York';
final String TIME_FORMAT = 'yyyy-MM-dd HH:mm:ss';
final String NAME_PREFIX = 'ElasticProbe_' + System.currentTimeMillis() + '_';

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();
kern.UTIL_ValidationRule.bypassObject('Account');

System.OrgLimit daily = OrgLimits.getMap().get('DailyAsyncApexExecutions');
System.debug('PROBE LAUNCHER time=' + System.now().format(TIME_FORMAT, TIME_ZONE) + ' remaining=' + (daily.getLimit() - daily.getValue())
		+ ' items=' + ITEMS + ' delayMinutes=' + DELAY_MINUTES + ' runs=' + RUNS + ' strategy=' + STRATEGY + ' jobSize=' + JOB_SIZE);

for(Integer run = 0; run < RUNS; run++)
{
	List<Account> accounts = new List<Account>();
	for(Integer index = 0; index < ITEMS; index++)
	{
		accounts.add(new Account(Name = NAME_PREFIX + run + '_' + index));
	}
	insert accounts;
	List<Object> items = new List<Object>();
	List<Id> accountIds = new List<Id>();
	for(Account record : accounts)
	{
		items.add(record);
		accountIds.add(record.Id);
	}
	System.debug('PROBE LAUNCHER items=' + String.join(accountIds, ',') + ' run=' + run);

	kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
			new kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(items).withLimitAtWhichToBatch(THRESHOLD);
	if(STRATEGY == 'chainable')
	{
		request.withExecutionStrategy(kern.IF_Async.AsynchronousExecutionStrategy.CHAINABLE).withQueueableJobSize(JOB_SIZE);
		if(DELAY_MINUTES > 0)
		{
			// The delay goes on the chain's own jobs, so the job the launch queues is the chain's first job.
			AsyncOptions options = new AsyncOptions();
			options.minimumQueueableDelayInMinutes = DELAY_MINUTES;
			request.withAsyncOptions(options);
		}
	}
	else if(DELAY_MINUTES > 0)
	{
		// The launcher's delayed dispatch: the job the launch queues is the launcher's handler, which starts the work later.
		request.withDelayMinutes(DELAY_MINUTES);
	}
	try
	{
		Id jobId = kern.UTIL_AsynchronousJobLauncher.process(request, new AccountArchiveProcessor());
		List<AsyncApexJob> jobs = [SELECT Id, ApexClass.Name, JobType, Status FROM AsyncApexJob WHERE Id = :jobId];
		System.debug('PROBE LAUNCHER run=' + run + ' accepted job=' + jobId + (jobs.isEmpty() ? ' (no job row)' : ' class=' + jobs[0].ApexClass?.Name
				+ ' type=' + jobs[0].JobType + ' status=' + jobs[0].Status));
	}
	catch(Exception launchError)
	{
		System.debug('PROBE LAUNCHER run=' + run + ' refused ' + launchError.getTypeName() + ': ' + launchError.getMessage());
	}
}
