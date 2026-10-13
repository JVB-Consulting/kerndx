// SPDX-License-Identifier: MIT
/**
 * MIT License
 *
 * Copyright (c) Mike Lockett 2024
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/**
 * @description Primary logging interface for application debugging, monitoring, and error tracking.
 * Uses a fluent builder API for rich contextual logging.
 *
 * ```apex
 * // Full chain with context
 * LOG_Builder.build()
 *     .error(caughtException)
 *     .at('PaymentService.charge')
 *     .forRecord(paymentId)
 *     .withContext('amount', payment.Amount__c)
 *     .emit();
 *
 * // Quick one-liner using emitAt shorthand
 * LOG_Builder.build().error(caughtException).emitAt('PaymentService.charge');
 * ```
 *
 * **Key Features:**
 * - Fluent builder for combining level, location, record, and context in a single chain
 * - Support for single messages, batch messages, and exception logging
 * - Record ID correlation for tracing log entries to specific data
 * - DML operation result analysis and error extraction
 * - Correlation IDs for multi-transaction tracing
 * - Scoped logging for batched publish
 * - Integration with platform events for asynchronous log processing
 *
 * **Querying log entries: filter by `UserId__c`, NOT `CreatedById`.**
 * `TRG_PersistLogEntry` saves log entries. It is the trigger on the `LogEntryEvent__e` platform event.
 * Salesforce runs platform event triggers as the Automated Process user. So EVERY saved `LogEntry__c` row
 * has `CreatedById` set to the Automated Process user, NOT to the user that called `LOG_Builder.emit()`.
 * When the event is published, the framework stores the Id of the user who logged the entry in
 * `LogEntry__c.UserId__c`. To query logs by that user, use:
 *
 * ```apex
 * // RIGHT: returns logs from the running user
 * QRY_Builder.selectFrom(LogEntry__c.SObjectType)
 *     .condition(LogEntry__c.UserId__c).equals(UserInfo.getUserId())
 *     .toList();
 *
 * // WRONG: returns ZERO rows without any error (CreatedById is the Automated Process user)
 * QRY_Builder.selectFrom(LogEntry__c.SObjectType)
 *     .condition(LogEntry__c.CreatedById).equals(UserInfo.getUserId())
 *     .toList();
 * ```
 *
 * The same applies to subscriber reports, dashboards, cleanup scripts, and audit queries. See
 * the section "Querying Log Entries" in the Logging Developer Guide for full examples.
 *
 * @see LoggingLevel
 * @see LOG_Builder_TEST
 * @see TRG_PersistLogEntry
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date October 2024, October 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * LOG_Builder.build().error(caughtException).emitAt('MyClass.myMethod');
 * LOG_Builder.build().info('Processing complete').emitAt('MyClass.myMethod');
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.CognitiveComplexity,PMD.AvoidBooleanMethodParameters,PMD.ExcessiveClassLength')
global inherited sharing class LOG_Builder
{
	/**
	 * @description Maximum raw fingerprint key length stored as-is; longer keys are hashed.
	 */
	@TestVisible
	private static final Integer MAXIMUM_RAW_FINGERPRINT_LENGTH = 200;

	/**
	 * @description Key prefix kept for the framework's bypass audit fingerprints. A subscriber key that starts with
	 * it is hashed, so it can never match a framework key. It is public so that `UTIL_BypassAudit`, which writes
	 * these keys, and the method that cleans up keys read the prefix from one place.
	 */
	public static final String RESERVED_FINGERPRINT_PREFIX = 'bypass:';

	/**
	 * @description Controls whether logging events are published during test execution.
	 * When set to true, enables logging in test mode for debugging test-specific issues.
	 * Defaults to false to avoid unnecessary logging overhead during unit tests.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.ignoreTestMode = true;
	 * LOG_Builder.build().debug('Test debugging message').at('TestClass.testMethod').emit();
	 * ```
	 */
	global static Boolean ignoreTestMode
	{
		get
		{
			return LOG_Engine.ignoreTestMode;
		}
		set
		{
			LOG_Engine.ignoreTestMode = value;
		}
	}

	/**
	 * @description Analyzes DML operation results and logs any errors encountered during database operations.
	 * Automatically extracts and logs error details from failed DML operations, supporting various result types
	 * including SaveResult, DeleteResult, UpsertResult, and UndeleteResult.
	 *
	 * @param operationResults Collection of DML operation results to analyze for errors
	 * @param classMethod The originating class and method in format 'ClassName.methodName'
	 *
	 * @return Boolean indicating whether any errors were found and logged
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Database.SaveResult> results = Database.insert(accounts, false);
	 * Boolean hasErrors = LOG_Builder.errorDMLOperationResults(results, 'AccountService.insertAccounts');
	 * if(hasErrors)
	 * {
	 * 	// Handle the fact that some records failed
	 * 	System.debug('Some account insertions failed - check logs for details');
	 * }
	 * ```
	 */
	global static Boolean errorDMLOperationResults(List<Object> operationResults, String classMethod)
	{
		return LOG_Engine.log(operationResults, classMethod);
	}

	/**
	 * @description Starts a new correlation context for multi-transaction tracing. The first correlation a transaction
	 * starts also becomes its root correlation id, the id the entries that follow name as their action; a later
	 * correlation started in the same transaction moves the correlation id and keeps that root.
	 *
	 * @return String The generated correlation ID to pass to child processes
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String correlationId = LOG_Builder.startCorrelation();
	 * System.enqueueJob(new MyQueueable(correlationId));
	 * ```
	 */
	global static String startCorrelation()
	{
		return LOG_Engine.startCorrelation();
	}

	/**
	 * @description Sets the correlation ID for child transactions. When the transaction has no root correlation id
	 * yet, this id becomes it; a later call moves the correlation id and keeps that root.
	 *
	 * @param correlationId The correlation ID from parent transaction
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.setCorrelationId('value');
	 * ```
	 */
	global static void setCorrelationId(String correlationId)
	{
		LOG_Engine.setCorrelationId(correlationId);
	}

	/**
	 * @description The current correlation ID for log grouping across related operations.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String value = LOG_Builder.correlationId;
	 * ```
	 */
	global static String correlationId
	{
		get
		{
			return LOG_Engine.getCorrelationId();
		}
	}

	/**
	 * @description The root correlation id: the tracking id of the action that started everything the current
	 * transaction belongs to. It equals the correlation id until a background chain continues the action under a
	 * tracking id of its own; then the correlation id names that run and the root still names the action. Search the
	 * Log Console for it to see every entry the action produced.
	 *
	 * @since 1.8
	 *
	 * @example
	 * ```apex
	 * String actionId = LOG_Builder.rootCorrelationId;
	 * ```
	 */
	global static String rootCorrelationId
	{
		get
		{
			return LOG_Engine.getRootCorrelationId();
		}
	}

	/**
	 * @description Sets parent transaction ID for hierarchy tracking.
	 *
	 * @param parentTransactionId The parent transaction's Request ID
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.setParentTransactionId('value');
	 * ```
	 */
	global static void setParentTransactionId(String parentTransactionId)
	{
		LOG_Engine.setParentTransactionId(parentTransactionId);
	}

	/**
	 * @description Serializes logging context for async job transfer.
	 *
	 * @return String JSON context to pass to Queueable/Batch/Future
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String logContext = LOG_Builder.serializeContext();
	 * System.enqueueJob(new MyQueueable(logContext));
	 * ```
	 */
	global static String serializeContext()
	{
		return LOG_Engine.serializeContext();
	}

	/**
	 * @description Serializes a logging context carrying the SUPPLIED correlation id: for
	 * handing a different execution its own logging identity (for example, a restarted chain's
	 * fresh run) without reading or touching this transaction's live context. The document is
	 * minimal on purpose: it carries no transaction lineage and no live context data, because it
	 * is written for another execution and outlives this request. It starts a new action: a job that
	 * restores it names the supplied id as both its correlation id and its root, so a search for the
	 * launching action's root does not find that job's entries. A job meant to continue the current
	 * action should carry serializeContext() instead.
	 *
	 * @param correlationId The correlation id the serialized context carries.
	 *
	 * @return String JSON context for the supplied correlation id, ready for hydrateContext.
	 *
	 * @since 1.7
	 *
	 * @example
	 * ```apex
	 * String cloneLogContext = LOG_Builder.serializeContext(cloneCorrelationId);
	 * ```
	 */
	global static String serializeContext(String correlationId)
	{
		return LOG_Engine.serializeContext(correlationId);
	}

	/**
	 * @description Restores logging context in async jobs.
	 *
	 * @param serializedContext JSON from serializeContext()
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * public void execute(QueueableContext ctx)
	 * {
	 *     LOG_Builder.hydrateContext(this.logContext);
	 *     LOG_Builder.build().info('Processing with correlation').at('MyQueueable.execute').emit();
	 * }
	 * ```
	 */
	global static void hydrateContext(String serializedContext)
	{
		LOG_Engine.hydrateContext(serializedContext);
	}

	/**
	 * @description Sets a global context value included in ALL logs this transaction.
	 *
	 * @param key Context key (e.g., 'orderId')
	 * @param value Context value
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.setGlobalContext('orderId', order.Id);
	 * LOG_Builder.build().info('Processing order').at('OrderService.process').emit(); // Includes orderId
	 * ```
	 */
	global static void setGlobalContext(String key, Object value)
	{
		LOG_Engine.setGlobalContext(key, value);
	}

	/**
	 * @description Clears a specific global context key.
	 *
	 * @param key The key to remove
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.clearGlobalContext('value');
	 * ```
	 */
	global static void clearGlobalContext(String key)
	{
		LOG_Engine.clearGlobalContext(key);
	}

	/**
	 * @description Clears all global context values.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.clearAllGlobalContext();
	 * ```
	 */
	global static void clearAllGlobalContext()
	{
		LOG_Engine.clearAllGlobalContext();
	}

	/**
	 * @description Suspends log publishing. Use try/finally to ensure resumeSaving().
	 * ERROR logs bypass buffer and trigger immediate flush, except inside a trigger the framework runs on a
	 * platform event or change event, where an ERROR waits with the rest and is written when the trigger ends.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.suspendSaving();
	 * try
	 * {
	 *     for(Account account : accounts)
	 *     {
	 *         LOG_Builder.build().debug('Processing: ' + account.Name).at('BatchJob.execute').emit();
	 *     }
	 *     LOG_Builder.flushBuffer();
	 * }
	 * finally
	 * {
	 *     LOG_Builder.resumeSaving();
	 * }
	 * ```
	 */
	global static void suspendSaving()
	{
		LOG_Engine.suspendSaving();
	}

	/**
	 * @description Resumes log publishing and flushes buffer.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.resumeSaving();
	 * ```
	 */
	global static void resumeSaving()
	{
		LOG_Engine.resumeSaving();
	}

	/**
	 * @description Manually flushes buffered logs without resuming.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.flushBuffer();
	 * ```
	 */
	global static void flushBuffer()
	{
		LOG_Engine.flushBuffer();
	}

	/**
	 * @description Creates a logging scope that suspends immediate log publishing. Logs emitted within
	 * the scope are buffered until the scope is closed, at which point the buffer is flushed and
	 * publishing resumes. This replaces the manual suspendSaving/flushBuffer/resumeSaving try/finally
	 * pattern with a single close() call.
	 *
	 * @return LogScope A new scope instance that must be closed when logging is complete
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.LogScope scope = LOG_Builder.scope();
	 * for(Account account : accounts)
	 * {
	 *     LOG_Builder.build().debug('Processing: ' + account.Name).at('BatchJob.execute').emit();
	 * }
	 * scope.close();
	 * ```
	 */
	global static LogScope scope()
	{
		return new LogScope();
	}

	/**
	 * @description A logging scope that buffers log entries until closed. On creation, suspends
	 * immediate log publishing. On close, flushes all buffered logs and resumes publishing.
	 * Provides a simpler alternative to manual suspendSaving/flushBuffer/resumeSaving patterns.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.LogScope scope = LOG_Builder.scope();
	 * LOG_Builder.build().debug('Step 1').at('BatchJob.execute').emit();
	 * LOG_Builder.build().debug('Step 2').at('BatchJob.execute').emit();
	 * scope.close();
	 * ```
	 */
	global inherited sharing class LogScope
	{
		/**
		 * @description Whether this scope has already been closed.
		 */
		private Boolean isClosed = false;

		/**
		 * @description Creates a new LogScope and suspends log publishing.
		 */
		private LogScope()
		{
			LOG_Engine.suspendSaving();
		}

		/**
		 * @description Flushes all buffered logs and resumes publishing. Safe to call multiple times;
		 * subsequent calls after the first are no-ops.
		 *
		 * @since 1.0
		 */
		global void close()
		{
			if(isClosed)
			{
				return;
			}

			isClosed = true;
			LOG_Engine.flushBuffer();
			LOG_Engine.resumeSaving();
		}
	}

	/**
	 * @description Creates a new fluent log entry builder for constructing rich contextual log entries.
	 *
	 * @return LogEntry A new builder instance
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.build()
	 *     .error(caughtException)
	 *     .at('PaymentService.charge')
	 *     .forRecord(paymentId)
	 *     .withContext('amount', payment.Amount__c)
	 *     .emit();
	 * ```
	 */
	global static LogEntry build()
	{
		return new LogEntry();
	}

	/**
	 * @description Creates a new log entry with the level set from a string. Used by Flow invocable
	 * classes to avoid duplicating the level-dispatch switch in each caller. Unrecognised or blank
	 * levels fall back to INFO.
	 *
	 * @param levelString The log level as a string (ERROR, WARN, INFO, DEBUG). Case-insensitive.
	 * @param message The message to log.
	 *
	 * @return LogEntry A new builder with the level and message applied, ready for chaining.
	 */
	public static LogEntry build(String levelString, String message)
	{
		String level = String.isNotBlank(levelString) ? levelString.toUpperCase() : 'INFO';
		LogEntry entry = new LogEntry();

		switch on level
		{
			when 'ERROR'
			{
				entry.error(message);
			}
			when 'WARN'
			{
				entry.warn(message);
			}
			when 'DEBUG'
			{
				entry.debug(message);
			}
			when else
			{
				entry.info(message);
			}
		}

		return entry;
	}

	/**
	 * @description Cleans up a fingerprint key that a subscriber supplied. It trims the key, and a blank key becomes
	 * null. A key that is too long, or that starts with the reserved prefix, becomes its SHA-256 hash in hex. A key
	 * is never cut short, because two different events whose keys differ only after the cut would then look the same.
	 *
	 * @param key The raw subscriber key.
	 *
	 * @return The normalized key, or null when blank.
	 */
	private static String normalizeFingerprintKey(String key)
	{
		String normalized = normalizeStoredFingerprintKey(key);
		if(normalized == null)
		{
			return null;
		}
		return normalized.startsWith(RESERVED_FINGERPRINT_PREFIX) ? UTIL_Crypto.generateSHA256Hash(normalized) : normalized;
	}

	/**
	 * @description Puts a fingerprint key into the exact form that `LogEntry__c.Fingerprint__c` can hold. A blank
	 * key becomes null, spaces at the start and end are trimmed, and a key longer than MAXIMUM_RAW_FINGERPRINT_LENGTH
	 * is replaced by its SHA-256 hash. The database needs both the trim and the length check, for different reasons.
	 * Salesforce removes spaces at the start and end of a text field when it saves it. So a key that was not trimmed
	 * is stored under a value that a lookup with the untrimmed key can never find. And a key that is too long makes
	 * the key with its `detail:` or `rollup:` prefix longer than the field, so the row is refused.
	 *
	 * Every piece of code that stores a fingerprint passes its key through this method, so one rule applies
	 * everywhere: `withFingerprint`, `withFingerprintInternal`, and the trigger that saves log entries
	 * (`TRG_PersistLogEntry.groupEvents`). The trigger cleans the key again because it also receives events that
	 * never passed through this class: a `LogEntryEvent__e` published directly carries whatever its own
	 * 216-character field accepted.
	 *
	 * @param key The raw key to put into a form that can be stored.
	 *
	 * @return The storable key, or null when the key is blank.
	 */
	public static String normalizeStoredFingerprintKey(String key)
	{
		return String.isBlank(key) ? null : capFingerprintLength(key.trim());
	}

	/**
	 * @description Keeps a fingerprint key within MAXIMUM_RAW_FINGERPRINT_LENGTH by replacing a longer key with its
	 * SHA-256 hash, so the keys with a `detail:` or `rollup:` prefix always fit the Fingerprint__c field. The key is
	 * hashed, not cut short, on purpose: a cut would make two different events whose keys differ only after the cut
	 * look the same.
	 *
	 * This is the length check of `normalizeStoredFingerprintKey`. That method is its only caller, and it has
	 * already trimmed the key.
	 *
	 * @param key The already-trimmed key to check.
	 *
	 * @return The key unchanged when it is short enough, otherwise its SHA-256 hash.
	 */
	private static String capFingerprintLength(String key)
	{
		if(key != null && key.length() > MAXIMUM_RAW_FINGERPRINT_LENGTH)
		{
			return UTIL_Crypto.generateSHA256Hash(key);
		}
		return key;
	}

	/**
	 * @description Lets a test call normalizeFingerprintKey, so tests can check the key clean-up rules
	 * without making the method visible to subscribers.
	 *
	 * @param key The raw key to normalize.
	 *
	 * @return The normalized key.
	 */
	@TestVisible
	private static String normalizeFingerprintKeyForTest(String key)
	{
		return normalizeFingerprintKey(key);
	}

	/**
	 * @description Fluent builder for constructing rich log entries with context.
	 * Provides a chainable API for setting log level, location, record association,
	 * and contextual metadata before emitting the log.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.build()
	 *     .error(caughtException)
	 *     .at('PaymentService.charge')
	 *     .forRecord(paymentId)
	 *     .withContext('amount', payment.Amount__c)
	 *     .emit();
	 * ```
	 */
	global inherited sharing class LogEntry
	{
		/**
		 * @description Brief summary message for the log entry.
		 */
		private String shortMessage;

		/**
		 * @description Detailed message for the log entry.
		 */
		private String longMessage;

		/**
		 * @description The originating class and method.
		 */
		private String classMethod;

		/**
		 * @description The associated record ID.
		 */
		private Id recordId;

		/**
		 * @description The log severity level.
		 */
		private LoggingLevel logLevel = LoggingLevel.DEBUG;

		/**
		 * @description The exception to log.
		 */
		private Exception error;

		/**
		 * @description List of messages for batch logging.
		 */
		private List<String> longMessages;

		/**
		 * @description Per-entry context key-value pairs.
		 */
		private final Map<String, Object> context = new Map<String, Object>();

		/**
		 * @description Normalized grouping key for flood control, or null when ungrouped.
		 */
		private String fingerprintKey;

		/**
		 * @description Caller-supplied stack trace persisted instead of the synthetic Apex trace,
		 * or null to let the engine calculate one. Ignored when an exception is logged.
		 */
		private String stackTrace;

		/**
		 * @description Caller-supplied exception class name persisted as the entry's exception type, or
		 * null to leave the type unset. Ignored when an exception is logged.
		 */
		private String exceptionType;

		/**
		 * @description Sets the log level to DEBUG with the given message.
		 *
		 * @param message The debug message
		 *
		 * @return This LogEntry for chaining
		 *
		 * @since 1.0
		 */
		global LogEntry debug(String message)
		{
			this.longMessage = message;
			this.logLevel = LoggingLevel.DEBUG;
			return this;
		}

		/**
		 * @description Sets the log level to INFO with the given message.
		 *
		 * @param message The informational message
		 *
		 * @return This LogEntry for chaining
		 *
		 * @since 1.0
		 */
		global LogEntry info(String message)
		{
			this.longMessage = message;
			this.logLevel = LoggingLevel.INFO;
			return this;
		}

		/**
		 * @description Sets the log level to WARN with the given message.
		 *
		 * @param message The warning message
		 *
		 * @return This LogEntry for chaining
		 *
		 * @since 1.0
		 */
		global LogEntry warn(String message)
		{
			this.longMessage = message;
			this.logLevel = LoggingLevel.WARN;
			return this;
		}

		/**
		 * @description Sets the log level to ERROR with the given message.
		 *
		 * @param message The error message
		 *
		 * @return This LogEntry for chaining
		 *
		 * @since 1.0
		 */
		global LogEntry error(String message)
		{
			this.longMessage = message;
			this.logLevel = LoggingLevel.ERROR;
			return this;
		}

		/**
		 * @description Sets the log level to ERROR with the given exception.
		 *
		 * @param error The exception to log
		 *
		 * @return This LogEntry for chaining
		 *
		 * @since 1.0
		 */
		global LogEntry error(Exception error)
		{
			this.error = error;
			this.logLevel = LoggingLevel.ERROR;
			return this;
		}

		/**
		 * @description Sets the log level to DEBUG with the given batch of messages.
		 *
		 * @param messages The debug messages to log
		 *
		 * @return This LogEntry for chaining
		 *
		 * @since 1.0
		 */
		global LogEntry debug(List<String> messages)
		{
			this.longMessages = messages;
			this.logLevel = LoggingLevel.DEBUG;
			return this;
		}

		/**
		 * @description Sets the log level to INFO with the given batch of messages.
		 *
		 * @param messages The informational messages to log
		 *
		 * @return This LogEntry for chaining
		 *
		 * @since 1.0
		 */
		global LogEntry info(List<String> messages)
		{
			this.longMessages = messages;
			this.logLevel = LoggingLevel.INFO;
			return this;
		}

		/**
		 * @description Sets the log level to WARN with the given batch of messages.
		 *
		 * @param messages The warning messages to log
		 *
		 * @return This LogEntry for chaining
		 *
		 * @since 1.0
		 */
		global LogEntry warn(List<String> messages)
		{
			this.longMessages = messages;
			this.logLevel = LoggingLevel.WARN;
			return this;
		}

		/**
		 * @description Sets the log level to ERROR with the given batch of messages.
		 *
		 * @param messages The error messages to log
		 *
		 * @return This LogEntry for chaining
		 *
		 * @since 1.0
		 */
		global LogEntry error(List<String> messages)
		{
			this.longMessages = messages;
			this.logLevel = LoggingLevel.ERROR;
			return this;
		}

		/**
		 * @description Sets the originating class and method for the log entry.
		 *
		 * @param classMethod The class and method in format 'ClassName.methodName'
		 *
		 * @return This LogEntry for chaining
		 *
		 * @since 1.0
		 */
		global LogEntry at(String classMethod)
		{
			this.classMethod = classMethod;
			return this;
		}

		/**
		 * @description Associates a record ID with the log entry.
		 *
		 * @param recordId The related record ID
		 *
		 * @return This LogEntry for chaining
		 *
		 * @since 1.0
		 */
		global LogEntry forRecord(Id recordId)
		{
			this.recordId = recordId;
			return this;
		}

		/**
		 * @description Associates a record ID (as String) with the log entry.
		 *
		 * @param recordId String representation of the related record ID
		 *
		 * @return This LogEntry for chaining
		 *
		 * @since 1.0
		 */
		global LogEntry forRecord(String recordId)
		{
			this.recordId = UTIL_SObject.validateId(recordId);
			return this;
		}

		/**
		 * @description Sets a brief summary message for the log entry. On an entry that carries an
		 * exception, the summary becomes the short message and the exception's text stays the message.
		 *
		 * @param shortMessage The summary message
		 *
		 * @return This LogEntry for chaining
		 *
		 * @since 1.0
		 */
		global LogEntry withSummary(String shortMessage)
		{
			this.shortMessage = shortMessage;
			return this;
		}

		/**
		 * @description Sets a grouping fingerprint for this entry, which turns on flood control. Flood control stops
		 * the same event from filling the log: the first time the event happens it is saved as a full detail row,
		 * and repeats are added up in one counter row per day. Use a key that names the kind of event and never
		 * changes (e.g. 'payment-retry-loop'). Never use data that changes each time, such as record ids or
		 * timestamps: that would make every entry unique and produce MORE rows than plain logging. Keys are trimmed.
		 * Keys longer than 200 characters, or starting with the reserved 'bypass:' prefix, are replaced by their
		 * SHA-256 hash. When a key is hashed, the original key is saved in this entry's context
		 * (`LOG_Engine.CONTEXT_FINGERPRINT_SOURCE`), so you can still match the stored hash to the key you supplied.
		 *
		 * @param key The stable grouping key.
		 *
		 * @return This LogEntry for chaining
		 *
		 * @since 1.1
		 *
		 * @example
		 * ```apex
		 * LOG_Builder.build().warn('Retry failed').withFingerprint('order-sync-retry').emitAt('OrderSync.run');
		 * ```
		 */
		global LogEntry withFingerprint(String key)
		{
			this.fingerprintKey = normalizeFingerprintKey(key);
			if(this.fingerprintKey != null && this.fingerprintKey != key.trim())
			{
				this.context.put(LOG_Engine.CONTEXT_FINGERPRINT_SOURCE, key.trim());
			}
			return this;
		}

		/**
		 * @description The framework's own way to set a fingerprint. It does not hash keys that start with the
		 * reserved prefix, so the framework can store such keys exactly as written, for example bypass audit
		 * fingerprints. It still trims the key and limits its length through `normalizeStoredFingerprintKey`, so the
		 * database never refuses a framework key that the subscriber method would have fixed. It is public, not
		 * global, so subscribers cannot call it.
		 *
		 * @param key The pre-composed framework fingerprint key.
		 *
		 * @return This LogEntry for chaining
		 */
		public LogEntry withFingerprintInternal(String key)
		{
			this.fingerprintKey = normalizeStoredFingerprintKey(key);
			return this;
		}

		/**
		 * @description For the framework only: saves a stack trace the caller supplies, instead of the Apex stack trace
		 * worked out when the entry is emitted. `CTRL_Logger` uses it to keep the JavaScript stack trace of entries
		 * that come from a Lightning web component, because their Apex call stack shows only framework code. It is
		 * ignored when the entry logs a real exception: the exception's own stack trace is always used. It is public,
		 * not global, so subscribers cannot call it. Subscriber Apex logs its own call stack, or an exception, through
		 * the global methods.
		 *
		 * @param stackTrace The stack trace text to persist; blank values are ignored.
		 *
		 * @return This LogEntry for chaining
		 *
		 * @date July 2026
		 */
		public LogEntry withStackTraceInternal(String stackTrace)
		{
			this.stackTrace = stackTrace;
			return this;
		}

		/**
		 * @description For the framework only: names the entry's exception type when no Apex exception carries that
		 * name. `CTRL_Logger` uses it to save the exception class that a failure in the browser reported. So a
		 * failure in a Lightning web component names its type the way a failure in Apex does, and is grouped with the
		 * same problems. It is ignored when the entry logs a real exception: the exception's own type is always used.
		 * It is public, not global, so subscribers cannot call it. Subscriber Apex names a type by logging the
		 * exception itself through the global methods.
		 *
		 * @param exceptionType The exception class name to persist; blank values are ignored.
		 *
		 * @return This LogEntry for chaining
		 */
		public LogEntry withExceptionTypeInternal(String exceptionType)
		{
			this.exceptionType = exceptionType;
			return this;
		}

		/**
		 * @description Adds a context key-value pair to this log entry.
		 * Context is scoped to this entry only and does not affect other logs.
		 *
		 * Complex types (Maps, Lists, SObjects) are turned into JSON automatically inside
		 * `LOG_Engine.setGlobalContext`. Callers MUST NOT turn them into JSON first with `JSON.serialize(value)`,
		 * or the value is encoded twice. Pass the value object directly and let the engine decide how to store it.
		 * Use the `LOG_Engine.CONTEXT_*` constants for `key` instead of your own text, so that log entries from every
		 * part of the framework use the same key names and can be searched together.
		 *
		 * @param key The context key (use a `LOG_Engine.CONTEXT_*` constant where one exists).
		 * @param value The context value (any type; auto-serialised when complex).
		 *
		 * @return This LogEntry for chaining
		 *
		 * @since 1.0
		 */
		global LogEntry withContext(String key, Object value)
		{
			this.context.put(key, value);
			return this;
		}

		/**
		 * @description A shortcut that sets the class and method and emits the entry in one call.
		 * Equivalent to `.at(classMethod).emit()`.
		 *
		 * @param classMethod The class and method in format 'ClassName.methodName'
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * LOG_Builder.build().error(caughtException).emitAt('PaymentService.charge');
		 * ```
		 */
		global void emitAt(String classMethod)
		{
			this.classMethod = classMethod;
			emit();
		}

		/**
		 * @description Emits the log entry with all configured properties.
		 * Any per-entry context is temporarily set as global context for the duration of the log call,
		 * then cleaned up to prevent leaking into subsequent logs.
		 *
		 * @since 1.0
		 */
		global void emit()
		{
			emitInternal(false);
		}

		/**
		 * @description For the framework only: emits this log entry into the separate audit log buffer instead of the
		 * application log buffer. A buffer is the list of entries waiting to be published. `UTIL_BypassAudit.emit`
		 * uses it, so that `BypassEvent` audit entries do not change the results of tests that count the entries in
		 * the application log buffer or the `LogEntry__c` rows. What is saved is exactly the same as with `emit()`: the
		 * same `LogEntryEvent__e` data, saved by the same `TRG_PersistLogEntry`, as the same kind of `LogEntry__c` row.
		 * Only the waiting entries are kept in a separate list.
		 *
		 * It is public, not global, so subscribers cannot call it. Subscriber Apex that emits its own logs must call
		 * `emit()`, so the application log buffer counts those entries. `UTIL_BypassAudit.emit` uses this method to save
		 * bypass audit entries. They need their own buffer for two reasons. In test mode it stops a loop where saving
		 * an entry writes an audit entry, which is emitted and saved, and writes another. And it keeps test checks of
		 * the application log buffer accurate.
		 *
		 * @example
		 * ```apex
		 * LOG_Builder.build()
		 *     .warn('Bypass audit: query BYPASS "system-mode"')
		 *     .at('UTIL_BypassAudit.emit')
		 *     .withContext('category', 'BypassEvent')
		 *     .emitAsAudit();
		 * ```
		 */
		public void emitAsAudit()
		{
			emitInternal(true);
		}

		/**
		 * @description The code that `emit()` and `emitAsAudit()` share. It sends the log entry either to the
		 * application log (`LOG_Engine.log`) or to the audit log (`LOG_Engine.logAudit`), depending on `isAudit`. The
		 * entry's own context is set as global context only while the log call runs, then removed, so it does not
		 * reach later logs. The values the entry passes to the engine for one emit follow the same pattern:
		 * `openEmitChannels` sets them, and `closeEmitChannels` clears them in the finally block.
		 *
		 * @param isAudit `true` to route to the audit buffer; `false` for the application buffer.
		 */
		private void emitInternal(Boolean isAudit)
		{
			Set<String> addedContextKeys = new Set<String>();

			for(String key : context.keySet())
			{
				addedContextKeys.add(key);
				LOG_Engine.setGlobalContext(key, context.get(key));
			}

			openEmitChannels();

			try
			{
				if(isAudit)
				{
					LOG_Engine.logAudit(shortMessage, longMessage, classMethod, recordId, logLevel);
				}
				else if(longMessages != null)
				{
					LOG_Engine.log(longMessages, classMethod, logLevel);
				}
				else if(error != null)
				{
					if(shortMessage != null)
					{
						LOG_Engine.log(error, shortMessage, classMethod, recordId, logLevel);
					}
					else if(recordId != null)
					{
						LOG_Engine.log(error, classMethod, recordId, logLevel);
					}
					else
					{
						LOG_Engine.log(error, classMethod, logLevel);
					}
				}
				else
				{
					LOG_Engine.log(shortMessage, longMessage, classMethod, recordId, logLevel);
				}
			}
			finally
			{
				for(String key : addedContextKeys)
				{
					LOG_Engine.clearGlobalContext(key);
				}

				closeEmitChannels();
			}
		}

		/**
		 * @description Passes this entry's values for one emit to the engine: its fingerprint, its stack trace and
		 * its exception type. Each of these is called a channel. Every event built during the log call then uses them.
		 * A channel is set only when this entry has a value for it; the others are left as they are. `emitInternal`
		 * clears all three in its finally block, so a value can never carry over into a later entry.
		 */
		private void openEmitChannels()
		{
			if(String.isNotBlank(fingerprintKey))
			{
				LOG_Engine.setCurrentFingerprint(fingerprintKey);
			}

			if(String.isNotBlank(stackTrace))
			{
				LOG_Engine.setCurrentStackTrace(stackTrace);
			}

			if(String.isNotBlank(exceptionType))
			{
				LOG_Engine.setCurrentExceptionType(exceptionType);
			}
		}

		/**
		 * @description Clears every channel that `openEmitChannels` can set, whether this entry set it or not, so the
		 * next entry emitted in the same transaction starts with none of these values on the engine.
		 */
		private void closeEmitChannels()
		{
			LOG_Engine.clearCurrentFingerprint();
			LOG_Engine.clearCurrentStackTrace();
			LOG_Engine.clearCurrentExceptionType();
		}
	}
}