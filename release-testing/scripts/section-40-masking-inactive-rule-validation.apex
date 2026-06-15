// Section 40 — Subscriber masking: every shipped rule's regex pattern compiles
// and matches a curated sample.
//
// Subscribers may activate any of the 12 inactive rule templates by flipping
// MaskingRule__mdt.IsActive__c = true and wiring a MaskingTarget__mdt. This test
// loads every shipped rule (active + inactive), compiles its Pattern__c as a
// regex, and verifies a positive + negative sample. Catches a deploy regression
// that ships an invalid regex (would throw PatternSyntaxException on first use
// in production) or a pattern that stops matching its intended input.
//
// Regex-mode rules: directly compile and matcher-find.
// JsonKey-mode rules: the pattern is a regex applied to JSON keys — same
// validation path, inputs are key strings rather than payload strings.
// CreditCard mode: the pattern is a regex PLUS post-match Luhn validation; we
// only validate the regex here, the Luhn path is covered by section 38.

Integer passCount = 0;
Integer failCount = 0;

Map<String, Map<String, String>> curatedSamples = new Map<String, Map<String, String>>
{
		'MaskAuthHeader' => new Map<String, String>
		{
				'positive' => 'Authorization: Bearer abc123xyz',
				'negative' => 'authorized users only'
		},
		'MaskAwsAccessKey' => new Map<String, String>
		{
				'positive' => 'AKIAIOSFODNN7EXAMPLE',
				'negative' => 'AKIX_not_a_valid_prefix_here'
		},
		'MaskEmail' => new Map<String, String>
		{
				'positive' => 'alice@example.com',
				'negative' => 'no at symbol here'
		},
		'MaskIban' => new Map<String, String>
		{
				'positive' => 'DE89370400440532013000',
				'negative' => 'random text without account'
		},
		'MaskIpv4Private' => new Map<String, String>
		{
				'positive' => 'server at 192.168.1.1 down',
				'negative' => 'public ip 8.8.8.8 is up'
		},
		'MaskJwt' => new Map<String, String>
		{
				'positive' => 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.abcdef',
				'negative' => 'not a jwt string at all'
		},
		'MaskMedicareBeneficiaryId' => new Map<String, String>
		{
				'positive' => '1AC2DE3FG44',
				'negative' => '111223333'
		},
		'MaskPhoneUS' => new Map<String, String>
		{
				'positive' => 'call 555-123-4567 today',
				'negative' => 'phone not present'
		},
		'MaskSsn' => new Map<String, String>
		{
				'positive' => 'ssn 123-45-6789',
				'negative' => 'zip 12345-6789'
		},
		'MaskSwiftBic' => new Map<String, String>
		{
				'positive' => 'DEUTDEFFXXX',
				'negative' => 'random string'
		},
		'MaskUrlBasicAuth' => new Map<String, String>
		{
				'positive' => 'https://admin:secret@example.com',
				'negative' => 'https://example.com'
		},
		'MaskSecretKeys' => new Map<String, String>
		{
				'positive' => 'password',
				'negative' => 'username'
		},
		'MaskHealthKeywords' => new Map<String, String>
		{
				'positive' => 'diagnosis',
				'negative' => 'notes'
		},
		'MaskCreditCard' => new Map<String, String>
		{
				'positive' => '4111111111111111',
				'negative' => '1234567890123456'
		},
		'MaskPaymentCard' => new Map<String, String>
		{
				// Raw-regex check only (no Luhn here): the successor pattern matches any
				// 13-19 digit run, so the negative must be shorter than 13 digits.
				'positive' => '4111111111111111',
				'negative' => '123456789012'
		}
};

List<kern__MaskingRule__mdt> rules =
[
		SELECT DeveloperName,
				kern__Pattern__c,
				kern__Mode__c,
				kern__IsActive__c,
				kern__CaseSensitive__c
		FROM kern__MaskingRule__mdt
		ORDER BY DeveloperName
];

System.debug('Validating ' + rules.size() + ' shipped MaskingRule__mdt records');

for(kern__MaskingRule__mdt rule : rules)
{
	String ruleName = rule.DeveloperName;
	String pattern = rule.kern__Pattern__c;
	String mode = rule.kern__Mode__c;

	Map<String, String> samples = curatedSamples.get(ruleName);
	if(samples == null)
	{
		System.debug('SKIP: ' + ruleName + ' — no curated sample in section 40 (new rule added; update this script)');
		continue;
	}

	Boolean passCompiles = true;
	try
	{
		System.Pattern.compile(pattern);
	}
	catch(Exception compileError)
	{
		passCompiles = false;
		System.debug('FAIL: ' + ruleName + ' — pattern failed to compile: ' + compileError.getMessage());
	}

	if(!passCompiles)
	{
		failCount++;
		continue;
	}

	Boolean casesensitive = rule.kern__CaseSensitive__c == true;
	String positive = casesensitive ? samples.get('positive') : samples.get('positive').toLowerCase();
	String negative = casesensitive ? samples.get('negative') : samples.get('negative').toLowerCase();
	String rawPattern = casesensitive ? pattern : pattern.toLowerCase();
	Pattern caseAwarePattern = System.Pattern.compile(rawPattern);

	Boolean passPositive = caseAwarePattern.matcher(positive).find();
	Boolean passNegativeExcluded = !caseAwarePattern.matcher(negative).find();

	System.debug
			(
					(passCompiles && passPositive && passNegativeExcluded ? 'PASS: ' : 'FAIL: ') +
					ruleName + ' (' + mode + ', active=' + rule.kern__IsActive__c + ') — compile=' + passCompiles + ' positive=' + passPositive + ' negative=' + passNegativeExcluded
			);

	passCount += (passCompiles ? 1 : 0) + (passPositive ? 1 : 0) + (passNegativeExcluded ? 1 : 0);
	failCount += (passCompiles ? 0 : 1) + (passPositive ? 0 : 1) + (passNegativeExcluded ? 0 : 1);
}

System.debug('=== SECTION 40 SUMMARY: ' + passCount + ' passed, ' + failCount + ' failed ===');
