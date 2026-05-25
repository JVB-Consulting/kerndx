// SPDX-License-Identifier: MIT
/**
 * MIT License
 *
 * Copyright (c) 2018 open-force
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/**
 * @description Utility class to streamline parsing nested JSON data structures.
 *
 * Provides methods to navigate and extract data from JSON using dot notation paths, with support for type-safe value retrieval and existence checks.
 * Adapted from [open-force](https://github.com/open-force/jsonparse).
 *
 * @see UTIL_JsonPath_TEST
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
 * UTIL_JsonPath json = new UTIL_JsonPath('{"account": {"name": "Acme", "active": true}}');
 * String name = json.get('account.name').getStringValue();
 * Boolean active = json.get('account.active').getBooleanValue();
 * Boolean exists = json.exists('account.name');
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.AvoidGlobalModifier')
global inherited sharing class UTIL_JsonPath
{
	private static final Pattern ARRAY_NOTATION = Pattern.compile('\\[(\\d+)]');
	private static final String SEPARATOR = '\\.';

	/**
	 * @description The raw JSON data wrapped by this instance.
	 */
	private final Object value;

	/**
	 * @description Constructs a UTIL_JsonPath instance from a serialized JSON string.
	 *
	 * @param jsonData The JSON string to parse.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_JsonPath instance = new UTIL_JsonPath('value');
	 * ```
	 */
	global UTIL_JsonPath(String jsonData)
	{
		value = JSON.deserializeUntyped(jsonData);
	}

	/**
	 * @description Constructs a UTIL_JsonPath instance from an already-deserialized object.
	 *
	 * @param value The deserialized JSON value (e.g., Map<String,Object>, List<Object>, or primitive).
	 */
	private UTIL_JsonPath(Object value)
	{
		this.value = value;
	}

	/**
	 * @description Retrieves a subtree in the JSON data using a dot notation path.
	 *
	 * Supports paths with array indices (e.g., `data.items[1]`) and object keys.
	 *
	 * @param path The dot notation path to the desired data.
	 *
	 * @return A UTIL_JsonPath instance wrapping the targeted subtree.
	 *
	 * @throws ListException If an array index is out of bounds.
	 * @throws MissingKeyException If a key in the path does not exist in the JSON object.
	 * @throws UTIL_Exceptions.IllegalStateException If an array index is applied to a non-array node or a key is applied to a non-object node.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_JsonPath json = new UTIL_JsonPath('{"data": {"items": [{"id": 1}, {"id": 2}]}}');
	 * UTIL_JsonPath item = json.get('data.items[1]');
	 * String id = item.getStringValue();
	 * ```
	 */
	global UTIL_JsonPath get(String path)
	{
		return traverse(path, true);
	}

	/**
	 * @description Checks if a path exists in the JSON data structure.
	 *
	 * @param path The dot notation path to check.
	 *
	 * @return True if the path exists, false otherwise.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_JsonPath json = new UTIL_JsonPath('{"data": {"items": [{"id": 1}]}}');
	 * Boolean existsFirst = json.exists('data.items[0]');
	 * Boolean existsSecond = json.exists('data.items[1]');
	 * ```
	 */
	global Boolean exists(String path)
	{
		return findNode(path) != null;
	}

	/**
	 * @description Navigates to a subtree in the JSON data using a dot notation path.
	 *
	 * @param path The dot notation path to the desired subtree.
	 *
	 * @return A UTIL_JsonPath instance wrapping the targeted subtree, or null if the path does not exist.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_JsonPath result = instance.findNode('value');
	 * ```
	 */
	global UTIL_JsonPath findNode(String path)
	{
		return traverse(path, false);
	}

	/**
	 * @description Traverses the JSON data structure using a dot notation path.
	 *
	 * When throwOnMissing is true, throws exceptions for type mismatches and missing keys (used by get()).
	 * When throwOnMissing is false, returns null for type mismatches and missing keys (used by findNode()).
	 *
	 * @param path The dot notation path to the desired data.
	 * @param throwOnMissing When true, throws exceptions on missing keys or type mismatches; when false, returns null.
	 *
	 * @return A UTIL_JsonPath instance wrapping the targeted subtree, or null if the path does not exist and throwOnMissing is false.
	 */
	private UTIL_JsonPath traverse(String path, Boolean throwOnMissing)
	{
		UTIL_JsonPath currentNode = this;
		for(String key : path.split(SEPARATOR))
		{
			Matcher arrayMatcher = ARRAY_NOTATION.matcher(key);
			if(arrayMatcher.matches())
			{
				if(!currentNode.isArray())
				{
					if(throwOnMissing)
					{
						throw new UTIL_Exceptions.IllegalStateException('The wrapped value is not a JSON array:\n' + currentNode.toStringPretty());
					}
					return null;
				}
				Integer index = Integer.valueOf(arrayMatcher.group(1));
				List<Object> items = (List<Object>)currentNode.value;
				if(0 <= index && index < items.size())
				{
					currentNode = new UTIL_JsonPath(items.get(index));
				}
				else
				{
					if(throwOnMissing)
					{
						items.get(index);
					}
					return null;
				}
			}
			else
			{
				if(!currentNode.isObject())
				{
					if(throwOnMissing)
					{
						throw new UTIL_Exceptions.IllegalStateException('The wrapped value is not a JSON object:\n' + currentNode.toStringPretty());
					}
					return null;
				}
				Map<String, Object> valueAsMap = (Map<String, Object>)currentNode.value;
				if(valueAsMap.containsKey(key))
				{
					currentNode = new UTIL_JsonPath(valueAsMap.get(key));
				}
				else
				{
					if(throwOnMissing)
					{
						throw new MissingKeyException('No match found for <' + key + '>: ' + valueAsMap.keySet());
					}
					return null;
				}
			}
		}
		return currentNode;
	}

	/**
	 * @description Checks if the wrapped JSON data is an object (Map<String, Object>).
	 *
	 * @return True if the value is a JSON object, false otherwise.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_JsonPath json = new UTIL_JsonPath('{"key": "value"}');
	 * Boolean result = json.isObject();
	 * ```
	 */
	global Boolean isObject()
	{
		return value instanceof Map<String, Object>;
	}

	/**
	 * @description Checks if the wrapped JSON data is an array (List<Object>).
	 *
	 * @return True if the value is a JSON array, false otherwise.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_JsonPath json = new UTIL_JsonPath('[{"id": 1}]');
	 * Boolean result = json.isArray();
	 * ```
	 */
	global Boolean isArray()
	{
		return value instanceof List<Object>;
	}

	/**
	 * @description Serializes the wrapped JSON data to a pretty-printed JSON string.
	 *
	 * @return A formatted JSON string.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_JsonPath json = new UTIL_JsonPath('{"key": "value"}');
	 * String result = json.toStringPretty();
	 * ```
	 */
	global String toStringPretty()
	{
		return JSON.serializePretty(value);
	}

	/**
	 * @description Converts the wrapped JSON data to a Boolean.
	 *
	 * @return The value as a Boolean.
	 *
	 * @throws TypeException If the value is not a Boolean or convertible string.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_JsonPath json = new UTIL_JsonPath('{"isActive": true}');
	 * Boolean isActive = json.get('isActive').getBooleanValue();
	 * ```
	 */
	global Boolean getBooleanValue()
	{
		if(value instanceof Boolean)
		{
			return (Boolean)value;
		}
		return Boolean.valueOf(value);
	}

	/**
	 * @description Converts the wrapped JSON data to a Datetime, supporting ISO-8601 strings or timestamps (Long).
	 *
	 * @return The value as a Datetime.
	 *
	 * @throws TypeException If the value is not a String or Long.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_JsonPath json = new UTIL_JsonPath('{"timestamp": 1625097600000}');
	 * Datetime dt = json.get('timestamp').getDatetimeValue();
	 * ```
	 */
	global Datetime getDatetimeValue()
	{
		if(value instanceof Long)
		{
			return Datetime.newInstance((Long)value);
		}
		if(value instanceof String)
		{
			return UTIL_Date.dateTimeFromIso8601((String)value);
		}
		throw new TypeException('Only Long and String values can be converted to a Datetime: ' + toStringPretty());
	}

	/**
	 * @description Converts the wrapped JSON data to a Date, supporting ISO-8601 strings or timestamps (Long).
	 *
	 * @return The value as a Date.
	 *
	 * @throws TypeException If the value is not a String or Long.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_JsonPath json = new UTIL_JsonPath('{"date": "2021-07-01"}');
	 * Date dt = json.get('date').getDateValue();
	 * ```
	 */
	global Date getDateValue()
	{
		if(value instanceof Long)
		{
			return Datetime.newInstance((Long)value).dateGmt();
		}
		if(value instanceof String)
		{
			return UTIL_Date.dateFromIso8601((String)value);
		}
		throw new TypeException('Only Long and String values can be converted to a Date: ' + toStringPretty());
	}

	/**
	 * @description Converts the wrapped JSON data to a Decimal.
	 *
	 * @return The value as a Decimal.
	 *
	 * @throws TypeException If the value is not a Decimal or convertible string.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_JsonPath json = new UTIL_JsonPath('{"amount": "123.45"}');
	 * Decimal amount = json.get('amount').getDecimalValue();
	 * ```
	 */
	global Decimal getDecimalValue()
	{
		if(value instanceof Decimal)
		{
			return (Decimal)value;
		}
		if(value instanceof String)
		{
			return Decimal.valueOf((String)value);
		}
		throw new TypeException('This value cannot be converted to a Decimal: ' + toStringPretty());
	}

	/**
	 * @description Converts the wrapped JSON data to a Salesforce Id, validating the string format.
	 *
	 * @return The value as an Id.
	 *
	 * @throws StringException If the string is not a valid Salesforce Id.
	 * @throws TypeException If the value is not a string.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_JsonPath json = new UTIL_JsonPath('{"recordId": "001xx0000000000AAA"}');
	 * Id recordId = json.get('recordId').getIdValue();
	 * ```
	 */
	global Id getIdValue()
	{
		if(value instanceof String)
		{
			return Id.valueOf((String)value);
		}
		throw new TypeException('This value cannot be converted to an Id: ' + toStringPretty());
	}

	/**
	 * @description Converts the wrapped JSON data to an Integer.
	 *
	 * @return The value as an Integer.
	 *
	 * @throws TypeException If the value is not an Integer, Decimal, or convertible string.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_JsonPath json = new UTIL_JsonPath('{"count": "42"}');
	 * Integer count = json.get('count').getIntegerValue();
	 * ```
	 */
	global Integer getIntegerValue()
	{
		if(value instanceof Integer)
		{
			return (Integer)value;
		}
		if(value instanceof Decimal)
		{
			return ((Decimal)value).intValue();
		}
		if(value instanceof String)
		{
			return Integer.valueOf((String)value);
		}
		throw new TypeException('This value cannot be converted to an Integer: ' + toStringPretty());
	}

	/**
	 * @description Converts the wrapped JSON data to a String, excluding objects and arrays.
	 *
	 * @return The value as a String.
	 *
	 * @throws TypeException If the value is a JSON object or array.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * UTIL_JsonPath json = new UTIL_JsonPath('{"name": "John"}');
	 * String name = json.get('name').getStringValue();
	 * ```
	 */
	global String getStringValue()
	{
		if(isObject() || isArray())
		{
			throw new TypeException('Objects and arrays are not Strings: ' + toStringPretty());
		}
		if(value instanceof String)
		{
			return (String)value;
		}
		return String.valueOf(value);
	}

	/**
	 * @description Custom exception thrown when a JSON path key cannot be resolved.
	 *
	 * @see UTIL_JsonPath.get
	 *
	 * @group Utilities
	 *
	 * @since 1.0
	 */
	global inherited sharing class MissingKeyException extends Exception
	{
	}
}