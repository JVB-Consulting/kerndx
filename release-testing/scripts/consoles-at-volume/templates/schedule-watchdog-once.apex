// Consoles at volume: one sweep of the real watchdog through the platform scheduler, 75 seconds out.
// Tokens: __APEX_NAMESPACE__ __THRESHOLD_MINUTES__ __JOB_NAME__ (filled by the runner).
__APEX_NAMESPACE__SCHED_ChainWatchdog job = new __APEX_NAMESPACE__SCHED_ChainWatchdog();
__APEX_NAMESPACE__DTO_NameValues attributes = new __APEX_NAMESPACE__DTO_NameValues();
attributes.add('StaleThresholdMinutes', '__THRESHOLD_MINUTES__');
attributes.add('BatchSize', '50');
job.setParameterValues(attributes);
Datetime fireAt = System.now().addSeconds(75);
String cron = '0 ' + fireAt.minute() + ' ' + fireAt.hour() + ' ' + fireAt.day() + ' ' + fireAt.month() + ' ? ' + fireAt.year();
System.debug('VOLUME_PROBE watchdog=' + System.schedule('__JOB_NAME__', cron, job) + ' fireAt=' + fireAt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
