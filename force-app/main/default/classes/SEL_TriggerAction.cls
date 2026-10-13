// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Provides Query methods related for Trigger Action custom metadata
 *
 * @see TRG_Dispatcher
 * @see TriggerAction__mdt
 * @see SEL_TriggerAction_TEST
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, October 2026
 */
public inherited sharing class SEL_TriggerAction
{
	/**
	 * @description Event__c picklist value for Before Insert.
	 */
	public static final String EVENT_BEFORE_INSERT = 'Before Insert';

	/**
	 * @description Event__c picklist value for After Insert.
	 */
	public static final String EVENT_AFTER_INSERT = 'After Insert';

	/**
	 * @description Event__c picklist value for Before Update.
	 */
	public static final String EVENT_BEFORE_UPDATE = 'Before Update';

	/**
	 * @description Event__c picklist value for After Update.
	 */
	public static final String EVENT_AFTER_UPDATE = 'After Update';

	/**
	 * @description Event__c picklist value for Before Delete.
	 */
	public static final String EVENT_BEFORE_DELETE = 'Before Delete';

	/**
	 * @description Event__c picklist value for After Delete.
	 */
	public static final String EVENT_AFTER_DELETE = 'After Delete';

	/**
	 * @description Event__c picklist value for After Undelete.
	 */
	public static final String EVENT_AFTER_UNDELETE = 'After Undelete';

	/**
	 * @description FailureAction__c picklist value: emit a structured log entry and let DML proceed.
	 * Default policy applied when the CMDT row leaves `FailureAction__c` blank.
	 */
	public static final String FAILURE_ACTION_LOG_AND_CONTINUE = 'LogAndContinue';

	/**
	 * @description FailureAction__c picklist value: call `record.addError(...)` (or rethrow for
	 * Apex actions) so the originating DML rolls back and the error surfaces to the user.
	 */
	public static final String FAILURE_ACTION_BLOCK_DML = 'BlockDml';

	/**
	 * @description Maps Event__c picklist values to TriggerOperation enum values.
	 */
	public static final Map<String, TriggerOperation> EVENT_TO_OPERATION = new Map<String, TriggerOperation>
	{
			EVENT_BEFORE_INSERT => TriggerOperation.BEFORE_INSERT,
			EVENT_AFTER_INSERT => TriggerOperation.AFTER_INSERT,
			EVENT_BEFORE_UPDATE => TriggerOperation.BEFORE_UPDATE,
			EVENT_AFTER_UPDATE => TriggerOperation.AFTER_UPDATE,
			EVENT_BEFORE_DELETE => TriggerOperation.BEFORE_DELETE,
			EVENT_AFTER_DELETE => TriggerOperation.AFTER_DELETE,
			EVENT_AFTER_UNDELETE => TriggerOperation.AFTER_UNDELETE
	};

	/**
	 * @description Maps TriggerOperation enum values to Event__c picklist values.
	 */
	public static final Map<TriggerOperation, String> OPERATION_TO_EVENT = new Map<TriggerOperation, String>
	{
			TriggerOperation.BEFORE_INSERT => EVENT_BEFORE_INSERT,
			TriggerOperation.AFTER_INSERT => EVENT_AFTER_INSERT,
			TriggerOperation.BEFORE_UPDATE => EVENT_BEFORE_UPDATE,
			TriggerOperation.AFTER_UPDATE => EVENT_AFTER_UPDATE,
			TriggerOperation.BEFORE_DELETE => EVENT_BEFORE_DELETE,
			TriggerOperation.AFTER_DELETE => EVENT_AFTER_DELETE,
			TriggerOperation.AFTER_UNDELETE => EVENT_AFTER_UNDELETE
	};

	/**
	 * @description Relationship path for SObjectType__r.QualifiedApiName on TriggerSetting__mdt (namespace-safe).
	 * Uses namespace prefix because SObjectType__c is a MetadataRelationship to EntityDefinition,
	 * which does not expose a relationship name via getDescribe().getRelationshipName().
	 */
	private static final String PATH_SOBJECT_TYPE_QUALIFIED_API_NAME =
			UTIL_System.getManagedPackageNamespacePrefix() + 'SObjectType__r.QualifiedApiName';

	/**
	 * @description API name of the trigger action field that switches one action off. The query that builds the trigger action map
	 * keeps only actions where it is false. Read from the field itself so the name carries the package namespace when there is one.
	 */
	private static final String FIELD_TA_BYPASS_EXECUTION = UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.BypassExecution__c);
	/**
	 * @description API name of the trigger setting field that switches off every action of one object. The query that builds the
	 * trigger action map keeps only settings where it is false.
	 */
	private static final String FIELD_TS_BYPASS_EXECUTION = UTIL_SObjectDescribe.getCachedFieldName(TriggerSetting__mdt.BypassExecution__c);
	/**
	 * @description API name of the trigger action field that names the Apex class to run. Selected by queryAllActionRegistrations,
	 * which reads every action to tell whether a class is registered as a trigger action.
	 */
	private static final String FIELD_TA_APEX_CLASS_NAME = UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.ApexClassName__c);
	/**
	 * @description API name of the trigger action field that names the flow to run. Selected by queryAllActionRegistrations, because
	 * an action that names a flow counts as a registration of the flow-running action class.
	 */
	private static final String FIELD_TA_FLOW_NAME = UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.FlowName__c);

	/**
	 * @description Cache lifetime for the unfiltered trigger-action registration query behind
	 * `isRegisteredActionClassName`. Registration rows change only on metadata deploys, so a
	 * short-lived shared cache avoids re-querying; staleness affects only the advisory
	 * unmatched-target audit annotation, never dispatch.
	 */
	private static final Integer REGISTRATION_CACHE_TTL_SECONDS = 300;

	/**
	 * @description The object name of the trigger action custom metadata type, as UTIL_SObjectDescribe.getObjectNameFromType returns
	 * it (with the package namespace when there is one). Nothing in this class reads it; it is visible to tests so they can name
	 * the type without working the name out again.
	 */
	@TestVisible
	private static final String OBJECT_NAME_TRIGGER_ACTION = UTIL_SObjectDescribe.getObjectNameFromType(TriggerAction__mdt.SObjectType);

	/**
	 * @description Map containing trigger actions by Object API name and Trigger Operation
	 * Map<Account, map<AFTER_INSERT, List<TriggerAction__mdt>>
	 */
	private static Map<String, Map<String, List<TriggerAction__mdt>>> triggerActionByObjectNameAndOperationMap;

	/**
	 * @description Map of object API name to the resolved `TriggerSetting__mdt.ApplyMasking__c`
	 * flag for that object. Populated during `buildTriggerActionMap` so TRG_Dispatcher can
	 * decide whether to run the masking pre-step on before-insert/before-update without a
	 * second CMDT query per transaction.
	 */
	@TestVisible
	private static Map<String, Boolean> applyMaskingByObjectNameMap;

	/**
	 * @description API name for the trigger setting bypass feature flag field.
	 */
	public static final String FIELD_TS_BYPASS_FEATURE_FLAG = UTIL_SObjectDescribe.getCachedFieldName(TriggerSetting__mdt.BypassFeatureFlag__c);
	/**
	 * @description API name for the trigger setting required feature flag field.
	 */
	public static final String FIELD_TS_REQUIRED_FEATURE_FLAG = UTIL_SObjectDescribe.getCachedFieldName(TriggerSetting__mdt.RequiredFeatureFlag__c);

	/**
	 * @description Relationship path for TriggerAction BypassFeatureFlag__r.DeveloperName (namespace-safe).
	 */
	private static final String PATH_TA_BYPASS_FEATURE_FLAG_DEVELOPER_NAME =
			UTIL_SObjectDescribe.getCachedFieldDescribe(TriggerAction__mdt.BypassFeatureFlag__c).getRelationshipName() + '.DeveloperName';
	/**
	 * @description Relationship path for TriggerAction RequiredFeatureFlag__r.DeveloperName (namespace-safe).
	 */
	private static final String PATH_TA_REQUIRED_FEATURE_FLAG_DEVELOPER_NAME =
			UTIL_SObjectDescribe.getCachedFieldDescribe(TriggerAction__mdt.RequiredFeatureFlag__c).getRelationshipName() + '.DeveloperName';
	/**
	 * @description Relationship path for TriggerSetting BypassFeatureFlag__r.DeveloperName (namespace-safe).
	 */
	private static final String PATH_TS_BYPASS_FEATURE_FLAG_DEVELOPER_NAME =
			UTIL_SObjectDescribe.getCachedFieldDescribe(TriggerSetting__mdt.BypassFeatureFlag__c).getRelationshipName() + '.DeveloperName';
	/**
	 * @description Relationship path for TriggerSetting RequiredFeatureFlag__r.DeveloperName (namespace-safe).
	 */
	private static final String PATH_TS_REQUIRED_FEATURE_FLAG_DEVELOPER_NAME =
			UTIL_SObjectDescribe.getCachedFieldDescribe(TriggerSetting__mdt.RequiredFeatureFlag__c).getRelationshipName() + '.DeveloperName';

	/**
	 * @description Method use to get the commonly queried fields
	 *
	 * @return A list of commonly queried TriggerAction__mdt fields
	 *
	 * @see TriggerAction__mdt
	 */
	private static Set<String> getTriggerActionFields()
	{
		return new Set<String>
		{
				FIELD_TA_BYPASS_EXECUTION,
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.AllowNonSelfInitiated__c),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.AllowRecursion__c),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.ApexClassName__c),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.BypassFeatureFlag__c),
				PATH_TA_BYPASS_FEATURE_FLAG_DEVELOPER_NAME,
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.Description__c),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.DeveloperName),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.EntryCriteriaContextClassName__c),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.EntryCriteriaFormula__c),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.Event__c),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.FailureAction__c),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.FlowName__c),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.ForcePerformanceLogging__c),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.NamespacePrefix),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.Order__c),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.PerformanceThresholdMs__c),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.RequiredFeatureFlag__c),
				PATH_TA_REQUIRED_FEATURE_FLAG_DEVELOPER_NAME,
				UTIL_SObjectDescribe.getCachedFieldName(TriggerAction__mdt.SuppressPerformanceLogging__c)
		};
	}

	/**
	 * @description Method use to get the commonly queried fields
	 *
	 * @return A list of commonly queried TriggerSetting__mdt fields
	 *
	 * @see TriggerSetting__mdt
	 */
	private static Set<String> getTriggerSettingFields()
	{
		return new Set<String>
		{
				FIELD_TS_BYPASS_EXECUTION,
				FIELD_TS_BYPASS_FEATURE_FLAG,
				PATH_TS_BYPASS_FEATURE_FLAG_DEVELOPER_NAME,
				FIELD_TS_REQUIRED_FEATURE_FLAG,
				PATH_TS_REQUIRED_FEATURE_FLAG_DEVELOPER_NAME,
				UTIL_SObjectDescribe.getCachedFieldName(TriggerSetting__mdt.ApplyMasking__c),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerSetting__mdt.EnablePerformanceLogging__c),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerSetting__mdt.PerformanceThresholdMs__c),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerSetting__mdt.SObjectType__c),
				UTIL_SObjectDescribe.getCachedFieldName(TriggerSetting__mdt.ObjectApiNameOverride__c),
				PATH_SOBJECT_TYPE_QUALIFIED_API_NAME
		};
	}

	/**
	 * @description Reports whether the `ApplyMasking__c` checkbox on the TriggerSetting for
	 * the given SObject API name is true. Lazy-builds the trigger-action map on first read and
	 * returns false for any object without a TriggerSetting.
	 *
	 * @param objectName The SObject API name (e.g. `ApiCall__c`)
	 *
	 * @return True when the object's TriggerSetting opts into data masking
	 */
	public static Boolean shouldApplyMaskingFor(String objectName)
	{
		if(applyMaskingByObjectNameMap == null)
		{
			triggerActionByObjectNameAndOperationMap = new Map<String, Map<String, List<TriggerAction__mdt>>>();
			applyMaskingByObjectNameMap = new Map<String, Boolean>();
			buildTriggerActionMap();
		}
		return applyMaskingByObjectNameMap.get(objectName) == true;
	}

	/**
	 * @description Method will find trigger action custom metadata record that is active based on object api name and database trigger operation
	 *
	 * @param objectName API name of the object
	 * @param operation Operation on which to filter records
	 *
	 * @return items found
	 */
	public static List<TriggerAction__mdt> findActiveByObjectNameAndTriggerOperation(String objectName, TriggerOperation operation)
	{
		if(triggerActionByObjectNameAndOperationMap == null)
		{
			triggerActionByObjectNameAndOperationMap = new Map<String, Map<String, List<TriggerAction__mdt>>>();
			applyMaskingByObjectNameMap = new Map<String, Boolean>();
			buildTriggerActionMap();
		}

		return triggerActionByObjectNameAndOperationMap.get(objectName)?.get(operation.name()) ?? new List<TriggerAction__mdt>();
	}

	/**
	 * @description Checks whether a class name matches at least one registered `TriggerAction__mdt`
	 * row's resolved action class: the row's `ApexClassName__c`, or the flow-runner class
	 * (`TRG_InvokeFlow`) when any flow-action row exists, since every flow row dispatches through
	 * that one class. Comparison is case-insensitive, mirroring Apex class-name semantics, and
	 * deliberately ignores `BypassExecution__c`: a row that is currently CMDT-bypassed is still a
	 * real target. Used by the bypass audit to flag bypass targets that can never take effect.
	 *
	 * @param actionClassName The action class name to check.
	 *
	 * @return `true` when at least one registered row resolves to the given class name, `false`
	 *         for blank input or when nothing matches.
	 */
	public static Boolean isRegisteredActionClassName(String actionClassName)
	{
		if(String.isBlank(actionClassName))
		{
			return false;
		}
		Boolean flowRunnerRequested = actionClassName.equalsIgnoreCase(TRG_InvokeFlow.class.getName());
		for(TriggerAction__mdt actionRow : queryAllActionRegistrations())
		{
			if(String.isNotBlank(actionRow.ApexClassName__c) && actionClassName.equalsIgnoreCase(actionRow.ApexClassName__c))
			{
				return true;
			}
			if(flowRunnerRequested && String.isNotBlank(actionRow.FlowName__c))
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * @description Queries the registration-relevant fields of every `TriggerAction__mdt` row
	 * through the framework cache (`QRY_Builder.withCache`: Platform Cache when available, with
	 * the engine's per-transaction fallback). Deliberately unfiltered (`BypassExecution__c`
	 * included): a row that is currently CMDT-bypassed is still a registered target, and
	 * custom-metadata SOQL does not count against query limits.
	 * The sharing setting is stated explicitly because a cached read must carry one: custom metadata
	 * has no record sharing, so the bypassed setting returns the same rows while letting every caller
	 * share one org-wide cache entry.
	 *
	 * @return Every trigger-action row with its class and flow name fields.
	 */
	private static List<TriggerAction__mdt> queryAllActionRegistrations()
	{
		return QRY_Builder.selectFrom(TriggerAction__mdt.SObjectType)
				.systemModeInternal()
				.bypassSharingInternal()
				.fields(new List<String> {FIELD_TA_APEX_CLASS_NAME, FIELD_TA_FLOW_NAME})
				.withCache(REGISTRATION_CACHE_TTL_SECONDS)
				.toList();
	}

	/**
	 * @description Queries all active trigger settings and their child actions, then indexes them
	 * by object name and trigger operation for efficient lookup.
	 * Child subselect intentionally omits ORDER BY due to Salesforce Known Issue W-8877088
	 * (CMDT subselect ORDER BY silently drops child records). Sorting is done in Apex via sortByOrder().
	 */
	private static void buildTriggerActionMap()
	{
		QRY_Builder.Builder settingQuery = QRY_Builder.selectFrom(TriggerSetting__mdt.SObjectType)
				.systemModeInternal()
				.fields(new List<String>(getTriggerSettingFields()))
				.condition(FIELD_TS_BYPASS_EXECUTION).equals(false);

		QRY_Builder.Builder childQuery = QRY_Builder.selectFrom(TriggerAction__mdt.SObjectType)
				.systemModeInternal()
				.fields(new List<String>(getTriggerActionFields()))
				.condition(FIELD_TA_BYPASS_EXECUTION).equals(false);

		settingQuery.subselect(childQuery, 'TriggerActions__r');

		for(TriggerSetting__mdt foundSetting : (List<TriggerSetting__mdt>)settingQuery.toList())
		{
			indexActionsForSetting(foundSetting);
		}
	}

	/**
	 * @description Indexes all executable child actions of a single trigger setting into the
	 * triggerActionByObjectNameAndOperationMap, grouped by object name and trigger operation.
	 * Actions are sorted by Order__c before indexing to guarantee deterministic execution order.
	 *
	 * @param foundSetting The trigger setting whose child actions should be indexed
	 */
	private static void indexActionsForSetting(TriggerSetting__mdt foundSetting)
	{
		String keyName = resolveObjectName(foundSetting);

		if(!triggerActionByObjectNameAndOperationMap.containsKey(keyName))
		{
			triggerActionByObjectNameAndOperationMap.put(keyName, new Map<String, List<TriggerAction__mdt>>());
		}

		applyMaskingByObjectNameMap.put(keyName, foundSetting.ApplyMasking__c == true);

		Map<String, List<TriggerAction__mdt>> actionByOperationMap = triggerActionByObjectNameAndOperationMap.get(keyName);

		for(TriggerAction__mdt action : sortByOrder(foundSetting.TriggerActions__r))
		{
			addActionIfExecutable(actionByOperationMap, foundSetting, action);
		}
	}

	/**
	 * @description Validates a single trigger action and adds it to the operation map if it has a
	 * valid trigger operation and passes permission/feature flag checks.
	 *
	 * @param actionByOperationMap The map to add the action to, keyed by operation name
	 * @param foundSetting The parent trigger setting for permission checks
	 * @param action The trigger action to evaluate and potentially add
	 */
	@TestVisible
	private static void addActionIfExecutable
			(
					Map<String, List<TriggerAction__mdt>> actionByOperationMap,
					TriggerSetting__mdt foundSetting,
					TriggerAction__mdt action
			)
	{
		TriggerOperation triggerOperation = EVENT_TO_OPERATION.get(action.Event__c);

		if(triggerOperation == null || !shouldExecute(foundSetting, action))
		{
			return;
		}

		String operationKey = triggerOperation.name();

		if(!actionByOperationMap.containsKey(operationKey))
		{
			actionByOperationMap.put(operationKey, new List<TriggerAction__mdt>());
		}

		actionByOperationMap.get(operationKey).add(action);
	}

	/**
	 * @description Decides from the feature flags whether the action may run. An action is skipped when its own
	 * bypass flag or its setting's bypass flag is on, or when a required flag on the setting or on the action is off.
	 * A skipped action writes no log entry: the flag is the subscriber's own setting, and the flag record already
	 * shows why the action did not run.
	 *
	 * @param triggerSetting The Trigger setting associated with the provided triggerAction
	 * @param triggerAction The action whose permissions/feature flags should be checked
	 *
	 * @return True if the action can be executed
	 */
	@TestVisible
	private static Boolean shouldExecute(TriggerSetting__mdt triggerSetting, TriggerAction__mdt triggerAction)
	{
		Boolean actionBypassed = UTIL_FeatureFlag.isEnabled(triggerAction.BypassFeatureFlag__r?.DeveloperName);
		Boolean settingBypassed = UTIL_FeatureFlag.isEnabled(triggerSetting.BypassFeatureFlag__r?.DeveloperName);

		if(actionBypassed || settingBypassed)
		{
			return false;
		}

		if(triggerSetting.RequiredFeatureFlag__c != null && !UTIL_FeatureFlag.isEnabled(triggerSetting.RequiredFeatureFlag__r?.DeveloperName))
		{
			return false;
		}

		if(triggerAction.RequiredFeatureFlag__c != null && !UTIL_FeatureFlag.isEnabled(triggerAction.RequiredFeatureFlag__r?.DeveloperName))
		{
			return false;
		}

		return true;
	}

	/**
	 * @description Sorts trigger actions by Order__c ascending, breaking ties on DeveloperName
	 * ascending so two actions sharing an Order__c value always dispatch in the same sequence.
	 * Delegates the ordering to the reusable fluent `UTIL_Comparators` sort chain
	 * (Order__c first, then DeveloperName, both ascending) so the null and direction semantics match
	 * the rest of the framework's field sorting.
	 * Required because CMDT parent-child subselect ORDER BY silently drops child records.
	 * Salesforce Known Issues:
	 * - W-8877088 (ORDER BY in subquery does not return all records)
	 * - W-6357102 (ASC/DESC in subquery returns different results)
	 *
	 * @param actions The trigger actions to sort
	 *
	 * @return A new list sorted by Order__c ascending (a null Order__c sorts first, ahead of any
	 * numbered action), with equal-Order rows broken deterministically by DeveloperName ascending
	 */
	@TestVisible
	private static List<TriggerAction__mdt> sortByOrder(List<TriggerAction__mdt> actions)
	{
		List<TriggerAction__mdt> sorted = new List<TriggerAction__mdt>(actions);
		sorted.sort(UTIL_Comparators.orderBy(TriggerAction__mdt.Order__c).thenBy(TriggerAction__mdt.DeveloperName));
		return sorted;
	}

	/**
	 * @description Resolves the SObject API name from a TriggerSetting__mdt record. When the
	 * ObjectApiNameOverride__c text field is populated, it takes precedence. It is used to register
	 * entity types the SObjectType__c relationship cannot reference (primary case: Change Data
	 * Capture entities, which the platform excludes from the relationship's restricted-picklist
	 * filter). The override text is normalised to the platform-canonical API-name casing so it
	 * matches the dispatch-time lookup key (which is derived from the live record's SObjectType
	 * and is always canonical) regardless of how the admin cased it. Otherwise resolves via the
	 * EntityDefinition relationship (QualifiedApiName) when available from real queries, falling
	 * back to SObjectType__c for test-constructed records where the relationship cannot be populated.
	 *
	 * @param setting The trigger setting record
	 *
	 * @return The fully qualified SObject API name, or null when neither the override nor the relationship is populated.
	 */
	@TestVisible
	private static String resolveObjectName(TriggerSetting__mdt setting)
	{
		if(String.isNotBlank(setting.ObjectApiNameOverride__c))
		{
			return canonicalizeObjectName(setting.ObjectApiNameOverride__c);
		}
		if(setting.SObjectType__r != null)
		{
			return setting.SObjectType__r.QualifiedApiName;
		}
		return setting.SObjectType__c;
	}

	/**
	 * @description Normalises a free-text object API name to the platform-canonical casing so
	 * it matches the dispatch-time lookup key (derived from the live record's SObjectType via
	 * UTIL_SObjectDescribe and therefore always canonical). When the name resolves via
	 * `UTIL_SObjectDescribe.getSObjectTypeByName`, the describe's canonical name is returned;
	 * otherwise the input is returned unchanged so a name the running context cannot describe
	 * still registers under exactly what the admin typed (no silent loss).
	 *
	 * @param objectApiName The admin-typed override text
	 *
	 * @return The canonical object API name when describable, else the input unchanged.
	 */
	private static String canonicalizeObjectName(String objectApiName)
	{
		SObjectType resolvedType = UTIL_SObjectDescribe.getSObjectTypeByName(objectApiName);
		return resolvedType != null ? UTIL_SObjectDescribe.getObjectNameFromType(resolvedType) : objectApiName;
	}
}