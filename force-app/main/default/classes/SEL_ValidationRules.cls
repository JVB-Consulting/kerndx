// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Provides query methods for ValidationRuleGroup__mdt and ValidationRule__mdt custom metadata.
 * Handles loading validation rule groups and their child rules based on object and trigger context.
 * Results are cached for performance.
 *
 * @see UTIL_ValidationRule
 * @see ValidationRuleGroup__mdt
 * @see ValidationRule__mdt
 * @see SEL_ValidationRules_TEST
 *
 * @author Jason van Beukering
 *
 * @group Validation
 *
 * @date January 2026, June 2026
 */
public inherited sharing class SEL_ValidationRules
{
	/**
	 * @description Map of timing + operation combinations to TriggerOperation enum values.
	 * Note: BEFORE_UNDELETE does not exist in Salesforce, so it's excluded.
	 */
	private static final Map<String, TriggerOperation> TRIGGER_OPERATION_MAP = new Map<String, TriggerOperation>
	{
			'BEFORE_INSERT' => TriggerOperation.BEFORE_INSERT,
			'BEFORE_UPDATE' => TriggerOperation.BEFORE_UPDATE,
			'BEFORE_DELETE' => TriggerOperation.BEFORE_DELETE,
			'AFTER_INSERT' => TriggerOperation.AFTER_INSERT,
			'AFTER_UPDATE' => TriggerOperation.AFTER_UPDATE,
			'AFTER_DELETE' => TriggerOperation.AFTER_DELETE,
			'AFTER_UNDELETE' => TriggerOperation.AFTER_UNDELETE
	};

	/**
	 * @description Relationship name for TriggerSetting__r on ValidationRuleGroup__mdt.
	 */
	public static final String RELATIONSHIP_TRIGGER_SETTING = UTIL_System.getManagedPackageNamespacePrefix() + 'TriggerSetting__r';

	/**
	 * @description Relationship path for TriggerSetting__r.SObjectType__c (namespace-safe).
	 */
	private static final String PATH_TRIGGER_SETTING_SOBJECT_TYPE =
			ValidationRuleGroup__mdt.TriggerSetting__c.getDescribe().getRelationshipName() + '.' +
			UTIL_SObjectDescribe.getCachedFieldName(TriggerSetting__mdt.SObjectType__c);

	/**
	 * @description Relationship path for TriggerSetting__r.SObjectType__r.QualifiedApiName (namespace-safe).
	 * Uses namespace prefix for SObjectType__r because it is a MetadataRelationship to EntityDefinition,
	 * which does not expose a relationship name via getDescribe().getRelationshipName().
	 */
	private static final String PATH_TRIGGER_SETTING_SOBJECT_TYPE_QUALIFIED_API_NAME =
			ValidationRuleGroup__mdt.TriggerSetting__c.getDescribe().getRelationshipName() + '.' +
			UTIL_System.getManagedPackageNamespacePrefix() + 'SObjectType__r.QualifiedApiName';

	/**
	 * @description Relationship name for ValidationRules__r child relationship on ValidationRuleGroup__mdt.
	 */
	public static final String RELATIONSHIP_VALIDATION_RULES = UTIL_System.getManagedPackageNamespacePrefix() + 'ValidationRules__r';

	/**
	 * @description Relationship path for group BypassFeatureFlag__r.DeveloperName (namespace-safe).
	 */
	private static final String PATH_GROUP_BYPASS_FEATURE_FLAG_DEVELOPER_NAME =
			ValidationRuleGroup__mdt.BypassFeatureFlag__c.getDescribe().getRelationshipName() + '.DeveloperName';
	/**
	 * @description Relationship path for group RequiredFeatureFlag__r.DeveloperName (namespace-safe).
	 */
	private static final String PATH_GROUP_REQUIRED_FEATURE_FLAG_DEVELOPER_NAME =
			ValidationRuleGroup__mdt.RequiredFeatureFlag__c.getDescribe().getRelationshipName() + '.DeveloperName';
	/**
	 * @description Relationship path for rule BypassFeatureFlag__r.DeveloperName (namespace-safe).
	 */
	private static final String PATH_RULE_BYPASS_FEATURE_FLAG_DEVELOPER_NAME =
			ValidationRule__mdt.BypassFeatureFlag__c.getDescribe().getRelationshipName() + '.DeveloperName';
	/**
	 * @description Relationship path for rule RequiredFeatureFlag__r.DeveloperName (namespace-safe).
	 */
	private static final String PATH_RULE_REQUIRED_FEATURE_FLAG_DEVELOPER_NAME =
			ValidationRule__mdt.RequiredFeatureFlag__c.getDescribe().getRelationshipName() + '.DeveloperName';

	/**
	 * @description Test override for the validation rules cache.
	 * Set this in tests to inject custom validation rules without needing actual custom metadata records.
	 * When set, the cache will use this map instead of querying custom metadata.
	 */
	@TestVisible
	private static Map<String, Map<String, List<ValidationRuleWithGroup>>> testCacheOverride;

	/**
	 * @description Test override for the queryActiveGroups result.
	 * Set this in tests to inject mock ValidationRuleGroup__mdt records for testing the loading logic.
	 */
	@TestVisible
	private static List<ValidationRuleGroup__mdt> testGroupsOverride;

	/**
	 * @description Lazy-loaded cached map of validation rules by object API name and trigger operation.
	 * Structure: Map<ObjectApiName, Map<TriggerOperation.name(), List<ValidationRuleWithGroup>>>
	 * Automatically loads all validation rules on first access.
	 */
	private static Map<String, Map<String, List<ValidationRuleWithGroup>>> cachedRulesByObjectAndOperation
	{
		get
		{
			if(Test.isRunningTest() && testCacheOverride != null)
			{
				return testCacheOverride;
			}
			if(cachedRulesByObjectAndOperation == null)
			{
				loadAllRules();
			}
			return cachedRulesByObjectAndOperation;
		}
		private set;
	}

	/**
	 * @description Field API names for querying ValidationRuleGroup__mdt.
	 *
	 * @return Set of field API names
	 */
	private static Set<String> getGroupFields()
	{
		return new Set<String>
		{
				ValidationRuleGroup__mdt.BypassExecution__c.getDescribe().name,
				ValidationRuleGroup__mdt.BypassFeatureFlag__c.getDescribe().name,
				PATH_GROUP_BYPASS_FEATURE_FLAG_DEVELOPER_NAME,
				ValidationRuleGroup__mdt.ContextClassName__c.getDescribe().name,
				ValidationRuleGroup__mdt.Description__c.getDescribe().name,
				ValidationRuleGroup__mdt.DeveloperName.getDescribe().name,
				ValidationRuleGroup__mdt.ExecutionStrategy__c.getDescribe().name,
				ValidationRuleGroup__mdt.MasterLabel.getDescribe().name,
				ValidationRuleGroup__mdt.NamespacePrefix.getDescribe().name,
				ValidationRuleGroup__mdt.RequiredFeatureFlag__c.getDescribe().name,
				PATH_GROUP_REQUIRED_FEATURE_FLAG_DEVELOPER_NAME,
				ValidationRuleGroup__mdt.TriggerOperations__c.getDescribe().name,
				ValidationRuleGroup__mdt.TriggerTiming__c.getDescribe().name,
				PATH_TRIGGER_SETTING_SOBJECT_TYPE,
				PATH_TRIGGER_SETTING_SOBJECT_TYPE_QUALIFIED_API_NAME
		};
	}

	/**
	 * @description Field API names for querying ValidationRule__mdt.
	 *
	 * @return Set of field API names
	 */
	private static Set<String> getRuleFields()
	{
		return new Set<String>
		{
				ValidationRule__mdt.BypassExecution__c.getDescribe().name,
				ValidationRule__mdt.BypassFeatureFlag__c.getDescribe().name,
				PATH_RULE_BYPASS_FEATURE_FLAG_DEVELOPER_NAME,
				ValidationRule__mdt.RequiredFeatureFlag__c.getDescribe().name,
				PATH_RULE_REQUIRED_FEATURE_FLAG_DEVELOPER_NAME,
				ValidationRule__mdt.ContextClassName__c.getDescribe().name,
				ValidationRule__mdt.Description__c.getDescribe().name,
				ValidationRule__mdt.DeveloperName.getDescribe().name,
				ValidationRule__mdt.ErrorDisplayField__c.getDescribe().name,
				ValidationRule__mdt.ErrorMessage__c.getDescribe().name,
				ValidationRule__mdt.MasterLabel.getDescribe().name,
				ValidationRule__mdt.NamespacePrefix.getDescribe().name,
				ValidationRule__mdt.Order__c.getDescribe().name,
				ValidationRule__mdt.RuleFormula__c.getDescribe().name,
				ValidationRule__mdt.Severity__c.getDescribe().name,
				ValidationRule__mdt.ShadowMode__c.getDescribe().name
		};
	}

	/**
	 * @description Wrapper class containing a validation rule and its parent group information.
	 * Used to provide complete context when executing validation rules.
	 */
	public class ValidationRuleWithGroup
	{
		/**
		 * @description The validation rule metadata record.
		 */
		public ValidationRule__mdt rule;

		/**
		 * @description The parent validation rule group metadata record.
		 */
		public ValidationRuleGroup__mdt ruleGroup;

		/**
		 * @description The object API name from the trigger setting.
		 */
		public String objectApiName;

		/**
		 * @description Constructs a new wrapper with the rule and its group.
		 *
		 * @param rule The validation rule record
		 * @param ruleGroup The parent validation rule group record
		 */
		public ValidationRuleWithGroup(ValidationRule__mdt rule, ValidationRuleGroup__mdt ruleGroup)
		{
			this.rule = rule;
			this.ruleGroup = ruleGroup;
			this.objectApiName = buildObjectApiName(ruleGroup);
		}

		/**
		 * @description Gets the full object API name including namespace if applicable.
		 *
		 * @param validationGroup The validation rule group
		 *
		 * @return The full object API name
		 */
		private String buildObjectApiName(ValidationRuleGroup__mdt validationGroup)
		{
			TriggerSetting__mdt setting = validationGroup.TriggerSetting__r;
			if(setting?.SObjectType__r != null)
			{
				return setting.SObjectType__r.QualifiedApiName;
			}
			return setting?.SObjectType__c;
		}
	}

	/**
	 * @description Finds all active validation rules for a given object and trigger operation.
	 * Groups and rules with BypassExecution__c = true are excluded.
	 * Results are cached for the duration of the transaction.
	 *
	 * @param objectApiName The API name of the object (e.g., 'Account', 'Custom__c')
	 * @param operation The trigger operation context
	 *
	 * @return List of ValidationRuleWithGroup wrappers sorted by Order__c
	 *
	 * @example
	 * ```apex
	 * List<SEL_ValidationRules.ValidationRuleWithGroup> rules =
	 *     SEL_ValidationRules.findByObjectAndOperation('Account', TriggerOperation.BEFORE_INSERT);
	 * ```
	 */
	public static List<ValidationRuleWithGroup> findByObjectAndOperation(String objectApiName, TriggerOperation operation)
	{
		Map<String, List<ValidationRuleWithGroup>> rulesByOperation = cachedRulesByObjectAndOperation.get(objectApiName);

		if(rulesByOperation == null)
		{
			return new List<ValidationRuleWithGroup>();
		}

		return rulesByOperation.get(operation.name()) ?? new List<ValidationRuleWithGroup>();
	}

	/**
	 * @description Loads all validation rule groups and their child rules into the cache.
	 * Only loads groups and rules where BypassExecution__c = false.
	 */
	private static void loadAllRules()
	{
		cachedRulesByObjectAndOperation = new Map<String, Map<String, List<ValidationRuleWithGroup>>>();

		List<ValidationRuleGroup__mdt> validationGroups = queryActiveGroups();

		for(ValidationRuleGroup__mdt validationGroup : validationGroups)
		{
			processGroupRules(validationGroup);
		}
	}

	/**
	 * @description Queries all active validation rule groups with their child rules.
	 * Child subselect intentionally omits ORDER BY due to Salesforce Known Issue W-8877088
	 * (CMDT subselect ORDER BY silently drops child records). Sorting is done in Apex via sortByOrder().
	 *
	 * @return List of active validation rule groups with child rules
	 */
	private static List<ValidationRuleGroup__mdt> queryActiveGroups()
	{
		if(Test.isRunningTest() && testGroupsOverride != null)
		{
			return testGroupsOverride;
		}

		QRY_Builder.Builder childQuery = QRY_Builder.selectFrom(ValidationRule__mdt.SObjectType)
				.systemModeInternal()
				.fields(new List<String>(getRuleFields()))
				.condition(ValidationRule__mdt.BypassExecution__c.getDescribe().name).equals(false);

		return QRY_Builder.selectFrom(ValidationRuleGroup__mdt.SObjectType)
				.systemModeInternal()
				.fields(new List<String>(getGroupFields()))
				.condition(ValidationRuleGroup__mdt.BypassExecution__c.getDescribe().name).equals(false)
				.subselect(childQuery, RELATIONSHIP_VALIDATION_RULES)
				.toList();
	}

	/**
	 * @description Processes a validation rule group and adds its rules to the cache.
	 * Maps rules to the appropriate trigger operations based on the group's
	 * TriggerTiming__c and TriggerOperations__c fields.
	 *
	 * @param ruleGroup The validation rule group to process
	 */
	private static void processGroupRules(ValidationRuleGroup__mdt ruleGroup)
	{
		if(ruleGroup.TriggerSetting__r == null || String.isBlank(buildObjectApiName(ruleGroup)))
		{
			return;
		}

		List<ValidationRule__mdt> childRules = ruleGroup.ValidationRules__r;
		if(childRules == null || childRules.isEmpty())
		{
			return;
		}

		String objectApiName = buildObjectApiName(ruleGroup);
		Map<String, List<ValidationRuleWithGroup>> operationMap = getOrCreateOperationMap(objectApiName);
		Set<TriggerOperation> applicableOperations = resolveOperations(ruleGroup);

		addRulesToOperations(sortByOrder(childRules), ruleGroup, operationMap, applicableOperations);
	}

	/**
	 * @description Sorts validation rules by Order__c ascending.
	 * Required because CMDT parent-child subselect ORDER BY silently drops child records.
	 * Salesforce Known Issues:
	 * - W-8877088 (ORDER BY in subquery does not return all records)
	 * - W-6357102 (ASC/DESC in subquery returns different results)
	 *
	 * @param rules The rules to sort
	 *
	 * @return A new list sorted by Order__c ascending (nulls treated as 0)
	 */
	private static List<ValidationRule__mdt> sortByOrder(List<ValidationRule__mdt> rules)
	{
		List<ValidationRule__mdt> sorted = new List<ValidationRule__mdt>(rules);
		sorted.sort(new UTIL_Comparators.SObjectFieldComparator(
				UTIL_SObjectDescribe.getCachedFieldName(ValidationRule__mdt.Order__c), true));
		return sorted;
	}

	/**
	 * @description Builds the full object API name including namespace.
	 *
	 * @param ruleGroup The validation rule group
	 *
	 * @return The full object API name
	 */
	private static String buildObjectApiName(ValidationRuleGroup__mdt ruleGroup)
	{
		TriggerSetting__mdt setting = ruleGroup.TriggerSetting__r;
		if(setting.SObjectType__r != null)
		{
			return setting.SObjectType__r.QualifiedApiName;
		}
		return setting.SObjectType__c;
	}

	/**
	 * @description Gets or creates the operation map for an object.
	 *
	 * @param objectApiName The object API name
	 *
	 * @return The operation map for the object
	 */
	private static Map<String, List<ValidationRuleWithGroup>> getOrCreateOperationMap(String objectApiName)
	{
		Map<String, List<ValidationRuleWithGroup>> operationMap = cachedRulesByObjectAndOperation.get(objectApiName);
		if(operationMap == null)
		{
			operationMap = new Map<String, List<ValidationRuleWithGroup>>();
			cachedRulesByObjectAndOperation.put(objectApiName, operationMap);
		}
		return operationMap;
	}

	/**
	 * @description Adds rules to the operation map for each applicable operation.
	 *
	 * @param childRules The rules to add
	 * @param ruleGroup The parent rule group
	 * @param operationMap The operation map to populate
	 * @param applicableOperations The operations to add rules for
	 */
	private static void addRulesToOperations
			(
					List<ValidationRule__mdt> childRules,
					ValidationRuleGroup__mdt ruleGroup,
					Map<String, List<ValidationRuleWithGroup>> operationMap,
					Set<TriggerOperation> applicableOperations
			)
	{
		for(TriggerOperation operation : applicableOperations)
		{
			List<ValidationRuleWithGroup> rulesForOperation = operationMap.get(operation.name());
			if(rulesForOperation == null)
			{
				rulesForOperation = new List<ValidationRuleWithGroup>();
				operationMap.put(operation.name(), rulesForOperation);
			}

			for(ValidationRule__mdt rule : childRules)
			{
				rulesForOperation.add(new ValidationRuleWithGroup(rule, ruleGroup));
			}
		}
	}

	/**
	 * @description Resolves the trigger operations for a validation rule group based on
	 * its TriggerTiming__c and TriggerOperations__c semicolon-separated values.
	 *
	 * Combines timing (Before/After) with operations (Insert/Update/Delete/Undelete) to
	 * produce valid TriggerOperation enum values. Invalid combinations (e.g., BEFORE_UNDELETE)
	 * are excluded as they don't exist in Salesforce.
	 *
	 * @param ruleGroup The validation rule group
	 *
	 * @return Set of applicable TriggerOperation enum values
	 */
	private static Set<TriggerOperation> resolveOperations(ValidationRuleGroup__mdt ruleGroup)
	{
		Set<TriggerOperation> operations = new Set<TriggerOperation>();

		if(String.isBlank(ruleGroup.TriggerTiming__c) || String.isBlank(ruleGroup.TriggerOperations__c))
		{
			return operations;
		}

		Set<String> timings = new Set<String>(ruleGroup.TriggerTiming__c.split(UTIL_String.SEMI_COLON));
		Set<String> dmlOperations = new Set<String>(ruleGroup.TriggerOperations__c.split(UTIL_String.SEMI_COLON));

		for(String timing : timings)
		{
			for(String dmlOp : dmlOperations)
			{
				String combinedKey = timing.trim().toUpperCase() + '_' + dmlOp.trim().toUpperCase();
				TriggerOperation operation = TRIGGER_OPERATION_MAP.get(combinedKey);
				if(operation != null)
				{
					operations.add(operation);
				}
			}
		}

		return operations;
	}

	/**
	 * @description Gets all unique developer names of feature flags referenced by validation rules and groups.
	 * Used for preloading feature flag checks.
	 *
	 * @return Set of feature flag developer names
	 */
	public static Set<String> getAllReferencedFeatureFlags()
	{
		Set<String> featureFlags = new Set<String>();

		for(Map<String, List<ValidationRuleWithGroup>> operationMap : cachedRulesByObjectAndOperation.values())
		{
			for(List<ValidationRuleWithGroup> rules : operationMap.values())
			{
				collectFeatureFlagsFromRules(rules, featureFlags);
			}
		}

		return featureFlags;
	}

	/**
	 * @description Collects feature flag names from a list of validation rules.
	 *
	 * @param rules The rules to collect feature flags from
	 * @param featureFlags The set to add feature flag names to
	 */
	private static void collectFeatureFlagsFromRules(List<ValidationRuleWithGroup> rules, Set<String> featureFlags)
	{
		for(ValidationRuleWithGroup ruleWrapper : rules)
		{
			addIfNotBlank(featureFlags, ruleWrapper.ruleGroup.RequiredFeatureFlag__r?.DeveloperName);
			addIfNotBlank(featureFlags, ruleWrapper.ruleGroup.BypassFeatureFlag__r?.DeveloperName);
			addIfNotBlank(featureFlags, ruleWrapper.rule.BypassFeatureFlag__r?.DeveloperName);
			addIfNotBlank(featureFlags, ruleWrapper.rule.RequiredFeatureFlag__r?.DeveloperName);
		}
	}

	/**
	 * @description Adds a value to a set if it's not blank.
	 *
	 * @param targetSet The set to add to
	 * @param value The value to add
	 */
	private static void addIfNotBlank(Set<String> targetSet, String value)
	{
		if(String.isNotBlank(value))
		{
			targetSet.add(value);
		}
	}
}