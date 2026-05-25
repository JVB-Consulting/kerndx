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
 * @description Unit tests for MAP_SObject in-memory record indexing.
 *
 * Adapted from: [SObjectIndex](https://bitbucket.org/aidan_harding/sobjectindex/src/master/)
 *
 * @see MAP_SObject
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class MAP_SObject_TEST
{
	/**
	 * @description Field name for the lookup field (self-referential relationship).
	 */
	private static final String FIELD_LOOKUP = SEL_Foobar.FIELD_LOOKUP;

	/**
	 * @description Field name for the text field.
	 */
	private static final String FIELD_TEXT = SEL_Foobar.FIELD_TEXT;

	/**
	 * @description Field name for the Name field.
	 */
	private static final String FIELD_NAME = SEL_Foobar.FIELD_NAME;

	/**
	 * @description Assertion message for record equality.
	 */
	private static final String MSG_RECORD_EQUALITY = 'Records should match';

	/**
	 * @description Assertion message for key containment.
	 */
	private static final String MSG_CONTAINS_KEY = 'Key set should contain expected value';

	/**
	 * @description Assertion message for expected exception.
	 */
	private static final String MSG_EXCEPTION_EXPECTED = 'Expected exception was not thrown';

	/**
	 * @description Assertion message for ID equality.
	 */
	private static final String MSG_ID_EQUALITY = 'IDs should match';

	/**
	 * @description Assertion message for non-empty index.
	 */
	private static final String MSG_INDEX_NOT_EMPTY = 'Index should not be empty';

	/**
	 * @description Assertion message for index size.
	 */
	private static final String MSG_INDEX_SIZE = 'Index size should match expected value';

	/**
	 * @description Assertion message for null result.
	 */
	private static final String MSG_NULL_RESULT = 'Result should be null';

	/**
	 * @description Assertion message for wrong exception type.
	 */
	private static final String MSG_WRONG_EXCEPTION = 'Expected IllegalStateException was not thrown';

	/**
	 * @description Test text value used across tests.
	 */
	private static final String TEST_TEXT_VALUE = 'Doe';

	/**
	 * @description Creates test records with standard names: John Doe, Jane Doe, Fred Deer.
	 *
	 * @param parentId The parent record ID for the lookup field.
	 *
	 * @return List of three in-memory Foobar__c records.
	 */
	private static List<Foobar__c> createTestRecords(Id parentId)
	{
		List<Foobar__c> records = TST_Factory.newFoobars(3);
		records[0].put(FIELD_LOOKUP, parentId);
		records[0].put(FIELD_NAME, 'John');
		records[0].put(FIELD_TEXT, TEST_TEXT_VALUE);
		records[1].put(FIELD_LOOKUP, parentId);
		records[1].put(FIELD_NAME, 'Jane');
		records[1].put(FIELD_TEXT, TEST_TEXT_VALUE);
		records[2].put(FIELD_LOOKUP, parentId);
		records[2].put(FIELD_NAME, 'Fred');
		records[2].put(FIELD_TEXT, 'Deer');
		return records;
	}

	/**
	 * @description Creates test records with only two records sharing the same text value.
	 *
	 * @param parentId The parent record ID for the lookup field.
	 *
	 * @return List of two in-memory Foobar__c records.
	 */
	private static List<Foobar__c> createTwoTestRecords(Id parentId)
	{
		List<Foobar__c> records = TST_Factory.newFoobars(2);
		records[0].put(FIELD_LOOKUP, parentId);
		records[0].put(FIELD_NAME, 'John');
		records[0].put(FIELD_TEXT, TEST_TEXT_VALUE);
		records[1].put(FIELD_LOOKUP, parentId);
		records[1].put(FIELD_NAME, 'Jane');
		records[1].put(FIELD_TEXT, TEST_TEXT_VALUE);
		return records;
	}

	/**
	 * @description Adds records to the provided index.
	 *
	 * @param sObjectIndex Index to which to add the records.
	 * @param parentId The parent record ID for test records.
	 */
	private static void addTestRecords(MAP_SObject sObjectIndex, Id parentId)
	{
		sObjectIndex.putAll(createTestRecords(parentId));
	}

	/**
	 * @description Creates and populates an index with records including null lookup.
	 *
	 * @param parentId The parent record ID for the lookup field.
	 *
	 * @return Newly created and populated index.
	 */
	private static MAP_SObject createAndPopulateIndex(Id parentId)
	{
		List<Foobar__c> records = TST_Factory.newFoobars(3);
		records[0].put(FIELD_LOOKUP, null);
		records[0].put(FIELD_NAME, 'John');
		records[0].put(FIELD_TEXT, TEST_TEXT_VALUE);
		records[1].put(FIELD_LOOKUP, parentId);
		records[1].put(FIELD_NAME, 'Jane');
		records[1].put(FIELD_TEXT, TEST_TEXT_VALUE);
		records[2].put(FIELD_LOOKUP, parentId);
		records[2].put(FIELD_NAME, 'Fred');
		records[2].put(FIELD_TEXT, 'Deer');

		return new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT}).putAll(records);
	}

	/**
	 * @description Creates an index with two hits for testing.
	 *
	 * @param parentId The parent record ID for test records.
	 *
	 * @return Index populated with records.
	 */
	private static MAP_SObject getTwoHitsIndex(Id parentId)
	{
		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT});
		addTestRecords(sObjectIndex, parentId);
		return sObjectIndex;
	}

	/**
	 * @description Tests static factory method with string field name.
	 */
	@IsTest
	private static void shouldCreateIndexWithStaticFactoryAndStringField()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		List<Foobar__c> records = createTwoTestRecords(parent.Id);

		Test.startTest();

		MAP_SObject index = MAP_SObject.of(records, FIELD_LOOKUP);

		Test.stopTest();

		Assert.areEqual(2, index.getAll(parent.Id).size(), MSG_INDEX_SIZE);
	}

	/**
	 * @description Tests static factory method with SObjectField token.
	 */
	@IsTest
	private static void shouldCreateIndexWithStaticFactoryAndFieldToken()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		List<Foobar__c> records = createTwoTestRecords(parent.Id);

		Test.startTest();

		MAP_SObject index = MAP_SObject.of(records, Foobar__c.Lookup__c);

		Test.stopTest();

		Assert.areEqual(2, index.getAll(parent.Id).size(), MSG_INDEX_SIZE);
	}

	/**
	 * @description Tests static factory method with multiple fields.
	 */
	@IsTest
	private static void shouldCreateIndexWithStaticFactoryAndMultipleFields()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		List<Foobar__c> records = createTestRecords(parent.Id);

		Test.startTest();

		MAP_SObject index = MAP_SObject.of(records, new List<String> {FIELD_LOOKUP, FIELD_TEXT});

		Test.stopTest();

		Foobar__c spec1 = new Foobar__c();
		spec1.put(FIELD_LOOKUP, parent.Id);
		spec1.put(FIELD_TEXT, TEST_TEXT_VALUE);

		Foobar__c spec2 = new Foobar__c();
		spec2.put(FIELD_LOOKUP, parent.Id);
		spec2.put(FIELD_TEXT, 'Deer');

		Assert.areEqual(2, index.getAll(spec1).size(), MSG_INDEX_SIZE);
		Assert.areEqual(1, index.getAll(spec2).size(), MSG_INDEX_SIZE);
	}

	/**
	 * @description Tests fluent caseInsensitive() method.
	 */
	@IsTest
	private static void shouldMatchCaseInsensitivelyWithFluentMethod()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		Foobar__c record = TST_Factory.newFoobar();
		record.put(FIELD_LOOKUP, parent.Id);
		record.put(FIELD_TEXT, TEST_TEXT_VALUE);

		Test.startTest();

		MAP_SObject index = new MAP_SObject(FIELD_TEXT).caseInsensitive().putAll(new List<SObject> {record});

		Test.stopTest();

		Assert.areEqual(1, index.getAll(TEST_TEXT_VALUE.toLowerCase()).size(), MSG_INDEX_SIZE);
		Assert.areEqual(1, index.getAll(TEST_TEXT_VALUE.toUpperCase()).size(), MSG_INDEX_SIZE);
	}

	/**
	 * @description Tests case-insensitive index behavior with multi-field index.
	 */
	@IsTest
	private static void shouldMatchCaseInsensitivelyWithMultipleFields()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT}).caseInsensitive();

		Test.startTest();

		Foobar__c record = TST_Factory.newFoobar();
		record.put(FIELD_LOOKUP, parent.Id);
		record.put(FIELD_TEXT, TEST_TEXT_VALUE);
		sObjectIndex.put(record);

		Test.stopTest();

		Foobar__c spec = new Foobar__c();
		spec.put(FIELD_LOOKUP, parent.Id);
		spec.put(FIELD_TEXT, TEST_TEXT_VALUE.toLowerCase());

		Assert.areEqual(1, sObjectIndex.getAll(spec).size(), MSG_INDEX_SIZE);
		Assert.isTrue(!sObjectIndex.isEmpty(), MSG_INDEX_NOT_EMPTY);
	}

	/**
	 * @description Tests case-insensitive index behavior with map-based lookup.
	 */
	@IsTest
	private static void shouldMatchCaseInsensitivelyWithMapLookup()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT}).caseInsensitive();

		Test.startTest();

		Foobar__c record = TST_Factory.newFoobar();
		record.put(FIELD_LOOKUP, parent.Id);
		record.put(FIELD_TEXT, TEST_TEXT_VALUE);
		sObjectIndex.put(record);

		Test.stopTest();

		Assert.areEqual
				(
						1,
						sObjectIndex.getAll(new Map<String, String>
						{
								FIELD_LOOKUP => parent.Id,
								FIELD_TEXT => TEST_TEXT_VALUE.toLowerCase()
						}).size(),
						MSG_INDEX_SIZE
				);
		Assert.isTrue(!sObjectIndex.isEmpty(), MSG_INDEX_NOT_EMPTY);
	}

	/**
	 * @description Tests case-insensitive index behavior with reversed case.
	 */
	@IsTest
	private static void shouldMatchCaseInsensitivelyWithReversedCase()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = new MAP_SObject(FIELD_TEXT).caseInsensitive();

		Test.startTest();

		Foobar__c record = TST_Factory.newFoobar();
		record.put(FIELD_LOOKUP, parent.Id);
		record.put(FIELD_TEXT, TEST_TEXT_VALUE.toLowerCase());
		sObjectIndex.put(record);

		Test.stopTest();

		Assert.areEqual(1, sObjectIndex.getAll(TEST_TEXT_VALUE).size(), MSG_INDEX_SIZE);
		Assert.isTrue(!sObjectIndex.isEmpty(), MSG_INDEX_NOT_EMPTY);
	}

	/**
	 * @description Tests case-sensitive index behavior with map-based lookup.
	 */
	@IsTest
	private static void shouldNotMatchDifferentCaseWhenCaseSensitive()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT});

		Test.startTest();

		Foobar__c record = TST_Factory.newFoobar();
		record.put(FIELD_LOOKUP, parent.Id);
		record.put(FIELD_TEXT, TEST_TEXT_VALUE);
		sObjectIndex.put(record);

		Test.stopTest();

		Assert.areEqual
				(
						0,
						sObjectIndex.getAll(new Map<String, String>
						{
								FIELD_LOOKUP => parent.Id,
								FIELD_TEXT => TEST_TEXT_VALUE.toLowerCase()
						}).size(),
						MSG_INDEX_SIZE
				);
		Assert.areEqual
				(
						1,
						sObjectIndex.getAll(new Map<String, String>
						{
								FIELD_LOOKUP => parent.Id,
								FIELD_TEXT => TEST_TEXT_VALUE
						}).size(),
						MSG_INDEX_SIZE
				);
		Assert.isTrue(!sObjectIndex.isEmpty(), MSG_INDEX_NOT_EMPTY);
	}

	/**
	 * @description Tests that caseInsensitive does not corrupt Id keys by lowercasing the case-sensitive checksum.
	 */
	@IsTest
	private static void shouldPreserveIdKeysWhenCaseInsensitive()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT}).caseInsensitive();

		Foobar__c record = TST_Factory.newFoobar();
		record.put(FIELD_LOOKUP, parent.Id);
		record.put(FIELD_TEXT, TEST_TEXT_VALUE);
		sObjectIndex.put(record);

		Test.startTest();

		List<SObject> results = sObjectIndex.getAll(parent.Id);

		Test.stopTest();

		Assert.areEqual(1, results.size(), MSG_INDEX_SIZE);
		Assert.areEqual(parent.Id, results[0].get(FIELD_LOOKUP), MSG_ID_EQUALITY);
	}

	/**
	 * @description Tests that caseInsensitive() throws on non-empty index.
	 */
	@IsTest
	private static void shouldThrowWhenSettingCaseInsensitiveOnNonEmptyIndex()
	{
		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT}).put(new Foobar__c());

		Test.startTest();

		try
		{
			sObjectIndex.caseInsensitive();
			Assert.fail(MSG_EXCEPTION_EXPECTED);
		}
		catch(UTIL_Exceptions.IllegalStateException e)
		{
			Assert.areEqual(MAP_SObject.ERROR_CASE_INSENSITIVE, e.getMessage(), MSG_WRONG_EXCEPTION);
		}

		Test.stopTest();
	}

	/**
	 * @description Tests indexing with cross-object field references using Foobar__c parent-child via self-referential Lookup__c.
	 */
	@IsTest
	private static void shouldIndexByCrossObjectField()
	{
		Foobar__c parentRecord = TST_Factory.insertFoobar();
		String parentNameField = SEL_Foobar.FIELD_PARENT_NAME;
		String nameField = Foobar__c.Name.getDescribe().name;

		Foobar__c childRecord = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Lookup__c, parentRecord.Id)
				.build();

		childRecord = (Foobar__c)new SEL_Foobar().findById(childRecord.Id);

		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {parentNameField, nameField});
		sObjectIndex.put(childRecord);

		Map<String, Object> spec = new Map<String, Object>
		{
				parentNameField => parentRecord.Name,
				nameField => childRecord.Name
		};

		Assert.areEqual(1, sObjectIndex.getAll(spec).size(), MSG_INDEX_SIZE);
		Assert.isTrue(!sObjectIndex.isEmpty(), MSG_INDEX_NOT_EMPTY);

		List<Foobar__c> indexedRecords = sObjectIndex.values();
		Assert.areEqual(1, indexedRecords.size(), MSG_INDEX_SIZE);
		Assert.areEqual(childRecord, indexedRecords[0], MSG_RECORD_EQUALITY);
	}

	/**
	 * @description Tests an empty index.
	 */
	@IsTest
	private static void shouldReturnNullForEmptyIndex()
	{
		Test.startTest();

		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT});

		Test.stopTest();

		Assert.isNull(sObjectIndex.get(new Foobar__c()), MSG_NULL_RESULT);
		Assert.isTrue(sObjectIndex.isEmpty(), 'Index should be empty');
	}

	/**
	 * @description Tests exact hit with map-based lookup.
	 */
	@IsTest
	private static void shouldFindExactMatchWithMapLookup()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT});

		Foobar__c record = TST_Factory.newFoobar();
		record.put(FIELD_LOOKUP, parent.Id);
		record.put(FIELD_TEXT, TEST_TEXT_VALUE);
		sObjectIndex.put(record);

		Assert.areEqual
				(
						1,
						sObjectIndex.getAll(new Map<String, Object> {FIELD_LOOKUP => parent.Id, FIELD_TEXT => TEST_TEXT_VALUE}).size(),
						MSG_INDEX_SIZE
				);
		Assert.isTrue(!sObjectIndex.isEmpty(), MSG_INDEX_NOT_EMPTY);
	}

	/**
	 * @description Tests near hit scenarios in the index.
	 */
	@IsTest
	private static void shouldDistinguishNearHits()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT});

		Test.startTest();

		List<Foobar__c> records = TST_Factory.newFoobars(2);
		records[0].put(FIELD_LOOKUP, parent.Id);
		records[0].put(FIELD_NAME, 'John');
		records[0].put(FIELD_TEXT, TEST_TEXT_VALUE);
		records[1].put(FIELD_LOOKUP, parent.Id);
		records[1].put(FIELD_NAME, 'Jane');
		records[1].put(FIELD_TEXT, TEST_TEXT_VALUE + '2');

		sObjectIndex.put(records[0]);
		sObjectIndex.put(records[1]);

		Test.stopTest();

		Foobar__c spec = new Foobar__c();
		spec.put(FIELD_LOOKUP, parent.Id);
		spec.put(FIELD_TEXT, TEST_TEXT_VALUE);

		Assert.areEqual(1, sObjectIndex.getAll(spec).size(), MSG_INDEX_SIZE);
	}

	/**
	 * @description Tests handling of null values in index fields.
	 */
	@IsTest
	private static void shouldHandleNullValueOnIndexField()
	{
		Foobar__c record = TST_Factory.newFoobar();
		record.put(FIELD_LOOKUP, null);

		MAP_SObject sObjectIndex = new MAP_SObject(FIELD_LOOKUP).put(record);

		Test.startTest();

		Foobar__c retrieved = (Foobar__c)sObjectIndex.get((Id)null);

		Test.stopTest();

		Assert.areEqual(record.get(FIELD_NAME), retrieved.get(FIELD_NAME), 'Name fields should match');
	}

	/**
	 * @description Tests a simple index with multiple records.
	 */
	@IsTest
	private static void shouldIndexMultipleRecordsBySingleField()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		List<Foobar__c> records = TST_Factory.newFoobars(2);
		records[0].put(FIELD_LOOKUP, parent.Id);
		records[0].put(FIELD_NAME, 'John');
		records[0].put(FIELD_TEXT, TEST_TEXT_VALUE);
		records[1].put(FIELD_LOOKUP, parent.Id);
		records[1].put(FIELD_NAME, 'Jane');
		records[1].put(FIELD_TEXT, TEST_TEXT_VALUE + '2');

		MAP_SObject sObjectIndex = new MAP_SObject(FIELD_LOOKUP).putAll(records);

		Assert.areEqual(2, sObjectIndex.getAll(parent.Id).size(), MSG_INDEX_SIZE);

		Set<String> lookupKeySet = sObjectIndex.keySet();
		Assert.areEqual(1, lookupKeySet.size(), MSG_INDEX_SIZE);
		Assert.isTrue(lookupKeySet.contains(parent.Id), MSG_CONTAINS_KEY);

		sObjectIndex.get(parent.Id);
		Assert.isNull(sObjectIndex.get('null'), MSG_NULL_RESULT);
		Assert.isTrue(sObjectIndex.getAll('null').isEmpty(), 'Result should be empty');
	}

	/**
	 * @description Tests single hit scenarios in the index.
	 */
	@IsTest
	private static void shouldFindSingleHit()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT});

		Foobar__c record = TST_Factory.newFoobar();
		record.put(FIELD_LOOKUP, parent.Id);
		record.put(FIELD_TEXT, TEST_TEXT_VALUE);
		sObjectIndex.put(record);

		Foobar__c spec = new Foobar__c();
		spec.put(FIELD_LOOKUP, parent.Id);
		spec.put(FIELD_TEXT, TEST_TEXT_VALUE);

		Assert.areEqual(1, sObjectIndex.getAll(spec).size(), MSG_INDEX_SIZE);
		Assert.isTrue(!sObjectIndex.isEmpty(), MSG_INDEX_NOT_EMPTY);

		Set<String> lookupKeySet = sObjectIndex.keySet(FIELD_LOOKUP);
		Assert.areEqual(1, lookupKeySet.size(), MSG_INDEX_SIZE);
		Assert.isTrue(lookupKeySet.contains(parent.Id), MSG_CONTAINS_KEY);

		Set<String> textKeySet = sObjectIndex.keySet(FIELD_TEXT);
		Assert.areEqual(1, textKeySet.size(), MSG_INDEX_SIZE);
		Assert.isTrue(textKeySet.contains(TEST_TEXT_VALUE), MSG_CONTAINS_KEY);

		List<Foobar__c> indexedRecords = sObjectIndex.values();
		Assert.areEqual(1, indexedRecords.size(), MSG_INDEX_SIZE);
		Assert.areEqual(record, indexedRecords[0], MSG_RECORD_EQUALITY);
	}

	/**
	 * @description Tests scenarios with two hits in the index.
	 */
	@IsTest
	private static void shouldFindMultipleHits()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = getTwoHitsIndex(parent.Id);

		Foobar__c spec = new Foobar__c();
		spec.put(FIELD_LOOKUP, parent.Id);
		spec.put(FIELD_TEXT, TEST_TEXT_VALUE);

		Assert.areEqual(2, sObjectIndex.getAll(spec).size(), MSG_INDEX_SIZE);
		Assert.isTrue(!sObjectIndex.isEmpty(), MSG_INDEX_NOT_EMPTY);

		Set<String> lookupKeySet = sObjectIndex.keySet(FIELD_LOOKUP);
		Assert.areEqual(1, lookupKeySet.size(), MSG_INDEX_SIZE);
		Assert.isTrue(lookupKeySet.contains(parent.Id), MSG_CONTAINS_KEY);

		Set<String> textKeySet = sObjectIndex.keySet(FIELD_TEXT);
		Assert.areEqual(2, textKeySet.size(), MSG_INDEX_SIZE);
		Assert.isTrue(textKeySet.contains(TEST_TEXT_VALUE), MSG_CONTAINS_KEY);
		Assert.isTrue(textKeySet.contains('Deer'), MSG_CONTAINS_KEY);
	}

	/**
	 * @description Tests map-based lookup with two hits.
	 */
	@IsTest
	private static void shouldFindMultipleHitsWithMapLookup()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = createAndPopulateIndex(parent.Id);

		List<Foobar__c> retrieved = sObjectIndex.getAll(new Map<String, Object> {FIELD_TEXT => TEST_TEXT_VALUE});

		Assert.areEqual(2, retrieved.size(), MSG_INDEX_SIZE);
		Assert.isNull(retrieved[0].get(FIELD_LOOKUP), 'Lookup should be null');
		Assert.areEqual(retrieved[1].get(FIELD_LOOKUP), parent.Id, MSG_ID_EQUALITY);
		Assert.areEqual(retrieved[0].get(FIELD_NAME), 'John', 'Name should be John');
		Assert.areEqual(retrieved[1].get(FIELD_NAME), 'Jane', 'Name should be Jane');
		Assert.areEqual(TEST_TEXT_VALUE, retrieved[0].get(FIELD_TEXT), 'Text should be Doe');
		Assert.areEqual(TEST_TEXT_VALUE, retrieved[1].get(FIELD_TEXT), 'Text should be Doe');
	}

	/**
	 * @description Tests sub-index functionality with two hits.
	 */
	@IsTest
	private static void shouldGetSubIndex()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = createAndPopulateIndex(parent.Id);

		MAP_SObject subIndex = sObjectIndex.getSubIndex(parent.Id);
		List<Foobar__c> retrieved = subIndex.getAll(new Map<String, Object> {FIELD_TEXT => TEST_TEXT_VALUE});
		Assert.areEqual(1, retrieved.size(), MSG_INDEX_SIZE);
		Assert.areEqual(retrieved[0].get(FIELD_LOOKUP), parent.Id, MSG_ID_EQUALITY);
		Assert.areEqual(retrieved[0].get(FIELD_NAME), 'Jane', 'Name should be Jane');
		Assert.areEqual(TEST_TEXT_VALUE, retrieved[0].get(FIELD_TEXT), 'Text should be Doe');
	}

	/**
	 * @description Tests that getSubIndex returns null for non-existent key.
	 */
	@IsTest
	private static void shouldReturnNullSubIndexForNonExistentKey()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		Foobar__c record = TST_Factory.newFoobar();
		record.put(FIELD_LOOKUP, parent.Id);

		MAP_SObject sObjectIndex = new MAP_SObject(FIELD_LOOKUP).put(record);

		Test.startTest();

		MAP_SObject subIndex = sObjectIndex.getSubIndex('nonexistent');

		Test.stopTest();

		Assert.isNull(subIndex, 'SubIndex should be null for non-existent key');
	}

	/**
	 * @description Tests removing records from the index.
	 */
	@IsTest
	private static void shouldRemoveRecordsWithSpecification()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = getTwoHitsIndex(parent.Id);

		Foobar__c removeSpec = new Foobar__c();
		removeSpec.put(FIELD_LOOKUP, parent.Id);
		removeSpec.put(FIELD_NAME, 'John');
		removeSpec.put(FIELD_TEXT, TEST_TEXT_VALUE);

		sObjectIndex.remove(removeSpec);

		Foobar__c querySpec = new Foobar__c();
		querySpec.put(FIELD_LOOKUP, parent.Id);
		querySpec.put(FIELD_TEXT, TEST_TEXT_VALUE);

		Assert.areEqual(0, sObjectIndex.getAll(querySpec).size(), MSG_INDEX_SIZE);

		Set<String> textKeySet = sObjectIndex.keySet(FIELD_TEXT);
		Assert.areEqual(1, textKeySet.size(), 'Empty keys should be removed to prevent memory leaks');
		Assert.isTrue(textKeySet.contains('Deer'), MSG_CONTAINS_KEY);

		Assert.isTrue(sObjectIndex.remove(new Foobar__c()).isEmpty(), 'Remove should return empty list for unmatched record');
	}

	/**
	 * @description Tests removing records using a map-based lookup.
	 */
	@IsTest
	private static void shouldRemoveRecordsWithMapLookup()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT, FIELD_NAME});
		addTestRecords(sObjectIndex, parent.Id);
		sObjectIndex.remove(new Map<String, Object> {FIELD_NAME => 'John'});
		Assert.areEqual
				(
						1,
						sObjectIndex.getAll(new Map<String, Object> {FIELD_LOOKUP => parent.Id, FIELD_TEXT => TEST_TEXT_VALUE}).size(),
						MSG_INDEX_SIZE
				);
		Set<String> textKeySet = sObjectIndex.keySet(FIELD_TEXT);
		Assert.areEqual(2, textKeySet.size(), 'Both keys should remain because Jane still exists under Doe');
		Assert.isTrue(textKeySet.contains(TEST_TEXT_VALUE), MSG_CONTAINS_KEY);
		Assert.isTrue(textKeySet.contains('Deer'), MSG_CONTAINS_KEY);
	}

	/**
	 * @description Tests getAll(Object key) on a multi-level index to traverse to child MAP_SObject.
	 */
	@IsTest
	private static void shouldGetAllByKeyOnMultiLevelIndex()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT});
		addTestRecords(sObjectIndex, parent.Id);

		Test.startTest();

		List<SObject> results = sObjectIndex.getAll(parent.Id);

		Test.stopTest();

		Assert.areEqual(3, results.size(), MSG_INDEX_SIZE);
	}

	/**
	 * @description Tests remove(Map) on a multi-level index with matching intermediate field.
	 */
	@IsTest
	private static void shouldRemoveWithMapOnMultiLevelIndex()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT});
		addTestRecords(sObjectIndex, parent.Id);

		Test.startTest();

		List<SObject> removed = sObjectIndex.remove(new Map<String, Object> {FIELD_LOOKUP => parent.Id, FIELD_TEXT => TEST_TEXT_VALUE});

		Test.stopTest();

		Assert.areEqual(2, removed.size(), 'Should remove 2 Doe records');
		Assert.areEqual(1, sObjectIndex.values().size(), 'Should have 1 Deer record remaining');
	}

	/**
	 * @description Tests getAll(Map) on a 3-level index searching by non-first field.
	 */
	@IsTest
	private static void shouldGetAllWithMapOnThreeLevelIndexByMiddleField()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT, FIELD_NAME});
		addTestRecords(sObjectIndex, parent.Id);

		Test.startTest();

		List<SObject> results = sObjectIndex.getAll(new Map<String, Object> {FIELD_NAME => 'John'});

		Test.stopTest();

		Assert.areEqual(1, results.size(), MSG_INDEX_SIZE);
	}

	/**
	 * @description Tests that removing all records from a child index removes the empty child key.
	 */
	@IsTest
	private static void shouldRemoveEmptyChildIndexKeyAfterRemoval()
	{
		Foobar__c parent1 = TST_Factory.newFoobarWithMockId();
		Foobar__c parent2 = TST_Factory.newFoobarWithMockId();

		List<Foobar__c> records = TST_Factory.newFoobars(2);
		records[0].put(FIELD_LOOKUP, parent1.Id);
		records[0].put(FIELD_TEXT, 'Alpha');
		records[1].put(FIELD_LOOKUP, parent2.Id);
		records[1].put(FIELD_TEXT, 'Beta');

		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT});
		sObjectIndex.putAll(records);

		Foobar__c removeSpecification = new Foobar__c();
		removeSpecification.put(FIELD_LOOKUP, parent1.Id);
		removeSpecification.put(FIELD_TEXT, 'Alpha');

		Test.startTest();

		List<SObject> removed = sObjectIndex.remove(removeSpecification);

		Test.stopTest();

		Assert.areEqual(1, removed.size(), 'Should remove 1 record');
		Assert.areEqual(1, sObjectIndex.keySet().size(), 'Parent1 key should be removed when empty');
		Assert.isTrue(sObjectIndex.keySet().contains(String.valueOf(parent2.Id)), 'Parent2 key should remain');
	}

	/**
	 * @description Tests containsKey returns true for existing keys and false for non-existent keys.
	 */
	@IsTest
	private static void shouldReturnTrueForExistingKey()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		List<Foobar__c> records = createTwoTestRecords(parent.Id);
		MAP_SObject sObjectIndex = MAP_SObject.of(records, FIELD_LOOKUP);

		Test.startTest();

		Boolean containsExisting = sObjectIndex.containsKey(parent.Id);
		Boolean containsNonExistent = sObjectIndex.containsKey('nonexistent');

		Test.stopTest();

		Assert.isTrue(containsExisting, 'Should contain existing key');
		Assert.isFalse(containsNonExistent, 'Should not contain non-existent key');
	}

	/**
	 * @description Tests containsKey with null key.
	 */
	@IsTest
	private static void shouldHandleNullKeyInContainsKey()
	{
		Foobar__c record = TST_Factory.newFoobar();
		record.put(FIELD_LOOKUP, null);
		MAP_SObject sObjectIndex = new MAP_SObject(FIELD_LOOKUP).put(record);

		Test.startTest();

		Boolean containsNull = sObjectIndex.containsKey(null);

		Test.stopTest();

		Assert.isTrue(containsNull, 'Should contain null key');
	}

	/**
	 * @description Tests size returns correct count for single-level index.
	 */
	@IsTest
	private static void shouldReturnCorrectSizeForSingleLevelIndex()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		List<Foobar__c> records = createTestRecords(parent.Id);
		MAP_SObject sObjectIndex = MAP_SObject.of(records, FIELD_LOOKUP);

		Test.startTest();

		Integer size = sObjectIndex.size();

		Test.stopTest();

		Assert.areEqual(3, size, 'Size should be 3');
	}

	/**
	 * @description Tests size returns correct count for multi-level index.
	 */
	@IsTest
	private static void shouldReturnCorrectSizeForMultiLevelIndex()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		MAP_SObject sObjectIndex = new MAP_SObject(new List<String> {FIELD_LOOKUP, FIELD_TEXT});
		addTestRecords(sObjectIndex, parent.Id);

		Test.startTest();

		Integer size = sObjectIndex.size();

		Test.stopTest();

		Assert.areEqual(3, size, 'Size should be 3');
	}

	/**
	 * @description Tests size returns zero for empty index.
	 */
	@IsTest
	private static void shouldReturnZeroSizeForEmptyIndex()
	{
		MAP_SObject sObjectIndex = new MAP_SObject(FIELD_TEXT);

		Test.startTest();

		Integer size = sObjectIndex.size();

		Test.stopTest();

		Assert.areEqual(0, size, 'Size should be 0 for empty index');
	}

	/**
	 * @description Tests clear removes all records from the index.
	 */
	@IsTest
	private static void shouldClearAllRecordsFromIndex()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		List<Foobar__c> records = createTestRecords(parent.Id);
		MAP_SObject sObjectIndex = MAP_SObject.of(records, FIELD_LOOKUP);

		Assert.isFalse(sObjectIndex.isEmpty(), 'Index should not be empty before clear');

		Test.startTest();

		sObjectIndex.clear();

		Test.stopTest();

		Assert.isTrue(sObjectIndex.isEmpty(), 'Index should be empty after clear');
		Assert.areEqual(0, sObjectIndex.size(), 'Size should be 0 after clear');
	}

	/**
	 * @description Tests toString returns a meaningful debug string.
	 */
	@IsTest
	private static void shouldReturnMeaningfulToString()
	{
		Foobar__c parent = TST_Factory.newFoobarWithMockId();
		List<Foobar__c> records = createTwoTestRecords(parent.Id);
		MAP_SObject sObjectIndex = MAP_SObject.of(records, FIELD_LOOKUP);

		Test.startTest();

		String result = sObjectIndex.toString();

		Test.stopTest();

		Assert.isTrue(result.contains('MAP_SObject'), 'Should contain class name');
		Assert.isTrue(result.contains('field=' + FIELD_LOOKUP), 'Should contain field name');
		Assert.isTrue(result.contains('depth=0'), 'Should contain depth');
		Assert.isTrue(result.contains(String.valueOf(parent.Id)), 'Should contain key');
	}
}