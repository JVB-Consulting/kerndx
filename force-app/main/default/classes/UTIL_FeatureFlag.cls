// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Provides static methods to check if a feature is enabled.
 * It reads Custom Metadata records to determine if a feature should be active for the current user
 * or for a specific user (user context evaluation).
 *
 * User Context Evaluation:
 * Use `isEnabled(flagName, userId)` or `isEnabled(flagName, username)` when you need to evaluate
 * a feature flag for a user other than the currently running user. This is essential for:
 * - TxnSecurity.EventCondition implementations (check flags for the event user, not the policy context)
 * - Batch Apex processing (evaluate flags for each user being processed)
 * - Platform Event handlers (check flags for the event publisher)
 * - Admin tools (preview flag status for troubleshooting)
 *
 * Performance and SOQL Cost:
 * The first `isEnabled(...)` call per transaction loads every active flag and its active strategies in
 * one CMDT query (`SEL_FeatureFlag.activeFlags` static cache); subsequent calls reuse that cache. Most
 * strategy types then add 1 SOQL per evaluation — Hierarchical/List Custom Setting, Custom Metadata,
 * Profile, Public Group, Permission Set Group, and unprefixed (subscriber-local) Custom Permission.
 * Namespaced or `core.` Custom Permission for the running user is free (`FeatureManagement.checkPermission()`).
 * For per-record loops or batch jobs, hoist the boolean out of the loop, or implement an
 * `INT_FeatureFlagStrategy` handler that calls typed `MyCS__c.getInstance(...)` to dodge SOQL on
 * Custom Setting reads. See the Utilities Guide → "Performance and SOQL Cost" for the full per-strategy
 * cost table and a worked example.
 *
 * @see FeatureFlag__mdt
 * @see UTIL_FeatureFlag_TEST
 *
 * @author Jason van Beukering
 *
 * @group Feature Flags
 *
 * @date November 2025, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * // Simple check to see if a feature is enabled for the running user
 * if(UTIL_FeatureFlag.isEnabled('My_New_Feature_Api_Name'))
 * {
 *     // Execute the new feature logic
 *     MY_FeatureController.doSomething();
 * }
 * // Check feature flag for a specific user (e.g., in TxnSecurity policy)
 * if(UTIL_FeatureFlag.isEnabled('Block_Large_Export', reportEvent.UserId))
 * {
 *     return reportEvent.RowsProcessed > 10000;
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
global inherited sharing class UTIL_FeatureFlag
{
	/**
	 * @description Prefix used to explicitly reference package (core) custom permissions.
	 * Example: `core.Admin_Access` refers to the package's Admin_Access permission.
	 */
	@TestVisible
	private static final String CORE_PERMISSION_PREFIX = 'core.';

	/**
	 * @description Delimiter indicating a fully-qualified namespaced permission.
	 * Example: `kern__Admin_Access` or `otherpkg__Some_Permission`
	 */
	@TestVisible
	private static final String NAMESPACE_DELIMITER = '__';

	/**
	 * @description The global interface for all feature evaluation strategies.
	 *
	 * Implement this interface and reference your class from `FeatureFlagStrategy__mdt.CustomHandler__c`
	 * to replace any built-in strategy. This is the recommended escape hatch when the built-in
	 * Hierarchical/List Custom Setting or Custom Metadata strategies cause SOQL hot spots: a custom
	 * handler can call typed `MyCS__c.getInstance(userId)` / `MyType__mdt.getInstance(name)` directly
	 * for zero-SOQL platform-cached reads. See the Utilities Guide → "Performance and SOQL Cost".
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Example implementation of a custom strategy
	 * public class MY_Region_Strategy implements UTIL_FeatureFlag.INT_FeatureFlagStrategy
	 * {
	 *     public Boolean isEnabled(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate)
	 *     {
	 *         // Custom logic to enable feature only for users in the 'US'
	 *         Boolean isFeatureEnabled = UserInfo.getCountry() == 'US';
	 *         return isFeatureEnabled;
	 *     }
	 * }
	 * ```
	 */
	global interface INT_FeatureFlagStrategy
	{
		/**
		 * @description Evaluates the strategy and determines if the feature should be enabled.
		 *
		 * @param flag The Feature Flag custom metadata record.
		 * @param strategyToEvaluate The specific strategy record to evaluate.
		 *
		 * @return `true` if the feature is enabled by this strategy, `false` otherwise.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * public Boolean isEnabled(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate)
		 * {
		 *     // Check if the strategy's target value matches our condition
		 *     Boolean isTargetMet = strategyToEvaluate.TargetValue__c == 'Some_Value';
		 *     return isTargetMet;
		 * }
		 * ```
		 */
		Boolean isEnabled(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate);
	}

	/**
	 * @description Extended interface for custom strategies that support user context evaluation.
	 *
	 * Implement this interface instead of INT_FeatureFlagStrategy when your custom
	 * strategy needs to evaluate for a specific user (not just the running user).
	 *
	 * IMPORTANT: You must implement BOTH methods:
	 * - isEnabled() for backward compatibility and running user scenarios
	 * - isEnabledForUser() for explicit user context scenarios
	 *
	 * The recommended pattern is to have isEnabled() delegate to isEnabledForUser().
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * public class MY_Region_Strategy implements UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy
	 * {
	 *     public Boolean isEnabled(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate)
	 *     {
	 *         return isEnabledForUser(flag, strategyToEvaluate, UserInfo.getUserId());
	 *     }
	 *     public Boolean isEnabledForUser(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate, Id userId)
	 *     {
	 *         User targetUser = new SEL_User().findById(userId);
	 *         List<String> allowedCountries = strategyToEvaluate.Target__c.split(',');
	 *         return allowedCountries.contains(targetUser.Country);
	 *     }
	 * }
	 * ```
	 */
	global interface INT_UserAwareFeatureFlagStrategy extends INT_FeatureFlagStrategy
	{
		/**
		 * @description Evaluates the strategy for a specific user.
		 *
		 * @param flag The parent Feature Flag custom metadata record
		 * @param strategyToEvaluate The specific strategy record being evaluated
		 * @param userId The user to evaluate the strategy for (may differ from running user)
		 *
		 * @return `true` if the feature is enabled for the specified user by this strategy
		 *
		 * @since 1.0
		 */
		Boolean isEnabledForUser(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate, Id userId);
	}

	/**
	 * @description Encapsulates user context information for feature flag evaluation.
	 *
	 * Use the factory methods createRunningUserContext() and createUserContext(Id)
	 * in the outer class to create instances. Inner classes cannot have static methods in Apex.
	 */
	@TestVisible
	private class UserContext
	{
		/**
		 * @description Flag to track whether profileId has been loaded (to handle null profiles correctly).
		 */
		private Boolean profileIdLoaded = false;

		/**
		 * @description The user ID to evaluate strategies against.
		 * This is always populated - either from UserInfo.getUserId() or the provided userId.
		 */
		public Id userId {get; private set;}

		/**
		 * @description The user's profile ID.
		 * For running user: Populated immediately from UserInfo.getProfileId() (no SOQL).
		 * For other users: Lazy-loaded on first access via new SEL_User().findProfileIdByUserId().
		 */
		public Id profileId
		{
			get
			{
				if(profileId == null && userId != null && !profileIdLoaded)
				{
					profileId = new SEL_User().findProfileIdByUserId(userId);
					profileIdLoaded = true;
				}
				return profileId;
			}
			private set;
		}

		/**
		 * @description Indicates whether this context represents the currently running user.
		 * When true, certain optimizations can be applied (e.g., using FeatureManagement.checkPermission).
		 */
		public Boolean isRunningUser {get; private set;}
	}

	/**
	 * @description Factory method: Creates context for the running user.
	 * Uses UserInfo methods for optimal performance (zero SOQL queries).
	 *
	 * @return UserContext configured for the running user
	 */
	private static UserContext createRunningUserContext()
	{
		UserContext context = new UserContext();
		context.userId = UserInfo.getUserId();
		context.profileId = UserInfo.getProfileId();
		context.profileIdLoaded = true;
		context.isRunningUser = true;
		return context;
	}

	/**
	 * @description Factory method: Creates context for a specific user.
	 * Detects if the provided userId matches the running user and optimizes accordingly.
	 * Profile ID is lazy-loaded only when needed.
	 *
	 * @param userId The user ID to create context for
	 *
	 * @return UserContext configured for the specified user, or null if userId is null
	 */
	private static UserContext createUserContext(Id userId)
	{
		UserContext context;

		if(String.isNotBlank(userId))
		{
			context = new UserContext();
			context.userId = userId;
			context.isRunningUser = (userId == UserInfo.getUserId());

			// Optimization: If this happens to be the running user, use UserInfo
			if(context.isRunningUser)
			{
				context.profileId = UserInfo.getProfileId();
				context.profileIdLoaded = true;
			}
			// Otherwise, profileId will be lazy-loaded when accessed
		}

		return context;
	}

	/**
	 * @description Checks if a feature is enabled for the RUNNING user by evaluating its associated strategies.
	 *
	 * @param flagName The DeveloperName (API Name) of the Feature Flag custom metadata record.
	 *
	 * @return `true` if the feature is enabled, `false` otherwise.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String featureFlagApiName = 'My_Feature_Flag';
	 * if(UTIL_FeatureFlag.isEnabled(featureFlagApiName))
	 * {
	 *     MY_NewFeature_CLASS.doSomething();
	 * }
	 * else
	 * {
	 *     MY_OldLogic_CLASS.doSomething();
	 * }
	 * ```
	 */
	global static Boolean isEnabled(String flagName)
	{
		return isEnabled(SEL_FeatureFlag.activeFlags.get(flagName), createRunningUserContext());
	}

	/**
	 * @description Checks if a feature is enabled for a SPECIFIC user.
	 *
	 * Use this method when you need to evaluate a feature flag for a user other than
	 * the currently running user. Common scenarios include:
	 *
	 * - TxnSecurity.EventCondition: Check flags for the event user, not the policy context
	 * - Batch Apex: Evaluate flags for each user being processed
	 * - Platform Events: Check flags for the event publisher
	 * - Admin Tools: Preview flag status for troubleshooting
	 *
	 * All built-in strategies (Custom Permission, Permission Set Group, Profile,
	 * Public Group, Hierarchical Custom Setting) fully support user context evaluation.
	 *
	 * Custom strategies implementing INT_UserAwareFeatureFlagStrategy will receive
	 * the userId parameter. Strategies implementing only INT_FeatureFlagStrategy
	 * will fall back to running user evaluation (backward compatible).
	 *
	 * @param flagName The DeveloperName (API Name) of the Feature Flag custom metadata record
	 * @param userId The Salesforce User ID to evaluate the flag for
	 *
	 * @return `true` if the feature is enabled for the specified user, `false` otherwise
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // TxnSecurity.EventCondition usage
	 * global class MySecurityPolicy implements TxnSecurity.EventCondition
	 * {
	 *     public Boolean evaluate(SObject event)
	 *     {
	 *         ReportEvent reportEvent = (ReportEvent)event;
	 *         // Check flag for the EVENT USER, not the policy context
	 *         if(UTIL_FeatureFlag.isEnabled('Block_Large_Export', reportEvent.UserId))
	 *         {
	 *             return reportEvent.RowsProcessed > 10000;
	 *         }
	 *         return false;
	 *     }
	 * }
	 * ```
	 */
	global static Boolean isEnabled(String flagName, Id userId)
	{
		if(String.isBlank(userId))
		{
			return false;
		}

		return isEnabled(SEL_FeatureFlag.activeFlags.get(flagName), createUserContext(userId));
	}

	/**
	 * @description Checks if a feature is enabled for a user identified by username.
	 *
	 * This is a convenience method for scenarios where you have a username
	 * (email format) instead of a Salesforce User ID. The method looks up
	 * the user first, then evaluates the flag.
	 *
	 * Returns false if the username does not match any user in the org.
	 *
	 * @param flagName The DeveloperName (API Name) of the Feature Flag custom metadata record
	 * @param username The username (typically email format) to look up and evaluate
	 *
	 * @return `true` if the user exists and the feature is enabled for them, `false` otherwise
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Check flag by username (e.g., from external system)
	 * Boolean enabled = UTIL_FeatureFlag.isEnabled('Premium_Feature', 'john.doe@company.com');
	 * if(enabled)
	 * {
	 *     System.debug('Feature is enabled for this user');
	 * }
	 * ```
	 */
	global static Boolean isEnabled(String flagName, String username)
	{
		User foundUser = new SEL_User().findByUsername(username);

		if(foundUser == null)
		{
			return false;
		}

		return isEnabled(flagName, foundUser.Id);
	}

	/**
	 * @description Checks if a feature is enabled by evaluating its strategies for a specific user context.
	 *
	 * @param flag The Feature Flag custom metadata record.
	 * @param context The user context to evaluate against (running user or specific user)
	 *
	 * @return `true` if the feature is enabled, `false` otherwise.
	 */
	@TestVisible
	private static Boolean isEnabled(FeatureFlag__mdt flag, UserContext context)
	{
		if(flag == null || context == null)
		{
			return false;
		}

		if(flag.FeatureFlagStrategies__r == null || flag.FeatureFlagStrategies__r.isEmpty())
		{
			return UTIL_Boolean.isTrue(flag.IsEnabledByDefault__c);
		}

		for(FeatureFlagStrategy__mdt strategy : sortByOrder(flag.FeatureFlagStrategies__r))
		{
			StrategyResult result = evaluateStrategy(flag, strategy, context);

			switch on result
			{
				when MATCH_TRUE
				{
					return true;
				}
				when MATCH_FALSE
				{
					return false;
				}
			}
		}

		return UTIL_Boolean.isTrue(flag.ResultOnNoMatch__c);
	}

	/**
	 * @description Evaluates a single feature flag strategy and returns its outcome.
	 *
	 * @param flag The parent Feature Flag metadata record.
	 * @param strategy The strategy record to evaluate.
	 * @param context The user context to evaluate against.
	 *
	 * @return `MATCH_TRUE` if strategy matches and evaluates to true;
	 *         `MATCH_FALSE` if strategy matches but evaluates to false;
	 *         `NO_MATCH` if strategy does not apply or fails to evaluate.
	 */
	private static StrategyResult evaluateStrategy(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategy, UserContext context)
	{
		StrategyResult result = StrategyResult.NO_MATCH;

		try
		{
			if(String.isNotBlank(strategy.CustomHandler__c))
			{
				result = evaluateCustomHandler(flag, strategy, context);
			}
			else if(SEL_FeatureFlagStrategy.TYPE_CUSTOM_PERMISSION.equals(strategy.Type__c))
			{
				result = checkCustomPermission(strategy, context);
			}
			else if(SEL_FeatureFlagStrategy.TYPE_PERMISSION_SET_GROUP.equals(strategy.Type__c))
			{
				result = checkPermissionSetGroup(strategy, context);
			}
			else if(SEL_FeatureFlagStrategy.TYPE_PUBLIC_GROUP.equals(strategy.Type__c))
			{
				result = checkPublicGroup(strategy, context);
			}
			else if(SEL_FeatureFlagStrategy.TYPE_HIERARCHICAL_CUSTOM_SETTING.equals(strategy.Type__c))
			{
				result = checkHierarchicalCustomSetting(strategy, context);
			}
			else if(SEL_FeatureFlagStrategy.TYPE_PROFILE.equals(strategy.Type__c))
			{
				result = checkProfile(strategy, context);
			}
			else if(SEL_FeatureFlagStrategy.TYPE_CUSTOM_METADATA.equals(strategy.Type__c))
			{
				result = checkCustomMetadataOrSettingRecord(strategy, true);
			}
			else if(SEL_FeatureFlagStrategy.TYPE_LIST_CUSTOM_SETTING.equals(strategy.Type__c))
			{
				result = checkCustomMetadataOrSettingRecord(strategy, false);
			}
		}
		catch(Exception error)
		{
			LOG_Builder.build().error(error).at(UTIL_FeatureFlag.class.getName() + '.evaluateStrategy').emit();
		}

		return result;
	}

	/**
	 * @description Evaluates a custom handler strategy, supporting both legacy and user-aware interfaces.
	 *
	 * @param flag The parent Feature Flag metadata record.
	 * @param strategy The strategy record containing the custom handler class name.
	 * @param context The user context to evaluate against.
	 *
	 * @return `MATCH_TRUE` if the handler returns true, `MATCH_FALSE` otherwise.
	 */
	private static StrategyResult evaluateCustomHandler(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategy, UserContext context)
	{
		INT_FeatureFlagStrategy customStrategy =
				(INT_FeatureFlagStrategy)UTIL_System.getTypeForClassName(strategy.CustomHandler__c, INT_FeatureFlagStrategy.class).newInstance();

		Boolean handlerResult;

		// Check if the handler supports user-aware evaluation
		if(!context.isRunningUser && customStrategy instanceof INT_UserAwareFeatureFlagStrategy)
		{
			// Use the user-aware method for non-running users
			handlerResult = ((INT_UserAwareFeatureFlagStrategy)customStrategy).isEnabledForUser(flag, strategy, context.userId);
		}
		else
		{
			// Use the standard method (running user or legacy handler)
			handlerResult = customStrategy.isEnabled(flag, strategy);
		}

		return handlerResult ? StrategyResult.MATCH_TRUE : StrategyResult.MATCH_FALSE;
	}

	/**
	 * @description Determines if the user has the specified custom permission.
	 *
	 * SUBSCRIBER-FIRST DESIGN:
	 * As a framework package, most custom permissions will be created by subscribers.
	 * The Target__c value is interpreted as follows:
	 *
	 * 1. Contains `__` (double underscore): Fully-qualified namespaced permission
	 *    Example: `kern__Admin_Access` or `otherpkg__Some_Permission`
	 *    Uses FeatureManagement.checkPermission() for running user (namespace-aware).
	 *
	 * 1. Starts with `core.`: Explicit package permission alias
	 *    Example: `core.Admin_Access` → checks for Kern's Admin_Access permission
	 *    Uses FeatureManagement.checkPermission() for running user.
	 *
	 * 1. No prefix (default): LOCAL subscriber permission
	 *    Example: `Edit_Confidential_Records` → subscriber-created permission
	 *    Uses SOQL-based checking (FeatureManagement cannot see local permissions).
	 *
	 * @param strategy The strategy record containing the target custom permission name.
	 * @param context The user context to evaluate against.
	 *
	 * @return `MATCH_TRUE` if user has permission and expected;
	 *         `MATCH_FALSE` if user has permission but not expected;
	 *         `NO_MATCH` if user lacks permission and no expectation defined.
	 */
	private static StrategyResult checkCustomPermission(FeatureFlagStrategy__mdt strategy, UserContext context)
	{
		String target = strategy.Target__c;
		Boolean hasPermission;

		if(String.isBlank(target))
		{
			return StrategyResult.NO_MATCH;
		}

		if(target.contains(NAMESPACE_DELIMITER))
		{
			// Fully-qualified namespaced permission (e.g., "kern__Admin_Access")
			// FeatureManagement.checkPermission() works with fully-qualified names for running user
			hasPermission = checkNamespacedPermission(target, context);
		}
		else if(target.startsWithIgnoreCase(CORE_PERMISSION_PREFIX))
		{
			// Explicit package permission alias (e.g., "core.Admin_Access")
			String permissionName = target.substringAfter(CORE_PERMISSION_PREFIX);
			hasPermission = checkPackagePermission(permissionName, context);
		}
		else
		{
			// Default: LOCAL subscriber permission (e.g., "Edit_Confidential_Records")
			// Must use SOQL - FeatureManagement cannot see subscriber permissions from managed package
			hasPermission = SEL_CustomPermission.hasLocalPermission(context.userId, target);
		}

		return getStrategyResult(strategy, hasPermission);
	}

	/**
	 * @description Checks a fully-qualified namespaced permission (contains __).
	 *
	 * @param qualifiedName The fully-qualified permission name (e.g., "kern__Admin_Access")
	 * @param context The user context to evaluate against
	 *
	 * @return True if user has the permission
	 */
	private static Boolean checkNamespacedPermission(String qualifiedName, UserContext context)
	{
		if(context.isRunningUser)
		{
			// FeatureManagement.checkPermission() accepts fully-qualified names for running user
			return FeatureManagement.checkPermission(qualifiedName);
		}

		// For other users, parse namespace and use SOQL
		String namespace = qualifiedName.substringBefore(NAMESPACE_DELIMITER);
		String permissionName = qualifiedName.substringAfter(NAMESPACE_DELIMITER);

		return SEL_CustomPermission.hasPermission(context.userId, permissionName, namespace);
	}

	/**
	 * @description Checks a package (core) custom permission.
	 *
	 * @param permissionName The permission DeveloperName (without namespace)
	 * @param context The user context to evaluate against
	 *
	 * @return True if user has the package permission
	 */
	private static Boolean checkPackagePermission(String permissionName, UserContext context)
	{
		if(context.isRunningUser)
		{
			// Optimization: use platform API for running user (no SOQL)
			return FeatureManagement.checkPermission(permissionName);
		}

		// For other users, use SOQL with package namespace
		return SEL_CustomPermission.hasPackagePermission(context.userId, permissionName);
	}

	/**
	 * @description Converts a boolean condition check into a definitive `StrategyResult`
	 * based on the `ExpectedValue__c` field in the strategy record.
	 *
	 * @param strategy The strategy record containing `ExpectedValue__c`.
	 * @param wasFound `true` if the condition (e.g., user in group) is met.
	 *
	 * @return `MATCH_TRUE`, `MATCH_FALSE`, or `NO_MATCH` based on expectation.
	 */
	private static StrategyResult getStrategyResult(FeatureFlagStrategy__mdt strategy, Boolean wasFound)
	{
		if(String.isBlank(strategy.ExpectedValue__c))
		{
			return wasFound ? StrategyResult.MATCH_TRUE : StrategyResult.NO_MATCH;
		}

		Boolean expected = UTIL_Boolean.toBoolean(strategy.ExpectedValue__c);
		return (wasFound == expected) ? StrategyResult.MATCH_TRUE : StrategyResult.MATCH_FALSE;
	}

	/**
	 * @description Checks if the user is assigned to the specified Permission Set or Permission Set Group.
	 *
	 * @param strategy The strategy record containing the target Permission Set Group name.
	 * @param context The user context to evaluate against.
	 *
	 * @return `MATCH_TRUE`, `MATCH_FALSE`, or `NO_MATCH` based on assignment and expectation.
	 */
	private static StrategyResult checkPermissionSetGroup(FeatureFlagStrategy__mdt strategy, UserContext context)
	{
		return getStrategyResult(strategy, new SEL_PermissionSetAssignment().isAssigned(strategy.Target__c, context.userId));
	}

	/**
	 * @description Checks if the user has the specified Profile.
	 *
	 * @param strategy The strategy record containing the target Profile name.
	 * @param context The user context to evaluate against.
	 *
	 * @return `MATCH_TRUE`, `MATCH_FALSE`, or `NO_MATCH` based on profile match and expectation.
	 */
	private static StrategyResult checkProfile(FeatureFlagStrategy__mdt strategy, UserContext context)
	{
		Profile targetProfile = new SEL_Profile().findByName(strategy.Target__c);

		if(targetProfile == null)
		{
			return StrategyResult.NO_MATCH;
		}

		return getStrategyResult(strategy, context.profileId == targetProfile.Id);
	}

	/**
	 * @description Checks if the user is a member of the specified Public Group.
	 *
	 * @param strategy The strategy record containing the target group name.
	 * @param context The user context to evaluate against.
	 *
	 * @return `MATCH_TRUE`, `MATCH_FALSE`, or `NO_MATCH` based on group membership and expectation.
	 */
	private static StrategyResult checkPublicGroup(FeatureFlagStrategy__mdt strategy, UserContext context)
	{
		return getStrategyResult(strategy, new SEL_Group().userIsInGroup(context.userId, strategy.Target__c));
	}

	/**
	 * @description Evaluates a field value on a Custom Metadata or List Custom Setting record.
	 *
	 * @param strategy The strategy record with `Target__c` in format: `Object__mdt.RecordName.Field__c`
	 * @param isCustomMetadata `true` for Custom Metadata, `false` for List Custom Setting.
	 *
	 * @return `MATCH_TRUE` or `MATCH_FALSE` if field value matches expectation; `NO_MATCH` if record/field not found.
	 */
	private static StrategyResult checkCustomMetadataOrSettingRecord(FeatureFlagStrategy__mdt strategy, Boolean isCustomMetadata)
	{
		String targetPath = strategy.Target__c;
		String expectedValue = strategy.ExpectedValue__c;

		String objectName;
		String recordName;
		String fieldName;

		if(String.isNotBlank(targetPath))
		{
			Integer firstDot = targetPath.indexOf(UTIL_String.DOT);
			Integer lastDot = targetPath.lastIndexOf(UTIL_String.DOT);

			// We cannot use targetPath.split('.', 3) because the Record Name itself
			// (e.g. 'acmelib.TRG_SetFoobarDefaults') can contain dots. We must parse based on the first and last dot positions.
			if(firstDot > 0 && lastDot > firstDot)
			{
				objectName = targetPath.substring(0, firstDot);
				recordName = targetPath.substring(firstDot + 1, lastDot);
				fieldName = targetPath.substring(lastDot + 1);
			}
		}

		if(String.isBlank(fieldName))
		{
			return StrategyResult.NO_MATCH;
		}

		return getStrategyResult(getCustomMetadataOrSettingValue(objectName, recordName, fieldName, isCustomMetadata), expectedValue);
	}

	/**
	 * @description Overloaded version of `getStrategyResult` that compares a retrieved field value with an expected string.
	 *
	 * @param fieldValue The actual value retrieved from the record (can be Boolean, Decimal, String, etc.).
	 * @param expectedValue The expected value as a string from `ExpectedValue__c`.
	 *
	 * @return `MATCH_TRUE` if values are equivalent after coercion; `MATCH_FALSE` otherwise; `NO_MATCH` if fieldValue is null.
	 */
	private static StrategyResult getStrategyResult(Object fieldValue, String expectedValue)
	{
		if(fieldValue == null)
		{
			return StrategyResult.NO_MATCH;
		}

		Boolean result = String.isBlank(expectedValue)
				? UTIL_Boolean.toBoolean(String.valueOf(fieldValue))
				: areValuesEqual(fieldValue, expectedValue);

		return result ? StrategyResult.MATCH_TRUE : StrategyResult.MATCH_FALSE;
	}

	/**
	 * @description Dynamically retrieves a field value from a Custom Metadata Type or List Custom Setting record.
	 *
	 * @param objectName API name of the object (e.g., `My_Settings__mdt`).
	 * @param uniqueRecordName DeveloperName (MDT) or Name (List Setting) of the record.
	 * @param fieldToReturn API name of the field to retrieve.
	 * @param isCustomMetadata `true` for Custom Metadata, `false` for List Custom Setting.
	 *
	 * @return Field value as `Object`, or `null` if record or field not found.
	 */
	private static Object getCustomMetadataOrSettingValue(String objectName, String uniqueRecordName, String fieldToReturn, Boolean isCustomMetadata)
	{
		SObject foundRecord = QRY_Builder.selectFrom(UTIL_SObjectDescribe.getSObjectTypeByName(objectName))
				.systemModeInternal()
				.fields(new List<String> {fieldToReturn})
				.condition(isCustomMetadata ? 'DeveloperName' : 'Name').equals(uniqueRecordName)
				.getFirst();
		return foundRecord?.get(fieldToReturn);
	}

	/**
	 * @description Evaluates a field value on a Hierarchical Custom Setting using user/profile/org hierarchy.
	 *
	 * @param strategy The strategy record with `Target__c` in format: `My_Setting__c.MyField__c`
	 * @param context The user context to evaluate against.
	 *
	 * @return `MATCH_TRUE` or `MATCH_FALSE` if value matches expectation; `NO_MATCH` if no value found.
	 */
	private static StrategyResult checkHierarchicalCustomSetting(FeatureFlagStrategy__mdt strategy, UserContext context)
	{
		String expectedValue = strategy.ExpectedValue__c;
		String targetPath = strategy.Target__c;
		final Integer numberOfParts = 2;

		List<String> fieldNameParts = String.isNotBlank(targetPath) ? targetPath.split('\\.', numberOfParts) : null;

		if(fieldNameParts?.size() != numberOfParts)
		{
			return StrategyResult.NO_MATCH;
		}

		return getStrategyResult(getHierarchicalSettingValue(fieldNameParts[0], fieldNameParts[1], context), expectedValue);
	}

	/**
	 * @description Retrieves a field value from a Hierarchical Custom Setting, respecting user to profile to org precedence.
	 *
	 * @param objectName API name of the Custom Setting (e.g., `My_Settings__c`).
	 * @param fieldName API name of the field to retrieve.
	 * @param context The user context to evaluate against.
	 *
	 * @return Field value as `Object`, or `null` if not defined at any level.
	 */
	private static Object getHierarchicalSettingValue(String objectName, String fieldName, UserContext context)
	{
		final Id orgId = UserInfo.getOrganizationId();
		final Id profileId = context.profileId;
		final Id userId = context.userId;
		final String setupOwnerFieldName = 'SetupOwnerId';

		List<Id> ownerIds = new List<Id> {userId, profileId, orgId};

		List<SObject> foundSettings = QRY_Builder.selectFrom(UTIL_SObjectDescribe.getSObjectTypeByName(objectName))
				.systemModeInternal()
				.fields(new List<String> {setupOwnerFieldName, fieldName})
				.condition(setupOwnerFieldName).isIn(new List<Id> {userId, profileId, orgId})
				.toList();
		Map<Id, SObject> settingsMap = UTIL_SObject.indexById(foundSettings, setupOwnerFieldName);

		SObject correctSetting;

		for(Id ownerId : ownerIds)
		{
			correctSetting = settingsMap.get(ownerId);
			if(correctSetting != null)
			{
				break;
			}
		}

		return correctSetting?.get(fieldName);
	}

	/**
	 * @description Compares a database field value (any type) with a string expected value, handling type conversion.
	 *
	 * Supports:
	 * - Boolean: coerces string to boolean via `UTIL_Boolean.toBoolean`
	 * - Numeric: converts both to `Decimal` and compares
	 * - String: case-insensitive comparison
	 *
	 * @param fieldValue The value retrieved from the database (Boolean, Decimal, String, etc.).
	 * @param compareValueString The expected value as a string from `ExpectedValue__c`.
	 *
	 * @return `true` if values are equivalent after type-safe comparison.
	 *
	 * @example
	 * ```apex
	 * // All return true
	 * UTIL_FeatureFlag.areValuesEqual(true, 'true');
	 * UTIL_FeatureFlag.areValuesEqual(5, '5');
	 * UTIL_FeatureFlag.areValuesEqual(5.0, '5');
	 * UTIL_FeatureFlag.areValuesEqual('Hello', 'hello');
	 * ```
	 */
	@TestVisible
	private static Boolean areValuesEqual(Object fieldValue, String compareValueString)
	{
		if(fieldValue instanceof Boolean)
		{
			return (Boolean)fieldValue == UTIL_Boolean.toBoolean(compareValueString);
		}
		else if(fieldValue instanceof Decimal || fieldValue instanceof Integer || fieldValue instanceof Double || fieldValue instanceof Long)
		{
			Decimal dbDecimal = Decimal.valueOf(String.valueOf(fieldValue));
			Decimal compareDecimal = Decimal.valueOf(compareValueString);
			return dbDecimal == compareDecimal;
		}
		else
		{
			return compareValueString.equalsIgnoreCase(String.valueOf(fieldValue));
		}
	}

	/**
	 * @description Sorts feature flag strategies by Order__c ascending.
	 * Required because CMDT parent-child subselect ORDER BY silently drops child records.
	 * Salesforce Known Issues:
	 * - W-8877088 (ORDER BY in subquery does not return all records)
	 * - W-6357102 (ASC/DESC in subquery returns different results)
	 *
	 * @param strategies The strategies to sort
	 *
	 * @return A new list sorted by Order__c ascending (nulls treated as 0)
	 */
	@TestVisible
	private static List<FeatureFlagStrategy__mdt> sortByOrder(List<FeatureFlagStrategy__mdt> strategies)
	{
		Map<Decimal, List<FeatureFlagStrategy__mdt>> strategiesByOrder = new Map<Decimal, List<FeatureFlagStrategy__mdt>>();

		for(FeatureFlagStrategy__mdt strategy : strategies)
		{
			Decimal orderValue = strategy.Order__c ?? 0;

			if(!strategiesByOrder.containsKey(orderValue))
			{
				strategiesByOrder.put(orderValue, new List<FeatureFlagStrategy__mdt>());
			}

			strategiesByOrder.get(orderValue).add(strategy);
		}

		List<Decimal> sortedOrders = new List<Decimal>(strategiesByOrder.keySet());
		sortedOrders.sort();

		List<FeatureFlagStrategy__mdt> sorted = new List<FeatureFlagStrategy__mdt>();

		for(Decimal orderValue : sortedOrders)
		{
			sorted.addAll(strategiesByOrder.get(orderValue));
		}

		return sorted;
	}

	/**
	 * @description Defines the three possible outcomes of evaluating a feature flag strategy.
	 */
	@TestVisible
	private enum StrategyResult
	{
		/**
		 * @description Strategy applies and condition is satisfied.
		 */
		MATCH_TRUE,
		/**
		 * @description Strategy applies but condition is not satisfied.
		 */
		MATCH_FALSE,
		/**
		 * @description Strategy does not apply to current context.
		 */
		NO_MATCH
	}
}