// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the FeatureFlag__mdt custom metadata type. Provides access to feature flag
 * definitions and their associated active strategies sorted by evaluation order.
 *
 * @see SEL_Base
 * @see SEL_FeatureFlag_TEST
 *
 * @author Jason van Beukering
 *
 * @group Feature Flags
 *
 * @date February 2026, May 2026
 */
public inherited sharing class SEL_FeatureFlag extends SEL_Base
{
	/**
	 * @description Test feature flag developer name used in unit tests.
	 */
	@TestVisible
	private static final String TEST_FEATURE_FLAG = 'TestFeatureFlag';

	/**
	 * @description All Feature Flag DeveloperNames (active + inactive) for definition lookup.
	 * Used by Strict Definition Priority pattern - an inactive flag still "claims" its name.
	 * Cached for the transaction.
	 *
	 * Populated via `QRY_Builder` rather than `FeatureFlag__mdt.getAll().keySet()` because
	 * `getAll()` throws `System.ListException: Row with duplicate DeveloperName` when a
	 * subscriber org has a FeatureFlag in its own namespace with the same DeveloperName as a
	 * shipped `kern__` record (e.g., release-testing CMDT fixtures that override shipped flags
	 * like `MockAllAPIs`, `UserModeDml_Enabled`, `UserModeQueries_Enabled`). CMDT SOQL is
	 * backed by the same metadata cache as `getAll()` — no meaningful performance delta — and
	 * `Set.add` de-dupes across namespaces, which is the intended semantic (override with the
	 * same name claims the same identity).
	 */
	@TestVisible
	public static Set<String> allDeveloperNames
	{
		get
		{
			if(allDeveloperNames == null)
			{
				allDeveloperNames = new SEL_FeatureFlag().fetchAllDeveloperNames();
			}
			return allDeveloperNames;
		}
		private set;
	}

	/**
	 * @description Returns a map of all active flags with their corresponding active strategies, sorted by order.
	 */
	@TestVisible
	public static Map<String, FeatureFlag__mdt> activeFlags
	{
		get
		{
			if(activeFlags == null)
			{
				activeFlags = getAllActiveWithStrategies();
			}

			return activeFlags;
		}
		private set;
	}

	/**
	 * @description Constructs a FeatureFlag selector with the FeatureFlag__mdt SObjectType.
	 */
	public SEL_FeatureFlag()
	{
		super(FeatureFlag__mdt.SObjectType);
	}

	/**
	 * @description Returns the core fields for FeatureFlag__mdt queries.
	 *
	 * @return List of FeatureFlag__mdt SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				FeatureFlag__mdt.DeveloperName,
				FeatureFlag__mdt.IsActive__c,
				FeatureFlag__mdt.IsEnabledByDefault__c,
				FeatureFlag__mdt.ResultOnNoMatch__c
		};
	}

	/**
	 * @description Forces SYSTEM_MODE on the selector's `query` builder so the framework keeps
	 * reading FeatureFlag__mdt records when subscribers run as users with no CRUD on
	 * `kern__FeatureFlag__mdt` / `kern__FeatureFlagStrategy__mdt`. Without this, flipping
	 * `UserModeQueries_Enabled` (the secure-by-default posture) would silently empty the active-flags map and
	 * disable every flag in the org.
	 *
	 * @return Always `true` — feature flag evaluation is framework-internal and must not depend
	 *         on the running user's permissions on the CMDT records.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Returns every `FeatureFlag__mdt` DeveloperName in the org, de-duped across
	 * namespaces. Used by the `allDeveloperNames` property when the cache is cold. Runs through
	 * the selector's `query` property (standard `QRY_Builder` surface) rather than
	 * `FeatureFlag__mdt.getAll()` because `getAll()` throws on cross-namespace name collisions
	 * and breaks the whole framework in any subscriber org that deploys an override flag with
	 * the same name as a shipped one.
	 *
	 * @return Set of distinct `DeveloperName` values across every `FeatureFlag__mdt` record.
	 */
	private Set<String> fetchAllDeveloperNames()
	{
		return query
				.asStringSet(FeatureFlag__mdt.DeveloperName);
	}

	/**
	 * @description Returns all active flags with their active strategies. Single point of truth
	 * for the {@link #activeFlags} cache — invoked once per transaction on cold cache.
	 *
	 * <p><b>Why hand-rolled SOQL + raw `Database.query` instead of `QRY_Builder` / `query`:</b>
	 * this method sits on the feature-flag bootstrap path. Constructing a `QRY_Builder.Builder`
	 * runs its field initializer `userModeEnabled = QRY_Builder.userModeQueriesEnabled()`, which
	 * resolves the `UserModeQueries_Enabled` flag via `UTIL_FeatureFlag.isEnabled(...)`, which
	 * reads `SEL_FeatureFlag.activeFlags`, which calls back into this method when the cache is
	 * cold — an infinite recursion that overflows the stack on first access. Building the SOQL
	 * string by hand and going straight to `Database.query` skips Builder instantiation entirely
	 * and breaks the cycle. Pinning to `AccessLevel.SYSTEM_MODE` here is also load-bearing:
	 * subscribers typically grant running users no CRUD on `kern__FeatureFlag__mdt`, so a
	 * USER_MODE read would return empty and silently disable every flag.
	 *
	 * <p><b>Why no ORDER BY in the strategy subselect:</b> Salesforce Known Issue W-8877088 —
	 * ORDER BY in a CMDT parent-child subselect silently drops child records. Strategies are
	 * sorted in Apex by `UTIL_FeatureFlag.sortByOrder()` after the query returns.
	 *
	 * <p><b>Why the bare `'FeatureFlagStrategies__r'` literal is namespace-safe:</b> the
	 * dynamic-SOQL parser auto-prefixes identifiers (objects, fields, relationship names) with
	 * the running package's namespace at runtime, the same way static SOQL does. The `kern__`
	 * prefix is applied for us in subscriber orgs without any string manipulation here. Same
	 * pattern as `SEL_TriggerAction.buildTriggerActionMap()`.
	 *
	 * @return Map of flag developer name to FeatureFlag__mdt record with populated strategies
	 */
	@SuppressWarnings('PMD.ApexSOQLInjection')
	private static Map<String, FeatureFlag__mdt> getAllActiveWithStrategies()
	{
		List<String> flagFieldNames = new List<String>
		{
				UTIL_SObjectDescribe.getCachedFieldName(FeatureFlag__mdt.DeveloperName),
				UTIL_SObjectDescribe.getCachedFieldName(FeatureFlag__mdt.IsActive__c),
				UTIL_SObjectDescribe.getCachedFieldName(FeatureFlag__mdt.IsEnabledByDefault__c),
				UTIL_SObjectDescribe.getCachedFieldName(FeatureFlag__mdt.ResultOnNoMatch__c)
		};

		List<String> strategyFieldNames = new List<String>
		{
				UTIL_SObjectDescribe.getCachedFieldName(FeatureFlagStrategy__mdt.CustomHandler__c),
				UTIL_SObjectDescribe.getCachedFieldName(FeatureFlagStrategy__mdt.DeveloperName),
				UTIL_SObjectDescribe.getCachedFieldName(FeatureFlagStrategy__mdt.ExpectedValue__c),
				UTIL_SObjectDescribe.getCachedFieldName(FeatureFlagStrategy__mdt.FeatureFlag__c),
				UTIL_SObjectDescribe.getCachedFieldName(FeatureFlagStrategy__mdt.IsActive__c),
				UTIL_SObjectDescribe.getCachedFieldName(FeatureFlagStrategy__mdt.Order__c),
				UTIL_SObjectDescribe.getCachedFieldName(FeatureFlagStrategy__mdt.Target__c),
				UTIL_SObjectDescribe.getCachedFieldName(FeatureFlagStrategy__mdt.Type__c)
		};

		String soql = 'SELECT ' + String.join(flagFieldNames, UTIL_String.COMMA) +
				', (SELECT ' + String.join(strategyFieldNames, UTIL_String.COMMA) +
				' FROM FeatureFlagStrategies__r' +
				' WHERE ' + UTIL_SObjectDescribe.getCachedFieldName(FeatureFlagStrategy__mdt.IsActive__c) + ' = true)' +
				' FROM ' + UTIL_SObjectDescribe.getObjectNameFromType(FeatureFlag__mdt.SObjectType) +
				' WHERE ' + UTIL_SObjectDescribe.getCachedFieldName(FeatureFlag__mdt.IsActive__c) + ' = true';

		Map<String, FeatureFlag__mdt> featureFlagMap = new Map<String, FeatureFlag__mdt>();

		for(FeatureFlag__mdt featureFlag : Database.query(soql, AccessLevel.SYSTEM_MODE))
		{
			featureFlagMap.put(featureFlag.DeveloperName, featureFlag);
		}

		return featureFlagMap;
	}
}