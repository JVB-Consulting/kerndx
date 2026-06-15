/**
 * Section 76: Data Masking Advisor — Scripted Configuration Round-Trip (Baseline)
 *
 * Scripted half of the advisor's release validation. The advisor's @AuraEnabled surface
 * (CTRL_MaskingAdvisor.describeFields / getOrgPostureSummary / getOrgPostureInventory /
 * generateConfiguration) is `public`, not `global` — invisible to subscriber anonymous Apex
 * by design — so the API behaviours are verified at the right layer by the Phase-3 part9
 * e2e suite (V90-V97) running the shipped LWC in the package namespace. What THIS section
 * proves is the subscriber-observable contract underneath that console:
 *
 *   76a. Namespace-safe CMDT resolution — kern__MaskingTarget__mdt and kern__MaskingRule__mdt
 *        resolve through describe from subscriber context, and their key prefixes resolve
 *        DYNAMICALLY (the advisor's "New masking rule" Setup link is built from describe,
 *        never a hard-coded m08-style prefix).
 *
 *   76b. Shipped rule catalogue — the packaged rules a fresh subscriber receives: at least
 *        19 rules visible (18 shipped + the harness's TestTypeFilterWarn from section 39),
 *        MaskPaymentCard + MaskSecretKeys + the legacy MaskCreditCard (replaced by
 *        MaskPaymentCard, kept for compatibility) active by default, and MaskEmail /
 *        MaskPhoneUS / MaskPhoneInternational present but dormant. The shipped rules deliberately leave
 *        ApplicableFieldTypes__c blank (unscoped — any maskable text-shaped field); the
 *        console's multi-mask pre-selection (one phone field surfacing BOTH phone rules)
 *        is stem-name-driven and verified end-to-end by part9 V96.
 *
 *   76c. Org posture baseline — SOQL over kern__MaskingTarget__mdt mirroring the advisor's
 *        posture semantics (distinct SObjectType__c among active targets; object-wide =
 *        blank Field__c; dead = active target whose rule is missing or inactive). A fresh
 *        subscriber org with the test harness deployed sits at exactly:
 *          objects-with-active-targets = 4   (ApiCall, ApiIssue, AsyncChainExecution, LogEntryEvent)
 *          object-wide targets         = 12  (Card + PaymentCard + Secret per object, shipped;
 *                                             the Card targets stay active CMDT rows — the engine
 *                                             defers them to the PaymentCard successor at runtime)
 *          field-level targets         = 1   (harness TestTypeFilterWarnOnApiCallUrl, section 39)
 *          dead configurations         = 0
 *        These four counts are the exact inputs to the Health Check masking-posture result
 *        (dead > 0 => Warn; zero masked objects => Warn; else Pass with the object count),
 *        so this baseline pins the Health Check at Pass(4) before the round-trip begins.
 *        Also asserts the round-trip probe records (Case_All_Card_Probe /
 *        Case_All_Email_DeadProbe), when present from a previous run, are inactive — the
 *        runner's cleanup contract that keeps re-runs idempotent.
 *
 * Orchestration: run-phase2.js runSection76() runs this baseline first, then deploys the
 * advisor-format bundles in e2e/fixtures/masking-advisor-bundles/ (create -> disable ->
 * re-enable -> cleanup) with the Export modal's own deploy command
 * (`sf project deploy start --metadata-dir metadata -o <alias>`), running the matching
 * section-76b/c/d verify scripts between deploys. See the fixtures README for the bundle
 * shapes and expected posture after each deploy.
 *
 * Run-isolation: read-only (SOQL + describe). No DML, no CMDT mutation, no cleanup needed.
 *
 * Prerequisites:
 *   - subscriber scratch org with the kern managed package installed
 *   - subscriber test artifacts deployed (RUNBOOK 1.4-1.5), including the section-39
 *     TestTypeFilterWarn rule + TestTypeFilterWarnOnApiCallUrl target
 *
 * Run (in isolation):
 *   sf apex run --file release-testing/scripts/section-76-masking-advisor-roundtrip.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock: <3 seconds (2 describes, 2 SOQL queries).
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 76: Masking Advisor Round-Trip — Baseline ===');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

// Scenario 76a — namespace-safe CMDT resolution + dynamic key prefixes.
// The advisor resolves both masking CMDT types through describe (namespace-aware), and the
// console's "New masking rule" Setup URL is built from the MaskingRule__mdt key prefix at
// runtime. From subscriber context both types must resolve under kern__ and expose a
// well-formed, dynamically-discovered key prefix (m-series, never assumed).
try
{
	List<Schema.DescribeSObjectResult> cmdtDescribes = Schema.describeSObjects(
			new List<String> {'kern__MaskingTarget__mdt', 'kern__MaskingRule__mdt'});

	Schema.DescribeSObjectResult targetDescribe = cmdtDescribes[0];
	Schema.DescribeSObjectResult ruleDescribe = cmdtDescribes[1];

	Assert.areEqual('kern__MaskingTarget__mdt', targetDescribe.getName(),
			'76a: MaskingTarget__mdt must resolve with the kern__ namespace prefix from subscriber context. Got: '
			+ targetDescribe.getName());
	Assert.areEqual('kern__MaskingRule__mdt', ruleDescribe.getName(),
			'76a: MaskingRule__mdt must resolve with the kern__ namespace prefix from subscriber context. Got: '
			+ ruleDescribe.getName());

	String targetKeyPrefix = targetDescribe.getKeyPrefix();
	String ruleKeyPrefix = ruleDescribe.getKeyPrefix();

	Assert.isTrue(String.isNotBlank(targetKeyPrefix) && targetKeyPrefix.length() == 3 && targetKeyPrefix.startsWith('m'),
			'76a: MaskingTarget__mdt key prefix must be a 3-character m-series CustomMetadata prefix. Got: ' + targetKeyPrefix);
	Assert.isTrue(String.isNotBlank(ruleKeyPrefix) && ruleKeyPrefix.length() == 3 && ruleKeyPrefix.startsWith('m'),
			'76a: MaskingRule__mdt key prefix must be a 3-character m-series CustomMetadata prefix. Got: ' + ruleKeyPrefix);
	Assert.areNotEqual(targetKeyPrefix, ruleKeyPrefix,
			'76a: the two CMDT types must carry distinct key prefixes. Both returned: ' + targetKeyPrefix);

	System.debug(LoggingLevel.INFO,
			'76a PASS: kern__MaskingTarget__mdt (prefix ' + targetKeyPrefix + ') and kern__MaskingRule__mdt (prefix '
			+ ruleKeyPrefix + ') resolve namespace-safe via describe from subscriber context. '
			+ 'CONTRACT: the advisor builds its New-masking-rule Setup URL from this runtime describe '
			+ 'prefix — org-specific prefixes are never hard-coded.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '76a FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('76a: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 76b — shipped rule catalogue under kern__.
// A fresh subscriber org receives 18 packaged rules (plus the harness's section-39 rule).
// The payment-card, secret, and legacy credit-card rules are active by default; Email and
// both Phone rules ship dormant.
// MaskEmail staying dormant is what the dead-config probe depends on; the dormant phone
// pair is what the console's stem-driven multi-mask pre-selection recommends (part9 V96).
try
{
	Map<String, kern__MaskingRule__mdt> rulesByName = new Map<String, kern__MaskingRule__mdt>();
	for(kern__MaskingRule__mdt rule :
	[
			SELECT DeveloperName,
					kern__IsActive__c
			FROM kern__MaskingRule__mdt
	])
	{
		rulesByName.put(rule.DeveloperName, rule);
	}

	Assert.isTrue(rulesByName.size() >= 19,
			'76b: expected at least 19 masking rules (18 shipped + harness TestTypeFilterWarn). Got '
			+ rulesByName.size() + ': ' + rulesByName.keySet());

	for(String shippedRuleName : new List<String> {'MaskCreditCard', 'MaskPaymentCard', 'MaskSecretKeys', 'MaskEmail', 'MaskPhoneUS', 'MaskPhoneInternational'})
	{
		Assert.isTrue(rulesByName.containsKey(shippedRuleName),
				'76b: shipped rule ' + shippedRuleName + ' must be visible under kern__ from subscriber context. Visible: '
				+ rulesByName.keySet());
	}

	Assert.isTrue(rulesByName.get('MaskCreditCard').kern__IsActive__c == true,
			'76b: MaskCreditCard must ship active by default (replaced by MaskPaymentCard but kept active for compatibility)');
	Assert.isTrue(rulesByName.get('MaskPaymentCard').kern__IsActive__c == true,
			'76b: MaskPaymentCard must ship active by default — it does the card masking on the framework objects');
	Assert.isTrue(rulesByName.get('MaskSecretKeys').kern__IsActive__c == true,
			'76b: MaskSecretKeys must ship active by default');
	Assert.isTrue(rulesByName.get('MaskEmail').kern__IsActive__c != true,
			'76b: MaskEmail must ship dormant — the round-trip dead-config probe depends on it staying inactive');
	Assert.isTrue(rulesByName.get('MaskPhoneUS').kern__IsActive__c != true,
			'76b: MaskPhoneUS must ship dormant');
	Assert.isTrue(rulesByName.get('MaskPhoneInternational').kern__IsActive__c != true,
			'76b: MaskPhoneInternational must ship dormant');

	System.debug(LoggingLevel.INFO,
			'76b PASS: rule catalogue visible under kern__ (' + rulesByName.size() + ' rules). '
			+ 'MaskPaymentCard + MaskSecretKeys + legacy MaskCreditCard active by default; MaskEmail / MaskPhoneUS / '
			+ 'MaskPhoneInternational dormant. Shipped rules are unscoped (blank '
			+ 'ApplicableFieldTypes__c); the multi-mask phone pre-selection is stem-driven '
			+ 'and covered end-to-end by part9 V96.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '76b FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('76b: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 76c — org posture baseline, mirroring the advisor's posture semantics in SOQL.
// objects-with-active-targets = distinct SObjectType__c among ACTIVE targets;
// object-wide = active target with blank Field__c; field-level = active with a Field__c;
// dead = ACTIVE target whose rule is missing or inactive (inactive targets are never dead).
// These four counts are exactly what the Health Check masking-posture check consumes:
// dead > 0 => Warn, zero masked objects => Warn, else Pass(<object count>).
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
			'76c: baseline must show exactly 4 objects with active targets (ApiCall, ApiIssue, '
			+ 'AsyncChainExecution, LogEntryEvent — shipped object-wide Card/PaymentCard/Secret triples). Got '
			+ activeObjectIdentifiers.size() + ': ' + activeObjectIdentifiers);
	Assert.areEqual(12, objectWideCount,
			'76c: baseline must show exactly 12 active object-wide targets (Card + PaymentCard + Secret per shipped object). Got: ' + objectWideCount);
	Assert.areEqual(1, fieldLevelCount,
			'76c: baseline must show exactly 1 active field-level target (harness TestTypeFilterWarnOnApiCallUrl). Got: ' + fieldLevelCount);
	Assert.areEqual(0, deadCount,
			'76c: baseline must carry no dead configuration (every active target binds an active rule). Dead: ' + deadTargetNames);
	Assert.isFalse(activeObjectIdentifiers.contains('Case'),
			'76c: Case must carry no ACTIVE masking target at baseline — the round-trip probe object must start clean. '
			+ 'A leftover active probe means a previous run did not clean up.');

	for(kern__MaskingTarget__mdt target : targets)
	{
		if(target.DeveloperName == 'Case_All_Card_Probe' || target.DeveloperName == 'Case_All_Email_DeadProbe')
		{
			Assert.isTrue(target.kern__IsActive__c != true,
					'76c: probe record ' + target.DeveloperName + ' exists from a previous run and must be inactive '
					+ '(runner cleanup contract — CustomMetadata deploys cannot delete, so probes persist disabled)');
		}
	}

	System.debug(LoggingLevel.INFO,
			'76c PASS: posture baseline = 4 masked objects / 12 object-wide / 1 field-level / 0 dead. '
			+ 'HEALTH CHECK INPUT: deadConfigCount=0 and objectsWithActiveTargets=4 => masking-posture '
			+ 'check computes Pass(4). The round-trip deploys that follow move these counts and with '
			+ 'them the Health Check result — the value-change proof.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '76c FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('76c: ' + scenarioError.getMessage());
	fail++;
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 76 (baseline): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 76 (baseline) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 76 (baseline) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 76 (baseline) COMPLETE: All scenarios passed ===');
}
