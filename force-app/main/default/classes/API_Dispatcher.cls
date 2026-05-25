// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Factory class for orchestrating the execution of web service handlers.
 * Manages the lifecycle of API calls, including handler initiation, error handling, and change commitment.
 * Supports both single and batch processing of web service requests.
 *
 * @see API_Dispatcher_TEST
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
	 * @description Hydrates logger context from API calls for cross-transaction correlation.
	 * Uses the first API call's context, then starts a new correlation for this batch if needed.
	 *
	 * @param apiCalls The API calls being processed
	 */
	private static void hydrateLoggerContext(List<ApiCall__c> apiCalls)
	{
		if(apiCalls == null || apiCalls.isEmpty())
		{
			return;
		}

		// Try to hydrate from first API call with context
		for(ApiCall__c apiCall : apiCalls)
		{
			if(String.isNotBlank(apiCall.LoggerContext__c))
			{
				LOG_Builder.hydrateContext(apiCall.LoggerContext__c);
				return;
			}
		}

		// No context found in any API call - start fresh correlation for this batch
		// This handles legacy API calls created before the auto-correlation enhancement
		if(String.isBlank(LOG_Builder.correlationId))
		{
			LOG_Builder.startCorrelation();
		}
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
	@SuppressWarnings('PMD.CyclomaticComplexity')
	global static List<API_Base> execute(List<ApiCall__c> apiCalls)
	{
		List<API_Base> apiHandlers = new List<API_Base>();
		List<API_Base> handlersToCommit = new List<API_Base>();
		DML_Transaction unitOfWork = new DML_Transaction();
		unitOfWork.setAccessLevel(AccessLevel.SYSTEM_MODE);
		unitOfWork.setAllowPartial(true);

		hydrateLoggerContext(apiCalls);
		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.API_BATCH, new Map<String, String> {LOG_Engine.CONTEXT_BATCH_SIZE => String.valueOf(apiCalls.size())});
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

				try
				{
					apiHandler.process(apiCall);
					if(simulateProcessException)
					{
						throw new UTIL_Exceptions.IllegalStateException('Simulated process exception');
					}
					handlersToCommit.add(apiHandler);
				}
				catch(Exception error)
				{
					handleError(apiHandler, error, unitOfWork);
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
				try
				{
					handlerToCommit.commitWork();
				}
				catch(Exception error)
				{
					handleError(handlerToCommit, error, unitOfWork);
				}
			}

			finalizeHandlers(apiHandlers, unitOfWork);
			persistUnitOfWork(unitOfWork);
		}
		finally
		{
			LOG_Engine.popOperationContext();
			LOG_Builder.resumeSaving();
		}

		return apiHandlers;
	}

	/**
	 * @description Records timing metrics for all processed handlers and registers their
	 * ApiCall__c records for persistence.
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
				unitOfWork.doSave(handler.apiCall);
			}
		}
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
	 * @description Aborts an API call that could not be resolved to a handler class.
	 * Logs the error, marks the call as aborted, and writes an error response.
	 *
	 * @param apiCall The API call record that failed resolution.
	 * @param error The exception thrown during handler resolution.
	 * @param unitOfWork The unit of work for persistence.
	 */
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
	 * @description Handles errors encountered during API call processing or commit.
	 * Delegates error recording to the handler, resets retry state, and registers
	 * failure artifacts (ApiIssue__c and ContentVersion files) in the shared unit of work.
	 *
	 * @param handler The `API_Base` handler processing the request.
	 * @param error The exception encountered.
	 * @param unitOfWork The unit of work for updating API call records.
	 */
	private static void handleError(API_Base handler, Exception error, DML_Transaction unitOfWork)
	{
		handler.applyLoggingContext();
		handler.handleError(error);
		handler.setApiCallDetails();

		ApiCall__c handlerApiCall = handler.apiCall;
		handlerApiCall.NextRetry__c = null;
		handlerApiCall.Retries__c = 0;

		LOG_Builder.build().error(error).at(handlerApiCall.ServiceName__c).emit();
		registerFailureArtifacts(handler, unitOfWork);
	}

	/**
	 * @description Registers failure-related records (ApiIssue__c and ContentVersion attachments)
	 * in the shared unit of work for later persistence.
	 *
	 * @param handler The handler that produced the failure.
	 * @param unitOfWork The unit of work for registering DML operations.
	 */
	private static void registerFailureArtifacts(API_Base handler, DML_Transaction unitOfWork)
	{
		ApiIssue__c failureRecord = handler.createFailureRecord();
		if(failureRecord != null)
		{
			unitOfWork.doSave(failureRecord);
		}

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