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
 * @date December 2025, October 2026
 *
 * @example
 * ```javascript
 * // From JavaScript (LWC)
 * import persistLogs from '@salesforce/apex/CTRL_Logger.persistLogs';
 * const logs = [
 *     {
 *         timestamp: new Date(), level: 'INFO', message: 'User clicked save', correlationId: 'abc-123',
 *         context: JSON.stringify({componentName: 'orderPanel', actionName: 'submitOrder'})
 *     }
 * ];
 * await persistLogs({entries: logs});
 * ```
 */
public inherited sharing class CTRL_Logger
{
	/**
	 * @description Context key naming the LWC bundle a client entry came from, such as `orderPanel`.
	 */
	@TestVisible
	private static final String CONTEXT_COMPONENT_NAME = 'componentName';

	/**
	 * @description Stand-in used in the class/method label when a client entry names neither a
	 * component nor an action.
	 */
	@TestVisible
	private static final String UNKNOWN_SOURCE = 'unknown';

	/**
	 * @description Context keys whose values name where a client entry came from, in the order they
	 * read in the class/method label: the component first, then the action it was performing.
	 */
	private static final List<String> SOURCE_CONTEXT_KEYS = new List<String> {CONTEXT_COMPONENT_NAME, LOG_Engine.CONTEXT_ACTION_NAME};

	/**
	 * @description Persists LWC logs to the logging framework. Accepts a JSON string because LWC
	 * does not support inner class or Map deserialization for @AuraEnabled parameters. Each
	 * entry's client context is persisted into `ContextData__c`, a client JavaScript error
	 * stack, when present, becomes the entry's stack trace, the exception class the client
	 * reported becomes the entry's exception type, and the component and action named in that
	 * context become the entry's class/method label. The operation context this opens for the batch is
	 * closed again whether the batch is written or an entry in it cannot be read, so a failure here never
	 * leaves a later log entry in the same request stamped with it.
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

			try
			{
				for(DTO_ClientLogEntry dtoClientLogEntry : dtoClientLogEntries)
				{
					Map<String, Object> contextMap = String.isNotBlank(dtoClientLogEntry.context)
							? (Map<String, Object>)JSON.deserializeUntyped(dtoClientLogEntry.context)
							: null;
					Map<String, String> sourceNames = resolveSourceNames(contextMap);
					LOG_Builder.LogEntry entry = LOG_Builder.build().at(buildClassMethod(sourceNames));

					attachClientContext(entry, contextMap, sourceNames.keySet());

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
			}
			finally
			{
				LOG_Engine.popOperationContext();
			}
		}
	}

	/**
	 * @description Collects the client context values that name where an entry came from — the
	 * component and the action — keyed by their context key. Only non-blank text can name either,
	 * so anything else (an absent key, a number, a nested object) is left out and stays in the
	 * persisted context rather than being promoted.
	 *
	 * @param contextMap The deserialized client context, or null when the client sent none.
	 *
	 * @return The usable source names keyed by context key; empty when the entry named nothing.
	 */
	private static Map<String, String> resolveSourceNames(Map<String, Object> contextMap)
	{
		Map<String, String> sourceNames = new Map<String, String>();

		for(String key : SOURCE_CONTEXT_KEYS)
		{
			Object value = contextMap?.get(key);

			if(value instanceof String && String.isNotBlank((String)value))
			{
				sourceNames.put(key, (String)value);
			}
		}

		return sourceNames;
	}

	/**
	 * @description Builds the class/method label for a client entry: the LWC operation type, then
	 * the component and the action the client named, joined as `LWC/orderPanel.submitOrder`. An
	 * entry that named only one of the two carries just that one; an entry that named neither falls
	 * back to `LWC/unknown`.
	 *
	 * @param sourceNames The usable source names keyed by context key, from `resolveSourceNames`.
	 *
	 * @return The class/method label to stamp on the entry.
	 */
	private static String buildClassMethod(Map<String, String> sourceNames)
	{
		List<String> sourceSegments = new List<String>();

		for(String key : SOURCE_CONTEXT_KEYS)
		{
			if(sourceNames.containsKey(key))
			{
				sourceSegments.add(sourceNames.get(key));
			}
		}

		return LOG_Engine.COMPONENT_SOURCE_PREFIX + (sourceSegments.isEmpty() ? UNKNOWN_SOURCE : String.join(sourceSegments, '.'));
	}

	/**
	 * @description Carries the client-supplied context payload onto the log entry so it persists
	 * into `ContextData__c`, and promotes two of its values into fields of their own: the
	 * client-side JavaScript error stack into the entry's stack trace (the synthetic Apex trace for
	 * an LWC entry holds only framework plumbing), and the exception class the client reported into
	 * the entry's exception type, which is what problem grouping keys on. A key is left out of the
	 * persisted context only when its value was actually promoted elsewhere on the entry — the
	 * component name and action name into the classMethod label, the error stack into
	 * `StackTrace__c`, the exception class into `ExceptionType__c`. A value that could not be
	 * promoted (non-text or blank) stays in context so no client data is lost.
	 *
	 * @param entry The builder entry being assembled for one client log line.
	 * @param contextMap The deserialized client context, or null when the client sent none.
	 * @param labelledKeys The context keys already promoted into the classMethod label.
	 */
	private static void attachClientContext(LOG_Builder.LogEntry entry, Map<String, Object> contextMap, Set<String> labelledKeys)
	{
		if(contextMap == null || contextMap.isEmpty())
		{
			return;
		}

		Object clientStackTrace = contextMap.get(LOG_Engine.CONTEXT_ERROR_STACK);
		Object clientExceptionType = contextMap.get(LOG_Engine.CONTEXT_EXCEPTION_TYPE);
		Set<String> promotedKeys = new Set<String>(labelledKeys);

		if(clientStackTrace instanceof String && String.isNotBlank((String)clientStackTrace))
		{
			entry.withStackTraceInternal((String)clientStackTrace);
			promotedKeys.add(LOG_Engine.CONTEXT_ERROR_STACK);
		}

		if(clientExceptionType instanceof String && String.isNotBlank((String)clientExceptionType))
		{
			entry.withExceptionTypeInternal((String)clientExceptionType);
			promotedKeys.add(LOG_Engine.CONTEXT_EXCEPTION_TYPE);
		}

		for(String key : contextMap.keySet())
		{
			if(!promotedKeys.contains(key))
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
		 * @description The text the component logged. persistLogs passes it unchanged to the log builder at the entry's level,
		 * and any level other than ERROR, WARN or DEBUG is logged as INFO.
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