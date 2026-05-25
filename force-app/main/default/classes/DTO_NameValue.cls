// SPDX-License-Identifier: BUSL-1.1
/**
 * @description DTO class for name-value pairs, used in invocable methods for data mapping, such as merge fields or configuration settings.
 *
 * Designed for flexibility in flows, Aura components, or Apex logic, supporting scenarios like email template merge fields, parameter passing, or custom metadata updates.
 *
 * @see DTO_NameValue_TEST
 *
 * @author Jason van Beukering
 *
 * @group Data Transfer Objects
 *
 * @date September 2025, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * DTO_NameValue pair = new DTO_NameValue();
 * pair.name = 'MergeField';
 * pair.value = 'Hello World';
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class DTO_NameValue
{
	/**
	 * @description The name of the data field or placeholder, used as a key in invocable methods.
	 *
	 * @since 1.0
	 */
	@AuraEnabled
	@InvocableVariable
	(
			Label='Field Name'
			Description='The name of the data field or placeholder, used as a key in invocable methods (e.g., merge field placeholder or parameter key).'
			Required=true
	)
	global String name;

	/**
	 * @description The value associated with the field name, used for substitution or configuration.
	 *
	 * @since 1.0
	 */
	@AuraEnabled
	@InvocableVariable
	(
			Label='Field Value'
			Description='The value to associate with the field name, used for substitution or configuration in invocable methods (e.g., email body merge fields or parameter values).'
			Required=false
	)
	global String value;

	/**
	 * @description Constructs a new name-value pair with the specified key and value.
	 *
	 * @param name The name of the data field or placeholder.
	 * @param value The value associated with the field name.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_NameValue pair = new DTO_NameValue('MergeField', 'Hello World');
	 * ```
	 */
	global DTO_NameValue(String name, String value)
	{
		this.name = name;
		this.value = value;
	}

	/**
	 * @description Default no-argument constructor for flow and invocable compatibility.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_NameValue pair = new DTO_NameValue();
	 * pair.name = 'MergeField';
	 * pair.value = 'Hello World';
	 * ```
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock')
	global DTO_NameValue()
	{
	}
}