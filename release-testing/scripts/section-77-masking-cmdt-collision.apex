// Section 77 — masking CMDT name-collision tolerance.
//
// An org-local kern__MaskingRule__mdt record sharing a packaged record's DeveloperName makes the
// platform's getAll() read throw System.ListException. Before the engine fallback shipped, that
// state bricked EVERY framework-object insert (CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY from
// kern.TRG_ApiCall BeforeInsert) — reproduced on a 1.1.0-8 Stage-2 org and confirmed live in the
// released 1.0.0-121. The engine must instead degrade to a fallback read that masks identically
// and announce itself with one flood-controlled WARN log.
//
// The runner invokes this script TWICE (mirroring the section-66/66b split: log persistence is
// asynchronous through the platform-event pipeline, so a collision WARN emitted by THIS
// transaction is never queryable in the same run):
//   Invocation 1 — collision SEEDED (runner deployed the org-local MaskPaymentCard clone):
//     77a: kern__ApiCall__c insert SUCCEEDS (engine on the fallback read path, no brick)
//     77b: the inserted 16-digit card value is REDACTED (fallback masks identically)
//   Invocation 2 — RECOVERED (runner deleted the org-local clone):
//     77a: insert succeeds on the restored fast path
//     77b: card value redacted on the restored fast path
//     77c: a kern__LogEntry__c row exists with Fingerprint LIKE 'detail:masking:cmdt-collision:%'
//          — the WARN the seeded invocation's fallback emitted, persisted by now (lookback proof
//          that the degraded path announced itself while the collision was live)
// Expected: 2 PASS (seeded) + 3 PASS (recovered) = 5.

List<kern__MaskingRule__mdt> cardRuleHomonyms =
[
		SELECT DeveloperName, NamespacePrefix
		FROM kern__MaskingRule__mdt
		WHERE DeveloperName = 'MaskPaymentCard'
];
Boolean collisionSeeded = cardRuleHomonyms.size() > 1;
System.debug('Section 77 state: ' + (collisionSeeded
		? 'collision SEEDED (' + cardRuleHomonyms.size() + ' records share DeveloperName MaskPaymentCard)'
		: 'clean (no org-local clone present) — recovery invocation'));

Integer passCount = 0;
Integer failCount = 0;

// Housekeeping (seeded invocation only): purge collision-WARN rows left by PREVIOUS runs so the
// recovery invocation's 77c proves THIS run's emission. Flood control persists the detail row once
// per fingerprint forever (repeats only bump the rollup twin), so on a re-used org a stale row
// would otherwise green-light 77c even if this build's emission regressed. LogEntry__c carries no
// trigger, so this delete is safe even while the org is bricked pre-fix.
if(collisionSeeded)
{
	delete [SELECT Id FROM kern__LogEntry__c WHERE kern__Fingerprint__c LIKE '%masking:cmdt-collision:%'];
}

// 77a: the insert that bricked pre-fix orgs. ServiceName__c is STRING, covered by the shipped
// object-wide ApiCall targets, and 4111111111111111 is the canonical Luhn-valid 16-digit Visa.
kern__ApiCall__c probeCall = new kern__ApiCall__c();
probeCall.kern__ServiceName__c = 'card 4111111111111111 saved';
probeCall.kern__Direction__c = 'Inbound';
probeCall.kern__Status__c = 'Completed';
probeCall.kern__Request__c = '{}';
Boolean insertSucceeded = false;
String insertFailure = '';
try
{
	insert probeCall;
	insertSucceeded = true;
}
catch(Exception failure)
{
	insertFailure = failure.getMessage();
}
System.debug((insertSucceeded ? 'PASS: ' : 'FAIL: ') + '77a framework-object insert succeeds'
		+ (collisionSeeded ? ' while the DeveloperName collision is live' : ' on the recovered fast path')
		+ (insertSucceeded ? '' : ' — ' + insertFailure));
passCount += insertSucceeded ? 1 : 0;
failCount += insertSucceeded ? 0 : 1;

// 77b: the stored value must be redacted exactly as the fast path redacts it.
if(insertSucceeded)
{
	kern__ApiCall__c stored =
	[
			SELECT kern__ServiceName__c
			FROM kern__ApiCall__c
			WHERE Id = :probeCall.Id
	];
	Boolean masked = !stored.kern__ServiceName__c.contains('4111111111111111')
			&& stored.kern__ServiceName__c.contains('[CARD_REDACTED]');
	System.debug((masked ? 'PASS: ' : 'FAIL: ') + '77b card value redacted'
			+ (collisionSeeded ? ' through the fallback read path' : ' on the recovered fast path')
			+ ' — stored: ' + stored.kern__ServiceName__c);
	passCount += masked ? 1 : 0;
	failCount += masked ? 0 : 1;
	delete probeCall;
}
else
{
	System.debug('FAIL: 77b card value redacted — skipped, the 77a insert did not succeed');
	failCount += 1;
}

// 77c (recovery invocation only): the seeded invocation's fallback must have announced itself.
// LIKE-filtered fingerprint query per the section-66b idiom — never an unfiltered count assert.
if(!collisionSeeded)
{
	List<kern__LogEntry__c> collisionWarnings =
	[
			SELECT kern__LogLevel__c, kern__Message__c
			FROM kern__LogEntry__c
			WHERE kern__Fingerprint__c LIKE 'detail:masking:cmdt-collision:%'
	];
	Boolean warned = !collisionWarnings.isEmpty();
	System.debug((warned ? 'PASS: ' : 'FAIL: ') + '77c collision WARN persisted from the seeded invocation'
			+ (warned ? ' — ' + collisionWarnings[0].kern__LogLevel__c + ': ' + collisionWarnings[0].kern__Message__c.abbreviate(160) : ' — no detail:masking:cmdt-collision:% row found'));
	passCount += warned ? 1 : 0;
	failCount += warned ? 0 : 1;
}

System.debug('=== SECTION 77 SUMMARY: ' + passCount + ' passed, ' + failCount + ' failed ===');
