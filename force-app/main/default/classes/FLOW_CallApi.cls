// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Invokes web service calls synchronously,
 * allowing for integration with external systems from Salesforce using Lightning Flow or Process Builder.
 * Receives a list of requests, sends them to their respective endpoints, and returns responses
 * as structured data.
 *
 * @see FLOW_CallApi_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * FLOW_CallApi.DTO_Request request = new FLOW_CallApi.DTO_Request();
 * request.apiName = 'API_GetCustomerInfo';
 * request.recordId = recordId;
 * request.inputs = 'customerId=5678';
 * List<FLOW_CallApi.DTO_Response> responses = FLOW_CallApi.invokeApiCallSynchronously(new List<FLOW_CallApi.DTO_Request> {request});
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,LongLine')
global inherited sharing class FLOW_CallApi
{
	/**
	 * @description Invokes web service calls synchronously using a list of DTO_Request objects.
	 *
	 * @param requestDataTransferObjects The list of web service requests to execute.
	 *
	 * @return List<DTO_Response> The results of the calls.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<FLOW_CallApi.DTO_Request> requests = new List<FLOW_CallApi.DTO_Request>();
	 * FLOW_CallApi.DTO_Request request = new FLOW_CallApi.DTO_Request();
	 * request.apiName = 'API_GetCustomerInfo';
	 * request.inputs = 'customerId=5678';
	 * requests.add(request);
	 * List<FLOW_CallApi.DTO_Response> responses = FLOW_CallApi.invokeApiCallSynchronously(requests);
	 * ```
	 */
	@InvocableMethod
	(
			Category='Api Callouts'
			Callout=true Label='Invoke Callout Synchronously'
			Description='Makes a real-time HTTP callout to an external system using a configured API handler. Use when a Flow needs to send or retrieve data from an external service and wait for the response.'
	)
	global static List<DTO_Response> invokeApiCallSynchronously(List<DTO_Request> requestDataTransferObjects)
	{
		List<DTO_Response> responseDataTransferObjects = new List<DTO_Response>();

		List<API_Base> apiHandlers = invokeApiCallSynchronouslyWithHandlers(requestDataTransferObjects);

		for(Integer i = 0; i < apiHandlers.size(); i++)
		{
			responseDataTransferObjects.add(processApiCallResponse(requestDataTransferObjects[i], (API_Outbound)apiHandlers[i]));
		}

		return responseDataTransferObjects;
	}

	/**
	 * @description Converts DTO_Request objects into API calls, executes each API call synchronously,
	 * and returns a list of API_Base handlers.
	 *
	 * @param requestDataTransferObjects The list of web service requests to execute.
	 *
	 * @return List<API_Base> The list of handlers that executed the requests.
	 */
	private static List<API_Base> invokeApiCallSynchronouslyWithHandlers(List<DTO_Request> requestDataTransferObjects)
	{
		List<ApiCall__c> apiCalls = new List<ApiCall__c>();

		for(DTO_Request requestDataTransferObject : requestDataTransferObjects)
		{
			Map<String, String> parameterMap =
					UTIL_String.toMap(requestDataTransferObject.inputs, requestDataTransferObject.inputDelimiter);

			ApiCall__c apiCall = TST_Factory.newOutboundApiCall
					(
							requestDataTransferObject.apiName,
							UTIL_SObject.validateId(requestDataTransferObject.recordId),
							parameterMap
					);

			if(String.isNotBlank(requestDataTransferObject.idempotencyKey))
			{
				apiCall.IdempotencyKey__c = requestDataTransferObject.idempotencyKey;
			}

			apiCalls.add(apiCall);
		}

		return API_Dispatcher.execute(apiCalls);
	}

	/**
	 * @description Processes a response received from an API call and generates a DTO_Response object.
	 *
	 * @param requestDataTransferObject The original request passed to the invocable action.
	 * @param outboundHandler The API handler that performed the request.
	 *
	 * @return DTO_Response The handler's response transformed into a generic structure.
	 */
	private static DTO_Response processApiCallResponse(DTO_Request requestDataTransferObject, API_Outbound outboundHandler)
	{
		DTO_Response responseDataTransferObject = new DTO_Response();

		API_Base.ServiceCallResult callResult = outboundHandler.result;

		responseDataTransferObject.success = callResult.isSuccess;
		responseDataTransferObject.apiCallId = outboundHandler.apiCall.Id;

		if(!responseDataTransferObject.success)
		{
			responseDataTransferObject.responseBody = outboundHandler.errorText;
		}
		else
		{
			responseDataTransferObject.responseBody = callResult.responseBody;
		}

		extractElementValue(requestDataTransferObject, responseDataTransferObject);

		return responseDataTransferObject;
	}

	/**
	 * @description Extracts a specified element from the JSON response body using JSONPath.
	 *
	 * @param requestDataTransferObject The original request.
	 * @param responseDataTransferObject The response where the extracted value should be written.
	 *
	 * @see UTIL_JsonPath
	 */
	private static void extractElementValue(DTO_Request requestDataTransferObject, DTO_Response responseDataTransferObject)
	{
		if(String.isNotBlank(requestDataTransferObject.extractPath))
		{
			try
			{
				UTIL_JsonPath foundItem = (new UTIL_JsonPath(responseDataTransferObject.responseBody)).findNode(requestDataTransferObject.extractPath);
				if(foundItem != null)
				{
					responseDataTransferObject.extractedValue =
							foundItem.isArray() || foundItem.isObject() ? foundItem.toStringPretty() : foundItem.getStringValue();
				}
			}
			catch(Exception error)
			{
				responseDataTransferObject.extractedValue = error.getMessage();
				LOG_Builder.build().error(error).at(FLOW_CallApi.class.getName() + '/extractElementValue').emit();
			}
		}
	}

	/**
	 * @description Data Transfer Object representing the web service call request.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Request
	{
		/**
		 * @description The full class name of the API handler to invoke.
		 *
		 * @since 1.0
		 */
		@InvocableVariable(Label='API Name' Description='The full class name of the API handler' Required=true PlaceholderText='API_PostExample')
		global String apiName;

		/**
		 * @description The ID of the record triggering the callout.
		 *
		 * @since 1.0
		 */
		@InvocableVariable(Label='Record Id' Description='The ID of the object triggering the callout' Required=false)
		global String recordId;

		/**
		 * @description A comma-delimited list of parameters in the format paramName=paramValue.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				Label='Inputs'
				Description='A list of parameters in the format paramName=paramValue,paramName2=paramValue2'
				Required=false
				PlaceholderText='ubiNum=1234'
		)
		global String inputs;

		/**
		 * @description A JSONPath expression to extract a specific element from the response body.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				Label='Extract Path (JSONPath)'
				Description='Element to extract from the JSON response, using JsonPath Notation'
				Required=false
		)
		global String extractPath;

		/**
		 * @description The delimiter used to split input parameters, defaults to a comma.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				Label='Input Delimiter'
				Description='The delimiter to use when splitting parameters, defaults to a comma'
				Required=false
		)
		global String inputDelimiter;

		/**
		 * @description Explicit idempotency key for duplicate detection. If blank, auto-generated when enabled.
		 *
		 * @since 1.0
		 */
		@InvocableVariable(Label='Idempotency Key' Description='Explicit idempotency key for duplicate detection. If blank, auto-generated when enabled.' Required=false)
		global String idempotencyKey;
	}

	/**
	 * @description Data Transfer Object representing the web service response or errors.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Response
	{
		/**
		 * @description Whether the API callout completed successfully.
		 *
		 * @since 1.0
		 */
		@InvocableVariable(Label='API Response Success Indicator' Description='A boolean representation of the success or failure of the callout')
		global Boolean success;

		/**
		 * @description The JSON payload containing the response body or failure message.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				Label='Response Body'
				Description='The JSON payload containing the response of the callout or failure message if applicable'
		)
		global String responseBody;

		/**
		 * @description The ID of the ApiCall__c record for this callout.
		 *
		 * @since 1.0
		 */
		@InvocableVariable(Label='API Call Id' Description='Id of the API Call record for the callout')
		global String apiCallId;

		/**
		 * @description The value extracted from the JSON response using the specified JSONPath.
		 *
		 * @since 1.0
		 */
		@InvocableVariable(Label='Extracted Value' Description='The extracted element from the JSON response')
		global String extractedValue;
	}
}