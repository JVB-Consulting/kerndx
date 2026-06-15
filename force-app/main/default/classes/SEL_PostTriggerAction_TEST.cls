// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for SEL_PostTriggerAction. Verifies ordered retrieval, null-Order
 * handling, override-seam behaviour, and the SOQL fall-through when no override is set.
 *
 * @see SEL_PostTriggerAction
 * @see PostTriggerAction__mdt
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date May 2026, June 2026
 */
@IsTest(SeeAllData=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_PostTriggerAction_TEST
{
	/**
	 * @description Verifies the override seam returns rows sorted by `Order__c` ascending.
	 */
	@IsTest
	private static void findActiveOrderedReturnsRowsSortedByOrderAscending()
	{
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt>
		{
				buildRow('Third', 30),
				buildRow('First', 10),
				buildRow('Second', 20)
		};

		Test.startTest();
		List<PostTriggerAction__mdt> rows = SEL_PostTriggerAction.findActiveOrdered();
		Test.stopTest();

		Assert.areEqual(3, rows.size(), 'All 3 override rows should be returned');
		Assert.areEqual('First', rows[0].DeveloperName, 'Row with Order=10 should be first');
		Assert.areEqual('Second', rows[1].DeveloperName, 'Row with Order=20 should be second');
		Assert.areEqual('Third', rows[2].DeveloperName, 'Row with Order=30 should be third');
	}

	/**
	 * @description Verifies that a null `Order__c` value sorts first — before any non-null
	 * Order value.
	 */
	@IsTest
	private static void findActiveOrderedSortsNullOrderFirst()
	{
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt>
		{
				buildRow('Ten', 10),
				buildRow('NullOrder', null),
				buildRow('Twenty', 20)
		};

		Test.startTest();
		List<PostTriggerAction__mdt> rows = SEL_PostTriggerAction.findActiveOrdered();
		Test.stopTest();

		Assert.areEqual(3, rows.size(), 'All 3 override rows should be returned');
		Assert.areEqual('NullOrder', rows[0].DeveloperName, 'Null Order should sort first');
		Assert.areEqual('Ten', rows[1].DeveloperName, 'Order=10 should follow null');
		Assert.areEqual('Twenty', rows[2].DeveloperName, 'Order=20 should be last');
	}

	/**
	 * @description Verifies that an empty override list returns an empty result without
	 * touching the SOQL path.
	 */
	@IsTest
	private static void findActiveOrderedReturnsEmptyForEmptyOverride()
	{
		SEL_PostTriggerAction.overrideRows = new List<PostTriggerAction__mdt>();

		Test.startTest();
		List<PostTriggerAction__mdt> rows = SEL_PostTriggerAction.findActiveOrdered();
		Test.stopTest();

		Assert.areEqual(0, rows.size(), 'Empty override should return empty list');
	}

	/**
	 * @description Verifies the SOQL fall-through path runs cleanly when no override is set.
	 * In a dev org with no `PostTriggerAction__mdt` records deployed, the SOQL returns an
	 * empty list — confirms the QRY_Builder field set + condition compile and execute.
	 */
	@IsTest
	private static void findActiveOrderedQueriesCmdtWhenOverrideIsNull()
	{
		SEL_PostTriggerAction.overrideRows = null;

		Test.startTest();
		List<PostTriggerAction__mdt> rows = SEL_PostTriggerAction.findActiveOrdered();
		Test.stopTest();

		Assert.isNotNull(rows, 'Selector should return a non-null list even when org has no rows');
	}

	/**
	 * @description Cascade guard. The real SOQL path reads framework CMDT config in
	 * SYSTEM_MODE through the non-audited internal channel, so it must NOT emit a bypass-audit
	 * `LogEntryEvent__e`. The post-action handler runs on the outermost unwind of EVERY
	 * dispatch — including the `LogEntryEvent__e` handler itself — so an audited read here
	 * re-enters the dispatcher and self-feeds an emit->deliver->dispatch->query->emit logging
	 * cascade (one log write fanning out into ~120). Measures the audit-buffer delta around the
	 * call (before `Test.stopTest` flushes it) so a regression to `.withSystemMode()` fails loudly.
	 *
	 * @see SEL_PostTriggerAction.findActiveOrdered
	 * @see QRY_Builder.Builder.systemModeInternal
	 */
	@IsTest
	private static void findActiveOrderedMustNotEmitBypassAudit()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();
		SEL_PostTriggerAction.overrideRows = null;

		Test.startTest();
		Integer auditCountBefore = LOG_Engine.getAuditBufferSize();
		SEL_PostTriggerAction.findActiveOrdered();
		Integer auditCountAfter = LOG_Engine.getAuditBufferSize();
		Test.stopTest();

		Assert.areEqual(auditCountBefore, auditCountAfter,
				'Framework-internal post-action config read must not emit a bypass audit; an audited read self-feeds a logging cascade on the LogEntryEvent__e dispatch');
	}

	/**
	 * @description Caching guard. The post-action hook runs at the outermost unwind of EVERY
	 * dispatch — including each delivered `LogEntryEvent__e` — so `findActiveOrdered()` must read
	 * the CMDT config once per transaction, not once per dispatch. An uncached query re-runs per
	 * delivered log event and exhausts the SOQL governor in log-heavy transactions. Asserts that
	 * repeated calls (override seam unset) issue no additional SOQL after the first, exercising the
	 * lazily-loaded `cachedActiveRows` property.
	 *
	 * @see SEL_PostTriggerAction.findActiveOrdered
	 */
	@IsTest
	private static void findActiveOrderedCachesCmdtReadPerTransaction()
	{
		SEL_PostTriggerAction.overrideRows = null;

		Test.startTest();
		SEL_PostTriggerAction.findActiveOrdered();
		Integer queriesAfterFirstCall = Limits.getQueries();
		SEL_PostTriggerAction.findActiveOrdered();
		SEL_PostTriggerAction.findActiveOrdered();
		Integer queriesAfterRepeatCalls = Limits.getQueries();
		Test.stopTest();

		Assert.areEqual(queriesAfterFirstCall, queriesAfterRepeatCalls,
				'findActiveOrdered must cache the CMDT read per transaction — repeated per-dispatch hook invocations should issue no further SOQL');
	}

	/**
	 * @description Guards against the field-projection regression class where the handler
	 * reads a field off a SOQL-returned row that the selector never queried — which throws
	 * `SObjectException` on the real CMDT path yet is invisible to the override seam (whose
	 * in-memory rows expose every field). Asserts `queriedFieldNames()` covers both every direct
	 * field AND every relationship-path traversal `UTIL_PostTriggerAction` reads at runtime — a
	 * relationship path (`Lookup__r.Field__c`) is not auto-included by querying its base lookup,
	 * so the traversals are the more fragile half of the projection and must be pinned explicitly.
	 */
	@IsTest
	private static void queriedFieldNamesCoverEveryHandlerReadField()
	{
		Set<String> projected = new Set<String>(SEL_PostTriggerAction.queriedFieldNames());

		List<Schema.SObjectField> handlerReadFields = new List<Schema.SObjectField>
		{
				PostTriggerAction__mdt.DeveloperName,
				PostTriggerAction__mdt.ApexClassName__c,
				PostTriggerAction__mdt.Order__c,
				PostTriggerAction__mdt.BypassExecution__c,
				PostTriggerAction__mdt.FailureAction__c,
				PostTriggerAction__mdt.EntryCriteriaContextClassName__c,
				PostTriggerAction__mdt.TriggerSetting__c,
				PostTriggerAction__mdt.PerformanceThresholdMs__c,
				PostTriggerAction__mdt.ForcePerformanceLogging__c,
				PostTriggerAction__mdt.RequiredFeatureFlag__c,
				PostTriggerAction__mdt.BypassFeatureFlag__c
		};

		for(Schema.SObjectField field : handlerReadFields)
		{
			String fieldName = UTIL_SObjectDescribe.getCachedFieldName(field);
			Assert.isTrue(projected.contains(fieldName),
					'Projection must query ' + fieldName + ' — the handler reads it off the SOQL-returned row');
		}

		Map<Schema.SObjectField, String> handlerReadRelationshipPaths = new Map<Schema.SObjectField, String>
		{
				PostTriggerAction__mdt.TriggerSetting__c => '.SObjectType__c',
				PostTriggerAction__mdt.RequiredFeatureFlag__c => '.DeveloperName',
				PostTriggerAction__mdt.BypassFeatureFlag__c => '.DeveloperName'
		};

		for(Schema.SObjectField lookupField : handlerReadRelationshipPaths.keySet())
		{
			String relationshipPath = UTIL_SObjectDescribe.getCachedFieldDescribe(lookupField).getRelationshipName()
					+ handlerReadRelationshipPaths.get(lookupField);
			Assert.isTrue(projected.contains(relationshipPath),
					'Projection must query ' + relationshipPath + ' — the handler traverses it off the SOQL-returned row');
		}
	}

	/**
	 * @description Builds an in-memory PostTriggerAction__mdt row via TST_Builder so the
	 * codebase rule "no bare new SObject()" in test code is honoured.
	 *
	 * @param developerName The developer-name to set on the row
	 * @param orderValue The Order__c value (nullable)
	 *
	 * @return An uninserted PostTriggerAction__mdt instance
	 */
	private static PostTriggerAction__mdt buildRow(String developerName, Decimal orderValue)
	{
		TST_Builder.Builder builder = TST_Builder.of(PostTriggerAction__mdt.SObjectType)
				.withOverride(PostTriggerAction__mdt.DeveloperName, developerName);

		if(orderValue != null)
		{
			builder.withOverride(PostTriggerAction__mdt.Order__c, orderValue);
		}

		return (PostTriggerAction__mdt)builder.withoutInsertion().build();
	}
}