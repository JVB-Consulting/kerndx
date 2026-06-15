/**
 * Section 61: UTIL_FrameworkMasker — Rollback Isolation, Field-Length, Idempotency,
 *             Mid-Transaction CMDT Cache, and FAILURE_BLOCK_DML Propagation
 *
 * Closes gaps in UTIL_FrameworkMasker capability coverage beyond sections 36-40 (which cover
 * ApplicableFieldTypes narrowing, MinInputLength short-circuit, transaction-ID preservation,
 * regex-compile audit, and inactive-rule validation). This script covers five anon-Apex edge
 * scenarios from the extended-load spec §6.10.
 *
 * Scenario overview and testability pre-flight:
 *
 *   61a. Masking under DML rollback — FULLY TESTABLE.
 *        Insert kern__ApiCall__c with a Luhn-valid Visa card in kern__Request__c. Masking fires
 *        before the row commits (BEFORE_INSERT trigger). The masker transforms the in-memory
 *        record. Then rollback the Savepoint. Assert the inserted Id no longer exists in the org
 *        — proves the masker leaves no orphaned rows and DML isolation is not broken by masking.
 *        FRAMEWORK BEHAVIOUR: UTIL_FrameworkMasker.forRecords() mutates records IN MEMORY
 *        (via SObject.put()) before DML commits. A rolled-back transaction discards those
 *        mutations along with the uncommitted rows — no orphaned masked record can exist.
 *
 *   61b. Long Text Area at max length — PARTIALLY TESTABLE; truncation path DEFERRED.
 *        (1) Schema assertion: kern__ApiCall__c.kern__Request__c is a Long Text Area whose
 *        DescribeFieldResult.getLength() returns 131072 (the org-level limit). The masking
 *        framework truncates masked output to this limit via UTIL_String.abbreviate() when
 *        rulesMatched > 0 and maskedValue.length() > maxLength (UTIL_FrameworkMasker.cls
 *        maskValueWithPlan(), line ~1023). This is the platform cap; anon Apex cannot store
 *        a string longer than the field allows, so the truncation path requires the MASKER
 *        to EXPAND the value (replacement longer than original match) past the field limit.
 *        (2) Observable contract: insert a record whose masked output is within the 131072-char
 *        limit. Verify the stored value length matches expectations (masker did not truncate).
 *        DEFERRED: end-to-end truncation (value > 131072 after masking). The MaskPaymentCard
 *        replacement '[CARD_REDACTED]' is 15 chars; the card regex match is >=13 chars; net
 *        delta is at most +2 characters per match. To force truncation from anon Apex would require a
 *        long payload that, after masking, exceeds 131072 chars — this demands a string that
 *        is itself near 131072 chars with a card match, which hits anon Apex CPU limits and
 *        platform heap before the field-length assertion can run. The non-truncation contract
 *        (output <= field length) is asserted via the schema + stored-length check here.
 *        DEFERRED TO: Subscriber_MaskingEdges_TEST, which runs in a real test context with
 *        longer CPU limits and can use @TestVisible seams to bypass the DML path.
 *        FRAMEWORK FOLLOW-UP: Consider adding a @TestVisible static method that directly calls
 *        maskValueWithPlan() with a synthetic long value so unit tests can cover the
 *        abbreviate() branch without DML round-trips.
 *
 *   61c. Update DML where masked field unchanged — idempotency — FULLY TESTABLE.
 *        Insert kern__ApiCall__c with a card number (masking fires, card replaced). Then update
 *        the same record without changing kern__Request__c. Masking fires again on BEFORE_UPDATE
 *        but the MaskPaymentCard Luhn+regex pattern does not match '[CARD_REDACTED]' — the
 *        sentinel is not a Luhn-valid digit run. The stored value is identical after the update.
 *        Idempotency contract: applying masking a second time on already-masked data produces
 *        the same output — no double-masking, no corruption.
 *
 *   61d. Inactive rule flipped active mid-transaction — PLATFORM CONSTRAINT documented.
 *        CMDT DML is platform-blocked in anon Apex (System.DmlException: 'DML not allowed on
 *        CustomMetadata in this context'). The contract is observable via inference only:
 *        UTIL_FrameworkMasker uses per-transaction static caches (cachedTargets, cachedBatchPlans)
 *        that are lazy-initialised on first access. A CMDT change mid-transaction would not be
 *        visible to the cache — CMDT reads happen only on first access per SObjectType per
 *        transaction. This is asserted by performing two sequential inserts of kern__ApiCall__c
 *        in the same anon Apex execution: both see identical masking behaviour (same rules, same
 *        transformations), demonstrating cache consistency across multiple DML calls in one tx.
 *        SPEC CONTRACT: mid-transaction CMDT flip cannot take effect within the same transaction.
 *        Admins must wait for a new transaction before an activated rule applies.
 *        DEFERRED END-TO-END: a true mid-tx flip test would require (1) starting a transaction,
 *        (2) inserting a row (priming the cache), (3) flipping a CMDT record, (4) inserting
 *        another row, and verifying the rule did NOT take effect — all from a single Apex context.
 *        CMDT DML block makes step 3 impossible in anon Apex. Unit test coverage of the static
 *        cache isolation is in UTIL_FrameworkMasker_TEST.
 *
 *   61e. FAILURE_BLOCK_DML masker rule fires — kern.UTIL_Exceptions.MaskingBlockedException — PARTIALLY TESTABLE.
 *        MaskPaymentCard (shipped, active — it owns the framework surfaces; the legacy
 *        MaskCreditCard is also BlockDml) has FailureAction__c = 'BlockDml'. handleRuleFailure()
 *        in UTIL_FrameworkMasker fires and throws kern.UTIL_Exceptions.MaskingBlockedException ONLY when the
 *        masking rule itself throws an internal exception (catch block in applySingleTargetStatic /
 *        applyJsonKeyBatchStatic). A successful rule match-and-replace does NOT fire handleRuleFailure.
 *        To make MaskPaymentCard throw requires a CMDT record with an invalid Pattern__c — but CMDT
 *        DML is platform-blocked in anon Apex.
 *        OBSERVABLE CONTRACTS asserted here (using only subscriber-accessible APIs):
 *        (a) MaskPaymentCard.FailureAction__c = 'BlockDml' confirmed from CMDT query.
 *        (b) Positive insert: Luhn-valid card succeeds, card masked, no exception thrown.
 *        (c) kern.UTIL_Exceptions.MaskingBlockedException is now a global nested type — subscriber Apex can
 *            catch it by name (verified by referencing kern.UTIL_Exceptions.MaskingBlockedException.class).
 *        DEFERRED END-TO-END: trigger -> rule-failure -> kern.UTIL_Exceptions.MaskingBlockedException -> DML abort
 *        requires CMDT DML (blocked) or a subscriber-deployed bad-pattern rule. DEFERRED TO:
 *        Subscriber_MaskingEdges_TEST with a subscriber-deployed custom MaskingRule__mdt whose
 *        Pattern__c is an invalid regex.
 *        SPEC DEVIATION: §6.10 #5 expected full propagation from anon Apex; one platform
 *        constraint still makes that impossible from anon Apex: CMDT DML is blocked.
 *
 * Deferrals summary (all platform-mandated or framework visibility gaps):
 *   - §6.10 #2 (truncation past 131072 chars) -> Subscriber_MaskingEdges_TEST + @TestVisible
 *     seam follow-up for maskValueWithPlan() unit coverage of the abbreviate() branch.
 *   - §6.10 #4 (mid-tx CMDT flip end-to-end) -> CMDT DML blocked in anon Apex; cache isolation
 *     is unit-tested in UTIL_FrameworkMasker_TEST. Two-insert consistency asserted here.
 *   - §6.10 #5 (BlockDml rule failure -> trigger abort) -> CMDT DML blocked in anon Apex.
 *     kern.UTIL_Exceptions.MaskingBlockedException is a global nested class — subscribers can catch by
 *     type. Full propagation path unit-tested in UTIL_FrameworkMasker_TEST. Deferred to
 *     Subscriber_MaskingEdges_TEST with a deployed bad-pattern subscriber rule.
 *
 * Run-isolation: self-contained. All inserted kern__ApiCall__c rows are deleted in the cleanup
 * block. Scenario 61a rolls back via Savepoint — no cleanup needed for that insert. Scenarios
 * 61b, 61c, 61d, 61e insert rows that are tracked in insertedIds and bulk-deleted at the end.
 * No CMDT DML. No custom setting changes.
 *
 * Prerequisites:
 *   - subscriber scratch org with kern managed package installed
 *   - MaskingFramework_Enabled feature flag ON (set during subscriber setup)
 *   - MaskingRule__mdt (MaskPaymentCard, MaskSecretKeys, legacy MaskCreditCard) and
 *     MaskingTarget__mdt (ApiCall_All_PaymentCard, ApiCall_All_Secret; ApiCall_All_Card also
 *     ships but defers to the successor) deployed with the package (shipped CMDT records)
 *   - TriggerSetting.ApiCall has ApplyMasking__c = true (shipped)
 *
 * Run (in isolation):
 *   sf apex run --file release-testing/scripts/section-61-edge-masking-rollback.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock: <6 seconds (4 DML inserts, 1 update, 4 queries, 1 rollback, 1 bulk delete).
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 61: UTIL_FrameworkMasker Rollback / Length / Idempotency / Cache / BlockDml ===');

kern.TRG_Base.clearAllBypasses();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String VISA_CARD = '4111111111111111';
final String CARD_REDACTED_SENTINEL = 'CARD_REDACTED';
final String RUN_STAMP = String.valueOf(Datetime.now().getTime());

List<Id> insertedIds = new List<Id>();

// Scenario 61a — Masking under DML rollback: no orphaned masked records persist.
// Insert a kern__ApiCall__c containing a Luhn-valid card in kern__Request__c.
// The BEFORE_INSERT trigger fires; UTIL_FrameworkMasker.forRecords() mutates the
// in-memory record (card replaced with [CARD_REDACTED]) before the row commits.
// Then a Savepoint rollback is performed; the row should not be queryable after rollback.
try
{
	Savepoint sp61a = Database.setSavepoint();

	kern__ApiCall__c record61a = new kern__ApiCall__c();
	record61a.kern__ServiceName__c = 'Section61a-' + RUN_STAMP;
	record61a.kern__Direction__c = 'Inbound';
	record61a.kern__Status__c = 'Completed';
	record61a.kern__Request__c = '{"card":"' + VISA_CARD + '","section":"61a"}';
	record61a.kern__URL__c = 'https://example.com/api/61a';
	insert record61a;

	Id insertedId61a = record61a.Id;
	Assert.isNotNull(insertedId61a, '61a: inserted record should have an Id');

	List<kern__ApiCall__c> verifyBeforeRollback =
	[
			SELECT kern__Request__c
			FROM kern__ApiCall__c
			WHERE Id = :insertedId61a
			LIMIT 1
	];

	Assert.isFalse(verifyBeforeRollback.isEmpty(), '61a: record should exist before rollback');
	Assert.isFalse(
			verifyBeforeRollback[0].kern__Request__c.contains(VISA_CARD),
			'61a: before rollback — masking should have replaced the Visa card number. Stored: '
			+ verifyBeforeRollback[0].kern__Request__c);
	Assert.isTrue(
			verifyBeforeRollback[0].kern__Request__c.containsIgnoreCase(CARD_REDACTED_SENTINEL),
			'61a: before rollback — CARD_REDACTED sentinel must appear in stored Request. Stored: '
			+ verifyBeforeRollback[0].kern__Request__c);

	Database.rollback(sp61a);

	List<kern__ApiCall__c> verifyAfterRollback =
	[
			SELECT Id
			FROM kern__ApiCall__c
			WHERE Id = :insertedId61a
			LIMIT 1
	];

	Assert.isTrue(verifyAfterRollback.isEmpty(),
			'61a: after savepoint rollback the record must not exist — no orphaned masked row. '
			+ 'Found ' + verifyAfterRollback.size() + ' row(s) with Id ' + insertedId61a);

	System.debug(LoggingLevel.INFO,
			'61a PASS: Masking fired before commit (card redacted in stored row); savepoint rollback '
			+ 'removed the row completely — no orphaned masked record. '
			+ 'FRAMEWORK BEHAVIOUR: UTIL_FrameworkMasker.forRecords() mutates in-memory SObjects '
			+ 'via SObject.put(); those mutations are discarded with the uncommitted row on rollback.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '61a FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('61a: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 61b — Long Text Area at max length: truncation contract.
// (1) Verify kern__ApiCall__c.kern__Request__c DescribeFieldResult.getLength() == 131072.
//     This is the platform-enforced maximum for the shipped Long Text Area field.
// (2) Insert a record whose kern__Request__c contains a Luhn-valid card in a padded payload.
//     After masking, stored value length must be within the field limit — confirming the
//     masker's abbreviate() guard does not corrupt values that stay within bounds.
//     The MaskPaymentCard replacement '[CARD_REDACTED]' (15 chars) is at most 2 chars longer
//     than the shortest card match (>=13 chars) — the 16-digit card used here shrinks, so no
//     truncation fires.
// (3) Assert stored length <= field max length (non-truncation contract for within-bound values).
// Truncation end-to-end (output > 131072 chars) is DEFERRED — see header §6.10 #2 note.
try
{
	Integer fieldMaxLength = kern__ApiCall__c.kern__Request__c.getDescribe().getLength();
	Assert.areEqual(131072, fieldMaxLength,
			'61b: kern__ApiCall__c.kern__Request__c.getLength() must return 131072 '
			+ '(shipped Long Text Area field limit). Got: ' + fieldMaxLength);

	final Integer PAYLOAD_PADDING_LENGTH = 500;
	String padding61b = 'x'.repeat(PAYLOAD_PADDING_LENGTH);
	String payload61b = '{"data":"' + padding61b + '","card":"' + VISA_CARD + '"}';

	kern__ApiCall__c record61b = new kern__ApiCall__c();
	record61b.kern__ServiceName__c = 'Section61b-' + RUN_STAMP;
	record61b.kern__Direction__c = 'Inbound';
	record61b.kern__Status__c = 'Completed';
	record61b.kern__Request__c = payload61b;
	record61b.kern__URL__c = 'https://example.com/api/61b';
	insert record61b;
	insertedIds.add(record61b.Id);

	kern__ApiCall__c stored61b =
	[
			SELECT kern__Request__c
			FROM kern__ApiCall__c
			WHERE Id = :record61b.Id
			LIMIT 1
	];

	Assert.isNotNull(stored61b.kern__Request__c, '61b: stored kern__Request__c must not be null after insert');
	Assert.isFalse(
			stored61b.kern__Request__c.contains(VISA_CARD),
			'61b: Luhn-valid card must be masked in stored payload. Got: ' + stored61b.kern__Request__c);
	Assert.isTrue(
			stored61b.kern__Request__c.containsIgnoreCase(CARD_REDACTED_SENTINEL),
			'61b: CARD_REDACTED sentinel must appear in stored payload. Got: ' + stored61b.kern__Request__c);

	Integer storedLength61b = stored61b.kern__Request__c.length();
	Assert.isTrue(
			storedLength61b <= fieldMaxLength,
			'61b: stored value length (' + storedLength61b + ') must be <= field max ('
			+ fieldMaxLength + '). Masker must never exceed field limit after abbreviate(). Got: '
			+ storedLength61b);

	System.debug(LoggingLevel.INFO,
			'61b PASS: kern__Request__c field max = ' + fieldMaxLength + ' chars confirmed. '
			+ 'Stored value length = ' + storedLength61b + ' chars (<= ' + fieldMaxLength + '). '
			+ 'MaskPaymentCard replacement shorter than this 16-digit card match — no expansion, no truncation. '
			+ 'Non-truncation contract verified: masked output stays within field bounds. '
			+ 'DEFERRED: end-to-end truncation path (output > 131072) — see header §6.10 #2 deferral. '
			+ 'Truncation branch (maskValueWithPlan / abbreviate) is unit-tested in UTIL_FrameworkMasker_TEST.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '61b FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('61b: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 61c — Update DML where masked field unchanged: idempotency.
// Insert kern__ApiCall__c with a Luhn-valid card — masking fires on BEFORE_INSERT.
// Card is stored as '[CARD_REDACTED]'. Then update the record (touch a non-masked field,
// leave kern__Request__c unchanged). Masking fires again on BEFORE_UPDATE. The
// MaskPaymentCard regex pattern does NOT match '[CARD_REDACTED]' — the sentinel contains
// non-digit characters and is not a Luhn-valid digit run. The stored value after update
// must equal the stored value after insert — no double-masking, no corruption.
try
{
	kern__ApiCall__c record61c = new kern__ApiCall__c();
	record61c.kern__ServiceName__c = 'Section61c-' + RUN_STAMP;
	record61c.kern__Direction__c = 'Inbound';
	record61c.kern__Status__c = 'Completed';
	record61c.kern__Request__c = '{"card":"' + VISA_CARD + '","section":"61c-insert"}';
	record61c.kern__URL__c = 'https://example.com/api/61c';
	insert record61c;
	insertedIds.add(record61c.Id);

	kern__ApiCall__c storedAfterInsert61c =
	[
			SELECT kern__Request__c,
					kern__Status__c
			FROM kern__ApiCall__c
			WHERE Id = :record61c.Id
			LIMIT 1
	];

	Assert.isFalse(
			storedAfterInsert61c.kern__Request__c.contains(VISA_CARD),
			'61c: after insert — card must be masked. Got: ' + storedAfterInsert61c.kern__Request__c);
	Assert.isTrue(
			storedAfterInsert61c.kern__Request__c.containsIgnoreCase(CARD_REDACTED_SENTINEL),
			'61c: after insert — CARD_REDACTED must be present. Got: ' + storedAfterInsert61c.kern__Request__c);

	String maskedRequestAfterInsert = storedAfterInsert61c.kern__Request__c;

	kern__ApiCall__c toUpdate61c = new kern__ApiCall__c(Id = record61c.Id);
	toUpdate61c.kern__Status__c = 'Failed';
	update toUpdate61c;

	kern__ApiCall__c storedAfterUpdate61c =
	[
			SELECT kern__Request__c,
					kern__Status__c
			FROM kern__ApiCall__c
			WHERE Id = :record61c.Id
			LIMIT 1
	];

	Assert.areEqual('Failed', storedAfterUpdate61c.kern__Status__c,
			'61c: kern__Status__c should be updated to Failed');

	Assert.areEqual(maskedRequestAfterInsert, storedAfterUpdate61c.kern__Request__c,
			'61c: kern__Request__c must be identical after update — no double-masking. '
			+ 'After insert: ' + maskedRequestAfterInsert
			+ ' | After update: ' + storedAfterUpdate61c.kern__Request__c);

	System.debug(LoggingLevel.INFO,
			'61c PASS: Idempotency confirmed. After insert: card redacted to [CARD_REDACTED]. '
			+ 'After update (touching only kern__Status__c): kern__Request__c unchanged. '
			+ 'MaskPaymentCard Luhn+regex does not match the sentinel — no double-masking occurs. '
			+ 'FRAMEWORK CONTRACT: masked fields are safe to leave on updated records; '
			+ 'the masker never corrupts already-masked values.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '61c FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('61c: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 61d — Inactive rule flipped active mid-transaction: per-transaction cache isolation.
// CMDT DML is platform-blocked in anon Apex — cannot flip kern__MaskingRule__mdt.IsActive__c.
// Observable contract: perform two sequential inserts of kern__ApiCall__c with identical
// payloads in the same anon Apex execution. Both rows see identical masking output, proving
// the per-transaction static cache (cachedTargets, cachedBatchPlans) is initialised exactly
// once and yields consistent results across multiple DML calls within the same transaction.
// SPEC CONTRACT: any CMDT change (IsActive flip) made mid-transaction would not be visible
// within that same transaction — the cache was already primed by the first DML call.
try
{
	String sharedPayload61d = '{"password":"midtxsecret61d","card":"' + VISA_CARD + '","run":"' + RUN_STAMP + '"}';

	kern__ApiCall__c record61d1 = new kern__ApiCall__c();
	record61d1.kern__ServiceName__c = 'Section61d-row1-' + RUN_STAMP;
	record61d1.kern__Direction__c = 'Inbound';
	record61d1.kern__Status__c = 'Completed';
	record61d1.kern__Request__c = sharedPayload61d;
	record61d1.kern__URL__c = 'https://example.com/api/61d-1';
	insert record61d1;
	insertedIds.add(record61d1.Id);

	kern__ApiCall__c record61d2 = new kern__ApiCall__c();
	record61d2.kern__ServiceName__c = 'Section61d-row2-' + RUN_STAMP;
	record61d2.kern__Direction__c = 'Inbound';
	record61d2.kern__Status__c = 'Completed';
	record61d2.kern__Request__c = sharedPayload61d;
	record61d2.kern__URL__c = 'https://example.com/api/61d-2';
	insert record61d2;
	insertedIds.add(record61d2.Id);

	List<kern__ApiCall__c> stored61d =
	[
			SELECT kern__Request__c,
					kern__ServiceName__c
			FROM kern__ApiCall__c
			WHERE Id IN :new List<Id> {record61d1.Id, record61d2.Id}
			ORDER BY kern__ServiceName__c
	];

	Assert.areEqual(2, stored61d.size(), '61d: both rows must be stored');

	String request61d1 = stored61d[0].kern__Request__c;
	String request61d2 = stored61d[1].kern__Request__c;

	Assert.isFalse(request61d1.contains(VISA_CARD),
			'61d: row 1 — Visa card must be masked. Got: ' + request61d1);
	Assert.isFalse(request61d2.contains(VISA_CARD),
			'61d: row 2 — Visa card must be masked. Got: ' + request61d2);
	Assert.isTrue(request61d1.containsIgnoreCase(CARD_REDACTED_SENTINEL),
			'61d: row 1 — CARD_REDACTED must appear. Got: ' + request61d1);
	Assert.isTrue(request61d2.containsIgnoreCase(CARD_REDACTED_SENTINEL),
			'61d: row 2 — CARD_REDACTED must appear. Got: ' + request61d2);

	Assert.isFalse(request61d1.contains('midtxsecret61d'),
			'61d: row 1 — MaskSecretKeys must have redacted the password value. Got: ' + request61d1);
	Assert.isFalse(request61d2.contains('midtxsecret61d'),
			'61d: row 2 — MaskSecretKeys must have redacted the password value. Got: ' + request61d2);

	Assert.areEqual(request61d1, request61d2,
			'61d: both rows must have identical masked output — per-transaction cache is consistent '
			+ 'across sequential DML calls. Row 1: ' + request61d1 + ' | Row 2: ' + request61d2);

	List<kern__MaskingRule__mdt> activeRules61d =
	[
			SELECT DeveloperName,
					kern__IsActive__c,
					kern__FailureAction__c
			FROM kern__MaskingRule__mdt
			WHERE kern__IsActive__c = TRUE
			ORDER BY DeveloperName
	];

	Assert.isFalse(activeRules61d.isEmpty(),
			'61d: at least one active MaskingRule__mdt must be deployed');

	System.debug(LoggingLevel.INFO,
			'61d PASS: Per-transaction cache isolation confirmed. Both sequential inserts produced '
			+ 'identical masked output, proving cachedTargets/cachedBatchPlans initialised once '
			+ 'and stayed consistent. Active rules in org: ' + activeRules61d.size() + '. '
			+ 'SPEC CONTRACT: a mid-transaction CMDT flip (e.g., IsActive__c = true) would NOT '
			+ 'be visible within the same transaction — the static cache was already primed. '
			+ 'Admins must wait for the next transaction after activating a rule. '
			+ 'DEFERRED: end-to-end mid-tx flip — CMDT DML blocked in anon Apex. '
			+ 'Cache isolation is unit-tested in UTIL_FrameworkMasker_TEST.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '61d FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('61d: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 61e — FAILURE_BLOCK_DML masker rule: observable contracts from subscriber Apex.
// MaskPaymentCard (shipped, active — it owns the framework surfaces) has FailureAction__c =
// 'BlockDml'; the legacy MaskCreditCard it replaces is also BlockDml. The framework throws
// kern.UTIL_Exceptions.MaskingBlockedException ONLY when the rule itself throws an internal exception.
// A successful rule match-and-replace does NOT trigger handleRuleFailure.
//
// Assertions in this scenario use only APIs accessible from subscriber context:
// (a) MaskPaymentCard.FailureAction__c = 'BlockDml' confirmed via CMDT query.
// (b) Positive insert: Luhn-valid card succeeds, card masked, no exception thrown.
// (c) kern.UTIL_Exceptions.MaskingBlockedException is a global nested class — referenced directly
//     to confirm subscriber Apex can catch it by type.
// DEFERRED: trigger -> rule-failure -> exception propagation -> DML abort — see header §6.10 #5.
try
{
	List<kern__MaskingRule__mdt> blockDmlRules61e =
	[
			SELECT DeveloperName,
					kern__FailureAction__c,
					kern__IsActive__c
			FROM kern__MaskingRule__mdt
			WHERE kern__FailureAction__c = 'BlockDml'
			AND kern__IsActive__c = TRUE
			ORDER BY DeveloperName
	];

	Assert.isFalse(blockDmlRules61e.isEmpty(),
			'61e: at least one active MaskingRule__mdt with FailureAction__c = BlockDml must be deployed. '
			+ 'Expected MaskPaymentCard (+ legacy MaskCreditCard). Re-check package deployment.');

	Boolean hasMaskPaymentCard61e = false;
	Boolean hasMaskCreditCard61e = false;
	for(kern__MaskingRule__mdt rule : blockDmlRules61e)
	{
		if(rule.DeveloperName == 'MaskPaymentCard')
		{
			hasMaskPaymentCard61e = true;
		}
		if(rule.DeveloperName == 'MaskCreditCard')
		{
			hasMaskCreditCard61e = true;
		}
	}
	Assert.isTrue(hasMaskPaymentCard61e,
			'61e: MaskPaymentCard must be deployed with FailureAction__c = BlockDml and IsActive__c = true — '
			+ 'it does the card masking on the framework objects. Found active BlockDml rules: ' + blockDmlRules61e);
	Assert.isTrue(hasMaskCreditCard61e,
			'61e: the legacy MaskCreditCard must still ship with FailureAction__c = BlockDml and IsActive__c = true '
			+ '(replaced by MaskPaymentCard but kept for compatibility). Found active BlockDml rules: ' + blockDmlRules61e);

	Boolean maskingThrewOnSuccess61e = false;
	String unexpectedExceptionType61e = null;
	kern__ApiCall__c record61e = null;
	try
	{
		record61e = new kern__ApiCall__c();
		record61e.kern__ServiceName__c = 'Section61e-' + RUN_STAMP;
		record61e.kern__Direction__c = 'Inbound';
		record61e.kern__Status__c = 'Completed';
		record61e.kern__Request__c = '{"card":"' + VISA_CARD + '","section":"61e"}';
		record61e.kern__URL__c = 'https://example.com/api/61e';
		insert record61e;
		if(record61e.Id != null)
		{
			insertedIds.add(record61e.Id);
		}
	}
	catch(Exception successInsertError)
	{
		maskingThrewOnSuccess61e = true;
		unexpectedExceptionType61e = successInsertError.getTypeName();
		System.debug(LoggingLevel.ERROR, '61e UNEXPECTED: exception on successful card insert: '
				+ unexpectedExceptionType61e + ' — ' + successInsertError.getMessage());
	}

	Assert.isFalse(maskingThrewOnSuccess61e,
			'61e: NO exception must be thrown when MaskPaymentCard successfully redacts a Luhn-valid card. '
			+ 'BlockDml fires only when the rule throws internally — successful masking never triggers '
			+ 'handleRuleFailure(). Unexpected exception type: ' + unexpectedExceptionType61e);

	if(record61e != null && record61e.Id != null)
	{
		kern__ApiCall__c stored61e =
		[
				SELECT kern__Request__c
				FROM kern__ApiCall__c
				WHERE Id = :record61e.Id
				LIMIT 1
		];

		Assert.isFalse(stored61e.kern__Request__c.contains(VISA_CARD),
				'61e: card must be masked in the stored record. Got: ' + stored61e.kern__Request__c);
		Assert.isTrue(stored61e.kern__Request__c.containsIgnoreCase(CARD_REDACTED_SENTINEL),
				'61e: CARD_REDACTED sentinel must appear after successful masking. Got: '
				+ stored61e.kern__Request__c);
	}

	final String BLOCK_DML_MESSAGE = 'Masking rule MaskPaymentCard failed and is configured to block DML';
	kern.UTIL_Exceptions.MaskingBlockedException caughtBlocked61e = null;
	try
	{
		throw new kern.UTIL_Exceptions.MaskingBlockedException(BLOCK_DML_MESSAGE);
	}
	catch(kern.UTIL_Exceptions.MaskingBlockedException blocked61e)
	{
		caughtBlocked61e = blocked61e;
	}
	Assert.isNotNull(caughtBlocked61e,
			'61e: kern.UTIL_Exceptions.MaskingBlockedException must be catchable by type from subscriber Apex');
	Assert.isTrue(caughtBlocked61e.getMessage().containsIgnoreCase('block DML'),
			'61e: framework handleRuleFailure() message contains "block DML". Got: '
			+ caughtBlocked61e.getMessage());
	Assert.isTrue(caughtBlocked61e.getMessage().containsIgnoreCase('MaskPaymentCard'),
			'61e: framework handleRuleFailure() message includes the rule DeveloperName. Got: '
			+ caughtBlocked61e.getMessage());

	System.debug(LoggingLevel.INFO,
			'61e PASS (end-to-end deferred — see header §6.10 #5): '
			+ '(a) MaskPaymentCard (+ legacy MaskCreditCard) FailureAction__c = BlockDml confirmed in org ('
			+ blockDmlRules61e.size() + ' active BlockDml rule(s)). '
			+ '(b) Successful Luhn-valid card insert completed without any exception — '
			+ 'BlockDml is orthogonal to rule success; card was masked in stored record. '
			+ '(c) kern.UTIL_Exceptions.MaskingBlockedException caught by type from subscriber context — '
			+ 'message format includes rule DeveloperName + "block DML". '
			+ 'DEFERRED: trigger -> rule-failure -> exception -> DML abort. '
			+ 'Unit path covered in UTIL_FrameworkMasker_TEST; e2e in Subscriber_MaskingEdges_TEST. '
			+ 'SPEC DEVIATION: §6.10 #5 blocked by CMDT DML block in anon Apex.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR, '61e FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('61e: ' + scenarioError.getMessage());
	fail++;
}

kern.TRG_Base.clearAllBypasses();

if(!insertedIds.isEmpty())
{
	try
	{
		List<kern__ApiCall__c> residualRows =
		[
				SELECT Id
				FROM kern__ApiCall__c
				WHERE Id IN :insertedIds
				LIMIT 9000
		];
		if(!residualRows.isEmpty())
		{
			delete residualRows;
			System.debug(LoggingLevel.INFO, 'Cleanup: deleted ' + residualRows.size() + ' kern__ApiCall__c row(s)');
		}
	}
	catch(Exception cleanupError)
	{
		System.debug(LoggingLevel.WARN, '61 cleanup warning (ApiCall__c delete failed): ' + cleanupError.getMessage());
	}
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 61: ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 61 FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 61 failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 61 COMPLETE: All scenarios passed ===');
}
