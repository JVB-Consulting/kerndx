// SPDX-License-Identifier: BUSL-1.1
/**
 * @description SObject runtime operations — filtering, field extraction, list-to-map conversion,
 * and dot-notation field value retrieval.
 *
 * @see UTIL_SObject_TEST
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
 * Set<Id> accountIds = UTIL_SObject.extractIds(contacts, Contact.AccountId, true);
 * Map<Id, List<SObject>> contactsByAccount = UTIL_SObject.groupByKey(contacts, Contact.AccountId);
 * List<SObject> changed = UTIL_SObject.getChangedRecords(newRecords, oldRecords, Account.Name);
 * ```
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.CognitiveComplexity,PMD.ExcessiveClassLength,PMD.ExcessivePublicCount,PMD.AvoidGlobalModifier,PMD.NcssTypeCount')
global inherited sharing class UTIL_SObject
{
	/**
	 * @description Checks if an SObject matches the field-value pairs in the provided filter map.
	 *
	 * @param obj The SObject to check.
	 * @param filterMap A map containing field API names and their expected values.
	 *
	 * @return True if all fields in the filter map match the corresponding SObject fields.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * SObject account = new Account(Name = 'Test Account', Industry = 'Technology');
	 * Map<String, Object> filterMap = new Map<String, Object>{'Name' => 'Test Account', 'Industry' => 'Technology'};
	 * Boolean doesMatch = UTIL_SObject.matches(account, filterMap); // True
	 * ```
	 */
	global static Boolean matches(SObject obj, Map<String, Object> filterMap)
	{
		Boolean doesMatch = true;

		for(String name : filterMap.keySet())
		{
			Object fieldValue = getFieldValue(obj, name);
			Object filterValue = filterMap.get(name);

			// Special case: we assume a match when [Boolean] false == null.
			if(filterValue instanceof Boolean && ((Boolean)filterValue == false))
			{
				doesMatch = fieldValue == false || fieldValue == null;
			}
			else
			{
				doesMatch = fieldValue == filterValue;
			}

			if(!doesMatch)
			{
				break;
			}
		}

		return doesMatch;
	}

	/**
	 * @description Filters a list of SObjects by a single field-value match.
	 *
	 * @param objects The SObjects to filter
	 * @param fieldName The field API name to match
	 * @param value The value to match against
	 *
	 * @return Matching SObjects
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObject> techAccounts = UTIL_SObject.findWhere(accounts, 'Industry', 'Technology');
	 * ```
	 */
	global static List<SObject> findWhere(List<SObject> objects, String fieldName, Object value)
	{
		return findWhere(objects, new Map<String, Object>
		{
				fieldName => value
		});
	}

	/**
	 * @description Filters a list of SObjects by multiple field-value matches.
	 *
	 * @param objects The SObjects to filter
	 * @param filter A map of field API names and their expected values
	 *
	 * @return Matching SObjects
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, Object> filter = new Map<String, Object>{ 'Industry' => 'Technology', 'Active__c' => true };
	 * List<SObject> matches = UTIL_SObject.findWhere(accounts, filter);
	 * ```
	 */
	global static List<SObject> findWhere(List<SObject> objects, Map<String, Object> filter)
	{
		return filterByMatch(objects, filter, true);
	}

	/**
	 * @description Filters a list of SObjects where a field value is in the provided list.
	 *
	 * @param objects The SObjects to filter
	 * @param fieldName The field API name to match
	 * @param values The values to match against
	 *
	 * @return Matching SObjects
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Object> targetIndustries = new List<Object>{ 'Technology', 'Finance' };
	 * List<SObject> filtered = UTIL_SObject.findWhereIn(accounts, 'Industry', targetIndustries);
	 * ```
	 */
	global static List<SObject> findWhereIn(List<SObject> objects, String fieldName, List<Object> values)
	{
		Set<Object> valueSet = new Set<Object>(values);
		Object fieldVal;
		List<SObject> result = new List<SObject>();

		for(SObject obj : objects)
		{
			fieldVal = obj.get(fieldName);

			if(valueSet.contains(fieldVal))
			{
				result.add(obj);
			}
		}

		return result;
	}

	/**
	 * @description Removes items from a list where the field matches a single value.
	 *
	 * @param objects The SObjects to filter
	 * @param fieldName The field API name to match for exclusion
	 * @param value The value that causes exclusion
	 *
	 * @return SObjects not matching the exclusion criteria
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObject> nonTech = UTIL_SObject.omitWhere(accounts, 'Industry', 'Technology');
	 * ```
	 */
	global static List<SObject> omitWhere(List<SObject> objects, String fieldName, Object value)
	{
		return omitWhere(objects, new Map<String, Object>
		{
				fieldName => value
		});
	}

	/**
	 * @description Removes items from a list where the fields match the filter map.
	 *
	 * @param objects The SObjects to filter
	 * @param filter A map of fields and values that cause exclusion
	 *
	 * @return SObjects not matching the exclusion criteria
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, Object> filter = new Map<String, Object>{ 'Status' => 'Closed', 'IsDeleted' => true };
	 * List<SObject> activeRecords = UTIL_SObject.omitWhere(allRecords, filter);
	 * ```
	 */
	global static List<SObject> omitWhere(List<SObject> objects, Map<String, Object> filter)
	{
		return filterByMatch(objects, filter, false);
	}

	/**
	 * @description Filters a list of SObjects by matching or excluding records based on a filter map.
	 *
	 * @param objects The SObjects to filter.
	 * @param filter A map of field API names and their expected values.
	 * @param include When true, includes matching records; when false, excludes them.
	 *
	 * @return Filtered SObjects, or null if the input list is null.
	 */
	private static List<SObject> filterByMatch(List<SObject> objects, Map<String, Object> filter, Boolean include)
	{
		List<SObject> result;

		if(objects != null)
		{
			result = new List<SObject>();

			for(SObject obj : objects)
			{
				if(matches(obj, filter) == include)
				{
					result.add(obj);
				}
			}
		}

		return result;
	}

	/**
	 * @description Extracts a unique set of Ids from a list of SObjects using the Id field.
	 *
	 * @param objects The SObjects from which to extract Ids
	 *
	 * @return Extracted Ids, could include a null
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<Id> accountIds = UTIL_SObject.extractIds(accounts);
	 * ```
	 */
	global static Set<Id> extractIds(List<SObject> objects)
	{
		return extractIds(objects, false);
	}

	/**
	 * @description Extracts a unique set of Ids from a list of SObjects using the Id field.
	 *
	 * @param objects The SObjects from which to extract Ids
	 * @param ignoreNulls Set to true to exclude null Ids
	 *
	 * @return Extracted Ids
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<Id> accountIds = UTIL_SObject.extractIds(accounts, true);
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	global static Set<Id> extractIds(List<SObject> objects, Boolean ignoreNulls)
	{
		return extractIds(objects, 'Id', ignoreNulls);
	}

	/**
	 * @description Extracts a unique set of Ids from a list of SObjects using a named field.
	 *
	 * @param objects The SObjects from which to extract Ids
	 * @param fieldName The API name of the field containing the Id (supports dot-notation)
	 *
	 * @return Extracted Ids, could include a null
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<Id> accountIds = UTIL_SObject.extractIds(contacts, 'AccountId');
	 * ```
	 */
	global static Set<Id> extractIds(List<SObject> objects, String fieldName)
	{
		return extractIds(objects, fieldName, false);
	}

	/**
	 * @description Extracts a unique set of Ids from a list of SObjects using a typed field token.
	 *
	 * @param objects The SObjects from which to extract Ids
	 * @param objectField The field token containing the Id
	 *
	 * @return Extracted Ids, could include a null
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<Id> accountIds = UTIL_SObject.extractIds(contacts, Contact.AccountId);
	 * ```
	 */
	global static Set<Id> extractIds(List<SObject> objects, SObjectField objectField)
	{
		return extractIds(objects, UTIL_SObjectDescribe.getCachedFieldName(objectField));
	}

	/**
	 * @description Extracts a unique set of Ids from a list of SObjects using a named field with null filtering.
	 *
	 * @param objects The SObjects from which to extract Ids
	 * @param fieldName The API name of the field containing the Id (supports dot-notation)
	 * @param ignoreNulls Set to true to exclude null Ids
	 *
	 * @return Extracted Ids
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<Id> accountIds = UTIL_SObject.extractIds(contacts, 'AccountId', true);
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	global static Set<Id> extractIds(List<SObject> objects, String fieldName, Boolean ignoreNulls)
	{
		Set<Id> results = new Set<Id>();

		if(objects != null)
		{
			for(SObject item : objects)
			{
				Id itemId = (Id)getFieldValue(item, fieldName);

				if(!ignoreNulls || (itemId != null))
				{
					results.add(itemId);
				}
			}
		}

		return results;
	}

	/**
	 * @description Extracts a unique set of Ids from a list of SObjects using a typed field token with null filtering.
	 *
	 * @param objects The SObjects from which to extract Ids
	 * @param objectField The field token containing the Id
	 * @param ignoreNulls Set to true to exclude null Ids
	 *
	 * @return Extracted Ids
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<Id> accountIds = UTIL_SObject.extractIds(contacts, Contact.AccountId, true);
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	global static Set<Id> extractIds(List<SObject> objects, SObjectField objectField, Boolean ignoreNulls)
	{
		return extractIds(objects, UTIL_SObjectDescribe.getCachedFieldName(objectField), ignoreNulls);
	}

	/**
	 * @description Extracts field values as strings from a list of SObjects.
	 *
	 * @param objects The SObjects from which to extract values
	 * @param fieldName The API name of the field (supports dot-notation)
	 *
	 * @return A list of string values (includes blanks)
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<String> names = UTIL_SObject.extractValues(accounts, 'Name');
	 * ```
	 */
	global static List<String> extractValues(List<SObject> objects, String fieldName)
	{
		return extractValues(objects, fieldName, false);
	}

	/**
	 * @description Extracts field values as strings from a list of SObjects using a typed field token.
	 *
	 * @param objects The SObjects from which to extract values
	 * @param objectField The field token to extract
	 *
	 * @return A list of string values (includes blanks)
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<String> names = UTIL_SObject.extractValues(accounts, Account.Name);
	 * ```
	 */
	global static List<String> extractValues(List<SObject> objects, SObjectField objectField)
	{
		return extractValues(objects, UTIL_SObjectDescribe.getCachedFieldName(objectField));
	}

	/**
	 * @description Extracts field values as strings from a list of SObjects with blank filtering.
	 *
	 * @param objects The SObjects from which to extract values
	 * @param fieldName The API name of the field (supports dot-notation)
	 * @param ignoreBlankValues Set to true to exclude blank values
	 *
	 * @return A list of string values
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<String> names = UTIL_SObject.extractValues(accounts, 'Name', true);
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	global static List<String> extractValues(List<SObject> objects, String fieldName, Boolean ignoreBlankValues)
	{
		List<String> listResult = new List<String>();
		collectStringValues(objects, fieldName, ignoreBlankValues, listResult, null);
		return listResult;
	}

	/**
	 * @description Extracts field values as strings from a list of SObjects using a typed field token with blank filtering.
	 *
	 * @param objects The SObjects from which to extract values
	 * @param objectField The field token to extract
	 * @param ignoreBlankValues Set to true to exclude blank values
	 *
	 * @return A list of string values
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<String> names = UTIL_SObject.extractValues(accounts, Account.Name, true);
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	global static List<String> extractValues(List<SObject> objects, SObjectField objectField, Boolean ignoreBlankValues)
	{
		return extractValues(objects, UTIL_SObjectDescribe.getCachedFieldName(objectField), ignoreBlankValues);
	}

	/**
	 * @description Extracts a unique set of field values as strings from a list of SObjects.
	 *
	 * @param objects The SObjects from which to extract values
	 * @param fieldName The API name of the field (supports dot-notation)
	 *
	 * @return A set of string values (includes blanks)
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> industries = UTIL_SObject.extractUniqueValues(accounts, 'Industry');
	 * ```
	 */
	global static Set<String> extractUniqueValues(List<SObject> objects, String fieldName)
	{
		return extractUniqueValues(objects, fieldName, false);
	}

	/**
	 * @description Extracts a unique set of field values as strings from a list of SObjects using a typed field token.
	 *
	 * @param objects The SObjects from which to extract values
	 * @param objectField The field token to extract
	 *
	 * @return A set of string values (includes blanks)
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> industries = UTIL_SObject.extractUniqueValues(accounts, Account.Industry);
	 * ```
	 */
	global static Set<String> extractUniqueValues(List<SObject> objects, SObjectField objectField)
	{
		return extractUniqueValues(objects, UTIL_SObjectDescribe.getCachedFieldName(objectField));
	}

	/**
	 * @description Extracts a unique set of field values as strings from a list of SObjects with blank filtering.
	 *
	 * @param objects The SObjects from which to extract values
	 * @param fieldName The API name of the field (supports dot-notation)
	 * @param ignoreBlankValues Set to true to exclude blank values
	 *
	 * @return A set of string values
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> industries = UTIL_SObject.extractUniqueValues(accounts, 'Industry', true);
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	global static Set<String> extractUniqueValues(List<SObject> objects, String fieldName, Boolean ignoreBlankValues)
	{
		Set<String> setResult = new Set<String>();
		collectStringValues(objects, fieldName, ignoreBlankValues, null, setResult);
		return setResult;
	}

	/**
	 * @description Extracts a unique set of field values as strings from a list of SObjects using a typed field token with blank filtering.
	 *
	 * @param objects The SObjects from which to extract values
	 * @param objectField The field token to extract
	 * @param ignoreBlankValues Set to true to exclude blank values
	 *
	 * @return A set of string values
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Set<String> industries = UTIL_SObject.extractUniqueValues(accounts, Account.Industry, true);
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	global static Set<String> extractUniqueValues(List<SObject> objects, SObjectField objectField, Boolean ignoreBlankValues)
	{
		return extractUniqueValues(objects, UTIL_SObjectDescribe.getCachedFieldName(objectField), ignoreBlankValues);
	}

	/**
	 * @description Collects string field values from SObjects into a list, a set, or both. Pass null for the
	 * collection that should not be populated.
	 *
	 * @param objects The SObjects from which to extract values.
	 * @param fieldName The API name of the field (supports dot-notation).
	 * @param ignoreBlankValues Set to true to exclude blank values.
	 * @param listCollector When non-null, each value is added to this list.
	 * @param setCollector When non-null, each value is added to this set.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static void collectStringValues(List<SObject> objects, String fieldName, Boolean ignoreBlankValues, List<String> listCollector, Set<String> setCollector)
	{
		if(objects != null)
		{
			for(SObject item : objects)
			{
				String fieldValue = String.valueOf(getFieldValue(item, fieldName));

				if(!ignoreBlankValues || String.isNotBlank(fieldValue))
				{
					if(listCollector != null)
					{
						listCollector.add(fieldValue);
					}

					if(setCollector != null)
					{
						setCollector.add(fieldValue);
					}
				}
			}
		}
	}

	/**
	 * @description Converts a list of SObjects into a grouped map by an Id field.
	 *
	 * @param objectList The SObjects to group
	 * @param keyFieldName The API name of the Id field (supports dot-notation)
	 *
	 * @return A map of Id to list of SObjects
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<Id, List<SObject>> contactsByAccount = UTIL_SObject.groupByKey(contacts, 'AccountId');
	 * ```
	 */
	global static Map<Id, List<SObject>> groupByKey(List<SObject> objectList, String keyFieldName)
	{
		Map<Id, List<SObject>> objectMap = new Map<Id, List<SObject>>();

		if(objectList != null)
		{
			for(SObject listItem : objectList)
			{
				Id key = (Id)getFieldValue(listItem, keyFieldName);

				List<SObject> listInMap = objectMap.get(key);

				if(listInMap == null)
				{
					listInMap = new List<SObject>();
					objectMap.put(key, listInMap);
				}

				listInMap.add(listItem);
			}
		}

		return objectMap;
	}

	/**
	 * @description Converts a list of SObjects into a grouped map by an Id field using a typed field token.
	 *
	 * @param objectList The SObjects to group
	 * @param keyField The field token for the key
	 *
	 * @return A map of Id to list of SObjects
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<Id, List<SObject>> contactsByAccount = UTIL_SObject.groupByKey(contacts, Contact.AccountId);
	 * ```
	 */
	global static Map<Id, List<SObject>> groupByKey(List<SObject> objectList, SObjectField keyField)
	{
		return groupByKey(objectList, UTIL_SObjectDescribe.getCachedFieldName(keyField));
	}

	/**
	 * @description Converts a list of SObjects into a single-value map by an Id field.
	 *
	 * @param objectList The SObjects to map
	 * @param keyFieldName The API name of the Id field (supports dot-notation)
	 *
	 * @return A map of Id to SObject
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<Id, SObject> accountById = UTIL_SObject.indexById(accounts, 'Id');
	 * ```
	 */
	global static Map<Id, SObject> indexById(List<SObject> objectList, String keyFieldName)
	{
		Map<Id, SObject> objectMap = new Map<Id, SObject>();

		if(objectList != null)
		{
			for(SObject listItem : objectList)
			{
				objectMap.put((Id)getFieldValue(listItem, keyFieldName), listItem);
			}
		}

		return objectMap;
	}

	/**
	 * @description Converts a list of SObjects into a single-value map by an Id field using a typed field token.
	 *
	 * @param objectList The SObjects to map
	 * @param keyField The field token for the key
	 *
	 * @return A map of Id to SObject
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<Id, SObject> accountById = UTIL_SObject.indexById(accounts, Account.Id);
	 * ```
	 */
	global static Map<Id, SObject> indexById(List<SObject> objectList, SObjectField keyField)
	{
		return indexById(objectList, UTIL_SObjectDescribe.getCachedFieldName(keyField));
	}

	/**
	 * @description Converts a list of SObjects into a grouped map by a String field.
	 *
	 * @param objectList The SObjects to group
	 * @param keyFieldName The API name of the String field (supports dot-notation)
	 *
	 * @return A map of String to list of SObjects
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, List<SObject>> accountsByIndustry = UTIL_SObject.groupByStringKey(accounts, 'Industry');
	 * ```
	 */
	global static Map<String, List<SObject>> groupByStringKey(List<SObject> objectList, String keyFieldName)
	{
		Map<String, List<SObject>> objectMap = new Map<String, List<SObject>>();

		if(objectList != null)
		{
			for(SObject listItem : objectList)
			{
				String idFromField = String.valueOf(getFieldValue(listItem, keyFieldName));

				List<SObject> listInMap = objectMap.get(idFromField);

				if(listInMap == null)
				{
					listInMap = new List<SObject>();
					objectMap.put(idFromField, listInMap);
				}

				listInMap.add(listItem);
			}
		}

		return objectMap;
	}

	/**
	 * @description Converts a list of SObjects into a grouped map by a String field using a typed field token.
	 *
	 * @param objectList The SObjects to group
	 * @param keyField The field token for the key
	 *
	 * @return A map of String to list of SObjects
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, List<SObject>> accountsByIndustry = UTIL_SObject.groupByStringKey(accounts, Account.Industry);
	 * ```
	 */
	global static Map<String, List<SObject>> groupByStringKey(List<SObject> objectList, SObjectField keyField)
	{
		return groupByStringKey(objectList, UTIL_SObjectDescribe.getCachedFieldName(keyField));
	}

	/**
	 * @description Converts a list of SObjects into a single-value map by a String field.
	 *
	 * @param objectList The SObjects to map
	 * @param keyFieldName The API name of the String field (supports dot-notation)
	 *
	 * @return A map of String to SObject
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, SObject> accountByName = UTIL_SObject.indexByStringKey(accounts, 'Name');
	 * ```
	 */
	global static Map<String, SObject> indexByStringKey(List<SObject> objectList, String keyFieldName)
	{
		Map<String, SObject> objectMap = new Map<String, SObject>();

		if(objectList != null)
		{
			for(SObject listItem : objectList)
			{
				objectMap.put(String.valueOf(getFieldValue(listItem, keyFieldName)), listItem);
			}
		}

		return objectMap;
	}

	/**
	 * @description Converts a list of SObjects into a single-value map by a String field using a typed field token.
	 *
	 * @param objectList The SObjects to map
	 * @param keyField The field token for the key
	 *
	 * @return A map of String to SObject
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Map<String, SObject> accountByName = UTIL_SObject.indexByStringKey(accounts, Account.Name);
	 * ```
	 */
	global static Map<String, SObject> indexByStringKey(List<SObject> objectList, SObjectField keyField)
	{
		return indexByStringKey(objectList, UTIL_SObjectDescribe.getCachedFieldName(keyField));
	}

	/**
	 * @description Retrieves the value for a field on an SObject using dot-notation for related objects.
	 *
	 * @param anObject The SObject (can include related object data)
	 * @param fieldName A single field name or dot-notation path (e.g. 'Contact.Name')
	 *
	 * @return The value of the field
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Object name = UTIL_SObject.getFieldValue(account, 'Name');
	 * Object contactName = UTIL_SObject.getFieldValue(myCase, 'Contact.Name');
	 * ```
	 */
	global static Object getFieldValue(SObject anObject, String fieldName)
	{
		if(anObject == null)
		{
			return null;
		}

		List<String> fieldNameParts = UTIL_String.splitByWholeSeparator(fieldName, UTIL_String.DOT);
		SObject objectToUse = anObject;

		for(Integer i = 0; i < fieldNameParts.size() - 1; i++)
		{
			objectToUse = objectToUse?.getSObject(fieldNameParts[i]);
		}

		return objectToUse?.get(fieldNameParts[fieldNameParts.size() - 1]);
	}

	/**
	 * @description Will return an Id if the string is a valid Id else null
	 *
	 * @param stringId A string containing the ID
	 *
	 * @return Either a valid ID or null
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Id result = UTIL_SObject.validateId('001000000000001');
	 * ```
	 */
	@SuppressWarnings('PMD.EmptyCatchBlock')
	global static Id validateId(String stringId)
	{
		Id validatedId = null;

		try
		{
			validatedId = Id.valueOf(stringId);
		}
		catch(Exception error)
		{
			// Do nothing here as the conversion to Id failed and therefore this is NOT a valid ID
		}

		return validatedId;
	}

	/**
	 * @description Checks whether a specific field value has changed between the old and new versions of a record.
	 *
	 * @param newRecord The new version of the record (from Trigger.new).
	 * @param oldRecord The old version of the record (from Trigger.oldMap).
	 * @param field The field to check for changes.
	 *
	 * @return True if the field value differs between the old and new records.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * if(UTIL_SObject.hasFieldChanged(newRecord, oldRecord, Foobar__c.Status__c))
	 * {
	 *     // Handle status change
	 * }
	 * ```
	 */
	global static Boolean hasFieldChanged(SObject newRecord, SObject oldRecord, SObjectField field)
	{
		return newRecord.get(field) != oldRecord.get(field);
	}

	/**
	 * @description Returns only the records where a specific field value has changed between the old and new
	 * versions. Compares each record in the new list against the corresponding record in the old list by index.
	 *
	 * @param newRecords The new versions of the records (from Trigger.new).
	 * @param oldRecords The old versions of the records (from Trigger.old).
	 * @param field The field to check for changes.
	 *
	 * @return A list containing only the new records where the specified field value changed.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObject> statusChanged = UTIL_SObject.getChangedRecords(newRecords, oldRecords, Foobar__c.Status__c);
	 * ```
	 */
	global static List<SObject> getChangedRecords(List<SObject> newRecords, List<SObject> oldRecords, SObjectField field)
	{
		return getChangedRecords(newRecords, oldRecords, new Set<SObjectField> {field});
	}

	/**
	 * @description Returns only the records where any of the specified fields have changed between the old and new
	 * versions. Compares each record in the new list against the corresponding record in the old list by index.
	 *
	 * @param newRecords The new versions of the records (from Trigger.new).
	 * @param oldRecords The old versions of the records (from Trigger.old).
	 * @param fields The set of fields to check for changes. A record is included if any field changed.
	 *
	 * @return A list containing only the new records where at least one of the specified fields changed.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<SObject> addressChanged = UTIL_SObject.getChangedRecords
	 * (
	 *     newRecords, oldRecords,
	 *     new Set<SObjectField>{ Foobar__c.Text__c, Foobar__c.Email__c }
	 * );
	 * ```
	 */
	global static List<SObject> getChangedRecords(List<SObject> newRecords, List<SObject> oldRecords, Set<SObjectField> fields)
	{
		List<SObject> changedRecords = new List<SObject>();

		for(Integer i = 0; i < newRecords.size(); i++)
		{
			for(SObjectField field : fields)
			{
				if(hasFieldChanged(newRecords[i], oldRecords[i], field))
				{
					changedRecords.add(newRecords[i]);
					break;
				}
			}
		}

		return changedRecords;
	}
}