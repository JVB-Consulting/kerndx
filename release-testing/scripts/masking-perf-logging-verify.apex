// Subscriber masking perf logging — verify. Companion to masking-perf-logging-setup.apex.
// Queries kern__LogEntry__c for the aggregate masker performance entries emitted by the
// setup step and asserts format + content.
//
// Run after setup, with a short gap for async LogEntryEvent__e → LogEntry__c persistence.

Integer passCount = 0;
Integer failCount = 0;

List<kern__LogEntry__c> entries =
[
	SELECT kern__Message__c, kern__ClassMethod__c, kern__LogLevel__c, kern__DurationMs__c, CreatedDate
	FROM kern__LogEntry__c
	WHERE kern__ClassMethod__c LIKE '%UTIL_MaskerPerformanceTimer/%ApiCall__c'
	ORDER BY CreatedDate DESC
	LIMIT 5
];

Boolean passFound = !entries.isEmpty();
System.debug((passFound ? 'PASS: ' : 'FAIL: ') + 'Masker perf LogEntry rows found (' + entries.size() + ')');
passCount += passFound ? 1 : 0;
failCount += passFound ? 0 : 1;

if(passFound)
{
	kern__LogEntry__c entry = entries[0];

	Boolean passClassMethod = entry.kern__ClassMethod__c.contains('UTIL_MaskerPerformanceTimer/') && entry.kern__ClassMethod__c.endsWith('ApiCall__c');
	System.debug((passClassMethod ? 'PASS: ' : 'FAIL: ') + 'ClassMethod carries target sObject: ' + entry.kern__ClassMethod__c);
	passCount += passClassMethod ? 1 : 0;
	failCount += passClassMethod ? 0 : 1;

	Boolean passMessage = entry.kern__Message__c != null && entry.kern__Message__c.contains('Masking on') && entry.kern__Message__c.contains('ApiCall__c');
	System.debug((passMessage ? 'PASS: ' : 'FAIL: ') + 'Message describes sObject: ' + entry.kern__Message__c);
	passCount += passMessage ? 1 : 0;
	failCount += passMessage ? 0 : 1;

	Boolean passDuration = entry.kern__DurationMs__c != null && entry.kern__DurationMs__c >= 0;
	System.debug((passDuration ? 'PASS: ' : 'FAIL: ') + 'DurationMs captured: ' + entry.kern__DurationMs__c);
	passCount += passDuration ? 1 : 0;
	failCount += passDuration ? 0 : 1;
}

// Cleanup — disable the opt-in so subsequent subscriber tests start from the default-OFF state.
kern__LogSetting__c setting = kern__LogSetting__c.getOrgDefaults();
setting.kern__EnableMaskerPerformanceLogging__c = false;
upsert setting;

System.debug('=== SUMMARY: ' + passCount + ' passed, ' + failCount + ' failed ===');
