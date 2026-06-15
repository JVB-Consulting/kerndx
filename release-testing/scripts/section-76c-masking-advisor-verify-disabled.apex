/**
 * Section 76c: Data Masking Advisor Round-Trip — Verify DISABLE
 *
 * Runs after run-phase2.js runSection76() deploys the `disable` bundle from
 * e2e/fixtures/masking-advisor-bundles/ — the advisor Export modal's "Disable" verb,
 * which re-emits each target with IsActive__c=false (CustomMetadata deploys cannot
 * delete, so disabling IS the advisor's removal story). The runner also re-runs this
 * script as the final cleanup verification, proving the org is back at the baseline
 * steady state for whatever runs next. Proves:
 *
 *   76f. Re-read — both probe records persist in kern__MaskingTarget__mdt but are now
 *        inactive: the disable half of the advisor's diff round-trips.
 *
 *   76g. Posture recompute — all four counts return to baseline: Case leaves the
 *        masked-object set (5 -> 4), the probes stop counting object-wide (14 -> 12), and
 *        the dead config vanishes (1 -> 0) because an INACTIVE target bound to a dormant
 *        rule is not dead — it masks nothing by design.
 *        HEALTH CHECK INPUT: deadConfigCount=0, objectsWithActiveTargets=4 => the
 *        masking-posture check computes Pass(4) again, recovering from the WARN that the
 *        create deploy provoked.
 *
 *   76k. Rule-activation restored to dormant — the packaged MaskPhoneUS rule that 76j
 *        activated is back to inactive (still the single package-owned record). NOTE: the
 *        advisor itself only ever GENERATES activations; the disable bundle carries a
 *        deactivation override purely so this harness can restore the dormant steady state
 *        and keep re-runs idempotent (see the fixtures README). The baseline (76b) asserts
 *        MaskPhoneUS dormant before each run, so this is the matching teardown.
 *
 * Run-isolation: read-only (SOQL). State transitions are owned by the runner's bundle deploys.
 *
 * Run (in isolation, after deploying the disable bundle):
 *   sf apex run --file release-testing/scripts/section-76c-masking-advisor-verify-disabled.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock: <3 seconds (2 SOQL queries).
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 76c: Masking Advisor Round-Trip — Verify DISABLE ===');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

// Scenario 76f — both probes persist, now inactive.
try
{
	Map<String, kern__MaskingTarget__mdt> probesByName = new Map<String, kern__MaskingTarget__mdt>();
	for(kern__MaskingTarget__mdt probe :
	[
			SELECT DeveloperName,
					kern__IsActive__c,
					kern__Rule__r.DeveloperName
			FROM kern__MaskingTarget__mdt
			WHERE DeveloperName IN ('Case_All_Card_Probe', 'Case_All_Email_DeadProbe')
	])
	{
		probesByName.put(probe.DeveloperName, probe);
	}

	Assert.areEqual(2, probesByName.size(),
			'76f: both probe records must persist after the disable-bundle deploy — CustomMetadata '
			+ 'deploys upsert, never delete. Found: ' + probesByName.keySet());
	Assert.isTrue(probesByName.get('Case_All_Card_Probe').kern__IsActive__c != true,
			'76f: Case_All_Card_Probe must be inactive after the disable deploy');
	Assert.isTrue(probesByName.get('Case_All_Email_DeadProbe').kern__IsActive__c != true,
			'76f: Case_All_Email_DeadProbe must be inactive after the disable deploy');

	System.debug(LoggingLevel.INFO,
			'76f PASS: disable bundle round-tripped — both probes persist in kern__MaskingTarget__mdt '
			+ 'with IsActive__c=false. CONTRACT: the advisor\'s Disable verb is the removal story; '
			+ 'records stay, masking stops.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '76f FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('76f: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 76g — posture returns to baseline.
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

	Assert.areEqual(4, activeObjectIdentifiers.size(),
			'76g: Case must leave the masked-object set — back to the 4 baseline objects. Got '
			+ activeObjectIdentifiers.size() + ': ' + activeObjectIdentifiers);
	Assert.isFalse(activeObjectIdentifiers.contains('Case'),
			'76g: Case must not be in the masked-object set after disable. Got: ' + activeObjectIdentifiers);
	Assert.areEqual(12, objectWideCount,
			'76g: object-wide count must return to the 12 shipped targets. Got: ' + objectWideCount);
	Assert.areEqual(1, fieldLevelCount,
			'76g: the harness field-level target must be untouched. Got: ' + fieldLevelCount);
	Assert.areEqual(0, deadCount,
			'76g: no dead configuration — an INACTIVE target on a dormant rule is not dead (it masks '
			+ 'nothing by design). Dead: ' + deadTargetNames);

	System.debug(LoggingLevel.INFO,
			'76g PASS: posture recomputed back to baseline — 4 masked objects / 12 object-wide / '
			+ '1 field-level / 0 dead. HEALTH CHECK INPUT: deadConfigCount=0 and '
			+ 'objectsWithActiveTargets=4 => masking-posture computes Pass(4) again — the Health '
			+ 'Check recovers when the dead config is disabled.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '76g FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('76g: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 76k — the packaged MaskPhoneUS rule is dormant again after the disable deploy.
// The disable bundle carries a deactivation override (a harness-only artifact — the advisor
// generates activations, never deactivations) so the dormant steady state is restored and
// re-runs stay idempotent. Still exactly one package-owned record.
try
{
	List<kern__MaskingRule__mdt> phoneRules =
	[
			SELECT DeveloperName,
					NamespacePrefix,
					kern__IsActive__c
			FROM kern__MaskingRule__mdt
			WHERE DeveloperName = 'MaskPhoneUS'
	];

	Assert.areEqual(1, phoneRules.size(),
			'76k: exactly one packaged MaskPhoneUS rule must exist. Got: ' + phoneRules.size());
	Assert.areEqual('kern', phoneRules[0].NamespacePrefix,
			'76k: MaskPhoneUS must remain the package-owned rule. Got: ' + phoneRules[0].NamespacePrefix);
	Assert.isTrue(phoneRules[0].kern__IsActive__c != true,
			'76k: MaskPhoneUS must be dormant again after the disable deploy — restoring the dormant steady state '
			+ 'the baseline (76b) asserts before the next run');

	System.debug(LoggingLevel.INFO,
			'76k PASS: the packaged MaskPhoneUS rule is dormant again. CONTRACT (harness teardown): the '
			+ 'rule-activation round-trip restores the shipped dormant state, so section 76 re-runs are idempotent.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '76k FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('76k: ' + scenarioError.getMessage());
	fail++;
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 76c (verify disable): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 76c (verify disable) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 76c (verify disable) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 76c (verify disable) COMPLETE: All scenarios passed ===');
}
