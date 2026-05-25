// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Aura-enabled controller for the scheduledJobEditor LWC. Provides parameter definitions
 * for scheduled job classes and handles record persistence.
 *
 * @see CTRL_ScheduledJob_TEST
 * @see DTO_ScheduledParameterDefinition
 * @see IF_Schedulable
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date March 2026, May 2026
 */
public inherited sharing class CTRL_ScheduledJob
{
	/**
	 * @description Org cache key for the schedulable class name list.
	 */
	@TestVisible
	private static final String CACHE_KEY_SCHEDULABLE_CLASSES = 'SchedulableClasses';

	/**
	 * @description Lazy-loaded list of Schedulable class names, backed by org Platform Cache.
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
					UTIL_Cache.org().put(CACHE_KEY_SCHEDULABLE_CLASSES, schedulableClassNames);
				}
			}

			return schedulableClassNames;
		}
		private set;
	}

	/**
	 * @description Returns the names of all Apex classes in the org that implement the Schedulable interface.
	 * Results are cached in the org Platform Cache to avoid repeated expensive reflection on every page load.
	 *
	 * @return List of class names that implement Schedulable (namespace-qualified for foreign packages).
	 */
	@AuraEnabled(Cacheable=true)
	public static List<String> getSchedulableClasses()
	{
		return schedulableClassNames;
	}

	/**
	 * @description Retrieves the parameter definitions declared by a scheduled job class. Validates that
	 * the class exists and implements Schedulable. If it also implements IF_Schedulable, returns the
	 * parameter definitions; otherwise returns null so the LWC falls back to the raw attributes textarea.
	 *
	 * @param className The fully qualified Apex class name to inspect.
	 *
	 * @return List of parameter definitions, or null when the class is blank or does not implement IF_Schedulable.
	 *
	 * @throws AuraHandledException When the class cannot be resolved or is not a Schedulable.
	 */
	@AuraEnabled(Cacheable=true)
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
	@AuraEnabled(Cacheable=true)
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

		DML_Builder.newTransaction().withSystemMode().doUpsert(record).execute();

		return record.Id;
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
	}
}