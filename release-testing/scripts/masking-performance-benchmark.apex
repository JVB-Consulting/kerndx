// Masking performance benchmark — compares bulk ApiCall__c insert with masking ON vs OFF.
//
// Purpose
// -------
// Measures the CPU and wall-clock overhead the data masking framework adds to a
// 200-record DML batch. Uses ApiCall__c because it ships with the full default target
// set (13 wildcard MaskingTarget__mdt records covering every active pre-built rule).
//
// Run
// ---
// sf apex run -o <ORG_ALIAS> -f release-testing/scripts/masking-performance-benchmark.apex
//
// Notes
// -----
// The ResetOutboundApiCall record-triggered flow runs before Apex triggers and nulls
// Request__c / Response__c / URL__c when Direction__c = Outbound AND Status__c = Queued.
// This benchmark sets Direction__c = Inbound and Status__c = Completed so the flow does
// not fire and the masker sees the full payload.
//
// The masking pre-step lives in TRG_Dispatcher, gated by TriggerSetting.ApplyMasking__c.
// The baseline pass bypasses the ApiCall__c trigger entirely so we measure raw DML.

Integer batchSize = 200;

String sampleRequest = '{"user":"alice@example.com","password":"hunter2","ssn":"123-45-6789","card":"4111-1111-1111-1111","jwt":"eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.abcdef"}';
String sampleResponse = '{"status":"ok","token":"secret-abc123","phone":"555-123-4567"}';
String sampleUrl = 'https://admin:hunter2@api.example.com/path';
String sampleParameters = '{"apiKey":"AKIAIOSFODNN7EXAMPLE","email":"bob@example.com"}';

// Baseline — bypass the ApiCall__c trigger so masking pre-step is skipped.
TRG_Base.bypass(ApiCall__c.SObjectType);

List<ApiCall__c> baselineRecords = new List<ApiCall__c>();
for(Integer i = 0; i < batchSize; i++)
{
	ApiCall__c call = new ApiCall__c();
	call.ServiceName__c = 'MaskingPerfBaseline';
	call.Direction__c = 'Inbound';
	call.Status__c = 'Completed';
	call.Request__c = sampleRequest.replace('alice@', 'alice' + i + '@');
	call.Response__c = sampleResponse;
	call.URL__c = sampleUrl + '/' + i;
	call.RequestParameters__c = sampleParameters.replace('bob@', 'bob' + i + '@');
	baselineRecords.add(call);
}

Long baselineCpuStart = Limits.getCpuTime();
Long baselineWallStart = System.currentTimeMillis();
insert baselineRecords;
Long baselineWall = System.currentTimeMillis() - baselineWallStart;
Long baselineCpu = Limits.getCpuTime() - baselineCpuStart;

ApiCall__c baselineSample = baselineRecords[0];
delete baselineRecords;

System.debug('=== MASKING OFF (baseline — trigger bypassed) ===');
System.debug('Records: ' + batchSize);
System.debug('Wall clock: ' + baselineWall + ' ms');
System.debug('CPU time: ' + baselineCpu + ' ms');
System.debug('CPU per record: ' + (baselineCpu / (Decimal)batchSize).setScale(2) + ' ms');
System.debug('Baseline sample Request (should contain raw PII): ' + baselineSample.Request__c);

// Clear bypass so the dispatcher masking pre-step runs.
TRG_Base.clearBypass(ApiCall__c.SObjectType);

List<ApiCall__c> maskedRecords = new List<ApiCall__c>();
for(Integer i = 0; i < batchSize; i++)
{
	ApiCall__c call = new ApiCall__c();
	call.ServiceName__c = 'MaskingPerfMasked';
	call.Direction__c = 'Inbound';
	call.Status__c = 'Completed';
	call.Request__c = sampleRequest.replace('alice@', 'alice' + i + '@');
	call.Response__c = sampleResponse;
	call.URL__c = sampleUrl + '/' + i;
	call.RequestParameters__c = sampleParameters.replace('bob@', 'bob' + i + '@');
	maskedRecords.add(call);
}

Long maskedCpuStart = Limits.getCpuTime();
Long maskedWallStart = System.currentTimeMillis();
insert maskedRecords;
Long maskedWall = System.currentTimeMillis() - maskedWallStart;
Long maskedCpu = Limits.getCpuTime() - maskedCpuStart;

System.debug('=== MASKING ON (default targets) ===');
System.debug('Records: ' + batchSize);
System.debug('Wall clock: ' + maskedWall + ' ms');
System.debug('CPU time: ' + maskedCpu + ' ms');
System.debug('CPU per record: ' + (maskedCpu / (Decimal)batchSize).setScale(2) + ' ms');

Long wallOverhead = maskedWall - baselineWall;
Long cpuOverhead = maskedCpu - baselineCpu;

System.debug('=== OVERHEAD ===');
System.debug('Wall: +' + wallOverhead + ' ms');
System.debug('CPU: +' + cpuOverhead + ' ms');
System.debug('CPU per record: +' + (cpuOverhead / (Decimal)batchSize).setScale(2) + ' ms');

// Query the DB to verify persistence. In-memory list refs do not always reflect
// before-insert trigger field mutations in anonymous Apex, but the committed row does.
ApiCall__c persistedSample = [
	SELECT Id, Request__c, Response__c, URL__c, RequestParameters__c
	FROM ApiCall__c
	WHERE Id = :maskedRecords[0].Id
];
System.debug('=== PERSISTED MASKED RECORD (from DB) ===');
System.debug('Request: ' + persistedSample.Request__c);
System.debug('Response: ' + persistedSample.Response__c);
System.debug('URL: ' + persistedSample.URL__c);
System.debug('RequestParameters: ' + persistedSample.RequestParameters__c);

delete maskedRecords;

// Regression gate — runs against the managed-package runtime, which is where the 99cdf4e
// SOQL-cost regression manifested (and where an Apex-class CPU gate on the dev org would
// have missed it). Wall-clock overhead above the budget indicates the masker pre-step has
// picked up a slow cold-path SOQL or similar structural slowdown; CPU overhead above its
// budget indicates per-record masking work has ballooned.
//
// Budgets are calibrated from observed fast-path numbers (~270ms wall, ~610ms CPU overhead
// on the kern dev scratch org for 200 records) with ~3x headroom for CI variance — tight
// enough that re-introducing the MetadataRelationship-joined SOQL in SEL_MaskingTarget
// (~880ms cold) pushes wall overhead past the budget and fails this gate loudly.
Integer WALL_OVERHEAD_BUDGET_MS = 900;
Integer CPU_OVERHEAD_BUDGET_MS = 1800;
Assert.isTrue(wallOverhead < WALL_OVERHEAD_BUDGET_MS,
	'Masking wall-clock overhead exceeded budget: observed=' + wallOverhead + 'ms budget=' + WALL_OVERHEAD_BUDGET_MS + 'ms '
	+ '(would have caught 99cdf4e SOQL-cost regression — see commit history).');
Assert.isTrue(cpuOverhead < CPU_OVERHEAD_BUDGET_MS,
	'Masking CPU overhead exceeded budget: observed=' + cpuOverhead + 'ms budget=' + CPU_OVERHEAD_BUDGET_MS + 'ms.');

System.debug('=== GATE: PASS ===');
System.debug('Wall overhead ' + wallOverhead + 'ms < ' + WALL_OVERHEAD_BUDGET_MS + 'ms budget');
System.debug('CPU overhead ' + cpuOverhead + 'ms < ' + CPU_OVERHEAD_BUDGET_MS + 'ms budget');
