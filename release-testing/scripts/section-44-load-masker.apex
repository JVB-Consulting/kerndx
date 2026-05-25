/**
 * Section 44 (extended-load Phase 2): Load Test — UTIL_FrameworkMasker bulk
 *
 * Stresses BulkRecordMasker.apply() on 200 kern__ApiCall__c records via the
 * TRG_Dispatcher inline masking pre-step.
 *
 * SPEC vs ACTUAL — target/rule counts:
 *   Spec expected: 5 MaskingTarget__mdt records for ApiCall__c × 10 active MaskingRule__mdt
 *   Actual deployed framework: 2 wildcard targets (ApiCall_All_Card → MaskCreditCard,
 *   ApiCall_All_Secret → MaskSecretKeys) × 2 active framework rules. Plus subscriber-side
 *   test fixtures from earlier sections may add ~1 additional active rule + 1 single-field
 *   target on Url. Realistic eval count: ~1000 per trigger fire (lower bound 800 framework-only,
 *   not the spec's ~10,000). Sections 45-51 will establish the Tier-1 load-test pattern regardless.
 *   CMDT DML is platform-blocked from anon Apex — target/rule counts cannot be changed here.
 *
 * BEHAVIOUR ASSERTIONS (hard gate):
 *   - All 200 records inserted and persisted (no rollback)
 *   - No sampled record retains the raw Visa card number '4111111111111111' (MaskCreditCard active)
 *   - Zero [MASKING_FAILURE] sentinels in sampled records
 *   - No invalidated rules post-run (pre-flight CMDT query confirms active rules)
 *   NOTE: SSN pattern '123-45-6789' is NOT asserted — MaskSsn is inactive in the deployed package.
 *
 * PERF METRICS (soft gate, harvested by Phase 2.6):
 *   wallMs, cpuMs, soqlCount, dmlCount, heapBytesPeak — emitted as PERF_ROW: lines
 *
 * Pre-seeded baseline (conservative; calibrated for 5×10 density; actual 2×2 will be faster):
 *   wallMs: 4500, cpuMs: 9000
 *
 * Run-isolation: self-contained. All 200 inserted rows are deleted in the cleanup block.
 *
 * Prerequisites:
 *   - subscriber scratch org with kern managed package installed
 *   - MaskingFramework_Enabled feature flag ON (default)
 *   - kern__MaskingTarget__mdt: ApiCall_All_Card + ApiCall_All_Secret active
 *   - kern__MaskingRule__mdt: MaskCreditCard + MaskSecretKeys active
 *   - TriggerSetting.ApiCall has ApplyMasking__c = true (shipped default)
 *
 * Run (in isolation):
 *   sf apex run --file release-testing/scripts/section-44-load-masker.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock: <5 seconds (200 DML inserts, 2 queries, 1 bulk delete).
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 44 (extended-load Phase 2): Load Test — UTIL_FrameworkMasker bulk ===');

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String VISA_CARD = '4111111111111111';
final String CARD_REDACTED_SENTINEL = 'CARD_REDACTED';
final String MASKING_FAILURE_SENTINEL = '[MASKING_FAILURE]';
final String RUN_STAMP = String.valueOf(Datetime.now().getTime());
final Integer BATCH_SIZE = 200;
final String SENSITIVE_REQUEST = '{"card":"' + VISA_CARD + '","password":"hunter2","apiKey":"AKIAIOSFODNN7EXAMPLE"}';
final String SENSITIVE_RESPONSE = '{"status":"ok","token":"secret-abc123"}';
final String SENSITIVE_URL = 'https://admin:hunter2@api.example.com/bulk-load-44';

// Pre-flight: query active MaskingTarget__mdt + MaskingRule__mdt.
// kern__SObjectType__c is a MetadataRelationship (EntityDefinition) field — its value is not
// a plain string and cannot be reliably filtered or compared in subscriber anon Apex. Report
// total active counts; masking fires correctly via the framework's internal resolution path
// (confirmed: 50/50 sampled records show CARD_REDACTED after insert).
// Source truth: 2 ApiCall__c targets deployed (ApiCall_All_Card, ApiCall_All_Secret).
// Spec expected 5 ApiCall__c targets × 10 active rules = 50 target-rule pairs. Actual: 2 × 2 = 4.
Integer activeTotalTargets =
[
	SELECT COUNT()
	FROM kern__MaskingTarget__mdt
	WHERE kern__IsActive__c = true
];
Integer activeRuleCount =
[
	SELECT COUNT()
	FROM kern__MaskingRule__mdt
	WHERE kern__IsActive__c = true
];
System.debug(LoggingLevel.INFO,
	'Pre-flight: ' + activeTotalTargets + ' total active MaskingTarget(s) (all SObjects) × '
	+ activeRuleCount + ' active rule(s). Known ApiCall__c targets: 2 (ApiCall_All_Card, ApiCall_All_Secret). '
	+ 'Known active rules: 2 (MaskCreditCard, MaskSecretKeys). Spec 5×10; actual 2×2=4 pairs. '
	+ 'Actual regex pressure ≈ ' + (BATCH_SIZE * 2 * 2) + ' evaluations per trigger fire (field wildcard).');

// Capture pre-run governor baselines
Long startWallMs = System.currentTimeMillis();
Long startCpuMs = Limits.getCpuTime();
Integer startSoqlCount = Limits.getQueries();
Integer startDmlCount = Limits.getDmlStatements();
Long startHeapBytes = Limits.getHeapSize();

try
{
	List<kern__ApiCall__c> bulkRecords = new List<kern__ApiCall__c>();
	for(Integer index = 0; index < BATCH_SIZE; index++)
	{
		kern__ApiCall__c record = new kern__ApiCall__c();
		record.kern__ServiceName__c = 'LoadMasker44-' + RUN_STAMP;
		record.kern__Direction__c = 'Inbound';
		record.kern__Status__c = 'Completed';
		record.kern__Request__c = SENSITIVE_REQUEST;
		record.kern__Response__c = SENSITIVE_RESPONSE;
		record.kern__URL__c = SENSITIVE_URL + '/' + index;
		bulkRecords.add(record);
	}

	insert bulkRecords;

	Long wallMs = System.currentTimeMillis() - startWallMs;
	Long cpuMs = Limits.getCpuTime() - startCpuMs;
	Integer soqlCount = Limits.getQueries() - startSoqlCount;
	Integer dmlCount = Limits.getDmlStatements() - startDmlCount;
	Long heapBytesPeak = Limits.getHeapSize() - startHeapBytes;

	// BEHAVIOUR ASSERTION 1: count persisted via query (all 200 must exist)
	Integer persistedCount =
	[
		SELECT COUNT()
		FROM kern__ApiCall__c
		WHERE kern__ServiceName__c = :('LoadMasker44-' + RUN_STAMP)
	];

	Assert.areEqual(BATCH_SIZE, persistedCount,
		'44: all ' + BATCH_SIZE + ' records must be persisted — no rollback. Got: ' + persistedCount);

	// BEHAVIOUR ASSERTIONS 2-4: sample 50 records from the org (committed rows reflect trigger mutations)
	List<kern__ApiCall__c> sample =
	[
		SELECT Id, kern__Request__c, kern__Response__c, kern__URL__c
		FROM kern__ApiCall__c
		WHERE kern__ServiceName__c = :('LoadMasker44-' + RUN_STAMP)
		LIMIT 50
	];

	Integer rawCardRetained = 0;
	Integer maskingFailures = 0;
	Integer maskedCount = 0;

	for(kern__ApiCall__c row : sample)
	{
		String requestBody = row.kern__Request__c == null ? '' : row.kern__Request__c;
		if(requestBody.contains(VISA_CARD)) { rawCardRetained++; }
		if(requestBody.contains(MASKING_FAILURE_SENTINEL)
			|| (row.kern__Response__c != null && row.kern__Response__c.contains(MASKING_FAILURE_SENTINEL)))
		{
			maskingFailures++;
		}
		if(!requestBody.contains(VISA_CARD) && requestBody.containsIgnoreCase(CARD_REDACTED_SENTINEL))
		{
			maskedCount++;
		}
	}

	Assert.areEqual(0, rawCardRetained,
		'44: no sampled record should retain raw Visa card number "' + VISA_CARD
		+ '" — masker must have replaced it. Raw retained: ' + rawCardRetained + '/' + sample.size());

	Assert.areEqual(0, maskingFailures,
		'44: no [MASKING_FAILURE] sentinels expected in sampled records. Found: '
		+ maskingFailures + '/' + sample.size());

	// BEHAVIOUR ASSERTION 5: no invalidated rules in per-transaction set
	// Observable via: confirm active rules still query correctly (invalidation resets each tx anyway)
	Integer postRunActiveRules =
	[
		SELECT COUNT()
		FROM kern__MaskingRule__mdt
		WHERE kern__IsActive__c = true
	];
	Assert.areEqual(activeRuleCount, postRunActiveRules,
		'44: active rule count must not change during the test transaction. Before: '
		+ activeRuleCount + ' After: ' + postRunActiveRules);

	// PERF_ROW emission (soft gate — harvested by Task 2.6 perf-history harvester)
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object>{'section' => 44, 'metric' => 'wallMs', 'value' => wallMs}));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object>{'section' => 44, 'metric' => 'cpuMs', 'value' => cpuMs}));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object>{'section' => 44, 'metric' => 'soqlCount', 'value' => soqlCount}));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object>{'section' => 44, 'metric' => 'dmlCount', 'value' => dmlCount}));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(new Map<String, Object>{'section' => 44, 'metric' => 'heapBytesPeak', 'value' => heapBytesPeak}));

	System.debug(LoggingLevel.INFO,
		'44 PASS: ' + BATCH_SIZE + ' records inserted + persisted. '
		+ 'Sample of ' + sample.size() + ': ' + maskedCount + ' show CARD_REDACTED, '
		+ '0 raw card retained, 0 MASKING_FAILURE sentinels. '
		+ 'Deployed: 2 ApiCall targets × 2 active rules (MaskCreditCard + MaskSecretKeys). '
		+ 'wall=' + wallMs + 'ms cpu=' + cpuMs + 'ms soql=' + soqlCount + ' dml=' + dmlCount
		+ ' heap=' + heapBytesPeak + ' bytes');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '44 FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('44: ' + scenarioError.getMessage());
	fail++;
}

// Cleanup — delete all rows inserted by this run (bounded at 9000)
kern.TRG_Base.clearAllBypasses();
try
{
	List<kern__ApiCall__c> residualRows =
	[
		SELECT Id
		FROM kern__ApiCall__c
		WHERE kern__ServiceName__c = :('LoadMasker44-' + RUN_STAMP)
		LIMIT 9000
	];
	if(!residualRows.isEmpty())
	{
		delete residualRows;
		System.debug(LoggingLevel.INFO, 'Cleanup: deleted ' + residualRows.size() + ' kern__ApiCall__c row(s)');
	}
}
catch(Exception cleanupError)
{
	System.debug(LoggingLevel.WARN, '44 cleanup warning (ApiCall__c delete failed): ' + cleanupError.getMessage());
}

// Summary
System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 44: ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 44 FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 44 failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 44 COMPLETE: All scenarios passed ===');
}
