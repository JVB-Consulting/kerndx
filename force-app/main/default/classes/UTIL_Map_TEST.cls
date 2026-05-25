// SPDX-License-Identifier: Apache-2.0
// Copyright (c) apex-lang contributors (see https://code.google.com/p/apex-lang/)
// Adapted from apex-lang (https://code.google.com/p/apex-lang/)
// Modifications copyright (c) 2026 JVB Consulting

/**
 * @description Unit tests for the UTIL_Map utility class covering flattenValues,
 * toDelimitedString, and CaseInsensitiveMap behaviour.
 *
 * @see UTIL_Map
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_Map_TEST
{
	/**
	 * @description Confirms that the source-map constructor populates entries with case-insensitive access.
	 */
	@IsTest
	private static void shouldInitialiseFromSourceMap()
	{
		Map<String, Object> sourceMap = new Map<String, Object>
		{
				'FirstKey' => 1,
				'secondKey' => 'two'
		};

		Test.startTest();

		UTIL_Map.CaseInsensitiveMap caseInsensitiveMap = new UTIL_Map.CaseInsensitiveMap(sourceMap);

		Test.stopTest();

		Assert.areEqual(sourceMap.size(), caseInsensitiveMap.size(), 'Map size should match the source map.');
		Assert.areEqual(1, caseInsensitiveMap.get('firstkey'), 'Should retrieve value regardless of case.');
		Assert.areEqual('two', caseInsensitiveMap.get('SECONDKEY'), 'Should retrieve value regardless of case.');
	}

	/**
	 * @description Confirms that a stored value can be retrieved using any casing of the original key.
	 */
	@IsTest
	private static void shouldRetrieveValueRegardlessOfCase()
	{
		UTIL_Map.CaseInsensitiveMap caseInsensitiveMap = new UTIL_Map.CaseInsensitiveMap();

		String originalKey = 'MyKey';
		String testValue = 'TestValue';

		Test.startTest();

		caseInsensitiveMap.put(originalKey, testValue);
		Object retrievedValueLowerCase = caseInsensitiveMap.get('mykey');
		Object retrievedValueUpperCase = caseInsensitiveMap.get('MYKEY');
		Object retrievedValueOriginalCase = caseInsensitiveMap.get('MyKey');

		Test.stopTest();

		Assert.areEqual(1, caseInsensitiveMap.size(), 'Map should contain one element.');
		Assert.areEqual(testValue, retrievedValueLowerCase, 'Get should be case-insensitive(lowercase).');
		Assert.areEqual(testValue, retrievedValueUpperCase, 'Get should be case-insensitive(uppercase).');
		Assert.areEqual(testValue, retrievedValueOriginalCase, 'Get should work with original case.');
	}

	/**
	 * @description Confirms that putting a value with a differently-cased key replaces both the value and the stored key form.
	 */
	@IsTest
	private static void shouldOverwriteExistingKeyWithDifferentCase()
	{
		UTIL_Map.CaseInsensitiveMap caseInsensitiveMap = new UTIL_Map.CaseInsensitiveMap();
		caseInsensitiveMap.put('OriginalKey', 1);

		caseInsensitiveMap.put('originalkey', 2);

		Set<String> expectedKeySet = new Set<String> {'originalkey'};
		Assert.areEqual(1, caseInsensitiveMap.size(), 'Map size should remain 1 after overwrite.');
		Assert.areEqual(2, caseInsensitiveMap.get('ORIGINALKEY'), 'The value should be overwritten.');
		Assert.areEqual(expectedKeySet, caseInsensitiveMap.keySet(), 'The original key casing should be updated.');
	}

	/**
	 * @description Confirms that putAll inserts every entry from the provided source map.
	 */
	@IsTest
	private static void shouldAddAllEntriesFromSourceMap()
	{
		UTIL_Map.CaseInsensitiveMap caseInsensitiveMap = new UTIL_Map.CaseInsensitiveMap();
		Map<String, Object> sourceMap = new Map<String, Object>
		{
				'Alpha' => 100,
				'Beta' => 200
		};

		Test.startTest();

		caseInsensitiveMap.putAll(sourceMap);

		Test.stopTest();

		Assert.areEqual(sourceMap.size(), caseInsensitiveMap.size(), 'Map size should be 2.');
		Assert.areEqual(100, caseInsensitiveMap.get('alpha'), 'Get should be case-insensitive(lowercase).');
		Assert.areEqual(200, caseInsensitiveMap.get('beta'), 'Get should be case-insensitive(lowercase).');
	}

	/**
	 * @description Confirms that get returns null when the requested key has no mapping.
	 */
	@IsTest
	private static void shouldReturnNullForMissingKey()
	{
		UTIL_Map.CaseInsensitiveMap caseInsensitiveMap = new UTIL_Map.CaseInsensitiveMap();
		caseInsensitiveMap.put('ExistingKey', 'SomeValue');

		Test.startTest();

		Object result = caseInsensitiveMap.get('NonExistentKey');

		Test.stopTest();

		Assert.isNull(result, 'Getting a non-existent key should return null.');
	}

	/**
	 * @description Confirms that remove deletes the entry using a case-insensitive key match and returns the old value.
	 */
	@IsTest
	private static void shouldRemoveEntryByCaseInsensitiveKey()
	{
		UTIL_Map.CaseInsensitiveMap caseInsensitiveMap = new UTIL_Map.CaseInsensitiveMap();
		String keyToRemove = 'ToBeRemoved';
		String valueToRemove = 'Goodbye';
		caseInsensitiveMap.put(keyToRemove, valueToRemove);
		caseInsensitiveMap.put('AnotherKey', 'Stay');

		Object removedValue = caseInsensitiveMap.remove('toberemoved');

		Assert.areEqual(valueToRemove, removedValue, 'Remove should return the value of the removed key.');
		Assert.areEqual(1, caseInsensitiveMap.size(), 'Map size should be decremented.');
		Assert.areEqual(false, caseInsensitiveMap.containsKey(keyToRemove), 'The key should no longer exist.');
	}

	/**
	 * @description Confirms that containsKey matches keys irrespective of letter case.
	 */
	@IsTest
	private static void shouldDetectKeyRegardlessOfCase()
	{
		UTIL_Map.CaseInsensitiveMap caseInsensitiveMap = new UTIL_Map.CaseInsensitiveMap();

		Test.startTest();

		caseInsensitiveMap.put('KeyOne', 1);

		Test.stopTest();

		Assert.areEqual(true, caseInsensitiveMap.containsKey('keyone'), 'Should be true for lowercase.');
		Assert.areEqual(true, caseInsensitiveMap.containsKey('KEYONE'), 'Should be true for uppercase.');
		Assert.areEqual(true, caseInsensitiveMap.containsKey('KeyOne'), 'Should be true for original case.');
		Assert.areEqual(false, caseInsensitiveMap.containsKey('KeyTwo'), 'Should be false for non-existent key.');
	}

	/**
	 * @description Confirms that keySet returns keys in their original, caller-supplied casing.
	 */
	@IsTest
	private static void shouldPreserveOriginalKeyCasing()
	{
		UTIL_Map.CaseInsensitiveMap caseInsensitiveMap = new UTIL_Map.CaseInsensitiveMap();

		caseInsensitiveMap.put('FirstKey', 1);
		caseInsensitiveMap.put('secondKey', 2);
		caseInsensitiveMap.put('THIRD_KEY', 3);
		caseInsensitiveMap.put(null, 4);

		Set<String> expectedKeys = new Set<String> {'FirstKey', 'secondKey', 'THIRD_KEY', null};

		Test.startTest();

		Set<String> actualKeys = caseInsensitiveMap.keySet();

		Test.stopTest();

		Assert.areEqual(expectedKeys, actualKeys, 'keySet should return all keys with their original casing.');
	}

	/**
	 * @description Confirms that values returns every value stored in the map.
	 */
	@IsTest
	private static void shouldReturnAllMapValues()
	{
		UTIL_Map.CaseInsensitiveMap caseInsensitiveMap = new UTIL_Map.CaseInsensitiveMap();

		caseInsensitiveMap.put('A', 1);
		caseInsensitiveMap.put('B', 'Two');

		Test.startTest();

		List<Object> mapValues = caseInsensitiveMap.values();

		Test.stopTest();

		Assert.areEqual(2, mapValues.size(), 'values() should return a list of all values.');

		Assert.isTrue(mapValues.contains(1), 'Value should match');
		Assert.isTrue(mapValues.contains('Two'), 'Value should match');
	}

	/**
	 * @description Confirms that toMap exports entries to a standard map with original key casing restored.
	 */
	@IsTest
	private static void shouldExportToStandardMapWithOriginalCasing()
	{
		UTIL_Map.CaseInsensitiveMap caseInsensitiveMap = new UTIL_Map.CaseInsensitiveMap();

		caseInsensitiveMap.put('OriginalCase', 123);
		caseInsensitiveMap.put('another_key', 456);

		Test.startTest();

		Map<String, Object> standardMap = caseInsensitiveMap.toMap();

		Test.stopTest();

		Assert.areEqual(2, standardMap.size(), 'The new map should have the same size.');
		Assert.isTrue(standardMap.containsKey('OriginalCase'), 'Map should contain original cased key.');
		Assert.isFalse(standardMap.containsKey('originalcase'), 'Map should not contain lowercase key.');
		Assert.areEqual(123, standardMap.get('OriginalCase'), 'Shold find based on original case');
	}

	/**
	 * @description Confirms that copy produces an independent instance unaffected by later mutations to the original.
	 */
	@IsTest
	private static void shouldCreateIndependentCopy()
	{
		UTIL_Map.CaseInsensitiveMap originalMap = new UTIL_Map.CaseInsensitiveMap();
		originalMap.put('Key1', 'Value1');

		Test.startTest();

		UTIL_Map.CaseInsensitiveMap copiedMap = originalMap.copy();
		originalMap.put('Key2', 'Value2');

		Test.stopTest();

		Assert.areEqual(1, copiedMap.size(), 'Copied map should have the size of the original at copy time.');
		Assert.areEqual('Value1', copiedMap.get('key1'), 'Copied map should contain the original data.');
		Assert.isFalse(copiedMap.containsKey('Key2'), 'Changes to original map should not affect the copy.');
	}

	/**
	 * @description Confirms that clear empties the map completely.
	 */
	@IsTest
	private static void shouldClearAllEntries()
	{
		UTIL_Map.CaseInsensitiveMap caseInsensitiveMap = new UTIL_Map.CaseInsensitiveMap();
		caseInsensitiveMap.put('Key1', 1);
		caseInsensitiveMap.put('Key2', 2);

		Test.startTest();

		caseInsensitiveMap.clear();

		Test.stopTest();

		Assert.areEqual(0, caseInsensitiveMap.size(), 'Map size should be 0 after clear.');
		Assert.isTrue(caseInsensitiveMap.isEmpty(), 'Map should be empty after clear.');
		Assert.areEqual(0, caseInsensitiveMap.keySet().size(), 'KeySet should be empty after clear.');
	}

	/**
	 * @description Confirms that size and isEmpty reflect the map state correctly as entries are added and removed.
	 */
	@IsTest
	private static void shouldTrackSizeAndEmptiness()
	{
		UTIL_Map.CaseInsensitiveMap caseInsensitiveMap = new UTIL_Map.CaseInsensitiveMap();

		Assert.areEqual(0, caseInsensitiveMap.size(), 'Initial size should be 0.');
		Assert.isTrue(caseInsensitiveMap.isEmpty(), 'New map should be empty.');

		caseInsensitiveMap.put('One', 1);

		Assert.areEqual(1, caseInsensitiveMap.size(), 'Size should be 1 after adding an element.');
		Assert.isFalse(caseInsensitiveMap.isEmpty(), 'Map with one element should not be empty.');

		caseInsensitiveMap.remove('One');

		Assert.areEqual(0, caseInsensitiveMap.size(), 'Size should be 0 after removing the last element.');
		Assert.isTrue(caseInsensitiveMap.isEmpty(), 'Map should be empty after removing the last element.');
	}

	/**
	 * @description Confirms that null keys are handled gracefully across put, get, containsKey, and remove.
	 */
	@IsTest
	private static void shouldHandleNullKeyGracefully()
	{
		UTIL_Map.CaseInsensitiveMap caseInsensitiveMap = new UTIL_Map.CaseInsensitiveMap();
		String testValueForNullKey = 'ValueForNull';

		caseInsensitiveMap.put(null, testValueForNullKey);
		Assert.areEqual(1, caseInsensitiveMap.size(), 'Map should handle putting a null key.');
		Assert.isTrue(caseInsensitiveMap.containsKey(null), 'containsKey should work for null key.');
		Assert.areEqual(testValueForNullKey, caseInsensitiveMap.get(null), 'get should work for null key.');

		Object removedValue = caseInsensitiveMap.remove(null);
		Assert.areEqual(testValueForNullKey, removedValue, 'Remove should work for null key.');
		Assert.areEqual(0, caseInsensitiveMap.size(), 'Map should be empty after removing null key.');
	}

	/**
	 * @description Confirms that flattenValues with Id keys collects all SObjects across every list into one result.
	 *
	 * @see UTIL_Map.flattenValues
	 */
	@IsTest
	private static void shouldExtractListFromIdKeyedMap()
	{
		Foobar__c firstRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion(true)
				.build();
		Foobar__c secondRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion(true)
				.build();
		Foobar__c thirdRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion(true)
				.build();

		Map<Id, List<SObject>> recordsByIdMap = new Map<Id, List<SObject>>
		{
				firstRecord.Id => new List<SObject> {firstRecord, secondRecord},
				thirdRecord.Id => new List<SObject> {thirdRecord}
		};

		Test.startTest();

		List<SObject> result = UTIL_Map.flattenValues(recordsByIdMap);

		Test.stopTest();

		Assert.areEqual(3, result.size(), 'Should contain all SObjects from all lists');
	}

	/**
	 * @description Confirms that flattenValues with Id keys yields an empty list when the map has no entries.
	 *
	 * @see UTIL_Map.flattenValues
	 */
	@IsTest
	private static void shouldReturnEmptyListForEmptyIdKeyedMap()
	{
		Map<Id, List<SObject>> emptyMap = new Map<Id, List<SObject>>();

		Test.startTest();

		List<SObject> result = UTIL_Map.flattenValues(emptyMap);

		Test.stopTest();

		Assert.isTrue(result.isEmpty(), 'Should return an empty list for an empty map');
	}

	/**
	 * @description Confirms that flattenValues with String keys collects all SObjects across every list into one result.
	 *
	 * @see UTIL_Map.flattenValues
	 */
	@IsTest
	private static void shouldExtractListFromStringKeyedMap()
	{
		Foobar__c firstRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion(true)
				.build();
		Foobar__c secondRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion(true)
				.build();
		Foobar__c thirdRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withoutInsertion(true)
				.build();

		Map<String, List<SObject>> recordsByStringMap = new Map<String, List<SObject>>
		{
				'GroupA' => new List<SObject> {firstRecord, secondRecord},
				'GroupB' => new List<SObject> {thirdRecord}
		};

		Test.startTest();

		List<SObject> result = UTIL_Map.flattenValues(recordsByStringMap);

		Test.stopTest();

		Assert.areEqual(3, result.size(), 'Should contain all SObjects from all lists');
	}

	/**
	 * @description Confirms that flattenValues with String keys yields an empty list when the map has no entries.
	 *
	 * @see UTIL_Map.flattenValues
	 */
	@IsTest
	private static void shouldReturnEmptyListForEmptyStringKeyedMap()
	{
		Map<String, List<SObject>> emptyMap = new Map<String, List<SObject>>();

		Test.startTest();

		List<SObject> result = UTIL_Map.flattenValues(emptyMap);

		Test.stopTest();

		Assert.isTrue(result.isEmpty(), 'Should return an empty list for an empty map');
	}

	/**
	 * @description Confirms that toDelimitedString serialises a map into a name=value string with the specified separator.
	 *
	 * @see UTIL_Map.toDelimitedString
	 */
	@IsTest
	private static void shouldConvertMapToNameValueString()
	{
		Map<String, String> parameters = new Map<String, String>
		{
				'key1' => 'value1'
		};

		Test.startTest();

		String result = UTIL_Map.toDelimitedString(parameters, '&');

		Test.stopTest();

		Assert.areEqual('key1=value1', result, 'Should produce a name=value string');
	}

	/**
	 * @description Confirms that toDelimitedString falls back to a comma separator when null is provided.
	 *
	 * @see UTIL_Map.toDelimitedString
	 */
	@IsTest
	private static void shouldDefaultToCommaSeparatorWhenNull()
	{
		Map<String, String> parameters = new Map<String, String>
		{
				'key1' => 'value1'
		};

		Test.startTest();

		String result = UTIL_Map.toDelimitedString(parameters, null);

		Test.stopTest();

		Assert.isTrue(result.contains('key1=value1'), 'Should contain the name=value pair');
	}

	/**
	 * @description Confirms that toDelimitedString returns null when given a null map.
	 *
	 * @see UTIL_Map.toDelimitedString
	 */
	@IsTest
	private static void shouldReturnNullForNullMapConversion()
	{
		Test.startTest();

		String result = UTIL_Map.toDelimitedString(null, UTIL_String.COMMA);

		Test.stopTest();

		Assert.isNull(result, 'Should return null for a null map');
	}

}