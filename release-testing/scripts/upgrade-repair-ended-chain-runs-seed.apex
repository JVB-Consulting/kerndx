/**
 * Upgrade leg, chain run repair, before the upgrade: leave two chain runs at Stalled with an end time
 *
 * Run on the 1.7.0-13 install, before the 1.8 upgrade. An earlier version could overwrite a finished run's status with
 * Stalled when it could not start the run's completion or error handler, leaving a Stalled run with an end time. From
 * 1.8 the framework refuses to save such a row, so it can only be made here, on 1.7, by a direct insert. Two rows:
 *   - UpgradeRepairSeed_AllSucceeded: every step in its step log succeeded; the repair script sets it to Completed.
 *   - UpgradeRepairSeed_StepFailed: its second step failed; the repair script sets it to Failed (Step Exception).
 * Both keep the end time set here (1 September 2026, 12:00 UTC); the verify script checks it did not move. Every field
 * written here exists on 1.7.0-13.
 *
 * After the upgrade: run upgrade-repair-ended-chain-runs.apex (the release note's script, byte for byte), then
 * upgrade-repair-ended-chain-runs-verify.apex.
 *
 * Run:
 *   sf apex run --file release-testing/scripts/upgrade-repair-ended-chain-runs-seed.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */
Datetime endedAt = Datetime.newInstanceGmt(2026, 9, 1, 12, 0, 0);
String seedStamp = String.valueOf(Datetime.now().getTime());
List<Map<String, Object>> allSucceeded = new List<Map<String, Object>>
{
		new Map<String, Object> {'className' => 'SeedValidate', 'stepName' => 'Validate', 'success' => true},
		new Map<String, Object> {'className' => 'SeedLoad', 'stepName' => 'Load', 'success' => true}
};
List<Map<String, Object>> stepFailed = new List<Map<String, Object>>
{
		new Map<String, Object> {'className' => 'SeedValidate', 'stepName' => 'Validate', 'success' => true},
		new Map<String, Object> {'className' => 'SeedLoad', 'stepName' => 'Load', 'success' => false}
};
List<kern__AsyncChainExecution__c> seeds = new List<kern__AsyncChainExecution__c>
{
		new kern__AsyncChainExecution__c(
				kern__ChainName__c = 'UpgradeRepairSeed_AllSucceeded',
				kern__Status__c = 'Stalled',
				kern__FailureCategory__c = 'Stalled',
				kern__StartedAt__c = endedAt.addMinutes(-5),
				kern__CompletedAt__c = endedAt,
				kern__TotalSteps__c = 2,
				kern__CompletedSteps__c = 2,
				kern__StepLog__c = JSON.serialize(allSucceeded),
				kern__ErrorMessage__c = 'Completion handler could not be queued',
				kern__CorrelationId__c = 'RepairSeedA-' + seedStamp,
				kern__ActiveDeduplicationKey__c = 'UpgradeRepairSeed-AllSucceeded-' + seedStamp
		),
		new kern__AsyncChainExecution__c(
				kern__ChainName__c = 'UpgradeRepairSeed_StepFailed',
				kern__Status__c = 'Stalled',
				kern__FailureCategory__c = 'Stalled',
				kern__StartedAt__c = endedAt.addMinutes(-5),
				kern__CompletedAt__c = endedAt,
				kern__TotalSteps__c = 2,
				kern__CompletedSteps__c = 1,
				kern__StepLog__c = JSON.serialize(stepFailed),
				kern__ErrorMessage__c = 'Error handler could not be queued',
				kern__CorrelationId__c = 'RepairSeedB-' + seedStamp,
				kern__ActiveDeduplicationKey__c = 'UpgradeRepairSeed-StepFailed-' + seedStamp
		)
};
insert seeds;
System.debug(LoggingLevel.ERROR, 'REPAIRSEED rows=' + seeds.size() + ' ' + JSON.serialize(seeds));
