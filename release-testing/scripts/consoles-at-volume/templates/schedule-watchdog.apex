// Consoles at volume: the real watchdog on the platform scheduler for a run, twelve recurring jobs at five-minute
// offsets (the minutes field of a cron takes no step), each with the run's stale threshold.
// Tokens: __APEX_NAMESPACE__ __THRESHOLD_MINUTES__ __JOB_NAME_PREFIX__
Integer scheduled = 0;
for(Integer minute = 0; minute < 60; minute += 5)
{
	__APEX_NAMESPACE__SCHED_ChainWatchdog job = new __APEX_NAMESPACE__SCHED_ChainWatchdog();
	__APEX_NAMESPACE__DTO_NameValues attributes = new __APEX_NAMESPACE__DTO_NameValues();
	attributes.add('StaleThresholdMinutes', '__THRESHOLD_MINUTES__');
	attributes.add('BatchSize', '50');
	job.setParameterValues(attributes);
	System.schedule('__JOB_NAME_PREFIX__ ' + String.valueOf(minute).leftPad(2, '0'), '0 ' + minute + ' * * * ?', job);
	scheduled++;
}
System.debug('VOLUME_WATCHDOG scheduled=' + scheduled);
