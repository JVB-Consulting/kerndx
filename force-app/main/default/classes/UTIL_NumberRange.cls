// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Defines bounded numeric intervals with comparison and containment operations.
 * Provides typed interval implementations for Integer and Long values.
 *
 * @see UTIL_NumberRange_TEST
 * @see UTIL_NumberRange.RangeContract
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
public inherited sharing class UTIL_NumberRange
{
	/**
	 * @description Validates that neither argument is null, throwing an exception when a null value is detected.
	 *
	 * @param boundaryOne The first value to validate.
	 * @param boundaryTwo The second value to validate.
	 */
	private static void validateNotNull(Object boundaryOne, Object boundaryTwo)
	{
		if(boundaryOne == null || boundaryTwo == null)
		{
			throw new IllegalArgumentException('NumberRange boundary values must not be null');
		}
	}

	/**
	 * @description Contract for numeric interval operations.
	 */
	private interface RangeContract
	{
		Object min();

		Object max();

		Integer compare(Object first, Object second);
	}

	/**
	 * @description Base class providing shared range behaviour for all numeric interval types.
	 * Containment and overlap operations are defined here using the `compare()` contract,
	 * so subclasses inherit them without duplication.
	 */
	public abstract class NumberRange implements RangeContract
	{
		private final Object lowerBound;
		private final Object upperBound;

		/**
		 * @description Initialises a range where both boundaries are the same value.
		 * The supplied value must be non-null.
		 *
		 * @param boundary The value used for both the lower and upper boundary.
		 *
		 * @throws IllegalArgumentException if `boundary` is null.
		 *
		 * @example
		 * ```apex
		 * UTIL_NumberRange.IntegerRange singleBound = new UTIL_NumberRange.IntegerRange(5);
		 * ```
		 */
		public NumberRange(Object boundary)
		{
			validateNotNull(boundary, boundary);
			lowerBound = upperBound = boundary;
		}

		/**
		 * @description Initialises a range from two values, automatically assigning the lower and upper boundaries
		 * based on their natural ordering. Neither value may be null.
		 *
		 * @param boundaryOne The first boundary candidate.
		 * @param boundaryTwo The second boundary candidate.
		 *
		 * @throws IllegalArgumentException if either value is null.
		 *
		 * @example
		 * ```apex
		 * UTIL_NumberRange.IntegerRange interval = new UTIL_NumberRange.IntegerRange(10, 5);
		 * ```
		 */
		public NumberRange(Object boundaryOne, Object boundaryTwo)
		{
			validateNotNull(boundaryOne, boundaryTwo);

			if(compare(boundaryOne, boundaryTwo) >= 0)
			{
				lowerBound = boundaryTwo;
				upperBound = boundaryOne;
			}
			else
			{
				lowerBound = boundaryOne;
				upperBound = boundaryTwo;
			}
		}

		/**
		 * @description Determines the ordering relationship between two numeric values.
		 * Subclasses override this to provide type-specific comparison logic.
		 *
		 * @param first The first value to evaluate.
		 * @param second The second value to evaluate.
		 *
		 * @return A negative integer when `first` precedes `second`, zero when equal,
		 * or a positive integer when `first` follows `second`.
		 *
		 * @example
		 * ```apex
		 * UTIL_NumberRange.IntegerRange interval = new UTIL_NumberRange.IntegerRange(5, 10);
		 * Integer ordering = interval.compare(7, 10);
		 * ```
		 */
		public virtual Integer compare(Object first, Object second)
		{
			return 0;
		}

		/**
		 * @description Determines whether a scalar value falls within this interval (inclusive).
		 *
		 * @param value The value to test.
		 *
		 * @return True when the value is between the boundaries, false otherwise.
		 */
		protected Boolean containsValue(Object value)
		{
			return compare(lowerBound, value) <= 0 && compare(value, upperBound) <= 0;
		}

		/**
		 * @description Determines whether another range is entirely enclosed by this interval.
		 *
		 * @param other The range to test for enclosure.
		 *
		 * @return True when the supplied range is fully within this interval, false otherwise.
		 */
		protected Boolean containsRange(NumberRange other)
		{
			return compare(lowerBound, other.lowerBound) <= 0 && compare(other.upperBound, upperBound) <= 0;
		}

		/**
		 * @description Determines whether another range shares any values with this interval.
		 *
		 * @param other The range to test for intersection.
		 *
		 * @return True when the ranges share at least one common value, false otherwise.
		 */
		protected Boolean overlapsRange(NumberRange other)
		{
			return compare(lowerBound, other.upperBound) <= 0 && compare(other.lowerBound, upperBound) <= 0;
		}
	}

	/**
	 * @description Concrete stub used exclusively for testing base NumberRange behaviour.
	 */
	@TestVisible
	private inherited sharing class TestableRange extends NumberRange
	{
		/**
		 * @description Constructs a testable range from a single value.
		 *
		 * @param boundary The value for both boundaries.
		 */
		@TestVisible
		TestableRange(Object boundary)
		{
			super(boundary);
		}

		/**
		 * @description Returns the upper boundary.
		 *
		 * @return The upper boundary value.
		 */
		public Object max()
		{
			return upperBound;
		}

		/**
		 * @description Returns the lower boundary.
		 *
		 * @return The lower boundary value.
		 */
		public Object min()
		{
			return lowerBound;
		}
	}

	/**
	 * @description Bounded interval for Integer values, offering containment and overlap checks.
	 */
	public inherited sharing class IntegerRange extends NumberRange
	{
		/**
		 * @description Constructs an Integer interval where both boundaries share the same value.
		 *
		 * @param boundary The integer used for both the lower and upper boundary.
		 *
		 * @example
		 * ```apex
		 * UTIL_NumberRange.IntegerRange point = new UTIL_NumberRange.IntegerRange(5);
		 * ```
		 */
		public IntegerRange(Integer boundary)
		{
			super(boundary);
		}

		/**
		 * @description Constructs an Integer interval from two values, ordering them automatically.
		 *
		 * @param boundaryOne The first integer boundary candidate.
		 * @param boundaryTwo The second integer boundary candidate.
		 *
		 * @example
		 * ```apex
		 * UTIL_NumberRange.IntegerRange interval = new UTIL_NumberRange.IntegerRange(10, 3);
		 * ```
		 */
		public IntegerRange(Integer boundaryOne, Integer boundaryTwo)
		{
			super(boundaryOne, boundaryTwo);
		}

		/**
		 * @description Evaluates the ordering of two Integer values.
		 *
		 * @param first The first integer to evaluate.
		 * @param second The second integer to evaluate.
		 *
		 * @return -1 when `first` is smaller, 0 when equal, 1 when `first` is larger.
		 *
		 * @example
		 * ```apex
		 * UTIL_NumberRange.IntegerRange interval = new UTIL_NumberRange.IntegerRange(5, 10);
		 * Integer ordering = interval.compare(7, 10);
		 * ```
		 */
		public virtual override Integer compare(Object first, Object second)
		{
			Integer firstValue = (Integer)first;
			Integer secondValue = (Integer)second;
			return firstValue < secondValue ? -1 : firstValue > secondValue ? 1 : 0;
		}

		/**
		 * @description Returns the upper boundary of this interval.
		 *
		 * @return The maximum integer value of the interval.
		 *
		 * @example
		 * ```apex
		 * Integer upper = interval.max();
		 * ```
		 */
		public Integer max()
		{
			return (Integer)upperBound;
		}

		/**
		 * @description Returns the lower boundary of this interval.
		 *
		 * @return The minimum integer value of the interval.
		 *
		 * @example
		 * ```apex
		 * Integer lower = interval.min();
		 * ```
		 */
		public Integer min()
		{
			return (Integer)lowerBound;
		}

		/**
		 * @description Determines whether a scalar value falls within this interval (inclusive).
		 *
		 * @param value The integer value to test.
		 *
		 * @return True when the value is between the boundaries, false otherwise.
		 *
		 * @example
		 * ```apex
		 * Boolean withinBounds = interval.contains(10);
		 * ```
		 */
		public Boolean contains(Integer value)
		{
			return containsValue(value);
		}

		/**
		 * @description Determines whether another IntegerRange is entirely enclosed by this interval.
		 *
		 * @param value The IntegerRange to test for enclosure.
		 *
		 * @return True when the supplied range is fully within this interval, false otherwise.
		 *
		 * @example
		 * ```apex
		 * Boolean enclosed = outer.contains(inner);
		 * ```
		 */
		public Boolean contains(IntegerRange value)
		{
			return containsRange(value);
		}

		/**
		 * @description Determines whether another IntegerRange shares any values with this interval.
		 *
		 * @param value The IntegerRange to test for intersection.
		 *
		 * @return True when the ranges share at least one common value, false otherwise.
		 *
		 * @example
		 * ```apex
		 * Boolean intersects = range.overlaps(other);
		 * ```
		 */
		public Boolean overlaps(IntegerRange value)
		{
			return overlapsRange(value);
		}
	}

	/**
	 * @description Bounded interval for Long values, offering containment and overlap checks.
	 */
	public inherited sharing class LongRange extends NumberRange
	{
		/**
		 * @description Constructs a Long interval where both boundaries share the same value.
		 *
		 * @param boundary The long value used for both the lower and upper boundary.
		 *
		 * @example
		 * ```apex
		 * UTIL_NumberRange.LongRange point = new UTIL_NumberRange.LongRange(100L);
		 * ```
		 */
		public LongRange(Long boundary)
		{
			super(boundary);
		}

		/**
		 * @description Constructs a Long interval from two values, ordering them automatically.
		 *
		 * @param boundaryOne The first long boundary candidate.
		 * @param boundaryTwo The second long boundary candidate.
		 *
		 * @example
		 * ```apex
		 * UTIL_NumberRange.LongRange interval = new UTIL_NumberRange.LongRange(200L, 100L);
		 * ```
		 */
		public LongRange(Long boundaryOne, Long boundaryTwo)
		{
			super(boundaryOne, boundaryTwo);
		}

		/**
		 * @description Evaluates the ordering of two Long values.
		 *
		 * @param first The first long value to evaluate.
		 * @param second The second long value to evaluate.
		 *
		 * @return -1 when `first` is smaller, 0 when equal, 1 when `first` is larger.
		 *
		 * @example
		 * ```apex
		 * UTIL_NumberRange.LongRange interval = new UTIL_NumberRange.LongRange(100L, 200L);
		 * Integer ordering = interval.compare(150L, 200L);
		 * ```
		 */
		public virtual override Integer compare(Object first, Object second)
		{
			Long firstValue = (Long)first;
			Long secondValue = (Long)second;
			return firstValue < secondValue ? -1 : firstValue > secondValue ? 1 : 0;
		}

		/**
		 * @description Returns the upper boundary of this interval.
		 *
		 * @return The maximum long value of the interval.
		 *
		 * @example
		 * ```apex
		 * Long upper = interval.max();
		 * ```
		 */
		public Long max()
		{
			return (Long)upperBound;
		}

		/**
		 * @description Returns the lower boundary of this interval.
		 *
		 * @return The minimum long value of the interval.
		 *
		 * @example
		 * ```apex
		 * Long lower = interval.min();
		 * ```
		 */
		public Long min()
		{
			return (Long)lowerBound;
		}

		/**
		 * @description Determines whether a scalar value falls within this interval (inclusive).
		 *
		 * @param value The long value to test.
		 *
		 * @return True when the value is between the boundaries, false otherwise.
		 *
		 * @example
		 * ```apex
		 * Boolean withinBounds = interval.contains(150L);
		 * ```
		 */
		public Boolean contains(Long value)
		{
			return containsValue(value);
		}

		/**
		 * @description Determines whether another LongRange is entirely enclosed by this interval.
		 *
		 * @param value The LongRange to test for enclosure.
		 *
		 * @return True when the supplied range is fully within this interval, false otherwise.
		 *
		 * @example
		 * ```apex
		 * Boolean enclosed = outer.contains(inner);
		 * ```
		 */
		public Boolean contains(LongRange value)
		{
			return containsRange(value);
		}

		/**
		 * @description Determines whether another LongRange shares any values with this interval.
		 *
		 * @param value The LongRange to test for intersection.
		 *
		 * @return True when the ranges share at least one common value, false otherwise.
		 *
		 * @example
		 * ```apex
		 * Boolean intersects = range.overlaps(other);
		 * ```
		 */
		public Boolean overlaps(LongRange value)
		{
			return overlapsRange(value);
		}
	}
}