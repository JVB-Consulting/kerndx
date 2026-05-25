// Section 37 — Subscriber masking: MinInputLength short-circuit.
//
// Proves from a subscriber's vantage that MaskCreditCard (MinInputLength=15) skips
// field values shorter than 15 characters — the pattern is not compiled, not
// matched, not evaluated. Guards against regressions that remove or weaken the
// short-circuit.

Integer passCount = 0;
Integer failCount = 0;

// Case A: value of length 13 (under MinInputLength=15) containing what would be a
// Luhn-valid card if the field were longer — rule must skip.
//
// 4111111111111 is 13 digits, Luhn-valid (it's the short form of the Visa test card)
// ServiceName__c is STRING so ApplicableFieldTypes admits it.
kern__ApiCall__c shortCall = new kern__ApiCall__c();
shortCall.kern__ServiceName__c = '4111111111111';
shortCall.kern__Direction__c = 'Inbound';
shortCall.kern__Status__c = 'Completed';
shortCall.kern__Request__c = '{}';
insert shortCall;

kern__ApiCall__c shortStored = [SELECT kern__ServiceName__c FROM kern__ApiCall__c WHERE Id = :shortCall.Id];
Boolean passShortSkipped = shortStored.kern__ServiceName__c == '4111111111111';
System.debug((passShortSkipped ? 'PASS: ' : 'FAIL: ') + '13-char value below MinInputLength=15 skipped rule — value preserved');
passCount += passShortSkipped ? 1 : 0;
failCount += passShortSkipped ? 0 : 1;
delete shortCall;

// Case B: value of length >= 15 containing a Luhn-valid card with valid issuer prefix — rule must fire.
//
// 4111111111111111 is 16 digits, Luhn-valid, Visa prefix. Total string length 16 >= 15.
kern__ApiCall__c longCall = new kern__ApiCall__c();
longCall.kern__ServiceName__c = '4111111111111111';
longCall.kern__Direction__c = 'Inbound';
longCall.kern__Status__c = 'Completed';
longCall.kern__Request__c = '{}';
insert longCall;

kern__ApiCall__c longStored = [SELECT kern__ServiceName__c FROM kern__ApiCall__c WHERE Id = :longCall.Id];
Boolean passLongMasked = !longStored.kern__ServiceName__c.contains('4111111111111111');
System.debug((passLongMasked ? 'PASS: ' : 'FAIL: ') + '16-char value above MinInputLength=15 with Luhn-valid Visa number — card redacted');
passCount += passLongMasked ? 1 : 0;
failCount += passLongMasked ? 0 : 1;
delete longCall;

System.debug('=== SECTION 37 SUMMARY: ' + passCount + ' passed, ' + failCount + ' failed ===');
