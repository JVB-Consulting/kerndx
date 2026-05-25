// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A Data Transfer Object (DTO) representing a single picklist and all associated values.
 * This class is typically used to retrieve and manage picklist values dynamically, often
 * for use in invocable actions.
 *
 * @see DTO_PickList_TEST
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
 * DTO_PickList picklist = new DTO_PickList();
 * picklist.picklistName = 'Status__c';
 * picklist.values = new List<DTO_PicklistValue>();
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class DTO_PickList
{
	/**
	 * @description The API name of the picklist field. This name is used for programmatic references
	 * and is case-sensitive.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String value = instance.picklistName;
	 * ```
	 */
	@AuraEnabled
	@InvocableVariable(Label='Api Name' Description='The API Name for the picklist' Required=true)
	global String picklistName;
	/**
	 * @description The default value for the picklist, represented as a `DTO_PicklistValue` object.
	 * If there is no default value, this field will be null.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_PicklistValue value = instance.defaultValue;
	 * ```
	 */
	@AuraEnabled
	@InvocableVariable(Label='Default Value' Description='The default value for the picklist, or null if there isn\'t one' Required=false)
	global DTO_PicklistValue defaultValue;
	/**
	 * @description A list of all available values for this picklist. Each entry is represented as a
	 * `DTO_PicklistValue` object, which includes both the label and API name of the value.
	 * This list corresponds to the field's available options and respects any record-type-specific
	 * or object-specific restrictions.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<DTO_PicklistValue> value = instance.values;
	 * ```
	 */
	@AuraEnabled
	@InvocableVariable(Label='Values' Description='A list of values for PickList field' Required=true)
	global List<DTO_PicklistValue> values;
}