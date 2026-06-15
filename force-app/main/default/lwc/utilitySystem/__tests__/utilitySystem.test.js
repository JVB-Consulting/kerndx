// SPDX-License-Identifier: BUSL-1.1
// @ts-nocheck
/**
 * @description Jest unit tests for utilitySystem LWC utility module
 *
 * @author Jason van Beukering
 *
 * @date December 2025, June 2026
 */
import {reduceErrors, sortBy, copyToClipBoard, flattenObject, setPropertyOnObject} from 'c/utilitySystem';

// Mock utilityLogger to prevent import errors. Resolve the module reference at the same static
// point as c/utilitySystem imports it — keeps the mock instance consistent across test files that
// may call jest.resetModules between suites.
jest.mock('c/utilityLogger', () =>
{
	return {
		__esModule: true, default: {
			debug: jest.fn(), info: jest.fn(), warn: jest.fn(), error: jest.fn()
		}
	};
}, {virtual: true});

import utilityLogger from 'c/utilityLogger';

describe('reduceErrors', () =>
{
	describe('string errors', () =>
	{
		it('should handle a single string error', () =>
		{
			// @ts-ignore - testing string input
			const result = reduceErrors('Something went wrong');
			expect(result).toBe('Something went wrong');
		});

		it('should handle an array of string errors', () =>
		{
			// noinspection JSValidateTypes
			const result = reduceErrors([
				'Error 1',
				'Error 2',
				'Error 3'
			]);
			expect(result).toBe('Error 1 // Error 2 // Error 3');
		});

		it('should filter out empty strings', () =>
		{
			// @ts-ignore - testing array with empty strings
			const result = reduceErrors([
				'Error 1',
				'',
				'Error 2'
			]);
			expect(result).toBe('Error 1 // Error 2');
		});
	});

	describe('JavaScript Error objects', () =>
	{
		it('should extract message from Error object', () =>
		{
			const error = new Error('JS Error occurred');
			const result = reduceErrors(error);
			expect(result).toBe('JS Error occurred');
		});

		it('should handle array of Error objects', () =>
		{
			const errors = [
				new Error('Error A'),
				new Error('Error B')
			];
			const result = reduceErrors(errors);
			expect(result).toBe('Error A // Error B');
		});
	});

	describe('LDS/FetchResponse errors', () =>
	{
		it('should handle body with message property', () =>
		{
			const error = {
				body: {message: 'Apex error message'}
			};
			const result = reduceErrors(error);
			expect(result).toBe('Apex error message');
		});

		it('should handle body as array of error details', () =>
		{
			const error = {
				body: [
					{message: 'Field error 1'},
					{message: 'Field error 2'}
				]
			};
			const result = reduceErrors(error);
			expect(result).toBe('Field error 1,Field error 2');
		});

		it('should handle duplicateResults errors', () =>
		{
			const error = {
				body: {
					duplicateResults: [
						{message: 'Duplicate 1'},
						{message: 'Duplicate 2'}
					]
				}
			};
			const result = reduceErrors(error);
			expect(result).toBe('Duplicate 1,Duplicate 2');
		});

		it('shouldReduceLegacyArrayFieldErrors', () =>
		{
			// Legacy callers may pass body.fieldErrors as an Array (pre-LDS shape).
			// The Array branch must continue to fire for these callers.
			const error = {
				body: {
					fieldErrors: [
						{message: 'Field A is required'},
						{message: 'Field B is invalid'}
					]
				}
			};
			const result = reduceErrors(error);
			expect(result).toBe('Field A is required,Field B is invalid');
		});

		it('shouldReduceObjectKeyedFieldErrors', () =>
		{
			// LDS shape: body.fieldErrors is an Object keyed by field API name, values are Array<{message}>.
			const error = {
				body: {
					fieldErrors: {Name: [{message: 'Required'}]}
				}
			};
			const result = reduceErrors(error);
			expect(result).toBe('Required');
		});

		it('shouldJoinMultipleObjectKeyedFieldErrorMessages', () =>
		{
			// Multiple messages within one field — flatten across Object.values.
			const error = {
				body: {
					fieldErrors: {
						Name: [
							{message: 'Required'},
							{message: 'TooLong'}
						], Industry: [{message: 'BadValue'}]
					}
				}
			};
			const result = reduceErrors(error);
			expect(result).toBe('Required,TooLong,BadValue');
		});

		it('shouldFallThroughWhenObjectFieldErrorsEmpty', () =>
		{
			// Empty fieldErrors{} must NOT short-circuit — fall through to body.message.
			const error = {
				body: {fieldErrors: {}, message: 'fallthrough'}
			};
			const result = reduceErrors(error);
			expect(result).toBe('fallthrough');
		});

		it('shouldReduceUiApiOutputErrors', () =>
		{
			// UI API shape: body.output.errors[].
			const error = {
				body: {output: {errors: [{message: 'UIErr'}]}}
			};
			const result = reduceErrors(error);
			expect(result).toBe('UIErr');
		});

		it('shouldReduceUiApiOutputFieldErrors', () =>
		{
			// UI API shape: body.output.fieldErrors{} (Object-keyed).
			const error = {
				body: {
					output: {
						fieldErrors: {Industry: [{message: 'Bad value'}]}
					}
				}
			};
			const result = reduceErrors(error);
			expect(result).toBe('Bad value');
		});

		it('shouldFallThroughWhenOutputFieldErrorsEmpty', () =>
		{
			// Empty output.fieldErrors{} must NOT short-circuit — fall through to body.message.
			const error = {
				body: {output: {fieldErrors: {}}, message: 'fallthrough'}
			};
			const result = reduceErrors(error);
			expect(result).toBe('fallthrough');
		});

		it('should handle pageErrors', () =>
		{
			const error = {
				body: {
					pageErrors: [
						{message: 'Page error 1'},
						{message: 'Page error 2'}
					]
				}
			};
			const result = reduceErrors(error);
			expect(result).toBe('Page error 1,Page error 2');
		});

		it('should handle HTTP status with statusText', () =>
		{
			const error = {
				status: 404, statusText: 'Not Found'
			};
			const result = reduceErrors(error);
			expect(result).toBe('404 - Not Found');
		});

		it('should handle statusText only', () =>
		{
			const error = {statusText: 'Internal Server Error'};
			const result = reduceErrors(error);
			expect(result).toBe('Internal Server Error');
		});

		it('should handle status only', () =>
		{
			const error = {status: 500};
			const result = reduceErrors(error);
			expect(result).toBe('500');
		});

		it('falls back to outer message when body is an object with no recognised shape', () =>
		{
			// body is truthy but not an array, has no duplicateResults/fieldErrors/
			// pageErrors collections, and has no string message. The outer message
			// is used as the fallback. Exercises the `if(typeof message === 'string')`
			// branch inside extractBodyMessages.
			const error = {body: {debugInfo: 'something'}, message: 'outer fallback message'};
			const result = reduceErrors(error);
			expect(result).toBe('outer fallback message');
		});

		it('returns empty string for an object with no body, status, statusText or message', () =>
		{
			// extractMessage returns undefined and the .filter(msg => msg !== undefined)
			// strips the entry, leaving an empty join. Exercises line 113 `return undefined`.
			const result = reduceErrors([{}]);
			expect(result).toBe('');
		});

		it('returns empty string when body is an unrecognised object and no outer message', () =>
		{
			// body is truthy but not an array, has no recognised collections, no body
			// .message, and the outer error has no message either. extractBodyMessages
			// reaches the final `return undefined` (line 74) and extractMessage
			// returns that undefined, which the filter strips.
			const result = reduceErrors({body: {debugInfo: 'nothing useful'}});
			expect(result).toBe('');
		});
	});

	describe('edge cases', () =>
	{
		it('should handle null values in array', () =>
		{
			// @ts-ignore - testing null values in array
			const result = reduceErrors([
				null,
				'Valid error',
				null
			]);
			expect(result).toBe('Valid error');
		});

		it('should handle undefined values in array', () =>
		{
			// @ts-ignore - testing undefined values in array
			const result = reduceErrors([
				undefined,
				'Valid error',
				undefined
			]);
			expect(result).toBe('Valid error');
		});

		it('should handle empty array', () =>
		{
			const result = reduceErrors([]);
			expect(result).toBe('');
		});

		it('should handle mixed error types', () =>
		{
			const errors = [
				'String error',
				new Error('JS Error'),
				{body: {message: 'Apex error'}}
			];
			// @ts-ignore - testing mixed error types
			const result = reduceErrors(errors);
			expect(result).toBe('String error // JS Error // Apex error');
		});
	});
});

describe('sortBy', () =>
{
	describe('string sorting', () =>
	{
		it('should sort strings ascending by default', () =>
		{
			const data = [
				{name: 'Charlie'},
				{name: 'Alice'},
				{name: 'Bob'}
			];
			const sorted = [...data].sort(sortBy('name'));
			expect(sorted.map(item => item.name)).toEqual([
				'Alice',
				'Bob',
				'Charlie'
			]);
		});

		it('should sort strings descending with reverse=-1', () =>
		{
			const data = [
				{name: 'Charlie'},
				{name: 'Alice'},
				{name: 'Bob'}
			];
			const sorted = [...data].sort(sortBy('name', -1));
			expect(sorted.map(item => item.name)).toEqual([
				'Charlie',
				'Bob',
				'Alice'
			]);
		});
	});

	describe('number sorting', () =>
	{
		it('should sort numbers ascending', () =>
		{
			const ten = 10;
			const twenty = 20;
			const thirty = 30;
			const data = [
				{value: thirty},
				{value: ten},
				{value: twenty}
			];
			const sorted = [...data].sort(sortBy('value'));
			expect(sorted.map(item => item.value)).toEqual([
				ten,
				twenty,
				thirty
			]);
		});

		it('should sort numbers descending', () =>
		{
			const ten = 10;
			const twenty = 20;
			const thirty = 30;
			const data = [
				{value: thirty},
				{value: ten},
				{value: twenty}
			];
			const sorted = [...data].sort(sortBy('value', -1));
			expect(sorted.map(item => item.value)).toEqual([
				thirty,
				twenty,
				ten
			]);
		});
	});

	describe('with primer function', () =>
	{
		it('should apply primer before comparison', () =>
		{
			const data = [
				{name: 'charlie'},
				{name: 'ALICE'},
				{name: 'Bob'}
			];
			const toUpperCase = value => value.toUpperCase();
			const sorted = [...data].sort(sortBy('name', 1, toUpperCase));
			expect(sorted.map(item => item.name)).toEqual([
				'ALICE',
				'Bob',
				'charlie'
			]);
		});

		it('should work with numeric primer', () =>
		{
			const data = [
				{price: '$30'},
				{price: '$10'},
				{price: '$20'}
			];
			const parsePrice = value => parseInt(value.replace('$', ''), 10);
			const sorted = [...data].sort(sortBy('price', 1, parsePrice));
			expect(sorted.map(item => item.price)).toEqual([
				'$10',
				'$20',
				'$30'
			]);
		});
	});

	describe('edge cases', () =>
	{
		it('should handle equal values', () =>
		{
			const data = [
				{name: 'Alice', id: 1},
				{name: 'Alice', id: 2},
				{name: 'Alice', id: 3}
			];
			const sorted = [...data].sort(sortBy('name'));
			expect(sorted.length).toBe(3);
		});

		it('should handle empty array', () =>
		{
			const data = [];
			const sorted = [...data].sort(sortBy('name'));
			expect(sorted).toEqual([]);
		});
	});
});

describe('flattenObject', () =>
{
	describe('basic flattening', () =>
	{
		it('should return flat object unchanged', () =>
		{
			const input = {a: 1, b: 2, c: 3};
			const result = flattenObject(input);
			expect(result).toEqual({a: 1, b: 2, c: 3});
		});

		it('should flatten single level nesting', () =>
		{
			const input = {
				a: 1, nested: {b: 2, c: 3}
			};
			const result = flattenObject(input);
			expect(result).toEqual({
				a: 1, 'nested.b': 2, 'nested.c': 3
			});
		});

		it('should flatten deep nesting', () =>
		{
			const input = {
				level1: {
					level2: {
						level3: {
							value: 'deep'
						}
					}
				}
			};
			const result = flattenObject(input);
			expect(result).toEqual({
				'level1.level2.level3.value': 'deep'
			});
		});
	});

	describe('array handling', () =>
	{
		it('should preserve arrays without flattening', () =>
		{
			const input = {
				items: [
					1,
					2,
					3
				], nested: {
					values: [
						4,
						5,
						6
					]
				}
			};
			const result = flattenObject(input);
			expect(result).toEqual({
				items: [
					1,
					2,
					3
				], 'nested.values': [
					4,
					5,
					6
				]
			});
		});
	});

	describe('null and undefined handling', () =>
	{
		it('should handle null property values without throwing', () =>
		{
			const input = {
				validKey: 'value', nullKey: null
			};
			expect(() => flattenObject(input)).not.toThrow();
			const result = flattenObject(input);
			expect(result).toEqual({
				validKey: 'value', nullKey: null
			});
		});

		it('should handle undefined property values', () =>
		{
			const input = {
				validKey: 'value', undefinedKey: undefined
			};
			const result = flattenObject(input);
			expect(result.validKey).toBe('value');
			expect(result.undefinedKey).toBeUndefined();
		});

		it('should handle mixed null values in nested objects', () =>
		{
			const input = {
				nested: {
					valid: 'value', nullProp: null
				}
			};
			expect(() => flattenObject(input)).not.toThrow();
			const result = flattenObject(input);
			expect(result).toEqual({
				'nested.valid': 'value', 'nested.nullProp': null
			});
		});

		it('should return empty object when input is null or undefined', () =>
		{
			expect(flattenObject(null)).toEqual({});
			expect(flattenObject(undefined)).toEqual({});
		});
	});

	describe('edge cases', () =>
	{
		it('should handle empty object', () =>
		{
			const result = flattenObject({});
			expect(result).toEqual({});
		});

		it('should handle object with various primitive types', () =>
		{
			const input = {
				string: 'hello', number: 42, boolean: true, nested: {
					string: 'world', number: 100
				}
			};
			const result = flattenObject(input);
			expect(result).toEqual({
				string: 'hello', number: 42, boolean: true, 'nested.string': 'world', 'nested.number': 100
			});
		});
	});
});

describe('setPropertyOnObject', () =>
{
	it('should set existing property value', () =>
	{
		const obj = {existingKey: 'oldValue'};
		const result = setPropertyOnObject(obj, 'existingKey', 'newValue');
		expect(result.existingKey).toBe('newValue');
	});

	it('should define new property if it does not exist', () =>
	{
		const obj = {};
		/** @type {{newKey?: string}} */
		const result = setPropertyOnObject(obj, 'newKey', 'newValue');
		expect(result.newKey).toBe('newValue');
	});

	it('should return the modified object', () =>
	{
		const obj = {a: 1};
		const result = setPropertyOnObject(obj, 'b', 2);
		expect(result).toBe(obj);
		expect(result).toEqual({a: 1, b: 2});
	});

	it('should set default value to null', () =>
	{
		const obj = {};
		const result = setPropertyOnObject(obj, 'nullKey');
		expect(result.nullKey).toBeNull();
	});

	it('should create writable property by default', () =>
	{
		const obj = {};
		setPropertyOnObject(obj, 'writableKey', 'initial');
		obj.writableKey = 'changed';
		expect(obj.writableKey).toBe('changed');
	});

	it('should create non-writable property when specified', () =>
	{
		const obj = {};
		setPropertyOnObject(obj, 'readOnlyKey', 'fixed', false);
		expect(() =>
		{
			'use strict';
			obj.readOnlyKey = 'changed';
		}).toThrow();
		expect(obj.readOnlyKey).toBe('fixed');
	});
});

describe('copyToClipBoard', () =>
{
	let originalClipboard;
	let originalExecCommand;

	beforeEach(() =>
	{
		// Save original implementations
		originalClipboard = navigator.clipboard;
		// noinspection JSDeprecatedSymbols - testing legacy execCommand fallback path
		originalExecCommand = document.execCommand;

		// Reset mocks
		jest.clearAllMocks();
	});

	afterEach(() =>
	{
		// Restore original implementations
		Object.defineProperty(navigator, 'clipboard', {
			value: originalClipboard, writable: true, configurable: true
		});
		// noinspection JSDeprecatedSymbols - restoring original execCommand
		document.execCommand = originalExecCommand;
	});

	describe('Clipboard API success path', () =>
	{
		it('should use navigator.clipboard.writeText when available', async() =>
		{
			const mockWriteText = jest.fn().mockResolvedValue(undefined);
			Object.defineProperty(navigator, 'clipboard', {
				value: {writeText: mockWriteText}, writable: true, configurable: true
			});

			await copyToClipBoard('test text');

			expect(mockWriteText).toHaveBeenCalledWith('test text');
		});

		it('should not do anything for empty text', async() =>
		{
			const mockWriteText = jest.fn().mockResolvedValue(undefined);
			Object.defineProperty(navigator, 'clipboard', {
				value: {writeText: mockWriteText}, writable: true, configurable: true
			});

			await copyToClipBoard('');

			expect(mockWriteText).not.toHaveBeenCalled();
		});

		it('should not do anything for null/undefined text', async() =>
		{
			const mockWriteText = jest.fn().mockResolvedValue(undefined);
			Object.defineProperty(navigator, 'clipboard', {
				value: {writeText: mockWriteText}, writable: true, configurable: true
			});

			await copyToClipBoard(null);
			await copyToClipBoard(undefined);

			expect(mockWriteText).not.toHaveBeenCalled();
		});
	});

	describe('execCommand fallback path', () =>
	{
		/**
		 * @description Sets up mocks for execCommand fallback testing
		 * @param {boolean} execCommandSuccess - Whether execCommand should succeed
		 */
		const setupExecCommandFallbackMocks = (execCommandSuccess) =>
		{
			// Mock clipboard API to fail
			Object.defineProperty(navigator, 'clipboard', {
				value: {
					writeText: jest.fn().mockRejectedValue(new Error('Clipboard not available'))
				}, writable: true, configurable: true
			});

			// Mock execCommand
			// noinspection JSDeprecatedSymbols
			document.execCommand = jest.fn().mockReturnValue(execCommandSuccess);

			// Mock document.body methods
			const mockInput = {
				setAttribute: jest.fn(), select: jest.fn()
			};
			// @ts-ignore - mock input element for testing
			jest.spyOn(document, 'createElement').mockReturnValue(mockInput);
			// @ts-ignore - simplified mock implementation
			jest.spyOn(document.body, 'appendChild').mockImplementation(() => mockInput);
			// @ts-ignore - simplified mock implementation
			jest.spyOn(document.body, 'removeChild').mockImplementation(() => mockInput);
		};

		it('should fall back to execCommand when clipboard API fails', async() =>
		{
			setupExecCommandFallbackMocks(true);

			await copyToClipBoard('fallback text');

			// noinspection JSDeprecatedSymbols
			expect(document.execCommand).toHaveBeenCalledWith('copy');
			expect(document.body.removeChild).toHaveBeenCalled();
		});

		it('should handle execCommand failure gracefully without throwing', async() =>
		{
			setupExecCommandFallbackMocks(false);

			// Should not throw even when execCommand fails (error is logged internally)
			await expect(copyToClipBoard('failing text')).resolves.not.toThrow();
			// Verify cleanup still happens
			expect(document.body.removeChild).toHaveBeenCalled();
		});

		it('logs an error via utilityLogger.error when execCommand throws', async() =>
		{
			// Clipboard API rejects, so we fall back to execCommand. Make execCommand
			// throw synchronously to exercise the inner catch (line 200) that calls
			// utilityLogger.error. The finally still runs and removes the input.
			Object.defineProperty(navigator, 'clipboard', {
				value: {
					writeText: jest.fn().mockRejectedValue(new Error('Clipboard not available'))
				}, writable: true, configurable: true
			});

			// noinspection JSDeprecatedSymbols
			document.execCommand = jest.fn().mockImplementation(() =>
			{
				throw new Error('execCommand blew up');
			});

			const mockInput = {setAttribute: jest.fn(), select: jest.fn()};
			// @ts-ignore
			jest.spyOn(document, 'createElement').mockReturnValue(mockInput);
			// @ts-ignore
			jest.spyOn(document.body, 'appendChild').mockImplementation(() => mockInput);
			// @ts-ignore
			jest.spyOn(document.body, 'removeChild').mockImplementation(() => mockInput);

			await expect(copyToClipBoard('boom text')).resolves.not.toThrow();

			expect(utilityLogger.error).toHaveBeenCalledWith('Clipboard fallback failed', expect.any(Error));
			expect(document.body.removeChild).toHaveBeenCalled();
		});
	});
});
