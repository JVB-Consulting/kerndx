// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Invocable method to get all the picklist values for a particular object for a given record type.
 * Delegates to UTIL_SObjectDescribe for ConnectApi retrieval and transformation.
 * Caches responses in org cache to reduce repeated ConnectApi calls for the same requests.
 *
 * @see DTO_PickList
 * @see DTO_PicklistValue
 * @see UTIL_SObjectDescribe
 * @see FLOW_GetPicklistValues_TEST
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
 * FLOW_GetPicklistValues.DTO_Request request = new FLOW_GetPicklistValues.DTO_Request();
 * request.objectApiName = 'Contact';
 * request.recordTypeApiName = 'Customer_Contact';
 * List<FLOW_GetPicklistValues.DTO_Response> responses = FLOW_GetPicklistValues.getPickListValues(new List<FLOW_GetPicklistValues.DTO_Request> {request});
 * List<DTO_PickList> pickLists = responses[0].pickLists;
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,LongLine')
global inherited sharing class FLOW_GetPicklistValues
{
	/**
	 * @description Test-only exception to exercise the catch block. ConnectApi.RecordUi does not support
	 * setTestData or mocking, so this is the only way to verify exception handling behaviour.
	 */
	@TestVisible
	private static Exception testException;

	/**
	 * @description Error message when the record type cannot be found.
	 */
	@TestVisible
	private static final String ERROR_NO_RECORD_TYPE = 'Unable to find a record type Id for the given object name: "{0}" & record type name: "{1}"';

	/**
	 * @description Retrieves the picklist values for an SObject and record type combination.
	 * Checks the org cache for stored values first and only calls ConnectApi if the values are not cached.
	 *
	 * @param dtoRequests A list of requests indicating for which object and record type combination to retrieve picklist values
	 *
	 * @return A list of responses (only will ever contain 1 item)
	 *
	 * @throws IllegalArgumentException If more than one request provided, an exception will be thrown
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<DTO_Request> dtoRequests = new List<DTO_Request>();
	 * DTO_Request request = new DTO_Request();
	 * request.objectApiName = 'Contact';
	 * request.recordTypeApiName = 'Customer_Contact';
	 * dtoRequests.add(request);
	 * List<DTO_Response> responses = FLOW_GetPicklistValues.getPickListValues(dtoRequests);
	 * ```
	 */
	@InvocableMethod(Category='Utilities' Label='Get PickList Values' Description='Returns the available picklist values for a specified object and record type. Use to dynamically populate choice lists or validate picklist selections in a Flow.')
	global static List<DTO_Response> getPickListValues(List<DTO_Request> dtoRequests)
	{
		TRG_Base.validateSingleRequest(dtoRequests.size(), FLOW_GetPicklistValues.class.getName());

		DTO_Request dtoRequest = dtoRequests.iterator().next();

		DTO_Response dtoResponse = getResponseFromCache(dtoRequest);

		if(dtoResponse == null)
		{
			dtoResponse = new DTO_Response();

			try
			{
				SObjectType objectType = UTIL_SObjectDescribe.getSObjectTypeByName(dtoRequest.objectApiName);
				Id recordTypeId = UTIL_SObjectDescribe.getRecordTypeByDeveloperName(objectType, dtoRequest.recordTypeApiName);

				if(String.isBlank(recordTypeId))
				{
					dtoResponse.callSuccessful = false;
					dtoResponse.errorText = String.format(ERROR_NO_RECORD_TYPE, new List<String> {dtoRequest.objectApiName, dtoRequest.recordTypeApiName});
				}
				else
				{
					if(testException != null)
					{
						throw testException;
					}

					dtoResponse.callSuccessful = true;
					dtoResponse.pickLists = UTIL_SObjectDescribe.getPicklistValues(dtoRequest.objectApiName, recordTypeId);
				}
			}
			catch(Exception error)
			{
				dtoResponse.callSuccessful = false;
				dtoResponse.errorText = error.getMessage();
			}

			saveResponseToCache(dtoRequest, dtoResponse);
		}

		return new List<DTO_Response> {dtoResponse};
	}

	/**
	 * @description Checks org cache for a stored response matching the request.
	 *
	 * @param dtoRequest The request provided
	 *
	 * @return Cached response or null if not found
	 */
	private static DTO_Response getResponseFromCache(DTO_Request dtoRequest)
	{
		return (DTO_Response)UTIL_Cache.org().get(getCacheKeyName(dtoRequest));
	}

	/**
	 * @description Constructs a cache key from the object and record type names.
	 *
	 * @param dtoRequest Request from which to construct a key name
	 *
	 * @return A string containing the cache key name
	 */
	private static String getCacheKeyName(DTO_Request dtoRequest)
	{
		return UTIL_String.remove(dtoRequest.objectApiName + dtoRequest.recordTypeApiName, '_');
	}

	/**
	 * @description Stores the response in org cache.
	 *
	 * @param dtoRequest Original request containing object and record type name
	 * @param dtoResponse The response to cache
	 */
	private static void saveResponseToCache(DTO_Request dtoRequest, DTO_Response dtoResponse)
	{
		UTIL_Cache.org().put(getCacheKeyName(dtoRequest), dtoResponse);
	}

	/**
	 * @description Request DTO containing the information required to retrieve picklist values.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Request
	{
		/**
		 * @description The object API name for the SObject whose picklist values are being retrieved.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.objectApiName;
		 * ```
		 */
		@InvocableVariable(Label='Object Name' Description='The SObject Api Name' Required=true PlaceholderText='Foobar__c')
		global String objectApiName;

		/**
		 * @description The Record Type API name for which to retrieve specifically configured picklist values.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.recordTypeApiName;
		 * ```
		 */
		@InvocableVariable(Label='Record Type Name' Description='The Record Type Api Name' Required=true PlaceholderText='DefaultFoobar')
		global String recordTypeApiName;
	}

	/**
	 * @description Provides the outcome of the picklist values retrieval.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Response
	{
		/**
		 * @description Indicates if the retrieval was successful.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean value = instance.callSuccessful;
		 * ```
		 */
		@InvocableVariable(Label='Call Successful' Description='Indicates whether an error was encountered when performing a request' Required=true)
		global Boolean callSuccessful;

		/**
		 * @description If the request was unsuccessful this will contain the error message.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.errorText;
		 * ```
		 */
		@InvocableVariable(Label='Error Text' Description='Will contains the error message(s) if any are encountered' Required=false)
		global String errorText;

		/**
		 * @description If the request was successful this will contain a list of picklists and their values for a given object and record type.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<DTO_PickList> value = instance.pickLists;
		 * ```
		 */
		@InvocableVariable(Label='PickList' Description=' will contain a list of picklist and their values for a given object and record type' Required=false)
		global List<DTO_PickList> pickLists;
	}
}