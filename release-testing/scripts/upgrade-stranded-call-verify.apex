/**
 * Upgrade leg (a), after the release note's script: the stranded call reads Failed, no issue appeared; delete it
 *
 * Run after mark-stranded-outbound-calls-failed.apex on the upgraded org. An ad-hoc call is stored under the
 * framework's handler name (kern.UTIL_HttpClient.DefaultOutboundHandler), not its credential, so the baseline row is
 * found by its address, which names the credential. The call wrote a log entry, which lands after the baseline's own
 * transaction; upgrade-stranded-call-log-cleanup.apex deletes it.
 *
 * Run:
 *   sf apex run --file release-testing/scripts/upgrade-stranded-call-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */
List<kern__ApiCall__c> marked = [SELECT Id, kern__Status__c, kern__NextRetry__c, kern__Retries__c, kern__URL__c
		FROM kern__ApiCall__c WHERE kern__URL__c LIKE '%Baseline17DoesNotExist%'];
System.debug(LoggingLevel.ERROR, 'BASELINE17 after script ' + JSON.serialize(marked));
System.debug(LoggingLevel.ERROR, 'BASELINE17 issues='
		+ [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ApiCall__c IN :marked OR kern__ServiceName__c = 'Baseline17DoesNotExist']);
// The issues first: a call with an Open issue cannot be deleted, so the issues of these calls go too, whoever wrote them.
delete [SELECT Id FROM kern__ApiIssue__c WHERE kern__ApiCall__c IN :marked];
delete marked;
System.debug(LoggingLevel.ERROR, 'BASELINE17 left=' + [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__URL__c LIKE '%Baseline17DoesNotExist%']);
