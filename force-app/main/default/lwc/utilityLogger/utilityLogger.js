// SPDX-License-Identifier: BUSL-1.1
/**
 * @file utilityLogger.js
 * @module c/utilityLogger
 *
 * @description Client-side logging with server-side persistence for LWC components.
 * Provides correlation tracking across async Apex calls, automatic log buffering,
 * and performance measurement.
 *
 * @author Jason van Beukering
 *
 * @date December 2025, July 2026
 *
 * @group Logging
 *
 * @example
 * import utilityLogger from 'c/utilityLogger';
 *
 * utilityLogger.info('User clicked button', { buttonName: 'Submit' });
 *
 * await utilityLogger.withCorrelation('Save Account', async (correlationId) => {
 *     return await saveAccount({ record, correlationId });
 * });
 *
 * @exports utilityLogger
 */
import persistLogs from '@salesforce/apex/CTRL_Logger.persistLogs';
import {generateUUID} from 'c/utilityRandom';

// ── Log Levels ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Log severity levels aligned with the Apex LoggingLevel enum.
 * @readonly
 * @enum {string}
 */
const LogLevel = Object.freeze({
	DEBUG: 'DEBUG', INFO: 'INFO', WARN: 'WARN', ERROR: 'ERROR'
});

/** @description Maps LogLevel values to their corresponding `console` method. */
const CONSOLE_METHODS = Object.freeze({
	[LogLevel.ERROR]: 'error', [LogLevel.WARN]: 'warn', [LogLevel.DEBUG]: 'log', [LogLevel.INFO]: 'log'
});

/** @description Number of buffered entries at which the buffer drains to the server automatically. */
const AUTO_FLUSH_ENTRY_THRESHOLD = 20;

// ── Module State ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Open correlation frames, innermost last. Each frame carries its own id, start time,
 * and metadata so nested or overlapping correlations never clobber one another.
 * @type {{correlationId: string, startMs: number, meta: Object}[]}
 */
const correlationFrames = [];

/** @type {Object[]} */
const pendingEntries = [];

/** @description Console mirroring is opt-in debug tooling — OFF by default in a released package. */
let isConsoleMirroringEnabled = false;

// ── Internal Helpers ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Returns the innermost open correlation frame, or null when none is open.
 * @returns {{correlationId: string, startMs: number, meta: Object}|null}
 * @private
 */
function getActiveFrame()
{
	return correlationFrames.length > 0 ? correlationFrames[correlationFrames.length - 1] : null;
}

/**
 * @description Serialises structured context, falling back to a serialisation-error marker for
 * circular or otherwise unserialisable data so a logging call can never crash its caller.
 *
 * @param {Object} context - Structured context to serialise
 * @returns {string} JSON string of the context, or of a serialisation-error marker
 * @private
 */
function serialiseContext(context)
{
	try
	{
		return JSON.stringify(context);
	}
	catch(serialisationError)
	{
		return JSON.stringify({serialisationError: serialisationError.message});
	}
}

/**
 * @description Appends a structured log entry to the buffer, optionally mirrors it to the browser
 * console (when mirroring is enabled), and drains the buffer once it reaches the auto-flush bound.
 *
 * @param {string} level - One of the LogLevel values
 * @param {string} message - Human-readable log message
 * @param {Object} data - Arbitrary structured data to attach (every caller supplies it)
 * @param {Object|null} [frame=getActiveFrame()] - Correlation frame the entry belongs to
 * @private
 */
function appendEntry(level, message, data, frame = getActiveFrame())
{
	pendingEntries.push({
		timestamp: new Date().toISOString(), level, message, correlationId: frame?.correlationId ?? null, context: serialiseContext({...frame?.meta, ...data})
	});

	if(isConsoleMirroringEnabled)
	{
		console[CONSOLE_METHODS[level]](`[${level}] ${message}`, data);
	}

	if(pendingEntries.length >= AUTO_FLUSH_ENTRY_THRESHOLD)
	{
		flush();
	}
}

/**
 * @description Sends all buffered log entries to the server via the CTRL_Logger Apex controller.
 * On failure, dumps the entries to the browser console as a fallback.
 * @private
 */
function flush()
{
	if(pendingEntries.length === 0)
	{
		return;
	}

	const snapshot = [...pendingEntries];
	pendingEntries.length = 0;

	persistLogs({entriesJson: JSON.stringify(snapshot)})
	.catch((persistError) =>
	{
		console.error('[utilityLogger] Server persistence failed:', persistError); // eslint-disable-line kerndx/no-console-log -- module-scoped flush(); no `this` binding for consoleError()
		console.group('[utilityLogger] Buffered entries:');
		for(const entry of snapshot)
		{
			console[CONSOLE_METHODS[entry.level]](`[${entry.level}] ${entry.timestamp} | ${entry.correlationId ?? 'no-correlation'} | ${entry.message}`, entry.context);
		}
		console.groupEnd();
	});
}

// ── Public API ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/**
 * @description Opens a new correlation context. All subsequent log entries are tagged
 * with the generated correlation ID until {@link endCorrelation} is called.
 *
 * @param {string} actionName - Descriptive name for the operation being correlated
 * @param {Object} [context={}] - Additional metadata to include in every entry
 * @returns {string} The generated correlation ID
 */
function startCorrelation(actionName, context = {})
{
	const frame = {
		correlationId: generateUUID(), startMs: performance.now(), meta: {actionName, startTime: new Date().toISOString(), ...context}
	};
	correlationFrames.push(frame);
	appendEntry(LogLevel.INFO, `[${actionName}] Started`, {}, frame);
	return frame.correlationId;
}

/**
 * @description Closes a correlation, logs its total duration, and flushes all buffered entries
 * to the server. Called with no arguments it closes the innermost open correlation; pass the ID
 * returned by {@link startCorrelation} to close a specific correlation when several overlap.
 *
 * @param {Object} [result={}] - Outcome data (e.g. `{success: true}`)
 * @param {string|null} [correlationId=null] - Specific correlation to close; defaults to the innermost open one
 */
function endCorrelation(result = {}, correlationId = null)
{
	const frameIndex = correlationId === null ? correlationFrames.length - 1 : correlationFrames.findIndex((frame) => frame.correlationId === correlationId);

	if(frameIndex < 0)
	{
		return;
	}

	const [endedFrame] = correlationFrames.splice(frameIndex, 1);
	const durationMs = Math.round(performance.now() - endedFrame.startMs);
	appendEntry(LogLevel.INFO, `[${endedFrame.meta.actionName}] Completed in ${durationMs}ms`, {durationMs, ...result}, endedFrame);
	flush();
}

/**
 * @description Returns the innermost active correlation ID, or null when no correlation is open.
 * @returns {string|null}
 */
function getCorrelationId()
{
	return getActiveFrame()?.correlationId ?? null;
}

/**
 * @description Turns browser-console mirroring of log entries on or off. Mirroring is OFF by
 * default in a released package; enable it explicitly while debugging to echo every buffered
 * entry to the matching `console` method.
 *
 * @param {boolean} isEnabled - True to mirror entries to the console
 */
function setConsoleMirroring(isEnabled)
{
	isConsoleMirroringEnabled = isEnabled === true;
}

/**
 * @description Logs a DEBUG-level message. Use for detailed diagnostic data.
 * @param {string} message - Log message
 * @param {Object} [data={}] - Structured context
 */
function debug(message, data = {})
{
	appendEntry(LogLevel.DEBUG, message, data);
}

/**
 * @description Logs an INFO-level message. Use for general operational information.
 * @param {string} message - Log message
 * @param {Object} [data={}] - Structured context
 */
function info(message, data = {})
{
	appendEntry(LogLevel.INFO, message, data);
}

/**
 * @description Logs a WARN-level message. Use for potentially problematic situations.
 * @param {string} message - Log message
 * @param {Object} [data={}] - Structured context
 */
function warn(message, data = {})
{
	appendEntry(LogLevel.WARN, message, data);
}

/**
 * @description Logs an ERROR-level message and immediately flushes the buffer.
 * Accepts either an Error instance or a plain data object.
 *
 * @param {string} message - Log message
 * @param {Error|Object} [err={}] - Error object or structured data
 */
function error(message, err = {})
{
	const errorData = err instanceof Error ? {errorMessage: err.message, errorStack: err.stack} : err;
	appendEntry(LogLevel.ERROR, message, errorData);
	flush();
}

/**
 * @description Starts a performance timer. Call `.stop()` on the returned object
 * to log the elapsed duration as a DEBUG entry.
 *
 * @param {string} operationName - Label for the timed operation
 * @returns {{stop: (function(Object=): number)}} Timer with a `stop()` method returning duration in ms
 */
function startTimer(operationName)
{
	const origin = performance.now();

	return {
		stop(data = {})
		{
			const durationMs = Math.round(performance.now() - origin);
			appendEntry(LogLevel.DEBUG, `[PERF] ${operationName}: ${durationMs}ms`, {operationName, durationMs, ...data});
			return durationMs;
		}
	};
}

/**
 * @description Wraps an async operation with automatic correlation lifecycle management.
 * Opens a correlation before the operation and closes it afterward (on success or failure).
 *
 * @param {string} actionName - Descriptive action label
 * @param {function(string): Promise<*>} asyncFn - Async function receiving the correlation ID
 * @param {Object} [context={}] - Additional metadata
 * @returns {Promise<*>} The result of `asyncFn`
 * @throws {Error} Re-throws any error from `asyncFn` after logging it
 */
async function withCorrelation(actionName, asyncFn, context = {})
{
	const correlationId = startCorrelation(actionName, context);
	try
	{
		const result = await asyncFn(correlationId);
		endCorrelation({success: true}, correlationId);
		return result;
	}
	catch(err)
	{
		error(`[${actionName}] Failed`, err);
		endCorrelation({success: false}, correlationId);
		throw err;
	}
}

/**
 * @description Test-only hook to force-flush buffered entries.
 * @private
 */
function _flushLogs()
{
	flush();
}

// ── Exports ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

export {LogLevel, startCorrelation, endCorrelation, getCorrelationId, debug, info, warn, error, startTimer, withCorrelation, setConsoleMirroring, _flushLogs};

/** @type {utilityLogger} */
export default {LogLevel, startCorrelation, endCorrelation, getCorrelationId, debug, info, warn, error, startTimer, withCorrelation, setConsoleMirroring, _flushLogs};