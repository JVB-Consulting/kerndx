// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the MaskingRule__mdt custom metadata type.
 *
 * Rules normally load through a separate cache in `SEL_MaskingTarget`, filled from getAll(), and never
 * through `Rule__r` joins. A rule without a target still has no effect, because the engine applies rules
 * only through targets. This selector is the one place that defines (1) the rule field list, which is also
 * the field list of the fallback query used when getAll() fails, (2) the Mode__c and FailureAction__c
 * picklist-value constants that Apex callers branch on, and (3) how a rule's fingerprint is built and the
 * helpers that decide supersession (a newer rule replacing an older one that it names in Replaces__c).
 * Its one query of its own is `fetchAllFlat`: the slower read that `SEL_MaskingTarget` falls back to when
 * two records with the same DeveloperName make `getAll()` fail.
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
 * @date April 2026, October 2026
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
	 * @description DeveloperName of the shipped MaskAddress rule. Defined once here, so
	 * callers and tests use the constant instead of typing the name again.
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
	 * @description Fully-qualified API name of the MaskingRule__mdt object: namespaced
	 * (`kern__MaskingRule__mdt`) in a subscriber org, and without a namespace prefix
	 * (`MaskingRule__mdt`) in the framework's development org. Used by callers that write metadata
	 * XML that refers to the type.
	 */
	public static final String OBJECT_NAME = UTIL_SObjectDescribe.getObjectNameFromType(MaskingRule__mdt.SObjectType);

	/**
	 * @description Namespace-aware API name of `IsActive__c`.
	 */
	public static final String FIELD_IS_ACTIVE = MaskingRule__mdt.IsActive__c.getDescribe().name;

	/**
	 * @description The number of characters `getAll()` cuts LongTextArea values down to. The fallback
	 * read does the same, so a record read by the fallback gets the same fingerprint as the getAll()
	 * records that the stored supersession fingerprints were generated from.
	 */
	private static final Integer GET_ALL_LONG_TEXT_LIMIT = 255;

	/**
	 * @description The rule values that change how a rule masks, serialised to JSON for the fingerprint,
	 * so a value that contains a delimiter can never run into the next field. Each value is normalised
	 * first (null becomes empty, a Boolean becomes true or false, MinInputLength becomes a whole-number
	 * string), so differences in how the platform serialises values cannot change a supersession
	 * decision. The platform decides the order of the serialised fields, and that order is stable. The
	 * tests in SEL_MaskingRule_TEST that compare against stored fingerprints fail if the platform ever
	 * changes how it serialises them.
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
	 * @description The standard fingerprint of the rule values that change how a rule masks. This is
	 * the only code that builds supersession fingerprints: the fingerprints stored on shipped records
	 * are generated by running this helper (never worked out by hand), and SEL_MaskingRule_TEST checks
	 * how they are built. Leaves out Category, Description, Order and IsActive (they are labels, run
	 * order, or handled separately).
	 *
	 * Inputs must be records shaped as getAll() returns them, because that is what the engine reads.
	 * getAll() cuts LongTextArea values (Pattern__c) to 255 characters, while SOQL returns them in full,
	 * so a record read by SOQL can get a different fingerprint once a pattern is longer than that. Stored
	 * fingerprints are therefore generated only from records read by getAll(). MinInputLength__c ships
	 * with scale 0, so the intValue() step assumes whole numbers.
	 *
	 * @param rule The rule whose live values to fingerprint
	 *
	 * @return Lowercase SHA-256 hex of the standard JSON of those values
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
	 * @description Maps each qualifying successor to the predecessors it supersedes. A successor is a
	 * newer rule that names an older rule, its predecessor, in Replaces__c. A pair qualifies only when every
	 * condition holds: the successor is active and names the predecessor in Replaces__c with a matching
	 * NamespacePrefix; the predecessor's current fingerprint equals the successor's
	 * ReplacesFingerprint__c (the predecessor was not tuned); and the successor's current fingerprint
	 * equals its own ShippedFingerprint__c (the successor was not tuned). A tuned successor must never
	 * replace its predecessor, or fields it no longer covers would quietly stop being masked. A rule
	 * that names itself is ignored: replacing itself would switch off the rule's own targets. Each pair
	 * stands on its own: the method does not follow chains, and code that reads the result must never
	 * let the fields one pair covers switch off another pair's predecessor. Every key and value is
	 * namespace-qualified through resolveQualifiedDeveloperName, so an org-local copy that shares a
	 * packaged rule's DeveloperName is never mistaken for the packaged rule.
	 *
	 * @param rules Every rule to check (typically SEL_MaskingTarget.getAllRulesById().values())
	 *
	 * @return Qualified successor name, mapped to the qualified names of the predecessors that successor supersedes
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
	 * @description Qualified names of every rule superseded by any qualifying successor. Used where
	 * it does not matter which fields each pair covers (filtering advisor candidates, health check
	 * results). Code that needs to know the fields each pair covers must use findSupersessionLinks.
	 *
	 * @param rules Every rule to check (typically SEL_MaskingTarget.getAllRulesById().values())
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
	 * @description Qualified names of the rules that an active, untuned successor really supersedes:
	 * the same DeveloperName as its Replaces__c, the same NamespacePrefix, and a current fingerprint
	 * equal to the successor's ReplacesFingerprint__c.
	 *
	 * @param successor The active, untuned successor rule
	 * @param rules Every rule to search
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
	 * @description Namespace-qualified key that identifies a rule record. A packaged record and an
	 * org-local record can legally share a DeveloperName, so all supersession code must key rules
	 * through this helper to keep the two apart. A record with a blank prefix is keyed on the bare
	 * DeveloperName, which matches in-memory records and unmanaged orgs.
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
	 * @description Namespace-qualified key built from a prefix and a developer name. For a caller
	 * that keys a rule another record only names (a successor's Replaces__c), when it does not hold
	 * the rule record itself. The named rule is keyed under the naming record's own prefix: a rule
	 * can never supersede a rule in another namespace, so a record in another namespace that names a
	 * packaged DeveloperName must be keyed apart from the packaged rule.
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
	 * @description Returns the core fields for MaskingRule__mdt queries. The fallback read uses the
	 * same list: when `MaskingRule__mdt.getAll()` fails on a duplicate DeveloperName, `SEL_MaskingTarget`
	 * rebuilds the rule cache from a flat selector query over exactly these fields. Every field that
	 * any reader of the cache uses must be listed here, or the fallback quietly leaves it null
	 * (MasterLabel and Category__c are read from the cache by the Data Masking Advisor, not needed by
	 * the query builder).
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
	 * @description Framework-internal CMDT selector: always runs in `AccessLevel.SYSTEM_MODE`,
	 * whatever the `UserModeQueries_Enabled` feature flag says. Subscribers usually give running
	 * users no access to `kern__*__mdt` records on purpose, so a USER_MODE fallback read after
	 * getAll() fails would quietly return no rules and switch off masking for the whole org.
	 *
	 * @return `true`: this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Flat fallback query over `getFields()` only. It deliberately does not use the
	 * selector's default `query`, so a field path added to `getFieldPaths()` later can never bring the
	 * slow CMDT query that joins MetadataRelationship fields (about 900 ms on a cold cache) into the
	 * fallback, which runs inside triggers on framework objects. Works like
	 * `SEL_MaskingTarget.fetchAllFlat`. Uses `systemModeInternal` for the same reason as
	 * {@see systemModeRequired}.
	 *
	 * @return Every masking rule, from a flat query.
	 */
	public List<MaskingRule__mdt> fetchAllFlat()
	{
		return QRY_Builder.selectFrom(MaskingRule__mdt.SObjectType)
				.fields(getFields())
				.systemModeInternal()
				.toList();
	}

	/**
	 * @description Copies rules read by SOQL into the `getAll()` record shape that the engine and the
	 * fingerprint code expect. The copies are new in-memory records, so every field can be read (a raw
	 * SOQL row throws `SObjectException` when code reads a field that was not queried), and their
	 * relationship fields are null. LongTextArea values are cut to the getAll() length (`Pattern__c` is
	 * the only LongTextArea field). Without that cut, a pattern longer than 255 characters would get a
	 * different fingerprint on each read path, and supersession decisions would quietly change.
	 *
	 * @param rules Rules read by SOQL, carrying at least the `getFields()` field set
	 *
	 * @return In-memory copies shaped as getAll() returns them, in input order
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