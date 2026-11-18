// Watchdog automation probe: what one pass of the chain watchdog did to the rows seed-stuck-runs.apex made.
// Run it in its own anonymous run, after the pass's scheduled job has finished and its log entries have arrived.
// Log entries come from a platform event, so they reach the org a little after the pass: wait two minutes first.
// It counts what the pass wrote, not what came after it. A restarted run's ChainExecutor runs after the pass, meets a
// step class this org does not have, and saves the row again, so status alone is not enough:
//   - restarted: RunKey__c or CurrentJobId__c is not the value seeded. Only a restart changes them.
//   - ended: Failed, and the reason starts with "Recovery stopped at step".
//   - parked: Stalled, with a reason the seed did not write (the watchdog left it for a later pass).
//   - untouched: Stalled, no reason, the seeded RunKey__c and CurrentJobId__c, and never saved again.
// Anything else is counted as other and printed, so a surprise is never hidden.
// It also prints the pass's own log entries (the restart and sweep entries and the stall entries), the Limits__c of the
// last one, and the scheduled job's Status and ExtendedStatus. A pass that throws System.LimitException leaves only the
// entries made before the throw; then the job's Status and ExtendedStatus show the throw.
// When the org has the stall time field (StalledAt__c, from Kern 1.12), each surprise row prints it too.
// Tokens (filled by probe.js):
//   __SEEDED__     the rows as they were just before the pass, as id=runKey=jobId, separated by semicolons
//   __CRON_ID__    the CronTrigger id that schedule-watchdog-once.apex printed for this pass
//   __SINCE__      the pass's start window in GMT, yyyy-MM-ddTHH:mm:ssZ; log entries and jobs from then on are read
//   __NAMESPACE__  the package's field prefix, for example kern__ (empty on an org without a namespace)
String seededText = '__SEEDED__';
String cronId = '__CRON_ID__';
Datetime since = (Datetime) JSON.deserialize('"__SINCE__"', Datetime.class);
String startedStepReasonStart = 'Recovery stopped at step';
Map<Id, String> seededRunKeyById = new Map<Id, String>();
Map<Id, String> seededJobIdById = new Map<Id, String>();
for(String seededRow : seededText.split(';'))
{
	List<String> parts = seededRow.split('=', -1);
	// An empty part stands for a field the seed left blank; compare it as null, since a blank text field reads back as null.
	seededRunKeyById.put((Id) parts[0], String.isEmpty(parts[1]) ? null : parts[1]);
	seededJobIdById.put((Id) parts[0], String.isEmpty(parts[2]) ? null : parts[2]);
}
Integer restarted = 0;
Integer ended = 0;
Integer parked = 0;
Integer untouched = 0;
Integer other = 0;
Map<String, Integer> reasonCounts = new Map<String, Integer>();
// The stall time field exists only from Kern 1.12, so the query is built at run time and names it only when it exists.
String stalledAtField = '__NAMESPACE__StalledAt__c';
Boolean hasStalledAtField = false;
for(String fieldName : __NAMESPACE__AsyncChainExecution__c.SObjectType.getDescribe().fields.getMap().keySet())
{
	hasStalledAtField = hasStalledAtField || fieldName.equalsIgnoreCase(stalledAtField);
}
List<String> fieldNames = new List<String> {
		'Id', '__NAMESPACE__Status__c', '__NAMESPACE__RunKey__c', '__NAMESPACE__CurrentJobId__c', '__NAMESPACE__ErrorMessage__c',
		'__NAMESPACE__CompletedAt__c', 'CreatedDate', 'LastModifiedDate'
};
if(hasStalledAtField)
{
	fieldNames.add(stalledAtField);
}
Set<Id> seededIds = seededRunKeyById.keySet();
String rowQuery = 'SELECT ' + String.join(fieldNames, ', ') + ' FROM __NAMESPACE__AsyncChainExecution__c WHERE Id IN :seededIds';
for(__NAMESPACE__AsyncChainExecution__c row : (List<__NAMESPACE__AsyncChainExecution__c>) Database.query(rowQuery))
{
	Boolean keyChanged = row.__NAMESPACE__RunKey__c != seededRunKeyById.get(row.Id) || row.__NAMESPACE__CurrentJobId__c != seededJobIdById.get(row.Id);
	String reason = row.__NAMESPACE__ErrorMessage__c;
	String reasonKey = row.__NAMESPACE__Status__c + ' | ' + (reason == null ? '(no reason)' : reason.left(90));
	reasonCounts.put(reasonKey, (reasonCounts.containsKey(reasonKey) ? reasonCounts.get(reasonKey) : 0) + 1);
	// Ending a run Failed also clears CurrentJobId__c, so the ended check comes before the restarted check.
	if(row.__NAMESPACE__Status__c == 'Failed' && reason != null && reason.startsWith(startedStepReasonStart))
	{
		ended++;
	}
	else if(keyChanged)
	{
		restarted++;
	}
	else if(row.__NAMESPACE__Status__c == 'Stalled' && String.isNotBlank(reason))
	{
		parked++;
	}
	else if(row.__NAMESPACE__Status__c == 'Stalled' && String.isBlank(reason) && row.LastModifiedDate == row.CreatedDate)
	{
		untouched++;
	}
	else
	{
		other++;
		System.debug('PROBE_OTHER id=' + row.Id + ' status=' + row.__NAMESPACE__Status__c + ' completedAt=' + row.__NAMESPACE__CompletedAt__c
				+ (hasStalledAtField ? ' stalledAt=' + row.get(stalledAtField) : '') + ' modified=' + row.LastModifiedDate + ' created=' + row.CreatedDate
				+ ' reason=' + reason);
	}
}
System.debug('PROBE_OUTCOME rows=' + seededRunKeyById.size() + ' restarted=' + restarted + ' ended=' + ended + ' parked=' + parked + ' untouched='
		+ untouched + ' other=' + other);
for(String reasonKey : reasonCounts.keySet())
{
	System.debug('PROBE_REASON count=' + reasonCounts.get(reasonKey) + ' ' + reasonKey);
}
for(AsyncApexJob job : [
		SELECT Id, JobType, Status, ExtendedStatus, NumberOfErrors, CreatedDate, CompletedDate
		FROM AsyncApexJob
		WHERE CronTriggerId = :cronId
])
{
	System.debug('PROBE_JOB id=' + job.Id + ' type=' + job.JobType + ' status=' + job.Status + ' errors=' + job.NumberOfErrors + ' created='
			+ job.CreatedDate + ' completed=' + job.CompletedDate + ' extendedStatus=' + job.ExtendedStatus);
}
Integer queuedAfter = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable' AND CreatedDate >= :since];
System.debug('PROBE_QUEUEABLES since=' + since + ' count=' + queuedAfter);
List<__NAMESPACE__LogEntry__c> entries = [
		SELECT Id, __NAMESPACE__Source__c, __NAMESPACE__ClassMethod__c, __NAMESPACE__LogLevel__c, __NAMESPACE__ShortMessage__c, __NAMESPACE__Limits__c,
				__NAMESPACE__TransactionId__c, CreatedDate
		FROM __NAMESPACE__LogEntry__c
		WHERE CreatedDate >= :since
		ORDER BY CreatedDate ASC, Id ASC
];
Map<String, Integer> entryCountBySource = new Map<String, Integer>();
__NAMESPACE__LogEntry__c lastPassEntry;
// Entries of one transaction often share a CreatedDate, so the order above is not always the order of the pass.
// The entry with the most queries used is the latest point of the pass that the log shows.
__NAMESPACE__LogEntry__c mostQueriesEntry;
Integer mostQueries = -1;
Pattern queriesPattern = Pattern.compile('(?m)^Queries: (\\d+) of');
for(__NAMESPACE__LogEntry__c entry : entries)
{
	String source = entry.__NAMESPACE__Source__c + ' / ' + entry.__NAMESPACE__ClassMethod__c;
	entryCountBySource.put(source, (entryCountBySource.containsKey(source) ? entryCountBySource.get(source) : 0) + 1);
	String sourceText = (entry.__NAMESPACE__Source__c + ' ' + entry.__NAMESPACE__ClassMethod__c).toLowerCase();
	if(sourceText.contains('redrivestalledchain') || sourceText.contains('runwatchdogsweep') || sourceText.contains('stall'))
	{
		lastPassEntry = entry;
		Matcher queriesMatcher = queriesPattern.matcher(entry.__NAMESPACE__Limits__c == null ? '' : entry.__NAMESPACE__Limits__c);
		if(queriesMatcher.find() && Integer.valueOf(queriesMatcher.group(1)) > mostQueries)
		{
			mostQueries = Integer.valueOf(queriesMatcher.group(1));
			mostQueriesEntry = entry;
		}
	}
}
System.debug('PROBE_LOGS entries=' + entries.size());
for(String source : entryCountBySource.keySet())
{
	System.debug('PROBE_LOG_SOURCE count=' + entryCountBySource.get(source) + ' ' + source);
}
if(lastPassEntry != null)
{
	System.debug('PROBE_LAST_ENTRY source=' + lastPassEntry.__NAMESPACE__Source__c + ' method=' + lastPassEntry.__NAMESPACE__ClassMethod__c + ' level='
			+ lastPassEntry.__NAMESPACE__LogLevel__c + ' transaction=' + lastPassEntry.__NAMESPACE__TransactionId__c + ' message=' + lastPassEntry.__NAMESPACE__ShortMessage__c);
	// Limits__c holds one limit per line; join them so the whole value prints on one debug line.
	System.debug('PROBE_LAST_LIMITS ' + (lastPassEntry.__NAMESPACE__Limits__c == null ? null : lastPassEntry.__NAMESPACE__Limits__c.replace('\n', ' | ')));
}
if(mostQueriesEntry != null)
{
	System.debug('PROBE_MOST_QUERIES queries=' + mostQueries + ' method=' + mostQueriesEntry.__NAMESPACE__ClassMethod__c + ' message='
			+ mostQueriesEntry.__NAMESPACE__ShortMessage__c);
	System.debug('PROBE_MOST_QUERIES_LIMITS ' + mostQueriesEntry.__NAMESPACE__Limits__c.replace('\n', ' | '));
}
