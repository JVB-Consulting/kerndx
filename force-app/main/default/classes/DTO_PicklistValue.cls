// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A Data Transfer Object (DTO) representing a single picklist value. This object includes
 * details about the picklist value's display label, API name, and any dependency
 * constraints if the picklist is a dependent picklist.
 *
 * @see FLOW_GetPicklistValues
 *
 * @author Jason van Beukering
 *
 * @group Data Transfer Objects
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * DTO_PicklistValue entry = new DTO_PicklistValue();
 * entry.label = 'Active';
 * entry.value = 'Active';
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class DTO_PicklistValue
{
	/**
	 * @description The display label of the picklist value, intended for use in the user interface (UI).
	 * This value is typically user-friendly and may differ from the API name of the picklist value.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String value = instance.label;
	 * ```
	 */
	@AuraEnabled
	@InvocableVariable(Label='Label' Description='The displayable value of the picklist' Required=true)
	global String label;
	/**
	 * @description If the picklist is a dependent picklist, the property contains a list of the controlling value indexes for which this value is valid.
	 * If the picklist is an independent picklist, the list is empty.
	 *
	 * @since 1.0
	 */
	@AuraEnabled
	@InvocableVariable
	(
			Label='ValidFor'
			Description='If the picklist is a dependent picklist, the property contains a list of the controlling values for which this value is valid'
			Required=false
	)
	global List<String> validFor;
	/**
	 * @description The API value of the picklist, used for programmatic access within Apex code and integrations.
	 * This value is often less user-friendly and is typically consistent across languages and locales.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String value = instance.value;
	 * ```
	 */
	@AuraEnabled
	@InvocableVariable(Label='Value' Description='The value of the picklist to use in the API' Required=true)
	global String value;
}