// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_MaskingRule selector.
 *
 * @see SEL_MaskingRule
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date April 2026, June 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_MaskingRule_TEST
{
	/**
	 * @description DeveloperName of the predecessor rule in the verdict-matrix fixtures.
	 */
	private static final String PREDECESSOR_NAME = 'OldRule';

	/**
	 * @description DeveloperName of the successor rule in the verdict-matrix fixtures.
	 */
	private static final String SUCCESSOR_NAME = 'SuccessorRule';

	/**
	 * @description Tests that getFields returns a populated list.
	 */
	@IsTest
	private static void shouldReturnDefaultFields()
	{
		List<SObjectField> fields = new SEL_MaskingRule().getFields();

		Assert.isFalse(fields.isEmpty(), 'getFields should return the default field list');
		Assert.isTrue(fields.contains(MaskingRule__mdt.Mode__c), 'Default fields should include Mode__c');
		Assert.isTrue(fields.contains(MaskingRule__mdt.Pattern__c), 'Default fields should include Pattern__c');
		Assert.isTrue(fields.contains(MaskingRule__mdt.FailureAction__c), 'Default fields should include FailureAction__c');
		Assert.isTrue(fields.contains(MaskingRule__mdt.NamespacePrefix), 'Default fields should include NamespacePrefix — verdict consumers key rules namespace-aware');
		Assert.isTrue(fields.contains(MaskingRule__mdt.MasterLabel), 'Default fields should include MasterLabel — advisor surfaces label rules from cached records');
		Assert.isTrue(fields.contains(MaskingRule__mdt.Category__c), 'Default fields should include Category__c — the advisor rule picker groups on it');
	}

	/**
	 * @description Tests that `systemModeRequired` is true — the selector must always run in
	 * SYSTEM_MODE because subscribers typically don't grant CRUD on `kern__*__mdt` to running
	 * users; a USER_MODE fallback read after a getAll() collision would silently return no rules
	 * and disable masking org-wide.
	 */
	@IsTest
	private static void shouldRequireSystemMode()
	{
		Assert.isTrue(new SEL_MaskingRule().systemModeRequired(), 'MaskingRule selector must always run in SYSTEM_MODE');
	}

	/**
	 * @description Tests that `normaliseToGetAllShape` mirrors the platform's getAll() LongTextArea
	 * truncation (255 characters, Pattern__c is the only LongTextArea field) so a fallback-shaped
	 * record fingerprints identically to the getAll()-shaped record the baked supersession
	 * constants were generated from. Values inside the budget — and nulls — pass through untouched.
	 */
	@IsTest
	private static void shouldTruncateLongTextToGetAllShapeInFallback()
	{
		MaskingRule__mdt oversized = buildVerdictRule('OversizedPattern', '4'.repeat(300), true);
		MaskingRule__mdt withinLimit = buildVerdictRule('ShortPattern', 'short-pattern', true);
		MaskingRule__mdt absent = buildVerdictRule('NullPattern', null, true);

		List<MaskingRule__mdt> shaped = SEL_MaskingRule.normaliseToGetAllShape(new List<MaskingRule__mdt> {oversized, withinLimit, absent});

		Assert.areEqual('4'.repeat(255), shaped[0].Pattern__c, 'getAll() truncates LongTextArea values to 255 characters — the fallback must mirror it');
		Assert.areEqual('short-pattern', shaped[1].Pattern__c, 'values inside the getAll() budget pass through untouched');
		Assert.isNull(shaped[2].Pattern__c, 'null patterns stay null through normalisation');
		Assert.areEqual('OversizedPattern', shaped[0].DeveloperName, 'non-truncated fields carry over unchanged');
	}

	/**
	 * @description Tests that the mode and failure-action constants match the MaskingRule__mdt picklist values.
	 * Protects against accidental renames of the picklist values without matching constant updates.
	 */
	@IsTest
	private static void modeConstantsShouldMatchPicklistValues()
	{
		Set<String> modeValues = new Set<String>();

		for(PicklistEntry entry : MaskingRule__mdt.Mode__c.getDescribe().getPicklistValues())
		{
			modeValues.add(entry.getValue());
		}

		Assert.isTrue(modeValues.contains(SEL_MaskingRule.MODE_REGEX), 'MODE_REGEX constant should match a picklist value');
		Assert.isTrue(modeValues.contains(SEL_MaskingRule.MODE_JSON_KEY), 'MODE_JSON_KEY constant should match a picklist value');
		Assert.isTrue(modeValues.contains(SEL_MaskingRule.MODE_EXACT_MATCH), 'MODE_EXACT_MATCH constant should match a picklist value');
	}

	/**
	 * @description Tests that the failure-action constants match the FailureAction__c picklist values.
	 */
	@IsTest
	private static void failureActionConstantsShouldMatchPicklistValues()
	{
		Set<String> failureValues = new Set<String>();

		for(PicklistEntry entry : MaskingRule__mdt.FailureAction__c.getDescribe().getPicklistValues())
		{
			failureValues.add(entry.getValue());
		}

		Assert.isTrue(failureValues.contains(SEL_MaskingRule.FAILURE_LOG_AND_CONTINUE), 'FAILURE_LOG_AND_CONTINUE constant should match a picklist value');
		Assert.isTrue(failureValues.contains(SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER), 'FAILURE_WRITE_FAILURE_MARKER constant should match a picklist value');
		Assert.isTrue(failureValues.contains(SEL_MaskingRule.FAILURE_BLOCK_DML), 'FAILURE_BLOCK_DML constant should match a picklist value');
	}

	/**
	 * @description Tests that the MODE_CREDIT_CARD constant matches the picklist value string
	 * exactly. The framework masker dispatches on this constant when routing to
	 * `UTIL_String.maskWithLuhnValidatedRegex`; any drift between the Apex constant and the
	 * `MaskingRule__mdt.Mode__c` restricted picklist entry would cause silent no-ops.
	 */
	@IsTest
	private static void shouldExposeCreditCardModeConstant()
	{
		Assert.areEqual('CreditCard', SEL_MaskingRule.MODE_CREDIT_CARD, 'Constant value must match the Mode__c picklist value exactly');
	}

	/**
	 * @description Pins the fingerprint recipe against the 1.0.0-121 shipped MaskCreditCard
	 * values. If this fails after a platform or recipe change, every baked fingerprint constant
	 * must be regenerated in the same version (spec §3 recipe evolution policy).
	 */
	@IsTest
	private static void shouldComputeStableFingerprintForOriginalCreditCardValues()
	{
		MaskingRule__mdt original = new MaskingRule__mdt
				(
						Pattern__c = '\\b(?:4(?:[ -]?\\d){12,15}|(?:5[1-5]|2(?:2[2-9]|[3-6]\\d|7[01]|720))(?:[ -]?\\d){14}|3[47](?:[ -]?\\d)' +
								'{13}|(?:6011|65\\d{2}|64[4-9]\\d)(?:[ -]?\\d){12}|3(?:0[0-5]|[68]\\d)(?:[ -]?\\d){11}|(?:2131|1800|35\\d{3})' +
								'(?:[ -]?\\d){11}|(?:62|88)(?:[ -]?\\d){13,17})\\b',
						Mode__c = SEL_MaskingRule.MODE_CREDIT_CARD,
						Replacement__c = '[CARD_REDACTED]',
						CaseSensitive__c = false,
						MinInputLength__c = 15,
						ApplicableFieldTypes__c = 'STRING;TEXTAREA;ENCRYPTEDSTRING',
						FailureAction__c = SEL_MaskingRule.FAILURE_BLOCK_DML
				);

		String fingerprint = SEL_MaskingRule.computeFingerprint(original);

		Assert.areEqual(64, fingerprint.length(), 'Fingerprint must be a SHA-256 hex digest');
		Assert.areEqual(fingerprint.toLowerCase(), fingerprint, 'Fingerprint must be lowercase hex');
		Assert.areEqual('4a7d0e90c279226127cf2431ed41c6f0cafc98efa6b60704370d258a1e67ad99', fingerprint,
				'The recipe must reproduce the baked ReplacesFingerprint__c of Mask Payment Card Numbers — a platform or recipe'
				+ ' change here means EVERY baked fingerprint constant must be regenerated in the same version');
	}

	/**
	 * @description Pins the fingerprint recipe against the shipped Mask Payment Card Numbers
	 * values, independently reproducing the baked ShippedFingerprint__c. A mis-baked or
	 * carelessly edited successor record would otherwise ship with supersession silently dead
	 * (fingerprint mismatch reads as "tuned" — fail-open, but the upgrade fix never engages).
	 */
	@IsTest
	private static void shouldComputeStableFingerprintForShippedPaymentCardValues()
	{
		MaskingRule__mdt shipped = new MaskingRule__mdt
				(
						Pattern__c = '\\b\\d(?:[ -]?\\d){12,18}\\b',
						Mode__c = SEL_MaskingRule.MODE_CREDIT_CARD,
						Replacement__c = '[CARD_REDACTED]',
						CaseSensitive__c = false,
						MinInputLength__c = 13,
						ApplicableFieldTypes__c = 'STRING;TEXTAREA;ENCRYPTEDSTRING',
						FailureAction__c = SEL_MaskingRule.FAILURE_BLOCK_DML
				);

		Assert.areEqual('0593ef03f0725e64e777c5bda0622dea9385658e9da7b492a60cee7d564c3a56', SEL_MaskingRule.computeFingerprint(shipped),
				'The recipe must reproduce the baked ShippedFingerprint__c of Mask Payment Card Numbers from its shipped values');
	}

	/**
	 * @description Nulls normalise to empty strings and Decimals to integer strings, so
	 * serialisation variance can never flip a tuning verdict.
	 */
	@IsTest
	private static void shouldNormaliseNullsAndDecimalsInFingerprint()
	{
		MaskingRule__mdt sparse = new MaskingRule__mdt(MinInputLength__c = 15.0);
		MaskingRule__mdt sparseIntScale = new MaskingRule__mdt(MinInputLength__c = 15);

		Assert.areEqual(SEL_MaskingRule.computeFingerprint(sparse), SEL_MaskingRule.computeFingerprint(sparseIntScale),
				'Decimal scale must not change the fingerprint');
		Assert.areNotEqual(SEL_MaskingRule.computeFingerprint(sparse), SEL_MaskingRule.computeFingerprint(new MaskingRule__mdt()),
				'A populated field must change the fingerprint versus all-null');
	}

	/**
	 * @description A pattern containing newlines or JSON delimiters cannot collide with adjacent
	 * tuple fields — JSON escaping keeps the canonical string unambiguous.
	 */
	@IsTest
	private static void shouldKeepFingerprintUnambiguousForDelimiterBearingPatterns()
	{
		MaskingRule__mdt newlineInPattern = new MaskingRule__mdt(Pattern__c = 'a\nb', Mode__c = 'c');
		MaskingRule__mdt newlineSplitDifferently = new MaskingRule__mdt(Pattern__c = 'a', Mode__c = 'b\nc');

		Assert.areNotEqual(SEL_MaskingRule.computeFingerprint(newlineInPattern),
				SEL_MaskingRule.computeFingerprint(newlineSplitDifferently),
				'Field boundaries must survive delimiter characters inside values');
	}

	/**
	 * @description Tests that an untuned predecessor named by an active, untuned successor is
	 * marked superseded — the positive control for the verdict matrix.
	 */
	@IsTest
	private static void shouldMarkUntunedPredecessorSuperseded()
	{
		MaskingRule__mdt predecessor = buildVerdictRule(PREDECESSOR_NAME, 'old-pattern', true);
		MaskingRule__mdt successor = buildSuccessor(predecessor, true);

		Set<String> superseded = SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {predecessor, successor});

		Assert.isTrue(superseded.contains(PREDECESSOR_NAME), 'Untuned predecessor with untuned active successor must be superseded');
	}

	/**
	 * @description Tests that a predecessor whose live values differ from the successor's
	 * ReplacesFingerprint__c (subscriber tuning) is never superseded.
	 */
	@IsTest
	private static void shouldNotSupersedeWhenPredecessorTuned()
	{
		MaskingRule__mdt predecessor = buildVerdictRule(PREDECESSOR_NAME, 'old-pattern', true);
		MaskingRule__mdt successor = buildSuccessor(predecessor, true);
		predecessor.Pattern__c = 'subscriber-tuned-pattern';

		Assert.isFalse(SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {predecessor, successor}).contains(PREDECESSOR_NAME),
				'A tuned predecessor must keep running');
	}

	/**
	 * @description Tests that a successor whose live values differ from its own
	 * ShippedFingerprint__c (subscriber tuning) suppresses nothing — a tuned successor could
	 * carry narrowed coverage, so suppression must end and both rules run.
	 */
	@IsTest
	private static void shouldNotSupersedeWhenSuccessorTuned()
	{
		MaskingRule__mdt predecessor = buildVerdictRule(PREDECESSOR_NAME, 'old-pattern', true);
		MaskingRule__mdt successor = buildSuccessor(predecessor, true);
		successor.ApplicableFieldTypes__c = 'TEXTAREA';

		Assert.isFalse(SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {predecessor, successor}).contains(PREDECESSOR_NAME),
				'A tuned successor must not suppress its predecessor (coverage-hole guard)');
	}

	/**
	 * @description Tests that an inactive successor suppresses nothing — deactivating the
	 * successor is the subscriber escape hatch that resumes the predecessor.
	 */
	@IsTest
	private static void shouldNotSupersedeWhenSuccessorInactive()
	{
		MaskingRule__mdt predecessor = buildVerdictRule(PREDECESSOR_NAME, 'old-pattern', true);
		MaskingRule__mdt successor = buildSuccessor(predecessor, false);

		Assert.isFalse(SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {predecessor, successor}).contains(PREDECESSOR_NAME),
				'An inactive successor must not suppress anything');
	}

	/**
	 * @description Tests that a Replaces__c value naming no rule in the universe is a no-op.
	 */
	@IsTest
	private static void shouldIgnoreDanglingReplaces()
	{
		MaskingRule__mdt successor = buildVerdictRule(SUCCESSOR_NAME, 'new-pattern', true);
		successor.Replaces__c = 'NoSuchRule';
		successor.ShippedFingerprint__c = SEL_MaskingRule.computeFingerprint(successor);

		Assert.isTrue(SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {successor}).isEmpty(),
				'Dangling Replaces__c must be a no-op');
	}

	/**
	 * @description Tests that among same-named, same-prefix records the verdict keys on the
	 * fingerprint of the MATCHING record only — a record with drifted values (here a different
	 * pattern) must not poison the verdict for the record whose values match the successor's
	 * ReplacesFingerprint__c.
	 */
	@IsTest
	private static void shouldKeyVerdictOnFingerprintAmongSameNamedRecords()
	{
		MaskingRule__mdt predecessor = buildVerdictRule(PREDECESSOR_NAME, 'old-pattern', true);
		MaskingRule__mdt drifted = buildVerdictRule(PREDECESSOR_NAME, 'drifted-pattern', true);
		MaskingRule__mdt successor = buildSuccessor(predecessor, true);

		Set<String> superseded = SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {predecessor, drifted, successor});

		Assert.isTrue(superseded.contains(PREDECESSOR_NAME), 'The fingerprint-matching record is superseded');
	}

	/**
	 * @description Tests namespace-aware predecessor resolution with real prefixes: a packaged
	 * predecessor (running package namespace) and an org-local clone carrying ANOTHER namespace
	 * but IDENTICAL functional values. Only the matching-prefix record may be superseded —
	 * prefix, not fingerprint, is the discriminator, because the clone's fingerprint also
	 * matches the successor's ReplacesFingerprint__c. The fixture derives the running namespace
	 * so the test holds unmanaged, managed, and rebuilt under any namespace.
	 */
	@IsTest
	private static void shouldNotSupersedeIdenticalCloneFromAnotherNamespace()
	{
		String runningNamespace = UTIL_System.getManagedPackageNamespace();
		String foreignNamespace = (runningNamespace ?? UTIL_String.EMPTY) + 'subscriber';
		MaskingRule__mdt predecessor = buildNamespacedVerdictRule(PREDECESSOR_NAME, 'old-pattern', runningNamespace);
		MaskingRule__mdt clone = buildNamespacedVerdictRule(PREDECESSOR_NAME, 'old-pattern', foreignNamespace);
		MaskingRule__mdt successor = buildNamespacedSuccessor(predecessor, runningNamespace);

		Set<String> superseded = SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {predecessor, clone, successor});

		Assert.isTrue(superseded.contains(SEL_MaskingRule.resolveQualifiedDeveloperName(predecessor)),
				'The matching-prefix predecessor must be superseded');
		Assert.isFalse(superseded.contains(SEL_MaskingRule.resolveQualifiedDeveloperName(clone)),
				'A functionally identical clone under another namespace must never be superseded');
	}

	/**
	 * @description Tests that a rule naming itself via Replaces__c never supersedes anything —
	 * self-supersession would drop the rule's own targets and unmask its surfaces while the rule
	 * still shows active.
	 */
	@IsTest
	private static void shouldIgnoreSelfReplacingRule()
	{
		MaskingRule__mdt selfReplacing = buildVerdictRule(PREDECESSOR_NAME, 'old-pattern', true);
		selfReplacing.Replaces__c = selfReplacing.DeveloperName;
		selfReplacing.ReplacesFingerprint__c = SEL_MaskingRule.computeFingerprint(selfReplacing);
		selfReplacing.ShippedFingerprint__c = selfReplacing.ReplacesFingerprint__c;

		Assert.isTrue(SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {selfReplacing}).isEmpty(),
				'A rule can never supersede itself');
	}

	/**
	 * @description Tests that supersession links stay pairwise: with two independent
	 * predecessor/successor pairs in the universe, each successor links exactly its own
	 * predecessor — never the sibling pair's.
	 */
	@IsTest
	private static void shouldKeepSupersessionLinksPairwiseIndependent()
	{
		MaskingRule__mdt firstPredecessor = buildVerdictRule('OldRuleOne', 'old-one', true);
		MaskingRule__mdt firstSuccessor = buildSuccessorNamed('NewRuleOne', firstPredecessor, true);
		MaskingRule__mdt secondPredecessor = buildVerdictRule('OldRuleTwo', 'old-two', true);
		MaskingRule__mdt secondSuccessor = buildSuccessorNamed('NewRuleTwo', secondPredecessor, true);

		Map<String, Set<String>> links = SEL_MaskingRule.findSupersessionLinks(
				new List<MaskingRule__mdt> {firstPredecessor, firstSuccessor, secondPredecessor, secondSuccessor});

		Assert.areEqual(new Set<String> {'OldRuleOne'}, links.get('NewRuleOne'), 'Each successor links only its own predecessor');
		Assert.areEqual(new Set<String> {'OldRuleTwo'}, links.get('NewRuleTwo'), 'Each successor links only its own predecessor');
		Assert.areEqual(2, links.size(), 'Exactly the two qualifying successors carry links');
	}

	/**
	 * @description Tests that every one of the seven behaviour-bearing tuple fields acts as a
	 * tuning detector: with an untuned pair as positive control, tuning exactly one field on the
	 * predecessor must flip its verdict off. If computeFingerprint silently stopped reading any
	 * tuple field, that field's row fails.
	 */
	@IsTest
	private static void shouldDetectTuningOnEveryFingerprintTupleField()
	{
		assertPredecessorTuningDetected(MaskingRule__mdt.Pattern__c, 'tuned-pattern');
		assertPredecessorTuningDetected(MaskingRule__mdt.Mode__c, SEL_MaskingRule.MODE_REGEX);
		assertPredecessorTuningDetected(MaskingRule__mdt.Replacement__c, '[TUNED]');
		assertPredecessorTuningDetected(MaskingRule__mdt.CaseSensitive__c, true);
		assertPredecessorTuningDetected(MaskingRule__mdt.MinInputLength__c, 14);
		assertPredecessorTuningDetected(MaskingRule__mdt.ApplicableFieldTypes__c, 'TEXTAREA');
		assertPredecessorTuningDetected(MaskingRule__mdt.FailureAction__c, SEL_MaskingRule.FAILURE_LOG_AND_CONTINUE);
	}

	/**
	 * @description Asserts one tuple field participates in tuning detection: the untuned pair
	 * supersedes (positive control), then tuning exactly the given predecessor field flips the
	 * verdict off.
	 *
	 * @param field The tuple field to tune
	 * @param tunedValue A value different from the fixture's shipped value for that field
	 */
	private static void assertPredecessorTuningDetected(SObjectField field, Object tunedValue)
	{
		MaskingRule__mdt predecessor = buildVerdictRule(PREDECESSOR_NAME, 'old-pattern', true);
		MaskingRule__mdt successor = buildSuccessor(predecessor, true);

		Assert.isTrue(SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {predecessor, successor}).contains(PREDECESSOR_NAME),
				'Positive control: the untuned pair must supersede before tuning ' + field);

		predecessor.put(field, tunedValue);

		Assert.isFalse(SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {predecessor, successor}).contains(PREDECESSOR_NAME),
				'Tuning ' + field + ' must flip the verdict off');
	}

	/**
	 * @description Builds an in-memory rule for verdict-matrix tests. No DML, no mocks — the
	 * verdict is pure logic over a passed-in list.
	 *
	 * @param developerName The rule DeveloperName
	 * @param pattern The Pattern__c value (the per-test tuning lever)
	 * @param isActive The IsActive__c value
	 *
	 * @return The in-memory rule
	 */
	private static MaskingRule__mdt buildVerdictRule(String developerName, String pattern, Boolean isActive)
	{
		return new MaskingRule__mdt
				(
						DeveloperName = developerName,
						Pattern__c = pattern,
						Mode__c = SEL_MaskingRule.MODE_CREDIT_CARD,
						Replacement__c = '[CARD_REDACTED]',
						CaseSensitive__c = false,
						MinInputLength__c = 13,
						ApplicableFieldTypes__c = 'STRING',
						FailureAction__c = SEL_MaskingRule.FAILURE_BLOCK_DML,
						IsActive__c = isActive
				);
	}

	/**
	 * @description Builds an in-memory successor for a predecessor: names it via Replaces__c and
	 * carries both fingerprints exactly as the shipped metadata would.
	 *
	 * @param predecessor The rule the successor supersedes
	 * @param isActive The successor's IsActive__c value
	 *
	 * @return The in-memory successor rule
	 */
	private static MaskingRule__mdt buildSuccessor(MaskingRule__mdt predecessor, Boolean isActive)
	{
		return buildSuccessorNamed(SUCCESSOR_NAME, predecessor, isActive);
	}

	/**
	 * @description Builds an in-memory successor with an explicit DeveloperName, for fixtures
	 * holding more than one supersession pair.
	 *
	 * @param developerName The successor's DeveloperName
	 * @param predecessor The rule the successor supersedes
	 * @param isActive The successor's IsActive__c value
	 *
	 * @return The in-memory successor rule
	 */
	private static MaskingRule__mdt buildSuccessorNamed(String developerName, MaskingRule__mdt predecessor, Boolean isActive)
	{
		MaskingRule__mdt successor = buildVerdictRule(developerName, 'new-pattern', isActive);
		successor.Replaces__c = predecessor.DeveloperName;
		successor.ReplacesFingerprint__c = SEL_MaskingRule.computeFingerprint(predecessor);
		successor.ShippedFingerprint__c = SEL_MaskingRule.computeFingerprint(successor);
		return successor;
	}

	/**
	 * @description Builds an in-memory verdict rule stamped with an explicit NamespacePrefix via
	 * TST_Builder (the read-only field cannot be set through the constructor). Functional values
	 * match buildVerdictRule exactly so cross-namespace fixtures share one fingerprint.
	 *
	 * @param developerName The rule DeveloperName
	 * @param pattern The Pattern__c value
	 * @param namespacePrefix The NamespacePrefix to stamp (blank models the unmanaged shape)
	 *
	 * @return The in-memory, namespace-stamped rule
	 */
	private static MaskingRule__mdt buildNamespacedVerdictRule(String developerName, String pattern, String namespacePrefix)
	{
		return (MaskingRule__mdt)TST_Builder.of(MaskingRule__mdt.SObjectType)
				.withOverride(MaskingRule__mdt.DeveloperName, developerName)
				.withOverride(MaskingRule__mdt.Pattern__c, pattern)
				.withOverride(MaskingRule__mdt.Mode__c, SEL_MaskingRule.MODE_CREDIT_CARD)
				.withOverride(MaskingRule__mdt.Replacement__c, '[CARD_REDACTED]')
				.withOverride(MaskingRule__mdt.CaseSensitive__c, false)
				.withOverride(MaskingRule__mdt.MinInputLength__c, 13)
				.withOverride(MaskingRule__mdt.ApplicableFieldTypes__c, 'STRING')
				.withOverride(MaskingRule__mdt.FailureAction__c, SEL_MaskingRule.FAILURE_BLOCK_DML)
				.withOverride(MaskingRule__mdt.IsActive__c, true)
				.withOverride(MaskingRule__mdt.NamespacePrefix, namespacePrefix)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Builds an in-memory, namespace-stamped successor for a predecessor: names it
	 * via Replaces__c and carries both fingerprints exactly as the shipped metadata would.
	 *
	 * @param predecessor The rule the successor supersedes
	 * @param namespacePrefix The NamespacePrefix to stamp
	 *
	 * @return The in-memory successor rule
	 */
	private static MaskingRule__mdt buildNamespacedSuccessor(MaskingRule__mdt predecessor, String namespacePrefix)
	{
		MaskingRule__mdt successor = buildNamespacedVerdictRule(SUCCESSOR_NAME, 'new-pattern', namespacePrefix);
		successor.Replaces__c = predecessor.DeveloperName;
		successor.ReplacesFingerprint__c = SEL_MaskingRule.computeFingerprint(predecessor);
		successor.ShippedFingerprint__c = SEL_MaskingRule.computeFingerprint(successor);
		return successor;
	}
}