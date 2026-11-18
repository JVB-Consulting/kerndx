// SPDX-License-Identifier: Apache-2.0
/**
 * @description Manages scheduling and termination of Apex jobs based on the `ScheduledJob__c` custom object.
 * Handles job creation, updates, and deletion with support for configurable attributes and cron expressions.
 * A record in job-runner mode never gets a platform job: the trigger seeds its next-run cursor instead. Only a user with
 * the Manage Job Runner permission can put a job on the job runner, change a job that is on it, or take a job off it.
 * Writes of the framework-owned run fields re-enter neither validation nor scheduling, so they need no permission.
 * A job restored from the Recycle Bin comes back switched off, so it runs again only after a normal save turns it on.
 * The action runs on every save of a job, also a save made from inside another trigger action or from a flow that such
 * an action started: it implements `TRG_Dispatcher.NestedSaveGuard`, so the permission checks, the guard on the job
 * runner's own records, the cursor seeding and the scheduling all run there too. It does not start again while it is
 * already running, so a job saved from inside this action itself is not checked.
 *
 * @see ScheduledJob__c
 * @see TRG_ScheduleJob_TEST
 * @see TRG_Base
 * @see TRG_Dispatcher
 * @see IF_Trigger
 * @see UTIL_ScheduledJobRunner
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, November 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
public inherited sharing class TRG_ScheduleJob extends TRG_Base implements
				IF_Trigger.BeforeInsert,
				IF_Trigger.BeforeUpdate,
				IF_Trigger.BeforeDelete,
				IF_Trigger.AfterUndelete,
				TRG_Dispatcher.NestedSaveGuard
{
	/**
	 * @description Set to true by Health Check's Activate, Repair and Deactivate around their writes of the runner's own
	 * records, which every other path is refused: a save re-owns a record's CronTrigger to the saving user, and the
	 * runner's records decide who every job on the runner runs as.
	 */
	public static Boolean allowRunnerRecordManagement = false;

	/**
	 * @description Set to true by Health Check around its move of a watchdog off a job runner that has stopped, so that the
	 * move works for a user without the Manage Job Runner permission. It lets a job leave the job runner and nothing else:
	 * the save must change only the execution mode, from the job runner to a scheduled job of its own. Any other change
	 * to a job on the job runner still needs the permission while it is set.
	 */
	public static Boolean allowLeavingTheJobRunner = false;

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
	 * Only Health Check may delete one of the job runner's own records, because deleting one stops the runner at that
	 * minute mark. Deleting a job on the job runner takes it off the runner, so that needs the Manage Job Runner
	 * permission too.
	 *
	 * @param oldRecords The `ScheduledJob__c` records being deleted.
	 */
	public void beforeDelete(List<SObject> oldRecords)
	{
		for(SObject record : oldRecords)
		{
			ScheduledJob__c scheduler = (ScheduledJob__c)record;

			if(UTIL_ScheduledJobRunner.isRunnerRecord(scheduler) && !allowRunnerRecordManagement)
			{
				scheduler.addError(System.Label.ScheduledJob_RunnerRecordManagedByHealthCheck);
				continue;
			}

			if(UTIL_ScheduledJobRunner.isJobRunnerMode(scheduler) && !UTIL_ScheduledJobRunner.hasManagePermission())
			{
				scheduler.addError(System.Label.ScheduledJob_ManageJobRunnerPermissionRequired);
				continue;
			}

			stopJob(scheduler);
		}
	}

	/**
	 * @description Handles logic after `ScheduledJob__c` records are restored from the Recycle Bin. Every restored job
	 * comes back switched off. Deleting the job normally stopped its platform job already. The restore tries to stop it
	 * once more, in case that stop failed, and then clears the stored id of that platform job.
	 *
	 * The restore never schedules a platform job. Someone turns the job back on in the editor, and that save runs every normal check.
	 *
	 * One of the job runner's own records cannot be restored from the Recycle Bin. To bring the job runner back, use
	 * Activate or Repair in Health Check.
	 *
	 * The save that switches the jobs off is made from inside this action. The framework does not start an action again
	 * while it is already running, so this action does not check that save. That is how a user without the Manage Job
	 * Runner permission can restore a job that was on the job runner: the user changes nothing about the job, the
	 * framework only switches it off.
	 *
	 * For the same reason, this action also does not check any other save of a job that a trigger action or a flow makes
	 * while the switch-off save runs.
	 *
	 * If the switch-off save fails, for example because a validation rule refuses it, the restore is refused too, and
	 * the error is logged. A restored job must never come back switched on. The jobs are switched off in one save, so if
	 * it fails, every job in the restore that needed switching off is refused, not only the one that caused the failure.
	 * Jobs that were already off are still restored.
	 *
	 * @param newRecords The restored `ScheduledJob__c` records.
	 */
	public void afterUndelete(List<SObject> newRecords)
	{
		List<ScheduledJob__c> restoredJobsToSwitchOff = new List<ScheduledJob__c>();
		List<ScheduledJob__c> jobsToSwitchOff = new List<ScheduledJob__c>();

		for(SObject record : newRecords)
		{
			ScheduledJob__c scheduler = (ScheduledJob__c)record;

			if(UTIL_ScheduledJobRunner.isRunnerRecord(scheduler) && !allowRunnerRecordManagement)
			{
				scheduler.addError(System.Label.ScheduledJob_RunnerRecordManagedByHealthCheck);
				continue;
			}

			if(scheduler.IsActive__c || String.isNotBlank(scheduler.ScheduledJobId__c))
			{
				stopPlatformJobLeftRunning(scheduler);
				restoredJobsToSwitchOff.add(scheduler);
				jobsToSwitchOff.add(new ScheduledJob__c(Id = scheduler.Id, IsActive__c = false, ScheduledJobId__c = null));
			}
		}

		if(jobsToSwitchOff.isEmpty())
		{
			return;
		}

		try
		{
			DML_Builder.newTransaction().systemModeInternal().doUpdate(jobsToSwitchOff).execute();
		}
		catch(Exception error)
		{
			LOG_Builder.build().error(error).at(TRG_ScheduleJob.class.getName() + '/afterUndelete').emit();

			for(ScheduledJob__c restored : restoredJobsToSwitchOff)
			{
				restored.addError(System.Label.ScheduledJob_RestoreNotSwitchedOff);
			}
		}
	}

	/**
	 * @description Stops the platform job a restored job still points at, in case stopping it failed when the job was
	 * deleted. Usually the delete already stopped it, so the stop fails here, and that failure is expected and ignored.
	 * When the stop failed at the delete, the delete already logged that failure.
	 *
	 * @param scheduler The restored `ScheduledJob__c` record.
	 */
	@SuppressWarnings('PMD.EmptyCatchBlock')
	private static void stopPlatformJobLeftRunning(ScheduledJob__c scheduler)
	{
		if(String.isBlank(scheduler.ScheduledJobId__c))
		{
			return;
		}

		try
		{
			System.abortJob(scheduler.ScheduledJobId__c);
		}
		catch(Exception alreadyStopped)
		{
			// The delete already stopped this platform job, which is the usual case.
		}
	}

	/**
	 * @description Routes one record: runner records are Health Check's, framework writes of a job-runner record's run
	 * fields are ignored, then any other change to a job that is or was on the job runner needs the Manage Job Runner
	 * permission, job-runner records are seeded, and own-mode records are scheduled or stopped as before. The runner
	 * guard comes first because the runner's own records receive no framework writes, so nothing may reach them ahead of
	 * it: the no-op check exists for the run fields of the records the runner checks and for description edits. An edit of
	 * only a runner record's description is therefore still refused outside Health Check. The permission check comes after
	 * the no-op check, so the job runner can still write a job's run fields when the running user does not hold the permission.
	 * Health Check's allowance for moving a watchdog off a stopped job runner lets only that move skip the permission.
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

		if(isJobRunnerSave(scheduler, previous) && !isAllowedLeavingOfTheJobRunner(scheduler, previous) && !UTIL_ScheduledJobRunner.hasManagePermission())
		{
			scheduler.ExecutionMode__c.addError(System.Label.ScheduledJob_ManageJobRunnerPermissionRequired);
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
	 * @description Whether a save that changes how a job behaves touches the job runner, reading the record both as it is
	 * being saved and as it was before. A job that is going onto the runner, is on it, or is leaving it counts, so a user
	 * without the Manage Job Runner permission cannot change a job on the runner by taking it off in the same save.
	 *
	 * @param scheduler The record as it is being saved.
	 * @param previous The record before the save, or null on insert.
	 *
	 * @return True when the job is in job-runner mode before the save or after it.
	 */
	private static Boolean isJobRunnerSave(ScheduledJob__c scheduler, ScheduledJob__c previous)
	{
		return UTIL_ScheduledJobRunner.isJobRunnerMode(scheduler) || (previous != null && UTIL_ScheduledJobRunner.isJobRunnerMode(previous));
	}

	/**
	 * @description Whether Health Check's allowance lets this save through without the Manage Job Runner permission. That
	 * is only so when the allowance is set, the job was on the job runner before the save, the save moves it to a
	 * scheduled job of its own, and no other field that changes how the job behaves is changed.
	 *
	 * @param scheduler The record as it is being saved.
	 * @param previous The record before the save, or null on insert.
	 *
	 * @return True when the save only takes the job off the job runner and the allowance is set.
	 */
	private static Boolean isAllowedLeavingOfTheJobRunner(ScheduledJob__c scheduler, ScheduledJob__c previous)
	{
		if(!allowLeavingTheJobRunner || previous == null || !UTIL_ScheduledJobRunner.isJobRunnerMode(previous)
				|| !UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB.equals(scheduler.ExecutionMode__c))
		{
			return false;
		}

		for(SObjectField field : JOB_BEHAVIOUR_FIELDS)
		{
			if(field != ScheduledJob__c.ExecutionMode__c && hasChanged(scheduler.get(field), previous.get(field)))
			{
				return false;
			}
		}

		return true;
	}

	/**
	 * @description Handles a record in job-runner mode, after the permission check: aborts any platform job left from a
	 * mode switch, validates the class and parameters exactly as own mode does, and seeds the cursor to the next future
	 * window when the expression, time zone, mode or active flag changed.
	 *
	 * @param scheduler The record as it is being saved.
	 * @param previous The record before the save, or null on insert.
	 */
	private static void manageJobRunnerRecord(ScheduledJob__c scheduler, ScheduledJob__c previous)
	{
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
