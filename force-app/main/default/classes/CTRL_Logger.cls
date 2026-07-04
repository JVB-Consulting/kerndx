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
 * @date December 2025, July 2026
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
	 * does not support inner class or Map deserialization for @AuraEnabled parameters. Each
	 * entry's client context is persisted into `ContextData__c` and a client JavaScript error
	 * stack, when present, becomes the entry's stack trace.
	 *
	 * @param entriesJson JSON-serialized List of DTO_ClientLogEntry objects to persist.
	 *
	 * @date July 2026
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

				attachClientContext(entry, contextMap);

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
	 * @description Carries the client-supplied context payload onto the log entry so it persists
	 * into `ContextData__c`, and promotes the client-side JavaScript error stack into the entry's
	 * stack trace (the synthetic Apex trace for an LWC entry holds only framework plumbing). The
	 * action name is excluded because it is already promoted into the classMethod label; the error
	 * stack is excluded from context only when it was actually promoted into `StackTrace__c` — a
	 * non-string or blank value cannot be promoted and stays in context so no client data is lost.
	 *
	 * @param entry The builder entry being assembled for one client log line.
	 * @param contextMap The deserialized client context, or null when the client sent none.
	 *
	 * @date July 2026
	 */
	private static void attachClientContext(LOG_Builder.LogEntry entry, Map<String, Object> contextMap)
	{
		if(contextMap == null || contextMap.isEmpty())
		{
			return;
		}

		Object clientStackTrace = contextMap.get(LOG_Engine.CONTEXT_ERROR_STACK);
		Boolean stackPromoted = clientStackTrace instanceof String && String.isNotBlank((String)clientStackTrace);

		if(stackPromoted)
		{
			entry.withStackTraceInternal((String)clientStackTrace);
		}

		for(String key : contextMap.keySet())
		{
			Boolean promotedKey = key == LOG_Engine.CONTEXT_ACTION_NAME || (key == LOG_Engine.CONTEXT_ERROR_STACK && stackPromoted);

			if(!promotedKey)
			{
				entry.withContext(key, contextMap.get(key));
			}
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