// Single-size perf pass. Pass the size via the SIZE constant below.
Integer batchSize = __SIZE__;

String sampleRequest = '{"user":"alice@example.com","password":"hunter2","ssn":"123-45-6789","card":"4111-1111-1111-1111","jwt":"eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.abcdef"}';
String sampleResponse = '{"status":"ok","token":"secret-abc123","phone":"555-123-4567"}';
String sampleUrl = 'https://admin:hunter2@api.example.com/path';
String sampleParameters = '{"apiKey":"AKIAIOSFODNN7EXAMPLE","email":"bob@example.com"}';

kern.TRG_Base.bypass(kern__ApiCall__c.SObjectType);
List<kern__ApiCall__c> baseline = new List<kern__ApiCall__c>();
for(Integer i = 0; i < batchSize; i++)
{
	kern__ApiCall__c call = new kern__ApiCall__c();
	call.kern__ServiceName__c = 'PerfBaseline_' + batchSize;
	call.kern__Direction__c = 'Inbound';
	call.kern__Status__c = 'Completed';
	call.kern__Request__c = sampleRequest;
	call.kern__Response__c = sampleResponse;
	call.kern__URL__c = sampleUrl + '/' + i;
	call.kern__RequestParameters__c = sampleParameters;
	baseline.add(call);
}
Long baselineCpuStart = Limits.getCpuTime();
Long baselineWallStart = System.currentTimeMillis();
insert baseline;
Long baselineWall = System.currentTimeMillis() - baselineWallStart;
Long baselineCpu = Limits.getCpuTime() - baselineCpuStart;
delete baseline;

kern.TRG_Base.clearBypass(kern__ApiCall__c.SObjectType);
List<kern__ApiCall__c> masked = new List<kern__ApiCall__c>();
for(Integer i = 0; i < batchSize; i++)
{
	kern__ApiCall__c call = new kern__ApiCall__c();
	call.kern__ServiceName__c = 'PerfMasked_' + batchSize;
	call.kern__Direction__c = 'Inbound';
	call.kern__Status__c = 'Completed';
	call.kern__Request__c = sampleRequest;
	call.kern__Response__c = sampleResponse;
	call.kern__URL__c = sampleUrl + '/' + i;
	call.kern__RequestParameters__c = sampleParameters;
	masked.add(call);
}
Long maskedCpuStart = Limits.getCpuTime();
Long maskedWallStart = System.currentTimeMillis();
insert masked;
Long maskedWall = System.currentTimeMillis() - maskedWallStart;
Long maskedCpu = Limits.getCpuTime() - maskedCpuStart;

kern__ApiCall__c sample =
[
		SELECT kern__Request__c
		FROM kern__ApiCall__c
		WHERE Id = :masked[0].Id
];
Boolean persisted = sample.kern__Request__c.contains('***SECRET***') && !sample.kern__Request__c.contains('hunter2');

Decimal baselinePerRecord = batchSize == 0 ? 0 : ((Decimal)baselineCpu / batchSize).setScale(2);
Decimal maskedPerRecord = batchSize == 0 ? 0 : ((Decimal)maskedCpu / batchSize).setScale(2);
Decimal overheadPerRecord = (maskedPerRecord - baselinePerRecord).setScale(2);
Decimal budgetShare = ((Decimal)maskedCpu / 10000 * 100).setScale(1);

System.debug('PERF_ROW: count=' + batchSize + ' baseline_cpu_ms=' + baselineCpu + ' baseline_wall_ms=' + baselineWall + ' masked_cpu_ms=' + maskedCpu + ' masked_wall_ms=' + maskedWall + ' baseline_per_record_ms=' + baselinePerRecord + ' masked_per_record_ms=' + maskedPerRecord + ' overhead_per_record_ms=' + overheadPerRecord + ' budget_share_pct=' + budgetShare + ' persisted_masked=' + persisted);

delete masked;
