// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Abstract base class for scheduled jobs that support configurable parameters.
 * Implements IF_Schedulable, providing parameter storage, typed parameter resolution, and a default
 * empty parameter definition list. Subscribers extend this class, override `getParameterDefinitions()`
 * to declare their parameters, and implement `execute(SchedulableContext)` for job logic.
 *
 * When `setParameterValues()` is called by the framework, the base class resolves raw string values
 * into typed values (String, Integer, Boolean) based on the DataType declared in `getParameterDefinitions()`,
 * applying default values where configured. Subclasses read typed values via `getTextParameter()`,
 * `getNumericParameter()`, and `getBooleanParameter()`.
 *
 * @see DTO_NameValues
 * @see DTO_ScheduledParameterDefinition
 * @see IF_Schedulable
 * @see SCHED_Base_TEST
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
 * global class SCHED_MyJob extends SCHED_Base
 * {
 *     public override List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
 *     {
 *         return new List<DTO_ScheduledParameterDefinition>
 *         {
 *             DTO_ScheduledParameterDefinition.of('objectName').required(),
 *             DTO_ScheduledParameterDefinition.of('batchSize').asNumeric().withDefault('2000')
 *         };
 *     }
 *     public void execute(SchedulableContext context)
 *     {
 *         String objectName = getTextParameter('objectName');
 *         Integer batchSize = getNumericParameter('batchSize');
 *     }
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global abstract inherited sharing class SCHED_Base implements IF_Schedulable
{
	/**
	 * @description Raw parameter values provided to this scheduled job at scheduling time.
	 */
	private DTO_NameValues attributes
	{
		get
		{
			if(attributes == null)
			{
				attributes = new DTO_NameValues();
			}
			return attributes;
		}
		set
		{
			attributes = value;
			resolveParameters();
		}
	}

	/**
	 * @description Resolved parameter values, typed according to their DataType declarations.
	 */
	private final Map<String, Object> parameterValues
	{
		get
		{
			if(parameterValues == null)
			{
				parameterValues = new Map<String, Object>();
			}
			return parameterValues;
		}
		private set;
	}

	/**
	 * @description Stores the provided parameter values. The property setter automatically
	 * resolves raw values into typed parameters.
	 *
	 * @param parameterValues The name-value pairs containing the resolved parameter values.
	 *
	 * @since 1.0
	 */
	global void setParameterValues(DTO_NameValues parameterValues)
	{
		this.attributes = parameterValues;
	}

	/**
	 * @description Returns the parameter definitions supported by this scheduled job.
	 * Override in subclasses to declare parameters for dynamic form rendering.
	 * Returns an empty list by default.
	 *
	 * @return List of parameter definitions.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * public override List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
	 * {
	 *     return new List<DTO_ScheduledParameterDefinition>
	 *     {
	 *         DTO_ScheduledParameterDefinition.of('batchSize').asNumeric()
	 *             .withDefault('2000')
	 *     };
	 * }
	 * ```
	 */
	global virtual List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
	{
		return new List<DTO_ScheduledParameterDefinition>();
	}

	/**
	 * @description Returns a TEXT parameter value.
	 *
	 * @param name The parameter name.
	 *
	 * @return The string value, or null if not set.
	 *
	 * @since 1.0
	 */
	global String getTextParameter(String name)
	{
		return (String)parameterValues.get(name);
	}

	/**
	 * @description Returns a NUMERIC parameter value.
	 *
	 * @param name The parameter name.
	 *
	 * @return The integer value, or null if not set or not numeric.
	 *
	 * @since 1.0
	 */
	global Integer getNumericParameter(String name)
	{
		return (Integer)parameterValues.get(name);
	}

	/**
	 * @description Returns a FLAG (boolean) parameter value.
	 *
	 * @param name The parameter name.
	 *
	 * @return The boolean value, defaulting to false if not set.
	 *
	 * @since 1.0
	 */
	global Boolean getBooleanParameter(String name)
	{
		Boolean value = (Boolean)parameterValues.get(name);
		return value != null ? value : false;
	}

	/**
	 * @description Resolves raw string attributes into typed values using the parameter definitions
	 * from `getParameterDefinitions()`. Applies default values when the raw attribute is blank.
	 */
	private void resolveParameters()
	{
		for(DTO_ScheduledParameterDefinition parameter : getParameterDefinitions())
		{
			String rawValue = attributes.exists(parameter.name, false) ? attributes.get(parameter.name) : parameter.defaultValue;
			parameterValues.put(parameter.name, convertValue(rawValue, parameter.dataType));
		}
	}

	/**
	 * @description Converts a raw string value to its typed representation based on the DataType.
	 *
	 * @param rawValue The raw string value to convert.
	 * @param dataType The DataType enum value.
	 *
	 * @return The typed value: String for TEXT, Integer for NUMERIC, Boolean for FLAG.
	 */
	private static Object convertValue(String rawValue, String dataType)
	{
		if(rawValue == null)
		{
			return null;
		}

		switch on dataType
		{
			when 'NUMERIC'
			{
				return rawValue.isNumeric() ? Integer.valueOf(rawValue) : null;
			}
			when 'FLAG'
			{
				return UTIL_Boolean.toBoolean(rawValue);
			}
			when else
			{
				return rawValue;
			}
		}
	}
}