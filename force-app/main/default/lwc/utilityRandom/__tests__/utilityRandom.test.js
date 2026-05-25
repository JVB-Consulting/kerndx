// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for utilityRandom LWC utility module
 *
 * @author Jason van Beukering
 *
 * @date December 2025, May 2026
 */

// Mock utilityString constants
jest.mock('c/utilityString', () =>
{
	return {
		__esModule: true, CAPITAL_LETTERS: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', LOWER_CASE_LETTERS: 'abcdefghijklmnopqrstuvwxyz', DIGITS: '0123456789'
	};
}, {virtual: true});

import {getRandomNumericString, getRandomAlphaString, getRandomAlphaNumericString, generateUUID} from 'c/utilityRandom';

describe('getRandomNumericString', () =>
{
	it('should return string of specified length', () =>
	{
		const result = getRandomNumericString(10);
		expect(result).toHaveLength(10);
	});

	it('should contain only digits', () =>
	{
		const result = getRandomNumericString(100);
		expect(result).toMatch(/^[0-9]+$/);
	});

	it('should return empty string for length 0', () =>
	{
		const result = getRandomNumericString(0);
		expect(result).toBe('');
	});

	it('should return different values on subsequent calls', () =>
	{
		const results = new Set();
		for(let i = 0; i < 10; i++)
		{
			results.add(getRandomNumericString(20));
		}
		// With 20 digit strings, collisions are extremely unlikely
		expect(results.size).toBeGreaterThan(1);
	});
});

describe('getRandomAlphaString', () =>
{
	describe('case sensitive (default)', () =>
	{
		it('should return string of specified length', () =>
		{
			const result = getRandomAlphaString(15);
			expect(result).toHaveLength(15);
		});

		it('should contain only letters', () =>
		{
			const result = getRandomAlphaString(100);
			expect(result).toMatch(/^[a-zA-Z]+$/);
		});

		it('should contain mix of upper and lower case', () =>
		{
			// Generate long string to increase probability of both cases
			const result = getRandomAlphaString(200);
			expect(result).toMatch(/[a-z]/);
			expect(result).toMatch(/[A-Z]/);
		});
	});

	describe('case-insensitive - lowercase only', () =>
	{
		it('should contain only lowercase letters', () =>
		{
			const result = getRandomAlphaString(100, false, true);
			expect(result).toMatch(/^[a-z]+$/);
		});
	});

	describe('case-insensitive - uppercase only', () =>
	{
		it('should contain only uppercase letters', () =>
		{
			const result = getRandomAlphaString(100, false, false);
			expect(result).toMatch(/^[A-Z]+$/);
		});
	});

	it('should return empty string for length 0', () =>
	{
		const result = getRandomAlphaString(0);
		expect(result).toBe('');
	});
});

describe('getRandomAlphaNumericString', () =>
{
	describe('case sensitive (default)', () =>
	{
		it('should return string of specified length', () =>
		{
			const result = getRandomAlphaNumericString(20);
			expect(result).toHaveLength(20);
		});

		it('should contain only alphanumeric characters', () =>
		{
			const result = getRandomAlphaNumericString(100);
			expect(result).toMatch(/^[a-zA-Z0-9]+$/);
		});

		it('should contain letters and digits', () =>
		{
			// Generate long string to increase probability of all character types
			const result = getRandomAlphaNumericString(500);
			expect(result).toMatch(/[a-zA-Z]/);
			expect(result).toMatch(/[0-9]/);
		});
	});

	describe('case-insensitive - lowercase only', () =>
	{
		it('should contain only lowercase letters and digits', () =>
		{
			const result = getRandomAlphaNumericString(100, false, true);
			expect(result).toMatch(/^[a-z0-9]+$/);
		});
	});

	describe('case-insensitive - uppercase only', () =>
	{
		it('should contain only uppercase letters and digits', () =>
		{
			const result = getRandomAlphaNumericString(100, false, false);
			expect(result).toMatch(/^[A-Z0-9]+$/);
		});
	});

	it('should return empty string for length 0', () =>
	{
		const result = getRandomAlphaNumericString(0);
		expect(result).toBe('');
	});
});

describe('generateUUID', () =>
{
	// Store original crypto state
	let originalCrypto;
	let originalRandomUUID;

	beforeEach(() =>
	{
		// Capture current state before each test
		originalCrypto = global.crypto;
		originalRandomUUID = global.crypto?.randomUUID;
	});

	afterEach(() =>
	{
		// Restore original crypto state after each test
		global.crypto = originalCrypto;
		if(global.crypto)
		{
			if(originalRandomUUID)
			{
				global.crypto.randomUUID = originalRandomUUID;
			}
			else
			{
				delete global.crypto.randomUUID;
			}
		}
	});

	describe('with native crypto.randomUUID', () =>
	{
		it('should use native randomUUID when available', () =>
		{
			// Add randomUUID to existing crypto object (jsdom has crypto but not randomUUID)
			const mockUUID = '550e8400-e29b-41d4-a716-446655440000';
			if(!global.crypto)
			{
				/** @type {*} */
				global.crypto = {};
			}
			global.crypto.randomUUID = () => mockUUID;

			const result = generateUUID();
			expect(result).toBe(mockUUID);
		});
	});

	describe('fallback implementation', () =>
	{
		beforeEach(() =>
		{
			// Remove crypto.randomUUID to test fallback
			if(global.crypto)
			{
				delete global.crypto.randomUUID;
			}
		});

		it('should return valid UUID v4 format', () =>
		{
			const result = generateUUID();
			// UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
			const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
			expect(result).toMatch(uuidRegex);
		});

		it('should have version 4 indicator', () =>
		{
			const result = generateUUID();
			// The 13th character (position 14 in string with dashes) should be '4'
			expect(result.charAt(14)).toBe('4');
		});

		it('should have correct variant bits', () =>
		{
			const result = generateUUID();
			// The 17th character (position 19 in string with dashes) should be 8, 9, a, or b
			expect(result.charAt(19)).toMatch(/[89ab]/);
		});

		it('should generate unique UUIDs', () =>
		{
			const uuids = new Set();
			for(let i = 0; i < 100; i++)
			{
				uuids.add(generateUUID());
			}
			expect(uuids.size).toBe(100);
		});

		it('should return correct length', () =>
		{
			const result = generateUUID();
			expect(result).toHaveLength(36); // 32 hex chars + 4 dashes
		});
	});

	describe('when crypto is undefined', () =>
	{
		it('should use fallback when crypto is undefined', () =>
		{
			global.crypto = undefined;

			const result = generateUUID();
			const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
			expect(result).toMatch(uuidRegex);
		});
	});
});
