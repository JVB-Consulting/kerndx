// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Provides null-safe Boolean evaluation and String-to-Boolean conversion.
 *
 * @see UTIL_Boolean_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
public inherited sharing class UTIL_Boolean
{
	/**
	 * @description Checks if a Boolean value is true, treating null as false.
	 *
	 * @param booleanValue The Boolean value to check.
	 *
	 * @return Boolean True if the input is non-null and true, false otherwise.
	 *
	 * @example
	 * ```apex
	 * Boolean result = UTIL_Boolean.isTrue(true);  // true
	 * Boolean result = UTIL_Boolean.isTrue(null);  // false
	 * ```
	 */
	public static Boolean isTrue(Boolean booleanValue)
	{
		return booleanValue ?? false;
	}

	/**
	 * @description Converts a String to a Boolean, recognizing common true indicators.
	 * Checks for case-insensitive values 'true', 'yes', 'y', or '1' to return true.
	 * All other values, including null and blank strings, return false.
	 *
	 * @param stringValue The String value to convert.
	 *
	 * @return Boolean True if the input matches a recognized true indicator, false otherwise.
	 *
	 * @example
	 * ```apex
	 * Boolean result = UTIL_Boolean.toBoolean('true');  // true
	 * Boolean result = UTIL_Boolean.toBoolean('yes');   // true
	 * Boolean result = UTIL_Boolean.toBoolean('no');    // false
	 * Boolean result = UTIL_Boolean.toBoolean(null);    // false
	 * ```
	 */
	public static Boolean toBoolean(String stringValue)
	{
		if(String.isBlank(stringValue))
		{
			return false;
		}

		return stringValue.equalsIgnoreCase('true') ||
				stringValue.equalsIgnoreCase('yes') ||
				stringValue.equalsIgnoreCase('y') ||
				stringValue.equalsIgnoreCase('1');
	}
}