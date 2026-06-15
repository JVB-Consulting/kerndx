/**
 * Section 76b: Data Masking Advisor Round-Trip — Verify CREATE
 *
 * Runs immediately after run-phase2.js runSection76() deploys the `create` bundle from
 * e2e/fixtures/masking-advisor-bundles/ — two advisor-format MaskingTarget records pushed
 * with the Export modal's own deploy command. Proves the create half of the round-trip:
 *
 *   76d. Re-read — both probe records exist in kern__MaskingTarget__mdt with every field
 *        the bundle carried: active, object-wide (blank Field__c), all-callers (blank
 *        CallerClass__c), SObjectType resolved to Case, and the namespace-qualified rule
 *        references in the bundle XML (kern__MaskCreditCard / kern__MaskEmail) resolved
 *        through the MetadataRelationship to the PACKAGED rules (kern__Rule__r.DeveloperName
 *        round-trips as MaskCreditCard / MaskEmail, the namespace-stripped developer name).
 *        Labels round-trip verbatim.
 *
 *   76e. Posture recompute — the four posture counts move exactly as the advisor's
 *        semantics dictate: Case joins the masked-object set (4 -> 5), both probes count
 *        object-wide (12 -> 14), the harness field-level target is untouched (1), and the
 *        dead-config probe (active target bound to the dormant MaskEmail rule) registers
 *        as the org's single dead configuration (0 -> 1).
 *        HEALTH CHECK INPUT: deadConfigCount=1 => the masking-posture check now computes
 *        WARN (dead-configuration branch) where the baseline computed Pass(4) — the
 *        config-change-moves-the-Health-Check proof, scripted.
 *
 *   76j. Rule-activation round-trip — the create bundle also carries the advisor's
 *        rule-activation override (kern__MaskingRule.kern__MaskPhoneUS), which flips the
 *        PACKAGED MaskPhoneUS rule active. The advisor emits that file under the
 *        namespace-qualified record name, so the override resolves to the shipped rule:
 *        exactly one MaskPhoneUS rule (NamespacePrefix kern) is now active, with its
 *        package-controlled label intact. A bare record name would either fail to deploy
 *        ("you must enter a Pattern") or spawn a second subscriber-owned rule — both are
 *        what this scenario rules out. Posture counts are unchanged (76e already pinned
 *        them exactly): an active rule that no target binds masks nothing.
 *
 * Run-isolation: read-only (SOQL). State transitions are owned by the runner's bundle
 * deploys; the runner always restores the disabled steady state afterwards.
 *
 * Run (in isolation, after deploying the create bundle):
 *   sf apex run --file release-testing/scripts/section-76b-masking-advisor-verify-created.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock: <3 seconds (2 SOQL queries).
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 76b: Masking Advisor Round-Trip — Verify CREATE ===');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

// Scenario 76d — the deployed bundle re-reads from kern__MaskingTarget__mdt field-for-field.
try
{
	Map<String, kern__MaskingTarget__mdt> probesByName = new Map<String, kern__MaskingTarget__mdt>();
	for(kern__MaskingTarget__mdt probe :
	[
			SELECT DeveloperName,
					MasterLabel,
					kern__IsActive__c,
					kern__Field__c,
					kern__CallerClass__c,
					kern__SObjectType__c,
					kern__Rule__c,
					kern__Rule__r.DeveloperName,
					kern__Rule__r.kern__IsActive__c
			FROM kern__MaskingTarget__mdt
			WHERE DeveloperName IN ('Case_All_Card_Probe', 'Case_All_Email_DeadProbe')
	])
	{
		probesByName.put(probe.DeveloperName, probe);
	}

	Assert.areEqual(2, probesByName.size(),
			'76d: both probe records must exist after the create-bundle deploy. Found: ' + probesByName.keySet());

	kern__MaskingTarget__mdt healthyProbe = probesByName.get('Case_All_Card_Probe');
	Assert.isTrue(healthyProbe.kern__IsActive__c == true,
			'76d: Case_All_Card_Probe must deploy active');
	Assert.areEqual('Card / Case.* (round-trip probe)', healthyProbe.MasterLabel,
			'76d: the bundle label must round-trip verbatim. Got: ' + healthyProbe.MasterLabel);
	Assert.isTrue(String.isBlank(healthyProbe.kern__Field__c),
			'76d: Case_All_Card_Probe must be object-wide — the bundle ships Field__c as xsi:nil. Got: ' + healthyProbe.kern__Field__c);
	Assert.isTrue(String.isBlank(healthyProbe.kern__CallerClass__c),
			'76d: Case_All_Card_Probe must apply to all callers — the bundle ships CallerClass__c as xsi:nil. Got: ' + healthyProbe.kern__CallerClass__c);
	Assert.areEqual('Case', healthyProbe.kern__SObjectType__c,
			'76d: SObjectType__c must resolve to the Case entity. Got: ' + healthyProbe.kern__SObjectType__c);
	Assert.isNotNull(healthyProbe.kern__Rule__r,
			'76d: the namespace-qualified rule reference kern__MaskCreditCard in the bundle XML must resolve through the '
			+ 'MetadataRelationship to the packaged rule — the advisor qualifies the rule name so '
			+ 'the export deploys on a managed subscriber org (a bare name resolves to no such record)');
	Assert.areEqual('MaskCreditCard', healthyProbe.kern__Rule__r.DeveloperName,
			'76d: Case_All_Card_Probe must bind the packaged MaskCreditCard rule. Got: ' + healthyProbe.kern__Rule__r.DeveloperName);
	Assert.isTrue(healthyProbe.kern__Rule__r.kern__IsActive__c == true,
			'76d: MaskCreditCard must be active — the healthy probe must not register as dead config');

	kern__MaskingTarget__mdt deadProbe = probesByName.get('Case_All_Email_DeadProbe');
	Assert.isTrue(deadProbe.kern__IsActive__c == true,
			'76d: Case_All_Email_DeadProbe must deploy active (an ACTIVE target on a dormant rule is what makes a dead config)');
	Assert.areEqual('Email / Case.* (dead-config probe)', deadProbe.MasterLabel,
			'76d: the dead-probe label must round-trip verbatim. Got: ' + deadProbe.MasterLabel);
	Assert.areEqual('Case', deadProbe.kern__SObjectType__c,
			'76d: dead probe SObjectType__c must resolve to Case. Got: ' + deadProbe.kern__SObjectType__c);
	Assert.isNotNull(deadProbe.kern__Rule__r,
			'76d: the namespace-qualified rule reference kern__MaskEmail must resolve to the packaged rule');
	Assert.areEqual('MaskEmail', deadProbe.kern__Rule__r.DeveloperName,
			'76d: Case_All_Email_DeadProbe must bind the packaged MaskEmail rule. Got: ' + deadProbe.kern__Rule__r.DeveloperName);
	Assert.isTrue(deadProbe.kern__Rule__r.kern__IsActive__c != true,
			'76d: MaskEmail must still be dormant — the dead-config scenario depends on it');

	System.debug(LoggingLevel.INFO,
			'76d PASS: create bundle round-tripped field-for-field — both probes active on Case, '
			+ 'object-wide, all-callers, labels verbatim, and the bundle\'s namespace-qualified rule references '
			+ '(kern__MaskCreditCard / kern__MaskEmail) resolved through the MetadataRelationship to the packaged '
			+ 'kern__ rules. CONTRACT: the advisor export deploys on a subscriber org exactly as generated.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '76d FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('76d: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 76e — posture recomputes from the new configuration.
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
			'76e: Case must join the masked-object set — 4 baseline objects + Case = 5. Got '
			+ activeObjectIdentifiers.size() + ': ' + activeObjectIdentifiers);
	Assert.isTrue(activeObjectIdentifiers.contains('Case'),
			'76e: the masked-object set must contain Case. Got: ' + activeObjectIdentifiers);
	Assert.areEqual(14, objectWideCount,
			'76e: both probes count object-wide — 12 baseline + 2 = 14. Got: ' + objectWideCount);
	Assert.areEqual(1, fieldLevelCount,
			'76e: the field-level count must be untouched by the object-wide probes. Got: ' + fieldLevelCount);
	Assert.areEqual(1, deadCount,
			'76e: exactly one dead configuration — the active dead-probe bound to dormant MaskEmail. Got '
			+ deadCount + ': ' + deadTargetNames);
	Assert.areEqual(new List<String> {'Case_All_Email_DeadProbe'}, deadTargetNames,
			'76e: the dead configuration must be Case_All_Email_DeadProbe specifically. Got: ' + deadTargetNames);

	System.debug(LoggingLevel.INFO,
			'76e PASS: posture recomputed from the deployed config — 5 masked objects / 14 object-wide / '
			+ '1 field-level / 1 dead. HEALTH CHECK INPUT: deadConfigCount=1 => the masking-posture check '
			+ 'now computes WARN (dead-configuration branch) where the baseline computed Pass(4). '
			+ 'A masking-config change moved the Health Check result — the recompute proof.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '76e FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('76e: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 76j — the rule-activation override resolved to the packaged MaskPhoneUS rule.
// The advisor's activation file is named for the namespace-qualified record
// (kern__MaskingRule.kern__MaskPhoneUS), so it flips the SHIPPED rule's IsActive rather
// than minting a new subscriber-owned record. Exactly one MaskPhoneUS rule must exist, it
// must be the package-owned one (NamespacePrefix kern), it must now be active, and its
// package-controlled label must be intact.
try
{
	List<kern__MaskingRule__mdt> phoneRules =
	[
			SELECT DeveloperName,
					NamespacePrefix,
					MasterLabel,
					kern__IsActive__c
			FROM kern__MaskingRule__mdt
			WHERE DeveloperName = 'MaskPhoneUS'
	];

	Assert.areEqual(1, phoneRules.size(),
			'76j: exactly one MaskPhoneUS rule must exist — the namespace-qualified activation override must '
			+ 'resolve to the packaged rule, never spawn a second subscriber-owned record. Got: ' + phoneRules.size());

	kern__MaskingRule__mdt phoneRule = phoneRules[0];
	Assert.areEqual('kern', phoneRule.NamespacePrefix,
			'76j: the activated MaskPhoneUS must be the PACKAGED rule (NamespacePrefix kern). A blank prefix would '
			+ 'mean the deploy minted a new subscriber rule instead of flipping the shipped one. Got: ' + phoneRule.NamespacePrefix);
	Assert.isTrue(phoneRule.kern__IsActive__c == true,
			'76j: the create bundle must have flipped the packaged MaskPhoneUS rule active');
	Assert.areEqual('Mask US Phone Numbers', phoneRule.MasterLabel,
			'76j: the package-controlled label must be intact — the activation override flips only IsActive. Got: ' + phoneRule.MasterLabel);

	System.debug(LoggingLevel.INFO,
			'76j PASS: the rule-activation override round-tripped — the packaged MaskPhoneUS rule '
			+ '(NamespacePrefix kern) is active with its shipped label intact. CONTRACT: the advisor activates a '
			+ 'dormant packaged rule via its namespace-qualified record name, so the export deploys on a subscriber '
			+ 'exactly as generated — a bare name would fail to deploy or create a phantom rule.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '76j FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('76j: ' + scenarioError.getMessage());
	fail++;
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 76b (verify create): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 76b (verify create) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 76b (verify create) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 76b (verify create) COMPLETE: All scenarios passed ===');
}
