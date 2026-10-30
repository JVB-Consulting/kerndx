// SPDX-License-Identifier: Apache-2.0
/**
 * @description Invokes inbound API requests programmatically with Safe Mode support.
 * Routes requests through the inbound API pipeline without external HTTP traffic.
 * When Safe Mode is enabled, all DML is rolled back. It also runs an inbound issue's request again (a replay): it reads
 * the request from the call the issue links to, and sends it to the service the issue names.
 * The complexity warnings are turned off for this class on purpose: rebuilding a stored request and running it again
 * belong to the invoker, so the code stays here instead of moving to a new class.
 *
 * @see API_InboundInvoker_TEST
 * @see CTRL_RetryApiIssue
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.AvoidBooleanMethodParameters, PMD.CognitiveComplexity, PMD.CyclomaticComplexity')
public inherited sharing class API_InboundInvoker
{
	/**
	 * @description When a test sets this to true, the invoker throws an exception during the call. This is the only
	 * way a test can reach the invoker's error handling. API_Dispatcher.routeRequest() catches the errors of a
	 * handler itself, so no normal failure reaches this invoker's catch block. The catch block is a safety net for
	 * unexpected platform failures, such as a governor limit or a runtime error while the request is routed.
	 */
	@TestVisible
	private static Boolean forceException = false;

	/**
	 * @description The title, with its file extension, of the file that holds the whole request body of a call when the
	 * body is too long for the call's Request__c field. It is built from the title API_Base gives the file when it saves
	 * the call.
	 */
	private static final String REQUEST_BODY_FILE_TITLE = API_Base.REQUEST_BODY_FILE_TITLE + SEL_ContentVersion.TEXT_FILE_EXTENSION;

	/**
	 * @description The character that starts the query string in a call's address.
	 */
	private static final String QUERY_STRING_START = '?';

	/**
	 * @description True while an issue's request is being run again. While it is true, a failed run writes no new
	 * issue (see API_Inbound.buildInboundFailureRecord). It is set and cleared by replay.
	 */
	private static Boolean replayRunning = false;

	/**
	 * @description The id of the call whose request is being run again, or null when no replay is running or the
	 * request came from the issue's own fields. The new call links to it through PreviousAttempt__c. It is set and
	 * cleared by replay.
	 */
	private static Id replayedCallId;

	/**
	 * @description The user who sent the call whose request is being run again (its CreatedById), or null when no replay
	 * of a call is running. The request still belongs to that user, so its Idempotency-Key is checked as that user, not
	 * as the person who runs it again. It is set and cleared by replay.
	 */
	private static Id replayedCallSenderId;

	/**
	 * @description Checks whether an issue's request is being run again in this transaction.
	 *
	 * @return True while a replay runs
	 */
	public static Boolean isReplayRunning()
	{
		return replayRunning;
	}

	/**
	 * @description Returns the id of the call whose request is being run again, so the new call can link to it.
	 *
	 * @return The id of the earlier call, or null when no replay of a call is running
	 */
	public static Id getReplayedCallId()
	{
		return replayedCallId;
	}

	/**
	 * @description Returns the user who sent the call whose request is being run again, so the request's key is checked
	 * as the user it belongs to (see API_Inbound.checkIdempotency).
	 *
	 * @return The id of that user, or null when no replay of a call is running
	 */
	public static Id getReplayedCallSenderId()
	{
		return replayedCallSenderId;
	}

	/**
	 * @description Invokes an inbound request with optional Safe Mode and custom headers.
	 *
	 * @param path The request URI path
	 * @param method The HTTP method (GET, POST, etc.)
	 * @param body The request body (optional)
	 * @param headers Map of request headers to apply (optional)
	 * @param enableSafeMode When true, all DML is rolled back after execution
	 *
	 * @return DTO_InvocationResult containing response and execution details
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	public static DTO_InvocationResult invoke(String path, String method, String body, Map<String, String> headers, Boolean enableSafeMode)
	{
		InboundRequest request = new InboundRequest();
		request.path = path;
		request.method = method;
		request.body = body;
		if(headers != null)
		{
			request.headers.putAll(headers);
		}
		return invoke(request, enableSafeMode);
	}

	/**
	 * @description Sends a request through the inbound pipeline and collects what happened. A request that names a
	 * service is sent to that service's handler. A request that names none is routed by its path, as a live request is.
	 *
	 * @param request The request to send
	 * @param enableSafeMode When true, all DML is rolled back after execution
	 *
	 * @return DTO_InvocationResult containing response and execution details
	 */
	private static DTO_InvocationResult invoke(InboundRequest request, Boolean enableSafeMode)
	{
		DTO_InvocationResult dtoInvocationResult = new DTO_InvocationResult();
		dtoInvocationResult.safeModeEnabled = enableSafeMode;

		API_Base.SafeModeContext safeMode = null;

		try
		{
			if(enableSafeMode)
			{
				safeMode = API_Base.enterSafeMode();
			}

			RestContext.request = new RestRequest();
			RestContext.request.requestURI = request.path;
			RestContext.request.httpMethod = request.method;
			if(String.isNotBlank(request.body))
			{
				RestContext.request.requestBody = Blob.valueOf(request.body);
			}

			for(String headerName : request.headers.keySet())
			{
				RestContext.request.addHeader(headerName, request.headers.get(headerName));
			}

			for(String parameterName : request.parameters.keySet())
			{
				RestContext.request.addParameter(parameterName, request.parameters.get(parameterName));
			}

			RestContext.response = new RestResponse();

			if(forceException)
			{
				throw new UTIL_Exceptions.IllegalStateException('Forced test exception');
			}

			API_Base handler = String.isBlank(request.serviceName)
					? API_Dispatcher.routeRequest()
					: API_Dispatcher.processInboundService(request.serviceName);

			dtoInvocationResult.statusCode = RestContext.response.statusCode;
			dtoInvocationResult.responseBody = RestContext.response.responseBody?.toString();
			dtoInvocationResult.requestBody = request.body;
			if(RestContext.request?.headers.isEmpty() == false)
			{
				dtoInvocationResult.requestHeaders = new DTO_NameValues(RestContext.request.headers);
			}
			if(RestContext.response?.headers.isEmpty() == false)
			{
				dtoInvocationResult.responseHeaders = new DTO_NameValues(RestContext.response.headers);
			}

			if(handler != null)
			{
				dtoInvocationResult.errorText = handler.errorText;
				dtoInvocationResult.executionTimeMs = handler.fullProcessingTime.getTime();
				dtoInvocationResult.isMockedResponse = handler.result.isMocked;

				dtoInvocationResult.handlerDurationMs = handler.serviceProcessingTime.getTime() - handler.calloutProcessingTime.getTime();
				dtoInvocationResult.calloutDurationMs = handler.calloutProcessingTime.getTime();
				dtoInvocationResult.commitDurationMs = handler.commitProcessingTime.getTime();

				if(handler.apiCall != null)
				{
					ApiCall__c log = handler.apiCall;
					dtoInvocationResult.serviceName = log.ServiceName__c;
					dtoInvocationResult.status = log.Status__c;
					dtoInvocationResult.httpMethod = log.HttpMethod__c;
					dtoInvocationResult.url = log.URL__c;
				}
			}
		}
		catch(Exception invocationError)
		{
			dtoInvocationResult.statusCode = API_Base.HTTP_INTERNAL_SERVER_ERROR;
			dtoInvocationResult.errors.add(invocationError.getMessage());
			dtoInvocationResult.errors.add(invocationError.getStackTraceString());
			dtoInvocationResult.errorText = String.join(dtoInvocationResult.errors, UTIL_String.LF);
			LOG_Builder.build().error(invocationError).emitAt(API_InboundInvoker.class.getName() + '.invoke');
		}
		finally
		{
			safeMode?.close();
		}

		return dtoInvocationResult;
	}

	/**
	 * @description Invokes an inbound request with optional Safe Mode (no custom headers).
	 *
	 * @param path The request URI path
	 * @param method The HTTP method (GET, POST, etc.)
	 * @param body The request body (optional)
	 * @param enableSafeMode When true, all DML is rolled back after execution
	 *
	 * @return DTO_InvocationResult containing response and execution details
	 */
	public static DTO_InvocationResult invoke(String path, String method, String body, Boolean enableSafeMode)
	{
		return invoke(path, method, body, null, enableSafeMode);
	}

	/**
	 * @description Invokes an inbound request with Safe Mode enabled by default.
	 *
	 * @param path The request URI path
	 * @param method The HTTP method
	 * @param body The request body
	 *
	 * @return DTO_InvocationResult
	 */
	public static DTO_InvocationResult invoke(String path, String method, String body)
	{
		return invoke(path, method, body, null, true);
	}

	/**
	 * @description Invokes an inbound API by service class name with optional mocking.
	 * Resolves the endpoint path and HTTP method from ApiSetting__mdt, enabling
	 * service discovery without requiring callers to know URL paths.
	 *
	 * @param serviceName The API handler class name (e.g., 'API_Echo')
	 * @param body The request body (optional)
	 * @param enableSafeMode When true, all DML is rolled back
	 * @param enableMocking When true, enables transaction-scoped mocking
	 *
	 * @return DTO_InvocationResult containing response and execution details
	 */
	public static DTO_InvocationResult invokeByServiceName(String serviceName, String body, Boolean enableSafeMode, Boolean enableMocking)
	{
		ApiSetting__mdt setting = new SEL_ApiSetting().findByClassName(serviceName);

		if(setting == null)
		{
			DTO_InvocationResult errorResult = new DTO_InvocationResult();
			errorResult.statusCode = API_Base.HTTP_NOT_FOUND;
			errorResult.errors.add('No ApiSetting__mdt found for service: ' + serviceName);
			errorResult.errorText = errorResult.errors.iterator().next();
			return errorResult;
		}

		if(enableMocking)
		{
			API_MockFactory.enableMocking(serviceName);
		}

		String path = toConcreteEndpointPath(setting.EndpointPath__c);

		DTO_InvocationResult invocationResult = invoke(path, null, body, null, enableSafeMode);
		invocationResult.mockingEnabled = enableMocking;
		return invocationResult;
	}

	/**
	 * @description Converts an endpoint pattern (e.g. '/echo/*') to a concrete
	 * routable path (e.g. '/echo/test') by replacing wildcard segments with 'test'.
	 *
	 * @param endpointPattern The pattern from ApiSetting__mdt EndpointPath__c
	 *
	 * @return A concrete path suitable for route matching
	 */
	@TestVisible
	private static String toConcreteEndpointPath(String endpointPattern)
	{
		if(String.isBlank(endpointPattern))
		{
			return '/test';
		}
		return endpointPattern.replace('/*', '/test').replace('*', 'test');
	}

	/**
	 * @description Reads the request each inbound issue would run again. Two reads at most, whatever the number of issues:
	 * the request fields of the issues' calls (SEL_ApiCall.findRequestById, unless the caller already read them), and
	 * the files of those calls (a body too long for its field is kept whole in a file). For each issue:
	 *
	 * 1. When the issue links to a call that still exists, the request comes from the call: the path (the address
	 *    before its query string), the method, the body (from the call's request body file when there is one, else from
	 *    Request__c), the parameters (from RequestParameters__c), and the Idempotency-Key. The request is marked as not
	 *    an exact copy when the body's SHA-256 hash differs from the hash the call recorded when the request came in
	 *    (masking changed the body, or it was cut and no file holds it), when the address or the parameters fill their
	 *    field to its full length (they may have been cut), or when the parameters cannot be read back.
	 * 2. A call saved before version 1.9 recorded the hash only when the request carried an Idempotency-Key. So for a
	 *    call with no key and no hash, a missing hash means "not known", not "changed" (see isSavedWithoutAHash and
	 *    buildRequestFromIssueOfCall). The request comes from the call when the call kept it whole: the body fits
	 *    in Request__c with room to spare and needed no file, and the address and the parameters are whole. Otherwise
	 *    it comes from the issue's own fields when the issue holds a request path, and it still links to the call.
	 *    Otherwise the request from the call is marked as not an exact copy, as in rule 1.
	 * 3. When the issue has no call but holds a request path in its own fields (an issue made by hand), the request
	 *    comes from those fields, and no exact copy check is possible.
	 * 4. Otherwise the issue has no request, and it gets none in the answer.
	 *
	 * Every request is sent to the service the issue names.
	 *
	 * @param issues The inbound issues
	 * @param callById The calls already read through SEL_ApiCall.findRequestById, by id; may be null, and then the calls
	 * are read here
	 *
	 * @return The request of each issue that has one, by issue id
	 */
	public static Map<Id, InboundRequest> readStoredRequests(List<ApiIssue__c> issues, Map<Id, ApiCall__c> callById)
	{
		Set<Id> callIds = UTIL_SObject.extractIds(issues, ApiIssue__c.ApiCall__c, true);
		Map<Id, ApiCall__c> knownCallById = callById;
		if(knownCallById == null)
		{
			knownCallById = new Map<Id, ApiCall__c>(callIds.isEmpty() ? new List<ApiCall__c>() : new SEL_ApiCall().findRequestById(callIds));
		}
		callIds.retainAll(knownCallById.keySet());
		Map<Id, String> fileBodyByCallId = readRequestBodyFiles(callIds);

		Map<Id, InboundRequest> requestByIssueId = new Map<Id, InboundRequest>();
		for(ApiIssue__c issue : issues)
		{
			ApiCall__c originalCall = knownCallById.get(issue.ApiCall__c);
			InboundRequest request = originalCall != null
					? buildRequestFromCall(originalCall, fileBodyByCallId.get(originalCall.Id), issue)
					: buildRequestFromIssue(issue);
			if(request != null)
			{
				request.serviceName = issue.ServiceName__c;
				requestByIssueId.put(issue.Id, request);
			}
		}
		return requestByIssueId;
	}

	/**
	 * @description Reads the whole request body of each call that kept its body in a file.
	 *
	 * @param callIds The ids of the calls
	 *
	 * @return The body text in each call's request body file, by call id; a call without such a file is left out
	 */
	private static Map<Id, String> readRequestBodyFiles(Set<Id> callIds)
	{
		Map<Id, String> fileBodyByCallId = new Map<Id, String>();
		if(callIds.isEmpty())
		{
			return fileBodyByCallId;
		}
		for(ContentVersion version : new SEL_ContentVersion().findByFirstPublishLocationId(callIds))
		{
			if(version.Title == REQUEST_BODY_FILE_TITLE)
			{
				fileBodyByCallId.put(version.FirstPublishLocationId, version.VersionData.toString());
			}
		}
		return fileBodyByCallId;
	}

	/**
	 * @description Builds the request a call kept, and checks that it is an exact copy of the request that came in (see
	 * readStoredRequests). A call with no key and no hash, saved before version 1.9, is checked another way: its request
	 * is run when the call kept it whole, else the issue's own copy (see buildRequestFromIssueOfCall).
	 *
	 * @param originalCall The call, with its request fields
	 * @param fileBody The body from the call's request body file, or null when the call has no such file
	 * @param issue The issue that links to the call
	 *
	 * @return The request, linked to the call
	 */
	private static InboundRequest buildRequestFromCall(ApiCall__c originalCall, String fileBody, ApiIssue__c issue)
	{
		InboundRequest request = new InboundRequest();
		request.originalCallId = originalCall.Id;
		request.originalCallSenderId = originalCall.CreatedById;
		request.path = originalCall.URL__c?.substringBefore(QUERY_STRING_START);
		request.method = originalCall.HttpMethod__c;
		request.body = fileBody ?? originalCall.Request__c;
		if(String.isNotBlank(originalCall.IdempotencyKey__c))
		{
			request.headers.put(API_Base.HEADER_IDEMPOTENCY_KEY, originalCall.IdempotencyKey__c);
		}
		addJsonContentType(request);

		Boolean isAddressWhole = readParameters(originalCall.RequestParameters__c, request.parameters)
				&& !isFieldFull(originalCall.URL__c, SEL_ApiCall.URL_LENGTH)
				&& !isFieldFull(originalCall.RequestParameters__c, SEL_ApiCall.REQUEST_PARAMETERS_LENGTH);
		if(isSavedWithoutAHash(originalCall))
		{
			Boolean isRequestWhole = isAddressWhole && fileBody == null && !isFieldFull(originalCall.Request__c, SEL_ApiCall.REQUEST_LENGTH);
			return isRequestWhole ? request : buildRequestFromIssueOfCall(request, issue);
		}
		request.isExactCopy = isAddressWhole && originalCall.IdempotencyKeyBodyHash__c == API_Inbound.computeBodyHash(request.body);
		return request;
	}

	/**
	 * @description Checks whether a call has no Idempotency-Key and no hash of its body. Before version 1.9, a call
	 * recorded the hash only when the request carried a key, so for such a call nobody knows whether the stored body is
	 * the one received. A call with a key always recorded the hash, so a call with a key and no hash is not one of these.
	 *
	 * @param originalCall The call, with its request fields
	 *
	 * @return True when the call has neither a key nor a hash
	 */
	private static Boolean isSavedWithoutAHash(ApiCall__c originalCall)
	{
		return String.isBlank(originalCall.IdempotencyKey__c) && String.isBlank(originalCall.IdempotencyKeyBodyHash__c);
	}

	/**
	 * @description Chooses the request to run again for a call with no key and no hash (see isSavedWithoutAHash) that did
	 * not keep the request whole. When the call kept it whole, the request from the call is run and this method is not
	 * used. Otherwise:
	 *
	 * 1. When the issue holds a request path in its own fields, the request the issue holds is run. Version 1.8 ran an
	 *    issue's request from those fields, so a person may have typed the request there. The new call still links to
	 *    the issue's call.
	 * 2. Otherwise the request from the call is marked as not an exact copy, so it is refused as a call that no longer
	 *    holds the request as it came in.
	 *
	 * @param callRequest The request built from the call
	 * @param issue The issue that links to the call
	 *
	 * @return The request to run again
	 */
	private static InboundRequest buildRequestFromIssueOfCall(InboundRequest callRequest, ApiIssue__c issue)
	{
		InboundRequest issueRequest = buildRequestFromIssue(issue);
		if(issueRequest == null)
		{
			callRequest.isExactCopy = false;
			return callRequest;
		}
		issueRequest.originalCallId = callRequest.originalCallId;
		issueRequest.originalCallSenderId = callRequest.originalCallSenderId;
		return issueRequest;
	}

	/**
	 * @description Builds the request an issue holds in its own fields: for an issue made by hand that links to no call,
	 * or for an issue whose call has no key and no hash and did not keep the request whole (see
	 * buildRequestFromIssueOfCall).
	 *
	 * @param issue The issue
	 *
	 * @return The request, or null when the issue holds no request path
	 */
	private static InboundRequest buildRequestFromIssue(ApiIssue__c issue)
	{
		if(String.isBlank(issue.RequestPath__c))
		{
			return null;
		}
		InboundRequest request = new InboundRequest();
		request.path = issue.RequestPath__c;
		request.method = issue.RequestMethod__c;
		request.body = issue.RequestBody__c;
		addJsonContentType(request);
		return request;
	}

	/**
	 * @description Adds the JSON content type header when the body looks like JSON. The call and the issue keep no
	 * headers, so the replay guesses the content type from the body's first character. A body that starts with { or [ is
	 * sent as JSON, the only encoding the inbound base class reads into the handler's request; a handler that reads the
	 * raw body therefore gets a JSON body parsed first, and a body that is not valid JSON ends the call Aborted, as a
	 * live call with that content type would. Any other body (blank, XML, plain text) is sent with no content type, so a
	 * handler that reads the raw body gets it unchanged.
	 *
	 * @param request The request to add the header to
	 */
	private static void addJsonContentType(InboundRequest request)
	{
		if(isJsonShaped(request.body))
		{
			request.headers.put(API_Base.HTTP_CONTENT_TYPE, API_Base.HTTP_ENCODING_JSON);
		}
	}

	/**
	 * @description Reads the parameters a call kept back into a map. The call keeps them as the JSON text of a
	 * DTO_NameValues.
	 *
	 * @param storedParameters The parameters as the call kept them; may be blank
	 * @param parameters The map the parameters are added to
	 *
	 * @return True when the parameters were read, or there were none; false when the text cannot be read back
	 */
	private static Boolean readParameters(String storedParameters, Map<String, String> parameters)
	{
		if(String.isBlank(storedParameters))
		{
			return true;
		}
		try
		{
			DTO_NameValues nameValues = (DTO_NameValues)new DTO_NameValues().deserialize(storedParameters);
			for(String name : nameValues.names)
			{
				parameters.put(name, nameValues.get(name));
			}
			return true;
		}
		catch(Exception readError)
		{
			return false;
		}
	}

	/**
	 * @description Checks whether a text fills its field to the full length, which means it may have been cut when it was
	 * saved.
	 *
	 * @param text The text; may be null
	 * @param fieldLength The number of characters the field holds
	 *
	 * @return True when the text is as long as the field
	 */
	private static Boolean isFieldFull(String text, Integer fieldLength)
	{
		return text != null && text.length() >= fieldLength;
	}

	/**
	 * @description Finds why an issue's request cannot be run again, from the request alone: the issue has no request
	 * (its call is gone and it holds no copy of the request), or the request is not an exact copy of the one that came
	 * in. The other checks (the service's setting, the permanent failure marker) are made by the caller.
	 *
	 * @param request The issue's request from readStoredRequests, or null when it has none
	 *
	 * @return The message that says why, or null when the request can be run again
	 */
	public static String findRequestRefusal(InboundRequest request)
	{
		if(request == null)
		{
			return System.Label.RetryApiIssue_OriginalCallMissing;
		}
		return request.isExactCopy ? null : System.Label.RetryApiIssue_StoredRequestDiffers;
	}

	/**
	 * @description Finds why an issue's request cannot be run again, from what is known without its body: the issue's
	 * call, read without its body and its parameters (see SEL_ApiCall.findRequestWithoutBodyById), and the issue's own fields.
	 * Retry Selected and the bulk retry use it when they schedule the job, so they never hold the bodies of many calls in
	 * memory at once. The job reads each request whole just before it runs it, and checks it again with
	 * findRequestRefusal. The answer refuses only what that check would refuse too:
	 *
	 * 1. The issue has no call and holds no request path in its own fields: it has no request.
	 * 2. The call has an Idempotency-Key but no hash of its body: a call with a key always recorded the hash, so the
	 *    body cannot be proved to be the one received.
	 * 3. The call's address fills its field to the full length, so it may have been cut. A call with no key and no hash
	 *    is refused for this only when the issue holds no request path of its own. When it does, the request the issue
	 *    holds may be run instead (see buildRequestFromIssueOfCall), and only the job can tell.
	 *
	 * A body whose hash differs from the recorded one, parameters that are cut or cannot be read back, or a body of a call
	 * with no key and no hash that fills its field or is kept in a file, can be found only from the request itself, so the
	 * job finds them.
	 *
	 * @param issue The inbound issue
	 * @param originalCall The issue's call, read without its body, or null when the issue has no call or its call is gone
	 *
	 * @return The message that says why, or null when nothing known so far stops the request from running
	 */
	public static String findRefusalWithoutTheBody(ApiIssue__c issue, ApiCall__c originalCall)
	{
		if(originalCall == null)
		{
			return String.isBlank(issue.RequestPath__c) ? System.Label.RetryApiIssue_OriginalCallMissing : null;
		}
		if(isSavedWithoutAHash(originalCall))
		{
			Boolean isAddressCut = isFieldFull(originalCall.URL__c, SEL_ApiCall.URL_LENGTH);
			return isAddressCut && String.isBlank(issue.RequestPath__c) ? System.Label.RetryApiIssue_StoredRequestDiffers : null;
		}
		Boolean isHashMissing = String.isBlank(originalCall.IdempotencyKeyBodyHash__c);
		return isHashMissing || isFieldFull(originalCall.URL__c, SEL_ApiCall.URL_LENGTH) ? System.Label.RetryApiIssue_StoredRequestDiffers : null;
	}

	/**
	 * @description Runs an inbound issue's request again: sends the request (see readStoredRequests) to the service the
	 * issue names. While the request runs, the new call links to the call the request came from (PreviousAttempt__c),
	 * and a failed run writes no new issue, so the issue it was run for stays the one open issue for the request. Its
	 * Idempotency-Key is checked as the user who sent that call, because the request belongs to that user. The caller
	 * has made the checks that decide whether the request may run (see findRequestRefusal).
	 *
	 * @param request The issue's request
	 * @param enableSafeMode When true, all DML is rolled back after execution
	 *
	 * @return DTO_InvocationResult
	 */
	public static DTO_InvocationResult replay(InboundRequest request, Boolean enableSafeMode)
	{
		replayRunning = true;
		replayedCallId = request.originalCallId;
		replayedCallSenderId = request.originalCallSenderId;
		try
		{
			return invoke(request, enableSafeMode);
		}
		finally
		{
			replayRunning = false;
			replayedCallId = null;
			replayedCallSenderId = null;
		}
	}

	/**
	 * @description Replays a failed inbound request from ApiIssue__c: reads the issue and its request (see
	 * readStoredRequests), refuses when the request cannot be run again (see findRequestRefusal), and otherwise runs it
	 * again (see replay). This method does not check the service's API setting or the permanent failure marker of the
	 * issue's call. CTRL_RetryApiIssue makes those checks before it runs a request again; a caller that needs them must
	 * make them first.
	 *
	 * @param failureId The ID of the ApiIssue__c record
	 * @param enableSafeMode When true, replay with rollback
	 *
	 * @return DTO_InvocationResult; when the request was refused, it is not successful and its error text says why
	 */
	public static DTO_InvocationResult replay(Id failureId, Boolean enableSafeMode)
	{
		ApiIssue__c failure = (ApiIssue__c)new SEL_ApiIssue().findById(failureId);

		if(failure == null)
		{
			DTO_InvocationResult errorResult = new DTO_InvocationResult();
			errorResult.statusCode = API_Base.HTTP_NOT_FOUND;
			errorResult.errors.add('Failure record not found: ' + failureId);
			errorResult.errorText = errorResult.errors.iterator().next();
			return errorResult;
		}

		InboundRequest request = readStoredRequests(new List<ApiIssue__c> {failure}, null).get(failure.Id);
		String refusal = findRequestRefusal(request);
		if(refusal != null)
		{
			DTO_InvocationResult refusedResult = new DTO_InvocationResult();
			refusedResult.errors.add(refusal);
			refusedResult.errorText = refusal;
			return refusedResult;
		}
		return replay(request, enableSafeMode);
	}

	/**
	 * @description Checks whether a stored body looks like JSON: after whitespace is removed from both ends, it starts with
	 * { or [. The call and the issue keep no headers, so this first character is the only sign of the body's encoding.
	 *
	 * @param body The stored request body
	 *
	 * @return True when the body starts with { or [, false for a blank body or any other text
	 */
	private static Boolean isJsonShaped(String body)
	{
		String trimmedBody = body?.trim() ?? UTIL_String.EMPTY;
		return trimmedBody.startsWith('{') || trimmedBody.startsWith('[');
	}

	/**
	 * @description Replays a failed inbound request with Safe Mode enabled (see replay(Id, Boolean)). Like that method,
	 * it does not check the service's API setting or the permanent failure marker of the issue's call.
	 * CTRL_RetryApiIssue makes those checks before it runs a request again; a caller that needs them must make them
	 * first.
	 *
	 * @param failureId The ID of the ApiIssue__c record
	 *
	 * @return DTO_InvocationResult
	 */
	public static DTO_InvocationResult replay(Id failureId)
	{
		return replay(failureId, true);
	}

	/**
	 * @description One inbound request to send through the pipeline: what a live request would carry, and, for an issue's
	 * request run again, where it came from and whether it is an exact copy of the request that came in.
	 */
	public inherited sharing class InboundRequest
	{
		/**
		 * @description The path the request is sent to, without a query string.
		 */
		public String path;

		/**
		 * @description The HTTP method, such as POST.
		 */
		public String method;

		/**
		 * @description The request body; may be null.
		 */
		public String body;

		/**
		 * @description The request headers, by name.
		 */
		public Map<String, String> headers = new Map<String, String>();

		/**
		 * @description The query parameters, by name.
		 */
		public Map<String, String> parameters = new Map<String, String>();

		/**
		 * @description The service whose handler gets the request. When it is blank, the request is routed by its path.
		 */
		public String serviceName;

		/**
		 * @description The call the request was read from, or null when it did not come from a call.
		 */
		public Id originalCallId;

		/**
		 * @description The user who sent the call the request was read from (its CreatedById), or null when the request
		 * did not come from a call.
		 */
		public Id originalCallSenderId;

		/**
		 * @description False when the request read from a call may differ from the request that came in (see
		 * readStoredRequests). A request that did not come from a call cannot be checked and counts as exact.
		 */
		public Boolean isExactCopy = true;
	}
}
