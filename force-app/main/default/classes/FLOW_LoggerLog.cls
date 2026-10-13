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
 * @date December 2025, September 2026
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
 * 5. Optionally set Flow Name so the entry is filed under the Flow rather than the step
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_LoggerLog
{
	/**
	 * @description The step an entry is filed under when the Flow Step input is left blank.
	 */
	private static final String DEFAULT_STEP = 'action';

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
	@InvocableMethod(label='Log Flow Event' description='Logs a message within a Flow with correlation support.' category='Logging')
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
					LOG_Engine.CONTEXT_SOURCE => LOG_Engine.FLOW_SOURCE_MARKER
			};

			if(String.isNotBlank(input.flowStep))
			{
				context.put(LOG_Engine.CONTEXT_FLOW_STEP, input.flowStep);
			}

			if(String.isNotBlank(input.flowName))
			{
				context.put(LOG_Engine.CONTEXT_FLOW_NAME, input.flowName);
			}

			if(String.isNotBlank(input.additionalContext))
			{
				context.put('additionalContext', input.additionalContext);
			}

			LOG_Engine.pushOperationContext(LOG_Engine.OperationType.FLOW, context);

			try
			{
				String formattedMessage = '[Flow] ' + input.message;

				LOG_Builder.LogEntry entry = LOG_Builder.build(input.logLevel, formattedMessage).at(buildClassMethod(input));

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
	 * @description Builds the location the entry is written at: the Flow prefix, then the Flow name and the step when a
	 * Flow name is given, and the step alone when it is not. The step is the one the Flow passed, or the default step.
	 *
	 * @param input The inputs the Flow passed for this entry.
	 *
	 * @return The class and method the entry is written at.
	 */
	private static String buildClassMethod(DTO_Request input)
	{
		String step = String.isNotBlank(input.flowStep) ? input.flowStep : DEFAULT_STEP;

		return String.isNotBlank(input.flowName)
				? LOG_Engine.FLOW_SOURCE_PREFIX + input.flowName + LOG_Engine.SOURCE_PREFIX_DELIMITER + step
				: LOG_Engine.FLOW_SOURCE_PREFIX + step;
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
		@InvocableVariable(label='Correlation ID' description='Correlation ID from Start Flow Correlation' required=true)
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
		@InvocableVariable(label='Message' description='Log message' required=true)
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
		@InvocableVariable(label='Log Level' description='Pick Debug, Info, Warning, or Error. Defaults to Info when left empty. Stored values are DEBUG, INFO, WARN, and ERROR.')
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
		@InvocableVariable(label='Flow Step' description='Current step/screen name for context')
		global String flowStep;

		/**
		 * @description The name of the Flow this event belongs to. Filled in, the entry names the Flow as its source and
		 * keeps the step in its location text; left blank, the entry names the step, as before.
		 *
		 * @since 1.8
		 *
		 * @example
		 * ```apex
		 * String value = instance.flowName;
		 * ```
		 */
		@SuppressWarnings('LongLine')
		@InvocableVariable
		(
				label='Flow Name'
				description='The name of the Flow this event belongs to. Filled in, the entry is filed under the Flow and the step stays in the location text; left blank, the entry is filed under the step, as before.'
		)
		global String flowName;

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
		@InvocableVariable(label='Additional Context' description='Additional context to include with the log entry')
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
		@InvocableVariable(label='Record ID' description='Optional record to associate with this log entry')
		global Id recordId;
	}
}