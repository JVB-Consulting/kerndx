// Elastic limits probe: schedule one pass of the chain watchdog, one pass of the outbound retry watchdog or one
// job-runner check, to fire once (section 79's schedule-once shape).
//
// Tokens:
//   __JOB__        watchdog (kern.SCHED_ChainWatchdog), outboundWatchdog (kern.SCHED_OutboundRetryWatchdog) or runner
//                  (kern.SCHED_JobRunner).
//   __THRESHOLD__  the StaleThresholdMinutes of either watchdog (ignored for the runner). Runbook section 89 uses 1
//                  for the outbound retry watchdog.
//   __SECONDS__    0: fire on the next minute boundary at least 60 seconds out, as section 79 does; more than 0: fire
//                  at that many seconds from now, on the second.
//
// The schedule is named "Elastic Probe ..." so read-budget.apex and clean-up.apex find it. Cron times are read in the
// running user's time zone, as System.schedule reads them.
//
// Run: sf apex run -o YourSubscriberOrgAlias -f <rendered copy with the tokens replaced> --json > <file>
final String JOB = '__JOB__';
final String THRESHOLD = '__THRESHOLD__';
final Integer SECONDS_OUT = __SECONDS__;
final String TIME_ZONE = 'America/New_York';
final String TIME_FORMAT = 'yyyy-MM-dd HH:mm:ss';

Datetime fireAt;
String cron;
if(SECONDS_OUT > 0)
{
	fireAt = System.now().addSeconds(SECONDS_OUT);
	cron = fireAt.second() + ' ' + fireAt.minute() + ' ' + fireAt.hour() + ' ' + fireAt.day() + ' ' + fireAt.month() + ' ? ' + fireAt.year();
}
else
{
	Datetime later = System.now().addSeconds(75);
	fireAt = Datetime.newInstance(later.year(), later.month(), later.day(), later.hour(), later.minute(), 0);
	cron = '0 ' + fireAt.minute() + ' ' + fireAt.hour() + ' ' + fireAt.day() + ' ' + fireAt.month() + ' ? ' + fireAt.year();
}

Schedulable schedulableJob;
String name;
if(JOB == 'watchdog')
{
	kern.SCHED_ChainWatchdog watchdog = new kern.SCHED_ChainWatchdog();
	kern.DTO_NameValues attributes = new kern.DTO_NameValues();
	attributes.add('StaleThresholdMinutes', THRESHOLD);
	attributes.add('BatchSize', '50');
	watchdog.setParameterValues(attributes);
	schedulableJob = watchdog;
	name = 'Elastic Probe Watchdog ' + System.now().getTime();
}
else if(JOB == 'outboundWatchdog')
{
	kern.SCHED_OutboundRetryWatchdog outboundWatchdog = new kern.SCHED_OutboundRetryWatchdog();
	kern.DTO_NameValues attributes = new kern.DTO_NameValues();
	attributes.add('StaleThresholdMinutes', THRESHOLD);
	attributes.add('BatchSize', '50');
	outboundWatchdog.setParameterValues(attributes);
	schedulableJob = outboundWatchdog;
	name = 'Elastic Probe Outbound Retry Watchdog ' + System.now().getTime();
}
else
{
	schedulableJob = new kern.SCHED_JobRunner();
	name = 'Elastic Probe Runner Check ' + System.now().getTime();
}
Id cronId = System.schedule(name, cron, schedulableJob);
System.debug('PROBE SCHEDULE ONCE name=' + name + ' cronId=' + cronId + ' fireAt=' + fireAt.format(TIME_FORMAT, TIME_ZONE) + ' cron=' + cron
		+ ' threshold=' + THRESHOLD);
