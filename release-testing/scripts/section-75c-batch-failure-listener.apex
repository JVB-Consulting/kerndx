/**
 * Section 75c: Batch failure log and batch size from the job setting (Launch)
 *
 * Starts two batch jobs over 290 Foobar rows seeded here; section 75d checks what they left about 60 seconds later.
 *
 *   1. TST_RaisingBatch, started straight through Database.executeBatch with a size of 75. It opts into failure events
 *      (Database.RaisesPlatformEvents) and throws in every execute() call, so the platform publishes one
 *      BatchApexErrorEvent per failed call. The framework's trigger on that event (TRG_LogBatchApexError) writes one ERROR
 *      log entry per failure, filed under TST_RaisingBatch/execute, linked to the job, with the phase in its context.
 *   2. TST_SizeProbeHandler, started through kern.UTIL_AsynchronousJobLauncher.process as a query-backed batch with no
 *      size set in code. The framework reads the size from the kern__AsynchronousJobSetting__mdt record named after the
 *      class (TST_SizeProbeHandler, 75). A query-backed batch reads its rows in chunks of 100 at that size, and 75 does
 *      not divide 100, so the launch writes one WARN naming size 75, the chunk of 100 and the short run of 25 rows.
 *
 * The WARN is grouped under a fixed key (flood control): the first WARN of a day writes a sample row and a daily counter
 * row, and a later one adds to the counter. So 75d reads only the rows under that key changed at or after this run's
 * start time, never a row an earlier run left. This script first deletes the Foobar rows of an earlier run, then saves
 * a handoff row (a kern__Foobar__c named Section75cHandoff_...) carrying both job ids and the start time.
 *
 * Prerequisites:
 *   - subscriber scratch org with the kern managed package installed
 *   - TST_RaisingBatch, TST_SizeProbeHandler and the kern__AsynchronousJobSetting.TST_SizeProbeHandler record deployed
 *
 * Run (in two stages, about 60 seconds apart):
 *   sf apex run --file release-testing/scripts/section-75c-batch-failure-listener.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *   (wait about 60 seconds for both jobs to finish and the log entries to arrive)
 *   sf apex run --file release-testing/scripts/section-75d-batch-failure-listener-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

final String ROW_NAME_PREFIX = 'Section75cRow_';
final String HANDOFF_NAME_PREFIX = 'Section75cHandoff_';
final Integer ROW_COUNT = 290;
final Integer RAISING_BATCH_SIZE = 75;
final String BATCH_JOB_TYPE = 'BatchApex';

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 75c: Batch failure log and batch size from the job setting (Launch) ===');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

delete [SELECT Id FROM kern__Foobar__c WHERE Name LIKE :(ROW_NAME_PREFIX + '%') OR Name LIKE :(HANDOFF_NAME_PREFIX + '%')];

List<kern__Foobar__c> rows = new List<kern__Foobar__c>();
for(Integer index = 0; index < ROW_COUNT; index++)
{
	rows.add(new kern__Foobar__c(Name = ROW_NAME_PREFIX + String.valueOf(index).leftPad(3, '0'), kern__Checkbox__c = false));
}
insert rows;

Datetime launchedAt = Datetime.now();
Id raisingJobId = null;
Id launcherJobId = null;

// 75c-raising: the failing batch is started and the platform has a BatchApex job for it.
try
{
	raisingJobId = Database.executeBatch(new TST_RaisingBatch(ROW_NAME_PREFIX), RAISING_BATCH_SIZE);
	AsyncApexJob job = [SELECT Id, JobType FROM AsyncApexJob WHERE Id = :raisingJobId];
	Assert.areEqual(BATCH_JOB_TYPE, job.JobType, '75c-raising: Expected a BatchApex job for TST_RaisingBatch');
	System.debug(LoggingLevel.INFO, '75c-raising PASS: started TST_RaisingBatch over ' + ROW_COUNT + ' rows at size ' + RAISING_BATCH_SIZE
			+ ' (job ' + raisingJobId + ')');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '75c-raising FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('75c-raising: ' + scenarioError.getMessage());
	fail++;
}

// 75c-launcher: the framework starts the size probe as a query-backed batch with no size set in code, so the size
// comes from the job setting named after TST_SizeProbeHandler.
try
{
	kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
			new kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(
					kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType)
							.fields(new List<SObjectField> {kern__Foobar__c.Name, kern__Foobar__c.kern__Checkbox__c})
							.condition(kern__Foobar__c.Name).startsWith(ROW_NAME_PREFIX)
			).withExecutionStrategy(kern.IF_Async.AsynchronousExecutionStrategy.BATCH);
	launcherJobId = kern.UTIL_AsynchronousJobLauncher.process(request, new TST_SizeProbeHandler());
	AsyncApexJob job = [SELECT Id, JobType FROM AsyncApexJob WHERE Id = :launcherJobId];
	Assert.areEqual(BATCH_JOB_TYPE, job.JobType, '75c-launcher: Expected the launcher to start a BatchApex job');
	System.debug(LoggingLevel.INFO, '75c-launcher PASS: the launcher started TST_SizeProbeHandler as a batch (job ' + launcherJobId + ')');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '75c-launcher FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('75c-launcher: ' + scenarioError.getMessage());
	fail++;
}

insert new kern__Foobar__c(
		Name = HANDOFF_NAME_PREFIX + launchedAt.getTime(),
		kern__TextAreaLong__c = JSON.serialize(new Map<String, Object>
		{
				'raisingJobId' => raisingJobId,
				'launcherJobId' => launcherJobId,
				'launchedAt' => launchedAt,
				'rowNamePrefix' => ROW_NAME_PREFIX,
				'rowCount' => ROW_COUNT
		})
);

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 75c (Launch): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 75c (Launch) failed: ' + fail + ' scenarios');
}
