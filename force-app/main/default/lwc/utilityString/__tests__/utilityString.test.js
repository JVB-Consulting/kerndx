// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Jest unit tests for utilityString LWC utility module
 *
 * @author Jason van Beukering
 *
 * @date December 2025, May 2026
 */
import {
	formatTemplateString, convertToSentenceCase, insertCharacterAtInterval, formatStringToCurrency, CAPITAL_LETTERS, LOWER_CASE_LETTERS, DIGITS, EMPTY, SPACE, COMMA, SEMI_COLON,
	COLON, NEW_LINE, CRLF, TAB, TILDE
} from 'c/utilityString';

describe('formatTemplateString', () =>
{
	describe('basic substitution', () =>
	{
		it('should replace single placeholder', () =>
		{
			const result = formatTemplateString('Hello {0}!', ['World']);
			expect(result).toBe('Hello World!');
		});

		it('should replace multiple placeholders in order', () =>
		{
			const result = formatTemplateString('{0} {1} {2}', [
				'one',
				'two',
				'three'
			]);
			expect(result).toBe('one two three');
		});

		it('should handle numeric substitutes', () =>
		{
			const result = formatTemplateString('Count: {0}, Total: {1}', [
				42,
				100
			]);
			expect(result).toBe('Count: 42, Total: 100');
		});

		it('should handle mixed string and number substitutes', () =>
		{
			const result = formatTemplateString('{0} has {1} items', [
				'Cart',
				5
			]);
			expect(result).toBe('Cart has 5 items');
		});
	});

	describe('multiple occurrences', () =>
	{
		it('should replace all occurrences of same placeholder', () =>
		{
			const result = formatTemplateString('{0} and {0} again', ['test']);
			expect(result).toBe('test and test again');
		});

		it('should replace multiple placeholders with multiple occurrences', () =>
		{
			const result = formatTemplateString('{0} {1} {0} {1}', [
				'A',
				'B'
			]);
			expect(result).toBe('A B A B');
		});
	});

	describe('edge cases', () =>
	{
		it('should handle empty template string', () =>
		{
			const result = formatTemplateString('', ['value']);
			expect(result).toBe('');
		});

		it('should handle null template string', () =>
		{
			const result = formatTemplateString(null, ['value']);
			expect(result).toBe('');
		});

		it('should handle undefined template string', () =>
		{
			const result = formatTemplateString(undefined, ['value']);
			expect(result).toBe('');
		});

		it('should handle empty substitutes array', () =>
		{
			const result = formatTemplateString('Hello {0}!', []);
			expect(result).toBe('Hello {0}!');
		});

		it('should handle extra substitutes (more values than placeholders)', () =>
		{
			const result = formatTemplateString('{0}', [
				'used',
				'ignored',
				'also ignored'
			]);
			expect(result).toBe('used');
		});

		it('should handle extra placeholders (more placeholders than values)', () =>
		{
			const result = formatTemplateString('{0} {1} {2}', ['only']);
			expect(result).toBe('only {1} {2}');
		});

		it('should handle empty string substitutes', () =>
		{
			const result = formatTemplateString('A{0}B', ['']);
			expect(result).toBe('AB');
		});

		it('should handle template with no placeholders', () =>
		{
			const result = formatTemplateString('No placeholders here', ['unused']);
			expect(result).toBe('No placeholders here');
		});
	});
});

describe('convertToSentenceCase', () =>
{
	describe('basic conversion', () =>
	{
		it('should capitalize first letter of lowercase string', () =>
		{
			const result = convertToSentenceCase('hello world');
			expect(result).toBe('Hello world');
		});

		it('should convert uppercase string to sentence case', () =>
		{
			const result = convertToSentenceCase('HELLO WORLD');
			expect(result).toBe('Hello world');
		});

		it('should convert mixed case string to sentence case', () =>
		{
			const result = convertToSentenceCase('hElLo WoRlD');
			expect(result).toBe('Hello world');
		});
	});

	describe('multiple sentences', () =>
	{
		it('should capitalize after period', () =>
		{
			const result = convertToSentenceCase('FIRST SENTENCE. SECOND SENTENCE.');
			expect(result).toBe('First sentence. Second sentence.');
		});

		it('should capitalize after exclamation mark', () =>
		{
			const result = convertToSentenceCase('WOW! THAT IS GREAT!');
			expect(result).toBe('Wow! That is great!');
		});

		it('should capitalize after question mark', () =>
		{
			const result = convertToSentenceCase('IS THIS CORRECT? YES IT IS.');
			expect(result).toBe('Is this correct? Yes it is.');
		});

		it('should handle multiple punctuation types', () =>
		{
			const result = convertToSentenceCase('HELLO. HOW ARE YOU? GREAT! THANKS.');
			expect(result).toBe('Hello. How are you? Great! Thanks.');
		});
	});

	describe('whitespace handling', () =>
	{
		it('should handle leading whitespace', () =>
		{
			const result = convertToSentenceCase('  HELLO WORLD');
			expect(result).toBe('  Hello world');
		});

		it('should handle multiple spaces after punctuation', () =>
		{
			const result = convertToSentenceCase('FIRST.  SECOND');
			expect(result).toBe('First.  Second');
		});
	});

	describe('edge cases', () =>
	{
		it('should handle single character', () =>
		{
			const result = convertToSentenceCase('a');
			expect(result).toBe('A');
		});

		it('should handle empty string', () =>
		{
			const result = convertToSentenceCase('');
			expect(result).toBe('');
		});
	});
});

describe('insertCharacterAtInterval', () =>
{
	describe('basic insertion', () =>
	{
		it('should insert space at default interval', () =>
		{
			const result = insertCharacterAtInterval('ABCDEF', 2);
			expect(result).toBe('AB CD EF');
		});

		it('should insert custom character at interval', () =>
		{
			const result = insertCharacterAtInterval('ABCDEF', 2, '-');
			expect(result).toBe('AB-CD-EF');
		});

		it('should insert at larger intervals', () =>
		{
			const result = insertCharacterAtInterval('ABCDEFGHIJ', 4, '-');
			expect(result).toBe('ABCD-EFGH-IJ');
		});
	});

	describe('practical examples', () =>
	{
		it('should format credit card number', () =>
		{
			const result = insertCharacterAtInterval('1234567890123456', 4, ' ');
			expect(result).toBe('1234 5678 9012 3456');
		});

		it('should format phone number', () =>
		{
			const result = insertCharacterAtInterval('0123456789', 3, '-');
			expect(result).toBe('012-345-678-9');
		});

		it('should format with dots', () =>
		{
			const result = insertCharacterAtInterval('AABBCCDD', 2, '.');
			expect(result).toBe('AA.BB.CC.DD');
		});
	});

	describe('edge cases', () =>
	{
		it('should not add trailing character', () =>
		{
			const result = insertCharacterAtInterval('ABCD', 2);
			expect(result).toBe('AB CD');
		});

		it('should handle string shorter than interval', () =>
		{
			const result = insertCharacterAtInterval('AB', 4);
			expect(result).toBe('AB');
		});

		it('should handle string equal to interval', () =>
		{
			const result = insertCharacterAtInterval('ABCD', 4);
			expect(result).toBe('ABCD');
		});

		it('should handle empty string', () =>
		{
			const result = insertCharacterAtInterval('', 2);
			expect(result).toBe('');
		});

		it('should handle single character', () =>
		{
			const result = insertCharacterAtInterval('A', 1);
			expect(result).toBe('A');
		});

		it('should handle interval of 1', () =>
		{
			const result = insertCharacterAtInterval('ABC', 1, '-');
			expect(result).toBe('A-B-C');
		});
	});
});

describe('formatStringToCurrency', () =>
{
	describe('basic formatting', () =>
	{
		it('should format simple currency with symbol', () =>
		{
			const result = formatStringToCurrency('100', 'R');
			expect(result).toBe('R 100');
		});

		it('should format thousands with spacing', () =>
		{
			const result = formatStringToCurrency('1000', 'R');
			expect(result).toBe('R 1 000');
		});

		it('should format millions', () =>
		{
			const result = formatStringToCurrency('1000000', 'R');
			expect(result).toBe('R 1 000 000');
		});
	});

	describe('decimal handling', () =>
	{
		it('should handle decimals', () =>
		{
			const result = formatStringToCurrency('1000.50', 'R');
			expect(result).toBe('R 1 000.50');
		});

		it('should handle large numbers with decimals', () =>
		{
			const result = formatStringToCurrency('10000.50', 'R');
			expect(result).toBe('R 10 000.50');
		});
	});

	describe('different currency symbols', () =>
	{
		it('should work with dollar symbol', () =>
		{
			const result = formatStringToCurrency('5000', '$');
			expect(result).toBe('$ 5 000');
		});

		it('should work with euro symbol', () =>
		{
			const result = formatStringToCurrency('2500', '€');
			expect(result).toBe('€ 2 500');
		});

		it('should work with pound symbol', () =>
		{
			const result = formatStringToCurrency('3500', '£');
			expect(result).toBe('£ 3 500');
		});

		it('should work with multi-character symbols', () =>
		{
			const result = formatStringToCurrency('1000', 'USD');
			expect(result).toBe('USD 1 000');
		});
	});

	describe('edge cases', () =>
	{
		it('should handle small numbers', () =>
		{
			const result = formatStringToCurrency('1', 'R');
			expect(result).toBe('R 1');
		});

		it('should handle two-digit numbers', () =>
		{
			const result = formatStringToCurrency('99', 'R');
			expect(result).toBe('R 99');
		});

		it('should handle three-digit numbers', () =>
		{
			const result = formatStringToCurrency('999', 'R');
			expect(result).toBe('R 999');
		});

		it('should handle zero', () =>
		{
			const result = formatStringToCurrency('0', 'R');
			expect(result).toBe('R 0');
		});
	});
});

describe('constants', () =>
{
	describe('alphabetic constants', () =>
	{
		it('should have correct capital letters', () =>
		{
			expect(CAPITAL_LETTERS).toBe('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
			expect(CAPITAL_LETTERS).toHaveLength(26);
		});

		it('should have correct lowercase letters', () =>
		{
			expect(LOWER_CASE_LETTERS).toBe('abcdefghijklmnopqrstuvwxyz');
			expect(LOWER_CASE_LETTERS).toHaveLength(26);
		});

		it('should have correct digits', () =>
		{
			expect(DIGITS).toBe('0123456789');
			expect(DIGITS).toHaveLength(10);
		});
	});

	describe('delimiter constants', () =>
	{
		it('should have correct empty string', () =>
		{
			expect(EMPTY).toBe('');
			expect(EMPTY).toHaveLength(0);
		});

		it('should have correct space', () =>
		{
			expect(SPACE).toBe(' ');
		});

		it('should have correct comma', () =>
		{
			expect(COMMA).toBe(',');
		});

		it('should have correct semi-colon', () =>
		{
			expect(SEMI_COLON).toBe(';');
		});

		it('should have correct colon', () =>
		{
			expect(COLON).toBe(':');
		});

		it('should have correct new line', () =>
		{
			expect(NEW_LINE).toBe('\n');
		});

		it('should have correct CRLF', () =>
		{
			expect(CRLF).toBe('\r\n');
		});

		it('should have correct tab', () =>
		{
			expect(TAB).toBe('\t');
		});

		it('should have correct tilde', () =>
		{
			expect(TILDE).toBe('~');
		});
	});
});
