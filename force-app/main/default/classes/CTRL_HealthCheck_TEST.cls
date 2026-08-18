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
 * @date February 2026, August 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.EagerlyLoadedDescribeSObjectResult,PMD.CyclomaticComplexity')
@IsTest(SeeAllData=false IsParallel=true)
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
	 * @description A live AsyncApexJob status — a scheduled-Apex registration waits in Queued.
	 */
	private static final String LIVE_SCHEDULED_APEX_STATUS = 'Queued';

	/**
	 * @description Verifies that runHealthChecks returns results for all checks.
	 */
	@IsTest
	private static void shouldReturnAllHealthCheckResults()
	{
		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		Assert.areEqual(9, results.size(), 'Expected nine health check results');
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

		CTRL_HealthCheck.DTO_HealthCheckResult coverageResult = results[6];
		Assert.areEqual(System.Label.HealthCheck_CustomObjectCoverage_CheckName, coverageResult.name, 'the seventh check is custom-object coverage');
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, coverageResult.status, 'an uncovered sensitive custom object warns');
		Assert.isTrue(coverageResult.detail.contains(apiCallObjectName), 'the warning names the uncovered object');
		Assert.areEqual(System.Label.HealthCheck_ReviewMasking_ActionLabel, coverageResult.actionLabel, 'the action deep-links to the advisor');
	}

	/**
	 * @description Verifies the warn detail joins multiple uncovered object names with a comma AND a space —
	 * not a bare comma — so the list reads cleanly. One object is sensitive (a classified field) and the other
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

		CTRL_HealthCheck.DTO_HealthCheckResult coverageResult = results[6];
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

		CTRL_HealthCheck.DTO_HealthCheckResult coverageResult = results[6];
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

		CTRL_HealthCheck.DTO_HealthCheckResult coverageResult = results[6];
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

		CTRL_HealthCheck.DTO_HealthCheckResult coverageResult = results[6];
		String expectedUncheckedSuffix = String.format(System.Label.HealthCheck_CustomObjectCoverage_Unchecked, new List<Object> {2});
		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, coverageResult.status, 'covered objects pass even with unchecked candidates');
		Assert.isTrue(coverageResult.detail.contains(expectedUncheckedSuffix), 'a bounded pass reports what it did not check');
	}

	/**
	 * @description Builds an in-memory EntityDefinition row (no namespace prefix) for the
	 * selectable-objects seam the coverage sweep reads.
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
	 * @description Verifies that the Trusted Site check fails when no matching CSP Trusted Site exists.
	 */
	@IsTest
	private static void shouldFailWhenTrustedSiteMissing()
	{
		TST_Mock.register(CspTrustedSite.SObjectType, new List<CspTrustedSite>());

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult trustedSiteResult = results[2];
		Assert.areEqual(CTRL_HealthCheck.CHECK_TRUSTED_SITE, trustedSiteResult.name, 'Third result should be Trusted Site');
		Assert.areEqual(CTRL_HealthCheck.STATUS_FAIL, trustedSiteResult.status, 'Trusted site check should fail without configuration');
		Assert.areEqual(30, trustedSiteResult.priority, 'Trusted Site should have priority 30');
	}

	/**
	 * @description Verifies that the Trusted Site check passes when a matching CSP Trusted Site is configured.
	 */
	@IsTest
	private static void shouldPassWhenTrustedSiteConfigured()
	{
		TST_Mock.of(CspTrustedSite.SObjectType).build();

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult trustedSiteResult = results[2];
		Assert.areEqual(CTRL_HealthCheck.CHECK_TRUSTED_SITE, trustedSiteResult.name, 'Third result should be Trusted Site');
		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, trustedSiteResult.status, 'Trusted site check should pass');
		Assert.areEqual(30, trustedSiteResult.priority, 'Trusted Site should have priority 30 when passing');
	}

	/**
	 * @description Verifies that the trusted-site probe — a framework-internal read of CSP setup
	 * configuration — emits no sharing BYPASS audit entry. The probe routes through
	 * `bypassSharingInternal()`, which must stay silent so each health-check run does not pollute
	 * the `BypassEvent` forensic trail.
	 *
	 * @see CTRL_HealthCheck.isTrustedSiteConfigured
	 * @see QRY_Builder.Builder.bypassSharingInternal
	 */
	@IsTest
	private static void shouldNotEmitBypassAuditWhenCheckingTrustedSite()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		TST_Mock.register(CspTrustedSite.SObjectType, new List<CspTrustedSite>());

		Test.startTest();
		CTRL_HealthCheck.isTrustedSiteConfigured();
		Test.stopTest();

		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			String target = (String)(context?.get(UTIL_BypassAudit.CONTEXT_TARGET));
			Assert.isFalse
					(
							target != null && target.startsWith('sharing'),
							'The trusted-site probe must not emit a sharing BYPASS audit entry'
					);
		}
	}

	/**
	 * @description Verifies that the Class Type Resolver check warns when no ClassTypeResolver__mdt records exist.
	 */
	@IsTest
	private static void shouldWarnWhenNoClassTypeResolverRecordsExist()
	{
		TST_Mock.register(ClassTypeResolver__mdt.SObjectType, new List<ClassTypeResolver__mdt>());

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult resolverResult = results[3];
		Assert.areEqual(CTRL_HealthCheck.CHECK_CLASS_TYPE_RESOLVER, resolverResult.name, 'Fourth result should be Class Type Resolver');
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

		CTRL_HealthCheck.DTO_HealthCheckResult resolverResult = results[3];
		Assert.areEqual(CTRL_HealthCheck.CHECK_CLASS_TYPE_RESOLVER, resolverResult.name, 'Fourth result should be Class Type Resolver');
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

		CTRL_HealthCheck.DTO_HealthCheckResult resolverResult = results[3];
		Assert.areEqual(CTRL_HealthCheck.CHECK_CLASS_TYPE_RESOLVER, resolverResult.name, 'Fourth result should be Class Type Resolver');
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

		CTRL_HealthCheck.DTO_HealthCheckResult resolverResult = results[3];
		Assert.areEqual(CTRL_HealthCheck.CHECK_CLASS_TYPE_RESOLVER, resolverResult.name, 'Fourth result should be Class Type Resolver');
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

		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = results[4];
		Assert.areEqual(CTRL_HealthCheck.CHECK_DATA_RETENTION, retentionResult.name, 'Fifth result should be Data Retention');
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

		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = results[4];
		Assert.areEqual(CTRL_HealthCheck.CHECK_DATA_RETENTION, retentionResult.name, 'Fifth result should be Data Retention');
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

		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = results[4];
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, retentionResult.status, 'Should warn for unconfigured objects');
		Assert.isFalse(retentionResult.detail.contains(LogEntry__c.SObjectType.getDescribe().getLabel()), 'Should not list Log Entry which has a purge job');
		Assert.isTrue(retentionResult.detail.contains(ApiCall__c.SObjectType.getDescribe().getLabel()), 'Should list unconfigured API Call');
		Assert.areEqual(3, retentionResult.recordCounts.size(), 'Should include counts for three unconfigured objects');
		Assert.areEqual(50, retentionResult.priority, 'Data Retention should have priority 50 when partially configured');
	}

	/**
	 * @description Verifies that jobs for non-purge classes are ignored in the retention check.
	 */
	@IsTest
	private static void shouldIgnoreNonPurgeScheduledJobs()
	{
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>
		{
				TST_Factory.newScheduledJob('SCHED_ProcessLoginHistory', new DTO_NameValues(new Map<String, String> {PARAM_OBJECT_NAME => LogEntry__c.SObjectType.getDescribe().name}))
		});

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		CTRL_HealthCheck.DTO_HealthCheckResult retentionResult = results[4];
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

		CTRL_HealthCheck.DTO_HealthCheckResult maskingResult = results[5];
		Assert.areEqual(CTRL_HealthCheck.CHECK_MASKING_POSTURE, maskingResult.name, 'Sixth result should be Data Masking');
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

		CTRL_HealthCheck.DTO_HealthCheckResult maskingResult = results[5];
		Assert.areEqual(CTRL_HealthCheck.CHECK_MASKING_POSTURE, maskingResult.name, 'Sixth result should be Data Masking');
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

		CTRL_HealthCheck.DTO_HealthCheckResult maskingResult = results[5];
		Assert.areEqual(CTRL_HealthCheck.CHECK_MASKING_POSTURE, maskingResult.name, 'Sixth result should be Data Masking');
		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, maskingResult.status, 'Should pass when masking is active and healthy');
		Assert.areEqual(String.format(CTRL_HealthCheck.DETAIL_MASKING_POSTURE_HEALTHY, new List<Object> {1}), maskingResult.detail, 'Detail should report the one masked object');
		Assert.isNull(maskingResult.actionLabel, 'A passing masking result should carry no action');
		Assert.areEqual(45, maskingResult.priority, 'Data Masking should have priority 45');
	}

	/**
	 * @description Verifies the chain-abort check warns when the gating flag is active but nobody holds the
	 * grant set. Seeds an empty PermissionSetAssignment mock so the probe never reads the org's ambient
	 * assignments (this class is IsParallel=true and a live smoke may have granted the dev user), and an
	 * empty SetupEntityAccess mock so install-written profile grants, visible regardless of test-data
	 * isolation, cannot divert the check to the broad-grant warning.
	 */
	@IsTest
	private static void shouldWarnWhenAbortHasNoAssignees()
	{
		TST_Mock.register(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment>());
		TST_Mock.register(SetupEntityAccess.SObjectType, new List<SetupEntityAccess>());

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();
		CTRL_HealthCheck.DTO_HealthCheckResult abortResult = results[7];

		Assert.areEqual(System.Label.HealthCheck_AsyncChainAbort_CheckName, abortResult.name, 'the eighth check is the chain abort capability');
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, abortResult.status, 'No assignee means the shipped-off capability is still undiscovered');
		Assert.areEqual(System.Label.HealthCheck_AsyncChainAbort_NoAssignees, abortResult.detail, 'The detail names the missing assignment');
		Assert.isNull(abortResult.actionLabel, 'No action ships until handleAction routes it (spec §6.6)');
	}

	/**
	 * @description Verifies the chain-abort check passes when the gating flag is active and at least one
	 * user holds the grant set. Seeds a single mocked assignment so the pass is proven without any real
	 * User DML (illegal in this IsParallel=true class) and without depending on ambient org data, plus an
	 * empty SetupEntityAccess mock so install-written profile grants cannot flip the pass to the
	 * broad-grant warning in subscriber orgs.
	 */
	@IsTest
	private static void shouldPassAbortCheckWhenConfigured()
	{
		TST_Mock.register(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment> {abortAssignment()});
		TST_Mock.register(SetupEntityAccess.SObjectType, new List<SetupEntityAccess>());

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, results[7].status, 'Flag active + an assignee = configured');
		Assert.areEqual(System.Label.HealthCheck_AsyncChainAbort_Configured, results[7].detail, 'The pass detail confirms the capability is usable');
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

		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, results[7].status, 'A deactivated flag is worth surfacing');
		Assert.areEqual(System.Label.HealthCheck_AsyncChainAbort_FlagInactive, results[7].detail, 'The detail names the deactivated flag');
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
		Id profileOwnedParentId = UTIL_Random.randomId(PermissionSet.SObjectType);
		TST_Mock.of(PermissionSet.SObjectType).withOverrides(new Map<SObjectField, Object>
		{
				PermissionSet.Id => profileOwnedParentId,
				PermissionSet.IsOwnedByProfile => true,
				PermissionSet.ProfileId => new SEL_Profile().findByName(SEL_Profile.PROFILE_STANDARD_USER).Id
		}).build();
		TST_Mock.of(SetupEntityAccess.SObjectType).withOverrides(new Map<SObjectField, Object>
		{
				SetupEntityAccess.ParentId => profileOwnedParentId
		}).build();
		TST_Mock.register(PermissionSetAssignment.SObjectType, new List<PermissionSetAssignment>());

		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();
		CTRL_HealthCheck.DTO_HealthCheckResult abortResult = results[7];

		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, abortResult.status, 'A profile-held grant beyond System Administrator silently broadens who can abort');
		Assert.areEqual(System.Label.HealthCheck_AsyncChainAbort_BroadlyGranted, abortResult.detail, 'The detail names the broad grant and its install-mode cause');
	}

	/**
	 * @description Verifies the chain-abort check stays green when the only profile holding the abort
	 * custom permission is System Administrator, the expected artifact of an admins-only install. That
	 * grant must never warn, or every correctly installed org would flag forever. A second,
	 * permission-set-shaped parent (ProfileId null, the AsyncChainAbort set's own ever-present grant in
	 * real orgs) rides along to pin the probe's null guard: the designed assignment route must never
	 * count as a profile grant.
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

		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, results[7].status, 'The System Administrator grant an admins-only install writes is expected and must not warn');
		Assert.areEqual(System.Label.HealthCheck_AsyncChainAbort_Configured, results[7].detail, 'The pass detail confirms the capability is usable');
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

		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, results[7].status, 'An unresolvable administrator profile must skip the broad-grant probe, not crash the Health Check');
		Assert.areEqual(System.Label.HealthCheck_AsyncChainAbort_Configured, results[7].detail, 'The check falls through to the assignee probe');
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

		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, results[7].status, 'An unresolvable abort permission must skip the broad-grant probe, not crash the Health Check');
		Assert.areEqual(System.Label.HealthCheck_AsyncChainAbort_Configured, results[7].detail, 'The check falls through to the assignee probe');
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

		CTRL_HealthCheck.DTO_HealthCheckResult watchdogResult = results[8];
		Assert.areEqual(System.Label.HealthCheck_ChainWatchdog_CheckName, watchdogResult.name, 'the ninth check is the chain watchdog');
		Assert.areEqual(CTRL_HealthCheck.STATUS_WARN, watchdogResult.status, 'an unscheduled watchdog is the operational gap this check surfaces');
		Assert.areEqual(System.Label.HealthCheck_ChainWatchdog_Missing, watchdogResult.detail, 'the detail names the missing watchdog sweep');
		Assert.areEqual(48, watchdogResult.priority, 'the chain watchdog should have priority 48');
		Assert.isNull(watchdogResult.actionLabel, 'no actionLabel ships — healthCheck.js renders schedule/customize from its own template branch');
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

		CTRL_HealthCheck.DTO_HealthCheckResult watchdogResult = results[8];
		Assert.areEqual(System.Label.HealthCheck_ChainWatchdog_CheckName, watchdogResult.name, 'the ninth check is the chain watchdog');
		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, watchdogResult.status, 'an active declarative watchdog job passes the check');
		Assert.areEqual(System.Label.HealthCheck_ChainWatchdog_Configured, watchdogResult.detail, 'the pass detail confirms the watchdog is scheduled');
		Assert.isNull(watchdogResult.actionLabel, 'a passing check offers no action');
	}

	/**
	 * @description Verifies the chain-watchdog check passes through the platform path: no declarative
	 * ScheduledJob__c exists, but a live scheduled-Apex AsyncApexJob row for the watchdog class does —
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

		CTRL_HealthCheck.DTO_HealthCheckResult watchdogResult = results[8];
		Assert.areEqual(System.Label.HealthCheck_ChainWatchdog_CheckName, watchdogResult.name, 'the ninth check is the chain watchdog');
		Assert.areEqual(CTRL_HealthCheck.STATUS_PASS, watchdogResult.status, 'a live scheduled-Apex platform row passes the check without any declarative job');
		Assert.areEqual(System.Label.HealthCheck_ChainWatchdog_Configured, watchdogResult.detail, 'the pass detail confirms the watchdog is scheduled');
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
	 * the chosen cron, the running user's timezone, and the recommended parameters serialized as
	 * name-value text. The AsyncApexJob mock is seeded empty so an ambient watchdog schedule in the org
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

		DTO_NameValues parameters = (DTO_NameValues)new DTO_NameValues().deserialize(createdJob.Parameters__c);
		Assert.areEqual(RECOMMENDED_STALE_THRESHOLD_MINUTES, parameters.get(SCHED_ChainWatchdog.PARAMETER_STALE_THRESHOLD_MINUTES), 'the parameters carry the stale threshold');
		Assert.areEqual(RECOMMENDED_BATCH_SIZE, parameters.get(SCHED_ChainWatchdog.PARAMETER_BATCH_SIZE), 'the serialized parameters carry the recommended batch size');
	}

	/**
	 * @description Verifies a blank cron falls back to the recommended hourly default — the shape the
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
	 * returns null and creates nothing. The unchanged DML-statement count proves no insert ran — the
	 * ScheduledJob__c mock intercepts the selector reads, so the real table cannot be queried to prove
	 * absence directly.
	 */
	@IsTest
	private static void shouldSkipSchedulingWhenWatchdogAlreadyScheduled()
	{
		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c> {newWatchdogJob()});
		Integer dmlStatementsBeforeCall = Limits.getDmlStatements();

		Id scheduledJobId = CTRL_HealthCheck.scheduleChainWatchdog(RECOMMENDED_HOURLY_CRON);

		Assert.isNull(scheduledJobId, 'an already-scheduled watchdog returns null — a stale button click never creates a duplicate');
		Assert.areEqual(dmlStatementsBeforeCall, Limits.getDmlStatements(), 'the skip guard must create nothing — no DML runs');
	}

	/**
	 * @description Builds a non-inserted, active ScheduledJob__c targeting SCHED_ChainWatchdog with the
	 * recommended watchdog parameters — the declarative-path proof row. IsActive__c is set true so the
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
		Integer chainJobCount = 0;
		List<ScheduledJob__c> createdJobs = new SEL_ScheduledJob().findById(new Set<Id>(insertedIds));
		for(ScheduledJob__c job : createdJobs)
		{
			DTO_NameValues parameters = (DTO_NameValues)new DTO_NameValues().deserialize(job.Parameters__c);
			if(chainObjectName.equals(parameters.get(SCHED_PurgeRecords.REQUIRED_PARAMETER_OBJECT_NAME)))
			{
				chainJobCount++;
				Assert.areEqual(completedAtFieldName, parameters.get(SCHED_PurgeRecords.OPTIONAL_PARAMETER_DATE_FIELD_NAME),
						'The async-chain purge job must key on CompletedAt__c so non-terminal chains are never purged');
			}
			else
			{
				Assert.isNull(parameters.get(SCHED_PurgeRecords.OPTIONAL_PARAMETER_DATE_FIELD_NAME),
						'Insert-once framework objects keep the CreatedDate default');
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
	 * MaskingTarget__mdt can reference it through the masking selector's test seams.
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
}