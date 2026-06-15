// Section 37 — Subscriber masking: MinInputLength short-circuit + successor floor.
//
// Proves from a subscriber's vantage that the effective card rule on the framework
// objects is MaskPaymentCard (MinInputLength=13): values shorter than 13 characters
// skip the rule entirely (pattern not compiled, not matched, not evaluated), and a
// 13-digit Luhn-valid card IS redacted. The original MaskCreditCard rule
// (MinInputLength=15) would have skipped that 13-digit value, so Case B doubles as
// the takeover-effective probe: it fails if the payment-card successor is not the
// rule doing the work on ApiCall__c.
//
// NOTE (divergence states): predecessor tuning does NOT change Case B — the successor's
// own targets are never suppressed, so the 13-digit card still masks even when a tuned
// MaskCreditCard runs alongside it. Case B fails only when the successor itself is
// deactivated (RUNBOOK §2.2c step 3), tuned, or missing its surface target — investigate
// those as defects or known seeded states. This script asserts the pristine ship state.

Integer passCount = 0;
Integer failCount = 0;

// Case A: 12-char digit run — below MinInputLength=13 (and below the pattern's
// 13-digit minimum) — rule must skip; value preserved.
// ServiceName__c is STRING so ApplicableFieldTypes admits it.
kern__ApiCall__c shortCall = new kern__ApiCall__c();
shortCall.kern__ServiceName__c = '411111111111';
shortCall.kern__Direction__c = 'Inbound';
shortCall.kern__Status__c = 'Completed';
shortCall.kern__Request__c = '{}';
insert shortCall;

kern__ApiCall__c shortStored =
[
		SELECT kern__ServiceName__c
		FROM kern__ApiCall__c
		WHERE Id = :shortCall.Id
];
Boolean passShortSkipped = shortStored.kern__ServiceName__c == '411111111111';
System.debug((passShortSkipped ? 'PASS: ' : 'FAIL: ') + '12-char value below MinInputLength=13 skipped rule — value preserved');
passCount += passShortSkipped ? 1 : 0;
failCount += passShortSkipped ? 0 : 1;
delete shortCall;

// Case B: 4222222222222 is the canonical 13-digit Luhn-valid Visa test number.
// Length 13 >= MinInputLength 13 — MaskPaymentCard must fire and redact it.
// (Pre-1.1, MaskCreditCard's floor of 15 skipped 13-char values on this surface;
// this redaction proves the successor owns the framework objects.)
kern__ApiCall__c thirteenCall = new kern__ApiCall__c();
thirteenCall.kern__ServiceName__c = '4222222222222';
thirteenCall.kern__Direction__c = 'Inbound';
thirteenCall.kern__Status__c = 'Completed';
thirteenCall.kern__Request__c = '{}';
insert thirteenCall;

kern__ApiCall__c thirteenStored =
[
		SELECT kern__ServiceName__c
		FROM kern__ApiCall__c
		WHERE Id = :thirteenCall.Id
];
Boolean passThirteenMasked = !thirteenStored.kern__ServiceName__c.contains('4222222222222');
System.debug((passThirteenMasked ? 'PASS: ' : 'FAIL: ') + '13-digit Luhn-valid card at MinInputLength=13 redacted — MaskPaymentCard owns the surface');
passCount += passThirteenMasked ? 1 : 0;
failCount += passThirteenMasked ? 0 : 1;
delete thirteenCall;

// Case C: value of length >= 13 containing a Luhn-valid 16-digit card — rule must fire.
//
// 4111111111111111 is 16 digits, Luhn-valid. Total string length 16 >= 13.
kern__ApiCall__c longCall = new kern__ApiCall__c();
longCall.kern__ServiceName__c = '4111111111111111';
longCall.kern__Direction__c = 'Inbound';
longCall.kern__Status__c = 'Completed';
longCall.kern__Request__c = '{}';
insert longCall;

kern__ApiCall__c longStored =
[
		SELECT kern__ServiceName__c
		FROM kern__ApiCall__c
		WHERE Id = :longCall.Id
];
Boolean passLongMasked = !longStored.kern__ServiceName__c.contains('4111111111111111');
System.debug((passLongMasked ? 'PASS: ' : 'FAIL: ') + '16-char value above MinInputLength=13 with Luhn-valid Visa number — card redacted');
passCount += passLongMasked ? 1 : 0;
failCount += passLongMasked ? 0 : 1;
delete longCall;

System.debug('=== SECTION 37 SUMMARY: ' + passCount + ' passed, ' + failCount + ' failed ===');
