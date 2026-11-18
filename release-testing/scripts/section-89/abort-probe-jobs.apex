// Runbook section 89: stop the background jobs that a run of the section left waiting, and say which have not ended.
// These are the jobs of Kern's adaptive processor and the jobs of the probe's own classes (such as the filler jobs a
// spend queues), so no job of the probe runs after the clean-up and none runs while its class is deleted.
//
// Tokens:
//   __JOB_ID__  the id of one job (an AsyncApexJob id): the chain's first job, which launch-adaptive-processor.apex
//               printed. Or all: every job of Kern's own UTIL_AdaptiveAsynchronousProcessor class that has not ended.
//               --restore-only uses all, because it has no run to read an id from. Kern's namespace on the org comes
//               from a Kern class name, so a class of the same name outside the package is never stopped. Or none: the
//               run launched no chain, so only the probe's own jobs are looked at.
//   __ACTION__  abort: stop each such job that waits at Queued, Holding or Preparing, then list the jobs. read: only
//               list them. The driver runs abort and then read, in a second transaction, to prove each job ended.
//
// Every job of a probe class (a class with no namespace whose name starts with ElasticProbe) that has not ended is
// always looked at too, whatever __JOB_ID__ says.
// A job at Processing is already running, so it is not stopped: it is listed and counted as not ended.
// Prints one line per job found: PROBE STOP JOB id=<id> status=<status> aborted=<true or false> class=<class>,
// then one summary line: PROBE STOP JOBS action=<abort or read> found=<number of jobs found> aborted=<number
// stopped> left=<number not ended>. Both lines give the status read before any stop; the read in the second
// transaction shows the status after it. A probe job that has ended is not found again, so after a stop it is not listed.
//
// Run: sf apex run -o <org alias> -f <rendered copy with the tokens replaced> --json > <file>
final String JOB_ID = '__JOB_ID__';
final String ACTION = '__ACTION__';
final String EVERY_JOB = 'all';
final String NO_JOB = 'none';
final String PROCESSOR_CLASS = 'UTIL_AdaptiveAsynchronousProcessor';
final String PROBE_CLASS_PATTERN = 'ElasticProbe%';
final Set<String> WAITING_STATUSES = new Set<String> {'Queued', 'Holding', 'Preparing'};
final Set<String> LIVE_STATUSES = new Set<String> {'Queued', 'Holding', 'Preparing', 'Processing'};

String launcherName = kern.UTIL_AsynchronousJobLauncher.class.getName();
String namespacePrefix = launcherName.contains('.') ? launcherName.substringBefore('.') : null;
List<AsyncApexJob> jobs = new List<AsyncApexJob>();
if(JOB_ID == EVERY_JOB)
{
	jobs.addAll([SELECT Id, Status, ApexClass.Name FROM AsyncApexJob
			WHERE ApexClass.Name = :PROCESSOR_CLASS AND ApexClass.NamespacePrefix = :namespacePrefix AND Status IN :LIVE_STATUSES]);
}
else if(JOB_ID != NO_JOB)
{
	jobs.addAll([SELECT Id, Status, ApexClass.Name FROM AsyncApexJob WHERE Id = :JOB_ID]);
}
jobs.addAll([SELECT Id, Status, ApexClass.Name FROM AsyncApexJob
		WHERE ApexClass.Name LIKE :PROBE_CLASS_PATTERN AND Status IN :LIVE_STATUSES]);
Integer aborted = 0;
Integer left = 0;
for(AsyncApexJob job : jobs)
{
	Boolean stopped = false;
	if(ACTION == 'abort' && WAITING_STATUSES.contains(job.Status))
	{
		System.abortJob(job.Id);
		stopped = true;
		aborted++;
	}
	if(LIVE_STATUSES.contains(job.Status))
	{
		left++;
	}
	System.debug('PROBE STOP JOB id=' + job.Id + ' status=' + job.Status + ' aborted=' + stopped + ' class=' + job.ApexClass?.Name);
}
System.debug('PROBE STOP JOBS action=' + ACTION + ' found=' + jobs.size() + ' aborted=' + aborted + ' left=' + left);
