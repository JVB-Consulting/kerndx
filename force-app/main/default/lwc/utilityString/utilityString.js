// SPDX-License-Identifier: BUSL-1.1
/**
 * @description String formatting, transformation, and common delimiter constants for LWC components.
 *
 * @author Jason van Beukering
 *
 * @date June 2021, March 2026
 */

		// ── Delimiters ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
export const EMPTY = '';
export const SPACE = ' ';
export const COMMA = ',';
export const SEMI_COLON = ';';
export const COLON = ':';
export const NEW_LINE = '\n';
export const CRLF = '\r\n';
export const TAB = '\t';
export const TILDE = '~';

// ── Character Sets ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
export const CAPITAL_LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
export const LOWER_CASE_LETTERS = 'abcdefghijklmnopqrstuvwxyz';
export const DIGITS = '0123456789';

/**
 * @description Replaces positional placeholders ({0}, {1}, ...) in a template with the corresponding
 * values from the substitutes array. Mirrors the Apex String.format() convention.
 * Excess substitutes are ignored; unmatched placeholders are removed.
 *
 * @param {string} templateString - Template containing {0}, {1}, ... placeholders
 * @param {(string|number)[]} substitutes - Replacement values, applied left-to-right by index
 * @returns {string} The interpolated string
 */
export function formatTemplateString(templateString, substitutes)
{
	if(!templateString)
	{
		return EMPTY;
	}

	// The replacer function inserts the value verbatim — a plain-string replacement would
	// interpret $-patterns ($$, $&, $`, $') inside substituted values, diverging from
	// the Apex String.format() behaviour this helper mirrors.
	return substitutes.reduce((result, value, index) => result.replaceAll(`{${index}}`, () => String(value)), templateString);
}

/**
 * @description Converts a string to sentence case — first letter of each sentence is capitalised,
 * all other characters are lowered. Sentence boundaries are detected by `.`, `!`, or `?`.
 *
 * @param {string} text - Mixed-case input
 * @returns {string} Sentence-cased output
 */
export function convertToSentenceCase(text)
{
	const SENTENCE_START = /(^\s*\w|[.!?]\s*\w)/g;
	return text.toLowerCase().replace(SENTENCE_START, (match) => match.toUpperCase());
}

/**
 * @description Inserts a separator character at every `n`-th position within a string.
 * Useful for formatting card numbers, serial keys, etc.
 *
 * @param {string} source - The string to modify
 * @param {number} interval - Insert separator every `interval` characters
 * @param {string} [separator=' '] - Character to insert (defaults to a space)
 * @returns {string} The formatted string
 */
export function insertCharacterAtInterval(source, interval, separator = SPACE)
{
	const CHUNK_PATTERN = new RegExp(`(.{${interval}})(?!$)`, 'g');
	return source.replace(CHUNK_PATTERN, `$1${separator}`);
}

/**
 * @description Formats a decimal string (e.g. "10000.50") into a display currency
 * string with thousand-separators and a currency symbol prefix (e.g. "R 10 000.50").
 *
 * @param {string} numberString - Numeric string in `whole.decimals` format
 * @param {string} currencySymbol - Symbol to prepend (e.g. "R", "$", "€")
 * @returns {string} Formatted currency string
 */
export function formatStringToCurrency(numberString, currencySymbol)
{
	const THOUSANDS = /(\d)(?=(\d{3})+(?!\d))/g;
	return `${currencySymbol} ${numberString.replace(THOUSANDS, '$1 ')}`;
}