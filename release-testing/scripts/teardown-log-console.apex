// SPDX-License-Identifier: BUSL-1.1
//
// Log Console e2e teardown - deletes every row seeded by seed-log-console.apex AND seed-log-console-bulk.apex.
// Covers fingerprinted rows ('e2e-' Fingerprint__c) AND the null-fingerprint forensic rows that carry an
// 'e2e-' CorrelationId__c or TransactionId__c (chain hops, correlated requests, derived-fold input, calendar
// rows), plus the seeded AsyncChainExecution__c chain record. Namespace-robust (LogEntry__c in a
// no-namespace org, kern__LogEntry__c in a managed subscriber org) and idempotent (safe to re-run).

String ns = '';
for(String key : Schema.getGlobalDescribe().keySet())
{
	if(key.endsWith('logentry__c'))
	{
		ns = key.substring(0, key.length() - 'logentry__c'.length());
		break;
	}
}

String fp = ns + 'Fingerprint__c';
String corr = ns + 'CorrelationId__c';
String txn = ns + 'TransactionId__c';
List<SObject> seeded = Database.query('SELECT Id FROM ' + ns + 'LogEntry__c WHERE ' + fp + ' LIKE \'%e2e-%\' OR ' + corr + ' LIKE \'e2e-%\' OR ' + txn + ' LIKE \'e2e-%\'');
if(!seeded.isEmpty())
{
	delete seeded;
}

List<SObject> chains = Database.query('SELECT Id FROM ' + ns + 'AsyncChainExecution__c WHERE ' + ns + 'CorrelationId__c LIKE \'e2e-%\'');
if(!chains.isEmpty())
{
	delete chains;
}

// Also purge the hero-loop capture demo rows (capture-seed.apex section 3): 'demo-' markers plus its
// fixed fulfilment correlation constant. Left behind, they sit inside part10's query windows and its
// occurrence-ranked problem picks can select a demo problem instead of the e2e fixture's.
String captureCorr = '7f3a9c14b8d2e5f6a0c1b2d3e4f50617';
List<SObject> captureDemo = Database.query('SELECT Id FROM ' + ns + 'LogEntry__c WHERE ' + fp + ' LIKE \'%demo-%\' OR ' + txn + ' LIKE \'demo-%\' OR ' + corr + ' = :captureCorr');
if(!captureDemo.isEmpty())
{
	delete captureDemo;
}
List<SObject> captureChains = Database.query('SELECT Id FROM ' + ns + 'AsyncChainExecution__c WHERE ' + ns + 'CorrelationId__c = :captureCorr');
if(!captureChains.isEmpty())
{
	delete captureChains;
}

System.debug('TEARDOWN_LOG_CONSOLE ns=[' + ns + '] logRows=' + seeded.size() + ' chainRows=' + chains.size() + ' captureDemoRows=' + captureDemo.size() + ' captureChainRows=' + captureChains.size());
