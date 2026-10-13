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
 * @date April 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_MaskingRule_TEST
{
	/**
	 * @description DeveloperName of the predecessor rule in the supersession test data.
	 */
	private static final String PREDECESSOR_NAME = 'OldRule';

	/**
	 * @description DeveloperName of the successor rule in the supersession test data.
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
		Assert.isTrue(fields.contains(MaskingRule__mdt.NamespacePrefix), 'Default fields should include NamespacePrefix: supersession code keys rules by namespace');
		Assert.isTrue(fields.contains(MaskingRule__mdt.MasterLabel), 'Default fields should include MasterLabel: the advisor pages show each rule\'s label from cached records');
		Assert.isTrue(fields.contains(MaskingRule__mdt.Category__c), 'Default fields should include Category__c: the advisor rule picker groups on it');
	}

	/**
	 * @description Tests that `systemModeRequired` is true. The selector must always run in
	 * SYSTEM_MODE because subscribers usually do not give running users access to `kern__*__mdt`
	 * records; a USER_MODE fallback read after getAll() fails on a duplicate name would quietly
	 * return no rules and switch off masking for the whole org.
	 */
	@IsTest
	private static void shouldRequireSystemMode()
	{
		Assert.isTrue(new SEL_MaskingRule().systemModeRequired(), 'MaskingRule selector must always run in SYSTEM_MODE');
	}

	/**
	 * @description Tests that `normaliseToGetAllShape` cuts LongTextArea values the way the platform's
	 * getAll() does (255 characters; Pattern__c is the only LongTextArea field), so a record read by
	 * the fallback gets the same fingerprint as the getAll() record that the stored supersession
	 * fingerprints were generated from. Shorter values, and nulls, are kept as they are.
	 */
	@IsTest
	private static void shouldTruncateLongTextToGetAllShapeInFallback()
	{
		MaskingRule__mdt oversized = buildInMemoryRule('OversizedPattern', '4'.repeat(300), true);
		MaskingRule__mdt withinLimit = buildInMemoryRule('ShortPattern', 'short-pattern', true);
		MaskingRule__mdt absent = buildInMemoryRule('NullPattern', null, true);

		List<MaskingRule__mdt> shaped = SEL_MaskingRule.normaliseToGetAllShape(new List<MaskingRule__mdt> {oversized, withinLimit, absent});

		Assert.areEqual('4'.repeat(255), shaped[0].Pattern__c, 'getAll() cuts LongTextArea values to 255 characters, and the fallback must do the same');
		Assert.areEqual('short-pattern', shaped[1].Pattern__c, 'values within the getAll() length are kept as they are');
		Assert.isNull(shaped[2].Pattern__c, 'null patterns stay null through normalisation');
		Assert.areEqual('OversizedPattern', shaped[0].DeveloperName, 'non-truncated fields carry over unchanged');
	}

	/**
	 * @description Tests that the mode and failure-action constants match the MaskingRule__mdt picklist values.
	 * Catches a picklist value that is renamed by mistake without the matching constant being updated.
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
	 * @description Tests that the MODE_CREDIT_CARD constant matches the picklist value exactly.
	 * The framework masker uses this constant to choose `UTIL_String.maskWithLuhnValidatedRegex`.
	 * If the Apex constant and the `MaskingRule__mdt.Mode__c` restricted picklist entry ever differed,
	 * the rule would quietly do nothing.
	 */
	@IsTest
	private static void shouldExposeCreditCardModeConstant()
	{
		Assert.areEqual('CreditCard', SEL_MaskingRule.MODE_CREDIT_CARD, 'Constant value must match the Mode__c picklist value exactly');
	}

	/**
	 * @description Checks how the fingerprint is built, against the MaskCreditCard values shipped in
	 * 1.0.0-121. If this fails after a platform change or a change to how fingerprints are built, every
	 * stored fingerprint must be generated again in the same version.
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
				'The fingerprint code must give the stored ReplacesFingerprint__c of Mask Payment Card Numbers. A platform change, or a change to the fingerprint code,'
				+ ' here means EVERY stored fingerprint must be generated again in the same version');
	}

	/**
	 * @description Checks how the fingerprint is built, against the shipped Mask Payment Card Numbers
	 * values, by working out the stored ShippedFingerprint__c again on its own. Otherwise a successor
	 * record with a wrong or carelessly edited fingerprint could ship with supersession quietly broken
	 * (a fingerprint that does not match reads as "tuned": masking stays on, but the upgrade fix never
	 * takes effect).
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
				'The fingerprint code must give the stored ShippedFingerprint__c of Mask Payment Card Numbers from its shipped values');
	}

	/**
	 * @description Tests that nulls become empty strings and Decimals become whole-number strings, so
	 * differences in how values are serialised can never change whether a rule counts as tuned.
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
	 * @description Tests that a pattern containing newlines or JSON delimiters cannot run into the
	 * fields next to it: JSON escaping keeps the standard string clear.
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
	 * marked superseded. This is the case that must succeed, against which the other supersession
	 * tests compare.
	 */
	@IsTest
	private static void shouldMarkUntunedPredecessorSuperseded()
	{
		MaskingRule__mdt predecessor = buildInMemoryRule(PREDECESSOR_NAME, 'old-pattern', true);
		MaskingRule__mdt successor = buildSuccessor(predecessor, true);

		Set<String> superseded = SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {predecessor, successor});

		Assert.isTrue(superseded.contains(PREDECESSOR_NAME), 'Untuned predecessor with untuned active successor must be superseded');
	}

	/**
	 * @description Tests that a predecessor whose current values differ from the successor's
	 * ReplacesFingerprint__c (the subscriber tuned it) is never superseded.
	 */
	@IsTest
	private static void shouldNotSupersedeWhenPredecessorTuned()
	{
		MaskingRule__mdt predecessor = buildInMemoryRule(PREDECESSOR_NAME, 'old-pattern', true);
		MaskingRule__mdt successor = buildSuccessor(predecessor, true);
		predecessor.Pattern__c = 'subscriber-tuned-pattern';

		Assert.isFalse(SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {predecessor, successor}).contains(PREDECESSOR_NAME),
				'A tuned predecessor must keep running');
	}

	/**
	 * @description Tests that a successor whose current values differ from its own
	 * ShippedFingerprint__c (the subscriber tuned it) replaces nothing. A tuned successor could
	 * cover fewer fields, so the predecessor must keep running and both rules run.
	 */
	@IsTest
	private static void shouldNotSupersedeWhenSuccessorTuned()
	{
		MaskingRule__mdt predecessor = buildInMemoryRule(PREDECESSOR_NAME, 'old-pattern', true);
		MaskingRule__mdt successor = buildSuccessor(predecessor, true);
		successor.ApplicableFieldTypes__c = 'TEXTAREA';

		Assert.isFalse(SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {predecessor, successor}).contains(PREDECESSOR_NAME),
				'A tuned successor must not suppress its predecessor (coverage-hole guard)');
	}

	/**
	 * @description Tests that an inactive successor replaces nothing. Switching off the successor
	 * is how a subscriber brings the predecessor back.
	 */
	@IsTest
	private static void shouldNotSupersedeWhenSuccessorInactive()
	{
		MaskingRule__mdt predecessor = buildInMemoryRule(PREDECESSOR_NAME, 'old-pattern', true);
		MaskingRule__mdt successor = buildSuccessor(predecessor, false);

		Assert.isFalse(SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {predecessor, successor}).contains(PREDECESSOR_NAME),
				'An inactive successor must not suppress anything');
	}

	/**
	 * @description Tests that a Replaces__c value that names no existing rule changes nothing.
	 */
	@IsTest
	private static void shouldIgnoreDanglingReplaces()
	{
		MaskingRule__mdt successor = buildInMemoryRule(SUCCESSOR_NAME, 'new-pattern', true);
		successor.Replaces__c = 'NoSuchRule';
		successor.ShippedFingerprint__c = SEL_MaskingRule.computeFingerprint(successor);

		Assert.isTrue(SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {successor}).isEmpty(),
				'Dangling Replaces__c must be a no-op');
	}

	/**
	 * @description Tests that, among records with the same name and prefix, the supersession check
	 * uses the fingerprint of the MATCHING record only. A record with changed values (here a different
	 * pattern) must not spoil the result for the record whose values match the successor's
	 * ReplacesFingerprint__c.
	 */
	@IsTest
	private static void shouldKeySupersessionOnFingerprintAmongSameNamedRecords()
	{
		MaskingRule__mdt predecessor = buildInMemoryRule(PREDECESSOR_NAME, 'old-pattern', true);
		MaskingRule__mdt drifted = buildInMemoryRule(PREDECESSOR_NAME, 'drifted-pattern', true);
		MaskingRule__mdt successor = buildSuccessor(predecessor, true);

		Set<String> superseded = SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {predecessor, drifted, successor});

		Assert.isTrue(superseded.contains(PREDECESSOR_NAME), 'The fingerprint-matching record is superseded');
	}

	/**
	 * @description Tests that predecessors are matched by namespace, with real prefixes: a packaged
	 * predecessor (in the running package's namespace) and an org-local copy in ANOTHER namespace with
	 * the SAME values. Only the record with the matching prefix may be superseded. The prefix, not the
	 * fingerprint, tells them apart, because the copy's fingerprint also matches the successor's
	 * ReplacesFingerprint__c. The test data uses the running namespace, so the test holds in an
	 * unmanaged org, in a managed package, and when rebuilt under any namespace.
	 */
	@IsTest
	private static void shouldNotSupersedeIdenticalCloneFromAnotherNamespace()
	{
		String runningNamespace = UTIL_System.getManagedPackageNamespace();
		String foreignNamespace = (runningNamespace ?? UTIL_String.EMPTY) + 'subscriber';
		MaskingRule__mdt predecessor = buildNamespacedInMemoryRule(PREDECESSOR_NAME, 'old-pattern', runningNamespace);
		MaskingRule__mdt clone = buildNamespacedInMemoryRule(PREDECESSOR_NAME, 'old-pattern', foreignNamespace);
		MaskingRule__mdt successor = buildNamespacedSuccessor(predecessor, runningNamespace);

		Set<String> superseded = SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {predecessor, clone, successor});

		Assert.isTrue(superseded.contains(SEL_MaskingRule.resolveQualifiedDeveloperName(predecessor)),
				'The matching-prefix predecessor must be superseded');
		Assert.isFalse(superseded.contains(SEL_MaskingRule.resolveQualifiedDeveloperName(clone)),
				'A functionally identical clone under another namespace must never be superseded');
	}

	/**
	 * @description Tests that a rule naming itself in Replaces__c never supersedes anything.
	 * Replacing itself would drop the rule's own targets and stop masking its fields while the rule
	 * still shows as active.
	 */
	@IsTest
	private static void shouldIgnoreSelfReplacingRule()
	{
		MaskingRule__mdt selfReplacing = buildInMemoryRule(PREDECESSOR_NAME, 'old-pattern', true);
		selfReplacing.Replaces__c = selfReplacing.DeveloperName;
		selfReplacing.ReplacesFingerprint__c = SEL_MaskingRule.computeFingerprint(selfReplacing);
		selfReplacing.ShippedFingerprint__c = selfReplacing.ReplacesFingerprint__c;

		Assert.isTrue(SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {selfReplacing}).isEmpty(),
				'A rule can never supersede itself');
	}

	/**
	 * @description Tests that each supersession link stays within its own pair: with two separate
	 * predecessor and successor pairs, each successor links only its own predecessor, never the
	 * other pair's.
	 */
	@IsTest
	private static void shouldKeepSupersessionLinksPairwiseIndependent()
	{
		MaskingRule__mdt firstPredecessor = buildInMemoryRule('OldRuleOne', 'old-one', true);
		MaskingRule__mdt firstSuccessor = buildSuccessorNamed('NewRuleOne', firstPredecessor, true);
		MaskingRule__mdt secondPredecessor = buildInMemoryRule('OldRuleTwo', 'old-two', true);
		MaskingRule__mdt secondSuccessor = buildSuccessorNamed('NewRuleTwo', secondPredecessor, true);

		Map<String, Set<String>> links = SEL_MaskingRule.findSupersessionLinks(
				new List<MaskingRule__mdt> {firstPredecessor, firstSuccessor, secondPredecessor, secondSuccessor});

		Assert.areEqual(new Set<String> {'OldRuleOne'}, links.get('NewRuleOne'), 'Each successor links only its own predecessor');
		Assert.areEqual(new Set<String> {'OldRuleTwo'}, links.get('NewRuleTwo'), 'Each successor links only its own predecessor');
		Assert.areEqual(2, links.size(), 'Exactly the two qualifying successors carry links');
	}

	/**
	 * @description Tests that a change to any one of the seven fingerprint fields (the values that
	 * change how a rule masks) is seen as tuning. An untuned pair is superseded first, as the case that
	 * must succeed; then changing exactly one field on the predecessor must stop the supersession. If
	 * computeFingerprint quietly stopped reading a field, the check for that field fails.
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
	 * @description Asserts that a change to one fingerprint field is seen as tuning: the untuned pair
	 * is superseded first (the case that must succeed), then changing exactly the given predecessor
	 * field stops the supersession.
	 *
	 * @param field The fingerprint field to change
	 * @param tunedValue A value different from the fixture's shipped value for that field
	 */
	private static void assertPredecessorTuningDetected(SObjectField field, Object tunedValue)
	{
		MaskingRule__mdt predecessor = buildInMemoryRule(PREDECESSOR_NAME, 'old-pattern', true);
		MaskingRule__mdt successor = buildSuccessor(predecessor, true);

		Assert.isTrue(SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {predecessor, successor}).contains(PREDECESSOR_NAME),
				'Positive control: the untuned pair must supersede before tuning ' + field);

		predecessor.put(field, tunedValue);

		Assert.isFalse(SEL_MaskingRule.findSupersededRuleNames(new List<MaskingRule__mdt> {predecessor, successor}).contains(PREDECESSOR_NAME),
				'Tuning ' + field + ' must stop the supersession');
	}

	/**
	 * @description Builds an in-memory rule for the supersession tests. No DML and no mocks: the
	 * supersession check is plain logic over a list that is passed in.
	 *
	 * @param developerName The rule DeveloperName
	 * @param pattern The Pattern__c value (each test changes it to simulate tuning)
	 * @param isActive The IsActive__c value
	 *
	 * @return The in-memory rule
	 */
	private static MaskingRule__mdt buildInMemoryRule(String developerName, String pattern, Boolean isActive)
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
		MaskingRule__mdt successor = buildInMemoryRule(developerName, 'new-pattern', isActive);
		successor.Replaces__c = predecessor.DeveloperName;
		successor.ReplacesFingerprint__c = SEL_MaskingRule.computeFingerprint(predecessor);
		successor.ShippedFingerprint__c = SEL_MaskingRule.computeFingerprint(successor);
		return successor;
	}

	/**
	 * @description Builds an in-memory rule with an explicit NamespacePrefix, set through TST_Builder
	 * (the read-only field cannot be set through the constructor). Its other values match
	 * buildInMemoryRule exactly, so test data in different namespaces shares one fingerprint.
	 *
	 * @param developerName The rule DeveloperName
	 * @param pattern The Pattern__c value
	 * @param namespacePrefix The NamespacePrefix to stamp (blank stands for an unmanaged org)
	 *
	 * @return The in-memory rule with that namespace
	 */
	private static MaskingRule__mdt buildNamespacedInMemoryRule(String developerName, String pattern, String namespacePrefix)
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
	 * @description Builds an in-memory successor with a given namespace for a predecessor: names it
	 * via Replaces__c and carries both fingerprints exactly as the shipped metadata would.
	 *
	 * @param predecessor The rule the successor supersedes
	 * @param namespacePrefix The NamespacePrefix to stamp
	 *
	 * @return The in-memory successor rule
	 */
	private static MaskingRule__mdt buildNamespacedSuccessor(MaskingRule__mdt predecessor, String namespacePrefix)
	{
		MaskingRule__mdt successor = buildNamespacedInMemoryRule(SUCCESSOR_NAME, 'new-pattern', namespacePrefix);
		successor.Replaces__c = predecessor.DeveloperName;
		successor.ReplacesFingerprint__c = SEL_MaskingRule.computeFingerprint(predecessor);
		successor.ShippedFingerprint__c = SEL_MaskingRule.computeFingerprint(successor);
		return successor;
	}
}