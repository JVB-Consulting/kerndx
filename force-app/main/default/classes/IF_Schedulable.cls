// SPDX-License-Identifier: BUSL-1.1
/**
 * @description An interface for a Schedulable class that can declare the parameters it supports
 * and receive validated parameter values at scheduling time. Enables dynamic form rendering
 * in the scheduledJobEditor LWC and required parameter validation by the trigger framework.
 *
 * Implementors have two paths:
 * - Extend `SCHED_Base` for built-in typed parameter resolution, default values, and accessors.
 * - Implement `IF_Schedulable` directly on an existing Schedulable class for full control.
 *
 * @see Schedulable
 * @see SCHED_Base
 * @see DTO_ScheduledParameterDefinition
 * @see DTO_NameValues
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date February 2026, May 2026
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
 *             DTO_ScheduledParameterDefinition.of('objectName').required()
 *         };
 *     }
 *     public void execute(SchedulableContext context) { }
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global interface IF_Schedulable extends Schedulable
{
	/**
	 * @description Returns the parameter definitions supported by this scheduled class.
	 * Used by the scheduledJobEditor LWC to render structured parameter forms
	 * and by the trigger framework for required parameter validation.
	 *
	 * @return List of parameter definitions, or an empty list if no parameters are supported.
	 *
	 * @since 1.0
	 */
	List<DTO_ScheduledParameterDefinition> getParameterDefinitions();

	/**
	 * @description Receives the validated parameter values at scheduling time.
	 * Called by the trigger framework after required parameter validation succeeds.
	 *
	 * @param parameterValues The name-value pairs containing the resolved parameter values.
	 *
	 * @since 1.0
	 */
	void setParameterValues(DTO_NameValues parameterValues);
}