// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for jsonViewer LWC component
 * @author Jason van Beukering
 * @date December 2025, May 2026
 */

import {createElement} from 'lwc';
import LwcJSONViewer from 'c/jsonViewer';

describe('c-json-viewer', () =>
{
	let element;

	beforeEach(() =>
	{
		jest.clearAllMocks();
	});

	afterEach(() =>
	{
		while(document.body.firstChild)
		{
			document.body.removeChild(document.body.firstChild);
		}
	});

	/**
	 * Helper to create component with JSON and wait for render
	 */
	async function createComponent(jsonText)
	{
		element = createElement('c-json-viewer', {
			is: LwcJSONViewer
		});
		element.jsonText = jsonText;
		document.body.appendChild(element);
		await Promise.resolve();
		return element;
	}

	/**
	 * Helper to check if a span with a specific class contains specific text
	 * This avoids issues with LWC adding internal attributes
	 */
	function hasSpanWithClassAndText(preElement, className, text)
	{
		const spans = preElement.querySelectorAll(`span.${className}`);
		for(const span of spans)
		{
			if(span.textContent === text)
			{
				return true;
			}
		}
		return false;
	}

	describe('initial rendering', () =>
	{
		it('should render component successfully', async() =>
		{
			await createComponent('{"test": "value"}');

			expect(element).toBeTruthy();
		});

		it('should render pre element with renderedElement class', async() =>
		{
			await createComponent('{"test": "value"}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(preElement).toBeTruthy();
			expect(preElement.tagName.toLowerCase()).toBe('pre');
		});

		it('should render JSON content into pre element', async() =>
		{
			await createComponent('{"name": "test"}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(preElement.textContent).toContain('name');
			expect(preElement.textContent).toContain('test');
		});
	});

	describe('JSON syntax highlighting', () =>
	{
		it('should highlight string values with string class', async() =>
		{
			await createComponent('{"key": "stringValue"}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(hasSpanWithClassAndText(preElement, 'string', '"stringValue"')).toBe(true);
		});

		it('should highlight keys with key class', async() =>
		{
			await createComponent('{"myKey": "value"}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(hasSpanWithClassAndText(preElement, 'key', '"myKey":')).toBe(true);
		});

		it('should highlight number values with number class', async() =>
		{
			await createComponent('{"count": 42}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(hasSpanWithClassAndText(preElement, 'number', '42')).toBe(true);
		});

		it('should highlight negative numbers with number class', async() =>
		{
			await createComponent('{"value": -123.45}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(hasSpanWithClassAndText(preElement, 'number', '-123.45')).toBe(true);
		});

		it('should highlight scientific notation with number class', async() =>
		{
			await createComponent('{"value": 1.5e10}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			// JSON.stringify expands scientific notation
			expect(hasSpanWithClassAndText(preElement, 'number', '15000000000')).toBe(true);
		});

		it('should highlight boolean true with boolean class', async() =>
		{
			await createComponent('{"active": true}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(hasSpanWithClassAndText(preElement, 'boolean', 'true')).toBe(true);
		});

		it('should highlight boolean false with boolean class', async() =>
		{
			await createComponent('{"active": false}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(hasSpanWithClassAndText(preElement, 'boolean', 'false')).toBe(true);
		});

		it('should highlight null values with null class', async() =>
		{
			await createComponent('{"empty": null}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(hasSpanWithClassAndText(preElement, 'null', 'null')).toBe(true);
		});

		it('should handle nested objects', async() =>
		{
			await createComponent('{"parent": {"child": "value"}}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(hasSpanWithClassAndText(preElement, 'key', '"parent":')).toBe(true);
			expect(hasSpanWithClassAndText(preElement, 'key', '"child":')).toBe(true);
			expect(hasSpanWithClassAndText(preElement, 'string', '"value"')).toBe(true);
		});

		it('should handle arrays', async() =>
		{
			await createComponent('{"items": [1, 2, 3]}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(hasSpanWithClassAndText(preElement, 'key', '"items":')).toBe(true);
			expect(hasSpanWithClassAndText(preElement, 'number', '1')).toBe(true);
			expect(hasSpanWithClassAndText(preElement, 'number', '2')).toBe(true);
			expect(hasSpanWithClassAndText(preElement, 'number', '3')).toBe(true);
		});

		it('should handle mixed data types', async() =>
		{
			await createComponent('{"str": "text", "num": 100, "bool": true, "nil": null}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(hasSpanWithClassAndText(preElement, 'string', '"text"')).toBe(true);
			expect(hasSpanWithClassAndText(preElement, 'number', '100')).toBe(true);
			expect(hasSpanWithClassAndText(preElement, 'boolean', 'true')).toBe(true);
			expect(hasSpanWithClassAndText(preElement, 'null', 'null')).toBe(true);
		});
	});

	describe('HTML sanitization', () =>
	{
		it('should escape ampersand characters', async() =>
		{
			await createComponent('{"text": "a & b"}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			// The string should contain the escaped ampersand in the text
			expect(preElement.innerHTML).toContain('&amp;');
		});

		it('should escape less-than characters', async() =>
		{
			await createComponent('{"text": "a < b"}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(preElement.innerHTML).toContain('&lt;');
		});

		it('should escape greater-than characters', async() =>
		{
			await createComponent('{"text": "a > b"}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(preElement.innerHTML).toContain('&gt;');
		});
	});

	describe('error handling', () =>
	{
		it('should display raw text when JSON is invalid', async() =>
		{
			await createComponent('not valid json');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(preElement.textContent).toBe('not valid json');
		});

		it('should not wrap invalid JSON in error structure', async() =>
		{
			await createComponent('Hello World');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(preElement.textContent).toBe('Hello World');
			expect(preElement.textContent).not.toContain('error');
		});

		it('should escape HTML in invalid JSON text', async() =>
		{
			await createComponent('<script>alert("xss")</script>');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(preElement.innerHTML).toContain('&lt;script&gt;');
			expect(preElement.innerHTML).not.toContain('<script>');
		});

		it('should handle empty string input', async() =>
		{
			await createComponent('');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(preElement.textContent).toBe('');
		});

		it('should handle undefined input', async() =>
		{
			await createComponent(undefined);

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(preElement.textContent).toBe('');
		});

		it('should handle null input as valid JSON', async() =>
		{
			// JSON.parse(null) is valid and returns null
			await createComponent(null);

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(hasSpanWithClassAndText(preElement, 'null', 'null')).toBe(true);
		});
	});

	describe('special JSON values', () =>
	{
		it('should handle empty object', async() =>
		{
			await createComponent('{}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(preElement.textContent).toContain('{');
			expect(preElement.textContent).toContain('}');
		});

		it('should handle empty array', async() =>
		{
			await createComponent('{"items": []}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(preElement.textContent).toContain('[');
			expect(preElement.textContent).toContain(']');
		});

		it('should handle Unicode escape sequences in keys', async() =>
		{
			await createComponent('{"\\u0041\\u0042": "value"}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			// JSON.parse converts \u0041\u0042 to "AB"
			expect(preElement.textContent).toContain('AB');
		});

		it('should handle escaped characters in strings', async() =>
		{
			await createComponent('{"text": "line1\\nline2"}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(preElement.textContent).toContain('line1');
		});

		it('should handle deeply nested structures', async() =>
		{
			const deepJson = '{"a": {"b": {"c": {"d": "deep"}}}}';
			await createComponent(deepJson);

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(hasSpanWithClassAndText(preElement, 'string', '"deep"')).toBe(true);
		});

		it('should handle array of objects', async() =>
		{
			await createComponent('[{"id": 1}, {"id": 2}]');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(hasSpanWithClassAndText(preElement, 'number', '1')).toBe(true);
			expect(hasSpanWithClassAndText(preElement, 'number', '2')).toBe(true);
		});
	});

	describe('formatting', () =>
	{
		it('should format JSON with indentation', async() =>
		{
			await createComponent('{"a":"b"}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			// JSON.stringify with 4 spaces indentation - check for newlines and spaces
			expect(preElement.textContent).toMatch(/\n/);
		});
	});

	describe('reactivity', () =>
	{
		it('should re-render when jsonText property changes', async() =>
		{
			await createComponent('{"first": "value"}');

			const preElement = element.shadowRoot.querySelector('.renderedElement');
			expect(preElement.textContent).toContain('first');

			element.jsonText = '{"second": "updated"}';
			await Promise.resolve();

			expect(preElement.textContent).toContain('second');
			expect(preElement.textContent).toContain('updated');
			expect(preElement.textContent).not.toContain('first');
		});
	});
});
