// SPDX-License-Identifier: Apache-2.0
/**
 * @description Manages scheduling and termination of Apex jobs based on the `ScheduledJob__c` custom object.
 * Handles job creation, updates, and deletion with support for configurable attributes and cron expressions.
 * A record in job-runner mode never gets a platform job: the trigger seeds its next-run cursor and refuses it without
 * the Manage Job Runner permission. Writes of the framework-owned run fields re-enter neither validation nor scheduling.
 *
 * @see ScheduledJob__c
 * @see TRG_ScheduleJob_TEST
 * @see TRG_Base
 * @see IF_Trigger
 * @see UTIL_ScheduledJobRunner
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
public inherited sharing class TRG_ScheduleJob extends TRG_Base implements
				IF_Trigger.BeforeInsert,
				IF_Trigger.BeforeUpdate,
				IF_Trigger.BeforeDelete
{
	/**
	 * @description Set to true by Health Check's Activate, Repair and Deactivate around their writes of the runner's own
	 * records, which every other path is refused: a save re-owns a record's CronTrigger to the saving user, and the
	 * runner's records decide who every job on the runner runs as.
	 */
	public static Boolean allowRunnerRecordManagement = false;

	/**
	 * @description The fields that change what a job runs, when it runs or how it runs. An update that changes none of them
	 * changes nothing for the trigger. That covers an edit of only the description and a framework write of the run fields.
	 * The description is left out on purpose. Saving an own-mode job again stops its platform job and schedules a new one
	 * owned by the user who saves, so a description edit would make the job run as that user.
	 */
	private static final List<SObjectField> JOB_BEHAVIOUR_FIELDS = new List<SObjectField>
	{
			ScheduledJob__c.SchedulerName__c, ScheduledJob__c.ClassName__c, ScheduledJob__c.CronExpression__c, ScheduledJob__c.IsActive__c,
			ScheduledJob__c.Parameters__c, ScheduledJob__c.Timezone__c, ScheduledJob__c.ExecutionMode__c, ScheduledJob__c.RunPriority__c,
			ScheduledJob__c.OverlapPolicy__c
	};

	/**
	 * @description The fields whose change re-seeds a job-runner record's cursor.
	 */
	private static final List<SObjectField> CURSOR_FIELDS = new List<SObjectField>
	{
			ScheduledJob__c.CronExpression__c, ScheduledJob__c.Timezone__c, ScheduledJob__c.ExecutionMode__c, ScheduledJob__c.IsActive__c
	};

	/**
	 * @description The fields whose change makes a job on the runner run different code, so that changing either of them
	 * needs the same permission as putting the job on the runner in the first place.
	 */
	private static final List<SObjectField> DEFINITION_FIELDS = new List<SObjectField>
	{
			ScheduledJob__c.ClassName__c, ScheduledJob__c.Parameters__c
	};

	/**
	 * @description Handles logic before inserting `ScheduledJob__c` records. Schedules, stops or seeds each record according to its mode.
	 *
	 * @param newRecords The `ScheduledJob__c` records being inserted.
	 */
	public void beforeInsert(List<SObject> newRecords)
	{
		for(SObject record : newRecords)
		{
			manageJob((ScheduledJob__c)record, null);
		}
	}

	/**
	 * @description Handles logic before updating `ScheduledJob__c` records. A write that changes only framework-owned fields or the
	 * description is ignored. The two lists are index-aligned, so each record is paired with its own previous state by position.
	 *
	 * @param newRecords The updated `ScheduledJob__c` records.
	 * @param oldRecords The previous state of the `ScheduledJob__c` records.
	 */
	public void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords)
	{
		for(Integer index = 0; index < newRecords.size(); index++)
		{
			manageJob((ScheduledJob__c)newRecords[index], (ScheduledJob__c)oldRecords[index]);
		}
	}

	/**
	 * @description Handles logic before deleting `ScheduledJob__c` records. Stops the associated platform job if there is one.
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
	 * @description Routes one record: runner records are Health Check's, framework writes of a job-runner record's run
	 * fields are ignored, job-runner records are seeded, own-mode records are scheduled or stopped as before. The runner
	 * guard comes first because the runner's own records receive no framework writes, so nothing may reach them ahead of
	 * it: the no-op check exists for the run fields of the records the runner checks and for description edits. An edit of
	 * only a runner record's description is therefore still refused outside Health Check.
	 *
	 * @param scheduler The record as it is being saved.
	 * @param previous The record before the save, or null on insert.
	 */
	private static void manageJob(ScheduledJob__c scheduler, ScheduledJob__c previous)
	{
		if(isRunnerRecordSave(scheduler, previous) && !allowRunnerRecordManagement)
		{
			scheduler.addError(System.Label.ScheduledJob_RunnerRecordManagedByHealthCheck);
			return;
		}

		if(previous != null && !anyChanged(scheduler, previous, JOB_BEHAVIOUR_FIELDS))
		{
			return;
		}

		if(UTIL_ScheduledJobRunner.isJobRunnerMode(scheduler))
		{
			manageJobRunnerRecord(scheduler, previous);
			return;
		}

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
	 * @description Whether a save touches one of the job runner's own records, reading the record both as it is being
	 * saved and as it was before: a record that was the runner's before the save is still the runner's, so renaming its
	 * class away from the runner's schedulable cannot slip the record out of Health Check's hands.
	 *
	 * @param scheduler The record as it is being saved.
	 * @param previous The record before the save, or null on insert.
	 *
	 * @return True when either image names the runner's schedulable.
	 */
	private static Boolean isRunnerRecordSave(ScheduledJob__c scheduler, ScheduledJob__c previous)
	{
		return UTIL_ScheduledJobRunner.isRunnerRecord(scheduler) || UTIL_ScheduledJobRunner.isRunnerRecord(previous);
	}

	/**
	 * @description Handles a record in job-runner mode: gates entry and definition changes on the permission, aborts any
	 * platform job left from a mode switch, validates the class and parameters exactly as own mode does, and seeds the
	 * cursor to the next future window when the expression, time zone, mode or active flag changed.
	 *
	 * @param scheduler The record as it is being saved.
	 * @param previous The record before the save, or null on insert.
	 */
	private static void manageJobRunnerRecord(ScheduledJob__c scheduler, ScheduledJob__c previous)
	{
		Boolean enteringMode = previous == null || !UTIL_ScheduledJobRunner.isJobRunnerMode(previous);
		Boolean definitionChanged = previous != null && anyChanged(scheduler, previous, DEFINITION_FIELDS);

		if((enteringMode || definitionChanged) && !UTIL_ScheduledJobRunner.hasManagePermission())
		{
			scheduler.ExecutionMode__c.addError(System.Label.ScheduledJob_ManageJobRunnerPermissionRequired);
			return;
		}

		stopJob(scheduler);

		if(buildConfiguredJobInstance(scheduler) == null)
		{
			return;
		}

		if(previous == null || anyChanged(scheduler, previous, CURSOR_FIELDS))
		{
			seedCursor(scheduler);
		}
	}

	/**
	 * @description Seeds NextRunAt__c with the first fire time strictly after now, or refuses the expression on its field.
	 *
	 * @param scheduler The record as it is being saved.
	 */
	private static void seedCursor(ScheduledJob__c scheduler)
	{
		try
		{
			Datetime next = UTIL_CronExpression.nextFireTime(scheduler.CronExpression__c, Datetime.now(), scheduler.Timezone__c);

			if(next == null)
			{
				scheduler.CronExpression__c.addError(System.Label.ScheduledJob_ExpressionCannotFireWithinHorizon);
				return;
			}

			scheduler.NextRunAt__c = next;
		}
		catch(Exception error)
		{
			scheduler.CronExpression__c.addError(error.getMessage());
		}
	}

	/**
	 * @description Builds the job the record describes and gives it its parameters, placing the error on the field that
	 * caused it when either step fails. Shared by both modes, and built once per save: a subscriber's setParameterValues
	 * may have side effects, so the instance this returns is the one that gets scheduled.
	 *
	 * @param scheduler The record as it is being saved.
	 *
	 * @return The configured job, or null when the record does not describe one.
	 */
	private static Schedulable buildConfiguredJobInstance(ScheduledJob__c scheduler)
	{
		try
		{
			Schedulable jobInstance = resolveJobInstance(scheduler.ClassName__c);

			try
			{
				injectParameters(jobInstance, deserializeAttributes(scheduler.Parameters__c));
			}
			catch(Exception error)
			{
				scheduler.Parameters__c.addError(error.getMessage());
				return null;
			}

			return jobInstance;
		}
		catch(Exception error)
		{
			scheduler.ClassName__c.addError(error.getMessage());
			return null;
		}
	}

	/**
	 * @description Whether any of the given fields differs between the saved and the previous record.
	 *
	 * @param scheduler The record as it is being saved.
	 * @param previous The record before the save.
	 * @param fields The fields to compare.
	 *
	 * @return True when at least one differs.
	 */
	private static Boolean anyChanged(ScheduledJob__c scheduler, ScheduledJob__c previous, List<SObjectField> fields)
	{
		for(SObjectField field : fields)
		{
			if(hasChanged(scheduler.get(field), previous.get(field)))
			{
				return true;
			}
		}

		return false;
	}

	/**
	 * @description Whether one field value differs from another, comparing text letter by letter. Apex reads two strings
	 * that differ only in letter case as equal, which would hide a real edit of a class name or a parameter value from
	 * the permission gate and from the re-schedule that an own-mode edit owes the administrator.
	 *
	 * @param savedValue The value as it is being saved.
	 * @param previousValue The value before the save.
	 *
	 * @return True when the two differ.
	 */
	private static Boolean hasChanged(Object savedValue, Object previousValue)
	{
		if(savedValue == null && previousValue == null)
		{
			return false;
		}

		if(savedValue == null || previousValue == null)
		{
			return true;
		}

		return !String.valueOf(savedValue).equals(String.valueOf(previousValue));
	}

	/**
	 * @description Starts an own-mode scheduled job: aborts any existing platform job, validates the class and parameters,
	 * and schedules the new job as the running user.
	 *
	 * @param scheduler The `ScheduledJob__c` record containing job details.
	 */
	private static void scheduleJob(ScheduledJob__c scheduler)
	{
		stopJob(scheduler);

		Schedulable jobInstance = buildConfiguredJobInstance(scheduler);

		if(jobInstance == null)
		{
			return;
		}

		try
		{
			DTO_NameValues attributes = deserializeAttributes(scheduler.Parameters__c);
			String adjustedCron = adjustCronForRunningUser(scheduler);
			scheduler.ScheduledJobId__c = System.schedule(buildJobName(scheduler, attributes), adjustedCron, jobInstance);
		}
		catch(Exception error)
		{
			scheduler.CronExpression__c.addError(error.getMessage());
		}
	}

	/**
	 * @description Resolves a class name to a new Schedulable instance. Shared by the trigger and the job runner, so a
	 * record is turned into a job the same way whichever mode runs it.
	 *
	 * @param className The Apex class name, qualified or bare.
	 *
	 * @return A new instance.
	 *
	 * @throws IllegalArgumentException When the class does not exist or is not a Schedulable (from UTIL_System).
	 */
	public static Schedulable resolveJobInstance(String className)
	{
		Type scheduleType = UTIL_System.getTypeForClassName(className, Schedulable.class);

		return (Schedulable)scheduleType.newInstance();
	}

	/**
	 * @description Gives a job its parameters when it declares any: refuses when a required one is blank, then hands the
	 * values to setParameterValues. A job that is not an IF_Schedulable takes no parameters and is left alone.
	 *
	 * @param jobInstance The job.
	 * @param attributes The parameter values from the record.
	 *
	 * @throws IllegalArgumentException Naming the missing required parameters.
	 */
	public static void injectParameters(Schedulable jobInstance, DTO_NameValues attributes)
	{
		if(!(jobInstance instanceof IF_Schedulable))
		{
			return;
		}

		IF_Schedulable configurable = (IF_Schedulable)jobInstance;
		List<String> missingParameters = getMissingRequiredParameters(configurable, attributes);

		if(!missingParameters.isEmpty())
		{
			throw new IllegalArgumentException('Missing required parameter' + (missingParameters.size() > 1 ? 's' : '') + ': ' + String.join(missingParameters, ', '));
		}

		configurable.setParameterValues(attributes);
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
	 * @description Deserializes the Parameters__c JSON value into a DTO_NameValues instance. Shared with the job runner,
	 * which reads a record's parameters the same way the trigger validates them.
	 *
	 * @param attributeValue The JSON-serialized Parameters__c field value.
	 *
	 * @return A DTO_NameValues instance populated from the JSON, or empty when blank.
	 */
	public static DTO_NameValues deserializeAttributes(String attributeValue)
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
