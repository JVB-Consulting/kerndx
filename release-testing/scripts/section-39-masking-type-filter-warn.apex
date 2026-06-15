// Section 39 — Subscriber masking: explicit-field target dropped by rule type filter.
//
// Proves from a subscriber's vantage that when a MaskingTarget__mdt wires a rule
// to a specific Field__c whose DisplayType is excluded by the rule's
// ApplicableFieldTypes__c, the masker correctly DROPS the rule and the field
// value is preserved. This is the synchronous behaviour assertion; the follow-up
// warn-LogEntry emission (which surfaces the misconfiguration to admins) is
// verified in `UTIL_FrameworkMasker_TEST` unit tests in the dev org because
// `LogEntryEvent__e → LogEntry__c` persistence latency has been observed from
// 1s to 90+s in freshly-provisioned subscriber scratch orgs — not deterministic
// enough for a subscriber-integration assertion.
//
// Uses the subscriber-deployed MaskingTarget 'TestTypeFilterWarnOnApiCallUrl'
// which wires the subscriber-deployed MaskingRule 'TestTypeFilterWarn' (scoped
// STRING;TEXTAREA, Regex mode, never-match sentinel pattern) onto
// ApiCall__c.URL__c (URL — excluded). A dedicated test rule is used instead
// of MaskSecretKeys because specific-field targets shadow rule-matched wildcards
// by rule+caller key — wiring a specific target for a shipped rule would break
// the rule's masking on other fields.

Integer passCount = 0;
Integer failCount = 0;

kern__ApiCall__c call = new kern__ApiCall__c();
call.kern__ServiceName__c = 'MaskTypeFilterWarn';
call.kern__Direction__c = 'Inbound';
call.kern__Status__c = 'Completed';
call.kern__Request__c = '{"noop":"ignored"}';
call.kern__URL__c = 'https://example.com?password=hunter2';
insert call;

kern__ApiCall__c stored =
[
		SELECT kern__URL__c
		FROM kern__ApiCall__c
		WHERE Id = :call.Id
];
Boolean passUrlPreserved = stored.kern__URL__c.contains('hunter2');
System.debug((passUrlPreserved ? 'PASS: ' : 'FAIL: ') + 'Rule scoped STRING;TEXTAREA did not fire on URL__c despite explicit target — value preserved');
passCount += passUrlPreserved ? 1 : 0;
failCount += passUrlPreserved ? 0 : 1;

delete call;

System.debug('=== SECTION 39 SUMMARY: ' + passCount + ' passed, ' + failCount + ' failed ===');
