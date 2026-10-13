/**
 * Section 87b: the purge of API calls at volume (verify; subscriber org)
 *
 * Run at least 4 minutes after the run of section 87 that scheduled the purge job. By then the job has fired once, as
 * the administrator who scheduled it, and the purge's Queueables have finished:
 *   87b-1. No API call older than 365 days is left, and none of the 5,000 seeded rows.
 *   87b-2. The batches: the purge started one Queueable per 2,000 rows due (3 for 5,000), all Completed with no
 *          error; if the platform chose a batch job instead, its batches are counted the same way.
 *   87b-3. The purge was not refused: no "Delete API Records" warning was logged at
 *          UTIL_PurgeRecords/deleteOlderThanNDays after the job fired (the flag is on for an administrator).
 * Then it prints the PERF_ROW lines for section 87: rowsPurged, wallMs (from the time the job was due to fire to the
 * end of the last batch, so it includes the platform's delay in starting it), rowsPerSecond and batches.
 * If the job has not fired yet, or a batch is still running, the script prints SECTION87 PENDING, deletes nothing, and
 * is run again 30 seconds later. Waiting ends 10 minutes after the job fired (or was due to fire): then the checks run
 * on what is there, so a refused purge (no batch started) prints 87b-2 and 87b-3 FAIL, and a job that never fired
 * prints one FAIL line and deletes its scheduled job row.
 *
 * Expected: 4 passed, 0 failed (87b-1 to 87b-3 and 87b-cleanup).
 *
 * Cleanup (only once nothing is pending): deletes the scheduled job row, which stops its platform job (the job's cron
 * fires once a day), deletes any seeded row the purge left, and proves by query that neither is left.
 *
 * Prerequisites (the same as section 87):
 *   - section 87 scheduled the purge job (its kern__ScheduledJob__c row, Section 87 Purge At Volume, is there)
 *   - the running user is the one who ran section 87 (the purge's jobs are found by their creator) and holds the Kern
 *     Administrator permission set: Delete API Records turns the BypassApiRecordDeleteGuard flag on, and the set gives
 *     delete access on API calls and access to scheduled jobs
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-87b-purge-at-volume-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug('=== Section 87b: the purge of API calls at volume (verify) ===');

Integer pass = 0;
Integer fail = 0;

final String SEED_SERVICE = 'PurgeVolumeSeed';
final String JOB_NAME = 'Section 87 Purge At Volume';
final String ROWS_DUE_PREFIX = 'rows due: ';
final String PURGE_LOCATION_PATTERN = '%UTIL_PurgeRecords/deleteOlderThanNDays';
final String LAUNCHER_CLASS = 'UTIL_AdaptiveAsynchronousProcessor';
final String PACKAGE_NAMESPACE = 'kern';
final String JOB_COMPLETED = 'Completed';
final String JOB_TYPE_BATCH = 'BatchApex';
final Set<String> JOB_ENDED = new Set<String> {'Completed', 'Failed', 'Aborted'};
final Set<String> JOB_TYPES = new Set<String> {'Queueable', 'BatchApex'};
final Integer ROWS_PER_BATCH = 2000;
final Integer START_WINDOW_MINUTES = 5;
final Integer PENDING_BOUND_MINUTES = 10;

List<kern__ScheduledJob__c> scheduledJobs = [SELECT Id, kern__ScheduledJobId__c, kern__Description__c FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c = :JOB_NAME];
if(scheduledJobs.isEmpty())
{
	throw new System.AssertException('Section 87b: no scheduled job of section 87 is found; run section 87 until it schedules the job');
}
kern__ScheduledJob__c scheduledJob = scheduledJobs[0];
Integer rowsDue = Integer.valueOf(scheduledJob.kern__Description__c.substringAfter(ROWS_DUE_PREFIX).trim());
Integer expectedBatches = (Integer)Math.ceil((Decimal)rowsDue / ROWS_PER_BATCH);

List<CronTrigger> triggers = [SELECT Id, PreviousFireTime, NextFireTime, TimesTriggered FROM CronTrigger WHERE Id = :scheduledJob.kern__ScheduledJobId__c];
Datetime firedAt = triggers.isEmpty() ? null : triggers[0].PreviousFireTime;
// Waiting ends this long after the job fired, or was due to fire: a refused purge starts no job, so without a bound the
// script would wait for ever and its 87b-3 line would never print.
Datetime dueAt = firedAt ?? (triggers.isEmpty() ? null : triggers[0].NextFireTime);
Boolean isPastBound = dueAt == null || Datetime.now() > dueAt.addMinutes(PENDING_BOUND_MINUTES);

List<AsyncApexJob> jobs = new List<AsyncApexJob>();
if(firedAt != null)
{
	// The purge starts its jobs from the scheduled transaction, as the user who scheduled it.
	Datetime windowEnd = firedAt.addMinutes(START_WINDOW_MINUTES);
	jobs = [SELECT Id, Status, JobType, TotalJobItems, NumberOfErrors, ExtendedStatus, CreatedDate, CompletedDate FROM AsyncApexJob
			WHERE ApexClass.Name = :LAUNCHER_CLASS AND ApexClass.NamespacePrefix = :PACKAGE_NAMESPACE AND JobType IN :JOB_TYPES
			AND CreatedById = :UserInfo.getUserId() AND CreatedDate >= :firedAt AND CreatedDate <= :windowEnd];
}
Boolean areJobsDone = firedAt != null && !jobs.isEmpty();
for(AsyncApexJob job : jobs)
{
	areJobsDone = areJobsDone && JOB_ENDED.contains(job.Status);
}

if(!areJobsDone && !isPastBound)
{
	System.debug('SECTION87 PENDING: the purge job ' + (firedAt == null ? 'has not fired yet' : 'fired at ' + firedAt + ', ' + jobs.size() + ' batches found, not all finished')
			+ '. Nothing was deleted. Run this script again in 30 seconds.');
}
else if(firedAt == null)
{
	fail++;
	System.debug('SECTION87 FAIL 87b-1: the purge job did not fire within ' + PENDING_BOUND_MINUTES + ' minutes of its time (' + dueAt + ', platform job '
			+ scheduledJob.kern__ScheduledJobId__c + '). The scheduled job row was deleted; run section 87 again.');
	delete scheduledJobs;
	System.debug('Section 87b: ' + pass + ' passed, ' + fail + ' failed');
}
else
{
	// 87b-1: nothing older than the retention is left.
	Integer rowsLeft = [SELECT COUNT() FROM kern__ApiCall__c WHERE CreatedDate < LAST_N_DAYS:364];
	Integer seedRowsLeft = [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SEED_SERVICE];
	if(rowsLeft == 0 && seedRowsLeft == 0)
	{
		pass++;
		System.debug('SECTION87 PASS 87b-1: the purge deleted all ' + rowsDue + ' API calls older than 365 days; none is left');
	}
	else
	{
		fail++;
		System.debug('SECTION87 FAIL 87b-1: ' + rowsLeft + ' API calls older than 365 days left, ' + seedRowsLeft + ' of them seeded by section 87');
	}

	// 87b-2: one batch per 2,000 rows due, all finished cleanly.
	Integer batches = 0;
	List<String> badJobs = new List<String>();
	Datetime lastCompleted;
	for(AsyncApexJob job : jobs)
	{
		batches += job.JobType == JOB_TYPE_BATCH ? (job.TotalJobItems ?? 0) : 1;
		if(job.Status != JOB_COMPLETED || (job.NumberOfErrors ?? 0) > 0)
		{
			badJobs.add(job.Id + ' ' + job.Status + ' ' + job.ExtendedStatus);
		}
		lastCompleted = lastCompleted == null || job.CompletedDate > lastCompleted ? job.CompletedDate : lastCompleted;
	}
	if(batches == expectedBatches && badJobs.isEmpty())
	{
		pass++;
		String jobType = jobs.isEmpty() ? 'none' : jobs[0].JobType;
		System.debug('SECTION87 PASS 87b-2: ' + batches + ' batches for ' + rowsDue + ' rows (' + jobs.size() + ' jobs, ' + jobType + '), all Completed with no error');
	}
	else
	{
		fail++;
		System.debug('SECTION87 FAIL 87b-2: expected ' + expectedBatches + ' batches all Completed; got ' + batches + ' in ' + jobs.size() + ' jobs, not completed: ' + badJobs);
	}

	// 87b-3: the administrator's purge was not refused.
	Integer refusals = [SELECT COUNT() FROM kern__LogEntry__c WHERE kern__ClassMethod__c LIKE :PURGE_LOCATION_PATTERN AND CreatedDate >= :firedAt];
	if(refusals == 0)
	{
		pass++;
		System.debug('SECTION87 PASS 87b-3: the purge was not refused: no Delete API Records warning was logged');
	}
	else
	{
		fail++;
		System.debug('SECTION87 FAIL 87b-3: ' + refusals + ' Delete API Records warnings logged by the purge; the flag is off for the running user');
	}

	Long wallMs = lastCompleted == null ? 0 : lastCompleted.getTime() - firedAt.getTime();
	Integer rowsPurged = rowsDue - rowsLeft;
	Decimal rowsPerSecond = ((Decimal)rowsPurged * 1000 / Math.max(wallMs, 1000)).setScale(1);
	System.debug('PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 87, 'metric' => 'rowsPurged', 'value' => rowsPurged}));
	System.debug('PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 87, 'metric' => 'wallMs', 'value' => wallMs}));
	System.debug('PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 87, 'metric' => 'rowsPerSecond', 'value' => rowsPerSecond}));
	System.debug('PERF_ROW: ' + JSON.serialize(new Map<String, Object> {'section' => 87, 'metric' => 'batches', 'value' => batches}));

	// Cleanup: the scheduled job row (its delete stops the platform job) and any seeded row the purge left.
	delete scheduledJobs;
	delete [SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SEED_SERVICE LIMIT 9000];
	Integer jobsLeft = [SELECT COUNT() FROM kern__ScheduledJob__c WHERE kern__SchedulerName__c = :JOB_NAME]
			+ [SELECT COUNT() FROM CronTrigger WHERE Id = :scheduledJob.kern__ScheduledJobId__c];
	Integer seedLeft = [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SEED_SERVICE];
	if(jobsLeft + seedLeft == 0)
	{
		pass++;
		System.debug('SECTION87 PASS 87b-cleanup: the scheduled job and its platform job are gone, and no seeded row is left');
	}
	else
	{
		fail++;
		System.debug('SECTION87 FAIL 87b-cleanup: left behind: ' + jobsLeft + ' scheduled or platform jobs, ' + seedLeft + ' seeded rows');
	}

	System.debug('Section 87b: ' + pass + ' passed, ' + fail + ' failed');
}
