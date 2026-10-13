// Consoles at volume: removes the run's watchdog jobs by their name prefix. Tokens: __JOB_NAME_PREFIX__
Integer aborted = 0;
for(CronTrigger job : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE '__JOB_NAME_PREFIX__%'])
{
	System.abortJob(job.Id);
	aborted++;
}
System.debug('VOLUME_WATCHDOG aborted=' + aborted);
