// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A scheduled job that deletes records from a specified Salesforce object based on age or all records, configurable via attributes.
 *
 * @see SCHED_Base
 * @see SCHED_PurgeRecords_TEST
 * @see UTIL_PurgeRecords
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
 * SCHED_PurgeRecords job = new SCHED_PurgeRecords();
 * DTO_NameValues attributes = new DTO_NameValues();
 * attributes.add('objectName', 'LogEntry__c');
 * attributes.add('minimumNumberOfDays', '30');
 * job.setParameterValues(attributes);
 * System.schedule('Purge Old Logs', '0 0 1 * * ?', job);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SCHED_PurgeRecords extends SCHED_Base
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
	 * @description Optional parameter for date field API name. Defaults to CreatedDate.
	 */
	@TestVisible
	private static final String OPTIONAL_PARAMETER_DATE_FIELD_NAME = 'dateFieldName';
	/**
	 * @description Optional parameter for minimum record age in days. If omitted, all records are deleted.
	 */
	public static final String OPTIONAL_PARAMETER_MINIMUM_NUMBER_OF_DAYS = 'minimumNumberOfDays';
	/**
	 * @description Required parameter for the object API name to purge records from.
	 */
	public static final String REQUIRED_PARAMETER_OBJECT_NAME = 'objectName';

	/**
	 * @description Executes the scheduled job, deleting records from the specified object. Deletes records older than the specified number of days if provided;
	 * otherwise, deletes all records.
	 *
	 * @param context The SchedulableContext for the scheduled job execution.
	 *
	 * @example
	 * ```apex
	 * // Schedule a job to delete Contact records older than 30 days based on LastModifiedDate
	 * SCHED_PurgeRecords purgeJob = new SCHED_PurgeRecords();
	 * DTO_NameValues attributes = new DTO_NameValues();
	 * attributes.put(SCHED_PurgeRecords.REQUIRED_PARAMETER_OBJECT_NAME, 'Contact');
	 * attributes.put(SCHED_PurgeRecords.OPTIONAL_PARAMETER_DATE_FIELD_NAME, 'LastModifiedDate');
	 * attributes.put(SCHED_PurgeRecords.OPTIONAL_PARAMETER_MINIMUM_NUMBER_OF_DAYS, '30');
	 * attributes.put(SCHED_PurgeRecords.OPTIONAL_PARAMETER_ALL_OR_NOTHING, 'true');
	 * attributes.put(SCHED_PurgeRecords.OPTIONAL_PARAMETER_BATCH_SIZE, '500');
	 * purgeJob.setParameterValues(attributes);
	 * System.schedule('Purge Old Contacts', '0 0 0 * * ?', purgeJob);
	 * ```
	 */
	public void execute(SchedulableContext context)
	{
		Integer minimumNumberOfDays = getNumericParameter(OPTIONAL_PARAMETER_MINIMUM_NUMBER_OF_DAYS);

		if(minimumNumberOfDays != null && minimumNumberOfDays > 0)
		{
			UTIL_PurgeRecords.deleteOlderThanNDays
					(
							getTextParameter(REQUIRED_PARAMETER_OBJECT_NAME),
							getTextParameter(OPTIONAL_PARAMETER_DATE_FIELD_NAME),
							minimumNumberOfDays,
							getBooleanParameter(OPTIONAL_PARAMETER_ALL_OR_NOTHING),
							getNumericParameter(OPTIONAL_PARAMETER_BATCH_SIZE)
					);
		}
		else
		{
			UTIL_PurgeRecords.deleteAllRecords
					(
							getTextParameter(REQUIRED_PARAMETER_OBJECT_NAME),
							getBooleanParameter(OPTIONAL_PARAMETER_ALL_OR_NOTHING),
							getNumericParameter(OPTIONAL_PARAMETER_BATCH_SIZE)
					);
		}
	}

	/**
	 * @description Returns the parameter definitions supported by this scheduled job.
	 *
	 * @return List of parameter definitions for object name, days threshold, date field, batch size, and transaction behavior.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<DTO_ScheduledParameterDefinition> parameters = new SCHED_PurgeRecords().getParameterDefinitions();
	 * ```
	 */
	public override List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
	{
		return new List<DTO_ScheduledParameterDefinition>
		{
				DTO_ScheduledParameterDefinition.of(REQUIRED_PARAMETER_OBJECT_NAME)
						.required().
						withDescription('API name of the SObject to purge records from'),
				DTO_ScheduledParameterDefinition.of(OPTIONAL_PARAMETER_MINIMUM_NUMBER_OF_DAYS, 'Minimum Age (Days)')
						.asNumeric()
						.withDescription('Delete records older than this many days. If omitted, all records are deleted.'),
				DTO_ScheduledParameterDefinition.of(OPTIONAL_PARAMETER_DATE_FIELD_NAME)
						.withDefault('CreatedDate')
						.withDescription('API name of the date field to evaluate for record age'),
				DTO_ScheduledParameterDefinition.of(OPTIONAL_PARAMETER_BATCH_SIZE)
						.asNumeric()
						.withDefault('2000')
						.withDescription('Number of records per DML batch'),
				DTO_ScheduledParameterDefinition.of(OPTIONAL_PARAMETER_ALL_OR_NOTHING)
						.asBoolean()
						.withDefault('false')
						.withDescription('When true, a single failure aborts the entire job')
		};
	}
}