// SPDX-License-Identifier: BUSL-1.1

/**
 * @description Unit tests for CTRL_HealthCheck.
 *
 * @see CTRL_HealthCheck
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.EagerlyLoadedDescribeSObjectResult,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssTypeCount,PMD.NcssCount')
@IsTest(seeAllData=false isParallel=false)
private class CTRL_HealthCheck_TEST
{
	/**
	 * @description The purge scheduler class name.
	 */
	private static final String PURGE_CLASS = SCHED_PurgeRecords.class.getName();

	/**
	 * @description The parameter key for the object name.
	 */
	private static final String PARAM_OBJECT_NAME = SCHED_PurgeRecords.REQUIRED_PARAMETER_OBJECT_NAME;

	/**
	 * @description The chain watchdog scheduler class name (namespace-qualified where applicable).
	 */
	private static final String WATCHDOG_CLASS = SCHED_ChainWatchdog.class.getName();

	/**
	 * @description The recommended hourly watchdog cron expression the one-click schedule applies.
	 */
	private static final String RECOMMENDED_HOURLY_CRON = '0 0 * * * ?';

	/**
	 * @description The recommended watchdog stale threshold in minutes, serialized as parameter text.
	 */
	private static final String RECOMMENDED_STALE_THRESHOLD_MINUTES = '30';

	/**
	 * @description The recommended watchdog maximum chains per sweep, serialized as parameter text.
	 */
	private static final String RECOMMENDED_BATCH_SIZE = '50';

	/**
	 * @description A deliberately non-default cron proving the chosen cron wins over the hourly default.
	 */
	private static final String CUSTOM_WATCHDOG_CRON = '0 0 3 * * ?';

	/**
	 * @description The AsyncApexJob job type a System.schedule registration creates.
	 */
	private static final String JOB_TYPE_SCHEDULED_APEX = 'ScheduledApex';

	/**
	 * @description A live AsyncApexJob status: a scheduled-Apex registration waits in Queued.
	 */
	private static final String LIVE_SCHEDULED_APEX_STATUS = 'Queued';

	/**
	 * @description The company name identifying the administrator who holds the Kern Job Runner Management permission set.
	 */
	private static final String MANAGING_ADMIN_COMPANY = 'CTRL_HealthCheck_TEST-managing';

	/**
	 * @description The company name identifying the administrator who holds the framework's own Administrator permission
	 * set but no job-runner permission, the shape a subscriber's Kern administrator has.
	 */
	private static final String PLAIN_ADMIN_COMPANY = 'CTRL_HealthCheck_TEST-plain';

	/**
	 * @description The company name identifying the inactive user standing in for an activator whose account was deactivated.
	 */
	private static final String INACTIVE_ACTIVATOR_COMPANY = 'CTRL_HealthCheck_TEST-inactive';

	/**
	 * @description The company name identifying a Standard User with no Kern permission set, so the user holds View All on
	 * none of the framework's objects and owns none of their records.
	 */
	private static final String VIEWER_WITHOUT_VIEW_ALL_COMPANY = 'CTRL_HealthCheck_TEST-viewer';

	/**
	 * @description How many API calls the retention count test saves, all owned by the user running the test.
	 */
	private static final Integer SEEDED_API_CALL_COUNT = 2;

	/**
	 * @description A check interval of fifteen minutes, which costs four of the org's scheduled-job slots.
	 */
	private static final Integer FIFTEEN_MINUTES = 15;

	/**
	 * @description The number of minutes in an hour: the job runner places one record at each check interval inside it.
	 */
	private static final Integer MINUTES_PER_HOUR = 60;

	/**
	 * @description A check interval of thirty minutes, which costs two of the org's scheduled-job slots.
	 */
	private static final Integer THIRTY_MINUTES = 30;

	/**
	 * @description A check interval no choice offers, so both actions refuse it.
	 */
	private static final Integer UNSUPPORTED_CHECK_INTERVAL_MINUTES = 7;

	/**
	 * @description How many runner records a fifteen-minute check interval calls for: one at each quarter of the hour.
	 */
	private static final Integer RECORD_COUNT_AT_FIFTEEN_MINUTES = 4;

	/**
	 * @description How many platform jobs a fifteen-minute runner still has once two of its four are deleted from Setup.
	 */
	private static final Integer SURVIVING_PLATFORM_JOB_COUNT = 2;

	/**
	 * @description How many records a fifteen-minute runner still has once one of its four is deleted from the Scheduled
	 * Jobs list.
	 */
	private static final Integer RECORD_COUNT_AFTER_ONE_IS_DELETED = 3;

	/**
	 * @description How many platform jobs a runner has left once every one of them is deleted from Setup: none at all.
	 */
	private static final Integer NO_PLATFORM_JOBS_LEFT = 0;

	/**
	 * @description The minute marks whose platform job the test stops, standing in for an administrator deleting two of
	 * the four from Setup.
	 */
	private static final Set<Integer> DELETED_PLATFORM_JOB_MINUTE_MARKS = new Set<Integer> {15, 45};

	/**
	 * @description Every minute mark a fifteen-minute check interval fires at.
	 */
	private static final Set<Integer> FIFTEEN_MINUTE_MARKS = new Set<Integer> {0, 15, 30, 45};

	/**
	 * @description The platform's own wording for a delete of a record it has never seen, which the client must be handed.
	 */
	private static final String PLATFORM_DELETE_FAILURE_FRAGMENT = 'Delete failed';

	/**
	 * @description The CronTrigger state of a scheduled job that will still fire.
	 */
	private static final String CRON_TRIGGER_STATE_WAITING = 'WAITING';

	/**
	 * @description A Scheduled Apex row count past the slots warning threshold but short of the failure threshold.
	 */
	private static final Integer SLOTS_IN_USE_AT_WARNING = 85;

	/**
	 * @description A Scheduled Apex row count past the slots failure threshold.
	 */
	private static final Integer SLOTS_IN_USE_AT_FAILURE = 92;

	/**
	 * @description The count the slot breakdown shows for a group of scheduled jobs the org does not have at all.
	 */
	private static final Integer NO_SLOTS_IN_USE = 0;

	/**
	 * @description How many scheduled jobs of the org's own stand beside a four-record job runner when the org has
	 * reached the failing slot count.
	 */
	private static final Integer SLOTS_IN_USE_BY_OTHER_JOBS_AT_FAILURE = SLOTS_IN_USE_AT_FAILURE - RECORD_COUNT_AT_FIFTEEN_MINUTES;

	/**
	 * @description The one job the last check could not start, which the capacity row counts as left waiting.
	 */
	private static final Integer ONE_JOB_LEFT_WAITING = 1;

	/**
	 * @description The label of a ticked API Setting that sorts first by label. It is added second, so the row must sort.
	 */
	private static final String FIRST_TICKED_SETTING_LABEL = 'Alpha Mocked Service';

	/**
	 * @description The label of a ticked API Setting that sorts second by label. It is added first.
	 */
	private static final String SECOND_TICKED_SETTING_LABEL = 'Bravo Mocked Service';

	/**
	 * @description How the selected API mocking row joins the labels of the ticked settings in its detail.
	 */
	private static final String SETTING_LABEL_SEPARATOR = ', ';

	/**
	 * @description The display priority of the selected API mocking row: just after the job-runner capacity row.
	 */
	private static final Integer SELECTED_API_MOCKING_PRIORITY = 53;

	/**
	 * @description The position of the selected API mocking row in the results: the twelfth and last row.
	 */
	private static final Integer SELECTED_API_MOCKING_POSITION = 11;

	/**
	 * @description Users for the job-runner tests: an administrator who holds Kern Job Runner Management, one who holds the
	 * framework's Administrator permission set on a standard profile and so reaches the framework's records without the
	 * job-runner permission, exactly as a subscriber's Kern administrator does, and an inactive user who stands in for an
	 * activator whose account was deactivated.
	 */
	@TestSetup
	private static void setupJobRunnerUsers()
	{
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_SYSTEM_ADMIN, MANAGING_ADMIN_COMPANY,
				UTIL_ScheduledJobRunner.JOB_RUNNER_MANAGEMENT_PERMISSION_SET_NAME);
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, PLAIN_ADMIN_COMPANY,
				SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);
		User inactiveActivator = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER, INACTIVE_ACTIVATOR_COMPANY);
		inactiveActivator.IsActive = false;
		TST_Factory.insertUsers(new List<User> {inactiveActivator});
		TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER, VIEWER_WITHOUT_VIEW_ALL_COMPANY);
	}

	/**
	 * @description Verifies that runHealthChecks returns results for all checks.
	 */
	@IsTest
	private static void shouldReturnAllHealthCheckResults()
	{
		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		Assert.areEqual(12, results.size(), 'Expected twelve health check results');
	}

	/**
	 * @description Verifies that the custom-object coverage check warns when one of the subscriber's own
	 * custom objects holds a natively classified field with no active masking, naming the object and
	 * offering the advisor deep-link action.
	 */
	@IsTest
	private static void customObjectCoverageWarnsOnUncoveredSensitiveObject()
	{
		final String apiCallObjectName = UTIL_SObjectDescribe.getObjectNameFromType(ApiCall__c.SObjectType);
		TST_Mock.register(EntityDefinition.SObjectType, new List<EntityDefinition> {coverageEntity(apiCallObjectName, 'API Call')});
		registerConfidentialFieldOverlay(ApiCall__c.Request__c);
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult coverageResult = results[5];
		Assert.areEqual(System.Label.HealthCheck_CustomObjectCoverage_CheckName, coverageResult.name, 'the sixth check is custom-object coverage');
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, coverageResult.status, 'an uncovered sensitive custom object warns');
		Assert.isTrue(coverageResult.detail.contains(apiCallObjectName), 'the warning names the uncovered object');
		Assert.areEqual(System.Label.HealthCheck_ReviewMasking_ActionLabel, coverageResult.actionLabel, 'the action deep-links to the advisor');
	}

	/**
	 * @description Verifies the warn detail joins several uncovered object names with a comma AND a space,
	 * not a comma alone, so the list reads cleanly. One object is sensitive (a classified field) and the other
	 * carries only a possibly-sensitive field (LogEntry's fingerprint), so the pair also confirms the Health
	 * Check now names possibly-sensitive-only objects, matching the on-demand scan.
	 */
	@IsTest
	private static void customObjectCoverageJoinsMultipleObjectNamesWithCommaAndSpace()
	{
		final String apiCallObjectName = UTIL_SObjectDescribe.getObjectNameFromType(ApiCall__c.SObjectType);
		final String logEntryObjectName = UTIL_SObjectDescribe.getObjectNameFromType(LogEntry__c.SObjectType);
		TST_Mock.register(EntityDefinition.SObjectType, new List<EntityDefinition>
		{
				coverageEntity(apiCallObjectName, 'API Call'),
				coverageEntity(logEntryObjectName, 'Log Entry')
		});
		registerConfidentialFieldOverlay(ApiCall__c.Request__c);
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult coverageResult = results[5];
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, coverageResult.status, 'two uncovered objects warn');
		Boolean joinedWithSpace = coverageResult.detail.contains(apiCallObjectName + ', ' + logEntryObjectName)
				|| coverageResult.detail.contains(logEntryObjectName + ', ' + apiCallObjectName);
		Assert.isTrue(joinedWithSpace, 'multiple uncovered object names are joined with a comma and a space, not jammed together');
	}

	/**
	 * @description Verifies that the custom-object coverage check passes when every assessed custom
	 * object carries active masking, offering no action.
	 */
	@IsTest
	private static void customObjectCoveragePassesWhenObjectsAreCovered()
	{
		final String apiCallObjectName = UTIL_SObjectDescribe.getObjectNameFromType(ApiCall__c.SObjectType);
		TST_Mock.register(EntityDefinition.SObjectType, new List<EntityDefinition> {coverageEntity(apiCallObjectName, 'API Call')});
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt> {maskingTarget('CoverAll', apiCallObjectName, null, true, null)});

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult coverageResult = results[5];
		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, coverageResult.status, 'covered custom objects pass');
		Assert.isNull(coverageResult.actionLabel, 'a passing check offers no action');
	}

	/**
	 * @description Verifies that the warn detail counts the custom objects left unchecked once the
	 * per-run assessment bound is reached, steering the administrator to the console's full scan.
	 */
	@IsTest
	private static void customObjectCoverageCountsUncheckedObjectsInWarnDetail()
	{
		final String apiCallObjectName = UTIL_SObjectDescribe.getObjectNameFromType(ApiCall__c.SObjectType);
		List<EntityDefinition> entities = new List<EntityDefinition> {coverageEntity(apiCallObjectName, 'API Call')};
		for(Integer index = 0; index < CTRL_MaskingAdvisor.MAXIMUM_OBJECTS_ASSESSED_PER_HEALTH_CHECK + 1; index++)
		{
			entities.add(coverageEntity('PlaceholderObject' + index + '__c', 'Placeholder ' + index));
		}
		TST_Mock.register(EntityDefinition.SObjectType, entities);
		registerConfidentialFieldOverlay(ApiCall__c.Request__c);
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt>());

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult coverageResult = results[5];
		String expectedUncheckedSuffix = String.format
				(
						System.Label.HealthCheck_CustomObjectCoverage_Unchecked,
						new List<Object> {CTRL_MaskingAdvisor.MAXIMUM_OBJECTS_ASSESSED_PER_HEALTH_CHECK + 1}
				);
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, coverageResult.status, 'the uncovered sensitive object warns despite the bound');
		Assert.isTrue(coverageResult.detail.contains(expectedUncheckedSuffix), 'the detail counts the objects this pass did not check');
	}

	/**
	 * @description Verifies that a passing check still reports how many custom objects went unchecked,
	 * so a bounded pass is never mistaken for a full scan.
	 */
	@IsTest
	private static void customObjectCoveragePassReportsUncheckedObjects()
	{
		final String apiCallObjectName = UTIL_SObjectDescribe.getObjectNameFromType(ApiCall__c.SObjectType);
		TST_Mock.register(EntityDefinition.SObjectType, new List<EntityDefinition>
		{
				coverageEntity(apiCallObjectName, 'API Call'),
				coverageEntity('UnresolvablePlaceholderOne__c', 'Placeholder One'),
				coverageEntity('UnresolvablePlaceholderTwo__c', 'Placeholder Two')
		});
		TST_Mock.register(MaskingTarget__mdt.SObjectType, new List<MaskingTarget__mdt> {maskingTarget('CoverAll', apiCallObjectName, null, true, null)});

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult coverageResult = results[5];
		String expectedUncheckedSuffix = String.format(System.Label.HealthCheck_CustomObjectCoverage_Unchecked, new List<Object> {2});
		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, coverageResult.status, 'covered objects pass even with unchecked candidates');
		Assert.isTrue(coverageResult.detail.contains(expectedUncheckedSuffix), 'a bounded pass reports what it did not check');
	}

	/**
	 * @description Builds an in-memory EntityDefinition row (no namespace prefix) for the mocked list
	 * of selectable objects that the coverage check reads.
	 *
	 * @param qualifiedApiName The object API name.
	 * @param label The object label.
	 *
	 * @return The in-memory EntityDefinition row.
	 */
	private static EntityDefinition coverageEntity(String qualifiedApiName, String label)
	{
		return (EntityDefinition)TST_Builder.of(EntityDefinition.SObjectType)
				.withOverride(EntityDefinition.QualifiedApiName, qualifiedApiName)
				.withOverride(EntityDefinition.Label, label)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Registers a FieldDefinition classification-overlay mock marking the given field
	 * Confidential, driving the coverage check's sensitivity signal through the native-classification
	 * path. The overlay name derives from the field token so it matches in any namespace context.
	 *
	 * @param field The field token the overlay classifies.
	 */
	private static void registerConfidentialFieldOverlay(SObjectField field)
	{
		TST_Mock.register(FieldDefinition.SObjectType, TST_Builder.of(FieldDefinition.SObjectType)
				.withOverride(FieldDefinition.QualifiedApiName, UTIL_SObjectDescribe.getCachedFieldName(field))
				.withOverride(FieldDefinition.SecurityClassification, 'Confidential')
				.withoutInsertion()
				.build());
	}

	/**
	 * @description Verifies that the Organisation Cache check returns a valid result.
	 */
	@IsTest
	private static void shouldCheckOrgCacheAvailability()
	{
		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult orgCacheResult = results[0];
		Assert.areEqual(CTRL_HealthCheck.CHECK_ORG_CACHE, orgCacheResult.name, 'First result should be Organisation Cache');
		Assert.isTrue
				(
						orgCacheResult.status == CTRL_HealthCheck.STATUS_PASS || orgCacheResult.status == CTRL_HealthCheck.STATUS_FAIL,
						'Organisation Cache status should be Pass or Fail'
				);
		Assert.isNotNull(orgCacheResult.detail, 'Detail should not be null');
		Assert.areEqual(10, orgCacheResult.priority, 'Organisation Cache should have priority 10');
	}

	/**
	 * @description Verifies that the Session Cache check returns a valid result.
	 */
	@IsTest
	private static void shouldCheckSessionCacheAvailability()
	{
		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult sessionCacheResult = results[1];
		Assert.areEqual(CTRL_HealthCheck.CHECK_SESSION_CACHE, sessionCacheResult.name, 'Second result should be Session Cache');
		Assert.isTrue
				(
						sessionCacheResult.status == CTRL_HealthCheck.STATUS_PASS || sessionCacheResult.status == CTRL_HealthCheck.STATUS_WARN,
						'Session Cache status should be Pass or Warn'
				);
		Assert.isNotNull(sessionCacheResult.detail, 'Detail should not be null');
		Assert.areEqual(20, sessionCacheResult.priority, 'Session Cache should have priority 20');
	}

	/**
	 * @description Verifies that cache checks report unavailable when partition is null.
	 */
	@IsTest
	private static void shouldReportUnavailableWhenPartitionNull()
	{
		UTIL_Cache.simulateNullPartition = true;

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult orgCacheResult = results[0];
		Assert.areEqual(CTRL_HealthCheck.STATUS_FAIL, orgCacheResult.status, 'Organisation Cache should fail when partition unavailable');
		Assert.areEqual(CTRL_HealthCheck.DETAIL_ORG_CACHE_NOT_ALLOCATED, orgCacheResult.detail, 'Should show Organisation Cache failure detail');
		Assert.areEqual(10, orgCacheResult.priority, 'Organisation Cache should have priority 10 even when failing');

		CTRL_HealthCheck.DTO_HealthCheckResult sessionCacheResult = results[1];
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, sessionCacheResult.status, 'Session Cache should warn when partition unavailable');
		Assert.areEqual(CTRL_HealthCheck.DETAIL_SESSION_CACHE_NOT_ALLOCATED, sessionCacheResult.detail, 'Should show Session Cache warning detail');
		Assert.areEqual(20, sessionCacheResult.priority, 'Session Cache should have priority 20 even when warning');
	}

	/**
	 * @description Verifies that the Class Type Resolver check warns when no ClassTypeResolver__mdt records exist.
	 */
	@IsTest
	private static void shouldWarnWhenNoClassTypeResolverRecordsExist()
	{
		TST_Mock.register(ClassTypeResolver__mdt.SObjectType, new List<ClassTypeResolver__mdt>());

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult resolverResult = results[2];
		Assert.areEqual(CTRL_HealthCheck.CHECK_CLASS_TYPE_RESOLVER, resolverResult.name, 'Third result should be Class Type Resolver');
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, resolverResult.status, 'Should warn when no resolver records exist');
		Assert.areEqual(CTRL_HealthCheck.DETAIL_CLASS_TYPE_RESOLVER_MISSING, resolverResult.detail, 'Should show missing resolver detail');
		Assert.areEqual('Setup', resolverResult.actionLabel, 'Should show Setup action when no resolver records exist');
		Assert.areEqual(40, resolverResult.priority, 'Class Type Resolver should have priority 40');
	}

	/**
	 * @description Verifies that the Class Type Resolver check warns when records exist but the referenced class cannot be resolved.
	 */
	@IsTest
	private static void shouldWarnWhenClassTypeResolverClassNotResolvable()
	{
		TST_Mock.of(ClassTypeResolver__mdt.SObjectType)
				.withOverride(ClassTypeResolver__mdt.ClassName__c, 'NonExistentClassName').build();

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult resolverResult = results[2];
		Assert.areEqual(CTRL_HealthCheck.CHECK_CLASS_TYPE_RESOLVER, resolverResult.name, 'Third result should be Class Type Resolver');
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, resolverResult.status, 'Should warn when resolver class is not resolvable');
		Assert.areEqual(CTRL_HealthCheck.DETAIL_CLASS_TYPE_RESOLVER_CLASS_NOT_FOUND, resolverResult.detail, 'Should show class not found detail');
		Assert.areEqual('Setup', resolverResult.actionLabel, 'Should show Setup action when resolver class is not resolvable');
		Assert.areEqual(40, resolverResult.priority, 'Class Type Resolver should have priority 40 when unresolvable');
	}

	/**
	 * @description Verifies that the Class Type Resolver check warns when the referenced class exists but does not extend BaseClassResolver.
	 */
	@IsTest
	private static void shouldWarnWhenClassTypeResolverClassDoesNotExtendBase()
	{
		TST_Mock.of(ClassTypeResolver__mdt.SObjectType)
				.withOverride(ClassTypeResolver__mdt.ClassName__c, CTRL_HealthCheck.class.getName()).build();

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult resolverResult = results[2];
		Assert.areEqual(CTRL_HealthCheck.CHECK_CLASS_TYPE_RESOLVER, resolverResult.name, 'Third result should be Class Type Resolver');
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, resolverResult.status, 'Should warn when resolver class does not extend BaseClassResolver');
		Assert.areEqual(CTRL_HealthCheck.DETAIL_CLASS_TYPE_RESOLVER_INVALID_TYPE, resolverResult.detail, 'Should show invalid type detail');
		Assert.areEqual('Setup', resolverResult.actionLabel, 'Should show Setup action when resolver class is invalid type');
		Assert.areEqual(40, resolverResult.priority, 'Class Type Resolver should have priority 40 when invalid type');
	}

	/**
	 * @description Verifies that the Class Type Resolver check passes when a record exists with a valid resolver class.
	 */
	@IsTest
	private static void shouldPassWhenClassTypeResolverClassExists()
	{
		TST_Mock.of(ClassTypeResolver__mdt.SObjectType)
				.withOverride(ClassTypeResolver__mdt.ClassName__c, UTIL_TypeResolver.PackageClassResolver.class.getName()).build();

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult resolverResult = results[2];
		Assert.areEqual(CTRL_HealthCheck.CHECK_CLASS_TYPE_RESOLVER, resolverResult.name, 'Third result should be Class Type Resolver');
		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, resolverResult.status, 'Should pass when resolver class exists');
		Assert.areEqual(CTRL_HealthCheck.DETAIL_CLASS_TYPE_RESOLVER_CONFIGURED, resolverResult.detail, 'Should show configured detail');
		Assert.isNull(resolverResult.actionLabel, 'Should not show action when resolver class exists');
		Assert.areEqual(40, resolverResult.priority, 'Class Type Resolver should have priority 40 when passing');
	}

	/**
	 * @description Verifies that the Data Retention check passes when active purge jobs cover all framework objects.
	 */
	@IsTest
	private static void shouldPassWhenRetentionJobsConfiguredForAllObjects()
	{
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>
		{
				newPurgeJob(LogEntry__c.SObjectType),
				newPurgeJob(ApiCall__c.SObjectType),
				newPurgeJob(ApiIssue__c.SObjectType),
				newPurgeJob(AsyncChainExecution__c.SObjectType)
		});

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = results[3];
		Assert.areEqual(CTRL_HealthCheck.CHECK_DATA_RETENTION, retentionResult.name, 'Fourth result should be Data Retention');
		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, retentionResult.status, 'Should pass when all retention jobs configured');
		Assert.areEqual(CTRL_HealthCheck.DETAIL_DATA_RETENTION_CONFIGURED, retentionResult.detail, 'Should show configured detail');
		Assert.isNull(retentionResult.recordCounts, 'Should not include record counts when all configured');
		Assert.areEqual(50, retentionResult.priority, 'Data Retention should have priority 50 when passing');
	}

	/**
	 * @description Verifies that the Data Retention check warns when no retention jobs exist.
	 */
	@IsTest
	private static void shouldWarnWhenNoRetentionJobsConfigured()
	{
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>());

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = results[3];
		Assert.areEqual(CTRL_HealthCheck.CHECK_DATA_RETENTION, retentionResult.name, 'Fourth result should be Data Retention');
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, retentionResult.status, 'Should warn when no retention jobs exist');
		Assert.isTrue(retentionResult.detail.contains(LogEntry__c.SObjectType.getDescribe().getLabel()), 'Detail should list Log Entry');
		Assert.isTrue(retentionResult.detail.contains(ApiCall__c.SObjectType.getDescribe().getLabel()), 'Detail should list API Call');
		Assert.isTrue(retentionResult.detail.contains(ApiIssue__c.SObjectType.getDescribe().getLabel()), 'Detail should list API Issue');
		Assert.isTrue(retentionResult.detail.contains(AsyncChainExecution__c.SObjectType.getDescribe().getLabel()), 'Detail should list Async Chain Execution');
		Assert.isNotNull(retentionResult.recordCounts, 'Should include record counts');
		Assert.areEqual(4, retentionResult.recordCounts.size(), 'Should include counts for all four objects');
		Assert.areEqual(50, retentionResult.priority, 'Data Retention should have priority 50 when warning');
	}

	/**
	 * @description The Data Retention check counts every record of an object, not only the ones the viewer may see. API
	 * calls are Private. Here the user running the test owns two of them, and a Standard User without View All opens the
	 * Health Check page. The count still says two.
	 */
	@IsTest
	private static void shouldCountEveryRecordForAViewerWithoutViewAll()
	{
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>());
		TST_Builder.of(ApiCall__c.SObjectType).withCount(SEEDED_API_CALL_COUNT).buildList();
		String apiCallLabel = UTIL_SObjectDescribe.getDescribe(ApiCall__c.SObjectType).getDescribe().getLabel();
		List<CTRL_HealthCheck.DTO_HealthCheckResult> results;

		System.runAs(new SEL_User().findByCompanyName(VIEWER_WITHOUT_VIEW_ALL_COMPANY))
		{
			results = new SharingEnforcedCaller().runHealthChecks();
		}

		Integer apiCallCount;
		for(CTRL_HealthCheck.DTO_ObjectRecordCount objectCount : resultNamed(results, CTRL_HealthCheck.CHECK_DATA_RETENTION).recordCounts)
		{
			if(objectCount.objectName == apiCallLabel)
			{
				apiCallCount = objectCount.recordCount;
			}
		}
		Assert.areEqual(SEEDED_API_CALL_COUNT, apiCallCount, 'Expected the count to include the API calls the viewer cannot see');
	}

	/**
	 * @description Verifies that the Data Retention check warns for only unconfigured objects when partial coverage exists.
	 */
	@IsTest
	private static void shouldWarnForOnlyUnconfiguredObjects()
	{
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>
		{
				newPurgeJob(LogEntry__c.SObjectType)
		});

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = results[3];
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, retentionResult.status, 'Should warn for unconfigured objects');
		Assert.isFalse(retentionResult.detail.contains(LogEntry__c.SObjectType.getDescribe().getLabel()), 'Should not list Log Entry which has a purge job');
		Assert.isTrue(retentionResult.detail.contains(ApiCall__c.SObjectType.getDescribe().getLabel()), 'Should list unconfigured API Call');
		Assert.areEqual(3, retentionResult.recordCounts.size(), 'Should include counts for three unconfigured objects');
		Assert.areEqual(50, retentionResult.priority, 'Data Retention should have priority 50 when partially configured');
	}

	/**
	 * @description When API calls or API issues have no purge job, the Data Retention warning also says who must schedule
	 * it: a user the BypassApiRecordDeleteGuard feature flag is on for, because only that user's purge deletes them. A
	 * built-in rule turns the flag on for holders of the Delete API Records permission, which the Kern Administrator
	 * permission set carries.
	 */
	@IsTest
	private static void shouldSayWhoMustScheduleTheApiRecordPurge()
	{
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>());

		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = resultNamed(CTRL_HealthCheck.runHealthChecks(), CTRL_HealthCheck.CHECK_DATA_RETENTION);

		Assert.isTrue(retentionResult.detail.contains(System.Label.HealthCheck_DataRetention_ApiPurgeNeedsUserWhoCanDelete),
				'Expected the warning to say who must schedule the purge, got ' + retentionResult.detail);
	}

	/**
	 * @description Your org deactivated the BypassApiRecordDeleteGuard feature flag, so nobody can delete API calls or API
	 * issues. API calls and API issues have no purge job yet. The Data Retention warning says the flag is deactivated
	 * instead of telling you who must schedule the purge, because no user's purge would delete anything.
	 */
	@IsTest
	private static void shouldSayTheDeleteFlagIsDeactivatedWhenTheApiRecordPurgeIsMissing()
	{
		SEL_FeatureFlag.activeFlags.remove(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD);
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>());

		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = resultNamed(CTRL_HealthCheck.runHealthChecks(), CTRL_HealthCheck.CHECK_DATA_RETENTION);

		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, retentionResult.status, 'Expected a warning for the missing purge jobs');
		Assert.isTrue(retentionResult.detail.contains(System.Label.HealthCheck_DataRetention_ApiRecordDeleteFlagInactive),
				'Expected the warning to say the flag is deactivated, got ' + retentionResult.detail);
		Assert.isFalse(retentionResult.detail.contains(System.Label.HealthCheck_DataRetention_ApiPurgeNeedsUserWhoCanDelete),
				'Expected no advice on who must schedule the purge, got ' + retentionResult.detail);
	}

	/**
	 * @description Every framework object has a purge job, but your org deactivated the BypassApiRecordDeleteGuard
	 * feature flag. Then nobody can delete API calls or API issues, an administrator included, and every purge of them
	 * deletes nothing. The check warns with the message that says so.
	 */
	@IsTest
	private static void shouldWarnThatNobodyCanDeleteApiRecordsWhenTheDeleteFlagIsDeactivated()
	{
		SEL_FeatureFlag.activeFlags.remove(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD);
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>
		{
				newPurgeJob(LogEntry__c.SObjectType),
				newPurgeJob(ApiCall__c.SObjectType),
				newPurgeJob(ApiIssue__c.SObjectType),
				newPurgeJob(AsyncChainExecution__c.SObjectType)
		});

		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = resultNamed(CTRL_HealthCheck.runHealthChecks(), CTRL_HealthCheck.CHECK_DATA_RETENTION);

		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, retentionResult.status, 'Expected a warning for the deactivated flag');
		Assert.areEqual(System.Label.HealthCheck_DataRetention_ApiRecordDeleteFlagInactive, retentionResult.detail, 'Expected the detail to say the flag is deactivated');
		Assert.isNull(retentionResult.actionLabel, 'Expected no scheduled jobs action, because a new purge job would not fix a deactivated flag');
	}

	/**
	 * @description Every framework object has a purge job, and the API issue purge runs on its own scheduled job, which
	 * belongs to a Standard User without the Delete API Records permission. Your org turned the BypassApiRecordDeleteGuard
	 * feature flag on for every user, so that user's purge deletes, and the check passes.
	 */
	@IsTest
	private static void shouldPassWhenTheApiIssuePurgeRunsAsAUserTheDeleteFlagIsOnFor()
	{
		TST_Factory.newFeatureFlag(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD);

		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = runRetentionCheckWithApiIssuePurgeOwnedBy(VIEWER_WITHOUT_VIEW_ALL_COMPANY);

		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, retentionResult.status, 'Expected the check to pass when the flag is on for the purge user');
		Assert.areEqual(CTRL_HealthCheck.DETAIL_DATA_RETENTION_CONFIGURED, retentionResult.detail, 'Expected the configured detail');
	}

	/**
	 * @description Every framework object has a purge job, but the API issue purge runs on its own scheduled job, which
	 * belongs to a Standard User without the Delete API Records permission. The flag is as the package ships it, so it is
	 * off for that user, and that purge would delete nothing. The check warns and names API Issue instead of reporting
	 * every purge as set up.
	 */
	@IsTest
	private static void shouldWarnWhenTheApiIssuePurgeRunsAsAUserWhoCannotDelete()
	{
		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = runRetentionCheckWithApiIssuePurgeOwnedBy(VIEWER_WITHOUT_VIEW_ALL_COMPANY);

		String expectedDetail = String.format(System.Label.HealthCheck_DataRetention_ApiPurgeCannotDelete,
				new List<String> {UTIL_SObjectDescribe.getDescribe(ApiIssue__c.SObjectType).getDescribe().getLabel()});
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, retentionResult.status, 'Expected a warning for a purge that cannot delete');
		Assert.areEqual(expectedDetail, retentionResult.detail, 'Expected the warning to name the purge and who must reschedule it');
	}

	/**
	 * @description The same setup, but the API issue purge's scheduled job belongs to a user who holds the Kern Administrator
	 * permission set, which grants Delete API Records. The flag's built-in rule turns the flag on for that user, so every
	 * purge can delete and the check passes.
	 */
	@IsTest
	private static void shouldPassWhenTheApiIssuePurgeRunsAsAUserWhoCanDelete()
	{
		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = runRetentionCheckWithApiIssuePurgeOwnedBy(PLAIN_ADMIN_COMPANY);

		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, retentionResult.status, 'Expected the check to pass when the purge can delete');
		Assert.areEqual(CTRL_HealthCheck.DETAIL_DATA_RETENTION_CONFIGURED, retentionResult.detail, 'Expected the configured detail');
	}

	/**
	 * @description Every framework object has a purge job, and the API issue purge runs on the job runner. A job on the
	 * runner runs as the user who turned the runner on, here a Standard User without the Delete API Records permission.
	 * The flag is as the package ships it, so it is off for that user, and that purge would delete nothing. The purge has
	 * no scheduled job of its own, so only the runner's user can tell the check who it runs as. The check warns and names
	 * API Issue.
	 */
	@IsTest
	private static void shouldWarnWhenTheApiIssuePurgeRunsOnAJobRunnerTurnedOnByAUserWhoCannotDelete()
	{
		seedRunnerRecords(new List<Integer> {0, 15, 30, 45}, new SEL_User().findByCompanyName(VIEWER_WITHOUT_VIEW_ALL_COMPANY).Id, CRON_TRIGGER_STATE_WAITING);
		seedActivePurgeJob(LogEntry__c.SObjectType, UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB);
		seedActivePurgeJob(ApiCall__c.SObjectType, UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB);
		seedActivePurgeJob(ApiIssue__c.SObjectType, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER);
		seedActivePurgeJob(AsyncChainExecution__c.SObjectType, UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB);

		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = resultNamed(CTRL_HealthCheck.runHealthChecks(), CTRL_HealthCheck.CHECK_DATA_RETENTION);

		String expectedDetail = String.format(System.Label.HealthCheck_DataRetention_ApiPurgeCannotDelete,
				new List<String> {UTIL_SObjectDescribe.getDescribe(ApiIssue__c.SObjectType).getDescribe().getLabel()});
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, retentionResult.status, 'Expected a warning for a purge on the runner that cannot delete');
		Assert.areEqual(expectedDetail, retentionResult.detail, 'Expected the warning to name the API issue purge');
	}

	/**
	 * @description A purge job may name its object in any letter case, because the purge finds the object whatever the
	 * case. Every framework object has a purge job whose object name is typed in lower case, so the check counts each one
	 * as set up and passes. It does not report the four objects as having no purge.
	 */
	@IsTest
	private static void shouldCountAPurgeJobWhoseObjectNameIsInLowerCase()
	{
		List<ScheduledJob__c> purgeJobs = new List<ScheduledJob__c>();
		for(SObjectType objectType : new List<SObjectType> {LogEntry__c.SObjectType, ApiCall__c.SObjectType, ApiIssue__c.SObjectType, AsyncChainExecution__c.SObjectType})
		{
			String lowerCaseObjectName = UTIL_SObjectDescribe.getObjectNameFromType(objectType).toLowerCase();
			purgeJobs.add(TST_Factory.newScheduledJob(PURGE_CLASS, new DTO_NameValues(new Map<String, String> {PARAM_OBJECT_NAME => lowerCaseObjectName})));
		}
		TST_Mock.register(ScheduledJob__c.SObjectType, purgeJobs);

		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = resultNamed(CTRL_HealthCheck.runHealthChecks(), CTRL_HealthCheck.CHECK_DATA_RETENTION);

		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, retentionResult.status, 'Expected the purge jobs named in lower case to count, got ' + retentionResult.detail);
		Assert.areEqual(CTRL_HealthCheck.DETAIL_DATA_RETENTION_CONFIGURED, retentionResult.detail, 'Expected the configured detail');
	}

	/**
	 * @description A purge of API issues runs as a user who cannot delete them, and its job names the object in lower
	 * case. The check still finds that purge and warns, naming API Issue.
	 */
	@IsTest
	private static void shouldWarnWhenALowerCaseApiIssuePurgeRunsAsAUserWhoCannotDelete()
	{
		CronTrigger purgeTrigger = (CronTrigger)TST_Builder.of(CronTrigger.SObjectType)
				.withOverride(CronTrigger.OwnerId, new SEL_User().findByCompanyName(VIEWER_WITHOUT_VIEW_ALL_COMPANY).Id)
				.withoutInsertion(true)
				.build();
		String lowerCaseObjectName = UTIL_SObjectDescribe.getObjectNameFromType(ApiIssue__c.SObjectType).toLowerCase();
		ScheduledJob__c apiIssuePurge = TST_Factory.newScheduledJob(PURGE_CLASS, new DTO_NameValues(new Map<String, String> {PARAM_OBJECT_NAME => lowerCaseObjectName}));
		apiIssuePurge.ExecutionMode__c = UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB;
		apiIssuePurge.ScheduledJobId__c = purgeTrigger.Id;
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>
		{
				newPurgeJob(LogEntry__c.SObjectType),
				newPurgeJob(ApiCall__c.SObjectType),
				apiIssuePurge,
				newPurgeJob(AsyncChainExecution__c.SObjectType)
		});
		TST_Mock.register(CronTrigger.SObjectType, new List<CronTrigger> {purgeTrigger});

		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = resultNamed(CTRL_HealthCheck.runHealthChecks(), CTRL_HealthCheck.CHECK_DATA_RETENTION);

		String expectedDetail = String.format(System.Label.HealthCheck_DataRetention_ApiPurgeCannotDelete,
				new List<String> {UTIL_SObjectDescribe.getDescribe(ApiIssue__c.SObjectType).getDescribe().getLabel()});
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, retentionResult.status, 'Expected a warning for a purge that cannot delete');
		Assert.areEqual(expectedDetail, retentionResult.detail, 'Expected the warning to name the API issue purge');
	}

	/**
	 * @description Saves one active purge job for the given object, in the given mode, with the trigger bypassed so the
	 * record lands without scheduling anything for real. The job has no scheduled job of its own.
	 *
	 * @param objectType The object the job purges.
	 * @param executionMode How the job runs: on the job runner or on a scheduled job of its own.
	 */
	private static void seedActivePurgeJob(SObjectType objectType, String executionMode)
	{
		seedActivePurgeJob(objectType, executionMode, new Map<SObjectField, Object> {ScheduledJob__c.CronExpression__c => RECOMMENDED_HOURLY_CRON});
	}

	/**
	 * @description Saves one active purge job for the given object, in the given mode, with the given extra field values,
	 * and with the trigger bypassed so the record lands without scheduling anything for real. Every purge job a test of
	 * this class seeds is saved here.
	 *
	 * @param objectType The object the job purges.
	 * @param executionMode How the job runs: on the job runner or on a scheduled job of its own.
	 * @param extraValues The other field values the job is saved with, such as its schedule and its next run.
	 */
	private static void seedActivePurgeJob(SObjectType objectType, String executionMode, Map<SObjectField, Object> extraValues)
	{
		DTO_NameValues parameters = new DTO_NameValues(new Map<String, String> {PARAM_OBJECT_NAME => UTIL_SObjectDescribe.getObjectNameFromType(objectType)});
		TRG_Base.bypass(ScheduledJob__c.SObjectType);
		TST_Builder.of(ScheduledJob__c.SObjectType)
				.withOverrides(extraValues)
				.withOverride(ScheduledJob__c.ClassName__c, PURGE_CLASS)
				.withOverride(ScheduledJob__c.IsActive__c, true)
				.withOverride(ScheduledJob__c.ExecutionMode__c, executionMode)
				.withOverride(ScheduledJob__c.Parameters__c, parameters.serialize())
				.build();
		TRG_Base.clearBypass(ScheduledJob__c.SObjectType);
	}

	/**
	 * @description Runs the Data Retention check with a purge job for every framework object. The API issue purge runs on
	 * its own scheduled job, owned by the user with the given company name; the job runs as that user.
	 *
	 * @param ownerCompany The company name of the user who owns the API issue purge's scheduled job.
	 *
	 * @return The Data Retention result.
	 */
	private static CTRL_HealthCheck.DTO_HealthCheckResult runRetentionCheckWithApiIssuePurgeOwnedBy(String ownerCompany)
	{
		CronTrigger purgeTrigger = (CronTrigger)TST_Builder.of(CronTrigger.SObjectType)
				.withOverride(CronTrigger.OwnerId, new SEL_User().findByCompanyName(ownerCompany).Id)
				.withoutInsertion(true)
				.build();
		ScheduledJob__c apiIssuePurge = newPurgeJob(ApiIssue__c.SObjectType);
		apiIssuePurge.ExecutionMode__c = UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB;
		apiIssuePurge.ScheduledJobId__c = purgeTrigger.Id;
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>
		{
				newPurgeJob(LogEntry__c.SObjectType),
				newPurgeJob(ApiCall__c.SObjectType),
				apiIssuePurge,
				newPurgeJob(AsyncChainExecution__c.SObjectType)
		});
		TST_Mock.register(CronTrigger.SObjectType, new List<CronTrigger> {purgeTrigger});

		return resultNamed(CTRL_HealthCheck.runHealthChecks(), CTRL_HealthCheck.CHECK_DATA_RETENTION);
	}

	/**
	 * @description Verifies that jobs for non-purge classes are ignored in the retention check.
	 */
	@IsTest
	private static void shouldIgnoreNonPurgeScheduledJobs()
	{
		DTO_NameValues parameters = new DTO_NameValues(new Map<String, String> {PARAM_OBJECT_NAME => LogEntry__c.SObjectType.getDescribe().name});
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>
		{
				TST_Factory.newScheduledJob('SCHED_ProcessLoginHistory', parameters)
		});

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = results[3];
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, retentionResult.status, 'Should warn when no purge jobs exist despite other active jobs');
	}

	/**
	 * @description Verifies the Data Masking check warns when an active masking target masks nothing
	 * (its rule is inactive or missing) so the admin is pointed at the advisor to fix or remove it.
	 */
	@IsTest
	private static void shouldWarnWhenMaskingHasDeadConfigurations()
	{
		MaskingRule__mdt activeRule = maskingRule(true);
		MaskingRule__mdt inactiveRule = maskingRule(false);
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>
		{
				'ActiveRule' => activeRule,
				'InactiveRule' => inactiveRule
		};
		SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt>
		{
				'LiveTarget' => maskingTarget('LiveTarget', 'ObjectADurable', null, true, activeRule.Id),
				'DeadTarget' => maskingTarget('DeadTarget', 'ObjectADurable', 'ObjectADurable.FieldOne', true, inactiveRule.Id)
		};

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult maskingResult = results[4];
		Assert.areEqual(CTRL_HealthCheck.CHECK_MASKING_POSTURE, maskingResult.name, 'Fifth result should be Data Masking');
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, maskingResult.status, 'Should warn when an active target masks nothing');
		Assert.areEqual(String.format(CTRL_HealthCheck.DETAIL_MASKING_POSTURE_DEAD, new List<Object> {1}), maskingResult.detail, 'Detail should report the one dead target');
		Assert.isNotNull(maskingResult.actionLabel, 'A masking warning should offer the Review-masking action');
		Assert.areEqual(45, maskingResult.priority, 'Data Masking should have priority 45');
	}

	/**
	 * @description Verifies the Data Masking check warns when the org carries no active masking at all,
	 * pointing the admin at the advisor to review their objects.
	 */
	@IsTest
	private static void shouldWarnWhenNoActiveMaskingExists()
	{
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>();
		SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt>();

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult maskingResult = results[4];
		Assert.areEqual(CTRL_HealthCheck.CHECK_MASKING_POSTURE, maskingResult.name, 'Fifth result should be Data Masking');
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, maskingResult.status, 'Should warn when nothing is masked');
		Assert.areEqual(CTRL_HealthCheck.DETAIL_MASKING_POSTURE_NONE_ACTIVE, maskingResult.detail, 'Detail should report that almost nothing is masked yet');
		Assert.isNotNull(maskingResult.actionLabel, 'A masking warning should offer the Review-masking action');
		Assert.areEqual(45, maskingResult.priority, 'Data Masking should have priority 45');
	}

	/**
	 * @description Verifies the Data Masking check passes when masking is active and healthy (objects carry
	 * active targets and no active target is dead), reporting the count of masked objects with no action.
	 */
	@IsTest
	private static void shouldPassWhenMaskingIsActiveAndHealthy()
	{
		MaskingRule__mdt activeRule = maskingRule(true);
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {'ActiveRule' => activeRule};
		SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt>
		{
				'LiveTarget' => maskingTarget('LiveTarget', 'ObjectADurable', 'ObjectADurable.FieldOne', true, activeRule.Id)
		};

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult maskingResult = results[4];
		Assert.areEqual(CTRL_HealthCheck.CHECK_MASKING_POSTURE, maskingResult.name, 'Fifth result should be Data Masking');
		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, maskingResult.status, 'Should pass when masking is active and healthy');
		Assert.areEqual(String.format(CTRL_HealthCheck.DETAIL_MASKING_POSTURE_HEALTHY, new List<Object> {1}), maskingResult.detail, 'Detail should report the one masked object');
		Assert.isNull(maskingResult.actionLabel, 'A passing masking result should carry no action');
		Assert.areEqual(45, maskingResult.priority, 'Data Masking should have priority 45');
	}

	/**
	 * @description Verifies the chain-abort check warns when the gating flag is active but nobody holds the
	 * grant set. Seeds an empty PermissionSetAssignment mock so the probe never reads the org's ambient
	 * assignments (a live smoke may have granted the dev user), and an empty SetupEntityAccess mock so
	 * install-written profile grants, visible regardless of test-data isolation, cannot divert the check
	 * to the broad-grant warning.
	 */
	@IsTest
	private static void shouldWarnWhenAbortHasNoAssignees()
	{
		TST_Mock.register(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment>());
		TST_Mock.register(SetupEntityAccess.SObjectType, new List<SetupEntityAccess>());

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();
		CTRL_HealthCheck.DTO_HealthCheckResult abortResult = results[6];

		Assert.areEqual(System.Label.HealthCheck_AsyncChainAbort_CheckName, abortResult.name, 'the seventh check is the chain abort capability');
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, abortResult.status, 'No assignee means the shipped-off capability is still undiscovered');
		Assert.areEqual(System.Label.HealthCheck_AsyncChainAbort_NoAssignees, abortResult.detail, 'The detail names the missing assignment');
		Assert.isNull(abortResult.actionLabel, 'The check has no action: healthCheck.js would open the wrong dialog for it');
	}

	/**
	 * @description Verifies the chain-abort check passes when the gating flag is active and at least one
	 * user holds the grant set. Seeds a single mocked assignment so the pass is proven without any real
	 * User DML, so the pass depends on the mock alone, and without depending on ambient org data, plus
	 * an empty SetupEntityAccess mock so install-written profile grants cannot flip the pass to the
	 * broad-grant warning in subscriber orgs.
	 */
	@IsTest
	private static void shouldPassAbortCheckWhenConfigured()
	{
		TST_Mock.register(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment> {abortAssignment()});
		TST_Mock.register(SetupEntityAccess.SObjectType, new List<SetupEntityAccess>());

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, results[6].status, 'Flag active + an assignee = configured');
		Assert.areEqual(System.Label.HealthCheck_AsyncChainAbort_Configured, results[6].detail, 'The pass detail confirms the capability is usable');
	}

	/**
	 * @description Verifies the chain-abort check warns when the gating feature flag is deactivated, short-
	 * circuiting before the permission-set probe so no assignment seeding is needed.
	 */
	@IsTest
	private static void shouldWarnWhenAbortFlagInactive()
	{
		SEL_FeatureFlag.activeFlags.remove(UTIL_AsyncChain.ABORT_FEATURE_FLAG_NAME);

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, results[6].status, 'A deactivated flag is worth surfacing');
		Assert.areEqual(System.Label.HealthCheck_AsyncChainAbort_FlagInactive, results[6].detail, 'The detail names the deactivated flag');
	}

	/**
	 * @description Verifies the chain-abort check warns when a profile other than System Administrator
	 * holds the abort custom permission, the shape an Install for All Users writes into every profile.
	 * Seeds the grant chain through mocks (a Standard User profile parent) alongside an empty assignment
	 * mock, proving the broad-grant warning outranks the no-assignee warning.
	 */
	@IsTest
	private static void shouldWarnWhenAbortPermissionHeldByNonAdministratorProfile()
	{
		mockProfileOwnedAbortGrant(SEL_Profile.PROFILE_STANDARD_USER);
		TST_Mock.register(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment>());

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();
		CTRL_HealthCheck.DTO_HealthCheckResult abortResult = results[6];

		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, abortResult.status, 'A profile-held grant beyond System Administrator silently broadens who can abort');
		Assert.areEqual(System.Label.HealthCheck_AsyncChainAbort_BroadlyGranted, abortResult.detail, 'The detail names the broad grant and its install-mode cause');
	}

	/**
	 * @description Verifies that the abort-grant probe, a framework-internal read of setup entities that
	 * structurally needs org-wide visibility, emits no sharing BYPASS audit entry. The probe routes through
	 * `bypassSharingInternal()`, which must stay silent so a health-check run does not pollute the
	 * `BypassEvent` forensic trail.
	 *
	 * @see CTRL_HealthCheck.hasNonAdministratorProfileAbortGrant
	 * @see QRY_Builder.Builder.bypassSharingInternal
	 */
	@IsTest
	private static void shouldNotEmitBypassAuditWhenProbingAbortGrants()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		mockProfileOwnedAbortGrant(SEL_Profile.PROFILE_STANDARD_USER);
		TST_Mock.register(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment>());

		Test.startTest();
		CTRL_HealthCheck.runHealthChecks();
		Test.stopTest();

		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			String target = (String)(context?.get(UTIL_BypassAudit.CONTEXT_TARGET));
			Assert.isFalse
					(
							target != null && target.startsWith('sharing'),
							'The abort-grant probe must not emit a sharing BYPASS audit entry'
					);
		}
	}

	/**
	 * @description Verifies the chain-abort check passes when the only profile holding the abort custom
	 * permission is System Administrator, which an admins-only install is expected to write. That grant
	 * must never warn, or every correctly installed org would show a warning forever. A second parent
	 * shaped like a permission set (ProfileId null, like the grant the AsyncChainAbort set always has in
	 * real orgs) is added to check the null check in the code: a grant through a permission set
	 * assignment, the intended route, must never count as a profile grant.
	 */
	@IsTest
	private static void shouldPassAbortCheckWhenOnlySystemAdministratorProfileHoldsPermission()
	{
		Id profileOwnedParentId = UTIL_Random.randomId(PermissionSet.SObjectType);
		Id permissionSetParentId = UTIL_Random.randomId(PermissionSet.SObjectType);
		TST_Mock.of(PermissionSet.SObjectType).withOverrides(new Map<SObjectField, Object>
		{
				PermissionSet.Id => profileOwnedParentId,
				PermissionSet.IsOwnedByProfile => true,
				PermissionSet.ProfileId => new SEL_Profile().findByName(SEL_Profile.PROFILE_SYSTEM_ADMIN).Id
		}).build();
		TST_Mock.of(PermissionSet.SObjectType).withOverrides(new Map<SObjectField, Object>
		{
				PermissionSet.Id => permissionSetParentId,
				PermissionSet.IsOwnedByProfile => false
		}).build();
		TST_Mock.of(SetupEntityAccess.SObjectType).withOverrides(new Map<SObjectField, Object>
		{
				SetupEntityAccess.ParentId => profileOwnedParentId
		}).build();
		TST_Mock.of(SetupEntityAccess.SObjectType).withOverrides(new Map<SObjectField, Object>
		{
				SetupEntityAccess.ParentId => permissionSetParentId
		}).build();
		TST_Mock.register(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment> {abortAssignment()});

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, results[6].status, 'The System Administrator grant an admins-only install writes is expected and must not warn');
		Assert.areEqual(System.Label.HealthCheck_AsyncChainAbort_Configured, results[6].detail, 'The pass detail confirms the capability is usable');
	}

	/**
	 * @description Verifies the chain-abort check degrades gracefully when the System Administrator
	 * profile cannot be resolved by name (standard profile names come back localised for non-English
	 * users): the broad-grant probe steps aside instead of failing the whole Health Check, and the
	 * check falls through to the assignee probe. Mirrors the null-guard precedent in
	 * UTIL_FeatureFlag.checkProfile. The grant chain is fully linked (grant to profile-owned parent
	 * with a live ProfileId) so an implementation that pressed on with a null administrator Id would
	 * compare ProfileId against null, warn, and turn this test red.
	 */
	@IsTest
	private static void shouldPassAbortCheckWhenAdministratorProfileCannotBeResolved()
	{
		Id profileOwnedParentId = UTIL_Random.randomId(PermissionSet.SObjectType);
		TST_Mock.register(Profile.SObjectType, new List<Profile>());
		TST_Mock.of(PermissionSet.SObjectType).withOverrides(new Map<SObjectField, Object>
		{
				PermissionSet.Id => profileOwnedParentId,
				PermissionSet.IsOwnedByProfile => true,
				PermissionSet.ProfileId => UTIL_Random.randomId(Profile.SObjectType)
		}).build();
		TST_Mock.of(SetupEntityAccess.SObjectType).withOverrides(new Map<SObjectField, Object>
		{
				SetupEntityAccess.ParentId => profileOwnedParentId
		}).build();
		TST_Mock.register(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment> {abortAssignment()});

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, results[6].status, 'An unresolvable administrator profile must skip the broad-grant probe, not crash the Health Check');
		Assert.areEqual(System.Label.HealthCheck_AsyncChainAbort_Configured, results[6].detail, 'The check falls through to the assignee probe');
	}

	/**
	 * @description Verifies the chain-abort check degrades gracefully when the abort custom permission
	 * itself cannot be resolved: the namespace-scoped lookup returns nothing, so the broad-grant probe
	 * has no grants to inspect and must report no broad grant rather than warn or fail the whole
	 * Health Check, and the check falls through to the assignee probe.
	 */
	@IsTest
	private static void shouldPassAbortCheckWhenAbortCustomPermissionCannotBeResolved()
	{
		TST_Mock.register(CustomPermission.SObjectType, new List<CustomPermission>());
		TST_Mock.register(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment> {abortAssignment()});

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, results[6].status, 'An unresolvable abort permission must skip the broad-grant probe, not crash the Health Check');
		Assert.areEqual(System.Label.HealthCheck_AsyncChainAbort_Configured, results[6].detail, 'The check falls through to the assignee probe');
	}

	/**
	 * @description Mocks a profile-owned permission set holding the abort custom permission, the shape an
	 * install for a profile writes, together with the grant row that points at it.
	 *
	 * @param profileName The name of the profile that owns the permission set.
	 *
	 * @return The mocked permission set's id, the parent of the grant row.
	 */
	private static Id mockProfileOwnedAbortGrant(String profileName)
	{
		Id profileOwnedParentId = UTIL_Random.randomId(PermissionSet.SObjectType);
		TST_Mock.of(PermissionSet.SObjectType).withOverrides(new Map<SObjectField, Object>
		{
				PermissionSet.Id => profileOwnedParentId,
				PermissionSet.IsOwnedByProfile => true,
				PermissionSet.ProfileId => new SEL_Profile().findByName(profileName).Id
		}).build();
		TST_Mock.of(SetupEntityAccess.SObjectType).withOverrides(new Map<SObjectField, Object>
		{
				SetupEntityAccess.ParentId => profileOwnedParentId
		}).build();
		return profileOwnedParentId;
	}

	/**
	 * @description Builds a non-inserted PermissionSetAssignment mock row. The abort probe counts through
	 * the TST_Mock registry, which returns the seeded list size, so a bare row is enough to prove presence.
	 *
	 * @return A non-inserted PermissionSetAssignment record.
	 */
	private static PermissionSetAssignment abortAssignment()
	{
		return (PermissionSetAssignment)TST_Builder.of(PermissionSetAssignment.SObjectType).withoutInsertion().build();
	}

	/**
	 * @description Verifies the chain-watchdog check warns when neither scheduling path shows a watchdog:
	 * no active declarative ScheduledJob__c and no live scheduled-Apex platform row. The AsyncApexJob mock
	 * is seeded empty because platform job rows are visible to tests regardless of test-data isolation, so
	 * an ambient watchdog schedule in the org would otherwise flip this check to Pass.
	 */
	@IsTest
	private static void shouldWarnWhenChainWatchdogNotScheduled()
	{
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>());
		TST_Mock.register(AsyncApexJob.SObjectType, new List<AsyncApexJob>());

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult watchdogResult = results[7];
		Assert.areEqual(System.Label.HealthCheck_ChainWatchdog_CheckName, watchdogResult.name, 'the eighth check is the chain watchdog');
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, watchdogResult.status, 'an unscheduled watchdog is the operational gap this check surfaces');
		Assert.areEqual(System.Label.HealthCheck_ChainWatchdog_Missing, watchdogResult.detail, 'the detail names the missing watchdog sweep');
		Assert.areEqual(48, watchdogResult.priority, 'the chain watchdog should have priority 48');
		Assert.isNull(watchdogResult.actionLabel, 'no actionLabel: healthCheck.js draws schedule and customize from its own template branch');
	}

	/**
	 * @description Verifies the chain-watchdog check passes through the declarative path: an active
	 * ScheduledJob__c targeting SCHED_ChainWatchdog proves the watchdog is scheduled, short-circuiting
	 * before the platform-job probe ever runs. The AsyncApexJob mock is seeded empty so the Pass can
	 * only come from the declarative leg: were that leg to regress, the platform probe would read the
	 * empty mock (never an ambient org schedule, which platform-job visibility would otherwise leak in)
	 * and the check would warn.
	 */
	@IsTest
	private static void shouldPassChainWatchdogViaDeclarativeScheduledJob()
	{
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c> {newWatchdogJob()});
		TST_Mock.register(AsyncApexJob.SObjectType, new List<AsyncApexJob>());

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult watchdogResult = results[7];
		Assert.areEqual(System.Label.HealthCheck_ChainWatchdog_CheckName, watchdogResult.name, 'the eighth check is the chain watchdog');
		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, watchdogResult.status, 'an active declarative watchdog job passes the check');
		Assert.isTrue(watchdogResult.detail.startsWith(System.Label.HealthCheck_ChainWatchdog_Configured),
				'the pass detail confirms the watchdog is scheduled: ' + watchdogResult.detail);
		Assert.isNull(watchdogResult.actionLabel, 'a passing check offers no action');
	}

	/**
	 * @description Verifies the chain-watchdog check passes through the platform path: no declarative
	 * ScheduledJob__c exists, but a live scheduled-Apex AsyncApexJob row for the watchdog class does:
	 * the trace a hand-run System.schedule leaves. The ApexClass and AsyncApexJob rows are mocked in the
	 * shape the probe derives; the mock layer answers queries regardless of their filters, so the
	 * assertion is on the check's outcome.
	 */
	@IsTest
	private static void shouldPassChainWatchdogViaPlatformScheduledApexJob()
	{
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>());
		ApexClass watchdogClass = registerWatchdogApexClassMock();
		TST_Mock.of(AsyncApexJob.SObjectType).withOverrides(new Map<SObjectField, Object>
		{
				AsyncApexJob.JobType => JOB_TYPE_SCHEDULED_APEX,
				AsyncApexJob.ApexClassId => watchdogClass.Id,
				AsyncApexJob.Status => LIVE_SCHEDULED_APEX_STATUS
		}).build();

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult watchdogResult = results[7];
		Assert.areEqual(System.Label.HealthCheck_ChainWatchdog_CheckName, watchdogResult.name, 'the eighth check is the chain watchdog');
		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, watchdogResult.status, 'a live scheduled-Apex platform row passes the check without any declarative job');
		Assert.isTrue(watchdogResult.detail.startsWith(System.Label.HealthCheck_ChainWatchdog_Configured),
				'the pass detail confirms the watchdog is scheduled: ' + watchdogResult.detail);
	}

	/**
	 * @description Verifies getChainWatchdogProposal returns the recommended defaults the one-click
	 * schedule applies: the scheduler label, the namespace-qualified class name, the hourly cron, and
	 * the parameter names and values the editor-modal prefill needs.
	 */
	@IsTest
	private static void shouldReturnChainWatchdogProposalWithRecommendedDefaults()
	{
		CTRL_HealthCheck.DTO_ChainWatchdogProposal proposal = CTRL_HealthCheck.getChainWatchdogProposal();

		Assert.areEqual(System.Label.HealthCheck_ChainWatchdog_SchedulerName, proposal.schedulerName, 'the proposal carries the scheduler display name from the label');
		Assert.areEqual(WATCHDOG_CLASS, proposal.schedulerClassName, 'the proposal carries the namespace-qualified watchdog class name so the LWC never guesses');
		Assert.areEqual(RECOMMENDED_HOURLY_CRON, proposal.cronExpression, 'the recommended cron is the hourly sweep');
		Assert.areEqual(SCHED_ChainWatchdog.PARAMETER_STALE_THRESHOLD_MINUTES, proposal.staleThresholdMinutesParameterName, 'the parameter name comes from the constant');
		Assert.areEqual(RECOMMENDED_STALE_THRESHOLD_MINUTES, proposal.staleThresholdMinutes, 'the recommended stale threshold is thirty minutes');
		Assert.areEqual(SCHED_ChainWatchdog.PARAMETER_BATCH_SIZE, proposal.batchSizeParameterName, 'the batch-size parameter name comes from the public constant');
		Assert.areEqual(RECOMMENDED_BATCH_SIZE, proposal.batchSize, 'the recommended batch size is fifty chains per sweep');
	}

	/**
	 * @description Verifies scheduleChainWatchdog creates one active watchdog ScheduledJob__c carrying
	 * the chosen cron, the running user's timezone, a description of what it checks, and the recommended
	 * parameters serialized as name-value text. The AsyncApexJob mock is seeded empty so an ambient watchdog schedule in the org
	 * (platform job rows are visible to tests) can never trip the skip guard, and the ScheduledJob__c
	 * trigger is bypassed so the insert does not System.schedule for real, mirroring the retention
	 * apply tests.
	 */
	@IsTest
	private static void shouldScheduleChainWatchdogWithChosenCron()
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);
		TST_Mock.register(AsyncApexJob.SObjectType, new List<AsyncApexJob>());

		Test.startTest();
		Id scheduledJobId = CTRL_HealthCheck.scheduleChainWatchdog(CUSTOM_WATCHDOG_CRON);
		Test.stopTest();

		Assert.isNotNull(scheduledJobId, 'the happy path returns the created job id');
		ScheduledJob__c createdJob = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduledJobId);
		Assert.areEqual(System.Label.HealthCheck_ChainWatchdog_SchedulerName, createdJob.SchedulerName__c, 'the scheduler display name comes from the label');
		Assert.areEqual(WATCHDOG_CLASS, createdJob.ClassName__c, 'the job targets SCHED_ChainWatchdog, namespace-qualified');
		Assert.areEqual(CUSTOM_WATCHDOG_CRON, createdJob.CronExpression__c, 'the chosen cron wins over the hourly default');
		Assert.isTrue(createdJob.IsActive__c, 'the job is created active');
		Assert.areEqual(UserInfo.getTimeZone().getID(), createdJob.Timezone__c, 'the timezone defaults to the running user so the cron fires at the intended local time');
		Assert.areEqual(String.format(System.Label.HealthCheck_ChainWatchdog_JobDescription, new List<Object> {RECOMMENDED_STALE_THRESHOLD_MINUTES}),
				createdJob.Description__c, 'Expected the description to say what the watchdog looks for and the stale threshold it uses');

		DTO_NameValues parameters = (DTO_NameValues)new DTO_NameValues().deserialize(createdJob.Parameters__c);
		Assert.areEqual(RECOMMENDED_STALE_THRESHOLD_MINUTES, parameters.get(SCHED_ChainWatchdog.PARAMETER_STALE_THRESHOLD_MINUTES), 'the parameters carry the stale threshold');
		Assert.areEqual(RECOMMENDED_BATCH_SIZE, parameters.get(SCHED_ChainWatchdog.PARAMETER_BATCH_SIZE), 'the serialized parameters carry the recommended batch size');
	}

	/**
	 * @description Verifies a blank cron falls back to the recommended hourly default: what the
	 * one-click schedule path submits when the administrator customizes nothing.
	 */
	@IsTest
	private static void shouldFallBackToHourlyCronWhenSuppliedCronIsBlank()
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);
		TST_Mock.register(AsyncApexJob.SObjectType, new List<AsyncApexJob>());

		Test.startTest();
		Id scheduledJobId = CTRL_HealthCheck.scheduleChainWatchdog(UTIL_String.EMPTY);
		Test.stopTest();

		Assert.isNotNull(scheduledJobId, 'the blank-cron path still creates the job');
		ScheduledJob__c createdJob = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduledJobId);
		Assert.areEqual(RECOMMENDED_HOURLY_CRON, createdJob.CronExpression__c, 'a blank cron falls back to the recommended hourly sweep');
	}

	/**
	 * @description Verifies the skip guard: when a watchdog is already scheduled, a stale button click
	 * returns null and creates nothing. The unchanged DML-statement count proves no insert ran: the
	 * ScheduledJob__c mock intercepts the selector reads, so the real table cannot be queried to prove
	 * absence directly.
	 */
	@IsTest
	private static void shouldSkipSchedulingWhenWatchdogAlreadyScheduled()
	{
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c> {newWatchdogJob()});
		Integer dmlStatementsBeforeCall = UTIL_Limits.dmlStatements().used();

		Id scheduledJobId = CTRL_HealthCheck.scheduleChainWatchdog(RECOMMENDED_HOURLY_CRON);

		Assert.isNull(scheduledJobId, 'an already-scheduled watchdog returns null: a click on an out-of-date button never creates a duplicate');
		Assert.areEqual(dmlStatementsBeforeCall, UTIL_Limits.dmlStatements().used(), 'the skip guard must create nothing: no DML runs');
	}

	/**
	 * @description Builds a non-inserted, active ScheduledJob__c targeting SCHED_ChainWatchdog with the
	 * recommended watchdog parameters: the row that shows the declarative path. IsActive__c is set true so the
	 * row mirrors what findActiveByClassName actually matches, even though the mock layer answers
	 * queries regardless of their filters.
	 *
	 * @return A non-inserted active watchdog ScheduledJob__c record with a mock Id.
	 */
	private static ScheduledJob__c newWatchdogJob()
	{
		DTO_NameValues parameters = new DTO_NameValues(new Map<String, String>
		{
				SCHED_ChainWatchdog.PARAMETER_STALE_THRESHOLD_MINUTES => RECOMMENDED_STALE_THRESHOLD_MINUTES,
				SCHED_ChainWatchdog.PARAMETER_BATCH_SIZE => RECOMMENDED_BATCH_SIZE
		});

		return (ScheduledJob__c)TST_Builder.of(ScheduledJob__c.SObjectType)
				.withOverride(ScheduledJob__c.ClassName__c, WATCHDOG_CLASS)
				.withOverride(ScheduledJob__c.IsActive__c, true)
				.withOverride(ScheduledJob__c.Parameters__c, parameters.serialize())
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Registers a mocked ApexClass row for SCHED_ChainWatchdog, split into local name and
	 * namespace prefix exactly as the platform probe derives them, so the seeded row is realistic in
	 * both namespaced and unmanaged deployments.
	 *
	 * @return The registered mock ApexClass row with a mock Id.
	 */
	private static ApexClass registerWatchdogApexClassMock()
	{
		Boolean isNamespaced = WATCHDOG_CLASS.contains(UTIL_String.DOT);
		TST_Mock.MockBuilder watchdogClassBuilder = TST_Mock.of(ApexClass.SObjectType)
				.withOverride(ApexClass.Name, isNamespaced ? WATCHDOG_CLASS.substringAfterLast(UTIL_String.DOT) : WATCHDOG_CLASS);
		if(isNamespaced)
		{
			watchdogClassBuilder = watchdogClassBuilder.withOverride(ApexClass.NamespacePrefix, WATCHDOG_CLASS.substringBeforeLast(UTIL_String.DOT));
		}
		return (ApexClass)watchdogClassBuilder.build();
	}

	/**
	 * @description Verifies that getRetentionProposals returns proposals for all four framework objects
	 * when no SCHED_PurgeRecords jobs exist.
	 */
	@IsTest
	private static void shouldReturnProposalsForUnconfiguredFrameworkObjects()
	{
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>());

		Test.startTest();
		List<CTRL_HealthCheck.DTO_RetentionProposal> proposals = CTRL_HealthCheck.getRetentionProposals();
		Test.stopTest();

		Assert.areEqual(4, proposals.size(), 'All four framework objects should be proposed when no purge jobs exist');

		Set<String> returnedLabels = new Set<String>();
		for(CTRL_HealthCheck.DTO_RetentionProposal proposal : proposals)
		{
			returnedLabels.add(proposal.objectLabel);
			Assert.isNotNull(proposal.objectApiName, 'objectApiName should be populated');
			Assert.isNotNull(proposal.retentionDays, 'retentionDays should be populated');
			Assert.isNotNull(proposal.schedulerName, 'schedulerName should be populated');
			Assert.isNotNull(proposal.schedulerClassName, 'schedulerClassName should be populated');
			Assert.areEqual(SCHED_PurgeRecords.class.getName(), proposal.schedulerClassName, 'schedulerClassName should equal the resolved SCHED_PurgeRecords class name');
			Assert.isNotNull(proposal.cronExpression, 'cronExpression should be populated');
		}
		Assert.isTrue(returnedLabels.contains('Log Entry'), 'Log Entry should be proposed');
		Assert.isTrue(returnedLabels.contains('API Call'), 'API Call should be proposed');
		Assert.isTrue(returnedLabels.contains('API Issue'), 'API Issue should be proposed');
		Assert.isTrue(returnedLabels.contains('Async Chain Execution'), 'Async Chain Execution should be proposed');
	}

	/**
	 * @description Verifies that getRetentionProposals omits objects that already have an active
	 * SCHED_PurgeRecords job.
	 */
	@IsTest
	private static void shouldOmitObjectsAlreadyCoveredByActivePurgeJob()
	{
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>
		{
				newPurgeJob(LogEntry__c.SObjectType)
		});

		Test.startTest();
		List<CTRL_HealthCheck.DTO_RetentionProposal> proposals = CTRL_HealthCheck.getRetentionProposals();
		Test.stopTest();

		Assert.areEqual(3, proposals.size(), 'Three unconfigured objects should remain');
		for(CTRL_HealthCheck.DTO_RetentionProposal proposal : proposals)
		{
			Assert.areNotEqual('Log Entry', proposal.objectLabel, 'Log Entry should be excluded');
		}
	}

	/**
	 * @description Verifies that applyRetentionRecommendations creates one active SCHED_PurgeRecords
	 * ScheduledJob__c per supplied proposal.
	 */
	@IsTest
	private static void shouldCreateActivePurgeJobsForEachProposal()
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);

		List<CTRL_HealthCheck.DTO_RetentionProposal> proposals = CTRL_HealthCheck.getRetentionProposals();
		Assert.areEqual(4, proposals.size(), 'Pre-condition: four proposals available');

		Test.startTest();
		List<Id> insertedIds = CTRL_HealthCheck.applyRetentionRecommendations(proposals);
		Test.stopTest();

		Assert.areEqual(4, insertedIds.size(), 'Four scheduled jobs should be created');

		List<ScheduledJob__c> created = new SEL_ScheduledJob().findById(new Set<Id>(insertedIds));
		Assert.areEqual(4, created.size(), 'All jobs should be queryable');
		String runningUserTimezone = UserInfo.getTimeZone().getID();
		for(ScheduledJob__c job : created)
		{
			Assert.isTrue(job.IsActive__c, 'Job should be active');
			Assert.isTrue(job.ClassName__c.endsWith('SCHED_PurgeRecords'), 'Job should target SCHED_PurgeRecords');
			Assert.isNotNull(job.Parameters__c, 'Parameters__c should be populated');
			Assert.areEqual(runningUserTimezone, job.Timezone__c, 'Timezone should default to the running user timezone so cron fires at the intended local time');
		}
	}

	/**
	 * @description Verifies the retention proposal for AsyncChainExecution__c schedules its purge
	 * job with CompletedAt__c as the date-field parameter
	 * (SCHED_PurgeRecords.OPTIONAL_PARAMETER_DATE_FIELD_NAME), while every other proposal omits the
	 * parameter so its job falls back to the SCHED_PurgeRecords CreatedDate default (appropriate
	 * for those insert-once framework objects, which have no separate completion timestamp).
	 * Keying the chain purge on CompletedAt__c is what makes it safe: Stalled and Running rows
	 * carry a null CompletedAt__c until a terminal path (the code that marks a chain Completed,
	 * Failed or Aborted) stamps it, so the purge can never delete a chain that has not finished.
	 * Each job's description names the records it deletes and their age in days, and the chain job's also names the date field.
	 */
	@IsTest
	private static void shouldKeyAsyncChainPurgeOnCompletedAtDateField()
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);

		List<CTRL_HealthCheck.DTO_RetentionProposal> proposals = CTRL_HealthCheck.getRetentionProposals();

		Test.startTest();
		List<Id> insertedIds = CTRL_HealthCheck.applyRetentionRecommendations(proposals);
		Test.stopTest();

		String chainObjectName = UTIL_SObjectDescribe.getObjectNameFromType(AsyncChainExecution__c.SObjectType);
		String completedAtFieldName = UTIL_SObjectDescribe.getCachedFieldName(AsyncChainExecution__c.CompletedAt__c);
		String completedAtFieldLabel = UTIL_SObjectDescribe.getCachedFieldDescribe(AsyncChainExecution__c.CompletedAt__c).getLabel();
		Map<String, CTRL_HealthCheck.DTO_RetentionProposal> proposalByObjectName = new Map<String, CTRL_HealthCheck.DTO_RetentionProposal>();
		for(CTRL_HealthCheck.DTO_RetentionProposal proposal : proposals)
		{
			proposalByObjectName.put(proposal.objectApiName, proposal);
		}
		Integer chainJobCount = 0;
		List<ScheduledJob__c> createdJobs = new SEL_ScheduledJob().findById(new Set<Id>(insertedIds));
		for(ScheduledJob__c job : createdJobs)
		{
			DTO_NameValues parameters = (DTO_NameValues)new DTO_NameValues().deserialize(job.Parameters__c);
			CTRL_HealthCheck.DTO_RetentionProposal proposal = proposalByObjectName.get(parameters.get(SCHED_PurgeRecords.REQUIRED_PARAMETER_OBJECT_NAME));
			String objectPluralLabel = UTIL_SObjectDescribe.getDescribe(proposal.objectApiName).getDescribe().getLabelPlural();
			String retentionDays = String.valueOf(proposal.retentionDays);
			if(chainObjectName.equals(parameters.get(SCHED_PurgeRecords.REQUIRED_PARAMETER_OBJECT_NAME)))
			{
				chainJobCount++;
				Assert.areEqual(completedAtFieldName, parameters.get(SCHED_PurgeRecords.OPTIONAL_PARAMETER_DATE_FIELD_NAME),
						'The async-chain purge job must key on CompletedAt__c so non-terminal chains are never purged');
				Assert.areEqual(String.format(System.Label.HealthCheck_DataRetention_JobDescriptionWithDateField,
						new List<Object> {objectPluralLabel, completedAtFieldLabel, retentionDays}), job.Description__c,
						'Expected the chain purge description to name the object, the date field and the age in days');
			}
			else
			{
				Assert.isNull(parameters.get(SCHED_PurgeRecords.OPTIONAL_PARAMETER_DATE_FIELD_NAME),
						'Insert-once framework objects keep the CreatedDate default');
				Assert.areEqual(String.format(System.Label.HealthCheck_DataRetention_JobDescription, new List<Object> {objectPluralLabel, retentionDays}),
						job.Description__c, 'Expected the purge description to name the object and the age in days');
			}
		}
		Assert.areEqual(1, chainJobCount, 'Exactly one proposal targets AsyncChainExecution__c');
	}

	/**
	 * @description Verifies that a user-supplied cron expression overrides the framework default.
	 */
	@IsTest
	private static void shouldRespectUserSelectedCronExpression()
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);

		List<CTRL_HealthCheck.DTO_RetentionProposal> proposals = CTRL_HealthCheck.getRetentionProposals();
		proposals.get(0).cronExpression = '0 0 1 * * ?';

		Test.startTest();
		List<Id> insertedIds = CTRL_HealthCheck.applyRetentionRecommendations(new List<CTRL_HealthCheck.DTO_RetentionProposal> {proposals.get(0)});
		Test.stopTest();

		ScheduledJob__c created = (ScheduledJob__c)new SEL_ScheduledJob().findById(insertedIds.get(0));
		Assert.areEqual('0 0 1 * * ?', created.CronExpression__c, 'User-supplied cron should win');
	}

	/**
	 * @description Verifies that proposals for objects not in the framework recommendation map are
	 * skipped silently.
	 */
	@IsTest
	private static void shouldSkipProposalsForNonFrameworkObjects()
	{
		CTRL_HealthCheck.DTO_RetentionProposal unknown = new CTRL_HealthCheck.DTO_RetentionProposal();
		unknown.objectApiName = Foobar__c.SObjectType.getDescribe().getName();
		unknown.retentionDays = 30;
		unknown.schedulerName = 'Should Not Be Used';
		unknown.cronExpression = '0 0 3 * * ?';

		Test.startTest();
		List<Id> insertedIds = CTRL_HealthCheck.applyRetentionRecommendations(new List<CTRL_HealthCheck.DTO_RetentionProposal> {unknown});
		Test.stopTest();

		Assert.areEqual(0, insertedIds.size(), 'No job should be created for objects outside the framework recommendation map');
	}

	/**
	 * @description Verifies that proposals for objects already covered by an active purge job are
	 * skipped silently.
	 */
	@IsTest
	private static void shouldSkipObjectsAlreadyCovered()
	{
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>
		{
				newPurgeJob(LogEntry__c.SObjectType)
		});

		CTRL_HealthCheck.DTO_RetentionProposal duplicate = new CTRL_HealthCheck.DTO_RetentionProposal();
		duplicate.objectApiName = LogEntry__c.SObjectType.getDescribe().getName();
		duplicate.retentionDays = 90;
		duplicate.schedulerName = 'Purge Log Entries';
		duplicate.cronExpression = '0 0 2 * * ?';

		Test.startTest();
		List<Id> insertedIds = CTRL_HealthCheck.applyRetentionRecommendations(new List<CTRL_HealthCheck.DTO_RetentionProposal> {duplicate});
		Test.stopTest();

		Assert.areEqual(0, insertedIds.size(), 'No job should be created when one already covers the object');
	}

	/**
	 * @description Creates a non-inserted ScheduledJob__c for SCHED_PurgeRecords targeting the given object.
	 *
	 * @param objectType The SObjectType to configure purge for
	 *
	 * @return A non-inserted ScheduledJob__c record
	 */
	private static ScheduledJob__c newPurgeJob(SObjectType objectType)
	{
		return TST_Factory.newScheduledJob(PURGE_CLASS, new DTO_NameValues(new Map<String, String> {PARAM_OBJECT_NAME => objectType.getDescribe().getName()}));
	}

	/**
	 * @description Builds an in-memory MaskingRule__mdt with a mock Id and the given active flag, so a
	 * MaskingTarget__mdt can reference it through the masking selector's test overrides.
	 *
	 * @param active Whether the rule is active.
	 *
	 * @return The in-memory rule with a mock Id.
	 */
	private static MaskingRule__mdt maskingRule(Boolean active)
	{
		return TST_Factory.newMaskingRule(new Map<SObjectField, Object> {MaskingRule__mdt.IsActive__c => active});
	}

	/**
	 * @description Builds an in-memory MaskingTarget__mdt with a mock Id for the masking-posture checks. A null
	 * fieldDurableId yields an object-wide target; a null ruleId leaves the rule reference unset (a dead target).
	 *
	 * @param developerName The target's DeveloperName.
	 * @param sObjectDurableId The EntityDefinition durable Id the target is scoped to.
	 * @param fieldDurableId The FieldDefinition durable Id, or null for an object-wide target.
	 * @param active Whether the target is active.
	 * @param ruleId The referenced rule's mock Id, or null for a missing-rule target.
	 *
	 * @return The in-memory target with a mock Id.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static MaskingTarget__mdt maskingTarget(String developerName, String sObjectDurableId, String fieldDurableId, Boolean active, Id ruleId)
	{
		Map<SObjectField, Object> overrides = new Map<SObjectField, Object>
		{
				MaskingTarget__mdt.DeveloperName => developerName,
				MaskingTarget__mdt.IsActive__c => active,
				MaskingTarget__mdt.SObjectType__c => sObjectDurableId
		};
		if(fieldDurableId != null)
		{
			overrides.put(MaskingTarget__mdt.Field__c, fieldDurableId);
		}
		if(ruleId != null)
		{
			overrides.put(MaskingTarget__mdt.Rule__c, ruleId);
		}
		return TST_Factory.newMaskingTarget(overrides);
	}

	/**
	 * @description Verifies that the @AuraEnabled JSON wrapper deserialises the payload and delegates
	 * to the typed helper, producing the same inserted jobs.
	 */
	@IsTest
	private static void shouldDeserializeJsonProposalsAndDelegate()
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);

		List<CTRL_HealthCheck.DTO_RetentionProposal> proposals = CTRL_HealthCheck.getRetentionProposals();
		String proposalsJson = JSON.serialize(proposals);

		Test.startTest();
		List<Id> insertedIds = CTRL_HealthCheck.applyRetentionRecommendations(proposalsJson);
		Test.stopTest();

		Assert.areEqual(4, insertedIds.size(), 'Wrapper should delegate and return all four inserted IDs');
	}

	/**
	 * @description Verifies that the @AuraEnabled JSON wrapper short-circuits and returns an empty
	 * list when the supplied JSON string is blank or null.
	 */
	@IsTest
	private static void shouldReturnEmptyListForBlankJson()
	{
		Test.startTest();
		List<Id> emptyResult = CTRL_HealthCheck.applyRetentionRecommendations('');
		List<Id> nullResult = CTRL_HealthCheck.applyRetentionRecommendations((String)null);
		Test.stopTest();

		Assert.areEqual(0, emptyResult.size(), 'Blank JSON should return empty list');
		Assert.areEqual(0, nullResult.size(), 'Null JSON should return empty list');
	}

	/**
	 * @description Verifies that the typed helper short-circuits and returns an empty list when
	 * the supplied proposals list is null or empty.
	 */
	@IsTest
	private static void shouldReturnEmptyListForNullOrEmptyProposals()
	{
		Test.startTest();
		List<Id> nullResult = CTRL_HealthCheck.applyRetentionRecommendations((List<CTRL_HealthCheck.DTO_RetentionProposal>)null);
		List<Id> emptyResult = CTRL_HealthCheck.applyRetentionRecommendations(new List<CTRL_HealthCheck.DTO_RetentionProposal>());
		Test.stopTest();

		Assert.areEqual(0, nullResult.size(), 'Null proposals should return empty list');
		Assert.areEqual(0, emptyResult.size(), 'Empty proposals should return empty list');
	}

	/**
	 * @description The administrator who holds the Kern Job Runner Management permission set.
	 *
	 * @return The managing administrator.
	 */
	private static User getManagingAdmin()
	{
		return new SEL_User().findByCompanyName(MANAGING_ADMIN_COMPANY);
	}

	/**
	 * @description The administrator who holds no job-runner permission, so every action refuses them.
	 *
	 * @return The plain administrator.
	 */
	private static User getPlainAdmin()
	{
		return new SEL_User().findByCompanyName(PLAIN_ADMIN_COMPANY);
	}

	/**
	 * @description The inactive user standing in for an activator whose account was deactivated.
	 *
	 * @return The inactive user.
	 */
	private static User getInactiveActivator()
	{
		return new SEL_User().findByCompanyName(INACTIVE_ACTIVATOR_COMPANY);
	}

	/**
	 * @description Seeds the runner's own records with the trigger bypassed, each pointing at a mocked scheduled job
	 * owned by the given user, so a dimension can be driven without scheduling anything for real. The scheduled job is
	 * mocked first because the mock layer issues its own id, which the record then points at.
	 *
	 * @param minuteMarks The minute marks the records fire at.
	 * @param ownerId The user the mocked scheduled jobs belong to.
	 * @param cronTriggerState The state of the mocked scheduled jobs.
	 */
	private static void seedRunnerRecords(List<Integer> minuteMarks, Id ownerId, String cronTriggerState)
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);
		for(Integer mark : minuteMarks)
		{
			CronTrigger mockedTrigger = (CronTrigger)TST_Mock.of(CronTrigger.SObjectType)
					.withOverrides(new Map<SObjectField, Object> {CronTrigger.State => cronTriggerState, CronTrigger.OwnerId => ownerId})
					.build();
			TST_Builder.of(ScheduledJob__c.SObjectType)
					.withOverride(ScheduledJob__c.SchedulerName__c,
							String.format(System.Label.HealthCheck_JobRunnerRecordName, new List<Object> {String.valueOf(mark).leftPad(2, '0')}))
					.withOverride(ScheduledJob__c.ClassName__c, UTIL_ScheduledJobRunner.RUNNER_CLASS_NAME)
					.withOverride(ScheduledJob__c.CronExpression__c, '0 ' + mark + ' * * * ?')
					.withOverride(ScheduledJob__c.IsActive__c, true)
					.withOverride(ScheduledJob__c.ScheduledJobId__c, String.valueOf(mockedTrigger.Id))
					.build();
		}
		TRG_Base.clearBypass(ScheduledJob__c.SObjectType);
	}

	/**
	 * @description Moves the creation time of every runner record, which is when the runner reads as having been
	 * activated or repaired, back to a chosen moment, so a test can seed a runner that has been running for a while
	 * rather than one activated as the test ran.
	 *
	 * @param activatedAt The moment the records are to read as created at.
	 */
	private static void backdateRunnerRecordsTo(Datetime activatedAt)
	{
		for(ScheduledJob__c runner : new SEL_ScheduledJob().findRunnerRecords())
		{
			Test.setCreatedDate(runner.Id, activatedAt);
		}
	}

	/**
	 * @description Records when the runner last checked for due jobs, through the framework writer the runner itself uses.
	 *
	 * @param checkedAt The time of the check.
	 */
	private static void recordLastCheck(Datetime checkedAt)
	{
		new UTIL_ScheduledJobRunner.FrameworkWriter().recordLastCheck(checkedAt);
	}

	/**
	 * @description Seeds one active job set to run on the job runner whose next run is already in the past, so it is a job
	 * waiting for the runner. It carries the purge job's own parameters because the Data Retention check reads the
	 * parameters of every active purge job, whichever mode it runs in.
	 */
	private static void seedWaitingJob()
	{
		seedActivePurgeJob(LogEntry__c.SObjectType, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER, new Map<SObjectField, Object>
		{
				ScheduledJob__c.CronExpression__c => '0 */5 * * * ?',
				ScheduledJob__c.NextRunAt__c => Datetime.now().addMinutes(-20)
		});
	}

	/**
	 * @description Seeds an active chain-watchdog record already set to run on the job runner, the shape Health Check
	 * creates while a runner is active. The trigger is bypassed so the record lands without the permission gate or a
	 * cursor seed getting in the way.
	 */
	private static void seedWatchdogRidingTheRunner()
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);
		TST_Builder.of(ScheduledJob__c.SObjectType)
				.withOverride(ScheduledJob__c.SchedulerName__c, System.Label.HealthCheck_ChainWatchdog_SchedulerName)
				.withOverride(ScheduledJob__c.ClassName__c, WATCHDOG_CLASS)
				.withOverride(ScheduledJob__c.CronExpression__c, RECOMMENDED_HOURLY_CRON)
				.withOverride(ScheduledJob__c.IsActive__c, true)
				.withOverride(ScheduledJob__c.ExecutionMode__c, UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER)
				.build();
		TRG_Base.clearBypass(ScheduledJob__c.SObjectType);
	}

	/**
	 * @description Seeds an active chain-watchdog record on a scheduled job of its own, the shape an org that scheduled
	 * the watchdog before the job runner existed carries into an upgrade. The trigger is bypassed so the record lands
	 * without scheduling anything for real.
	 */
	private static void seedWatchdogOnItsOwnScheduledJob()
	{
		TRG_Base.bypass(ScheduledJob__c.SObjectType);
		TST_Builder.of(ScheduledJob__c.SObjectType)
				.withOverride(ScheduledJob__c.SchedulerName__c, System.Label.HealthCheck_ChainWatchdog_SchedulerName)
				.withOverride(ScheduledJob__c.ClassName__c, WATCHDOG_CLASS)
				.withOverride(ScheduledJob__c.CronExpression__c, RECOMMENDED_HOURLY_CRON)
				.withOverride(ScheduledJob__c.IsActive__c, true)
				.withOverride(ScheduledJob__c.ExecutionMode__c, UTIL_ScheduledJobRunner.EXECUTION_MODE_OWN_SCHEDULED_JOB)
				.build();
		TRG_Base.clearBypass(ScheduledJob__c.SObjectType);
	}

	/**
	 * @description The minute mark a runner record fires at, read from the second token of its cron expression.
	 *
	 * @param runner The runner record.
	 *
	 * @return The minute mark.
	 */
	private static Integer minuteMarkOf(ScheduledJob__c runner)
	{
		return Integer.valueOf(runner.CronExpression__c.split('\\s+')[1]);
	}

	/**
	 * @description Finds one health check result by its display name, failing the test when no result carries it.
	 *
	 * @param results The health check results.
	 * @param name The display name to find.
	 *
	 * @return The matching result.
	 */
	private static CTRL_HealthCheck.DTO_HealthCheckResult resultNamed(List<CTRL_HealthCheck.DTO_HealthCheckResult> results, String name)
	{
		for(CTRL_HealthCheck.DTO_HealthCheckResult result : results)
		{
			if(result.name == name)
			{
				return result;
			}
		}
		Assert.fail('no result named ' + name);
		return null;
	}

	/**
	 * @description Verifies the three job-runner rows come after the chain watchdog in the order the screen reads them,
	 * carry the priorities that place them around data retention, and all pass on an org that never opted in: the job
	 * runner row reads not applicable, the jobs-waiting row reads that no job waits, and the capacity row shows the
	 * slot breakdown of an org with nothing scheduled at all.
	 */
	@IsTest
	private static void theThreeJobRunnerRowsFollowTheWatchdogAndAllPassOnAnOrgWithoutARunner()
	{
		TST_Mock.register(CronTrigger.SObjectType, new List<CronTrigger>());

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		Assert.areEqual(System.Label.HealthCheck_JobRunner_CheckName, results[8].name, 'the job runner is the ninth result');
		Assert.areEqual(System.Label.HealthCheck_JobRunner_Orphaned_CheckName, results[9].name, 'then the jobs waiting for it');
		Assert.areEqual(System.Label.HealthCheck_JobRunner_Capacity_CheckName, results[10].name, 'then its capacity');
		for(Integer index = 8; index <= 10; index++)
		{
			Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, results[index].status, results[index].name + ' passes on an org that never opted in');
		}
		Assert.areEqual(System.Label.HealthCheck_JobRunner_NotApplicable, results[8].detail, 'the job runner row reads not applicable');
		Assert.areEqual(System.Label.HealthCheck_JobRunner_Orphaned_Pass, results[9].detail, 'the jobs-waiting row reads that no job waits for an inactive runner');
		Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_Capacity_Slots, new List<Object>
		{NO_SLOTS_IN_USE, NO_SLOTS_IN_USE, NO_SLOTS_IN_USE, NO_SLOTS_IN_USE}), results[10].detail,
				'the capacity row still shows the slot breakdown, of an org with nothing scheduled: ' + results[10].detail);
		Assert.areEqual(49, results[8].priority, 'the job runner row sorts just after the chain watchdog');
		Assert.areEqual(51, results[9].priority, 'the jobs waiting for it sort after data retention');
		Assert.areEqual(52, results[10].priority, 'and its capacity last of the three');
	}

	/**
	 * @description Verifies that a runner whose four records each still own a live scheduled job, and which
	 * checked five minutes ago at a fifteen-minute interval, passes with a sentence naming both the size of its complete
	 * set and the time of that last check.
	 */
	@IsTest
	private static void theJobRunnerRowPassesNamingItsCompleteSetAndTheTimeOfItsLastCheck()
	{
		seedRunnerRecords(new List<Integer> {0, 15, 30, 45}, UserInfo.getUserId(), CRON_TRIGGER_STATE_WAITING);
		backdateRunnerRecordsTo(Datetime.now().addHours(-3));
		recordLastCheck(Datetime.now().addMinutes(-5));

		CTRL_HealthCheck.DTO_HealthCheckResult jobRunner = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_JobRunner_CheckName);

		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, jobRunner.status, 'a complete set that checked five minutes ago at a fifteen-minute interval passes');
		Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_Pass,
				new List<Object> {RECORD_COUNT_AT_FIFTEEN_MINUTES, String.valueOf(lastCheckedAt())}), jobRunner.detail,
				'the detail names the four scheduled jobs and the time of the last check: ' + jobRunner.detail);
	}

	/**
	 * @description Verifies that a runner which has been running for hours but whose last check is older than one
	 * check interval warns, naming that check and the interval it is late against, and asks for Repair only if a refresh
	 * still shows the same.
	 */
	@IsTest
	private static void theJobRunnerRowWarnsWhenItsLastCheckIsOlderThanOneCheckInterval()
	{
		seedRunnerRecords(new List<Integer> {0, 15, 30, 45}, UserInfo.getUserId(), CRON_TRIGGER_STATE_WAITING);
		backdateRunnerRecordsTo(Datetime.now().addHours(-3));
		recordLastCheck(Datetime.now().addMinutes(-20));

		CTRL_HealthCheck.DTO_HealthCheckResult late = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_JobRunner_CheckName);

		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, late.status, 'a last check older than one interval warns');
		Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_Late,
				new List<Object> {String.valueOf(lastCheckedAt()), FIFTEEN_MINUTES}), late.detail,
				'the detail names the late check and the fifteen-minute schedule it is late against: ' + late.detail);
	}

	/**
	 * @description Verifies that a runner which has been running for hours and whose last check is older than two
	 * check intervals fails, naming the time of that last check so the administrator sees how long its jobs have been
	 * waiting.
	 */
	@IsTest
	private static void theJobRunnerRowFailsWhenItHasNotCheckedForTwoCheckIntervals()
	{
		seedRunnerRecords(new List<Integer> {0, 15, 30, 45}, UserInfo.getUserId(), CRON_TRIGGER_STATE_WAITING);
		backdateRunnerRecordsTo(Datetime.now().addHours(-3));
		recordLastCheck(Datetime.now().addMinutes(-40));

		CTRL_HealthCheck.DTO_HealthCheckResult stopped = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_JobRunner_CheckName);

		Assert.areEqual(CTRL_HealthCheck.STATUS_FAIL, stopped.status, 'a last check older than two intervals fails');
		Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_Stopped, new List<Object> {String.valueOf(lastCheckedAt())}), stopped.detail,
				'a runner that stopped after a check names the time of that check: ' + stopped.detail);
	}

	/**
	 * @description Verifies that a runner whose scheduled jobs belong to a user that has since been deactivated
	 * fails however recent its last check was, because those checks cannot run any more, and names the user so the
	 * administrator knows whose runner to take over.
	 */
	@IsTest
	private static void theJobRunnerRowFailsWhenTheUserItRunsAsIsInactive()
	{
		seedRunnerRecords(new List<Integer> {0, 15, 30, 45}, getInactiveActivator().Id, CRON_TRIGGER_STATE_WAITING);
		recordLastCheck(Datetime.now().addMinutes(-1));

		CTRL_HealthCheck.DTO_HealthCheckResult inactive = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_JobRunner_CheckName);

		Assert.areEqual(CTRL_HealthCheck.STATUS_FAIL, inactive.status, 'an inactive activator fails however recent the last check');
		Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_ActivatorInactive, new List<Object> {getInactiveActivator().Name}),
				inactive.detail, 'the detail names the user the runner runs as: ' + inactive.detail);
	}

	/**
	 * @description Verifies that just after a runner is activated its first check is still to come, which passes and
	 * names when that first check is due, and that once the first check is long overdue the runner reads as stopped
	 * instead.
	 */
	@IsTest
	private static void theJobRunnerRowAwaitsItsFirstCheckAfterActivationAndFailsOnceThatCheckIsOverdue()
	{
		seedRunnerRecords(new List<Integer> {0, 30}, UserInfo.getUserId(), CRON_TRIGGER_STATE_WAITING);

		CTRL_HealthCheck.DTO_HealthCheckResult awaiting = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_JobRunner_CheckName);
		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, awaiting.status, 'a runner activated a moment ago is waiting for its first check');
		Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_AwaitingFirstCheck,
				new List<Object> {String.valueOf(newestRunnerRecordCreatedDate()), THIRTY_MINUTES}), awaiting.detail,
				'the detail names when it was activated and when its first check is due: ' + awaiting.detail);

		backdateRunnerRecordsTo(Datetime.now().addHours(-2));

		CTRL_HealthCheck.DTO_HealthCheckResult overdue = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_JobRunner_CheckName);
		Assert.areEqual(CTRL_HealthCheck.STATUS_FAIL, overdue.status, 'a runner that has still not checked two hours after it was activated is stopped');
		Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_Stopped,
				new List<Object> {String.valueOf(newestRunnerRecordCreatedDate())}), overdue.detail,
				'with no check ever recorded, the detail falls back to the moment it was activated: ' + overdue.detail);
	}

	/**
	 * @description Verifies that a missing minute mark leaves the check interval the administrator chose in
	 * place, so the runner is reported as a broken set at that interval rather than as a healthy set at a wider one.
	 * Three records at 0, 15 and 45 still derive a fifteen-minute interval, which expects four records.
	 */
	@IsTest
	private static void theJobRunnerRowFailsWhenAMarkIsMissingBecauseTheDerivedCheckIntervalStaysTheChosenOne()
	{
		seedRunnerRecords(new List<Integer> {0, 15, 45}, UserInfo.getUserId(), CRON_TRIGGER_STATE_WAITING);
		recordLastCheck(Datetime.now());

		CTRL_HealthCheck.DTO_HealthCheckResult incomplete = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_JobRunner_CheckName);

		Assert.areEqual(CTRL_HealthCheck.STATUS_FAIL, incomplete.status, 'marks 0, 15 and 45 derive a fifteen-minute interval, which expects four records, not three');
		Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_Incomplete, new List<Object>
		{RECORD_COUNT_AT_FIFTEEN_MINUTES, FIFTEEN_MINUTES, RECORD_COUNT_AFTER_ONE_IS_DELETED, RECORD_COUNT_AFTER_ONE_IS_DELETED}),
				incomplete.detail, 'the detail asks for four at fifteen minutes and names the three that are left: ' + incomplete.detail);
	}

	/**
	 * @description Verifies that a job set to run on the runner while no runner is active fails the jobs-waiting row
	 * with a count of the jobs that are waiting.
	 */
	@IsTest
	private static void jobsWaitingFailsWhenJobsAreSetToRunOnARunnerThatIsNotThere()
	{
		TST_Mock.register(CronTrigger.SObjectType, new List<CronTrigger>());
		seedWaitingJob();

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult waiting = resultNamed(results, System.Label.HealthCheck_JobRunner_Orphaned_CheckName);
		Assert.areEqual(CTRL_HealthCheck.STATUS_FAIL, waiting.status, 'a waiting job with no runner fails');
		Assert.isTrue(waiting.detail.contains('1 waiting'), 'the detail counts the waiting jobs: ' + waiting.detail);
	}

	/**
	 * @description Verifies that an org which holds no runner record at all has nothing to say on the job runner
	 * row, even while jobs are waiting for a runner, because the jobs-waiting row is the one that carries that fault and
	 * the one whose remedy, Activate, is the remedy that helps.
	 */
	@IsTest
	private static void theJobRunnerRowReadsNotApplicableWhenNoRunnerRecordExistsEvenWhileAJobWaits()
	{
		TST_Mock.register(CronTrigger.SObjectType, new List<CronTrigger>());
		seedWaitingJob();

		CTRL_HealthCheck.DTO_HealthCheckResult jobRunner = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_JobRunner_CheckName);

		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, jobRunner.status, 'an org that never activated a runner has no runner fault to report');
		Assert.areEqual(System.Label.HealthCheck_JobRunner_NotApplicable, jobRunner.detail,
				'the row reads not applicable and leaves the waiting jobs to the row that can fix them: ' + jobRunner.detail);
	}

	/**
	 * @description Verifies the capacity row on an org well under the slot cap: it shows the slot breakdown of the four
	 * scheduled jobs an active fifteen-minute runner owns, and says nothing about jobs left waiting because the last
	 * check started everything that was due.
	 */
	@IsTest
	private static void theCapacityRowShowsTheSlotBreakdownWhileTheOrgIsWellUnderTheCap()
	{
		seedRunnerRecords(new List<Integer> {0, 15, 30, 45}, UserInfo.getUserId(), CRON_TRIGGER_STATE_WAITING);
		recordLastCheck(Datetime.now().addMinutes(-3));

		CTRL_HealthCheck.DTO_HealthCheckResult capacity = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_JobRunner_Capacity_CheckName);

		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, capacity.status, 'four of a hundred slots in use, and nothing left waiting');
		Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_Capacity_Slots, new List<Object>
		{RECORD_COUNT_AT_FIFTEEN_MINUTES, RECORD_COUNT_AT_FIFTEEN_MINUTES, NO_SLOTS_IN_USE, NO_SLOTS_IN_USE}), capacity.detail,
				'the detail is the slot breakdown alone, the four belonging to the runner: ' + capacity.detail);
	}

	/**
	 * @description Verifies that a row still due at the time of the last check is reported as left waiting: the capacity
	 * row warns, and its detail adds that sentence to the slot breakdown, naming the limit on how many jobs one check
	 * may start so the administrator knows which dial to turn.
	 */
	@IsTest
	private static void theCapacityRowWarnsAndNamesTheCheckLimitWhenTheLastCheckLeftDueRowsWaiting()
	{
		seedRunnerRecords(new List<Integer> {0, 15, 30, 45}, UserInfo.getUserId(), CRON_TRIGGER_STATE_WAITING);
		recordLastCheck(Datetime.now().addMinutes(-3));
		seedWaitingJob();

		CTRL_HealthCheck.DTO_HealthCheckResult capacity = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_JobRunner_Capacity_CheckName);

		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, capacity.status, 'a row still due at the time of the last check was left waiting');
		Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_Capacity_Slots, new List<Object>
		{RECORD_COUNT_AT_FIFTEEN_MINUTES, RECORD_COUNT_AT_FIFTEEN_MINUTES, NO_SLOTS_IN_USE, NO_SLOTS_IN_USE})
				+ ' ' + String.format(System.Label.HealthCheck_JobRunner_Capacity_LeftWaiting,
				new List<Object> {ONE_JOB_LEFT_WAITING, UTIL_ScheduledJobRunner.DEFAULT_CHECK_LIMIT}), capacity.detail,
				'the detail is the slot breakdown followed by the jobs the last check could not start: ' + capacity.detail);
	}

	/**
	 * @description Verifies the capacity row's two slot thresholds against the org's hundred scheduled-job slots, on an
	 * org with no job runner of its own: eighty-five in use warns that the org is close to the cap, and ninety-two fails
	 * because new schedules start failing at a hundred.
	 */
	@IsTest
	private static void theCapacityRowWarnsAtEightyFiveSlotsAndFailsAtNinetyTwo()
	{
		TST_Mock.register(CronTrigger.SObjectType, TST_Builder.of(CronTrigger.SObjectType)
				.withOverrides(new Map<SObjectField, Object> {CronTrigger.State => CRON_TRIGGER_STATE_WAITING})
				.withCount(SLOTS_IN_USE_AT_WARNING)
				.withoutInsertion(true)
				.buildList());
		CTRL_HealthCheck.DTO_HealthCheckResult close = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_JobRunner_Capacity_CheckName);
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, close.status, 'eighty-five of a hundred warns');
		Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_Capacity_SlotsWarn, new List<Object>
		{SLOTS_IN_USE_AT_WARNING, NO_SLOTS_IN_USE, NO_SLOTS_IN_USE, SLOTS_IN_USE_AT_WARNING}), close.detail,
				'the detail is the warning breakdown, every slot belonging to something else: ' + close.detail);

		TST_Mock.clear(CronTrigger.SObjectType);
		TST_Mock.register(CronTrigger.SObjectType, TST_Builder.of(CronTrigger.SObjectType)
				.withOverrides(new Map<SObjectField, Object> {CronTrigger.State => CRON_TRIGGER_STATE_WAITING})
				.withCount(SLOTS_IN_USE_AT_FAILURE)
				.withoutInsertion(true)
				.buildList());
		CTRL_HealthCheck.DTO_HealthCheckResult atTheCap = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_JobRunner_Capacity_CheckName);
		Assert.areEqual(CTRL_HealthCheck.STATUS_FAIL, atTheCap.status, 'ninety-two fails');
		Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_Capacity_SlotsFail, new List<Object>
		{SLOTS_IN_USE_AT_FAILURE, NO_SLOTS_IN_USE, NO_SLOTS_IN_USE, SLOTS_IN_USE_AT_FAILURE}), atTheCap.detail,
				'the detail is the failing breakdown: ' + atTheCap.detail);
	}

	/**
	 * @description Verifies that an org which has reached the failing slot count keeps that failure when its last check
	 * also left jobs waiting, rather than being softened to the warning the waiting jobs alone would give, and that the
	 * detail carries both sentences: the failing slot breakdown, then the jobs the last check could not start.
	 */
	@IsTest
	private static void theCapacityRowKeepsItsFailureAtTheSlotCapWhenTheLastCheckAlsoLeftJobsWaiting()
	{
		seedRunnerRecords(new List<Integer> {0, 15, 30, 45}, UserInfo.getUserId(), CRON_TRIGGER_STATE_WAITING);
		recordLastCheck(Datetime.now().addMinutes(-3));
		seedWaitingJob();
		TST_Mock.register(CronTrigger.SObjectType, TST_Builder.of(CronTrigger.SObjectType)
				.withOverrides(new Map<SObjectField, Object> {CronTrigger.State => CRON_TRIGGER_STATE_WAITING})
				.withCount(SLOTS_IN_USE_BY_OTHER_JOBS_AT_FAILURE)
				.withoutInsertion(true)
				.buildList());

		CTRL_HealthCheck.DTO_HealthCheckResult capacity = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_JobRunner_Capacity_CheckName);

		Assert.areEqual(CTRL_HealthCheck.STATUS_FAIL, capacity.status,
				'an org at the slot cap keeps its failure however many jobs the last check left waiting');
		Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_Capacity_SlotsFail, new List<Object>
		{SLOTS_IN_USE_AT_FAILURE, RECORD_COUNT_AT_FIFTEEN_MINUTES, NO_SLOTS_IN_USE, SLOTS_IN_USE_BY_OTHER_JOBS_AT_FAILURE})
				+ ' ' + String.format(System.Label.HealthCheck_JobRunner_Capacity_LeftWaiting,
				new List<Object> {ONE_JOB_LEFT_WAITING, UTIL_ScheduledJobRunner.DEFAULT_CHECK_LIMIT}), capacity.detail,
				'the detail is the failing breakdown followed by the jobs the last check could not start: ' + capacity.detail);
	}

	/**
	 * @description Verifies Activate creates one runner record per minute mark, each naming the runner's own schedulable,
	 * active, in its own mode and owning a scheduled job of its own, in the activator's time zone, and that the status it
	 * answers names the activator and the slot cost. Also checks two more things the action must do: the trigger's
	 * Health Check allowance is put back afterwards, and the runner-management lock's setting row exists. Each record's
	 * description says which minute of the hour it runs at.
	 */
	@IsTest
	private static void activateCreatesOneRunnerRecordPerMinuteMarkOwnedByTheActivator()
	{
		System.runAs(getManagingAdmin())
		{
			Test.startTest();
			CTRL_HealthCheck.DTO_JobRunnerStatus status = CTRL_HealthCheck.activateJobRunner(FIFTEEN_MINUTES);
			ScheduleSetting__c lockRow = SEL_ScheduleSetting.getScheduleSetting(UTIL_ScheduledJobRunner.LAST_CHECK_SETTING_NAME);
			Test.stopTest();

			Assert.isTrue(status.isActive, 'the runner is active');
			Assert.areEqual(FIFTEEN_MINUTES, status.checkIntervalMinutes, 'at fifteen minutes');
			Assert.areEqual(4, status.slotCost, 'costing four slots');
			Assert.areEqual(getManagingAdmin().Name, status.activatorName, 'the activator is the running user');
			Assert.isTrue(status.isActivatorActive, 'who is active');
			Assert.isFalse(TRG_ScheduleJob.allowRunnerRecordManagement, 'the trigger allowance is put back after the action');
			Assert.isNotNull(lockRow, 'Activate took the runner-management lock, which creates the setting row, read before any job the action scheduled could run');
			List<ScheduledJob__c> runners = new SEL_ScheduledJob().findRunnerRecords();
			Assert.areEqual(4, runners.size(), 'four runner records');
			Map<String, String> expectedDescriptionByName = new Map<String, String>();
			for(Integer mark = 0; mark < MINUTES_PER_HOUR; mark += FIFTEEN_MINUTES)
			{
				String name = String.format(System.Label.HealthCheck_JobRunnerRecordName, new List<Object> {String.valueOf(mark).leftPad(2, '0')});
				expectedDescriptionByName.put(name, String.format(System.Label.HealthCheck_JobRunnerRecordDescription, new List<Object> {String.valueOf(mark)}));
			}
			Set<String> names = new Set<String>();
			for(ScheduledJob__c runner : runners)
			{
				names.add(runner.SchedulerName__c);
				Assert.areEqual(UTIL_ScheduledJobRunner.RUNNER_CLASS_NAME, runner.ClassName__c, 'each names the runner class');
				Assert.isTrue(runner.IsActive__c, 'each is active');
				Assert.isNotNull(runner.ScheduledJobId__c, 'each owns a scheduled job');
				Assert.isFalse(UTIL_ScheduledJobRunner.isJobRunnerMode(runner), 'each is in its own mode');
				Assert.areEqual(UserInfo.getTimeZone().getID(), runner.Timezone__c, 'each carries the activator time zone so no minute shift applies');
				Assert.areEqual(expectedDescriptionByName.get(runner.SchedulerName__c), runner.Description__c,
						'Expected each runner record to describe itself as a regular check at its own minute of the hour');
			}
			Assert.areEqual(new Set<String> {'Job runner :00', 'Job runner :15', 'Job runner :30', 'Job runner :45'},
					names, 'named by minute mark');
		}
	}

	/**
	 * @description Verifies Repair replaces every runner record at the interval derived from the existing set, and that
	 * Deactivate then removes the set and moves a watchdog that ran on the runner back to a scheduled job of its own.
	 */
	@IsTest
	private static void repairReplacesTheSetAtTheDerivedCheckIntervalAndDeactivateRemovesItAndConvertsTheWatchdog()
	{
		TST_Mock.register(AsyncApexJob.SObjectType, new List<AsyncApexJob>());
		System.runAs(getManagingAdmin())
		{
			Test.startTest();
			CTRL_HealthCheck.activateJobRunner(THIRTY_MINUTES);
			Set<Id> firstIds = new Map<Id, ScheduledJob__c>(new SEL_ScheduledJob().findRunnerRecords()).keySet();
			CTRL_HealthCheck.scheduleChainWatchdog(RECOMMENDED_HOURLY_CRON);
			ScheduledJob__c watchdog = new SEL_ScheduledJob().findActiveByClassName(WATCHDOG_CLASS)[0];
			Assert.isTrue(UTIL_ScheduledJobRunner.isJobRunnerMode(watchdog), 'with a runner active, the watchdog runs on it');
			Assert.isNull(watchdog.ScheduledJobId__c, 'and owns no scheduled job of its own');

			CTRL_HealthCheck.DTO_JobRunnerStatus repaired = CTRL_HealthCheck.repairJobRunner();
			Assert.areEqual(THIRTY_MINUTES, repaired.checkIntervalMinutes, 'Repair keeps the derived check interval');
			Set<Id> secondIds = new Map<Id, ScheduledJob__c>(new SEL_ScheduledJob().findRunnerRecords()).keySet();
			Assert.areEqual(2, secondIds.size(), 'two records at thirty minutes');
			for(Id firstId : firstIds)
			{
				Assert.isFalse(secondIds.contains(firstId), 'Repair replaced every record: ' + firstId);
			}

			CTRL_HealthCheck.DTO_JobRunnerStatus deactivated = CTRL_HealthCheck.deactivateJobRunner();
			Test.stopTest();

			Assert.isFalse(deactivated.isActive, 'the runner is inactive');
			Assert.isTrue(new SEL_ScheduledJob().findRunnerRecords().isEmpty(), 'every runner record is gone');
			ScheduledJob__c converted = new SEL_ScheduledJob().findActiveByClassName(WATCHDOG_CLASS)[0];
			Assert.isFalse(UTIL_ScheduledJobRunner.isJobRunnerMode(converted), 'Deactivate moved the watchdog back to a scheduled job of its own');
			Assert.isNotNull(converted.ScheduledJobId__c, 'and it owns one again');
		}
	}

	/**
	 * @description Verifies that Repair restores the check interval the administrator chose rather than the wider one the
	 * surviving platform jobs imply, and that the job runner row promises exactly what Repair then does. Two of a
	 * fifteen-minute runner's four platform jobs are stopped, as an administrator deleting them from Setup would: the row
	 * asks for four records at fifteen minutes, names the two that are still live, and Repair then restores four records at
	 * every quarter of the hour, after which the row waits for the first check of the restored set.
	 */
	@IsTest
	private static void repairRestoresTheConfiguredIntervalWhenPlatformJobsAreMissingAndTheJobRunnerRowNamesIt()
	{
		TST_Mock.register(AsyncApexJob.SObjectType, new List<AsyncApexJob>());
		System.runAs(getManagingAdmin())
		{
			Test.startTest();
			CTRL_HealthCheck.activateJobRunner(FIFTEEN_MINUTES);
			for(ScheduledJob__c runner : new SEL_ScheduledJob().findRunnerRecords())
			{
				if(DELETED_PLATFORM_JOB_MINUTE_MARKS.contains(minuteMarkOf(runner)))
				{
					System.abortJob(runner.ScheduledJobId__c);
				}
			}

			CTRL_HealthCheck.DTO_HealthCheckResult broken = resultNamed(CTRL_HealthCheck.runHealthChecks(),
					System.Label.HealthCheck_JobRunner_CheckName);
			Assert.areEqual(CTRL_HealthCheck.STATUS_FAIL, broken.status, 'two of the four platform jobs are gone, so the set is incomplete');
			Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_Incomplete, new List<Object>
			{RECORD_COUNT_AT_FIFTEEN_MINUTES, FIFTEEN_MINUTES, RECORD_COUNT_AT_FIFTEEN_MINUTES, SURVIVING_PLATFORM_JOB_COUNT}), broken.detail,
					'the reading comes from the records, so it asks for four at fifteen minutes and names the two still live: ' + broken.detail);

			CTRL_HealthCheck.DTO_JobRunnerStatus repaired = CTRL_HealthCheck.repairJobRunner();
			Assert.areEqual(FIFTEEN_MINUTES, repaired.checkIntervalMinutes, 'Repair restores the interval the administrator chose, not the one the survivors imply');
			List<ScheduledJob__c> restoredRecords = new SEL_ScheduledJob().findRunnerRecords();
			Assert.areEqual(RECORD_COUNT_AT_FIFTEEN_MINUTES, restoredRecords.size(), 'four records again');
			Set<Integer> restoredMinuteMarks = new Set<Integer>();
			for(ScheduledJob__c runner : restoredRecords)
			{
				restoredMinuteMarks.add(minuteMarkOf(runner));
			}
			Assert.areEqual(FIFTEEN_MINUTE_MARKS, restoredMinuteMarks, 'one at every quarter of the hour');

			CTRL_HealthCheck.DTO_HealthCheckResult intact = resultNamed(CTRL_HealthCheck.runHealthChecks(),
					System.Label.HealthCheck_JobRunner_CheckName);
			Test.stopTest();

			Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, intact.status, 'the repaired set reads as complete');
			Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_AwaitingFirstCheck,
					new List<Object> {String.valueOf(newestRunnerRecordCreatedDate()), FIFTEEN_MINUTES}), intact.detail,
					'and the restored set is now waiting for its first check, due within the interval it keeps: ' + intact.detail);
		}
	}

	/**
	 * @description Verifies that a failure which is not a refusal still reaches the client in words it can act on: with the
	 * runner-record query answering a record the platform has never seen, the delete that Deactivate runs fails, and the action
	 * carries the platform's own message out as an AuraHandledException rather than letting the raw failure escape as a
	 * generic error.
	 */
	@IsTest
	private static void deactivateCarriesAPlatformFailureToTheClientInThePlatformsOwnWords()
	{
		System.runAs(getManagingAdmin())
		{
			ScheduledJob__c neverSeenRecord = (ScheduledJob__c)TST_Builder.of(ScheduledJob__c.SObjectType)
					.withOverride(ScheduledJob__c.Id, UTIL_Random.randomId(ScheduledJob__c.SObjectType))
					.withOverride(ScheduledJob__c.ClassName__c, UTIL_ScheduledJobRunner.RUNNER_CLASS_NAME)
					.withOverride(ScheduledJob__c.CronExpression__c, RECOMMENDED_HOURLY_CRON)
					.withOverride(ScheduledJob__c.IsActive__c, true)
					.withoutInsertion()
					.build();
			TST_Mock.register(ScheduledJob__c.SObjectType, neverSeenRecord);

			try
			{
				CTRL_HealthCheck.deactivateJobRunner();
				Assert.fail('deleting a record the platform has never seen must fail');
			}
			catch(AuraHandledException surfaced)
			{
				Assert.isTrue(String.isNotBlank(surfaced.getMessage()), 'the client is handed words, not an empty message');
				Assert.areNotEqual(System.Label.HealthCheck_JobRunner_PermissionRequired, surfaced.getMessage(),
						'the administrator holds the permission, so this is not the refusal text: ' + surfaced.getMessage());
				Assert.isTrue(surfaced.getMessage().contains(PLATFORM_DELETE_FAILURE_FRAGMENT),
						'the platform\'s own words for the failed delete reach the client: ' + surfaced.getMessage());
				Assert.isTrue(surfaced.getMessage().contains(String.valueOf(neverSeenRecord.Id)),
						'and they name the record the delete could not find: ' + surfaced.getMessage());
			}
		}
	}

	/**
	 * @description Verifies the refusals the actions owe: Repair with nothing to derive an interval from asks for one,
	 * Activate turns down an interval that does not divide the hour, and all three actions refuse an administrator who
	 * does not hold the Manage Job Runner permission, leaving an activated runner's records exactly as they were.
	 */
	@IsTest
	private static void repairWithNoRunnerRecordsAsksForACheckIntervalAndActionsRefuseWithoutThePermissionOrWithABadInterval()
	{
		System.runAs(getManagingAdmin())
		{
			try
			{
				CTRL_HealthCheck.repairJobRunner();
				Assert.fail('Repair with nothing to derive from must ask for a check interval');
			}
			catch(AuraHandledException asked)
			{
				Assert.areEqual(System.Label.HealthCheck_JobRunner_RepairNeedsCheckFrequency, asked.getMessage(), 'the message is the label');
			}
			try
			{
				CTRL_HealthCheck.activateJobRunner(UNSUPPORTED_CHECK_INTERVAL_MINUTES);
				Assert.fail('seven minutes is not a check interval the runner offers');
			}
			catch(AuraHandledException refused)
			{
				Assert.areEqual(System.Label.HealthCheck_JobRunner_InvalidCheckFrequency, refused.getMessage(), 'the message is the label');
			}
		}
		seedRunnerRecords(new List<Integer> {0, 15, 30, 45}, UserInfo.getUserId(), CRON_TRIGGER_STATE_WAITING);
		Set<Id> recordsBeforeTheRefusals = new Map<Id, ScheduledJob__c>(new SEL_ScheduledJob().findRunnerRecords()).keySet();

		System.runAs(getPlainAdmin())
		{
			try
			{
				CTRL_HealthCheck.activateJobRunner(FIFTEEN_MINUTES);
				Assert.fail('Activate needs the Manage Job Runner permission');
			}
			catch(AuraHandledException refused)
			{
				Assert.areEqual(System.Label.HealthCheck_JobRunner_PermissionRequired, refused.getMessage(), 'Activate refuses with the label');
			}
			try
			{
				CTRL_HealthCheck.repairJobRunner();
				Assert.fail('Repair needs the Manage Job Runner permission');
			}
			catch(AuraHandledException refused)
			{
				Assert.areEqual(System.Label.HealthCheck_JobRunner_PermissionRequired, refused.getMessage(), 'Repair refuses with the label');
			}
			try
			{
				CTRL_HealthCheck.deactivateJobRunner();
				Assert.fail('Deactivate needs the Manage Job Runner permission');
			}
			catch(AuraHandledException refused)
			{
				Assert.areEqual(System.Label.HealthCheck_JobRunner_PermissionRequired, refused.getMessage(), 'Deactivate refuses with the label');
			}
			Assert.areEqual(recordsBeforeTheRefusals, new Map<Id, ScheduledJob__c>(new SEL_ScheduledJob().findRunnerRecords()).keySet(),
					'the three refusals changed nothing: no record created, none replaced by Repair and none deleted by Deactivate');
		}
	}

	/**
	 * @description Verifies the two cases in which the one-click watchdog schedule takes a scheduled job of its own
	 * rather than running on the runner: no runner is active, exactly as before the runner existed; and a runner is active
	 * but the administrator pressing the button does not hold the Manage Job Runner permission, which is what setting a
	 * record to run on the runner requires, so the watchdog keeps a scheduled job of its own and still sweeps.
	 */
	@IsTest
	private static void theWatchdogTakesItsOwnSlotWhenNoRunnerIsActiveOrThePresserLacksThePermission()
	{
		TST_Mock.register(AsyncApexJob.SObjectType, new List<AsyncApexJob>());

		Test.startTest();
		ScheduledJob__c ownSlot;
		System.runAs(getManagingAdmin())
		{
			CTRL_HealthCheck.scheduleChainWatchdog(RECOMMENDED_HOURLY_CRON);
			ownSlot = new SEL_ScheduledJob().findActiveByClassName(WATCHDOG_CLASS)[0];
			Assert.isFalse(UTIL_ScheduledJobRunner.isJobRunnerMode(ownSlot), 'no runner, its own scheduled job');
			Assert.isNotNull(ownSlot.ScheduledJobId__c, 'which it owns');
		}

		DML_Builder.newTransaction().systemModeInternal().doDelete(ownSlot).execute();
		seedRunnerRecords(new List<Integer> {0, 15, 30, 45}, UserInfo.getUserId(), CRON_TRIGGER_STATE_WAITING);

		System.runAs(getPlainAdmin())
		{
			CTRL_HealthCheck.scheduleChainWatchdog(RECOMMENDED_HOURLY_CRON);
			ScheduledJob__c pressedWithoutThePermission = new SEL_ScheduledJob().findActiveByClassName(WATCHDOG_CLASS)[0];
			Assert.isFalse(UTIL_ScheduledJobRunner.isJobRunnerMode(pressedWithoutThePermission),
					'a runner is active, but an administrator without the Manage Job Runner permission cannot put a record on it');
			Assert.isNotNull(pressedWithoutThePermission.ScheduledJobId__c, 'so the watchdog takes a scheduled job of its own instead');
		}
		Test.stopTest();
	}

	/**
	 * @description Verifies that a watchdog set to run on the job runner counts as scheduled only while a runner is
	 * active: with no runner it is a watchdog that can never sweep, so the chain-watchdog dimension warns, and once a
	 * runner is active the same record passes.
	 */
	@IsTest
	private static void aRunnerModeWatchdogCountsAsScheduledOnlyWhileARunnerIsActive()
	{
		TST_Mock.register(AsyncApexJob.SObjectType, new List<AsyncApexJob>());
		seedWatchdogRidingTheRunner();
		TST_Mock.register(CronTrigger.SObjectType, new List<CronTrigger>());

		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN,
				resultNamed(CTRL_HealthCheck.runHealthChecks(), System.Label.HealthCheck_ChainWatchdog_CheckName).status,
				'a watchdog waiting on an inactive runner is not a scheduled watchdog');

		seedRunnerRecords(new List<Integer> {0, 30}, UserInfo.getUserId(), CRON_TRIGGER_STATE_WAITING);
		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS,
				resultNamed(CTRL_HealthCheck.runHealthChecks(), System.Label.HealthCheck_ChainWatchdog_CheckName).status,
				'with a runner active it counts');
	}

	/**
	 * @description Verifies the chain-watchdog row reads its slot cost from the watchdog that is scheduled rather than
	 * from the job runner: a watchdog left on a scheduled job of its own, which is what an upgrade leaves behind, still
	 * holds one of the org's hundred slots while a runner is active, and the row says so.
	 */
	@IsTest
	private static void theWatchdogRowSaysItKeepsItsOwnSlotWhileARunnerIsActive()
	{
		TST_Mock.register(AsyncApexJob.SObjectType, new List<AsyncApexJob>());
		seedRunnerRecords(new List<Integer> {0, 15, 30, 45}, UserInfo.getUserId(), CRON_TRIGGER_STATE_WAITING);
		seedWatchdogOnItsOwnScheduledJob();

		CTRL_HealthCheck.DTO_HealthCheckResult watchdogRow = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_ChainWatchdog_CheckName);

		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, watchdogRow.status, 'a watchdog on a scheduled job of its own is a scheduled watchdog');
		Assert.areEqual(System.Label.HealthCheck_ChainWatchdog_Configured + UTIL_String.SPACE + System.Label.HealthCheck_ChainWatchdog_SlotCostOwnSlot,
				watchdogRow.detail, 'and it costs a slot of its own however the job runner stands: ' + watchdogRow.detail);
	}

	/**
	 * @description Verifies the one-click schedule moves a watchdog that ran on a job runner which has since stopped
	 * back to a scheduled job of its own, rather than leaving it in place and creating a second watchdog beside it: one
	 * watchdog record is left, it runs on a scheduled job it owns, and the action answers that record.
	 */
	@IsTest
	private static void schedulingTheWatchdogMovesTheOneRidingADeadRunnerBackToItsOwnScheduledJob()
	{
		TST_Mock.register(AsyncApexJob.SObjectType, new List<AsyncApexJob>());
		TST_Mock.register(CronTrigger.SObjectType, new List<CronTrigger>());
		seedWatchdogRidingTheRunner();

		Test.startTest();
		Id scheduledJobId = CTRL_HealthCheck.scheduleChainWatchdog(RECOMMENDED_HOURLY_CRON);
		Test.stopTest();

		List<ScheduledJob__c> watchdogs = new SEL_ScheduledJob().findActiveByClassName(WATCHDOG_CLASS);
		Assert.areEqual(1, watchdogs.size(), 'the watchdog waiting on the dead runner is moved, not joined by a second watchdog');
		Assert.areEqual(watchdogs[0].Id, scheduledJobId, 'and the action answers the record it moved');
		Assert.isFalse(UTIL_ScheduledJobRunner.isJobRunnerMode(watchdogs[0]), 'the watchdog now runs on a scheduled job of its own');
		Assert.isNotNull(watchdogs[0].ScheduledJobId__c, 'which it owns, so the sweep runs again');
	}

	/**
	 * @description Verifies that a runner repaired after it stopped is read as waiting for its first check again, rather
	 * than as still stopped at the check that came before the repair: with the last check three hours old and the
	 * records created a moment ago the job runner row passes, and once those records are two hours old it fails again.
	 */
	@IsTest
	private static void theJobRunnerRowAwaitsItsFirstCheckAgainWhenItWasActivatedAfterThatCheck()
	{
		seedRunnerRecords(new List<Integer> {0, 15, 30, 45}, UserInfo.getUserId(), CRON_TRIGGER_STATE_WAITING);
		recordLastCheck(Datetime.now().addHours(-3));

		CTRL_HealthCheck.DTO_HealthCheckResult awaiting = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_JobRunner_CheckName);

		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, awaiting.status, 'a runner whose records were created after the last check is waiting for its first check again');
		Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_AwaitingFirstCheck,
				new List<Object> {String.valueOf(newestRunnerRecordCreatedDate()), FIFTEEN_MINUTES}), awaiting.detail,
				'and the detail names the moment it was activated, not the older check: ' + awaiting.detail);

		backdateRunnerRecordsTo(Datetime.now().addHours(-2));

		CTRL_HealthCheck.DTO_HealthCheckResult stopped = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_JobRunner_CheckName);

		Assert.areEqual(CTRL_HealthCheck.STATUS_FAIL, stopped.status, 'a runner that has still not checked two hours after it was activated is stopped again');
	}

	/**
	 * @description Verifies that a runner whose every platform job was deleted from Setup reports its broken set rather
	 * than excusing itself as not applicable: the four records are still there, none of them owns a scheduled job that
	 * will fire, and the job runner row fails naming the four on record and the none still live.
	 */
	@IsTest
	private static void theJobRunnerRowFailsWhenEveryPlatformJobIsGoneRatherThanReadingAsNotApplicable()
	{
		seedRunnerRecords(new List<Integer> {0, 15, 30, 45}, UserInfo.getUserId(), CRON_TRIGGER_STATE_WAITING);
		TST_Mock.clear(CronTrigger.SObjectType);
		TST_Mock.register(CronTrigger.SObjectType, new List<CronTrigger>());

		CTRL_HealthCheck.DTO_HealthCheckResult incomplete = resultNamed(CTRL_HealthCheck.runHealthChecks(),
				System.Label.HealthCheck_JobRunner_CheckName);

		Assert.areEqual(CTRL_HealthCheck.STATUS_FAIL, incomplete.status,
				'four records with no scheduled job left to fire is a broken set, not an org that never opted in');
		Assert.areEqual(String.format(System.Label.HealthCheck_JobRunner_Incomplete, new List<Object>
		{RECORD_COUNT_AT_FIFTEEN_MINUTES, FIFTEEN_MINUTES, RECORD_COUNT_AT_FIFTEEN_MINUTES, NO_PLATFORM_JOBS_LEFT}), incomplete.detail,
				'the detail asks for four at fifteen minutes and names the four on record and none live: ' + incomplete.detail);
	}

	/**
	 * @description When the runner last completed a check for due jobs, read back from the row the runner writes it to,
	 * which is the time the job runner row names in its pass, late and stopped sentences.
	 *
	 * @return The time of the last completed check.
	 */
	private static Datetime lastCheckedAt()
	{
		return SEL_ScheduleSetting.getScheduleSetting(UTIL_ScheduledJobRunner.LAST_CHECK_SETTING_NAME).LastSuccessfulRunTime__c;
	}

	/**
	 * @description The creation time of the newest runner record, which is when the runner was last activated or
	 * repaired and what the job runner row names while the first check after that is still to come.
	 *
	 * @return The newest runner record's creation time.
	 */
	private static Datetime newestRunnerRecordCreatedDate()
	{
		Datetime activatedAt;
		for(ScheduledJob__c runner : new SEL_ScheduledJob().findRunnerRecords())
		{
			if(activatedAt == null || runner.CreatedDate > activatedAt)
			{
				activatedAt = runner.CreatedDate;
			}
		}
		return activatedAt;
	}

	/**
	 * @description Verifies that the selected API mocking row is the last row and passes when no active API Setting has
	 * Mocking Enabled ticked and both flags that mock every service are off for the viewer. The settings read finds no
	 * records, so the org's own settings cannot change the answer. The row has no action button, because the page would
	 * open the wrong dialog for it.
	 */
	@IsTest
	private static void shouldPassSelectedApiMockingWhenNoSettingHasMockingEnabled()
	{
		registerMockingFlags(false, false, false);
		TST_Mock.registerNext(ApiSetting__mdt.SObjectType, new List<SObject>());

		CTRL_HealthCheck.DTO_HealthCheckResult mocking = CTRL_HealthCheck.runHealthChecks()[SELECTED_API_MOCKING_POSITION];

		Assert.areEqual(System.Label.HealthCheck_SelectedApiMocking_CheckName, mocking.name, 'Expected the selected API mocking row last');
		Assert.areEqual(SELECTED_API_MOCKING_PRIORITY, mocking.priority, 'Expected the row to sort just after the job-runner capacity row');
		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, mocking.status, 'Expected a pass when no setting is ticked and no mock-all flag is on');
		Assert.areEqual(System.Label.HealthCheck_SelectedApiMocking_NoneTicked, mocking.detail, 'Expected the detail to say no setting is ticked');
		Assert.isNull(mocking.actionLabel, 'Expected no action button on the row');
	}

	/**
	 * @description Verifies that the row warns, and names the ticked settings in label order, when the Mock Selected APIs
	 * flag is off for the viewer: for the viewer those services call the real system. The flag is registered as off, so
	 * the flag record deployed in the org cannot change the answer.
	 */
	@IsTest
	private static void shouldWarnThatTickedServicesCallTheRealSystemWhenTheFlagIsOffForTheViewer()
	{
		registerMockingFlags(false, false, false);
		registerTickedSettings();

		CTRL_HealthCheck.DTO_HealthCheckResult mocking = runSelectedApiMockingCheck();

		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, mocking.status, 'Expected a warning when a setting is ticked');
		Assert.areEqual(String.format(System.Label.HealthCheck_SelectedApiMocking_FlagOffForYou, new List<Object> {joinTickedSettingLabels()}),
				mocking.detail, 'Expected the flag-off sentence with both labels in label order, got ' + mocking.detail);
		Assert.isNull(mocking.actionLabel, 'Expected no action button on the row');
	}

	/**
	 * @description Verifies that the row warns, and names the ticked settings in label order, when the Mock Selected APIs
	 * flag is on for the viewer: for the viewer those services answer from mock data.
	 */
	@IsTest
	private static void shouldWarnThatTickedServicesAnswerMockDataWhenTheFlagIsOnForTheViewer()
	{
		registerMockingFlags(true, false, false);
		registerTickedSettings();

		CTRL_HealthCheck.DTO_HealthCheckResult mocking = runSelectedApiMockingCheck();

		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, mocking.status, 'Expected a warning when a setting is ticked');
		Assert.areEqual(String.format(System.Label.HealthCheck_SelectedApiMocking_FlagOnForYou, new List<Object> {joinTickedSettingLabels()}),
				mocking.detail, 'Expected the flag-on sentence with both labels in label order, got ' + mocking.detail);
		Assert.isNull(mocking.actionLabel, 'Expected no action button on the row');
	}

	/**
	 * @description Verifies that the row warns when the Mock All APIs flag is on for the viewer, even with no setting
	 * ticked: for the viewer every outgoing service answers from mock data.
	 */
	@IsTest
	private static void shouldWarnThatEveryOutgoingServiceAnswersMockDataWhenMockAllApisIsOnForTheViewer()
	{
		registerMockingFlags(false, true, false);
		TST_Mock.registerNext(ApiSetting__mdt.SObjectType, new List<SObject>());

		CTRL_HealthCheck.DTO_HealthCheckResult mocking = runSelectedApiMockingCheck();

		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, mocking.status, 'Expected a warning when Mock All APIs is on for the viewer');
		Assert.areEqual(System.Label.HealthCheck_SelectedApiMocking_MockAllApisOnForYou, mocking.detail,
				'Expected only the Mock All APIs sentence, got ' + mocking.detail);
		Assert.isNull(mocking.actionLabel, 'Expected no action button on the row');
	}

	/**
	 * @description Verifies that the row warns when the Mock All Inbound APIs flag is on for the viewer, even with no
	 * setting ticked: every incoming service answers mock data to requests signed in as the viewer.
	 */
	@IsTest
	private static void shouldWarnThatEveryIncomingServiceAnswersMockDataWhenMockAllInboundApisIsOnForTheViewer()
	{
		registerMockingFlags(false, false, true);
		TST_Mock.registerNext(ApiSetting__mdt.SObjectType, new List<SObject>());

		CTRL_HealthCheck.DTO_HealthCheckResult mocking = runSelectedApiMockingCheck();

		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, mocking.status, 'Expected a warning when Mock All Inbound APIs is on for the viewer');
		Assert.areEqual(System.Label.HealthCheck_SelectedApiMocking_MockAllInboundApisOnForYou, mocking.detail,
				'Expected only the Mock All Inbound APIs sentence, got ' + mocking.detail);
		Assert.isNull(mocking.actionLabel, 'Expected no action button on the row');
	}

	/**
	 * @description Verifies that, with settings ticked and Mock Selected APIs off for the viewer, the row does not say the
	 * services call the real system when Mock All APIs is on for the viewer. It says the box alone does not mock them, then
	 * adds the Mock All APIs sentence.
	 */
	@IsTest
	private static void shouldSayTheBoxDoesNotMockTickedServicesWhenOnlyMockAllApisIsOnForTheViewer()
	{
		registerMockingFlags(false, true, false);
		registerTickedSettings();

		CTRL_HealthCheck.DTO_HealthCheckResult mocking = runSelectedApiMockingCheck();

		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, mocking.status, 'Expected a warning when a setting is ticked');
		Assert.areEqual(String.format(System.Label.HealthCheck_SelectedApiMocking_FlagOffForYouWithMockAll, new List<Object> {joinTickedSettingLabels()})
				+ UTIL_String.SPACE + System.Label.HealthCheck_SelectedApiMocking_MockAllApisOnForYou,
				mocking.detail, 'Expected the box sentence then the Mock All APIs sentence, got ' + mocking.detail);
		Assert.isNull(mocking.actionLabel, 'Expected no action button on the row');
	}

	/**
	 * @description Verifies that, with settings ticked and Mock Selected APIs off for the viewer, the detail lists the box
	 * sentence, the Mock All APIs sentence and the Mock All Inbound APIs sentence in that order, joined by a space.
	 */
	@IsTest
	private static void shouldListEverySentenceInOrderWhenBothMockAllFlagsAreOnForTheViewer()
	{
		registerMockingFlags(false, true, true);
		registerTickedSettings();

		CTRL_HealthCheck.DTO_HealthCheckResult mocking = runSelectedApiMockingCheck();

		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, mocking.status, 'Expected a warning when a setting is ticked');
		Assert.areEqual(String.format(System.Label.HealthCheck_SelectedApiMocking_FlagOffForYouWithMockAll, new List<Object> {joinTickedSettingLabels()})
				+ UTIL_String.SPACE + System.Label.HealthCheck_SelectedApiMocking_MockAllApisOnForYou
				+ UTIL_String.SPACE + System.Label.HealthCheck_SelectedApiMocking_MockAllInboundApisOnForYou,
				mocking.detail, 'Expected the three sentences in order, got ' + mocking.detail);
		Assert.isNull(mocking.actionLabel, 'Expected no action button on the row');
	}

	/**
	 * @description Registers the three mocking flags the selected API mocking row reads, each on or off for the user
	 * running the test. Every flag is registered, so the flag records deployed in the org cannot change the answer.
	 *
	 * @param isMockSelectedApisOn Whether Mock Selected APIs is on.
	 * @param isMockAllApisOn Whether Mock All APIs is on.
	 * @param isMockAllInboundApisOn Whether Mock All Inbound APIs is on.
	 */
	private static void registerMockingFlags(Boolean isMockSelectedApisOn, Boolean isMockAllApisOn, Boolean isMockAllInboundApisOn)
	{
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_SELECTED_APIS, true, isMockSelectedApisOn);
		TST_Factory.newFeatureFlag(API_Base.FLAG_MOCK_ALL_APIS, true, isMockAllApisOn);
		TST_Factory.newFeatureFlag(API_Inbound.FLAG_MOCK_ALL_INBOUND_APIS, true, isMockAllInboundApisOn);
	}

	/**
	 * @description Registers two active API Settings with Mocking Enabled ticked, the second label first, so only a
	 * sorted read names them in label order.
	 */
	private static void registerTickedSettings()
	{
		String className = CTRL_HealthCheck_TEST.class.getName();
		TST_Factory.newOutboundApiSetting(className, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MasterLabel => SECOND_TICKED_SETTING_LABEL, ApiSetting__mdt.MockingEnabled__c => true
		});
		TST_Factory.newOutboundApiSetting(className, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MasterLabel => FIRST_TICKED_SETTING_LABEL, ApiSetting__mdt.MockingEnabled__c => true
		});
	}

	/**
	 * @description The labels of the two ticked settings as the row writes them: in label order, joined by a comma.
	 *
	 * @return The joined labels.
	 */
	private static String joinTickedSettingLabels()
	{
		return FIRST_TICKED_SETTING_LABEL + SETTING_LABEL_SEPARATOR + SECOND_TICKED_SETTING_LABEL;
	}

	/**
	 * @description Runs every health check and returns the selected API mocking row.
	 *
	 * @return The selected API mocking row.
	 */
	private static CTRL_HealthCheck.DTO_HealthCheckResult runSelectedApiMockingCheck()
	{
		return resultNamed(CTRL_HealthCheck.runHealthChecks(), System.Label.HealthCheck_SelectedApiMocking_CheckName);
	}

	/**
	 * @description Calls the Health Check controller the way the Health Check page does: with the running user's record
	 * sharing applied. This test class declares no sharing, so a call made straight from a test method does not apply
	 * record sharing the way the page does.
	 */
	private with sharing class SharingEnforcedCaller
	{
		/**
		 * @description Runs every health check, as the Health Check page does when it opens.
		 *
		 * @return The result of each check
		 */
		public List<CTRL_HealthCheck.DTO_HealthCheckResult> runHealthChecks()
		{
			return CTRL_HealthCheck.runHealthChecks();
		}
	}
}