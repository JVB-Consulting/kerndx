// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Flow invocable action to manage trigger bypasses. Supports bypassing a specific
 * trigger action or object, clearing a specific bypass, and clearing all bypasses in a single action.
 *
 * @see FLOW_BypassTrigger_TEST
 * @see FLOW_CheckTriggerBypassed
 * @see TRG_Base
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, July 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * FLOW_BypassTrigger.DTO_Request request = new FLOW_BypassTrigger.DTO_Request();
 * request.action = 'BYPASS';
 * request.bypassType = 'OBJECT_NAME';
 * request.name = 'Account';
 * FLOW_BypassTrigger.execute(new List<FLOW_BypassTrigger.DTO_Request> {request});
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_BypassTrigger
{
	/**
	 * @description Manages trigger bypasses based on the requested action.
	 *
	 * @param requests A list of bypass requests to process
	 *
	 * @throws IllegalArgumentException if more than one request is provided
	 * @throws NoSuchElementException if the bypass type or action is invalid
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * FLOW_BypassTrigger.DTO_Request request = new FLOW_BypassTrigger.DTO_Request();
	 * request.action = 'BYPASS';
	 * request.bypassType = 'OBJECT_NAME';
	 * request.name = 'Account';
	 * FLOW_BypassTrigger.execute(new List<FLOW_BypassTrigger.DTO_Request>{request});
	 * ```
	 */
	@InvocableMethod(Category='Trigger Actions' Label='Trigger Bypass' Description='Bypass, clear, or clear all trigger bypasses for an object or action class.')
	global static void execute(List<DTO_Request> requests)
	{
		TRG_Base.validateSingleRequest(requests.size(), FLOW_BypassTrigger.class.getName());

		DTO_Request request = requests.iterator().next();
		String actionString = String.isNotBlank(request.action) ? request.action.toUpperCase() : TRG_Base.BypassAction.BYPASS.name();
		TRG_Base.BypassAction action = TRG_Base.resolveBypassAction(actionString);
		TRG_Base.BypassType bypassType = TRG_Base.resolveBypassType(request.bypassType);

		switch on action
		{
			when BYPASS
			{
				TRG_Base.bypass(request.name, bypassType);
			}
			when CLEAR
			{
				TRG_Base.clearBypass(request.name, bypassType);
			}
			when CLEAR_ALL
			{
				TRG_Base.clearAllBypasses(bypassType);
			}
		}
	}

	/**
	 * @description Request DTO for the Trigger Bypass invocable action.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Request
	{
		/**
		 * @description The action to perform. Valid values:
		 * - BYPASS: Add to the bypass list (default)
		 * - CLEAR: Remove a specific item from the bypass list
		 * - CLEAR_ALL: Clear all items from the bypass list (name is ignored)
		 *
		 * @since 1.0
		 */
		@SuppressWarnings('LongLine')
		@InvocableVariable
		(
				Label='Action'
				Description='Pick Bypass to add a bypass, Clear to remove one, or Clear All to remove every bypass. Stored values are BYPASS, CLEAR, and CLEAR_ALL; the field shows the stored value.'
				DefaultValue='BYPASS'
				PlaceholderText='BYPASS'
		)
		global String action;

		/**
		 * @description The type of bypass: Class (stored as CLASS_NAME) targets one trigger action class;
		 * Object (stored as OBJECT_NAME) targets every trigger action on the object.
		 *
		 * @since 1.0
		 */
		@SuppressWarnings('LongLine')
		@InvocableVariable
		(
				Label='Bypass Type'
				Description='Pick Class to bypass one trigger action class, or Object to bypass every trigger action on an object. Stored values are CLASS_NAME and OBJECT_NAME; the field shows the stored value.'
				DefaultValue='OBJECT_NAME'
				PlaceholderText='OBJECT_NAME'
		)
		global String bypassType;

		/**
		 * @description The API name of the trigger action class or SObject. Required for BYPASS and CLEAR actions, ignored for CLEAR_ALL.
		 *
		 * @since 1.0
		 */
		@InvocableVariable(Label='Name' Description='API Name of the trigger action class or SObject' Required=true)
		global String name;
	}
}