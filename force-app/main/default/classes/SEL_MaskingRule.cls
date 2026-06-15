// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the MaskingRule__mdt custom metadata type.
 *
 * Rules normally load through `SEL_MaskingTarget`'s getAll()-backed sidecar cache, never through
 * `Rule__r` joins — and a rule without a target still has no effect, because the engine applies
 * rules only through targets. This selector is the single source of truth for (1) the rule field
 * list, which doubles as the collision-fallback query contract, (2) the Mode__c and
 * FailureAction__c picklist-value constants Apex callers dispatch on, and (3) the supersession
 * fingerprint recipe and verdict helpers. Its one standalone query path is `fetchAllFlat` — the
 * degraded read `SEL_MaskingTarget` falls back to when a DeveloperName collision breaks
 * `getAll()`.
 *
 * @see SEL_Base
 * @see SEL_MaskingRule_TEST
 * @see SEL_MaskingTarget
 * @see MaskingRule__mdt
 *
 * @author Jason van Beukering
 *
 * @group Data Masking
 *
 * @date April 2026, June 2026
 */
public inherited sharing class SEL_MaskingRule extends SEL_Base
{
	/**
	 * @description Mode__c picklist value indicating a regular expression rule matched against the field value.
	 */
	public static final String MODE_REGEX = 'Regex';

	/**
	 * @description Mode__c picklist value indicating a regex rule whose matches must additionally
	 * pass the Luhn (mod-10) checksum per ISO/IEC 7812. Only regex matches that also pass
	 * `UTIL_String.isValidCardNumber` are replaced. Intended for credit-card redaction rules
	 * where the regex alone would over-match 15-19 digit runs like transaction IDs.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	public static final String MODE_CREDIT_CARD = 'CreditCard';

	/**
	 * @description Mode__c picklist value indicating a rule whose Pattern matches JSON keys, redacting values under matching keys.
	 */
	public static final String MODE_JSON_KEY = 'JsonKey';

	/**
	 * @description Mode__c picklist value indicating a rule that matches the Pattern as an exact substring.
	 */
	public static final String MODE_EXACT_MATCH = 'ExactMatch';

	/**
	 * @description FailureAction__c picklist value indicating that a rule failure should log a warning and keep the original value.
	 */
	public static final String FAILURE_LOG_AND_CONTINUE = 'LogAndContinue';

	/**
	 * @description FailureAction__c picklist value indicating that a rule failure should replace the field with [MASKING_FAILURE].
	 */
	public static final String FAILURE_WRITE_FAILURE_MARKER = 'WriteFailureMarker';

	/**
	 * @description FailureAction__c picklist value indicating that a rule failure should refuse the DML.
	 */
	public static final String FAILURE_BLOCK_DML = 'BlockDml';

	/**
	 * @description DeveloperName of the shipped MaskAddress rule. Single source of truth so
	 * callers and tests reference the rule by constant rather than re-typing the literal.
	 */
	public static final String RULE_MASK_ADDRESS = 'MaskAddress';

	/**
	 * @description DeveloperName of the shipped MaskAuthHeader rule.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	public static final String RULE_MASK_AUTH_HEADER = 'MaskAuthHeader';

	/**
	 * @description DeveloperName of the shipped MaskAwsAccessKey rule.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	public static final String RULE_MASK_AWS_ACCESS_KEY = 'MaskAwsAccessKey';

	/**
	 * @description DeveloperName of the shipped MaskCreditCard rule.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	public static final String RULE_MASK_CREDIT_CARD = 'MaskCreditCard';

	/**
	 * @description DeveloperName of the shipped MaskEmail rule.
	 */
	public static final String RULE_MASK_EMAIL = 'MaskEmail';

	/**
	 * @description DeveloperName of the shipped MaskFreeText rule.
	 */
	public static final String RULE_MASK_FREE_TEXT = 'MaskFreeText';

	/**
	 * @description DeveloperName of the shipped MaskHealthKeywords rule.
	 */
	public static final String RULE_MASK_HEALTH_KEYWORDS = 'MaskHealthKeywords';

	/**
	 * @description DeveloperName of the shipped MaskIban rule.
	 */
	public static final String RULE_MASK_IBAN = 'MaskIban';

	/**
	 * @description DeveloperName of the shipped MaskIpv4Private rule.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	public static final String RULE_MASK_IPV4_PRIVATE = 'MaskIpv4Private';

	/**
	 * @description DeveloperName of the shipped MaskJwt rule.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	public static final String RULE_MASK_JWT = 'MaskJwt';

	/**
	 * @description DeveloperName of the shipped MaskMedicareBeneficiaryId rule.
	 */
	public static final String RULE_MASK_MEDICARE_BENEFICIARY_ID = 'MaskMedicareBeneficiaryId';

	/**
	 * @description DeveloperName of the shipped Mask Payment Card Numbers rule (successor to
	 * MaskCreditCard).
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	public static final String RULE_MASK_PAYMENT_CARD = 'MaskPaymentCard';

	/**
	 * @description DeveloperName of the shipped MaskPhoneInternational rule.
	 */
	public static final String RULE_MASK_PHONE_INTERNATIONAL = 'MaskPhoneInternational';

	/**
	 * @description DeveloperName of the shipped MaskPhoneUS rule.
	 */
	public static final String RULE_MASK_PHONE_US = 'MaskPhoneUS';

	/**
	 * @description DeveloperName of the shipped MaskSecretKeys rule.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	public static final String RULE_MASK_SECRET_KEYS = 'MaskSecretKeys';

	/**
	 * @description DeveloperName of the shipped MaskSsn rule.
	 */
	public static final String RULE_MASK_SSN = 'MaskSsn';

	/**
	 * @description DeveloperName of the shipped MaskSwiftBic rule.
	 */
	public static final String RULE_MASK_SWIFT_BIC = 'MaskSwiftBic';

	/**
	 * @description DeveloperName of the shipped MaskUrlBasicAuth rule.
	 */
	@SuppressWarnings('PMD.AvoidHardcodedCredentialsInFieldDecls')
	public static final String RULE_MASK_URL_BASIC_AUTH = 'MaskUrlBasicAuth';

	/**
	 * @description Fully-qualified API name of the MaskingRule__mdt object — namespaced
	 * (`kern__MaskingRule__mdt`) in a subscriber org, without a namespace prefix
	 * (`MaskingRule__mdt`) in the framework's dev preview. Used by callers that emit metadata XML
	 * referencing the type.
	 */
	public static final String OBJECT_NAME = UTIL_SObjectDescribe.getObjectNameFromType(MaskingRule__mdt.SObjectType);

	/**
	 * @description Namespace-aware API name of `IsActive__c`.
	 */
	public static final String FIELD_IS_ACTIVE = MaskingRule__mdt.IsActive__c.getDescribe().name;

	/**
	 * @description The character count `getAll()` truncates LongTextArea values to. The fallback
	 * read path mirrors this so a fallback-shaped record fingerprints identically to the
	 * getAll()-shaped records the baked supersession constants were generated from.
	 */
	private static final Integer GET_ALL_LONG_TEXT_LIMIT = 255;

	/**
	 * @description The behaviour-bearing fingerprint tuple, serialised via JSON so values
	 * containing delimiters can never blur field boundaries. Strings are pre-normalised
	 * (null → empty; Boolean → true/false; MinInputLength → integer string) so platform
	 * serialisation variance cannot flip verdicts. The serialised field order is
	 * platform-determined and stable; the baked-digest recipe pins in SEL_MaskingRule_TEST
	 * surface any platform serialisation change as a test failure.
	 */
	private class FingerprintInput
	{
		/**
		 * @description Normalised Pattern__c.
		 */
		public String pattern;

		/**
		 * @description Normalised Mode__c.
		 */
		public String mode;

		/**
		 * @description Normalised Replacement__c.
		 */
		public String replacement;

		/**
		 * @description Normalised CaseSensitive__c (true/false, empty when null).
		 */
		public String caseSensitive;

		/**
		 * @description Normalised MinInputLength__c (integer string, empty when null).
		 */
		public String minInputLength;

		/**
		 * @description Normalised ApplicableFieldTypes__c.
		 */
		public String applicableFieldTypes;

		/**
		 * @description Normalised FailureAction__c.
		 */
		public String failureAction;
	}

	/**
	 * @description Canonical fingerprint of a rule's behaviour-bearing values. The ONLY producer
	 * of supersession fingerprints — baked record constants are generated by executing this
	 * helper (never hand-derived), and the recipe is pinned by SEL_MaskingRule_TEST. Excludes
	 * Category/Description/Order/IsActive (cosmetic, sequencing, handled separately).
	 *
	 * Inputs must be getAll()-shaped records — the engine's source. getAll() truncates
	 * LongTextArea values (Pattern__c) to 255 characters while SOQL returns them in full, so a
	 * SOQL-sourced record can fingerprint differently once a pattern crosses that length; baked
	 * constants are therefore generated from getAll()-sourced records only. MinInputLength__c
	 * ships scale 0, so the intValue() normalisation assumes whole numbers.
	 *
	 * @param rule The rule whose live values to fingerprint
	 *
	 * @return Lowercase SHA-256 hex of the canonical JSON tuple
	 */
	public static String computeFingerprint(MaskingRule__mdt rule)
	{
		FingerprintInput input = new FingerprintInput();
		input.pattern = rule.Pattern__c ?? UTIL_String.EMPTY;
		input.mode = rule.Mode__c ?? UTIL_String.EMPTY;
		input.replacement = rule.Replacement__c ?? UTIL_String.EMPTY;
		input.caseSensitive = rule.CaseSensitive__c == null ? UTIL_String.EMPTY : String.valueOf(rule.CaseSensitive__c);
		input.minInputLength = rule.MinInputLength__c == null ? UTIL_String.EMPTY : String.valueOf(rule.MinInputLength__c.intValue());
		input.applicableFieldTypes = rule.ApplicableFieldTypes__c ?? UTIL_String.EMPTY;
		input.failureAction = rule.FailureAction__c ?? UTIL_String.EMPTY;

		return UTIL_Crypto.generateSHA256Hash(JSON.serialize(input));
	}

	/**
	 * @description Maps each qualifying successor to the predecessors it supersedes (spec:
	 * masking-rule supersession). A pair qualifies only when EVERY condition holds: the successor
	 * is active and names the predecessor via Replaces__c with a matching NamespacePrefix; the
	 * predecessor's live fingerprint equals the successor's ReplacesFingerprint__c (predecessor
	 * untuned); and the successor's live fingerprint equals its own ShippedFingerprint__c
	 * (successor untuned — a tuned successor must never evict its predecessor, or narrowed
	 * coverage would silently unmask fields). A rule naming itself is ignored — self-supersession
	 * would suppress the rule's own targets. Links are pairwise and independent — no chain
	 * traversal, and a verdict consumer must never let one link's surfaces suppress another
	 * link's predecessor. All keys and values are namespace-qualified via
	 * resolveQualifiedDeveloperName so an org-local clone sharing a packaged rule's
	 * DeveloperName can never be keyed by the packaged verdict.
	 *
	 * @param rules The rule universe to evaluate (typically SEL_MaskingTarget.getAllRulesById().values())
	 *
	 * @return Qualified successor name → qualified names of the predecessors that successor supersedes
	 */
	public static Map<String, Set<String>> findSupersessionLinks(List<MaskingRule__mdt> rules)
	{
		Map<String, Set<String>> predecessorNamesBySuccessor = new Map<String, Set<String>>();

		for(MaskingRule__mdt successor : rules)
		{
			if(String.isBlank(successor.Replaces__c) || successor.IsActive__c != true)
			{
				continue;
			}
			if(successor.Replaces__c == successor.DeveloperName)
			{
				continue;
			}
			if(computeFingerprint(successor) != successor.ShippedFingerprint__c)
			{
				continue;
			}

			Set<String> predecessorNames = findPredecessorsSupersededBy(successor, rules);

			if(!predecessorNames.isEmpty())
			{
				predecessorNamesBySuccessor.put(resolveQualifiedDeveloperName(successor), predecessorNames);
			}
		}

		return predecessorNamesBySuccessor;
	}

	/**
	 * @description Qualified names of every rule superseded by any qualifying successor — the
	 * rule-level verdict consumed where per-surface pairing does not matter (advisor candidate
	 * filtering, posture surfaces). Per-surface consumers must use findSupersessionLinks instead.
	 *
	 * @param rules The rule universe to evaluate (typically SEL_MaskingTarget.getAllRulesById().values())
	 *
	 * @return Qualified developer names of superseded predecessor rules
	 */
	public static Set<String> findSupersededRuleNames(List<MaskingRule__mdt> rules)
	{
		Set<String> superseded = new Set<String>();

		for(Set<String> predecessorNames : findSupersessionLinks(rules).values())
		{
			superseded.addAll(predecessorNames);
		}

		return superseded;
	}

	/**
	 * @description Qualified names of the rules in the universe that an untuned active successor
	 * actually supersedes: same DeveloperName as its Replaces__c, same NamespacePrefix, and a
	 * live fingerprint equal to the successor's ReplacesFingerprint__c.
	 *
	 * @param successor The active, untuned successor rule
	 * @param rules The rule universe to scan
	 *
	 * @return Qualified developer names of the matching predecessors
	 */
	private static Set<String> findPredecessorsSupersededBy(MaskingRule__mdt successor, List<MaskingRule__mdt> rules)
	{
		Set<String> names = new Set<String>();

		for(MaskingRule__mdt predecessor : rules)
		{
			if(predecessor.DeveloperName == successor.Replaces__c
					&& predecessor.NamespacePrefix == successor.NamespacePrefix
					&& computeFingerprint(predecessor) == successor.ReplacesFingerprint__c)
			{
				names.add(resolveQualifiedDeveloperName(predecessor));
			}
		}

		return names;
	}

	/**
	 * @description Namespace-qualified identity key for a rule record. Packaged and org-local
	 * records can legally share a DeveloperName; every supersession verdict consumer must key
	 * rules through this helper so the two never collide. Blank-prefix records key on the bare
	 * DeveloperName, matching the in-memory and unmanaged-org shapes.
	 *
	 * @param rule The rule to key
	 *
	 * @return The prefix-qualified developer name
	 */
	public static String resolveQualifiedDeveloperName(MaskingRule__mdt rule)
	{
		return resolveQualifiedName(rule.NamespacePrefix, rule.DeveloperName);
	}

	/**
	 * @description Namespace-qualified identity key from a prefix + developer-name pair, for a caller
	 * keying a rule another record merely NAMES (a successor's Replaces__c) rather than a record in
	 * hand. The named rule is keyed under the namer's own prefix — cross-namespace supersession is
	 * never legal, so a foreign-namespace record naming a packaged DeveloperName must key apart from
	 * the packaged rule.
	 *
	 * @param namespacePrefix The owning namespace prefix, blank for an org-local record
	 * @param developerName The rule developer name
	 *
	 * @return The prefix-qualified developer name
	 */
	public static String resolveQualifiedName(String namespacePrefix, String developerName)
	{
		return String.isBlank(namespacePrefix) ? developerName : namespacePrefix + UTIL_String.DOT + developerName;
	}

	/**
	 * @description Constructs a MaskingRule selector.
	 */
	public SEL_MaskingRule()
	{
		super(MaskingRule__mdt.SObjectType);
	}

	/**
	 * @description Returns the core fields for MaskingRule__mdt queries. This list doubles as the
	 * collision-fallback contract: when `MaskingRule__mdt.getAll()` fails on a duplicate
	 * DeveloperName, `SEL_MaskingTarget` rebuilds the rule cache from a flat selector query over
	 * exactly these fields — every field any cache consumer reads must be listed here, or the
	 * fallback silently nulls it (MasterLabel and Category__c are cache-consumer reads from the
	 * Data Masking Advisor, not query-builder needs).
	 *
	 * @return List of MaskingRule__mdt SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				MaskingRule__mdt.ApplicableFieldTypes__c,
				MaskingRule__mdt.CaseSensitive__c,
				MaskingRule__mdt.Category__c,
				MaskingRule__mdt.Description__c,
				MaskingRule__mdt.DeveloperName,
				MaskingRule__mdt.FailureAction__c,
				MaskingRule__mdt.IsActive__c,
				MaskingRule__mdt.MasterLabel,
				MaskingRule__mdt.MinInputLength__c,
				MaskingRule__mdt.Mode__c,
				MaskingRule__mdt.NamespacePrefix,
				MaskingRule__mdt.Order__c,
				MaskingRule__mdt.Pattern__c,
				MaskingRule__mdt.Replacement__c,
				MaskingRule__mdt.Replaces__c,
				MaskingRule__mdt.ReplacesFingerprint__c,
				MaskingRule__mdt.ShippedFingerprint__c
		};
	}

	/**
	 * @description Framework-internal CMDT selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Subscribers typically grant
	 * running users no CRUD on `kern__*__mdt` records by design, so a USER_MODE fallback read
	 * after a getAll() collision would silently return no rules and disable masking org-wide.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Flat collision-fallback query over `getFields()` only — deliberately NOT the
	 * selector's default `query`, so a future `getFieldPaths()` addition can never pull the
	 * MetadataRelationship-joined CMDT query shape (~900 ms cold) into the collision fallback,
	 * which runs inside framework-object triggers. Mirrors `SEL_MaskingTarget.fetchAllFlat`;
	 * `systemModeInternal` for the same reason as {@see systemModeRequired}.
	 *
	 * @return Every masking rule, flat-queried.
	 */
	public List<MaskingRule__mdt> fetchAllFlat()
	{
		return QRY_Builder.selectFrom(MaskingRule__mdt.SObjectType)
				.fields(getFields())
				.systemModeInternal()
				.toList();
	}

	/**
	 * @description Re-materialises SOQL-sourced rules into the `getAll()` record shape the engine
	 * and the fingerprint recipe are contracted to: fresh in-memory records (any field readable —
	 * a raw SOQL row throws `SObjectException` on un-queried field reads — and relationship fields
	 * null) with LongTextArea values truncated to the getAll() budget (`Pattern__c` is the only
	 * LongTextArea field). Without the truncation, a pattern crossing 255 characters would
	 * fingerprint differently per load path and silently flip supersession verdicts.
	 *
	 * @param rules SOQL-sourced rules carrying at least the `getFields()` field set
	 *
	 * @return getAll()-shaped in-memory copies, in input order
	 */
	public static List<MaskingRule__mdt> normaliseToGetAllShape(List<MaskingRule__mdt> rules)
	{
		List<SObjectField> fields = new SEL_MaskingRule().getFields();
		List<MaskingRule__mdt> shaped = new List<MaskingRule__mdt>();

		for(MaskingRule__mdt rule : rules)
		{
			MaskingRule__mdt copy = new MaskingRule__mdt(Id = rule.Id);
			for(SObjectField field : fields)
			{
				copy.put(field, rule.get(field));
			}
			copy.Pattern__c = copy.Pattern__c?.left(GET_ALL_LONG_TEXT_LIMIT);
			shaped.add(copy);
		}

		return shaped;
	}

}