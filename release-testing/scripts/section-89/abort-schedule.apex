// Runbook section 89: stop one schedule the driver made, and say whether it is gone.
//
// Token:
//   __CRON_ID__  the id of the schedule (a CronTrigger id) that schedule-once.apex printed.
//
// The dry run uses it to stop the outbound retry watchdog's schedule before it fires; the probe's clean-up.apex,
// which stops every probe schedule, also deletes rows, so the dry run does not run it.
// Prints one line: SECTION89 SCHEDULE id=<id> aborted=<true or false> left=<number of such schedules not deleted>.
//
// Run: sf apex run -o <org alias> -f <rendered copy with the token replaced> --json > <file>
final Id CRON_ID = (Id)'__CRON_ID__';

Boolean aborted = false;
if(![SELECT Id FROM CronTrigger WHERE Id = :CRON_ID AND State != 'DELETED'].isEmpty())
{
	System.abortJob(CRON_ID);
	aborted = true;
}
System.debug('SECTION89 SCHEDULE id=' + CRON_ID + ' aborted=' + aborted + ' left='
		+ [SELECT COUNT() FROM CronTrigger WHERE Id = :CRON_ID AND State != 'DELETED']);
