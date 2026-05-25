// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Controller for receiving and persisting logs from LWC components.
 * Supports correlation IDs to link LWC logs with server-side operations.
 *
 * @see CTRL_Logger_TEST
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date December 2025, May 2026
 *
 * @example
 * ```javascript
 * // From JavaScript (LWC)
 * import persistLogs from '@salesforce/apex/CTRL_Logger.persistLogs';
 * const logs = [
 *     {timestamp: new Date(), level: 'INFO', message: 'User clicked save', correlationId: 'abc-123'}
 * ];
 * await persistLogs({entries: logs});
 * ```
 */
public inherited sharing class CTRL_Logger
{
	/**
	 * @description Persists LWC logs to the logging framework. Accepts a JSON string because LWC
	 * does not support inner class or Map deserialization for @AuraEnabled parameters.
	 *
	 * @param entriesJson JSON-serialized List of DTO_ClientLogEntry objects to persist.
	 */
	@AuraEnabled
	public static void persistLogs(String entriesJson)
	{
		List<DTO_ClientLogEntry> dtoClientLogEntries = String.isNotBlank(entriesJson)
				? (List<DTO_ClientLogEntry>)JSON.deserialize(entriesJson, List<DTO_ClientLogEntry>.class)
				: null;

		if(dtoClientLogEntries?.isEmpty() == false)
		{
			// Use the correlation ID from the first log dtoClientLogEntry
			String clientCorrelationId = dtoClientLogEntries.iterator().next().correlationId;
			if(String.isNotBlank(clientCorrelationId))
			{
				LOG_Engine.setCorrelationId(clientCorrelationId);
			}

			// Push LWC context
			LOG_Engine.pushOperationContext(LOG_Engine.OperationType.LWC, new Map<String, String> {LOG_Engine.CONTEXT_SOURCE => LOG_Engine.OperationType.LWC.name()});

			for(DTO_ClientLogEntry dtoClientLogEntry : dtoClientLogEntries)
			{
				Map<String, Object> contextMap = String.isNotBlank(dtoClientLogEntry.context)
						? (Map<String, Object>)JSON.deserializeUntyped(dtoClientLogEntry.context)
						: null;
				String classMethod = LOG_Engine.OperationType.LWC.name() + '/' + ((String)contextMap?.get(LOG_Engine.CONTEXT_ACTION_NAME) ?? 'unknown');
				LOG_Builder.LogEntry entry = LOG_Builder.build().at(classMethod);

				switch on dtoClientLogEntry.level
				{
					when ERROR
					{
						entry.error(dtoClientLogEntry.message).emit();
					}
					when WARN
					{
						entry.warn(dtoClientLogEntry.message).emit();
					}
					when DEBUG
					{
						entry.debug(dtoClientLogEntry.message).emit();
					}
					when else
					{
						entry.info(dtoClientLogEntry.message).emit();
					}
				}
			}

			LOG_Engine.popOperationContext();
		}
	}

	/**
	 * @description DTO class representing a client-side log entry from LWC.
	 * Properties are AuraEnabled to allow direct passing from JavaScript.
	 */
	public class DTO_ClientLogEntry
	{
		/**
		 * @description Timestamp of when the log was created
		 */
		@AuraEnabled
		public Datetime timestamp;
		/**
		 * @description Log level (DEBUG, INFO, WARN, ERROR)
		 */
		@AuraEnabled
		public LoggingLevel level;
		/**
		 * @description Log message
		 */
		@AuraEnabled
		public String message;
		/**
		 * @description Correlation ID for linking related logs
		 */
		@AuraEnabled
		public String correlationId;
		/**
		 * @description Additional context data as a JSON string.
		 */
		@AuraEnabled
		public String context;
	}
}