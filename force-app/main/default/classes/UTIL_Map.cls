// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Static helper methods for common Map operations in Apex, including key-value transformation,
 * entry joining, equality comparison, SObject indexing, and case-insensitive lookups.
 *
 * @see UTIL_Map_TEST
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
 * Map<String, String> params = new Map<String, String>{'key' => 'value', 'name' => 'test'};
 * String delimited = UTIL_Map.toDelimitedString(params, ',');
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.AvoidGlobalModifier')
global inherited sharing class UTIL_Map
{
	/**
	 * @description Collapses an Id-keyed map of SObject lists into a single flat list containing every record.
	 *
	 * @param idMap A map where the value is a list of SObjects and the key is an Id
	 *
	 * @return A list containing all the SObjects from the map
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<Id, List<SObject>> contactsByAccount = new Map<Id, List<SObject>>();
	 * List<SObject> allContacts = UTIL_Map.flattenValues(contactsByAccount);
	 * ```
	 */
	global static List<SObject> flattenValues(Map<Id, List<SObject>> idMap)
	{
		List<SObject> objectList = new List<SObject>();

		if(idMap?.values().isEmpty() == false)
		{
			for(List<SObject> valuesList : idMap.values())
			{
				objectList.addAll(valuesList);
			}
		}

		return objectList;
	}

	/**
	 * @description Collapses a String-keyed map of SObject lists into a single flat list containing every record.
	 *
	 * @param stringMap A map where the value is a list of SObjects and the key is a string
	 *
	 * @return A list containing all the SObjects from the map
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, List<SObject>> recordsByType = new Map<String, List<SObject>>();
	 * List<SObject> allRecords = UTIL_Map.flattenValues(recordsByType);
	 * ```
	 */
	global static List<SObject> flattenValues(Map<String, List<SObject>> stringMap)
	{
		List<SObject> objectList = new List<SObject>();

		if(stringMap?.values().isEmpty() == false)
		{
			for(List<SObject> valuesList : stringMap.values())
			{
				objectList.addAll(valuesList);
			}
		}

		return objectList;
	}

	/**
	 * @description Serialises a map of name-value pairs into a single delimited string of the form name=value[separator]name=value.
	 *
	 * @param valuesByNameMap A map of name and values
	 * @param separator The separator to use between pairs; defaults to comma if null
	 *
	 * @return A string in the format paramName=paramValue[separator]paramName2=paramValue2
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, String> params = new Map<String, String>{ 'key1' => 'value1', 'key2' => 'value2' };
	 * String result = UTIL_Map.toDelimitedString(params, ',');
	 * ```
	 */
	global static String toDelimitedString(Map<String, String> valuesByNameMap, String separator)
	{
		String nameValues;

		if(valuesByNameMap?.isEmpty() == false)
		{
			UTIL_String.DelimitedListBuilder listBuilder = new UTIL_String.DelimitedListBuilder();

			for(String name : valuesByNameMap.keySet())
			{
				listBuilder.add(name + UTIL_String.EQUALS + valuesByNameMap.get(name));
			}

			listBuilder.setDelimiter(separator ?? UTIL_String.COMMA);

			nameValues = listBuilder.toString();
		}

		return nameValues;
	}

	/**
	 * @description A Map implementation that performs case-insensitive key lookups.
	 * Keys are normalised to lower case for internal storage and retrieval,
	 * but the original casing is retained for display and export operations.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_Map.CaseInsensitiveMap ciMap = new UTIL_Map.CaseInsensitiveMap();
	 * ciMap.put('Acme Ltd', myAccount);
	 * Account a = (Account) ciMap.get('ACME LTD');
	 * ```
	 */
	global inherited sharing class CaseInsensitiveMap
	{
		/**
		 * @description Primary storage for values, keyed by the normalised (lower-cased)
		 * form of each key. All internal lookups are performed against this map.
		 */
		private final Map<String, Object> entries;

		/**
		 * @description Maps normalised (lower-cased) keys back to the original,
		 * case-preserving key strings supplied by the caller.
		 */
		private final Map<String, String> casedKeys;

		/**
		 * @description Constructs an empty CaseInsensitiveMap.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_Map.CaseInsensitiveMap instance = new UTIL_Map.CaseInsensitiveMap();
		 * ```
		 */
		global CaseInsensitiveMap()
		{
			entries = new Map<String, Object>();
			casedKeys = new Map<String, String>();
		}

		/**
		 * @description Constructs a new CaseInsensitiveMap pre-populated with entries
		 * from the provided standard map.
		 *
		 * @param sourceMap The map whose entries are to be placed into this map.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_Map.CaseInsensitiveMap instance = new UTIL_Map.CaseInsensitiveMap(new Map<String, Object>{'key' => 'value'});
		 * ```
		 */
		global CaseInsensitiveMap(Map<String, Object> sourceMap)
		{
			this();
			putAll(sourceMap);
		}

		/**
		 * @description Stores a value under the given key. If a mapping already exists
		 * for the same key (regardless of letter case), it is replaced.
		 *
		 * @param key The key with which the specified value is to be associated.
		 * @param value The value to be associated with the specified key.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * instance.put('value', 'value');
		 * ```
		 */
		global void put(String key, Object value)
		{
			String normalised = key?.toLowerCase();
			entries.put(normalised, value);
			casedKeys.put(normalised, key);
		}

		/**
		 * @description Inserts all entries from the supplied map into this map.
		 * Existing mappings whose keys match (case-insensitively) are overwritten.
		 *
		 * @param sourceMap The map whose entries are to be placed into this map.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * instance.putAll(new Map<String, Object>{'key' => 'value'});
		 * ```
		 */
		global void putAll(Map<String, Object> sourceMap)
		{
			if(sourceMap != null)
			{
				for(String key : sourceMap.keySet())
				{
					put(key, sourceMap.get(key));
				}
			}
		}

		/**
		 * @description Retrieves the value mapped to the supplied key using a
		 * case-insensitive comparison. Returns null when no mapping exists.
		 *
		 * @param key The key whose associated value is to be returned.
		 *
		 * @return The value associated with the key, or null if no mapping exists.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Object result = instance.get('value');
		 * ```
		 */
		global Object get(String key)
		{
			return entries.get(key?.toLowerCase());
		}

		/**
		 * @description Deletes the entry for the given key (case-insensitive match)
		 * and returns the previously associated value.
		 *
		 * @param key The key whose mapping is to be removed from the map.
		 *
		 * @return The previous value associated with the key, or null if there
		 * was no mapping for the key.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Object result = instance.remove('value');
		 * ```
		 */
		global Object remove(String key)
		{
			String normalised = key?.toLowerCase();
			casedKeys.remove(normalised);
			return entries.remove(normalised);
		}

		/**
		 * @description Checks whether this map holds an entry for the specified key,
		 * ignoring letter case.
		 *
		 * @param key The key whose presence in this map is to be tested.
		 *
		 * @return Boolean `true` if this map contains a mapping for the specified key,
		 * otherwise `false`.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean result = instance.containsKey('value');
		 * ```
		 */
		global Boolean containsKey(String key)
		{
			return entries.containsKey(key?.toLowerCase());
		}

		/**
		 * @description Returns the set of keys in their original, caller-supplied casing.
		 *
		 * @return A Set of the original keys in the map.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Set<String> result = instance.keySet();
		 * ```
		 */
		global Set<String> keySet()
		{
			return new Set<String>(casedKeys.values());
		}

		/**
		 * @description Returns all values stored in this map as an ordered list.
		 *
		 * @return A List of the values in the map.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Object> result = instance.values();
		 * ```
		 */
		global List<Object> values()
		{
			return new List<Object>(entries.values());
		}

		/**
		 * @description Exports the contents of this map to a standard Map<String, Object>,
		 * restoring the original key casing.
		 *
		 * @return A new `Map<String, Object>` containing all entries from this map.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Map<String, Object> result = instance.toMap();
		 * ```
		 */
		global Map<String, Object> toMap()
		{
			Map<String, Object> exported = new Map<String, Object>();

			for(String normalisedKey : entries.keySet())
			{
				exported.put(casedKeys.get(normalisedKey), entries.get(normalisedKey));
			}

			return exported;
		}

		/**
		 * @description Produces a shallow copy of this CaseInsensitiveMap. The returned
		 * instance is independent; mutations do not propagate between the original and the copy.
		 *
		 * @return A new CaseInsensitiveMap instance that is a copy of this one.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * CaseInsensitiveMap result = instance.copy();
		 * ```
		 */
		global CaseInsensitiveMap copy()
		{
			return new CaseInsensitiveMap(toMap());
		}

		/**
		 * @description Empties this map, discarding all stored entries.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * instance.clear();
		 * ```
		 */
		global void clear()
		{
			entries.clear();
			casedKeys.clear();
		}

		/**
		 * @description Returns the current number of key-value mappings stored in this map.
		 *
		 * @return The number of entries in the map.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer result = instance.size();
		 * ```
		 */
		global Integer size()
		{
			return entries.size();
		}

		/**
		 * @description Indicates whether this map is empty, containing zero entries.
		 *
		 * @return Boolean `true` if the map is empty, otherwise `false`.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Boolean result = instance.isEmpty();
		 * ```
		 */
		global Boolean isEmpty()
		{
			return entries.isEmpty();
		}
	}
}