// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for the ready-made `MaskingRule__mdt` records shipped with the
 * package. Each test loads a rule by DeveloperName, applies its pattern, replacement and mode to
 * a standard sample input, and asserts that the output is masked as expected. Fails if a shipped
 * rule's Pattern or Replacement is edited and the rule no longer does what its documentation says.
 *
 * @see UTIL_FrameworkMasker
 * @see UTIL_String
 *
 * @author Jason van Beukering
 *
 * @group Data Masking
 *
 * @date April 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
private class MaskingRules_TEST
{
	/**
	 * @description The current card pattern (a run of digits checked with the Luhn checksum) shipped on
	 * the Mask Payment Card Numbers successor rule. A copy of the shipped value, so the card tests can
	 * still check what the engine guarantees in orgs whose installed records were tuned, or were
	 * installed before the newer rule replaced the older one.
	 */
	private static final String CREDIT_CARD_CURRENT_PATTERN = '\\b\\d(?:[ -]?\\d){12,18}\\b';

	/**
	 * @description Replacement token both shipped card rules apply.
	 */
	private static final String CREDIT_CARD_REPLACEMENT = '[CARD_REDACTED]';

	/**
	 * @description A replacement text an admin might put on the older card rule in place of the shipped one. A changed
	 * replacement must stop the newer rule from replacing the older one.
	 */
	private static final String REPLACEMENT_CHANGED_BY_AN_ADMIN = '[CARD_HIDDEN_BY_ADMIN]';

	/**
	 * @description A copy of the card pattern the older card rule, MaskCreditCard, has shipped since version 1.0. It
	 * lists the number ranges of each card brand. These values never change, because the newer rule stores a
	 * fingerprint of them: a short code worked out from the values, used to tell whether an admin changed the rule.
	 */
	private static final String OLDER_CARD_RULE_PATTERN = '\\b(?:4(?:[ -]?\\d){12,15}|(?:5[1-5]|2(?:2[2-9]|[3-6]\\d|7[01]|720))(?:[ -]?\\d){14}'
			+ '|3[47](?:[ -]?\\d){13}|(?:6011|65\\d{2}|64[4-9]\\d)(?:[ -]?\\d){12}|3(?:0[0-5]|[68]\\d)(?:[ -]?\\d){11}'
			+ '|(?:2131|1800|35\\d{3})(?:[ -]?\\d){11}|(?:62|88)(?:[ -]?\\d){13,17})\\b';

	/**
	 * @description The shortest value, in characters, the older card rule looks at, as shipped since version 1.0.
	 */
	private static final Decimal OLDER_CARD_RULE_MINIMUM_INPUT_LENGTH = 15;

	/**
	 * @description The shortest value, in characters, the newer card rule looks at, as this version ships it.
	 */
	private static final Decimal NEWER_CARD_RULE_MINIMUM_INPUT_LENGTH = 13;

	/**
	 * @description The field types both shipped card rules look at.
	 */
	private static final String CARD_RULE_FIELD_TYPES = 'STRING;TEXTAREA;ENCRYPTEDSTRING';

	/**
	 * @description The number of characters a value needs before the shipped MaskJwt rule looks at it.
	 */
	private static final Integer JWT_MINIMUM_INPUT_LENGTH = 20;

	/**
	 * @description The names of the four shipped targets that point at the older card rule, MaskCreditCard: one each
	 * for API calls, API issues, chain runs and log events.
	 */
	private static final List<String> OLDER_CARD_RULE_TARGET_NAMES = new List<String> {'ApiCall_All_Card', 'Issue_All_Card', 'Chain_All_Card', 'Event_All_Card'};

	/**
	 * @description A copy of the description this version ships on the older card rule, MaskCreditCard. An upgrade never
	 * changes a description the org already has, so an org carries this text only after a fresh install of this version.
	 */
	private static final String CREDIT_CARD_DESCRIPTION_OF_THIS_VERSION = 'Older card rule, replaced by Mask Payment Card Numbers, which covers the same '
			+ 'cards. Ships off: on a long text full of digits, its pattern can use so much processing time that the save stops. If masking fails, the '
			+ 'value becomes [MASKING_FAILURE].';

	/**
	 * @description A copy of the description this version ships on the newer card rule, MaskPaymentCard. An upgrade never
	 * changes a description the org already has, so an org carries this text only after a fresh install of this version.
	 */
	private static final String PAYMENT_CARD_DESCRIPTION_OF_THIS_VERSION = 'Hides 13 to 19 digit numbers that pass the Luhn (mod-10) card checksum, '
			+ 'for all major card brands, with spaces or hyphens allowed. If masking fails, the value is replaced with [MASKING_FAILURE] and the save '
			+ 'goes on. Review with PCI before disabling.';

	/**
	 * @description The description an earlier version shipped on the older card rule. An org upgraded from that version
	 * still carries it.
	 */
	private static final String CREDIT_CARD_DESCRIPTION_OF_AN_EARLIER_VERSION = 'Redacts credit card numbers matching ISO/IEC 7812 issuer prefixes '
			+ '(Visa, MC, Amex, Discover, Diners, JCB, UnionPay) that additionally pass the Luhn mod-10 checksum. MinInputLength 15, Block DML. Review '
			+ 'with PCI before deactivating.';

	/**
	 * @description The description an earlier version shipped on the newer card rule. An org upgraded from that version
	 * still carries it.
	 */
	private static final String PAYMENT_CARD_DESCRIPTION_OF_AN_EARLIER_VERSION = 'Redacts 13-19 digit numbers passing the Luhn (mod-10) checksum. '
			+ 'Covers all major card brands (Visa, Mastercard, Amex, Discover, JCB, UnionPay, Maestro); spaces or hyphens allowed. Blocks saving if '
			+ 'masking fails. Review with PCI before disabling.';

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
	 * @description Tests that a hyphen-separated 16-digit card number is masked. The test is strict
	 * against the installed MaskCreditCard record (now replaced by a successor) while it keeps its
	 * shipped 1.0 values. In tuned orgs it checks the current pattern directly instead (subscribers may
	 * tune rules, and that must not fail the package's own tests).
	 */
	@IsTest
	private static void shouldMaskCreditCard()
	{
		if(isPredecessorUntuned())
		{
			assertRuleMasks(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, 'card 4111-1111-1111-1111 saved', 'card [CARD_REDACTED] saved');
			return;
		}

		assertCurrentGenerationCardBehaviour('card 4111-1111-1111-1111 saved', 'card [CARD_REDACTED] saved');
	}

	/**
	 * @description Tests that both card rules ship with the Write Failure Marker failure action. When a card rule fails
	 * on a value, the value is hidden behind the failure marker and the save goes on. The card value is never kept, and
	 * a hard-to-read value cannot stop a save. An org upgraded from an earlier version keeps its own failure actions,
	 * so there the test checks that the newer rule still replaces the older one instead.
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldShipBothCardRulesOnWriteFailureMarker()
	{
		assertCardRuleFailureActions();
	}

	/**
	 * @description Tests that the older card rule ships off. MaskPaymentCard covers every card the older rule covers.
	 * On a long text full of digits, the older rule's pattern can use so much processing time that the save stops, so
	 * a fresh install runs only the newer rule. An org upgraded from an earlier version keeps the older rule on, so
	 * there the test checks that the newer rule still replaces it instead.
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldShipTheOlderCardRuleInactive()
	{
		assertOlderCardRuleState();
	}

	/**
	 * @description Tests that the four shipped targets of the older card rule ship off with their rule. Each is read by
	 * name through the target selector, and each must be found. After a fresh install each must be off. An org upgraded
	 * from an earlier version keeps them on, so there the test checks that the newer rule still replaces the older one,
	 * which makes the targets that are on mask nothing.
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldShipTheFourTargetsOfTheOlderCardRuleInactive()
	{
		assertOlderCardRuleTargets();
	}

	/**
	 * @description Tests the three card checks on rules and targets that carry the values a fresh install of this
	 * version gets: both rules on Write Failure Marker, the older rule and its four targets off, and this version's
	 * descriptions. The checks must take their strict path and pass.
	 */
	@IsTest
	private static void shouldCheckTheShippedCardValuesAfterAFreshInstall()
	{
		registerCardRules(
				buildCardRuleCopy(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, true, SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER, PAYMENT_CARD_DESCRIPTION_OF_THIS_VERSION),
				buildCardRuleCopy(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, false, SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER, CREDIT_CARD_DESCRIPTION_OF_THIS_VERSION),
				false);

		Assert.isTrue(hasCardRuleDescriptionsOfAFreshInstall(), 'Expected the card rules to read as a fresh install of this version');
		assertCardRuleFailureActions();
		assertOlderCardRuleState();
		assertOlderCardRuleTargets();
	}

	/**
	 * @description Tests the three card checks on rules and targets that carry the values an org upgraded from an earlier
	 * version keeps: both rules on Block DML, the older rule and its four targets on, and the earlier descriptions. The
	 * checks must take the other path and pass, because the newer rule still replaces the older one there. The copies
	 * carry the values the package ships, not the org's own, so the test also passes in an org whose admin changed a
	 * card rule.
	 */
	@IsTest
	private static void shouldCheckThatTheNewerCardRuleStillReplacesTheOlderOneAfterAnUpgrade()
	{
		registerCardRules(
				buildCardRuleCopy(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, true, SEL_MaskingRule.FAILURE_BLOCK_DML, PAYMENT_CARD_DESCRIPTION_OF_AN_EARLIER_VERSION),
				buildCardRuleCopy(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, true, SEL_MaskingRule.FAILURE_BLOCK_DML, CREDIT_CARD_DESCRIPTION_OF_AN_EARLIER_VERSION),
				true);

		Assert.isFalse(hasCardRuleDescriptionsOfAFreshInstall(), 'Expected the card rules to read as an upgraded org');
		Assert.isTrue(isOlderCardRuleReplaced(), 'Expected the newer card rule to replace the older one in the upgraded org');
		assertCardRuleFailureActions();
		assertOlderCardRuleState();
		assertOlderCardRuleTargets();
	}

	/**
	 * @description Tests the card checks in an org upgraded from an earlier version whose admin changed the replacement
	 * text of the older card rule. The changed rule no longer matches the fingerprint stored on the newer rule (a short
	 * code worked out from the values that decide how a rule masks), so the newer rule must not replace the older one,
	 * and the older rule keeps masking. The three card checks and the fingerprint check must expect exactly that.
	 */
	@IsTest
	private static void shouldStopReplacingTheOlderCardRuleWhenAnAdminChangedItsReplacement()
	{
		MaskingRule__mdt older = buildCardRuleCopy(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, true, SEL_MaskingRule.FAILURE_BLOCK_DML, CREDIT_CARD_DESCRIPTION_OF_AN_EARLIER_VERSION);
		older.Replacement__c = REPLACEMENT_CHANGED_BY_AN_ADMIN;
		registerCardRules(
				buildCardRuleCopy(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, true, SEL_MaskingRule.FAILURE_BLOCK_DML, PAYMENT_CARD_DESCRIPTION_OF_AN_EARLIER_VERSION),
				older,
				true);

		Assert.isFalse(hasCardRuleDescriptionsOfAFreshInstall(), 'Expected the card rules to read as an upgraded org');
		Assert.isFalse(isOlderCardRuleReplaced(), 'Expected the newer card rule not to replace the older one after an admin changed its replacement');
		assertCardRuleFailureActions();
		assertOlderCardRuleState();
		assertOlderCardRuleTargets();
		assertStoredFingerprint(SEL_MaskingRule.computeFingerprint(findShippedRule(SEL_MaskingRule.RULE_MASK_CREDIT_CARD)),
				findShippedRule(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD).ReplacesFingerprint__c, SEL_MaskingRule.RULE_MASK_CREDIT_CARD);
	}

	/**
	 * @description Tests the card checks in an org upgraded from an earlier version whose admin switched the newer card
	 * rule off. A rule that is off replaces nothing, so the older rule keeps masking even though both rules still carry
	 * their shipped values. The three card checks must expect exactly that.
	 */
	@IsTest
	private static void shouldKeepTheOlderCardRuleRunningWhenTheNewerOneIsOff()
	{
		registerCardRules(
				buildCardRuleCopy(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, false, SEL_MaskingRule.FAILURE_BLOCK_DML, PAYMENT_CARD_DESCRIPTION_OF_AN_EARLIER_VERSION),
				buildCardRuleCopy(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, true, SEL_MaskingRule.FAILURE_BLOCK_DML, CREDIT_CARD_DESCRIPTION_OF_AN_EARLIER_VERSION),
				true);

		Assert.isFalse(hasCardRuleDescriptionsOfAFreshInstall(), 'Expected the card rules to read as an upgraded org');
		Assert.isFalse(isOlderCardRuleReplaced(), 'Expected the newer card rule not to replace the older one while the newer rule is off');
		assertCardRuleFailureActions();
		assertOlderCardRuleState();
		assertOlderCardRuleTargets();
	}

	/**
	 * @description Tests that no shipped target that is on points at a shipped rule that is off. Such a target masks
	 * nothing, and the Data Masking Advisor warns about it, so a fresh install must open the Advisor with no such
	 * warning. The targets of the two card rules are left out. An admin may switch the newer card rule off after an
	 * upgrade, and its targets then stay on, so the older rule's targets take over the work. The card checks above
	 * check the targets of the older card rule.
	 */
	@IsTest
	private static void shouldShipNoActiveTargetOnAnInactiveShippedRule()
	{
		Set<String> cardRuleNames = new Set<String> {SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, SEL_MaskingRule.RULE_MASK_CREDIT_CARD};
		Map<Id, MaskingRule__mdt> rulesById = new SEL_MaskingTarget().getAllRulesById();
		List<String> activeTargetsOnInactiveRules = new List<String>();
		Integer checkedTargetCount = 0;

		for(MaskingTarget__mdt target : findShippedTargets())
		{
			MaskingRule__mdt rule = rulesById.get(target.Rule__c);

			if(cardRuleNames.contains(rule?.DeveloperName))
			{
				continue;
			}

			checkedTargetCount++;

			if(target.IsActive__c == true && rule?.IsActive__c != true)
			{
				activeTargetsOnInactiveRules.add(target.DeveloperName);
			}
		}

		Assert.isTrue(checkedTargetCount > 0, 'Expected shipped targets of rules other than the card rules to be deployed for this test to run');
		Assert.isTrue(activeTargetsOnInactiveRules.isEmpty(), 'Expected no shipped target that is on to point at a rule that is off: ' + activeTargetsOnInactiveRules);
	}

	/**
	 * @description Tests that the fingerprints stored on MaskPaymentCard are the ones the fingerprint code gives for the
	 * two shipped card rules, read the way the masking engine reads them. A wrong stored fingerprint reads as a rule an
	 * admin changed, and the newer rule would then never replace the older one. After a fresh install of this version
	 * both must match. In an upgraded org an admin may have changed a card rule, so a rule whose values no longer match
	 * must stop the newer rule from replacing the older one instead.
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldShipAFingerprintThatMatchesTheHelperForEachCardRule()
	{
		MaskingRule__mdt newer = findShippedRule(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD);
		MaskingRule__mdt older = findShippedRule(SEL_MaskingRule.RULE_MASK_CREDIT_CARD);

		assertStoredFingerprint(SEL_MaskingRule.computeFingerprint(newer), newer.ShippedFingerprint__c, SEL_MaskingRule.RULE_MASK_PAYMENT_CARD);
		assertStoredFingerprint(SEL_MaskingRule.computeFingerprint(older), newer.ReplacesFingerprint__c, SEL_MaskingRule.RULE_MASK_CREDIT_CARD);
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
	 * @description Tests that no rule the package ships keeps the failure action that lets a broken
	 * rule pass the value through unmasked. Every shipped rule must stop or mark the value instead.
	 * It reads the installed rules the same way as the other shipped-record tests and looks at the
	 * package's own rules only, so a rule a subscriber wrote never counts.
	 */
	@IsTest
	private static void shouldShipNoRuleOnLogAndContinue()
	{
		String packageNamespace = UTIL_System.getManagedPackageNamespace() ?? UTIL_String.EMPTY;
		Integer shippedRuleCount = 0;

		for(MaskingRule__mdt rule : new SEL_MaskingTarget().getAllRulesById().values())
		{
			if((rule.NamespacePrefix ?? UTIL_String.EMPTY) == packageNamespace)
			{
				shippedRuleCount++;
				Assert.areNotEqual(SEL_MaskingRule.FAILURE_LOG_AND_CONTINUE, rule.FailureAction__c, 'Expected ' + rule.DeveloperName + ' to fail closed');
			}
		}

		Assert.isTrue(shippedRuleCount > 0, 'Expected the shipped rules to be deployed for this test to run');
	}

	/**
	 * @description Tests that MaskJwt ships active, writes a failure marker when it fails, and skips
	 * values shorter than 20 characters. It reads the installed record and asserts on the values the
	 * package ships. It has no guard for a rule a subscriber changed: the test checks the record as the
	 * package ships it, and an org that changed or upgraded the record may hold other values.
	 */
	@IsTest
	private static void shouldShipJwtRuleActiveOnWriteFailureMarker()
	{
		MaskingRule__mdt rule = findShippedRule(SEL_MaskingRule.RULE_MASK_JWT);

		Assert.isTrue(rule.IsActive__c, 'Expected MaskJwt to ship active');
		Assert.areEqual(SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER, rule.FailureAction__c, 'Expected MaskJwt to write a failure marker');
		Assert.areEqual(JWT_MINIMUM_INPUT_LENGTH, rule.MinInputLength__c?.intValue(), 'Expected MaskJwt to skip values shorter than the shortest real token');
	}

	/**
	 * @description Tests that the MaskJwt pattern still matches a very short real token. The token
	 * has 32 characters, just over the 20 character floor. This test applies the pattern only and does
	 * not look at the floor. The record test above checks the floor value itself.
	 */
	@IsTest
	private static void shouldMaskAMinimalJwtLongerThanTheLengthFloor()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_JWT, 'eyJhbGciOiJub25lIn0.eyJhIjoxfQ.x', '[JWT_REDACTED]');
	}

	/**
	 * @description Tests that MaskSecretKeys ships with the failure action that writes a failure
	 * marker, so a broken rule never lets a secret key through in plain text.
	 */
	@IsTest
	private static void shouldShipSecretKeysRuleOnWriteFailureMarker()
	{
		MaskingRule__mdt rule = findShippedRule(SEL_MaskingRule.RULE_MASK_SECRET_KEYS);

		Assert.areEqual(SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER, rule.FailureAction__c, 'Expected MaskSecretKeys to write a failure marker');
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
	 * @description Tests that MaskMedicareBeneficiaryId redacts an 11-character MBI that follows the
	 * CMS format, where each position allows certain characters.
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
	 * @description Tests that MaskIpv4Private ships inactive. Subscribers switch it on when their
	 * compliance rules treat internal IP addresses as sensitive.
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
	 * @description Tests that MaskSwiftBic is case-sensitive: lower-case text with the BIC shape
	 * must NOT be redacted (so the rule does not match normal lower-case words).
	 */
	@IsTest
	private static void shouldNotMaskLowercaseSwiftBic()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_SWIFT_BIC, 'not a bic deutdeff500 here', 'not a bic deutdeff500 here');
	}

	/**
	 * @description Tests that MaskAwsAccessKey is case-sensitive: lower-case akia text
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
	 * @description Tests that a 15-digit Amex card is masked. The test is strict against the installed
	 * MaskCreditCard record (now replaced by a successor) while it keeps its shipped 1.0 values, and
	 * checks the current pattern directly in tuned orgs.
	 */
	@IsTest
	private static void shouldMaskCreditCard15DigitAmex()
	{
		if(isPredecessorUntuned())
		{
			assertRuleMasks(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, 'amex 378282246310005 saved', 'amex [CARD_REDACTED] saved');
			return;
		}

		assertCurrentGenerationCardBehaviour('amex 378282246310005 saved', 'amex [CARD_REDACTED] saved');
	}

	/**
	 * @description Tests that Mask Payment Card Numbers does NOT redact a 13-digit millisecond
	 * timestamp. The digit-run pattern matches the 13-digit value, but the value fails the Luhn
	 * (mod-10) checksum, so the Luhn check leaves it alone. This guards against a false match that a
	 * subscriber test (SubscriberChainSteps_TEST) hit when part of its correlation ID
	 * `correlation-1776297919466` was redacted.
	 */
	@IsTest
	private static void shouldNotMaskTimestampDigits()
	{
		if(isSuccessorUntuned())
		{
			assertRuleMasks(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, 'correlation-1776297919466 saved', 'correlation-1776297919466 saved');
			return;
		}

		assertCurrentGenerationCardBehaviour('correlation-1776297919466 saved', 'correlation-1776297919466 saved');
	}

	/**
	 * @description Tests that 16 digits separated by spaces are masked. The test is strict against the
	 * installed MaskCreditCard record (now replaced by a successor) while it keeps its shipped 1.0
	 * values, and checks the current pattern directly in tuned orgs.
	 */
	@IsTest
	private static void shouldMaskCreditCardWithSpaces()
	{
		if(isPredecessorUntuned())
		{
			assertRuleMasks(SEL_MaskingRule.RULE_MASK_CREDIT_CARD, 'card 4111 1111 1111 1111 saved', 'card [CARD_REDACTED] saved');
			return;
		}

		assertCurrentGenerationCardBehaviour('card 4111 1111 1111 1111 saved', 'card [CARD_REDACTED] saved');
	}

	/**
	 * @description Guards the 2-series Mastercard fix. Standard 16-digit Mastercard 2-series cards
	 * (BIN range 2221-2720, issued since 2017) must be masked. The older MaskCreditCard pattern, built
	 * from a list of issuers, never matched them; the successor's Luhn-checked digit-run pattern does.
	 * The test is strict only while the installed successor matches its shipped fingerprint.
	 * Subscribers may tune rules, and that must not fail the package's own tests, so in that case the
	 * test checks what the engine guarantees against the current pattern directly.
	 */
	@IsTest
	private static void shouldMaskTwoSeriesMastercard()
	{
		if(isSuccessorUntuned())
		{
			assertRuleMasks(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, 'card 2223000048400011 saved', 'card [CARD_REDACTED] saved');
			return;
		}

		assertCurrentGenerationCardBehaviour('card 2223000048400011 saved', 'card [CARD_REDACTED] saved');
	}

	/**
	 * @description Tests that Mask Payment Card Numbers redacts a 19-digit card (the longest
	 * supported length), here a UnionPay number. The successor's Luhn-checked digit-run pattern
	 * accepts every length from 13 to 19 digits.
	 */
	@IsTest
	private static void shouldMaskNineteenDigitCard()
	{
		if(isSuccessorUntuned())
		{
			assertRuleMasks(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD, 'card 6205500000000000004 saved', 'card [CARD_REDACTED] saved');
			return;
		}

		assertCurrentGenerationCardBehaviour('card 6205500000000000004 saved', 'card [CARD_REDACTED] saved');
	}

	/**
	 * @description Tests that Mask Payment Card Numbers ships with MinInputLength 13, so the shortest
	 * supported card length (a 13-digit Visa) is not skipped by the minimum length before the
	 * Luhn-checked pattern runs. The test is strict only while the installed record matches its
	 * shipped fingerprint. Subscribers may tune the successor (even clear the minimum length), and that
	 * must not fail the package's own tests, so tuned orgs check the shipped 13-digit pattern directly.
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
	 * @description Tests that the MaskCreditCard record, now replaced by a successor, still ships the
	 * 1.0 values that decide how it masks, on purpose. Its on or off state and its failure action are not
	 * among them. The successor (Mask Payment Card Numbers) carries the current behaviour.
	 * DO NOT "modernise" the older record: the same shipped values are what make new installs and
	 * upgraded orgs behave the same, and the supersession fingerprint depends on them. In orgs where
	 * the record was customised (or installed from a 1.1 build before release) it may differ, and
	 * there the rule must not be superseded: it keeps masking.
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
				'Superseded MaskCreditCard intentionally ships its original 1.0 values: the successor carries current behaviour; never modernise this record');
		Assert.areEqual(successorSupersedes, SEL_MaskingRule.findSupersededRuleNames(universe).contains(predecessorKey),
				'The untuned predecessor must be superseded exactly while the successor is active and untuned');
	}

	/**
	 * @description Tests that every shipped target linked to a replaced (predecessor) rule has a
	 * successor target for the same object, field and caller. A missing one would mean some fields
	 * quietly stop being masked. Holds for every Replaces__c link in the org, packaged or org-local,
	 * matched by namespace.
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
	 * @description Guards against a masking bug a user reported coming back. Runs the shipped
	 * `MaskCreditCard` rule (a broad digit-run regex checked with the Luhn mod-10 checksum, plus
	 * MinInputLength and ApplicableFieldTypes) through the full `UTIL_FrameworkMasker` path against a
	 * `LogEntryEvent__e` that carries a 16-digit transaction ID. The regex matches the digit run, but
	 * the value fails the Luhn checksum, so the engine keeps it. If a later change drops the Luhn check,
	 * this test fails.
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
	 * @description Guards that a value shaped like a Salesforce Request ID is not changed by
	 * `MaskCreditCard`. Request IDs mix upper-case letters with digits, so there is never a run of 13
	 * or more digits in a row (the least the digit-run pattern needs): the regex never matches and the
	 * Luhn check is never reached. Guards against a later rule edit that loosens the regex so it
	 * matches mixes of letters and digits.
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
	 * @description Guards a correlation ID shaped like a UUID. UUIDs are hex digits and hyphens: the
	 * hex letters `a-f` break every digit run into at most 8 characters (the first part of the UUID
	 * shape `8-4-4-4-12`). No part reaches the 13-digit minimum, so the digit-run regex cannot match
	 * anywhere in the UUID, and the value is kept as it is.
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
	 * @description Guards the exact case a user reported: a JSON payload inside `ApiCall__c.Request__c`
	 * with a `parentTransactionId` field whose value is `TID:` + 16 digits. Before the fix this was
	 * masked to `TID:[CARD_REDACTED]`. Since the fix, the digit-run regex matches the 16-digit run but
	 * the value fails the Luhn checksum, so it is kept. If this test ever fails, the bug users saw has
	 * come back.
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
	 * mrn, rx_number, prescription, icd10, ndc, patient_id). Fails if one keyword is removed from
	 * the regex's list of choices by accident.
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
	 * @description Tests that MaskSecretKeys catches every shipped keyword in its regex: password,
	 * passwd, secret, token, api_key, authorization, bearer, client_secret, private_key, access_token,
	 * refresh_token.
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
	 * range: 172.0.0.0-172.15.255.255 is public).
	 */
	@IsTest
	private static void shouldNotMaskIpv4Address172BelowPrivateRange()
	{
		assertRuleMasks(SEL_MaskingRule.RULE_MASK_IPV4_PRIVATE, 'host 172.15.0.1 stays', 'host 172.15.0.1 stays');
	}

	/**
	 * @description Tests that MaskIpv4Private does NOT match 172.32.x.x (outside the private
	 * range: 172.32.0.0 and above is public).
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
	 * shipped values (its current fingerprint equals the successor's ReplacesFingerprint__c). False in
	 * orgs where the subscriber tuned the record, or where it was installed before the newer rule
	 * replaced it. Tests that check the exact 1.0 values must then check the current pattern instead.
	 *
	 * @return True when tests may check the exact shipped values of the older rule
	 */
	private static Boolean isPredecessorUntuned()
	{
		return SEL_MaskingRule.computeFingerprint(findShippedRule(SEL_MaskingRule.RULE_MASK_CREDIT_CARD))
				== findShippedRule(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD).ReplacesFingerprint__c;
	}

	/**
	 * @description True while the installed Mask Payment Card Numbers record still carries its
	 * shipped values (its current fingerprint equals its own ShippedFingerprint__c). False where the
	 * subscriber tuned the successor. Tests that check the successor's exact values must then check
	 * the current pattern instead.
	 *
	 * @return True when tests may check the exact shipped values of the successor rule
	 */
	private static Boolean isSuccessorUntuned()
	{
		MaskingRule__mdt successor = findShippedRule(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD);
		return SEL_MaskingRule.computeFingerprint(successor) == successor.ShippedFingerprint__c;
	}

	/**
	 * @description True when both card rules carry the descriptions this version ships. A fresh install of this version
	 * writes them. An upgrade never changes a description the org already has, so an org upgraded from an earlier
	 * version keeps the earlier text and gets false. The description is used because, like the failure action and the
	 * on or off state, it is a value the admin owns, and this version is the first to ship it, so it tells the two kinds
	 * of org apart. Apex cannot read when or how the package was installed, so no install fact can do this.
	 * What it cannot see: an admin who edited a description makes the card checks take the upgraded path, which checks
	 * less. An admin who changed a failure action or an on or off state after a fresh install, but left the
	 * descriptions alone, makes the strict checks fail, as with every other shipped value an admin changed. A later
	 * version that changes either description must change the copies in this class with it.
	 *
	 * @return True when the card rules carry the descriptions of a fresh install of this version
	 */
	private static Boolean hasCardRuleDescriptionsOfAFreshInstall()
	{
		return findShippedRule(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD).Description__c == PAYMENT_CARD_DESCRIPTION_OF_THIS_VERSION
				&& findShippedRule(SEL_MaskingRule.RULE_MASK_CREDIT_CARD).Description__c == CREDIT_CARD_DESCRIPTION_OF_THIS_VERSION;
	}

	/**
	 * @description True when the masking engine skips the older card rule because the newer one replaces it.
	 *
	 * @return True when the older card rule is in the engine's set of replaced rules
	 */
	private static Boolean isOlderCardRuleReplaced()
	{
		List<MaskingRule__mdt> allRules = new SEL_MaskingTarget().getAllRulesById().values();
		String olderRuleName = SEL_MaskingRule.resolveQualifiedDeveloperName(findShippedRule(SEL_MaskingRule.RULE_MASK_CREDIT_CARD));

		return SEL_MaskingRule.findSupersededRuleNames(allRules).contains(olderRuleName);
	}

	/**
	 * @description Checks what must hold for the card rules in an org that does not carry the values of a fresh install.
	 * The newer rule replaces the older one exactly while the newer rule is on and both rules still mask the way they
	 * were shipped. The failure action and the on or off state of the older rule play no part. When the older rule is
	 * replaced, the engine skips it, so its targets that are on mask nothing.
	 */
	private static void assertOlderCardRuleReplacedWhileUnchanged()
	{
		Boolean shouldBeReplaced = findShippedRule(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD).IsActive__c == true && isSuccessorUntuned() && isPredecessorUntuned();

		Assert.areEqual(shouldBeReplaced, isOlderCardRuleReplaced(),
				'Expected the newer card rule to replace the older one exactly while the newer rule is on and both still mask as shipped');
	}

	/**
	 * @description Checks the failure action of both card rules. After a fresh install of this version both must be on
	 * Write Failure Marker. In any other org it checks that the newer rule still replaces the older one.
	 */
	private static void assertCardRuleFailureActions()
	{
		if(!hasCardRuleDescriptionsOfAFreshInstall())
		{
			assertOlderCardRuleReplacedWhileUnchanged();
			return;
		}

		Assert.areEqual(SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER, findShippedRule(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD).FailureAction__c,
				'Expected MaskPaymentCard to ship with Write Failure Marker');
		Assert.areEqual(SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER, findShippedRule(SEL_MaskingRule.RULE_MASK_CREDIT_CARD).FailureAction__c,
				'Expected MaskCreditCard to ship with Write Failure Marker');
	}

	/**
	 * @description Checks the on or off state of the older card rule. After a fresh install of this version it must be
	 * off. In any other org it checks that the newer rule still replaces the older one.
	 */
	private static void assertOlderCardRuleState()
	{
		if(!hasCardRuleDescriptionsOfAFreshInstall())
		{
			assertOlderCardRuleReplacedWhileUnchanged();
			return;
		}

		Assert.isFalse(findShippedRule(SEL_MaskingRule.RULE_MASK_CREDIT_CARD).IsActive__c, 'Expected MaskCreditCard to ship inactive');
	}

	/**
	 * @description Checks the four shipped targets of the older card rule. Each must be found in every org. After a fresh
	 * install of this version each must be off. In any other org it checks that the newer rule still replaces the older
	 * one, so the targets that are on mask nothing.
	 */
	private static void assertOlderCardRuleTargets()
	{
		Map<String, MaskingTarget__mdt> shippedTargetsByName = new Map<String, MaskingTarget__mdt>();

		for(MaskingTarget__mdt target : findShippedTargets())
		{
			shippedTargetsByName.put(target.DeveloperName, target);
		}

		for(String targetName : OLDER_CARD_RULE_TARGET_NAMES)
		{
			Assert.isTrue(shippedTargetsByName.containsKey(targetName), 'Expected the shipped target ' + targetName + ' to be deployed');
		}

		if(!hasCardRuleDescriptionsOfAFreshInstall())
		{
			assertOlderCardRuleReplacedWhileUnchanged();
			return;
		}

		for(String targetName : OLDER_CARD_RULE_TARGET_NAMES)
		{
			Assert.isFalse(shippedTargetsByName.get(targetName).IsActive__c, 'Expected the shipped target ' + targetName + ' to ship inactive');
		}
	}

	/**
	 * @description Checks one fingerprint stored on the newer card rule against the fingerprint worked out from a card
	 * rule's values. After a fresh install of this version the two must be equal. In any other org they must be equal
	 * too, unless an admin changed the rule. A changed rule must then stop the newer rule from replacing the older
	 * one, so the older rule keeps masking.
	 *
	 * @param computed The fingerprint worked out from the rule's values in the org
	 * @param stored The fingerprint stored on the newer card rule
	 * @param ruleName The name of the rule the fingerprint belongs to
	 */
	private static void assertStoredFingerprint(String computed, String stored, String ruleName)
	{
		if(computed == stored || hasCardRuleDescriptionsOfAFreshInstall())
		{
			Assert.areEqual(computed, stored, 'Expected the stored fingerprint of ' + ruleName + ' to match its values');
			return;
		}

		Assert.isFalse(isOlderCardRuleReplaced(), 'Expected the newer card rule not to replace the older one while ' + ruleName + ' is changed');
	}

	/**
	 * @description Builds an in-memory copy of a card rule with the values that decide how it masks as the package ships
	 * them, whatever the org's own record holds, and with the given failure action, on or off state and description.
	 * The newer rule's copy also carries the two fingerprints stored on the org's newer rule. An upgrade always delivers
	 * those, so they match the copies in every org of this version.
	 *
	 * @param developerName The name of the card rule, MaskPaymentCard or MaskCreditCard
	 * @param isActive The IsActive__c value of the copy
	 * @param failureAction The FailureAction__c value of the copy
	 * @param description The Description__c value of the copy
	 *
	 * @return The in-memory copy
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static MaskingRule__mdt buildCardRuleCopy(String developerName, Boolean isActive, String failureAction, String description)
	{
		MaskingRule__mdt shippedNewer = findShippedRule(SEL_MaskingRule.RULE_MASK_PAYMENT_CARD);
		Boolean isNewer = developerName == SEL_MaskingRule.RULE_MASK_PAYMENT_CARD;

		return (MaskingRule__mdt)TST_Builder.of(MaskingRule__mdt.SObjectType)
				.withOverride(MaskingRule__mdt.DeveloperName, developerName)
				.withOverride(MaskingRule__mdt.NamespacePrefix, shippedNewer.NamespacePrefix)
				.withOverride(MaskingRule__mdt.Pattern__c, isNewer ? CREDIT_CARD_CURRENT_PATTERN : OLDER_CARD_RULE_PATTERN)
				.withOverride(MaskingRule__mdt.Mode__c, SEL_MaskingRule.MODE_CREDIT_CARD)
				.withOverride(MaskingRule__mdt.Replacement__c, CREDIT_CARD_REPLACEMENT)
				.withOverride(MaskingRule__mdt.CaseSensitive__c, false)
				.withOverride(MaskingRule__mdt.MinInputLength__c, isNewer ? NEWER_CARD_RULE_MINIMUM_INPUT_LENGTH : OLDER_CARD_RULE_MINIMUM_INPUT_LENGTH)
				.withOverride(MaskingRule__mdt.ApplicableFieldTypes__c, CARD_RULE_FIELD_TYPES)
				.withOverride(MaskingRule__mdt.Order__c, shippedNewer.Order__c)
				.withOverride(MaskingRule__mdt.Replaces__c, isNewer ? SEL_MaskingRule.RULE_MASK_CREDIT_CARD : null)
				.withOverride(MaskingRule__mdt.ReplacesFingerprint__c, isNewer ? shippedNewer.ReplacesFingerprint__c : null)
				.withOverride(MaskingRule__mdt.ShippedFingerprint__c, isNewer ? shippedNewer.ShippedFingerprint__c : null)
				.withOverride(MaskingRule__mdt.IsActive__c, isActive)
				.withOverride(MaskingRule__mdt.FailureAction__c, failureAction)
				.withOverride(MaskingRule__mdt.Description__c, description)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Makes the target selector read only the two given card rules and the four targets of the older rule,
	 * all on or all off, in place of the records deployed in the org.
	 *
	 * @param newer The copy of MaskPaymentCard
	 * @param older The copy of MaskCreditCard
	 * @param areTargetsActive The IsActive__c value of the four targets
	 */
	private static void registerCardRules(MaskingRule__mdt newer, MaskingRule__mdt older, Boolean areTargetsActive)
	{
		Map<String, MaskingTarget__mdt> targetsByName = new Map<String, MaskingTarget__mdt>();

		for(String targetName : OLDER_CARD_RULE_TARGET_NAMES)
		{
			targetsByName.put(targetName, (MaskingTarget__mdt)TST_Builder.of(MaskingTarget__mdt.SObjectType)
					.withOverride(MaskingTarget__mdt.DeveloperName, targetName)
					.withOverride(MaskingTarget__mdt.NamespacePrefix, older.NamespacePrefix)
					.withOverride(MaskingTarget__mdt.IsActive__c, areTargetsActive)
					.withOverride(MaskingTarget__mdt.Rule__c, older.Id)
					.withoutInsertion(true)
					.build());
		}

		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {newer.DeveloperName => newer, older.DeveloperName => older};
		SEL_MaskingTarget.allTargetsOverrideForTest = targetsByName;
		SEL_MaskingTarget.cachedRulesById = null;
	}

	/**
	 * @description Asserts the current card behaviour directly against the Luhn-checked digit-run
	 * pattern. This is what the engine guarantees, whatever values the org's installed records carry.
	 * Every card test uses it when the org's card rules were tuned.
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
	 * @description Loads the PACKAGE'S OWN shipped MaskingRule__mdt through the framework's selector,
	 * which reads getAll(). That is what the engine reads, and the only input shape
	 * SEL_MaskingRule.computeFingerprint accepts (getAll() cuts LongTextArea values, and SOQL does
	 * not). Matches by namespace: an org-local copy that shares a packaged DeveloperName is never
	 * picked, in any packaging context. Fails the test with a clear message when the rule is not
	 * deployed.
	 *
	 * @param developerName The rule's DeveloperName
	 *
	 * @return The deployed packaged rule (never null: a missing rule fails the test)
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

		Assert.isNotNull(found, 'Expected the shipped rule ' + developerName + ' to be deployed for this test to run');
		return found;
	}

	/**
	 * @description Loads the package's own shipped masking targets through the framework's selector, matched by
	 * namespace, so a target an admin wrote in the org is never counted.
	 *
	 * @return Every shipped target, on or off
	 */
	private static List<MaskingTarget__mdt> findShippedTargets()
	{
		String packageNamespace = UTIL_System.getManagedPackageNamespace() ?? UTIL_String.EMPTY;
		List<MaskingTarget__mdt> shipped = new List<MaskingTarget__mdt>();

		for(MaskingTarget__mdt target : new SEL_MaskingTarget().getAllTargets())
		{
			if((target.NamespacePrefix ?? UTIL_String.EMPTY) == packageNamespace)
			{
				shipped.add(target);
			}
		}

		return shipped;
	}

	/**
	 * @description The object|field|caller keys of every SHIPPED target linked to the given rule,
	 * matched by namespace so packaged and org-local rules that share a DeveloperName never mix.
	 * Targets a subscriber wrote for a packaged rule are left out on purpose: only shipped targets need
	 * a matching successor target, and a subscriber's target on a custom object rightly has none.
	 *
	 * @param rule The rule whose shipped target keys to collect
	 * @param rulesById Every rule, keyed by Id
	 *
	 * @return The combined keys of the rule's shipped targets
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

		Assert.areEqual(expected, output, 'Expected ' + developerName + ' to produce the expected masked output');
	}
}