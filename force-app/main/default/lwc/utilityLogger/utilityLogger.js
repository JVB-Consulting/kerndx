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
 * @date December 2025, October 2026
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
 * @description True when a value is text worth persisting — a string holding at least one
 * non-whitespace character.
 *
 * @param {*} value - Candidate value
 * @returns {boolean} True when the value is non-blank text
 * @private
 */
function isPresentText(value)
{
	return typeof value === 'string' && value.trim().length > 0;
}

/**
 * @description Pulls the structured detail out of a caught failure so the persisted entry carries
 * it in named fields rather than buried in a nested payload: the server message, the stack the
 * failure reported (`stack` for a JavaScript error, `body.stackTrace` for an Apex failure relayed
 * by Aura) and the Apex exception class name. The server-side bridge promotes `errorStack` into the
 * log entry's stack trace. Blank and absent values are left out so a caller's own structured
 * payload is never overwritten with an empty string. An array of failures reports the first.
 *
 * @param {Error|Object|Object[]|string} failure - The caught error, an Aura failure, or structured data
 * @returns {Object} The detail keys that could be resolved
 * @private
 */
function describeError(failure)
{
	const [first] = Array.isArray(failure) ? failure : [failure];
	const source = first ?? {};
	const errorMessage = typeof source === 'string' ? source : (source.body?.message ?? source.message);
	const errorStack = source.stack ?? source.body?.stackTrace;
	const exceptionType = source.body?.exceptionType ?? (source instanceof Error ? source.name : undefined);
	const details = {};

	if(isPresentText(errorMessage))
	{
		details.errorMessage = errorMessage;
	}

	if(isPresentText(errorStack))
	{
		details.errorStack = errorStack;
	}

	if(isPresentText(exceptionType))
	{
		details.exceptionType = exceptionType;
	}

	return details;
}

/**
 * @description Keeps whatever the caller passed alongside the failure so nothing is lost from the
 * persisted context: a plain object is copied as-is, an array of failures is kept under `errors`,
 * and an Error or a bare string contributes nothing (their text is normalised into the detail keys
 * by {@link describeError} instead of being spread one key per character).
 *
 * @param {Error|Object|Object[]|string} failure - The caught error, an Aura failure, or structured data
 * @returns {Object} The context payload to persist alongside the resolved detail
 * @private
 */
function resolveErrorPayload(failure)
{
	if(Array.isArray(failure))
	{
		return {errors: failure};
	}

	if(failure instanceof Error || typeof failure === 'string')
	{
		return {};
	}

	return {...failure};
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
		console.error('[utilityLogger] Server persistence failed:', persistError);
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
 * @description Logs an ERROR-level message and immediately flushes the buffer. Accepts an Error
 * instance, an Aura failure relayed from Apex, an array of Lightning Data Service failures, or a
 * plain data object; whichever it is, the server message, stack and Apex exception class are
 * normalised into named context keys the server-side bridge understands. Pass the calling
 * component's name so the persisted entry can be attributed to it instead of an unnamed source.
 *
 * @param {string} message - Log message
 * @param {Error|Object|Object[]|string} [failure={}] - Error object, Aura failure, or structured data
 * @param {string} [componentName=''] - Name of the component the failure surfaced in
 */
function error(message, failure = {}, componentName = '')
{
	const data = {...resolveErrorPayload(failure), ...describeError(failure)};

	if(isPresentText(componentName))
	{
		data.componentName = componentName;
	}

	appendEntry(LogLevel.ERROR, message, data);
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