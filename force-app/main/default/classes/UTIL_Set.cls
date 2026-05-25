// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Provides utility methods for manipulating sets,
 * including type conversions, collection transformations, and case operations.
 *
 * @see UTIL_Set_TEST
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
public inherited sharing class UTIL_Set
{
	/**
	 * @description Converts a set of Objects to a set of Ids, including only Id instances.
	 *
	 * @param objectSet The input set of Objects.
	 *
	 * @return A set of Ids, or null if the input is null.
	 *
	 * @example
	 * ```apex
	 * Set<Object> inputSet = new Set<Object>{'0013X00000M8HkqQAF', 'string'};
	 * Set<Id> result = UTIL_Set.extractIds(inputSet);
	 * System.debug(result); // Outputs: {0013X00000M8HkqQAF}
	 * ```
	 */
	public static Set<Id> extractIds(Set<Object> objectSet)
	{
		if(objectSet == null)
		{
			return null;
		}
		Set<Id> idSet = new Set<Id>();
		for(Object anObject : objectSet)
		{
			if(anObject instanceof Id)
			{
				idSet.add((Id)anObject);
			}
		}
		return idSet;
	}

	/**
	 * @description Converts a set of Ids to a set of Objects.
	 *
	 * @param idSet The input set of Ids.
	 *
	 * @return A set of Objects containing all Id values, or null if the input is null.
	 *
	 * @example
	 * ```apex
	 * Set<Id> inputSet = new Set<Id>{'0013X00000M8HkqQAF'};
	 * Set<Object> result = UTIL_Set.idToObject(inputSet);
	 * System.debug(result); // Outputs: {0013X00000M8HkqQAF}
	 * ```
	 */
	public static Set<Object> idToObject(Set<Id> idSet)
	{
		if(idSet == null)
		{
			return null;
		}
		Set<Object> objectSet = new Set<Object>();
		for(Id aId : idSet)
		{
			objectSet.add(aId);
		}
		return objectSet;
	}

	/**
	 * @description Converts a set of Strings to a set of Objects.
	 *
	 * @param stringSet The input set of Strings.
	 *
	 * @return A set of Objects containing all String values, or null if the input is null.
	 *
	 * @example
	 * ```apex
	 * Set<String> inputSet = new Set<String>{'example', 'test'};
	 * Set<Object> result = UTIL_Set.stringToObject(inputSet);
	 * System.debug(result); // Outputs: {example, test}
	 * ```
	 */
	public static Set<Object> stringToObject(Set<String> stringSet)
	{
		if(stringSet == null)
		{
			return null;
		}
		Set<Object> objectSet = new Set<Object>();
		for(String aString : stringSet)
		{
			objectSet.add(aString);
		}
		return objectSet;
	}

	/**
	 * @description Converts a set of Strings to a list of Strings.
	 *
	 * @param stringSet The input set of Strings.
	 *
	 * @return A list of Strings, or null if the input is null.
	 *
	 * @example
	 * ```apex
	 * Set<String> inputSet = new Set<String>{'example', 'test'};
	 * List<String> result = UTIL_Set.toList(inputSet);
	 * System.debug(result); // Outputs: [example, test]
	 * ```
	 */
	public static List<String> toList(Set<String> stringSet)
	{
		List<String> returnValue = null;
		if(stringSet != null)
		{
			returnValue = new List<String>();
			if(stringSet.size() > 0)
			{
				for(String value : stringSet)
				{
					returnValue.add(value);
				}
			}
		}
		return returnValue;
	}

	/**
	 * @description Converts a list of Strings to a set of Strings, removing duplicates.
	 *
	 * @param stringList The input list of Strings.
	 *
	 * @return A set of unique Strings, or null if the input is null.
	 *
	 * @example
	 * ```apex
	 * List<String> inputList = new List<String>{'example', 'example', 'test'};
	 * Set<String> result = UTIL_Set.toSet(inputList);
	 * System.debug(result); // Outputs: {example, test}
	 * ```
	 */
	public static Set<String> toSet(List<String> stringList)
	{
		Set<String> returnValue = null;
		if(stringList != null)
		{
			returnValue = new Set<String>();
			if(stringList.size() > 0)
			{
				for(String value : stringList)
				{
					returnValue.add(value);
				}
			}
		}
		return returnValue;
	}

	/**
	 * @description Converts all strings in a set to lowercase.
	 *
	 * @param stringSet The input set of Strings.
	 *
	 * @return A set of lowercase Strings, or null if the input is null.
	 *
	 * @example
	 * ```apex
	 * Set<String> inputSet = new Set<String>{'Example', 'TEST'};
	 * Set<String> result = UTIL_Set.lowerCase(inputSet);
	 * System.debug(result); // Outputs: {example, test}
	 * ```
	 */
	public static Set<String> lowerCase(Set<String> stringSet)
	{
		Set<String> returnValue = null;
		if(stringSet != null)
		{
			returnValue = new Set<String>();
			for(String str : stringSet)
			{
				returnValue.add(str?.toLowerCase().trim());
			}
		}
		return returnValue;
	}

	/**
	 * @description Converts a Set<Id> into a List<Id>.
	 *
	 * @param aSet A set of Salesforce record IDs
	 *
	 * @return A list containing the IDs from the input set, or null if input is null
	 *
	 * @example
	 * ```apex
	 * Set<Id> idSet = new Set<Id>{ accountId1, accountId2 };
	 * List<Id> idList = UTIL_Set.toList(idSet);
	 * ```
	 */
	public static List<Id> toList(Set<Id> aSet)
	{
		return aSet != null ? new List<Id>(aSet) : null;
	}
}