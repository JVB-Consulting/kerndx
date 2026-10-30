// SPDX-License-Identifier: Apache-2.0
/**
 * @description Factory class for orchestrating the execution of web service handlers.
 * Manages the lifecycle of API calls, including handler initiation, error handling, and change commitment.
 * Supports both single and batch processing of web service requests.
 *
 * @see API_Dispatcher_TEST
 * @see API_InboundIssue_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, October 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * // Process an inbound REST service
 * API_Dispatcher.processInboundService(API_UpdateInvoice.class.getName());
 * // Execute an outbound API call
 * ApiCall__c apiCall = TST_Factory.newOutboundApiCall('API_SendEmail', recordId, parameters);
 * API_Base handler = API_Dispatcher.execute(apiCall);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
global inherited sharing class API_Dispatcher
{
	/**
	 * @description Flag to simulate API call commit failure for testing.
	 */
	@TestVisible
	private static Boolean simulateApiCallCommitFailure = false;

	/**
	 * @description Flag to simulate an exception after process completes, for testing error handling with pre-inserted API calls.
	 */
	@TestVisible
	private static Boolean simulateProcessException = false;

	/**
	 * @description Flag to simulate an unexpected exception during final commit work, for testing error logging.
	 */
	@TestVisible
	private static Boolean simulateCommitWorkException = false;

	/**
	 * @description Flag to simulate callout budget exhaustion for testing.
	 */
	@TestVisible
	private static Boolean simulateCalloutBudgetExhausted = false;

	/**
	 * @description What separates one service name from the next in the batch context's list of names.
	 */
	private static final String SERVICE_NAME_SEPARATOR = ', ';

	/**
	 * @description Returns whether the callout governor limit has been reached.
	 * Called by UTIL_HttpClient (retry guard) and CTRL_RetryApiIssue (bulk replay guard).
	 *
	 * @return True when no further callouts can be made in this transaction
	 */
	public static Boolean isCalloutBudgetExhausted()
	{
		return simulateCalloutBudgetExhausted || UTIL_Limits.callouts().isExhausted();
	}

	/**
	 * @description Hydrates the logger context from the API calls, so a run of stored calls names the transaction that
	 * built them as its parent. The first call that carries a context document decides. A document this very request
	 * wrote (a call built and dispatched in one transaction) describes the live context itself, so it is left alone and
	 * the live context stands: restoring it would only make the transaction its own parent. With no document in any
	 * call, a correlation is started for the batch when there is none.
	 *
	 * @param apiCalls The API calls being processed
	 */
	private static void hydrateLoggerContext(List<ApiCall__c> apiCalls)
	{
		if(apiCalls == null || apiCalls.isEmpty())
		{
			return;
		}

		for(ApiCall__c apiCall : apiCalls)
		{
			if(String.isNotBlank(apiCall.LoggerContext__c))
			{
				if(!LOG_Engine.wasContextWrittenByCurrentRequest(apiCall.LoggerContext__c))
				{
					LOG_Builder.hydrateContext(apiCall.LoggerContext__c);
				}
				return;
			}
		}

		// No document in any call: records from before contexts were stored. Give the batch a correlation when there is none.
		if(String.isBlank(LOG_Builder.correlationId))
		{
			LOG_Builder.startCorrelation();
		}
	}

	/**
	 * @description Builds the details the batch's `API_BATCH` logging context carries: how many calls the batch holds and
	 * the names of the services they call, each name once, in alphabetical order. Every line logged while the batch runs
	 * carries them, including lines from the batch-wide save that follows the handlers and belongs to no single call.
	 * Inside a call, that call's own context names the service instead.
	 *
	 * @param apiCalls The API calls the batch processes.
	 *
	 * @return The batch size, and the service names when at least one call names a service.
	 */
	private static Map<String, String> buildBatchContext(List<ApiCall__c> apiCalls)
	{
		Map<String, String> batchContext = new Map<String, String> {LOG_Engine.CONTEXT_BATCH_SIZE => String.valueOf(apiCalls.size())};
		Set<String> serviceNames = new Set<String>();
		for(ApiCall__c apiCall : apiCalls)
		{
			if(String.isNotBlank(apiCall.ServiceName__c))
			{
				serviceNames.add(apiCall.ServiceName__c);
			}
		}
		if(!serviceNames.isEmpty())
		{
			batchContext.put(LOG_Engine.CONTEXT_SERVICE_NAME, UTIL_String.joinSorted(serviceNames, SERVICE_NAME_SEPARATOR));
		}
		return batchContext;
	}

	/**
	 * @description Executes a single API callout for the provided API call record.
	 *
	 * @param apiCall A `ApiCall__c` record containing details of the API call to execute.
	 *
	 * @return The `API_Base` handler that processed the request, or `null` if no handler was executed.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiCall__c apiCall = TST_Factory.newInboundApiCall('MyServiceHandler');
	 * API_Base handler = API_Dispatcher.execute(apiCall);
	 * ```
	 */
	global static API_Base execute(ApiCall__c apiCall)
	{
		List<API_Base> handlers = execute(new List<ApiCall__c> {apiCall});
		return handlers.isEmpty() ? null : handlers.iterator().next();
	}

	/**
	 * @description Processes a list of API callout requests by executing multiple web service handlers.
	 * Manages batch processing, commits successful transactions, and logs failures for retries.
	 *
	 * @param apiCalls A list of `ApiCall__c` records representing API calls to process.
	 *
	 * @return A list of `API_Base` handlers that successfully processed the requests.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ApiCall__c> apiCalls = [SELECT Id, Service__c FROM ApiCall__c WHERE Status__c = 'Pending'];
	 * List<API_Base> handlers = API_Dispatcher.execute(apiCalls);
	 * ```
	 */
	global static List<API_Base> execute(List<ApiCall__c> apiCalls)
	{
		List<API_Base> apiHandlers = new List<API_Base>();
		List<API_Base> handlersToCommit = new List<API_Base>();
		DML_Transaction unitOfWork = new DML_Transaction();
		unitOfWork.setAccessLevel(AccessLevel.SYSTEM_MODE);
		unitOfWork.setAllowPartial(true);

		hydrateLoggerContext(apiCalls);
		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.API_BATCH, buildBatchContext(apiCalls));
		LOG_Builder.suspendSaving();

		try
		{
			Integer skippedCount = 0;

			for(Integer index = 0; index < apiCalls.size(); index++)
			{
				ApiCall__c apiCall = apiCalls[index];

				if(index > 0 && isCalloutBudgetExhausted())
				{
					skippedCount++;
					continue;
				}

				API_Base apiHandler;
				try
				{
					apiHandler = getHandler(apiCall.ServiceName__c);
					apiHandlers.add(apiHandler);
				}
				catch(Exception error)
				{
					abortUnresolvableCall(apiCall, error, unitOfWork);
					continue;
				}

				if(processWithinCallContext(apiHandler, apiCall, unitOfWork))
				{
					handlersToCommit.add(apiHandler);
				}
			}

			if(skippedCount > 0)
			{
				LOG_Builder.build()
						.warn(skippedCount + ' API call(s) deferred — callout budget exhausted')
						.emitAt(API_Dispatcher.class.getName() + '/execute');
			}

			for(API_Base handlerToCommit : handlersToCommit)
			{
				commitWithinCallContext(handlerToCommit, unitOfWork);
			}

			finalizeHandlers(apiHandlers, unitOfWork);
			persistUnitOfWork(unitOfWork);
		}
		finally
		{
			clearLoggingContexts(apiHandlers);
			LOG_Engine.popOperationContext();
			LOG_Builder.resumeSaving();
		}

		return apiHandlers;
	}

	/**
	 * @description Removes each handler's call details from the logging engine, so lines logged once the handlers are
	 * done carry the batch's own context only.
	 *
	 * @param handlers The handlers the batch ran.
	 */
	private static void clearLoggingContexts(List<API_Base> handlers)
	{
		for(API_Base handler : handlers)
		{
			handler.clearLoggingContext();
		}
	}

	/**
	 * @description Records timing metrics for all processed handlers and registers their
	 * ApiCall__c records for persistence. A call record the handler's own commit already saved is registered with only
	 * the fields that changed since that commit (see API_Base.buildApiCallChangesToSave), so the payloads that commit
	 * saved, and masked, are not sent again.
	 *
	 * @param handlers The list of API handlers that were processed.
	 * @param unitOfWork The shared unit of work for final persistence.
	 */
	private static void finalizeHandlers(List<API_Base> handlers, DML_Transaction unitOfWork)
	{
		for(API_Base handler : handlers)
		{
			handler.applyLoggingContext();
			recordTimingMetrics(handler);

			if(!handler.skipPersistence && !API_Base.isSafeModeActive())
			{
				unitOfWork.doSave(handler.buildApiCallChangesToSave());
			}
		}

		clearLoggingContexts(handlers);
	}

	/**
	 * @description Calculates and persists callout, commit, handler, and total duration
	 * on the ApiCall__c record for the given handler.
	 *
	 * @param handler The handler whose timing metrics should be recorded.
	 */
	private static void recordTimingMetrics(API_Base handler)
	{
		ApiCall__c apiCall = handler.apiCall;
		Long calloutTime = handler.calloutProcessingTime.getTime();

		apiCall.CalloutDurationMs__c = simulateApiCallCommitFailure
				? UTIL_Random.randomIntegerOfLength(SEL_ApiCall.CALL_OUT_TIME_TAKEN_LENGTH + 1)
				: calloutTime;
		apiCall.CommitDurationMs__c = handler.commitProcessingTime.getTime();
		apiCall.HandlerDurationMs__c = handler.serviceProcessingTime.getTime() - calloutTime;
		handler.fullProcessingTime.stop();
		apiCall.TotalDurationMs__c = handler.fullProcessingTime.getTime();
	}

	/**
	 * @description Commits the shared unit of work unless Safe Mode is active.
	 *
	 * @param unitOfWork The unit of work containing all pending DML operations.
	 */
	private static void persistUnitOfWork(DML_Transaction unitOfWork)
	{
		if(API_Base.isSafeModeActive())
		{
			return;
		}
		try
		{
			if(simulateCommitWorkException)
			{
				throw new UTIL_Exceptions.IllegalStateException('Simulated commit work exception');
			}
			unitOfWork.commitWork(false);
		}
		catch(Exception error)
		{
			LOG_Builder.build().error(error).at(API_Dispatcher.class.getName() + '/execute').emit();
		}
	}

	/**
	 * @description Processes one API call with the handler's `API_CALL` logging context on the stack, popping it in a
	 * `finally` so the context never outlives the run. Errors are handled inside that context, so the error entry
	 * carries the handler's service name and HTTP method.
	 *
	 * @param handler The handler that processes the call.
	 * @param apiCall The API call record to process.
	 * @param unitOfWork The shared unit of work for failure artifacts.
	 *
	 * @return True when the call processed without error and is ready to commit.
	 */
	private static Boolean processWithinCallContext(API_Base handler, ApiCall__c apiCall, DML_Transaction unitOfWork)
	{
		Boolean isProcessed = false;
		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.API_CALL, handler.buildCallContext());
		try
		{
			handler.process(apiCall);
			if(simulateProcessException)
			{
				throw new UTIL_Exceptions.IllegalStateException('Simulated process exception');
			}
			isProcessed = true;
		}
		catch(Exception error)
		{
			handleError(handler, apiCall, error, unitOfWork);
		}
		finally
		{
			LOG_Engine.popOperationContext();
		}
		return isProcessed;
	}

	/**
	 * @description Commits one handler's work with that handler's `API_CALL` logging context on the stack, popping it
	 * in a `finally` so each commit runs under its own handler's context.
	 *
	 * @param handler The handler whose work is committed.
	 * @param unitOfWork The shared unit of work for failure artifacts.
	 */
	private static void commitWithinCallContext(API_Base handler, DML_Transaction unitOfWork)
	{
		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.API_CALL, handler.buildCallContext());
		try
		{
			handler.commitWork();
		}
		catch(Exception error)
		{
			handleError(handler, handler.apiCall, error, unitOfWork);
		}
		finally
		{
			LOG_Engine.popOperationContext();
		}
	}

	/**
	 * @description Aborts an API call that could not be resolved to a handler class.
	 * Logs the error, marks the call as aborted, and writes an error response.
	 *
	 * @param apiCall The API call record that failed resolution.
	 * @param error The exception thrown during handler resolution.
	 * @param unitOfWork The unit of work for persistence.
	 */
	@SuppressWarnings('PMD.KernNoRawRestContext')
	private static void abortUnresolvableCall(ApiCall__c apiCall, Exception error, DML_Transaction unitOfWork)
	{
		LOG_Engine.setWebserviceContext(null, apiCall.ServiceName__c, 'Unknown-Endpoint', 'Unknown-Method');
		LOG_Builder.build().error(error).at(apiCall.ServiceName__c).emit();
		LOG_Engine.clearWebserviceContext(null);

		apiCall.Request__c = UTIL_String.abbreviate(apiCall.Request__c, ApiCall__c.Request__c);
		apiCall.Status__c = SEL_ApiCall.STATUS_ABORTED;
		apiCall.ErrorMessages__c = error.getMessage();
		unitOfWork.doSave(apiCall);

		RestContext.response = RestContext.response ?? new RestResponse();
		RestContext.response.responseBody = Blob.valueOf(apiCall.ErrorMessages__c);
		RestContext.response.statusCode = API_Base.HTTP_INTERNAL_SERVER_ERROR;
	}

	/**
	 * @description Retrieves an API handler instance based on the provided class name.
	 *
	 * @param handlerName The class name of the handler.
	 *
	 * @return An instance of the `API_Base` handler.
	 */
	private static API_Base getHandler(String handlerName)
	{
		return (API_Base)UTIL_System.getTypeForClassName(handlerName, API_Base.class).newInstance();
	}

	/**
	 * @description Handles errors met while an API call is processed or committed. If the handler failed before it
	 * received the call record, it is given the record first. The exception is kept for the retry decision. Then the
	 * handler's own error handling runs inside a guard: the logging context, handleError, setApiCallDetails (which
	 * decides the retry and writes it to the call) and the failure records. If any of those throws, that one call ends
	 * Failed with both messages and no retry time, and the batch's other calls are saved as they would have been. An
	 * inbound call then still gets its key, the hash of its body, its permanent failure marker and its issue, all without
	 * the handler's code (see recordInboundCallWithoutTheHandler). Its issue is left out when the issue step already ran
	 * before the throw, whatever that step decided, so a call never gets two issues and never gets one the step refused.
	 * The retry fields that setApiCallDetails writes are kept: nothing here resets the next retry time or the retry count.
	 *
	 * @param handler The `API_Base` handler processing the request.
	 * @param apiCall The API call record being processed.
	 * @param error The exception encountered.
	 * @param unitOfWork The unit of work for updating API call records.
	 */
	private static void handleError(API_Base handler, ApiCall__c apiCall, Exception error, DML_Transaction unitOfWork)
	{
		handler.assignApiCallWhenMissing(apiCall);
		handler.lastFailure = error;
		Boolean hasFailureRecordStepRun = false;
		try
		{
			handler.applyLoggingContext();
			handler.handleError(error);
			handler.setApiCallDetails();
			registerFailureRecord(handler.createFailureRecord(), handler.apiCall, unitOfWork);
			hasFailureRecordStepRun = true;
			registerRelatedFiles(handler, unitOfWork);
			LOG_Builder.build().error(error).at(handler.apiCall.ServiceName__c).emit();
		}
		catch(Exception handlingFailure)
		{
			failWithoutTheHandler(handler, error, handlingFailure);
			recordInboundCallWithoutTheHandler(handler, unitOfWork, hasFailureRecordStepRun);
		}
		finally
		{
			handler.clearLoggingContext();
		}
	}

	/**
	 * @description Ends one call Failed when the handler's own error handling threw (a handleError override, a retry
	 * strategy, a hook or a failure-record override that throws): the row keeps both messages and no time, both failures
	 * are logged once each (the error log inside the guard runs last, so a throw before it never doubles the entry), and
	 * the batch's other calls are saved as they would have been. An inbound handler writes the REST response inside its
	 * own handleError, which is the code that threw, so for an inbound call the response is written here: status 500
	 * with the row's error text as the body, so the caller never reads a failed request as a success. The details and the
	 * issue of an inbound call are recorded after this method (see recordInboundCallWithoutTheHandler). An outbound call
	 * gets no issue here, because building one runs the same handler code that just threw; the row's error text is the
	 * record of this failure.
	 *
	 * @param handler The handler whose error handling threw.
	 * @param error The exception the call failed with.
	 * @param handlingFailure The exception the handler's error handling threw.
	 */
	@SuppressWarnings('PMD.KernNoRawRestContext')
	private static void failWithoutTheHandler(API_Base handler, Exception error, Exception handlingFailure)
	{
		ApiCall__c handlerApiCall = handler.apiCall;
		handlerApiCall.Status__c = SEL_ApiCall.STATUS_FAILED;
		handlerApiCall.NextRetry__c = null;
		handlerApiCall.ErrorMessages__c = UTIL_String.abbreviate(error.getMessage() + UTIL_String.SPACE + handlingFailure.getMessage(), ApiCall__c.ErrorMessages__c);
		LOG_Builder.build().error(error).at(handlerApiCall.ServiceName__c).emit();
		LOG_Builder.build().error(handlingFailure).at(handlerApiCall.ServiceName__c).emit();

		if(handler instanceof API_Inbound)
		{
			RestContext.response = RestContext.response ?? new RestResponse();
			RestContext.response.responseBody = Blob.valueOf(handlerApiCall.ErrorMessages__c);
			RestContext.response.statusCode = API_Base.HTTP_INTERNAL_SERVER_ERROR;
		}
	}

	/**
	 * @description Records an inbound call whose handler's error handling threw. First the call gets its key, the hash
	 * of its body and its permanent failure marker (see API_Inbound.recordRequestDetailsWithoutTheHandler), so a call
	 * like this is never run again after a permanent failure and can still prove its stored body is an exact copy. Then,
	 * when the issue step did not run before the throw, the issue is registered. It is built by
	 * API_Inbound.buildInboundFailureRecord, which keeps the same rules as the handler: no issue when Log Issues is off,
	 * none for a key reused with another body, and none when an earlier call with the same key already holds an open
	 * issue. Both methods run none of the handler's own code. The first only reads fields; the second makes at most one
	 * read, which checks the query limit first and catches its own errors. So they cannot throw the way the handler did.
	 * An outbound call gets nothing here.
	 *
	 * @param handler The handler whose error handling threw.
	 * @param unitOfWork The unit of work for registering DML operations.
	 * @param hasFailureRecordStepRun True when the issue step ran before the throw, whether or not it gave an issue.
	 */
	private static void recordInboundCallWithoutTheHandler(API_Base handler, DML_Transaction unitOfWork, Boolean hasFailureRecordStepRun)
	{
		if(handler instanceof API_Inbound)
		{
			API_Inbound inboundHandler = (API_Inbound)handler;
			inboundHandler.recordRequestDetailsWithoutTheHandler();
			if(!hasFailureRecordStepRun)
			{
				registerFailureRecord(inboundHandler.buildInboundFailureRecord(), handler.apiCall, unitOfWork);
			}
		}
	}

	/**
	 * @description Registers an issue record in the shared unit of work. When the call is not saved yet, the issue is
	 * registered with the call as its parent, so the save fills in the issue's link to the call once the call has an Id.
	 * When the call is already saved, the issue is registered as it is: it already holds the call's Id.
	 *
	 * @param failureRecord The issue to register; may be null, and then nothing is registered.
	 * @param handlerApiCall The call the issue belongs to.
	 * @param unitOfWork The unit of work for registering DML operations.
	 */
	private static void registerFailureRecord(ApiIssue__c failureRecord, ApiCall__c handlerApiCall, DML_Transaction unitOfWork)
	{
		if(failureRecord == null)
		{
			return;
		}

		if(String.isBlank(handlerApiCall.Id))
		{
			unitOfWork.doInsert(failureRecord, ApiIssue__c.ApiCall__c, handlerApiCall);
		}
		else
		{
			unitOfWork.doSave(failureRecord);
		}
	}

	/**
	 * @description Registers the files for call data too long for its fields (ContentVersion attachments) in the shared
	 * unit of work for later persistence. When the call is not saved yet, each file is registered with the call as its
	 * parent.
	 *
	 * @param handler The handler that produced the failure.
	 * @param unitOfWork The unit of work for registering DML operations.
	 */
	private static void registerRelatedFiles(API_Base handler, DML_Transaction unitOfWork)
	{
		ApiCall__c handlerApiCall = handler.apiCall;
		for(ContentVersion version : handler.createRelatedContentVersions())
		{
			if(String.isBlank(handlerApiCall.Id))
			{
				unitOfWork.doInsert(version, ContentVersion.FirstPublishLocationId, handlerApiCall);
			}
			else
			{
				version.FirstPublishLocationId = handlerApiCall.Id;
				unitOfWork.doInsert(version);
			}
		}
	}

	/**
	 * @description Processes a single inbound web service request by executing the specified handler.
	 *
	 * @param serviceName The name of the web service handler class to execute.
	 *
	 * @return The `API_Base` handler that processed the request, or `null` if no handler was executed.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * API_Base handler = API_Dispatcher.processInboundService('MyServiceHandler');
	 * ```
	 */
	global static API_Base processInboundService(String serviceName)
	{
		return execute(TST_Factory.newInboundApiCall(serviceName));
	}

	/**
	 * @description Routes incoming REST request to appropriate handler.
	 * Uses "Best Match" algorithm: longest path prefix wins.
	 * Handles namespace prefixes for managed package deployments.
	 *
	 * @return The handler that processed the request, or null if no route found
	 */
	@SuppressWarnings('PMD.KernNoRawRestContext')
	public static API_Base routeRequest()
	{
		RestRequest request = RestContext.request;
		RestResponse response = RestContext.response;

		if(request == null)
		{
			return null;
		}

		ApiSetting__mdt route = findBestRoute(request.requestURI);

		if(route == null)
		{
			response.statusCode = API_Base.HTTP_NOT_FOUND;
			response.responseBody = Blob.valueOf('{"error":"NOT_FOUND","message":"No route configured for path: ' + request.requestURI + '"}');
			return null;
		}

		String handlerClassName = buildQualifiedClassName(route);

		return processInboundService(handlerClassName);
	}

	/**
	 * @description Builds the fully qualified class name including namespace prefix.
	 *
	 * @param setting The ApiSetting__mdt record
	 *
	 * @return Fully qualified class name (e.g., "MyNamespace.API_Handler" or "API_Handler")
	 */
	@TestVisible
	private static String buildQualifiedClassName(ApiSetting__mdt setting)
	{
		return buildQualifiedClassName(setting.ClassName__c, setting.NamespacePrefix);
	}

	/**
	 * @description Builds the fully qualified class name from a class name and optional namespace prefix.
	 *
	 * @param className The class name (may already include namespace)
	 * @param namespacePrefix The namespace prefix to prepend (may be blank)
	 *
	 * @return Fully qualified class name (e.g., "MyNamespace.API_Handler" or "API_Handler")
	 */
	@TestVisible
	private static String buildQualifiedClassName(String className, String namespacePrefix)
	{
		if(className.contains('.'))
		{
			return className;
		}

		if(String.isNotBlank(namespacePrefix))
		{
			return namespacePrefix + '.' + className;
		}

		return className;
	}

	/**
	 * @description Finds the best matching route for a request path.
	 * Uses "longest path prefix wins" algorithm for wildcard matching.
	 *
	 * @param requestPath The incoming request URI
	 *
	 * @return Best matching ApiSetting__mdt or null if no match
	 */
	@TestVisible
	private static ApiSetting__mdt findBestRoute(String requestPath)
	{
		List<ApiSetting__mdt> candidates = new SEL_ApiSetting().findActiveInboundRoutes();

		ApiSetting__mdt bestMatch = null;
		Integer bestMatchLength = -1;

		for(ApiSetting__mdt setting : candidates)
		{
			if(API_MockMatcher.matchesPath(setting.EndpointPath__c, requestPath))
			{
				Integer pathLength = setting.EndpointPath__c?.length() ?? 0;
				if(pathLength > bestMatchLength)
				{
					bestMatch = setting;
					bestMatchLength = pathLength;
				}
			}
		}

		return bestMatch;
	}
}