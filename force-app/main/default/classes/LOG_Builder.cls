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
 * **Querying log entries — filter by `UserId__c`, NOT `CreatedById`:**
 * Log entries are persisted by `TRG_PersistLogEntry` running on the `LogEntryEvent__e` Platform
 * Event subscriber. Salesforce executes Platform Event triggers as the Automated Process user, so
 * EVERY persisted `LogEntry__c` row has `CreatedById` set to the Automated Process user — NOT
 * the user that called `LOG_Builder.emit()`. The framework captures the emitting user's Id at
 * publish time into `LogEntry__c.UserId__c`. To query logs by emitting user, use:
 *
 * ```apex
 * // RIGHT — returns logs from the running user
 * QRY_Builder.selectFrom(LogEntry__c.SObjectType)
 *     .condition(LogEntry__c.UserId__c).equals(UserInfo.getUserId())
 *     .toList();
 *
 * // WRONG — silently returns ZERO rows (CreatedById is the Automated Process user)
 * QRY_Builder.selectFrom(LogEntry__c.SObjectType)
 *     .condition(LogEntry__c.CreatedById).equals(UserInfo.getUserId())
 *     .toList();
 * ```
 *
 * The same applies to subscriber reports, dashboards, cleanup scripts, and audit queries. See
 * the Logging Developer Guide → "Querying Log Entries" for worked subscriber examples.
 *
 * @see LoggingLevel
 * @see LOG_Builder_TEST
 *
 * @author Jason van Beukering
 *
 * @group Logging
 *
 * @date October 2024, June 2026
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
	 * @description Key prefix reserved for framework bypass-audit fingerprints; subscriber keys
	 * invading it are hashed so they can never collide with framework keys. Public so the framework
	 * producer (`UTIL_BypassAudit`) and the normalizer share one source of truth for the prefix.
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
	 * @description Starts a new correlation context for multi-transaction tracing.
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
	 * @description Sets the correlation ID for child transactions.
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
	 * ERROR logs bypass buffer and trigger immediate flush.
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
	global class LogScope
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
	/**
	 * @description Normalizes a subscriber-supplied fingerprint key: trims; blank → null;
	 * oversized or reserved-prefix keys → SHA-256 hex (never truncated — truncation would
	 * silently collapse distinct events whose keys differ only past the cut).
	 *
	 * @param key The raw subscriber key.
	 *
	 * @return The normalized key, or null when blank.
	 */
	private static String normalizeFingerprintKey(String key)
	{
		if(String.isBlank(key))
		{
			return null;
		}
		String trimmed = key.trim();
		if(trimmed.startsWith(RESERVED_FINGERPRINT_PREFIX))
		{
			return UTIL_Crypto.generateSHA256Hash(trimmed);
		}
		return capFingerprintLength(trimmed);
	}

	/**
	 * @description Length-caps a fingerprint key to the raw budget by SHA-256 hashing anything
	 * longer, so the prefixed `detail:`/`rollup:` keys always fit the Fingerprint__c field. Shared
	 * by the subscriber normalizer and the framework-internal setter so neither path can overflow.
	 *
	 * @param key The already-trimmed or pre-composed key to length-check.
	 *
	 * @return The key unchanged when within budget, otherwise its SHA-256 hash.
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
	 * @description Test-only window onto normalizeFingerprintKey so normalization rules are
	 * pinned without exposing the helper to subscribers.
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
	global class LogEntry
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
		 * @description Sets a brief summary message for the log entry.
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
		 * @description Sets a grouping fingerprint for this entry, enabling flood control: the first
		 * occurrence persists as a full detail row, repeats roll up into daily counter rows. Use a
		 * STABLE event-template identity (e.g. 'payment-retry-loop') — never per-occurrence data
		 * such as record ids or timestamps, which would make every entry unique and produce MORE
		 * rows than plain logging. Keys are trimmed; keys longer than 200 characters or starting
		 * with the reserved 'bypass:' prefix are SHA-256 hashed. When a key is hashed, the original
		 * key is recorded in this entry's context (`LOG_Engine.CONTEXT_FINGERPRINT_SOURCE`) so the
		 * opaque stored fingerprint stays reconcilable with what you supplied.
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
		 * @description Framework-internal fingerprint setter that skips subscriber normalization so
		 * the framework can stamp reserved-prefix keys verbatim (e.g. bypass-audit fingerprints), but
		 * still length-caps an oversized key (SHA-256 hash beyond the raw budget) so the framework can
		 * never overflow the Fingerprint__c field. Public-but-not-global so subscribers cannot bind to it.
		 *
		 * @param key The pre-composed framework fingerprint key.
		 *
		 * @return This LogEntry for chaining
		 */
		public LogEntry withFingerprintInternal(String key)
		{
			this.fingerprintKey = capFingerprintLength(key);
			return this;
		}

		/**
		 * @description Adds a context key-value pair to this log entry.
		 * Context is scoped to this entry only and does not affect other logs.
		 *
		 * Complex types (Maps, Lists, SObjects) are JSON-serialised automatically inside
		 * `LOG_Engine.setGlobalContext` — callers MUST NOT pre-serialise via `JSON.serialize(value)`
		 * or the payload is double-encoded. Pass the value object directly and let the engine
		 * decide the wire form. Prefer `LOG_Engine.CONTEXT_*` constants for `key` over string
		 * literals so cross-framework log entries pivot on the same key namespace.
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
		 * @description Convenience terminal that sets the class/method and emits in one call.
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
		 * @description Framework-internal terminal that routes this log entry into the dedicated
		 * audit log buffer instead of the application log buffer. Used by `UTIL_BypassAudit.emit`
		 * so `BypassEvent`-shape audit entries do not pollute test assertions that count
		 * application-log buffer size or `LogEntry__c` rows. The persisted wire format is identical
		 * to `emit()` — same `LogEntryEvent__e` payload, same `TRG_PersistLogEntry` persistence,
		 * same `LogEntry__c` row shape — only the in-flight buffer accumulates separately.
		 *
		 * Public-but-not-global so subscribers cannot bind to it; subscriber Apex emitting their
		 * own logs must call `emit()` so application-log buffer accounting reflects their writes.
		 * Used by `UTIL_BypassAudit.emit` when persisting bypass audit entries (which require an
		 * isolated buffer to avoid the emit→deliver→persist→emit cascade in test mode and to keep
		 * application-log buffer assertions clean).
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
		 * @description Shared implementation of `emit()` and `emitAsAudit()` — routes the log
		 * entry through either the application-log path (`LOG_Engine.log`) or the audit-log path
		 * (`LOG_Engine.logAudit`) depending on `isAudit`. Per-entry context is temporarily set as
		 * global context for the duration of the log call, then cleaned up to prevent leaking
		 * into subsequent logs.
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

			if(String.isNotBlank(fingerprintKey))
			{
				LOG_Engine.setCurrentFingerprint(fingerprintKey);
			}

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
					if(recordId != null)
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

				LOG_Engine.clearCurrentFingerprint();
			}
		}
	}
}