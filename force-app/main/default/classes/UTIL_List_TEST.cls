// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Tests the behaviour of associated utility methods
 *
 * @see UTIL_List
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, November 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
@IsTest(seeAllData=false isParallel=true)
private class UTIL_List_TEST
{
	/**
	 * @description Failure message shown when a null list or a list with no items is not treated as empty.
	 */
	private static final String MSG_IS_EMPTY = 'List should be considered empty';
	/**
	 * @description Failure message shown when a list holding at least one item is treated as empty.
	 */
	private static final String MSG_NOT_EMPTY = 'List should be considered non-empty';
	/**
	 * @description Failure message shown when a helper that must always hand back a list returns null.
	 */
	private static final String MSG_NOT_NULL = 'Result should not be null';
	/**
	 * @description Failure message shown when a helper returns a value where the tests expect null, for example
	 * when taking an item from an empty list.
	 */
	private static final String MSG_NULL_RESULT = 'Result should be null';
	/**
	 * @description Failure message shown when a list does not hold the number of items the test expects.
	 */
	private static final String MSG_SIZE_EQUALITY = 'List size should match expected';
	/**
	 * @description Failure message shown when a returned item or list differs from the one the test expects.
	 */
	private static final String MSG_VALUE_EQUALITY = 'Value should match expected';

	/**
	 * @description Tests the isEmpty method for various list types
	 *
	 * @see UTIL_List.isEmpty
	 */
	@IsTest
	private static void isEmpty()
	{
		List<String> nullStringList = null;
		List<UTIL_NumberRange.IntegerRange> nullDecimalRangeList = null;
		Assert.isTrue(UTIL_List.isEmpty(nullStringList), MSG_IS_EMPTY);
		Assert.isTrue(UTIL_List.isEmpty(new List<String> {}), MSG_IS_EMPTY);
		Assert.isFalse(UTIL_List.isEmpty(new List<String> {'a'}), MSG_NOT_EMPTY);
		Assert.isFalse(UTIL_List.isEmpty(new List<String> {'a', 'b'}), MSG_NOT_EMPTY);
		Assert.isTrue(UTIL_List.isEmpty(new List<Integer> {}), MSG_IS_EMPTY);
		Assert.isFalse(UTIL_List.isEmpty(new List<Integer> {1}), MSG_NOT_EMPTY);
		Assert.isFalse(UTIL_List.isEmpty(new List<Integer> {1, 2}), MSG_NOT_EMPTY);
		Assert.isTrue(UTIL_List.isEmpty(nullDecimalRangeList), MSG_IS_EMPTY);
		Assert.isTrue(UTIL_List.isEmpty(new List<UTIL_NumberRange.IntegerRange> {}), MSG_IS_EMPTY);
		Assert.isFalse
				(
						UTIL_List.isEmpty(new List<UTIL_NumberRange.IntegerRange> {new UTIL_NumberRange.IntegerRange(1, 1)}),
						MSG_NOT_EMPTY
				);
	}

	/**
	 * @description Tests the isNotEmpty method for various list types
	 *
	 * @see UTIL_List.isNotEmpty
	 */
	@IsTest
	private static void isNotEmpty()
	{
		List<String> nullStringList = null;
		List<UTIL_NumberRange.IntegerRange> nullDecimalRangeList = null;
		Assert.isFalse(UTIL_List.isNotEmpty(nullStringList), 'Null string list should not be non-empty');
		Assert.isFalse(UTIL_List.isNotEmpty(new List<String> {}), 'Empty string list should not be non-empty');
		Assert.isTrue(UTIL_List.isNotEmpty(new List<String> {'a'}), MSG_NOT_EMPTY);
		Assert.isTrue(UTIL_List.isNotEmpty(new List<String> {'a', 'b'}), MSG_NOT_EMPTY);
		Assert.isFalse(UTIL_List.isNotEmpty(new List<Integer> {}), 'Empty integer list should not be non-empty');
		Assert.isTrue(UTIL_List.isNotEmpty(new List<Integer> {1}), MSG_NOT_EMPTY);
		Assert.isTrue(UTIL_List.isNotEmpty(new List<Integer> {1, 2}), MSG_NOT_EMPTY);
		Assert.isFalse(UTIL_List.isNotEmpty(nullDecimalRangeList), 'Null DecimalRange list should not be non-empty');
		Assert.isFalse(UTIL_List.isNotEmpty(new List<UTIL_NumberRange.IntegerRange> {}), 'Empty DecimalRange list should not be non-empty');
		Assert.isTrue
				(
						UTIL_List.isNotEmpty(new List<UTIL_NumberRange.IntegerRange>
						{
								new UTIL_NumberRange.IntegerRange(1, 1)
						}), MSG_NOT_EMPTY
				);
	}

	/**
	 * @description Tests the conversion of objects to strings by filtering
	 *
	 * @see UTIL_List.filterStrings
	 */
	@IsTest
	private static void filterStrings()
	{
		Assert.areEqual(new List<String>(), UTIL_List.filterStrings(null), 'Null input should return empty list');
		Assert.areEqual(new List<String> {}, UTIL_List.filterStrings(new List<Object> {}), MSG_VALUE_EQUALITY);
		final String str1 = 'xyz';
		final String str2 = 'abc';
		Assert.areEqual(new List<String> {str1}, UTIL_List.filterStrings(new List<Object> {str1}), MSG_VALUE_EQUALITY);
		Assert.areEqual(new List<String> {str1, str2}, UTIL_List.filterStrings(new List<Object> {str1, str2}), MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests push and pop stack operations
	 *
	 * @see UTIL_List.push
	 * @see UTIL_List.pop
	 */
	@IsTest
	private static void pushAndPop()
	{
		List<Object> stack = new List<Object>();

		UTIL_List.push(stack, 'first');
		UTIL_List.push(stack, 'second');
		UTIL_List.push(stack, 'third');

		Assert.areEqual(3, stack.size(), MSG_SIZE_EQUALITY);

		Object popped = UTIL_List.pop(stack);
		Assert.areEqual('third', popped, MSG_VALUE_EQUALITY);
		Assert.areEqual(2, stack.size(), MSG_SIZE_EQUALITY);

		popped = UTIL_List.pop(stack);
		Assert.areEqual('second', popped, MSG_VALUE_EQUALITY);

		popped = UTIL_List.pop(stack);
		Assert.areEqual('first', popped, MSG_VALUE_EQUALITY);

		Assert.isTrue(stack.isEmpty(), MSG_IS_EMPTY);
	}

	/**
	 * @description Tests pop on an empty list returns null
	 *
	 * @see UTIL_List.pop
	 */
	@IsTest
	private static void popEmptyList()
	{
		List<Object> emptyStack = new List<Object>();

		Object result = UTIL_List.pop(emptyStack);

		Assert.isNull(result, MSG_NULL_RESULT);
	}

	/**
	 * @description Tests peek returns last element without removing it
	 *
	 * @see UTIL_List.peek
	 */
	@IsTest
	private static void peek()
	{
		List<Object> stack = new List<Object> {'first', 'second', 'third'};

		Object top = UTIL_List.peek(stack);

		Assert.areEqual('third', top, MSG_VALUE_EQUALITY);
		Assert.areEqual(3, stack.size(), 'Peek should not modify the list');
	}

	/**
	 * @description Tests peek on an empty list returns null
	 *
	 * @see UTIL_List.peek
	 */
	@IsTest
	private static void peekEmptyList()
	{
		List<Object> emptyStack = new List<Object>();

		Object result = UTIL_List.peek(emptyStack);

		Assert.isNull(result, MSG_NULL_RESULT);
	}

	/**
	 * @description Tests peekAt at specific index
	 *
	 * @see UTIL_List.peekAt
	 */
	@IsTest
	private static void peekAtIndex()
	{
		List<Object> stack = new List<Object> {'first', 'second', 'third'};

		Assert.areEqual('first', UTIL_List.peekAt(stack, 0), MSG_VALUE_EQUALITY);
		Assert.areEqual('second', UTIL_List.peekAt(stack, 1), MSG_VALUE_EQUALITY);
		Assert.areEqual('third', UTIL_List.peekAt(stack, 2), MSG_VALUE_EQUALITY);
		Assert.isNull(UTIL_List.peekAt(stack, -1), 'Negative index should return null');
		Assert.isNull(UTIL_List.peekAt(stack, 3), 'Out of bounds index should return null');
	}

	/**
	 * @description Tests peekFirst returns first element
	 *
	 * @see UTIL_List.peekFirst
	 */
	@IsTest
	private static void peekFirst()
	{
		List<Object> stack = new List<Object> {'first', 'second', 'third'};

		Object bottom = UTIL_List.peekFirst(stack);

		Assert.areEqual('first', bottom, MSG_VALUE_EQUALITY);
		Assert.areEqual(3, stack.size(), 'PeekFirst should not modify the list');
	}

	/**
	 * @description Tests peekFirst on an empty list returns null
	 *
	 * @see UTIL_List.peekFirst
	 */
	@IsTest
	private static void peekFirstEmptyList()
	{
		List<Object> emptyStack = new List<Object>();

		Object result = UTIL_List.peekFirst(emptyStack);

		Assert.isNull(result, MSG_NULL_RESULT);
	}

	/**
	 * @description Tests that sort sorts SObject records using a field comparator
	 *
	 * @see UTIL_List.sort
	 */
	@IsTest
	private static void shouldSortSObjectsByField()
	{
		Foobar__c recordB = TST_Factory.newFoobarWithName('B');
		Foobar__c recordA = TST_Factory.newFoobarWithName('A');
		Foobar__c recordC = TST_Factory.newFoobarWithName('C');
		List<SObject> unsorted = new List<SObject> {recordB, recordA, recordC};

		List<SObject> sorted = UTIL_List.sort(unsorted, new UTIL_Comparators.SObjectFieldComparator('Name', true));

		Assert.isNotNull(sorted, MSG_NOT_NULL);
		Assert.areEqual(3, sorted.size(), MSG_SIZE_EQUALITY);
		Assert.areEqual('A', ((Foobar__c)sorted[0]).Name, MSG_VALUE_EQUALITY);
		Assert.areEqual('B', ((Foobar__c)sorted[1]).Name, MSG_VALUE_EQUALITY);
		Assert.areEqual('C', ((Foobar__c)sorted[2]).Name, MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests that sort returns an empty list for null input
	 *
	 * @see UTIL_List.sort
	 */
	@IsTest
	private static void shouldReturnEmptyListWhenSortingSObjectsWithNullInput()
	{
		List<SObject> result = UTIL_List.sort(null, new UTIL_Comparators.SObjectFieldComparator('Name', true));

		Assert.areEqual(new List<SObject>(), result, 'Null input should return empty list');
	}

	/**
	 * @description Tests that partition returns an empty list when input is null
	 *
	 * @see UTIL_List.partition
	 */
	@IsTest
	private static void shouldReturnEmptyListWhenPartitioningNullInput()
	{
		List<List<Object>> result = UTIL_List.partition(null, 5);

		Assert.isTrue(result.isEmpty(), 'Null input should return empty list');
	}

	/**
	 * @description Tests that partition returns the full list as a single sublist when partition size is zero or negative
	 *
	 * @see UTIL_List.partition
	 */
	@IsTest
	private static void shouldReturnSingleSublistWhenPartitionSizeIsZeroOrNegative()
	{
		List<Object> items = new List<Object> {'alpha', 'beta'};

		List<List<Object>> zeroResult = UTIL_List.partition(items, 0);
		Assert.areEqual(1, zeroResult.size(), 'Zero partition size should return single sublist');
		Assert.areEqual(2, zeroResult[0].size(), MSG_SIZE_EQUALITY);

		List<List<Object>> negativeResult = UTIL_List.partition(items, -1);
		Assert.areEqual(1, negativeResult.size(), 'Negative partition size should return single sublist');
		Assert.areEqual(2, negativeResult[0].size(), MSG_SIZE_EQUALITY);
	}

	/**
	 * @description Tests that partition divides objects into smaller sublists of the specified size
	 *
	 * @see UTIL_List.partition
	 */
	@IsTest
	private static void shouldPartitionObjectsIntoSublists()
	{
		List<Object> items = new List<Object> {'alpha', 'beta', 'gamma', 'delta', 'epsilon'};

		List<List<Object>> result = UTIL_List.partition(items, 2);

		Assert.areEqual(3, result.size(), 'Should produce three sublists');
		Assert.areEqual(2, result[0].size(), 'First sublist should contain two items');
		Assert.areEqual(2, result[1].size(), 'Second sublist should contain two items');
		Assert.areEqual(1, result[2].size(), 'Third sublist should contain one item');
	}

	/**
	 * @description Tests that partition returns a single sublist when the object list is smaller than partition size
	 *
	 * @see UTIL_List.partition
	 */
	@IsTest
	private static void shouldReturnSingleSublistWhenObjectListFitsWithinPartitionSize()
	{
		List<Object> items = new List<Object> {'alpha', 'beta'};

		List<List<Object>> result = UTIL_List.partition(items, 10);

		Assert.areEqual(1, result.size(), 'Should produce a single sublist');
		Assert.areEqual(2, result[0].size(), MSG_SIZE_EQUALITY);
	}

	/**
	 * @description An empty list gives one empty part. The caller always gets a list it can loop over.
	 *
	 * @see UTIL_List.partition
	 */
	@IsTest
	private static void shouldReturnOneEmptySublistWhenPartitioningAnEmptyList()
	{
		List<List<Object>> result = UTIL_List.partition(new List<Object>(), 5);

		Assert.areEqual(1, result.size(), 'Expected one sublist for an empty list.');
		Assert.isTrue(result[0].isEmpty(), 'Expected the one sublist to be empty.');
	}

	/**
	 * @description A list one item longer than the part size gives two parts. No item is lost.
	 *
	 * @see UTIL_List.partition
	 */
	@IsTest
	private static void shouldKeepEveryItemWhenPartitioning201ItemsBy200()
	{
		assertPartitionKeepsEveryItem(201, 200, 2);
	}

	/**
	 * @description A list a few items over the part size gives two parts. No item is lost.
	 *
	 * @see UTIL_List.partition
	 */
	@IsTest
	private static void shouldKeepEveryItemWhenPartitioning210ItemsBy200()
	{
		assertPartitionKeepsEveryItem(210, 200, 2);
	}

	/**
	 * @description A list eleven items over the part size gives two parts. No item is lost.
	 *
	 * @see UTIL_List.partition
	 */
	@IsTest
	private static void shouldKeepEveryItemWhenPartitioning211ItemsBy200()
	{
		assertPartitionKeepsEveryItem(211, 200, 2);
	}

	/**
	 * @description A list one item over two full parts gives three parts. No item is lost.
	 *
	 * @see UTIL_List.partition
	 */
	@IsTest
	private static void shouldKeepEveryItemWhenPartitioning401ItemsBy200()
	{
		assertPartitionKeepsEveryItem(401, 200, 3);
	}

	/**
	 * @description A list ten items over two full parts gives three parts. No item is lost.
	 *
	 * @see UTIL_List.partition
	 */
	@IsTest
	private static void shouldKeepEveryItemWhenPartitioning410ItemsBy200()
	{
		assertPartitionKeepsEveryItem(410, 200, 3);
	}

	/**
	 * @description A list two items over a part size of 50 gives two parts. No item is lost.
	 *
	 * @see UTIL_List.partition
	 */
	@IsTest
	private static void shouldKeepEveryItemWhenPartitioning52ItemsBy50()
	{
		assertPartitionKeepsEveryItem(52, 50, 2);
	}

	/**
	 * @description A list one item over a small part size of 19 gives two parts. No item is lost.
	 *
	 * @see UTIL_List.partition
	 */
	@IsTest
	private static void shouldKeepEveryItemWhenPartitioning20ItemsBy19()
	{
		assertPartitionKeepsEveryItem(20, 19, 2);
	}

	/**
	 * @description A part size of 1 gives one part for each item. No item is lost.
	 *
	 * @see UTIL_List.partition
	 */
	@IsTest
	private static void shouldKeepEveryItemWhenPartitioning3ItemsBy1()
	{
		assertPartitionKeepsEveryItem(3, 1, 3);
	}

	/**
	 * @description A list exactly as long as the part size gives one part. No item is lost.
	 *
	 * @see UTIL_List.partition
	 */
	@IsTest
	private static void shouldKeepEveryItemWhenPartitioning200ItemsBy200()
	{
		assertPartitionKeepsEveryItem(200, 200, 1);
	}

	/**
	 * @description A list that fills two parts exactly gives two parts. No empty part is added.
	 *
	 * @see UTIL_List.partition
	 */
	@IsTest
	private static void shouldKeepEveryItemWhenPartitioning400ItemsBy200()
	{
		assertPartitionKeepsEveryItem(400, 200, 2);
	}

	/**
	 * @description Partitions a numbered list and checks the number of parts, the size of each part and that the parts
	 * joined together give back the list in its original order.
	 *
	 * @param itemCount The number of items in the list
	 * @param partitionSize The largest size of one part
	 * @param expectedPartCount The number of parts the list must give
	 */
	private static void assertPartitionKeepsEveryItem(Integer itemCount, Integer partitionSize, Integer expectedPartCount)
	{
		List<Object> items = new List<Object>();
		for(Integer index = 0; index < itemCount; index++)
		{
			items.add(index);
		}

		List<List<Object>> result = UTIL_List.partition(items, partitionSize);

		Assert.areEqual(expectedPartCount, result.size(), 'Expected ' + expectedPartCount + ' parts for ' + itemCount + ' items of part size ' + partitionSize + '.');

		List<Object> joined = new List<Object>();
		for(List<Object> part : result)
		{
			Assert.isTrue(part.size() <= partitionSize, 'Expected every part to hold at most ' + partitionSize + ' items, got ' + part.size() + '.');
			joined.addAll(part);
		}
		Assert.areEqual(items, joined, 'Expected the parts joined together to equal the list, in order.');
	}
}
