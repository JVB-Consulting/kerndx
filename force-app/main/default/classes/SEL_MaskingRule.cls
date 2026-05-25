// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the MaskingRule__mdt custom metadata type.
 *
 * Rules are never queried standalone — the masking engine (UTIL_FrameworkMasker) reads them
 * through MaskingTarget__mdt joins, so a rule without a target has no effect. This selector
 * exists to be the single source of truth for two things: (1) the default rule field list
 * used by SEL_MaskingTarget.getFieldPaths() to join parent-rule fields into target queries,
 * and (2) the Mode__c and FailureAction__c picklist-value constants that Apex callers use to
 * dispatch on rule configuration.
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
 * @date April 2026, May 2026
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
	 * @description Constructs a MaskingRule selector.
	 */
	public SEL_MaskingRule()
	{
		super(MaskingRule__mdt.SObjectType);
	}

	/**
	 * @description Returns the core fields for MaskingRule__mdt queries.
	 *
	 * @return List of MaskingRule__mdt SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				MaskingRule__mdt.ApplicableFieldTypes__c,
				MaskingRule__mdt.CaseSensitive__c,
				MaskingRule__mdt.Description__c,
				MaskingRule__mdt.DeveloperName,
				MaskingRule__mdt.FailureAction__c,
				MaskingRule__mdt.IsActive__c,
				MaskingRule__mdt.MinInputLength__c,
				MaskingRule__mdt.Mode__c,
				MaskingRule__mdt.Order__c,
				MaskingRule__mdt.Pattern__c,
				MaskingRule__mdt.Replacement__c
		};
	}

}