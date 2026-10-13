/**
 * Upgrade leg, chain run repair, after the release note's repair script: two runs repaired, end times kept, a direct edit refused
 *
 * Run on the upgraded org after upgrade-repair-ended-chain-runs.apex (which should have printed two Repaired lines).
 * Checks, one PASS or FAIL line each:
 *   - repair-a: UpgradeRepairSeed_AllSucceeded reads Completed, with no failure category, no active deduplication key,
 *     its end time unchanged and a message that starts "Repaired on".
 *   - repair-b: UpgradeRepairSeed_StepFailed reads Failed with the StepException failure category, no active
 *     deduplication key, its end time unchanged and a message that starts "Repaired on".
 *   - repair-backstop: a direct edit moving the Completed run back to Running is refused, with the package's
 *     AsyncChain_TransitionRefused message ("This chain run cannot move from Completed to Running.").
 * Then deletes both rows. The refused edit also writes one ERROR log entry starting "Chain run status write refused by
 * the backstop"; it is left in the Log Console as the record of the check.
 *
 * Run:
 *   sf apex run --file release-testing/scripts/upgrade-repair-ended-chain-runs-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */
final Datetime SEEDED_END_TIME = Datetime.newInstanceGmt(2026, 9, 1, 12, 0, 0);
final String REPAIRED_PREFIX = 'Repaired on ';

Map<String, kern__AsyncChainExecution__c> runByChainName = new Map<String, kern__AsyncChainExecution__c>();
for(kern__AsyncChainExecution__c run :
[
		SELECT Id,
				kern__ChainName__c,
				kern__Status__c,
				kern__FailureCategory__c,
				kern__CompletedAt__c,
				kern__ActiveDeduplicationKey__c,
				kern__ErrorMessage__c
		FROM kern__AsyncChainExecution__c
		WHERE kern__ChainName__c IN ('UpgradeRepairSeed_AllSucceeded', 'UpgradeRepairSeed_StepFailed')
])
{
	runByChainName.put(run.kern__ChainName__c, run);
}
System.debug(LoggingLevel.ERROR, 'REPAIRSEED after script ' + JSON.serialize(runByChainName.values()));

kern__AsyncChainExecution__c succeeded = runByChainName.get('UpgradeRepairSeed_AllSucceeded');
try
{
	Assert.isNotNull(succeeded, 'Expected the UpgradeRepairSeed_AllSucceeded row; run the seed on 1.7 before the upgrade');
	Assert.areEqual('Completed', succeeded.kern__Status__c, 'Expected Completed');
	Assert.isNull(succeeded.kern__FailureCategory__c, 'Expected no failure category');
	Assert.isNull(succeeded.kern__ActiveDeduplicationKey__c, 'Expected no active deduplication key');
	Assert.areEqual(SEEDED_END_TIME, succeeded.kern__CompletedAt__c, 'Expected the end time unchanged');
	Assert.isTrue(succeeded.kern__ErrorMessage__c.startsWith(REPAIRED_PREFIX), 'Expected the message to start "Repaired on", got ' + succeeded.kern__ErrorMessage__c);
	System.debug(LoggingLevel.ERROR, 'REPAIRSEED repair-a PASS: the all-succeeded run reads Completed, end time kept');
}
catch(Exception checkError)
{
	System.debug(LoggingLevel.ERROR, 'REPAIRSEED repair-a FAIL: ' + checkError.getMessage());
}

kern__AsyncChainExecution__c failed = runByChainName.get('UpgradeRepairSeed_StepFailed');
try
{
	Assert.isNotNull(failed, 'Expected the UpgradeRepairSeed_StepFailed row; run the seed on 1.7 before the upgrade');
	Assert.areEqual('Failed', failed.kern__Status__c, 'Expected Failed');
	Assert.areEqual('StepException', failed.kern__FailureCategory__c, 'Expected the StepException failure category');
	Assert.isNull(failed.kern__ActiveDeduplicationKey__c, 'Expected no active deduplication key');
	Assert.areEqual(SEEDED_END_TIME, failed.kern__CompletedAt__c, 'Expected the end time unchanged');
	Assert.isTrue(failed.kern__ErrorMessage__c.startsWith(REPAIRED_PREFIX), 'Expected the message to start "Repaired on", got ' + failed.kern__ErrorMessage__c);
	System.debug(LoggingLevel.ERROR, 'REPAIRSEED repair-b PASS: the step-failed run reads Failed (StepException), end time kept');
}
catch(Exception checkError)
{
	System.debug(LoggingLevel.ERROR, 'REPAIRSEED repair-b FAIL: ' + checkError.getMessage());
}

try
{
	Assert.isNotNull(succeeded, 'Expected the Completed run from repair-a to try the edit on');
	String expectedMessage = String.format(System.Label.kern.AsyncChain_TransitionRefused, new List<String> {'Completed', 'Running'});
	try
	{
		update new kern__AsyncChainExecution__c(Id = succeeded.Id, kern__Status__c = 'Running');
		Assert.fail('Expected the move from Completed to Running to be refused');
	}
	catch(DmlException refusal)
	{
		Assert.isTrue(refusal.getMessage().contains(expectedMessage), 'Expected "' + expectedMessage + '", got ' + refusal.getMessage());
	}
	System.debug(LoggingLevel.ERROR, 'REPAIRSEED repair-backstop PASS: the direct edit was refused with "' + expectedMessage + '"');
}
catch(Exception checkError)
{
	System.debug(LoggingLevel.ERROR, 'REPAIRSEED repair-backstop FAIL: ' + checkError.getMessage());
}

delete runByChainName.values();
System.debug(LoggingLevel.ERROR, 'REPAIRSEED left=' + [SELECT COUNT() FROM kern__AsyncChainExecution__c WHERE kern__ChainName__c LIKE 'UpgradeRepairSeed_%']);
