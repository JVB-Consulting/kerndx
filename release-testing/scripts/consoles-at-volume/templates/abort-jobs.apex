// Consoles at volume: aborts queued jobs by id, what an administrator's Abort in Setup, Apex Jobs does. The rows keep
// their dead job ids and the scheduled watchdog re-drives them. Tokens: __JOB_IDS__ (a list literal's body).
Integer aborted = 0;
for(Id jobId : new List<Id> {__JOB_IDS__})
{
	System.abortJob(jobId);
	aborted++;
}
System.debug('VOLUME_ABORTED jobs=' + aborted);
