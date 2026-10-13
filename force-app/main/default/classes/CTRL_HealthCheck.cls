// SPDX-License-Identifier: BUSL-1.1

/**
 * @description Controller for the Health Check component. Runs checks that confirm the required
 * setup after install (Platform Cache) is in place, suggests how long to keep the records of the
 * framework's data objects, reports how the org's data masking is set up, schedules the chain
 * watchdog with one click, and manages the job runner: switching it on, repairing it and switching
 * it off, its status card and its three health check rows.
 *
 * @see CTRL_HealthCheck_TEST
 * @see UTIL_ScheduledJobRunner
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength,PMD.NcssCount,PMD.NcssTypeCount')
public inherited sharing class CTRL_HealthCheck
{
	/**
	 * @description Display name for the Organisation Cache health check.
	 */
	@TestVisible
	private static final String CHECK_ORG_CACHE = System.Label.HealthCheck_OrgCache_CheckName;

	/**
	 * @description Display name for the Session Cache health check.
	 */
	@TestVisible
	private static final String CHECK_SESSION_CACHE = System.Label.HealthCheck_SessionCache_CheckName;

	/**
	 * @description Display name for the Class Type Resolver health check.
	 */
	@TestVisible
	private static final String CHECK_CLASS_TYPE_RESOLVER = System.Label.HealthCheck_ClassTypeResolver_CheckName;

	/**
	 * @description Display name for the Data Retention health check.
	 */
	@TestVisible
	private static final String CHECK_DATA_RETENTION = System.Label.HealthCheck_DataRetention_CheckName;

	/**
	 * @description Display name for the Data Masking posture health check.
	 */
	@TestVisible
	private static final String CHECK_MASKING_POSTURE = System.Label.HealthCheck_MaskingPosture_CheckName;

	/**
	 * @description Display name for the Custom-Object Masking Coverage health check.
	 */
	private static final String CHECK_CUSTOM_OBJECT_COVERAGE = System.Label.HealthCheck_CustomObjectCoverage_CheckName;

	/**
	 * @description Display name for the Async Chain Abort capability health check.
	 */
	private static final String CHECK_ASYNC_CHAIN_ABORT = System.Label.HealthCheck_AsyncChainAbort_CheckName;

	/**
	 * @description Display name for the Chain Watchdog health check.
	 */
	private static final String CHECK_CHAIN_WATCHDOG = System.Label.HealthCheck_ChainWatchdog_CheckName;

	// Priority ordering (lower = higher priority, sorted to the top of each severity section in the UI).
	// The package depends on Platform Cache partitions more than on anything else, so they rank above
	// resolver and retention setup when they appear in the same severity section.
	/**
	 * @description Display priority for the Organisation Cache health check.
	 */
	private static final Integer PRIORITY_ORG_CACHE = 10;

	/**
	 * @description Display priority for the Session Cache health check.
	 */
	private static final Integer PRIORITY_SESSION_CACHE = 20;

	/**
	 * @description Display priority for the Class Type Resolver health check.
	 */
	private static final Integer PRIORITY_CLASS_TYPE_RESOLVER = 40;

	/**
	 * @description Display priority for the Data Masking posture health check.
	 */
	private static final Integer PRIORITY_MASKING_POSTURE = 45;

	/**
	 * @description Display priority for the Custom-Object Masking Coverage health check.
	 */
	private static final Integer PRIORITY_CUSTOM_OBJECT_COVERAGE = 46;

	/**
	 * @description Display priority for the Async Chain Abort capability health check.
	 */
	private static final Integer PRIORITY_ASYNC_CHAIN_ABORT = 47;

	/**
	 * @description Display priority for the Chain Watchdog health check.
	 */
	private static final Integer PRIORITY_CHAIN_WATCHDOG = 48;

	/**
	 * @description Display priority for the Data Retention health check.
	 */
	private static final Integer PRIORITY_DATA_RETENTION = 50;

	/**
	 * @description Display name for the health check reporting whether the job runner is checking for due jobs and
	 * whether its set of scheduled jobs is complete.
	 */
	private static final String CHECK_JOB_RUNNER = System.Label.HealthCheck_JobRunner_CheckName;

	/**
	 * @description Display name for the health check reporting jobs that wait for a job runner that is not active.
	 */
	private static final String CHECK_JOB_RUNNER_ORPHANED = System.Label.HealthCheck_JobRunner_Orphaned_CheckName;

	/**
	 * @description Display name for the health check reporting how many of the org's scheduled-job slots are in use and
	 * whether the last check started every job that was due.
	 */
	private static final String CHECK_JOB_RUNNER_CAPACITY = System.Label.HealthCheck_JobRunner_Capacity_CheckName;

	/**
	 * @description Display priority for the job-runner health check: immediately after the chain watchdog.
	 */
	private static final Integer PRIORITY_JOB_RUNNER = 49;

	/**
	 * @description Display priority for the jobs-waiting-for-the-job-runner health check.
	 */
	private static final Integer PRIORITY_JOB_RUNNER_ORPHANED = 51;

	/**
	 * @description Display priority for the job-runner capacity health check, last of the three job-runner rows.
	 */
	private static final Integer PRIORITY_JOB_RUNNER_CAPACITY = 52;

	/**
	 * @description How many Scheduled Apex rows the capacity row warns from: the org holds a hundred slots in all.
	 */
	private static final Integer SCHEDULED_APEX_SLOT_WARN_FROM = 80;

	/**
	 * @description How many Scheduled Apex rows the capacity row fails from: new schedules start failing at a hundred.
	 */
	private static final Integer SCHEDULED_APEX_SLOT_FAIL_FROM = 90;

	/**
	 * @description Minutes in an hour, for deriving the check interval and the slot cost.
	 */
	private static final Integer MINUTES_PER_HOUR = 60;

	/**
	 * @description The cron expression of a runner record at a given minute mark: seconds 0, that minute, every hour.
	 */
	private static final String RUNNER_CRON_TEMPLATE = '0 {0} * * * ?';

	/**
	 * @description Status value indicating a health check passed.
	 */
	@TestVisible
	private static final String STATUS_PASS = 'Pass';

	/**
	 * @description Status value indicating a health check has a non-critical issue.
	 */
	@TestVisible
	private static final String STATUS_WARN = 'Warn';

	/**
	 * @description Status value indicating a health check failed.
	 */
	@TestVisible
	private static final String STATUS_FAIL = 'Fail';

	/**
	 * @description The Platform Cache partition name used in detail messages.
	 */
	private static final String PARTITION_NAME = UTIL_Cache.getPlatformCacheName();

	/**
	 * @description Detail message when Organisation Cache is allocated. Sourced from Custom Label.
	 */
	@TestVisible
	private static final String DETAIL_ORG_CACHE_ALLOCATED = String.format(System.Label.HealthCheck_OrgCache_Allocated, new List<Object> {PARTITION_NAME});

	/**
	 * @description Detail message when Organisation Cache is not allocated. Sourced from Custom Label.
	 */
	@TestVisible
	private static final String DETAIL_ORG_CACHE_NOT_ALLOCATED = String.format(System.Label.HealthCheck_OrgCache_NotAllocated, new List<Object> {PARTITION_NAME});

	/**
	 * @description Detail message when Session Cache is allocated. Sourced from Custom Label.
	 */
	@TestVisible
	private static final String DETAIL_SESSION_CACHE_ALLOCATED = String.format(System.Label.HealthCheck_SessionCache_Allocated, new List<Object> {PARTITION_NAME});

	/**
	 * @description Detail message when Session Cache is not allocated. Sourced from Custom Label.
	 */
	@TestVisible
	private static final String DETAIL_SESSION_CACHE_NOT_ALLOCATED = String.format(System.Label.HealthCheck_SessionCache_NotAllocated, new List<Object> {PARTITION_NAME});

	/**
	 * @description Detail message when a Class Type Resolver record is configured and its class resolves. Sourced from Custom Label.
	 */
	@TestVisible
	private static final String DETAIL_CLASS_TYPE_RESOLVER_CONFIGURED = System.Label.HealthCheck_ClassTypeResolver_Configured;

	/**
	 * @description Detail message when no ClassTypeResolver__mdt records exist. Sourced from Custom Label.
	 */
	@TestVisible
	private static final String DETAIL_CLASS_TYPE_RESOLVER_MISSING = System.Label.HealthCheck_ClassTypeResolver_Missing;

	/**
	 * @description Detail message when ClassTypeResolver__mdt records exist but none of the referenced classes can be resolved. Sourced from Custom Label.
	 */
	@TestVisible
	private static final String DETAIL_CLASS_TYPE_RESOLVER_CLASS_NOT_FOUND = System.Label.HealthCheck_ClassTypeResolver_ClassNotFound;

	/**
	 * @description Detail message when ClassTypeResolver__mdt records exist and the class resolves but does not extend BaseClassResolver. Sourced from Custom Label.
	 */
	@TestVisible
	private static final String DETAIL_CLASS_TYPE_RESOLVER_INVALID_TYPE = System.Label.HealthCheck_ClassTypeResolver_InvalidType;

	/**
	 * @description Detail message when retention purge jobs are configured for all framework objects.
	 */
	@TestVisible
	private static final String DETAIL_DATA_RETENTION_CONFIGURED = System.Label.HealthCheck_DataRetention_Configured;

	/**
	 * @description Detail message template when retention is not configured. {0} is populated with a comma-separated list of unconfigured objects.
	 */
	@TestVisible
	private static final String DETAIL_DATA_RETENTION_MISSING = System.Label.HealthCheck_DataRetention_Missing;

	/**
	 * @description Detail message template when active masking targets mask nothing. {0} is populated with the dead-target count.
	 */
	@TestVisible
	private static final String DETAIL_MASKING_POSTURE_DEAD = System.Label.HealthCheck_MaskingPosture_DeadConfig;

	/**
	 * @description Detail message when no object in the org carries active masking yet.
	 */
	@TestVisible
	private static final String DETAIL_MASKING_POSTURE_NONE_ACTIVE = System.Label.HealthCheck_MaskingPosture_NoneActive;

	/**
	 * @description Detail message template when masking is active and healthy. {0} is populated with the count of objects carrying active masking.
	 */
	@TestVisible
	private static final String DETAIL_MASKING_POSTURE_HEALTHY = System.Label.HealthCheck_MaskingPosture_Healthy;

	/**
	 * @description Detail message template when checked custom objects show no unmasked likely-sensitive fields. {0} is populated with the checked-object count.
	 */
	@TestVisible
	private static final String DETAIL_CUSTOM_OBJECT_COVERAGE_HEALTHY = System.Label.HealthCheck_CustomObjectCoverage_Healthy;

	/**
	 * @description Detail message template when custom objects hold likely-sensitive fields with no masking.
	 * {0} is populated with the object count, {1} with the comma-separated object names.
	 */
	@TestVisible
	private static final String DETAIL_CUSTOM_OBJECT_COVERAGE_UNPROTECTED = System.Label.HealthCheck_CustomObjectCoverage_Unprotected;

	/**
	 * @description Detail suffix counting the custom objects one run left unchecked once the assessment bound was reached. {0} is populated with the unchecked-object count.
	 */
	@TestVisible
	private static final String DETAIL_CUSTOM_OBJECT_COVERAGE_UNCHECKED = System.Label.HealthCheck_CustomObjectCoverage_Unchecked;

	/**
	 * @description Default nightly 2 am cron expression for all framework purge jobs.
	 */
	private static final String DEFAULT_CRON = '0 0 2 * * ?';

	/**
	 * @description Default hourly cron expression for the chain watchdog sweep, the schedule the
	 * Async Processing guide recommends.
	 */
	private static final String WATCHDOG_CRON = '0 0 * * * ?';

	/**
	 * @description Default number of minutes after which a chain counts as stuck, used by the one-click
	 * watchdog schedule. Held as a String because scheduled-job parameters are saved as name-value text.
	 */
	private static final String WATCHDOG_DEFAULT_STALE_THRESHOLD_MINUTES = '30';

	/**
	 * @description Default maximum chains per sweep the one-click watchdog schedule applies.
	 * Held as a String because scheduled-job parameters are saved as name-value text.
	 */
	private static final String WATCHDOG_DEFAULT_BATCH_SIZE = '50';

	/**
	 * @description Retention recommendations keyed by framework SObjectType. Drives both the
	 * Data Retention health check and the retention-proposal list returned to the UI.
	 */
	private static final Map<SObjectType, RetentionRecommendation> FRAMEWORK_RECOMMENDATIONS = new Map<SObjectType, RetentionRecommendation>
	{
			LogEntry__c.SObjectType => new RetentionRecommendation(90, DEFAULT_CRON, System.Label.HealthCheck_DataRetention_SchedulerName_LogEntry),
			ApiCall__c.SObjectType => new RetentionRecommendation(90, DEFAULT_CRON, System.Label.HealthCheck_DataRetention_SchedulerName_ApiCall),
			ApiIssue__c.SObjectType => new RetentionRecommendation(180, DEFAULT_CRON, System.Label.HealthCheck_DataRetention_SchedulerName_ApiIssue),
			AsyncChainExecution__c.SObjectType => new RetentionRecommendation(90, DEFAULT_CRON,
					System.Label.HealthCheck_DataRetention_SchedulerName_AsyncChainExecution, AsyncChainExecution__c.CompletedAt__c)
	};

	/**
	 * @description Map from each framework object's qualified API name (namespaced in subscriber orgs)
	 * to its SObjectType, derived from FRAMEWORK_RECOMMENDATIONS. Used when matching user-supplied
	 * retention proposals (which carry API names from the UI) back to the internal SObjectType keys.
	 */
	private static final Map<String, SObjectType> FRAMEWORK_OBJECT_TYPE_BY_QUALIFIED_API_NAME = buildFrameworkObjectTypeByQualifiedApiName();

	/**
	 * @description Builds the map from API name to SObjectType once, when the class loads. A separate
	 * static method, so the final field can be set in one expression while the describe loop stays
	 * easy to read.
	 *
	 * @return Map of qualified API name to SObjectType for every framework retention object
	 */
	private static Map<String, SObjectType> buildFrameworkObjectTypeByQualifiedApiName()
	{
		Map<String, SObjectType> index = new Map<String, SObjectType>();
		for(SObjectType objectType : FRAMEWORK_RECOMMENDATIONS.keySet())
		{
			index.put(UTIL_SObjectDescribe.getObjectNameFromType(objectType), objectType);
		}
		return index;
	}

	/**
	 * @description Runs all health checks and returns their results.
	 *
	 * @return List of health check results (one per check, in display order)
	 *
	 * @example
	 * ```apex
	 * List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();
	 * ```
	 */
	@AuraEnabled
	public static List<DTO_HealthCheckResult> runHealthChecks()
	{
		JobRunnerState state = loadJobRunnerState();

		return new List<DTO_HealthCheckResult>
		{
				checkOrganisationCache(),
				checkSessionCache(),
				checkClassTypeResolver(),
				checkDataRetention(state),
				checkMaskingPosture(),
				checkCustomObjectMaskingCoverage(),
				checkAsyncChainAbort(),
				checkChainWatchdog(state),
				checkJobRunner(state),
				checkOrphanedJobRunnerRecords(state),
				checkJobRunnerCapacity(state)
		};
	}

	/**
	 * @description Returns the set of framework-object retention proposals for objects that do not
	 * yet have an active SCHED_PurgeRecords job. Each proposal carries the current record count and
	 * recommended retention window / cron defaults to display in the confirmation dialog.
	 *
	 * @return Ordered list of DTO_RetentionProposal (one per unconfigured framework object)
	 */
	@AuraEnabled(cacheable=false)
	public static List<DTO_RetentionProposal> getRetentionProposals()
	{
		List<DTO_RetentionProposal> proposals = new List<DTO_RetentionProposal>();

		for(SObjectType objectType : getUnconfiguredRetentionObjectTypes())
		{
			DescribeSObjectResult describe = UTIL_SObjectDescribe.getDescribe(objectType).getDescribe();
			RetentionRecommendation recommendation = FRAMEWORK_RECOMMENDATIONS.get(objectType);

			DTO_RetentionProposal proposal = new DTO_RetentionProposal();
			proposal.objectApiName = describe.getName();
			proposal.objectLabel = describe.getLabel();
			proposal.recordCount = (Integer)QRY_Builder.selectFrom(objectType).systemModeInternal().count();
			proposal.retentionDays = recommendation.retentionDays;
			proposal.schedulerName = recommendation.schedulerName;
			proposal.schedulerClassName = SCHED_PurgeRecords.class.getName();
			proposal.cronExpression = recommendation.cronExpression;

			proposals.add(proposal);
		}

		return proposals;
	}

	/**
	 * @description Creates one active SCHED_PurgeRecords ScheduledJob__c per supplied proposal in a
	 * single transaction. Proposals for objects already covered by an active purge job (or not in the
	 * framework's internal recommendation map) are skipped silently. Accepts a JSON string because LWC
	 * does not support inner class or List-of-inner-class deserialization for @AuraEnabled parameters.
	 *
	 * @param proposalsJson JSON-serialized List&lt;DTO_RetentionProposal&gt; from the UI (cronExpression may have been user-modified)
	 *
	 * @return IDs of the created ScheduledJob__c records
	 */
	@AuraEnabled
	public static List<Id> applyRetentionRecommendations(String proposalsJson)
	{
		if(String.isBlank(proposalsJson))
		{
			return new List<Id>();
		}

		List<DTO_RetentionProposal> proposals = (List<DTO_RetentionProposal>)JSON.deserialize(proposalsJson, List<DTO_RetentionProposal>.class);

		return applyRetentionRecommendations(proposals);
	}

	/**
	 * @description Typed implementation for applyRetentionRecommendations. Invoked by the @AuraEnabled
	 * wrapper above and by Apex callers (notably tests) that can pass typed DTOs directly. Skips any
	 * proposal whose object is already covered by an active purge job or is not in the framework's
	 * recommendation map.
	 *
	 * @param proposals Retention proposals from the UI (cronExpression may have been user-modified)
	 *
	 * @return IDs of the created ScheduledJob__c records
	 */
	@TestVisible
	private static List<Id> applyRetentionRecommendations(List<DTO_RetentionProposal> proposals)
	{
		if(proposals == null || proposals.isEmpty())
		{
			return new List<Id>();
		}

		Set<String> coveredObjects = getCoveredRetentionObjects();
		String schedulerClassName = SCHED_PurgeRecords.class.getName();
		String runningUserTimezone = UserInfo.getTimeZone().getID();
		List<ScheduledJob__c> jobsToInsert = new List<ScheduledJob__c>();

		for(DTO_RetentionProposal proposal : proposals)
		{
			if(coveredObjects.contains(proposal.objectApiName))
			{
				continue;
			}

			SObjectType targetType = FRAMEWORK_OBJECT_TYPE_BY_QUALIFIED_API_NAME.get(proposal.objectApiName);
			if(targetType == null)
			{
				continue;
			}

			RetentionRecommendation recommendation = FRAMEWORK_RECOMMENDATIONS.get(targetType);

			DTO_NameValues jobParameters = new DTO_NameValues();
			jobParameters.add(SCHED_PurgeRecords.REQUIRED_PARAMETER_OBJECT_NAME, proposal.objectApiName);
			jobParameters.add(SCHED_PurgeRecords.OPTIONAL_PARAMETER_MINIMUM_NUMBER_OF_DAYS, String.valueOf(recommendation.retentionDays));
			if(recommendation.dateField != null)
			{
				jobParameters.add(SCHED_PurgeRecords.OPTIONAL_PARAMETER_DATE_FIELD_NAME, UTIL_SObjectDescribe.getCachedFieldName(recommendation.dateField));
			}

			jobsToInsert.add(new ScheduledJob__c(
					SchedulerName__c = recommendation.schedulerName,
					ClassName__c = schedulerClassName,
					CronExpression__c = String.isBlank(proposal.cronExpression) ? recommendation.cronExpression : proposal.cronExpression,
					IsActive__c = true,
					Timezone__c = runningUserTimezone,
					Parameters__c = jobParameters.serialize()
			));
		}

		if(jobsToInsert.isEmpty())
		{
			return new List<Id>();
		}

		return DML_Builder.newTransaction().withSystemMode().doInsert(jobsToInsert).execute().getInsertedIds();
	}

	/**
	 * @description Returns the framework SObjectTypes that do not yet have an active
	 * SCHED_PurgeRecords job: the common filter behind both the Data Retention health
	 * check and the retention-proposal list.
	 *
	 * @return Framework SObjectTypes lacking an active purge job (iteration order follows FRAMEWORK_RECOMMENDATIONS)
	 */
	private static List<SObjectType> getUnconfiguredRetentionObjectTypes()
	{
		Set<String> coveredObjects = getCoveredRetentionObjects();
		List<SObjectType> unconfigured = new List<SObjectType>();

		for(SObjectType objectType : FRAMEWORK_RECOMMENDATIONS.keySet())
		{
			if(!coveredObjects.contains(UTIL_SObjectDescribe.getObjectNameFromType(objectType)))
			{
				unconfigured.add(objectType);
			}
		}

		return unconfigured;
	}

	/**
	 * @description Queries active ScheduledJob__c records for SCHED_PurgeRecords and extracts
	 * the configured object names from their Parameters__c JSON. A name is stored the way the object's describe spells
	 * it, so a job whose name was typed in another letter case still counts; a name that names no object is kept as typed.
	 *
	 * @return Set of object API names covered by active purge jobs
	 */
	private static Set<String> getCoveredRetentionObjects()
	{
		Set<String> coveredObjects = new Set<String>();

		for(ScheduledJob__c job : new SEL_ScheduledJob().findActiveByClassName(SCHED_PurgeRecords.class.getName()))
		{
			String objectName = readPurgedObjectName(job);
			coveredObjects.add(UTIL_SObjectDescribe.getObjectNameFromType(UTIL_SObjectDescribe.getSObjectTypeByName(objectName)) ?? objectName);
		}

		return coveredObjects;
	}

	/**
	 * @description Reads the name of the object a purge job deletes from, as it is stored in the job's parameters.
	 *
	 * @param job The purge job
	 *
	 * @return The object name as typed, or null when the job names none
	 */
	private static String readPurgedObjectName(ScheduledJob__c job)
	{
		DTO_NameValues parameters = (DTO_NameValues)new DTO_NameValues().deserialize(job.Parameters__c);
		return parameters.get(SCHED_PurgeRecords.REQUIRED_PARAMETER_OBJECT_NAME);
	}

	/**
	 * @description Checks whether Organisation Cache has capacity allocated.
	 * Organisation Cache is required for circuit breaker, API retry, and distributed state.
	 *
	 * @return Health check result for Organisation Cache (Fail when missing)
	 */
	private static DTO_HealthCheckResult checkOrganisationCache()
	{
		Boolean isAllocated = UTIL_Cache.isOrgAllocated();

		DTO_HealthCheckResult result = new DTO_HealthCheckResult();
		result.name = CHECK_ORG_CACHE;
		result.status = isAllocated ? STATUS_PASS : STATUS_FAIL;
		result.detail = isAllocated ? DETAIL_ORG_CACHE_ALLOCATED : DETAIL_ORG_CACHE_NOT_ALLOCATED;
		result.priority = PRIORITY_ORG_CACHE;

		return result;
	}

	/**
	 * @description Checks whether Session Cache has capacity allocated.
	 * Session Cache is optional but recommended for improved performance.
	 *
	 * @return Health check result for Session Cache (Warn when missing)
	 */
	private static DTO_HealthCheckResult checkSessionCache()
	{
		Boolean isAllocated = UTIL_Cache.isSessionAllocated();

		DTO_HealthCheckResult result = new DTO_HealthCheckResult();
		result.name = CHECK_SESSION_CACHE;
		result.status = isAllocated ? STATUS_PASS : STATUS_WARN;
		result.detail = isAllocated ? DETAIL_SESSION_CACHE_ALLOCATED : DETAIL_SESSION_CACHE_NOT_ALLOCATED;
		result.priority = PRIORITY_SESSION_CACHE;

		return result;
	}

	/**
	 * @description Checks whether a ClassTypeResolver__mdt record is configured, and whether the resolver
	 * class it names can be found at runtime and extends BaseClassResolver. Each class name is looked up
	 * the same way the resolver chain looks up its own classes when it starts, subscriber classes first.
	 * It does not go through the resolver chain itself, because that is what this check tests. So the
	 * result always matches what the chain will really load.
	 *
	 * @return Health check result for Class Type Resolver (Warn when missing, unresolvable, or invalid type)
	 */
	private static DTO_HealthCheckResult checkClassTypeResolver()
	{
		DTO_HealthCheckResult result = new DTO_HealthCheckResult();
		result.name = CHECK_CLASS_TYPE_RESOLVER;
		result.priority = PRIORITY_CLASS_TYPE_RESOLVER;

		List<ClassTypeResolver__mdt> resolvers = new SEL_ClassTypeResolver().findAll();

		if(resolvers.isEmpty())
		{
			result.status = STATUS_WARN;
			result.detail = DETAIL_CLASS_TYPE_RESOLVER_MISSING;
			result.actionLabel = System.Label.HealthCheck_SetupActionLabel;
			return result;
		}

		Boolean hasValidResolver = false;
		Boolean hasResolvableClass = false;

		for(ClassTypeResolver__mdt resolver : resolvers)
		{
			Type resolverType = UTIL_TypeResolver.getTypeForClassName(resolver.ClassName__c);

			if(resolverType == null)
			{
				continue;
			}

			hasResolvableClass = true;

			if(UTIL_TypeResolver.INT_ClassTypeResolver.class.isAssignableFrom(resolverType))
			{
				hasValidResolver = true;
				break;
			}
		}

		if(hasValidResolver)
		{
			result.status = STATUS_PASS;
			result.detail = DETAIL_CLASS_TYPE_RESOLVER_CONFIGURED;
		}
		else if(hasResolvableClass)
		{
			result.status = STATUS_WARN;
			result.detail = DETAIL_CLASS_TYPE_RESOLVER_INVALID_TYPE;
			result.actionLabel = System.Label.HealthCheck_SetupActionLabel;
		}
		else
		{
			result.status = STATUS_WARN;
			result.detail = DETAIL_CLASS_TYPE_RESOLVER_CLASS_NOT_FOUND;
			result.actionLabel = System.Label.HealthCheck_SetupActionLabel;
		}

		return result;
	}

	/**
	 * @description Checks whether scheduled purge jobs are configured for framework data objects
	 * (LogEntry__c, ApiCall__c, ApiIssue__c, AsyncChainExecution__c). Warns with a per-object
	 * record count when any framework object lacks an active purge job. The counts read every user's records on purpose:
	 * the check is about how much data the whole org holds, and a count carries no record content, so each count waives
	 * record sharing (bypassSharingInternal()) as well as object and field permissions (systemModeInternal()). Without
	 * that, a viewer without View All would see only the records they own, and these objects are Private.
	 *
	 * API calls and API issues can be deleted only by a user the BypassApiRecordDeleteGuard feature flag is on for. A
	 * built-in rule turns the flag on for holders of the Delete API Records permission. So when either has no purge job,
	 * the warning also says who must schedule it; and when every object has a purge job but the purge of either runs as a
	 * user the flag is off for, the check warns and names it, because that purge deletes nothing. When the flag record is
	 * deactivated or missing, nobody can delete API calls or API issues, so the check says that instead, with no action:
	 * a new purge job would not help.
	 *
	 * @param state The job runner state, which names the user every job on the runner runs as.
	 *
	 * @return Health check result for Data Retention (Pass when all configured and able to delete, Warn otherwise)
	 */
	private static DTO_HealthCheckResult checkDataRetention(JobRunnerState state)
	{
		DTO_HealthCheckResult result = new DTO_HealthCheckResult();
		result.name = CHECK_DATA_RETENTION;
		result.priority = PRIORITY_DATA_RETENTION;

		List<SObjectType> unconfigured = getUnconfiguredRetentionObjectTypes();
		Boolean isApiRecordDeleteFlagActive = SEL_FeatureFlag.activeFlags.containsKey(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD);

		if(unconfigured.isEmpty())
		{
			if(!isApiRecordDeleteFlagActive)
			{
				result.status = STATUS_WARN;
				result.detail = System.Label.HealthCheck_DataRetention_ApiRecordDeleteFlagInactive;
				return result;
			}
			List<String> purgesThatCannotDelete = findApiRecordPurgesThatCannotDelete(state);
			if(!purgesThatCannotDelete.isEmpty())
			{
				result.status = STATUS_WARN;
				result.detail = String.format(System.Label.HealthCheck_DataRetention_ApiPurgeCannotDelete, new List<String> {String.join(purgesThatCannotDelete, ', ')});
				result.actionLabel = System.Label.HealthCheck_ScheduledJobsActionLabel;
				return result;
			}
			result.status = STATUS_PASS;
			result.detail = DETAIL_DATA_RETENTION_CONFIGURED;
			return result;
		}

		result.status = STATUS_WARN;
		result.recordCounts = new List<DTO_ObjectRecordCount>();
		List<String> objectLabels = new List<String>();

		for(SObjectType objectType : unconfigured)
		{
			String objectLabel = UTIL_SObjectDescribe.getDescribe(objectType).getDescribe().getLabel();
			objectLabels.add(objectLabel);
			result.recordCounts.add(new DTO_ObjectRecordCount(objectLabel, (Integer)QRY_Builder.selectFrom(objectType).systemModeInternal().bypassSharingInternal().count()));
		}

		result.detail = String.format(DETAIL_DATA_RETENTION_MISSING, new List<String> {String.join(objectLabels, ', ')});
		if(unconfigured.contains(ApiCall__c.SObjectType) || unconfigured.contains(ApiIssue__c.SObjectType))
		{
			result.detail += ' ' + (isApiRecordDeleteFlagActive
					? System.Label.HealthCheck_DataRetention_ApiPurgeNeedsUserWhoCanDelete
					: System.Label.HealthCheck_DataRetention_ApiRecordDeleteFlagInactive);
		}
		result.actionLabel = System.Label.HealthCheck_ScheduledJobsActionLabel;
		return result;
	}

	/**
	 * @description Finds the active purge jobs for API calls and API issues that run as a user the
	 * BypassApiRecordDeleteGuard feature flag is off for, and so delete nothing. A job on the job runner runs as the user
	 * who activated the runner; a job with a scheduled job of its own runs as that scheduled job's owner. A job whose user
	 * cannot be told (the runner is not active, or the job has no scheduled job yet) is left out. The flag is asked for
	 * that user, not for the user who opens the page, so a strategy record your org added for that user counts. A job's
	 * object name is matched in any letter case, as the purge itself matches it.
	 *
	 * @param state The job runner state, which names the user every job on the runner runs as.
	 *
	 * @return The labels of the objects whose purge cannot delete, in the order the jobs were read.
	 */
	private static List<String> findApiRecordPurgesThatCannotDelete(JobRunnerState state)
	{
		List<ScheduledJob__c> apiRecordPurges = new List<ScheduledJob__c>();
		List<SObjectType> apiRecordTypes = new List<SObjectType>();
		Set<Id> ownTriggerIds = new Set<Id>();
		for(ScheduledJob__c job : new SEL_ScheduledJob().findActiveByClassName(SCHED_PurgeRecords.class.getName()))
		{
			SObjectType objectType = UTIL_SObjectDescribe.getSObjectTypeByName(readPurgedObjectName(job));
			if(objectType == ApiCall__c.SObjectType || objectType == ApiIssue__c.SObjectType)
			{
				apiRecordPurges.add(job);
				apiRecordTypes.add(objectType);
				ownTriggerIds.add(toCronTriggerId(job.ScheduledJobId__c));
			}
		}
		ownTriggerIds.remove(null);
		Map<Id, CronTrigger> triggerById = ownTriggerIds.isEmpty()
				? new Map<Id, CronTrigger>()
				: new Map<Id, CronTrigger>(new SEL_CronTrigger().findByIds(ownTriggerIds));

		List<String> objectLabels = new List<String>();
		for(Integer index = 0; index < apiRecordPurges.size(); index++)
		{
			ScheduledJob__c job = apiRecordPurges[index];
			Id runAsUserId = job.ExecutionMode__c == UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER
					? state.activatorId
					: triggerById.get(toCronTriggerId(job.ScheduledJobId__c))?.OwnerId;
			if(runAsUserId != null && !UTIL_FeatureFlag.isEnabled(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD, runAsUserId))
			{
				objectLabels.add(UTIL_SObjectDescribe.getDescribe(apiRecordTypes[index]).getDescribe().getLabel());
			}
		}
		return objectLabels;
	}

	/**
	 * @description Checks the org's data-masking posture by reading CTRL_MaskingAdvisor.getOrgPostureSummary().
	 * Warns when any active masking target masks nothing (its rule is missing or inactive) so the admin can fix
	 * or remove it, warns when no object carries active masking yet, and otherwise passes with the count of
	 * masked objects. The Review-masking action deep-links into the Data Masking Advisor.
	 *
	 * @return Health check result for Data Masking (Warn on dead config or zero active masking, Pass otherwise)
	 */
	private static DTO_HealthCheckResult checkMaskingPosture()
	{
		CTRL_MaskingAdvisor.DTO_OrgPostureSummary posture = CTRL_MaskingAdvisor.getOrgPostureSummary();

		DTO_HealthCheckResult result = new DTO_HealthCheckResult();
		result.name = CHECK_MASKING_POSTURE;
		result.priority = PRIORITY_MASKING_POSTURE;

		if(posture.deadConfigCount > 0)
		{
			result.status = STATUS_WARN;
			result.detail = String.format(DETAIL_MASKING_POSTURE_DEAD, new List<Object> {posture.deadConfigCount});
			result.actionLabel = System.Label.HealthCheck_ReviewMasking_ActionLabel;
			return result;
		}

		if(posture.objectsWithActiveTargets == 0)
		{
			result.status = STATUS_WARN;
			result.detail = DETAIL_MASKING_POSTURE_NONE_ACTIVE;
			result.actionLabel = System.Label.HealthCheck_ReviewMasking_ActionLabel;
			return result;
		}

		result.status = STATUS_PASS;
		result.detail = String.format(DETAIL_MASKING_POSTURE_HEALTHY, new List<Object> {posture.objectsWithActiveTargets});
		return result;
	}

	/**
	 * @description Checks the masking coverage of the subscriber's own custom objects through
	 * CTRL_MaskingAdvisor.summarizeCustomObjectCoverage(). That method checks a limited number of
	 * objects, so one run never walks a very long object list in orgs with many custom objects. Warns,
	 * naming the objects that hold likely-sensitive fields with no active masking; otherwise passes with
	 * the number checked. Either way the detail adds how many objects the limit left unchecked, so a
	 * partial check is never mistaken for a full scan. The Review-masking action opens the Data Masking
	 * Advisor, whose on-demand scan covers everything this limited check cannot.
	 *
	 * @return Health check result for Custom-Object Masking Coverage (Warn when unmasked sensitive custom objects exist, Pass otherwise)
	 */
	private static DTO_HealthCheckResult checkCustomObjectMaskingCoverage()
	{
		CTRL_MaskingAdvisor.DTO_CustomObjectCoverageSummary coverage = CTRL_MaskingAdvisor.summarizeCustomObjectCoverage();

		DTO_HealthCheckResult result = new DTO_HealthCheckResult();
		result.name = CHECK_CUSTOM_OBJECT_COVERAGE;
		result.priority = PRIORITY_CUSTOM_OBJECT_COVERAGE;

		String uncheckedSuffix = coverage.unassessedObjectCount > 0 ?
				UTIL_String.SPACE + String.format(DETAIL_CUSTOM_OBJECT_COVERAGE_UNCHECKED, new List<Object> {coverage.unassessedObjectCount}) : UTIL_String.EMPTY;

		if(coverage.objectsRequiringAttention.isEmpty())
		{
			result.status = STATUS_PASS;
			result.detail = String.format(DETAIL_CUSTOM_OBJECT_COVERAGE_HEALTHY, new List<Object> {coverage.assessedObjectCount}) + uncheckedSuffix;
			return result;
		}

		result.status = STATUS_WARN;
		result.detail = String.format
				(
						DETAIL_CUSTOM_OBJECT_COVERAGE_UNPROTECTED,
						new List<Object> {coverage.objectsRequiringAttention.size(), String.join(coverage.objectsRequiringAttention, ', ')}
				) + uncheckedSuffix;
		result.actionLabel = System.Label.HealthCheck_ReviewMasking_ActionLabel;
		return result;
	}

	/**
	 * @description Reports whether operators can abort chains in this org: the feature flag that
	 * controls it must be active, no profile other than System Administrator may hold the abort custom
	 * permission, and at least one user must hold the permission set that grants it. Only checks that
	 * such grants exist, never the running user's own assignment: that would warn in a correctly set-up
	 * org whose viewer simply does not have the permission. Has no action: healthCheck.js sends every
	 * action that is not about masking to the resolver dialog, so a label here would open the wrong dialog.
	 *
	 * @return The check result: Pass when the flag is active, no other profile holds the permission, and someone holds the permission set; Warn otherwise.
	 */
	private static DTO_HealthCheckResult checkAsyncChainAbort()
	{
		DTO_HealthCheckResult result = new DTO_HealthCheckResult();
		result.name = CHECK_ASYNC_CHAIN_ABORT;
		result.priority = PRIORITY_ASYNC_CHAIN_ABORT;

		if(SEL_FeatureFlag.activeFlags.get(UTIL_AsyncChain.ABORT_FEATURE_FLAG_NAME) == null)
		{
			result.status = STATUS_WARN;
			result.detail = System.Label.HealthCheck_AsyncChainAbort_FlagInactive;
			return result;
		}

		if(hasNonAdministratorProfileAbortGrant())
		{
			result.status = STATUS_WARN;
			result.detail = System.Label.HealthCheck_AsyncChainAbort_BroadlyGranted;
			return result;
		}

		if(!new SEL_PermissionSetAssignment().hasAnyAssignee(UTIL_AsyncChain.ABORT_PERMISSION_SET_NAME))
		{
			result.status = STATUS_WARN;
			result.detail = System.Label.HealthCheck_AsyncChainAbort_NoAssignees;
			return result;
		}

		result.status = STATUS_PASS;
		result.detail = System.Label.HealthCheck_AsyncChainAbort_Configured;
		return result;
	}

	/**
	 * @description Finds profiles other than System Administrator that hold the abort custom permission.
	 * An Install for All Users writes such grants, and they quietly let every user in those profiles
	 * abort chains. An admins-only install grants it to System Administrator, which is expected and never
	 * triggers this check. The permission is looked up through SEL_CustomPermission.getCustomPermissionId
	 * with this package's namespace, so a permission of the subscriber or of another package that has the
	 * same DeveloperName can never trigger the warning. Its grants are then traced to the permission sets
	 * that the profiles own. When the System Administrator profile cannot be found by name (standard
	 * profile names are translated for users who do not use English), the method returns false. The abort
	 * check then goes on to its other conditions, and System Administrator's own grant is never reported
	 * as a broad grant. UTIL_FeatureFlag.checkProfile handles a missing profile the same way. The two reads of the
	 * permission setup ignore record sharing and object access (bypassSharingInternal() and systemModeInternal()): the
	 * person who opens the Health Check may not be allowed to read that setup, and the check returns only a yes or no,
	 * never the rows it read.
	 *
	 * @return True when a profile other than System Administrator holds the abort custom permission.
	 */
	private static Boolean hasNonAdministratorProfileAbortGrant()
	{
		Id abortPermissionId = SEL_CustomPermission.getCustomPermissionId(UTIL_AsyncChain.ABORT_CUSTOM_PERMISSION_NAME, UTIL_System.getManagedPackageNamespace());
		if(abortPermissionId == null)
		{
			return false;
		}

		List<SetupEntityAccess> grants = QRY_Builder.selectFrom(SetupEntityAccess.SObjectType)
				.systemModeInternal()
				.addField(SetupEntityAccess.ParentId)
				.condition(SetupEntityAccess.SetupEntityId).equals(abortPermissionId)
				.bypassSharingInternal()
				.toList();
		if(grants.isEmpty())
		{
			return false;
		}

		Set<Id> parentIds = new Set<Id>();
		for(SetupEntityAccess grant : grants)
		{
			parentIds.add(grant.ParentId);
		}

		Id administratorProfileId = new SEL_Profile().findByName(SEL_Profile.PROFILE_SYSTEM_ADMIN)?.Id;
		if(administratorProfileId == null)
		{
			return false;
		}

		List<PermissionSet> profileOwnedParents = QRY_Builder.selectFrom(PermissionSet.SObjectType)
				.systemModeInternal()
				.addField(PermissionSet.ProfileId)
				.condition(PermissionSet.Id).isIn(new List<Id>(parentIds))
				.condition(PermissionSet.IsOwnedByProfile).equals(true)
				.bypassSharingInternal()
				.toList();
		for(PermissionSet parent : profileOwnedParents)
		{
			if(parent.ProfileId != null && parent.ProfileId != administratorProfileId)
			{
				return true;
			}
		}

		return false;
	}

	/**
	 * @description Reports whether a chain watchdog job is scheduled, and warns with a one-click fix when
	 * it is not. Without a watchdog, a chain that the platform quietly drops stays Running forever, so
	 * this check shows that gap. Has no actionLabel, for the same reason as the abort check:
	 * healthCheck.js draws this row's two actions (schedule and customize) from its own template branch.
	 * The Pass detail also says whether the watchdog uses one of the org's scheduled-job slots or runs on
	 * the job runner at no slot cost. This is read from the watchdog that is scheduled: one left on its own
	 * scheduled job uses a slot, whatever the state of the job runner.
	 *
	 * @param state The job runner state.
	 *
	 * @return The check result: Pass when a watchdog job is scheduled; Warn otherwise.
	 */
	private static DTO_HealthCheckResult checkChainWatchdog(JobRunnerState state)
	{
		DTO_HealthCheckResult result = new DTO_HealthCheckResult();
		result.name = CHECK_CHAIN_WATCHDOG;
		result.priority = PRIORITY_CHAIN_WATCHDOG;

		WatchdogSchedule watchdogSchedule = describeChainWatchdogSchedule(state);

		if(watchdogSchedule.isScheduled)
		{
			result.status = STATUS_PASS;
			result.detail = System.Label.HealthCheck_ChainWatchdog_Configured + UTIL_String.SPACE
					+ (watchdogSchedule.ridesTheRunner
					? System.Label.HealthCheck_ChainWatchdog_SlotCostOnRunner
					: System.Label.HealthCheck_ChainWatchdog_SlotCostOwnSlot);
			return result;
		}

		result.status = STATUS_WARN;
		result.detail = System.Label.HealthCheck_ChainWatchdog_Missing;
		return result;
	}

	/**
	 * @description Decides whether SCHED_ChainWatchdog is scheduled, and how it is scheduled, honouring
	 * both scheduling paths the Async Processing guide documents: an active declarative ScheduledJob__c
	 * for the class, or a live scheduled-Apex platform job (a hand-run System.schedule leaves no
	 * ScheduledJob__c record, and a declarative activation produces the same platform row, so the overlap
	 * is expected). A declarative watchdog set to run on the job runner counts only while a job runner
	 * is active: without one, nothing would ever start it. Only a watchdog that runs on the job runner
	 * is free of a scheduled-job slot; one on its own scheduled job, and one a hand-run System.schedule
	 * created, each hold one of the org's hundred slots.
	 *
	 * @param state The job runner state.
	 *
	 * @return What the org's watchdog schedule looks like.
	 */
	private static WatchdogSchedule describeChainWatchdogSchedule(JobRunnerState state)
	{
		WatchdogSchedule watchdogSchedule = new WatchdogSchedule();
		String watchdogClassName = SCHED_ChainWatchdog.class.getName();

		for(ScheduledJob__c watchdog : new SEL_ScheduledJob().findActiveByClassName(watchdogClassName))
		{
			Boolean ridesTheRunner = UTIL_ScheduledJobRunner.isJobRunnerMode(watchdog);

			if(!ridesTheRunner || state.isActive())
			{
				watchdogSchedule.isScheduled = true;
				watchdogSchedule.ridesTheRunner = ridesTheRunner;
				return watchdogSchedule;
			}
		}

		ApexClass watchdogClass = new SEL_ApexClass().findByQualifiedName(watchdogClassName);
		watchdogSchedule.isScheduled = watchdogClass != null
				&& !new SEL_AsyncApexJob().findLiveScheduledApexByApexClassId(watchdogClass.Id).isEmpty();
		return watchdogSchedule;
	}

	/**
	 * @description Returns the chain-watchdog schedule proposal: the defaults the one-click schedule
	 * applies and the prefill the customize path hands the scheduled job editor. Supplied by Apex so
	 * the LWC never has to guess the namespace-qualified scheduler class name.
	 *
	 * @return The watchdog schedule proposal with recommended defaults
	 */
	@AuraEnabled
	public static DTO_ChainWatchdogProposal getChainWatchdogProposal()
	{
		DTO_ChainWatchdogProposal proposal = new DTO_ChainWatchdogProposal();
		proposal.schedulerName = System.Label.HealthCheck_ChainWatchdog_SchedulerName;
		proposal.schedulerClassName = SCHED_ChainWatchdog.class.getName();
		proposal.cronExpression = WATCHDOG_CRON;
		proposal.staleThresholdMinutesParameterName = SCHED_ChainWatchdog.PARAMETER_STALE_THRESHOLD_MINUTES;
		proposal.staleThresholdMinutes = WATCHDOG_DEFAULT_STALE_THRESHOLD_MINUTES;
		proposal.batchSizeParameterName = SCHED_ChainWatchdog.PARAMETER_BATCH_SIZE;
		proposal.batchSize = WATCHDOG_DEFAULT_BATCH_SIZE;
		return proposal;
	}

	/**
	 * @description Creates the active SCHED_ChainWatchdog ScheduledJob__c with the recommended
	 * defaults, in the same shape applyRetentionRecommendations uses. Does nothing when a watchdog
	 * is already scheduled through either path, so a click on an out-of-date button never creates a
	 * duplicate. When a job runner is active and the administrator who presses the button holds the
	 * Manage Job Runner permission (needed to put a job on the runner), the watchdog runs on the runner
	 * and uses no slot; otherwise it takes its own slot as before. A watchdog left waiting on a job runner
	 * that stopped is moved back to a scheduled job of its own, instead of a second watchdog being added.
	 *
	 * @param cronExpression Cron to schedule with; blank falls back to the recommended hourly default
	 *
	 * @return Id of the created ScheduledJob__c, of the watchdog moved back to its own scheduled job, or null when
	 * one was already scheduled
	 */
	@AuraEnabled
	public static Id scheduleChainWatchdog(String cronExpression)
	{
		JobRunnerState state = loadJobRunnerState();

		if(describeChainWatchdogSchedule(state).isScheduled)
		{
			return null;
		}

		if(!state.isActive())
		{
			List<Id> movedWatchdogIds = moveRunnerModeWatchdogsToTheirOwnScheduledJob(new UTIL_ScheduledJobRunner.FrameworkWriter());

			if(!movedWatchdogIds.isEmpty())
			{
				return movedWatchdogIds[0];
			}
		}

		DTO_NameValues jobParameters = new DTO_NameValues();
		jobParameters.add(SCHED_ChainWatchdog.PARAMETER_STALE_THRESHOLD_MINUTES, WATCHDOG_DEFAULT_STALE_THRESHOLD_MINUTES);
		jobParameters.add(SCHED_ChainWatchdog.PARAMETER_BATCH_SIZE, WATCHDOG_DEFAULT_BATCH_SIZE);

		Boolean ridesTheRunner = state.isActive() && UTIL_ScheduledJobRunner.hasManagePermission();

		List<Id> insertedIds = DML_Builder.newTransaction().withSystemMode().doInsert(new List<ScheduledJob__c>
		{
				new ScheduledJob__c(
						SchedulerName__c = System.Label.HealthCheck_ChainWatchdog_SchedulerName,
						ClassName__c = SCHED_ChainWatchdog.class.getName(),
						CronExpression__c = String.isBlank(cronExpression) ? WATCHDOG_CRON : cronExpression,
						IsActive__c = true,
						Timezone__c = UserInfo.getTimeZone().getID(),
						Parameters__c = jobParameters.serialize(),
						ExecutionMode__c = ridesTheRunner
								? UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER
								: UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB
				)
		}).execute().getInsertedIds();

		return insertedIds.isEmpty() ? null : insertedIds[0];
	}

	/**
	 * @description The job runner's status for the Health Check card: whether it is active, at what check interval and
	 * slot cost, who its jobs run as and whether that user is active, when it last checked for due jobs, the slot
	 * breakdown, how many jobs wait on it, and whether the running user may change it.
	 *
	 * @return The status.
	 */
	@AuraEnabled
	public static DTO_JobRunnerStatus getJobRunnerStatus()
	{
		return describeJobRunner(loadJobRunnerState());
	}

	/**
	 * @description Activates the job runner at a check interval: replaces the runner's records with one per minute mark,
	 * scheduled as the running user, who becomes the user every job on the runner runs as.
	 *
	 * @param intervalMinutes 60, 30, 15, 10 or 5.
	 *
	 * @return The fresh status.
	 *
	 * @throws AuraHandledException When the running user does not hold the Manage Job Runner permission, or the interval
	 * is not one the runner offers. A refusal carries its label text; a lock wait or a failed write carries the platform's
	 * own words.
	 */
	@AuraEnabled
	public static DTO_JobRunnerStatus activateJobRunner(Integer intervalMinutes)
	{
		try
		{
			requireManagePermission();

			if(intervalMinutes == null || !UTIL_ScheduledJobRunner.CHECK_INTERVAL_MINUTES.contains(intervalMinutes))
			{
				throw clientError(System.Label.HealthCheck_JobRunner_InvalidCheckFrequency);
			}

			replaceRunnerRecords(intervalMinutes);

			return getJobRunnerStatus();
		}
		catch(Exception failure)
		{
			throw clientError(failure.getMessage());
		}
	}

	/**
	 * @description Replaces the runner's records at the check interval derived from the existing ones, as the running
	 * user. When no interval can be derived (no runner record exists), asks the caller to choose one.
	 *
	 * @return The fresh status.
	 *
	 * @throws AuraHandledException When the running user does not hold the Manage Job Runner permission, or no interval
	 * the runner offers can be derived from the existing records. A refusal carries its label text; a lock wait or a failed
	 * write carries the platform's own words.
	 */
	@AuraEnabled
	public static DTO_JobRunnerStatus repairJobRunner()
	{
		try
		{
			requireManagePermission();

			JobRunnerState state = loadJobRunnerState();
			Integer checkInterval = deriveCheckInterval(state.allMinuteMarks);

			if(checkInterval == null || !UTIL_ScheduledJobRunner.CHECK_INTERVAL_MINUTES.contains(checkInterval))
			{
				throw clientError(System.Label.HealthCheck_JobRunner_RepairNeedsCheckFrequency);
			}

			replaceRunnerRecords(checkInterval);

			return getJobRunnerStatus();
		}
		catch(Exception failure)
		{
			throw clientError(failure.getMessage());
		}
	}

	/**
	 * @description Deletes the runner's records, which aborts their scheduled jobs. A watchdog that ran on
	 * the runner is moved back to a scheduled job of its own, so the async safety net keeps one. Jobs set
	 * to run on the runner are left in place and reported by the jobs-waiting row.
	 *
	 * @return The fresh status.
	 *
	 * @throws AuraHandledException When the running user does not hold the Manage Job Runner permission. A refusal carries
	 * its label text; a lock wait or a failed write carries the platform's own words.
	 */
	@AuraEnabled
	public static DTO_JobRunnerStatus deactivateJobRunner()
	{
		try
		{
			requireManagePermission();

			UTIL_ScheduledJobRunner.FrameworkWriter writer = new UTIL_ScheduledJobRunner.FrameworkWriter();
			TRG_ScheduleJob.allowRunnerRecordManagement = true;

			try
			{
				writer.lockRunnerManagement();
				writer.deleteRecords(new SEL_ScheduledJob().findRunnerRecords());
			}
			finally
			{
				TRG_ScheduleJob.allowRunnerRecordManagement = false;
			}

			moveRunnerModeWatchdogsToTheirOwnScheduledJob(writer);

			return getJobRunnerStatus();
		}
		catch(Exception failure)
		{
			throw clientError(failure.getMessage());
		}
	}

	/**
	 * @description Moves every active watchdog record that was set to run on the job runner back to a scheduled job of
	 * its own, so the async safety net keeps checking chains once the runner it ran on is gone. Deactivate calls it
	 * for the runner it has just removed. The one-click schedule calls it for a runner that stopped some other way: there
	 * the watchdog to move is the one the row is warning about, not a second watchdog to create.
	 *
	 * @param writer The framework writer the caller is already working through.
	 *
	 * @return The ids of the watchdog records that were moved, in the order they were read.
	 */
	private static List<Id> moveRunnerModeWatchdogsToTheirOwnScheduledJob(UTIL_ScheduledJobRunner.FrameworkWriter writer)
	{
		List<Id> movedWatchdogIds = new List<Id>();

		for(ScheduledJob__c watchdog : new SEL_ScheduledJob().findActiveByClassName(SCHED_ChainWatchdog.class.getName()))
		{
			if(UTIL_ScheduledJobRunner.isJobRunnerMode(watchdog))
			{
				writer.updateRecord(new ScheduledJob__c(Id = watchdog.Id, ExecutionMode__c = UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB));
				movedWatchdogIds.add(watchdog.Id);
			}
		}

		return movedWatchdogIds;
	}

	/**
	 * @description Deletes every runner record and creates one per minute mark at the check interval. This runs inside
	 * the trigger's Health Check allowance and under the runner-management lock, so two administrators repairing at the
	 * same moment take turns and the set of records is never doubled. The records are own-mode records in the running
	 * user's time zone, so no minute shift applies.
	 *
	 * @param intervalMinutes The check interval.
	 */
	private static void replaceRunnerRecords(Integer intervalMinutes)
	{
		UTIL_ScheduledJobRunner.FrameworkWriter writer = new UTIL_ScheduledJobRunner.FrameworkWriter();
		TRG_ScheduleJob.allowRunnerRecordManagement = true;

		try
		{
			writer.lockRunnerManagement();
			writer.deleteRecords(new SEL_ScheduledJob().findRunnerRecords());

			List<ScheduledJob__c> runners = new List<ScheduledJob__c>();
			for(Integer mark = 0; mark < MINUTES_PER_HOUR; mark += intervalMinutes)
			{
				runners.add(new ScheduledJob__c(
						SchedulerName__c = String.format(System.Label.HealthCheck_JobRunnerRecordName, new List<Object> {String.valueOf(mark).leftPad(2, '0')}),
						ClassName__c = UTIL_ScheduledJobRunner.RUNNER_CLASS_NAME,
						CronExpression__c = String.format(RUNNER_CRON_TEMPLATE, new List<Object> {mark}),
						IsActive__c = true,
						Timezone__c = UserInfo.getTimeZone().getID(),
						ExecutionMode__c = UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB
				));
			}

			writer.insertRecords(runners);
		}
		finally
		{
			TRG_ScheduleJob.allowRunnerRecordManagement = false;
		}
	}

	/**
	 * @description Refuses the action unless the running user holds the Manage Job Runner permission.
	 *
	 * @throws AuraHandledException With the label text when the running user does not hold it.
	 */
	private static void requireManagePermission()
	{
		if(!UTIL_ScheduledJobRunner.hasManagePermission())
		{
			throw clientError(System.Label.HealthCheck_JobRunner_PermissionRequired);
		}
	}

	/**
	 * @description Builds an exception whose message survives to the client and to a test: AuraHandledException hides its
	 * message unless it is set explicitly.
	 *
	 * @param message The text the client reads: a refusal's label, or the platform's own words for a failure.
	 *
	 * @return The exception, ready to throw.
	 */
	private static AuraHandledException clientError(String message)
	{
		AuraHandledException error = new AuraHandledException(message);
		error.setMessage(message);
		return error;
	}

	/**
	 * @description Turns the job runner state into the card's payload.
	 *
	 * @param state The job runner state.
	 *
	 * @return The status.
	 */
	private static DTO_JobRunnerStatus describeJobRunner(JobRunnerState state)
	{
		DTO_JobRunnerStatus status = new DTO_JobRunnerStatus();
		status.isActive = state.isActive();
		status.checkIntervalMinutes = state.checkIntervalMinutes;
		status.slotCost = state.expectedRecordCount;
		status.runnerRecordCount = state.runnerRecords.size();
		status.liveCronTriggerCount = state.liveTriggers.size();
		status.activatorName = state.activator?.Name;
		status.isActivatorActive = state.activator?.IsActive ?? false;
		status.lastCheckAt = state.lastCheckAt;

		SlotBreakdown slots = countSlots(state);
		status.totalScheduledApexSlots = slots.total;
		status.jobRunnerSlots = slots.jobRunner;
		status.ownModeSlots = slots.ownMode;
		status.otherSlots = slots.other;

		status.waitingJobCount = state.waitingRows.size();
		status.canManage = UTIL_ScheduledJobRunner.hasManagePermission();
		status.runningUserName = UserInfo.getName();
		return status;
	}

	/**
	 * @description Reads the runner's records, their scheduled jobs, the activator, the time of the last check and the
	 * jobs waiting on the runner.
	 *
	 * @return The job runner state.
	 */
	private static JobRunnerState loadJobRunnerState()
	{
		JobRunnerState state = new JobRunnerState();
		state.runnerRecords = new SEL_ScheduledJob().findRunnerRecords();

		for(ScheduledJob__c runner : state.runnerRecords)
		{
			Id cronTriggerId = toCronTriggerId(runner.ScheduledJobId__c);
			if(cronTriggerId != null)
			{
				state.runnerTriggerIds.add(cronTriggerId);
			}

			state.allMinuteMarks.add(minuteMarkOf(runner.CronExpression__c));

			if(state.activatedAt == null || runner.CreatedDate > state.activatedAt)
			{
				state.activatedAt = runner.CreatedDate;
			}
		}

		Map<Id, CronTrigger> triggersById = new Map<Id, CronTrigger>(new SEL_CronTrigger().findByIds(state.runnerTriggerIds));

		for(ScheduledJob__c runner : state.runnerRecords)
		{
			CronTrigger cronTrigger = triggersById.get(toCronTriggerId(runner.ScheduledJobId__c));

			if(SEL_CronTrigger.isLive(cronTrigger))
			{
				state.liveTriggers.add(cronTrigger);
				state.liveMinuteMarks.add(minuteMarkOf(runner.CronExpression__c));
				state.activatorId = state.activatorId ?? cronTrigger.OwnerId;
			}
		}

		state.checkIntervalMinutes = deriveCheckInterval(state.liveMinuteMarks);
		state.expectedRecordCount = state.checkIntervalMinutes == null ? 0 : MINUTES_PER_HOUR / state.checkIntervalMinutes;
		state.activator = state.activatorId == null ? null : (User)new SEL_User().findById(state.activatorId);
		state.lastCheckAt = SEL_ScheduleSetting.getScheduleSetting(UTIL_ScheduledJobRunner.LAST_CHECK_SETTING_NAME)?.LastSuccessfulRunTime__c;
		state.waitingRows = new SEL_ScheduledJob().findActiveJobRunnerModeRecords();
		return state;
	}

	/**
	 * @description Reads the scheduled job a record points at. The field is text, so it can hold anything; a blank or
	 * unreadable value simply means the record points at no scheduled job.
	 *
	 * @param storedCronTriggerId The record's ScheduledJobId__c value.
	 *
	 * @return The id, or null when the field holds nothing usable.
	 */
	private static Id toCronTriggerId(String storedCronTriggerId)
	{
		if(String.isBlank(storedCronTriggerId) || !(storedCronTriggerId instanceof Id))
		{
			return null;
		}

		return Id.valueOf(storedCronTriggerId);
	}

	/**
	 * @description The minute mark a runner record's expression names.
	 *
	 * @param cronExpression The record's expression, in the shape `0 M * * * ?`.
	 *
	 * @return M, or 0 when the expression is not in that shape.
	 */
	private static Integer minuteMarkOf(String cronExpression)
	{
		List<String> parts = String.isBlank(cronExpression) ? new List<String>() : cronExpression.trim().split('\\s+');

		return parts.size() > 1 && parts[1].isNumeric() ? Integer.valueOf(parts[1]) : 0;
	}

	/**
	 * @description The check interval that a set of minute marks gives: the smallest gap between two marks next to
	 * each other, going round the hour. That is the chosen interval whenever two neighbouring marks are left. A single
	 * mark means an hourly interval; an empty set gives no interval, so the answer is null.
	 *
	 * @param minuteMarks The minute marks.
	 *
	 * @return The check interval in minutes, or null.
	 */
	private static Integer deriveCheckInterval(List<Integer> minuteMarks)
	{
		if(minuteMarks.isEmpty())
		{
			return null;
		}

		List<Integer> sorted = new List<Integer>(new Set<Integer>(minuteMarks));
		sorted.sort();

		if(sorted.size() == 1)
		{
			return MINUTES_PER_HOUR;
		}

		Integer smallestGap = MINUTES_PER_HOUR - sorted[sorted.size() - 1] + sorted[0];
		for(Integer index = 1; index < sorted.size(); index++)
		{
			smallestGap = Math.min(smallestGap, sorted[index] - sorted[index - 1]);
		}

		return smallestGap;
	}

	/**
	 * @description The one result about the job runner itself: whether the user its jobs run as is still active,
	 * whether its set of scheduled jobs is complete for the interval its records give, and whether it has checked for
	 * due jobs within that interval. Only the first of these that finds a problem is reported, so the reader sees the
	 * problem to fix first, not several results about the same problem. An org with no runner record at all reports
	 * nothing here, even while jobs wait for a runner: the jobs-waiting row reports that problem, and Activate is the
	 * fix that helps. A runner switched on or repaired since its last check is waiting for its first check again, so
	 * it is treated like a runner that was just switched on, not like one that stopped at a check older than the
	 * repair.
	 *
	 * @param state The job runner state.
	 *
	 * @return The check result.
	 */
	private static DTO_HealthCheckResult checkJobRunner(JobRunnerState state)
	{
		DTO_HealthCheckResult result = newResult(CHECK_JOB_RUNNER, PRIORITY_JOB_RUNNER);

		if(state.runnerRecords.isEmpty())
		{
			return pass(result, System.Label.HealthCheck_JobRunner_NotApplicable);
		}

		if(state.activator != null && !state.activator.IsActive)
		{
			return fail(result, String.format(System.Label.HealthCheck_JobRunner_ActivatorInactive, new List<Object> {state.activator.Name}));
		}

		Integer checkInterval = deriveCheckInterval(state.allMinuteMarks);
		Integer expected = MINUTES_PER_HOUR / checkInterval;

		if(!state.isActive() || state.runnerRecords.size() != expected || state.liveTriggers.size() != expected)
		{
			return fail(result, String.format(System.Label.HealthCheck_JobRunner_Incomplete,
					new List<Object> {expected, checkInterval, state.runnerRecords.size(), state.liveTriggers.size()}));
		}

		String lastCheck = String.valueOf(state.lastCheckAt ?? state.activatedAt);
		String stoppedDetail = String.format(System.Label.HealthCheck_JobRunner_Stopped, new List<Object> {lastCheck});

		if(state.lastCheckAt == null || state.activatedAt > state.lastCheckAt)
		{
			List<Object> activationArguments = new List<Object> {String.valueOf(state.activatedAt), state.checkIntervalMinutes};

			return state.activatedAt > Datetime.now().addMinutes(-state.checkIntervalMinutes)
					? pass(result, String.format(System.Label.HealthCheck_JobRunner_AwaitingFirstCheck, activationArguments))
					: fail(result, stoppedDetail);
		}

		if(state.lastCheckAt > Datetime.now().addMinutes(-state.checkIntervalMinutes))
		{
			return pass(result, String.format(System.Label.HealthCheck_JobRunner_Pass, new List<Object> {expected, lastCheck}));
		}

		if(state.lastCheckAt > Datetime.now().addMinutes(-2 * state.checkIntervalMinutes))
		{
			return warn(result, String.format(System.Label.HealthCheck_JobRunner_Late, new List<Object> {lastCheck, state.checkIntervalMinutes}));
		}

		return fail(result, stoppedDetail);
	}

	/**
	 * @description Whether jobs are set to run on the job runner while no job runner is active.
	 *
	 * @param state The job runner state.
	 *
	 * @return The check result.
	 */
	private static DTO_HealthCheckResult checkOrphanedJobRunnerRecords(JobRunnerState state)
	{
		DTO_HealthCheckResult result = newResult(CHECK_JOB_RUNNER_ORPHANED, PRIORITY_JOB_RUNNER_ORPHANED);

		return !state.isActive() && !state.waitingRows.isEmpty()
				? fail(result, String.format(System.Label.HealthCheck_JobRunner_Orphaned_Fail, new List<Object> {state.waitingRows.size()}))
				: pass(result, System.Label.HealthCheck_JobRunner_Orphaned_Pass);
	}

	/**
	 * @description How much room the org has left for scheduled work: how many of its hundred scheduled-job slots are in
	 * use, split into the job runner's, Scheduled Job records that own a slot of their own, and everything else, and whether the
	 * runner's last check started everything that was due. The slot breakdown is always shown, whether a runner is
	 * active or not, because an org near the cap needs that warning either way. A job set to run on the runner whose
	 * next run is still at or before the time of that check was left waiting by it, and adds a second sentence. A job
	 * whose save failed after its run was started is still due and counts there too. That check's ERROR log entry names
	 * the job, so the two results together tell a check that ran out of room apart from a save that was refused.
	 *
	 * @param state The job runner state.
	 *
	 * @return The check result.
	 */
	private static DTO_HealthCheckResult checkJobRunnerCapacity(JobRunnerState state)
	{
		DTO_HealthCheckResult result = newResult(CHECK_JOB_RUNNER_CAPACITY, PRIORITY_JOB_RUNNER_CAPACITY);
		SlotBreakdown slots = countSlots(state);
		List<Object> slotArguments = new List<Object> {slots.total, slots.jobRunner, slots.ownMode, slots.other};
		Boolean slotsAtFailThreshold = slots.total >= SCHEDULED_APEX_SLOT_FAIL_FROM;
		Boolean slotsAtWarnThreshold = !slotsAtFailThreshold && slots.total >= SCHEDULED_APEX_SLOT_WARN_FROM;
		String slotsSentence = System.Label.HealthCheck_JobRunner_Capacity_Slots;

		if(slotsAtFailThreshold)
		{
			slotsSentence = System.Label.HealthCheck_JobRunner_Capacity_SlotsFail;
		}
		else if(slotsAtWarnThreshold)
		{
			slotsSentence = System.Label.HealthCheck_JobRunner_Capacity_SlotsWarn;
		}

		String detail = String.format(slotsSentence, slotArguments);
		Integer leftWaiting = state.isActive() && state.lastCheckAt != null
				? new SEL_ScheduledJob().countDueJobRunnerRecords(state.lastCheckAt)
				: 0;

		if(leftWaiting > 0)
		{
			Integer checkLimit = SEL_AsynchronousJobSetting.getBatchSize(UTIL_ScheduledJobRunner.CHECK_LIMIT_SETTING_NAME, UTIL_ScheduledJobRunner.DEFAULT_CHECK_LIMIT);
			detail += ' ' + String.format(System.Label.HealthCheck_JobRunner_Capacity_LeftWaiting, new List<Object> {leftWaiting, checkLimit});
		}

		if(slotsAtFailThreshold)
		{
			return fail(result, detail);
		}

		return slotsAtWarnThreshold || leftWaiting > 0 ? warn(result, detail) : pass(result, detail);
	}

	/**
	 * @description Counts every Scheduled Apex row and attributes each to the job runner, to a Scheduled Job record that owns a slot
	 * of its own, or to everything else. Scheduled-job ids are compared as ids, never as text: the same job is written
	 * as fifteen characters in one place and eighteen in another, and only an id comparison sees those as the same job.
	 *
	 * @param state The job runner state.
	 *
	 * @return The breakdown.
	 */
	private static SlotBreakdown countSlots(JobRunnerState state)
	{
		Set<Id> ownModeTriggerIds = new Set<Id>();
		for(ScheduledJob__c job : new SEL_ScheduledJob().findActiveWithPlatformJob())
		{
			if(!UTIL_ScheduledJobRunner.isRunnerRecord(job))
			{
				ownModeTriggerIds.add(toCronTriggerId(job.ScheduledJobId__c));
			}
		}

		SlotBreakdown slots = new SlotBreakdown();
		for(CronTrigger cronTrigger : new SEL_CronTrigger().findScheduledApex())
		{
			slots.total++;

			if(state.runnerTriggerIds.contains(cronTrigger.Id))
			{
				slots.jobRunner++;
			}
			else if(ownModeTriggerIds.contains(cronTrigger.Id))
			{
				slots.ownMode++;
			}
			else
			{
				slots.other++;
			}
		}

		return slots;
	}

	/**
	 * @description Starts a health check result with its display name and priority, ready for its status.
	 *
	 * @param name The display name.
	 * @param priority The display priority.
	 *
	 * @return The result.
	 */
	private static DTO_HealthCheckResult newResult(String name, Integer priority)
	{
		DTO_HealthCheckResult result = new DTO_HealthCheckResult();
		result.name = name;
		result.priority = priority;
		return result;
	}

	/**
	 * @description Marks a health check result as passing, with the detail the administrator reads.
	 *
	 * @param result The result.
	 * @param detail The detail message.
	 *
	 * @return The same result.
	 */
	private static DTO_HealthCheckResult pass(DTO_HealthCheckResult result, String detail)
	{
		result.status = STATUS_PASS;
		result.detail = detail;
		return result;
	}

	/**
	 * @description Marks a health check result as a warning, with the detail the administrator reads.
	 *
	 * @param result The result.
	 * @param detail The detail message.
	 *
	 * @return The same result.
	 */
	private static DTO_HealthCheckResult warn(DTO_HealthCheckResult result, String detail)
	{
		result.status = STATUS_WARN;
		result.detail = detail;
		return result;
	}

	/**
	 * @description Marks a health check result as failing, with the detail the administrator reads.
	 *
	 * @param result The result.
	 * @param detail The detail message.
	 *
	 * @return The same result.
	 */
	private static DTO_HealthCheckResult fail(DTO_HealthCheckResult result, String detail)
	{
		result.status = STATUS_FAIL;
		result.detail = detail;
		return result;
	}

	/**
	 * @description Everything the job-runner rows and the card read, loaded once per request.
	 */
	private class JobRunnerState
	{
		/**
		 * @description The job runner's own records, oldest first.
		 */
		public List<ScheduledJob__c> runnerRecords = new List<ScheduledJob__c>();

		/**
		 * @description The scheduled jobs of those records that will still fire.
		 */
		public List<CronTrigger> liveTriggers = new List<CronTrigger>();

		/**
		 * @description The minute marks of the records whose scheduled job will still fire.
		 */
		public List<Integer> liveMinuteMarks = new List<Integer>();

		/**
		 * @description The minute marks of every record, whether its scheduled job is live or not.
		 */
		public List<Integer> allMinuteMarks = new List<Integer>();

		/**
		 * @description The ids of the scheduled jobs the records point at.
		 */
		public Set<Id> runnerTriggerIds = new Set<Id>();

		/**
		 * @description How often the runner checks for due jobs, in minutes, or null when no scheduled job is live.
		 */
		public Integer checkIntervalMinutes;

		/**
		 * @description How many records the derived check interval calls for, which is the runner's slot cost.
		 */
		public Integer expectedRecordCount = 0;

		/**
		 * @description The user the runner's scheduled jobs belong to, and so the user every job on the runner runs as.
		 */
		public Id activatorId;

		/**
		 * @description That user's record, or null when no scheduled job is live.
		 */
		public User activator;

		/**
		 * @description When the runner was last activated or repaired, read from the newest record.
		 */
		public Datetime activatedAt;

		/**
		 * @description When the runner last completed a check for due jobs, or null when it never has.
		 */
		public Datetime lastCheckAt;

		/**
		 * @description The active jobs set to run on the job runner.
		 */
		public List<ScheduledJob__c> waitingRows = new List<ScheduledJob__c>();

		/**
		 * @description Whether a job runner is active: at least one of its records still owns a scheduled job that will fire.
		 *
		 * @return True when the runner is active.
		 */
		public Boolean isActive()
		{
			return !liveTriggers.isEmpty();
		}
	}

	/**
	 * @description How the org's chain watchdog is scheduled, which is what the watchdog row reads its slot cost from.
	 */
	private class WatchdogSchedule
	{
		/**
		 * @description Whether a watchdog is scheduled at all, through either of the two scheduling paths.
		 */
		public Boolean isScheduled = false;

		/**
		 * @description Whether the watchdog that is scheduled runs on the job runner, and so costs no slot of its own.
		 */
		public Boolean ridesTheRunner = false;
	}

	/**
	 * @description The org's Scheduled Apex rows, split three ways.
	 */
	private class SlotBreakdown
	{
		/**
		 * @description Every Scheduled Apex row in the org.
		 */
		public Integer total = 0;

		/**
		 * @description The rows belonging to the job runner's own records.
		 */
		public Integer jobRunner = 0;

		/**
		 * @description The rows belonging to Scheduled Job records that own a scheduled job of their own.
		 */
		public Integer ownMode = 0;

		/**
		 * @description The rows belonging to everything else in the org.
		 */
		public Integer other = 0;
	}

	/**
	 * @description The job runner's status for the Health Check card.
	 */
	public class DTO_JobRunnerStatus
	{
		/**
		 * @description Whether a job runner is active.
		 */
		@AuraEnabled public Boolean isActive;

		/**
		 * @description How often the runner checks for due jobs, in minutes, or null when it is not active.
		 */
		@AuraEnabled public Integer checkIntervalMinutes;

		/**
		 * @description How many of the org's hundred scheduled-job slots the runner itself costs.
		 */
		@AuraEnabled public Integer slotCost;

		/**
		 * @description How many runner records exist, which the card compares with the live count to spot a broken set.
		 */
		@AuraEnabled public Integer runnerRecordCount;

		/**
		 * @description How many of those records still own a scheduled job that will fire.
		 */
		@AuraEnabled public Integer liveCronTriggerCount;

		/**
		 * @description The name of the user every job on the runner runs as, or null when it is not active.
		 */
		@AuraEnabled public String activatorName;

		/**
		 * @description Whether that user is still active.
		 */
		@AuraEnabled public Boolean isActivatorActive;

		/**
		 * @description When the runner last completed a check for due jobs, or null when it never has.
		 */
		@AuraEnabled public Datetime lastCheckAt;

		/**
		 * @description Every Scheduled Apex row in the org.
		 */
		@AuraEnabled public Integer totalScheduledApexSlots;

		/**
		 * @description The rows belonging to the job runner's own records.
		 */
		@AuraEnabled public Integer jobRunnerSlots;

		/**
		 * @description The rows belonging to Scheduled Job records that own a scheduled job of their own.
		 */
		@AuraEnabled public Integer ownModeSlots;

		/**
		 * @description The rows belonging to everything else in the org.
		 */
		@AuraEnabled public Integer otherSlots;

		/**
		 * @description How many active jobs are set to run on the job runner.
		 */
		@AuraEnabled public Integer waitingJobCount;

		/**
		 * @description Whether the running user holds the Manage Job Runner permission, which gates all three actions.
		 */
		@AuraEnabled public Boolean canManage;

		/**
		 * @description The running user's name, which the Activate dialogue shows as the user the jobs will run as.
		 */
		@AuraEnabled public String runningUserName;
	}

	/**
	 * @description Data transfer object representing a single health check result.
	 */
	public class DTO_HealthCheckResult
	{
		/**
		 * @description The name of the health check.
		 */
		@AuraEnabled
		public String name;

		/**
		 * @description The status of the health check (Pass, Warn, or Fail).
		 */
		@AuraEnabled
		public String status;

		/**
		 * @description Detail message explaining the result.
		 */
		@AuraEnabled
		public String detail;

		/**
		 * @description Optional label for an action button associated with this result.
		 */
		@AuraEnabled
		public String actionLabel;

		/**
		 * @description Record counts for unconfigured framework data objects. Populated by the Data Retention check
		 * so the component can display per-object counts with locale-aware formatting.
		 */
		@AuraEnabled
		public List<DTO_ObjectRecordCount> recordCounts;

		/**
		 * @description Priority ranking within the severity section (lower sorts first). Drives the
		 * client-side ordering so the most foundational issue in each Fail/Warn section sits at the top.
		 */
		@AuraEnabled
		public Integer priority;
	}

	/**
	 * @description Represents a record count for a single object, used by the Data Retention health check.
	 */
	public class DTO_ObjectRecordCount
	{
		/**
		 * @description The API name of the object (e.g. LogEntry__c).
		 */
		@AuraEnabled
		public String objectName;

		/**
		 * @description The number of records in the object.
		 */
		@AuraEnabled
		public Integer recordCount;

		/**
		 * @description Constructs a record count entry.
		 *
		 * @param objectName The object API name
		 * @param recordCount The number of records
		 */
		public DTO_ObjectRecordCount(String objectName, Integer recordCount)
		{
			this.objectName = objectName;
			this.recordCount = recordCount;
		}
	}

	/**
	 * @description Payload describing a single retention recommendation and its current record-count
	 * context. Returned by CTRL_HealthCheck.getRetentionProposals and submitted back to
	 * applyRetentionRecommendations.
	 */
	public class DTO_RetentionProposal
	{
		/**
		 * @description Fully-qualified API name of the target framework object (namespaced in subscriber orgs).
		 */
		@AuraEnabled public String objectApiName;

		/**
		 * @description Human-readable object label (from Schema describe).
		 */
		@AuraEnabled public String objectLabel;

		/**
		 * @description Current record count for the target object, displayed in the confirmation dialog.
		 */
		@AuraEnabled public Integer recordCount;

		/**
		 * @description Retention window in days: records older than this are purged.
		 */
		@AuraEnabled public Integer retentionDays;

		/**
		 * @description Default SchedulerName__c value applied when creating the ScheduledJob__c record.
		 */
		@AuraEnabled public String schedulerName;

		/**
		 * @description Fully-qualified Apex class name (namespace-aware) for the purge scheduler.
		 * Supplied by Apex so the LWC never has to guess the namespace when pre-populating the
		 * scheduled job editor modal.
		 */
		@AuraEnabled public String schedulerClassName;

		/**
		 * @description Cron expression to schedule with. May be overridden by the user via the confirmation dialog picklist.
		 */
		@AuraEnabled public String cronExpression;
	}

	/**
	 * @description Payload describing the chain-watchdog schedule proposal: the defaults the
	 * one-click schedule applies and the prefill the customize path hands the scheduled job editor.
	 * Returned by CTRL_HealthCheck.getChainWatchdogProposal.
	 */
	public class DTO_ChainWatchdogProposal
	{
		/**
		 * @description Default SchedulerName__c value applied when creating the ScheduledJob__c record.
		 */
		@AuraEnabled public String schedulerName;

		/**
		 * @description Fully-qualified Apex class name (namespace-aware) for the watchdog scheduler.
		 * Supplied by Apex so the LWC never has to guess the namespace when pre-populating the
		 * scheduled job editor modal.
		 */
		@AuraEnabled public String schedulerClassName;

		/**
		 * @description Recommended cron expression (hourly). May be replaced via the confirm dialog picklist.
		 */
		@AuraEnabled public String cronExpression;

		/**
		 * @description Parameter name for the stale threshold, for the editor-modal prefill.
		 */
		@AuraEnabled public String staleThresholdMinutesParameterName;

		/**
		 * @description Recommended stale threshold in minutes, serialized as parameter text.
		 */
		@AuraEnabled public String staleThresholdMinutes;

		/**
		 * @description Parameter name for the sweep batch size, for the editor-modal prefill.
		 */
		@AuraEnabled public String batchSizeParameterName;

		/**
		 * @description Recommended maximum chains per sweep, serialized as parameter text.
		 */
		@AuraEnabled public String batchSize;
	}

	/**
	 * @description The recommended retention settings for one framework object. The values are Apex
	 * constants and not CMDT, because the four framework objects are a fixed internal list (subscribers
	 * do not add to it), and CMDT would add metadata files without adding anything useful.
	 */
	private class RetentionRecommendation
	{
		/**
		 * @description Retention window in days: records older than this are purged.
		 */
		public final Integer retentionDays;

		/**
		 * @description Default cron expression for the purge scheduler.
		 */
		public final String cronExpression;

		/**
		 * @description Default scheduler name to pre-populate when creating the purge job.
		 */
		public final String schedulerName;

		/**
		 * @description Date field the recommended purge job evaluates for record age, or null to let
		 * SCHED_PurgeRecords fall back to its CreatedDate default. The AsyncChainExecution__c entry
		 * must key on CompletedAt__c: chains that are still running, stalled, or awaiting recovery
		 * leave that field null, so a purge aged on CompletedAt__c can never delete them.
		 */
		public final SObjectField dateField;

		/**
		 * @description Constructs a RetentionRecommendation with no date field: calls the four-argument
		 * constructor with a null dateField, so the recommended purge job measures record age by
		 * CreatedDate (the SCHED_PurgeRecords default).
		 *
		 * @param retentionDays Retention window in days
		 * @param cronExpression Default cron expression
		 * @param schedulerName Default scheduler display name
		 */
		public RetentionRecommendation(Integer retentionDays, String cronExpression, String schedulerName)
		{
			this(retentionDays, cronExpression, schedulerName, null);
		}

		/**
		 * @description Constructs a RetentionRecommendation.
		 *
		 * @param retentionDays Retention window in days
		 * @param cronExpression Default cron expression
		 * @param schedulerName Default scheduler display name
		 * @param dateField Date field the purge job evaluates for record age, or null for the CreatedDate default
		 */
		public RetentionRecommendation(Integer retentionDays, String cronExpression, String schedulerName, SObjectField dateField)
		{
			this.retentionDays = retentionDays;
			this.cronExpression = cronExpression;
			this.schedulerName = schedulerName;
			this.dateField = dateField;
		}
	}
}