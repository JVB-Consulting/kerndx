// Subscriber masking perf logging — setup. Verifies the managed package's
// UTIL_MaskerPerformanceTimer fires from a subscriber org when the new LogSetting__c
// fields opt-in to masker performance logging.
//
// Expected behaviour:
// - With EnableMaskerPerformanceLogging__c = true AND MaskerPerformanceThresholdMs__c = 0,
//   every trigger batch that invokes the masker emits one aggregate LogEntryEvent__e
//   whose ClassMethod__c = 'UTIL_MaskerPerformanceTimer/<sObjectName>'.
// - Default off — subscribers who do nothing pay zero event volume.
//
// Run setup first, wait a few seconds for async event persistence, then run the -verify
// companion script.
//
// Run
// ---
// sf apex run -o <ORG_ALIAS> -f release-testing/scripts/masking-perf-logging-setup.apex

// Enable the two new LogSetting__c fields at org level.
kern__LogSetting__c setting = kern__LogSetting__c.getOrgDefaults();
if(setting.Id == null)
{
	setting = new kern__LogSetting__c(SetupOwnerId = UserInfo.getOrganizationId());
}
setting.kern__EnableMaskerPerformanceLogging__c = true;
setting.kern__MaskerPerformanceThresholdMs__c = 0;
upsert setting;

// Bulk insert ApiCall__c to exercise the masker pre-step. Threshold 0 means every batch emits.
Integer batchSize = 50;
String sampleRequest = '{"user":"alice@example.com","password":"hunter2","card":"4111-1111-1111-1111"}';

List<kern__ApiCall__c> records = new List<kern__ApiCall__c>();
for(Integer i = 0; i < batchSize; i++)
{
	kern__ApiCall__c call = new kern__ApiCall__c();
	call.kern__ServiceName__c = 'MaskerPerfLogging';
	call.kern__Direction__c = 'Inbound';
	call.kern__Status__c = 'Completed';
	call.kern__Request__c = sampleRequest.replace('alice@', 'alice' + i + '@');
	records.add(call);
}
insert records;

System.debug('Setup complete: ' + batchSize + ' records inserted with masking; threshold = 0');
System.debug('Masker performance LogEntryEvent__e published — await async persistence then run verify script');

delete records;
