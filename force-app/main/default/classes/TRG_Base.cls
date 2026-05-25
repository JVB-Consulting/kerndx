// SPDX-License-Identifier: Apache-2.0
/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @description The base class for trigger actions, designed to be extended and implement relevant interfaces.
 * This class provides the core functionality for executing trigger actions based on the trigger context,
 * with support for bypassing specific SObject types. It is adapted from the
 * [apex-trigger-actions-framework](https://github.com/mitchspano/apex-trigger-actions-framework/blob/master/README.md#metadata-driven-trigger-actions).
 *
 * @see TRG_Dispatcher
 * @see TRG_Base_TEST
 * @see IF_Trigger
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * public with sharing class TRG_SetFoobarDefaults extends TRG_Base implements IF_Trigger.BeforeInsert
 * {
 *     public void beforeInsert(List<SObject> newRecords)
 *     {
 *         for(SObject record : newRecords)
 *         {
 *             if(record.get(Foobar__c.Name) == null)
 *             {
 *                 record.put(Foobar__c.Name, 'Default');
 *             }
 *         }
 *     }
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity')
global inherited sharing virtual class TRG_Base
{
	/**
	 * @description Set of SObject type names for which trigger actions are bypassed.
	 */
	@TestVisible
	private static final Set<String> BYPASSED_OBJECTS = new Set<String>();

	/**
	 * @description Set of trigger action class names for which execution is bypassed.
	 */
	@TestVisible
	private static final Set<String> BYPASSED_ACTIONS = new Set<String>();

	/**
	 * @description Sentinel target recorded when every bypass of a given type is cleared.
	 * Mirrors `UTIL_BypassAudit.TARGET_ALL` — kept inline to avoid cross-class static
	 * initialisation order coupling.
	 */
	@TestVisible
	private static final String BYPASS_TARGET_ALL = 'ALL';

	/**
	 * @description Maps each trigger operation to the interface type that handlers must implement.
	 * Used for validation and diagnostic error messages when a handler class is missing
	 * the required interface for its configured trigger context.
	 */
	public static final Map<TriggerOperation, Type> HANDLER_INTERFACES = new Map<TriggerOperation, Type>
	{
			TriggerOperation.BEFORE_INSERT => IF_Trigger.BeforeInsert.class,
			TriggerOperation.AFTER_INSERT => IF_Trigger.AfterInsert.class,
			TriggerOperation.BEFORE_UPDATE => IF_Trigger.BeforeUpdate.class,
			TriggerOperation.AFTER_UPDATE => IF_Trigger.AfterUpdate.class,
			TriggerOperation.BEFORE_DELETE => IF_Trigger.BeforeDelete.class,
			TriggerOperation.AFTER_DELETE => IF_Trigger.AfterDelete.class,
			TriggerOperation.AFTER_UNDELETE => IF_Trigger.AfterUndelete.class
	};

	/**
	 * @description Error message thrown when a trigger action is invoked without an active trigger context.
	 */
	public static final String HANDLER_OUTSIDE_TRIGGER_MESSAGE = 'Cannot execute trigger action without an active trigger context';

	/**
	 * @description Error message thrown when an unrecognised bypass type string is provided.
	 */
	@TestVisible
	private static final String ERROR_INVALID_BYPASS_TYPE = 'Bypass type must be one of: OBJECT_NAME, CLASS_NAME';

	/**
	 * @description Error message thrown when an unrecognised bypass action string is provided.
	 */
	@TestVisible
	private static final String ERROR_INVALID_BYPASS_ACTION = 'Bypass action must be one of: BYPASS, CLEAR, CLEAR_ALL';

	/**
	 * @description Error message thrown when an invocable method receives more than one request.
	 */
	private static final String ERROR_INVALID_REQUEST_LENGTH = 'Invocable method {0} requires exactly one request';

	/**
	 * @description Indicates the type of trigger bypass being applied.
	 *
	 * @since 1.0
	 */
	global enum BypassType
	{
		/**
		 * @description Bypass a specific trigger action class by class name.
		 */
		CLASS_NAME,
		/**
		 * @description Bypass all triggers for a specific SObject by object API name.
		 */
		OBJECT_NAME
	}

	/**
	 * @description Indicates the bypass operation being applied or audited. Framework-internal
	 * (package-private) — no subscriber API consumes this enum directly. `FLOW_BypassTrigger`
	 * resolves it via `resolveBypassAction(String)` for its `switch`; audit-log context data
	 * stores the `.name()` serialisation as a plain string.
	 */
	public enum BypassAction
	{
		/**
		 * @description Add a name to the bypass set (activate a bypass).
		 */
		BYPASS,
		/**
		 * @description Remove a specific name from the bypass set.
		 */
		CLEAR,
		/**
		 * @description Remove every name from the bypass set of the given type.
		 */
		CLEAR_ALL
	}

	/**
	 * @description Validates that an invocable method received exactly one request.
	 * Throws an IllegalArgumentException if the request count is not 1.
	 *
	 * @param requestSize The number of requests received
	 * @param className The name of the calling class, included in the error message
	 *
	 * @throws IllegalArgumentException If requestSize is not 1
	 *
	 * @example
	 * ```apex
	 * TRG_Base.validateSingleRequest(requests.size(), FLOW_BypassTrigger.class.getName());
	 * ```
	 */
	public static void validateSingleRequest(Integer requestSize, String className)
	{
		if(requestSize != 1)
		{
			throw new IllegalArgumentException(String.format(ERROR_INVALID_REQUEST_LENGTH, new List<String> {className}));
		}
	}

	/**
	 * @description Parses a bypass type string into the corresponding BypassType enum value.
	 * Wraps the standard valueOf call with a user-friendly error message on failure.
	 *
	 * @param bypassTypeString The string to parse (must be 'OBJECT_NAME' or 'CLASS_NAME')
	 *
	 * @return The parsed BypassType enum value
	 *
	 * @throws System.Exception If the string does not match a valid BypassType value
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.BypassType type = TRG_Base.resolveBypassType('OBJECT_NAME');
	 * ```
	 */
	global static BypassType resolveBypassType(String bypassTypeString)
	{
		try
		{
			return BypassType.valueOf(bypassTypeString);
		}
		catch(Exception error)
		{
			error.setMessage(ERROR_INVALID_BYPASS_TYPE);
			throw error;
		}
	}

	/**
	 * @description Parses a bypass action string into the corresponding BypassAction enum value.
	 * Wraps the standard valueOf call with a user-friendly error message on failure. Framework-
	 * internal (package-private) — consumed by `FLOW_BypassTrigger.execute()` within the same
	 * namespace. Callers that need to default a blank value (e.g., Flow invocable's) should
	 * handle the null / blank case before calling this method.
	 *
	 * @param bypassActionString The string to parse (must be 'BYPASS', 'CLEAR', or 'CLEAR_ALL').
	 *
	 * @return The parsed BypassAction enum value.
	 *
	 * @throws System.Exception If the string does not match a valid BypassAction value.
	 */
	public static BypassAction resolveBypassAction(String bypassActionString)
	{
		try
		{
			return BypassAction.valueOf(bypassActionString);
		}
		catch(Exception error)
		{
			error.setMessage(ERROR_INVALID_BYPASS_ACTION);
			throw error;
		}
	}

	/**
	 * @description Executes the relevant trigger action based on the implemented interface and trigger context.
	 * This method checks the trigger operation and calls the appropriate interface method if implemented.
	 *
	 * @throws TypeException If the class does not implement the required interface for the current context.
	 * @throws UTIL_Exceptions.IllegalStateException If called outside of a trigger execution context.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * public class CustomTriggerAction extends TRG_Base implements IF_Trigger.BeforeInsert
	 * {
	 *     public void beforeInsert(List<SObject> newRecords)
	 *     {
	 *         for (SObject record : newRecords)
	 *         {
	 *             Account accountRecord = (Account)record;
	 *             accountRecord.Name = 'Updated Name';
	 *         }
	 *     }
	 * }
	 * // In a trigger context, calling run() will invoke beforeInsert for BEFORE_INSERT
	 * ```
	 */
	global void run()
	{
		if(!validateRun())
		{
			return;
		}

		try
		{
			switch on context
			{
				when BEFORE_INSERT
				{
					((IF_Trigger.BeforeInsert)this).beforeInsert(triggerNew);
				}
				when AFTER_INSERT
				{
					((IF_Trigger.AfterInsert)this).afterInsert(triggerNew);
				}
				when BEFORE_UPDATE
				{
					((IF_Trigger.BeforeUpdate)this).beforeUpdate(triggerNew, triggerOld);
				}
				when AFTER_UPDATE
				{
					((IF_Trigger.AfterUpdate)this).afterUpdate(triggerNew, triggerOld);
				}
				when BEFORE_DELETE
				{
					((IF_Trigger.BeforeDelete)this).beforeDelete(triggerOld);
				}
				when AFTER_DELETE
				{
					((IF_Trigger.AfterDelete)this).afterDelete(triggerOld);
				}
				when AFTER_UNDELETE
				{
					((IF_Trigger.AfterUndelete)this).afterUndelete(triggerNew);
				}
			}
		}
		catch(TypeException error)
		{
			throw new TypeException(
					'Handler "' + UTIL_System.getRuntimeTypeName(this) + '" must implement ' +
					HANDLER_INTERFACES.get(context).getName() + ' for the ' + context.name() + ' context.'
			);
		}
	}

	/**
	 * @description Bypasses trigger actions for the specified SObject type.
	 *
	 * @param sObjectName The API name of the SObject type to bypass.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.bypass('Account');
	 * Boolean isBypassed = TRG_Base.isBypassed('Account'); // true
	 * ```
	 */
	global static void bypass(String sObjectName)
	{
		TRG_Base.BYPASSED_OBJECTS.add(sObjectName);
		logBypassEvent(BypassAction.BYPASS, BypassType.OBJECT_NAME, sObjectName);
	}

	/**
	 * @description Clears the bypass for the specified SObject type, allowing trigger actions to execute.
	 *
	 * @param sObjectName The API name of the SObject type to clear from bypass.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.bypass('Account');
	 * TRG_Base.clearBypass('Account');
	 * Boolean isBypassed = TRG_Base.isBypassed('Account'); // false
	 * ```
	 */
	global static void clearBypass(String sObjectName)
	{
		TRG_Base.BYPASSED_OBJECTS.remove(sObjectName);
		logBypassEvent(BypassAction.CLEAR, BypassType.OBJECT_NAME, sObjectName);
	}

	/**
	 * @description Checks if trigger actions are bypassed for the specified SObject type.
	 *
	 * @param sObjectName The API name of the SObject type to check.
	 *
	 * @return Boolean True if the SObject type is bypassed, false otherwise.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.bypass('Account');
	 * Boolean isBypassed = TRG_Base.isBypassed('Account'); // true
	 * ```
	 */
	global static Boolean isBypassed(String sObjectName)
	{
		return TRG_Base.BYPASSED_OBJECTS.contains(sObjectName);
	}

	/**
	 * @description Bypasses trigger actions for the specified SObject type.
	 * Type-safe overload that accepts an SObjectType token instead of a string name.
	 *
	 * @param sObjectType The SObjectType token of the object to bypass.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.bypass(Account.SObjectType);
	 * Boolean isBypassed = TRG_Base.isBypassed(Account.SObjectType); // true
	 * ```
	 */
	global static void bypass(SObjectType sObjectType)
	{
		bypass(UTIL_SObjectDescribe.getObjectNameFromType(sObjectType));
	}

	/**
	 * @description Clears the bypass for the specified SObject type, allowing trigger actions to execute.
	 * Type-safe overload that accepts an SObjectType token instead of a string name.
	 *
	 * @param sObjectType The SObjectType token of the object to clear from bypass.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.bypass(Account.SObjectType);
	 * TRG_Base.clearBypass(Account.SObjectType);
	 * Boolean isBypassed = TRG_Base.isBypassed(Account.SObjectType); // false
	 * ```
	 */
	global static void clearBypass(SObjectType sObjectType)
	{
		clearBypass(UTIL_SObjectDescribe.getObjectNameFromType(sObjectType));
	}

	/**
	 * @description Checks if trigger actions are bypassed for the specified SObject type.
	 * Type-safe overload that accepts an SObjectType token instead of a string name.
	 *
	 * @param sObjectType The SObjectType token of the object to check.
	 *
	 * @return Boolean True if the SObject type is bypassed, false otherwise.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.bypass(Account.SObjectType);
	 * Boolean isBypassed = TRG_Base.isBypassed(Account.SObjectType); // true
	 * ```
	 */
	global static Boolean isBypassed(SObjectType sObjectType)
	{
		return TRG_Base.BYPASSED_OBJECTS.contains(UTIL_SObjectDescribe.getObjectNameFromType(sObjectType));
	}

	/**
	 * @description Clears all SObject type bypasses, allowing all trigger actions to execute.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.bypass('Account');
	 * TRG_Base.bypass('Contact');
	 * TRG_Base.clearAllBypasses();
	 * Boolean isBypassed = TRG_Base.isBypassed('Account'); // false
	 * ```
	 */
	global static void clearAllBypasses()
	{
		TRG_Base.BYPASSED_OBJECTS.clear();
		logBypassEvent(BypassAction.CLEAR_ALL, BypassType.OBJECT_NAME, BYPASS_TARGET_ALL);
	}

	/**
	 * @description Bypasses a specific trigger action class by name.
	 *
	 * @param actionClassName The class name of the trigger action to bypass.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.bypassAction('TRG_SetFoobarDefaults');
	 * Boolean isBypassed = TRG_Base.isActionBypassed('TRG_SetFoobarDefaults'); // true
	 * ```
	 */
	global static void bypassAction(String actionClassName)
	{
		TRG_Base.BYPASSED_ACTIONS.add(actionClassName);
		logBypassEvent(BypassAction.BYPASS, BypassType.CLASS_NAME, actionClassName);
	}

	/**
	 * @description Checks if a specific trigger action class is bypassed.
	 *
	 * @param actionClassName The class name of the trigger action to check.
	 *
	 * @return Boolean True if the action class is bypassed, false otherwise.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.bypassAction('TRG_SetFoobarDefaults');
	 * Boolean isBypassed = TRG_Base.isActionBypassed('TRG_SetFoobarDefaults'); // true
	 * ```
	 */
	global static Boolean isActionBypassed(String actionClassName)
	{
		return TRG_Base.BYPASSED_ACTIONS.contains(actionClassName);
	}

	/**
	 * @description Clears the bypass for a specific trigger action class, allowing it to execute.
	 *
	 * @param actionClassName The class name of the trigger action to clear from bypass.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.bypassAction('TRG_SetFoobarDefaults');
	 * TRG_Base.clearActionBypass('TRG_SetFoobarDefaults');
	 * Boolean isBypassed = TRG_Base.isActionBypassed('TRG_SetFoobarDefaults'); // false
	 * ```
	 */
	global static void clearActionBypass(String actionClassName)
	{
		TRG_Base.BYPASSED_ACTIONS.remove(actionClassName);
		logBypassEvent(BypassAction.CLEAR, BypassType.CLASS_NAME, actionClassName);
	}

	/**
	 * @description Clears all action-level bypasses, allowing all trigger action classes to execute.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.bypassAction('TRG_SetFoobarDefaults');
	 * TRG_Base.bypassAction('TRG_ValidateFields');
	 * TRG_Base.clearAllActionBypasses();
	 * Boolean isBypassed = TRG_Base.isActionBypassed('TRG_SetFoobarDefaults'); // false
	 * ```
	 */
	global static void clearAllActionBypasses()
	{
		TRG_Base.BYPASSED_ACTIONS.clear();
		logBypassEvent(BypassAction.CLEAR_ALL, BypassType.CLASS_NAME, BYPASS_TARGET_ALL);
	}

	/**
	 * @description Bypasses a trigger by name, dispatching to the correct bypass set based on the bypass type.
	 *
	 * @param name The object API name or action class name to bypass
	 * @param type The bypass type (OBJECT_NAME or CLASS_NAME)
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.bypass('Account', TRG_Base.BypassType.OBJECT_NAME);
	 * TRG_Base.bypass('TRG_SetDefaults', TRG_Base.BypassType.CLASS_NAME);
	 * ```
	 */
	global static void bypass(String name, BypassType type)
	{
		switch on type
		{
			when OBJECT_NAME
			{
				bypass(name);
			}
			when else
			{
				bypassAction(name);
			}
		}
	}

	/**
	 * @description Checks if a trigger is bypassed, dispatching to the correct bypass set based on the bypass type.
	 *
	 * @param name The object API name or action class name to check
	 * @param type The bypass type (OBJECT_NAME or CLASS_NAME)
	 *
	 * @return True if bypassed
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.bypass('Account', TRG_Base.BypassType.OBJECT_NAME);
	 * Boolean result = TRG_Base.isBypassed('Account', TRG_Base.BypassType.OBJECT_NAME); // true
	 * ```
	 */
	global static Boolean isBypassed(String name, BypassType type)
	{
		switch on type
		{
			when OBJECT_NAME
			{
				return isBypassed(name);
			}
			when else
			{
				return isActionBypassed(name);
			}
		}
	}

	/**
	 * @description Clears a trigger bypass by name, dispatching to the correct bypass set based on the bypass type.
	 *
	 * @param name The object API name or action class name to clear
	 * @param type The bypass type (OBJECT_NAME or CLASS_NAME)
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.bypass('Account', TRG_Base.BypassType.OBJECT_NAME);
	 * TRG_Base.clearBypass('Account', TRG_Base.BypassType.OBJECT_NAME);
	 * Boolean isBypassed = TRG_Base.isBypassed('Account'); // false
	 * ```
	 */
	global static void clearBypass(String name, BypassType type)
	{
		switch on type
		{
			when OBJECT_NAME
			{
				clearBypass(name);
			}
			when else
			{
				clearActionBypass(name);
			}
		}
	}

	/**
	 * @description Clears all trigger bypasses, dispatching to the correct bypass set based on the bypass type.
	 *
	 * @param type The bypass type (OBJECT_NAME or CLASS_NAME)
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.bypass('Account', TRG_Base.BypassType.OBJECT_NAME);
	 * TRG_Base.clearAllBypasses(TRG_Base.BypassType.OBJECT_NAME);
	 * Boolean isBypassed = TRG_Base.isBypassed('Account'); // false
	 * ```
	 */
	global static void clearAllBypasses(BypassType type)
	{
		switch on type
		{
			when OBJECT_NAME
			{
				clearAllBypasses();
			}
			when else
			{
				clearAllActionBypasses();
			}
		}
	}

	/**
	 * @description Sets an optional transaction-scoped reason string that is attached to every
	 * subsequent bypass audit log entry. Use before a batch of bypass calls to document the
	 * operational context (e.g., a data migration or incident response). Pass `null` or empty
	 * to clear.
	 *
	 * @param reason The reason string to record, or `null` to clear the previously set reason.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TRG_Base.setBypassReason('Customer data migration 2026-04-19');
	 * TRG_Base.bypass(Account.SObjectType);
	 * TRG_Base.bypass(Contact.SObjectType);
	 * ```
	 */
	global static void setBypassReason(String reason)
	{
		UTIL_BypassAudit.setBypassReason(reason);
	}

	/**
	 * @description Emits a structured audit log entry for a trigger-surface bypass state change.
	 * Every mutating trigger bypass call (`bypass`, `clearBypass`, `clearAllBypasses`, and their
	 * action-class peers) invokes this helper, which delegates to `UTIL_BypassAudit.emit` so the
	 * audit shape is uniform with the query, DML, and validation surfaces.
	 *
	 * @param action The bypass action enum value (BYPASS / CLEAR / CLEAR_ALL).
	 * @param scope The bypass scope enum value (OBJECT_NAME / CLASS_NAME). Parameter is named
	 *              `scope` rather than `bypassType` because Apex identifier resolution is case-
	 *              insensitive, so the lower-case `bypassType` would shadow the `BypassType` enum
	 *              type inside the method body.
	 * @param target The object API name, action class name, or `ALL` for clear-all operations.
	 */
	private static void logBypassEvent(BypassAction action, BypassType scope, String target)
	{
		String surface = (scope == BypassType.OBJECT_NAME)
				? UTIL_BypassAudit.SURFACE_TRIGGER_OBJECT
				: UTIL_BypassAudit.SURFACE_TRIGGER_ACTION;
		UTIL_BypassAudit.emit(surface, action.name(), target, null);
	}

	/**
	 * @description Validates whether the trigger action can run, checking for trigger context and bypass status.
	 *
	 * @return Boolean True if the action can run, false if bypassed.
	 *
	 * @throws UTIL_Exceptions.IllegalStateException If called outside of a trigger execution context.
	 *
	 * @example
	 * ```apex
	 * public class CustomTriggerAction extends TRG_Base
	 * {
	 *     public Boolean validate()
	 *     {
	 *         return validateRun();
	 *     }
	 * }
	 * ```
	 */
	private Boolean validateRun()
	{
		Boolean hasTriggerContext = Trigger.isExecuting || context != null;

		if(!hasTriggerContext)
		{
			throw new UTIL_Exceptions.IllegalStateException(HANDLER_OUTSIDE_TRIGGER_MESSAGE);
		}

		return !TRG_Base.BYPASSED_OBJECTS.contains(sObjectName);
	}

	/**
	 * @description The API name of the SObject being processed by the trigger action.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String value = instance.sObjectName;
	 * ```
	 */
	@TestVisible
	global protected String sObjectName
	{
		get
		{
			if(String.isBlank(sObjectName))
			{
				sObjectName = resolveSObjectName(triggerNew, triggerOld);
			}
			return sObjectName;
		}
		private set;
	}

	/**
	 * @description Resolves the SObject API name from trigger record lists.
	 * Used by both TRG_Base and TRG_Dispatcher to avoid duplicating the resolution logic.
	 *
	 * @param newRecords The trigger new records
	 * @param oldRecords The trigger old records
	 *
	 * @return The fully qualified SObject API name
	 */
	public static String resolveSObjectName(List<SObject> newRecords, List<SObject> oldRecords)
	{
		List<SObject> triggerRecords = newRecords ?? oldRecords;
		return UTIL_SObjectDescribe.getObjectNameFromType(triggerRecords?.iterator().next().getSObjectType());
	}

	/**
	 * @description The current operation type being processed by the trigger action.
	 *
	 * @see Trigger.operationType
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TriggerOperation value = instance.context;
	 * ```
	 */
	@TestVisible
	global protected TriggerOperation context
	{
		get
		{
			if(context == null)
			{
				context = Trigger.operationType;
			}
			return context;
		}
		private set;
	}

	/**
	 * @description The list of "new" SObjects in the trigger context.
	 *
	 * @see Trigger.new
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObject> value = instance.triggerNew;
	 * ```
	 */
	@TestVisible
	global protected List<SObject> triggerNew
	{
		get
		{
			if(triggerNew == null)
			{
				triggerNew = Trigger.new;
			}
			return triggerNew;
		}
		private set;
	}

	/**
	 * @description The list of "old" SObjects in the trigger context.
	 *
	 * @see Trigger.old
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObject> value = instance.triggerOld;
	 * ```
	 */
	@TestVisible
	global protected List<SObject> triggerOld
	{
		get
		{
			if(triggerOld == null)
			{
				triggerOld = Trigger.old;
			}
			return triggerOld;
		}
		private set;
	}

	/**
	 * @description Map of "old" SObjects keyed by Id, for efficient field change detection in update contexts.
	 *
	 * @see Trigger.oldMap
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SObject oldRecord = triggerOldMap.get(newRecord.Id);
	 * ```
	 */
	@TestVisible
	global protected Map<Id, SObject> triggerOldMap
	{
		get
		{
			if(triggerOldMap == null)
			{
				triggerOldMap = Trigger.oldMap;
			}
			return triggerOldMap;
		}
		private set;
	}
}