// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Scheduled job to automatically deactivate users who haven't logged in for a specified number of days.
 * Configurable with parameters such as profile names, minimum inactivity days, batch size, and transaction behavior.
 *
 * @see SCHED_Base
 * @see SCHED_DeactivateUsers_TEST
 * @see UTIL_BulkUpdates.deactivateUsers
 *
 * @author Jason van Beukering
 *
 * @group Bulk DML
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * SCHED_DeactivateUsers job = new SCHED_DeactivateUsers();
 * DTO_NameValues attributes = new DTO_NameValues();
 * attributes.add('profileNames', 'Standard User|Chatter Free User');
 * attributes.add('minimumNumberOfDays', '90');
 * job.setParameterValues(attributes);
 * System.schedule('Deactivate Inactive Users', '0 0 2 * * ?', job);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SCHED_DeactivateUsers extends SCHED_Base
{
	/**
	 * @description Optional parameter for all-or-nothing transaction behavior. Defaults to false.
	 */
	@TestVisible
	private static final String OPTIONAL_PARAMETER_ALL_OR_NOTHING = 'allOrNothing';
	/**
	 * @description Optional parameter for batch size. Defaults to 2000.
	 */
	@TestVisible
	private static final String OPTIONAL_PARAMETER_BATCH_SIZE = 'batchSize';
	/**
	 * @description Required parameter for pipe-separated profile names to target.
	 */
	@TestVisible
	private static final String REQUIRED_PARAMETER_PROFILE_NAMES = 'profileNames';
	/**
	 * @description Required parameter for minimum inactive days before deactivation.
	 */
	@TestVisible
	private static final String REQUIRED_PARAMETER_MINIMUM_NUMBER_OF_DAYS = 'minimumNumberOfDays';

	/**
	 * @description Executes the deactivation job, invoking `UTIL_BulkUpdates.deactivateUsers` with configured parameters.
	 *
	 * @param context The `SchedulableContext` providing job execution details.
	 *
	 * @example
	 * ```apex
	 * // Schedule the job to deactivate users who haven't logged in for 90 days
	 * System.schedule('Deactivate Inactive Users', '0 0 12 * * ?', new SCHED_DeactivateUsers());
	 * ```
	 */
	public void execute(SchedulableContext context)
	{
		String profileNamesValue = getTextParameter(REQUIRED_PARAMETER_PROFILE_NAMES);
		Set<String> profileNames = new Set<String>(UTIL_String.splitByWholeSeparator(profileNamesValue, '|'));

		UTIL_BulkUpdates.deactivateUsers
				(
						profileNames,
						getNumericParameter(REQUIRED_PARAMETER_MINIMUM_NUMBER_OF_DAYS),
						getNumericParameter(OPTIONAL_PARAMETER_BATCH_SIZE),
						getBooleanParameter(OPTIONAL_PARAMETER_ALL_OR_NOTHING)
				);
	}

	/**
	 * @description Returns the parameter definitions supported by this scheduled job.
	 *
	 * @return List of parameter definitions for profile names, inactivity days, batch size, and transaction behavior.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<DTO_ScheduledParameterDefinition> parameters = new SCHED_DeactivateUsers().getParameterDefinitions();
	 * ```
	 */
	public override List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
	{
		return new List<DTO_ScheduledParameterDefinition>
		{
				DTO_ScheduledParameterDefinition.of(REQUIRED_PARAMETER_PROFILE_NAMES)
						.required()
						.withDescription('Pipe-separated profile names to target for deactivation'),
				DTO_ScheduledParameterDefinition.of(REQUIRED_PARAMETER_MINIMUM_NUMBER_OF_DAYS, 'Minimum Inactive Days')
						.asNumeric()
						.required().
						withDescription('Users inactive for at least this many days will be deactivated'),
				DTO_ScheduledParameterDefinition.of(OPTIONAL_PARAMETER_BATCH_SIZE)
						.asNumeric()
						.withDefault('2000')
						.withDescription('Number of records per DML batch'),
				DTO_ScheduledParameterDefinition.of(OPTIONAL_PARAMETER_ALL_OR_NOTHING).asBoolean()
						.withDefault('false')
						.withDescription('When true, a single failure aborts the entire job')
		};
	}
}