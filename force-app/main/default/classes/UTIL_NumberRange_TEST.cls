// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Validates numeric interval creation, boundary assignment, containment, and overlap logic.
 *
 * @see UTIL_NumberRange
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_NumberRange_TEST
{
	/**
	 * @description Assertion message for range enclosure checks.
	 */
	private static final String EXPECTED_RANGE_CONTAINMENT = 'Range should contain the specified range';

	/**
	 * @description Assertion message for scalar containment checks.
	 */
	private static final String EXPECTED_VALUE_CONTAINMENT = 'Range should contain the specified value';

	/**
	 * @description Assertion message for exception type verification.
	 */
	private static final String EXPECTED_EXCEPTION_TYPE = 'Expected IllegalArgumentException was thrown';

	/**
	 * @description Assertion message for range intersection checks.
	 */
	private static final String EXPECTED_RANGE_OVERLAP = 'Range should overlap with the specified range';

	/**
	 * @description Assertion message for boundary value verification.
	 */
	private static final String EXPECTED_BOUNDARY_VALUE = 'Range value should match expected';

	/**
	 * @description Verifies that the base compare implementation returns zero for any input.
	 */
	@IsTest
	private static void shouldReturnZeroForEqualValues()
	{
		UTIL_NumberRange.TestableRange testableRange = new UTIL_NumberRange.TestableRange(0);
		Assert.areEqual(0, testableRange.compare(0, 0), 'Base compare should return zero');
		Assert.areEqual(0, testableRange.min(), EXPECTED_BOUNDARY_VALUE);
		Assert.areEqual(0, testableRange.max(), EXPECTED_BOUNDARY_VALUE);
	}

	/**
	 * @description Verifies IntegerRange boundary assignment, containment, and overlap behaviour.
	 */
	@IsTest
	private static void shouldCreateValidIntegerRange()
	{
		UTIL_NumberRange.IntegerRange integerRange = new UTIL_NumberRange.IntegerRange(0);
		Assert.areEqual(0, integerRange.min(), EXPECTED_BOUNDARY_VALUE);
		Assert.areEqual(0, integerRange.max(), EXPECTED_BOUNDARY_VALUE);

		integerRange = new UTIL_NumberRange.IntegerRange(0, 1);
		Assert.areEqual(0, integerRange.min(), EXPECTED_BOUNDARY_VALUE);
		Assert.areEqual(1, integerRange.max(), EXPECTED_BOUNDARY_VALUE);

		integerRange = new UTIL_NumberRange.IntegerRange(1, 0);
		Assert.areEqual(0, integerRange.min(), EXPECTED_BOUNDARY_VALUE);
		Assert.areEqual(1, integerRange.max(), EXPECTED_BOUNDARY_VALUE);

		Assert.isTrue(integerRange.contains(1), EXPECTED_VALUE_CONTAINMENT);
		Assert.isTrue(integerRange.contains(new UTIL_NumberRange.IntegerRange(0, 1)), EXPECTED_RANGE_CONTAINMENT);
		Assert.isTrue(integerRange.overlaps(new UTIL_NumberRange.IntegerRange(1, 0)), EXPECTED_RANGE_OVERLAP);
	}

	/**
	 * @description Verifies LongRange boundary assignment, containment, and overlap behaviour.
	 */
	@IsTest
	private static void shouldCreateValidLongRange()
	{
		UTIL_NumberRange.LongRange longRange = new UTIL_NumberRange.LongRange(0);
		Assert.areEqual(0, longRange.min(), EXPECTED_BOUNDARY_VALUE);
		Assert.areEqual(0, longRange.max(), EXPECTED_BOUNDARY_VALUE);

		longRange = new UTIL_NumberRange.LongRange(0, 1);
		Assert.areEqual(0, longRange.min(), EXPECTED_BOUNDARY_VALUE);
		Assert.areEqual(1, longRange.max(), EXPECTED_BOUNDARY_VALUE);

		longRange = new UTIL_NumberRange.LongRange(1, 0);
		Assert.areEqual(0, longRange.min(), EXPECTED_BOUNDARY_VALUE);
		Assert.areEqual(1, longRange.max(), EXPECTED_BOUNDARY_VALUE);

		Assert.isTrue(longRange.contains(1), EXPECTED_VALUE_CONTAINMENT);
		Assert.isTrue(longRange.contains(new UTIL_NumberRange.LongRange(0, 1)), EXPECTED_RANGE_CONTAINMENT);
		Assert.isTrue(longRange.overlaps(new UTIL_NumberRange.LongRange(1, 0)), EXPECTED_RANGE_OVERLAP);
	}

	/**
	 * @description Verifies that constructing a single-value range with null throws IllegalArgumentException.
	 */
	@IsTest
	private static void shouldThrowForNullSingleValue()
	{
		try
		{
			new UTIL_NumberRange.IntegerRange(null);
			Assert.fail('Expected IllegalArgumentException was not thrown');
		}
		catch(Exception thrownError)
		{
			Assert.isInstanceOfType(thrownError, IllegalArgumentException.class, EXPECTED_EXCEPTION_TYPE);
		}
	}

	/**
	 * @description Verifies that constructing a two-value range with nulls throws IllegalArgumentException.
	 */
	@IsTest
	private static void shouldThrowForNullBothValues()
	{
		try
		{
			new UTIL_NumberRange.IntegerRange(null, null);
			Assert.fail('Expected IllegalArgumentException was not thrown');
		}
		catch(Exception thrownError)
		{
			Assert.isInstanceOfType(thrownError, IllegalArgumentException.class, EXPECTED_EXCEPTION_TYPE);
		}
	}

}