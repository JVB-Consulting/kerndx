// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A LWC component for displaying JSON with syntax highlighting.
 *
 * @author Jason van Beukering
 *
 * @date February 2020, February 2026
 */

import {api, LightningElement} from 'lwc';

// ── Constants ────────────────────────────────────────────────────────────

/**
 * @description Regex pattern matching JSON tokens: strings, keys, booleans, nulls, and numbers.
 */
const JSON_TOKEN_PATTERN = /("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+-]?\d+)?)/g;

// ── Helpers ──────────────────────────────────────────────────────────────

/**
 * @description Escapes HTML special characters to prevent XSS when injecting into innerHTML.
 *
 * @param {string} text - Raw text to sanitize.
 * @returns {string} HTML-escaped text.
 */
function sanitizeHtml(text)
{
	return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

/**
 * @description Determines the CSS class name for a JSON token based on its type.
 *
 * @param {string} token - The matched JSON token string.
 * @returns {string} CSS class name: 'key', 'string', 'boolean', 'null', or 'number'.
 */
function getTokenClassName(token)
{
	if(/^"/.test(token))
	{
		return /:$/.test(token) ? 'key' : 'string';
	}
	if(/true|false/.test(token))
	{
		return 'boolean';
	}
	if(/null/.test(token))
	{
		return 'null';
	}
	return 'number';
}

// ── Component ────────────────────────────────────────────────────────────

// eslint-disable-next-line kerndx/use-component-builder -- framework component extends LightningElement directly (no ComponentBuilder wrapper needed for this layer)
export default class JsonViewer extends LightningElement
{
	// ── Internal State ───────────────────────────────────────────────────

	/** @description HTML-highlighted JSON output for display. */
	renderedText;

	/** @description Backing field for the raw JSON string. */
	_jsonText;

	// ── @api Properties ──────────────────────────────────────────────────

	/** @description Raw JSON string to render. */
	@api get jsonText()
	{
		return this._jsonText;
	}

	set jsonText(value)
	{
		this._jsonText = value;

		try
		{
			this.renderedText = this.highlightJSONSyntax(value);
		}
		catch
		{
			this.renderedText = value ? sanitizeHtml(value) : '';
		}

		this.updateDisplay();
	}

	// ── Lifecycle ────────────────────────────────────────────────────────

	renderedCallback()
	{
		this.updateDisplay();
	}

	// ── Internal Helpers ─────────────────────────────────────────────────

	/**
	 * @description Updates the DOM container with the rendered HTML content.
	 */
	updateDisplay()
	{
		const container = this.template.querySelector('.renderedElement');

		if(container)
		{
			// eslint-disable-next-line @lwc/lwc/no-inner-html -- clear container before re-rendering syntax-highlighted JSON
			container.innerHTML = '';
			// eslint-disable-next-line @lwc/lwc/no-inner-html -- inject pre-sanitized syntax-highlighted JSON markup
			container.insertAdjacentHTML('afterbegin', this.renderedText);
		}
	}

	/**
	 * @description Parses and syntax-highlights JSON input by wrapping tokens in span elements.
	 *
	 * @param {string} inputJSON - Raw JSON string to highlight.
	 * @returns {string} HTML string with syntax-highlighted tokens.
	 */
	highlightJSONSyntax(inputJSON)
	{
		const parsed = JSON.parse(inputJSON);
		const formatted = JSON.stringify(parsed, undefined, 4);
		const escaped = sanitizeHtml(formatted);
		return escaped.replace(JSON_TOKEN_PATTERN, (token) =>
		{
			const tokenClassName = getTokenClassName(token);
			return `<span class="${tokenClassName}">${token}</span>`;
		});
	}
}