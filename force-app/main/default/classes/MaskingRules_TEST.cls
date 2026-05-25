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
 * @date April 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
private class MaskingRules_TEST
{
	/**
	 * @description Tests that MaskEmail redacts the local-part and preserves the domain so the
	 * result is still a syntactically valid email address.
	 */
	@IsTest
	private static void shouldMaskEmail()
	{
		assertRuleMasks('MaskEmail', 'contact alice@example.com today', 'contact redacted@example.com today');
	}

	/**
	 * @description Tests that MaskSsn redacts nine-digit SSNs with hyphen separators.
	 */
	@IsTest
	private static void shouldMaskSsn()
	{
		assertRuleMasks('MaskSsn', 'SSN is 123-45-6789 verified', 'SSN is XXX-XX-XXXX verified');
	}

	/**
	 * @description Tests that MaskSsn excludes invalid SSN prefix 000.
	 */
	@IsTest
	private static void shouldNotMaskInvalidSsnPrefix()
	{
		assertRuleMasks('MaskSsn', 'ID 000-12-3456 passes', 'ID 000-12-3456 passes');
	}

	/**
	 * @description Tests that MaskPhoneUS redacts US-format phone numbers with dashes.
	 */
	@IsTest
	private static void shouldMaskPhoneUS()
	{
		assertRuleMasks('MaskPhoneUS', 'call 555-123-4567 now', 'call [PHONE_REDACTED] now');
	}

	/**
	 * @description Tests that MaskCreditCard redacts a hyphen-separated 16-digit card number.
	 */
	@IsTest
	private static void shouldMaskCreditCard()
	{
		assertRuleMasks('MaskCreditCard', 'card 4111-1111-1111-1111 saved', 'card [CARD_REDACTED] saved');
	}

	/**
	 * @description Tests that MaskCreditCard ships with FailureAction = BlockDml so a broken
	 * config aborts the DML rather than silently leaking cardholder data.
	 */
	@IsTest
	private static void shouldShipCreditCardWithBlockDmlFailureAction()
	{
		MaskingRule__mdt rule = findRule('MaskCreditCard');

		Assert.areEqual(SEL_MaskingRule.FAILURE_BLOCK_DML, rule.FailureAction__c, 'MaskCreditCard must ship with FailureAction = BlockDml');
	}

	/**
	 * @description Tests that MaskJwt redacts a three-segment token starting with the eyJ header.
	 */
	@IsTest
	private static void shouldMaskJwt()
	{
		assertRuleMasks('MaskJwt', 'token eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.abcdef here', 'token [JWT_REDACTED] here');
	}

	/**
	 * @description Tests that MaskAuthHeader redacts the full value after "Authorization:"
	 * including an optional "Bearer " scheme prefix.
	 */
	@IsTest
	private static void shouldMaskAuthHeaderWithBearerScheme()
	{
		assertRuleMasks('MaskAuthHeader', 'Authorization: Bearer s3cret', 'Authorization: [REDACTED]');
	}

	/**
	 * @description Tests that MaskAuthHeader also redacts a raw token after Authorization:
	 * (no Bearer scheme prefix).
	 */
	@IsTest
	private static void shouldMaskAuthHeaderWithRawToken()
	{
		assertRuleMasks('MaskAuthHeader', 'Authorization: abc123xyz', 'Authorization: [REDACTED]');
	}

	/**
	 * @description Tests that MaskSecretKeys (JsonKey mode) redacts the value under a password
	 * key in a JSON payload while leaving sibling keys intact.
	 */
	@IsTest
	private static void shouldMaskSecretKeysInJson()
	{
		String input = '{"user":"alice","password":"hunter2"}';
		String output = applyRule('MaskSecretKeys', input);

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
		String output = applyRule('MaskSecretKeys', input);

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
		assertRuleMasks('MaskSwiftBic', 'BIC DEUTDEFF500 verified', 'BIC [BIC_REDACTED] verified');
	}

	/**
	 * @description Tests that MaskSwiftBic ships with FailureAction = BlockDml.
	 */
	@IsTest
	private static void shouldShipSwiftBicWithBlockDmlFailureAction()
	{
		Assert.areEqual(SEL_MaskingRule.FAILURE_BLOCK_DML, findRule('MaskSwiftBic').FailureAction__c, 'MaskSwiftBic must ship with FailureAction = BlockDml');
	}

	/**
	 * @description Tests that MaskIban redacts a valid IBAN format account number.
	 */
	@IsTest
	private static void shouldMaskIban()
	{
		assertRuleMasks('MaskIban', 'IBAN DE89370400440532013000 present', 'IBAN [IBAN_REDACTED] present');
	}

	/**
	 * @description Tests that MaskIban ships with FailureAction = BlockDml.
	 */
	@IsTest
	private static void shouldShipIbanWithBlockDmlFailureAction()
	{
		Assert.areEqual(SEL_MaskingRule.FAILURE_BLOCK_DML, findRule('MaskIban').FailureAction__c, 'MaskIban must ship with FailureAction = BlockDml');
	}

	/**
	 * @description Tests that MaskMedicareBeneficiaryId redacts an 11-character MBI per the
	 * CMS positional format.
	 */
	@IsTest
	private static void shouldMaskMedicareBeneficiaryId()
	{
		assertRuleMasks('MaskMedicareBeneficiaryId', 'MBI 1EG4TE5MK73 on file', 'MBI [MBI_REDACTED] on file');
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
						findRule('MaskMedicareBeneficiaryId').FailureAction__c,
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
		String output = applyRule('MaskHealthKeywords', input);

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
		Assert.areEqual(SEL_MaskingRule.FAILURE_BLOCK_DML, findRule('MaskHealthKeywords').FailureAction__c, 'MaskHealthKeywords must ship with FailureAction = BlockDml');
	}

	/**
	 * @description Tests that MaskAwsAccessKey redacts a 20-character AKIA-prefixed
	 * (AWS Access Key ID) permanent IAM key.
	 */
	@IsTest
	private static void shouldMaskAwsAccessKey()
	{
		assertRuleMasks('MaskAwsAccessKey', 'AWS AKIAIOSFODNN7EXAMPLE used', 'AWS [AWS_KEY_REDACTED] used');
	}

	/**
	 * @description Tests that MaskUrlBasicAuth redacts embedded user:password in a URL while
	 * preserving the scheme and host.
	 */
	@IsTest
	private static void shouldMaskUrlBasicAuth()
	{
		assertRuleMasks('MaskUrlBasicAuth', 'see https://admin:hunter2@example.com ok', 'see https://[USER]:[PWD]@example.com ok');
	}

	/**
	 * @description Tests that MaskIpv4Private redacts a 192.168.x.x private-range address.
	 */
	@IsTest
	private static void shouldMaskIpv4Private()
	{
		assertRuleMasks('MaskIpv4Private', 'Connected to 192.168.1.1 ok', 'Connected to [IP_REDACTED] ok');
	}

	/**
	 * @description Tests that MaskIpv4Private ships inactive — opt-in for subscribers whose
	 * compliance scope treats internal IPs as sensitive identifiers.
	 */
	@IsTest
	private static void shouldShipIpv4PrivateInactive()
	{
		Assert.isFalse(findRule('MaskIpv4Private').IsActive__c, 'MaskIpv4Private must ship inactive (opt-in)');
	}

	/**
	 * @description Tests that MaskSsn excludes the invalid 666 prefix (known never-issued).
	 */
	@IsTest
	private static void shouldNotMaskSsnWithPrefix666()
	{
		assertRuleMasks('MaskSsn', 'record 666-12-3456 kept', 'record 666-12-3456 kept');
	}

	/**
	 * @description Tests that MaskMedicareBeneficiaryId rejects MBIs containing the
	 * excluded-letter set (S, L, O, I, B, Z). The 'S' in position 2 should prevent a match.
	 */
	@IsTest
	private static void shouldNotMaskMbiWithExcludedLetter()
	{
		assertRuleMasks('MaskMedicareBeneficiaryId', 'MBI 1SG4TE5MK73 rejected', 'MBI 1SG4TE5MK73 rejected');
	}

	/**
	 * @description Tests that MaskSwiftBic is case-sensitive — lowercase strings matching the
	 * BIC shape should NOT be redacted (protects against matching normal lowercase prose).
	 */
	@IsTest
	private static void shouldNotMaskLowercaseSwiftBic()
	{
		assertRuleMasks('MaskSwiftBic', 'not a bic deutdeff500 here', 'not a bic deutdeff500 here');
	}

	/**
	 * @description Tests that MaskAwsAccessKey is case-sensitive — lowercase akia strings
	 * should NOT be redacted.
	 */
	@IsTest
	private static void shouldNotMaskLowercaseAwsAccessKey()
	{
		assertRuleMasks('MaskAwsAccessKey', 'value akiaiosfodnn7example stays', 'value akiaiosfodnn7example stays');
	}

	/**
	 * @description Tests that MaskIpv4Private does NOT redact public IPv4 addresses (only
	 * RFC1918 private ranges + 127.x loopback are in scope).
	 */
	@IsTest
	private static void shouldNotMaskPublicIpv4Address()
	{
		assertRuleMasks('MaskIpv4Private', 'public 8.8.8.8 kept', 'public 8.8.8.8 kept');
	}

	/**
	 * @description Tests that MaskSecretKeys recognises the hyphen-variant api-key spelling,
	 * not just the underscore form.
	 */
	@IsTest
	private static void shouldMaskSecretKeysHyphenVariant()
	{
		String input = '{"api-key":"xyz","note":"ok"}';
		String output = applyRule('MaskSecretKeys', input);

		Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(output);
		Assert.areEqual('***SECRET***', parsed.get('api-key'), 'api-key should be redacted');
	}

	/**
	 * @description Tests that MaskPhoneUS recognises the parenthesised format common in the US.
	 */
	@IsTest
	private static void shouldMaskPhoneWithParentheses()
	{
		assertRuleMasks('MaskPhoneUS', 'call (555) 123-4567 now', 'call [PHONE_REDACTED] now');
	}

	/**
	 * @description Tests that MaskUrlBasicAuth preserves the scheme and host so log readers
	 * still see which endpoint was involved.
	 */
	@IsTest
	@SuppressWarnings('HttpUrlsUsage')
	private static void shouldPreserveSchemeAndHostInMaskUrlBasicAuth()
	{
		String output = applyRule('MaskUrlBasicAuth', 'http://user:pwd@api.example.com/path');

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
		assertRuleMasks('MaskEmail', 'user alice+marketing@example.com signed up', 'user redacted@example.com signed up');
	}

	/**
	 * @description Tests that MaskEmail handles subdomains and two-level TLDs.
	 */
	@IsTest
	private static void shouldMaskSubdomainEmail()
	{
		assertRuleMasks('MaskEmail', 'contact support@mail.example.co.uk today', 'contact redacted@mail.example.co.uk today');
	}

	/**
	 * @description Tests that MaskSsn handles space-separated format.
	 */
	@IsTest
	private static void shouldMaskSsnWithSpaceSeparators()
	{
		assertRuleMasks('MaskSsn', 'ID 123 45 6789 filed', 'ID XXX-XX-XXXX filed');
	}

	/**
	 * @description Tests that MaskSsn handles no-separator format.
	 */
	@IsTest
	private static void shouldMaskSsnWithoutSeparators()
	{
		assertRuleMasks('MaskSsn', 'packed 123456789 format', 'packed XXX-XX-XXXX format');
	}

	/**
	 * @description Tests that MaskPhoneUS handles dot-separated format.
	 */
	@IsTest
	private static void shouldMaskPhoneWithDotSeparators()
	{
		assertRuleMasks('MaskPhoneUS', 'call 555.123.4567 asap', 'call [PHONE_REDACTED] asap');
	}

	/**
	 * @description Tests that MaskPhoneUS handles the +1 country code prefix.
	 */
	@IsTest
	private static void shouldMaskPhoneWithCountryCode()
	{
		assertRuleMasks('MaskPhoneUS', 'dial +1 555-123-4567 now', 'dial [PHONE_REDACTED] now');
	}

	/**
	 * @description Tests that MaskCreditCard handles the 15-digit Amex card length.
	 */
	@IsTest
	private static void shouldMaskCreditCard15DigitAmex()
	{
		assertRuleMasks('MaskCreditCard', 'amex 378282246310005 saved', 'amex [CARD_REDACTED] saved');
	}

	/**
	 * @description Tests that MaskCreditCard does NOT redact a 13-digit millisecond
	 * timestamp. The rule's minimum length was raised to 15 specifically to avoid this
	 * false positive after a subscriber test (SubscriberChainSteps_TEST) failed when
	 * its correlation ID `correlation-1776297919466` was partially redacted.
	 */
	@IsTest
	private static void shouldNotMaskTimestampDigits()
	{
		assertRuleMasks('MaskCreditCard', 'correlation-1776297919466 saved', 'correlation-1776297919466 saved');
	}

	/**
	 * @description Tests that MaskCreditCard handles 16 digits separated by spaces.
	 */
	@IsTest
	private static void shouldMaskCreditCardWithSpaces()
	{
		assertRuleMasks('MaskCreditCard', 'card 4111 1111 1111 1111 saved', 'card [CARD_REDACTED] saved');
	}

	/**
	 * @description Regression guard for the user-reported masking-rehydrate bug. Drives the shipped
	 * `MaskCreditCard` rule (issuer-union regex + Luhn + MinInputLength + ApplicableFieldTypes)
	 * through the full `UTIL_FrameworkMasker` pipeline against a `LogEntryEvent__e` carrying a
	 * 16-digit transaction ID that starts with `1` — a digit that no card issuer prefix uses.
	 * The issuer-union regex skips the match entirely, Luhn never runs, the value is preserved.
	 * If a future rule change weakens the regex back to a permissive `\\d{15,19}` the test fails.
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
	 * `MaskCreditCard`. Request IDs interleave uppercase letters with digits — the issuer-union
	 * regex requires 13+ consecutive digits with a specific leading issuer prefix, which a
	 * Request ID format cannot produce. Guards against a future rule edit that relaxes the
	 * regex into matching letter-digit mixtures.
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
	 * UUID shape `8-4-4-4-12`). No segment meets the 13-digit floor, so the issuer-union regex
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
	 * `TID:` + 16 digits starting with `1`. Pre-fix this redacted to `TID:[CARD_REDACTED]`.
	 * Post-fix the issuer-union regex rejects leading-`1` digit runs so the value survives.
	 * If this test ever fails the user-visible bug has returned.
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
		assertRuleMasks('MaskSwiftBic', 'BIC DEUTDEFF filed', 'BIC [BIC_REDACTED] filed');
	}

	/**
	 * @description Tests that MaskIban handles the UK IBAN format (different country code).
	 */
	@IsTest
	private static void shouldMaskUkIban()
	{
		assertRuleMasks('MaskIban', 'IBAN GB82WEST12345698765432 sent', 'IBAN [IBAN_REDACTED] sent');
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

		String output = applyRule('MaskHealthKeywords', JSON.serialize(input));
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
		assertRuleMasks('MaskJwt', 'id SGVsbG9Xb3JsZA== here', 'id SGVsbG9Xb3JsZA== here');
	}

	/**
	 * @description Tests that MaskAwsAccessKey recognises the ASIA (STS session token) prefix
	 * in addition to the AKIA permanent-key prefix.
	 */
	@IsTest
	private static void shouldMaskAwsSessionAccessKey()
	{
		assertRuleMasks('MaskAwsAccessKey', 'session ASIAIOSFODNN7EXAMPLE used', 'session [AWS_KEY_REDACTED] used');
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

		String output = applyRule('MaskSecretKeys', JSON.serialize(input));
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
		assertRuleMasks('MaskIpv4Private', 'router 10.0.0.1 here', 'router [IP_REDACTED] here');
	}

	/**
	 * @description Tests that MaskIpv4Private covers the 172.16.x.x-172.31.x.x private range
	 * at the lower boundary.
	 */
	@IsTest
	private static void shouldMaskIpv4Range172LowerBoundary()
	{
		assertRuleMasks('MaskIpv4Private', 'host 172.16.0.1 ok', 'host [IP_REDACTED] ok');
	}

	/**
	 * @description Tests that MaskIpv4Private covers the 172.16-31 private range at the upper
	 * boundary.
	 */
	@IsTest
	private static void shouldMaskIpv4Range172UpperBoundary()
	{
		assertRuleMasks('MaskIpv4Private', 'host 172.31.255.1 ok', 'host [IP_REDACTED] ok');
	}

	/**
	 * @description Tests that MaskIpv4Private does NOT match 172.15.x.x (outside the private
	 * range — 172.0.0.0-172.15.255.255 is public).
	 */
	@IsTest
	private static void shouldNotMaskIpv4Address172BelowPrivateRange()
	{
		assertRuleMasks('MaskIpv4Private', 'host 172.15.0.1 stays', 'host 172.15.0.1 stays');
	}

	/**
	 * @description Tests that MaskIpv4Private does NOT match 172.32.x.x (outside the private
	 * range — 172.32.0.0+ is public).
	 */
	@IsTest
	private static void shouldNotMaskIpv4Address172AbovePrivateRange()
	{
		assertRuleMasks('MaskIpv4Private', 'host 172.32.0.1 stays', 'host 172.32.0.1 stays');
	}

	/**
	 * @description Tests that MaskIpv4Private covers the 127.x loopback range.
	 */
	@IsTest
	private static void shouldMaskIpv4Loopback()
	{
		assertRuleMasks('MaskIpv4Private', 'local 127.0.0.1 responds', 'local [IP_REDACTED] responds');
	}

	/**
	 * @description Tests that MaskUrlBasicAuth supports the http:// scheme as well as https://.
	 */
	@IsTest
	@SuppressWarnings('HttpUrlsUsage')
	private static void shouldMaskUrlBasicAuthOnHttpScheme()
	{
		assertRuleMasks('MaskUrlBasicAuth', 'ping http://admin:hunter2@api.local ok', 'ping http://[USER]:[PWD]@api.local ok');
	}

	/**
	 * @description Tests that MaskUrlBasicAuth leaves URLs without embedded credentials
	 * untouched.
	 */
	@IsTest
	private static void shouldNotMaskUrlWithoutBasicAuth()
	{
		assertRuleMasks('MaskUrlBasicAuth', 'ping https://example.com/v1 ok', 'ping https://example.com/v1 ok');
	}

	/**
	 * @description Loads a shipped MaskingRule__mdt record by DeveloperName.
	 *
	 * @param developerName The rule's DeveloperName
	 *
	 * @return The rule record with pattern/replacement/mode populated
	 */
	private static MaskingRule__mdt findRule(String developerName)
	{
		return
		[
				SELECT DeveloperName,
						Mode__c,
						Pattern__c,
						Replacement__c,
						CaseSensitive__c,
						IsActive__c,
						FailureAction__c
				FROM MaskingRule__mdt
				WHERE DeveloperName = :developerName
				LIMIT 1
		];
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
		MaskingRule__mdt rule = findRule(developerName);

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