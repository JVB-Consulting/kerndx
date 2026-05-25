// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Generates random values across multiple data types for testing and development, including numbers, strings, UUIDs, and mock Salesforce IDs.
 *
 * @see UTIL_Random_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * String uuid = UTIL_Random.randomUUID();
 * String email = UTIL_Random.randomEmail();
 * Integer number = UTIL_Random.nextInteger(1, 100);
 * Id mockAccountId = UTIL_Random.randomId(Account.SObjectType);
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessivePublicCount,PMD.AvoidGlobalModifier,PMD.ExcessiveClassLength')
global inherited sharing class UTIL_Random
{
	/**
	 * @description Letter pool containing all upper and lowercase Latin characters for building random strings.
	 */
	private static final String LETTERS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

	/**
	 * @description Digit pool containing characters zero through nine for numeric string generation.
	 */
	private static final String DIGITS = '0123456789';

	/**
	 * @description Start of the printable ASCII range (space character, code point 32).
	 */
	private static final Integer ASCII_PRINTABLE_START = 32;

	/**
	 * @description End of the printable ASCII range (one past tilde, code point 127; used as exclusive upper bound).
	 */
	private static final Integer ASCII_PRINTABLE_END = 127;

	/**
	 * @description Standard whole-number digit count used as the default length parameter for randomDecimal(scale).
	 */
	private static final Integer STANDARD_DECIMAL_LENGTH = 6;

	/**
	 * @description Produces a random boolean by mapping a binary integer result to true or false.
	 *
	 * @return A randomly selected boolean value.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Boolean randomBool = UTIL_Random.nextBoolean();
	 * System.debug(randomBool); // Outputs: true or false
	 * ```
	 */
	global static Boolean nextBoolean()
	{
		final UTIL_NumberRange.IntegerRange coinFlipRange = new UTIL_NumberRange.IntegerRange(0, 1);
		return nextInteger(coinFlipRange) == 1;
	}

	/**
	 * @description Produces a random double from 0 (inclusive) up to but not including 1.
	 *
	 * @return A double in the half-open interval [0, 1).
	 */
	private static Double nextDouble()
	{
		return Math.random();
	}

	/**
	 * @description Produces a random integer from zero up to the given ceiling.
	 *
	 * @param upperBound The maximum value (inclusive).
	 *
	 * @return An integer between 0 and the absolute value of upperBound.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Integer randomInt = UTIL_Random.nextInteger(100);
	 * System.debug(randomInt); // Outputs: e.g., 42
	 * ```
	 */
	global static Integer nextInteger(Integer upperBound)
	{
		return nextInteger(new UTIL_NumberRange.IntegerRange(0, Math.abs(upperBound)));
	}

	/**
	 * @description Produces a random integer between the specified floor and ceiling, both inclusive.
	 *
	 * @param lowerBound The minimum value (inclusive).
	 * @param upperBound The maximum value (inclusive).
	 *
	 * @return An integer within the specified boundaries.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Integer randomInt = UTIL_Random.nextInteger(10, 20);
	 * System.debug(randomInt); // Outputs: e.g., 15
	 * ```
	 */
	global static Integer nextInteger(Integer lowerBound, Integer upperBound)
	{
		return nextInteger(new UTIL_NumberRange.IntegerRange(lowerBound, upperBound));
	}

	// Apex lacks generics, so nextInteger and nextLong cannot share a single implementation despite identical structure.

	/**
	 * @description Core integer generation logic that maps a random double onto the given range with inclusive upper boundary.
	 *
	 * @param range The IntegerRange that defines the lower and upper boundaries.
	 *
	 * @return An integer within the specified range.
	 */
	private static Integer nextInteger(UTIL_NumberRange.IntegerRange range)
	{
		Integer delta = (Integer)(range.max() - range.min());
		if(delta <= 0)
		{
			return range.min();
		}
		return (Integer)(
				Math.round(
						Math.floor(
								nextDouble() * ((Integer)range.max() - (Integer)range.min() + 1)
						)
				) + (Integer)range.min()
		);
	}

	/**
	 * @description Builds a random string of the requested length from the printable ASCII character set (codes 32-126).
	 *
	 * @param length How many characters the result should contain.
	 *
	 * @return A random printable-ASCII string, or an empty string when length is non-positive.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String randomString = UTIL_Random.random(10);
	 * System.debug(randomString); // Outputs: e.g., "Kj#9mP$2vQ"
	 * ```
	 */
	global static String random(Integer length)
	{
		return random(length, 0, 0, false, false, null);
	}

	/**
	 * @description Builds a random string of the requested length using only Latin letters (a-z, A-Z).
	 *
	 * @param length How many characters the result should contain.
	 *
	 * @return A random alphabetic string, or an empty string when length is non-positive.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String randomAlpha = UTIL_Random.randomAlphabetic(6);
	 * System.debug(randomAlpha); // Outputs: e.g., "KjmPqR"
	 * ```
	 */
	global static String randomAlphabetic(Integer length)
	{
		return random(length, 0, 0, true, false, null);
	}

	/**
	 * @description Builds a random string of the requested length using Latin letters and decimal digits (a-z, A-Z, 0-9).
	 *
	 * @param length How many characters the result should contain.
	 *
	 * @return A random alphanumeric string, or an empty string when length is non-positive.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String randomAlphanumeric = UTIL_Random.randomAlphanumeric(8);
	 * System.debug(randomAlphanumeric); // Outputs: e.g., "Kj9mP2vQ"
	 * ```
	 */
	global static String randomAlphanumeric(Integer length)
	{
		return random(length, 0, 0, true, true, null);
	}

	/**
	 * @description Builds a random string of the requested length using only decimal digit characters (0-9).
	 *
	 * @param length How many characters the result should contain.
	 *
	 * @return A random numeric string, or an empty string when length is non-positive.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String randomNum = UTIL_Random.randomNumeric(5);
	 * System.debug(randomNum); // Outputs: e.g., "39281"
	 * ```
	 */
	global static String randomNumeric(Integer length)
	{
		return random(length, 0, 0, false, true, null);
	}

	/**
	 * @description Builds a random string of the requested length by sampling from the supplied character set.
	 *
	 * @param length How many characters the result should contain.
	 * @param characterSet The pool of characters to draw from.
	 *
	 * @return A random string composed of characters from the set, or an empty string when length is non-positive.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String randomCustom = UTIL_Random.random(5, 'ABC');
	 * System.debug(randomCustom); // Outputs: e.g., "ABCCB"
	 * ```
	 */
	global static String random(Integer length, String characterSet)
	{
		return random(length, 0, (characterSet?.length() ?? 0), false, false, characterSet);
	}

	/**
	 * @description Builds a random string of the requested length using either a caller-supplied character pool
	 * or an auto-assembled pool based on composition flags and index boundaries.
	 *
	 * @param length How many characters the result should contain.
	 * @param startIndex The starting position within the character pool.
	 * @param endIndex The ending position within the character pool.
	 * @param includeLetters Whether Latin letters should be added when no explicit pool is given.
	 * @param includeNumbers Whether decimal digits should be added when no explicit pool is given.
	 * @param seedCharacterSet An explicit character pool, or null to auto-assemble one from the flags.
	 *
	 * @return A random string matching the requested composition, or an empty string when length is non-positive.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static String random
			(
					Integer length,
					Integer startIndex,
					Integer endIndex,
					Boolean includeLetters,
					Boolean includeNumbers,
					String seedCharacterSet
			)
	{
		if(length <= 0)
		{
			return UTIL_String.EMPTY;
		}

		String pool = seedCharacterSet;
		if(String.isEmpty(pool) && (includeLetters || includeNumbers))
		{
			pool = UTIL_String.EMPTY;
			startIndex = 0;

			if(includeLetters)
			{
				endIndex += LETTERS.length();
				pool += LETTERS;
			}

			if(includeNumbers)
			{
				endIndex += DIGITS.length();
				pool += DIGITS;
			}
		}

		UTIL_NumberRange.IntegerRange validRange = pool == null
				? new UTIL_NumberRange.IntegerRange(ASCII_PRINTABLE_START, ASCII_PRINTABLE_END)
				: new UTIL_NumberRange.IntegerRange(0, pool.length());

		if(!validRange.contains(new UTIL_NumberRange.IntegerRange(startIndex, endIndex)))
		{
			startIndex = validRange.min();
			endIndex = validRange.max();
		}

		List<String> characters = new List<String>();
		Integer span = endIndex - startIndex;
		Integer charIndex = 0;
		String selectedChar;

		while(length-- > 0)
		{
			charIndex = Math.round(Math.floor(nextDouble() * span)) + startIndex;
			selectedChar = pool == null ? UTIL_Character.toChar(charIndex) : UTIL_String.charAt(pool, charIndex);
			characters.add(selectedChar);
		}

		return String.join(characters, UTIL_String.EMPTY);
	}

	/**
	 * @description Produces a universally unique identifier in the standard 8-4-4-4-12 hexadecimal format.
	 *
	 * @return A freshly generated UUID string.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String uuid = UTIL_Random.randomUUID();
	 * System.debug(uuid); // Outputs: e.g., "550e8400-e29b-41d4-a716-446655440000"
	 * ```
	 */
	global static String randomUUID()
	{
		return UUID.randomUUID().toString();
	}

	/**
	 * @description Constructs a mock 18-character Salesforce ID based on the key prefix of the supplied SObjectType, useful for unit tests that need fake record IDs.
	 *
	 * @param sObjectType The SObject type whose key prefix seeds the mock ID.
	 *
	 * @return A synthetic 18-character Salesforce ID.
	 *
	 * @throws IllegalArgumentException When the SObjectType does not yield a valid 3-character key prefix.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Id mockId = UTIL_Random.randomId(Account.SObjectType);
	 * System.debug(mockId); // Outputs: e.g., "00100000000lACzAAM"
	 * ```
	 */
	global static Id randomId(SObjectType sObjectType)
	{
		String objectKeyPrefix = UTIL_SObjectDescribe.getDescribe(sObjectType)?.getDescribe().keyPrefix;
		if(objectKeyPrefix?.length() != 3)
		{
			throw new IllegalArgumentException('Invalid Object Key Prefix provided: "' + objectKeyPrefix + '"');
		}
		return objectKeyPrefix + '0'.repeat(8) + randomAlphanumeric(4);
	}

	/**
	 * @description Produces a random non-negative integer up to the specified ceiling.
	 *
	 * @param upperBound The inclusive maximum for the generated value.
	 *
	 * @return A random integer between 0 and upperBound, or null when upperBound is null.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Integer randomInt = UTIL_Random.randomInteger(100);
	 * System.debug(randomInt); // Outputs: e.g., 42
	 * ```
	 */
	global static Integer randomInteger(Integer upperBound)
	{
		return upperBound == null ? null : nextInteger(upperBound);
	}

	/**
	 * @description Produces a random date falling between the Unix epoch (1970-01-01) and the current day.
	 *
	 * @return A Date that is never in the future.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Date randomDate = UTIL_Random.randomDate();
	 * ```
	 */
	global static Date randomDate()
	{
		return Date.today().addDays(-randomDaysFromEpoch());
	}

	/**
	 * @description Produces a random datetime falling between the Unix epoch (1970-01-01) and the current moment.
	 *
	 * @return A Datetime that is never in the future.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Datetime randomDt = UTIL_Random.randomDateTime();
	 * ```
	 */
	global static Datetime randomDateTime()
	{
		return System.now().addDays(-randomDaysFromEpoch());
	}

	/**
	 * @description Calculates a random day offset between zero and the number of days from the Unix epoch to today.
	 *
	 * @return A random non-negative integer representing a number of days to subtract from the current date.
	 */
	private static Integer randomDaysFromEpoch()
	{
		Integer daysBetween = UTIL_Date.getEpochDate().daysBetween(Date.today());
		return UTIL_Random.nextInteger(daysBetween - 1);
	}

	/**
	 * @description Produces a random decimal value with two digits after the decimal point.
	 *
	 * @return A Decimal such as 45.67.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Decimal randomDec = UTIL_Random.randomDecimal();
	 * ```
	 */
	global static Decimal randomDecimal()
	{
		return randomDecimal(2);
	}

	/**
	 * @description Produces a random decimal with a caller-specified whole-number digit count and fractional precision.
	 *
	 * @param length The magnitude of digits before the decimal point.
	 * @param scale The number of digits after the decimal point.
	 *
	 * @return A Decimal with the requested scale.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Decimal randomDec = UTIL_Random.randomDecimal(4, 2);
	 * ```
	 */
	global static Decimal randomDecimal(Integer length, Integer scale)
	{
		Double randomDouble = nextDouble() * Math.pow(10, length);
		if(scale == 0)
		{
			randomDouble = Math.floor(randomDouble);
		}
		return Decimal.valueOf(randomDouble).setScale(scale);
	}

	/**
	 * @description Produces a random decimal with a standard digit count and the caller-specified fractional precision.
	 *
	 * @param scale The number of digits after the decimal point.
	 *
	 * @return A Decimal with the requested precision.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Decimal randomDec = UTIL_Random.randomDecimal(2);
	 * ```
	 */
	global static Decimal randomDecimal(Integer scale)
	{
		return randomDecimal(STANDARD_DECIMAL_LENGTH, scale);
	}

	/**
	 * @description Produces a random alphabetic string exactly 40 characters long, suitable for description fields.
	 *
	 * @return A 40-character alphabetic string.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String randomDesc = UTIL_Random.randomDescription();
	 * ```
	 */
	global static String randomDescription()
	{
		final Integer descriptionLength = 40;
		return randomAlphabetic(descriptionLength);
	}

	/**
	 * @description Produces a random, realistic-looking email address by combining name components with a randomly selected provider domain.
	 *
	 * @return A randomly composed email address such as 'john.doe@gmail.com'.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String randomEmail = UTIL_Random.randomEmail();
	 * ```
	 */
	global static String randomEmail()
	{
		List<EmailFormat> formats = EmailFormat.values();
		return randomEmail(formats.get(UTIL_Random.nextInteger(formats.size() - 1)));
	}

	/**
	 * @description Produces a random email address following the specified structural format.
	 *
	 * @param format The email structure pattern to apply (e.g., FIRSTNAME_LAST, ALPHA_NUMERIC).
	 *
	 * @return A randomly composed email address such as 'john.smith@gmail.com'.
	 *
	 * @example
	 * ```apex
	 * String randomEmail = UTIL_Random.randomEmail(UTIL_Random.EmailFormat.FIRSTNAME_LAST);
	 * ```
	 */
	@TestVisible
	private static String randomEmail(EmailFormat format)
	{
		String userName;
		String delimiter = randomElement(emailNameDelimiters);

		switch on format
		{
			when ALPHA_NUMERIC
			{
				String alpha = UTIL_Random.randomAlphabetic(UTIL_Random.nextInteger(2, 5));
				String numeric = UTIL_Random.randomNumeric(UTIL_Random.nextInteger(1, 3));
				userName = alpha + delimiter + numeric;
			}
			when CREATIVE
			{
				String prefix = randomElement(creativePrefixOrSuffixes);
				String suffix = randomElement(creativePrefixOrSuffixes);
				userName = prefix + delimiter + suffix;
			}
			when CREATIVE_LASTNAME
			{
				String prefix = randomElement(creativePrefixOrSuffixes);
				String lastName = randomElement(lastNames);
				userName = prefix + delimiter + lastName;
			}
			when FIRSTNAME
			{
				userName = randomElement(firstNames);
			}
			when FIRSTNAME_CREATIVE
			{
				String firstName = randomElement(firstNames);
				String suffix = randomElement(creativePrefixOrSuffixes);
				userName = firstName + delimiter + suffix;
			}
			when FIRSTNAME_DEPARTMENT
			{
				String firstName = randomElement(firstNames);
				String department = randomElement(departments);
				userName = firstName + delimiter + department;
			}
			when FIRSTNAME_INITIAL_LAST
			{
				String firstName = randomElement(firstNames);
				String lastName = randomElement(lastNames);
				String middleName = randomElement(middleNames);
				userName = firstName + delimiter + middleName.substring(0, 1) + delimiter + lastName;
			}
			when FIRSTNAME_LAST
			{
				String firstName = randomElement(firstNames);
				String lastName = randomElement(lastNames);
				userName = firstName + delimiter + lastName;
			}
			when FIRSTNAME_LAST_INITIAL
			{
				String firstName = randomElement(firstNames);
				String lastName = randomElement(lastNames);
				userName = firstName + lastName.substring(0, 1);
			}
			when FIRSTNAME_LAST_NO_DELIMITER
			{
				String firstName = randomElement(firstNames);
				String lastName = randomElement(lastNames);
				userName = firstName + lastName;
			}
			when FIRSTNAME_MIDDLE_LAST
			{
				String firstName = randomElement(firstNames);
				String lastName = randomElement(lastNames);
				String middleName = randomElement(middleNames);
				userName = firstName + delimiter + middleName + delimiter + lastName;
			}
			when LASTNAME_FIRSTNAME_INITIAL
			{
				String firstName = randomElement(firstNames);
				String lastName = randomElement(lastNames);
				String middleName = randomElement(middleNames);
				userName = lastName + delimiter + firstName + delimiter + middleName.substring(0, 1);
			}
			when LASTNAME_INITIALS
			{
				String firstName = randomElement(firstNames);
				String lastName = randomElement(lastNames);
				String middleName = randomElement(middleNames);
				userName = lastName + delimiter + firstName.substring(0, 1) + middleName.substring(0, 1);
			}
			when LAST_NAME_NUMERIC
			{
				String lastName = randomElement(lastNames);
				String numeric = UTIL_Random.randomNumeric(UTIL_Random.nextInteger(1, 4));
				userName = lastName + numeric;
			}
			when RANDOM_ALPHANUMERIC
			{
				userName = UTIL_Random.randomAlphanumeric(UTIL_Random.nextInteger(4, 8));
			}
		}

		Boolean capitalizeWords = UTIL_Random.nextBoolean();
		Boolean doUpperCase = !capitalizeWords && UTIL_Random.nextBoolean();
		Boolean doUpperEmailProvider = !capitalizeWords && UTIL_Random.nextBoolean();

		if(capitalizeWords)
		{
			userName = UTIL_String.capitalizeWords(userName, delimiter);
		}
		else if(doUpperCase)
		{
			userName = userName.toUpperCase();
		}
		else
		{
			userName = userName.toLowerCase();
		}

		String emailProvider = randomElement(emailProviders);

		return userName + '@' + (doUpperEmailProvider ? emailProvider?.toUpperCase() : emailProvider);
	}

	/**
	 * @description Produces a random integer with a standard length of 6 digits.
	 *
	 * @return A 6-digit random integer such as 789234.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Integer randomInt = UTIL_Random.randomInteger();
	 * ```
	 */
	global static Integer randomInteger()
	{
		final Integer standardDigitCount = 6;
		return randomIntegerOfLength(standardDigitCount);
	}

	/**
	 * @description Produces a random integer with exactly the specified number of digits.
	 *
	 * @param requiredLength The exact digit count for the generated integer.
	 *
	 * @return An integer guaranteed to have the requested number of digits.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Integer randomInt = UTIL_Random.randomIntegerOfLength(5);
	 * ```
	 */
	global static Integer randomIntegerOfLength(Integer requiredLength)
	{
		Integer min = ((Integer)Math.pow(10, requiredLength - 1));
		Integer max = (Integer)Math.pow(10, requiredLength) - 1;

		return UTIL_Random.nextInteger(min, max);
	}

	/**
	 * @description Produces a random alphabetic string with a standard length of 10 characters.
	 *
	 * @return A 10-character alphabetic string.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String randomName = UTIL_Random.randomName();
	 * ```
	 */
	global static String randomName()
	{
		final Integer standardNameLength = 10;
		return randomAlphabetic(standardNameLength);
	}

	/**
	 * @description Produces a random numeric string with a standard length of 6 digits.
	 *
	 * @return A 6-character numeric string.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String randomNum = UTIL_Random.randomNumber();
	 * ```
	 */
	global static String randomNumber()
	{
		final Integer standardNumericLength = 6;
		return randomNumeric(standardNumericLength);
	}

	/**
	 * @description Produces a random international phone number in the format '+[countryCode] ([areaCode]) [part1]-[part2]'.
	 *
	 * @return A formatted phone number such as '+123 (456) 789-0123'.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String randomPhone = UTIL_Random.randomPhoneNumber();
	 * ```
	 */
	global static String randomPhoneNumber()
	{
		final String countryCodeDigits = '1234567890';
		final String leadingZeros = '00';

		String countryCode = UTIL_Random.random(3, countryCodeDigits);
		String areaCode = randomNumeric(3).removeStart(leadingZeros);
		String phonePart1 = randomNumeric(3);
		String phonePart2 = randomNumeric(4);

		final String formatPattern = '+{0} ({1}) {2}-{3}';
		return String.format(formatPattern, new List<String>
		{
				countryCode, areaCode, phonePart1, phonePart2
		});
	}

	/**
	 * @description Selects a random element from the given list using a uniformly distributed index.
	 *
	 * @param items The list to select from.
	 *
	 * @return A randomly chosen element from the list.
	 */
	private static String randomElement(List<String> items)
	{
		return items.get(UTIL_Random.nextInteger(items.size() - 1));
	}

	/**
	 * @description Enum cataloguing the structural patterns available for random email address composition.
	 */
	@TestVisible
	private enum EmailFormat
	{
		ALPHA_NUMERIC,
		CREATIVE,
		CREATIVE_LASTNAME,
		FIRSTNAME,
		FIRSTNAME_CREATIVE,
		FIRSTNAME_DEPARTMENT,
		FIRSTNAME_INITIAL_LAST,
		FIRSTNAME_LAST,
		FIRSTNAME_LAST_INITIAL,
		FIRSTNAME_LAST_NO_DELIMITER,
		FIRSTNAME_MIDDLE_LAST,
		LASTNAME_FIRSTNAME_INITIAL,
		LASTNAME_INITIALS,
		LAST_NAME_NUMERIC,
		RANDOM_ALPHANUMERIC
	}

	/**
	 * @description Delimiter characters used to join name segments within the local part of an email address.
	 */
	@TestVisible
	private static final List<String> emailNameDelimiters
	{
		get
		{
			if(emailNameDelimiters == null)
			{
				emailNameDelimiters = new List<String>
				{
						'', '.', '-', '_'
				};
			}

			return emailNameDelimiters;
		}
		set;
	}

	/**
	 * @description Organisational department labels used as name components in email generation.
	 */
	private static final List<String> departments
	{
		get
		{
			if(departments == null)
			{
				departments = new List<String>
				{
						'ceo', 'cfo', 'cto', 'coo', 'exec', 'mgmt', 'sales', 'mktg', 'bdev', 'rev',
						'tech', 'dev', 'eng', 'infra', 'cloud', 'devops', 'qa', 'arch',
						'fin', 'acct', 'ops', 'proc', 'hr', 'admin', 'recruit', 'talent',
						'support', 'care', 'crm', 'service', 'prod', 'proj', 'pmo', 'design',
						'legal', 'comply', 'risk', 'audit', 'rnd', 'innov', 'labs', 'research',
						'data', 'analytics', 'bi', 'ml', 'content', 'comm', 'media', 'pr'
				};
			}

			return departments;
		}
		set;
	}

	/**
	 * @description Domain names of worldwide email providers used as the host portion of generated email addresses.
	 */
	@TestVisible
	private static final List<String> emailProviders
	{
		get
		{
			if(emailProviders == null)
			{
				emailProviders = new List<String>
				{
						'gmail.com', 'yahoo.com', 'outlook.com', 'icloud.com', 'hotmail.com',
						'protonmail.com', 'zoho.com', 'mail.com', 'gmx.com', 'hushmail.com',
						'aol.com', 'fastmail.com', 'tutanota.com', 'pm.me', 'yandex.com',
						'state.gov', 'treasury.gov', 'dhs.gov', 'doi.gov', 'ed.gov',
						'energy.gov', 'epa.gov', 'fbi.gov', 'fda.gov', 'gsa.gov',
						'irs.gov', 'justice.gov', 'nasa.gov', 'nih.gov', 'nist.gov',
						'noaa.gov', 'nsf.gov', 'senate.gov', 'house.gov', 'usda.gov',
						'va.gov', 'whitehouse.gov', 'army.mil', 'navy.mil',
						'af.mil', 'marines.mil', 'uscg.mil', 'defense.gov',
						'ca.gov', 'ny.gov', 'texas.gov', 'florida.gov', 'illinois.gov',
						'mass.gov', 'michigan.gov', 'pa.gov', 'ohio.gov', 'virginia.gov',
						'microsoft.com', 'apple.com', 'amazon.com', 'google.com', 'meta.com',
						'oracle.com', 'salesforce.com', 'ibm.com', 'intel.com', 'cisco.com'
				};
			}

			return emailProviders;
		}
		set;
	}

	/**
	 * @description Given names used as building blocks for random name and email generation.
	 */
	private static final List<String> firstNames
	{
		get
		{
			if(firstNames == null)
			{
				firstNames = new List<String>
				{
						'Liam', 'Noah', 'Oliver', 'Elijah', 'Lucas', 'Mason', 'Logan', 'James', 'Ethan', 'Benjamin',
						'William', 'Henry', 'Jackson', 'Charlie', 'Thomas', 'Alfie', 'Jacob', 'Leo', 'Alexander', 'Daniel',
						'Christopher', 'Jonathan', 'Nicholas', 'Nathaniel', 'Zachary', 'Harrison', 'Theodore', 'Sebastian', 'Dominic', 'Frederick',
						'Emma', 'Olivia', 'Ava', 'Isabella', 'Sophia', 'Charlotte', 'Mia', 'Amelia', 'Harper', 'Evelyn', 'Jason',
						'Adrian', 'Austin', 'Blake', 'Brandon', 'Caleb', 'Cameron', 'Carter', 'Chase', 'Cole', 'Connor',
						'Cooper', 'David', 'Dylan', 'Edward', 'Evan', 'Gabriel', 'Gavin', 'George', 'Grant', 'Hunter',
						'Isaac', 'Jack', 'Jaden', 'Jake', 'Jordan', 'Joseph', 'Justin', 'Kevin', 'Luke', 'Marcus',
						'Matthew', 'Maxwell', 'Michael', 'Nathan', 'Owen', 'Parker', 'Peter', 'Ryan', 'Samuel', 'Tyler'
				};
			}

			return firstNames;
		}
		set;
	}

	/**
	 * @description Family names used as building blocks for random name and email generation.
	 */
	private static final List<String> lastNames
	{
		get
		{
			if(lastNames == null)
			{
				lastNames = new List<String>
				{
						'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Miller', 'Davis', 'Garcia', 'Wilson', 'Thomas',
						'Evans', 'Roberts', 'Taylor', 'Clark', 'Walker', 'Harris', 'Lewis', 'King', 'Scott', 'Wright',
						'Richardson', 'Henderson', 'Alexander', 'Montgomery', 'Wellington', 'Kensington', 'Blackwood', 'Whitaker', 'Fitzpatrick', 'Chamberlain',
						'MacDonald', 'Campbell', 'MacLeod', 'Stewart', 'Murray', 'OConnor', 'OBrien', 'Murphy', 'Kennedy', 'Flynn',
						'Schmidt', 'Mueller', 'Weber', 'Wagner', 'Becker', 'Hoffmann', 'VanDerBerg', 'VanDijk', 'DeJong', 'Jansen',
						'Martin', 'Bernard', 'Dubois', 'Robert', 'Richard', 'Petit', 'Durand', 'Leroy', 'Moreau', 'Laurent',
						'Tanaka', 'Suzuki', 'Sato', 'Takahashi', 'Watanabe', 'Ito', 'Yamamoto', 'Nakamura', 'Kobayashi', 'Kato',
						'Wang', 'Li', 'Zhang', 'Liu', 'Chen', 'Yang', 'Huang', 'Zhao', 'Wu', 'Zhou',
						'Kim', 'Lee', 'Park', 'Choi', 'Jung', 'Kang', 'Cho', 'Han', 'Kwon', 'Lim'
				};
			}

			return lastNames;
		}
		set;
	}

	/**
	 * @description Secondary given names used as building blocks for random name and email generation.
	 */
	private static final List<String> middleNames
	{
		get
		{
			if(middleNames == null)
			{
				middleNames = new List<String>
				{
						'Augustine', 'Bartholomew', 'Constantine', 'Dominic', 'Eugene', 'Francis', 'Gregory', 'Ignatius', 'Jerome', 'Lawrence',
						'Maurice', 'Pascal', 'Quentin', 'Reginald', 'Solomon', 'Thaddeus', 'Vincent', 'Wilfred', 'Xavier', 'Yves',
						'Adelaide', 'Bernadette', 'Constance', 'Daphne', 'Estelle', 'Felicity', 'Genevieve', 'Harriet', 'Irene', 'Josephine',
						'Alastair', 'Brendan', 'Cormac', 'Declan', 'Eamonn', 'Finnian', 'Keiran', 'Malachy', 'Niall', 'Padraig',
						'Adalbert', 'Burkhard', 'Dietrich', 'Engelbert', 'Friedhelm', 'Gottfried', 'Hartmut', 'Manfred', 'Reinhard', 'Siegfried'
				};
			}

			return middleNames;
		}
		set;
	}

	/**
	 * @description Imaginative word fragments that serve as prefixes or suffixes in creative email address compositions.
	 */
	private static final List<String> creativePrefixOrSuffixes
	{
		get
		{
			if(creativePrefixOrSuffixes == null)
			{
				creativePrefixOrSuffixes = new List<String>
				{
						'Spark', 'Whisper', 'Blaze', 'Hawk', 'Storm', 'Mist', 'Jet', 'Moon', 'Wave', 'Glide',
						'Frost', 'Comet', 'Dream', 'Sky', 'Sun', 'Fire', 'Nova', 'Shadow', 'Quest', 'Lynx',
						'Thunder', 'Lightning', 'Rain', 'Cloud', 'Wind', 'River', 'Ocean', 'Mountain', 'Forest', 'Desert',
						'Wizard', 'Dragon', 'Phoenix', 'Mystic', 'Magic', 'Crystal', 'Spirit', 'Soul', 'Legend', 'Myth',
						'Ninja', 'Samurai', 'Sensei', 'Shinobi', 'Shogun', 'Ronin', 'Kanji', 'Zen', 'Dao', 'Chi',
						'Pixel', 'Cyber', 'Digital', 'Tech', 'Gamer', 'Player', 'Bot', 'Code', 'Dev', 'Hack',
						'Cool', 'Awesome', 'Amazing', 'Brilliant', 'Clever', 'Smart', 'Wise', 'Bold', 'Brave', 'Wild'
				};
			}

			return creativePrefixOrSuffixes;
		}
		set;
	}
}