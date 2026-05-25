// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unified result of an API invocation, used by both outbound and inbound invokers.
 * Consolidates shared fields (response, headers, timing) with direction-specific fields
 * (apiCallId for outbound, httpMethod/url for inbound) into a single type.
 *
 * @see DTO_InvocationResult_TEST
 *
 * @author Jason van Beukering
 *
 * @group Data Transfer Objects
 *
 * @date February 2026, May 2026
 */
public inherited sharing class DTO_InvocationResult
{
	/**
	 * @description HTTP status code of the response.
	 */
	public Integer statusCode;

	/**
	 * @description Response body content.
	 */
	public String responseBody;

	/**
	 * @description Original request body.
	 */
	public String requestBody;

	/**
	 * @description The service class name.
	 */
	public String serviceName;

	/**
	 * @description The status of the API call (e.g. Completed, Failed, Aborted).
	 */
	public String status;

	/**
	 * @description The ApiCall__c record ID (outbound only).
	 */
	public String apiCallId;

	/**
	 * @description The HTTP method (inbound only).
	 */
	public String httpMethod;

	/**
	 * @description The request URL (inbound only).
	 */
	public String url;

	/**
	 * @description Whether Safe Mode was enabled for this invocation.
	 */
	public Boolean safeModeEnabled;

	/**
	 * @description Total execution time in milliseconds.
	 */
	public Long executionTimeMs;

	/**
	 * @description Whether mocking was enabled for this invocation.
	 */
	public Boolean mockingEnabled;

	/**
	 * @description Whether the response was mocked (handler-level).
	 */
	public Boolean isMockedResponse;

	/**
	 * @description Newline-delimited error text from the handler.
	 */
	public String errorText;

	/**
	 * @description List of error messages if invocation failed.
	 */
	public List<String> errors;

	/**
	 * @description Request headers as name-value pairs.
	 */
	public DTO_NameValues requestHeaders;

	/**
	 * @description Response headers as name-value pairs.
	 */
	public DTO_NameValues responseHeaders;

	/**
	 * @description Handler processing time in milliseconds (service time minus callout time).
	 */
	public Long handlerDurationMs;

	/**
	 * @description Callout processing time in milliseconds.
	 */
	public Long calloutDurationMs;

	/**
	 * @description Commit processing time in milliseconds.
	 */
	public Long commitDurationMs;

	/**
	 * @description Whether the invocation was successful (2xx status code).
	 */
	public Boolean success
	{
		get
		{
			return statusCode != null && statusCode >= 200 && statusCode < 300;
		}
	}

	/**
	 * @description Creates a new invocation result with default empty collections.
	 */
	public DTO_InvocationResult()
	{
		errors = new List<String>();
		requestHeaders = new DTO_NameValues();
		responseHeaders = new DTO_NameValues();
	}
}