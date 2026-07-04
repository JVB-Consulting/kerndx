// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Flow invocable action to bypass validation rules for the current transaction.
 * Use this before DML operations in Flow to temporarily disable validation rules.
 *
 * **Important:** Bypasses are cleared at the end of the transaction. Use
 * FLOW_ClearValidationBypass after your DML to explicitly clear bypasses for clarity.
 *
 * @see UTIL_ValidationRule
 * @see FLOW_ExecuteValidationRules
 * @see FLOW_ClearValidationBypass
 *
 * @author Jason van Beukering
 *
 * @group Validation
 *
 * @date January 2026, July 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * // Flow Configuration:
 * Action: Bypass Validation
 * Input:
 *   - BypassType: OBJECT_NAME (or GROUP_NAME or RULE_NAME)
 *   - Name: Account
 * // Perform DML...
 * Action: Clear Validation Bypass
 * Input:
 *   - Name: Account
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_BypassValidation
{
	/**
	 * @description Error message displayed when an invalid bypass type is provided.
	 */
	@TestVisible
	private static final String ERROR_INVALID_BYPASS_TYPE = 'Invalid bypassType. Must be one of: OBJECT_NAME, GROUP_NAME, or RULE_NAME';

	/**
	 * @description Sets a validation bypass for the current transaction.
	 *
	 * @param requests List of bypass requests
	 *
	 * @throws System.NoSuchElementException if an invalid bypass type is provided (with a user-friendly message)
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Bypass all Account validation rules
	 * FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
	 * request.bypassType = 'OBJECT_NAME';
	 * request.name = 'Account';
	 * FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request>{request});
	 * ```
	 */
	@InvocableMethod
	(
			Category='Validation'
			Label='Bypass Validation'
			Description='Bypasses validation rules for an object, group, or specific rule for the current transaction.'
	)
	global static void bypass(List<DTO_Request> requests)
	{
		for(DTO_Request request : requests)
		{
			processRequest(request);
		}
	}

	/**
	 * @description Processes a single bypass request by determining the bypass type and applying
	 * the appropriate bypass via UTIL_ValidationRule.
	 *
	 * @param request The bypass request containing the bypass type and name
	 *
	 * @throws System.NoSuchElementException if the bypass type is not a valid VALIDATION_BYPASS_TYPE value
	 */
	private static void processRequest(DTO_Request request)
	{
		if(String.isBlank(request.name))
		{
			return;
		}

		String bypassTypeString = String.isNotBlank(request.bypassType) ? request.bypassType.toUpperCase() : 'OBJECT_NAME';

		try
		{
			UTIL_ValidationRule.bypass(request.name, UTIL_ValidationRule.VALIDATION_BYPASS_TYPE.valueOf(bypassTypeString));
		}
		catch(Exception error)
		{
			error.setMessage(ERROR_INVALID_BYPASS_TYPE);
			throw error;
		}
	}

	/**
	 * @description Request DTO for the Bypass Validation invocable action.
	 * Specifies which validation rules to bypass by type (object, group, or rule) and name.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Request
	{
		/**
		 * @description The type of bypass to apply. Determines how the Name field is interpreted.
		 * Valid values are:
		 * - OBJECT_NAME: Bypasses all validation rules for the specified SObject type
		 * - GROUP_NAME: Bypasses all validation rules in the specified ValidationRuleGroup__mdt
		 * - RULE_NAME: Bypasses a specific ValidationRule__mdt by its DeveloperName
		 * Defaults to OBJECT_NAME if not specified.
		 *
		 * To clear bypasses, use the FLOW_ClearValidationBypass action instead.
		 *
		 * @since 1.0
		 */
		@SuppressWarnings('LongLine')
		@InvocableVariable
		(
				Label='Bypass Type'
				Description='Pick Object to bypass all validation rules on an object, Rule Group to bypass one rule group, or Rule to bypass a single rule. Stored values are OBJECT_NAME, GROUP_NAME, and RULE_NAME; the field shows the stored value.'
				DefaultValue='OBJECT_NAME'
				PlaceholderText='OBJECT_NAME'
		)
		global String bypassType;

		/**
		 * @description The name of the object, group, or rule to bypass. Interpretation depends on bypassType:
		 * - For OBJECT_NAME: The SObject API name (e.g., 'Account', 'MyCustomObject__c')
		 * - For GROUP_NAME: The ValidationRuleGroup__mdt DeveloperName
		 * - For RULE_NAME: The ValidationRule__mdt DeveloperName
		 * Required for all bypass types.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				Label='Name'
				Description='Object API name, group DeveloperName, or rule DeveloperName to bypass.'
				PlaceholderText='Account'
				Required=true
		)
		global String name;
	}
}