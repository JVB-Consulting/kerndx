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
 * @date February 2026, June 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.EagerlyLoadedDescribeSObjectResult')
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
	 * @description Verifies that runHealthChecks returns results for all checks.
	 */
	@IsTest
	private static void shouldReturnAllHealthCheckResults()
	{
		List<CTRL_HealthCheck.DTO_HealthCheckResult> results = CTRL_HealthCheck.runHealthChecks();

		Assert.areEqual(7, results.size(), 'Expected seven health check results');
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