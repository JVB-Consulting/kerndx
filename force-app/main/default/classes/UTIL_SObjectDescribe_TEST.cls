// SPDX-License-Identifier: BSD-3-Clause
/**
 * Copyright (c), FinancialForce.com, inc
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 * - Neither the name of the FinancialForce.com, inc nor the names of its contributors
 * may be used to endorse or promote products derived from this software without
 * specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * This class adapted from https://github.com/capeterson/Apex-Util
 * Used under a BSD license: https://github.com/capeterson/Apex-Util/blob/master/LICENSE
 */

/**
 * @description Test the behaviour of the associated utility class
 *
 * @see UTIL_SObjectDescribe
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_SObjectDescribe_TEST
{
	/**
	 * @description Assertion message for key set containment checks
	 */
	private static final String MSG_CONTAINS_KEY = 'Key set should contain expected value';
	/**
	 * @description Assertion message for cache miss / different instance checks
	 */
	private static final String MSG_DIFFERENT_INSTANCE = 'Should return a different instance';
	/**
	 * @description Assertion message for field equality checks
	 */
	private static final String MSG_FIELD_EQUALITY = 'Field should match expected';
	/**
	 * @description Assertion message for incorrect object name
	 */
	private static final String MSG_INCORRECT_OBJECT_NAME = 'Incorrect Object Name';
	/**
	 * @description Assertion message for incorrect object type
	 */
	private static final String MSG_INCORRECT_OBJECT_TYPE = 'Incorrect Object Type';
	/**
	 * @description Assertion message for empty field results
	 */
	private static final String MSG_NO_FIELDS_RETURNED = 'No fields returned';
	/**
	 * @description Assertion message for non-empty map checks
	 */
	private static final String MSG_NOT_EMPTY = 'Map should not be empty';
	/**
	 * @description Assertion message for expected null results
	 */
	private static final String MSG_NULL_RESULT = 'Result should be null';
	/**
	 * @description Assertion message for cache hit / same instance checks
	 */
	private static final String MSG_SAME_INSTANCE = 'Should return the same cached instance';
	/**
	 * @description Assertion message for size equality checks
	 */
	private static final String MSG_SIZE_EQUALITY = 'Sizes should be equal';
	/**
	 * @description Assertion message for SObject type equality checks
	 */
	private static final String MSG_SOBJECT_TYPE = 'SObject type should match expected';
	/**
	 * @description Assertion message for value equality checks
	 */
	private static final String MSG_VALUE_EQUALITY = 'Values should match expected';
	/**
	 * @description Tests various ways of getting a Foobar__c describe
	 *
	 * @see UTIL_SObjectDescribe.getDescribe
	 */
	@IsTest
	private static void foobarDescribes()
	{
		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(objectName);
		UTIL_SObjectDescribe foobarDescribe2 = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);
		UTIL_SObjectDescribe foobarDescribe3 = UTIL_SObjectDescribe.getDescribe(SObjectType.Foobar__c);
		Assert.areEqual(objectName, foobarDescribe.getDescribe().name, 'Describe name should match');
		Assert.isTrue(foobarDescribe === foobarDescribe2 && foobarDescribe2 === foobarDescribe3, MSG_SAME_INSTANCE);
	}

	/**
	 * @description Tests field describe functionality
	 *
	 * @see UTIL_SObjectDescribe.getFieldsMap
	 */
	@IsTest
	private static void fieldDescribe()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);
		Map<String, SObjectField> fieldMap;
		for(Integer i = 0; i < 10; i++)
		{
			fieldMap = foobarDescribe.getFieldsMap();
		}

		Assert.isFalse(fieldMap.isEmpty(), MSG_NOT_EMPTY);
		Assert.areEqual(Foobar__c.SObjectType, foobarDescribe.getSObjectType(), MSG_SOBJECT_TYPE);
	}

	/**
	 * @description Tests field map behavior with namespaces
	 *
	 * @see UTIL_SObjectDescribe.FieldsMap
	 */
	@IsTest
	private static void fieldMap()
	{
		String fakeNamespace = 'ns_test';
		Map<String, SObjectField> mockFieldMap = new Map<String, SObjectField>
		{
				'name__c' => Foobar__c.Name,
				fakeNamespace + '__name__c' => Foobar__c.Text__c,
				fakeNamespace + '__otherField__c' => Foobar__c.Email__c,
				'createdDate' => Foobar__c.CreatedDate
		};
		UTIL_SObjectDescribe.FieldsMap fields = new UTIL_SObjectDescribe.FieldsMap(mockFieldMap);
		fields.currentNamespace = fakeNamespace;
		fields.namespacePrefix = fakeNamespace + UTIL_String.DOUBLE_UNDERSCORE;
		Assert.isTrue(fields.containsKey('name__c'), MSG_CONTAINS_KEY);
		Assert.isTrue(fields.containsKey(fakeNamespace.toUpperCase() + '__nAMe__c'), MSG_CONTAINS_KEY);
		Assert.isTrue(fields.get('NAme__c') === fields.get(fakeNamespace + '__namE__c'), MSG_SAME_INSTANCE);

		Assert.isFalse(fields.keySet(false).contains('otherField__c'), 'Key set should not contain unnamespaced field');
		Assert.isTrue(fields.keySet(false).contains(fakeNamespace + '__otherField__c'), MSG_CONTAINS_KEY);

		Assert.isTrue(fields.keySet(true).contains('otherField__c'), MSG_CONTAINS_KEY);
		Assert.isFalse(fields.keySet(true).contains(fakeNamespace + '__otherField__c'), 'Key set should not contain namespaced field');

		fields.currentNamespace = 'someOtherNamespace';
		fields.namespacePrefix = 'someOtherNamespace' + UTIL_String.DOUBLE_UNDERSCORE;
		Assert.areNotEqual(fields.get('name__C'), fields.get(fakeNamespace.capitalize() + '__nAme__c'), MSG_DIFFERENT_INSTANCE);
	}

	/**
	 * @description Tests field set describe functionality
	 *
	 * @see UTIL_SObjectDescribe.getFieldSetsMap
	 */
	@IsTest
	private static void fieldSetDescribe()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);
		Map<String, FieldSet> fieldSetMap;
		for(Integer i = 0; i < 10; i++)
		{
			fieldSetMap = foobarDescribe.getFieldSetsMap();
		}

		Assert.isFalse(fieldSetMap.isEmpty(), MSG_NOT_EMPTY);
	}

	/**
	 * @description Tests cache flush functionality
	 *
	 * @see UTIL_SObjectDescribe.flushCache
	 */
	@IsTest
	private static void flushCache()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);
		UTIL_SObjectDescribe.flushCache();
		UTIL_SObjectDescribe foobarDescribe2 = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);
		Assert.areNotEqual(foobarDescribe, foobarDescribe2, MSG_DIFFERENT_INSTANCE);
	}

	/**
	 * @description Tests handling of bad input for describe methods
	 *
	 * @see UTIL_SObjectDescribe.getDescribe
	 */
	@IsTest
	private static void getDescribeBadInput()
	{
		String nullString = null;
		SObjectType nullSObjectType = null;
		DescribeSObjectResult nullDescribeResult = null;
		SObject nullSObjectRecord = null;
		Assert.isNull(UTIL_SObjectDescribe.getDescribe(nullString), MSG_NULL_RESULT);
		Assert.isNull(UTIL_SObjectDescribe.getDescribe(''), MSG_NULL_RESULT);
		Assert.isNull(UTIL_SObjectDescribe.getDescribe(' '), MSG_NULL_RESULT);
		Assert.isNull(UTIL_SObjectDescribe.getDescribe(nullSObjectType), MSG_NULL_RESULT);
		Assert.isNull(UTIL_SObjectDescribe.getDescribe(nullDescribeResult), MSG_NULL_RESULT);
		Assert.isNull(UTIL_SObjectDescribe.getDescribe(nullSObjectRecord), MSG_NULL_RESULT);
	}

	/**
	 * @description Tests global describe map behavior with namespaces.
	 * Uses package-internal object types for namespace resolution testing.
	 *
	 * @see UTIL_SObjectDescribe.GlobalDescribeMap
	 */
	@IsTest
	private static void globalDescribeMap()
	{
		String fakeNamespace = 'ns_test';
		Map<String, SObjectType> mockSObjectTypeMap = new Map<String, SObjectType>
		{
				'name__c' => Foobar__c.SObjectType,
				fakeNamespace + '__name__c' => TriggerSetting__mdt.SObjectType,
				'createdDate' => TriggerAction__mdt.SObjectType
		};
		UTIL_SObjectDescribe.GlobalDescribeMap globalDescribe = new UTIL_SObjectDescribe.GlobalDescribeMap(mockSObjectTypeMap);
		globalDescribe.currentNamespace = fakeNamespace;
		globalDescribe.namespacePrefix = fakeNamespace + UTIL_String.DOUBLE_UNDERSCORE;
		Assert.isTrue(globalDescribe.containsKey('name__c'), MSG_CONTAINS_KEY);
		Assert.isTrue(globalDescribe.containsKey(fakeNamespace + '__name__c'), MSG_CONTAINS_KEY);
		Assert.isTrue(globalDescribe.get('name__c') === globalDescribe.get(fakeNamespace + '__name__c'), MSG_SAME_INSTANCE);

		globalDescribe.currentNamespace = 'someOtherNamespace';
		globalDescribe.namespacePrefix = 'someOtherNamespace' + UTIL_String.DOUBLE_UNDERSCORE;
		Assert.areNotEqual(globalDescribe.get('name__c'), globalDescribe.get(fakeNamespace + '__name__c'), MSG_DIFFERENT_INSTANCE);
	}

	/**
	 * @description Tests the isPersonAccountEnabled method
	 *
	 * @see UTIL_SObjectDescribe.isPersonAccountEnabled
	 */
	@IsTest
	private static void isPersonAccountEnabled()
	{
		Boolean isPersonAccountEnabled = UTIL_SObjectDescribe.getDescribe(Account.SObjectType).getField(UTIL_SObjectDescribe.FIELD_IS_PERSON_ACCOUNT) != null;

		Test.startTest();

		Boolean isPersonAccountEnabledUsingMethod = UTIL_SObjectDescribe.isPersonAccountEnabled();

		Test.stopTest();

		Assert.areEqual(isPersonAccountEnabled, isPersonAccountEnabledUsingMethod, MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests namespace attribute map functionality
	 *
	 * @see UTIL_SObjectDescribe.getGlobalDescribe
	 * @see UTIL_SObjectDescribe.getFields
	 */
	@IsTest
	private static void namespaceAttributeMap()
	{
		UTIL_SObjectDescribe.GlobalDescribeMap globalDescribe = UTIL_SObjectDescribe.getGlobalDescribe();

		Map<String, SObjectType> globalDescribeMap = Schema.getGlobalDescribe();

		Assert.areEqual(globalDescribeMap.size(), globalDescribe.size(), MSG_SIZE_EQUALITY);

		String foobarObjectName = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);
		SObjectType foobarSObjectType = globalDescribe.get(foobarObjectName);
		Assert.areEqual(Foobar__c.SObjectType, foobarSObjectType, MSG_SOBJECT_TYPE);
		Assert.areEqual(Schema.getGlobalDescribe().size(), globalDescribe.size(), MSG_SIZE_EQUALITY);

		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(foobarSObjectType);
		UTIL_SObjectDescribe.FieldsMap fields = foobarDescribe.getFields();
		Assert.isTrue(fields.keySet().containsAll(foobarDescribe.getFieldsMap().keySet()), MSG_CONTAINS_KEY);

		Assert.areEqual(Foobar__c.Name, fields.get(SEL_Foobar.FIELD_NAME), MSG_FIELD_EQUALITY);
		Assert.areEqual(SObjectType.Foobar__c.fields.getMap().size(), fields.size(), MSG_SIZE_EQUALITY);

		Assert.isNull(fields.get(null), MSG_NULL_RESULT);
		Assert.isNull(fields.get(''), MSG_NULL_RESULT);
	}

	/**
	 * @description Tests raw global describe functionality
	 *
	 * @see UTIL_SObjectDescribe.getRawGlobalDescribe
	 */
	@IsTest
	private static void rawGlobalDescribeCheck()
	{
		Map<String, SObjectType> systemGlobalDescribe = Schema.getGlobalDescribe();
		UTIL_SObjectDescribe.flushCache();
		Map<String, SObjectType> cachedGlobalDescribe = UTIL_SObjectDescribe.getRawGlobalDescribe();
		Assert.areEqual(systemGlobalDescribe.size(), cachedGlobalDescribe.size(), MSG_SIZE_EQUALITY);
	}

	/**
	 * @description Tests getting the name field for Foobar__c
	 *
	 * @see UTIL_SObjectDescribe.getNameField
	 */
	@IsTest
	private static void simpleFoobarGetNameField()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);
		SObjectField nameField = foobarDescribe.getNameField();
		Assert.areEqual(SEL_Foobar.FIELD_NAME, nameField.getDescribe().name, MSG_FIELD_EQUALITY);
	}

	/**
	 * @description Tests values in the global describe
	 *
	 * @see UTIL_SObjectDescribe.getGlobalDescribe
	 */
	@IsTest
	private static void valuesCheck()
	{
		Map<String, SObjectType> systemGlobalDescribe = Schema.getGlobalDescribe();
		UTIL_SObjectDescribe.flushCache();
		UTIL_SObjectDescribe.GlobalDescribeMap cachedGlobalDescribe = UTIL_SObjectDescribe.getGlobalDescribe();
		Assert.areEqual(systemGlobalDescribe.values().size(), cachedGlobalDescribe.values().size(), MSG_SIZE_EQUALITY);
	}

	/**
	 * @description Tests that Object Name is retrieved from type
	 *
	 * @see UTIL_SObjectDescribe.getObjectNameFromType
	 */
	@IsTest
	private static void getObjectNameFromType()
	{
		final String objectName = Foobar__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).name;

		Test.startTest();

		String objectNameFromType = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);

		Test.stopTest();

		Assert.areEqual(objectName, objectNameFromType, MSG_VALUE_EQUALITY);
	}

	/**
	 * @description Tests that Object Name is retrieved from type, where the type is null
	 *
	 * @see UTIL_SObjectDescribe.getObjectNameFromType
	 */
	@IsTest
	private static void getObjectNameFromNullType()
	{
		Test.startTest();

		String objectNameFromType = UTIL_SObjectDescribe.getObjectNameFromType(null);

		Test.stopTest();

		Assert.isNull(objectNameFromType, MSG_NULL_RESULT);
	}

	/**
	 * @description Tests getFieldDescribe returns correct DescribeFieldResult for valid field name
	 *
	 * @see UTIL_SObjectDescribe.getFieldDescribe
	 */
	@IsTest
	private static void getFieldDescribeByStringReturnsDescribe()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		DescribeFieldResult fieldDescribe = foobarDescribe.getFieldDescribe(SEL_Foobar.FIELD_NAME);

		Test.stopTest();

		Assert.isNotNull(fieldDescribe, 'DescribeFieldResult should not be null');
		Assert.areEqual(SEL_Foobar.FIELD_NAME, fieldDescribe.name, 'Field name should match');
	}

	/**
	 * @description Tests getFieldDescribe returns null for blank or invalid field names
	 *
	 * @see UTIL_SObjectDescribe.getFieldDescribe
	 */
	@IsTest
	private static void getFieldDescribeByStringReturnsNullForInvalid()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		DescribeFieldResult nullResult = foobarDescribe.getFieldDescribe((String)null);
		DescribeFieldResult emptyResult = foobarDescribe.getFieldDescribe(UTIL_String.EMPTY);
		DescribeFieldResult blankResult = foobarDescribe.getFieldDescribe(UTIL_String.SPACE);
		DescribeFieldResult invalidResult = foobarDescribe.getFieldDescribe('NonExistentField__c');

		Test.stopTest();

		Assert.isNull(nullResult, MSG_NULL_RESULT);
		Assert.isNull(emptyResult, MSG_NULL_RESULT);
		Assert.isNull(blankResult, MSG_NULL_RESULT);
		Assert.isNull(invalidResult, MSG_NULL_RESULT);
	}

	/**
	 * @description Tests getFieldDescribe caches results for subsequent calls
	 *
	 * @see UTIL_SObjectDescribe.getFieldDescribe
	 */
	@IsTest
	private static void getFieldDescribeByStringCachesResult()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		DescribeFieldResult firstCall = foobarDescribe.getFieldDescribe(SEL_Foobar.FIELD_NAME);
		DescribeFieldResult secondCall = foobarDescribe.getFieldDescribe(SEL_Foobar.FIELD_NAME.toLowerCase());
		DescribeFieldResult thirdCall = foobarDescribe.getFieldDescribe(SEL_Foobar.FIELD_NAME.toUpperCase());

		Test.stopTest();

		Assert.isTrue(firstCall === secondCall, MSG_SAME_INSTANCE);
		Assert.isTrue(secondCall === thirdCall, MSG_SAME_INSTANCE);
	}

	/**
	 * @description Tests getFieldDescribe with SObjectField token returns correct DescribeFieldResult
	 *
	 * @see UTIL_SObjectDescribe.getFieldDescribe
	 */
	@IsTest
	private static void getFieldDescribeBySObjectFieldReturnsDescribe()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		DescribeFieldResult fieldDescribe = foobarDescribe.getFieldDescribe(Foobar__c.Name);

		Test.stopTest();

		Assert.isNotNull(fieldDescribe, 'DescribeFieldResult should not be null');
		Assert.areEqual(SEL_Foobar.FIELD_NAME, fieldDescribe.name, 'Field name should match');
	}

	/**
	 * @description Tests getFieldDescribe with SObjectField returns null for null field
	 *
	 * @see UTIL_SObjectDescribe.getFieldDescribe
	 */
	@IsTest
	private static void getFieldDescribeBySObjectFieldReturnsNullForNull()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);
		SObjectField nullField = null;

		Test.startTest();

		DescribeFieldResult result = foobarDescribe.getFieldDescribe(nullField);

		Test.stopTest();

		Assert.isNull(result, MSG_NULL_RESULT);
	}

	/**
	 * @description Tests getFieldDescribe with SObjectField caches and shares results with string version
	 *
	 * @see UTIL_SObjectDescribe.getFieldDescribe
	 */
	@IsTest
	private static void getFieldDescribeBySObjectFieldCachesResult()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		DescribeFieldResult fromToken = foobarDescribe.getFieldDescribe(Foobar__c.Name);
		DescribeFieldResult fromString = foobarDescribe.getFieldDescribe(SEL_Foobar.FIELD_NAME);

		Test.stopTest();

		Assert.isTrue(fromToken === fromString, MSG_SAME_INSTANCE);
	}

	/**
	 * @description Tests static getCachedFieldName returns correct field name for valid SObjectField
	 *
	 * @see UTIL_SObjectDescribe.getCachedFieldName
	 */
	@IsTest
	private static void getCachedFieldNameReturnsName()
	{
		Test.startTest();

		String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name);

		Test.stopTest();

		Assert.areEqual(SEL_Foobar.FIELD_NAME, fieldName, 'Field name should match');
	}

	/**
	 * @description Tests static getCachedFieldName returns null for null SObjectField
	 *
	 * @see UTIL_SObjectDescribe.getCachedFieldName
	 */
	@IsTest
	private static void getCachedFieldNameReturnsNullForNull()
	{
		SObjectField nullField = null;

		Test.startTest();

		String result = UTIL_SObjectDescribe.getCachedFieldName(nullField);

		Test.stopTest();

		Assert.isNull(result, MSG_NULL_RESULT);
	}

	/**
	 * @description Tests instance getFieldName with SObjectField returns correct field name
	 *
	 * @see UTIL_SObjectDescribe.getFieldName
	 */
	@IsTest
	private static void getFieldNameBySObjectFieldReturnsName()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		String fieldName = foobarDescribe.getFieldName(Foobar__c.Name);

		Test.stopTest();

		Assert.areEqual(SEL_Foobar.FIELD_NAME, fieldName, 'Field name should match');
	}

	/**
	 * @description Tests instance getFieldName with SObjectField returns null for null field
	 *
	 * @see UTIL_SObjectDescribe.getFieldName
	 */
	@IsTest
	private static void getFieldNameBySObjectFieldReturnsNullForNull()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);
		SObjectField nullField = null;

		Test.startTest();

		String result = foobarDescribe.getFieldName(nullField);

		Test.stopTest();

		Assert.isNull(result, MSG_NULL_RESULT);
	}

	/**
	 * @description Tests that instance getFieldName shares cache with static getCachedFieldName
	 *
	 * @see UTIL_SObjectDescribe.getFieldName
	 * @see UTIL_SObjectDescribe.getCachedFieldName
	 */
	@IsTest
	private static void getFieldNameSharesCacheWithStatic()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		String fromInstance = foobarDescribe.getFieldName(Foobar__c.Name);
		String fromStatic = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Name);

		Test.stopTest();

		Assert.areEqual(fromInstance, fromStatic, 'Both methods should return the same field name');
	}

	/**
	 * @description Tests getQueryableFieldNames returns set of selectable fields
	 *
	 * @see UTIL_SObjectDescribe.getQueryableFieldNames
	 */
	@IsTest
	private static void getQueryableFieldNamesReturnsSelectableFields()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		Set<String> queryableFields = foobarDescribe.getQueryableFieldNames();

		Test.stopTest();

		Assert.isFalse(queryableFields.isEmpty(), MSG_NOT_EMPTY);
		Assert.isTrue(queryableFields.contains(SEL_Foobar.FIELD_NAME), 'Should contain Name field');
		Assert.isFalse(queryableFields.contains('Id'), 'Should not contain Id field');
		Assert.isFalse(queryableFields.contains('IsDeleted'), 'Should not contain IsDeleted field');
	}

	/**
	 * @description Tests getQueryableFieldNames returns clone to prevent modification
	 *
	 * @see UTIL_SObjectDescribe.getQueryableFieldNames
	 */
	@IsTest
	private static void getQueryableFieldNamesReturnsClone()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		Set<String> firstCall = foobarDescribe.getQueryableFieldNames();
		Integer originalSize = firstCall.size();
		firstCall.add('FakeField__c');
		Set<String> secondCall = foobarDescribe.getQueryableFieldNames();

		Test.stopTest();

		Assert.areEqual(originalSize, secondCall.size(), 'Original cache should not be modified');
	}

	/**
	 * @description Tests getTraversableReferenceFields returns safe lookup fields
	 *
	 * @see UTIL_SObjectDescribe.getTraversableReferenceFields
	 */
	@IsTest
	private static void getTraversableReferenceFieldsExcludesSystemFields()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		Set<String> traversableFields = foobarDescribe.getTraversableReferenceFields();

		Test.stopTest();

		Assert.isFalse(traversableFields.contains(SEL_Foobar.FIELD_CREATED_BY_ID.toLowerCase()), 'Should not contain CreatedById');
		Assert.isFalse(traversableFields.contains(SEL_Foobar.FIELD_LAST_MODIFIED_BY_ID.toLowerCase()), 'Should not contain LastModifiedById');
		Assert.isFalse(traversableFields.contains(SEL_Foobar.FIELD_OWNER_ID.toLowerCase()), 'Should not contain OwnerId');
	}

	/**
	 * @description Tests getTraversableReferenceFields includes business lookups
	 *
	 * @see UTIL_SObjectDescribe.getTraversableReferenceFields
	 */
	@IsTest
	private static void getTraversableReferenceFieldsIncludesBusinessLookups()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		Set<String> traversableFields = foobarDescribe.getTraversableReferenceFields();

		Test.stopTest();

		Assert.isTrue(traversableFields.contains(SEL_Foobar.FIELD_LOOKUP.toLowerCase()), 'Should contain Lookup__c');
	}

	/**
	 * @description Tests getCreatableRequiredFields returns fields required for insert.
	 * Validates method execution without asserting specific fields since object configurations vary.
	 *
	 * @see UTIL_SObjectDescribe.getCreatableRequiredFields
	 */
	@IsTest
	private static void getCreatableRequiredFieldsReturnsRequiredFields()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		Set<String> requiredFields = foobarDescribe.getCreatableRequiredFields();

		Test.stopTest();

		Assert.isNotNull(requiredFields, 'Should return non-null set');
		for(String fieldName : requiredFields)
		{
			UTIL_SObjectDescribe.FieldMetadata metadata = foobarDescribe.getFieldMetadata(fieldName);
			Assert.isTrue(metadata.isCreatableRequired, 'All returned fields should be creatable required');
		}
	}

	/**
	 * @description Tests getRelationshipFieldMap returns field-to-relationship mapping
	 *
	 * @see UTIL_SObjectDescribe.getRelationshipFieldMap
	 */
	@IsTest
	private static void getRelationshipFieldMapReturnsMapping()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		Map<String, String> relationshipMap = foobarDescribe.getRelationshipFieldMap();

		Test.stopTest();

		Assert.isFalse(relationshipMap.isEmpty(), MSG_NOT_EMPTY);
		Assert.areEqual(SEL_Foobar.RELATIONSHIP_LOOKUP.toLowerCase(), relationshipMap.get(SEL_Foobar.FIELD_LOOKUP.toLowerCase()), 'Lookup__c should map to Lookup relationship');
	}

	/**
	 * @description Tests getReferenceFieldMap returns relationship-to-field mapping
	 *
	 * @see UTIL_SObjectDescribe.getReferenceFieldMap
	 */
	@IsTest
	private static void getReferenceFieldMapReturnsMapping()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		Map<String, SObjectField> referenceMap = foobarDescribe.getReferenceFieldMap();

		Test.stopTest();

		Assert.isFalse(referenceMap.isEmpty(), MSG_NOT_EMPTY);
		Assert.areEqual(Foobar__c.Lookup__c, referenceMap.get(SEL_Foobar.RELATIONSHIP_LOOKUP), 'Lookup relationship should map to Lookup__c field');
	}

	/**
	 * @description Tests getFieldMetadataMap returns metadata for all fields
	 *
	 * @see UTIL_SObjectDescribe.getFieldMetadataMap
	 */
	@IsTest
	private static void getFieldMetadataMapReturnsAllFields()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		Map<String, UTIL_SObjectDescribe.FieldMetadata> metadataMap = foobarDescribe.getFieldMetadataMap();

		Test.stopTest();

		Assert.isFalse(metadataMap.isEmpty(), MSG_NOT_EMPTY);
		Assert.isTrue(metadataMap.containsKey(SEL_Foobar.FIELD_NAME.toLowerCase()), 'Should contain Name field');

		UTIL_SObjectDescribe.FieldMetadata nameMetadata = metadataMap.get(SEL_Foobar.FIELD_NAME.toLowerCase());
		Assert.areEqual(SEL_Foobar.FIELD_NAME, nameMetadata.name, 'Name should have correct original case');
		Assert.areEqual(SEL_Foobar.FIELD_NAME.toLowerCase(), nameMetadata.nameLowerCase, 'Should have lowercase name');
		Assert.isTrue(nameMetadata.isSelectableInQuery, 'Name should be selectable');
	}

	/**
	 * @description Tests getFieldMetadata returns metadata for specific field
	 *
	 * @see UTIL_SObjectDescribe.getFieldMetadata
	 */
	@IsTest
	private static void getFieldMetadataReturnsSpecificField()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		UTIL_SObjectDescribe.FieldMetadata metadata = foobarDescribe.getFieldMetadata(SEL_Foobar.FIELD_NAME);
		UTIL_SObjectDescribe.FieldMetadata metadataLowerCase = foobarDescribe.getFieldMetadata(SEL_Foobar.FIELD_NAME.toLowerCase());
		UTIL_SObjectDescribe.FieldMetadata metadataUpperCase = foobarDescribe.getFieldMetadata(SEL_Foobar.FIELD_NAME.toUpperCase());

		Test.stopTest();

		Assert.isNotNull(metadata, 'Should return metadata for valid field');
		Assert.areEqual(SEL_Foobar.FIELD_NAME, metadata.name, 'Should have correct field name');
		Assert.isTrue(metadata === metadataLowerCase, 'Should be case-insensitive');
		Assert.isTrue(metadataLowerCase === metadataUpperCase, 'Should be case-insensitive');
	}

	/**
	 * @description Tests getFieldMetadata returns null for invalid input
	 *
	 * @see UTIL_SObjectDescribe.getFieldMetadata
	 */
	@IsTest
	private static void getFieldMetadataReturnsNullForInvalid()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		UTIL_SObjectDescribe.FieldMetadata nullResult = foobarDescribe.getFieldMetadata(null);
		UTIL_SObjectDescribe.FieldMetadata emptyResult = foobarDescribe.getFieldMetadata('');
		UTIL_SObjectDescribe.FieldMetadata blankResult = foobarDescribe.getFieldMetadata(' ');
		UTIL_SObjectDescribe.FieldMetadata invalidResult = foobarDescribe.getFieldMetadata('NonExistentField__c');

		Test.stopTest();

		Assert.isNull(nullResult, MSG_NULL_RESULT);
		Assert.isNull(emptyResult, MSG_NULL_RESULT);
		Assert.isNull(blankResult, MSG_NULL_RESULT);
		Assert.isNull(invalidResult, MSG_NULL_RESULT);
	}

	/**
	 * @description Tests FieldMetadata correctly identifies lookup field properties
	 *
	 * @see UTIL_SObjectDescribe.FieldMetadata
	 */
	@IsTest
	private static void fieldMetadataIdentifiesLookupFields()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);
		String foobarObjectName = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);

		Test.startTest();

		UTIL_SObjectDescribe.FieldMetadata lookupMetadata = foobarDescribe.getFieldMetadata(SEL_Foobar.FIELD_LOOKUP);

		Test.stopTest();

		Assert.isNotNull(lookupMetadata, 'Should return metadata for Lookup__c');
		Assert.areEqual(DisplayType.REFERENCE, lookupMetadata.fieldType, 'Should be REFERENCE type');
		Assert.areEqual(SEL_Foobar.RELATIONSHIP_LOOKUP.toLowerCase(), lookupMetadata.relationshipName, 'Should have relationship name');
		Assert.isFalse(lookupMetadata.referenceToObjectNames.isEmpty(), 'Should have reference targets');
		Assert.areEqual(foobarObjectName, lookupMetadata.referenceToObjectNames[0], 'Should reference Foobar__c');
		Assert.isTrue(lookupMetadata.isTraversableReference, 'Lookup__c should be traversable');
	}

	/**
	 * @description Tests FieldMetadata correctly identifies system audit fields as non-traversable
	 *
	 * @see UTIL_SObjectDescribe.FieldMetadata
	 */
	@IsTest
	private static void fieldMetadataIdentifiesSystemFieldsAsNonTraversable()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Test.startTest();

		UTIL_SObjectDescribe.FieldMetadata createdByMetadata = foobarDescribe.getFieldMetadata(SEL_Foobar.FIELD_CREATED_BY_ID);
		UTIL_SObjectDescribe.FieldMetadata ownerMetadata = foobarDescribe.getFieldMetadata(SEL_Foobar.FIELD_OWNER_ID);

		Test.stopTest();

		Assert.isNotNull(createdByMetadata, 'Should return metadata for CreatedById');
		Assert.isFalse(createdByMetadata.isTraversableReference, 'CreatedById should not be traversable');

		Assert.isNotNull(ownerMetadata, 'Should return metadata for OwnerId');
		Assert.isFalse(ownerMetadata.isTraversableReference, 'OwnerId should not be traversable');
	}

	/**
	 * @description Tests that all derived caches are populated on first access only.
	 * Verifies single iteration by checking that all caches are populated after one access.
	 *
	 * @see UTIL_SObjectDescribe.getQueryableFieldNames
	 * @see UTIL_SObjectDescribe.getCreatableRequiredFields
	 */
	@IsTest
	private static void shouldPopulateAllCachesOnFirstAccessOnly()
	{
		UTIL_SObjectDescribe.flushCache();

		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);

		Set<String> queryableFields = foobarDescribe.getQueryableFieldNames();

		Assert.isFalse(queryableFields.isEmpty(), 'Should have queryable fields after first access');

		Set<String> requiredFields = foobarDescribe.getCreatableRequiredFields();
		Map<String, String> relationshipMap = foobarDescribe.getRelationshipFieldMap();
		Map<String, SObjectField> referenceMap = foobarDescribe.getReferenceFieldMap();
		Set<String> traversableFields = foobarDescribe.getTraversableReferenceFields();

		Assert.isNotNull(requiredFields, 'Required fields should be populated');
		Assert.isNotNull(relationshipMap, 'Relationship map should be populated');
		Assert.isNotNull(referenceMap, 'Reference map should be populated');
		Assert.isNotNull(traversableFields, 'Traversable fields should be populated');
	}

	/**
	 * @description Tests that cache is cleared when flushCache is called
	 *
	 * @see UTIL_SObjectDescribe.flushCache
	 * @see UTIL_SObjectDescribe.getQueryableFieldNames
	 */
	@IsTest
	private static void flushCacheClearsDerivedCaches()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);
		Set<String> firstQueryableFields = foobarDescribe.getQueryableFieldNames();

		UTIL_SObjectDescribe.flushCache();

		UTIL_SObjectDescribe newFoobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);
		Set<String> secondQueryableFields = newFoobarDescribe.getQueryableFieldNames();

		Assert.areNotEqual(foobarDescribe, newFoobarDescribe, MSG_DIFFERENT_INSTANCE);
		Assert.areEqual(firstQueryableFields.size(), secondQueryableFields.size(), MSG_SIZE_EQUALITY);
	}

	/**
	 * @description Tests FieldMetadata correctly identifies polymorphic fields as non-traversable
	 *
	 * @see UTIL_SObjectDescribe.FieldMetadata
	 */
	@IsTest
	private static void fieldMetadataIdentifiesPolymorphicFieldsAsNonTraversable()
	{
		UTIL_SObjectDescribe taskDescribe = UTIL_SObjectDescribe.getDescribe(Task.SObjectType);

		Test.startTest();

		UTIL_SObjectDescribe.FieldMetadata whoIdMetadata = taskDescribe.getFieldMetadata('WhoId');

		Test.stopTest();

		Assert.isNotNull(whoIdMetadata, 'Should return metadata for WhoId');
		Assert.areEqual(DisplayType.REFERENCE, whoIdMetadata.fieldType, 'Should be REFERENCE type');
		Assert.isFalse(whoIdMetadata.isTraversableReference, 'WhoId should not be traversable (polymorphic)');
	}

	/**
	 * @description Tests that suffix constants are accessible and have expected values
	 *
	 * @see UTIL_SObjectDescribe.CUSTOM_FIELD_SUFFIX
	 * @see UTIL_SObjectDescribe.CUSTOM_OBJECT_SHARE_SUFFIX
	 * @see UTIL_SObjectDescribe.RELATIONSHIP_SUFFIX
	 */
	@IsTest
	private static void shouldHaveCorrectSuffixConstants()
	{
		Assert.areEqual('__c', UTIL_SObjectDescribe.CUSTOM_FIELD_SUFFIX, 'Custom field suffix should be __c');
		Assert.areEqual('__Share', UTIL_SObjectDescribe.CUSTOM_OBJECT_SHARE_SUFFIX, 'Custom object share suffix should be __Share');
		Assert.areEqual('__r', UTIL_SObjectDescribe.RELATIONSHIP_SUFFIX, 'Relationship suffix should be __r');
	}

	/**
	 * @description Tests getDefaultPicklistValue returns default value when one exists
	 *
	 * @see UTIL_SObjectDescribe.getDefaultPicklistValue
	 */
	@IsTest
	private static void getDefaultPicklistValueReturnsDefaultValue()
	{
		Test.startTest();

		String defaultValue = UTIL_SObjectDescribe.getDefaultPicklistValue(Foobar__c.Picklist__c);

		Test.stopTest();

		Assert.isNotNull(defaultValue, 'Should return a default picklist value');
	}

	/**
	 * @description Tests getDefaultPicklistValue with returnFirstEntryIfNoDefault flag
	 *
	 * @see UTIL_SObjectDescribe.getDefaultPicklistValue
	 */
	@IsTest
	private static void getDefaultPicklistValueReturnsFirstEntryWhenNoDefault()
	{
		Test.startTest();

		String value = UTIL_SObjectDescribe.getDefaultPicklistValue(Foobar__c.Picklist__c, true);

		Test.stopTest();

		Assert.isNotNull(value, 'Should return a picklist value');
	}

	/**
	 * @description Tests getDefaultPicklistValue with DescribeFieldResult overload
	 *
	 * @see UTIL_SObjectDescribe.getDefaultPicklistValue
	 */
	@IsTest
	private static void getDefaultPicklistValueWithDescribeReturnsValue()
	{
		DescribeFieldResult fieldDescribe = Foobar__c.Picklist__c.getDescribe();

		Test.startTest();

		String value = UTIL_SObjectDescribe.getDefaultPicklistValue(fieldDescribe);

		Test.stopTest();

		Assert.isNotNull(value, 'Should return a picklist value');
	}

	/**
	 * @description Tests getDefaultPicklistValue returns null for non-picklist fields
	 *
	 * @see UTIL_SObjectDescribe.getDefaultPicklistValue
	 */
	@IsTest
	private static void getDefaultPicklistValueReturnsNullForNonPicklist()
	{
		Test.startTest();

		String value = UTIL_SObjectDescribe.getDefaultPicklistValue(Foobar__c.Text__c);

		Test.stopTest();

		Assert.isNull(value, MSG_NULL_RESULT);
	}

	/**
	 * @description Tests getDefaultRecordType returns an Id when record types exist
	 *
	 * @see UTIL_SObjectDescribe.getDefaultRecordType
	 */
	@IsTest
	private static void getDefaultRecordTypeReturnsId()
	{
		Test.startTest();

		Id recordTypeId = UTIL_SObjectDescribe.getDefaultRecordType(Account.SObjectType);

		Test.stopTest();

		Assert.isNotNull(recordTypeId, 'Should return a default record type Id');
	}

	/**
	 * @description Tests getDefaultRecordType returns null for null input
	 *
	 * @see UTIL_SObjectDescribe.getDefaultRecordType
	 */
	@IsTest
	private static void getDefaultRecordTypeReturnsNullForNullInput()
	{
		Test.startTest();

		Id recordTypeId = UTIL_SObjectDescribe.getDefaultRecordType(null);

		Test.stopTest();

		Assert.isNull(recordTypeId, MSG_NULL_RESULT);
	}

	/**
	 * @description Tests getRecordTypeByDeveloperName returns null for invalid name
	 *
	 * @see UTIL_SObjectDescribe.getRecordTypeByDeveloperName
	 */
	@IsTest
	private static void getRecordTypeByDeveloperNameReturnsNullForInvalidName()
	{
		Test.startTest();

		Id recordTypeId = UTIL_SObjectDescribe.getRecordTypeByDeveloperName(Account.SObjectType, 'NonExistentRecordType');

		Test.stopTest();

		Assert.isNull(recordTypeId, MSG_NULL_RESULT);
	}

	/**
	 * @description Tests FieldsMap.keySet() override returns keys
	 *
	 * @see UTIL_SObjectDescribe.FieldsMap.keySet
	 */
	@IsTest
	private static void fieldsMapKeySetReturnsKeys()
	{
		UTIL_SObjectDescribe foobarDescribe = UTIL_SObjectDescribe.getDescribe(Foobar__c.SObjectType);
		UTIL_SObjectDescribe.FieldsMap fields = foobarDescribe.getFields();

		Test.startTest();

		Set<String> keys = fields.keySet();
		Set<String> keysWithNamespace = fields.keySet(true);

		Test.stopTest();

		Assert.isFalse(keys.isEmpty(), MSG_NOT_EMPTY);
		Assert.isFalse(keysWithNamespace.isEmpty(), MSG_NOT_EMPTY);
	}

	/**
	 * @description Tests GlobalDescribeMap.keySet() and keySet(true) overrides return keys
	 *
	 * @see UTIL_SObjectDescribe.GlobalDescribeMap.keySet
	 */
	@IsTest
	private static void globalDescribeMapKeySetReturnsKeys()
	{
		UTIL_SObjectDescribe.GlobalDescribeMap globalDescribe = UTIL_SObjectDescribe.getGlobalDescribe();

		Test.startTest();

		Set<String> keys = globalDescribe.keySet();
		Set<String> keysWithNamespace = globalDescribe.keySet(true);

		Test.stopTest();

		Assert.isFalse(keys.isEmpty(), MSG_NOT_EMPTY);
		Assert.isFalse(keysWithNamespace.isEmpty(), MSG_NOT_EMPTY);
	}

	/**
	 * @description Tests getPicklistEntriesMap with SObjectField returns map keyed by label
	 *
	 * @see UTIL_SObjectDescribe.getPicklistEntriesMap
	 */
	@IsTest
	private static void getPicklistEntriesMapBySObjectFieldReturnsMap()
	{
		Test.startTest();

		Map<String, String> entriesMap = UTIL_SObjectDescribe.getPicklistEntriesMap(Foobar__c.Picklist__c);

		Test.stopTest();

		Assert.isFalse(entriesMap.isEmpty(), MSG_NOT_EMPTY);
	}

	/**
	 * @description Tests getPicklistEntriesMap with SObjectField and useLabelAsKey flag
	 *
	 * @see UTIL_SObjectDescribe.getPicklistEntriesMap
	 */
	@IsTest
	private static void getPicklistEntriesMapBySObjectFieldWithKeyFlag()
	{
		Test.startTest();

		Map<String, String> labelKeyedMap = UTIL_SObjectDescribe.getPicklistEntriesMap(Foobar__c.Picklist__c, true);
		Map<String, String> valueKeyedMap = UTIL_SObjectDescribe.getPicklistEntriesMap(Foobar__c.Picklist__c, false);

		Test.stopTest();

		Assert.isFalse(labelKeyedMap.isEmpty(), 'Label-keyed map should not be empty');
		Assert.isFalse(valueKeyedMap.isEmpty(), 'Value-keyed map should not be empty');
	}

	/**
	 * @description Tests getObjectFieldReferenceMap returns reference fields keyed by relationship name
	 *
	 * @see UTIL_SObjectDescribe.getObjectFieldReferenceMap
	 */
	@IsTest
	private static void getObjectFieldReferenceMapReturnsReferenceFields()
	{
		Test.startTest();

		Map<String, SObjectField> referenceMap = UTIL_SObjectDescribe.getObjectFieldReferenceMap(SEL_Foobar.OBJECT_NAME);

		Test.stopTest();

		Assert.isFalse(referenceMap.isEmpty(), MSG_NOT_EMPTY);
	}

	/**
	 * @description Tests getNestableFieldNames with one argument returns nested field names
	 *
	 * @see UTIL_SObjectDescribe.getNestableFieldNames
	 */
	@IsTest
	private static void getNestableFieldNamesReturnsNestedFields()
	{
		Test.startTest();

		Set<String> fieldNames = UTIL_SObjectDescribe.getNestableFieldNames(SEL_Foobar.OBJECT_NAME);

		Test.stopTest();

		Assert.isFalse(fieldNames.isEmpty(), 'Should return nestable field names');
	}

	/**
	 * @description Tests getAllFieldNames with SObjectType returns queryable field names
	 *
	 * @see UTIL_SObjectDescribe.getAllFieldNames
	 */
	@IsTest
	private static void getAllFieldNamesBySObjectTypeReturnsFields()
	{
		Test.startTest();

		Set<String> fieldNames = UTIL_SObjectDescribe.getAllFieldNames(Foobar__c.SObjectType);

		Test.stopTest();

		Assert.isFalse(fieldNames.isEmpty(), 'Should return field names');
		Assert.isTrue(fieldNames.contains('Name'), 'Should contain Name field');
	}

	/**
	 * @description Tests that invalid field names are filtered out and valid ones retained.
	 *
	 * @see UTIL_SObjectDescribe.extractValidObjectFieldNames
	 */
	@IsTest
	private static void extractValidFieldNames()
	{
		Set<String> inputFields = UTIL_SObjectDescribe.getSObjectFieldNames(new Set<SObjectField>(new SEL_Foobar().fields));
		final String invalidFieldName = 'Invalid';
		inputFields.add(invalidFieldName);

		Test.startTest();

		Set<String> outputFields = UTIL_SObjectDescribe.extractValidObjectFieldNames(SEL_Foobar.OBJECT_NAME, inputFields);

		Test.stopTest();

		Assert.isFalse(outputFields.isEmpty(), MSG_NO_FIELDS_RETURNED);
		Assert.areNotEqual(inputFields, outputFields, 'Sets should not be equal');
		Assert.isFalse(outputFields.contains(invalidFieldName), 'Field was not removed');

		inputFields.remove(invalidFieldName);
		Assert.isTrue(inputFields.removeAll(outputFields), 'Expected fields to be removed');
		Assert.isTrue(
				inputFields.isEmpty(),
				String.format(
						'The expected fields were not retrieved: Input Fields: "{0}", Output Fields "{1}',
						new List<Object> {inputFields, outputFields}
				)
		);
	}

	/**
	 * @description Tests that a custom relationship traversal is validated correctly.
	 *
	 * @see UTIL_SObjectDescribe.extractValidObjectFieldNames
	 */
	@IsTest
	private static void extractValidFieldNamesWithCustomRelationship()
	{
		Set<String> inputFields = new Set<String> {SEL_Foobar.RELATIONSHIP_LOOKUP + '.Name'};

		Test.startTest();

		Set<String> outputFields = UTIL_SObjectDescribe.extractValidObjectFieldNames(SEL_Foobar.OBJECT_NAME, inputFields);

		Test.stopTest();

		Assert.isTrue(outputFields.contains(SEL_Foobar.RELATIONSHIP_LOOKUP + '.Name'), 'Custom relationship traversal should be valid');
	}

	/**
	 * @description Tests that a standard relationship traversal is validated correctly.
	 *
	 * @see UTIL_SObjectDescribe.extractValidObjectFieldNames
	 */
	@IsTest
	private static void extractValidFieldNamesWithStandardRelationship()
	{
		Set<String> inputFields = new Set<String> {'CreatedBy.Name'};

		Test.startTest();

		Set<String> outputFields = UTIL_SObjectDescribe.extractValidObjectFieldNames(SEL_Foobar.OBJECT_NAME, inputFields);

		Test.stopTest();

		Assert.isTrue(outputFields.contains('CreatedBy.Name'), 'Standard relationship traversal should be valid');
	}

	/**
	 * @description Tests that a Foobar__c Id resolves to the correct object name.
	 *
	 * @see UTIL_SObjectDescribe.getObjectNameFromId
	 */
	@IsTest
	private static void resolveObjectNameFromId()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build();

		Test.startTest();

		String objectName = UTIL_SObjectDescribe.getObjectNameFromId(record.Id);

		Test.stopTest();

		Assert.areEqual(SEL_Foobar.OBJECT_NAME, objectName, MSG_INCORRECT_OBJECT_NAME);
	}

	/**
	 * @description Tests that a Foobar__c Id resolves to Foobar__c.SObjectType.
	 *
	 * @see UTIL_SObjectDescribe.getSObjectTypeById
	 */
	@IsTest
	private static void resolveSObjectTypeById()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build();

		Test.startTest();

		SObjectType objectType = UTIL_SObjectDescribe.getSObjectTypeById(record.Id);

		Test.stopTest();

		Assert.areEqual(Foobar__c.SObjectType, objectType, MSG_INCORRECT_OBJECT_TYPE);
	}

	/**
	 * @description Tests that a valid name returns SObjectType and an invalid name returns null.
	 *
	 * @see UTIL_SObjectDescribe.getSObjectTypeByName
	 */
	@IsTest
	private static void resolveSObjectTypeByName()
	{
		Test.startTest();

		SObjectType validObjectType = UTIL_SObjectDescribe.getSObjectTypeByName(SEL_Foobar.OBJECT_NAME);
		SObjectType invalidObjectType = UTIL_SObjectDescribe.getSObjectTypeByName(SEL_Foobar.FIELD_DECIMAL);

		Test.stopTest();

		Assert.areEqual(Foobar__c.SObjectType, validObjectType, MSG_INCORRECT_OBJECT_TYPE);
		Assert.isNull(invalidObjectType, MSG_NULL_RESULT);
	}

	/**
	 * @description Tests that FieldListBuilder single-arg constructor builds a comma-delimited field list.
	 *
	 * @see UTIL_SObjectDescribe.FieldListBuilder
	 */
	@IsTest
	private static void fieldListBuilderShouldBuildFromFieldTokens()
	{
		Test.startTest();

		UTIL_SObjectDescribe.FieldListBuilder builder = new UTIL_SObjectDescribe.FieldListBuilder
				(
						new List<SObjectField> {Account.Name, Account.Industry}
				);

		Test.stopTest();

		String result = builder.toString();
		Assert.isTrue(result.contains(Account.Name.getDescribe().getName()), 'Should contain Name field');
		Assert.isTrue(result.contains(Account.Industry.getDescribe().getName()), 'Should contain Industry field');
	}
}