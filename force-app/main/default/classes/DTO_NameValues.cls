// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Class for managing and transferring key-value pairs, represented as names and values, between classes.
 * Provides functionalities to store, retrieve, and manipulate these name-value pairs.
 *
 * @see DTO_NameValues_TEST
 *
 * @author Jason van Beukering
 *
 * @group Data Transfer Objects
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * DTO_NameValues params = new DTO_NameValues();
 * params.add('recipient', 'user@example.com');
 * params.add('subject', 'Hello');
 * String recipient = params.get('recipient');
 * Boolean hasAll = params.allExists(new Set<String>{'recipient', 'subject'}, true);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.AvoidBooleanMethodParameters')
@JsonAccess(Serializable='always' Deserializable='always')
global inherited sharing class DTO_NameValues extends DTO_JsonBase
{
	private final Map<String, String> nameValueMap;

	/**
	 * @description Constructor that initializes an empty name-value map to store key-value pairs.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_NameValues instance = new DTO_NameValues();
	 * ```
	 */
	global DTO_NameValues()
	{
		nameValueMap = new Map<String, String>();
	}

	/**
	 * @description Constructor that accepts a delimited string of name-value pairs, converting
	 * them into key-value entries within the map.
	 *
	 * @param separatedNameValues A string of name-value pairs separated by a comma, e.g., `"paramName=paramValue,paramName2=paramValue2"`.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_NameValues instance = new DTO_NameValues('value');
	 * ```
	 */
	global DTO_NameValues(String separatedNameValues)
	{
		this(separatedNameValues, null);
	}

	/**
	 * @description Constructor that accepts a delimited string of name-value pairs, with a specified separator,
	 * and converts them into key-value entries within the map.
	 *
	 * @param separatedNameValues A string of name-value pairs, e.g., `"paramName=paramValue|paramName2=paramValue2"`.
	 * @param separator The delimiter to separate each name-value pair. If null, defaults to a comma.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_NameValues instance = new DTO_NameValues('value', ',');
	 * ```
	 */
	global DTO_NameValues(String separatedNameValues, String separator)
	{
		this(UTIL_String.toMap(separatedNameValues, separator));
	}

	/**
	 * @description Constructor that populates name-value pairs from a provided map.
	 *
	 * @param nameValues A map of key-value pairs where both keys and values are strings.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_NameValues instance = new DTO_NameValues(new Map<String, String>{'key' => 'value'});
	 * ```
	 */
	global DTO_NameValues(Map<String, String> nameValues)
	{
		this();
		nameValueMap.putAll(nameValues);
	}

	/**
	 * @description Returns the number of name-value pairs
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Integer value = instance.size;
	 * ```
	 */
	global transient Integer size
	{
		get
		{
			return nameValueMap.size();
		}
	}

	/**
	 * @description Returns all the names for registered name-value pairs
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> value = instance.names;
	 * ```
	 */
	global transient Set<String> names
	{
		get
		{
			return nameValueMap.keySet();
		}
	}

	/**
	 * @description Returns all the values for registered name-value pairs
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<String> value = instance.values;
	 * ```
	 */
	global transient List<String> values
	{
		get
		{
			return nameValueMap.values();
		}
	}

	/**
	 * @description Retrieves the value associated with the specified key in the map.
	 * If the key does not exist, returns null.
	 *
	 * @param name The key for which to retrieve the value. Case-sensitive.
	 *
	 * @return The value associated with the specified key, or null if the key is absent.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = instance.get('myName');
	 * ```
	 */
	global String get(String name)
	{
		return nameValueMap.get(name);
	}

	/**
	 * @description Checks if the DTO contains no key-value pairs.
	 * Returns true if the object has zero key-value pairs.
	 *
	 * @return true if there are no entries, false otherwise.
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
		return nameValueMap.isEmpty();
	}

	/**
	 * @description Determines if a key exists in the map and, optionally, if it is non-blank.
	 * A non-blank value is neither null nor an empty string.
	 *
	 * @param nameToMatch Name against which to find a key, note the compare is case-sensitive
	 * @param isNonBlank Will return false if item exists and it's blank (either null or empty string)
	 *
	 * @return true if the key exists (and has a non-blank value if specified).
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Boolean result = instance.exists('value', true);
	 * ```
	 */
	global Boolean exists(String nameToMatch, Boolean isNonBlank)
	{
		Boolean exists = !isEmpty() && nameValueMap.containsKey(nameToMatch);

		if(exists && isNonBlank)
		{
			exists = String.isNotBlank(nameValueMap.get(nameToMatch));
		}

		return exists;
	}

	/**
	 * @description Returns true if the objects contains a value for the specified name
	 *
	 * @param nameToMatch Name against which to find a key, note the compare is case-sensitive
	 *
	 * @return Null or the item found
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Boolean result = instance.exists('value');
	 * ```
	 */
	global Boolean exists(String nameToMatch)
	{
		return exists(nameToMatch, false);
	}

	/**
	 * @description Checks to see if all the parameter names provided exist in the list
	 *
	 * @param names A list of names on which to match (please note this is case sensitive)
	 *
	 * @return True if ALL the parameters exist
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Boolean result = instance.allExists(new Set<String>{'a', 'b'});
	 * ```
	 */
	global Boolean allExists(Set<String> names)
	{
		return allExists(names, false);
	}

	/**
	 * @description Determines if all keys in the provided set exist in the map, and optionally
	 * ensures that all have non-blank values.
	 *
	 * @param namesToMatch A set of keys to check for existence. Case-sensitive.
	 * @param isNonBlank If true, requires that all specified keys have non-blank values.
	 *
	 * @return true if all keys exist (and have non-blank values if specified).
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Boolean result = instance.allExists(new Set<String>{'a', 'b'}, true);
	 * ```
	 */
	global Boolean allExists(Set<String> namesToMatch, Boolean isNonBlank)
	{
		Boolean exists = namesToMatch == null || namesToMatch.isEmpty();

		if(!exists)
		{
			for(String nameToMatch : namesToMatch)
			{
				exists = exists(nameToMatch, isNonBlank);

				if(!exists)
				{
					break;
				}
			}
		}

		return exists;
	}

	/**
	 * @description Adds a new key-value pair to the map, or updates the value if the key already exists.
	 *
	 * @param name The key to add or update.
	 * @param value The value to associate with the key.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * instance.add('myName', 'value');
	 * ```
	 */
	global void add(String name, String value)
	{
		nameValueMap.put(name, value);
	}

	/**
	 * @description Serializes the map to a JSON string. If the map is empty, returns an empty JSON object `{}`.
	 *
	 * @return A JSON string representation of the map.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = instance.serialize();
	 * ```
	 */
	global override String serialize()
	{
		return nameValueMap?.isEmpty() == false ? super.serialize() : UTIL_String.EMPTY_JSON_RESPONSE;
	}

	/**
	 * @description Returns the type of this DTO for deserialization purposes, useful for reconstructing
	 * the object from JSON.
	 *
	 * @return The type class of DTO_NameValues.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Type result = instance.getObjectType();
	 * ```
	 */
	global protected override Type getObjectType()
	{
		return DTO_NameValues.class;
	}

	/**
	 * @description Converts the name-value pairs in the map into a parameter string in the format `"name1=value1,name2=value2"`.
	 *
	 * @return A string of comma-separated name-value pairs.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = instance.toParameterString();
	 * ```
	 */
	global String toParameterString()
	{
		return UTIL_Map.toDelimitedString(nameValueMap, UTIL_String.COMMA);
	}
}