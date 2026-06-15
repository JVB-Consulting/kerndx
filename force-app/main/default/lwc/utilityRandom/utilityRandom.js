// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Random value generation utilities for LWC — numeric, alphabetic,
 * alphanumeric strings and UUID v4.
 *
 * @author Jason van Beukering
 *
 * @date June 2021, March 2026
 */
import {CAPITAL_LETTERS, DIGITS, LOWER_CASE_LETTERS} from 'c/utilityString';

/**
 * @description Builds a random string by sampling characters from the provided alphabet.
 * @param {string} alphabet - Character set to sample from
 * @param {number} length - Desired output length
 * @returns {string} Random string of the specified length
 * @private
 */
function sample(alphabet, length)
{
	return Array.from({length}, () => alphabet[Math.floor(Math.random() * alphabet.length)]).join('');
}

/**
 * @description Resolves the character alphabet based on case options.
 * @param {string} base - Base characters (letters only, no digits)
 * @param {boolean} caseSensitive - Include both upper and lower case
 * @param {boolean} lowerCaseOnly - When caseSensitive is false, prefer lower case
 * @returns {string} Resolved alphabet
 * @private
 */
function resolveAlphabet(base, caseSensitive, lowerCaseOnly)
{
	if(caseSensitive)
	{
		return CAPITAL_LETTERS + LOWER_CASE_LETTERS + base;
	}
	return (lowerCaseOnly ? LOWER_CASE_LETTERS : CAPITAL_LETTERS) + base;
}

/**
 * @description Returns a random numeric string of the specified length.
 * @param {number} length - Desired string length
 * @returns {string} Random numeric string (digits only)
 */
export function getRandomNumericString(length)
{
	return sample(DIGITS, length);
}

/**
 * @description Returns a random alphabetic string of the specified length.
 * @param {number} length - Desired string length
 * @param {boolean} [caseSensitive=true] - Include both upper and lower case letters
 * @param {boolean} [lowerCaseOnly=true] - When caseSensitive is false, use lower case only; otherwise capitals only
 * @returns {string} Random alphabetic string
 */
export function getRandomAlphaString(length, caseSensitive = true, lowerCaseOnly = true)
{
	const alphabet = resolveAlphabet('', caseSensitive, lowerCaseOnly);
	return sample(alphabet, length);
}

/**
 * @description Returns a random alphanumeric string of the specified length.
 * @param {number} length - Desired string length
 * @param {boolean} [caseSensitive=true] - Include both upper and lower case letters
 * @param {boolean} [lowerCaseOnly=true] - When caseSensitive is false, use lower case only; otherwise capitals only
 * @returns {string} Random alphanumeric string
 */
export function getRandomAlphaNumericString(length, caseSensitive = true, lowerCaseOnly = true)
{
	const alphabet = resolveAlphabet(DIGITS, caseSensitive, lowerCaseOnly);
	return sample(alphabet, length);
}

// UUID v4 constants
const HEX_RADIX = 16;
const VARIANT_MASK = 0x3;
const VARIANT_BITS = 0x8;

/**
 * @description Generates a UUID v4 string. Delegates to the native `crypto.randomUUID()` API
 * when available; falls back to a Math.random()-based implementation for older environments.
 *
 * @returns {string} UUID v4 (e.g. '550e8400-e29b-41d4-a716-446655440000')
 */
export function generateUUID()
{
	if(typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function')
	{
		return crypto.randomUUID();
	}

	return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (placeholder) =>
	{
		const random = Math.floor(Math.random() * HEX_RADIX);
		const value = placeholder === 'x' ? random : (random & VARIANT_MASK) | VARIANT_BITS;
		return value.toString(HEX_RADIX);
	});
}