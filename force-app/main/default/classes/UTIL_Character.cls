// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Provides utility methods for character manipulation, including whitespace detection and ASCII conversion.
 *
 * @see UTIL_Character_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.NcssMethodCount')
public inherited sharing class UTIL_Character
{
	/**
	 * @description Converts an ASCII value to its corresponding character.
	 *
	 * @param asciiValue The ASCII value to convert (0-127).
	 *
	 * @return String The character corresponding to the ASCII value, or null if not found.
	 *
	 * @example
	 * ```apex
	 * String charValue = UTIL_Character.toChar(65);
	 * System.debug(charValue); // Outputs: A
	 * ```
	 */
	public static String toChar(Integer asciiValue)
	{
		return asciiToCharacterMap.get(asciiValue);
	}

	/**
	 * @description Determines if a character is a Java whitespace character.
	 *
	 * @param inputChar The character to test.
	 *
	 * @return Boolean True if the character is a whitespace character (space, tab, newline, etc.), false otherwise.
	 *
	 * @throws IllegalArgumentException If the input is not a single character.
	 *
	 * @example
	 * ```apex
	 * Boolean isWhitespace = UTIL_Character.isWhitespace(' ');
	 * System.debug(isWhitespace); // Outputs: true
	 * ```
	 */
	public static Boolean isWhitespace(String inputChar)
	{
		validateChar(inputChar);
		return ' '.equals(inputChar)
				|| '\n'.equals(inputChar)
				|| '\t'.equals(inputChar)
				|| '\f'.equals(inputChar)
				|| '\r'.equals(inputChar);
	}

	/**
	 * @description Validates that the input is a single character.
	 *
	 * @param inputChar The character to validate.
	 *
	 * @throws IllegalArgumentException If the input is null or not a single character.
	 *
	 * @example
	 * ```apex
	 * try
	 * {
	 * 	UTIL_Character.validateChar('ab');
	 * }
	 * catch(IllegalArgumentException e)
	 * {
	 * 	System.debug('Invalid input: ' + e.getMessage());
	 * }
	 * ```
	 */
	public static void validateChar(String inputChar)
	{
		if(inputChar != null && inputChar.length() != 1)
		{
			throw new IllegalArgumentException('Invalid character string: ' + inputChar);
		}
	}

	/**
	 * @description Maps characters to their ASCII values (0-127).
	 */
	private static final Map<String, Integer> characterToAsciiMap
	{
		get
		{
			if(characterToAsciiMap == null)
			{
				characterToAsciiMap = new Map<String, Integer>();

				characterToAsciiMap.put(null, 0);
				characterToAsciiMap.put('\t', 9);
				characterToAsciiMap.put('\n', 10);
				characterToAsciiMap.put('\f', 12);
				characterToAsciiMap.put('\r', 13);
				characterToAsciiMap.put(' ', 32);
				characterToAsciiMap.put('!', 33);
				characterToAsciiMap.put('"', 34);
				characterToAsciiMap.put('#', 35);
				characterToAsciiMap.put('$', 36);
				characterToAsciiMap.put('%', 37);
				characterToAsciiMap.put('&', 38);
				characterToAsciiMap.put('\'', 39);
				characterToAsciiMap.put('(', 40);
				characterToAsciiMap.put(')', 41);
				characterToAsciiMap.put('*', 42);
				characterToAsciiMap.put('+', 43);
				characterToAsciiMap.put(',', 44);
				characterToAsciiMap.put('-', 45);
				characterToAsciiMap.put('.', 46);
				characterToAsciiMap.put('/', 47);
				characterToAsciiMap.put('0', 48);
				characterToAsciiMap.put('1', 49);
				characterToAsciiMap.put('2', 50);
				characterToAsciiMap.put('3', 51);
				characterToAsciiMap.put('4', 52);
				characterToAsciiMap.put('5', 53);
				characterToAsciiMap.put('6', 54);
				characterToAsciiMap.put('7', 55);
				characterToAsciiMap.put('8', 56);
				characterToAsciiMap.put('9', 57);
				characterToAsciiMap.put(':', 58);
				characterToAsciiMap.put(';', 59);
				characterToAsciiMap.put('<', 60);
				characterToAsciiMap.put('=', 61);
				characterToAsciiMap.put('>', 62);
				characterToAsciiMap.put('?', 63);
				characterToAsciiMap.put('@', 64);
				characterToAsciiMap.put('A', 65);
				characterToAsciiMap.put('B', 66);
				characterToAsciiMap.put('C', 67);
				characterToAsciiMap.put('D', 68);
				characterToAsciiMap.put('E', 69);
				characterToAsciiMap.put('F', 70);
				characterToAsciiMap.put('G', 71);
				characterToAsciiMap.put('H', 72);
				characterToAsciiMap.put('I', 73);
				characterToAsciiMap.put('J', 74);
				characterToAsciiMap.put('K', 75);
				characterToAsciiMap.put('L', 76);
				characterToAsciiMap.put('M', 77);
				characterToAsciiMap.put('N', 78);
				characterToAsciiMap.put('O', 79);
				characterToAsciiMap.put('P', 80);
				characterToAsciiMap.put('Q', 81);
				characterToAsciiMap.put('R', 82);
				characterToAsciiMap.put('S', 83);
				characterToAsciiMap.put('T', 84);
				characterToAsciiMap.put('U', 85);
				characterToAsciiMap.put('V', 86);
				characterToAsciiMap.put('W', 87);
				characterToAsciiMap.put('X', 88);
				characterToAsciiMap.put('Y', 89);
				characterToAsciiMap.put('Z', 90);
				characterToAsciiMap.put('[', 91);
				characterToAsciiMap.put('\\', 92);
				characterToAsciiMap.put(']', 93);
				characterToAsciiMap.put('^', 94);
				characterToAsciiMap.put('_', 95);
				characterToAsciiMap.put('`', 96);
				characterToAsciiMap.put('a', 97);
				characterToAsciiMap.put('b', 98);
				characterToAsciiMap.put('c', 99);
				characterToAsciiMap.put('d', 100);
				characterToAsciiMap.put('e', 101);
				characterToAsciiMap.put('f', 102);
				characterToAsciiMap.put('g', 103);
				characterToAsciiMap.put('h', 104);
				characterToAsciiMap.put('i', 105);
				characterToAsciiMap.put('j', 106);
				characterToAsciiMap.put('k', 107);
				characterToAsciiMap.put('l', 108);
				characterToAsciiMap.put('m', 109);
				characterToAsciiMap.put('n', 110);
				characterToAsciiMap.put('o', 111);
				characterToAsciiMap.put('p', 112);
				characterToAsciiMap.put('q', 113);
				characterToAsciiMap.put('r', 114);
				characterToAsciiMap.put('s', 115);
				characterToAsciiMap.put('t', 116);
				characterToAsciiMap.put('u', 117);
				characterToAsciiMap.put('v', 118);
				characterToAsciiMap.put('w', 119);
				characterToAsciiMap.put('x', 120);
				characterToAsciiMap.put('y', 121);
				characterToAsciiMap.put('z', 122);
				characterToAsciiMap.put('{', 123);
				characterToAsciiMap.put('|', 124);
				characterToAsciiMap.put('}', 125);
				characterToAsciiMap.put('~', 126);
			}
			return characterToAsciiMap;
		}
		set;
	}

	/**
	 * @description Maps ASCII values to their corresponding characters.
	 */
	private static final Map<Integer, String> asciiToCharacterMap
	{
		get
		{
			if(asciiToCharacterMap == null)
			{
				asciiToCharacterMap = new Map<Integer, String>();
				for(String charKey : characterToAsciiMap.keySet())
				{
					asciiToCharacterMap.put(characterToAsciiMap.get(charKey), charKey);
				}
			}
			return asciiToCharacterMap;
		}
		set;
	}
}