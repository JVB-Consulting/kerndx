/**
 * Upgrade leg (a), before the upgrade: leave the call a 1.7 install strands
 *
 * Run on the 1.7.0-13 install, before the 1.8 upgrade. A GET with two retries to a Named Credential that does not exist
 * fails at the send point; on 1.7 that leaves the call at Retry with no Next Retry time, the shape the 1.8 release
 * note's filter (Status equals Retry, Next Retry empty) finds and its script marks Failed. The call is stored under
 * kern.UTIL_HttpClient.DefaultOutboundHandler; its address names the credential. Note the row's id from the log line.
 * After the upgrade: run mark-stranded-outbound-calls-failed.apex, then upgrade-stranded-call-verify.apex, then, 30
 * seconds later, upgrade-stranded-call-log-cleanup.apex.
 *
 * Run:
 *   sf apex run --file release-testing/scripts/upgrade-stranded-call-baseline.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */
kern.UTIL_HttpClient.get('Baseline17DoesNotExist', '/baseline').withRetry(2, 30).send();
List<kern__ApiCall__c> stranded = [SELECT Id, kern__Status__c, kern__NextRetry__c, kern__Retries__c, kern__ServiceName__c, kern__ErrorMessages__c
		FROM kern__ApiCall__c WHERE kern__Status__c = 'Retry' AND kern__NextRetry__c = null AND CreatedDate = TODAY];
System.debug(LoggingLevel.ERROR, 'BASELINE17 rows=' + stranded.size() + ' ' + JSON.serialize(stranded));
