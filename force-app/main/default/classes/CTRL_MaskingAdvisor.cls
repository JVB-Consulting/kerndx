// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Controller for the Data Masking Advisor console. Surfaces problems in the org's
 * data-masking configuration so administrators can correct them before sensitive data is exposed.
 * The first diagnostic flags dead configuration — active `MaskingTarget__mdt` records whose rule is
 * inactive or missing, which silently mask nothing despite appearing configured.
 *
 * @see CTRL_MaskingAdvisor_TEST
 * @see SEL_MaskingTarget
 * @see MaskingRule__mdt
 * @see MaskingTarget__mdt
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date May 2026, June 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength,PMD.NcssTypeCount')
public inherited sharing class CTRL_MaskingAdvisor
{
	/**
	 * @description The kind of dead-configuration problem found on an active masking target. A closed
	 * set — each value maps to a user-facing Custom Label that explains the problem to an administrator.
	 */
	public enum ConfigurationIssue
	{
		/**
		 * @description An active target references a rule that exists but is inactive — it masks nothing.
		 */
		INACTIVE_RULE,
		/**
		 * @description An active target references a rule that does not exist (or is null) — it masks nothing.
		 */
		MISSING_RULE
	}

	/**
	 * @description Confidence tier for a heuristic name/type match, used only when a field carries no
	 * native classification. A coarse three-level label — never an assertion that the field is sensitive.
	 */
	public enum HeuristicConfidence
	{
		/**
		 * @description Strong signal — a recognised sensitive-identifier name, or a contact field whose
		 * type and name agree (for example an email-typed field named email).
		 */
		HIGH,
		/**
		 * @description Moderate signal — a contact-data field type (email or phone) with a neutral name.
		 */
		MEDIUM,
		/**
		 * @description Weak signal — a lone ambiguous substring (for example card, token, secret); hidden
		 * by default in the console to curb false positives.
		 */
		LOW
	}

	/**
	 * @description Field-name substrings that are strong sensitive-identifier signals (high confidence).
	 * Covers US/UK/EU regulated PII, regional national identifiers across 25+ jurisdictions, PCI sensitive
	 * authentication data, HIPAA Safe Harbor healthcare identifiers, ISO banking codes, and telecom
	 * subscriber identifiers. Matched case-insensitively as substrings of the field DeveloperName / label,
	 * so coverage is strongest when the org follows Salesforce English-API-name convention; non-English
	 * API names get partial coverage from English fragments in the translated label.
	 */
	private static final Set<String> HIGH_CONFIDENCE_NAME_PATTERNS = new Set<String>
	{
			'ssn', 'socialsecurity', 'passport', 'creditcard', 'cardnumber', 'taxid', 'nationalid', 'iban',
			'nino', 'nationalinsurance', 'bsn', 'cpf', 'cnpj', 'curp', 'rfc', 'aadhaar', 'aadhar', 'uidai',
			'pancard', 'pannumber', 'pesel', 'codicefiscale', 'rrn', 'mynumber', 'kojinbango', 'nric',
			'tckimlik', 'cnic', 'emiratesid', 'cuil', 'cedula', 'fodselsnummer', 'personnummer', 'hetu',
			'sozialversicherung', 'steuerid', 'steuernummer', 'ppsn', 'rut',
			'cvv', 'cvc', 'cvv2', 'cvc2', 'cardverification', 'pinblock', 'magstripe', 'trackdata',
			'mrn', 'medicalrecord', 'patientid', 'healthplan', 'beneficiaryid', 'deanumber', 'npinumber',
			'medicaid', 'medicare',
			'swiftcode', 'biccode',
			'imei', 'imsi', 'iccid'
	};

	/**
	 * @description Field-name substrings that are moderate sensitive-data signals (medium confidence).
	 * Covers secondary identifiers (DOB, driver license, VAT/tax numbers), insurance and healthcare
	 * compound identifiers, banking transfer references, telecom subscriber numbers, travel-programme
	 * identifiers, and government / biometric markers.
	 */
	private static final Set<String> MEDIUM_CONFIDENCE_NAME_PATTERNS = new Set<String>
	{
			'dateofbirth', 'dob', 'license', 'routing', 'accountnumber', 'sortcode',
			'dlnumber', 'driverlicense', 'driverslicense', 'driverlic', 'birthdate', 'birthplace',
			'placeofbirth', 'greencard', 'alienreg', 'workpermit', 'vatnumber', 'tfn', 'abn', 'gstin',
			'policynumber', 'claimnumber', 'certificateno', 'groupnumber', 'subscriberid', 'taxonomycode',
			'wirenumber', 'achnumber', 'blz', 'fednumber',
			'msisdn',
			'frequentflyer', 'frequentflier', 'redressnumber', 'knowntraveler',
			'vinnumber', 'plateno', 'licenseplate', 'fingerprint', 'biometric'
	};

	/**
	 * @description Field-name substrings that are weak, false-positive-prone signals (low confidence).
	 * Covers generic credential markers (token, password, API key), knowledge-based-authentication
	 * fragments (maiden name, security questions), PCI truncated / masked artifacts (card last 4,
	 * expiry dates), and a small set of abbreviated Salesforce field idioms (taxno, idnbr).
	 */
	private static final Set<String> LOW_CONFIDENCE_NAME_PATTERNS = new Set<String>
	{
			'token', 'secret', 'passcode',
			'apikey', 'accesskey', 'privatekey', 'password', 'mfa', 'otp', 'recoverycode', 'authtoken',
			'maidenname', 'mothersmaiden', 'securityanswer', 'securityquestion',
			'cardlast4', 'maskedpan', 'truncatedpan', 'expirydate', 'expirationdate', 'cardexpiry',
			'cardholder',
			'taxno', 'idnbr'
	};

	/**
	 * @description Field `DisplayType`s a masking rule can sensibly be recommended on — the same
	 * text-shaped set the masking engine itself recognises (`UTIL_FrameworkMasker.getTextShapedDisplayTypes`).
	 * The recommendation resolver gates on this so a rule is never recommended on a field the framework
	 * could not mask anyway (a Boolean, Date, DateTime, Reference, …), keeping recommendations credible.
	 */
	private static final Set<DisplayType> RECOMMENDABLE_FIELD_TYPES = new Set<DisplayType>
	{
			DisplayType.STRING, DisplayType.TEXTAREA, DisplayType.URL,
			DisplayType.EMAIL, DisplayType.PHONE, DisplayType.ENCRYPTEDSTRING
	};

	/**
	 * @description Field `DisplayType`s whose type *reinforces* a name match — a match on one of these
	 * specific text types is treated as a strong signal, whereas a match on a generic STRING/TEXTAREA is
	 * only moderate (the name carried the signal, the type did not). Drives the `matchStrength` band.
	 */
	private static final Set<DisplayType> TYPE_REINFORCING_FIELD_TYPES = new Set<DisplayType>
	{
			DisplayType.EMAIL, DisplayType.PHONE, DisplayType.URL, DisplayType.ENCRYPTEDSTRING
	};

	/**
	 * @description Maps a field `DisplayType` to the rule concept (aliased stem) its type unambiguously
	 * signals, so the resolver can promote the type's own concept to the primary recommendation ahead of a
	 * longer but type-contradicting name match. An EMAIL field's primary is the `email` rule even when its
	 * name also carries the longer `address` stem (an `EmailAddress` field); a PHONE field's primary is the
	 * `phone` concept (both phone rules), made deterministic by a stable secondary order. Types with no
	 * single concept rule (STRING/TEXTAREA/URL/ENCRYPTEDSTRING) are absent — they keep the longest-stem
	 * default, since the name, not the type, carries their signal.
	 */
	private static final Map<DisplayType, String> TYPE_PRIMARY_CONCEPT = new Map<DisplayType, String>
	{
			DisplayType.EMAIL => 'email',
			DisplayType.PHONE => 'phone'
	};

	/**
	 * @description Synthetic, clearly-fictional example email input for the inline before→after example —
	 * the reserved `example.com` domain guarantees no real data is ever displayed. Only the
	 * well-defined-shape types carry an example constant; the undefined-shape text types route to
	 * "Try a value" with no auto-example.
	 */
	private static final String EXAMPLE_INPUT_EMAIL = 'jane@example.com';

	/**
	 * @description Synthetic example phone input for the inline before→after example — the reserved
	 * `555-01xx` range guarantees no real number is ever displayed.
	 */
	private static final String EXAMPLE_INPUT_PHONE = '+1 (555) 015-0100';

	/**
	 * @description Synthetic example URL input for the inline before→after example, carrying embedded
	 * fictional credentials so the redaction is visible — the `example.com` domain guarantees no real
	 * data is ever displayed.
	 */
	private static final String EXAMPLE_INPUT_URL = 'https://user:pass@example.com/account';

	/**
	 * @description The strongest of the three signal-strength band literals the LWC renders. The bands
	 * are a heuristic match-signal band, never a calibrated probability — named for the signal source so
	 * a future reader does not mistake them for a confidence percentage.
	 */
	private static final String MATCH_STRENGTH_STRONG = 'Strong';

	/**
	 * @description The middle signal-strength band literal — see `MATCH_STRENGTH_STRONG` for the band's
	 * heuristic (not probabilistic) semantics.
	 */
	private static final String MATCH_STRENGTH_MODERATE = 'Moderate';

	/**
	 * @description The weakest signal-strength band literal — see `MATCH_STRENGTH_STRONG` for the band's
	 * heuristic (not probabilistic) semantics.
	 */
	private static final String MATCH_STRENGTH_WEAK = 'Weak';

	/**
	 * @description The highest sensitivity-level axis literal the LWC renders as the reclassifiable badge —
	 * a natively classified field or a high-confidence heuristic match. The axis is deliberately
	 * domain-neutral rather than PII-specific, because framework masking covers data that is sensitive
	 * without being personally identifiable — credentials, API keys, IP addresses, payment tokens. The
	 * console shows the literals with spacing ("Possibly Sensitive"); they are the stable keys it
	 * switches on.
	 */
	@TestVisible
	private static final String SENSITIVITY_SENSITIVE = 'Sensitive';

	/**
	 * @description The middle sensitivity-level literal — a plausible but unconfirmed signal. See
	 * `SENSITIVITY_SENSITIVE` for the axis's domain-neutral naming rationale.
	 */
	private static final String SENSITIVITY_POSSIBLY_SENSITIVE = 'PossiblySensitive';

	/**
	 * @description The lowest sensitivity-level literal — no native classification and no meaningful
	 * heuristic signal. See `SENSITIVITY_SENSITIVE` for the axis's domain-neutral naming rationale.
	 */
	@TestVisible
	private static final String SENSITIVITY_NOT_SENSITIVE = 'NotSensitive';

	/**
	 * @description Stem aliases that widen substring matching where a rule's developer name carries a
	 * qualifier the field API name does not. `MaskPhoneUS` stems to `phoneus` and `MaskPhoneInternational`
	 * to `phoneinternational`, neither of which a standard phone field's API name contains; aliasing both to
	 * `phone` lets a phone field concept-match each of them, so both pre-select as candidates. The two
	 * card-rule generations alias to `card` the same way: a card field's tokens (`CreditCard__c`,
	 * `Card_Number__c`) never contain `paymentcard` or `creditcard` as a run, and the successor rule must
	 * reach every field the rule it replaces reached. Applied inside `resolveRuleStem` so the resolver and
	 * the stem-length comparator stay consistent.
	 */
	private static final Map<String, String> RULE_STEM_ALIASES = new Map<String, String>
	{
			'phoneus' => 'phone',
			'phoneinternational' => 'phone',
			'paymentcard' => 'card',
			'creditcard' => 'card'
	};

	/**
	 * @description Field-name substring → rule developer name synonyms, consulted only when the
	 * substring-stem match finds nothing. Closes the under-match for common field names a rule's own
	 * stem never reaches (a `MailingStreet` field carries no `address` stem, yet should reach
	 * `MaskAddress`). Like `RULE_STEM_ALIASES`, this is hardcoded Apex (not CMDT) to match the existing
	 * heuristic constants; making synonyms subscriber-extensible belongs to the heuristic-pattern layer.
	 * Each entry only ever fires on a recommendable-typed field — the type gate runs first — so a synonym
	 * never widens the maskable-type set (a native DATE or numeric field is excluded before any synonym
	 * is consulted). The mapped rule names come from `SEL_MaskingRule.RULE_MASK_*` (the single source of
	 * truth for shipped rule developer names); the synonym lookup resolves them namespace-aware to the
	 * package's own rules (see `findCandidateByDeveloperName`), so a subscriber-authored rule with the
	 * same developer name never hijacks a synonym.
	 *
	 * Invariant: overlapping tokens — where one is a substring of another, e.g. `street`/`mailingstreet`
	 * or `postalcode`/`mailingpostalcode` — MUST map to the same rule. `resolveSynonymRule` iterates the
	 * tokens alphabetically (deterministic) rather than by specificity, so the winner among overlapping
	 * matches is immaterial only while they resolve to the same rule. If a future entry pairs overlapping
	 * tokens that map to *different* rules, switch that iteration to longest-token-first (mirroring the
	 * stem-length-descending precedence) so the most specific synonym wins.
	 */
	private static final Map<String, String> FIELD_NAME_RULE_SYNONYMS = new Map<String, String>
	{
			'street' => SEL_MaskingRule.RULE_MASK_ADDRESS,
			'mailingstreet' => SEL_MaskingRule.RULE_MASK_ADDRESS,
			'otherstreet' => SEL_MaskingRule.RULE_MASK_ADDRESS,
			'billingstreet' => SEL_MaskingRule.RULE_MASK_ADDRESS,
			'shippingstreet' => SEL_MaskingRule.RULE_MASK_ADDRESS,
			'postalcode' => SEL_MaskingRule.RULE_MASK_ADDRESS,
			'mailingpostalcode' => SEL_MaskingRule.RULE_MASK_ADDRESS,
			'otherpostalcode' => SEL_MaskingRule.RULE_MASK_ADDRESS,
			'billingpostalcode' => SEL_MaskingRule.RULE_MASK_ADDRESS,
			'shippingpostalcode' => SEL_MaskingRule.RULE_MASK_ADDRESS,
			'zip' => SEL_MaskingRule.RULE_MASK_ADDRESS,
			'zipcode' => SEL_MaskingRule.RULE_MASK_ADDRESS,
			'fax' => SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL,
			'mobile' => SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL,
			'cell' => SEL_MaskingRule.RULE_MASK_PHONE_INTERNATIONAL
	};

	/**
	 * @description Maximum number of real records sampled in a single real-record masking preview, capping
	 * the volume of real (authorised) data surfaced to the console.
	 */
	private static final Integer SAMPLE_LIMIT = 10;

	/**
	 * @description The CustomMetadata `<value>` element emitted for a blank field — `xsi:nil`.
	 */
	private static final String NIL_VALUE = '<value xsi:nil="true"/>';

	/**
	 * @description The shared "nothing matched" result — a `null` rule with `NONE` provenance. Held as a
	 * single immutable instance so the resolver's guard clauses and synonym fallback all return the one
	 * sentinel instead of each constructing an identical empty `RuleMatch`. The `RuleMatch` inner type is
	 * immutable (both fields `final`), so sharing one instance is safe.
	 */
	private static final RuleMatch NO_MATCH = new RuleMatch(null, MatchProvenance.NONE);

	/**
	 * @description Admin-facing message templates keyed by issue kind. Each template carries a single
	 * `{0}` placeholder for the offending target's developer name, substituted at request time.
	 */
	@TestVisible
	private static final Map<ConfigurationIssue, String> MESSAGE_TEMPLATE_BY_ISSUE = new Map<ConfigurationIssue, String>
	{
			ConfigurationIssue.INACTIVE_RULE => System.Label.DataMaskingAdvisor_DeadConfiguration_InactiveRule,
			ConfigurationIssue.MISSING_RULE => System.Label.DataMaskingAdvisor_DeadConfiguration_MissingRule
	};

	/**
	 * @description Custom Metadata Type API-name suffix (`__mdt`), stripped from a selector's `OBJECT_NAME`
	 * to derive the CMDT type developer-name stem used in the generated bundle's file paths and `package.xml`
	 * members. `@TestVisible` so the generation tests build the same stem without re-typing the literal.
	 */
	@TestVisible
	private static final String CUSTOM_METADATA_SUFFIX = '__mdt';

	/**
	 * @description Custom-object API-name suffix (`__c`), used to mark the object-picker options the
	 * custom-object coverage scan iterates.
	 */
	private static final String CUSTOM_OBJECT_SUFFIX = '__c';

	/**
	 * @description Maximum length of a short Text Area field. A `TEXTAREA`-typed field longer than this is a
	 * Long Text Area (or Rich Text) — the regulated-field inventory flags those as a free-text masking blind
	 * spot.
	 */
	private static final Integer SHORT_TEXT_AREA_MAX_LENGTH = 255;

	/**
	 * @description Upper bound on the custom objects one Health Check run assesses for masking coverage.
	 * Each assessment costs a FieldDefinition query, so an unbounded sweep would exhaust transaction
	 * limits in an org with hundreds of custom objects; candidates beyond the bound surface as an
	 * unchecked count that routes the administrator to the console's full scan.
	 */
	@TestVisible
	private static final Integer MAXIMUM_OBJECTS_ASSESSED_PER_HEALTH_CHECK = 10;

	/**
	 * @description CMDT-bundle file-path / `package.xml` member stem for MaskingTarget records — the
	 * CMDT object's namespaced API name with the `__mdt` suffix stripped. Resolves to `kern__MaskingTarget`
	 * in a subscriber org and `MaskingTarget` in the framework's dev preview.
	 */
	private static final String TYPE_STEM_MASKING_TARGET = SEL_MaskingTarget.OBJECT_NAME.removeEnd(CUSTOM_METADATA_SUFFIX);

	/**
	 * @description CMDT-bundle file-path / `package.xml` member stem for MaskingRule records — see
	 * `TYPE_STEM_MASKING_TARGET`.
	 */
	private static final String TYPE_STEM_MASKING_RULE = SEL_MaskingRule.OBJECT_NAME.removeEnd(CUSTOM_METADATA_SUFFIX);

	/**
	 * @description Returns every dead-configuration finding across the org's masking setup. Sources all
	 * masking targets and rules — active and inactive — through SEL_MaskingTarget so the inactive-rule
	 * versus missing-rule distinction is preserved, then flags each active target whose rule is inactive
	 * or absent.
	 *
	 * @return One finding per dead active target (empty when the configuration is healthy)
	 *
	 * @example
	 * ```apex
	 * List<CTRL_MaskingAdvisor.DTO_DeadConfiguration> findings = CTRL_MaskingAdvisor.getDeadConfigurations();
	 * ```
	 */
	@AuraEnabled
	public static List<DTO_DeadConfiguration> getDeadConfigurations()
	{
		SEL_MaskingTarget selector = new SEL_MaskingTarget();
		return analyzeDeadConfiguration(selector.getAllTargets(), selector.getAllRulesById());
	}

	/**
	 * @description Summarizes the org's masking posture from its configured targets — the count of distinct
	 * objects with an active target, the active field-level and object-wide target counts, and the dead-
	 * configuration count — to drive the console's Review landing view. The counts are **as-configured**
	 * CustomMetadata target counts, not a describe-level org scan: an org-wide describe of every object is a
	 * real limits/performance risk, and a target pointing at a since-deleted field still appears here, so the
	 * numbers describe what is configured, not what a per-object analysis would verify (the per-object
	 * `getDeadConfigurations` surfaces orphaned targets at drill-down).
	 *
	 * @return The org-wide posture summary.
	 *
	 * @example
	 * ```apex
	 * CTRL_MaskingAdvisor.DTO_OrgPostureSummary summary = CTRL_MaskingAdvisor.getOrgPostureSummary();
	 * ```
	 */
	@AuraEnabled
	public static DTO_OrgPostureSummary getOrgPostureSummary()
	{
		SEL_MaskingTarget selector = new SEL_MaskingTarget();
		return summarizePosture(selector.getAllTargets(), selector.getAllRulesById());
	}

	/**
	 * @description Returns the org's masked objects as a drillable inventory for the Review landing view —
	 * one entry per object that carries at least one active masking target, each with its active object-wide
	 * and field-level target counts, the distinct active rule labels applied across the object, and the count
	 * of dead configurations scoped to it. Object durable Ids are resolved to their API name and label in a
	 * single `EntityDefinition` query (avoiding the slow MetadataRelationship traversal); an object whose
	 * durable Id does not resolve — a since-deleted object still referenced by a target — is omitted. The rows
	 * reconcile with `getOrgPostureSummary`: the row count equals the summary's objects-with-active-targets
	 * count (modulo any active target whose `SObjectType__c` is blank or does not resolve), and the per-object
	 * dead counts sum to its dead-configuration count.
	 *
	 * @return One inventory entry per masked object, ordered by object label.
	 *
	 * @example
	 * ```apex
	 * List<CTRL_MaskingAdvisor.DTO_ObjectMaskingInventory> inventory = CTRL_MaskingAdvisor.getOrgPostureInventory();
	 * ```
	 */
	@AuraEnabled
	public static List<DTO_ObjectMaskingInventory> getOrgPostureInventory()
	{
		SEL_MaskingTarget selector = new SEL_MaskingTarget();
		List<MaskingTarget__mdt> targets = selector.getAllTargets();
		Map<Id, MaskingRule__mdt> rulesById = selector.getAllRulesById();

		Set<String> durableIds = new Set<String>();
		for(MaskingTarget__mdt target : targets)
		{
			if(target.IsActive__c == true && String.isNotBlank(target.SObjectType__c))
			{
				durableIds.add(target.SObjectType__c);
			}
		}

		Map<String, String> apiNameByDurableId = new Map<String, String>();
		Map<String, String> labelByDurableId = new Map<String, String>();
		for(EntityDefinition entity : new SEL_EntityDefinition().findByDurableIds(durableIds))
		{
			apiNameByDurableId.put(entity.DurableId, entity.QualifiedApiName);
			labelByDurableId.put(entity.DurableId, entity.Label);
		}

		return summarizeInventory(targets, rulesById, apiNameByDurableId, labelByDurableId);
	}

	/**
	 * @description Returns the SObjects an administrator can choose to analyze — every customizable object
	 * that can host an Apex trigger, ordered by label — to populate the console's object picker. Masking is
	 * applied through the trigger framework, so non-triggerable objects (which can never be masked) are excluded.
	 *
	 * @return One option per selectable object (API name + label)
	 */
	@AuraEnabled
	public static List<DTO_ObjectOption> listObjects()
	{
		List<DTO_ObjectOption> options = new List<DTO_ObjectOption>();

		for(EntityDefinition entity : new SEL_EntityDefinition().findSelectableObjects())
		{
			DTO_ObjectOption option = new DTO_ObjectOption();
			option.apiName = entity.QualifiedApiName;
			option.label = entity.Label;
			option.isCustom = entity.QualifiedApiName.endsWith(CUSTOM_OBJECT_SUFFIX);
			option.namespacePrefix = entity.NamespacePrefix;
			options.add(option);
		}

		return options;
	}

	/**
	 * @description Returns the fields of one SObject enriched for the coverage advisor: native
	 * classification where available (with a graceful, silent fall back to heuristics when FieldDefinition
	 * cannot be read), a heuristic confidence tier for unclassified fields, and the masking targets already
	 * applied to each field (active and inactive) so the console can render existing coverage and offer a
	 * disable / re-enable diff. Output is restricted to fields the framework can actually
	 * mask: the text-shaped types (`RECOMMENDABLE_FIELD_TYPES`) that are also writable — the type gate plus
	 * a system-managed-field exclusion are applied in `UTIL_SObjectDescribe` so metadata is never built for
	 * fields that would only be discarded. The type gate alone keeps every Id/audit-stamp/lookup/Boolean/
	 * Date field out (they are non-text), and the system-managed exclusion additionally drops text-typed
	 * fields the engine cannot write — formula/roll-up (computed) and auto-number (assigned) — so the
	 * analysis never recommends masking a field the engine would silently skip.
	 *
	 * @param objectApiName The SObject to analyze (for example `Account`)
	 *
	 * @return The field analysis (empty when the object name does not resolve)
	 */
	@AuraEnabled
	public static DTO_FieldAnalysis describeFields(String objectApiName)
	{
		DTO_FieldAnalysis analysis = new DTO_FieldAnalysis();
		analysis.fields = new List<DTO_FieldRow>();

		SObjectType sObjectType = UTIL_SObjectDescribe.getSObjectTypeByName(objectApiName);
		if(sObjectType == null)
		{
			analysis.classificationAvailable = true;
			return analysis;
		}

		Map<String, FieldDefinition> classificationByFieldName = new Map<String, FieldDefinition>();

		try
		{
			for(FieldDefinition definition : new SEL_FieldDefinition().findByEntity(objectApiName))
			{
				classificationByFieldName.put(definition.QualifiedApiName.toLowerCase(), definition);
			}
			analysis.classificationAvailable = true;
		}
		catch(QueryException error)
		{
			analysis.classificationAvailable = false;
		}

		List<MaskingRule__mdt> allRules = new SEL_MaskingTarget().getAllRulesById().values();
		Map<String, String> successorLabelByReplacedName = resolveSuccessorLabels(allRules);
		List<MaskingRule__mdt> recommendationCandidates = sortedRecommendationCandidates(rulesWithoutSuperseded(allRules));
		ExistingMasking existing = resolveExistingTargets(sObjectType, successorLabelByReplacedName);
		FieldAnalysisContext context = new FieldAnalysisContext
				(
						sObjectType,
						classificationByFieldName,
						existing,
						recommendationCandidates,
						applicableRuleNamesByType(recommendationCandidates)
				);

		Map<String, UTIL_SObjectDescribe.DTO_FieldInformation> fieldInformationByName = UTIL_SObjectDescribe.getAllFieldInformation(objectApiName, RECOMMENDABLE_FIELD_TYPES, true);
		for(String fieldApiName : fieldInformationByName.keySet())
		{
			analysis.fields.add(buildFieldRow(fieldApiName, fieldInformationByName.get(fieldApiName), context));
		}

		analysis.rules = buildRuleCatalogue(context.recommendationCandidates, successorLabelByReplacedName);
		analysis.objectWideRules = existing.objectWideRules;
		analysis.newRuleSetupUrl = buildNewRuleSetupUrl();

		return analysis;
	}

	/**
	 * @description Drops every rule the supersession verdict marks superseded — an untuned predecessor
	 * fully replaced by an untuned active successor would only duplicate the successor in the catalogue
	 * and the recommendation candidates. Verdict keys are namespace-qualified
	 * (`resolveQualifiedDeveloperName`), so a packaged verdict can never drop an org-local clone that
	 * shares a packaged rule's DeveloperName. A tuned generation never reaches the verdict, so a
	 * customised predecessor stays visible.
	 *
	 * @param rules The full rule universe.
	 *
	 * @return The rules no qualifying successor supersedes.
	 */
	private static List<MaskingRule__mdt> rulesWithoutSuperseded(List<MaskingRule__mdt> rules)
	{
		Set<String> supersededNames = SEL_MaskingRule.findSupersededRuleNames(rules);
		if(supersededNames.isEmpty())
		{
			return rules;
		}
		List<MaskingRule__mdt> visibleRules = new List<MaskingRule__mdt>();
		for(MaskingRule__mdt rule : rules)
		{
			if(!supersededNames.contains(SEL_MaskingRule.resolveQualifiedDeveloperName(rule)))
			{
				visibleRules.add(rule);
			}
		}
		return visibleRules;
	}

	/**
	 * @description Maps each named-as-replaced rule (qualified under the naming successor's own prefix —
	 * cross-namespace supersession is never legal) to that successor's label. Name-based deliberately,
	 * NOT the fingerprint verdict: a tuned generation fails the verdict and stays in the catalogue, yet
	 * the admin should still see which rule replaces it. A rule naming itself is ignored, mirroring the
	 * verdict engine's self-supersession guard. Keys are lowercased on both hops because platform
	 * developer names are case-insensitive (the verdict engine pairs them with ==) while Apex map keys
	 * are not — a case-mismatched org-local `Replaces__c` must not silently miss.
	 *
	 * @param rules The full rule universe.
	 *
	 * @return Successor label keyed by the lowercased qualified name of the rule it replaces.
	 */
	private static Map<String, String> resolveSuccessorLabels(List<MaskingRule__mdt> rules)
	{
		Map<String, String> successorLabelByReplacedName = new Map<String, String>();
		for(MaskingRule__mdt rule : rules)
		{
			if(String.isNotBlank(rule.Replaces__c) && rule.Replaces__c != rule.DeveloperName)
			{
				successorLabelByReplacedName.put(SEL_MaskingRule.resolveQualifiedName(rule.NamespacePrefix, rule.Replaces__c).toLowerCase(), rule.MasterLabel);
			}
		}
		return successorLabelByReplacedName;
	}

	/**
	 * @description Builds the supersession annotation for one rule — the `MaskingRuleSupersededBy` label
	 * formatted with the successor's label — or null when no successor names the rule.
	 *
	 * @param rule The rule to annotate.
	 * @param successorLabelByReplacedName Successor label keyed by the lowercased qualified replaced-rule name.
	 *
	 * @return The annotation, or null when no successor names the rule.
	 */
	private static String resolveSupersededAnnotation(MaskingRule__mdt rule, Map<String, String> successorLabelByReplacedName)
	{
		String qualifiedName = SEL_MaskingRule.resolveQualifiedDeveloperName(rule);
		String successorLabel = qualifiedName == null ? null : successorLabelByReplacedName.get(qualifiedName.toLowerCase());
		return successorLabel == null ? null : String.format(System.Label.MaskingRuleSupersededBy, new List<String> {successorLabel});
	}

	/**
	 * @description Assesses one SObject's masking coverage for the custom-object coverage scan: whether any
	 * active masking target (field-level or object-wide) covers the object, and which of its fields look
	 * sensitive while no masking is configured. One object per call — the console iterates the custom
	 * objects from `listObjects` so each assessment stays within a single transaction's limits.
	 *
	 * @param objectApiName The SObject to assess (for example `CustomerFeedback__c`)
	 *
	 * @return The coverage assessment (safe and empty when the object name does not resolve)
	 */
	@AuraEnabled
	public static DTO_ObjectCoverageAssessment assessObjectCoverage(String objectApiName)
	{
		DTO_ObjectCoverageAssessment assessment = new DTO_ObjectCoverageAssessment();
		assessment.objectApiName = objectApiName;
		assessment.hasActiveMasking = false;
		assessment.requiresAttention = false;
		assessment.flaggedFields = new List<DTO_FlaggedField>();

		SObjectType sObjectType = UTIL_SObjectDescribe.getSObjectTypeByName(objectApiName);
		if(sObjectType == null)
		{
			return assessment;
		}
		UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(sObjectType);
		assessment.objectLabel = describe.getDescribe().getLabel();

		DTO_FieldAnalysis analysis = describeFields(objectApiName);
		assessment.hasActiveMasking = containsActiveMasking(analysis);
		if(assessment.hasActiveMasking)
		{
			return assessment;
		}

		for(DTO_FieldRow row : analysis.fields)
		{
			Boolean isSensitive = SENSITIVITY_SENSITIVE == row.sensitivityLevel;
			if(!isSensitive && SENSITIVITY_POSSIBLY_SENSITIVE != row.sensitivityLevel)
			{
				continue;
			}
			DTO_FlaggedField flagged = new DTO_FlaggedField();
			flagged.fieldApiName = row.apiName;
			flagged.fieldLabel = row.label;
			flagged.sensitivityLevel = row.sensitivityLevel;
			flagged.isLongTextArea = isLongTextArea(describe, row.apiName);
			assessment.flaggedFields.add(flagged);
		}

		// The object requires attention when any likely-sensitive field (sensitive OR possibly sensitive) has
		// no masking — the same bar the on-demand coverage scan flags on, so the Health Check card, the scan,
		// and the landing all name the same objects rather than diverging on a hidden sensitivity threshold.
		assessment.requiresAttention = !assessment.flaggedFields.isEmpty();

		return assessment;
	}

	/**
	 * @description Summarizes the masking coverage of the subscriber's own custom objects for the Health
	 * Check card: assesses up to `MAXIMUM_OBJECTS_ASSESSED_PER_HEALTH_CHECK` un-namespaced custom objects
	 * via `assessObjectCoverage` and reports the ones requiring attention plus the count left unchecked.
	 * Standard objects and managed-package objects are not candidates — the console's on-demand scan
	 * covers those on the administrator's explicit request. A candidate whose name does not
	 * describe-resolve counts as unchecked without consuming an assessment slot, so a stale
	 * EntityDefinition row can never push a real offender out of the assessed window.
	 *
	 * @return The bounded coverage summary.
	 */
	public static DTO_CustomObjectCoverageSummary summarizeCustomObjectCoverage()
	{
		DTO_CustomObjectCoverageSummary summary = new DTO_CustomObjectCoverageSummary();
		summary.assessedObjectCount = 0;
		summary.unassessedObjectCount = 0;
		summary.objectsRequiringAttention = new List<String>();

		for(EntityDefinition entity : new SEL_EntityDefinition().findSelectableObjects())
		{
			if(!entity.QualifiedApiName.endsWith(CUSTOM_OBJECT_SUFFIX) || entity.NamespacePrefix != null)
			{
				continue;
			}
			if
			(
					summary.assessedObjectCount >= MAXIMUM_OBJECTS_ASSESSED_PER_HEALTH_CHECK ||
					UTIL_SObjectDescribe.getSObjectTypeByName(entity.QualifiedApiName) == null
			)
			{
				summary.unassessedObjectCount++;
				continue;
			}
			summary.assessedObjectCount++;

			if(assessObjectCoverage(entity.QualifiedApiName).requiresAttention)
			{
				summary.objectsRequiringAttention.add(entity.QualifiedApiName);
			}
		}

		return summary;
	}

	/**
	 * @description Builds the regulated-field inventory for one object: every maskable field the advisor rates
	 * `Sensitive` or `PossiblySensitive`, each projected into a spreadsheet-ready row. Unlike
	 * `assessObjectCoverage`, the inventory lists fields regardless of whether masking already covers them,
	 * marking each with `maskedToday` — the export is a coverage map across both covered and uncovered fields.
	 * Scope mirrors the advisor's analysis: the maskable text-shaped field types (`RECOMMENDABLE_FIELD_TYPES`),
	 * excluding system-managed and computed fields (formulas, auto-numbers) the framework cannot mask. Fields
	 * the advisor leaves `NotSensitive` — including type-reinforcing "likely miss" fields — are not inventoried;
	 * the console's interactive "Other" section surfaces those. One object per call: the console iterates the
	 * chosen scope and assembles the CSV/JSON client-side, keeping each describe within a single transaction's
	 * limits the way the on-demand scan does.
	 *
	 * @param objectApiName The SObject to inventory (for example `CustomerFeedback__c`).
	 *
	 * @return The object's regulated-field inventory (safe and empty when the object name does not resolve).
	 */
	@AuraEnabled
	public static DTO_ObjectFieldInventory getRegulatedFieldInventory(String objectApiName)
	{
		DTO_ObjectFieldInventory inventory = new DTO_ObjectFieldInventory();
		inventory.objectApiName = objectApiName;
		inventory.rows = new List<DTO_FieldInventoryRow>();

		SObjectType sObjectType = UTIL_SObjectDescribe.getSObjectTypeByName(objectApiName);
		if(sObjectType == null)
		{
			return inventory;
		}
		UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(sObjectType);
		inventory.objectLabel = describe.getDescribe().getLabel();

		DTO_FieldAnalysis analysis = describeFields(objectApiName);
		Boolean objectWideMasked = hasActiveRule(analysis.objectWideRules);

		for(DTO_FieldRow row : analysis.fields)
		{
			if(!isRegulated(row.sensitivityLevel))
			{
				continue;
			}
			inventory.rows.add(toInventoryRow(row, describe, objectWideMasked));
		}

		return inventory;
	}

	/**
	 * @description Projects one analyzed field row into the regulated-field inventory shape, deriving the
	 * Long Text Area flag from the field describe, the masked-today flag from object-wide and field-level
	 * active targets, and the history-tracking recommendation from the sensitivity rating.
	 *
	 * @param row The analyzed field row to project.
	 * @param describe The cached object describe, for the field's length/type.
	 * @param objectWideMasked Whether an active object-wide target covers every field on the object.
	 *
	 * @return The inventory row.
	 */
	private static DTO_FieldInventoryRow toInventoryRow(DTO_FieldRow row, UTIL_SObjectDescribe describe, Boolean objectWideMasked)
	{
		DTO_FieldInventoryRow inventoryRow = new DTO_FieldInventoryRow();
		inventoryRow.fieldApiName = row.apiName;
		inventoryRow.fieldLabel = row.label;
		inventoryRow.fieldType = row.type;
		inventoryRow.isLongTextArea = isLongTextArea(describe, row.apiName);
		inventoryRow.securityClassification = row.securityClassification;
		inventoryRow.complianceGroup = row.complianceGroup;
		inventoryRow.sensitivityLevel = row.sensitivityLevel;
		inventoryRow.recommendedRuleDeveloperName = row.recommendedRuleDeveloperName;
		inventoryRow.recommendedRuleLabel = row.recommendedRuleLabel;
		inventoryRow.maskedToday = objectWideMasked || hasActiveRule(row.appliedRules);
		inventoryRow.historyTrackingRecommended = SENSITIVITY_SENSITIVE == row.sensitivityLevel;
		return inventoryRow;
	}

	/**
	 * @description Reports whether a sensitivity level is regulated — `Sensitive` or `PossiblySensitive` —
	 * so the inventory lists the fields that hold or likely hold regulated data and excludes the rest.
	 *
	 * @param sensitivityLevel The field's resolved sensitivity level.
	 *
	 * @return `true` when the field is regulated.
	 */
	private static Boolean isRegulated(String sensitivityLevel)
	{
		return SENSITIVITY_SENSITIVE == sensitivityLevel || SENSITIVITY_POSSIBLY_SENSITIVE == sensitivityLevel;
	}

	/**
	 * @description Reports whether a field is a Long Text Area (or Rich Text) — `TEXTAREA` display type with
	 * a length beyond the short Text Area ceiling — the common unmasked free-text blind spot the export flags.
	 *
	 * @param describe The cached object describe.
	 * @param fieldApiName The field to inspect.
	 *
	 * @return `true` when the field is a Long Text Area.
	 */
	private static Boolean isLongTextArea(UTIL_SObjectDescribe describe, String fieldApiName)
	{
		DescribeFieldResult field = describe.getFieldDescribe(fieldApiName);
		return field != null && field.getType() == DisplayType.TEXTAREA && field.getLength() > SHORT_TEXT_AREA_MAX_LENGTH;
	}

	/**
	 * @description Reports whether the list holds any active applied rule.
	 *
	 * @param appliedRules The applied rules to inspect.
	 *
	 * @return `true` when at least one applied rule is active.
	 */
	private static Boolean hasActiveRule(List<DTO_AppliedRule> appliedRules)
	{
		for(DTO_AppliedRule appliedRule : appliedRules)
		{
			if(appliedRule.isActive == true)
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * @description Reports whether a field analysis carries any active masking — an active object-wide
	 * rule, or an active target applied to any field — so the coverage assessment can treat the object
	 * as covered and skip field flagging. Precondition: the analysis must come from a resolvable object
	 * (`describeFields`' unresolvable-object early return leaves `objectWideRules` null); the caller
	 * guards the object name before describing.
	 *
	 * @param analysis The field analysis to inspect.
	 *
	 * @return `true` when at least one active masking target covers the analyzed object.
	 */
	private static Boolean containsActiveMasking(DTO_FieldAnalysis analysis)
	{
		if(hasActiveRule(analysis.objectWideRules))
		{
			return true;
		}
		for(DTO_FieldRow row : analysis.fields)
		{
			if(hasActiveRule(row.appliedRules))
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * @description Maps the candidate rules into the catalogue the console renders — one `DTO_RuleOption`
	 * per rule carrying its developer name, label, category hint, mode, active state, applicable field
	 * types, and description — so the rule chips, the type filter, and the rule-detail popup read from rule
	 * metadata without a hardcoded map or a second round-trip. A rule another rule's `Replaces__c` names
	 * carries the supersession annotation so the picker steers the admin to the successor.
	 *
	 * @param rules The candidate rules.
	 * @param successorLabelByReplacedName Successor label keyed by qualified replaced-rule name.
	 *
	 * @return One catalogue entry per rule.
	 */
	private static List<DTO_RuleOption> buildRuleCatalogue(List<MaskingRule__mdt> rules, Map<String, String> successorLabelByReplacedName)
	{
		List<DTO_RuleOption> catalogue = new List<DTO_RuleOption>();
		for(MaskingRule__mdt rule : rules)
		{
			DTO_RuleOption option = new DTO_RuleOption();
			option.developerName = rule.DeveloperName;
			option.label = rule.MasterLabel;
			option.category = rule.Category__c;
			option.mode = rule.Mode__c;
			option.isActive = rule.IsActive__c == true;
			option.applicableFieldTypes = parseApplicableFieldTypes(rule);
			option.description = rule.Description__c;
			option.supersededByLabel = resolveSupersededAnnotation(rule, successorLabelByReplacedName);
			catalogue.add(option);
		}
		return catalogue;
	}

	/**
	 * @description Resolves one SObject's existing masking from **all** its targets — active and inactive —
	 * read through `findAllForSObjectType`. Returns every field's applied targets keyed by lowercased field
	 * API name plus the object-wide applied targets. The advisor renders the applied targets as checkbox
	 * chips and re-emits them (flipped) in a disable / re-enable diff, so it must see the inactive ones too.
	 * A target's field reference is a `FieldDefinition` durable Id in `Object.Field` form, so the field name
	 * is taken after the dot.
	 *
	 * @param sObjectType The object whose targets to resolve.
	 * @param successorLabelByReplacedName Successor label keyed by qualified replaced-rule name.
	 *
	 * @return The object's existing masking: applied rules by field and object-wide rules.
	 */
	private static ExistingMasking resolveExistingTargets(SObjectType sObjectType, Map<String, String> successorLabelByReplacedName)
	{
		Map<String, List<DTO_AppliedRule>> appliedByFieldLowerName = new Map<String, List<DTO_AppliedRule>>();
		List<DTO_AppliedRule> objectWideRules = new List<DTO_AppliedRule>();

		for(MaskingTarget__mdt target : new SEL_MaskingTarget().findAllForSObjectType(sObjectType))
		{
			DTO_AppliedRule applied = toAppliedRule(target, successorLabelByReplacedName);

			if(String.isBlank(target.Field__c))
			{
				objectWideRules.add(applied);
			}
			else
			{
				String fieldNameLowerCase = target.Field__c.substringAfter(UTIL_String.DOT).toLowerCase();
				if(!appliedByFieldLowerName.containsKey(fieldNameLowerCase))
				{
					appliedByFieldLowerName.put(fieldNameLowerCase, new List<DTO_AppliedRule>());
				}
				appliedByFieldLowerName.get(fieldNameLowerCase).add(applied);
			}
		}

		return new ExistingMasking(appliedByFieldLowerName, objectWideRules);
	}

	/**
	 * @description Maps one masking target to its `DTO_AppliedRule` chip — the target's developer name (the
	 * re-emit key), the target's own active state, the preserved caller-class scope, and the bound rule's
	 * developer name and label. The rule is resolved through `SEL_MaskingTarget.getRuleById`, which reads the
	 * selector's transaction rule cache (every rule, active and inactive, plus any mock-registered target's
	 * `Rule__r`). A target whose rule cannot be resolved keeps null rule metadata rather than throwing — the
	 * configuration-health surfacing flags it separately. A resolved rule another rule's `Replaces__c` names
	 * carries the supersession annotation — applied rows are annotated, never filtered, because the binding
	 * still actively masks until the admin rebinds it.
	 *
	 * @param target The masking target to map.
	 * @param successorLabelByReplacedName Successor label keyed by qualified replaced-rule name.
	 *
	 * @return The applied-rule chip for the target.
	 */
	private static DTO_AppliedRule toAppliedRule(MaskingTarget__mdt target, Map<String, String> successorLabelByReplacedName)
	{
		DTO_AppliedRule applied = new DTO_AppliedRule();
		applied.targetDeveloperName = target.DeveloperName;
		applied.isActive = target.IsActive__c == true;
		applied.callerClass = target.CallerClass__c;

		MaskingRule__mdt rule = SEL_MaskingTarget.getRuleById(target.Rule__c);
		if(rule != null)
		{
			applied.ruleDeveloperName = rule.DeveloperName;
			applied.ruleLabel = rule.MasterLabel;
			applied.ruleIsActive = rule.IsActive__c == true;
			applied.supersededByLabel = resolveSupersededAnnotation(rule, successorLabelByReplacedName);
		}
		return applied;
	}

	/**
	 * @description Builds the absolute URL that opens the New Masking Rule form in Setup. The org domain is
	 * resolved at request time the same way the Health Check does (`Url.getOrgDomainUrl`), the object name
	 * comes from `UTIL_SObjectDescribe` (namespace-aware — `kern__MaskingRule__mdt` in a subscriber org),
	 * and the `MaskingRule__mdt` key prefix is resolved dynamically (never hardcoded — it differs per
	 * packaging context). The CMDT record-create address is URL-encoded so the console can navigate to it as
	 * a `standard__webPage`.
	 *
	 * @return The absolute New-Masking-Rule Setup URL.
	 */
	private static String buildNewRuleSetupUrl()
	{
		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(MaskingRule__mdt.SObjectType);
		String keyPrefix = UTIL_SObjectDescribe.getDescribe(MaskingRule__mdt.SObjectType).getDescribe().keyPrefix;
		String recordCreateAddress = '/' + keyPrefix + '/e?sObjectName=' + objectName;

		return Url.getOrgDomainUrl().toExternalForm() + '/lightning/setup/CustomMetadata/page?address=' + EncodingUtil.urlEncode(recordCreateAddress, 'UTF-8');
	}

	/**
	 * @description Builds one field row, overlaying native classification when present and otherwise
	 * applying the name/type heuristic, and attaching the field's existing applied targets. A recommended
	 * rule is set when any candidate's stem substring-matches the field's API name.
	 *
	 * @param fieldApiName The field API name.
	 * @param fieldInformation The shared display metadata (label, type) for the field.
	 * @param context Shared per-SObject analysis inputs — classification map, existing applied targets, and
	 * recommendation candidates pre-sorted by stem length descending.
	 *
	 * @return The populated field row.
	 */
	private static DTO_FieldRow buildFieldRow(String fieldApiName, UTIL_SObjectDescribe.DTO_FieldInformation fieldInformation, FieldAnalysisContext context)
	{
		DTO_FieldRow row = new DTO_FieldRow();
		FieldDefinition classification = context.classificationByFieldName.get(fieldApiName.toLowerCase());

		row.apiName = fieldApiName;
		row.label = fieldInformation.fieldLabel;
		row.type = fieldInformation.fieldType;
		row.appliedRules = context.existing.appliedRulesFor(fieldApiName.toLowerCase());
		row.isClassified = classification != null && (String.isNotBlank(classification.SecurityClassification) || String.isNotBlank(classification.ComplianceGroup));

		DisplayType fieldType = DisplayType.valueOf(fieldInformation.fieldType);

		HeuristicConfidence confidence = null;
		if(row.isClassified)
		{
			row.securityClassification = classification.SecurityClassification;
			row.complianceGroup = classification.ComplianceGroup;
		}
		else
		{
			confidence = evaluateHeuristic(fieldApiName, fieldType);
			row.heuristicConfidence = confidence?.name();
		}

		List<RuleMatch> matches = resolveRuleMatches(fieldApiName, fieldType, context.recommendationCandidates);
		RuleMatch primaryMatch = matches.isEmpty() ? NO_MATCH : matches[0];
		row.recommendedRules = new List<DTO_RecommendedRule>();
		for(RuleMatch matched : matches)
		{
			row.recommendedRules.add(toRecommendedRule(matched.rule));
		}
		if(primaryMatch.rule != null)
		{
			row.recommendedRuleDeveloperName = primaryMatch.rule.DeveloperName;
			row.recommendedRuleLabel = primaryMatch.rule.MasterLabel;
			row.recommendedRuleIsActive = primaryMatch.rule.IsActive__c == true;
		}

		row.applicableRuleDeveloperNames = context.applicableRuleNamesFor(fieldType);
		row.matchStrength = resolveMatchStrength(primaryMatch.provenance, fieldType);
		row.sensitivityLevel = resolveSensitivityLevel(row.isClassified, confidence, primaryMatch.rule != null);
		row.likelyMiss = likelyMiss(row.sensitivityLevel, fieldType);

		row.exampleInput = exampleInputForType(fieldType);
		if(row.exampleInput != null && primaryMatch.rule != null)
		{
			SObjectField fieldToken = resolveField(context.sObjectType, fieldApiName);
			row.exampleOutput = UTIL_FrameworkMasker.maskValueAgainstRule(fieldToken, primaryMatch.rule, row.exampleInput).maskedValue;
		}

		return row;
	}

	/**
	 * @description Maps a matched masking rule to the `DTO_RecommendedRule` the console pre-ticks as a
	 * Field-level candidate — its developer name, label, and active state.
	 *
	 * @param rule The matched rule.
	 *
	 * @return The recommended-rule DTO.
	 */
	private static DTO_RecommendedRule toRecommendedRule(MaskingRule__mdt rule)
	{
		DTO_RecommendedRule recommended = new DTO_RecommendedRule();
		recommended.developerName = rule.DeveloperName;
		recommended.label = rule.MasterLabel;
		recommended.isActive = rule.IsActive__c == true;
		return recommended;
	}

	/**
	 * @description Returns a synthetic, clearly-fictional example input for a field's `DisplayType` — an
	 * email for EMAIL, a US phone for PHONE, a basic-auth URL for URL — or `null` for any other type,
	 * including the undefined-shape text types (STRING/TEXTAREA/ENCRYPTEDSTRING) whose content has no
	 * single representative shape. The map is per type (not per rule), so it is neither a per-rule guess
	 * nor a subscriber authoring burden.
	 *
	 * @param fieldType The field's `DisplayType`.
	 *
	 * @return The synthetic example input, or `null` when the type has no well-defined shape.
	 */
	@TestVisible
	private static String exampleInputForType(DisplayType fieldType)
	{
		if(fieldType == DisplayType.EMAIL)
		{
			return EXAMPLE_INPUT_EMAIL;
		}
		if(fieldType == DisplayType.PHONE)
		{
			return EXAMPLE_INPUT_PHONE;
		}
		if(fieldType == DisplayType.URL)
		{
			return EXAMPLE_INPUT_URL;
		}
		return null;
	}

	/**
	 * @description Pre-computes, once per analysis, the developer names of every candidate rule whose type
	 * scope admits each maskable `DisplayType` — the rules the per-field rule picker may offer. Each rule's
	 * `ApplicableFieldTypes__c` scope is parsed a single time (rather than re-split for every field on the
	 * object), then bucketed under each type it admits, so a field row resolves its applicable rules with a
	 * single map lookup. A rule with a blank scope is unscoped and admitted by every maskable type. Within
	 * each type's list the names keep candidate order (stem length descending).
	 *
	 * @param candidates The candidate rules.
	 *
	 * @return Maskable `DisplayType` to the applicable rule developer names for that type.
	 */
	private static Map<DisplayType, List<String>> applicableRuleNamesByType(List<MaskingRule__mdt> candidates)
	{
		Map<DisplayType, List<String>> namesByType = new Map<DisplayType, List<String>>();
		for(DisplayType maskableType : RECOMMENDABLE_FIELD_TYPES)
		{
			namesByType.put(maskableType, new List<String>());
		}
		for(MaskingRule__mdt candidate : candidates)
		{
			Set<String> scopedTypeNames = parseApplicableTypeNames(candidate);
			for(DisplayType maskableType : RECOMMENDABLE_FIELD_TYPES)
			{
				if(scopedTypeNames.isEmpty() || scopedTypeNames.contains(maskableType.name()))
				{
					namesByType.get(maskableType).add(candidate.DeveloperName);
				}
			}
		}
		return namesByType;
	}

	/**
	 * @description Parses a rule's `ApplicableFieldTypes__c` scope into a set of upper-cased `DisplayType`
	 * names. An empty set means the rule is unscoped — it applies to any maskable text-shaped field. Derived
	 * from {@see parseApplicableFieldTypes} so the split/trim/upper-case logic lives in one place.
	 *
	 * @param rule The candidate rule.
	 *
	 * @return The upper-cased type names the rule is scoped to, or an empty set when unscoped.
	 */
	private static Set<String> parseApplicableTypeNames(MaskingRule__mdt rule)
	{
		return new Set<String>(parseApplicableFieldTypes(rule));
	}

	/**
	 * @description Parses a rule's `ApplicableFieldTypes__c` scope into a list of upper-cased `DisplayType`
	 * names, splitting the semicolon-separated value, trimming each entry, and dropping blanks. An empty
	 * list means the rule is unscoped — it applies to any maskable text-shaped field. Surfaced on the rule
	 * catalogue so the console can filter a rule's chips to the fields whose type it admits.
	 *
	 * @param rule The candidate rule.
	 *
	 * @return The upper-cased type names the rule is scoped to, or an empty list when unscoped.
	 */
	private static List<String> parseApplicableFieldTypes(MaskingRule__mdt rule)
	{
		List<String> typeNames = new List<String>();
		if(String.isBlank(rule.ApplicableFieldTypes__c))
		{
			return typeNames;
		}
		for(String typeName : rule.ApplicableFieldTypes__c.split(UTIL_String.SEMI_COLON))
		{
			if(String.isNotBlank(typeName))
			{
				typeNames.add(typeName.trim().toUpperCase());
			}
		}
		return typeNames;
	}

	/**
	 * @description Evaluates the name/type heuristic for a field with no native classification, returning a
	 * coarse confidence tier or `null` when nothing matches. Pure logic — no describe, no SOQL.
	 *
	 * @param fieldApiName The field API name to inspect.
	 * @param fieldType The field's DisplayType. `null` falls through to name-pattern-only matching.
	 *
	 * @return The confidence tier, or `null` when the field is not a heuristic match.
	 */
	@TestVisible
	private static HeuristicConfidence evaluateHeuristic(String fieldApiName, DisplayType fieldType)
	{
		List<String> nameTokens = tokenizeFieldName(fieldApiName);

		Boolean emailMatch = fieldType == DisplayType.EMAIL && nameMatchesConcept(nameTokens, 'email');
		Boolean phoneMatch = fieldType == DisplayType.PHONE && (nameMatchesConcept(nameTokens, 'phone') || nameMatchesConcept(nameTokens, 'mobile'));

		if(containsAnyConcept(nameTokens, HIGH_CONFIDENCE_NAME_PATTERNS) || emailMatch || phoneMatch)
		{
			return HeuristicConfidence.HIGH;
		}

		if(fieldType == DisplayType.EMAIL || fieldType == DisplayType.PHONE || containsAnyConcept(nameTokens, MEDIUM_CONFIDENCE_NAME_PATTERNS))
		{
			return HeuristicConfidence.MEDIUM;
		}

		if(containsAnyConcept(nameTokens, LOW_CONFIDENCE_NAME_PATTERNS))
		{
			return HeuristicConfidence.LOW;
		}

		return null;
	}

	/**
	 * @description Returns true when any of the supplied concepts matches the field's name tokens at a token
	 * boundary (see `nameMatchesConcept`). Token-aware so a multi-letter pattern that only appears as an
	 * accidental cross-word substring — `ssn` inside `claSSNAme` — never fires.
	 *
	 * @param nameTokens The field API name's lowercased tokens.
	 * @param concepts The concept substrings to look for.
	 *
	 * @return True when any concept matches the tokens at a boundary.
	 */
	private static Boolean containsAnyConcept(List<String> nameTokens, Set<String> concepts)
	{
		for(String concept : concepts)
		{
			if(nameMatchesConcept(nameTokens, concept))
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * @description Splits a field API name into lowercased word tokens on underscore, camelCase, acronym, and
	 * letter↔digit boundaries, after stripping a trailing custom suffix (`__c`, `__r`, …). `EmailAddress__c`
	 * tokenises to (`email`, `address`); `ClassName__c` to (`class`, `name`); `Customer_SSN__c` to
	 * (`customer`, `ssn`); `BankSwiftCode__c` to (`bank`, `swift`, `code`). Pure string logic — no describe.
	 *
	 * @param fieldApiName The field API name to tokenise.
	 *
	 * @return The lowercased word tokens, or an empty list when the name is blank.
	 */
	private static List<String> tokenizeFieldName(String fieldApiName)
	{
		List<String> tokens = new List<String>();
		if(String.isBlank(fieldApiName))
		{
			return tokens;
		}
		String spaced = fieldApiName.replaceAll('__[A-Za-z]+$', UTIL_String.EMPTY)
				.replaceAll('([a-z0-9])([A-Z])', '$1 $2')
				.replaceAll('([A-Z]+)([A-Z][a-z])', '$1 $2')
				.replaceAll('([A-Za-z])([0-9])', '$1 $2')
				.replaceAll('([0-9])([A-Za-z])', '$1 $2');
		for(String piece : spaced.split('[^A-Za-z0-9]+'))
		{
			if(String.isNotBlank(piece))
			{
				tokens.add(piece.toLowerCase());
			}
		}
		return tokens;
	}

	/**
	 * @description Returns true when a concept matches the field-name tokens at a meaningful boundary — either
	 * the concept sits inside a SINGLE token (so a sensitive identifier glued into one un-separated token,
	 * like `ssn` inside `ssnvalue`, still matches, preserving recall for names that carry no camelCase or
	 * underscore boundary) OR the concept equals a run of consecutive whole tokens (so `swiftcode` matches the
	 * run `swift`+`code`, and `socialsecurity` matches `social`+`security`). What it rejects is a concept that
	 * would have to SPAN a token boundary without filling it — `ssn` does NOT match (`class`, `name`), because
	 * it neither sits inside one token nor equals a whole-token run. This is the single boundary-aware
	 * primitive the heuristic, the stem resolver, and the synonym fallback all consult, so all three reject
	 * accidental cross-word substrings (`claSSNAme`) the same way.
	 *
	 * @param nameTokens The field API name's lowercased tokens.
	 * @param concept The concept (rule stem, synonym token, or heuristic pattern) to test.
	 *
	 * @return True when the concept sits within one token or equals a consecutive-token run.
	 */
	private static Boolean nameMatchesConcept(List<String> nameTokens, String concept)
	{
		if(String.isBlank(concept) || nameTokens.isEmpty())
		{
			return false;
		}
		for(String token : nameTokens)
		{
			if(token.contains(concept))
			{
				return true;
			}
		}
		for(Integer start = 0; start < nameTokens.size(); start++)
		{
			String run = nameTokens[start];
			for(Integer offset = start + 1; offset < nameTokens.size(); offset++)
			{
				run += nameTokens[offset];
				if(run == concept)
				{
					return true;
				}
				if(run.length() >= concept.length())
				{
					break;
				}
			}
		}
		return false;
	}

	/**
	 * @description Sorts candidate rules by stem length descending so the most specific name match
	 * resolves first when picking a recommendation. Rules without a `Mask` prefix keep their full
	 * developer name as the stem. Equal-length stems preserve their input order.
	 *
	 * @param rules The candidate rules.
	 *
	 * @return A new list of the candidates, sorted by stem length descending.
	 */
	private static List<MaskingRule__mdt> sortedRecommendationCandidates(List<MaskingRule__mdt> rules)
	{
		return UTIL_List.sort(new List<MaskingRule__mdt>(rules), new MaskingRuleStemLengthComparator());
	}

	/**
	 * @description Resolves the best-match recommended rule for a field by substring-matching the
	 * field's API name against the candidate rules' stems. A rule is only recommended on a field whose
	 * `DisplayType` is one the framework can actually mask (text-shaped — see `RECOMMENDABLE_FIELD_TYPES`);
	 * this gate stops a rule from being recommended on a Boolean/Date/etc. it could never apply to. Active
	 * rules are preferred over dormant rules so an admin sees a healthy configuration first; among rules
	 * of the same active state, the longest stem wins (most specific match). When no stem matches, a
	 * field-name synonym map (`FIELD_NAME_RULE_SYNONYMS`) is consulted as a fallback so common names a
	 * rule's own stem never reaches (for example `MailingStreet` → `MaskAddress`) still resolve. Returns
	 * `null` when neither a stem nor a synonym matches, or when the field type is not maskable.
	 *
	 * @param fieldApiName The field API name to recommend for.
	 * @param fieldType The field's `DisplayType`; `null` skips the type gate (matches on name alone).
	 * @param candidates The candidate rules, pre-sorted by stem length descending.
	 *
	 * @return The recommended rule, or `null` when nothing matches or the field type is not maskable.
	 */
	@TestVisible
	private static MaskingRule__mdt resolveRecommendedRule(String fieldApiName, DisplayType fieldType, List<MaskingRule__mdt> candidates)
	{
		return resolveRuleMatch(fieldApiName, fieldType, candidates).rule;
	}

	/**
	 * @description Resolves the single primary recommended rule for a field together with the provenance of
	 * the match (direct stem, alias, synonym, or none) so callers can derive an honest match-strength signal.
	 * The primary is the first of {@see resolveRuleMatches} — the first active stem/alias match, or the first
	 * dormant one when none is active, or the synonym fallback — so the match-strength band and sensitivity
	 * coupling read from the strongest of a field's concept matches.
	 *
	 * @param fieldApiName The field API name to recommend for.
	 * @param fieldType The field's `DisplayType`; `null` skips the type gate.
	 * @param candidates The candidate rules, pre-sorted by stem length descending.
	 *
	 * @return The primary match — `rule` is `null` with `NONE` provenance when nothing matches.
	 */
	private static RuleMatch resolveRuleMatch(String fieldApiName, DisplayType fieldType, List<MaskingRule__mdt> candidates)
	{
		List<RuleMatch> matches = resolveRuleMatches(fieldApiName, fieldType, candidates);
		return matches.isEmpty() ? NO_MATCH : matches[0];
	}

	/**
	 * @description Resolves EVERY concept-matched rule for a field, in resolution priority — the multi-mask
	 * recommendation a field row pre-ticks. Applies the same gates as {@see resolveRuleMatch}: a blank name or
	 * empty candidate set, or a non-maskable field type, yields no matches. Otherwise it collects all stem/
	 * alias matches (active rules first, longest stem first within each group) so a field whose name two rules
	 * both stem/alias-match yields both — a `Phone` field surfaces both the US and the international phone
	 * rule. Only when no stem/alias matches does it fall back to the single field-name synonym match, returned
	 * as a one-element list. The first element is the primary {@see resolveRuleMatch} returns.
	 *
	 * @param fieldApiName The field API name to recommend for.
	 * @param fieldType The field's `DisplayType`; `null` skips the type gate.
	 * @param candidates The candidate rules, pre-sorted by stem length descending.
	 *
	 * @return The matches in priority order — empty when nothing matches or the field type is not maskable.
	 */
	private static List<RuleMatch> resolveRuleMatches(String fieldApiName, DisplayType fieldType, List<MaskingRule__mdt> candidates)
	{
		if(String.isBlank(fieldApiName) || candidates == null || candidates.isEmpty())
		{
			return new List<RuleMatch>();
		}
		if(fieldType != null && !RECOMMENDABLE_FIELD_TYPES.contains(fieldType))
		{
			return new List<RuleMatch>();
		}
		List<String> nameTokens = tokenizeFieldName(fieldApiName);
		List<RuleMatch> stemMatches = resolveStemMatches(candidates, nameTokens);
		if(!stemMatches.isEmpty())
		{
			return promoteTypeConceptPrimary(stemMatches, fieldType);
		}
		RuleMatch synonymMatch = resolveSynonymMatch(candidates, nameTokens);
		return synonymMatch.rule == null ? new List<RuleMatch>() : new List<RuleMatch> {synonymMatch};
	}

	/**
	 * @description Re-ranks an EMAIL/PHONE field's concept matches (via `MatchRankComparator`) so the primary
	 * is a type-compatible rule — its stem carries the field's type concept — ahead of a longer but type-
	 * foreign match. An `EmailAddress` field's `email` rule beats the longer `address` match; a phone field's
	 * more-specific `accountphone` rule still beats the generic `phone` rule (both carry the `phone` concept);
	 * and the two phone rules order deterministically (international before US) regardless of candidate input
	 * order. Fields whose type has no single concept rule (`TYPE_PRIMARY_CONCEPT` has no entry) or with a
	 * single match are returned unchanged — they keep the longest-stem default.
	 *
	 * @param matches The concept matches in resolution priority (active-first, longest-stem-first).
	 * @param fieldType The field's `DisplayType`.
	 *
	 * @return The matches re-ranked so a type-compatible rule is primary, or unchanged.
	 */
	private static List<RuleMatch> promoteTypeConceptPrimary(List<RuleMatch> matches, DisplayType fieldType)
	{
		String typeConcept = fieldType == null ? null : TYPE_PRIMARY_CONCEPT.get(fieldType);
		if(typeConcept == null || matches.size() < 2)
		{
			return matches;
		}
		List<RuleMatch> ranked = new List<RuleMatch>(matches);
		ranked.sort(new MatchRankComparator(typeConcept));
		return ranked;
	}

	/**
	 * @description Collects every stem/alias match among the candidates, in resolution priority: active rules
	 * before dormant rules, and within each group longest-stem-first (the candidates arrive pre-sorted by stem
	 * length descending). So the first element is the same rule the old single-match resolver returned — the
	 * first active stem/alias match, or the first dormant one when none is active — and the remaining elements
	 * are the field's other concept matches (a phone field matches both phone rules). Returns an empty list
	 * when no candidate's stem (or alias) is a substring of the field name, signalling the synonym fallback.
	 *
	 * Because matching is substring-based, a compound field name that spans two concepts (e.g. a custom
	 * `EmailAddress__c`, whose name contains both the `email` and `address` stems) intentionally surfaces
	 * BOTH concept rules as pre-ticked candidates. This is deliberate: candidates are reviewed (and unticked)
	 * before export, never auto-applied, so surfacing every concept match is safer than silently dropping one.
	 * No shipped standard field name spans two stems; stem disambiguation (preferring the type-reinforced
	 * concept) is name-detection-quality work owned by the heuristic-pattern layer, not this resolver.
	 *
	 * @param candidates The candidate rules, pre-sorted by stem length descending.
	 * @param nameTokens The field API name's lowercased tokens.
	 *
	 * @return The stem/alias matches in priority order (active-first, longest-stem-first), or an empty list.
	 */
	private static List<RuleMatch> resolveStemMatches(List<MaskingRule__mdt> candidates, List<String> nameTokens)
	{
		List<RuleMatch> activeMatches = new List<RuleMatch>();
		List<RuleMatch> dormantMatches = new List<RuleMatch>();
		for(MaskingRule__mdt candidate : candidates)
		{
			RuleMatch candidateMatch = stemMatchFor(candidate, nameTokens);
			if(candidateMatch == null)
			{
				continue;
			}
			if(candidate.IsActive__c == true)
			{
				activeMatches.add(candidateMatch);
			}
			else
			{
				dormantMatches.add(candidateMatch);
			}
		}
		activeMatches.addAll(dormantMatches);
		return activeMatches;
	}

	/**
	 * @description Tests a single candidate's stem (and its alias, if any) against the field name and, on a
	 * substring hit, returns the match paired with its provenance — `DIRECT_STEM` when the rule's own stem
	 * matched directly, `ALIAS` when a {@see RULE_STEM_ALIASES} entry widened the stem to reach the field.
	 * Returns `null` when the candidate has no stem (a blank developer name) or its stem is not a substring
	 * of the field name. Provenance is decided in this one place so the caller never re-derives it.
	 *
	 * @param candidate The candidate rule to test.
	 * @param nameTokens The field API name's lowercased tokens.
	 *
	 * @return The match with its stem-based provenance, or `null` when the candidate does not match.
	 */
	private static RuleMatch stemMatchFor(MaskingRule__mdt candidate, List<String> nameTokens)
	{
		String rawStem = resolveRawRuleStem(candidate.DeveloperName);
		if(String.isBlank(rawStem))
		{
			return null;
		}
		String matchStem = RULE_STEM_ALIASES.containsKey(rawStem) ? RULE_STEM_ALIASES.get(rawStem) : rawStem;
		if(!nameMatchesConcept(nameTokens, matchStem))
		{
			return null;
		}
		MatchProvenance provenance = matchStem == rawStem ? MatchProvenance.DIRECT_STEM : MatchProvenance.ALIAS;
		return new RuleMatch(candidate, provenance);
	}

	/**
	 * @description Resolves the field-name synonym fallback, run only when no stem/alias match was found.
	 * Wraps {@see resolveSynonymRule} (which is namespace-aware, so it resolves the package's own rule and
	 * never a subscriber same-named one) and pairs the result with `SYNONYM` provenance, returning the
	 * shared {@see NO_MATCH} sentinel when no synonym resolves.
	 *
	 * @param candidates The candidate rules.
	 * @param nameTokens The field API name's lowercased tokens.
	 *
	 * @return The synonym match with `SYNONYM` provenance, or `NO_MATCH` when no synonym resolves.
	 */
	private static RuleMatch resolveSynonymMatch(List<MaskingRule__mdt> candidates, List<String> nameTokens)
	{
		MaskingRule__mdt synonymRule = resolveSynonymRule(nameTokens, candidates);
		return synonymRule == null ? NO_MATCH : new RuleMatch(synonymRule, MatchProvenance.SYNONYM);
	}

	/**
	 * @description How a rule matched a field — the source of the match-strength band. `DIRECT_STEM` and
	 * `ALIAS` are name-stem matches (the latter via `RULE_STEM_ALIASES`); `SYNONYM` is a synonym-map
	 * match; `NONE` means no rule matched.
	 */
	private enum MatchProvenance
	{
		DIRECT_STEM,
		ALIAS,
		SYNONYM,
		NONE
	}

	/**
	 * @description A resolved rule recommendation paired with the provenance of how it matched, so the
	 * field row can render an honest match-strength band without re-deriving the match.
	 */
	private class RuleMatch
	{
		/**
		 * @description The matched rule, or `null` when nothing matched.
		 */
		private final MaskingRule__mdt rule;

		/**
		 * @description How the rule matched, or `NONE` when nothing matched.
		 */
		private final MatchProvenance provenance;

		/**
		 * @description Constructs a rule match.
		 *
		 * @param rule The matched rule, or `null` when nothing matched.
		 * @param provenance How the rule matched (or `NONE`).
		 */
		private RuleMatch(MaskingRule__mdt rule, MatchProvenance provenance)
		{
			this.rule = rule;
			this.provenance = provenance;
		}
	}

	/**
	 * @description Ranks a field's concept matches so the primary recommendation is right for the field type
	 * and deterministic. Order, highest priority first: (1) a rule whose raw stem CARRIES the field's type
	 * concept — `email` for an EMAIL field, `phone` for a PHONE field — outranks a type-foreign match, so an
	 * `EmailAddress` field's `email` rule beats the longer `address` match, while a phone-concept rule like
	 * `accountphone` (whose stem still contains `phone`) keeps its place; (2) active rules before dormant; (3)
	 * the longer (more specific) stem; (4) developer name ascending, so the two phone rules (international
	 * before US) resolve identically every run regardless of candidate order. Built per field with the type
	 * concept.
	 */
	private class MatchRankComparator implements System.Comparator<RuleMatch>
	{
		/**
		 * @description The field's type concept (`email`/`phone`) a matched rule's stem must carry to rank
		 * as type-compatible.
		 */
		private final String typeConcept;

		/**
		 * @description Constructs the comparator for a field's type concept.
		 *
		 * @param typeConcept The field's type concept (`email`/`phone`).
		 */
		private MatchRankComparator(String typeConcept)
		{
			this.typeConcept = typeConcept;
		}

		/**
		 * @description Compares two matches by type-concept compatibility, then active state, then stem
		 * length, then developer name — each descending in priority except the name tiebreak (ascending).
		 *
		 * @param firstMatch The first match to compare.
		 * @param secondMatch The second match to compare.
		 *
		 * @return Negative when `firstMatch` ranks ahead, positive when behind, zero when equal.
		 */
		public Integer compare(RuleMatch firstMatch, RuleMatch secondMatch)
		{
			Integer byCompatibility = rankCompatibility(secondMatch) - rankCompatibility(firstMatch);
			if(byCompatibility != 0)
			{
				return byCompatibility;
			}
			Integer byActive = rankActive(secondMatch) - rankActive(firstMatch);
			if(byActive != 0)
			{
				return byActive;
			}
			Integer byStemLength = resolveRuleStem(secondMatch.rule.DeveloperName).length() - resolveRuleStem(firstMatch.rule.DeveloperName).length();
			if(byStemLength != 0)
			{
				return byStemLength;
			}
			return firstMatch.rule.DeveloperName.compareTo(secondMatch.rule.DeveloperName);
		}

		/**
		 * @description Ranks a match 1 when its raw stem carries the field's type concept, else 0.
		 *
		 * @param match The match to rank.
		 *
		 * @return 1 when type-compatible, else 0.
		 */
		private Integer rankCompatibility(RuleMatch match)
		{
			return resolveRawRuleStem(match.rule.DeveloperName).contains(typeConcept) ? 1 : 0;
		}

		/**
		 * @description Ranks a match 1 when its rule is active, else 0.
		 *
		 * @param match The match to rank.
		 *
		 * @return 1 when active, else 0.
		 */
		private Integer rankActive(RuleMatch match)
		{
			return match.rule.IsActive__c == true ? 1 : 0;
		}
	}

	/**
	 * @description Derives the match-strength band from the match provenance and the field's type. No
	 * match is `Weak` (the floor — no positive name signal); a synonym match is `Moderate`; a stem/alias
	 * match is `Strong` only when the type reinforces it (`TYPE_REINFORCING_FIELD_TYPES`), otherwise
	 * `Moderate` (a name match on a generic STRING/TEXTAREA the type does not reinforce).
	 *
	 * @param provenance How the rule matched.
	 * @param fieldType The field's `DisplayType`.
	 *
	 * @return The `Weak`/`Moderate`/`Strong` band literal.
	 */
	private static String resolveMatchStrength(MatchProvenance provenance, DisplayType fieldType)
	{
		if(provenance == MatchProvenance.NONE)
		{
			return MATCH_STRENGTH_WEAK;
		}
		if(provenance == MatchProvenance.SYNONYM)
		{
			return MATCH_STRENGTH_MODERATE;
		}
		return TYPE_REINFORCING_FIELD_TYPES.contains(fieldType) ? MATCH_STRENGTH_STRONG : MATCH_STRENGTH_MODERATE;
	}

	/**
	 * @description Maps a field's classification, heuristic signal, and whether a masking rule was
	 * recommended onto the sensitivity-level axis. A natively classified field or a `HIGH` heuristic is
	 * `Sensitive`. A `MEDIUM`/`LOW` heuristic — or any field the resolver recommended a rule for, even
	 * when the PII heuristic found nothing — is `PossiblySensitive`: recommending masking is itself a
	 * sensitivity signal, so a recommended field is never `NotSensitive` (this is the coupling that stops
	 * a field like `MailingStreet` reading "recommended to mask" yet "Not sensitive"). Everything else is
	 * `NotSensitive`.
	 *
	 * @param isClassified Whether the field carries a native classification.
	 * @param confidence The heuristic confidence tier, or `null` when there is no heuristic signal.
	 * @param hasRecommendation Whether the resolver recommended a masking rule for the field.
	 *
	 * @return The `Sensitive`/`PossiblySensitive`/`NotSensitive` level literal.
	 */
	@TestVisible
	private static String resolveSensitivityLevel(Boolean isClassified, HeuristicConfidence confidence, Boolean hasRecommendation)
	{
		if(isClassified == true || confidence == HeuristicConfidence.HIGH)
		{
			return SENSITIVITY_SENSITIVE;
		}
		if(confidence == HeuristicConfidence.MEDIUM || confidence == HeuristicConfidence.LOW || hasRecommendation == true)
		{
			return SENSITIVITY_POSSIBLY_SENSITIVE;
		}
		return SENSITIVITY_NOT_SENSITIVE;
	}

	/**
	 * @description Flags a "likely miss": a field the advisor left `NotSensitive` (so it lands in the
	 * console's "Other" section) whose `DisplayType` structurally signals sensitive content — the same
	 * type-reinforcing set (`TYPE_REINFORCING_FIELD_TYPES`) that promotes a name match to `Strong`. In
	 * practice these are URL or encrypted-string fields that slipped past name/heuristic matching (email
	 * and phone types always escalate to at least a `MEDIUM` heuristic, so they never reach `NotSensitive`).
	 * Recommending or flagging a field already surfaces it, so a non-`NotSensitive` field is never a miss.
	 *
	 * @param sensitivityLevelLiteral The resolved sensitivity level literal.
	 * @param fieldType The field's `DisplayType`.
	 *
	 * @return True when the field is a likely miss worth a second look.
	 */
	@TestVisible
	private static Boolean likelyMiss(String sensitivityLevelLiteral, DisplayType fieldType)
	{
		return SENSITIVITY_NOT_SENSITIVE.equals(sensitivityLevelLiteral) && TYPE_REINFORCING_FIELD_TYPES.contains(fieldType);
	}

	/**
	 * @description Resolves a recommended rule from the field-name synonym map when the substring-stem
	 * match found nothing. Tokens are consulted in a deterministic (alphabetical) order; the first token
	 * that is a substring of the field name resolves to its mapped rule, when that rule is among the
	 * candidates. Returns `null` when no synonym matches or the mapped rule is not present. Callers run
	 * the type gate first, so this never fires on a non-recommendable type.
	 *
	 * @param nameTokens The field API name's lowercased tokens.
	 * @param candidates The candidate rules.
	 *
	 * @return The synonym-matched rule, or `null` when nothing matches.
	 */
	private static MaskingRule__mdt resolveSynonymRule(List<String> nameTokens, List<MaskingRule__mdt> candidates)
	{
		List<String> tokens = new List<String>(FIELD_NAME_RULE_SYNONYMS.keySet());
		tokens.sort();
		for(String token : tokens)
		{
			if(nameMatchesConcept(nameTokens, token))
			{
				MaskingRule__mdt match = findCandidateByDeveloperName(candidates, FIELD_NAME_RULE_SYNONYMS.get(token));
				if(match != null)
				{
					return match;
				}
			}
		}
		return null;
	}

	/**
	 * @description Returns the framework's *own* rule with the given developer name, or `null` when the
	 * package ships no such rule. The synonym map hardcodes framework rule names, so this resolves
	 * namespace-aware: in a subscriber org a subscriber may author a `MaskingRule__mdt` with the same
	 * developer name as one of ours, and both appear in `getAll()` with the same (namespace-stripped)
	 * `DeveloperName`. Matching on developer name **and** package ownership (`NamespacePrefix` equals the
	 * running package namespace) guarantees a synonym resolves to our rule, never a subscriber's
	 * same-named one.
	 *
	 * @param candidates The candidate rules.
	 * @param developerName The framework rule developer name to find.
	 *
	 * @return The package-owned rule with that developer name, or `null`.
	 */
	private static MaskingRule__mdt findCandidateByDeveloperName(List<MaskingRule__mdt> candidates, String developerName)
	{
		for(MaskingRule__mdt candidate : candidates)
		{
			if(candidate.DeveloperName == developerName && isPackageOwnedRule(candidate))
			{
				return candidate;
			}
		}
		return null;
	}

	/**
	 * @description Whether a rule belongs to the framework's own package (rather than a subscriber). True
	 * when the record's `NamespacePrefix` equals the running package namespace — treating blank and null
	 * as equivalent so the unmanaged dev-org case (no namespace) and the managed subscriber case (the
	 * package namespace) both resolve correctly.
	 *
	 * @param rule The rule to test.
	 *
	 * @return True when the rule is owned by the running package.
	 */
	private static Boolean isPackageOwnedRule(MaskingRule__mdt rule)
	{
		return namespaceMatchesRunningPackage(UTIL_System.getManagedPackageNamespace(), rule.NamespacePrefix);
	}

	/**
	 * @description Whether a rule's `NamespacePrefix` identifies it as owned by the running package, given
	 * the running package namespace. Blank and null are treated as equivalent, so the unmanaged dev-org
	 * case (both blank) and the managed subscriber case (both the package namespace) each resolve true,
	 * while a subscriber's differently-namespaced same-named rule resolves false. Pure logic, split out
	 * from `isPackageOwnedRule` so both the unmanaged-blank and managed-namespace branches are directly
	 * testable without standing up a live managed package.
	 *
	 * @param packageNamespace The running package namespace (blank when unmanaged).
	 * @param ruleNamespace The rule record's `NamespacePrefix`.
	 *
	 * @return True when the rule belongs to the running package.
	 */
	@TestVisible
	private static Boolean namespaceMatchesRunningPackage(String packageNamespace, String ruleNamespace)
	{
		if(String.isBlank(packageNamespace))
		{
			return String.isBlank(ruleNamespace);
		}
		return packageNamespace == ruleNamespace;
	}

	/**
	 * @description Returns the lowercased stem of a rule developer name — the name minus the leading
	 * `Mask` prefix, or the full lowercased name when there is no prefix. A rule named `Foo` has stem
	 * `foo`; `MaskFoo` also has stem `foo`. A small alias map then widens qualified stems that no field
	 * name would contain (for example `MaskPhoneUS` → `phoneus` → `phone`) so common fields still match.
	 *
	 * @param developerName The rule developer name.
	 *
	 * @return The lowercased (and alias-resolved) stem, or empty when the developer name is blank.
	 */
	@TestVisible
	private static String resolveRuleStem(String developerName)
	{
		String stem = resolveRawRuleStem(developerName);
		return RULE_STEM_ALIASES.containsKey(stem) ? RULE_STEM_ALIASES.get(stem) : stem;
	}

	/**
	 * @description Returns the raw stem of a rule developer name — the name minus a leading `Mask`
	 * prefix, lowercased — without applying the alias map. The resolver uses this to tell a direct-stem
	 * match (raw == aliased) apart from an alias match (raw != aliased) for the match-strength band.
	 *
	 * @param developerName The rule developer name.
	 *
	 * @return The lowercased raw stem, or empty when the developer name is blank.
	 */
	private static String resolveRawRuleStem(String developerName)
	{
		if(String.isBlank(developerName))
		{
			return UTIL_String.EMPTY;
		}
		return (developerName.startsWithIgnoreCase('Mask') ? developerName.substring(4) : developerName).toLowerCase();
	}

	/**
	 * @description Sort comparator that orders candidate rules by stem length descending so the most
	 * specific name match resolves first. Extends the framework `SObjectComparator` so this class
	 * shares the project's sort-comparator base; the descending order is hand-rolled (no
	 * `sortAscending` toggle) because this comparator is single-purpose with one direction.
	 */
	private class MaskingRuleStemLengthComparator extends UTIL_Comparators.SObjectComparator
	{
		/**
		 * @description Compares two rule records by stem length descending — the longest stem sorts
		 * first so the resolver's first-match iteration picks the most specific recommendation.
		 *
		 * @param firstRule The first rule to compare.
		 * @param secondRule The second rule to compare.
		 *
		 * @return Negative when `firstRule` has the longer stem, positive when shorter, zero on tie.
		 */
		public override Integer compare(SObject firstRule, SObject secondRule)
		{
			Integer firstStemLength = resolveRuleStem(((MaskingRule__mdt)firstRule).DeveloperName).length();
			Integer secondStemLength = resolveRuleStem(((MaskingRule__mdt)secondRule).DeveloperName).length();
			return secondStemLength - firstStemLength;
		}
	}

	/**
	 * @description Masks a single typed value to preview how a field's masking rules transform it, with no
	 * data access at all — the administrator supplies a representative string. Mirrors the runtime engine via
	 * `UTIL_FrameworkMasker`, so a matched-rule result confirms the rule fires on the framework path.
	 *
	 * @param objectApiName The SObject API name (for example `Account`)
	 * @param fieldApiName The field API name (for example `Phone`)
	 * @param callerClass The caller-class scope to evaluate (blank means all callers)
	 * @param value The representative value to mask
	 *
	 * @return The masking preview, or `null` when the object or field cannot be resolved
	 */
	@AuraEnabled
	@SuppressWarnings('PMD.ExcessiveParameterList')
	public static DTO_MaskPreview previewTyped(String objectApiName, String fieldApiName, String callerClass, String value)
	{
		SObjectField field = resolveField(objectApiName, fieldApiName);
		if(field == null)
		{
			return null;
		}

		return toPreview(UTIL_FrameworkMasker.forField(field).calledFrom(callerClass).mask(value));
	}

	/**
	 * @description Previews what a specific named rule would redact on a field's value, even when no
	 * active MaskingTarget wires that rule to the field. Unlike {@see previewTyped} (which masks through
	 * the active configuration), this resolves the rule by developer name and applies it directly, so a
	 * reviewer can see a dormant rule's effect before activating it. Returns `null` when the object/field
	 * or the rule cannot be resolved.
	 *
	 * @param objectApiName The SObject API name (for example `Contact`).
	 * @param fieldApiName The field API name (for example `HomePhone`).
	 * @param ruleDeveloperName The developer name of the rule to preview (active or dormant).
	 * @param value The sample value to mask.
	 *
	 * @return The masking preview, or `null` when the field or rule cannot be resolved.
	 */
	@AuraEnabled
	@SuppressWarnings('PMD.ExcessiveParameterList')
	public static DTO_MaskPreview previewWithRule(String objectApiName, String fieldApiName, String ruleDeveloperName, String value)
	{
		SObjectField field = resolveField(objectApiName, fieldApiName);
		if(field == null)
		{
			return null;
		}

		MaskingRule__mdt rule = findRuleByDeveloperName(new SEL_MaskingTarget().getAllRulesById(), ruleDeveloperName);
		if(rule == null)
		{
			return null;
		}

		DTO_MaskPreview preview = toPreview(UTIL_FrameworkMasker.maskValueAgainstRule(field, rule, value));
		preview.expectsJsonInput = rule.Mode__c == SEL_MaskingRule.MODE_JSON_KEY;
		return preview;
	}

	/**
	 * @description Resolves the `SObjectField` token for an object/field API-name pair, or `null` when
	 * either does not resolve.
	 *
	 * @param objectApiName The SObject API name.
	 * @param fieldApiName The field API name.
	 *
	 * @return The field token, or `null` when unresolvable.
	 */
	private static SObjectField resolveField(String objectApiName, String fieldApiName)
	{
		SObjectType sObjectType = UTIL_SObjectDescribe.getSObjectTypeByName(objectApiName);
		return sObjectType == null ? null : resolveField(sObjectType, fieldApiName);
	}

	/**
	 * @description Resolves the `SObjectField` token for an already-resolved `SObjectType` and field API
	 * name, reusing the describe cached for the object, or `null` when the field does not resolve. The
	 * inline-example precompute calls this with the type the analysis already loaded so it never
	 * re-describes per row.
	 *
	 * @param sObjectType The resolved SObject type.
	 * @param fieldApiName The field API name.
	 *
	 * @return The field token, or `null` when unresolvable.
	 */
	private static SObjectField resolveField(SObjectType sObjectType, String fieldApiName)
	{
		UTIL_SObjectDescribe.FieldMetadata metadata = UTIL_SObjectDescribe.getDescribe(sObjectType).getFieldMetadata(fieldApiName);
		return metadata?.fieldDescribe.getSobjectField();
	}

	/**
	 * @description Maps a masking engine result into the preview DTO returned to the test bench.
	 *
	 * @param result The engine masking result.
	 *
	 * @return The populated preview.
	 */
	private static DTO_MaskPreview toPreview(UTIL_FrameworkMasker.MaskingResult result)
	{
		DTO_MaskPreview preview = new DTO_MaskPreview();
		preview.maskedValue = result.maskedValue;
		preview.matchedRuleDeveloperNames = result.matchedRuleDeveloperNames;
		preview.failedRuleDeveloperNames = result.failedRuleDeveloperNames;
		preview.hadErrors = result.hadErrors;
		preview.maskedLength = result.maskedLength;
		return preview;
	}

	/**
	 * @description Pulls a small, FLS-respected sample of real values for a field and masks each, so an
	 * administrator can confirm a rule fires against representative production data. Runs in user mode, so
	 * fields the running user cannot read are never sampled, and the sample is capped. The source value is
	 * returned alongside the masked value; the console shows the masked value by default and reveals the
	 * source only on explicit, per-row request by an authorised user.
	 *
	 * @param objectApiName The SObject API name (for example `Account`)
	 * @param fieldApiName The field API name (for example `Phone`)
	 * @param callerClass The caller-class scope to evaluate (blank means all callers)
	 *
	 * @return Up to `SAMPLE_LIMIT` masked rows (empty when the object or field cannot be resolved)
	 */
	@AuraEnabled
	public static List<DTO_MaskSample> sampleMasked(String objectApiName, String fieldApiName, String callerClass)
	{
		List<DTO_MaskSample> samples = new List<DTO_MaskSample>();

		SObjectField field = resolveField(objectApiName, fieldApiName);
		if(field == null)
		{
			return samples;
		}

		List<SObject> records = QRY_Builder.selectFrom(UTIL_SObjectDescribe.getSObjectTypeByName(objectApiName))
				.addField(field)
				.condition(field).notEquals((Object)null)
				.withUserMode()
				.withLimit(SAMPLE_LIMIT)
				.toList();

		UTIL_FrameworkMasker.FieldMasker masker = UTIL_FrameworkMasker.forField(field).calledFrom(callerClass);

		for(SObject record : records)
		{
			String sourceValue = String.valueOf(record.get(field));
			if(String.isBlank(sourceValue))
			{
				continue;
			}

			UTIL_FrameworkMasker.MaskingResult result = masker.mask(sourceValue);

			DTO_MaskSample sample = new DTO_MaskSample();
			sample.sourceValue = sourceValue;
			sample.maskedValue = result.maskedValue;
			sample.matchedRuleDeveloperNames = result.matchedRuleDeveloperNames;
			sample.hadErrors = result.hadErrors;
			samples.add(sample);
		}

		return samples;
	}

	/**
	 * @description Returns the active masking targets that currently reference a rule — the accurate
	 * blast radius shown before a subscriber activates a dormant rule. For a dormant rule this is empty
	 * today: a rule masks only where an active target wires it to a scope, so activating it touches only
	 * the target(s) being added now, while staying reusable for any target added later.
	 *
	 * @param ruleDeveloperName The rule whose referencing active targets to list.
	 *
	 * @return The blast radius (rule developer name plus the active targets referencing it).
	 */
	@AuraEnabled
	public static DTO_BlastRadius getBlastRadius(String ruleDeveloperName)
	{
		DTO_BlastRadius radius = new DTO_BlastRadius();
		radius.ruleDeveloperName = ruleDeveloperName;
		radius.activeTargetDeveloperNames = new List<String>();

		SEL_MaskingTarget selector = new SEL_MaskingTarget();
		Id ruleId = findRuleIdByDeveloperName(selector.getAllRulesById(), ruleDeveloperName);
		if(ruleId == null)
		{
			return radius;
		}

		for(MaskingTarget__mdt target : selector.getAllTargets())
		{
			if(target.IsActive__c == true && target.Rule__c == ruleId)
			{
				radius.activeTargetDeveloperNames.add(target.DeveloperName);
			}
		}

		return radius;
	}

	/**
	 * @description Finds the record Id of the rule with the given developer name.
	 *
	 * @param rulesById All rules keyed by Id.
	 * @param developerName The rule developer name to find.
	 *
	 * @return The rule's Id, or `null` when no rule has that developer name.
	 */
	private static Id findRuleIdByDeveloperName(Map<Id, MaskingRule__mdt> rulesById, String developerName)
	{
		return findRuleByDeveloperName(rulesById, developerName)?.Id;
	}

	/**
	 * @description Finds the rule with the given developer name among the supplied rules.
	 *
	 * @param rulesById All rules keyed by Id.
	 * @param developerName The rule developer name to find.
	 *
	 * @return The matching rule, or `null` when no rule has that developer name.
	 */
	private static MaskingRule__mdt findRuleByDeveloperName(Map<Id, MaskingRule__mdt> rulesById, String developerName)
	{
		for(MaskingRule__mdt rule : rulesById.values())
		{
			if(rule.DeveloperName == developerName)
			{
				return rule;
			}
		}
		return null;
	}

	/**
	 * @description Generates a deployment-neutral masking-configuration bundle from the administrator's
	 * field-to-rule decisions. Accepts a JSON string because Lightning does not support inner-class or
	 * list-of-inner-class deserialization for `@AuraEnabled` parameters. Produces inert text only — no DML,
	 * no Metadata API; the subscriber deploys the bundle with their own pipeline.
	 *
	 * @param requestJson JSON-serialized `DTO_GenerationRequest` from the UI.
	 *
	 * @return The bundle of relative file path to file body (empty when the input is blank).
	 */
	@AuraEnabled
	public static DTO_Bundle generateConfiguration(String requestJson)
	{
		if(String.isBlank(requestJson))
		{
			return new DTO_Bundle();
		}

		DTO_GenerationRequest request = (DTO_GenerationRequest)JSON.deserialize(requestJson, DTO_GenerationRequest.class);
		return request == null ? new DTO_Bundle() : generateConfiguration(request);
	}

	/**
	 * @description Typed implementation behind the `@AuraEnabled` JSON wrapper, also called directly by
	 * Apex callers. Renders one CustomMetadata file per chosen target, one activation file per dormant rule
	 * to activate, a `package.xml`, and a `README.md`.
	 *
	 * @param request The administrator's generation request.
	 *
	 * @return The deployment-neutral bundle.
	 */
	@TestVisible
	private static DTO_Bundle generateConfiguration(DTO_GenerationRequest request)
	{
		DTO_Bundle bundle = new DTO_Bundle();
		List<String> members = new List<String>();
		Map<String, MaskingRule__mdt> rulesByName = mapRulesByDeveloperName();

		for(DTO_TargetDecision decision : request.targets ?? new List<DTO_TargetDecision>())
		{
			String deployName = resolveRuleDeployName(rulesByName.get(decision.ruleDeveloperName), decision.ruleDeveloperName);
			bundle.files.put('metadata/customMetadata/' + TYPE_STEM_MASKING_TARGET + UTIL_String.DOT + decision.developerName + '.md-meta.xml', renderTargetXml(decision, deployName));
			members.add(TYPE_STEM_MASKING_TARGET + UTIL_String.DOT + decision.developerName);
		}

		for(String ruleName : request.rulesToActivate ?? new List<String>())
		{
			MaskingRule__mdt rule = rulesByName.get(ruleName);
			String deployName = resolveRuleDeployName(rule, ruleName);
			String label = rule?.MasterLabel ?? ruleName;
			bundle.files.put('metadata/customMetadata/' + TYPE_STEM_MASKING_RULE + UTIL_String.DOT + deployName + '.md-meta.xml', renderRuleActivationXml(label));
			members.add(TYPE_STEM_MASKING_RULE + UTIL_String.DOT + deployName);
		}

		bundle.files.put('metadata/package.xml', renderPackageXml(members));
		bundle.files.put('README.md', renderReadme(members));
		bundle.zipBase64 = encodeBundleAsBase64Zip(bundle.files);
		return bundle;
	}

	/**
	 * @description Packages every entry in `files` into a single zip archive using the platform-native
	 * `Compression.ZipWriter`, then base64-encodes the resulting bytes for transport over `@AuraEnabled`.
	 * The LWC decodes this to a `Blob('application/zip')` and triggers a one-click download — the admin
	 * gets a single deployable artifact rather than copy-pasting each file in turn.
	 *
	 * @param files Relative file path to file body for every entry to include in the archive.
	 *
	 * @return Base64-encoded zip archive.
	 */
	private static String encodeBundleAsBase64Zip(Map<String, String> files)
	{
		Compression.ZipWriter writer = new Compression.ZipWriter();
		for(String path : files.keySet())
		{
			writer.addEntry(path, Blob.valueOf(files.get(path)));
		}
		return EncodingUtil.base64Encode(writer.getArchive());
	}

	/**
	 * @description Maps every masking rule's developer name to its rule record, sourced through the selector
	 * so a shipped rule's activation preserves its label and the generator can qualify the rule's deployable
	 * name by the rule's own `NamespacePrefix`. When a subscriber authors a rule sharing a packaged rule's
	 * developer name, both appear under the same (namespace-stripped) developer name; the package-owned record
	 * wins — order-independently — so an activation resolves to the framework's rule, never the subscriber's
	 * same-named one. Unshipped names simply have no entry, and callers fall back to the requested name.
	 *
	 * @return Map of rule developer name to the preferred rule record.
	 */
	private static Map<String, MaskingRule__mdt> mapRulesByDeveloperName()
	{
		Map<String, MaskingRule__mdt> ruleByName = new Map<String, MaskingRule__mdt>();
		for(MaskingRule__mdt rule : new SEL_MaskingTarget().getAllRulesById().values())
		{
			MaskingRule__mdt existing = ruleByName.get(rule.DeveloperName);
			if(existing == null || (!isPackageOwnedRule(existing) && isPackageOwnedRule(rule)))
			{
				ruleByName.put(rule.DeveloperName, rule);
			}
		}
		return ruleByName;
	}

	/**
	 * @description Resolves the deployable name a masking rule must be referenced by in a generated bundle. A
	 * subscriber-owned (unmanaged, blank-namespace) rule keeps its bare developer name; a package-owned rule is
	 * qualified with its own `NamespacePrefix` (for example `kern__MaskEmail`), because in a managed subscriber
	 * org the packaged record's API name carries that prefix and a bare reference resolves to no such record on
	 * deploy. Qualifying by the rule's *own* namespace (rather than the running package's) is correct for the
	 * framework's rules, a subscriber's own rules, and third-party-packaged rules alike. A null rule — the
	 * requested name matches no known rule — falls back to the requested name unchanged.
	 *
	 * @param rule The resolved rule record, or null when the requested name matches no known rule.
	 * @param requestedDeveloperName The bare developer name the administrator requested.
	 *
	 * @return The deployable rule name — bare for a subscriber-owned rule, namespace-qualified for a packaged one.
	 */
	private static String resolveRuleDeployName(MaskingRule__mdt rule, String requestedDeveloperName)
	{
		if(rule == null)
		{
			return requestedDeveloperName;
		}
		return String.isBlank(rule.NamespacePrefix)
				? rule.DeveloperName
				: rule.NamespacePrefix + UTIL_String.DOUBLE_UNDERSCORE + rule.DeveloperName;
	}

	/**
	 * @description Renders one MaskingTarget__mdt record as deployable CustomMetadata XML. A blank field or
	 * caller renders as `xsi:nil` (SObject-wide scope / all callers). `IsActive__c` follows the decision's
	 * `isActive` flag — a null or true decision emits an active target (create / re-enable), an explicit
	 * false emits a disabled target (the disable half of the diff). Defaulting null to active is deliberate:
	 * the common create case carries no flag.
	 *
	 * @param decision The target to render.
	 * @param ruleDeployName The deployable (bare or namespace-qualified) name of the rule the target binds to,
	 * resolved so the `Rule__c` relationship resolves to the packaged record on a managed subscriber org.
	 *
	 * @return The `.md-meta.xml` file body.
	 */
	private static String renderTargetXml(DTO_TargetDecision decision, String ruleDeployName)
	{
		List<String> rows = new List<String>
		{
				renderValueRow(SEL_MaskingTarget.FIELD_CALLER_CLASS, renderStringOrNil(decision.callerClass)),
				renderValueRow(SEL_MaskingTarget.FIELD_FIELD, renderStringOrNil(decision.field)),
				renderValueRow(SEL_MaskingTarget.FIELD_IS_ACTIVE, renderBooleanValue(decision.isActive != false)),
				renderValueRow(SEL_MaskingTarget.FIELD_RULE, renderStringValue(ruleDeployName)),
				renderValueRow(SEL_MaskingTarget.FIELD_SOBJECT_TYPE, renderStringValue(decision.sObjectType))
		};
		return renderCustomMetadata(decision.label, rows);
	}

	/**
	 * @description Renders a rule-activation override (`IsActive__c = true`) so a subscriber can activate a
	 * dormant shipped rule without editing it by hand.
	 *
	 * @param ruleLabel The rule's label, preserved on the record.
	 *
	 * @return The `.md-meta.xml` body that flips the rule active.
	 */
	private static String renderRuleActivationXml(String ruleLabel)
	{
		return renderCustomMetadata(ruleLabel, new List<String> {renderValueRow(SEL_MaskingRule.FIELD_IS_ACTIVE, renderBooleanValue(true))});
	}

	/**
	 * @description Wraps the given value rows in the CustomMetadata envelope under the given label.
	 *
	 * @param label The record label (XML-escaped).
	 * @param valueRows The pre-rendered `<values>` rows.
	 *
	 * @return The complete `.md-meta.xml` file body.
	 */
	@SuppressWarnings('HttpUrlsUsage')
	private static String renderCustomMetadata(String label, List<String> valueRows)
	{
		return '<?xml version="1.0" encoding="UTF-8"?>\n'
				+ '<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' +
				'xmlns:xsd="http://www.w3.org/2001/XMLSchema">\n'
				+ '    <label>' + escapeXml(label) + '</label>\n'
				+ '    <protected>false</protected>\n'
				+ String.join(valueRows, '\n') + '\n'
				+ '</CustomMetadata>';
	}

	/**
	 * @description Renders one `<values>` element binding a CMDT field to its value XML.
	 *
	 * @param field The CMDT field API name.
	 * @param valueXml The pre-rendered `<value>` element.
	 *
	 * @return The `<values>` row.
	 */
	private static String renderValueRow(String field, String valueXml)
	{
		return '    <values>\n        <field>' + field + '</field>\n        ' + valueXml + '\n    </values>';
	}

	/**
	 * @description Renders a typed boolean `<value>` element.
	 *
	 * @param value The boolean to render.
	 *
	 * @return The `<value xsi:type="xsd:boolean">` element.
	 */
	private static String renderBooleanValue(Boolean value)
	{
		return '<value xsi:type="xsd:boolean">' + value + '</value>';
	}

	/**
	 * @description Renders a typed, XML-escaped string `<value>` element.
	 *
	 * @param value The string to render.
	 *
	 * @return The `<value xsi:type="xsd:string">` element.
	 */
	private static String renderStringValue(String value)
	{
		return '<value xsi:type="xsd:string">' + escapeXml(value) + '</value>';
	}

	/**
	 * @description Renders a string `<value>` element, or `xsi:nil` when the value is blank.
	 *
	 * @param value The string to render, or blank for `xsi:nil`.
	 *
	 * @return The string `<value>` element, or the nil element.
	 */
	private static String renderStringOrNil(String value)
	{
		return String.isBlank(value) ? NIL_VALUE : renderStringValue(value);
	}

	/**
	 * @description Escapes the five XML metacharacters; a null value renders as the empty string.
	 *
	 * @param value The raw text.
	 *
	 * @return The XML-safe text.
	 */
	private static String escapeXml(String value)
	{
		return value == null
				? UTIL_String.EMPTY
				: value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace('\'', '&apos;');
	}

	/**
	 * @description Builds the `package.xml` listing every CustomMetadata member, pinned to the package
	 * API version.
	 *
	 * @param members Fully-qualified `MaskingTarget.<name>` / `MaskingRule.<name>` members.
	 *
	 * @return The `package.xml` body.
	 */
	@SuppressWarnings('HttpUrlsUsage')
	private static String renderPackageXml(List<String> members)
	{
		String memberRows = UTIL_String.EMPTY;
		for(String member : members)
		{
			memberRows += '        <members>' + member + '</members>\n';
		}
		return '<?xml version="1.0" encoding="UTF-8"?>\n'
				+ '<Package xmlns="http://soap.sforce.com/2006/04/metadata">\n'
				+ '    <types>\n' + memberRows
				+ '        <name>CustomMetadata</name>\n    </types>\n'
				+ '    <version>' + UTIL_System.getOrgApiVersion() + '</version>\n</Package>';
	}

	/**
	 * @description Builds the human-readable README describing the bundle and how to deploy it.
	 *
	 * @param members Fully-qualified CustomMetadata members in the bundle.
	 *
	 * @return The README body.
	 */
	private static String renderReadme(List<String> members)
	{
		String memberList = members.isEmpty() ? System.Label.DataMaskingAdvisor_Readme_NoMembers : String.join(members, UTIL_String.COMMA);
		return String.format(System.Label.DataMaskingAdvisor_Readme_Body, new List<String> {memberList});
	}

	/**
	 * @description Flags active targets whose referenced rule is inactive or absent. A target whose
	 * `Rule__c` is null or not present in the map is a `MISSING_RULE`; a target whose rule is present but
	 * inactive is an `INACTIVE_RULE`. Inactive targets are skipped — they mask nothing by design, which
	 * is not a misconfiguration.
	 *
	 * @param targets All masking targets (active and inactive)
	 * @param rulesById Rules keyed by Id, including inactive rules so the two issue kinds are distinguishable
	 *
	 * @return One finding per dead active target
	 */
	@TestVisible
	private static List<DTO_DeadConfiguration> analyzeDeadConfiguration(List<MaskingTarget__mdt> targets, Map<Id, MaskingRule__mdt> rulesById)
	{
		List<DTO_DeadConfiguration> findings = new List<DTO_DeadConfiguration>();

		for(MaskingTarget__mdt target : targets)
		{
			if(!isDeadTarget(target, rulesById))
			{
				continue;
			}
			ConfigurationIssue issue = (target.Rule__c == null || !rulesById.containsKey(target.Rule__c))
					? ConfigurationIssue.MISSING_RULE
					: ConfigurationIssue.INACTIVE_RULE;
			findings.add(buildFinding(target.DeveloperName, issue));
		}

		return findings;
	}

	/**
	 * @description Decides whether a masking target is "dead" — active but masking nothing — because its rule
	 * is missing (no `Rule__c`, or a `Rule__c` not present in the supplied map) or its rule is inactive. An
	 * inactive target is never dead: it masks nothing by design, which is not a misconfiguration. Shared by
	 * `analyzeDeadConfiguration` (which additionally reports the issue kind) and the org-wide inventory (which
	 * counts dead targets per object) so both apply a single definition of "dead".
	 *
	 * @param target The masking target to test.
	 * @param rulesById Rules keyed by Id, including inactive rules, so an inactive-rule target is detectable.
	 *
	 * @return True when the target is active and its rule is missing or inactive.
	 */
	private static Boolean isDeadTarget(MaskingTarget__mdt target, Map<Id, MaskingRule__mdt> rulesById)
	{
		if(!target.IsActive__c)
		{
			return false;
		}
		return target.Rule__c == null || !rulesById.containsKey(target.Rule__c) || rulesById.get(target.Rule__c).IsActive__c != true;
	}

	/**
	 * @description Reduces the org's targets to the four posture counts in a single pass. Active targets are
	 * partitioned into field-level (a non-blank `Field__c`) and object-wide (a blank `Field__c`); the distinct
	 * `SObjectType__c` durable Ids among active targets give the object count; inactive targets are ignored. The
	 * dead-configuration count is tallied via the shared `isDeadTarget` predicate — the same one
	 * `analyzeDeadConfiguration` applies — so the posture total stays consistent with the per-target findings the
	 * banner surfaces without allocating the findings list just to count it.
	 *
	 * @param targets All masking targets (active and inactive).
	 * @param rulesById Rules keyed by Id, including inactive rules, so dead configurations are detectable.
	 *
	 * @return The populated posture summary.
	 */
	@TestVisible
	private static DTO_OrgPostureSummary summarizePosture(List<MaskingTarget__mdt> targets, Map<Id, MaskingRule__mdt> rulesById)
	{
		Set<String> objectsWithActiveTargets = new Set<String>();
		Integer activeFieldTargetCount = 0;
		Integer sObjectWideTargetCount = 0;
		Integer deadConfigCount = 0;

		for(MaskingTarget__mdt target : targets)
		{
			if(target.IsActive__c != true)
			{
				continue;
			}
			objectsWithActiveTargets.add(target.SObjectType__c);
			if(String.isBlank(target.Field__c))
			{
				sObjectWideTargetCount += 1;
			}
			else
			{
				activeFieldTargetCount += 1;
			}
			// Reached only for active targets; isDeadTarget also short-circuits on inactive, so this tally
			// matches analyzeDeadConfiguration (which counts active targets whose rule is missing or inactive).
			if(isDeadTarget(target, rulesById))
			{
				deadConfigCount += 1;
			}
		}

		DTO_OrgPostureSummary summary = new DTO_OrgPostureSummary();
		summary.objectsWithActiveTargets = objectsWithActiveTargets.size();
		summary.activeFieldTargetCount = activeFieldTargetCount;
		summary.sObjectWideTargetCount = sObjectWideTargetCount;
		summary.deadConfigCount = deadConfigCount;
		return summary;
	}

	/**
	 * @description Reduces the org's targets to a drillable per-object inventory. Active targets are grouped by
	 * their `SObjectType__c` durable Id; only objects with at least one active target appear (an object whose
	 * targets are all inactive is omitted, as is an object whose durable Id is absent from the supplied
	 * resolution maps — a since-deleted object). Per object it counts active object-wide targets (blank
	 * `Field__c`) and active field-level targets (non-blank `Field__c`), collects the distinct labels of the
	 * active rules those targets bind, and counts dead configurations via `isDeadTarget`. Object identity (API
	 * name + label) is supplied pre-resolved so the reducer stays free of describe/SOQL and is unit-testable
	 * with synthetic durable Ids. Rows are ordered by object label, and each row's rule labels alphabetically,
	 * for a stable render.
	 *
	 * @param targets All masking targets (active and inactive).
	 * @param rulesById Rules keyed by Id, including inactive rules, so dead targets and inactive rule labels are distinguishable.
	 * @param apiNameByDurableId Object API name keyed by `SObjectType__c` durable Id; a durable Id absent here is dropped.
	 * @param labelByDurableId Object label keyed by `SObjectType__c` durable Id.
	 *
	 * @return One inventory entry per masked, resolvable object, ordered by object label.
	 */
	@TestVisible
	private static List<DTO_ObjectMaskingInventory> summarizeInventory
			(List<MaskingTarget__mdt> targets, Map<Id, MaskingRule__mdt> rulesById, Map<String, String> apiNameByDurableId, Map<String, String> labelByDurableId)
	{
		Map<String, DTO_ObjectMaskingInventory> inventoryByDurableId = new Map<String, DTO_ObjectMaskingInventory>();
		Map<String, Set<String>> ruleLabelsByDurableId = new Map<String, Set<String>>();

		for(MaskingTarget__mdt target : targets)
		{
			if(target.IsActive__c != true)
			{
				continue;
			}
			String durableId = target.SObjectType__c;
			if(!apiNameByDurableId.containsKey(durableId))
			{
				continue;
			}

			DTO_ObjectMaskingInventory entry = inventoryByDurableId.get(durableId);
			if(entry == null)
			{
				entry = new DTO_ObjectMaskingInventory();
				entry.objectApiName = apiNameByDurableId.get(durableId);
				entry.objectLabel = labelByDurableId.get(durableId);
				entry.ruleLabels = new List<String>();
				entry.objectWideTargetCount = 0;
				entry.fieldTargetCount = 0;
				entry.deadCount = 0;
				inventoryByDurableId.put(durableId, entry);
				ruleLabelsByDurableId.put(durableId, new Set<String>());
			}

			if(String.isBlank(target.Field__c))
			{
				entry.objectWideTargetCount += 1;
			}
			else
			{
				entry.fieldTargetCount += 1;
			}

			MaskingRule__mdt rule = rulesById.get(target.Rule__c);
			if(rule != null && rule.IsActive__c == true)
			{
				ruleLabelsByDurableId.get(durableId).add(rule.MasterLabel);
			}

			if(isDeadTarget(target, rulesById))
			{
				entry.deadCount += 1;
			}
		}

		for(String durableId : inventoryByDurableId.keySet())
		{
			List<String> sortedLabels = new List<String>(ruleLabelsByDurableId.get(durableId));
			sortedLabels.sort();
			inventoryByDurableId.get(durableId).ruleLabels = sortedLabels;
		}

		return orderInventoryByLabel(inventoryByDurableId.values());
	}

	/**
	 * @description Orders inventory rows by object label, then API name as a tiebreaker, for a stable render —
	 * without requiring the DTO to implement `Comparable`.
	 *
	 * @param entries The unordered inventory rows.
	 *
	 * @return The rows ordered by object label then API name.
	 */
	private static List<DTO_ObjectMaskingInventory> orderInventoryByLabel(List<DTO_ObjectMaskingInventory> entries)
	{
		Map<String, DTO_ObjectMaskingInventory> entryBySortKey = new Map<String, DTO_ObjectMaskingInventory>();
		for(DTO_ObjectMaskingInventory entry : entries)
		{
			entryBySortKey.put(entry.objectLabel + '|' + entry.objectApiName, entry);
		}
		List<String> sortKeys = new List<String>(entryBySortKey.keySet());
		sortKeys.sort();

		List<DTO_ObjectMaskingInventory> ordered = new List<DTO_ObjectMaskingInventory>();
		for(String sortKey : sortKeys)
		{
			ordered.add(entryBySortKey.get(sortKey));
		}
		return ordered;
	}

	/**
	 * @description Builds a dead-configuration finding, resolving the admin-facing message from the
	 * Custom Label template for the issue kind.
	 *
	 * @param targetDeveloperName Developer name of the offending target
	 * @param issue The kind of problem found
	 *
	 * @return The populated finding
	 */
	private static DTO_DeadConfiguration buildFinding(String targetDeveloperName, ConfigurationIssue issue)
	{
		DTO_DeadConfiguration finding = new DTO_DeadConfiguration();
		finding.targetDeveloperName = targetDeveloperName;
		finding.issueCode = issue.name();
		finding.message = String.format(MESSAGE_TEMPLATE_BY_ISSUE.get(issue), new List<Object> {targetDeveloperName});
		return finding;
	}

	/**
	 * @description One dead-configuration finding for an active masking target that silently masks nothing.
	 */
	public class DTO_DeadConfiguration
	{
		/**
		 * @description Developer name of the active masking target that masks nothing.
		 */
		@AuraEnabled
		public String targetDeveloperName;

		/**
		 * @description The issue kind as the `ConfigurationIssue` enum name (e.g. `INACTIVE_RULE`), so the
		 * component can group or style findings without parsing the message text.
		 */
		@AuraEnabled
		public String issueCode;

		/**
		 * @description Admin-facing message explaining the problem and how to fix it, naming the target.
		 */
		@AuraEnabled
		public String message;
	}

	/**
	 * @description The org-wide masking posture summary for the Review landing view — as-configured target
	 * counts derived from CustomMetadata, not a describe-level org scan.
	 */
	public class DTO_OrgPostureSummary
	{
		/**
		 * @description Count of distinct objects that carry at least one active masking target.
		 */
		@AuraEnabled
		public Integer objectsWithActiveTargets;

		/**
		 * @description Count of active targets scoped to a specific field (field-level masking).
		 */
		@AuraEnabled
		public Integer activeFieldTargetCount;

		/**
		 * @description Count of active targets with no field, i.e. object-wide masking.
		 */
		@AuraEnabled
		public Integer sObjectWideTargetCount;

		/**
		 * @description Count of active targets that mask nothing because their rule is missing or inactive.
		 */
		@AuraEnabled
		public Integer deadConfigCount;
	}

	/**
	 * @description One masked object in the org-wide inventory the Review landing view drills into — its API
	 * name and label, the distinct active rule labels applied across it, its active object-wide and field-level
	 * target counts, and the count of dead configurations scoped to it.
	 */
	public class DTO_ObjectMaskingInventory
	{
		/**
		 * @description Qualified API name of the masked object (namespaced in subscriber orgs).
		 */
		@AuraEnabled
		public String objectApiName;

		/**
		 * @description Human-readable object label.
		 */
		@AuraEnabled
		public String objectLabel;

		/**
		 * @description Distinct labels of the active rules applied across the object's active targets, ordered alphabetically.
		 */
		@AuraEnabled
		public List<String> ruleLabels;

		/**
		 * @description Count of active object-wide targets (blank `Field__c`) on the object.
		 */
		@AuraEnabled
		public Integer objectWideTargetCount;

		/**
		 * @description Count of active field-level targets (non-blank `Field__c`) on the object.
		 */
		@AuraEnabled
		public Integer fieldTargetCount;

		/**
		 * @description Count of dead configurations scoped to the object — active targets whose rule is missing or inactive.
		 */
		@AuraEnabled
		public Integer deadCount;
	}

	/**
	 * @description One selectable SObject option for the console's object picker.
	 */
	public class DTO_ObjectOption
	{
		/**
		 * @description Qualified API name of the object (namespaced in subscriber orgs).
		 */
		@AuraEnabled
		public String apiName;

		/**
		 * @description Human-readable object label.
		 */
		@AuraEnabled
		public String label;

		/**
		 * @description Whether the object is a custom object (`__c`) — the population the custom-object
		 * coverage scan iterates.
		 */
		@AuraEnabled
		public Boolean isCustom;

		/**
		 * @description The object's managed-package namespace prefix (for example `FSL`), or null for the
		 * subscriber's own objects. The coverage scan defaults to un-namespaced custom objects and treats
		 * managed-package objects as an explicit opt-in, keeping the default scan population manageable in
		 * orgs with large AppExchange footprints.
		 */
		@AuraEnabled
		public String namespacePrefix;
	}

	/**
	 * @description The masking-coverage assessment of one SObject for the custom-object coverage scan.
	 */
	public class DTO_ObjectCoverageAssessment
	{
		/**
		 * @description API name of the assessed object, echoed from the request.
		 */
		@AuraEnabled
		public String objectApiName;

		/**
		 * @description Human-readable object label, or null when the object does not resolve.
		 */
		@AuraEnabled
		public String objectLabel;

		/**
		 * @description Whether at least one active masking target (field-level or object-wide) covers the object.
		 */
		@AuraEnabled
		public Boolean hasActiveMasking;

		/**
		 * @description Whether the object requires attention — it has at least one sensitive-rated field
		 * while no active masking covers it.
		 */
		@AuraEnabled
		public Boolean requiresAttention;

		/**
		 * @description The sensitive and possibly-sensitive fields found while the object has no active
		 * masking. Empty when the object is covered or carries no such fields.
		 */
		@AuraEnabled
		public List<DTO_FlaggedField> flaggedFields;
	}

	/**
	 * @description One field flagged by the custom-object coverage scan as likely holding sensitive data.
	 */
	public class DTO_FlaggedField
	{
		/**
		 * @description API name of the flagged field.
		 */
		@AuraEnabled
		public String fieldApiName;

		/**
		 * @description Human-readable field label.
		 */
		@AuraEnabled
		public String fieldLabel;

		/**
		 * @description The field's sensitivity rating (`Sensitive` or `PossiblySensitive`).
		 */
		@AuraEnabled
		public String sensitivityLevel;

		/**
		 * @description Whether the field is a Long Text Area (or Rich Text) — the high-risk unmasked
		 * free-text blind spot the console highlights among scan results.
		 */
		@AuraEnabled
		public Boolean isLongTextArea;
	}

	/**
	 * @description The bounded masking-coverage summary of the subscriber's own custom objects,
	 * consumed by the Health Check's custom-object coverage card.
	 */
	public class DTO_CustomObjectCoverageSummary
	{
		/**
		 * @description How many of the subscriber's own custom objects this pass assessed.
		 */
		@AuraEnabled
		public Integer assessedObjectCount;

		/**
		 * @description How many candidate objects remained unassessed once the per-run bound was reached.
		 */
		@AuraEnabled
		public Integer unassessedObjectCount;

		/**
		 * @description API names of assessed objects requiring attention — at least one sensitive-rated
		 * field while no active masking covers the object.
		 */
		@AuraEnabled
		public List<String> objectsRequiringAttention;
	}

	/**
	 * @description One object's regulated-field inventory — the object identity plus one row per field that
	 * holds or likely holds regulated data. The console denormalizes the object identity onto each row when
	 * it assembles the cross-object CSV/JSON export.
	 */
	public class DTO_ObjectFieldInventory
	{
		/**
		 * @description API name of the inventoried object, echoed from the request.
		 */
		@AuraEnabled
		public String objectApiName;

		/**
		 * @description Human-readable object label, or null when the object does not resolve.
		 */
		@AuraEnabled
		public String objectLabel;

		/**
		 * @description One row per regulated field on the object. Empty when the object does not resolve or
		 * carries no regulated fields.
		 */
		@AuraEnabled
		public List<DTO_FieldInventoryRow> rows;
	}

	/**
	 * @description One regulated field projected into the inventory-export shape — the ten columns the export
	 * modal previews. `securityClassification` / `complianceGroup` are null for a field carrying no native
	 * classification; the recommended-rule fields are null when no rule matches.
	 */
	public class DTO_FieldInventoryRow
	{
		/**
		 * @description API name of the field.
		 */
		@AuraEnabled
		public String fieldApiName;

		/**
		 * @description Human-readable field label.
		 */
		@AuraEnabled
		public String fieldLabel;

		/**
		 * @description Field display type (for example `EMAIL`, `PHONE`, `TEXTAREA`).
		 */
		@AuraEnabled
		public String fieldType;

		/**
		 * @description Whether the field is a Long Text Area (or Rich Text) — a common unmasked free-text
		 * blind spot the export flags for a second look.
		 */
		@AuraEnabled
		public Boolean isLongTextArea;

		/**
		 * @description Native `SecurityClassification` value, or null when the field is unclassified.
		 */
		@AuraEnabled
		public String securityClassification;

		/**
		 * @description Native `ComplianceGroup` value, or null when the field is unclassified.
		 */
		@AuraEnabled
		public String complianceGroup;

		/**
		 * @description The field's sensitivity rating (`Sensitive` or `PossiblySensitive`).
		 */
		@AuraEnabled
		public String sensitivityLevel;

		/**
		 * @description Developer name of the advisor's recommended masking rule, or null when no rule matches.
		 */
		@AuraEnabled
		public String recommendedRuleDeveloperName;

		/**
		 * @description Master label of the recommended rule, or null when no rule matches.
		 */
		@AuraEnabled
		public String recommendedRuleLabel;

		/**
		 * @description Whether an active masking target (field-level or object-wide) covers this field today.
		 */
		@AuraEnabled
		public Boolean maskedToday;

		/**
		 * @description Whether field-history tracking is recommended for this field — true for `Sensitive`
		 * fields whose changes warrant an audit trail. Informational only; the export never enables tracking.
		 */
		@AuraEnabled
		public Boolean historyTrackingRecommended;
	}

	/**
	 * @description One masking rule in the catalogue the console renders — its developer name, label,
	 * category hint, mode, and active state — so the per-field rule picker and category chip read from
	 * rule metadata without a second round-trip or a hardcoded map. `category` is null for an
	 * uncategorized rule (subscriber-created, or any a package upgrade did not populate).
	 */
	public class DTO_RuleOption
	{
		/**
		 * @description Rule developer name (the value stored on a target's `Rule__c`).
		 */
		@AuraEnabled
		public String developerName;

		/**
		 * @description Human-readable rule label for display in the rule picker.
		 */
		@AuraEnabled
		public String label;

		/**
		 * @description Optional category hint (for example `Contact`, `Payment`), or null when the rule
		 * carries no category.
		 */
		@AuraEnabled
		public String category;

		/**
		 * @description The rule's masking mode (for example `Regex`, `JsonKey`), so the console can hint
		 * when a rule expects a JSON payload.
		 */
		@AuraEnabled
		public String mode;

		/**
		 * @description Whether the rule is currently active.
		 */
		@AuraEnabled
		public Boolean isActive;

		/**
		 * @description The upper-cased `DisplayType` names this rule's `ApplicableFieldTypes__c` scope admits
		 * (for example `EMAIL`, `PHONE`). Empty means the rule is unscoped — it applies to any maskable
		 * text-shaped field. Lets the console filter a rule's chips to the fields whose type it admits.
		 */
		@AuraEnabled
		public List<String> applicableFieldTypes;

		/**
		 * @description The rule's `Description__c` — a plain-language account of what the rule redacts — so the
		 * rule-detail popup can show "what it masks". Null when the rule carries no description.
		 */
		@AuraEnabled
		public String description;

		/**
		 * @description The supersession annotation for a rule another rule's `Replaces__c` names — the
		 * `MaskingRuleSupersededBy` label formatted with the successor's label — or null for a rule no
		 * successor names. Steers the admin to the successor while a tuned predecessor stays visible.
		 */
		@AuraEnabled
		public String supersededByLabel;
	}

	/**
	 * @description One masking target wired to a field or applied object-wide, surfaced so the console can
	 * render it as a chip and re-emit it (flipped) in a disable / re-enable diff.
	 */
	public class DTO_AppliedRule
	{
		/**
		 * @description `MaskingTarget__mdt` DeveloperName — the key the diff re-emits the target under.
		 */
		@AuraEnabled
		public String targetDeveloperName;

		/**
		 * @description `MaskingRule__mdt` DeveloperName of the rule the target binds to, or null when the
		 * rule cannot be resolved (a dead or orphaned reference).
		 */
		@AuraEnabled
		public String ruleDeveloperName;

		/**
		 * @description Human-readable rule label for display, or null when the rule cannot be resolved.
		 */
		@AuraEnabled
		public String ruleLabel;

		/**
		 * @description The target's own `IsActive__c` — whether this masking is active today. Drives the
		 * chip's checked state and whether the diff offers disable (true) or re-enable (false).
		 */
		@AuraEnabled
		public Boolean isActive;

		/**
		 * @description The target's `CallerClass__c` scope, preserved so a disable / re-enable re-emit keeps
		 * the original caller scope. Blank means the target applies to all callers.
		 */
		@AuraEnabled
		public String callerClass;

		/**
		 * @description The supersession annotation for the bound rule when another rule's `Replaces__c`
		 * names it, or null. Applied rows are annotated, never filtered — the binding still actively
		 * masks until the admin rebinds it to the successor.
		 */
		@AuraEnabled
		public String supersededByLabel;

		/**
		 * @description The bound rule's own `IsActive__c` (distinct from the target's `isActive`), or null
		 * when the rule cannot be resolved. Lets the rule-detail popup style a superseded-but-active rule
		 * honestly even though the rule no longer appears in the catalogue.
		 */
		@AuraEnabled
		public Boolean ruleIsActive;
	}

	/**
	 * @description The result of analyzing one SObject's fields for masking coverage and sensitivity.
	 */
	public class DTO_FieldAnalysis
	{
		/**
		 * @description Whether native classification was readable. `false` means the console is running in
		 * heuristic-only mode (FieldDefinition could not be queried) and should say so in-product.
		 */
		@AuraEnabled
		public Boolean classificationAvailable;

		/**
		 * @description One row per field on the SObject.
		 */
		@AuraEnabled
		public List<DTO_FieldRow> fields;

		/**
		 * @description The masking-rule catalogue — one entry per rule — so the console renders a rule's
		 * label and category from rule metadata rather than a hardcoded map.
		 */
		@AuraEnabled
		public List<DTO_RuleOption> rules;

		/**
		 * @description The object-wide masking targets on this SObject (Field__c blank), active and inactive,
		 * each as an applied rule — so the console renders an object-wide coverage banner and offers to
		 * disable / re-enable object-wide masking.
		 */
		@AuraEnabled
		public List<DTO_AppliedRule> objectWideRules;

		/**
		 * @description The Setup address that opens the New Masking Rule form, with the `MaskingRule__mdt`
		 * key prefix resolved dynamically — so the console's "create a custom rule" link never hardcodes a
		 * prefix that differs across packaging contexts.
		 */
		@AuraEnabled
		public String newRuleSetupUrl;
	}

	/**
	 * @description One field row in the coverage advisor.
	 */
	public class DTO_FieldRow
	{
		/**
		 * @description Field API name.
		 */
		@AuraEnabled
		public String apiName;

		/**
		 * @description Field label.
		 */
		@AuraEnabled
		public String label;

		/**
		 * @description Field display type (for example `EMAIL`, `PHONE`, `STRING`).
		 */
		@AuraEnabled
		public String type;

		/**
		 * @description Native `SecurityClassification` value, or `null` when the field is unclassified.
		 */
		@AuraEnabled
		public String securityClassification;

		/**
		 * @description Native `ComplianceGroup` value, or `null` when the field is unclassified.
		 */
		@AuraEnabled
		public String complianceGroup;

		/**
		 * @description Whether the field carries a native classification.
		 */
		@AuraEnabled
		public Boolean isClassified;

		/**
		 * @description Heuristic confidence tier (`HIGH`/`MEDIUM`/`LOW`) for an unclassified field, or
		 * `null` when the field is classified or is not a heuristic match.
		 */
		@AuraEnabled
		public String heuristicConfidence;

		/**
		 * @description The masking targets wired to this specific field, active and inactive, each as an
		 * applied rule — so the console renders existing field-level coverage as checkbox chips and offers a
		 * disable / re-enable diff. Empty when no target masks this field.
		 */
		@AuraEnabled
		public List<DTO_AppliedRule> appliedRules;

		/**
		 * @description Developer name of the rule the advisor recommends staging for this field, or `null`
		 * when no rule's `Mask`-stem substring-matches the field's API name. Best-effort copy that does
		 * not assert the rule is the correct choice; the admin can override before staging.
		 */
		@AuraEnabled
		public String recommendedRuleDeveloperName;

		/**
		 * @description Master label of the recommended rule, for in-product display next to the developer
		 * name. `null` when no rule is recommended.
		 */
		@AuraEnabled
		public String recommendedRuleLabel;

		/**
		 * @description Whether the recommended rule is currently active. `false` when the rule is dormant —
		 * the bundle will activate it on deploy, gated by the Generate-Bundle confirmation modal. `null`
		 * when no rule is recommended.
		 */
		@AuraEnabled
		public Boolean recommendedRuleIsActive;

		/**
		 * @description Every concept-matched recommended rule for this field, each pre-ticked as its own
		 * Field-level candidate in the console — so a field a single rule's name never fully covers still
		 * surfaces every applicable rule (a phone field surfaces both the US and the international phone rule).
		 * The singular `recommendedRule*` fields above are this list's primary element (the first match), the
		 * one that drives the match-strength band and the sensitivity coupling. Empty when no rule matches.
		 */
		@AuraEnabled
		public List<DTO_RecommendedRule> recommendedRules;

		/**
		 * @description Developer names of every masking rule whose type scope admits this field's
		 * `DisplayType` — the rules the per-field rule picker may offer. Empty for a non-maskable field.
		 * A rule with no `ApplicableFieldTypes__c` scope is applicable to any maskable text-shaped field.
		 */
		@AuraEnabled
		public List<String> applicableRuleDeveloperNames;

		/**
		 * @description The heuristic match-signal band (`Weak`/`Moderate`/`Strong`) the console renders.
		 * `Weak` means no rule matched (the floor); `Strong` means a name match reinforced by a specific
		 * text type; `Moderate` is everything between. A band, never a calibrated percentage. (The "likely
		 * miss" surfacing in the Other section is driven by `likelyMiss`, not by this band.)
		 */
		@AuraEnabled
		public String matchStrength;

		/**
		 * @description The sensitivity level (`Sensitive`/`PossiblySensitive`/`NotSensitive`) the console
		 * renders as the reclassifiable badge, derived from the native classification, the name/type
		 * heuristic, and whether a masking rule was recommended (a recommended field is never
		 * `NotSensitive`). Domain-neutral because framework masking covers sensitive data beyond PII.
		 */
		@AuraEnabled
		public String sensitivityLevel;

		/**
		 * @description True when this is a `NotSensitive` field whose type structurally signals sensitive
		 * content (the type-reinforcing EMAIL/PHONE/URL/ENCRYPTEDSTRING set) — a likely miss the advisor
		 * did not recommend, worth a second look. The console's "Other" section can filter to these and
		 * floats them to the top. False for every recommended or flagged field (those are already
		 * surfaced) and for plain text/picklist fields with no type signal.
		 */
		@AuraEnabled
		public Boolean likelyMiss;

		/**
		 * @description A synthetic, clearly-fictional example value whose shape is derived from the field's
		 * `DisplayType` (an email for EMAIL, a US phone for PHONE, a basic-auth URL for URL), or `null` for
		 * an undefined-shape type (STRING/TEXTAREA/ENCRYPTEDSTRING) where no single value is representative.
		 * Drives the inline before→after example with no client-side sample data and no JavaScript masking.
		 */
		@AuraEnabled
		public String exampleInput;

		/**
		 * @description The engine's true masking of `exampleInput` under this row's recommended rule,
		 * computed server-side via the same masker path the live framework uses. `null` when there is no
		 * `exampleInput` (an undefined-shape type) or no recommended rule — the console then shows only the
		 * on-demand "Try a value" affordance rather than a fabricated transformation.
		 */
		@AuraEnabled
		public String exampleOutput;
	}

	/**
	 * @description One recommended masking rule for a field — the unit the console pre-ticks as a Field-level
	 * candidate chip (and stages as a MaskingTarget on export). A field carries more than one when several
	 * rules match its concept (a phone field matches both the US and the international phone rule).
	 */
	public class DTO_RecommendedRule
	{
		/**
		 * @description Developer name of the recommended rule — the value stored on the created target's `Rule__c`.
		 */
		@AuraEnabled
		public String developerName;

		/**
		 * @description Master label of the recommended rule, for in-product display.
		 */
		@AuraEnabled
		public String label;

		/**
		 * @description Whether the recommended rule is currently active. `false` when the rule is dormant — the
		 * bundle activates it on deploy, gated by the Generate-Bundle confirmation modal.
		 */
		@AuraEnabled
		public Boolean isActive;
	}

	/**
	 * @description The result of masking one value, surfaced to the test bench.
	 */
	public class DTO_MaskPreview
	{
		/**
		 * @description The masked output.
		 */
		@AuraEnabled
		public String maskedValue;

		/**
		 * @description Developer names of the rules that matched and transformed the value.
		 */
		@AuraEnabled
		public List<String> matchedRuleDeveloperNames;

		/**
		 * @description Developer names of the rules that errored while masking the value.
		 */
		@AuraEnabled
		public List<String> failedRuleDeveloperNames;

		/**
		 * @description Whether any rule errored while masking the value.
		 */
		@AuraEnabled
		public Boolean hadErrors;

		/**
		 * @description Character length of the masked output.
		 */
		@AuraEnabled
		public Integer maskedLength;

		/**
		 * @description Whether the previewed rule masks JSON keys (Mode `JsonKey`) and therefore expects a
		 * JSON payload. When true, a no-op on a non-JSON scalar is expected behaviour, not a broken rule, so
		 * the console can explain the result instead of letting a correct no-op read as a failure.
		 */
		@AuraEnabled
		public Boolean expectsJsonInput;
	}

	/**
	 * @description One sampled real value with its masked output, for the real-record test path.
	 */
	public class DTO_MaskSample
	{
		/**
		 * @description The real (FLS-authorised) source value, shown only on explicit reveal in the console.
		 */
		@AuraEnabled
		public String sourceValue;

		/**
		 * @description The masked output, shown by default in the console.
		 */
		@AuraEnabled
		public String maskedValue;

		/**
		 * @description Developer names of the rules that matched and transformed the value.
		 */
		@AuraEnabled
		public List<String> matchedRuleDeveloperNames;

		/**
		 * @description Whether any rule errored while masking the value.
		 */
		@AuraEnabled
		public Boolean hadErrors;
	}

	/**
	 * @description The active targets that currently reference a rule — the activation blast radius.
	 */
	public class DTO_BlastRadius
	{
		/**
		 * @description The rule the blast radius describes.
		 */
		@AuraEnabled
		public String ruleDeveloperName;

		/**
		 * @description Developer names of the active targets currently referencing the rule.
		 */
		@AuraEnabled
		public List<String> activeTargetDeveloperNames;
	}

	/**
	 * @description One field-to-rule decision the administrator made in the console — a target to create.
	 */
	public class DTO_TargetDecision
	{
		/**
		 * @description Developer name of the `MaskingTarget__mdt` record to create.
		 */
		@AuraEnabled
		public String developerName;

		/**
		 * @description Human-readable label for the record.
		 */
		@AuraEnabled
		public String label;

		/**
		 * @description Developer name of the `MaskingRule__mdt` the target binds to.
		 */
		@AuraEnabled
		public String ruleDeveloperName;

		/**
		 * @description API name of the SObject the target applies to.
		 */
		@AuraEnabled
		public String sObjectType;

		/**
		 * @description API name of the field to mask; blank means SObject-wide scope.
		 */
		@AuraEnabled
		public String field;

		/**
		 * @description Optional caller-class scope; blank means the target applies to all callers.
		 */
		@AuraEnabled
		public String callerClass;

		/**
		 * @description Whether the emitted target should be active. Null or true emits an active target
		 * (create / re-enable); an explicit false emits a disabled target (the disable half of the diff).
		 * Defaulting null to active keeps the common create case flag-free.
		 */
		@AuraEnabled
		public Boolean isActive;
	}

	/**
	 * @description The administrator's full generation request: the targets to create plus the dormant
	 * rules to activate.
	 */
	public class DTO_GenerationRequest
	{
		/**
		 * @description Targets to create.
		 */
		@AuraEnabled
		public List<DTO_TargetDecision> targets;

		/**
		 * @description Developer names of dormant rules that must be activated for the targets to mask.
		 */
		@AuraEnabled
		public List<String> rulesToActivate;
	}

	/**
	 * @description The deployment-neutral bundle: relative file path to file body for every artifact, plus a
	 * base64-encoded single-archive `.zip` of those files for one-click download.
	 */
	public class DTO_Bundle
	{
		/**
		 * @description Relative file path to file body for every artifact in the bundle.
		 */
		@AuraEnabled
		public Map<String, String> files = new Map<String, String>();

		/**
		 * @description Base64-encoded zip archive containing every entry from `files` at its relative path.
		 * The LWC decodes this to a `Blob('application/zip')` and triggers a single anchor download — the
		 * admin gets one deployable artifact rather than copy-pasting each file in turn. `null` when
		 * `files` is empty — the JSON payload omits the field entirely rather than carrying an empty
		 * string for the no-bundle case.
		 */
		@AuraEnabled
		public String zipBase64;
	}

	/**
	 * @description Bundles the shared per-SObject inputs `describeFields` resolves once and passes to
	 * every `buildFieldRow` call — the object type, the field-classification map, the resolved existing
	 * masking, the sorted recommendation candidates, and the applicable-rule names by type. Holding them in
	 * one struct keeps `buildFieldRow` to a few parameters and signals that they always travel together.
	 */
	private class FieldAnalysisContext
	{
		/**
		 * @description The SObject type under analysis, so a field row can resolve its `SObjectField` token
		 * from the already-loaded describe (for the server-side inline-example precompute) without
		 * re-describing per row.
		 */
		private final SObjectType sObjectType;

		/**
		 * @description Lowercased-field-name → FieldDefinition, populated when classification is readable.
		 * `null`-tolerant: `.get(name)` returns `null` for unclassified fields.
		 */
		private final Map<String, FieldDefinition> classificationByFieldName;

		/**
		 * @description The object's existing masking — applied rules per field and object-wide rules —
		 * resolved once for the whole analysis from all the object's targets.
		 */
		private final ExistingMasking existing;

		/**
		 * @description Candidate masking rules pre-sorted by stem length descending, ready for
		 * `resolveRecommendedRule` to walk first-match-wins.
		 */
		private final List<MaskingRule__mdt> recommendationCandidates;

		/**
		 * @description Maskable `DisplayType` to the applicable rule developer names for that type, computed
		 * once for the whole analysis so each field row resolves its picker options with a map lookup.
		 */
		private final Map<DisplayType, List<String>> applicableRuleNamesByType;

		/**
		 * @description Builds a context bundle.
		 *
		 * @param sObjectType The SObject type under analysis.
		 * @param classificationByFieldName Map of lowercased field name to classification.
		 * @param existing The object's existing masking (applied rules per field + object-wide rules).
		 * @param recommendationCandidates Pre-sorted candidate masking rules.
		 * @param applicableRuleNamesByType Maskable `DisplayType` to applicable rule developer names.
		 */
		@SuppressWarnings('PMD.ExcessiveParameterList')
		private FieldAnalysisContext
				(
						SObjectType sObjectType,
						Map<String, FieldDefinition> classificationByFieldName,
						ExistingMasking existing,
						List<MaskingRule__mdt> recommendationCandidates,
						Map<DisplayType, List<String>> applicableRuleNamesByType
				)
		{
			this.sObjectType = sObjectType;
			this.classificationByFieldName = classificationByFieldName;
			this.existing = existing;
			this.recommendationCandidates = recommendationCandidates;
			this.applicableRuleNamesByType = applicableRuleNamesByType;
		}

		/**
		 * @description Returns a fresh copy of the applicable rule developer names for a field's
		 * `DisplayType` — a copy so each field row owns its own list. Called only for fields that passed the
		 * maskability gate, so the type is always one of the pre-populated maskable types.
		 *
		 * @param fieldType The field's `DisplayType` (a maskable type).
		 *
		 * @return The applicable rule developer names for the type (a new list).
		 */
		private List<String> applicableRuleNamesFor(DisplayType fieldType)
		{
			return applicableRuleNamesByType.get(fieldType).clone();
		}
	}

	/**
	 * @description One SObject's existing masking, resolved once per analysis from all its targets: every
	 * field's applied targets (active and inactive) keyed by lowercased field API name, and the object-wide
	 * applied targets. Bundled so `describeFields` resolves the object's targets in a single pass and each
	 * field row reads its applied rules with a map lookup.
	 */
	private class ExistingMasking
	{
		/**
		 * @description Lowercased field API name to the applied targets on that field (active and inactive).
		 */
		private final Map<String, List<DTO_AppliedRule>> appliedByFieldLowerName;

		/**
		 * @description The object-wide applied targets (Field__c blank), active and inactive.
		 */
		private final List<DTO_AppliedRule> objectWideRules;

		/**
		 * @description Builds an existing-masking bundle.
		 *
		 * @param appliedByFieldLowerName Applied targets keyed by lowercased field API name.
		 * @param objectWideRules The object-wide applied targets.
		 */
		private ExistingMasking(Map<String, List<DTO_AppliedRule>> appliedByFieldLowerName, List<DTO_AppliedRule> objectWideRules)
		{
			this.appliedByFieldLowerName = appliedByFieldLowerName;
			this.objectWideRules = objectWideRules;
		}

		/**
		 * @description Returns the applied targets on a field, or an empty list when the field has none.
		 *
		 * @param fieldNameLowerCase The lowercased field API name.
		 *
		 * @return The field's applied rules (a possibly-empty list).
		 */
		private List<DTO_AppliedRule> appliedRulesFor(String fieldNameLowerCase)
		{
			return appliedByFieldLowerName.containsKey(fieldNameLowerCase)
					? appliedByFieldLowerName.get(fieldNameLowerCase)
					: new List<DTO_AppliedRule>();
		}
	}

}