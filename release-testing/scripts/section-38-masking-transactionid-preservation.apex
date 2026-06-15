// Section 38 — Subscriber masking: TransactionId / correlation-ID preservation.
//
// Regression guard for the original user-reported bug where
// 'parentTransactionId: "TID:1234567890123456"' was Luhn-redacted as a credit card
// number. The effective card rule on the framework objects (MaskPaymentCard) fires only
// on Luhn-VALID digit runs — the Luhn (mod-10) gate alone keeps arbitrary transaction
// IDs raw; there is no issuer-prefix filter on this surface.
//
// The payload below mixes a Luhn-VALID card number (must redact) with a longer
// digit run that is NOT Luhn-valid (must preserve) — a single insert proves both
// sides of the decision table.

Integer passCount = 0;
Integer failCount = 0;

// 4111111111111111 — Luhn-valid Visa test card (must redact)
// TID:1234567890123456 — 16 digits, Luhn sum 50 → NOT divisible by 10 (must preserve)
String payload = '{"parentTransactionId":"TID:1234567890123456","correlationId":"3258728f-d54c-4cd3-81b3-efb5859e5958","card":"4111111111111111"}';

kern__ApiCall__c call = new kern__ApiCall__c();
call.kern__ServiceName__c = 'MaskTransactionIdRegression';
call.kern__Direction__c = 'Inbound';
call.kern__Status__c = 'Completed';
call.kern__Request__c = payload;
insert call;

kern__ApiCall__c stored =
[
		SELECT kern__Request__c
		FROM kern__ApiCall__c
		WHERE Id = :call.Id
];
String storedRequest = stored.kern__Request__c;

Boolean passCardRedacted = !storedRequest.contains('4111111111111111');
Boolean passTransactionIdPreserved = storedRequest.contains('TID:1234567890123456');
Boolean passCorrelationIdPreserved = storedRequest.contains('3258728f-d54c-4cd3-81b3-efb5859e5958');

System.debug((passCardRedacted ? 'PASS: ' : 'FAIL: ') + 'Luhn-valid Visa 4111111111111111 redacted');
System.debug((passTransactionIdPreserved ? 'PASS: ' : 'FAIL: ') + 'Non-Luhn 16-digit TID:1234567890123456 preserved — would have been falsely redacted prior to the masking perf work');
System.debug((passCorrelationIdPreserved ? 'PASS: ' : 'FAIL: ') + 'UUID correlationId preserved (contains only short digit runs, never matched card pattern)');
System.debug('Stored: ' + storedRequest);

passCount += (passCardRedacted ? 1 : 0) + (passTransactionIdPreserved ? 1 : 0) + (passCorrelationIdPreserved ? 1 : 0);
failCount += (passCardRedacted ? 0 : 1) + (passTransactionIdPreserved ? 0 : 1) + (passCorrelationIdPreserved ? 0 : 1);

delete call;

System.debug('=== SECTION 38 SUMMARY: ' + passCount + ' passed, ' + failCount + ' failed ===');
