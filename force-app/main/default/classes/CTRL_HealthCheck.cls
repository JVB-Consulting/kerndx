// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Controller for the Health Check component. Runs diagnostic checks
 * to verify that required post-install configuration (CSP Trusted Site,
 * Platform Cache) is in place, surfaces retention recommendations for
 * framework data objects, reports the org's data-masking posture, and offers
 * one-click scheduling for the chain watchdog.
 *
 * @see CTRL_HealthCheck_TEST
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, August 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength')
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
	 * @description Display name for the Trusted Site health check.
	 */
	@TestVisible
	private static final String CHECK_TRUSTED_SITE = System.Label.HealthCheck_TrustedSite_CheckName;

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
	// Platform Cache partitions and the CSP Trusted Site are the most foundational to the package working,
	// so they outrank resolver / retention configuration if they ever co-appear in the same severity section.
	/**
	 * @description Display priority for the Organisation Cache health check.
	 */
	private static final Integer PRIORITY_ORG_CACHE = 10;

	/**
	 * @description Display priority for the Session Cache health check.
	 */
	private static final Integer PRIORITY_SESSION_CACHE = 20;

	/**
	 * @description Display priority for the Trusted Site health check.
	 */
	private static final Integer PRIORITY_TRUSTED_SITE = 30;

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
	 * @description Detail message template when a CSP Trusted Site is configured for the org domain.
	 * Sourced from Custom Label. Placeholder {0} is substituted at request time with the org domain URL.
	 */
	@TestVisible
	private static final String DETAIL_TRUSTED_SITE_CONFIGURED = System.Label.HealthCheck_TrustedSite_Configured;

	/**
	 * @description Detail message template when a CSP Trusted Site is missing for the org domain.
	 * Sourced from Custom Label. Placeholder {0} is substituted at request time with the org domain URL.
	 */
	@TestVisible
	private static final String DETAIL_TRUSTED_SITE_MISSING = System.Label.HealthCheck_TrustedSite_Missing;

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
	 * @description Default hourly cron expression for the chain watchdog sweep — the cadence the
	 * Async Processing guide recommends.
	 */
	private static final String WATCHDOG_CRON = '0 0 * * * ?';

	/**
	 * @description Default stale threshold, in minutes, the one-click watchdog schedule applies.
	 * Held as a String because scheduled-job parameters serialize as name-value text.
	 */
	private static final String WATCHDOG_DEFAULT_STALE_THRESHOLD_MINUTES = '30';

	/**
	 * @description Default maximum chains per sweep the one-click watchdog schedule applies.
	 * Held as a String because scheduled-job parameters serialize as name-value text.
	 */
	private static final String WATCHDOG_DEFAULT_BATCH_SIZE = '50';

	/**
	 * @description Retention recommendations keyed by framework SObjectType. Drives both the
	 * Data Retention health check and the retention-proposal list returned to the UI.
	 */
	private static final Map<SObjectType, RecommendationSpec> FRAMEWORK_RECOMMENDATIONS = new Map<SObjectType, RecommendationSpec>
	{
			LogEntry__c.SObjectType => new RecommendationSpec(90, DEFAULT_CRON, System.Label.HealthCheck_DataRetention_SchedulerName_LogEntry),
			ApiCall__c.SObjectType => new RecommendationSpec(90, DEFAULT_CRON, System.Label.HealthCheck_DataRetention_SchedulerName_ApiCall),
			ApiIssue__c.SObjectType => new RecommendationSpec(180, DEFAULT_CRON, System.Label.HealthCheck_DataRetention_SchedulerName_ApiIssue),
			AsyncChainExecution__c.SObjectType => new RecommendationSpec(90, DEFAULT_CRON,
					System.Label.HealthCheck_DataRetention_SchedulerName_AsyncChainExecution, AsyncChainExecution__c.CompletedAt__c)
	};

	/**
	 * @description Map from each framework object's qualified API name (namespaced in subscriber orgs)
	 * to its SObjectType, derived from FRAMEWORK_RECOMMENDATIONS. Used when matching user-supplied
	 * retention proposals (which carry API names from the UI) back to the internal SObjectType keys.
	 */
	private static final Map<String, SObjectType> FRAMEWORK_OBJECT_TYPE_BY_QUALIFIED_API_NAME = buildFrameworkObjectTypeByQualifiedApiName();

	/**
	 * @description Builds the API-name to SObjectType index once at class load. Kept as a
	 * separate static method so the final field can be assigned in a single expression while
	 * the describe loop stays readable.
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
		return new List<DTO_HealthCheckResult>
		{
				checkOrganisationCache(),
				checkSessionCache(),
				checkTrustedSite(),
				checkClassTypeResolver(),
				checkDataRetention(),
				checkMaskingPosture(),
				checkCustomObjectMaskingCoverage(),
				checkAsyncChainAbort(),
				checkChainWatchdog()
		};
	}

	/**
	 * @description Returns the set of framework-object retention proposals for objects that do not
	 * yet have an active SCHED_PurgeRecords job. Each proposal carries the current record count and
	 * recommended retention window / cron defaults to display in the confirmation dialog.
	 *
	 * @return Ordered list of DTO_RetentionProposal (one per unconfigured framework object)
	 */
	@AuraEnabled(Cacheable=false)
	public static List<DTO_RetentionProposal> getRetentionProposals()
	{
		List<DTO_RetentionProposal> proposals = new List<DTO_RetentionProposal>();

		for(SObjectType objectType : getUnconfiguredRetentionObjectTypes())
		{
			DescribeSObjectResult describe = UTIL_SObjectDescribe.getDescribe(objectType).getDescribe();
			RecommendationSpec recommendation = FRAMEWORK_RECOMMENDATIONS.get(objectType);

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

			RecommendationSpec recommendation = FRAMEWORK_RECOMMENDATIONS.get(targetType);

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
	 * SCHED_PurgeRecords job — the common filter behind both the Data Retention health
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
	 * the configured object names from their Parameters__c JSON.
	 *
	 * @return Set of object API names covered by active purge jobs
	 */
	private static Set<String> getCoveredRetentionObjects()
	{
		Set<String> coveredObjects = new Set<String>();

		for(ScheduledJob__c job : new SEL_ScheduledJob().findActiveByClassName(SCHED_PurgeRecords.class.getName()))
		{
			DTO_NameValues parameters = (DTO_NameValues)new DTO_NameValues().deserialize(job.Parameters__c);
			coveredObjects.add(parameters.get(SCHED_PurgeRecords.REQUIRED_PARAMETER_OBJECT_NAME));
		}

		return coveredObjects;
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
	 * @description Checks whether a CSP Trusted Site is configured for the current org domain
	 * by querying CspTrustedSite records.
	 *
	 * @return Health check result for CSP Trusted Site (Fail when missing)
	 */
	private static DTO_HealthCheckResult checkTrustedSite()
	{
		Boolean isConfigured = isTrustedSiteConfigured();
		List<String> formatArgs = new List<String> {Url.getOrgDomainUrl().toExternalForm()};

		DTO_HealthCheckResult result = new DTO_HealthCheckResult();
		result.name = CHECK_TRUSTED_SITE;
		result.status = isConfigured ? STATUS_PASS : STATUS_FAIL;
		result.detail = String.format(isConfigured ? DETAIL_TRUSTED_SITE_CONFIGURED : DETAIL_TRUSTED_SITE_MISSING, formatArgs);
		result.priority = PRIORITY_TRUSTED_SITE;

		return result;
	}

	/**
	 * @description Checks whether a ClassTypeResolver__mdt record is configured and its
	 * referenced resolver class can be resolved at runtime and extends BaseClassResolver.
	 * Each class name resolves through the same Subscriber-First primitive the resolver-chain
	 * bootstrap applies (not through the chain itself, which this check validates), so the
	 * verdict always matches what the chain will actually load.
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
	 * record count when any framework object lacks an active purge job.
	 *
	 * @return Health check result for Data Retention (Pass when all configured, Warn otherwise)
	 */
	private static DTO_HealthCheckResult checkDataRetention()
	{
		DTO_HealthCheckResult result = new DTO_HealthCheckResult();
		result.name = CHECK_DATA_RETENTION;
		result.priority = PRIORITY_DATA_RETENTION;

		List<SObjectType> unconfigured = getUnconfiguredRetentionObjectTypes();

		if(unconfigured.isEmpty())
		{
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
			result.recordCounts.add(new DTO_ObjectRecordCount(objectLabel, (Integer)QRY_Builder.selectFrom(objectType).systemModeInternal().count()));
		}

		result.detail = String.format(DETAIL_DATA_RETENTION_MISSING, new List<String> {String.join(objectLabels, ', ')});
		result.actionLabel = System.Label.HealthCheck_ScheduledJobsActionLabel;
		return result;
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
	 * @description Checks the masking coverage of the subscriber's own custom objects via
	 * CTRL_MaskingAdvisor.summarizeCustomObjectCoverage() — a bounded sweep, so one run never walks an
	 * unbounded object list in orgs with large custom-object counts. Warns naming the objects that hold
	 * likely-sensitive fields with no active masking; passes with the checked count otherwise. Either
	 * way the detail appends how many candidates the bound left unchecked, so a bounded pass is never
	 * mistaken for a full scan. The Review-masking action deep-links into the Data Masking Advisor,
	 * whose on-demand scan covers everything the bounded sweep cannot.
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
	 * @description Reports whether the operator chain-abort capability is usable in this org: the
	 * gating feature flag must be active, the abort custom permission must not be held by profiles
	 * beyond System Administrator, and at least one user must hold the grant set. Existence
	 * probes only — never the running user's own assignment, which would warn for a correctly
	 * configured org whose viewer is simply not a grantee. Ships no action: healthCheck.js routes
	 * every non-masking action to the resolver modal, so a label here would open the wrong dialog.
	 *
	 * @return The check result: Pass when flag active + no broad profile grant + any assignee; Warn otherwise.
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
	 * @description Detects grants of the abort custom permission held by profiles other than System
	 * Administrator — the signature an Install for All Users writes, which silently lets every user in
	 * those profiles abort chains. The System Administrator grant an admins-only install writes is the
	 * expected artifact and never trips this probe. The permission resolves through
	 * SEL_CustomPermission.getCustomPermissionId with this package's namespace, so a subscriber-local
	 * or third-package permission that happens to share the DeveloperName can never trip the warning;
	 * its grants then resolve to their profile-owned permission-set parents. When the System
	 * Administrator profile cannot be resolved by name (standard profile names come back localised for
	 * non-English users), the probe steps aside rather than failing the whole Health Check — the
	 * null-guard precedent in UTIL_FeatureFlag.checkProfile.
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
	 * @description Reports whether a chain watchdog job is scheduled, warning with a one-click
	 * remedy when it is not. A chain the platform silently drops stays Running forever without a
	 * watchdog sweep, so an unscheduled watchdog is the operational gap this check surfaces. Ships
	 * no actionLabel for the same routing reason as the abort check: healthCheck.js renders this
	 * row's dual schedule/customize actions from its own template branch.
	 *
	 * @return The check result: Pass when a watchdog job is scheduled; Warn otherwise.
	 */
	private static DTO_HealthCheckResult checkChainWatchdog()
	{
		DTO_HealthCheckResult result = new DTO_HealthCheckResult();
		result.name = CHECK_CHAIN_WATCHDOG;
		result.priority = PRIORITY_CHAIN_WATCHDOG;

		if(isChainWatchdogScheduled())
		{
			result.status = STATUS_PASS;
			result.detail = System.Label.HealthCheck_ChainWatchdog_Configured;
			return result;
		}

		result.status = STATUS_WARN;
		result.detail = System.Label.HealthCheck_ChainWatchdog_Missing;
		return result;
	}

	/**
	 * @description Decides whether SCHED_ChainWatchdog is scheduled, honouring both scheduling paths
	 * the Async Processing guide documents: an active declarative ScheduledJob__c for the class, or a
	 * live scheduled-Apex platform job (a hand-run System.schedule leaves no ScheduledJob__c record,
	 * and a declarative activation produces the same platform row — the overlap is expected).
	 *
	 * @return True when either path shows the watchdog scheduled
	 */
	private static Boolean isChainWatchdogScheduled()
	{
		String watchdogClassName = SCHED_ChainWatchdog.class.getName();

		if(!new SEL_ScheduledJob().findActiveByClassName(watchdogClassName).isEmpty())
		{
			return true;
		}

		ApexClass watchdogClass = new SEL_ApexClass().findByQualifiedName(watchdogClassName);

		return watchdogClass != null && !new SEL_AsyncApexJob().findLiveScheduledApexByApexClassId(watchdogClass.Id).isEmpty();
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
	 * defaults, in the same shape applyRetentionRecommendations uses. Skips silently when a watchdog
	 * is already scheduled through either path, so a stale button click never creates a duplicate.
	 *
	 * @param cronExpression Cron to schedule with; blank falls back to the recommended hourly default
	 *
	 * @return Id of the created ScheduledJob__c, or null when one was already scheduled
	 */
	@AuraEnabled
	public static Id scheduleChainWatchdog(String cronExpression)
	{
		if(isChainWatchdogScheduled())
		{
			return null;
		}

		DTO_NameValues jobParameters = new DTO_NameValues();
		jobParameters.add(SCHED_ChainWatchdog.PARAMETER_STALE_THRESHOLD_MINUTES, WATCHDOG_DEFAULT_STALE_THRESHOLD_MINUTES);
		jobParameters.add(SCHED_ChainWatchdog.PARAMETER_BATCH_SIZE, WATCHDOG_DEFAULT_BATCH_SIZE);

		List<Id> insertedIds = DML_Builder.newTransaction().withSystemMode().doInsert(new List<ScheduledJob__c>
		{
				new ScheduledJob__c(
						SchedulerName__c = System.Label.HealthCheck_ChainWatchdog_SchedulerName,
						ClassName__c = SCHED_ChainWatchdog.class.getName(),
						CronExpression__c = String.isBlank(cronExpression) ? WATCHDOG_CRON : cronExpression,
						IsActive__c = true,
						Timezone__c = UserInfo.getTimeZone().getID(),
						Parameters__c = jobParameters.serialize()
				)
		}).execute().getInsertedIds();

		return insertedIds.isEmpty() ? null : insertedIds[0];
	}

	/**
	 * @description Queries CspTrustedSite to determine if an active record exists
	 * with an endpoint URL matching the current org domain.
	 *
	 * @return True if a matching trusted site is configured
	 */
	public static Boolean isTrustedSiteConfigured()
	{
		String orgUrl = Url.getOrgDomainUrl().toExternalForm();

		List<CspTrustedSite> trustedSites = QRY_Builder.selectFrom(CspTrustedSite.SObjectType)
				.systemModeInternal()
				.addField(CspTrustedSite.EndpointUrl)
				.condition(CspTrustedSite.IsActive).equals(true)
				.condition(CspTrustedSite.EndpointUrl).equals(orgUrl)
				.bypassSharingInternal()
				.toList();

		return !trustedSites.isEmpty();
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
		 * @description Retention window in days — records older than this are purged.
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
	 * @description Internal specification for a framework-object retention recommendation. Values
	 * are held as Apex constants rather than CMDT because the four framework objects are fixed
	 * internals (subscribers do not extend this list) and a CMDT would add metadata files without
	 * functional benefit.
	 */
	private class RecommendationSpec
	{
		/**
		 * @description Retention window in days — records older than this are purged.
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
		 * @description Constructs a RecommendationSpec with no explicit date field: delegates to the
		 * four-argument constructor with a null dateField, so the recommended purge job ages records
		 * by CreatedDate (the SCHED_PurgeRecords default).
		 *
		 * @param retentionDays Retention window in days
		 * @param cronExpression Default cron expression
		 * @param schedulerName Default scheduler display name
		 */
		public RecommendationSpec(Integer retentionDays, String cronExpression, String schedulerName)
		{
			this(retentionDays, cronExpression, schedulerName, null);
		}

		/**
		 * @description Constructs a RecommendationSpec.
		 *
		 * @param retentionDays Retention window in days
		 * @param cronExpression Default cron expression
		 * @param schedulerName Default scheduler display name
		 * @param dateField Date field the purge job evaluates for record age, or null for the CreatedDate default
		 */
		public RecommendationSpec(Integer retentionDays, String cronExpression, String schedulerName, SObjectField dateField)
		{
			this.retentionDays = retentionDays;
			this.cronExpression = cronExpression;
			this.schedulerName = schedulerName;
			this.dateField = dateField;
		}
	}
}