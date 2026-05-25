// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Checks the behaviour of the set utility methods
 *
 * @see UTIL_Set
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_Set_TEST
{
	private static final String A_TO_C = 'abc';
	private static final String A_TO_D = A_TO_C + 'd';
	private static final String A_TO_D_UPPER = A_TO_D.toUpperCase();

	/**
	 * @description Verifies that lowerCase converts all strings in a set to lowercase.
	 */
	@IsTest
	private static void lowerCaseSetString()
	{
		Assert.areEqual(null, UTIL_Set.lowerCase(null), 'lowerCase(null) should return null');
		Assert.areEqual(new Set<String>(), UTIL_Set.lowerCase(new Set<String>()), 'lowerCase of empty set should return empty set');
		Assert.areEqual(new Set<String> {'a', 'b', A_TO_D}, UTIL_Set.lowerCase(new Set<String> {'A', 'B', A_TO_D_UPPER}), 'lowerCase should fold every entry to lower-case');
	}

	/**
	 * @description Verifies that extractIds converts a set of Objects containing Ids to a set of Ids,
	 * returning null for null input and preserving all Id values.
	 */
	@IsTest
	private static void shouldExtractIdsFromObjectSet()
	{
		assertExtractIds(null, null);
		assertExtractIds(new Set<Object> {}, new Set<Id> {});

		Foobar__c foo1 = TST_Factory.newFoobarWithMockId();
		Foobar__c foo2 = TST_Factory.newFoobarWithMockId();

		assertExtractIds(new Set<Object> {foo1.Id}, new Set<Id> {foo1.Id});
		assertExtractIds(new Set<Object> {foo1.Id, foo2.Id}, new Set<Id> {foo1.Id, foo2.Id});
	}

	private static void assertExtractIds(Set<Object> objectSet, Set<Id> expected)
	{
		Assert.isTrue(!((objectSet == null && expected != null) || (objectSet != null && expected == null)),
				'Invalid test input: both parameters should be null.');
		Set<Id> actual = UTIL_Set.extractIds(objectSet);
		Assert.isTrue(!(objectSet == null && expected == null && actual != null),
				'UTIL_Set.extractIds(null) returned ' + String.valueOf(actual) + '; expected null');
		if(expected != null && actual != null)
		{
			Assert.isTrue(actual.containsAll(expected) && expected.containsAll(actual),
					'UTIL_Set.extractIds(' + String.valueOf(objectSet) + ') returned ' + String.valueOf(actual) + '; expected '
					+ String.valueOf(expected));
		}
	}

	/**
	 * @description Verifies that idToObject converts a set of Ids to a set of Objects,
	 * returning null for null input and preserving all values.
	 *
	 * @see UTIL_Set.idToObject
	 */
	@IsTest
	private static void shouldConvertIdSetToObjectSet()
	{
		Assert.isNull(UTIL_Set.idToObject(null), 'Null input should return null');
		Assert.isTrue(UTIL_Set.idToObject(new Set<Id>()).isEmpty(), 'Empty set should return empty set');

		Foobar__c foobar1 = TST_Factory.newFoobarWithMockId();
		Foobar__c foobar2 = TST_Factory.newFoobarWithMockId();
		Set<Object> result = UTIL_Set.idToObject(new Set<Id> {foobar1.Id, foobar2.Id});

		Assert.areEqual(2, result.size(), 'Result should contain two elements');
		Assert.isTrue(result.contains(foobar1.Id), 'Result should contain the first Id value');
		Assert.isTrue(result.contains(foobar2.Id), 'Result should contain the second Id value');
	}

	/**
	 * @description Verifies that stringToObject converts a set of Strings to a set of Objects,
	 * returning null for null input and preserving all values.
	 *
	 * @see UTIL_Set.stringToObject
	 */
	@IsTest
	private static void shouldConvertStringSetToObjectSet()
	{
		Assert.isNull(UTIL_Set.stringToObject(null), 'Null input should return null');
		Assert.isTrue(UTIL_Set.stringToObject(new Set<String>()).isEmpty(), 'Empty set should return empty set');

		Set<Object> result = UTIL_Set.stringToObject(new Set<String> {'alpha', 'beta'});

		Assert.areEqual(2, result.size(), 'Result should contain two elements');
		Assert.isTrue(result.contains('alpha'), 'Result should contain the first String value');
		Assert.isTrue(result.contains('beta'), 'Result should contain the second String value');
	}

	/**
	 * @description Verifies that toList converts a Set of Strings to a List of Strings,
	 * returning null for null input.
	 */
	@IsTest
	private static void shouldConvertStringSetToList()
	{
		final Set<String> records = null;
		Assert.isNull(UTIL_Set.toList(records), 'Null set should convert to null list');
		Assert.areEqual(0, UTIL_Set.toList(new Set<String>()).size(), 'Empty set should convert to empty list');
		Assert.areEqual(1, UTIL_Set.toList(new Set<String> {''}).size(), 'Set with empty string should convert to list with one element');
		Assert.areEqual(1, UTIL_Set.toList(new Set<String> {'a'}).size(), 'Set with single string should convert to list with one element');
		Assert.areEqual(2, UTIL_Set.toList(new Set<String> {'a', 'b'}).size(), 'Set with two unique strings should convert to list with two elements');
		Assert.areEqual(1, UTIL_Set.toList(new Set<String> {'a', 'a'}).size(), 'Set with duplicate strings should convert to list with one element');
	}

	/**
	 * @description Verifies that toList converts a Set of Ids to a List of Ids,
	 * returning null for null input.
	 *
	 * @see UTIL_Set.toList
	 */
	@IsTest
	private static void shouldConvertIdSetToList()
	{
		final Set<Id> nullSet = null;
		Assert.isNull(UTIL_Set.toList(nullSet), 'Null Id set should return null list');

		Foobar__c foobar1 = TST_Factory.newFoobarWithMockId();
		Foobar__c foobar2 = TST_Factory.newFoobarWithMockId();

		List<Id> result = UTIL_Set.toList(new Set<Id> {foobar1.Id, foobar2.Id});

		Assert.areEqual(2, result.size(), 'Result list should contain two elements');
		Assert.isTrue(result.contains(foobar1.Id), 'Result list should contain the first Id');
		Assert.isTrue(result.contains(foobar2.Id), 'Result list should contain the second Id');
	}

	/**
	 * @description Verifies that toSet converts a List of Strings to a Set of Strings,
	 * returning null for null input and removing duplicates.
	 */
	@IsTest
	private static void shouldConvertStringListToSet()
	{
		final List<String> aList = null;
		Assert.isNull(UTIL_Set.toSet(aList), 'Expected null result when converting null list to set');
		Assert.areEqual(0, UTIL_Set.toSet(new List<String>()).size(), 'Empty list should convert to empty set');
		Assert.areEqual(1, UTIL_Set.toSet(new List<String> {''}).size(), 'Single empty string should convert to set with one element');
		Assert.areEqual(1, UTIL_Set.toSet(new List<String> {'a'}).size(), 'Single string should convert to set with one element');
		Assert.areEqual(2, UTIL_Set.toSet(new List<String> {'a', 'b'}).size(), 'Two unique strings should convert to set with two elements');
		Assert.areEqual(1, UTIL_Set.toSet(new List<String> {'a', 'a'}).size(), 'Duplicate strings should be removed in set conversion');
	}
}