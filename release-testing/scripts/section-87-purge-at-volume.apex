/**
 * Section 87: the purge of API calls at volume, run by an administrator through a scheduled job (subscriber org)
 *
 * Seeds 5,000 kern__ApiCall__c rows created 400 days ago and schedules the package's purge job, SCHED_PurgeRecords,
 * the way the Scheduled Jobs page does (a kern__ScheduledJob__c row; journey V15 creates one from the page). The job
 * fires about two minutes later as the running user, an administrator, and calls
 * kern.UTIL_PurgeRecords.deleteOlderThanNDays('kern__ApiCall__c', null, 365, false, 2000). Why the delete goes through:
 *   - the purge checks the BypassApiRecordDeleteGuard feature flag first (UTIL_PurgeRecords.canPurge). A built-in rule
 *     turns that flag on for every holder of the Delete API Records permission, which the Kern Administrator
 *     permission set grants, so the purge starts its jobs and logs no warning;
 *   - the delete guard (TRG_GuardApiRecordDeletion) runs before every delete of an API call, but the trigger framework
 *     skips it for a user the same flag is on for, so no row is refused.
 * The purge reads every row older than 365 days and starts its jobs from the scheduled transaction, 2,000 rows per job
 * (the job's default batch size). With 5,000 rows due that is 3 Queueables side by side. Section 87b, run once the job
 * has fired, checks that no row is left and counts the batches. The resolver's purge (a user without the flag: nothing
 * deleted, one warning per job) is the subscriber test SubscriberApiRecordDeleteGuard_TEST, because anonymous Apex
 * cannot run as another user.
 *
 * Seeding: the rows are inserted in lists of 1,000, as many as fit in this transaction's CPU time. When fewer than
 * 5,000 seeded rows exist after this run, the script prints SECTION87 PENDING and schedules nothing: run it again until
 * the seed is complete. Each run tops up to 5,000.
 *
 * Checks printed here (on the run that completes the seed): 87-1 the seed (5,000 rows, all created 400 days ago, so
 * back-dating works); 87-2 the job is scheduled (a platform job id is recorded, and it fires within three minutes).
 * Expected: 2 passed, 0 failed.
 *
 * Note: the purge deletes EVERY kern__ApiCall__c row older than 365 days in the org, not only this section's rows. The
 * script counts them all and records the count for 87b; on a subscriber scratch org they are normally only these 5,000.
 *
 * Run-isolation: refuses to schedule while a scheduled job of an earlier run is left (section 87b deletes it).
 *
 * Prerequisites:
 *   - subscriber org with the kern managed package installed
 *   - the running user holds the Kern Administrator permission set (Delete API Records, so the flag is on; delete and
 *     create access on API calls; access to scheduled jobs)
 *   - audit-field back-dating enabled for the running user (RUNBOOK Phase 1.4: "Set Audit Fields upon Record Creation"
 *     and the KernE2EAuditFieldAccess permission set; preflight-audit-backdating.apex checks it). The script checks it
 *     first with one row, before any heavy work: without it, it prints one 87-1 FAIL line and seeds and schedules nothing
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-87-purge-at-volume.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *   (again while it prints PENDING), then, at least 4 minutes after the run that scheduled the job,
 *   section-87b-purge-at-volume-verify.apex
 */

System.debug('=== Section 87: the purge of API calls at volume ===');

Integer pass = 0;
Integer fail = 0;

final String SEED_SERVICE = 'PurgeVolumeSeed';
final String JOB_NAME = 'Section 87 Purge At Volume';
final String JOB_CLASS = 'kern.SCHED_PurgeRecords';
final String EXECUTION_MODE = 'OwnScheduledJob';
final String STATUS_COMPLETED = 'Completed';
final String DIRECTION_OUTBOUND = 'Outbound';
final String ROWS_DUE_PREFIX = 'rows due: ';
final Integer SEED_TOTAL = 5000;
final Integer SEED_LIST_SIZE = 1000;
final Integer RETENTION_DAYS = 365;
final Integer SEED_AGE_DAYS = 400;
final Integer CPU_BUDGET_MS = 8500;
final Integer MINUTES_UNTIL_FIRE = 2;
final Datetime SEED_CREATED_DATE = System.now().addDays(-SEED_AGE_DAYS);
final Datetime RETENTION_CUTOFF = System.now().addDays(-RETENTION_DAYS);

if([SELECT COUNT() FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c = :JOB_NAME] > 0)
{
	throw new System.AssertException('Section 87: the scheduled job of an earlier run is left; run section-87b-purge-at-volume-verify.apex to delete it');
}

// The precondition first, with one row and before any heavy work: back-dating must work for the running user. Without
// the permission the write or the insert throws; with it switched off the platform may keep today's date instead.
Integer seeded = [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SEED_SERVICE];
Boolean canBackdate = seeded >= SEED_TOTAL;
String backdateProblem = '';
if(!canBackdate)
{
	kern__ApiCall__c probe = new kern__ApiCall__c(kern__ServiceName__c = SEED_SERVICE, kern__Direction__c = DIRECTION_OUTBOUND, kern__Status__c = STATUS_COMPLETED);
	try
	{
		probe.put('CreatedDate', SEED_CREATED_DATE);
		insert probe;
		canBackdate = [SELECT CreatedDate FROM kern__ApiCall__c WHERE Id = :probe.Id].CreatedDate < RETENTION_CUTOFF;
		if(canBackdate)
		{
			seeded++;
		}
		else
		{
			backdateProblem = 'the platform kept today\'s date';
			delete probe;
		}
	}
	catch(Exception backdateError)
	{
		backdateProblem = backdateError.getMessage();
	}
}
if(!canBackdate)
{
	fail++;
	System.debug('SECTION87 FAIL 87-1: back-dating is not enabled for the running user (' + backdateProblem + '). Nothing was seeded or scheduled; '
			+ 'enable it (RUNBOOK Phase 1.4) and run this section again.');
}

// The seed, topped up to 5,000 in lists of 1,000 while the CPU time lasts.
Integer lastListCpuMs = 0;
while(canBackdate && seeded < SEED_TOTAL && Limits.getCpuTime() + lastListCpuMs < CPU_BUDGET_MS)
{
	Integer cpuBeforeMs = Limits.getCpuTime();
	List<kern__ApiCall__c> rows = new List<kern__ApiCall__c>();
	for(Integer index = 0; index < Math.min(SEED_LIST_SIZE, SEED_TOTAL - seeded); index++)
	{
		kern__ApiCall__c row = new kern__ApiCall__c(kern__ServiceName__c = SEED_SERVICE, kern__Direction__c = DIRECTION_OUTBOUND, kern__Status__c = STATUS_COMPLETED);
		row.put('CreatedDate', SEED_CREATED_DATE);
		rows.add(row);
	}
	insert rows;
	seeded += rows.size();
	lastListCpuMs = Limits.getCpuTime() - cpuBeforeMs;
}

if(!canBackdate)
{
	System.debug('Section 87: ' + pass + ' passed, ' + fail + ' failed.');
}
else if(seeded < SEED_TOTAL)
{
	System.debug('SECTION87 PENDING: ' + seeded + ' of ' + SEED_TOTAL + ' rows seeded; the CPU time of one run is spent. Nothing was scheduled. '
			+ 'Run this section again to seed the rest.');
}
else
{
	// 87-1: the seed is complete and every row is older than the retention, so back-dating works.
	Integer recentSeedRows = [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SEED_SERVICE AND CreatedDate >= :RETENTION_CUTOFF];
	// The purge's own filter for 365 days: CreatedDate < LAST_N_DAYS:364 (UTIL_PurgeRecords.deleteOlderThanNDays).
	Integer rowsDue = [SELECT COUNT() FROM kern__ApiCall__c WHERE CreatedDate < LAST_N_DAYS:364];
	if(recentSeedRows > 0)
	{
		// The FAIL line before the delete, so it prints even if the delete runs out of CPU time.
		fail++;
		System.debug('SECTION87 FAIL 87-1: ' + recentSeedRows + ' seeded rows were created today, so back-dating did not work for the running user '
				+ '(RUNBOOK Phase 1.4). The seed is being deleted; enable back-dating and run this section again.');
		delete [SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SEED_SERVICE];
	}
	else
	{
		pass++;
		System.debug('SECTION87 PASS 87-1: ' + seeded + ' rows seeded, all created ' + SEED_AGE_DAYS + ' days ago; ' + rowsDue
				+ ' API calls in the org are older than ' + RETENTION_DAYS + ' days');

		// 87-2: the purge job, scheduled for the next whole minute two minutes from now, in the running user's time zone
		// (a job with no time zone runs its cron as written, in the time zone of the user who schedules it).
		try
		{
			Datetime fireAt = System.now().addMinutes(MINUTES_UNTIL_FIRE);
			String cron = '0 ' + fireAt.format('m') + ' ' + fireAt.format('H') + ' * * ?';
			kern__ScheduledJob__c job = new kern__ScheduledJob__c(
					kern__SchedulerName__c = JOB_NAME,
					kern__ClassName__c = JOB_CLASS,
					kern__CronExpression__c = cron,
					kern__IsActive__c = true,
					kern__ExecutionMode__c = EXECUTION_MODE,
					kern__Description__c = 'Release testing: the purge of API calls at volume; ' + ROWS_DUE_PREFIX + rowsDue,
					kern__Parameters__c = '{"nameValueMap":{"objectName":"kern__ApiCall__c","minimumNumberOfDays":"' + RETENTION_DAYS + '"}}'
			);
			insert job;
			job = [SELECT kern__ScheduledJobId__c FROM kern__ScheduledJob__c WHERE Id = :job.Id];
			List<CronTrigger> triggers = job.kern__ScheduledJobId__c == null ? new List<CronTrigger>()
					: [SELECT NextFireTime FROM CronTrigger WHERE Id = :job.kern__ScheduledJobId__c];
			Boolean firesSoon = !triggers.isEmpty() && triggers[0].NextFireTime <= System.now().addMinutes(MINUTES_UNTIL_FIRE + 1);
			if(firesSoon)
			{
				pass++;
				System.debug('SECTION87 PASS 87-2: the purge job is scheduled (cron ' + cron + '), platform job ' + job.kern__ScheduledJobId__c
						+ ', first run at ' + triggers[0].NextFireTime);
			}
			else
			{
				fail++;
				System.debug('SECTION87 FAIL 87-2: expected a platform job that fires within ' + (MINUTES_UNTIL_FIRE + 1) + ' minutes; got job id '
						+ job.kern__ScheduledJobId__c + ', triggers ' + triggers);
			}
		}
		catch(Exception scenarioError)
		{
			fail++;
			System.debug('SECTION87 FAIL 87-2: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
		}
	}

	System.debug('Section 87: ' + pass + ' passed, ' + fail + ' failed. Run section-87b-purge-at-volume-verify.apex at least 4 minutes from now.');
}
