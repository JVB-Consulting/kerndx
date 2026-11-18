// Runbook section 89: stop every schedule of the outbound retry watchdog that the probe made, found by its name, and
// say which are still there.
//
// Token:
//   __ACTION__  abort: stop every such schedule, then list the ones still there. read: only list them. The driver runs
//               abort and then read, in a second transaction, to prove none is left.
//
// The driver runs it when it could not read a schedule's id, or could not confirm that the stop by id worked, and
// always in --restore-only. Every such schedule is named "Elastic Probe Outbound Retry Watchdog <number>".
// Prints one line per schedule still there: SECTION89 SCHEDULE LEFT id=<id> name=<name>, then one summary line:
// SECTION89 SCHEDULES action=<abort or read> aborted=<number stopped> left=<number still there>.
//
// Run: sf apex run -o <org alias> -f <rendered copy with the token replaced> --json > <file>
final String ACTION = '__ACTION__';
final String NAME_PATTERN = 'Elastic Probe Outbound Retry Watchdog%';

Integer aborted = 0;
if(ACTION == 'abort')
{
	for(CronTrigger cronRow : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE :NAME_PATTERN AND State != 'DELETED'])
	{
		System.abortJob(cronRow.Id);
		aborted++;
	}
}
List<CronTrigger> stillThere = [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name LIKE :NAME_PATTERN AND State != 'DELETED'];
for(CronTrigger cronRow : stillThere)
{
	System.debug('SECTION89 SCHEDULE LEFT id=' + cronRow.Id + ' name=' + cronRow.CronJobDetail.Name);
}
System.debug('SECTION89 SCHEDULES action=' + ACTION + ' aborted=' + aborted + ' left=' + stillThere.size());
