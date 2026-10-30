// SPDX-License-Identifier: Apache-2.0
/**
 * @description String formatting, transformation, and common delimiter constants for LWC components.
 *
 * @author Jason van Beukering
 *
 * @date June 2021, October 2026
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
// noinspection SpellCheckingInspection
export const CAPITAL_LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
// noinspection SpellCheckingInspection
export const LOWER_CASE_LETTERS = 'abcdefghijklmnopqrstuvwxyz';
export const DIGITS = '0123456789';

/**
 * @description Replaces positional placeholders ({0}, {1}, ...) in a template with the corresponding
 * values from the substitutes array. Mirrors the Apex String.format() convention.
 * Extra substitutes are ignored. A placeholder with no substitute stays in the text as it is:
 * `formatTemplateString('{0} {1}', ['only'])` gives `'only {1}'`.
 *
 * @param {string} templateString - Template containing {0}, {1}, ... placeholders
 * @param {(string|number)[]} substitutes - Replacement values, applied left-to-right by index
 * @returns {string} The interpolated string
 */
export function formatTemplateString(templateString, substitutes)
{
	let formatted = EMPTY;
	if(templateString)
	{
		formatted = templateString;
		// The replacer function inserts each value as it is. A plain-string replacement would read $ patterns inside a
		// value, such as $& or $$, as instructions, and differ from the Apex String.format() behaviour this helper mirrors.
		substitutes.forEach((value, index) =>
		{
			formatted = formatted.replaceAll(`{${index}}`, () => String(value));
		});
	}
	return formatted;
}

/**
 * @description Converts a string to sentence case: the first letter of each sentence is capitalized,
 * all other characters are lowered. Sentence boundaries are detected by `.`, `!`, or `?`.
 *
 * @param {string} text - Mixed-case input
 * @returns {string} Sentence-cased output
 */
export function convertToSentenceCase(text)
{
	const sentenceStart = /(^\s*\w|[.!?]\s*\w)/g;
	return text.toLowerCase().replace(sentenceStart, (match) => match.toUpperCase());
}

/**
 * @description Inserts a separator character at every `n`-th position within a string.
 * Useful for formatting card numbers, serial keys, etc.
 *
 * @param {string} source - The string to modify
 * @param {number|string} interval - Insert separator every `interval` characters. A string of digits counts as its
 * number. Any other value, or a number below 1 or with a fraction, returns the source as it was given
 * @param {string} [separator=' '] - Character to insert (defaults to a space)
 * @returns {string} The formatted string
 */
export function insertCharacterAtInterval(source, interval, separator = SPACE)
{
	// The interval is built into the pattern, so only a whole number may reach it.
	// The replacer function inserts the separator as it is. A plain-string replacement would read $ patterns inside it,
	// such as $& or the numbered group $1, as instructions.
	const chunkLength = typeof interval === 'number' || (typeof interval === 'string' && /^\d+$/.test(interval)) ? Number(interval) : Number.NaN;
	let formatted = source;
	if(Number.isInteger(chunkLength) && chunkLength >= 1)
	{
		const chunkPattern = new RegExp(`(.{${chunkLength}})(?!$)`, 'g');
		formatted = source.replace(chunkPattern, (chunk) => `${chunk}${separator}`);
	}
	return formatted;
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
	const thousandsBoundary = /(\d)(?=(\d{3})+(?!\d))/g;
	return `${currencySymbol} ${numberString.replace(thousandsBoundary, '$1 ')}`;
}