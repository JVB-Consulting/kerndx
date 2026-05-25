// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Flow invocable action to clear validation rule bypasses for the current transaction.
 * Use this after DML operations in Flow to explicitly clear bypasses set by FLOW_BypassValidation.
 *
 * **Important:** While bypasses are automatically cleared at the end of the transaction,
 * explicitly clearing them after DML improves code clarity and prevents accidental bypass
 * of subsequent validation in the same transaction.
 *
 * @see UTIL_ValidationRule
 * @see FLOW_BypassValidation
 *
 * @author Jason van Beukering
 *
 * @group Validation
 *
 * @date January 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * // Flow Configuration - Clear specific bypass:
 * Action: Clear Validation Bypass
 * Input:
 *   - Name: Account
 * // Flow Configuration - Clear all bypasses:
 * Action: Clear Validation Bypass
 * Input:
 *   - ClearAll: true
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_ClearValidationBypass
{
	/**
	 * @description Clears validation rule bypasses for the current transaction.
	 * If clearAll is true, all active bypasses are removed. Otherwise, the specified
	 * name is removed from all bypass lists (object, group, and rule).
	 *
	 * @param requests List of clear bypass requests
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Clear Account bypass
	 * FLOW_ClearValidationBypass.DTO_Request request = new FLOW_ClearValidationBypass.DTO_Request();
	 * request.name = 'Account';
	 * FLOW_ClearValidationBypass.clearBypass(new List<FLOW_ClearValidationBypass.DTO_Request>{request});
	 * ```
	 */
	@InvocableMethod
	(
			Category='Validation'
			Label='Clear Validation Bypass'
			Description='Clears validation rule bypasses for an object, group, or specific rule for the current transaction.'
	)
	global static void clearBypass(List<DTO_Request> requests)
	{
		for(DTO_Request request : requests)
		{
			processRequest(request);
		}
	}

	/**
	 * @description Processes a single clear bypass request.
	 *
	 * @param request The clear bypass request
	 */
	private static void processRequest(DTO_Request request)
	{
		if(UTIL_Boolean.isTrue(request.clearAll))
		{
			UTIL_ValidationRule.clearAllBypasses();
			return;
		}

		if(String.isBlank(request.name))
		{
			return;
		}

		UTIL_ValidationRule.clearBypass(request.name);
	}

	/**
	 * @description Request DTO for the Clear Validation Bypass invocable action.
	 * Specifies which bypass to clear by name or clears all bypasses.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Request
	{
		/**
		 * @description When true, clears all active bypasses. The Name field is ignored.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				Label='Clear All'
				Description='When true, clears all active bypasses (Name is ignored)'
		)
		global Boolean clearAll;

		/**
		 * @description The name of the bypassed object, group, or rule to clear.
		 * This should match the name used when creating the bypass with FLOW_BypassValidation.
		 * The bypass is cleared from all lists (object, group, and rule) regardless of how it was set.
		 * Ignored when clearAll is true.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				Label='Name'
				Description='Object API name, group DeveloperName, or rule DeveloperName to clear from bypass list.'
				PlaceholderText='Account'
		)
		global String name;
	}
}