/**
 * Section 76d: Data Masking Advisor Round-Trip — Verify RE-ENABLE
 *
 * Runs after run-phase2.js runSection76() deploys the `reenable` bundle from
 * e2e/fixtures/masking-advisor-bundles/ — the advisor Export modal's "Re-enable" verb,
 * re-emitting ONLY the healthy probe with IsActive__c=true (the dead-config probe stays
 * disabled). Proves:
 *
 *   76h. Re-read — Case_All_Card_Probe flips back to active while Case_All_Email_DeadProbe
 *        remains inactive, AND the packaged MaskPhoneUS rule stays dormant: a bundle touches
 *        exactly the records it carries, nothing else. The re-enable bundle carries only the
 *        healthy probe — neither the dead probe nor the MaskPhoneUS activation (both last set
 *        by the disable deploy) may move.
 *
 *   76i. Posture recompute — Case rejoins the masked-object set (4 -> 5) with one
 *        object-wide target more than baseline (12 -> 13) and ZERO dead configs — distinct
 *        from the create state (5 objects / 14 object-wide / 1 dead), so the three deploys
 *        produce three distinguishable postures.
 *        HEALTH CHECK INPUT: deadConfigCount=0, objectsWithActiveTargets=5 => the
 *        masking-posture check computes Pass(5) — a PASS-branch value change from the
 *        baseline's Pass(4). Together with 76e's Warn flip this covers every branch of the
 *        masking-posture Health Check from configuration changes alone.
 *
 * Run-isolation: read-only (SOQL). The runner deploys the disable bundle again right after
 * this script (final cleanup) and re-verifies with section-76c, leaving the org at the
 * baseline steady state.
 *
 * Run (in isolation, after deploying the reenable bundle):
 *   sf apex run --file release-testing/scripts/section-76d-masking-advisor-verify-reenabled.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock: <3 seconds (2 SOQL queries).
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 76d: Masking Advisor Round-Trip — Verify RE-ENABLE ===');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

// Scenario 76h — the re-enable bundle touches only the record it carries.
try
{
	Map<String, kern__MaskingTarget__mdt> probesByName = new Map<String, kern__MaskingTarget__mdt>();
	for(kern__MaskingTarget__mdt probe :
	[
			SELECT DeveloperName,
					kern__IsActive__c,
					kern__Rule__r.DeveloperName,
					kern__Rule__r.kern__IsActive__c
			FROM kern__MaskingTarget__mdt
			WHERE DeveloperName IN ('Case_All_Card_Probe', 'Case_All_Email_DeadProbe')
	])
	{
		probesByName.put(probe.DeveloperName, probe);
	}

	Assert.areEqual(2, probesByName.size(),
			'76h: both probe records must still exist. Found: ' + probesByName.keySet());
	Assert.isTrue(probesByName.get('Case_All_Card_Probe').kern__IsActive__c == true,
			'76h: Case_All_Card_Probe must be active again after the re-enable deploy');
	Assert.areEqual('MaskCreditCard', probesByName.get('Case_All_Card_Probe').kern__Rule__r.DeveloperName,
			'76h: the re-enabled probe must still bind MaskCreditCard');
	Assert.isTrue(probesByName.get('Case_All_Email_DeadProbe').kern__IsActive__c != true,
			'76h: Case_All_Email_DeadProbe must REMAIN inactive — the re-enable bundle does not carry '
			+ 'it, and a deploy must only touch the records in its package.xml');

	List<kern__MaskingRule__mdt> phoneRules =
	[
			SELECT DeveloperName,
					kern__IsActive__c
			FROM kern__MaskingRule__mdt
			WHERE DeveloperName = 'MaskPhoneUS'
	];
	Assert.areEqual(1, phoneRules.size(),
			'76h: exactly one packaged MaskPhoneUS rule must exist. Got: ' + phoneRules.size());
	Assert.isTrue(phoneRules[0].kern__IsActive__c != true,
			'76h: MaskPhoneUS must REMAIN dormant — the re-enable bundle does not carry the rule activation, '
			+ 'so the deploy leaves the packaged rule exactly as the disable deploy left it '
			+ '(bundle-scoped upserts touch only carried records)');

	System.debug(LoggingLevel.INFO,
			'76h PASS: re-enable bundle round-tripped — Case_All_Card_Probe active again, the '
			+ 'dead-config probe untouched (still inactive). CONTRACT: a bundle deploy upserts exactly '
			+ 'the records it carries — the dead-config probe and the packaged MaskPhoneUS rule both stayed put.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '76h FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('76h: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 76i — posture lands on the third distinct state: Pass(5).
try
{
	List<kern__MaskingTarget__mdt> targets =
	[
			SELECT DeveloperName,
					kern__IsActive__c,
					kern__Field__c,
					kern__SObjectType__c,
					kern__Rule__c,
					kern__Rule__r.DeveloperName,
					kern__Rule__r.kern__IsActive__c
			FROM kern__MaskingTarget__mdt
	];

	Set<String> activeObjectIdentifiers = new Set<String>();
	Integer objectWideCount = 0;
	Integer fieldLevelCount = 0;
	Integer deadCount = 0;
	List<String> deadTargetNames = new List<String>();

	for(kern__MaskingTarget__mdt target : targets)
	{
		if(target.kern__IsActive__c != true)
		{
			continue;
		}
		activeObjectIdentifiers.add(target.kern__SObjectType__c);
		if(String.isBlank(target.kern__Field__c))
		{
			objectWideCount++;
		}
		else
		{
			fieldLevelCount++;
		}
		if(target.kern__Rule__c == null || target.kern__Rule__r == null || target.kern__Rule__r.kern__IsActive__c != true)
		{
			deadCount++;
			deadTargetNames.add(target.DeveloperName);
		}
	}

	Assert.areEqual(5, activeObjectIdentifiers.size(),
			'76i: Case must rejoin the masked-object set — 4 baseline objects + Case = 5. Got '
			+ activeObjectIdentifiers.size() + ': ' + activeObjectIdentifiers);
	Assert.isTrue(activeObjectIdentifiers.contains('Case'),
			'76i: the masked-object set must contain Case. Got: ' + activeObjectIdentifiers);
	Assert.areEqual(13, objectWideCount,
			'76i: only the healthy probe re-enabled — 12 baseline + 1 = 13 object-wide. Got: ' + objectWideCount);
	Assert.areEqual(1, fieldLevelCount,
			'76i: the harness field-level target must be untouched. Got: ' + fieldLevelCount);
	Assert.areEqual(0, deadCount,
			'76i: no dead configuration — the dead probe stayed disabled. Dead: ' + deadTargetNames);

	System.debug(LoggingLevel.INFO,
			'76i PASS: posture recomputed to the third distinct state — 5 masked objects / 13 object-wide / '
			+ '1 field-level / 0 dead. HEALTH CHECK INPUT: deadConfigCount=0 and '
			+ 'objectsWithActiveTargets=5 => masking-posture computes Pass(5), a PASS-branch value '
			+ 'change from the baseline Pass(4). With 76e\'s Warn flip, configuration changes alone '
			+ 'have now exercised every branch of the masking-posture Health Check.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '76i FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('76i: ' + scenarioError.getMessage());
	fail++;
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 76d (verify re-enable): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 76d (verify re-enable) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 76d (verify re-enable) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 76d (verify re-enable) COMPLETE: All scenarios passed ===');
}
