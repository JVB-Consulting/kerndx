List<kern__LogEntry__c> logs = [SELECT kern__Message__c, kern__ClassMethod__c, CreatedDate FROM kern__LogEntry__c WHERE kern__ClassMethod__c = 'MaskSanity.logEntry' ORDER BY CreatedDate DESC LIMIT 1];
if(logs.isEmpty()) {
	System.debug('FAIL: LogEntry not yet persisted');
} else {
	String msg = logs[0].kern__Message__c;
	Boolean passLogPassword = msg.contains('***SECRET***') && !msg.contains('hunter2');
	Boolean passLogCard = !msg.contains('4111-1111-1111-1111');
	System.debug((passLogPassword ? 'PASS: ' : 'FAIL: ') + 'LogEntry.Message password redacted');
	System.debug((passLogCard ? 'PASS: ' : 'FAIL: ') + 'LogEntry.Message card redacted');
	System.debug('Sample: ' + msg.left(200));
}
