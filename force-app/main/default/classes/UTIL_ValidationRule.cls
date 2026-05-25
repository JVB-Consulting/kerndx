// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Formula-driven declarative validation framework for advanced validation scenarios
 * that standard Salesforce validation rules cannot handle.
 *
 * This framework enables:
 * - Cross-object validation requiring queries
 * - Complex conditional logic exceeding native formula limits
 * - Validation with sophisticated bypass rules
 * - Shadow mode for safe production testing
 * - Warning severity that logs but allows save
 *
 * **Important:** This framework complements standard validation rules. Use native Salesforce
 * validation rules for simple field checks. Use this framework for advanced scenarios.
 *
 * ## Usage Patterns
 *
 * ### Trigger Integration (Recommended)
 * Configure via `TRG_ExecuteValidationRules` trigger action:
 * ```apex
 * // No code required - configure via TriggerAction__mdt to use TRG_ExecuteValidationRules
 * ```
 *
 * ### Direct Programmatic Usage
 * ```apex
 * // Validate records programmatically
 * List<UTIL_ValidationRule.ValidationResult> results =
 *     UTIL_ValidationRule.validate(Trigger.new, Trigger.old, TriggerOperation.BEFORE_INSERT);
 *
 * // Apply errors to records
 * UTIL_ValidationRule.applyErrors(Trigger.new, results);
 * ```
 *
 * ### Bypass Usage
 * ```apex
 * // Bypass all validation for an object
 * UTIL_ValidationRule.bypassObject('Account');
 * try
 * {
 *     insert accounts;
 * }
 * finally
 * {
 *     UTIL_ValidationRule.clearBypass('Account');
 * }
 * ```
 *
 * @see SEL_ValidationRules
 * @see ValidationRuleGroup__mdt
 * @see ValidationRule__mdt
 * @see TRG_ExecuteValidationRules
 *
 * @author Jason van Beukering
 *
 * @group Validation
 *
 * @date January 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * List<UTIL_ValidationRule.ValidationResult> results =
 *     UTIL_ValidationRule.validate(Trigger.new, Trigger.old, TriggerOperation.BEFORE_UPDATE);
 * UTIL_ValidationRule.applyErrors(Trigger.new, results);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.ExcessiveClassLength,PMD.CyclomaticComplexity,PMD.CognitiveComplexity')
global inherited sharing class UTIL_ValidationRule
{
	/**
	 * @description Severity level for errors that block save.
	 */
	public static final String SEVERITY_ERROR = 'Error';

	/**
	 * @description Severity level for warnings that log but allow save.
	 */
	public static final String SEVERITY_WARNING = 'Warning';

	/**
	 * @description Tag used in log messages for shadow mode violations.
	 */
	private static final String SHADOW_TAG = '[SHADOW]';

	/**
	 * @description Execution strategy value for fail-fast mode (stop after first error per record).
	 */
	private static final String STRATEGY_FAIL_FAST = 'Fail Fast';

	/**
	 * @description Compiled pattern for merge fields in error messages.
	 * Matches Salesforce merge field syntax: {!PropertyName} or {!path.to.Property}
	 */
	private static final Pattern MERGE_FIELD_PATTERN = Pattern.compile('\\{!([^}]+)\\}');

	/**
	 * @description Set of object API names bypassed for the current transaction.
	 */
	private static final Set<String> BYPASSED_OBJECTS = new Set<String>();

	/**
	 * @description Set of group developer names bypassed for the current transaction.
	 */
	private static final Set<String> BYPASSED_GROUPS = new Set<String>();

	/**
	 * @description Set of rule developer names bypassed for the current transaction.
	 */
	private static final Set<String> BYPASSED_RULES = new Set<String>();

	/**
	 * @description Cache of formula instances keyed by rule DeveloperName.
	 */
	private static final Map<String, FormulaEval.FormulaInstance> FORMULA_CACHE = new Map<String, FormulaEval.FormulaInstance>();

	/**
	 * @description Cache of context instances keyed by context class name.
	 */
	private static final Map<String, UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext> CONTEXT_CACHE =
			new Map<String, UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext>();

	/**
	 * @description Types of validation bypasses available. Used internally for Flow integration.
	 */
	public enum VALIDATION_BYPASS_TYPE
	{
		/**
		 * @description Bypass all validation rules for an object
		 */
		OBJECT_NAME,
		/**
		 * @description Bypass all validation rules in a specific group
		 */
		GROUP_NAME,
		/**
		 * @description Bypass a single validation rule by name
		 */
		RULE_NAME
	}

	/**
	 * @description Types of clear operations available. Used internally for Flow integration.
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	public enum VALIDATION_CLEAR_TYPE
	{
		/**
		 * @description Clear a single bypass by name
		 */
		SINGLE,
		/**
		 * @description Clear all active bypasses
		 */
		ALL
	}

	/**
	 * @description Result of validating a single record.
	 * Contains all validation errors/warnings for that record.
	 *
	 * @since 1.0
	 */
	global class ValidationResult
	{
		/**
		 * @description The index of the record in the trigger list (for before insert correlation).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer value = instance.recordIndex;
		 * ```
		 */
		global Integer recordIndex;

		/**
		 * @description The record ID (available in all contexts except before insert).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Id value = instance.recordId;
		 * ```
		 */
		global Id recordId;
		/**
		 * @description True if the record passed all validation rules.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean value = instance.isValid;
		 * ```
		 */
		global Boolean isValid
		{
			get
			{
				return errors.isEmpty() || !hasBlockingErrors();
			}
		}

		/**
		 * @description List of validation errors/warnings for this record.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<ValidationError> value = instance.errors;
		 * ```
		 */
		global List<ValidationError> errors
		{
			get
			{
				if(errors == null)
				{
					errors = new List<ValidationError>();
				}
				return errors;
			}
			set;
		}

		/**
		 * @description Constructs a new ValidationResult for the given record.
		 *
		 * @param recordIndex The index in the trigger list
		 * @param recordId The record ID (may be null for before insert)
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_ValidationRule.ValidationResult instance = new UTIL_ValidationRule.ValidationResult(10, recordId);
		 * ```
		 */
		global ValidationResult(Integer recordIndex, Id recordId)
		{
			this.recordIndex = recordIndex;
			this.recordId = recordId;
		}

		/**
		 * @description Gets concatenated error message string.
		 *
		 * @return All error messages joined by newlines
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String result = instance.getErrorMessage();
		 * ```
		 */
		global String getErrorMessage()
		{
			List<String> messages = new List<String>();
			for(ValidationError error : errors)
			{
				messages.add(error.message);
			}
			return String.join(messages, '\n');
		}

		/**
		 * @description Gets errors filtered by severity.
		 *
		 * @param severity The severity to filter by ('Error' or 'Warning')
		 *
		 * @return List of errors matching the severity
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<ValidationError> result = instance.getErrorsBySeverity('Error');
		 * ```
		 */
		global List<ValidationError> getErrorsBySeverity(String severity)
		{
			List<ValidationError> filtered = new List<ValidationError>();
			for(ValidationError error : errors)
			{
				if(error.severity == severity)
				{
					filtered.add(error);
				}
			}
			return filtered;
		}

		/**
		 * @description Checks if this result has any blocking (Error severity) errors.
		 *
		 * @return True if there are Error severity violations
		 */
		private Boolean hasBlockingErrors()
		{
			for(ValidationError error : errors)
			{
				if(error.severity == SEVERITY_ERROR && !error.shadowMode)
				{
					return true;
				}
			}
			return false;
		}
	}

	/**
	 * @description Represents a single validation error or warning.
	 *
	 * @since 1.0
	 */
	global class ValidationError
	{
		/**
		 * @description The DeveloperName of the validation rule that failed.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.ruleName;
		 * ```
		 */
		@AuraEnabled
		global String ruleName;

		/**
		 * @description The error message to display.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.message;
		 * ```
		 */
		@AuraEnabled
		global String message;

		/**
		 * @description The field API name to display the error on (may be null for page-level).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.fieldName;
		 * ```
		 */
		@AuraEnabled
		global String fieldName;

		/**
		 * @description The severity ('Error' or 'Warning').
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.severity;
		 * ```
		 */
		@AuraEnabled
		global String severity;

		/**
		 * @description The record index in the trigger list (for before insert).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer value = instance.recordIndex;
		 * ```
		 */
		@AuraEnabled
		global Integer recordIndex;

		/**
		 * @description The record ID (available except in before insert).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Id value = instance.recordId;
		 * ```
		 */
		@AuraEnabled
		global Id recordId;

		/**
		 * @description True if this error is from a rule in shadow mode.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean value = instance.shadowMode;
		 * ```
		 */
		@AuraEnabled
		global Boolean shadowMode;

		/**
		 * @description The validation rule group DeveloperName.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.groupName;
		 * ```
		 */
		@AuraEnabled
		global String groupName;

		/**
		 * @description Constructs a new ValidationError.
		 *
		 * @param ruleName The rule DeveloperName
		 * @param message The error message
		 * @param fieldName The field API name (may be null)
		 * @param severity The severity level
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_ValidationRule.ValidationError instance = new UTIL_ValidationRule.ValidationError('myName', 'An error occurred', 'myName', 'Error');
		 * ```
		 */
		global ValidationError(String ruleName, String message, String fieldName, String severity)
		{
			this.ruleName = ruleName;
			this.message = message;
			this.fieldName = fieldName;
			this.severity = severity;
			this.shadowMode = false;
		}
	}

	/**
	 * @description Optional interface for bulk-optimized validation contexts.
	 * Implement this in addition to INT_SObjectFormulaEvaluationContext when your
	 * context class needs to query related data.
	 *
	 * The `preLoad()` method is called once per batch of records BEFORE the record loop,
	 * allowing you to perform bulk queries and cache results for use in `setContext()`.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * global class VAL_AccountWithContactsContext
	 *     implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext,
	 *                UTIL_ValidationRule.INT_BulkValidationContext
	 * {
	 *     private Map<Id, Integer> contactCountByAccountId = new Map<Id, Integer>();
	 *     global Integer ContactCount { get; set; }
	 *     global void preLoad(List<SObject> newRecords, List<SObject> oldRecords)
	 *     {
	 *         Set<Id> accountIds = UTIL_SObject.extractIds(newRecords);
	 *         List<AggregateResult> results = QRY_Builder.selectFrom(Contact.SObjectType)
	 *             .count('Id')
	 *             .groupBy(Contact.AccountId)
	 *             .condition(Contact.AccountId).isIn(new List<Id>(accountIds))
	 *             .toList();
	 *         for(AggregateResult result : results)
	 *         {
	 *             contactCountByAccountId.put((Id)result.get('AccountId'), (Integer)result.get('count_Id'));
	 *         }
	 *     }
	 *     global void setContext(SObject oldRecord, SObject newRecord)
	 *     {
	 *         Account account = (Account)newRecord;
	 *         this.ContactCount = contactCountByAccountId.get(account.Id) ?? 0;
	 *     }
	 * }
	 * ```
	 */
	global interface INT_BulkValidationContext
	{
		/**
		 * @description Called once per batch before the record loop.
		 * Use this to perform bulk queries and cache results.
		 *
		 * @param newRecords The list of new records (Trigger.new)
		 * @param oldRecords The list of old records (Trigger.old), may be null for insert
		 *
		 * @since 1.0
		 */
		void preLoad(List<SObject> newRecords, List<SObject> oldRecords);
	}

	/**
	 * @description Bypasses all validation rules for the specified object.
	 * This is the highest level of bypass and takes precedence over group and rule bypasses.
	 *
	 * @param objectApiName The API name of the object to bypass (e.g., 'Account')
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_ValidationRule.bypassObject('Account');
	 * try
	 * {
	 *     insert accounts; // No validation rules fire
	 * }
	 * finally
	 * {
	 *     UTIL_ValidationRule.clearBypass('Account');
	 * }
	 * ```
	 */
	global static void bypassObject(String objectApiName)
	{
		if(String.isNotBlank(objectApiName))
		{
			BYPASSED_OBJECTS.add(objectApiName);
			UTIL_BypassAudit.emit(UTIL_BypassAudit.SURFACE_VALIDATION, UTIL_BypassAudit.ACTION_BYPASS, UTIL_BypassAudit.TARGET_PREFIX_OBJECT + objectApiName, null);
		}
	}

	/**
	 * @description Bypasses all validation rules in the specified group.
	 *
	 * @param groupDeveloperName The DeveloperName of the ValidationRuleGroup__mdt to bypass
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_ValidationRule.bypassGroup('SalesCloud_Account_Validations');
	 * ```
	 */
	global static void bypassGroup(String groupDeveloperName)
	{
		if(String.isNotBlank(groupDeveloperName))
		{
			BYPASSED_GROUPS.add(groupDeveloperName);
			UTIL_BypassAudit.emit(UTIL_BypassAudit.SURFACE_VALIDATION, UTIL_BypassAudit.ACTION_BYPASS, UTIL_BypassAudit.TARGET_PREFIX_GROUP + groupDeveloperName, null);
		}
	}

	/**
	 * @description Bypasses a specific validation rule.
	 *
	 * @param ruleDeveloperName The DeveloperName of the ValidationRule__mdt to bypass
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_ValidationRule.bypassRule('Account_Requires_Primary_Contact');
	 * ```
	 */
	global static void bypassRule(String ruleDeveloperName)
	{
		if(String.isNotBlank(ruleDeveloperName))
		{
			BYPASSED_RULES.add(ruleDeveloperName);
			UTIL_BypassAudit.emit(UTIL_BypassAudit.SURFACE_VALIDATION, UTIL_BypassAudit.ACTION_BYPASS, UTIL_BypassAudit.TARGET_PREFIX_RULE + ruleDeveloperName, null);
		}
	}

	/**
	 * @description Sets a validation bypass based on the bypass type. Used internally for Flow integration.
	 *
	 * @param name The identifier (object API name, group DeveloperName, or rule DeveloperName)
	 * @param bypassType The type of bypass
	 */
	public static void bypass(String name, VALIDATION_BYPASS_TYPE bypassType)
	{
		switch on bypassType
		{
			when OBJECT_NAME
			{
				bypassObject(name);
			}
			when GROUP_NAME
			{
				bypassGroup(name);
			}
			when RULE_NAME
			{
				bypassRule(name);
			}
		}
	}

	/**
	 * @description Clears a specific bypass (object, group, or rule).
	 *
	 * @param identifier The object API name, group DeveloperName, or rule DeveloperName to clear
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_ValidationRule.clearBypass('value');
	 * ```
	 */
	global static void clearBypass(String identifier)
	{
		BYPASSED_OBJECTS.remove(identifier);
		BYPASSED_GROUPS.remove(identifier);
		BYPASSED_RULES.remove(identifier);
		UTIL_BypassAudit.emit(UTIL_BypassAudit.SURFACE_VALIDATION, UTIL_BypassAudit.ACTION_CLEAR, identifier, null);
	}

	/**
	 * @description Clears all bypasses for the current transaction.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_ValidationRule.clearAllBypasses();
	 * ```
	 */
	global static void clearAllBypasses()
	{
		BYPASSED_OBJECTS.clear();
		BYPASSED_GROUPS.clear();
		BYPASSED_RULES.clear();
		UTIL_BypassAudit.emit(UTIL_BypassAudit.SURFACE_VALIDATION, UTIL_BypassAudit.ACTION_CLEAR_ALL, UTIL_BypassAudit.TARGET_ALL, null);
	}

	/**
	 * @description Checks if a specific bypass is currently active.
	 *
	 * @param identifier The object API name, group DeveloperName, or rule DeveloperName
	 *
	 * @return True if bypassed
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Boolean result = UTIL_ValidationRule.isBypassed('value');
	 * ```
	 */
	global static Boolean isBypassed(String identifier)
	{
		return BYPASSED_OBJECTS.contains(identifier) ||
				BYPASSED_GROUPS.contains(identifier) ||
				BYPASSED_RULES.contains(identifier);
	}

	/**
	 * @description Executes validation rules for the current trigger context.
	 * This is the main entry point for trigger-based validation.
	 *
	 * @param newRecords The list of new records (Trigger.new)
	 * @param oldRecords The list of old records (Trigger.old), may be null for insert
	 * @param operation The trigger operation
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // In a trigger action class
	 * UTIL_ValidationRule.executeForTrigger(newRecords, oldRecords, TriggerOperation.BEFORE_UPDATE);
	 * ```
	 */
	global static void executeForTrigger(List<SObject> newRecords, List<SObject> oldRecords, TriggerOperation operation)
	{
		if(newRecords == null || newRecords.isEmpty())
		{
			return;
		}

		List<ValidationResult> results = validate(newRecords, oldRecords, operation);
		applyErrors(newRecords, results);
	}

	/**
	 * @description Validates a list of records against all applicable validation rules.
	 *
	 * @param newRecords The list of new records to validate
	 * @param oldRecords The list of old records (may be null for insert)
	 * @param operation The trigger operation determining which rules apply
	 *
	 * @return List of ValidationResult objects, one per record
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ValidationResult> result = UTIL_ValidationRule.validate(records, records, TriggerOperation.BEFORE_INSERT);
	 * ```
	 */
	global static List<ValidationResult> validate(List<SObject> newRecords, List<SObject> oldRecords, TriggerOperation operation)
	{
		List<ValidationResult> results = new List<ValidationResult>();

		if(newRecords == null || newRecords.isEmpty())
		{
			return results;
		}

		// Get object API name from the first record
		String objectApiName = String.valueOf(newRecords[0].getSObjectType());

		// Check object-level bypass
		if(BYPASSED_OBJECTS.contains(objectApiName))
		{
			return createEmptyResults(newRecords);
		}

		// Get applicable validation rules
		List<SEL_ValidationRules.ValidationRuleWithGroup> ruleWrappers =
				SEL_ValidationRules.findByObjectAndOperation(objectApiName, operation);

		if(ruleWrappers.isEmpty())
		{
			return createEmptyResults(newRecords);
		}

		// Group rules by context class for efficient processing
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> rulesByContext = groupRulesByContext(ruleWrappers, objectApiName);

		// Initialize results
		results = createEmptyResults(newRecords);

		// Process each context group
		for(String contextClassName : rulesByContext.keySet())
		{
			List<SEL_ValidationRules.ValidationRuleWithGroup> contextRules = rulesByContext.get(contextClassName);

			// Time the entire context processing (preLoad + all formula evaluations)
			UTIL_PerformanceTimer timer = new UTIL_PerformanceTimer(contextClassName, UTIL_ValidationRule.class.getName() + '/processRulesForContext');
			timer.start();
			processRulesForContext(contextClassName, contextRules, newRecords, oldRecords, results);
			Long elapsedMs = timer.stopSilent();

			// Log validation performance if enabled and threshold exceeded
			logValidationPerformanceIfNeeded(contextClassName, contextRules.size(), newRecords.size(), elapsedMs);
		}

		return results;
	}

	/**
	 * @description Applies validation errors to the trigger records.
	 * Error severity violations call record.addError() to block save.
	 * Warning severity violations are logged but don't block save.
	 *
	 * **Page-level addError calls coalesce in Database.SaveResult.** When the validation rule
	 * targets the whole record (i.e. `kern__ErrorDisplayField__c` is blank — page-level error),
	 * each violation invokes `record.addError(message)`. Salesforce's platform behaviour for
	 * page-level addError is to COALESCE multiple calls on the same record into a SINGLE
	 * `Database.SaveResult.Error` entry — only the LAST rule's message is surfaced via
	 * `getErrors()`. Field-level addError (`record.addError(field, message)`, used when
	 * `kern__ErrorDisplayField__c` is set) is per-field unique and does NOT coalesce.
	 *
	 * Subscribers that want to see ALL violations on a record should consult the framework's
	 * own `ValidationResult.errors` collection, which preserves every violation regardless of
	 * page vs field scope. The `Database.SaveResult.getErrors()` collection should be treated
	 * as a "save blocked" / "save succeeded" boolean, not as a complete error inventory.
	 *
	 * Empirically: a record violating two page-level rules (e.g. `RequireAccountIndustry` +
	 * `PhoneOrWebsiteRequired`) returns `getErrors().size() == 1` with only the second rule's
	 * message — but `ValidationResult.errors.size() == 2` reports both correctly.
	 *
	 * @param records The list of records (Trigger.new)
	 * @param results The validation results
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_ValidationRule.applyErrors(records, new List<ValidationResult>());
	 * ```
	 */
	global static void applyErrors(List<SObject> records, List<ValidationResult> results)
	{
		if(records == null || results == null)
		{
			return;
		}

		for(ValidationResult result : results)
		{
			if(result.errors.isEmpty())
			{
				continue;
			}

			SObject record = records[result.recordIndex];

			for(ValidationError error : result.errors)
			{
				if(error.shadowMode)
				{
					// Shadow mode - log but don't block
					logShadowViolation(error, record);
				}
				else if(error.severity == SEVERITY_ERROR)
				{
					// Error severity - block save
					applyErrorToRecord(record, error);
				}
				else if(error.severity == SEVERITY_WARNING)
				{
					// Warning severity - log but don't block
					logWarning(error, record);
				}
			}
		}
	}

	/**
	 * @description Groups validation rules by their resolved context class name.
	 *
	 * @param ruleWrappers The list of rule wrappers to group
	 * @param objectApiName The object API name for resolving default contexts
	 *
	 * @return Map of context class name to list of rule wrappers
	 */
	private static Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> groupRulesByContext
			(
					List<SEL_ValidationRules.ValidationRuleWithGroup> ruleWrappers,
					String objectApiName
			)
	{
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> rulesByContext =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();

		for(SEL_ValidationRules.ValidationRuleWithGroup ruleWrapper : ruleWrappers)
		{
			String contextClassName = resolveContextClassName(ruleWrapper, objectApiName);

			if(String.isBlank(contextClassName))
			{
				// Log error and skip rule if no context can be resolved
				LOG_Builder.build()
						.error('Validation rule "' + ruleWrapper.rule.DeveloperName + '" has no context class and object "' + objectApiName + '" has no built-in context. Rule skipped.')
						.withSummary('Missing context class for validation rule')
						.at(UTIL_ValidationRule.class.getName() + '/groupRulesByContext')
						.emit();
				continue;
			}

			List<SEL_ValidationRules.ValidationRuleWithGroup> contextRules = rulesByContext.get(contextClassName);
			if(contextRules == null)
			{
				contextRules = new List<SEL_ValidationRules.ValidationRuleWithGroup>();
				rulesByContext.put(contextClassName, contextRules);
			}
			contextRules.add(ruleWrapper);
		}

		return rulesByContext;
	}

	/**
	 * @description Resolves the context class name for a validation rule.
	 * Priority: Rule > Group > Auto-detected standard object context
	 *
	 * @param ruleWrapper The rule wrapper
	 * @param objectApiName The object API name
	 *
	 * @return The resolved context class name, or null if none available
	 */
	private static String resolveContextClassName(SEL_ValidationRules.ValidationRuleWithGroup ruleWrapper, String objectApiName)
	{
		// Rule-level override takes precedence
		if(String.isNotBlank(ruleWrapper.rule.ContextClassName__c))
		{
			return ruleWrapper.rule.ContextClassName__c;
		}

		// Group-level context
		if(String.isNotBlank(ruleWrapper.ruleGroup.ContextClassName__c))
		{
			return ruleWrapper.ruleGroup.ContextClassName__c;
		}

		// Auto-detect for standard objects
		return UTIL_FormulaFilter.resolveContextClass(objectApiName, null);
	}

	/**
	 * @description Processes validation rules for a specific context class.
	 *
	 * @param contextClassName The context class name
	 * @param ruleWrappers The rules using this context
	 * @param newRecords The new records
	 * @param oldRecords The old records
	 * @param results The results to populate
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static void processRulesForContext
			(
					String contextClassName,
					List<SEL_ValidationRules.ValidationRuleWithGroup> ruleWrappers,
					List<SObject> newRecords,
					List<SObject> oldRecords,
					List<ValidationResult> results
			)
	{
		// Get or create context instance
		UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext context = getOrCreateContext(contextClassName);

		if(context == null)
		{
			LOG_Builder.build()
					.error('Failed to instantiate context class "' + contextClassName + '". Rules using this context skipped.')
					.at(UTIL_ValidationRule.class.getName() + '/processRulesForContext')
					.emit();
			return;
		}

		// Call preLoad if context implements bulk interface
		if(context instanceof INT_BulkValidationContext)
		{
			((INT_BulkValidationContext)context).preLoad(newRecords, oldRecords);
		}

		// Process each record
		for(Integer i = 0; i < newRecords.size(); i++)
		{
			SObject newRecord = newRecords[i];
			SObject oldRecord = oldRecords != null && i < oldRecords.size() ? oldRecords[i] : null;
			ValidationResult result = results[i];

			// Set context for this record
			context.setContext(oldRecord, newRecord);

			// Evaluate each rule
			for(SEL_ValidationRules.ValidationRuleWithGroup ruleWrapper : ruleWrappers)
			{
				// Check bypasses
				if(isRuleBypassed(ruleWrapper))
				{
					continue;
				}

				// Check condition/permission bypasses
				if(!shouldExecuteRule(ruleWrapper))
				{
					continue;
				}

				// Track error count before evaluation for fail-fast check
				Integer errorCountBefore = result.errors.size();

				// Evaluate the rule formula
				evaluateRule(ruleWrapper, context, result, i, newRecord.Id);

				// Fail-fast: stop processing remaining rules for this record if error was added
				if(STRATEGY_FAIL_FAST.equals(ruleWrapper.ruleGroup.ExecutionStrategy__c) &&
						result.errors.size() > errorCountBefore)
				{
					break;
				}
			}
		}
	}

	/**
	 * @description Gets or creates a context instance for the given class name.
	 *
	 * @param contextClassName The fully qualified class name
	 *
	 * @return The context instance, or null if creation failed
	 */
	private static UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext getOrCreateContext(String contextClassName)
	{
		if(CONTEXT_CACHE.containsKey(contextClassName))
		{
			return CONTEXT_CACHE.get(contextClassName);
		}

		try
		{
			Type contextType = UTIL_System.getTypeForClassName(contextClassName, UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.class);
			UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext context =
					(UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext)contextType.newInstance();
			CONTEXT_CACHE.put(contextClassName, context);
			return context;
		}
		catch(Exception error)
		{
			LOG_Builder.build().error(error).at(UTIL_ValidationRule.class.getName() + '/getOrCreateContext').emit();
			return null;
		}
	}

	/**
	 * @description Checks if a rule is bypassed via programmatic bypass.
	 *
	 * @param ruleWrapper The rule wrapper to check
	 *
	 * @return True if the rule should be skipped
	 */
	private static Boolean isRuleBypassed(SEL_ValidationRules.ValidationRuleWithGroup ruleWrapper)
	{
		// Check group bypass
		if(BYPASSED_GROUPS.contains(ruleWrapper.ruleGroup.DeveloperName))
		{
			return true;
		}

		// Check rule bypass
		if(BYPASSED_RULES.contains(ruleWrapper.rule.DeveloperName))
		{
			return true;
		}

		return false;
	}

	/**
	 * @description Checks if a rule should execute based on feature flag conditions.
	 *
	 * @param ruleWrapper The rule wrapper to check
	 *
	 * @return True if the rule should execute
	 */
	private static Boolean shouldExecuteRule(SEL_ValidationRules.ValidationRuleWithGroup ruleWrapper)
	{
		if(UTIL_FeatureFlag.isEnabled(ruleWrapper.ruleGroup.BypassFeatureFlag__r?.DeveloperName))
		{
			return false;
		}

		if(ruleWrapper.ruleGroup.RequiredFeatureFlag__c != null && !UTIL_FeatureFlag.isEnabled(ruleWrapper.ruleGroup.RequiredFeatureFlag__r?.DeveloperName))
		{
			return false;
		}

		if(UTIL_FeatureFlag.isEnabled(ruleWrapper.rule.BypassFeatureFlag__r?.DeveloperName))
		{
			return false;
		}

		if(ruleWrapper.rule.RequiredFeatureFlag__c != null && !UTIL_FeatureFlag.isEnabled(ruleWrapper.rule.RequiredFeatureFlag__r?.DeveloperName))
		{
			return false;
		}

		return true;
	}

	/**
	 * @description Evaluates a single validation rule formula against a record.
	 *
	 * @param ruleWrapper The rule wrapper
	 * @param context The populated context instance
	 * @param result The result to add errors to
	 * @param recordIndex The record index
	 * @param recordId The record ID
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static void evaluateRule
			(
					SEL_ValidationRules.ValidationRuleWithGroup ruleWrapper,
					UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext context,
					ValidationResult result,
					Integer recordIndex,
					Id recordId
			)
	{
		ValidationRule__mdt rule = ruleWrapper.rule;

		try
		{
			FormulaEval.FormulaInstance formulaInstance = getOrCreateFormula(rule, context);
			Boolean formulaResult = (Boolean)formulaInstance.evaluate(context);

			// Formula returning TRUE means validation FAILED
			if(formulaResult)
			{
				// Process error message with merge fields
				String errorMessage = processMergeFields(rule.ErrorMessage__c, context);

				ValidationError error = new ValidationError
						(
								rule.DeveloperName,
								errorMessage,
								rule.ErrorDisplayField__c,
								rule.Severity__c
						);
				error.recordIndex = recordIndex;
				error.recordId = recordId;
				error.shadowMode = rule.ShadowMode__c;
				error.groupName = ruleWrapper.ruleGroup.DeveloperName;

				result.errors.add(error);
			}
		}
		catch(Exception e)
		{
			// Log formula evaluation error but don't block save
			LOG_Builder.build()
					.error('Validation rule "' + rule.DeveloperName + '" formula evaluation failed: ' + e.getMessage())
					.withSummary('Formula evaluation failed for validation rule')
					.at(UTIL_ValidationRule.class.getName() + '/evaluateRule')
					.emit();
		}
	}

	/**
	 * @description Gets or creates a formula instance for a validation rule.
	 * Uses the shared buildBooleanFormula() method from UTIL_FormulaFilter for consistent formula building.
	 *
	 * @param rule The validation rule
	 * @param context The context instance (used for type resolution)
	 *
	 * @return The formula instance
	 */
	private static FormulaEval.FormulaInstance getOrCreateFormula
			(
					ValidationRule__mdt rule,
					UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext context
			)
	{
		String cacheKey = rule.DeveloperName;

		if(FORMULA_CACHE.containsKey(cacheKey))
		{
			return FORMULA_CACHE.get(cacheKey);
		}

		Type contextType = UTIL_System.getTypeForClassName(UTIL_System.getRuntimeTypeName(context));
		FormulaEval.FormulaInstance formulaInstance = UTIL_FormulaFilter.buildBooleanFormula
				(
						rule.RuleFormula__c,
						contextType,
						'ValidationRule:' + rule.DeveloperName
				);

		FORMULA_CACHE.put(cacheKey, formulaInstance);
		return formulaInstance;
	}

	/**
	 * @description Processes merge fields in error messages.
	 * Supports {!PropertyName} syntax for context properties.
	 *
	 * @param template The message template with merge fields
	 * @param context The context object to pull values from
	 *
	 * @return The processed message with merge fields replaced
	 */
	@TestVisible
	private static String processMergeFields(String template, Object context)
	{
		if(String.isBlank(template) || context == null)
		{
			return template;
		}

		Matcher matcher = MERGE_FIELD_PATTERN.matcher(template);

		String result = template;

		while(matcher.find())
		{
			String fieldPath = matcher.group(1);
			String replacement = getMergeFieldValue(context, fieldPath);
			result = result.replace('{!' + fieldPath + '}', replacement);
		}

		return result;
	}

	/**
	 * @description Gets the value of a merge field from a context object.
	 *
	 * @param context The context object
	 * @param fieldPath The field path (e.g., 'newRecord.Name')
	 *
	 * @return The string value of the field
	 */
	@TestVisible
	private static String getMergeFieldValue(Object context, String fieldPath)
	{
		try
		{
			// Use JSON serialization and parsing to access properties dynamically
			String contextJson = JSON.serialize(context);
			Map<String, Object> contextMap = (Map<String, Object>)JSON.deserializeUntyped(contextJson);

			// Navigate the field path

			List<String> pathParts = fieldPath.split('\\.');
			Object currentValue = contextMap;

			for(String part : pathParts)
			{
				if(currentValue == null)
				{
					return UTIL_String.EMPTY;
				}

				if(currentValue instanceof Map<String, Object>)
				{
					currentValue = ((Map<String, Object>)currentValue).get(part);
				}
				else
				{
					return UTIL_String.EMPTY;
				}
			}

			return currentValue != null ? String.valueOf(currentValue) : UTIL_String.EMPTY;
		}
		catch(Exception e)
		{
			return UTIL_String.EMPTY;
		}
	}

	/**
	 * @description Applies an error to a record, optionally to a specific field.
	 *
	 * @param record The record to apply the error to
	 * @param error The validation error
	 */
	@TestVisible
	private static void applyErrorToRecord(SObject record, ValidationError error)
	{
		if(String.isNotBlank(error.fieldName))
		{
			record.addError(error.fieldName, error.message);
		}
		else
		{
			record.addError(error.message);
		}
	}

	/**
	 * @description Logs a shadow mode violation without blocking save.
	 * The short message includes both the rule name and error message
	 * in the format: "[SHADOW] Rule_Name: Error message text..."
	 *
	 * @param error The validation error
	 * @param record The record that failed validation
	 */
	@TestVisible
	private static void logShadowViolation(ValidationError error, SObject record)
	{
		String shortMessage = SHADOW_TAG + ' ' + error.ruleName + ': ' + error.message;

		String longMessage = 'Validation rule "' + error.ruleName + '" would have failed for ' +
				UTIL_SObjectDescribe.getObjectNameFromType(record.getSObjectType()) +
				' (Index: ' + error.recordIndex + '): ' + error.message;

		LOG_Builder.build().warn(longMessage).withSummary(shortMessage).at(UTIL_ValidationRule.class.getName() + '/logShadowViolation').emit();
	}

	/**
	 * @description Logs a warning severity violation.
	 *
	 * @param error The validation error
	 * @param record The record that failed validation
	 */
	@TestVisible
	private static void logWarning(ValidationError error, SObject record)
	{
		String message = 'Validation warning "' + error.ruleName + '" for ' +
				UTIL_SObjectDescribe.getObjectNameFromType(record.getSObjectType()) +
				' (Index: ' + error.recordIndex + '): ' + error.message;

		LOG_Builder.build().warn(message).at(UTIL_ValidationRule.class.getName() + '/executeForTrigger').emit();
	}

	/**
	 * @description Creates empty ValidationResult objects for each record.
	 * Used when validation is bypassed or no rules apply.
	 *
	 * @param records The records to create results for
	 *
	 * @return List of empty ValidationResult objects
	 */
	private static List<ValidationResult> createEmptyResults(List<SObject> records)
	{
		List<ValidationResult> results = new List<ValidationResult>();
		for(Integer i = 0; i < records.size(); i++)
		{
			results.add(new ValidationResult(i, records[i].Id));
		}
		return results;
	}

	/**
	 * @description Logs validation context performance if enabled and threshold exceeded.
	 * Uses validation-specific LogSetting__c fields for independent control.
	 * Pushes validation context onto the operation stack for nested tracing within trigger actions.
	 *
	 * @param contextClassName The validation context class name
	 * @param ruleCount Number of rules processed for this context
	 * @param recordCount Number of records validated
	 * @param elapsedMs The elapsed time in milliseconds
	 */
	private static void logValidationPerformanceIfNeeded(String contextClassName, Integer ruleCount, Integer recordCount, Long elapsedMs)
	{
		LogSetting__c setting = LOG_Engine.getLogSetting();

		if(setting.EnableValidationPerformanceLogging__c != true)
		{
			return;
		}

		Long threshold = (Long)setting.ValidationPerformanceThresholdMs__c;

		if(elapsedMs < threshold)
		{
			return;
		}

		// Build validation context for nested tracing
		Map<String, String> validationContext = new Map<String, String>
		{
				LOG_Engine.CONTEXT_CONTEXT_CLASS_NAME => contextClassName,
				LOG_Engine.CONTEXT_RULE_COUNT => String.valueOf(ruleCount),
				LOG_Engine.CONTEXT_RECORD_COUNT => String.valueOf(recordCount)
		};

		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.VALIDATION, validationContext);

		try
		{
			String message = contextClassName + ' validation completed in ' + elapsedMs + 'ms';
			String details = 'Rules: ' + ruleCount + ', Records: ' + recordCount;
			LOG_Engine.logPerformance(message, details, UTIL_ValidationRule.class.getName() + '/processRulesForContext', elapsedMs);
		}
		finally
		{
			LOG_Engine.popOperationContext();
		}
	}
}