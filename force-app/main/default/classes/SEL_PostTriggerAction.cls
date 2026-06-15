// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for `PostTriggerAction__mdt` rows. Provides ordered retrieval
 * for the dispatcher's outermost-unwind hook and a `@TestVisible` override seam for
 * unit-test injection.
 *
 * @see UTIL_PostTriggerAction
 * @see PostTriggerAction__mdt
 * @see SEL_PostTriggerAction_TEST
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date May 2026, June 2026
 *
 * @since 1.1
 */
public inherited sharing class SEL_PostTriggerAction
{
	/**
	 * @description Relationship path for `TriggerSetting__r.SObjectType__c` — used by the
	 * handler's optional-lookup smart-semantics filter to gate execution on whether the
	 * parent setting's SObject participated in the transaction.
	 */
	private static final String PATH_TRIGGER_SETTING_SOBJECT_TYPE =
			UTIL_SObjectDescribe.getCachedFieldDescribe(PostTriggerAction__mdt.TriggerSetting__c).getRelationshipName() + '.SObjectType__c';

	/**
	 * @description Relationship path for `RequiredFeatureFlag__r.DeveloperName` (namespace-safe).
	 */
	private static final String PATH_REQUIRED_FEATURE_FLAG_DEVELOPER_NAME =
			UTIL_SObjectDescribe.getCachedFieldDescribe(PostTriggerAction__mdt.RequiredFeatureFlag__c).getRelationshipName() + '.DeveloperName';

	/**
	 * @description Relationship path for `BypassFeatureFlag__r.DeveloperName` (namespace-safe).
	 */
	private static final String PATH_BYPASS_FEATURE_FLAG_DEVELOPER_NAME =
			UTIL_SObjectDescribe.getCachedFieldDescribe(PostTriggerAction__mdt.BypassFeatureFlag__c).getRelationshipName() + '.DeveloperName';

	/**
	 * @description `@TestVisible` override seam for injecting in-memory rows in unit tests.
	 * When non-null, `findActiveOrdered()` returns this list (after `sortByOrder`) without
	 * running the SOQL fall-through. Frees subscribers from needing to deploy real CMDT
	 * records to exercise the post-action pipeline from their own tests.
	 */
	@TestVisible
	private static List<PostTriggerAction__mdt> overrideRows;

	/**
	 * @description Transaction-scoped, lazily-loaded cache of the SOQL-fetched active rows. The
	 * post-action hook runs at the outermost unwind of EVERY dispatch, so an uncached query would
	 * re-run once per dispatch — and once per delivered `LogEntryEvent__e` — exhausting the SOQL
	 * governor in log-heavy transactions. The getter populates the cache on first access and reuses
	 * it for the rest of the transaction; `findActiveOrdered()` consults the `overrideRows` test
	 * seam ahead of this cache so injected rows are always honoured.
	 *
	 * `systemModeInternal()` (not `withSystemMode()`) because this is a framework-internal CMDT
	 * config read, not an application sharing/FLS opt-out — it must NOT emit a bypass-audit
	 * `LogEntryEvent__e`. The hook runs on the outermost unwind of EVERY dispatch incl. the
	 * `LogEntryEvent__e` handler itself, so an audited read here re-enters the dispatcher and
	 * self-feeds a logging cascade.
	 */
	private static final List<PostTriggerAction__mdt> cachedActiveRows
	{
		get
		{
			if(cachedActiveRows == null)
			{
				cachedActiveRows = sortByOrder
						(
								QRY_Builder.selectFrom(PostTriggerAction__mdt.SObjectType)
										.systemModeInternal()
										.fields(queriedFieldNames())
										.condition(UTIL_SObjectDescribe.getCachedFieldName(PostTriggerAction__mdt.BypassExecution__c)).equals(false)
										.toList()
						);
			}
			return cachedActiveRows;
		}
		private set;
	}

	/**
	 * @description Returns active `PostTriggerAction__mdt` rows (bypassed rows excluded
	 * at the SOQL level) sorted by `Order__c` ascending — null `Order__c` sorts first,
	 * before any non-null value. The SOQL result is cached per transaction (see
	 * `cachedActiveRows`) so the per-dispatch hook does not re-query on every invocation.
	 *
	 * Queried fields cover everything the handler needs at runtime: identity, Apex
	 * class binding, gating (feature flags, entry-criteria evaluator, TriggerSetting
	 * scope), failure-action policy, and per-row performance knobs. Two relationship
	 * traversals: `TriggerSetting__r.SObjectType__c` (for the optional scope filter)
	 * and the two feature-flag `DeveloperName`s. See `queriedFieldNames()` for the
	 * authoritative projection.
	 *
	 * @return A list of active `PostTriggerAction__mdt` rows sorted by `Order__c` ascending.
	 */
	public static List<PostTriggerAction__mdt> findActiveOrdered()
	{
		return overrideRows != null ? sortByOrder(overrideRows) : cachedActiveRows;
	}

	/**
	 * @description The SOQL field projection for the post-action query, exposed via
	 * `@TestVisible` so a test can assert it covers every field the handler reads off the
	 * SOQL-returned row. A Custom Metadata Type field that is omitted from the projection
	 * is not auto-populated — accessing it throws `System.SObjectException`. The override
	 * seam returns fully-populated in-memory rows, so it cannot surface such an omission;
	 * pinning this list in a test is the only guard against that class of regression.
	 *
	 * @return The field and relationship-path names selected by `findActiveOrdered()`.
	 */
	@TestVisible
	private static List<String> queriedFieldNames()
	{
		return new List<String>
		{
				UTIL_SObjectDescribe.getCachedFieldName(PostTriggerAction__mdt.DeveloperName),
				UTIL_SObjectDescribe.getCachedFieldName(PostTriggerAction__mdt.ApexClassName__c),
				UTIL_SObjectDescribe.getCachedFieldName(PostTriggerAction__mdt.Order__c),
				UTIL_SObjectDescribe.getCachedFieldName(PostTriggerAction__mdt.BypassExecution__c),
				UTIL_SObjectDescribe.getCachedFieldName(PostTriggerAction__mdt.FailureAction__c),
				UTIL_SObjectDescribe.getCachedFieldName(PostTriggerAction__mdt.Description__c),
				UTIL_SObjectDescribe.getCachedFieldName(PostTriggerAction__mdt.EntryCriteriaContextClassName__c),
				UTIL_SObjectDescribe.getCachedFieldName(PostTriggerAction__mdt.TriggerSetting__c),
				PATH_TRIGGER_SETTING_SOBJECT_TYPE,
				UTIL_SObjectDescribe.getCachedFieldName(PostTriggerAction__mdt.PerformanceThresholdMs__c),
				UTIL_SObjectDescribe.getCachedFieldName(PostTriggerAction__mdt.ForcePerformanceLogging__c),
				UTIL_SObjectDescribe.getCachedFieldName(PostTriggerAction__mdt.RequiredFeatureFlag__c),
				UTIL_SObjectDescribe.getCachedFieldName(PostTriggerAction__mdt.BypassFeatureFlag__c),
				PATH_REQUIRED_FEATURE_FLAG_DEVELOPER_NAME,
				PATH_BYPASS_FEATURE_FLAG_DEVELOPER_NAME
		};
	}

	/**
	 * @description Sorts the supplied rows by `Order__c` ascending via the framework
	 * `SObjectFieldComparator`. Apex-side sort is required because Salesforce Known
	 * Issue W-8877088 makes CMDT SOQL `ORDER BY` unreliable in some configurations.
	 * Null `Order__c` sorts before any non-null value (Comparator semantics).
	 *
	 * @param rows The list of rows to sort
	 *
	 * @return A new list sorted by `Order__c` ascending
	 */
	private static List<PostTriggerAction__mdt> sortByOrder(List<PostTriggerAction__mdt> rows)
	{
		List<PostTriggerAction__mdt> sorted = new List<PostTriggerAction__mdt>(rows);
		sorted.sort(new UTIL_Comparators.SObjectFieldComparator(UTIL_SObjectDescribe.getCachedFieldName(PostTriggerAction__mdt.Order__c), true));
		return sorted;
	}
}