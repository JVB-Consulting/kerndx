// SPDX-License-Identifier: MIT
/**
 * MIT License
 *
 * Copyright (c) 2018 Aidan Harding, Nebula Consulting
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
 * PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
 * OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

/**
 * @description In-memory index for SObjects, indexed by one or more fields. Supports cross-object field references,
 * case-insensitive matching, and hierarchical multi-field indexing.
 *
 * **Performance & Usage Guidelines**
 *
 * Use MAP_SObject when:
 * - **Grouping (1-to-Many):** You need to map a key to multiple records (e.g., "Get all Contacts by AccountId").
 *   MAP_SObject handles list creation automatically, eliminating boilerplate null-checks.
 * - **Cross-Object Fields:** You need to index by relationship fields (e.g., `Account.Owner.Name`).
 * - **Composite Keys:** You need hierarchical indexing by multiple fields (e.g., AccountId then LastName).
 * - **Case-Insensitive Matching:** You need to match keys regardless of case without manual string normalization.
 *
 * Use native `Map<Id, SObject>` instead when:
 * - **Unique Primary Keys:** You are indexing by Id or a unique field where 1 Key = 1 Record.
 *   Native Apex Maps are approximately 5-10x faster and consume less heap memory than this utility.
 *   Always prefer native Maps for simple ID lookups in performance-critical code paths (e.g., triggers).
 *
 * ```apex
 * // BAD: Using MAP_SObject for unique ID lookups
 * MAP_SObject accountsById = MAP_SObject.of(accounts, 'Id');
 * Account account = (Account)accountsById.get(someId);
 *
 * // GOOD: Using native Map for unique ID lookups
 * Map<Id, Account> accountsById = new Map<Id, Account>(accounts);
 * Account account = accountsById.get(someId);
 *
 * // GOOD: Using MAP_SObject for 1-to-Many grouping
 * MAP_SObject contactsByAccountId = MAP_SObject.of(contacts, 'AccountId');
 * List<Contact> accountContacts = contactsByAccountId.getAll(someAccountId);
 * ```
 *
 * Adapted from: [SObjectIndex](https://bitbucket.org/aidan_harding/sobjectindex/src/master/)
 *
 * @see MAP_SObject_TEST
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
 * MAP_SObject contactsByAccountId = MAP_SObject.of(contacts, 'AccountId');
 * List<Contact> accountContacts = contactsByAccountId.getAll(someAccountId);
 * Contact first = (Contact)contactsByAccountId.get(someAccountId);
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessivePublicCount,PMD.AvoidGlobalModifier')
global inherited sharing class MAP_SObject
{
	/**
	 * @description Error message when attempting to change case sensitivity on a non-empty index.
	 */
	@TestVisible
	private static final String ERROR_CASE_INSENSITIVE = 'Case sensitivity can only be changed on an empty index';

	/**
	 * @description Whether keys should be case-insensitive.
	 */
	private Boolean isCaseInsensitive;

	/**
	 * @description Whether this is the last level in the index hierarchy.
	 */
	private final Boolean isLastIndexLayer;

	/**
	 * @description Current depth in the index tree.
	 */
	private final Integer thisIndexDepth;

	/**
	 * @description All field names used for indexing.
	 */
	private final List<String> allIndexFields;

	/**
	 * @description The field name for this level of the index.
	 */
	private final String thisIndexField;

	/**
	 * @description Whether the field name is simple (no dot notation for cross-object reference).
	 */
	private final Boolean isSimpleField;

	/**
	 * @description Hybrid storage: values are either List<SObject> (leaf) or MAP_SObject (branch).
	 */
	private final Map<String, Object> data;

	/**
	 * @description Creates an index from a list of records indexed by a single field.
	 *
	 * @param records The records to index.
	 * @param fieldName The field to index by.
	 *
	 * @return A new MAP_SObject containing the indexed records.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject accountsById = MAP_SObject.of(accounts, 'Id');
	 * Account acc = (Account)accountsById.get(someId);
	 * ```
	 */
	global static MAP_SObject of(List<SObject> records, String fieldName)
	{
		return new MAP_SObject(fieldName).putAll(records);
	}

	/**
	 * @description Creates an index from a list of records indexed by a single field token.
	 *
	 * @param records The records to index.
	 * @param field The field token to index by.
	 *
	 * @return A new MAP_SObject containing the indexed records.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject accountsById = MAP_SObject.of(accounts, Account.Id);
	 * Account acc = (Account)accountsById.get(someId);
	 * ```
	 */
	global static MAP_SObject of(List<SObject> records, SObjectField field)
	{
		return new MAP_SObject(field.getDescribe().getName()).putAll(records);
	}

	/**
	 * @description Creates an index from a list of records indexed by multiple fields.
	 *
	 * @param records The records to index.
	 * @param fieldNames The fields to index by (hierarchical).
	 *
	 * @return A new MAP_SObject containing the indexed records.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject contactsByAccountAndName = MAP_SObject.of(contacts, new List<String>{'AccountId', 'LastName'});
	 * List<Contact> contacts = contactsByAccountAndName.getAll(new Contact(AccountId = accId, LastName = 'Smith'));
	 * ```
	 */
	global static MAP_SObject of(List<SObject> records, List<String> fieldNames)
	{
		return new MAP_SObject(fieldNames).putAll(records);
	}

	/**
	 * @description Initializes a new MAP_SObject with a single indexed field.
	 *
	 * @param fieldName The name of the field to index.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = new MAP_SObject('Name');
	 * ```
	 */
	global MAP_SObject(String fieldName)
	{
		this(new List<String> {fieldName}, 0);
	}

	/**
	 * @description Initializes a new MAP_SObject with multiple indexed fields.
	 *
	 * @param indexFields The list of fields to index.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = new MAP_SObject(new List<String>{'AccountId', 'LastName'});
	 * ```
	 */
	global MAP_SObject(List<String> indexFields)
	{
		this(indexFields, 0);
	}

	/**
	 * @description Internal constructor for initializing the index with fields and depth.
	 *
	 * @param indexFields The list of fields to index.
	 * @param fieldDepth The current depth in the index tree.
	 */
	private MAP_SObject(List<String> indexFields, Integer fieldDepth)
	{
		this.thisIndexDepth = fieldDepth;
		this.allIndexFields = indexFields;
		this.thisIndexField = indexFields[fieldDepth];
		this.isSimpleField = !this.thisIndexField.contains('.');
		this.isLastIndexLayer = fieldDepth == indexFields.size() - 1;
		this.isCaseInsensitive = false;
		this.data = new Map<String, Object>();
	}

	/**
	 * @description Enables case-insensitive key matching. Must be called on an empty index.
	 *
	 * @return This MAP_SObject instance for method chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = MAP_SObject.of(contacts, 'Email').caseInsensitive();
	 * Contact c = (Contact)index.get('JOHN@EXAMPLE.COM');
	 * ```
	 */
	global MAP_SObject caseInsensitive()
	{
		if(!isEmpty())
		{
			throw new UTIL_Exceptions.IllegalStateException(ERROR_CASE_INSENSITIVE);
		}
		this.isCaseInsensitive = true;
		return this;
	}

	/**
	 * @description Adds a single SObject to the index.
	 *
	 * @param sObjectToAdd The SObject to add.
	 *
	 * @return This MAP_SObject instance for method chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = new MAP_SObject('Name');
	 * index.put(new Account(Name='Acme'));
	 * ```
	 */
	global MAP_SObject put(SObject sObjectToAdd)
	{
		String key = getKeyFrom(sObjectToAdd);

		if(isLastIndexLayer)
		{
			List<SObject> records = (List<SObject>)data.get(key);
			if(records == null)
			{
				records = new List<SObject>();
				data.put(key, records);
			}
			records.add(sObjectToAdd);
		}
		else
		{
			MAP_SObject childIndex = (MAP_SObject)data.get(key);
			if(childIndex == null)
			{
				childIndex = new MAP_SObject(allIndexFields, thisIndexDepth + 1);
				childIndex.isCaseInsensitive = this.isCaseInsensitive;
				data.put(key, childIndex);
			}
			childIndex.put(sObjectToAdd);
		}

		return this;
	}

	/**
	 * @description Adds a list of SObjects to the index.
	 *
	 * @param sObjectsToAdd List of SObjects to add.
	 *
	 * @return This MAP_SObject instance for method chaining.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = new MAP_SObject('Name');
	 * index.putAll(new List<Account>{new Account(Name='Acme')});
	 * ```
	 */
	global MAP_SObject putAll(List<SObject> sObjectsToAdd)
	{
		for(SObject sObjectToAdd : sObjectsToAdd)
		{
			put(sObjectToAdd);
		}
		return this;
	}

	/**
	 * @description Retrieves a single SObject matching the specified key.
	 *
	 * @param key A value for the indexed field.
	 *
	 * @return A matching SObject, or null if no match is found (returns the first match if multiple exist).
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = MAP_SObject.of(accounts, 'Id');
	 * Account acc = (Account)index.get(someAccountId);
	 * ```
	 */
	global SObject get(Object key)
	{
		List<SObject> results = getAll(key);
		return results.isEmpty() ? null : results[0];
	}

	/**
	 * @description Retrieves a single SObject matching the specification SObject on all indexed fields.
	 *
	 * @param specification An SObject with values for all indexed fields.
	 *
	 * @return A matching SObject, or null if no match is found (returns the first match if multiple exist).
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = MAP_SObject.of(contacts, new List<String>{'AccountId', 'LastName'});
	 * Contact c = (Contact)index.get(new Contact(AccountId = accId, LastName = 'Smith'));
	 * ```
	 */
	global SObject get(SObject specification)
	{
		List<SObject> results = getAll(specification);
		return results.isEmpty() ? null : results[0];
	}

	/**
	 * @description Retrieves all SObjects matching the specified key.
	 *
	 * @param key A value for the indexed field.
	 *
	 * @return A list of matching SObjects, or an empty list if no matches are found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = MAP_SObject.of(contacts, 'AccountId');
	 * List<Contact> accountContacts = index.getAll(someAccountId);
	 * ```
	 */
	global List<SObject> getAll(Object key)
	{
		String serializedKey = serializeKey(key);
		Object child = data.get(serializedKey);

		if(child == null)
		{
			return new List<SObject>();
		}

		if(child instanceof List<SObject>)
		{
			return (List<SObject>)child;
		}

		return ((MAP_SObject)child).values();
	}

	/**
	 * @description Retrieves all SObjects matching the specification SObject on all indexed fields.
	 *
	 * @param specification An SObject with values for all indexed fields.
	 *
	 * @return A list of matching SObjects, or an empty list if no matches are found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = MAP_SObject.of(contacts, new List<String>{'AccountId', 'LastName'});
	 * List<Contact> results = index.getAll(new Contact(AccountId = accId, LastName = 'Smith'));
	 * ```
	 */
	global List<SObject> getAll(SObject specification)
	{
		String key = getKeyFrom(specification);
		Object child = data.get(key);

		if(child == null)
		{
			return new List<SObject>();
		}

		if(child instanceof List<SObject>)
		{
			return (List<SObject>)child;
		}

		return ((MAP_SObject)child).getAll(specification);
	}

	/**
	 * @description Retrieves all SObjects matching the field-value map for indexed fields.
	 *
	 * @param fieldValueMap A map of field names to values.
	 *
	 * @return A list of matching SObjects, or an empty list if no matches are found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = MAP_SObject.of(contacts, new List<String>{'AccountId', 'LastName'});
	 * Map<String, Object> spec = new Map<String, Object>{ 'LastName' => 'Smith' };
	 * List<Contact> results = index.getAll(spec);
	 * ```
	 */
	global List<SObject> getAll(Map<String, Object> fieldValueMap)
	{
		if(fieldValueMap.containsKey(thisIndexField))
		{
			String key = getKeyFrom(fieldValueMap);
			Object child = data.get(key);

			if(child == null)
			{
				return new List<SObject>();
			}

			if(child instanceof List<SObject>)
			{
				return (List<SObject>)child;
			}

			return ((MAP_SObject)child).getAll(fieldValueMap);
		}
		else
		{
			List<SObject> accumulator = new List<SObject>();
			fillAllMatching(fieldValueMap, accumulator);
			return accumulator;
		}
	}

	/**
	 * @description Retrieves a sub-index for entries matching the specified key.
	 *
	 * @param key A value for the first indexed field.
	 *
	 * @return A MAP_SObject for matching entries, or null if no match is found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = MAP_SObject.of(contacts, new List<String>{'AccountId', 'LastName'});
	 * MAP_SObject accountContacts = index.getSubIndex(someAccountId);
	 * List<Contact> smiths = accountContacts.getAll('Smith');
	 * ```
	 */
	global MAP_SObject getSubIndex(Object key)
	{
		String serializedKey = serializeKey(key);
		Object child = data.get(serializedKey);

		if(child instanceof MAP_SObject)
		{
			return (MAP_SObject)child;
		}

		return null;
	}

	/**
	 * @description Removes SObjects matching the specification SObject from the index.
	 *
	 * @param specification An SObject with values for all indexed fields.
	 *
	 * @return A list of removed SObjects, or an empty list if no matches are found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = MAP_SObject.of(contacts, 'AccountId');
	 * List<SObject> removed = index.remove(new Contact(AccountId = accId));
	 * ```
	 */
	global List<SObject> remove(SObject specification)
	{
		String key = getKeyFrom(specification);
		return removeByKey(key, specification);
	}

	/**
	 * @description Removes SObjects matching the field-value map from the index.
	 *
	 * @param fieldValueMap A map of field names to values.
	 *
	 * @return A list of removed SObjects, or an empty list if no matches are found.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = MAP_SObject.of(contacts, new List<String>{'AccountId', 'LastName'});
	 * Map<String, Object> spec = new Map<String, Object>{ 'LastName' => 'Smith' };
	 * List<SObject> removed = index.remove(spec);
	 * ```
	 */
	global List<SObject> remove(Map<String, Object> fieldValueMap)
	{
		if(fieldValueMap.containsKey(thisIndexField))
		{
			String key = getKeyFrom(fieldValueMap);
			return removeByKey(key, fieldValueMap);
		}
		else
		{
			List<SObject> removedValues = new List<SObject>();
			for(Object child : data.values())
			{
				if(child instanceof MAP_SObject)
				{
					removedValues.addAll(((MAP_SObject)child).remove(fieldValueMap));
				}
			}
			return removedValues;
		}
	}

	/**
	 * @description Removes data at the given key, delegating to child index if needed.
	 * Removes keys entirely to prevent memory leaks and ensure isEmpty() is accurate.
	 *
	 * @param key The serialized key.
	 * @param removalSpec The specification (SObject or Map) to pass to child index.
	 *
	 * @return List of removed records.
	 */
	private List<SObject> removeByKey(String key, Object removalSpec)
	{
		Object child = data.get(key);

		if(child == null)
		{
			return new List<SObject>();
		}

		if(child instanceof List<SObject>)
		{
			data.remove(key);
			return (List<SObject>)child;
		}

		MAP_SObject childIndex = (MAP_SObject)child;
		List<SObject> removed;

		if(removalSpec instanceof SObject)
		{
			removed = childIndex.remove((SObject)removalSpec);
		}
		else
		{
			removed = childIndex.remove((Map<String, Object>)removalSpec);
		}

		if(childIndex.isEmpty())
		{
			data.remove(key);
		}

		return removed;
	}

	/**
	 * @description Checks if the index is empty.
	 *
	 * @return `true` if the index is empty, `false` otherwise.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = new MAP_SObject('Name');
	 * Boolean isEmpty = index.isEmpty(); // Returns true
	 * ```
	 */
	global Boolean isEmpty()
	{
		return data.isEmpty();
	}

	/**
	 * @description Checks if the index contains records for the specified key at the first index level.
	 *
	 * @param key A value for the first indexed field.
	 *
	 * @return `true` if records exist for the key, `false` otherwise.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = MAP_SObject.of(accounts, 'Industry');
	 * if(index.containsKey('Technology'))
	 * {
	 *     // Process technology accounts
	 * }
	 * ```
	 */
	global Boolean containsKey(Object key)
	{
		String serializedKey = serializeKey(key);
		return data.containsKey(serializedKey);
	}

	/**
	 * @description Returns the total number of SObjects stored in the index. More efficient than `values().size()`
	 * as it counts recursively without materializing the full list.
	 *
	 * @return The total count of indexed SObjects.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = MAP_SObject.of(contacts, 'AccountId');
	 * System.debug('Indexed ' + index.size() + ' contacts');
	 * ```
	 */
	global Integer size()
	{
		Integer count = 0;
		for(Object child : data.values())
		{
			if(child instanceof List<SObject>)
			{
				count += ((List<SObject>)child).size();
			}
			else
			{
				count += ((MAP_SObject)child).size();
			}
		}
		return count;
	}

	/**
	 * @description Removes all records from the index, allowing it to be reused or explicitly freeing memory.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = MAP_SObject.of(accounts, 'Industry');
	 * index.clear();
	 * Assert.isTrue(index.isEmpty());
	 * ```
	 */
	global void clear()
	{
		data.clear();
	}

	/**
	 * @description Returns a string representation of the index structure for debugging purposes.
	 *
	 * @return A string showing the index field, depth, and current keys.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = MAP_SObject.of(contacts, new List<String>{'AccountId', 'LastName'});
	 * System.debug(index); // Outputs: MAP_SObject[field=AccountId, depth=0, keys={001...}]
	 * ```
	 */
	global override String toString()
	{
		return 'MAP_SObject[field=' + thisIndexField + ', depth=' + thisIndexDepth + ', keys=' + data.keySet() + ']';
	}

	/**
	 * @description Retrieves the set of unique keys for the current index level.
	 *
	 * @return A set of string keys.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = MAP_SObject.of(accounts, 'Industry');
	 * Set<String> industries = index.keySet();
	 * ```
	 */
	global Set<String> keySet()
	{
		return data.keySet();
	}

	/**
	 * @description Retrieves the set of unique keys for a specific field in the index.
	 *
	 * @param field The field name to retrieve keys for.
	 *
	 * @return A set of string keys.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = MAP_SObject.of(contacts, new List<String>{'AccountId', 'LastName'});
	 * Set<String> lastNames = index.keySet('LastName');
	 * ```
	 */
	global Set<String> keySet(String field)
	{
		Set<String> accumulator = new Set<String>();
		fillKeySet(field, accumulator);
		return accumulator;
	}

	/**
	 * @description Fills the accumulator with keys for the specified field using depth-first traversal.
	 *
	 * @param field The field name to retrieve keys for.
	 * @param accumulator The set to fill with keys.
	 */
	private void fillKeySet(String field, Set<String> accumulator)
	{
		if(thisIndexField == field)
		{
			accumulator.addAll(data.keySet());
			return;
		}

		for(Object child : data.values())
		{
			if(child instanceof MAP_SObject)
			{
				((MAP_SObject)child).fillKeySet(field, accumulator);
			}
		}
	}

	/**
	 * @description Retrieves all SObjects stored in the index.
	 *
	 * @return A list of all SObjects in the index.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * MAP_SObject index = MAP_SObject.of(accounts, 'Industry');
	 * List<SObject> allAccounts = index.values();
	 * ```
	 */
	global List<SObject> values()
	{
		List<SObject> accumulator = new List<SObject>();
		fillValues(accumulator);
		return accumulator;
	}

	/**
	 * @description Fills the accumulator with all values using depth-first traversal.
	 *
	 * @param accumulator The list to fill with values.
	 */
	private void fillValues(List<SObject> accumulator)
	{
		for(Object child : data.values())
		{
			if(child instanceof List<SObject>)
			{
				accumulator.addAll((List<SObject>)child);
			}
			else
			{
				((MAP_SObject)child).fillValues(accumulator);
			}
		}
	}

	/**
	 * @description Fills the accumulator with all records matching the field-value map.
	 *
	 * @param fieldValueMap The field-value map to match.
	 * @param accumulator The list to fill with matching values.
	 */
	private void fillAllMatching(Map<String, Object> fieldValueMap, List<SObject> accumulator)
	{
		for(Object child : data.values())
		{
			if(child instanceof List<SObject>)
			{
				accumulator.addAll((List<SObject>)child);
			}
			else
			{
				MAP_SObject childIndex = (MAP_SObject)child;
				if(fieldValueMap.containsKey(childIndex.thisIndexField))
				{
					accumulator.addAll(childIndex.getAll(fieldValueMap));
				}
				else
				{
					childIndex.fillAllMatching(fieldValueMap, accumulator);
				}
			}
		}
	}

	/**
	 * @description Serializes a key value to a string, applying case-insensitivity if configured.
	 *
	 * @param key The key value to serialize.
	 *
	 * @return The serialized key string.
	 */
	private String serializeKey(Object key)
	{
		if(key == null)
		{
			return null;
		}

		if(key instanceof Id)
		{
			return String.valueOf(key);
		}

		String value = String.valueOf(key);
		return isCaseInsensitive ? value.toLowerCase() : value;
	}

	/**
	 * @description Retrieves the serialized key from an SObject.
	 *
	 * @param sObjectRecord The SObject to extract the key from.
	 *
	 * @return The serialized key.
	 */
	private String getKeyFrom(SObject sObjectRecord)
	{
		Object value;
		if(isSimpleField)
		{
			value = sObjectRecord.get(thisIndexField);
		}
		else
		{
			value = UTIL_SObject.getFieldValue(sObjectRecord, thisIndexField);
		}
		return serializeKey(value);
	}

	/**
	 * @description Retrieves the serialized key from a field-value map.
	 *
	 * @param fieldValueMap The map containing field values.
	 *
	 * @return The serialized key.
	 */
	private String getKeyFrom(Map<String, Object> fieldValueMap)
	{
		return serializeKey(fieldValueMap.get(thisIndexField));
	}
}