// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Various list utilities for manipulating lists of objects and SObjects.
 *
 * This class provides methods for converting, transforming, sorting, and partitioning lists,
 * as well as utility methods for checking emptiness and creating typed lists.
 *
 * @see UTIL_List_TEST
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
 * Boolean empty = UTIL_List.isEmpty(records);
 * List<List<SObject>> batches = UTIL_List.partition(records, 200);
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessivePublicCount,PMD.ApexUnitTestClassShouldHaveRunAs,PMD.AvoidGlobalModifier')
global inherited sharing class UTIL_List
{
	/**
	 * @description Filters string instances from a list of objects, returning only String elements.
	 *
	 * @param objects The list of objects to filter.
	 *
	 * @return A list containing only the String elements, or an empty list if the input is null.
	 *
	 * @example
	 * ```apex
	 * List<Object> inputs = new List<Object>{'Hello', 123, 'World'};
	 * List<String> strings = UTIL_List.filterStrings(inputs);
	 * System.debug(strings); // Outputs: ['Hello', 'World']
	 * ```
	 */
	public static List<String> filterStrings(List<Object> objects)
	{
		List<String> strings = new List<String>();
		if(objects != null)
		{
			for(Object obj : objects)
			{
				if(obj instanceof String)
				{
					strings.add((String)obj);
				}
			}
		}
		return strings;
	}

	/**
	 * @description Checks if an object array is empty or null.
	 *
	 * @param items The array to check.
	 *
	 * @return True if the array is null or empty, false otherwise.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Object> emptyList = new List<Object>();
	 * Boolean isEmpty = UTIL_List.isEmpty(emptyList);
	 * System.debug(isEmpty); // Outputs: true
	 * ```
	 */
	global static Boolean isEmpty(List<Object> items)
	{
		if(items == null)
		{
			return true;
		}
		return items.isEmpty();
	}

	/**
	 * @description Checks if an object array is not empty.
	 *
	 * @param items The array to check.
	 *
	 * @return True if the array is not null and not empty, false otherwise.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Object> numbers = new List<Object>{1, 2};
	 * Boolean isNotEmpty = UTIL_List.isNotEmpty(numbers);
	 * System.debug(isNotEmpty); // Outputs: true
	 * ```
	 */
	global static Boolean isNotEmpty(List<Object> items)
	{
		return !isEmpty(items);
	}

	/**
	 * @description Sorts an SObject list using a custom SObject comparator.
	 *
	 * @param records The SObject list to sort.
	 * @param comparator The SObject comparator to use for sorting.
	 *
	 * @return A sorted SObject list, or an empty list if the input is null.
	 *
	 * @example
	 * ```apex
	 * List<Account> accounts = new List<Account>{new Account(Name='B'), new Account(Name='A')};
	 * UTIL_Comparators.SObjectComparator comp = new UTIL_Comparators.SObjectFieldComparator('Name', true);
	 * List<Account> sorted = UTIL_List.sort(accounts, comp);
	 * System.debug(sorted[0].Name); // Outputs: 'A'
	 * ```
	 */
	public static List<SObject> sort(List<SObject> records, UTIL_Comparators.SObjectComparator comparator)
	{
		if(records == null)
		{
			return new List<SObject>();
		}
		List<SObject> sortedSObjectList = records.clone();
		sortedSObjectList.sort(comparator);
		return sortedSObjectList;
	}

	/**
	 * @description Pushes an element onto the end of the list (stack push operation).
	 *
	 * @param stack The list to push onto.
	 * @param element The element to push.
	 *
	 * @example
	 * ```apex
	 * List<Object> stack = new List<Object>();
	 * UTIL_List.push(stack, 'first');
	 * UTIL_List.push(stack, 'second');
	 * System.debug(stack); // Outputs: ['first', 'second']
	 * ```
	 */
	public static void push(List<Object> stack, Object element)
	{
		stack.add(element);
	}

	/**
	 * @description Removes and returns the last element from the list (stack pop operation).
	 *
	 * @param stack The list to pop from.
	 *
	 * @return The removed element, or null if the list is empty.
	 *
	 * @example
	 * ```apex
	 * List<Object> stack = new List<Object>{'first', 'second'};
	 * Object popped = UTIL_List.pop(stack);
	 * System.debug(popped); // Outputs: 'second'
	 * System.debug(stack); // Outputs: ['first']
	 * ```
	 */
	public static Object pop(List<Object> stack)
	{
		if(isEmpty(stack))
		{
			return null;
		}
		return stack.remove(stack.size() - 1);
	}

	/**
	 * @description Returns the last element without removing it (stack peek operation).
	 *
	 * @param stack The list to peek.
	 *
	 * @return The last element, or null if the list is empty.
	 *
	 * @example
	 * ```apex
	 * List<Object> stack = new List<Object>{'first', 'second'};
	 * Object top = UTIL_List.peek(stack);
	 * System.debug(top); // Outputs: 'second'
	 * System.debug(stack.size()); // Outputs: 2 (unchanged)
	 * ```
	 */
	public static Object peek(List<Object> stack)
	{
		return isEmpty(stack) ? null : peekAt(stack, stack.size() - 1);
	}

	/**
	 * @description Returns the element at the specified index without removing it.
	 *
	 * @param stack The list to peek.
	 * @param index The index to peek at (0 = bottom of stack).
	 *
	 * @return The element at the index, or null if index is out of bounds.
	 *
	 * @example
	 * ```apex
	 * List<Object> stack = new List<Object>{'first', 'second', 'third'};
	 * Object element = UTIL_List.peekAt(stack, 1);
	 * System.debug(element); // Outputs: 'second'
	 * ```
	 */
	public static Object peekAt(List<Object> stack, Integer index)
	{
		if(isEmpty(stack) || index < 0 || index >= stack.size())
		{
			return null;
		}
		return stack.get(index);
	}

	/**
	 * @description Returns the first element without removing it (bottom of stack).
	 *
	 * @param stack The list to peek.
	 *
	 * @return The first element, or null if the list is empty.
	 *
	 * @example
	 * ```apex
	 * List<Object> stack = new List<Object>{'first', 'second', 'third'};
	 * Object bottom = UTIL_List.peekFirst(stack);
	 * System.debug(bottom); // Outputs: 'first'
	 * ```
	 */
	public static Object peekFirst(List<Object> stack)
	{
		return peekAt(stack, 0);
	}

	/**
	 * @description Partitions a list into smaller lists of the specified size.
	 *
	 * @param objects A list of objects
	 * @param partitionSize The maximum size of each sub-list
	 *
	 * @return A list of sub-lists, each no larger than partitionSize
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<List<Object>> batches = UTIL_List.partition(records, 200);
	 * ```
	 */
	global static List<List<Object>> partition(List<Object> objects, Integer partitionSize)
	{
		if(objects == null)
		{
			return new List<List<Object>>();
		}

		if(partitionSize <= 0)
		{
			return new List<List<Object>> {objects};
		}

		List<List<Object>> objectPartitions = new List<List<Object>>();

		if(objects.size() > partitionSize)
		{
			List<Object> partitionObjects;
			Integer partitionCount = (Integer)Math.ceil(Decimal.valueOf(objects.size()).divide(Math.max(partitionSize, 1), 1));

			for(Integer partitionIndex = 0; partitionIndex < partitionCount; partitionIndex++)
			{
				partitionObjects = new List<Object>();

				for
				(
						Integer elementIndex = partitionIndex * partitionSize;
						(elementIndex < (partitionIndex * partitionSize) + partitionSize) && elementIndex < objects.size();
						elementIndex++
				)
				{
					partitionObjects.add(objects.get(elementIndex));
				}

				objectPartitions.add(partitionObjects);
			}
		}
		else
		{
			objectPartitions.add(objects);
		}

		return objectPartitions;
	}
}