// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Aura-enabled controller for the scheduledJobEditor LWC. Provides parameter definitions
 * for scheduled job classes and handles record persistence.
 *
 * @see CTRL_ScheduledJob_TEST
 * @see DTO_ScheduledParameterDefinition
 * @see IF_Schedulable
 * @see SEL_LogEntry
 * @see UTIL_ScheduledJobRunner
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date March 2026, October 2026
 */
public inherited sharing class CTRL_ScheduledJob
{
	/**
	 * @description Org cache key for the schedulable class name list.
	 */
	@TestVisible
	private static final String CACHE_KEY_SCHEDULABLE_CLASSES = 'SchedulableClasses';

	/**
	 * @description How long the schedulable class list stays in org Platform Cache, in seconds: eight hours. Finding the
	 * classes reads every Apex class in the org, so the list is kept; a class deployed after it was stored is missing from
	 * the editors' suggestions until it lapses, and the editors take its name typed in instead.
	 */
	private static final Integer CACHE_SECONDS_SCHEDULABLE_CLASSES = 28800;

	/**
	 * @description How many log entries the last-run lookup reads: only the newest one is offered.
	 */
	private static final Integer NEWEST_LOG_ENTRY_ROW_LIMIT = 1;

	/**
	 * @description Lazy-loaded list of Schedulable class names, kept in org Platform Cache for eight hours.
	 */
	private static final List<String> schedulableClassNames
	{
		get
		{
			if(schedulableClassNames == null)
			{
				Object cached = UTIL_Cache.org().get(CACHE_KEY_SCHEDULABLE_CLASSES);

				if(cached != null)
				{
					schedulableClassNames = (List<String>)cached;
				}
				else
				{
					schedulableClassNames = new SEL_ApexClass().findSchedulableClassNames();
					UTIL_Cache.org().put(CACHE_KEY_SCHEDULABLE_CLASSES, schedulableClassNames, CACHE_SECONDS_SCHEDULABLE_CLASSES);
				}
			}

			return schedulableClassNames;
		}
		private set;
	}

	/**
	 * @description Returns the names of all Apex classes in the org that implement the Schedulable interface, for the
	 * editors' class field to suggest. The list is kept in org Platform Cache for eight hours, because finding the classes
	 * reads every Apex class in the org; a class deployed since the list was stored is missing from it until then, and the
	 * editors accept its name typed in.
	 *
	 * @return List of class names that implement Schedulable (namespace-qualified for foreign packages).
	 */
	@AuraEnabled(cacheable=true)
	public static List<String> getSchedulableClasses()
	{
		return schedulableClassNames;
	}

	/**
	 * @description Retrieves the parameter definitions declared by a scheduled job class. Validates that the class exists
	 * and implements Schedulable. If it also implements IF_Schedulable, returns the parameter definitions; otherwise
	 * returns null so the LWC falls back to the raw attributes textarea. The editors call it as soon as a class name is
	 * picked or typed, so its refusal is how a misspelt name, or a class that cannot be scheduled, is caught before save.
	 *
	 * @param className The fully qualified Apex class name to inspect.
	 *
	 * @return List of parameter definitions, or null when the class is blank or does not implement IF_Schedulable.
	 *
	 * @throws AuraHandledException When the class cannot be resolved or is not a Schedulable.
	 */
	@AuraEnabled(cacheable=true)
	public static List<DTO_ScheduledParameterDefinition> getParameterDefinitions(String className)
	{
		if(String.isBlank(className))
		{
			return null;
		}

		try
		{
			Type classType = UTIL_System.getTypeForClassName(className, Schedulable.class);
			Object instance = classType.newInstance();

			if(instance instanceof IF_Schedulable)
			{
				return ((IF_Schedulable)instance).getParameterDefinitions();
			}

			return null;
		}
		catch(Exception error)
		{
			throw new AuraHandledException(error.getMessage());
		}
	}

	/**
	 * @description Returns the IANA timezone ID of the running user.
	 *
	 * @return The running user's TimeZoneSidKey (e.g., Africa/Johannesburg).
	 */
	@AuraEnabled(cacheable=true)
	public static String getUserTimezone()
	{
		return UserInfo.getTimeZone().getID();
	}

	/**
	 * @description Saves a ScheduledJob__c record with the provided field values. Inserts a new record
	 * when recordId is null; updates the existing record otherwise. Accepts a JSON string because LWC
	 * does not support inner class or Map deserialization for @AuraEnabled parameters.
	 *
	 * @param requestJson JSON-serialized SaveRequest containing all field values.
	 *
	 * @return The saved record ID.
	 */
	@AuraEnabled
	public static Id saveRecord(String requestJson)
	{
		SaveRequest request = (SaveRequest)JSON.deserialize(requestJson, SaveRequest.class);
		ScheduledJob__c record = new ScheduledJob__c();

		record.ClassName__c = request.className;
		record.CronExpression__c = request.cronExpression;
		record.Description__c = request.description;
		record.Id = request.recordId;
		record.IsActive__c = request.isActive == true;
		record.Parameters__c = request.parameters?.isEmpty() == false ? new DTO_NameValues(request.parameters).serialize() : null;
		record.SchedulerName__c = request.schedulerName;
		record.Timezone__c = String.isNotBlank(request.timezone)
				? request.timezone
				: UserInfo.getTimeZone().getID();
		record.ExecutionMode__c = String.isBlank(request.executionMode) ? UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB : request.executionMode;
		record.RunPriority__c = request.runPriority;
		record.OverlapPolicy__c = String.isBlank(request.overlapPolicy) ? UTIL_ScheduledJobRunner.OVERLAP_POLICY_SKIP : request.overlapPolicy;

		DML_Builder.newTransaction().systemModeInternal().doUpsert(record).execute();

		return record.Id;
	}

	/**
	 * @description The next time an expression fires in a time zone, computed by the same evaluator the job runner
	 * uses, so what the editor shows is what the job runner's check will do. The answer is read from the clock of the
	 * moment it is asked for, so every request is answered afresh. Null when the expression cannot be read or never
	 * fires.
	 *
	 * @param cronExpression The expression as typed.
	 * @param timezone The time zone key; blank means UTC.
	 *
	 * @return The next fire instant, or null.
	 */
	@AuraEnabled
	public static Datetime previewNextRun(String cronExpression, String timezone)
	{
		try
		{
			return UTIL_CronExpression.nextFireTime(cronExpression, Datetime.now(), timezone);
		}
		catch(Exception unreadable)
		{
			return null;
		}
	}

	/**
	 * @description Runs a job on the runner now, as the user who asks (see UTIL_ScheduledJobRunner.runNow). A refusal
	 * reaches the client with its label text; a lock wait or a failed write reaches it with the platform's own words,
	 * never as a generic error.
	 *
	 * @param recordId The scheduled job to run now.
	 *
	 * @return The run's platform job id.
	 */
	@AuraEnabled
	public static Id runNow(Id recordId)
	{
		try
		{
			return UTIL_ScheduledJobRunner.runNow(recordId);
		}
		catch(Exception failure)
		{
			AuraHandledException error = new AuraHandledException(failure.getMessage());
			error.setMessage(failure.getMessage());
			throw error;
		}
	}

	/**
	 * @description Whether a job runner is active, how often it checks for due jobs, and whether the running user may
	 * put a job on it: what the editor needs to offer the runner option and its presets.
	 *
	 * @return Whether a runner is active, how often it checks, and whether the running user may manage it.
	 */
	@AuraEnabled
	public static DTO_JobRunnerState getJobRunnerState()
	{
		CTRL_HealthCheck.DTO_JobRunnerStatus status = CTRL_HealthCheck.getJobRunnerStatus();
		DTO_JobRunnerState state = new DTO_JobRunnerState();
		state.isActive = status.isActive;
		state.checkIntervalMinutes = status.checkIntervalMinutes;
		state.canManage = status.canManage;
		return state;
	}

	/**
	 * @description The log entry the record's last run wrote, so the detail view can offer a way to it. A run that
	 * fails and a run that is parked both write an entry carrying the record's id, and the newest of those is the one
	 * the view opens. Null when the running user may not read log entries, or when no entry is left for the record.
	 *
	 * @param recordId The scheduled job whose last run wrote the entry.
	 *
	 * @return The entry's id, or null.
	 */
	@AuraEnabled
	public static Id findLastRunLogEntryId(Id recordId)
	{
		if(!UTIL_SObjectDescribe.isObjectAccessible(LogEntry__c.SObjectType))
		{
			return null;
		}

		List<LogEntry__c> entries = new SEL_LogEntry().findNewestByCorrelationIdOrRecordId(null, recordId, NEWEST_LOG_ENTRY_ROW_LIMIT);

		return entries.isEmpty() ? null : entries[0].Id;
	}

	/**
	 * @description The job runner as the editor sees it.
	 */
	public class DTO_JobRunnerState
	{
		/**
		 * @description True when at least one of the job runner's records still owns a scheduled job that will fire. Copied
		 * from the job runner status the Health Check reads.
		 */
		@AuraEnabled
		public Boolean isActive;

		/**
		 * @description How often the job runner checks for due jobs, in minutes, while one is active; null
		 * otherwise.
		 */
		@AuraEnabled
		public Integer checkIntervalMinutes;

		/**
		 * @description Whether the running user holds Manage Job Runner.
		 */
		@AuraEnabled
		public Boolean canManage;
	}

	/**
	 * @description Request DTO for saving a ScheduledJob__c record.
	 */
	public class SaveRequest
	{
		/**
		 * @description The existing record ID, or null for new records.
		 */
		@AuraEnabled
		public Id recordId;

		/**
		 * @description The user-friendly job name.
		 */
		@AuraEnabled
		public String schedulerName;

		/**
		 * @description The Apex class name implementing Schedulable.
		 */
		@AuraEnabled
		public String className;

		/**
		 * @description The cron expression defining the schedule.
		 */
		@AuraEnabled
		public String cronExpression;

		/**
		 * @description Whether the job should be active.
		 */
		@AuraEnabled
		public Boolean isActive;

		/**
		 * @description Optional description of the job.
		 */
		@AuraEnabled
		public String description;

		/**
		 * @description Structured map of parameter name-value pairs.
		 */
		@AuraEnabled
		public Map<String, String> parameters;

		/**
		 * @description IANA timezone ID of the user creating or editing the cron expression.
		 */
		@AuraEnabled
		public String timezone;

		/**
		 * @description Where the job runs: OwnScheduledJob or JobRunner. Blank saves as its own scheduled job.
		 */
		@AuraEnabled
		public String executionMode;

		/**
		 * @description Order among jobs due at the same check of the job runner: lower numbers start first, blank
		 * goes last.
		 */
		@AuraEnabled
		public Decimal runPriority;

		/**
		 * @description Skip or Allow, for a job on the runner. Blank saves as Skip.
		 */
		@AuraEnabled
		public String overlapPolicy;
	}
}