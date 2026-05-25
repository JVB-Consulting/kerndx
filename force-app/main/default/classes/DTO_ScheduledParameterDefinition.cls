// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A Data Transfer Object describing a single parameter definition supported by a scheduled job class.
 * Used by classes implementing IF_Schedulable to declare their configurable parameters via
 * `getParameterDefinitions()`, enabling dynamic form rendering in the scheduledJobEditor LWC component.
 * Uses a fluent builder pattern.
 *
 * @see IF_Schedulable
 * @see SCHED_Base
 * @see DTO_ScheduledParameterDefinition_TEST
 * @see DTO_JsonBase
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date March 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * DTO_ScheduledParameterDefinition.of('profileNames')
 *     .required()
 *     .withDescription('Pipe-separated profile names to target')
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
@JsonAccess(Serializable='always' Deserializable='always')
global inherited sharing class DTO_ScheduledParameterDefinition extends DTO_JsonBase
{
	/**
	 * @description Enumeration of supported input data types for scheduled job parameters.
	 *
	 * @since 1.0
	 */
	global enum DataType
	{
		/**
		 * @description Free-text string input.
		 */
		TEXT,
		/**
		 * @description Whole number input.
		 */
		NUMERIC,
		/**
		 * @description Boolean input.
		 */
		FLAG
	}

	/**
	 * @description The API name of the parameter (key used in DTO_NameValues).
	 *
	 * @since 1.0
	 */
	@AuraEnabled
	global String name;

	/**
	 * @description The user-facing display label for the parameter.
	 *
	 * @since 1.0
	 */
	@AuraEnabled
	global String label;

	/**
	 * @description Help text describing the parameter's purpose and expected format.
	 *
	 * @since 1.0
	 */
	@AuraEnabled
	global String description;

	/**
	 * @description Whether this parameter must be provided for the job to function.
	 *
	 * @since 1.0
	 */
	@AuraEnabled
	global Boolean isRequired;

	/**
	 * @description The input data type name determining which UI control to render.
	 * Stored as the DataType enum name string (TEXT, NUMERIC, FLAG) because the Aura
	 * transport serializes Apex enums as empty objects.
	 *
	 * @since 1.0
	 */
	@AuraEnabled
	global String dataType;

	/**
	 * @description The default value pre-populated when the parameter is not yet configured.
	 *
	 * @since 1.0
	 */
	@AuraEnabled
	global String defaultValue;

	/**
	 * @description Creates a new TEXT parameter definition with a label derived from the API name.
	 * Optional by default. Use `.withLabel()` to override the label,
	 * `.asNumeric()` or `.asBoolean()` to change the data type.
	 *
	 * @param name The API name of the parameter. Also used to generate the display label
	 * by splitting on camelCase boundaries (e.g., `'profileNames'` becomes `'Profile Names'`).
	 *
	 * @return A new DTO_ScheduledParameterDefinition instance with TEXT data type.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_ScheduledParameterDefinition.of('profileNames')
	 *     .required()
	 *     .withDescription('Pipe-separated profile names to target')
	 * ```
	 */
	global static DTO_ScheduledParameterDefinition of(String name)
	{
		return of(name, camelCaseToLabel(name));
	}

	/**
	 * @description Converts a camelCase API name to a human-readable label by inserting spaces
	 * before uppercase letters and capitalizing the first character.
	 *
	 * @param name The camelCase API name to convert.
	 *
	 * @return A human-readable label (e.g., `'profileNames'` becomes `'Profile Names'`).
	 */
	private static String camelCaseToLabel(String name)
	{
		if(String.isBlank(name))
		{
			return name;
		}

		String label = name.replaceAll('([a-z])([A-Z])', '$1 $2');
		return label.substring(0, 1).toUpperCase() + label.substring(1);
	}

	/**
	 * @description Creates a new TEXT parameter definition with an explicit label. Optional by default.
	 * Use `.asNumeric()` or `.asBoolean()` to change the data type.
	 *
	 * @param name The API name of the parameter.
	 * @param label The display label for the parameter.
	 *
	 * @return A new DTO_ScheduledParameterDefinition instance with TEXT data type.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_ScheduledParameterDefinition.of('minimumNumberOfDays', 'Minimum Age (Days)').asNumeric()
	 * ```
	 */
	global static DTO_ScheduledParameterDefinition of(String name, String label)
	{
		DTO_ScheduledParameterDefinition parameter = new DTO_ScheduledParameterDefinition();

		parameter.dataType = DTO_ScheduledParameterDefinition.DataType.TEXT.name();
		parameter.isRequired = false;
		parameter.label = label;
		parameter.name = name;

		return parameter;
	}

	/**
	 * @description Marks this parameter as required.
	 *
	 * @return This parameter instance for method chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_ScheduledParameterDefinition.of('objectName', 'Object Name').required()
	 * ```
	 */
	global DTO_ScheduledParameterDefinition required()
	{
		this.isRequired = true;
		return this;
	}

	/**
	 * @description Sets the data type to NUMERIC (whole number input).
	 *
	 * @return This parameter instance for method chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_ScheduledParameterDefinition.of('batchSize', 'Batch Size').asNumeric().withDefault('2000')
	 * ```
	 */
	global DTO_ScheduledParameterDefinition asNumeric()
	{
		this.dataType = DTO_ScheduledParameterDefinition.DataType.NUMERIC.name();
		return this;
	}

	/**
	 * @description Sets the data type to FLAG (boolean).
	 *
	 * @return This parameter instance for method chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_ScheduledParameterDefinition.of('allOrNothing', 'All or Nothing').asBoolean().withDefault('false')
	 * ```
	 */
	global DTO_ScheduledParameterDefinition asBoolean()
	{
		this.dataType = DTO_ScheduledParameterDefinition.DataType.FLAG.name();
		return this;
	}

	/**
	 * @description Sets the help text description for this parameter.
	 *
	 * @param description The description text to display as field-level help.
	 *
	 * @return This parameter instance for method chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_ScheduledParameterDefinition.of('profileNames', 'Profile Names')
	 *     .withDescription('Pipe-separated profile names to target')
	 * ```
	 */
	global DTO_ScheduledParameterDefinition withDescription(String description)
	{
		this.description = description;
		return this;
	}

	/**
	 * @description Sets the default value for this parameter.
	 *
	 * @param defaultValue The default value as a string.
	 *
	 * @return This parameter instance for method chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_ScheduledParameterDefinition.of('batchSize').asNumeric()
	 *     .withDefault('2000')
	 * ```
	 */
	global DTO_ScheduledParameterDefinition withDefault(String defaultValue)
	{
		this.defaultValue = defaultValue;
		return this;
	}
}