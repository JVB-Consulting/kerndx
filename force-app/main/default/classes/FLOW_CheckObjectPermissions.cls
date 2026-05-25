// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Will check what the current user's object permissions are
 *
 * @see FLOW_CheckObjectPermissions_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * FLOW_CheckObjectPermissions.DTO_Request request = new FLOW_CheckObjectPermissions.DTO_Request();
 * request.objectApiName = 'Account';
 * List<FLOW_CheckObjectPermissions.DTO_Response> results = FLOW_CheckObjectPermissions.checkPermissions(new List<FLOW_CheckObjectPermissions.DTO_Request> {request});
 * Boolean canCreate = results[0].hasCreateAccess;
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,LongLine')
global inherited sharing class FLOW_CheckObjectPermissions
{
	/**
	 * @description Method to check the running users' access to the object names provided
	 *
	 * @param dtoRequests List of objects for whom to retrieve permissions
	 *
	 * @return List of items contain users objects permissions
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * FLOW_CheckObjectPermissions.DTO_Request request = new FLOW_CheckObjectPermissions.DTO_Request();
	 * request.objectApiName = 'Account';
	 * List<FLOW_CheckObjectPermissions.DTO_Response> results = FLOW_CheckObjectPermissions.checkPermissions(new List<FLOW_CheckObjectPermissions.DTO_Request>{request});
	 * if(results[0].hasCreateAccess)
	 * {
	 * 	LOG_Builder.build().info('User can create Account records').emitAt('MyFlow.checkPermissions');
	 * }
	 * ```
	 */
	@InvocableMethod(Category='Utilities' Label='Check Object Permissions' Description='Checks whether the current user has read, create, edit, and delete access to a specified Salesforce object. Use to conditionally show or hide UI elements based on permissions.')
	global static List<DTO_Response> checkPermissions(List<DTO_Request> dtoRequests)
	{
		List<DTO_Response> dtoObjectAccesses = new List<DTO_Response>();

		for(DTO_Request dtoRequest : dtoRequests)
		{
			DTO_Response dtoObjectAccess = new DTO_Response();

			dtoObjectAccess.objectApiName = dtoRequest.objectApiName;

			SObjectType objectType = UTIL_SObjectDescribe.getSObjectTypeByName(dtoRequest.objectApiName);

			if(objectType != null)
			{
				DescribeSObjectResult describe = UTIL_SObjectDescribe.getDescribe(objectType).getDescribe();

				dtoObjectAccess.isValidObject = true;
				dtoObjectAccess.hasCreateAccess = describe.isCreateable();
				dtoObjectAccess.hasDeleteAccess = describe.isDeletable();
				dtoObjectAccess.hasEditAccess = describe.isUpdateable();
				dtoObjectAccess.hasReadAccess = describe.isAccessible();
			}

			dtoObjectAccesses.add(dtoObjectAccess);
		}

		return dtoObjectAccesses;
	}

	/**
	 * @description DTO containing the name of the object for which to object permissions
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Request
	{
		/**
		 * @description The API name of the object for which to check permissions.
		 *
		 * @since 1.0
		 */
		@InvocableVariable(Label='Object Name' Description='The API name of the object for which you want to check permissions' Required=true PlaceholderText='Foobar__c')
		global String objectApiName;
	}

	/**
	 * @description DTO containing the permissions per object provided in request.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Response
	{
		/**
		 * @description The API name of the object these permissions apply to.
		 *
		 * @since 1.0
		 */
		@InvocableVariable(Required=true Label='Object Name' Description='The API name of the object these permissions apply to')
		global String objectApiName;

		/**
		 * @description Whether the provided object API name resolves to a valid SObject type.
		 *
		 * @since 1.0
		 */
		@InvocableVariable(Label='Is Valid Object' Description='Whether the provided object API name resolves to a valid SObject type')
		global Boolean isValidObject = false;

		/**
		 * @description Whether the running user has read access to the object.
		 *
		 * @since 1.0
		 */
		@InvocableVariable(Required=true Label='Has Read Access' Description='Whether the running user can read records of this object type')
		global Boolean hasReadAccess = false;

		/**
		 * @description Whether the running user has create access to the object.
		 *
		 * @since 1.0
		 */
		@InvocableVariable(Required=true Label='Has Create Access' Description='Whether the running user can create records of this object type')
		global Boolean hasCreateAccess = false;

		/**
		 * @description Whether the running user has edit access to the object.
		 *
		 * @since 1.0
		 */
		@InvocableVariable(Required=true Label='Has Edit Access' Description='Whether the running user can edit records of this object type')
		global Boolean hasEditAccess = false;

		/**
		 * @description Whether the running user has delete access to the object.
		 *
		 * @since 1.0
		 */
		@InvocableVariable(Required=true Label='Has Delete Access' Description='Whether the running user can delete records of this object type')
		global Boolean hasDeleteAccess = false;
	}
}