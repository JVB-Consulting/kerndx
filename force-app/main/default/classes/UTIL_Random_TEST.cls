// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Validates that all random value generation methods produce correctly typed, correctly sized, and correctly bounded output.
 *
 * @see UTIL_Random
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_Random_TEST
{
	/**
	 * @description Label prefix for the random() method in assertion messages.
	 */
	private static final String PREFIX_RANDOM = 'UTIL_Random.random(';
	/**
	 * @description Label prefix for the randomAlphabetic() method in assertion messages.
	 */
	private static final String PREFIX_ALPHABETIC = 'UTIL_Random.randomAlphabetic(';
	/**
	 * @description Label prefix for the randomAlphanumeric() method in assertion messages.
	 */
	private static final String PREFIX_ALPHANUMERIC = 'UTIL_Random.randomAlphanumeric(';
	/**
	 * @description Label prefix for the randomNumeric() method in assertion messages.
	 */
	private static final String PREFIX_NUMERIC = 'UTIL_Random.randomNumeric(';
	/**
	 * @description Comma-and-quote fragment appended before a character set argument in assertion messages.
	 */
	private static final String SUFFIX_COMMA = ',\'';
	/**
	 * @description Trailing fragment indicating the expected result was an empty string.
	 */
	private static final String SUFFIX_EXPECTED_EMPTY = '\'; expected \'\'';
	/**
	 * @description Trailing fragment flagging the presence of characters outside the ASCII range.
	 */
	private static final String SUFFIX_NON_ASCII = '\' (unexpected non-ascii characters present)';
	/**
	 * @description Trailing fragment flagging the presence of non-digit characters.
	 */
	private static final String SUFFIX_NON_NUMERIC = '\' (unexpected non-numeric characters present)';
	/**
	 * @description Single-quote character used to wrap values in assertion messages.
	 */
	private static final String SUFFIX_QUOTE = '\'';
	/**
	 * @description Fragment separating the method signature from its returned value in assertion messages.
	 */
	private static final String SUFFIX_RETURNED = ') returned \'';
	/**
	 * @description Fragment separating a quoted method signature from its returned value in assertion messages.
	 */
	private static final String SUFFIX_RETURNED_QUOTED = '\') returned \'';
	/**
	 * @description Trailing fragment flagging the presence of characters outside the alphanumeric set.
	 */
	private static final String SUFFIX_NON_ALPHANUMERIC = '\' (unexpected non-alphanumeric characters present)';
	/**
	 * @description Trailing fragment flagging the presence of characters not belonging to the allowed set.
	 */
	private static final String SUFFIX_INVALID_CHARS = '\' (unexpected characters present)';
	/**
	 * @description Trailing fragment flagging an output whose length differs from the requested length.
	 */
	private static final String SUFFIX_WRONG_LENGTH = '\' (unexpected length)';
	/**
	 * @description Generic assertion message for values that did not match expectations.
	 */
	private static final String VALUE_ASSERTION_FAILED = 'Value not as expected.';

	/**
	 * @description Confirms that nextBoolean produces a non-null result.
	 */
	@IsTest
	private static void shouldGenerateNonNullBoolean()
	{
		Assert.isNotNull(UTIL_Random.nextBoolean(), VALUE_ASSERTION_FAILED);
	}

	/**
	 * @description Confirms that nextInteger with a single upper bound produces values within the expected range.
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldGenerateIntegerWithUpperBound()
	{
		UTIL_NumberRange.IntegerRange inputRange = null;
		for(Integer i = -2; i <= 2; i++)
		{
			inputRange = new UTIL_NumberRange.IntegerRange(0, Math.abs(i));
			assertIntegerInRange(inputRange, true, UTIL_Random.nextInteger(i));
		}
	}

	/**
	 * @description Confirms that nextInteger with lower and upper bounds produces values within the expected range.
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldGenerateIntegerWithBounds()
	{
		UTIL_NumberRange.IntegerRange inputRange = null;
		for(Integer i = -2; i <= 2; i++)
		{
			for(Integer j = -2; j <= 2; j++)
			{
				inputRange = new UTIL_NumberRange.IntegerRange(i, j);
				assertIntegerInRange(inputRange, true, UTIL_Random.nextInteger(i, j));
			}
		}
	}

	/**
	 * @description Checks that the produced integer falls within the acceptable range derived from the input range and inclusivity setting.
	 *
	 * @param inputRange The range of acceptable integer values.
	 * @param inclusive Whether the range boundaries are inclusive.
	 * @param actual The generated integer value to validate.
	 */
	private static void assertIntegerInRange(UTIL_NumberRange.IntegerRange inputRange, Boolean inclusive, Integer actual)
	{
		UTIL_NumberRange.IntegerRange acceptableRange = null;
		if(!inclusive && (inputRange.max() - inputRange.min()) <= 2)
		{
			acceptableRange = new UTIL_NumberRange.IntegerRange(inputRange.min(), inputRange.min());
		}
		else
		{
			Integer inclusiveChange = 1;
			if(inclusive)
			{
				inclusiveChange = 0;
			}
			acceptableRange = new UTIL_NumberRange.IntegerRange((Integer)inputRange.min() - inclusiveChange, (Integer)inputRange.max() - inclusiveChange);
		}
		Assert.isTrue
				(
						acceptableRange.contains(actual),
						'Expected value within range ' + acceptableRange.min() + ' to ' + acceptableRange.max() + ', but got ' + actual
				);
	}

	/**
	 * @description Confirms that random() produces strings of the correct length containing only printable ASCII characters.
	 */
	@IsTest
	private static void shouldGenerateRandomAsciiString()
	{
		for(Integer numberOfChars = -1; numberOfChars < 2; numberOfChars++)
		{
			String actual = UTIL_Random.random(numberOfChars);

			if(numberOfChars < 0)
			{
				Assert.isTrue(String.isBlank(actual), PREFIX_RANDOM + numberOfChars + SUFFIX_RETURNED + actual + SUFFIX_EXPECTED_EMPTY);
			}
			else
			{
				Assert.areEqual(numberOfChars, actual.length(), PREFIX_RANDOM + numberOfChars + SUFFIX_RETURNED + actual + SUFFIX_WRONG_LENGTH);
				Assert.isTrue(actual.isAsciiPrintable(), PREFIX_RANDOM + numberOfChars + SUFFIX_RETURNED + actual + SUFFIX_NON_ASCII);
			}
		}
	}

	/**
	 * @description Confirms that randomAlphabetic() produces strings of the correct length containing only Latin letters.
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldGenerateAlphabeticString()
	{
		for(Integer i = -1; i < 2; i++)
		{
			assertAlphabeticOutput(i);
		}
	}

	/**
	 * @description Validates that the randomAlphabetic output has the expected length and consists entirely of alphabetic characters.
	 *
	 * @param count The number of characters to generate and verify.
	 */
	private static void assertAlphabeticOutput(Integer count)
	{
		String actual = UTIL_Random.randomAlphabetic(count);
		if(count <= 0)
		{
			Assert.isTrue(String.isBlank(actual), PREFIX_ALPHABETIC + count + SUFFIX_RETURNED + actual + SUFFIX_EXPECTED_EMPTY);
		}
		else
		{
			Assert.areEqual(count, actual.length(), PREFIX_ALPHABETIC + count + SUFFIX_RETURNED + actual + SUFFIX_WRONG_LENGTH);
			Assert.isTrue(actual.isAlpha(), PREFIX_ALPHABETIC + count + SUFFIX_RETURNED + actual + '\' (unexpected non-alphabetic characters present)');
		}
	}

	/**
	 * @description Confirms that randomAlphanumeric() produces strings of the correct length containing only letters and digits.
	 *
	 * @see UTIL_Random.randomAlphanumeric
	 */
	@IsTest
	private static void shouldGenerateAlphanumericString()
	{
		for(Integer numberOfCharacters = -1; numberOfCharacters < 2; numberOfCharacters++)
		{
			String actual = UTIL_Random.randomAlphanumeric(numberOfCharacters);
			if(numberOfCharacters <= 0)
			{
				Assert.isTrue(String.isBlank(actual), PREFIX_ALPHANUMERIC + numberOfCharacters + SUFFIX_RETURNED + actual + SUFFIX_EXPECTED_EMPTY);
			}
			else
			{
				Assert.areEqual
						(
								numberOfCharacters,
								actual.length(),
								PREFIX_ALPHANUMERIC + numberOfCharacters + SUFFIX_RETURNED + actual + SUFFIX_WRONG_LENGTH
						);
				Assert.isTrue(actual.isAlphanumeric(), PREFIX_ALPHANUMERIC + numberOfCharacters + SUFFIX_RETURNED + actual + SUFFIX_NON_ALPHANUMERIC);
			}
		}
	}

	/**
	 * @description Confirms that randomNumeric() produces strings of the correct length containing only digit characters.
	 *
	 * @see UTIL_Random.randomNumeric
	 */
	@IsTest
	private static void shouldGenerateNumericString()
	{
		for(Integer numberOfDigits = -1; numberOfDigits < 2; numberOfDigits++)
		{
			String actual = UTIL_Random.randomNumeric(numberOfDigits);

			if(numberOfDigits <= 0)
			{
				Assert.isTrue(String.isBlank(actual), PREFIX_NUMERIC + numberOfDigits + SUFFIX_RETURNED + actual + SUFFIX_EXPECTED_EMPTY);
			}
			else
			{
				Assert.areEqual(numberOfDigits, actual.length(), PREFIX_NUMERIC + numberOfDigits + SUFFIX_RETURNED + actual + SUFFIX_WRONG_LENGTH);
				Assert.isTrue(actual.isNumeric(), PREFIX_NUMERIC + numberOfDigits + SUFFIX_RETURNED + actual + SUFFIX_NON_NUMERIC);
			}
		}
	}

	/**
	 * @description Confirms that random() with a character set draws exclusively from the supplied characters.
	 */
	@IsTest
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	private static void shouldGenerateStringFromCharacterSet()
	{
		for(Integer i = -1; i < 2; i++)
		{
			assertCharsetOutput(i, 'abc');
		}
		for(Integer i = -1; i < 2; i++)
		{
			assertCharsetOutput(i, '4938%(#*@x)');
		}
	}

	/**
	 * @description Validates that the generated string uses only the specified character pool and has the expected length.
	 *
	 * @param count The number of characters to generate.
	 * @param chars The allowed character pool to draw from.
	 */
	private static void assertCharsetOutput(Integer count, String chars)
	{
		String actual = UTIL_Random.random(count, chars);
		if(count <= 0)
		{
			Assert.isTrue(String.isBlank(actual), PREFIX_RANDOM + count + SUFFIX_COMMA + chars + SUFFIX_RETURNED_QUOTED + actual + SUFFIX_QUOTE);
		}
		else
		{
			Assert.areEqual(count, actual.length(), PREFIX_RANDOM + count + SUFFIX_COMMA + chars + SUFFIX_RETURNED_QUOTED + actual + SUFFIX_WRONG_LENGTH);
			Assert.isTrue(actual.containsOnly(chars), PREFIX_RANDOM + count + SUFFIX_COMMA + chars + SUFFIX_RETURNED_QUOTED + actual + SUFFIX_INVALID_CHARS);
		}
	}

	/**
	 * @description Confirms that randomUUID produces a 36-character string with valid hexadecimal digits and hyphens, and that consecutive calls yield distinct values.
	 *
	 * @see UTIL_Random.randomUUID
	 */
	@IsTest
	private static void shouldGenerateValidUUID()
	{
		String actual = UTIL_Random.randomUUID();
		Assert.isNotNull(actual, VALUE_ASSERTION_FAILED);
		Assert.areEqual(36, actual.length(), VALUE_ASSERTION_FAILED);
		Assert.isTrue(actual.containsOnly('01234567890abcdef-'), 'The following UUID contains invalid characters: ' + actual);
		String comparison = UTIL_Random.randomUUID();
		Assert.areNotEqual(actual, comparison, 'Non unique UUID generated.');
	}

	/**
	 * @description Confirms that randomId with an SObjectType produces a valid 18-character mock ID that differs across calls.
	 *
	 * @see UTIL_Random.randomId
	 */
	@IsTest
	private static void shouldGenerateValidMockId()
	{
		Test.startTest();

		String actual = UTIL_Random.randomId(Foobar__c.SObjectType);

		Test.stopTest();

		Assert.isNotNull(actual, VALUE_ASSERTION_FAILED);
		Assert.areEqual(18, actual.length(), VALUE_ASSERTION_FAILED);
		String comparison = UTIL_Random.randomId(Foobar__c.SObjectType);
		Assert.areNotEqual(actual, comparison, 'Non unique Id generated.');
	}

	/**
	 * @description Confirms that randomId throws IllegalArgumentException for a null SObjectType.
	 *
	 * @see UTIL_Random.randomId
	 */
	@IsTest
	private static void shouldThrowWhenRandomIdGivenNullType()
	{
		try
		{
			UTIL_Random.randomId((SObjectType)null);
			Assert.fail('Should throw IllegalArgumentException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Confirms that randomDate produces a non-null date that is not in the future.
	 *
	 * @see UTIL_Random.randomDate
	 */
	@IsTest
	private static void shouldGenerateDateNotInFuture()
	{
		Test.startTest();

		Date randomDate = UTIL_Random.randomDate();

		Test.stopTest();

		Assert.isNotNull(randomDate, VALUE_ASSERTION_FAILED);
		Assert.isTrue(randomDate <= Date.today(), 'Random date should not be in the future');
	}

	/**
	 * @description Confirms that randomDateTime produces a non-null datetime that is not in the future.
	 *
	 * @see UTIL_Random.randomDateTime
	 */
	@IsTest
	private static void shouldGenerateDateTimeNotInFuture()
	{
		Test.startTest();

		Datetime randomDateTime = UTIL_Random.randomDateTime();

		Test.stopTest();

		Assert.isNotNull(randomDateTime, VALUE_ASSERTION_FAILED);
		Assert.isTrue(randomDateTime <= System.now(), 'Random datetime should not be in the future');
	}

	/**
	 * @description Confirms that randomDecimal and its overloads produce non-null decimal values.
	 *
	 * @see UTIL_Random.randomDecimal
	 */
	@IsTest
	private static void shouldGenerateValidDecimals()
	{
		Test.startTest();

		Decimal randomDecimal = UTIL_Random.randomDecimal();
		Decimal randomDecimalWithScale = UTIL_Random.randomDecimal(3);
		Decimal randomDecimalWithLengthScale = UTIL_Random.randomDecimal(4, 2);
		Decimal randomDecimalWithZeroScale = UTIL_Random.randomDecimal(4, 0);

		Test.stopTest();

		Assert.isNotNull(randomDecimal, VALUE_ASSERTION_FAILED);
		Assert.isNotNull(randomDecimalWithScale, VALUE_ASSERTION_FAILED);
		Assert.isNotNull(randomDecimalWithLengthScale, VALUE_ASSERTION_FAILED);
		Assert.areEqual(0, randomDecimalWithZeroScale.scale(), 'Zero-scale decimal should have no fractional digits');
	}

	/**
	 * @description Confirms that randomDescription produces a non-null string exactly 40 characters long.
	 *
	 * @see UTIL_Random.randomDescription
	 */
	@IsTest
	private static void shouldGenerateFortyCharDescription()
	{
		Test.startTest();

		String description = UTIL_Random.randomDescription();

		Test.stopTest();

		Assert.isNotNull(description, VALUE_ASSERTION_FAILED);
		Assert.areEqual(40, description.length(), 'Description should be 40 characters');
	}

	/**
	 * @description Confirms that randomEmail produces a valid email address for every format.
	 *
	 * @see UTIL_Random.randomEmail
	 */
	@IsTest
	private static void shouldGenerateValidEmailForEveryFormat()
	{
		String publicEmail = UTIL_Random.randomEmail();
		Assert.isTrue(UTIL_Email.isValidEmailAddress(publicEmail), 'Public randomEmail should pass validation: ' + publicEmail);

		for(UTIL_Random.EmailFormat format : UTIL_Random.EmailFormat.values())
		{
			String email = UTIL_Random.randomEmail(format);
			Assert.isTrue(UTIL_Email.isValidEmailAddress(email), 'Generated email should pass validation for format ' + format.name() + ': ' + email);
		}
	}

	/**
	 * @description Confirms that randomInteger and randomIntegerOfLength produce non-null integer values.
	 *
	 * @see UTIL_Random.randomInteger
	 */
	@IsTest
	private static void shouldGenerateValidIntegers()
	{
		Test.startTest();

		Integer randomInt = UTIL_Random.randomInteger();
		Integer randomIntWithUpperBound = UTIL_Random.randomInteger(100);
		Integer randomIntOfLength = UTIL_Random.randomIntegerOfLength(5);

		Test.stopTest();

		Assert.isNotNull(randomInt, VALUE_ASSERTION_FAILED);
		Assert.isNotNull(randomIntWithUpperBound, VALUE_ASSERTION_FAILED);
		Assert.isNotNull(randomIntOfLength, VALUE_ASSERTION_FAILED);
	}

	/**
	 * @description Confirms that randomName produces an alphabetic string of the default length.
	 *
	 * @see UTIL_Random.randomName
	 */
	@IsTest
	private static void shouldGenerateAlphabeticName()
	{
		Test.startTest();

		String randomName = UTIL_Random.randomName();

		Test.stopTest();

		Assert.areEqual(10, randomName.length(), 'Default name should be 10 characters');
	}

	/**
	 * @description Confirms that randomNumber produces a numeric string of the default length.
	 *
	 * @see UTIL_Random.randomNumber
	 */
	@IsTest
	private static void shouldGenerateDefaultLengthNumber()
	{
		Test.startTest();

		String randomNum = UTIL_Random.randomNumber();

		Test.stopTest();

		Assert.areEqual(6, randomNum.length(), 'Default number should be 6 digits');
	}

	/**
	 * @description Confirms that randomPhoneNumber produces a formatted string starting with '+' and containing area code parentheses.
	 *
	 * @see UTIL_Random.randomPhoneNumber
	 */
	@IsTest
	private static void shouldGenerateFormattedPhoneNumber()
	{
		Test.startTest();

		String phone = UTIL_Random.randomPhoneNumber();

		Test.stopTest();

		Assert.isNotNull(phone, VALUE_ASSERTION_FAILED);
		Assert.isTrue(phone.startsWith('+'), 'Phone should start with +');
		Assert.isTrue(phone.contains('(') && phone.contains(')'), 'Phone should contain area code brackets');
	}

}