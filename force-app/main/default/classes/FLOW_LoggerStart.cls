// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Starts a logging correlation for a Flow.
 * Use this at the beginning of a Flow to generate a correlation ID
 * that links all subsequent log entries.
 *
 * @see FLOW_Logger_TEST
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date December 2025, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * In Flow Builder:
 * 1. Add "Start Flow Correlation" action at the beginning
 * 2. Set Flow Name (e.g., "Create Account")
 * 3. Optionally set Record ID for context
 * 4. Store the returned Correlation ID in a variable
 * 5. Pass this ID to subsequent "Log Flow Event" and "End Flow Correlation" actions
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_LoggerStart
{

	/**
	 * @description Starts a correlation context for Flow logging.
	 *
	 * @param dtoRequests List of input parameters
	 *
	 * @return List of outputs containing correlation IDs
	 *
	 * @since 1.0
	 */
	@InvocableMethod
	(
			Label='Start Flow Correlation'
			Description='Starts logging correlation for a Flow. Returns a correlation ID to pass to other logging actions.'
			Category='Logging'
	)
	global static List<DTO_Response> execute(List<DTO_Request> dtoRequests)
	{
		TRG_Base.validateSingleRequest(dtoRequests.size(), FLOW_LoggerStart.class.getName());

		List<DTO_Response> outputs = new List<DTO_Response>();

		for(DTO_Request dtoRequest : dtoRequests)
		{
			DTO_Response output = new DTO_Response();
			output.correlationId = LOG_Engine.startCorrelation();

			Map<String, String> context = new Map<String, String>
			{
					LOG_Engine.CONTEXT_FLOW_NAME => dtoRequest.flowName,
					LOG_Engine.CONTEXT_SOURCE => 'Flow'
			};

			if(String.isNotBlank(dtoRequest.recordId))
			{
				context.put(LOG_Engine.CONTEXT_RECORD_ID, dtoRequest.recordId);
			}

			if(String.isNotBlank(dtoRequest.additionalContext))
			{
				context.put('additionalContext', dtoRequest.additionalContext);
			}

			LOG_Engine.pushOperationContext(LOG_Engine.OperationType.FLOW, context);

			try
			{
				LOG_Builder.build().info('[Flow] ' + dtoRequest.flowName + ' started').at('Flow/' + dtoRequest.flowName).emit();
			}
			finally
			{
				LOG_Engine.popOperationContext();
			}

			outputs.add(output);
		}

		return outputs;
	}

	/**
	 * @description Input parameters for starting Flow correlation.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Request
	{
		/**
		 * @description Name of the Flow for logging
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.flowName;
		 * ```
		 */
		@InvocableVariable(Label='Flow Name' Description='Name of the Flow for logging' Required=true)
		global String flowName;

		/**
		 * @description Optional record ID for context
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.recordId;
		 * ```
		 */
		@InvocableVariable(Label='Record ID' Description='Optional record ID for context')
		global String recordId;

		/**
		 * @description Additional context to include with the log entry
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.additionalContext;
		 * ```
		 */
		@InvocableVariable(Label='Additional Context' Description='Additional context to include with the log entry')
		global String additionalContext;
	}

	/**
	 * @description Output containing the generated correlation ID.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Response
	{
		/**
		 * @description Generated correlation ID to pass to subsequent actions
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.correlationId;
		 * ```
		 */
		@InvocableVariable(Label='Correlation ID' Description='Generated correlation ID to pass to subsequent actions')
		global String correlationId;
	}
}