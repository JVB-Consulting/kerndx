// Custom-object extensibility test: MaskSecretKeys wired via MaskingTarget__mdt
// onto Account.Description. Demonstrates that subscribers can extend coverage
// to any SObject by adding CMDT records — no Apex required.
//
// Also verifies the negative case: Account.Name (no target wired) stays raw.

Integer passCount = 0;
Integer failCount = 0;

String body = '{"user":"alice@example.com","password":"hunter2","card":"4111-1111-1111-1111"}';

Account a = new Account();
a.Name = 'Test Account with ' + body; // no MaskingTarget on Name → should stay raw
a.Phone = '+1 555 000 0000'; // subscriber validation rule requires Phone or Website
a.Industry = 'Technology'; // subscriber validation rule requires Industry
a.Description = body; // Account.Description wired → MaskSecretKeys fires
insert a;

Account stored =
[
		SELECT Name,
				Description
		FROM Account
		WHERE Id = :a.Id
];

Boolean passDescPassword = stored.Description.contains('***SECRET***') && !stored.Description.contains('hunter2');
Boolean passDescCard = stored.Description.contains('4111-1111-1111-1111'); // Card rule NOT wired to Account → stays raw
Boolean passNameRaw = stored.Name.contains('hunter2'); // Name not wired → stays raw

System.debug((passDescPassword ? 'PASS: ' : 'FAIL: ') + 'Account.Description password redacted via custom target');
System.debug((passDescCard ? 'PASS: ' : 'FAIL: ') + 'Account.Description card stays raw (only Secret rule wired)');
System.debug((passNameRaw ? 'PASS: ' : 'FAIL: ') + 'Account.Name stays raw (no target wired)');

passCount += (passDescPassword ? 1 : 0) + (passDescCard ? 1 : 0) + (passNameRaw ? 1 : 0);
failCount += (passDescPassword ? 0 : 1) + (passDescCard ? 0 : 1) + (passNameRaw ? 0 : 1);

System.debug('Description stored: ' + stored.Description);
System.debug('Name stored: ' + stored.Name);

delete a;
System.debug('=== CUSTOM-OBJECT SUMMARY: ' + passCount + ' passed, ' + failCount + ' failed ===');
