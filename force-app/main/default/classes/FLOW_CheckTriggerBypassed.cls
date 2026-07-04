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
 * @description This class is used to check whether certain triggers or actions are bypassed in the system.
 * The class provides a method that can be invoked from a flow or Apex to determine if an object-level,
 * Apex trigger class-level, or flow action-level bypass is active. It is based on the metadata-driven
 * trigger actions framework that enables trigger execution to be turned on or off based on metadata configuration.
 * adapted from:[apex-trigger-actions-framework](https://github.com/mitchspano/apex-trigger-actions-framework/blob/master/README.md#metadata-driven-trigger-actions)
 *
 * @see FLOW_CheckTriggerBypassed_TEST
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
 * FLOW_CheckTriggerBypassed.DTO_Request request = new FLOW_CheckTriggerBypassed.DTO_Request();
 * request.name = 'Account';
 * request.bypassType = 'OBJECT_NAME';
 * List<Boolean> results = FLOW_CheckTriggerBypassed.isBypassed(new List<FLOW_CheckTriggerBypassed.DTO_Request> {request});
 * Boolean isBypassed = results[0];
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_CheckTriggerBypassed
{
	/**
	 * @description Returns if the bypass for this object, apex action, or flow action is set to true.
	 * The DTO_Request class represents the request to check if a specific bypass is active.
	 * Each request contains the name of the object or Apex class to be checked, and the type of the bypass
	 * (either for a class name or object name). This object is passed into the isBypassed method to specify
	 * the bypass type and target.
	 *
	 * @param dtoRequests A list of Action Names and Types
	 *
	 * @return If the action has been bypassed
	 *
	 * @throws IllegalArgumentException Will throw exception if more than one request is provided or the bypass type is invalid
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<DTO_Request> requests = new List<DTO_Request>();
	 * DTO_Request request = new DTO_Request();
	 * request.name = 'Account';
	 * request.bypassType = 'OBJECT_NAME';
	 * requests.add(request);
	 * List<Boolean> isBypassedResult = FLOW_CheckTriggerBypassed.isBypassed(requests);
	 * ```
	 */
	@InvocableMethod(Category='Trigger Actions' Label='Is Bypassed' Description='Returns if the bypass for an Object or Apex trigger action class is set to true.')
	global static List<Boolean> isBypassed(List<DTO_Request> dtoRequests)
	{
		TRG_Base.validateSingleRequest(dtoRequests.size(), FLOW_CheckTriggerBypassed.class.getName());

		DTO_Request dtoRequest = dtoRequests.iterator().next();
		return new List<Boolean> {TRG_Base.isBypassed(dtoRequest.name, TRG_Base.resolveBypassType(dtoRequest.bypassType))};
	}

	/**
	 * @description A DTO indicating what action has been bypassed
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_Request request = new DTO_Request();
	 * request.name = 'Account';
	 * request.bypassType = 'OBJECT_NAME';
	 * ```
	 */
	global inherited sharing class DTO_Request
	{
		/**
		 * @description The type of bypass to check: Class (stored as CLASS_NAME) checks one trigger action class;
		 * Object (stored as OBJECT_NAME) checks an object-wide bypass.
		 *
		 * @since 1.0
		 */
		@SuppressWarnings('LongLine')
		@InvocableVariable
		(
				Label='Bypass Type'
				Description='Pick Class to check a trigger action class bypass, or Object to check an object-wide bypass. Stored values are CLASS_NAME and OBJECT_NAME; the field shows the stored value.'
				DefaultValue='OBJECT_NAME'
				PlaceholderText='OBJECT_NAME'
		)
		global String bypassType;

		/**
		 * @description The API name of the trigger action class or SObject to check bypass status for.
		 *
		 * @since 1.0
		 */
		@InvocableVariable(Label='Item Name' Description='API name of the trigger action class or SObject to check' Required=true)
		global String name;
	}
}