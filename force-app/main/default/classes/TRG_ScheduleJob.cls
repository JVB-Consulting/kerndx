// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Manages scheduling and termination of Apex jobs based on the `ScheduledJob__c` custom object.
 * Handles job creation, updates, and deletion with support for configurable attributes and cron expressions.
 *
 * @see ScheduledJob__c
 * @see TRG_ScheduleJob_TEST
 * @see TRG_Base
 * @see IF_Trigger
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, May 2026
 */
public inherited sharing class TRG_ScheduleJob extends TRG_Base implements
				IF_Trigger.BeforeInsert,
				IF_Trigger.BeforeUpdate,
				IF_Trigger.BeforeDelete
{
	/**
	 * @description Handles logic before inserting `ScheduledJob__c` records. Initiates or stops the job based on the `IsActive__c` field.
	 *
	 * @param newRecords The `ScheduledJob__c` records being inserted.
	 */
	public void beforeInsert(List<SObject> newRecords)
	{
		for(SObject record : newRecords)
		{
			manageJob((ScheduledJob__c)record);
		}
	}

	/**
	 * @description Handles logic before updating `ScheduledJob__c` records. Initiates or stops the job based on the `IsActive__c` field.
	 *
	 * @param newRecords The updated `ScheduledJob__c` records.
	 * @param oldRecords The previous state of the `ScheduledJob__c` records.
	 */
	public void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords)
	{
		for(SObject record : newRecords)
		{
			manageJob((ScheduledJob__c)record);
		}
	}

	/**
	 * @description Handles logic before deleting `ScheduledJob__c` records. Stops the associated job if it exists.
	 *
	 * @param oldRecords The `ScheduledJob__c` records being deleted.
	 */
	public void beforeDelete(List<SObject> oldRecords)
	{
		for(SObject record : oldRecords)
		{
			stopJob((ScheduledJob__c)record);
		}
	}

	/**
	 * @description Determines whether to start or stop a job based on the `IsActive__c` field of the scheduler record.
	 *
	 * @param scheduler The `ScheduledJob__c` record to evaluate.
	 */
	private static void manageJob(ScheduledJob__c scheduler)
	{
		if(scheduler.IsActive__c)
		{
			scheduleJob(scheduler);
		}
		else
		{
			stopJob(scheduler);
		}
	}

	/**
	 * @description Starts a scheduled job based on the provided `ScheduledJob__c` record.
	 * Aborts any existing job, validates the class name and cron expression, and schedules the new job.
	 *
	 * @param scheduler The `ScheduledJob__c` record containing job details.
	 */
	private static void scheduleJob(ScheduledJob__c scheduler)
	{
		stopJob(scheduler);
		try
		{
			Type scheduleType = UTIL_System.getTypeForClassName(scheduler.ClassName__c, Schedulable.class);
			Schedulable jobInstance = (Schedulable)scheduleType.newInstance();
			DTO_NameValues attributes = deserializeAttributes(scheduler.Parameters__c);

			if(jobInstance instanceof IF_Schedulable)
			{
				IF_Schedulable configurable = (IF_Schedulable)jobInstance;

				List<String> missingParameters = getMissingRequiredParameters(configurable, attributes);
				if(!missingParameters.isEmpty())
				{
					scheduler.Parameters__c.addError('Missing required parameter' + (missingParameters.size() > 1 ? 's' : '') + ': ' + String.join(missingParameters, ', '));
					return;
				}

				try
				{
					configurable.setParameterValues(attributes);
				}
				catch(Exception error)
				{
					scheduler.Parameters__c.addError(error.getMessage());
					return;
				}
			}
			try
			{
				String adjustedCron = adjustCronForRunningUser(scheduler);
				scheduler.ScheduledJobId__c = System.schedule(buildJobName(scheduler, attributes), adjustedCron, jobInstance);
			}
			catch(Exception error)
			{
				scheduler.CronExpression__c.addError(error.getMessage());
			}
		}
		catch(Exception error)
		{
			scheduler.ClassName__c.addError(error.getMessage());
		}
	}

	/**
	 * @description Builds a human-readable job name for use in Setup > Scheduled Jobs.
	 * Format: `SchedulerName [key=value, key2=value2] (cron)` or `SchedulerName (cron)` when no attributes.
	 *
	 * @param scheduler The ScheduledJob__c record.
	 * @param attributes The deserialized attribute values.
	 *
	 * @return A formatted job name string.
	 */
	private static String buildJobName(ScheduledJob__c scheduler, DTO_NameValues attributes)
	{
		String jobName = scheduler.SchedulerName__c;

		if(!attributes.isEmpty())
		{
			jobName += ' [' + attributes.toParameterString() + ']';
		}

		jobName += ' (' + scheduler.CronExpression__c + ')';
		return jobName.left(UTIL_SObjectDescribe.getCachedFieldDescribe(CronJobDetail.Name).getLength());
	}

	/**
	 * @description Deserializes the Parameters__c JSON value into a DTO_NameValues instance.
	 *
	 * @param attributeValue The JSON-serialized Parameters__c field value.
	 *
	 * @return A DTO_NameValues instance populated from the JSON, or empty when blank.
	 */
	private static DTO_NameValues deserializeAttributes(String attributeValue)
	{
		if(String.isBlank(attributeValue) || attributeValue == UTIL_String.EMPTY_JSON_RESPONSE)
		{
			return new DTO_NameValues();
		}

		return (DTO_NameValues)new DTO_NameValues().deserialize(attributeValue);
	}

	/**
	 * @description Returns the labels of required parameters that are missing from the provided attributes.
	 *
	 * @param configurable The IF_Schedulable instance declaring parameter definitions.
	 * @param attributes The DTO_NameValues containing the provided attribute values.
	 *
	 * @return List of missing required parameter labels, empty if all are satisfied.
	 */
	private static List<String> getMissingRequiredParameters(IF_Schedulable configurable, DTO_NameValues attributes)
	{
		List<String> missingParameters = new List<String>();
		List<DTO_ScheduledParameterDefinition> dtoDefinitions = configurable.getParameterDefinitions();

		if(dtoDefinitions == null || dtoDefinitions.isEmpty())
		{
			return missingParameters;
		}

		for(DTO_ScheduledParameterDefinition dtoDefinition : dtoDefinitions)
		{
			if(dtoDefinition.isRequired && String.isBlank(attributes.get(dtoDefinition.name)))
			{
				missingParameters.add(dtoDefinition.label);
			}
		}

		return missingParameters;
	}

	/**
	 * @description Adjusts the cron expression for the running user's timezone. When the record has a stored
	 * timezone that differs from the running user, shifts the cron hours so the job fires at the originally
	 * intended absolute time. Returns the raw cron expression when no timezone is stored (backward compatible).
	 *
	 * @param scheduler The ScheduledJob__c record containing the cron expression and timezone.
	 *
	 * @return The timezone-adjusted cron expression, or the original when no adjustment is needed.
	 */
	private static String adjustCronForRunningUser(ScheduledJob__c scheduler)
	{
		if(String.isBlank(scheduler.Timezone__c))
		{
			return scheduler.CronExpression__c;
		}

		String runnerTimezone = UserInfo.getTimeZone().getID();

		if(scheduler.Timezone__c == runnerTimezone)
		{
			return scheduler.CronExpression__c;
		}

		return UTIL_CronExpression.shiftTimezone(
				scheduler.CronExpression__c,
				scheduler.Timezone__c,
				runnerTimezone
		);
	}

	/**
	 * @description Stops a scheduled job associated with the provided `ScheduledJob__c` record.
	 *
	 * @param scheduler The `ScheduledJob__c` record containing the job to stop.
	 */
	@TestVisible
	private static void stopJob(ScheduledJob__c scheduler)
	{
		if(String.isNotBlank(scheduler.ScheduledJobId__c) && !Trigger.isInsert)
		{
			try
			{
				System.abortJob(scheduler.ScheduledJobId__c);
			}
			catch(Exception error)
			{
				LOG_Builder.build().error(error).at(TRG_ScheduleJob.class.getName() + '/stopJob').forRecord(scheduler.Id).emit();
			}
		}

		if(!Trigger.isDelete)
		{
			scheduler.ScheduledJobId__c = null;
		}
	}
}