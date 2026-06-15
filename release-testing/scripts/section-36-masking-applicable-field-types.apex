// Section 36 — Subscriber masking: rule-level ApplicableFieldTypes narrowing.
//
// Proves from a subscriber's vantage that MaskSecretKeys (scoped STRING;TEXTAREA)
// and MaskPaymentCard (scoped STRING;TEXTAREA;ENCRYPTEDSTRING) skip fields whose
// DisplayType is not in their ApplicableFieldTypes list — even when the target is
// a wildcard that would otherwise match the field. (MaskPaymentCard replaces
// MaskCreditCard on the framework objects; same ApplicableFieldTypes scope.)
//
// Run
// ---
// sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-36-masking-applicable-field-types.apex

Integer passCount = 0;
Integer failCount = 0;

// The shipped MaskPaymentCard rule matches any Luhn-valid 13-19 digit run;
// 4111111111111111 is a classic Visa test number. MaskSecretKeys redacts
// JSON values under keys like 'password'.
kern__ApiCall__c call = new kern__ApiCall__c();
call.kern__ServiceName__c = 'MaskTypeFilter';
call.kern__Direction__c = 'Inbound';
call.kern__Status__c = 'Completed';
call.kern__Request__c = '{"password":"hunter2","card":"4111111111111111"}';
call.kern__URL__c = 'https://example.com/pay?password=hunter2&card=4111111111111111';
insert call;

kern__ApiCall__c stored =
[
		SELECT kern__Request__c,
				kern__URL__c
		FROM kern__ApiCall__c
		WHERE Id = :call.Id
];

Boolean passRequestSecret = stored.kern__Request__c.contains('***SECRET***') && !stored.kern__Request__c.contains('hunter2');
Boolean passRequestCard = !stored.kern__Request__c.contains('4111111111111111');
Boolean passUrlSecret = stored.kern__URL__c.contains('hunter2');
Boolean passUrlCard = stored.kern__URL__c.contains('4111111111111111');

System.debug((passRequestSecret ? 'PASS: ' : 'FAIL: ') + 'MaskSecretKeys fires on TEXTAREA field (Request__c) — value was redacted');
System.debug((passRequestCard ? 'PASS: ' : 'FAIL: ') + 'MaskPaymentCard fires on TEXTAREA field (Request__c) — Luhn-valid card redacted');
System.debug((passUrlSecret ? 'PASS: ' : 'FAIL: ') + 'MaskSecretKeys scoped STRING;TEXTAREA skips URL__c — hunter2 preserved');
System.debug((passUrlCard ? 'PASS: ' : 'FAIL: ') + 'MaskPaymentCard scoped STRING;TEXTAREA;ENCRYPTEDSTRING skips URL__c — card preserved');

passCount += (passRequestSecret ? 1 : 0) + (passRequestCard ? 1 : 0) + (passUrlSecret ? 1 : 0) + (passUrlCard ? 1 : 0);
failCount += (passRequestSecret ? 0 : 1) + (passRequestCard ? 0 : 1) + (passUrlSecret ? 0 : 1) + (passUrlCard ? 0 : 1);

delete call;

System.debug('=== SECTION 36 SUMMARY: ' + passCount + ' passed, ' + failCount + ' failed ===');
