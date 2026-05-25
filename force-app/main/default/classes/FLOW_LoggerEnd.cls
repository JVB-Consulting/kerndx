// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Ends a logging correlation for a Flow.
 * Use this at the end of a Flow to log completion status.
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
 * 1. Add "End Flow Correlation" action at the end of your Flow
 * 2. Pass the Correlation ID from "Start Flow Correlation"
 * 3. Set Flow Name and Success status
 * 4. Optionally set Error Message if the Flow failed
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_LoggerEnd
{
	/**
	 * @description Ends a correlation context for Flow logging.
	 *
	 * @param inputs List of input parameters
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * FLOW_LoggerEnd.execute(new List<DTO_Request>());
	 * ```
	 */
	@InvocableMethod(Label='End Flow Correlation' Description='Ends logging correlation for a Flow and logs completion status.' Category='Logging')
	global static void execute(List<DTO_Request> inputs)
	{
		for(DTO_Request input : inputs)
		{
			if(String.isNotBlank(input.correlationId))
			{
				LOG_Engine.setCorrelationId(input.correlationId);
			}

			Map<String, String> context = new Map<String, String>
			{
					LOG_Engine.CONTEXT_FLOW_NAME => input.flowName,
					LOG_Engine.CONTEXT_FLOW_STATUS => input.success == true ? 'SUCCESS' : 'FAILED',
					LOG_Engine.CONTEXT_SOURCE => 'Flow'
			};

			LOG_Engine.pushOperationContext(LOG_Engine.OperationType.FLOW, context);

			try
			{
				String classMethod = 'Flow/' + input.flowName;

				if(input.success == true)
				{
					LOG_Builder.build().info('[Flow] ' + input.flowName + ' completed successfully').at(classMethod).emit();
				}
				else
				{
					String message = '[Flow] ' + input.flowName + ' failed';
					if(String.isNotBlank(input.errorMessage))
					{
						message += ': ' + input.errorMessage;
					}
					LOG_Builder.build().warn(message).at(classMethod).emit();
				}
			}
			finally
			{
				LOG_Engine.popOperationContext();
			}
		}
	}

	/**
	 * @description Input parameters for ending Flow correlation.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Request
	{
		/**
		 * @description Correlation ID from Start Flow Correlation
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.correlationId;
		 * ```
		 */
		@InvocableVariable(Label='Correlation ID' Description='Correlation ID from Start Flow Correlation' Required=true)
		global String correlationId;

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
		 * @description Whether the Flow completed successfully
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean value = instance.success;
		 * ```
		 */
		@InvocableVariable(Label='Success' Description='Whether the Flow completed successfully')
		global Boolean success;

		/**
		 * @description Error message if Flow failed
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.errorMessage;
		 * ```
		 */
		@InvocableVariable(Label='Error Message' Description='Error message if Flow failed')
		global String errorMessage;
	}
}