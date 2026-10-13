// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Provides an invocable method for logging messages at specified levels (DEBUG, INFO, WARN, ERROR) from Salesforce flows.
 * Allows control over log levels and additional details such as short messages and associated record IDs.
 * Utilizes the LOG_Builder utility to write messages to the application log.
 *
 * @see FLOW_WriteLog_TEST
 * @see LOG_Builder
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date September 2025, September 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * FLOW_WriteLog.DTO_Request request = new FLOW_WriteLog.DTO_Request();
 * request.logLevel = 'ERROR';
 * request.message = 'Payment processing failed for order';
 * request.shortMessage = 'Payment failure';
 * request.classMethod = 'PaymentFlow.ProcessPayment';
 * request.recordId = orderId;
 * FLOW_WriteLog.writeLog(new List<FLOW_WriteLog.DTO_Request> {request});
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_WriteLog
{
	/**
	 * @description Logs messages at specified levels with additional context, designed for use in Salesforce flows.
	 * Supports multiple messages with customizable log levels, short messages, record IDs, and class/method references for enhanced monitoring and troubleshooting.
	 *
	 * @param dtoRequests The list of log requests, each specifying the level, message, and optional details.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // In a flow, create a DTO_Request variable and pass a list to the action.
	 * FLOW_WriteLog.DTO_Request dtoRequest = new FLOW_WriteLog.DTO_Request();
	 * dtoRequest.classMethod = 'MyFlow.ErrorHandler';
	 * dtoRequest.logLevel = 'ERROR';
	 * dtoRequest.message = 'Detailed error in flow execution';
	 * dtoRequest.recordId = 'a0300000000Nqu7AAC';
	 * dtoRequest.shortMessage = 'Flow error';
	 * FLOW_WriteLog.writeLog(new List<FLOW_WriteLog.DTO_Request>{dtoRequest}); // Logs the message with the specified level and details.
	 * ```
	 */
	@InvocableMethod
	(
			category='Logging'
			label='Write Detailed Log Messages'
			description='Writes provided messages to the Application Log, allows setting of LogLevel and other details'
	)
	global static void writeLog(List<DTO_Request> dtoRequests)
	{
		for(DTO_Request dtoRequest : dtoRequests)
		{
			if(String.isNotBlank(dtoRequest.correlationId))
			{
				LOG_Builder.setCorrelationId(dtoRequest.correlationId);
			}

			String classMethod = String.isBlank(dtoRequest.classMethod) ? FLOW_WriteLog.class.getName() + LOG_Engine.SOURCE_PREFIX_DELIMITER + 'writeLog' : dtoRequest.classMethod;

			LOG_Engine.pushOperationContext(LOG_Engine.OperationType.FLOW, new Map<String, String> {LOG_Engine.CONTEXT_SOURCE => LOG_Engine.FLOW_SOURCE_MARKER});
			try
			{
				LOG_Builder.build(dtoRequest.logLevel, '[Flow] ' + dtoRequest.message)
						.at(classMethod)
						.forRecord(UTIL_SObject.validateId(dtoRequest.recordId))
						.withSummary(dtoRequest.shortMessage)
						.emit();
			}
			finally
			{
				LOG_Engine.popOperationContext();
			}
		}
	}

	/**
	 * @description Data Transfer Object (DTO) for log requests, specifying log level, message details, and context.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Request
	{
		/**
		 * @description The logging level (DEBUG, INFO, WARN, ERROR).
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				label='Log Level'
				description='Pick Debug, Info, Warning, or Error for this log entry. Stored values are DEBUG, INFO, WARN, and ERROR; the field shows the stored value.'
				defaultValue='INFO'
				placeholderText='INFO'
		)
		global String logLevel;

		/**
		 * @description The detailed (long) message to log.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.message;
		 * ```
		 */
		@InvocableVariable(label='Message' description='The detailed message to be logged' required=true)
		global String message;

		/**
		 * @description An optional short summary of the message.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.shortMessage;
		 * ```
		 */
		@InvocableVariable(label='Short Summary' description='A brief summary of the message' required=false)
		global String shortMessage;

		/**
		 * @description An optional record ID associated with the log entry.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * String value = instance.recordId;
		 * ```
		 */
		@InvocableVariable(label='Record Id' description='The Id of the record related to this log' required=false)
		global String recordId;

		/**
		 * @description An optional class and method name for context.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				label='Class.Method'
				description='The class and method name for logging context (defaults to FLOW_WriteLog.writeLog)'
				required=false
				placeholderText='MyFlow.ErrorHandler'
		)
		global String classMethod;

		/**
		 * @description An optional correlation ID for tracing across transactions.
		 *
		 * @since 1.0
		 */
		@InvocableVariable
		(
				label='Correlation Id'
				description='Links this log to related logs across transactions'
				required=false
		)
		global String correlationId;
	}
}