// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the methods in [UTIL_SObject] for SObject filtering, field extraction,
 * list-to-map conversion, field-change detection, and utility operations.
 *
 * @see UTIL_SObject
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_SObject_TEST
{
	/**
	 * @description Test value for the Name field.
	 */
	private static final String TEST_NAME_ALPHA = 'Alpha';

	/**
	 * @description Test value for the Name field.
	 */
	private static final String TEST_NAME_BRAVO = 'Bravo';

	/**
	 * @description Test value for the Text field.
	 */
	private static final String TEST_TEXT_VALUE = 'SomeText';

	/**
	 * @description Test value for the Email field.
	 */
	private static final String TEST_EMAIL_VALUE = 'test@example.com';

	/**
	 * @description Tests that matches returns true when all filter fields match.
	 *
	 * @see UTIL_SObject.matches
	 */
	@IsTest
	private static void matchesReturnsTrueWhenAllFieldsMatch()
	{
		Foobar__c record = buildRecord(new Map<SObjectField, Object>
		{
				Foobar__c.Name => TEST_NAME_ALPHA,
				Foobar__c.Text__c => TEST_TEXT_VALUE
		});

		Map<String, Object> filterMap = new Map<String, Object>
		{
				Foobar__c.Name.getDescribe().name => TEST_NAME_ALPHA,
				Foobar__c.Text__c.getDescribe().name => TEST_TEXT_VALUE
		};

		Assert.isTrue(UTIL_SObject.matches(record, filterMap), 'Should match when all fields match');
	}

	/**
	 * @description Tests that matches treats a null checkbox field as equivalent to false.
	 *
	 * @see UTIL_SObject.matches
	 */
	@IsTest
	private static void matchesReturnsTrueWhenBooleanFalseAndFieldNull()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
				.withOverride(Foobar__c.Checkbox__c, null)
				.withoutInsertion()
				.build();

		Map<String, Object> filterMap = new Map<String, Object>
		{
				Foobar__c.Checkbox__c.getDescribe().name => false
		};

		Assert.isTrue(UTIL_SObject.matches(record, filterMap), 'Should match when Boolean false and field is null');
	}

	/**
	 * @description Tests that matches returns false when a field does not match.
	 *
	 * @see UTIL_SObject.matches
	 */
	@IsTest
	private static void matchesReturnsFalseWhenFieldDiffers()
	{
		Foobar__c record = TST_Factory.newFoobarWithName(TEST_NAME_ALPHA);

		Map<String, Object> filterMap = new Map<String, Object>
		{
				Foobar__c.Name.getDescribe().name => TEST_NAME_BRAVO
		};

		Assert.isFalse(UTIL_SObject.matches(record, filterMap), 'Should not match when field differs');
	}

	/**
	 * @description Tests that findWhere returns matching records by single field and value.
	 *
	 * @see UTIL_SObject.findWhere
	 */
	@IsTest
	private static void findWhereFiltersBySingleField()
	{
		List<Foobar__c> records = buildTestRecordPair();

		List<SObject> result = UTIL_SObject.findWhere(records, Foobar__c.Name.getDescribe().name, TEST_NAME_ALPHA);

		Assert.areEqual(1, result.size(), 'Should return one matching record');
		Assert.areEqual(TEST_NAME_ALPHA, ((Foobar__c)result[0]).Name, 'Should return the matching record');
	}

	/**
	 * @description Tests that findWhere returns matching records by filter map.
	 *
	 * @see UTIL_SObject.findWhere
	 */
	@IsTest
	private static void findWhereFiltersByFilterMap()
	{
		List<Foobar__c> records = buildTestRecordPair();

		Map<String, Object> filterMap = new Map<String, Object>
		{
				Foobar__c.Name.getDescribe().name => TEST_NAME_ALPHA
		};

		List<SObject> result = UTIL_SObject.findWhere(records, filterMap);

		Assert.areEqual(1, result.size(), 'Should return one matching record');
	}

	/**
	 * @description Tests that findWhereIn returns records matching any value in the list.
	 *
	 * @see UTIL_SObject.findWhereIn
	 */
	@IsTest
	private static void findWhereInFiltersToMatchingValues()
	{
		List<Foobar__c> records = buildTestRecordPair();

		List<SObject> result = UTIL_SObject.findWhereIn(
				records,
				Foobar__c.Name.getDescribe().name,
				new List<Object> {TEST_NAME_ALPHA, 'NonExistent'}
		);

		Assert.areEqual(1, result.size(), 'Should return one matching record');
	}

	/**
	 * @description Tests that omitWhere excludes matching records by single field.
	 *
	 * @see UTIL_SObject.omitWhere
	 */
	@IsTest
	private static void omitWhereExcludesBySingleField()
	{
		List<Foobar__c> records = buildTestRecordPair();

		List<SObject> result = UTIL_SObject.omitWhere(records, Foobar__c.Name.getDescribe().name, TEST_NAME_ALPHA);

		Assert.areEqual(1, result.size(), 'Should return one remaining record');
		Assert.areEqual(TEST_NAME_BRAVO, ((Foobar__c)result[0]).Name, 'Should return the non-matching record');
	}

	/**
	 * @description Tests that omitWhere excludes matching records by filter map.
	 *
	 * @see UTIL_SObject.omitWhere
	 */
	@IsTest
	private static void omitWhereExcludesByFilterMap()
	{
		List<Foobar__c> records = buildTestRecordPair();

		Map<String, Object> filterMap = new Map<String, Object>
		{
				Foobar__c.Name.getDescribe().name => TEST_NAME_ALPHA
		};

		List<SObject> result = UTIL_SObject.omitWhere(records, filterMap);

		Assert.areEqual(1, result.size(), 'Should return one remaining record');
	}

	/**
	 * @description Tests that extractIds returns Ids from the default Id field.
	 *
	 * @see UTIL_SObject.extractIds
	 */
	@IsTest
	private static void extractIdsReturnsRecordIds()
	{
		List<Foobar__c> records = new List<Foobar__c>
		{
				TST_Factory.newFoobarWithMockId(),
				TST_Factory.newFoobarWithMockId()
		};

		Set<Id> result = UTIL_SObject.extractIds(records);

		Assert.areEqual(2, result.size(), 'Should return two Ids');
	}

	/**
	 * @description Tests that extractIds with ignoreNulls excludes null Ids.
	 *
	 * @see UTIL_SObject.extractIds
	 */
	@IsTest
	private static void extractIdsIgnoresNulls()
	{
		List<SObject> records = new List<SObject> {TST_Factory.newFoobar()};

		Set<Id> result = UTIL_SObject.extractIds(records, true);

		Assert.isTrue(result.isEmpty(), 'Should return empty set when Ids are null and ignoreNulls is true');
	}

	/**
	 * @description Tests that extractIds returns Ids from a named field.
	 *
	 * @see UTIL_SObject.extractIds
	 */
	@IsTest
	private static void extractIdsFromNamedField()
	{
		Foobar__c record = TST_Factory.newFoobarWithMockId();

		Set<Id> result = UTIL_SObject.extractIds(new List<SObject> {record}, 'Id');

		Assert.areEqual(1, result.size(), 'Should return one Id');
	}

	/**
	 * @description Tests that extractIds returns Ids from a typed field token.
	 *
	 * @see UTIL_SObject.extractIds
	 */
	@IsTest
	private static void extractIdsFromFieldToken()
	{
		Foobar__c record = TST_Factory.newFoobarWithMockId();

		Set<Id> result = UTIL_SObject.extractIds(new List<SObject> {record}, Foobar__c.Id);

		Assert.areEqual(1, result.size(), 'Should return one Id');
	}

	/**
	 * @description Tests that extractIds with typed field token and ignoreNulls works correctly.
	 *
	 * @see UTIL_SObject.extractIds
	 */
	@IsTest
	private static void extractIdsFromFieldTokenIgnoresNulls()
	{
		List<SObject> records = new List<SObject> {TST_Factory.newFoobar()};

		Set<Id> result = UTIL_SObject.extractIds(records, Foobar__c.Lookup__c, true);

		Assert.isTrue(result.isEmpty(), 'Should return empty set when field is null and ignoreNulls is true');
	}

	/**
	 * @description Tests that extractValues returns field values as a list of strings.
	 *
	 * @see UTIL_SObject.extractValues
	 */
	@IsTest
	private static void extractValuesReturnsFieldValues()
	{
		List<Foobar__c> records = buildTestRecordPair();

		List<String> result = UTIL_SObject.extractValues(records, Foobar__c.Name.getDescribe().name);

		Assert.areEqual(2, result.size(), 'Should return two values');
		Assert.isTrue(result.contains(TEST_NAME_ALPHA), 'Should contain Alpha');
	}

	/**
	 * @description Tests that extractValues with typed field token returns field values.
	 *
	 * @see UTIL_SObject.extractValues
	 */
	@IsTest
	private static void extractValuesFromFieldToken()
	{
		List<Foobar__c> records = buildTestRecordPair();

		List<String> result = UTIL_SObject.extractValues(records, Foobar__c.Name);

		Assert.areEqual(2, result.size(), 'Should return two values');
	}

	/**
	 * @description Tests that extractValues with ignoreBlankValues excludes blanks.
	 *
	 * @see UTIL_SObject.extractValues
	 */
	@IsTest
	private static void extractValuesIgnoresBlanks()
	{
		List<SObject> records = buildRecordsWithPartialText();

		List<String> result = UTIL_SObject.extractValues(records, Foobar__c.Text__c.getDescribe().name, true);

		Assert.areEqual(1, result.size(), 'Should return one non-blank value');
	}

	/**
	 * @description Tests that extractValues with typed field token and ignoreBlankValues works.
	 *
	 * @see UTIL_SObject.extractValues
	 */
	@IsTest
	private static void extractValuesFromFieldTokenIgnoresBlanks()
	{
		List<SObject> records = buildRecordsWithPartialText();

		List<String> result = UTIL_SObject.extractValues(records, Foobar__c.Text__c, true);

		Assert.areEqual(1, result.size(), 'Should return one non-blank value');
	}

	/**
	 * @description Tests that extractUniqueValues returns unique field values.
	 *
	 * @see UTIL_SObject.extractUniqueValues
	 */
	@IsTest
	private static void extractUniqueValuesReturnsUniqueValues()
	{
		List<SObject> records = new List<SObject>
		{
				TST_Factory.newFoobarWithName(TEST_NAME_ALPHA),
				TST_Factory.newFoobarWithName(TEST_NAME_ALPHA),
				TST_Factory.newFoobarWithName(TEST_NAME_BRAVO)
		};

		Set<String> result = UTIL_SObject.extractUniqueValues(records, Foobar__c.Name.getDescribe().name);

		Assert.areEqual(2, result.size(), 'Should return two unique values');
	}

	/**
	 * @description Tests that extractUniqueValues with typed field token returns unique values.
	 *
	 * @see UTIL_SObject.extractUniqueValues
	 */
	@IsTest
	private static void extractUniqueValuesFromFieldToken()
	{
		List<Foobar__c> records = buildTestRecordPair();

		Set<String> result = UTIL_SObject.extractUniqueValues(records, Foobar__c.Name);

		Assert.areEqual(2, result.size(), 'Should return two unique values');
	}

	/**
	 * @description Tests that extractUniqueValues with ignoreBlankValues excludes blanks.
	 *
	 * @see UTIL_SObject.extractUniqueValues
	 */
	@IsTest
	private static void extractUniqueValuesIgnoresBlanks()
	{
		List<SObject> records = buildRecordsWithPartialText();

		Set<String> result = UTIL_SObject.extractUniqueValues(records, Foobar__c.Text__c.getDescribe().name, true);

		Assert.areEqual(1, result.size(), 'Should return one non-blank value');
	}

	/**
	 * @description Tests that extractUniqueValues with typed field token and ignoreBlankValues works.
	 *
	 * @see UTIL_SObject.extractUniqueValues
	 */
	@IsTest
	private static void extractUniqueValuesFromFieldTokenIgnoresBlanks()
	{
		List<SObject> records = buildRecordsWithPartialText();

		Set<String> result = UTIL_SObject.extractUniqueValues(records, Foobar__c.Text__c, true);

		Assert.areEqual(1, result.size(), 'Should return one non-blank value');
	}

	/**
	 * @description Tests that groupByKey groups records by Id field.
	 *
	 * @see UTIL_SObject.groupByKey
	 */
	@IsTest
	private static void groupByKeyGroupsById()
	{
		Foobar__c record = TST_Factory.newFoobarWithMockId();

		Map<Id, List<SObject>> result = UTIL_SObject.groupByKey(new List<SObject> {record}, 'Id');

		Assert.areEqual(1, result.size(), 'Should have one group');
		Assert.areEqual(1, result.values()[0].size(), 'Should have one record in group');
	}

	/**
	 * @description Tests that groupByKey with typed field token groups records.
	 *
	 * @see UTIL_SObject.groupByKey
	 */
	@IsTest
	private static void groupByKeyFromFieldToken()
	{
		Foobar__c record = TST_Factory.newFoobarWithMockId();

		Map<Id, List<SObject>> result = UTIL_SObject.groupByKey(new List<SObject> {record}, Foobar__c.Id);

		Assert.areEqual(1, result.size(), 'Should have one group');
	}

	/**
	 * @description Tests that indexById creates a one-to-one Id map.
	 *
	 * @see UTIL_SObject.indexById
	 */
	@IsTest
	private static void indexByIdCreatesIdMap()
	{
		Foobar__c record = TST_Factory.newFoobarWithMockId();

		Map<Id, SObject> result = UTIL_SObject.indexById(new List<SObject> {record}, 'Id');

		Assert.areEqual(1, result.size(), 'Should have one entry');
	}

	/**
	 * @description Tests that indexById with typed field token creates a one-to-one Id map.
	 *
	 * @see UTIL_SObject.indexById
	 */
	@IsTest
	private static void indexByIdFromFieldToken()
	{
		Foobar__c record = TST_Factory.newFoobarWithMockId();

		Map<Id, SObject> result = UTIL_SObject.indexById(new List<SObject> {record}, Foobar__c.Id);

		Assert.areEqual(1, result.size(), 'Should have one entry');
	}

	/**
	 * @description Tests that groupByStringKey groups records by a String field.
	 *
	 * @see UTIL_SObject.groupByStringKey
	 */
	@IsTest
	private static void groupByStringKeyGroupsByStringField()
	{
		List<Foobar__c> records = buildTestRecordPair();

		Map<String, List<SObject>> result = UTIL_SObject.groupByStringKey(records, Foobar__c.Name.getDescribe().name);

		Assert.areEqual(2, result.size(), 'Should have two groups');
	}

	/**
	 * @description Tests that groupByStringKey with typed field token groups records.
	 *
	 * @see UTIL_SObject.groupByStringKey
	 */
	@IsTest
	private static void groupByStringKeyFromFieldToken()
	{
		List<Foobar__c> records = buildTestRecordPair();

		Map<String, List<SObject>> result = UTIL_SObject.groupByStringKey(records, Foobar__c.Name);

		Assert.areEqual(2, result.size(), 'Should have two groups');
	}

	/**
	 * @description Tests that indexByStringKey creates a one-to-one String map.
	 *
	 * @see UTIL_SObject.indexByStringKey
	 */
	@IsTest
	private static void indexByStringKeyCreatesStringMap()
	{
		List<Foobar__c> records = buildTestRecordPair();

		Map<String, SObject> result = UTIL_SObject.indexByStringKey(records, Foobar__c.Name.getDescribe().name);

		Assert.areEqual(2, result.size(), 'Should have two entries');
	}

	/**
	 * @description Tests that indexByStringKey with typed field token works.
	 *
	 * @see UTIL_SObject.indexByStringKey
	 */
	@IsTest
	private static void indexByStringKeyFromFieldToken()
	{
		List<Foobar__c> records = buildTestRecordPair();

		Map<String, SObject> result = UTIL_SObject.indexByStringKey(records, Foobar__c.Name);

		Assert.areEqual(2, result.size(), 'Should have two entries');
	}

	/**
	 * @description Tests that getFieldValue retrieves a simple field value.
	 *
	 * @see UTIL_SObject.getFieldValue
	 */
	@IsTest
	private static void getFieldValueReturnsSimpleFieldValue()
	{
		Foobar__c record = TST_Factory.newFoobarWithName(TEST_NAME_ALPHA);

		Object result = UTIL_SObject.getFieldValue(record, Foobar__c.Name.getDescribe().name);

		Assert.areEqual(TEST_NAME_ALPHA, result, 'Should return the field value');
	}

	/**
	 * @description Tests that getFieldValue returns null for a null SObject.
	 *
	 * @see UTIL_SObject.getFieldValue
	 */
	@IsTest
	private static void getFieldValueReturnsNullForNullObject()
	{
		Object result = UTIL_SObject.getFieldValue(null, 'Name');

		Assert.isNull(result, 'Should return null for null SObject');
	}

	/**
	 * @description Tests that getFieldValue traverses a dot-notation path to a related record.
	 *
	 * @see UTIL_SObject.getFieldValue
	 */
	@IsTest
	private static void getFieldValueTraversesDotNotationPath()
	{
		Foobar__c record = buildRecordWithParent();

		Object result = UTIL_SObject.getFieldValue(record, Foobar__c.Lookup__c.getDescribe().getRelationshipName() + '.Name');

		Assert.areEqual(TEST_NAME_BRAVO, result, 'Should return the parent Name via dot-notation');
	}

	/**
	 * @description Tests that validateId returns a valid Id for a valid string.
	 *
	 * @see UTIL_SObject.validateId
	 */
	@IsTest
	@SuppressWarnings('PMD.AvoidHardcodingId')
	private static void validateIdReturnsIdForValidString()
	{
		Id result = UTIL_SObject.validateId('001000000000001AAA');

		Assert.isNotNull(result, 'Should return a valid Id');
	}

	/**
	 * @description Tests that validateId returns null for an invalid string.
	 *
	 * @see UTIL_SObject.validateId
	 */
	@IsTest
	private static void validateIdReturnsNullForInvalidString()
	{
		Id result = UTIL_SObject.validateId('not-an-id');

		Assert.isNull(result, 'Should return null for invalid Id');
	}

	/**
	 * @description Tests that hasFieldChanged returns true when the field value differs.
	 *
	 * @see UTIL_SObject.hasFieldChanged
	 */
	@IsTest
	private static void hasFieldChangedReturnsTrueWhenDifferent()
	{
		Foobar__c oldRecord = TST_Factory.newFoobarWithName(TEST_NAME_ALPHA);
		Foobar__c newRecord = TST_Factory.newFoobarWithName(TEST_NAME_BRAVO);

		Assert.isTrue(UTIL_SObject.hasFieldChanged(newRecord, oldRecord, Foobar__c.Name), 'Should detect field change');
	}

	/**
	 * @description Tests that hasFieldChanged returns false when the field value is the same.
	 *
	 * @see UTIL_SObject.hasFieldChanged
	 */
	@IsTest
	private static void hasFieldChangedReturnsFalseWhenSame()
	{
		Foobar__c oldRecord = TST_Factory.newFoobarWithName(TEST_NAME_ALPHA);
		Foobar__c newRecord = TST_Factory.newFoobarWithName(TEST_NAME_ALPHA);

		Assert.isFalse(UTIL_SObject.hasFieldChanged(newRecord, oldRecord, Foobar__c.Name), 'Should not detect change');
	}

	/**
	 * @description Tests that getChangedRecords returns only records where the specified field changed.
	 *
	 * @see UTIL_SObject.getChangedRecords
	 */
	@IsTest
	private static void getChangedRecordsFiltersBySingleField()
	{
		List<Foobar__c> oldRecords = new List<Foobar__c>
		{
				buildRecord(new Map<SObjectField, Object> {Foobar__c.Name => TEST_NAME_ALPHA, Foobar__c.Text__c => TEST_TEXT_VALUE}),
				buildRecord(new Map<SObjectField, Object> {Foobar__c.Name => TEST_NAME_BRAVO, Foobar__c.Text__c => TEST_TEXT_VALUE})
		};

		List<Foobar__c> newRecords = new List<Foobar__c>
		{
				buildRecord(new Map<SObjectField, Object> {Foobar__c.Name => 'Changed', Foobar__c.Text__c => TEST_TEXT_VALUE}),
				buildRecord(new Map<SObjectField, Object> {Foobar__c.Name => TEST_NAME_BRAVO, Foobar__c.Text__c => TEST_TEXT_VALUE})
		};

		List<SObject> result = UTIL_SObject.getChangedRecords(newRecords, oldRecords, Foobar__c.Name);

		Assert.areEqual(1, result.size(), 'Should return one changed record');
		Assert.areEqual('Changed', ((Foobar__c)result[0]).Name, 'Should return the record with changed Name');
	}

	/**
	 * @description Tests that getChangedRecords returns records where any of the specified fields changed.
	 *
	 * @see UTIL_SObject.getChangedRecords
	 */
	@IsTest
	private static void getChangedRecordsFiltersByMultipleFields()
	{
		Map<SObjectField, Object> charlieFields = new Map<SObjectField, Object>
		{
				Foobar__c.Name => 'Charlie',
				Foobar__c.Text__c => TEST_TEXT_VALUE,
				Foobar__c.Email__c => TEST_EMAIL_VALUE
		};

		List<Foobar__c> oldRecords = new List<Foobar__c>
		{
				buildRecord(new Map<SObjectField, Object>
				{
						Foobar__c.Name => TEST_NAME_ALPHA,
						Foobar__c.Text__c => TEST_TEXT_VALUE,
						Foobar__c.Email__c => TEST_EMAIL_VALUE
				}),
				buildRecord(new Map<SObjectField, Object>
				{
						Foobar__c.Name => TEST_NAME_BRAVO,
						Foobar__c.Text__c => TEST_TEXT_VALUE,
						Foobar__c.Email__c => TEST_EMAIL_VALUE
				}),
				buildRecord(charlieFields)
		};

		List<Foobar__c> newRecords = new List<Foobar__c>
		{
				buildRecord(new Map<SObjectField, Object>
				{
						Foobar__c.Name => TEST_NAME_ALPHA,
						Foobar__c.Text__c => 'Changed',
						Foobar__c.Email__c => TEST_EMAIL_VALUE
				}),
				buildRecord(new Map<SObjectField, Object>
				{
						Foobar__c.Name => TEST_NAME_BRAVO,
						Foobar__c.Text__c => TEST_TEXT_VALUE,
						Foobar__c.Email__c => 'changed@example.com'
				}),
				buildRecord(charlieFields)
		};

		List<SObject> result = UTIL_SObject.getChangedRecords(
				newRecords, oldRecords,
				new Set<SObjectField> {Foobar__c.Text__c, Foobar__c.Email__c}
		);

		Assert.areEqual(2, result.size(), 'Should return two changed records');
	}

	/**
	 * @description Tests that getChangedRecords returns empty list when no fields changed.
	 *
	 * @see UTIL_SObject.getChangedRecords
	 */
	@IsTest
	private static void getChangedRecordsReturnsEmptyWhenNoChanges()
	{
		Map<SObjectField, Object> sharedFields = new Map<SObjectField, Object>
		{
				Foobar__c.Name => TEST_NAME_ALPHA,
				Foobar__c.Text__c => TEST_TEXT_VALUE
		};

		List<Foobar__c> records = new List<Foobar__c> {buildRecord(sharedFields)};
		List<Foobar__c> identicalRecords = new List<Foobar__c> {buildRecord(sharedFields)};

		List<SObject> result = UTIL_SObject.getChangedRecords(identicalRecords, records, Foobar__c.Name);

		Assert.isTrue(result.isEmpty(), 'Should return empty list when no changes');
	}

	/**
	 * @description Builds a pair of test Foobar__c records with different names, without insertion.
	 *
	 * @return A list of two Foobar__c records.
	 */
	private static List<Foobar__c> buildTestRecordPair()
	{
		return new List<Foobar__c>
		{
				TST_Factory.newFoobarWithName(TEST_NAME_ALPHA),
				TST_Factory.newFoobarWithName(TEST_NAME_BRAVO)
		};
	}

	/**
	 * @description Builds a pair of records where the first has a populated Text field and the second does not.
	 *
	 * @return A list of two Foobar__c records as SObjects.
	 */
	private static List<SObject> buildRecordsWithPartialText()
	{
		return new List<SObject>
		{
				buildRecord(new Map<SObjectField, Object> {Foobar__c.Name => TEST_NAME_ALPHA, Foobar__c.Text__c => TEST_TEXT_VALUE}),
				buildRecord(new Map<SObjectField, Object> {Foobar__c.Name => TEST_NAME_BRAVO, Foobar__c.Text__c => null})
		};
	}

	/**
	 * @description Builds a Foobar__c record with specified field overrides, without insertion.
	 *
	 * @param overrides The field-value map for the record.
	 *
	 * @return A Foobar__c record.
	 */
	private static Foobar__c buildRecord(Map<SObjectField, Object> overrides)
	{
		return (Foobar__c)TST_Factory.getFoobarBuilder()
				.withOverrides(overrides)
				.withoutInsertion().build();
	}

	/**
	 * @description Builds a Foobar__c record with a populated parent relationship for dot-notation testing.
	 *
	 * @return A Foobar__c record with a parent Lookup__r relationship.
	 */
	private static Foobar__c buildRecordWithParent()
	{
		String relationshipName = Foobar__c.Lookup__c.getDescribe().getRelationshipName();

		return (Foobar__c)JSON.deserialize(
				'{"attributes":{"type":"Foobar__c"},"Name":"' + TEST_NAME_ALPHA + '","' + relationshipName + '":{"attributes":{"type":"Foobar__c"},"Name":"' + TEST_NAME_BRAVO + '"}}',
				Foobar__c.class
		);
	}
}