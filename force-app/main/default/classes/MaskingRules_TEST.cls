// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for the pre-built `MaskingRule__mdt` records shipped with the
 * package. Each test loads a rule by DeveloperName, applies its pattern/replacement/mode to
 * a canonical sample input, and asserts the output matches the expected redaction. Catches
 * drift if a shipped rule's Pattern or Replacement is edited without updating the contract
 * these rules are documented to fulfil.
 *
 * @see UTIL_FrameworkMasker
 * @see UTIL_String
 *
 * @author Jason van Beukering
 *
 * @group Data Masking
 *
 * @date April 2026, June 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
private class MaskingRules_TEST
{
	/**
	 * @description Current-generation card pattern (the Luhn-gated digit run) shipped on the
	 * Mask Payment Card Numbers successor rule. Mirrors the shipped record so guarded pins can
	 * assert the engine guarantee even in orgs whose installed records are tuned or predate the
	 * supersession split.
	 */
	private static final String CREDIT_CARD_CURRENT_PATTERN = '\\b\\d(?:[ -]?\\d){12,18}\\b';

	/**
	 * @description Replacement token both shipped card rules apply.
	 */
	private static final String CREDIT_CARD_REPLACEMENT = '[CARD_REDACTED]';

	/**
	 * @description Tests that MaskEmail redacts the local-part and preserves the domain so the
	 * result is still a syntactically valid email address.
	 */
	@IsTest
	private static void shouldMaskEmail()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_EMAIL, 'contact alice@example.com today', 'contact redacted@example.com today');
	}

	/**
	 * @description Tests that MaskSsn redacts nine-digit SSNs with hyphen separators.
	 */
	@IsTest
	private static void shouldMaskSsn()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_SSN, 'SSN is 123-45-6789 verified', 'SSN is XXX-XX-XXXX verified');
	}

	/**
	 * @description Tests that MaskSsn excludes invalid SSN prefix 000.
	 */
	@IsTest
	private static void shouldNotMaskInvalidSsnPrefix()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_SSN, 'ID 000-12-3456 passes', 'ID 000-12-3456 passes');
	}

	/**
	 * @description Tests that MaskPhoneUS redacts US-format phone numbers with dashes.
	 */
	@IsTest
	private static void shouldMaskPhoneUS()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_PHONE_US, 'call 555-123-4567 now', 'call [PHONE_REDACTED] now');
	}

	/**
	 * @description Tests that a hyphen-separated 16-digit card number redacts — strict against
	 * the live superseded MaskCreditCard record while it carries its shipped 1.0 values, and
	 * against the current-generation pattern directly in tuned orgs (subscriber tuning is
	 * permitted and must not fail the package's own tests).
	 */
	@IsTest
	private static void shouldMaskCreditCard()
	{
		if(predecessorMatchesShippedValues())
		{
			assertRuleMasks(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, 'card 4111-1111-1111-1111 saved', 'card [CARD_REDACTED] saved');
			return;
		}

		assertCurrentGenerationCardBehaviour('card 4111-1111-1111-1111 saved', 'card [CARD_REDACTED] saved');
	}

	/**
	 * @description Tests that MaskCreditCard ships with FailureAction = BlockDml so a broken
	 * config aborts the DML rather than silently leaking cardholder data.
	 */
	@IsTest
	private static void shouldShipCreditCardWithBlockDmlFailureAction()
	{
		MaskingRule__mdt rule = findShippedRule(SEL_MaskingRule.RULE_MASK_CREDIT_CARD);

		Assert.areEqual(SEL_MaskingRule.FAILURE_BLOCK_DML, rule.FailureAction__c, 'MaskCreditCard must ship with FailureAction = BlockDml');
	}

	/**
	 * @description Tests that MaskJwt redacts a three-segment token starting with the eyJ header.
	 */
	@IsTest
	private static void shouldMaskJwt()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_JWT, 'token eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.abcdef here', 'token [JWT_REDACTED] here');
	}

	/**
	 * @description Tests that MaskAuthHeader redacts the full value after "Authorization:"
	 * including an optional "Bearer " scheme prefix.
	 */
	@IsTest
	private static void shouldMaskAuthHeaderWithBearerScheme()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_AUTH_HEADER, 'Authorization: Bearer s3cret', 'Authorization: [REDACTED]');
	}

	/**
	 * @description Tests that MaskAuthHeader also redacts a raw token after Authorization:
	 * (no Bearer scheme prefix).
	 */
	@IsTest
	private static void shouldMaskAuthHeaderWithRawToken()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_AUTH_HEADER, 'Authorization: abc123xyz', 'Authorization: [REDACTED]');
	}

	/**
	 * @description Tests that MaskSecretKeys (JsonKey mode) redacts the value under a password
	 * key in a JSON payload while leaving sibling keys intact.
	 */
	@IsTest
	private static void shouldMaskSecretKeysInJson()
	{
		String input = '{"user":"alice","password":"hunter2"}';
		String output = applyRule(SEL_MaskingRule.RULE_MASK_SECRET_KEYS, input);

		Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(output);
		Assert.areEqual('***SECRET***', parsed.get('password'), 'password value should be redacted');
		Assert.areEqual('alice', parsed.get('user'), 'sibling key should remain');
	}

	/**
	 * @description Tests that MaskSecretKeys also redacts nested secret-key values.
	 */
	@IsTest
	private static void shouldMaskSecretKeysAtNestedDepth()
	{
		String input = '{"outer":{"api_key":"xyz","note":"ok"}}';
		String output = applyRule(SEL_MaskingRule.RULE_MASK_SECRET_KEYS, input);

		Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(output);
		Map<String, Object> innerMap = (Map<String, Object>)parsed.get('outer');
		Assert.areEqual('***SECRET***', innerMap.get('api_key'), 'nested api_key value should be redacted');
		Assert.areEqual('ok', innerMap.get('note'), 'nested non-secret key should remain');
	}

	/**
	 * @description Tests that MaskSwiftBic redacts an 11-character SWIFT/BIC code.
	 */
	@IsTest
	private static void shouldMaskSwiftBic()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_SWIFT_BIC, 'BIC DEUTDEFF500 verified', 'BIC [BIC_REDACTED] verified');
	}

	/**
	 * @description Tests that MaskSwiftBic ships with FailureAction = BlockDml.
	 */
	@IsTest
	private static void shouldShipSwiftBicWithBlockDmlFailureAction()
	{
		Assert.areEqual
				(
						SEL_MaskingRule.FAILURE_BLOCK_DML,
						findShippedRule(SEL_MaskingRule.RULE_MASK_SWIFT_BIC).FailureAction__c,
						'MaskSwiftBic must ship with FailureAction = BlockDml'
				);
	}

	/**
	 * @description Tests that MaskIban redacts a valid IBAN format account number.
	 */
	@IsTest
	private static void shouldMaskIban()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_IBAN, 'IBAN DE89370400440532013000 present', 'IBAN [IBAN_REDACTED] present');
	}

	/**
	 * @description Tests that MaskIban ships with FailureAction = BlockDml.
	 */
	@IsTest
	private static void shouldShipIbanWithBlockDmlFailureAction()
	{
		Assert.areEqual(SEL_MaskingRule.FAILURE_BLOCK_DML, findShippedRule(SEL_MaskingRule.RULE_MASK_IBAN).FailureAction__c, 'MaskIban must ship with FailureAction = BlockDml');
	}

	/**
	 * @description Tests that MaskMedicareBeneficiaryId redacts an 11-character MBI per the
	 * CMS positional format.
	 */
	@IsTest
	private static void shouldMaskMedicareBeneficiaryId()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_MEDICARE_BENEFICIARY_ID, 'MBI 1EG4TE5MK73 on file', 'MBI [MBI_REDACTED] on file');
	}

	/**
	 * @description Tests that MaskMedicareBeneficiaryId ships with FailureAction = BlockDml.
	 */
	@IsTest
	private static void shouldShipMbiWithBlockDmlFailureAction()
	{
		Assert.areEqual
				(
						SEL_MaskingRule.FAILURE_BLOCK_DML,
						findShippedRule(SEL_MaskingRule.RULE_MASK_MEDICARE_BENEFICIARY_ID).FailureAction__c,
						'MaskMedicareBeneficiaryId must ship with FailureAction = BlockDml'
				);
	}

	/**
	 * @description Tests that MaskHealthKeywords redacts a patient_id value in a JSON payload.
	 */
	@IsTest
	private static void shouldMaskHealthKeywords()
	{
		String input = '{"patient_id":"12345","note":"ok"}';
		String output = applyRule(SEL_MaskingRule.RULE_MASK_HEALTH_KEYWORDS, input);

		Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(output);
		Assert.areEqual('***PHI***', parsed.get('patient_id'), 'patient_id should be redacted');
		Assert.areEqual('ok', parsed.get('note'), 'non-PHI key should remain');
	}

	/**
	 * @description Tests that MaskHealthKeywords ships with FailureAction = BlockDml.
	 */
	@IsTest
	private static void shouldShipHealthKeywordsWithBlockDmlFailureAction()
	{
		Assert.areEqual
				(
						SEL_MaskingRule.FAILURE_BLOCK_DML,
						findShippedRule(SEL_MaskingRule.RULE_MASK_HEALTH_KEYWORDS).FailureAction__c,
						'MaskHealthKeywords must ship with FailureAction = BlockDml'
				);
	}

	/**
	 * @description Tests that MaskAwsAccessKey redacts a 20-character AKIA-prefixed
	 * (AWS Access Key ID) permanent IAM key.
	 */
	@IsTest
	private static void shouldMaskAwsAccessKey()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_AWS_ACCESS_KEY, 'AWS AKIAIOSFODNN7EXAMPLE used', 'AWS [AWS_KEY_REDACTED] used');
	}

	/**
	 * @description Tests that MaskUrlBasicAuth redacts embedded user:password in a URL while
	 * preserving the scheme and host.
	 */
	@IsTest
	private static void shouldMaskUrlBasicAuth()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_URL_BASIC_AUTH, 'see https://admin:hunter2@example.com ok', 'see https://[USER]:[PWD]@example.com ok');
	}

	/**
	 * @description Tests that MaskIpv4Private redacts a 192.168.x.x private-range address.
	 */
	@IsTest
	private static void shouldMaskIpv4Private()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_IPV4_PRIVATE, 'Connected to 192.168.1.1 ok', 'Connected to [IP_REDACTED] ok');
	}

	/**
	 * @description Tests that MaskIpv4Private ships inactive — opt-in for subscribers whose
	 * compliance scope treats internal IPs as sensitive identifiers.
	 */
	@IsTest
	private static void shouldShipIpv4PrivateInactive()
	{
		Assert.isFalse(findShippedRule(SEL_MaskingRule.RULE_MASK_IPV4_PRIVATE).IsActive__c, 'MaskIpv4Private must ship inactive (opt-in)');
	}

	/**
	 * @description Tests that MaskSsn excludes the invalid 666 prefix (known never-issued).
	 */
	@IsTest
	private static void shouldNotMaskSsnWithPrefix666()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_SSN, 'record 666-12-3456 kept', 'record 666-12-3456 kept');
	}

	/**
	 * @description Tests that MaskMedicareBeneficiaryId rejects MBIs containing the
	 * excluded-letter set (S, L, O, I, B, Z). The 'S' in position 2 should prevent a match.
	 */
	@IsTest
	private static void shouldNotMaskMbiWithExcludedLetter()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_MEDICARE_BENEFICIARY_ID, 'MBI 1SG4TE5MK73 rejected', 'MBI 1SG4TE5MK73 rejected');
	}

	/**
	 * @description Tests that MaskSwiftBic is case-sensitive — lowercase strings matching the
	 * BIC shape should NOT be redacted (protects against matching normal lowercase prose).
	 */
	@IsTest
	private static void shouldNotMaskLowercaseSwiftBic()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_SWIFT_BIC, 'not a bic deutdeff500 here', 'not a bic deutdeff500 here');
	}

	/**
	 * @description Tests that MaskAwsAccessKey is case-sensitive — lowercase akia strings
	 * should NOT be redacted.
	 */
	@IsTest
	private static void shouldNotMaskLowercaseAwsAccessKey()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_AWS_ACCESS_KEY, 'value akiaiosfodnn7example stays', 'value akiaiosfodnn7example stays');
	}

	/**
	 * @description Tests that MaskIpv4Private does NOT redact public IPv4 addresses (only
	 * RFC1918 private ranges + 127.x loopback are in scope).
	 */
	@IsTest
	private static void shouldNotMaskPublicIpv4Address()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_IPV4_PRIVATE, 'public 8.8.8.8 kept', 'public 8.8.8.8 kept');
	}

	/**
	 * @description Tests that MaskSecretKeys recognises the hyphen-variant api-key spelling,
	 * not just the underscore form.
	 */
	@IsTest
	private static void shouldMaskSecretKeysHyphenVariant()
	{
		String input = '{"api-key":"xyz","note":"ok"}';
		String output = applyRule(SEL_MaskingRule.RULE_MASK_SECRET_KEYS, input);

		Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(output);
		Assert.areEqual('***SECRET***', parsed.get('api-key'), 'api-key should be redacted');
	}

	/**
	 * @description Tests that MaskPhoneUS recognises the parenthesised format common in the US.
	 */
	@IsTest
	private static void shouldMaskPhoneWithParentheses()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_PHONE_US, 'call (555) 123-4567 now', 'call [PHONE_REDACTED] now');
	}

	/**
	 * @description Tests that MaskUrlBasicAuth preserves the scheme and host so log readers
	 * still see which endpoint was involved.
	 */
	@IsTest
	@SuppressWarnings('HttpUrlsUsage')
	private static void shouldPreserveSchemeAndHostInMaskUrlBasicAuth()
	{
		String output = applyRule(SEL_MaskingRule.RULE_MASK_URL_BASIC_AUTH, 'http://user:pwd@api.example.com/path');

		Assert.isTrue(output.contains('api.example.com'), 'Host must be preserved');
		Assert.isFalse(output.contains('user:pwd'), 'Credentials must not remain');
		Assert.isTrue(output.startsWith('http://[USER]:[PWD]@'), 'Scheme and redaction markers must appear first');
	}

	/**
	 * @description Tests that MaskEmail handles plus-addressed (alias) emails, a common
	 * subscriber pattern that shouldn't break pattern matching.
	 */
	@IsTest
	private static void shouldMaskPlusAddressedEmail()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_EMAIL, 'user alice+marketing@example.com signed up', 'user redacted@example.com signed up');
	}

	/**
	 * @description Tests that MaskEmail handles subdomains and two-level TLDs.
	 */
	@IsTest
	private static void shouldMaskSubdomainEmail()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_EMAIL, 'contact support@mail.example.co.uk today', 'contact redacted@mail.example.co.uk today');
	}

	/**
	 * @description Tests that MaskSsn handles space-separated format.
	 */
	@IsTest
	private static void shouldMaskSsnWithSpaceSeparators()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_SSN, 'ID 123 45 6789 filed', 'ID XXX-XX-XXXX filed');
	}

	/**
	 * @description Tests that MaskSsn handles no-separator format.
	 */
	@IsTest
	private static void shouldMaskSsnWithoutSeparators()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_SSN, 'packed 123456789 format', 'packed XXX-XX-XXXX format');
	}

	/**
	 * @description Tests that MaskPhoneUS handles dot-separated format.
	 */
	@IsTest
	private static void shouldMaskPhoneWithDotSeparators()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_PHONE_US, 'call 555.123.4567 asap', 'call [PHONE_REDACTED] asap');
	}

	/**
	 * @description Tests that MaskPhoneUS handles the +1 country code prefix.
	 */
	@IsTest
	private static void shouldMaskPhoneWithCountryCode()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_PHONE_US, 'dial +1 555-123-4567 now', 'dial [PHONE_REDACTED] now');
	}

	/**
	 * @description Tests that the 15-digit Amex card length redacts — strict against the live
	 * superseded MaskCreditCard record while it carries its shipped 1.0 values, and against the
	 * current-generation pattern directly in tuned orgs.
	 */
	@IsTest
	private static void shouldMaskCreditCard15DigitAmex()
	{
		if(predecessorMatchesShippedValues())
		{
			assertRuleMasks(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, 'amex 378282246310005 saved', 'amex [CARD_REDACTED] saved');
			return;
		}

		assertCurrentGenerationCardBehaviour('amex 378282246310005 saved', 'amex [CARD_REDACTED] saved');
	}

	/**
	 * @description Tests that Mask Payment Card Numbers does NOT redact a 13-digit millisecond
	 * timestamp. The digit-run pattern matches the 13-digit value, but it fails the Luhn
	 * (mod-10) checksum, so the Luhn gate leaves it untouched — guarding the false positive a
	 * subscriber test (SubscriberChainSteps_TEST) hit when its correlation ID
	 * `correlation-1776297919466` was partially redacted.
	 */
	@IsTest
	private static void shouldNotMaskTimestampDigits()
	{
		if(successorMatchesShippedValues())
		{
			assertRuleMasks(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, 'correlation-1776297919466 saved', 'correlation-1776297919466 saved');
			return;
		}

		assertCurrentGenerationCardBehaviour('correlation-1776297919466 saved', 'correlation-1776297919466 saved');
	}

	/**
	 * @description Tests that 16 digits separated by spaces redact — strict against the live
	 * superseded MaskCreditCard record while it carries its shipped 1.0 values, and against the
	 * current-generation pattern directly in tuned orgs.
	 */
	@IsTest
	private static void shouldMaskCreditCardWithSpaces()
	{
		if(predecessorMatchesShippedValues())
		{
			assertRuleMasks(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, 'card 4111 1111 1111 1111 saved', 'card [CARD_REDACTED] saved');
			return;
		}

		assertCurrentGenerationCardBehaviour('card 4111 1111 1111 1111 saved', 'card [CARD_REDACTED] saved');
	}

	/**
	 * @description Regression guard for the 2-series Mastercard fix. Standard 16-digit
	 * Mastercard 2-series cards (BIN range 2221-2720, issued since 2017) must redact. The
	 * superseded MaskCreditCard issuer-union pattern never matched them; the successor's
	 * Luhn-gated digit-run pattern does. Strict only while the installed successor matches its
	 * shipped fingerprint — subscriber tuning is permitted and must not fail the package's own
	 * tests; the engine guarantee is then pinned against the current-generation pattern
	 * directly.
	 */
	@IsTest
	private static void shouldMaskTwoSeriesMastercard()
	{
		if(successorMatchesShippedValues())
		{
			assertRuleMasks(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, 'card 2223000048400011 saved', 'card [CARD_REDACTED] saved');
			return;
		}

		assertCurrentGenerationCardBehaviour('card 2223000048400011 saved', 'card [CARD_REDACTED] saved');
	}

	/**
	 * @description Tests that Mask Payment Card Numbers redacts a 19-digit card (the longest
	 * supported length) — here a UnionPay number. The successor's Luhn-gated digit-run pattern
	 * accepts the full 13-19 digit range.
	 */
	@IsTest
	private static void shouldMaskNineteenDigitCard()
	{
		if(successorMatchesShippedValues())
		{
			assertRuleMasks(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, 'card 6205500000000000004 saved', 'card [CARD_REDACTED] saved');
			return;
		}

		assertCurrentGenerationCardBehaviour('card 6205500000000000004 saved', 'card [CARD_REDACTED] saved');
	}

	/**
	 * @description Tests that Mask Payment Card Numbers ships with MinInputLength 13 so the
	 * shortest supported card length (a 13-digit Visa) is not suppressed by the length floor
	 * before the Luhn-gated pattern runs. Strict only while the installed record matches its
	 * shipped fingerprint — subscriber tuning of the successor (including blanking the floor)
	 * is permitted and must not fail the package's own tests; tuned orgs assert the shipped
	 * 13-digit pattern coverage directly instead.
	 */
	@IsTest
	private static void shouldShipPaymentCardWithThirteenDigitMinInputLength()
	{
		MaskingRule__mdt successor = findShippedRule(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD);

		if(SEL_MaskingRule.computeFingerprint(successor) != successor.ShippedFingerprint__c)
		{
			assertCurrentGenerationCardBehaviour('card 4222222222222 saved', 'card [CARD_REDACTED] saved');
			return;
		}

		Assert.areEqual(13, successor.MinInputLength__c.intValue(),
				'Mask Payment Card Numbers must ship with MinInputLength 13 to cover 13-digit cards');
	}

	/**
	 * @description The superseded MaskCreditCard record intentionally ships its 1.0 values — the
	 * successor (Mask Payment Card Numbers) carries the current behaviour. DO NOT "modernise" the
	 * predecessor record: identical shipped values are what make fresh installs and upgraded orgs
	 * behave the same, and the supersession fingerprint depends on them. In orgs where the record
	 * was customised (or installed from a pre-release 1.1 build) it legitimately differs — there
	 * the rule must simply remain un-suppressed.
	 */
	@IsTest
	private static void shouldKeepSupersededCreditCardRuleAtItsShippedValues()
	{
		MaskingRule__mdt successor = findShippedRule(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD);
		MaskingRule__mdt predecessor = findShippedRule(SEL_MaskingRule.RULE_MASK_CREDIT_CARD);
		List<MaskingRule__mdt> universe = new SEL_MaskingTarget().getAllRulesById().values();
		String predecessorKey = SEL_MaskingRule.resolveQualifiedDeveloperName(predecessor);

		if(SEL_MaskingRule.computeFingerprint(predecessor) != successor.ReplacesFingerprint__c)
		{
			Assert.isFalse(SEL_MaskingRule.findSupersededRuleNames(universe).contains(predecessorKey),
					'A customised predecessor must not be suppressed');
			return;
		}

		Boolean successorSupersedes = successor.IsActive__c == true
				&& SEL_MaskingRule.computeFingerprint(successor) == successor.ShippedFingerprint__c;

		Assert.areEqual(15, predecessor.MinInputLength__c.intValue(),
				'Superseded MaskCreditCard intentionally ships its original 1.0 values — the successor carries current behaviour; never modernise this record');
		Assert.areEqual(successorSupersedes, SEL_MaskingRule.findSupersededRuleNames(universe).contains(predecessorKey),
				'The untuned predecessor must be superseded exactly while the successor is active and untuned');
	}

	/**
	 * @description Every shipped target bound to a superseded predecessor must have a successor
	 * target with the same object|field|caller surface — a forgotten surface would mean silent
	 * partial coverage. Holds for every Replaces__c relationship in the org, packaged or
	 * org-local, resolved namespace-aware.
	 */
	@IsTest
	private static void shouldMirrorEveryPredecessorTargetWithASuccessorTarget()
	{
		Map<Id, MaskingRule__mdt> rulesById = new SEL_MaskingTarget().getAllRulesById();

		for(MaskingRule__mdt successor : rulesById.values())
		{
			if(String.isBlank(successor.Replaces__c))
			{
				continue;
			}
			Set<String> successorSurfaces = findTargetSurfaces(successor, rulesById);

			for(MaskingRule__mdt predecessor : rulesById.values())
			{
				if(predecessor.DeveloperName != successor.Replaces__c || predecessor.NamespacePrefix != successor.NamespacePrefix)
				{
					continue;
				}

				for(String predecessorSurface : findTargetSurfaces(predecessor, rulesById))
				{
					Assert.isTrue(successorSurfaces.contains(predecessorSurface),
							successor.DeveloperName + ' must mirror predecessor surface ' + predecessorSurface);
				}
			}
		}
	}

	/**
	 * @description Regression guard for the user-reported masking-rehydrate bug. Drives the shipped
	 * `MaskCreditCard` rule (broad digit-run regex gated by the Luhn mod-10 checksum, plus
	 * MinInputLength and ApplicableFieldTypes) through the full `UTIL_FrameworkMasker` pipeline
	 * against a `LogEntryEvent__e` carrying a 16-digit transaction ID. The regex matches the
	 * digit run, but the value fails the Luhn checksum, so the engine preserves it. If a future
	 * change drops the Luhn gate this test fails.
	 */
	@IsTest
	private static void shouldPreserveParentTransactionIdOnLogEntryEvent()
	{
		String originalValue = 'TID:1234567890123456';
		LogEntryEvent__e event = new LogEntryEvent__e(ParentTransactionId__c = originalValue);

		UTIL_FrameworkMasker.forRecord(event).apply();

		Assert.areEqual(originalValue, event.ParentTransactionId__c, 'Luhn-invalid 16-digit transaction ID starting with 1 must survive MaskCreditCard on LogEntryEvent__e');
	}

	/**
	 * @description Regression guard asserting a Salesforce Request ID shape survives
	 * `MaskCreditCard`. Request IDs interleave uppercase letters with digits, so no run of 13+
	 * consecutive digits (the digit-run pattern's minimum) exists — the regex never matches and
	 * the Luhn gate is never reached. Guards against a future rule edit that relaxes the regex
	 * into matching letter-digit mixtures.
	 */
	@IsTest
	private static void shouldPreserveSalesforceRequestIdShapedTransactionIdOnLogEntryEvent()
	{
		String requestId = '4Zc2aA00A00000001EEyAAM';
		LogEntryEvent__e event = new LogEntryEvent__e(TransactionId__c = requestId);

		UTIL_FrameworkMasker.forRecord(event).apply();

		Assert.areEqual(requestId, event.TransactionId__c, 'Salesforce Request ID shape must survive MaskCreditCard on LogEntryEvent__e');
	}

	/**
	 * @description Regression guard for a UUID-shaped correlation ID. UUIDs are hex + hyphens —
	 * the hex letters `a-f` break all digit runs to at most 8 chars (the first segment of the
	 * UUID shape `8-4-4-4-12`). No segment meets the 13-digit minimum, so the digit-run regex
	 * cannot match anywhere in the UUID. Preserves the format intact.
	 */
	@IsTest
	private static void shouldPreserveUuidShapedCorrelationIdOnLogEntryEvent()
	{
		String uuid = '3258728f-d54c-4cd3-81b3-efb5859e5958';
		LogEntryEvent__e event = new LogEntryEvent__e(ParentTransactionId__c = uuid);

		UTIL_FrameworkMasker.forRecord(event).apply();

		Assert.areEqual(uuid, event.ParentTransactionId__c, 'UUID-shaped correlation ID must survive MaskCreditCard on LogEntryEvent__e');
	}

	/**
	 * @description Regression guard for the exact scenario the user reported — a JSON payload
	 * inside `ApiCall__c.Request__c` with a `parentTransactionId` field whose value is
	 * `TID:` + 16 digits. Pre-fix this redacted to `TID:[CARD_REDACTED]`. Post-fix the digit-run
	 * regex matches the 16-digit run but it fails the Luhn checksum, so the value survives. If
	 * this test ever fails the user-visible bug has returned.
	 */
	@IsTest
	private static void shouldPreserveParentTransactionIdInsideApiCallRequestJsonPayload()
	{
		String payload = '{"parentTransactionId":"TID:1234567890123456","correlationId":"3258728f-d54c-4cd3-81b3-efb5859e5958"}';
		ApiCall__c call = new ApiCall__c(Request__c = payload);

		UTIL_FrameworkMasker.forRecord(call).apply();

		Assert.isTrue(call.Request__c.contains('1234567890123456'), 'Luhn-invalid 16-digit transaction ID inside Request__c JSON must survive; observed=' + call.Request__c);
		Assert.isFalse(call.Request__c.contains('[CARD_REDACTED]'), 'MaskCreditCard must not redact a Luhn-invalid digit run inside Request__c');
	}

	/**
	 * @description Tests that MaskSwiftBic handles the 8-character BIC variant (no branch code).
	 */
	@IsTest
	private static void shouldMaskSwiftBic8Chars()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_SWIFT_BIC, 'BIC DEUTDEFF filed', 'BIC [BIC_REDACTED] filed');
	}

	/**
	 * @description Tests that MaskIban handles the UK IBAN format (different country code).
	 */
	@IsTest
	private static void shouldMaskUkIban()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_IBAN, 'IBAN GB82WEST12345698765432 sent', 'IBAN [IBAN_REDACTED] sent');
	}

	/**
	 * @description Tests that MaskHealthKeywords redacts every shipped keyword (diagnosis,
	 * mrn, rx_number, prescription, icd10, ndc, patient_id). Catches regex drift if one key
	 * is removed from the alternation by accident.
	 */
	@IsTest
	private static void shouldMaskEveryHealthKeyword()
	{
		Map<String, String> input = new Map<String, String>
		{
				'diagnosis' => 'hypertension',
				'mrn' => '123',
				'rx_number' => 'A1',
				'prescription' => 'drug',
				'icd10' => 'I10',
				'ndc' => '0000-0000-00',
				'patient_id' => '99',
				'note' => 'ok'
		};

		String output = applyRule(SEL_MaskingRule.RULE_MASK_HEALTH_KEYWORDS, JSON.serialize(input));
		Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(output);

		for(String phiKey : new List<String> {'diagnosis', 'mrn', 'rx_number', 'prescription', 'icd10', 'ndc', 'patient_id'})
		{
			Assert.areEqual('***PHI***', parsed.get(phiKey), phiKey + ' should be redacted');
		}
		Assert.areEqual('ok', parsed.get('note'), 'non-PHI key should remain');
	}

	/**
	 * @description Tests that MaskJwt does NOT over-match a random base64 string that lacks
	 * the three-segment eyJ structure.
	 */
	@IsTest
	private static void shouldNotMaskNonJwtBase64String()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_JWT, 'id SGVsbG9Xb3JsZA== here', 'id SGVsbG9Xb3JsZA== here');
	}

	/**
	 * @description Tests that MaskAwsAccessKey recognises the ASIA (STS session token) prefix
	 * in addition to the AKIA permanent-key prefix.
	 */
	@IsTest
	private static void shouldMaskAwsSessionAccessKey()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_AWS_ACCESS_KEY, 'session ASIAIOSFODNN7EXAMPLE used', 'session [AWS_KEY_REDACTED] used');
	}

	/**
	 * @description Tests that MaskSecretKeys catches every shipped alternation keyword —
	 * password, passwd, secret, token, api_key, authorization, bearer, client_secret,
	 * private_key, access_token, refresh_token.
	 */
	@IsTest
	private static void shouldMaskEverySecretKeyVariant()
	{
		Map<String, String> input = new Map<String, String>
		{
				'password' => 'p1',
				'passwd' => 'p2',
				'secret' => 's1',
				'token' => 't1',
				'api_key' => 'a1',
				'authorization' => 'o1',
				'bearer' => 'b1',
				'client_secret' => 'cs1',
				'private_key' => 'pk1',
				'access_token' => 'at1',
				'refresh_token' => 'rt1',
				'note' => 'ok'
		};

		String output = applyRule(SEL_MaskingRule.RULE_MASK_SECRET_KEYS, JSON.serialize(input));
		Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(output);

		List<String> secretKeys = new List<String>
		{
				'password', 'passwd', 'secret', 'token', 'api_key', 'authorization',
				'bearer', 'client_secret', 'private_key', 'access_token', 'refresh_token'
		};
		for(String secretKey : secretKeys)
		{
			Assert.areEqual('***SECRET***', parsed.get(secretKey), secretKey + ' should be redacted');
		}
		Assert.areEqual('ok', parsed.get('note'), 'non-secret key should remain');
	}

	/**
	 * @description Tests that MaskIpv4Private covers the 10.x/8 private range.
	 */
	@IsTest
	private static void shouldMaskIpv4Range10()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_IPV4_PRIVATE, 'router 10.0.0.1 here', 'router [IP_REDACTED] here');
	}

	/**
	 * @description Tests that MaskIpv4Private covers the 172.16.x.x-172.31.x.x private range
	 * at the lower boundary.
	 */
	@IsTest
	private static void shouldMaskIpv4Range172LowerBoundary()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_IPV4_PRIVATE, 'host 172.16.0.1 ok', 'host [IP_REDACTED] ok');
	}

	/**
	 * @description Tests that MaskIpv4Private covers the 172.16-31 private range at the upper
	 * boundary.
	 */
	@IsTest
	private static void shouldMaskIpv4Range172UpperBoundary()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_IPV4_PRIVATE, 'host 172.31.255.1 ok', 'host [IP_REDACTED] ok');
	}

	/**
	 * @description Tests that MaskIpv4Private does NOT match 172.15.x.x (outside the private
	 * range — 172.0.0.0-172.15.255.255 is public).
	 */
	@IsTest
	private static void shouldNotMaskIpv4Address172BelowPrivateRange()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_IPV4_PRIVATE, 'host 172.15.0.1 stays', 'host 172.15.0.1 stays');
	}

	/**
	 * @description Tests that MaskIpv4Private does NOT match 172.32.x.x (outside the private
	 * range — 172.32.0.0+ is public).
	 */
	@IsTest
	private static void shouldNotMaskIpv4Address172AbovePrivateRange()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_IPV4_PRIVATE, 'host 172.32.0.1 stays', 'host 172.32.0.1 stays');
	}

	/**
	 * @description Tests that MaskIpv4Private covers the 127.x loopback range.
	 */
	@IsTest
	private static void shouldMaskIpv4Loopback()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_IPV4_PRIVATE, 'local 127.0.0.1 responds', 'local [IP_REDACTED] responds');
	}

	/**
	 * @description Tests that MaskUrlBasicAuth supports the http:// scheme as well as https://.
	 */
	@IsTest
	@SuppressWarnings('HttpUrlsUsage')
	private static void shouldMaskUrlBasicAuthOnHttpScheme()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_URL_BASIC_AUTH, 'ping http://admin:hunter2@api.local ok', 'ping http://[USER]:[PWD]@api.local ok');
	}

	/**
	 * @description Tests that MaskUrlBasicAuth leaves URLs without embedded credentials
	 * untouched.
	 */
	@IsTest
	private static void shouldNotMaskUrlWithoutBasicAuth()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_URL_BASIC_AUTH, 'ping https://example.com/v1 ok', 'ping https://example.com/v1 ok');
	}

	/**
	 * @description True while the installed MaskCreditCard record still carries its original
	 * shipped values (live fingerprint equals the successor's ReplacesFingerprint__c). False in
	 * orgs where the subscriber tuned the record or the install path predates the supersession
	 * split — strict 1.0-value pins must then fall back to the cross-generation guarantee.
	 *
	 * @return True when strict predecessor pins may assert
	 */
	private static Boolean predecessorMatchesShippedValues()
	{
		return SEL_MaskingRule.computeFingerprint(findShippedRule(SEL_MaskingRule.RULE_MASK_CREDIT_CARD))
				== findShippedRule(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD).ReplacesFingerprint__c;
	}

	/**
	 * @description True while the installed Mask Payment Card Numbers record still carries its
	 * shipped values (live fingerprint equals its own ShippedFingerprint__c). False where the
	 * subscriber tuned the successor — strict successor pins must then fall back to the
	 * cross-generation guarantee.
	 *
	 * @return True when strict successor pins may assert
	 */
	private static Boolean successorMatchesShippedValues()
	{
		MaskingRule__mdt successor = findShippedRule(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD);
		return SEL_MaskingRule.computeFingerprint(successor) == successor.ShippedFingerprint__c;
	}

	/**
	 * @description Asserts the current-generation card behaviour directly against the Luhn-gated
	 * digit-run pattern — the engine guarantee that holds whatever values the org's installed
	 * records carry. The tuned-org fallback for every guarded card pin.
	 *
	 * @param input The input to mask
	 * @param expected The expected output
	 */
	private static void assertCurrentGenerationCardBehaviour(String input, String expected)
	{
		Assert.areEqual(expected, UTIL_String.maskWithLuhnValidatedRegex(input, CREDIT_CARD_CURRENT_PATTERN, CREDIT_CARD_REPLACEMENT, false),
				'The Luhn-gated digit-run pattern must produce the cross-generation card behaviour');
	}

	/**
	 * @description Loads the PACKAGE'S OWN shipped MaskingRule__mdt through the framework's
	 * getAll()-backed selector path — the engine's own source, and the only valid input shape
	 * for SEL_MaskingRule.computeFingerprint (getAll() truncates LongTextArea values where SOQL
	 * does not). Namespace-aware: an org-local clone sharing a packaged DeveloperName is never
	 * picked, in any packaging context. Fails the test with a clear message when the rule is
	 * not deployed.
	 *
	 * @param developerName The rule's DeveloperName
	 *
	 * @return The deployed packaged rule (never null — a missing rule fails the test)
	 */
	private static MaskingRule__mdt findShippedRule(String developerName)
	{
		String packageNamespace = UTIL_System.getManagedPackageNamespace() ?? UTIL_String.EMPTY;
		MaskingRule__mdt found;

		for(MaskingRule__mdt rule : new SEL_MaskingTarget().getAllRulesById().values())
		{
			if(rule.DeveloperName == developerName && (rule.NamespacePrefix ?? UTIL_String.EMPTY) == packageNamespace)
			{
				found = rule;
				break;
			}
		}

		Assert.isNotNull(found, 'the shipped rule ' + developerName + ' must be deployed for this test to run');
		return found;
	}

	/**
	 * @description The object|field|caller surfaces of every SHIPPED target bound to the given
	 * rule, matched namespace-aware so packaged and org-local rules sharing a DeveloperName
	 * never blend. Subscriber-authored targets binding a packaged rule are deliberately
	 * excluded — the mirror obligation covers shipped targets only; a subscriber's
	 * custom-object binding legitimately has no successor mirror.
	 *
	 * @param rule The rule whose shipped target surfaces to collect
	 * @param rulesById The rule universe keyed by Id
	 *
	 * @return The composite surface keys of the rule's shipped targets
	 */
	private static Set<String> findTargetSurfaces(MaskingRule__mdt rule, Map<Id, MaskingRule__mdt> rulesById)
	{
		Set<String> surfaces = new Set<String>();

		for(MaskingTarget__mdt target : new SEL_MaskingTarget().getAllTargets())
		{
			MaskingRule__mdt targetRule = rulesById.get(target.Rule__c);

			if(targetRule != null && targetRule.DeveloperName == rule.DeveloperName && targetRule.NamespacePrefix == rule.NamespacePrefix
					&& target.NamespacePrefix == rule.NamespacePrefix)
			{
				surfaces.add((target.SObjectType__c ?? UTIL_String.EMPTY) + UTIL_String.PIPE + (target.Field__c ?? UTIL_String.EMPTY)
						+ UTIL_String.PIPE + (target.CallerClass__c ?? UTIL_String.EMPTY));
			}
		}

		return surfaces;
	}

	/**
	 * @description Applies a shipped rule to an input string using the appropriate UTIL_String
	 * helper based on the rule's Mode.
	 *
	 * @param developerName The rule's DeveloperName
	 * @param input The input to mask
	 *
	 * @return The masked output
	 */
	private static String applyRule(String developerName, String input)
	{
		MaskingRule__mdt rule = findShippedRule(developerName);

		if(rule.Mode__c == SEL_MaskingRule.MODE_REGEX)
		{
			return UTIL_String.maskWithRegex(input, rule.Pattern__c, rule.Replacement__c, rule.CaseSensitive__c);
		}

		if(rule.Mode__c == SEL_MaskingRule.MODE_CREDIT_CARD)
		{
			return UTIL_String.maskWithLuhnValidatedRegex(input, rule.Pattern__c, rule.Replacement__c, rule.CaseSensitive__c);
		}

		if(rule.Mode__c == SEL_MaskingRule.MODE_JSON_KEY)
		{
			return UTIL_String.maskJsonKeys(input, rule.Pattern__c, rule.Replacement__c, rule.CaseSensitive__c);
		}

		return UTIL_String.maskExactMatch(input, rule.Pattern__c, rule.Replacement__c);
	}

	/**
	 * @description Asserts that applying a shipped rule to `input` produces `expected`.
	 *
	 * @param developerName The rule's DeveloperName
	 * @param input The input to mask
	 * @param expected The expected masked output
	 */
	private static void assertRuleMasks(String developerName, String input, String expected)
	{
		String output = applyRule(developerName, input);

		Assert.areEqual(expected, output, developerName + ' did not produce the expected masked output');
	}
}