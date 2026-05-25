// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Platform utilities for LWC — error reduction, comparator factory,
 * clipboard operations, object flattening, and property definition.
 *
 * @author Jason van Beukering
 *
 * @date June 2021, December 2025, March 2026
 */
import utilityLogger from 'c/utilityLogger';

/**
 * @typedef {Object} ErrorDetail
 * @property {string} [message] - Error message text
 */

/**
 * @typedef {Object} UiApiOutput
 * @property {ErrorDetail[]} [errors] - UI API output-level error records
 * @property {Object<string, ErrorDetail[]>} [fieldErrors] - UI API field errors keyed by field API name
 */

/**
 * @typedef {Object} FetchResponseBody
 * @property {string} [message] - Top-level error message
 * @property {ErrorDetail[]} [duplicateResults] - Duplicate record errors
 * @property {ErrorDetail[]|Object<string, ErrorDetail[]>} [fieldErrors] - Field errors — LDS shape is an Object keyed by field API name; legacy callers pass an Array
 * @property {ErrorDetail[]} [pageErrors] - Page-level errors
 * @property {UiApiOutput} [output] - UI API output envelope
 */

/**
 * @typedef {Object} FetchResponse
 * @property {FetchResponseBody|ErrorDetail[]} [body] - Response body
 * @property {string} [message] - Direct error message
 * @property {string} [statusText] - HTTP status text
 * @property {number|string} [status] - HTTP status code
 */

const ERROR_SEPARATOR = ' // ';

/**
 * @description Extracts message strings from a response body, handling the various
 * shapes returned by LDS (array, duplicateResults, fieldErrors, pageErrors, or plain message).
 *
 * @param {FetchResponseBody|ErrorDetail[]} body - Response body to inspect
 * @param {string} [message] - Fallback message from the outer error object
 * @returns {string|string[]|undefined} Extracted message(s) or undefined
 * @private
 */
function extractBodyMessages(body, message)
{
	if(Array.isArray(body))
	{
		return body.map((entry) => entry.message);
	}

	const bodyObj = /** @type {FetchResponseBody} */ (body);

	if(bodyObj?.duplicateResults?.length > 0)
	{
		return bodyObj.duplicateResults.map((entry) => entry.message);
	}

	if(bodyObj?.fieldErrors && !Array.isArray(bodyObj.fieldErrors) && Object.keys(bodyObj.fieldErrors).length > 0)
	{
		return Object.values(bodyObj.fieldErrors).flat().map((entry) => entry.message);
	}

	if(Array.isArray(bodyObj?.fieldErrors) && bodyObj.fieldErrors.length > 0)
	{
		return bodyObj.fieldErrors.map((entry) => entry.message);
	}

	if(bodyObj?.pageErrors?.length > 0)
	{
		return bodyObj.pageErrors.map((entry) => entry.message);
	}

	if(bodyObj?.output?.errors?.length > 0)
	{
		return bodyObj.output.errors.map((entry) => entry.message);
	}

	if(bodyObj?.output?.fieldErrors && Object.keys(bodyObj.output.fieldErrors).length > 0)
	{
		return Object.values(bodyObj.output.fieldErrors).flat().map((entry) => entry.message);
	}

	if(typeof bodyObj?.message === 'string')
	{
		return bodyObj.message;
	}

	if(typeof message === 'string')
	{
		return message;
	}

	return undefined;
}

/**
 * @description Extracts a human-readable message from a single error-like object.
 *
 * @param {FetchResponse} errorItem - A normalised error object
 * @returns {string|string[]|undefined} Extracted error text
 * @private
 */
function extractMessage(errorItem)
{
	const {body, message, statusText, status} = errorItem;

	if(body !== undefined && body !== null)
	{
		return extractBodyMessages(body, message);
	}

	if(statusText && status)
	{
		return `${status} - ${statusText}`;
	}

	if(statusText)
	{
		return statusText;
	}

	if(status)
	{
		return String(status);
	}

	if(typeof message === 'string')
	{
		return message;
	}

	return undefined;
}

/**
 * @description Reduces one or more LDS / Apex / network errors into a single human-readable string.
 * @see https://developer.salesforce.com/docs/component-library/documentation/en/lwc/lwc.data_error
 *
 * @param {Error|FetchResponse|FetchResponse[]|string} errors - Error(s) to reduce
 * @returns {string} All error messages joined by ' // '
 */
export function reduceErrors(errors)
{
	const normalised = (Array.isArray(errors) ? errors : [errors])
	.filter(Boolean)
	.map((entry) => (typeof entry === 'string' ? {message: entry} : entry));

	return normalised
	.map((item) => extractMessage(item))
	.filter((msg) => msg !== undefined)
	.join(ERROR_SEPARATOR);
}

/**
 * @description Creates a comparator function for `Array.prototype.sort()`.
 *
 * @param {string} field - Property name to sort by
 * @param {number} [direction=1] - Sort direction: `1` ascending, `-1` descending
 * @param {((value: *) => *)|null} [transform=null] - Optional value transform applied before comparison
 * @returns {(a: *, b: *) => number} Comparator function
 */
export function sortBy(field, direction = 1, transform = null)
{
	const extractKey = transform ? (obj) => transform(obj[field]) : (obj) => obj[field];

	return (objectA, objectB) =>
	{
		const a = extractKey(objectA);
		const b = extractKey(objectB);

		if(a > b)
		{
			return direction;
		}
		if(b > a)
		{
			return -direction;
		}
		return 0;
	};
}

/**
 * @description Copies the provided text to the system clipboard. Uses the modern
 * Clipboard API with a fallback to a temporary input element for restricted contexts.
 *
 * @param {string} text - Text to copy
 * @returns {Promise<void>}
 */
export async function copyToClipBoard(text)
{
	if(!text)
	{
		return;
	}

	try
	{
		await navigator.clipboard.writeText(text);
	}
	catch(clipboardError)
	{
		utilityLogger.warn('Clipboard API unavailable, using fallback', {
			errorMessage: clipboardError.message, errorStack: clipboardError.stack
		});

		const temporaryInput = document.createElement('input');
		temporaryInput.setAttribute('value', text);
		document.body.appendChild(temporaryInput);
		temporaryInput.select();

		try
		{
			// eslint-disable-next-line no-restricted-properties
			document.execCommand('copy');
		}
		catch(fallbackError)
		{
			utilityLogger.error('Clipboard fallback failed', fallbackError);
		}
		finally
		{
			document.body.removeChild(temporaryInput);
		}
	}
}

/**
 * @description Recursively flattens a nested object into a single-depth object with
 * dot-notation keys. Arrays and null values are preserved as leaf values.
 *
 * @param {Object<string, *>} source - Object to flatten
 * @returns {Object<string, *>} Flat object with dot-separated keys
 *
 * @example
 * flattenObject({a: {b: 1, c: {d: 2}}})
 * // => {'a.b': 1, 'a.c.d': 2}
 */
export function flattenObject(source)
{
	if(!source)
	{
		return {};
	}

	const result = {};

	for(const [key, value] of Object.entries(source))
	{
		if(value !== null && typeof value === 'object' && !Array.isArray(value))
		{
			const nested = flattenObject(value);
			for(const [nestedKey, nestedValue] of Object.entries(nested))
			{
				result[`${key}.${nestedKey}`] = nestedValue;
			}
		}
		else
		{
			result[key] = value;
		}
	}

	return result;
}

/**
 * @description Sets a property on an object — updating it if it already exists, or
 * defining it via `Object.defineProperty` if it does not.
 *
 * @param {Object} target - Object to modify
 * @param {string} key - Property name
 * @param {*} [value=null] - Value to assign
 * @param {boolean} [writable=true] - Whether the property should be writable
 * @returns {Object} The modified object (for chaining)
 */
export function setPropertyOnObject(target, key, value = null, writable = true)
{
	if(key in target)
	{
		target[key] = value;
	}
	else
	{
		Object.defineProperty(target, key, {value, writable, enumerable: true});
	}

	return target;
}