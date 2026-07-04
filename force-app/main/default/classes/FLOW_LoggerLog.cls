// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Logs an event within a Flow with correlation support.
 * Use this to log messages, warnings, or errors during Flow execution.
 *
 * @see FLOW_Logger_TEST
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date December 2025, July 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * In Flow Builder:
 * 1. Add "Log Flow Event" action anywhere in your Flow
 * 2. Pass the Correlation ID from "Start Flow Correlation"
 * 3. Set Message and optionally Log Level (DEBUG, INFO, WARN, ERROR)
 * 4. Optionally set Flow Step to identify where in the Flow the log occurred
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_LoggerLog
{
	/**
	 * @description Logs an event within a Flow.
	 *
	 * @param inputs List of input parameters
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * FLOW_LoggerLog.execute(new List<DTO_Request>());
	 * ```
	 */
	@InvocableMethod(Label='Log Flow Event' Description='Logs a message within a Flow with correlation support.' Category='Logging')
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
					LOG_Engine.CONTEXT_SOURCE => 'Flow'
			};

			if(String.isNotBlank(input.flowStep))
			{
				context.put(LOG_Engine.CONTEXT_FLOW_STEP, input.flowStep);
			}

			if(String.isNotBlank(input.additionalContext))
			{
				context.put('additionalContext', input.additionalContext);
			}

			LOG_Engine.pushOperationContext(LOG_Engine.OperationType.FLOW, context);

			try
			{
				String classMethod = 'Flow/' + (String.isNotBlank(input.flowStep) ? input.flowStep : 'action');
				String formattedMessage = '[Flow] ' + input.message;

				LOG_Builder.LogEntry entry = LOG_Builder.build(input.logLevel, formattedMessage).at(classMethod);

				if(input.recordId != null)
				{
					entry.forRecord(input.recordId);
				}

				entry.emit();
			}
			finally
			{
				LOG_Engine.popOperationContext();
			}
		}
	}

	/**
	 * @description Input parameters for logging a Flow event.
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
		 * @description Log message
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.message;
		 * ```
		 */
		@InvocableVariable(Label='Message' Description='Log message' Required=true)
		global String message;

		/**
		 * @description The log level: Debug, Info, Warning, or Error (stored as DEBUG, INFO, WARN, or ERROR).
		 * Defaults to INFO when left empty.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.logLevel;
		 * ```
		 */
		@InvocableVariable(Label='Log Level' Description='Pick Debug, Info, Warning, or Error. Defaults to Info when left empty. Stored values are DEBUG, INFO, WARN, and ERROR.')
		global String logLevel;

		/**
		 * @description Current step/screen name for context
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.flowStep;
		 * ```
		 */
		@InvocableVariable(Label='Flow Step' Description='Current step/screen name for context')
		global String flowStep;

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

		/**
		 * @description Optional record to associate with this log entry. When set, the
		 * record is linked to the log entry so every log for that record can be filtered
		 * and reported on together. Leave blank when the log is not about a specific record.
		 *
		 * @since 1.2
		 *
		 * @example
		 * ```apex
		 * Id value = instance.recordId;
		 * ```
		 */
		@InvocableVariable(Label='Record ID' Description='Optional record to associate with this log entry')
		global Id recordId;
	}
}