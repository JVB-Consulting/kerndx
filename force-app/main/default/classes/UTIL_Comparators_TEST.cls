// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Tests the functionality of pre-built comparators in UTIL_Comparators.
 *
 * @see UTIL_Comparators
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date 2012, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_Comparators_TEST
{
	private static final Integer EQUAL = 0;
	private static final Integer GREATER = 1;
	private static final Integer LESS = -1;
	private static final String FIELD_NAME = SEL_Foobar.FIELD_NAME;
	private static final String FIELD_NUMBER = SEL_Foobar.FIELD_DECIMAL;
	private static final String MSG_EXPECTED_EXCEPTION = 'Expected IllegalArgumentException for invalid input: {0}';
	private static final String MSG_WRONG_COMPARISON = 'Expected comparison result {0} for {1} vs {2}, but found {3}';
	private static final String MSG_WRONG_SORT = 'Expected {0} at index {1} to be {2}, but found {3}';

	/**
	 * @description Tests the SObjectFieldComparator with null SObject records.
	 *
	 * @see UTIL_Comparators.SObjectFieldComparator
	 */
	@IsTest
	private static void compareNulls()
	{
		UTIL_Comparators.SObjectFieldComparator comparator = new UTIL_Comparators.SObjectFieldComparator(FIELD_NAME);

		assertSObjectComparison(comparator, null, TST_Factory.newFoobarWithName('test123'), LESS);
		assertSObjectComparison(comparator, null, null, EQUAL);
		assertSObjectComparison(comparator, TST_Factory.newFoobarWithName('test123'), null, GREATER);
	}

	/**
	 * @description Tests the SObjectFieldComparator with Integer field comparisons.
	 *
	 * @see UTIL_Comparators.SObjectFieldComparator
	 */
	@IsTest
	private static void compareIntegerRecords()
	{
		Foobar__c a1 = newFoobarWithNameAndDecimal('abc', 2);
		Foobar__c a2 = newFoobarWithNameAndDecimal('efg', 1);
		UTIL_Comparators.SObjectFieldComparator comparator = new UTIL_Comparators.SObjectFieldComparator(FIELD_NUMBER);

		// Ascending order
		assertSObjectComparison(comparator, a1, a2, GREATER);
		assertSObjectComparison(comparator, a1, a1, EQUAL);
		assertSObjectComparison(comparator, a2, a1, LESS);

		// Descending order
		comparator.sortAscending = false;
		assertSObjectComparison(comparator, a1, a2, LESS);
		assertSObjectComparison(comparator, a1, a1, EQUAL);
		assertSObjectComparison(comparator, a2, a1, GREATER);

		// Ascending order again
		comparator.sortAscending = true;
		assertSObjectComparison(comparator, a1, a2, GREATER);
		assertSObjectComparison(comparator, a1, a1, EQUAL);
		assertSObjectComparison(comparator, a2, a1, LESS);

		// Null sort order
		comparator.sortAscending = null;
		assertSObjectComparison(comparator, a1, a2, GREATER);
		assertSObjectComparison(comparator, a1, a1, EQUAL);
		assertSObjectComparison(comparator, a2, a1, LESS);
	}

	/**
	 * @description Tests the SObjectFieldComparator with String field comparisons.
	 *
	 * @see UTIL_Comparators.SObjectFieldComparator
	 */
	@IsTest
	private static void compareStringRecords()
	{
		Foobar__c a1 = newFoobarWithNameAndDecimal('abc', 2);
		Foobar__c a2 = newFoobarWithNameAndDecimal('efg', 1);
		UTIL_Comparators.SObjectFieldComparator comparator = new UTIL_Comparators.SObjectFieldComparator(FIELD_NAME);

		// Ascending order
		assertSObjectComparison(comparator, a1, a2, LESS);
		assertSObjectComparison(comparator, a1, a1, EQUAL);
		assertSObjectComparison(comparator, a2, a1, GREATER);

		// Descending order
		comparator.sortAscending = false;
		assertSObjectComparison(comparator, a1, a2, GREATER);
		assertSObjectComparison(comparator, a1, a1, EQUAL);
		assertSObjectComparison(comparator, a2, a1, LESS);

		// Ascending order again
		comparator.sortAscending = true;
		assertSObjectComparison(comparator, a1, a2, LESS);
		assertSObjectComparison(comparator, a1, a1, EQUAL);
		assertSObjectComparison(comparator, a2, a1, GREATER);

		// Null sort order
		comparator.sortAscending = null;
		assertSObjectComparison(comparator, a1, a2, LESS);
		assertSObjectComparison(comparator, a1, a1, EQUAL);
		assertSObjectComparison(comparator, a2, a1, GREATER);
	}

	/**
	 * @description Tests the SObjectFieldComparator for throwing IllegalArgumentException with null field.
	 *
	 * @see UTIL_Comparators.SObjectFieldComparator
	 */
	@IsTest
	private static void compareThrowsIllegalArgumentException()
	{
		try
		{
			new UTIL_Comparators.SObjectFieldComparator(null).compare(TST_Factory.newFoobarWithName('test123'), TST_Factory.newFoobarWithName('test123'));
			Assert.fail(String.format(MSG_EXPECTED_EXCEPTION, new List<Object> {'null field'}));
		}
		catch(IllegalArgumentException exp)
		{
			Assert.isInstanceOfType(exp, IllegalArgumentException.class,
					String.format(MSG_EXPECTED_EXCEPTION, new List<Object> {'null field'}));
		}
	}

	/**
	 * @description Tests the PrimitiveComparator with Blob values, expecting an exception.
	 *
	 * @see UTIL_Comparators.PrimitiveComparator
	 */
	@IsTest
	private static void primitiveComparatorBlob()
	{
		Object b1 = Blob.valueOf('123');
		Object b2 = Blob.valueOf('abc');

		try
		{
			new UTIL_Comparators.PrimitiveComparator().compare(b1, b2);
			Assert.fail(String.format(MSG_EXPECTED_EXCEPTION, new List<Object> {'Blob comparison'}));
		}
		catch(IllegalArgumentException exp)
		{
			Assert.isInstanceOfType(exp, IllegalArgumentException.class,
					String.format(MSG_EXPECTED_EXCEPTION, new List<Object> {'Blob comparison'}));
		}
	}

	/**
	 * @description Tests the PrimitiveComparator with Boolean values.
	 *
	 * @see UTIL_Comparators.PrimitiveComparator
	 */
	@IsTest
	private static void primitiveComparatorBoolean()
	{
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), false, true, LESS);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), true, true, EQUAL);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), false, false, EQUAL);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), true, false, GREATER);
	}

	/**
	 * @description Tests the PrimitiveComparator with Date values.
	 *
	 * @see UTIL_Comparators.PrimitiveComparator
	 */
	@IsTest
	private static void primitiveComparatorDate()
	{
		Date d1 = Date.newInstance(1980, 2, 17);
		Date d2 = Date.newInstance(1981, 2, 17);

		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), d1, d2, LESS);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), d1, d1, EQUAL);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), d2, d1, GREATER);
	}

	/**
	 * @description Tests the PrimitiveComparator with Datetime values.
	 *
	 * @see UTIL_Comparators.PrimitiveComparator
	 */
	@IsTest
	private static void primitiveComparatorDatetime()
	{
		Datetime d1 = Datetime.newInstance(2008, 12, 1, 12, 30, 1);
		Datetime d2 = Datetime.newInstance(2008, 12, 1, 12, 30, 2);

		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), d1, d2, LESS);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), d1, d1, EQUAL);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), d2, d1, GREATER);
	}

	/**
	 * @description Tests the PrimitiveComparator with Decimal values.
	 *
	 * @see UTIL_Comparators.PrimitiveComparator
	 */
	@IsTest
	private static void primitiveComparatorDecimal()
	{
		Decimal d1 = 123.123;
		Decimal d2 = 125.125;

		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), d1, d2, LESS);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), d1, d1, EQUAL);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), d2, d1, GREATER);
	}

	/**
	 * @description Tests the PrimitiveComparator with Double values.
	 *
	 * @see UTIL_Comparators.PrimitiveComparator
	 */
	@IsTest
	private static void primitiveComparatorDouble()
	{
		Double d1 = 123.123;
		Double d2 = 125.125;

		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), d1, d2, LESS);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), d1, d1, EQUAL);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), d2, d1, GREATER);
	}

	/**
	 * @description Tests the PrimitiveComparator with Integer values.
	 *
	 * @see UTIL_Comparators.PrimitiveComparator
	 */
	@IsTest
	private static void primitiveComparatorInteger()
	{
		Integer i1 = -10;
		Integer i2 = 15;

		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), i1, i2, LESS);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), i1, i1, EQUAL);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), i2, i1, GREATER);
	}

	/**
	 * @description Tests the PrimitiveComparator with Long values.
	 *
	 * @see UTIL_Comparators.PrimitiveComparator
	 */
	@IsTest
	private static void primitiveComparatorLong()
	{
		Long i1 = -10;
		Long i2 = 15;

		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), i1, i2, LESS);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), i1, i1, EQUAL);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), i2, i1, GREATER);
	}

	/**
	 * @description Tests the PrimitiveComparator with null values.
	 *
	 * @see UTIL_Comparators.PrimitiveComparator
	 */
	@IsTest
	private static void primitiveComparatorNulls()
	{
		String aNull = null;
		Object aNullO = aNull;
		Object xyz = 'xyz';

		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), aNullO, xyz, LESS);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), aNullO, aNullO, EQUAL);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), xyz, aNullO, GREATER);
	}

	/**
	 * @description Tests the PrimitiveComparator with String values.
	 *
	 * @see UTIL_Comparators.PrimitiveComparator
	 */
	@IsTest
	private static void primitiveComparatorString()
	{
		String s1 = 'abc';
		String s2 = 'def';

		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), s1, s2, LESS);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), s1, s1, EQUAL);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), s2, s1, GREATER);
	}

	/**
	 * @description Tests the PrimitiveComparator with Time values.
	 *
	 * @see UTIL_Comparators.PrimitiveComparator
	 */
	@IsTest
	private static void primitiveComparatorTime()
	{
		Time t1 = Time.newInstance(18, 30, 2, 20);
		Time t2 = Time.newInstance(18, 30, 2, 21);

		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), t1, t2, LESS);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), t2, t2, EQUAL);
		assertObjectComparison(new UTIL_Comparators.PrimitiveComparator(), t2, t1, GREATER);
	}

	/**
	 * @description Tests sorting SObjects by a field in ascending order.
	 *
	 * @see UTIL_Comparators.SObjectFieldComparator
	 */
	@IsTest
	private static void sortListSObject()
	{
		List<SObject> unsorted = createUnsortedList();
		UTIL_Comparators.SObjectFieldComparator comparator = new UTIL_Comparators.SObjectFieldComparator();

		List<SObject> sorted = comparator.sortSObjects(unsorted);

		assertSortedList(sorted, FIELD_NAME, new List<Object> {'A', 'B', 'C', 'D'});
	}

	/**
	 * @description Tests sorting SObjects by a field in descending order.
	 *
	 * @see UTIL_Comparators.SObjectFieldComparator
	 */
	@IsTest
	private static void sortListSObjectBoolean()
	{
		List<SObject> unsorted = createUnsortedList();
		UTIL_Comparators.SObjectFieldComparator comparator = new UTIL_Comparators.SObjectFieldComparator();

		List<SObject> sorted = comparator.sortSObjects(unsorted, false);

		assertSortedList(sorted, FIELD_NAME, new List<Object> {'D', 'C', 'B', 'A'});
	}

	/**
	 * @description Tests sorting SObjects by a numeric field in ascending order.
	 *
	 * @see UTIL_Comparators.SObjectFieldComparator
	 */
	@IsTest
	private static void sortListSObjectString()
	{
		List<SObject> unsorted = createUnsortedList();
		UTIL_Comparators.SObjectFieldComparator comparator = new UTIL_Comparators.SObjectFieldComparator();

		List<SObject> sorted = comparator.sortSObjects(unsorted, FIELD_NUMBER);

		assertSortedList(sorted, FIELD_NUMBER, new List<Object> {0, 1, 2, 3});
	}

	/**
	 * @description Tests sorting SObjects by a numeric field in descending order.
	 *
	 * @see UTIL_Comparators.SObjectFieldComparator
	 */
	@IsTest
	private static void sortListSObjectStringBoolean()
	{
		List<SObject> unsorted = createUnsortedList();
		UTIL_Comparators.SObjectFieldComparator comparator = new UTIL_Comparators.SObjectFieldComparator();

		List<SObject> sorted = comparator.sortSObjects(unsorted, FIELD_NUMBER, false);

		assertSortedList(sorted, FIELD_NUMBER, new List<Object> {3, 2, 1, 0});
	}

	/**
	 * @description Asserts the comparison result for an Object comparator and inputs.
	 *
	 * @param objectComparator The comparator implementing Comparator<Object>.
	 * @param o1 The first object to compare.
	 * @param o2 The second object to compare.
	 * @param expected The expected comparison result.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static void assertObjectComparison(Comparator<Object> objectComparator, Object o1, Object o2, Integer expected)
	{
		Integer actual = objectComparator.compare(o1, o2);
		Assert.areEqual(expected, actual, String.format(MSG_WRONG_COMPARISON, new List<Object> {expected, o1, o2, actual}));
	}

	/**
	 * @description Asserts the comparison result for an SObject comparator and inputs.
	 *
	 * @param comparator The comparator implementing Comparator<SObject>.
	 * @param o1 The first SObject to compare.
	 * @param o2 The second SObject to compare.
	 * @param expected The expected comparison result.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static void assertSObjectComparison(Comparator<SObject> comparator, SObject o1, SObject o2, Integer expected)
	{
		Integer actual = comparator.compare(o1, o2);
		Assert.areEqual(expected, actual, String.format(MSG_WRONG_COMPARISON, new List<Object> {expected, o1, o2, actual}));
	}

	/**
	 * @description Asserts that a sorted list matches the expected values for a given field.
	 *
	 * @param sorted The sorted list of SObjects.
	 * @param fieldName The field to check.
	 * @param expectedValues The expected values in order.
	 */
	private static void assertSortedList(List<SObject> sorted, String fieldName, List<Object> expectedValues)
	{
		Assert.isNotNull(sorted, 'Sorted list should not be null');
		Assert.areEqual(expectedValues.size(), sorted.size(), 'Sorted list size should match expected');
		for(Integer i = 0; i < sorted.size(); i++)
		{
			Object actual = sorted.get(i).get(fieldName);
			Assert.areEqual(expectedValues[i], actual,
					String.format(MSG_WRONG_SORT, new List<Object> {fieldName, i, expectedValues[i], actual}));
		}
	}

	/**
	 * @description Creates an unsorted list of SObjects for testing.
	 *
	 * @return List of unsorted SObjects.
	 */
	private static List<SObject> createUnsortedList()
	{
		return new List<SObject>
		{
				newFoobarWithNameAndDecimal('A', 2),
				newFoobarWithNameAndDecimal('D', 3),
				newFoobarWithNameAndDecimal('C', 0),
				newFoobarWithNameAndDecimal('B', 1)
		};
	}

	private static Foobar__c newFoobarWithNameAndDecimal(String name, Decimal numberDecimal)
	{
		Foobar__c foobar = TST_Factory.newFoobarWithName(name);
		foobar.NumberDecimal__c = numberDecimal;
		return foobar;
	}
}